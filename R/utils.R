## Copied from the future package

## Assign globals to an specific environment and set that environment
## for functions.  If they are functions of namespaces/packages
## and exclude == "namespace", then the globals are not assigned
## Reference: https://github.com/HenrikBengtsson/future/issues/515
assign_globals <- function(envir, globals, exclude = getOption("future.assign_globals.exclude", c("namespace")), debug = getOption("future.debug", FALSE)) {
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
          if (debug) {
            mdebugf("- reassign environment for %s", sQuote(name))
            where[[name]] <- envir
            globals[[name]] <- global
          }
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