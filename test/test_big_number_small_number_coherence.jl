# test_big_number_small_number_coherence.jl
# ==============================================================================
# GRUG v7.19 — BIG-NUMBER / SMALL-NUMBER COHERENCE TESTS
# ==============================================================================
# Verifies the coherence fusion replacement for naive averaging in
# _bidirectional_cheap_scan. The function must:
#   1. Return near-1.0 when both confidences are strong and close.
#   2. Return near-0.0 when both confidences are tiny ("agreement on noise").
#   3. Return near-0.0 when confidences disagree strongly (even if both big).
#   4. Be immune to catastrophic cancellation between close Float64 values.
#   5. Handle negative confidences symmetrically (evaluate_window can return
#      negative values).
#   6. Reject NaN and Inf LOUDLY (PatternScanError). NO SILENT FAILURES.
#   7. Return values clamped to [0.0, 1.0].
#   8. Be semantically different from arithmetic mean on key edge cases.
#
# Test groups:
#   [A] Basic behavior: strong/strong, weak/weak, mixed
#   [B] Catastrophic cancellation: near-identical floats
#   [C] Asymmetry detection: coherence != average
#   [D] Negative confidence inputs
#   [E] Zero / near-zero inputs
#   [F] Poison input rejection (NaN, Inf)
#   [G] Output range guarantees
#   [H] Monotonicity / ordering sanity checks
#
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test

println("\n" * "="^60)
println("GRUG v7.19 BIG-NUMBER / SMALL-NUMBER COHERENCE TESTS")
println("="^60)

using GrugBot420
const G = GrugBot420

# Grab the function under test from the PatternScanner module.
const bnsnc = G.big_number_small_number_coherence

# Convenience: PatternScanError lives in PatternScanner. GrugBot420 re-exports
# the coherence function but not the error type directly; fetch via the module.
const PSE = G.PatternScanner.PatternScanError

@testset "v7.19 big_number_small_number_coherence" begin

    # --------------------------------------------------------------------------
    # [A] BASIC BEHAVIOR: strong/strong, weak/weak, mixed
    # --------------------------------------------------------------------------
    @testset "[A] basic strong/weak/mixed" begin
        # [A1] Two strong, nearly-identical confidences -> high coherence.
        # agreement = 1 - |0.9-0.9|/0.9 = 1.0
        # magnitude_mean = 0.9
        # coherence = 1.0 * 0.9 = 0.9
        c_strong = bnsnc(0.9, 0.9)
        @test c_strong ≈ 0.9 atol=1e-9

        # [A2] Two tiny, nearly-identical confidences -> low coherence.
        # Even though "agreement" is ~1.0, magnitude_mean is tiny, so
        # coherence is tiny. This is the whole point of the function.
        c_tiny = bnsnc(0.01, 0.01)
        @test c_tiny ≈ 0.01 atol=1e-9
        @test c_tiny < c_strong  # Tiny agreement must score below strong agreement.

        # [A3] Moderate confidence, exact agreement.
        c_mod = bnsnc(0.5, 0.5)
        @test c_mod ≈ 0.5 atol=1e-9

        # [A4] One strong, one zero -> non-trivial but moderate coherence.
        # agreement = 1 - |0.9-0.0|/0.9 = 0.0
        # coherence = 0.0 * 0.45 = 0.0
        c_mixed = bnsnc(0.9, 0.0)
        @test c_mixed ≈ 0.0 atol=1e-9

        # [A5] Strong / half-strong -> agreement partial, magnitude mid.
        # agreement = 1 - |0.9-0.45|/0.9 = 1 - 0.5 = 0.5
        # magnitude_mean = 0.675
        # coherence = 0.5 * 0.675 = 0.3375
        c_half = bnsnc(0.9, 0.45)
        @test c_half ≈ 0.3375 atol=1e-9
    end

    # --------------------------------------------------------------------------
    # [B] CATASTROPHIC CANCELLATION IMMUNITY
    # --------------------------------------------------------------------------
    @testset "[B] catastrophic cancellation immunity" begin
        # [B1] Two confidences differing only in floating-point noise should
        # produce a coherence almost equal to the magnitude_mean, NOT a wild
        # output driven by the tiny difference.
        a = 0.847291234567
        b = a + 1.0e-13  # Sub-ULP-ish noise
        c = bnsnc(a, b)
        # agreement should be ~1.0, coherence ~ magnitude_mean ~ a
        @test c ≈ a atol=1e-6
        @test c > 0.8

        # [B2] Exactly equal values should produce exactly magnitude_mean.
        c_eq = bnsnc(0.5, 0.5)
        @test c_eq == 0.5  # Exact equality — no noise in either operand.

        # [B3] Huge noise between small close values should still behave.
        # Even 1e-8 between two 1e-6 values is a relative delta of 1%,
        # which is fine; coherence should stay near the tiny magnitude_mean.
        c_tiny = bnsnc(1.0e-6, 1.0e-6 + 1.0e-8)
        @test 0.0 <= c_tiny <= 2.0e-6
    end

    # --------------------------------------------------------------------------
    # [C] ASYMMETRY DETECTION: coherence must differ from arithmetic mean
    # --------------------------------------------------------------------------
    @testset "[C] coherence != arithmetic mean on asymmetric inputs" begin
        # [C1] forward=0.9, backward=0.1 and forward=0.5, backward=0.5 both
        # have arithmetic mean 0.5. Coherence must distinguish them.
        c_disagree = bnsnc(0.9, 0.1)  # real disagreement
        c_agree    = bnsnc(0.5, 0.5)  # real agreement

        mean_disagree = (0.9 + 0.1) / 2.0
        mean_agree    = (0.5 + 0.5) / 2.0
        @test mean_disagree == mean_agree   # sanity: naive average is identical

        # Coherence MUST separate the two cases.
        @test c_disagree < c_agree
        @test c_agree - c_disagree > 0.3

        # Math check for c_disagree:
        #   agreement = 1 - |0.9-0.1|/0.9 = 1 - 0.888... = 0.111...
        #   magnitude_mean = 0.5
        #   coherence = 0.111... * 0.5 ≈ 0.0556
        @test c_disagree ≈ (1.0 - 0.8/0.9) * 0.5 atol=1e-9

        # [C2] forward=0.8, backward=0.2 vs forward=0.5, backward=0.5 — same mean.
        c_moderate_disagree = bnsnc(0.8, 0.2)
        @test c_moderate_disagree < c_agree
    end

    # --------------------------------------------------------------------------
    # [D] NEGATIVE CONFIDENCE INPUTS
    # --------------------------------------------------------------------------
    @testset "[D] negative confidences" begin
        # [D1] Two equally-negative confidences: magnitudes agree.
        # agreement = 1 - |(-0.8) - (-0.8)| / 0.8 = 1.0
        # magnitude_mean = 0.8
        # coherence = 0.8
        c_neg_agree = bnsnc(-0.8, -0.8)
        @test c_neg_agree ≈ 0.8 atol=1e-9

        # [D2] Mixed signs, equal magnitude: real disagreement despite same |.|.
        # agreement = 1 - |0.5 - (-0.5)| / 0.5 = 1 - 2.0 = clamped to 0.0
        # coherence = 0.0 * 0.5 = 0.0
        c_opposite = bnsnc(0.5, -0.5)
        @test c_opposite ≈ 0.0 atol=1e-9

        # [D3] Mixed signs, different magnitudes.
        c_mixed = bnsnc(0.9, -0.1)
        # agreement = 1 - |0.9 - (-0.1)|/0.9 = 1 - 1.111... = clamp -> 0.0
        @test c_mixed ≈ 0.0 atol=1e-9
    end

    # --------------------------------------------------------------------------
    # [E] ZERO / NEAR-ZERO INPUTS
    # --------------------------------------------------------------------------
    @testset "[E] zero / near-zero inputs" begin
        # [E1] Both exactly zero -> magnitude_floor below epsilon -> 0.0.
        @test bnsnc(0.0, 0.0) == 0.0

        # [E2] Both under 1e-9 -> still treated as silence.
        @test bnsnc(1.0e-12, 1.0e-12) == 0.0
        @test bnsnc(-1.0e-12, 1.0e-12) == 0.0

        # [E3] One side zero, other non-trivial -> coherence = 0 (max disagreement).
        @test bnsnc(0.0, 0.5) ≈ 0.0 atol=1e-9
        @test bnsnc(0.5, 0.0) ≈ 0.0 atol=1e-9
    end

    # --------------------------------------------------------------------------
    # [F] POISON INPUT REJECTION — NO SILENT FAILURES
    # --------------------------------------------------------------------------
    @testset "[F] NaN / Inf poison rejection" begin
        @test_throws PSE bnsnc(NaN, 0.5)
        @test_throws PSE bnsnc(0.5, NaN)
        @test_throws PSE bnsnc(NaN, NaN)

        @test_throws PSE bnsnc(Inf, 0.5)
        @test_throws PSE bnsnc(0.5, Inf)
        @test_throws PSE bnsnc(-Inf, 0.5)
        @test_throws PSE bnsnc(Inf, -Inf)
    end

    # --------------------------------------------------------------------------
    # [G] OUTPUT RANGE GUARANTEES
    # --------------------------------------------------------------------------
    @testset "[G] output always in [0.0, 1.0]" begin
        # Sweep a bunch of combos and verify no output escapes the range.
        samples = [
            (0.0, 0.0), (1.0, 1.0), (-1.0, -1.0), (1.0, -1.0),
            (0.5, 0.5), (0.9, 0.1), (0.3, 0.7),
            (2.0, 2.0),    # above 1 — function must still return <= 1.0
            (-2.0, -2.0),
            (0.001, 0.002),
            (0.9999, 1.0),
        ]
        for (a, b) in samples
            c = bnsnc(a, b)
            @test 0.0 <= c <= 1.0
            @test !isnan(c)
            @test !isinf(c)
        end
    end

    # --------------------------------------------------------------------------
    # [H] MONOTONICITY / ORDERING SANITY
    # --------------------------------------------------------------------------
    @testset "[H] monotonicity and ordering" begin
        # [H1] Holding forward fixed, increasing backward toward forward
        # should never DECREASE coherence (monotone up to equality).
        fwd = 0.7
        c_near  = bnsnc(fwd, 0.69)
        c_close = bnsnc(fwd, 0.699)
        c_exact = bnsnc(fwd, 0.70)
        @test c_near <= c_close
        @test c_close <= c_exact

        # [H2] Two same-magnitude agreements at different scales: bigger scale
        # MUST produce bigger coherence.
        c_small = bnsnc(0.1, 0.1)
        c_big   = bnsnc(0.9, 0.9)
        @test c_big > c_small

        # [H3] Commutativity: bnsnc(a,b) == bnsnc(b,a) because agreement and
        # magnitude_mean are symmetric.
        @test bnsnc(0.3, 0.8) == bnsnc(0.8, 0.3)
        @test bnsnc(0.1, 0.9) == bnsnc(0.9, 0.1)
        @test bnsnc(-0.4, 0.6) == bnsnc(0.6, -0.4)

        # [H4] Reflexivity at nontrivial magnitude: bnsnc(x, x) == |x| (for |x| <= 1).
        for x in (0.25, 0.5, 0.75, -0.5, -0.25)
            @test bnsnc(x, x) ≈ abs(x) atol=1e-9
        end
    end

end

println("\n" * "="^60)
println("[OK] v7.19 big_number_small_number_coherence — ALL CHECKS PASS")
println("="^60)