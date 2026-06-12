# test_context_polarity.jl
# GRUG v7.32: Test the context polarity gate — tri-state NEGATIVE/NEUTRAL/POSITIVE
# with SelfObserver pre/post vote observations.
#
# Test cases:
#   1. "don't calculate 2+2"  → NEGATIVE polarity (explicit negation) → suppressed
#   2. "easy as 2+2"          → NEGATIVE polarity (figurative dismiss) → suppressed
#   3. "maybe calculate 2+2"  → NEUTRAL polarity (speculative) → attenuated (0.7x)
#   4. "what is 2+2"          → POSITIVE polarity (query) → fires normally (1.0x)
#   5. "calculate 3*4"        → POSITIVE polarity (assert + neutral tone) → fires normally

using Test

using GrugBot420
using GrugBot420.SelfObserver
using GrugBot420.ActionTonePredictor
using GrugBot420.SemanticVerbs

@testset "Context Polarity Gate — Tri-State" begin

    GrugBot420._CURRENT_PREDICTION[] = nothing
    SelfObserver.drop_store!(SelfObserver.default_store())

    # ── ATP polarity computation ──

    @testset "ATP: figurative dismiss → NEGATIVE" begin
        pred = ActionTonePredictor.predict_action_tone("easy as 2+2", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_NEGATIVE
        @test pred.figurative_dismiss === true
        @test pred.negation_strength > 0.0
        @info "[TEST] ✅ 'easy as 2+2' → POLARITY_NEGATIVE"
    end

    @testset "ATP: explicit negation → NEGATIVE" begin
        pred = ActionTonePredictor.predict_action_tone("don't calculate 2+2", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_NEGATIVE
        @test pred.action_family === ACTION_NEGATE
        @test pred.negation_strength > 0.5
        @info "[TEST] ✅ 'don't calculate 2+2' → POLARITY_NEGATIVE"
    end

    @testset "ATP: speculative → NEUTRAL" begin
        pred = ActionTonePredictor.predict_action_tone("maybe calculate 2+2", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_NEUTRAL
        @test pred.action_family === ACTION_SPECULATE
        @info "[TEST] ✅ 'maybe calculate 2+2' → POLARITY_NEUTRAL"
    end

    @testset "ATP: assert + reflective tone → NEUTRAL" begin
        pred = ActionTonePredictor.predict_action_tone("I think 2+2 equals 4", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_NEUTRAL
        @info "[TEST] ✅ 'I think 2+2 equals 4' → POLARITY_NEUTRAL"
    end

    @testset "ATP: query → POSITIVE" begin
        pred = ActionTonePredictor.predict_action_tone("what is 2+2", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_POSITIVE
        @test pred.action_family === ACTION_QUERY
        @info "[TEST] ✅ 'what is 2+2' → POLARITY_POSITIVE"
    end

    @testset "ATP: assert + neutral tone → POSITIVE" begin
        pred = ActionTonePredictor.predict_action_tone("calculate 3*4", SemanticVerbs.get_all_verbs())
        @test pred.context_polarity === POLARITY_POSITIVE
        @info "[TEST] ✅ 'calculate 3*4' → POLARITY_POSITIVE"
    end

    # ── Gate: _context_polarity_for ──

    @testset "Gate: figurative dismiss → NEGATIVE for :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("easy as 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._context_polarity_for(:math) === POLARITY_NEGATIVE
        @test GrugBot420._context_polarity_for(:doaction) === POLARITY_NEGATIVE
        @test GrugBot420._context_polarity_for(:multipart) === POLARITY_POSITIVE
        @test GrugBot420._context_polarity_for(:instruction) === POLARITY_POSITIVE
        @info "[TEST] ✅ Figurative dismiss → NEGATIVE for :math/:doaction, POSITIVE for :multipart/:instruction"
    end

    @testset "Gate: explicit negation → NEGATIVE for :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("don't calculate 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._context_polarity_for(:math) === POLARITY_NEGATIVE
        @test GrugBot420._context_polarity_for(:doaction) === POLARITY_NEGATIVE
        @info "[TEST] ✅ Explicit negation → NEGATIVE for :math/:doaction"
    end

    @testset "Gate: speculative → NEUTRAL for :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("maybe calculate 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._context_polarity_for(:math) === POLARITY_NEUTRAL
        @test GrugBot420._context_polarity_for(:doaction) === POLARITY_NEUTRAL
        @test GrugBot420._context_polarity_for(:multipart) === POLARITY_POSITIVE
        @info "[TEST] ✅ Speculative → NEUTRAL for :math/:doaction, POSITIVE for :multipart"
    end

    @testset "Gate: normal query → POSITIVE" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("what is 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._context_polarity_for(:math) === POLARITY_POSITIVE
        @test GrugBot420._context_polarity_for(:doaction) === POLARITY_POSITIVE
        @info "[TEST] ✅ Normal query → POSITIVE"
    end

    @testset "Gate: no prediction → POSITIVE (gate open)" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        @test GrugBot420._context_polarity_for(:math) === POLARITY_POSITIVE
        @test GrugBot420._context_polarity_for(:doaction) === POLARITY_POSITIVE
        @info "[TEST] ✅ No prediction → POSITIVE (gate open)"
    end

    # ── SelfObserver integration ──

    @testset "SelfObserver :context_polarity tag is valid" begin
        @test :context_polarity in SelfObserver.VALID_TAGS
        @info "[TEST] ✅ :context_polarity is in SelfObserver.VALID_TAGS"
    end

    @testset "SelfObserver pre-vote observation with polarity" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        wrote = SelfObserver.observe!(
            SelfObserver.default_store(),
            "polarity_pre_vote_test1",
            :context_polarity,
            Dict{String,Any}(
                "phase"             => "pre_vote",
                "input_hash"        => hash("easy as 2+2"),
                "action_family"     => "ACTION_NEGATE",
                "figurative_dismiss"=> true,
                "negation_strength" => 1.75,
                "polarity"          => "negative",
                "input_preview"     => "easy as 2+2",
            );
            p_write    = 1.0,
            salience   = 7.0,
            provenance = :atp_pre_vote,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_pre_vote_test1")
        @test fragments !== nothing
        @test length(fragments) >= 1
        f = fragments[1]
        @test f.tag === :context_polarity
        @test f.payload_strings["phase"] == "pre_vote"
        @test f.payload_strings["polarity"] == "negative"
        @test f.payload_strings["figurative_dismiss"] == "true"
        @info "[TEST] ✅ SelfObserver pre-vote observation with polarity written and retrieved"
    end

    @testset "SelfObserver post-vote: negative (suppressed)" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        wrote = SelfObserver.observe!(
            SelfObserver.default_store(),
            "polarity_post_vote_test1",
            :context_polarity,
            Dict{String,Any}(
                "phase"        => "post_vote",
                "node_id"      => "test_math_node",
                "sigil_kind"   => "math",
                "outcome"      => "suppressed",
                "polarity"     => "negative",
                "opener"       => "observe",
                "conf"         => 0.24,
                "objective_id" => "obj_001",
            );
            p_write    = 1.0,
            salience   = 6.0,
            provenance = :polarity_gate_negative,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_post_vote_test1")
        @test fragments !== nothing
        @test fragments[1].payload_strings["outcome"] == "suppressed"
        @test fragments[1].payload_strings["polarity"] == "negative"
        @info "[TEST] ✅ SelfObserver post-vote negative (suppressed) observation written"
    end

    @testset "SelfObserver post-vote: neutral (attenuated)" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        wrote = SelfObserver.observe!(
            SelfObserver.default_store(),
            "polarity_post_vote_test2",
            :context_polarity,
            Dict{String,Any}(
                "phase"        => "post_vote",
                "node_id"      => "test_math_node",
                "sigil_kind"   => "math",
                "outcome"      => "attenuated",
                "polarity"     => "neutral",
                "n_votes"      => 1,
                "objective_id" => "obj_002",
            );
            p_write    = 1.0,
            salience   = 5.0,
            provenance = :polarity_gate_fired,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_post_vote_test2")
        @test fragments !== nothing
        @test fragments[1].payload_strings["outcome"] == "attenuated"
        @test fragments[1].payload_strings["polarity"] == "neutral"
        @info "[TEST] ✅ SelfObserver post-vote neutral (attenuated) observation written"
    end

    @testset "SelfObserver post-vote: positive (fired normally)" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        wrote = SelfObserver.observe!(
            SelfObserver.default_store(),
            "polarity_post_vote_test3",
            :context_polarity,
            Dict{String,Any}(
                "phase"        => "post_vote",
                "node_id"      => "test_math_node",
                "sigil_kind"   => "math",
                "outcome"      => "fired",
                "polarity"     => "positive",
                "n_votes"      => 2,
                "objective_id" => "obj_003",
            );
            p_write    = 1.0,
            salience   = 5.0,
            provenance = :polarity_gate_fired,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_post_vote_test3")
        @test fragments !== nothing
        @test fragments[1].payload_strings["outcome"] == "fired"
        @test fragments[1].payload_strings["polarity"] == "positive"
        @info "[TEST] ✅ SelfObserver post-vote positive (fired) observation written"
    end

    @testset "SelfObserver peek_pattern for context_polarity" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        SelfObserver.observe!(SelfObserver.default_store(), "polarity_entry_1", :context_polarity,
            Dict{String,Any}("phase" => "pre_vote", "polarity" => "negative");
            p_write=1.0, salience=7.0, provenance=:test)
        SelfObserver.observe!(SelfObserver.default_store(), "polarity_entry_2", :context_polarity,
            Dict{String,Any}("phase" => "post_vote", "polarity" => "neutral");
            p_write=1.0, salience=6.0, provenance=:test)
        SelfObserver.observe!(SelfObserver.default_store(), "other_entry_1", :mood,
            Dict{String,Any}("mood" => "curious");
            p_write=1.0, salience=5.0, provenance=:test)

        results = SelfObserver.peek_pattern(SelfObserver.default_store(), "test-node", "polarity";
            tag=:context_polarity)
        @test results !== nothing
        @test length(results) == 2
        @test all(f -> f.tag === :context_polarity, results)
        @info "[TEST] ✅ SelfObserver peek_pattern(tag=:context_polarity) returns only polarity entries"
    end

    # Clean up
    GrugBot420._CURRENT_PREDICTION[] = nothing
    GrugBot420._ATTENUATED_FIRE[] = false
end

@info "[TEST] ══════════════════════════════════════════"
@info "[TEST] All context polarity gate tests completed!"
@info "[TEST] ══════════════════════════════════════════"
