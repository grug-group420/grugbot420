# test_lobe_topicality_gate.jl
# ==============================================================================
# GRUG v7.18 — LOBE TOPICALITY GATE + SEMANTIC-BRIDGE EXCEPTION
# ==============================================================================
# Verifies the engine-level fix that mutes unrelated lobes and reinstates a
# muted node ONLY when a semantic bridge exists:
#   - relational-triple overlap with mission DYNAMIC triples
#   - required_relation verb shared with an eligible-lobe node
#   - /nodeAttach attachment to/from an eligible-lobe node
#
# Raw keyword overlap alone does NOT unmute.
#
# Test groups:
#   [A] _compute_lobe_topicality: eligible for matching subject, zero for disjoint
#   [B] Full gate: physics mission → cooking nodes muted (no bridge)
#   [C] Semantic bridge via shared required_relation verb reinstates a muted node
#   [D] Bridged node votes at ×BRIDGED_NODE_CONF_WEIGHT (half) weight
#   [E] /nodeAttach bridges muted node to eligible lobe
#   [F] Telemetry Refs populated/reset per call
#
# All failures scream loudly. No silent passes.
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
println("GRUG v7.18 LOBE TOPICALITY GATE TESTS")
println("="^60)

using GrugBot420
const G = GrugBot420

# ==============================================================================
# HELPERS — fresh lobe/node state for each group
# ==============================================================================

function _wipe_world!()
    # Lobes
    lock(G.Lobe.LOBE_LOCK) do
        empty!(G.Lobe.LOBE_REGISTRY)
        empty!(G.Lobe.NODE_TO_LOBE_IDX)
    end
    # Nodes
    lock(G.NODE_LOCK) do
        empty!(G.NODE_MAP)
    end
    # Attachments
    lock(G.ATTACHMENT_LOCK) do
        empty!(G.ATTACHMENT_MAP)
    end
    # Telemetry
    G._LAST_MUTED_LOBES[]   = String[]
    G._LAST_BRIDGED_NODES[] = Tuple{String,String,String}[]
end

# GRUG: Create a node via the real public path, then patch in overrides.
# Returns (node_id::String, node::Node).
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

# GRUG: Build a vote-pool tuple the gate expects.
function _poolentry(id::String, conf::Float64, node)
    return (id, conf, false, G.RelationalTriple[], node.relational_patterns)
end

# ==============================================================================
# TEST GROUPS
# ==============================================================================

@testset "v7.18 Lobe Topicality Gate" begin

    # --------------------------------------------------------------------------
    # [A] _compute_lobe_topicality sanity
    # --------------------------------------------------------------------------
    @testset "[A] _compute_lobe_topicality: match vs disjoint" begin
        _wipe_world!()

        mission_exp = G.Thesaurus.thesaurus_gate_filter("explain gravity and acceleration")

        topic_phys = G._compute_lobe_topicality("physics gravity motion", mission_exp)
        topic_cook = G._compute_lobe_topicality("cooking recipes cuisine", mission_exp)

        println("  [A] topic_phys=$(round(topic_phys, digits=3))  topic_cook=$(round(topic_cook, digits=3))")
        @test topic_phys > 0.0
        @test topic_phys > topic_cook
        @test G._compute_lobe_topicality("", mission_exp) == 0.0
    end

    # --------------------------------------------------------------------------
    # [B] physics mission mutes cooking lobe entirely
    # --------------------------------------------------------------------------
    @testset "[B] physics mission mutes cooking lobe (no bridge)" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity motion force")
        G.Lobe.create_lobe!("cooking_lobe", "cooking recipes food cuisine")

        phys_id, phys_node = _mknode("gravity pulls objects down"; action_packet="explain")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)

        # Cooking node with NO bridge: unique verb not used by physics, no attach.
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

        gated_ids = Set(e[1] for e in gated)
        println("  [B] gated ids = $(gated_ids)   muted = $(G._LAST_MUTED_LOBES[])")

        @test phys_id in gated_ids
        @test !(cook_id in gated_ids)  # muted + no bridge -> dropped
        @test "cooking_lobe" in G._LAST_MUTED_LOBES[]
        @test !("physics_lobe" in G._LAST_MUTED_LOBES[])
    end

    # --------------------------------------------------------------------------
    # [C] shared required_relation verb bridges a muted node
    # --------------------------------------------------------------------------
    @testset "[C] shared required_relation verb reinstates muted node" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity motion force")
        G.Lobe.create_lobe!("cooking_lobe", "cooking recipes food cuisine")

        phys_id, phys_node = _mknode("energy transforms matter";
            required_relations=["transforms"], action_packet="explain")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)

        # Cooking node shares the verb "transforms" — this is the bridge.
        cook_id, cook_node = _mknode("heat transforms dough";
            required_relations=["transforms"], action_packet="bake")
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        expanded = [
            _poolentry(phys_id, 0.9, phys_node),
            _poolentry(cook_id, 0.6, cook_node),
        ]

        gated = G.apply_lobe_topicality_gate!(
            "how does energy transforms matter in physics", expanded)

        gated_ids   = Set(e[1] for e in gated)
        bridged_ids = Set(b[1] for b in G._LAST_BRIDGED_NODES[])
        println("  [C] gated=$(gated_ids)  bridged=$(G._LAST_BRIDGED_NODES[])")

        @test cook_id in gated_ids
        @test cook_id in bridged_ids
        @test "cooking_lobe" in G._LAST_MUTED_LOBES[]
    end

    # --------------------------------------------------------------------------
    # [D] Bridged node's confidence is halved
    # --------------------------------------------------------------------------
    @testset "[D] bridged node confidence reduced to BRIDGED_NODE_CONF_WEIGHT" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity motion force")
        G.Lobe.create_lobe!("cooking_lobe", "cooking recipes food cuisine")

        phys_id, phys_node = _mknode("energy transforms matter";
            required_relations=["transforms"])
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)

        cook_id, cook_node = _mknode("heat transforms dough";
            required_relations=["transforms"])
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        original_cook_conf = 0.6
        expanded = [
            _poolentry(phys_id, 0.8, phys_node),
            _poolentry(cook_id, original_cook_conf, cook_node),
        ]

        gated = G.apply_lobe_topicality_gate!(
            "how does energy transforms matter in physics", expanded)

        cook_entry = nothing
        for e in gated
            if e[1] == cook_id
                cook_entry = e
                break
            end
        end

        @test !isnothing(cook_entry)
        if !isnothing(cook_entry)
            expected = original_cook_conf * G.BRIDGED_NODE_CONF_WEIGHT
            println("  [D] $(cook_id) conf: orig=$(original_cook_conf) gated=$(cook_entry[2]) expected=$(expected)")
            @test isapprox(cook_entry[2], expected; atol=1e-6)
        end
    end

    # --------------------------------------------------------------------------
    # [E] /nodeAttach bridges a muted node with no verb overlap
    # --------------------------------------------------------------------------
    @testset "[E] /nodeAttach bridges muted node to eligible lobe" begin
        _wipe_world!()

        G.Lobe.create_lobe!("physics_lobe", "physics gravity motion force")
        G.Lobe.create_lobe!("cooking_lobe", "cooking recipes food cuisine")

        phys_id, phys_node = _mknode("gravity pulls objects")
        G.Lobe.add_node_to_lobe!("physics_lobe", phys_id)

        # Cooking node — NO shared verb, NO shared triple. Only the attachment
        # connects it to the eligible physics lobe.
        cook_id, cook_node = _mknode("bake bread";
            required_relations=["kneads"])
        G.Lobe.add_node_to_lobe!("cooking_lobe", cook_id)

        G.attach_node!(phys_id, cook_id, "heat energy analogy")

        expanded = [
            _poolentry(phys_id, 0.9, phys_node),
            _poolentry(cook_id, 0.5, cook_node),
        ]

        gated = G.apply_lobe_topicality_gate!(
            "explain gravity and how objects fall", expanded)

        gated_ids  = Set(e[1] for e in gated)
        bridge_rsn = Dict(b[1] => b[3] for b in G._LAST_BRIDGED_NODES[])
        println("  [E] gated=$(gated_ids)  bridged=$(G._LAST_BRIDGED_NODES[])")

        @test cook_id in gated_ids
        @test haskey(bridge_rsn, cook_id)
        @test occursin("attach", bridge_rsn[cook_id])
    end

    # --------------------------------------------------------------------------
    # [F] Telemetry resets per-call (no accumulation across missions)
    # --------------------------------------------------------------------------
    @testset "[F] telemetry resets between missions" begin
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
        muted_after_1 = copy(G._LAST_MUTED_LOBES[])

        _ = G.apply_lobe_topicality_gate!("bake bread recipe",
            [_poolentry(cook_id, 0.8, cook_node),
             _poolentry(phys_id, 0.5, phys_node)])
        muted_after_2 = copy(G._LAST_MUTED_LOBES[])

        println("  [F] muted after physics mission = $muted_after_1")
        println("  [F] muted after cooking mission = $muted_after_2")

        @test "cooking_lobe" in muted_after_1
        @test !("physics_lobe" in muted_after_1)
        @test "physics_lobe" in muted_after_2
        @test !("cooking_lobe" in muted_after_2)
    end
end

println("\n" * "="^60)
println("ALL v7.18 LOBE TOPICALITY GATE TESTS PASSED!")
println("  [A] topicality score: match > disjoint")
println("  [B] unrelated lobe muted end-to-end (no bridge)")
println("  [C] shared required_relation verb bridges muted node")
println("  [D] bridged node confidence discounted by BRIDGED_NODE_CONF_WEIGHT")
println("  [E] /nodeAttach reinstates muted node with no verb overlap")
println("  [F] telemetry resets per-mission (no accumulation)")
println("="^60)