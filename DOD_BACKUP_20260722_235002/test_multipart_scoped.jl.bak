#!/usr/bin/env julia --project=.
# test_multipart_scoped.jl — Test that compound questions get ALL parts answered
# Phase 2 fix: scoped_mission ensures each COMMANDS handler only sees its sub-subject text

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

using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK

const LOG_PATH = "/tmp/grug_multipart_scoped_test.txt"

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
end

function run_test(input::String, expected_topics::Vector{String}, test_name::String, io::IO)
    print("  Testing: \"$input\" ... ")
    println(io, "\n=== $test_name ===")
    println(io, "Input: \"$input\"")
    println(io, "Expected topics: $expected_topics")

    lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[] = ""
    end

    try
        process_mission(input)
    catch e
        println("ERROR: $e")
        println(io, "ERROR: $e")
        return false
    end

    sleep(1.0)  # Give voice thread time to finish
    output = read_last_output()

    println(io, "Output: $output")

    # Check if each expected topic appears in the output
    all_found = true
    for topic in expected_topics
        found = occursin(topic, lowercase(output))
        status = found ? "✅ FOUND" : "❌ MISSING"
        println(io, "  Topic \"$topic\": $status")
        if !found
            all_found = false
        end
    end

    if all_found
        println("✅ PASS")
        println(io, "RESULT: PASS")
    else
        println("❌ FAIL")
        println(io, "RESULT: FAIL")
    end

    return all_found
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

    open(LOG_PATH, "w") do io
        println(io, "=== Multipart Scoped Mission Test ===")
        println(io, "Date: $(Dates.now())")
        println(io, "Specimen: comprehensive_specimen_v81.json")
        println(io, "Alive nodes: $n_alive")
        println(io, "")

        results = Dict{String, Bool}()

        # ─── Compound questions that previously only answered ONE part ───

        # Test 1: Arithmetic + animal
        results["arithmetic+animal"] = run_test(
            "what is 2+2 and what is a cat",
            ["4", "cat"],   # expect arithmetic answer "4" AND "cat" mentioned
            "Test 1: arithmetic + animal",
            io
        )

        sleep(1.0)

        # Test 2: Arithmetic + emotion
        results["arithmetic+emotion"] = run_test(
            "what is 3 times 4 and why do we feel sad",
            ["12", "sad"],  # expect "12" AND "sad"
            "Test 2: arithmetic + emotion",
            io
        )

        sleep(1.0)

        # Test 3: Single arithmetic (regression check)
        results["single_arithmetic"] = run_test(
            "what is 2+2",
            ["4"],
            "Test 3: single arithmetic (regression)",
            io
        )

        sleep(1.0)

        # Test 4: Single knowledge (regression check)
        results["single_knowledge"] = run_test(
            "what is a dog",
            ["dog"],
            "Test 4: single knowledge (regression)",
            io
        )

        sleep(1.0)

        # Test 5: Three-part compound
        results["three_part"] = run_test(
            "what is 5 plus 3 and what is a tree and why is the sky blue",
            ["8", "tree", "blue"],
            "Test 5: three-part compound",
            io
        )

        sleep(1.0)

        # Test 6: Arithmetic + emotion (original failing case from test_log)
        results["love+arithmetic"] = run_test(
            "what is love also what is 3 times 4",
            ["12"],          # at minimum arithmetic should compute
            "Test 6: love + arithmetic",
            io
        )

        # ─── Summary ───
        println(io, "\n\n=== SUMMARY ===")
        pass_count = count(v -> v, values(results))
        total_count = length(results)
        for (name, passed) in sort(collect(results), by=x->x[1])
            status = passed ? "✅ PASS" : "❌ FAIL"
            println(io, "  $name: $status")
        end
        println(io, "\nTotal: $pass_count / $total_count passed")
    end

    println("\nFull output written to: $LOG_PATH")
end

main()
