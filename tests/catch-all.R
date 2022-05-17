# Catch-all checks of bad, missing or edge-case function arguments 

# 1. utils.R
stopifnot(tryCatch({assign_globals(pi)}, error = function(e) TRUE))
stopifnot(tryCatch({assign_globals(new.env(), globals = pi)}, error = function(e) TRUE))
future.redis:::assign_globals(new.env(), globals = list(), debug = TRUE)
stopifnot(!isTRUE(future.redis:::inherits_from_namespace(new.env())))
stopifnot(is.null(future.redis:::uncerealize(NULL)))
stopifnot(future.redis:::uncerealize(0L) == 0L)
if (redux::redis_available()) {
  config <- redux::redis_config()
  key <- paste(sample(letters,26), collapse="")
  future.redis:::setAlive(config[["port"]], config[["host"]], key)
  future.redis:::delAlive()
}
