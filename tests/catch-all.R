# Catch-all checks of bad, missing or edge-case function arguments 
library("future.redis")

# utils.R
stopifnot(tryCatch({future.redis:::assign_globals(pi)}, error = function(e) TRUE))
stopifnot(tryCatch({future.redis:::assign_globals(new.env(), globals = pi)}, error = function(e) TRUE))
stopifnot(!isTRUE(future.redis:::inherits_from_namespace(baseenv())))
stopifnot(is.null(future.redis:::uncerealize(NULL)))
stopifnot(future.redis:::uncerealize(0L) == 0L)
if (redux::redis_available()) {
  config <- redux::redis_config()
  key <- paste(sample(letters,26), collapse="")
  future.redis:::setAlive(config[["port"]], config[["host"]], key)
  future.redis:::setAlive(config[["port"]], config[["host"]], key)
  future.redis:::delAlive()
  future.redis:::delAlive()
}

# alive.c
# test bogus host/port
stopifnot(tryCatch({future.redis:::setAlive(0,0,"x")}, error = function(e) TRUE))
# test auth (expected to fail)
stopifnot(tryCatch({future.redis:::setAlive(6379L, "127.0.0.1", "x", "auth")}, error = function(e) TRUE))
# test thread creation fail
# ???

if (redux::redis_available()) {
# worker.R
# test log to file
  plan(redis)
  startLocalWorkers(1, linger=1, log=tempfile())
  stopifnot(value(future(0L, lazy=FALSE)) == 0L)

# RedisFuture-class.R (already computed globals)
  l <- list()
  attributes(l)[["already-done"]] = FALSE
  g <- future.redis:::RedisFuture(expr = 0L, globals = l, substitute = FALSE,
         queue = "RJOBS", config = redux::redis_config(),
         output_queue = NA, max_retries = 1L)
  # NOTE! substitute = TRUE fails on value below? TO FIX XXX
  stopifnot(value(g) == 0L)
  v <- redis(0L, lazy=FALSE)
  stopifnot(value(v) == 0L)
  removeQ()
# null task (we know for sure 'RJOBS' is not in redis from above test removeQ)
  stopifnot(is.null(future.redis:::processTask("RJOBS", redux::hiredis())))
}
