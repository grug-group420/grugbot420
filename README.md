# 🧠 grugbot420

[![CI](https://github.com/grug-group420/grugbot420/actions/workflows/CI.yml/badge.svg)](https://github.com/grug-group420/grugbot420/actions/workflows/CI.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Julia](https://img.shields.io/badge/Julia-1.9%2B-blue.svg)](https://julialang.org)


A neuromorphic AI engine written in Julia. GrugBot models cognition through competing populations of pattern nodes — not if-else waterfalls, not transformers, not lookup tables. Many rocks compete to be loudest. Loudest rock gets to talk. Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.

---


---

## Quick Start

Download the prebuilt binary from [`grug-binary/`](./grug-binary/):

```bash
chmod +x grugbot420
./grugbot420
```

Requires [Julia 1.9+](https://julialang.org/downloads/) on your PATH. First run detects a missing Julia install, opens the download page, and waits. Every run after that goes straight to the `Brain >` prompt.

---

## CLI Commands

### Core

| Command | What it does |
|---|---|
| `/mission <text>` | Send input to the engine. This is the main command. Also accepts image binary (Base64 or hex). |
| `/wrong` | Tell GrugBot its last response was bad. Penalizes every node that voted via coinflip strength decay. Nodes that reach 0 become graves. |
| `/explicit <cmd> [<node_id>] <text>` | Force a specific command+node combination, bypassing the vote system. |
| `/grow <json>` | Plant one or more new nodes from a JSON packet (see format below). |
| `/addRule <rule text> [prob=0.0-1.0]` | Add a stochastic orchestration rule. Fires with given probability on every response. Supports template tags. |
| `/pin <text>` | Pin text permanently to the memory cave wall. Pinned messages survive the 10,000-message rolling window. |

### Status & Inspection

| Command | What it does |
|---|---|
| `/nodes` | Show all nodes: ID, pattern, strength, neighbor count, grave status. |
| `/status` | Full system health snapshot: node count, Hopfield cache, memory estimate, lobe summary, BrainStem stats, ChatterMode stats. |
| `/arousal <0.0-1.0>` | Manually set the EyeSystem arousal level. Higher arousal = tighter visual attention cutout. |

### Semantic Verbs

| Command | What it does |
|---|---|
| `/addVerb <verb> <class>` | Add a verb to a relation class (e.g. `/addVerb triggers causal`). Takes effect immediately on next `/mission`. |
| `/addRelationClass <name>` | Create a new verb class bucket (e.g. `/addRelationClass epistemic`). |
| `/addSynonym <canonical> <alias>` | Register a synonym normalization (e.g. `/addSynonym causes triggers`). Alias is rewritten to canonical before triple extraction. |
| `/listVerbs` | Dump all registered verb classes, their verbs, and synonym mappings. |

### Lobes & Tables

| Command | What it does |
|---|---|
| `/newLobe <id> <subject>` | Create a new subject partition (e.g. `/newLobe language "natural language processing"`). Cap: 20,000 nodes per lobe, 64 lobes max. |
| `/connectLobes <id_a> <id_b>` | Link two lobes bidirectionally. BrainStem uses connections for lateral signal propagation (60% decay per hop). |
| `/lobeGrow <lobe_id> <json>` | Grow a node directly into a specific lobe. JSON must have `pattern` and `action_packet` fields. |
| `/lobes` | Show all lobes: node counts, connection graph, fire counts. |
| `/tableStatus <lobe_id>` | Show hash table chunk sizes for a lobe (nodes, json, drop, hopfield, meta chunks). |
| `/tableMatch <lobe_id> <chunk> <pattern>` | Pattern-activate entries in a lobe's hash table. Use `node_id` for prefix match, any other token for token match. |

### Thesaurus

| Command | What it does |
|---|---|
| `/thesaurus <word1> \| <word2>` | Dimensional similarity comparison: overall %, semantic %, contextual %, associative %, confidence %. |
| `/thesaurus <w1> \| <w2> :: <ctx1> :: <ctx2>` | Same comparison with context lists (comma-separated) to modulate scoring. |

### Negative Thesaurus (Inhibition Filter)

| Command | What it does |
|---|---|
| `/negativeThesaurus add <word> [--reason <text>]` | Register a word as inhibited. Filtered from input before scan. |
| `/negativeThesaurus remove <word>` | Remove a word from the inhibition list. |
| `/negativeThesaurus list` | Show all inhibited words with reasons and timestamps. |
| `/negativeThesaurus check <word>` | Quick check if a word is currently inhibited. |
| `/negativeThesaurus flush` | Clear all inhibitions at once. |

### Relational Fire (Node Attachments)

| Command | What it does |
|---|---|
| `/nodeAttach <target> <id1> <pattern1> [<id2> <pattern2> ...]` | Attach up to 4 nodes to a target node. When the target fires during `scan_and_expand`, each attached node does a strength-biased coinflip to decide if it should fire too. Patterns support quoted multi-word strings (e.g. `"deep learning"`). |
| `/nodeDetach <target> <attach_id>` | Remove a specific attachment from a target node. |
| `/attachments` | Show the full attachment map — every target and its attached nodes with patterns and slot usage. |

### Specimen Persistence (Long-Term Storage)

| Command | What it does |
|---|---|
| `/saveSpecimen <filepath>` | Freeze the entire cave state to a gzip-compressed JSON file. Every node, lobe, rule, message, verb, thesaurus entry, inhibition, attachment, arousal level, trajectory state, temporal coherence, and morph cooldowns — everything. |
| `/loadSpecimen <filepath>` | Restore the entire cave state from a previously saved specimen file. **Destructive** — current state is wiped and replaced (full brain transplant). |

### Help

```
/help
```

Prints the full command reference inside the CLI.

---

## Growing Nodes (`/grow`)

Nodes are the atomic unit of GrugBot. Each node has a pattern (the text it matches against), an action packet (what it does when it fires), optional JSON data, and an optional drop table (co-activation neighbors).

**JSON packet format:**

```json
{
  "nodes": [
    {
      "pattern": "machine learning neural network",
      "action_packet": "reason[dont hallucinate]^4 | analyze^2 | explain^1",
      "data": {
        "system_prompt": "Technical ML domain active.",
        "required_relations": ["uses"],
        "relation_weights": {"uses": 2.0}
      },
      "drop_table": []
    }
  ]
}
```

**Action packet format:** `action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight`

- Actions: `reason`, `analyze`, `ponder`, `calculate`, `greet`, `welcome`, `smile`, `laugh`, `flee`, `hide`, `fight`, `explain`, `clarify`, `describe`, `define`, `elaborate`, `comfort`, `support`, `validate`, `acknowledge`, `reassure`, `alert`, `warn`, `caution`, `notify`, `flag`
- Negatives in `[...]` are constraints injected into the AIML payload
- `^weight` sets the relative voting weight for the superposition orchestrator

**Example:**

```
/grow {"nodes":[{"pattern":"sad unhappy depressed","action_packet":"comfort[dont dismiss]^3 | validate^2 | support^1","data":{"system_prompt":"Emotional support mode active."}}]}
```

---

## Specimen Persistence (`/saveSpecimen` + `/loadSpecimen`)

GrugBot supports full long-term persistence via specimen files. A specimen file is a **gzip-compressed JSON** snapshot of the entire cave state — every node, lobe, rule, message, verb, thesaurus entry, inhibition, and more. Save your cave at any time, share it with others, or restore it later.

### Saving

```
/saveSpecimen mycave.specimen.gz
```

This freezes the entire cave state into `mycave.specimen.gz`. The file contains compressed JSON covering all 17 state categories (v2.1 format).

### Loading (Restoring)

```
/loadSpecimen mycave.specimen.gz
```

**This is a destructive operation** — current cave state is completely wiped and replaced with the specimen file contents. Think of it as a full brain transplant.

The file is validated before any state is wiped. If validation fails, zero changes are made.

### What gets saved/restored

| # | State Category | Description |
|---|---|---|
| 1 | **nodes** | Full Node structs — id, pattern, signal, action_packet, strength, neighbors, graves, drop_table, response_times, hopfield_key, relational_patterns, throttle, json_data |
| 2 | **hopfield_cache** | Familiar input fast-path cache with hit counts (UInt64 hash → node IDs) |
| 3 | **rules** | AIML_DROP_TABLE stochastic orchestration rules (text + fire probability) |
| 4 | **message_history** | Up to 10,000 ChatMessage entries with pin flags preserved |
| 5 | **lobes** | LOBE_REGISTRY — subject, node_ids, connected_lobe_ids, fire/inhibit counts |
| 6 | **node_to_lobe_idx** | NODE_TO_LOBE_IDX reverse index (node → lobe mapping) |
| 7 | **lobe_tables** | LOBE_TABLE_REGISTRY with all chunks (nodes, json, drop, hopfield, meta) and NodeRef objects |
| 8 | **verb_registry** | SemanticVerbs — all verb classes, verbs, and synonym normalizations |
| 9 | **thesaurus_seeds** | Thesaurus SYNONYM_SEED_MAP (hardcoded defaults + runtime additions) |
| 10 | **inhibitions** | InputQueue NegativeThesaurus entries (word, reason, timestamp) |
| 11 | **arousal** | EyeSystem arousal state (level, decay_rate, baseline) |
| 12 | **id_counters** | NODE ID_COUNTER and MSG_ID_COUNTER atomic values |
| 13 | **brainstem** | BrainStem dispatch count and propagation history |
| 14 | **attachments** | ATTACHMENT_MAP — target→attached node mappings with patterns and pre-baked signal vectors |
| 15 | **trajectory** | ActionTonePredictor ring buffer + config — behavioral inertia through action-tone space (Lorenz damping) |
| 16 | **temporal_coherence** | ImageSDF TEMPORAL_COHERENCE_LEDGER — SDF timing patterns and coherence scores |
| 17 | **morph_cooldowns** | ChatterMode MORPH_COOLDOWN_MAP — 24h morph cooldown timestamps per node |

### Restore order

`id_counters` → `verb_registry` → `thesaurus_seeds` → `lobes` → `lobe_tables` → `nodes` → `node_to_lobe_idx` → `hopfield_cache` → `rules` → `inhibitions` → `message_history` → `arousal` → `brainstem` → `attachments` → `trajectory` → `temporal_coherence` → `morph_cooldowns`

This ensures upstream entities exist before downstream references (e.g., lobes exist before nodes reference them).

### File format

- **Extension convention:** `.specimen.gz` (not enforced, any path works)
- **Compression:** gzip (system `gzip`/`gunzip` via pipeline — no extra Julia packages)
- **Content:** JSON with pretty-print indentation (human-readable when decompressed)
- **Metadata:** `_meta` section records version, timestamp, and format identifier

---

## Relational Fire System (`/nodeAttach` & `/imgnodeAttach`)

The relational fire system lets you wire nodes into explicit firing chains. When a target node fires during `scan_and_expand`, its attached nodes each do a strength-biased coinflip to decide whether they should fire too. Think of it as user-defined relay circuitry overlaid on top of the stochastic scan.

### Attaching Text Nodes

```
/nodeAttach node_0 node_1 "machine learning" node_2 "gradient descent"
```

This attaches `node_1` and `node_2` to `node_0`. The patterns (`"machine learning"`, `"gradient descent"`) are **connector patterns** — middleman reasons that explain WHY these nodes are related to the target.

### JIT Confidence Baking

Confidence is computed **once at attach time** (JIT), not every fire cycle. When you issue `/nodeAttach`, the engine immediately:
1. Scans the connector pattern against the **attached node's own pattern** (Jaccard token overlap)
2. Adds a strength bonus: `(attachment_strength / STRENGTH_CAP) * 0.5`
3. Stores the result as `base_confidence` in the `AttachedNode` struct

When `node_0` fires:
1. Each attachment does a **strength-biased coinflip**: `scan_prob = 0.20 + (strength / STRENGTH_CAP) * 0.70`
2. Winners use the **pre-baked** `base_confidence` with stochastic jitter: `confidence = max(0.1, base_confidence + randn() * 0.05)` — floor of 0.1 so attachments always have *some* voice; small jitter keeps vote pool diverse
3. The connector pattern surfaces downstream as a `RelationalTriple(target_id, "relay_attached", connector_pattern)` so the generative pipeline knows WHY the relay fired
4. The **active cap** (biological attention bottleneck, `rand(600:1800)`) is respected — if the relay pass hits the cap, remaining attachments are skipped

### Attaching Image Nodes (`/imgnodeAttach`)

```
/imgnodeAttach node_0 img_node_1 "data:image/png;base64,iVBOR..." 64 64
```

Does everything `/nodeAttach` does but for **image nodes**. Instead of text connector patterns, uses image binary converted to **nonlinear SDF** at attach time via real GPU kernel dispatch:
1. Image binary is detected and decoded from the input (Base64 data URI, hex dump, or raw bytes)
2. Converted to `SDFParams` via **`JITGPU(binary; width, height)`** — real `KernelAbstractions.jl` kernel dispatch. Backend selected at runtime: `CUDABackend()` (NVIDIA), `ROCBackend()` (AMD), `MetalBackend()` (Apple Silicon), or `CPU()` multithreaded fallback on CI/no-GPU. Two-pass kernel: parallel pixel decode → `synchronize` → parallel `tanh(3×grad_mag)` SDF activation
3. Flattened to a signal vector via `sdf_to_signal()` for PatternScanner compatibility
4. `base_confidence` is baked from **SDF cosine similarity** between the connector signal and the attached image node's own signal, plus strength bonus
5. The attached node **must** be an image node (`is_image_node=true`); text nodes are rejected with an explicit error

Width and height can be omitted (defaults to 8×8) but should be specified for accurate SDF conversion.

### Constraints & Validation

- **Max 4 attachments** per target node (hard cap)
- Target and attachment nodes must exist on the map and must not be graves
- A node cannot attach to itself
- Duplicate attachments are rejected
- `/nodeAttach`: patterns support quoted multi-word strings
- `/imgnodeAttach`: attach node must be an image node; image data must not be empty; dimensions must be > 0
- Every error is explicit — no silent failures

### Detaching

```
/nodeDetach node_0 node_1
/imgnodeDetach node_0 img_node_1
```

Removes the attached node from the target's attachment list. `/imgnodeDetach` reuses the same `detach_node!` function — both text and image attachments live in the same `ATTACHMENT_MAP`. If that was the last attachment, the target's entry is cleaned up entirely.

### Viewing Attachments

```
/attachments
```

Prints every target and its attached nodes with `base_confidence`, connector patterns, signal vector lengths, and slot usage (`N/4`).

### Pipeline Integration (Pass 3)

The attachment relay runs as **Pass 3** in `scan_and_expand()`, after the primary scan (Pass 1) and lobe cascade (Pass 2). It iterates every node in the expanded set, checks for attachments, and fires winners into the vote pool. Deduplication ensures no node appears twice. The relay has its own independent `active_cap` sample.

### Specimen Persistence

Attachments are fully serialized in `/saveSpecimen` (section 14) and restored in `/loadSpecimen` (section 4.14). Each attachment entry stores `target_id`, `node_id`, `pattern`, `signal`, and the JIT-baked `base_confidence`. On load, if `base_confidence` is missing (backward compatibility), it is re-computed: text attachments re-run `_token_overlap_similarity`, image attachments use `_sdf_signal_similarity`, with strength bonus added. If the signal vector is also missing, it is re-baked from the pattern via `words_to_signal`.

---

## Adding Orchestration Rules (`/addRule`)

Rules are injected into every response payload. They support template tags and fire stochastically.

**Template tags:** `{MISSION}`, `{PRIMARY_ACTION}`, `{SURE_ACTIONS}`, `{UNSURE_ACTIONS}`, `{ALL_ACTIONS}`, `{CONFIDENCE}`, `{NODE_ID}`, `{MEMORY}`, `{LOBE_CONTEXT}`

**Examples:**

```
/addRule Always ground responses in {MISSION} before expanding.
/addRule If confidence {CONFIDENCE} is below 0.5, hedge your answer. [prob=0.7]
/addRule Current lobe state: {LOBE_CONTEXT} — use cross-domain reasoning. [prob=0.5]
```

Rules with no `[prob=X]` suffix default to `prob=1.0` (always fire).

---

## Idle Behavior (v7.1 — Slow Timer)

When the cave has been quiet for ~120 seconds (±30s jitter), GrugBot runs an idle action automatically — a 50/50 coinflip between:

- **Chatter (1000+ nodes only):** 50–500 node clones gossip and exchange patterns. Only **weak** nodes morph — receivers must be weaker than senders. Each node can only morph **once per 24 hours** (cooldown enforced). New specimens with < 1000 nodes skip chatter entirely.
- **Phagy (1000+ nodes only):** One maintenance automaton runs (orphan pruning, strength decay, grave recycling, cache validation, drop table compaction, rule pruning, or memory forensics).

Both chatter and phagy share the same slow idle timer and the same 1000+ node population gate. New specimens with < 1000 nodes skip all idle actions entirely. If fewer than 50 eligible nodes exist in a chatter round, the group size floors at whatever is available. You don't need to trigger this manually. It runs between CLI prompts.

---


## Specimen Immune System

Once a specimen reaches maturity (≥ 1000 nodes), an automata-based immune system activates to protect the node population from funky inputs. This is not adversarial security — it's biological: tolerance-based, stochastic, and imperfect by design.

### How It Works

1. **AST Scan**: Every `/grow` and `/lobeGrow` command gets a high-resolution structural scan before touching anything. The scan produces an AST signature — a structural fingerprint of the input.

2. **Hopfield Immune Memory**: Non-funky signatures are stored in an attractor memory. Repeated safe inputs strengthen their basin, making future recognition instant.

3. **Funky Detection**: If a signature doesn't match known patterns in the immune Hopfield memory, it's flagged as funky.

4. **Population Coinflip**: Funky inputs trigger an automata population (1/3 of node count). Each agent coinflips independently (50/50) before intervening — this prevents explosion.

5. **Quarantine → Patch → Delete**: Materialized agents quarantine the input, attempt structural patching within a stochastic timer, and delete on failure.

6. **No Silent Failures**: Every decision — funky detection, coinflip skip, patch success, patch failure, deletion — is logged in an append-only immune ledger. Nothing happens in the dark.

### Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `MATURITY_THRESHOLD` | 1000 | Immune system sleeps below this node count |
| `AUTOMATA_POPULATION_RATIO` | 1/3 | Automata count = nodes ÷ 3 |
| `COINFLIP_PROBABILITY` | 0.5 | Per-agent materialization probability |
| `PATCH_TIMEOUT_SECONDS` | 2.0 | Max time for patch attempt (± 0.5s jitter) |
| `HOPFIELD_FAMILIARITY_THRESHOLD` | 3 | Sightings needed before a signature is "strongly known" |

### CLI Integration

The immune system gates `/grow` and `/lobeGrow` commands automatically. When it rejects an input, you'll see:

```
[IMMUNE] ⛔ /grow REJECTED by immune system: Funky input failed patching and was deleted
```

Immune state (Hopfield memory + ledger) is saved/restored with `/saveSpecimen` and `/loadSpecimen`.

Full specification: [`docs/immune_system.html`](./docs/immune_system.html)

---

## File Reference

| File | Role |
|---|---|
| `src/Main.jl` | Entry point. CLI loop, memory cave, mission processor, idle manager, specimen persistence. |
| `src/engine.jl` | Core node engine: node creation, scanning, voting, Hopfield cache, drop-table expansion, relational fire (JIT confidence baking, SDF image attachments). |
| `src/stochastichelper.jl` | `@coinflip` macro and `bias()` helper for weighted probabilistic branching. |
| `src/patternscanner.jl` | Signal-level pattern matching: `cheap_scan`, `medium_scan`, `high_res_scan`. Scan tier selected per-node based on input + pattern complexity. Tier-1 nodes use `_bidirectional_cheap_scan` (forward + reverse, smoothed confidence). |
| `src/Lobe.jl` | Subject-specific node partitions with O(1) reverse index. |
| `src/LobeTable.jl` | Per-lobe chunked hash table storage (nodes, json, drop, hopfield, meta chunks). |
| `src/BrainStem.jl` | Winner-take-all dispatcher with cross-lobe signal propagation and fire-count decay. |
| `src/Thesaurus.jl` | Dimensional similarity engine with seed synonym dictionary, gate filter, and runtime seed injection. |
| `src/InputQueue.jl` | FIFO input queue and NegativeThesaurus inhibition filter. |
| `src/ChatterMode.jl` | Idle gossip system (v7.1): 50–500 ephemeral clones, 1000+ node gate, weak-only morph, 24h cooldown, 120s±30s shared timer. |
| `src/PhagyMode.jl` | Seven idle-time maintenance automata for self-healing map management (includes memory forensics). |
| `src/EyeSystem.jl` | Visual attention: edge blurring, arousal-gated center cutout, attention modulation. |
| `src/ImageSDF.jl` | `JITGPU(binary)` — real KernelAbstractions.jl GPU kernel dispatch for image→SDF conversion. CPU reference path (`image_to_sdf_params`) kept for backward compat. |
| `src/SemanticVerbs.jl` | Live mutable verb registry: causal, spatial, temporal classes + runtime synonyms. |
| `src/ActionTonePredictor.jl` | Pre-vote input classifier: predicts action type and tone, nudges arousal and confidence weights. |
| `src/ImmuneSystem.jl` | Specimen immune system: automata-based anomaly handling for growth/ledger commands. AST scanning, Hopfield immune memory, quarantine-patch-delete pipeline. |
| `grugbot_whitepaper.html` | Full technical documentation and architecture reference. |

---

## Documentation

Open `grugbot_whitepaper.html` in a browser for the full technical whitepaper covering architecture, formal mathematics, all subsystems, and design rationale.

See [`docs/immune_system.html`](./docs/immune_system.html) for the immune system specification (grug analogy, academic details, math/lambda, flowchart).

---

## Notes on Seeding

The first ~100 nodes you plant are the specimen's DNA. Before hitting 1,000 nodes, automatic neighbor latching is suppressed — you control topology manually via drop tables. Recommendations:

1. Seed orthogonal archetypes first — distinct semantic poles, not 50 near-identical nodes
2. Use `required_relations` as semantic gates from day one so nodes don't fire on noise
3. Name action packets deliberately — distinct action families give the superposition orchestrator something meaningful to work with
4. Wire drop tables manually for known co-activation pairs
5. The engine enforces structure at scale (1,000+ nodes). You enforce meaning at the start.