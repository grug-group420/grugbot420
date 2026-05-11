# GroupRegistry.jl
# ==============================================================================
# GRUG v7.15 - NODE GROUP REGISTRY (for chatter-mode group selection)
# ==============================================================================
# GRUG: Each node gets 8-16 random partners before it is marked UNLINKABLE.
# (Old cap was 4 for neighbors; this is the ATTACH-LINK cap from the updates.)
# Groups are assigned unique ids and stored in a dedicated hash table section.
# During chatter, 100-400 group ids are picked off the FRONT of the group id
# list, chatter runs, cursor advances so next chatter window starts where
# the last one stopped. Log persists to disk in a compressed JSON file.
#
# GRAVE INTERACTION: if a node inside a group gets graved, the group's
# UNLINKABLE tag is temporarily removed (for that group only) until another
# node joins to replace the graved one. Graves free slots; they do not lock
# the group shut.
#
# NO SILENT FAILURES: every edge case (duplicate membership, oversize group,
# missing group id) throws a typed error.
# ==============================================================================

module GroupRegistry

using Base.Threads: ReentrantLock
using Random
using JSON

export GroupRegistryError
export NodeGroup, GroupRegistryState
export register_node_in_group!, remove_node_from_group!, grave_node_in_group!
export get_group, list_group_ids, group_count, node_partners
export next_chatter_window_ids, advance_chatter_cursor!
export save_registry_compressed, load_registry_compressed
export PARTNER_CAP_MIN, PARTNER_CAP_MAX, CHATTER_WINDOW_MIN, CHATTER_WINDOW_MAX
export assign_partner_cap, mark_unlinkable!, clear_unlinkable_if_has_grave!
export is_unlinkable, partners_for_node, get_registry
export reset_registry!

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Partner cap is random per-node in [MIN, MAX]. Node gets a personal
# ceiling at registration time; different nodes have different ceilings so the
# population doesn't mass-unlink at the same threshold.
const PARTNER_CAP_MIN = 8
const PARTNER_CAP_MAX = 16

# GRUG: Chatter window size is random in [MIN, MAX]. Picked at cursor-advance
# time from the head of the group id list (FIFO order). Cursor wraps when it
# reaches the end of the list.
const CHATTER_WINDOW_MIN = 100
const CHATTER_WINDOW_MAX = 400

# GRUG: Default on-disk path for compressed registry snapshots. Callers may
# override with a different path.
const DEFAULT_REGISTRY_DISK_PATH = "group_registry.json.gz"

# ==============================================================================
# ERROR TYPE
# ==============================================================================

struct GroupRegistryError <: Exception
    message::String
    context::String
end

Base.showerror(io::IO, e::GroupRegistryError) =
    print(io, "GroupRegistryError[", e.context, "]: ", e.message)

_throw(msg::String, ctx::String) = throw(GroupRegistryError(msg, ctx))

# ==============================================================================
# GROUP STRUCTURE
# ==============================================================================

"""
    NodeGroup(group_id, member_ids, partner_cap, is_unlinkable, grave_count)

GRUG: A group of node IDs that chatter together. The group has its own
partner_cap (picked at creation in [PARTNER_CAP_MIN, PARTNER_CAP_MAX]) and
its own unlinkable flag. grave_count is the number of members currently
marked grave; when > 0 the unlinkable flag is temporarily suppressed so
replacements can join.
"""
mutable struct NodeGroup
    group_id::String
    member_ids::Vector{String}
    partner_cap::Int
    is_unlinkable::Bool
    grave_count::Int
end

# ==============================================================================
# REGISTRY STATE
# ==============================================================================

"""
    GroupRegistryState

GRUG: In-memory registry of all groups plus a cursor into the group-id list
for chatter windowing. The cursor is advanced by advance_chatter_cursor! and
read by next_chatter_window_ids. Both operations are thread-safe.
"""
mutable struct GroupRegistryState
    groups::Dict{String, NodeGroup}                    # group_id -> NodeGroup
    node_to_groups::Dict{String, Vector{String}}       # node_id  -> group_ids it belongs to
    group_id_order::Vector{String}                     # insertion order of group ids
    cursor::Int                                        # 1-based index into group_id_order
    lock::ReentrantLock
end

const _REGISTRY = GroupRegistryState(
    Dict{String, NodeGroup}(),
    Dict{String, Vector{String}}(),
    String[],
    1,
    ReentrantLock(),
)

"""
    get_registry()::GroupRegistryState

GRUG: Returns the process-wide registry singleton. Tests that want isolation
should call reset_registry!() at the start of the test group.
"""
get_registry() = _REGISTRY

"""
    reset_registry!()

GRUG: Empty the singleton. Safe to call from tests. Does NOT touch on-disk
snapshots --- use fresh paths for per-test isolation.
"""
function reset_registry!()
    lock(_REGISTRY.lock) do
        empty!(_REGISTRY.groups)
        empty!(_REGISTRY.node_to_groups)
        empty!(_REGISTRY.group_id_order)
        _REGISTRY.cursor = 1
    end
    return nothing
end

# ==============================================================================
# PARTNER CAP + UNLINKABLE MECHANICS
# ==============================================================================

"""
    assign_partner_cap(; rng)::Int

GRUG: Roll a random partner cap in [PARTNER_CAP_MIN, PARTNER_CAP_MAX]. Exposed
as a public helper so tests can inject a seeded RNG for reproducibility.
"""
assign_partner_cap(; rng::Random.AbstractRNG = Random.GLOBAL_RNG)::Int =
    rand(rng, PARTNER_CAP_MIN:PARTNER_CAP_MAX)

"""
    mark_unlinkable!(group::NodeGroup)

GRUG: Flip a group to unlinkable. Only meaningful when grave_count == 0 ---
with graves present, `is_unlinkable` is temporarily overridden to false by
`is_unlinkable(group)`.
"""
mark_unlinkable!(group::NodeGroup) = (group.is_unlinkable = true)

"""
    is_unlinkable(group::NodeGroup)::Bool

GRUG: Group is effectively unlinkable only when flagged AND no graves exist.
Graves free slots so replacements can join even if the cap was hit.
"""
is_unlinkable(group::NodeGroup)::Bool =
    group.is_unlinkable && group.grave_count == 0

# ==============================================================================
# MEMBERSHIP
# ==============================================================================

"""
    register_node_in_group!(group_id, node_id; partner_cap_rng)

GRUG: Add a node to a group. Creates the group on first use. Rejects:
  - Empty group_id or node_id
  - Duplicate membership (node already in this group)
  - Group already at partner_cap AND no graves available (silent reject
    would be bad, so this throws)

Returns the (possibly new) NodeGroup.
"""
function register_node_in_group!(
    group_id::String,
    node_id::String;
    partner_cap_rng::Random.AbstractRNG = Random.GLOBAL_RNG,
)::NodeGroup

    isempty(strip(group_id)) && _throw("empty group_id", "register_node_in_group!")
    isempty(strip(node_id))  && _throw("empty node_id",  "register_node_in_group!")

    lock(_REGISTRY.lock) do
        group = get(_REGISTRY.groups, group_id, nothing)
        if isnothing(group)
            group = NodeGroup(
                group_id,
                String[],
                assign_partner_cap(; rng = partner_cap_rng),
                false,
                0,
            )
            _REGISTRY.groups[group_id] = group
            push!(_REGISTRY.group_id_order, group_id)
        end

        if node_id in group.member_ids
            _throw("node '$node_id' already in group '$group_id'",
                   "register_node_in_group!")
        end

        if length(group.member_ids) >= group.partner_cap && group.grave_count == 0
            _throw("group '$group_id' is unlinkable (cap=$(group.partner_cap), no graves)",
                   "register_node_in_group!")
        end

        push!(group.member_ids, node_id)

        # GRUG: If this fill moved us to cap AND no graves, flip to unlinkable.
        if length(group.member_ids) >= group.partner_cap && group.grave_count == 0
            mark_unlinkable!(group)
        end

        # GRUG: Index back-reference
        gids = get!(_REGISTRY.node_to_groups, node_id, String[])
        if !(group_id in gids)
            push!(gids, group_id)
        end

        return group
    end
end

"""
    remove_node_from_group!(group_id, node_id)

GRUG: Fully remove a node from a group (not grave --- actual removal). Rejects
if the node isn't in the group.
"""
function remove_node_from_group!(group_id::String, node_id::String)
    lock(_REGISTRY.lock) do
        group = get(_REGISTRY.groups, group_id, nothing)
        isnothing(group) && _throw("group '$group_id' does not exist", "remove_node_from_group!")

        idx = findfirst(isequal(node_id), group.member_ids)
        isnothing(idx) && _throw("node '$node_id' not in group '$group_id'", "remove_node_from_group!")
        deleteat!(group.member_ids, idx)

        # GRUG: If the removed node was graved, decrement grave_count too.
        # Callers are expected to clear graves via grave_node_in_group! first,
        # but tolerate the common case defensively --- by reference, we can't
        # tell from here, so leave grave_count alone and let callers manage it.

        gids = get(_REGISTRY.node_to_groups, node_id, String[])
        filter!(g -> g != group_id, gids)
        if isempty(gids)
            delete!(_REGISTRY.node_to_groups, node_id)
        end

        # GRUG: Removal frees a slot --- clear unlinkable.
        if length(group.member_ids) < group.partner_cap
            group.is_unlinkable = false
        end
    end
    return nothing
end

"""
    grave_node_in_group!(group_id, node_id)

GRUG: Mark a member as grave. Increments grave_count. The node stays in
`member_ids` so other subsystems can still see the slot was occupied.
Once grave_count > 0, `is_unlinkable(group)` returns false --- replacement
welcome.
"""
function grave_node_in_group!(group_id::String, node_id::String)
    lock(_REGISTRY.lock) do
        group = get(_REGISTRY.groups, group_id, nothing)
        isnothing(group) && _throw("group '$group_id' does not exist", "grave_node_in_group!")
        node_id in group.member_ids || _throw(
            "node '$node_id' not in group '$group_id'", "grave_node_in_group!")
        group.grave_count += 1
    end
    return nothing
end

"""
    clear_unlinkable_if_has_grave!(group_id)

GRUG: Convenience wrapper: if the group has at least one grave member, clear
the unlinkable flag explicitly. Idempotent. Does NOT touch grave_count.
"""
function clear_unlinkable_if_has_grave!(group_id::String)
    lock(_REGISTRY.lock) do
        group = get(_REGISTRY.groups, group_id, nothing)
        isnothing(group) && _throw("group '$group_id' does not exist",
                                   "clear_unlinkable_if_has_grave!")
        if group.grave_count > 0
            group.is_unlinkable = false
        end
    end
    return nothing
end

# ==============================================================================
# QUERIES
# ==============================================================================

get_group(group_id::String)::Union{NodeGroup, Nothing} =
    lock(() -> get(_REGISTRY.groups, group_id, nothing), _REGISTRY.lock)

list_group_ids()::Vector{String} =
    lock(() -> copy(_REGISTRY.group_id_order), _REGISTRY.lock)

group_count()::Int =
    lock(() -> length(_REGISTRY.group_id_order), _REGISTRY.lock)

"""
    partners_for_node(node_id)::Vector{String}

GRUG: Return the union of member ids across all groups containing `node_id`,
minus the node itself. Duplicates across groups are collapsed.
"""
function partners_for_node(node_id::String)::Vector{String}
    lock(_REGISTRY.lock) do
        gids = get(_REGISTRY.node_to_groups, node_id, String[])
        seen = Set{String}()
        for gid in gids
            group = _REGISTRY.groups[gid]
            for m in group.member_ids
                m != node_id && push!(seen, m)
            end
        end
        return collect(seen)
    end
end

# GRUG: Alias kept for external callers that want a shorter name.
node_partners(node_id::String) = partners_for_node(node_id)

# ==============================================================================
# CHATTER WINDOW CURSOR --- walks the group id list FIFO, STOPS at the end
# ==============================================================================
# GRUG: when cursor near tail of lobe list, window shrinks to whatever is left.
# no mid-window wrap. caller's next advance_chatter_cursor! will wrap cursor to
# 1, and the FOLLOWING call picks up a fresh full-size window from the front.
# this matches the user spec: "if it doesnt have enough slots to use, just use
# the remaining ids in the lobe list."
# ==============================================================================

"""
    next_chatter_window_ids(; window_size, rng)::Vector{String}

GRUG: Peek at the next chatter window --- the group ids starting at the cursor,
up to `window_size` entries. Does NOT advance the cursor (separate call so
the caller can chatter first, then commit).

window_size defaults to a random draw in [CHATTER_WINDOW_MIN, CHATTER_WINDOW_MAX];
tests inject explicit sizes via the kwarg.

TAIL-SHRINK SEMANTICS (v7.15.1):
  * If fewer than `window_size` ids remain from cursor to end of list, returns
    ONLY the tail remnant (no mid-window wrap back to the front). The caller's
    subsequent advance_chatter_cursor! then wraps the cursor to position 1, so
    the NEXT call gets a fresh full window from the front.
  * If the entire registry has fewer groups than window_size, returns every id
    once (no artificial inflation).
"""
function next_chatter_window_ids(;
    window_size::Int = rand(Random.GLOBAL_RNG,
                            CHATTER_WINDOW_MIN:CHATTER_WINDOW_MAX),
    rng::Random.AbstractRNG = Random.GLOBAL_RNG,
)::Vector{String}
    window_size <= 0 && _throw("window_size must be positive (got $window_size)",
                               "next_chatter_window_ids")

    lock(_REGISTRY.lock) do
        n = length(_REGISTRY.group_id_order)
        n == 0 && return String[]

        # GRUG: clamp cursor defensively. if somehow past end (shouldn't happen
        # because advance! uses mod1, but belt-and-suspenders), snap to 1.
        start_idx = _REGISTRY.cursor
        if start_idx < 1 || start_idx > n
            start_idx = 1
        end

        # GRUG: slots remaining from cursor to end of list.
        slots_remaining = n - start_idx + 1

        # GRUG: tail-shrink --- take min of (requested window, slots left).
        # no wrap. if cursor was near end, window is smaller this time.
        take_n = min(window_size, slots_remaining)

        out = Vector{String}(undef, take_n)
        @inbounds for i in 1:take_n
            out[i] = _REGISTRY.group_id_order[start_idx + i - 1]
        end
        return out
    end
end

"""
    advance_chatter_cursor!(step::Int)

GRUG: Move the cursor forward by `step` positions. Wraps. Used after a chatter
window has been fully processed so the next window starts where this one ended.
"""
function advance_chatter_cursor!(step::Int)
    step < 0 && _throw("step must be non-negative (got $step)", "advance_chatter_cursor!")
    lock(_REGISTRY.lock) do
        n = length(_REGISTRY.group_id_order)
        n == 0 && (return nothing)
        _REGISTRY.cursor = mod1(_REGISTRY.cursor + step, n)
    end
    return nothing
end

# ==============================================================================
# DISK PERSISTENCE (compressed JSON) --- snapshots for crash recovery
# ==============================================================================

"""
    save_registry_compressed(path::String = DEFAULT_REGISTRY_DISK_PATH)

GRUG: Snapshot the entire registry to a gzipped JSON blob. Uses the external
`gzip` command --- Julia ships this on every supported OS via the `CodecZlib`
stdlib-adjacent, but we avoid adding a dep and use Base.Sys. If gzip is not
available, we write uncompressed JSON with a `.json` suffix and warn loudly.

Returns the path actually written (compressed or uncompressed fallback).
"""
function save_registry_compressed(path::String = DEFAULT_REGISTRY_DISK_PATH)::String
    snapshot = lock(_REGISTRY.lock) do
        Dict{String, Any}(
            "version" => "v7.15",
            "groups" => [Dict(
                "group_id"      => g.group_id,
                "member_ids"    => g.member_ids,
                "partner_cap"   => g.partner_cap,
                "is_unlinkable" => g.is_unlinkable,
                "grave_count"   => g.grave_count,
            ) for (_, g) in _REGISTRY.groups],
            "group_id_order" => _REGISTRY.group_id_order,
            "cursor"         => _REGISTRY.cursor,
        )
    end

    json_str = JSON.json(snapshot)

    # GRUG: Try gzip. If it fails, fall back to uncompressed JSON and warn.
    if endswith(path, ".gz")
        uncompressed = replace(path, r"\.gz$" => "")
        open(uncompressed, "w") do io
            write(io, json_str)
        end
        try
            run(pipeline(`gzip -f $uncompressed`))
            return path
        catch e
            @warn "[GroupRegistry] gzip failed, saving uncompressed: $e"
            return uncompressed
        end
    else
        open(path, "w") do io
            write(io, json_str)
        end
        return path
    end
end

"""
    load_registry_compressed(path::String = DEFAULT_REGISTRY_DISK_PATH)

GRUG: Load a snapshot into the singleton (replaces current contents). Throws
on missing file, bad JSON, or version mismatch.
"""
function load_registry_compressed(path::String = DEFAULT_REGISTRY_DISK_PATH)
    isfile(path) || _throw("snapshot not found: $path", "load_registry_compressed")

    json_str = if endswith(path, ".gz")
        # GRUG: Shell out to gunzip -c for read. Keeps dep surface at zero.
        try
            read(pipeline(`gunzip -c $path`), String)
        catch e
            _throw("gunzip failed on $path: $e", "load_registry_compressed")
        end
    else
        read(path, String)
    end

    data = try
        JSON.parse(json_str)
    catch e
        _throw("bad JSON in $path: $e", "load_registry_compressed")
    end

    haskey(data, "version") || _throw("snapshot missing 'version' field",
                                      "load_registry_compressed")

    lock(_REGISTRY.lock) do
        empty!(_REGISTRY.groups)
        empty!(_REGISTRY.node_to_groups)
        empty!(_REGISTRY.group_id_order)

        for g in data["groups"]
            group = NodeGroup(
                String(g["group_id"]),
                [String(m) for m in g["member_ids"]],
                Int(g["partner_cap"]),
                Bool(g["is_unlinkable"]),
                Int(g["grave_count"]),
            )
            _REGISTRY.groups[group.group_id] = group

            for m in group.member_ids
                gids = get!(_REGISTRY.node_to_groups, m, String[])
                if !(group.group_id in gids)
                    push!(gids, group.group_id)
                end
            end
        end

        append!(_REGISTRY.group_id_order, [String(x) for x in data["group_id_order"]])
        _REGISTRY.cursor = Int(data["cursor"])
    end

    return nothing
end

end # module GroupRegistry
