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
    useCustomDistance::Bool
    initialization::String
    codebook::Array{Float32, 2}
    bmus::Array{Cint, 2}
    umatrix::Array{Float32, 2}

    function Som(ncolumns, nrows; kerneltype=0, maptype="planar",
        gridtype="square", compactsupport=true, neighborhood="gaussian",
        stdcoeff=0.5, verbose=0, useCustomDistance=false, initialization="random",
        initialcodebook=nothing)

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
            neighborhood, stdcoeff, verbose, useCustomDistance, initialization,
            initialcodebook)
        else
            new(ncolumns, nrows, kerneltype, maptype, gridtype, compactsupport,
            neighborhood, stdcoeff, verbose, useCustomDistance, initialization)
        end
    end
end

distance(p1::Ptr{Cfloat}, p2::Ptr{Cfloat}, d::Cuint) = Cfloat(0.0)::Cfloat

function get_parameters(context::Ptr{Void})
    pr = Ptr{Cfloat}(context)::Ptr{Cfloat}
    dim = unsafe_load(Ptr{Cuint}(context + Core.sizeof(Cfloat)))::Cuint
    p1a = Ptr{Ptr{Cfloat}}(pr + Core.sizeof(Cfloat) + Core.sizeof(Cuint))::Ptr{Ptr{Cfloat}}
    p2a = (p1a + Core.sizeof(Ptr{Cfloat}))::Ptr{Ptr{Cfloat}}
    p1 = unsafe_load(p1a)
    p2 = unsafe_load(p2a)
    rem = Ptr{Void}(p2a + Core.sizeof(Ptr{Cfloat}))::Ptr{Void}
    return dim, p1, p2, pr, rem
end

function nothreads_distance(context::Ptr{Void})
    dim, p1, p2, pr, ignore = get_parameters(context)
    r = distance(p1, p2, dim)
    unsafe_store!(pr, r)
    return r::Cfloat
end

function __init__()
    global const fdist_nt_c = cfunction(nothreads_distance, Cfloat, (Ptr{Void}, ))
    global mt_data_map = Dict{AsyncCondition, Ref{Ptr{Void}}}()
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

    fp = !som.useCustomDistance ? C_NULL : fdist_nt_c

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

    som.umatrix = reshape(umatrix, som.nrows, som.ncolumns);
    som.bmus = reshape(bmus, 2, nVectors)
    som.bmus[1, :], som.bmus[2, :] = som.bmus[2, :]+1, som.bmus[1, :]+1;
    return nothing
end

end
