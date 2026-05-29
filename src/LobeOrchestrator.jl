module LobeOrchestrator

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
#      Score: lobe_score = base_avg * top_avg     (the "curve")
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

# --- Tunables ----------------------------------------------------------------
const HARD_FIRE_BATCH_CAP           = 1000
const MIN_PASS_THROUGH_SCORE        = 0.10
const MIN_WINNING_VOTES_PER_LOBE    = 2
const TOP_K_FRACTION                = 0.5
const HARD_SELECTION_CONF_THRESHOLD = 0.5

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
    LAST_LOBE_SCORES[] = Tuple{String, Float64, Float64, Float64, Int}[]
    LAST_WINNER[]      = ""
    LAST_PASSTHROUGH[] = String[]
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
  score    = base_avg * top_avg                     <-- the curve
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

    # GRUG: PEAK-DOMINATED LOBE FIX.
    # The averages curve (base_avg * top_avg) penalizes lobes that have one
    # overwhelmingly strong node alongside weak siblings — the weak ones drag
    # the average down even when the peak is decisive (e.g. node_88 scoring
    # 0.949 alongside two 0.17 cousins gets averaged to ~0.4, losing to a
    # consensus-mid lobe with three nodes at 0.6). We take max(curve, peak^2)
    # so a single dominating node lifts its lobe to its peak's geometric tier.
    # Squaring keeps the score on the same scale as base*top (both ∈ [0,1]),
    # and the max() guarantees consensus lobes still win when their curve is
    # higher than any singleton peak elsewhere.
    peak = sorted[1]
    curve = base_avg * top_avg
    score = max(curve, peak * peak)

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

        # GRUG: FUZZY WHITELIST VETO!
        # If this lobe has a non-empty subject_whitelist and none of the
        # input_tokens match, force score=0. This prevents misfiring lobes —
        # e.g. "What is the quadratic formula" can't win the conversation lobe
        # because the conversation lobe's whitelist only has greeting/meta tokens.
        # Empty whitelist = no gate (backward compatible). Empty input_tokens = no gate.
        if !isempty(input_tokens) && score > 0.0 && lobe_id != "-"
            can_accept = try
                # GRUG: Reach the Lobe module through the parent of lobe_lookup.
                # lobe_lookup is Lobe.find_lobe_for_node, so its parent module
                # is the Lobe module itself. We call lobe_can_accept_subject directly.
                lobe_lookup_mod = typeof(lobe_lookup).name.module
                if isdefined(lobe_lookup_mod, :lobe_can_accept_subject)
                    lobe_lookup_mod.lobe_can_accept_subject(lobe_id, input_tokens)
                elseif isdefined(lobe_lookup_mod, :Lobe) && isdefined(lobe_lookup_mod.Lobe, :lobe_can_accept_subject)
                    lobe_lookup_mod.Lobe.lobe_can_accept_subject(lobe_id, input_tokens)
                else
                    # Fallback: try Main.Lobe directly
                    Main.Lobe.lobe_can_accept_subject(lobe_id, input_tokens)
                end
            catch e
                # GRUG: Whitelist check failed — don't veto on error, but warn.
                @warn "[LOBE_ORCHESTRATOR] Whitelist check error for lobe '$lobe_id': $e — defaulting to accept"
                true
            end
            if !can_accept
                # GRUG: WHITELIST VETO — this lobe is NOT allowed to win for this input!
                # Force score to 0 so it can't win or pass through.
                score = 0.0
            end
        end

        push!(scored, (lobe_id, base_avg, top_avg, score, hard_count, lobe_entries))
        push!(LAST_LOBE_SCORES[], (lobe_id, base_avg, top_avg, score, hard_count))
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
        LAST_WINNER[] = out[1].lobe_id
        LAST_PASSTHROUGH[] = [o.lobe_id for o in out if o.is_passthrough]
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
    if isempty(LAST_LOBE_SCORES[])
        return "Lobe Curve: (no lobes scored)"
    end
    lines = String["Lobe Curve (base × top = score):"]
    # Sort scores desc for the readout
    sorted = sort(LAST_LOBE_SCORES[]; by = x -> -x[4])
    for (lobe_id, base_avg, top_avg, score, hard_count) in sorted
        marker = if lobe_id == LAST_WINNER[]
            "👑"
        elseif lobe_id in LAST_PASSTHROUGH[]
            "↗"
        else
            "·"
        end
        veto_tag = if score == 0.0 && base_avg > 0.0
            " 🚫whitelist-veto"
        else
            ""
        end
        push!(lines, "  $marker $lobe_id: base=$(round(base_avg, digits=3)) " *
                     "× top=$(round(top_avg, digits=3)) = $(round(score, digits=4)) " *
                     "[hard_votes=$hard_count]$veto_tag")
    end
    return join(lines, "\n")
end

# --- Exports -----------------------------------------------------------------
export LobeFireOrder
export score_lobes, flatten_in_fire_order, compute_fire_batches
export reset_telemetry!, last_summary
export LAST_LOBE_SCORES, LAST_WINNER, LAST_PASSTHROUGH
export HARD_FIRE_BATCH_CAP, MIN_PASS_THROUGH_SCORE,
       MIN_WINNING_VOTES_PER_LOBE, TOP_K_FRACTION,
       HARD_SELECTION_CONF_THRESHOLD

end # module LobeOrchestrator
