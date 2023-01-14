if (require("future.tests") && redux::redis_available()) {
  library("future.redis")
  plan(redis)
  
  ## FIXME: Make Redis queue unique to avoid wreaking havoc
  removeQ()
  startLocalWorkers(1L, linger=1.0)

  run <- function()
  {
    ## FIXME: Make Redis queue unique to avoid wreaking havoc
    on.exit(removeQ())
    check("redis", timeout = 10.0, exit_value = FALSE)
    # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
    # quits R session before we can clean up Redis with removeQ.
  }
  result <- run()
}
