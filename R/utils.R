## Copied from the future package
## Assign globals to an specific environment and set that environment
## for functions.  If they are functions of namespaces/packages
## and exclude == "namespace", then the globals are not assigned
## Reference: https://github.com/HenrikBengtsson/future/issues/515
assign_globals <- function(envir, globals, exclude = getOption("future.assign_globals.exclude", c("namespace"))) {
  if(!isTRUE(is.environment(envir))) stop("invalid argument")
  if(!isTRUE(is.list(globals))) stop("invalid argument")
  if (length(globals) == 0L) return(envir)

  exclude_namespace <- ("namespace" %in% exclude)
  names <- names(globals)
  where <- attr(globals, "where")
  for (name in names) {
    global <- globals[[name]]
    if (exclude_namespace) {
      e <- environment(global)
      if (!inherits_from_namespace(e)) {
        w <- where[[name]]
        ## FIXME: Can we remove this?
        ## Here I'm just being overly conservative ## /HB 2021-06-15
        if (identical(w, emptyenv())) {
          environment(global) <- envir
        }
      }
    }
    envir[[name]] <- global
  }
  invisible(envir)
}

inherits_from_namespace <- function(env) {
  while (!identical(env, emptyenv())) {
    if (is.null(env)) return(TRUE) ## primitive functions, e.g. base::sum()
    if (isNamespace(env)) return(TRUE)
    if (identical(env, globalenv())) return(FALSE)
    env <- parent.env(env)
  }
  FALSE
}

uncerealize <- function(x)
{
  if(!is.null(x) && is.raw(x)) unserialize(x) else x
}

#' Start a task liveness thread
#'
#' setAlive and delAlive support worker fault tolerance and are only to be
#' use internally by the package. It's safe to call setAlive and delAlive
#' multiple times; at most one copy of the liveness thread is run.
#' @param port Redis port
#' @param host Redis host name
#' @param key The task liveness key to maintain
#' @param password (optional) Redis password
#' @return Invoked for the side-effect of maintaining a task liveness
#' key, \code{NULL} is invisibly returned.
#' @keywords internal
`setAlive` <- function(port, host, key, password)
{
  if(missing(password)) password <- ""
  if(is.null(password)) password <- ""
  invisible(
    .Call(C_setAlive, as.integer(port), as.character(host),
        as.character(key), as.character(password), PACKAGE = "future.redis"))
}

#' End a task liveness thread
#'
#' setAlive and delAlive support worker fault tolerance and are only to be
#' use internally by the package. It's safe to call delAlive multiple times.
#' @return Invoked for the side-effect of ending a maintenance thread for
#'  a task liveness key, \code{NULL} is invisibly returned.
#' @keywords internal
`delAlive` <- function()
{
  invisible(.Call(C_delAlive, PACKAGE="future.redis"))
}


now <- function(x = Sys.time(), format = "[%H:%M:%OS3] ") {
  ## format(x, format = format) ## slower
  format(as.POSIXlt(x, tz = ""), format = format)
}

mdebug <- function(..., prefix = now(), debug = getOption("future.debug", FALSE)) {
  if (!debug) return()
  message(prefix, ...)
}

mdebugf <- function(..., appendLF = TRUE,
                    prefix = now(), debug = getOption("future.debug", FALSE)) {
  if (!debug) return()
  message(prefix, sprintf(...), appendLF = appendLF)
}
