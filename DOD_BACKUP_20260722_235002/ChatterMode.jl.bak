# ChatterMode.jl
# ==============================================================================
# IDLE / CHATTER MODE — GROUP-BASED VOTE+PATTERN STEAL (v8.0)
# ==============================================================================
#
# WHAT CHANGED FROM v7.19
# ----------------------
# Old chatter used cursor walks, random window snapshots, semantic-compat
# checks, and family-coinflip swaps. It was scattered and random.
#
# New chatter is GROUP-BASED and PAIRWISE:
#   1. Sample a few random groups from GROUP_MAP
#   2. Per group: pair strong nodes with weak nodes (2×2, non-colliding)
#   3. Each pair: weak node STEALS the strong node's pattern (straight swap)
#      AND steals the strong node's vote — but the vote gets a Markov remix
#      based on both nodes' previous action packets (not a stale copy)
#   4. Bottom-tier weak nodes still grave
#   5. Group membership IS the similarity gate — no separate Jaccard check
#
# "should also steal the votes for those patterns. thats more coherent."
# "the vote needs an automata remix slightly to not be stale. base it on
#  both nodes votes. like a markov is fine for this"
# "just select a few random groups to do this with thats the sample size"
# "just swap the pattern dont bother doing pattern blend not necessary"
#
# CORE RULES (v8.0)
# -----------------
#   1. Group-based dispatch: sample 8–16 random groups from GROUP_MAP
#      from GROUP_MAP each cycle. Groups are the natural similarity clusters.
#   2. 2×2 pairing: per group, pair strong nodes with weak nodes. Each node
#      appears in exactly one pair — no collisions, no concurrent mutation.
#   3. Pattern: straight swap from strong → weak. No blend, no remix.
#   4. Vote: stolen from strong node, then Markov-remixed using both nodes'
#      action vocabularies so the result isn't a stale copy.
#   5. Grave: bottom-tier weak nodes (below CHATTER_GRAVE_FLOOR) still grave.
#      Mid-tier weak nodes get chatter (the steal+remix). That's type 2.
#   6. 1-hour cooldown PER NODE (engine-side: chatter_cooldown_remaining()).
#   7. Disk persistence: the chatter log is written to a compressed JSON file
#      so cross-session telemetry survives reboot.
#
# WHAT CHATTER DOES NOT DO
# ------------------------
#   - It does not blend patterns (straight swap only).
#   - It does not change neighbor_ids / latch state.
#   - It does not move nodes between groups (phagy does that at idle).
#   - It does not touch crystalized attachments — those always fire regardless.
#
# IDLE SCHEDULING
# ---------------
#   should_trigger_idle / IDLE_THRESHOLD_SECONDS / IDLE_JITTER_SECONDS still
#   live here unchanged so the orchestrator in Main.jl can keep its 50/50
#   chatter-vs-phagy coinflip.
# ==============================================================================

module ChatterMode

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

using Random
using JSON

export ChatterSession, start_chatter_session!, process_chatter_queue!
export ChatterNodeClone, ChatterLog, get_chatter_status
export should_trigger_idle, is_morph_allowed, record_morph!
export should_trigger_chatter
export apply_chatter_diffs!, drain_input_queue!, enqueue_input!
export persist_chatter_log!, load_persisted_chatter_log!
export MORPH_COOLDOWN_MAP, MORPH_COOLDOWN_LOCK
export MIN_POPULATION_FOR_CHATTER, IDLE_THRESHOLD_SECONDS
export CHATTER_GROUP_SAMPLE_MIN, CHATTER_GROUP_SAMPLE_MAX
export CHATTER_LOG, CHATTER_CURSOR
export ChatterError

# BUG-011: Bridge functions to the permanent chatter mutation registry in
# engine.jl. ChatterMode is its own module and cannot directly see Main-scoped
# identifiers. These thin wrappers resolve to the parent module at call time.
function _is_chatter_mutated(node_id::String)::Bool
    return getfield(parentmodule(@__MODULE__), :is_chatter_mutated)(node_id)
end
function _mark_chatter_mutated!(node_id::String)
    getfield(parentmodule(@__MODULE__), :mark_chatter_mutated!)(node_id)
end

# ==============================================================================
# CONSTANTS (v8.0)
# ==============================================================================

# GRUG: Minimum alive non-image node population required before chatter is
# allowed to fire. New specimens (< 1000 nodes) skip chatter entirely — they
# need explicit /grow shaping before random vote swaps add value.
const MIN_POPULATION_FOR_CHATTER = 1000

# GRUG: Default idle threshold in seconds before any idle event (chatter OR
# phagy) fires. Both chatter and phagy share this timer; the 50/50 coinflip
# in Main.jl decides which one runs.
const IDLE_THRESHOLD_SECONDS = 120.0
const IDLE_JITTER_SECONDS    = 30.0

# GRUG (v8.0): How many random groups to sample each chatter cycle.
# Range: 8–16 groups. Each sampled group produces exactly ONE pair (2 nodes:
# 1 strong + 1 weak). So each cycle dispatches 8–16 unique steal+remix pairs.
# Not all groups chatter every cycle — just a random slice. Keeps chatter
# focused and avoids sweeping the entire topology each round.
const CHATTER_GROUP_SAMPLE_MIN = 8
const CHATTER_GROUP_SAMPLE_MAX = 16

# GRUG (v8.0): Strength thresholds.
# Strong nodes donate votes and patterns. Mid-tier weak nodes receive them
# (type 2 chatter — steal+remix). Bottom-tier weak nodes grave.
const CHATTER_WEAK_FLOOR    = 2.0   # node.strength <= this → weak (eligible receiver)
const CHATTER_STRONG_FLOOR  = 5.0   # node.strength >= this → strong (eligible donor)
const CHATTER_GRAVE_FLOOR   = 0.5   # node.strength <= this → grave (too weak to save)

# GRUG (v8.0): Weight jitter on the remixed vote. The borrowed action item
# gets a small shake so receivers don't all converge on identical packets.
const CHATTER_WEIGHT_JITTER_SIGMA = 0.10

# GRUG (v8.0): Markov remix constants.
# When a vote is stolen, it's remixed via a Markov bigram chain so it's not
# a stale copy of the donor's action. The remix draws from BOTH the receiver's
# and donor's action vocabularies.
const MARKOV_MAX_ATTEMPTS = 12       # collision retries before prefix-splice fallback
const WEIGHT_BLEND_RECEIVER_SHARE = 0.60  # receiver weight dominance in the blend

# GRUG (v8.0): NONJITTER override. A strong node whose vote nonetheless
# came back low-confidence is uncertain authority — jitter still applies
# even if the node has the NONJITTER tag set.
const STRONG_LOW_CONF_OVERRIDE = 0.35

# GRUG (legacy v7.19): Semantic compatibility intensity is still exercised by
# the chatter unit tests even though v8 dispatch uses group membership as the
# primary gate. Keep the cap and helper API available as a no-side-effect
# compatibility layer for tests and older callers.
const CHATTER_SEMANTIC_INTENSITY_CAP = 0.85

# GRUG (v8.0): Disk persistence path for the chatter log. Compressed JSON.
const CHATTER_LOG_PATH_DEFAULT = "chatter_log.json.gz"
const MAX_CHATTER_LOG          = 200   # in-memory ring — disk is unbounded.

# GRUG (legacy v7.1): pattern-morph cooldown. Kept for backwards compat.
const MORPH_COOLDOWN_SECONDS = 86400.0

# GRUG: Test override refs — same pattern as v7.19.
const _TEST_MIN_POPULATION = Ref{Int}(MIN_POPULATION_FOR_CHATTER)
const _TEST_WEAK_FLOOR     = Ref{Float64}(-1.0)
const _TEST_STRONG_FLOOR   = Ref{Float64}(-1.0)
const _TEST_GRAVE_FLOOR    = Ref{Float64}(-1.0)
const _TEST_GROUP_SAMPLE_MIN = Ref{Int}(CHATTER_GROUP_SAMPLE_MIN)
const _TEST_GROUP_SAMPLE_MAX = Ref{Int}(CHATTER_GROUP_SAMPLE_MAX)

function _override_test_gates!(; min_population=nothing, weak_floor=nothing,
                                  strong_floor=nothing, grave_floor=nothing,
                                  group_sample_min=nothing, group_sample_max=nothing,
                                  window_min=nothing, window_max=nothing)
    prev = (
        min_population     = _TEST_MIN_POPULATION[],
        weak_floor         = _TEST_WEAK_FLOOR[],
        strong_floor       = _TEST_STRONG_FLOOR[],
        grave_floor        = _TEST_GRAVE_FLOOR[],
        group_sample_min   = _TEST_GROUP_SAMPLE_MIN[],
        group_sample_max   = _TEST_GROUP_SAMPLE_MAX[],
        window_min         = _TEST_GROUP_SAMPLE_MIN[],
        window_max         = _TEST_GROUP_SAMPLE_MAX[],
    )
    isnothing(min_population)     || (_TEST_MIN_POPULATION[]     = Int(min_population))
    isnothing(weak_floor)         || (_TEST_WEAK_FLOOR[]         = Float64(weak_floor))
    isnothing(strong_floor)       || (_TEST_STRONG_FLOOR[]       = Float64(strong_floor))
    isnothing(grave_floor)        || (_TEST_GRAVE_FLOOR[]        = Float64(grave_floor))
    isnothing(group_sample_min)   || (_TEST_GROUP_SAMPLE_MIN[]   = Int(group_sample_min))
    isnothing(group_sample_max)   || (_TEST_GROUP_SAMPLE_MAX[]   = Int(group_sample_max))
    isnothing(window_min)         || (_TEST_GROUP_SAMPLE_MIN[]   = Int(window_min))
    isnothing(window_max)         || (_TEST_GROUP_SAMPLE_MAX[]   = Int(window_max))
    return prev
end

_effective_min_population() = _TEST_MIN_POPULATION[]
_effective_weak_floor()     = _TEST_WEAK_FLOOR[] < 0.0 ? CHATTER_WEAK_FLOOR   : _TEST_WEAK_FLOOR[]
_effective_strong_floor()   = _TEST_STRONG_FLOOR[] < 0.0 ? CHATTER_STRONG_FLOOR : _TEST_STRONG_FLOOR[]
_effective_grave_floor()    = _TEST_GRAVE_FLOOR[] < 0.0 ? CHATTER_GRAVE_FLOOR   : _TEST_GRAVE_FLOOR[]
_effective_group_sample_min() = _TEST_GROUP_SAMPLE_MIN[]
_effective_group_sample_max() = _TEST_GROUP_SAMPLE_MAX[]
_effective_group_sample()     = rand(_effective_group_sample_min():_effective_group_sample_max())

# ==============================================================================
# ERRORS — NO SILENT FAILURES
# ==============================================================================

struct ChatterError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ChatterError) =
    print(io, "ChatterError: ", e.msg)

# ==============================================================================
# LEGACY MORPH COOLDOWN MAP (v7.1) — retained for backwards compat
# ==============================================================================

const MORPH_COOLDOWN_MAP  = Dict{String, Float64}()
const MORPH_COOLDOWN_LOCK = ReentrantLock()

function is_morph_allowed(node_id::String)::Bool
    if strip(node_id) == ""
        throw(ChatterError("!!! FATAL: is_morph_allowed got empty node_id! !!!"))
    end
    return lock(MORPH_COOLDOWN_LOCK) do
        haskey(MORPH_COOLDOWN_MAP, node_id) || return true
        (time() - MORPH_COOLDOWN_MAP[node_id]) >= MORPH_COOLDOWN_SECONDS
    end
end

function record_morph!(node_id::String)
    if strip(node_id) == ""
        throw(ChatterError("!!! FATAL: record_morph! got empty node_id! !!!"))
    end
    lock(MORPH_COOLDOWN_LOCK) do
        MORPH_COOLDOWN_MAP[node_id] = time()
    end
end

# ==============================================================================
# CHATTER CLONE — carries the stolen pattern + remixed vote
# ==============================================================================

# GRUG (v8.0): A clone carries the result of one pair's steal+remix.
# proposed_pattern is the straight-swapped pattern from the strong node.
# proposed_action_packet is the Markov-remixed action packet.
# Both get written back to the weak node's live fields at apply time.
mutable struct ChatterNodeClone
    source_id::String                    # the weak node that received
    pattern::String                      # frozen snapshot (old pattern)
    action_packet::String                # frozen snapshot (old packet)
    strength::Float64                    # for diagnostics

    # GRUG (v8.0): Cargo — the stolen pattern + remixed vote
    proposed_pattern::String             # strong node's pattern (straight swap)
    proposed_action_packet::String       # Markov-remixed action packet
    accepted_swap::Bool                  # gates apply_chatter_diffs!
    donor_id::String                     # the strong node that donated
    donor_action_name::String            # the original donor action name (before remix)
end

# Constructor for a bare clone (no swap staged yet)
function ChatterNodeClone(source_id::String, pattern::String,
                          action_packet::String, strength::Float64)
    return ChatterNodeClone(source_id, pattern, action_packet, strength,
                            "", "", false, "", "")
end

# ==============================================================================
# CHATTER SESSION + LOG
# ==============================================================================

mutable struct ChatterSession
    session_id::String
    start_time::Float64
    end_time::Float64
    groups_sampled::Int              # GRUG (v8.0): how many groups were sampled
    pairs_formed::Int                # GRUG (v8.0): how many 2×2 pairs
    clones::Vector{ChatterNodeClone}
    is_running::Bool
    queued_inputs::Vector{String}
    swaps_attempted::Int
    swaps_accepted::Int
    swaps_blocked_cooldown::Int
    swaps_graved::Int                # GRUG (v8.0): bottom-tier weak nodes graved
    swaps_blocked_semantic::Int
    swaps_blocked_coinflip::Int
end

# GRUG (legacy v7.19): Older tests/readers ask for cursor/window fields that
# were replaced by group-sampling counters in v8. Expose read-only aliases.
function Base.getproperty(s::ChatterSession, name::Symbol)
    if name === :window_size
        return getfield(s, :groups_sampled)
    elseif name === :cursor_start
        return get(_LEGACY_SESSION_CURSOR_START, getfield(s, :session_id), CHATTER_CURSOR[])
    elseif name === :cursor_end
        return get(_LEGACY_SESSION_CURSOR_END, getfield(s, :session_id), CHATTER_CURSOR[])
    else
        return getfield(s, name)
    end
end

# GRUG (v8.0): Kept for cursor compat but no longer used for dispatch.
const CHATTER_CURSOR = Ref{Int}(0)
const _LEGACY_SESSION_CURSOR_START = Dict{String, Int}()
const _LEGACY_SESSION_CURSOR_END = Dict{String, Int}()

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
    groups_sampled::Int
    pairs_formed::Int
    swaps_attempted::Int
    swaps_accepted::Int
    swaps_blocked_cooldown::Int
    swaps_graved::Int
    swaps_blocked_semantic::Int
    swaps_blocked_coinflip::Int
end

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
# INPUT QUEUE — user input parked while chatter runs
# ==============================================================================

function enqueue_input!(input::String)
    if strip(input) == ""
        throw(ChatterError("!!! FATAL: enqueue_input! got empty string! !!!"))
    end
    lock(INPUT_QUEUE_LOCK) do
        push!(INPUT_QUEUE, input)
    end
    println("[CHATTER] ⏸  User input queued (chatter in progress). Queue depth: $(length(INPUT_QUEUE))")
end

function drain_input_queue!()::Vector{String}
    return lock(INPUT_QUEUE_LOCK) do
        queued = copy(INPUT_QUEUE)
        empty!(INPUT_QUEUE)
        queued
    end
end

# ==============================================================================
# IDLE TIMER — unchanged from v7.1
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
# GRUG: Same parser as v7.19 — we need structured ActionItem for the Markov
# remix. Kept in-module to avoid load-order coupling with engine.jl.

struct ActionItem
    action::String
    negatives::Vector{String}
    weight::Float64
    has_weight::Bool
end

# GRUG BUG-011: Keep pipe-delimited packets, but allow literal pipes in
# action names via {PIPE}/{{PIPE}} macro decoded after slot splitting.
_expand_action_macro_string(s::AbstractString)::String = replace(replace(String(s), "{{PIPE}}" => "|"), "{PIPE}" => "|")

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
            push!(items, ActionItem(_expand_action_macro_string(action_name), negs, weight, has_weight))
        elseif contains(p, '^')
            parts = split(p, '^'; limit=2)
            action_name = strip(parts[1])
            w = tryparse(Float64, strip(parts[2]))
            isnothing(w) && throw(ChatterError("bad weight '$(parts[2])' in '$packet'"))
            push!(items, ActionItem(_expand_action_macro_string(action_name), String[], w, true))
        else
            push!(items, ActionItem(_expand_action_macro_string(p), String[], 1.0, false))
        end
    end
    isempty(items) && throw(ChatterError("no actions in packet '$packet'"))
    return items
end

function _serialize_action_items(items::Vector{ActionItem})::String
    parts = String[]
    for it in items
        body = isempty(it.negatives) ? it.action : "$(it.action)[" * join(it.negatives, ", ") * "]"
        push!(parts, it.has_weight ? "$(body)^$(round(it.weight, digits=3))" : body)
    end
    return join(parts, " | ")
end

# GRUG (legacy v7.19): lightweight action-family compatibility for older
# chatter vote-swap tests/callers. This is intentionally local and conservative:
# it only decides whether a donor ActionItem may enter a receiver packet and
# computes a bounded text-overlap intensity. It does not mutate packets/nodes.
const _CHATTER_ACTION_FAMILIES = Dict{String,String}(
    "warn" => "ESCALATE", "alert" => "ESCALATE", "flee" => "ESCALATE",
    "danger" => "ESCALATE", "acknowledge" => "ESCALATE", "smile" => "ESCALATE",
    "ponder" => "QUERY", "query" => "QUERY", "ask" => "QUERY", "question" => "QUERY", "why" => "QUERY",
    "answer" => "ASSERT", "assert" => "ASSERT", "say" => "ASSERT", "tell" => "ASSERT",
    "observe" => "ASSERT", "validate" => "ASSERT", "greet" => "ASSERT",
)

function _chatter_action_family(action::String)::String
    toks = _tokenize_action(action)
    for t in toks
        if haskey(_CHATTER_ACTION_FAMILIES, t)
            return _CHATTER_ACTION_FAMILIES[t]
        end
    end
    low = lowercase(strip(action))
    for (needle, fam) in _CHATTER_ACTION_FAMILIES
        occursin(needle, low) && return fam
    end
    return "ASSERT"
end

function _text_overlap_intensity(a::String, b::String)::Float64
    toks_a = Set([m.match for m in eachmatch(r"[a-z0-9]+", lowercase(a))])
    toks_b = Set([m.match for m in eachmatch(r"[a-z0-9]+", lowercase(b))])
    if isempty(toks_a) && isempty(toks_b)
        return 0.0
    end
    inter = length(intersect(toks_a, toks_b))
    uni = length(union(toks_a, toks_b))
    uni == 0 && return 0.0
    return min(CHATTER_SEMANTIC_INTENSITY_CAP, inter / uni)
end

function _semantic_compat(donor::ActionItem,
                          receiver::Vector{ActionItem},
                          receiver_pattern::String,
                          donor_pattern::String)::Tuple{Bool, Float64}
    donor_action = lowercase(strip(donor.action))
    isempty(donor_action) && return (false, 0.0)

    for it in receiver
        recv_action = lowercase(strip(it.action))
        recv_action == donor_action && return (false, 0.0)
        for neg in it.negatives
            lowercase(strip(neg)) == donor_action && return (false, 0.0)
        end
    end

    donor_family = _chatter_action_family(donor.action)
    receiver_families = Set(_chatter_action_family(it.action) for it in receiver)
    (donor_family in receiver_families) || return (false, 0.0)

    intensity = _text_overlap_intensity(receiver_pattern, donor_pattern)
    return (true, intensity)
end

# ==============================================================================
# MARKOV REMIX ENGINE — vote stealing with automata remix
# ==============================================================================
# GRUG: When a vote is stolen from a strong node, it can't be a stale copy.
# The stolen vote is remixed via a Markov bigram chain that draws from BOTH
# the receiver's and donor's action vocabularies, producing a new action
# that belongs to the receiver's identity while carrying the donor's trace.

"""
    _tokenize_action(action_name::String)::Vector{String}

GRUG: Split an action name into tokens by underscores, spaces, and hyphens.
"""
function _tokenize_action(action_name::String)::Vector{String}
    tokens = String[]
    for raw in split(replace(lowercase(strip(action_name)), "-" => "_"), '_')
        t = strip(raw)
        !isempty(t) && push!(tokens, t)
    end
    return tokens
end

"""
    _build_bigram_table(token_sequences::Vector{Vector{String}})::Dict{String, Vector{String}}

GRUG: Build a bigram transition table from multiple token sequences.
"""
function _build_bigram_table(token_sequences::Vector{Vector{String}})::Dict{String, Vector{String}}
    table = Dict{String, Vector{String}}()
    for seq in token_sequences
        for i in 1:(length(seq) - 1)
            src = seq[i]
            dst = seq[i + 1]
            if !haskey(table, src)
                table[src] = String[]
            end
            push!(table[src], dst)
        end
    end
    return table
end

"""
    _walk_markov(bigram_table, start_tokens, max_len)::Vector{String}

GRUG: Walk a Markov chain starting from a random start token.
Legacy single-strand walk — kept for fallback.
"""
function _walk_markov(bigram_table::Dict{String, Vector{String}},
                      start_tokens::Vector{String},
                      max_len::Int)::Vector{String}
    isempty(start_tokens) && return String[]
    seed = rand(start_tokens)
    chain = [seed]
    for _ in 1:max_len
        current = chain[end]
        if !haskey(bigram_table, current) || isempty(bigram_table[current])
            break
        end
        push!(chain, rand(bigram_table[current]))
    end
    return chain
end

# ==============================================================================
# GRUG (v8.1): STRUCTURAL CROSSOVER MARKOV — two-strand blend
# ==============================================================================
# The old Markov dumped both vocabularies into one bigram table and walked
# blindly. The remix was accidental. The new approach builds TWO separate
# bigram tables (strand A = donor, strand B = receiver) and walks with
# deliberate crossover between them. Like genetic crossover: at each step,
# there's a chance to jump to the other strand and continue from there.
# The result is a chain that STRUCTURALLY blends the two inputs, not one
# that wanders through a merged soup.
#
# "the markov mutator for vote swaps should work by converting the original
#  node vote + the node vote you are stealing then markov remix both inputs
#  in a way where markov knows these are two structures to blend together"
# ==============================================================================

# GRUG: Crossover rate — probability of jumping to the other strand at each step.
const MARKOV_CROSSOVER_RATE = 0.35

"""
    _walk_crossover_markov(strand_a, strand_b, bigram_a, bigram_b;
                            start_in_a::Bool = true,
                            crossover_rate::Float64 = MARKOV_CROSSOVER_RATE,
                            max_len::Int = 4)::Vector{String}

GRUG: Walk a two-strand Markov chain with deliberate crossover. strand_a is
the donor (stolen vote), strand_b is the receiver (original vote). We start
in strand A (the donor — the stolen vote is the seed identity). At each step:
  1. Try to continue in the current strand (bigram transition)
  2. If crossover roll succeeds, jump to the other strand:
     - If the other strand has a token at this position, use it
     - If not (strand is shorter), try the other strand's bigram table instead
  3. If both strands are dead ends at this token, stop

The walk produces a chain that traces through BOTH structures deliberately.
Like genetic crossover — the child inherits from both parents at marked points.
"""
function _walk_crossover_markov(strand_a::Vector{String},
                                 strand_b::Vector{String},
                                 bigram_a::Dict{String, Vector{String}},
                                 bigram_b::Dict{String, Vector{String}};
                                 start_in_a::Bool = true,
                                 crossover_rate::Float64 = MARKOV_CROSSOVER_RATE,
                                 max_len::Int = 4)::Vector{String}
    isempty(strand_a) && isempty(strand_b) && return String[]

    # GRUG: Start from the first token of the starting strand.
    # Default: start in strand A (donor) — the stolen vote is the seed.
    in_a = start_in_a
    current_strand = in_a ? strand_a : strand_b
    if isempty(current_strand)
        # GRUG: Starting strand is empty, flip to the other.
        in_a = !in_a
        current_strand = in_a ? strand_a : strand_b
        isempty(current_strand) && return String[]
    end

    chain = [current_strand[1]]
    step = 1  # position index in the current strand

    for _ in 1:max_len
        current_token = chain[end]
        current_bigram = in_a ? bigram_a : bigram_b
        other_bigram = in_a ? bigram_b : bigram_a
        other_strand = in_a ? strand_b : strand_a

        # GRUG: Crossover roll — should we jump to the other strand?
        if rand() < crossover_rate && !isempty(other_strand)
            # GRUG: Cross over! Try to continue from the other strand.
            # If the other strand has a token at our current position + 1,
            # use it (positional crossover — like genetic recombination).
            next_pos = step + 1
            if next_pos <= length(other_strand)
                # GRUG: Positional crossover — take the token at this position
                # from the other strand. This is the structural blend.
                cross_token = other_strand[next_pos]
                push!(chain, cross_token)
                in_a = !in_a
                step = next_pos
                continue
            elseif haskey(other_bigram, current_token) && !isempty(other_bigram[current_token])
                # GRUG: No positional token, but the other strand's bigram
                # knows this token. Transition into the other strand.
                push!(chain, rand(other_bigram[current_token]))
                in_a = !in_a
                step += 1
                continue
            end
            # GRUG: Crossover failed — other strand has nothing at this point.
            # Fall through to same-strand continuation.
        end

        # GRUG: Continue in the current strand (no crossover, or crossover failed).
        if haskey(current_bigram, current_token) && !isempty(current_bigram[current_token])
            push!(chain, rand(current_bigram[current_token]))
            step += 1
        else
            # GRUG: Dead end in current strand. Try the other strand as rescue.
            if haskey(other_bigram, current_token) && !isempty(other_bigram[current_token])
                push!(chain, rand(other_bigram[current_token]))
                in_a = !in_a
                step += 1
            else
                break  # Both strands dead. Walk ends here.
            end
        end
    end

    return chain
end

"""
    _markov_remix_action_name(donor_action::String, receiver_actions::Vector{String};
                               max_len::Int = 4)::String

GRUG: Produce a Markov-remixed action name from the donor's action and the
receiver's existing action vocabulary. Uses structural crossover Markov: builds
TWO separate bigram tables (one per strand) and walks with deliberate crossover
between them. The donor strand is the stolen vote identity; the receiver strand
is the node's own voice. Crossover blends them structurally, not by accident.
"""
function _markov_remix_action_name(donor_action::String,
                                    receiver_actions::Vector{String};
                                    max_len::Int = 4)::String
    donor_tokens = _tokenize_action(donor_action)
    isempty(donor_tokens) && return donor_action

    # GRUG: Tokenize ALL of the receiver's actions. The receiver's full
    # action vocabulary forms strand B (the node's own voice).
    recv_token_seqs = Vector{Vector{String}}()
    for a in receiver_actions
        t = _tokenize_action(a)
        !isempty(t) && push!(recv_token_seqs, t)
    end

    # GRUG: Build TWO separate bigram tables — strand A (donor) and
    # strand B (receiver). The crossover walk knows these are two
    # distinct structures to blend, not one merged soup.
    donor_bigram = _build_bigram_table([donor_tokens])
    recv_bigram = _build_bigram_table(recv_token_seqs)

    # GRUG: The receiver's primary action (strongest) forms strand B's
    # main sequence for positional crossover. The donor is strand A.
    recv_primary = isempty(recv_token_seqs) ? String[] : recv_token_seqs[1]

    # GRUG: Walk the two-strand crossover chain.
    chain = _walk_crossover_markov(donor_tokens, recv_primary,
                                    donor_bigram, recv_bigram;
                                    start_in_a = true,
                                    max_len = max_len)

    # GRUG: If the crossover walk produced only 1 token (just the seed),
    # try starting from the receiver's strand instead. The donor strand
    # might have no transitions (single-token action name).
    if length(chain) <= 1 && !isempty(recv_primary)
        chain = _walk_crossover_markov(donor_tokens, recv_primary,
                                        donor_bigram, recv_bigram;
                                        start_in_a = false,
                                        max_len = max_len)
    end

    # GRUG: Last resort — if crossover still can't produce a multi-token
    # chain, fall back to the old single-strand walk on a combined table.
    if length(chain) <= 1
        all_seqs = vcat([donor_tokens], recv_token_seqs)
        combined_bigram = _build_bigram_table(all_seqs)
        all_starts = vcat(donor_tokens, reduce(vcat, recv_token_seqs; init=String[]))
        chain = _walk_markov(combined_bigram, all_starts, max_len)
    end

    remixed = join(chain, "_")
    isempty(remixed) && return donor_action
    return remixed
end

"""
    _prefix_splice_fallback(donor_action::String, receiver_actions::Vector{String})::String

GRUG: Fallback when all Markov walks produce collisions.
"""
function _prefix_splice_fallback(donor_action::String,
                                  receiver_actions::Vector{String})::String
    d_tokens = _tokenize_action(donor_action)
    r_tokens = isempty(receiver_actions) ? String[] :
               _tokenize_action(rand(receiver_actions))
    prefix = isempty(d_tokens) ? "remix" : d_tokens[1]
    suffix = isempty(r_tokens) ? "drift" : r_tokens[end]
    return "$(prefix)_$(suffix)"
end

"""
    _jitter_weight(weight) -> Float64

Apply a small symmetric jitter to a weight.
"""
function _jitter_weight(weight::Float64)::Float64
    j = (rand() * 2.0 - 1.0) * CHATTER_WEIGHT_JITTER_SIGMA
    return max(0.05, weight + j)
end

# ==============================================================================
# VOTE REMIX — main entry point for stolen vote processing
# ==============================================================================

"""
    _remix_vote(donor_action_name, receiver_packet, donor_packet; overlap=0.5) -> String

GRUG: Steal the donor's vote, Markov-remix it based on both nodes' action
packets, and produce a new action_packet for the receiver. The stolen vote
replaces the receiver's weakest action. Weight is blended (60% receiver / 40%
donor). Donor negatives are carried over.
"""
function _remix_vote(donor_action_name::String,
                     receiver_packet::String,
                     donor_packet::String;
                     overlap::Float64 = 0.5)::String
    recv_items = _parse_action_items(receiver_packet)
    donor_items = _parse_action_items(donor_packet)

    isempty(recv_items) && return receiver_packet

    # GRUG: Find the donor item matching the donor_action_name.
    donor_item = nothing
    for it in donor_items
        if it.action == donor_action_name
            donor_item = it
            break
        end
    end
    if isnothing(donor_item) && !isempty(donor_items)
        donor_item = donor_items[1]
    end
    if isnothing(donor_item)
        return receiver_packet
    end

    # GRUG: Build the receiver's action name list for Markov vocabulary.
    recv_action_names = [it.action for it in recv_items]

    # GRUG: Run Markov remix with collision retries.
    remixed_name = donor_action_name
    for attempt in 1:MARKOV_MAX_ATTEMPTS
        candidate = _markov_remix_action_name(donor_item.action, recv_action_names)
        if !(candidate in recv_action_names)
            remixed_name = candidate
            break
        end
        if attempt == MARKOV_MAX_ATTEMPTS
            remixed_name = _prefix_splice_fallback(donor_item.action, recv_action_names)
            if remixed_name in recv_action_names
                remixed_name = "$(remixed_name)_$(rand(100:999))"
            end
        end
    end

    # GRUG: Merge negatives from donor.
    remixed_negs = String[]
    for n in donor_item.negatives
        (!(n in remixed_negs) && n != remixed_name) && push!(remixed_negs, n)
    end

    # GRUG: Replace the receiver's lowest-weight item.
    swap_idx = argmin([it.weight for it in recv_items])
    weakest_weight = recv_items[swap_idx].weight

    # GRUG: Blend weight — receiver dominance, donor trace.
    donor_w = donor_item.has_weight ? donor_item.weight : 1.0
    blended_weight = (WEIGHT_BLEND_RECEIVER_SHARE * weakest_weight +
                      (1.0 - WEIGHT_BLEND_RECEIVER_SHARE) * donor_w)
    blended_weight += (rand() * 2.0 - 1.0) * 0.05
    blended_weight = max(0.05, blended_weight)

    remixed_item = ActionItem(remixed_name, remixed_negs,
                               round(blended_weight, digits=3), true)

    new_items = copy(recv_items)
    new_items[swap_idx] = remixed_item

    return _serialize_action_items(new_items)
end

# ==============================================================================
# CHATTER SESSION RUNNER (v8.0 — group-based 2×2 steal+remix)
# ==============================================================================

"""
    start_chatter_session!(node_map, node_lock, group_map, group_lock;
                            cooldown_query, stamp_fn) -> ChatterSession

Run one chatter cycle. v8.0 architecture:

  1. Sample 8–16 random groups from GROUP_MAP (sample size = rand(8:16))
  2. Per group: identify strong + weak members (non-grave, non-image)
  3. Pair strong+weak 2×2 — each node appears in exactly one pair
  4. For each pair:
     a. If weak node strength <= CHATTER_GRAVE_FLOOR: grave it (bottom-tier)
     b. Otherwise (mid-tier weak): steal pattern (straight swap) + steal vote
        (Markov remix based on both nodes' action packets)
  5. Return session with clones for apply step

Group membership IS the similarity gate — no separate Jaccard check needed.
"""
function start_chatter_session!(
    node_map::Dict,
    node_lock::ReentrantLock,
    group_map::Dict,
    group_lock::ReentrantLock;
    cooldown_query::Function = (id) -> 0.0,
    stamp_fn::Function = (id) -> nothing,
    grave_fn::Function = (id, reason) -> nothing,
)::ChatterSession
    lock(CHATTER_LOCK) do
        CHATTER_RUNNING[] = true
    end

    session_id = "chatter_$(round(Int, time() * 1000))"
    session_start = time()

    try
        # ── STEP 1: Sample random groups ──
        all_group_ids = lock(group_lock) do
            collect(keys(group_map))
        end

        if isempty(all_group_ids)
            println("[CHATTER] ⚠  No groups available. Skipping chatter.")
            session = ChatterSession(session_id, session_start, 0.0, 0, 0,
                                     ChatterNodeClone[], false, String[],
                                     0, 0, 0, 0, 0, 0)
            session.end_time = time()
            _store_session!(session)
            return session
        end

        sample_size = min(_effective_group_sample(), length(all_group_ids))
        shuffled = collect(all_group_ids)
        shuffle!(shuffled)
        sampled_ids = shuffled[1:sample_size]

        println("[CHATTER] 🗣  Session $session_id: sampling $sample_size group(s) from $(length(all_group_ids)) total")

        # ── STEP 2+3+4: Per group, pair strong+weak, steal+remix ──
        clones = ChatterNodeClone[]
        swaps_attempted = 0
        swaps_accepted = 0
        swaps_blocked_cooldown = 0
        swaps_graved = 0
        swaps_blocked_semantic = 0
        swaps_blocked_coinflip = 0
        pairs_formed = 0

        # GRUG BUG-011: Permanent mutation guard + session-scoped donor set.
        # A node that has EVER been chatter-mutated (receiver OR donor whose
        # vote was stolen) may NEVER participate again. The permanent registry
        # lives in engine.jl (CHATTER_MUTATED_SET). Additionally, a donor
        # can only be used once per session to avoid repeat steals.
        session_used = Set{String}()

        for gid in sampled_ids
            group = lock(group_lock) do
                get(group_map, gid, nothing)
            end
            isnothing(group) && continue

            # GRUG v7.39: NOCHAT enforcement. Groups with is_chatter_eligible=false
            # are invisible to ChatterMode. These are singleton/under-populated groups
            # that haven't yet graduated. Skipping them prevents whacky remixes.
            if hasproperty(group, :is_chatter_eligible) && !group.is_chatter_eligible
                continue
            end

            # GRUG: Categorize members into strong / weak / grave-tier
            strong_ids = String[]
            weak_ids = String[]

            lock(node_lock) do
                for mid in group.members
                    _is_chatter_mutated(mid) && continue   # BUG-011: permanently excluded
                    (mid in session_used) && continue     # BUG-011: already used this session
                    !haskey(node_map, mid) && continue
                    node = node_map[mid]
                    node.is_grave && continue
                    node.is_image_node && continue
                    # GRUG v8.26h: antimatch nodes removed. is_antimatch_node is always false for new nodes.  # node.is_antimatch_node && continue
                    # GRUG v7.59: Sigil nodes are NOCHAT — their patterns are syntactic
                    # grammars (e.g. "&n &op &n"), not semantic content. Chatter must not
                    # remix procedural votes. People don't dream in procedures. Relational
                    # triples can optionally USE sigils, making them dynamic rather than
                    # static — easy to forget when authoring specimens.
                    (isdefined(node, :node_type) && node.node_type === :sigil) && continue

                    # GRUG: Cooldown check — skip nodes still on cooldown
                    if cooldown_query(mid) > 0.0
                        continue
                    end

                    if node.strength >= _effective_strong_floor()
                        push!(strong_ids, mid)
                    elseif node.strength <= _effective_weak_floor()
                        push!(weak_ids, mid)
                    end
                end
            end

            isempty(strong_ids) && continue  # no donors in this group
            isempty(weak_ids) && continue    # no receivers in this group

            # GRUG (v8.0): Exactly ONE pair per group — 2 nodes: 1 strong + 1 weak.
            # Shuffle both lists so the pick is random each cycle, then take
            # the first of each. This is the 2×2 unique dispatch: each group
            # contributes exactly 2 random nodes to the chatter cycle.
            shuffle!(strong_ids)
            shuffle!(weak_ids)
            strong_id = strong_ids[1]
            weak_id = weak_ids[1]

            # BUG-011: double-check permanent + session guards after shuffle pick
            (_is_chatter_mutated(strong_id) || _is_chatter_mutated(weak_id) ||
             strong_id in session_used || weak_id in session_used) && continue

            swaps_attempted += 1

            # GRUG: Read both nodes under lock
            local weak_node, strong_node
            lock(node_lock) do
                weak_node = get(node_map, weak_id, nothing)
                strong_node = get(node_map, strong_id, nothing)
            end

            if isnothing(weak_node) || isnothing(strong_node)
                continue
            end

            # ── GRAVE CHECK: bottom-tier weak nodes ──
            if weak_node.strength <= _effective_grave_floor()
                # GRUG: Too weak to save. Grave it.
                try grave_fn(weak_id, "CHATTER_GRAVE") catch e
                    @warn "[CHATTER] grave_fn failed for $weak_id: $e"
                end
                swaps_graved += 1
                continue
            end

            # ── STEAL PATTERN: straight swap ──
            # GRUG: The weak node's pattern gets replaced by the strong
            # node's pattern. No blend, no remix. Just swap.
            stolen_pattern = strong_node.pattern

            # ── STEAL VOTE: Markov remix ──
            # GRUG: Pick a random action from the strong node's packet
            # to steal. Then remix it via Markov based on both nodes'
            # action packets so it's not a stale copy.
            local donor_action_name::String
            local new_packet::String

            try
                donor_items = _parse_action_items(strong_node.action_packet)
                donor_item = rand(donor_items)
                donor_action_name = donor_item.action

                new_packet = _remix_vote(donor_action_name,
                                          weak_node.action_packet,
                                          strong_node.action_packet)
            catch e
                # GRUG: Parse/remix failed — skip this pair
                println("[CHATTER] ⚠  Skip pair $weak_id ← $strong_id: $e")
                swaps_blocked_semantic += 1
                continue
            end

            # GRUG: Validate the remixed packet before staging
            try
                _parse_action_items(new_packet)
            catch e
                println("[CHATTER] ⛔  Refused remixed vote for $weak_id: $e")
                swaps_blocked_semantic += 1
                continue
            end

            # GRUG: Stage the steal on a clone — apply step writes back
            clone = ChatterNodeClone(weak_id, weak_node.pattern,
                                      weak_node.action_packet,
                                      weak_node.strength)
            clone.proposed_pattern = stolen_pattern
            clone.proposed_action_packet = new_packet
            clone.accepted_swap = true
            clone.donor_id = strong_id
            clone.donor_action_name = donor_action_name

            push!(clones, clone)
            swaps_accepted += 1
            pairs_formed += 1
            push!(session_used, weak_id)    # BUG-011: mark used this session
            push!(session_used, strong_id)  # BUG-011: mark used this session

            # GRUG: Stamp cooldown on both participants
            try stamp_fn(weak_id) catch e
                @warn "[CHATTER] stamp_fn failed for $weak_id: $e"
            end
            try stamp_fn(strong_id) catch e
                @warn "[CHATTER] stamp_fn failed for $strong_id: $e"
            end
        end

        session = ChatterSession(
            session_id, session_start, 0.0,
            length(sampled_ids), pairs_formed,
            clones, true, String[],
            swaps_attempted, swaps_accepted,
            swaps_blocked_cooldown, swaps_graved,
            swaps_blocked_semantic, swaps_blocked_coinflip
        )
        session.end_time = time()
        session.is_running = false

        println("[CHATTER] ✅  Session $session_id complete. " *
                "groups=$(length(sampled_ids)) pairs=$pairs_formed " *
                "accepted=$swaps_accepted graved=$swaps_graved " *
                "blocked(semantic=$swaps_blocked_semantic)")

        _store_session!(session)
        return session

    catch e
        if e isa ChatterError
            println("[CHATTER] ⛔  $session_id: $(e.msg)")
            rethrow(e)
        else
            println("[CHATTER] !!! FATAL: chatter session $session_id exploded: $e !!!")
            rethrow(e)
        end
    finally
        lock(CHATTER_LOCK) do
            CHATTER_RUNNING[] = false
        end
        println("[CHATTER] 🔓  Chatter lock released. Main loop can resume.")
    end
end

# GRUG (legacy v7.19): Snapshot-vector runner retained for old chatter tests.
# Snapshot rows are (id, pattern, action_packet, strength). This overload stages
# clones only; apply_chatter_diffs! still performs live writes against NODE_MAP.
function start_chatter_session!(snapshot::Vector{Tuple{String,String,String,Float64}};
                                cooldown_query::Function = (id) -> 0.0,
                                stamp_fn::Function = (id) -> nothing,
                                grave_fn::Function = (id, reason) -> nothing,
                                nonjitter_query::Function = (id) -> false,
                                confidence_query::Function = (id) -> 1.0)::ChatterSession
    session_id = "chatter_$(round(Int, time() * 1000))"
    session_start = time()
    n = length(snapshot)
    win_min = _effective_group_sample_min()
    win_max = _effective_group_sample_max()
    window_size = n == 0 ? 0 : min(rand(win_min:win_max), n)
    cursor_start = n == 0 ? 0 : CHATTER_CURSOR[]

    window = Tuple{String,String,String,Float64}[]
    if n > 0 && window_size > 0
        for k in 0:(window_size - 1)
            push!(window, snapshot[mod1(cursor_start + k + 1, n)])
        end
        CHATTER_CURSOR[] = mod(cursor_start + window_size, n)
    end
    cursor_end = CHATTER_CURSOR[]

    clones = ChatterNodeClone[]
    swaps_attempted = 0
    swaps_accepted = 0
    swaps_blocked_cooldown = 0
    swaps_graved = 0
    swaps_blocked_semantic = 0
    swaps_blocked_coinflip = 0

    strong = [row for row in window if row[4] >= _effective_strong_floor() && !_is_chatter_mutated(row[1])]
    weak = [row for row in window if row[4] <= _effective_weak_floor() && !_is_chatter_mutated(row[1])]

    # BUG-011: Session-scoped set so a donor can only be used once per session.
    # The permanent CHATTER_MUTATED_SET (checked above) handles the lifetime ban.
    session_used = Set{String}()

    for w in weak
        wid, wpat, wpacket, wstrength = w
        (wid in session_used) && continue             # BUG-011: already used this session
        if cooldown_query(wid) > 0.0
            swaps_blocked_cooldown += 1
            continue
        end
        if wstrength <= _effective_grave_floor()
            try grave_fn(wid, "CHATTER_GRAVE") catch; end
            swaps_graved += 1
            continue
        end
        isempty(strong) && continue
        # BUG-011: pick a donor not already used this session and not permanently mutated
        available_donors = [d for d in strong if !(d[1] in session_used) && !_is_chatter_mutated(d[1])]
        isempty(available_donors) && continue
        donor = rand(available_donors)
        did, dpat, dpacket, _ = donor
        cooldown_query(did) > 0.0 && continue
        swaps_attempted += 1

        try
            donor_items = _parse_action_items(dpacket)
            recv_items = _parse_action_items(wpacket)
            donor_item = rand(donor_items)
            compat, _ = _semantic_compat(donor_item, recv_items, wpat, dpat)
            if !compat
                swaps_blocked_semantic += 1
                continue
            end
            if nonjitter_query(wid) && confidence_query(did) >= STRONG_LOW_CONF_OVERRIDE
                swaps_blocked_coinflip += 1
                continue
            end
            new_packet = _remix_vote(donor_item.action, wpacket, dpacket)
            _parse_action_items(new_packet)

            clone = ChatterNodeClone(wid, wpat, wpacket, wstrength)
            clone.proposed_pattern = dpat
            clone.proposed_action_packet = new_packet
            clone.accepted_swap = true
            clone.donor_id = did
            clone.donor_action_name = donor_item.action
            push!(clones, clone)
            swaps_accepted += 1
            push!(session_used, wid)    # BUG-011: mark used this session
            push!(session_used, did)    # BUG-011: mark used this session
            try stamp_fn(wid) catch; end
            try stamp_fn(did) catch; end
        catch
            swaps_blocked_semantic += 1
            continue
        end
    end

    session = ChatterSession(session_id, session_start, time(), window_size,
                             length(clones), clones, false, String[],
                             swaps_attempted, swaps_accepted,
                             swaps_blocked_cooldown, swaps_graved,
                             swaps_blocked_semantic, swaps_blocked_coinflip)
    _LEGACY_SESSION_CURSOR_START[session_id] = cursor_start
    _LEGACY_SESSION_CURSOR_END[session_id] = cursor_end
    _store_session!(session)
    return session
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

GRUG (v8.0): For every clone with accepted_swap, write back BOTH the stolen
pattern AND the remixed action_packet to the weak node. Pattern is a straight
swap, vote is the Markov-remixed version.
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

            changed = false

            # GRUG (v8.0): Write back stolen pattern (straight swap)
            if !isempty(clone.proposed_pattern) &&
               isdefined(node, :pattern) &&
               node.pattern != clone.proposed_pattern
                node.pattern = clone.proposed_pattern
                changed = true
            end

            # GRUG (v8.0): Write back remixed action packet
            if !isempty(clone.proposed_action_packet) &&
               isdefined(node, :action_packet) &&
               node.action_packet != clone.proposed_action_packet
                # GRUG: Validate the proposed packet round-trips through
                # the parser. If not, REFUSE the swap.
                try
                    _parse_action_items(clone.proposed_action_packet)
                catch e
                    println("[CHATTER] ⛔  Refused swap for $(clone.source_id): proposed packet failed parse: $e")
                    continue
                end
                node.action_packet = clone.proposed_action_packet
                changed = true
            end

            if changed
                updates_applied += 1
                # BUG-011: Mark both receiver and donor as permanently mutated.
                # Once a node has been chatter-mutated, it can NEVER participate
                # in chatter again — not in this session, not ever.
                _mark_chatter_mutated!(clone.source_id)
                if !isempty(clone.donor_id)
                    _mark_chatter_mutated!(clone.donor_id)
                end
                try stamp_fn(clone.source_id) catch e
                    @warn "[CHATTER] stamp_fn failed for $(clone.source_id): $e"
                end
            end
        end
    end

    if updates_applied > 0
        println("[CHATTER] 📝  Applied $updates_applied steal+remix(es) from session $(session.session_id).")
    end
    return updates_applied
end

# ==============================================================================
# QUEUE PROCESSING (after chatter completes)
# ==============================================================================

function process_chatter_queue!(process_fn::Function)
    queued = drain_input_queue!()
    isempty(queued) && return
    println("[CHATTER] 📨  Processing $(length(queued)) queued input(s) from chatter period.")
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
# DISK PERSISTENCE — compressed JSON chatter log
# ==============================================================================

"""
    persist_chatter_log!(path = CHATTER_LOG_PATH_DEFAULT) -> String

Serialize the in-memory CHATTER_LOG ring to a gzip-compressed JSON file.
"""
function persist_chatter_log!(path::String=CHATTER_LOG_PATH_DEFAULT)::String
    rows = lock(CHATTER_LOG_LOCK) do
        [Dict{String, Any}(
            "session_id"             => s.session_id,
            "start_time"             => s.start_time,
            "end_time"               => s.end_time,
            "groups_sampled"         => s.groups_sampled,
            "pairs_formed"           => s.pairs_formed,
            "swaps_attempted"        => s.swaps_attempted,
            "swaps_accepted"         => s.swaps_accepted,
            "swaps_blocked_cooldown" => s.swaps_blocked_cooldown,
            "swaps_graved"           => s.swaps_graved,
            "swaps_blocked_semantic" => s.swaps_blocked_semantic,
            "swaps_blocked_coinflip" => s.swaps_blocked_coinflip,
            "swaps" => [Dict{String, Any}(
                "node_id"      => c.source_id,
                "donor_id"     => c.donor_id,
                "donor_action" => c.donor_action_name,
                "new_packet"   => c.proposed_action_packet,
                "new_pattern"  => c.proposed_pattern,
            ) for c in s.clones if c.accepted_swap],
        ) for s in CHATTER_LOG]
    end
    payload = JSON.json(Dict("version" => "v8.0", "sessions" => rows))

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

Inverse of persist_chatter_log!. Loads sessions back into CHATTER_LOG.
"""
function load_persisted_chatter_log!(path::String=CHATTER_LOG_PATH_DEFAULT)::Int
    isfile(path) || return 0
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
                Int(get(r, "groups_sampled", 0)),
                Int(get(r, "pairs_formed", 0)),
                ChatterNodeClone[],
                false,
                String[],
                Int(r["swaps_attempted"]),
                Int(r["swaps_accepted"]),
                Int(get(r, "swaps_blocked_cooldown", 0)),
                Int(get(r, "swaps_graved", 0)),
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
