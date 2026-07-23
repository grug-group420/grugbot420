# ==============================================================================
# HippocampalModulator.jl — v7.48 Confidence-Ordered Dispatch, Reserved Steps,
#                             Non-Winner Additive Entries, Relay Discount
# ==============================================================================
# GRUG say: old way, singletons go first in input order, then multipart in
#           group_id order. That wrong! Input order not same as confidence
#           order. Weak rock talk before strong rock = decoherence. User see
#           wrong answer first because wrong rock happened to be first in
#           the votes vector.
#
# GRUG say: new way, ALL entries sorted by confidence. Strongest rock talks
#           first. Weakest rock talks last. Each rock gets its own RESERVED
#           STEP — a writing space that determines where its output appears
#           in the final scaffold. Even if dispatch order different from
#           step order, step coherence preserved because each rock writes
#           to its own reserved slot.
#
# GRUG say: non-winner votes also get reserved space but they come AFTER
#           all winners. They get prefix "(Grug also think these infos
#           maybe important)" and present as bulleted list. They NOT part
#           of step coherence — they unsure additives.
#
# GRUG v7.48 say: ALL non-winner votes get their own sections now, not
#           just multipart unsure_supports. Every vote that didn't win its
#           objective but still had something to say gets an additive entry.
#           This is the "honest uncertainty tip off" — user sees what else
#           Grug considered, not just what won. Singleton missions now also
#           get additive entries (before: 0 additives because singletons
#           have no unsure_supports).
#
# GRUG say: low-confidence winner votes get prefix "*Grug think this also
#           important*" — they won but not confidently. Still part of step
#           coherence but marked as supplementary.
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
#
# v7.47 CHANGES:
#   - ActionEntry now carries confidence, reserved_step, is_supplementary,
#     and entry_type fields for confidence-ordered dispatch
#   - modulate_objectives! sorts ALL objectives by confidence (descending)
#     and assigns reserved_steps — dispatch order matches confidence rank
#   - Non-winner (unsure additive) entries get is_supplementary=true and
#     entry_type=:additive — they are presented as bulleted list with prefix
#   - Low-confidence sure entries get is_supplementary=true and
#     entry_type=:low_confidence — prefixed "*Grug think this also important*"
#   - next_pending! dispatches by confidence order (highest first)
#   - assemble_output! joins entries in reserved_step order with prefixes
#
# v7.48 CHANGES:
#   - modulate_objectives! now accepts nonwinner_votes parameter
#   - ALL non-winner votes (rejected by select_aiml_votes or lost coinflip)
#     become additive entries — not just multipart unsure_supports
#   - This fixes the "0 additive entries" bug for singleton missions
#   - Honest uncertainty tip offs: user sees what else Grug considered
# ==============================================================================

module HippocampalModulator

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
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

export ActionEntry, ActionLog, ActionLogStatus, ActionEntryType
export ENTRY_PENDING, ENTRY_EXECUTING, ENTRY_DONE, ENTRY_FAILED
export ENTRY_SURE, ENTRY_LOW_CONFIDENCE, ENTRY_ADDITIVE
export create_action_log!, wipe_action_log!, add_entry!, next_pending!
export complete_entry!, fail_entry!, get_entry, log_entries, log_summary
export modulate_objectives!, assemble_output!
export all_sure_done

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
# ACTION ENTRY TYPE — distinguishes sure winners, low-confidence, additives
# ==============================================================================

@enum ActionEntryType begin
    ENTRY_SURE           # High-confidence winner — part of step coherence
    ENTRY_LOW_CONFIDENCE # Winner but low confidence — supplementary, prefixed
    ENTRY_ADDITIVE       # Non-winner unsure additive — bulleted list, not step-coherent
end

# ==============================================================================
# CONFIDENCE THRESHOLD FOR SUPPLEMENTARY MARKING
# ==============================================================================

# GRUG: If a winner's confidence is below this fraction of the top winner's
# confidence, it gets marked as low-confidence supplementary. Still dispatched
# and executed, but prefixed with "*Grug think this also important*"
const LOW_CONFIDENCE_FRACTION = 0.65

# ==============================================================================
# ACTION ENTRY — ONE STEP IN THE EXECUTION PLAN
# ==============================================================================

#=
    ActionEntry — a single objective in the execution plan.

    Fields:
      sequence_number  — Dispatch order (1, 2, 3...). Determined by confidence
                         ranking. Highest confidence = sequence 1. This is the
                         ORDER IN WHICH ENTRIES ARE DISPATCHED to AIML.
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
      confidence       — The primary vote's composite confidence score. Used
                         to determine dispatch order and supplementary marking.
      reserved_step    — The position in the FINAL output where this entry's
                         output appears. Determined by confidence rank among
                         sure entries. Low-confidence and additive entries
                         get steps AFTER all sure entries. This ensures step
                         coherence: even if dispatch order differs from step
                         order, each entry writes to its own reserved slot.
      is_supplementary — True if this entry should be prefixed with a
                         supplementary marker. Low-confidence winners get
                         "*Grug think this also important*" prefix. Additive
                         entries get "(Grug also think these infos maybe
                         important)" prefix and are bulleted.
      entry_type       — ENTRY_SURE, ENTRY_LOW_CONFIDENCE, or ENTRY_ADDITIVE.
                         Determines prefix formatting and output placement.
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
    confidence::Float64             # Primary vote's confidence — determines dispatch rank
    reserved_step::Int              # Position in final output assembly — ensures step coherence
    is_supplementary::Bool          # True = gets supplementary prefix
    entry_type::ActionEntryType     # Sure / low-confidence / additive
    scoped_mission::String          # GRUG v8.2: Sub-subject text for this entry (not full mission)
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
      entries            — Ordered list of ActionEntry objects. Ordered by
                           confidence (descending) for dispatch. Each entry
                           has a reserved_step for output position.
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
               prior_context, dependencies, confidence,
               reserved_step, is_supplementary, entry_type) -> ActionEntry

Append a new entry to the log. Sequence number is auto-assigned
(next integer). Status defaults to ENTRY_PENDING.
"""
function add_entry!(log::ActionLog;
                    objective_id::String = "",
                    scoped_votes::Vector = Any[],
                    sure_votes::Vector = Any[],
                    unsure_votes::Vector = Any[],
                    prior_context::Vector{String} = String[],
                    dependencies::Vector{Int} = Int[],
                    confidence::Float64 = 0.0,
                    reserved_step::Int = 0,
                    is_supplementary::Bool = false,
                    entry_type::ActionEntryType = ENTRY_SURE,
                    scoped_mission::String = "")::ActionEntry
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
        confidence,
        reserved_step,
        is_supplementary,
        entry_type,
        scoped_mission,        # GRUG v8.2: sub-subject text
    )
    push!(log.entries, entry)
    return entry
end

"""
    next_pending!(log::ActionLog) -> Union{ActionEntry, Nothing}

Return the next ENTRY_PENDING entry whose dependencies are all ENTRY_DONE.
Entries are iterated in sequence_number order, which is now confidence-
ordered (highest confidence = lowest sequence_number = dispatched first).
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

"""
    all_sure_done(log::ActionLog) -> Bool

GRUG v8.2: Check whether ALL sure/low-confidence entries in the log are
either ENTRY_DONE or ENTRY_FAILED. This is the "cycle complete" gate —
the signal that tells AIML it's safe to commit the final response because
every sub-objective has been resolved.

Returns true if:
  - There are no sure/low-confidence entries at all (edge case), OR
  - Every ENTRY_SURE and ENTRY_LOW_CONFIDENCE entry has status DONE or FAILED

Additive entries are excluded — they're supplementary extras, not part of
the core answer. The system should not wait for additives before committing.
"""
function all_sure_done(log::ActionLog)::Bool
    core_entries = filter(e -> e.entry_type in (ENTRY_SURE, ENTRY_LOW_CONFIDENCE), log.entries)
    isempty(core_entries) && return true
    return all(e -> e.status in (ENTRY_DONE, ENTRY_FAILED), core_entries)
end

# ==============================================================================
# OUTPUT ASSEMBLY — JOIN ENTRIES IN RESERVED STEP ORDER WITH PREFIXES
# ==============================================================================

"""
    assemble_output!(log::ActionLog) -> String

Assemble the final scaffold output from all completed entries.

Entries are ordered by reserved_step (their final output position), NOT by
dispatch order. This ensures step coherence: each entry wrote to its own
reserved slot, and the final output reflects the intended reading order.

Formatting:
  - ENTRY_SURE entries: output as-is, in reserved_step order
  - ENTRY_LOW_CONFIDENCE entries: prefixed with "*Grug think this also important*\\n"
  - ENTRY_ADDITIVE entries: collected into a single block prefixed with
    "(Grug also think these infos maybe important)" and formatted as a
    bulleted list. Additives come AFTER all sure/low-confidence entries.

Failed or pending entries are skipped.
"""
function assemble_output!(log::ActionLog)::String
# REMINDER: ANTIMATCH DRAINS DO NOT EXIST. Antimatch was removed.
    # GRUG: Separate entries into sure+low_conf vs additive groups.
    # Sort each group by reserved_step for coherent output ordering.
    main_entries = ActionEntry[]
    additive_entries = ActionEntry[]

    for entry in log.entries
        entry.status !== ENTRY_DONE && continue
        if entry.entry_type == ENTRY_ADDITIVE
            push!(additive_entries, entry)
        else
            push!(main_entries, entry)
        end
    end

    # GRUG: Sort main entries by reserved_step (output position order)
    sort!(main_entries, by = e -> e.reserved_step)

    # GRUG: Build main output with prefixes
    parts = String[]
    for entry in main_entries
        if entry.entry_type == ENTRY_LOW_CONFIDENCE
            push!(parts, "*Grug think this also important*\n$(entry.output)")
        else
            push!(parts, entry.output)
        end
    end

    # GRUG: Additives come last as bulleted list with prefix
    # GRUG v8.7: DEDUP — skip additive entries whose output is too similar
    # to any main entry. Prevents duplicate content like "Sad is the color
    # of a gray sky" appearing in both the primary answer and the additive
    # side-channel. Similarity = substring check OR token-overlap ratio.
    if !isempty(additive_entries)
        sort!(additive_entries, by = e -> e.reserved_step)
        # Collect main output text for comparison
        main_texts = [lowercase(strip(e.output)) for e in main_entries]
        bullet_items = String[]
        for entry in additive_entries
            add_text = lowercase(strip(entry.output))
            is_dup = false
            for mt in main_texts
                if length(mt) > 20 && length(add_text) > 20
                    # Check 1: substring containment (exact)
                    if occursin(mt, add_text) || occursin(add_text, mt)
                        is_dup = true
                        break
                    end
                    # Check 2: token-overlap ratio (catches thesaurus-swapped
                    # duplicates like "The thread is:" vs "The relation:")
                    mt_tokens = Set(split(replace(mt, r"[^a-z0-9\s]" => "")))
                    add_tokens = Set(split(replace(add_text, r"[^a-z0-9\s]" => "")))
                    delete!(mt_tokens, "")
                    delete!(add_tokens, "")
                    if !isempty(mt_tokens) && !isempty(add_tokens)
                        overlap = length(intersect(mt_tokens, add_tokens))
                        ratio = overlap / min(length(mt_tokens), length(add_tokens))
                        if ratio > 0.75
                            is_dup = true
                            break
                        end
                    end
                end
            end
            if !is_dup
                push!(bullet_items, "- $(entry.output)")
            end
        end
        if !isempty(bullet_items)
            additive_block = "(Grug also think these infos maybe important)\n" * join(bullet_items, "\n")
            push!(parts, additive_block)
        end
    end

    return join(parts, "\n\n")
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
        conf_str = " conf=$(round(e.confidence, digits=3))"
        step_str = " step=$(e.reserved_step)"
        type_str = e.is_supplementary ? " [$(e.entry_type)]" : ""
        scoped_str = isempty(e.scoped_mission) ? "" : " scoped=\"$(first(e.scoped_mission, 40))$(length(e.scoped_mission) > 40 ? "..." : "")\""
        push!(lines, "  [$(e.sequence_number)] $obj_str | votes=$n_votes (sure=$n_sure unsure=$n_unsure)$conf_str$step_str$type_str | $status_str$(dep_str)$(ctx_str)$(out_str)$(scoped_str)")
    end
    return join(lines, "\n")
end

# ==============================================================================
# MODULATION — BUILD LOG FROM MULTIPART OBJECTIVES (CONFIDENCE-ORDERED)
# ===============================================================================

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
    _objective_confidence(obj) -> Float64

Get the primary vote's confidence from a MultipartObjective.
=#
function _objective_confidence(obj)::Float64
    return Float64(getfield(obj.primary, :confidence))
end

#=
    _vote_confidence(v) -> Float64

Get a vote's confidence regardless of its concrete type.
=#
function _vote_confidence(v)::Float64
    return Float64(getfield(v, :confidence))
end

#=
    _safe_multipart_group(v) -> String

Safely get multipart_group from a vote, returning "" if not available.
Some vote-like objects (e.g. from rejected_tier conversion) may not have
this field.
=#
function _safe_multipart_group(v)::String
    try
        return String(getfield(v, :multipart_group))
    catch
        return ""
    end
end

#=
    modulate_objectives!(log::ActionLog, objectives; prior_outputs, nonwinner_votes)

Build ActionLog entries from MultipartOrchestrator output.

v7.47 CONFIDENCE-ORDERED DISPATCH:
  ALL objectives (singletons AND multipart) are sorted by their primary
  vote's confidence in DESCENDING order. The highest-confidence objective
  gets dispatched first (sequence_number 1), the lowest last.

  Each entry gets a RESERVED STEP that determines its final output position
  in the scaffold. Sure entries get steps 1..N in confidence order.
  Low-confidence sure entries (below LOW_CONFIDENCE_FRACTION of the top
  confidence) also get reserved steps but are marked ENTRY_LOW_CONFIDENCE.
  Additive entries (non-winner votes) get reserved steps AFTER all sure
  entries and are marked ENTRY_ADDITIVE.

v7.48 NON-WINNER ADDITIVE ENTRIES:
  In addition to unsure_supports from multipart objectives, ALL non-winner
  votes (votes that didn't win any objective) are surfaced as ADDITIVE
  entries with the "(Grug also think these infos maybe important)" prefix.
  This is the "honest uncertainty tip off" — every vote that passed the
  confidence threshold but didn't win gets its own section so the user
  can see what else Grug considered. This makes the system's uncertainty
  VISIBLE instead of hidden.

  Non-winner votes come from the rejected_tier of select_aiml_votes and
  from subtop_tier coinflip losers. They are not part of step coherence —
  they're additive extras. But they ARE sorted by confidence (descending)
  so the most relevant alternatives appear first.

`prior_outputs` is an optional Dict{String, String} of objective_id -> output
from a previous cycle.
=#
function modulate_objectives!(log::ActionLog, objectives::AbstractVector;
# REMINDER: Relational triples in votes may contain sigils — dynamic, not literal.
                              prior_outputs::Dict{String, String} = Dict{String, String}(),
                              nonwinner_votes::AbstractVector = Any[],
                              scoped_text_of::Function = _ -> "")
    # GRUG v7.47: Sort ALL objectives by confidence (descending).
    # Highest confidence = dispatched first = sequence 1.
    sorted_objs = sort(objectives, by = _objective_confidence, rev = true)

    # GRUG: Find top confidence for low-confidence threshold calculation.
    top_conf = isempty(sorted_objs) ? 0.0 : _objective_confidence(sorted_objs[1])
    low_conf_threshold = top_conf * LOW_CONFIDENCE_FRACTION

    # GRUG: Track multipart entries for dependency computation.
    multipart_seq_numbers = Int[]
    multipart_chunk_sets  = Set{Int}[]

    # GRUG: Two passes:
    #   Pass 1: Create sure entries (primary + locked supports) with reserved steps
    #   Pass 2: Create additive entries (unsure votes + nonwinner votes) after all sure

    # ---- PASS 1: Sure entries (primary + locked supports) ----
    sure_step = 0

    for obj in sorted_objs
        sure = vcat([obj.primary], obj.locked_supports)
        all_votes = vcat(sure, obj.unsure_supports)
        obj_conf = _objective_confidence(obj)

        # GRUG: Determine entry type based on confidence relative to top.
        is_low_conf = obj_conf < low_conf_threshold
        etype = is_low_conf ? ENTRY_LOW_CONFIDENCE : ENTRY_SURE

        # GRUG: Compute chunk-aware dependencies for multipart objectives.
        my_chunks = _chunks_from_group_id(obj.group_id)
        deps = Int[]

        if obj.is_multipart
            if !isempty(my_chunks)
                for (idx, prior_seq) in enumerate(multipart_seq_numbers)
                    prior_chunks = multipart_chunk_sets[idx]
                    if !isempty(intersect(my_chunks, prior_chunks))
                        push!(deps, prior_seq)
                    end
                end
            else
                deps = copy(multipart_seq_numbers)
            end
        end

        # GRUG: Context from dependency entries.
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

        sure_step += 1

        # GRUG v8.2: Look up the sub-subject text for this objective.
        # For multipart objectives, this is the specific part of the input
        # that this sub-objective should answer. For singletons, it's empty
        # (the full mission text will be used as fallback in the dispatch loop).
        _scoped_text = scoped_text_of(obj.group_id)

        entry = add_entry!(log;
            objective_id    = obj.group_id,
            scoped_votes    = all_votes,
            sure_votes      = sure,
            unsure_votes    = Any[],
            prior_context   = prior_ctx,
            dependencies    = deps,
            confidence      = obj_conf,
            reserved_step   = sure_step,
            is_supplementary = is_low_conf,
            entry_type      = etype,
            scoped_mission  = _scoped_text,
        )

        if obj.is_multipart
            push!(multipart_seq_numbers, entry.sequence_number)
            push!(multipart_chunk_sets, my_chunks)
        end
    end

    # ---- PASS 2: Additive entries (non-winner votes + unsure supports) ----
    # GRUG v7.48: Additive entries come from TWO sources:
    #   1. unsure_supports from multipart objectives (existing)
    #   2. nonwinner_votes — ALL votes that didn't win any objective (NEW)
    # Both are marked ENTRY_ADDITIVE and presented as bulleted list with
    # "(Grug also think these infos maybe important)" prefix.

    additive_step = sure_step

    # GRUG: Collect ALL additive votes, deduplicated by node_id.
    additive_seen = Set{String}()
    additive_votes = Any[]

    # GRUG: First, unsure_supports from multipart objectives (existing behavior)
    for obj in sorted_objs
        for unsure_vote in obj.unsure_supports
            nid = string(getfield(unsure_vote, :node_id))
            nid in additive_seen && continue
            push!(additive_seen, nid)
            push!(additive_votes, unsure_vote)
        end
    end

    # GRUG v7.48: Then, nonwinner_votes — "honest uncertainty tip offs".
    # Sort by confidence (descending) for coherent presentation.
    sorted_nonwinners = sort(nonwinner_votes, by = v -> _vote_confidence(v), rev = true)
    for nw_vote in sorted_nonwinners
        nid = string(getfield(nw_vote, :node_id))
        nid in additive_seen && continue
        # GRUG: Skip if this node is already a primary in an objective
        # (defensive — it shouldn't be in nonwinner_votes if it won)
        is_primary = any(obj -> string(getfield(obj.primary, :node_id)) == nid, sorted_objs)
        is_primary && continue
        push!(additive_seen, nid)
        push!(additive_votes, nw_vote)
    end

    # GRUG: Create additive entries for all collected additive votes
    for additive_vote in additive_votes
        vote_conf = _vote_confidence(additive_vote)
        additive_step += 1

        # GRUG: Find which sure entry this additive vote might be associated with
        # for context carry-forward. Check scoped_votes or multipart_group.
        vote_nid = string(getfield(additive_vote, :node_id))
        deps = Int[]

        # GRUG: Check if this additive vote's node appears in any sure entry's scoped_votes
        for e in log.entries
            e.entry_type == ENTRY_ADDITIVE && continue
            for sv in e.scoped_votes
                if string(getfield(sv, :node_id)) == vote_nid
                    push!(deps, e.sequence_number)
                    break
                end
            end
            !isempty(deps) && break
        end

        # GRUG: If no scoped_vote match, check by objective_id from vote's multipart_group
        if isempty(deps)
    vote_group = _safe_multipart_group(additive_vote)
            if !isempty(vote_group)
                for e in log.entries
                    if e.objective_id == vote_group && e.entry_type != ENTRY_ADDITIVE
                        push!(deps, e.sequence_number)
                        break
                    end
                end
            end
        end

        # GRUG: Context from dependency entries.
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

        # GRUG v8.2: Look up scoped text for this additive entry if it has a group.
        _add_scoped = scoped_text_of(_safe_multipart_group(additive_vote))

        add_entry!(log;
            objective_id     = _safe_multipart_group(additive_vote),
            scoped_votes     = Any[additive_vote],
            sure_votes       = Any[],
            unsure_votes     = Any[additive_vote],
            prior_context    = prior_ctx,
            dependencies     = deps,
            confidence       = vote_conf,
            reserved_step    = additive_step,
            is_supplementary = true,
            entry_type       = ENTRY_ADDITIVE,
            scoped_mission   = _add_scoped,
        )
    end

    return log
end

end # module HippocampalModulator
