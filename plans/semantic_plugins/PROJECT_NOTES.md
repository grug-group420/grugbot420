# grugbot420 — Full Project Notes

> Reading-pass notes taken while traversing every source and doc file.
> Goal: build an accurate, complete model of the system before proposing
> a Voter Macro Signal implementation. **No code yet.**

---

## 0. One-paragraph elevator

grugbot420 is a Julia neuromorphic cognitive runtime. A user mission goes
through a pre-gated input pipeline (NegativeThesaurus filter, EyeSystem
arousal, ActionTonePredictor pre-tuning), then a strength-gated stochastic
**voter node** scan across one or more **lobes** (domain partitions),
producing a quorum of `Vote(node_id, action, confidence, …)` records. The
quorum is split into top-tier (locked-in) and sub-top (strength-biased
coinflip) by **VoteOrchestrator**. The result lands at the **AIML executive
layer** which orchestrates the votes into a natural-language reply using
templated rules and substitutes a small set of frame-level `{TAG}`
placeholders. Idle systems (ChatterMode, PhagyMode), an ImmuneSystem, a
Hopfield familiar-input cache, and persistence-as-DNA specimens round out
the platform.

---

## 1. The two distinct node populations (CRITICAL distinction)

There are **two** node systems in grugbot420. The Voter Macro design must
peg to the correct one.

### 1.1 Voter nodes — `engine.jl::Node`

The atomic cognition unit. Population scanned per cycle. Cast `Vote`s.

Fields (engine.jl ~line 433):

| field                           | type                       | notes                                                |
|---------------------------------|----------------------------|------------------------------------------------------|
| `id`                            | `String`                   |                                                      |
| `pattern`                       | `String`                   | text pattern node matches against                    |
| `signal`                        | `Vector{Float64}`          | numeric pattern fingerprint (PatternScanner input)   |
| `action_packet`                 | `String`                   | parseable action specification                       |
| `json_data`                     | `Dict{String,Any}`         | free-form aux data                                   |
| `drop_table`                    | `Vector{String}`           | seeded co-activated patterns                         |
| `throttle`                      | `Float64`                  |                                                      |
| `relational_patterns`           | `Vector{RelationalTriple}` | node's own (subj,rel,obj) facts                      |
| `required_relations`            | `Vector{String}`           | hard-required relations                              |
| `relation_weights`              | `Dict{String,Float64}`     |                                                      |
| `strength`                      | `Float64`                  | [0.0, STRENGTH_CAP]                                  |
| `is_image_node`                 | `Bool`                     | pattern is SDF binary                                |
| `neighbor_ids`                  | `Vector{String}`           | up to MAX_NEIGHBORS                                  |
| `is_unlinkable`                 | `Bool`                     | reached MAX_NEIGHBORS                                |
| `is_grave`                      | `Bool`                     | strength=0 OR persistently slow                      |
| `grave_reason`                  | `String`                   | "STRENGTH_ZERO", "GRAVED-SLOW", ""                   |
| `response_times`                | `Vector{Float64}`          | rolling 24h ledger                                   |
| `ledger_last_cleared`           | `Float64`                  | unix ts                                              |
| `hopfield_key`                  | `UInt64`                   | hash of pattern                                      |
| `fired_this_cycle`              | `Bool`                     | contributor flag                                     |
| `voted_this_cycle`              | `Bool`                     |                                                      |
| `gained_this_cycle`             | `Bool`                     |                                                      |
| `strength_delta_this_cycle`     | `Float64`                  | over-compensation penalty input                      |

`Vote` (immutable):

```
node_id::String
action::String
confidence::Float64
negatives::Vector{String}
user_triples::Vector{RelationalTriple}
node_triples::Vector{RelationalTriple}
antimatch::Bool
```

`cast_vote(id, conf, antimatch, u_trips, n_trips)`:
1. Look up node by id (under `NODE_LOCK`).
2. `select_action(node.action_packet)` → `(winning_action, negatives)`.
3. `bump_strength!(node)` (strength coinflip).
4. Return `Vote(...)`.

`cast_explicit_vote(cmd_name, id)` — bypasses stochastics, sets
`confidence = 9999.0`, used by `/force`.

Globals:
- `NODE_MAP::Dict{String,Node}` under `NODE_LOCK::ReentrantLock`
- `COMMANDS::Dict{String,Function}` — string action names → handler funcs
- `ID_COUNTER::Atomic{Int}`

### 1.2 AIML executive nodes — `AIMLNodeSystem.jl::AIMLNode`

Per-lobe **executive** templates that run AFTER voter nodes finish voting.
This is the **orchestration layer**, not a vote source. AIML reads the
locked-in voter quorum and renders a reply using templates + the AIML
drop-table rule list.

`AIMLNode` carries:
- `id`, `lobe_id`, `template::String`, `strength`, cycle bookkeeping,
  contributor flags, grave state (mirrors voter node lifecycle).

AIML has its own `/aimlRight` and `/aimlWrong` feedback channels —
contributors-only.

Per-lobe AIML "tribes" — each lobe has its own executive population.

---

## 2. The runtime pipeline (one mission, top-to-bottom)

From `Main.jl` and `engine.jl::scan_specimens`:

1. **InputQueue** — input arrives, may be batched.
2. **NegativeThesaurus filter** — inhibited tokens stripped before scan
   (gate-first principle).
3. **`screen_input_complexity`** → `scan_mode ∈ {1, 2, 3}`.
4. **Relational extraction**:
   - `scan_mode < 3`: basic `extract_relational_triples` (non-fatal on err).
   - `scan_mode >= 3`: **`extract_dynamic_relational_triples`** — REQUIRED,
     no fallback, fatal on failure. Compound subjects/objects, nested
     "which/that" clauses, conjunctions.
5. **`ActionTonePredictor.predict_action_tone`** — runs on **every** input.
   - Produces `PredictionResult`: `action_family` ∈ {ASSERT, QUERY, COMMAND,
     NEGATE, SPECULATE, ESCALATE}, `tone_family` ∈ {HOSTILE, CURIOUS,
     DECLARATIVE, URGENT, NEUTRAL, REFLECTIVE}, `arousal_nudge`,
     `action_weight` multiplier, `incomplete_chain` bool, etc.
   - `arousal_nudge` → applied to EyeSystem before scan.
   - `action_weight` → multiplied into per-node confidence inside scan.
6. **(Disabled) Hopfield fast-path** — currently disabled per inline
   comment; would skip scan for familiar inputs.
7. **Active key snapshot** under `NODE_LOCK`, capped at
   `VoteOrchestrator.ACTIVE_FIRE_CAP = 1000`.
8. **`FireCounter`** built for the cycle (`cycle_id = "scan#$hash(input)"`).
9. **`parallel_fire_batches`** runs `fire_one` closure across batches.
   Each `fire_one`:
   - Reads node under lock.
   - Strength-biased scan coinflip (`0.20 + 0.70 * strength/cap`).
   - Pattern scan (`cheap_scan`/`medium_scan`/`high_res_scan`) using
     `RelationalJitter.jitter_score` on raw component scores.
   - Confidence aggregation, ATP `action_weight` multiplier applied.
   - If passes, `cast_vote` returns `Vote`; tuple emitted.
10. **Lobe topicality gate (`apply_lobe_topicality_gate!`)** —
    cross-domain leakage filter. Muted-lobe nodes without a semantic
    bridge (dynamic-triple verb overlap, required_relation match, or
    /nodeAttach) are filtered or discounted to half weight.
11. **Attachment relay** — fired voter nodes can fire their declared
    attachments (`/nodeAttach`) within the global FireCounter cap.
    Connector pattern is injected as `relay_attached` triple.
12. **VoteOrchestrator.select_aiml_votes**:
    - Threshold `AIML_CONFIDENCE_THRESHOLD = 0.15`.
    - Top tier: within `AIML_TOP_TIER_WINDOW = 0.05` of max → locked in.
    - Sub-top: `0.20 + 0.70 * strength/cap` coinflip.
    - Returns `(top, kept_subtop, rejected)`.
13. **Vote aggregation** in `Main.jl` — `sure_votes`/`unsure_votes`
    derived from same top-tier window. Primary vote chosen.
14. **AIML render**:
    - Pick AIML template for lobe.
    - For each rule in `AIML_DROP_TABLE`, roll fire-probability coinflip.
    - `replace(rule.text, "{MISSION}" => mission, ...)` — substitute
      every frame-level placeholder (full list §3).
    - Synthesize natural-language reply (skeleton based on primary
      action family).
15. **BrainStem.dispatch!** — winner-take-all across lobes; propagate
    decayed signal to connected lobes (60% per hop).
16. **Hopfield store** — if confidence cleared `HOPFIELD_STORE_THRESHOLD`
    (1.5) and input has been seen `HOPFIELD_HIT_COUNT_MIN` (2) times,
    record `(input_hash → [node_ids])`.
17. **Reply emitted** to user.
18. **`/right` and `/wrong`** (out-of-band feedback) reinforce/penalize
    contributors via coinflips on strength.

---

## 3. Frame-level template placeholders (existing `{TAG}` system)

In `Main.jl` ~line 1226 (`AIML_DROP_TABLE` rule rendering):

| placeholder            | source                                        |
|------------------------|-----------------------------------------------|
| `{MISSION}`            | raw user input                                |
| `{PRIMARY_ACTION}`     | top vote's action                             |
| `{SURE_ACTIONS}`       | comma-joined top-tier actions                 |
| `{UNSURE_ACTIONS}`     | comma-joined sub-top actions                  |
| `{ALL_ACTIONS}`        | every action in cycle                         |
| `{CONFIDENCE}`         | top vote confidence (rounded)                 |
| `{NODE_ID}`            | top vote node id                              |
| `{MEMORY}`             | pinned memory string                          |
| `{LOBE_CONTEXT}`       | lobe-aware context summary                    |
| `{VOTE_CERTAINTY}`     | "SURE" or "UNSURE"                            |
| `{TIED_ALTERNATIVES}`  | tied sure_votes minus primary                 |

These are **statistics about the cycle**, not world values. They are
substituted via `replace(string, "{TAG}" => value)` — pure literal
substitution, not regex.

`engine.jl` line 3082 also lists these in the rule canonicalization helper.

---

## 4. Subsystem inventory (with role + key files)

| subsystem             | file(s)                                       | role                                                      | runs when                |
|-----------------------|------------------------------------------------|-----------------------------------------------------------|--------------------------|
| InputQueue            | `InputQueue.jl`                               | inbound mission buffer                                    | every input              |
| NegativeThesaurus     | (in `engine.jl` / Main)                       | inhibition list filter                                    | every input, pre-scan    |
| EyeSystem             | `EyeSystem.jl`                                | global arousal gate                                       | every input, pre-scan    |
| ImageSDF              | `ImageSDF.jl`                                 | image → SDF binary signal                                 | image inputs only        |
| ActionTonePredictor   | `ActionTonePredictor.jl`                      | action+tone family pre-prediction (always-on gate-first)  | every input, pre-scan    |
| PatternScanner        | `patternscanner.jl`                           | cheap/medium/high_res scan tiers                          | every scan               |
| RelationalJitter      | `RelationalJitter.jl`                         | per-activation entropy on score components                | every scan               |
| Thesaurus             | `Thesaurus.jl`                                | semantic similarity, synonym expansion, gate filter       | every scan               |
| SemanticVerbs         | `SemanticVerbs.jl`                            | mutable verb-class + synonym registry                     | every triple extraction  |
| DYNAMIC relational    | `engine.extract_dynamic_relational_triples`   | compound triples for complex inputs                       | **only `scan_mode>=3`**  |
| engine.scan_specimens | `engine.jl`                                   | top-level scan orchestrator                               | every input              |
| Lobe                  | `Lobe.jl`                                     | domain partition definition + reverse index               | always                   |
| LobeTable             | `LobeTable.jl`                                | global registry of lobes + connections                    | always                   |
| BrainStem             | `BrainStem.jl`                                | winner-take-all dispatcher + cross-lobe propagation       | every cycle              |
| FullLobeScanner       | `FullLobeScanner.jl`                          | phase-gated full-lobe associative scan, AIML gated by DONE| trigger-based            |
| VoteOrchestrator      | `VoteOrchestrator.jl`                         | top-tier / sub-top vote selection, FireCounter, DONE chs  | every cycle              |
| AIMLNodeSystem        | `AIMLNodeSystem.jl`                           | per-lobe AIML executive tribes                            | every cycle              |
| Main render           | `Main.jl`                                     | `{TAG}` substitution, NL synthesis                        | every cycle              |
| Hopfield cache        | `engine.jl`                                   | familiar-input fast-path (currently disabled)             | always (tracked)         |
| ChatterMode           | `ChatterMode.jl`                              | idle gossip — weak nodes drift toward strong              | idle, ≥1000 nodes        |
| PhagyMode             | `PhagyMode.jl`                                | idle maintenance (orphan prune, decay, recycle, etc.)     | idle, ≥1000 nodes        |
| ImmuneSystem          | `ImmuneSystem.jl`                             | protects mature specimens from funky inputs               | always after maturity    |
| ImmuneThreadPool      | `ImmuneThreadPool.jl`                         | hardened 8-worker pool with priority lanes                | always                   |
| StochasticHelper      | `stochastichelper.jl`                         | shared coinflip helpers + `@coinflip` macro + `bias`      | utility                  |
| GrugBot420 module     | `GrugBot420.jl`                               | top-level package entry; module load order matters        | boot                     |

---

## 5. Where the AIML render actually happens — the single hot spot

`Main.jl :: ephemeral_aiml_orchestrator(mission, votes)`:

1. Sort votes by confidence desc.
2. Build `Vector{VoteCandidate}` from votes (lookup node strength under
   `NODE_LOCK`, attach `STRENGTH_CAP = 10.0`).
3. Call `VoteOrchestrator.select_aiml_votes` →
   `(top_tier, subtop_tier, rejected_tier)`.
4. Empty fallback: if both top and subtop empty, push `rejected_tier[1]`
   into `top_tier` ("cave should always try to answer").
5. Translate candidates back to `Vote`s → `sure_votes`, `unsure_votes`.
6. Tie-break primary: shuffle votes within `1e-9` of max, pick one.
7. **Dispatch** `COMMANDS[primary_vote.action](mission, node, primary_vote,
   sure_votes, unsure_votes, votes)` — THIS is where action handlers run.
8. Every action family (reason, greet, survival, explain, empathy,
   warning) calls `generate_aiml_payload(...)` and resets throttle.
   They all share the same payload builder.

**`generate_aiml_payload` (`Main.jl` line 1191) is the single hot spot
for `{TAG}` substitution** (line ~1226). It iterates `AIML_DROP_TABLE`,
rolls each rule's fire-probability coinflip, and `replace`-substitutes
every `{TAG}` literally. The tag list it substitutes:

```
{MISSION}, {PRIMARY_ACTION}, {SURE_ACTIONS}, {UNSURE_ACTIONS},
{ALL_ACTIONS}, {CONFIDENCE}, {NODE_ID}, {MEMORY}, {LOBE_CONTEXT},
{VOTE_CERTAINTY}, {TIED_ALTERNATIVES}
```

Tag set is canonicalized in `engine.jl :: ALLOWED_RULE_TAGS` (Set). The
`add_orchestration_rule!` validator regexes `r"\{[A-Z_]+\}"` and rejects
anything not in `ALLOWED_RULE_TAGS`. **Implication:** any *new* tag
syntax we introduce must NOT match `\{[A-Z_]+\}` or it gets caught by
the existing strict validator. Using `%TAG%` cleanly side-steps this.

After `generate_aiml_payload` builds the prompt block it falls into the
NL synthesis pipeline (skeleton based on action family + vote
quorum + thesaurus + drop tables + memory + lobe context).

---

## 6. Pipeline as actually called from `process_mission` (`Main.jl` line 2020)

1. `AIMLNodeSystem.begin_cycle!()` — reset per-cycle bookkeeping on every
   AIML executive node.
2. `add_message_to_history!("User", mission_text, false)`.
3. `is_image, img_signal = maybe_convert_image_input(mission_text)`.
4. **TEXT ONLY:**
   `prediction = ActionTonePredictor.predict_action_tone(...)`,
   `apply_prediction_to_arousal!` — writes EyeSystem arousal **before**
   scan. Wrapped in try/catch with @warn (non-fatal). **ATP ALWAYS RUNS
   on text input** — it is part of "the gate comes first", not a
   complex-input gate.
5. **TEXT ONLY:**
   `Thesaurus.thesaurus_gate_filter(mission_text)` — synonym expansion
   logged for operator. Non-fatal.
6. `done_channel = VoteOrchestrator.make_done_channel(8)`.
7. `dispatch_task_with_timeout(scan_and_expand or _scan_image_specimens,
    "scan_cycle", 30.0)` → fetch → `valid_specimens`.
8. `VoteOrchestrator.send_done!(done_channel, DoneSignal(...))` — explicit
   handoff from fire layer to orchestrator layer.
9. `wait_for_done(done_channel, 1; timeout_s=5.0)`.
10. If empty → return silent.
11. `refresh_message_intensities!(mission_text)` — re-score history,
    snap intensity toward relevance, jitter-clamp.
12. `dispatch_task_with_timeout(... cast_vote loop ..., "cast_votes", 10s)`
    → `cast_votes :: Vector{Vote}`.
13. `dispatch_task_with_timeout(ephemeral_aiml_orchestrator, "aiml_orchestrator", 20s)`
    → `(output, sure_votes, unsure_votes)`.
14. Output written to history; `LAST_VOTER_IDS` and
    `LAST_CONTRIBUTOR_IDS` updated.

`scan_and_expand` (engine.jl) internally calls `scan_specimens` (which
ALSO runs ATP for confidence weighting — so ATP runs twice, once in
Main for arousal, once in engine for action_weight; the two uses are
intentionally orthogonal).

Then `scan_and_expand` runs the attachment-relay pass (fire_attachments!)
and finally `apply_lobe_topicality_gate!` — cross-domain leakage filter.

---

## 7. Action packets — relevant for macro design

`parse_action_packet(packet::String)` understands:

- Pipe-delimited actions: `"reason | analyze[no, never]^2.5 | flee"`.
- Inline negatives: `[neg1, neg2]` after action name.
- Weight suffix: `^X.X` (must be > 0.0).
- Returns `(positives, all_negatives, action_items)`.

`select_action(packet::String)` weighted-coinflips `(name, weight)`
positives via `@coinflip` and `bias(Symbol(name), prob_pct)`.
Returns `(winning_action::String, negatives::Vector{String})`.

So the action packet field on a node is essentially a tiny DSL of the
**actions** that node can vote for. The macro signal is structurally
parallel: **secondary** vote payload that doesn't compete for action
selection but rides along.

---

## 8. Strength model (relevant for sub-top coinflip)

- `STRENGTH_CAP = 10.0`, `STRENGTH_FLOOR = 0.0`.
- `bump_strength!`: 50/50 coinflip; if heads, `strength += 1.0`, capped.
- `penalize_strength!` (from `/wrong`): coinflip; on heads, decrement.
- `mark_node_grave!`: `is_grave = true`, `grave_reason ∈ {"STRENGTH_ZERO",
  "GRAVED-SLOW", ""}`.
- `STRENGTH_SOLIDIFY_THRESHOLD = 9.0` — at 90% cap, node is "solidified"
  (mostly immune to /wrong decay or further bumps; behavior gate).
- `is_nonjitter(node)` / `set_nonjitter!` — node-scoped jitter
  suppression for relay-conf jitter.

`strength_biased_scan_coinflip(node)`:
```
prob = 0.20 + (strength / STRENGTH_CAP) * 0.70   # range [0.20, 0.90]
return rand() < prob
```
This is the same formula `VoteOrchestrator.strength_biased_vote_coinflip`
uses for sub-top vote retention. **Strong nodes are more likely to be
scanned, more likely to keep their sub-top vote, and more likely to
fire as attachments.**

---

## 9. Specimen save format (from `save_specimen_to_file!`)

Sections (each a key in the top-level Dict):
- `"nodes"` — every Node field, `signal` as JSON array, `hopfield_key`
  stringified UInt64.
- `"hopfield_cache"` — currently still serialized even though scan path
  is disabled (compatible going forward).
- `"rules"` — `[Dict("text"=>..., "prob"=>...) ...]` from `AIML_DROP_TABLE`.
- (continues with attachments, lobes, immune state, AIML state, etc.)

**Implication for macros:** any new persistent state we add (Node fields,
trigger registry, attachment of macros to nodes) must:
- Plain-string-only on the wire (no closures).
- New keys must be tolerated as `missing` on load for old specimens.
- Saved/loaded under existing locks + the same JSON-safe rules
  (UInt64 → string, etc.).

---

## 10. Module load order (from `GrugBot420.jl`)

```
stochastichelper → patternscanner → ImageSDF → EyeSystem → SemanticVerbs
→ ActionTonePredictor → LobeTable → Lobe → BrainStem → Thesaurus
→ InputQueue → ChatterMode → PhagyMode → ImmuneSystem → ImmuneThreadPool
→ FullLobeScanner → RelationalJitter → AIMLNodeSystem → VoteOrchestrator
→ engine.jl → Main.jl
```

Anything new for macros must slot in **after RelationalJitter** (so
jitter is available for the coinflips) and **before engine.jl** (so
engine can reference the new module's API), assuming we put the
trigger registry in its own module. Or we can put the registry inline
in `engine.jl` with a forward declaration — depends on cleanliness
preference.

---

## 11. Gate observations relevant to the macro design

Per the user's directive, **the macro plug-in system has no
input-shape gate.** It fires whenever a voter node carrying a macro
wins the AIML lock-in (top tier or surviving sub-top). Simple input,
complex input — doesn't matter. The macro is a property of the *node*,
not the input.

That said, the existing complexity machinery is documented here for
context, since macros must coexist with it without interfering:

- **`screen_input_complexity`** returns `scan_mode ∈ {1, 2, 3}` based
  on `(sig_len * 0.15) + (rel_count * 1.5)`:
  - `< 1.5` → mode 1 (cheap)
  - `< 4.5` → mode 2 (medium)
  - `≥ 4.5` → mode 3 (high-res, dynamic triples required)
- **`extract_dynamic_relational_triples`** only runs as the
  *user-facing* triple-extractor at mode 3.
- **`apply_lobe_topicality_gate!`** runs at the END of
  `scan_and_expand` and uses `extract_dynamic_relational_triples
  (mission, mode=3)` regardless of original scan_mode. This is the
  gate's internal bridge check; it does NOT reflect the input's actual
  scan_mode.
- **`ActionTonePredictor.predict_action_tone`** runs on EVERY input
  (always-on gate-first). Its DYNAMIC mode kicks in only at mode 3.

None of these systems gate the macro plug-in. They run as they always
have. The macro pass is orthogonal: it kicks in based on which voter
nodes won, not based on input shape.

---

## 12. New tag syntax constraints

The existing `add_orchestration_rule!` validator regex is:
```
r"\{[A-Z_]+\}"
```
and only accepts tags in `ALLOWED_RULE_TAGS`.

The macro `%NAME%` syntax:
- Cannot use `{...}` (collides with validator).
- Should be uppercase letters/underscores by analogy: `%TIME%`, `%CALC%`,
  `%WEATHER%`.
- Must be substituted in `generate_aiml_payload` AFTER the existing
  `{...}` substitution loop, so macros cannot accidentally inject
  `{TAG}` strings that get re-resolved.
- Must be substituted **per rule** so unfired rules (lost their
  fire-probability coinflip) don't pay the macro cost. This means the
  `%X%` pass is per-rule-text inside the same loop.

---

## 13. Where the secondary macro vote belongs structurally

Three candidate placements, each with trade-offs:

**(a) New optional field on `Node`** (`macro_signal::String` default `""`):
- Pros: persists with specimen; per-node opt-in is natural;
  semantically matches "voter node carries a macro signal".
- Cons: slightly bloats every node even when 99% don't carry one.

**(b) New side dictionary** `NODE_MACRO_MAP::Dict{String,String}`:
- Pros: zero overhead on nodes that don't opt in; cleanly
  serializable as a separate specimen section.
- Cons: extra lookup hop in `cast_vote`; two locks to coordinate.

**(c) Composite via `relational_patterns`** (encode macro as a
special triple with `relation == "@macro"`):
- Pros: zero new fields anywhere; uses existing serialization.
- Cons: overloads relational triples; risk of macro triples leaking
  into actual relational eval; not user-clear.

**Recommendation: (a)** — the user model is "voter nodes carry a macro
signal". Adding the field is honest and inspectable. We can
default-empty it on existing specimens at load time.

---

## 14. Where the secondary macro field belongs on `Vote`

Single new field: `macro_signal::String` (default `""`). `cast_vote`
copies `node.macro_signal` to `Vote.macro_signal` **unconditionally**
— no input-shape gate, no scan_mode check. If the node has no macro,
the slot stays `""`.

A `Vote` carrying a non-empty `macro_signal` is the "secondary vote"
the user described. The primary vote (`action`, `confidence`) is
unchanged; the macro rides along.

---

## 15. Where AIML reads the locked macros

`ephemeral_aiml_orchestrator` already produces `top_tier` and
`subtop_tier`. After the existing tie-break, dedupe macro names from
both tiers (top is auto-locked; sub-top must have already passed its
strength-biased coinflip):

```
locked_macros = unique(filter(!isempty,
    String[v.macro_signal for v in vcat(sure_votes, unsure_votes)]))
```

`locked_macros` is then passed into `COMMANDS[action](...)` via an
extra positional or via a thread-local context. Cleanest: extend the
`context::Dict` already passed through `generate_aiml_payload`.

If `locked_macros` is empty (no carrier voters won), the `%X%`
substitution pass is a no-op. Templates that reference `%X%` when no
matching macro is locked emit `@warn` and leave the placeholder
intact (default) or throw (strict mode).

---

## 16. Two open design questions (carried forward)

1. **Strict-mode default** for unresolved `%X%` placeholders — warn or
   throw?
2. **Multi-macro per node** — `String` or `Vector{String}`?
3. **Phase 1 built-in resolver scope** — `current_time` + `current_date`
   + `calc` only, or include `weather` (remote) in phase 1?

