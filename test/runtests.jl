using Somoclu
using Base.Test

import Somoclu: distance

# Calling this method will suffice only in no OpenMPI cases.
# Julia otherwise expects a thread safe message passing for callbacks.
# This is an Euclidean distance estimate computed from Julia,
function distance(p1::Ptr{Cfloat}, p2::Ptr{Cfloat}, d::Cuint)
    s = Cfloat(0.0)
    for i = 1:d
        v = unsafe_load(p1, i) - unsafe_load(p2, i)
        s += v*v
    end
    return sqrt(s)::Cfloat
end


function deterministic_codebook(useCustomDistance=false)
    ncolumns, nrows = 2, 2
    initialcodebook = Array{Float32}(zeros(2, ncolumns*nrows))
    som = Som(ncolumns, nrows, initialcodebook=initialcodebook,
              useCustomDistance=useCustomDistance)
    println("hasOpenMP, useCustomDistance:$(som.hasOpenMP), $(som.useCustomDistance)")
    data = Array{Float32}([0.1 0.2; 0.3 0.4]);
    train!(som, data);
    correct_codebook = Array{Float32, 2}([0.15  0.126894  0.173106  0.15;
                                          0.35  0.326894  0.373106  0.35]);
    return sum(som.codebook - correct_codebook) < 10e-6
end

# write your own tests here
#@test deterministic_codebook()
deterministic_codebook(true)
