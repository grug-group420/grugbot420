# test_lobes.jl - GRUG Comprehensive Tests for Lobe.jl
# GRUG say: no tests = no trust. Every feature needs a rock thrown at it.
# GRUG say: test O(1) reverse index, capacity enforcement, lobe_grow!, and all error paths.

if !isdefined(Main, :Lobe)
    include("Lobe.jl")
end
using .Lobe
using Test

println("🧪 Running Lobe.jl tests...")

# ============================================================================
# HELPER - Fresh registry for each test group
# GRUG: Tests must not bleed state into each other. Each section cleans up.
# ============================================================================

function _clear_lobe_registry!()
    # GRUG: Direct clear for test isolation. Bypasses public API on purpose.
    lock(Lobe.LOBE_LOCK) do
        empty!(Lobe.LOBE_REGISTRY)
        empty!(Lobe.NODE_TO_LOBE_IDX)
    end
end

@testset "Lobe.jl - Full Test Suite" begin

    # ========================================================================
    # SECTION 1: create_lobe!
    # ========================================================================
    @testset "create_lobe! basics" begin
        _clear_lobe_registry!()

        rec = Lobe.create_lobe!("lang", "language")
        @test rec.id      == "lang"
        @test rec.subject == "language"
        @test rec.node_cap == Lobe.LOBE_NODE_CAP
        @test isempty(rec.node_ids)
        @test isempty(rec.connected_lobe_ids)
        @test rec.fire_count    == 0
        @test rec.inhibit_count == 0
        @test rec.created_at    >  0.0
    end

    @testset "create_lobe! custom cap" begin
        _clear_lobe_registry!()

        rec = Lobe.create_lobe!("small", "tiny cave"; node_cap=5)
        @test rec.node_cap == 5
    end

    @testset "create_lobe! duplicate id throws" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("dup", "test")

        @test_throws Lobe.LobeError Lobe.create_lobe!("dup", "test again")
    end

    @testset "create_lobe! empty id throws" begin
        _clear_lobe_registry!()
        @test_throws Lobe.LobeError Lobe.create_lobe!("", "subject")
    end

    @testset "create_lobe! empty subject throws" begin
        _clear_lobe_registry!()
        @test_throws Lobe.LobeError Lobe.create_lobe!("id1", "")
    end

    @testset "create_lobe! zero cap throws" begin
        _clear_lobe_registry!()
        @test_throws Lobe.LobeError Lobe.create_lobe!("id1", "subject"; node_cap=0)
    end

    @testset "create_lobe! MAX_LOBES enforcement" begin
        _clear_lobe_registry!()
        # GRUG: Fill up to MAX_LOBES
        for i in 1:Lobe.MAX_LOBES
            Lobe.create_lobe!("lobe_$i", "subject_$i")
        end
        @test length(Lobe.get_lobe_ids()) == Lobe.MAX_LOBES
        # GRUG: One more should throw
        @test_throws Lobe.LobeError Lobe.create_lobe!("overflow", "over")
    end

    # ========================================================================
    # SECTION 2: add_node_to_lobe! and reverse index
    # ========================================================================
    @testset "add_node_to_lobe! basic" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")

        Lobe.add_node_to_lobe!("L1", "node_1")
        @test Lobe.get_lobe_node_count("L1") == 1

        # GRUG: Reverse index must be populated
        found = Lobe.find_lobe_for_node("node_1")
        @test found == "L1"
    end

    @testset "add_node_to_lobe! multiple nodes" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")

        for i in 1:10
            Lobe.add_node_to_lobe!("L1", "node_$i")
        end
        @test Lobe.get_lobe_node_count("L1") == 10

        # GRUG: All 10 nodes in reverse index
        snap = Lobe.get_node_to_lobe_snapshot()
        for i in 1:10
            @test get(snap, "node_$i", nothing) == "L1"
        end
    end

    @testset "add_node_to_lobe! O(1) exclusive membership - cross lobe rejection" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("LA", "lobe a")
        Lobe.create_lobe!("LB", "lobe b")

        Lobe.add_node_to_lobe!("LA", "shared_node")
        # GRUG: Trying to add same node to different lobe must throw
        @test_throws Lobe.LobeError Lobe.add_node_to_lobe!("LB", "shared_node")
    end

    @testset "add_node_to_lobe! same lobe no-op (idempotent)" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")

        Lobe.add_node_to_lobe!("L1", "node_1")
        # GRUG: Adding same node to same lobe again is a no-op, not an error
        Lobe.add_node_to_lobe!("L1", "node_1")
        @test Lobe.get_lobe_node_count("L1") == 1
    end

    @testset "add_node_to_lobe! capacity exceeded throws" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("tiny", "small cave"; node_cap=3)

        Lobe.add_node_to_lobe!("tiny", "n1")
        Lobe.add_node_to_lobe!("tiny", "n2")
        Lobe.add_node_to_lobe!("tiny", "n3")
        @test Lobe.lobe_is_full("tiny")
        @test_throws Lobe.LobeError Lobe.add_node_to_lobe!("tiny", "n4")
    end

    @testset "add_node_to_lobe! empty args throw" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")
        @test_throws Lobe.LobeError Lobe.add_node_to_lobe!("", "node_1")
        @test_throws Lobe.LobeError Lobe.add_node_to_lobe!("L1", "")
    end

    @testset "add_node_to_lobe! nonexistent lobe throws" begin
        _clear_lobe_registry!()
        @test_throws Lobe.LobeError Lobe.add_node_to_lobe!("ghost", "node_1")
    end

    # ========================================================================
    # SECTION 3: remove_node_from_lobe! and reverse index sync
    # ========================================================================
    @testset "remove_node_from_lobe! basic" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")
        Lobe.add_node_to_lobe!("L1", "node_1")

        result = Lobe.remove_node_from_lobe!("L1", "node_1")
        @test result == true
        @test Lobe.get_lobe_node_count("L1") == 0

        # GRUG: Reverse index must be cleaned up!
        @test isnothing(Lobe.find_lobe_for_node("node_1"))
    end

    @testset "remove_node_from_lobe! nonexistent node returns false" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")

        result = Lobe.remove_node_from_lobe!("L1", "ghost_node")
        @test result == false
    end

    @testset "remove_node_from_lobe! then re-add to different lobe" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("LA", "lobe a")
        Lobe.create_lobe!("LB", "lobe b")

        Lobe.add_node_to_lobe!("LA", "migrant_node")
        Lobe.remove_node_from_lobe!("LA", "migrant_node")

        # GRUG: After removal, node can join a new lobe
        Lobe.add_node_to_lobe!("LB", "migrant_node")
        @test Lobe.find_lobe_for_node("migrant_node") == "LB"
        @test Lobe.get_lobe_node_count("LB") == 1
    end

    @testset "remove_node_from_lobe! empty args throw" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")
        @test_throws Lobe.LobeError Lobe.remove_node_from_lobe!("", "node_1")
        @test_throws Lobe.LobeError Lobe.remove_node_from_lobe!("L1", "")
    end

    # ========================================================================
    # SECTION 4: lobe_grow! (batch add with atomic capacity check)
    # ========================================================================
    @testset "lobe_grow! basic batch add" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test"; node_cap=100)

        added = Lobe.lobe_grow!("L1", ["na", "nb", "nc"])
        @test added == 3
        @test Lobe.get_lobe_node_count("L1") == 3

        # GRUG: All three in reverse index
        @test Lobe.find_lobe_for_node("na") == "L1"
        @test Lobe.find_lobe_for_node("nb") == "L1"
        @test Lobe.find_lobe_for_node("nc") == "L1"
    end

    @testset "lobe_grow! skips duplicates in batch" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")
        Lobe.add_node_to_lobe!("L1", "existing")

        # GRUG: Batch with existing node - should only add the new ones
        added = Lobe.lobe_grow!("L1", ["existing", "fresh1", "fresh2"])
        @test added == 2
        @test Lobe.get_lobe_node_count("L1") == 3
    end

    @testset "lobe_grow! throws if batch exceeds capacity" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("tiny", "small"; node_cap=2)

        @test_throws Lobe.LobeError Lobe.lobe_grow!("tiny", ["n1", "n2", "n3"])
        # GRUG: No partial adds! Cave stays empty after failed grow.
        @test Lobe.get_lobe_node_count("tiny") == 0
    end

    @testset "lobe_grow! throws if node already in different lobe" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("LA", "lobe a")
        Lobe.create_lobe!("LB", "lobe b")
        Lobe.add_node_to_lobe!("LA", "claimed_node")

        @test_throws Lobe.LobeError Lobe.lobe_grow!("LB", ["new_node", "claimed_node"])
    end

    @testset "lobe_grow! empty args throw" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("L1", "test")
        @test_throws Lobe.LobeError Lobe.lobe_grow!("", ["n1"])
        @test_throws Lobe.LobeError Lobe.lobe_grow!("L1", String[])
    end

    # ========================================================================
    # SECTION 5: find_lobe_for_node (O(1) reverse index)
    # ========================================================================
    @testset "find_lobe_for_node returns correct lobe" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("science", "science stuff")
        Lobe.create_lobe!("art", "art stuff")

        Lobe.add_node_to_lobe!("science", "quantum_node")
        Lobe.add_node_to_lobe!("art", "color_node")

        @test Lobe.find_lobe_for_node("quantum_node") == "science"
        @test Lobe.find_lobe_for_node("color_node")   == "art"
    end

    @testset "find_lobe_for_node returns nothing for unknown node" begin
        _clear_lobe_registry!()
        @test isnothing(Lobe.find_lobe_for_node("unknown"))
    end

    @testset "find_lobe_for_node empty throws" begin
        _clear_lobe_registry!()
        @test_throws Lobe.LobeError Lobe.find_lobe_for_node("")
    end

    # ========================================================================
    # SECTION 6: connect_lobes! / disconnect_lobes!
    # ========================================================================
    @testset "connect_lobes! bidirectional" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("A", "alpha")
        Lobe.create_lobe!("B", "beta")

        Lobe.connect_lobes!("A", "B")
        recA = Lobe.get_lobe("A")
        recB = Lobe.get_lobe("B")
        @test "B" in recA.connected_lobe_ids
        @test "A" in recB.connected_lobe_ids
    end

    @testset "connect_lobes! self-connection throws" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("solo", "alone")
        @test_throws Lobe.LobeError Lobe.connect_lobes!("solo", "solo")
    end

    @testset "disconnect_lobes! removes both directions" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("A", "alpha")
        Lobe.create_lobe!("B", "beta")
        Lobe.connect_lobes!("A", "B")
        Lobe.disconnect_lobes!("A", "B")

        recA = Lobe.get_lobe("A")
        recB = Lobe.get_lobe("B")
        @test !("B" in recA.connected_lobe_ids)
        @test !("A" in recB.connected_lobe_ids)
    end

    # ========================================================================
    # SECTION 7: lobe_is_full
    # ========================================================================
    @testset "lobe_is_full transitions correctly" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("cap2", "test"; node_cap=2)
        @test !Lobe.lobe_is_full("cap2")

        Lobe.add_node_to_lobe!("cap2", "n1")
        @test !Lobe.lobe_is_full("cap2")

        Lobe.add_node_to_lobe!("cap2", "n2")
        @test Lobe.lobe_is_full("cap2")
    end

    # ========================================================================
    # SECTION 8: get_lobe_status_summary
    # ========================================================================
    @testset "get_lobe_status_summary includes reverse index count" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("X", "xray")
        Lobe.add_node_to_lobe!("X", "n1")
        Lobe.add_node_to_lobe!("X", "n2")

        summary = Lobe.get_lobe_status_summary()
        @test occursin("LOBE REGISTRY", summary)
        @test occursin("2 nodes indexed", summary)
        @test occursin("xray", summary)
    end

    @testset "get_lobe_status_summary empty registry" begin
        _clear_lobe_registry!()
        summary = Lobe.get_lobe_status_summary()
        @test occursin("EMPTY", summary)
    end

    # ========================================================================
    # SECTION 9: reverse index stays consistent under load
    # ========================================================================
    @testset "reverse index consistent after mixed add/remove" begin
        _clear_lobe_registry!()
        Lobe.create_lobe!("big", "big lobe"; node_cap=1000)

        # GRUG: Add 50 nodes
        for i in 1:50
            Lobe.add_node_to_lobe!("big", "node_$i")
        end
        @test Lobe.get_lobe_node_count("big") == 50

        # GRUG: Remove every other one
        for i in 1:2:50
            Lobe.remove_node_from_lobe!("big", "node_$i")
        end
        @test Lobe.get_lobe_node_count("big") == 25

        # GRUG: Verify reverse index matches
        snap = Lobe.get_node_to_lobe_snapshot()
        for i in 1:50
            if i % 2 == 0
                @test get(snap, "node_$i", nothing) == "big"
            else
                @test isnothing(get(snap, "node_$i", nothing))
            end
        end
    end

    # ========================================================================
    # CLEANUP
    # ========================================================================
    _clear_lobe_registry!()

end # @testset

println("✅ Lobe.jl tests complete.")