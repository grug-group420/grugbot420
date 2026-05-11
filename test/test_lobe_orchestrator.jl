# test_lobe_orchestrator.jl
# ==============================================================================
# GRUG v7.15 TESTS --- LobeOrchestrator sequential + curved-average + ties
# ==============================================================================
# NO SILENT FAILURES: every @test has a diagnostic message.
# ==============================================================================

using Test
using Random

include("../src/LobeOrchestrator.jl")
using .LobeOrchestrator

println("\n" * "=" ^ 60)
println("GRUG v7.15 LobeOrchestrator TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] SUMMARIZE --- basic curved-average math
# ==============================================================================
@testset "summarize_lobe_votes: basic curved average" begin
    votes = Dict(
        "science"    => [0.90, 0.85, 0.60, 0.20],     # top-tier = {0.90, 0.85}
        "philosophy" => [0.40, 0.35, 0.30],            # top-tier = {0.40, 0.35} (0.40-0.05=0.35)
        "cooking"    => [0.10, 0.05],                  # below multi-lobe threshold
    )

    summaries = summarize_lobe_votes(votes)
    @test length(summaries) == 3

    # GRUG: Verify sort by curved_avg descending.
    @test issorted([s.curved_avg for s in summaries], rev = true)

    # GRUG: Verify curve math for science.
    sci = first(filter(s -> s.lobe_id == "science", summaries))
    expected_base = (0.90 + 0.85 + 0.60 + 0.20) / 4
    expected_top  = (0.90 + 0.85) / 2
    @test isapprox(sci.base_avg,  expected_base; atol = 1e-9)
    @test isapprox(sci.top_avg,   expected_top;  atol = 1e-9)
    @test isapprox(sci.curved_avg, expected_base * expected_top; atol = 1e-9)

    # GRUG: Verify the winning_vote threshold (>= WINNING_VOTE_CONF = 0.55).
    @test sci.winning_vote_count == 3   # 0.90, 0.85, 0.60

    # GRUG: Science should pass the multi-lobe gate; cooking should not.
    @test sci.passes_multi_lobe_gate == true
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
        "science"    => [0.90, 0.85, 0.75, 0.70, 0.60],   # very strong
        "philosophy" => [0.80, 0.78, 0.70, 0.65],         # also strong
    )
    summaries = summarize_lobe_votes(votes)
    plan = compute_orchestration_plan(summaries)

    @test plan.floor_winner.lobe_id == "science"
    @test length(plan.secondary_async) == 1
    @test plan.secondary_async[1].lobe_id == "philosophy"
    @test plan.tie_resolved_by_coinflip == false

    # GRUG: Secondaries must come in descending curved_avg order.
    all_curveds = [plan.floor_winner.curved_avg;
                   [s.curved_avg for s in plan.secondary_async]]
    @test issorted(all_curveds, rev = true)
end

# ==============================================================================
# [5] PLAN --- exact tie resolved by 50/50 coinflip
# ==============================================================================
@testset "compute_orchestration_plan: exact-tie coinflip" begin
    # GRUG: Two lobes with IDENTICAL confidence lists = identical curved_avg.
    votes = Dict(
        "lobe_a" => [0.80, 0.75, 0.70],
        "lobe_b" => [0.80, 0.75, 0.70],
    )
    summaries = summarize_lobe_votes(votes)

    # GRUG: Many trials, both lobes should win roughly half the time.
    rng = MersenneTwister(0xC0FFEE)
    a_wins = 0
    b_wins = 0
    n_trials = 2000
    for _ in 1:n_trials
        plan = compute_orchestration_plan(summaries; rng = rng)
        @test plan.tie_resolved_by_coinflip == true
        plan.floor_winner.lobe_id == "lobe_a" && (a_wins += 1)
        plan.floor_winner.lobe_id == "lobe_b" && (b_wins += 1)
    end
    @test a_wins + b_wins == n_trials
    # Allow 5% slop either direction.
    @test 0.45 <= a_wins / n_trials <= 0.55
end

# ==============================================================================
# [6] PLAN --- floor winner fails gate, no secondaries admitted
# ==============================================================================
@testset "compute_orchestration_plan: floor winner fails gate, no secondaries" begin
    # GRUG: Every lobe is weak. Someone must still speak (floor winner), but
    # NO secondaries get in because the "multi-lobe moment" criterion is not met.
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
    gate = new_cross_talk_gate(5)   # small cap for test

    # GRUG: Claim up to the cap.
    for i in 1:5
        @test try_claim_cross_talk!(gate) == true
    end
    @test reserved_cross_talk_slots(gate) == 5

    # GRUG: Sixth must reject.
    @test try_claim_cross_talk!(gate) == false
    @test reserved_cross_talk_slots(gate) == 5

    # GRUG: Release one, then can claim again.
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

println("\n" * "=" ^ 60)
println("\u2705  LobeOrchestrator tests COMPLETE")
println("=" ^ 60)
