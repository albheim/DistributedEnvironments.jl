# DistributedEnvironments

This is a package to simplify using the distributed functionalities in julia by supplying a
way to synchronize the local environment to all workers.

## Installation

Currently it is not registred so you can install it with the url.
```julia
] add https://github.com/albheim/DistributedEnvironments.jl
```

## Example

```julia
using Distributed, DistributedEnvironments

nodes = ["10.0.0.1", "otherserver"]
@initcluster nodes

# As long as SomePackage was in the local environment this should now work
@everywhere using SomePackage 
...
```

## Notes

Currently it is a very simple implementation which assumes some things which could be improved.
* Same directory structure can be created on workers
* `rsync` exists on host and workers
* `julia` exists and will use that
* Checks `nthreads()` on host and start that many processes on each worker