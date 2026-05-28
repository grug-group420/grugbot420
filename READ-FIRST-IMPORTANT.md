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

Expected: `GrugBot420 Tests | 45 45 ~4m`. Zero failures.

Module-by-module:

```bash
# Ported modules
julia --project=. test/test_self_observer.jl       # 129 assertions
julia --project=. test/test_sigil_registry.jl      # 177 assertions
julia --project=. test/test_sigil_promoter.jl      # 284 assertions
julia --project=. test/test_arithmetic_engine.jl   # 111 assertions

# New tonal dynamics
julia --project=. test/test_tonal_buildup_and_snapback.jl  # 268 assertions
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
│   ├── engine.jl                         ← MODIFIED: sparse-active fire gate at 2 sites
│   ├── GroupRegistry.jl                  ← MODIFIED: v2.5 in-memory state ser/de
│   ├── GrugBot420.jl                     ← MODIFIED: 4 new module includes
│   ├── InputQueue.jl                     ← MODIFIED: v2.5 concept-inhibitions ser/de
│   ├── Main.jl                           ← MODIFIED: save/load wired for v2.5 (7 new keys)
│   ├── SelfObserver.jl                   ← MODIFIED: process-wide singleton + v2.5 ser/de
│   ├── SigilPromoter.jl                  ← NEW (ported from main)
│   ├── SigilRegistry.jl                  ← NEW (ported from main)
│   ├── Thesaurus.jl                      ← MODIFIED: v2.5 concept-class ser/de
│   └── VoteOrchestrator.jl               ← MODIFIED: sparse-active gate API + constants
└── test/
    ├── runtests.jl                       ← MODIFIED: 7 new entries in ALL_TESTS
    ├── test_arithmetic_engine.jl         ← NEW (ported from main)
    ├── test_dynamic_action_tone.jl       ← MODIFIED: tolerances for jitter+build-up
    ├── test_save_coverage_v25.jl         ← NEW (v2.5 save coverage round-trip)
    ├── test_self_observer.jl             ← NEW (ported from main)
    ├── test_sigil_promoter.jl            ← NEW (ported from main)
    ├── test_sigil_registry.jl            ← NEW (ported from main)
    ├── test_sparse_active_fire.jl        ← NEW (sparse-active gate coverage)
    └── test_tonal_buildup_and_snapback.jl ← NEW (NEW DYNAMICS COVERAGE)
```
