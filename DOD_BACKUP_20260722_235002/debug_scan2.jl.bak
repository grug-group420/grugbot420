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

input = "what is fire"
input_signal = words_to_signal(input)
nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)

results = []
for node in nodes
    node.is_grave && continue
    node.is_image_node && continue
    sig_conf = _scan_confidence_for_node(input_signal, input, node, 1)
    lex_conf = _lexical_overlap_confidence(input, node)
    push!(results, (node.id, node.pattern, sig_conf, lex_conf, max(sig_conf, lex_conf)))
end

sort!(results, by=x -> x[5], rev=true)

# Find node_100
for (id, pat, sig, lex, best) in results
    if id == "node_100"
        println("node_100: pattern=\"$pat\" sig_conf=$(round(sig, digits=3)) lex_conf=$(round(lex, digits=3)) best=$(round(best, digits=3))")
        # Find its rank
        rank = findfirst(x -> x[1] == "node_100", results)
        println("node_100 rank: $rank / $(length(results))")
    end
end

# Show all nodes with any lexical overlap
println("\nNodes with lexical overlap > 0:")
for (id, pat, sig, lex, best) in results
    if lex > 0.0
        println("  $id: pattern=\"$pat\" sig=$(round(sig, digits=3)) lex=$(round(lex, digits=3))")
    end
end

println("\nSCAN_CONFIDENCE_LOCK = $SCAN_CONFIDENCE_LOCK")
