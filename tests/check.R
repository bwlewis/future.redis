library("future.redis")
library("future.tests")

if (redux::redis_available()) {
  plan(redis)
  removeQ()
  startLocalWorkers(1, linger=1)

  run <- function()
  {
    on.exit(removeQ())
    check("redis", timeout = 10, exit_value = FALSE)
    # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
    # quits R session before we can clean up Redis with removeQ.
  }
  result <- run()
}
