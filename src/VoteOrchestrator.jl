# ==============================================================================
# VoteOrchestrator.jl — GRUG Parallel Vote Firing & Orchestrator Layer
# ==============================================================================
# GRUG say: old scan go one rock at time. Too slow. New scan use many hand.
# GRUG say: but many hand fight over same rock = bad. So each hand get own Task
#           with unique name. No collision. No crash.
# GRUG say: 1000 is hard cap for active rocks. ALL firing counts:
#           - pattern scan fires
#           - drop-table relay fires
#           - lobe cascade fires
#           - attachment (NodeAttach) fires
# GRUG say: when lobe done firing, send DONE to orchestrator. Orchestrator wait
#           for DONE from all lobes before letting AIML pick winner.
# GRUG say: AIML pick by threshold. Strong votes go straight in. Weak votes
#           within threshold get coinflip, biased toward stronger ones.
# GRUG say: ALL sub-process = own Task with own name. NO SILENT FAILURES.
# ==============================================================================

module VoteOrchestrator

using Base.Threads
using Base.Threads: Atomic, atomic_add!, atomic_cas!, ReentrantLock, @spawn
using Random

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

# GRUG: One error type, carries message + context breadcrumb.
struct VoteOrchestratorError <: Exception
    message::String
    context::String
end

function throw_vo_error(msg::String, ctx::String = "unknown")
    throw(VoteOrchestratorError(msg, ctx))
end

# ==============================================================================
# CONSTANTS — GRUG put magic numbers in one place
# ==============================================================================

# GRUG: Hard cap on active rocks per scan cycle. Biological attention bottleneck.
# ALL firing types count toward this: scan, drop-table, cascade, attachments.
const ACTIVE_FIRE_CAP = 1000

# GRUG: Batch size for threaded fire. Each Task chews through one batch.
# Smaller = more parallelism but more overhead. 64 is sweet spot on most CPUs.
const FIRE_BATCH_SIZE = 64

# GRUG: Positive confidence threshold. Votes below this are ignored by AIML.
# Raw token+rel confidence floor for "this rock has real opinion".
const AIML_CONFIDENCE_THRESHOLD = 0.15

# GRUG: How close to max confidence to be "top". Votes within this window of
# the max confidence are the "top tier" and ALWAYS picked. No coinflip.
const AIML_TOP_TIER_WINDOW = 0.05

# GRUG: Coinflip base + strength bonus for sub-top votes within threshold.
# Mirrors engine.jl strength_biased_scan_coinflip formula so behavior is consistent.
const AIML_SUBTOP_BASE_PROB  = 0.20
const AIML_SUBTOP_BONUS_PROB = 0.70

# GRUG: Default timeout for DONE signal (seconds). If orchestrator waits this
# long without hearing DONE from all lobes, scream loud with timeout error.
const DONE_SIGNAL_TIMEOUT_S = 30.0

# ==============================================================================
# TASK DISPATCHER — unique non-colliding task IDs
# ==============================================================================

# GRUG: Global atomic counter. Every Task issuance gets unique name.
# No two Tasks share a name. No collision. Ever.
const _TASK_ID_COUNTER = Atomic{Int}(0)

# GRUG: Registry of active tasks by name. For diagnostics + graceful shutdown.
# Key = task_name, Value = (Task, issuer_context, timestamp).
const _TASK_REGISTRY      = Dict{String, Tuple{Task, String, Float64}}()
const _TASK_REGISTRY_LOCK = ReentrantLock()

"""
    next_task_id(prefix::String="task")::String

GRUG: Return next unique task name. Prefix is caller-chosen for readability.
Format: "<prefix>#<counter>". Guaranteed unique across whole process lifetime.
"""
function next_task_id(prefix::String = "task")::String
    if isempty(strip(prefix))
        throw_vo_error("Task prefix cannot be empty", "next_task_id")
    end
    id = atomic_add!(_TASK_ID_COUNTER, 1)
    return "$(prefix)#$(id)"
end

"""
    dispatch_task(f::Function, prefix::String; context::String="unknown")::Tuple{String, Task}

GRUG: Issue a new Task with unique non-colliding name. Registers in task table.
Returns (task_name, Task). Errors inside the task are caught by Julia's Task
error handling — caller can `fetch` or `wait` to surface them. NO SILENT FAILURES.

f must be a zero-argument function (closure).
"""
function dispatch_task(f::Function, prefix::String; context::String = "unknown")::Tuple{String, Task}
    name = next_task_id(prefix)
    # GRUG: Wrap f so errors inside Task carry context forward.
    wrapped = function()
        try
            return f()
        catch e
            # GRUG: Don't swallow. Re-throw wrapped so fetch() surfaces it.
            # Also log loudly so we never lose the error even if no one fetches.
            @error "[VoteOrchestrator] Task '$name' (context=$context) threw: $e"
            rethrow(e)
        finally
            # GRUG: Always unregister, even on error. No stale entries.
            lock(_TASK_REGISTRY_LOCK) do
                delete!(_TASK_REGISTRY, name)
            end
        end
    end
    t = @spawn wrapped()
    lock(_TASK_REGISTRY_LOCK) do
        _TASK_REGISTRY[name] = (t, context, time())
    end
    return (name, t)
end

"""
    list_active_tasks()::Vector{Tuple{String, String, Float64}}

GRUG: Diagnostic. Returns (task_name, context, age_seconds) for all live tasks.
"""
function list_active_tasks()::Vector{Tuple{String, String, Float64}}
    now_t = time()
    out = Tuple{String, String, Float64}[]
    lock(_TASK_REGISTRY_LOCK) do
        for (name, (_, ctx, ts)) in _TASK_REGISTRY
            push!(out, (name, ctx, now_t - ts))
        end
    end
    return out
end

# ==============================================================================
# FIRE COUNTER — atomic global cap enforcement across ALL fire types
# ==============================================================================

# GRUG: FireCounter is the single source of truth for "how many rocks have fired
# this cycle". Pattern scan, drop-table, lobe cascade, AND attachment relays all
# increment the SAME counter. When it hits ACTIVE_FIRE_CAP, ALL fires stop.
# This is the hard cap the user asked for.
mutable struct FireCounter
    active::Atomic{Int}      # GRUG: How many rocks have fired so far this cycle
    cap::Int                 # GRUG: Hard ceiling (default ACTIVE_FIRE_CAP)
    cycle_id::String         # GRUG: Unique id for this scan cycle (diagnostic)
end

"""
    FireCounter(cycle_id::String, cap::Int = ACTIVE_FIRE_CAP)

GRUG: Build a fresh fire counter for one scan cycle. Cap defaults to 1000.
"""
function FireCounter(cycle_id::String, cap::Int = ACTIVE_FIRE_CAP)
    if isempty(strip(cycle_id))
        throw_vo_error("FireCounter cycle_id cannot be empty", "FireCounter")
    end
    if cap <= 0
        throw_vo_error("FireCounter cap must be positive, got $cap", "FireCounter")
    end
    return FireCounter(Atomic{Int}(0), cap, cycle_id)
end

"""
    try_claim_fire_slot!(fc::FireCounter)::Bool

GRUG: Atomically try to claim ONE fire slot. Returns true if under cap (you fired!),
false if cap reached (you did NOT fire, caller must skip).

This is the function ALL firing paths must call before firing:
  - scan_specimens per-node fire
  - drop-table relay fire
  - lobe cascade fire
  - fire_attachments! per-attachment fire
"""
function try_claim_fire_slot!(fc::FireCounter)::Bool
    # GRUG: atomic_add! returns OLD value. If old < cap, we got a slot.
    # If old >= cap, we over-counted by 1 — decrement back for accurate reading.
    old = atomic_add!(fc.active, 1)
    if old >= fc.cap
        atomic_add!(fc.active, -1)
        return false
    end
    return true
end

"""
    current_fire_count(fc::FireCounter)::Int

GRUG: How many fires consumed so far? Read-only atomic snapshot.
"""
function current_fire_count(fc::FireCounter)::Int
    return fc.active[]
end

"""
    fire_cap_reached(fc::FireCounter)::Bool

GRUG: Has the hard cap been hit? True = stop all firing.
"""
function fire_cap_reached(fc::FireCounter)::Bool
    return fc.active[] >= fc.cap
end

# ==============================================================================
# DONE SIGNAL CHANNELS — per-lobe completion signalling
# ==============================================================================

# GRUG: DoneSignal is a tiny message wrapper sent on a Channel when a lobe
# finishes firing all its nodes for this cycle. The orchestrator waits on these
# from every participating lobe before letting AIML pick winners.
struct DoneSignal
    lobe_id::String          # GRUG: Which lobe finished
    fires_count::Int         # GRUG: How many of its rocks fired
    votes_count::Int         # GRUG: How many votes it produced
    elapsed_s::Float64       # GRUG: How long it took
    error::Union{Nothing, Exception}  # GRUG: nothing = clean, or caught error
end

"""
    make_done_channel(n_lobes::Int = 64)::Channel{DoneSignal}

GRUG: Build a bounded Channel large enough to hold one DONE from every lobe.
Bounded so if orchestrator is slow, lobes back-pressure instead of eating RAM.
"""
function make_done_channel(n_lobes::Int = 64)::Channel{DoneSignal}
    if n_lobes <= 0
        throw_vo_error("n_lobes must be positive, got $n_lobes", "make_done_channel")
    end
    return Channel{DoneSignal}(n_lobes)
end

"""
    send_done!(ch::Channel{DoneSignal}, sig::DoneSignal)

GRUG: Put DONE signal on channel. Non-blocking as long as channel has room.
"""
function send_done!(ch::Channel{DoneSignal}, sig::DoneSignal)
    put!(ch, sig)
end

"""
    wait_for_done(ch::Channel{DoneSignal}, expected::Int;
                  timeout_s::Float64 = DONE_SIGNAL_TIMEOUT_S)::Vector{DoneSignal}

GRUG: Block until `expected` DONE signals have arrived. Throws on timeout.
Returns the collected DoneSignal vector so orchestrator can inspect per-lobe stats.

Implementation uses a polling loop with short sleep increments. Simple and
collision-free — no racing Tasks, no closed-channel shenanigans.
"""
function wait_for_done(ch::Channel{DoneSignal}, expected::Int;
                       timeout_s::Float64 = DONE_SIGNAL_TIMEOUT_S)::Vector{DoneSignal}
    if expected <= 0
        throw_vo_error("wait_for_done expected must be positive, got $expected", "wait_for_done")
    end
    # GRUG: Short poll interval — tight enough to be responsive, loose enough
    # to avoid busy-spinning the scheduler. 10ms is a good biological heartbeat.
    poll_s   = 0.010
    collected = DoneSignal[]
    deadline  = time() + timeout_s
    while length(collected) < expected
        if time() >= deadline
            throw_vo_error(
                "wait_for_done TIMEOUT after $(round(timeout_s, digits=2))s. Got $(length(collected))/$expected DONE signals.",
                "wait_for_done"
            )
        end
        # GRUG: Non-blocking drain — pull every signal currently available.
        drained = false
        while isready(ch)
            push!(collected, take!(ch))
            drained = true
            if length(collected) >= expected
                break
            end
        end
        if length(collected) >= expected
            break
        end
        # GRUG: If we didn't drain anything, sleep briefly then retry.
        # Sleep shorter than the remaining deadline so we never overshoot.
        if !drained
            remaining = deadline - time()
            sleep(max(0.0, min(poll_s, remaining)))
        end
    end
    return collected
end

# ==============================================================================
# PARALLEL FIRE — batched threaded scan-and-fire with shared FireCounter
# ==============================================================================

"""
    parallel_fire_batches(node_ids::Vector{String},
                         fc::FireCounter,
                         fire_one::Function;
                         batch_size::Int = FIRE_BATCH_SIZE,
                         task_prefix::String = "fire_batch")::Vector{Any}

GRUG: Split node_ids into chunks of `batch_size`, dispatch each chunk to its own
Task (unique name, no collision). Each Task calls `fire_one(node_id, fc)` for
each id in its batch. `fire_one` MUST honor the FireCounter — call
try_claim_fire_slot!(fc) before firing, skip if false, break out of loop when
fire_cap_reached(fc).

fire_one signature: (node_id::String, fc::FireCounter) -> Union{Nothing, T}
  Return nothing to indicate skip (no vote). Return T to contribute to results.

Returns a flat Vector of all non-nothing results from all batches, in no
guaranteed order (parallel). Errors from any batch are re-raised via fetch.
"""
function parallel_fire_batches(node_ids::Vector{String},
                               fc::FireCounter,
                               fire_one::Function;
                               batch_size::Int = FIRE_BATCH_SIZE,
                               task_prefix::String = "fire_batch")::Vector{Any}
    if batch_size <= 0
        throw_vo_error("batch_size must be positive, got $batch_size", "parallel_fire_batches")
    end
    if isempty(node_ids)
        return Any[]
    end

    # GRUG: Carve id list into chunks. Each chunk goes to its own Task.
    chunks = Vector{Vector{String}}()
    for i in 1:batch_size:length(node_ids)
        push!(chunks, node_ids[i:min(i + batch_size - 1, length(node_ids))])
    end

    # GRUG: Dispatch each chunk. Unique task name per chunk.
    dispatched = Vector{Tuple{String, Task}}()
    for (idx, chunk) in enumerate(chunks)
        # GRUG: Closure captures chunk + fc. Each task independent.
        chunk_copy = copy(chunk)  # GRUG: defensive copy so closure not race
        task_name, t = dispatch_task(
            () -> begin
                local_results = Any[]
                for nid in chunk_copy
                    # GRUG: Short-circuit on cap — save work.
                    if fire_cap_reached(fc)
                        break
                    end
                    result = fire_one(nid, fc)
                    if !isnothing(result)
                        push!(local_results, result)
                    end
                end
                return local_results
            end,
            "$(task_prefix)_$(idx)";
            context = "parallel_fire_batches"
        )
        push!(dispatched, (task_name, t))
    end

    # GRUG: Fetch all results. fetch() re-raises errors from Tasks.
    all_results = Any[]
    for (name, t) in dispatched
        try
            batch_results = fetch(t)
            append!(all_results, batch_results)
        catch e
            # GRUG: One batch exploded. Scream with batch name so we can debug.
            throw_vo_error(
                "parallel_fire_batches: batch Task '$name' failed: $e",
                "parallel_fire_batches"
            )
        end
    end
    return all_results
end

# ==============================================================================
# AIML VOTE SELECTION — threshold + top-N + strength-biased coinflip
# ==============================================================================

"""
    VoteCandidate — minimal protocol for AIML vote selection

GRUG: Input to select_aiml_votes. Must carry at least node_id, confidence,
and strength. VoteOrchestrator doesn't know about engine's Vote type, so
this wrapper keeps the module decoupled. Caller builds these from Vote structs.
"""
struct VoteCandidate
    node_id::String
    confidence::Float64
    strength::Float64        # GRUG: Node strength (0.0 to STRENGTH_CAP, usually 10.0)
    strength_cap::Float64    # GRUG: Cap used for normalization (default 10.0)
end

function VoteCandidate(node_id::String, confidence::Float64, strength::Float64;
                       strength_cap::Float64 = 10.0)
    if isempty(strip(node_id))
        throw_vo_error("VoteCandidate node_id cannot be empty", "VoteCandidate")
    end
    if strength_cap <= 0
        throw_vo_error("VoteCandidate strength_cap must be positive, got $strength_cap", "VoteCandidate")
    end
    return VoteCandidate(node_id, confidence, strength, strength_cap)
end

"""
    strength_biased_vote_coinflip(vc::VoteCandidate)::Bool

GRUG: Same formula as engine.strength_biased_scan_coinflip. Strong nodes biased
to be kept. Weak nodes still have ~20% base chance.
  base = 0.20
  bonus = 0.70 * (strength / cap)
  prob  = base + bonus (clamped to [0, 1])
"""
function strength_biased_vote_coinflip(vc::VoteCandidate)::Bool
    p = AIML_SUBTOP_BASE_PROB + (vc.strength / vc.strength_cap) * AIML_SUBTOP_BONUS_PROB
    return rand() < clamp(p, 0.0, 1.0)
end

"""
    select_aiml_votes(candidates::Vector{VoteCandidate};
                     threshold::Float64 = AIML_CONFIDENCE_THRESHOLD,
                     top_window::Float64 = AIML_TOP_TIER_WINDOW)
                     ::Tuple{Vector{VoteCandidate}, Vector{VoteCandidate}, Vector{VoteCandidate}}

GRUG: AIML picks votes past confidence threshold. Within threshold:
  - TOP TIER: votes within `top_window` of the max confidence go straight in.
              No coinflip. They are the strongest opinions.
  - SUB-TOP:  votes below top_window but above threshold get a strength-biased
              coinflip. Strong neurons more likely kept.
  - REJECTED: below threshold or lost coinflip.

Returns (top_votes, kept_subtop_votes, rejected_votes). Caller combines
top + subtop to feed into final orchestrator.

Throws on empty candidates — NO SILENT FAILURES.
"""
function select_aiml_votes(candidates::Vector{VoteCandidate};
                           threshold::Float64 = AIML_CONFIDENCE_THRESHOLD,
                           top_window::Float64 = AIML_TOP_TIER_WINDOW)::Tuple{Vector{VoteCandidate}, Vector{VoteCandidate}, Vector{VoteCandidate}}
    if isempty(candidates)
        throw_vo_error("select_aiml_votes received zero candidates. Cave is silent.", "select_aiml_votes")
    end
    if threshold < 0.0
        throw_vo_error("threshold must be >= 0, got $threshold", "select_aiml_votes")
    end
    if top_window < 0.0
        throw_vo_error("top_window must be >= 0, got $top_window", "select_aiml_votes")
    end

    # GRUG: First pass — filter by threshold. Everything below is auto-rejected.
    above_threshold = VoteCandidate[]
    rejected        = VoteCandidate[]
    for vc in candidates
        if vc.confidence >= threshold
            push!(above_threshold, vc)
        else
            push!(rejected, vc)
        end
    end

    if isempty(above_threshold)
        # GRUG: Nothing passed threshold. AIML has no voice. Not a fatal error
        # at this layer — caller decides what to do (often: degrade gracefully).
        return (VoteCandidate[], VoteCandidate[], rejected)
    end

    # GRUG: Find max confidence among threshold-passers.
    max_conf = maximum(vc.confidence for vc in above_threshold)

    # GRUG: Top tier = within top_window of max. Selected directly, no coinflip.
    # Sub-top tier = below top but >= threshold. Coinflip with strength bias.
    top_tier    = VoteCandidate[]
    subtop_tier = VoteCandidate[]
    for vc in above_threshold
        if vc.confidence >= max_conf - top_window
            push!(top_tier, vc)
        else
            push!(subtop_tier, vc)
        end
    end

    # GRUG: Sub-top coinflip. Strong neurons more likely to survive.
    kept_subtop = VoteCandidate[]
    for vc in subtop_tier
        if strength_biased_vote_coinflip(vc)
            push!(kept_subtop, vc)
        else
            push!(rejected, vc)
        end
    end

    return (top_tier, kept_subtop, rejected)
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export VoteOrchestratorError
export ACTIVE_FIRE_CAP, FIRE_BATCH_SIZE
export AIML_CONFIDENCE_THRESHOLD, AIML_TOP_TIER_WINDOW
export AIML_SUBTOP_BASE_PROB, AIML_SUBTOP_BONUS_PROB
export DONE_SIGNAL_TIMEOUT_S

# Task dispatch
export next_task_id, dispatch_task, list_active_tasks

# Fire counter
export FireCounter, try_claim_fire_slot!, current_fire_count, fire_cap_reached

# DONE channels
export DoneSignal, make_done_channel, send_done!, wait_for_done

# Parallel fire
export parallel_fire_batches

# AIML vote selection
export VoteCandidate, select_aiml_votes, strength_biased_vote_coinflip

end # module VoteOrchestrator