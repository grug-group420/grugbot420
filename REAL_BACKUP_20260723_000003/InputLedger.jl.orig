# ==============================================================================
# InputLedger.jl — Background Thread Mining User Input into Cell Growth Data
# ==============================================================================
# GRUG: The user input log IS the data. Every word the user types carries
# latent structure — which topics cluster together, what relational triples
# emerge, what concepts co-occur. This thread watches MESSAGE_HISTORY,
# consumes ONLY fresh entries (tracked by hash ledger), and digests them
# into batches of 10k records that feed mitosis and relational governance.
#
# Architecture:
#   - Hash ledger: UInt64 hash of (role|text) → consumed flag
#   - Fresh scanner: walks MESSAGE_HISTORY, skips consumed, returns batch
#   - Background thread: @async loop, runs continuously, sleeps when no fresh data
#   - Thread-safe: all ledger access through CO_LEDGER_LOCK
#   - Bounded: ledger capped at 2x MAX_HISTORY (20k entries max)
#   - Resilient: thread auto-restarts on crash, logs errors but never dies
#
# GRUG philosophy: the input stream is the blood supply. This thread is
# the gut — it digests input into nutrients that feed cell growth.
# No input is ever double-processed. Stale entries are skipped.
# 10k fresh entries = one batch = one chance to grow new cells.
# ==============================================================================

module InputLedger

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
using Base.Threads: ReentrantLock, @spawn
using Random

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

struct InputLedgerError <: Exception
    msg::String
end

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Maximum ledger entries. 2x MESSAGE_HISTORY cap (20k) because
# some entries get replaced (pinned eviction), creating new hashes.
# Bounded so the ledger can't grow without limit.
const LEDGER_CAP = 20000

# GRUG: How many fresh entries to collect per batch before processing.
# 10k records = one batch = fuel for one mitosis cycle.
const BATCH_SIZE = 10000

# GRUG: How long the background thread sleeps when no fresh data is found.
# 5 seconds — long enough to not burn CPU, short enough to respond quickly
# when the user starts typing again.
const POLL_INTERVAL_EMPTY = 5.0

# GRUG: How long the background thread sleeps after processing a batch.
# Shorter than empty poll — there might be more fresh data right behind.
const POLL_INTERVAL_AFTER_BATCH = 1.0

# GRUG: Minimum number of fresh entries needed to even bother processing.
# Less than this = not enough signal. Wait for more.
const MIN_BATCH_THRESHOLD = 50

# GRUG: Intensity increment per co-occurrence observation from user input.
# User-typed co-occurrence is a STRONGER signal than scan-cycle co-firing
# because the user CHOSE to put those concepts together. 2.0 vs 1.0.
const INPUT_CO_OCCUR_INCREMENT = 2.0

# ==============================================================================
# HASH LEDGER — tracks which MESSAGE_HISTORY entries have been consumed
# ==============================================================================
# GRUG: Key is hash(role * "|" * text). This is stable — the same message
# always maps to the same hash. Value is always true (consumed).
# If a hash is NOT in the ledger, the entry is fresh.
# If a hash IS in the ledger, it's already been digested — skip it.

const _LEDGER = Dict{UInt64, Bool}()
const _LEDGER_LOCK = ReentrantLock()

# GRUG: Counters for diagnostics
const _STATS = Atomic{Int}(0)       # total entries consumed ever
const _BATCHES = Atomic{Int}(0)     # total batches processed ever
const _LAST_BATCH_TIME = Atomic{Float64}(0.0)  # timestamp of last batch

# ==============================================================================
# BACKGROUND THREAD STATE
# ==============================================================================

const _THREAD_RUNNING = Atomic{Bool}(false)  # is the thread alive?
const _THREAD_REF = Ref{Task}(Task(() -> nothing))  # reference to the async task

# ==============================================================================
# LEDGER OPERATIONS
# ==============================================================================

"""
    _entry_hash(role::String, text::String)::UInt64

GRUG: Compute a stable hash for a message entry. Same input = same hash.
Uses role + "|" + text so different roles with same text get different hashes.
"""
function _entry_hash(role::String, text::String)::UInt64
    return hash(role * "|" * text)
end

"""
    is_consumed(h::UInt64)::Bool

GRUG: Check if a hash has already been consumed. Thread-safe.
"""
function is_consumed(h::UInt64)::Bool
    return lock(() -> haskey(_LEDGER, h), _LEDGER_LOCK)
end

"""
    mark_consumed!(h::UInt64)

GRUG: Mark a hash as consumed. Thread-safe. Evicts oldest entry if
ledger is at cap.
"""
function mark_consumed!(h::UInt64)
    lock(_LEDGER_LOCK) do
        if !haskey(_LEDGER, h)
            # GRUG: Evict if at cap. We evict a random consumed entry —
            # its data has already been digested so losing the flag is fine.
            # The hash just prevents double-processing; old consumed entries
            # don't need to be tracked forever.
            if length(_LEDGER) >= LEDGER_CAP
                # GRUG: Delete a random entry. It's already consumed,
                # so the worst case is we re-process one old message.
                # Better than crashing or growing without limit.
                keys_vec = collect(keys(_LEDGER))
                delete!(_LEDGER, keys_vec[rand(1:length(keys_vec))])
            end
            _LEDGER[h] = true
        end
    end
end

"""
    ledger_size()::Int

GRUG: How many entries in the ledger. For diagnostics.
"""
function ledger_size()::Int
    return lock(() -> length(_LEDGER), _LEDGER_LOCK)
end

# ==============================================================================
# FRESH ENTRY SCANNER — finds unconsumed messages
# ==============================================================================

"""
    scan_fresh_entries(;
        message_history_ref,
        history_lock_ref,
        batch_size::Int = BATCH_SIZE,
        min_threshold::Int = MIN_BATCH_THRESHOLD
    )::Vector{Tuple{String, String, UInt64}}

GRUG: Walk MESSAGE_HISTORY and collect fresh (unconsumed) entries.
Returns a vector of (role, text, hash) tuples. Only entries whose
hash is NOT in the ledger are returned — these are the fresh ones.

Stops at batch_size entries OR end of history, whichever comes first.
If fewer than min_threshold fresh entries are found, returns empty
(the thread will sleep and try again later).

Thread-safe: takes the history lock for the walk, ledger lock for
consumption checks.
"""
function scan_fresh_entries(;
    message_history_ref,
    history_lock_ref,
    batch_size::Int = BATCH_SIZE,
    min_threshold::Int = MIN_BATCH_THRESHOLD
)::Vector{Tuple{String, String, UInt64}}

    fresh = Tuple{String, String, UInt64}[]

    # GRUG: Walk MESSAGE_HISTORY under lock.
    lock(history_lock_ref) do
        for msg in message_history_ref
            h = _entry_hash(msg.role, msg.text)
            if !is_consumed(h)
                push!(fresh, (msg.role, msg.text, h))
            end
            length(fresh) >= batch_size && break
        end
    end

    # GRUG: Not enough fresh data? Return empty — thread should sleep.
    if length(fresh) < min_threshold
        return Tuple{String, String, UInt64}[]
    end

    return fresh
end

# ==============================================================================
# BATCH PROCESSOR — digest fresh entries into growth data
# ==============================================================================

"""
    process_batch!(fresh_entries::Vector{Tuple{String, String, UInt64}};
                   co_occur_fn::Function = (id_a, id_b, increment) -> nothing,
                   token_overlap_fn::Function = (id_a, id_b) -> 0.0,
                   node_map_ref,
                   node_lock_ref)::Int

GRUG: Process a batch of fresh message entries into growth data.

For each USER role entry:
  1. Tokenize the text
  2. Find which existing nodes match the tokens (pattern overlap)
  3. Record co-occurrence between matched nodes (they were expressed
     together in the SAME user input — strong relational signal)
  4. Feed the co-occurrence data to the co-activation accumulator
     via co_occur_fn

Then marks all entries in the batch as consumed in the ledger.

Returns the number of entries processed.
"""
function process_batch!(fresh_entries::Vector{Tuple{String, String, UInt64}};
                        co_occur_fn::Function = (id_a, id_b, increment) -> nothing,
                        token_overlap_fn::Function = (id_a, id_b) -> 0.0,
                        node_map_ref,
                        node_lock_ref)::Int

    if isempty(fresh_entries)
        return 0
    end

    entries_processed = 0
    co_occur_observations = 0

    for (role, text, h) in fresh_entries
        # GRUG: Only mine USER inputs for co-occurrence data.
        # System messages are generated by the engine — they don't carry
        # the user's intentional concept clustering signal.
        # Other roles (Assistant, etc.) are also engine-generated.
        if role != "User"
            mark_consumed!(h)
            entries_processed += 1
            continue
        end

        # GRUG: Find which alive non-image nodes have pattern overlap
        # with this user input. These are the nodes the user "touched"
        # by expressing these concepts.
        input_tokens = Set(split(lowercase(strip(text))))

        touched_node_ids = String[]

        lock(node_lock_ref) do
            for (id, node) in node_map_ref
                node.is_grave && continue
                node.is_image_node && continue
                # GRUG: Check if any input tokens appear in node pattern
                pattern_tokens = Set(split(lowercase(strip(node.pattern))))
                if !isempty(intersect(input_tokens, pattern_tokens))
                    push!(touched_node_ids, id)
                end
            end
        end

        # GRUG: Record co-occurrence between ALL touched node pairs.
        # The user expressed these concepts together — that's a strong
        # relational signal. 2.0 increment (vs 1.0 for scan co-firing).
        if length(touched_node_ids) >= 2
            sorted_ids = sort(touched_node_ids)
            n = length(sorted_ids)
            for i in 1:(n-1)
                for j in (i+1):n
                    id_a = sorted_ids[i]
                    id_b = sorted_ids[j]
                    # GRUG: Check token overlap between the nodes themselves.
                    # Same filter as observe_co_firing! — no junk pairs.
                    overlap = token_overlap_fn(id_a, id_b)
                    if overlap >= 0.05  # MIN_OVERLAP_FOR_TRACKING
                        co_occur_fn(id_a, id_b, INPUT_CO_OCCUR_INCREMENT)
                        co_occur_observations += 1
                    end
                end
            end
        end

        # GRUG: Mark this entry consumed regardless of whether it
        # produced co-occurrence data. Even a user input that doesn't
        # touch any existing nodes has been "seen" — don't re-process it.
        mark_consumed!(h)
        entries_processed += 1
    end

    # GRUG: Update stats
    atomic_add!(_STATS, entries_processed)
    atomic_add!(_BATCHES, 1)
    atomic_add!(_LAST_BATCH_TIME, time())

    return entries_processed
end

# ==============================================================================
# BACKGROUND THREAD — the gut that keeps digesting
# ==============================================================================

"""
    start_input_ledger_thread!(;
        message_history_ref,
        history_lock_ref,
        node_map_ref,
        node_lock_ref,
        co_occur_fn::Function,
        token_overlap_fn::Function)

GRUG: Start the background input ledger thread. It runs forever in a
loop: scan for fresh entries → process batch → sleep → repeat.

If the thread crashes, it auto-restarts after a delay. The thread
should NEVER die — it's the gut. Guts don't stop.

Thread-safe: all shared state access goes through locks.
"""
function start_input_ledger_thread!(;
    message_history_ref,
    history_lock_ref,
    node_map_ref,
    node_lock_ref,
    co_occur_fn::Function,
    token_overlap_fn::Function)

    if _THREAD_RUNNING[]
        @warn "[INPUT_LEDGER] Thread already running. Not starting another."
        return
    end

    _THREAD_RUNNING[] = true

    _THREAD_REF[] = @async begin
        # GRUG: Outer crash-recovery loop. If the inner loop throws,
        # we log it, wait, and restart. The thread NEVER dies.
        while _THREAD_RUNNING[]
            try
                _ledger_inner_loop(;
                    message_history_ref = message_history_ref,
                    history_lock_ref = history_lock_ref,
                    node_map_ref = node_map_ref,
                    node_lock_ref = node_lock_ref,
                    co_occur_fn = co_occur_fn,
                    token_overlap_fn = token_overlap_fn,
                )
            catch e
                # GRUG: Thread crashed! Log it but DON'T die.
                # Auto-restart after a delay. The gut keeps going.
                println("[INPUT_LEDGER] !!! Thread crashed: $e. Auto-restarting in 30s...")
                sleep(30.0)
            end
        end
        println("[INPUT_LEDGER] 🛑 Thread stopped.")
    end

    println("[INPUT_LEDGER] 🧵  Background thread started. Watching for fresh input...")
end

"""
    _ledger_inner_loop(; kwargs...)

GRUG: The inner loop of the background thread. Scans for fresh entries,
processes batches, sleeps when empty. Runs until _THREAD_RUNNING is false.
"""
function _ledger_inner_loop(;
    message_history_ref,
    history_lock_ref,
    node_map_ref,
    node_lock_ref,
    co_occur_fn::Function,
    token_overlap_fn::Function)

    while _THREAD_RUNNING[]
        # GRUG: Scan for fresh entries.
        fresh = scan_fresh_entries(;
            message_history_ref = message_history_ref,
            history_lock_ref = history_lock_ref,
        )

        if isempty(fresh)
            # GRUG: Nothing fresh. Sleep and try again.
            sleep(POLL_INTERVAL_EMPTY)
            continue
        end

        # GRUG: Process the batch. This is where input becomes growth data.
        processed = process_batch!(fresh;
            co_occur_fn = co_occur_fn,
            token_overlap_fn = token_overlap_fn,
            node_map_ref = node_map_ref,
            node_lock_ref = node_lock_ref,
        )

        if processed > 0
            # GRUG: Report what we digested.
            println("[INPUT_LEDGER] 📝  Digested $(processed) fresh entries into growth data")
        end

        # GRUG: Brief sleep after processing — there might be more fresh data.
        sleep(POLL_INTERVAL_AFTER_BATCH)
    end
end

"""
    stop_input_ledger_thread!()

GRUG: Signal the background thread to stop. It will finish its current
batch and then exit. Does NOT wait for it — just sets the flag.
"""
function stop_input_ledger_thread!()
    _THREAD_RUNNING[] = false
    println("[INPUT_LEDGER] 🛑 Stop signal sent to background thread.")
end

# ==============================================================================
# STATUS & DIAGNOSTICS
# ==============================================================================

"""
    get_input_ledger_status()::String

GRUG: Human-readable status of the input ledger thread.
"""
function get_input_ledger_status()::String
    lines = String[]
    push!(lines, "═══ INPUT LEDGER ═══")
    push!(lines, "  Thread running   : $(_THREAD_RUNNING[])")
    push!(lines, "  Ledger entries   : $(ledger_size()) / $(LEDGER_CAP)")
    push!(lines, "  Total consumed   : $(_STATS[])")
    push!(lines, "  Batches processed: $(_BATCHES[])")
    if _LAST_BATCH_TIME[] > 0
        ago = round(time() - _LAST_BATCH_TIME[], digits=1)
        push!(lines, "  Last batch       : $(ago)s ago")
    else
        push!(lines, "  Last batch       : never")
    end
    push!(lines, "  Batch size       : $(BATCH_SIZE)")
    push!(lines, "  Min threshold    : $(MIN_BATCH_THRESHOLD)")
    push!(lines, "  Poll (empty)     : $(POLL_INTERVAL_EMPTY)s")
    push!(lines, "  Poll (after)     : $(POLL_INTERVAL_AFTER_BATCH)s")
    return join(lines, "\n")
end

# ==============================================================================
# SERIALIZATION — for specimen save/load
# ==============================================================================

"""
    serialize_input_ledger()::Dict{String, Any}

GRUG: Serialize the ledger for specimen save. Only the hash keys are
saved (values are always true). Keeps specimens compact.
"""
function serialize_input_ledger()::Dict{String, Any}
    hash_list = lock(_LEDGER_LOCK) do
        [string(h) for h in keys(_LEDGER)]
    end

    return Dict{String, Any}(
        "ledger_hashes"    => hash_list,
        "total_consumed"   => _STATS[],
        "batches_processed" => _BATCHES[],
        "ledger_cap"       => LEDGER_CAP,
    )
end

"""
    deserialize_input_ledger!(data)

GRUG: Restore the ledger from specimen data. Merges with existing ledger.
"""
function deserialize_input_ledger!(data)
    hash_list = get(data, "ledger_hashes", [])

    lock(_LEDGER_LOCK) do
        for h_str in hash_list
            h = parse(UInt64, String(h_str))
            if !haskey(_LEDGER, h)
                _LEDGER[h] = true
            end
        end
        # GRUG: Enforce cap after deserialization
        while length(_LEDGER) > LEDGER_CAP
            keys_vec = collect(keys(_LEDGER))
            delete!(_LEDGER, keys_vec[rand(1:length(keys_vec))])
        end
    end

    # GRUG: Restore counters
    _STATS[] = max(_STATS[], get(data, "total_consumed", 0))
    _BATCHES[] = max(_BATCHES[], get(data, "batches_processed", 0))
end

"""
    reset_input_ledger!()

GRUG: Clear the entire ledger and reset counters. For testing.
"""
function reset_input_ledger!()
    lock(_LEDGER_LOCK) do
        empty!(_LEDGER)
    end
    _STATS[] = 0
    _BATCHES[] = 0
    _LAST_BATCH_TIME[] = 0.0
end

end # module InputLedger
