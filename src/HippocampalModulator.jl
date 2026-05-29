# ==============================================================================
# HippocampalModulator.jl — v7.23 Semantic Ordering & Vote Scoping
# ==============================================================================
# GRUG say: old way, votes go straight to AIML. All votes, all at once, good
#           luck figuring out which ones belong to which objective. That like
#           giving cave ALL rocks at same time and saying "you figure out which
#           rock answers which question." Cave can't do that. Cave gets confused.
#
# GRUG say: new way, votes write to a LOG. Log has entries. Each entry is one
#           objective with ONLY its own votes. Log is numbered. Entry 1 happens
#           before entry 2. Entry 2 can see entry 1's output. That is step
#           coherence. Hippocampus doesn't think — hippocampus ORDERS.
#
# GRUG say: log wiped every cycle. Born empty, dies empty. Same as
#           gained_this_cycle. Ephemeral by nature.
#
# GRUG say: this module does NOT execute objectives. It writes the plan.
#           AIML reads the plan, one entry at a time. AIML stays simple.
#           Modulator stays simple. Log is the bridge between them.
#
# ==============================================================================
# ACADEMIC: HippocampalModulator implements a transient action-log buffer
# inspired by hippocampal replay/sequencing. Votes are not submitted directly
# to the generative engine; instead they are written to an ActionLog as
# numbered, scoped entries. Each entry carries only the votes relevant to its
# objective, plus any prior context from completed entries. The modulator
# resolves hard ordering dependencies (pronoun antecedents, output references)
# and applies soft preferences (user-extensible ordering rules — slot exists,
# not yet built). The log is wiped at cycle boundaries, making it inherently
# ephemeral. This decouples vote production from vote consumption and gives
# AIML a clean, scoped interface: "read the next entry, execute it, write
# your output back."
# ==============================================================================

module HippocampalModulator

export ActionEntry, ActionLog, ActionLogStatus
export ENTRY_PENDING, ENTRY_EXECUTING, ENTRY_DONE, ENTRY_FAILED
export create_action_log!, wipe_action_log!, add_entry!, next_pending!
export complete_entry!, fail_entry!, get_entry, log_entries, log_summary
export modulate_objectives!

# ==============================================================================
# ERROR TYPES — NO SILENT FAILURES
# ==============================================================================

struct HippocampalError <: Exception
    message::String
    context::String
end

@inline _err(msg, ctx) = throw(HippocampalError(msg, ctx))

# ==============================================================================
# ACTION ENTRY STATUS
# ==============================================================================

@enum ActionLogStatus begin
    ENTRY_PENDING    # Written to log, awaiting execution
    ENTRY_EXECUTING  # Currently being processed by AIML
    ENTRY_DONE       # Completed, output available
    ENTRY_FAILED     # Execution failed
end

# ==============================================================================
# ACTION ENTRY — ONE STEP IN THE EXECUTION PLAN
# ==============================================================================

#=
    ActionEntry — a single objective in the execution plan.

    Fields:
      sequence_number  — Execution order (1, 2, 3...). Determined by the
                          modulator's ordering logic. Lower = earlier.
      objective_id     — Group ID from MultipartOrchestrator (e.g. "mp_1")
                          or "" for singletons.
      scoped_votes     — ONLY the votes belonging to this objective. Not the
                          full pile. AIML never sees votes from other groups.
      sure_votes       — The locked-in votes for this objective (from the
                          objective's primary + locked_supports).
      unsure_votes     — The unsure votes for this objective (from the
                          objective's unsure_supports).
      prior_context    — Outputs from earlier entries this one depends on.
                          Populated by the modulator based on dependency
                          resolution. Empty if no dependencies.
      dependencies     — Sequence numbers of entries this entry depends on.
                          Hard constraints: if entry 2 depends on entry 1,
                          entry 1 MUST complete before entry 2 executes.
      status           — Current execution status.
      output           — Result after AIML executes this entry. Empty until
                          status is ENTRY_DONE.
=#
mutable struct ActionEntry
    sequence_number::Int
    objective_id::String
    scoped_votes::Vector{Any}       # All votes for this objective
    sure_votes::Vector{Any}         # Locked-in votes (primary + locked supports)
    unsure_votes::Vector{Any}       # Unsure votes (survived coinflip)
    prior_context::Vector{String}   # Outputs from prior entries
    dependencies::Vector{Int}       # Sequence numbers this entry depends on
    status::ActionLogStatus
    output::String
end

# ==============================================================================
# ACTION LOG — THE BUFFER
# ==============================================================================

#=
    ActionLog — the ordered execution plan. Wiped every cycle.

    The log is the single source of truth for what happens, in what order,
    with what scoped inputs. AIML reads from the log, one entry at a time.
    The log accumulates outputs as entries complete, making them available
    for downstream entries that depend on them.

    Fields:
      entries            — Ordered list of ActionEntry objects.
      objective_outputs  — Map from objective_id -> output string. Filled in
                           as entries complete. Used for context carry-forward.
=#
mutable struct ActionLog
    entries::Vector{ActionEntry}
    objective_outputs::Dict{String, String}
end

# ==============================================================================
# LOG LIFECYCLE — CREATE, WIPE, QUERY
# ==============================================================================

"""
    create_action_log!() -> ActionLog

Create a fresh, empty ActionLog. Call at cycle start.
"""
function create_action_log!()
    return ActionLog(ActionEntry[], Dict{String, String}())
end

"""
    wipe_action_log!(log::ActionLog)

Wipe the log clean. Call at cycle end (or cycle start, same effect).
Log is ephemeral — no state survives across cycles.
"""
function wipe_action_log!(log::ActionLog)
    empty!(log.entries)
    empty!(log.objective_outputs)
    return nothing
end

"""
    log_entries(log::ActionLog) -> Vector{ActionEntry}

Return a copy of all entries in sequence order.
"""
function log_entries(log::ActionLog)
    return copy(log.entries)
end

"""
    get_entry(log::ActionLog, seq::Int) -> ActionEntry

Get entry by sequence number. Throws if not found.
"""
function get_entry(log::ActionLog, seq::Int)
    for e in log.entries
        if e.sequence_number == seq
            return e
        end
    end
    _err("No entry with sequence_number=$seq", "get_entry")
end

# ==============================================================================
# ENTRY MUTATION — ADD, NEXT, COMPLETE
# ==============================================================================

"""
    add_entry!(log::ActionLog;
               objective_id, scoped_votes, sure_votes, unsure_votes,
               prior_context, dependencies) -> ActionEntry

Append a new entry to the log. Sequence number is auto-assigned
(next integer). Status defaults to ENTRY_PENDING.
"""
function add_entry!(log::ActionLog;
                    objective_id::String = "",
                    scoped_votes::Vector = Any[],
                    sure_votes::Vector = Any[],
                    unsure_votes::Vector = Any[],
                    prior_context::Vector{String} = String[],
                    dependencies::Vector{Int} = Int[])::ActionEntry
    seq = length(log.entries) + 1
    entry = ActionEntry(
        seq,
        objective_id,
        scoped_votes,
        sure_votes,
        unsure_votes,
        prior_context,
        dependencies,
        ENTRY_PENDING,
        "",                     # output empty until executed
    )
    push!(log.entries, entry)
    return entry
end

"""
    next_pending!(log::ActionLog) -> Union{ActionEntry, Nothing}

Return the next ENTRY_PENDING entry whose dependencies are all ENTRY_DONE.
Returns nothing if no eligible entry exists. Marks the entry as ENTRY_EXECUTING.
This is AIML's "give me the next thing to do" call.
"""
function next_pending!(log::ActionLog)::Union{ActionEntry, Nothing}
    for entry in log.entries
        entry.status !== ENTRY_PENDING && continue

        # GRUG: Check all dependencies are done. If any dependency is still
        # pending or executing, this entry can't run yet.
        deps_met = true
        for dep_seq in entry.dependencies
            dep = get_entry(log, dep_seq)
            if dep.status !== ENTRY_DONE
                deps_met = false
                break
            end
        end
        if !deps_met
            continue
        end

        # GRUG: This one's eligible. Mark it executing and return.
        entry.status = ENTRY_EXECUTING
        return entry
    end
    return nothing
end

"""
    complete_entry!(log::ActionLog, seq::Int, output::String)

Mark an entry as done with its output. Stores the output in
objective_outputs for context carry-forward by later entries.
"""
function complete_entry!(log::ActionLog, seq::Int, output::String)
    entry = get_entry(log, seq)
    entry.status = ENTRY_DONE
    entry.output = output

    # GRUG: Store output keyed by objective_id so later entries can
    # look it up for context carry-forward. Singleton objectives (id="")
    # get keyed by sequence number as string to avoid collisions.
    key = isempty(entry.objective_id) ? string(seq) : entry.objective_id
    log.objective_outputs[key] = output

    return nothing
end

"""
    fail_entry!(log::ActionLog, seq::Int)

Mark an entry as failed. It will not be retried. Downstream entries
that depend on this one will be stuck waiting (they can detect this
by checking if a dependency is ENTRY_FAILED).
"""
function fail_entry!(log::ActionLog, seq::Int)
    entry = get_entry(log, seq)
    entry.status = ENTRY_FAILED
    return nothing
end

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

"""
    log_summary(log::ActionLog) -> String

Human-readable summary of the log. One line per entry.
"""
function log_summary(log::ActionLog)::String
    if isempty(log.entries)
        return "[ActionLog: empty]"
    end
    lines = String["[ActionLog: $(length(log.entries)) entries]"]
    for e in log.entries
        status_str = string(e.status)
        dep_str = isempty(e.dependencies) ? "" : " deps=$(e.dependencies)"
        ctx_str = isempty(e.prior_context) ? "" : " ctx=$(length(e.prior_context))"
        out_str = isempty(e.output) ? "" : " out=$(length(e.output))chars"
        obj_str = isempty(e.objective_id) ? "singleton" : e.objective_id
        n_votes = length(e.scoped_votes)
        n_sure = length(e.sure_votes)
        n_unsure = length(e.unsure_votes)
        push!(lines, "  [$(e.sequence_number)] $obj_str | votes=$n_votes (sure=$n_sure unsure=$n_unsure) | $status_str$(dep_str)$(ctx_str)$(out_str)")
    end
    return join(lines, "\n")
end

# ==============================================================================
# MODULATION — BUILD LOG FROM MULTIPART OBJECTIVES
# ==============================================================================

#=
    _chunks_from_group_id(group_id) -> Set{Int}

Extract chunk indices from a chunk-derived group_id.
"chk_1_2_3" -> Set([1,2,3]). Returns empty set for non-chunk IDs.
=#
function _chunks_from_group_id(gid::String)::Set{Int}
    if !startswith(gid, "chk_")
        return Set{Int}()
    end
    return Set(parse.(Int, split(gid[5:end], "_")))
end

#=
    modulate_objectives!(log::ActionLog, objectives; prior_outputs)

Build ActionLog entries from MultipartOrchestrator output.

For each MultipartObjective:
  - scoped_votes = [primary, locked_supports..., unsure_supports...]
  - sure_votes = [primary, locked_supports...]
  - unsure_votes = [unsure_supports...]
  - objective_id = objective.group_id (or "" for singletons)
  - prior_context = outputs from earlier multipart objectives (if any)
  - dependencies = [sequence numbers of prior multipart entries that
                    share chunk overlap, or all prior for legacy groups]

Ordering: singletons first (no dependencies among them), then multipart
objectives in group_id order.

v7.23 CHUNK-AWARE DEPENDENCIES: When objectives carry chunk-derived group IDs
("chk_*"), dependencies are computed from chunk OVERLAP rather than the
conservative "depend on all prior" default. Two objectives whose chunks
don't overlap are independent — they resolved different parts of the input
and don't need to reference each other's output. This enables parallelism:
independent objectives can execute concurrently since neither references
the other. For legacy "mp_*" groups, the old conservative behavior is
preserved (depend on all prior multipart entries).

`prior_outputs` is an optional Dict{String, String} of objective_id -> output
from a previous cycle. This supports cross-cycle context carry-forward if
needed, but the primary use is within-cycle: as each entry completes, its
output goes into log.objective_outputs and becomes available to later entries.
=#
function modulate_objectives!(log::ActionLog, objectives::AbstractVector;
                              prior_outputs::Dict{String, String} = Dict{String, String}())
    # GRUG: Partition into singletons and multipart. Singletons have no
    # dependencies on each other or on multipart objectives. Multipart
    # objectives may depend on earlier multipart objectives (step coherence).
    singletons = [obj for obj in objectives if !obj.is_multipart]
    multipart  = [obj for obj in objectives if obj.is_multipart]

    # GRUG: Write singleton entries first. They're independent — no deps.
    for obj in singletons
        all_votes = vcat([obj.primary], obj.locked_supports, obj.unsure_supports)
        sure = vcat([obj.primary], obj.locked_supports)
        unsure = Any[obj.unsure_supports...]

        # GRUG: Singletons don't depend on anything. They can run in any order.
        add_entry!(log;
            objective_id   = obj.group_id,
            scoped_votes   = all_votes,
            sure_votes     = sure,
            unsure_votes   = unsure,
            prior_context  = String[],
            dependencies   = Int[],
        )
    end

    # GRUG v7.23: Write multipart entries with chunk-aware dependencies.
    # For chunk-derived groups ("chk_*"), only depend on prior objectives
    # whose chunks OVERLAP with this one. Objectives about different parts
    # of the input are independent — they can run in parallel.
    # For legacy groups ("mp_*"), keep the conservative "depend on all prior"
    # behavior (we don't know which parts they reference).
    multipart_seq_numbers = Int[]
    multipart_chunk_sets  = Set{Int}[]    # parallel to multipart_seq_numbers

    for obj in multipart
        all_votes = vcat([obj.primary], obj.locked_supports, obj.unsure_supports)
        sure = vcat([obj.primary], obj.locked_supports)
        unsure = Any[obj.unsure_supports...]

        # GRUG v7.23: Compute chunk-aware dependencies.
        my_chunks = _chunks_from_group_id(obj.group_id)

        if !isempty(my_chunks)
            # CHUNK-AWARE: Only depend on prior objectives that share chunks.
            # Two objectives about different parts of the input are independent.
            deps = Int[]
            for (idx, prior_seq) in enumerate(multipart_seq_numbers)
                prior_chunks = multipart_chunk_sets[idx]
                if !isempty(intersect(my_chunks, prior_chunks))
                    push!(deps, prior_seq)
                end
            end
        else
            # LEGACY: Conservative — depend on all prior multipart entries.
            deps = copy(multipart_seq_numbers)
        end

        # GRUG: Context from dependency entries (not ALL prior entries).
        # Only entries we depend on provide prior context.
        prior_ctx = String[]
        for ps in deps
            prior_entry = get_entry(log, ps)
            key = isempty(prior_entry.objective_id) ? string(ps) : prior_entry.objective_id
            if haskey(log.objective_outputs, key)
                push!(prior_ctx, log.objective_outputs[key])
            elseif haskey(prior_outputs, key)
                push!(prior_ctx, prior_outputs[key])
            end
        end

        entry = add_entry!(log;
            objective_id   = obj.group_id,
            scoped_votes   = all_votes,
            sure_votes     = sure,
            unsure_votes   = unsure,
            prior_context  = prior_ctx,
            dependencies   = deps,
        )
        push!(multipart_seq_numbers, entry.sequence_number)
        push!(multipart_chunk_sets, my_chunks)
    end

    return log
end

end # module HippocampalModulator
