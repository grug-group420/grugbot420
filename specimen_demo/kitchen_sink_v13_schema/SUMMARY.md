# Kitchen Sink v13 — Schema Utilization (v7.21c-1)

**Date:** 2025-05-26
**HEAD:** v7.21c-1 (Phase B + Phase C of `docs/node_schema_audit.md`)
**Seed:** `kitchen_sink.specimen.gz` — 42 nodes, 13 lobes, beefed schema
**Missions:** 89 (`missions_clean.txt`, identical to v11/v12 for fair comparison)
**Errors:** 0
**Test suite:** 32/32 testfiles green (added `test_v7_21c1.jl`: 6 testsets, 16 individual tests)

---

## Why this run exists

v12 (kitchen_sink_v12_coherence) shipped the v7.21b-3d coherence fix:
the AIML scaffold now used the seeded grug-voice prose body as `{CLAIM}`
and dispatched the skeleton on the judge's `frame_hint`. That fixed the
"parrot the trigger pattern" regression. Replies stopped reading like:

```
v11: [Grug greet warm] Hello — here is what matters: hello hi.
v12: [Grug greet warm] Let me think with you. Be polite, brief.
```

But v12's seed was thin. The schema audit (`docs/node_schema_audit.md`)
catalogued every dial the engine and scaffold offered and showed that
the v12 specimen utilized only a small fraction of them:

| Schema field | v12 nodes using | Total nodes |
|---|---|---|
| `frame_hints` | 33 | 42 |
| `relational_patterns` (auto-extracted) | 1 | 42 |
| `required_relations` | 0 | 42 |
| `drop_table` (non-empty) | 8 | 42 |
| Per-action inline negatives | 3 | 42 |
| `wants_context` | 0 | 42 |

The user's reframing nailed it:

> "no i mean the way you configured the save file is the issue lol.
>  think about it. votes can do way more than what youre using them
>  for. and you need to configure aiml to have matching knobs.
>  think language coherence"

So v7.21c-1 is **not** a new system. It is **schema co-design**: beef
the seed config so the engine actually has signal to work with, AND
extend the scaffold so it consumes new dials the seed can now turn.

---

## What v7.21c-1 ships

### A. Engine extension (`src/engine.jl`)

`create_node` now also absorbs an optional `aux_triples` field from
`json_data`. When the pattern is too short for `extract_relational_triples`
to auto-detect (1–2 tokens, e.g. `"danger"`, `"i feel"`), the seed author
can hand-write the canonical triples and they will be merged into
`relational_patterns` at grow time:

```json
"aux_triples": [
  ["danger", "causes", "harm"],
  ["predator", "threatens", "tribe"]
]
```

### B. Scaffold extension (`src/Main.jl :: generate_aiml_payload`)

Three new `json_data` keys are now read at synthesis time and modulate
the spoken reply:

| Key | Type | Effect |
|---|---|---|
| `voice_register` | `"warm"`/`"terse"`/`"casual"`/`"plain"`/`"formal"` | Modulates skeleton TEXTURE. `terse` strips `{SUPPORT}`. `formal` converts ` — ` to `: `. |
| `noun_anchors` | `[String]` | Fallback `{CLAIM}` source — `"the {anchor[1]}"` — when pattern is bare AND `system_prompt` body is empty. Prevents single-word patterns from producing bare claims like `"hammer."`. |
| `companion_node_pref` | `[node_id]` | Overrides the legacy "first tied alternative" heuristic. When the winning node declares a preferred companion, that companion's body is what fills the support clause. |

CLAIM priority ladder (Fix A from v7.21b-3d, extended in c-1):

1. `system_prompt` body sentences (the seeded grug-voice prose)
2. `node.pattern` if it has 2+ words
3. `"the " * noun_anchors[1]` ← **NEW in c-1**, single-word-pattern repair
4. `node.pattern` (single word)
5. quoted-mission fallback

### C. Seed beef-up (`specimen_seed.txt`)

Schema utilization in v13 vs v12:

| Schema field | v12 | v13 |
|---|---|---|
| `frame_hints` | 33/42 | **42/42** |
| Multi-sentence `system_prompt` | partial | **42/42** |
| `drop_table` (non-empty) | 8/42 | **42/42** |
| `voice_register` | 0/42 | **42/42** |
| `noun_anchors` | 0/42 | **42/42** |
| `companion_node_pref` | 0/42 | 14/42 |
| `aux_triples` | 0/42 | 7/42 |
| Per-action inline negatives | 3/42 | 9/42 |
| `wants_context` | 0/42 | 14/42 |

A small, surgical revert mid-tuning: `required_relations` was tried on
6 emotion/survival nodes but produced a fire-rate regression (89 → 55
firings, ~10pp drop) because mission inputs like `"i feel sad today"`
don't carry an explicit "X feels Y" triple — the gate dropped them.
Removed for v13 final; `relation_weights` (a soft bias) remains.

---

## Results

### Headline numbers

| Cut | Missions | Replies fired | Fire rate | Errors | Notes |
|---|---|---|---|---|---|
| v11 (kitchen_sink_v11_comprehensive) | 89 | 64 | 71.9% | 0 | pre-coherence-fix; replies parroted patterns |
| v12 (kitchen_sink_v12_coherence) | 89 | 64 | 71.9% | 0 | coherence fix; bodies spoken |
| **v13 (kitchen_sink_v13_schema)** | **89** | **64** | **71.9%** | **0** | **+ register/anchors/pref/aux_triples** |

Fire rate held flat. Quality of fired replies up materially (see below).

### Sample replies — v11 → v12 → v13

Same mission column, three runs side by side:

```
mission : 'good morning'
v11     : [Grug acknowledge time of day with warmth] Hello — here is what matters: good morning.
v12     : [Grug acknowledge time of day with warmth] good morning.
v13     : [Grug acknowledge time of day with warmth] good morning. A companion frame: Sun is up, tribe gather.
```

```
mission : 'i feel sad today'
v11     : [Grug listen to feeling] To acknowledge what matters here: i feel.
v12     : [Grug listen to feeling] I hear that. Validate, do not fix.
v13     : [Grug listen to feeling] Let me think with you. Check, do not patch. Sit close in the dark with tribemate. The link is clear: tribemate feels feeling.
```

```
mission : 'run from the wolf now'
v11     : [Grug urge escape from harm] A concern worth raising: run.
v12     : [Grug urge escape from harm] run.
v13     : [Grug urge escape from harm] Feet shift now, questions later.
```

```
mission : 'how does a hammer work'
v11     : [Grug talk about hitting-rock-with-handle] Here is the picture: how does.
v12     : [Grug talk about hitting-rock-with-handle] Here is the picture: hammer.
v13     : [Grug talk about hitting-rock-with-handle] Here is the picture: Heavy head, mighty handle, true swing.
```

```
mission : 'perhaps the river bends near the old tree'
v11     : [Grug know water move ...] (silent — pattern miss)
v12     : [Grug know water move ...] Let me think with you. Where river bend, fish gather.
v13     : [Grug know water move and life depend on it] Let me think with you. Where river bend, fish gather. A companion frame: Tree older than grandfather.
```

What changed from v12 → v13 in qualitative terms:

1. **voice_body fully populated** on every node. Replies that v12 left
   bare (`"good morning."`, `"hammer."`, `"run."`) now carry seeded prose.
2. **Companion clauses landing**. The v13 scaffold's
   `companion_node_pref` lets a primary node nominate a specific peer
   for the support clause. v12 took the first tied alt regardless of
   semantic fit; v13 the seed author has a say.
3. **Relational triples surfacing in support**. `aux_triples` on emotion
   nodes (`tribemate feels feeling`) now appear as `"The link is clear: ..."`
   support clauses — previously this slot was empty for short-pattern nodes.
4. **Register modulation working**. Survival-lobe terse register
   (`"Feet shift now, questions later."`) reads materially tighter than
   the v12 generic warm/exploratory wrapper.

### Test suite

```
GrugBot420 Tests |   32     32  3m53.3s
```

All 32 testfiles green. New `test_v7_21c1.jl` adds 6 testsets / 16
individual tests covering:

- `[1]` voice_register=terse strips SUPPORT (3 assertions)
- `[2]` voice_register=formal converts em-dash to colon (2)
- `[3]` noun_anchors fallback wraps a noun when pattern is bare (2)
- `[4]` companion_node_pref selects the preferred companion (2)
- `[5]` aux_triples are absorbed into relational_patterns at create (3)
- `[6]` smoke — full schema node produces coherent reply (4)

---

## Files in this directory

| File | What |
|---|---|
| `specimen_seed.txt` | Beefed v13 seed (42 nodes, 13 lobes, full schema utilization) |
| `seed_build.log` | CLI transcript of `/grow` replay that built the specimen |
| `kitchen_sink.specimen.gz` | Specimen at end of build (pre-mission run) |
| `kitchen_sink_post_run.specimen.gz` | Specimen after all 89 missions |
| `missions_clean.txt` | 146 lines (89 `/mission`, plus `/right`, `/wrong`, `/nodeAttach`, etc.) |
| `run.log` | Full CLI transcript of the v13 run |
| `spoken_v11.txt` | Just the spoken replies, v11 baseline (64) |
| `spoken_v12.txt` | Just the spoken replies, v12 baseline (64) |
| `spoken_v13.txt` | Just the spoken replies, v13 final (64) |
| `extract_spoken.py` | Helper that pulls scaffold-output blocks from a run.log |

---

## Followups (not blocking c-1)

1. Synonym swap is a little aggressive — `"clear"` → `"delete"` in the
   danger reply is a noticeable miss. Worth a `_swap_words_in` audit
   that excludes verbs already present in `node.action_packet`.
2. `voice_register=warm/casual/plain` are currently no-ops on the
   skeleton. They should affect downstream synonym swap weighting
   (warm prefers softer forms, plain prefers shorter ones). Future work.
3. Pattern duplication in `good morning` reply — the body is showing
   in the companion clause but not the primary CLAIM because pattern
   is short. The CLAIM ladder picks `node.pattern` over body when
   `length(split(pattern)) >= 2`. Consider promoting body above pattern
   even for 2-word patterns. Future work.

---

## Ship list

- [x] `src/engine.jl` — `create_node` reads `aux_triples` from json_data
- [x] `src/Main.jl` — `generate_aiml_payload` reads voice_register / noun_anchors / companion_node_pref
- [x] `src/Main.jl` — chatter_groups / chatter_cooldowns added to specimen validator allowed_keys (latent bug)
- [x] `docs/node_schema_audit.md` — schema field census + Phase B/C plan
- [x] `test/test_v7_21c1.jl` — 6 testsets, 16 individual tests, all green
- [x] `test/runtests.jl` — registered new test file
- [x] `specimen_demo/kitchen_sink_v13_schema/` — full artifact bundle
- [x] Kitchen-sink v13 run completed, 0 errors, 64/89 fire rate
- [x] 32/32 testfiles green in full suite
