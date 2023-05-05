.onLoad <- function(libname, pkgname) {
  ## Set 'debug' option by environment variable
  value <- Sys.getenv("R_FUTURE_REDIS_DEBUG", "FALSE")
  value <- isTRUE(suppressWarnings(as.logical(value)))
  options(future.redis.debug = value)

  ## Set 'queue' option by environment variable
  value <- Sys.getenv("R_FUTURE_REDIS_QUEUE", NA_character_)
  if (!is.na(value)) {
    options(future.redis.queue = value)
  }
}
