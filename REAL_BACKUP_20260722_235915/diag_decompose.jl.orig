#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
include("src/GrugBot420.jl")
using .GrugBot420: InputDecomposer

# Test decomposer directly
cfg = InputDecomposer.DecomposerConfig()

test_inputs = [
    "what is fire and what is water",
    "why does fire burn and why does water flow",
    "what is love and what is courage",
    "what is gravity and what is thermodynamics",
    "what is fire and what is water and what is earth",
]

for inp in test_inputs
    clauses = InputDecomposer.decompose(inp, cfg)
    println("Input: \"$inp\"")
    println("  Clauses: $clauses")
    println()
end
