#' future.redis: An elastic distributed computing backend for the future package.
#'
#' The \pkg{future.redis} package implements the Future API
#' using the Redis key/value database to define partially fault-tolerant task
#' queues for elastic distributed computing.
#'
#' @examples
#' \donttest{
#' if (redux::redis_available()) {
#' ## The example assumes that a Redis server is running on the local host
#' ## and standard port.
#' plan(redis)
#' workers <- startLocalWorkers(2, linger = 1.0)
#' demo("mandelbrot", package = "future", ask = FALSE)
#' stopLocalWorkers(workers)
#' }
#' }
#'
#' @docType package
#' @useDynLib future.redis, .registration=TRUE, .fixes="C_"
#' @aliases future.redis-package
#' @name future.redis
NULL
