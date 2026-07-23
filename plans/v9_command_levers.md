# v9 Command Levers — Exposing Implicit Computations

## Philosophy

Grug already computes most of the v9 meta-cognitive features implicitly. The
coherence field, gradient routing, phase-space geometry, pattern mining, and
temporal identity are all latent in the existing codebase. What's missing is
*explicit command levers* — CLI commands that let the operator see, configure,
and use these computations without adding new algorithmic modules.

This document maps every implicit computation to the CLI command that would
expose it, along with implementation priority and wiring estimates.

## Quantum Emulation Warning

The coherence field Φ + gradient routing ΔΦ + phase relationships creates
genuine attractor dynamics analogous to quantum measurement. With weight > 0,
the system will prefer coherent states and resist incoherent ones. This is
**the intended behavior** — it's the whole point of coherence-gradient routing.
But it means the system can become resistant to correction.

**Weight above 0.3 risks "quantum Zeno effect"** — frequent routing locks the
state, making the system unable to escape its current attractor basin. This is
not a bug; it's a physical consequence of the mathematics.

**Mitigations:**
- Weight defaults to 0.0 (OFF). No surprise activations.
- Recommended starting weight: 0.05. Always start low.
- `/coherenceConfig reset` snaps back to weight=0.0 instantly.
- The gradient is ADDITIVE to the existing vote score, not multiplicative.
  Even at weight=0.5, a node with high confidence but negative ΔΦ still wins
  if its raw confidence is high enough.

---

## Command Group 1: Coherence Field (Priority 1 — IMPLEMENTED)

These commands expose the scalar coherence field Φ and its gradient ΔΦ.

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/coherence` | Current field value Φ + routing status | Calls `CoherenceField.compute_field()` |
| `/coherenceGradient <node_id>` | ΔΦ for a candidate node | Calls `CoherenceField.compute_delta()` |
| `/coherenceField` | Detailed field breakdown (top/bottom contributors, active count) | Calls `CoherenceField.coherence_field_status()` |
| `/coherenceConfig` | Show config (weight, depth, decay, recency) | Reads `COHERENCE_FIELD_CONFIG` |
| `/coherenceConfig weight <float>` | Set routing weight (0.0=off, max 0.5) | Calls `CoherenceField.set_coherence_config!(:weight, ...)` |
| `/coherenceConfig depth <int>` | Set gradient walk depth (1-3) | Calls `CoherenceField.set_coherence_config!(:depth, ...)` |
| `/coherenceConfig decay <float>` | Set activation decay rate | Calls `CoherenceField.set_coherence_config!(:decay, ...)` |
| `/coherenceConfig recency <float>` | Set recency window (seconds) | Calls `CoherenceField.set_coherence_config!(:recency_window, ...)` |
| `/coherenceConfig reset` | Reset to defaults (weight=0.0) | Calls `CoherenceField.reset_coherence_config!()` |

**Module:** `src/CoherenceField.jl` (new, 669 lines)
**Wiring:** Include after ActionTonePredictor in GrugBot420.jl, guard-include in Main.jl
**Vote integration:** Future: add `coherence_delta` field to VoteCandidate + `VOTE_W_COHERENCE_DELTA = 0.0` weight

---

## Command Group 2: Phase Space (Priority 2)

These commands expose the four named geometric spaces that already exist in
the codebase with real distance functions.

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/phaseSpace` | Overview of all four spaces + current position | Aggregates from existing functions |
| `/phaseSpace semantic <a> <b>` | Semantic space distance between two nodes | Calls `_semantic_truth_score()` |
| `/phaseSpace coherence <a> <b>` | Coherence space distance | Compares Φ-contribution of two nodes |
| `/phaseSpace phase <a> <b>` | Phase space distance (JS on 12-dim ATP) | Calls `_distribution_js_distance()` |
| `/phaseSpace tone <a> <b>` | Tone space distance | Calls TonalJudge distance |
| `/phaseSpace nearest <node_id>` | Nearest neighbors across all spaces | Combines phase_pull_query + semantic |

**Existing code:**
- `EphemeralAutomaton._distribution_js_distance()` — JS distance on 12-dim ATP vectors
- `EphemeralAutomaton.phase_pull_query()` — nearest-neighbor in phase space
- `engine._semantic_truth_score()` — relational triple anchoring
- `TonalJudge` — tone space computations

**New wiring:** Thin wrapper module `GeometryKit.jl` that cross-references the
four spaces and provides a unified `/phaseSpace` CLI interface.

---

## Command Group 3: Geometry (Priority 3)

These commands expose the state-space geometry that emerges from the four
named spaces.

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/geometry` | Overview of state-space geometry | Aggregates from all spaces |
| `/geometry trajectory` | Current trajectory through state space | Reads PhaseSnapshot history |
| `/geometry attractors` | Current attractor basins | Analyzes phase accumulator |
| `/geometry distance <space> <a> <b>` | Distance in named space | Dispatches to space-specific function |

**Existing code:**
- PhaseSnapshot accumulation in EphemeralAutomaton
- ActionTonePredictor strange-attractor detection (Gini coefficient)
- CoherenceField Φ computation

**New wiring:** Part of GeometryKit.jl module.

---

## Command Group 4: Pattern Mining (Priority 4)

These commands expose the recurring graph shapes that RelationalGovernance
already detects at the pair level.

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/mineShapes` | List recurring graph shapes | Extends RelationalGovernance co-firing |
| `/mineShapes depth <n>` | Set mining depth (2-4) | Config for PatternMiner |
| `/mineShapes promote <shape_id>` | Promote shape to :relation sigil | Fills Stage 6 :procedure slot |

**Existing code:**
- `RelationalGovernance.observe_co_firing!()` — tracks pair-level co-activation
- `AUTO_ATTACH_THRESHOLD = 10.0` — already detecting recurring patterns
- `SigilRegistry` — `:relation` class for dynamic relation sigils

**New module:** `PatternMiner.jl` that watches the triple store for recurring
graph shapes (not just pairs) and proposes new `:relation` sigils.

---

## Command Group 5: Temporal Identity (Priority 5)

These commands expose the temporal chain grouping that already exists
implicitly through time-node sigils (&now, &before, &next).

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/identity` | List temporal identities | Groups nodes by temporal chain |
| `/identity create <name>` | Create a temporal identity | First-class continuant object |
| `/identity chain <name>` | Show chain for an identity | Walks &now/&before/&next links |
| `/identity merge <a> <b>` | Merge two identities | Re-links temporal chains |

**Existing code:**
- Time node sigils: `&now`, `&before`, `&next` in SigilRegistry
- TemporalCoherenceRecord in ImageSDF
- `time_orientation_config` in specimen save/load

**New module:** `TemporalIdentity.jl` with first-class continuant objects.

---

## Command Group 6: Structure Sigils (Priority 6)

These commands fill the reserved Stage 6 `:procedure` slot in the sigil
registry with ordered sequences of sigil references.

| Command | What it exposes | Implementation |
|---------|-----------------|----------------|
| `/sigil addStructure <name> [sig1 sig2 ...]` | Register a :structure sigil | Fills Stage 6 slot |
| `/sigil expand <name>` | Show expansion of a structure sigil | Walks ordered sequence |

**Existing code:**
- `SigilRegistry.SIGIL_CLASSES` already includes `:procedure` (Stage 6)
- `SigilRegistry.SIGIL_CLASSES` already includes `:functor` (Stage 6)

**New wiring:** Extend `/sigil add` to accept `:structure` class with ordered
sequence expansion.

---

## Implementation Priority

1. **CoherenceField** (Priority 1) — ✅ IMPLEMENTED
   - New module: CoherenceField.jl (669 lines)
   - CLI: /coherence, /coherenceGradient, /coherenceField, /coherenceConfig
   - Specimen save/load: coherence_config section

2. **PhaseSpace** (Priority 2) — Thin wrapper around existing functions
   - New module: GeometryKit.jl (~200 lines)
   - CLI: /phaseSpace, /phaseSpace semantic/coherence/phase/tone/nearest

3. **Geometry** (Priority 3) — Aggregation over PhaseSpace
   - Part of GeometryKit.jl
   - CLI: /geometry, /geometry trajectory/attractors/distance

4. **MineShapes** (Priority 4) — Extends RelationalGovernance
   - New module: PatternMiner.jl (~300 lines)
   - CLI: /mineShapes, /mineShapes depth/promote

5. **Identity** (Priority 5) — First-class temporal continuants
   - New module: TemporalIdentity.jl (~250 lines)
   - CLI: /identity, /identity create/chain/merge

6. **Structure Sigils** (Priority 6) — Fills Stage 6 slot
   - Extension to existing /sigil add handler
   - No new module needed

---

## Specimen Save/Load Integration

Each command group that has persistent config needs a save section in
`save_specimen_to_file!()` and a load section in `load_specimen_from_file!()`.

| Section | Key | Priority |
|---------|-----|----------|
| CoherenceField config | `coherence_config` | 1 |
| GeometryKit config | `geometry_config` | 2-3 |
| PatternMiner config | `pattern_miner_config` | 4 |
| TemporalIdentity map | `temporal_identities` | 5 |

All keys must be added to the `allowed_keys` set in `load_specimen_from_file!()`.
