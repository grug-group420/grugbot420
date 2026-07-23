# BrainStem.jl - GRUG Winner-Take-All Dispatcher
# GRUG say: BrainStem is cave router. Only ONE cave talks at a time. Others shut up.
# GRUG say: This how brain work. One thing get attention. Other things wait.
# GRUG say: No silent failures. If dispatch break, Grug must know.
# GRUG say: NEW - cross-lobe signal propagation! Connected caves whisper to each other.
# GRUG say: NEW - fire count decay! Old winners don't hog attention forever.

module BrainStem
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


# ============================================================================
# ERROR TYPES - GRUG hate silent failures!
# ============================================================================

struct BrainStemError <: Exception
    message::String
    context::String
end

function throw_brainstem_error(msg::String, ctx::String = "unknown")
    throw(BrainStemError(msg, ctx))
end

# ============================================================================
# CONSTANTS - GRUG like numbers in one place
# ============================================================================

# GRUG: Signal decays as it crosses lobe boundaries.
# 0.6 = connected lobe gets 60% of winner's confidence. Feels right for one hop.
const PROPAGATION_DECAY = 0.6

# GRUG: Fire count decay rate. Every DECAY_INTERVAL dispatches, fire counts
# are multiplied by FIRE_COUNT_DECAY_FACTOR. Prevents old winners from
# hogging tie-breaking priority forever. Fair cave for all lobes!
const FIRE_COUNT_DECAY_FACTOR   = 0.85
const FIRE_COUNT_DECAY_INTERVAL = 50   # GRUG: Decay every 50 dispatches

# GRUG: Minimum confidence a propagated signal must have to be considered.
# Below this, the signal is too weak - don't include in results.
const PROPAGATION_MIN_CONFIDENCE = 0.1

# ============================================================================
# DISPATCH RESULT - What a lobe returns when asked to fire
# ============================================================================

struct DispatchResult
    lobe_id        ::String
    confidence     ::Float64
    node_ids_fired ::Vector{String}
    action_output  ::String
    silent         ::Bool
end

# ============================================================================
# PROPAGATION RECORD - What a connected lobe received via propagation
# ============================================================================

struct PropagationRecord
    source_lobe_id ::String
    target_lobe_id ::String
    confidence     ::Float64
    dispatch_count ::Int
end

# ============================================================================
# BRAINSTEM STATE - GRUG track what cave won last time
# ============================================================================

mutable struct BrainStemState
    dispatch_count      ::Int
    last_winner_id      ::String
    last_dispatch_t     ::Float64
    is_dispatching      ::Bool
    propagation_history ::Vector{PropagationRecord}  # GRUG: last 100 propagation events
end

const BRAINSTEM_STATE = BrainStemState(0, "", 0.0, false, PropagationRecord[])
const BRAINSTEM_LOCK  = ReentrantLock()

# ============================================================================
# INHIBIT LOBE - Tell losing cave to shut up
# ============================================================================

function inhibit_lobe!(lobe_id::String, registry::Dict, lock_obj::ReentrantLock)
    # GRUG: Increment inhibit counter on losing lobe
    lock(lock_obj) do
        if haskey(registry, lobe_id)
            registry[lobe_id].inhibit_count += 1
        end
    end
end

# ============================================================================
# FIRE LOBE - Tell winning cave to speak
# ============================================================================

function fire_lobe!(lobe_id::String, registry::Dict, lock_obj::ReentrantLock)
    # GRUG: Increment fire counter on winning lobe
    lock(lock_obj) do
        if haskey(registry, lobe_id)
            registry[lobe_id].fire_count += 1
        end
    end
end

# ============================================================================
# FIRE COUNT DECAY - Prevent starvation of newer/quieter lobes
# GRUG: Every FIRE_COUNT_DECAY_INTERVAL dispatches, multiply all fire counts
# by FIRE_COUNT_DECAY_FACTOR. Old history fades. Recent winners still ahead,
# but not by runaway margin. New lobes get fair shot at tie-breaking.
# ============================================================================

function apply_fire_count_decay!(registry::Dict, lock_obj::ReentrantLock)
    lock(lock_obj) do
        for (_, rec) in registry
            # GRUG: Multiply by decay factor and round down. Floor at 0.
            rec.fire_count = max(0, floor(Int, rec.fire_count * FIRE_COUNT_DECAY_FACTOR))
        end
    end
    @info "[BrainStem] 🕰  Fire count decay applied (factor=$(FIRE_COUNT_DECAY_FACTOR))."
end

# ============================================================================
# PROPAGATE SIGNAL - Spread activation to connected lobes after winner fires
# GRUG: Winner cave whispers to connected caves. They get weaker version of signal.
# Connected lobes whose confidence exceeds PROPAGATION_MIN_CONFIDENCE are
# returned as secondary results. They don't win, but they know something happened.
# This models associative spreading activation in real neural networks.
# ============================================================================

function propagate_signal!(
    winner_lobe_id  ::String,
    winner_confidence::Float64,
    registry        ::Dict,
    lock_obj        ::ReentrantLock
)::Vector{PropagationRecord}

    if isempty(strip(winner_lobe_id))
        throw_brainstem_error("propagate_signal! got empty winner_lobe_id", "propagate_signal!")
    end
    if winner_confidence <= 0.0
        # GRUG: Zero or negative confidence winner cannot propagate anything meaningful
        return PropagationRecord[]
    end

    records = PropagationRecord[]
    dispatch_now = lock(BRAINSTEM_LOCK) do
        BRAINSTEM_STATE.dispatch_count
    end

    connected_ids = lock(lock_obj) do
        if !haskey(registry, winner_lobe_id)
            return String[]
        end
        collect(registry[winner_lobe_id].connected_lobe_ids)
    end

    if isempty(connected_ids)
        return records
    end

    propagated_conf = winner_confidence * PROPAGATION_DECAY

    if propagated_conf < PROPAGATION_MIN_CONFIDENCE
        # GRUG: Winner confidence too low for propagation to matter. Skip.
        return records
    end

    for target_id in connected_ids
        lock(lock_obj) do
            if !haskey(registry, target_id)
                # GRUG: Connected lobe may have been deleted. Non-fatal, skip.
                return
            end
            # GRUG: Increment the connected lobe's fire count slightly (partial activation).
            # NOT a full fire - this is sub-threshold activation, not a win.
            # We increment by a fraction to show the lobe was "touched" by propagation.
            registry[target_id].fire_count += 1
        end

        rec = PropagationRecord(winner_lobe_id, target_id, propagated_conf, dispatch_now)
        push!(records, rec)
        @info "[BrainStem] 📡 Signal propagated: $winner_lobe_id → $target_id (conf=$(round(propagated_conf, digits=3)))"
    end

    # GRUG: Store in propagation history (cap at 100 entries to prevent unbounded growth)
    lock(BRAINSTEM_LOCK) do
        append!(BRAINSTEM_STATE.propagation_history, records)
        if length(BRAINSTEM_STATE.propagation_history) > 100
            # GRUG: Trim oldest entries. Keep last 100.
            deleteat!(BRAINSTEM_STATE.propagation_history, 1:(length(BRAINSTEM_STATE.propagation_history) - 100))
        end
    end

    return records
end

# ============================================================================
# DISPATCH - The big winner-take-all function
# GRUG: Send input to all lobes, pick winner, inhibit losers,
#       then propagate signal to winner's connected lobes.
# ============================================================================

function dispatch!(input::String,
                   lobe_ids::Vector{String},
                   lobe_scan_fn::Function,
                   registry::Dict,
                   lock_obj::ReentrantLock)::DispatchResult

    if isempty(strip(input))
        throw_brainstem_error("Cannot dispatch empty input", "dispatch!")
    end
    if isempty(lobe_ids)
        throw_brainstem_error("Cannot dispatch to empty lobe list", "dispatch!")
    end

    # GRUG: Mark dispatch in progress, bump counter
    new_count = lock(BRAINSTEM_LOCK) do
        BRAINSTEM_STATE.is_dispatching = true
        BRAINSTEM_STATE.dispatch_count += 1
        BRAINSTEM_STATE.last_dispatch_t = time()
        BRAINSTEM_STATE.dispatch_count
    end

    # GRUG: Check if it's time to apply fire count decay (every FIRE_COUNT_DECAY_INTERVAL)
    if new_count % FIRE_COUNT_DECAY_INTERVAL == 0
        apply_fire_count_decay!(registry, lock_obj)
    end

    results = DispatchResult[]

    # GRUG: Ask each lobe what it thinks. Catch errors per-lobe (fault isolation).
    # One failing lobe NEVER aborts the whole dispatch round. Cave stays open!
    for lid in lobe_ids
        try
            result = lobe_scan_fn(lid, input)
            if !result.silent
                push!(results, result)
            end
        catch e
            # GRUG: One lobe failing does NOT abort the whole dispatch round.
            # Treat as silent. Log it so Grug knows what broke.
            @warn "[BrainStem] Lobe '$lid' threw error during dispatch: $e"
        end
    end

    # GRUG: No winners. Return silent result.
    if isempty(results)
        lock(BRAINSTEM_LOCK) do
            BRAINSTEM_STATE.is_dispatching = false
        end
        return DispatchResult("", 0.0, String[], "", true)
    end

    # GRUG: Sort by confidence descending.
    # Tie-break: lobe with fewer fires gets priority (fairness, starvation prevention).
    sort!(results, by = r -> begin
        fire_cnt = lock(lock_obj) do
            haskey(registry, r.lobe_id) ? registry[r.lobe_id].fire_count : 0
        end
        (r.confidence, -fire_cnt)
    end, rev = true)

    winner = results[1]
    losers = results[2:end]

    # GRUG: Fire winner, inhibit losers.
    fire_lobe!(winner.lobe_id, registry, lock_obj)
    for loser in losers
        inhibit_lobe!(loser.lobe_id, registry, lock_obj)
    end

    # GRUG: Also inhibit lobes that were silent but in the dispatch list.
    winner_ids = Set(r.lobe_id for r in results)
    for lid in lobe_ids
        if !(lid in winner_ids)
            inhibit_lobe!(lid, registry, lock_obj)
        end
    end

    # GRUG: NEW - Propagate signal to connected lobes after winner is decided.
    # This spreads activation to semantically adjacent lobes at reduced strength.
    # Non-fatal: if propagation fails for any reason, dispatch result is still valid.
    try
        propagate_signal!(winner.lobe_id, winner.confidence, registry, lock_obj)
    catch e
        @warn "[BrainStem] Propagation failed (non-fatal): $e"
    end

    lock(BRAINSTEM_LOCK) do
        BRAINSTEM_STATE.last_winner_id  = winner.lobe_id
        BRAINSTEM_STATE.is_dispatching  = false
    end

    return winner
end

# ============================================================================
# GET BRAINSTEM STATUS - Show what BrainStem been doing
# ============================================================================

function get_brainstem_status()::Dict{String, Any}
    lock(BRAINSTEM_LOCK) do
        recent_propagations = length(BRAINSTEM_STATE.propagation_history)
        return Dict{String, Any}(
            "dispatch_count"        => BRAINSTEM_STATE.dispatch_count,
            "last_winner_id"        => BRAINSTEM_STATE.last_winner_id,
            "last_dispatch_t"       => BRAINSTEM_STATE.last_dispatch_t,
            "is_dispatching"        => BRAINSTEM_STATE.is_dispatching,
            "propagation_events"    => recent_propagations,
            "decay_interval"        => FIRE_COUNT_DECAY_INTERVAL,
            "propagation_decay"     => PROPAGATION_DECAY
        )
    end
end

# ============================================================================
# GET PROPAGATION HISTORY - Last N propagation events for diagnostics
# ============================================================================

function get_propagation_history(n::Int = 10)::Vector{PropagationRecord}
    if n <= 0
        throw_brainstem_error("n must be positive, got $n", "get_propagation_history")
    end
    lock(BRAINSTEM_LOCK) do
        hist = BRAINSTEM_STATE.propagation_history
        start_idx = max(1, length(hist) - n + 1)
        return hist[start_idx:end]
    end
end

# GRUG say: BrainStem done. Only one cave talks. Connected caves whisper.
# Fire counts fade over time so new caves get fair chance. Grug very happy.

end # module BrainStem