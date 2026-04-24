# Node Contributor-Only Reinforcement Update

## Summary

This update applies the same contributor-only reinforcement logic used for AIML nodes to regular (non-AIML) nodes. Now, **only nodes that actually contributed to generating output (i.e., their votes were used by the AIML orchestrator)** are eligible for reinforcement via `/right` and penalty via `/wrong`.

## Key Changes

### 1. Node Structure Updates

Added four new fields to the `Node` struct in `src/engine.jl`:

```julia
fired_this_cycle::Bool           # True if node's vote was used by AIML orchestrator
voted_this_cycle::Bool           # True if node voted (may or may not have contributed)
gained_this_cycle::Bool          # True if node gained strength this cycle
strength_delta_this_cycle::Float64  # Strength change this cycle (for over-compensation penalty)
```

### 2. Orchestrator Changes

The `ephemeral_aiml_orchestrator` function in `src/Main.jl` now returns a tuple:
- **Previously:** `String` (output only)
- **Now:** `(String, Vector{Vote}, Vector{Vote})` (output, sure_votes, unsure_votes)

### 3. Vote Processing

After the orchestrator returns:
1. All voters are marked `voted_this_cycle = true`
2. Vote response times are recorded
3. Contributing nodes (sure_votes + unsure_votes) are marked `fired_this_cycle = true`
4. Both `LAST_VOTER_IDS` and `LAST_CONTRIBUTOR_IDS` are populated

### 4. /wrong Command Update

**Previous behavior:** Penalized all nodes that voted
**New behavior:** Penalizes only contributing nodes (those with `fired_this_cycle = true`)

```julia
# Old
voter_ids = copy(LAST_VOTER_IDS)
apply_wrong_feedback!(voter_ids)

# New
contributor_ids = copy(LAST_CONTRIBUTOR_IDS)
apply_wrong_feedback!(contributor_ids)
```

### 5. /right Command Addition

Added a new `/right` command for regular nodes (similar to `/aimlRight` for AIML nodes):

**Behavior:**
- Only processes contributing nodes (`fired_this_cycle = true`)
- Skips nodes that already gained strength this cycle (no double reward)
- Skips grave nodes
- Uses 50/50 coinflip for eligible contributors (secondary reinforcement chance)

**Returns statistics dictionary:**
- `total_contributors`: Total number of contributing nodes
- `rewarded`: Node IDs that gained strength
- `skipped_double_reward`: Node IDs that already gained (skipped)
- `coinflip_missed`: Node IDs that lost the coinflip
- `grave_skipped`: Node IDs that are grave and were skipped

### 6. Helper Functions Added

```julia
mark_node_contributor!(node::Node)
# Mark a node as having contributed to output this cycle

reset_cycle_flags!(node::Node)
# Reset cycle tracking flags at the start of a new cycle

reset_all_cycle_flags!()
# Reset cycle flags for all nodes at the start of a new mission

apply_right_feedback!(contributor_ids::Vector{String})
# Apply secondary reinforcement to contributing nodes
```

## Design Principles

1. **Contributor-Only Feedback**: Only nodes that meaningfully contributed to output generation can be reinforced or penalized.

2. **Secondary Reinforcement**: `/right` provides a second chance for contributors to gain strength, with checks to prevent double-rewarding.

3. **Fair Penalties**: `/wrong` penalizes only contributors, ensuring that nodes that didn't contribute aren't unfairly punished.

4. **Cycle Awareness**: The system tracks contribution per cycle to prevent double-rewards and ensure honest penalties.

5. **No Silent Failures**: All functions validate inputs and report errors explicitly.

## Voter vs Contributor Distinction

### Voters
- Nodes that participated in the voting process
- May or may not have their votes used by AIML
- Marked with `voted_this_cycle = true`

### Contributors
- Nodes whose votes were actually used by the AIML orchestrator
- Found in `sure_votes` or `unsure_votes` buckets
- Marked with `fired_this_cycle = true`
- **Only contributors are eligible for /right and /wrong feedback**

## Workflow Example

1. User input is processed → `scan_and_expand()` returns matching votes
2. Votes are passed to `ephemeral_aiml_orchestrator()`:
   - Votes are sorted by confidence
   - High-confidence votes go to `sure_votes`
   - Lower-confidence votes get 50/50 coinflip → `unsure_votes`
3. Orchestrator returns `(output, sure_votes, unsure_votes)`
4. Post-processing:
   - All voters marked `voted_this_cycle = true`
   - Contributors (sure + unsure) marked `fired_this_cycle = true`
   - `LAST_VOTER_IDS` and `LAST_CONTRIBUTOR_IDS` populated
5. User provides feedback:
   - `/right` → reinforces only contributors
   - `/wrong` → penalizes only contributors

## Compatibility Notes

- **Breaking Change**: The `ephemeral_aiml_orchestrator` return type changed from `String` to `(String, Vector{Vote}, Vector{Vote})`
- **New Command**: `/right` command added for regular node reinforcement
- **Test Updates**: All test files updated to handle the new contributor tracking

## Testing

All existing tests pass:
- `test/test_smoke.jl` - 16 test groups
- `test/test_comprehensive.jl` - 25 test groups
- `test/test_chat_specimen.jl` - Live chat simulation

## Related Changes

This update complements the AIML contributor-only reinforcement update (documented in `AIML_CONTRIBUTOR_UPDATE.md`), ensuring consistent behavior across both AIML and regular node systems.