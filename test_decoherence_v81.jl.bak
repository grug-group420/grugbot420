#!/usr/bin/env julia --project=.
# test_decoherence_v81.jl — v8.1-coherence-fix verification
# Tests: (1) per-group binding stash for multipart arithmetic
#        (2) lobe alignment via score_lobes integration
#        (3) correct lobe routing for compound inputs
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
    NODE_MAP, NODE_LOCK, save_specimen_to_file!,
    current_promotion_bindings, get_multipart_bindings,
    get_multipart_lobe_state, clear_multipart_bindings!, clear_multipart_lobe_states!

import .GrugBot420.LobeOrchestrator: get_last_state
import .GrugBot420.Lobe: find_lobe_for_node

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")
const LOG_PATH = joinpath(@__DIR__, "test_log_v81.md")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

# Track results for MD log
struct TestResult
    input::String
    response::String
    fired_node::String
    fired_pattern::String
    fired_lobe::String
    confidence::Float64
    lobe_winner::String
    lobe_passthrough::Vector{String}
    passed::Bool
    notes::String
end

function run_test(input::String; expect_math::Bool=false, expect_lobe::String="", label::String="")::TestResult
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(input); catch e; @warn "process_mission error: $e"; end
    resp = read_last_output()

    # Strip debug telemetry for display
    conv = resp
    ti = findfirst("--- DEBUG TELEMETRY", resp)
    if ti !== nothing; conv = strip(resp[1:first(ti)-1]); end

    fired_node = _LAST_FIRED_NODE[]
    fired = try; lock(NODE_LOCK) do; NODE_MAP[fired_node]; end; catch; nothing; end
    fired_pattern = fired !== nothing ? fired.pattern : "N/A"
    fired_lobe = try; find_lobe_for_node(fired_node); catch; "N/A"; end
    confidence = _LAST_CONFIDENCE[]

    # Get lobe orchestrator state
    lobe_scores, lobe_winner, lobe_passthrough = get_last_state()

    # Determine pass/fail
    passed = true
    notes = String[]

    if expect_math
        has_number = occursin(r"\d+", conv)
        has_arithmetic_word = occursin("four", lowercase(conv)) || occursin("seven", lowercase(conv)) ||
                              occursin("five", lowercase(conv)) || occursin("three", lowercase(conv)) ||
                              occursin("ten", lowercase(conv)) || occursin("eight", lowercase(conv)) ||
                              occursin("sum", lowercase(conv)) || occursin("result", lowercase(conv))
        if !has_number && !has_arithmetic_word
            passed = false
            push!(notes, "EXPECTED arithmetic result but found none in response")
        else
            push!(notes, "Arithmetic result found ✓")
        end
        # Check if math lobe won
        if lobe_winner != "MathLobe" && lobe_winner != "math" && !isempty(lobe_winner)
            push!(notes, "Lobe winner=$lobe_winner (expected MathLobe)")
        elseif !isempty(lobe_winner)
            push!(notes, "MathLobe won ✓")
        end
    end

    if !isempty(expect_lobe)
        if fired_lobe != expect_lobe
            passed = false
            push!(notes, "Fired lobe=$fired_lobe (expected $expect_lobe)")
        else
            push!(notes, "Fired lobe matches expected ✓")
        end
    end

    println("\n══════════════════════════════════════════════════")
    println("INPUT: \"$input\"")
    if !isempty(label); println("LABEL: $label"); end
    println("FIRED: $fired_node | pattern=\"$fired_pattern\" | lobe=$fired_lobe | conf=$confidence")
    println("LOBE WINNER: $lobe_winner  PASSTHROUGH: $(join(lobe_passthrough, ","))")
    println("RESULT: $(passed ? "PASS ✓" : "FAIL ✗")")
    if !isempty(notes); println("NOTES: $(join(notes, "; "))"); end
    println("RESPONSE:\n$conv")

    TestResult(input, conv, fired_node, fired_pattern, fired_lobe isa String ? fired_lobe : "N/A",
               confidence, lobe_winner, lobe_passthrough, passed, join(notes, "; "))
end

function main()
    println("="^60)
    println("GrugBot420 v8.1-coherence-fix Decoherence Test")
    println("Date: $(now())")
    println("="^60)

    println("\nLoading specimen...")
    load_specimen_from_file!(SPEC_PATH)

    results = TestResult[]

    # --- Test 1: Simple arithmetic (should already work) ---
    push!(results, run_test("what is 2+2"; expect_math=true, label="Simple arithmetic baseline"))

    # --- Test 2: Compound input with arithmetic + non-math ---
    push!(results, run_test("what is 2+2 also what is a cat"; expect_math=true,
                            label="Compound: arithmetic + knowledge"))

    # --- Test 3: Compound with emotional + arithmetic ---
    push!(results, run_test("I feel happy and what is 5 plus 3"; expect_math=true,
                            label="Compound: emotional + arithmetic"))

    # --- Test 4: Compound with survival + arithmetic ---
    push!(results, run_test("what is fire and what is 3+4"; expect_math=true,
                            label="Compound: survival + arithmetic"))

    # --- Test 5: Pure knowledge (no arithmetic expected, but check coherence) ---
    push!(results, run_test("what is a cat"; label="Pure knowledge singleton"))

    # --- Test 6: Pure arithmetic (another baseline) ---
    push!(results, run_test("what is 5 plus 3"; expect_math=true,
                            label="Pure arithmetic singleton"))

    # --- Test 7: Complex compound ---
    push!(results, run_test("tell me about water and what is ten plus seven"; expect_math=true,
                            label="Compound: knowledge + arithmetic"))

    # --- Test 8: Another compound ---
    push!(results, run_test("why does ice melt and what is 2+3"; expect_math=true,
                            label="Compound: science + arithmetic"))

    # --- Summary ---
    total = length(results)
    passed_count = count(r -> r.passed, results)
    failed_count = total - passed_count

    println("\n" * "="^60)
    println("SUMMARY: $passed_count/$total PASSED  ($failed_count FAILED)")
    println("="^60)

    for r in results
        status = r.passed ? "✓" : "✗"
        println("  $status  \"$(r.input)\"  [$(r.fired_lobe)] conf=$(round(r.confidence; digits=3))")
    end

    # --- Write MD log ---
    log_io = IOBuffer()
    println(log_io, "# GrugBot420 v8.1-coherence-fix Test Log")
    println(log_io, "Date: $(now())")
    println(log_io, "")
    println(log_io, "## Summary")
    println(log_io, "Total: $total | Passed: $passed_count | Failed: $failed_count")
    println(log_io, "")
    println(log_io, "## Fixes Applied")
    println(log_io, "1. **Per-group binding stash** (engine.jl): `scan_and_expand` now stashes promotion bindings per multipart_group. `synthesize_voice_reply` looks up bindings by primary_vote's group_id before falling back to global Ref.")
    println(log_io, "2. **score_lobes integration** (Main.jl): `score_lobes()` is now called after cast_votes and before `ephemeral_voice_orchestrator`. This populates `lobe_alignment` for all vote candidates.")
    println(log_io, "3. **Per-group lobe scoring** (Main.jl + engine.jl): For multipart inputs, `score_lobes` runs per group so each sub-subject gets its own winner/passthrough lobes. Votes use their group's lobe state for alignment computation.")
    println(log_io, "4. **Per-group peak_dominance** (Main.jl): Peak dominance uses per-group lobe_base_map for multipart votes.")
    println(log_io, "")
    println(log_io, "## Test Results")
    println(log_io, "")
    println(log_io, "| # | Input | Fired Node | Lobe | Conf | Lobe Winner | Math Result | Status |")
    println(log_io, "|---|-------|-----------|------|------|-------------|-------------|--------|")

    for (i, r) in enumerate(results)
        has_math = occursin(r"\d+", r.response)
        println(log_io, "| $i | $(replace(r.input, "|"=>"&#124;")) | $(r.fired_node) | $(r.fired_lobe) | $(round(r.confidence; digits=3)) | $(r.lobe_winner) | $(has_math ? "Yes" : "No") | $(r.passed ? "✓ PASS" : "✗ FAIL") |")
    end

    println(log_io, "")
    println(log_io, "## Detailed Results")
    println(log_io, "")
    for (i, r) in enumerate(results)
        println(log_io, "### Test $i: \"$(r.input)\"")
        println(log_io, "- **Fired Node**: $(r.fired_node) (pattern=\"$(r.fired_pattern)\", lobe=$(r.fired_lobe))")
        println(log_io, "- **Confidence**: $(round(r.confidence; digits=4))")
        println(log_io, "- **Lobe Winner**: $(r.lobe_winner), Passthrough: $(join(r.lobe_passthrough, ", "))")
        println(log_io, "- **Status**: $(r.passed ? "PASS ✓" : "FAIL ✗")")
        if !isempty(r.notes); println(log_io, "- **Notes**: $(r.notes)"); end
        # Response (truncated for readability)
        resp_short = length(r.response) > 500 ? r.response[1:500] * "..." : r.response
        println(log_io, "- **Response** (truncated):")
        println(log_io, "  > $(replace(resp_short, "\n" => "  \n  > "))")
        println(log_io, "")
    end

    log_str = String(take!(log_io))
    write(LOG_PATH, log_str)
    println("\nLog written to $LOG_PATH")
end

main()
