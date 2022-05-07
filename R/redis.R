#' Redis-based futures
#'
#' Use the Redis key/value database to define partially fault-tolerant,
#' asynchronous task queues for elastic distributed computing.
#'
#' @inheritParams RedisFuture
#' @importFrom redux redis_config
#' @return An object of class [RedisFuture].
#' @seealso \code{\link{redis_config}}, \code{\link{worker}}, \code{\link{removeQ}}
#' @examples
#' if (redux::redis_available()) {
#' ## The example assumes that a Redis server is running on the local host
#' ## and standard port.
#' 
#' # Register the redis plan on a specified task queue:
#' plan(redis, queue = "R jobs")
#' 
#' # Start some local R worker processes:
#' startLocalWorkers(n=2, queue="R jobs", linger=1)
#' 
#' # Alternatively, use the following to run the workers quietly without
#' # showing their output as they run:
#' # startLocalWorkers(n=2, queue="R jobs", linger=1, log="/dev/null")
#' 
#' # A function that returns a future, note that N uses lexical scoping...
#' f <- \() future({4 * sum((runif(N) ^ 2 + runif(N) ^ 2) < 1) / N}, seed = TRUE)
#' 
#' # Run a simple sampling approximation of pi in parallel using  M * N points:
#' N <- 1e6  # samples per worker
#' M <- 10   # iterations
#' Reduce(sum, Map(value, replicate(M, f()))) / M
#' 
#' # Clean up
#' removeQ("R jobs")
#' }
#' @export
redis <- function(...,
                  queue = "RJOBS",
                  config = redis_config(),
                  output_queue = NA,
                  max_retries = 3)
{
  future <- RedisFuture(..., queue=queue, config=config,
              output_queue=output_queue, max_retries = max_retries)
  invisible(run(future))
}
class(redis) <- c("RedisFuture", "future", "function")


#' Remove a Redis-based work queue
#'
#' Redis keys beginning with the \code{queue} name are removed.
#' Removing the work queue signlas to local and remote R workers to exit.
#'
#' @param config Redis config
#' @param queue Redis key name of the task queue (Redis list)
#' @return NULL is silently returned (this function is evaluated for the
#' side-effect of altering Redis state).
#' @importFrom redux redis_config hiredis
#' @export
removeQ <- function(queue = "RJOBS", config = redis_config())
{
  all_keys <- hiredis(config)[["KEYS"]](sprintf("%s.*", queue))
  del <- hiredis(config)[["DEL"]]
  Map(del, all_keys)
  invisible()
}
