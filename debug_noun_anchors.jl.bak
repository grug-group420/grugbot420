#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    load_specimen_from_file!,
    NODE_MAP, NODE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")
load_specimen_from_file!(SPEC_PATH)

# Check node_18 noun_anchors at runtime
node_18 = lock(() -> get(NODE_MAP, "node_18", nothing), NODE_LOCK)
if !isnothing(node_18)
    na = get(node_18.json_data, "noun_anchors", String[])
    sp = get(node_18.json_data, "system_prompt", "")
    println("node_18 noun_anchors: $na")
    println("node_18 system_prompt: $sp")
    println("node_18 pattern: $(node_18.pattern)")
else
    println("node_18 not found!")
end

# Also check node_6
node_6 = lock(() -> get(NODE_MAP, "node_6", nothing), NODE_LOCK)
if !isnothing(node_6)
    na = get(node_6.json_data, "noun_anchors", String[])
    println("node_6 noun_anchors: $na")
    println("node_6 pattern: $(node_6.pattern)")
end

# Check all nodes with "gravity" in noun_anchors
println("\nAll nodes with 'gravity' in noun_anchors:")
all_nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)
for n in all_nodes
    na = get(n.json_data, "noun_anchors", String[])
    if !isempty(na) && any(x -> lowercase(strip(string(x))) == "gravity", na)
        println("  $(n.id): pattern='$(n.pattern)', noun_anchors=$na")
    end
end
