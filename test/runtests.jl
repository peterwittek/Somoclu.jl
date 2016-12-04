using Somoclu
using Base.Test

function deterministic_codebook()
    ncolumns, nrows = 2, 2;
    initialcodebook = Array{Float32}(zeros(2, ncolumns*nrows));
    som = Som(ncolumns, nrows, initialcodebook=initialcodebook);
    data = Array{Float32}([0.1 0.2; 0.3 0.4]);
    train!(som, data);
    correct_codebook = Array{Float32, 2}([0.15  0.126894  0.173106  0.15; 0.35  0.326894  0.373106  0.35]);
    return sum(som.codebook - correct_codebook) < 10e-6
end

# write your own tests here
@test deterministic_codebook()
