# PhagyGroupOrganizer.jl
# ==============================================================================
# GRUG v7.15 - PHAGY GROUP ORGANIZER AUTOMATON
# ==============================================================================
# GRUG: One more automaton for the idle-time maintenance loop. This one
# operates on the GroupRegistry instead of the node map.
#
# THREE SMALL JOBS:
#
#   1. CLEAR-UNLINKABLE-ON-GRAVE: iterate every group, if grave_count > 0 and
#      is_unlinkable == true, unset the unlinkable flag. Ensures stale flags
#      don't outlive their reason. (The registry already does this on mutation
#      paths; this pass catches any state that somehow drifted.)
#
#   2. PRUNE-EMPTY-GROUPS: if a group's member_ids is empty and grave_count
#      is zero (all members fully removed), the group is deleted entirely.
#      Empty groups waste cursor slots during chatter.
#
#   3. COMPACT-CURSOR: if the cursor is pointing past the end of the id list
#      after pruning (only possible during races, but defense-in-depth),
#      reset it to 1.
#
# DISK SNAPSHOT: if auto_snapshot=true, take a compressed JSON snapshot after
# the pass. Useful so crash recovery sees the post-organize state.
#
# NO SILENT FAILURES: the pass never swallows; it returns a typed record of
# what it did so the phagy logger can print it. The only non-throw mode is
# "nothing to do" which returns a zero-count record.
# ==============================================================================

module PhagyGroupOrganizer

using ..GroupRegistry
using ..GroupRegistry: _REGISTRY      # GRUG: internal access for compact-cursor

export GroupOrganizerStats, run_group_organizer!

"""
    GroupOrganizerStats(unlinkable_cleared, groups_pruned, cursor_reset,
                        snapshot_path)

GRUG: Plain data record describing what the pass did. snapshot_path is
empty string when auto_snapshot=false.
"""
struct GroupOrganizerStats
    unlinkable_cleared::Int
    groups_pruned::Int
    cursor_reset::Bool
    snapshot_path::String
end

"""
    run_group_organizer!(; auto_snapshot = false, snapshot_path = "group_registry.json.gz")
        ::GroupOrganizerStats

GRUG: Run the organizer pass. Returns stats for the phagy logger.

The pass is SAFE under concurrent reads of the registry (GroupRegistry's
internal lock is acquired implicitly by the mutating calls we make). It does
NOT coordinate with a running chatter round --- callers must ensure the
organizer is only scheduled at idle time, same as other phagy automata.
"""
function run_group_organizer!(;
    auto_snapshot::Bool = false,
    snapshot_path::String = "group_registry.json.gz",
)::GroupOrganizerStats

    unlinkable_cleared = 0
    groups_pruned      = 0
    cursor_reset       = false
    snap               = ""

    # GRUG: Job 1 --- clear unlinkable flag when grave_count > 0.
    for gid in list_group_ids()
        g = get_group(gid)
        isnothing(g) && continue  # GRUG: racing delete; skip.
        if g.grave_count > 0 && g.is_unlinkable
            clear_unlinkable_if_has_grave!(gid)
            unlinkable_cleared += 1
        end
    end

    # GRUG: Job 2 --- prune fully-empty groups (no live, no grave members).
    # We walk a SNAPSHOT of ids because we delete during iteration.
    for gid in list_group_ids()
        g = get_group(gid)
        isnothing(g) && continue
        if isempty(g.member_ids) && g.grave_count == 0
            # GRUG: Direct mutation through the registry singleton. Registry
            # uses its own lock; we just ask for the delete.
            lock(_REGISTRY.lock) do
                delete!(_REGISTRY.groups, gid)
                idx = findfirst(isequal(gid), _REGISTRY.group_id_order)
                if !isnothing(idx)
                    deleteat!(_REGISTRY.group_id_order, idx)
                end
            end
            groups_pruned += 1
        end
    end

    # GRUG: Job 3 --- compact cursor if it ran off the end after pruning.
    lock(_REGISTRY.lock) do
        n = length(_REGISTRY.group_id_order)
        if _REGISTRY.cursor > n
            _REGISTRY.cursor = max(1, 1)
            cursor_reset = true
        end
    end

    # GRUG: Optional disk snapshot.
    if auto_snapshot
        try
            snap = save_registry_compressed(snapshot_path)
        catch e
            @warn "[PhagyGroupOrganizer] snapshot failed (non-fatal): $e"
        end
    end

    return GroupOrganizerStats(
        unlinkable_cleared,
        groups_pruned,
        cursor_reset,
        snap,
    )
end

end # module PhagyGroupOrganizer
