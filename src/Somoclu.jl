__precompile__(true)

module Somoclu

using BinDeps
using MultivariateStats: PCA, fit, principalvars, projection

export Som, train!

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

"""
type Som
    ncolumns::Int
    nrows::Int
    kerneltype::Int
    maptype::String
    gridtype::String
    compactsupport::Bool
    neighborhood::String
    stdcoeff::Float32
    initialization::String
    codebook::Array{Float32, 2}
    bmus::Array{Cint, 2}
    umatrix::Array{Float32, 2}
    function Som(ncolumns, nrows; kerneltype=0, maptype="planar", 
        gridtype="square", compactsupport=true, neighborhood="gaussian", 
        stdcoeff=0.5, initialization="random", initialcodebook=nothing)
        if maptype != "planar" && maptype != "toroid"
            error("Unknown map type!")
        elseif gridtype != "square" && gridtype != "hexagonal"
            error("Unknown grid type!")
        elseif neighborhood != "gaussian" && neighborhood != "bubble"
            error("Unknown neighborhood function!")
        elseif initialization != "random" && initialization != "pca"
            error("Unknown initialization!")
        elseif kerneltype != 0 && kerneltype != 1
            error("Unsupported kernel type!")
        end
        if initialcodebook != nothing
            new(ncolumns, nrows, kerneltype, maptype, gridtype, compactsupport,
            neighborhood, stdcoeff, initialization, initialcodebook)
        else
            new(ncolumns, nrows, kerneltype, maptype, gridtype, compactsupport,
            neighborhood, stdcoeff, initialization)
        end
    end
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
    if radiuscooling == "linear"
        _radiuscooling = 0
    elseif radiuscooling == "exponential"
        _radiuscooling = 1
    else
        error("Unknown radius cooling")
    end
    if scalecooling == "linear"
        _scalecooling = 0
    elseif scalecooling == "exponential"
        _scalecooling = 1
    else
        error("Unknown scale cooling")
    end
    if som.maptype == "planar"
        _maptype = 0
    elseif som.maptype == "toroid"
        _maptype = 1
    end
    if som.gridtype == "square"
        _gridtype = 0
    elseif som.gridtype == "hexagonal"
        _gridtype = 1
    end
    bmus = Array{Cint}(nVectors*2);
    umatrix = Array{Float32}(som.ncolumns*som.nrows);
    # Note that som.ncolumns and som.nrows are swapped because Julia is column-first
    ccall((:julia_train, libsomoclu), Void, (Ptr{Float32}, Cint, Cuint, Cuint, Cuint, Cuint, Cuint, Float32, Float32, Cuint, Float32, Float32, Cuint, Cuint, Cuint, Cuint, Bool, Bool, Float32, Ptr{Float32}, Cint, Ptr{Cint}, Cint, Ptr{Float32}, Cint), reshape(data, length(data)), length(data), epochs, som.nrows, som.ncolumns, nDimensions, nVectors, radius0, radiusN, _radiuscooling, scale0, scaleN, _scalecooling, som.kerneltype, _maptype, _gridtype, som.compactsupport, som.neighborhood=="gaussian", som.stdcoeff, reshape(som.codebook, length(som.codebook)), length(som.codebook), bmus, length(bmus), umatrix, length(umatrix))
    som.umatrix = reshape(umatrix, som.nrows, som.ncolumns);
    som.bmus = reshape(bmus, 2, nVectors)
    som.bmus[1, :], som.bmus[2, :] = som.bmus[2, :], som.bmus[1, :];
    return nothing
end

end
