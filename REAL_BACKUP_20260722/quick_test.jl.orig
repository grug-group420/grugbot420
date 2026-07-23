#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    return read_last_output()
end

# Load specimen
load_specimen_from_file!(SPEC_PATH)

# Test queries
queries = [
    "what is fire",
    "what is water", 
    "tell me about rocks",
    "why does fire burn",
    "why is sky blue",
    "how does grug think",
    "hello",
    "what is 2 plus 2",
]

for q in queries
    result = run_mission(q)
    # Extract conversational part
    conv = result
    ti = findfirst("--- DEBUG TELEMETRY", result)
    if ti !== nothing
        conv = strip(result[1:first(ti)-1])
    end
    println("Q: $q")
    println("A: $conv")
    println()
end
