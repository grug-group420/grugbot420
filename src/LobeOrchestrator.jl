# LobeOrchestrator.jl
# ==============================================================================
# GRUG v7.24 - SEQUENTIAL LOBE ORCHESTRATION + LOCK-IN AVERAGE + MULTI-LOBE ASYNC
# ==============================================================================
# #############################################################################
# ###  DO NOT ADD LOBE MUTING. DO NOT CHANGE LOBE SELECTION TO A GATE.     ###
# ###  LOBE_TOPICALITY_FLOOR AND apply_lobe_topicality_gate! ARE WRONG.     ###
# ###  THE CORRECT DESIGN IS THIS FILE: SEQUENTIAL LOBE FIRING.            ###
# ###  THIS WAS THE ORIGINAL DESIGN. IT WAS REMOVED AND REPLACED WITH       ###
# ###  MUTING. DO NOT DO THAT AGAIN.                                        ###
# ###  LOBES ARE NEVER MUTED. THEY FIRE SEQUENTIALLY. THE HIGHEST          ###
# ###  AVG LOCK-IN CONFIDENCE GOES FIRST. TIED LOBES BOTH FIRE,            ###
# ###  COINFLIP DECIDES ORDER.                                              ###
# #############################################################################
#
# GRUG: Old BrainStem pick one cave. Other caves get muted. Bad! Two smart caves
# could both have good idea but only one got to talk. New way: whichever cave
# has highest average lock-in confidence wins the floor AND goes FIRST.
# Other caves that pass threshold get to go AFTER, async. Cross-talk between
# caves must WAIT until the speaking caves finish. Cross-talk is hard-capped
# at 1000 active nodes total no matter how many caves are involved.
#
# TIE RULE (v7.24 CONFIRMED): If two+ lobes tie for highest avg, ALL
# tying lobes FIRE. A 50/50 coinflip decides which one goes FIRST. The tying
# lobes do NOT need to pass any separate gate — they already tied for first
# place. They are guaranteed to fire. The coinflip is purely an ORDERING
# decision, not an admission decision.
#
# NO CURVE NEEDED (v7.24): The lock-in floor (AIML_TOP_LOCKIN_FLOOR = 0.50)
# already filters out weak votes. Only votes that pass 0.50 reach this
# orchestrator. There are no mediocre votes to curve against. A simple
# average of lock-in confidences per lobe is all that's needed. The old
# curved_avg (base_avg * top_avg) was designed to prevent many-mediocre from
# beating few-strong, but mediocre votes don't exist here. Simple avg wins.
#
# MULTI-LOBE ASYNC GATE:
#   - A lobe must have avg >= MULTI_LOBE_THRESHOLD, AND
#   - A lobe must have at least MIN_WINNING_VOTES lock-in votes.
#   If both hold for more than one lobe, they run ASYNC. Highest avg
#   fires first. Tied avgs: both fire, coinflip decides order.
#
# HARD CAPS:
#   - Per-lobe active fire cap: 1000 nodes per speaking lobe per turn.
#   - Cross-talk active cap: 1000 nodes total regardless of how many lobes.
#
# NO SILENT FAILURES: every reject path throws LobeOrchestratorError.
# ==============================================================================

module LobeOrchestrator

using Base.Threads: ReentrantLock, @spawn
using Random

export LobeOrchestratorError
export LobeVoteSummary, OrchestrationPlan, FloorWinner
export summarize_lobe_votes, compute_orchestration_plan
export MULTI_LOBE_THRESHOLD, MIN_WINNING_VOTES
export PER_LOBE_FIRE_CAP, CROSS_TALK_ACTIVE_CAP
export CrossTalkGate, new_cross_talk_gate, try_claim_cross_talk!, release_cross_talk!
export reserved_cross_talk_slots

# ==============================================================================
# CONSTANTS (v7.24) --- all documented, all tunable from one place
# ==============================================================================

# GRUG v7.24: Minimum average lock-in confidence a lobe must reach before it
# can be considered for multi-lobe async firing. Below this, lobe is strictly
# runner-up. Since only lock-in votes (>= 0.50) feed this, the avg is already
# meaningful — no curve needed.
const MULTI_LOBE_THRESHOLD = 0.50

# GRUG: A lobe needs AT LEAST this many lock-in votes to be considered a real
# contender for multi-lobe async firing. Prevents a single freak high-confidence
# vote from granting floor access.
const MIN_WINNING_VOTES  = 2

# GRUG v7.24: REMOVED WINNING_VOTE_CONF — the lock-in floor (0.50) in
# VoteOrchestrator already gates which votes reach this module. No separate
# confidence threshold needed here. Every vote that arrives IS a lock-in vote.

# GRUG: Hard cap on concurrently-firing nodes per speaking lobe per turn.
const PER_LOBE_FIRE_CAP  = 1_000

# GRUG: Hard cap on cross-talk activations across ALL lobes. This is a global
# ceiling regardless of how many lobes are cross-talking. Enforced atomically
# through the CrossTalkGate below.
const CROSS_TALK_ACTIVE_CAP = 1_000

# ==============================================================================
# ERROR TYPE --- no silent failures, ever
# ==============================================================================

struct LobeOrchestratorError <: Exception
    message::String
    context::String
end

Base.showerror(io::IO, e::LobeOrchestratorError) =
    print(io, "LobeOrchestratorError[", e.context, "]: ", e.message)

_throw(msg::String, ctx::String) = throw(LobeOrchestratorError(msg, ctx))

# ==============================================================================
# LOBE VOTE SUMMARY --- per-lobe rollup of lock-in votes
# ==============================================================================

"""
    LobeVoteSummary(lobe_id, vote_count, avg_conf, max_conf, passes_multi_lobe_gate)

GRUG v7.24: Per-lobe rollup of this cycle's LOCK-IN vote pool.
`avg_conf` is the simple average of all lock-in confidences for this lobe.
No curve needed — the lock-in floor already filtered out weak votes.
`passes_multi_lobe_gate` pre-computes the two-factor gate so downstream
code can't forget one of the factors.
"""
struct LobeVoteSummary
    lobe_id::String
    vote_count::Int
    avg_conf::Float64
    max_conf::Float64
    passes_multi_lobe_gate::Bool
end

# ==============================================================================
# ORCHESTRATION PLAN --- what the orchestrator decided
# ==============================================================================

struct FloorWinner
    lobe_id::String
    avg_conf::Float64
    vote_count::Int
end

"""
    OrchestrationPlan(floor_winner, secondary_async, tie_resolved_by_coinflip,
                      all_summaries)

GRUG: The plan tells the pipeline who speaks first (`floor_winner`), which
other lobes get an async turn right after (`secondary_async`, ordered by
descending avg_conf), and whether a 50/50 coinflip was used to break an
exact tie (diagnostic only, does not change dispatch order).
"""
struct OrchestrationPlan
    floor_winner::Union{FloorWinner, Nothing}
    secondary_async::Vector{FloorWinner}
    tie_resolved_by_coinflip::Bool
    all_summaries::Vector{LobeVoteSummary}
end

# ==============================================================================
# SUMMARIZE --- build per-lobe summaries from lock-in votes
# ==============================================================================

"""
    summarize_lobe_votes(votes_by_lobe::Dict{String, Vector{Float64}})
        ::Vector{LobeVoteSummary}

GRUG v7.24: Takes a mapping from lobe_id -> list of LOCK-IN confidence scores
cast from that lobe this cycle. Returns a LobeVoteSummary per lobe, sorted by
avg_conf descending. Empty-vote lobes are silently dropped (no vote = no
summary = no floor claim). A lobe with a single lock-in vote is legal but
will almost never pass the two-factor gate (needs >= MIN_WINNING_VOTES).

NO CURVE: Since only lock-in votes (>= 0.50) reach this function, there are
no mediocre votes to curve against. Simple average is all that's needed.

Throws LobeOrchestratorError if any confidence is NaN/Inf.
"""
function summarize_lobe_votes(
    votes_by_lobe::Dict{String, Vector{Float64}}
)::Vector{LobeVoteSummary}

    summaries = LobeVoteSummary[]

    for (lobe_id, confs) in votes_by_lobe
        if isempty(strip(lobe_id))
            _throw("empty lobe_id in votes_by_lobe", "summarize_lobe_votes")
        end
        for c in confs
            if !isfinite(c)
                _throw("non-finite confidence $c for lobe '$lobe_id'", "summarize_lobe_votes")
            end
        end

        isempty(confs) && continue  # GRUG: lobe cast no votes; no summary

        avg_conf = sum(confs) / length(confs)
        max_conf = maximum(confs)

        # GRUG v7.24: Simple avg of lock-in votes. No curve needed.
        # The lock-in floor already filtered out weak votes.
        passes = (avg_conf >= MULTI_LOBE_THRESHOLD) &&
                 (length(confs) >= MIN_WINNING_VOTES)

        push!(summaries, LobeVoteSummary(
            String(lobe_id),
            length(confs),
            avg_conf,
            max_conf,
            passes,
        ))
    end

    # GRUG: Sort descending by avg_conf so downstream planning code can walk
    # summaries in priority order.
    sort!(summaries, by = s -> s.avg_conf, rev = true)

    return summaries
end

# ==============================================================================
# PLAN --- decide floor winner + async secondaries + handle exact ties
# ==============================================================================

"""
    compute_orchestration_plan(summaries::Vector{LobeVoteSummary};
                               rng::AbstractRNG = Random.GLOBAL_RNG)
        ::OrchestrationPlan

GRUG v7.24: Build the orchestration plan from summaries (sorted by avg_conf desc).

Rules enforced here (straight from the spec):
  - Floor winner = lobe with max avg_conf. Exact ties: ALL tying lobes FIRE.
    A 50/50 coinflip decides WHO GOES FIRST (ordering, not admission).
    Tying lobes are NEVER gated out — they tied for first place.
  - Secondary async = the remaining tying lobes (in coinflip order), THEN
    any other lobe whose `passes_multi_lobe_gate == true`. Non-tying secondaries
    must clear the gate; tying lobes are guaranteed regardless.
  - If the floor winner itself does NOT pass the multi-lobe gate, it still
    wins the floor (you always need someone to speak), but non-tying secondaries
    are not admitted — the gate is strictly additive for non-tiers.

The plan is pure data: no dispatching happens here. The caller (Main/engine)
consumes the plan and runs it through its own fire loop, respecting
PER_LOBE_FIRE_CAP and the CrossTalkGate below.
"""
function compute_orchestration_plan(
    summaries::Vector{LobeVoteSummary};
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
)::OrchestrationPlan

    if isempty(summaries)
        return OrchestrationPlan(nothing, FloorWinner[], false, summaries)
    end

    # GRUG: Find exact ties at the top (avg_conf equal to the very max).
    top_val = summaries[1].avg_conf
    tied_at_top = filter(s -> s.avg_conf == top_val, summaries)

    # #############################################################################
    # ###  DO NOT CHANGE: TIE RULE — ALL tying lobes FIRE.                    ###
    # ###  Coinflip decides ORDER (who goes first), NOT admission.            ###
    # ###  A tying lobe is NEVER gated out — it tied for first place.         ###
    # #############################################################################
    tie_flag = false
    ordered_tied = if length(tied_at_top) == 1
        tied_at_top
    else
        tie_flag = true
        # GRUG: Fair 50/50 (really 1/N) coinflip to decide ORDER only.
        # ALL tied lobes fire. The coinflip just picks who goes FIRST.
        shuffled = copy(tied_at_top)
        Random.shuffle!(rng, shuffled)
        shuffled
    end

    # GRUG: Floor winner = first in the coinflipped ordering.
    floor = FloorWinner(
        ordered_tied[1].lobe_id,
        ordered_tied[1].avg_conf,
        ordered_tied[1].vote_count,
    )

    # GRUG v7.24: Build the fire-order list. ALL tying lobes are guaranteed to
    # fire (they go first, in coinflip-decided order). After the tying lobes,
    # any OTHER lobe that passes the multi-lobe gate gets to go async.
    secondaries = FloorWinner[]

    # GRUG: First, the remaining tying lobes (2nd, 3rd, etc. in coinflip order).
    # These are GUARANTEED to fire — no gate check. They tied for first place.
    for i in 2:length(ordered_tied)
        push!(secondaries, FloorWinner(
            ordered_tied[i].lobe_id,
            ordered_tied[i].avg_conf,
            ordered_tied[i].vote_count,
        ))
    end

    # GRUG: Then, any non-tying lobes that pass the multi-lobe gate.
    # These did NOT tie for first, so they need to clear the gate to join.
    if ordered_tied[1].passes_multi_lobe_gate
        for s in summaries
            # Skip lobes already in the tie group (they're already guaranteed)
            any(t -> t.lobe_id == s.lobe_id, ordered_tied) && continue
            s.passes_multi_lobe_gate || continue
            push!(secondaries, FloorWinner(s.lobe_id, s.avg_conf, s.vote_count))
        end
    end

    return OrchestrationPlan(floor, secondaries, tie_flag, summaries)
end

# ==============================================================================
# CROSS-TALK GATE --- 1000 active cap across ALL cross-talking lobes
# ==============================================================================

"""
    CrossTalkGate(active_count, cap, lock)

GRUG: Atomic slot counter for cross-talk activations. Cross-talk means any
node-attach relay, drop-table cascade, or semantic-bridge firing that spans
lobe boundaries while multiple lobes are holding the floor. The gate is the
one shared resource all such firings must claim from.
"""
mutable struct CrossTalkGate
    active_count::Int
    cap::Int
    lock::ReentrantLock
end

new_cross_talk_gate(cap::Int = CROSS_TALK_ACTIVE_CAP) =
    CrossTalkGate(0, cap, ReentrantLock())

"""
    try_claim_cross_talk!(gate::CrossTalkGate)::Bool

GRUG: Returns true if a slot was claimed, false if the cap is full. Caller
must call release_cross_talk! exactly once per successful claim (pair them
in try/finally to avoid leaks). Rejections are counted by the caller's own
metrics --- this primitive just does the atomic math.
"""
function try_claim_cross_talk!(gate::CrossTalkGate)::Bool
    lock(gate.lock) do
        if gate.active_count >= gate.cap
            return false
        end
        gate.active_count += 1
        return true
    end
end

"""
    release_cross_talk!(gate::CrossTalkGate)

GRUG: Release a previously-claimed slot. Throws if called when count is
already 0 --- silent over-release is a bug, surface it.
"""
function release_cross_talk!(gate::CrossTalkGate)
    lock(gate.lock) do
        if gate.active_count <= 0
            _throw("release on empty gate (active_count=$(gate.active_count))",
                   "release_cross_talk!")
        end
        gate.active_count -= 1
    end
    return nothing
end

reserved_cross_talk_slots(gate::CrossTalkGate)::Int =
    lock(() -> gate.active_count, gate.lock)

# #############################################################################
# ###  DO NOT ADD LOBE MUTING. DO NOT REPLACE THIS WITH A GATE.            ###
# ###  THIS FILE IS THE CORRECT DESIGN. LOBES FIRE SEQUENTIALLY.           ###
# ###  IF YOU ARE TEMPTED TO ADD LOBE_TOPICALITY_FLOOR OR                  ###
# ###  apply_lobe_topicality_gate! OR ANYTHING THAT MUTES LOBES,            ###
# ###  STOP. READ THIS FILE AGAIN. DO NOT DO IT.                           ###
# #############################################################################

end # module LobeOrchestrator
