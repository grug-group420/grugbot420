# ==============================================================================
# test_relational_jitter.jl — Per-Activation Relational Jitter
# ==============================================================================
# GRUG: Verify the entropy nudge on relational match-score values:
#   1. Zero-mean property ("snap back to normal") over many activations
#   2. Bounded magnitude: no nudge ever exceeds the configured ratio
#   3. Sentinel and zero pass-through (semantic preservation)
#   4. Error handling: NaN, Inf, out-of-bounds ratio all throw LOUD
#   5. Toggle switch: disable_jitter! → exact identity
#   6. Thread safety under concurrent activation
#   7. Integration with evaluate_relational_dialectics (downstream effect)
# NO SILENT FAILURES. Every failure mode is surfaced with context.
# ==============================================================================

using Test
using Random
using Statistics
using Base.Threads

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
const SRC_DIR   = joinpath(REPO_ROOT, "src")

# GRUG: Isolated include — same pattern as the other test files.
include(joinpath(SRC_DIR, "RelationalJitter.jl"))
using .RelationalJitter

# GRUG: engine.jl pulls RelationalJitter too (for the dialectics integration
# test). We need SemanticVerbs first (engine depends on it). Use the same
# isolated-subprocess include chain other test files use.
include(joinpath(SRC_DIR, "stochastichelper.jl"))
using .CoinFlipHeader
include(joinpath(SRC_DIR, "patternscanner.jl"))
using .PatternScanner
include(joinpath(SRC_DIR, "ImageSDF.jl"))
using .ImageSDF
include(joinpath(SRC_DIR, "SemanticVerbs.jl"))
using .SemanticVerbs
include(joinpath(SRC_DIR, "VoteOrchestrator.jl"))
using .VoteOrchestrator

# Needed by engine.jl's full include chain — mirror engine.jl's upstream deps.
include(joinpath(SRC_DIR, "EyeSystem.jl"))
using .EyeSystem
include(joinpath(SRC_DIR, "ActionTonePredictor.jl"))
using .ActionTonePredictor
include(joinpath(SRC_DIR, "LobeTable.jl"))
using .LobeTable
include(joinpath(SRC_DIR, "Lobe.jl"))
using .Lobe
include(joinpath(SRC_DIR, "BrainStem.jl"))
using .BrainStem
include(joinpath(SRC_DIR, "Thesaurus.jl"))
using .Thesaurus
include(joinpath(SRC_DIR, "InputQueue.jl"))
using .InputQueue
include(joinpath(SRC_DIR, "ChatterMode.jl"))
using .ChatterMode
include(joinpath(SRC_DIR, "PhagyMode.jl"))
using .PhagyMode
include(joinpath(SRC_DIR, "ImmuneSystem.jl"))
using .ImmuneSystem
include(joinpath(SRC_DIR, "ImmuneThreadPool.jl"))
using .ImmuneThreadPool
include(joinpath(SRC_DIR, "FullLobeScanner.jl"))
using .FullLobeScanner
include(joinpath(SRC_DIR, "AIMLNodeSystem.jl"))
using .AIMLNodeSystem

# engine.jl is NOT wrapped in a module — it defines symbols at the current scope.
include(joinpath(SRC_DIR, "engine.jl"))

println("\n" * "="^70)
println("🧠 GRUG: RELATIONAL JITTER TESTS")
println("="^70 * "\n")

# ============================================================================
# TEST GROUP 1 — Core primitive: jitter_value basic contract
# ============================================================================
@testset "[1] jitter_value: basic contract" begin
    # GRUG: Default state — enabled at module load.
    @test RelationalJitter.is_jitter_enabled() == true

    # GRUG: Default ratio matches constant.
    @test RelationalJitter.get_jitter_ratio() == RelationalJitter.JITTER_RATIO_DEFAULT

    # GRUG: Zero stays zero — no denormal leakage.
    @test RelationalJitter.jitter_value(0.0) == 0.0

    # GRUG: Effectively-zero stays as-is (below JITTER_EPS_FLOOR).
    @test RelationalJitter.jitter_value(1e-15) == 1e-15

    # GRUG: Sentinel propagates UNTOUCHED — critical for the hard-requirement-miss contract.
    @test RelationalJitter.jitter_value(RelationalJitter.HARD_REQ_MISS_SENTINEL) ==
          RelationalJitter.HARD_REQ_MISS_SENTINEL

    println("  ✓ zero, near-zero, and sentinel all pass through")
end

# ============================================================================
# TEST GROUP 2 — Magnitude bound: jitter never exceeds ratio * |x|
# ============================================================================
@testset "[2] jitter_value: magnitude bounded by ratio" begin
    Random.seed!(12345)

    ratio = RelationalJitter.get_jitter_ratio()
    xs = [1.0, 2.0, 0.5, -1.0, -2.0, 10.0, 100.0]

    for x in xs
        max_abs_dev = 0.0
        for _ in 1:5_000
            j = RelationalJitter.jitter_value(x)
            dev = abs(j - x)
            max_abs_dev = max(max_abs_dev, dev)
        end
        # GRUG: Observed max deviation must not exceed ratio * |x| + tiny float slack.
        # Plus the absolute cap — whichever is tighter.
        theoretical_bound = min(ratio * abs(x), RelationalJitter.JITTER_ABS_CAP) + 1e-12
        @test max_abs_dev <= theoretical_bound
    end

    println("  ✓ 5,000 samples per value stayed inside ratio·|x| bound")
end

# ============================================================================
# TEST GROUP 3 — Zero-mean ("snap back to normal" statistical property)
# ============================================================================
@testset "[3] jitter_value: zero-mean convergence" begin
    Random.seed!(67890)

    N = 20_000
    for x in [1.0, 5.0, -3.0, 10.0]
        samples = [RelationalJitter.jitter_value(x) for _ in 1:N]
        observed_mean = mean(samples)

        # GRUG: With N=20k and ε=0.03, the standard error on the mean is
        # σ/√N = (ε·|x|/√3)/√N. For x=10.0 that is ≈ 0.0012, so a 4σ
        # tolerance is ~0.005. We use 0.01·|x| as a generous bound that
        # still catches any sign bias.
        tolerance = 0.01 * abs(x)
        @test abs(observed_mean - x) < tolerance
    end

    println("  ✓ empirical mean over 20k activations snaps back within 1%·|x|")
end

# ============================================================================
# TEST GROUP 4 — Every call is independent (no persistence)
# ============================================================================
@testset "[4] jitter_value: no persistent state" begin
    Random.seed!(111)

    # GRUG: Consecutive calls on the same x should differ (almost surely)
    # — that's the whole point. If two equal, sample again.
    distinct = 0
    a = RelationalJitter.jitter_value(1.0)
    for _ in 1:20
        b = RelationalJitter.jitter_value(1.0)
        if a != b
            distinct += 1
        end
        a = b
    end
    # GRUG: Out of 20 consecutive calls, the overwhelming majority must differ.
    @test distinct >= 18

    println("  ✓ 18+/20 consecutive calls produced fresh nudges")
end

# ============================================================================
# TEST GROUP 5 — Error handling: NaN, Inf, bad ratio
# ============================================================================
@testset "[5] jitter_value: error handling (no silent failures)" begin
    # GRUG: NaN input must throw, not return NaN.
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(NaN)

    # GRUG: Inf input must throw, not saturate.
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(Inf)
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(-Inf)

    # GRUG: Out-of-range ratio via kwarg must throw.
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(1.0; ratio = -0.01)
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(1.0;
        ratio = RelationalJitter.JITTER_RATIO_MAX + 0.01)
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(1.0; ratio = NaN)
    @test_throws RelationalJitter.JitterError RelationalJitter.jitter_value(1.0; ratio = Inf)

    # GRUG: Global setter rejects bad values too.
    @test_throws RelationalJitter.JitterError RelationalJitter.set_jitter_ratio!(-0.1)
    @test_throws RelationalJitter.JitterError RelationalJitter.set_jitter_ratio!(NaN)
    @test_throws RelationalJitter.JitterError RelationalJitter.set_jitter_ratio!(
        RelationalJitter.JITTER_RATIO_MAX + 0.5)

    # GRUG: JitterConfig constructor rejects bad values.
    @test_throws RelationalJitter.JitterError RelationalJitter.JitterConfig(-0.1, true)
    @test_throws RelationalJitter.JitterError RelationalJitter.JitterConfig(NaN, true)

    println("  ✓ NaN, Inf, out-of-range ratios all throw LOUD")
end

# ============================================================================
# TEST GROUP 6 — Global toggle: disable_jitter! → exact identity
# ============================================================================
@testset "[6] jitter toggle: disable/enable roundtrip" begin
    RelationalJitter.disable_jitter!()
    @test RelationalJitter.is_jitter_enabled() == false

    # GRUG: When disabled, every call returns bit-exact input.
    for x in [1.0, 2.5, -3.14, 0.0, 100.0]
        for _ in 1:100
            @test RelationalJitter.jitter_value(x) === x
        end
    end

    RelationalJitter.enable_jitter!()
    @test RelationalJitter.is_jitter_enabled() == true

    println("  ✓ disable yields bit-exact identity; re-enable restores nudge")
end

# ============================================================================
# TEST GROUP 7 — Ratio setter roundtrip + custom ratio kwarg
# ============================================================================
@testset "[7] set_jitter_ratio! roundtrip" begin
    original = RelationalJitter.get_jitter_ratio()

    # GRUG: Valid ratios round-trip.
    RelationalJitter.set_jitter_ratio!(0.01)
    @test RelationalJitter.get_jitter_ratio() == 0.01

    RelationalJitter.set_jitter_ratio!(0.0)  # zero is legal — means "no nudge"
    @test RelationalJitter.get_jitter_ratio() == 0.0

    # GRUG: At ratio = 0.0, output == input exactly (no entropy to add).
    for x in [1.0, 2.5, 10.0]
        for _ in 1:50
            @test RelationalJitter.jitter_value(x) == x
        end
    end

    # GRUG: Upper bound accepted.
    RelationalJitter.set_jitter_ratio!(RelationalJitter.JITTER_RATIO_MAX)
    @test RelationalJitter.get_jitter_ratio() == RelationalJitter.JITTER_RATIO_MAX

    # GRUG: Per-call ratio override works.
    Random.seed!(2024)
    samples = [RelationalJitter.jitter_value(1.0; ratio = 0.01) for _ in 1:1000]
    @test maximum(abs.(samples .- 1.0)) <= 0.01 + 1e-12

    # GRUG: Restore default for downstream tests.
    RelationalJitter.set_jitter_ratio!(original)
    @test RelationalJitter.get_jitter_ratio() == original

    println("  ✓ ratio round-trips; ratio=0.0 is exact identity; per-call override works")
end

# ============================================================================
# TEST GROUP 8 — Semantic wrappers
# ============================================================================
@testset "[8] semantic wrappers: jitter_score, jitter_weight" begin
    Random.seed!(4242)

    # GRUG: Wrappers delegate to jitter_value — same invariants.
    for _ in 1:500
        @test abs(RelationalJitter.jitter_score(1.0) - 1.0) <= RelationalJitter.get_jitter_ratio()
        @test abs(RelationalJitter.jitter_weight(2.0) - 2.0) <= 2.0 * RelationalJitter.get_jitter_ratio()
    end

    # GRUG: Sign preserved — positive weights stay positive at default ratio (<1.0).
    for _ in 1:500
        w = RelationalJitter.jitter_weight(1.0)
        @test w > 0.0
    end

    # GRUG: Sentinel propagates through wrappers too.
    @test RelationalJitter.jitter_score(RelationalJitter.HARD_REQ_MISS_SENTINEL) ==
          RelationalJitter.HARD_REQ_MISS_SENTINEL

    println("  ✓ wrappers preserve sign, respect bound, propagate sentinel")
end

# ============================================================================
# TEST GROUP 9 — Thread safety under concurrent activation
# ============================================================================
@testset "[9] thread safety: concurrent jitter calls" begin
    # GRUG: Hammer the jitter from multiple threads. Must not produce NaN,
    # Inf, or crash, and each thread's samples must stay within bounds.
    N_THREADS = max(2, Threads.nthreads())
    N_PER = 2_000

    results = Vector{Vector{Float64}}(undef, N_THREADS)
    @threads for t in 1:N_THREADS
        local_samples = Float64[]
        for _ in 1:N_PER
            push!(local_samples, RelationalJitter.jitter_value(1.0))
        end
        results[t] = local_samples
    end

    # GRUG: Validate ALL samples from ALL threads.
    all_samples = vcat(results...)
    @test length(all_samples) == N_THREADS * N_PER
    @test all(isfinite, all_samples)
    @test maximum(abs.(all_samples .- 1.0)) <= RelationalJitter.get_jitter_ratio() + 1e-12
    # GRUG: Aggregate mean still snaps back.
    @test abs(mean(all_samples) - 1.0) < 0.01

    println("  ✓ $(N_THREADS) threads × $(N_PER) samples: all finite, bounded, zero-mean")
end

# ============================================================================
# TEST GROUP 10 — JitterConfig struct
# ============================================================================
@testset "[10] JitterConfig struct" begin
    cfg = RelationalJitter.JitterConfig(0.02, true)
    @test cfg.ratio == 0.02
    @test cfg.enabled == true

    cfg_off = RelationalJitter.JitterConfig(0.02, false)
    @test cfg_off.enabled == false

    # GRUG: Zero is a legal config — means "I explicitly want identity".
    cfg_zero = RelationalJitter.JitterConfig(0.0, true)
    @test cfg_zero.ratio == 0.0

    println("  ✓ JitterConfig constructs and validates")
end

# ============================================================================
# TEST GROUP 11 — Integration with evaluate_relational_dialectics
# ============================================================================
@testset "[11] integration: evaluate_relational_dialectics snap-back" begin
    Random.seed!(98765)

    # GRUG: Build a tiny deterministic relational triple matchup and score
    # it many times. The mean score should converge to the jitter-off score.

    user  = [RelationalTriple("a", "causes", "b")]
    node  = [RelationalTriple("a", "causes", "b")]  # exact match → +2.0 * 1.0
    req   = String[]
    wts   = Dict{String, Float64}()

    # Deterministic baseline (jitter OFF).
    RelationalJitter.disable_jitter!()
    det_score, det_antim = evaluate_relational_dialectics(user, node, req, wts)
    @test det_antim == false
    @test det_score == 2.0
    RelationalJitter.enable_jitter!()

    # GRUG: Jittered runs — each call fresh nudge, mean should snap back.
    N = 3_000
    scores = Float64[]
    for _ in 1:N
        s, a = evaluate_relational_dialectics(user, node, req, wts)
        @test a == false   # antimatch flag never flips
        @test isfinite(s)  # no NaN / Inf leak
        push!(scores, s)
    end

    # GRUG: Bound — every single score within ratio × 2.0 of 2.0. Because
    # weight AND the 2.0*weight product both get nudged, upper bound is
    # compound: (1+ε)·(1+ε)·2.0. At ε=0.03 that's 2.0·1.0609 ≈ 2.122.
    ε = RelationalJitter.get_jitter_ratio()
    compound_bound = 2.0 * (1.0 + ε) * (1.0 + ε) + 1e-9
    @test maximum(scores) <= compound_bound
    @test minimum(scores) >= 2.0 * (1.0 - ε) * (1.0 - ε) - 1e-9

    # GRUG: Mean snap-back. Both nudges are zero-mean so the product is
    # also zero-mean to first order: E[(1+δw)(1+δs)·2] = 2·(1 + E[δw]·E[δs])
    # = 2 (since δw ⊥ δs, both zero-mean). Tolerate 1% slack.
    obs_mean = mean(scores)
    @test abs(obs_mean - 2.0) < 0.02

    println("  ✓ dialectics: det=2.0, jittered mean=$(round(obs_mean, digits=4)), " *
            "range=[$(round(minimum(scores), digits=4)), $(round(maximum(scores), digits=4))]")
end

# ============================================================================
# TEST GROUP 12 — Sentinel preservation through dialectics
# ============================================================================
@testset "[12] integration: hard-requirement-miss sentinel never jittered" begin
    # GRUG: If required_relations contains a verb the user DIDN'T use,
    # the function must return exactly -9999.0 — not -9998.7 or -9999.2.
    # Jitter must not touch the sentinel path.
    user  = [RelationalTriple("a", "causes", "b")]
    node  = [RelationalTriple("x", "requires", "y")]
    req   = ["requires"]   # user did not use this verb
    wts   = Dict{String, Float64}()

    # GRUG: Run many times — every single result must be EXACTLY -9999.0.
    for _ in 1:500
        s, a = evaluate_relational_dialectics(user, node, req, wts)
        @test s == -9999.0
        @test a == false
    end

    println("  ✓ sentinel -9999.0 returned exactly on every one of 500 calls")
end

# ============================================================================
# TEST GROUP 13 — Antimatch path still flips flag correctly under jitter
# ============================================================================
@testset "[13] integration: antimatch detection robust under jitter" begin
    Random.seed!(31415)

    # GRUG: User says "a causes b", node says "b causes a" — reversed →
    # antimatch → match_score goes -2.0 * weight. Flag must always flip.
    user  = [RelationalTriple("a", "causes", "b")]
    node  = [RelationalTriple("b", "causes", "a")]
    req   = String[]
    wts   = Dict{String, Float64}()

    flip_count = 0
    for _ in 1:1_000
        s, a = evaluate_relational_dialectics(user, node, req, wts)
        if a
            flip_count += 1
        end
        @test isfinite(s)
        @test s < 0.0   # antimatch score is negative even after jitter
    end
    # GRUG: Antimatch is deterministic on triple contents — flag always flips.
    @test flip_count == 1_000

    println("  ✓ antimatch flag deterministic; score sign preserved under jitter")
end

# ============================================================================
# TEST GROUP 14 — Disabled jitter makes dialectics bit-exact
# ============================================================================
@testset "[14] integration: disable_jitter! → deterministic dialectics" begin
    user  = [RelationalTriple("a", "causes", "b")]
    node  = [RelationalTriple("a", "causes", "b")]
    req   = String[]
    wts   = Dict{String, Float64}()

    RelationalJitter.disable_jitter!()
    first_score, first_antim = evaluate_relational_dialectics(user, node, req, wts)
    for _ in 1:200
        s, a = evaluate_relational_dialectics(user, node, req, wts)
        @test s === first_score
        @test a === first_antim
    end
    RelationalJitter.enable_jitter!()

    println("  ✓ with jitter disabled, 200 identical calls return bit-exact score")
end

println("\n" * "="^70)
println("✅ RELATIONAL JITTER TESTS COMPLETE")
println("="^70 * "\n")