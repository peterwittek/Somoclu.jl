__precompile__(true)

module Somoclu

using BinDeps
using MultivariateStats: PCA, fit, principalvars, projection
using Base: AsyncCondition

export Som, train!, distance

if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
    include("../deps/deps.jl")
else
    error("Somoclu not properly installed. Please run Pkg.build(\"Somoclu\")")
end

function OpenMPSupported()
    retval = false
    try
        retval = cglobal((:update_messages, libsomoclu)) != C_NULL
    catch
    end
    retval && throw(ErrorException("OpenMP version is not supported."))
    return retval
end

"""
    Som(ncolumns, nrows; <keyword arguments>)

Self-organizing map of size `ncolumns`x`nrows`.

# Arguments
* `compactsupport::Bool=true`: Cut off map updates beyond the training radius
                                with the Gaussian neighborhood.
* `gridtype::String="rectangular"`: Specify the grid form of the nodes:
                                    `"rectangular"` or `"hexagonal"`
* `initialcodebook::Array{32, 2}=nothing`: Specify an initial codebook.
* `initialization::String="random"`: Specify the codebook initialization:
                                     `"random"` or `"pca"`.
* `kerneltype::Integer=0`: Specify which kernel to use: 0 for dense CPU kernel
                          or 1 for dense GPU kernel (if compiled with it).
* `maptype::String="planar"`: Specify the map topology: `"planar"` or `"toroid"`
* `neighborhood::String="gaussian"`: Specify the neighborhood function:
                                     `"gaussian"` or `"bubble"`.
* `stdcoeff::Float32=0.5`: Coefficient in the Gaussian neighborhood function
                           exp(-||x-y||^2/(2\*(coeff\*radius)^2))
* `verbose::Integer=0p`: Specify verbosity: 0, 1, or 2.
"""
mutable struct Som
    ncolumns::Int
    nrows::Int
    kerneltype::Int
    maptype::String
    gridtype::String
    compactsupport::Bool
    neighborhood::String
    stdcoeff::Float32
    verbose::Int
    hasOpenMP::Bool
    useCustomDistance::Bool
    initialization::String
    codebook::Array{Float32, 2}
    bmus::Array{Cint, 2}
    umatrix::Array{Float32, 2}

    function Som(ncolumns, nrows; kerneltype=0, maptype="planar",
        gridtype="square", compactsupport=true, neighborhood="gaussian",
        stdcoeff=0.5, verbose=0, hasOpenMP=OpenMPSupported(),
        useCustomDistance=false, initialization="random", initialcodebook=nothing)

        maptype != "planar"        && maptype != "toroid" &&
            error("Unknown map type!")
        gridtype != "square"       && gridtype != "hexagonal" &&
            error("Unknown grid type!")
        neighborhood != "gaussian" && neighborhood != "bubble" &&
            error("Unknown neighborhood function!")
        initialization != "random" && initialization != "pca" &&
            error("Unknown initialization!")
        kerneltype != 0            && kerneltype != 1 &&
            error("Unsupported kernel type!")
        verbose < 0                && verbose > 2 &&
            error("Unsupported verbosity level!")

        if initialcodebook != nothing
            new(ncolumns, nrows, kerneltype, maptype, gridtype, compactsupport,
            neighborhood, stdcoeff, verbose, hasOpenMP, useCustomDistance, initialization,
            initialcodebook)
        else
            new(ncolumns, nrows, kerneltype, maptype, gridtype, compactsupport,
            neighborhood, stdcoeff, verbose, hasOpenMP, useCustomDistance, initialization)
        end
    end
end

release(cond::AsyncCondition) = close(cond) #try; close(cond); catch; end
release(cond) = 0

distance(p1::Ptr{Cfloat}, p2::Ptr{Cfloat}, d::Cuint) = Cfloat(0.0)::Cfloat

function get_parameters(context::Ptr{Void})
    dim = unsafe_load(Ptr{Cuint}(context))
    p1 = Ptr{Cfloat}(context + Core.sizeof(Cuint))::Ptr{Cfloat}
    p2 = (p1 + Core.sizeof(Ptr{Cfloat}))::Ptr{Cfloat}
    pr = (p2 + Core.sizeof(Ptr{Cfloat}))::Ptr{Cfloat}
    return dim, p1, p2, pr
end

sizeof_message() = Core.sizeof(Cuint) + 2*Core.sizeof(Ptr{Cfloat}) + Core.sizeof(Cfloat)

next_message(msg) = unsafe_load(Ptr{Void}(msg + sizeof_message()))::Ptr{Void}

function nothreads_distance(context::Ptr{Void})
    dim, p1, p2, pr = get_parameters(context)
    r = distance(p1, p2, dim)
    unsafe_store!(pr, r)
    return r::Cfloat
end

function __init__()
    global const fdist_nt_c = cfunction(nothreads_distance, Cfloat, (Ptr{Void}, ))
end

function threads_distance(cond::AsyncCondition)
    println("I am here in threads")
    #=
    # All the messages which needs to be processed have been received. So remove them
    # from the synchronization object for further compuations. New messages attached
    # do not have to track which messages are resolved.
    msgs = ccall((:detach_messages, libsomoclu), Ptr{Void}, (Ptr{Void}, ), cond.handle)
    msgs == C_NULL && return 0
    iter = msgs
    count = 0
    while true
        count += 1
        nothreads_distance(iter)
        iter = next_message(iter)
        iter == msgs && break
    end
    println("Total nodes: $count")
    ccall((:update_messages, libsomoclu), Void, (Ptr{Void}, ), msgs)
    =#
    return 0
end

"""
    train!(som::Som, data::Array{Float32, 2}; <keyword arguments>)

Train a self-organizing map `som` on `data`.

The som will be updated during training.

# Arguments
* `epochs::Integer=10`: The number of epochs to train the map for.
* `radius0::Float32=0`: The initial radius on the map where the update happens
                       around a best matching unit. Default value of 0 will
                       trigger a value of min(n_columns, n_rows)/2.
* `radiusN::Float32=1`: The radius on the map where the update happens around a
                       best matching unit in the final epoch.
* `radiuscooling::String="linear"`: The cooling strategy between radius0 and
                                    radiusN: `"linear"` or `"exponential"`.
* `scale0::Float32=0.1`: The initial learning scale.
* `scaleN::Float32=0.01`: The learning scale in the final epoch.
* `scalecooling::String="linear"`: The cooling strategy between scale0 and
                                   scaleN: `"linear"` or `"exponential"`.

"""
function train!(som::Som, data::Array{Float32, 2}; epochs=10, radius0=0, radiusN=1, radiuscooling="linear", scale0=0.1, scaleN=0.01, scalecooling="linear")
    nDimensions, nVectors = size(data)
    if som.initialization == "random"
        som.codebook = Array{Float32}(nDimensions, som.ncolumns*som.nrows);
        # These two lines trigger the C++ code to randomly initialize the codebook
        som.codebook[1, 1] = 1000.0
        som.codebook[2, 1] = 2000.0
    elseif som.initialization == "pca"
        coord = zeros(Float32, som.ncolumns*som.nrows, 2);
        for i = 1:som.ncolumns*som.nrows
            coord[i, 1] = div(i-1, som.ncolumns)
            coord[i, 2] = rem(i-1, som.ncolumns)
        end
        coord = coord ./ [som.nrows-1 som.ncolumns-1];
        coord = 2*(coord - .5);
        me = mean(data, 2);
        M = fit(PCA, data.-me; maxoutdim=2);
        eigval = principalvars(M);
        eigvec = projection(M);
        norms = [norm(eigvec[:, i]) for i in 1:2];
        eigvec = ((eigvec' ./ norms) .* eigval)'
        som.codebook = repeat(me, outer=[1, som.ncolumns*som.nrows])
        for j = 1:som.ncolumns*som.nrows
            for i = 1:2
                som.codebook[:, j] = som.codebook[:, j] + coord[j, i] * eigvec[:, i]
            end
        end
    else
        error("Unknown initialization method")
    end
    _radiuscooling = radiuscooling == "linear"      ? 0 :
                     radiuscooling == "exponential" ? 1 :
                     error("Unknown radius cooling")

    _scalecooling  = scalecooling == "linear"       ? 0 :
                     scalecooling == "exponential"  ? 1 :
                     error("Unknown scale cooling")

    _maptype       = som.maptype == "planar"        ? 0 :
                     som.maptype == "toroid"        ? 1 :
                     error("Unknown map type!")

    _gridtype      = som.gridtype == "square"       ? 0 :
                     som.gridtype == "hexagonal"    ? 1 :
                     error("Unknown grid type!")

    bmus = Array{Cint}(nVectors*2);
    umatrix = Array{Float32}(som.ncolumns*som.nrows);

    global fdist_nt_c

    cond = nothing
    fp = !som.useCustomDistance ? C_NULL :
         !som.hasOpenMP         ? fdist_nt_c:
                                  (cond = AsyncCondition(threads_distance); cond)

    println(fp)
    println(cond)

    # Note that som.ncolumns and som.nrows are swapped because Julia is column-first
    ccall((:julia_train, libsomoclu), Void,
          (Ptr{Float32}, Cint, Cuint, Cuint, Cuint, Cuint, Cuint, Float32, Float32, Cuint,
           Float32, Float32, Cuint, Cuint, Cuint, Cuint, Bool, Bool, Float32, Cuint,
           Ptr{Float32}, Cint, Ptr{Cint}, Cint, Ptr{Float32}, Cint, Ptr{Void}),
          reshape(data, length(data)), length(data), epochs, som.nrows, som.ncolumns,
          nDimensions, nVectors, radius0, radiusN, _radiuscooling, scale0, scaleN,
          _scalecooling, som.kerneltype, _maptype, _gridtype, som.compactsupport,
          som.neighborhood=="gaussian", som.stdcoeff, som.verbose, reshape(som.codebook,
          length(som.codebook)), length(som.codebook), bmus, length(bmus), umatrix,
          length(umatrix), fp)

    release(cond)

    som.umatrix = reshape(umatrix, som.nrows, som.ncolumns);
    som.bmus = reshape(bmus, 2, nVectors)
    som.bmus[1, :], som.bmus[2, :] = som.bmus[2, :]+1, som.bmus[1, :]+1;
    return nothing
end

end
