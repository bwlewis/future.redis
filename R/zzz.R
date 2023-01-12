## To be cached by .onLoad()
FutureRegistry <- NULL

.onLoad <- function(libname, pkgname) {
  ## Import private functions from 'future'
  FutureRegistry <<- import_future("FutureRegistry")
}

