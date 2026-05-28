# ==============================================================================
# MultipartOrchestrator.jl — v7.23 Multipart Vote Coalescing
# ==============================================================================
# GRUG say: AIML always get many votes. Old way — many rocks, many opinions,
#           AIML pick top tier and coinflip the rest. That fine when each rock
#           talk about its OWN thing. But sometimes one smart rock split its
#           thought into PIECES — "answer is X, also Y, also Z, all parts of
#           SAME idea". Old AIML treat X, Y, Z as competing rocks. Wrong! They
#           are PARTS. Same objective.
#
# GRUG say: this module group votes by `multipart_group` field. Empty group =
#           singleton, wraps to one-vote objective so downstream code sees
#           uniform shape. Non-empty group = collect, pick :primary as the
#           locked-in claim, partition :supports into locked vs unsure under
#           the SAME objective.
#
# GRUG say: lock vs unsure WITHIN a multipart group is *internal structure*,
#           not competing alternatives. AIML emits one cohesive answer per
#           group with sure parts and noted-unsure parts.
# ==============================================================================
#
# ACADEMIC: This module sits between the BrainStem vote stream and the AIML
# orchestrator. It performs a partition of the incoming Vote vector into
# objectives — one per multipart group plus one per singleton. Within a
# multipart group, the unique :primary vote is the locked-in claim and is
# never coinflipped. Supports are partitioned into the historical
# (top_window, sub-top, rejected) tiers, but ALL kept supports remain
# associated with the same objective rather than competing as separate
# answers. The orchestrator is intentionally a pure function over the
# candidate vector; it owns no state and emits no side effects.
#
# Backward compatibility: any vote whose multipart_group is "" maps to a
# one-element MultipartObjective with no supports. This is the historical
# case and produces output equivalent to the old top/subtop pipeline.
# ==============================================================================

module MultipartOrchestrator

using ..VoteOrchestrator: AIML_CONFIDENCE_THRESHOLD, AIML_TOP_TIER_WINDOW,
                          AIML_SUBTOP_BASE_PROB, AIML_SUBTOP_BONUS_PROB

export MultipartObjective, MultipartError
export group_votes_by_multipart, build_objectives, summarize_objective

# ==============================================================================
# ERRORS — NO SILENT FAILURES
# ==============================================================================

struct MultipartError <: Exception
    message::String
    context::String
end

@inline _throw(msg::String, ctx::String) = throw(MultipartError(msg, ctx))

# ==============================================================================
# OBJECTIVE STRUCT
# ==============================================================================

"""
A `MultipartObjective` is one cohesive thing AIML must answer. For a singleton
vote, `primary` is the vote and both support vectors are empty. For a
multipart group, `primary` is the unique :primary-role vote (the locked claim)
and the support vectors carry the other parts partitioned by AIML tier.

Fields:
  group_id          — "" for singletons, the shared group key otherwise.
  primary           — the locked-in vote (always present).
  locked_supports   — supports within `top_window` of primary's confidence.
                      They are stated alongside primary, no coinflip.
  unsure_supports   — supports below the lock window but above threshold;
                      they SURVIVED the strength-biased coinflip and are
                      noted as "also possibly" parts of the same objective.
  is_multipart      — Bool; true iff group_id != "".
"""
struct MultipartObjective
    group_id::String
    primary::Any                 # ::Vote, kept abstract to avoid module cycles
    locked_supports::Vector
    unsure_supports::Vector
    is_multipart::Bool
end

# ==============================================================================
# GROUPING
# ==============================================================================

"""
    group_votes_by_multipart(votes) -> (singletons, groups)

Pure partition. `singletons` is a Vector of votes whose multipart_group is "".
`groups` is a Dict keyed by non-empty group_id mapping to the votes carrying
that id. No mutation of the input. No coinflips here — this is shape work
only.
"""
function group_votes_by_multipart(votes::AbstractVector)
    singletons = eltype(votes)[]
    groups     = Dict{String, Vector{eltype(votes)}}()
    for v in votes
        gid = getfield(v, :multipart_group)
        if isempty(gid)
            push!(singletons, v)
        else
            push!(get!(groups, gid, eltype(votes)[]), v)
        end
    end
    return singletons, groups
end

# ==============================================================================
# OBJECTIVE CONSTRUCTION
# ==============================================================================

"""
    _strength_biased_coin(strength, cap) -> Bool

GRUG: same shape as VoteOrchestrator's coinflip. Strong nodes more likely
to keep an unsure support. We re-implement here instead of importing the
typed VoteCandidate version because supports are already raw votes.
"""
function _strength_biased_coin(strength::Float64, cap::Float64)::Bool
    p = AIML_SUBTOP_BASE_PROB + (strength / cap) * AIML_SUBTOP_BONUS_PROB
    return rand() < clamp(p, 0.0, 1.0)
end

"""
    _objective_from_singleton(vote) -> MultipartObjective
"""
function _objective_from_singleton(v)
    return MultipartObjective("", v, Any[], Any[], false)
end

"""
    _objective_from_group(group_id, group_votes; threshold, top_window, strength_of)

Build a single objective from a multipart group. Required structure:
  - exactly one vote with role == :primary
  - zero or more votes with role == :support

`strength_of` is a callable (vote -> Float64) so the orchestrator does not
have to know how strength is stored on the underlying Node — caller
provides the lookup.
"""
function _objective_from_group(group_id::String, gvotes::AbstractVector;
                               threshold::Float64 = AIML_CONFIDENCE_THRESHOLD,
                               top_window::Float64 = AIML_TOP_TIER_WINDOW,
                               strength_of::Function = _ -> 5.0,
                               strength_cap::Float64 = 10.0)
    if isempty(gvotes)
        _throw("multipart group '$group_id' has zero votes", "_objective_from_group")
    end

    primaries = [v for v in gvotes if getfield(v, :multipart_role) === :primary]
    supports  = [v for v in gvotes if getfield(v, :multipart_role) === :support]
    others    = [v for v in gvotes if !(getfield(v, :multipart_role) in (:primary, :support))]

    if !isempty(others)
        roles = unique(getfield.(others, :multipart_role))
        _throw("multipart group '$group_id' has votes with disallowed roles $(roles); allowed roles: :primary, :support",
               "_objective_from_group")
    end
    if length(primaries) != 1
        _throw("multipart group '$group_id' must have exactly one :primary vote, got $(length(primaries))",
               "_objective_from_group")
    end

    primary  = primaries[1]
    pri_conf = getfield(primary, :confidence)

    # Below threshold supports are dropped (they don't reach AIML at all).
    surviving = [s for s in supports if getfield(s, :confidence) >= threshold]

    locked = eltype(supports)[]
    unsure = eltype(supports)[]
    for s in surviving
        sc = getfield(s, :confidence)
        if sc >= pri_conf - top_window
            push!(locked, s)
        else
            # strength-biased coinflip; survivors become "noted" unsure parts
            str = strength_of(s)
            if _strength_biased_coin(str, strength_cap)
                push!(unsure, s)
            end
            # losers vanish — same semantics as old sub-top rejection
        end
    end

    return MultipartObjective(group_id, primary, Any[s for s in locked],
                              Any[s for s in unsure], true)
end

"""
    build_objectives(votes; threshold, top_window, strength_of, strength_cap)
        -> Vector{MultipartObjective}

Top-level entry. Partitions votes, builds one objective per singleton and
one objective per multipart group. Singletons are emitted in input order;
multipart objectives follow, sorted by group_id for deterministic output
(individual tie-breaking inside groups is still stochastic by design).

Throws MultipartError if any group is malformed (zero or >1 :primary, or
votes with unknown roles). Never silently drops a multipart group.
"""
function build_objectives(votes::AbstractVector;
                          threshold::Float64    = AIML_CONFIDENCE_THRESHOLD,
                          top_window::Float64   = AIML_TOP_TIER_WINDOW,
                          strength_of::Function = _ -> 5.0,
                          strength_cap::Float64 = 10.0)::Vector{MultipartObjective}
    singletons, groups = group_votes_by_multipart(votes)
    out = MultipartObjective[]
    for v in singletons
        push!(out, _objective_from_singleton(v))
    end
    for gid in sort(collect(keys(groups)))
        push!(out, _objective_from_group(gid, groups[gid];
                                         threshold = threshold,
                                         top_window = top_window,
                                         strength_of = strength_of,
                                         strength_cap = strength_cap))
    end
    return out
end

# ==============================================================================
# DIAGNOSTIC PRINTING
# ==============================================================================

"""
    summarize_objective(obj) -> String

One-line human-readable summary. Used by AIML scaffold + test diagnostics.
"""
function summarize_objective(obj::MultipartObjective)::String
    p = obj.primary
    pid    = getfield(p, :node_id)
    pact   = getfield(p, :action)
    pconf  = getfield(p, :confidence)
    head   = obj.is_multipart ?
        "[multipart $(obj.group_id)] primary=$(pact)@$(round(pconf, digits=3)) by $(pid)" :
        "[singleton] $(pact)@$(round(pconf, digits=3)) by $(pid)"
    locked_part = isempty(obj.locked_supports) ? "" :
        " | locked=" * join([getfield(s, :action) for s in obj.locked_supports], ",")
    unsure_part = isempty(obj.unsure_supports) ? "" :
        " | unsure=" * join([getfield(s, :action) for s in obj.unsure_supports], ",")
    return head * locked_part * unsure_part
end

end # module
