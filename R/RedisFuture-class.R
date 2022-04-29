#' A Redis future implementation.
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
#' @param config Redis config
#' @param queue Redis key name of the task queue (Redis list)
#' @param output_queue (optional) Redis key name of the work output queue (Redis list)
#' @return An object of class `RedisFuture`.
#' @aliases run.RedisFuture
#' @keywords internal
#' @importFrom future getGlobalsAndPackages
#' @importFrom redux redis_config
#' @export
RedisFuture <- function(expr = NULL,
                        substitute = TRUE,
                        globals = TRUE,
                        packages = NULL,
                        envir = parent.frame(),
                        lazy = TRUE,
                        queue = "RJOBS",
                        config = redis_config(),
                        output_queue = NA,
                        ...)
{
  if (substitute) expr <- substitute(expr)
  ## Record globals
  if (!isTRUE(attr(globals, "already-done", exact = TRUE))) {
    gp <- getGlobalsAndPackages(expr, envir = envir, persistent = persistent, globals = globals)
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
                   lazy = TRUE,
                   ...)
  future[["config"]] <- config
  future[["queue"]] <- queue
  future[["state"]] <- "created"
  structure(future, class = c("RedisFuture", class(future)))
}


#' Check on the status of a future task.
#' @return boolean indicating the task is finished (TRUE) or not (FALSE)
#' @importFrom future resolved
#' @keywords internal
#' @export
resolved.RedisFuture <- function(x, ...) {
  resolved <- NextMethod()
  if(resolved) return(TRUE)
  if(x[["state"]] == "finished") return(TRUE)

  # check for task problems... XXX XXX TODO:

  # return status key for this task in Redis
  hi <- hiredis(x[["config"]])
  isTRUE(hi[["GET"]](sprintf("%s.%s.status", x[["queue"]], x[["taskid"]])) == "finished")
}

#' Submit the future to the task queue
#' @importFrom digest digest
#' @importFrom redux hiredis
#' @export
run.RedisFuture <- function(future, ...) {
  if(isTRUE(future[["state"]] == "submitted")) return(invisible(future))
  future[["state"]] <- "submitted"
  future[["taskid"]] <- digest(future)
  if(is.null(future[["output_queue"]]) || is.na(future[["output_queue"]])) {
    future[["output_queue"]] <- sprintf("%s.%s.out", future[["queue"]], future[["taskid"]])
  }
  hi <- hiredis(future[["config"]])
  key <- sprintf("%s.%s", future[["queue"]], future[["taskid"]])
  live <- sprintf("%s.live", future[["queue"]])
  status <- sprintf("%s.status", key)
## XXX TODO: consolidate the following into a single transaction (low-priority)
  hi[["SET"]](key = key, value = serialize(future, NULL))
  hi[["SET"]](key = live, value = "")
  hi[["SET"]](key = status, value = "submitted")
  hi[["LPUSH"]](key = future[["queue"]], future[["taskid"]])
  invisible(future)
}

#' Obtain and return a future task result (blocking)
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
# XXX other housekeeping things here XXX
    Sys.sleep(0.01) # rate limiting, but allows CTRL + C that redux lacks
  }

  future[["result"]] <- uncerealize(value)
  future[["state"]] <- "finished"
  # clean up Redis state
## XXX TODO: consolidate the following into a single transaction (low-priority)
  hi[["DEL"]](key = future[["output_queue"]])
  hi[["DEL"]](key = key)
  hi[["DEL"]](key = status)
  future[["result"]]
}
