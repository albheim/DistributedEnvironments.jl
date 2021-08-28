# DistributedEnvironments

This is a package to simplify using the distributed functionalities in julia by supplying a
way to synchronize the local environment to all workers.

## Installation

Currently it is not registred so you can install it with the url.
```julia
] add https://github.com/albheim/DistributedEnvironments.jl
```

## Example

Setup assumes you are in the environment you want to clone and you have `DistributedEnvironments` installed.

```julia
using Distributed, DistributedEnvironments

nodes = ["10.0.0.1", "otherserver"]
@initcluster nodes

# As long as SomePackage was in the local environment this should now work
@everywhere using SomePackage 
...
```

If you are in a REPL and want to rerun this after some changes, 
you should remove all workers first so they can be synced and re-added.

```julia
julia> rmprocs(workers())
Task (done) ...

julia> @initcluster nodes 
```

## Notes

Currently it is a very simple implementation which assumes some things which could be improved.
* Same directory structure can be created on workers
* `rsync` exists on host and workers
* `julia` exists and will use that
* Checks `nthreads()` on host and start that many processes on each worker