#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    load_specimen_from_file!, scan_specimens, words_to_signal,
    _scan_confidence_for_node, _lexical_overlap_confidence,
    NODE_MAP, NODE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")
load_specimen_from_file!(SPEC_PATH)

input = "what is fire"
input_signal = words_to_signal(input)
nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)

results = []
for node in nodes
    node.is_grave && continue
    node.is_image_node && continue
    sig_conf = _scan_confidence_for_node(input_signal, input, node, 1)
    lex_conf = _lexical_overlap_confidence(input, node)
    if sig_conf > 0.1 || lex_conf > 0.1
        push!(results, (node.id, node.pattern, sig_conf, lex_conf, max(sig_conf, lex_conf)))
    end
end

sort!(results, by=x -> x[5], rev=true)
println("Top 20 nodes for input='$input':")
for (id, pat, sig, lex, best) in results[1:min(20, length(results))]
    println("  $id: pattern=\"$pat\" sig_conf=$(round(sig, digits=3)) lex_conf=$(round(lex, digits=3)) best=$(round(best, digits=3))")
end
