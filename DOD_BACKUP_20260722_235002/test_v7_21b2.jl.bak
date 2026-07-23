# test_v7_21b2.jl
# ==============================================================================
# v7.21b-2: TonalJudge — token bag, common-sense mode picker, frame hints.
# ==============================================================================
# This is the SECOND observation-only pass. b-1 added the running observation
# state and emotional_coherence measurement. b-2 adds a JUDGE that lifts a
# PredictionResult into a token bag and picks a FrameHint that downstream
# scaffolds will (in b-3) consume.
#
# What we verify in b-2:
#   1. Token bag is built correctly from PredictionResult (functorial lift)
#   2. Mode picker is COMMON SENSE: relational tones / low coherence /
#      arousal swing / dangling chain → RELATIONAL; everything else → BASIC
#   3. Basic judge picks frames by action lookup (deterministic, cheap)
#   4. Relational judge picks tone-aware frames (HOSTILE → de-escalating, etc.)
#   5. Judgements are deterministic given (reading, observation)
#   6. b-2 does NOT alter PredictionResult or any predictor behavior —
#      this is a downstream layer that READS predictions
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

const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

const ATP = ActionTonePredictor
const TJ  = TonalJudge

println("\n" * "="^70)
println("GRUG v7.21b-2 — TonalJudge: tokens, mode picker, frame hints")
println("="^70)

# ------------------------------------------------------------------
# Helper: build a synthetic PredictionResult for tests so we don't
# depend on the predictor's exact output for a given string. We only
# need the field shape to be right.
# ------------------------------------------------------------------
function make_pred(;
    action::ATP.ActionFamily = ATP.ACTION_QUERY,
    tone::ATP.ToneFamily = ATP.TONE_NEUTRAL,
    confidence::Float64 = 0.7,
    coherence::Float64 = 0.5,
    arousal::Float64 = 0.0,
    weight::Float64 = 1.0,
    dangling::Bool = false,
    dangling_verb::Union{String, Nothing} = nothing,
    mode::Symbol = :lexicon,
    trajectory_damped::Bool = false,
)::ATP.PredictionResult
    return ATP.PredictionResult(
        action, tone, confidence, dangling, dangling_verb,
        arousal, weight, time(),
        Dict{ATP.ActionFamily, Float64}(), Dict{ATP.ToneFamily, Float64}(),
        trajectory_damped, mode, coherence
    )
end

function neutral_obs()
    ATP.reset_tonal_observation!()
    return ATP.get_tonal_observation()
end

@testset "v7.21b-2 :: enums and types load" begin
    @test isa(TJ.FRAME_DE_ESCALATING, TJ.FrameHint)
    @test isa(TJ.TOK_TONE, TJ.TokenCategory)
    @test isa(TJ.BASIC, TJ.JudgementMode)
    @test isa(TJ.RELATIONAL, TJ.JudgementMode)

    # All seven frames exist
    frames = instances(TJ.FrameHint)
    @test length(frames) == 7
    @test TJ.FRAME_WARM in frames
    @test TJ.FRAME_DE_ESCALATING in frames
    @test TJ.FRAME_PLAIN in frames

    # Frame labels are stable strings
    @test TJ.frame_hint_label(TJ.FRAME_DE_ESCALATING) == "de-escalating"
    @test TJ.frame_hint_label(TJ.FRAME_WARM) == "warm"
end

@testset "v7.21b-2 :: token bag built correctly from PredictionResult" begin
    # CURIOUS + QUERY + high confidence + neutral arousal
    p = make_pred(action=ATP.ACTION_QUERY, tone=ATP.TONE_CURIOUS,
                  confidence=0.8, coherence=1.0, arousal=0.0)
    r = TJ.build_reading_from_prediction(p)

    # Scalar mirrors preserved
    @test r.action_family === ATP.ACTION_QUERY
    @test r.tone_family   === ATP.TONE_CURIOUS
    @test r.confidence    == 0.8
    @test r.coherence     == 1.0

    # Token bag has tone + action + coherence at minimum
    cats_present = Set(t.category for t in r.tokens)
    @test TJ.TOK_TONE in cats_present
    @test TJ.TOK_ACTION in cats_present
    @test TJ.TOK_COHERENCE in cats_present

    # No intensity token (arousal=0 is below threshold)
    @test !(TJ.TOK_INTENSITY in cats_present)

    # No form token (no dangling chain)
    @test !(TJ.TOK_FORM in cats_present)

    # Tone token name maps correctly
    tone_tok = first(t for t in r.tokens if t.category === TJ.TOK_TONE)
    @test tone_tok.name === :curious

    # Action token name maps correctly
    action_tok = first(t for t in r.tokens if t.category === TJ.TOK_ACTION)
    @test action_tok.name === :query

    # Coherence token classified as :coherent (>= 0.7)
    coh_tok = first(t for t in r.tokens if t.category === TJ.TOK_COHERENCE)
    @test coh_tok.name === :coherent
end

@testset "v7.21b-2 :: intensity tokens fire on arousal swings" begin
    # High positive arousal → :high_arousal token
    p_hi = make_pred(arousal=0.45)
    r_hi = TJ.build_reading_from_prediction(p_hi)
    intensity_toks = [t for t in r_hi.tokens if t.category === TJ.TOK_INTENSITY]
    @test length(intensity_toks) == 1
    @test intensity_toks[1].name === :high_arousal

    # High negative arousal → :low_arousal token
    p_lo = make_pred(arousal=-0.4)
    r_lo = TJ.build_reading_from_prediction(p_lo)
    intensity_toks_lo = [t for t in r_lo.tokens if t.category === TJ.TOK_INTENSITY]
    @test length(intensity_toks_lo) == 1
    @test intensity_toks_lo[1].name === :low_arousal

    # Below threshold → no intensity token
    p_mid = make_pred(arousal=0.2)
    r_mid = TJ.build_reading_from_prediction(p_mid)
    @test isempty([t for t in r_mid.tokens if t.category === TJ.TOK_INTENSITY])
end

@testset "v7.21b-2 :: dangling chain produces form token" begin
    p = make_pred(dangling=true, dangling_verb="causes")
    r = TJ.build_reading_from_prediction(p)
    form_toks = [t for t in r.tokens if t.category === TJ.TOK_FORM]
    @test length(form_toks) == 1
    @test form_toks[1].name === :dangling_chain
end

@testset "v7.21b-2 :: pick_mode common sense — BASIC for ordinary input" begin
    obs = neutral_obs()

    # Neutral tone, coherent, no arousal swing, no dangling
    r = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_QUERY, tone=ATP.TONE_NEUTRAL,
        confidence=0.7, coherence=0.5, arousal=0.0))
    @test TJ.pick_mode(r, obs) === TJ.BASIC

    # Curious tone — but CURIOUS is not in _RELATIONAL_TONES (we keep
    # it BASIC because curiosity is a low-stakes mode)
    r2 = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_QUERY, tone=ATP.TONE_CURIOUS,
        confidence=0.7, coherence=1.0, arousal=0.0))
    @test TJ.pick_mode(r2, obs) === TJ.BASIC

    # Declarative — also low-stakes
    r3 = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_ASSERT, tone=ATP.TONE_DECLARATIVE,
        confidence=0.7, coherence=1.0, arousal=0.0))
    @test TJ.pick_mode(r3, obs) === TJ.BASIC
end

@testset "v7.21b-2 :: pick_mode common sense — RELATIONAL for charged input" begin
    obs = neutral_obs()

    # Trigger 1: HOSTILE tone
    r_h = TJ.build_reading_from_prediction(make_pred(tone=ATP.TONE_HOSTILE,
                                                    action=ATP.ACTION_NEGATE,
                                                    coherence=1.0))
    @test TJ.pick_mode(r_h, obs) === TJ.RELATIONAL

    # Trigger 1: URGENT tone
    r_u = TJ.build_reading_from_prediction(make_pred(tone=ATP.TONE_URGENT,
                                                    action=ATP.ACTION_COMMAND,
                                                    coherence=1.0))
    @test TJ.pick_mode(r_u, obs) === TJ.RELATIONAL

    # Trigger 1: REFLECTIVE tone
    r_r = TJ.build_reading_from_prediction(make_pred(tone=ATP.TONE_REFLECTIVE,
                                                    action=ATP.ACTION_SPECULATE,
                                                    coherence=1.0))
    @test TJ.pick_mode(r_r, obs) === TJ.RELATIONAL

    # Trigger 2: low coherence on otherwise neutral input
    r_lc = TJ.build_reading_from_prediction(make_pred(tone=ATP.TONE_NEUTRAL,
                                                     coherence=0.0))
    @test TJ.pick_mode(r_lc, obs) === TJ.RELATIONAL

    # Trigger 5: dangling chain on otherwise neutral input
    r_d = TJ.build_reading_from_prediction(make_pred(tone=ATP.TONE_NEUTRAL,
                                                    coherence=0.5,
                                                    dangling=true,
                                                    dangling_verb="causes"))
    @test TJ.pick_mode(r_d, obs) === TJ.RELATIONAL
end

@testset "v7.21b-2 :: pick_mode trigger 3 — observer history forces RELATIONAL" begin
    # Even on a clean neutral reading, if observation says we were just
    # incoherent the judge must spin up the relational path.
    ATP.reset_tonal_observation!()
    ATP._TONAL_OBSERVATION[] = (
        last_tone = ATP.TONE_HOSTILE,
        last_action = ATP.ACTION_NEGATE,
        last_arousal = 0.5,
        last_emotional_coherence = 0.0,    # incoherent observation
        ts = time()
    )
    obs = ATP.get_tonal_observation()

    r_clean = TJ.build_reading_from_prediction(make_pred(
        tone=ATP.TONE_NEUTRAL, action=ATP.ACTION_QUERY,
        coherence=0.5, arousal=0.0))
    @test TJ.pick_mode(r_clean, obs) === TJ.RELATIONAL

    ATP.reset_tonal_observation!()
end

@testset "v7.21b-2 :: pick_mode trigger 4 — arousal swing across observation" begin
    ATP.reset_tonal_observation!()
    ATP._TONAL_OBSERVATION[] = (
        last_tone = ATP.TONE_NEUTRAL,
        last_action = ATP.ACTION_ASSERT,
        last_arousal = 0.0,                 # observed: calm
        last_emotional_coherence = 1.0,
        ts = time()
    )
    obs = ATP.get_tonal_observation()

    # Current reading: big arousal jump from 0.0 → 0.5 (above 0.4 threshold)
    r_swing = TJ.build_reading_from_prediction(make_pred(
        tone=ATP.TONE_NEUTRAL, action=ATP.ACTION_QUERY,
        coherence=0.5, arousal=0.5))
    @test TJ.pick_mode(r_swing, obs) === TJ.RELATIONAL

    # Small arousal change should NOT trigger
    r_calm = TJ.build_reading_from_prediction(make_pred(
        tone=ATP.TONE_NEUTRAL, action=ATP.ACTION_QUERY,
        coherence=0.5, arousal=0.2))
    @test TJ.pick_mode(r_calm, obs) === TJ.BASIC

    ATP.reset_tonal_observation!()
end

@testset "v7.21b-2 :: basic judge — action → frame lookup" begin
    obs = neutral_obs()

    pairs = [
        (ATP.ACTION_QUERY,     TJ.FRAME_EXPLORATORY),
        (ATP.ACTION_COMMAND,   TJ.FRAME_IMPERATIVE),
        (ATP.ACTION_NEGATE,    TJ.FRAME_TERSE),
        (ATP.ACTION_ASSERT,    TJ.FRAME_PLAIN),
        (ATP.ACTION_SPECULATE, TJ.FRAME_CONTEMPLATIVE),
        (ATP.ACTION_ESCALATE,  TJ.FRAME_IMPERATIVE),
    ]
    for (act, expected) in pairs
        r = TJ.build_reading_from_prediction(make_pred(
            action=act, tone=ATP.TONE_NEUTRAL,
            confidence=0.7, coherence=0.5, arousal=0.0))
        j = TJ.judge(r, obs)
        @test j.mode === TJ.BASIC
        @test j.frame_hint === expected
        @test :basic_path in j.reasoning
    end
end

@testset "v7.21b-2 :: relational judge — tone wins over action" begin
    obs = neutral_obs()

    # HOSTILE + QUERY — basic would say EXPLORATORY, relational says DE_ESCALATING
    r_h = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_QUERY, tone=ATP.TONE_HOSTILE,
        confidence=0.8, coherence=1.0))
    j_h = TJ.judge(r_h, obs)
    @test j_h.mode === TJ.RELATIONAL
    @test j_h.frame_hint === TJ.FRAME_DE_ESCALATING
    @test :hostile_tone in j_h.reasoning

    # URGENT + COMMAND — relational says IMPERATIVE
    r_u = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_COMMAND, tone=ATP.TONE_URGENT,
        confidence=0.8, coherence=1.0))
    j_u = TJ.judge(r_u, obs)
    @test j_u.mode === TJ.RELATIONAL
    @test j_u.frame_hint === TJ.FRAME_IMPERATIVE
    @test :urgent_tone in j_u.reasoning

    # REFLECTIVE + SPECULATE — relational says CONTEMPLATIVE (action would also)
    r_r = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_SPECULATE, tone=ATP.TONE_REFLECTIVE,
        confidence=0.8, coherence=1.0))
    j_r = TJ.judge(r_r, obs)
    @test j_r.mode === TJ.RELATIONAL
    @test j_r.frame_hint === TJ.FRAME_CONTEMPLATIVE
    @test :reflective_tone in j_r.reasoning
end

@testset "v7.21b-2 :: relational judge — incoherence fires safety frame" begin
    obs = neutral_obs()

    # Neutral tone but coherence = 0.0 — relational path picks TERSE as safety
    r = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_ASSERT, tone=ATP.TONE_NEUTRAL,
        confidence=0.5, coherence=0.0))
    j = TJ.judge(r, obs)
    @test j.mode === TJ.RELATIONAL
    @test j.frame_hint === TJ.FRAME_TERSE
    @test :low_coherence_safety in j.reasoning
end

@testset "v7.21b-2 :: judge is deterministic given (reading, observation)" begin
    obs = neutral_obs()
    r = TJ.build_reading_from_prediction(make_pred(
        action=ATP.ACTION_NEGATE, tone=ATP.TONE_HOSTILE,
        confidence=0.8, coherence=1.0))

    # Same inputs → same judgement (modulo timestamp)
    j1 = TJ.judge(r, obs)
    j2 = TJ.judge(r, obs)
    @test j1.mode === j2.mode
    @test j1.frame_hint === j2.frame_hint
    @test j1.reasoning == j2.reasoning
end

@testset "v7.21b-2 :: judge_from_prediction wires through and stashes" begin
    TJ.reset_last_judgement!()
    @test TJ.get_last_judgement() === nothing

    p = make_pred(action=ATP.ACTION_NEGATE, tone=ATP.TONE_HOSTILE,
                  confidence=0.8, coherence=1.0)
    j = TJ.judge_from_prediction(p)

    @test j.frame_hint === TJ.FRAME_DE_ESCALATING
    @test TJ.get_last_judgement() !== nothing
    @test TJ.get_last_judgement().frame_hint === TJ.FRAME_DE_ESCALATING

    TJ.reset_last_judgement!()
    @test TJ.get_last_judgement() === nothing
end

@testset "v7.21b-2 :: end-to-end with real predictor" begin
    # Verify the wiring all the way from a string input to a frame hint.
    ATP.reset_tonal_observation!()
    TJ.reset_last_judgement!()
    Random.seed!(42)
    empty_verbs = Set{String}()

    # Hostile real input
    p1 = ATP.predict_action_tone("you stupid wrong garbage useless terrible", empty_verbs)
    j1 = TJ.judge_from_prediction(p1)
    @test p1.tone_family === ATP.TONE_HOSTILE
    @test j1.mode === TJ.RELATIONAL
    @test j1.frame_hint === TJ.FRAME_DE_ESCALATING

    # Reflective real input
    p2 = ATP.predict_action_tone("perhaps the river bends near the old tree", empty_verbs)
    j2 = TJ.judge_from_prediction(p2)
    @test p2.tone_family === ATP.TONE_REFLECTIVE
    @test j2.mode === TJ.RELATIONAL
    @test j2.frame_hint === TJ.FRAME_CONTEMPLATIVE

    # Curious real input — BASIC path (curious is low-stakes)
    p3 = ATP.predict_action_tone("what is fire", empty_verbs)
    j3 = TJ.judge_from_prediction(p3)
    @test p3.tone_family === ATP.TONE_CURIOUS
    @test j3.mode === TJ.BASIC
    @test j3.frame_hint === TJ.FRAME_EXPLORATORY

    ATP.reset_tonal_observation!()
    TJ.reset_last_judgement!()
end

@testset "v7.21b-2 :: b-2 contract — judge does NOT mutate predictor state" begin
    # The b-2 contract: TonalJudge READS from PredictionResult and observation
    # but does not WRITE back into the predictor's state. Same prediction
    # twice → same prediction (judge had no side effects on predictor).
    ATP.reset_tonal_observation!()
    Random.seed!(7)
    empty_verbs = Set{String}()

    p_before = ATP.predict_action_tone("you stupid garbage", empty_verbs)
    obs_after_pred = ATP.get_tonal_observation()

    # Run judge — should not change observation
    _ = TJ.judge_from_prediction(p_before)
    obs_after_judge = ATP.get_tonal_observation()

    @test obs_after_pred.last_tone === obs_after_judge.last_tone
    @test obs_after_pred.last_action === obs_after_judge.last_action
    @test obs_after_pred.last_emotional_coherence == obs_after_judge.last_emotional_coherence
    @test obs_after_pred.ts == obs_after_judge.ts

    ATP.reset_tonal_observation!()
end

println("\n" * "="^70)
println("✅  All v7.21b-2 TonalJudge tests passed.")
println("="^70)
