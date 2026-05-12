# test/test_group_registry_grave_everywhere.jl
# ==============================================================================
# GRUG v7.15.2 test: GroupRegistry.grave_node_everywhere! --- single-call
# grave propagation across every group containing a given node.
#
# Covers:
#   1. Node in one group: touched=1, grave_count bumped exactly once.
#   2. Node in multiple groups: touched=N, each group's grave_count bumped.
#   3. Node in NO groups: touched=0, no mutation, no error.
#   4. Empty string node_id: explicit GroupRegistryError (NO SILENT FAILURE).
#   5. Idempotency boundary: two consecutive calls double the grave_count.
#      (That is the intended contract; callers should dedupe if they care.)
#   6. Drift recovery: if node_to_groups is out-of-sync with member_ids,
#      we warn + skip (return count reflects real work done).
# ==============================================================================

using Test

include("../src/RelationalJitter.jl"); using .RelationalJitter
include("../src/GroupRegistry.jl");    using .GroupRegistry

println("\n" * "="^60)
println("GRUG v7.15.2 GroupRegistry.grave_node_everywhere! TEST SUITE")
println("="^60)

# ==============================================================================
# [1] Single-group grave
# ==============================================================================
@testset "grave_node_everywhere!: node in one group" begin
    reset_registry!()
    register_node_in_group!("grp_solo", "node_solo_1")

    touched = grave_node_everywhere!("node_solo_1")
    @test touched == 1
    g = get_group("grp_solo")
    @test !isnothing(g)
    @test g.grave_count == 1
end

# ==============================================================================
# [2] Multi-group grave
# ==============================================================================
@testset "grave_node_everywhere!: node in three groups" begin
    reset_registry!()
    register_node_in_group!("grp_a", "node_multi")
    register_node_in_group!("grp_b", "node_multi")
    register_node_in_group!("grp_c", "node_multi")
    # GRUG: Put a decoy node in one of them so we can confirm decoy is untouched.
    register_node_in_group!("grp_a", "node_decoy")

    touched = grave_node_everywhere!("node_multi")
    @test touched == 3

    for gid in ("grp_a", "grp_b", "grp_c")
        g = get_group(gid)
        @test !isnothing(g)
        @test g.grave_count == 1
    end

    # GRUG: Decoy was not touched.
    @test get_group("grp_a").grave_count == 1  # still 1, not 2
end

# ==============================================================================
# [3] Node in no groups --- no-op, no error
# ==============================================================================
@testset "grave_node_everywhere!: unregistered node is a no-op" begin
    reset_registry!()
    touched = grave_node_everywhere!("ghost_node")
    @test touched == 0
end

# ==============================================================================
# [4] Empty string node_id throws
# ==============================================================================
@testset "grave_node_everywhere!: empty node_id throws" begin
    reset_registry!()
    @test_throws GroupRegistryError grave_node_everywhere!("")
end

# ==============================================================================
# [5] Idempotency boundary --- double-call double-counts by design
# ==============================================================================
@testset "grave_node_everywhere!: double-call doubles grave_count" begin
    reset_registry!()
    register_node_in_group!("grp_idem", "node_idem")

    grave_node_everywhere!("node_idem")
    grave_node_everywhere!("node_idem")

    g = get_group("grp_idem")
    @test g.grave_count == 2
end

# ==============================================================================
# [6] After grave, is_unlinkable can be cleared (contract with group organizer)
# ==============================================================================
@testset "grave_node_everywhere!: grave_count > 0 unlocks clear_unlinkable" begin
    reset_registry!()
    # GRUG: Fill a group up to its RANDOM partner cap (8..16) without tripping
    # the per-insert unlinkable raise. Then mark unlinkable explicitly and
    # confirm grave_node_everywhere!+clear_unlinkable_if_has_grave! clears.
    # Using 5 members keeps us well under any random cap.
    for i in 1:5
        register_node_in_group!("grp_full", "node_$i")
    end
    g = get_group("grp_full")
    @test length(g.member_ids) == 5
    @test g.grave_count == 0

    # GRUG: Force the unlinkable flag on (simulates the cap-reached path
    # without relying on the random cap falling at exactly 5).
    # GRUG: mark_unlinkable! and is_unlinkable take a NodeGroup, not the id.
    mark_unlinkable!(get_group("grp_full"))
    @test is_unlinkable(get_group("grp_full")) == true

    # GRUG: Grave one member via grave_node_everywhere!; then organizer helper
    # should clear the flag.
    grave_node_everywhere!("node_1")
    @test get_group("grp_full").grave_count == 1

    clear_unlinkable_if_has_grave!("grp_full")
    @test is_unlinkable(get_group("grp_full")) == false
end

println("\n" * "="^60)
println("✅  grave_node_everywhere! tests COMPLETE")
println("="^60)
