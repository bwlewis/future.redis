% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/worker.R
\name{worker}
\alias{worker}
\title{Start a Redis worker process loop}
\usage{
worker(
  queue = getOption("future.redis.queue", "{{session}}"),
  linger = 10,
  config = redis_config(),
  iter = Inf,
  quit = FALSE,
  log = NULL
)
}
\arguments{
\item{queue}{Redis task queue name.}

\item{linger}{in seconds, max time before system checks (including termination).}

\item{config}{Redis configuration (see \code{\link{redis_config}})).}

\item{iter}{Maximum number of tasks to acquire before exiting.}

\item{quit}{if TRUE, quit R on exit.}

\item{log}{divert stdout and messages to log file.}
}
\value{
After conclusion of the worker loop, either R exits or NULL
is silently returned.
}
\description{
The worker process blocks for tasks on the specified queue (a Redis list).
The worker continues to process tasks from the queue untile the queue
liveness key is removed (see \code{\link{removeQ}}), the number of
processed tasks reaches the \code{iter} limit, or until a Redis
communication or other error occurs; after which the worker exits (quits R).
}
