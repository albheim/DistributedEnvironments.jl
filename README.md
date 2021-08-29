# DistributedEnvironments

This is a package to simplify using the distributed functionalities in julia by supplying a
way to synchronize the local environment to all workers.


It looks at the current environment and checks which packages have local paths associated with them.
It will copy all of those packages as well as the current `Project.toml` and `Manifest.toml` to the 
corresponding locations on the worker machines.

It then starts workers on each machine equal to the number of threads available on the current node.

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

## TODO

Currently it is a very simple implementation making some not perfect assumptions.

* Same directory structure needed on all nodes (allow for one structure on host and one on workers?)
* `rsync` exists on host and workers (allow for choise between scp/rsync other?)
* `julia` exists and will use that (allow to set julia executable)
* Checks `nthreads()` on host and start that many processes on each worker (use `:auto` for `addprocs`, but need to fix the precompile problems)

## Contributors

Mattias Fält and Johan Ruuskanen created a script doing distributed environment syncing at the Dept. of Control in Lund, and that was used as the base for this package.
