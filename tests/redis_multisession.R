## The example assumes that a Redis server is running
## on the local host and the standard Redis port (6379)
if (redux::redis_available()) {
  library(future.redis)
  
  message("redis_multisession() ...")

  # Start two local R worker processes running in the background
  workers <- startLocalWorkers(2L, linger = 1.0)
  
  plan(redis, workers = workers)

  message("- future(42)")
  f <- future(42L)
  v <- value(f)
  stopifnot(identical(v, 42L))

  message("- future(2*a)")
  a <- 3.14
  f <- future(2*a)
  v <- value(f)
  stopifnot(identical(v, 2*3.14))

  # Make sure to stop the workers
  stopLocalWorkers(workers)

  message("redis_multisession() ... done")
}
