module LobeOrchestrator

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

using Base.Threads: ReentrantLock

# ==============================================================================
# LobeOrchestrator — averages-curve lobe selection (replaces hard mute gate)
# ==============================================================================
#
# Replaces the v7.18 "topicality mute gate" with the user-spec averages curve:
#
#   1. Every lobe collects its node-vote confidences. Nobody is muted up-front.
#   2. For each lobe compute:
#        base_avg = mean of all vote confidences in that lobe
#        top_avg  = mean of the hard-selected top-K confidences in that lobe
#      Score: lobe_score = sqrt(base_avg) * top_avg²  (the "curve")
#      Top averages have exponentially more weight than base averages.
#   3. Highest score wins the orchestration floor.
#   4. Multi-lobe pass-through: a runner-up lobe also fires IF
#         (a) lobe_score >= MIN_PASS_THROUGH_SCORE, AND
#         (b) it has >= MIN_WINNING_VOTES_PER_LOBE hard-selected votes
#            (small votes piling up to a high avg do NOT count).
#   5. Tie: equal scores → 50/50 coinflip. Winner goes first, both still fire.
#   6. Hard 1k-per-batch fire cap. Winner lobe fires first in 1k rows.
#      Runners-up wait their turn and also fire in 1k batches. Cross-talk /
#      attached / nodeAttach activations from any of these MUST WAIT until the
#      lobe(s) finish, then fire as their own 1k-capped batch.
#
# This module exports:
#   - score_lobes(entries) → ordered Vector of LobeFireOrder
#   - compute_fire_batches(ordered) → Vector of 1k-capped batch chunks
#   - LobeFireOrder struct (lobe_id, score, entries, is_winner, is_passthrough)
#   - fire-stage telemetry refs (read by Main.jl to surface in the AIML scaffold)
#
# Constants:
#   - HARD_FIRE_BATCH_CAP            = 1000  (rows-per-batch hard cap)
#   - MIN_PASS_THROUGH_SCORE         = 0.10  (lobe_score floor for passthrough)
#   - MIN_WINNING_VOTES_PER_LOBE     = 2     (hard-selected votes required)
#   - TOP_K_FRACTION                 = 0.5   (top K = top half by confidence)
#   - HARD_SELECTION_CONF_THRESHOLD  = 0.5   (a "hard selection" is conf >= 0.5)
#
# Telemetry refs (consumed by the scaffold):
#   - LAST_LOBE_SCORES :: Vector{Tuple{String, Float64, Float64, Float64, Int}}
#       (lobe_id, base_avg, top_avg, lobe_score, hard_vote_count)
#   - LAST_WINNER      :: Ref{String}
#   - LAST_PASSTHROUGH :: Vector{String}
# ==============================================================================

using Statistics: mean
using Base.Math: sqrt

# --- Tunables ----------------------------------------------------------------
const HARD_FIRE_BATCH_CAP           = 1000
const MIN_PASS_THROUGH_SCORE        = 0.10
const MIN_WINNING_VOTES_PER_LOBE    = 2
const TOP_K_FRACTION                = 0.5
const HARD_SELECTION_CONF_THRESHOLD = 0.5
# v10-coherence-fix: PEAK-VOTE LOBE GUARD.
# The averages curve (sqrt(base_avg) * top_avg^2) can crown a lobe that does
# NOT contain the single highest-confidence vote in the whole pool. When the
# downstream composite_vote_score then applies VOTE_W_LOBE_ALIGNMENT (+0.40)
# to every node in the crowned lobe, the TRUE content winner (a decisive vote
# sitting in a different lobe) gets out-ranked by a weaker sibling of the
# crowned lobe. Observed decoherence: "what is gravity" (n101, physics) lost
# to n103 (math) because the math lobe's curve edged out physics even though
# n101 was the single highest-confidence vote.
#
# Guard: if one lobe owns the GLOBAL peak vote AND that peak clears
# PEAK_GUARD_MIN_CONF AND it leads the next-best lobe's peak by
# PEAK_GUARD_MARGIN, that lobe is promoted to winner. This only fires when a
# single node is a clear, decisive content match — genuinely ambiguous
# multi-lobe inputs (close peaks) still go through the normal curve.
const PEAK_GUARD_ENABLED            = true
const PEAK_GUARD_MIN_CONF           = 0.45   # peak vote must be at least this confident
const PEAK_GUARD_MARGIN             = 0.05   # peak must lead 2nd lobe's peak by this much
# v7.24-coherence-fix BUG #2: when ANY named lobe has hard_votes >= 1, the
# `default` lobe score is multiplied by this factor. The `default` lobe
# carries the inline boot seeds (boot fallback). Without this demotion, the
# greedy boot patterns ("think ponder reason calculate", "hello hi greeting
# mornin") steal wins from named lobes on inputs the named lobes obviously
# own. 0.5 is conservative — `default` can still win if no named lobe has
# any hard votes, or if its score is more than 2x the strongest named lobe.
const DEFAULT_LOBE_DEMOTION_FACTOR  = 0.5

# A scan/vote entry is the engine's standard expanded tuple:
#   (node_id::String, conf::Float64, antimatch::Bool,
#    user_triples::Vector, node_triples::Vector)
const EntryT = Tuple{String, Float64, Bool, Any, Any}

"""
    LobeFireOrder

GRUG: Per-lobe firing decision after the curve. `entries` are the raw
vote-pool tuples that belong to this lobe. `is_winner` is true for the
single highest-scoring lobe. `is_passthrough` is true for runners-up that
cleared the multi-lobe threshold.
"""
struct LobeFireOrder
    lobe_id::String
    score::Float64
    base_avg::Float64
    top_avg::Float64
    hard_vote_count::Int
    entries::Vector
    is_winner::Bool
    is_passthrough::Bool
end

# --- Telemetry refs ----------------------------------------------------------
const _TELEMETRY_LOCK = ReentrantLock()
const LAST_LOBE_SCORES = Ref{Vector{Tuple{String, Float64, Float64, Float64, Int}}}(
    Tuple{String, Float64, Float64, Float64, Int}[]
)
const LAST_WINNER      = Ref{String}("")
const LAST_PASSTHROUGH = Ref{Vector{String}}(String[])

"""
    reset_telemetry!()

GRUG: Clear all telemetry refs. Called at the top of score_lobes so repeated
calls don't accumulate.
"""
function reset_telemetry!()
    lock(_TELEMETRY_LOCK) do
        LAST_LOBE_SCORES[] = Tuple{String, Float64, Float64, Float64, Int}[]
        LAST_WINNER[]      = ""
        LAST_PASSTHROUGH[] = String[]
    end
    return nothing
end

"""
    get_last_state() -> (scores, winner, passthrough)

Thread-safe snapshot of all three telemetry refs under a single lock.
Returns (copy(LAST_LOBE_SCORES[]), LAST_WINNER[], copy(LAST_PASSTHROUGH[])).
"""
function get_last_state()
    lock(_TELEMETRY_LOCK) do
        (copy(LAST_LOBE_SCORES[]), LAST_WINNER[], copy(LAST_PASSTHROUGH[]))
    end
end

"""
    set_last_state!(scores, winner, passthrough)

Thread-safe write of all three telemetry refs under a single lock.
Used by specimen restore to replay saved lobe orchestrator state.
"""
function set_last_state!(scores, winner, passthrough)
    lock(_TELEMETRY_LOCK) do
        LAST_LOBE_SCORES[] = scores
        LAST_WINNER[]      = winner
        LAST_PASSTHROUGH[] = passthrough
    end
    return nothing
end

"""
    _group_by_lobe(entries, lobe_lookup) -> Dict{String, Vector}

GRUG: Group raw vote-pool entries by their lobe id. `lobe_lookup` is a
function that returns either a String lobe id or nothing for orphan nodes.
Orphans are bucketed under "-" (the legacy unassigned bucket).
"""
function _group_by_lobe(entries::AbstractVector, lobe_lookup)::Dict{String, Vector}
    by_lobe = Dict{String, Vector}()
    for e in entries
        nid = e[1]
        lobe_id = try
            lobe_lookup(nid)
        catch
            nothing
        end
        key = isnothing(lobe_id) ? "-" : lobe_id
        push!(get!(by_lobe, key, similar(entries, 0)), e)
    end
    return by_lobe
end

"""
    _compute_lobe_score(entries) -> (base_avg, top_avg, score, hard_vote_count)

GRUG: The averages curve.
  base_avg = mean of all confidences
  top_avg  = mean of the top TOP_K_FRACTION by confidence
  score    = sqrt(base_avg) * top_avg^2              <-- top-dominated curve
  hard_vote_count = how many entries have conf >= HARD_SELECTION_CONF_THRESHOLD
"""
function _compute_lobe_score(entries::AbstractVector)::Tuple{Float64, Float64, Float64, Int}
    if isempty(entries)
        return (0.0, 0.0, 0.0, 0)
    end
    confs = Float64[Float64(e[2]) for e in entries]
    base_avg = mean(confs)

    # top-K (round up so a single-vote lobe still has a top set)
    k = max(1, Int(ceil(length(confs) * TOP_K_FRACTION)))
    sorted = sort(confs; rev = true)
    top_avg = mean(@view sorted[1:k])

    # GRUG: TOP-DOMINATED CURVE — top vote averages have a MUCH larger
    # influence on the score than base averages.
    #
    # The old formula was base_avg * top_avg (equal weight). That meant a
    # lobe with many weak votes (high base_avg) and low hard selections
    # (low top_avg) could beat a lobe with a few decisive hard votes and
    # a low base_avg. For example, conversation lobe on "What is the quadratic
    # formula" would get base_avg ≈ 0.27 from 4 nodes (some mediocre), while
    # math lobe got base_avg ≈ 0.13 from 1-2 nodes — but math's top_avg was
    # decisive. Equal weighting let conversation's broad mediocrity win over
    # math's focused confidence.
    #
    # The fix: weight top_avg exponentially higher than base_avg.
    #   curve = base_avg^0.5 * top_avg^2.0
    #
    # This means:
    #   - base_avg is square-rooted: a lobe with many weak votes contributes
    #     less (sqrt(0.27) ≈ 0.52 vs sqrt(0.13) ≈ 0.36 — not a 2× gap anymore).
    #   - top_avg is squared: decisive hard selections dominate the curve.
    #     A top_avg of 0.6 → 0.36, while 0.3 → 0.09 — a 4× gap.
    #   - The net effect: lobes with confident hard selections win handily
    #     over lobes with broad but weak consensus.
    #
    # The old max(curve, peak^2) override has been REMOVED. The new curve
    # already rewards high top_avg (which includes the peak), so peak^2 is
    # redundant and actually counterproductive — it overrides the curve in
    # cases where the curve should matter (e.g., conversation peak=0.25
    # gives peak^2=0.0625, which is higher than the curve for EITHER lobe,
    # masking the curve's routing effect entirely).
    #
    # With this fix, the per-lobe fuzzy whitelist becomes a safety net rather
    # than a primary gate. The curve itself should correctly route "What is
    # the quadratic formula" to math, not conversation, because math's hard
    # selections (node_5 at decent confidence) will dominate conversation's
    # mediocre top_avg.
    peak = sorted[1]
    score = sqrt(base_avg) * (top_avg ^ 2)

    hard_count = count(c -> c >= HARD_SELECTION_CONF_THRESHOLD, confs)
    return (base_avg, top_avg, score, hard_count)
end

"""
    score_lobes(entries, lobe_lookup; input_tokens=String[]) -> Vector{LobeFireOrder}

GRUG: Replaces the hard mute gate. Returns lobes ordered by score (winner
first), with runners-up that cleared the multi-lobe threshold flagged as
`is_passthrough`. Lobes that did not clear are EXCLUDED from the result.

`lobe_lookup(node_id)` should return the String lobe id, or nothing for
orphans. Orphans are bucketed into a synthetic "-" lobe and competed alongside
real lobes (no special-case fallback).

`input_tokens` are the tokenized input words, used by the per-lobe fuzzy
whitelist gate. If a lobe has a non-empty subject_whitelist and none of the
input tokens match, the lobe is vetoed (score forced to 0). This prevents
"What is the quadratic formula" from misfiring into the conversation lobe.
Empty input_tokens disables the whitelist gate entirely (backward compatible).

Tie handling: lobes with identical scores are ordered by a 50/50 coinflip
between them (one of the two is randomly first). Both still fire.
"""
function score_lobes(entries::AbstractVector, lobe_lookup; input_tokens::AbstractVector=String[])::Vector{LobeFireOrder}
# REMINDER: ANTIMATCH NODES DO NOT EXIST. Do not add antimatch drain logic.
    reset_telemetry!()

    if isempty(entries)
        return LobeFireOrder[]
    end

    by_lobe = _group_by_lobe(entries, lobe_lookup)
    if isempty(by_lobe)
        return LobeFireOrder[]
    end

    # Score every lobe, store telemetry for ALL lobes (so the scaffold can show
    # losers too — important for debugging "why didn't lobe X fire").
    scored = Tuple{String, Float64, Float64, Float64, Int, Vector}[]
    for (lobe_id, lobe_entries) in by_lobe
        base_avg, top_avg, score, hard_count = _compute_lobe_score(lobe_entries)

        # v7.24-restore: REMOVED fuzzy whitelist veto.
        # User directive: "no the anti match white list not needed. now it does
        # lobe muting which is dumb." A lobe with high vote-confidence average
        # has earned the floor on merit; we do NOT need a subject whitelist to
        # gate it. The averages curve (sqrt(base_avg) * top_avg^2) plus the
        # MIN_PASS_THROUGH_SCORE threshold already keep mediocre lobes from
        # winning. If two lobes pass the threshold, they fire async (highest
        # first), and cross-talk is hard-capped to 1k active at a time.
        push!(scored, (lobe_id, base_avg, top_avg, score, hard_count, lobe_entries))
        lock(_TELEMETRY_LOCK) do
            push!(LAST_LOBE_SCORES[], (lobe_id, base_avg, top_avg, score, hard_count))
        end
    end

    # v7.24-coherence-fix BUG #2: `default` lobe demotion.
    # The `default` lobe holds the inline boot seeds (greet/reason/relational)
    # whose patterns contain greedy tokens like "calculate", "hello", "fire".
    # Those seeds were stealing wins from properly named lobes (MathLobe,
    # SocialLobe, ScienceLobe) on inputs that obviously belong to the named
    # lobe — e.g. "calculate ten plus five plus seven" beat MathLobe because
    # the boot reasoning seed has the word "calculate" in its pattern.
    #
    # v7.24-BUG2-v2: The original rule (hard_votes >= 1) was too strict.
    # Greetings like "hello grug" score low confidence on both default and
    # SocialLobe (neither reaches HARD_SELECTION_CONF_THRESHOLD=0.5), so
    # the demotion never fires and default wins the tie. Fix: demote default
    # when ANY named lobe has a non-zero base_avg (i.e., at least one node
    # in that lobe matched the input). This means "default only wins when
    # no named lobe even showed up."
    let
        any_named_present = any(
            t -> t[1] != "default" && t[1] != "-" && t[2] > 0.0,
            scored
        )
        if any_named_present
            # v10-coherence-fix: demote BOTH the boot "default" lobe AND the
            # synthetic orphan "-" bucket when any real named lobe matched. The
            # orphan bucket holds freshly AutoGrowth-created nodes (strength ~1,
            # generic "wall of knowing" prompts) and lobeless seeds. These must
            # not out-rank an established named-lobe content match — otherwise a
            # weak learned node steals the answer from the canonical strong node
            # (observed: post-learn "what is gravity" routed to orphan node_154
            # "force math field" instead of the n101 gravity node). Demotion lets
            # learned nodes still WIN when no named lobe matched at all (genuine
            # novel input → the learned node is the best the cave has).
            for demote_lid in ("default", "-")
                for k in eachindex(scored)
                    if scored[k][1] == demote_lid
                        (lid, ba, ta, sc, hc, le) = scored[k]
                        new_score = sc * DEFAULT_LOBE_DEMOTION_FACTOR
                        scored[k] = (lid, ba, ta, new_score, hc, le)
                        # Update telemetry too so the scaffold prints the
                        # demoted score, not the raw one.
                        lock(_TELEMETRY_LOCK) do
                            for ti in eachindex(LAST_LOBE_SCORES[])
                                if LAST_LOBE_SCORES[][ti][1] == demote_lid
                                    (tlid, tba, tta, _, thc) = LAST_LOBE_SCORES[][ti]
                                    LAST_LOBE_SCORES[][ti] = (tlid, tba, tta, new_score, thc)
                                    break
                                end
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    # Sort by score descending. For ties, randomize ordering (50/50 coinflip
    # equivalent for pairs; for >2-way ties we shuffle once across the tied
    # group, which is the natural generalization of a coinflip).
    sort!(scored; by = x -> -x[4])  # primary: score desc

    # Coinflip for ties: walk runs of equal score and shuffle them in place.
    i = 1
    while i <= length(scored)
        j = i
        while j < length(scored) && scored[j + 1][4] == scored[i][4]
            j += 1
        end
        if j > i
            # randomize the tied run
            tied_run = view(scored, i:j)
            tied_idx = collect(1:(j - i + 1))
            # Fisher-Yates on tied_idx
            for k in length(tied_idx):-1:2
                r = rand(1:k)
                tied_idx[k], tied_idx[r] = tied_idx[r], tied_idx[k]
            end
            tied_copy = [scored[i + idx - 1] for idx in tied_idx]
            for (k, v) in enumerate(tied_copy)
                scored[i + k - 1] = v
            end
        end
        i = j + 1
    end

    # v10-coherence-fix: PEAK-VOTE LOBE GUARD.
    # After the curve sort, check whether a *different* lobe owns the global
    # peak vote by a decisive margin. If so, promote that lobe to winner. This
    # prevents the averages curve from handing the +VOTE_W_LOBE_ALIGNMENT bonus
    # to a lobe that does NOT contain the single best content match, which was
    # the root cause of "what is gravity" routing to a math node instead of the
    # physics node. We only override when the peak is decisive (>= MIN_CONF and
    # leads the runner-lobe peak by >= MARGIN); ambiguous inputs keep the curve.
    if PEAK_GUARD_ENABLED && length(scored) > 1
        # Compute each lobe's peak (max) confidence from its entries.
        # entries are tuples; confidence is field 2 (id, conf, ...).
        _peak_of(lobe_entries) = begin
            mx = -Inf
            for e in lobe_entries
                c = e[2]
                if c > mx
                    mx = c
                end
            end
            mx
        end
        # Build (idx, lobe_id, peak) for all scored lobes (skip the synthetic
        # orphan bucket "-" and the demoted "default" — they should never win
        # the content-peak guard with their weak/generic learned nodes).
        peaks = Tuple{Int,String,Float64}[]
        for (idx, t) in enumerate(scored)
            lid = t[1]
            if lid == "-" || lid == "default"
                continue
            end
            push!(peaks, (idx, lid, _peak_of(t[6])))
        end
        if length(peaks) >= 1
            sort!(peaks; by = x -> -x[3])
            top_idx, top_lid, top_peak = peaks[1]
            second_peak = length(peaks) >= 2 ? peaks[2][3] : 0.0
            current_winner_lid = scored[1][1]
            if get(ENV, "GRUG_DEBUG_PEAK", "") != ""
                @info "[PEAKGUARD] winner_curve=$current_winner_lid top_peak_lobe=$top_lid peak=$(round(top_peak,digits=3)) second=$(round(second_peak,digits=3))"
            end
            # Decisive-peak promotion: a named lobe owning a clear global peak
            # is promoted over the curve winner.
            decisive = top_lid != current_winner_lid &&
                       top_peak >= PEAK_GUARD_MIN_CONF &&
                       (top_peak - second_peak) >= PEAK_GUARD_MARGIN
            # v10-coherence-fix: ORPHAN/DEFAULT OVERRIDE. If the curve crowned the
            # synthetic orphan bucket "-" or the boot "default" lobe, but a real
            # NAMED lobe owns the global content peak, promote the named lobe even
            # at a modest peak. Lobeless AutoGrowth nodes (generic "wall of
            # knowing" patterns) must not answer a query that a named-lobe node
            # matched on content — the named node is the real answer; the orphan
            # only won because its curve edged out after the bridge/relay shuffle.
            orphan_override = (current_winner_lid == "-" || current_winner_lid == "default") &&
                              top_lid != current_winner_lid &&
                              top_peak > 0.0 &&
                              top_peak >= second_peak
            if decisive || orphan_override
                # Promote the peak-owning lobe to the front.
                promoted = scored[top_idx]
                deleteat!(scored, top_idx)
                pushfirst!(scored, promoted)
            end
        end
    end

    # Apply pass-through threshold:
    #   - winner is always included regardless of threshold
    #     (otherwise we'd have systemic silence on very weak input,
    #      which is what we just removed by deleting the mute gate).
    #   - runner-ups are included only if score >= MIN_PASS_THROUGH_SCORE
    #     AND hard_vote_count >= MIN_WINNING_VOTES_PER_LOBE.
    out = LobeFireOrder[]
    for (idx, (lobe_id, base_avg, top_avg, score, hard_count, lobe_entries)) in enumerate(scored)
        is_winner = (idx == 1)
        is_passthrough = false
        if !is_winner
            if score >= MIN_PASS_THROUGH_SCORE && hard_count >= MIN_WINNING_VOTES_PER_LOBE
                is_passthrough = true
            else
                # Not winner and didn't clear threshold — drop.
                continue
            end
        end
        push!(out, LobeFireOrder(
            lobe_id, score, base_avg, top_avg, hard_count,
            collect(lobe_entries), is_winner, is_passthrough
        ))
    end

    # Update top-level telemetry
    if !isempty(out)
        lock(_TELEMETRY_LOCK) do
            LAST_WINNER[] = out[1].lobe_id
            LAST_PASSTHROUGH[] = [o.lobe_id for o in out if o.is_passthrough]
        end
    end

    return out
end

"""
    flatten_in_fire_order(orders) -> Vector

GRUG: Take the ordered Vector{LobeFireOrder} from score_lobes and produce a
single flat entries vector in the order they should fire. Winner's nodes go
first, then each passthrough lobe's nodes in score order. The downstream
firing pipeline batches this into HARD_FIRE_BATCH_CAP rows per batch.

Cross-talk / attached node activation MUST happen AFTER this flat list is
fully fired (the engine handles that as a separate relay pass — see
attachment_relay_fire in engine.jl).
"""
function flatten_in_fire_order(orders::Vector{LobeFireOrder})::Vector
    out = Any[]
    for o in orders
        append!(out, o.entries)
    end
    return out
end

"""
    compute_fire_batches(flat_entries) -> Vector{Vector}

GRUG: Chunk a flat entries vector into batches of at most HARD_FIRE_BATCH_CAP.
Used by the firing pipeline to keep the per-batch active fire count bounded.
"""
function compute_fire_batches(flat_entries::AbstractVector)::Vector{Vector}
    batches = Vector{Vector}()
    n = length(flat_entries)
    i = 1
    while i <= n
        j = min(i + HARD_FIRE_BATCH_CAP - 1, n)
        push!(batches, collect(flat_entries[i:j]))
        i = j + 1
    end
    return batches
end

"""
    last_summary() -> String

GRUG: Multi-line readout of the last score_lobes call, for the AIML
scaffold debug block. Replaces the old "Muted Lobes:" / "Bridged Nodes:"
lines.
"""
function last_summary()::String
    scores, winner, passthrough = lock(_TELEMETRY_LOCK) do
        (copy(LAST_LOBE_SCORES[]), LAST_WINNER[], copy(LAST_PASSTHROUGH[]))
    end
    if isempty(scores)
        return "Lobe Curve: (no lobes scored)"
    end
    lines = String["Lobe Curve (√base × top² = score):"]
    # Sort scores desc for the readout
    sorted = sort(scores; by = x -> -x[4])
    for (lobe_id, base_avg, top_avg, score, hard_count) in sorted
        marker = if lobe_id == winner
            "👑"
        elseif lobe_id in passthrough
            "↗"
        else
            "·"
        end
        veto_tag = ""
        push!(lines, "  $marker $lobe_id: base=$(round(base_avg, digits=3)) " *
                     "× top=$(round(top_avg, digits=3)) = $(round(score, digits=4)) " *
                     "[hard_votes=$hard_count]$veto_tag")
    end
    return join(lines, "\n")
end

# --- Exports -----------------------------------------------------------------
export LobeFireOrder
export score_lobes, flatten_in_fire_order, compute_fire_batches
export reset_telemetry!, last_summary, get_last_state, set_last_state!
export LAST_LOBE_SCORES, LAST_WINNER, LAST_PASSTHROUGH
export HARD_FIRE_BATCH_CAP, MIN_PASS_THROUGH_SCORE,
       MIN_WINNING_VOTES_PER_LOBE, TOP_K_FRACTION,
       HARD_SELECTION_CONF_THRESHOLD

end # module LobeOrchestrator
