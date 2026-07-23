# test_coherence_delta_evidence.jl - GRUG v10 CoherenceField ΔΦ → AutoGrowth Evidence Source Tests
# GRUG say: When coherence field drops, growth must fill the gap.
# SOURCE 12 fires when coherence_delta_phi < COHERENCE_DROP_THRESHOLD (-0.15).
# Evidence increment = |ΔΦ| * 0.5 * intensity per uncovered token.
# NOTE: The activation mode multiplier (sigmoid=0.8, relu=1.25) applies GLOBALLY
# to all evidence. So the total accumulated_intensity includes silence_map + coherence_drop
# all multiplied by the mode factor. We test the DELTA between with/without coherence_drop
# to isolate SOURCE 12's contribution.

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

module _CoherenceDeltaTestParent
    # BUG-011: AutoGrowth does `using ..SigilRegistry`, so the parent must
    # provide it before AutoGrowth is included.
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
    include(joinpath(@__DIR__, "..", "src", "AutoGrowth.jl"))
end

using ._CoherenceDeltaTestParent.AutoGrowth

println("🧪 Running CoherenceField ΔΦ → AutoGrowth evidence source tests...")

# =========================================================================
# HELPERS
# =========================================================================

"""Full reset: evidence + curiosity."""
function _full_reset!()
    AutoGrowth.reset_evidence!()
    AutoGrowth.deserialize_curiosity!(Dict{String,Any}(
        "buffer" => String[],
        "intensity" => 0.0,
        "quenched_at" => 0.0,
        "overflow_count" => 0,
    ))
end

"""Run accumulate with specified params, return snapshot."""
#function _run( # DoD REMEDIATION;
    user_text::String = "quantum",
    intensity::Float64 = 0.5,
    node_patterns::Set{String} = Set(["happy"]),
    coherence_delta_phi::Float64 = 0.0,
    mlp_semantic_score::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    mlp_disambiguation::Float64 = 0.5,
    mlp_novelty_score::Float64 = 0.5,
    mlp_activation_mode::Symbol = :sigmoid,
    mlp_hash_rarity::Float64 = 0.0,
    mlp_correlation_quality::Float64 = 0.5,
    strain_energy::Float64 = 0.0,
    gate_filter::Function = w -> String[],
    word_sim::Function = (a, b) -> 0.0,
    lobe_snaps = Tuple{String,String,Set{String}}[],
)
    _full_reset!()
    AutoGrowth.accumulate_evidence!(;
        user_text = user_text,
        intensity = intensity,
        node_patterns = node_patterns,
        node_ids_patterns = [("n1", "happy")],
        thesaurus_gate_filter = gate_filter,
        thesaurus_word_similarity = word_sim,
        lobe_snapshots = lobe_snaps,
        strain_energy = strain_energy,
        mlp_semantic_score = mlp_semantic_score,
        mlp_relevance_score = mlp_relevance_score,
        mlp_disambiguation = mlp_disambiguation,
        coherence_delta_phi = coherence_delta_phi,
        mlp_novelty_score = mlp_novelty_score,
        mlp_activation_mode = mlp_activation_mode,
        mlp_hash_rarity = mlp_hash_rarity,
        mlp_correlation_quality = mlp_correlation_quality,
    )
    return AutoGrowth.get_evidence_snapshot()
end

"""Find a specific pattern in a snapshot, return its Dict or nothing."""
function _find_pattern(snap::Vector{Dict{String,Any}}, pattern::String)::Union{Dict{String,Any}, Nothing}
    for entry in snap
        if entry["pattern"] == pattern
            return entry
        end
    end
    return nothing
end

"""Get intensity for a pattern from snapshot, or 0.0 if not found."""
function _get_intensity(snap, pattern::String)::Float64
    p = _find_pattern(snap, pattern)
    return p === nothing ? 0.0 : Float64(p["accumulated_intensity"])
end

# =========================================================================
# SOURCE 12: COHERENCE FIELD DELTA
# =========================================================================

@testset "SOURCE 12 — CoherenceField ΔΦ threshold boundary" begin
    # COHERENCE_DROP_THRESHOLD = -0.15 (strict <)
    # At exactly -0.15, threshold is NOT crossed (strict <)
#    snap = _run( # DoD REMEDIATION; user_text="quantum", coherence_delta_phi=-0.15)
    p = _find_pattern(snap, "quantum")
    @test p !== nothing  # silence_map still creates it
    @test !("coherence_drop" in p["sources"])  # but no coherence_drop

    # At -0.151, threshold IS crossed (strict <)
#    snap = _run( # DoD REMEDIATION; user_text="quantum", coherence_delta_phi=-0.151)
    p = _find_pattern(snap, "quantum")
    @test p !== nothing
    @test "coherence_drop" in p["sources"]
end

@testset "SOURCE 12 — evidence delta = |ΔΦ| * 0.5 * intensity (mode-adjusted)" begin
    # Strategy: run WITHOUT coherence_drop, then WITH. The delta isolates SOURCE 12.
    # In sigmoid mode, ALL evidence gets multiplied by ACTIVATION_SIGMOID_GROWTH_MULT=0.8.
    # So the raw coherence_drop contribution = |ΔΦ|*0.5*intensity, then *0.8 from mode.

    # Case 1: intensity=0.5, ΔΦ=-0.3 → raw=0.3*0.5*0.5=0.075, mode-adjusted=0.075*0.8=0.06
#    snap_no_drop = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=0.0)
#    snap_with_drop = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-0.3)
    delta = _get_intensity(snap_with_drop, "quantum") - _get_intensity(snap_no_drop, "quantum")
    @test abs(delta - 0.06) < 0.01  # 0.075 * 0.8 (sigmoid mode)

    # Case 2: intensity=1.0, ΔΦ=-0.4 → raw=0.4*0.5*1.0=0.2, mode-adjusted=0.2*0.8=0.16
#    snap_no_drop2 = _run( # DoD REMEDIATION; user_text="quantum", intensity=1.0, coherence_delta_phi=0.0)
#    snap_with_drop2 = _run( # DoD REMEDIATION; user_text="quantum", intensity=1.0, coherence_delta_phi=-0.4)
    delta2 = _get_intensity(snap_with_drop2, "quantum") - _get_intensity(snap_no_drop2, "quantum")
    @test abs(delta2 - 0.16) < 0.01  # 0.2 * 0.8 (sigmoid mode)
end

@testset "SOURCE 12 — evidence delta with ReLU mode" begin
    # ReLU mode: ACTIVATION_RELU_GROWTH_MULT = 1.25
    # raw contribution = |ΔΦ|*0.5*intensity, then *1.25 from mode
    # intensity=0.5, ΔΦ=-0.3 → raw=0.075, mode-adjusted=0.075*1.25=0.09375
#    snap_no = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=0.0, mlp_activation_mode=:relu)
#    snap_yes = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-0.3, mlp_activation_mode=:relu)
    delta = _get_intensity(snap_yes, "quantum") - _get_intensity(snap_no, "quantum")
    @test abs(delta - 0.09375) < 0.01
end

@testset "SOURCE 12 — no fire when ΔΦ is positive or zero" begin
    for dphi in [0.0, 0.1, 0.5, 1.0, 10.0]
#        snap = _run( # DoD REMEDIATION; user_text="quantum", coherence_delta_phi=dphi)
        p = _find_pattern(snap, "quantum")
        @test p === nothing || !("coherence_drop" in p["sources"])
    end
end

@testset "SOURCE 12 — no fire when ΔΦ is mildly negative (above threshold)" begin
    # -0.1 > -0.15, so above threshold — no coherence_drop
    for dphi in [-0.01, -0.05, -0.1, -0.14, -0.149]
#        snap = _run( # DoD REMEDIATION; user_text="quantum", coherence_delta_phi=dphi)
        p = _find_pattern(snap, "quantum")
        @test p === nothing || !("coherence_drop" in p["sources"])
    end
end

@testset "SOURCE 12 — stronger drop produces larger evidence delta" begin
    # Compare deltas for ΔΦ=-0.2 vs ΔΦ=-0.8
#    snap_no = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=0.0)
#    snap_mild = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-0.2)
#    snap_strong = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-0.8)

    delta_mild = _get_intensity(snap_mild, "quantum") - _get_intensity(snap_no, "quantum")
    delta_strong = _get_intensity(snap_strong, "quantum") - _get_intensity(snap_no, "quantum")

    @test delta_strong > delta_mild
    # Ratio should be 4:1 (0.8/0.2)
    @test abs(delta_strong / delta_mild - 4.0) < 0.1
end

@testset "SOURCE 12 — only uncovered tokens get coherence_drop" begin
    # "quantum" is NOT in node_patterns={"happy"} → uncovered → gets evidence
#    snap = _run( # DoD REMEDIATION; user_text="quantum", node_patterns=Set(["happy"]), coherence_delta_phi=-0.3)
    p = _find_pattern(snap, "quantum")
    @test p !== nothing
    @test "coherence_drop" in p["sources"]

    # "happy" IS in node_patterns → covered → should NOT get coherence_drop
#    snap2 = _run( # DoD REMEDIATION; user_text="happy", node_patterns=Set(["happy"]), coherence_delta_phi=-0.3)
    p2 = _find_pattern(snap2, "happy")
    @test p2 === nothing || !("coherence_drop" in p2["sources"])
end

@testset "SOURCE 12 — stopwords excluded from coherence_drop" begin
#    snap = _run( # DoD REMEDIATION; user_text="is quantum", coherence_delta_phi=-0.3)
    # "is" is a stopword (length=2) → excluded from coherence_drop
    p_is = _find_pattern(snap, "is")
    @test p_is === nothing || !("coherence_drop" in p_is["sources"])
    # "quantum" should still get coherence_drop
    p_q = _find_pattern(snap, "quantum")
    @test p_q !== nothing
    @test "coherence_drop" in p_q["sources"]
end

@testset "SOURCE 12 — multiple uncovered tokens each get coherence_drop" begin
#    snap_no = _run( # DoD REMEDIATION; user_text="quantum gravity entanglement", intensity=0.5, coherence_delta_phi=0.0)
#    snap_yes = _run( # DoD REMEDIATION; user_text="quantum gravity entanglement", intensity=0.5, coherence_delta_phi=-0.3)

    for tok in ["quantum", "gravity", "entanglement"]
        p = _find_pattern(snap_yes, tok)
        @test p !== nothing
        @test "coherence_drop" in p["sources"]
        # Each token's delta should be the same: |ΔΦ|*0.5*intensity*0.8 = 0.3*0.5*0.5*0.8 = 0.06
        delta = _get_intensity(snap_yes, tok) - _get_intensity(snap_no, tok)
        @test abs(delta - 0.06) < 0.01
    end
end

@testset "SOURCE 12 — coherence_drop evidence stacks across cycles" begin
    _full_reset!()
    # First cycle
    AutoGrowth.accumulate_evidence!(;
        user_text="quantum", intensity=0.5, node_patterns=Set(["happy"]),
        node_ids_patterns=[("n1","happy")], thesaurus_gate_filter=w->String[],
        thesaurus_word_similarity=(a,b)->0.0, coherence_delta_phi=-0.3,
    )
    snap1 = AutoGrowth.get_evidence_snapshot()
    p1 = _find_pattern(snap1, "quantum")
    @test p1 !== nothing
    first_intensity = p1["accumulated_intensity"]

    # Second cycle (same coherence drop)
    AutoGrowth.accumulate_evidence!(;
        user_text="quantum", intensity=0.5, node_patterns=Set(["happy"]),
        node_ids_patterns=[("n1","happy")], thesaurus_gate_filter=w->String[],
        thesaurus_word_similarity=(a,b)->0.0, coherence_delta_phi=-0.3,
    )
    snap2 = AutoGrowth.get_evidence_snapshot()
    p2 = _find_pattern(snap2, "quantum")
    @test p2 !== nothing
    @test p2["frequency"] > p1["frequency"]
    @test p2["accumulated_intensity"] >= first_intensity
end

@testset "SOURCE 12 — combined with novelty surge (SOURCE 14)" begin
    # SOURCE 14 (novelty surge) modulates existing evidence intensity, doesn't add a new source.
    # When both coherence_drop and novelty surge fire, intensity should be higher than
    # coherence_drop alone.
#    snap_drop_only = _run( # DoD REMEDIATION;
        user_text="quantum", intensity=0.5,
        coherence_delta_phi=-0.3, mlp_novelty_score=0.5,  # no surge
    )
#    snap_drop_and_surge = _run( # DoD REMEDIATION;
        user_text="quantum", intensity=0.5,
        coherence_delta_phi=-0.3, mlp_novelty_score=0.8,  # surge fires (>0.65)
    )
    # Both should have coherence_drop in sources
    @test "coherence_drop" in _find_pattern(snap_drop_only, "quantum")["sources"]
    @test "coherence_drop" in _find_pattern(snap_drop_and_surge, "quantum")["sources"]
    # With surge, intensity should be HIGHER (surge boosts all recent evidence)
    @test _get_intensity(snap_drop_and_surge, "quantum") > _get_intensity(snap_drop_only, "quantum")
end

@testset "SOURCE 12 — combined with semantic gap (SOURCE 9)" begin
    # SOURCE 9 (semantic gap) fires when mlp_semantic_score < 0.35 AND intensity > 0.5.
    # It adds "semantic_gap" as a separate source. Use intensity=0.6 to trigger it.
#    snap_drop_only = _run( # DoD REMEDIATION;
        user_text="quantum", intensity=0.6,
        coherence_delta_phi=-0.3, mlp_semantic_score=0.5,  # no semantic gap
    )
#    snap_drop_and_gap = _run( # DoD REMEDIATION;
        user_text="quantum", intensity=0.6,
        coherence_delta_phi=-0.3, mlp_semantic_score=0.2,  # semantic gap fires
    )
    p = _find_pattern(snap_drop_and_gap, "quantum")
    @test p !== nothing
    @test "coherence_drop" in p["sources"]
    @test "semantic_gap" in p["sources"]
    # Intensity with both should be higher than coherence_drop alone
    @test _get_intensity(snap_drop_and_gap, "quantum") > _get_intensity(snap_drop_only, "quantum")
end

@testset "SOURCE 12 — growth_type is :match for coherence_drop" begin
#    snap = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-0.3)
    p = _find_pattern(snap, "quantum")
    @test p !== nothing
    @test p["growth_type"] == "match"
end

@testset "COHERENCE_DROP_THRESHOLD export check" begin
    @test AutoGrowth.COHERENCE_DROP_THRESHOLD ≈ -0.15 atol=0.001
end

@testset "SOURCE 12 — very large coherence drop still valid" begin
#    snap_no = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=0.0)
#    snap_yes = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5, coherence_delta_phi=-5.0)
    delta = _get_intensity(snap_yes, "quantum") - _get_intensity(snap_no, "quantum")
    # Raw = 5.0*0.5*0.5 = 1.25, mode-adjusted = 1.25*0.8 = 1.0
    @test delta > 0.5  # Very strong evidence
    @test "coherence_drop" in _find_pattern(snap_yes, "quantum")["sources"]
end

@testset "SOURCE 12 — ΔΦ with ReLU mode produces larger evidence than sigmoid" begin
#    snap_sigmoid = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5,
                         coherence_delta_phi=-0.3, mlp_activation_mode=:sigmoid)
#    snap_relu = _run( # DoD REMEDIATION; user_text="quantum", intensity=0.5,
                      coherence_delta_phi=-0.3, mlp_activation_mode=:relu)
    # ReLU (1.25x) > sigmoid (0.8x) for same coherence drop
    @test _get_intensity(snap_relu, "quantum") > _get_intensity(snap_sigmoid, "quantum")
end

println("✅ All CoherenceField ΔΦ → AutoGrowth evidence source tests complete!")
