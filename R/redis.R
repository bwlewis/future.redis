#' Redis-based futures
#'
#' Use the Redis key/value database to define partially fault-tolerant,
#' asynchronous task queues for elastic distributed computing.
#'
#' @inheritParams RedisFuture
#'
#' @return An object of class [RedisFuture].
#'
#' @example incl/redis.R
#'
#' @seealso [redux::redis_config()], [worker()], [removeQ()]
#'
#' @importFrom redux redis_config
#' @export
redis <- function(expr,
                  substitute = TRUE,
                  envir = parent.frame(),
                  ...,
                  queue = getOption("future.redis.queue", "{{session}}"),
                  config = redis_config(),
                  output_queue = NA,
                  max_retries = 3L)
{
  if (substitute) expr <- substitute(expr)
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
class(redis) <- c("RedisFuture", "future", "function")



#' Remove a Redis-based work queue
#'
#' Redis keys beginning with the `queue` name are removed.
#' Removing the work queue signals to local and remote R workers to exit.
#'
#' @inheritParams RedisFuture
#'
#' @param queue Redis key name of the task queue (Redis list)
#'
#' @return NULL is silently returned (this function is evaluated for the
#' side-effect of altering Redis state).
#'
#' @importFrom redux redis_config hiredis
#' @export
removeQ <- function(queue = getOption("future.redis.queue", "{{session}}"), config = redis_config())
{
  queue <- redis_queue(queue)
  redis <- hiredis(config)

  # Redis keys used
  key_alive <- sprintf("%s.live", queue)

  ## Remove task queue liveness key
  redis[["DEL"]](key = key_alive)

  ## Remove all other keys for this queue
  all_keys <- redis[["KEYS"]](pattern = sprintf("%s.*", queue))
  Map(f = redis[["DEL"]], all_keys)
  
  invisible()
}
