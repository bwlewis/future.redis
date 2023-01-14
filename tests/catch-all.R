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
res <- tryCatch({future.redis:::setAlive(0,0,"x")}, error = identity)
if (.Platform[["OS.type"]] == "windows") {
  stopifnot(is.null(res)) ## FIXME
} else {
  stopifnot(inherits(res, "error"))
}

# test auth (expected to fail)
res <- tryCatch({future.redis:::setAlive(6379L, "127.0.0.1", "x", "auth")}, error = identity)
if (.Platform[["OS.type"]] == "windows") {
  stopifnot(is.null(res)) ## FIXME
} else {
  stopifnot(inherits(res, "error"))
}
# test thread creation fail
# ???

if (redux::redis_available()) {
  # worker.R
  # test log to file
  plan(redis)
  
  workers <- startLocalWorkers(1L, linger = 1.0)
  stopifnot(value(future(0L, lazy=FALSE)) == 0L)

  # RedisFuture-class.R (already computed globals)
  l <- list()
  attributes(l)[["already-done"]] = FALSE
  g <- future.redis:::RedisFuture(expr = 0L, globals = l, substitute = FALSE,
         config = redux::redis_config(),
         output_queue = NA, max_retries = 1L)
  # NOTE! substitute = TRUE fails on value below? TO FIX XXX
  stopifnot(value(g) == 0L)
  v <- redis(0L, lazy = FALSE)
  stopifnot(value(v) == 0L)

  ## Make sure to stop local workers
  stopLocalWorkers(workers)
  
  # Assert that queue(?!?) is not in Redis
  queue <- getOption("future.redis.queue", "{{session}}")
  queue <- future.redis:::redis_queue(queue)
  stopifnot(is.null(future.redis:::processTask(task = queue, redis = redux::hiredis())))
}
