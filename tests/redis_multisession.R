## The example assumes that a Redis server is running
## on the local host and the standard Redis port (6379)
if (redux::redis_available()) {
  library(future.redis)
  
  message("redis_multisession() ...")

  # Start two local R worker processes running in the background
  workers <- startLocalWorkers(2L, linger = 1.0)
  
  plan(redis, workers = workers)

  f <- future(42L)
  v <- value(f)
  stopifnot(identical(v, 42L))
  
  # Make sure to stop the workers
  stopLocalWorkers(workers)

  message("redis_multisession() ... done")
}
