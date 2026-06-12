# =============================================================================
# GRUG v7.28 — MUTUAL INCOMPLETENESS ORCHESTRATION RULE TEST
# =============================================================================
# Tests the rule: when 2+ lobes each have MULTIPLE strong matches
# (pass the multi-lobe gate), they get co-equal standing regardless of
# overall averages. curved_avg still decides who speaks FIRST but no lobe
# is demoted to "secondary." The 1k per-lobe cap is always enforced.
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
# [2] TWO LOBES BOTH PASS GATE — mutual incompleteness fires
# =====================================================================
@testset "[2] Two qualifying lobes: mutual incompleteness fires" begin
    s1 = LobeVoteSummary("math", 4, 0.85, 0.95, true, 0.6, 0.978)   # high curved_avg
    s2 = LobeVoteSummary("physics", 3, 0.70, 0.88, true, 0.4, 0.770) # lower but passes gate
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    @test "math" in plan.coequal_lobe_ids
    @test "physics" in plan.coequal_lobe_ids
    # curved_avg still decides who speaks first
    @test plan.floor_winner.lobe_id == "math"
    println("  ✓ Two qualifying lobes: mutual_incompleteness=true, both coequal")
end

# =====================================================================
# [3] THREE LOBES, ALL PASS — all three coequal
# =====================================================================
@testset "[3] Three qualifying lobes: all coequal" begin
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
    println("  ✓ Three qualifying lobes: all three coequal")
end

# =====================================================================
# [4] TWO LOBES, ONLY ONE PASSES GATE — no mutual incompleteness
# =====================================================================
@testset "[4] Only one passes gate: no mutual incompleteness" begin
    s1 = LobeVoteSummary("math", 5, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("history", 1, 0.90, 0.90, false, 0.0, 0.90) # 1 vote → fails gate
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == false
    @test isempty(plan.coequal_lobe_ids)
    println("  ✓ One passes, one doesn't: no mutual incompleteness")
end

# =====================================================================
# [5] TWO LOBES, BOTH FAIL GATE — no mutual incompleteness
# =====================================================================
@testset "[5] Both fail gate: no mutual incompleteness" begin
    s1 = LobeVoteSummary("math", 1, 0.95, 0.95, false, 0.0, 0.95)
    s2 = LobeVoteSummary("art", 1, 0.90, 0.90, false, 0.0, 0.90)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == false
    @test isempty(plan.coequal_lobe_ids)
    println("  ✓ Both fail gate: no mutual incompleteness")
end

# =====================================================================
# [6] THREE LOBES, TWO PASS, ONE DOESN'T — only qualifying two are coequal
# =====================================================================
@testset "[6] Mixed: two pass, one doesn't" begin
    s1 = LobeVoteSummary("math", 5, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("physics", 3, 0.70, 0.88, true, 0.4, 0.770)
    s3 = LobeVoteSummary("art", 1, 0.90, 0.90, false, 0.0, 0.90) # fails gate
    plan = compute_orchestration_plan([s1, s2, s3])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    @test "math" in plan.coequal_lobe_ids
    @test "physics" in plan.coequal_lobe_ids
    @test !("art" in plan.coequal_lobe_ids)
    println("  ✓ Two pass gate, one doesn't: only qualifying two are coequal")
end

# =====================================================================
# [7] EMPTY SUMMARIES — no mutual incompleteness
# =====================================================================
@testset "[7] Empty summaries: no mutual incompleteness" begin
    plan = compute_orchestration_plan(LobeVoteSummary[])
    @test plan.mutual_incompleteness == false
    @test isempty(plan.coequal_lobe_ids)
    @test plan.floor_winner === nothing
    println("  ✓ Empty summaries: mutual_incompleteness=false, no winner")
end

# =====================================================================
# [8] EXACT TIE + MUTUAL INCOMPLETENESS — both fire, coinflip for order
# =====================================================================
@testset "[8] Tie + mutual incompleteness: both fire" begin
    s1 = LobeVoteSummary("math", 3, 0.80, 0.90, true, 0.5, 0.90)
    s2 = LobeVoteSummary("physics", 3, 0.80, 0.90, true, 0.5, 0.90)
    # Same curved_avg → exact tie. Both pass gate → mutual incompleteness.
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    # Tie rule: both fire, coinflip decides order
    @test plan.tie_resolved_by_coinflip == true
    # One is floor winner, other is in secondary_async, but BOTH are coequal
    winning_id = plan.floor_winner.lobe_id
    @test winning_id in ("math", "physics")
    println("  ✓ Tie + mutual incompleteness: both coequal, coinflip for order")
end

# =====================================================================
# [9] CURVED_AVG ORDERING STILL WORKS WITH MUTUAL INCOMPLETENESS
# =====================================================================
@testset "[9] curved_avg still orders among coequal lobes" begin
    s1 = LobeVoteSummary("math", 4, 0.90, 0.98, true, 0.9, 1.103)  # highest curved_avg
    s2 = LobeVoteSummary("physics", 4, 0.80, 0.88, true, 0.5, 0.90) # mid
    s3 = LobeVoteSummary("chemistry", 3, 0.65, 0.75, true, 0.1, 0.666) # lowest but passes
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
# [10] PER_LOBE_FIRE_CAP AND CROSS_TALK_ACTIVE_CAP STILL ENFORCED
# =====================================================================
@testset "[10] Caps still enforced with mutual incompleteness" begin
    @test PER_LOBE_FIRE_CAP == 1_000
    @test CROSS_TALK_ACTIVE_CAP == 1_000
    # Mutual incompleteness doesn't change caps — they're hard limits
    s1 = LobeVoteSummary("math", 500, 0.80, 0.95, true, 0.6, 0.92)
    s2 = LobeVoteSummary("physics", 500, 0.75, 0.90, true, 0.4, 0.825)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    # Caps are enforced downstream in Main.jl, not here. Verify constants.
    println("  ✓ PER_LOBE_FIRE_CAP=1000, CROSS_TALK_ACTIVE_CAP=1000 unchanged")
end

# =====================================================================
# [11] MUTUAL INCOMPLETENESS + SINGLE VOTE LOBE EXCLUDED
# =====================================================================
@testset "[11] High-conf single-vote lobe NOT coequal" begin
    s1 = LobeVoteSummary("math", 4, 0.85, 0.95, true, 0.6, 0.978)
    s2 = LobeVoteSummary("physics", 3, 0.70, 0.88, true, 0.4, 0.770)
    s3 = LobeVoteSummary("logic", 1, 0.99, 0.99, false, 0.9, 1.213) # 1 vote, fails gate
    plan = compute_orchestration_plan([s1, s2, s3])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    @test !("logic" in plan.coequal_lobe_ids) # single vote lobe excluded
    # Even though logic has highest curved_avg, it doesn't qualify for coequality
    # because it doesn't pass the gate (only 1 vote)
    println("  ✓ High-conf single-vote lobe excluded from coequality")
end

# =====================================================================
# [12] MIN_WINNING_VOTES THRESHOLD VERIFIED
# =====================================================================
@testset "[12] MIN_WINNING_VOTES threshold" begin
    @test MIN_WINNING_VOTES == 2
    # A lobe with exactly 2 votes and avg >= 0.50 passes
    s1 = LobeVoteSummary("math", 2, 0.55, 0.60, true, 0.0, 0.55)
    s2 = LobeVoteSummary("physics", 2, 0.52, 0.58, true, 0.0, 0.52)
    plan = compute_orchestration_plan([s1, s2])
    @test plan.mutual_incompleteness == true
    @test length(plan.coequal_lobe_ids) == 2
    println("  ✓ MIN_WINNING_VOTES=2, exactly-2-vote lobes qualify")
end

println()
println("="^70)
println("ALL v7.28 MUTUAL INCOMPLETENESS TESTS PASSED!")
println("="^70)
