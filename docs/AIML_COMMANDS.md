# AIML Node System - Commands Reference

## Overview

The AIML (Artificial Intelligence Markup Language) Node System provides an executive layer for GrugBot420. Each lobe has its own AIML tribe of nodes that can vote, fire, and be reinforced or penalized based on user feedback.

## Core Concepts

- **Per-Lobe Tribes**: Each lobe has its own AIML node population
- **Population Cap**: AIML nodes per lobe ≤ floor(parent_lobe_cap / 3)
- **Strength Bounds**: AIML node strength ∈ [0.0, 10.0]
- **Grave Nodes**: Nodes with strength = 0.0 are marked as grave (dead)
- **Cycle Memory**: Each node tracks per-cycle activity for honest feedback
- **Maturity Threshold**: AIML immune system activates at 1000+ AIML nodes
- **Contributors vs Voters**: Only nodes that **fired** (actually contributed to output) are eligible for reinforcement/penalty. Voters who didn't fire are ignored.

---

## User Commands

### `/aimlRight`

**Purpose**: Apply secondary reinforcement to AIML nodes that actually contributed to output generation.

**Usage**: `/aimlRight`

**Behavior**:
- **CRITICAL**: Only processes nodes that **fired** this cycle (contributors), not all voters
- Increases strength by `AIML_STRENGTH_DELTA` (1.0) for contributing nodes that didn't already gain strength
- Skips nodes that already gained strength this cycle from initial coinflip (no double reward)
- Uses 50/50 coinflip for eligible contributors (secondary reinforcement chance)
- Clamps strength to `AIML_STRENGTH_CAP` (10.0)
- Returns summary of rewarded, skipped, and missed contributors

**Example**:
```
/aimlRight
✅  /aimlRight applied. 15 contributors processed, 8 rewarded, 5 double-skip, 2 missed coinflip.
```

**Key Concept**: Contributors who were "worthy but unlucky" in the initial coinflip get a second chance via secondary reinforcement.

**Error Handling**:
- Warns if no AIML nodes contributed this cycle
- No silent failures - all errors are logged

---

### `/aimlWrong`

**Purpose**: Penalize AIML nodes that actually contributed to a wrong output.

**Usage**: `/aimlWrong`

**Behavior**:
- **CRITICAL**: Only processes nodes that **fired** this cycle (contributors), not all voters
- Uses 50/50 coinflip to determine which contributors get penalized
- Contributors that already gained strength this cycle get EXTRA penalty (net-negative):
  - Penalty magnitude = strength gained this cycle + AIML_STRENGTH_DELTA
  - Ensures net loss even if node gained during cycle
- Contributors that didn't gain strength get standard penalty
- Contributors that hit strength = 0.0 become grave
- Returns summary of penalized, spared, and newly graved contributors

**Example**:
```
/aimlWrong
❌  /aimlWrong applied. 10 contributors processed, 5 penalized, 5 spared by coinflip, 1 newly graved.
```

**Key Concept**: Only nodes that actually contributed to the "wrong" output should be penalized. Voters who didn't fire are innocent bystanders.

**Error Handling**:
- Warns if no AIML nodes contributed this cycle
- No silent failures - all errors are logged

---

## System Commands (Internal)

### `/status` - AIML Section

**Purpose**: Display AIML node tribe status summary.

**Usage**: `/status`

**Output**: Shows per-lobe AIML population, alive count, grave count, and average strength.

---

## API Functions

### Lobe Registration

#### `register_lobe!(lobe_id::String, parent_lobe_cap::Int)::Int`

Register a lobe for AIML node population.

**Parameters**:
- `lobe_id`: Unique identifier for the lobe
- `parent_lobe_cap`: Population cap of the parent lobe

**Returns**: Computed AIML population cap (floor(parent_lobe_cap / 3))

**Throws**: `AIMLNodeError` if:
- `lobe_id` is empty
- `parent_lobe_cap` is not positive
- Computed cap is non-positive (lobe too small)

**Example**:
```julia
cap = AIMLNodeSystem.register_lobe!("science", 3000)
# Returns 1000 (floor(3000 / 3))
```

---

#### `unregister_lobe!(lobe_id::String)`

Remove a lobe's AIML tribe entirely.

**Parameters**:
- `lobe_id`: Lobe identifier to unregister

**Throws**: `AIMLNodeError` if `lobe_id` is empty

**Example**:
```julia
AIMLNodeSystem.unregister_lobe!("science")
```

---

#### `is_lobe_registered(lobe_id::String)::Bool`

Check if a lobe is registered for AIML.

**Parameters**:
- `lobe_id`: Lobe identifier to check

**Returns**: `true` if registered, `false` otherwise

---

#### `get_population_cap(lobe_id::String)::Int`

Get the AIML population cap for a lobe.

**Parameters**:
- `lobe_id`: Lobe identifier

**Returns**: Population cap (integer)

**Throws**: `AIMLNodeError` if lobe not registered

---

#### `get_population_size(lobe_id::String)::Int`

Get total AIML node count for a lobe (including graves).

**Parameters**:
- `lobe_id`: Lobe identifier

**Returns**: Total node count

**Throws**: `AIMLNodeError` if lobe not registered

---

#### `get_alive_population_size(lobe_id::String)::Int`

Get alive AIML node count for a lobe (excluding graves).

**Parameters**:
- `lobe_id`: Lobe identifier

**Returns**: Alive node count

**Throws**: `AIMLNodeError` if lobe not registered

---

### Node Management

#### `add_aiml_node!(lobe_id::String, node_id::String, template::String; initial_strength::Float64=5.0)::AIMLNode`

Add a new AIML node to a lobe's tribe.

**Parameters**:
- `lobe_id`: Lobe identifier
- `node_id`: Unique node identifier
- `template`: AIML template text (executive payload)
- `initial_strength`: Starting strength (default: 5.0, range: [0.0, 10.0])

**Returns**: Created `AIMLNode` object

**Throws**: `AIMLNodeError` if:
- Any parameter is empty
- `initial_strength` out of bounds
- Lobe not registered
- Population cap exceeded
- Node ID already exists

**Example**:
```julia
node = AIMLNodeSystem.add_aiml_node!(
    "science",
    "rule_001",
    "The answer is {VOTE_CERTAINTY}.",
    initial_strength=7.0
)
```

---

#### `get_aiml_node(lobe_id::String, node_id::String)::AIMLNode`

Get an AIML node by ID.

**Parameters**:
- `lobe_id`: Lobe identifier
- `node_id`: Node identifier

**Returns**: `AIMLNode` object

**Throws**: `AIMLNodeError` if lobe or node not found

---

#### `has_aiml_node(lobe_id::String, node_id::String)::Bool`

Check if an AIML node exists.

**Parameters**:
- `lobe_id`: Lobe identifier
- `node_id`: Node identifier

**Returns**: `true` if node exists, `false` otherwise

---

#### `remove_aiml_node!(lobe_id::String, node_id::String)::Bool`

Remove an AIML node from the tribe.

**Parameters**:
- `lobe_id`: Lobe identifier
- `node_id`: Node identifier

**Returns**: `true` if removed, `false` if not found

---

#### `list_aiml_nodes(lobe_id::String)::Vector{AIMLNode}`

List all AIML nodes in a lobe.

**Parameters**:
- `lobe_id`: Lobe identifier

**Returns**: Vector of `AIMLNode` objects

**Throws**: `AIMLNodeError` if lobe not registered

---

#### `get_registered_lobes()::Vector{String}`

Get all lobe IDs registered for AIML.

**Returns**: Vector of lobe identifiers

---

### Cycle Management

#### `begin_cycle!()`

Start a new AIML cycle. Resets all per-cycle bookkeeping flags.

**Behavior**:
- Increments global cycle counter
- Resets `voted_this_cycle`, `fired_this_cycle`, `gained_this_cycle` for all nodes
- Resets `strength_delta_this_cycle` to 0.0 for all nodes

**Throws**: `AIMLNodeError` if cycle reset fails

---

#### `current_cycle()::Int`

Get the current cycle number.

**Returns**: Cycle counter value

---

### Node Activity

#### `record_fire!(node::AIMLNode)`

Record that a node fired in the current cycle (actually contributed to output).

**Behavior**:
- Sets `fired_this_cycle = true` (marks node as contributor)
- Applies strength gain (+1.0) via 50/50 coinflip
- Sets `gained_this_cycle = true` if strength increased
- Clamps strength to `AIML_STRENGTH_CAP`
- Updates `strength_delta_this_cycle`

**Important**: Only nodes with `fired_this_cycle == true` are eligible for `/aimlRight` and `/aimlWrong` feedback.

**Throws**: `AIMLNodeError` if strength update fails

---

#### `record_vote!(node::AIMLNode)`

Record that a node voted in the current cycle.

**Behavior**:
- Sets `voted_this_cycle = true`

**Important**: Voting alone does NOT make a node eligible for feedback. The node must also fire (call `record_fire!()`) to be considered a contributor for `/aimlRight` and `/aimlWrong`.

---

### Feedback Application

#### `apply_aiml_right!()::Dict{String, Any}`

Apply secondary reinforcement to AIML nodes that contributed to output.

**Returns**: Dictionary with keys:
- `"total_contributors"`: Total number of nodes that fired (contributed)
- `"rewarded"`: List of node IDs that received reward
- `"skipped_double_reward"`: List of node IDs skipped (already gained this cycle)
- `"coinflip_missed"`: List of node IDs that missed the coinflip
- `"grave_skipped"`: List of grave node IDs skipped

**Behavior**:
- **Only processes nodes that fired** (fired_this_cycle == true), not all voters
- Rewards contributing nodes that didn't already gain strength via coinflip
- Skips contributors that already gained (no double reward - secondary reinforcement only)
- Uses 50/50 coinflip for eligible contributors
- Clamps strength to `AIML_STRENGTH_CAP`

---

#### `apply_aiml_wrong!()::Dict{String, Any}`

Apply negative feedback to AIML nodes that contributed to output.

**Returns**: Dictionary with keys:
- `"total_contributors"`: Total number of nodes that fired (contributed)
- `"penalized"`: List of node IDs that were penalized
- `"spared"`: List of node IDs spared by coinflip
- `"newly_graved"`: List of node IDs that hit strength = 0.0
- `"grave_skipped"`: List of grave node IDs skipped

**Behavior**:
- **Only processes nodes that fired** (fired_this_cycle == true), not all voters
- Uses 50/50 coinflip to determine which contributors get penalized
- Contributors that already gained strength get EXTRA penalty:
  - Penalty = strength_delta_this_cycle + AIML_STRENGTH_DELTA
  - Ensures net loss even if node gained during cycle
- Contributors hitting strength = 0.0 become grave

---

### Phagy (Cleanup)

#### `aiml_phagy_sweep!(; prune_graves::Bool=true)::Dict{String, Any}`

Perform phagy sweep to clean up AIML tribe.

**Parameters**:
- `prune_graves`: If `true`, remove grave nodes from registry

**Returns**: Dictionary with keys:
- `"lobes_swept"`: List of lobe IDs processed
- `"graves_found"`: Total grave nodes found
- `"graves_pruned"`: Grave nodes removed (if `prune_graves=true`)
- `"alive_count"`: Total alive nodes after sweep

---

### Diagnostics

#### `get_aiml_status_summary()::String`

Get a formatted summary of AIML tribe status.

**Returns**: Multi-line string with per-lobe statistics

---

#### `reset_all!()`

Reset entire AIML system. Clears all lobes, nodes, and cycle state.

**Warning**: This is destructive and cannot be undone.

---

## Immune System Integration

### AIML Immune Functions

#### `ImmuneSystem.aiml_immune_gate(aiml_node_count::Int; is_critical::Bool=true)::Bool`

Check if AIML immune system should activate.

**Parameters**:
- `aiml_node_count`: Current AIML node count
- `is_critical`: Whether this is a critical operation

**Returns**: `true` if AIML tribe is mature (≥1000 nodes), `false` if immature

**Behavior**:
- Returns `false` if `aiml_node_count < 1000` (immune dormant)
- Returns `true` if `aiml_node_count ≥ 1000` (immune active)

---

#### `ImmuneSystem.aiml_immune_scan!(input_text::String, aiml_node_count::Int; is_critical::Bool=true)::Tuple{Symbol, UInt64}`

Run full immune scan for AIML context.

**Parameters**:
- `input_text`: Text to scan
- `aiml_node_count`: Current AIML node count
- `is_critical`: Whether this is a critical operation

**Returns**: Tuple of `(status, signature)` where `status` is one of:
- `:immature` - AIML tribe below 1000 nodes, immune sleeping
- `:nonfunky` - Input is safe
- `:coinflip_skip` - Was funky but all agents skipped
- `:patched` - Funky but successfully patched
- `:deleted` - Funky and deleted
- `:error` - Something went wrong

**Behavior**:
- Uses AIML node count for maturity threshold (not total node count)
- Runs same scan logic as main immune system
- Logs all events with `:aiml_` prefix in ledger

---

#### `ImmuneSystem.get_aiml_immune_status(aiml_node_count::Int)::Dict{String, Any}`

Get AIML immune system status.

**Parameters**:
- `aiml_node_count`: Current AIML node count

**Returns**: Dictionary with keys:
- `"aiml_node_count"`: Current AIML node count
- `"aiml_maturity_threshold"`: Threshold (1000)
- `"is_mature"`: Whether AIML tribe is mature
- `"hopfield_size"`: Size of Hopfield immune memory
- `"ledger_size"`: Size of immune ledger

---

## Constants

### Strength Bounds
- `AIML_STRENGTH_CAP = 10.0` - Maximum strength
- `AIML_STRENGTH_FLOOR = 0.0` - Minimum strength (triggers grave)

### Population
- `AIML_POPULATION_CAP_RATIO = 3` - Cap = floor(parent_cap / 3)

### Plasticity
- `AIML_STRENGTH_DELTA = 1.0` - Strength change per reward/penalty

### Immune
- `AIML_MATURITY_THRESHOLD = 1000` - AIML immune activation threshold

### Grave Reasons
- `AIML_GRAVE_REASON_STRENGTH_ZERO = "AIML_STRENGTH_ZERO"` - Node died from strength hitting 0.0

---

## Error Handling

All AIML functions throw `AIMLNodeError` on failure with:
- `message`: Human-readable error description
- `context`: Function or operation where error occurred

**No silent failures** - all errors are logged and propagated.

---

## Usage Patterns

### Typical Workflow

1. **Register Lobe** (when creating new lobe):
   ```julia
   AIMLNodeSystem.register_lobe!(lobe_id, Lobe.LOBE_NODE_CAP)
   ```

2. **Add AIML Nodes** (during learning):
   ```julia
   AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template)
   ```

3. **Start Cycle** (before processing input):
   ```julia
   AIMLNodeSystem.begin_cycle!()
   ```

4. **Record Activity** (during processing):
   ```julia
   AIMLNodeSystem.record_vote!(node)
   AIMLNodeSystem.record_fire!(node)
   ```

5. **Apply Feedback** (after user response):
   ```julia
   AIMLNodeSystem.apply_aiml_right!()  # or apply_aiml_wrong!()
   ```

6. **Cleanup** (periodic):
   ```julia
   AIMLNodeSystem.aiml_phagy_sweep!(prune_graves=true)
   ```

### Immune Integration

When adding AIML nodes programmatically:

```julia
aiml_count = AIMLNodeSystem.get_alive_population_size(lobe_id)

if ImmuneSystem.aiml_immune_gate(aiml_count)
    status, sig = ImmuneSystem.aiml_immune_scan!(template, aiml_count)
    if status == :deleted
        error("AIML template rejected by immune system")
    end
end

# Safe to add node
AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template)
```

---

## Design Principles

1. **Per-Lobe Isolation**: Each lobe's AIML tribe is independent
2. **Population Control**: AIML nodes capped at 1/3 of parent lobe size
3. **Contributor-Only Feedback**: Only nodes that actually fired (contributed to output) are reinforced or penalized. Voters who didn't fire are ignored.
4. **Secondary Reinforcement**: `/aimlRight` gives contributors who missed initial coinflip a second chance
5. **Honest Feedback**: Cycle memory prevents double rewards and ensures real penalties with over-compensation
6. **No Silent Failures**: All errors are logged and propagated
7. **Immune Protection**: AIML immune system activates at 1000+ nodes
8. **Grave Tracking**: Dead nodes are remembered, not silently deleted
9. **Thread Safety**: All operations protected by ReentrantLock

---

## See Also

- `src/AIMLNodeSystem.jl` - Full implementation
- `src/ImmuneSystem.jl` - Immune system integration
- `README.md` - General GrugBot420 documentation
- `docs/src/architecture.md` - System architecture