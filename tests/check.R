library("future.redis")

if (redux::redis_available()) {
  plan(redis)
  removeQ()
  startLocalWorkers(1L, linger=1.0)

  run <- function()
  {
    on.exit(removeQ())
    check("redis", timeout = 10.0, exit_value = FALSE)
    # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
    # quits R session before we can clean up Redis with removeQ.
  }
  result <- run()
}
