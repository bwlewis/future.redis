#' future.redis: An elastic distributed computing backend for the future package.
#'
#' The \pkg{future.redis} package implements the Future API
#' using the Redis key/value database to define partially fault-tolerant task
#' queues for elastic distributed computing.
#'
#' @examples
#' \donttest{
#' plan(redis)
#' demo("mandelbrot", package = "future", ask = FALSE)
#' }
#'
#' @docType package
#' @useDynLib future.redis, .registration=TRUE, .fixes="C_"
#' @aliases future.redis-package
#' @name future.redis
NULL
