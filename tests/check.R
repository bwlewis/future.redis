library("future.redis")
library("future.tests")

plan(redis)
removeQ()
startLocalWorkers(1, linger=1, log="/dev/null")
check("redis", timeout=10)
removeQ()
