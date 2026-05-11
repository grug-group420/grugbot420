# LobeOrchestrator.jl
# ==============================================================================
# GRUG v7.15 - SEQUENTIAL LOBE ORCHESTRATION + CURVED AVERAGE + MULTI-LOBE ASYNC
# ==============================================================================
# GRUG: Old BrainStem pick one cave. Other caves get muted. Bad! Two smart caves
# could both have good idea but only one got to talk. New way: whichever cave
# has highest CURVED vote-confidence-average wins the floor AND goes FIRST.
# Other caves that pass threshold get to go AFTER, async. Cross-talk between
# caves must WAIT until the speaking caves finish. Cross-talk is hard-capped
# at 1000 active nodes total no matter how many caves are involved.
#
# CURVE FORMULA:
#   base_avg   = mean(all vote confidences in lobe)
#   top_avg    = mean(top-tier vote confidences in lobe - within TOP_WINDOW of max)
#   curved_avg = base_avg * top_avg
#
# The curve multiplies the base average by the top-tier average so that a lobe
# with many mediocre votes DOES NOT beat a lobe with a few high-confidence
# votes. The curve enforces vote quality over vote quantity.
#
# MULTI-LOBE ASYNC GATE:
#   - A lobe must have curved_avg >= MULTI_LOBE_THRESHOLD, AND
#   - A lobe must have at least MIN_WINNING_VOTES votes above WINNING_VOTE_CONF.
#   If both hold for more than one lobe, they run ASYNC. Highest curved_avg
#   fires first. Tied curved_avgs resolve by fair 50/50 coinflip.
#
# HARD CAPS (all updates in this section):
#   - Per-lobe active fire cap: 1000 nodes per speaking lobe per turn.
#   - Cross-talk active cap: 1000 nodes total regardless of how many lobes
#     are cross-talking.
#
# NO SILENT FAILURES: every reject path throws LobeOrchestratorError with a
# named context so the caller can surface exactly which lobe / which gate
# rejected the floor.
# ==============================================================================

module LobeOrchestrator

using Base.Threads: ReentrantLock, @spawn
using Random

export LobeOrchestratorError
export LobeVoteSummary, OrchestrationPlan, FloorWinner
export summarize_lobe_votes, compute_orchestration_plan
export MULTI_LOBE_THRESHOLD, MIN_WINNING_VOTES, WINNING_VOTE_CONF
export PER_LOBE_FIRE_CAP, CROSS_TALK_ACTIVE_CAP, TOP_WINDOW
export CrossTalkGate, new_cross_talk_gate, try_claim_cross_talk!, release_cross_talk!
export reserved_cross_talk_slots

# ==============================================================================
# CONSTANTS (v7.15) --- all documented, all tunable from one place
# ==============================================================================

# GRUG: Minimum curved-average a lobe must reach before it can be considered
# for multi-lobe async firing. Below this, lobe is strictly runner-up.
# 0.35 chosen so that a lobe with mean=0.45 and a single 0.80-top wins
# (0.45 * 0.80 = 0.36 > threshold) while a lobe of mostly-noise stays out.
const MULTI_LOBE_THRESHOLD = 0.35

# GRUG: A lobe needs AT LEAST this many votes above WINNING_VOTE_CONF to be
# considered a real contender for multi-lobe async firing. Prevents a single
# freak high-confidence vote from granting floor access.
const MIN_WINNING_VOTES  = 2
const WINNING_VOTE_CONF  = 0.55

# GRUG: Hard cap on concurrently-firing nodes per speaking lobe per turn.
const PER_LOBE_FIRE_CAP  = 1_000

# GRUG: Hard cap on cross-talk activations across ALL lobes. This is a global
# ceiling regardless of how many lobes are cross-talking. Enforced atomically
# through the CrossTalkGate below.
const CROSS_TALK_ACTIVE_CAP = 1_000

# GRUG: Top-tier window for curve computation. Votes within TOP_WINDOW of the
# max confidence in a lobe count as top-tier. Matches AIML_TOP_TIER_WINDOW
# in VoteOrchestrator for consistency.
const TOP_WINDOW = 0.05

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
# LOBE VOTE SUMMARY --- per-lobe rollup of the vote pool
# ==============================================================================

"""
    LobeVoteSummary(lobe_id, vote_count, base_avg, top_avg, curved_avg,
                    winning_vote_count, max_conf, passes_multi_lobe_gate)

GRUG: Per-lobe rollup of this cycle's vote pool. `curved_avg` is the quantity
all orchestration decisions look at. `passes_multi_lobe_gate` pre-computes the
two-factor gate so downstream code can't forget one of the factors.
"""
struct LobeVoteSummary
    lobe_id::String
    vote_count::Int
    base_avg::Float64
    top_avg::Float64
    curved_avg::Float64
    winning_vote_count::Int
    max_conf::Float64
    passes_multi_lobe_gate::Bool
end

# ==============================================================================
# ORCHESTRATION PLAN --- what the orchestrator decided
# ==============================================================================

struct FloorWinner
    lobe_id::String
    curved_avg::Float64
    winning_vote_count::Int
end

"""
    OrchestrationPlan(floor_winner, secondary_async, tie_resolved_by_coinflip,
                      all_summaries)

GRUG: The plan tells the pipeline who speaks first (`floor_winner`), which
other lobes get an async turn right after (`secondary_async`, ordered by
descending curved_avg), and whether a 50/50 coinflip was used to break an
exact tie (diagnostic only, does not change dispatch order).
"""
struct OrchestrationPlan
    floor_winner::Union{FloorWinner, Nothing}
    secondary_async::Vector{FloorWinner}
    tie_resolved_by_coinflip::Bool
    all_summaries::Vector{LobeVoteSummary}
end

# ==============================================================================
# SUMMARIZE --- build per-lobe summaries from a (lobe_id, confidence) stream
# ==============================================================================

"""
    summarize_lobe_votes(votes_by_lobe::Dict{String, Vector{Float64}})
        ::Vector{LobeVoteSummary}

GRUG: Takes a mapping from lobe_id -> list of confidence scores cast from that
lobe this cycle. Returns a LobeVoteSummary per lobe, sorted by curved_avg
descending. Empty-vote lobes are silently dropped (no vote = no summary =
no floor claim). A lobe with a single vote is legal but will almost never pass
the two-factor gate (needs >= MIN_WINNING_VOTES).

Throws LobeOrchestratorError if any confidence is NaN/Inf or if the map itself
is not a Dict (no silent corruption).
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

        max_conf = maximum(confs)
        base_avg = sum(confs) / length(confs)

        # GRUG: Top-tier = votes within TOP_WINDOW of max_conf. At least one
        # vote always qualifies (max itself). Average over just those.
        top_tier = filter(c -> c >= max_conf - TOP_WINDOW, confs)
        top_avg  = sum(top_tier) / length(top_tier)

        curved_avg = base_avg * top_avg  # GRUG: the whole point of the curve

        winning_vote_count = count(c -> c >= WINNING_VOTE_CONF, confs)

        passes = (curved_avg >= MULTI_LOBE_THRESHOLD) &&
                 (winning_vote_count >= MIN_WINNING_VOTES)

        push!(summaries, LobeVoteSummary(
            String(lobe_id),
            length(confs),
            base_avg,
            top_avg,
            curved_avg,
            winning_vote_count,
            max_conf,
            passes,
        ))
    end

    # GRUG: Sort descending by curved_avg so downstream planning code can walk
    # summaries in priority order.
    sort!(summaries, by = s -> s.curved_avg, rev = true)

    return summaries
end

# ==============================================================================
# PLAN --- decide floor winner + async secondaries + handle exact ties
# ==============================================================================

"""
    compute_orchestration_plan(summaries::Vector{LobeVoteSummary};
                               rng::AbstractRNG = Random.GLOBAL_RNG)
        ::OrchestrationPlan

GRUG: Build the orchestration plan from summaries (sorted by curved_avg desc).

Rules enforced here (straight from the update spec):
  - Floor winner = lobe with max curved_avg. Exact ties resolve by 50/50
    coinflip and mark `tie_resolved_by_coinflip = true`.
  - Secondary async = any other lobe whose `passes_multi_lobe_gate == true`.
    They fire in curved_avg-desc order AFTER the floor winner has finished.
  - If the floor winner itself does NOT pass the multi-lobe gate, it still
    wins the floor (you always need someone to speak), but no secondaries
    are admitted --- the gate is strictly additive.

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

    # GRUG: Find exact ties at the top (curved_avg equal to the very max).
    top_avg = summaries[1].curved_avg
    tied_at_top = filter(s -> s.curved_avg == top_avg, summaries)

    tie_flag = false
    winner_summary = if length(tied_at_top) == 1
        tied_at_top[1]
    else
        tie_flag = true
        # GRUG: Fair 50/50 (really 1/N) coinflip over exact-ties only.
        tied_at_top[rand(rng, 1:length(tied_at_top))]
    end

    floor = FloorWinner(
        winner_summary.lobe_id,
        winner_summary.curved_avg,
        winner_summary.winning_vote_count,
    )

    # GRUG: Only admit secondaries if the floor winner itself cleared the gate.
    # Otherwise there's no "strong multi-lobe moment" to share the floor.
    secondaries = FloorWinner[]
    if winner_summary.passes_multi_lobe_gate
        for s in summaries
            s.lobe_id == winner_summary.lobe_id && continue
            s.passes_multi_lobe_gate || continue
            push!(secondaries, FloorWinner(s.lobe_id, s.curved_avg, s.winning_vote_count))
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

end # module LobeOrchestrator
