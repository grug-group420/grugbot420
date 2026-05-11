# test_group_registry.jl
# ==============================================================================
# GRUG v7.15 TESTS --- GroupRegistry: 8-16 partner cap, grave re-opening,
#                       chatter windowing, compressed JSON round-trip
# ==============================================================================

using Test
using Random

include("../src/GroupRegistry.jl")
using .GroupRegistry

println("\n" * "=" ^ 60)
println("GRUG v7.15 GroupRegistry TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] REGISTER --- partner cap picked in [8, 16] range
# ==============================================================================
@testset "assign_partner_cap: within [PARTNER_CAP_MIN, PARTNER_CAP_MAX]" begin
    rng = MersenneTwister(42)
    for _ in 1:200
        c = assign_partner_cap(; rng = rng)
        @test PARTNER_CAP_MIN <= c <= PARTNER_CAP_MAX
    end
end

# ==============================================================================
# [2] REGISTER --- creates group on first call, idempotent membership
# ==============================================================================
@testset "register_node_in_group!: basic add + duplicate reject" begin
    reset_registry!()

    g = register_node_in_group!("grp_1", "node_a")
    @test g.group_id == "grp_1"
    @test "node_a" in g.member_ids
    @test PARTNER_CAP_MIN <= g.partner_cap <= PARTNER_CAP_MAX

    # GRUG: Adding same node twice must throw (silent idempotency would hide
    # a bug in the caller).
    @test_throws GroupRegistryError register_node_in_group!("grp_1", "node_a")
end

# ==============================================================================
# [3] UNLINKABLE --- cap flip + grave re-opens slot
# ==============================================================================
@testset "register_node_in_group!: cap reached -> UNLINKABLE -> grave frees" begin
    reset_registry!()

    # GRUG: Force a tiny cap by passing a seeded RNG --- actually caps are
    # random in [8,16]. We just fill one group to its own cap and confirm flip.
    g = register_node_in_group!("grp_small", "seed_node")
    cap = g.partner_cap

    for i in 1:(cap - 1)
        register_node_in_group!("grp_small", "node_$(i)")
    end

    @test length(g.member_ids) == cap
    @test is_unlinkable(g) == true

    # GRUG: New add must throw (group at cap, no graves).
    @test_throws GroupRegistryError register_node_in_group!("grp_small", "overflow_node")

    # GRUG: Grave one member -> cap relaxes.
    grave_node_in_group!("grp_small", "seed_node")
    @test g.grave_count == 1
    @test is_unlinkable(g) == false

    # GRUG: Now a new add must succeed.
    register_node_in_group!("grp_small", "replacement_node")
    @test "replacement_node" in g.member_ids
end

# ==============================================================================
# [4] MULTIPLE GROUPS --- partner union, node-to-groups index
# ==============================================================================
@testset "partners_for_node: union across groups" begin
    reset_registry!()
    register_node_in_group!("g1", "alice")
    register_node_in_group!("g1", "bob")
    register_node_in_group!("g2", "alice")
    register_node_in_group!("g2", "carol")

    partners = partners_for_node("alice")
    @test sort(partners) == sort(["bob", "carol"])
    @test sort(partners_for_node("bob")) == ["alice"]
end

# ==============================================================================
# [5] CHATTER WINDOW --- cursor walks FIFO + wraps
# ==============================================================================
@testset "chatter window: FIFO + cursor wrap" begin
    reset_registry!()
    for i in 1:10
        register_node_in_group!("grp_$i", "node_$i")
    end

    ids = next_chatter_window_ids(; window_size = 3)
    @test ids == ["grp_1", "grp_2", "grp_3"]

    advance_chatter_cursor!(3)
    ids2 = next_chatter_window_ids(; window_size = 3)
    @test ids2 == ["grp_4", "grp_5", "grp_6"]

    # GRUG: Wrap around the end.
    advance_chatter_cursor!(7)  # now at position mod1(4+7, 10) = mod1(11,10) = 1
    ids3 = next_chatter_window_ids(; window_size = 3)
    @test ids3 == ["grp_1", "grp_2", "grp_3"]
end

# ==============================================================================
# [6] CHATTER WINDOW --- empty registry returns empty list (not crash)
# ==============================================================================
@testset "chatter window: empty registry" begin
    reset_registry!()
    ids = next_chatter_window_ids(; window_size = 5)
    @test isempty(ids)
end

# ==============================================================================
# [7] CHATTER WINDOW --- size > group count returns each id once
# ==============================================================================
@testset "chatter window: window_size > group count" begin
    reset_registry!()
    for i in 1:3
        register_node_in_group!("g_$i", "n_$i")
    end
    ids = next_chatter_window_ids(; window_size = 100)
    @test length(ids) == 3
end

# ==============================================================================
# [7b] CHATTER WINDOW --- tail-remainder: at end of lobe list, return ONLY
#      what's left; next cycle (after advance) picks fresh from the front.
#      SPEC (user v7.15.1): "if it doesnt have enough slots to use just use
#      the remaining ids in the lobe list."
# ==============================================================================
@testset "chatter window: tail-remainder (no mid-window wrap)" begin
    reset_registry!()
    # GRUG: 10 groups total, we'll exercise a window that bumps into the tail.
    for i in 1:10
        register_node_in_group!("tail_grp_$i", "tail_node_$i")
    end

    # Jump cursor to position 8 (so only 3 slots remain to end: 8,9,10).
    advance_chatter_cursor!(7)  # mod1(1+7,10) = 8

    # Ask for a window of 5 --- only 3 are left. EXPECT: tail-remainder of 3,
    # NOT 3-at-tail + 2-wrapped-from-front.
    ids_tail = next_chatter_window_ids(; window_size = 5)
    @test ids_tail == ["tail_grp_8", "tail_grp_9", "tail_grp_10"]
    @test length(ids_tail) == 3

    # Advance by the count actually returned --- cursor wraps to 1.
    advance_chatter_cursor!(length(ids_tail))    # mod1(8+3,10) = 1

    # Next window starts fresh from the front with full requested size.
    ids_fresh = next_chatter_window_ids(; window_size = 5)
    @test ids_fresh == ["tail_grp_1", "tail_grp_2", "tail_grp_3",
                        "tail_grp_4", "tail_grp_5"]
end

# ==============================================================================
# [7c] CHATTER WINDOW --- tail-remainder edge: cursor at exact last slot
# ==============================================================================
@testset "chatter window: cursor at exact last slot returns singleton" begin
    reset_registry!()
    for i in 1:4
        register_node_in_group!("edge_grp_$i", "edge_node_$i")
    end

    # Move cursor to position 4 (the final slot).
    advance_chatter_cursor!(3)   # mod1(1+3,4) = 4

    ids = next_chatter_window_ids(; window_size = 10)
    @test ids == ["edge_grp_4"]
    @test length(ids) == 1

    # Advance by 1 --- wraps to 1.
    advance_chatter_cursor!(1)   # mod1(4+1,4) = 1
    ids2 = next_chatter_window_ids(; window_size = 2)
    @test ids2 == ["edge_grp_1", "edge_grp_2"]
end

# ==============================================================================
# [8] DISK ROUND-TRIP --- compressed JSON preserves all state
# ==============================================================================
@testset "disk round-trip: save + load compressed" begin
    reset_registry!()
    for i in 1:5
        register_node_in_group!("disk_grp_$i", "node_$i")
        register_node_in_group!("disk_grp_$i", "node_$(i+100)")
    end
    advance_chatter_cursor!(2)
    grave_node_in_group!("disk_grp_3", "node_3")

    before_snap = Dict(
        "count"    => group_count(),
        "order"    => list_group_ids(),
        "partners" => partners_for_node("node_1"),
        "graves"   => get_group("disk_grp_3").grave_count,
    )

    tmpdir = mktempdir()
    path = joinpath(tmpdir, "snapshot.json.gz")
    written = save_registry_compressed(path)
    @test isfile(written)

    # GRUG: Wipe in-memory state.
    reset_registry!()
    @test group_count() == 0

    # GRUG: Reload from disk.
    load_registry_compressed(written)

    @test group_count()                    == before_snap["count"]
    @test list_group_ids()                 == before_snap["order"]
    @test sort(partners_for_node("node_1")) == sort(before_snap["partners"])
    @test get_group("disk_grp_3").grave_count == before_snap["graves"]
end

# ==============================================================================
# [9] DISK --- missing file + bad JSON throw loudly
# ==============================================================================
@testset "disk: missing file + bad json reject" begin
    @test_throws GroupRegistryError load_registry_compressed("/nonexistent/path.json.gz")

    tmpdir = mktempdir()
    badpath = joinpath(tmpdir, "bad.json")
    write(badpath, "this is not json {{{")
    @test_throws GroupRegistryError load_registry_compressed(badpath)
end

# ==============================================================================
# [10] ERROR PATHS --- empty ids, unknown groups, over-step cursor
# ==============================================================================
@testset "error paths: empty inputs + unknown groups" begin
    reset_registry!()
    @test_throws GroupRegistryError register_node_in_group!("", "n1")
    @test_throws GroupRegistryError register_node_in_group!("g", "")
    @test_throws GroupRegistryError remove_node_from_group!("unknown_grp", "x")
    @test_throws GroupRegistryError grave_node_in_group!("unknown_grp", "x")
    @test_throws GroupRegistryError next_chatter_window_ids(; window_size = 0)
    @test_throws GroupRegistryError advance_chatter_cursor!(-1)
end

println("\n" * "=" ^ 60)
println("\u2705  GroupRegistry tests COMPLETE")
println("=" ^ 60)
