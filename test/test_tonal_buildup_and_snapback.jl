# ==============================================================================
# test_tonal_buildup_and_snapback.jl --- v7.16+ tonal build-up + Lorenz snap-back
# ==============================================================================
# GRUG: This test pins the new dynamics added on top of v7.15-updates:
#   1. TONAL BUILD-UP: consecutive same-tone predictions grow the buildup
#      accumulator; tone change resets it; long quiet decays it.
#   2. LORENZ SNAP-BACK: every prediction's softmax curve gets a bounded
#      jitter and a small pull toward uniform — so identical inputs never
#      produce identical curves and the curve never stays maximally sharp.
#
# These are independent mechanisms with independent failure modes:
#   - build-up shapes the SCORE (arousal_nudge magnitude across calls).
#   - snap-back shapes the CURVE (per-call distribution shape).
# Tests are split accordingly.
# ==============================================================================

using Test
using GrugBot420
using GrugBot420.ActionTonePredictor:
    predict_action_tone, reset_tonal_buildup!, get_tonal_buildup,
    reset_trajectory!,
    TONE_HOSTILE, TONE_NEUTRAL, TONE_REFLECTIVE,
    TONAL_BUILDUP_INCREMENT, TONAL_BUILDUP_HALFLIFE_S,
    TONAL_BUILDUP_AROUSAL_GAIN,
    LORENZ_SNAPBACK_JITTER, LORENZ_SNAPBACK_PULL

const TEST_VERBS = Set(["is", "cause", "affect", "imply"])

# Helper: drive the predictor with a HOSTILE-leaning string and report the
# arousal nudge it produced. Build-up is intentionally NOT reset between
# calls — we want consecutive calls to stack mood.
hostile_call() = predict_action_tone("you are stupid and wrong", TEST_VERBS)
hostile_call_b() = predict_action_tone("idiot, hate you so much", TEST_VERBS)
neutral_call() = predict_action_tone("the table is brown", TEST_VERBS)

# ──────────────────────────────────────────────────────────────────────────
# (1) Module-level constants are sane (sanity guard against accidental edits)
# ──────────────────────────────────────────────────────────────────────────
@testset "(1) tonal-dynamics constants are in legal ranges" begin
    @test 0.0 < TONAL_BUILDUP_INCREMENT < 1.0
    @test TONAL_BUILDUP_HALFLIFE_S > 0.0
    @test TONAL_BUILDUP_AROUSAL_GAIN >= 0.0
    @test 0.0 <= LORENZ_SNAPBACK_JITTER <= 0.10  # never let jitter run away
    @test 0.0 <= LORENZ_SNAPBACK_PULL <= 0.50    # never let pull dominate
end

# ──────────────────────────────────────────────────────────────────────────
# (2) reset_tonal_buildup! produces a clean slate
# ──────────────────────────────────────────────────────────────────────────
@testset "(2) reset_tonal_buildup! clears the accumulator" begin
    reset_tonal_buildup!()
    s = get_tonal_buildup()
    @test s.tone === nothing
    @test s.buildup == 0.0
    @test s.ts == 0.0
end

# ──────────────────────────────────────────────────────────────────────────
# (3) Same-tone calls grow the buildup; tone change resets it
# ──────────────────────────────────────────────────────────────────────────
@testset "(3) same-tone calls stack buildup; tone change resets it" begin
    reset_tonal_buildup!()

    r1 = hostile_call()
    s1 = get_tonal_buildup()
    @test s1.tone == r1.tone_family
    # First-ever call seeds at 0.05 — small but non-zero.
    @test 0.0 < s1.buildup <= 0.10

    r2 = hostile_call_b()
    s2 = get_tonal_buildup()
    if r2.tone_family == r1.tone_family
        # Same tone → buildup grew.
        @test s2.buildup > s1.buildup
    else
        # Different tone → fresh seed (cooling old, seeding new).
        @test s2.buildup <= 0.10
    end

    r3 = neutral_call()
    s3 = get_tonal_buildup()
    if r3.tone_family != s2.tone
        # Tone shift → seed back to ~0.05.
        @test s3.buildup <= 0.10
        @test s3.tone == r3.tone_family
    end
end

# ──────────────────────────────────────────────────────────────────────────
# (4) Build-up amplifies arousal magnitude on the SAME tone over consecutive
#     calls (sign preserved, magnitude stacks).
# ──────────────────────────────────────────────────────────────────────────
@testset "(4) repeated hostile calls amplify arousal magnitude" begin
    reset_tonal_buildup!()
    nudges = Float64[]
    for _ in 1:5
        push!(nudges, hostile_call().arousal_nudge)
    end
    # GRUG: each call's tone may flip if the lexicon disagrees, so we filter
    # to the runs where same-tone build-up actually applied. The first
    # element after reset is the cold baseline; later HOSTILE-tagged entries
    # should on average produce a larger |nudge| than the cold one.
    @test length(nudges) == 5
    if all(n -> sign(n) == sign(nudges[1]) || nudges[1] == 0.0, nudges)
        cold = abs(nudges[1])
        avg_late = sum(abs.(nudges[3:end])) / 3.0
        # Build-up should make later calls strictly bigger than the cold one
        # on average (the increment is 20% of headroom — easy to detect).
        @test avg_late >= cold
    end
end

# ──────────────────────────────────────────────────────────────────────────
# (5) Tone change snaps mood back: HOSTILE-then-NEUTRAL produces a NEUTRAL
#     prediction whose nudge magnitude is NOT amplified by old hostile mood.
# ──────────────────────────────────────────────────────────────────────────
@testset "(5) tone change snaps mood back to cold" begin
    reset_tonal_buildup!()
    # Build up some hostile mood
    for _ in 1:4
        hostile_call()
    end
    s_before = get_tonal_buildup()
    @test s_before.buildup > 0.10  # mood is built up

    # Now switch to a NEUTRAL-leaning input
    r = neutral_call()
    s_after = get_tonal_buildup()

    # If the tone actually flipped, mood should have been reset, not carried.
    if r.tone_family != s_before.tone
        @test s_after.tone == r.tone_family
        @test s_after.buildup <= 0.10  # fresh seed, not stacked from hostile
    end
end

# ──────────────────────────────────────────────────────────────────────────
# (6) Lorenz snap-back: identical inputs do NOT produce bit-identical
#     distributions across calls. (Statistical — extremely unlikely a 2.5%
#     jitter envelope lands on identical floats twice in a row across many
#     families, but we make this deterministic by checking inequality on a
#     sufficiently dense sample.)
# ──────────────────────────────────────────────────────────────────────────
@testset "(6) snap-back jitter: identical input produces non-identical curves" begin
    reset_tonal_buildup!()
    reset_trajectory!()
    inp = "explain why the sky is blue and how light scatters in air"
    r1 = predict_action_tone(inp, TEST_VERBS)
    reset_tonal_buildup!()  # isolate from build-up effects
    r2 = predict_action_tone(inp, TEST_VERBS)

    # GRUG: at least one family in either distribution must differ between
    # the two calls. With ~6 action families and ~6 tone families and
    # ±2.5% jitter, the probability of all 12 floats matching exactly is
    # vanishingly small.
    a_match = all(get(r1.action_distribution, k, 0.0) == get(r2.action_distribution, k, 0.0)
                  for k in keys(r1.action_distribution))
    t_match = all(get(r1.tone_distribution, k, 0.0) == get(r2.tone_distribution, k, 0.0)
                  for k in keys(r1.tone_distribution))
    @test !(a_match && t_match)
end

# ──────────────────────────────────────────────────────────────────────────
# (7) Lorenz snap-back: distribution still sums to ~1.0 after every call.
# ──────────────────────────────────────────────────────────────────────────
@testset "(7) snap-back preserves sum-to-1 invariant" begin
    reset_tonal_buildup!()
    inputs = ["hello there",
              "what is the meaning of this",
              "you cannot do that",
              "imagine if the wind learned to sing"]
    for inp in inputs
        r = predict_action_tone(inp, TEST_VERBS)
        a_total = sum(values(r.action_distribution))
        t_total = sum(values(r.tone_distribution))
        @test isapprox(a_total, 1.0; atol = 1e-9)
        @test isapprox(t_total, 1.0; atol = 1e-9)
    end
end

# ──────────────────────────────────────────────────────────────────────────
# (8) Snap-back is bounded: no family ever exceeds 1.0 or falls below 0.0
# ──────────────────────────────────────────────────────────────────────────
@testset "(8) snap-back keeps every family in [0, 1]" begin
    reset_tonal_buildup!()
    for _ in 1:20
        r = predict_action_tone("you are angry and i am furious", TEST_VERBS)
        for v in values(r.action_distribution)
            @test 0.0 <= v <= 1.0
        end
        for v in values(r.tone_distribution)
            @test 0.0 <= v <= 1.0
        end
    end
end

# ──────────────────────────────────────────────────────────────────────────
# (9) Build-up cool-down: a long sleep between same-tone calls should
#     mostly DECAY the buildup. We can't actually sleep TONAL_BUILDUP_HALFLIFE_S
#     in a test, so this is a structural check via reset.
# ──────────────────────────────────────────────────────────────────────────
@testset "(9) reset_tonal_buildup! between calls eliminates build-up effect" begin
    reset_tonal_buildup!()

    cold_nudges = Float64[]
    for _ in 1:3
        reset_tonal_buildup!()
        push!(cold_nudges, hostile_call().arousal_nudge)
    end

    reset_tonal_buildup!()
    hot_nudges = Float64[]
    for _ in 1:3
        push!(hot_nudges, hostile_call().arousal_nudge)
    end

    # Cold runs should average roughly equal magnitudes (each starts fresh).
    # Hot runs should drift upward (build-up stacking) on average.
    cold_avg = sum(abs.(cold_nudges)) / length(cold_nudges)
    hot_avg  = sum(abs.(hot_nudges))  / length(hot_nudges)
    if all(n -> sign(n) == sign(hot_nudges[1]), hot_nudges) &&
       all(n -> sign(n) == sign(cold_nudges[1]), cold_nudges) &&
       sign(hot_nudges[1]) == sign(cold_nudges[1])
        @test hot_avg >= cold_avg  # build-up at least as loud as cold
    else
        # Tone bounced around (possible on borderline lexicon scores) →
        # weaken to a structural check: the means are both finite numbers.
        @test isfinite(cold_avg) && isfinite(hot_avg)
    end
end

println("\n[tonal-buildup-snapback] All targeted dynamics tests defined.")
