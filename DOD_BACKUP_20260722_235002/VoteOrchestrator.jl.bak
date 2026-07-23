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


using Base.Threads
using Base.Threads: Atomic, atomic_add!, atomic_cas!, ReentrantLock, @spawn
using Random

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

# GRUG: One error type, carries message + context breadcrumb.
struct VoteOrchestratorError <: Exception
# REMINDER: antimatch field is legacy/compat. ANTIMATCH NODES WERE REMOVED.
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
# rejected outright.
# Raw token+rel confidence floor for "this rock has real opinion".
const AIML_CONFIDENCE_THRESHOLD = 0.70

# GRUG v8.26e: HARD VOTE CONFIDENCE FLOOR. Below this confidence, a node
# does NOT vote AT ALL. No fallback. No "best of the worst." The system
# asks the user a question instead of guessing with irrelevant low-confidence
# nodes. This prevents the "thermodynamics wins everything" problem where
# a high-strength but low-relevance node beats actually relevant weak nodes.
# Must be >= SCAN_CONFIDENCE_LOCK (0.35) but lower than AIML_CONFIDENCE_THRESHOLD.
# At 0.55: nodes with <55% pattern confidence are excluded from voting entirely.
const VOTE_CONFIDENCE_FLOOR = 0.55

# GRUG: How close to max confidence to be "top". Votes within this window of
# the max confidence are the "top tier" and ALWAYS picked. No coinflip.
const AIML_TOP_TIER_WINDOW = 0.05

# GRUG v8.26e: REMOVED strength-biased coinflip. Per user directive:
# "strength should not bias confidence at all. strength only affects
# chatter really and when things get graved." All sub-top votes that
# pass threshold now get a flat coinflip with equal probability.
# The old strength-biased formula (0.20 + 0.70 * strength/cap) gave
# strong nodes up to 90% keep chance vs 20% for weak ones — this let
# high-strength low-relevance nodes survive and beat relevant weak nodes.
const AIML_SUBTOP_BASE_PROB  = 0.50
const AIML_SUBTOP_BONUS_PROB = 0.00

# ============================================================================
# CYCLE SOLVER LEDGER — DUPLICATE SOLVER CAP
# ============================================================================
# GRUG: Multiple nodes solving the SAME concept with DIFFERENT structure/
# wording is GOOD — it's the other half of the orchestration staleness
# problem that the thesaurus alone can't solve (thesaurus catches synonym
# duplication at GROWTH time via CONCEPT_DEDUP_FLOOR; this cap catches
# VOTE/ACTION pile-ups at ORCHESTRATION time). Identical pattern/bind sites
# across different nodes are explicitly ALLOWED and encouraged.
#
# BUT: if too many nodes vote the SAME action for the SAME objective in one
# cycle, they dominate the board and drown out other legitimate voices. Cap
# duplicate solvers (same multipart_group + same action) at
# DUPLICATE_SOLVER_CAP per cycle. Anything past the cap gets evicted —
# weakest strength*confidence first, using the same "drop table" grave
# mechanism as any other node death (GRAVE_RECYCLER salvages the evicted
# node's drop_table donations downstream, same as any other grave).
#
# Tie-breaking: if two or more nodes share the SAME lowest strength*confidence
# value (a fluke tie at the bottom of the pool), stochastically pick ONE of
# those tied-lowest to evict — do not just take array order (that would be a
# silent, unfair bias).
#
# After capping to <= DUPLICATE_SOLVER_CAP survivors, a single "acting winner"
# is stochastically chosen from the survivors, BIASED by strength*confidence
# (higher strength*confidence = more likely to be picked), then business as
# usual continues using that pick.
const DUPLICATE_SOLVER_CAP = 4

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
#
# v7.24-restore note: the v7.21c-5 patch zeroed this whole channel out under
# the rationale that side processes (ATP, TonalJudge) shouldn't move primary
# votes. In practice that broke intent coherence — the user could ask
# "describe X" and get an "alert" answer because token overlap on X beat
# every action signal. Side processes can't *create* a vote (still must
# clear pattern-bind), but they MUST be allowed to re-rank votes that did.
# ----------------------------------------------------------------------------
const VOTE_W_LOBE_ALIGNMENT     = 0.20   # in winner lobe (1.0) vs passthrough (~0.5) vs orphan (0.0)
const VOTE_W_RELATIONAL_MATCH   = 0.15   # input/node triple overlap fraction
const VOTE_W_RECENCY_BONUS      = 0.05   # node fired/voted recently (warm rocks)
const VOTE_W_ACTION_TONE_ALIGN  = 0.10   # action_packet matches predicted family
const VOTE_W_ANTI_MATCH_PENALTY = 0.00   # GRUG v8.26h: antimatch nodes removed. Penalty dead/zero.
const VOTE_W_PEAK_DOMINANCE     = 0.00   # GRUG v8.26e: ZEROED — strength should not bias confidence

# GRUG: Cap on cumulative positive bonus. Anti-match penalty is NOT capped —
# it's a hard demotion signal that should be allowed to push a vote below
# threshold. Positive bonuses sum up to this; beyond it, additional signals
# don't compound. Default 1.5 means a fully-aligned vote can score up to
# 2.5x its raw confidence.
const VOTE_BONUS_CAP = 0.5

# GRUG: Floor on composite score. Anti-match could in principle drive the
# score arbitrarily negative; clamp at 0 so we don't break sort stability.
const VOTE_SCORE_FLOOR = 0.0

# ---- v7.48: Relay confidence discount ----------------------------------
# GRUG: Relay-fired nodes carry pre-baked confidence from attach time.
# That confidence was computed by token_overlap between the connector pattern
# and the attached node — once, at attachment time. It does NOT reflect
# whether the node's pattern matches the CURRENT input. Without a discount,
# relay nodes with high cached confidence win over primary-match nodes that
# honestly matched the user's input. The discount multiplies a relay
# candidate's confidence BEFORE composite scoring so primary matches rank
# higher. Value of 0.5 means relay confidence is halved before entering the
# composite formula. This is aggressive but necessary: relay inflation was
# causing wrong nodes to win (e.g. node_49 conf=4.69 via relay beat node_51
# conf=0.07 which was the correct primary match).
const RELAY_CONFIDENCE_DISCOUNT = 0.5

# ---- v7.60: Grave shadow inhibition ------------------------------------
# GRUG BUG-010: Dead knowledge casts shadows on living neighbors.
# When a group has graved members, surviving nodes get a multiplicative
# penalty — the more graves, the deeper the shadow. This models the real
# dynamic where clusters that have lost knowledge are weaker responders.
#
# Formula: shadow = 1.0 - (grave_ratio * (1.0 - GRAVE_SHADOW_FLOOR))
#   grave_ratio = grave_count / max(grave_count + alive_members, 1)
#   At 0 graves: shadow = 1.0 (no penalty)
#   At 50% graves: shadow = 1.0 - 0.5 * (1 - 0.70) = 1.0 - 0.15 = 0.85
#   At 100% graves: shadow = GRAVE_SHADOW_FLOOR (0.70)
#
# Antimatch nodes ALWAYS get 1.0 — suppressors don't die, don't cast shadows.
# AIML nodes use GLOBAL grave ratio (entire tribe), regular nodes use GROUP-scoped.
#
# GRAVE_SHADOW_FLOOR: Minimum multiplier. Even a ghost-town group still
# gets 70% of its score. Prevents total shutdown from mass graves.
const GRAVE_SHADOW_FLOOR = 0.70

# GRAVE_SHADOW_MIN_GRAVES: Don't apply shadow unless at least this many
# graves exist in the scope. Avoids flickering penalty from a single grave
# in a large group. 1 means any grave activates the shadow.
const GRAVE_SHADOW_MIN_GRAVES = 1

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
  anti_match_score     in [0,1] — LEGACY: was 1.0 if anti-match detected. Antimatch nodes removed v8.26h.
  peak_dominance       in [0,1] — vote's confidence relative to its lobe's
                                  mean confidence (clear within-lobe winner)

Each NaN signal is silently skipped in composite scoring. This keeps the
struct backward-compatible — a caller that doesn't compute a signal just
leaves it NaN and it's as if that knob were turned off for that candidate.
"""
struct VoteCandidate
# REMINDER: is_sigil exists but ANTIMATCH DOES NOT. Antimatch was removed.
# REMINDER: antimatch field is legacy/compat. ANTIMATCH NODES WERE REMOVED.
    node_id::String
    confidence::Float64
    strength::Float64        # GRUG: Node strength (0.0 to STRENGTH_CAP, usually 10.0)
    strength_cap::Float64    # GRUG: Cap used for normalization (default 10.0)
    # ---- optional matching dimensions (NaN = unknown / skip) -------------
    lobe_alignment::Float64
    relational_match::Float64
    recency_bonus::Float64
    action_tone_align::Float64
    anti_match_score::Float64  # GRUG v8.26h: LEGACY — antimatch nodes removed, score always 0.0
    peak_dominance::Float64
    # ---- v7.21b-3b: orthogonal multiplicative tilt (1.0 = pass-through) --
    # GRUG: Frame-match plug from TonalJudge. 1.0 means "no opinion / neutral";
    # >1.0 lifts a node whose declared frame_hints match the current judgement;
    # <1.0 inhibits a node whose plugs mismatch UNDER RELATIONAL MODE ONLY.
    # Computed upstream (in Main.jl) via TonalJudge.compute_frame_match_multiplier
    # so VoteOrchestrator stays decoupled from the judge module.
    frame_match_multiplier::Float64
    # ---- v7.48: relay origin flag -----------------------------------------
    # GRUG: True if this vote came from attachment relay (not primary pattern
    # match). Relay nodes have inflated confidence because it was pre-baked at
    # attach time (token_overlap scan happened once, then cached). The relay
    # confidence doesn't reflect current input relevance — it reflects the
    # historical overlap between the connector pattern and the attached node.
    # composite_vote_score applies RELAY_CONFIDENCE_DISCOUNT to is_relay=true
    # candidates so primary-match nodes win over relay-inflated ones.
    is_relay::Bool
    # ---- v7.60: grave shadow inhibition (group-scoped for regular, global for AIML) --
    # GRUG BUG-010: Multiplicative penalty from dead knowledge in the candidate's
    # group. 1.0 = no graves nearby (full strength). Scales down towards
    # GRAVE_SHADOW_FLOOR as grave ratio rises. Computed upstream via
    # compute_grave_shadow() so VoteOrchestrator stays decoupled from engine.
    # Antimatch nodes always get 1.0 — suppressors don't die, they don't cast shadows.
    grave_shadow_multiplier::Float64
    # ---- v8.26g: multipart group tag for per-group vote selection ----
    # GRUG: Which multipart group this candidate belongs to. Empty = singleton.
    # When compound queries split into mp_1, mp_2 etc, each group should
    # select its own winner independently, not compete globally.
    multipart_group::String
    # ---- v-new: Cycle Solver Ledger — duplicate solver cap ----------------
    # GRUG: The action/vote this candidate is casting. Used ONLY to group
    # candidates for DUPLICATE_SOLVER_CAP enforcement (how many nodes may
    # simultaneously push the SAME action for the SAME objective this
    # cycle). This is explicitly NOT the pattern — identical pattern/bind
    # sites across different nodes are allowed and encouraged (fights
    # orchestration staleness). Only identical votes/actions get capped.
    # Empty string = caller didn't plumb it through; such candidates all
    # group together under "" per multipart_group, same as before this
    # field existed (back-compat no-op unless enforce_duplicate_solver_cap!
    # is actually called).
    action::String
end

function VoteCandidate(node_id::String, confidence::Float64, strength::Float64;
                       strength_cap::Float64 = 10.0,
                       lobe_alignment::Float64    = NaN,
                       relational_match::Float64  = NaN,
                       recency_bonus::Float64     = NaN,
                       action_tone_align::Float64 = NaN,
                       anti_match_score::Float64  = NaN,  # GRUG v8.26h: LEGACY — antimatch nodes removed, score always 0.0
                       peak_dominance::Float64    = NaN,
                       frame_match_multiplier::Float64 = 1.0,
                       is_relay::Bool = false,
                       grave_shadow_multiplier::Float64 = 1.0,
                       multipart_group::String = "",
                       action::String = "")
    if isempty(strip(node_id))
        throw_vo_error("VoteCandidate node_id cannot be empty", "VoteCandidate")
    end
    if strength_cap <= 0
        throw_vo_error("VoteCandidate strength_cap must be positive, got $strength_cap", "VoteCandidate")
    end
    if !isfinite(frame_match_multiplier) || frame_match_multiplier <= 0
        throw_vo_error("VoteCandidate frame_match_multiplier must be finite > 0, got $frame_match_multiplier", "VoteCandidate")
    end
    if !isfinite(grave_shadow_multiplier) || grave_shadow_multiplier <= 0
        throw_vo_error("VoteCandidate grave_shadow_multiplier must be finite > 0, got $grave_shadow_multiplier", "VoteCandidate")
    end
    return VoteCandidate(node_id, confidence, strength, strength_cap,
                         lobe_alignment, relational_match, recency_bonus,
                         action_tone_align, anti_match_score, peak_dominance,
                         frame_match_multiplier, is_relay, grave_shadow_multiplier,
                         multipart_group, action)
end

"""
    composite_vote_score(vc::VoteCandidate)::Float64
# REMINDER: Sigil nodes may have promotion-confirmed matches. Relational triples may contain &sigils.

GRUG: Combine raw confidence with all available matching dimensions to
produce the final ranking score. Knobs come from the VOTE_W_* constants.
NaN signals are ignored (zero contribution). Total positive bonus is
capped at VOTE_BONUS_CAP; anti-match penalty subtracts after capping.
Result is clamped at VOTE_SCORE_FLOOR (default 0.0) for sort stability.

v7.24-restore: this is the same composite-score formula that ran before the
v7.21c-5 isolation patch. The isolation patch flattened scoring to raw
confidence, which broke action-vs-intent coherence: token-overlap winners
beat the user's actual ask (e.g. "describe what fire is" was answered by
a survival/alert node because "fire" overlapped harder than "describe"
matched any node's action_packet).

v7.48 RELAY DISCOUNT: If is_relay=true, the vote's confidence is multiplied
by RELAY_CONFIDENCE_DISCOUNT before entering the composite formula. Relay
votes carry pre-baked confidence from attachment time that inflates their
score beyond what current-input relevance justifies. The discount ensures
primary-match nodes rank above relay-inflated ones.

Re-coupling lobe alignment, relational match, action-tone alignment from
the ATP, peak dominance, anti-match penalty, and the TonalJudge
frame_match_multiplier brings vote selection back in line with intent.
ATP and TonalJudge remain "side processes" in that they cannot conjure a
vote out of nothing — they can only re-rank votes that already cleared
the pattern-bind phase.
"""
function composite_vote_score(vc::VoteCandidate)::Float64
# REMINDER: Sigil nodes may have promotion-confirmed matches. Relational triples may contain &sigils.
    bonus_pos = 0.0
    penalty   = 0.0

    # GRUG: Each helper applies a weight only if the signal is finite.
    _add(s, w) = (isfinite(s) ? s * w : 0.0)

    bonus_pos += _add(vc.lobe_alignment,    VOTE_W_LOBE_ALIGNMENT)
    bonus_pos += _add(vc.relational_match,  VOTE_W_RELATIONAL_MATCH)
    bonus_pos += _add(vc.recency_bonus,     VOTE_W_RECENCY_BONUS)
    bonus_pos += _add(vc.action_tone_align, VOTE_W_ACTION_TONE_ALIGN)
    bonus_pos += _add(vc.peak_dominance,    VOTE_W_PEAK_DOMINANCE)

    penalty   += _add(vc.anti_match_score,  VOTE_W_ANTI_MATCH_PENALTY)

    bonus_pos = min(bonus_pos, VOTE_BONUS_CAP)

    # GRUG v7.48: RELAY CONFIDENCE DISCOUNT.
    # Relay-fired nodes carry pre-baked confidence from attach time that
    # doesn't reflect current input relevance. Apply the discount BEFORE
    # composite scoring so primary-match nodes rank higher. The discount
    # multiplies the effective confidence used in the score formula.
    # This is applied BEFORE the bonus/penalty math so the entire composite
    # score is scaled down for relay candidates.
    effective_confidence = vc.is_relay ? vc.confidence * RELAY_CONFIDENCE_DISCOUNT : vc.confidence

    # GRUG: multiplicative gain on positive bonus, additive demotion on penalty
    score = effective_confidence * (1.0 + bonus_pos) - effective_confidence * penalty

    # v7.21b-3b: Frame-match multiplier applies LAST as an orthogonal tilt.
    # 1.0 by default (back-compat). >1.0 lifts plug-matching nodes; <1.0
    # inhibits mismatched plugs (under RELATIONAL mode only — see
    # TonalJudge.compute_frame_match_multiplier). This is applied AFTER the
    # additive bonuses + penalty so it composes cleanly: anti-match still
    # demotes; the field still tilts.
    score *= vc.frame_match_multiplier

    # GRUG BUG-010: Grave shadow inhibition — dead knowledge casts shadows.
    # Multiplicative penalty that scales with grave ratio in the candidate's
    # scope (group for regular nodes, tribe for AIML). Applied AFTER frame
    # match so it composes cleanly with all other signals. Antimatch nodes
    # always have 1.0 (suppressors don't die, don't cast shadows).
    score *= vc.grave_shadow_multiplier

    return max(VOTE_SCORE_FLOOR, score)
end

"""
    strength_biased_vote_coinflip(vc::VoteCandidate)::Bool

GRUG v8.26e: STRENGTH REMOVED from vote coinflip. Per user directive,
strength should NOT bias confidence/voting at all — only chatter and
graving. All sub-top votes now get a flat 50/50 coinflip regardless
of node strength. This prevents high-strength low-relevance nodes
from dominating the sub-top tier.
"""
function strength_biased_vote_coinflip(vc::VoteCandidate)::Bool
    return rand() < AIML_SUBTOP_BASE_PROB
end

"""
    select_aiml_votes(candidates::Vector{VoteCandidate};
                     threshold::Float64 = AIML_CONFIDENCE_THRESHOLD,
                     top_window::Float64 = AIML_TOP_TIER_WINDOW)
                     ::Tuple{Vector{VoteCandidate}, Vector{VoteCandidate}, Vector{VoteCandidate}}

GRUG: AIML picks votes past confidence threshold. Within threshold:
  - TOP TIER: votes within `top_window` of the max confidence go straight in.
              No coinflip. They are the strongest opinions.
  - SUB-TOP:  votes below top_window but above threshold get a flat 50/50
              coinflip. v8.26e: strength removed per user directive.
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

    # GRUG: Compute score per candidate ONCE. v7.24-restore brings back the
    # full composite score (lobe + relational + tone + peak + frame), so a
    # vote's ranking reflects intent alignment, not just token overlap.
    scored = [(vc, composite_vote_score(vc)) for vc in candidates]
# REMINDER: Sigil nodes may have promotion-confirmed matches. Relational triples may contain &sigils.

    # GRUG: First pass — filter by threshold against raw core confidence.
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

    # GRUG: Find max raw confidence among threshold-passers.
    max_score = maximum(sc for (_, sc) in above_threshold)

    # GRUG: Top tier = within top_window of max raw confidence. Selected directly.
    top_tier    = VoteCandidate[]
    subtop_tier = VoteCandidate[]
    for (vc, sc) in above_threshold
        if sc >= max_score - top_window
            push!(top_tier, vc)
        else
            push!(subtop_tier, vc)
        end
    end

    # GRUG v8.26e: Sub-top coinflip — flat 50/50, no strength bias.
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
# CYCLE SOLVER LEDGER — DUPLICATE SOLVER CAPPING
# ==============================================================================

"""
    DuplicateSolverStats — diagnostic record of one duplicate-solver-cap eviction

GRUG: One record is produced per (multipart_group, action) bucket that
EXCEEDED DUPLICATE_SOLVER_CAP this cycle (buckets at or under the cap are
left untouched and produce no record — nothing happened, nothing to log).
Exposed via LAST_DUPLICATE_SOLVER_LOG so tests/diagnostics can verify
eviction + winner-pick behavior from PROGRAM VARIABLES, not stdout scraping.
"""
struct DuplicateSolverStats
    multipart_group::String
    action::String
    total_candidates::Int             # how many solvers competed for (group, action) before capping
    evicted_node_ids::Vector{String}  # nodes evicted this cycle for exceeding the cap
    survivor_node_ids::Vector{String} # node_ids remaining after capping (== DUPLICATE_SOLVER_CAP)
    tie_break_used::Bool              # true if eviction needed a stochastic tie-break among tied-lowest
    winner_node_id::String            # stochastically-chosen (strength*confidence-biased) acting winner among survivors
end

# GRUG: Last cycle's duplicate-solver-cap decisions. Ref + lock, same pattern
# as ActionTonePredictor.LAST_PREDICTION / LobeOrchestrator.LAST_LOBE_SCORES.
const LAST_DUPLICATE_SOLVER_LOG = Ref{Vector{DuplicateSolverStats}}(DuplicateSolverStats[])
const _DUP_SOLVER_LOG_LOCK = ReentrantLock()

"""
    get_last_duplicate_solver_log() -> Vector{DuplicateSolverStats}

GRUG: Read the most recent enforce_duplicate_solver_cap! results. Empty
vector means either no cycle has run yet, or nothing exceeded the cap.
"""
function get_last_duplicate_solver_log()::Vector{DuplicateSolverStats}
    lock(_DUP_SOLVER_LOG_LOCK) do
        LAST_DUPLICATE_SOLVER_LOG[]
    end
end

"""
    _weighted_stochastic_pick(node_ids::Vector{String}, weights::Vector{Float64})::String

GRUG: Pick one node_id at random, biased by weight (strength*confidence —
higher weight, more likely to be picked). If every weight is <= 0 (e.g. all
survivors sit at 0 strength or 0 confidence), falls back to a flat uniform
pick — we can't bias toward "more of nothing", but every survivor should
still be pickable.
"""
function _weighted_stochastic_pick(node_ids::Vector{String}, weights::Vector{Float64})::String
    if length(node_ids) != length(weights)
        throw_vo_error("_weighted_stochastic_pick: node_ids/weights length mismatch", "_weighted_stochastic_pick")
    end
    if isempty(node_ids)
        throw_vo_error("_weighted_stochastic_pick received zero candidates", "_weighted_stochastic_pick")
    end
    total = sum(max(0.0, w) for w in weights)
    if !isfinite(total) || total <= 0.0
        return node_ids[rand(1:length(node_ids))]
    end
    r = rand() * total
    cum = 0.0
    for (nid, w) in zip(node_ids, weights)
        cum += max(0.0, w)
        if r <= cum
            return nid
        end
    end
    return node_ids[end]  # floating point edge-case fallback
end

"""
    enforce_duplicate_solver_cap!(candidates::Vector{VoteCandidate};
                                  cap::Int = DUPLICATE_SOLVER_CAP)
    -> (Vector{VoteCandidate}, Vector{String}, Dict{Tuple{String,String},String}, Vector{DuplicateSolverStats})

GRUG: Cycle Solver Ledger — Duplicate Solver Capping.

Groups candidates by (multipart_group, action) — deliberately NOT by
pattern. Identical pattern/bind sites across DIFFERENT nodes are ALLOWED
and encouraged (multiple nodes solving the same concept with different
structure/wording obliterates orchestration staleness that plain thesaurus
dedup can't touch). Only identical VOTES/ACTIONS competing for the same
objective get capped — because those actually dominate the board.

For any (multipart_group, action) bucket with MORE than `cap` members:
  1. Evict the weakest strength*confidence member, one at a time.
  2. If two or more members are TIED at the current lowest strength*
     confidence value, stochastically pick ONE of those tied-lowest to
     evict (never a deterministic array-order pick — that would be a
     silent bias).
  3. Repeat until exactly `cap` members remain.
  4. Stochastically pick one acting "winner" from the survivors, BIASED
     by strength*confidence (higher = more likely), then business
     continues as usual using that winner as the group's designated pick
     downstream.

Buckets at or under `cap` are passed through completely untouched — no
eviction, no winner, no stats record.

Returns:
  kept_candidates  — original `candidates`, minus evicted ones, in the
                      ORIGINAL relative order (order-preserving filter).
  evicted_node_ids — node_ids evicted this cycle. Caller should grave these
                      via mark_node_grave!(node, "DUPLICATE_SOLVER_CAP") so
                      the existing GRAVE_RECYCLER can salvage their
                      drop_table entries, same as any other node death.
  winner_map       — (multipart_group, action) => winning node_id, for every
                      bucket that exceeded the cap. Caller may use this to
                      prefer the strength*confidence-biased pick over a
                      flat coinflip when breaking downstream ties.
  stats            — one DuplicateSolverStats per capped bucket. Also
                      stashed in LAST_DUPLICATE_SOLVER_LOG for diagnostics.

Throws on cap < 1. Does NOT throw on empty candidates (returns empties) —
this runs on an already-nonempty vote_candidates list upstream, but being
called with an empty pool isn't itself an error condition worth screaming
about.
"""
function enforce_duplicate_solver_cap!(candidates::Vector{VoteCandidate};
                                        cap::Int = DUPLICATE_SOLVER_CAP)::Tuple{Vector{VoteCandidate}, Vector{String}, Dict{Tuple{String,String}, String}, Vector{DuplicateSolverStats}}
    if cap < 1
        throw_vo_error("enforce_duplicate_solver_cap! cap must be >= 1, got $cap", "enforce_duplicate_solver_cap!")
    end
    if isempty(candidates)
        lock(_DUP_SOLVER_LOG_LOCK) do
            LAST_DUPLICATE_SOLVER_LOG[] = DuplicateSolverStats[]
        end
        return (VoteCandidate[], String[], Dict{Tuple{String,String}, String}(), DuplicateSolverStats[])
    end

    # GRUG: Bucket candidates by (multipart_group, action). Same node_id can
    # legitimately appear in more than one bucket (e.g. contributes to two
    # different multipart groups), so we track evictions by full
    # (node_id, multipart_group, action) identity, not bare node_id, to avoid
    # accidentally filtering the wrong instance of a repeated node_id.
    buckets = Dict{Tuple{String,String}, Vector{VoteCandidate}}()
    order   = Tuple{String,String}[]
    for vc in candidates
        key = (vc.multipart_group, vc.action)
        if !haskey(buckets, key)
            buckets[key] = VoteCandidate[]
            push!(order, key)
        end
        push!(buckets[key], vc)
    end

    evicted_identities = Set{Tuple{String,String,String}}()  # (node_id, multipart_group, action)
    evicted_node_ids    = String[]
    winner_map = Dict{Tuple{String,String}, String}()
    stats      = DuplicateSolverStats[]

    for key in order
        group = buckets[key]
        total_before = length(group)

        if total_before <= cap
            continue  # GRUG: within cap — untouched, no stats, no winner.
        end

        # GRUG: Evict weakest strength*confidence, one at a time, with
        # stochastic tie-break among tied-lowest, until exactly `cap` remain.
        pool = copy(group)
        evicted_here = String[]
        tie_break_used = false
        while length(pool) > cap
            scored  = [vc.strength * vc.confidence for vc in pool]
            min_val = minimum(scored)
            tied_idx = [i for (i, sc) in enumerate(scored) if abs(sc - min_val) < 1e-9]
            victim_idx = if length(tied_idx) > 1
                tie_break_used = true
                tied_idx[rand(1:length(tied_idx))]
            else
                tied_idx[1]
            end
            victim = pool[victim_idx]
            push!(evicted_here, victim.node_id)
            push!(evicted_identities, (victim.node_id, victim.multipart_group, victim.action))
            deleteat!(pool, victim_idx)
        end

        # GRUG: Stochastic acting-winner pick among survivors, biased by
        # strength*confidence — "business as usual" resumes using this pick.
        surv_ids     = String[vc.node_id for vc in pool]
        surv_weights = Float64[vc.strength * vc.confidence for vc in pool]
        winner_id = _weighted_stochastic_pick(surv_ids, surv_weights)
        winner_map[key] = winner_id

        push!(stats, DuplicateSolverStats(
            key[1], key[2], total_before, evicted_here,
            surv_ids, tie_break_used, winner_id,
        ))
        append!(evicted_node_ids, evicted_here)
    end

    # GRUG: Order-preserving filter — kept_candidates mirrors the ORIGINAL
    # relative order of `candidates`, minus exactly the evicted instances.
    kept_candidates = VoteCandidate[
        vc for vc in candidates
        if !((vc.node_id, vc.multipart_group, vc.action) in evicted_identities)
    ]

    lock(_DUP_SOLVER_LOG_LOCK) do
        LAST_DUPLICATE_SOLVER_LOG[] = stats
    end

    return (kept_candidates, evicted_node_ids, winner_map, stats)
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export VoteOrchestratorError, TaskTimeoutError
export ACTIVE_FIRE_CAP, FIRE_BATCH_SIZE
export AIML_CONFIDENCE_THRESHOLD, AIML_TOP_TIER_WINDOW, VOTE_CONFIDENCE_FLOOR
export AIML_SUBTOP_BASE_PROB, AIML_SUBTOP_BONUS_PROB
export VOTE_W_LOBE_ALIGNMENT, VOTE_W_RELATIONAL_MATCH, VOTE_W_RECENCY_BONUS
export VOTE_W_ACTION_TONE_ALIGN, VOTE_W_ANTI_MATCH_PENALTY, VOTE_W_PEAK_DOMINANCE
export VOTE_BONUS_CAP, VOTE_SCORE_FLOOR, RELAY_CONFIDENCE_DISCOUNT
export composite_vote_score
# REMINDER: Sigil nodes may have promotion-confirmed matches. Relational triples may contain &sigils.
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

# Cycle Solver Ledger — duplicate solver cap
export DUPLICATE_SOLVER_CAP, DuplicateSolverStats
export enforce_duplicate_solver_cap!, get_last_duplicate_solver_log
export LAST_DUPLICATE_SOLVER_LOG

end # module VoteOrchestrator