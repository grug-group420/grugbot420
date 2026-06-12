# =============================================================================
# GRUG v7.28 — MUTUAL INCOMPLETENESS ORCHESTRATION RULE TEST
# =============================================================================
# Tests the rule: when 2+ lobes each have at least one lock-in vote,
# they get co-equal standing regardless of overall averages. curved_avg
# still decides who speaks FIRST but no lobe is demoted to "secondary."
# The 1k per-lobe cap is always enforced.
# =============================================================================

using Test

# Load the LobeOrchestrator module directly
include("../src/LobeOrchestrator.jl")
using .LobeOrchestrator

println("="^70)
println("GRUG v7.28 — MUTUAL INCOMPLETENESS ORCHESTRATION RULE TEST")
println("="^70)

# =====================================================================
# [1] SINGLE LOBE — no mutual incompleteness possible
# =====================================================================
@testset "[1] Single lobe: no mutual incompleteness" begin
    s = LobeVoteSummary("math", 5, 0.80, 0.95, true, 0.5, 0.90)
    plan = compute_orchestration_plan([s])
    @test plan.mutual_incompleteness == false
    @test isempty(plan.coequal_lobe_ids)
    @test plan.floor_winner.lobe_id == "math"
    println("  ✓ Single lobe: mutual_incompleteness=false, empty coequal set")
end

# =====================================================================
# [2] TWO LOBES EACH HAVE AT LEAST ONE VOTE — mutual incompleteness fires
# =====================================================================
@testset "[2] Two lobes with votes: mutual incompleteness fires" begin
    s1 = LobeVoteSummary("math", 4, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("physics", 3, 0.70, 0.88, true, 0.4, 0.770)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    @test "math" in plan.coequal_lobe_ids
    @test "physics" in plan.coequal_lobe_ids
    # curved_avg still decides who speaks first
    @test plan.floor_winner.lobe_id == "math"
    println("  ✓ Two lobes with votes: mutual_incompleteness=true, both coequal")
end

# =====================================================================
# [3] THREE LOBES, ALL HAVE VOTES — all three coequal
# =====================================================================
@testset "[3] Three lobes with votes: all coequal" begin
    s1 = LobeVoteSummary("math", 5, 0.90, 0.98, true, 0.8, 1.08)
    s2 = LobeVoteSummary("physics", 4, 0.75, 0.88, true, 0.5, 0.844)
    s3 = LobeVoteSummary("chemistry", 3, 0.60, 0.72, true, 0.3, 0.645)
    plan = compute_orchestration_plan([s1, s2, s3])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 3
    @test "math" in plan.coequal_lobe_ids
    @test "physics" in plan.coequal_lobe_ids
    @test "chemistry" in plan.coequal_lobe_ids
    @test plan.floor_winner.lobe_id == "math"
    println("  ✓ Three lobes with votes: all three coequal")
end

# =====================================================================
# [4] TWO LOBES, ONE WITH SINGLE VOTE — STILL mutual incompleteness
# The key v7.28 change: even ONE lock-in is enough for co-equality.
# =====================================================================
@testset "[4] One lobe has single vote: still mutual incompleteness" begin
    s1 = LobeVoteSummary("math", 5, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("history", 1, 0.90, 0.90, false, 0.0, 0.90) # 1 vote but fails gate
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true   # <-- CHANGED from v7.28
    @test length(plan.coequal_lobe_ids) == 2
    @test "math" in plan.coequal_lobe_ids
    @test "history" in plan.coequal_lobe_ids   # <-- single-vote lobe IS coequal
    println("  ✓ Single-vote lobe IS coequal under v7.28 rule")
end

# =====================================================================
# [5] EMPTY SUMMARIES — no mutual incompleteness
# =====================================================================
@testset "[5] Empty summaries: no mutual incompleteness" begin
    plan = compute_orchestration_plan(LobeVoteSummary[])
    @test plan.mutual_incompleteness == false
    @test isempty(plan.coequal_lobe_ids)
    @test plan.floor_winner === nothing
    println("  ✓ Empty summaries: mutual_incompleteness=false, no winner")
end

# =====================================================================
# [6] EXACT TIE + MUTUAL INCOMPLETENESS — both fire, coinflip for order
# =====================================================================
@testset "[6] Tie + mutual incompleteness: both fire" begin
    s1 = LobeVoteSummary("math", 3, 0.80, 0.90, true, 0.5, 0.90)
    s2 = LobeVoteSummary("physics", 3, 0.80, 0.90, true, 0.5, 0.90)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    # Tie rule: both fire, coinflip decides order
    @test plan.tie_resolved_by_coinflip == true
    winning_id = plan.floor_winner.lobe_id
    @test winning_id in ("math", "physics")
    println("  ✓ Tie + mutual incompleteness: both coequal, coinflip for order")
end

# =====================================================================
# [7] CURVED_AVG ORDERING STILL WORKS WITH MUTUAL INCOMPLETENESS
# =====================================================================
@testset "[7] curved_avg still orders among coequal lobes" begin
    s1 = LobeVoteSummary("math", 4, 0.90, 0.98, true, 0.9, 1.103)
    s2 = LobeVoteSummary("physics", 4, 0.80, 0.88, true, 0.5, 0.90)
    s3 = LobeVoteSummary("chemistry", 3, 0.65, 0.75, true, 0.1, 0.666)
    plan = compute_orchestration_plan([s1, s2, s3])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 3
    # Floor winner = highest curved_avg, even though all are coequal
    @test plan.floor_winner.lobe_id == "math"
    # Secondaries are ordered by curved_avg too
    @test length(plan.secondary_async) == 2
    @test plan.secondary_async[1].lobe_id == "physics"
    @test plan.secondary_async[2].lobe_id == "chemistry"
    println("  ✓ curved_avg orders coequal lobes (math > physics > chemistry)")
end

# =====================================================================
# [8] PER_LOBE_FIRE_CAP AND CROSS_TALK_ACTIVE_CAP STILL ENFORCED
# =====================================================================
@testset "[8] Caps still enforced with mutual incompleteness" begin
    @test PER_LOBE_FIRE_CAP == 1_000
    @test CROSS_TALK_ACTIVE_CAP == 1_000
    println("  ✓ PER_LOBE_FIRE_CAP=1000, CROSS_TALK_ACTIVE_CAP=1000 unchanged")
end

# =====================================================================
# [9] HIGH-CONF SINGLE-VOTE LOBE IS NOW COEQUAL (v7.28 change)
# =====================================================================
@testset "[9] Single-vote lobe IS coequal" begin
    s1 = LobeVoteSummary("math", 4, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("physics", 3, 0.70, 0.88, true, 0.4, 0.770)
    s3 = LobeVoteSummary("logic", 1, 0.99, 0.99, false, 0.9, 1.213) # 1 vote, fails gate
    plan = compute_orchestration_plan([s1, s2, s3])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 3   # <-- ALL three, including logic
    @test "logic" in plan.coequal_lobe_ids      # <-- single-vote lobe IS coequal
    println("  ✓ Single-vote lobe IS coequal under v7.28 (1 lock-in = real signal)")
end

# =====================================================================
# [10] TWO SINGLE-VOTE LOBES — mutual incompleteness fires
# =====================================================================
@testset "[10] Two single-vote lobes: mutual incompleteness" begin
    s1 = LobeVoteSummary("math", 1, 0.55, 0.55, false, 0.0, 0.55)
    s2 = LobeVoteSummary("art", 1, 0.52, 0.52, false, 0.0, 0.52)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    @test "math" in plan.coequal_lobe_ids
    @test "art" in plan.coequal_lobe_ids
    println("  ✓ Two single-vote lobes: mutual incompleteness fires")
end

# =====================================================================
# [11] MIXED: TWO WITH VOTES, ZERO-VOTE LOBE NOT IN SUMMARIES
# (zero-vote lobes are already dropped by summarize_lobe_votes)
# =====================================================================
@testset "[11] Only lobes with votes appear in summaries" begin
    s1 = LobeVoteSummary("math", 3, 0.75, 0.90, true, 0.5, 0.844)
    s2 = LobeVoteSummary("physics", 2, 0.60, 0.70, true, 0.3, 0.645)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    println("  ✓ Only lobes with votes appear, mutual incompleteness fires")
end

# =====================================================================
# [12] COEQUAL LOBES STILL RESPECT SECONDARY ASYNC GATE
# Mutual incompleteness determines CO-EQUALITY (winner bucket).
# The multi-lobe gate still determines SECONDARY ASYNC admission for
# lobes NOT in the coequal set (if any exist with 0 votes, they're
# already excluded from summaries).
# =====================================================================
@testset "[12] Mutual incompleteness vs multi-lobe gate are separate" begin
    @test MULTI_LOBE_THRESHOLD == 0.50
    @test MIN_WINNING_VOTES == 2
    # The gate requires avg >= 0.50 AND count >= 2.
    # Mutual incompleteness requires only count >= 1.
    # These are different thresholds for different purposes.
    s1 = LobeVoteSummary("math", 2, 0.60, 0.75, true, 0.4, 0.66)
    s2 = LobeVoteSummary("art", 1, 0.55, 0.55, false, 0.0, 0.55) # fails gate but qualifies for coequality
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true  # both have votes
    @test "art" in plan.coequal_lobe_ids       # even though art fails the gate
    println("  ✓ Mutual incompleteness (any vote) ≠ multi-lobe gate (2+ votes + avg)")
end

println()
println("="^70)
println("ALL v7.28 MUTUAL INCOMPLETENESS TESTS PASSED!")
println("="^70)
