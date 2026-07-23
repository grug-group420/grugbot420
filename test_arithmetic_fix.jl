#!/usr/bin/env julia --project=.
# test_arithmetic_fix.jl — Quick test to verify sigil promotion fix
# Tests: arithmetic computation ("2+2"), PettyLearner flashcard path

using Pkg
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
Pkg.instantiate()

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    add_message_to_history!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK

const LOG_PATH = "/tmp/grug_arithmetic_test.txt"

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
end

function main()
    specimen_path = abspath(joinpath(@__DIR__, "comprehensive_specimen_v81.json"))

    println("Loading specimen: $specimen_path ...")
    try
        result = load_specimen_from_file!(specimen_path)
        println("Load result: $result")
    catch e
        println("FATAL: Load error: $e")
        return
    end

    n_alive = lock(NODE_LOCK) do
        count(v -> v.strength > 0.0, values(NODE_MAP))
    end
    println("Alive nodes: $n_alive")

    # Test arithmetic
    inputs = [
        "what is 2+2",
        "what is 3 plus 4",
        "what is 10 minus 3",
    ]


try
        open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do io
        println(io, "=== Arithmetic Fix Test ===")
        for input in inputs
            print("Testing: \"$input\" ... ")

            lock(_LAST_VOICE_OUTPUT_LOCK) do
                _LAST_VOICE_OUTPUT[] = ""
            end

            try
                process_mission(input)
            catch e
                println("ERROR: $e")
                println(io, "Input: $input -> ERROR: $e")
                continue
            end

            sleep(0.5)
            output = read_last_output()
            println(io, "Input: $input")
            println(io, "Output: $output")
            println(io, "---")

            # Check if arithmetic computed
            if occursin("4", output) && occursin("2", output)
                println("✅ Likely computed arithmetic")
            else
                println("⚠️  No arithmetic result detected")
            end
            println("Output preview: $(first(output, 200))")
        end
    end

    println("\nFull output written to: $LOG_PATH")
end

main()
