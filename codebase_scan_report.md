# GrugBot420 Codebase Scan Report
## Branch: `v7.15-updates` @ commit `7969b4a`

---

## 1. Specimen ↔ Engine Gap Analysis

The `comprehensive_v3_specimen.json` (92 nodes, 13 lobes) is significantly ahead of the current engine code. It carries **44 top-level keys** that `load_specimen_from_file!` has no `haskey()` branches for — they will be silently dropped on load. Conversely, `save_specimen_to_file!` never writes them, so a round-trip loses all of this data.

### 1.1 New Top-Level Config Keys (44 total, all silently dropped on load)

| Category | Key | Type | Notes |
|---|---|---|---|
| **Decomposer** | `decomposer_config` | dict | compound_pairs, question_markers, split_conjunctions, conjugation_rules — the full InputDecomposer spec |
| **Answer Modes** | `answer_mode_config` | dict | 12 modes (define, math, time, proc, multi, explain, alert, comfort, json, relate, poetry, reason) with voice/action/frame/prompt |
| **Automaton** | `automaton_rules` | list | 3 rules (creative_escalation, alert_escalation, empathy_escalation) with steps, ops, jitter_targets — concrete seed for StepCoherenceAutomaton |
| **Coherence** | `coherence_config` | dict | depth, weight, decay, cache_ttl, recency_window |
| **Growth** | `growth_config` | dict | group_strength_floor, growth_batch_size, growth_probability_ceiling, etc. |
| **Mitosis** | `mitosis_config` | dict | mitosis_probability, strain_warrant_weight, max_population_cap, etc. |
| **Vigilance** | `vigilance_config` | dict | weight tiers, max_injectors_per_cycle, injector_timeout, etc. |
| **Fanout** | `fanout_config` | dict | enabled, max_shadows=4, 8 modes |
| **Time Orientation** | `time_orientation_config` | dict | global_orientation, time_node_index (per-node orientation + sigil) |
| **Tonal Judge** | `tonal_judge_knobs` | dict | — |
| **Lobe Orch** | `lobe_orchestrator_knobs` | dict | — |
| **Vote Orch** | `vote_orchestrator_knobs` | dict | — |
| **Relational Jitter** | `relational_jitter_config` | dict | — |
| **Engine Config** | `engine_config` | dict | — |
| **Brainstem Config** | `brainstem_config` | dict | — |
| **Immune Config** | `immune_config` | dict | — |
| **Phagy** | `phagy_config`, `phagy_rules_ref` | dict, list | — |
| **Chatter** | `chatter_config`, `chatter_cooldowns`, `chatter_cursor`, `chatter_groups`, `chatter_residuals` | mixed | ChatterMode subsystem state |
| **Scanner** | `scanner_config` | dict | — |
| **Phase Accum** | `phase_accumulator` | dict | — |
| **Autogrowth** | `autogrowth_co_occur`, `autogrowth_evidence` | list, list | — |
| **Autolink** | `autolink_evidence` | dict | — |
| **Bridges** | `bridges` | list | — |
| **Co-Activation** | `co_activation` | dict | — |
| **Curiosity** | `curiosity` | dict | — |
| **Flashcards** | `flashcards` | dict | — |
| **Hippocampal** | `hippocampal_pending_ask` | dict | — |
| **MLP** | `mlp_cached_phi`, `ephemeral_mlp`, `mlp_observer_store` | dict×3 | EphemeralMLP state |
| **Injector** | `injector_stats` | dict | — |
| **Input Ledger** | `input_ledger` | dict | — |
| **Admin** | `admin_session` | dict | — |
| **Action Tone** | `action_tone_knobs` | dict | — |
| **Node→Group** | `node_to_group_idx` | dict | — |
| **Sigil Table** | `sigil_table` | list | 21 entries (vs engine's `sigils` dict key) |
| **Votes** | `last_contributor_votes` | list | — |

### 1.2 Node `json_data` Fields (new, not handled on load)

The v3 specimen's nodes carry new `json_data` keys that the current engine ignores:

| Field | Prevalence (of 92 nodes) | Purpose |
|---|---|---|
| `frame_hints` | 89 nodes | Frame/styling hints (e.g. `['plain']`) for response rendering |
| `voice_register` | 89 nodes | Voice mode per node (e.g. `'plain'`, `'warm'`, `'terse'`) |
| `noun_anchors` | 89 nodes | Key nouns for the node's semantic domain |
| `time_orientation` | 6 nodes | past/present/future anchor |
| `time_node` | 6 nodes | boolean: is this a temporal anchor node |
| `time_sigil` | 6 nodes | associated temporal sigil |
| `wants_context` | 2 nodes | node requests additional context |
| `response_type` | 1 node | typed response mode |
| `unknowable` | 1 node | marks node as unknowable/philosophical |

---

## 2. Sigil Registry Gap

The v3 specimen's `sigil_table` has **21 entries** including classes and applies_at values that the current engine **rejects at registration time**:

### 2.1 New Sigil Classes Used in Specimen (REJECTED by engine)

| Name | Class | applies_at | sigil_type | Status |
|---|---|---|---|---|
| `math-chain` | **:procedure** | :bind | — | RESERVED Stage 6 — will throw |
| `similarity` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `possessive` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `produces` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `temporal` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `causal` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `spatial` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |
| `opposes` | **:relation** | :relation | — | RESERVED Stage 4-5 — will throw |

### 2.2 New applies_at Values Used in Specimen (REJECTED by engine)

| Name | applies_at | Status |
|---|---|---|
| `now`, `next`, `before` | **:tone** | RESERVED Stage 7 — will throw |

### 2.3 Existing-Class Sigils (will register fine)

| Name | Class | applies_at | sigil_type |
|---|---|---|---|
| `rest` | :lambda | :match | slurp |
| `op` | :lambda | :match | op |
| `word` | :lambda | :match | word |
| `n` | :lambda | :match | number |
| `noun` | :macro | :bind | — |
| `element` | :macro | :bind | — |
| `mathop` | :macro | :bind | — |
| `emotion` | :macro | :bind | — |
| `mood` | :lambda | :bind | string |
| `philosophical` | :tag | :match | — |

### 2.4 Key Observation: No Sigil-Tagged Node Patterns

Despite the rich sigil table, **zero** of the 92 nodes have sigil-tagged patterns (no `&n &op &n` or similar). All patterns are plain text like `"what is a planet"` or `"why is the sky blue"`. The sigils exist in the registry but are not referenced in any node's pattern field.

---

## 3. Test Log Features Not in Engine

The `test_log.md` documents a v8.1/v8.2 test run that references features **absent from the current codebase**:

| Feature | In test_log? | In engine code? | Notes |
|---|---|---|---|
| `InputDecomposer` | ✅ | ❌ | Splits compound inputs on conjunction boundaries |
| `MultipartOrchestrator` | ✅ | ❌ | Coordinates multipart vote groups, prevents arithmetic bleed |
| `scoped_mission` | ✅ | ❌ | Per-group sub-subject text (prevents cross-group binding bleed) |
| `answer_mode_config` | ✅ | ❌ | Mode-specific voice/action/frame routing |
| `decomposer_config` | ✅ | ❌ | Split rules, question markers, conjugation handling |
| `fanout_config` | ✅ | ❌ | Shadow dispatch to multiple answer modes |
| `frame_hints` | ✅ | ❌ | Per-node frame styling for response rendering |
| `voice_register` | ✅ | ❌ | Per-node voice mode selection |
| `automaton_rules` | ✅ (implied) | ❌ | Auto-escalation rules with jitter targets |

The test_log also reports engine-level bugs:
- **EphemeralMLP BoundsError**: 17 votes vs 16 weights — the specimen has more votes than the MLP was configured for
- **Coherence features MethodError**: `is_grave` field access on Node — struct field mismatch
- **BUG-004**: Multi-token patterns penalized by bidirectional scan

---

## 4. Vote Struct Status

Current `Vote` struct (engine.jl:473) has 8 fields:

```
node_id, action, confidence, negatives, user_triples, node_triples, antimatch, payload
```

The previously discussed extensions (`objective_id::UInt64`, `bundle_role::Symbol`) were edited locally but **never committed** — the working tree is clean at `7969b4a`. The `_OBJECTIVE_COUNTER` and `fresh_objective_id()` are also absent.

This means:
- `_cast_math_votes` emits step votes and a final answer vote, but they have **no shared objective_id** — the AIML layer cannot tell they belong to the same computation
- `_cast_multipart_votes` splits on `&conj` boundaries but the resulting votes are **not grouped** — the AIML layer cannot distinguish a multipart bundle from independent singleton votes

---

## 5. Multipart Decoherence: Root Cause

The multipart decoherence you mentioned traces to several gaps in the current pipeline:

### 5.1 No Objective Grouping
Without `objective_id`/`bundle_role` on Vote, the AIML layer cannot:
- Know that votes from `_cast_multipart_votes` belong to the same compound question
- Distinguish a `:step_n` vote from a `:final` answer in a math chain
- Apply a coherent narrative arc across a vote bundle

### 5.2 No Input Decomposition
The current engine has no `InputDecomposer`. The only multipart handling is `_cast_multipart_votes` in engine.jl, which:
- Splits on `&conj` boundaries (SigilMediator detects `:multipart` routing kind)
- But the raw text input `"what is 2+2 and what is a cat"` doesn't contain `&conj` — the sigil mediator has to **inject** that boundary, which it currently doesn't do for raw text

### 5.3 Arithmetic Bleed
The test_log documents the fix (`scoped_mission`) but this doesn't exist in the engine. Without it, when a multipart vote bundle hits the COMMANDS handler, the arithmetic engine sees the entire compound input and may produce spurious bindings.

### 5.4 No Answer Mode Routing
The v3 specimen's `answer_mode_config` defines per-mode voice/action/frame/prompt tuples. The current engine's `generate_aiml_payload` uses a single code path with fixed band rendering — there's no mode-aware dispatch.

---

## 6. Summary of What's Missing (Priority Order for Multipart Fix)

1. **Vote objective_id + bundle_role** — without this, multipart votes are ungrouped
2. **InputDecomposer** — split compound inputs before they hit the sigil mediator
3. **scoped_mission** — per-group sub-subject text to prevent arithmetic bleed
4. **Answer mode dispatch** — route vote bundles through mode-specific renderers
5. **Automaton rules** — apply jitter_targets and escalation steps per-bundle
6. **Sigil class promotion** — allow :procedure and :relation to register (currently RESERVED, will throw)
7. **Node json_data extensions** — frame_hints, voice_register, noun_anchors for per-node rendering
8. **Save/load for 44 new config keys** — the v3 specimen loses all config on round-trip

---

## 7. Specimen Format Mismatch

The v3 specimen uses `sigil_table` (a list) as its sigil key; the engine save/load uses `sigils` (a dict via `SigilRegistry.serialize_global()`). On load, the engine looks for `haskey(specimen, "sigils")` — it will not find `sigil_table`, so **all 21 sigil entries are lost** on load even before the class rejection issue.
