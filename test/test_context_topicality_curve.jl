# test_context_topicality_curve.jl
# ==============================================================================
# GRUG v7.26 TESTS --- Context topicality curve in LobeOrchestrator
# ==============================================================================
# Tests that domain-relevant lobes get an ordering boost via
# curved_avg = avg_conf * (1.0 + CAP * topicality).
# Zero topicality = no boost (v7.24 behavior). High topicality = proportional
# boost. The curve only affects ORDERING, not admission (no muting).
# ==============================================================================

using Test
using Random

include("../src/LobeOrchestrator.jl")
using .LobeOrchestrator

println("\n" * "=" ^ 60)
println("GRUG v7.26 Context Topicality Curve TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] CURVE FORMULA --- curved_avg = avg_conf * (1.0 + CAP * topicality)
# ==============================================================================
@testset "[1] curve formula math" begin
    votes = Dict(
        "lobe_a" => [0.60, 0.60],  # avg = 0.60
    )

    # topicality = 0.0 → no boost
    s0 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_a" => 0.0))
    @test length(s0) == 1
    @test isapprox(s0[1].curved_avg, 0.60; atol = 1e-9)
    @test isapprox(s0[1].topicality, 0.0; atol = 1e-9)

    # topicality = 1.0 → max boost: 0.60 * (1.0 + 0.25 * 1.0) = 0.75
    s1 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_a" => 1.0))
    @test isapprox(s1[1].curved_avg, 0.60 * 1.25; atol = 1e-9)
    @test isapprox(s1[1].topicality, 1.0; atol = 1e-9)

    # topicality = 0.5 → half boost: 0.60 * (1.0 + 0.25 * 0.5) = 0.675
    s05 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_a" => 0.5))
    @test isapprox(s05[1].curved_avg, 0.60 * 1.125; atol = 1e-9)

    # avg_conf unchanged by curve
    @test isapprox(s0[1].avg_conf, 0.60; atol = 1e-9)
    @test isapprox(s1[1].avg_conf, 0.60; atol = 1e-9)
    @test isapprox(s05[1].avg_conf, 0.60; atol = 1e-9)
end

# ==============================================================================
# [2] ORDERING BOOST --- relevant lobe beats irrelevant with higher curved_avg
# ==============================================================================
@testset "[2] topical lobe sorts above irrelevant with same raw avg" begin
    votes = Dict(
        "physics"  => [0.70, 0.70],  # avg = 0.70
        "cooking"  => [0.70, 0.70],  # avg = 0.70
    )

    # physics is topical (0.8), cooking is not (0.0)
    topicalities = Dict("physics" => 0.8, "cooking" => 0.0)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)

    # Both have same avg_conf, but physics has higher curved_avg
    @test summaries[1].lobe_id == "physics"
    @test summaries[1].curved_avg > summaries[2].curved_avg
    @test isapprox(summaries[1].curved_avg, 0.70 * 1.20; atol = 1e-9)  # 0.84
    @test isapprox(summaries[2].curved_avg, 0.70; atol = 1e-9)
end

# ==============================================================================
# [3] CURVE DOES NOT OVERRIDE STRONG SIGNAL --- weak relevant doesn't beat
#     strong irrelevant unless the boost closes the gap
# ==============================================================================
@testset "[3] curve doesn't override strong signal" begin
    votes = Dict(
        "physics"  => [0.55, 0.55],  # avg = 0.55
        "cooking"  => [0.85, 0.85],  # avg = 0.85
    )

    # physics is very topical (1.0), cooking is not (0.0)
    topicalities = Dict("physics" => 1.0, "cooking" => 0.0)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)

    # cooking still wins: 0.85 > 0.55 * 1.25 = 0.6875
    @test summaries[1].lobe_id == "cooking"
    @test summaries[1].curved_avg > summaries[2].curved_avg
end

# ==============================================================================
# [4] CURVE CAN CLOSE THE GAP --- when avgs are close, topicality wins
# ==============================================================================
@testset "[4] topicality can flip close avgs" begin
    votes = Dict(
        "physics"  => [0.68, 0.68],  # avg = 0.68
        "cooking"  => [0.70, 0.70],  # avg = 0.70
    )

    # physics is highly topical (0.9), cooking is not (0.0)
    # physics curved = 0.68 * (1.0 + 0.25 * 0.9) = 0.68 * 1.225 = 0.833
    # cooking curved = 0.70 * 1.0 = 0.70
    topicalities = Dict("physics" => 0.9, "cooking" => 0.0)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)

    @test summaries[1].lobe_id == "physics"
    @test summaries[1].curved_avg > summaries[2].curved_avg
    @test isapprox(summaries[1].curved_avg, 0.68 * 1.225; atol = 1e-9)
end

# ==============================================================================
# [5] NO TOPIICALITY PROVIDED --- defaults to 0.0 (v7.24 behavior)
# ==============================================================================
@testset "[5] no topicality = v7.24 behavior" begin
    votes = Dict(
        "science"    => [0.90, 0.85, 0.60],  # avg = 0.7833
        "philosophy" => [0.40, 0.35],         # avg = 0.375
    )

    # No topicality_by_lobe kwarg → all topicality = 0.0 → curved_avg = avg_conf
    summaries = summarize_lobe_votes(votes)
    for s in summaries
        @test isapprox(s.curved_avg, s.avg_conf; atol = 1e-9)
        @test isapprox(s.topicality, 0.0; atol = 1e-9)
    end
    # Sort order same as v7.24: by avg_conf desc
    @test summaries[1].lobe_id == "science"
end

# ==============================================================================
# [6] PARTIAL TOPIICALITY --- only some lobes have scores, rest get 0.0
# ==============================================================================
@testset "[6] partial topicality: unspecified lobes get 0.0" begin
    votes = Dict(
        "lobe_a" => [0.60, 0.60],  # avg = 0.60
        "lobe_b" => [0.60, 0.60],  # avg = 0.60
        "lobe_c" => [0.60, 0.60],  # avg = 0.60
    )

    # Only lobe_a has topicality
    topicalities = Dict("lobe_a" => 0.8)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)

    # lobe_a gets the boost, others don't
    a = first(filter(s -> s.lobe_id == "lobe_a", summaries))
    b = first(filter(s -> s.lobe_id == "lobe_b", summaries))
    c = first(filter(s -> s.lobe_id == "lobe_c", summaries))

    @test isapprox(a.topicality, 0.8; atol = 1e-9)
    @test isapprox(b.topicality, 0.0; atol = 1e-9)
    @test isapprox(c.topicality, 0.0; atol = 1e-9)

    @test a.curved_avg > b.curved_avg
    @test isapprox(b.curved_avg, c.curved_avg; atol = 1e-9)
end

# ==============================================================================
# [7] FLOOR WINNER CARRIES TOPIICALITY --- telemetry fields populated
# ==============================================================================
@testset "[7] FloorWinner carries topicality + curved_avg" begin
    votes = Dict(
        "physics"  => [0.80, 0.75, 0.70],  # avg = 0.75
        "cooking"  => [0.60, 0.55],          # avg = 0.575
    )

    topicalities = Dict("physics" => 0.6, "cooking" => 0.1)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)
    plan = compute_orchestration_plan(summaries)

    @test plan.floor_winner !== nothing
    @test plan.floor_winner.lobe_id == "physics"

    # FloorWinner has topicality and curved_avg fields
    @test isapprox(plan.floor_winner.topicality, 0.6; atol = 1e-9)
    expected_curved = 0.75 * (1.0 + CONTEXT_TOPICALITY_CURVE_CAP * 0.6)
    @test isapprox(plan.floor_winner.curved_avg, expected_curved; atol = 1e-9)
end

# ==============================================================================
# [8] GATE STILL USES RAW AVG --- curve does NOT affect admission
# ==============================================================================
@testset "[8] multi-lobe gate uses raw avg_conf, not curved_avg" begin
    # Two lobes with same raw avg but different topicality.
    # Gate should treat them identically.
    votes = Dict(
        "lobe_a" => [0.55, 0.55],  # avg = 0.55 (passes gate)
        "lobe_b" => [0.55, 0.55],  # avg = 0.55 (passes gate)
    )

    topicalities = Dict("lobe_a" => 1.0, "lobe_b" => 0.0)
    summaries = summarize_lobe_votes(votes; topicality_by_lobe = topicalities)

    a = first(filter(s -> s.lobe_id == "lobe_a", summaries))
    b = first(filter(s -> s.lobe_id == "lobe_b", summaries))

    # Both pass the gate — same raw avg, same vote count
    @test a.passes_multi_lobe_gate == true
    @test b.passes_multi_lobe_gate == true

    # But ordering differs due to curve
    @test a.curved_avg > b.curved_avg
end

# ==============================================================================
# [9] TOPIICALITY CURVE CAP CONSTANT
# ==============================================================================
@testset "[9] CONTEXT_TOPICALITY_CURVE_CAP constant" begin
    @test CONTEXT_TOPICALITY_CURVE_CAP == 0.25
    @test CONTEXT_TOPICALITY_CURVE_CAP > 0.0  # boost, not penalty
    @test CONTEXT_TOPICALITY_CURVE_CAP < 1.0  # bounded, not unlimited
end

# ==============================================================================
# [10] CURVE IS NEVER A PENALTY --- topicality < 1 still boosts, never reduces
# ==============================================================================
@testset "[10] curve never penalizes" begin
    votes = Dict("lobe_x" => [0.65, 0.65])

    # topicality = 0.0 → curved_avg = avg_conf exactly
    s0 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_x" => 0.0))
    @test isapprox(s0[1].curved_avg, s0[1].avg_conf; atol = 1e-9)

    # topicality = 0.01 → tiny boost, never a penalty
    s01 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_x" => 0.01))
    @test s01[1].curved_avg >= s0[1].avg_conf

    # topicality = 1.0 → max boost
    s1 = summarize_lobe_votes(votes; topicality_by_lobe = Dict("lobe_x" => 1.0))
    @test s1[1].curved_avg > s0[1].avg_conf
    @test isapprox(s1[1].curved_avg, 0.65 * 1.25; atol = 1e-9)
end

println("\n" * "=" ^ 60)
println("v7.26 Context Topicality Curve tests COMPLETE")
println("=" ^ 60)
