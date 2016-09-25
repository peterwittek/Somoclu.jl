# Somoclu

[![Build Status](https://travis-ci.org/peterwittek/Somoclu.jl.svg?branch=master)](https://travis-ci.org/peterwittek/Somoclu.jl)
[![Coverage Status](https://coveralls.io/repos/peterwittek/Somoclu.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/peterwittek/Somoclu.jl?branch=master)
[![codecov.io](http://codecov.io/github/peterwittek/Somoclu.jl/coverage.svg?branch=master)](http://codecov.io/github/peterwittek/Somoclu.jl?branch=master)

Somoclu.jl - Julia Interface for Somoclu
========================================

Somoclu is a massively parallel implementation of self-organizing maps. It relies on OpenMP for multicore execution and it can be accelerated by CUDA. The topology of map is either planar or toroid, the grid is rectangular or hexagonal.

Key features of the Julia interface:

- Fast execution by parallelization: OpenMP and CUDA are supported.
- Planar and toroid maps.
- Rectangular and hexagonal grids.
- Gaussian or bubble neighborhood functions.

Usage
-----
A simple example is as follows.

```julia
using Somoclu

nSomX, nSomY = 40, 30;
nDimensions, nVectors = 2, 20;
c1 = Array{Float32}(rand(nDimensions, nVectors));
c2 = Array{Float32}(rand(nDimensions, nVectors));
c2[1, :] = c2[1, :] .+ 0.2;
c2[2, :] = c2[1, :] .+ 0.5;
c3 = Array{Float32}(rand(nDimensions, nVectors));
c3[1, :] = c3[1, :] .+ 0.4;
c3[2, :] = c3[1, :] .+ 0.1;
data = hcat(c1, c2, c3);

codebook, bmus, uMatrix = Somoclu.train(data, nSomX, nSomY, mapType="toroid");
```

Citation
--------

1. Peter Wittek, Shi Chao Gao, Ik Soo Lim, Li Zhao (2015). Somoclu: An Efficient Parallel Library for Self-Organizing Maps. `arXiv:1305.1422 <http://arxiv.org/abs/1305.1422>`_.
