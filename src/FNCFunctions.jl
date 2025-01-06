module FNCFunctions

export FNC
FNC = FNCFunctions

# Required by the package itself
using Polynomials
using OrdinaryDiffEq
using LinearAlgebra
using SparseArrays

include("chapter01.jl")
include("chapter02.jl")
include("chapter03.jl")
include("chapter04.jl")
include("chapter05.jl")
include("chapter06.jl")
include("chapter08.jl")
include("chapter09.jl")
include("chapter10.jl")
include("chapter11.jl")
include("chapter13.jl")

end  # module
