# Voter Macro Signal — Design (grugbot420)

> **Status:** design draft, no code yet. Builds on the existing voter-node /
> VoteOrchestrator / AIML pipeline. Replaces the earlier
> `AIML_MACRO_FILLIN_DESIGN.md` which was pegged to the wrong node system.
>
> **Scope:** grugbot420 only. Not analog-turing.

---

## 0. Problem statement

Current pipeline: a user mission goes through `pattern bind → cast_vote →
select_aiml_votes → AIML executive → orchestration rules → reply`.

Every `Vote` is `(node_id, action, confidence, …)`. An action is a fixed
string drawn from the node's action packet. The orchestration rule layer
(`AIML_DROP_TABLE` in `Main.jl`) does string substitution for a small set of
**frame-level** placeholders that describe the *current cycle*:

```
{MISSION}, {PRIMARY_ACTION}, {SURE_ACTIONS}, {UNSURE_ACTIONS}, {ALL_ACTIONS},
{CONFIDENCE}, {NODE_ID}, {MEMORY}, {LOBE_CONTEXT}, {VOTE_CERTAINTY},
{TIED_ALTERNATIVES}
```

These tags are **statistics about the vote**. They cannot pull a live world
value (current time, current weather, a calculator result, an HTTP fetch).

Compound user inputs like

> "what is a dog also what time is it?"

are exactly the case where part of the answer is a **pattern → action** match
(`dog`) and part of the answer is a **value plug-in** (`current time`). The
pattern half is already covered. The plug-in half is not.

We need a way for the system to detect, *during the same vote round*, that a
**live value is required**, and to hand AIML the information it needs to
fill that value in at orchestration time.

---

## 1. Mental model

1. **Voter nodes** (the main population in `engine.jl`, struct `Node`,
   produced by `cast_vote` returning `Vote`) are what cast votes during scan.
   They carry `pattern`, `action_packet`, `signal`, `relational_patterns`,
   `strength`, etc. **They are NOT AIML nodes.**

2. **AIML nodes** (`AIMLNodeSystem.jl`) are the *executive* layer. They are
   per-lobe templates invoked **after** voter nodes have finished voting.
   AIML is the **orchestrator**. AIML does not vote on world values —
   it fills them in.

3. The top-confidence selection rule already exists in
   `VoteOrchestrator.select_aiml_votes`:
   - **Top tier** (within `AIML_TOP_TIER_WINDOW = 0.05` of max,
     above `AIML_CONFIDENCE_THRESHOLD = 0.15`): locked in, no coinflip.
   - **Sub-top:** strength-biased coinflip.
   - **Rejected:** below threshold or lost the flip.

4. **The new piece:** when a voter node has a macro attached to it, that
   macro rides along on its vote as a **secondary** payload. If the voter
   wins (top tier or surviving sub-top), its macro is locked in alongside
   its primary action. AIML reads the macro names out of the locked vote
   bundle and performs the fill-in.

5. **No special gate.** The macro system fires on simple OR complex inputs.
   The plug-in is a property of the *node*, not of the input. If a voter
   carrying a macro wins its strength-biased scan coinflip and clears the
   AIML threshold, the macro fires. Simple as that. Complex-input dynamic
   systems (`extract_dynamic_relational_triples`, etc.) keep doing their
   own thing for relational reasoning — they are not part of the macro
   gate.

6. **Semantic side systems** are how voter nodes decide what macro to
   carry. These already exist:
   - `SemanticVerbs` — verb classes + synonyms.
   - `Thesaurus` — concept similarity, synonym expansion, gate filter.
   - `RelationalJitter` — per-activation entropy.
   - `ActionTonePredictor` — action family + tone pre-prediction (always
     on).
   They inform user-registered semantic-fill-in rules: "if a node's
   pattern overlaps with these cue tokens, it can carry this macro."
   The matching itself happens at registration / `/nodeMacro` time, not
   at fire time.

7. The end user can **register their own macro triggers** at runtime
   the same way they can `/addVerb`, `/addSynonym`, etc. today.

---

## 2. No special gate — fires on any input

The macro system is a property of the **node**, not the input.

A voter node either carries a macro signal (set by the user via
`/nodeMacro` or, in phase 3, auto-attached by node agency) or it doesn't.
When a node casts a vote, if it carries a macro, the macro rides along on
the `Vote`. When `select_aiml_votes` picks the top tier and surviving
sub-top, every macro on every locked vote is in scope for AIML fill-in.

**There is no scan_mode gate, no clause-count predicate, no compound-query
detector.** The plug-in fires whenever the carrier voter wins. That's it.

This matches the natural composition: if a user asks "what time is it?"
and a `time#7` node with `macro_signal = "current_time"` wins, the macro
fires. If a user asks "what is a dog also what time is it?" and BOTH
`dog#42` and `time#7` win at top tier, only `time#7`'s macro fires —
`dog#42` doesn't carry one. Either case works without a gate.

The complex-input dynamic systems (`extract_dynamic_relational_triples`,
mode-3 high-res scan) keep doing their own thing for relational reasoning.
They are entirely orthogonal to macros.

---

## 3. Where the macro signal lives on a voter node

Add **one optional field** to `engine.Node`:

```julia
# (sketch, NOT TO IMPLEMENT YET)
macro_signal :: String   # "" means "no macro"; else macro name like "current_time"
```

Defaults to empty. Most nodes never set it.

`Vote` gets one new optional field:

```julia
macro_signal :: String   # propagated from the casting node, "" if none
```

`cast_vote` copies the node's `macro_signal` into the `Vote` it returns
unconditionally — no input-shape gate, no scan_mode check. If the node
has a macro, the vote carries it. If the vote later loses (rejected
tier), the macro is dropped along with the rest of the rejected vote.

This is the "secondary vote" the user described. It rides along on the
existing primary `Vote`. No second scanner pass, no second
`select_aiml_votes` call. Same struct, one extra string.

---

## 4. Macro selection during AIML lock-in

Inside `select_aiml_votes` the **top tier** is already computed. Extend the
return shape (or add a parallel helper) to also produce:

```
locked_macros :: Vector{String}
```

— deduplicated macro names taken from the top-tier and kept-sub-top vote
bundles. Sub-top macros are only kept when the carrier vote itself survived
the strength-biased coinflip. This is the part the user called out:

> "votes with locked in confidence which are any vote past a threshold these
>  are hard aiml selections … a secondary vote fires from the winners with
>  fill in macros."

Macros from rejected votes are dropped. They never reach AIML.

`locked_macros` is empty for any cycle where no macro-carrying voter wins.

---

### 5. How voter nodes know *what* macro to carry — the Macro Trigger Registry

The voter node does **not** hard-code macro logic. It carries a name. The
matching, the deciding, and the fill-in live in a separate mutable registry,
much like `SemanticVerbs._VERB_REGISTRY` is mutable today.

New module `MacroTriggers.jl` (sketch only, not implementing yet):

```
const MACRO_TRIGGERS = Dict{String, MacroTrigger}()  # name -> trigger
```

A `MacroTrigger` carries:

| field            | type                        | role                                                   |
|------------------|-----------------------------|--------------------------------------------------------|
| `name`           | `String`                    | e.g. `"current_time"`                                  |
| `placeholder`    | `String`                    | e.g. `"%TIME%"` — what AIML will substitute            |
| `kind`           | `Symbol`                    | `:builtin` (system-supplied), `:user`, `:remote`       |
| `resolver_id`    | `String`                    | name of the resolver function in the registry          |

We deliberately store **a resolver name, not a closure**, so the registry
serializes cleanly with the rest of the specimen.

### 5.1 Built-in macro triggers (proposed minimum set)

| name           | placeholder    | semantic_match (cues)                               | resolver           |
|----------------|----------------|------------------------------------------------------|--------------------|
| `current_time` | `%TIME%`       | "time", "clock", "hour", "now"                      | `resolve_time`     |
| `current_date` | `%DATE%`       | "date", "day", "today"                              | `resolve_date`     |
| `weather`      | `%WEATHER%`    | "weather", "temperature", "forecast", "rain"        | `resolve_weather`  |
| `calc`         | `%CALC%`       | numeric tokens + arithmetic verbs                    | `resolve_calc`     |
| `ip`           | `%IP%`         | "ip address", "my ip"                               | `resolve_ip`       |

Built-in resolvers `resolve_time`, `resolve_date`, etc. live in a new
`AIMLResolvers.jl` module. `resolve_weather` and `resolve_ip` use free
public APIs (`wttr.in`, `worldtimeapi.org`, `api.ipify.org`) per the user's
earlier ask. `resolve_calc` is a pure-Julia safe arithmetic evaluator
(addition, subtraction, multiplication, division, parentheses — **no**
`eval`, **no** code execution).

### 5.2 User-registered macro triggers

Two new slash commands (definition only, no implementation here):

```
/macroAdd <name> <placeholder> <cue1> <cue2> ... <resolver_name>
/macroRemove <name>
```

`<resolver_name>` must already exist in the resolver registry. Users
register resolvers either by:

- pointing at an existing built-in (`resolve_time`, etc.), or
- registering a remote one via `/macroRemote <resolver_name> <url_template>
  <jq_path>` — this stores a small declarative descriptor (URL, JSON path),
  **not** an executable closure, so it survives specimen save/load.

### 5.3 How a voter node opts in

Two new slash commands at node level:

```
/nodeMacro <node_id> <macro_name>
/nodeMacroClear <node_id>
```

This is the user-driven path. It writes `macro_signal = "current_time"` (or
whichever name) onto the node. That's it — no second field, no gate name.

---

## 6. Node agency — auto-attaching macros (deferred but planned)

The user also said:

> "nodes should also have more agency. like ability to add macros on the
>  fly as needed"

Plan, but not part of phase 1:

- During a successful scan where a node was a top-tier voter and the
  user mission contained tokens that matched a
  `MacroTrigger.semantic_match` cue, the node may **autonomously** attach
  `macro_signal = trigger.name` to itself with a small probability,
  modulated by the node's strength (same coinflip family used by the rest
  of the engine).
- This is the analogue of the existing strength-bumping behavior: the node
  notices a useful behavior was needed in its neighborhood and ratchets
  toward providing it next time.
- `/right` reinforcement on a contributor that fired with a macro keeps
  the macro association. `/wrong` decays it. Same machinery as today's
  contributor reinforcement, just one extra field.

This whole section is **disabled** in phase 1. It only turns on once §3–§5
are stable.

---

## 7. AIML as the orchestrator (the fill-in step)

AIML never decides *whether* a macro fires. It only renders.

In `Main.jl` near the existing `processed = replace(processed, "{MISSION}"
=> mission)` block, **after** all `{...}` frame-level tags are substituted:

1. AIML sees `locked_macros :: Vector{String}` from §4.
2. For each macro name, look up its `placeholder` and `resolver_id` in the
   `MACRO_TRIGGERS` registry.
3. Call the resolver. Resolvers must return `String` and must error loudly
   on failure (NO SILENT FAILURES — same engine convention).
4. `replace(processed, placeholder => resolved_value)`.
5. If a placeholder `%X%` survives the pass (i.e. an AIML template
   referenced `%X%` but the matching macro was not in `locked_macros`),
   **leave it alone** in dev builds and emit a `@warn`. In strict mode,
   raise an error. The strictness is a config flag; default is warn-only.

Two distinct syntaxes therefore coexist on purpose:

| syntax     | meaning                                | resolved by                  |
|------------|----------------------------------------|------------------------------|
| `{NAME}`   | frame-level orchestration tag          | existing AIML rule renderer  |
| `%NAME%`   | world-level live value (macro)          | new macro fill-in pass       |

The two passes never collide. `{...}` is statistics about the cycle.
`%...%` is a pull from the world.

---

## 8. Compound-input flow walkthrough

User mission: **"what is a dog also what time is it?"**

1. Normal pipeline runs: tokenization, lemma extraction, pattern bind, etc.
   `screen_input_complexity` returns `scan_mode = 3`, so the existing
   complex-input dynamic systems (`extract_dynamic_relational_triples`,
   high-res scan) light up. **None of this is macro machinery** — it's
   the same pipeline as today.
2. Voter scan fires. Node `dog#42` matches `pattern = "dog"`, casts a
   primary vote `action = "explain_dog"` with confidence ~ 0.42.
   `dog#42` carries no `macro_signal`, so its vote's `macro_signal` is
   `""`.
3. Node `time#7` matches the lemma "time" and has
   `macro_signal = "current_time"` (set at registration). It casts a
   primary vote `action = "report_time"` with confidence ~ 0.40 and
   the `Vote` carries `macro_signal = "current_time"` — copied
   unconditionally by `cast_vote`.
4. `select_aiml_votes` runs. Both `dog#42` and `time#7` clear threshold
   and fall inside the top-tier window. Both are locked in.
   `locked_macros = ["current_time"]` (deduped from the locked bundle;
   `dog#42` contributed nothing because its slot was empty).
5. AIML executive picks its template for the lobe. Template happens to
   contain `... and the time is %TIME%.`
6. Frame-level tags are substituted (`{MISSION}`, `{PRIMARY_ACTION}`,
   etc.) as today.
7. New macro fill-in pass runs: `%TIME%` → `resolve_time()` → e.g.
   `"14:32 UTC"`.
8. Final reply leaves the cave with both the dog explanation **and** the
   live time.

If the user instead asked just *"what time is it?"* — same flow, just
`time#7` alone wins, `locked_macros = ["current_time"]`, and the macro
fires. Simple input, macro fires. No gate.

If the user asked just *"what is a dog?"* — `time#7` may or may not
even cast (depends on lemma overlap); if it does cast and loses the
top-tier cut, its macro is dropped with the rejected vote.
`locked_macros` ends up empty, no macro pass runs, no macro tax.

---

## 9. /right and /wrong feedback under macros

No new feedback math. The contributor list already exists. Adjustments:

- A vote that carried a non-empty `macro_signal` and contributed to output
  is a contributor. It already gets reinforced by `/right`.
- If `/wrong` lands on a cycle whose macro pass was active, the carriers
  of the macro are penalized exactly like other contributors. Their
  `macro_signal` field is **not** automatically cleared on a single
  `/wrong` — apoptosis (strength → 0 → grave) handles persistent failures
  the same way it does for action choices.

---

## 10. Persistence

Specimen save/load needs the new fields, no new file format:

- `Node.macro_signal`: plain string, serializes trivially.
- `MacroTrigger` records: serialize the descriptor (name, placeholder,
  cues, kind, resolver_id). **Do not** serialize closures.
- Built-in resolver names are re-bound at boot from the resolver
  registry. User-registered remote descriptors are reattached from the
  saved descriptor.

Specimens saved before this feature load cleanly: missing fields default
to empty / no macro.

---

## 11. Constraints and non-goals

- **No code in this phase.** This file is the plan.
- **No LLM dependency.** Calculator is pure arithmetic. Remote APIs are
  small, free, and explicit; user opts in. No model in the loop.
- **No silent failures.** Resolver errors throw. Missing trigger throws
  (or warns, depending on strict-mode flag). Same convention as the rest
  of grugbot420.
- **Macros do not vote.** They cannot beat a pattern → action vote. They
  ride along on a winning vote. If no voter wins, no macro fires.
- **Macro cost is bounded by carrier-node count.** Most nodes have empty
  `macro_signal`; the registry lookup for an empty string is a single
  branch. Only nodes the user (or, in phase 3, the engine itself) has
  explicitly opted in pay any macro cost at all.
- **Per-frame deduplication.** Same macro name from multiple top-tier
  voters resolves once per cycle. Resolver outputs are cached for the
  duration of the cycle only.

---

## 12. Phased rollout

**Phase 1 — minimal vertical slice**

- `MacroTrigger` struct + global registry.
- `Node.macro_signal` field, default `""`.
- `Vote.macro_signal` field, copied unconditionally by `cast_vote`.
- `select_aiml_votes` returns `locked_macros`.
- New `%NAME%` substitution pass in `Main.jl`, after `{...}` pass.
- Built-in `resolve_time` and `resolve_calc` only.
- Slash commands: `/nodeMacro`, `/nodeMacroClear`, `/macroAdd`,
  `/macroRemove`.

**Phase 2 — remote resolvers**

- `/macroRemote` slash command.
- `resolve_weather`, `resolve_date`, `resolve_ip` built-ins.
- HTTP timeout + cache layer.

**Phase 3 — node agency**

- Auto-attachment per §6.
- Strength-modulated coinflip for self-assignment.
- Decay on `/wrong`.

**Phase 4 — semantic auto-suggest**

- Use `Thesaurus.expand_token_set` to translate user cues into trigger
  matches. Right now §5 stores raw strings; phase 4 lets cues be
  classes (e.g. `:temporal_query` synthesized from
  `SemanticVerbs.get_verbs_in_class("temporal")`).

---

## 13. Open questions (defer until user signs off on §1–§12)

- Should a single voter node be allowed to carry **multiple** macro
  signals (e.g. both `current_time` and `current_date`)? Current sketch
  allows one. Could promote `macro_signal` to `Vector{String}`.
- Should the macro pass run **before** the orchestration synthesis or
  **after**? Current sketch says after `{...}` substitution but before
  the final natural-language synthesis at line ~1255 of `Main.jl`.
  Confirm.
- Strict mode default: warn-only or hard-error on unresolved `%X%`?

---

*End of design draft. Awaiting sign-off before any code lands.*
