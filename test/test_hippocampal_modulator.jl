# test/test_hippocampal_modulator.jl
# ==============================================================================
# v7.23 — HippocampalModulator: ActionLog + vote scoping + step coherence
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("HIPPOCAMPAL MODULATOR TESTS")
println("="^60)

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
const SRC_DIR   = joinpath(REPO_ROOT, "src")

include(joinpath(SRC_DIR, "RelationalJitter.jl"))
using .RelationalJitter

include(joinpath(SRC_DIR, "stochastichelper.jl"))
using .CoinFlipHeader
include(joinpath(SRC_DIR, "patternscanner.jl"))
using .PatternScanner
include(joinpath(SRC_DIR, "ImageSDF.jl"))
using .ImageSDF
include(joinpath(SRC_DIR, "SemanticVerbs.jl"))
using .SemanticVerbs
include(joinpath(SRC_DIR, "VoteOrchestrator.jl"))
using .VoteOrchestrator
include(joinpath(SRC_DIR, "MultipartOrchestrator.jl"))
using .MultipartOrchestrator

include(joinpath(SRC_DIR, "HippocampalModulator.jl"))
using .HippocampalModulator

include(joinpath(SRC_DIR, "EyeSystem.jl"))
using .EyeSystem
include(joinpath(SRC_DIR, "ActionTonePredictor.jl"))
using .ActionTonePredictor
include(joinpath(SRC_DIR, "LobeTable.jl"))
using .LobeTable
include(joinpath(SRC_DIR, "Lobe.jl"))
using .Lobe
include(joinpath(SRC_DIR, "BrainStem.jl"))
using .BrainStem
include(joinpath(SRC_DIR, "Thesaurus.jl"))
using .Thesaurus
include(joinpath(SRC_DIR, "InputQueue.jl"))
using .InputQueue
include(joinpath(SRC_DIR, "ChatterMode.jl"))
using .ChatterMode
include(joinpath(SRC_DIR, "PhagyMode.jl"))
using .PhagyMode
include(joinpath(SRC_DIR, "ImmuneSystem.jl"))
using .ImmuneSystem
include(joinpath(SRC_DIR, "ImmuneThreadPool.jl"))
using .ImmuneThreadPool
include(joinpath(SRC_DIR, "FullLobeScanner.jl"))
using .FullLobeScanner
include(joinpath(SRC_DIR, "AIMLNodeSystem.jl"))
using .AIMLNodeSystem
include(joinpath(SRC_DIR, "InputDecomposer.jl"))
using .InputDecomposer
include(joinpath(SRC_DIR, "engine.jl"))

using .RelationalJitter
RelationalJitter.disable_jitter!()

# ==============================================================================
# HELPERS — build MultipartObjective objects for testing
# ==============================================================================

function make_vote(node_id::String, action::String, confidence::Float64,
                   group_id::String = "", role::Symbol = :singleton)
    return Vote(node_id, action, confidence, String[],
                RelationalTriple[], RelationalTriple[], false, group_id, role)
end

function make_singleton_objective(node_id::String, action::String, confidence::Float64)
    v = make_vote(node_id, action, confidence, "", :singleton)
    return MultipartOrchestrator.MultipartObjective("", v, Any[], Any[], false)
end

function make_multipart_objective(group_id::String, primary_vote, locked_votes, unsure_votes)
    return MultipartOrchestrator.MultipartObjective(
        group_id, primary_vote, locked_votes, unsure_votes, true
    )
end

# ==============================================================================
# TEST 1: Create and wipe log
# ==============================================================================
@testset "HippocampalModulator — create and wipe" begin
    log = create_action_log!()
    @test isempty(log.entries)
    @test isempty(log.objective_outputs)

    add_entry!(log; objective_id = "mp_1", scoped_votes = Any["fake"])
    @test length(log.entries) == 1

    wipe_action_log!(log)
    @test isempty(log.entries)
    @test isempty(log.objective_outputs)
end

# ==============================================================================
# TEST 2: Add entries with auto-sequence numbering
# ==============================================================================
@testset "HippocampalModulator — auto-sequence numbering" begin
    log = create_action_log!()

    e1 = add_entry!(log; objective_id = "mp_1")
    e2 = add_entry!(log; objective_id = "mp_2")
    e3 = add_entry!(log; objective_id = "")

    @test e1.sequence_number == 1
    @test e2.sequence_number == 2
    @test e3.sequence_number == 3
    @test e1.status == ENTRY_PENDING
    @test e2.status == ENTRY_PENDING
    @test e3.status == ENTRY_PENDING
end

# ==============================================================================
# TEST 3: next_pending! returns entries in order, respects dependencies
# ==============================================================================
@testset "HippocampalModulator — next_pending! respects dependencies" begin
    log = create_action_log!()

    # Entry 1: no deps (singleton)
    add_entry!(log; objective_id = "", dependencies = Int[])
    # Entry 2: depends on entry 1
    add_entry!(log; objective_id = "mp_1", dependencies = [1])
    # Entry 3: depends on entry 2
    add_entry!(log; objective_id = "mp_2", dependencies = [2])

    # Entry 1 should be eligible
    e1 = next_pending!(log)
    @test !isnothing(e1)
    @test e1.sequence_number == 1
    @test e1.status == ENTRY_EXECUTING

    # Entry 2 depends on 1, but 1 isn't DONE yet — should skip
    e2_attempt = next_pending!(log)
    @test isnothing(e2_attempt)

    # Complete entry 1
    complete_entry!(log, 1, "Paris is the capital of France.")
    @test e1.status == ENTRY_DONE

    # Now entry 2 should be eligible
    e2 = next_pending!(log)
    @test !isnothing(e2)
    @test e2.sequence_number == 2
    @test e2.status == ENTRY_EXECUTING

    # Entry 3 still blocked (depends on 2)
    e3_attempt = next_pending!(log)
    @test isnothing(e3_attempt)

    # Complete entry 2
    complete_entry!(log, 2, "Its population is 2.1 million.")
    @test e2.status == ENTRY_DONE

    # Now entry 3 should be eligible
    e3 = next_pending!(log)
    @test !isnothing(e3)
    @test e3.sequence_number == 3
end

# ==============================================================================
# TEST 4: complete_entry! stores output in objective_outputs
# ==============================================================================
@testset "HippocampalModulator — complete_entry! stores output" begin
    log = create_action_log!()

    add_entry!(log; objective_id = "mp_1")
    add_entry!(log; objective_id = "mp_2")

    # Complete entry 1
    complete_entry!(log, 1, "Output for mp_1")

    @test haskey(log.objective_outputs, "mp_1")
    @test log.objective_outputs["mp_1"] == "Output for mp_1"

    # Singleton uses sequence number as key
    add_entry!(log; objective_id = "")
    complete_entry!(log, 3, "Singleton output")
    @test haskey(log.objective_outputs, "3")
    @test log.objective_outputs["3"] == "Singleton output"
end

# ==============================================================================
# TEST 5: modulate_objectives! with singletons only
# ==============================================================================
@testset "HippocampalModulator — singletons only, no deps" begin
    log = create_action_log!()

    obj1 = make_singleton_objective("node_a", "act_a", 0.9)
    obj2 = make_singleton_objective("node_b", "act_b", 0.7)

    modulate_objectives!(log, [obj1, obj2])

    @test length(log.entries) == 2

    # Singletons should have no dependencies
    @test isempty(log.entries[1].dependencies)
    @test isempty(log.entries[2].dependencies)

    # Both should be pending
    @test log.entries[1].status == ENTRY_PENDING
    @test log.entries[2].status == ENTRY_PENDING

    # Votes should be scoped correctly
    @test length(log.entries[1].scoped_votes) == 1
    @test length(log.entries[2].scoped_votes) == 1
end

# ==============================================================================
# TEST 6: modulate_objectives! with multipart — dependencies created
# ==============================================================================
@testset "HippocampalModulator — multipart objectives get dependencies" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    v1s = make_vote("n1s", "act1s", 0.8, "mp_1", :support)
    obj1 = make_multipart_objective("mp_1", v1, Any[v1s], Any[])

    v2 = make_vote("n2", "act2", 0.85, "mp_2", :primary)
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[])

    modulate_objectives!(log, [obj1, obj2])

    @test length(log.entries) == 2

    # First multipart has no deps (nothing before it)
    @test isempty(log.entries[1].dependencies)

    # Second multipart depends on first
    @test log.entries[2].dependencies == [1]
end

# ==============================================================================
# TEST 7: modulate_objectives! with mixed singletons + multipart
# ==============================================================================
@testset "HippocampalModulator — singletons first, multipart after with deps" begin
    log = create_action_log!()

    # Singleton first
    sing = make_singleton_objective("n_s", "act_s", 0.6)
    # Multipart after
    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    obj1 = make_multipart_objective("mp_1", v1, Any[], Any[])
    v2 = make_vote("n2", "act2", 0.85, "mp_2", :primary)
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[])

    # Pass in mixed order — modulator should reorder singletons first
    modulate_objectives!(log, [obj1, sing, obj2])

    @test length(log.entries) == 3

    # Entry 1 should be the singleton (singletons come first)
    @test log.entries[1].objective_id == ""
    @test isempty(log.entries[1].dependencies)

    # Entry 2 should be mp_1 (first multipart)
    @test log.entries[2].objective_id == "mp_1"
    @test isempty(log.entries[2].dependencies)

    # Entry 3 should be mp_2 (second multipart, depends on mp_1)
    @test log.entries[3].objective_id == "mp_2"
    @test log.entries[3].dependencies == [2]
end

# ==============================================================================
# TEST 8: Context carry-forward — prior entry output available to later entries
# ==============================================================================
@testset "HippocampalModulator — context carry-forward" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    obj1 = make_multipart_objective("mp_1", v1, Any[], Any[])
    v2 = make_vote("n2", "act2", 0.85, "mp_2", :primary)
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[])

    modulate_objectives!(log, [obj1, obj2])

    # No prior context yet (nothing completed)
    @test isempty(log.entries[1].prior_context)
    @test isempty(log.entries[2].prior_context)

    # Complete entry 1 with output
    complete_entry!(log, 1, "Paris is the capital of France.")

    # Now re-modulate — entry 2 should see entry 1's output
    wipe_action_log!(log)
    modulate_objectives!(log, [obj1, obj2];
        prior_outputs = Dict("mp_1" => "Paris is the capital of France."))

    @test isempty(log.entries[1].prior_context)
    @test length(log.entries[2].prior_context) == 1
    @test log.entries[2].prior_context[1] == "Paris is the capital of France."
end

# ==============================================================================
# TEST 9: Vote scoping — each entry only gets its own group's votes
# ==============================================================================
@testset "HippocampalModulator — vote scoping: no cross-group leakage" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    v1s1 = make_vote("n1s1", "act1s1", 0.85, "mp_1", :support)
    v1s2 = make_vote("n1s2", "act1s2", 0.7, "mp_1", :support)
    obj1 = make_multipart_objective("mp_1", v1, Any[v1s1], Any[v1s2])

    v2 = make_vote("n2", "act2", 0.88, "mp_2", :primary)
    v2s = make_vote("n2s", "act2s", 0.6, "mp_2", :support)
    obj2 = make_multipart_objective("mp_2", v2, Any[v2s], Any[])

    modulate_objectives!(log, [obj1, obj2])

    # Entry 1 (mp_1): primary + 1 locked + 1 unsure = 3 scoped votes
    @test length(log.entries[1].scoped_votes) == 3
    @test length(log.entries[1].sure_votes) == 2   # primary + locked
    @test length(log.entries[1].unsure_votes) == 1  # unsure

    # Entry 2 (mp_2): primary + 1 locked + 0 unsure = 2 scoped votes
    @test length(log.entries[2].scoped_votes) == 2
    @test length(log.entries[2].sure_votes) == 2   # primary + locked
    @test length(log.entries[2].unsure_votes) == 0

    # Cross-check: no vote from mp_2 appears in mp_1's scoped_votes
    mp1_node_ids = Set([getfield(v, :node_id) for v in log.entries[1].scoped_votes])
    @test !("n2" in mp1_node_ids)
    @test !("n2s" in mp1_node_ids)
end

# ==============================================================================
# TEST 10: Log summary is human-readable
# ==============================================================================
@testset "HippocampalModulator — log_summary output" begin
    log = create_action_log!()

    # Empty log
    @test occursin("empty", log_summary(log))

    add_entry!(log; objective_id = "mp_1")
    complete_entry!(log, 1, "done")

    summary = log_summary(log)
    @test occursin("mp_1", summary)
    @test occursin("DONE", summary)
end

# ==============================================================================
# TEST 11: Fail entry marks as ENTRY_FAILED
# ==============================================================================
@testset "HippocampalModulator — fail_entry! marks failed" begin
    log = create_action_log!()
    add_entry!(log; objective_id = "mp_1")

    e = next_pending!(log)
    @test e.sequence_number == 1
    @test e.status == ENTRY_EXECUTING

    fail_entry!(log, 1)
    @test e.status == ENTRY_FAILED

    # No more pending entries
    @test isnothing(next_pending!(log))
end

# ==============================================================================
# TEST 12: Singleton objective — sure_votes and unsure_votes correct
# ==============================================================================
@testset "HippocampalModulator — singleton sure/unsure split" begin
    log = create_action_log!()

    v = make_vote("n1", "act1", 0.9)
    obj = MultipartOrchestrator.MultipartObjective("", v, Any[], Any[], false)

    modulate_objectives!(log, [obj])

    @test length(log.entries) == 1
    @test log.entries[1].objective_id == ""
    @test length(log.entries[1].scoped_votes) == 1
    @test length(log.entries[1].sure_votes) == 1   # primary is the only sure vote
    @test length(log.entries[1].unsure_votes) == 0
end

# ==============================================================================
# TEST 13: Full execution flow — write log, execute entries, collect output
# ==============================================================================
@testset "HippocampalModulator — full execution flow" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    obj1 = make_multipart_objective("mp_1", v1, Any[], Any[])
    v2 = make_vote("n2", "act2", 0.85, "mp_2", :primary)
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[])

    modulate_objectives!(log, [obj1, obj2])

    # Simulate AIML reading and executing entries one by one
    outputs = String[]
    while true
        entry = next_pending!(log)
        isnothing(entry) && break

        # Simulate AIML generating output for this entry
        simulated_output = "Output for $(entry.objective_id)"
        complete_entry!(log, entry.sequence_number, simulated_output)
        push!(outputs, simulated_output)
    end

    @test length(outputs) == 2
    @test outputs[1] == "Output for mp_1"
    @test outputs[2] == "Output for mp_2"

    # All entries should be done
    for e in log.entries
        @test e.status == ENTRY_DONE
    end
end

# ==============================================================================
# TEST 14: Wipe clears everything for next cycle
# ==============================================================================
@testset "HippocampalModulator — cycle wipe resets state" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    obj1 = make_multipart_objective("mp_1", v1, Any[], Any[])
    modulate_objectives!(log, [obj1])

    # Complete the entry
    e = next_pending!(log)
    complete_entry!(log, e.sequence_number, "output")

    # Everything is populated
    @test !isempty(log.entries)
    @test !isempty(log.objective_outputs)

    # Wipe for next cycle
    wipe_action_log!(log)

    @test isempty(log.entries)
    @test isempty(log.objective_outputs)

    # Can add new entries after wipe
    add_entry!(log; objective_id = "mp_2")
    @test length(log.entries) == 1
    @test log.entries[1].sequence_number == 1  # Sequence resets after wipe
end

println("\n" * "="^60)
println("✅ ALL HIPPOCAMPAL MODULATOR TESTS PASSED")
println("="^60)
