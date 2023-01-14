## The example assumes that a Redis server is running
## on the local host and the standard Redis port (6379)
if (redux::redis_available()) {

# Start two local R worker processes running in the background
workers <- startLocalWorkers(2L, linger = 1.0)

plan(redis)

# A function that returns a future, note that N uses lexical scoping...
f <- \() future({4 * sum((runif(N) ^ 2 + runif(N) ^ 2) < 1) / N}, seed = TRUE)

# Run a simple sampling approximation of pi in parallel using  M * N points:
N <- 1e6  # samples per worker
M <- 10   # iterations
pi_est <- Reduce(sum, Map(value, replicate(M, f()))) / M
print(pi_est)

# Make sure to stop the workers
stopLocalWorkers(workers)

}
