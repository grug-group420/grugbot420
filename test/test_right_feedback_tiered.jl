# test/test_right_feedback_tiered.jl
# ==============================================================================
# v7.23 — Tiered /right feedback: locked votes get guaranteed reward,
# unsure votes get confidence-biased coinflip. Both tiers skip if
# gained_this_cycle is already true (no double reward).
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("TIERED /RIGHT FEEDBACK TESTS")
println("="^60)

# GRUG: Include dependencies in correct order (same as test_relational_jitter.jl).
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

# Needed by engine.jl's full include chain — mirror engine.jl's upstream deps.
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

# Disable jitter for deterministic arithmetic assertions.
using .RelationalJitter
RelationalJitter.disable_jitter!()

# ==============================================================================
# HELPERS
# ==============================================================================

# Create a test node in NODE_MAP with given id and strength. Returns the node.
function make_test_node(id::String, strength::Float64 = 5.0)
    node = Node(
        id,                           # id
        "test_$(id)",                 # pattern
        Float64[1.0, 2.0, 3.0],      # signal
        "test_action|test_slot",      # action_packet
        Dict{String,Any}(),           # json_data
        String[],                     # drop_table
        1.0,                          # throttle
        RelationalTriple[],            # relational_patterns
        String[],                     # required_relations
        Dict{String,Float64}(),       # relation_weights
        strength,                     # strength
        false,                        # is_image_node
        String[],                     # neighbor_ids
        false,                        # is_unlinkable
        12,                           # max_neighbors
        false,                        # is_grave
        "",                           # grave_reason
        Float64[],                    # response_times
        time(),                       # ledger_last_cleared
        UInt64(0),                    # hopfield_key
        false,                        # fired_this_cycle
        false,                        # voted_this_cycle
        false,                        # gained_this_cycle
        0.0,                          # strength_delta_this_cycle
    )
    lock(NODE_LOCK) do
        NODE_MAP[id] = node
    end
    return node
end

# Clean up all test nodes from NODE_MAP.
function cleanup_test_nodes(ids)
    lock(NODE_LOCK) do
        for id in ids
            delete!(NODE_MAP, id)
        end
    end
end

# Reset cycle flags on all given node IDs.
function reset_cycle_flags(ids)
    lock(NODE_LOCK) do
        for id in ids
            node = get(NODE_MAP, id, nothing)
            !isnothing(node) || continue
            node.fired_this_cycle = false
            node.voted_this_cycle = false
            node.gained_this_cycle = false
            node.strength_delta_this_cycle = 0.0
        end
    end
end

# ==============================================================================
# TEST 1: Locked votes get guaranteed reward
# ==============================================================================
@testset "Tiered /right — locked votes guaranteed reward" begin
    ids = ["locked_a", "locked_b"]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("locked_a", "action_a", 0.85, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton),
             Vote("locked_b", "action_b", 0.78, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton)]
    locked = Set(["locked_a", "locked_b"])

    result = apply_right_feedback!(votes, locked)

    @test length(result["locked_rewarded"]) == 2
    @test length(result["unsure_rewarded"]) == 0
    @test length(result["coinflip_missed"]) == 0
    @test length(result["rewarded"]) == 2

    # Both nodes gained strength
    for id in ids
        node = lock(() -> NODE_MAP[id], NODE_LOCK)
        @test node.strength == 6.0
        @test node.gained_this_cycle == true
    end

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 2: Unsure votes — high confidence likely rewarded
# ==============================================================================
@testset "Tiered /right — unsure votes: high confidence likely rewarded" begin
    Random.seed!(42)

    n = 100
    ids = ["unsure_$i" for i in 1:n]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("unsure_$i", "action_$i", 0.95, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton)
             for i in 1:n]
    locked = Set{String}()

    result = apply_right_feedback!(votes, locked)

    @test length(result["locked_rewarded"]) == 0
    @test length(result["unsure_rewarded"]) >= 80
    @test length(result["coinflip_missed"]) <= 20

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 3: Unsure votes — low confidence rarely rewarded
# ==============================================================================
@testset "Tiered /right — unsure votes: low confidence rarely rewarded" begin
    Random.seed!(123)

    n = 100
    ids = ["low_$i" for i in 1:n]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("low_$i", "action_$i", 0.05, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton)
             for i in 1:n]
    locked = Set{String}()

    result = apply_right_feedback!(votes, locked)

    @test length(result["unsure_rewarded"]) <= 20
    @test length(result["coinflip_missed"]) >= 80

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 4: Mixed — locked guaranteed + unsure coinflip
# ==============================================================================
@testset "Tiered /right — mixed locked + unsure" begin
    Random.seed!(999)

    ids = ["lock_1", "lock_2", "unsure_1", "unsure_2"]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("lock_1",   "act_l1", 0.90, String[], RelationalTriple[], RelationalTriple[], false, "mp_1", :primary),
             Vote("lock_2",   "act_l2", 0.88, String[], RelationalTriple[], RelationalTriple[], false, "mp_2", :primary),
             Vote("unsure_1", "act_u1", 0.60, String[], RelationalTriple[], RelationalTriple[], false, "mp_1", :support),
             Vote("unsure_2", "act_u2", 0.30, String[], RelationalTriple[], RelationalTriple[], false, "mp_2", :support)]
    locked = Set(["lock_1", "lock_2"])

    result = apply_right_feedback!(votes, locked)

    @test "lock_1" in result["locked_rewarded"]
    @test "lock_2" in result["locked_rewarded"]
    @test length(result["locked_rewarded"]) == 2

    all_unsure = vcat(result["unsure_rewarded"], result["coinflip_missed"])
    @test "unsure_1" in all_unsure
    @test "unsure_2" in all_unsure

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 5: gained_this_cycle skips both tiers
# ==============================================================================
@testset "Tiered /right — gained_this_cycle skips even locked votes" begin
    ids = ["already_gained"]
    for id in ids
        n = make_test_node(id, 5.0)
        n.gained_this_cycle = true
    end

    votes = [Vote("already_gained", "act", 0.95, String[], RelationalTriple[], RelationalTriple[], false, "", :primary)]
    locked = Set(["already_gained"])

    result = apply_right_feedback!(votes, locked)

    @test length(result["rewarded"]) == 0
    @test length(result["skipped_double_reward"]) == 1
    @test "already_gained" in result["skipped_double_reward"]

    node = lock(() -> NODE_MAP["already_gained"], NODE_LOCK)
    @test node.strength == 5.0

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 6: Grave nodes skipped
# ==============================================================================
@testset "Tiered /right — grave nodes skipped even if locked" begin
    ids = ["grave_node"]
    n = make_test_node("grave_node", 0.0)
    n.is_grave = true

    votes = [Vote("grave_node", "act", 0.95, String[], RelationalTriple[], RelationalTriple[], false, "", :primary)]
    locked = Set(["grave_node"])

    result = apply_right_feedback!(votes, locked)

    @test length(result["rewarded"]) == 0
    @test length(result["grave_skipped"]) == 1

    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 7: Backward compat — old Vector{String} signature
# ==============================================================================
@testset "Tiered /right — backward compat: Vector{String} delegates" begin
    ids = ["compat_node"]
    make_test_node("compat_node", 5.0)

    result = apply_right_feedback!(["compat_node"])

    @test haskey(result, "rewarded")
    @test haskey(result, "locked_rewarded")
    @test haskey(result, "unsure_rewarded")
    @test haskey(result, "skipped_double_reward")
    @test haskey(result, "coinflip_missed")

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 8: Deduplication — same node in multiple votes
# ==============================================================================
@testset "Tiered /right — deduplication: same node only rewarded once" begin
    ids = ["dup_node"]
    make_test_node("dup_node", 5.0)

    votes = [Vote("dup_node", "act_a", 0.90, String[], RelationalTriple[], RelationalTriple[], false, "mp_1", :primary),
             Vote("dup_node", "act_b", 0.70, String[], RelationalTriple[], RelationalTriple[], false, "mp_2", :support)]
    locked = Set(["dup_node"])

    result = apply_right_feedback!(votes, locked)

    @test length(result["rewarded"]) == 1
    @test length(result["locked_rewarded"]) == 1

    node = lock(() -> NODE_MAP["dup_node"], NODE_LOCK)
    @test node.strength == 6.0

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 9: Confidence exactly 1.0 — always rewarded
# ==============================================================================
@testset "Tiered /right — confidence=1.0 always rewarded (unsure tier)" begin
    ids = ["perfect_$i" for i in 1:20]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("perfect_$i", "act", 1.0, String[], RelationalTriple[], RelationalTriple[], false, "", :support)
             for i in 1:20]
    locked = Set{String}()

    result = apply_right_feedback!(votes, locked)

    @test length(result["unsure_rewarded"]) == 20
    @test length(result["coinflip_missed"]) == 0

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 10: Confidence exactly 0.0 — never rewarded
# ==============================================================================
@testset "Tiered /right — confidence=0.0 never rewarded (unsure tier)" begin
    ids = ["zero_$i" for i in 1:20]
    for id in ids
        make_test_node(id, 5.0)
    end

    votes = [Vote("zero_$i", "act", 0.0, String[], RelationalTriple[], RelationalTriple[], false, "", :support)
             for i in 1:20]
    locked = Set{String}()

    result = apply_right_feedback!(votes, locked)

    @test length(result["unsure_rewarded"]) == 0
    @test length(result["coinflip_missed"]) == 20

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

# ==============================================================================
# TEST 11: Locked vote at confidence=0.1 still guaranteed
# ==============================================================================
@testset "Tiered /right — locked vote always rewarded regardless of confidence" begin
    ids = ["low_conf_locked"]
    make_test_node("low_conf_locked", 5.0)

    # Even though confidence is low (0.1), locked tier guarantees reward
    votes = [Vote("low_conf_locked", "act", 0.1, String[], RelationalTriple[], RelationalTriple[], false, "", :primary)]
    locked = Set(["low_conf_locked"])

    result = apply_right_feedback!(votes, locked)

    @test length(result["locked_rewarded"]) == 1
    @test length(result["unsure_rewarded"]) == 0

    node = lock(() -> NODE_MAP["low_conf_locked"], NODE_LOCK)
    @test node.strength == 6.0

    reset_cycle_flags(ids)
    cleanup_test_nodes(ids)
end

println("\n" * "="^60)
println("✅ ALL TIERED /RIGHT FEEDBACK TESTS PASSED")
println("="^60)
