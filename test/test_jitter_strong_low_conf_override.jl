# test_jitter_strong_low_conf_override.jl
# ==============================================================================
# GRUG v7.15 TESTS --- RelationalJitter strong-node-low-confidence override
#                       (NONJITTER tag does NOT apply in that corner)
# ==============================================================================

using Test
using GrugBot420
using GrugBot420.RelationalJitter
using GrugBot420.RelationalJitter:
    strong_low_conf_override, jitter_score_with_override,
    NONJITTER_OVERRIDE_STRENGTH_FLOOR, NONJITTER_OVERRIDE_CONF_CEIL,
    JitterError

println("\n" * "=" ^ 60)
println("GRUG v7.15 Strong-Low-Conf Jitter Override TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] PREDICATE --- truthful at the four corners
# ==============================================================================
@testset "strong_low_conf_override: four corners" begin
    # GRUG: Strong + low-conf => override triggers.
    @test strong_low_conf_override(9.0, 0.10) == true
    @test strong_low_conf_override(NONJITTER_OVERRIDE_STRENGTH_FLOOR,
                                   NONJITTER_OVERRIDE_CONF_CEIL - 0.01) == true

    # GRUG: Strong + high-conf => no override.
    @test strong_low_conf_override(9.0, 0.80) == false

    # GRUG: Weak + low-conf => no override.
    @test strong_low_conf_override(2.0, 0.10) == false

    # GRUG: Weak + high-conf => no override.
    @test strong_low_conf_override(2.0, 0.80) == false

    # GRUG: Exactly on the strength floor, below the conf ceiling => override.
    @test strong_low_conf_override(NONJITTER_OVERRIDE_STRENGTH_FLOOR, 0.20) == true

    # GRUG: Exactly on the conf ceiling (not below) => no override.
    @test strong_low_conf_override(NONJITTER_OVERRIDE_STRENGTH_FLOOR,
                                   NONJITTER_OVERRIDE_CONF_CEIL) == false
end

# ==============================================================================
# [2] PREDICATE --- bad inputs throw loudly
# ==============================================================================
@testset "strong_low_conf_override: NaN/Inf rejected" begin
    @test_throws JitterError strong_low_conf_override(NaN, 0.5)
    @test_throws JitterError strong_low_conf_override(5.0, NaN)
    @test_throws JitterError strong_low_conf_override(Inf, 0.5)
    @test_throws JitterError strong_low_conf_override(5.0, -Inf)
end

# ==============================================================================
# [3] HELPER --- honors nonjitter flag when override does NOT trigger
# ==============================================================================
@testset "jitter_score_with_override: nonjitter=true, not overridden" begin
    # GRUG: Strong + HIGH conf + nonjitter=true => identity.
    out = jitter_score_with_override(
        0.85;
        strength = 9.0,
        nonjitter = true,
        confidence = 0.85,
    )
    @test out == 0.85
end

# ==============================================================================
# [4] HELPER --- override trumps nonjitter when strong + low conf
# ==============================================================================
@testset "jitter_score_with_override: strong-low-conf bypasses nonjitter" begin
    # GRUG: Use deterministic seed so we can prove jitter was actually applied.
    # A strong, low-conf node with nonjitter=true should STILL receive jitter.
    # We sample many times and confirm at least one deviation from the input.
    RelationalJitter.enable_jitter!()
    RelationalJitter.set_jitter_ratio!(0.05)

    inputs = [0.20 for _ in 1:500]
    outputs = [jitter_score_with_override(
                    x;
                    strength = 9.0,
                    nonjitter = true,      # tag set
                    confidence = 0.15,     # low-conf -> override fires
                )
               for x in inputs]

    # GRUG: At least SOME outputs must differ from 0.20 (i.e. jitter fired).
    different = count(o -> abs(o - 0.20) > 1e-9, outputs)
    @test different > 0

    # GRUG: All outputs must stay within the jitter window bounds.
    for (i, o) in enumerate(outputs)
        @test abs(o - 0.20) <= 0.05 * 0.20 + 1e-9
    end
end

# ==============================================================================
# [5] HELPER --- nonjitter=false always jitters regardless of strength/conf
# ==============================================================================
@testset "jitter_score_with_override: nonjitter=false always jitters" begin
    RelationalJitter.enable_jitter!()
    RelationalJitter.set_jitter_ratio!(0.05)

    inputs = [0.5 for _ in 1:500]
    outputs = [jitter_score_with_override(
                    x;
                    strength = 2.0,        # weak
                    nonjitter = false,     # not tagged
                    confidence = 0.95,     # high-conf
                )
               for x in inputs]

    different = count(o -> abs(o - 0.5) > 1e-9, outputs)
    @test different > 0
end

# ==============================================================================
# [6] GLOBAL TOGGLE --- disabled jitter returns identity everywhere
# ==============================================================================
@testset "jitter_score_with_override: global disable is orthogonal" begin
    RelationalJitter.disable_jitter!()
    try
        # Even the override corner returns identity when jitter is globally off.
        out = jitter_score_with_override(
            0.20;
            strength = 9.0,
            nonjitter = true,
            confidence = 0.10,
        )
        @test out == 0.20
    finally
        RelationalJitter.enable_jitter!()
    end
end

println("\n" * "=" ^ 60)
println("\u2705  Strong-Low-Conf override tests COMPLETE")
println("=" ^ 60)
