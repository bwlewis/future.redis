% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/redis.R
\name{removeQ}
\alias{removeQ}
\title{Remove a Redis-based work queue}
\usage{
removeQ(
  queue = getOption("future.redis.queue", "{{session}}"),
  config = redis_config()
)
}
\arguments{
\item{queue}{Redis key name of the task queue (Redis list)}

\item{config}{Redis config}
}
\value{
NULL is silently returned (this function is evaluated for the
side-effect of altering Redis state).
}
\description{
Redis keys beginning with the \code{queue} name are removed.
Removing the work queue signlas to local and remote R workers to exit.
}
