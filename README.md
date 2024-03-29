# future.redis: An Elastic Backend for the Future Package using Redis

## Description

The **[future]** package defines a simple and uniform way of evaluating R expressions asynchronously. Future "backend" packages implement asynchronous processing over various shared-memory and distributed systems.

[Redis] is a fast networked key/value database that includes a stack-like data structure (Redis "lists").  This feature makes Redis useful as a lightweight task queue manager for elastic distributed computing.

The **future.redis** package defines a simple elastic distributed computing backend for future using the **[redux]** package to communicate with Redis. Elastic means that workers can be added or removed at any time, including during a running computation. Elasticity implies partial fault-tolerance (to handle workers that go away during a running computation). This style of distributed computing is well-suited to modern cloud environments, and especially cloud spot markets.

Here is a quick example procedure for experimenting with **future.redis**:

1. Install Redis on your computer.
2. Install the **future.redis** package, e.g. `remotes::install_github("bwlewis/future.redis")`.
3. Start the Redis server running (see the [Redis documentation]). We assume that the server is running on the host "localhost" and port 6379 (the default Redis port). We assume in the examples below that the worker R processes and the coordinator are running on the same machine. In practice, they can of course run across a network.
4. See the `?redis` or `?future.redis` help pages in the package.


[future]: https://cran.r-project.org/package=future
[redux]: https://cran.r-project.org/package=redux
[Redis]: https://redis.io
[Redis documentation]: https://redis.io/docs/
