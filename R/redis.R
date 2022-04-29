#' Redis-based futures
#'
#' Use the Redis key/value database to define partially fault-tolerant,
#' asynchronous task queues for elastic distributed computing.
#'
#' @inheritParams RedisFuture
#' @importFrom redux redis_config
#' @return An object of class [RedisFuture].
#' @example
#' plan(redis)
#' data(warpbreaks)
#' trials <- 1000
#' Map(\(i) future({
#'     i <- sample(NROW(warpbreaks), replace=TRUE)
#'     coefficients(lm(breaks ~ wool * tension, data = warpbreaks[i,]))
#'   }, lazy = TRUE, seed = TRUE), seq(trials)
#" ) |> (
#'        \(v) Reduce(function(x,y) rbind(x, value(y)), init=NULL, v)
#'      )() -> ans
#' plot(density(ans[, 2]), main = "wool coef")
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
