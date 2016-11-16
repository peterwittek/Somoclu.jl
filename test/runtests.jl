using Somoclu
using Base.Test

function deterministic_codebook()
    ncolumns, nrows = 2, 2;
    codebook = Array{Float32}(zeros(2, ncolumns*nrows));
    data = Array{Float32}([0.1 0.2; 0.3 0.4]);
    bmus, umatrix = train!(codebook, data, ncolumns, nrows);
    correct_codebook = Array{Float32, 2}([0.15  0.126894  0.173106  0.15; 0.35  0.326894  0.373106  0.35]);
    return sum(codebook - correct_codebook) < 10e-8
end

# write your own tests here
@test deterministic_codebook()
