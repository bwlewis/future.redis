if (require("future.tests") && redux::redis_available()) {
  library("future.redis")
  
  workers <- startLocalWorkers(1L, linger = 1.0)

  run <- function()
  {
    ## Make sure to stop local workers at the end
    on.exit({
      stopLocalWorkers(workers)
    })
    
    check("redis", timeout = 10.0, exit_value = FALSE)
    # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
    # quits R session before we can clean up Redis with removeQ().
  }
  
  result <- run()
}
