module DistributedEnvironments

export @initcluster

using Distributed, Pkg


"""
    @initcluster ips

Takes a list of ip-strings and sets up the current environment on these machines.
The machines should be reachable using ssh from the machine running the command.
The setup will copy the local project and manifest files as well as copying all
packages that are added to the env using `dev` to corresponding location on the 
remote machines.

Needs to be called from top level since the macro includes imports.

# Example
```julia
using RemoteSync, Distributed

ips = ["10.0.0.1", "10.0.0.2"]
@initcluster ips

@everywhere using SomePackage
...
"""
macro initcluster(nodes)
    return _initcluster(nodes)
end

function _initcluster(nodes)
    quote
        cluster = collect($(esc(nodes)))

        # Cleanup?
        # rmprocs(workers())

        # Sync local packages and environment files to all nodes
        synchronize(cluster)

        addprocs(
            map(node -> (node, 1), cluster), 
            # map(node -> (node, :auto), cluster), 
            topology=:master_worker, 
            tunnel=true, 
            max_parallel=length(cluster), 
        ) 

        # Activate and instantiate on all targets
        @everywhere import Pkg
        @everywhere Pkg.activate($(Pkg.project().path))
        @everywhere Pkg.instantiate()

        cores = length(Sys.cpu_info())
        addprocs(
            map(node -> (node, cores - 1), cluster), 
            topology=:master_worker, 
            tunnel=true, 
            max_parallel=cores*length(cluster), 
        ) 
        @everywhere import Pkg
        @everywhere Pkg.activate($(Pkg.project().path))
    end
end

function synchronize(cluster)
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
    if isfile(path)
        run(`rsync -e ssh $(path) $(target):$(path)`) # Copy
    else
        run(`rsync -re ssh --delete $(path)/ $(target):$(path)`) # Copy
    end
end

# function scp(path, target)
#     dir = isfile(path) ? dirname(path) : path
#     run(`ssh -q -t $(target) mkdir -p $(dir)`) # Make sure path exists
#     run(`ssh -q -t $(target) rm -rf $(path)`) # Delete old
#     run(`scp -r -q $(path) $(target):$(path)`) # Copy
# end
# 
# function status(cluster::Vector{String})
#     calc_cpu = "awk '{u=\$2+\$4; t=\$2+\$4+\$5; if (NR==1){u1=u; t1=t;} else print (\$2+\$4-u1) * 100 / (t-t1) \"%\"; }' <(grep 'cpu ' /proc/stat) <(sleep 1;grep 'cpu ' /proc/stat)"
# 
#     connection_error = []
#     for node in cluster
#         printstyled("Checking machine $(node):\n", bold=true, color=:magenta)
#         try
#             run(`ssh -q -t $(m) who \&\& $calc_cpu \&\& nproc`)
#         catch
#             connection_error = vcat(connection_error, node)
#         end
#     end
# 
#     if !isempty(connection_error)
#         println("Failed to connect to the following machines:") for node in connection_error
#             println("\t $(node)")
#         end
#     end
# end


end
