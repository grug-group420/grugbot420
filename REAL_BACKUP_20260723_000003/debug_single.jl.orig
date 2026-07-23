#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    ChatterMode

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    return read_last_output()
end

load_specimen_from_file!(SPEC_PATH)

# Test with chatter disabled
ENV["GRUG_CHATTER_ENABLED"] = "false"

result = run_mission("why does fire burn")
# Extract conversational part
conv = result
ti = findfirst("--- DEBUG TELEMETRY", result)
if ti !== nothing
    conv = strip(result[1:first(ti)-1])
end
println("CONVERSATIONAL OUTPUT:")
println(conv)
println()
println("---")
println("FULL OUTPUT LENGTH: $(length(result))")
