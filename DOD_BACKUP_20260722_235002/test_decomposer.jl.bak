#!/usr/bin/env julia --project=.
# Quick test: what does InputDecomposer do with "what is 2+2"?
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

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420.InputDecomposer: decompose_input, DecomposedSubSubject

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

# Load specimen to get its decomposer config
import .GrugBot420: load_specimen_from_file!
load_specimen_from_file!(SPEC_PATH)

test_inputs = [
    "what is 2+2",
    "what is a cat",
    "what is 2+2 also what is a cat",
    "I feel happy and what is 5 plus 3",
    "what is 5 plus 3",
    "calculate 3+4",
    "compute 5*7",
]

for inp in test_inputs
    println("\n=== Input: \"$inp\" ===")
    try
        subs = decompose_input(inp)
        println("  Sub-subjects: $(length(subs))")
        for (i, sub) in enumerate(subs)
            println("    $i: text=\"$(sub.text)\" group=\"$(sub.multipart_group)\" role=$(sub.role)")
        end
    catch e
        println("  ERROR: $e")
    end
end
