#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    load_specimen_from_file!,
    _scan_confidence_for_node,
    _lexical_overlap_confidence,
    words_to_signal,
    NODE_MAP,
    NODE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

load_specimen_from_file!(SPEC_PATH)

# Get all nodes and compute scan confidence for "why does fire burn"
input_text = "why does fire burn"
input_signal = words_to_signal(input_text)

nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)

results = []
for node in nodes
    node_id = node.id
    pattern = node.pattern
    node.is_grave && continue
    node.is_image_node && continue
    
    # Compute lexical overlap
    lex_conf = _lexical_overlap_confidence(input_text, node)
    
    # Compute full scan confidence
    scan_conf = _scan_confidence_for_node(input_signal, input_text, node, 1)
    
    if scan_conf > 0.0 || lex_conf > 0.05
        push!(results, (node_id, pattern, lex_conf, scan_conf))
    end
end

sort!(results, by=x -> x[4], rev=true)

println("Top 15 nodes by scan_confidence for 'why does fire burn':")
println("  ID        | Pattern                         | LexConf | ScanConf")
println("  ----------|---------------------------------|---------|--------")
for (nid, pat, lc, sc) in results[1:min(15, length(results))]
    println("  $(rpad(nid, 10))| $(rpad(pat, 33))| $(rpad(string(round(lc, digits=3)), 8))| $(round(sc, digits=3))")
end
