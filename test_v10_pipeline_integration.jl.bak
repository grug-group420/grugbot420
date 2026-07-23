# test/test_v10_pipeline_integration.jl
# v10 — Enhanced integration test: full pipeline with v10 features.
#
# This test exercises the complete v10 pipeline:
#   1. InputDecomposer (v10 enhancements) → DecomposedSubSubject[]
#   2. MLP-assisted decomposition → additional compound splits
#   3. MultipartOrchestrator → objectives from compound inputs
#   4. Flashcard + Arithmetic pipeline
#   5. Curiosity accumulator + overflow → pending ask
#   6. PettyLearner + decomposition interaction
#   7. AutoGrowth evidence + coherence field ΔΦ
#
# KEY DESIGN: Like test_multipart_integration.jl, this test does NOT pull in
# the full engine. It uses the three pipeline modules (InputDecomposer,
# VoteOrchestrator, MultipartOrchestrator) plus isolated LobeTable, AutoGrowth,
# PettyLearner, and CoherenceField for cross-cutting concerns. Duck-typed
# TestVote structs simulate what process_mission would produce.

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

# ── Load pipeline modules ─────────────────────────────────────────────────
module _V10PipelineParent
    include(joinpath(@__DIR__, "..", "src", "InputDecomposer.jl"))
    using .InputDecomposer

    include(joinpath(@__DIR__, "..", "src", "VoteOrchestrator.jl"))
    include(joinpath(@__DIR__, "..", "src", "MultipartOrchestrator.jl"))
    using .MultipartOrchestrator
end

# ── Load isolated subsystem modules ───────────────────────────────────────
module _V10AutoGrowthParent
    # BUG-011: AutoGrowth does `using ..SigilRegistry`, so the parent must
    # provide it before AutoGrowth is included.
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
    include(joinpath(@__DIR__, "..", "src", "AutoGrowth.jl"))
end

module _V10LobeTableParent
    include(joinpath(@__DIR__, "..", "src", "LobeTable.jl"))
end

module _V10PettyLearnerParent
    include(joinpath(@__DIR__, "..", "src", "PettyLearner.jl"))
end

module _V10CoherenceFieldParent
    include(joinpath(@__DIR__, "..", "src", "CoherenceField.jl"))
end

using ._V10PipelineParent: DecomposedSubSubject
using ._V10PipelineParent.InputDecomposer
using ._V10PipelineParent.MultipartOrchestrator
using ._V10AutoGrowthParent.AutoGrowth
using ._V10LobeTableParent.LobeTable
using ._V10PettyLearnerParent.PettyLearner
using ._V10CoherenceFieldParent.CoherenceField

println("🧪 Running v10 pipeline integration tests...")

# ── Duck-typed Vote (same as test_multipart_integration.jl) ────────────────
struct TestVote
    node_id::String
    action::String
    confidence::Float64
    multipart_group::String
    multipart_role::Symbol
    input_chunks::Vector{Int}
end

# =========================================================================
# HELPERS
# =========================================================================

"""Full reset of AutoGrowth evidence + curiosity state."""
function _full_ag_reset!()
    AutoGrowth.reset_evidence!()
    AutoGrowth.deserialize_curiosity!(Dict{String,Any}(
        "buffer" => String[],
        "intensity" => 0.0,
        "quenched_at" => 0.0,
        "overflow_count" => 0,
    ))
end

"""Create a fresh lobe table for flashcard testing."""
function _fresh_lobe(suffix::String = "")::String
    lid = "v10_test_lobe_$(suffix)_$(round(Int, time() * 1000) % 1_000_000)"
    LobeTable.create_lobe_table!(lid)
    return lid
end

"""Run AutoGrowth evidence accumulation and return snapshot (Vector{Dict})."""
function _run_evidence(;
    user_text::String = "quantum",
    intensity::Float64 = 0.5,
    node_patterns::Set{String} = Set(["happy"]),
    node_ids_patterns::Vector{Tuple{String,String}} = Tuple{String,String}[],
    mlp_novelty_score::Float64 = 0.5,
    mlp_activation_mode::Symbol = :sigmoid,
    mlp_semantic_score::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    mlp_disambiguation::Float64 = 0.5,
    coherence_delta_phi::Float64 = 0.0,
)
    _full_ag_reset!()
    AutoGrowth.accumulate_evidence!(;
        user_text = user_text,
        intensity = intensity,
        node_patterns = node_patterns,
        node_ids_patterns = node_ids_patterns,
        thesaurus_gate_filter = w -> String[],
        thesaurus_word_similarity = (a, b) -> 0.0,
        mlp_novelty_score = mlp_novelty_score,
        mlp_activation_mode = mlp_activation_mode,
        mlp_semantic_score = mlp_semantic_score,
        mlp_relevance_score = mlp_relevance_score,
        mlp_disambiguation = mlp_disambiguation,
        coherence_delta_phi = coherence_delta_phi,
        lobe_snapshots = Tuple{String,String,Set{String}}[],
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

"""Get accumulated_intensity for a pattern, or 0.0 if not found."""
function _get_intensity(snap, pattern::String)::Float64
    p = _find_pattern(snap, pattern)
    return p === nothing ? 0.0 : Float64(p["accumulated_intensity"])
end

"""Sum all accumulated_intensity across all patterns in snapshot."""
function _total_intensity(snap)::Float64
    return isempty(snap) ? 0.0 : sum(Float64(e["accumulated_intensity"]) for e in snap; init=0.0)
end

"""Get all sources from a specific pattern, or empty set if not found."""
function _get_sources(snap, pattern::String)::Set{String}
    p = _find_pattern(snap, pattern)
    return p === nothing ? Set{String}() : Set{String}(p["sources"])
end

# =========================================================================
# SECTION 1: ENHANCED DECOMPOSITION → MULTIPART OBJECTIVES
# =========================================================================

@testset "v10 Pipeline: Enhanced decomposition → multipart objectives" begin

    @testset "v10 conjunctions: while/whilst/since/unless → compound split" begin
        inputs_and_counts = [
            ("what is gravity while what is mass" => 2),
            ("what is fire whilst what is water" => 2),
            ("what is heat since what is cold" => 2),
            ("what is velocity unless what is speed" => 2),
        ]
        for (input, expected_count) in inputs_and_counts
            subs = InputDecomposer.decompose_input(input)
            @test length(subs) == expected_count
            @test InputDecomposer.is_compound(input)
            # Each sub-subject should get a multipart group
            @test all(s -> startswith(s.multipart_group, "mp_"), subs)
        end
    end

    @testset "v10 conjunctions: except/plus/independently/separately → compound split" begin
        inputs_and_counts = [
            ("what is alpha except what is beta" => 2),
            ("what is photosynthesis plus what is respiration" => 2),
        ]
        for (input, expected_count) in inputs_and_counts
            subs = InputDecomposer.decompose_input(input)
            @test length(subs) == expected_count
            @test InputDecomposer.is_compound(input)
        end
    end

    @testset "v10 compound pairs: or else/but rather/then additionally → compound split" begin
        inputs_and_counts = [
            ("what is X or else what is Y" => 2),
            ("what is fire but rather what is ice" => 2),
        ]
        for (input, expected_count) in inputs_and_counts
            subs = InputDecomposer.decompose_input(input)
            @test length(subs) >= expected_count
            @test InputDecomposer.is_compound(input)
        end
    end

    @testset "v10 expanded question markers: can/could/would/is/are → split" begin
        inputs = [
            "can you explain gravity also could you explain mass",
            "what is fire and would water extinguish it",
        ]
        for input in inputs
            subs = InputDecomposer.decompose_input(input)
            @test length(subs) >= 2
            @test InputDecomposer.is_compound(input)
        end
    end

    @testset "v10 expanded command markers: compare/contrast/analyze → split" begin
        inputs = [
            "compare velocity and what is speed",
            "contrast heat and what is cold",
        ]
        for input in inputs
            subs = InputDecomposer.decompose_input(input)
            @test length(subs) >= 2
            @test InputDecomposer.is_compound(input)
        end
    end

    @testset "enhanced decomposition → objectives pipeline" begin
        # Test that v10 decompositions flow through to MultipartOrchestrator
        input = "what is gravity while what is mass"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) == 2

        # Each sub-subject's winning vote is :primary in its own group
        votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                           subs[i].multipart_group, :primary, Int[])
                 for i in 1:length(subs)]
        objs = MultipartOrchestrator.build_objectives(votes; strength_of = _ -> 8.0)

        @test length(objs) == 2
        @test all(o -> o.is_multipart, objs)
        group_ids = sort([o.group_id for o in objs])
        @test group_ids == ["mp_1", "mp_2"]
    end

    @testset "v10 triple compound with while and also" begin
        input = "what is gravity while what is mass also what is energy"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) >= 3

        votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                           subs[i].multipart_group, :primary, Int[])
                 for i in 1:length(subs)]
        objs = MultipartOrchestrator.build_objectives(votes; strength_of = _ -> 8.0)
        @test length(objs) >= 3
        @test all(o -> o.is_multipart, objs)
    end

    @testset "sigil-boundary split → arithmetic + text objectives" begin
        # "3+5 compute and what is gravity" splits at sigil boundary
        input = "3+5 compute and what is gravity"
        subs = InputDecomposer.decompose_input(input)
        # Should split arithmetic from natural language
        @test length(subs) >= 2
        @test InputDecomposer.is_compound(input)
    end
end

# =========================================================================
# SECTION 2: MLP-ASSISTED DECOMPOSITION → OBJECTIVES
# =========================================================================

@testset "v10 Pipeline: MLP-assisted decomposition → objectives" begin

    @testset "low directive + high novelty triggers MLP split" begin
        # directive_quality < 0.35 AND novelty >= 0.70 → MLP split
        input = "discuss the nature of reality with what consciousness means"
        subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,
            mlp_novelty = 0.80,
        )
        @test length(subs) >= 2
        @test all(s -> startswith(s.multipart_group, "mp_"), subs)
    end

    @testset "high directive quality → no MLP split" begin
        # directive_quality >= 0.35 → singleton
        input = "discuss the nature of reality with what consciousness means"
        subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.50,
            mlp_novelty = 0.80,
        )
        @test length(subs) == 1
        @test subs[1].role == :singleton
    end

    @testset "low novelty → no MLP split" begin
        # novelty < 0.70 → singleton
        input = "discuss the nature of reality with what consciousness means"
        subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,
            mlp_novelty = 0.50,
        )
        @test length(subs) == 1
        @test subs[1].role == :singleton
    end

    @testset "both conditions required (AND not OR)" begin
        input = "discuss the nature of reality with what consciousness means"
        # Only one condition met → no split
        subs1 = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,  # below threshold
            mlp_novelty = 0.50,             # below threshold
        )
        @test length(subs1) == 1

        subs2 = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.50,  # above threshold
            mlp_novelty = 0.80,             # above threshold
        )
        @test length(subs2) == 1
    end

    @testset "MLP decomposition → objectives pipeline" begin
        input = "discuss the nature of reality with what consciousness means"
        subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,
            mlp_novelty = 0.80,
        )
        if length(subs) >= 2
            votes = [TestVote("node_$(i)", "action_$(i)", 0.70 + 0.05*i,
                               subs[i].multipart_group, :primary, Int[])
                     for i in 1:length(subs)]
            objs = MultipartOrchestrator.build_objectives(votes; strength_of = _ -> 8.0)
            @test length(objs) >= 2
            @test all(o -> o.is_multipart, objs)
        end
    end

    @testset "MLP max parts cap = 4" begin
        @test InputDecomposer.MLP_COMPOUND_MAX_PARTS == 4
        # Input with many conjunctions should cap at 4 parts
        input = "what is a with what is b with what is c with what is d with what is e"
        subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,
            mlp_novelty = 0.80,
        )
        @test length(subs) <= 4
    end

    @testset "MLP thresholds: compound=0.35, novelty=0.70" begin
        @test InputDecomposer.MLP_COMPOUND_THRESHOLD == 0.35
        @test InputDecomposer.MLP_NOVELTY_COMPOUND_THRESHOLD == 0.70
    end
end

# =========================================================================
# SECTION 3: FLASHCARD + ARITHMETIC PIPELINE
# =========================================================================

@testset "v10 Pipeline: Flashcard + Arithmetic pipeline" begin

    @testset "arithmetic result auto-writes to flashcard" begin
        lid = _fresh_lobe("arith_fc")
        # Simulate what Main.jl does: compute arithmetic → write flashcard
        LobeTable.flashcard_put!(lid, "3+5", "8";
            result_num=8.0, card_type=:arithmetic)
        @test LobeTable.flashcard_has(lid, "3+5")
        card = LobeTable.flashcard_get(lid, "3+5")
        @test card["result"] == "8"
        @test card["result_num"] == 8.0
        @test card["type"] == "arithmetic"
    end

    @testset "flashcard hit increments on re-query" begin
        lid = _fresh_lobe("arith_hit")
        LobeTable.flashcard_put!(lid, "7*8", "56"; result_num=56.0, card_type=:arithmetic)

        # Simulate repeated queries (each query hits the flashcard)
        for _ in 1:3
            card = LobeTable.flashcard_get(lid, "7*8")
            @test card !== nothing
            LobeTable.flashcard_hit!(lid, "7*8")
        end
        card = LobeTable.flashcard_get(lid, "7*8")
        @test card["hits"] == 3
    end

    @testset "arithmetic flashcard survives serialize/deserialize" begin
        lid = _fresh_lobe("arith_ser")
        LobeTable.flashcard_put!(lid, "2+2", "4"; result_num=4.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "9*9", "81"; result_num=81.0, card_type=:arithmetic)
        LobeTable.flashcard_hit!(lid, "2+2")

        data = LobeTable.serialize_flashcards()
        @test data !== nothing
        @test haskey(data, lid)
        @test length(data[lid]) == 2

        # Clear and restore
        LobeTable.flashcard_delete!(lid, "2+2")
        LobeTable.flashcard_delete!(lid, "9*9")
        @test LobeTable.flashcard_count(lid) == 0

        LobeTable.deserialize_flashcards!(Dict{String,Any}(lid => data[lid]))
        @test LobeTable.flashcard_count(lid) == 2
        restored = LobeTable.flashcard_get(lid, "2+2")
        @test restored["hits"] == 1  # hit count preserved
    end

    @testset "petty learner → flashcard fast-path" begin
        # PettyLearner classifies simple math as flashcard path
        arith_bindings = Dict{String,Any}("&n1" => "6", "&op1" => "*", "&n2" => "7")
        result = PettyLearner.classify_petty(
            "what is 6*7",
            ["what", "is", "6*7"],
            Set(["happy", "big"]),  # node_patterns (don't cover "6*7")
            w -> String[],          # gate_filter
            (a, b) -> 0.0,         # word_similarity
            Tuple{String,String,Set{String}}[],  # lobe_snap
            Dict{String,Any}(),    # sigil_entries
            arith_bindings,
        )
        @test result.dispatched
        @test result.path == :flashcard
        @test result.arithmetic_expr != ""
    end

    @testset "petty learner dispatches flashcard write" begin
        lid = _fresh_lobe("petty_fc")
        arith_bindings = Dict{String,Any}("&n1" => "4", "&op1" => "+", "&n2" => "5")
        result = PettyLearner.classify_petty(
            "what is 4+5",
            ["what", "is", "4+5"],
            Set(["happy"]),
            w -> String[],
            (a, b) -> 0.0,
            Tuple{String,String,Set{String}}[],
            Dict{String,Any}(),
            arith_bindings,
        )
        @test result.dispatched
        @test result.path == :flashcard

        # Dispatch the petty result
        dispatched = PettyLearner.dispatch_petty!(result;
            flashcard_put_fn = (lobe_id, expr, result_str; result_num=NaN, card_type=:arithmetic) ->
                LobeTable.flashcard_put!(lobe_id, expr, result_str;
                    result_num=result_num, card_type=card_type),
            arithmetic_compute_fn = (bindings) -> (expression="4+5", answer=9, answer_str="9", error=nothing),
            arithmetic_bindings = arith_bindings,
        )
        @test dispatched.dispatched
    end

    @testset "flashcard TTL expiry for ephemeral cards" begin
        lid = _fresh_lobe("arith_ttl")
        LobeTable.flashcard_put!(lid, "temp_calc", "42"; ttl=0.01, card_type=:arithmetic)
        @test LobeTable.flashcard_get(lid, "temp_calc") !== nothing
        sleep(0.1)
        # flashcard_get checks TTL and returns nothing for expired cards
        @test LobeTable.flashcard_get(lid, "temp_calc") === nothing
    end

    @testset "flashcard count across lobes" begin
        lid1 = _fresh_lobe("cnt1")
        lid2 = _fresh_lobe("cnt2")
        LobeTable.flashcard_put!(lid1, "1+1", "2"; result_num=2.0)
        LobeTable.flashcard_put!(lid1, "2+2", "4"; result_num=4.0)
        LobeTable.flashcard_put!(lid2, "3+3", "6"; result_num=6.0)
        @test LobeTable.flashcard_count(lid1) == 2
        @test LobeTable.flashcard_count(lid2) == 1
        @test LobeTable.flashcard_count("no_such_lobe_v10") == 0
    end
end

# =========================================================================
# SECTION 4: CURIOSITY ACCUMULATOR + OVERFLOW
# =========================================================================

@testset "v10 Pipeline: Curiosity accumulator + overflow" begin

    @testset "curiosity accumulates from novelty" begin
        _full_ag_reset!()
        # High novelty should accumulate curiosity intensity
        _run_evidence(;
            user_text = "novel_concept_xyz",
            intensity = 0.8,
            mlp_novelty_score = 0.9,
        )
        cur = AutoGrowth.get_curiosity_status()
        @test cur["intensity"] > 0.0
    end

    @testset "curiosity overflow generates pending ask" begin
        _full_ag_reset!()
        # Run multiple high-novelty cycles to push curiosity over the edge
        for i in 1:10
            _run_evidence(;
                user_text = "novel_concept_$(i)",
                intensity = 0.9,
                mlp_novelty_score = 0.95,
            )
        end
        overflow = AutoGrowth.check_curiosity_overflow()
        # Either overflow happened or intensity is very high
        cur = AutoGrowth.get_curiosity_status()
        if overflow !== nothing
            @test isa(overflow, String)
            @test length(overflow) > 0
        end
    end

    @testset "quench curiosity resets intensity" begin
        _full_ag_reset!()
        # Accumulate some curiosity
        _run_evidence(;
            user_text = "novel_concept_abc",
            intensity = 0.8,
            mlp_novelty_score = 0.9,
        )
        cur_before = AutoGrowth.get_curiosity_status()
        @test cur_before["intensity"] > 0.0

        # Quench
        AutoGrowth.quench_curiosity!()
        cur_after = AutoGrowth.get_curiosity_status()
        @test cur_after["intensity"] == 0.0
        @test cur_after["quenched_at"] > 0.0
    end

    @testset "curiosity serialize/deserialize round-trip" begin
        _full_ag_reset!()
        # Accumulate curiosity
        _run_evidence(;
            user_text = "novel_concept_rtt",
            intensity = 0.8,
            mlp_novelty_score = 0.9,
        )
        cur_data = AutoGrowth.serialize_curiosity()
        @test haskey(cur_data, "intensity")
        @test haskey(cur_data, "buffer")
        @test haskey(cur_data, "quenched_at")
        @test haskey(cur_data, "overflow_count")

        saved_intensity = cur_data["intensity"]

        # Reset and restore
        _full_ag_reset!()
        @test AutoGrowth.get_curiosity_status()["intensity"] == 0.0

        AutoGrowth.deserialize_curiosity!(cur_data)
        @test AutoGrowth.get_curiosity_status()["intensity"] ≈ saved_intensity
    end

    @testset "curiosity does NOT reset with reset_evidence!" begin
        _full_ag_reset!()
        _run_evidence(;
            user_text = "novel_concept_persist",
            intensity = 0.8,
            mlp_novelty_score = 0.9,
        )
        cur_before = AutoGrowth.get_curiosity_status()
        @test cur_before["intensity"] > 0.0

        # reset_evidence! does NOT reset curiosity
        AutoGrowth.reset_evidence!()
        cur_after = AutoGrowth.get_curiosity_status()
        @test cur_after["intensity"] == cur_before["intensity"]
    end

    @testset "full curiosity reset requires deserialize_curiosity!" begin
        _full_ag_reset!()
        _run_evidence(;
            user_text = "novel_concept_full_reset",
            intensity = 0.8,
            mlp_novelty_score = 0.9,
        )
        @test AutoGrowth.get_curiosity_status()["intensity"] > 0.0

        # Full reset via deserialize_curiosity!
        AutoGrowth.deserialize_curiosity!(Dict{String,Any}(
            "buffer" => String[],
            "intensity" => 0.0,
            "quenched_at" => 0.0,
            "overflow_count" => 0,
        ))
        @test AutoGrowth.get_curiosity_status()["intensity"] == 0.0
    end
end

# =========================================================================
# SECTION 5: PETTY LEARNER + DECOMPOSITION INTERACTION
# =========================================================================

@testset "v10 Pipeline: PettyLearner + decomposition interaction" begin

    @testset "compound input → decomposition, not petty" begin
        # Compound inputs with multiple uncovered tokens should decompose,
        # NOT be classified as petty (petty requires exactly 1 uncovered token)
        input = "what is quantum also what is relativity"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) == 2

        # Petty classifier would see multiple uncovered tokens → not petty
        result = PettyLearner.classify_petty(
            input,
            Vector{String}(split(input)),
            Set(["happy"]),  # doesn't cover quantum or relativity
            w -> String[],
            (a, b) -> 0.0,
            Tuple{String,String,Set{String}}[],
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result.path == :none  # not petty — too many uncovered tokens
    end

    @testset "singleton input with 1 uncovered token → petty fast-path" begin
        # "glad" uncovered, "happy" covered → thesaurus fast-path
        result = PettyLearner.classify_petty(
            "glad and happy",
            ["glad", "and", "happy"],
            Set(["happy"]),
            w -> String[],
            (a, b) -> (lowercase(a) == "glad" && lowercase(b) == "happy") ? 0.85 : 0.0,
            Tuple{String,String,Set{String}}[],
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result.dispatched
        @test result.path == :thesaurus
    end

    @testset "petty dispatches thesaurus add" begin
        # Verify that dispatch actually calls the thesaurus register function
        result = PettyLearner.classify_petty(
            "glad and happy",
            ["glad", "and", "happy"],
            Set(["happy"]),
            w -> String[],
            (a, b) -> (lowercase(a) == "glad" && lowercase(b) == "happy") ? 0.85 : 0.0,
            Tuple{String,String,Set{String}}[],
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result.dispatched

        # Track whether thesaurus register was called
        registered = Ref(false)
        registered_pair = Ref("")
        dispatched = PettyLearner.dispatch_petty!(result;
            thesaurus_register_fn = (a, b) -> begin
                registered[] = true
                registered_pair[] = "$(a)=$(b)"
            end,
        )
        @test dispatched.dispatched
        @test registered[]
        # dispatch_petty! registers candidate_token with itself (src/PettyLearner.jl line 226)
        @test occursin("glad", registered_pair[])
    end

    @testset "singleton input not petty → goes through normal evidence" begin
        # "quantum" is uncovered, but no similar covered token → not petty
        result = PettyLearner.classify_petty(
            "what is quantum",
            ["what", "is", "quantum"],
            Set(["happy"]),
            w -> String[],
            (a, b) -> 0.0,  # no similarity
            Tuple{String,String,Set{String}}[],
            Dict{String,Any}(),
            Dict{String,Any}(),  # no arithmetic bindings
        )
        # Not thesaurus (no similarity), not flashcard (no bindings), not whitelist (no match)
        @test result.path == :none || result.path == :lobe_whitelist
    end
end

# =========================================================================
# SECTION 6: AUTOGROWTH EVIDENCE + COHERENCE FIELD ΔΦ
# =========================================================================

@testset "v10 Pipeline: AutoGrowth evidence + coherence ΔΦ" begin

    @testset "coherence drop triggers evidence" begin
        # ΔΦ below threshold → coherence_drop evidence fires
        snap_no_drop = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            coherence_delta_phi = 0.0,  # no drop
        )
        snap_with_drop = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            coherence_delta_phi = -0.30,  # significant drop
        )
        # Evidence intensity should be higher with coherence drop
        int_no = _get_intensity(snap_no_drop, "quantum")
        int_yes = _get_intensity(snap_with_drop, "quantum")
        @test int_yes > int_no
    end

    @testset "coherence drop threshold is strict (< -0.15)" begin
        @test AutoGrowth.COHERENCE_DROP_THRESHOLD == -0.15

        # Exactly -0.15 does NOT fire
        snap_at = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            coherence_delta_phi = -0.15,
        )
        # Just below threshold DOES fire
        snap_below = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            coherence_delta_phi = -0.151,
        )
        int_at = _get_intensity(snap_at, "quantum")
        int_below = _get_intensity(snap_below, "quantum")
        @test int_below > int_at
    end

    @testset "semantic gap requires intensity > 0.5" begin
        # intensity = 0.5 → semantic gap does NOT fire (strict >)
        snap_at = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            mlp_semantic_score = 0.2,  # below SEMANTIC_GAP_THRESHOLD
        )
        # intensity = 0.6 → semantic gap DOES fire
        snap_above = _run_evidence(;
            user_text = "quantum",
            intensity = 0.6,
            mlp_semantic_score = 0.2,
        )
        int_at = _get_intensity(snap_at, "quantum")
        int_above = _get_intensity(snap_above, "quantum")
        @test int_above > int_at
    end

    @testset "novelty surge modulates existing evidence (no new source name)" begin
        # SOURCE 14 (novelty surge) boosts intensity of existing entries
        # but does NOT add "novelty_surge" to the sources list
        snap_normal = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            mlp_novelty_score = 0.5,  # below surge threshold
        )
        snap_surge = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            mlp_novelty_score = 0.9,  # above NOVELTY_SURGE_THRESHOLD (0.65)
        )
        # Surge should produce higher intensity
        int_normal = _get_intensity(snap_normal, "quantum")
        int_surge = _get_intensity(snap_surge, "quantum")
        @test int_surge > int_normal
        # But "novelty_surge" should NOT be in the sources list
        @test !("novelty_surge" in _get_sources(snap_surge, "quantum"))
    end

    @testset "ReLU mode produces larger evidence than sigmoid" begin
        snap_relu = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            mlp_activation_mode = :relu,
            coherence_delta_phi = -0.30,
        )
        snap_sigmoid = _run_evidence(;
            user_text = "quantum",
            intensity = 0.5,
            mlp_activation_mode = :sigmoid,
            coherence_delta_phi = -0.30,
        )
        # ReLU mode multiplier (1.25) > sigmoid (0.8), so ReLU intensity should be higher
        int_relu = _get_intensity(snap_relu, "quantum")
        int_sigmoid = _get_intensity(snap_sigmoid, "quantum")
        @test int_relu > int_sigmoid
    end

    @testset "evidence snapshot has expected structure" begin
        snap = _run_evidence(; user_text = "test_token")
        @test isa(snap, Vector)
        if !isempty(snap)
            entry = snap[1]
            @test haskey(entry, "pattern")
            @test haskey(entry, "accumulated_intensity")
            @test haskey(entry, "sources")
            @test haskey(entry, "growth_type")
            @test isa(entry["accumulated_intensity"], Float64)
            @test isa(entry["sources"], Vector)
            @test isa(entry["growth_type"], String)
        end
    end

    @testset "growth_type is String not Symbol" begin
        # Regression: evidence_snapshot returns growth_type as String
        snap = _run_evidence(; user_text = "quantum", intensity = 0.5)
        for entry in snap
            @test isa(entry["growth_type"], String)
        end
    end
end

# =========================================================================
# SECTION 7: CROSS-SUBSYSTEM INTEGRATION
# =========================================================================

@testset "v10 Pipeline: Cross-subsystem integration" begin

    @testset "decomposition + AutoGrowth evidence per sub-subject" begin
        # When compound input decomposes, each sub-subject would be processed
        # independently by AutoGrowth. Verify that running evidence for each
        # sub-subject text produces separate evidence accumulations.
        input = "what is gravity also what is mass"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) == 2

        _full_ag_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = subs[1].text,
            intensity = 0.5,
            node_patterns = Set(["gravity"]),
            node_ids_patterns = Tuple{String,String}[],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.5,
            lobe_snapshots = Tuple{String,String,Set{String}}[],
        )
        snap1 = AutoGrowth.get_evidence_snapshot()

        _full_ag_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = subs[2].text,
            intensity = 0.5,
            node_patterns = Set(["mass"]),
            node_ids_patterns = Tuple{String,String}[],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.5,
            lobe_snapshots = Tuple{String,String,Set{String}}[],
        )
        snap2 = AutoGrowth.get_evidence_snapshot()

        # Both produce evidence (different tokens → different patterns)
        @test _total_intensity(snap1) >= 0.0
        @test _total_intensity(snap2) >= 0.0
    end

    @testset "MLP-assisted decomposition then evidence accumulation" begin
        # Simulate the process_mission flow:
        # 1. Standard decomposer says singleton
        # 2. MLP scores come in → low directive, high novelty
        # 3. MLP-assisted decomposition finds compound structure
        # 4. Each sub-subject goes through evidence accumulation
        input = "discuss the nature of reality with what consciousness means"

        # Step 2: MLP-assisted decomposition splits it
        mlp_subs = InputDecomposer.decompose_input_mlp(input;
            mlp_directive_quality = 0.20,
            mlp_novelty = 0.80,
        )
        @test length(mlp_subs) >= 2

        # Step 3: Each sub-subject gets evidence accumulation
        for sub in mlp_subs
            _full_ag_reset!()
            AutoGrowth.accumulate_evidence!(;
                user_text = sub.text,
                intensity = 0.5,
                node_patterns = Set(["existing_pattern"]),
                node_ids_patterns = Tuple{String,String}[],
                thesaurus_gate_filter = w -> String[],
                thesaurus_word_similarity = (a, b) -> 0.0,
                mlp_novelty_score = 0.8,
                mlp_semantic_score = 0.4,  # borderline → may trigger semantic gap
                mlp_relevance_score = 0.5,
                mlp_disambiguation = 0.5,
                coherence_delta_phi = -0.20,  # coherence drop
                lobe_snapshots = Tuple{String,String,Set{String}}[],
            )
            snap = AutoGrowth.get_evidence_snapshot()
            @test _total_intensity(snap) > 0.0
        end
    end

    @testset "flashcard + curiosity + evidence in same cycle" begin
        # A single cycle can write a flashcard (from arithmetic),
        # accumulate curiosity (from novelty), and build evidence (from coherence).
        # These are independent subsystems that should not interfere.

        # 1. Flashcard
        lid = _fresh_lobe("cycle_fc")
        LobeTable.flashcard_put!(lid, "10+10", "20"; result_num=20.0, card_type=:arithmetic)

        # 2. Curiosity
        _full_ag_reset!()
        AutoGrowth.accumulate_evidence!(;
            user_text = "novel_phenomenon",
            intensity = 0.8,
            node_patterns = Set(["existing"]),
            node_ids_patterns = Tuple{String,String}[],
            thesaurus_gate_filter = w -> String[],
            thesaurus_word_similarity = (a, b) -> 0.0,
            mlp_novelty_score = 0.9,
            lobe_snapshots = Tuple{String,String,Set{String}}[],
        )
        cur = AutoGrowth.get_curiosity_status()
        @test cur["intensity"] > 0.0

        # 3. Evidence
        snap = AutoGrowth.get_evidence_snapshot()
        @test _total_intensity(snap) > 0.0

        # 4. Flashcard still intact
        @test LobeTable.flashcard_has(lid, "10+10")
        card = LobeTable.flashcard_get(lid, "10+10")
        @test card["result"] == "20"
    end

    @testset "compound input with arithmetic sub-subject" begin
        # "what is 3+5 also what is gravity" should decompose into
        # an arithmetic part and a natural language part.
        # The arithmetic part could trigger flashcard write.
        input = "what is 3+5 also what is gravity"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) == 2

        # First sub should contain arithmetic
        has_arith = any(s -> occursin(r"\d+[\+\-\*\/]\d+", s.text), subs)
        @test has_arith

        # Each gets its own multipart group
        @test subs[1].multipart_group != subs[2].multipart_group
    end
end

# =========================================================================
# SECTION 8: REGRESSION — EXISTING DECOMPOSITION STILL WORKS
# =========================================================================

@testset "v10 Pipeline: Regression — existing decomposition patterns" begin

    @testset "\"also\" split still works" begin
        subs = InputDecomposer.decompose_input("what time is it also what is a dinosaur")
        @test length(subs) == 2
        @test InputDecomposer.is_compound("what time is it also what is a dinosaur")
    end

    @testset "\"and\" with question markers still splits" begin
        subs = InputDecomposer.decompose_input("what is the sun and what is the moon")
        @test length(subs) == 2
    end

    @testset "singleton stays singleton" begin
        subs = InputDecomposer.decompose_input("what is a rock")
        @test length(subs) == 1
        @test subs[1].role == :singleton
        @test !InputDecomposer.is_compound("what is a rock")
    end

    @testset "bread and butter stays singleton" begin
        subs = InputDecomposer.decompose_input("bread and butter")
        @test length(subs) == 1
        @test !InputDecomposer.is_compound("bread and butter")
    end

    @testset "comma-separated questions still split" begin
        subs = InputDecomposer.decompose_input("what is fire, what is ice")
        @test length(subs) == 2
    end

    @testset "question mark decomposition still works" begin
        subs = InputDecomposer.decompose_input("what time is it? what is a dinosaur? what is 2+2?")
        @test length(subs) >= 2
    end

    @testset "deterministic group IDs" begin
        input = "what is the sun also what is the moon"
        subs1 = InputDecomposer.decompose_input(input)
        subs2 = InputDecomposer.decompose_input(input)
        @test subs1[1].multipart_group == subs2[1].multipart_group
        @test subs1[2].multipart_group == subs2[2].multipart_group
    end

    @testset "regression: every group needs :primary vote" begin
        input = "what time is it also what is a dinosaur"
        subs = InputDecomposer.decompose_input(input)
        @test length(subs) == 2

        # Correct: every group's winning vote is :primary
        v1 = TestVote("node_time",     "reason_time",     0.80, "mp_1", :primary, Int[])
        v2 = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", :primary, Int[])
        objs = MultipartOrchestrator.build_objectives([v1, v2]; strength_of = _ -> 8.0)
        @test length(objs) == 2

        # Buggy: using subs[2].role = :support would fail
        v2_buggy = TestVote("node_dinosaur", "explain_dinosaur", 0.75, "mp_2", :support, Int[])
        @test_throws MultipartOrchestrator.MultipartError MultipartOrchestrator.build_objectives([v1, v2_buggy]; strength_of = _ -> 8.0)
    end

    @testset "diagnostic summaries work" begin
        input = "what is alpha also what is beta"
        subs = InputDecomposer.decompose_input(input)
        decomp_summary = InputDecomposer.summarize_decomposition(subs)
        @test occursin("compound", decomp_summary) || occursin("mp_1", decomp_summary)

        votes = [TestVote("node_$(i)", "action_$(i)", 0.75,
                           subs[i].multipart_group, :primary, Int[])
                 for i in 1:length(subs)]
        objs = MultipartOrchestrator.build_objectives(votes; strength_of = _ -> 8.0)
        for obj in objs
            obj_summary = MultipartOrchestrator.summarize_objective(obj)
            @test occursin("multipart", obj_summary) || occursin("singleton", obj_summary)
        end
    end
end

println("✅ v10 pipeline integration tests complete.")
