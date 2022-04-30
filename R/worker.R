#' Start a Redis worker process loop
#'
#' The worker process blocks for tasks on the specified queue (a Redis list).
#' The worker continues to process tasks from the queue untile the queue
#' liveness key is removed (see \code{\link{removeQ}}), the number of
#' processed tasks reaches the \code{iter} limit, or until a Redis
#' communication or other error occurs; after which the worker exits (quits R).
#' @param queue Redis task queue name.
#' @param linger in seconds, max time before system checks (including termination).
#' @param config Redis configuration (see \code{\link{redux::redis_config}}
#' @param iter Maximum number of tasks to acquire before exiting.
#' @param quit if TRUE, quit R on exit.
#' @param log divert stdout and messages to log file.
#' @importFrom redux redis_config hiredis
#' @return After conclusion of the worker loop, either R exits or NULL
#' is silently returned.
#' @export
worker <- function(queue = "RJOBS",
                   linger = 10,
                   config = redis_config(),
                   iter = Inf,
                   quit = FALSE,
                   log = NULL)
{
  if(quit) {
    on.exit(quit(save = "no"))
  }
  if(isTRUE(is.character(log)) && isTRUE(nchar(log) > 0)) {
    f <- file(log, open = "w+")
    sink(f)
    sink(f, append = TRUE, type = "message")
    on.exit(sink(), add = TRUE)
  }
  msg <- tryCatch({
    N <- double(1)
    hi <- hiredis(config)
    # Set liveness key
    live <- sprintf("%s.live", queue)
    hi[["SET"]](key = live, value = "")
    if(interactive()) message("Waiting for doRedis jobs.")
    while(isTRUE(N < iter)) {
      taskid <- hi[["BRPOP"]](queue, timeout = linger)[[2]]
      if(!is.null(taskid)) {
        message("Retrieved task ", taskid)
        N <- N + 1
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
#' @importFrom future getExpression
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
  ans <- eval(getExpression(future))
  # Detach packages
  for(p in future[["packages"]]) {
    tryCatch(detach(sprintf("package:%s", p), character.only = TRUE), error = invisible)
  }
  message("Submitting result to ", future[["output_queue"]], " ", ans[["finished"]])
  redis[["LPUSH"]](key = future[["output_queue"]], serialize(ans, NULL))
}




#' Start one or more background R worker processes on the local system.
#'
#' Use \code{startLocalWorkers} to start one or more future.redis R worker
#' processes in the background. The worker processes are started on the local
#' system using the \code{\link{worker}} function.
#'
#' Running workers self-terminate after a \code{linger} interval if their task
#' queue is deleted with the \code{removeQ} function, or if network
#' communication with the Redis server encounters an error.
#'
#' @inheritParams worker
#' @param n number of workers to start.
#' @param Rbin full path to the command-line R program.
#' @importFrom redux redis_config hiredis
#' @importFrom base64enc base64encode
#' @return NULL is invisibly returned.
#' @seealso \code{\link{redux::redis_config}}, \code{\link{worker}}, \code{\link{removeQ}}
#' @examples
#' library(future.redis)
#' 
#' if (redux::redis_available()) {
#' ## The example assumes that a Redis server is running on the local host
#' ## and standard port.
#' 
#' # Register the redis plan on a specified task queue:
#' plan(redis, queue = "R jobs")
#' 
#' # Start some local R worker processes:
#' startLocalWorkers(n=2, queue="R jobs", linger=1)
#' 
#' # Alternatively, use the following to run the workers quietly without
#' # showing their output as they run:
#' # startLocalWorkers(n=2, queue="R jobs", linger=1, log="/dev/null")
#' 
#' # Run a simple sampling approximation of pi in parallel using  M * N points:
#' N <- 1e6  # samples per worker
#' M <- 10   # iterations
#' est <- Reduce(sum, Map(value, 
#'          replicate(M, future({4 * sum((runif(N) ^ 2 + runif(N) ^ 2) < 1) / N}))
#'        )) / M
#' print(est)
#' 
#' # Clean up
#' removeQ("R jobs")
#' }
#' @export
startLocalWorkers <- function(n, queue = "RJOBS",
  config = redis_config(), iter = Inf, linger = 10, log = NULL,
  Rbin = paste(R.home(component = "bin"), "R", sep="/"))
{
  args <- list(queue = queue, linger = linger, config = config,
               iter = iter, quit = TRUE, log = log)
  cmd <- sprintf("suppressMessages(require(future.redis, quietly = TRUE)); args <- unserialize(base64enc::base64decode('%s')); do.call('worker', args)",
           base64encode(serialize(args, NULL)))
  replicate(n, system2(Rbin, args = "-s --no-save",  input = cmd, wait=FALSE))
  invisible()
}
