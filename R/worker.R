#' Start a Redis worker process loop
#'
#' The worker process blocks for tasks on the specified queue (a Redis list).
#' The worker continues to process tasks from the queue untile the queue
#' liveness key is removed (see [removeQ()]), the number of
#' processed tasks reaches the `iter` limit, or until a Redis
#' communication or other error occurs; after which the worker exits (quits R).
#'
#' @inheritParams RedisFuture
#'
#' @param queue Redis task queue name.
#'
#' @param linger in seconds, max time before system checks (including
#' termination).
#'
#' @param iter Maximum number of tasks to acquire before exiting.
#'
#' @param quit if TRUE, quit R on exit.
#'
#' @param log divert stdout and messages to log file.
#'
#' @return After conclusion of the worker loop, either R exits or NULL
#' is silently returned.
#'
#' @importFrom redux redis_config hiredis
#' @export
worker <- function(queue = "RJOBS",
                   linger = 10.0,
                   config = redis_config(),
                   iter = Inf,
                   quit = FALSE,
                   log = nullfile())
{
  debug <- getOption("future.redis.debug", FALSE)
  if (debug) {
    mdebug("future.redis::worker() ...")
    on.exit(mdebug("future.redis::worker() ... done"), add = TRUE)
    mdebug("Arguments:")
    mstr(list(
      queue = queue, linger = linger, config = config, iter = iter,
      quit = quit, log = log
    ))
  }
  
  if(quit) {
    on.exit(quit(save = "no"), add = TRUE)
  }

  if(isTRUE(is.character(log)) && isTRUE(nchar(log) > 0)) {
    if (tolower(log) %in% c("/dev/null", "nil:")) log <- nullfile()
    mdebugf("Sinking standard output and standard error to %s", log)
    f <- file(log, open = "w+")
    sink(f, append = TRUE)                   ## stdout
    sink(f, append = TRUE, type = "message") ## stderr
    on.exit({
      sink()
      sink(type = "message")
      close(f)
    }, add = TRUE)
  }
  
  msg <- tryCatch({
    mdebug("Processing 'future.redis' jobs ...")
    on.exit(mdebug("Processing 'future.redis' jobs ... done"), add = TRUE)
    
    N <- 0.0
    redis <- hiredis(config)
    
    # Set task queue liveness key
    key_live <- sprintf("%s.live", queue)
    redis[["SET"]](key = key_live, value = "")
    
    while(isTRUE(N < iter)) {
      mdebugf("%s worker (PID=%d) waiting for next task #%g", .packageName, Sys.getpid(), N)
      taskid <- redis[["BRPOP"]](key = queue, timeout = linger)[[2]]
      if(!is.null(taskid)) {
        mdebugf("Retrieved task #%g (%s)", N, taskid)
        N <- N + 1
        processTask(task = sprintf("%s.%s", queue, taskid), redis = redis)
      }
      
      # Check for queue liveness key, worker exit if missing
      if(!redis[["EXISTS"]](key = key_live)) {
        mdebugf("Shutting down %s::worker()", .packageName)
        stop(sprintf("%s::worker() terminated", .packageName))
      }
    }

    sprintf("%s::worker() processed %g tasks", .packageName, iter)
  }, error = function(e) {
    conditionMessage(e)
  })
  
  mdebug(msg)
}

#' Process a task
#'
#' @param task A Redis key containing the future to process.
#'
#' @param redis A [redux::redis_api] object as returned by [redux::hiredis()]
#' connection.
#'
#" @return Nothing.
#'
#' @keywords internal
#' @importFrom future getExpression
processTask <- function(task, redis)
{
  stopifnot(
    length(task) == 1L, !is.na(task), is.character(task), nzchar(task),
    inherits(redis, "redis_api")
  )
  
  on.exit(delAlive())

  ## Get Future object, if available
  future <- tryCatch({
    uncerealize(redis[["GET"]](key = task))
  }, error = function(e) NULL)
  if(is.null(future)) return()
  
  mdebugf("Obtained future %s", task)

  ## Redis keys used
  key_prefix <- sprintf("%s.%s", future[["queue"]], future[["taskid"]])
  key_alive <- sprintf("%s.live", key_prefix)
  key_status <- sprintf("%s.status", key_prefix)
  key_output_queue <- future[["output_queue"]]
  
  # Set ephemeral (5.0s) task liveness key
  redis[["SET"]](key = key_alive, value = "OK")
  redis[["EXPIRE"]](key = key_alive, seconds = 5.0)
  
  # Start thread to maintain task liveness key in background
  config <- redis[["config"]]()
  setAlive(port = config[["port"]],
           host = config[["host"]],
           key = key_alive,
           password = config[["password"]])
           
  # Update task queue status
  redis[["SET"]](key = key_status, value = "running")

  # Process the future, first attaching required packages (if any)
  for(p in future[["packages"]]) {
    library(p, character.only = TRUE, quietly = TRUE)
  }

  # Evaluate the future
  ans <- eval(getExpression(future), envir = future[["envir"]])
  
  # Detach packages
  for(p in future[["packages"]]) {
    tryCatch(detach(sprintf("package:%s", p), character.only = TRUE), error = invisible)
  }
  
  # Submit result if task status key exists, otherwise discard
  if(redis[["EXISTS"]](key = key_status)) {
    mdebugf("Submitting result to %s %s", key_output_queue, ans[["finished"]])
    redis[["LPUSH"]](key = key_output_queue, serialize(ans, NULL))
    redis[["SET"]](key = key_status, value = "finished")
  }
}



#' Start one or more background R worker processes on the local system.
#'
#' Use `startLocalWorkers()` to start one or more **future.redis** R worker
#' processes in the background. The worker processes are started on the local
#' system using the [worker()] function.
#'
#' Running workers self-terminate after a `linger` interval if their task
#' queue is deleted with the [removeQ()] function, or if network
#' communication with the Redis server encounters an error.
#'
#' @inheritParams worker
#'
#' @param n number of workers to start.
#'
#' @param Rbin full path to the command-line R program.
#'
#' @return NULL is invisibly returned.
#'
#' @seealso [redux::redis_config()], [worker()], [removeQ()]
#' @examples
#' if (redux::redis_available()) {
#' ## The example assumes that a Redis server is running on the local host
#' ## and standard port.
#' 
#' # Register the redis plan on a specified task queue:
#' plan(redis, queue = "R jobs")
#' 
#' # Start some local R worker processes:
#' startLocalWorkers(n=2, queue="R jobs", linger=1.0)
#' 
#' # Alternatively, use the following to run the workers quietly without
#' # showing their output as they run:
#' # startLocalWorkers(n=2, queue="R jobs", linger=1.0, log="/dev/null")
#' 
#' # A function that returns a future (note the scope of N)
#' f <- \() future({4 * sum((runif(N) ^ 2 + runif(N) ^ 2) < 1) / N}, seed = TRUE)
#' 
#' # Run a simple sampling approximation of pi in parallel using  M * N points:
#' N <- 1e6  # samples per worker
#' M <- 10   # iterations
#' pi_est <- Reduce(sum, Map(value, replicate(M, f()))) / M
#' print(pi_est)
#' 
#' # Clean up
#' removeQ("R jobs")
#' }
#'
#' @importFrom redux redis_config
#' @importFrom base64enc base64encode
#' @export
startLocalWorkers <- function(n, queue = "RJOBS",
  config = redis_config(), iter = Inf, linger = 10.0, log = nullfile(),
  Rbin = paste(R.home(component = "bin"), "R", sep="/"))
{
  stopifnot(
    length(n) == 1L, !is.na(n), is.numeric(n), n >= 1,
    length(iter) == 1L, !is.na(iter), is.numeric(iter), iter >= 1,
    length(linger) == 1L, !is.na(linger), is.numeric(linger), linger >= 0.0
  )

  ## Arguments for future.redis::worker()
  ## FIXME: Pass most or all of this as command-line arguments to
  ## make it easier to identify them from 'ps' output /HB 2023-01-14
  worker_args <- list(
    queue = queue,      ## character scalar
    linger = linger,    ## numeric scalar
    config = config,    ## WARNING: might expose a password
    iter = iter,        ## numeric scalar
    quit = TRUE,        ## logical
    log = log           ## character string
  )
  worker_args <- serialize(worker_args, connection = NULL)
  worker_args <- base64encode(worker_args)
  code <- sprintf("args <- unserialize(base64enc::base64decode('%s')); do.call(future.redis::worker, args)", worker_args)
  args <- c("-s", "--no-save", "-e", shQuote(code))
  replicate(n, system2(Rbin, args = args, wait=FALSE))
  invisible()
}
