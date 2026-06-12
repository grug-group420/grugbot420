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

# GRUG: Dedicated timeout error. Lets callers distinguish timeout from
# other VoteOrchestratorErrors cleanly (for retries, fallbacks, etc).
struct TaskTimeoutError <: Exception
    task_name::String
    context::String
    timeout_s::Float64
end

function Base.showerror(io::IO, e::TaskTimeoutError)
    print(io, "TaskTimeoutError: Task '$(e.task_name)' (context=$(e.context)) exceeded timeout of $(round(e.timeout_s, digits=3))s")
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

# GRUG v7.16.0: TWO-TIER CONFIDENCE FLOORS.
# Raised floor because v7.15.x floor of 0.15 let too many weak voices through,
# producing "explain, explain, explain, describe, describe" babble when 8 weak
# nodes tied at 0.16. New scheme:
#
#   conf >= AIML_TOP_TIER_WINDOW distance from max  ->  TOP BAND  (drives claim + voice)
#   AIML_SUPPORT_FLOOR <= conf < top                ->  SUPPORT BAND  ("Grug also sure of")
#   AIML_CONFIDENCE_THRESHOLD <= conf < support     ->  SUBTOP BAND   (coinflip, hedge only)
#   conf < AIML_CONFIDENCE_THRESHOLD                ->  REJECTED
#
# Biology: only loud confident voices lead. Mid-confidence voices support AFTER
# the main claim. Below floor is silence. NO SILENT FAILURES -- dropped votes
# are still reported in the (top_tier, subtop_tier, rejected_tier) tuple so
# telemetry stays honest.
const AIML_CONFIDENCE_THRESHOLD = 0.20

# GRUG: Support floor. Votes >= this AND below top become "Grug also sure of"
# supporting claims, rendered AFTER the main claim (not inline, not as hedge).
# Votes between THRESHOLD and SUPPORT_FLOOR still exist but only appear as a
# compact hedge -- they were not strong enough to stand as their own claim.
const AIML_SUPPORT_FLOOR = 0.35

# GRUG v7.16.1: RELATION SCORE FLOOR for the support band.
# Even a loud vote (past SUPPORT_FLOOR) must have a detectable SEMANTIC OR
# STRUCTURAL LINK to the primary winner before it can lock in as "Grug also
# sure of". Without a link, a loud vote about an unrelated topic would sneak
# in as pretend-support -- e.g. primary says "gravity pulls objects" and an
# unrelated loud vote injects "bees pollinate flowers" as supposed support.
# That's non-sequitur riding on confidence coattails. This floor demands an
# actual link. Score below the floor -> demoted to reliability-flagged hedge.
# See `relation_score` in Main.jl for the scoring weights.
const AIML_SUPPORT_RELATION_FLOOR = 2

# GRUG: How close to max confidence to be "top". Votes within this window of
# the max confidence are the "top tier" and ALWAYS picked. No coinflip.
#
# GRUG v7.16.3: This constant is RE-SCOPED -- it no longer decides which
# votes enter the top band (that's now `AIML_TOP_LOCKIN_FLOOR` below). Instead,
# this window is used ONLY by the tie-break step inside the orchestrator:
# among all top-tier lock-ins, votes within this confidence-window of the
# argmax-primary count as "tied alternatives" (drives UNSURE certainty in
# the AIML payload). Votes in the top tier but outside the window are
# still primary-strength claims, they just aren't "tied" with the primary.
const AIML_TOP_TIER_WINDOW = 0.05

# GRUG v7.16+: SPARSE-ACTIVE FIRE FLOOR.
# A node whose post-weighting fire confidence is below this floor does NOT
# fire at all. The gate runs at the engine fire site (and the attachment
# relay fire site) — BEFORE the vote is added to the pool, BEFORE any
# downstream lock-in / orchestration / AIML logic gets to see it.
#
# Why this lives at the fire site, not the AIML layer:
#   - Filtering at AIML means every sub-threshold vote still claims a
#     fire-counter slot (against the 1000-cap), still gets thrown into
#     parallel batch results, still inflates the orchestrator's working
#     set, and only THEN gets discarded. That's wasted attention.
#   - Filtering at the fire site means the pool stays lean: the attention
#     budget is spent on votes that have a real chance of mattering.
#   - This is the "sparse-active" property: only nodes whose evidence
#     clears a minimum activation floor compete for the pool. Below the
#     floor, the node is effectively silent on this cycle.
#
# Threshold choice (0.20):
#   - Well below AIML_TOP_LOCKIN_FLOOR (0.50) — cannot interfere with the
#     lock-in machinery. A vote that COULD have locked in is not at risk.
#   - Well above the relay hard floor (0.10) — that floor exists to keep
#     biological-noise voices in the conversation, but a relay vote at
#     0.10–0.19 is pure noise and earns its silence here.
#   - Above the cheap-scan PASS threshold post-jitter (0.6 raw before
#     length-normalization yields ~0.15–0.30 in token_conf land), so a
#     legitimate weak match still has a chance to clear if the scan was
#     real evidence.
# GRUG v7.23: SPARSE_ACTIVE_FIRE_FLOOR set to 0.0.
# Confidence is the ONLY gate now. The lock-in floor (AIML_TOP_LOCKIN_FLOOR)
# is the authoritative threshold for orchestration. This pre-scan floor was
# culling weak matches before they even got a chance to accumulate relational
# confidence, causing stochastic failures where nodes with good relational
# overlap but low token_conf were sometimes kept and sometimes dropped.
const SPARSE_ACTIVE_FIRE_FLOOR = 0.0

# GRUG v7.16+: SPARSE-ACTIVE FIRE TELEMETRY.
# Atomic counter incremented every time the floor culls a fire. Read with
# `get_sparse_active_skip_count()` for diagnostics; reset with
# `reset_sparse_active_skip_count!()`. Per-cycle interpretation is the
# caller's responsibility (e.g. Main.jl can snapshot before/after a scan).
const _SPARSE_ACTIVE_SKIP_COUNT = Threads.Atomic{Int}(0)

"""
    should_fire_sparse_active(confidence::Real)::Bool

GRUG v7.23: Always returns true for finite confidence. The sparse-active floor
is now 0.0, so the only rejection is NaN/Inf. Confidence decides everything
at the lock-in stage, not here.
"""
function should_fire_sparse_active(confidence::Real)::Bool
    return isfinite(confidence)
end

"""
    tally_sparse_active_skip!()

GRUG: Increment the global "fires culled by sparse-active floor" counter.
Atomic — safe to call from parallel fire batches.
"""
function tally_sparse_active_skip!()
    Threads.atomic_add!(_SPARSE_ACTIVE_SKIP_COUNT, 1)
    return nothing
end

"""
    get_sparse_active_skip_count()::Int

GRUG: Read the current skip count. Useful for tests and per-cycle
telemetry deltas. Does NOT reset.
"""
get_sparse_active_skip_count() = _SPARSE_ACTIVE_SKIP_COUNT[]

"""
    reset_sparse_active_skip_count!()

GRUG: Reset the skip counter to 0. Tests use this to isolate cycles.
"""
function reset_sparse_active_skip_count!()
    Threads.atomic_xchg!(_SPARSE_ACTIVE_SKIP_COUNT, 0)
    return nothing
end

# GRUG v7.16.3: ABSOLUTE TOP-TIER LOCK-IN FLOOR.
# Replaces the old "within 0.05 of max" relative gate. A vote enters TOP tier
# when its COMBINED SCORE (confidence + semantic_weight * linkage_to_peers)
# meets or exceeds this floor. Simple questions: only high-confidence votes
# lock in, just like before. Complex questions: multiple strong peers can all
# lock in together, because the linkage bonus lifts borderline-confidence
# votes that are semantically tied to the cluster. See Main.jl
# `_combined_lockin_score` for the exact formula.
const AIML_TOP_LOCKIN_FLOOR = 0.50

# GRUG v7.16.3: SEMANTIC WEIGHT for the combined lock-in score.
# combined = confidence + AIML_SEMANTIC_WEIGHT * normalized_linkage_field
# A weight of 0.15 means the semantic linkage axis can contribute up to 0.15
# toward crossing the lock-in floor. Tunable; 0.15 was chosen so a quiet
# well-linked vote (conf ~0.35, linkage 1.0) just crosses at 0.50, while
# confidence alone at 0.50 always locks regardless of linkage.
const AIML_SEMANTIC_WEIGHT = 0.15

# GRUG v7.16.3: NORMALIZATION DIVISOR for relation_score linkage.
# Max possible raw relation_score is roughly 12 (see Main.jl relation_score
# docstring: group+3 + attach+3 + same-lobe+2 + triples+2 + action-class+1 +
# pattern-class+1 = 12). We divide the measured max-linkage by this to get
# a normalized value in [0.0, 1.0] before weighting. If the scoring axes are
# ever extended, BUMP THIS so the weighting stays calibrated.
const AIML_RELATION_SCORE_MAX = 12

# GRUG: Coinflip base + strength bonus for sub-top votes within threshold.
# Mirrors engine.jl strength_biased_scan_coinflip formula so behavior is consistent.
const AIML_SUBTOP_BASE_PROB  = 0.20
const AIML_SUBTOP_BONUS_PROB = 0.70

# GRUG: Default timeout for DONE signal (seconds). If orchestrator waits this
# long without hearing DONE from all lobes, scream loud with timeout error.
const DONE_SIGNAL_TIMEOUT_S = 30.0

# GRUG: Default per-Task timeout for sub-processes (seconds).
# Fire batches, DONE waits, AIML selection all inherit this unless overridden.
# 15s is generous — typical scan batch finishes in <100ms. Timeout exists to
# catch DEADLOCK or runaway loops, not to cancel normal work.
const DEFAULT_TASK_TIMEOUT_S = 15.0

# GRUG: Per-batch fire timeout. Scan pattern match on one 64-node batch should
# finish in well under a second. 5s is a hard ceiling.
const FIRE_BATCH_TIMEOUT_S = 5.0

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
    dispatch_task(f::Function, prefix::String;
                  context::String = "unknown",
                  timeout_s::Union{Nothing, Float64} = nothing)::Tuple{String, Task}

GRUG: Issue a new Task with unique non-colliding name. Registers in task table.
Returns (task_name, Task). Errors inside the task are caught by Julia's Task
error handling — caller can `fetch` or `wait` to surface them. NO SILENT FAILURES.

f must be a zero-argument function (closure).

TIMEOUT: If `timeout_s` is provided, a guardian Task is spawned alongside the
work Task. If the work Task hasn't finished by the deadline, caller code that
uses `fetch_with_timeout` will throw TaskTimeoutError. The work Task itself
cannot be forcibly killed (Julia doesn't support Task cancellation), but the
guardian lets us surface the timeout cleanly to callers.

Use `dispatch_task_with_timeout` or `fetch_with_timeout` for easy timeout
enforcement at the call site. Raw `fetch()` always ignores timeout.
"""
function dispatch_task(f::Function, prefix::String;
                       context::String = "unknown",
                       timeout_s::Union{Nothing, Float64} = nothing)::Tuple{String, Task}
    if !isnothing(timeout_s) && timeout_s <= 0
        throw_vo_error("dispatch_task timeout_s must be positive if given, got $timeout_s", "dispatch_task")
    end
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
            # GRUG: Always unregister, even on error. No stale entries in
            # either the registry or the deadline map.
            lock(_TASK_REGISTRY_LOCK) do
                delete!(_TASK_REGISTRY, name)
                delete!(_TASK_DEADLINES, name)
            end
        end
    end
    t = @spawn wrapped()
    lock(_TASK_REGISTRY_LOCK) do
        # GRUG: Store timeout deadline too (nothing if none).
        deadline = isnothing(timeout_s) ? nothing : time() + timeout_s
        _TASK_REGISTRY[name] = (t, context, time())
        _TASK_DEADLINES[name] = (deadline, timeout_s, context)
    end
    return (name, t)
end

# GRUG: Parallel deadline map. Same lock as _TASK_REGISTRY so reads/writes
# stay consistent. Value = (deadline_time_or_nothing, timeout_s_or_nothing, context).
const _TASK_DEADLINES = Dict{String, Tuple{Union{Nothing, Float64}, Union{Nothing, Float64}, String}}()

"""
    fetch_with_timeout(name::String, t::Task;
                      timeout_s::Union{Nothing, Float64} = nothing)::Any

GRUG: Fetch the result of a Task with an optional timeout. If timeout expires
before the Task finishes, throws TaskTimeoutError. If Task throws internally,
original exception is re-raised. NO SILENT FAILURES.

If `timeout_s` is nothing, uses the timeout registered at dispatch time. If
neither is set, behaves like plain `fetch` (blocks forever on runaway Task).
"""
function fetch_with_timeout(name::String, t::Task;
                           timeout_s::Union{Nothing, Float64} = nothing)::Any
    # GRUG: Resolve effective timeout — explicit arg > registered deadline > none.
    effective = timeout_s
    if isnothing(effective)
        lock(_TASK_REGISTRY_LOCK) do
            if haskey(_TASK_DEADLINES, name)
                _, reg_timeout, _ = _TASK_DEADLINES[name]
                effective = reg_timeout
            end
        end
    end

    if isnothing(effective)
        # GRUG: No timeout configured anywhere. Plain fetch.
        return fetch(t)
    end

    # GRUG: Poll Task state with short sleep until done or deadline hits.
    # Cheap for fast Tasks (istaskdone immediate true → fetch returns).
    # Safe for slow Tasks (deadline check each loop).
    deadline = time() + effective
    poll_s   = 0.005
    while !istaskdone(t)
        if time() >= deadline
            # GRUG: Timeout hit. Look up context for a useful error message.
            ctx = lock(_TASK_REGISTRY_LOCK) do
                haskey(_TASK_DEADLINES, name) ? _TASK_DEADLINES[name][3] : "unknown"
            end
            throw(TaskTimeoutError(name, ctx, effective))
        end
        sleep(min(poll_s, max(0.0, deadline - time())))
    end
    # GRUG: Task finished in time. fetch will either return value or rethrow
    # the Task's own exception. We want that behavior.
    return fetch(t)
end

"""
    dispatch_task_with_timeout(f::Function, prefix::String,
                              timeout_s::Float64;
                              context::String = "unknown")::Tuple{String, Task}

GRUG: Convenience — dispatch + guaranteed timeout. Equivalent to
`dispatch_task(f, prefix; context=context, timeout_s=timeout_s)`.
Caller still uses `fetch_with_timeout(name, t)` to surface TaskTimeoutError.
"""
function dispatch_task_with_timeout(f::Function, prefix::String, timeout_s::Float64;
                                    context::String = "unknown")::Tuple{String, Task}
    if timeout_s <= 0
        throw_vo_error("dispatch_task_with_timeout timeout_s must be positive, got $timeout_s", "dispatch_task_with_timeout")
    end
    return dispatch_task(f, prefix; context = context, timeout_s = timeout_s)
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
                         task_prefix::String = "fire_batch",
                         batch_timeout_s::Float64 = FIRE_BATCH_TIMEOUT_S)::Vector{Any}

GRUG: Split node_ids into chunks of `batch_size`, dispatch each chunk to its own
Task (unique name, no collision, per-batch timeout). Each Task calls
`fire_one(node_id, fc)` for each id in its batch. `fire_one` MUST honor the
FireCounter — call try_claim_fire_slot!(fc) before firing, skip if false,
break out of loop when fire_cap_reached(fc).

fire_one signature: (node_id::String, fc::FireCounter) -> Union{Nothing, T}
  Return nothing to indicate skip (no vote). Return T to contribute to results.

TIMEOUT: Each batch Task is given `batch_timeout_s` seconds. If any batch
blows the deadline, parallel_fire_batches throws TaskTimeoutError naming the
offending batch. This prevents a single stuck Task from halting the whole
scan — caller gets a loud signal instead of a silent hang. NO SILENT FAILURES.

Returns a flat Vector of all non-nothing results from all batches, in no
guaranteed order (parallel). Errors from any batch are re-raised via fetch.
"""
function parallel_fire_batches(node_ids::Vector{String},
                               fc::FireCounter,
                               fire_one::Function;
                               batch_size::Int = FIRE_BATCH_SIZE,
                               task_prefix::String = "fire_batch",
                               batch_timeout_s::Float64 = FIRE_BATCH_TIMEOUT_S)::Vector{Any}
    if batch_size <= 0
        throw_vo_error("batch_size must be positive, got $batch_size", "parallel_fire_batches")
    end
    if batch_timeout_s <= 0
        throw_vo_error("batch_timeout_s must be positive, got $batch_timeout_s", "parallel_fire_batches")
    end
    if isempty(node_ids)
        return Any[]
    end

    # GRUG: Carve id list into chunks. Each chunk goes to its own Task.
    chunks = Vector{Vector{String}}()
    for i in 1:batch_size:length(node_ids)
        push!(chunks, node_ids[i:min(i + batch_size - 1, length(node_ids))])
    end

    # GRUG: Dispatch each chunk. Unique task name per chunk. Per-batch timeout
    # registered via dispatch_task so fetch_with_timeout can enforce it.
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
            context = "parallel_fire_batches",
            timeout_s = batch_timeout_s
        )
        push!(dispatched, (task_name, t))
    end

    # GRUG: Fetch all results with timeout. fetch_with_timeout re-raises both
    # Task-internal errors AND TaskTimeoutError. Either way, caller sees loud.
    all_results = Any[]
    for (name, t) in dispatched
        try
            batch_results = fetch_with_timeout(name, t; timeout_s = batch_timeout_s)
            append!(all_results, batch_results)
        catch e
            # GRUG: Batch explode or timeout — both surface here. Scream with
            # batch name so we can debug. TaskTimeoutError preserved via chain
            # because we include the original exception string.
            if e isa TaskTimeoutError
                # GRUG: Re-raise directly so callers can catch TaskTimeoutError.
                rethrow(e)
            end
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

GRUG v7.23: REMOVED stochastic coinflip. Confidence is the ONLY gate for
orchestration. If a vote's confidence crosses the lock-in floor, it's in.
If it doesn't, it's out. No lottery. Strength still affects node growth
(bump_strength!) but does NOT gate whether a vote survives selection.

Old behavior: 20-90% survival chance based on strength in sub-top/hedge
bands. This caused stochastic output where the same input produced different
responses on different runs — sometimes a knowledge vote survived the
coinflip and rendered, sometimes it didn't, even with identical confidence.
"""
function strength_biased_vote_coinflip(vc::VoteCandidate)::Bool
    return true  # v7.23: Confidence decides, not a coinflip.
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

"""
    select_aiml_votes_banded(candidates::Vector{VoteCandidate};
                             threshold::Float64     = AIML_CONFIDENCE_THRESHOLD,
                             support_floor::Float64 = AIML_SUPPORT_FLOOR,
                             top_window::Float64    = AIML_TOP_TIER_WINDOW)
        ::NamedTuple

GRUG v7.16.0: THREE-BAND vote splitter. Unlike the two-band `select_aiml_votes`,
this function carves the survivors into three semantic bands:

  - `top`:     confidence within `top_window` of max. Drives primary claim.
  - `support`: confidence >= `support_floor` AND below top. Renders AFTER the
               main claim as "Grug also sure of ..." supporting confident voices.
  - `hedge`:   `threshold` <= confidence < `support_floor`. Strength-biased
               coinflip decides survival; survivors render as a compact hedge
               only. These are the "quiet voices in the room" -- heard, not led by.
  - `rejected`: below `threshold` OR lost the hedge coinflip.

Returns a NamedTuple with fields `:top, :support, :hedge, :rejected`. Using
NamedTuple (not positional) so callers never confuse band order. NO SILENT
FAILURES -- throws on empty input or invalid floors.
"""
function select_aiml_votes_banded(candidates::Vector{VoteCandidate};
                                  threshold::Float64     = AIML_CONFIDENCE_THRESHOLD,
                                  support_floor::Float64 = AIML_SUPPORT_FLOOR,
                                  top_window::Float64    = AIML_TOP_TIER_WINDOW)
    if isempty(candidates)
        throw_vo_error("select_aiml_votes_banded received zero candidates. Cave is silent.",
                       "select_aiml_votes_banded")
    end
    if threshold < 0.0
        throw_vo_error("threshold must be >= 0, got $threshold", "select_aiml_votes_banded")
    end
    if support_floor < threshold
        throw_vo_error("support_floor ($support_floor) must be >= threshold ($threshold) -- " *
                       "support band sits ABOVE the hedge band.",
                       "select_aiml_votes_banded")
    end
    if top_window < 0.0
        throw_vo_error("top_window must be >= 0, got $top_window", "select_aiml_votes_banded")
    end

    # GRUG: First pass -- split by threshold. Below floor = gone, no recovery.
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
        # GRUG: Nothing cleared the floor. Caller (orchestrator) handles fallback.
        return (top = VoteCandidate[], support = VoteCandidate[],
                hedge = VoteCandidate[], rejected = rejected)
    end

    max_conf = maximum(vc.confidence for vc in above_threshold)
    top_boundary = max_conf - top_window

    # GRUG: Carve the three bands.
    top_tier     = VoteCandidate[]
    support_tier = VoteCandidate[]
    hedge_tier   = VoteCandidate[]
    for vc in above_threshold
        if vc.confidence >= top_boundary
            push!(top_tier, vc)
        elseif vc.confidence >= support_floor
            push!(support_tier, vc)
        else
            push!(hedge_tier, vc)
        end
    end

    # GRUG: Hedge band gets the old strength-biased coinflip. Strong weak-voters
    # more likely to survive to hedge. Losers rejected with honest accounting.
    kept_hedge = VoteCandidate[]
    for vc in hedge_tier
        if strength_biased_vote_coinflip(vc)
            push!(kept_hedge, vc)
        else
            push!(rejected, vc)
        end
    end

    return (top = top_tier, support = support_tier,
            hedge = kept_hedge, rejected = rejected)
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export VoteOrchestratorError, TaskTimeoutError
export ACTIVE_FIRE_CAP, FIRE_BATCH_SIZE
export AIML_CONFIDENCE_THRESHOLD, AIML_TOP_TIER_WINDOW, AIML_SUPPORT_FLOOR
export AIML_SUPPORT_RELATION_FLOOR
export AIML_TOP_LOCKIN_FLOOR, AIML_SEMANTIC_WEIGHT, AIML_RELATION_SCORE_MAX
export AIML_SUBTOP_BASE_PROB, AIML_SUBTOP_BONUS_PROB
export DONE_SIGNAL_TIMEOUT_S, DEFAULT_TASK_TIMEOUT_S, FIRE_BATCH_TIMEOUT_S

# Sparse-active fire gate (enforced at the engine fire site, not in AIML layer)
export SPARSE_ACTIVE_FIRE_FLOOR
export should_fire_sparse_active, tally_sparse_active_skip!
export get_sparse_active_skip_count, reset_sparse_active_skip_count!

# Task dispatch (with timeouts)
export next_task_id, dispatch_task, dispatch_task_with_timeout
export fetch_with_timeout, list_active_tasks

# Fire counter
export FireCounter, try_claim_fire_slot!, current_fire_count, fire_cap_reached

# DONE channels
export DoneSignal, make_done_channel, send_done!, wait_for_done

# Parallel fire
export parallel_fire_batches

# AIML vote selection
export VoteCandidate, select_aiml_votes, select_aiml_votes_banded, strength_biased_vote_coinflip

end # module VoteOrchestrator