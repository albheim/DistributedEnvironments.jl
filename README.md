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

@everywhere using SomePackage
...
```
For example, one could run hyperparameter optimization using the `@phyperopt` macro from [Hypteropt.jl](https://github.com/baggepinnen/Hyperopt.jl)
```julia
... # As above
@everywhere using Hyperopt, Flux, MLDatasets, Statistics
@everywhere MNIST.download(i_accept_the_terms_of_use=true)

ho = @phyperopt for i=100, fun = [tanh, σ, relu], units = [16, 64, 256], hidden = 1:5, epochs = 1:7
    train_x, train_y = MNIST.traindata()
    test_x,  test_y  = MNIST.testdata()
    model = Chain([
        flatten; Dense(784, units, fun);
        [Dense(units, units, fun) for _ in 1:hidden];
        Dense(units, 10); softmax;
    ]...)
    loss(data) = Flux.Losses.mse(model(data.x), data.y)
    Flux.@epochs epochs Flux.train!(
        loss, 
        Flux.params(model), 
        Flux.DataLoader((x=train_x, y=Flux.onehotbatch(train_y, 0:9)), batchsize=16, shuffle=true), 
        ADAM()
    )
    mean(Flux.onecold(model(test_x), 0:9) .== test_y)
end
```

## TODO

Currently it is a very simple implementation making some not perfect assumptions.

* Same directory structure needed on all nodes (allow for one structure on host and one on workers?)
* `rsync` exists on host and workers (allow for choise between scp/rsync other?)
* `julia` exists and will use that (allow to set julia executable)
* Check if we can create a SSHManager object and keep that alive to have acces to individual machines, would allow for either running `@everywhere` or something like `@allmachines` to only run once on each machine (downloading dataset, precompiling)

## Contributors

Mattias Fält and Johan Ruuskanen created a script doing distributed environment syncing at the Dept. of Automatic Control in Lund, and that was used as the base for this package.
