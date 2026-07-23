#!/usr/bin/env julia --project=.
# Quick test: single input "what is 2+2"
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

import .GrugBot420: process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

println("Loading specimen...")
load_specimen_from_file!(SPEC_PATH)

println("\n=== Test: 'what is 2+2' ===")
lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
try; process_mission("what is 2+2"); catch e; @warn "process_mission error: $e"; end
resp = read_last_output()

# Strip debug telemetry
conv = resp
ti = findfirst("--- DEBUG TELEMETRY", resp)
if ti !== nothing; conv = strip(resp[1:first(ti)-1]); end

println("\nFIRED NODE: $(_LAST_FIRED_NODE[])")
println("CONFIDENCE: $(_LAST_CONFIDENCE[])")
println("RESPONSE:\n$conv")

# Check for arithmetic result
if occursin(r"4", conv) || occursin("four", lowercase(conv))
    println("\n✓ ARITHMETIC RESULT FOUND")
else
    println("\n✗ NO ARITHMETIC RESULT")
end

# Check debug telemetry for math info
if occursin("Arithmetic Computed", resp)
    println("✓ 'Arithmetic Computed' found in telemetry")
elseif occursin("no math bindings", resp)
    println("✗ 'no math bindings this cycle' found in telemetry")
elseif occursin("math bindings present", resp)
    println("✓ 'math bindings present' found in telemetry")
end
