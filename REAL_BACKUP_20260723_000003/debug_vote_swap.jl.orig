#!/usr/bin/env julia --project=.
# Minimal debug test for _vote_word_swap pipeline
# Focus: trace why word swaps aren't happening

using Pkg; Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    Thesaurus

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

ENV["GRUG_CHATTER_ENABLED"] = "false"

println("=" ^ 60)
println("  VOTE_WORD_SWAP DEBUG TEST")
println("=" ^ 60)

# Check thesaurus state
println("\n📊 Thesaurus SYNONYM_SEED_MAP has $(length(Thesaurus.SYNONYM_SEED_MAP)) entries")
# Check a few key words
for w in ["and", "but", "fire", "heat", "cave", "forest", "oxygen", "combines", "with"]
    if haskey(Thesaurus.SYNONYM_SEED_MAP, w)
        syns = collect(Thesaurus.SYNONYM_SEED_MAP[w])
        println("  '$w' → $(syns)")
    else
        println("  '$w' → NOT IN THESAURUS")
    end
end

println("\n📦 Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("✅ Loaded. Running test queries...\n")

# Run the same query 3 times to see variation
for i in 1:3
    println("\n--- RUN $i: 'what is fire' ---")
    result = ask_grug("what is fire")
    println("RESULT: $result")
end

# Also test water
for i in 1:3
    println("\n--- RUN $i: 'what is water' ---")
    result = ask_grug("what is water")
    println("RESULT: $result")
end

println("\n✅ Debug test complete. Check logs above for [VOTE_SWAP_DBG] and [PIPELINE_DBG] entries.")
