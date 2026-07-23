# test_duplicate_solver_cap.jl
# ==============================================================================
# GRUG: Tests for the Cycle Solver Ledger — Duplicate Solver Capping Mechanism.
#
#   1. Multiple nodes with IDENTICAL pattern/bind sites are allowed (anti-
#      staleness — the thesaurus alone can't catch this, so we don't want to
#      block it either). Only identical VOTES/ACTIONS competing for the same
#      objective get capped.
#   2. <= DUPLICATE_SOLVER_CAP (4) duplicate solvers for the same
#      (multipart_group, action) pass through untouched.
#   3. > 4 duplicate solvers get capped down to exactly 4, evicting the
#      weakest strength*confidence solver(s) first.
#   4. Ties at the lowest strength*confidence are broken STOCHASTICALLY
#      (verified statistically over many trials).
#   5. After capping, a strength*confidence-BIASED stochastic winner is
#      picked from the survivors (verified statistically).
#   6. A fully exact-duplicate node (same pattern + action_packet + drop_table)
#      is blocked by the separate _is_exact_node_duplicate guard, while nodes
#      sharing only the pattern (different action_packet/drop_table) are NOT
#      blocked by it.
#
# Tests run in order. Any failure throws loudly. NO SILENT FAILURES.
# ==============================================================================

using Test
# ╔══════════════════════════════════════════════════════════════════════════╗
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
# ╚══════════════════════════════════════════════════════════════════════════╝
using Random
using Base.Threads: ReentrantLock

include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
using .VoteOrchestrator

println("\n" * "="^60)
println("GRUG DUPLICATE SOLVER CAP TEST SUITE")
println("="^60)

# ==============================================================================
# [1] BASIC PASS-THROUGH — <= cap duplicate solvers untouched
# ==============================================================================

@testset "[1] <= DUPLICATE_SOLVER_CAP solvers pass through untouched" begin
    @test VoteOrchestrator.DUPLICATE_SOLVER_CAP == 4

    cands = [
        VoteOrchestrator.VoteCandidate("a", 0.8, 5.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("b", 0.7, 4.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("c", 0.6, 3.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("d", 0.6, 2.0; multipart_group="", action="greet"),
    ]
    kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    @test length(kept) == 4
    @test isempty(evicted)
    @test isempty(stats)
    @test isempty(winners)
    # order preserved
    @test [vc.node_id for vc in kept] == ["a", "b", "c", "d"]
end

@testset "[1b] IDENTICAL pattern/bind sites across different nodes are ALLOWED" begin
    # GRUG: This cap groups by (multipart_group, action), NOT pattern. Two
    # VoteCandidates representing nodes with the exact same pattern but
    # DIFFERENT actions must never collide/cap each other.
    cands = [
        VoteOrchestrator.VoteCandidate("fire_n1", 0.8, 5.0; multipart_group="", action="describe_fire"),
        VoteOrchestrator.VoteCandidate("fire_n2", 0.75, 4.0; multipart_group="", action="warn_fire"),
        VoteOrchestrator.VoteCandidate("fire_n3", 0.7, 3.0; multipart_group="", action="explain_fire"),
    ]
    kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    @test length(kept) == 3
    @test isempty(evicted)
    @test isempty(stats)
end

# ==============================================================================
# [2] EXACTLY 5 DUPLICATE SOLVERS -> 1 EVICTED, 4 REMAIN
# ==============================================================================

@testset "[2] 5 duplicate solvers -> exactly 1 evicted, weakest strength*confidence" begin
    cands = [
        VoteOrchestrator.VoteCandidate("n1", 0.8, 5.0; multipart_group="", action="greet"),  # sc=4.0
        VoteOrchestrator.VoteCandidate("n2", 0.9, 6.0; multipart_group="", action="greet"),  # sc=5.4
        VoteOrchestrator.VoteCandidate("n3", 0.5, 1.0; multipart_group="", action="greet"),  # sc=0.5 <- weakest
        VoteOrchestrator.VoteCandidate("n4", 0.7, 3.0; multipart_group="", action="greet"),  # sc=2.1
        VoteOrchestrator.VoteCandidate("n5", 0.6, 2.0; multipart_group="", action="greet"),  # sc=1.2
    ]
    kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    @test length(kept) == 4
    @test length(evicted) == 1
    @test evicted == ["n3"]
    @test "n3" ∉ [vc.node_id for vc in kept]
    @test length(stats) == 1
    st = stats[1]
    @test st.total_candidates == 5
    @test st.evicted_node_ids == ["n3"]
    @test length(st.survivor_node_ids) == 4
    @test !st.tie_break_used
    @test st.winner_node_id in st.survivor_node_ids
    @test winners[("", "greet")] == st.winner_node_id
end

@testset "[2b] Multiple buckets — only the over-cap bucket is touched" begin
    cands = [
        # bucket A: 5 candidates, action "solve" -> gets capped
        VoteOrchestrator.VoteCandidate("a1", 0.9, 5.0; multipart_group="mp_1", action="solve"),
        VoteOrchestrator.VoteCandidate("a2", 0.8, 5.0; multipart_group="mp_1", action="solve"),
        VoteOrchestrator.VoteCandidate("a3", 0.7, 5.0; multipart_group="mp_1", action="solve"),
        VoteOrchestrator.VoteCandidate("a4", 0.6, 5.0; multipart_group="mp_1", action="solve"),
        VoteOrchestrator.VoteCandidate("a5", 0.1, 1.0; multipart_group="mp_1", action="solve"),  # weakest
        # bucket B: 2 candidates, different group -> untouched
        VoteOrchestrator.VoteCandidate("b1", 0.9, 5.0; multipart_group="mp_2", action="solve"),
        VoteOrchestrator.VoteCandidate("b2", 0.8, 5.0; multipart_group="mp_2", action="solve"),
    ]
    kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    @test evicted == ["a5"]
    @test length(kept) == 6
    @test length(stats) == 1
    @test stats[1].multipart_group == "mp_1"
    @test !haskey(winners, ("mp_2", "solve"))
end

# ==============================================================================
# [3] TIE AT LOWEST STRENGTH*CONFIDENCE -> STOCHASTIC EVICTION PICK
# ==============================================================================

@testset "[3] Tie at lowest strength*confidence -> stochastic eviction (statistical)" begin
    make_cands() = [
        VoteOrchestrator.VoteCandidate("n1", 0.9, 6.0; multipart_group="", action="greet"),  # sc=5.4
        VoteOrchestrator.VoteCandidate("n2", 0.8, 5.0; multipart_group="", action="greet"),  # sc=4.0
        VoteOrchestrator.VoteCandidate("n3", 0.6, 2.0; multipart_group="", action="greet"),  # sc=1.2 tied lowest
        VoteOrchestrator.VoteCandidate("n4", 0.6, 2.0; multipart_group="", action="greet"),  # sc=1.2 tied lowest
        VoteOrchestrator.VoteCandidate("n5", 0.7, 3.0; multipart_group="", action="greet"),  # sc=2.1
    ]

    counts = Dict("n3" => 0, "n4" => 0)
    trials = 3000
    tie_break_flags = Bool[]
    for _ in 1:trials
        kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(make_cands())
        @test length(evicted) == 1
        @test evicted[1] in ("n3", "n4")
        counts[evicted[1]] += 1
        push!(tie_break_flags, stats[1].tie_break_used)
    end

    # GRUG: tie_break_used must always be true here — it IS a real tie.
    @test all(tie_break_flags)

    # GRUG: roughly 50/50 over many trials (loose bounds to avoid test flakiness —
    # true 50/50 binomial std dev at n=3000 is ~27, so a >40% margin is very safe).
    @test counts["n3"] > trials * 0.35
    @test counts["n4"] > trials * 0.35
    @test counts["n3"] + counts["n4"] == trials
    println("  [3] tie eviction distribution over $trials trials: $counts")
end

@testset "[3b] No false tie-break flag when there's a clean unique minimum" begin
    cands = [
        VoteOrchestrator.VoteCandidate("n1", 0.9, 6.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n2", 0.8, 5.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n3", 0.5, 1.0; multipart_group="", action="greet"),  # unique lowest
        VoteOrchestrator.VoteCandidate("n4", 0.7, 3.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n5", 0.6, 2.0; multipart_group="", action="greet"),
    ]
    _, evicted, _, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    @test evicted == ["n3"]
    @test !stats[1].tie_break_used
end

# ==============================================================================
# [4] POST-EVICTION WINNER PICK — STOCHASTIC, BIASED BY STRENGTH*CONFIDENCE
# ==============================================================================

@testset "[4] Winner pick after capping is biased by strength*confidence (statistical)" begin
    # 5 candidates, cap=3 -> 2 evicted (the two weakest, distinct so no tie
    # noise), leaving 3 survivors with clearly different strength*confidence
    # so we can check the winner distribution is proportionally biased.
    make_cands() = [
        VoteOrchestrator.VoteCandidate("strong", 0.9, 8.0; multipart_group="", action="x"),  # sc=7.2
        VoteOrchestrator.VoteCandidate("mid",    0.6, 3.0; multipart_group="", action="x"),  # sc=1.8
        VoteOrchestrator.VoteCandidate("weak",   0.3, 1.0; multipart_group="", action="x"),  # sc=0.3
        VoteOrchestrator.VoteCandidate("floor1", 0.1, 0.5; multipart_group="", action="x"),  # sc=0.05 evicted
        VoteOrchestrator.VoteCandidate("floor2", 0.1, 0.3; multipart_group="", action="x"),  # sc=0.03 evicted
    ]

    winner_counts = Dict{String,Int}()
    trials = 4000
    for _ in 1:trials
        _, evicted, winners, _ = VoteOrchestrator.enforce_duplicate_solver_cap!(make_cands(); cap=3)
        @test Set(evicted) == Set(["floor1", "floor2"])
        w = winners[("", "x")]
        winner_counts[w] = get(winner_counts, w, 0) + 1
    end
    println("  [4] winner-pick distribution over $trials trials (expected ~ strong:mid:weak = 7.2:1.8:0.3): $winner_counts")

    # GRUG: expected proportions (7.2 : 1.8 : 0.3 out of 9.3 total) ~ 77% : 19% : 3%.
    # Assert directional/statistical ordering rather than exact numbers to avoid flakiness:
    @test get(winner_counts, "strong", 0) > get(winner_counts, "mid", 0)
    @test get(winner_counts, "mid", 0) > get(winner_counts, "weak", 0)
    # strong should clearly dominate (well above flat-1/3 expectation of ~1333/trials)
    @test get(winner_counts, "strong", 0) > trials * 0.55
    # every survivor must be pickable at least sometimes (no hard zero-floor bug)
    @test get(winner_counts, "weak", 0) > 0
end

@testset "[4b] Winner pick falls back to uniform when all weights are zero" begin
    cands = [
        VoteOrchestrator.VoteCandidate("a", 0.0, 0.0; multipart_group="", action="x"),
        VoteOrchestrator.VoteCandidate("b", 0.0, 0.0; multipart_group="", action="x"),
        VoteOrchestrator.VoteCandidate("c", 0.0, 0.0; multipart_group="", action="x"),
    ]
    _, evicted, winners, _ = VoteOrchestrator.enforce_duplicate_solver_cap!(cands; cap=3)
    @test isempty(evicted)  # at cap, untouched
    @test !haskey(winners, ("", "x"))  # untouched buckets get no winner record

    # Force a cap breach with all-zero weights to exercise the uniform fallback path.
    cands2 = [
        VoteOrchestrator.VoteCandidate("a", 0.0, 0.0; multipart_group="", action="x"),
        VoteOrchestrator.VoteCandidate("b", 0.0, 0.0; multipart_group="", action="x"),
        VoteOrchestrator.VoteCandidate("c", 0.0, 0.0; multipart_group="", action="x"),
        VoteOrchestrator.VoteCandidate("d", 0.0, 0.0; multipart_group="", action="x"),
    ]
    _, evicted2, winners2, stats2 = VoteOrchestrator.enforce_duplicate_solver_cap!(cands2; cap=3)
    @test length(evicted2) == 1
    @test haskey(winners2, ("", "x"))
    @test winners2[("", "x")] in stats2[1].survivor_node_ids
end

# ==============================================================================
# [5] EDGE CASES
# ==============================================================================

@testset "[5] Edge cases" begin
    # empty input -> no crash, empty everything
    kept, evicted, winners, stats = VoteOrchestrator.enforce_duplicate_solver_cap!(VoteOrchestrator.VoteCandidate[])
    @test isempty(kept)
    @test isempty(evicted)
    @test isempty(winners)
    @test isempty(stats)

    # cap < 1 throws loudly
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.enforce_duplicate_solver_cap!(
        [VoteOrchestrator.VoteCandidate("a", 0.5, 5.0)]; cap=0)

    # LAST_DUPLICATE_SOLVER_LOG reflects most recent call
    cands = [
        VoteOrchestrator.VoteCandidate("n1", 0.9, 6.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n2", 0.8, 5.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n3", 0.5, 1.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n4", 0.7, 3.0; multipart_group="", action="greet"),
        VoteOrchestrator.VoteCandidate("n5", 0.6, 2.0; multipart_group="", action="greet"),
    ]
    VoteOrchestrator.enforce_duplicate_solver_cap!(cands)
    log = VoteOrchestrator.get_last_duplicate_solver_log()
    @test length(log) == 1
    @test log[1].evicted_node_ids == ["n3"]
end

# ==============================================================================
# [6] EXACT-NODE-COPY GUARD (AutoGrowth._is_exact_node_duplicate)
# ==============================================================================
# GRUG: This is a SEPARATE, lightweight check from the VoteOrchestrator cap
# above. It lives in AutoGrowth.jl and blocks growth of BYTE-IDENTICAL node
# clones (same pattern AND action_packet AND drop_table). It must NOT block
# nodes that merely share a pattern with different action_packet/drop_table
# — that sharing is explicitly desired (anti-staleness via diversity).
#
# We test the guard function directly with a minimal mock "node" struct
# (only needs .is_grave, .pattern, .action_packet, .drop_table — exactly what
# _is_exact_node_duplicate reads) so this test file stays independent of the
# full engine.jl / Node struct load (which requires the whole GrugBot420
# dependency chain to construct real Node objects).
# ==============================================================================

module _ExactDupTestParent
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
    include(joinpath(@__DIR__, "..", "src", "InverseSigil.jl"))
    using .InverseSigil
    include(joinpath(@__DIR__, "..", "src", "AutoGrowth.jl"))
end

using ._ExactDupTestParent.AutoGrowth

# GRUG: Minimal mock standing in for engine.Node — only the 3 fields
# _is_exact_node_duplicate actually reads, plus is_grave.
mutable struct _MockNode
    id::String
    pattern::String
    action_packet::String
    drop_table::Vector{String}
    is_grave::Bool
end

@testset "[6] Exact node copy guard — byte-identical clones blocked" begin
    node_map  = Dict{String, _MockNode}()
    node_lock = ReentrantLock()

    existing = _MockNode("node_1", "big red rock", "describe^1", ["drop_a", "drop_b"], false)
    node_map["node_1"] = existing

    # GRUG: byte-identical copy (same pattern, same action_packet, same drop_table) -> blocked
    @test AutoGrowth._is_exact_node_duplicate(
        "big red rock", "describe^1", ["drop_a", "drop_b"], node_map, node_lock) == true

    # GRUG: drop_table order-insensitive — same SET of drops still counts as identical
    @test AutoGrowth._is_exact_node_duplicate(
        "big red rock", "describe^1", ["drop_b", "drop_a"], node_map, node_lock) == true

    # GRUG: case-insensitive / whitespace-insensitive on pattern (matches node.pattern normalization elsewhere)
    @test AutoGrowth._is_exact_node_duplicate(
        "  BIG RED ROCK  ", "describe^1", ["drop_a", "drop_b"], node_map, node_lock) == true
end

@testset "[6b] IDENTICAL pattern/bind sites with DIFFERENT structure ARE ALLOWED" begin
    node_map  = Dict{String, _MockNode}()
    node_lock = ReentrantLock()

    existing = _MockNode("node_1", "big red rock", "describe^1", ["drop_a", "drop_b"], false)
    node_map["node_1"] = existing

    # GRUG: same pattern, DIFFERENT action_packet -> NOT an exact duplicate. Allowed.
    @test AutoGrowth._is_exact_node_duplicate(
        "big red rock", "warn^1", ["drop_a", "drop_b"], node_map, node_lock) == false

    # GRUG: same pattern, same action_packet, DIFFERENT drop_table -> NOT an exact duplicate. Allowed.
    @test AutoGrowth._is_exact_node_duplicate(
        "big red rock", "describe^1", ["drop_c"], node_map, node_lock) == false

    # GRUG: totally different pattern -> obviously not a duplicate.
    @test AutoGrowth._is_exact_node_duplicate(
        "small blue pebble", "describe^1", ["drop_a", "drop_b"], node_map, node_lock) == false
end

@testset "[6c] Grave nodes don't count as existing duplicates" begin
    node_map  = Dict{String, _MockNode}()
    node_lock = ReentrantLock()

    graved = _MockNode("node_1", "big red rock", "describe^1", ["drop_a", "drop_b"], true)  # is_grave=true
    node_map["node_1"] = graved

    # GRUG: the only matching node is dead — growth should NOT be blocked.
    @test AutoGrowth._is_exact_node_duplicate(
        "big red rock", "describe^1", ["drop_a", "drop_b"], node_map, node_lock) == false
end

println("\n" * "="^60)
println("ALL DUPLICATE SOLVER CAP TESTS COMPLETE")
println("="^60)
