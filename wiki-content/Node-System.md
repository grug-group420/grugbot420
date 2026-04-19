# Node System

Nodes are the atomic unit of cognition in grugbot420. Each node is an explicit, inspectable structure — not a hidden vector inside an opaque model.

## Node Structure

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier (e.g., `node_0`) |
| `pattern` | String | Space-separated tokens the node matches against |
| `signal` | Vector | Numeric signal representation for comparison |
| `strength` | Float | Local trust/influence (0.0 to STRENGTH_CAP) |
| `action_packet` | String | Proposed behavioral output |
| `neighbors` | Array | Connected nodes (drop table) |
| `lobe` | String | Domain partition membership |
| `grave` | Bool | Dead node waiting for recycling |
| `json_data` | Dict | System prompt, required relations, weights |
| `hopfield_key` | UInt64 | Cache key for fast recall |
| `is_image_node` | Bool | Whether this is an image-type node |

## Node Lifecycle

```
Created (/grow) → Active (voting) → Strengthened (/mission hits)
                                   → Weakened (/wrong penalties)
                                   → Graved (strength → 0)
                                   → Recycled (phagy)
```

## Strength Dynamics

- **Reinforcement**: Nodes that fire on successful missions gain strength
- **Penalty**: `/wrong` decays strength via coinflip
- **Idle decay**: PhagyMode gradually decays unused nodes
- **Grave threshold**: Strength reaching 0 = grave

## Creating Nodes

```
/grow {"nodes":[{"pattern":"hello greeting","action_packet":"greet^3 | smile^1"}]}
```

Into a specific lobe:
```
/lobeGrow language {"nodes":[{"pattern":"syntax grammar","action_packet":"analyze^3"}]}
```

## Inspecting Nodes

```
/nodes          # List all nodes with ID, pattern, strength, neighbors, grave status
/status         # System-wide node statistics
/attachments    # Node attachment map
```

## Node Attachments

Nodes can be wired into explicit firing chains via [[Relational Fire]]. When a target fires, attached nodes coinflip to decide if they fire too.

```
/nodeAttach node_0 node_1 "machine learning" node_2 "gradient descent"
```

Max 4 attachments per target. JIT confidence baking at attach time.
