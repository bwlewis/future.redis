# .setAlive and .delAlive support worker fault tolerance
`.setAlive` <- function(port, host, key, password)
{
  if(missing(password)) password <- ""
  if(is.null(password)) password <- ""
  invisible(
    .Call(C_setAlive, as.integer(port), as.character(host),
        as.character(key), as.character(password), PACKAGE="future.redis"))
}

`.delAlive` <- function()
{
  invisible(.Call(C_delAlive, PACKAGE="future.redis"))
}
