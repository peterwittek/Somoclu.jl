module Somoclu

"""
    train(data::Array{Float32, 2}, nSomX, nSomY; <keyword arguments>)

Train a self-organizing map of size `nSomX`x`nSomY` on `data`.


# Arguments
* `compactsupport::Bool=false`: Cut off map updates beyond the training radius
                                with the Gaussian neighborhood.
* `epochs::Integer=10`: The number of epochs to train the map for.
* `gridtype::String="rectangular"`: Specify the grid form of the nodes:
                                    `"rectangular"` or `"hexagonal"`
* `kerneltype::Integer=0`: Specify which kernel to use: 0 for dense CPU kernel
                          or 1 for dense GPU kernel (if compiled with it).
* `maptype::String="planar"`: Specify the map topology: `"planar"` or `"toroid"`
* `neighborhood::String="gaussian"`: Specify the neighborhood function:
                                     `"gaussian"` or `"bubble"`.
* `radius0::Integer=0`: The initial radius on the map where the update happens
                       around a best matching unit. Default value of 0 will
                       trigger a value of min(n_columns, n_rows)/2.
* `radiusN::Integer=1`: The radius on the map where the update happens around a
                       best matching unit in the final epoch.
* `radiuscooling::String="linear"`: The cooling strategy between radius0 and
                                    radiusN: `"linear"` or `"exponential"`.
* `scale0::Float32=0.1`: The initial learning scale.
* `scaleN::Float32=0.01`: The learning scale in the final epoch.
* `scalecooling::String="linear"`: The cooling strategy between scale0 and
                                   scaleN: `"linear"` or `"exponential"`.

"""
function train(data::Array{Float32, 2}, nSomX, nSomY; epochs=10, radius0=0, radiusN=1, radiusCooling="linear", scale0=0.1, scaleN=0.01, scaleCooling="linear", kernelType=0, mapType="planar", gridType="square", compact_support=false, neighborhood="gaussian")
    nDimensions, nVectors = size(data)
    codebook = Array{Float32}(nDimensions, nSomX*nSomY);
    # These two lines trigger the C++ code to randomly initialize the codebook
    codebook[1, 1] = 1000.0
    codebook[2, 1] = 2000.0
    uMatrix, bmus = train!(codebook, data, nSomX, nSomY, epochs=epochs, radius0=radius0, radiusN=radiusN, radiusCooling=radiusCooling, scale0=scale0, scaleN=scaleN, scaleCooling=scaleCooling, kernelType=kernelType, mapType=mapType, gridType=gridType, compact_support=compact_support, neighborhood=neighborhood)
    return codebook, uMatrix, bmus
end

"""
    train!(codebook::Array{Float32, 2}, data::Array{Float32, 2}, nSomX, nSomY; <keyword arguments>)

Train a self-organizing map of size `nSomX`x`nSomY` on `data` given an initial
`codebook`.

The codebook will be updated during the training.

# Arguments
* `compactsupport::Bool=false`: Cut off map updates beyond the training radius
                                with the Gaussian neighborhood.
* `epochs::Integer=10`: The number of epochs to train the map for.
* `gridtype::String="rectangular"`: Specify the grid form of the nodes:
                                    `"rectangular"` or `"hexagonal"`
* `kerneltype::Integer=0`: Specify which kernel to use: 0 for dense CPU kernel
                          or 1 for dense GPU kernel (if compiled with it).
* `maptype::String="planar"`: Specify the map topology: `"planar"` or `"toroid"`
* `neighborhood::String="gaussian"`: Specify the neighborhood function:
                                     `"gaussian"` or `"bubble"`.
* `radius0::Integer=0`: The initial radius on the map where the update happens
                       around a best matching unit. Default value of 0 will
                       trigger a value of min(n_columns, n_rows)/2.
* `radiusN::Integer=1`: The radius on the map where the update happens around a
                       best matching unit in the final epoch.
* `radiuscooling::String="linear"`: The cooling strategy between radius0 and
                                    radiusN: `"linear"` or `"exponential"`.
* `scale0::Float32=0.1`: The initial learning scale.
* `scaleN::Float32=0.01`: The learning scale in the final epoch.
* `scalecooling::String="linear"`: The cooling strategy between scale0 and
                                   scaleN: `"linear"` or `"exponential"`.

"""
function train!(codebook::Array{Float32, 2}, data::Array{Float32, 2}, nSomX, nSomY; epochs=10, radius0=0, radiusN=1, radiusCooling="linear", scale0=0.1, scaleN=0.01, scaleCooling="linear", kernelType=0, mapType="planar", gridType="square", compact_support=false, neighborhood="gaussian")
    if radiusCooling == "linear"
        _radiusCooling = 0
    elseif radiusCooling == "exponential"
        _radiusCooling = 1
    else
        error("Unknown radius cooling")
    end
    if scaleCooling == "linear"
        _scaleCooling = 0
    elseif scaleCooling == "exponential"
        _scaleCooling = 1
    else
        error("Unknown scale cooling")
    end
    if mapType == "planar"
        _mapType = 0
    elseif mapType == "toroid"
        _mapType = 1
    else
        error("Unknown map type")
    end
    if gridType == "square"
        _gridType = 0
    elseif gridType == "hexagonal"
        _gridType = 1
    else
        error("Unknown grid type")
    end
    nDimensions, nVectors = size(data)
    bmus = Array{Cint}(nVectors*2);
    uMatrix = Array{Float32}(nSomX*nSomY);

    ccall((:julia_train, "libsomoclu.so"), Void, (Ptr{Float32}, Cint, Cuint, Cuint, Cuint, Cuint, Cuint, Cuint, Cuint, Cuint, Float32, Float32, Cuint, Cuint, Cuint, Cuint, Bool, Bool, Ptr{Float32}, Cint, Ptr{Cint}, Cint, Ptr{Float32}, Cint), reshape(data, length(data)), length(data), epochs, nSomX, nSomY, nDimensions, nVectors, radius0, radiusN, _radiusCooling, scale0, scaleN, _scaleCooling, kernelType, _mapType, _gridType, compact_support, neighborhood=="gaussian", reshape(codebook, length(codebook)), length(codebook), bmus, length(bmus), uMatrix, length(uMatrix))
    return reshape(bmus, 2, nVectors), reshape(uMatrix, nSomX, nSomY)
end

end
