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

ENV["GRUG_CHATTER_ENABLED"] = "false"

load_specimen_from_file!(SPEC_PATH)

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    return read_last_output()
end

# Run only the first few queries that lead up to "why does fire burn"
# in the same order as the expanded test
queries = [
    "what is fire",
    "what is water",
    "what is air",
    "what is earth",
    "what is sky",
    "why does fire burn",  # This is where gravity appeared
]

for q in queries
    result = run_mission(q)
    # Extract just the conversational part (before telemetry)
    ti = findfirst("--- DEBUG TELEMETRY", result)
    conv = ti !== nothing ? strip(result[1:first(ti)-1]) : strip(result)
    conv = strip(replace(conv, r"\n{3,}" => "\n\n"))
    println("Q: $q")
    println("A: $conv")
    println()
end
