#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

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

# Run ONLY "how does fire work" in isolation
result = run_mission("how does fire work")
# Extract the conversational part
ti = findfirst("--- DEBUG TELEMETRY", result)
conv = ti !== nothing ? strip(result[1:first(ti)-1]) : strip(result)
println("CONVERSATIONAL OUTPUT:")
println(conv)
println()
# Show full output with telemetry
println("FULL OUTPUT:")
println(result)
