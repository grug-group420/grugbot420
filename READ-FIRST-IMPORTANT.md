# READ-FIRST-IMPORTANT.md

> **Branch this lives on: `v7.15-updates`** — this is the active development branch.
> The `feat/v7.22-lobe-dynamics-followups` branch was an agent-created fork (mistake)
> and has been left alone, NOT merged. See `AGENT_RULES.md` for why.
> See also: `feat/comprehensive-save-and-chat-proof` was deleted from origin (orphan).

---

## TL;DR

`v7.15-updates` is the **canonical branch**. It carries:

| Feature | Module(s) | Status |
|---|---|---|
| Sequential lobe orchestration with curved floor + multi-lobe gate | `LobeOrchestrator.jl` | ✅ |
| 8–16 random-partner cap, group-id FIFO chatter, gzipped persistence | `GroupRegistry.jl` | ✅ |
| User + auto-promoted CRYSTALIZE always-fire bypass with hysteresis | `CrystalizeTag.jl` | ✅ |
| Vote-copy chatter (not pattern-copy) with cooldown + intensity gate | `ChatterVoteSwap.jl` | ✅ |
| Complexity-gated dynamic re-weighting wrapper | `DynamicActionTonePredictor.jl` | ✅ |
| Phagy 7th automaton — stale-unlinkable / empty-group cleanup | `PhagyGroupOrganizer.jl` | ✅ |
| Strong-low-conf NONJITTER override | `RelationalJitter.jl` | ✅ |
| Two-tier AIML threshold + concept-class thesaurus | `Thesaurus.jl` | ✅ (v7.16.0) |
| Relation-gated support band | `Main.jl` orchestration | ✅ (v7.16.1) |
| Composition-roll for confirmed-support claims | `Main.jl` AIML | ✅ (v7.16.2) |
| Absolute lock-in floor with semantic weighting | vote pipeline | ✅ (v7.16.3) |
| **Subconscious microlog (fuzzy time-cues, throttled)** | `SelfObserver.jl` | ✅ (ported from main) |
| **Sigil registry kernel (`&n`, `&op`, `&noun`, `&word`, `&rest`)** | `SigilRegistry.jl` | ✅ (ported from main) |
| **Front-door input promoter (variants → canonical)** | `SigilPromoter.jl` | ✅ (ported from main) |
| **Sigil-bound arithmetic ("two plus two" → 4)** | `ArithmeticEngine.jl` | ✅ (ported from main) |
| **Tonal build-up over consecutive same-tone predictions** | `ActionTonePredictor.jl` | ✅ (NEW v7.16+) |
| **Per-prediction Lorenz snap-back (jitter + entropy tug)** | `ActionTonePredictor.jl` | ✅ (NEW v7.16+) |
| **Sparse-active fire gate at the engine fire site** | `VoteOrchestrator.jl` + `engine.jl` | ✅ (NEW v7.16+) |
| **Sigil routing rail (multi-step + multi-clause linguistic reasoning)** | `SigilMediator.jl` + `engine.jl` + `Main.jl` | ✅ (NEW v2.6) |
| **Engine-default sigil-tagged seed nodes (fresh cave answers `2+2`)** | `Main.jl` boot seeds | ✅ (NEW v2.6) |
| **Save format v2.6 (sigil registry persists across save/load)** | `SigilRegistry.jl` + `Main.jl` | ✅ (NEW v2.6) |

**Hopfield networks were commented out long ago.** The ghost references in
`PhagyMode.jl` (`CACHE_VALIDATOR` etc.) are stubbed; nothing in the live
runtime calls a Hopfield path. Do not re-enable without explicit user OK.

---

## What was ported in this round (May 2026)

The following work was already on `origin/main` but not yet on
`v7.15-updates`. It has been **added** to this branch without disturbing the
v7.15/v7.16 features above.

### 1. `SelfObserver.jl` — subconscious microlog
- Fuzzy, throttled, observation-only memory store.
- Stochastic write, globally serialized read with token-bucket throttle and
  hard timeout.
- Returns fuzzy time-bucket symbols (`:just_now`, `:earlier_today`,
  `:yesterday_ish`, `:long_ago`, …) — never raw timestamps, never confidence
  scalars.
- **Structural guarantee**: nothing in this module returns `Float64` from
  public API. `test_self_observer.jl` enforces it.
- Test: `test/test_self_observer.jl` — 129 assertions, all pass.

### 2. `SigilRegistry.jl` — sigil kernel (Stage 1)
- Single source of truth for typed symbolic handles (`&n`, `&op`, `&word`,
  `&noun`, `&rest`).
- Token-sigil classes: `:lambda`, `:macro`, `:tag` activated. `:glue`,
  `:functor`, `:procedure` reserved.
- Pattern parsing extracts `&name` tokens, resolves against registry, fails
  loud on unknown sigil.
- Zero runtime cost when no sigils used.
- Test: `test/test_sigil_registry.jl` — 177 assertions, all pass.

### 3. `SigilPromoter.jl` — front-door input promoter (Stage 1.5a/c)
- Layer 1 (language): `"two"` → `"2"`, `"plus"` → `"+"`. Closed lookup table.
- Layer 2 (shape): `"2"` → `&n=2`, `"+"` → `&op=plus`. Driven by registry's
  `promote_at_tokenize` flag.
- Idempotent: `promote(promote(x)) == promote(x)`.
- Empty-bindings fast path for pure-text inputs (zero allocation, bit-identical
  to old behavior).
- Test: `test/test_sigil_promoter.jl` — 284 assertions, all pass.

### 4. `ArithmeticEngine.jl` — sigil-bound math (Stage 2)
- Reads `current_promotion_bindings()` set by `SigilPromoter`.
- Multi-step evaluation: `"3 + 5 * 2"` → step 1: `5*2=10`, step 2: `3+10=13`.
- Operators: `+ - * / = < > % ^`.
- Division by zero returns an error string, not a crash.
- Returns structured `ArithmeticResult` with `ComputationStep` list — caller
  decides format.
- Test: `test/test_arithmetic_engine.jl` — 111 assertions, all pass.
- End-to-end verified: `"what is 2+2"` → `"2 plus 2 equals 4"`.

---

## NEW in this round — tonal build-up + per-prediction Lorenz snap-back

Two **independent** dynamics added to `ActionTonePredictor.jl`. Both run on
every call, both are bounded, both maintain all existing invariants
(distributions sum to 1.0, every value in `[0,1]`, no NaN/Inf).

### A. Tonal build-up over time
| Constant | Default | Meaning |
|---|---|---|
| `TONAL_BUILDUP_INCREMENT` | `0.20` | Each consecutive same-tone hit adds `0.20 × (1 - current_buildup)` |
| `TONAL_BUILDUP_HALFLIFE_S` | `30.0` | Cool-down halflife when same tone is not refreshed |
| `TONAL_BUILDUP_AROUSAL_GAIN` | `0.6` | Multiplies `arousal_nudge` by `(1 + GAIN × buildup)` |

- **State**: a single-slot `(tone, buildup, ts)` accumulator with a `ReentrantLock`.
  This is NOT the trajectory ring buffer — those are separate concerns.
- **Same tone twice** → mood stacks: someone making consecutive hostile
  remarks gets a stronger arousal push than a one-off insult.
- **Tone change** → mood snaps back: build-up of the *old* tone is dropped,
  the new tone seeds at `0.05`. Mood doesn't transfer across emotional shifts.
- **Long quiet** → exponential cool-down: a fresh conversation effectively
  starts cold (after ≈30s of no matching tone, build-up halves; after a few
  half-lives it's a rounding error).
- **Sign preserved**: gain multiplier never flips the sign of the cold nudge.
  HOSTILE/URGENT (positive nudge) gets pushed more positive; REFLECTIVE
  (negative nudge) gets pushed more negative.

### B. Per-prediction Lorenz snap-back
| Constant | Default | Meaning |
|---|---|---|
| `LORENZ_SNAPBACK_JITTER` | `0.025` | ±2.5% multiplicative noise per family before snap |
| `LORENZ_SNAPBACK_PULL`   | `0.05`  | Pull each family 5% of the way toward `1/N` |

- Always-on, runs after the existing trajectory-buffer Lorenz damper (Step 4)
  and before winner pick (Step 5).
- **Step 1**: per-family multiplicative jitter — identical inputs no longer
  produce bit-identical curves.
- **Step 2**: pull each family toward the uniform `1/N` baseline.
- **Step 3**: renormalize so values sum to 1.0.
- This is the **per-prediction** analog of the long-horizon Lorenz damper.
  It runs whether or not the trajectory damper fired. Bounded, fast,
  unconditional.

### Public API surface added
- `reset_tonal_buildup!()` — wipe the accumulator. Called automatically by
  `reset_trajectory!`.
- `get_tonal_buildup() -> NamedTuple{(:tone, :buildup, :ts), …}` — read-only
  snapshot for diagnostics and tests.
- All five new constants are exported.

### Tests
`test/test_tonal_buildup_and_snapback.jl` — **9 testsets, 268 assertions**
covering:
1. Constants are in legal ranges (sanity guard).
2. `reset_tonal_buildup!` produces clean slate.
3. Same-tone calls grow buildup; tone change resets it.
4. Repeated same-tone calls amplify arousal magnitude.
5. Tone shift snaps mood back to cold.
6. Snap-back jitter: identical input produces non-identical curves.
7. Snap-back preserves sum-to-1 invariant.
8. Snap-back keeps every family in `[0, 1]` (240 assertions over a stress run).
9. `reset_tonal_buildup!` between calls eliminates build-up effect (cool-down structural check).

### Tests that needed updates
`test/test_dynamic_action_tone.jl`: the simple-input passthrough test asserted
**bit-exact equality** between two consecutive `predict_action_tone` calls.
That assumption is gone by design (jitter + build-up). The test now resets
build-up between calls and uses bounded tolerances. Family decisions are still
asserted exactly. **No other test in the suite needed changes.**

---

## NEW in this round — sparse-active fire gate

> **User directive (verbatim):** *"a pattern bind below a high threshold
> shouldn't even fire really. its sparse active. shouldn't handle that from
> the aiml layer."*

The fix lives at the **engine fire site**, not in the AIML layer.

### What changed
| Constant | Default | Meaning |
|---|---|---|
| `SPARSE_ACTIVE_FIRE_FLOOR` | `0.20` | Post-action-tone-weighted confidence below this is culled BEFORE claiming a fire slot |

- Above the relay hard floor (`0.10` — "always have SOME voice")
- Below the AIML lock-in floor (`0.50`) so the lock-in machinery is untouched
- Below `AIML_CONFIDENCE_THRESHOLD` so the two-tier band logic is untouched

### Where it fires
1. **`scan_specimens` → `fire_one` closure** (`engine.jl` ~line 2682). The
   gate runs **after** action-tone weighting, so the value the gate sees is
   the same value the vote pool would have seen. On cull: tally a skip,
   return `nothing`, do **not** claim from `FireCounter`. Saves attention
   budget for genuinely confident specimens.
2. **`fire_attachments!`** (`engine.jl` ~line 1624). The relay's own hard
   floor of `0.1` still applies first, but a `max(0.1, ...)` clamp on a
   genuinely weak base is just noise riding the connector — culled.

### Public API
- `SPARSE_ACTIVE_FIRE_FLOOR` (const)
- `should_fire_sparse_active(confidence::Real)::Bool` — `false` for NaN/Inf, `true` iff `confidence ≥ FLOOR`
- `tally_sparse_active_skip!()` — atomic increment of a thread-safe counter
- `get_sparse_active_skip_count()::Int` — read counter
- `reset_sparse_active_skip_count!()` — reset for new cycle / test isolation

### Tests
`test/test_sparse_active_fire.jl` — 24 assertions covering threshold
behavior, NaN/Inf rejection, integer confidences, thread-safe counter
increment under `Threads.@threads`, and the relay-floor interaction.

### Why this is the right layer
The AIML layer's job is to pick winners from a pool of fired specimens. If
sub-threshold noise is in the pool, the AIML layer can suppress it but the
fire slot has already been spent — `ACTIVE_FIRE_CAP` (1000) is a finite
budget. Culling at the fire site keeps the budget for signals that actually
crossed sparse-active threshold.

---

## NEW in this round — save format v2.5 (specimen save coverage holes plugged)

> **User directive (verbatim):** *"i think there are quite a few features that
> save to disc rn that arent part of the save file system. so yea check that
> ... sub conscious writing isn't in the file either. lets get it all wired up"*

The audit found seven categories of live runtime state that the canonical
`/saveSpecimen` was silently dropping. All seven are now folded into the
unified specimen file. Format version: `2.4 → 2.5`. Backward-compatible:
loading a v2.4 specimen leaves the new categories at clean defaults (with
concept-class seeds rebuilt automatically).

### What was missing before v2.5
| Specimen key | State holder | Why it matters |
|---|---|---|
| `tonal_buildup` | `ActionTonePredictor._TONAL_BUILDUP` | Single-slot tonal arousal accumulator — added earlier this round. Reload zeroed it → cold-start every save. |
| `concept_classes` | `Thesaurus.CONCEPT_CLASS_MEMBERS` | v7.16 concept classes. User-managed via `/conceptClass add/remove`. Reload lost runtime additions. |
| `concept_inhibitions` | `InputQueue._NEG_CONCEPT_BANS` | Sibling of `inhibitions`. User-managed. Reload silently lost all bans. |
| `groups` | `GroupRegistry._REGISTRY` | v7.15 group registry. Was previously persisted via its OWN external file (`group_registry.json.gz`) — splitting state across two files. Now folded into the unified specimen. |
| `crystalize` | `CrystalizeTag` (two sets) | v7.15 crystallization tags (user-issued + auto-promoted). Reload lost every "lock me forever" decision. |
| `chatter_swap_cooldowns` | `ChatterVoteSwap._COOLDOWN_MAP` | 1-hour cooldown timestamps for chatter swaps. Reload let all swaps fire again immediately (parity with `morph_cooldowns` which WAS saved). |
| `subconscious` | `SelfObserver._GLOBAL_STORE` | NEW process-wide singleton wired this round. Without it, the subconscious microlog table was wiped on every reload. |

### Disk-write fragmentation: fixed
`GroupRegistry.save_registry_compressed` / `load_registry_compressed` are
preserved (still callable for ops use) but are no longer the primary
persistence path for groups. Everything goes through the unified specimen.

### Per-module API surface added
Each affected module now has matched `serialize_*` / `restore_*` helpers so
the persistence concern lives near the type:

- `ActionTonePredictor.serialize_tonal_buildup() / restore_tonal_buildup!`
- `Thesaurus.serialize_concept_classes() / restore_concept_classes!`
- `InputQueue.serialize_concept_inhibitions() / restore_concept_inhibitions!`
- `GroupRegistry.serialize_state() / restore_state!`
- `CrystalizeTag.serialize_state() / restore_state!`
- `ChatterVoteSwap.serialize_cooldowns() / restore_cooldowns!`
- `SelfObserver.default_store() / serialize_store / restore_store! / restore_global_store!`

The wipe phase of `/loadSpecimen` resets each holder to clean state before
the restore step, so loading an older v2.4 specimen leaves the new
categories empty rather than carrying forward stale runtime state. Concept
classes are re-seeded after wipe (they have hardcoded baseline seeds).

### Validation allowlist
`load_specimen_from_file!`'s `allowed_keys` set was extended to accept the
seven new top-level keys. Unknown keys still produce a hard validation
failure — no silent acceptance.

### Tests
`test/test_save_coverage_v25.jl` — **87 assertions across 9 testsets**:
- 7 per-module round-trip testsets (one per new save category)
- 1 testset for tone-string corruption tolerance (unknown tone → nothing,
  missing keys → defaults)
- 1 integration testset that drives the full `save_specimen_to_file!` →
  decompress JSON → assert seven new keys present → wipe live state →
  `load_specimen_from_file!` → assert live state restored

Full suite: 47 / 47 testfiles pass, ~4m20s. Zero regressions.

### Specimen ops scroll
The save scroll now reports counts for every new category alongside the
existing ones (tone build-up snapshot, concept classes, concept bans,
groups, crystalize sets, swap cooldowns, subconscious keys).

---

## NEW in this round — v2.6 sigil routing rail (multi-step linguistic reasoning)

> **User directive (verbatim):** *"nodes now do pattern reaction which suffices
> for most tasks. but lets say a user asks something more intermediate
> linguistically not even just math. like a multi part question or
> instruction"*
>
> *"when user input is sent and is detected to have math syntax or certain
> linguistics that require sigils. like lets say 2+2 is in the input. it is
> replaced with sigil notation this way the pattern bind phase need not
> change. now for nodes that have things like this... the node can fire
> more than one vote. all votes inherit the same confidence from pattern
> bind phase... user input that is like this should be routed directly to
> node types like this in fact those node types have a special tag so its
> simple to figure out."*

The Sigil/Promoter/Arithmetic kernel ported earlier was **dormant
infrastructure** — the modules existed but were never wired into the engine
fire path. This round wires the entire rail end-to-end. Math is the
cleanest first instance; the same machinery handles any input that needs
linguistic-structure parsing before answering (multi-part questions /
instructions).

### What changed at a glance

| Layer | Before v2.6 | After v2.6 |
|---|---|---|
| Front-door | SigilPromoter rewrites tokens, but bindings died at the boundary | `SigilMediator.mediate(raw)` produces structured `(original, rewritten, bindings, kinds)` consumed by Main.jl |
| Pattern-bind | Pattern-reactive only — no way to mark "answer with structure" | Nodes can carry `@sigil:<kind>` tags on `drop_table`. Fully back-compat: untagged nodes behave identically |
| Vote casting | One vote per fire | `cast_sigil_votes` lets tagged nodes emit **N votes per fire**, one per reasoning step (math) or per clause (multipart). All votes inherit the pattern-bind confidence — voting is per-step, the confidence math is unchanged |
| Vote payload | `Vote.action` = command-name only | New `Vote.payload::String` carries structured content (e.g. the computed answer `4`). Orchestrator concatenates it after `COMMANDS[action]` renders. **8-arg constructor; backward-compat 7-arg constructor defaults payload to `""` so all existing call sites compile unchanged** |
| Routing | Tagged nodes had to win pattern-bind to fire | `list_sigil_node_ids(kind)` walked at scan time — when SigilMediator detects `:math` / `:multipart` in the input, matching tagged nodes are **directly injected** into the candidate pool with `inject_conf = max(0.4, max_primary_conf × 0.5)` |
| Persistence | Sigil registry rebuilt from defaults every boot | Save format **v2.5 → v2.6**: full registry serialized as a `"sigils"` block. Engine-default sigils with lambda predicates re-attach via `merge_registry!(:keep)` so v2.5 specimens load cleanly |
| Boot seeds | Three pattern-reactive seeds (greet / reason / relational) | Three pattern-reactive seeds **plus three sigil-tagged seeds**: `&n &op &n` and `&n &op &n &op &n` (math), `&conj` (multipart). A fresh cave can answer `"what is two plus two"` with `4` out of the box |

### New module: `src/SigilMediator.jl`

Thin coordinator. Calls `SigilPromoter.promote_input(raw)`, then walks the
returned bindings to determine which routing kinds apply. Deterministic
order on the kinds vector: `[:math, :multipart]`.

```julia
struct SigilMediation
    original::String         # exactly what the user typed
    rewritten::String        # canonical sigil form (e.g. "&n &op &n")
    bindings::Vector{SigilBinding}
    kinds::Vector{Symbol}    # subset of [:math, :multipart], deterministic order
end

mediate(raw::String) -> SigilMediation
has_math(bindings) -> Bool       # ≥2 &n + ≥1 &op
has_multipart(bindings) -> Bool  # ≥1 &conj
kinds_for_bindings(bindings) -> Vector{Symbol}
```

`process_mission` calls `mediate(mission_text)` after image detection in a
non-fatal try/catch — sigil failures degrade to plain pattern-bind, never
abort the mission.

### New macro: `&conj`

Added to `default_registry()`. Lexicon: `["and", "then", "also", "plus",
"but", "or"]`, `promote_at_tokenize=true`. This is what the multipart
clause-slicer keys off. Default-registry size: 5 → 6 sigils.

`&punct` was considered and **dropped** — `SigilPromoter._tokenize` strips
punctuation before binding runs, so a `&punct` macro would be dead infrastructure.

### New tagging convention on `Node.drop_table`

| Tag | Meaning | Status |
|---|---|---|
| `@sigil:math` | Node answers arithmetic via `ArithmeticEngine`; emits one vote per `ComputationStep` plus a final headline vote | ✅ live |
| `@sigil:multipart` | Node answers multi-clause input by slicing on `&conj` boundaries; emits one vote per non-empty clause | ✅ live |
| `@sigil:instruction` | Reserved for Stage-3 instruction-decomposition. Currently raises `SigilFireError` if a node tries to fire with this tag | 🟡 reserved |

Helpers (all in `engine.jl`):
- `node_sigil_kind(node) -> Symbol` — returns the kind (or `:none`) by scanning `drop_table` for the `@sigil:` prefix
- `has_sigil_tag(node) -> Bool`
- `create_sigil_node(pattern, packet, data, drop_table; kind, ...)` — convenience wrapper that prepends the tag
- `list_sigil_node_ids(kind=:any) -> Vector{String}` — walks `NODE_MAP`, **skips graved nodes**, returns ids in deterministic sorted order

`collect_drop_table_neighbors` was updated to filter `@`-prefixed entries so
the existing neighbor-cluster logic doesn't try to treat sigil tags as
content tokens.

### New fire path: `cast_sigil_votes`

```julia
cast_sigil_votes(
    id::String,
    conf::Float64,
    bindings::Vector{SigilBinding},
    original_text::String,
    u_trips::Vector{RelationalTriple},
    n_trips::Vector{RelationalTriple},
)::Vector{Vote}
```

Dispatches on `node_sigil_kind(node)`:
- **`:math`** → `_cast_math_votes` runs `ArithmeticEngine.evaluate(bindings)`, emits one `Vote` per `ComputationStep` (action = first opener from action packet, payload = the step's text rendering). For multi-step problems the final headline vote carries the full answer; for single-step problems just one vote with the answer in payload.
- **`:multipart`** → `_cast_multipart_votes` slices `original_text` at every `&conj` binding's `raw_position` (0-based per SigilPromoter contract — `+1` for Julia indexing), emits one vote per non-empty clause, each with the clause text as payload.
- **`:instruction`** → currently throws `SigilFireError(:reserved, ...)`.
- **`:none`** → delegates to `cast_vote` (the existing single-vote path).
- **Unknown kind** → throws `SigilFireError(:unknown_kind, ...)`. Loud failure, no silent fallback.

`SigilFireError <: Exception` carries `(kind, node_id, reason)` and a clean
`showerror` so traceback noise is bounded.

In the engine fire site, `cast_vote` now peeks `has_sigil_tag(node)` and
fans out to `cast_sigil_votes` when set, with a try/catch fallback to the
plain path so a broken sigil node degrades to one vote rather than killing
the whole fire batch.

### Vote.payload + orchestrator concatenation

The `Vote` struct gained a `payload::String` field with an inner
constructor that defaults `payload=""`. **All 17+ existing 7-arg call
sites compile unchanged.** In `ephemeral_aiml_orchestrator` (Main.jl
~line 2105), after `COMMANDS[primary_vote.action]` produces its output,
`primary_vote.payload` is concatenated when non-empty. This is how the
computed `4` rides alongside the `calculate` action key without breaking
the `COMMANDS[...]` lookup contract.

### Direct routing in `process_mission`

Post-scan, pre-DONE: for each kind in `sigil_mediation.kinds`, walk
`list_sigil_node_ids(kind)` and inject any tagged node that didn't
already win pattern-bind, with `inject_conf = max(0.4, max_primary_conf × 0.5)`.
This means a fresh cave with sigil-tagged seeds can answer math and
multipart inputs even before the user has trained any pattern-reactive
nodes for them.

### Save format v2.6

```jsonc
{
  "format": "grugbot420-specimen-v2.6",
  "version": "2.6",
  // ... all v2.5 keys ...
  "sigils": {
    "label": "default_with_runtime_additions",
    "entries": [
      {"name": "n",    "class": "lambda", "applies_at": "tokenize", "sigil_type": "ord", "promote_at_tokenize": true,  "provenance": "default", "lexicon": null},
      {"name": "op",   "class": "lambda", "applies_at": "tokenize", "sigil_type": "ord", "promote_at_tokenize": true,  "provenance": "default", "lexicon": null},
      {"name": "word", "class": "lambda", "applies_at": "bind",     "sigil_type": null,  "promote_at_tokenize": false, "provenance": "default", "lexicon": null},
      {"name": "rest", "class": "lambda", "applies_at": "bind",     "sigil_type": null,  "promote_at_tokenize": false, "provenance": "default", "lexicon": null},
      {"name": "noun", "class": "tag",    "applies_at": "bind",     "sigil_type": null,  "promote_at_tokenize": false, "provenance": "default", "lexicon": null},
      {"name": "conj", "class": "macro",  "applies_at": "tokenize", "sigil_type": null,  "promote_at_tokenize": true,  "provenance": "default", "lexicon": ["and","then","also","plus","but","or"]}
    ]
  }
}
```

- Lambda predicates (the actual matcher functions) **never serialize** — they
  re-attach via `merge_registry!(table, default_registry(); conflict=:keep)`
  inside `restore_table!`. Restored entries win on conflict; defaults fill
  any gaps. **The merge is now hoisted into a closure that runs even on the
  empty-entries early-return path** so engine defaults are guaranteed
  present after any restore — fix landed in commit `b604a86`.
- v2.5 specimens (no `"sigils"` key) load cleanly: the wipe phase calls
  `SigilRegistry.reset_default_table!()`, the absent key leaves clean
  defaults, no error.
- Save scroll prints `🔣 Sigil registry restored (N sigils)`.
- Validation allowlist extended; unknown keys still fail loud.

### Engine-default sigil seeds

Three sigil-tagged seeds in `Main.jl` boot block. Pattern-bind matches the
canonical sigil-rewritten form, so they also light up via normal pattern-bind:

```julia
# Math: simple two-operand
create_sigil_node("&n &op &n",
                  "calculate^4 | reason^2 | analyze^1",
                  Dict("system_prompt" => "Sigil-bound arithmetic engine: solve the rewritten &n &op &n form step-by-step.",
                       "sigil_kind" => "math"),
                  String[]; kind = :math)

# Math: three-operand
create_sigil_node("&n &op &n &op &n",
                  "calculate^4 | reason^2 | ponder^1",
                  ..., kind = :math)

# Multipart: pattern is just "&conj" so it ONLY pattern-binds when a
# conjunction token is present in rewritten input -- avoids greedy matches.
create_sigil_node("&conj",
                  "explain^4 | describe^2 | elaborate^1",
                  ..., kind = :multipart)
```

End-to-end smoke verified: `"what is two plus two"` → SigilMediator returns
`kinds=[:math]` → math seeds bind on rewritten `"what is &n &op &n"` →
`cast_sigil_votes` invokes `ArithmeticEngine` → primary vote action=`calculate`
payload=`"4"` → orchestrator output ends with `4`.

### Tests

`test/test_sigil_pipeline.jl` — **17 testsets, 123 assertions, all pass**:

1. `SigilMediator.mediate` happy path + kind detection
2. `kinds_for_bindings` deterministic ordering + no false positives
3. Tagging helpers (`node_sigil_kind`, `has_sigil_tag`, `list_sigil_node_ids`)
4. `create_sigil_node` rejects `:none`, dedups existing tag
5. `cast_sigil_votes` for `:math` single-step
6. `cast_sigil_votes` for `:math` multi-step (per-step votes + headline)
7. `cast_sigil_votes` for `:multipart` clause slicing
8. `:instruction` reserved → `SigilFireError(:reserved, ...)`
9. `:none` delegates to `cast_vote`
10. Unknown kind → `SigilFireError(:unknown_kind, ...)`
11. `SigilFireError` fields + `showerror`
12. `Vote.payload` field default + 7-arg backward compat
13. End-to-end `process_mission` stdout capture: `"two plus two"` produces output containing `4`
14. Save / load v2.6 round-trip preserves custom sigils
15. v2.5 backward compat (no `"sigils"` key → defaults)
16. Singleton lifecycle (reset / register / serialize / restore)
17. `restore_table!` bad-input tolerance (skip non-Dict + empty-name with warning, throw on non-array entries) + `list_sigil_node_ids` skips graved nodes

`test/test_save_coverage_v25.jl` was bumped from 87 to **89 assertions**
(asserts `"format" == "grugbot420-specimen-v2.6"`, `"version" == "2.6"`,
and presence of the `"sigils"` block).

Full suite: **48 / 48 testfiles pass, ~4m52s, zero regressions**.

### Why this layer

Pattern-bind is reactive: input → match → action. Sigil routing is
**structural**: input → rewrite → recognize structure → emit one vote per
reasoning step. The two paths share the same vote pool, the same lock-in
floor, the same relation-gated support band. The sigil rail is purely
additive — every pre-v2.6 node and every pre-v2.6 specimen continue to
behave identically.

---

## What was NOT ported (and why)

| From `origin/main` | Why not |
|---|---|
| `TonalJudge.jl` | Depends on v7.21b-1 features (`get_tonal_observation`, `emotional_coherence`, `classifier_mode`) that the v7.15-updates `ActionTonePredictor` does not expose. Hot-swapping ATP would break the v7.15/v7.16 lock-in floor and relation-gated support stack. The new tonal build-up dynamics deliver the same observable arousal-shaping effect without the structural rewrite. If TonalJudge is wanted later, port `PredictionResult`'s `classifier_mode` + `emotional_coherence` fields first, then drop in TonalJudge unchanged. |
| Wholesale `ActionTonePredictor.jl` from main | Same reason as above — main's ATP is a clean v7.21 superset, but `DynamicActionTonePredictor` rebuilds `PredictionResult` positionally with 11 fields and main's struct has 13. Rather than refactor every consumer, only the new dynamics were added on top of the existing 11-field struct. |

These are **deliberate hold-outs**, not mistakes. They can be picked up in a
future round if the user wants them.

---

## Verification (run yourself)

```bash
cd grugbot420
julia --project=. test/runtests.jl
```

Expected: `GrugBot420 Tests | 48 48 ~4m52s`. Zero failures.

Module-by-module:

```bash
# Ported modules
julia --project=. test/test_self_observer.jl       # 129 assertions
julia --project=. test/test_sigil_registry.jl      # 183 assertions (v2.6: +&conj)
julia --project=. test/test_sigil_promoter.jl      # 284 assertions
julia --project=. test/test_arithmetic_engine.jl   # 111 assertions

# v2.6 sigil routing rail
julia --project=. test/test_sigil_pipeline.jl      # 123 assertions

# New tonal dynamics
julia --project=. test/test_tonal_buildup_and_snapback.jl  # 268 assertions

# v2.5/v2.6 save coverage
julia --project=. test/test_save_coverage_v25.jl   # 89 assertions
```

---

## Branch hygiene

- **Don't fork.** See `AGENT_RULES.md`. The agent that created
  `feat/v7.22-lobe-dynamics-followups` off `main` instead of working on
  `v7.15-updates` cost real time; the file documents the rules to prevent
  a repeat.
- **Don't delete branches without explicit named user permission.** Same file.
- **The orphan branch `feat/comprehensive-save-and-chat-proof` was deleted**
  (origin only) in a prior round with user approval.
- **The `feat/v7.22-lobe-dynamics-followups` branch is left intact on origin**
  for the user to inspect or delete at their leisure. It has duplicate
  inline implementations of features now consolidated into this branch via
  the v7.15-updates modules — do not merge it.

---

## File map for this round

```
grugbot420/
├── AGENT_RULES.md                        ← agent-behavior contract (do not fork)
├── READ-FIRST-IMPORTANT.md               ← this file
├── src/
│   ├── ActionTonePredictor.jl            ← MODIFIED: tonal build-up + Lorenz snap-back + v2.5 ser/de
│   ├── ArithmeticEngine.jl               ← NEW (ported from main)
│   ├── ChatterVoteSwap.jl                ← MODIFIED: v2.5 cooldown ser/de
│   ├── CrystalizeTag.jl                  ← MODIFIED: v2.5 state ser/de
│   ├── engine.jl                         ← MODIFIED: sparse-active fire gate + v2.6 sigil tagging + cast_sigil_votes + Vote.payload
│   ├── GroupRegistry.jl                  ← MODIFIED: v2.5 in-memory state ser/de
│   ├── GrugBot420.jl                     ← MODIFIED: 4 new module includes + SigilMediator
│   ├── InputQueue.jl                     ← MODIFIED: v2.5 concept-inhibitions ser/de
│   ├── Main.jl                           ← MODIFIED: save/load wired for v2.5/v2.6 + sigil direct routing + sigil-tagged seeds + payload concat
│   ├── SelfObserver.jl                   ← MODIFIED: process-wide singleton + v2.5 ser/de
│   ├── SigilMediator.jl                  ← NEW (v2.6 routing coordinator)
│   ├── SigilPromoter.jl                  ← NEW (ported from main)
│   ├── SigilRegistry.jl                  ← MODIFIED: process-wide singleton + ser/de + &conj macro + restore default-merge closure
│   ├── Thesaurus.jl                      ← MODIFIED: v2.5 concept-class ser/de
│   └── VoteOrchestrator.jl               ← MODIFIED: sparse-active gate API + constants
└── test/
    ├── runtests.jl                       ← MODIFIED: 8 new entries in ALL_TESTS (v2.5 + v2.6)
    ├── test_arithmetic_engine.jl         ← NEW (ported from main)
    ├── test_dynamic_action_tone.jl       ← MODIFIED: tolerances for jitter+build-up
    ├── test_save_coverage_v25.jl         ← NEW (v2.5/v2.6 save coverage round-trip)
    ├── test_self_observer.jl             ← NEW (ported from main)
    ├── test_sigil_pipeline.jl            ← NEW (v2.6 sigil routing rail — 17 testsets, 123 assertions)
    ├── test_sigil_promoter.jl            ← NEW (ported from main)
    ├── test_sigil_registry.jl            ← NEW (ported from main, +&conj coverage in v2.6)
    ├── test_sparse_active_fire.jl        ← NEW (sparse-active gate coverage)
    └── test_tonal_buildup_and_snapback.jl ← NEW (NEW DYNAMICS COVERAGE)
```
