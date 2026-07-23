# GrugBot Specimen Guide

**Building and loading GrugBot brain specimens from scratch**  
**Version:** v7.24 EphemeralMLP Transformer  
**Format:** grugbot420-specimen-v2.7


<!-- ⚠️ ARCHITECTURE REMINDERS ⚠️ -->
<!-- 1. ANTIMATCH NODES WERE REMOVED — do not reference, implement, or assume they exist -->
<!-- 2. SIGILS CAN APPEAR IN RELATIONAL TRIPLES — triples are dynamic, not just literal strings -->
<!-- 3. HOPFIELD CACHING WAS REMOVED — hopfield_key is a dead field for specimen compat only -->
---

## What Is a Specimen?

A specimen is a JSON file that captures the complete state of a GrugBot brain — every node, lobe, weight, rule, and memory. Loading a specimen with `/loadSpecimen` performs a full brain transplant: the current state is wiped and replaced with the specimen's contents. This makes specimens the primary way to save, share, and deploy GrugBot configurations.

A specimen is NOT a configuration file in the traditional sense. It is a serialized brain — a snapshot of a living system at a point in time, including learned weights, fire counts, strength values, and memory. You can build one from scratch (as this guide explains), or save a running brain with `/saveSpecimen` and reload it later.

---

## Quick Start: Load and Run

```julia
# Start GrugBot
using GrugBot420
GrugBot420.run_cli()

# In the CLI:
/loadSpecimen grug-binary/comprehensive_v724.specimen.json
/mission hello
```

If the specimen JSON is well-formed and all required keys are present, the load will succeed with zero errors. The specimen summary will show node count, lobe count, MLP rules, and other stats.

---

## Specimen JSON Top-Level Structure

A specimen is a single JSON object with the following top-level keys. Keys marked **required** must be present; keys marked **optional** will use engine defaults if absent.

```json
{
  "_meta":               { ... },   // REQUIRED — version metadata
  "nodes":               [ ... ],   // REQUIRED — array of node objects
  "lobes":               [ ... ],   // REQUIRED — array of lobe objects
  "lobe_tables":         [ ... ],   // REQUIRED — array of lobe table objects
  "rules":               [ ... ],   // REQUIRED — stochastic orchestration rules
  "messages":            [ ... ],   // REQUIRED — message history (can be empty)
  "verb_registry":       { ... },   // REQUIRED — verb class → verb list mapping
  "thesaurus":           { ... },   // REQUIRED — canonical word → aliases
  "inhibitions":         [ ... ],   // REQUIRED — negative thesaurus entries
  "arousal":             0.5,       // REQUIRED — float 0.0–1.0
  "id_counters":         { ... },   // REQUIRED — ID generation state
  "immune_system":       { ... },   // REQUIRED — hopfield signatures + ledger
  "brainstem":           { ... },   // REQUIRED — dispatch state
  "trajectory":          { ... },   // REQUIRED — trajectory config + buffer
  "chatter_cooldowns":   [ ... ],   // REQUIRED — must be array, not dict
  "node_to_lobe_idx":    { ... },   // REQUIRED — node_id → lobe_id mapping
  "sigils":              [ ... ],   // OPTIONAL — SigilPromoter rules
  "automaton_rules":     [ ... ],   // OPTIONAL — EphemeralAutomaton rules
  "last_contributor_votes": [ ... ],// OPTIONAL — vote history for /right /wrong
  "node_to_group_idx":   { ... },   // OPTIONAL — group membership index
  "tonal_judge_knobs":   { ... },   // OPTIONAL — TonalJudge tunables
  "ephemeral_mlp":       { ... },   // OPTIONAL — EphemeralMLP state (weights + rules)
  "mlp_observer_store":  { ... },   // OPTIONAL — SelfObserver store state
  "aiml_system":         { ... },   // OPTIONAL — AIML node tribe data
  "groups":              [ ... ],   // OPTIONAL — chatter group definitions
  "attachments":         { ... }    // OPTIONAL — relational fire attachments
}
```

Each section is documented in detail below.

---

## 1. Nodes (`"nodes"`)

Nodes are the fundamental cognitive units. Each node has a pattern (space-separated keywords), an action (how it responds), and metadata controlling its behavior.

**CRITICAL: Node patterns must use SPACE-SEPARATED words, NOT pipe `|` delimiters.** The literal-token pre-gate in `fire_one` splits patterns by whitespace and checks for overlap with input tokens. If you use `|` as an OR separator, the entire pattern becomes a single token that never matches any input word.

### Node JSON Format

```json
{
  "id": "node_math_01",
  "pattern": "calculate solve equation arithmetic",
  "signal": [0.123, 0.456, 0.789, 0.012],
  "action_packet": "reason",
  "json_data": {
    "system_prompt": "Grug computes carefully and verifies each step.",
    "lobe_hint": "mathematics"
  },
  "drop_table": [],
  "throttle": 0.5,
  "relational_patterns": [],
  "required_relations": [],
  "relation_weights": {},
  "strength": 0.8,
  "is_image_node": false,
  "neighbor_ids": [],
  "is_unlinkable": false,
  "max_neighbors": 12,
  "is_grave": false,
  "grave_reason": "",
  "response_times": [],
  "ledger_last_cleared": 0.0,
  "hopfield_key": 0,
  "fired_this_cycle": false,
  "voted_this_cycle": false,
  "gained_this_cycle": false,
  "strength_delta_this_cycle": 0.0
}
```

### Field Reference

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique node identifier (e.g. `"node_math_01"`) |
| `pattern` | string | **Space-separated** keywords for matching (NOT pipe-delimited) |
| `signal` | float[] | Pre-computed signal vector (one float per pattern word) |
| `action_packet` | string | Weighted action packet: `verb[negatives]^weight \| verb2[negatives]^weight` (see Weighted Action Packets section) |
| `json_data` | object | Arbitrary metadata; `system_prompt` and `lobe_hint` are conventional |
| `drop_table` | string[] | Linked node IDs for cascading activation |
| `throttle` | float | Minimum time between fires (seconds) |
| `relational_patterns` | array | RelationalTriple objects (usually empty in specimen) |
| `required_relations` | string[] | Relations that must be present for firing |
| `relation_weights` | object | Relation type → weight mapping |
| `strength` | float | Node power [0.0, STRENGTH_CAP]; determines survival |
| `is_image_node` | bool | True if pattern is SDF binary data, not text |
| `neighbor_ids` | string[] | Linked partner node IDs |
| `is_unlinkable` | bool | True when neighbor cap reached |
| `max_neighbors` | int | Per-node neighbor cap (typically 8–16) |
| `is_grave` | bool | True if node is dead (strength=0 or slow response) |
| `grave_reason` | string | `"STRENGTH_ZERO"`, `"GRAVED-SLOW"`, or `""` |
| `response_times` | float[] | Rolling response time history |
| `ledger_last_cleared` | float | Unix timestamp of last 24hr clear |
| `hopfield_key` | int | Hash of pattern for familiar input lookup (0 for new nodes) |
| `fired_this_cycle` | bool | Cycle tracking flag |
| `voted_this_cycle` | bool | Cycle tracking flag |
| `gained_this_cycle` | bool | Cycle tracking flag |
| `strength_delta_this_cycle` | float | Strength change this cycle |

### Valid Actions

These verbs can be used in action packets, either standalone (`"reason"`) or in weighted packets (`"reason[dont guess]^4 | explain^1"`):

```
acknowledge  alert      analyze    calculate  caution
clarify      comfort    define     describe   elaborate
explain      fight      flag       flee       greet
hide         laugh      notify     ponder     reason
reassure     smile      support    validate   warn
welcome
```

### Pattern Best Practices

**CRITICAL: Use single-token (one-word) patterns for maximum confidence.** Multi-word patterns suffer from BUG-004 (see below) which dramatically lowers confidence scores when the pattern is longer than the input. The default specimen uses 1–2 token patterns and achieves conf=0.60–0.70. Single-token patterns can achieve conf=0.33–1.00 depending on input length.

**DO:** Use single-token patterns — one word per node, multiple nodes per concept:
```
Node 1: pattern="calculate"   action_packet="reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1"
Node 2: pattern="solve"       action_packet="reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1"
Node 3: pattern="equation"    action_packet="reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1"
```

**DO:** Cover concept variants with multiple nodes sharing the same action_packet:
```
Node 1: pattern="hello"   action_packet="greet[dont frown, dont insult]^4 | welcome[be warm]^2 | smile^1"
Node 2: pattern="hi"      action_packet="greet[dont frown, dont insult]^4 | welcome[be warm]^2 | smile^1"
Node 3: pattern="hey"     action_packet="greet[dont frown, dont insult]^4 | welcome[be warm]^2 | smile^1"
Node 4: pattern="howdy"   action_packet="greet[dont frown, dont insult]^4 | welcome[be warm]^2 | smile^1"
```

**DO NOT:** Use pipe delimiters — these create a single token that never matches:
```
"calculate|solve|equation|arithmetic"  ← BROKEN: becomes one token
```

**DO NOT:** Use multi-word patterns unless absolutely necessary. A 4-token pattern like `"calculate solve equation arithmetic"` will score conf=0.14–0.33 against typical inputs due to BUG-004 and Jaccard dilution.

**DO NOT:** Include stopwords (a, an, the, is, of, etc.) — the scanner strips them.

### BUG-004: Pattern Length vs Input Length

When `length(node.signal) > length(input_signal)`, the engine's `fire_one` closure forces a cheap bidirectional scan with **swapped roles** — the input becomes the pattern and the node signal becomes the target. This dramatically lowers confidence because the scan was designed for the opposite orientation. A 4-token pattern against a 2-word input drops to conf≈0.14–0.25.

**Impact by pattern length (against 1-word input):**

| Pattern tokens | Example | Confidence | Notes |
|---|---|---|---|
| 1 | `"hello"` | 0.33–1.00 | Best. No BUG-004. Jaccard-only dilution. |
| 2 | `"hello hi"` | 0.25–0.50 | BUG-004 triggers on 1-word inputs. |
| 3+ | `"hello hi hey"` | 0.14–0.25 | Severe BUG-004. Avoid. |

**Workaround:** Use multiple nodes with single-token patterns instead of one node with a multi-token pattern. This completely eliminates BUG-004.

**Jaccard Dilution:** Even with single-token patterns, long inputs reduce confidence. A pattern `"calculate"` against input `"calculate 15 plus 27"` (4 content words) gives Jaccard = 1/4 = 0.25. This is inherent to the Jaccard-based system. The engine's fallback mechanism still selects the correct node, but confidence will be lower for verbose inputs. This is expected behavior.

### Weighted Action Packets

Action packets support a rich syntax for controlling vote behavior: alternative actions separated by `|`, inline negative constraints in `[brackets]`, and vote weights with `^N`.

**Format:** `verb1[negatives]^weight | verb2[negatives]^weight | verb3^weight`

- **Pipe `|`** — Separates alternative actions. The engine evaluates all alternatives and selects the highest-weighted one that passes constraints.
- **Brackets `[...]`** — Inline negative constraints. These are added to the node's inhibition set for this vote, preventing unwanted behaviors.
- **Caret `^N`** — Vote weight multiplier. Default is 1.0 if omitted. Higher weights make this action more likely to win the vote.

**Examples:**
```
greet[dont frown, dont insult]^4 | welcome[be warm]^2 | smile^1
```
- `greet` with weight 4, negatives "dont frown" and "dont insult"
- `welcome` with weight 2, negative "be warm" (encouragement constraint)
- `smile` with weight 1 (default fallback)

```
reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1
```
- `reason` is the primary action (4x weight) with constraints against guessing
- `elaborate` as secondary (2x weight) with precision constraint
- `explain` as tertiary fallback (1x weight)

```
comfort[dont dismiss feelings, dont be cold]^5 | reassure[be patient]^3 | support^1
```
- `comfort` dominates (5x) with emotional constraints
- `reassure` as strong secondary (3x)
- `support` as minimal fallback

**Weight Strategy:**
- Use weights 4–5 for the primary desired action
- Use weights 2–3 for acceptable secondary actions
- Use weight 1 for fallback actions you want available but not preferred
- The gap between weights determines how strongly the primary action dominates

### Multiple Nodes Per Concept

Since the `Node` struct has a single `pattern::String` field, you cannot store multiple patterns in one node. Instead, create multiple nodes with different single-token patterns that share the same action packet. This is the recommended approach for broad concept coverage.

**Why not one node with multiple keywords?** A pattern like `"hello hi hey howdy"` is 4 tokens long. When a user types just `"hello"` (1 word), BUG-004 triggers because the pattern (4 tokens) is longer than the input (1 token). This drops confidence to 0.14–0.25. Four separate single-token nodes each achieve conf=0.33–1.00.

**Pattern:** Create a group of nodes like this:

```
node_greeting_01:  pattern="hello"   →  greet[dont frown]^4 | welcome^2 | smile^1
node_greeting_02:  pattern="hi"      →  greet[dont frown]^4 | welcome^2 | smile^1
node_greeting_03:  pattern="hey"     →  greet[dont frown]^4 | welcome^2 | smile^1
node_greeting_04:  pattern="howdy"   →  greet[dont frown]^4 | welcome^2 | smile^1
node_greeting_05:  pattern="morning" →  greet[dont frown]^4 | welcome^2 | smile^1
```

All nodes share the same weighted action packet, so whichever one matches produces the same voting behavior. The engine picks the highest-confidence match, and with single-token patterns, confidence is always optimal.

**Naming convention:** Use `node_{lobe}_{NN}` (e.g., `node_math_01`, `node_math_02`) so nodes are easy to identify in logs and status output.

### Signal Generation

The `signal` array must have one float per pattern token. The engine uses Julia's `hash()` function to produce these values. In Python, replicate this with:

```python
import struct

def julia_hash(token: str) -> float:
    """Replicate Julia's hash() → Float64 for pattern tokens."""
    h = hash(token)  # Python's hash (64-bit on 64-bit systems)
    if h < 0:
        h += 2**64
    return h / (2**64 - 1)  # Maps to [0.0, 1.0]

def make_signal(pattern: str) -> list:
    words = pattern.split()
    return [julia_hash(w) for w in words]
```

**Important:** The engine's `words_to_signal()` (line 190 of engine.jl) uses `hash(tok) / typemax(UInt64)` which maps each token to a Float64 in [0.0, 1.0]. For single-token patterns, the signal array has exactly one element.

---

## 2. Lobes (`"lobes"`)

Lobes are subject partitions that organize nodes into functional groups. Every node must belong to exactly one lobe.

### Lobe JSON Format

```json
{
  "id": "mathematics",
  "subject": "Mathematical reasoning and computation",
  "node_cap": 15,
  "connections": ["science", "reasoning"],
  "created_at": 1716979200.0
}
```

### Field Reference

| Field | Type | Description |
|---|---|---|
| `id` | string | Unique lobe identifier |
| `subject` | string | Human-readable description |
| `node_cap` | int | Maximum nodes this lobe can hold |
| `connections` | string[] | IDs of connected lobes (bidirectional) |
| `created_at` | float | Unix timestamp of creation |

### Creating Lobes via CLI

```
/newLobe mathematics Mathematical reasoning and computation
/connectLobes mathematics science
```

---

## 3. Lobe Tables (`"lobe_tables"`)

Each lobe has a hash table that maps nodes into chunks for efficient pattern lookup. The format is specific and must match exactly.

### Lobe Table JSON Format

```json
{
  "lobe_id": "mathematics",
  "created_at": 1716979200.0,
  "chunks": {
    "nodes": {
      "node_math_01": {
        "_type": "NodeRef",
        "node_id": "node_math_01",
        "lobe_id": "mathematics",
        "is_active": true,
        "inserted_at": 1716979200.0
      },
      "node_math_02": {
        "_type": "NodeRef",
        "node_id": "node_math_02",
        "lobe_id": "mathematics",
        "is_active": true,
        "inserted_at": 1716979200.0
      }
    }
  }
}
```

**CRITICAL:** The lobe table must use the `chunks` → `nodes` → `NodeRef` structure. The loader calls `get_active_node_ids()` which expects `chunks["nodes"]` to be a dict of NodeRef entries. Using a flat `entries` list will cause a `KeyError("nodes")`.

---

## 4. Rules (`"rules"`)

Stochastic orchestration rules that bias the vote selection process. These control how the engine decides between competing nodes.

### Rule JSON Format

```json
{
  "name": "prefer_high_confidence",
  "condition": "max_confidence > 0.3",
  "action": "boost",
  "weight": 1.2,
  "description": "Boost votes with high confidence"
}
```

---

## 5. Messages (`"messages"`)

Message history for the conversation. Can be empty in a fresh specimen.

```json
[]
```

Or with entries:

```json
[
  {
    "role": "User",
    "content": "hello",
    "pinned": false,
    "timestamp": 1716979200.0
  }
]
```

---

## 6. Verb Registry (`"verb_registry"`)

Maps verb classes to flat lists of verbs. Each class is a key mapping to an array of verb strings.

### CORRECT Format

```json
{
  "action": ["calculate", "solve", "analyze", "reason"],
  "communication": ["greet", "acknowledge", "comfort", "welcome"],
  "cognitive": ["think", "ponder", "elaborate", "clarify"],
  "emotional": ["feel", "worry", "fear", "desire"],
  "motion": ["go", "move", "run", "walk"]
}
```

**CRITICAL:** Each class maps to a **flat array** of verb strings. Do NOT wrap in `{"verbs": [...]}` — the loader will crash with an ArgumentError about broadcasting over dictionaries.

### WRONG Format (DO NOT USE)

```json
{
  "action": {"verbs": ["calculate", "solve"]},
  "communication": {"verbs": ["greet", "acknowledge"]}
}
```

### Adding Verbs via CLI

```
/addVerb calculate action
/addRelationClass spatial
```

---

## 7. Thesaurus (`"thesaurus"`)

Maps canonical words to their alias lists for synonym normalization.

```json
{
  "big": ["large", "huge", "enormous", "vast"],
  "small": ["tiny", "little", "minute", "compact"],
  "fast": ["quick", "rapid", "swift", "speedy"],
  "smart": ["intelligent", "clever", "brilliant", "wise"],
  "good": ["great", "excellent", "fine", "wonderful"]
}
```

### Adding Synonyms via CLI

```
/addSynonym big large
```

---

## 8. Inhibitions (`"inhibitions"`)

Negative thesaurus entries that prevent certain words from triggering specific nodes.

```json
[
  {
    "word": "kill",
    "reason": "Violent language blocked from comfort nodes",
    "added_at": 1716979200.0
  },
  {
    "word": "stupid",
    "reason": "Insult blocked from greeting nodes",
    "added_at": 1716979200.0
  }
]
```

### Managing via CLI

```
/negativeThesaurus add kill --reason Violent language blocked
/negativeThesaurus list
/negativeThesaurus check kill
/negativeThesaurus remove kill
```

---

## 9. Arousal (`"arousal"`)

A single float value [0.0, 1.0] controlling the system's alertness level. Default is 0.5.

```json
0.5
```

### Setting via CLI

```
/arousal 0.7
```

---

## 10. ID Counters (`"id_counters"`)

Controls the auto-increment counters for generating unique node and message IDs.

### CORRECT Format

```json
{
  "node_id_counter": 45,
  "msg_id_counter": 0
}
```

**CRITICAL:** Keys must be `node_id_counter` and `msg_id_counter`. Using `node` and `msg` will cause ID generation to fail silently.

### WRONG Format (DO NOT USE)

```json
{
  "node": 45,
  "msg": 0
}
```

---

## 11. Immune System (`"immune_system"`)

Stores Hopfield pattern signatures and the immune ledger for guarding structural commands.

### CORRECT Format

```json
{
  "hopfield": {},
  "ledger": []
}
```

**CRITICAL:** Must use `hopfield` (dict) and `ledger` (array) keys. Using `signatures` instead of `hopfield` will cause a validation error.

### WRONG Format (DO NOT USE)

```json
{
  "signatures": [],
  "ledger": []
}
```

---

## 12. Brainstem (`"brainstem"`)

Controls the dispatch state for lobe-based processing.

```json
{
  "dispatch_count": 0,
  "last_winner": "",
  "propagation_count": 0,
  "is_dispatching": false
}
```

---

## 13. Trajectory (`"trajectory"`)

Stores the trajectory configuration and buffer for temporal tracking.

### CORRECT Format

```json
{
  "config": {
    "decay_halflife": 120.0,
    "max_buffer_size": 100,
    "context_intensity_baseline": 0.35
  },
  "buffer": []
}
```

**CRITICAL:** Must be a **dict** (object), not an array. The validator checks `isa(specimen["trajectory"], Dict)` and will reject `[]`.

### WRONG Format (DO NOT USE)

```json
[]
```

---

## 14. Chatter Cooldowns (`"chatter_cooldowns"`)

Tracks cooldown timestamps for chatter mode. **Must be an array**, not a dict.

```json
[]
```

---

## 15. Node-to-Lobe Index (`"node_to_lobe_idx"`)

Maps every node ID to its home lobe ID. Every node in the `nodes` array must have an entry here.

```json
{
  "node_math_01": "mathematics",
  "node_phil_01": "philosophy",
  "node_greeting_01": "greeting"
}
```

---

## 16. Sigils (`"sigils"`)

SigilPromoter rules that rewrite input before scanning. Each sigil has a name, pattern, and replacement.

### Sigil JSON Format

```json
[
  {
    "name": "number_word_to_digit",
    "pattern": "\\b(one|two|three|four|five|six|seven|eight|nine|ten)\\b",
    "replacement": "&n",
    "provenance": "specimen"
  },
  {
    "name": "operator_word_to_symbol",
    "pattern": "\\b(plus|minus|times|divided)\\b",
    "replacement": "&op",
    "provenance": "specimen"
  }
]
```

**NOTE:** Sigils with `"provenance": "engine-default"` are skipped during load — they are built into the engine. Only sigils with `"provenance": "specimen"` or any other value are loaded.

---

## 17. Automaton Rules (`"automaton_rules"`)

EphemeralAutomaton escalation rules with multi-step operation sequences.

```json
[
  {
    "id": "math_escalation",
    "trigger_action": "calculate",
    "steps": [
      {"label": "verify", "op": "boost_confidence", "payload": {"factor": 1.2}},
      {"label": "expand", "op": "activate_lobe", "payload": {"lobe_id": "mathematics"}}
    ],
    "jitter_targets": ["node_math_01", "node_math_02"],
    "min_confidence": 0.1
  }
]
```

---

## 18. EphemeralMLP State (`"ephemeral_mlp"`)

The EphemeralMLP is a lightweight neural network that transforms vote lists using learned weights and pattern-matched rules. This is the brain's "second opinion" system.

### Structure

```json
{
  "_meta": {
    "version": "1.2",
    "format": "ephemeral-mlp-v1.2",
    "saved_at": 1716979200.0
  },
  "weights": {
    "w_input_hidden": [ ...192 entries... ],
    "b_hidden": [ ...16 entries... ],
    "w_hidden_output": [ ...16 entries... ],
    "b_output": { "value": 0.0, "jitter_eligible": false, "last_wobble": 0.0 },
    "w_attention": [ ...32 entries... ]
  },
  "rules": [ ... ],
  "novelty_tracker": { ... },
  "input_correlations": { ... },
  "last_activation": "relu",
  "last_novelty_score": 1.0,
  "last_directive_quality": 0.5,
  "last_user_input": "",
  "total_transforms": 0,
  "total_sigmoid_activations": 0,
  "total_relu_activations": 0,
  "right_feedback_count": 0,
  "wrong_feedback_count": 0,
  "selfobserver_observations": 0,
  "observation_threshold": 5,
  "adjustments_enabled": true
}
```

### Weight Dimensions

**CRITICAL:** Weight array lengths must match the engine's constants. Mismatched dimensions cause a `BoundsError` during `from_specimen_dict!`.

| Weight | Dimensions | Entry Count | Description |
|---|---|---|---|
| `w_input_hidden` | VOTE_FEATURE_DIM × HIDDEN_DIM | **192** (12×16) | Input-to-hidden connections |
| `b_hidden` | HIDDEN_DIM | **16** | Hidden layer bias |
| `w_hidden_output` | HIDDEN_DIM | **16** | Hidden-to-output connections |
| `b_output` | 1 (scalar) | **1 (dict)** | Output bias (dict, not array!) |
| `w_attention` | HIDDEN_DIM × ATTENTION_HEADS | **32** (16×2) | Multi-head attention weights |

Constants from `EphemeralMLP.jl`:
- `VOTE_FEATURE_DIM = 12`
- `HIDDEN_DIM = 16`
- `ATTENTION_HEADS = 2`

### Weight Entry Format

Each weight in an array is a dict:

```json
{
  "value": 0.123456,
  "jitter_eligible": true,
  "last_wobble": 0.0
}
```

The `b_output` field is a single dict (not an array):

```json
{
  "value": 0.0,
  "jitter_eligible": false,
  "last_wobble": 0.0
}
```

### MLP Rules

Rules are pattern-matched transformers that apply subject-specific adjustments during the MLP's forward pass.

```json
[
  {
    "id": "math_solid",
    "pattern": "calculate|solve|equation|arithmetic|add|plus|subtract|minus",
    "key": "math_solid",
    "transform_type": "solid",
    "weight": {
      "value": 0.8,
      "jitter_eligible": true
    },
    "payload": {},
    "drop_table": [],
    "fire_count": 0,
    "last_fire_time": 0.0,
    "enabled": true
  }
]
```

**CRITICAL MLP Rule Fields:**

| Field | Required | Description |
|---|---|---|
| `id` | YES | Unique rule identifier |
| `pattern` | YES | Regex pattern for vote matching |
| `key` | YES | Explicit activation key (usually same as `id`) |
| `transform_type` | YES | `"solid"` (relu) or `"fuzzy"` (sigmoid) |
| `weight` | YES | Nested `{"value": float, "jitter_eligible": bool}` |
| `payload` | YES | Arbitrary data dict (can be empty `{}`) |
| `drop_table` | YES | Array of linked rule IDs for cascading |
| `fire_count` | YES | How many times this rule has fired |
| `last_fire_time` | YES | Unix timestamp of last fire (0.0 = never) |
| `enabled` | YES | Whether this rule is active |

**NOTE:** The `key` and `payload` fields are REQUIRED. If `key` is missing, the rule will not be indexed for key-based lookup. If `payload` is missing, `from_specimen_dict!` will fail with a type error.

### Solid vs. Fuzzy Transforms

- **solid** (`relu`): For concrete, deterministic subjects (math, science). Produces sharp, confident outputs.
- **fuzzy** (`sigmoid`): For uncertain, subjective subjects (emotion, speculation). Produces smooth, calibrated outputs.

### Adding MLP Rules via CLI

```
/mlpRule add math_solid solid math_solid
/mlpRule list
/mlpRule drop math_solid
```

---

## 19. MLP Observer Store (`"mlp_observer_store"`)

Controls the SelfObserver gate that determines when MLP adjustments become non-zero.

```json
{
  "total_entries": 0,
  "key_count": 0
}
```

The observation threshold (default: 5) means the MLP needs at least 5 observations before its adjustments take effect. This prevents the MLP from making adjustments based on insufficient evidence.

### Setting via CLI

```
/mlpThreshold 10
/mlpObserver
```

---

## 20. AIML System (`"aiml_system"`)

AIML node tribe data for template-based response generation.

```json
{
  "registry": {},
  "population_caps": {},
  "cycle": 0
}
```

**Required keys:** `registry`, `population_caps`, `cycle`.

---

## Building a Specimen from Scratch

### Step-by-Step Process

1. **Define your lobes.** Decide what subject areas your brain will cover. Create a lobe for each.

2. **Create nodes for each lobe.** Each node needs a unique ID, a space-separated pattern, a valid action, and a system prompt in `json_data`.

3. **Map nodes to lobes.** Create `node_to_lobe_idx` entries and lobe_table NodeRef entries for every node.

4. **Set up verb_registry and thesaurus.** Define the verb classes and synonym mappings that support your node patterns.

5. **Configure the EphemeralMLP.** Create weight arrays with correct dimensions and rules with `key` and `payload` fields.

6. **Add sigils (optional).** Define SigilPromoter rules for input rewriting (e.g., number words → digits).

7. **Fill in boilerplate.** Set `trajectory`, `immune_system`, `id_counters`, `brainstem`, and other required fields to their default values.

8. **Validate.** Load the specimen and check for errors. Run test missions to verify correct routing.

### Python Generator Template

```python
import json, hashlib, time

def make_node(node_id, pattern, action, strength, system_prompt, lobe_hint=""):
    signal = [hash(f"{pattern}_{i}") / 2**64 for i in range(len(pattern.split()))]
    return {
        "id": node_id,
        "pattern": pattern,  # SPACE-SEPARATED words!
        "signal": signal,
        "action_packet": action,
        "json_data": {"system_prompt": system_prompt, "lobe_hint": lobe_hint},
        "drop_table": [],
        "throttle": 0.5,
        "relational_patterns": [],
        "required_relations": [],
        "relation_weights": {},
        "strength": strength,
        "is_image_node": False,
        "neighbor_ids": [],
        "is_unlinkable": False,
        "max_neighbors": 12,
        "is_grave": False,
        "grave_reason": "",
        "response_times": [],
        "ledger_last_cleared": 0.0,
        "hopfield_key": 0,
        "fired_this_cycle": False,
        "voted_this_cycle": False,
        "gained_this_cycle": False,
        "strength_delta_this_cycle": 0.0
    }

def make_lobe(lobe_id, subject, node_cap=15, connections=None):
    return {
        "id": lobe_id,
        "subject": subject,
        "node_cap": node_cap,
        "connections": connections or [],
        "created_at": time.time()
    }

def make_lobe_table(lobe_id, node_ids):
    node_refs = {}
    for nid in node_ids:
        node_refs[nid] = {
            "_type": "NodeRef",
            "node_id": nid,
            "lobe_id": lobe_id,
            "is_active": True,
            "inserted_at": time.time()
        }
    return {
        "lobe_id": lobe_id,
        "created_at": time.time(),
        "chunks": {"nodes": node_refs}
    }

def make_mlp_weights():
    """Create MLP weights with correct dimensions."""
    def weight(val=0.0, jitter=True):
        return {"value": val, "jitter_eligible": jitter, "last_wobble": 0.0}
    
    return {
        "w_input_hidden": [weight(0.01 * (i % 7 - 3)) for i in range(192)],
        "b_hidden": [weight(0.0) for _ in range(16)],
        "w_hidden_output": [weight(0.01 * (i % 5 - 2)) for i in range(16)],
        "b_output": weight(0.0, jitter=False),
        "w_attention": [weight(0.01 * (i % 3 - 1)) for i in range(32)]
    }

def make_mlp_rule(rid, pattern, transform_type, weight_val=0.7, payload=None):
    """Create an MLP rule with required key and payload fields."""
    return {
        "id": rid,
        "pattern": pattern,
        "key": rid,                    # REQUIRED — must match id
        "transform_type": transform_type,
        "weight": {"value": weight_val, "jitter_eligible": True},
        "payload": payload or {},      # REQUIRED — can be empty dict
        "drop_table": [],
        "fire_count": 0,
        "last_fire_time": 0.0,
        "enabled": True
    }

# Build specimen
nodes = []
lobes = []
lobe_tables = []
node_to_lobe = {}

# Create lobes and nodes
math_lobe = make_lobe("mathematics", "Mathematical reasoning")
lobes.append(math_lobe)

math_nodes = [
    make_node("node_math_01", "calculate solve equation arithmetic", "reason", 0.8,
              "Grug computes carefully and verifies each step.", "mathematics"),
    make_node("node_math_02", "multiply times product divide fraction", "elaborate", 0.75,
              "Grug works through multiplication step by step.", "mathematics"),
]
nodes.extend(math_nodes)
for n in math_nodes:
    node_to_lobe[n["id"]] = "mathematics"
lobe_tables.append(make_lobe_table("mathematics", [n["id"] for n in math_nodes]))

# ... repeat for other lobes ...

specimen = {
    "_meta": {"version": "2.7", "saved_at": time.time(), "format": "grugbot420-specimen-v2.7"},
    "nodes": nodes,
    "lobes": lobes,
    "lobe_tables": lobe_tables,
    "rules": [],
    "messages": [],
    "verb_registry": {
        "action": ["calculate", "solve", "analyze", "reason"],
        "communication": ["greet", "acknowledge", "comfort", "welcome"],
        "cognitive": ["think", "ponder", "elaborate", "clarify"],
        "emotional": ["feel", "worry", "fear", "desire"],
        "motion": ["go", "move", "run", "walk"]
    },
    "thesaurus": {},
    "inhibitions": [],
    "arousal": 0.5,
    "id_counters": {"node_id_counter": len(nodes), "msg_id_counter": 0},
    "immune_system": {"hopfield": {}, "ledger": []},
    "brainstem": {"dispatch_count": 0, "last_winner": "", "propagation_count": 0, "is_dispatching": False},
    "trajectory": {"config": {"decay_halflife": 120.0, "max_buffer_size": 100, "context_intensity_baseline": 0.35}, "buffer": []},
    "chatter_cooldowns": [],
    "node_to_lobe_idx": node_to_lobe,
    "ephemeral_mlp": {
        "_meta": {"version": "1.2", "format": "ephemeral-mlp-v1.2", "saved_at": time.time()},
        "weights": make_mlp_weights(),
        "rules": [
            make_mlp_rule("math_solid", r"calculate|solve|equation", "solid", 0.8),
        ],
        "novelty_tracker": {"history": [], "hash_counts": [], "total_observations": 0},
        "input_correlations": {"entries": [], "input_quality_ema": [], "total_correlations": 0},
        "last_activation": "relu",
        "last_novelty_score": 1.0,
        "last_directive_quality": 0.5,
        "last_user_input": "",
        "total_transforms": 0,
        "total_sigmoid_activations": 0,
        "total_relu_activations": 0,
        "right_feedback_count": 0,
        "wrong_feedback_count": 0,
        "selfobserver_observations": 0,
        "observation_threshold": 5,
        "adjustments_enabled": True
    },
    "mlp_observer_store": {"total_entries": 0, "key_count": 0},
    "aiml_system": {"registry": {}, "population_caps": {}, "cycle": 0},
}

with open("my_specimen.specimen.json", "w") as f:
    json.dump(specimen, f, indent=2)
```

---

## Building a Specimen via CLI Commands

Instead of writing JSON by hand, you can build a specimen interactively using CLI commands, then save it.

### Step 1: Create Lobes

```
/newLobe mathematics Mathematical reasoning and computation
/newLobe philosophy Philosophical inquiry and contemplation
/newLobe science Scientific analysis and explanation
/connectLobes mathematics science
```

### Step 2: Grow Nodes into Lobes

**Best practice: one pattern word per node, shared action packets across synonym nodes.**

```
/grow mathematics {"pattern":"calculate","action_packet":"reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1","data":{"system_prompt":"Grug computes carefully and verifies each step."}}
/grow mathematics {"pattern":"solve","action_packet":"reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1","data":{"system_prompt":"Grug computes carefully and verifies each step."}}
/grow mathematics {"pattern":"multiply","action_packet":"reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1","data":{"system_prompt":"Grug works through multiplication step by step."}}
/grow mathematics {"pattern":"times","action_packet":"reason[dont guess, show work]^4 | elaborate[be precise]^2 | explain^1","data":{"system_prompt":"Grug works through multiplication step by step."}}
/grow philosophy {"pattern":"consciousness","action_packet":"ponder[dont dismiss, explore depth]^4 | reason[be thoughtful]^2 | explain^1","data":{"system_prompt":"Grug contemplates the deep questions."}}
/grow philosophy {"pattern":"meaning","action_packet":"ponder[dont dismiss, explore depth]^4 | reason[be thoughtful]^2 | explain^1","data":{"system_prompt":"Grug contemplates the deep questions."}}
```

### Step 3: Add Verbs and Synonyms

```
/addVerb calculate action
/addVerb solve action
/addSynonym big large
```

### Step 4: Add MLP Rules

```
/mlpRule add math_solid solid math_solid
/mlpRule add philosophy_fuzzy fuzzy philosophy_fuzzy
```

### Step 5: Add Inhibitions

```
/negativeThesaurus add kill --reason Violent language blocked
```

### Step 6: Test and Save

```
/mission calculate 2 plus 3
/mission what is consciousness
/status
/saveSpecimen my_specimen.specimen.json
```

---

## Common Pitfalls and Fixes

### 1. `trajectory` must be a Dict, not an Array

**Error:** `ArgumentException("trajectory must be a dict")`  
**Fix:** Use `{"config": {...}, "buffer": []}` instead of `[]`

### 2. `verb_registry` classes must be flat arrays

**Error:** `ArgumentException("broadcasting over dictionaries")`  
**Fix:** Use `{"action": ["calculate", "solve"]}` instead of `{"action": {"verbs": ["calculate", "solve"]}}`

### 3. `id_counters` must use `node_id_counter` and `msg_id_counter`

**Error:** Nodes get duplicate IDs or wrong counter values  
**Fix:** Use `{"node_id_counter": N, "msg_id_counter": 0}` instead of `{"node": N, "msg": 0}`

### 4. `immune_system` must use `hopfield` key

**Error:** Validation error during load  
**Fix:** Use `{"hopfield": {}, "ledger": []}` instead of `{"signatures": [], "ledger": []}`

### 5. Lobe tables must use `chunks.nodes` format

**Error:** `KeyError("nodes")` in `get_active_node_ids`  
**Fix:** Use `{"chunks": {"nodes": {node_id: NodeRef}}}` instead of flat `entries` list

### 6. MLP weight dimensions must match engine constants

**Error:** `BoundsError` in `from_specimen_dict!`  
**Fix:** w_input_hidden=192, b_hidden=16, w_hidden_output=16, b_output=dict, w_attention=32

### 7. MLP rules must include `key` and `payload`

**Error:** Rule skipped or type error during load  
**Fix:** Every rule needs `"key": rule_id` and `"payload": {}`

### 8. Node patterns must use space-separated words

**Error:** Node never fires despite pattern matching input  
**Fix:** Use `"calculate"` instead of `"calculate|solve|equation"`  
**Reason:** The `fire_one` closure splits patterns by whitespace to check for literal token overlap with input. Pipe-delimited patterns produce a single token that never matches.

### 8b. Multi-word patterns cause low confidence (BUG-004)

**Error:** Node fires but with very low confidence (0.14–0.25) despite pattern matching  
**Fix:** Use single-token patterns (one word per node) and create multiple nodes for concept variants  
**Reason:** When `length(node.signal) > length(input_signal)`, the engine swaps scan roles (BUG-004), dramatically lowering confidence. Single-token patterns completely avoid this. See "BUG-004: Pattern Length vs Input Length" section for details.

### 9. `chatter_cooldowns` must be an array

**Error:** Type error during load  
**Fix:** Use `[]` instead of `{}`

### 10. `b_output` must be a dict, not an array

**Error:** Type error or BoundsError in MLP weight parsing  
**Fix:** Use `{"value": 0.0, "jitter_eligible": false, "last_wobble": 0.0}` instead of an array

---

## File Format

Specimen files use the `.specimen.json` extension (or `.specimen.json.gz` for gzip-compressed files). The JSON is pretty-printed with 2-space indentation for readability.

The `_meta` field tracks the format version:

```json
{
  "version": "2.7",
  "saved_at": 1716979200.0,
  "format": "grugbot420-specimen-v2.7"
}
```

---

## Testing Your Specimen

After creating a specimen, always test it with a comprehensive set of missions:

1. **Load the specimen** and check the summary for expected node/lobe counts
2. **Test each lobe** with inputs matching its node patterns
3. **Test multipart queries** that cross lobe boundaries
4. **Check MLP status** with `/mlpStatus` to verify rules loaded correctly
5. **Check system status** with `/status` for overall health
6. **Verify no errors** — any BoundsError, KeyError, or validation error means the specimen has a structural issue

### Test Script Template

```
/loadSpecimen grug-binary/my_specimen.specimen.json
/mission hello
/mission calculate 2 plus 3
/mission what is consciousness
/mission I feel sad today
/mission step first add 7 and 3 then multiply by 5
/mlpStatus
/status
/nodes
/saveSpecimen grug-binary/test_output.specimen.json
/exit
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────┐
│                    SPECIMEN                      │
├─────────────────────────────────────────────────┤
│  NODES (45)     │ Pattern-matchable tokens      │
│  LOBES (12)     │ Subject partitions            │
│  LOBE_TABLES    │ Hash tables for node lookup   │
│  VERB_REGISTRY  │ Semantic verb classes          │
│  THESAURUS      │ Synonym normalization          │
│  INHIBITIONS    │ Negative filter entries        │
│  SIGILS         │ Input rewriting rules          │
├─────────────────────────────────────────────────┤
│  EPHEMERAL MLP                                  │
│  ├── WEIGHTS    │ 12×16×2 neural network        │
│  ├── RULES (9)  │ Pattern-matched transformers  │
│  ├── NOVELTY    │ Input novelty tracker          │
│  └── OBSERVER   │ Adjustment gate                │
├─────────────────────────────────────────────────┤
│  AUTOMATON      │ Escalation rule sequences      │
│  BRAINSTEM      │ Lobe dispatch state            │
│  TRAJECTORY     │ Temporal tracking config       │
│  IMMUNE SYSTEM  │ Hopfield + ledger              │
│  AIML SYSTEM    │ Template response tribes       │
│  TONAL JUDGE    │ Emotional calibration          │
└─────────────────────────────────────────────────┘
```

---

## CLI Command Reference

| Command | Description |
|---|---|
| `/mission <text>` | Send input to the AI engine |
| `/brainstorm <text>` | Like /mission with heavy jitter |
| `/grow <lobe> <json>` | Plant nodes from JSON packet |
| `/wrong` | Penalize last contributors |
| `/right` | Reward last contributors |
| `/nodes` | Show all node map status |
| `/status` | Full system health snapshot |
| `/lobes` | Show lobe status summary |
| `/newLobe <id> <subject>` | Create new subject partition |
| `/connectLobes <a> <b>` | Link two lobes bidirectionally |
| `/addVerb <verb> <class>` | Add verb to relation class |
| `/addRelationClass <name>` | Create new verb class bucket |
| `/addSynonym <canon> <alias>` | Register synonym normalization |
| `/listVerbs` | Show verb registry |
| `/mlpStatus` | Show MLP brain status |
| `/mlpRule add/drop/list` | Manage MLP rules |
| `/mlpThreshold <n>` | Set observer threshold |
| `/mlpObserver` | Show observer store stats |
| `/saveSpecimen <path>` | Save cave state to file |
| `/loadSpecimen <path>` | Restore cave from file |
| `/arousal <0.0-1.0>` | Set alertness level |
| `/help` | Show all commands |
| `/quit` or `/exit` | Close cave and exit |
