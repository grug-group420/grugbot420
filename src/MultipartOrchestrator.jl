# =============================================================================
# MultipartOrchestrator.jl — coordinates grouped votes for multipart responses
# =============================================================================
#
# GRUG v7.17+: When InputDecomposer splits a compound input into clauses,
# each clause produces its own set of votes. The MultipartOrchestrator:
#
#   1. Groups votes by objective_id (all votes sharing an objective_id
#      belong to the same compound question)
#   2. Provides scoped_mission text per group (the sub-subject text,
#      not the full compound input) so arithmetic doesn't bleed
#   3. Selects the top vote per group as each group's "voice"
#   4. Returns a MultipartResult that AIML can iterate over to build
#      a coherent composite response
#
# The key insight: votes with objective_id=0x0 are singletons (not from
# a compound input) and pass through unchanged. Only votes with
# objective_id > 0 and bundle_role ≠ :singleton are grouped.

module MultipartOrchestrator

export MultipartGroup, MultipartResult, orchestrate_multipart, scoped_mission_for_group

# =============================================================================
# DATA STRUCTURES
# =============================================================================

struct MultipartGroup
    objective_id::UInt64              # shared objective_id
    votes::Vector{Any}                 # all votes in this group (untyped to avoid using-cycle)
    scoped_mission::String            # the sub-subject text for this group
    primary_vote::Any                 # highest-confidence vote (untyped)
    is_math::Bool                     # true if any vote has math payload
    is_multipart::Bool                # true if this is a multipart group (vs singleton)
end

struct MultipartResult
    groups::Vector{MultipartGroup}    # ordered groups (original clause order)
    singleton_votes::Vector{Any}     # ungrouped singleton votes (pass-through)
    n_clauses::Int                    # number of clauses in original input
end

# =============================================================================
# CORE LOGIC
# =============================================================================

"""
    orchestrate_multipart(votes, clauses) → MultipartResult

Group votes by objective_id and associate each group with its clause text.
Votes with objective_id=0x0 or bundle_role=:singleton are singletons and
pass through unchanged.

`clauses` is a Vector of InputDecomposer.DecomposedClause (we access
.text and .index by duck-typing to avoid a using-cycle).
"""
function orchestrate_multipart(votes, clauses)::MultipartResult
    # GRUG: separate grouped votes from singletons.
    grouped = Dict{UInt64, Vector{Any}}()   # objective_id → votes
    singletons = Vector{Any}()

    for v in votes
        # GRUG: access fields by duck-typing (Vote has .objective_id, .bundle_role).
        obj_id = getfield(v, :objective_id)
        role = getfield(v, :bundle_role)

        if obj_id == UInt64(0) || role == :singleton
            push!(singletons, v)
        else
            if !haskey(grouped, obj_id)
                grouped[obj_id] = Any[]
            end
            push!(grouped[obj_id], v)
        end
    end

    # GRUG: build MultipartGroup for each objective_id.
    groups = MultipartGroup[]

    for (obj_id, grp_votes) in grouped
        # GRUG: sort by confidence descending to find primary.
        sorted = sort(grp_votes; by = v -> getfield(v, :confidence), rev = true)
        primary = sorted[1]

        # GRUG: determine scoped_mission text.
        # For multipart votes, the payload of each companion vote IS the
        # sub-subject text (InputDecomposer clause text stored in payload).
        # For math votes, scoped_mission = the full math expression.
        scoped = _infer_scoped_mission(grp_votes, clauses)

        # GRUG: detect math group (any vote with :step_n or :final role).
        is_math = any(v -> getfield(v, :bundle_role) in (:step_n, :final), grp_votes)

        # GRUG: detect multipart (has :companion votes).
        is_multipart = any(v -> getfield(v, :bundle_role) == :companion, grp_votes)

        push!(groups, MultipartGroup(
            obj_id, grp_votes, scoped, primary, is_math, is_multipart
        ))
    end

    # GRUG: sort groups by the index of their primary vote's clause text
    # matching against clause texts (preserve original order).
    # For now, just sort by objective_id which is monotonically increasing.
    sort!(groups; by = g -> g.objective_id)

    n_clauses = isempty(clauses) ? 1 : length(clauses)

    return MultipartResult(groups, singletons, n_clauses)
end

"""
    scoped_mission_for_group(group::MultipartGroup) → String

Return the scoped_mission text for a group — the sub-subject text that
should be used for COMMANDS handlers instead of the full compound input.
"""
function scoped_mission_for_group(group::MultipartGroup)::String
    return group.scoped_mission
end

# =============================================================================
# INTERNAL HELPERS
# =============================================================================

# GRUG: infer scoped_mission from votes + clauses.
# For companion votes, the payload IS the clause text.
# For math votes, we reconstruct from step payloads.
# For singleton groups, fall back to the primary vote's node context.
function _infer_scoped_mission(grp_votes, clauses)::String
    # GRUG: check for companion votes — their payload is the clause text.
    companions = filter(v -> getfield(v, :bundle_role) == :companion, grp_votes)
    if !isempty(companions)
        # GRUG: join all companion payloads (there may be multiple for
        # the same objective_id if the same node fires on multiple clauses).
        parts = [getfield(c, :payload) for c in companions if !isempty(getfield(c, :payload))]
        if !isempty(parts)
            return strip(join(parts, " ")) |> String
        end
    end

    # GRUG: check for math votes — reconstruct the expression.
    math_votes = filter(v -> getfield(v, :bundle_role) in (:step_n, :final), grp_votes)
    if !isempty(math_votes)
        # GRUG: the final vote's payload is the answer. Step payloads
        # carry "lhs op rhs = result". For scoped_mission we just need
        # the question, not the answer — but we don't have the original
        # question text here. Fall back to first step or final payload.
        final_v = findfirst(v -> getfield(v, :bundle_role) == :final, math_votes)
        if !isnothing(final_v)
            return getfield(math_votes[final_v], :payload) |> String
        end
        # fallback: first step
        return getfield(first(math_votes), :payload) |> String
    end

    # GRUG: no clause or math info — return a generic marker.
    return "(multipart scope)"
end

end # module MultipartOrchestrator
