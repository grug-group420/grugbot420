# test_mlp_autolinker_signals.jl - GRUG v10 Deep MLP → AutoLinker Evidence Signal Flow Tests
# GRUG say: MLP knobs must change link evidence. Disambiguation bridges ambiguous pairs.
# GRUG say: Low relevance reveals cross-lobe gaps. High novelty amplifies co-fire.
# GRUG say: Chatter residuals feed underground co-occurrence. Test all sources.

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

module _MLPAutoLinkerTestParent
    include(joinpath(@__DIR__, "..", "src", "AutoLinker.jl"))
end

using ._MLPAutoLinkerTestParent.AutoLinker

println("🧪 Running EphemeralMLP → AutoLinker evidence signal flow tests...")

# =========================================================================
# HELPERS
# =========================================================================

"""Full reset of link evidence."""
function _reset!()
    AutoLinker.reset_link_evidence!()
end

"""Run accumulate_link_evidence! with specified knobs, return snapshot."""
#function _run( # DoD REMEDIATION;
    co_fired_ids::Vector{String} = String[],
    lobe_of_fn::Function = id -> nothing,
    mlp_disambiguation::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    mlp_novelty_score::Float64 = 0.5,
    node_ids_patterns::Vector{Tuple{String,String}} = Tuple{String,String}[],
    chatter_co_occur_pairs::Vector{Tuple{String,String,Float64}} = Tuple{String,String,Float64}[],
    strain_nodes::Vector{String} = String[],
    input_touched_ids::Vector{String} = String[],
)
    _reset!()
    AutoLinker.accumulate_link_evidence!(;
        co_fired_ids = co_fired_ids,
        lobe_of_fn = lobe_of_fn,
        mlp_disambiguation = mlp_disambiguation,
        mlp_relevance_score = mlp_relevance_score,
        mlp_novelty_score = mlp_novelty_score,
        node_ids_patterns = node_ids_patterns,
        chatter_co_occur_pairs = chatter_co_occur_pairs,
        strain_nodes = strain_nodes,
        input_touched_ids = input_touched_ids,
    )
    return AutoLinker.get_link_evidence_snapshot()
end

"""Find link evidence for a pair, return its Dict or nothing."""
function _find_pair(snap::Dict{String,Any}, id_a::String, id_b::String)
    key = id_a < id_b ? "$(id_a)::$(id_b)" : "$(id_b)::$(id_a)"
    return get(snap, key, nothing)
end

# Lobe assignment helpers
_lobe_cross = id -> id == "n1" ? "lobe_a" : (id == "n2" ? "lobe_b" : nothing)
_lobe_same  = id -> "lobe_a"

@testset "MLP → AutoLinker Evidence Signal Flow" begin

    # =====================================================================
    # BASELINE: Co-fire only, no MLP boosts, no lobe info
    # =====================================================================
    @testset "Baseline — Co-fire, no MLP boosts" begin
#        snap = _run( # DoD REMEDIATIONco_fired_ids = ["n1", "n2"])
        @test length(snap) == 1
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test rec["accumulated_intensity"] ≈ 1.0 atol=0.001  # CO_FIRE_INCREMENT
        @test "co_firing" in rec["sources"]
    end

    # =====================================================================
    # SOURCE 4: CROSS-LOBE CO-ACTIVATION
    # =====================================================================
    @testset "SOURCE 4 — Cross-Lobe Co-Activation" begin
#        snap = _run( # DoD REMEDIATIONco_fired_ids = ["n1", "n2"], lobe_of_fn = _lobe_cross)
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test "opposing_lobe_co_act" in rec["sources"]
        @test rec["is_cross_lobe"] == true
        # CO_FIRE_INCREMENT (1.0) + CROSS_LOBE_CO_ACT_INCREMENT (3.0) = 4.0
        @test rec["accumulated_intensity"] ≈ 4.0 atol=0.001

        # Same-lobe pair: no opposing_lobe_co_act
#        snap2 = _run( # DoD REMEDIATIONco_fired_ids = ["n1", "n2"], lobe_of_fn = _lobe_same)
        rec2 = _find_pair(snap2, "n1", "n2")
        @test rec2 !== nothing
        @test "opposing_lobe_co_act" ∉ rec2["sources"]
        @test rec2["is_cross_lobe"] == false
        @test rec2["accumulated_intensity"] ≈ 1.0 atol=0.001
    end

    # =====================================================================
    # SOURCE 9: DISAMBIGUATION BRIDGE (MLP head 4)
    # =====================================================================
    @testset "SOURCE 9 — Disambiguation Bridge" begin
        # High disambiguation (0.8) with cross-lobe pair
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.8,
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test "disambiguation_bridge" in rec["sources"]
        # disambiguation_bridge = 0.4 * 0.8 * 1.5 (cross) = 0.48
        # total = 1.0 (co_fire) + 3.0 (cross_lobe_co_act) + 0.48 = 4.48
        @test rec["accumulated_intensity"] ≈ 4.48 atol=0.001

        # High disambiguation (0.8) with SAME-lobe pair
#        snap2 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_same,
            mlp_disambiguation = 0.8,
        )
        rec2 = _find_pair(snap2, "n1", "n2")
        @test rec2 !== nothing
        @test "disambiguation_bridge" in rec2["sources"]
        # disambiguation_bridge = 0.4 * 0.8 * 1.0 (no cross bonus) = 0.32
        # total = 1.0 + 0.32 = 1.32
        @test rec2["accumulated_intensity"] ≈ 1.32 atol=0.001

        # Below threshold (0.5 < 0.6) — no disambiguation bridge
#        snap3 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.5,
        )
        rec3 = _find_pair(snap3, "n1", "n2")
        @test rec3 !== nothing
        @test "disambiguation_bridge" ∉ rec3["sources"]

        # At threshold (0.6) — strict >, no bridge
#        snap4 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.6,
        )
        rec4 = _find_pair(snap4, "n1", "n2")
        @test rec4 !== nothing
        @test "disambiguation_bridge" ∉ rec4["sources"]

        # Just above threshold (0.61)
#        snap5 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.61,
        )
        rec5 = _find_pair(snap5, "n1", "n2")
        @test rec5 !== nothing
        @test "disambiguation_bridge" in rec5["sources"]
    end

    # =====================================================================
    # SOURCE 10: RELEVANCE CROSS-LOBE (MLP head 3)
    # =====================================================================
    @testset "SOURCE 10 — Relevance Cross-Lobe" begin
        # Low relevance (0.3) with cross-lobe pair
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_relevance_score = 0.3,
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test "relevance_cross_lobe" in rec["sources"]
        # gap_magnitude = 1.0 - 0.3 = 0.7
        # increment = 0.5 * 0.7 = 0.35
        # total = 1.0 + 3.0 + 0.35 = 4.35
        @test rec["accumulated_intensity"] ≈ 4.35 atol=0.001

        # Low relevance with SAME-lobe pair — NO relevance_cross_lobe
#        snap2 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_same,
            mlp_relevance_score = 0.3,
        )
        rec2 = _find_pair(snap2, "n1", "n2")
        @test rec2 !== nothing
        @test "relevance_cross_lobe" ∉ rec2["sources"]

        # Above threshold (0.5) — no relevance cross-lobe
#        snap3 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_relevance_score = 0.5,
        )
        rec3 = _find_pair(snap3, "n1", "n2")
        @test rec3 !== nothing
        @test "relevance_cross_lobe" ∉ rec3["sources"]

        # At threshold (0.45) — strict <, no relevance
#        snap4 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_relevance_score = 0.45,
        )
        rec4 = _find_pair(snap4, "n1", "n2")
        @test rec4 !== nothing
        @test "relevance_cross_lobe" ∉ rec4["sources"]

        # Just below threshold (0.44)
#        snap5 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_relevance_score = 0.44,
        )
        rec5 = _find_pair(snap5, "n1", "n2")
        @test rec5 !== nothing
        @test "relevance_cross_lobe" in rec5["sources"]
    end

    # =====================================================================
    # SOURCE 12: NOVELTY-AMPLIFIED CO-FIRING (MLP novelty_score)
    # =====================================================================
    @testset "SOURCE 12 — Novelty-Amplified Co-Fire" begin
        # High novelty (0.8) with cross-lobe pair
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.8,
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test "novelty_co_fire" in rec["sources"]
        # novelty_mult = 1 + 0.4 * (0.8 - 0.6) / 0.4 = 1.2
        # cross_bonus = 1.5
        # increment = 1.0 * (1.2 - 1.0) * 1.5 = 0.3
        # total = 1.0 + 3.0 + 0.3 = 4.3
        @test rec["accumulated_intensity"] ≈ 4.3 atol=0.001

        # High novelty with SAME-lobe pair
#        snap2 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_same,
            mlp_novelty_score = 0.8,
        )
        rec2 = _find_pair(snap2, "n1", "n2")
        @test rec2 !== nothing
        @test "novelty_co_fire" in rec2["sources"]
        # no cross bonus: 1.0 * 0.2 * 1.0 = 0.2
        # total = 1.0 + 0.2 = 1.2
        @test rec2["accumulated_intensity"] ≈ 1.2 atol=0.001

        # Below threshold (0.5) — no novelty co-fire
#        snap3 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.5,
        )
        rec3 = _find_pair(snap3, "n1", "n2")
        @test rec3 !== nothing
        @test "novelty_co_fire" ∉ rec3["sources"]

        # At threshold (0.6) — strict >, no novelty co-fire
#        snap4 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.6,
        )
        rec4 = _find_pair(snap4, "n1", "n2")
        @test rec4 !== nothing
        @test "novelty_co_fire" ∉ rec4["sources"]

        # Just above threshold (0.61)
#        snap5 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.61,
        )
        rec5 = _find_pair(snap5, "n1", "n2")
        @test rec5 !== nothing
        @test "novelty_co_fire" in rec5["sources"]

        # Maximum novelty (1.0)
        # novelty_mult = 1 + 0.4 * (1.0 - 0.6) / 0.4 = 1.4
        # increment = 1.0 * 0.4 * 1.5 = 0.6 (cross-lobe)
        # total = 1.0 + 3.0 + 0.6 = 4.6
#        snap6 = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 1.0,
        )
        rec6 = _find_pair(snap6, "n1", "n2")
        @test rec6 !== nothing
        @test rec6["accumulated_intensity"] ≈ 4.6 atol=0.001
    end

    # =====================================================================
    # SOURCE 11: CHATTER RESIDUAL CO-OCCURRENCE
    # =====================================================================
    @testset "SOURCE 11 — Chatter Residual Co-Occurrence" begin
#        snap = _run( # DoD REMEDIATION
            node_ids_patterns = [("n1", "gravity"), ("n2", "quantum")],
            lobe_of_fn = _lobe_cross,
            chatter_co_occur_pairs = [("gravity", "quantum", 0.5)],
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        @test "chatter_residual" in rec["sources"]
        # 0.6 * 0.5 * 0.5 = 0.15
        @test rec["accumulated_intensity"] ≈ 0.15 atol=0.001

        # Below minimum intensity (< 0.1)
#        snap2 = _run( # DoD REMEDIATION
            node_ids_patterns = [("n1", "gravity"), ("n2", "quantum")],
            lobe_of_fn = _lobe_cross,
            chatter_co_occur_pairs = [("gravity", "quantum", 0.05)],
        )
        @test length(snap2) == 0  # filtered out

        # High intensity
#        snap3 = _run( # DoD REMEDIATION
            node_ids_patterns = [("n1", "gravity"), ("n2", "quantum")],
            lobe_of_fn = _lobe_cross,
            chatter_co_occur_pairs = [("gravity", "quantum", 1.0)],
        )
        rec3 = _find_pair(snap3, "n1", "n2")
        @test rec3 !== nothing
        # 0.6 * 1.0 * 0.5 = 0.3
        @test rec3["accumulated_intensity"] ≈ 0.3 atol=0.001
    end

    # =====================================================================
    # COMBINED: All 3 MLP knobs active simultaneously
    # =====================================================================
    @testset "Combined — All MLP knobs active (cross-lobe)" begin
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.8,
            mlp_relevance_score = 0.3,
            mlp_novelty_score = 0.8,
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        # SOURCE 1: co_firing = 1.0
        # SOURCE 4: opposing_lobe_co_act = 3.0
        # SOURCE 9: disambiguation_bridge = 0.4*0.8*1.5 = 0.48
        # SOURCE 10: relevance_cross_lobe = 0.5*(1-0.3) = 0.35
        # SOURCE 12: novelty_co_fire = 1.0*0.2*1.5 = 0.3
        # Total = 1.0 + 3.0 + 0.48 + 0.35 + 0.3 = 5.13
        @test rec["accumulated_intensity"] ≈ 5.13 atol=0.01
        @test "co_firing" in rec["sources"]
        @test "opposing_lobe_co_act" in rec["sources"]
        @test "disambiguation_bridge" in rec["sources"]
        @test "relevance_cross_lobe" in rec["sources"]
        @test "novelty_co_fire" in rec["sources"]
    end

    # =====================================================================
    # COMBINED: All MLP knobs, same-lobe (limited sources)
    # =====================================================================
    @testset "Combined — All MLP knobs active (same-lobe)" begin
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_same,
            mlp_disambiguation = 0.8,
            mlp_relevance_score = 0.3,
            mlp_novelty_score = 0.8,
        )
        rec = _find_pair(snap, "n1", "n2")
        @test rec !== nothing
        # SOURCE 1: co_firing = 1.0
        # SOURCE 9: disambiguation_bridge = 0.4*0.8*1.0 = 0.32
        # SOURCE 12: novelty_co_fire = 1.0*0.2*1.0 = 0.2
        # NO SOURCE 4 (same lobe), NO SOURCE 10 (same lobe only)
        # Total = 1.0 + 0.32 + 0.2 = 1.52
        @test rec["accumulated_intensity"] ≈ 1.52 atol=0.01
        @test "co_firing" in rec["sources"]
        @test "disambiguation_bridge" in rec["sources"]
        @test "novelty_co_fire" in rec["sources"]
        @test "opposing_lobe_co_act" ∉ rec["sources"]
        @test "relevance_cross_lobe" ∉ rec["sources"]
    end

    # =====================================================================
    # NEGATIVE: No co-fired IDs → no MLP-based link evidence
    # =====================================================================
    @testset "Negative — No co-fired IDs" begin
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = String[],
            lobe_of_fn = _lobe_cross,
            mlp_disambiguation = 0.8,
            mlp_relevance_score = 0.3,
            mlp_novelty_score = 0.8,
        )
        @test length(snap) == 0  # no pairs to link
    end

    # =====================================================================
    # NEGATIVE: Single node → no pairs
    # =====================================================================
    @testset "Negative — Single co-fired node" begin
#        snap = _run( # DoD REMEDIATION
            co_fired_ids = ["n1"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.8,
        )
        @test length(snap) == 0
    end

    # =====================================================================
    # LINK EVIDENCE RESET
    # =====================================================================
    @testset "Link Evidence Reset" begin
        _reset!()
        AutoLinker.accumulate_link_evidence!(;
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
        )
        @test length(AutoLinker.get_link_evidence_snapshot()) >= 1
        _reset!()
        @test length(AutoLinker.get_link_evidence_snapshot()) == 0
    end

    # =====================================================================
    # EVIDENCE STACKS ACROSS CALLS
    # =====================================================================
    @testset "Link Evidence Stacks Across Calls" begin
        _reset!()
        AutoLinker.accumulate_link_evidence!(;
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
        )
        snap1 = AutoLinker.get_link_evidence_snapshot()
        rec1 = _find_pair(snap1, "n1", "n2")
        freq1 = rec1["frequency"]
        int1 = rec1["accumulated_intensity"]

        AutoLinker.accumulate_link_evidence!(;
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
        )
        snap2 = AutoLinker.get_link_evidence_snapshot()
        rec2 = _find_pair(snap2, "n1", "n2")
        @test rec2["frequency"] > freq1
        @test rec2["accumulated_intensity"] > int1
    end

    # =====================================================================
    # SERIALIZE / DESERIALIZE ROUND-TRIP
    # =====================================================================
    @testset "Link Evidence Serialize/Deserialize Round-Trip" begin
        _reset!()
        AutoLinker.accumulate_link_evidence!(;
            co_fired_ids = ["n1", "n2"],
            lobe_of_fn = _lobe_cross,
            mlp_novelty_score = 0.8,
        )
        snap_before = AutoLinker.get_link_evidence_snapshot()
        @test length(snap_before) >= 1

        serialized = copy(snap_before)
        _reset!()
        @test length(AutoLinker.get_link_evidence_snapshot()) == 0

        AutoLinker.load_link_evidence_snapshot!(serialized)
        snap_after = AutoLinker.get_link_evidence_snapshot()
        @test length(snap_after) == length(snap_before)

        rec_before = _find_pair(snap_before, "n1", "n2")
        rec_after = _find_pair(snap_after, "n1", "n2")
        @test rec_after !== nothing
        @test rec_after["accumulated_intensity"] ≈ rec_before["accumulated_intensity"] atol=0.01
        @test rec_after["is_cross_lobe"] == rec_before["is_cross_lobe"]
    end

end

println("✅ EphemeralMLP → AutoLinker evidence signal flow tests complete!")
