# test_v7_21b3b.jl
# ==============================================================================
# v7.21b-3b: FRAME-MATCH MULTIPLIER — the orchestration quorum field
# ==============================================================================
# b-3a wired the [FRAME=...] diagnostic. b-3b is where the judgement actually
# tilts the vote field.  The user direction:
#
#   "AIML is an orchestration quorum field. It just needs matching plugs."
#   "A mismatch should act as inhibitor. In a meta kind of way."
#   Decision (c): inhibit fires ONLY under RELATIONAL mode; BASIC stays
#                 neutral on mismatch so the cheap autopilot path doesn't
#                 silently suppress mis-plugged nodes.
#
# What we verify here:
#   1. compute_frame_match_multiplier — pure function, all 5 branches
#   2. set_frame_match_weights! / get_frame_match_weights round-trip
#   3. Multiplier defaults preserve back-compat (no judge → 1.0)
#   4. VoteCandidate carries frame_match_multiplier and composite_vote_score
#      applies it as a final tilt
#   5. The 3-node trio scenario: same pattern, different plugs, judgement
#      lifts the matching one and (under RELATIONAL) inhibits the mismatch
#   6. BASIC mode neutralizes inhibit but keeps lift live
# ==============================================================================

using Test
using Random

const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

const ATP = ActionTonePredictor
const TJ  = TonalJudge
const VO  = VoteOrchestrator

println("\n" * "="^70)
println("GRUG v7.21b-3b — frame-match multiplier (orchestration quorum field)")
println("="^70)

# ------------------------------------------------------------------------------
# Helpers — build deterministic readings/judgements so we don't lean on the
# predictor's exact output for any given string.
# ------------------------------------------------------------------------------
function make_pred(;
    action::ATP.ActionFamily = ATP.ACTION_QUERY,
    tone::ATP.ToneFamily = ATP.TONE_NEUTRAL,
    confidence::Float64 = 0.7,
    coherence::Float64 = 0.6,
    arousal::Float64 = 0.0,
    weight::Float64 = 1.0,
    dangling::Bool = false,
    dangling_verb::Union{String, Nothing} = nothing,
)::ATP.PredictionResult
    return ATP.PredictionResult(
        action, tone, confidence, dangling, dangling_verb,
        arousal, weight, time(),
        Dict{ATP.ActionFamily, Float64}(), Dict{ATP.ToneFamily, Float64}(),
        false, :lexicon, coherence
    )
end

# Build a TonalJudgement straight (synthetic reading/observation discarded
# for unit tests where we want to control the verdict directly).
function make_judgement(frame::TJ.FrameHint, mode::TJ.JudgementMode)
    return TJ.TonalJudgement(
        mode, frame,
        TJ.Token[],                # promoted_tokens not exercised here
        Symbol[:synthetic_test_judgement],
        time()
    )
end

# ------------------------------------------------------------------------------
# 1. compute_frame_match_multiplier — the 5 branches of the truth table.
# ------------------------------------------------------------------------------
@testset "[1] compute_frame_match_multiplier — branches" begin
    # Reset to defaults so prior testsets can't poison.
    TJ.set_frame_match_weights!(lift = 1.20, inhibit = 0.85)

    # Branch A: judgement is nothing → 1.0 regardless of plugs.
    @test TJ.compute_frame_match_multiplier(String[], nothing) == 1.0
    @test TJ.compute_frame_match_multiplier(["de_escalating"], nothing) == 1.0

    # Branch B: empty plug list → 1.0 (back-compat for legacy nodes).
    j_basic = make_judgement(TJ.FRAME_DE_ESCALATING, TJ.BASIC)
    j_rel   = make_judgement(TJ.FRAME_DE_ESCALATING, TJ.RELATIONAL)
    @test TJ.compute_frame_match_multiplier(String[], j_basic) == 1.0
    @test TJ.compute_frame_match_multiplier(String[], j_rel)   == 1.0

    # Branch C: match → LIFT, regardless of mode (lift always fires).
    @test TJ.compute_frame_match_multiplier(["de_escalating"], j_basic) ≈ 1.20
    @test TJ.compute_frame_match_multiplier(["de_escalating"], j_rel)   ≈ 1.20
    # Multi-plug: any-of match still lifts.
    @test TJ.compute_frame_match_multiplier(["terse", "de_escalating"], j_rel) ≈ 1.20

    # Branch D: mismatch under BASIC → 1.0 (inhibit gated off).
    @test TJ.compute_frame_match_multiplier(["terse"], j_basic) == 1.0
    @test TJ.compute_frame_match_multiplier(["warm", "exploratory"], j_basic) == 1.0

    # Branch E: mismatch under RELATIONAL → INHIBIT.
    @test TJ.compute_frame_match_multiplier(["terse"], j_rel) ≈ 0.85
    @test TJ.compute_frame_match_multiplier(["warm", "exploratory"], j_rel) ≈ 0.85

    # Case-insensitive match (node JSON tolerance).
    @test TJ.compute_frame_match_multiplier(["DE_ESCALATING"], j_rel) ≈ 1.20
    @test TJ.compute_frame_match_multiplier(["De_Escalating"], j_basic) ≈ 1.20
end

# ------------------------------------------------------------------------------
# 2. set_frame_match_weights! round-trip + validation.
# ------------------------------------------------------------------------------
@testset "[2] set_frame_match_weights! — runtime tunable" begin
    # Round-trip
    TJ.set_frame_match_weights!(lift = 1.50, inhibit = 0.50)
    (l, i) = TJ.get_frame_match_weights()
    @test l ≈ 1.50
    @test i ≈ 0.50

    # Effect on the multiplier
    j_rel = make_judgement(TJ.FRAME_TERSE, TJ.RELATIONAL)
    @test TJ.compute_frame_match_multiplier(["terse"], j_rel) ≈ 1.50
    @test TJ.compute_frame_match_multiplier(["warm"], j_rel)  ≈ 0.50

    # Partial update
    TJ.set_frame_match_weights!(lift = 1.10)
    (l2, i2) = TJ.get_frame_match_weights()
    @test l2 ≈ 1.10
    @test i2 ≈ 0.50  # unchanged

    # Validation
    @test_throws Exception TJ.set_frame_match_weights!(lift = 0.5)       # < 1.0 illegal
    @test_throws Exception TJ.set_frame_match_weights!(inhibit = 0.0)    # 0 illegal
    @test_throws Exception TJ.set_frame_match_weights!(inhibit = 1.5)    # > 1 illegal

    # Restore defaults so subsequent tests are predictable.
    TJ.set_frame_match_weights!(lift = 1.20, inhibit = 0.85)
end

# ------------------------------------------------------------------------------
# 3. VoteCandidate field plumbing — default 1.0 + custom values.
# ------------------------------------------------------------------------------
@testset "[3] VoteCandidate carries frame_match_multiplier" begin
    # Default: 1.0 (back-compat with existing call sites)
    vc_default = VO.VoteCandidate("n1", 0.6, 5.0)
    @test vc_default.frame_match_multiplier == 1.0

    # Explicit lift
    vc_lift = VO.VoteCandidate("n2", 0.6, 5.0; frame_match_multiplier = 1.20)
    @test vc_lift.frame_match_multiplier ≈ 1.20

    # Explicit inhibit
    vc_inh = VO.VoteCandidate("n3", 0.6, 5.0; frame_match_multiplier = 0.85)
    @test vc_inh.frame_match_multiplier ≈ 0.85

    # Validation: negative / zero rejected
    @test_throws Exception VO.VoteCandidate("n4", 0.6, 5.0; frame_match_multiplier = 0.0)
    @test_throws Exception VO.VoteCandidate("n5", 0.6, 5.0; frame_match_multiplier = -0.5)
    @test_throws Exception VO.VoteCandidate("n6", 0.6, 5.0; frame_match_multiplier = NaN)
end

# ------------------------------------------------------------------------------
# 4. composite_vote_score applies the multiplier as a final tilt.
# ------------------------------------------------------------------------------
@testset "[4] composite_vote_score — multiplier composes correctly" begin
    # Bare vote with no other signals: score == confidence * frame_mult.
    vc_base = VO.VoteCandidate("n", 0.6, 5.0)  # mult=1.0
    vc_lift = VO.VoteCandidate("n", 0.6, 5.0; frame_match_multiplier = 1.20)
    vc_inh  = VO.VoteCandidate("n", 0.6, 5.0; frame_match_multiplier = 0.85)

    s_base = VO.composite_vote_score(vc_base)
    s_lift = VO.composite_vote_score(vc_lift)
    s_inh  = VO.composite_vote_score(vc_inh)

    @test s_base ≈ 0.6
    @test s_lift ≈ 0.6 * 1.20
    @test s_inh  ≈ 0.6 * 0.85

    # Compose with other signals: lift should still lift the post-bonus score.
    vc_with_signals = VO.VoteCandidate("n", 0.5, 5.0;
        lobe_alignment = 1.0,
        relational_match = 0.5,
        frame_match_multiplier = 1.20)
    vc_baseline = VO.VoteCandidate("n", 0.5, 5.0;
        lobe_alignment = 1.0,
        relational_match = 0.5,
        frame_match_multiplier = 1.0)
    s_signals = VO.composite_vote_score(vc_with_signals)
    s_basesig = VO.composite_vote_score(vc_baseline)
    @test s_signals ≈ s_basesig * 1.20

    # Floor still works: an anti-match-heavy vote with inhibit still floors at 0.
    vc_floor = VO.VoteCandidate("n", 0.6, 5.0;
        anti_match_score = 1.0,
        frame_match_multiplier = 0.85)
    @test VO.composite_vote_score(vc_floor) >= 0.0
end

# ------------------------------------------------------------------------------
# 5. THE TRIO: three nodes on the same pattern with different plugs.
# Judge picks DE_ESCALATING under RELATIONAL → de_esc node lifted, terse
# node inhibited, default-no-plug node neutral. Same setup under BASIC →
# de_esc node lifted, terse node UNCHANGED (gating), default neutral.
# ------------------------------------------------------------------------------
@testset "[5] Trio scenario — lift / inhibit / neutral routing" begin
    TJ.set_frame_match_weights!(lift = 1.20, inhibit = 0.85)

    # Three sibling votes on the same pattern, identical confidence/strength.
    base_conf = 0.7
    base_str  = 5.0

    # --- RELATIONAL HOSTILE → DE_ESCALATING judgement ---
    j_rel_de = make_judgement(TJ.FRAME_DE_ESCALATING, TJ.RELATIONAL)

    n_default = VO.VoteCandidate("default", base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(String[], j_rel_de))
    n_de_esc  = VO.VoteCandidate("de_esc",  base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(["de_escalating"], j_rel_de))
    n_terse   = VO.VoteCandidate("terse",   base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(["terse"], j_rel_de))

    s_default = VO.composite_vote_score(n_default)
    s_de_esc  = VO.composite_vote_score(n_de_esc)
    s_terse   = VO.composite_vote_score(n_terse)

    # The matching plug wins outright.
    @test s_de_esc > s_default
    @test s_de_esc > s_terse
    # Mismatched plug is demoted below the no-plug back-compat sibling.
    @test s_terse < s_default
    # Neutral sibling is the bare baseline.
    @test s_default ≈ base_conf

    # --- BASIC CURIOUS → EXPLORATORY judgement; gate the inhibit ---
    j_basic_exp = make_judgement(TJ.FRAME_EXPLORATORY, TJ.BASIC)

    n_default_b = VO.VoteCandidate("default", base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(String[], j_basic_exp))
    n_exp_b     = VO.VoteCandidate("explor",  base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(["exploratory"], j_basic_exp))
    n_terse_b   = VO.VoteCandidate("terse",   base_conf, base_str;
        frame_match_multiplier = TJ.compute_frame_match_multiplier(["terse"], j_basic_exp))

    s_default_b = VO.composite_vote_score(n_default_b)
    s_exp_b     = VO.composite_vote_score(n_exp_b)
    s_terse_b   = VO.composite_vote_score(n_terse_b)

    # Match still lifts under BASIC.
    @test s_exp_b > s_default_b
    # CRITICAL: under BASIC, the mismatched plug does NOT get inhibited.
    # It collapses to neutral and ties the no-plug sibling.
    @test s_terse_b ≈ s_default_b
    @test s_terse_b ≈ base_conf
end

# ------------------------------------------------------------------------------
# 6. select_aiml_votes still respects the multiplier (the trio in the picker).
# This is the integration check: does the AIML selection actually pick the
# matching plug as the top tier?
# ------------------------------------------------------------------------------
@testset "[6] select_aiml_votes — matching plug wins top tier" begin
    TJ.set_frame_match_weights!(lift = 1.20, inhibit = 0.85)
    j_rel_de = make_judgement(TJ.FRAME_DE_ESCALATING, TJ.RELATIONAL)

    # Three candidates with identical raw confidence — only frame plug differs.
    candidates = VO.VoteCandidate[
        VO.VoteCandidate("default", 0.6, 5.0;
            frame_match_multiplier = TJ.compute_frame_match_multiplier(String[], j_rel_de)),
        VO.VoteCandidate("de_esc",  0.6, 5.0;
            frame_match_multiplier = TJ.compute_frame_match_multiplier(["de_escalating"], j_rel_de)),
        VO.VoteCandidate("terse",   0.6, 5.0;
            frame_match_multiplier = TJ.compute_frame_match_multiplier(["terse"], j_rel_de)),
    ]

    top_tier, _, _ = VO.select_aiml_votes(candidates;
        threshold  = VO.AIML_CONFIDENCE_THRESHOLD,
        top_window = VO.AIML_TOP_TIER_WINDOW)

    @test !isempty(top_tier)
    top_ids = [c.node_id for c in top_tier]
    # The matching plug must be in the top tier.
    @test "de_esc" in top_ids
    # The inhibited mismatch should NOT be in the top tier (its composite is
    # 0.6 * 0.85 = 0.51, while de_esc is 0.6 * 1.20 = 0.72; gap is 0.21,
    # bigger than the AIML_TOP_TIER_WINDOW = 0.05 default).
    @test !("terse" in top_ids)
end

# ------------------------------------------------------------------------------
# 7. End-to-end: judgement Ref → multiplier → composite (no synthetic
# judgement; use the live LAST_JUDGEMENT path the engine actually goes
# through).
# ------------------------------------------------------------------------------
@testset "[7] Live LAST_JUDGEMENT round-trip" begin
    TJ.reset_last_judgement!()
    @test TJ.get_last_judgement() === nothing

    # Build a real judgement from a prediction
    pred = make_pred(action = ATP.ACTION_NEGATE, tone = ATP.TONE_HOSTILE,
                     coherence = 0.3, arousal = 0.6)
    j = TJ.judge_from_prediction(pred)
    @test TJ.get_last_judgement() === j
    # HOSTILE + low coherence forces RELATIONAL
    @test j.mode === TJ.RELATIONAL

    label = TJ.frame_hint_label(j.frame_hint)
    # A node declaring this exact label should lift.
    mult_match = TJ.compute_frame_match_multiplier([label], j)
    @test mult_match ≈ 1.20

    # A node declaring something else should inhibit (RELATIONAL mode).
    other_label = label == "warm" ? "terse" : "warm"
    mult_miss = TJ.compute_frame_match_multiplier([other_label], j)
    @test mult_miss ≈ 0.85

    # Empty plug list back-compat
    @test TJ.compute_frame_match_multiplier(String[], j) == 1.0
end

println("\n" * "="^70)
println("GRUG v7.21b-3b — frame-match multiplier tests COMPLETE")
println("="^70)
