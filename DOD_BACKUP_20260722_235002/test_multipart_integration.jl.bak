# test/test_multipart_integration.jl
# v7.23 — integration test: InputDecomposer → MultipartOrchestrator → objective output.
#
# This test exercises the THREE-module pipeline that makes multipart work:
#   1. InputDecomposer decomposes compound input into sub-subjects with mp_1/mp_2 IDs
#   2. Those IDs flow through specimen tuples and into Vote structs
#   3. MultipartOrchestrator.build_objectives groups votes and produces objectives
#
# KEY DESIGN INSIGHT: When InputDecomposer splits "what is X also what is Y",
# each sub-subject is an INDEPENDENT question. Each gets its own multipart_group
# (mp_1, mp_2, ...) and each group's winning vote is :primary within that group.
# The decomposer's .role field (:primary, :support) is about ORDERING for the
# orchestrator's COMBINED output, NOT about the vote role within each group.
# Within a group, the top-scoring vote is always :primary.
#
# The test does NOT pull in the full engine (no NODE_MAP, no scan_and_expand).
# Instead it uses duck-typed TestVote structs and simulates the vote vectors
# that process_mission would produce after scanning each sub-subject.

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

# ── Load the three modules under test ──────────────────────────────────────────
module _MultipartIntegrationParent
    include(joinpath(@__DIR__, "..", "src", "InputDecomposer.jl"))
    using .InputDecomposer

    include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "MultipartOrchestrator.jl"))
    using .MultipartOrchestrator
end

using ._MultipartIntegrationParent: DecomposedSubSubject
using ._MultipartIntegrationParent.InputDecomposer
using ._MultipartIntegrationParent.MultipartOrchestrator

# ── Duck-typed Vote ────────────────────────────────────────────────────────────
# GRUG: Same stand-in as test_multipart_orchestrator.jl. MultipartOrchestrator
# reads fields via getfield, so we only need the fields it actually inspects.
struct TestVote
    node_id::String
    action::String
    confidence::Float64
    multipart_group::String
    multipart_role::Symbol
    input_chunks::Vector{Int}
end

# ==============================================================================
# TEST 1: End-to-end decomposition → grouping → objective building
# ==============================================================================
@testset "Multipart Integration — compound input → objectives" begin
    # STEP 1: Decompose a compound input.
    input = "what time is it also what is a dinosaur"
    subs = decompose_input(input)

    @test length(subs) == 2
    @test subs[1].multipart_group == "mp_1"
    @test subs[2].multipart_group == "mp_2"
    @test is_compound(input)

    # STEP 2: Simulate what process_mission would do — each sub-subject
    # gets its own scan pass. The WINNING vote from each sub-scan is
    # :primary within its own group. Each group is independent.
    v1 = TestVote("node_time",     "reason_time",     0.80, "mp_1", :primary, Int[])
    v2 = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", :primary, Int[])

    # STEP 3: Feed the votes to MultipartOrchestrator.
    # mp_1 and mp_2 are DIFFERENT groups, so each gets its own objective.
    # Each group has one :primary — this is the correct structure.
    objs = build_objectives([v1, v2]; strength_of = _ -> 8.0)

    @test length(objs) == 2
    @test all(o -> o.is_multipart, objs)

    group_ids = sort([o.group_id for o in objs])
    @test group_ids == ["mp_1", "mp_2"]

    mp1_obj = filter(o -> o.group_id == "mp_1", objs)[1]
    @test getfield(mp1_obj.primary, :node_id) == "node_time"

    mp2_obj = filter(o -> o.group_id == "mp_2", objs)[1]
    @test getfield(mp2_obj.primary, :node_id) == "node_dinosaur"
end

# ==============================================================================
# TEST 2: Singleton input → one objective
# ==============================================================================
@testset "Multipart Integration — singleton input → one objective" begin
    input = "what is a rock"
    subs = decompose_input(input)

    @test length(subs) == 1
    @test subs[1].multipart_group == ""
    @test subs[1].role == :singleton
    @test !is_compound(input)

    # Singleton vote → one singleton objective.
    v = TestVote("node_rock", "reason_rock", 0.7, "", :singleton, Int[])
    objs = build_objectives([v])

    @test length(objs) == 1
    @test !objs[1].is_multipart
    @test objs[1].group_id == ""
end

# ==============================================================================
# TEST 3: Triple compound → three objectives
# ==============================================================================
@testset "Multipart Integration — triple compound (also + and) → three objectives" begin
    input = "what time is it also what is a dinosaur and what is 2+2"
    subs = decompose_input(input)

    @test length(subs) == 3
    @test is_compound(input)

    # Each sub-subject gets its own group with :primary winning vote.
    votes = [TestVote("node_$(i)", "action_$(i)", 0.7 + 0.05*i,
                       "mp_$(i)", :primary, Int[])
             for i in 1:3]

    objs = build_objectives(votes; strength_of = _ -> 8.0)

    @test length(objs) == 3
    group_ids = sort([o.group_id for o in objs])
    @test group_ids == ["mp_1", "mp_2", "mp_3"]
end

# ==============================================================================
# TEST 4: Mixed: singleton votes + multipart votes from compound input
# ==============================================================================
@testset "Multipart Integration — mixed singleton + multipart votes" begin
    # GRUG: In process_mission, image specimens produce singleton votes with
    # ("", :singleton) even when the input is compound. This tests that
    # build_objectives handles the mix correctly.
    input = "what is fire also what is ice"
    subs = decompose_input(input)
    @test length(subs) == 2

    # Multipart votes from the compound sub-subjects.
    v_mp1 = TestVote("node_fire", "reason_fire", 0.85, "mp_1", :primary, Int[])
    v_mp2 = TestVote("node_ice",  "reason_ice",  0.78, "mp_2", :primary, Int[])

    # Singleton vote from an image specimen (or a node that didn't decompose).
    v_singleton = TestVote("node_img", "describe_image", 0.60, "", :singleton, Int[])

    objs = build_objectives([v_mp1, v_mp2, v_singleton]; strength_of = _ -> 8.0)

    @test length(objs) == 3
    multi  = filter(o -> o.is_multipart, objs)
    single = filter(o -> !o.is_multipart, objs)

    @test length(multi) == 2
    @test length(single) == 1
    @test single[1].group_id == ""
    @test getfield(single[1].primary, :node_id) == "node_img"
end

# ==============================================================================
# TEST 5: Multipart group with primary + supports (same group, multiple votes)
# ==============================================================================
@testset "Multipart Integration — group with primary and supports" begin
    # GRUG: When a single sub-subject scan produces MULTIPLE votes (e.g.
    # the top node plus a close runner-up), they should both be in the SAME
    # group: the winner is :primary, the runner-up is :support. This tests
    # that MultipartOrchestrator correctly partitions supports into locked
    # vs unsure within a single group.
    Random.seed!(0xCAFE)

    primary  = TestVote("node_a", "explain_physics", 0.85, "mp_1", :primary, Int[])
    s_lock   = TestVote("node_b", "note_gravity",    0.83, "mp_1", :support, Int[])
    s_unsure = TestVote("node_c", "note_momentum",   0.55, "mp_1", :support, Int[])
    # Below threshold — should be dropped entirely.
    s_drop   = TestVote("node_d", "note_irrelevant", 0.05, "mp_1", :support, Int[])

    objs = build_objectives([primary, s_lock, s_unsure, s_drop];
                            strength_of = _ -> 10.0,
                            strength_cap = 10.0)

    @test length(objs) == 1
    o = objs[1]
    @test o.is_multipart
    @test o.group_id == "mp_1"
    @test getfield(o.primary, :node_id) == "node_a"
    @test length(o.locked_supports) == 1
    @test getfield(o.locked_supports[1], :action) == "note_gravity"
    # s_drop was below threshold — should not appear anywhere.
    all_actions = [getfield(s, :action) for s in o.locked_supports ∪ o.unsure_supports]
    @test "note_irrelevant" ∉ all_actions
end

# ==============================================================================
# TEST 6: Group IDs are deterministic for same input
# ==============================================================================
@testset "Multipart Integration — deterministic group IDs" begin
    input = "what is the sun also what is the moon"
    subs1 = decompose_input(input)
    subs2 = decompose_input(input)

    @test subs1[1].multipart_group == subs2[1].multipart_group
    @test subs1[2].multipart_group == subs2[2].multipart_group
    @test subs1[1].multipart_group == "mp_1"
    @test subs1[2].multipart_group == "mp_2"
end

# ==============================================================================
# TEST 7: summarize_decomposition + summarize_objective end-to-end
# ==============================================================================
@testset "Multipart Integration — diagnostic summaries" begin
    input = "what is alpha also what is beta"
    subs = decompose_input(input)
    decomp_summary = InputDecomposer.summarize_decomposition(subs)

    @test occursin("compound", decomp_summary)
    @test occursin("mp_1", decomp_summary)

    votes = [TestVote("node_$(i)", "action_$(i)", 0.75,
                       "mp_$(i)", :primary, Int[])
             for i in 1:length(subs)]
    objs = build_objectives(votes; strength_of = _ -> 8.0)

    for obj in objs
        obj_summary = summarize_objective(obj)
        @test occursin("multipart", obj_summary) || occursin("singleton", obj_summary)
    end
end

# ==============================================================================
# TEST 8: Multi-question-mark split produces multiple objectives
# ==============================================================================
@testset "Multipart Integration — question-mark decomposition → objectives" begin
    input = "what time is it? what is a dinosaur? what is 2+2?"
    subs = decompose_input(input)

    @test length(subs) >= 2
    @test is_compound(input)

    votes = [TestVote("node_$(i)", "action_$(i)", 0.65 + 0.05*i,
                       subs[i].multipart_group, :primary, Int[])
             for i in 1:length(subs)]

    objs = build_objectives(votes; strength_of = _ -> 8.0)

    # Each sub-question should get its own objective.
    @test length(objs) == length(subs)
    # All should be multipart (non-empty group_id).
    @test all(o -> o.is_multipart, objs)
end

# ==============================================================================
# TEST 9: "and" with no question markers → singleton (not decomposed)
# ==============================================================================
@testset "Multipart Integration — and-no-split stays singleton" begin
    input = "bread and butter"
    subs = decompose_input(input)

    @test length(subs) == 1
    @test !is_compound(input)

    v = TestVote("node_food", "describe_food", 0.6, "", :singleton, Int[])
    objs = build_objectives([v])

    @test length(objs) == 1
    @test !objs[1].is_multipart
end

# ==============================================================================
# TEST 10: Two independent groups + singleton in same pool
# ==============================================================================
@testset "Multipart Integration — two groups plus singleton" begin
    # Simulates: "what is X also what is Y" + an image node that matched
    # as singleton. Three objectives total.
    v1 = TestVote("node_x",   "explain_x",    0.80, "mp_1", :primary, Int[])
    v2 = TestVote("node_y",   "explain_y",    0.75, "mp_2", :primary, Int[])
    v3 = TestVote("node_img", "describe_img", 0.60, "",     :singleton, Int[])

    objs = build_objectives([v1, v2, v3]; strength_of = _ -> 8.0)

    @test length(objs) == 3
    multi  = filter(o -> o.is_multipart, objs)
    single = filter(o -> !o.is_multipart, objs)
    @test length(multi) == 2
    @test length(single) == 1
end

# ==============================================================================
# TEST 11: REGRESSION — using decomposer .role as vote role would FAIL
# ==============================================================================
# GRUG: This is the bug that was in process_mission! When InputDecomposer
# splits "what is X also what is Y", subs[2].role is :support. If process_mission
# stamps that :support as the vote's multipart_role, then MultipartOrchestrator
# sees mp_2 with ZERO :primary votes and throws MultipartError. The fix is to
# stamp :primary as the vote role for EVERY group's winning vote. Each sub-subject
# is an independent question — within its own group, the winner is :primary.
@testset "Multipart Integration — regression: every group needs :primary vote" begin
    input = "what time is it also what is a dinosaur"
    subs = decompose_input(input)

    @test length(subs) == 2
    @test subs[1].role == :primary
    @test subs[2].role == :support   # decomposer says :support for ordering

    # WRONG (old bug): using sub.role as vote multipart_role
    # v1_buggy = TestVote("node_time",     "reason_time",     0.80, "mp_1", subs[1].role)  # :primary — OK
    # v2_buggy = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", subs[2].role)  # :support — BOOM!
    # build_objectives([v1_buggy, v2_buggy])  # would throw MultipartError

    # CORRECT: every group's winning vote is :primary
    v1 = TestVote("node_time",     "reason_time",     0.80, "mp_1", :primary, Int[])
    v2 = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", :primary, Int[])

    objs = build_objectives([v1, v2]; strength_of = _ -> 8.0)

    @test length(objs) == 2
    @test all(o -> o.is_multipart, objs)

    # Verify that the WRONG pattern would indeed fail.
    v2_buggy = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", :support, Int[])
    @test_throws MultipartOrchestrator.MultipartError build_objectives([v1, v2_buggy]; strength_of = _ -> 8.0)
end

# ==============================================================================
# TEST 12: Triple compound — every group is :primary
# ==============================================================================
@testset "Multipart Integration — triple compound: all groups :primary" begin
    input = "what is the sun also what is the moon and what are the stars"
    subs = decompose_input(input)

    @test length(subs) == 3

    # All three get :primary as their vote role (not decomposer's .role)
    votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                       subs[i].multipart_group, :primary, Int[])
             for i in 1:3]

    objs = build_objectives(votes; strength_of = _ -> 8.0)
    @test length(objs) == 3

    # Verify: using decomposer roles would fail for mp_2 and mp_3
    buggy_votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                             subs[i].multipart_group, subs[i].role, Int[])
                   for i in 1:3]
    @test_throws MultipartOrchestrator.MultipartError build_objectives(buggy_votes; strength_of = _ -> 8.0)
end

# ==============================================================================
# TEST 13: Comma-based splitting → multiple objectives
# ==============================================================================
@testset "Multipart Integration — comma-separated compound questions" begin
    # "what is X, what is Y" should decompose into two sub-subjects
    input = "what is fire, what is ice"
    subs = decompose_input(input)

    @test length(subs) == 2
    @test is_compound(input)

    # Each sub-subject gets its own group with :primary winning vote.
    votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                       subs[i].multipart_group, :primary, Int[])
             for i in 1:length(subs)]

    objs = build_objectives(votes; strength_of = _ -> 8.0)
    @test length(objs) == 2
    @test all(o -> o.is_multipart, objs)
end
