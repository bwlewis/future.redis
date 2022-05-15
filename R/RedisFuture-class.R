#' A Redis-based future task queue implementation
#'
#' Set up the future parameters.
#'
#' @inheritParams future::`Future-class`
#' @param queue Redis task queue
#' @param globals (optional) a logical, a character vector, a named list, or
#' a [globals::Globals] object.  If `TRUE`, globals are identified by code
#' inspection based on `expr` and `tweak` searching from environment
#' `envir`.  If `FALSE`, no globals are used.  If a character vector, then
#' globals are identified by lookup based their names `globals` searching
#' from environment `envir`.  If a named list or a Globals object, the
#' globals are used as is.
#' @param packages (optional) R packages to load on worker processes
#' @param lazy logical value, if \code{TRUE} then delay submitting the task
#' associated with the future to the associated task queue in Redis until the
#' future status is polled or its value is requested
#' @param config Redis config
#' @param queue Redis key name of the task queue (Redis list)
#' @param output_queue (optional) Redis key name of the work output queue
#'        (note: reserved for future use).
#' @param max_retries Maximum number of times the future can be submitted
#'        to the task queue in the event of failure.
#' @return An object of class `RedisFuture`.
#' @keywords internal
#' @importFrom future getGlobalsAndPackages Future
#' @importFrom redux redis_config
#' @export
RedisFuture <- function(expr = NULL,
                        substitute = TRUE,
                        globals = TRUE,
                        packages = NULL,
                        envir = parent.frame(),
                        lazy = FALSE,
                        queue = "RJOBS",
                        config = redis_config(),
                        output_queue = NA,
                        max_retries = 3,
                        ...)
{
  if (substitute) expr <- substitute(expr)
  ## Record globals
  if (!isTRUE(attr(globals, "already-done", exact = TRUE))) {
    gp <- getGlobalsAndPackages(expr, envir = envir, persistent = FALSE, globals = globals)
    globals <- gp[["globals"]]
    packages <- c(packages, gp[["packages"]])
    expr <- gp[["expr"]]
    gp <- NULL
  }
  envir <- new.env(parent = envir)
  envir <- assign_globals(envir, globals = globals)

  future <- Future(expr = expr,
                   envir = envir,
                   substitute = substitute,
                   packages = packages,
                   lazy = lazy,
                   ...)
  future[["config"]] <- config
  future[["queue"]] <- as.character(queue)
  future[["retries"]] <- 0L
  future[["state"]] <- "created"
  future[["max_retries"]] <- as.integer(max_retries)
  structure(future, class = c("RedisFuture", class(future)))
}


#' Check on the status of a future task.
#' @return boolean indicating the task is finished (TRUE) or not (FALSE)
#' @importFrom redux redis_multi
#' @importFrom future resolved
#' @keywords internal
#' @export
resolved.RedisFuture <- function(x, ...) {
  resolved <- NextMethod()
  if(resolved) return(TRUE)
  if(x[["state"]] == "finished") {
    return(TRUE)
  } else if(x[["state"]] == "created") { # Not yet submitted to queue (iff lazy)
    x <- run(x)
    return(FALSE)
  }
  # return status key for this task from Redis
  hi <- hiredis(x[["config"]])
  status <- redis_multi(hi, {
    hi[["GET"]](sprintf("%s.%s.status", x[["queue"]], x[["taskid"]]))
    hi[["EXISTS"]](sprintf("%s.%s.live", x[["queue"]], x[["taskid"]]))
  })
  # check for task problems
  if(isTRUE(status[[1]] == "running")) {
    if(!isTRUE(status[[2]] == 1)) {
      # The task is marked running but the corresponding 'live' key has expired.
      # Re-submit the tasks to the queue.
      return(!isTRUE(is.null(resubmit(x, hi))))
    }
  }
  isTRUE(status[[1]] == "finished")
}


#' Re-submit a future to the task queue
#' @param future An object of class RedisFuture
#' @param redis A redux Redis connection
#' @importFrom redux redis_multi
#' @importFrom future FutureResult
#' @return If the number of retries is less than or equal to the maximum number of retries,
#' then the re-submitted future is invisibly returned. Otherwise NULL is returned.
#' @keywords internal
resubmit <- function(future, redis) {
  future[["state"]] <- "created"
  future[["retries"]] <- tryCatch(
    future[["retries"]] + 1,
    error = function(e) Inf
  )
  warning(sprintf("Detected lost task %s, resubmitting (%d).", future[["taskid"]], future[["retries"]]))
  if(isTRUE(future[["retries"]] >= future[["max_retries"]])) {
    # This task has exceeded the retry limit, return an error.
    status <- sprintf("%s.%s.status", future[["queue"]], future[["taskid"]])
    if(redis[["EXISTS"]](status)) {
      warning(sprintf("Task %s exceeded maximum number of retries, returning error.", future[["taskid"]]))
      ans <- FutureResult(value = errorCondition("Task excedded maximum number of retries."))
      redis_multi(redis, {
        redis[["LPUSH"]](key = future[["output_queue"]], serialize(ans, NULL))
        redis[["SET"]](key = status, value = "finished")
      })
      return()
    }
  }
  invisible(run(future))
}

#' Submit the future to the task queue
#' @param future an object of class \code{Redis.future}
#' @param ... additional parameters for \code{future} class methods
#' @importFrom digest digest
#' @importFrom redux hiredis
#' @importFrom future run
#' @export
run.RedisFuture <- function(future, ...) {
  if(isTRUE(future[["state"]] != "created")) return(invisible(future))
  future[["state"]] <- "submitted"
  future[["taskid"]] <- digest(future)
  if(is.null(future[["output_queue"]]) || is.na(future[["output_queue"]])) {
    future[["output_queue"]] <- sprintf("%s.%s.out", future[["queue"]], future[["taskid"]])
  }
  hi <- hiredis(future[["config"]])
  key <- sprintf("%s.%s", future[["queue"]], future[["taskid"]])
  live <- sprintf("%s.live", future[["queue"]])
  status <- sprintf("%s.status", key)
  redis_multi(hi, {
    hi[["SET"]](key = key, value = serialize(future, NULL))
    hi[["SET"]](key = live, value = "")
    hi[["SET"]](key = status, value = "submitted")
    hi[["LPUSH"]](key = future[["queue"]], future[["taskid"]])
  })
  invisible(future)
}

#' Obtain and return a future task result (blocking)
#' @param future an object of class \code{Redis.future}
#' @param ... additional parameters for \code{future} class methods
#' @importFrom future result
#' @export
result.RedisFuture <- function(future, ...) {
  if(isTRUE(future[["state"]] == "finished")) {
    return(future[["result"]])
  }
  hi <- hiredis(future[["config"]])
  key <- sprintf("%s.%s", future[["queue"]], future[["taskid"]])
  status <- sprintf("%s.status", key)
  value <- NULL

  while(TRUE) {
    value <- hi[["BRPOP"]](key = future[["output_queue"]], timeout = 5)[[2]]   # XXX Make configurable
    if(length(value) > 0) break
    status <- redis_multi(hi, {
      hi[["GET"]](sprintf("%s.%s.status", future[["queue"]], future[["taskid"]]))
      hi[["EXISTS"]](sprintf("%s.%s.live", future[["queue"]], future[["taskid"]]))
    })
    future[["state"]] <- status[[1]]
    # check for task problems
    if(isTRUE(future[["state"]] == "running")) {
      if(!isTRUE(status[[2]] == 1)) {
        # The task is marked running but the corresponding 'live' key has expired.
        # Re-submit the tasks to the queue.
        resubmit(future, hi)
      }
    }
    Sys.sleep(0.01) # rate limiting, but allows CTRL + C that redux lacks
  }

  future[["result"]] <- uncerealize(value)
  future[["state"]] <- "finished"
  # clean up Redis state
  redis_multi(hi, {
    hi[["DEL"]](key = future[["output_queue"]])
    hi[["DEL"]](key = key)
    hi[["DEL"]](key = status)
  })
  future[["result"]]
}
