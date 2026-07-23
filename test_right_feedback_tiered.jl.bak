# test/test_right_feedback_tiered.jl
# ==============================================================================
# BUG-011 — /right feedback is lock-in-only and stochastic.
# Non-lock / unsure votes never change strength. Compatibility result fields
# remain, but old tiered confidence reward and double-reward behavior are gone.
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
println("BUG-011 LOCK-IN-ONLY /RIGHT FEEDBACK TESTS")
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
include(joinpath(SRC_DIR, "EyeSystem.jl"))
using .EyeSystem
include(joinpath(SRC_DIR, "ActionTonePredictor.jl"))
using .ActionTonePredictor
include(joinpath(SRC_DIR, "LobeTable.jl"))
using .LobeTable
include(joinpath(SRC_DIR, "Lobe.jl"))
using .Lobe
include(joinpath(SRC_DIR, "BrainStem.jl"))
using .BrainStem
include(joinpath(SRC_DIR, "Thesaurus.jl"))
using .Thesaurus
include(joinpath(SRC_DIR, "InputQueue.jl"))
using .InputQueue
include(joinpath(SRC_DIR, "ChatterMode.jl"))
using .ChatterMode
include(joinpath(SRC_DIR, "PhagyMode.jl"))
using .PhagyMode
include(joinpath(SRC_DIR, "ImmuneSystem.jl"))
using .ImmuneSystem
include(joinpath(SRC_DIR, "ImmuneThreadPool.jl"))
using .ImmuneThreadPool
include(joinpath(SRC_DIR, "FullLobeScanner.jl"))
using .FullLobeScanner
include(joinpath(SRC_DIR, "AIMLNodeSystem.jl"))
using .AIMLNodeSystem

include(joinpath(SRC_DIR, "engine.jl"))

RelationalJitter.disable_jitter!()

function make_test_node(id::String, strength::Float64 = 5.0; time_node::Bool=false)
    node = Node(
        id,
        "test_$(id)",
        Float64[1.0, 2.0, 3.0],
        "test_action|test_slot",
        time_node ? Dict{String,Any}("time_node" => true) : Dict{String,Any}(),
        String[],
        1.0,
        RelationalTriple[],
        String[],
        Dict{String,Float64}(),
        strength,
        false,
        false,
        String[],
        false,
        12,
        false,
        "",
        Float64[],
        time(),
        UInt64(0),
        false,
        false,
        false,
        0.0,
        "test_$(id)",
        "test_action|test_slot",
    )
    lock(NODE_LOCK) do
        NODE_MAP[id] = node
    end
    return node
end

function cleanup_test_nodes(ids)
    lock(NODE_LOCK) do
        for id in ids
            delete!(NODE_MAP, id)
        end
    end
end

function vote_for(id::String; conf::Float64=0.9, role::Symbol=:singleton)
    return Vote(id, "act_$(id)", conf, String[], RelationalTriple[], RelationalTriple[], false, "", role)
end

@testset "BUG-011 /right — non-lock votes never change strength" begin
    ids = ["unsure_$i" for i in 1:25]
    for id in ids
        make_test_node(id, 5.0)
    end
    votes = [vote_for(id; conf=1.0, role=:support) for id in ids]

    result = apply_right_feedback!(votes, Set{String}())

    @test result["total_contributors"] == length(ids)
    @test isempty(result["rewarded"])
    @test isempty(result["locked_rewarded"])
    @test isempty(result["unsure_rewarded"])
    @test isempty(result["coinflip_missed"])
    @test Set(result["nonlocked_skipped"]) == Set(ids)

    lock(NODE_LOCK) do
        for id in ids
            @test NODE_MAP[id].strength == 5.0
            @test !NODE_MAP[id].gained_this_cycle
        end
    end
    cleanup_test_nodes(ids)
end

@testset "BUG-011 /right — locked votes are coinflip-gated, not guaranteed" begin
    Random.seed!(10)
    ids = ["locked_$i" for i in 1:80]
    for id in ids
        make_test_node(id, 5.0)
    end
    votes = [vote_for(id; conf=0.01, role=:primary) for id in ids]
    locked = Set(ids)

    result = apply_right_feedback!(votes, locked)

    @test result["total_contributors"] == length(ids)
    @test isempty(result["unsure_rewarded"])
    @test isempty(result["nonlocked_skipped"])
    @test length(result["rewarded"]) + length(result["coinflip_missed"]) == length(ids)
    @test 0 < length(result["rewarded"]) < length(ids)

    lock(NODE_LOCK) do
        for id in result["rewarded"]
            @test NODE_MAP[id].strength == 6.0
        end
        for id in result["coinflip_missed"]
            @test NODE_MAP[id].strength == 5.0
            @test !NODE_MAP[id].gained_this_cycle
        end
    end
    cleanup_test_nodes(ids)
end

@testset "BUG-011 /right — time nodes follow same lock-in rules" begin
    ids = ["time_locked", "time_unsure"]
    make_test_node("time_locked", 5.0; time_node=true)
    make_test_node("time_unsure", 5.0; time_node=true)

    votes = [vote_for("time_locked"; conf=0.1, role=:primary),
             vote_for("time_unsure"; conf=1.0, role=:support)]
    result = apply_right_feedback!(votes, Set(["time_locked"]))

    @test "time_unsure" in result["nonlocked_skipped"]
    @test !("time_unsure" in result["rewarded"])
    @test isempty(result["unsure_rewarded"])
    @test length(result["rewarded"]) + length(result["coinflip_missed"]) == 1

    lock(NODE_LOCK) do
        @test NODE_MAP["time_unsure"].strength == 5.0
    end
    cleanup_test_nodes(ids)
end

@testset "BUG-011 /right — grave locked nodes skipped" begin
    id = "grave_locked"
    n = make_test_node(id, 0.0)
    n.is_grave = true

    result = apply_right_feedback!([vote_for(id; conf=1.0, role=:primary)], Set([id]))

    @test isempty(result["rewarded"])
    @test result["grave_skipped"] == [id]
    cleanup_test_nodes([id])
end

@testset "BUG-011 /right — duplicate locked node processed once" begin
    id = "dup_locked"
    make_test_node(id, 5.0)
    votes = [vote_for(id; conf=0.9, role=:primary), vote_for(id; conf=0.7, role=:support)]

    result = apply_right_feedback!(votes, Set([id]))

    @test length(result["rewarded"]) + length(result["coinflip_missed"]) == 1
    cleanup_test_nodes([id])
end

@testset "BUG-011 /right — compatibility Vector{String} path has no lock-ins" begin
    id = "compat_nonlock"
    make_test_node(id, 5.0)

    result = apply_right_feedback!([id])

    @test haskey(result, "rewarded")
    @test haskey(result, "locked_rewarded")
    @test haskey(result, "unsure_rewarded")
    @test haskey(result, "skipped_double_reward")
    @test haskey(result, "coinflip_missed")
    @test haskey(result, "nonlocked_skipped")
    @test isempty(result["rewarded"])
    @test result["nonlocked_skipped"] == [id]

    lock(NODE_LOCK) do
        @test NODE_MAP[id].strength == 5.0
    end
    cleanup_test_nodes([id])
end

println("\n" * "="^60)
println("✅ BUG-011 LOCK-IN-ONLY /RIGHT FEEDBACK TESTS PASSED")
println("="^60)
