#' Remove a Redis-based work queue
#'
#' Redis keys beginning with the `queue` name are removed.
#' Removing the work queue signals to local and remote R workers to exit.
#'
#' @inheritParams RedisFuture
#'
#' @param queue Redis key name of the task queue (Redis list)
#'
#' @return NULL is silently returned (this function is evaluated for the
#' side-effect of altering Redis state).
#'
#' @importFrom redux redis_config hiredis
#' @export
removeQ <- function(queue = getOption("future.redis.queue", "{{session}}"), config = redis_config())
{
  queue <- redis_queue(queue)
  redis <- hiredis(config)

  # Redis keys used
  key_alive <- sprintf("%s.live", queue)

  ## Remove task queue liveness key
  redis[["DEL"]](key = key_alive)

  ## Remove all other keys for this queue
  all_keys <- redis[["KEYS"]](pattern = sprintf("%s.*", queue))
  Map(f = redis[["DEL"]], all_keys)
  
  invisible()
}


uncerealize <- function(x)
{
  if(!is.null(x) && is.raw(x)) unserialize(x) else x
}

#' Start a task liveness thread
#'
#' `setAlive()` and `delAlive()` support worker fault tolerance and are only
#' to be use internally by the package. It's safe to call `setAlive()` and
#' `delAlive()` multiple times; at most one copy of the liveness thread is run.
#'
#' @param port Redis port
#'
#' @param host Redis host name
#'
#' @param key The task liveness key to maintain
#'
#' @param password (optional) Redis password
#'
#' @return Invoked for the side-effect of maintaining a task liveness
#' key, `NULL` is invisibly returned.
#'
#' @keywords internal
setAlive <- function(port, host, key, password)
{
  if(missing(password)) password <- ""
  if(is.null(password)) password <- ""
  invisible(
    .Call(C_setAlive, as.integer(port), as.character(host),
        as.character(key), as.character(password), PACKAGE = .packageName))
}


#' End a task liveness thread
#'
#' `setAlive()` and `delAlive()` support worker fault tolerance and are
#' only to be use internally by the package. It's safe to call `delAlive()`
#' multiple times.
#'
#' @return Invoked for the side-effect of ending a maintenance thread for
#' a task liveness key, `NULL` is invisibly returned.
#'
#' @keywords internal
delAlive <- function()
{
  invisible(.Call(C_delAlive, PACKAGE = .packageName))
}


redis_queue <- function(queue) {
  stopifnot(
    length(queue) == 1L,
    is.character(queue),
    !is.na(queue),
    nzchar(queue)
  )

  ## Replace all {{...}} values one by one
  pattern <- "^([^}]*)[{][{]([^}]*)[}][}](.*)$"
  while (grepl(pattern, queue)) {
    what <- sub(pattern, "\\2", queue)
    if (what == "session") {
      session_uuid <- import_future("session_uuid")
      value <- session_uuid()
    } else if (what == "user") {
      value <- Sys.info()[["user"]]
    } else if (what == "hostname") {
      value <- Sys.info()[["nodename"]]
    } else {
      stop(sprintf("Unsupported Redis queue declaration: ", sQuote(queue)))
    }
    queue <- gsub(pattern, sprintf("\\1%s\\3", value), queue)
  }

  ## Add package prefix, iff missing
  if (!grepl(sprintf("^%s:", .packageName), queue)) {
    queue <- sprintf("%s:%s", .packageName, queue)
  }

  queue
}
