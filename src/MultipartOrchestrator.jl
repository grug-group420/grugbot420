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
export group_votes_by_multipart, group_votes_by_chunks, build_objectives, summarize_objective

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
# CHUNK-AWARE GROUPING (v7.23 chunked affinities)
# ==============================================================================

#=
    _union_find_root(parent, x) -> Int

Find the root of x in a union-find structure. Path compression
for amortized near-constant time.
=#
function _union_find_root(parent::Dict{Int, Int}, x::Int)::Int
    while parent[x] != x
        parent[x] = parent[parent[x]]   # path compression
        x = parent[x]
    end
    return x
end

#=
    _union_find_union!(parent, rank, a, b)

Union two sets in the union-find structure. Union by rank
for balanced trees.
=#
function _union_find_union!(parent::Dict{Int, Int}, rank::Dict{Int, Int},
                            a::Int, b::Int)
    ra = _union_find_root(parent, a)
    rb = _union_find_root(parent, b)
    ra == rb && return nothing
    if rank[ra] < rank[rb]
        ra, rb = rb, ra
    end
    parent[rb] = ra
    rank[ra] == rank[rb] && (rank[ra] += 1)
    return nothing
end

#=
    _connected_components(edges) -> Vector{Vector{Int}}

Given a vector of (Set of Int), compute connected components using
union-find. Each edge is a set of chunk indices that overlap.
Returns groups of chunk indices that are transitively connected.
=#
function _connected_components(chunk_sets::Vector{Set{Int}})::Vector{Vector{Int}}
    isempty(chunk_sets) && return Vector{Int}[]

    # Collect all unique chunk indices
    all_chunks = Set{Int}()
    for cs in chunk_sets
        union!(all_chunks, cs)
    end
    isempty(all_chunks) && return Vector{Int}[]

    # Initialize union-find
    parent = Dict{Int, Int}(c => c for c in all_chunks)
    rank   = Dict{Int, Int}(c => 0 for c in all_chunks)

    # Union all chunks within each chunk set
    for cs in chunk_sets
        arr = collect(cs)
        for i in 2:length(arr)
            _union_find_union!(parent, rank, arr[1], arr[i])
        end
    end

    # Collect components
    components = Dict{Int, Vector{Int}}()
    for c in all_chunks
        root = _union_find_root(parent, c)
        push!(get!(components, root, Int[]), c)
    end

    return collect(values(components))
end

"""
    group_votes_by_chunks(votes) -> (singletons, groups)

GRUG: Old way group by multipart_group string. New way: when vote know which
chunk of input it resolved (input_chunks non-empty), group by CHUNK OVERLAP.
Two votes covering chunks [1,2] and [2,3] share chunk 2 — they are in the
SAME group because they talk about the same part of the input. That is the
place-cell way: cell fires for a LOCATION, not "the environment."

Algorithm:
  1. Partition votes into chunked (non-empty input_chunks) and unchunked.
  2. Among chunked votes: compute connected components via union-find on
     chunk overlap. Two votes are connected if their input_chunks share
     any chunk index. Transitive closure means [1,2] + [2,3] + [3,4] all
     land in one group even though the first and last share no chunk directly.
  3. Each component becomes a group. group_id = "chk_{sorted_chunks_joined}".
  4. Unchunked votes fall back to the old multipart_group grouping.
  5. Singletons are votes with no group (empty input_chunks AND empty
     multipart_group).

The group_id format differs from old "mp_X" to make it easy to distinguish
chunk-derived groups from decomposer-derived groups: "chk_1_2_3" vs "mp_1".
"""
function group_votes_by_chunks(votes::AbstractVector)
    chunked   = eltype(votes)[]   # votes with non-empty input_chunks
    unchunked = eltype(votes)[]   # votes without input_chunks

    for v in votes
        ic = getfield(v, :input_chunks)
        if !isempty(ic)
            push!(chunked, v)
        else
            push!(unchunked, v)
        end
    end

    # --- Chunked votes: connected components by chunk overlap ---
    chunk_groups = Dict{String, Vector{eltype(votes)}}()

    if !isempty(chunked)
        # Collect the chunk sets for connected-component computation
        chunk_sets = [Set(getfield(v, :input_chunks)) for v in chunked]
        components = _connected_components(chunk_sets)

        # Map each component to a group_id, then assign votes
        for comp in components
            sorted = sort(comp)
            gid = "chk_" * join(sorted, "_")
            chunk_groups[gid] = eltype(votes)[]
        end

        # Assign each chunked vote to its component's group
        for (i, v) in enumerate(chunked)
            v_chunks = getfield(v, :input_chunks)
            # Find which component this vote belongs to
            assigned = false
            for (gid, _) in chunk_groups
                # Extract chunk indices from group_id: "chk_1_2_3" -> [1,2,3]
                gid_chunks = Set(parse.(Int, split(gid[5:end], "_")))
                # Vote belongs to this group if any of its chunks are in the component
                if !isempty(intersect(Set(v_chunks), gid_chunks))
                    push!(chunk_groups[gid], v)
                    assigned = true
                    break
                end
            end
            if !assigned
                # Should never happen if components are computed correctly,
                # but as safety: make a group from the vote's own chunks
                sorted = sort(v_chunks)
                gid = "chk_" * join(sorted, "_")
                if !haskey(chunk_groups, gid)
                    chunk_groups[gid] = eltype(votes)[v]
                else
                    push!(chunk_groups[gid], v)
                end
            end
        end
    end

    # --- Unchunked votes: fall back to multipart_group grouping ---
    singletons = eltype(votes)[]
    mp_groups  = Dict{String, Vector{eltype(votes)}}()

    for v in unchunked
        gid = getfield(v, :multipart_group)
        if isempty(gid)
            push!(singletons, v)
        else
            push!(get!(mp_groups, gid, eltype(votes)[]), v)
        end
    end

    # Merge chunk-derived groups with multipart-derived groups.
    # Chunk-derived groups take precedence if there's a key collision
    # (unlikely since "chk_X" vs "mp_X" naming differs, but be safe).
    all_groups = merge(mp_groups, chunk_groups)

    return singletons, all_groups
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

# ==============================================================================
# CHUNK-DERIVED OBJECTIVE CONSTRUCTION
# ==============================================================================

#=
    _reassign_roles!(group_votes) -> (primary, supports)

GRUG v7.23: When grouping by chunk overlap, all chunked votes carry :primary
role (because cast_vote_chunked always stamps :primary). But an objective
needs exactly ONE primary. So: pick the highest-confidence vote as primary,
the rest become supports. Their original :primary role is preserved in the
vote's own data — we just change how the objective treats them.

This is the chunked-affinities way: the GROUP is determined by chunk overlap
(not by a decomposer tag), and the primary is determined by confidence
(not by a role assigned at cast time).
=#
function _reassign_roles!(gvotes::AbstractVector)
    if isempty(gvotes)
        _throw("chunk group has zero votes", "_reassign_roles!")
    end

    # Find the highest-confidence vote. Ties broken by first occurrence.
    best_idx = 1
    best_conf = getfield(gvotes[1], :confidence)
    for i in 2:length(gvotes)
        c = getfield(gvotes[i], :confidence)
        if c > best_conf
            best_conf = c
            best_idx = i
        end
    end

    primary = gvotes[best_idx]
    supports = [gvotes[i] for i in 1:length(gvotes) if i != best_idx]
    return primary, supports
end

"""
    _objective_from_chunk_group(group_id, group_votes; threshold, top_window, strength_of, strength_cap)

Build an objective from a chunk-derived group. Unlike `_objective_from_group`
(which expects exactly one :primary vote from the decomposer path), this
function handles the case where all votes carry :primary (because
cast_vote_chunked stamps them that way). It reassigns roles: highest-
confidence vote becomes the objective's primary, the rest become supports.

The rest of the logic (locked vs unsure partitioning) is the same as
`_objective_from_group`.
"""
function _objective_from_chunk_group(group_id::String, gvotes::AbstractVector;
                                     threshold::Float64 = AIML_CONFIDENCE_THRESHOLD,
                                     top_window::Float64 = AIML_TOP_TIER_WINDOW,
                                     strength_of::Function = _ -> 5.0,
                                     strength_cap::Float64 = 10.0)
    if isempty(gvotes)
        _throw("chunk group '$group_id' has zero votes", "_objective_from_chunk_group")
    end

    # Single vote in group: it's the primary, no supports needed.
    if length(gvotes) == 1
        return MultipartObjective(group_id, gvotes[1], Any[], Any[], true)
    end

    # Reassign roles: highest confidence = primary, rest = supports.
    primary, supports = _reassign_roles!(gvotes)
    pri_conf = getfield(primary, :confidence)

    # Below-threshold supports are dropped.
    surviving = [s for s in supports if getfield(s, :confidence) >= threshold]

    locked = eltype(supports)[]
    unsure = eltype(supports)[]
    for s in surviving
        sc = getfield(s, :confidence)
        if sc >= pri_conf - top_window
            push!(locked, s)
        else
            str = strength_of(s)
            if _strength_biased_coin(str, strength_cap)
                push!(unsure, s)
            end
        end
    end

    return MultipartObjective(group_id, primary, Any[s for s in locked],
                              Any[s for s in unsure], true)
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
one objective per multipart group. When any votes carry non-empty
`input_chunks`, uses `group_votes_by_chunks` (chunk-overlap connected
components) instead of the legacy `group_votes_by_multipart`. This is the
chunked-affinities path: votes that know which part of the input they
resolved are grouped by shared chunk overlap, not by the decomposer's
multipart_group tag.

Singletons are emitted in input order; multipart objectives follow, sorted
by group_id for deterministic output (individual tie-breaking inside groups
is still stochastic by design).

Throws MultipartError if any group is malformed (zero or >1 :primary, or
votes with unknown roles). Never silently drops a multipart group.
"""
function build_objectives(votes::AbstractVector;
                          threshold::Float64    = AIML_CONFIDENCE_THRESHOLD,
                          top_window::Float64   = AIML_TOP_TIER_WINDOW,
                          strength_of::Function = _ -> 5.0,
                          strength_cap::Float64 = 10.0)::Vector{MultipartObjective}
    # GRUG v7.23: If any vote has chunk info, use chunk-aware grouping.
    # Otherwise fall back to old multipart_group grouping. Chunk-aware
    # grouping uses connected components on chunk overlap — two votes
    # that touch the same input chunk are in the same group.
    has_chunks = any(v -> !isempty(getfield(v, :input_chunks)), votes)

    singletons, groups = if has_chunks
        group_votes_by_chunks(votes)
    else
        group_votes_by_multipart(votes)
    end

    out = MultipartObjective[]
    for v in singletons
        push!(out, _objective_from_singleton(v))
    end
    for gid in sort(collect(keys(groups)))
        # GRUG v7.23: Chunk-derived groups ("chk_*") use their own objective
        # builder that handles multi-primary votes from cast_vote_chunked.
        # Legacy multipart groups ("mp_*") use the original builder that
        # expects exactly one :primary from the decomposer.
        if startswith(gid, "chk_")
            push!(out, _objective_from_chunk_group(gid, groups[gid];
                                             threshold = threshold,
                                             top_window = top_window,
                                             strength_of = strength_of,
                                             strength_cap = strength_cap))
        else
            push!(out, _objective_from_group(gid, groups[gid];
                                             threshold = threshold,
                                             top_window = top_window,
                                             strength_of = strength_of,
                                             strength_cap = strength_cap))
        end
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
    pchunks = getfield(p, :input_chunks)
    chunk_str = isempty(pchunks) ? "" : " chunks=$(pchunks)"
    head   = obj.is_multipart ?
        "[multipart $(obj.group_id)] primary=$(pact)@$(round(pconf, digits=3)) by $(pid)$(chunk_str)" :
        "[singleton] $(pact)@$(round(pconf, digits=3)) by $(pid)$(chunk_str)"
    locked_part = isempty(obj.locked_supports) ? "" :
        " | locked=" * join([getfield(s, :action) for s in obj.locked_supports], ",")
    unsure_part = isempty(obj.unsure_supports) ? "" :
        " | unsure=" * join([getfield(s, :action) for s in obj.unsure_supports], ",")
    return head * locked_part * unsure_part
end

end # module
