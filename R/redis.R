#' Redis-based futures
#'
#' Use the Redis key/value database to define partially fault-tolerant task
#' queues for elastic distributed computing.
#'
#' @inheritParams RedisFuture
#' @importFrom redux redis_config
#' @return An object of class [RedisFuture].
#' @export
redis <- function(...,
                  queue = "RJOBS",
                  config = redis_config(),
                  output_queue = NA)
{
  future <- RedisFuture(..., queue=queue, config=config, output_queue=output_queue)
  invisible(run(future))
}
class(redis) <- c("RedisFuture", "future", "function")


#' Remove a Redis-based work queue
#'
#' Removing the work queue signlas to local and remote R workers to exit.
#'
#' @param config Redis config
#' @param queue Redis key name of the task queue (Redis list)
#' @importFrom redux redis_config hiredis
#' @export
removeQ <- function(queue = "RJOBS", config = redis_config())
{
  hiredis(config)[["DEL"]](sprintf("%s.live", queue)) # liveness key
  hiredis(config)[["DEL"]](queue)                     # the task queue
}
