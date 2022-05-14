# test of fault recovery
#
# This test starts two local workers and issues one task.  The task is
# engineered so that the first worker to try to run it is forced to quit,
# simulating a fault.  The task should then be re-submitted after a short delay
# and succesfully processed by the 2nd worker.
#
# Because this can take a while to run, this test is not run as a standard
# CRAN check; to run it set the envinonment variable TEST_FAULT=1.
if(nchar(Sys.getenv("TEST_FAULT")) > 0) { 
  library("future.redis")
  plan(redis)
  startLocalWorkers(2, linger=1)
  t1 <- Sys.time()
  f <- future({
    Sys.sleep(1.1)
    dt <- as.numeric(Sys.time() - t1)
    cat("Elapsed time: ", dt, "\n", file=stderr())
    if(dt < 2) q(save = "no")
    pi
  })
  value(f)
  removeQ()
}
