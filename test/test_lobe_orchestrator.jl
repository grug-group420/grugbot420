# test_lobe_orchestrator.jl
# ==============================================================================
# GRUG v7.24 TESTS --- LobeOrchestrator sequential + simple lock-in average + ties
# ==============================================================================
# NO SILENT FAILURES: every @test has a diagnostic message.
# ==============================================================================

using Test
using Random

include("../src/LobeOrchestrator.jl")
using .LobeOrchestrator

println("\n" * "=" ^ 60)
println("GRUG v7.24 LobeOrchestrator TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] SUMMARIZE --- basic simple average math (no curve)
# ==============================================================================
@testset "summarize_lobe_votes: simple average of lock-in votes" begin
    votes = Dict(
        "science"    => [0.90, 0.85, 0.60],  # avg = 0.7833
        "philosophy" => [0.40, 0.35],         # avg = 0.375 (fails gate)
        "cooking"    => [0.10, 0.05],          # avg = 0.075 (fails gate)
    )

    summaries = summarize_lobe_votes(votes)
    @test length(summaries) == 3

    # GRUG v7.24: Verify sort by avg_conf descending (no curve).
    @test issorted([s.avg_conf for s in summaries], rev = true)

    # GRUG v7.24: Verify simple average math for science.
    sci = first(filter(s -> s.lobe_id == "science", summaries))
    expected_avg = (0.90 + 0.85 + 0.60) / 3
    @test isapprox(sci.avg_conf, expected_avg; atol = 1e-9)
    @test sci.max_conf == 0.90
    @test sci.vote_count == 3

    # GRUG v7.24: Science passes the multi-lobe gate (avg >= 0.50 AND count >= 2).
    @test sci.passes_multi_lobe_gate == true

    # GRUG: Philosophy fails - avg too low.
    phil = first(filter(s -> s.lobe_id == "philosophy", summaries))
    @test phil.passes_multi_lobe_gate == false

    # GRUG: Cooking fails - avg way too low.
    cook = first(filter(s -> s.lobe_id == "cooking", summaries))
    @test cook.passes_multi_lobe_gate == false
end

# ==============================================================================
# [2] SUMMARIZE --- empty / bad input rejected loudly
# ==============================================================================
@testset "summarize_lobe_votes: error paths" begin
    # Empty confidence list is legal (lobe just cast nothing) -> dropped.
    s = summarize_lobe_votes(Dict("empty" => Float64[]))
    @test isempty(s)

    # NaN confidence must throw.
    @test_throws LobeOrchestratorError summarize_lobe_votes(
        Dict("bad" => [0.5, NaN]))

    # Empty lobe_id must throw.
    @test_throws LobeOrchestratorError summarize_lobe_votes(
        Dict("" => [0.5]))
end

# ==============================================================================
# [3] PLAN --- single winner, no ties, no secondaries
# ==============================================================================
@testset "compute_orchestration_plan: single winner" begin
    votes = Dict(
        "science" => [0.95, 0.90, 0.80, 0.75, 0.60],
        "cooking" => [0.15, 0.10],
    )
    summaries = summarize_lobe_votes(votes)
    plan = compute_orchestration_plan(summaries)

    @test plan.floor_winner !== nothing
    @test plan.floor_winner.lobe_id == "science"
    @test plan.tie_resolved_by_coinflip == false
    @test isempty(plan.secondary_async)  # cooking did not pass gate
end

# ==============================================================================
# [4] PLAN --- multi-lobe async: two lobes both pass the gate
# ==============================================================================
@testset "compute_orchestration_plan: multi-lobe async" begin
    votes = Dict(
        "science"    => [0.90, 0.85, 0.75, 0.70, 0.60],   # avg = 0.76
        "philosophy" => [0.80, 0.78, 0.70, 0.65],         # avg = 0.7325
    )
    summaries = summarize_lobe_votes(votes)
    plan = compute_orchestration_plan(summaries)

    @test plan.floor_winner.lobe_id == "science"
    @test length(plan.secondary_async) == 1
    @test plan.secondary_async[1].lobe_id == "philosophy"
    @test plan.tie_resolved_by_coinflip == false

    # GRUG v7.24: Secondaries must come in descending avg_conf order.
    all_avgs = [plan.floor_winner.avg_conf;
                [s.avg_conf for s in plan.secondary_async]]
    @test issorted(all_avgs, rev = true)
end

# ==============================================================================
# [5] PLAN --- exact tie resolved by 50/50 coinflip (ORDER only, ALL fire)
# ==============================================================================
@testset "compute_orchestration_plan: exact-tie coinflip decides ORDER" begin
    # GRUG v7.24: Two lobes with IDENTICAL confidence lists = identical avg_conf.
    votes = Dict(
        "lobe_a" => [0.80, 0.75, 0.70],
        "lobe_b" => [0.80, 0.75, 0.70],
    )
    summaries = summarize_lobe_votes(votes)

    # GRUG v7.24: ALL tying lobes FIRE. Coinflip decides WHO GOES FIRST.
    # The tying lobe that doesn't go first becomes a GUARANTEED secondary.
    rng = MersenneTwister(0xC0FFEE)
    a_wins = 0
    b_wins = 0
    n_trials = 2000
    for _ in 1:n_trials
        plan = compute_orchestration_plan(summaries; rng = rng)
        @test plan.tie_resolved_by_coinflip == true

        # GRUG v7.24: CRITICAL - the tying lobe that didn't go first
        # MUST still appear as a guaranteed secondary. BOTH lobes FIRE.
        @test length(plan.secondary_async) >= 1
        if plan.floor_winner.lobe_id == "lobe_a"
            a_wins += 1
            @test any(s -> s.lobe_id == "lobe_b", plan.secondary_async)
        else
            b_wins += 1
            @test any(s -> s.lobe_id == "lobe_a", plan.secondary_async)
        end
    end
    @test a_wins + b_wins == n_trials
    # Allow 5% slop either direction.
    @test 0.45 <= a_wins / n_trials <= 0.55
end

# ==============================================================================
# [6] PLAN --- floor winner fails gate, no secondaries admitted
# ==============================================================================
@testset "compute_orchestration_plan: floor winner fails gate, no secondaries" begin
    votes = Dict(
        "weak_a" => [0.30, 0.25],
        "weak_b" => [0.25, 0.20],
    )
    summaries = summarize_lobe_votes(votes)
    plan = compute_orchestration_plan(summaries)

    @test plan.floor_winner !== nothing
    @test isempty(plan.secondary_async)
end

# ==============================================================================
# [7] PLAN --- empty input
# ==============================================================================
@testset "compute_orchestration_plan: empty summaries" begin
    plan = compute_orchestration_plan(LobeVoteSummary[])
    @test plan.floor_winner === nothing
    @test isempty(plan.secondary_async)
    @test plan.tie_resolved_by_coinflip == false
end

# ==============================================================================
# [8] CROSS-TALK GATE --- 1000-cap enforced
# ==============================================================================
@testset "CrossTalkGate: cap enforcement" begin
    gate = new_cross_talk_gate(5)

    for i in 1:5
        @test try_claim_cross_talk!(gate) == true
    end
    @test reserved_cross_talk_slots(gate) == 5

    @test try_claim_cross_talk!(gate) == false
    @test reserved_cross_talk_slots(gate) == 5

    release_cross_talk!(gate)
    @test reserved_cross_talk_slots(gate) == 4
    @test try_claim_cross_talk!(gate) == true
    @test reserved_cross_talk_slots(gate) == 5
end

# ==============================================================================
# [9] CROSS-TALK GATE --- over-release throws
# ==============================================================================
@testset "CrossTalkGate: over-release surfaces loudly" begin
    gate = new_cross_talk_gate(3)
    @test_throws LobeOrchestratorError release_cross_talk!(gate)
end

# ==============================================================================
# [10] DEFAULT CAP --- matches spec constant
# ==============================================================================
@testset "CrossTalkGate: default cap is CROSS_TALK_ACTIVE_CAP" begin
    gate = new_cross_talk_gate()
    @test gate.cap == CROSS_TALK_ACTIVE_CAP
end

# ==============================================================================
# [11] PLAN --- three-way tie: ALL fire, coinflip decides order
# ==============================================================================
@testset "compute_orchestration_plan: three-way exact tie" begin
    votes = Dict(
        "lobe_a" => [0.70, 0.65, 0.60],
        "lobe_b" => [0.70, 0.65, 0.60],
        "lobe_c" => [0.70, 0.65, 0.60],
    )
    summaries = summarize_lobe_votes(votes)

    rng = MersenneTwister(42)
    plan = compute_orchestration_plan(summaries; rng = rng)

    @test plan.tie_resolved_by_coinflip == true
    # GRUG v7.24: ALL three tying lobes fire. Floor winner + 2 guaranteed secondaries.
    @test length(plan.secondary_async) >= 2
    all_firing = Set([plan.floor_winner.lobe_id;
                      [s.lobe_id for s in plan.secondary_async]])
    @test "lobe_a" in all_firing
    @test "lobe_b" in all_firing
    @test "lobe_c" in all_firing
end

# ==============================================================================
# [12] CONSTANTS --- v7.24 values match spec
# ==============================================================================
@testset "Constants: v7.24 values" begin
    @test MULTI_LOBE_THRESHOLD == 0.50
    @test MIN_WINNING_VOTES == 2
    @test PER_LOBE_FIRE_CAP == 1_000
    @test CROSS_TALK_ACTIVE_CAP == 1_000
end

println("\n" * "=" ^ 60)
println("v7.24 LobeOrchestrator tests COMPLETE")
println("=" ^ 60)
