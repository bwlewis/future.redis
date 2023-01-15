#' A Redis-based future task queue implementation
#'
#' Set up the future parameters.
#'
#' @inheritParams future::`Future-class`
#'
#' @param queue A Redis key name of the task queue, or a
#' `RedisWorkerConfiguration` object as returned by [startLocalWorkers()].
#'
#' @param config A [redux::redis_config] Redis configuration object.
#'
#' @param output_queue (optional) Redis key name of the work output queue
#'        (note: reserved for future use).
#'
#' @param max_retries Maximum number of times the future can be re-submitted
#'        to the task queue in the event of failure.
#'
#' @return An object of class `RedisFuture`.
#'
#' @keywords internal
#' @importFrom future getGlobalsAndPackages Future
#' @importFrom redux redis_config
#' @export
RedisFuture <- function(expr = NULL,
                        substitute = TRUE,
                        envir = parent.frame(),
                        globals = TRUE,
                        packages = NULL,
                        lazy = FALSE,
                        queue = getOption("future.redis.queue", "{{session}}"),
                        config = redis_config(),
                        output_queue = NA_character_,
                        max_retries = 3L,
                        ...)
{
  if(isTRUE(substitute)) expr <- substitute(expr)

  if (inherits(queue, "RedisWorkerConfiguration")) {
    config <- queue[["config"]]
    queue <- queue[["queue"]]
  }
  queue <- redis_queue(queue)
  stopifnot(inherits(config, "redis_config"))

  stopifnot(
    length(max_retries) == 1L,
    is.numeric(max_retries),
    is.finite(max_retries),
    max_retries >= 1
  )
  max_retries <- as.integer(max_retries)

  ## Record globals
  if(!isTRUE(attr(globals, "already-done", exact = TRUE))) {
    gp <- getGlobalsAndPackages(expr, envir = envir, persistent = FALSE, globals = globals)
    globals <- gp[["globals"]]
    packages <- c(packages, gp[["packages"]])
    expr <- gp[["expr"]]
    gp <- NULL
  }

  future <- Future(expr = expr,
                   substitute = substitute,
                   envir = envir,
                   globals = globals,
                   packages = packages,
                   lazy = lazy,
                   ...)
  future[["config"]] <- config
  future[["queue"]] <- queue
  future[["retries"]] <- 0L
  future[["state"]] <- "created"
  future[["max_retries"]] <- max_retries
  
  structure(future, class = c("RedisFuture", class(future)))
}


#' Check on the status of a future task.
#' @return boolean indicating the task is finished (TRUE) or not (FALSE)
#' @importFrom redux redis_multi
#' @importFrom future resolved
#' @keywords internal
#' @export
resolved.RedisFuture <- function(x, ...) {
  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebugf("resolved() for %s ...", class(x)[1], debug = debug)
    on.exit(mdebugf("resolved() for %s ... done", class(x)[1], debug = debug))
  }
  
  resolved <- NextMethod()
  if(resolved) {
    mdebug("- already resolved", debug = debug)
    return(TRUE)
  }
  
  if(x[["state"]] == "finished") {
    mdebug("- already resolved (state == finished)", debug = debug)
    return(TRUE)
  } else if(x[["state"]] == "created") { # Not yet submitted to queue (iff lazy)
    mdebug("- just created; launching")
    x <- run(x)
    return(FALSE)
  }

  redis <- hiredis_future(x)
  keys <- redis_future_keys(x)
  
  # return status key for this task from Redis
  mdebug("redux::redis_multi() 'GET'/'EXISTS' ...", debug = debug)
  status <- redis_multi(redis, {
    redis[["GET"]](key = keys[["status"]])    ## a string
    redis[["EXISTS"]](key = keys[["alive"]])  ## 0L if not, 1L if exists
  })
  mstr(status, debug = debug)
  mdebug("redux::redis_multi() 'GET'/'EXISTS' ... done", debug = debug)
  
  # check for task problems
  if(isTRUE(status[[1]] == "running")) {
    if(!isTRUE(status[[2]] == 1L)) {  ## key does not exist
      # The task is marked running but the corresponding 'live' key has expired.
      # Re-submit the tasks to the queue.
      mdebug("- task is running, but Redis key has expired; resubmitting", debug = debug)
      return(!isTRUE(is.null(resubmit(x, redis))))
    }
  }
  isTRUE(status[[1]] == "finished")
}


#' Re-submit a future to the task queue
#' @param future An object of class RedisFuture.
#' @param redis A redux Redis connection.
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
  warning(sprintf("Detected lost task %s, resubmitting (%d)", future[["taskid"]], future[["retries"]]))

  # Redis keys used
  keys <- redis_future_keys(future)
  
  if(isTRUE(future[["retries"]] >= future[["max_retries"]])) {
    # This task has exceeded the retry limit, return an error.
    if(redis[["EXISTS"]](key = keys[["status"]])) {
      msg <- sprintf("Task %s exceeded maximum number of retries (%g), returning error",
                     future[["taskid"]], future[["max_retries"]])
      warning(msg)
      msg <- sprintf("Task exceeded maximum number of retries (%g)",
                     future[["max_retries"]])
      result <- FutureResult(value = errorCondition(msg))
      result <- serialize(result, connection = NULL)
      status <- redis_multi(redis, {
        redis[["LPUSH"]](key = keys[["output_queue"]], value = result)
        redis[["SET"]](key = keys[["status"]], value = "finished")
      })
      mstr(status)
      return()
    }
  }
  
  # No need to re-serialize here, future already cached. simply re-submit ID to queue.

  status <- redis_multi(redis, {
    redis[["SET"]](key = keys[["status"]], value = "submitted")
    redis[["LPUSH"]](key = keys[["queue"]], value = future[["taskid"]])
  })
  mstr(status)

  invisible(future)
}

#' @importFrom digest digest
#' @importFrom redux hiredis
#' @importFrom future run
#' @export
run.RedisFuture <- function(future, ...) {
  if(isTRUE(future[["state"]] != "created")) return(invisible(future))
  
  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebugf("run() for %s ...", class(future)[1], debug = debug)
    on.exit(mdebugf("run() for %s ... done", class(future)[1], debug = debug))
  }

  future[["state"]] <- "submitted"
  future[["taskid"]] <- digest(future)

  # Redis keys used
  keys <- redis_future_keys(future)
  
  if(is.null(future[["output_queue"]]) || is.na(future[["output_queue"]])) {
    future[["output_queue"]] <- sprintf("%s.out", keys[["name"]])
  }

  redis <- hiredis_future(future)
  keys <- redis_future_keys(future)
  
  mdebug("redux::redis_multi() 'SET' ...", debug = debug)
  status <- redis_multi(redis, {
    redis[["SET"]](key = keys[["name"]], value = serialize(future, connection = NULL))
    redis[["SET"]](key = keys[["alive"]], value = "")
    redis[["SET"]](key = keys[["status"]], value = "submitted")
    redis[["LPUSH"]](key = keys[["queue"]], value = future[["taskid"]])
  })
  mstr(status, debug = debug)
  mdebug("redux::redis_multi() 'SET' ... done", debug = debug)

  invisible(future)
}


#' @importFrom future result
#' @export
result.RedisFuture <- function(future, ...) {
  if(isTRUE(future[["state"]] == "finished")) {
    return(future[["result"]])
  }

  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebugf("result() for %s ...", class(future)[1], debug = debug)
    on.exit(mdebugf("result() for %s ... done", class(future)[1], debug = debug))
  }

  redis <- hiredis_future(future)
  keys <- redis_future_keys(future)

  value <- NULL

  count <- 0L
  while(TRUE) {
    count <- count + 1L
    mdebugf(" - redis poll #%d", count, debug = debug)
    value <- redis[["BRPOP"]](key = keys[["output_queue"]], timeout = 5.0)[[2]]   # FIXME: Make configurable
    mdebugf(" - length(value): %d", length(value), debug = debug)
    if(length(value) > 0) break
    
    mdebug("redux::redis_multi() 'GET'/'EXISTS' ...", debug = debug)
    status <- redis_multi(redis, {
      redis[["GET"]](key = keys[["status"]])    ## a string
      redis[["EXISTS"]](key = keys[["alive"]])  ## 0L if not, 1L if exists
    })
    mstr(status, debug = debug)
    mdebug("redux::redis_multi() 'GET'/'EXISTS' ... done", debug = debug)
    
    future[["state"]] <- status[[1]]
    mdebugf("- future$state: %s", future[["state"]], debug = debug)
    
    # check for task problems
    if(isTRUE(future[["state"]] == "running")) {
      if(!isTRUE(status[[2]] == 1L)) {  # does not exists
        # The task is marked running but the corresponding 'live' key has expired.
        # Re-submit the tasks to the queue.
        mdebug("- task is running, but Redis key has expired; resubmitting", debug = debug)
        resubmit(future, redis)
      }
    }
    Sys.sleep(0.01) # rate limiting, but allows CTRL + C that redux lacks
  }

  future[["result"]] <- uncerealize(value)
  future[["state"]] <- "finished"
  
  # clean up Redis state
  mdebug("redux::redis_multi() 'DEL' ...", debug = debug)
  status <- redis_multi(redis, {
    redis[["DEL"]](key = keys[["output_queue"]])
    redis[["DEL"]](key = keys[["name"]])
    redis[["DEL"]](key = keys[["status"]])
  })
  mstr(status, debug = debug)
  mdebug("redux::redis_multi() 'DEL' ... done", debug = debug)

  future[["result"]]
}


#' @importFrom redux hiredis
hiredis_future <- function(future) {
  stopifnot(inherits(future, "RedisFuture"))
  
  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebug("hiredis_future() ...", debug = debug)
    on.exit(mdebug("hiredis_future() ... done", debug = debug))
  }
  
  config <- future[["config"]]
  mstr(config, debug = debug)
  
  redis <- hiredis(config)
  mdebugf("- result: %s object", sQuote(class(redis)[1]), debug = debug)

  redis
}


redis_future_keys <- function(future) {
  stopifnot(inherits(future, "RedisFuture"))
  
  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebug("redis_future_keys() ...", debug = debug)
    on.exit(mdebug("redis_future_keys() ... done", debug = debug))
  }

  # Redis keys used
  name <- sprintf("%s.%s", future[["queue"]], future[["taskid"]])
  keys <- list(
            name = name,
           alive = sprintf("%s.live", name),
          status = sprintf("%s.status", name),
    output_queue = future[["output_queue"]],
           queue = future[["queue"]]
  )

  mstr(keys, debug = debug)
  
  keys
}
