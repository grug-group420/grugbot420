# test_context_polarity.jl
# GRUG: Test the context polarity gate — SelfObserver pre/post vote observations
# and the _sigil_suppressed_by_polarity gate.
#
# Three test cases:
#   1. "don't calculate 2+2"  → math suppressed (explicit negation)
#   2. "easy as 2+2"          → math suppressed (figurative dismiss)
#   3. "what is 2+2"          → math fires normally

using Test

# ── Load the module ──
using GrugBot420
using GrugBot420.SelfObserver
using GrugBot420.ActionTonePredictor
using GrugBot420.SemanticVerbs

@testset "Context Polarity Gate" begin

    # ── Reset state between tests ──
    GrugBot420._CURRENT_PREDICTION[] = nothing
    SelfObserver.drop_store!(SelfObserver.default_store())

    @testset "ATP figurative dismiss detection" begin
        pred = ActionTonePredictor.predict_action_tone("easy as 2+2", SemanticVerbs.get_all_verbs())
        @test pred.figurative_dismiss === true
        @test pred.negation_strength > 0.0
        @info "[TEST] ✅ 'easy as 2+2' → figurative_dismiss=$(pred.figurative_dismiss), neg_strength=$(pred.negation_strength)"
    end

    @testset "ATP explicit negation detection" begin
        pred = ActionTonePredictor.predict_action_tone("don't calculate 2+2", SemanticVerbs.get_all_verbs())
        @test pred.action_family === ActionTonePredictor.ACTION_NEGATE
        @test pred.negation_strength > 0.5
        @info "[TEST] ✅ 'don't calculate 2+2' → action_family=$(pred.action_family), neg_strength=$(pred.negation_strength)"
    end

    @testset "ATP normal query — no suppression signals" begin
        pred = ActionTonePredictor.predict_action_tone("what is 2+2", SemanticVerbs.get_all_verbs())
        @test pred.figurative_dismiss === false
        # Should NOT be a strong negation
        gate_would_suppress = (pred.action_family === ActionTonePredictor.ACTION_NEGATE && pred.negation_strength > 0.5) || pred.figurative_dismiss
        @test gate_would_suppress === false
        @info "[TEST] ✅ 'what is 2+2' → figurative_dismiss=$(pred.figurative_dismiss), action_family=$(pred.action_family), neg_strength=$(pred.negation_strength)"
    end

    @testset "Gate: figurative dismiss suppresses :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("easy as 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._sigil_suppressed_by_polarity(:math) === true
        @test GrugBot420._sigil_suppressed_by_polarity(:doaction) === true
        @test GrugBot420._sigil_suppressed_by_polarity(:multipart) === false
        @test GrugBot420._sigil_suppressed_by_polarity(:instruction) === false
        @info "[TEST] ✅ Figurative dismiss suppresses :math and :doaction, not :multipart/:instruction"
    end

    @testset "Gate: explicit negation suppresses :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("don't calculate 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._sigil_suppressed_by_polarity(:math) === true
        @test GrugBot420._sigil_suppressed_by_polarity(:doaction) === true
        @info "[TEST] ✅ Explicit negation suppresses :math and :doaction"
    end

    @testset "Gate: normal query does NOT suppress :math" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        pred = ActionTonePredictor.predict_action_tone("what is 2+2", SemanticVerbs.get_all_verbs())
        GrugBot420._CURRENT_PREDICTION[] = pred
        @test GrugBot420._sigil_suppressed_by_polarity(:math) === false
        @test GrugBot420._sigil_suppressed_by_polarity(:doaction) === false
        @info "[TEST] ✅ Normal query does NOT suppress :math or :doaction"
    end

    @testset "Gate: no prediction → gate is open" begin
        GrugBot420._CURRENT_PREDICTION[] = nothing
        @test GrugBot420._sigil_suppressed_by_polarity(:math) === false
        @test GrugBot420._sigil_suppressed_by_polarity(:doaction) === false
        @info "[TEST] ✅ No prediction → gate is open (no suppression)"
    end

    @testset "SelfObserver pre-vote observation" begin
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
                "negation_strength" => 1.2,
                "input_preview"     => "easy as 2+2",
            );
            p_write    = 1.0,
            salience   = 7.0,
            provenance = :atp_pre_vote,
        )
        @test wrote === true

        # peek_exact takes (store, node_id, key) — node_id is typically
        # a dash-separated entity id; for tests we use a dummy.
        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_pre_vote_test1")
        @test fragments !== nothing
        @test length(fragments) >= 1
        f = fragments[1]
        @test f.tag === :context_polarity
        @test f.payload_strings["phase"] == "pre_vote"
        @test f.payload_strings["figurative_dismiss"] == "true"
        @info "[TEST] ✅ SelfObserver pre-vote observation written and retrieved"
    end

    @testset "SelfObserver post-vote observation (suppressed)" begin
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
                "opener"       => "observe",
                "conf"         => 0.24,
                "objective_id" => "obj_001",
            );
            p_write    = 1.0,
            salience   = 6.0,
            provenance = :polarity_gate_suppressed,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_post_vote_test1")
        @test fragments !== nothing
        @test length(fragments) >= 1
        @test fragments[1].payload_strings["outcome"] == "suppressed"
        @info "[TEST] ✅ SelfObserver post-vote suppressed observation written and retrieved"
    end

    @testset "SelfObserver post-vote observation (fired)" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        wrote = SelfObserver.observe!(
            SelfObserver.default_store(),
            "polarity_post_vote_test2",
            :context_polarity,
            Dict{String,Any}(
                "phase"        => "post_vote",
                "node_id"      => "test_math_node",
                "sigil_kind"   => "math",
                "outcome"      => "fired",
                "n_votes"      => 2,
                "objective_id" => "obj_002",
            );
            p_write    = 1.0,
            salience   = 5.0,
            provenance = :polarity_gate_fired,
        )
        @test wrote === true

        fragments = SelfObserver.peek_exact(SelfObserver.default_store(), "test-node", "polarity_post_vote_test2")
        @test fragments !== nothing
        @test length(fragments) >= 1
        @test fragments[1].payload_strings["outcome"] == "fired"
        @info "[TEST] ✅ SelfObserver post-vote fired observation written and retrieved"
    end

    @testset "SelfObserver :context_polarity tag is valid" begin
        @test :context_polarity in SelfObserver.VALID_TAGS
        @info "[TEST] ✅ :context_polarity is in SelfObserver.VALID_TAGS"
    end

    @testset "SelfObserver peek_pattern for context_polarity" begin
        SelfObserver.drop_store!(SelfObserver.default_store())

        SelfObserver.observe!(SelfObserver.default_store(), "polarity_entry_1", :context_polarity,
            Dict{String,Any}("phase" => "pre_vote", "figurative_dismiss" => true);
            p_write=1.0, salience=7.0, provenance=:test)
        SelfObserver.observe!(SelfObserver.default_store(), "polarity_entry_2", :context_polarity,
            Dict{String,Any}("phase" => "post_vote", "outcome" => "suppressed");
            p_write=1.0, salience=6.0, provenance=:test)
        SelfObserver.observe!(SelfObserver.default_store(), "other_entry_1", :mood,
            Dict{String,Any}("mood" => "curious");
            p_write=1.0, salience=5.0, provenance=:test)

        # peek_pattern takes (store, node_id, query_string; tag=...)
        # Query "polarity" should match keys containing "polarity"
        results = SelfObserver.peek_pattern(SelfObserver.default_store(), "test-node", "polarity";
            tag=:context_polarity)
        @test results !== nothing
        @test length(results) == 2
        @test all(f -> f.tag === :context_polarity, results)
        @info "[TEST] ✅ SelfObserver peek_pattern(tag=:context_polarity) returns only polarity entries"
    end

    # Clean up
    GrugBot420._CURRENT_PREDICTION[] = nothing
end

@info "[TEST] ══════════════════════════════════════════"
@info "[TEST] All context polarity gate tests completed!"
@info "[TEST] ══════════════════════════════════════════"
