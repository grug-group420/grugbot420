#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

# Disable chatter
ENV["GRUG_CHATTER_ENABLED"] = "false"

load_specimen_from_file!(SPEC_PATH)

# Check node_18 before query
n18 = lock(NODE_LOCK) do
    get(NODE_MAP, "node_18", nothing)
end
if n18 !== nothing
    println("node_18 noun_anchors: ", n18.json_data["noun_anchors"])
    println("node_18 pattern: ", n18.pattern)
end

# Check node_6
n6 = lock(NODE_LOCK) do
    get(NODE_MAP, "node_6", nothing)
end
if n6 !== nothing
    println("node_6 noun_anchors: ", n6.json_data["noun_anchors"])
    println("node_6 pattern: ", n6.pattern)
end

# Run ONLY "why does fire burn" in isolation
function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    return read_last_output()
end

println("\n=== Running single query: why does fire burn ===")
result = run_mission("why does fire burn")
println(result)
