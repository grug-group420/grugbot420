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
using GrugBot420.ActionTonePredictor: predict_action_tone, PredictionResult,
                                       reset_tonal_buildup!

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
# [3] SIMPLE PATH --- dynamic returns the base result (family-equal; numerics
#     drift by snap-back jitter + tonal build-up between two consecutive
#     predict_action_tone calls, which is BY DESIGN as of the v7.16+ tonal
#     dynamics. The contract is "dynamic adds NO work on simple inputs",
#     i.e. dynamic must not BOOST or otherwise perturb beyond what calling
#     the base predictor twice would itself produce.)
# ==============================================================================
@testset "predict_action_tone_dynamic: simple input passes through" begin
    input = "what time is it"
    triple_count = 0

    # GRUG: Reset the tonal build-up state between the two calls so each
    # one starts cold. The remaining drift between `base` and `dyn` is
    # ONLY the per-call snap-back jitter (±2.5% per family, multiplicative,
    # then a 5% tug toward uniform), which is bounded.
    reset_tonal_buildup!()
    base = predict_action_tone(input, TEST_VERBS)
    reset_tonal_buildup!()
    dyn  = predict_action_tone_dynamic(input, TEST_VERBS, triple_count)

    # Family decisions must agree (jitter is too small to flip a winner).
    @test dyn.action_family    == base.action_family
    @test dyn.tone_family      == base.tone_family
    @test dyn.incomplete_chain == base.incomplete_chain

    # Numerics: dynamic's job on a simple input is "no boost". Allow a
    # generous tolerance so the snap-back jitter envelope and any minor
    # build-up seed effects don't trip the test, but reject any actual
    # confidence boost (which would mean the dynamic path mistakenly fired).
    @test abs(dyn.confidence    - base.confidence)    < 0.10
    @test abs(dyn.arousal_nudge - base.arousal_nudge) < 0.10
    @test abs(dyn.action_weight - base.action_weight) < 0.10
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

    # GRUG: Reset build-up between the two predict calls so neither carries
    # mood from the other. Per-call snap-back jitter still applies, so the
    # exact-equality assertion is replaced by a bounded-tolerance one.
    reset_tonal_buildup!()
    base = predict_action_tone(long, TEST_VERBS)
    reset_tonal_buildup!()
    dyn  = predict_action_tone_dynamic(long, TEST_VERBS, triple_count;
                                        causal_verb_count = causal_count)

    @test dyn.action_family == base.action_family
    @test dyn.tone_family   == base.tone_family

    # GRUG: Boost applied; new confidence >= base − jitter slop; never > 1.0.
    # Jitter envelope is ±2.5% per family + 5% snap toward uniform, so on
    # the confidence-margin (winner − runnerup, scaled by 2.5) the absolute
    # drift between two calls can be a few percent. We test that the dynamic
    # boost exists in expectation, not bit-exactly.
    @test dyn.confidence + 0.05 >= base.confidence
    @test dyn.confidence <= 1.0

    # Expected boost = min(0.30, 5 * 0.05) = 0.25. Compare with a tolerance
    # that accommodates the jitter on BOTH `base` and `dyn` independently.
    expected_boost = min(0.30, (triple_count + causal_count) * 0.05)
    expected_conf  = clamp(base.confidence + expected_boost, 0.0, 1.0)
    @test isapprox(dyn.confidence, expected_conf; atol = 0.05)
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
