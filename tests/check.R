library("future.redis")
library("future.tests")

plan(redis)
removeQ()
startLocalWorkers(1, linger=1)
check("redis", timeout = 10, exit_value = FALSE)
removeQ()
