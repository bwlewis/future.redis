#' Start a Redis worker process
#' The worker process blocks for tasks on the specified queue (a Redis list).
#' The worker continues to process tasks from the queue untile the queue liveness key is removed,
#' or until a Redis communication or other error occurs; after which the worker exits (quits R).
#' @param queue The Redis task queue
#' @param linger in seconds, max time before system checks (including termination).
#' @param config Redis configuration (see XXX TODO: add reference)
#' @param quit if TRUE, quit R on exit
#' @importFrom redux redis_config hiredis
#' @export
worker <- function(queue = "RJOBS",
                        linger = 10,
                        config = redis_config(),
                        quit = FALSE)
{
  if(quit) {
    on.exit(quit(save = "no"))
  }
  msg <- tryCatch({
    hi <- hiredis(config)
    # Set liveness key
    live <- sprintf("%s.live", queue)
    hi[["SET"]](key = live, value = "")
    if(interactive()) message("Waiting for doRedis jobs.")
    while(TRUE) {
      taskid <- hi[["BRPOP"]](queue, timeout = linger)[[2]]
      if(!is.null(taskid)) {
        message("Retrieved task ", taskid)
        processTask(sprintf("%s.%s", queue, taskid), hi)
      }
      # Check for queue liveness key, worker exit if missing
      if(!hi[["EXISTS"]](live)) {
        stop("Normal worker shutdown")
      }
    }
  }, error = function(e) message(e))
  message(msg)
}

#' Process a task
#' @param task A Redis key containing the future to process
#' @param redis A hiredis connection
#' @keywords internal
processTask <- function(task, redis)
{
  t_start <- Sys.time()
  future <- tryCatch(uncerealize(redis[["GET"]](key = task)), error = function(e) NULL)
  if(is.null(future)) return()
  message("Obtained future ", task, " ", t_start)
# XXX check class
# XXX TODO: Start thread to maintain task liveness key

  # Process the future, first attaching required packages (if any)
  for(p in future[["packages"]]) {
    require(p, quietly = TRUE, character.only = TRUE)
  }
  ans <- FutureResult(
    value = eval(future[["expr"]], envir = future[["envir"]]),
    started = t_start,
    finished = Sys.time()
  )
  # Detach packages
  for(p in future[["packages"]]) {
    tryCatch(detach(sprintf("package:%s", p), character.only = TRUE), error = invisible)
  }
  message("Submitting result to ", future[["output_queue"]], " ", ans[["finished"]])
  redis[["LPUSH"]](key = future[["output_queue"]], serialize(ans, NULL))
}
