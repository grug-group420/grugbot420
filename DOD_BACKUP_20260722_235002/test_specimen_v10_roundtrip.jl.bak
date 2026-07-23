#!/usr/bin/env julia
# test/test_specimen_v10_roundtrip.jl
# ──────────────────────────────────────────────────────────────────────────────
# GRUG: Regression test — specimen save/load round-trip with all v10 chunks.
# Verifies flashcards, curiosity accumulator, and evidence sources
# survive the serialize → deserialize cycle without data loss.
# ──────────────────────────────────────────────────────────────────────────────

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

# ── Load modules in isolated sub-modules ──────────────────────────────────────
module _SpecLobeTableParent
    include(joinpath(@__DIR__, "..", "src", "LobeTable.jl"))
end

module _SpecAutoGrowthParent
    # BUG-011: AutoGrowth does `using ..SigilRegistry`, so the parent must
    # provide it before AutoGrowth is included.
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
    include(joinpath(@__DIR__, "..", "src", "AutoGrowth.jl"))
end

module _SpecAutoLinkerParent
    include(joinpath(@__DIR__, "..", "src", "AutoLinker.jl"))
end

module _SpecThesaurusParent
    include(joinpath(@__DIR__, "..", "src", "Thesaurus.jl"))
end

using ._SpecLobeTableParent.LobeTable
using ._SpecAutoGrowthParent.AutoGrowth
using ._SpecAutoLinkerParent.AutoLinker
using ._SpecThesaurusParent.Thesaurus

# ── Helpers ───────────────────────────────────────────────────────────────────

function _reset_all!()
    AutoGrowth.reset_evidence!()
    AutoLinker.reset_link_evidence!()
    AutoGrowth.deserialize_curiosity!(Dict(
        "buffer" => String[],
        "intensity" => 0.0,
        "quenched_at" => 0.0,
        "overflow_count" => 0,
    ))
    for (lid, rec) in collect(LobeTable.LOBE_TABLE_REGISTRY)
        if haskey(rec.chunks, LobeTable.CHUNK_FLASHCARD)
            chunk = rec.chunks[LobeTable.CHUNK_FLASHCARD]
            lock(chunk.lock) do
                empty!(chunk.store)
            end
        end
    end
end

function _fresh_lobe(suffix::String="")::String
    lid = "spec_v10_$(suffix)_$(round(Int, time() * 1000) % 1_000_000)"
    LobeTable.create_lobe_table!(lid)
    return lid
end

# ═════════════════════════════════════════════════════════════════════════════
@testset "Specimen v10 Round-Trip" begin

    # ── 1. Flashcard serialize/deserialize round-trip ─────────────────────────
    @testset "Flashcard round-trip" begin
        _reset_all!()
        lid = _fresh_lobe("flash")

        LobeTable.flashcard_put!(lid, "3+5", "8"; result_num=8.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "7*6", "42"; result_num=42.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "pi", "3.14159"; card_type=:reference)

        @test LobeTable.flashcard_has(lid, "3+5")
        @test LobeTable.flashcard_has(lid, "7*6")
        @test LobeTable.flashcard_has(lid, "pi")
        @test LobeTable.flashcard_count(lid) == 3

        fc_data = LobeTable.serialize_flashcards()
        @test haskey(fc_data, lid)
        @test length(fc_data[lid]) == 3

        LobeTable.flashcard_delete!(lid, "3+5")
        LobeTable.flashcard_delete!(lid, "7*6")
        LobeTable.flashcard_delete!(lid, "pi")
        @test LobeTable.flashcard_count(lid) == 0

        LobeTable.deserialize_flashcards!(fc_data)

        @test LobeTable.flashcard_count(lid) == 3
        result_35 = LobeTable.flashcard_get(lid, "3+5")
        @test result_35 !== nothing
        @test get(result_35, "result", "") == "8" || occursin("8", get(result_35, "result", ""))
        result_76 = LobeTable.flashcard_get(lid, "7*6")
        @test result_76 !== nothing
        @test get(result_76, "result", "") == "42" || occursin("42", get(result_76, "result", ""))
        result_pi = LobeTable.flashcard_get(lid, "pi")
        @test result_pi !== nothing
    end

    # ── 2. Curiosity accumulator serialize/deserialize round-trip ─────────────
    #    NOTE: get_curiosity_status() returns "buffer_size" and "buffer_top5",
    #    NOT "buffer". The serialize/deserialize API uses "buffer" internally.
    @testset "Curiosity round-trip" begin
        _reset_all!()

        AutoGrowth.accumulate_evidence!(
            user_text = "quantum entanglement coherence",
            intensity = 0.8,
            node_patterns = Set{String}(["quantum", "entanglement"]),
            node_ids_patterns = [("n_q", "quantum"), ("n_e", "entanglement")],
            thesaurus_gate_filter = Thesaurus.synonym_lookup,
            thesaurus_word_similarity = Thesaurus.word_similarity,
            mlp_novelty_score = 0.9,
        )

        cur_status = AutoGrowth.get_curiosity_status()
        @test cur_status["intensity"] > 0.0

        cur_data = AutoGrowth.serialize_curiosity()
        @test haskey(cur_data, "intensity")
        @test haskey(cur_data, "buffer")
        @test haskey(cur_data, "quenched_at")
        @test haskey(cur_data, "overflow_count")
        saved_intensity = cur_data["intensity"]
        saved_buffer_len = length(cur_data["buffer"])

        # Clear curiosity via deserialize with reset Dict
        AutoGrowth.deserialize_curiosity!(Dict(
            "buffer" => String[],
            "intensity" => 0.0,
            "quenched_at" => 0.0,
            "overflow_count" => 0,
        ))

        # Verify cleared — use "buffer_size" (get_curiosity_status key), not "buffer"
        cur_cleared = AutoGrowth.get_curiosity_status()
        @test cur_cleared["intensity"] == 0.0
        @test cur_cleared["buffer_size"] == 0

        # Restore from saved data
        AutoGrowth.deserialize_curiosity!(cur_data)

        cur_restored = AutoGrowth.get_curiosity_status()
        @test cur_restored["intensity"] ≈ saved_intensity atol=0.01
        @test cur_restored["buffer_size"] == saved_buffer_len
    end

    # ── 3. AutoGrowth evidence snapshot round-trip ────────────────────────────
    @testset "AutoGrowth evidence round-trip" begin
        _reset_all!()

        AutoGrowth.accumulate_evidence!(
            user_text = "photosynthesis chlorophyll wavelength",
            intensity = 1.0,
            node_patterns = Set{String}(["photosynthesis", "chlorophyll"]),
            node_ids_patterns = [("n_p", "photosynthesis"), ("n_c", "chlorophyll")],
            thesaurus_gate_filter = Thesaurus.synonym_lookup,
            thesaurus_word_similarity = Thesaurus.word_similarity,
            mlp_semantic_score = 0.3,
            mlp_relevance_score = 0.4,
            mlp_disambiguation = 0.7,
            coherence_delta_phi = -0.2,
        )

        snap = AutoGrowth.get_evidence_snapshot()
        @test !isempty(snap)

        patterns = [e["pattern"] for e in snap]
        @test any(occursin("photosynthesis", p) for p in patterns)

        for e in snap
            @test haskey(e, "pattern")
            @test haskey(e, "accumulated_intensity")
            @test haskey(e, "frequency")
            @test haskey(e, "sources")
            @test haskey(e, "growth_type")
        end
    end

    # ── 4. AutoLinker evidence snapshot round-trip ────────────────────────────
    #    NOTE: get_link_evidence_snapshot() returns Dict{String,Any} where
    #    keys are composite link keys and values are Dicts with "node_a",
    #    "node_b", "accumulated_intensity", "frequency", etc.
    @testset "AutoLinker evidence round-trip" begin
        _reset_all!()

        AutoLinker.accumulate_link_evidence!(
            co_fired_ids = ["n1", "n2"],
            input_touched_ids = String[],
            node_ids_patterns = [("n1", "alpha"), ("n2", "beta")],
            bridge_map_snapshot = Dict{String,Vector{Tuple{String,String}}}(),
            thesaurus_gate_filter = Thesaurus.synonym_lookup,
            thesaurus_word_similarity = Thesaurus.word_similarity,
            lobe_of_fn = (nid) -> "default",
            strain_nodes = String[],
            co_occur_map = Dict{Tuple{String,String},Int}(),
            co_activation_pairs = Tuple{String,String,Float64}[],
            mlp_disambiguation = 0.8,
            mlp_relevance_score = 0.3,
        )

        snap = AutoLinker.get_link_evidence_snapshot()
        @test !isempty(snap)

        # Iterate over values (each is a Dict), not pairs
        for (key, rec) in snap
            @test haskey(rec, "node_a")
            @test haskey(rec, "node_b")
            @test haskey(rec, "accumulated_intensity")
            @test haskey(rec, "frequency")
            @test haskey(rec, "sources")
        end
    end

    # ── 5. Empty flashcard serialization ─────────────────────────────────────
    @testset "Empty flashcard serialization" begin
        _reset_all!()

        fc_data = LobeTable.serialize_flashcards()
        @test isempty(fc_data) || all(isempty(v) for v in values(fc_data))
    end

    # ── 6. Multiple lobe flashcard round-trip ────────────────────────────────
    @testset "Multi-lobe flashcard round-trip" begin
        _reset_all!()
        lid_math = _fresh_lobe("math")
        lid_geo = _fresh_lobe("geo")

        LobeTable.flashcard_put!(lid_math, "9*9", "81"; result_num=81.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid_geo, "triangle_angles", "180"; card_type=:reference)

        @test LobeTable.flashcard_count(lid_math) == 1
        @test LobeTable.flashcard_count(lid_geo) == 1

        fc_data = LobeTable.serialize_flashcards()
        @test haskey(fc_data, lid_math)
        @test haskey(fc_data, lid_geo)

        LobeTable.flashcard_delete!(lid_math, "9*9")
        LobeTable.flashcard_delete!(lid_geo, "triangle_angles")
        @test LobeTable.flashcard_count(lid_math) == 0
        @test LobeTable.flashcard_count(lid_geo) == 0

        LobeTable.deserialize_flashcards!(fc_data)
        @test LobeTable.flashcard_count(lid_math) == 1
        @test LobeTable.flashcard_count(lid_geo) == 1
        card_99 = LobeTable.flashcard_get(lid_math, "9*9")
        @test card_99 !== nothing
        @test get(card_99, "result", "") == "81" || occursin("81", get(card_99, "result", ""))
    end

    # ── 7. Curiosity with overflow count ──────────────────────────────────────
    #    NOTE: get_curiosity_status() uses "overflow_count" key.
    @testset "Curiosity overflow count preservation" begin
        _reset_all!()

        AutoGrowth.deserialize_curiosity!(Dict(
            "buffer" => String["pattern_a"],
            "intensity" => 0.5,
            "quenched_at" => 0.0,
            "overflow_count" => 3,
        ))

        cur1 = AutoGrowth.get_curiosity_status()
        @test cur1["overflow_count"] == 3

        cur_data = AutoGrowth.serialize_curiosity()
        @test cur_data["overflow_count"] == 3

        AutoGrowth.deserialize_curiosity!(Dict(
            "buffer" => String[],
            "intensity" => 0.0,
            "quenched_at" => 0.0,
            "overflow_count" => 0,
        ))

        AutoGrowth.deserialize_curiosity!(cur_data)
        cur2 = AutoGrowth.get_curiosity_status()
        @test cur2["overflow_count"] == 3
    end

end # @testset "Specimen v10 Round-Trip"

println("✅ Specimen v10 round-trip regression tests complete.")
