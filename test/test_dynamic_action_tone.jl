# test_dynamic_action_tone.jl
# ==============================================================================
# GRUG v7.15 TESTS --- DynamicActionTonePredictor: simple path unchanged,
#                       complex path boosts confidence, bad-input rejection
# ==============================================================================

using Test

# GRUG: We need the full ActionTonePredictor module loaded first so that the
# DynamicActionTonePredictor can reference it via `..ActionTonePredictor`.
# Easiest path: use the full package.
using GrugBot420
using GrugBot420: DynamicActionTonePredictor
using GrugBot420: ActionTonePredictor
using GrugBot420.DynamicActionTonePredictor:
    predict_action_tone_dynamic, compute_semantic_complexity,
    should_use_dynamic_path, DynamicPredictionError, COMPLEXITY_FLOOR
using GrugBot420.ActionTonePredictor: predict_action_tone, PredictionResult

println("\n" * "=" ^ 60)
println("GRUG v7.15 DynamicActionTonePredictor TEST SUITE")
println("=" ^ 60)

# GRUG: Build a minimal verb set for the base predictor.
const TEST_VERBS = Set([
    "cause", "emerge", "enumerate", "explain", "defend",
    "relate", "produce", "refute", "accept",
])

# ==============================================================================
# [1] COMPLEXITY SCORE --- matches engine formula
# ==============================================================================
@testset "compute_semantic_complexity: engine formula" begin
    # GRUG: 4-word input, 0 triples: 4 * 0.15 = 0.6
    @test isapprox(compute_semantic_complexity("what is the time", 0), 0.6;
                   atol = 1e-9)

    # GRUG: 10-word input, 2 triples: 10*0.15 + 2*1.5 = 1.5 + 3.0 = 4.5
    long = "explain how entropy emerges from microstates in isolated thermodynamic systems"
    @test isapprox(compute_semantic_complexity(long, 2), 4.5; atol = 1e-9)

    @test_throws DynamicPredictionError compute_semantic_complexity("", 0)
    @test_throws DynamicPredictionError compute_semantic_complexity("hi", -1)
end

# ==============================================================================
# [2] GATE --- simple input uses simple path; complex input uses dynamic
# ==============================================================================
@testset "should_use_dynamic_path: boundary" begin
    @test should_use_dynamic_path("hi there", 0) == false

    long = "explain how entropy emerges from microstates in isolated thermodynamic systems"
    @test should_use_dynamic_path(long, 2) == true  # 4.5 hits exactly
end

# ==============================================================================
# [3] SIMPLE PATH --- dynamic returns bit-exact base result
# ==============================================================================
@testset "predict_action_tone_dynamic: simple input passes through" begin
    input = "what time is it"
    triple_count = 0

    base = predict_action_tone(input, TEST_VERBS)
    dyn  = predict_action_tone_dynamic(input, TEST_VERBS, triple_count)

    @test dyn.action_family    == base.action_family
    @test dyn.tone_family      == base.tone_family
    @test dyn.confidence       == base.confidence   # bit-exact
    @test dyn.arousal_nudge    == base.arousal_nudge
    @test dyn.action_weight    == base.action_weight
    @test dyn.incomplete_chain == base.incomplete_chain
end

# ==============================================================================
# [4] COMPLEX PATH --- confidence boosted, other fields preserved
# ==============================================================================
@testset "predict_action_tone_dynamic: complex input boosts confidence" begin
    # GRUG: Construct an input that clears the complexity floor (>= 4.5).
    long = "please explain how thermodynamic entropy emerges from microstate " *
           "enumeration and defend that claim against the H-theorem objection"
    triple_count = 3
    causal_count = 2

    base = predict_action_tone(long, TEST_VERBS)
    dyn  = predict_action_tone_dynamic(long, TEST_VERBS, triple_count;
                                        causal_verb_count = causal_count)

    @test dyn.action_family == base.action_family
    @test dyn.tone_family   == base.tone_family

    # GRUG: Boost applied; new confidence >= base; never > 1.0.
    @test dyn.confidence >= base.confidence
    @test dyn.confidence <= 1.0

    # Expected boost = min(0.30, 5 * 0.05) = 0.25.
    expected_boost = min(0.30, (triple_count + causal_count) * 0.05)
    expected_conf  = clamp(base.confidence + expected_boost, 0.0, 1.0)
    @test isapprox(dyn.confidence, expected_conf; atol = 1e-9)
end

# ==============================================================================
# [5] ERROR PATHS --- empty + negative counts rejected
# ==============================================================================
@testset "predict_action_tone_dynamic: error paths" begin
    @test_throws DynamicPredictionError predict_action_tone_dynamic(
        "", TEST_VERBS, 0)
    @test_throws DynamicPredictionError predict_action_tone_dynamic(
        "hi", TEST_VERBS, -1)
    @test_throws DynamicPredictionError predict_action_tone_dynamic(
        "hi", TEST_VERBS, 0; causal_verb_count = -1)
end

# ==============================================================================
# [6] BOUNDARY --- complexity exactly at floor counts as dynamic
# ==============================================================================
@testset "boundary: complexity == COMPLEXITY_FLOOR enters dynamic path" begin
    # GRUG: Construct input so complexity == exactly 4.5.
    # 30-word input (30*0.15 = 4.5), 0 triples.
    words30 = join(["w" for _ in 1:30], " ")
    @test isapprox(compute_semantic_complexity(words30, 0), 4.5; atol = 1e-9)
    @test should_use_dynamic_path(words30, 0) == true
end

println("\n" * "=" ^ 60)
println("\u2705  DynamicActionTonePredictor tests COMPLETE")
println("=" ^ 60)
