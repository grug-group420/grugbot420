#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    load_specimen_from_file!, scan_specimens, words_to_signal,
    _scan_confidence_for_node, _lexical_overlap_confidence,
    NODE_MAP, NODE_LOCK, SCAN_CONFIDENCE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")
load_specimen_from_file!(SPEC_PATH)

input = "what is water"
input_signal = words_to_signal(input)
nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)
results = []
for node in nodes
    node.is_grave && continue
    node.is_image_node && continue
    conf = _scan_confidence_for_node(input_signal, input, node, 1)
    conf > 0.0 && push!(results, (node.id, node.pattern, conf))
end
sort!(results, by=x -> x[3], rev=true)
println("ALL nodes with conf > 0 for 'what is water':")
for (id, pat, conf) in results
    println("  $id: pattern=\"$pat\" conf=$(round(conf, digits=3))")
end
