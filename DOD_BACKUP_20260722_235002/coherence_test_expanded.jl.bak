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

# Disable chatter for clean single responses
ENV["GRUG_CHATTER_ENABLED"] = "false"

load_specimen_from_file!(SPEC_PATH)

# Expanded test set: 20 queries covering multiple domains
queries = [
    # Core knowledge queries
    "what is fire",
    "what is water",
    "what is air",
    "what is earth",
    "what is sky",
    # Causal queries
    "why does fire burn",
    "why is sky blue",
    "why does water flow",
    # Process/method queries
    "how does grug think",
    "how does fire work",
    # Math queries
    "what is 2 plus 2",
    "what is 3 times 4",
    # Social/greeting
    "hello",
    "who are you",
    # Abstract queries
    "what is love",
    "what is courage",
    "what is beauty",
    # Specimen-gap queries (should produce graceful no-match)
    "tell me about rocks",
    "what is a computer",
]

results = Dict{String, String}()

for q in queries
    result = run_mission(q)
    conv = result
    ti = findfirst("--- DEBUG TELEMETRY", result)
    if ti !== nothing
        conv = strip(result[1:first(ti)-1])
    end
    # Clean up any trailing whitespace/newlines
    conv = strip(replace(conv, r"\n{3,}" => "\n\n"))
    results[q] = conv
    println("Q: $q")
    println("A: $conv")
    println()
end

# Save results to JSON for analysis
open(joinpath(@__DIR__, "coherence_test_results.json"), "w") do f
    JSON.print(f, results, 2)
end
println("\n=== Results saved to coherence_test_results.json ===")
