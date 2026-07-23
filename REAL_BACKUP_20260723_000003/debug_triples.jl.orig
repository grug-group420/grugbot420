#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    load_specimen_from_file!,
    extract_relational_triples,
    extract_dynamic_relational_triples,
    words_to_signal,
    screen_input_complexity

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

load_specimen_from_file!(SPEC_PATH)

# Test triple extraction for several inputs
test_inputs = [
    "why does fire burn",
    "what is fire",
    "what is water",
    "why is sky blue",
    "how does grug think",
    "what is 2 plus 2",
]

for input in test_inputs
    println("Input: '$input'")
    basic_triples = extract_relational_triples(input)
    println("  Basic triples: $basic_triples")
    sig = words_to_signal(input)
    mode = screen_input_complexity(sig, basic_triples)
    dynamic_triples = extract_dynamic_relational_triples(input, mode)
    println("  Dynamic triples (mode=$mode): $dynamic_triples")
    println()
end
