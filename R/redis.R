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
                  output_queue = NA_character_,
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
