# test_lobe_topicality_gate.jl
# ==============================================================================
# GRUG v7.24 - LOBE TOPICALITY GATE IS A PASS-THROUGH (NO MUTING)
# ==============================================================================
# Verifies the v7.24 fix: apply_lobe_topicality_gate! is now a pass-through.
# No lobes are ever muted. LOBE_TOPICALITY_FLOOR = 0.0 (disabled).
# The correct design is LobeOrchestrator.jl: sequential lobe firing.
#
# Test groups:
#   [A] apply_lobe_topicality_gate! returns expanded unchanged
#   [B] _LAST_MUTED_LOBES is always empty after gate call
#   [C] _LAST_BRIDGED_NODES is always empty after gate call
#   [D] LOBE_TOPICALITY_FLOOR is 0.0
#   [E] _support_vote_is_coherent always returns true
#   [F] _compute_muted_lobes always returns empty muted set
#   [G] _scaffold_coherence_pass is a no-op
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG v7.24 LOBE TOPICALITY GATE PASS-THROUGH TESTS")
println("="^60)

using GrugBot420
const G = GrugBot420

# ==============================================================================
# HELPERS
# ==============================================================================

function _wipe_world!()
    lock(G.Lobe.LOBE_LOCK) do
        empty!(G.Lobe.LOBE_REGISTRY)
        empty!(G.Lobe.NODE_TO_LOBE_IDX)
    end
    lock(G.NODE_LOCK) do
        empty!(G.NODE_MAP)
    end
    lock(G.ATTACHMENT_LOCK) do
        empty!(G.ATTACHMENT_MAP)
    end
    G._LAST_MUTED_LOBES[]   = String[]
    G._LAST_BRIDGED_NODES[] = Tuple{String,String,String}[]
end

function _mknode(pattern::String;
                 relational_patterns::Vector{G.RelationalTriple} = G.RelationalTriple[],
                 required_relations::Vector{String} = String[],
                 action_packet::String = "think")
    data = Dict{String, Any}()
    node_id = G.create_node(pattern, action_packet, data, String[])
    node = lock(() -> G.NODE_MAP[node_id], G.NODE_LOCK)
    if !isempty(relational_patterns)
        node.relational_patterns = relational_patterns
    end
    if !isempty(required_relations)
        node.required_relations = required_relations
    end
    return (node_id, node)
end

function _poolentry(id::String, conf::Float64, node)
    return (id, conf, false, G.RelationalTriple[], node.relational_patterns)
end

# ==============================================================================
# TEST GROUPS
# ==============================================================================

@testset "v7.24 Lobe Topicality Gate (Pass-Through)" begin

    # --------------------------------------------------------------------------
    # [A] apply_lobe_topicality_gate! returns expanded unchanged
    # --------------------------------------------------------------------------
    @testset "[A] gate returns expanded unchanged" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity motion force")
        G.Lobe.create_lobe!("cooking_lobe", "cooking recipes food cuisine")

        phys_id, phys_node = _mknode("gravity pulls objects down"; action_packet="explain")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)

        cook_id, cook_node = _mknode("bake a cake";
            relational_patterns=[G.RelationalTriple("sugar", "sweetens", "cake")],
            required_relations=["sweetens"],
            action_packet="bake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        expanded = [
            _poolentry(phys_id, 0.9, phys_node),
            _poolentry(cook_id, 0.6, cook_node),
        ]

        mission = "explain how gravity pulls objects down"
        gated = G.apply_lobe_topicality_gate!(mission, expanded)

        # GRUG v7.24: Gate is pass-through. ALL nodes survive.
        gated_ids = Set(e[1] for e in gated)
        println("  [A] gated ids = $(gated_ids)")
        @test phys_id in gated_ids
        @test cook_id in gated_ids   # NOT muted - pass-through!
        @test length(gated) == length(expanded)
    end

    # --------------------------------------------------------------------------
    # [B] _LAST_MUTED_LOBES is always empty after gate call
    # --------------------------------------------------------------------------
    @testset "[B] _LAST_MUTED_LOBES always empty" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity")
        G.Lobe.create_lobe!("cooking_lobe", "cooking bake")

        phys_id, phys_node = _mknode("gravity pulls")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)
        cook_id, cook_node = _mknode("bake cake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        _ = G.apply_lobe_topicality_gate!("gravity problem",
            [_poolentry(phys_id, 0.8, phys_node),
             _poolentry(cook_id, 0.5, cook_node)])

        println("  [B] muted = $(G._LAST_MUTED_LOBES[])")
        @test isempty(G._LAST_MUTED_LOBES[])
    end

    # --------------------------------------------------------------------------
    # [C] _LAST_BRIDGED_NODES is always empty after gate call
    # --------------------------------------------------------------------------
    @testset "[C] _LAST_BRIDGED_NODES always empty" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity")
        G.Lobe.create_lobe!("cooking_lobe", "cooking bake")

        phys_id, phys_node = _mknode("gravity pulls")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)
        cook_id, cook_node = _mknode("bake cake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        _ = G.apply_lobe_topicality_gate!("gravity problem",
            [_poolentry(phys_id, 0.8, phys_node),
             _poolentry(cook_id, 0.5, cook_node)])

        println("  [C] bridged = $(G._LAST_BRIDGED_NODES[])")
        @test isempty(G._LAST_BRIDGED_NODES[])
    end

    # --------------------------------------------------------------------------
    # [D] LOBE_TOPICALITY_FLOOR is 0.0 (disabled)
    # --------------------------------------------------------------------------
    @testset "[D] LOBE_TOPICALITY_FLOOR is 0.0" begin
        @test G.LOBE_TOPICALITY_FLOOR == 0.0
    end

    # --------------------------------------------------------------------------
    # [E] _support_vote_is_coherent always returns true
    # --------------------------------------------------------------------------
    @testset "[E] _support_vote_is_coherent always true" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity")
        G.Lobe.create_lobe!("cooking_lobe", "cooking bake")

        phys_id, phys_node = _mknode("gravity pulls")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)
        cook_id, cook_node = _mknode("bake cake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        # Create mock votes for testing coherence
        support_vote = (node_id=cook_id, confidence=0.6, payload="")
        primary_vote = (node_id=phys_id, confidence=0.9, payload="")

        result = G._support_vote_is_coherent(support_vote, primary_vote, "physics question")
        println("  [E] _support_vote_is_coherent = $(result)")
        @test result == true
    end

    # --------------------------------------------------------------------------
    # [F] _compute_muted_lobes always returns empty muted set
    # --------------------------------------------------------------------------
    @testset "[F] _compute_muted_lobes returns empty muted set" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity")
        G.Lobe.create_lobe!("cooking_lobe", "cooking bake")

        phys_id, phys_node = _mknode("gravity pulls")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)
        cook_id, cook_node = _mknode("bake cake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        eligible, muted, eligible_node_ids, eligible_verbs =
            G._compute_muted_lobes("explain gravity")

        println("  [F] eligible=$(eligible) muted=$(muted)")
        @test isempty(muted)
        # All lobes should be eligible (no muting)
        @test "physics_lobe" in eligible
        @test "cooking_lobe" in eligible
    end

    # --------------------------------------------------------------------------
    # [G] _scaffold_coherence_pass is a no-op
    # --------------------------------------------------------------------------
    @testset "[G] _scaffold_coherence_pass returns input unchanged" begin
        result = G._scaffold_coherence_pass("hello world scaffold", "test mission")
        println("  [G] _scaffold_coherence_pass = '$(result)'")
        @test result == "hello world scaffold"
    end
end

println("\n" * "="^60)
println("ALL v7.24 LOBE TOPICALITY GATE PASS-THROUGH TESTS PASSED!")
println("  [A] gate returns expanded unchanged (no nodes dropped)")
println("  [B] _LAST_MUTED_LOBES always empty")
println("  [C] _LAST_BRIDGED_NODES always empty")
println("  [D] LOBE_TOPICALITY_FLOOR is 0.0 (disabled)")
println("  [E] _support_vote_is_coherent always true")
println("  [F] _compute_muted_lobes returns empty muted set")
println("  [G] _scaffold_coherence_pass returns input unchanged")
println("="^60)
