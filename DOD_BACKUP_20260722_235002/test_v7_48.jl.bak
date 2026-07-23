#!/usr/bin/env julia
# ==============================================================================
# v7.48 — Test relay discount + non-winner additive entries
# ==============================================================================
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

println("\n" * "="^60)
println("v7.48 RELAY DISCOUNT + NON-WINNER ADDITIVE TESTS")
println("="^60)

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
const SRC_DIR   = joinpath(REPO_ROOT, "src")

include(joinpath(SRC_DIR, "RelationalJitter.jl"))
using .RelationalJitter

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
include(joinpath(SRC_DIR, "MultipartOrchestrator.jl"))
using .MultipartOrchestrator
include(joinpath(SRC_DIR, "HippocampalModulator.jl"))
using .HippocampalModulator

# ==============================================================================
# Test 1: Relay discount in VoteOrchestrator
# ==============================================================================
@testset "v7.48 Relay confidence discount" begin
    # Same confidence, same everything — only is_relay differs
    vc_normal = VoteOrchestrator.VoteCandidate(
        "node_a", 4.0, 5.0;
        strength_cap=10.0, lobe_alignment=1.0, relational_match=0.5,
        recency_bonus=0.0, action_tone_align=1.0, anti_match_score=0.0,
        peak_dominance=1.0, frame_match_multiplier=1.0, is_relay=false
    )
    vc_relay = VoteOrchestrator.VoteCandidate(
        "node_b", 4.0, 5.0;
        strength_cap=10.0, lobe_alignment=1.0, relational_match=0.5,
        recency_bonus=0.0, action_tone_align=1.0, anti_match_score=0.0,
        peak_dominance=1.0, frame_match_multiplier=1.0, is_relay=true
    )

    score_normal = VoteOrchestrator.composite_vote_score(vc_normal)
    score_relay  = VoteOrchestrator.composite_vote_score(vc_relay)

    @test score_relay < score_normal
    # Relay discount = 0.5, so effective_confidence halves
    # score = effective_confidence * (1 + bonus) - effective_confidence * penalty
    # With same bonus/penalty, ratio should be ~0.5
    ratio = score_relay / score_normal
    @test 0.4 < ratio < 0.6  # Approximate, depends on bonus/penalty

    println("  ✓ Relay vote scores $(round(score_relay, digits=3)) vs normal $(round(score_normal, digits=3)) (ratio=$(round(ratio, digits=3)))")
end

# ==============================================================================
# Test 2: Relay detection via RELAY_CONFIDENCE_DISCOUNT constant
# ==============================================================================
@testset "v7.48 RELAY_CONFIDENCE_DISCOUNT constant exported" begin
    @test VoteOrchestrator.RELAY_CONFIDENCE_DISCOUNT == 0.5
    println("  ✓ RELAY_CONFIDENCE_DISCOUNT = $(VoteOrchestrator.RELAY_CONFIDENCE_DISCOUNT)")
end

# ==============================================================================
# Test 3: Non-winner additive entries in HippocampalModulator
# ==============================================================================

# Minimal vote-like struct for testing (doesn't need all fields)
struct TestVote
    node_id::String
    confidence::Float64
    action::Symbol
    multipart_group::String
    input_chunks::Vector{Int}
end

@testset "v7.48 Non-winner votes become additive entries" begin
    # Build objectives from 2 winning votes
    obj1 = MultipartOrchestrator.MultipartObjective(
        "", TestVote("node_a", 0.9, :explain, "", Int[]), Any[], Any[], false
    )
    obj2 = MultipartOrchestrator.MultipartObjective(
        "mp_1", TestVote("node_b", 0.7, :analyze, "mp_1", Int[]),
        Any[TestVote("node_c", 0.5, :ponder, "mp_1", Int[])],  # locked_support
        Any[TestVote("node_d", 0.4, :validate, "mp_1", Int[])],  # unsure_support
        true
    )

    # Non-winner votes (rejected by select_aiml_votes)
    nonwin1 = TestVote("node_e", 0.6, :define, "", Int[])
    nonwin2 = TestVote("node_f", 0.3, :clarify, "", Int[])

    log = HippocampalModulator.create_action_log!()
    HippocampalModulator.modulate_objectives!(log, [obj1, obj2];
        nonwinner_votes=[nonwin1, nonwin2])

    # Should have 2 sure entries + 1 unsure (from obj2) + 2 nonwinner = 5 total
    entries = HippocampalModulator.log_entries(log)
    n_sure = count(e -> e.entry_type == HippocampalModulator.ENTRY_SURE, entries)
    n_additive = count(e -> e.entry_type == HippocampalModulator.ENTRY_ADDITIVE, entries)

    @test n_sure == 2
    # node_d (unsure_support from obj2) + node_e + node_f (nonwinners) = 3 additives
    @test n_additive == 3
    @test length(entries) == 5

    # Verify nonwinner additive entries have correct node_ids
    additive_nids = [string(getfield(e.unsure_votes[1], :node_id)) for e in entries if e.entry_type == HippocampalModulator.ENTRY_ADDITIVE]
    @test "node_d" in additive_nids  # from unsure_supports
    @test "node_e" in additive_nids  # nonwinner
    @test "node_f" in additive_nids  # nonwinner

    # Nonwinners sorted by confidence (descending): node_e(0.6) before node_f(0.3)
    nw_entries = [e for e in entries if e.entry_type == HippocampalModulator.ENTRY_ADDITIVE && string(getfield(e.unsure_votes[1], :node_id)) in ["node_e", "node_f"]]
    @test length(nw_entries) == 2
    # The higher-confidence nonwinner should have a lower sequence number
    conf_e = getfield(nw_entries[1].unsure_votes[1], :confidence)
    conf_f = getfield(nw_entries[2].unsure_votes[1], :confidence)
    @test conf_e >= conf_f  # sorted descending

    println("  ✓ 2 sure + 3 additive entries (1 unsure_support + 2 nonwinner)")
    println("  ✓ Nonwinner votes sorted by confidence (descending)")
end

# ==============================================================================
# Test 4: Nonwinner that's already a primary gets filtered out
# ==============================================================================
@testset "v7.48 Nonwinner that won an objective is filtered" begin
    obj1 = MultipartOrchestrator.MultipartObjective(
        "", TestVote("node_a", 0.9, :explain, "", Int[]), Any[], Any[], false
    )

    # This nonwinner is the SAME node as obj1's primary — should be filtered
    nonwin_dupe = TestVote("node_a", 0.5, :ponder, "", Int[])
    # This is a genuine nonwinner — should appear
    nonwin_real = TestVote("node_b", 0.3, :clarify, "", Int[])

    log = HippocampalModulator.create_action_log!()
    HippocampalModulator.modulate_objectives!(log, [obj1];
        nonwinner_votes=[nonwin_dupe, nonwin_real])

    entries = HippocampalModulator.log_entries(log)
    additive_nids = [string(getfield(e.unsure_votes[1], :node_id)) for e in entries if e.entry_type == HippocampalModulator.ENTRY_ADDITIVE]

    # node_a should NOT appear as additive (it's already a primary)
    @test !("node_a" in additive_nids)
    # node_b SHOULD appear as additive
    @test "node_b" in additive_nids

    println("  ✓ Duplicate primary filtered, genuine nonwinner preserved")
end

# ==============================================================================
# Test 5: No nonwinner_votes parameter → backward compatible
# ==============================================================================
@testset "v7.48 Backward compatibility (no nonwinner_votes)" begin
    obj1 = MultipartOrchestrator.MultipartObjective(
        "", TestVote("node_a", 0.9, :explain, "", Int[]), Any[], Any[], false
    )
    obj2 = MultipartOrchestrator.MultipartObjective(
        "mp_1", TestVote("node_b", 0.7, :analyze, "mp_1", Int[]),
        Any[],
        Any[TestVote("node_c", 0.4, :validate, "mp_1", Int[])],  # unsure_support
        true
    )

    log = HippocampalModulator.create_action_log!()
    # Call WITHOUT nonwinner_votes — should still work
    HippocampalModulator.modulate_objectives!(log, [obj1, obj2])

    entries = HippocampalModulator.log_entries(log)
    n_sure = count(e -> e.entry_type == HippocampalModulator.ENTRY_SURE, entries)
    n_additive = count(e -> e.entry_type == HippocampalModulator.ENTRY_ADDITIVE, entries)

    @test n_sure == 2
    @test n_additive == 1  # Only the unsure_support from obj2
    println("  ✓ Without nonwinner_votes: 2 sure + 1 unsure_support additive")
end

# ==============================================================================
# Test 6: Empty nonwinner_votes → no extra additives
# ==============================================================================
@testset "v7.48 Empty nonwinner_votes" begin
    obj1 = MultipartOrchestrator.MultipartObjective(
        "", TestVote("node_a", 0.9, :explain, "", Int[]), Any[], Any[], false
    )

    log = HippocampalModulator.create_action_log!()
    HippocampalModulator.modulate_objectives!(log, [obj1]; nonwinner_votes=Any[])

    entries = HippocampalModulator.log_entries(log)
    @test length(entries) == 1
    @test entries[1].entry_type == HippocampalModulator.ENTRY_SURE
    println("  ✓ Empty nonwinner_votes: just 1 sure entry")
end

println("\n" * "="^60)
println("✅ ALL v7.48 RELAY DISCOUNT + NON-WINNER ADDITIVE TESTS PASSED")
println("="^60)
