[![Build Status](https://travis-ci.org/peterwittek/Somoclu.jl.svg?branch=master)](https://travis-ci.org/peterwittek/Somoclu.jl)
[![Win status](https://ci.appveyor.com/api/projects/status/12dpu5p5e5wb2fwr?svg=true)](https://ci.appveyor.com/project/peterwittek/somoclu-jl)
[![Coverage Status](https://coveralls.io/repos/github/peterwittek/Somoclu.jl/badge.svg?branch=master)](https://coveralls.io/github/peterwittek/Somoclu.jl?branch=master)
[![codecov.io](http://codecov.io/github/peterwittek/Somoclu.jl/coverage.svg?branch=master)](http://codecov.io/github/peterwittek/Somoclu.jl?branch=master)

Somoclu.jl - Julia Interface for Somoclu
========================================

[Somoclu](https://github.com/peterwittek/somoclu) is a massively parallel implementation of self-organizing maps. It relies on OpenMP for multicore execution and it can be accelerated by CUDA. The topology of map is either planar or toroid, the grid is rectangular or hexagonal.

Key features of the Julia interface:

- Fast execution by parallelization: OpenMP and CUDA are supported.
- Planar and toroid maps.
- Rectangular and hexagonal grids.
- Gaussian or bubble neighborhood functions.
- PCA initialization of the codebook.

Usage
-----
A simple example is as follows.

```julia
using Somoclu

ncolumns, nrows = 40, 30;
ndimensions, nvectors = 2, 50;
c1 = Array{Float32}(rand(ndimensions, nvectors) ./ 5);
c2 = Array{Float32}(rand(ndimensions, nvectors) ./ 5 .+ [0.2; 0.5]);
c3 = Array{Float32}(rand(ndimensions, nvectors) ./ 5 .+ [0.4; 0.1]);
data = hcat(c1, c2, c3);
som = Som(ncolumns, nrows, maptype="toroid")
train!(som, data);
```

Then you can plot the result with a plotting package of your choice. For example:
```julia
using PyPlot
class_colors = vcat(["red" for _=1:50], ["blue" for _=1:50], ["green" for _=1:50]);
imshow(som.umatrix, cmap="Spectral_r")
scatter(som.bmus[1, :], som.bmus[2, :], c=class_colors)
```

Citation
--------

1. Peter Wittek, Shi Chao Gao, Ik Soo Lim, Li Zhao (2015). Somoclu: An Efficient Parallel Library for Self-Organizing Maps. [arXiv:1305.1422](http://arxiv.org/abs/1305.1422).
