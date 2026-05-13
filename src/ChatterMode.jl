# ChatterMode.jl
# ==============================================================================
# IDLE / CHATTER MODE - LOW-FLOW NODE GOSSIP SYSTEM (v7.1)
# ==============================================================================
# GRUG: When cave is quiet (no user input = low flow / idle mode), nodes do NOT vote.
# Instead, at DISCRETE RANDOM INTERVALS (120s ±30s), a random group of 50-500
# pattern-related nodes are selected to CHATTER.
#
# POPULATION GATE: Chatter ONLY fires if total alive non-image node count >= 1000.
# New specimens with < 1000 nodes do NOT chatter. Period.
# Minimum eligible group size is floored at available population (if < 50 eligible,
# use whatever is available as ceiling).
#
# CHATTER MECHANICS (v7.1):
#   - Selected nodes exchange their pattern + vote_slot params as JSON to neighbors
#   - Exchange happens on a COINFLIP (not guaranteed)
#   - ONLY WEAK NODES MORPH: receiver must be WEAKER than sender to accept blend
#   - Strong nodes signal but do NOT change. Weak nodes drift toward strong neighbors.
#   - ONCE-PER-DAY MORPH LIMIT: each node can only morph once every 24 hours.
#     Tracked via MORPH_COOLDOWN_MAP (node_id -> last_morph_timestamp).
#   - Copied content makes receiving node's pattern/vote_slot MORE SIMILAR to sender
#   - Chatter spawns EPHEMERAL REGULAR-SPEED CLONES (not part of flowing map)
#   - Nodes get JITTER on their strength values during chatter (levels playing field)
#   - ANTI-COLLISION: nodes track who they've talked to this round (no double-chatter)
#   - If USER INPUT arrives during chatter: queue it, wait for chatter to finish
# ==============================================================================

module ChatterMode

using Random
using JSON

export ChatterSession, start_chatter_session!, process_chatter_queue!
export ChatterNodeClone, ChatterLog, get_chatter_status
export should_trigger_idle, is_morph_allowed, record_morph!
export MORPH_COOLDOWN_MAP, MORPH_COOLDOWN_LOCK
export MIN_POPULATION_FOR_CHATTER, IDLE_THRESHOLD_SECONDS

# ==============================================================================
# CONSTANTS (v7.1)
# ==============================================================================

# GRUG: Minimum node population before chatter is allowed.
# New specimens with < 1000 nodes do NOT chatter. They need to grow first.
const MIN_POPULATION_FOR_CHATTER = 1000

# GRUG: Default idle threshold in seconds before an idle event (chatter OR phagy) fires.
# Both chatter and phagy use this SAME timer. Much slower than v7 (was 30s, now 120s).
# Jitter band: ±30s (was ±5s). This means idle events fire between 90s and 150s apart.
const IDLE_THRESHOLD_SECONDS = 120.0

# GRUG: Jitter band for idle threshold. Random offset in [-JITTER, +JITTER].
const IDLE_JITTER_SECONDS = 30.0

# GRUG: Chatter group size bounds. 50-500 nodes per gossip round (was 100-800).
# If fewer than 50 eligible nodes exist, floor at whatever is available.
const CHATTER_GROUP_MIN = 50
const CHATTER_GROUP_MAX = 500

# GRUG: Morph cooldown period in seconds. 24 hours = 86400 seconds.
# A node that morphed cannot morph again until this cooldown expires.
const MORPH_COOLDOWN_SECONDS = 86400.0

# ==============================================================================
# ERROR TYPES - GRUG: NO SILENT FAILURES!
# ==============================================================================

struct ChatterError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ChatterError) =
    print(io, "ChatterError: ", e.msg)

# ==============================================================================
# MORPH COOLDOWN TRACKING (ONCE-PER-DAY LIMIT)
# ==============================================================================

# GRUG: Global map of node_id -> last morph timestamp (Float64, epoch seconds).
# Nodes can only morph once per 24 hours. This prevents runaway drift where
# weak nodes get blended every single chatter round and lose all identity.
const MORPH_COOLDOWN_MAP = Dict{String, Float64}()
const MORPH_COOLDOWN_LOCK = ReentrantLock()

"""
is_morph_allowed(node_id::String)::Bool

GRUG: Check if a node is allowed to morph right now.
Returns true if the node has never morphed OR if >= 24 hours since last morph.
Returns false if the node morphed within the last 24 hours.
"""
function is_morph_allowed(node_id::String)::Bool
    if strip(node_id) == ""
        throw(ChatterError("!!! FATAL: is_morph_allowed got empty node_id! !!!"))
    end
    lock(MORPH_COOLDOWN_LOCK) do
        if !haskey(MORPH_COOLDOWN_MAP, node_id)
            # GRUG: Node has never morphed. Allow it.
            return true
        end
        last_morph = MORPH_COOLDOWN_MAP[node_id]
        elapsed = time() - last_morph
        return elapsed >= MORPH_COOLDOWN_SECONDS
    end
end

"""
record_morph!(node_id::String)

GRUG: Record that a node just morphed. Stamps current time into cooldown map.
Next morph attempt by this node will be blocked until 24 hours pass.
"""
function record_morph!(node_id::String)
    if strip(node_id) == ""
        throw(ChatterError("!!! FATAL: record_morph! got empty node_id! !!!"))
    end
    lock(MORPH_COOLDOWN_LOCK) do
        MORPH_COOLDOWN_MAP[node_id] = time()
    end
end

# ==============================================================================
# CHATTER NODE CLONE (EPHEMERAL)
# ==============================================================================

# GRUG: Clones are ephemeral! They only exist during a chatter session.
# They carry a snapshot of a node's pattern and vote_slot data for gossip exchange.
# They are NOT part of the main NODE_MAP and do not vote in real sessions.
mutable struct ChatterNodeClone
    source_id::String           # GRUG: ID of the real node this clone came from
    pattern::String             # GRUG: Snapshot of pattern at chatter time
    vote_slot::String           # GRUG: Snapshot of action_packet at chatter time
    strength::Float64           # GRUG: Snapshot of strength (jittered for chatter!)
    original_strength::Float64  # GRUG: UN-jittered strength for weak/strong comparison
    talked_to::Set{String}      # GRUG: Anti-collision: who this clone has chatted with
    morphed_this_session::Bool  # GRUG: Track if this clone morphed (for diff application)
end

# ==============================================================================
# CHATTER SESSION
# ==============================================================================

# GRUG: One chatter session covers one idle gossip round.
mutable struct ChatterSession
    session_id::String
    start_time::Float64
    end_time::Float64             # GRUG: 0.0 means session still running
    group_size::Int               # GRUG: How many nodes were selected (50-500)
    clones::Vector{ChatterNodeClone}
    is_running::Bool
    queued_inputs::Vector{String} # GRUG: User inputs that arrived during chatter
    exchanges_completed::Int      # GRUG: How many gossip exchanges happened
    copies_accepted::Int          # GRUG: How many times a weak node accepted a morph
    morphs_blocked_cooldown::Int  # GRUG: How many morphs blocked by 24h cooldown
    morphs_blocked_strength::Int  # GRUG: How many morphs blocked by strength gate
end

# GRUG: Chatter log for diagnostics. Keeps last N sessions.
const CHATTER_LOG = ChatterSession[]
const CHATTER_LOG_LOCK = ReentrantLock()
const MAX_CHATTER_LOG = 50

# GRUG: Global flag: is chatter currently running?
# Main loop checks this before processing user input.
const CHATTER_RUNNING = Ref{Bool}(false)
const CHATTER_LOCK = ReentrantLock()
const INPUT_QUEUE = String[]
const INPUT_QUEUE_LOCK = ReentrantLock()

# ==============================================================================
# CHATTER LOG HELPER
# ==============================================================================

struct ChatterLog
    session_id::String
    start_time::Float64
    end_time::Float64
    group_size::Int
    exchanges::Int
    copies::Int
    morphs_blocked_cooldown::Int
    morphs_blocked_strength::Int
    queued_inputs::Int
end

"""
get_chatter_status()::NamedTuple

GRUG: Return current chatter state for diagnostics and CLI /status command.
"""
function get_chatter_status()
    is_running = lock(CHATTER_LOCK) do
        CHATTER_RUNNING[]
    end
    queue_depth = lock(INPUT_QUEUE_LOCK) do
        length(INPUT_QUEUE)
    end
    log_count = lock(CHATTER_LOG_LOCK) do
        length(CHATTER_LOG)
    end
    cooldown_count = lock(MORPH_COOLDOWN_LOCK) do
        length(MORPH_COOLDOWN_MAP)
    end
    return (
        is_running      = is_running,
        queue_depth     = queue_depth,
        sessions_run    = log_count,
        nodes_on_cooldown = cooldown_count
    )
end

# ==============================================================================
# INPUT QUEUE (USER INPUT DURING CHATTER)
# ==============================================================================

"""
enqueue_input!(input::String)

GRUG: If user sends input while chatter is running, park it here.
Main loop will drain the queue after chatter finishes.
"""
function enqueue_input!(input::String)
    if strip(input) == ""
        throw(ChatterError("!!! FATAL: enqueue_input! got empty string! !!!"))
    end
    lock(INPUT_QUEUE_LOCK) do
        push!(INPUT_QUEUE, input)
    end
    println("[CHATTER] ⏸  User input queued (chatter in progress). Queue depth: $(length(INPUT_QUEUE))")
end

"""
drain_input_queue!()::Vector{String}

GRUG: After chatter finishes, drain and return all queued inputs for processing.
Clears the queue. No silent failures if queue empty (just returns empty vector).
"""
function drain_input_queue!()::Vector{String}
    return lock(INPUT_QUEUE_LOCK) do
        queued = copy(INPUT_QUEUE)
        empty!(INPUT_QUEUE)
        queued
    end
end

# ==============================================================================
# STRENGTH JITTER FOR CHATTER (LEVEL PLAYING FIELD)
# ==============================================================================

"""
jitter_clone_strength(strength::Float64)::Float64

GRUG: Apply a small random jitter to clone strength during chatter.
This levels the playing field slightly so strong nodes don't completely dominate gossip.
Jitter is bounded: strong nodes stay relatively strong, weak ones stay weak.
"""
function jitter_clone_strength(strength::Float64)::Float64
    if isnan(strength) || isinf(strength)
        throw(ChatterError("!!! FATAL: jitter_clone_strength got NaN or Inf! !!!"))
    end
    # GRUG: Jitter magnitude scales inversely with strength.
    # Strong node: small jitter (0.02-0.06). Weak node: bigger jitter (0.05-0.15).
    # This gives weaker nodes a fighting chance in chatter rounds.
    jitter_range = 0.02 + (1.0 - clamp(strength, 0.0, 1.0)) * 0.13
    jitter = (rand() * 2.0 - 1.0) * jitter_range
    return clamp(strength + jitter, 0.0, 1.0)
end

# ==============================================================================
# ANTI-COLLISION HELPERS
# ==============================================================================

"""
can_chat(sender::ChatterNodeClone, receiver_id::String)::Bool

GRUG: Anti-collision check. A clone cannot chat with the same node twice in one session.
Returns true if exchange is allowed, false if already talked.
"""
function can_chat(sender::ChatterNodeClone, receiver_id::String)::Bool
    return !(receiver_id in sender.talked_to)
end

"""
mark_chatted!(sender::ChatterNodeClone, receiver_id::String)

GRUG: Record that sender has chatted with receiver_id this session.
"""
function mark_chatted!(sender::ChatterNodeClone, receiver_id::String)
    push!(sender.talked_to, receiver_id)
end

# ==============================================================================
# PATTERN SIMILARITY HELPER (FOR LATCH + COPY BIAS)
# ==============================================================================

"""
pattern_similarity(p1::String, p2::String)::Float64

GRUG: Rough token-overlap similarity between two pattern strings.
Returns [0.0, 1.0]. Used to find "similar" neighbors for latching.
"""
function pattern_similarity(p1::String, p2::String)::Float64
    if strip(p1) == "" || strip(p2) == ""
        return 0.0
    end
    tokens1 = Set(split(lowercase(strip(p1))))
    tokens2 = Set(split(lowercase(strip(p2))))
    if isempty(tokens1) || isempty(tokens2)
        return 0.0
    end
    overlap = length(intersect(tokens1, tokens2))
    union_size = length(union(tokens1, tokens2))
    return union_size > 0 ? Float64(overlap) / Float64(union_size) : 0.0
end

# ==============================================================================
# MERGE PATTERNS (GOSSIP COPY LOGIC)
# ==============================================================================

"""
merge_patterns(receiver_pattern::String, sender_pattern::String,
               blend_factor::Float64)::String

GRUG: When receiver accepts gossip from sender, their pattern becomes MORE SIMILAR.
Grug do this by injecting some of sender's tokens into receiver's pattern.
blend_factor controls how many sender tokens get injected [0.0, 1.0].
"""
function merge_patterns(
    receiver_pattern::String,
    sender_pattern::String,
    blend_factor::Float64
)::String
    if strip(receiver_pattern) == ""
        throw(ChatterError("!!! FATAL: merge_patterns got empty receiver_pattern! !!!"))
    end
    if strip(sender_pattern) == ""
        # GRUG: Sender has no pattern to copy. Return receiver unchanged.
        return receiver_pattern
    end
    blend_factor = clamp(blend_factor, 0.0, 1.0)

    r_tokens = split(lowercase(strip(receiver_pattern)))
    s_tokens = split(lowercase(strip(sender_pattern)))

    # GRUG: How many sender tokens to inject?
    n_inject = max(1, round(Int, length(s_tokens) * blend_factor))
    # GRUG: Pick random subset of sender tokens to inject
    inject_tokens = sample(s_tokens, min(n_inject, length(s_tokens)); replace=false)

    # GRUG: Add injected tokens if not already present (no duplicates)
    r_set = Set(r_tokens)
    for tok in inject_tokens
        if !(tok in r_set)
            push!(r_tokens, tok)
            push!(r_set, tok)
        end
    end

    return join(r_tokens, " ")
end

# GRUG: Bring sample() for random selection without replacement
using Random: shuffle

function sample(v::AbstractVector, n::Int; replace::Bool=false)
    if n <= 0
        return eltype(v)[]
    end
    if replace
        return [v[rand(1:length(v))] for _ in 1:n]
    else
        return shuffle(v)[1:min(n, length(v))]
    end
end

# ==============================================================================
# CHATTER SESSION RUNNER (v7.1)
# ==============================================================================

"""
start_chatter_session!(node_map_snapshot::Vector{Tuple{String, String, String, Float64}})::ChatterSession

GRUG: Run one full chatter session.

node_map_snapshot is a Vector of (node_id, pattern, action_packet, strength) tuples.
This is a SNAPSHOT - chatter works on copies, not live nodes (ephemeral clones).

POPULATION GATE (v7.1): If snapshot has < MIN_POPULATION_FOR_CHATTER (1000) nodes,
chatter is REFUSED. New specimens don't chatter. Throw ChatterError.

GROUP SIZE (v7.1): 50-500 nodes per round. If fewer than 50 eligible, use whatever
is available as the ceiling (floor at population).

WEAK-ONLY MORPH (v7.1): Only receivers WEAKER than the sender can accept a pattern
blend. Strong nodes signal but never change. Weak nodes drift toward strong neighbors.

ONCE-PER-DAY MORPH (v7.1): Each node can only morph once every 24 hours.
Tracked via MORPH_COOLDOWN_MAP. If a node morphed within 24h, it is skipped.

STEPS:
  1. Population gate: refuse if < 1000 nodes
  2. Select random group of 50-500 nodes
  3. Create ephemeral clones with jittered strength (preserve original for comparison)
  4. For each clone, on a coinflip, attempt to exchange with random neighbor clone
  5. Receiver MUST be weaker than sender AND not on morph cooldown
  6. If accepted, receiver clone's pattern/vote_slot blends toward sender
  7. Session ends; returns session record for the caller to apply diffs back to live nodes

RETURNS: ChatterSession with updated clone data.
Caller in Main.jl applies clone diffs back to real nodes.
"""
function start_chatter_session!(
    node_map_snapshot::Vector{Tuple{String, String, String, Float64}}
)::ChatterSession

    if isempty(node_map_snapshot)
        throw(ChatterError("!!! FATAL: start_chatter_session! got empty node_map_snapshot! !!!"))
    end

    # GRUG: POPULATION GATE (v7.1) — chatter only for mature specimens (1000+ nodes).
    # New specimens don't chatter. They need to grow first via /grow and /mission.
    if length(node_map_snapshot) < MIN_POPULATION_FOR_CHATTER
        throw(ChatterError(
            "!!! POPULATION GATE: Chatter requires >= $(MIN_POPULATION_FOR_CHATTER) nodes, " *
            "got $(length(node_map_snapshot)). New specimens don't chatter. !!!"
        ))
    end

    # GRUG: Mark chatter as running so main loop queues user input
    lock(CHATTER_LOCK) do
        CHATTER_RUNNING[] = true
    end

    session_id = "chatter_$(round(Int, time() * 1000))"
    session_start = time()

    try
        # GRUG: STEP 1 - Select random group size (50-500, bounded by available nodes)
        # If fewer than CHATTER_GROUP_MIN (50) nodes, floor at whatever is available.
        max_nodes = length(node_map_snapshot)
        group_floor = min(CHATTER_GROUP_MIN, max_nodes)
        group_ceiling = min(CHATTER_GROUP_MAX, max_nodes)
        group_size = rand(group_floor:group_ceiling)

        # GRUG: Shuffle and pick group
        shuffled = shuffle(node_map_snapshot)
        group = shuffled[1:group_size]

        # GRUG: STEP 2 - Create ephemeral clones with jittered strength
        # Store BOTH jittered and original strength so we can do weak/strong comparison
        # using the un-jittered original (jitter is for gossip probability, not gate logic).
        clones = ChatterNodeClone[]
        for (nid, pattern, action_packet, strength) in group
            jittered_str = jitter_clone_strength(strength)
            push!(clones, ChatterNodeClone(
                nid, pattern, action_packet, jittered_str, strength, Set{String}(), false
            ))
        end

        session = ChatterSession(
            session_id, session_start, 0.0, group_size,
            clones, true, String[], 0, 0, 0, 0
        )

        println("[CHATTER] 🗣  Session $session_id started. Group size: $group_size nodes (population: $max_nodes).")

        # GRUG: STEP 3 - Run gossip exchanges
        # Each clone gets a chance to send to a random neighbor clone
        # Shuffle clone order to avoid positional bias
        clone_order = shuffle(1:length(clones))

        for sender_idx in clone_order
            sender = clones[sender_idx]

            # GRUG: Sender coinflip (50/50): does this clone initiate gossip?
            rand() < 0.5 || continue

            # GRUG: Pick a random receiver from the clone group (not self, anti-collision)
            eligible_receivers = [
                i for i in 1:length(clones)
                if i != sender_idx && can_chat(sender, clones[i].source_id)
            ]

            if isempty(eligible_receivers)
                # GRUG: No eligible receivers. This clone already talked to everyone. Skip.
                continue
            end

            receiver_idx = eligible_receivers[rand(1:length(eligible_receivers))]
            receiver = clones[receiver_idx]

            # GRUG: Anti-collision: mark both as having talked
            mark_chatted!(sender, receiver.source_id)
            mark_chatted!(receiver, sender.source_id)
            session.exchanges_completed += 1

            # GRUG: STRENGTH GATE (v7.1) — Only weak nodes morph.
            # Receiver must be STRICTLY WEAKER than sender (original un-jittered strength).
            # Strong nodes signal to weaker nodes. They do not change themselves.
            if receiver.original_strength >= sender.original_strength
                session.morphs_blocked_strength += 1
                continue
            end

            # GRUG: MORPH COOLDOWN GATE (v7.1) — Once per day per node.
            # If this receiver morphed within the last 24 hours, skip it.
            if !is_morph_allowed(receiver.source_id)
                session.morphs_blocked_cooldown += 1
                continue
            end

            # GRUG: STEP 4 - Receiver does BIASED coinflip.
            # Strong senders are MORE likely to be copied.
            # copy_probability = sender.strength biased [0.3, 0.8]
            copy_prob = clamp(0.3 + sender.original_strength * 0.5, 0.3, 0.8)

            if rand() < copy_prob
                # GRUG: COPY ACCEPTED! Weak receiver blends pattern toward strong sender.
                # Blend factor scales with sender strength [0.1, 0.4]
                blend = clamp(0.1 + sender.original_strength * 0.3, 0.1, 0.4)

                try
                    merged_pattern = merge_patterns(receiver.pattern, sender.pattern, blend)
                    receiver.pattern = merged_pattern

                    # GRUG: Also blend vote_slot (action_packet) slightly.
                    # Less aggressive than pattern blend (0.5x the blend factor).
                    merged_vote = merge_patterns(receiver.vote_slot, sender.vote_slot, blend * 0.5)
                    receiver.vote_slot = merged_vote

                    # GRUG: Mark this receiver as morphed and record cooldown
                    receiver.morphed_this_session = true
                    record_morph!(receiver.source_id)
                    session.copies_accepted += 1
                catch e
                    # GRUG: merge_patterns failure is non-fatal in chatter context.
                    # Log it but keep session running. One bad merge = not a system death.
                    println("[CHATTER] ⚠  merge_patterns failed for $(receiver.source_id): $e")
                end
            end
        end

        # GRUG: STEP 5 - Session complete
        session.end_time = time()
        session.is_running = false

        println("[CHATTER] ✅  Session $session_id complete. " *
                "Exchanges: $(session.exchanges_completed), " *
                "Morphs: $(session.copies_accepted), " *
                "Blocked(strength): $(session.morphs_blocked_strength), " *
                "Blocked(cooldown): $(session.morphs_blocked_cooldown).")

        # GRUG: Store session in log (bounded)
        lock(CHATTER_LOG_LOCK) do
            push!(CHATTER_LOG, session)
            # GRUG: Trim log if over max size
            while length(CHATTER_LOG) > MAX_CHATTER_LOG
                deleteat!(CHATTER_LOG, 1)
            end
        end

        return session

    catch e
        # GRUG: If chatter session explodes, mark it dead and rethrow.
        # NEVER silently swallow errors in chatter. Main loop must know.
        if e isa ChatterError
            # GRUG: ChatterErrors are expected (population gate, etc). Log and rethrow.
            println("[CHATTER] ⛔  $session_id: $(e.msg)")
            rethrow(e)
        else
            println("[CHATTER] !!! FATAL: Chatter session $session_id exploded: $e !!!")
            rethrow(e)
        end
    finally
        # GRUG: ALWAYS clear the running flag, even if session crashed.
        # Otherwise main loop stays frozen waiting for chatter that will never end!
        lock(CHATTER_LOCK) do
            CHATTER_RUNNING[] = false
        end
        println("[CHATTER] 🔓  Chatter lock released. Main loop can resume.")
    end
end

# ==============================================================================
# APPLY CHATTER DIFFS TO LIVE NODES
# ==============================================================================

"""
apply_chatter_diffs!(session::ChatterSession, node_map::Dict, node_lock::ReentrantLock)

GRUG: After chatter session completes, apply the clone diffs back to the real NODE_MAP.
Only nodes that ACTUALLY MORPHED during chatter get updated (v7.1: morphed_this_session flag).
This is the "ephemeral -> real" merge step.

IMPORTANT: Only pattern and action_packet are updated from chatter.
Strength, neighbors, and grave status are NOT touched by chatter diffs.
"""
function apply_chatter_diffs!(
    session::ChatterSession,
    node_map::Dict,
    node_lock::ReentrantLock
)::Int
    if !isa(session, ChatterSession)
        throw(ChatterError("!!! FATAL: apply_chatter_diffs! got invalid session! !!!"))
    end

    updates_applied = 0

    lock(node_lock) do
        for clone in session.clones
            # GRUG: Only apply diffs for clones that actually morphed (v7.1)
            !clone.morphed_this_session && continue

            if !haskey(node_map, clone.source_id)
                # GRUG: Node may have been graved during chatter. Skip it safely.
                continue
            end

            node = node_map[clone.source_id]

            # GRUG: Only update if pattern actually changed during gossip
            if node.pattern != clone.pattern
                node.pattern = clone.pattern
                # GRUG: Re-bake the signal since pattern changed!
                # (words_to_signal is defined in Engine.jl, called from Main.jl context)
                # We store the new pattern; Engine.jl re-scans will use updated pattern.
                updates_applied += 1
            end
        end
    end

    if updates_applied > 0
        println("[CHATTER] 📝  Applied $updates_applied pattern updates from chatter session $(session.session_id).")
    end

    return updates_applied
end

# ==============================================================================
# QUEUE PROCESSING (AFTER CHATTER COMPLETES)
# ==============================================================================

"""
process_chatter_queue!(process_fn::Function)

GRUG: After chatter session ends, drain the input queue and run process_fn on each.
process_fn is the normal /mission processing function from Main.jl.
This ensures no user input is lost during idle chatter rounds.
"""
function process_chatter_queue!(process_fn::Function)
    queued = drain_input_queue!()
    if isempty(queued)
        return
    end

    println("[CHATTER] 📬  Processing $(length(queued)) queued input(s) from chatter period.")
    for input in queued
        try
            process_fn(input)
        catch e
            # GRUG: One bad queued input should not kill the whole drain pass.
            println("[CHATTER] !!! ERROR processing queued input '$input': $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end

# ==============================================================================
# IDLE MODE SCHEDULER (v7.1 — SHARED TIMER FOR CHATTER + PHAGY)
# ==============================================================================

"""
should_trigger_idle(last_input_time::Float64)::Bool

GRUG: Returns true if the cave has been quiet long enough to trigger an idle event.
This is the SHARED TIMER for both chatter AND phagy (v7.1).
Default threshold: 120 seconds (was 30s in v7). Jitter: ±30s (was ±5s).
Idle events fire between 90s and 150s apart. Much slower, more drawn out.

NOTE: This replaces the old should_trigger_chatter() function.
Both chatter and phagy use this same timer — the 50/50 coinflip in Main.jl
decides which one runs.
"""
function should_trigger_idle(last_input_time::Float64)::Bool
    if last_input_time <= 0.0
        throw(ChatterError(
            "!!! FATAL: should_trigger_idle got invalid last_input_time: $(last_input_time)! !!!"
        ))
    end
    elapsed = time() - last_input_time
    # GRUG: Jitter the threshold so idle events don't happen on a perfectly regular
    # schedule. ±30s band makes it feel organic, not robotic.
    jittered_threshold = IDLE_THRESHOLD_SECONDS + (rand() * 2.0 * IDLE_JITTER_SECONDS - IDLE_JITTER_SECONDS)
    return elapsed >= jittered_threshold
end

# GRUG: BACKWARD COMPAT — keep old function name as alias that delegates to new one.
# Any code still calling should_trigger_chatter() will work but use the new 120s timer.
function should_trigger_chatter(last_input_time::Float64, _idle_threshold_seconds::Float64=120.0)::Bool
    return should_trigger_idle(last_input_time)
end

end # module ChatterMode

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: CHATTER MODE LAYER (v7.1)
#
# 1. POPULATION GATE (v7.1):
# Chatter ONLY fires if the total alive non-image node population >= 1000.
# New specimens with < 1000 nodes are excluded. The engine needs a mature specimen
# before idle gossip adds value. Below 1000 nodes, topology is still user-directed
# via /grow and drop_table wiring. Chatter would destabilize immature specimens.
#
# 2. SLOW IDLE TIMER (v7.1):
# Idle threshold raised from 30s to 120s, jitter band from ±5s to ±30s.
# Both chatter and phagy share this SAME timer. One idle event fires every 90-150s.
# The 50/50 coinflip in Main.jl decides chatter vs phagy. Much slower, more drawn out.
#
# 3. SMALLER GROUPS (v7.1):
# Group size reduced from 100-800 to 50-500. If fewer than 50 eligible nodes exist
# in the snapshot, the floor is set to whatever is available (use entire population).
#
# 4. WEAK-ONLY MORPH (v7.1):
# Only receivers WEAKER than the sender can morph. Strong nodes signal but never
# change themselves. This creates directional knowledge flow: strong nodes teach,
# weak nodes learn. Prevents strong nodes from drifting away from their proven patterns.
#
# 5. ONCE-PER-DAY MORPH LIMIT (v7.1):
# Each node tracked via MORPH_COOLDOWN_MAP (node_id -> timestamp). A node that morphed
# cannot morph again until 24 hours (86400s) have passed. Prevents runaway drift where
# a weak node gets blended every chatter round and loses its original identity entirely.
#
# 6. EPHEMERAL CLONE ARCHITECTURE:
# Chatter operates exclusively on ChatterNodeClone structs - snapshots of real nodes.
# Real NODE_MAP nodes are never directly mutated during chatter. Only after session
# completion are diffs selectively applied via apply_chatter_diffs!(). This prevents
# race conditions between chatter gossip and live user input processing.
#
# 7. ANTI-COLLISION MECHANISM:
# Each clone maintains a `talked_to` Set. Before any exchange, can_chat() verifies
# the receiver hasn't been contacted this session. This prevents the same pair from
# gossiping repeatedly in one round (echo chamber prevention).
#
# 8. BIASED COPY PROBABILITY:
# When a weak receiver evaluates a strong sender's gossip packet, copy acceptance
# probability is [0.3, 0.8] biased by sender strength. Strong senders propagate
# their patterns more effectively, modeling biological reinforcement.
#
# 9. STRENGTH JITTER IN CHATTER:
# Clone strength is jittered before gossip rounds. Weaker clones receive proportionally
# more jitter, giving them occasional bursts of influence. This prevents permanent
# dominance hierarchies from calcifying across chatter sessions.
#
# 10. INPUT QUEUE SAFETY:
# CHATTER_RUNNING flag gates user input in the main loop. Any input arriving during
# a chatter session is pushed to INPUT_QUEUE and processed via process_chatter_queue!()
# after the session completes. No user input is ever dropped.
# ==============================================================================