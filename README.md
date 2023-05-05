<div id="badges"><!-- pkgdown markup -->
<img border="0" src="https://www.r-pkg.org/badges/version/future.redis" alt="CRAN check status"/>
<a href="https://github.com/HenrikBengtsson/future.redis/actions?query=workflow%3AR-CMD-check"><img border="0" src="https://github.com/HenrikBengtsson/future.redis/actions/workflows/R-CMD-check.yaml/badge.svg?branch=develop" alt="R CMD check status"/></a>
<a href="https://github.com/HenrikBengtsson/future.redis/actions?query=workflow%3Afuture_tests"><img border="0" src="https://github.com/HenrikBengtsson/future.redis/actions/workflows/future_tests.yaml/badge.svg?branch=develop" alt="future.tests checks status"/></a>
</div>


# future.redis: An Elastic Backend for the Future Package using Redis

## Description

The **[future]** package defines a simple and uniform way of
evaluating R expressions asynchronously. Future "backend" packages
implement asynchronous processing over various shared-memory and
distributed systems.

[Redis] is a fast networked key/value database that includes a
stack-like data structure (Redis "lists").  This feature makes Redis
useful as a lightweight task queue manager for elastic distributed
computing.

The **future.redis** package defines a simple elastic distributed
computing backend for future using the **[redux]** package to
communicate with Redis. Elastic means that workers can be added or
removed at any time, including during a running
computation. Elasticity implies partial fault-tolerance (to handle
workers that go away during a running computation). This style of
distributed computing is well-suited to modern cloud environments, and
especially cloud spot markets.

The **future.redis** package fullfills the [Future API Backend
Specification].  This is validated using the **[future.tests]** (Test
Suite for 'Future API' Backends) package.


## Example: Hello world

To try out **future.redis** for the first time,

1. make sure [Redis] and **future.redis** are installed, and

2. if not already running, start the Redis server (see the [Redis
   documentation]).  You can verify it's running by calling
   `redux::redis_available()`.

Then, launch R, and try the following code:

```r
library(future.redis)

## Start two future.redis parallel workers
workers <- startLocalWorkers(2)

## Use them for futures
plan(redis)

## Create a future that calculates the sum of 1:100
f <- future(sum(1:100))
v <- value(f)
print(v)
## [1] 5050

## Stop the local workers
stopLocalWorkers(workers)
```

You should also get 5050.  If it stalls when you call `value()`, make
sure you did indeed start the parallel workers first.

For more information and examples, see `?future.redis::future.redis`.


## Requirements

The **future.redis** package requires that [Redis] is installed on the
machine.  Redis is available on all modern operating systems,
including Linux, macOS, and MS Windows.
   

## Installation

The **future.redis** package is only available from GitHub. To install
it, and all of its dependencies, call:

```r
remotes::install_github("bwlewis/future.redis")
```


[future]: https://cran.r-project.org/package=future
[future.tests]: https://cran.r-project.org/package=future.tests
[Future API Backend Specification]: https://future.futureverse.org/articles/future-6-future-api-backend-specification.html
[redux]: https://cran.r-project.org/package=redux
[Redis]: https://redis.io
[Redis documentation]: https://redis.io/docs/
