# Action Packet Format

Action packets define what a node proposes when it fires. They are the behavioral output of each node.

## Syntax

```
action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight
```

- **Actions** — behavioral verbs the orchestrator uses to shape output
- **Negatives `[...]`** — constraints injected into the AIML payload
- **Weights `^N`** — relative voting weight for the superposition orchestrator

## Available Actions

| Action | Category |
|--------|----------|
| `reason`, `analyze`, `ponder`, `calculate` | Cognitive |
| `explain`, `clarify`, `describe`, `define`, `elaborate` | Explanatory |
| `greet`, `welcome`, `smile`, `laugh` | Social |
| `comfort`, `support`, `validate`, `acknowledge`, `reassure` | Emotional |
| `alert`, `warn`, `caution`, `notify`, `flag` | Safety |
| `flee`, `hide`, `fight` | Defensive |

## Examples

**Technical analysis node:**
```json
"action_packet": "reason[dont hallucinate]^4 | analyze^2 | explain^1"
```
→ Strong preference for reasoning (weight 4), with a constraint against hallucination.

**Emotional support node:**
```json
"action_packet": "comfort[dont dismiss, dont minimize]^3 | validate^2 | support^1"
```
→ Primary comfort action with constraints, backed by validation and support.

**Alert node:**
```json
"action_packet": "alert^3 | warn[dont panic]^2 | flag^1"
```
→ Alert-focused with a calming constraint on warnings.

## How Weights Work

Weights set relative influence during vote resolution. In a packet like `reason^4 | analyze^2 | explain^1`:

- `reason` has 4/7 (57%) of the vote weight
- `analyze` has 2/7 (29%)
- `explain` has 1/7 (14%)

The orchestrator uses these to shape the superposition of competing proposals from all active nodes.

## Full Node JSON Format

```json
{
  "nodes": [
    {
      "pattern": "machine learning neural network deep learning",
      "action_packet": "reason[dont hallucinate]^4 | analyze^2 | explain^1",
      "data": {
        "system_prompt": "Technical ML domain active.",
        "required_relations": ["uses"],
        "relation_weights": {"uses": 2.0}
      },
      "drop_table": ["node_5", "node_12"]
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `pattern` | ✅ | Space-separated tokens the node matches against |
| `action_packet` | ✅ | Behavioral output proposal |
| `data.system_prompt` | Optional | Context injected when node fires |
| `data.required_relations` | Optional | Relations that must be present for node to fire |
| `data.relation_weights` | Optional | Weight multipliers for specific relations |
| `drop_table` | Optional | Co-activation neighbors (node IDs) |
