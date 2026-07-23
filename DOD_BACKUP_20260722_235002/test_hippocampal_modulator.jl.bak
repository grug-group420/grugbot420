# test/test_hippocampal_modulator.jl
# ==============================================================================
# v7.47 — HippocampalModulator: Confidence-Ordered Dispatch & Reserved Steps
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

    add_entry!(log; objective_id = "mp_1", scoped_votes = Any["fake"],
               confidence = 0.5, reserved_step = 1)
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

    e1 = add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1)
    e2 = add_entry!(log; objective_id = "mp_2", confidence = 0.7, reserved_step = 2)
    e3 = add_entry!(log; objective_id = "", confidence = 0.5, reserved_step = 3)

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
    add_entry!(log; objective_id = "", dependencies = Int[], confidence = 0.9, reserved_step = 1)
    # Entry 2: depends on entry 1
    add_entry!(log; objective_id = "mp_1", dependencies = [1], confidence = 0.7, reserved_step = 2)
    # Entry 3: depends on entry 2
    add_entry!(log; objective_id = "mp_2", dependencies = [2], confidence = 0.5, reserved_step = 3)

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

    add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1)
    add_entry!(log; objective_id = "mp_2", confidence = 0.7, reserved_step = 2)

    # Complete entry 1
    complete_entry!(log, 1, "Output for mp_1")

    @test haskey(log.objective_outputs, "mp_1")
    @test log.objective_outputs["mp_1"] == "Output for mp_1"

    # Singleton uses sequence number as key
    add_entry!(log; objective_id = "", confidence = 0.5, reserved_step = 3)
    complete_entry!(log, 3, "Singleton output")
    @test haskey(log.objective_outputs, "3")
    @test log.objective_outputs["3"] == "Singleton output"
end

# ==============================================================================
# TEST 5: modulate_objectives! with singletons only — confidence-ordered
# ==============================================================================
@testset "HippocampalModulator — singletons only, confidence-ordered" begin
    log = create_action_log!()

    # Pass in LOW confidence first, HIGH confidence second
    obj1 = make_singleton_objective("node_a", "act_a", 0.7)   # lower confidence
    obj2 = make_singleton_objective("node_b", "act_b", 0.9)   # higher confidence

    modulate_objectives!(log, [obj1, obj2])

    @test length(log.entries) == 2

    # v7.47: Entries should be ordered by confidence DESCENDING
    # So entry 1 (highest confidence) should be node_b (0.9)
    # and entry 2 should be node_a (0.7)
    @test log.entries[1].confidence >= log.entries[2].confidence
    @test log.entries[1].confidence == 0.9
    @test log.entries[2].confidence == 0.7

    # No dependencies for singletons
    @test isempty(log.entries[1].dependencies)
    @test isempty(log.entries[2].dependencies)

    # Both should be pending
    @test log.entries[1].status == ENTRY_PENDING
    @test log.entries[2].status == ENTRY_PENDING

    # Reserved steps should be 1 and 2 (in confidence order)
    @test log.entries[1].reserved_step == 1
    @test log.entries[2].reserved_step == 2

    # Neither should be supplementary (both above low-confidence threshold)
    @test !log.entries[1].is_supplementary
    @test !log.entries[2].is_supplementary

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

    # Two sure entries + no additive entries (no unsure_supports)
    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test length(sure_entries) == 2

    # First (higher confidence) multipart has no deps (nothing before it)
    @test isempty(sure_entries[1].dependencies)

    # Second (lower confidence) multipart depends on first
    @test sure_entries[2].dependencies == [sure_entries[1].sequence_number]
end

# ==============================================================================
# TEST 7: modulate_objectives! — ALL entries sorted by confidence
# ==============================================================================
@testset "HippocampalModulator — confidence ordering across singletons + multipart" begin
    log = create_action_log!()

    # Singleton with MEDIUM confidence
    sing = make_singleton_objective("n_s", "act_s", 0.6)
    # Multipart with HIGH confidence
    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    obj1 = make_multipart_objective("mp_1", v1, Any[], Any[])
    # Multipart with LOWER confidence
    v2 = make_vote("n2", "act2", 0.75, "mp_2", :primary)
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[])

    # Pass in mixed order — modulator should sort by confidence
    modulate_objectives!(log, [obj1, sing, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test length(sure_entries) == 3

    # v7.47: ALL entries sorted by confidence descending
    # Entry 1 = highest confidence (0.9, mp_1)
    # Entry 2 = next highest (0.75, mp_2)
    # Entry 3 = lowest (0.6, singleton)
    @test sure_entries[1].confidence == 0.9
    @test sure_entries[2].confidence == 0.75
    @test sure_entries[3].confidence == 0.6

    # No singleton-first ordering anymore — pure confidence ordering
    @test sure_entries[1].objective_id == "mp_1"
    @test sure_entries[2].objective_id == "mp_2"
    @test sure_entries[3].objective_id == ""

    # Dependencies: mp_2 depends on mp_1 (multipart dep)
    # Singleton has no deps
    mp1_entry = sure_entries[1]
    mp2_entry = sure_entries[2]
    sing_entry = sure_entries[3]

    @test isempty(mp1_entry.dependencies)
    @test isempty(sing_entry.dependencies)
    # mp_2 depends on mp_1 (legacy multipart dep on all prior multipart)
    @test mp1_entry.sequence_number in mp2_entry.dependencies
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
    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test isempty(sure_entries[1].prior_context)
    @test isempty(sure_entries[2].prior_context)

    # Complete entry 1 with output
    complete_entry!(log, sure_entries[1].sequence_number, "Paris is the capital of France.")

    # Now re-modulate — entry 2 should see entry 1's output via prior_outputs
    wipe_action_log!(log)
    modulate_objectives!(log, [obj1, obj2];
        prior_outputs = Dict("mp_1" => "Paris is the capital of France."))

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test isempty(sure_entries[1].prior_context)
    @test length(sure_entries[2].prior_context) == 1
    @test sure_entries[2].prior_context[1] == "Paris is the capital of France."
end

# ==============================================================================
# TEST 9: Vote scoping — each sure entry only gets its own group's sure votes
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

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    additive_entries = [e for e in log.entries if e.entry_type == ENTRY_ADDITIVE]

    # Sure entry for mp_1: primary + 1 locked = 2 sure votes
    mp1_sure = sure_entries[1]  # higher confidence (0.9)
    @test length(mp1_sure.sure_votes) == 2   # primary + locked
    @test length(mp1_sure.unsure_votes) == 0  # unsure votes get their own additive entries

    # Sure entry for mp_2: primary + 1 locked = 2 sure votes
    mp2_sure = sure_entries[2]  # lower confidence (0.88)
    @test length(mp2_sure.sure_votes) == 2   # primary + locked
    @test length(mp2_sure.unsure_votes) == 0

    # Additive entries: unsure votes get their own entries
    @test length(additive_entries) == 1  # v1s2 is the only unsure vote
    @test additive_entries[1].entry_type == ENTRY_ADDITIVE
    @test additive_entries[1].is_supplementary == true

    # Cross-check: no vote from mp_2 appears in mp_1's scoped_votes
    mp1_node_ids = Set([getfield(v, :node_id) for v in mp1_sure.scoped_votes])
    @test !("n2" in mp1_node_ids)
    @test !("n2s" in mp1_node_ids)
end

# ==============================================================================
# TEST 10: Log summary is human-readable (with confidence/step info)
# ==============================================================================
@testset "HippocampalModulator — log_summary output" begin
    log = create_action_log!()

    # Empty log
    @test occursin("empty", log_summary(log))

    add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1)
    complete_entry!(log, 1, "done")

    summary = log_summary(log)
    @test occursin("mp_1", summary)
    @test occursin("DONE", summary)
    @test occursin("conf=", summary)
    @test occursin("step=", summary)
end

# ==============================================================================
# TEST 11: Fail entry marks as ENTRY_FAILED
# ==============================================================================
@testset "HippocampalModulator — fail_entry! marks failed" begin
    log = create_action_log!()
    add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1)

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
    @test log.entries[1].confidence == 0.9
    @test log.entries[1].reserved_step == 1
    @test !log.entries[1].is_supplementary
    @test log.entries[1].entry_type == ENTRY_SURE
end

# ==============================================================================
# TEST 13: Full execution flow — confidence-ordered dispatch
# ==============================================================================
@testset "HippocampalModulator — full execution flow, confidence-ordered" begin
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

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test length(outputs) == 2
    # Dispatched in confidence order: mp_1 (0.9) first, then mp_2 (0.85)
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
    add_entry!(log; objective_id = "mp_2", confidence = 0.5, reserved_step = 1)
    @test length(log.entries) == 1
    @test log.entries[1].sequence_number == 1  # Sequence resets after wipe
end

# ==============================================================================
# TEST 15: Low-confidence entries get supplementary marking
# ==============================================================================
@testset "HippocampalModulator — low-confidence supplementary marking" begin
    log = create_action_log!()

    # High confidence singleton
    obj1 = make_singleton_objective("node_a", "act_a", 0.95)
    # Medium confidence singleton
    obj2 = make_singleton_objective("node_b", "act_b", 0.7)
    # Low confidence singleton (below 0.65 * 0.95 = 0.6175)
    obj3 = make_singleton_objective("node_c", "act_c", 0.4)

    modulate_objectives!(log, [obj1, obj2, obj3])

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    @test length(sure_entries) == 3

    # Highest confidence should be ENTRY_SURE
    @test sure_entries[1].entry_type == ENTRY_SURE
    @test !sure_entries[1].is_supplementary

    # Medium confidence should be ENTRY_SURE (0.7 > 0.6175)
    @test sure_entries[2].entry_type == ENTRY_SURE
    @test !sure_entries[2].is_supplementary

    # Low confidence should be ENTRY_LOW_CONFIDENCE (0.4 < 0.6175)
    @test sure_entries[3].entry_type == ENTRY_LOW_CONFIDENCE
    @test sure_entries[3].is_supplementary
end

# ==============================================================================
# TEST 16: Unsure votes become additive entries
# ==============================================================================
@testset "HippocampalModulator — unsure votes become additive entries" begin
    log = create_action_log!()

    v1 = make_vote("n1", "act1", 0.9, "mp_1", :primary)
    v1s1 = make_vote("n1s1", "act1s1", 0.85, "mp_1", :support)  # locked
    v1u1 = make_vote("n1u1", "act1u1", 0.5, "mp_1", :support)   # unsure
    obj1 = make_multipart_objective("mp_1", v1, Any[v1s1], Any[v1u1])

    v2 = make_vote("n2", "act2", 0.8, "mp_2", :primary)
    v2u1 = make_vote("n2u1", "act2u1", 0.4, "mp_2", :support)   # unsure
    obj2 = make_multipart_objective("mp_2", v2, Any[], Any[v2u1])

    modulate_objectives!(log, [obj1, obj2])

    sure_entries = [e for e in log.entries if e.entry_type != ENTRY_ADDITIVE]
    additive_entries = [e for e in log.entries if e.entry_type == ENTRY_ADDITIVE]

    # 2 sure entries (one per objective)
    @test length(sure_entries) == 2

    # 2 additive entries (one per unsure vote)
    @test length(additive_entries) == 2

    # Additive entries have correct properties
    for ae in additive_entries
        @test ae.entry_type == ENTRY_ADDITIVE
        @test ae.is_supplementary
        @test isempty(ae.sure_votes)
        @test length(ae.unsure_votes) == 1
    end

    # Additive entries have reserved_steps AFTER all sure entries
    max_sure_step = maximum(e.reserved_step for e in sure_entries)
    for ae in additive_entries
        @test ae.reserved_step > max_sure_step
    end

    # Sure entries don't have unsure votes anymore (they're in additive entries)
    for se in sure_entries
        @test isempty(se.unsure_votes)
    end
end

# ==============================================================================
# TEST 17: assemble_output! — sure entries in step order, additives bulleted
# ==============================================================================
@testset "HippocampalModulator — assemble_output! with supplementary prefixes" begin
    log = create_action_log!()

    # Create entries manually for assembly test
    e1 = add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1,
                     entry_type = ENTRY_SURE, is_supplementary = false)
    e2 = add_entry!(log; objective_id = "mp_2", confidence = 0.5, reserved_step = 2,
                     entry_type = ENTRY_LOW_CONFIDENCE, is_supplementary = true)
    e3 = add_entry!(log; objective_id = "mp_1", confidence = 0.3, reserved_step = 3,
                     entry_type = ENTRY_ADDITIVE, is_supplementary = true)
    e4 = add_entry!(log; objective_id = "mp_2", confidence = 0.2, reserved_step = 4,
                     entry_type = ENTRY_ADDITIVE, is_supplementary = true)

    # Complete all entries with outputs
    complete_entry!(log, 1, "Paris is the capital of France.")
    complete_entry!(log, 2, "The Eiffel Tower is 330m tall.")
    complete_entry!(log, 3, "French cuisine is renowned worldwide.")
    complete_entry!(log, 4, "The Louvre is the world's largest art museum.")

    output = assemble_output!(log)

    # Sure entry should appear first, as-is
    @test occursin("Paris is the capital of France.", output)

    # Low-confidence entry should have prefix
    @test occursin("*Grug think this also important*", output)
    @test occursin("The Eiffel Tower is 330m tall.", output)

    # Additive entries should have prefix and be bulleted
    @test occursin("(Grug also think these infos maybe important)", output)
    @test occursin("- French cuisine is renowned worldwide.", output)
    @test occursin("- The Louvre is the world's largest art museum.", output)

    # Sure entry should appear BEFORE additive section
    paris_pos = findfirst("Paris", output).start
    additive_pos = findfirst("(Grug also think", output).start
    @test paris_pos < additive_pos
end

# ==============================================================================
# TEST 18: assemble_output! — single sure entry, no additives
# ==============================================================================
@testset "HippocampalModulator — assemble_output! simple case" begin
    log = create_action_log!()

    e1 = add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1,
                     entry_type = ENTRY_SURE, is_supplementary = false)
    complete_entry!(log, 1, "Hello world")

    output = assemble_output!(log)
    @test output == "Hello world"
end

# ==============================================================================
# TEST 19: Reserved step ensures output coherence regardless of dispatch order
# ==============================================================================
@testset "HippocampalModulator — reserved step ensures output coherence" begin
    log = create_action_log!()

    # Create entries OUT OF STEP ORDER to test that assembly uses reserved_step
    # Entry with reserved_step=2 added first (simulating lower-confidence dispatch)
    e1 = add_entry!(log; objective_id = "mp_2", confidence = 0.7, reserved_step = 2,
                     entry_type = ENTRY_SURE)
    # Entry with reserved_step=1 added second (simulating higher-confidence dispatch)
    e2 = add_entry!(log; objective_id = "mp_1", confidence = 0.9, reserved_step = 1,
                     entry_type = ENTRY_SURE)

    # Complete in dispatch order (e1 first, then e2)
    complete_entry!(log, 1, "Second in output")
    complete_entry!(log, 2, "First in output")

    output = assemble_output!(log)

    # Output should be in reserved_step order, not dispatch order
    # reserved_step=1 ("First in output") should appear before reserved_step=2 ("Second in output")
    first_pos = findfirst("First in output", output).start
    second_pos = findfirst("Second in output", output).start
    @test first_pos < second_pos
end

println("\n" * "="^60)
println("✅ ALL HIPPOCAMPAL MODULATOR TESTS PASSED")
println("="^60)
