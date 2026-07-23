#!/usr/bin/env julia --project=.
# test_binding_race.jl — Minimal reproduction of math binding propagation bug
using Pkg; Pkg.instantiate()
include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420: process_mission,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK, _ENGINE_SIGIL_TABLE

# Access sub-modules directly
using .GrugBot420.SigilPromoter
using .GrugBot420.ArithmeticEngine
using .GrugBot420.VoteOrchestrator
import .GrugBot420: current_promotion_bindings, scan_and_expand

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

println("=" ^ 60)
println("BINDING RACE REPRODUCTION TEST")
println("=" ^ 60)

# TEST 1: Direct promote_input
println("\n=== TEST 1: Direct SigilPromoter.promote_input ===")
text = "what is 3 plus 4"
promoted, bindings = SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, text)
println("  Input:     \"$text\"")
println("  Promoted:   \"$promoted\"")
println("  Bindings:   $(length(bindings))")
for b in bindings; println("    $(b.name) = $(b.surface)"); end
t1 = ArithmeticEngine.has_math_bindings(bindings)
println("  has_math:   $t1")
if t1
    result = ArithmeticEngine.compute_arithmetic(bindings)
    println("  Computed:   $(result.expression) = $(result.answer_str)")
end

# TEST 2: scan_and_expand in same task
println("\n=== TEST 2: scan_and_expand (same task) ===")
result2 = scan_and_expand("what is 5 plus 3")
gb2 = current_promotion_bindings()
println("  Global bindings: $(length(gb2))")
for b in gb2; println("    $(b.name) = $(b.surface)"); end
t2 = ArithmeticEngine.has_math_bindings(gb2)
println("  has_math:   $t2")

# TEST 3: scan_and_expand via @spawn (simulating VoteOrchestrator dispatch)
println("\n=== TEST 3: scan_and_expand via VoteOrchestrator @spawn ===")
tn, tk = VoteOrchestrator.dispatch_task_with_timeout(
    () -> scan_and_expand("what is 2 plus 6"),
    "test_scan", 30.0; context="binding_test")
specimens = try; VoteOrchestrator.fetch_with_timeout(tn, tk); catch e; println("  ERROR: $e"); nothing; end
gb3 = current_promotion_bindings()
println("  Global bindings after @spawn scan: $(length(gb3))")
for b in gb3; println("    $(b.name) = $(b.surface)"); end
t3 = ArithmeticEngine.has_math_bindings(gb3)
println("  has_math:   $t3")

# TEST 4: Full process_mission
println("\n=== TEST 4: Full process_mission ===")
lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
try; process_mission("what is 3 plus 4"); catch e; println("  ERROR: $e"); end
output = read_last_output()
has_arith = occursin("7", output)
no_math = occursin("no math bindings this cycle", output)
println("  Output length: $(length(output))")
println("  Has '7' in output: $has_arith")
println("  Has 'no math bindings': $no_math")
t4 = has_arith && !no_math

println("\n" * "=" ^ 60)
println("RESULTS:")
println("  Test 1 (direct promote_input):     $(t1 ? "PASS ✅" : "FAIL ⚠️")")
println("  Test 2 (scan_and_expand same-task): $(t2 ? "PASS ✅" : "FAIL ⚠️")")
println("  Test 3 (scan_and_expand @spawn):    $(t3 ? "PASS ✅" : "FAIL ⚠️")")
println("  Test 4 (full process_mission):      $(t4 ? "PASS ✅" : "FAIL ⚠️")")
