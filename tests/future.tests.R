if (require("future.tests") && redux::redis_available()) {
  library("future.redis")
  plan(redis)

  ## Make sure we use a unique Redis queue to avoid wreaking havoc elsewhere
  queue <- sprintf("future.redis:%s", future:::session_uuid())
  oopts <- options(future.redis.queue = queue)
  
  removeQ()
  startLocalWorkers(1L, linger = 1.0)

  run <- function()
  {
    ## FIXME: Make Redis queue unique to avoid wreaking havoc
    on.exit(removeQ())
    ## FIXME: Here, queue is hardcoded to the default value
    ## Add an R option/environment variable to override the default?
    check("redis", timeout = 10.0, exit_value = FALSE)
    # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
    # quits R session before we can clean up Redis with removeQ.
  }
  result <- run()

  options(oopts)
}
