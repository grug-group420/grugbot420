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
    Node

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

load_specimen_from_file!(SPEC_PATH)

# Get all nodes and compute scan confidence for "why does fire burn"
input_text = "why does fire burn"
input_signal = GrugBot420._float_hash_vector(input_text)

results = []
for node in GrugBot420.SPECIMEN_NODES
    node_id = node.id
    pattern = node.pattern
    
    # Compute lexical overlap
    lex_conf = _lexical_overlap_confidence(input_text, node)
    
    # Compute full scan confidence
    scan_conf = _scan_confidence_for_node(input_signal, input_text, node, 1)
    
    if scan_conf > 0.0 || lex_conf > 0.0
        push!(results, (node_id, pattern, lex_conf, scan_conf))
    end
end

sort!(results, by=x -> x[4], rev=true)

println("Top 15 nodes by scan_confidence for 'why does fire burn':")
println("  ID        | Pattern                    | LexConf | ScanConf")
println("  ----------|----------------------------|---------|--------")
for (nid, pat, lc, sc) in results[1:min(15, length(results))]
    println("  $(rpad(nid, 10))| $(rpad(pat, 28))| $(rpad(string(round(lc, digits=3)), 8))| $(round(sc, digits=3))")
end
