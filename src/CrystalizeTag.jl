# CrystalizeTag.jl
# ==============================================================================
# GRUG v7.15 - CRYSTALIZE TAG FOR NODE-ATTACH / AUTO-CRYSTALIZER
# ==============================================================================
# GRUG: A node can be CRYSTALIZED. When an attached-node is crystalized, its
# relay fire is not subject to the coinflip --- it ALWAYS fires. The tag has
# two origins:
#
#   1. USER-DEFINED: the operator marks a node crystalized via a CLI command
#      (hooked up in Main.jl to /crystalize <node_id>).
#
#   2. AUTO-CRYSTALIZER: a strong node (strength >= AUTO_STRENGTH_FLOOR) that
#      accumulates a high average semantic-truth score on its relational
#      matches (>= AUTO_SEMANTIC_FLOOR) is auto-promoted to crystalized.
#      Auto-crystalization is revocable: if the node's strength drops below
#      AUTO_STRENGTH_FLOOR, the tag is cleared on the next maintenance pass.
#
# The tag itself is a simple Set{String} of node_ids, protected by a lock.
# The auto-crystalizer logic is exposed as a pure function that takes
# (strength, avg_semantic_truth) and returns Bool --- easy to test, easy
# to call from the phagy maintenance loop.
#
# NO SILENT FAILURES: empty node ids and re-clears-on-unknown are caught.
# ==============================================================================

module CrystalizeTag

using Base.Threads: ReentrantLock

export CrystalizeError
export crystalize!, uncrystalize!, is_crystalized, list_crystalized
export mark_user_crystalized!, mark_auto_crystalized!, is_auto_crystalized
export clear_all_crystalized!, crystalized_count
export should_auto_crystalize, AUTO_STRENGTH_FLOOR, AUTO_SEMANTIC_FLOOR
export AUTO_STRENGTH_RELEASE_FLOOR

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Auto-crystalizer thresholds. Strength is on the usual [0, 10] range.
# Average semantic truth is expected in [0, 1] (see Thesaurus / SemanticVerbs).
const AUTO_STRENGTH_FLOOR        = 7.5   # promote: must be this strong or stronger
const AUTO_SEMANTIC_FLOOR        = 0.70  # promote: avg semantic truth >= this
# GRUG: Release floor is lower than promote floor to avoid chattering around
# the edge of the promote threshold (hysteresis).
const AUTO_STRENGTH_RELEASE_FLOOR = 6.0

# ==============================================================================
# ERROR TYPE
# ==============================================================================

struct CrystalizeError <: Exception
    message::String
    context::String
end

Base.showerror(io::IO, e::CrystalizeError) =
    print(io, "CrystalizeError[", e.context, "]: ", e.message)

_throw(msg::String, ctx::String) = throw(CrystalizeError(msg, ctx))

# ==============================================================================
# REGISTRY (two sets: user + auto, same privilege at fire time)
# ==============================================================================

const _USER_CRYSTALIZED = Set{String}()
const _AUTO_CRYSTALIZED = Set{String}()
const _CRYSTALIZE_LOCK  = ReentrantLock()

"""
    mark_user_crystalized!(node_id)

GRUG: Operator-issued crystalization. Overlapping with auto is fine: a node
present in both sets remains crystalized until BOTH sets release it.
"""
function mark_user_crystalized!(node_id::String)
    isempty(strip(node_id)) && _throw("empty node_id", "mark_user_crystalized!")
    lock(_CRYSTALIZE_LOCK) do
        push!(_USER_CRYSTALIZED, node_id)
    end
    return nothing
end

"""
    mark_auto_crystalized!(node_id)

GRUG: Auto-crystalizer promotion. Called by the maintenance pass (phagy) when
a node passes both strength and semantic-truth gates.
"""
function mark_auto_crystalized!(node_id::String)
    isempty(strip(node_id)) && _throw("empty node_id", "mark_auto_crystalized!")
    lock(_CRYSTALIZE_LOCK) do
        push!(_AUTO_CRYSTALIZED, node_id)
    end
    return nothing
end

"""
    uncrystalize!(node_id; user=true, auto=true)

GRUG: Remove crystalize tags. By default clears both. Use kwargs to clear only
one origin (e.g. auto-maintenance should not yank a user-issued tag).
Idempotent: removing an un-tagged node is a no-op, not an error.
"""
function uncrystalize!(node_id::String; user::Bool = true, auto::Bool = true)
    isempty(strip(node_id)) && _throw("empty node_id", "uncrystalize!")
    lock(_CRYSTALIZE_LOCK) do
        user && delete!(_USER_CRYSTALIZED, node_id)
        auto && delete!(_AUTO_CRYSTALIZED, node_id)
    end
    return nothing
end

"""
    is_crystalized(node_id)::Bool

GRUG: True if node is in either set. Fire-path check uses this.
"""
function is_crystalized(node_id::String)::Bool
    isempty(strip(node_id)) && _throw("empty node_id", "is_crystalized")
    lock(_CRYSTALIZE_LOCK) do
        return (node_id in _USER_CRYSTALIZED) || (node_id in _AUTO_CRYSTALIZED)
    end
end

"""
    is_auto_crystalized(node_id)::Bool

GRUG: Specifically true if this node was auto-promoted. Used by the revocation
path so a phagy pass doesn't clear user-issued tags.
"""
function is_auto_crystalized(node_id::String)::Bool
    isempty(strip(node_id)) && _throw("empty node_id", "is_auto_crystalized")
    lock(_CRYSTALIZE_LOCK) do
        return node_id in _AUTO_CRYSTALIZED
    end
end

# GRUG: Public alias used by some CLI paths.
crystalize! = mark_user_crystalized!

"""
    list_crystalized()::Vector{String}

GRUG: Snapshot the union of both sets, sorted for stable output. Reference
semantics: caller gets a fresh vector, no lock leakage.
"""
function list_crystalized()::Vector{String}
    lock(_CRYSTALIZE_LOCK) do
        s = Set{String}()
        union!(s, _USER_CRYSTALIZED)
        union!(s, _AUTO_CRYSTALIZED)
        return sort!(collect(s))
    end
end

crystalized_count()::Int =
    lock(() -> length(_USER_CRYSTALIZED) + length(_AUTO_CRYSTALIZED),
         _CRYSTALIZE_LOCK)

"""
    clear_all_crystalized!()

GRUG: Test helper / admin reset. Wipes both sets.
"""
function clear_all_crystalized!()
    lock(_CRYSTALIZE_LOCK) do
        empty!(_USER_CRYSTALIZED)
        empty!(_AUTO_CRYSTALIZED)
    end
    return nothing
end

# ==============================================================================
# AUTO-CRYSTALIZER GATE (pure function, easy to test)
# ==============================================================================

"""
    should_auto_crystalize(strength::Float64, avg_semantic_truth::Float64;
                           already_auto::Bool = false)::Bool

GRUG: Decide whether a node qualifies for auto-crystalization.

Promote   when:  strength >= AUTO_STRENGTH_FLOOR  AND avg_semantic_truth >= AUTO_SEMANTIC_FLOOR
Maintain  when:  strength >= AUTO_STRENGTH_RELEASE_FLOOR AND already_auto == true
Release   when:  neither condition above holds

The function returns true to indicate the node SHOULD be auto-crystalized
after this evaluation. Callers translate:
  - was-auto but should-not: call uncrystalize!(node_id; user=false, auto=true)
  - was-not-auto but should: call mark_auto_crystalized!(node_id)

Throws on non-finite inputs --- a NaN strength in this function is a loud
symptom of a corrupted node record upstream.
"""
function should_auto_crystalize(
    strength::Float64,
    avg_semantic_truth::Float64;
    already_auto::Bool = false,
)::Bool
    if !isfinite(strength)
        _throw("non-finite strength: $strength", "should_auto_crystalize")
    end
    if !isfinite(avg_semantic_truth)
        _throw("non-finite avg_semantic_truth: $avg_semantic_truth",
               "should_auto_crystalize")
    end

    # GRUG: Clamp semantic truth to [0,1] interpretation.
    sem = clamp(avg_semantic_truth, 0.0, 1.0)

    if strength >= AUTO_STRENGTH_FLOOR && sem >= AUTO_SEMANTIC_FLOOR
        return true  # promote
    end

    # GRUG: Hysteresis --- stay crystalized while strength is between the
    # release floor and the promote floor, as long as semantic truth also
    # stays above the floor. This avoids chattering on/off at the boundary.
    if already_auto &&
       strength >= AUTO_STRENGTH_RELEASE_FLOOR &&
       sem >= AUTO_SEMANTIC_FLOOR
        return true  # maintain
    end

    return false     # release
end

end # module CrystalizeTag
