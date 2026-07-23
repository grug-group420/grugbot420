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

for input in ["why does fire burn", "why is sky blue"]
    input_signal = words_to_signal(input)
    nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)
    results = []
    for node in nodes
        node.is_grave && continue
        node.is_image_node && continue
        conf = _scan_confidence_for_node(input_signal, input, node, 1)
        conf > 0.25 && push!(results, (node.id, node.pattern, conf))
    end
    sort!(results, by=x -> x[3], rev=true)
    println("\n=== '$input' (above 0.25) ===")
    for (id, pat, conf) in results[1:min(10, length(results))]
        jd = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        sp = isnothing(jd) ? "" : get(jd.json_data, "system_prompt", "")
        na = isnothing(jd) ? [] : get(jd.json_data, "noun_anchors", [])
        println("  $id: pattern=\"$pat\" conf=$(round(conf, digits=3)) na=$na sp=\"$(sp[:80])\"")
    end
end
