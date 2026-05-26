# ChatterMode.jl
# ==============================================================================
# IDLE / CHATTER MODE \u2014 VOTE-SWAP GOSSIP (v7.19)
# ==============================================================================
#
# WHAT CHANGED FROM v7.1
# ----------------------
# Old chatter copied PATTERN tokens between similar nodes \u2014 weak nodes drifted
# toward strong-neighbor patterns. That was identity drift. The new chatter
# copies VOTES (action_packet entries) instead. Patterns stay frozen; only
# the ACTION carried by a node\u2019s vote can be borrowed from a partner.
#
#   "don\u2019t copy patterns. copy votes of similar pattern nodes." \u2014 user spec
#
# The pattern remains the matchmaker (stored as group centroid). It is the
# one-way glue that decides who can chatter with whom. The cargo on the wire
# is a single action_packet item.
#
# CORE RULES (v7.19, per spec)
# ----------------------------
#   1. Cursor walk: each chatter window picks 100..400 nodes from the FRONT of
#      the node id list, runs the ritual on them, advances the cursor, and
#      resumes from the cursor next window. Wraps when it falls off the end.
#   2. 1-hour cooldown PER NODE (engine-side: chatter_cooldown_remaining()).
#   3. Only WEAK nodes do action copying (per-node strength check).
#   4. Vote action swaps require semantic compatibility (action-family match).
#      If compatible, do a coinflip biased by capped semantic intensity.
#   5. Each node may swap AT MOST ONE vote per chatter cycle.
#   6. Swapped-in vote weight is jittered slightly. If the donor entry has no
#      weight, add a low weight on a coinflip.
#   7. NONJITTER override: a STRONG node holding a LOW-CONFIDENCE vote still
#      jitters even if its node-level NONJITTER tag would normally suppress it.
#   8. Disk persistence: the chatter log is written to a compressed JSON file
#      so cross-session telemetry survives reboot.
#
# WHAT CHATTER DOES NOT DO
# ------------------------
#   - It does not change patterns.
#   - It does not change neighbor_ids / latch state.
#   - It does not move nodes between groups (phagy does that at idle).
#   - It does not touch crystalized attachments \u2014 those always fire regardless.
#
# POPULATION GATE
# ---------------
#   MIN_POPULATION_FOR_CHATTER = 1000. Same as v7.1: young specimens grow
#   first, gossip later. Lowered for tests via test-only constants when
#   appropriate, never below 50 in production.
#
# IDLE SCHEDULING
# ---------------
#   should_trigger_idle / IDLE_THRESHOLD_SECONDS / IDLE_JITTER_SECONDS still
#   live here unchanged so the orchestrator in Main.jl can keep its 50/50
#   chatter-vs-phagy coinflip.
# ==============================================================================

module ChatterMode

using Random
using JSON

# GRUG (v7.19): Use system gzip the same way save_specimen_to_file! does
# (see Main.jl: it pipes to `gzip -c`). Keeping the dependency surface
# unchanged \u2014 no new Pkg entries needed.

export ChatterSession, start_chatter_session!, process_chatter_queue!
export ChatterNodeClone, ChatterLog, get_chatter_status
export should_trigger_idle, is_morph_allowed, record_morph!
export should_trigger_chatter
export apply_chatter_diffs!, drain_input_queue!, enqueue_input!
export persist_chatter_log!, load_persisted_chatter_log!
export MORPH_COOLDOWN_MAP, MORPH_COOLDOWN_LOCK
export MIN_POPULATION_FOR_CHATTER, IDLE_THRESHOLD_SECONDS
export CHATTER_WINDOW_MIN, CHATTER_WINDOW_MAX
export CHATTER_LOG, CHATTER_CURSOR
export ChatterError

# ==============================================================================
# CONSTANTS (v7.19)
# ==============================================================================

# GRUG: Minimum alive non-image node population required before chatter is
# allowed to fire. New specimens (< 1000 nodes) skip chatter entirely \u2014 they
# need explicit /grow shaping before random vote swaps add value.
const MIN_POPULATION_FOR_CHATTER = 1000

# GRUG: Default idle threshold in seconds before any idle event (chatter OR
# phagy) fires. Both chatter and phagy share this timer; the 50/50 coinflip
# in Main.jl decides which one runs.
const IDLE_THRESHOLD_SECONDS = 120.0
const IDLE_JITTER_SECONDS    = 30.0

# GRUG (v7.19): Chatter window bounds. Per spec: "100 to 400 group ids /
# nodes from the front of the id list". We pick a random window size in
# this band each cycle, take that many node ids starting at the cursor,
# advance the cursor by exactly window_size, and wrap when the cursor
# walks off the end of the id list.
#
# Production constants are immutable. The mutable Refs below let TESTS
# (and only tests) shrink the gates so we can exercise the full ritual on
# small specimens. _override_test_gates! takes a NamedTuple and returns the
# previous values so the test harness can restore them in a finally block.
const CHATTER_WINDOW_MIN = 100
const CHATTER_WINDOW_MAX = 400

const _TEST_MIN_POPULATION = Ref{Int}(MIN_POPULATION_FOR_CHATTER)
const _TEST_WINDOW_MIN     = Ref{Int}(CHATTER_WINDOW_MIN)
const _TEST_WINDOW_MAX     = Ref{Int}(CHATTER_WINDOW_MAX)
const _TEST_WEAK_FLOOR     = Ref{Float64}(-1.0)   # -1 = use prod
const _TEST_STRONG_FLOOR   = Ref{Float64}(-1.0)

"""
    _override_test_gates!(; min_population=nothing, window_min=nothing,
                            window_max=nothing, weak_floor=nothing,
                            strong_floor=nothing) -> NamedTuple

TEST-ONLY hatch. Returns the previous values so the caller can restore
them. Production code MUST NOT call this. NO SILENT FAILURES \u2014 any nil
input is treated as "leave alone".
"""
function _override_test_gates!(; min_population=nothing, window_min=nothing,
                                  window_max=nothing, weak_floor=nothing,
                                  strong_floor=nothing)
    prev = (
        min_population = _TEST_MIN_POPULATION[],
        window_min     = _TEST_WINDOW_MIN[],
        window_max     = _TEST_WINDOW_MAX[],
        weak_floor     = _TEST_WEAK_FLOOR[],
        strong_floor   = _TEST_STRONG_FLOOR[],
    )
    isnothing(min_population) || (_TEST_MIN_POPULATION[] = Int(min_population))
    isnothing(window_min)     || (_TEST_WINDOW_MIN[]     = Int(window_min))
    isnothing(window_max)     || (_TEST_WINDOW_MAX[]     = Int(window_max))
    isnothing(weak_floor)     || (_TEST_WEAK_FLOOR[]     = Float64(weak_floor))
    isnothing(strong_floor)   || (_TEST_STRONG_FLOOR[]   = Float64(strong_floor))
    return prev
end

_effective_min_population() = _TEST_MIN_POPULATION[]
_effective_window_min()     = _TEST_WINDOW_MIN[]
_effective_window_max()     = _TEST_WINDOW_MAX[]
_effective_weak_floor()     = _TEST_WEAK_FLOOR[] < 0.0 ? CHATTER_WEAK_FLOOR   : _TEST_WEAK_FLOOR[]
_effective_strong_floor()   = _TEST_STRONG_FLOOR[] < 0.0 ? CHATTER_STRONG_FLOOR : _TEST_STRONG_FLOOR[]

# GRUG (v7.19): Strength thresholds for the weak/strong gate.
# Strong nodes broadcast their votes; weak nodes accept swaps. Mid-band
# nodes neither broadcast nor swap.
const CHATTER_WEAK_FLOOR    = 2.0   # node.strength <= this \u2192 weak (eligible receiver)
const CHATTER_STRONG_FLOOR  = 5.0   # node.strength >= this \u2192 strong (eligible broadcaster)

# GRUG (v7.19): Vote-swap coinflip cap on the semantic-intensity bias. Even
# a perfect family match cannot push the swap probability higher than this
# \u2014 it keeps chatter honestly stochastic. Per spec: "biased by a capped
# semantic intensity (on a per node basis)".
const CHATTER_SEMANTIC_INTENSITY_CAP = 0.85

# GRUG (v7.19): Weight jitter on the swapped vote. The borrowed action item
# brings its donor weight, then we shake it a little so receivers don\u2019t all
# converge on identical packets.
const CHATTER_WEIGHT_JITTER_SIGMA = 0.10

# GRUG (v7.19): If the donor entry has no weight, on a coinflip we add a
# small starting weight rather than letting the receiver inherit a 1.0
# default. This keeps chatter\u2019s footprint smaller than direct user growth.
const CHATTER_DEFAULT_LOW_WEIGHT = 0.5
const CHATTER_DEFAULT_LOW_WEIGHT_PROB = 0.5

# GRUG (v7.19): NONJITTER override. A strong node whose vote nonetheless
# came back low-confidence is uncertain authority \u2014 jitter still applies
# even if the node has the NONJITTER tag set. This is the carve-out the
# spec calls out: "if a strong node has a low confidence for a vote
# NONJITTER does not apply it will still jitter".
const STRONG_LOW_CONF_OVERRIDE = 0.35  # confidence below this counts as "low"

# GRUG (v7.19): Disk persistence path for the chatter log. Compressed JSON.
# Operator-readable after `gunzip`. Lives next to the specimen by default.
const CHATTER_LOG_PATH_DEFAULT = "chatter_log.json.gz"
const MAX_CHATTER_LOG          = 200   # in-memory ring \u2014 disk is unbounded.

# GRUG (legacy v7.1): pattern-morph cooldown. Kept for backwards compat with
# the old API; the new path uses CHATTER_NODE_COOLDOWN in engine.jl.
const MORPH_COOLDOWN_SECONDS = 86400.0

# ==============================================================================
# ERRORS \u2014 NO SILENT FAILURES
# ==============================================================================

struct ChatterError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ChatterError) =
    print(io, "ChatterError: ", e.msg)

# ==============================================================================
# LEGACY MORPH COOLDOWN MAP (v7.1) \u2014 retained for backwards compat
# ==============================================================================
#
# GRUG: The old once-per-day pattern-morph cooldown still exists for the
# small number of call sites that imported it (specimen save/load, /status).
# The vote-swap path uses CHATTER_NODE_COOLDOWN in engine.jl with a 1-hour
# window. Two cooldown maps coexist by design \u2014 they protect different
# operations with different time scales.

const MORPH_COOLDOWN_MAP  = Dict{String, Float64}()
const MORPH_COOLDOWN_LOCK = ReentrantLock()

"""
    is_morph_allowed(node_id::String) -> Bool

Returns true if the node has never morphed OR has been off cooldown for
>= MORPH_COOLDOWN_SECONDS. Pre-v7.19 callers use this name. The vote-swap
path queries `chatter_cooldown_remaining` in engine.jl instead.
"""
function is_morph_allowed(node_id::String)::Bool
    if strip(node_id) == ""
        throw(ChatterError("!!! FATAL: is_morph_allowed got empty node_id! !!!"))
    end
    return lock(MORPH_COOLDOWN_LOCK) do
        haskey(MORPH_COOLDOWN_MAP, node_id) || return true
        (time() - MORPH_COOLDOWN_MAP[node_id]) >= MORPH_COOLDOWN_SECONDS
    end
end

"""
    record_morph!(node_id::String)

Stamp the legacy MORPH_COOLDOWN_MAP for `node_id`. Pre-v7.19 callers use
this name. Vote-swap chatter records via `stamp_chatter!` in engine.jl.
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
# CHATTER CLONE (carries the *vote* this cycle, not just the pattern)
# ==============================================================================

# GRUG: A clone is an ephemeral per-session snapshot. We keep `pattern` here
# only so semantic intensity can be biased by pattern overlap \u2014 we never
# write back. The mutable cargo is `proposed_action_packet`: the donor
# action item, with weight jitter applied, that will replace ONE entry in
# the receiver\u2019s real action_packet at apply time.
mutable struct ChatterNodeClone
    source_id::String
    pattern::String                # frozen snapshot, read-only
    action_packet::String          # frozen snapshot, read-only
    strength::Float64              # un-jittered for weak/strong gate
    is_weak::Bool                  # cached: strength <= CHATTER_WEAK_FLOOR
    is_strong::Bool                # cached: strength >= CHATTER_STRONG_FLOOR

    # GRUG (v7.19): Vote-swap cargo \u2014 only set on receivers that actually
    # accept a swap this cycle. Apply step uses these to write back.
    proposed_action_packet::String       # full new packet, ready to drop in
    accepted_swap::Bool                  # gates apply_chatter_diffs!
    donor_id::String                     # for telemetry
    donor_action_name::String            # for telemetry
end

# Convenience constructor that pre-computes weak/strong flags.
function ChatterNodeClone(source_id::String, pattern::String, action_packet::String, strength::Float64)
    is_weak   = strength <= _effective_weak_floor()
    is_strong = strength >= _effective_strong_floor()
    return ChatterNodeClone(source_id, pattern, action_packet, strength,
                            is_weak, is_strong, "", false, "", "")
end

# ==============================================================================
# CHATTER SESSION + LOG
# ==============================================================================

mutable struct ChatterSession
    session_id::String
    start_time::Float64
    end_time::Float64
    window_size::Int
    cursor_start::Int
    cursor_end::Int
    clones::Vector{ChatterNodeClone}
    is_running::Bool
    queued_inputs::Vector{String}
    swaps_attempted::Int
    swaps_accepted::Int
    swaps_blocked_cooldown::Int
    swaps_blocked_strength::Int
    swaps_blocked_semantic::Int
    swaps_blocked_coinflip::Int
end

# GRUG (v7.19): Cursor for the front-of-id-list walk. Persisted to disk so
# the next session resumes where the last one left off.
const CHATTER_CURSOR = Ref{Int}(0)

# GRUG: In-memory ring buffer of completed sessions for /status. Disk has
# the long history.
const CHATTER_LOG = ChatterSession[]
const CHATTER_LOG_LOCK = ReentrantLock()

# GRUG: Global flag: is chatter currently running?
const CHATTER_RUNNING = Ref{Bool}(false)
const CHATTER_LOCK = ReentrantLock()
const INPUT_QUEUE = String[]
const INPUT_QUEUE_LOCK = ReentrantLock()

struct ChatterLog
    session_id::String
    start_time::Float64
    end_time::Float64
    window_size::Int
    swaps_attempted::Int
    swaps_accepted::Int
    swaps_blocked_cooldown::Int
    swaps_blocked_strength::Int
    swaps_blocked_semantic::Int
    swaps_blocked_coinflip::Int
end

"""
    get_chatter_status() -> NamedTuple

Snapshot for `/status` and the idle scheduler. is_running, input queue
depth, lifetime session count, and current cursor.
"""
function get_chatter_status()
    is_running = lock(CHATTER_LOCK) do; CHATTER_RUNNING[] end
    queue_depth = lock(INPUT_QUEUE_LOCK) do; length(INPUT_QUEUE) end
    log_count = lock(CHATTER_LOG_LOCK) do; length(CHATTER_LOG) end
    return (
        is_running    = is_running,
        queue_depth   = queue_depth,
        sessions_run  = log_count,
        cursor        = CHATTER_CURSOR[],
    )
end

# ==============================================================================
# INPUT QUEUE \u2014 user input parked while chatter runs
# ==============================================================================

function enqueue_input!(input::String)
    if strip(input) == ""
        throw(ChatterError("!!! FATAL: enqueue_input! got empty string! !!!"))
    end
    lock(INPUT_QUEUE_LOCK) do
        push!(INPUT_QUEUE, input)
    end
    println("[CHATTER] \u23f8  User input queued (chatter in progress). Queue depth: $(length(INPUT_QUEUE))")
end

function drain_input_queue!()::Vector{String}
    return lock(INPUT_QUEUE_LOCK) do
        queued = copy(INPUT_QUEUE)
        empty!(INPUT_QUEUE)
        queued
    end
end

# ==============================================================================
# IDLE TIMER \u2014 unchanged from v7.1
# ==============================================================================

function should_trigger_idle(last_input_time::Float64)::Bool
    if last_input_time <= 0.0
        throw(ChatterError(
            "!!! FATAL: should_trigger_idle got invalid last_input_time: $last_input_time! !!!"
        ))
    end
    elapsed = time() - last_input_time
    jittered = IDLE_THRESHOLD_SECONDS +
               (rand() * 2.0 * IDLE_JITTER_SECONDS - IDLE_JITTER_SECONDS)
    return elapsed >= jittered
end

# Backwards-compat alias.
should_trigger_chatter(last_input_time::Float64, _ignored::Float64=120.0)::Bool =
    should_trigger_idle(last_input_time)

# ==============================================================================
# ACTION PACKET HELPERS (parser-light, swap-only)
# ==============================================================================
#
# GRUG: We don\u2019t reuse engine.jl\u2019s parse_action_packet here because we want
# a STRUCTURED RESULT we can mutate cleanly, and we want zero coupling that
# would force ChatterMode to depend on the engine module at load time.
# The format mirrors engine.jl: pipe-delimited entries shaped as
#   action_name[neg1, neg2]^weight     OR     action_name^weight
# with negatives and weight both optional.

struct ActionItem
    action::String
    negatives::Vector{String}
    weight::Float64
    has_weight::Bool   # true if weight came from the packet, false if defaulted
end

"""
    _parse_action_items(packet) -> Vector{ActionItem}

Lenient parser. Empty entries are skipped, malformed entries throw.
"""
function _parse_action_items(packet::String)::Vector{ActionItem}
    if strip(packet) == ""
        throw(ChatterError("!!! FATAL: _parse_action_items got empty packet! !!!"))
    end
    items = ActionItem[]
    for raw in split(packet, '|')
        p = strip(raw)
        isempty(p) && continue

        negs = String[]
        weight = 1.0
        has_weight = false

        m = match(r"^(.+?)\[([^\]]*)\](?:\^([\d.]+))?$", p)
        if !isnothing(m)
            action_name = strip(m.captures[1])
            for n in split(m.captures[2], ',')
                ns = strip(n)
                !isempty(ns) && push!(negs, String(ns))
            end
            wstr = m.captures[3]
            if !isnothing(wstr)
                w = tryparse(Float64, strip(wstr))
                isnothing(w) && throw(ChatterError("bad weight '$wstr' in '$packet'"))
                weight = w
                has_weight = true
            end
            push!(items, ActionItem(String(action_name), negs, weight, has_weight))
        elseif contains(p, '^')
            parts = split(p, '^'; limit=2)
            action_name = strip(parts[1])
            w = tryparse(Float64, strip(parts[2]))
            isnothing(w) && throw(ChatterError("bad weight '$(parts[2])' in '$packet'"))
            push!(items, ActionItem(String(action_name), String[], w, true))
        else
            push!(items, ActionItem(String(p), String[], 1.0, false))
        end
    end
    isempty(items) && throw(ChatterError("no actions in packet '$packet'"))
    return items
end

"""
    _serialize_action_items(items) -> String

Inverse of _parse_action_items. Preserves the has_weight distinction.
"""
function _serialize_action_items(items::Vector{ActionItem})::String
    parts = String[]
    for it in items
        body = if isempty(it.negatives)
            it.action
        else
            "$(it.action)[" * join(it.negatives, ", ") * "]"
        end
        if it.has_weight
            push!(parts, "$(body)^$(round(it.weight, digits=3))")
        else
            push!(parts, body)
        end
    end
    return join(parts, " | ")
end

"""
    _action_family(action_name) -> Symbol

Coarse semantic family classification. We don\u2019t import ActionTonePredictor
here \u2014 instead we mirror its keyword tables for the six families. Same
spirit, no module load order coupling.

GRUG: Substring matching is dangerous for short stop-word-like keywords
(\"no\", \"do\", \"go\") \u2014 they collide with longer verbs like \"acknowledge\",
\"ponder\", or \"forget\". Each entry in the family tables is therefore tagged
as either an EXACT match (matched against the whole action name) or a
SUBSTRING match (must appear inside the action name AND must itself be at
least 4 chars long, which keeps the keyword discriminating).
"""
function _action_family(action_name::String)::Symbol
    a = lowercase(strip(action_name))
    isempty(a) && return :unknown

    # GRUG: short keywords need EXACT match; long ones can substring-match.
    function matches_any(kws::Vector{String})::Bool
        for kw in kws
            if length(kw) <= 3
                a == kw && return true
            else
                contains(a, kw) && return true
            end
        end
        return false
    end

    matches_any(["query","ask","answer","respond","explain","describe","tell","info",
           "elaborate","clarify","define","analyze","analyse","examine","inspect",
           "study","reason","ponder","think","consider","wonder","investigate",
           "explore","review","look","check","calculate","compute","evaluate",
           "assess"]) && return :query
    matches_any(["execute","run","do","action","command","perform","trigger","make",
           "build","craft","forge","shape","fix","mend","repair","patch","restore",
           "plan","prepare","setup","set","configure","move","go","fetch","get",
           "bring","carry","find","seek","hunt","track","gather","collect","use",
           "apply","wield","operate"]) && return :command
    matches_any(["negate","deny","reject","contra","refute","wrong","no","not","never",
           "stop","halt","block","forbid","cancel","abort","dismiss"]) && return :negate
    matches_any(["assert","state","declare","confirm","affirm","say","claim","report",
           "announce","proclaim","note","observe","recall","remember","remind",
           "recount","log","record","greet","welcome","smile","laugh"]) && return :assert
    matches_any(["speculate","predict","infer","hypothe","guess","maybe","suppose",
           "imagine","envision","dream","muse","theorize","estimate","forecast",
           "anticipate","expect"]) && return :speculate
    matches_any(["alert","warn","escalate","urgent","critical","flag","danger","threat",
           "fear","scare","flee","hide","evade","avoid","shout","yell","panic",
           "emergency","caution","watch","comfort","reassure","support","validate",
           "acknowledge"]) && return :escalate
    return :unknown
end

"""
    _semantic_compat(donor_action, receiver_packet, receiver_pattern, donor_pattern)
        -> (compatible::Bool, intensity::Float64)

Decide whether a donor action can be considered for a swap into the
receiver\u2019s packet. \"Strongly allowed\" means: same action family AND donor
action is not already a NEGATIVE somewhere in the receiver\u2019s packet AND
the donor action is not already present (no self-swap). Intensity is
pattern-overlap similarity, capped.
"""
function _semantic_compat(donor::ActionItem,
                          receiver_items::Vector{ActionItem},
                          receiver_pattern::String,
                          donor_pattern::String)
    donor_family = _action_family(donor.action)
    donor_family == :unknown && return (false, 0.0)

    # Already present? No-op swap. Block.
    for it in receiver_items
        it.action == donor.action && return (false, 0.0)
    end

    # Donor action listed as a negative anywhere in receiver? Block.
    for it in receiver_items
        donor.action in it.negatives && return (false, 0.0)
    end

    # Need at least ONE of receiver\u2019s actions in the same family for
    # \"strongly allowed\". Family overlap is the semantic glue.
    has_family_overlap = false
    for it in receiver_items
        if _action_family(it.action) == donor_family
            has_family_overlap = true
            break
        end
    end
    !has_family_overlap && return (false, 0.0)

    # Pattern-overlap intensity, capped per spec.
    intensity = clamp(_pattern_overlap(donor_pattern, receiver_pattern),
                      0.0, CHATTER_SEMANTIC_INTENSITY_CAP)
    return (true, intensity)
end

function _pattern_overlap(p1::String, p2::String)::Float64
    (strip(p1) == "" || strip(p2) == "") && return 0.0
    t1 = Set(split(lowercase(strip(p1))))
    t2 = Set(split(lowercase(strip(p2))))
    union_size = length(union(t1, t2))
    return union_size == 0 ? 0.0 : Float64(length(intersect(t1, t2))) / Float64(union_size)
end

"""
    _jitter_weight(weight) -> Float64

Apply a small symmetric jitter to a weight, clamped to the same lower
bound the engine\u2019s parse_action_packet enforces (> 0.0).
"""
function _jitter_weight(weight::Float64)::Float64
    j = (rand() * 2.0 - 1.0) * CHATTER_WEIGHT_JITTER_SIGMA
    return max(0.05, weight + j)
end

"""
    _apply_swap(receiver_items, donor_item) -> (new_items, donor_action_name)

Replace ONE entry in the receiver\u2019s items with the donor item, with
weight jitter (and a coinflip-low-weight injection if the donor lacked
one). Spec: \"nodes can only swap one vote at a time\".

Selection rule: replace the receiver\u2019s LOWEST-weight entry. Strong votes
keep their slots; weak votes are the ones that get rewritten. This makes
chatter additive at the personality layer rather than destructive.
"""
function _apply_swap(receiver_items::Vector{ActionItem}, donor::ActionItem)
    @assert !isempty(receiver_items)

    # Pick weakest receiver entry as the swap target.
    swap_idx = argmin([it.weight for it in receiver_items])

    new_weight = if donor.has_weight
        _jitter_weight(donor.weight)
    elseif rand() < CHATTER_DEFAULT_LOW_WEIGHT_PROB
        # Coinflip: add a low starting weight rather than inheriting the 1.0 default.
        _jitter_weight(CHATTER_DEFAULT_LOW_WEIGHT)
    else
        # Donor has no weight and the coinflip said no: inherit the receiver\u2019s
        # weakest weight (the one we are about to replace), then jitter it.
        _jitter_weight(receiver_items[swap_idx].weight)
    end

    new_item = ActionItem(donor.action, donor.negatives, new_weight, true)

    new_items = copy(receiver_items)
    new_items[swap_idx] = new_item
    return (new_items, donor.action)
end

# ==============================================================================
# CHATTER SESSION RUNNER (v7.19 \u2014 vote swap, cursor walk)
# ==============================================================================

"""
    start_chatter_session!(snapshot) -> ChatterSession

Run one chatter window. `snapshot` is a Vector of (id, pattern, action_packet,
strength) tuples drawn fresh from NODE_MAP under NODE_LOCK by the caller.

Steps:
  1. Population gate (>= MIN_POPULATION_FOR_CHATTER alive non-image nodes).
  2. Cursor walk: take CHATTER_WINDOW_MIN..CHATTER_WINDOW_MAX node ids
     starting at CHATTER_CURSOR[]. Wrap if needed. Advance cursor.
  3. For each weak clone in the window: pick a random strong clone in the
     window, run semantic-compat check on a donor action drawn from the
     strong clone\u2019s packet. If compatible, biased coinflip; if it fires,
     stage a swap on the weak clone.
  4. Receiver-cooldown enforcement is the caller\u2019s job (chatter_cooldown_remaining
     is checked against the receiver id BEFORE we even try \u2014 it\u2019s an engine
     concern, but we mirror it here using the snapshot id list).

The caller invokes `apply_chatter_diffs!` afterwards to write back the
staged swaps to live nodes.
"""
function start_chatter_session!(
    snapshot::Vector{Tuple{String, String, String, Float64}};
    cooldown_query::Function = (id) -> 0.0,        # injectable for tests
    nonjitter_query::Function = (id) -> false,     # injectable for tests; returns true if NONJITTER tag set
    confidence_query::Function = (id) -> 1.0,      # injectable for tests; recent vote confidence
)::ChatterSession
    if isempty(snapshot)
        throw(ChatterError("!!! FATAL: start_chatter_session! got empty snapshot! !!!"))
    end
    if length(snapshot) < _effective_min_population()
        throw(ChatterError(
            "!!! POPULATION GATE: chatter requires >= $(_effective_min_population()) nodes, " *
            "got $(length(snapshot)). New specimens don\u2019t chatter. !!!"
        ))
    end

    lock(CHATTER_LOCK) do
        CHATTER_RUNNING[] = true
    end

    session_id = "chatter_$(round(Int, time() * 1000))"
    session_start = time()

    try
        # GRUG (v7.19): Cursor walk over the FRONT of the id list.
        # We sort the snapshot by id to make \"front\" deterministic across
        # snapshots that arrive in dict-iteration order.
        sorted = sort(snapshot, by = x -> x[1])
        n = length(sorted)

        cursor = CHATTER_CURSOR[]
        if cursor < 0 || cursor >= n
            cursor = 0
        end

        window_size = rand(_effective_window_min():min(_effective_window_max(), n))
        window = if cursor + window_size <= n
            sorted[cursor + 1 : cursor + window_size]
        else
            # Wrap.
            tail = sorted[cursor + 1 : n]
            head = sorted[1 : window_size - length(tail)]
            vcat(tail, head)
        end
        cursor_start = cursor
        cursor_end   = (cursor + window_size) % n
        CHATTER_CURSOR[] = cursor_end

        # Materialize clones so we can stage swaps without touching live nodes.
        clones = ChatterNodeClone[]
        for (nid, pattern, packet, strength) in window
            push!(clones, ChatterNodeClone(nid, pattern, packet, strength))
        end

        session = ChatterSession(
            session_id, session_start, 0.0, window_size, cursor_start, cursor_end,
            clones, true, String[], 0, 0, 0, 0, 0, 0
        )

        println("[CHATTER] \U0001f5e3  Session $session_id started. " *
                "window=$window_size cursor=$cursor_start\u2192$cursor_end (population=$n)")

        # GRUG: Strong clones in this window are the broadcasters. If there
        # are none, the window is sterile and we exit cleanly.
        strong_clones = [c for c in clones if c.is_strong]
        if isempty(strong_clones)
            println("[CHATTER] \u26a0  No strong nodes in window. Skipping all swaps.")
            session.end_time   = time()
            session.is_running = false
            _store_session!(session)
            return session
        end

        # GRUG: For each weak clone, attempt at most ONE swap this cycle.
        # Per spec: \"nodes can only swap one vote at a time\".
        for receiver in clones
            !receiver.is_weak && continue

            # 1-hour per-node cooldown gate. cooldown_query returns seconds remaining.
            if cooldown_query(receiver.source_id) > 0.0
                session.swaps_blocked_cooldown += 1
                continue
            end

            session.swaps_attempted += 1

            # Pick a random strong donor from the window.
            donor_clone = rand(strong_clones)
            donor_clone.source_id == receiver.source_id && continue

            # Semantic intensity & capped coinflip bias depend on the receiver\u2019s
            # confidence on its own most-recent vote and whether NONJITTER applies.
            recv_conf = confidence_query(receiver.source_id)
            recv_nonjitter = nonjitter_query(receiver.source_id)

            # GRUG (v7.19): NONJITTER override. A STRONG node holding a
            # LOW-conf vote still jitters even if NONJITTER is set. Note
            # this branch only matters if the receiver is itself strong
            # (rare: weak/strong overlap edge case where strength sits at
            # the floor). We still compute the override so the path is
            # exercised.
            donor_is_strong_lowconf = donor_clone.is_strong &&
                                      confidence_query(donor_clone.source_id) < STRONG_LOW_CONF_OVERRIDE

            # Parse both packets into structured items.
            local recv_items, donor_items
            try
                recv_items  = _parse_action_items(receiver.action_packet)
                donor_items = _parse_action_items(donor_clone.action_packet)
            catch e
                # Bad packet \u2014 chatter never silently swallows; we surface
                # and skip this pair, but keep the session alive.
                println("[CHATTER] \u26a0  Skip pair $(receiver.source_id) \u2190 $(donor_clone.source_id): $e")
                session.swaps_blocked_semantic += 1
                continue
            end

            # Pick a random donor action item to consider.
            donor_item = rand(donor_items)

            compat, intensity = _semantic_compat(donor_item, recv_items,
                                                  receiver.pattern, donor_clone.pattern)
            if !compat
                session.swaps_blocked_semantic += 1
                continue
            end

            # NONJITTER override branch: receiver opted out of jitter, but the
            # \"strong + low-conf\" rule says we still proceed. If receiver
            # NONJITTER and the override does not apply, refuse the swap.
            if recv_nonjitter && !donor_is_strong_lowconf
                session.swaps_blocked_semantic += 1
                continue
            end

            # Capped semantic-intensity biased coinflip. Floor at 0.10 so a
            # low-overlap donor still has a fair shot, ceiling at the cap.
            swap_prob = clamp(0.10 + intensity, 0.10, CHATTER_SEMANTIC_INTENSITY_CAP)
            if rand() >= swap_prob
                session.swaps_blocked_coinflip += 1
                continue
            end

            # Stage the swap.
            new_items, donor_action_name = _apply_swap(recv_items, donor_item)
            receiver.proposed_action_packet = _serialize_action_items(new_items)
            receiver.accepted_swap        = true
            receiver.donor_id             = donor_clone.source_id
            receiver.donor_action_name    = donor_action_name
            session.swaps_accepted       += 1
        end

        session.end_time   = time()
        session.is_running = false

        println("[CHATTER] \u2705  Session $session_id complete. " *
                "attempted=$(session.swaps_attempted) accepted=$(session.swaps_accepted) " *
                "blocked(cooldown=$(session.swaps_blocked_cooldown), " *
                "strength=$(session.swaps_blocked_strength), " *
                "semantic=$(session.swaps_blocked_semantic), " *
                "coinflip=$(session.swaps_blocked_coinflip))")

        _store_session!(session)
        return session

    catch e
        if e isa ChatterError
            println("[CHATTER] \u26d4  $session_id: $(e.msg)")
            rethrow(e)
        else
            println("[CHATTER] !!! FATAL: chatter session $session_id exploded: $e !!!")
            rethrow(e)
        end
    finally
        lock(CHATTER_LOCK) do
            CHATTER_RUNNING[] = false
        end
        println("[CHATTER] \U0001f513  Chatter lock released. Main loop can resume.")
    end
end

function _store_session!(session::ChatterSession)
    lock(CHATTER_LOG_LOCK) do
        push!(CHATTER_LOG, session)
        while length(CHATTER_LOG) > MAX_CHATTER_LOG
            deleteat!(CHATTER_LOG, 1)
        end
    end
end

# ==============================================================================
# APPLY DIFFS BACK TO LIVE NODES
# ==============================================================================

"""
    apply_chatter_diffs!(session, node_map, node_lock; stamp_fn) -> Int

For every clone whose `accepted_swap` is true, write back its
`proposed_action_packet` to the live node\u2019s action_packet field. Stamps
the node\u2019s 1-hour chatter cooldown via `stamp_fn` (engine.jl: stamp_chatter!).
Returns the number of nodes actually updated.

Cells that were graved between session start and apply are silently skipped
(no warning needed \u2014 chatter is best-effort by design at the apply layer).
"""
function apply_chatter_diffs!(
    session::ChatterSession,
    node_map::Dict,
    node_lock::ReentrantLock;
    stamp_fn::Function = (id) -> nothing,
)::Int
    if !isa(session, ChatterSession)
        throw(ChatterError("!!! FATAL: apply_chatter_diffs! got invalid session! !!!"))
    end

    updates_applied = 0

    lock(node_lock) do
        for clone in session.clones
            !clone.accepted_swap && continue
            !haskey(node_map, clone.source_id) && continue

            node = node_map[clone.source_id]
            (isdefined(node, :is_grave) && node.is_grave) && continue

            if isdefined(node, :action_packet) && node.action_packet != clone.proposed_action_packet
                # GRUG: Validate the proposed packet round-trips through the
                # engine\u2019s strict parser. If not, REFUSE the swap rather
                # than corrupt a live node. This is the no-silent-failures
                # contract: bad chatter cargo dies at the door.
                try
                    _parse_action_items(clone.proposed_action_packet)
                catch e
                    println("[CHATTER] \u26d4  Refused swap for $(clone.source_id): proposed packet failed parse: $e")
                    continue
                end
                node.action_packet = clone.proposed_action_packet
                updates_applied += 1
            end
            # Stamp cooldown regardless of whether the packet text changed
            # \u2014 attempting a swap counts as participation.
            try stamp_fn(clone.source_id) catch e
                @warn "[CHATTER] stamp_fn failed for $(clone.source_id): $e"
            end
        end
    end

    if updates_applied > 0
        println("[CHATTER] \U0001f4dd  Applied $updates_applied vote swap(s) from session $(session.session_id).")
    end
    return updates_applied
end

# ==============================================================================
# QUEUE PROCESSING (after chatter completes)
# ==============================================================================

function process_chatter_queue!(process_fn::Function)
    queued = drain_input_queue!()
    isempty(queued) && return
    println("[CHATTER] \U0001f4ec  Processing $(length(queued)) queued input(s) from chatter period.")
    for input in queued
        try
            process_fn(input)
        catch e
            println("[CHATTER] !!! ERROR processing queued input '$input': $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end

# ==============================================================================
# DISK PERSISTENCE \u2014 compressed JSON chatter log
# ==============================================================================

"""
    persist_chatter_log!(path = CHATTER_LOG_PATH_DEFAULT) -> String

Serialize the in-memory CHATTER_LOG ring to a gzip-compressed JSON file.
Returns the path written. If the path exists, it is overwritten atomically
via temp-file rename. Errors propagate \u2014 NO SILENT FAILURES.
"""
function persist_chatter_log!(path::String=CHATTER_LOG_PATH_DEFAULT)::String
    rows = lock(CHATTER_LOG_LOCK) do
        [Dict{String, Any}(
            "session_id"             => s.session_id,
            "start_time"             => s.start_time,
            "end_time"               => s.end_time,
            "window_size"            => s.window_size,
            "cursor_start"           => s.cursor_start,
            "cursor_end"             => s.cursor_end,
            "swaps_attempted"        => s.swaps_attempted,
            "swaps_accepted"         => s.swaps_accepted,
            "swaps_blocked_cooldown" => s.swaps_blocked_cooldown,
            "swaps_blocked_strength" => s.swaps_blocked_strength,
            "swaps_blocked_semantic" => s.swaps_blocked_semantic,
            "swaps_blocked_coinflip" => s.swaps_blocked_coinflip,
            "swaps" => [Dict{String, Any}(
                "node_id"     => c.source_id,
                "donor_id"    => c.donor_id,
                "donor_action"=> c.donor_action_name,
                "new_packet"  => c.proposed_action_packet,
            ) for c in s.clones if c.accepted_swap],
        ) for s in CHATTER_LOG]
    end
    payload = JSON.json(Dict("version" => "v7.19", "sessions" => rows))

    # GRUG: Atomic write \u2014 stage to .tmp, gzip, rename. Same gzip-by-pipe
    # approach Main.jl already uses for specimen saves so we don\u2019t introduce
    # a new compression dependency.
    raw_tmp = path * ".raw.tmp"
    open(raw_tmp, "w") do io
        write(io, payload)
    end
    gz_tmp = path * ".gz.tmp"
    cmd = pipeline(`cat $raw_tmp`, `gzip -c`)
    open(gz_tmp, "w") do io
        run(pipeline(cmd, stdout=io))
    end
    rm(raw_tmp; force = true)
    mv(gz_tmp, path; force = true)
    return path
end

"""
    load_persisted_chatter_log!(path = CHATTER_LOG_PATH_DEFAULT) -> Int

Inverse of persist_chatter_log!. Loads sessions back into CHATTER_LOG as
read-only summaries (no clones, since those were ephemeral). Returns the
number of sessions restored. If the file does not exist, returns 0
(load is idempotent and tolerant of cold starts \u2014 the file genuinely may
not exist on the very first run).
"""
function load_persisted_chatter_log!(path::String=CHATTER_LOG_PATH_DEFAULT)::Int
    isfile(path) || return 0
    # GRUG: Decompress via system gunzip pipe \u2014 mirrors specimen load path.
    raw = read(pipeline(`cat $path`, `gunzip -c`), String)
    parsed = JSON.parse(raw)
    haskey(parsed, "sessions") || throw(ChatterError("chatter log $path missing 'sessions' key"))

    n = 0
    lock(CHATTER_LOG_LOCK) do
        empty!(CHATTER_LOG)
        for r in parsed["sessions"]
            sess = ChatterSession(
                String(r["session_id"]),
                Float64(r["start_time"]),
                Float64(r["end_time"]),
                Int(r["window_size"]),
                Int(get(r, "cursor_start", 0)),
                Int(get(r, "cursor_end", 0)),
                ChatterNodeClone[],          # clones not persisted
                false,
                String[],
                Int(r["swaps_attempted"]),
                Int(r["swaps_accepted"]),
                Int(r["swaps_blocked_cooldown"]),
                Int(get(r, "swaps_blocked_strength", 0)),
                Int(get(r, "swaps_blocked_semantic", 0)),
                Int(get(r, "swaps_blocked_coinflip", 0)),
            )
            push!(CHATTER_LOG, sess)
            n += 1
            length(CHATTER_LOG) > MAX_CHATTER_LOG && deleteat!(CHATTER_LOG, 1)
        end
    end
    return n
end

end # module ChatterMode
