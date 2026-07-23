# test_v7_21b1.jl
# ==============================================================================
# v7.21b-1: Tonal observation running state + emotional_coherence field +
#           [INCOHERENT] tag.
# ==============================================================================
# This is the OBSERVATION-ONLY pass. We verify:
#   1. PredictionResult has the new emotional_coherence field
#   2. _compute_emotional_coherence maps tone+action pairs correctly
#   3. The running state (_TONAL_OBSERVATION) updates after each prediction
#   4. get_tonal_observation / reset_tonal_observation! work as advertised
#   5. format_prediction_summary emits [INCOHERENT] when coherence is low
#   6. b-1 does NOT change prediction behavior — the running state is
#      WRITTEN by predict_action_tone but NOT READ by it. Same input
#      twice (across reset boundaries) produces structurally same winners.
# ==============================================================================

using Test
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
using Random

# GRUG: Same include pattern as test_v7_21a.jl — pull the whole engine
# pipeline so ActionTonePredictor is available with its full marker
# tables and constants. runtests.jl runs each file in isolated scope,
# so each file owns its own include.
const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

const ATP = ActionTonePredictor

println("\n" * "="^70)
println("GRUG v7.21b-1 — tonal observation + emotional_coherence + [INCOHERENT]")
println("="^70)

@testset "v7.21b-1 :: emotional_coherence field exists" begin
    @test :emotional_coherence in fieldnames(ATP.PredictionResult)
    @test fieldtype(ATP.PredictionResult, :emotional_coherence) === Float64
end

@testset "v7.21b-1 :: _compute_emotional_coherence mapping" begin
    # HOSTILE has prior +0.7 for NEGATE, +0.4 for QUERY, -0.3 for ASSERT
    @test ATP._compute_emotional_coherence(ATP.ACTION_NEGATE, ATP.TONE_HOSTILE) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_QUERY,  ATP.TONE_HOSTILE) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_ASSERT, ATP.TONE_HOSTILE) == 0.0   # opposed

    # CURIOUS has prior +0.7 for QUERY, +0.4 for SPECULATE; nothing else mapped
    @test ATP._compute_emotional_coherence(ATP.ACTION_QUERY,    ATP.TONE_CURIOUS) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_SPECULATE, ATP.TONE_CURIOUS) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_COMMAND,  ATP.TONE_CURIOUS) == 0.5  # absent

    # URGENT: +COMMAND, +ESCALATE, -SPECULATE
    @test ATP._compute_emotional_coherence(ATP.ACTION_COMMAND,   ATP.TONE_URGENT) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_ESCALATE,  ATP.TONE_URGENT) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_SPECULATE, ATP.TONE_URGENT) == 0.0

    # REFLECTIVE: +SPECULATE, +QUERY, -COMMAND
    @test ATP._compute_emotional_coherence(ATP.ACTION_SPECULATE, ATP.TONE_REFLECTIVE) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_COMMAND,   ATP.TONE_REFLECTIVE) == 0.0

    # DECLARATIVE: +ASSERT, nothing else
    @test ATP._compute_emotional_coherence(ATP.ACTION_ASSERT, ATP.TONE_DECLARATIVE) == 1.0
    @test ATP._compute_emotional_coherence(ATP.ACTION_QUERY,  ATP.TONE_DECLARATIVE) == 0.5

    # NEUTRAL: empty prior → always 0.5 (no opinion)
    for action in (ATP.ACTION_QUERY, ATP.ACTION_COMMAND, ATP.ACTION_NEGATE,
                   ATP.ACTION_ASSERT, ATP.ACTION_SPECULATE, ATP.ACTION_ESCALATE)
        @test ATP._compute_emotional_coherence(action, ATP.TONE_NEUTRAL) == 0.5
    end
end

@testset "v7.21b-1 :: tonal observation lifecycle" begin
    ATP.reset_tonal_observation!()
    obs0 = ATP.get_tonal_observation()
    @test obs0.last_tone === ATP.TONE_NEUTRAL
    @test obs0.last_action === ATP.ACTION_ASSERT
    @test obs0.last_emotional_coherence == 0.5
    @test obs0.ts == 0.0

    # Run a prediction — observation should update
    Random.seed!(42)
    empty_verbs = Set{String}()
    result = ATP.predict_action_tone("you stupid garbage broken useless terrible", empty_verbs)
    obs1 = ATP.get_tonal_observation()

    # Observation timestamp should advance
    @test obs1.ts > 0.0
    # Observation tone+action should match the result
    @test obs1.last_tone === result.tone_family
    @test obs1.last_action === result.action_family
    @test obs1.last_emotional_coherence == result.emotional_coherence

    # Reset works
    ATP.reset_tonal_observation!()
    obs2 = ATP.get_tonal_observation()
    @test obs2.ts == 0.0
    @test obs2.last_tone === ATP.TONE_NEUTRAL
end

@testset "v7.21b-1 :: HOSTILE input produces high coherence (NEGATE/QUERY)" begin
    ATP.reset_tonal_observation!()
    Random.seed!(1)
    empty_verbs = Set{String}()
    # Hostile sentence with no action verbs — tone-prior tilts toward NEGATE
    r = ATP.predict_action_tone("you stupid wrong garbage useless terrible", empty_verbs)
    @test r.tone_family === ATP.TONE_HOSTILE
    # action should be in the HOSTILE tilt set (NEGATE +0.7 or QUERY +0.4)
    @test r.action_family in (ATP.ACTION_NEGATE, ATP.ACTION_QUERY)
    @test r.emotional_coherence == 1.0
end

@testset "v7.21b-1 :: REFLECTIVE input produces high coherence (SPECULATE/QUERY)" begin
    ATP.reset_tonal_observation!()
    Random.seed!(2)
    empty_verbs = Set{String}()
    r = ATP.predict_action_tone("perhaps the river bends near the old tree", empty_verbs)
    @test r.tone_family === ATP.TONE_REFLECTIVE
    @test r.action_family in (ATP.ACTION_SPECULATE, ATP.ACTION_QUERY)
    @test r.emotional_coherence == 1.0
end

@testset "v7.21b-1 :: format_prediction_summary tag emission" begin
    # Build a coherent result manually and check the tag is absent
    coherent = ATP.PredictionResult(
        ATP.ACTION_NEGATE, ATP.TONE_HOSTILE,
        0.8, false, nothing, 0.35, 1.4, time(),
        Dict{ATP.ActionFamily, Float64}(), Dict{ATP.ToneFamily, Float64}(),
        false, :lexicon, 1.0   # coherent
    )
    s_coh = ATP.format_prediction_summary(coherent)
    @test !occursin("[INCOHERENT", s_coh)

    # Build an incoherent result manually (HOSTILE+ASSERT, coherence=0.0)
    incoherent = ATP.PredictionResult(
        ATP.ACTION_ASSERT, ATP.TONE_HOSTILE,
        0.6, false, nothing, 0.35, 1.2, time(),
        Dict{ATP.ActionFamily, Float64}(), Dict{ATP.ToneFamily, Float64}(),
        false, :lexicon, 0.0   # incoherent
    )
    s_inc = ATP.format_prediction_summary(incoherent)
    @test occursin("[INCOHERENT", s_inc)
    @test occursin("coh=0.0", s_inc)

    # Build a neutral-coherence result (NEUTRAL tone, coherence=0.5)
    neutral = ATP.PredictionResult(
        ATP.ACTION_ASSERT, ATP.TONE_NEUTRAL,
        0.5, false, nothing, 0.0, 1.0, time(),
        Dict{ATP.ActionFamily, Float64}(), Dict{ATP.ToneFamily, Float64}(),
        false, :lexicon, 0.5   # neutral / no opinion
    )
    s_neu = ATP.format_prediction_summary(neutral)
    # 0.5 > threshold 0.4 — tag should NOT fire (we only flag clear mismatches)
    @test !occursin("[INCOHERENT", s_neu)
end

@testset "v7.21b-1 :: INCOHERENCE_TAG_THRESHOLD constant is sane" begin
    @test 0.0 < ATP.INCOHERENCE_TAG_THRESHOLD < 0.5
    # Threshold strictly below 0.5 means NEUTRAL-tone predictions
    # (which always have coherence=0.5) never flag — that's the contract.
end

@testset "v7.21b-1 :: observation-only — running state does NOT alter winners" begin
    # The b-1 contract: writing to _TONAL_OBSERVATION must not change
    # what predict_action_tone produces. We verify by running the same
    # input from two different starting observation states and checking
    # the WINNERS are identical (numerical drift from RNG is expected
    # and is the curve jitter — that's separate).
    empty_verbs = Set{String}()

    # State A: clean reset
    ATP.reset_tonal_observation!()
    Random.seed!(99)
    r_a = ATP.predict_action_tone("perhaps maybe wonder if storm comes", empty_verbs)

    # State B: deliberately corrupt the observation to a contradicting tone
    ATP._TONAL_OBSERVATION[] = (
        last_tone = ATP.TONE_HOSTILE,        # very different from REFLECTIVE
        last_action = ATP.ACTION_NEGATE,
        last_arousal = 1.0,
        last_emotional_coherence = 0.0,
        ts = time()
    )
    Random.seed!(99)
    r_b = ATP.predict_action_tone("perhaps maybe wonder if storm comes", empty_verbs)

    # b-1 contract: the winners must match. Observation does not yet act.
    @test r_a.action_family === r_b.action_family
    @test r_a.tone_family   === r_b.tone_family
    @test r_a.emotional_coherence == r_b.emotional_coherence
end

println("\n" * "="^70)
println("✅  All v7.21b-1 observation-pass tests passed.")
println("="^70)
