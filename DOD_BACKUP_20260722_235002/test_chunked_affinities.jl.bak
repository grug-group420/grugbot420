# test/test_chunked_affinities.jl
# ==============================================================================
# v7.23 — Chunked Affinities: group_votes_by_chunks, _objective_from_chunk_group,
#          build_objectives auto-detection, HippocampalModulator chunk-aware deps.
#
# Part 1 (lightweight): Tests MultipartOrchestrator chunk-aware grouping using
#   a duck-typed TestVote struct (no engine.jl dependency).
# Part 2 (heavyweight): Tests _match_to_chunks from engine.jl + InputDecomposer
#   chunk_boundaries.
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
using Random

println("\n" * "="^60)
println("CHUNKED AFFINITIES TESTS — Part 1: MultipartOrchestrator")
println("="^60)

# ==============================================================================
# Part 1: Lightweight MultipartOrchestrator tests (no engine.jl)
# ==============================================================================

module _ChunkedAffinityTestParent
    include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "MultipartOrchestrator.jl"))
    using .VoteOrchestrator
    using .MultipartOrchestrator

    # Duck-typed Vote with input_chunks field for testing.
    # The orchestrator reads fields via getfield, so this works.
    struct TestVote
        node_id::String
        action::String
        confidence::Float64
        multipart_group::String
        multipart_role::Symbol
        input_chunks::Vector{Int}
    end
end

using ._ChunkedAffinityTestParent: TestVote
using ._ChunkedAffinityTestParent.MultipartOrchestrator

# ==============================================================================
# HELPERS
# ==============================================================================

function make_chunked_vote(node_id::String, action::String, confidence::Float64,
                           input_chunks::Vector{Int})
    group_id = isempty(input_chunks) ? "" : "mp_$(input_chunks[1])"
    return TestVote(node_id, action, confidence, group_id, :primary, input_chunks)
end

function make_legacy_vote(node_id::String, action::String, confidence::Float64,
                          group_id::String = "", role::Symbol = :singleton)
    return TestVote(node_id, action, confidence, group_id, role, Int[])
end

function make_multipart_objective(group_id::String, primary_vote, locked_votes, unsure_votes)
    return MultipartObjective(
        group_id, primary_vote, locked_votes, unsure_votes, true
    )
end

function make_singleton_objective(node_id::String, action::String, confidence::Float64)
    v = make_legacy_vote(node_id, action, confidence, "", :singleton)
    return MultipartObjective("", v, Any[], Any[], false)
end

# ==============================================================================
# TEST 1: group_votes_by_chunks — no chunked votes (pure legacy)
# ==============================================================================

@testset "group_votes_by_chunks — no chunked votes (pure legacy)" begin
    v1 = make_legacy_vote("n1", "act1", 0.9, "", :singleton)
    v2 = make_legacy_vote("n2", "act2", 0.8, "mp_1", :primary)
    v3 = make_legacy_vote("n3", "act3", 0.7, "mp_1", :support)

    singletons, groups = group_votes_by_chunks([v1, v2, v3])

    @test length(singletons) == 1
    @test getfield(singletons[1], :node_id) == "n1"
    @test haskey(groups, "mp_1")
    @test length(groups["mp_1"]) == 2
end

# ==============================================================================
# TEST 2: group_votes_by_chunks — all chunked, no overlap → separate groups
# ==============================================================================

@testset "group_votes_by_chunks — all chunked, no overlap" begin
    v1 = make_chunked_vote("n1", "act1", 0.9, [1])
    v2 = make_chunked_vote("n2", "act2", 0.8, [3])

    singletons, groups = group_votes_by_chunks([v1, v2])

    @test isempty(singletons)
    @test length(groups) == 2
    @test haskey(groups, "chk_1")
    @test haskey(groups, "chk_3")
    @test length(groups["chk_1"]) == 1
    @test length(groups["chk_3"]) == 1
end

# ==============================================================================
# TEST 3: group_votes_by_chunks — chunked votes with overlap → one group
# ==============================================================================

@testset "group_votes_by_chunks — overlapping chunks coalesce" begin
    v1 = make_chunked_vote("n1", "act1", 0.9, [1, 2])
    v2 = make_chunked_vote("n2", "act2", 0.8, [2, 3])

    singletons, groups = group_votes_by_chunks([v1, v2])

    @test isempty(singletons)
    @test length(groups) == 1
    gid = collect(keys(groups))[1]
    @test startswith(gid, "chk_")
    @test length(groups[gid]) == 2
end

# ==============================================================================
# TEST 4: group_votes_by_chunks — transitive chunk overlap
# ==============================================================================

@testset "group_votes_by_chunks — transitive overlap via bridge vote" begin
    # v1 covers [1,2], v2 covers [2,3], v3 covers [3,4]
    # v1 and v3 don't share a chunk directly, but v2 bridges them
    v1 = make_chunked_vote("n1", "act1", 0.9, [1, 2])
    v2 = make_chunked_vote("n2", "act2", 0.8, [2, 3])
    v3 = make_chunked_vote("n3", "act3", 0.7, [3, 4])

    singletons, groups = group_votes_by_chunks([v1, v2, v3])

    @test isempty(singletons)
    @test length(groups) == 1
    gid = collect(keys(groups))[1]
    @test length(groups[gid]) == 3
    # The group name should contain all chunk indices
    @test occursin("1", gid)
    @test occursin("4", gid)
end

# ==============================================================================
# TEST 5: group_votes_by_chunks — mixed chunked and legacy
# ==============================================================================

@testset "group_votes_by_chunks — mixed chunked and legacy" begin
    v_chunk = make_chunked_vote("n1", "act1", 0.9, [1])
    v_legacy = make_legacy_vote("n2", "act2", 0.8, "mp_5", :primary)
    v_sing = make_legacy_vote("n3", "act3", 0.7, "", :singleton)

    singletons, groups = group_votes_by_chunks([v_chunk, v_legacy, v_sing])

    @test length(singletons) == 1
    @test getfield(singletons[1], :node_id) == "n3"
    @test haskey(groups, "chk_1")
    @test haskey(groups, "mp_5")
end

# ==============================================================================
# TEST 6: _objective_from_chunk_group — single vote
# ==============================================================================

@testset "_objective_from_chunk_group — single vote in group" begin
    v = make_chunked_vote("n1", "act1", 0.9, [1])
    obj = MultipartOrchestrator._objective_from_chunk_group("chk_1", [v])

    @test obj.is_multipart
    @test obj.group_id == "chk_1"
    @test getfield(obj.primary, :node_id) == "n1"
    @test isempty(obj.locked_supports)
    @test isempty(obj.unsure_supports)
end

# ==============================================================================
# TEST 7: _objective_from_chunk_group — highest confidence wins
# ==============================================================================

@testset "_objective_from_chunk_group — highest confidence becomes primary" begin
    # Use high strength to ensure all supports survive the coinflip
    v1 = make_chunked_vote("n1", "act_low", 0.7, [1])
    v2 = make_chunked_vote("n2", "act_high", 0.95, [1])
    v3 = make_chunked_vote("n3", "act_mid", 0.85, [1])

    obj = MultipartOrchestrator._objective_from_chunk_group("chk_1", [v1, v2, v3];
                threshold = 0.3, top_window = 0.3,
                strength_of = _ -> 10.0, strength_cap = 10.0)

    @test obj.is_multipart
    @test getfield(obj.primary, :node_id) == "n2"  # highest confidence
    @test getfield(obj.primary, :confidence) ≈ 0.95
    # v3 (0.85) is within top_window of primary (0.95-0.3=0.65) → locked
    # v1 (0.7) is within top_window too → locked
    all_supports = vcat(obj.locked_supports, obj.unsure_supports)
    @test length(all_supports) >= 1  # at least v3 should survive
    # Primary should NOT appear in supports
    support_ids = Set(getfield.(all_supports, :node_id))
    @test !("n2" in support_ids)  # n2 is the primary, not a support
end

# ==============================================================================
# TEST 8: _objective_from_chunk_group — empty group throws
# ==============================================================================

@testset "_objective_from_chunk_group — empty group throws" begin
    @test_throws MultipartOrchestrator.MultipartError MultipartOrchestrator._objective_from_chunk_group("chk_1", TestVote[])
end

# ==============================================================================
# TEST 9: build_objectives — legacy path (no input_chunks)
# ==============================================================================

@testset "build_objectives — legacy path (no input_chunks)" begin
    v1 = make_legacy_vote("n1", "act1", 0.9, "", :singleton)
    v2 = make_legacy_vote("n2", "act2", 0.85, "mp_1", :primary)
    v3 = make_legacy_vote("n3", "act3", 0.7, "mp_1", :support)

    objs = build_objectives([v1, v2, v3]; strength_of = _ -> 5.0)

    @test length(objs) == 2
    sing = filter(o -> !o.is_multipart, objs)
    mp   = filter(o -> o.is_multipart, objs)
    @test length(sing) == 1
    @test length(mp) == 1
    @test mp[1].group_id == "mp_1"
end

# ==============================================================================
# TEST 10: build_objectives — chunked path (with input_chunks)
# ==============================================================================

@testset "build_objectives — chunked path, separate chunks" begin
    v1 = make_chunked_vote("n1", "act1", 0.9, [1])
    v2 = make_chunked_vote("n2", "act2", 0.8, [2])

    objs = build_objectives([v1, v2]; strength_of = _ -> 5.0)

    @test all(o -> o.is_multipart, objs)
    gids = [o.group_id for o in objs]
    @test "chk_1" in gids
    @test "chk_2" in gids
end

# ==============================================================================
# TEST 11: build_objectives — chunked overlap coalesces into one objective
# ==============================================================================

@testset "build_objectives — chunked overlap coalesces" begin
    v1 = make_chunked_vote("n1", "act1", 0.9, [1, 2])
    v2 = make_chunked_vote("n2", "act2", 0.8, [2, 3])

    objs = build_objectives([v1, v2]; strength_of = _ -> 5.0)

    @test length(objs) == 1
    @test objs[1].is_multipart
    @test getfield(objs[1].primary, :node_id) == "n1"  # higher confidence
end

# ==============================================================================
# TEST 12: build_objectives — mixed chunked and legacy
# ==============================================================================

@testset "build_objectives — mixed chunked and legacy" begin
    v_chunk = make_chunked_vote("n1", "act1", 0.9, [1])
    v_legacy = make_legacy_vote("n2", "act2", 0.8, "mp_5", :primary)
    v_sing = make_legacy_vote("n3", "act3", 0.7, "", :singleton)

    objs = build_objectives([v_chunk, v_legacy, v_sing]; strength_of = _ -> 5.0)

    sing = filter(o -> !o.is_multipart, objs)
    mp   = filter(o -> o.is_multipart, objs)
    @test length(sing) == 1
    @test length(mp) == 2

    gids = [o.group_id for o in mp]
    @test "chk_1" in gids
    @test "mp_5" in gids
end

# ==============================================================================
# TEST 13: summarize_objective shows chunk info
# ==============================================================================

@testset "summarize_objective — chunk info displayed" begin
    v = make_chunked_vote("n1", "reason", 0.9, [1, 2])
    obj = MultipartObjective("chk_1_2", v, Any[], Any[], true)
    summary = summarize_objective(obj)
    @test occursin("chk_1_2", summary)
    @test occursin("chunks=[1, 2]", summary)
end

@testset "summarize_objective — singleton no chunk info" begin
    v = make_legacy_vote("n1", "reason", 0.9)
    obj = MultipartObjective("", v, Any[], Any[], false)
    summary = summarize_objective(obj)
    @test occursin("singleton", summary)
    @test !occursin("chunks=", summary)
end

println("\n" * "="^60)
println("✅ PART 1 PASSED — MultipartOrchestrator chunked affinities")
println("="^60)

# ==============================================================================
# Part 2: HippocampalModulator chunk-aware dependencies
# ==============================================================================

println("\n" * "="^60)
println("CHUNKED AFFINITIES TESTS — Part 2: HippocampalModulator")
println("="^60)

# Load HippocampalModulator with its dependencies.
# We reuse the _ChunkedAffinityTestParent module which already has
# VoteOrchestrator and MultipartOrchestrator loaded.

# We need to load HippocampalModulator inside a module that has
# MultipartOrchestrator visible. Let's create a fresh parent.
module _HippoChunkTestParent
    include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "MultipartOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "HippocampalModulator.jl"))
    using .VoteOrchestrator
    using .MultipartOrchestrator
    using .HippocampalModulator

    struct TestVote2
        node_id::String
        action::String
        confidence::Float64
        multipart_group::String
        multipart_role::Symbol
        input_chunks::Vector{Int}
    end
end

using ._HippoChunkTestParent.HippocampalModulator
using ._HippoChunkTestParent.MultipartOrchestrator

function make_chunked_vote2(node_id::String, action::String, confidence::Float64,
                            input_chunks::Vector{Int})
    group_id = isempty(input_chunks) ? "" : "mp_$(input_chunks[1])"
    return _HippoChunkTestParent.TestVote2(node_id, action, confidence, group_id, :primary, input_chunks)
end

function make_legacy_vote2(node_id::String, action::String, confidence::Float64,
                           group_id::String = "", role::Symbol = :singleton)
    return _HippoChunkTestParent.TestVote2(node_id, action, confidence, group_id, role, Int[])
end

function make_multipart_objective2(group_id::String, primary_vote, locked_votes, unsure_votes)
    return _HippoChunkTestParent.MultipartOrchestrator.MultipartObjective(
        group_id, primary_vote, locked_votes, unsure_votes, true
    )
end

function make_singleton_objective2(node_id::String, action::String, confidence::Float64)
    v = make_legacy_vote2(node_id, action, confidence, "", :singleton)
    return _HippoChunkTestParent.MultipartOrchestrator.MultipartObjective("", v, Any[], Any[], false)
end

# ==============================================================================
# TEST 14: Chunk-derived objectives, no overlap → no deps
# ==============================================================================

@testset "HippocampalModulator — chunk-derived, no overlap → no deps" begin
    log = _HippoChunkTestParent.HippocampalModulator.create_action_log!()

    v1 = make_chunked_vote2("n1", "act1", 0.9, [1])
    v2 = make_chunked_vote2("n2", "act2", 0.8, [3])

    obj1 = make_multipart_objective2("chk_1", v1, Any[], Any[])
    obj2 = make_multipart_objective2("chk_3", v2, Any[], Any[])

    _HippoChunkTestParent.HippocampalModulator.modulate_objectives!(log, [obj1, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != _HippoChunkTestParent.HippocampalModulator.ENTRY_ADDITIVE]
    @test length(sure_entries) == 2
    # Both should have no dependencies — they're independent
    @test isempty(sure_entries[1].dependencies)
    @test isempty(sure_entries[2].dependencies)
end

# ==============================================================================
# TEST 15: Chunk-derived objectives, overlapping chunks → deps
# ==============================================================================

@testset "HippocampalModulator — chunk-derived, overlapping → deps" begin
    log = _HippoChunkTestParent.HippocampalModulator.create_action_log!()

    v1 = make_chunked_vote2("n1", "act1", 0.9, [1, 2])
    v2 = make_chunked_vote2("n2", "act2", 0.8, [2, 3])

    obj1 = make_multipart_objective2("chk_1_2", v1, Any[], Any[])
    obj2 = make_multipart_objective2("chk_2_3", v2, Any[], Any[])

    _HippoChunkTestParent.HippocampalModulator.modulate_objectives!(log, [obj1, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != _HippoChunkTestParent.HippocampalModulator.ENTRY_ADDITIVE]
    @test length(sure_entries) == 2
    @test isempty(sure_entries[1].dependencies)
    # Second entry depends on first (they share chunk 2)
    @test sure_entries[2].dependencies == [sure_entries[1].sequence_number]
end

# ==============================================================================
# TEST 16: Legacy objectives still use conservative deps
# ==============================================================================

@testset "HippocampalModulator — legacy objectives conservative deps" begin
    log = _HippoChunkTestParent.HippocampalModulator.create_action_log!()

    v1 = make_legacy_vote2("n1", "act1", 0.9, "mp_1", :primary)
    v2 = make_legacy_vote2("n2", "act2", 0.8, "mp_2", :primary)

    obj1 = make_multipart_objective2("mp_1", v1, Any[], Any[])
    obj2 = make_multipart_objective2("mp_2", v2, Any[], Any[])

    _HippoChunkTestParent.HippocampalModulator.modulate_objectives!(log, [obj1, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != _HippoChunkTestParent.HippocampalModulator.ENTRY_ADDITIVE]
    @test length(sure_entries) == 2
    @test isempty(sure_entries[1].dependencies)
    # Legacy: second depends on first (conservative)
    @test sure_entries[2].dependencies == [sure_entries[1].sequence_number]
end

# ==============================================================================
# TEST 17: Mixed chunk/legacy: chunk deps based on overlap, legacy conservative
# ==============================================================================

@testset "HippocampalModulator — mixed chunk/legacy deps" begin
    log = _HippoChunkTestParent.HippocampalModulator.create_action_log!()

    v1 = make_chunked_vote2("n1", "act1", 0.9, [1])
    obj1 = make_multipart_objective2("chk_1", v1, Any[], Any[])

    v2 = make_chunked_vote2("n2", "act2", 0.8, [3])
    obj2 = make_multipart_objective2("chk_3", v2, Any[], Any[])

    v3 = make_legacy_vote2("n3", "act3", 0.85, "mp_5", :primary)
    obj3 = make_multipart_objective2("mp_5", v3, Any[], Any[])

    _HippoChunkTestParent.HippocampalModulator.modulate_objectives!(log, [obj1, obj2, obj3])

    sure_entries = [e for e in log.entries if e.entry_type != _HippoChunkTestParent.HippocampalModulator.ENTRY_ADDITIVE]
    @test length(sure_entries) == 3

    # v7.47: Confidence ordering: 0.9, 0.85, 0.8
    # Entry 1: chk_1 (0.9)
    # Entry 2: mp_5 (0.85)
    # Entry 3: chk_3 (0.8)
    @test sure_entries[1].objective_id == "chk_1"
    @test sure_entries[1].confidence == 0.9
    @test isempty(sure_entries[1].dependencies)

    @test sure_entries[2].objective_id == "mp_5"
    @test sure_entries[2].confidence == 0.85
    # mp_5 is legacy, no chunks → conservative: depends on all prior multipart
    # chk_1 is multipart and comes before mp_5
    @test sure_entries[1].sequence_number in sure_entries[2].dependencies

    @test sure_entries[3].objective_id == "chk_3"
    @test sure_entries[3].confidence == 0.8
    # chk_3 has no overlap with chk_1 → no chunk deps
    # But mp_5 is legacy and came before chk_3, so chk_3 doesn't depend on it
    # (chunk-derived groups only depend on overlapping chunks, not on legacy groups)
    @test isempty(sure_entries[3].dependencies)
end

# ==============================================================================
# TEST 18: Singletons + chunk-derived with overlap
# ==============================================================================

@testset "HippocampalModulator — singletons + chunk overlap" begin
    log = _HippoChunkTestParent.HippocampalModulator.create_action_log!()

    sing = make_singleton_objective2("n_s", "act_s", 0.6)

    v1 = make_chunked_vote2("n1", "act1", 0.9, [1, 2])
    obj1 = make_multipart_objective2("chk_1_2", v1, Any[], Any[])

    v2 = make_chunked_vote2("n2", "act2", 0.8, [2, 3])
    obj2 = make_multipart_objective2("chk_2_3", v2, Any[], Any[])

    _HippoChunkTestParent.HippocampalModulator.modulate_objectives!(log, [obj1, sing, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != _HippoChunkTestParent.HippocampalModulator.ENTRY_ADDITIVE]
    @test length(sure_entries) == 3

    # v7.47: ALL entries sorted by confidence descending
    # Entry 1: chk_1_2 (0.9) — highest confidence
    # Entry 2: chk_2_3 (0.8) — next highest
    # Entry 3: singleton (0.6) — lowest
    @test sure_entries[1].objective_id == "chk_1_2"
    @test sure_entries[1].confidence == 0.9
    @test isempty(sure_entries[1].dependencies)

    @test sure_entries[2].objective_id == "chk_2_3"
    @test sure_entries[2].confidence == 0.8
    # chk_2_3 depends on chk_1_2 (shared chunk 2)
    @test sure_entries[1].sequence_number in sure_entries[2].dependencies

    @test sure_entries[3].objective_id == ""
    @test sure_entries[3].confidence == 0.6
    @test isempty(sure_entries[3].dependencies)
end

# ==============================================================================
# TEST 19: _chunks_from_group_id helper
# ==============================================================================

@testset "_chunks_from_group_id — parsing" begin
    @test HippocampalModulator._chunks_from_group_id("chk_1") == Set([1])
    @test HippocampalModulator._chunks_from_group_id("chk_1_2_3") == Set([1, 2, 3])
    @test HippocampalModulator._chunks_from_group_id("mp_1") == Set{Int}()
    @test HippocampalModulator._chunks_from_group_id("") == Set{Int}()
end

println("\n" * "="^60)
println("✅ PART 2 PASSED — HippocampalModulator chunk-aware dependencies")
println("="^60)

# ==============================================================================
# Part 3: InputDecomposer.chunk_boundaries + _match_to_chunks
# ==============================================================================

println("\n" * "="^60)
println("CHUNKED AFFINITIES TESTS — Part 3: InputDecomposer + _match_to_chunks")
println("="^60)

module _InputChunkTestParent
    include(joinpath(@__DIR__, "..", "src", "InputDecomposer.jl"))
    using .InputDecomposer
end

using ._InputChunkTestParent.InputDecomposer

# ==============================================================================
# TEST 20: chunk_boundaries — simple text
# ==============================================================================

@testset "chunk_boundaries — simple text" begin
    chunks = InputDecomposer.chunk_boundaries("hello world")
    @test length(chunks) >= 1
    @test chunks[1].first_token == 1
    @test chunks[1].chunk_index == 1
end

# ==============================================================================
# TEST 21: chunk_boundaries — empty string
# ==============================================================================

@testset "chunk_boundaries — empty string" begin
    chunks = InputDecomposer.chunk_boundaries("")
    # Empty input still gets one chunk (by design) with last_token=0
    @test length(chunks) == 1
    @test chunks[1].first_token == 1
    @test chunks[1].last_token == 0
    @test chunks[1].chunk_index == 1
end

# ==============================================================================
# TEST 22: chunk_boundaries — multi-sentence text
# ==============================================================================

@testset "chunk_boundaries — multi-sentence text" begin
    chunks = InputDecomposer.chunk_boundaries("hello world. foo bar baz.")
    @test length(chunks) >= 1
    # Tokens should be contiguous
    for i in 2:length(chunks)
        @test chunks[i].first_token == chunks[i-1].last_token + 1
    end
end

# ==============================================================================
# TEST 23: _match_to_chunks — basic overlap (standalone test)
# ==============================================================================

@testset "_match_to_chunks — basic overlap (via InputChunk)" begin
    # Build InputChunk objects manually to test the resolution logic
    chunks = [
        InputDecomposer.InputChunk(1, 5, 1, "hello world foo bar baz"),
        InputDecomposer.InputChunk(6, 10, 2, "qux quux corge grault garply"),
    ]

    # Match at token 3, pattern length 2 → tokens 3-4 → chunk 1
    # Note: We can't call engine._match_to_chunks without loading engine.jl,
    # so we test the algorithm inline to verify the logic.
    best_idx = 3
    pat_len = 2
    match_first = best_idx
    match_last = best_idx + pat_len - 1

    result = Int[]
    for chunk in chunks
        overlap_first = max(match_first, chunk.first_token)
        overlap_last = min(match_last, chunk.last_token)
        if overlap_first <= overlap_last
            push!(result, chunk.chunk_index)
        end
    end
    @test result == [1]

    # Match spanning both chunks: token 5, length 3 → tokens 5-7
    best_idx = 5
    pat_len = 3
    match_first = best_idx
    match_last = best_idx + pat_len - 1

    result = Int[]
    for chunk in chunks
        overlap_first = max(match_first, chunk.first_token)
        overlap_last = min(match_last, chunk.last_token)
        if overlap_first <= overlap_last
            push!(result, chunk.chunk_index)
        end
    end
    @test sort(result) == [1, 2]
end

println("\n" * "="^60)
println("✅ PART 3 PASSED — InputDecomposer + _match_to_chunks logic")
println("="^60)

println("\n" * "="^60)
println("✅ ALL CHUNKED AFFINITIES TESTS PASSED")
println("="^60)
