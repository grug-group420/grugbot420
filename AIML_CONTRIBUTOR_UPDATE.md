# AIML Strength Modification Update - Contributors Only

## Summary

**Date:** April 23, 2025  
**Commit:** 8693ff9  
**Status:** ✅ Completed and Pushed to GitHub

### Core Rule Change

**Before:** All voters (nodes that participated in voting) could be reinforced or penalized by `/right` and `/wrong` feedback.

**After:** ONLY contributors (nodes that actually fired and contributed to output generation) are eligible for strength modifications from `/right` and `/wrong`.

**Rationale:** Contribution to output generation is the hard test of whether an AIML node was useful. Only nodes that actually helped produce the output should be reinforced or penalized.

---

## Implementation Details

### 1. New Helper Function: `_collect_contributors()`

```julia
function _collect_contributors()::Vector{AIMLNode}
    contributors = AIMLNode[]
    lock(AIML_LOCK) do
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                if node.fired_this_cycle
                    push!(contributors, node)
                end
            end
        end
    end
    return contributors
end
```

**Purpose:** Collects all AIML nodes that have `fired_this_cycle == true`. These are nodes that actually contributed to generating output.

### 2. Updated `apply_aiml_right!()` - Secondary Reinforcement

**Current Behavior:**
- Processes ONLY contributors (fired nodes)
- For each contributor:
  - If `gained_this_cycle == true`: Skip (already rewarded via initial coinflip)
  - Else: Coinflip (50% chance of gaining strength)
- **Logic:** Contributors who were "worthy but unlucky" in the initial coinflip get a second chance

**Key Changes:**
- Changed from `_collect_voters()` to `_collect_contributors()`
- Changed result key from `total_voters` to `total_contributors`
- Updated logging messages to use "contributors" instead of "voters"
- Preserved all error handling and comment conventions

**Diagnostic Output:**
```julia
Dict(
    "total_contributors"   => Int,
    "rewarded"             => Vector{String},
    "skipped_double_reward" => Vector{String},
    "coinflip_missed"      => Vector{String},
    "grave_skipped"        => Vector{String},
)
```

### 3. Updated `apply_aiml_wrong!()` - Contributor Penalty

**Current Behavior:**
- Processes ONLY contributors (fired nodes)
- For each contributor:
  - 50/50 coinflip for penalty
  - If penalized:
    - If `gained_this_cycle == true`: Over-compensate penalty (cancel gain + ensure net loss)
    - Else: Standard penalty magnitude
- **Logic:** Only nodes that contributed to the "wrong" output should be penalized

**Key Changes:**
- Changed from `_collect_voters()` to `_collect_contributors()`
- Changed result key from `total_voters` to `total_contributors`
- Updated logging messages to use "contributors" instead of "voters"
- Preserved all error handling and comment conventions

**Diagnostic Output:**
```julia
Dict(
    "total_contributors" => Int,
    "penalized"         => Vector{String},
    "spared"            => Vector{String},
    "newly_graved"      => Vector{String},
    "grave_skipped"     => Vector{String},
)
```

---

## Test Updates

All tests in `test/test_aiml_node_system.jl` were updated to reflect the new logic:

### Test Changes:
1. **Nodes marked as contributors**: Added `fired_this_cycle = true` to nodes that should be processed by feedback
2. **Result key updates**: Changed `total_voters` to `total_contributors` in all assertions
3. **Grave node handling**: Updated tests to mark grave nodes as `fired_this_cycle` to verify they're properly skipped

### Test Results:
✅ **All 15 AIML Node System test groups PASSED**

Test groups verified:
- Lobe registration
- Node lifecycle
- Population cap
- Lobe isolation
- Cycle management
- Use-based strength gain
- `/aimlRight` double-snack exclusion
- `/aimlWrong` net-loss guarantee
- AIML_GRAVE transition
- Phagy sweep compatibility
- Diagnostics
- Reset

---

## Behavior Examples

### Example 1: Output Generation Cycle

**Scenario:** 10 nodes participate in voting, but only 3 actually fire and contribute to output.

**Old Behavior:**
- `/right`: All 10 voters eligible for reinforcement
- `/wrong`: All 10 voters eligible for penalty

**New Behavior:**
- `/right`: Only 3 contributors eligible for reinforcement
- `/wrong`: Only 3 contributors eligible for penalty
- 7 voters who didn't fire are ignored

### Example 2: Secondary Reinforcement

**Scenario:** A contributor fires but loses the initial coinflip (doesn't gain strength).

**Behavior:**
- Initial coinflip: 50% chance of gaining strength → **LOST**
- Later, `/right` issued:
  - `gained_this_cycle == false` → Not skipped
  - Secondary coinflip: 50% chance → **WON**
  - Node gains strength (second chance)

### Example 3: Over-compensation Penalty

**Scenario:** A contributor fires and gains strength (+1.0), then `/wrong` is issued.

**Behavior:**
- Coinflip for penalty: **PENALIZE**
- Check `gained_this_cycle == true` and `strength_delta_this_cycle = 1.0`
- Penalty magnitude = `AIML_STRENGTH_DELTA + 1.0 = 2.0`
- Apply -2.0 penalty:
  - Cancels the +1.0 gain
  - Applies additional -1.0 net loss
- Final result: Net loss of 1.0 strength

---

## Error Handling & Safety

All error handling and safety mechanisms preserved:

1. **Grave Node Protection:** Grave nodes cannot gain strength, even if they fire
2. **Strength Clamping:** All strength changes clamped to `[AIML_STRENGTH_FLOOR, AIML_STRENGTH_CAP]`
3. **Thread Safety:** All operations protected by `AIML_LOCK`
4. **No Silent Failures:** All errors thrown with descriptive messages
5. **Cycle Isolation:** Each cycle's changes tracked independently via `strength_delta_this_cycle`

---

## Compatibility Notes

### Breaking Changes:
- **Result API:** `total_voters` renamed to `total_contributors`
- **Behavior:** Non-firing voters no longer affected by feedback

### Non-Breaking:
- All function signatures unchanged
- All comment conventions preserved
- All error messages unchanged
- All locking mechanisms preserved

### Migration Guide:
For code that reads feedback results:
```julia
# OLD
result = apply_aiml_right!()
println("Processed $(result["total_voters"]) voters")

# NEW
result = apply_aiml_right!()
println("Processed $(result["total_contributors"]) contributors")
```

---

## Files Modified

### Source Code:
- `src/AIMLNodeSystem.jl`
  - Added `_collect_contributors()` function
  - Updated `apply_aiml_right!()` function
  - Updated `apply_aiml_wrong!()` function
  - Updated `_collect_voters()` docstring

### Tests:
- `test/test_aiml_node_system.jl`
  - Updated all tests to mark nodes as `fired_this_cycle`
  - Updated all assertions to use `total_contributors`
  - Updated test messages for clarity

### Total Changes:
- 2 files changed
- 88 insertions(+)
- 30 deletions(-)

---

## Verification

### Automated Tests:
```bash
cd /workspace/grugbot420
julia test/test_aiml_node_system.jl
```

**Result:** ✅ All 15 test groups passed

### Git Status:
```bash
git log --oneline -1
# 8693ff9 Update AIML strength modification: only contributors (fired nodes) can be reinforced/penalized by /right and /wrong
```

### Repository:
- **GitHub:** https://github.com/grug-group420/grugbot420
- **Branch:** main
- **Commit:** 8693ff9

---

## Next Steps

The AIML contributor-only reinforcement system is now active and production-ready.

**Recommendations:**
1. Monitor behavior in production to verify contributor-based reinforcement works as expected
2. Review logs for "contributors=" vs. "voters=" to verify the change in scope
3. Consider adding metrics to track vs. contributors ratio over time

**No further action required** - the change is complete and tested.