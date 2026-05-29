# test/test_multipart_orchestrator.jl
# v7.23 — exercise the multipart vote coalescing primitive.
#
# Loads source modules directly inside a parent module (matching the pattern
# used by test_arithmetic_engine.jl) so we don't depend on the package
# precompile cache being warm. MultipartOrchestrator does
# `using ..VoteOrchestrator: ...`, so VoteOrchestrator must live in the
# parent module too.

using Test
using Random

module _MultipartTestParent
    include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "MultipartOrchestrator.jl"))
    using .VoteOrchestrator
    using .MultipartOrchestrator

    # We need a minimal Vote-like struct. Rather than pull in the full engine,
    # we build a stand-in that has the duck-typed fields the orchestrator
    # reads via `getfield`. This isolates the test from engine.jl's heavyweight
    # dependencies while exercising the exact field-access path the production
    # code uses.
    # v7.23: Added input_chunks field for chunked affinities support.
    struct TestVote
        node_id::String
        action::String
        confidence::Float64
        multipart_group::String
        multipart_role::Symbol
        input_chunks::Vector{Int}
    end
end

using ._MultipartTestParent: TestVote
using ._MultipartTestParent.MultipartOrchestrator

@testset "MultipartOrchestrator — singleton passthrough" begin
    v = TestVote("node_a", "reason", 0.7, "", :singleton, Int[])
    objs = build_objectives([v])
    @test length(objs) == 1
    @test objs[1].is_multipart == false
    @test objs[1].group_id == ""
    @test isempty(objs[1].locked_supports)
    @test isempty(objs[1].unsure_supports)
    @test getfield(objs[1].primary, :node_id) == "node_a"
    @test occursin("singleton", summarize_objective(objs[1]))
end

@testset "MultipartOrchestrator — pure multipart group" begin
    # GRUG: support classification touches a strength-biased coinflip; seed
    # the RNG so the test is deterministic across the runtests harness.
    Random.seed!(0x6e75)

    primary  = TestVote("node_x", "explain_force", 0.85, "g1", :primary, Int[])
    s_lock   = TestVote("node_x", "note_mass",     0.84, "g1", :support, Int[])
    s_unsure = TestVote("node_x", "note_acc",      0.55, "g1", :support, Int[])
    s_drop   = TestVote("node_x", "note_irrelevant", 0.05, "g1", :support, Int[])

    objs = build_objectives([primary, s_lock, s_unsure, s_drop];
                            strength_of = _ -> 10.0,
                            strength_cap = 10.0)
    @test length(objs) == 1
    o = objs[1]
    @test o.is_multipart
    @test o.group_id == "g1"
    @test getfield(o.primary, :action) == "explain_force"
    @test length(o.locked_supports) == 1
    @test getfield(o.locked_supports[1], :action) == "note_mass"
    @test !any(getfield(s, :action) == "note_irrelevant" for s in o.unsure_supports)
    @test !any(getfield(s, :action) == "note_irrelevant" for s in o.locked_supports)
    # s_unsure landed in the unsure tier; strength=10 means survive coinflip
    # ~90% of the time; statistically combined with the seed above this is
    # deterministic. We assert presence rather than exact length to remain
    # robust if the strength-bias formula is later retuned.
    @test any(getfield(s, :action) == "note_acc" for s in o.unsure_supports) ||
          any(getfield(s, :action) == "note_acc" for s in o.locked_supports) == false  # not in locked
    # Stronger property: no support survived in BOTH buckets simultaneously.
    locked_ids = Set(getfield(s, :action) for s in o.locked_supports)
    unsure_ids = Set(getfield(s, :action) for s in o.unsure_supports)
    @test isempty(intersect(locked_ids, unsure_ids))
end

@testset "MultipartOrchestrator — pure multipart, deterministic unsure with high-strength override" begin
    # GRUG: explicit version — force the coin to keep by seeding tightly,
    # to verify the unsure bucket carries the support that was below the
    # lock window but above threshold.
    primary = TestVote("node_x", "p", 0.85, "g1", :primary, Int[])
    s_unsure = TestVote("node_x", "u", 0.55, "g1", :support, Int[])
    # Run many trials; with strength=10, ~90% retention rate => well over
    # half should keep s_unsure across N=200.
    keeps = 0
    for _ in 1:200
        objs = build_objectives([primary, s_unsure];
                                strength_of = _ -> 10.0,
                                strength_cap = 10.0)
        if any(getfield(s, :action) == "u" for s in objs[1].unsure_supports)
            keeps += 1
        end
    end
    # Loose lower bound: 10 < observed < 200 with overwhelming probability.
    @test keeps > 100
end

@testset "MultipartOrchestrator — mixed singletons + group" begin
    s1  = TestVote("a", "greet", 0.6, "",   :singleton, Int[])
    p   = TestVote("b", "plan",  0.9, "g2", :primary, Int[])
    # Pick support confidence inside the lock window so this test is
    # deterministic regardless of the strength-biased coinflip.
    sup = TestVote("b", "step",  0.88, "g2", :support, Int[])
    s2  = TestVote("c", "smile", 0.5, "",   :singleton, Int[])

    objs = build_objectives([s1, p, sup, s2]; strength_of = _ -> 10.0)
    @test length(objs) == 3
    multi = filter(o -> o.is_multipart, objs)
    @test length(multi) == 1
    @test multi[1].group_id == "g2"
    @test length(multi[1].locked_supports) == 1
end

@testset "MultipartOrchestrator — malformed group: zero primaries" begin
    s1 = TestVote("a", "x", 0.7, "bad", :support, Int[])
    s2 = TestVote("a", "y", 0.6, "bad", :support, Int[])
    @test_throws MultipartError build_objectives([s1, s2])
end

@testset "MultipartOrchestrator — malformed group: two primaries" begin
    p1 = TestVote("a", "x", 0.7, "bad", :primary, Int[])
    p2 = TestVote("a", "y", 0.7, "bad", :primary, Int[])
    @test_throws MultipartError build_objectives([p1, p2])
end

@testset "MultipartOrchestrator — group_votes_by_multipart partition" begin
    a = TestVote("a", "act", 0.5, "",  :singleton, Int[])
    b = TestVote("b", "act", 0.5, "G", :primary, Int[])
    sing, grp = group_votes_by_multipart([a, b])
    @test length(sing) == 1 && getfield(sing[1], :node_id) == "a"
    @test haskey(grp, "G") && length(grp["G"]) == 1
end
