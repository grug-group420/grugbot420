#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    extract_relational_triples, extract_dynamic_relational_triples,
    SemanticVerbs

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")
load_specimen_from_file!(SPEC_PATH)

test_inputs = [
    "why does fire burn",
    "how does fire work",
    "what is love",
    "why is sky blue",
    "why does water flow",
]

for input in test_inputs
    basic = extract_relational_triples(input)
    dynamic = extract_dynamic_relational_triples(input, 1)
    println("Input: '$input'")
    println("  Basic triples: $basic")
    println("  Dynamic triples (mode=1): $dynamic")
    
    # Also check what normalize_synonyms does
    norm = SemanticVerbs.normalize_synonyms(input)
    println("  Normalized: '$norm'")
    println()
end
