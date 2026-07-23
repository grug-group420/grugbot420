#!/usr/bin/env julia --project=.
# test_decoherence_deep.jl — Deep decoherence analysis
# Shows FULL responses, fired nodes, confidence, and checks semantic coherence
using Pkg; Pkg.instantiate()
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK, save_specimen_to_file!

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function main()
    println("Loading specimen...")
    load_specimen_from_file!(SPEC_PATH)

    # Test inputs — focus on ones that showed decoherence
    inputs = [
        "what is 2+2 also what is a cat",
        "what is fire and why does it burn",
        "tell me about water and what is 5 plus 3",
        "what is fire",
        "what is a cat",
        "what is 2+2",
        "why does ice melt",
        "I feel sad today",
        "what causes thunder",
        "where is the mountain",
    ]

    for input in inputs
        lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
        try; process_mission(input); catch e; @warn "err: $e"; end
        resp = read_last_output()

        # Strip debug telemetry
        conv = resp
        ti = findfirst("--- DEBUG TELEMETRY", resp)
        if ti !== nothing; conv = strip(resp[1:first(ti)-1]); end

        fired = try; lock(NODE_LOCK) do; NODE_MAP[_LAST_FIRED_NODE[]]; end; catch; nothing; end
        fired_pattern = fired !== nothing ? fired.pattern : "N/A"
        fired_lobe = fired !== nothing ? fired.lobe_id : "N/A"
        fired_strength = fired !== nothing ? fired.strength : 0.0

        println("\n════════════════════════════════════════")
        println("INPUT: \"$input\"")
        println("FIRED: $(_LAST_FIRED_NODE[]) | pattern=\"$fired_pattern\" | lobe=$fired_lobe | strength=$fired_strength")
        println("CONFIDENCE: $(_LAST_CONFIDENCE[])")
        println("RESPONSE:\n$conv")
    end
end

main()
