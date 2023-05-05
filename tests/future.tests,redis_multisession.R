if (requireNamespace("future.tests") && redux::redis_available()) {
  library("future.redis")
  
  future.tests::check("redis_multisession", timeout = 10.0, exit_value = FALSE)
  # NOTE: if exit_value = TRUE and not interactive (say, R CMD check) then
  # quits R session before we can clean up Redis with removeQ().
}
