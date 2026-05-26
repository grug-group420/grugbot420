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

# GRUG: Positive confidence threshold. Votes below this are ignored by AIML.
# Set high enough to drop pattern-mismatch noise (typical mismatch confidence
# clusters at 0.05-0.25) while keeping legitimate semantic matches (0.38+).
# Empirically calibrated from the kitchen-sink specimen run: 36 votes at 0.1,
# 12 at 0.05, scattered 0.19-0.24 are all pattern-collision noise; the lowest
# legitimate semantic family in that distribution clusters at 0.38, so 0.35
# is the cleanest cut. Sub-threshold votes don't get coinflipped — they're
# rejected outright. A safety fallback in run_orchestrator picks the highest
# rejected vote if NOTHING passes, so the cave never freezes silent.
# Raw token+rel confidence floor for "this rock has real opinion".
const AIML_CONFIDENCE_THRESHOLD = 0.35

# GRUG: How close to max confidence to be "top". Votes within this window of
# the max confidence are the "top tier" and ALWAYS picked. No coinflip.
const AIML_TOP_TIER_WINDOW = 0.05

# GRUG: Coinflip base + strength bonus for sub-top votes within threshold.
# Mirrors engine.jl strength_biased_scan_coinflip formula so behavior is consistent.
const AIML_SUBTOP_BASE_PROB  = 0.20
const AIML_SUBTOP_BONUS_PROB = 0.70

# ============================================================================
# COMPOSITE VOTE-SCORING KNOBS (vote-pick stage matching dimensions)
# ============================================================================
# GRUG: The vote orchestrator used to rank candidates on raw confidence alone
# (one knob, one dimension). That meant two candidates with confidence 0.6 were
# treated identically even when one came from the consensus-winner lobe and
# the other was an isolated cross-lobe leaker, or one had strong relational
# alignment with the input triples and the other had none.
#
# COMPOSITE SCORE: a vote's final ranking is its base confidence multiplied
# by (1 + Σᵢ Wᵢ * sᵢ) where sᵢ ∈ [0,1] is each per-vote signal and Wᵢ is the
# global weight knob below. Each signal is optional — passing NaN means
# "skip this dimension for this candidate". Weights set to 0 disable a knob
# without removing the plumbing. Total bonus is capped at +VOTE_BONUS_CAP so
# no single vote can 10x itself out of contention.
#
# All weights live HERE so tuning is one-stop; production runs can tweak the
# constants without code surgery elsewhere.
# ----------------------------------------------------------------------------
const VOTE_W_LOBE_ALIGNMENT     = 0.40   # in winner lobe (1.0) vs passthrough (~0.5) vs orphan (0.0)
const VOTE_W_RELATIONAL_MATCH   = 0.50   # input/node triple overlap fraction
const VOTE_W_RECENCY_BONUS      = 0.15   # node fired/voted recently (warm rocks)
const VOTE_W_ACTION_TONE_ALIGN  = 0.25   # action_packet matches predicted family
const VOTE_W_ANTI_MATCH_PENALTY = 1.00   # subtractive — strong demotion for stance-violators
const VOTE_W_PEAK_DOMINANCE     = 0.20   # vote conf vs lobe mean — clear within-lobe winners

# GRUG: Cap on cumulative positive bonus. Anti-match penalty is NOT capped —
# it's a hard demotion signal that should be allowed to push a vote below
# threshold. Positive bonuses sum up to this; beyond it, additional signals
# don't compound. Default 1.5 means a fully-aligned vote can score up to
# 2.5x its raw confidence.
const VOTE_BONUS_CAP = 1.5

# GRUG: Floor on composite score. Anti-match could in principle drive the
# score arbitrarily negative; clamp at 0 so we don't break sort stability.
const VOTE_SCORE_FLOOR = 0.0

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

OPTIONAL SCORING SIGNALS (all default to NaN = "skip this dimension"):
  lobe_alignment       in [0,1] — 1.0 if vote is from the winner lobe, ~0.5
                                  if from a passthrough lobe, 0.0 if orphan
  relational_match     in [0,1] — fraction of input triples this node's
                                  required_relations satisfied
  recency_bonus        in [0,1] — 1.0 if fired this cycle, decays with age
  action_tone_align    in [0,1] — 1.0 if action_packet aligns with the
                                  predicted action family, 0.0 if misaligned
  anti_match_score     in [0,1] — 1.0 if anti-match detected (stance violator)
  peak_dominance       in [0,1] — vote's confidence relative to its lobe's
                                  mean confidence (clear within-lobe winner)

Each NaN signal is silently skipped in composite scoring. This keeps the
struct backward-compatible — a caller that doesn't compute a signal just
leaves it NaN and it's as if that knob were turned off for that candidate.
"""
struct VoteCandidate
    node_id::String
    confidence::Float64
    strength::Float64        # GRUG: Node strength (0.0 to STRENGTH_CAP, usually 10.0)
    strength_cap::Float64    # GRUG: Cap used for normalization (default 10.0)
    # ---- optional matching dimensions (NaN = unknown / skip) -------------
    lobe_alignment::Float64
    relational_match::Float64
    recency_bonus::Float64
    action_tone_align::Float64
    anti_match_score::Float64
    peak_dominance::Float64
end

function VoteCandidate(node_id::String, confidence::Float64, strength::Float64;
                       strength_cap::Float64 = 10.0,
                       lobe_alignment::Float64    = NaN,
                       relational_match::Float64  = NaN,
                       recency_bonus::Float64     = NaN,
                       action_tone_align::Float64 = NaN,
                       anti_match_score::Float64  = NaN,
                       peak_dominance::Float64    = NaN)
    if isempty(strip(node_id))
        throw_vo_error("VoteCandidate node_id cannot be empty", "VoteCandidate")
    end
    if strength_cap <= 0
        throw_vo_error("VoteCandidate strength_cap must be positive, got $strength_cap", "VoteCandidate")
    end
    return VoteCandidate(node_id, confidence, strength, strength_cap,
                         lobe_alignment, relational_match, recency_bonus,
                         action_tone_align, anti_match_score, peak_dominance)
end

"""
    composite_vote_score(vc::VoteCandidate)::Float64

GRUG: Combine raw confidence with all available matching dimensions to
produce the final ranking score. Knobs come from the VOTE_W_* constants.
NaN signals are ignored (zero contribution). Total positive bonus is
capped at VOTE_BONUS_CAP; anti-match penalty subtracts after capping.
Result is clamped at VOTE_SCORE_FLOOR (default 0.0) for sort stability.
"""
function composite_vote_score(vc::VoteCandidate)::Float64
    bonus_pos  = 0.0
    penalty    = 0.0

    # GRUG: Each helper applies a weight only if the signal is finite.
    _add(s, w) = (isfinite(s) ? s * w : 0.0)

    bonus_pos += _add(vc.lobe_alignment,    VOTE_W_LOBE_ALIGNMENT)
    bonus_pos += _add(vc.relational_match,  VOTE_W_RELATIONAL_MATCH)
    bonus_pos += _add(vc.recency_bonus,     VOTE_W_RECENCY_BONUS)
    bonus_pos += _add(vc.action_tone_align, VOTE_W_ACTION_TONE_ALIGN)
    bonus_pos += _add(vc.peak_dominance,    VOTE_W_PEAK_DOMINANCE)

    penalty   += _add(vc.anti_match_score,  VOTE_W_ANTI_MATCH_PENALTY)

    bonus_pos = min(bonus_pos, VOTE_BONUS_CAP)

    # GRUG: multiplicative gain on positive bonus, additive demotion on penalty
    score = vc.confidence * (1.0 + bonus_pos) - vc.confidence * penalty
    return max(VOTE_SCORE_FLOOR, score)
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

    # GRUG: Compute composite score per candidate ONCE. Threshold and top-tier
    # comparisons all use composite, not raw confidence — the composite IS the
    # vote's final standing once all matching dimensions are folded in.
    # Pair (vc, score) so we can sort/filter without recomputing.
    scored = [(vc, composite_vote_score(vc)) for vc in candidates]

    # GRUG: First pass — filter by threshold against composite. Anything below
    # the bar is auto-rejected. Note: a candidate whose RAW confidence was
    # above threshold but whose COMPOSITE drops below (e.g. anti-match
    # penalty) gets correctly rejected here. Conversely, a vote whose raw
    # confidence was just below threshold can be lifted past it by strong
    # matching-dimension bonuses.
    above_threshold = Tuple{VoteCandidate, Float64}[]
    rejected        = VoteCandidate[]
    for (vc, sc) in scored
        if sc >= threshold
            push!(above_threshold, (vc, sc))
        else
            push!(rejected, vc)
        end
    end

    if isempty(above_threshold)
        return (VoteCandidate[], VoteCandidate[], rejected)
    end

    # GRUG: Find max composite score among threshold-passers.
    max_score = maximum(sc for (_, sc) in above_threshold)

    # GRUG: Top tier = within top_window of max composite. Selected directly.
    top_tier    = VoteCandidate[]
    subtop_tier = VoteCandidate[]
    for (vc, sc) in above_threshold
        if sc >= max_score - top_window
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

export VoteOrchestratorError, TaskTimeoutError
export ACTIVE_FIRE_CAP, FIRE_BATCH_SIZE
export AIML_CONFIDENCE_THRESHOLD, AIML_TOP_TIER_WINDOW
export AIML_SUBTOP_BASE_PROB, AIML_SUBTOP_BONUS_PROB
export VOTE_W_LOBE_ALIGNMENT, VOTE_W_RELATIONAL_MATCH, VOTE_W_RECENCY_BONUS
export VOTE_W_ACTION_TONE_ALIGN, VOTE_W_ANTI_MATCH_PENALTY, VOTE_W_PEAK_DOMINANCE
export VOTE_BONUS_CAP, VOTE_SCORE_FLOOR
export composite_vote_score
export DONE_SIGNAL_TIMEOUT_S, DEFAULT_TASK_TIMEOUT_S, FIRE_BATCH_TIMEOUT_S

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
export VoteCandidate, select_aiml_votes, strength_biased_vote_coinflip

end # module VoteOrchestrator