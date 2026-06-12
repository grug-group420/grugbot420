# test_multipart_coherence_v722.jl
# ==============================================================================
# GRUG v7.22 — Focused test for multipart coherence gate regression.
# Verifies that:
#   1. MultipartOrchestrator._infer_scoped_mission() correctly maps
#      objective_id to clause text via the reverse lookup.
#   2. Knowledge groups in multipart inputs are NOT incorrectly skipped
#      by the coherence gate.
#   3. Math answers remain clean for deterministic single-clause inputs.
#   4. Multiple clauses each get their own scoped_mission (no bleed).
# ==============================================================================

using Test
using JSON

using GrugBot420
const GB = GrugBot420

using GrugBot420.MultipartOrchestrator
using GrugBot420.InputDecomposer

println("\n" * "="^60)
println("GRUG v7.22 — MULTIPART COHERENCE GATE TEST")
println("="^60)

@testset "v7.22 Multipart Coherence" begin

    # =========================================================================
    @testset "1. Reverse lookup: objective_id → clause text" begin
        # Populate the global mapping
        clause_text_1 = "what is 3 times 4"
        clause_text_2 = "what is the sky"
        obj_id_1 = GB.fresh_objective_id()
        obj_id_2 = GB.fresh_objective_id()

        lock(GB._CURRENT_CLAUSE_OBJ_IDS_LOCK) do
            empty!(GB._CURRENT_CLAUSE_OBJ_IDS)
            GB._CURRENT_CLAUSE_OBJ_IDS[clause_text_1] = obj_id_1
            GB._CURRENT_CLAUSE_OBJ_IDS[clause_text_2] = obj_id_2
        end

        # Create mock votes with these objective_ids
        # Group 1: math group
        math_vote = GB.Vote("node_math", "reason", 0.9, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "3 times 4 equals 12", obj_id_1, :final)
        # Group 2: knowledge group (no companion payload — this was the bug trigger)
        knowledge_vote = GB.Vote("node_knowledge", "describe", 0.7, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "", obj_id_2, :companion)

        # Test: _infer_scoped_mission for the knowledge group
        # Should return "what is the sky" via the reverse lookup, NOT "describe"
        clauses = InputDecomposer.decompose("what is 3 times 4 and what is the sky")
        scoped = MultipartOrchestrator._infer_scoped_mission([knowledge_vote], clauses, GB._CURRENT_CLAUSE_OBJ_IDS)

        @test occursin("sky", lowercase(scoped))
        @test scoped != "describe"

        # Test: _infer_scoped_mission for the math group
        scoped_math = MultipartOrchestrator._infer_scoped_mission([math_vote], clauses, GB._CURRENT_CLAUSE_OBJ_IDS)
        @test occursin("3", lowercase(scoped_math))

        # Clean up
        lock(GB._CURRENT_CLAUSE_OBJ_IDS_LOCK) do
            empty!(GB._CURRENT_CLAUSE_OBJ_IDS)
        end
    end

    # =========================================================================
    @testset "2. Full orchestrate_multipart with clause_obj_ids" begin
        # Decompose a multipart input
        mission = "what is 3 times 4 and what is the sky"
        clauses = InputDecomposer.decompose(mission)
        @test length(clauses) >= 2

        # Create per-clause objective_ids
        clause_obj_ids = Dict{String, UInt64}()
        for cl in clauses
            clause_obj_ids[cl.text] = GB.fresh_objective_id()
        end

        # Populate the global mapping too
        lock(GB._CURRENT_CLAUSE_OBJ_IDS_LOCK) do
            empty!(GB._CURRENT_CLAUSE_OBJ_IDS)
            merge!(GB._CURRENT_CLAUSE_OBJ_IDS, clause_obj_ids)
        end

        # Create mock votes: one for each clause
        math_obj_id = clause_obj_ids[clauses[1].text]
        sky_obj_id = length(clauses) >= 2 ? clause_obj_ids[clauses[2].text] : GB.fresh_objective_id()

        math_vote = GB.Vote("node_math", "reason", 0.9, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "3 times 4 equals 12", math_obj_id, :final)
        sky_vote = GB.Vote("node_sky", "describe", 0.7, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "", sky_obj_id, :companion)

        # Run orchestrate_multipart WITH clause_obj_ids
        result = MultipartOrchestrator.orchestrate_multipart([math_vote, sky_vote], clauses, clause_obj_ids)

        @test length(result.groups) == 2

        # Check each group's scoped_mission
        for grp in result.groups
            if grp.objective_id == math_obj_id
                @test occursin("3", lowercase(grp.scoped_mission))
                @test grp.is_math
            elseif grp.objective_id == sky_obj_id
                @test occursin("sky", lowercase(grp.scoped_mission))
                @test !grp.is_math
            end
        end

        # Clean up
        lock(GB._CURRENT_CLAUSE_OBJ_IDS_LOCK) do
            empty!(GB._CURRENT_CLAUSE_OBJ_IDS)
        end
    end

    # =========================================================================
    @testset "3. Reverse lookup survives empty companion payload" begin
        # This is the core regression scenario: a knowledge group where the
        # companion vote has an EMPTY payload (""), no chunk map overlap,
        # and the action name alone ("describe"/"explain") doesn't match
        # any user clause. Before v7.22, _infer_scoped_mission would fall
        # through to the bare action name, causing Gate (a) to skip the group.
        # With the reverse lookup, the clause text is always found.

        clause_text = "what is the sky"
        obj_id = GB.fresh_objective_id()

        clause_obj_ids = Dict{String, UInt64}(clause_text => obj_id)

        # Companion vote with empty payload — the exact bug trigger
        empty_vote = GB.Vote("node_sky", "describe", 0.7, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "", obj_id, :companion)

        clauses = InputDecomposer.decompose("what is 3 times 4 and what is the sky")

        # Without clause_obj_ids, this would return "describe" (bare action fallback)
        scoped_no_map = MultipartOrchestrator._infer_scoped_mission([empty_vote], clauses, Dict{String, UInt64}())
        @test scoped_no_map == "describe"  # confirms the old broken behavior

        # WITH clause_obj_ids, reverse lookup finds the clause text
        scoped_with_map = MultipartOrchestrator._infer_scoped_mission([empty_vote], clauses, clause_obj_ids)
        @test occursin("sky", lowercase(scoped_with_map))
        @test scoped_with_map != "describe"
    end

    # =========================================================================
    @testset "4. Three-clause multipart: all scoped correctly" begin
        # Stress test: 3 clauses, ensure each group gets the right scoped_mission
        mission = "what is 2 plus 2 and what is the sky and what is love"
        clauses = InputDecomposer.decompose(mission)
        @test length(clauses) >= 3

        clause_obj_ids = Dict{String, UInt64}()
        for cl in clauses
            clause_obj_ids[cl.text] = GB.fresh_objective_id()
        end

        # Mock votes: one per clause
        votes = GB.Vote[]
        for (i, cl) in enumerate(clauses)
            action = i == 1 ? "calculate" : "describe"
            obj_id = clause_obj_ids[cl.text]
            v = GB.Vote("node_$i", action, 0.8, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "", obj_id, :companion)
            push!(votes, v)
        end

        result = MultipartOrchestrator.orchestrate_multipart(votes, clauses, clause_obj_ids)
        @test length(result.groups) >= 3

        # Verify each group's scoped_mission matches its clause
        for grp in result.groups
            # Find which clause this group belongs to
            matched = false
            for (cl_text, cl_obj_id) in clause_obj_ids
                if cl_obj_id == grp.objective_id
                    @test occursin(strip(lowercase(split(cl_text, " ")[end])), lowercase(grp.scoped_mission)) ||
                          occursin(strip(lowercase(cl_text)), lowercase(grp.scoped_mission))
                    matched = true
                    break
                end
            end
            @test matched  # every group should match a clause
        end
    end

    # =========================================================================
    @testset "5. Singleton votes pass through unchanged" begin
        # Votes with objective_id=0 (singletons) should not be grouped.
        # This is a regression guard for the multipart orchestrator.
        singleton_vote = GB.Vote("node_solo", "reason", 0.9, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "test answer", UInt64(0), :singleton)

        clauses = InputDecomposer.decompose("what is 2 plus 2")  # single clause
        result = MultipartOrchestrator.orchestrate_multipart([singleton_vote], clauses)

        # Should produce 0 multipart groups (singleton votes aren't grouped)
        @test length(result.groups) == 0
    end

    # =========================================================================
    @testset "6. Clause_obj_ids empty dict fallback still works" begin
        # When clause_obj_ids is empty (e.g. first-cycle or finally-cleared),
        # _infer_scoped_mission should still work via companion payload or
        # other fallback methods.

        obj_id = GB.fresh_objective_id()
        # Vote WITH a non-empty payload (companion with clause text)
        good_vote = GB.Vote("node_sky", "describe", 0.7, String[], GB.RelationalTriple[], GB.RelationalTriple[], false, "what is the sky", obj_id, :companion)

        clauses = InputDecomposer.decompose("what is 3 times 4 and what is the sky")

        # Empty clause_obj_ids — should fall through to companion payload
        scoped = MultipartOrchestrator._infer_scoped_mission([good_vote], clauses, Dict{String, UInt64}())
        @test occursin("sky", lowercase(scoped))
    end

end

println("\n" * "="^60)
println("v7.22 MULTIPART COHERENCE TEST COMPLETE")
println("="^60)
