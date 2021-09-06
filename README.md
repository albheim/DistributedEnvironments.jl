# DistributedEnvironments

This package provides a simple way to sync a local development environment to a cluster of workers using the distributed functionalities in julia. 

The main functionality is exported through the macro `@initcluster` which takes a list of machines accessible through ssh using keys (see `addprocs` in `Distributed.jl` for more information).
It looks at the active environment and takes packages with local paths associated to them, i.e. `dev` packages,
as well as the `Project.toml` and `Manifest.toml` and copies them to the corresponding locations on the added machines.

Each machine then have workers equal to the number of the available threads added, and the environment is activated for each of them. 

It also export the `@everywhere` macro from `Distributed.jl` as well as a `@eachmachine` macro that is similar to `@everywhere` but runs
the command only once for each machine which can be useful for things that the workers on one machine can share such as precompilation or
downloading datasets.

## Installation

Currently it is not registred so you can install it with the url.
```julia
] add https://github.com/albheim/DistributedEnvironments.jl
```

## Example

Make sure the current active environment is the one that should be copied.

```julia
using DistributedEnvironments

nodes = ["10.0.0.1", "otherserver"]
@initcluster nodes

@everywhere using SomePackage
...
```

For example, one could run hyperparameter optimization using the `@phyperopt` macro from [Hypteropt.jl](https://github.com/baggepinnen/Hyperopt.jl)
```julia
... # Initial setup as above
@everywhere using Hypteropt, Flux, MLDatasets, Statistics
@eachmachine MNIST.download(i_accept_the_terms_of_use=true)

ho = @phyperopt for i=100, fun = [tanh, σ, relu], units = [16, 64, 256], hidden = 1:5, epochs = 1:7
    # Read data (already downloaded)
    train_x, train_y = MNIST.traindata()
    test_x,  test_y  = MNIST.testdata()
    # Create model based on optimization parameters
    model = Chain([
        flatten; 
        Dense(784, units, fun);
        [Dense(units, units, fun) for _ in 1:hidden];
        Dense(units, 10); 
        softmax;
    ]...)
    loss(data) = Flux.Losses.mse(model(data.x), data.y)
    # Train
    Flux.@epochs epochs Flux.train!(
        loss, 
        Flux.params(model), 
        Flux.DataLoader((x=train_x, y=Flux.onehotbatch(train_y, 0:9)), batchsize=16, shuffle=true), 
        ADAM()
    )
    # Return test score
    mean(Flux.onecold(model(test_x), 0:9) .== test_y)
end
```

## TODO

Currently it is a very simple implementation making some not perfect assumptions.

* Same directory structure needed on all nodes for now
    * Allow for supplying a `project` folder which all dev packages and env files are added to. Modify Manifest to update paths. Could be problematic with nested packages?
* `rsync` exists on host and workers (allow for choise between scp/rsync other?)
* rsync with multicast?
* Allow to set addprocs keywords, such as julia executable, env vars...?
* Check for julia, otherwise suggest installation?
* Check if we can create a SSHManager object and keep that alive to have acces to individual machines, would allow for either running `@everywhere` or something like `@allmachines` to only run once on each machine (downloading dataset, precompiling)
* Should it rather reexport `Distributed` since it will likely never be used without it?
* So far no testing, but not really sure how to do that in a good way since the only functionality needs ssh and other machines...

## Contributors

Mattias Fält and Johan Ruuskanen created a script for doing distributed environment syncing at the Dept. of Automatic Control in Lund which was used as the base for this package.
