#!/usr/bin/env julia --project=.
# Minimal test: verify SigilPromoter produces math bindings for "what is 2+2"
# and that scan_and_expand stashes them correctly
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

import .GrugBot420: current_promotion_bindings, get_multipart_bindings
import .GrugBot420.SigilPromoter: promote_input, SigilBinding
import .GrugBot420.SigilRegistry: SigilTable, list_sigils
import .GrugBot420.ArithmeticEngine: has_math_bindings

# Get scan_and_expand from the engine module
import .GrugBot420: scan_and_expand

# Test 1: Direct promote_input call
println("=== Test 1: Direct promote_input ===")
table = GrugBot420._ENGINE_SIGIL_TABLE
rewritten, bindings = promote_input(table, "what is 2+2")
println("  Input:     \"what is 2+2\"")
println("  Rewritten: \"$rewritten\"")
println("  Bindings:  $(length(bindings)) total")
for b in bindings
    println("    name=$(b.name) value=$(b.value) raw_pos=$(b.raw_position)")
end
println("  has_math_bindings: $(has_math_bindings(bindings))")

# Test 2: Call scan_and_expand directly (in current task, no Task boundary)
println("\n=== Test 2: scan_and_expand in current task ===")
specimens = try
    scan_and_expand("what is 2+2")
catch e
    @warn "scan_and_expand failed: $e"
    nothing
end
if specimens !== nothing
    println("  Specimens returned: $(length(specimens))")
end
# Now check global bindings
gb = current_promotion_bindings()
println("  Global bindings after scan_and_expand: $(length(gb)) total")
for b in gb
    println("    name=$(b.name) value=$(b.value)")
end
println("  has_math_bindings: $(has_math_bindings(gb))")

# Test 2b: Check what _GLOBAL_PROMOTION_BINDINGS Ref actually contains
println("\n=== Test 2b: Check _GLOBAL_PROMOTION_BINDINGS Ref directly ===")
gb_direct = GrugBot420._GLOBAL_PROMOTION_BINDINGS[]
println("  Direct ref value: $(length(gb_direct)) total")
for b in gb_direct
    println("    name=$(b.name) value=$(b.value)")
end

println("\n=== DONE ===")
