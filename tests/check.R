library("future.redis")
library("future.tests")

test <- function()
{
  on.exit({removeQ()})
  plan(redis)
  removeQ()
  startLocalWorkers(1, linger=1)
  check("redis", timeout=10)
}

test()
