__precompile__(true)

module Somoclu

using BinDeps

export train, train!

if isfile(joinpath(dirname(@__FILE__),"..","deps","deps.jl"))
    include("../deps/deps.jl")
else
    error("Somoclu not properly installed. Please run Pkg.build(\"Somoclu\")")
end

"""
    train(data::Array{Float32, 2}, ncolumns, nrows; <keyword arguments>)

Train a self-organizing map of size `ncolumns`x`nrows` on `data`.


# Arguments
* `compactsupport::Bool=true`: Cut off map updates beyond the training radius
                                with the Gaussian neighborhood.
* `epochs::Integer=10`: The number of epochs to train the map for.
* `gridtype::String="rectangular"`: Specify the grid form of the nodes:
                                    `"rectangular"` or `"hexagonal"`
* `kerneltype::Integer=0`: Specify which kernel to use: 0 for dense CPU kernel
                          or 1 for dense GPU kernel (if compiled with it).
* `maptype::String="planar"`: Specify the map topology: `"planar"` or `"toroid"`
* `neighborhood::String="gaussian"`: Specify the neighborhood function:
                                     `"gaussian"` or `"bubble"`.
* `stdCoeff::Float32=0.5`: Coefficient in the Gaussian neighborhood function
                           exp(-||x-y||^2/(2*(coeff*radius)^2))
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
function train(data::Array{Float32, 2}, ncolumns, nrows; epochs=10, radius0=0, radiusN=1, radiuscooling="linear", scale0=0.1, scaleN=0.01, scalecooling="linear", kerneltype=0, maptype="planar", gridtype="square", compactsupport=true, neighborhood="gaussian", stdCoeff=0.5)
    nDimensions, nVectors = size(data)
    codebook = Array{Float32}(nDimensions, ncolumns*nrows);
    # These two lines trigger the C++ code to randomly initialize the codebook
    codebook[1, 1] = 1000.0
    codebook[2, 1] = 2000.0
    umatrix, bmus = train!(codebook, data, ncolumns, nrows, epochs=epochs, radius0=radius0, radiusN=radiusN, radiuscooling=radiuscooling, scale0=scale0, scaleN=scaleN, scalecooling=scalecooling, kerneltype=kerneltype, maptype=maptype, gridtype=gridtype, compactsupport=compactsupport, neighborhood=neighborhood, stdCoeff=stdCoeff)
    return codebook, umatrix, bmus
end

"""
    train!(codebook::Array{Float32, 2}, data::Array{Float32, 2}, ncolumns, nrows; <keyword arguments>)

Train a self-organizing map of size `ncolumns`x`nrows` on `data` given an initial
`codebook`.

The codebook will be updated during the training.

# Arguments
* `compactsupport::Bool=true`: Cut off map updates beyond the training radius
                                with the Gaussian neighborhood.
* `epochs::Integer=10`: The number of epochs to train the map for.
* `gridtype::String="rectangular"`: Specify the grid form of the nodes:
                                    `"rectangular"` or `"hexagonal"`
* `kerneltype::Integer=0`: Specify which kernel to use: 0 for dense CPU kernel
                          or 1 for dense GPU kernel (if compiled with it).
* `maptype::String="planar"`: Specify the map topology: `"planar"` or `"toroid"`
* `neighborhood::String="gaussian"`: Specify the neighborhood function:
                                     `"gaussian"` or `"bubble"`.
* `stdCoeff::Float32=0.5`: Coefficient in the Gaussian neighborhood function
                           exp(-||x-y||^2/(2*(coeff*radius)^2))
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
function train!(codebook::Array{Float32, 2}, data::Array{Float32, 2}, ncolumns, nrows; epochs=10, radius0=0, radiusN=1, radiuscooling="linear", scale0=0.1, scaleN=0.01, scalecooling="linear", kerneltype=0, maptype="planar", gridtype="square", compactsupport=true, neighborhood="gaussian", stdCoeff=0.5)
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
    if maptype == "planar"
        _maptype = 0
    elseif maptype == "toroid"
        _maptype = 1
    else
        error("Unknown map type")
    end
    if gridtype == "square"
        _gridtype = 0
    elseif gridtype == "hexagonal"
        _gridtype = 1
    else
        error("Unknown grid type")
    end
    nDimensions, nVectors = size(data)
    bmus = Array{Cint}(nVectors*2);
    umatrix = Array{Float32}(ncolumns*nrows);

    # Note that ncolumns and nrows are swapped because Julia is column-first
    ccall((:julia_train, libsomoclu), Void, (Ptr{Float32}, Cint, Cuint, Cuint, Cuint, Cuint, Cuint, Float32, Float32, Cuint, Float32, Float32, Cuint, Cuint, Cuint, Cuint, Bool, Bool, Float32, Ptr{Float32}, Cint, Ptr{Cint}, Cint, Ptr{Float32}, Cint), reshape(data, length(data)), length(data), epochs, nrows, ncolumns, nDimensions, nVectors, radius0, radiusN, _radiuscooling, scale0, scaleN, _scalecooling, kerneltype, _maptype, _gridtype, compactsupport, neighborhood=="gaussian", stdCoeff, reshape(codebook, length(codebook)), length(codebook), bmus, length(bmus), umatrix, length(umatrix))
    bmus = reshape(bmus, 2, nVectors)
    bmus[1, :], bmus[2, :] = bmus[2, :], bmus[1, :];
    return bmus, reshape(umatrix, nrows, ncolumns)
end

end
