library("future.redis")
library("future.tests")

plan(redis)
startLocalWorkers(1, linger=1, log="/dev/null")
check("redis", timeout=5)
removeQ()
