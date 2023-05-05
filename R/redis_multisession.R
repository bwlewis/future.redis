#' Redis-based localhost multisession futures
#'
#' @inheritParams redis
#' @inheritParams future::multisession
#'
#' @return An object of class [RedisFuture].
#'
#' @example incl/redis_multisession.R
#'
#' @seealso [redux::redis_config()], [redis()]
#'
#' @importFrom parallelly availableCores
#' @importFrom redux redis_config
#' @export
redis_multisession <- local({
  .workers <- NULL
  .nworkers <- 0L
  
  function(expr,
           substitute = TRUE,
           envir = parent.frame(),
           ...,
           workers = availableCores(),
           queue = getOption("future.redis.queue", "{{session}}"),
           config = redis_config(),
           output_queue = NA_character_,
           max_retries = 3L)
  {
    if (substitute) expr <- substitute(expr)

    if (is.null(workers)) {
      .workers <<- NULL
      .nworkers <<- 0L
      return(invisible())
    }

    if (inherits(workers, "RedisWorkerConfiguration")) {
      queue <- workers[["queue"]]
      config <- workers[["config"]]
      .workers <<- workers
      .nworkers <- Inf   ## FIXME: Number of workers is unknown
    } else if (is.function(workers)) {
      workers <- workers()
    } else if (!is.numeric(workers)) {
      stop(sprintf("Argument 'workers' should be a numeric, a function, or an RedisWorkerConfiguration object: ", class(workers)[1]))
    }
  
    if (is.numeric(workers)) {
      workers <- structure(as.integer(workers), class = class(workers))
      stopifnot(length(workers) == 1, is.finite(workers), workers >= 1)
  
      ## Reuse existing worker configuration, i.e.
      ## ignore 'queue' and 'config' arguments
      if (!is.null(.workers)) {
        queue <- .workers[["queue"]]
        config <- .workers[["config"]]
        delta <- workers - .nworkers
      } else {
        delta <- workers
      }
      
      ## Need to launch more workers?
      if (delta > 0L) {
        .workers <<- startLocalWorkers(delta, queue = queue, config = config)
        .nworkers <<- workers
      }
    }
  
    future <- RedisFuture(
                expr = expr, substitute = FALSE,
                envir = envir, 
                ...,
                queue = queue,
                config = config,
                output_queue = output_queue,
                max_retries = max_retries
              )
    if(!isTRUE(future[["lazy"]])) future <- run(future)
    invisible(future)
  }
})
class(redis_multisession) <- c("redis_multisession", "redis", "multiprocess", "future", "function")
attr(redis_multisession, "init") <- TRUE
attr(redis_multisession, "tweakable") <- "workers"



#' @importFrom future nbrOfWorkers
#' @export
nbrOfWorkers.redis <- function(evaluator) {
  ## FIXME: Find a way to query Redis for the number of active workers
  Inf
}

#' @importFrom future nbrOfFreeWorkers
#' @export
nbrOfFreeWorkers.redis <- function(evaluator, background = FALSE, ...) {
  ## FIXME: Find a way to query Redis for the number of free workers
  Inf
}

#' @importFrom future nbrOfWorkers
#' @export
nbrOfWorkers.redis_multisession <- function(evaluator) {
  expr <- formals(evaluator)$workers
  workers <- eval(expr, enclos = baseenv())
  if (is.function(workers)) {
    workers <- workers()
  }
  if (inherits(workers, "RedisWorkerConfiguration")) {
    ## FIXME: Find a way to query Redis for the number of active workers
    workers <- Inf
  } else if (is.numeric(workers)) {
  } else {
      stopf("Unsupported type of 'workers' for evaluator of class %s: %s", 
          paste(sQuote(class(evaluator)), collapse = ", "), 
          class(workers)[1])
  }
  stopifnot(length(workers) == 1L, !is.na(workers), workers >= 1L)
  workers
}