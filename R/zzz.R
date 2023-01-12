## To be cached by .onLoad()
FutureRegistry <- NULL

.onLoad <- function(libname, pkgname) {
  ## Import private functions from 'future'
  FutureRegistry <<- import_future("FutureRegistry")

  ## Set debug option by environment variable
  debug <- Sys.getenv("R_FUTURE_REDIS_DEBUG", "FALSE")
  debug <- isTRUE(suppressWarnings(as.logical(debug)))
  options(future.redis.debug = debug)
}

