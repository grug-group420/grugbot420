# API Reference

This page documents the public API of GrugBot420's core subsystems.

## Stochastic Helper (`CoinFlipHeader`)

The `@coinflip` macro provides weighted probabilistic branching. Given a list of `(outcome, weight)` pairs, it selects one outcome proportionally to its weight using a `Categorical` distribution.

```julia
result = @coinflip begin
    "greet"   => 3.0
    "analyze" => 1.5
    "refuse"  => 0.5
end
```

`bias(outcomes)` returns the most probable outcome without randomness — useful for deterministic fallback.

## Pattern Scanner (`PatternScanner`)

Three scan modes with increasing precision:

- `cheap_scan(input, pattern)` — strided sliding window, O(n/stride)
- `medium_scan(input, pattern)` — every-index sliding window, O(n)
- `high_res_scan(input, pattern)` — two-pass: candidate zone detection + strict variance-penalized validation

All return `(best_index, confidence)` or throw `PatternNotFoundError`.

- `_bidirectional_cheap_scan(target, pattern; threshold)` — tier-1 wrapper: runs `cheap_scan` **forward AND reverse** (reversed pattern signal), returns smoothed confidence = average of both contributions. Miss contribution = `threshold - 0.01` (not zero, to avoid harshly penalizing partial reversal). If both directions miss → `PatternNotFoundError`. Corrects order-sensitivity of `words_to_signal` encoding for short patterns.

### Selective Scan Tier Selection

Scan tier is determined by two factors:

1. **Input complexity** (`screen_input_complexity`) — signal length and triple count set the base tier (1=cheap, 2=medium, 3=high-res)
2. **Node pattern complexity** (`_effective_scan_mode`) — per-node downgrade based on the node's own signal length. Simple patterns don't justify expensive scanning:
   - ≤3 tokens → capped at tier 1 (**bidirectional** `_bidirectional_cheap_scan`)
   - 4–8 tokens → capped at tier 2 (medium scan, single direction)
   - \>8 tokens → no cap (full tier from input complexity)

The tier can only go **down**, never up. If the input demands cheap scan, the node can't push it to high-res. But if the input demands high-res, a tiny node pattern drops it back to cheap. Tier-1 nodes additionally get bidirectional smoothing to resolve the order-sensitivity of `words_to_signal` encoding — "dog bites man" and "man bites dog" both match regardless of which order the connector pattern was encoded.

## Image SDF (`ImageSDF`)

- `detect_image_binary(input)` — detects Base64 image data URIs or raw binary image headers. Returns `(found::Bool, format::Symbol, payload::String)`.
- `JITGPU(binary; width, height)` — **GPU-accelerated** nonlinear SDF conversion via `KernelAbstractions.jl`. Dispatches `@kernel` functions to `CUDABackend()`, `ROCBackend()`, `MetalBackend()`, or `CPU()` (multithreaded, CI-safe) based on runtime detection. Two-pass kernel: Pass 1 decodes pixels in parallel; `synchronize(backend)` ensures all neighbors exist before Pass 2 computes `tanh(3 × grad_mag)` SDF activations. Returns `SDFParams`.
- `image_to_sdf_params(pixels, width, height)` — CPU reference implementation (same algorithm as `JITGPU` but Float64 throughout). **Test-only** — all production image paths now use `JITGPU`.
- `SDFParams` — struct holding the SDF representation of an image for pattern scanning.
- `apply_sdf_jitter(params::SDFParams)` — injects small bounded per-element noise into SDF brightness/gradient values. Called each time an SDF fires to prevent identical repeat activations. Returns a new `SDFParams`.
- `sdf_to_signal(params::SDFParams)` — flattens `SDFParams` into a `Vector{Float64}` signal for pattern scanning. Interleaves brightness and gradient values.

## Semantic Verbs (`SemanticVerbs`)

- `add_verb!(verb, class)` — register a new causal/relational verb
- `add_relation_class!(class)` — add a new relation class
- `add_synonym!(canonical, alias)` — register a synonym alias

## Action+Tone Predictor (`ActionTonePredictor`)

Pre-vote reflex prediction layer. Fires BEFORE the vote pool assembles. Classifies input into an **action family** (what the user intends to DO) and a **tone family** (HOW they sound doing it). Two outputs feed back into the cave: `arousal_nudge` (applied to EyeSystem) and `action_weight` (multiplied into node confidence during scan).

### Enums

- `ActionFamily` — `ACTION_ASSERT`, `ACTION_QUERY`, `ACTION_COMMAND`, `ACTION_NEGATE`, `ACTION_SPECULATE`, `ACTION_ESCALATE`
- `ToneFamily` — `TONE_HOSTILE`, `TONE_CURIOUS`, `TONE_DECLARATIVE`, `TONE_URGENT`, `TONE_NEUTRAL`, `TONE_REFLECTIVE`

### Types

- `PredictionResult` — Immutable prediction packet carrying: `action_family`, `tone_family`, `confidence`, `incomplete_chain`, `dangling_verb`, `arousal_nudge`, `action_weight`, `timestamp`, `action_distribution` (normalized probability distribution over action families), `tone_distribution` (normalized over tone families), `trajectory_damped` (true if Lorenz damping was applied).
- `TrajectoryConfig` — Tuning knobs for trajectory normalization: `buffer_size` (ring buffer depth, default 16), `decay_halflife` (seconds, default 120), `gini_threshold` (Lorenz trigger, default 0.72), `damping_strength` (redistribution intensity, default 0.25), `softmax_temperature` (normalization sharpness, default 1.5).

### Core Functions

- `predict_action_tone(input_text, all_verbs) → PredictionResult` — Main entry point. Scores input against lexicons, softmax-normalizes into probability distributions, applies Lorenz trajectory damping if strange attractor detected, detects incomplete causal chains. Thread-safe.
- `apply_prediction_to_arousal!(prediction, get_arousal_fn, set_arousal_fn!)` — Apply arousal nudge to EyeSystem via decoupled function handles. No-ops on zero nudge.
- `get_action_weight_multiplier(prediction, node_action_name) → Float64` — Returns confidence multiplier for a node based on action family alignment. Aligned > 1.0, misaligned < 1.0, weak prediction = 1.0.
- `format_prediction_summary(prediction) → String` — Compact human-readable summary for logging. Includes `[LORENZ-DAMPED]` tag when damping was active.

### Trajectory & Attractor Avoidance

- `reset_trajectory!()` — Clear all trajectory history and reset config to defaults. Thread-safe.
- `set_trajectory_config!(config::TrajectoryConfig)` — Override trajectory tuning knobs. Validates all fields — throws `FATAL` on invalid values.
- `get_trajectory_state() → (centroid_action, centroid_tone, gini_action, gini_tone, buffer_len)` — Read-only snapshot of current trajectory state for diagnostics.

### Softmax Normalization

Raw lexicon scores are converted into proper probability distributions via temperature-scaled softmax. This provides **length invariance**: a 3-word and a 30-word input expressing the same intent produce similar distributions. Temperature (default 1.5) is warm — keeps minority signals alive while letting clear winners dominate.

### Lorenz Damping (Strange Attractor Avoidance)

A ring buffer of the last N (default 16) normalized prediction distributions tracks the system's path through action-tone space. Each entry decays exponentially by age (halflife-based). The trajectory centroid's **Gini coefficient** is monitored:

- Gini < threshold (0.72): system is exploring normally — no damping
- Gini ≥ threshold: strange attractor detected — one category dominates. **Lorenz damping** redistributes mass from overrepresented to underrepresented categories in the CURRENT prediction. This is the discrete analog of Lorenz curve wealth redistribution to avoid chaotic concentration.

Damping intensity scales with overshoot: just barely past threshold → gentle nudge, way past → stronger correction. The trajectory records the damped distribution (what the system actually used), not the raw prediction.

## Lobe System (`Lobe`)

- `create_lobe!(subject)` — create a named subject partition
- `connect_lobes!(lobe_a, lobe_b)` — link two lobes for cross-domain signal propagation
- `lobe_grow!(lobe_id, node_id)` — assign a node to a lobe (enforces capacity cap)

## Lobe Table (`LobeTable`)

- `create_lobe_table!(lobe_id)` — initialize the chunked hash table for a lobe

## BrainStem (`BrainStem`)

Winner-take-all dispatcher. Routes the highest-confidence vote to the correct lobe and propagates a decayed signal (60% of winning confidence) to connected lobes.

## Thesaurus (`Thesaurus`)

Multi-axis similarity engine with semantic, contextual, and associative dimensions. Seeded with a synonym dictionary at startup; extensible at runtime via `SemanticVerbs.add_synonym!`.

## Attachment System (Relational Fire)

The attachment system enables explicit relational firing chains between nodes. It lives in `engine.jl` alongside the core node engine. Supports both text nodes (`/nodeAttach`) and image nodes (`/imgnodeAttach`).

### Data Structures

- `AttachedNode` — Immutable struct holding:
  - `node_id::String` — ID of the attached node
  - `pattern::String` — Connector/middleman pattern (text) or SDF metadata (`"SDF:image:WxH"` for image attachments)
  - `signal::Vector{Float64}` — Pre-baked signal (text: via `words_to_signal`; image: via `sdf_to_signal`)
  - `base_confidence::Float64` — JIT-baked confidence computed at attach time (not at fire time)
- `ATTACHMENT_MAP` — `Dict{String, Vector{AttachedNode}}` mapping target node IDs to their attached nodes
- `ATTACHMENT_LOCK` — `ReentrantLock` for thread-safe access
- `MAX_ATTACHMENTS` — Hard cap of 4 attachments per target (shared between text and image)
- `RELAY_CONF_JITTER_SIGMA` — `0.05`, stochastic jitter applied at fire time to pre-baked confidence

### Functions

- `attach_node!(target_id, attach_id, pattern)` — Attach a text node to a target with a connector pattern (middleman). JIT confidence baking: the connector pattern is scanned against the **attached node's own pattern** at attach time via `_token_overlap_similarity()`, combined with a strength bonus `(strength / STRENGTH_CAP) * 0.5`, and stored as `base_confidence`. The signal is pre-baked via `words_to_signal()`. Validates: non-empty arguments, node existence, grave status, self-attach prevention, max cap, duplicate prevention. Returns a human-readable confirmation string including the baked `base_confidence`.

- `attach_image_node!(target_id, attach_id, image_data, width, height)` — Attach an image node to a target with SDF-based relational fire. JIT GPU accel: image binary is converted to nonlinear SDF at attach time via `JITGPU(image_data; width, height)` (real KernelAbstractions.jl kernel dispatch — CUDA/ROC/Metal/CPU), flattened to a signal via `sdf_to_signal()`, and `base_confidence` is baked from `_sdf_signal_similarity()` (cosine similarity) + strength bonus. The attach node **must** be an image node (`is_image_node=true`). Pattern field stores `"SDF:image:WxH"` metadata. All validations from `attach_node!` apply, plus image-specific checks (non-empty data, valid dimensions, image node requirement).

- `detach_node!(target_id, attach_id)` — Remove a specific attachment (works for both text and image). Cleans up the target's entry entirely if no attachments remain. Returns a confirmation string.

- `fire_attachments!(target_id, active_count, active_cap)` — Called during Pass 3 of `scan_and_expand()`. For each attached node: checks the active cap gate, verifies the node is alive, runs a strength-biased coinflip, then applies **only jitter** to the pre-baked `base_confidence`: `confidence = max(0.1, att.base_confidence + randn() * RELAY_CONF_JITTER_SIGMA)`. Calls `bump_strength!` on winners. Returns `Vector{Tuple{String, Float64, String}}` of `(node_id, confidence, connector_pattern)` triples. The connector pattern surfaces downstream as a `RelationalTriple("target_id", "relay_attached", connector_pattern)`.

- `_sdf_signal_similarity(sig_a, sig_b)` — Cosine similarity between two SDF-derived signal vectors, clamped to `[0.0, 1.0]`. Image-domain equivalent of `_token_overlap_similarity`. Truncates to the shorter signal length. Errors on empty signals.

- `get_attachment_summary()` — Returns a formatted string showing every target and its attached nodes with `base_confidence`, patterns, and slot usage. Used by the `/attachments` CLI command.

- `get_attachments_for_target(target_id)` — Simple accessor returning the `Vector{AttachedNode}` for a given target (empty vector if none).

## PhagyMode (`PhagyMode`)

Idle maintenance automata system with seven automata. Exported functions and types:

### Types

- `PhagyStats` — Return type for all automata. Fields: `automaton::String` (name), `items_examined::Int`, `items_changed::Int`, `cycle_time_ms::Float64`, `notes::String` (human-readable report).
- `PhagyError` — Custom exception type for structural failures (invalid locks, corrupted state). Always propagated, never silently swallowed.

### Core Functions

- `run_phagy!(node_map, node_lock, hopfield_cache, cache_lock, rules, rules_lock; message_history=nothing, history_lock=nothing)::PhagyStats` — Main entry point. Randomly selects one of seven automata to run. Automaton 7 (Memory Forensics) requires the optional `message_history` and `history_lock` kwargs; if not provided and Automaton 7 is rolled, re-rolls to 1–6.
- `get_phagy_log()::Vector{PhagyStats}` — Returns a copy of the `PHAGY_LOG` ring buffer (last 50 cycle results).

### Memory Forensics Functions

- `run_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Dispatcher. Validates locks, flips a coin (`rand(Bool)`), routes to fuzzy or metric mode. Returns `PhagyStats` with findings in the `notes` field.
- `fuzzy_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Approximate heuristic analysis. Samples up to 500 messages for role balance, 1000 nodes for pattern diversity and strength distribution, 200 messages for echo detection. Returns `PhagyStats` with automaton name `"MEMORY_FORENSICS_FUZZY"`.
- `metric_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats` — Exact measurement-based analysis. Full enumeration of message census, node population, dead reference audit, pinned tracking, strength statistics, and orphan count. Returns `PhagyStats` with automaton name `"MEMORY_FORENSICS_METRIC"`.

### Forensics Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `FORENSICS_STALE_MSG_RATIO` | `0.90` | Role imbalance threshold — flag if one role exceeds 90% of messages |
| `FORENSICS_DEAD_REF_THRESHOLD` | `0.10` | Dead reference alert — flag if >10% of node refs in messages are dead |
| `FORENSICS_PATTERN_ENTROPY_LO` | `0.15` | Low diversity — flag if <15% unique patterns among alive nodes |
| `FORENSICS_STRENGTH_SKEW_MAX` | `0.80` | Monoculture — flag if >80% of nodes cluster in one strength band |

## Input Queue (`InputQueue`)

Bounded input queue with integrated `NegativeThesaurus` inhibition filter. Strips inhibited tokens before pattern matching begins.

## Immune System (`ImmuneSystem`)

Automata-based anomaly detection for all structure-storing commands. Activates once the specimen reaches maturity (≥ 1000 nodes). Built around a shared `immune_gate()` helper in `Main.jl`.

### Types

- `ImmuneError` — Custom exception thrown when input is rejected. Fields: `kind::Symbol` (`:funky_deleted`, `:duplicate_anomaly`, etc.), `signature::UInt64` (hex fingerprint of the rejected input), `info::String` (human-readable reason).

### Core Functions

- `immune_scan!(input_text, node_count; is_critical=true) → (Symbol, UInt64)` — Main gate entry point. Returns `(status, signature)` where status is one of: `:immature` (below maturity threshold, pass-through), `:known` (familiar safe input), `:quarantine_patched` (funky but repaired), `:deleted` (rejected). Throws `ImmuneError` on hard rejection.
- `reset_immune_state!()` — Clear all immune Hopfield memory and ledger. Called during specimen wipe/replace.
- `serialize_immune_state() → Dict` — Export immune state (Hopfield memory + ledger) for specimen save.
- `deserialize_immune_state!(data::Dict)` — Restore immune state from specimen data.

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MATURITY_THRESHOLD` | 1000 | Node count required before immune system activates |
| `AUTOMATA_POPULATION_RATIO` | 1/3 | Automata count = nodes ÷ 3 |
| `COINFLIP_PROBABILITY` | 0.5 | Per-agent materialization probability |
| `PATCH_TIMEOUT_SECONDS` | 2.0 | Max time for patch attempt (±0.5s jitter) |
| `HOPFIELD_FAMILIARITY_THRESHOLD` | 3 | Sightings before a signature is "strongly known" |

### CLI Helper (`immune_gate`)

```julia
immune_gate(cmd_name, input_text; is_critical=true) → Bool
```

Shared helper in `Main.jl` used by all structure-storing commands. Returns `true` if input passed, `false` if rejected. Logs all decisions. Non-immune errors warn but do not block (immune system crash ≠ command block).

## Full-Lobe Scanner (`FullLobeScanner`)

Phase-gated associative memory scanner that sweeps an entire lobe's feature-vector space. Unlike `scan_specimens` (which works on the flat `NODE_MAP`), `FullLobeScanner` operates on a `Dict{String, Vector{Float64}}` feature dictionary and produces typed matches with spreading-activation semantics. All activations are bounded to prevent runaway expansion.

### Scan Phases

The scanner advances through a strict one-way phase machine:

| Phase | Constant | Description |
|-------|----------|-------------|
| Init | `PHASE_INIT` | Scanner created, no query set yet |
| Gather | `PHASE_GATHER` | Query set; ready to collect candidates |
| Activate | `PHASE_ACTIVATE` | Candidates scored and ranked |
| Continue | `PHASE_CONTINUE` | Spreading activation propagating |
| Done | `PHASE_DONE` | DONE signal emitted; AIML may fire |

### Match Types

- `PatternMatch` — direct cosine similarity hit between input query and a stored feature vector. Fields: `node_id::String`, `confidence::Float64`, `matched_pattern::String`, `source_lobe::String`.
- `SemanticMatch` — spreading-activation secondary hit: a node that is similar to a `PatternMatch` winner. Fields: `node_id::String`, `confidence::Float64`, `seed_node_id::String`, `semantic_distance::Float64`, `source_lobe::String`.

### Core Functions

- `FullLobeScannerState(lobe_id; threshold, max_hops)` — Construct a scanner for a given lobe. Optional kwargs: `threshold::Float64` (minimum confidence to include a candidate, default `SCANNER_CONFIDENCE_THRESHOLD = 0.65`) and `max_hops::Int` (spreading-activation depth, default `SCANNER_MAX_HOPS = 3`).
- `set_query!(scanner, query_vector)` — Set the query signal and advance phase to `PHASE_GATHER`. Throws `FullLobeScannerError` if query is empty or scanner is past `PHASE_INIT`.
- `gather_candidates!(scanner, feature_dict)` — Score all features against the query via cosine similarity. Advances phase to `PHASE_ACTIVATE`. Thread-safe: spawns up to `SCANNER_THREADS` (default 4) parallel tasks. Bounded by `MAX_ACTIVE_NODES = 1000`.
- `activate_candidates!(scanner)` — Rank candidates, apply `slight_jitter` for vote diversity, advance to `PHASE_CONTINUE`. Returns sorted `Vector{PatternMatch}`.
- `spread_activation!(scanner, feature_dict)` — Walk the ranked candidates and find semantically similar neighbors via cosine distance. Adds `SemanticMatch` results. Advances to `PHASE_DONE`.
- `emit_done_signal!(scanner)` — Emits the DONE marker and locks AIML gating open. Must be called after `PHASE_DONE` is reached. Throws if called out of sequence.
- `get_pattern_matches(scanner)` — Returns `Vector{PatternMatch}` (available after `PHASE_ACTIVATE`).
- `get_semantic_matches(scanner)` — Returns `Vector{SemanticMatch}` (available after `PHASE_DONE`).
- `is_aiml_gated(scanner)` — Returns `true` until `emit_done_signal!` is called. AIML layer must check this before using results.
- `reset_scanner!(scanner)` — Reset to `PHASE_INIT` and clear all results. Reuse the same scanner object for the next query.

### Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `MAX_ACTIVE_NODES` | `1000` | Hard cap on candidates entering the active set |
| `SCANNER_CONFIDENCE_THRESHOLD` | `0.65` | Minimum cosine similarity to include a candidate |
| `SCANNER_MAX_HOPS` | `3` | Maximum spreading-activation depth |
| `SCANNER_THREADS` | `4` | Worker threads for parallel candidate gathering |
| `SEMANTIC_DISTANCE_THRESHOLD` | `0.70` | Cosine distance cutoff for semantic neighbor inclusion |

### AIML Gating

Results are **blocked from AIML until `PHASE_DONE`** is reached and `emit_done_signal!` is called. Always check `is_aiml_gated(scanner)` before handing results to the orchestrator:

```julia
scanner = FullLobeScannerState("science"; threshold=0.7)
set_query!(scanner, query_vec)
gather_candidates!(scanner, feature_dict)
activate_candidates!(scanner)
spread_activation!(scanner, feature_dict)
emit_done_signal!(scanner)

if !is_aiml_gated(scanner)
    matches = get_pattern_matches(scanner)
    # hand matches to orchestrator
end
```

### Error Types

- `FullLobeScannerError` — thrown on out-of-sequence phase transitions, empty queries, or structural violations. Never silently swallowed (GRUG style).

---

## Immune Thread Pool (`ImmuneThreadPool`)

Priority-lane thread pool with per-source rate limiting, cost-weighted load balancing, and a tripwire state machine. Provides hardened task execution for scan workloads that must not overwhelm the system under adversarial or runaway conditions.

### Priority Lanes

Tasks are submitted with a priority level. Each priority has its own waiting list bounded by `MAX_WAITING_LIST_SIZE_PER_PRIORITY`:

| Priority | Constant | Use case |
|----------|----------|---------|
| Critical | `PRIORITY_CRITICAL` | Immune system responses, hard deadlines |
| Normal | `PRIORITY_NORMAL` | Standard scan tasks |
| Low | `PRIORITY_LOW` | Background maintenance |
| Junk | `PRIORITY_JUNK` | Throwaway / test tasks |

### Rate Limiting

Each source (`SOURCE_EXTERNAL`, `SOURCE_INTERNAL`, `SOURCE_SCANNER`) has its own `TokenBucket`. Internal sources bypass rate limiting. External sources are subject to standard limits; limits tighten when the tripwire is hardened.

| Constant | Value | Description |
|----------|-------|-------------|
| `RATE_LIMIT_TOKENS_PER_SEC` | Dict per source | Normal-state token refill rates |
| `RATE_LIMIT_BURST` | Dict per source | Normal-state burst capacity |
| `RATE_LIMIT_TOKENS_PER_SEC_HARDENED` | Dict per source | Hardened-state refill rates (reduced) |
| `RATE_LIMIT_BURST_HARDENED` | Dict per source | Hardened-state burst capacity (reduced) |

### Tripwire State Machine

The `TripwireMonitor` watches the rejection rate over a sliding window (`TRIPWIRE_WINDOW_S` seconds) and escalates the system's defense posture:

```
NORMAL ──(rejection rate > TRIPWIRE_ELEVATED_THRESHOLD)──► ELEVATED
ELEVATED ──(rate > TRIPWIRE_HARDENED_THRESHOLD)──► HARDENED
HARDENED ──(rate > TRIPWIRE_CRITICAL_THRESHOLD)──► CRITICAL
CRITICAL / any ──(rate drops below ELEVATED threshold)──► NORMAL
```

| Constant | Default | Description |
|----------|---------|-------------|
| `TRIPWIRE_WINDOW_S` | `60.0` | Sliding window for rejection rate calculation |
| `TRIPWIRE_ELEVATED_THRESHOLD` | `0.10` | 10% rejection rate triggers ELEVATED |
| `TRIPWIRE_HARDENED_THRESHOLD` | `0.25` | 25% triggers HARDENED (rate limits tighten) |
| `TRIPWIRE_CRITICAL_THRESHOLD` | `0.50` | 50% triggers CRITICAL |

### Core Functions

- `create_immune_thread_pool(n_workers)` — Create a pool with `n_workers` worker threads (default 8). Returns `ImmuneThreadPool`.
- `submit_immune_work!(pool, task_id, cost_ms; priority, source)` — Submit a task. `cost_ms` is estimated work duration in milliseconds. `priority` defaults to `PRIORITY_NORMAL`, `source` defaults to `SOURCE_EXTERNAL`. Throws `ImmuneRateLimitExhaustedError` if the rate limit is hit, `ImmuneWaitingListFullError` if the lane's waiting list is full.
- `shutdown_immune_pool!(pool)` — Graceful shutdown: drain queues, stop workers.
- `get_tripwire_state(monitor)` — Returns the current tripwire state symbol (`:normal`, `:elevated`, `:hardened`, `:critical`).
- `get_rejection_rate(monitor)` — Returns the current rejection rate in the sliding window as a `Float64`.
- `get_lane_size(pool, priority)` — Returns the number of tasks currently waiting in a priority lane.
- `try_consume!(bucket, n)` — Attempt to consume `n` tokens from a `TokenBucket`. Returns `true` on success, `false` on exhaustion. Auto-refills based on elapsed time.
- `refill!(bucket)` — Force a time-based refill of a `TokenBucket` without consuming.
- `record_processed!(monitor)` — Record a successfully processed task in the tripwire window.
- `update_tripwire_state!(monitor)` — Recompute tripwire state from current rejection rate and advance state machine.
- `estimate_scan_cost(node_count, complexity) → ScanCost` — Estimate the scan cost category from node count and complexity score. Returns `COST_CHEAP`, `COST_MODERATE`, or `COST_EXPENSIVE`.

### Cost Weights

`COST_WEIGHTS::Dict{ScanCost, Int}` maps each cost category to a relative weight used for load balancing across workers:

| Cost | Constant | Weight |
|------|----------|--------|
| Cheap | `COST_CHEAP` | 1 |
| Moderate | `COST_MODERATE` | 3 |
| Expensive | `COST_EXPENSIVE` | 8 |

### Error Types

- `ImmuneRateLimitExhaustedError` — thrown when a source's token bucket is empty.
- `ImmuneWaitingListFullError` — thrown when a priority lane's waiting list has reached `MAX_WAITING_LIST_SIZE_PER_PRIORITY`.

---

## AIML Node System (`AIMLNodeSystem`)

Per-lobe AIML node tribes with isolated populations and independent population caps. Each lobe maintains its own AIML registry (a "tribe") with configurable caps.

### Core Functions

- `register_lobe!(lobe_id::String, node_cap::Int)` — Register a lobe for AIML nodes. Creates a tribe entry with population cap = `node_cap ÷ 3`. Throws `AIMLNodeError` if lobe_id is empty or already registered.
- `add_aiml_node!(lobe_id::String, node_id::String, template_id::String)` — Add an AIML node to a lobe's tribe. Checks population cap against **alive nodes only** (graves don't count). Throws `AIMLNodeError` on: empty ids, unregistered lobe, duplicate node_id, or cap exceeded.
- `get_aiml_node(lobe_id::String, node_id::String)` — Retrieve an AIML node by ID. Returns the `AIMLNode` struct or throws `AIMLNodeError` if not found.
- `get_population_size(lobe_id::String)::Int` — Total AIML node count in a lobe's tribe (includes graves).
- `get_alive_population_size(lobe_id::String)::Int` — Number of **alive** AIML nodes (excludes graves). This is the number used for population cap enforcement.
- `remove_aiml_node!(lobe_id::String, node_id::String)` — Remove an AIML node from a tribe. Throws `AIMLNodeError` if lobe or node not found.

### AIMLNode Struct

```julia
mutable struct AIMLNode
    node_id::String
    template_id::String
    is_grave::Bool
    reinforcement_count::Int
    last_cycle_id::Union{String, Nothing}
end
```

- `node_id` — Unique identifier within the tribe
- `template_id` — Template reference for AIML generation
- `is_grave` — Death flag; when `true`, node doesn't count towards cap
- `reinforcement_count` — Number of times node has been reinforced
- `last_cycle_id` — Optional cycle identifier for cycle-aware reinforcement

### Population Cap Enforcement

Caps are enforced against **alive population only**. Graves are memory, not bloat — dead nodes don't eat cap space.

```
ALIVE nodes = tribe nodes where is_grave == false
CAP_CHECK: alive_count < cap
```

This design prevents "cap lock" scenarios where accumulated graves block new node creation. When an AIML node dies (marked as grave), it immediately frees cap space for new nodes.

### Thread Safety

All AIML operations are protected by `AIML_LOCK::ReentrantLock`. The lock is held for the duration of each operation to ensure thread-safe access to `AIML_REGISTRY`.

### Error Type

- `AIMLNodeError` — thrown on all validation failures with descriptive messages including the offending lobe_id, node_id, and operation name.

---

## Vote Orchestrator (`ephemeral_aiml_orchestrator`)

Main response generation entry point in `Main.jl`. Handles vote bucketing, tie-breaking, and AIML payload construction.

### Vote Certainty

- **SURE** — Primary vote had a clear confidence lead (no exact ties in the sure-vote basket)
- **UNSURE** — Multiple votes tied at the same confidence; winner chosen randomly via `shuffle!`

Tied alternatives (non-selected tied winners) are available as `Vote[]` via local variable `tied_alternatives`. Strong runner-ups that survived the coinflip enter `unsure_votes`.

### AIML Rule Tags

| Tag | Source |
|-----|--------|
| `{VOTE_CERTAINTY}` | `"SURE"` or `"UNSURE"` |
| `{TIED_ALTERNATIVES}` | Comma-separated `node_id(action,conf=X.XX)` strings |
| `{MISSION}` | Raw input text |
| `{PRIMARY_ACTION}` | Winning vote's action name |
| `{SURE_ACTIONS}` | Comma-separated action names from sure-vote basket |
| `{UNSURE_ACTIONS}` | Comma-separated action names from unsure-vote coinflips |
| `{ALL_ACTIONS}` | All actions from all votes |
| `{CONFIDENCE}` | Primary vote confidence (2 decimal places) |
| `{NODE_ID}` | Primary vote's node ID |
| `{MEMORY}` | Formatted recent + pinned memory |
| `{LOBE_CONTEXT}` | Prefrontal lobe context string |