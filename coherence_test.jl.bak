#!/usr/bin/env julia
# Comprehensive routing coherence test
using Pkg; Pkg.activate(".")
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
include("src/Main.jl")
load_specimen_from_file!("comprehensive_specimen_v10.json")

function run_coherence_test()
    test_cases = [
        ("hello", "n136"),
        ("hi", "n137"),
        ("what is gravity", "n101"),
        ("explain photosynthesis", "n105"),
        ("explain newtons laws", "n106"),
        ("explain how computers work", "n107"),
        ("define entropy", "n108"),
        ("define algorithm", "n109"),
        ("predator eats prey", "n119"),
        ("explain machine learning", "n153"),
        ("what is quantum computing", "n154"),
        ("what is dark matter", "n155"),
        ("what is evolution", "n102"),
        ("what is climate change", "n104"),
        ("what is biodiversity", "n141"),
        ("danger extinction", "n151"),
        ("define species", "n110"),
        ("danger radiation", "n111"),
        ("i am sad", "n113"),
        ("calculate integral", "n115"),
        ("explain relativity", "n142"),
        ("explain the water cycle", "n143"),
        ("define ecosystem", "n144"),
    ]

    p = 0
    f = 0
    failures = []

    for (query, expected_node) in test_cases
        votes = scan_specimens(query)
        if isempty(votes)
            println("FAIL '$query' -> NO VOTES (expected=$expected_node)")
            f += 1
            push!(failures, (query, expected_node, "NONE"))
            continue
        end
        sorted = sort(votes, by=x->x[2], rev=true)
        winner = sorted[1][1]
        conf = sorted[1][2]
        if winner == expected_node
            println("PASS '$query' -> $winner (conf=$(round(conf,digits=3)))")
            p += 1
        else
            println("FAIL '$query' -> $winner (expected=$expected_node, conf=$(round(conf,digits=3)))")
            f += 1
            push!(failures, (query, expected_node, winner))
        end
    end

    println("\n=== ROUTING COHERENCE SUMMARY ===")
    println("Passed: $p / $(length(test_cases))")
    println("Failed: $f / $(length(test_cases))")
    if !isempty(failures)
        println("\nFailures:")
        for (q, exp, got) in failures
            println("  '$q': expected=$exp got=$got")
        end
    end
end

run_coherence_test()
