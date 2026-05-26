# Node Schema Audit — v7.21c-1

**Status as of HEAD `5fce1c1` (v7.21b-3d).** What every Node field can carry,
what the kitchen-sink v12 seed actually puts there, and what the AIML scaffold
(`generate_aiml_payload`) actually reads from it.

The motivating insight: the save-file schema is much richer than the seed
configurations have been using. Several knobs the scaffold *already reads* are
empty on most nodes, so the scaffold falls back to the trigger pattern instead
of the data the field would have carried. The fix is **schema + scaffold
co-design**: beef up what the seed populates AND extend the scaffold to read
fields that aren't being read yet.

---

## A. Top-level Node fields (struct, `src/engine.jl:449`)

| Field                       | Type                    | Purpose                                                           | v12 seed usage          | Scaffold reads?                            |
|-----------------------------|-------------------------|-------------------------------------------------------------------|--------------------------|---------------------------------------------|
| `id`                         | `String`                | Unique node id                                                    | 42/42                    | Yes (lookup, telemetry)                     |
| `pattern`                    | `String`                | Trigger pattern (the literal string the input must hit)           | 42/42                    | Yes — fallback CLAIM when body is empty     |
| `signal`                     | `Vector{Float64}`       | Pattern Scanner numeric vector                                    | 42/42 (auto)             | No                                          |
| `action_packet`              | `String`                | Pipe-separated `action[neg]^weight` entries                       | 42/42                    | Indirectly (vote outcome flows in)          |
| `json_data`                  | `Dict{String,Any}`      | Free-form metadata (see Section B)                                | varies — see Section B   | Reads `system_prompt`, `frame_hints`, etc.  |
| `drop_table`                 | `Vector{String}`        | Per-node stochastic synonym/inhibition rules                      | 8/42                     | Yes (`_swap_words_in` / `_pick_synonym`)    |
| `throttle`                   | `Float64`               | Per-node firing throttle                                          | 42/42 (default 0.5)      | No                                          |
| `relational_patterns`        | `Vector{RelationalTriple}` | Subject-relation-object triples this node knows about           | **1/42** ❌              | **Yes** — drives SUPPORT clause (a)         |
| `required_relations`         | `Vector{String}`        | Relations that MUST fire for this node to vote                    | **1/42** ❌              | Yes — biases triple selection in SUPPORT    |
| `relation_weights`           | `Dict{String,Float64}`  | Per-relation confidence multipliers                               | **1/42** ❌              | Yes (orchestrator) / No (scaffold)          |
| `strength`                   | `Float64`               | Apoptosis/stratification system                                   | 42/42 (default 1.0)      | No                                          |
| `is_image_node`              | `Bool`                  | SDF binary vs text                                                | 42/42 (false)            | No                                          |
| `neighbor_ids` / `is_unlinkable` / `max_neighbors` | various | Neighbor-link cap                                       | 42/42                    | No                                          |
| `is_grave` / `grave_reason`  | `Bool` / `String`       | Apoptosis flags                                                   | 42/42 (false / "")       | No (engine uses)                             |
| `response_times` / `ledger_last_cleared` | various      | Big-O response ledger                                              | 42/42                    | No                                          |
| `hopfield_key`               | `UInt64`                | Familiar-input cache key                                          | 42/42 (auto)             | No                                          |
| `fired_this_cycle` / `voted_this_cycle` / `gained_this_cycle` / `strength_delta_this_cycle` | various | Cycle bookkeeping for /right /wrong feedback | runtime | No |

**Top-level gaps:**
- `relational_patterns` populated on 1/42 nodes (2.4%). This is the single
  biggest under-populated knob — the scaffold's SUPPORT clause `(a)` is
  programmed to pull `"The link is clear: <subject> <relation> <object>."`
  from these triples, but with 1/42 coverage almost no replies get a
  relational sub-clause.
- `required_relations` and `relation_weights` similarly empty.
- `drop_table` populated on 8/42 (19%). Where present it routes synonym
  substitutions correctly, but most nodes can't take advantage.

---

## B. `json_data` keys

Currently-known consumed keys (from grep across `src/`):

| Key                          | Type                | Read by                              | v12 seed usage   | Purpose                                                                     |
|------------------------------|---------------------|--------------------------------------|------------------|-----------------------------------------------------------------------------|
| `system_prompt`              | `String`            | `generate_aiml_payload` (Main.jl)    | 42/42 ✅         | Voice prefix (first sentence) + CLAIM body (rest, since v7.21b-3d)          |
| `frame_hints`                | `Vector{String}`    | TonalJudge / orchestrator            | 33/42 (78%)      | Frame hint that `compute_frame_match_multiplier` lifts/inhibits votes for   |
| `wants_context`              | `Bool`              | `pull_fresh_memory` gate (Main.jl)   | **0/42** ❌      | Opt-in to fresh memory pull when this node is a winning voter              |
| `nonjitter`                  | `Bool`              | ChatterMode opt-out                  | **0/42** ❌      | Excludes node from chatter jitter rolls                                     |
| `last_reason`                | `String`            | Written at runtime (not seeded)      | runtime          | Diagnostic — last mission this node fired on                                |
| `_long_pattern_warn_emitted` | `Bool`              | Engine warning gate                  | runtime          | Internal flag to suppress repeated long-pattern warnings                    |

**`json_data` gaps:**
- `wants_context` — never seeded. Means the fresh-memory pull gate is purely
  driven by the trust floor (confidence < threshold), not by nodes opting in.
  Some nodes (e.g., `i feel`, `remember when`, `last time`) clearly *should*
  opt in because their replies need recent conversation history to be coherent.
- `nonjitter` — never seeded. ChatterMode picks any node as a jitter source,
  including nodes whose voice would clash (e.g., picking `danger` as a jitter
  source when the conversation is tonally warm).

---

## C. `action_packet` syntax (per `parse_action_packet`, `src/engine.jl:2196`)

The format is **richer than most seeds use**:

```
action[neg1, neg2, ...]^weight | action2[neg3]^weight | ...
```

- Pipe-delimited actions (so action names can contain commas)
- **Per-action inline negatives** in `[ ]` — these become the `negatives`
  field of the resulting Vote, which the scaffold routes through synonym swap
- Optional `^weight` (defaults to 1.0)

| Feature                     | v12 seed usage | Scaffold reads?                                  |
|-----------------------------|-----------------|---------------------------------------------------|
| Multiple weighted actions   | 42/42 ✅        | Yes (orchestrator + selector)                     |
| Per-action inline negatives | **3/42** ❌     | Yes (Vote.negatives → synonym substitution)       |

**`action_packet` gaps:**
- Inline negatives almost never used. A node like `"i feel"` whose action is
  `comfort` should declare `comfort[dont fix, dont solve, dont minimize]^3` so
  the scaffold blocks those words from substituting into the reply. Today the
  scaffold could enforce that constraint but the data doesn't carry it.

---

## D. What the scaffold reads but the seed doesn't supply

Cross-referencing Sections A–C, the **highest-leverage gaps** (scaffold
already reads, seed is empty):

1. **`relational_patterns`** — 1/42 nodes. Scaffold has working code for the
   `"The link is clear: <s> <r> <o>."` SUPPORT sub-clause but can't fire it
   because the triples aren't there.
2. **`required_relations`** — 1/42 nodes. Same issue.
3. **`drop_table`** — 8/42 nodes. Per-node synonym substitution rules; scaffold
   reads them through `_swap_words_in` and `_pick_synonym` but only fires for
   the 8 nodes that have entries.
4. **Per-action negatives in `action_packet`** — 3/42 nodes. Vote.negatives
   gets propagated into `_swap_words_in` but is empty for ~93% of votes.
5. **`wants_context: true`** — 0/42 nodes. The fresh-memory pull gate sits
   idle for nodes that would benefit from it.

---

## E. What the seed could supply but the scaffold doesn't yet read

These are **fields the scaffold should be extended to consume** in v7.21c-1.
None of them require schema changes — they fit inside `json_data`:

| New `json_data` key       | Type                | Purpose                                                                                                   | Scaffold action                                                              |
|----------------------------|---------------------|-----------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------|
| `noun_anchors`             | `Vector{String}`    | The nouns this node's prose is "about" (e.g., `["fire", "heat", "burn"]` for `fire burns`)                | When CLAIM is bare-noun-y, pull the highest-priority anchor as a substitute  |
| `voice_register`           | `String`            | `"formal"`, `"casual"`, `"terse"`, `"warm"` — modulates skeleton choice independent of frame              | Apply as a tilt on top of the frame skeleton (`terse` register strips fillers) |
| `companion_node_pref`      | `Vector{String}`    | Preferred companion-frame node IDs (overrides "first tied alternative" heuristic)                          | Use this list before falling back to `tied_alternatives[1]`                  |
| `claim_template`           | `String`            | Optional jinja-style `"I hear that {feeling}."` override for very high-stakes nodes                        | If present, use as the CLAIM directly; substitute `{...}` from input tokens  |
| `frame_hints` (existing)   | `Vector{String}`    | Already present, but only 33/42 nodes use it                                                              | (already wired in v7.21b-3b)                                                 |

---

## F. Plan for v7.21c-1

**Phase B — Beef up the kitchen-sink seed (config only, no code).**
Rewrite the seed to populate:
- `frame_hints` on **42/42** nodes (currently 33/42)
- `relational_patterns` on every node where it makes sense (target: ≥30/42)
- `required_relations` + `relation_weights` aligned with above
- Per-action inline negatives on emotionally loaded actions (`comfort`,
  `validate`, `acknowledge`) — block "fix" / "solve" / "minimize" tokens
- `wants_context: true` on memory/feeling/planning nodes
- `drop_table` on every node (target: 42/42, ≥3 entries each)
- New: `noun_anchors`, `voice_register`, `companion_node_pref` populated where useful

**Phase C — Extend the scaffold to consume the new fields.**
- `noun_anchors`: when CLAIM body is empty/bare, substitute the top anchor
- `voice_register`: post-process skeleton (terse=strip fillers, formal=expand contractions, etc.)
- `companion_node_pref`: override companion selection

**Phase D — Verify with kitchen sink v13a (config-only) and v13b (config + scaffold).**
- v13a measures pure config delta — same scaffold, richer data
- v13b measures config + scaffold delta — full v7.21c-1
- Compare both against v12 baseline

Expected outcome: SUPPORT clauses now fire (v12 had almost none because triples
were empty), CLAIM body is consistently non-empty (multi-sentence prompts),
companion-frame echoes are tasteful (using `companion_node_pref` instead of
random tied alternative), and emotional replies don't slip into "fix it"
language (per-action negatives now active).
