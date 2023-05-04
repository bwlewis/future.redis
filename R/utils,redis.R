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
