NOTE: readme and binary are outdated I hadn't had time to update I been busy with auto growth mechanics. Source still works in Julia just hadn't updated the binary or documentation.
# 🧠 grugbot420

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Julia](https://img.shields.io/badge/Julia-1.9%2B-blue.svg)](https://julialang.org)
[![Version](https://img.shields.io/badge/version-v8.0-brightgreen.svg)](#whats-new-in-v80)


<!-- ⚠️ ARCHITECTURE REMINDERS ⚠️ -->
<!-- 1. ANTIMATCH NODES WERE REMOVED — do not reference, implement, or assume they exist -->
<!-- 2. SIGILS CAN APPEAR IN RELATIONAL TRIPLES — triples are dynamic, not just literal strings -->
<!-- 3. HOPFIELD CACHING WAS REMOVED — hopfield_key is a dead field for specimen compat only -->

A neuromorphic AI engine written in Julia. GrugBot models cognition through competing populations of pattern nodes — not if-else waterfalls, not transformers, not lookup tables. Many rocks compete to be loudest. Loudest rock gets to talk. Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.

---

## What's New in v7.24

**Decoherence Fix Release** — five critical bugs squashed that were causing incoherent responses across arithmetic, voice, lobe routing, and support text:

- **BUG-5 (CRITICAL):** Arithmetic engine now fires across `@spawn` Task boundaries. Module-level Refs with ReentrantLock replace broken task-local storage for sigil promotion binding handoff. `calculate ten plus five plus seven` → `10+5=15, 15+7=22` ✓
- **BUG-6:** Voice prefix no longer leaks raw system_prompt persona tags into response body. The first sentence of `system_prompt` is an internal frame for TonalJudge, not speech for the user.
- **BUG-7:** Authored `voice_body` prose is now preserved verbatim — `_swap_words_in` and `_reorder_clauses` are both skipped for voice_body claims. No more "petite answers" when the operator wrote "small answers".
- **BUG-8:** Circular pattern-token triples are suppressed in support text. No more "The link is clear: calculate compute number" echo garbage.
- **BUG-2v2:** Default lobe demotion now triggers when any named lobe has `base_avg > 0.0` (not the old `hard_votes >= 1` threshold). Named lobes win their territory on even marginal matches.

---

## What's New in v7.19

**Vote-Swap Chatter Mode** — at idle, weak nodes can adopt vote actions (not patterns) from semantically-similar strong neighbors:

- **Groups** — every new node tries to latch onto a similar-pattern partner via a strength-biased coinflip; each node has its own per-node neighbor cap rolled in `[8, 16]`. When the cap is hit the node becomes `UNLINKABLE`. Each unique partnership cluster gets a stable `group_id` and persists to disk in compressed JSON.
- **Front-of-list cursor walk** — each chatter cycle picks 100–400 nodes from the front of the id list, swaps at most one vote per node, and resumes from the cursor next cycle.
- **1-hour per-node cooldown** — distinct from the legacy 24-hour pattern-morph cooldown.
- **Semantic gates** — vote swaps only fire when receiver and donor share an action family (ASSERT / ESCALATE / NEGATE / QUERY / COMMAND), the donor isn't already in the receiver's vote list, and isn't in the receiver's negatives.
- **Capped semantic-intensity coinflip** — bias is clamped at `0.85` so even tight matches still get a chance to fail.
- **Vote-weight jitter** — donor weight is jittered slightly on swap; if the donor has no weight, a low one is added on a coinflip.
- **NONJITTER override** — strong + low-confidence donors still jitter (so high-strength but uncertain votes don't ossify).
- **CRYSTALIZE attachments** — manual or auto (high relational truth + high strength) attachments always fire, skipping the strength-biased coinflip. Reversible if strength drops.
- **Grave-slot recovery** — when a group member dies, the group loses `UNLINKABLE` until a replacement latches in.

See [`src/ChatterMode.jl`](src/ChatterMode.jl) and [`test/test_chatter_v2.jl`](test/test_chatter_v2.jl).

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
| `/wrong` | Tell GrugBot its last response was bad. Penalizes only contributing nodes (that actually fired) via coinflip strength decay. Nodes that reach 0 become graves. |
| `/right` | Tell GrugBot its last response was good. Secondary reinforcement for contributing nodes: 50% coinflip chance to gain strength (no double reward). |
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

### Admin Commands

| Command | What it does |
|---|---|
| `/login <password>` | Authenticate as admin. Session expires after 1 hour of inactivity. Required for `/writeSave`. |
| `/logout` | End admin session. |
| `/writeSave <filepath> <json>` | Append validated JSON to an existing save file. **Requires admin login.** Validates JSON before writing — no silent failures. |

**Default admin password:** `grug_cave_master_420` (change `ADMIN_PASSWORD_HASH` before deployment!)

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

### What gets saved/restored (v2.4 — 21 categories)

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
| 11.5 | **eye_state** | EyeSystem tracking state — attention_enabled, blur_enabled, last centroid, last_arousal |
| 12 | **id_counters** | NODE ID_COUNTER and MSG_ID_COUNTER atomic values |
| 12.5 | **last_contributors** | LAST_VOTER_IDS — node IDs that fired and contributed in last cycle (for /right and /wrong feedback) |
| 13 | **brainstem** | BrainStem dispatch count and propagation history |
| 14 | **attachments** | ATTACHMENT_MAP — target→attached node mappings with patterns and pre-baked signal vectors |
| 15 | **trajectory** | ActionTonePredictor ring buffer + config — behavioral inertia through action-tone space (Lorenz damping) |
| 16 | **temporal_coherence** | ImageSDF TEMPORAL_COHERENCE_LEDGER — SDF timing patterns and coherence scores |
| 17 | **morph_cooldowns** | ChatterMode MORPH_COOLDOWN_MAP — 24h morph cooldown timestamps per node |
| 18 | **immune_system** | ImmuneSystem Hopfield memory + ledger — what was safe/funky, automata state |
| 19 | **aiml_system** | AIMLNodeSystem per-lobe tribes — AIML nodes, templates, strength, cycle state |

### Restore order

`id_counters` → `last_voters` → `verb_registry` → `thesaurus_seeds` → `lobes` → `lobe_tables` → `nodes` → `node_to_lobe_idx` → `hopfield_cache` → `rules` → `inhibitions` → `message_history` → `arousal` → `eye_state` → `brainstem` → `attachments` → `trajectory` → `temporal_coherence` → `morph_cooldowns` → `immune_system` → `aiml_system`

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

## Vote Tie-Breaking & Certainty

When multiple nodes compete for the same response slot, ties happen. The orchestrator now handles them explicitly instead of silently picking the first sorted result.

### How It Works

1. **Sure Basket**: All votes within 0.05 of the max confidence are bucketed as "sure" candidates.

2. **Exact Tie Detection**: Within the sure basket, votes at the *exact* same confidence (within floating-point epsilon) are identified as tied.

3. **Random Winner**: When ties exist, the tied group is shuffled and one is picked at random. No more deterministic first-in-sort-order bias.

4. **SURE vs UNSURE**: If the primary winner stands alone at the top, the vote is classified as `SURE`. If ties existed, it's `UNSURE`. This classification is available to AIML rules via `{VOTE_CERTAINTY}`.

5. **Tied Alternatives**: Non-selected tied winners are listed at the bottom of the response with their node ID, action, confidence, and relational triples — so you can see what the other tied rocks looked like.

6. **Runner-Up Possibilities**: Unsure votes (below the sure threshold but kept via coinflip) are listed as "Other Possibilities" with their relations.

### AIML Rule Tags

Two new tags are available in `/addRule` templates:

| Tag | Expands To |
|---|---|
| `{VOTE_CERTAINTY}` | `SURE` or `UNSURE` — whether a tie existed |
| `{TIED_ALTERNATIVES}` | Comma-separated list of tied non-winners with their actions and confidence |

Example rule: `/addRule When {VOTE_CERTAINTY} is UNSURE, also consider: {TIED_ALTERNATIVES} [prob=0.8]`

---

## Specimen Immune System

Once a specimen reaches maturity (≥ 1000 nodes), an automata-based immune system activates to protect the node population from funky inputs. This is not adversarial security — it's biological: tolerance-based, stochastic, and imperfect by design.

### How It Works

1. **AST Scan**: Every structure-storing command gets a high-resolution structural scan before touching anything. The scan produces an AST signature — a structural fingerprint of the input.

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

The immune system gates **all structure-storing commands** automatically. Gated commands (critical gates marked with ⚡):

| Command | Gate | Notes |
|---|---|---|
| `/grow` | ⚡ Critical | Modifies node population |
| `/lobeGrow` | ⚡ Critical | Grows nodes into lobes |
| `/loadSpecimen` | ⚡ Critical | Replaces entire brain state |
| `/addRule` | Standard | Stores AIML orchestration rules |
| `/pin` | Standard | Stores pinned memory |
| `/addVerb` | Standard | Modifies verb registry |
| `/addRelationClass` | Standard | Creates verb class buckets |
| `/addSynonym` | Standard | Modifies synonym map |
| `/newLobe` | Standard | Creates lobe structure |
| `/connectLobes` | Standard | Links lobes bidirectionally |
| `/negativeThesaurus add` | Standard | Adds inhibition entries |
| `/nodeAttach` | Standard | Modifies node attachments |
| `/imgnodeAttach` | Standard | Modifies image node attachments |

**Exempt commands** (read-only or destructive-remove-only): `/mission`, `/wrong`, `/explicit`, `/nodes`, `/status`, `/lobes`, `/listVerbs`, `/thesaurus`, `/help`, `/arousal`, `/saveSpecimen`, `/attachments`, `/tableStatus`, `/tableMatch`, `/nodeDetach`, `/imgnodeDetach`, `/negativeThesaurus remove/flush/list/check`.

When the immune system rejects an input, you'll see:

```
[IMMUNE] ⛔ /grow REJECTED by immune system: Funky input failed patching and was deleted
```

All gates use the shared `immune_gate()` helper — no copy-pasted immune logic. Immune state (Hopfield memory + ledger) is saved/restored with `/saveSpecimen` and `/loadSpecimen`.

Full specification: [`docs/immune_system.html`](./docs/immune_system.html)

---

## Full-Lobe Scanning System (`FullLobeScanner`)

The full-lobe scanner runs an associative memory scan over an entire lobe. Unlike `scan_specimens` which works on the flat NODE_MAP, `FullLobeScanner` operates on a feature-vector dictionary and produces typed matches with spreading activation semantics.

### How It Works

1. **Set Query** (`set_query!`) — Load the feature vector you're looking for. Must be called in INIT phase. Transitions scanner to GATHER phase.

2. **Gather Candidates** (`gather_candidates!`) — Multithreaded scan of all nodes using cosine similarity. Static chunking divides nodes evenly across threads (4–8 default). Nodes above the candidate threshold (default 0.3) are collected and sorted by score.

3. **Activate Candidates** (`activate_candidates!`) — Top candidates are activated into the `ActiveNodeSet` (max 1,000 active nodes, FIFO eviction at capacity). Nodes above the confident threshold (default 0.75) become `PatternMatch` results.

4. **Continue Scan** (`continue_scan!`) — Spreading activation through node connections. Each active node's activation decays (default 0.9×) as it spreads to neighbors. Neighbors that meet both activation and similarity thresholds become `SemanticMatch` results. Scan terminates when activation is exhausted or max cycles (default 10) reached.

5. **DONE Signal** — When the scan completes, a DONE signal is emitted. Only after DONE is `can_aiml_respond()` true. **AIML must not respond until DONE.**

### Quick Example

```julia
using GrugBot420

scanner = LobeScanner("language_lobe", 4)  # 4 threads

node_features = Dict(
    "node_1" => [0.9, 0.1, 0.2],
    "node_2" => [0.8, 0.15, 0.3],
    "node_3" => [0.1, 0.9, 0.2],
)
node_connections = Dict(
    "node_1" => ["node_2"],
    "node_2" => ["node_1", "node_3"],
    "node_3" => ["node_2"],
)

set_query!(scanner, [0.85, 0.12, 0.25])
result = full_scan!(scanner, node_features, node_connections)

if result.done_signal
    println("Confident matches: ", result.confident_matches)
    println("Pattern matches: ", result.pattern_matches)
    println("Semantic matches: ", result.semantic_matches)
end
```

### Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `MAX_ACTIVE_NODES` | 1000 | Hard cap on simultaneously active nodes |
| `DEFAULT_THREADS` | 4 | Default thread count for candidate gathering |
| `MAX_THREADS` | 8 | Maximum allowed threads |
| `CONFIDENT_THRESHOLD` | 0.75 | Cosine similarity required for a confident match |
| `DEFAULT_CANDIDATE_THRESHOLD` | 0.3 | Minimum similarity to be considered a candidate |
| `MAX_CONTINUE_CYCLES` | 10 | Maximum spreading activation cycles |

### Phase Lifecycle

```
INIT → GATHER → ACTIVATE → CONTINUE → DONE
```

Each phase has strict entry requirements. Calling a phase function out of order throws `FullLobeScanError`. The `full_scan!` convenience function runs all phases in one call.

### AIML Gating

```julia
if can_aiml_respond(scanner)
    # safe to use scan results
else
    require_aiml_ready!(scanner)  # throws FullLobeScanError if not ready
end
```

The DONE gate is enforced at the API level — you cannot accidentally read results from an in-progress scan.

---

## Parallel Vote Orchestrator (`VoteOrchestrator`) — v7.8

The `VoteOrchestrator` module is the hard-bounded fire/vote engine that sits under the whole pipeline. Every fire — pattern scan, drop-table relay, lobe cascade, NodeAttach relay — is routed through it. No silent failures, no unbounded parallelism, no colliding task names.

### Key Guarantees

- **Global fire cap** — at most `ACTIVE_FIRE_CAP = 1000` concurrent fire slots across the entire engine. Enforced by an atomic `FireCounter`, shared by every fire type.
- **Unique Task names** — every sub-process gets a `prefix#id` task ID from a global atomic counter. No two live tasks can share a name. Makes debugging parallel crashes deterministic.
- **Deadline-bounded dispatch** — every sub-process can run under a hard timeout. Deadline hits → `TaskTimeoutError` with the task name attached. Callers distinguish this from other errors so they can pick retry vs. abort.
- **Batched parallel fire** — `parallel_fire_batches` dispatches nodes in batches of `FIRE_BATCH_SIZE = 64`. Each batch is its own Task with its own `FIRE_BATCH_TIMEOUT_S = 5.0`s deadline. Batch failure re-raises with batch name, never swallowed.
- **DONE channels** — lobes signal completion over typed `Channel{DoneSignal}`s. AIML is gated until expected DONE count arrives or the `DONE_SIGNAL_TIMEOUT_S = 30.0`s window expires (whichever comes first).
- **Strength-biased voting** — `strength_biased_vote_coinflip` and `select_aiml_votes` implement the top-tier (within `AIML_TOP_TIER_WINDOW = 0.05` of max confidence, always fires) and sub-top (fires at `AIML_SUBTOP_BASE_PROB = 0.20` + up to `AIML_SUBTOP_BONUS_PROB = 0.70` based on strength) selection rules.

### Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `ACTIVE_FIRE_CAP` | 1000 | Hard cap on concurrent fires (all types, all lobes) |
| `FIRE_BATCH_SIZE` | 64 | Nodes per parallel fire batch |
| `DEFAULT_TASK_TIMEOUT_S` | 15.0 | Default deadline for `dispatch_task_with_timeout` |
| `FIRE_BATCH_TIMEOUT_S` | 5.0 | Per-batch deadline inside `parallel_fire_batches` |
| `DONE_SIGNAL_TIMEOUT_S` | 30.0 | Max wait on the DONE channel before AIML gate releases |
| `AIML_CONFIDENCE_THRESHOLD` | 0.15 | Minimum confidence for a candidate to enter AIML vote |
| `AIML_TOP_TIER_WINDOW` | 0.05 | Distance from max confidence that counts as top-tier |

### Core API

| Function | Description |
|---|---|
| `next_task_id(prefix)` | Atomic counter → unique non-colliding `prefix#N` task name |
| `dispatch_task(f, prefix; timeout_s=nothing)` | Run `f` in a fresh Task with a unique name, optional deadline |
| `dispatch_task_with_timeout(f, prefix, timeout_s)` | Deadline-required variant — always times out |
| `fetch_with_timeout(name, task)` | Safely fetch a task result or raise `TaskTimeoutError` |
| `list_active_tasks()` | Snapshot of the active task registry (debug/observability) |
| `FireCounter(cycle_id, cap)` / `try_claim_fire_slot!(fc)` | Atomic fire-slot claim |
| `parallel_fire_batches(ids, fc, firefunc; batch_size, timeout_s)` | Batched threaded fire with shared cap + per-batch deadline |
| `make_done_channel(n)` / `send_done!` / `wait_for_done` | DONE signaling for phase-gated lobes |
| `select_aiml_votes(candidates; threshold, top_window)` | Threshold + top-tier + strength-biased coinflip selection |

### Error Model

- `VoteOrchestratorError` — generic orchestrator-layer failure with `message` + `context` breadcrumb.
- `TaskTimeoutError` — distinguishable subtype: carries `task_name`, `context`, `timeout_s`. Custom `showerror` renders a human-readable trace. Callers pattern-match on this subtype to decide retry vs. abort. **Never swallowed** — always rethrown out of `fetch_with_timeout`.

---

## Timeout-Bounded Sub-Process Dispatch — v7.8

Every sub-process dispatched through the engine and `Main.jl` runs in its own unique non-colliding Task under a hard deadline. This is the cross-cutting "no infinite hangs" rule.

- `dispatch_task` accepts an optional `timeout_s` kwarg; when set, the task is registered in `_TASK_DEADLINES` and monitored.
- `fetch_with_timeout` uses `timedwait` on the registered deadline. Timeout → `TaskTimeoutError`, not a generic hang.
- Call-site convention: pipeline stages import `VoteOrchestrator.FIRE_BATCH_TIMEOUT_S` and the other named constants rather than hard-coding numbers, so the whole engine moves in lockstep when a constant is tuned.

Callers that need retry semantics pattern-match:

```julia
try
    result = fetch_with_timeout(name, task)
catch e
    if e isa TaskTimeoutError
        @warn "task timed out, skipping this cycle" name=e.task_name timeout=e.timeout_s
        # abort or retry — caller's decision, never silently ignored
    else
        rethrow()
    end
end
```

---

## Strict Relational-Triple Coupling — v7.8

Relational-triple extraction is now **strictly coupled** to scan complexity. No silent degradation.

| `scan_mode` | Complexity | Extractor | On failure |
|---|---|---|---|
| 1 | Cheap (token overlap) | `extract_relational_triples` (basic) | Log + empty — non-fatal |
| 2 | Medium | `extract_relational_triples` (basic) | Log + empty — non-fatal |
| **3+** | **High-res / complex** | **`extract_dynamic_relational_triples` (dynamic)** | **RETHROW — hard failure** |

### Why

Before this change, a complex input that triggered high-res pattern scan would call the dynamic extractor. If that failed, the engine silently fell back to the basic extractor — producing a quietly degraded result that looked normal from the outside. That violated the no-silent-failure rule.

Now:
- Complex inputs (`scan_mode >= 3`) **require** dynamic extraction. Failure is a hard error that rethrows out of `scan_specimens`.
- Simple inputs (`scan_mode <= 2`) use the basic extractor. Failure is logged and returns an empty triple list — because basic extraction is best-effort by design.

This means a complex input never gets basic-quality relational output without a loud, stack-trace-bearing error.

### Detection

`screen_input_complexity(input)` returns a scan mode in `{1, 2, 3}`. It looks at input length, token diversity, punctuation density, and known complexity markers. Tests for the strict coupling live in `test/test_relational_strict.jl` (9 groups, all green).

---

## Per-Activation Jitter (`RelationalJitter`) — v7.9 (relational) + v7.10 (AIML) + v7.11 (/brainstorm)

Bullseye values across the engine used to be deterministic constants. Now they get a tiny zero-mean nudge at activation time — exact ties between competing nodes break naturally, quiet neighbors occasionally win a coinflip they'd otherwise always lose, and sibling AIML nodes stop marching in lockstep on 50/50 gates.

- **v7.9** applied per-activation jitter to the relational dialectics match-score components (`weight`, exact-match `+2.0`, partial-match `+1.0`, orthogonal `+0.5`, final-dampener `+0.1`).
- **v7.10** extends the same treatment to the AIML executive layer: initial node strength, every strength delta, and the three 50/50 coin gates (`record_fire!`, `apply_aiml_right!`, `apply_aiml_wrong!`).
- **v7.11** adds the **`/brainstorm <text>`** command and the `with_brainstorm_jitter(f)` scope primitive: a simulated-annealing-lite "far jump, then snap back" override that temporarily raises the value-jitter ratio from 3% to 8% and the coin-threshold ratio from ±1pp to ±5pp for the duration of one mission, then restores bit-exact on every exit path (including exceptions). Useful when the engine is stuck in a local minimum and needs heavier variance to escape.

### The Idea

> Each activation, every scored value runs slightly away from the bullseye — then snaps back to normal across activations.

- **Per-activation**: every call to `evaluate_relational_dialectics` draws fresh nudges. Nothing is persisted.
- **Snap-back**: the nudge is symmetric uniform on `[-ε·|x|, +ε·|x|]` with `E[δ] = 0`. The expected score equals the deterministic score — the bullseye is preserved in expectation. Over many activations, the mean converges back by the law of large numbers.
- **Bounded**: default `JITTER_RATIO = 0.03` (3%). Sign is always preserved for any `|x|` above the epsilon floor. Absolute cap (`JITTER_ABS_CAP = 1.0`) prevents freak nudges on large scores.

### Contract

| Input | Output |
|---|---|
| `0.0` or `|x| < 1e-9` | returned unchanged (no denormal leak) |
| `-9999.0` (hard-requirement-miss sentinel) | returned **exactly** unchanged (preserves the dialectics contract) |
| `NaN` or `Inf` | **throws `JitterError`** — no silent failure |
| Jitter globally disabled | returns input bit-exact (identity function) |
| Anything else | `x + δ`, `δ ~ U(-ε·|x|, +ε·|x|)`, clamped to `|δ| ≤ 1.0` |

### Key Constants

| Constant | Value | Purpose |
|---|---|---|
| `JITTER_RATIO_DEFAULT` | 0.03 | Value-jitter magnitude as fraction of `|x|` |
| `JITTER_RATIO_MAX` | 0.10 | Hard upper bound accepted by `set_jitter_ratio!` |
| `JITTER_ABS_CAP` | 1.0 | Maximum absolute nudge on any single value |
| `JITTER_EPS_FLOOR` | 1e-9 | Below this, `|x|` is treated as zero |
| `HARD_REQ_MISS_SENTINEL` | -9999.0 | Propagates untouched through jitter |
| `JITTER_COIN_RATIO_DEFAULT` | 0.01 | ± percentage-point swing on coin thresholds (additive, not proportional) |
| `JITTER_COIN_RATIO_MAX` | 0.10 | Hard upper bound accepted by `set_jitter_coin_ratio!` |
| `JITTER_COIN_FLOOR` | 0.01 | Lower clamp on jittered coin threshold (prevents never-fire gate) |
| `JITTER_COIN_CEILING` | 0.99 | Upper clamp on jittered coin threshold (prevents always-fire gate) |

### API

| Function | Description |
|---|---|
| `jitter_value(x; ratio=get_jitter_ratio())` | Core primitive: returns nudged value (proportional, ±ratio·\|x\|) |
| `jitter_score(s)` / `jitter_weight(w)` | Intent-carrying wrappers used by dialectics |
| `jitter_strength(s)` / `jitter_delta(d)` | Intent-carrying wrappers used by AIMLNodeSystem |
| `jitter_coin_threshold(p; ratio=get_jitter_coin_ratio())` | Additive ±ratio nudge on a probability, clamped to `[JITTER_COIN_FLOOR, JITTER_COIN_CEILING]` |
| `enable_jitter!()` / `disable_jitter!()` | Global toggle (default: ON) — affects all `jitter_*` primitives |
| `is_jitter_enabled()` | Current state |
| `set_jitter_ratio!(r)` / `get_jitter_ratio()` | Tune / inspect the value-jitter ratio |
| `set_jitter_coin_ratio!(r)` / `get_jitter_coin_ratio()` | Tune / inspect the coin-threshold ratio |
| `JitterConfig(ratio, enabled)` | Immutable policy bundle for scoped passing |

### Where It's Applied

Inside `evaluate_relational_dialectics` (v7.9):
- Each `weight` lookup is nudged via `jitter_weight`.
- Each match-score contribution (`+2.0·w` exact, `-2.0·w` antimatch, `+1.0·w` partial, `+0.5·w` orthogonal) is nudged via `jitter_score`.
- The final `orthogonal_penalty * 0.1` dampener is nudged via `jitter_score`.

Inside `AIMLNodeSystem` (v7.10):
- `AIMLNode` constructor passes `initial_strength` through `jitter_strength` before the `[FLOOR, CAP]` clamp.
- `_apply_strength_delta!` jitters every delta (reward or penalty magnitude) via `jitter_delta` before the clamp + grave-transition check. Because `ratio < 1`, sign is always preserved — a `+1.0` delta stays positive, a `−1.0` delta stays negative.
- The three `rand() < 0.5` coin gates (`record_fire!`, `apply_aiml_right!`, `apply_aiml_wrong!`) now compare against `jitter_coin_threshold(0.5)` instead, so sibling contributors don't share a locked-in coin outcome within a cycle.
- The honest-net-loss contract (`/aimlWrong` on a prior-gain node MUST end strictly below cycle-start strength) is preserved because penalty magnitude = `AIML_STRENGTH_DELTA + prior_gain > 0` and the delta jitter preserves sign.

What's **not** jittered:
- The hard-requirement-miss sentinel path (`-9999.0`) — must stay exact.
- The antimatch flag (`is_antimatch`) — a boolean, no entropy to add.
- The `max(0.1, …)` floor in dialectics — floor value 0.1 is constant by design.
- `AIML_STRENGTH_CAP` / `AIML_STRENGTH_FLOOR` — these are the clamp boundaries jitter respects, not values that float themselves.
- Boolean cycle state (`is_grave`, `gained_this_cycle`, `fired_this_cycle`, `voted_this_cycle`) — no meaningful entropy on flags.
- Penalty magnitude is jittered **only once** inside `_apply_strength_delta!` — the caller does NOT pre-jitter the magnitude, so the net-loss guarantee stays tight.

### Error Handling

All bad inputs (`NaN`, `Inf`, out-of-range ratio) throw `JitterError`. The error carries a `context` string identifying the failing call site so stack traces are immediately actionable. The error type subclasses `Exception` so standard Julia `try` / `catch` works normally.

### Tests

`test/test_relational_jitter.jl` — 14 test groups covering: magnitude bounds, zero-mean convergence (empirical mean snaps back within 1%·|x| over 20k samples), error handling, toggle, ratio setter, semantic wrappers, thread safety under `@threads`, `JitterConfig`, integration with `evaluate_relational_dialectics` (snap-back in live dialectics), sentinel preservation (500/500 exact), antimatch robustness (1000/1000 flag-flip preserved), and bit-exact determinism when disabled.

`test/test_aiml_jitter.jl` — 8 test groups covering: initial-strength jitter (window + zero-mean + near-cap / near-floor / exact-zero behaviour), strength-delta jitter (sign preservation + mean snap-back), coin-threshold jitter at all three AIML call sites (long-run rate stays ~50% across thousands of trials), honest-net-loss contract preservation under jitter (zero violations across 1000 penalty trials), `disable_jitter!` identity contract across every AIML path, and error propagation (NaN/Inf/out-of-range inputs raise `JitterError`, no silent clamping).

`test/test_brainstorm_jitter.jl` — 8 test groups covering: normal enter/exit with ratio swap, exception propagation with state restore, nested-scope refusal via `JitterScopeError`, custom-ratio handling, invalid-ratio rejection before state mutation, orthogonality with `disable_jitter!`, empirical widening of the jitter window (>1.8× factor inside scope vs outside), and lifecycle correctness of `is_brainstorm_active` / `get_brainstorm_depth` across re-entry.

### `/brainstorm <text>` — Scoped Heavy-Jitter (v7.11)

Use `/brainstorm <prompt>` instead of `/mission <prompt>` when you want the engine to take bigger jumps before settling. The command runs the exact same mission pipeline but wraps it in `with_brainstorm_jitter()` so every jitter-wired code path (relational dialectics, AIML strength updates, AIML coin gates) sees a wider entropy window for that one mission. On exit — whether the mission completed normally or threw — the ratios snap back to their defaults.

**Ratios used inside the scope:**

| Setting | Default | Brainstorm | Hard cap |
|---|---|---|---|
| Value-jitter ratio | 0.03 (±3%·\|x\|) | 0.08 (±8%·\|x\|) | 0.10 |
| Coin-threshold ratio | 0.01 (±1pp) | 0.05 (±5pp) | 0.10 |

Both brainstorm ratios stay within the permanent hard caps, so every validator in the system still sees a legal value during the scope. The coin-threshold ratio is kept well below 0.5 so even a full negative swing cannot drag the gate across the `[0, 1]` boundary — the floor/ceiling clamp inside `jitter_coin_threshold` is a safety net, not the normal operating point.

**API:**

```julia
using GrugBot420

# Wrap any callable in a brainstorm scope
result = GrugBot420.RelationalJitter.with_brainstorm_jitter() do
    process_mission("your tricky prompt here")
end

# Custom ratios (still validated against the hard caps)
GrugBot420.RelationalJitter.with_brainstorm_jitter(ratio = 0.05, coin_ratio = 0.02) do
    process_mission("your tricky prompt here")
end

# Check scope state
GrugBot420.RelationalJitter.is_brainstorm_active()   # Bool
GrugBot420.RelationalJitter.get_brainstorm_depth()   # Int (0 = inactive, 1 = active)
```

**Invariants:**

- Nested `with_brainstorm_jitter` calls throw `JitterScopeError` — no silent coalescing of overlapping scopes.
- Invalid ratios (NaN, Inf, negative, or above the hard cap) throw `JitterError` **before** any state mutation. The caller can safely retry with sane values without worrying about leaked state.
- A `try/finally` guarantees the saved ratios are restored bit-exact regardless of exit path. If `f` throws, the scope still unwinds cleanly and rethrows.
- Brainstorm is **orthogonal** to the global `enable_jitter!` / `disable_jitter!` toggle. If jitter is globally disabled, brainstorm still returns identity from every `jitter_*` primitive — brainstorm controls magnitude, the enable flag controls on/off.
- Entering and exiting brainstorm scope is thread-safe (`_CONFIG_LOCK`-protected), so a stray async task cannot interleave into a half-set state.

### Disabling for Deterministic Tests

```julia
using GrugBot420.RelationalJitter
disable_jitter!()
# ... deterministic assertions ...
enable_jitter!()
```

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
| `src/ImmuneThreadPool.jl` | 8-worker immune thread pool with priority lanes (CRITICAL/NORMAL/LOW/JUNK), per-source rate limiting, cost-weighted load balancing, and tripwire state machine (NORMAL→ELEVATED→HARDENED→CRITICAL). |
| `src/FullLobeScanner.jl` | Full-lobe scanning system: bounded activation (max 1,000 active nodes), phase-gated scan pipeline (INIT→GATHER→ACTIVATE→CONTINUE→DONE), pattern + semantic matches, multithreaded candidate gathering. AIML gated until DONE signal. |
| `src/AIMLNodeSystem.jl` | Per-lobe AIML node tribes: isolated AIML node populations per lobe, configurable population caps (default node_cap ÷ 3), grave-exclusion cap accounting, cycle-aware reinforcement, full save/load serialization. v7.10 routes initial strength, every strength delta, and the three 50/50 reward/penalty coin gates through `RelationalJitter` for per-activation entropy. |
| `src/VoteOrchestrator.jl` | Parallel vote orchestrator (v7.8): unique non-colliding Task dispatch, atomic `FireCounter` with hard 1000-slot cap across ALL fire types, `parallel_fire_batches` (batch size 64), `TaskTimeoutError` + `dispatch_task_with_timeout` for deadline-bounded sub-processes, `DoneSignal` channels, strength-biased vote coinflip with top-tier / sub-top windows. No silent failures — timeouts rethrow distinguishable errors. |
| `src/RelationalJitter.jl` | Per-activation zero-mean nudge on scored values and coin thresholds. v7.9: proportional jitter on `[-ε·\|x\|, +ε·\|x\|]` with `ε = 0.03` default for relational match-score components (bullseye preserved in expectation, exact ties break naturally). v7.10: additive `±ρ` nudge on probability thresholds with `ρ = 0.01` default, clamped to `[0.01, 0.99]` interior so gates never degenerate to always-yes or always-no. Consumed by engine dialectics and AIMLNodeSystem. v7.11: `with_brainstorm_jitter(f)` scope primitive raises both ratios to their far-jump settings (`0.08` / `0.05`) for one call, `try/finally` restores bit-exact on any exit path, nested scopes throw `JitterScopeError`. Sentinel (`-9999.0`) and zero pass through untouched; `NaN`/`Inf`/out-of-range inputs throw `JitterError`; global toggle for deterministic tests. |
| `grugbot_whitepaper.html` | Full technical documentation and architecture reference. |

---

## AIML Node System

GrugBot420 supports per-lobe AIML node tribes — isolated populations of AIML nodes within each lobe with their own population caps.

### Key Concepts

- **Per-Lobe Tribes**: Each lobe maintains its own AIML node registry, independent of other lobes
- **Population Caps**: Each lobe has a configurable AIML population cap (default: 1/3 of lobe's node cap)
- **Grave Exclusion**: Dead nodes (graves) don't count towards population caps — they're memory, not bloat
- **Cycle-Aware Reinforcement**: AIML nodes can be reinforced based on cycle detection

### API Functions

| Function | Description |
|---|---|
| `register_lobe!(lobe_id, node_cap)` | Register a lobe for AIML with population cap = node_cap ÷ 3 |
| `add_aiml_node!(lobe_id, node_id, template_id)` | Add an AIML node to a lobe's tribe |
| `get_aiml_node(lobe_id, node_id)` | Retrieve a specific AIML node |
| `get_population_size(lobe_id)` | Get total AIML node count (including graves) |
| `get_alive_population_size(lobe_id)` | Get alive AIML node count (excludes graves) |
| `remove_aiml_node!(lobe_id, node_id)` | Remove an AIML node from a tribe |

### Population Cap Enforcement

When adding an AIML node, the system checks the **alive** population count (excluding graves). This means:

- A lobe with cap=3 can have 3 alive nodes + any number of grave nodes
- When an AIML node dies (becomes a grave), it frees up cap space for new nodes
- This prevents "cap lock" where dead nodes prevent new growth

Example:
```julia
# Register lobe with 9 node cap → AIML cap = 3
register_lobe!("my_lobe", 9)

# Add 3 alive nodes (fills cap)
add_aiml_node!("my_lobe", "node1", "tmpl1")
add_aiml_node!("my_lobe", "node2", "tmpl2")
add_aiml_node!("my_lobe", "node3", "tmpl3")

# Mark one as grave
node = get_aiml_node("my_lobe", "node3")
node.is_grave = true

# Now we can add another! (2 alive + 1 grave = 3 total, but alive cap has room)
add_aiml_node!("my_lobe", "node4", "tmpl4")  # ✓ Works!

# But 4th alive would fail
add_aiml_node!("my_lobe", "node5", "tmpl5")  # ✗ Throws AIMLNodeError
```

---

## Documentation

Open `grugbot_whitepaper.html` in a browser for the full technical whitepaper covering architecture, formal mathematics, all subsystems, and design rationale.

See [`docs/immune_system.html`](./docs/immune_system.html) for the immune system specification (grug analogy, academic details, math/lambda, flowchart).

See [`docs/AIML_COMMANDS.md`](./docs/AIML_COMMANDS.md) for the complete AIML Node System command reference, including user commands, API functions, and immune system integration.

---

## Notes on Seeding

The first ~100 nodes you plant are the specimen's DNA. Before hitting 1,000 nodes, automatic neighbor latching is suppressed — you control topology manually via drop tables. Recommendations:

1. Seed orthogonal archetypes first — distinct semantic poles, not 50 near-identical nodes
2. Use `required_relations` as semantic gates from day one so nodes don't fire on noise
3. Name action packets deliberately — distinct action families give the superposition orchestrator something meaningful to work with
4. Wire drop tables manually for known co-activation pairs
5. The engine enforces structure at scale (1,000+ nodes). You enforce meaning at the start.
