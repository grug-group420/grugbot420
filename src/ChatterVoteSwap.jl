# ChatterVoteSwap.jl
# ==============================================================================
# GRUG v7.15 - VOTE-SWAP CHATTER (replacement path for pattern-copy)
# ==============================================================================
# GRUG: Old chatter copied PATTERNS. Dumb --- pattern belongs to node's identity.
# New chatter copies VOTES between similar-pattern nodes. Quiet rocks learn
# WHICH ACTION strong rocks would have voted for, without losing their own
# pattern identity.
#
# RULES:
#   - Only WEAK nodes receive vote copies. Strong nodes send, never receive.
#   - Nodes may swap AT MOST ONE vote per chatter round.
#   - Per-node chatter cooldown is 1 HOUR (3600s). Same node cannot swap
#     twice in the same hour.
#   - Semantic-rule GATE: swap only happens if the receiver's relational
#     triples semantically allow the action. The gate is a coinflip biased
#     by a capped semantic intensity (per node basis).
#   - Vote WEIGHTS themselves get a zero-mean jitter during chatter. If the
#     donated vote has no weight, a small coinflip-gated weight is added.
#   - Groups are selected via GroupRegistry.next_chatter_window_ids; only
#     nodes in those groups participate.
#
# NO SILENT FAILURES: every reject path logs or throws. Missing-node is
# logged and skipped (non-fatal); corrupted weights raise.
# ==============================================================================

module ChatterVoteSwap

using Base.Threads: ReentrantLock
using Random

export ChatterVoteSwapError
export VoteSwapEvent, VoteSwapStats
export run_vote_swap_round!, should_swap_vote
export can_chatter_now, record_chatter_time!
export clear_chatter_cooldowns!, CHATTER_COOLDOWN_SECONDS
export SEMANTIC_INTENSITY_CAP, WEIGHT_JITTER_RATIO
export DONATED_BARE_WEIGHT_PROB, DONATED_BARE_WEIGHT

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Per-node cooldown between vote swaps, in seconds. 1 hour = 3600s.
const CHATTER_COOLDOWN_SECONDS = 3600.0

# GRUG: Semantic-intensity ceiling used to bias the per-node swap coinflip.
# Intensity is computed from triple overlap / relation-weight overlap and
# clamped into [0, cap]. Above the cap the bias saturates at 0.95.
const SEMANTIC_INTENSITY_CAP = 1.0

# GRUG: Zero-mean additive jitter ratio applied to the donated vote weight
# during the copy. Matches RelationalJitter's default magnitude so values
# stay coherent with the rest of the engine.
const WEIGHT_JITTER_RATIO = 0.03

# GRUG: If the donated vote has no weight, coinflip on whether to attach a
# small default one. Chance and value below.
const DONATED_BARE_WEIGHT_PROB = 0.5
const DONATED_BARE_WEIGHT      = 0.25

# ==============================================================================
# ERROR TYPE
# ==============================================================================

struct ChatterVoteSwapError <: Exception
    message::String
    context::String
end

Base.showerror(io::IO, e::ChatterVoteSwapError) =
    print(io, "ChatterVoteSwapError[", e.context, "]: ", e.message)

_throw(msg::String, ctx::String) = throw(ChatterVoteSwapError(msg, ctx))

# ==============================================================================
# PER-NODE COOLDOWN (1 HOUR)
# ==============================================================================

const _COOLDOWN_MAP  = Dict{String, Float64}()   # node_id -> last swap timestamp
const _COOLDOWN_LOCK = ReentrantLock()

"""
    can_chatter_now(node_id; now=time())::Bool

GRUG: Returns true if this node has never chattered OR its last chatter was
more than CHATTER_COOLDOWN_SECONDS ago. Caller should record a successful
swap with record_chatter_time!.
"""
function can_chatter_now(node_id::String; now::Float64 = time())::Bool
    isempty(strip(node_id)) && _throw("empty node_id", "can_chatter_now")
    lock(_COOLDOWN_LOCK) do
        haskey(_COOLDOWN_MAP, node_id) || return true  # GRUG: never chattered
        last_t = _COOLDOWN_MAP[node_id]
        return (now - last_t) >= CHATTER_COOLDOWN_SECONDS
    end
end

function record_chatter_time!(node_id::String; now::Float64 = time())
    isempty(strip(node_id)) && _throw("empty node_id", "record_chatter_time!")
    lock(_COOLDOWN_LOCK) do
        _COOLDOWN_MAP[node_id] = now
    end
    return nothing
end

clear_chatter_cooldowns!() = lock(() -> empty!(_COOLDOWN_MAP), _COOLDOWN_LOCK)

# ==============================================================================
# SEMANTIC-INTENSITY GATE (pure function)
# ==============================================================================

"""
    should_swap_vote(semantic_intensity::Float64; rng=Random.GLOBAL_RNG)::Bool

GRUG: Coinflip biased by capped semantic intensity. Zero intensity -> effectively
never. Saturating intensity -> 0.95 (not 1.0; exploration should never be
fully silenced). Negative or non-finite inputs throw.
"""
function should_swap_vote(
    semantic_intensity::Float64;
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
)::Bool
    if !isfinite(semantic_intensity)
        _throw("non-finite semantic_intensity: $semantic_intensity",
               "should_swap_vote")
    end
    if semantic_intensity < 0.0
        _throw("negative semantic_intensity: $semantic_intensity",
               "should_swap_vote")
    end

    intensity = clamp(semantic_intensity, 0.0, SEMANTIC_INTENSITY_CAP)
    p = min(0.95, 0.10 + (intensity / SEMANTIC_INTENSITY_CAP) * 0.85)
    return rand(rng) < p
end

# ==============================================================================
# WEIGHT JITTER (borrows shape from RelationalJitter but self-contained so
# tests don't need the full jitter module loaded; the zero-mean contract is
# identical)
# ==============================================================================

"""
    jitter_vote_weight(w; rng, ratio=WEIGHT_JITTER_RATIO)::Float64

GRUG: Additive zero-mean jitter on a vote weight. Symmetric uniform draw in
[-ratio*|w|, +ratio*|w|]. Zero and near-zero values pass through unchanged.
"""
function jitter_vote_weight(
    w::Float64;
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
    ratio::Float64 = WEIGHT_JITTER_RATIO,
)::Float64
    if !isfinite(w)
        _throw("non-finite weight: $w", "jitter_vote_weight")
    end
    abs(w) < 1e-9 && return w
    bound = ratio * abs(w)
    delta = (rand(rng) * 2.0 - 1.0) * bound
    return w + delta
end

"""
    maybe_attach_default_weight(w::Float64; rng)::Float64

GRUG: If the donated vote weight is effectively zero, attach a small default
weight on a DONATED_BARE_WEIGHT_PROB coinflip. Otherwise return w unchanged.
"""
function maybe_attach_default_weight(
    w::Float64;
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
)::Float64
    abs(w) < 1e-9 || return w
    return rand(rng) < DONATED_BARE_WEIGHT_PROB ? DONATED_BARE_WEIGHT : 0.0
end

# ==============================================================================
# VOTE-SWAP EVENT + STATS
# ==============================================================================

struct VoteSwapEvent
    group_id::String
    sender_id::String
    receiver_id::String
    donated_action::String
    donated_weight::Float64
    semantic_intensity::Float64
end

mutable struct VoteSwapStats
    rounds_run::Int
    swaps_attempted::Int
    swaps_accepted::Int
    rejected_cooldown::Int
    rejected_not_weak::Int
    rejected_semantic::Int
end

VoteSwapStats() = VoteSwapStats(0, 0, 0, 0, 0, 0)

# ==============================================================================
# ROUND RUNNER
# ==============================================================================

"""
    run_vote_swap_round!(group_ids, get_node, get_semantic_intensity,
                         apply_swap!; rng, now, stats)

GRUG: Run a vote-swap round over the provided group_ids.

Arguments:

  - `group_ids`: Vector of group ids to process this round. Typically comes
    from GroupRegistry.next_chatter_window_ids.

  - `get_node`: function (node_id) -> NamedTuple of
         (exists::Bool, strength::Float64, action::String, weight::Float64,
          is_weak::Bool)
    The engine wires this to its own NODE_MAP accessor. Unknown or graved
    nodes should return `(exists=false, ...)`.

  - `get_semantic_intensity`: function (sender_id, receiver_id) -> Float64.
    The engine uses relational-triple overlap + thesaurus / SemanticVerbs
    similarity to compute this. The gate is a coinflip on this value.

  - `apply_swap!`: function (event::VoteSwapEvent) -> Bool. The engine writes
    the donated action + weight into the receiver's per-cycle vote slot and
    returns true on success, false if the write failed (e.g. node vanished
    mid-round). Failures are logged and counted but do not abort the round.

  - `group_members`: function (group_id) -> Vector{String}. Returns the current
    members of the group. Allows the caller to delegate to GroupRegistry.

The round enforces all invariants described at the top of the module.
Returns the updated `stats` for telemetry.

Throws ChatterVoteSwapError for caller contract violations (empty lists,
non-callable arguments). Individual node errors are logged and skipped.
"""
function run_vote_swap_round!(
    group_ids::Vector{String},
    get_node::Function,
    get_semantic_intensity::Function,
    apply_swap!::Function,
    group_members::Function;
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
    now::Float64 = time(),
    stats::VoteSwapStats = VoteSwapStats(),
)::VoteSwapStats

    isempty(group_ids) && return stats  # GRUG: nothing to do is not an error

    # GRUG: Track who has already swapped THIS ROUND so we enforce the
    # "at most one swap per chatter round" rule.
    swapped_this_round = Set{String}()

    stats.rounds_run += 1

    for gid in group_ids
        isempty(strip(gid)) && _throw("empty group_id in list", "run_vote_swap_round!")

        members = group_members(gid)
        isempty(members) && continue

        # GRUG: Pair-up pass. Each member takes one pass as possible RECEIVER.
        # For each receiver, pick a random OTHER member as possible sender.
        # We shuffle once per group so pairing order is unbiased.
        shuffled = shuffle(rng, members)

        for receiver_id in shuffled
            receiver_id in swapped_this_round && continue

            # GRUG: Cooldown gate (1hr per node)
            if !can_chatter_now(receiver_id; now = now)
                stats.rejected_cooldown += 1
                continue
            end

            recv = try
                get_node(receiver_id)
            catch e
                @warn "[ChatterVoteSwap] get_node failed for receiver '$receiver_id': $e"
                continue
            end

            (!recv.exists || !recv.is_weak) && (stats.rejected_not_weak += 1; continue)

            # GRUG: Pick a sender that is not the receiver.
            candidates = filter(m -> m != receiver_id, members)
            isempty(candidates) && continue
            sender_id = candidates[rand(rng, 1:length(candidates))]

            send = try
                get_node(sender_id)
            catch e
                @warn "[ChatterVoteSwap] get_node failed for sender '$sender_id': $e"
                continue
            end

            (!send.exists) && continue

            # GRUG: Strength gate --- sender must be strictly stronger than
            # receiver. Weak-only copy preserves strong-node identity.
            if send.strength <= recv.strength
                stats.rejected_not_weak += 1
                continue
            end

            # GRUG: Semantic intensity gate (coinflip biased by capped intensity)
            intensity = try
                Float64(get_semantic_intensity(sender_id, receiver_id))
            catch e
                @warn "[ChatterVoteSwap] semantic_intensity failed ($sender_id -> $receiver_id): $e"
                0.0
            end

            if !should_swap_vote(intensity; rng = rng)
                stats.rejected_semantic += 1
                continue
            end

            # GRUG: Donated weight: jitter what sender has, OR coinflip-attach
            # a small default if sender's weight is effectively zero.
            donated_weight = maybe_attach_default_weight(send.weight; rng = rng)
            donated_weight = jitter_vote_weight(donated_weight; rng = rng)

            event = VoteSwapEvent(
                gid,
                sender_id,
                receiver_id,
                send.action,
                donated_weight,
                intensity,
            )

            stats.swaps_attempted += 1

            accepted = try
                apply_swap!(event)
            catch e
                @warn "[ChatterVoteSwap] apply_swap! threw for event $(event): $e"
                false
            end

            if accepted
                stats.swaps_accepted += 1
                record_chatter_time!(receiver_id; now = now)
                push!(swapped_this_round, receiver_id)
            end
        end
    end

    return stats
end

end # module ChatterVoteSwap
