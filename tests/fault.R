# test of fault recovery
#
# This test starts two local workers and issues one task.  The task is
# engineered so that the first worker to try to run it is forced to quit,
# simulating a fault.  The task should then be re-submitted after a short delay
# and succesfully processed by the 2nd worker.
#
# Because this can take a while to run, this test is not run as a standard
# CRAN check; to run it set the envinonment variable TEST_FAULT=1.

quitter <- function() {
  future({
    Sys.sleep(1.1)
    dt <- as.numeric(Sys.time() - t1)
    cat("Elapsed time: ", dt, "\n", file=stderr())
    if(dt < 2) q(save = "no")
    pi
  })
}

if(nchar(Sys.getenv("TEST_FAULT")) > 0 && redux::redis_available()) {
  library("future.redis")
  plan(redis, max_retries = 2)
  ## FIXME: Make Redis queue unique to avoid wreaking havoc
  startLocalWorkers(2, linger = 1)
  t1 <- Sys.time()
  f <- quitter()
  if(!isTRUE(value(f) == pi)) stop("resubmit fault tolerance value error")

# test of max retries on the remaining worker, expect an error
  plan(redis, max_retries = 1)
  t1 <- Sys.time()
  f <- quitter()
  ans <- value(f)
  if(!isTRUE(inherits(ans, "error"))) stop("max_retries fault tolerance error")

  ## FIXME: Make Redis queue unique to avoid wreaking havoc
  removeQ()
}
