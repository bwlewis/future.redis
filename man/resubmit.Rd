% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RedisFuture-class.R
\name{resubmit}
\alias{resubmit}
\title{Re-submit a future to the task queue}
\usage{
resubmit(future, redis)
}
\arguments{
\item{future}{An object of class RedisFuture.}

\item{redis}{A redux Redis connection.}
}
\value{
If the number of retries is less than or equal to the maximum number of retries,
then the re-submitted future is invisibly returned. Otherwise NULL is returned.
}
\description{
Re-submit a future to the task queue
}
\keyword{internal}
