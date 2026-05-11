# test_phagy_group_organizer.jl
# ==============================================================================
# GRUG v7.15 TESTS --- PhagyGroupOrganizer idle-time automaton
# ==============================================================================

using Test
using GrugBot420
using GrugBot420.GroupRegistry
using GrugBot420.PhagyGroupOrganizer

println("\n" * "=" ^ 60)
println("GRUG v7.15 PhagyGroupOrganizer TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] CLEAR UNLINKABLE ON GRAVE --- stale flag gets swept
# ==============================================================================
@testset "organizer clears stale is_unlinkable when grave present" begin
    reset_registry!()

    register_node_in_group!("g1", "n1")
    g = get_group("g1")
    # GRUG: Force an unlinkable flag with a grave present --- this is the
    # exact "stale state" the organizer is meant to fix.
    g.is_unlinkable = true
    grave_node_in_group!("g1", "n1")  # grave_count = 1

    stats = run_group_organizer!()
    @test stats.unlinkable_cleared == 1
    @test get_group("g1").is_unlinkable == false
end

# ==============================================================================
# [2] PRUNE EMPTY GROUPS --- no live, no grave -> delete
# ==============================================================================
@testset "organizer prunes empty groups" begin
    reset_registry!()

    register_node_in_group!("keep",  "alice")
    register_node_in_group!("empty", "bob")
    remove_node_from_group!("empty", "bob")   # leaves empty, no graves

    @test group_count() == 2

    stats = run_group_organizer!()
    @test stats.groups_pruned == 1
    @test group_count() == 1
    @test get_group("empty") === nothing
    @test get_group("keep")  !== nothing
end

# ==============================================================================
# [3] DO NOT PRUNE GROUP WITH GRAVES --- graves are memory, not bloat
# ==============================================================================
@testset "organizer preserves groups with grave members" begin
    reset_registry!()

    register_node_in_group!("memorial", "departed")
    grave_node_in_group!("memorial", "departed")
    # GRUG: Even with 0 live members, grave_count > 0 means keep it.

    stats = run_group_organizer!()
    @test stats.groups_pruned == 0
    @test get_group("memorial") !== nothing
    @test get_group("memorial").grave_count == 1
end

# ==============================================================================
# [4] AUTO SNAPSHOT --- writes a gz file and returns its path
# ==============================================================================
@testset "organizer auto snapshot" begin
    reset_registry!()
    register_node_in_group!("g1", "n1")
    register_node_in_group!("g2", "n2")

    tmpdir = mktempdir()
    snapfile = joinpath(tmpdir, "phagy_snap.json.gz")
    stats = run_group_organizer!(; auto_snapshot = true, snapshot_path = snapfile)

    @test !isempty(stats.snapshot_path)
    @test isfile(stats.snapshot_path)

    # GRUG: Snapshot round-trip smoke: wipe, reload, content matches.
    before = group_count()
    reset_registry!()
    @test group_count() == 0
    load_registry_compressed(stats.snapshot_path)
    @test group_count() == before
end

# ==============================================================================
# [5] IDEMPOTENT --- running twice in a row does nothing the second time
# ==============================================================================
@testset "organizer idempotent across consecutive runs" begin
    reset_registry!()
    register_node_in_group!("g1", "x")
    register_node_in_group!("g2", "y")
    remove_node_from_group!("g2", "y")

    s1 = run_group_organizer!()
    @test s1.groups_pruned == 1

    s2 = run_group_organizer!()
    @test s2.groups_pruned == 0
    @test s2.unlinkable_cleared == 0
end

println("\n" * "=" ^ 60)
println("\u2705  PhagyGroupOrganizer tests COMPLETE")
println("=" ^ 60)
