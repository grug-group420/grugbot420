# test_mlp_autogrowth_signals.jl - GRUG v10 Deep MLP → AutoGrowth Evidence Signal Flow Tests
# GRUG say: MLP knobs must ACTUALLY change evidence numbers. No hand-waving.
# GRUG say: SOURCE 14 (novelty surge) must boost. SOURCE 15 (activation mode) must multiply.
# GRUG say: SOURCE 16 (hash rarity) must add. SOURCE 17 (correlation quality) must boost thesaurus.
# GRUG say: Curiosity accumulator must overflow and quench. Novelty must feed curiosity.
# ALL math is traced to exact constants. No approximations without tolerance.

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

module _MLPAutoGrowthTestParent
    # BUG-011: AutoGrowth does `using ..SigilRegistry`, so the parent must
    # provide it before AutoGrowth is included.
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
    include(joinpath(@__DIR__, "..", "src", "AutoGrowth.jl"))
end

using ._MLPAutoGrowthTestParent.AutoGrowth

println("🧪 Running EphemeralMLP → AutoGrowth evidence signal flow tests...")

# =========================================================================
# HELPERS
# =========================================================================

"""Full reset: evidence + curiosity + co-occurrence."""
function _full_reset!()
    AutoGrowth.reset_evidence!()
    AutoGrowth.deserialize_curiosity!(Dict{String,Any}(
        "buffer" => String[],
        "intensity" => 0.0,
        "quenched_at" => 0.0,
        "overflow_count" => 0,
    ))
end

"""Reset evidence, call accumulate_evidence! with specified MLP knobs, return snapshot."""
function _run_accumulate(;
    user_text::String = "quantum",
    intensity::Float64 = 0.5,
    node_patterns::Set{String} = Set(["happy"]),
    mlp_novelty_score::Float64 = 0.5,
    mlp_activation_mode::Symbol = :sigmoid,
    mlp_hash_rarity::Float64 = 0.0,
    mlp_correlation_quality::Float64 = 0.5,
    mlp_semantic_score::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    mlp_disambiguation::Float64 = 0.5,
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

@testset "MLP → AutoGrowth Evidence Signal Flow" begin

    # =====================================================================
    # BASELINE: No MLP boosts (sigmoid, low novelty, no rarity, low quality)
    # =====================================================================
    @testset "Baseline — sigmoid, no boosts" begin
        snap = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.0,
            mlp_correlation_quality = 0.5,
        )
        @test length(snap) == 1
        rec = _find_pattern(snap, "quantum")
        @test rec !== nothing
        @test rec["accumulated_intensity"] ≈ 0.4 atol=0.001
        @test "silence_map" in rec["sources"]
        @test rec["growth_type"] == "match"
    end

    # =====================================================================
    # SOURCE 14: NOVELTY SURGE
    # =====================================================================
    @testset "SOURCE 14 — Novelty Surge" begin
        snap = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :sigmoid,
        )
        rec = _find_pattern(snap, "quantum")
        @test rec !== nothing
        @test rec["accumulated_intensity"] ≈ 0.46 atol=0.001

        snap2 = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :relu,
        )
        rec2 = _find_pattern(snap2, "quantum")
        @test rec2 !== nothing
        @test rec2["accumulated_intensity"] ≈ 0.71875 atol=0.001

        snap3 = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.64,
            mlp_activation_mode = :sigmoid,
        )
        rec3 = _find_pattern(snap3, "quantum")
        @test rec3 !== nothing
        @test rec3["accumulated_intensity"] ≈ 0.4 atol=0.001

        snap4 = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.65,
            mlp_activation_mode = :sigmoid,
        )
        rec4 = _find_pattern(snap4, "quantum")
        @test rec4 !== nothing
        @test rec4["accumulated_intensity"] ≈ 0.4 atol=0.001

        snap5 = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.95,
            mlp_activation_mode = :sigmoid,
        )
        rec5 = _find_pattern(snap5, "quantum")
        @test rec5 !== nothing
        @test rec5["accumulated_intensity"] ≈ 0.52 atol=0.001
    end

    # =====================================================================
    # SOURCE 15: ACTIVATION MODE BIAS
    # =====================================================================
    @testset "SOURCE 15 — Activation Mode Bias" begin
        snap_relu = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :relu,
        )
        rec_relu = _find_pattern(snap_relu, "quantum")
        @test rec_relu !== nothing
        @test rec_relu["accumulated_intensity"] ≈ 0.625 atol=0.001

        snap_sig = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
        )
        rec_sig = _find_pattern(snap_sig, "quantum")
        @test rec_sig !== nothing
        @test rec_sig["accumulated_intensity"] ≈ 0.4 atol=0.001

        snap_both = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :relu,
        )
        rec_both = _find_pattern(snap_both, "quantum")
        @test rec_both !== nothing
        @test rec_both["accumulated_intensity"] ≈ 0.71875 atol=0.001

        @test rec_relu["accumulated_intensity"] > rec_sig["accumulated_intensity"]
    end

    # =====================================================================
    # SOURCE 16: HASH RARITY
    # =====================================================================
    @testset "SOURCE 16 — Hash Rarity" begin
        snap = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.5,
        )
        rec = _find_pattern(snap, "quantum")
        @test rec !== nothing
        @test rec["accumulated_intensity"] ≈ 0.4625 atol=0.001
        @test "hash_rarity" in rec["sources"]
        @test "silence_map" in rec["sources"]

        snap_below = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.2,
        )
        rec_below = _find_pattern(snap_below, "quantum")
        @test rec_below !== nothing
        @test "hash_rarity" ∉ rec_below["sources"]
        @test rec_below["accumulated_intensity"] ≈ 0.4 atol=0.001

        # At threshold (0.3) — strict > is false, no rarity
        snap_at = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.3,
        )
        rec_at = _find_pattern(snap_at, "quantum")
        @test rec_at !== nothing
        @test "hash_rarity" ∉ rec_at["sources"]
        @test rec_at["accumulated_intensity"] ≈ 0.4 atol=0.001

        # Just above threshold (0.31) — rarity fires
        snap_just = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.31,
        )
        rec_just = _find_pattern(snap_just, "quantum")
        @test rec_just !== nothing
        @test "hash_rarity" in rec_just["sources"]

        # Very high hash_rarity (0.9)
        snap_high = _run_accumulate(;
            user_text = "quantum",
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.9,
        )
        rec_high = _find_pattern(snap_high, "quantum")
        @test rec_high !== nothing
        @test rec_high["accumulated_intensity"] ≈ 0.5125 atol=0.001
    end

    # =====================================================================
    # SOURCE 17: CORRELATION QUALITY BOOST
    # =====================================================================
    @testset "SOURCE 17 — Correlation Quality Boost" begin
        snap = _run_accumulate(;
            user_text = "happy",
            node_patterns = Set(["happy"]),
            gate_filter = w -> w == "happy" ? ["joyful", "glad"] : String[],
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.0,
            mlp_correlation_quality = 0.8,
        )
        rec_joyful = _find_pattern(snap, "joyful")
        @test rec_joyful !== nothing
        @test rec_joyful["accumulated_intensity"] ≈ 0.218 atol=0.002
        @test "thesaurus_gap" in rec_joyful["sources"]
        @test "correlation_quality_boost" in rec_joyful["sources"]
        @test rec_joyful["growth_type"] == "thesaurus"

        rec_glad = _find_pattern(snap, "glad")
        @test rec_glad !== nothing
        @test rec_glad["accumulated_intensity"] ≈ 0.218 atol=0.002

        # Below threshold (0.55) — no quality boost
        snap_below = _run_accumulate(;
            user_text = "happy",
            node_patterns = Set(["happy"]),
            gate_filter = w -> w == "happy" ? ["joyful"] : String[],
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.0,
            mlp_correlation_quality = 0.55,
        )
        rec_below = _find_pattern(snap_below, "joyful")
        @test rec_below !== nothing
        @test "correlation_quality_boost" ∉ rec_below["sources"]
        @test rec_below["accumulated_intensity"] ≈ 0.2 atol=0.001

        # At threshold (0.6) — strict > is false, no quality boost
        snap_at = _run_accumulate(;
            user_text = "happy",
            node_patterns = Set(["happy"]),
            gate_filter = w -> w == "happy" ? ["joyful"] : String[],
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.0,
            mlp_correlation_quality = 0.6,
        )
        rec_at = _find_pattern(snap_at, "joyful")
        @test rec_at !== nothing
        @test "correlation_quality_boost" ∉ rec_at["sources"]
        @test rec_at["accumulated_intensity"] ≈ 0.2 atol=0.001

        # Just above threshold (0.61) — quality boost fires
        snap_just = _run_accumulate(;
            user_text = "happy",
            node_patterns = Set(["happy"]),
            gate_filter = w -> w == "happy" ? ["joyful"] : String[],
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_hash_rarity = 0.0,
            mlp_correlation_quality = 0.61,
        )
        rec_just = _find_pattern(snap_just, "joyful")
        @test rec_just !== nothing
        @test "correlation_quality_boost" in rec_just["sources"]
        @test rec_just["accumulated_intensity"] > 0.2
    end

    # =====================================================================
    # COMBINED: All 4 MLP knobs active simultaneously
    # =====================================================================
    @testset "Combined — All MLP knobs active" begin
        snap = _run_accumulate(;
            user_text = "happy entangle",
            node_patterns = Set(["happy"]),
            gate_filter = w -> w == "happy" ? ["joyful"] : String[],
            mlp_novelty_score = 0.9,
            mlp_activation_mode = :relu,
            mlp_hash_rarity = 0.6,
            mlp_correlation_quality = 0.9,
        )

        rec_entangle = _find_pattern(snap, "entangle")
        @test rec_entangle !== nothing
        @test "silence_map" in rec_entangle["sources"]
        @test "hash_rarity" in rec_entangle["sources"]
        @test rec_entangle["accumulated_intensity"] ≈ 0.85625 atol=0.01

        rec_joyful = _find_pattern(snap, "joyful")
        @test rec_joyful !== nothing
        @test "thesaurus_gap" in rec_joyful["sources"]
        @test "correlation_quality_boost" in rec_joyful["sources"]
        @test rec_joyful["growth_type"] == "thesaurus"
        @test rec_joyful["accumulated_intensity"] ≈ 0.414625 atol=0.01
    end

    # =====================================================================
    # CURIOSITY ACCUMULATOR — novelty feeds curiosity
    # =====================================================================
    @testset "Curiosity Accumulator — Novelty Feed" begin
        _full_reset!()

        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_semantic_score = 0.5,
        )
        cs = AutoGrowth.get_curiosity_status()
        @test cs["intensity"] ≈ 0.05 atol=0.001
        @test cs["buffer_size"] == 1
        @test "quantum" in cs["buffer_top5"]

        _full_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.9,
            mlp_activation_mode = :sigmoid,
            mlp_semantic_score = 0.5,
        )
        cs2 = AutoGrowth.get_curiosity_status()
        @test cs2["intensity"] ≈ 0.104 atol=0.001
    end

    # =====================================================================
    # CURIOSITY OVERFLOW
    # =====================================================================
    @testset "Curiosity Overflow → Pending Ask" begin
        _full_reset!()

        for i in 1:9
            AutoGrowth.accumulate_evidence!(;
                user_text = "mystery$(i)",
                intensity = 0.5,
                node_patterns = Set(["happy"]),
                node_ids_patterns = [("n1", "happy")],
                thesaurus_gate_filter = w -> String[],
                thesaurus_word_similarity = (a, b) -> 0.0,
                mlp_novelty_score = 0.9,
                mlp_activation_mode = :sigmoid,
                mlp_semantic_score = 0.5,
            )
        end

        cs = AutoGrowth.get_curiosity_status()
        @test cs["is_overflowing"] == true
        @test cs["intensity"] >= 0.85
        @test cs["buffer_size"] >= 1

        overflow_pattern = AutoGrowth.check_curiosity_overflow()
        @test overflow_pattern !== nothing
        @test typeof(overflow_pattern) == String
        @test length(overflow_pattern) > 0

        AutoGrowth.quench_curiosity!()
        cs2 = AutoGrowth.get_curiosity_status()
        @test cs2["intensity"] ≈ 0.0 atol=0.001
        @test cs2["buffer_size"] == 0
        @test cs2["overflow_count"] == 1

        overflow2 = AutoGrowth.check_curiosity_overflow()
        @test overflow2 === nothing
        @test cs2["cooldown_remaining"] > 0.0
    end

    # =====================================================================
    # CURIOSITY — strain_energy contribution
    # =====================================================================
    @testset "Curiosity — Strain Energy Feed" begin
        _full_reset!()

        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            strain_energy = 0.7,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_semantic_score = 0.5,
        )
        cs = AutoGrowth.get_curiosity_status()
        @test cs["intensity"] ≈ 0.12 atol=0.001

        _full_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            strain_energy = 0.3,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
            mlp_semantic_score = 0.5,
        )
        cs2 = AutoGrowth.get_curiosity_status()
        @test cs2["intensity"] ≈ 0.05 atol=0.001
    end

    # =====================================================================
    # CURIOSITY — low semantic score contribution
    # =====================================================================
    @testset "Curiosity — Low Semantic Score Feed" begin
        _full_reset!()

        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_semantic_score = 0.2,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
        )
        cs = AutoGrowth.get_curiosity_status()
        @test cs["intensity"] > 0.05

        _full_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_semantic_score = 0.8,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
        )
        cs2 = AutoGrowth.get_curiosity_status()
        @test cs2["intensity"] ≈ 0.05 atol=0.001
    end

    # =====================================================================
    # CURIOSITY — serialize / deserialize round-trip
    # =====================================================================
    @testset "Curiosity Serialize/Deserialize Round-Trip" begin
        _full_reset!()

        for i in 1:5
            AutoGrowth.accumulate_evidence!(;
                user_text = "enigma$(i)",
                intensity = 0.5,
                node_patterns = Set(["happy"]),
                node_ids_patterns = [("n1", "happy")],
                thesaurus_gate_filter = w -> String[],
                thesaurus_word_similarity = (a, b) -> 0.0,
                mlp_novelty_score = 0.9,
                mlp_activation_mode = :sigmoid,
                mlp_semantic_score = 0.5,
            )
        end

        cs_before = AutoGrowth.get_curiosity_status()
        serialized = AutoGrowth.serialize_curiosity()
        @test haskey(serialized, "buffer")
        @test haskey(serialized, "intensity")
        @test haskey(serialized, "quenched_at")
        @test haskey(serialized, "overflow_count")
        @test length(serialized["buffer"]) == cs_before["buffer_size"]

        _full_reset!()
        AutoGrowth.deserialize_curiosity!(serialized)

        cs_after = AutoGrowth.get_curiosity_status()
        @test cs_after["intensity"] ≈ cs_before["intensity"] atol=0.01
        @test cs_after["buffer_size"] == cs_before["buffer_size"]
        @test cs_after["overflow_count"] == cs_before["overflow_count"]
    end

    # =====================================================================
    # MULTIPLE TOKENS — all knobs across multiple uncovered tokens
    # =====================================================================
    @testset "Multiple Uncovered Tokens — All MLP Effects" begin
        snap = _run_accumulate(;
            user_text = "quantum entangle paradox",
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :relu,
            mlp_hash_rarity = 0.5,
        )

        for tok in ["quantum", "entangle", "paradox"]
            rec = _find_pattern(snap, tok)
            @test rec !== nothing
            @test "silence_map" in rec["sources"]
            @test "hash_rarity" in rec["sources"]
            @test rec["accumulated_intensity"] ≈ 0.78125 atol=0.005
        end
    end

    # =====================================================================
    # NEGATIVE — covered tokens get no silence_map evidence
    # =====================================================================
    @testset "Negative — Covered Tokens No Evidence" begin
        snap = _run_accumulate(;
            user_text = "happy",
            node_patterns = Set(["happy"]),
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :relu,
            mlp_hash_rarity = 0.5,
        )
        rec = _find_pattern(snap, "happy")
        @test rec === nothing
    end

    # =====================================================================
    # EVIDENCE RESET
    # =====================================================================
    @testset "Evidence Reset Clears All" begin
        _full_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.8,
            mlp_activation_mode = :relu,
        )
        @test length(AutoGrowth.get_evidence_snapshot()) >= 1

        AutoGrowth.reset_evidence!()
        @test length(AutoGrowth.get_evidence_snapshot()) == 0
    end

    # =====================================================================
    # EVIDENCE STACKS ACROSS CYCLES
    # =====================================================================
    @testset "Evidence Stacks Across Cycles" begin
        _full_reset!()

        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
        )
        snap1 = AutoGrowth.get_evidence_snapshot()
        rec1 = _find_pattern(snap1, "quantum")
        @test rec1 !== nothing

        AutoGrowth.accumulate_evidence!(;
            user_text = "quantum",
            intensity = 0.5,
            node_patterns = Set(["happy"]),
            node_ids_patterns = [("n1", "happy")],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.3,
            mlp_activation_mode = :sigmoid,
        )
        snap2 = AutoGrowth.get_evidence_snapshot()
        rec2 = _find_pattern(snap2, "quantum")
        @test rec2 !== nothing
        @test rec2["frequency"] > rec1["frequency"]
        @test length(rec2["sources"]) >= length(rec1["sources"])
    end

end

println("✅ EphemeralMLP → AutoGrowth evidence signal flow tests complete!")
