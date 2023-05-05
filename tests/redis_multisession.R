## The example assumes that a Redis server is running
## on the local host and the standard Redis port (6379)
if (redux::redis_available()) {
  library(future.redis)
  
  message("redis_multisession()...")

  message("- workers = <RedisWorkerConfiguration>")
  
  # Start two local R worker processes running in the background
  workers <- startLocalWorkers(2L, linger = 1.0)
  
  plan(redis_multisession, workers = workers)

  message("- future(42)")
  f <- future(42L)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 42L))

  message("- future(2*a)")
  a <- 3.14
  f <- future(2*a)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 2*3.14))

  message("- future(2*a)")
  a <- 3.14
  f <- future(2*a)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 2*3.14))

  # Make sure to stop the workers
  stopLocalWorkers(workers)
  ## Reset cache (FIXME: This is a hack)
  redis_multisession(workers = NULL)

  message("- workers = 2")
  
  plan(redis_multisession, workers = 2L)

  message("- future(42)")
  f <- future(42L)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 42L))

  message("- future(42)")
  f <- future(42L)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 42L))

  message("- future(2*a)")
  a <- 3.14
  f <- future(2*a)
  v <- value(f)
  print(v)
  stopifnot(identical(v, 2*3.14))

  ## Reset cache (FIXME: This is a hack)
  redis_multisession(workers = NULL)

  message("redis_multisession() ... done")
}
