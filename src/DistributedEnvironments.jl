module DistributedEnvironments

export @initcluster, @eachmachine, @everywhere

using Distributed, Pkg, MacroTools


"""
Allows for kwargs with macro, looks for additional args and splits them on =
"""
function preprocess_args(args)
    kwargs = Dict{Symbol, Any}()
    for arg in args
        @capture(arg, param_ = value_) || throw(ArgumentError("wrong syntax for argument $(arg)"))
        kwargs[param] = value
    end
    kwargs
end


"""
    @initcluster ips [worker_procs=:auto] [sync=true] [status=false]

Takes a list of ip-strings and sets up the current environment on these machines.
The machines should be reachable using ssh from the machine running the command.
The setup will copy the local project and manifest files as well as copying all
packages that are added to the env using `dev` to corresponding location on the 
remote machines.

Additional arguments:
* `worker_procs` - Integer or :auto (default), how many workers are added on each machine.
* `sync` - Whether or not to sync the local environment (default is `true`) before adding the workers.
* `status` - Whether or not to show a short status (current users, cpu utilization, julia version) for each machine and remove any machine that does not connect. Default is `false`.

Needs to be called from top level since the macro includes imports.

# Example
```julia
using DistributedEnvironments

ips = ["10.0.0.1", "10.0.0.2"]
@initcluster ips

@everywhere using SomePackage
...
"""
macro initcluster(nodes, args...)
    kwargs = preprocess_args(args)
    return _initcluster(nodes; kwargs...)
end

function _initcluster(nodes; status=false, sync=true, worker_procs=:auto)
    quote
        cluster = collect($(esc(nodes)))

        length(cluster) > 0 || throw(ArgumentError("no servers supplied, nodes=$cluster"))

        # 1 is host, if it is in workers it is the only one. Otherwise remove all workers.
        if 1 ∉ workers()
            rmprocs(workers())
        end

        # Check status of machines
        $(status) && status(cluster)

        # Sync and instantiate (does precompilation)
        if $(sync)
            # Sync local packages and environment files to all nodes
            sync_env(cluster)

            # Add single worker on each machine to precompile
            addprocs(
                map(node -> (node, 1), cluster), 
                topology = :master_worker, 
                tunnel = true, 
                exeflags = "--project=$(Base.active_project())",
                max_parallel = length(cluster), 
            ) 

            # Instantiate environment on all machines
            @everywhere begin
                import Pkg
                Pkg.instantiate()
            end

            # Remove precompile workers
            # TODO should be able to keep them and add the right amount, maybe SSHManager?
            # Or maybe not, good to have restart of all machines after precompile since sometimes it hangs there.
            rmprocs(workers())
        end

        # Add one worker per thread on each node in the cluster
        addprocs(
            map(node -> (node, $(worker_procs)), cluster), 
            topology=:master_worker, 
            tunnel=true, 
            exeflags = "--project=$(Base.active_project())",
            max_parallel=24*length(cluster), # TODO what should this be?
        ) 
        println("All workers initialized.")
    end
end

"""
    @eachmachine expr

Similar to `@everywhere`, but only runs on one worker per machine.
Can be used for things like precompiling, downloading datasets or similar.
"""
macro eachmachine(expr)
    return _eachmachine(expr)
end

function _eachmachine(expr)
    machinepids = unique(id -> Distributed.get_bind_addr(id), procs())
    quote 
        @everywhere $machinepids $expr
    end
end

function sync_env(cluster)
    proj_path = dirname(Pkg.project().path)
    deps = Pkg.dependencies()
    # (:name, :version, :tree_hash, :is_direct_dep, :is_pinned, :is_tracking_path, :is_tracking_repo, :is_tracking_registry, :git_revision, :git_source, :source, :dependencies)

    for node in cluster
        printstyled("Replicating local environment on machine $(node):\n", bold=true, color=:magenta)

        println("Copying environment files to target:")
        println("\tProject.toml")
        rsync("$(proj_path)/Project.toml", node)
        println("\tManifest.toml")
        rsync("$(proj_path)/Manifest.toml", node)

        println("Copying local projects to target:")
        for (id, package) in deps
            if package.is_tracking_path
                println("\t$(package.name)")
                rsync(package.source, node)
            end
        end
    end
end

function rsync(path, target)
    run(`ssh -q -t $(target) mkdir -p $(dirname(path))`) # Make sure path exists
    if isfile(path)
        run(`rsync -e ssh $(path) $(target):$(path)`) # Copy
    else
        run(`rsync -re ssh --delete $(path)/ $(target):$(path)`) # Copy
    end
end

function scp(path, target)
    dir = isfile(path) ? dirname(path) : path
    run(`ssh -q -t $(target) mkdir -p $(dir)`) # Make sure path exists
    run(`ssh -q -t $(target) rm -rf $(path)`) # Delete old
    run(`scp -r -q $(path) $(target):$(path)`) # Copy
end
 
function status(cluster::Vector{String})
    calc_cpu = "awk '{u=\$2+\$4; t=\$2+\$4+\$5; if (NR==1){u1=u; t1=t;} else print (\$2+\$4-u1) * 100 / (t-t1) \"%\"; }' <(grep 'cpu ' /proc/stat) <(sleep 1;grep 'cpu ' /proc/stat)"

    connection_error = []
    for node in cluster
        printstyled("Checking machine $(node):\n", bold=true, color=:magenta)
        try
            run(`ssh -q -t $(node) who \&\& $calc_cpu \&\& julia --version`)
        catch
            connection_error = vcat(connection_error, node)
        end
    end

    filter!(x -> x ∉ connection_error, cluster)

    if !isempty(connection_error)
        println("Failed to connect to the following machines:") 
        for node in connection_error
            println("\t $(node)")
        end
    end
end


end
