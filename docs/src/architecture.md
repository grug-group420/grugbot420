# Architecture

GrugBot420 is organized as a layered neuromorphic engine. This page describes the major subsystems and their interactions.

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│                     CLI (Main.jl)                        │
├───────────┬───────────┬───────────┬──────────────────────┤
│ InputQueue│ Thesaurus │ BrainStem │    ChatterMode        │
│ (FIFO +   │ (Dim.Sim) │ (WTA      │    (Idle Gossip)      │
│  NegThes) │           │ Dispatch) │                       │
├───────────┴───────────┴───────────┴──────────────────────┤
│           Lobe System (Subject Partitions)                │
│           LobeTable (Chunked Hash Storage)                │
├──────────────────────────────────────────────────────────┤
│            Engine (Node Voting Core)                      │
│  ActionTonePredictor │ SemanticVerbs                      │
│  AttachmentRelay (Relational Fire System)                 │
├──────────────────────────┬───────────────────────────────┤
│  PatternScanner          │  FullLobeScanner               │
│  ImageSDF │ EyeSystem    │  (Phase-gated lobe sweep,      │
│                          │   cosine sim + spreading       │
│                          │   activation, AIML gated)      │
├──────────────────────────┴───────────────────────────────┤
│  ImmuneThreadPool (8 workers, priority lanes,             │
│  TokenBucket rate limiting, TripwireMonitor)              │
├──────────────────────────────────────────────────────────┤
│          StochasticHelper (@coinflip)                     │
├──────────────────────────────────────────────────────────┤
│  PhagyMode (7 Idle Maintenance Automata)                  │
│  MemoryForensics (Coinflip: Fuzzy │ Metric)               │
└──────────────────────────────────────────────────────────┘
```

## Node Lifecycle

1. **Creation** — Nodes are planted via `/grow` (or `/lobeGrow`) after passing the immune gate
2. **Scanning** — Input is converted to a signal vector; nodes compete via pattern matching with selective scan tiers (cheap/medium/high-res) based on both input complexity and per-node pattern complexity. Tier-1 (cheap scan) nodes use **bidirectional scanning**: forward pass + reverse-signal pass, confidence smoothed as the average of both. This catches order-reversed token matches that forward-only scanning misses.
3. **Attachment Relay** — Nodes that fired are checked for attachments; attached nodes do a strength-biased coinflip and winners join the vote pool (Pass 3 of `scan_and_expand`)
4. **Voting** — Matched nodes enter a superposition pool; action weights determine contribution
5. **Selection** — The orchestrator picks a winner. If multiple nodes tie at the same confidence, the tie is broken randomly via `shuffle!`. The result is classified as SURE (clear winner) or UNSURE (tie broken). Tied alternatives and strong runner-ups are reported.
6. **Decay** — Unused nodes lose strength over time; grave nodes may be recycled by PhagyMode
7. **Forensics** — During idle cycles, PhagyMode may roll Automaton 7 (Memory Forensics) to audit message history and node population health. This is read-only observation, never mutation.

## Subsystems

| Subsystem | File | Purpose |
|-----------|------|---------|
| Immune System | `ImmuneSystem.jl` | Protects mature specimens from funky inputs |
| ChatterMode | `ChatterMode.jl` | Idle gossip — weak nodes drift toward strong |
| PhagyMode | `PhagyMode.jl` | Idle maintenance — pruning, decay, recycling |
| Thesaurus System | `Thesaurus.jl` | Semantic similarity and synonym expansion |
| EyeSystem & Image SDF | `EyeSystem.jl`, `ImageSDF.jl` | Visual attention and GPU SDF conversion |
| Relational Fire | `engine.jl` | JIT confidence-baked node attachment chains |
| ActionTonePredictor | `ActionTonePredictor.jl` | Pre-vote action/tone classification |
| Full Lobe Scanner | `FullLobeScanner.jl` | Phase-gated full-lobe associative scan with spreading activation; AIML gated until DONE |
| AIML Node System | `AIMLNodeSystem.jl` | Per-lobe AIML tribes with population caps; graves excluded from caps; contributor-only reinforcement |
| ImmuneThreadPool | `ImmuneThreadPool.jl` | Hardened 8-worker pool with priority lanes, rate limiting, and tripwire escalation |


## Attachment Relay (Relational Fire)

The attachment relay is **Pass 3** of `scan_and_expand()` in `engine.jl`. After the primary scan (Pass 1) and lobe cascade (Pass 2), the engine iterates every node in the expanded set and checks for attachments via `ATTACHMENT_MAP`. Each attached node does a strength-biased coinflip (`scan_prob = 0.20 + (strength / STRENGTH_CAP) * 0.70`). Winners enter the expanded vote set with pre-baked confidence plus jitter. The relay has its own independent active cap sample (`rand(600:1800)`) to respect the biological attention bottleneck.

### JIT Confidence Baking

The **connector pattern** (middleman) is the core of the relay system. Confidence is computed **once at attach time** (JIT), not every fire cycle:

1. **Text nodes** (`/nodeAttach`): token overlap similarity between the connector pattern and the **attached node's own pattern** (Jaccard) + strength bonus → stored as `base_confidence`
2. **Image nodes** (`/imgnodeAttach`): image binary → `JITGPU(binary)` (real KernelAbstractions.jl GPU kernel dispatch) → cosine similarity between connector SDF signal and attached image node's signal + strength bonus → stored as `base_confidence`

At fire time, only stochastic jitter is applied: `confidence = max(0.1, base_confidence + randn() * 0.05)`. The connector pattern is still stored for AIML reference and surfaces as a `RelationalTriple(target_id, "relay_attached", connector_pattern)` so downstream knows WHY these nodes were co-activated.

### Image Attachment (`/imgnodeAttach`)

Image attachments use the same `AttachedNode` struct and `ATTACHMENT_MAP` as text attachments. The key difference is the JIT computation at attach time: image binary is converted to nonlinear SDF parameters via **`JITGPU(binary; width, height)`**, then flattened to a signal vector via `sdf_to_signal()`. Confidence is derived from `_sdf_signal_similarity()` (cosine similarity) instead of `_token_overlap_similarity()` (Jaccard). The pattern field stores SDF metadata (`"SDF:image:WxH"`) instead of a text connector pattern.

`JITGPU` uses `KernelAbstractions.jl` to dispatch real GPU kernels across backends selected at runtime: `CUDABackend()` on NVIDIA hardware, `ROCBackend()` on AMD, `MetalBackend()` on Apple Silicon, and `CPU()` (multithreaded Julia threads) as the CI-safe fallback. The kernel code is identical across all backends — only the dispatch target changes. The two-pass kernel pipeline is:

1. **Pass 1 (`_sdf_pixel_decode_kernel!`)**: one thread per pixel — decode UInt8 bytes (gray/RGB/RGBA) → `brightness_raw`, `color_scalar`, normalized `x`/`y` coordinates
2. **`KernelAbstractions.synchronize(backend)`**: device barrier — all pixels decoded before any gradient reads its neighbors
3. **Pass 2 (`_sdf_gradient_kernel!`)**: central-difference gradient → `tanh(3 × grad_mag)` nonlinear SDF activation — edges produce high activation, uniform regions suppress to near zero

**All image paths use JITGPU.** Every entry point where image binary enters the system — `/mission` inline detection, `/grow` packet detection, and `/imgnodeAttach` explicit attachment — routes through `JITGPU(binary; width, height)` for nonlinear SDF conversion. The CPU reference path (`image_to_sdf_params`) is retained for tests only.

Key properties:
- Max 4 attachments per target node (text + image share the same pool)
- Coinflip-gated: strong attachments fire more often but weak ones still have a 20% floor
- JIT confidence: `base_confidence` baked at attach time, fire applies `max(0.1, base_confidence + randn() * 0.05)` (synaptic jitter for vote diversity)
- Connector pattern / SDF metadata surfaces as a relay triple for generative context
- Deduplication: no node appears twice in the expanded set
- Fired attachments get a `bump_strength!` call (they earned it)
- Fully serialized in specimen save/load (section 14 / 4.14), with backward compat re-baking

### Selective Scan Tiers + Bidirectional Smoothing

Pattern scan complexity is two-layered: `screen_input_complexity()` sets a base tier from input signal length and relational triple count (tier 1/2/3). `_effective_scan_mode()` then applies a per-node downgrade — a 2-token node never justifies a high-res O(n²) scan regardless of input complexity.

| Effective tier | Scan function | Notes |
|---|---|---|
| 1 (≤ 3 signal elements) | `_bidirectional_cheap_scan` | forward + reverse, confidence smoothed |
| 2 (≤ 8 signal elements) | `medium_scan` | every index, single direction |
| 3 (> 8 signal elements) | `high_res_scan` | two-pass variance penalty |

**Bidirectional smoothing (tier 1):** `_bidirectional_cheap_scan()` runs `cheap_scan` forward and in reverse (reversed pattern signal). Confidence is the average of both contributions. The miss contribution for a failed direction is `threshold - 0.01` (not zero) — this softens but doesn't zero-out the average, preventing a lucky single-direction spike from inflating the score. If both directions miss, `PatternNotFoundError` propagates normally. This resolves the order-sensitivity of signal encoding: `words_to_signal("man bites dog")` and `words_to_signal("dog bites man")` produce different vectors, but bidirectional scan finds the alignment from either direction.

## PhagyMode (Idle Maintenance Automata)

PhagyMode runs one randomly selected automaton per idle cycle. There are seven automata:

1. **Orphan Pruner** — Graves nodes with zero neighbors and zero strength
2. **Strength Decayer** — Decays forgotten node strengths toward a floor
3. **Grave Recycler** — Reclaims resources from long-dead grave nodes
4. **Hopfield Cache Validator** — Purges stale or orphaned cache entries
5. **Drop Table Compactor** — Trims low-probability drop table entries (preserves last entry)
6. **Rule Pruner** — Flags dormant rules by tracking fire count and dormancy strikes
7. **Memory Forensics** — Coinflip-gated read-only analysis of message history and node health

Selection is uniform (`rand(1:7)`). If Automaton 7 is rolled but `message_history` / `history_lock` kwargs are not available, the dispatcher re-rolls to 1–6 (graceful fallback, not silent skip). Each automaton handles its own locking and returns a `PhagyStats` result that is logged to the `PHAGY_LOG` ring buffer.

## Memory Forensics (Automaton 7)

Memory Forensics is a read-only diagnostic system that audits the health of `MESSAGE_HISTORY` and `NODE_MAP`. A coinflip (`rand(Bool)`) selects between two analysis modes:

**Fuzzy Mode** (approximate, heuristic, sampled) — fast for large caves:
- Role distribution balance (samples up to 500 messages, flags if one role exceeds 90%)
- Pattern diversity estimate (hash-based unique ratio across up to 1000 alive nodes)
- Strength distribution shape (5-band histogram, flags if >80% cluster in one band)
- Memory echo detection (samples 200 recent messages for repeated content)

**Metric Mode** (exact, measurement-based, full enumeration) — thorough but slower:
- Exact message census by role with totals
- Node population metrics (alive, grave, image node counts, grave reason breakdown)
- Dead node reference audit (regex scan of messages for `node_\d+` references to dead/missing nodes)
- Pinned message tracking (count, percentage, oldest pinned message ID)
- Strength statistics (mean, median, std dev, min, max — computed without Statistics.jl)
- Orphan detection (alive nodes with 0 neighbors and 0 strength)

Key design properties:
- **Read-only** — forensics never mutates MESSAGE_HISTORY or NODE_MAP
- **No silent failures** — all errors propagate via `PhagyError`, never swallowed
- **Dual-lock order** — metric dead-ref audit acquires `history_lock` then `node_lock` (consistent ordering prevents deadlock)
- **Configurable thresholds** — `FORENSICS_STALE_MSG_RATIO`, `FORENSICS_DEAD_REF_THRESHOLD`, `FORENSICS_PATTERN_ENTROPY_LO`, `FORENSICS_STRENGTH_SKEW_MAX`

## Trajectory Normalization & Lorenz Damping

The ActionTonePredictor uses **softmax normalization** and **trajectory-based attractor avoidance** to produce stable, length-invariant predictions that resist chaotic lock-in.

### Softmax Normalization

Raw lexicon scores (unbounded accumulators that grow with input length) are converted into proper probability distributions via temperature-scaled softmax. Temperature (default 1.5) is warm: sharp enough to let clear winners dominate, soft enough to keep minority signals alive. This makes a 3-word query and a 30-word query expressing the same intent produce similar distributions instead of the longer one having 10x raw score.

### Trajectory Memory

A ring buffer of the last N (default 16) normalized prediction distributions tracks the system's path through action-tone space over time. Each entry carries a timestamp. The **trajectory centroid** is the time-weighted exponential moving average of the buffer, where each entry's influence decays with a configurable halflife (default 120 seconds). The centroid answers: "where has the system been spending its time in action-tone space?"

### Lorenz Damping (Strange Attractor Avoidance)

The trajectory centroid is monitored via its **Gini coefficient** — a concentration measure where 0.0 = perfectly uniform distribution and 1.0 = total concentration in one category. This is the discrete analog of the Lorenz curve from economics.

When the Gini coefficient exceeds a threshold (default 0.72), the system has entered a strange attractor — one action or tone family dominates the trajectory history. **Lorenz damping** activates: mass is redistributed from overrepresented categories to underrepresented ones in the *current* prediction (not the historical record). Damping intensity scales with overshoot: barely past threshold → gentle nudge, far past → stronger correction.

Key properties:
- **Applied to current prediction only** — trajectory history is an immutable diagnostic record
- **Fresh input always wins** — damping adjusts the distribution, it doesn't override strong current signal
- **Decay prevents stale lock-in** — old trajectory entries lose influence naturally via halflife decay
- **Thread-safe** — all trajectory state access guarded by ReentrantLock
- **Graceful fallback** — if trajectory math fails, raw prediction still fires normally (callers catch errors)

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `buffer_size` | 16 | Ring buffer depth (how many past predictions to remember) |
| `decay_halflife` | 120.0s | Seconds until a past prediction loses half its influence |
| `gini_threshold` | 0.72 | Gini coefficient above which Lorenz damping activates |
| `damping_strength` | 0.25 | How much mass to redistribute when damping fires |
| `softmax_temperature` | 1.5 | Softmax temperature (lower = sharper, higher = flatter) |

## AIML Node System

The AIML Node System provides per-lobe "tribes" of AIML nodes with isolated populations and independent population caps. Each lobe can host its own AIML tribe, separate from other lobes.

### Per-Lobe Tribes

When a lobe is registered for AIML via `register_lobe!(lobe_id, node_cap)`, the system:

1. Creates an entry in `AIML_REGISTRY` keyed by `lobe_id`
2. Sets the AIML population cap to `node_cap ÷ 3` (one-third of the lobe's node cap)
3. Initializes an empty tribe (Dict mapping node_id → AIMLNode)

### Population Cap with Grave Exclusion

The key innovation is that **graves don't count towards caps**. When checking if a tribe can accept new nodes:

```
alive_count = count(n -> !n.is_grave, values(tribe))
if alive_count >= cap
    throw AIMLNodeError("population cap exceeded")
```

This design prevents "cap lock" — a scenario where accumulated dead nodes block all new growth. When an AIML node dies (marked `is_grave = true`), it immediately frees cap space.

### Cycle-Aware Reinforcement

AIML nodes track their participation in processing cycles:

- `reinforcement_count` — How many times the node has been reinforced
- `last_cycle_id` — Optional identifier for cycle-aware logic

This enables patterns like "only reinforce once per cycle" or "track reinforcement velocity over time."

### Contributor-Only Feedback

**CRITICAL DESIGN PRINCIPLE:** AIML nodes can only gain or lose strength if they actually **fired** and contributed to generating output (marked with `fired_this_cycle = true`). 

This distinction separates:
- **Voters:** Nodes that voted but may or may not have contributed
- **Contributors:** Nodes that fired and generated actual output content

**Reinforcement behavior:**
- `/aimlRight` (secondary reinforcement): Only contributors get a 50% coinflip chance to gain additional strength, minus those who already gained from initial coinflip (no double reward)
- `/aimlWrong` (penalty): Only contributors are penalized on a 50% coinflip, with over-compensation penalty if they gained strength during the cycle

This ensures that only nodes that meaningfully contributed to outputs are eligible for strength modification.

### Thread Safety

All AIML operations are protected by `AIML_LOCK::ReentrantLock`. The lock is held for the duration of each registry operation.

---

## File Reference

| File | Description |
|------|-------------|
| `src/stochastichelper.jl` | `@coinflip` macro and `bias()` helper |
| `src/patternscanner.jl` | Multi-resolution signal pattern matching |
| `src/ImageSDF.jl` | JIT image → SDF parameter conversion |
| `src/EyeSystem.jl` | Visual attention and peripheral processing |
| `src/SemanticVerbs.jl` | Live mutable verb registry |
| `src/ActionTonePredictor.jl` | Pre-vote input classifier with trajectory normalization & Lorenz damping |
| `src/engine.jl` | Core node engine |
| `src/Lobe.jl` | Subject-specific node partitions |
| `src/LobeTable.jl` | Per-lobe chunked hash table storage |
| `src/BrainStem.jl` | Winner-take-all dispatcher |
| `src/Thesaurus.jl` | Dimensional similarity engine |
| `src/InputQueue.jl` | FIFO queue and NegativeThesaurus |
| `src/ChatterMode.jl` | Idle gossip system |
| `src/PhagyMode.jl` | 7 maintenance automata including memory forensics |
| `src/ImmuneSystem.jl` | Specimen immune system: AST scanning, Hopfield immune memory, quarantine→patch→delete pipeline. Gates all structure-storing commands. |
| `src/ImmuneThreadPool.jl` | Hardened task executor: 8-worker priority-lane pool, per-source TokenBucket rate limiting, cost-weighted load balancing, TripwireMonitor state machine (NORMAL→ELEVATED→HARDENED→CRITICAL). |
| `src/FullLobeScanner.jl` | Phase-gated full-lobe associative memory scanner: bounded activation (max 1,000 active nodes), cosine-similarity candidate gathering, spreading activation, AIML gating until DONE signal. |
| `src/AIMLNodeSystem.jl` | Per-lobe AIML node tribes with population caps, grave exclusion from caps, cycle-aware reinforcement. |
| `src/Main.jl` | CLI loop, memory cave, specimen persistence, `immune_gate()` helper |
