# ==============================================================================
# test/test_v7_21a.jl  —  Foundation tests for emotional-coherence work
# ==============================================================================
# v7.21a ships the foundation that v7.21b's tonal observer will sit on top of:
#
#   1. Per-query action curve (no cross-query memory in the predictor)
#   2. Tone-first ordering (tone observed before action; tone conditions
#      the action prior BEFORE action lexicon scoring runs)
#   3. Curve snap-back jitter (identical inputs produce different curve
#      shapes within a bounded envelope; same family winner preserved on
#      clear signals)
#
# This file exercises each property in isolation with concrete assertions
# so that v7.21b can build on a load-bearing foundation.
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

# GRUG: We include the whole engine pipeline because predict_action_tone
# pulls in marker tables, enums, and the trajectory config — same pattern
# as the v7.20 test file.
const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

const ATP = ActionTonePredictor

println("\n" * "="^70)
println("GRUG v7.21a — foundation tests (per-query curve + tone-first + jitter)")
println("="^70)

# Empty verb set is fine for these tests; the dangling-chain detector is
# what consumes verbs and we're not exercising that here.
const _VERBS = Set{String}()

# ============================================================================
# Test 1: Per-query — predictor does NOT accumulate trajectory state during
# normal prediction. The buffer stays empty across many calls.
# ============================================================================

@testset "v7.21a per-query: buffer stays empty across predictions" begin
    # GRUG: Make sure we start clean. reset_trajectory! is part of the
    # preserved API and should still empty the buffer.
    ATP.reset_trajectory!()
    @test isempty(ATP._trajectory_buffer)

    # Run a batch of predictions of varying tonal flavors.
    inputs = String[
        "what is happening here",
        "you are wrong stupid",
        "maybe it could be okay",
        "RUN THE TESTS NOW",
        "hello there friend",
        "i wonder why",
    ]
    for txt in inputs
        ATP.predict_action_tone(txt, _VERBS)
    end

    # GRUG: Buffer must still be empty. The predictor is no longer a writer.
    @test isempty(ATP._trajectory_buffer)
end

# ============================================================================
# Test 2: Per-query — query N's distribution does not depend on query N-1.
# The same input gives the same DISTRIBUTION SHAPE (modulo jitter) regardless
# of what was predicted just before.
# ============================================================================

@testset "v7.21a per-query: no cross-query bleed in distribution shape" begin
    ATP.reset_trajectory!()

    # Pre-load with 5 hostile predictions. Under the OLD (session-spanning)
    # behavior, this would load HOSTILE/NEGATE mass into the centroid and
    # the next prediction would get damped against that history.
    for _ in 1:5
        ATP.predict_action_tone("you stupid wrong garbage idiot", _VERBS)
    end

    # GRUG: Now ask a clean curious question. Under per-query semantics
    # the action distribution should be QUERY-dominant — the previous
    # hostile predictions should have left no trace.
    Random.seed!(42)
    res = ATP.predict_action_tone("what causes the crash?", _VERBS)
    @test res.action_family == ATP.ACTION_QUERY

    # GRUG: ACTION_QUERY should hold a comfortable plurality of the
    # post-curve distribution. We don't pin an exact value because
    # softmax temperature flattens, but the winner should clearly lead.
    qmass = res.action_distribution[ATP.ACTION_QUERY]
    other_max = maximum(v for (k, v) in res.action_distribution if k != ATP.ACTION_QUERY)
    @test qmass > other_max
end

# ============================================================================
# Test 3: Tone-first — observed HOSTILE tone tilts the action distribution
# toward ACTION_NEGATE even when no action marker is present. This is the
# load-bearing property of the reorder.
# ============================================================================

@testset "v7.21a tone-first: HOSTILE tone tilts action toward NEGATE" begin
    ATP.reset_trajectory!()

    # GRUG: This input has HOSTILE_MARKERS (stupid, wrong, garbage) but
    # NO action markers (no ?, no command verbs, no negation words like
    # "never"/"not"). Under the OLD ordering action would default to
    # ASSERT. Under tone-first, observed HOSTILE tone applies a +0.7
    # NEGATE prior that should dominate.
    res = ATP.predict_action_tone("you stupid wrong garbage", _VERBS)

    @test res.tone_family   == ATP.TONE_HOSTILE
    @test res.action_family == ATP.ACTION_NEGATE

    # GRUG: ACTION_ASSERT (the old default) should NOT win.
    @test res.action_distribution[ATP.ACTION_ASSERT] <
          res.action_distribution[ATP.ACTION_NEGATE]
end

# ============================================================================
# Test 4: Tone-first — observed REFLECTIVE tone tilts toward SPECULATE.
# Different prior, same mechanism. This catches the case where the prior
# table works for one tone but is wired wrong for others.
# ============================================================================

@testset "v7.21a tone-first: REFLECTIVE tone tilts action toward SPECULATE" begin
    ATP.reset_trajectory!()

    # GRUG: Reflective markers, no action markers. Should land on SPECULATE.
    res = ATP.predict_action_tone("perhaps this could maybe happen somehow", _VERBS)

    @test res.tone_family == ATP.TONE_REFLECTIVE
    @test res.action_family == ATP.ACTION_SPECULATE
end

# ============================================================================
# Test 5: Tone-first — clear action markers still dominate over tone prior.
# The prior is a TILT, not an OVERRIDE. A loud "?" should still win QUERY
# even if the tone is HOSTILE.
# ============================================================================

@testset "v7.21a tone-first: action markers still dominate over tone prior" begin
    ATP.reset_trajectory!()

    # GRUG: Hostile tone but explicit query — "?" gives +1.5 to QUERY which
    # should clearly outweigh the HOSTILE → NEGATE prior of +0.7.
    res = ATP.predict_action_tone("why is this stupid garbage broken?", _VERBS)

    @test res.tone_family == ATP.TONE_HOSTILE
    @test res.action_family == ATP.ACTION_QUERY
end

# ============================================================================
# Test 6: Curve jitter — same input twice produces different curve SHAPES.
# The mass diff between two calls on the same input is bounded but non-zero.
# ============================================================================

@testset "v7.21a curve jitter: same input → different curve shape" begin
    ATP.reset_trajectory!()

    Random.seed!(101)
    r1 = ATP.predict_action_tone("what causes this", _VERBS)
    Random.seed!(202)
    r2 = ATP.predict_action_tone("what causes this", _VERBS)

    # GRUG: Total absolute mass difference across all six families.
    # Under jitter envelope of 0.03, expect diff in the [0.001, 0.4] range.
    diff = sum(abs(r1.action_distribution[k] - r2.action_distribution[k])
               for k in keys(r1.action_distribution))
    @test diff > 0.0
    @test diff < 0.4   # bounded — jitter never goes wild

    # GRUG: Same family winner must survive the jitter on a clear signal.
    @test r1.action_family == r2.action_family
end

# ============================================================================
# Test 7: Curve jitter — bounded envelope. No family ever moves more than
# a small fraction of its mass per call.
# ============================================================================

@testset "v7.21a curve jitter: per-family movement is bounded" begin
    ATP.reset_trajectory!()

    # Run many calls and track the maximum per-family delta we see.
    deltas = Float64[]
    base = ATP.predict_action_tone("run the tests now", _VERBS)
    for _ in 1:20
        r = ATP.predict_action_tone("run the tests now", _VERBS)
        for k in keys(r.action_distribution)
            push!(deltas, abs(r.action_distribution[k] - base.action_distribution[k]))
        end
    end

    # GRUG: With CURVE_JITTER_ENVELOPE = 0.03, single-call multiplicative
    # bound is ~3% of mass; after re-normalize, observed deltas can drift
    # somewhat further. We accept up to 0.15 as the empirical ceiling for
    # any single family on a clear-signal input.
    @test maximum(deltas) < 0.15
end

# ============================================================================
# Test 8: Per-query Gini damping — a deliberately concentrated current
# distribution should still trigger trajectory_damped=true. The damper
# now operates on the current query, not on history.
# ============================================================================

@testset "v7.21a per-query damping: concentrated current curve still damps" begin
    ATP.reset_trajectory!()

    # GRUG: Pile every action marker onto QUERY to force concentration.
    # Multiple "?", multiple QUERY_MARKERS — the curve should be heavily
    # tilted toward ACTION_QUERY, which (per the per-query Gini check)
    # should fire damping.
    res = ATP.predict_action_tone(
        "what why how when where which what why how when",
        _VERBS
    )

    # GRUG: Either damping fired (preferred outcome on this concentrated
    # input) OR the input was not concentrated enough by the Gini metric
    # — in which case we still want a sane prediction.
    @test res.action_family == ATP.ACTION_QUERY
    # Gini threshold default is 0.72; this input should clear it.
    @test res.trajectory_damped == true
end

# ============================================================================
# Test 9: API preservation — the trajectory API still works for callers
# that depend on it (tests, specimen save/load, /status diagnostics).
# ============================================================================

@testset "v7.21a API preservation: trajectory API still callable" begin
    ATP.reset_trajectory!()
    @test isempty(ATP._trajectory_buffer)

    # get_trajectory_state should return a tuple even on an empty buffer.
    state = ATP.get_trajectory_state()
    @test length(state) == 5
    @test state[5] == 0   # buffer length

    # set_trajectory_config! should accept a valid config and reject bad ones.
    valid_cfg = ATP.TrajectoryConfig(8, 60.0, 0.5, 0.3, 1.2)
    ATP.set_trajectory_config!(valid_cfg)
    @test ATP._trajectory_config[].buffer_size == 8

    # FATAL on bad config — buffer_size <= 0.
    bad_cfg = ATP.TrajectoryConfig(0, 60.0, 0.5, 0.3, 1.2)
    @test_throws ErrorException ATP.set_trajectory_config!(bad_cfg)

    # Restore default for downstream tests.
    ATP.set_trajectory_config!(ATP.DEFAULT_TRAJECTORY_CONFIG)
end

println("\n" * "="^70)
println("✅  All v7.21a foundation tests passed.")
println("="^70)
