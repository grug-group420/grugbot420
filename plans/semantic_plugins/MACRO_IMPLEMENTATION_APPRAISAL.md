# Voter Macro Signal — Implementation Appraisal

> **Companion to:** `PROJECT_NOTES.md` (full system audit) and
> `VOTER_MACRO_SIGNAL_DESIGN.md` (the design spec).
>
> **Purpose:** answer the user's request to "appraise me of the best way
> to do this" after reading the entire grugbot420 codebase. This is the
> opinionated recommendation, with explicit trade-offs.

---

## TL;DR

The cleanest implementation is a **single thin slice** that touches five
files:

1. `engine.jl` — add `Node.macro_signal::String` (default `""`).
   Add `Vote.macro_signal::String`. `cast_vote` copies the node's
   `macro_signal` onto the Vote unconditionally — no input-shape gate,
   no scan_mode check. The macro is a property of the node.
2. `VoteOrchestrator.jl` — add `VoteCandidate.macro_signal::String`,
   no other changes. The existing top-tier / sub-top split is already
   correct; macros simply ride along on whichever candidates survive.
3. **New module** `MacroTriggers.jl` — a `Dict{String, MacroTrigger}`
   registry of named triggers, each with a placeholder string
   (`%NAME%`), a built-in resolver name, and a small declarative
   spec (kind, optional remote URL template, JSON path). Loaded
   between `RelationalJitter` and `AIMLNodeSystem` in `GrugBot420.jl`.
4. `Main.jl :: generate_aiml_payload` — add a **second substitution
   pass** AFTER the existing `replace(rule.text, "{TAG}" => ...)` loop
   that resolves any `%NAME%` whose name appears in `locked_macros`.
   The orchestrator computes `locked_macros` once per cycle and feeds
   it via the existing `context::Dict`.
5. **New slash commands** in `Main.jl`: `/nodeMacro`, `/nodeMacroClear`,
   `/macroAdd`, `/macroRemove`, `/macroList`, `/macroRemote` (phase 2).

That is the entire phase-1 surface area. Everything else (auto-attach,
remote resolvers, semantic auto-suggest) is purely additive on top of
this skeleton.

---

## Why this shape — the four constraints driving the design

### 1. The macro fires when a carrier voter wins. No input-shape gate.

Per the user's direction: "plugin system can fire for simple or complex
input. that's not the point." A macro is a property of the *node*, not
of the input. If a voter carrying a macro wins (top tier, or surviving
sub-top), its macro is locked in. If no carrier wins, no macro fires.
That's the entire condition.

This collapses what would have been a complex gate predicate
(`scan_mode == 3` plus ATP query family plus clause-count heuristics)
into a single line in `cast_vote`: copy `node.macro_signal` to
`Vote.macro_signal`. Done.

The complex-input dynamic systems
(`extract_dynamic_relational_triples`, mode-3 high-res scan,
`ActionTonePredictor`'s dynamic mode) keep doing their own thing for
relational reasoning. They are entirely orthogonal to macros.

### 2. The validator regex `\{[A-Z_]+\}` forces the syntax

`add_orchestration_rule!` already rejects any `{TAG}` not in
`ALLOWED_RULE_TAGS`. We cannot reuse `{TIME}` — it would be rejected at
rule registration. We must use a syntax that the validator literally
cannot match. `%NAME%` is the obvious choice and it's also visually
distinct ("frame stat" vs "world value").

### 3. AIML render is a single hot spot

Every action handler in `Main.jl` (reason, greet, survival, explain,
empathy, warning) routes through `generate_aiml_payload`. The `{TAG}`
substitution loop is right there, line ~1226. Adding a second
`replace(text, "%X%" => resolved)` loop after it costs nothing
architecturally and keeps macro handling co-located with the existing
template machinery.

This is also where the existing per-rule fire-probability gating works
in our favor: rules that lost their `rand() > rule.fire_probability`
coinflip never reach the macro pass.

### 4. Specimens persist as JSON, no closures allowed

`save_specimen_to_file!` serializes every Node field straight into a
Dict. Adding `macro_signal::String` is trivial — empty string on every
existing node when loaded, no migration needed. Adding the
`MacroTriggers` registry is trivial **only if** we store names of
resolvers, not closures. Resolvers live in a code-side
`RESOLVER_REGISTRY::Dict{String, Function}` that is **rebuilt at boot**
from the package's built-ins, plus any user-registered remote
descriptors that store URL+jq path declaratively.

This is the single most important architectural rule for phase 1: the
trigger registry contains data, never code.

---

## Concrete struct/field recommendations (no code, just shapes)

### `engine.jl :: Node`

Add **one** new field:

```
macro_signal :: String   # default ""
```

That's it. No `macro_signal_when` (no gate). No `Vector{String}` yet
(defer to later phase — single name covers the "what time is it"
case).

### `engine.jl :: Vote`

Add one new field:

```
macro_signal :: String   # default ""
```

`cast_vote` reads `node.macro_signal` and copies it onto the Vote
unconditionally. If the node has no macro, the Vote's slot is `""`
(cheap empty string, no allocation overhead beyond the field itself).

### `VoteOrchestrator.jl :: VoteCandidate`

Add one new field:

```
macro_signal :: String   # default ""
```

`select_aiml_votes` is unchanged — it operates on confidence and
strength, exactly as today. The macro rides through. Calling code in
`ephemeral_aiml_orchestrator` builds candidates from votes and pulls
`v.macro_signal` through. After selection, the orchestrator scans the
locked candidates and produces `locked_macros::Vector{String}`
(deduplicated, empty strings filtered).

### `MacroTriggers.jl` (new module)

Three top-level constants:

```
MACRO_TRIGGER_REGISTRY :: Dict{String, MacroTrigger}
RESOLVER_REGISTRY      :: Dict{String, Function}
MACRO_TRIGGER_LOCK     :: ReentrantLock
```

`MacroTrigger`:

```
name         :: String          # e.g. "current_time"
placeholder  :: String          # e.g. "%TIME%"
resolver_id  :: String          # key into RESOLVER_REGISTRY
kind         :: Symbol          # :builtin | :user | :remote
remote_spec  :: Union{Nothing, RemoteResolverSpec}   # phase 2
```

`RemoteResolverSpec` (phase 2):

```
url_template :: String          # e.g. "https://wttr.in/{q}?format=j1"
jq_path      :: String          # e.g. ".current_condition[0].temp_C"
timeout_s    :: Float64
```

Public API:

```
register_macro_trigger!(t::MacroTrigger)
unregister_macro_trigger!(name::String)
get_macro_trigger(name::String)::Union{Nothing, MacroTrigger}
list_macro_triggers()::Vector{MacroTrigger}
resolve_macro(name::String)::String     # throws if missing/fails
```

**Built-in triggers seeded at module init (phase 1):**

| name           | placeholder    | resolver_id     | notes                   |
|----------------|----------------|-----------------|-------------------------|
| `current_time` | `%TIME%`       | `time_utc`      | `time()` → format       |
| `current_date` | `%DATE%`       | `date_utc`      | `today()` → format      |
| `calc`         | `%CALC%`       | `calc_eval`     | safe arithmetic only    |

`%CALC%` resolution **does not** evaluate user input directly. It pulls
the most recent numeric expression out of the user mission via a tight
regex, evaluates it through a hand-rolled shunting-yard parser
(addition, subtraction, multiplication, division, parentheses, decimals),
and returns the result. **No `Meta.parse`, no `eval`, ever.**

### `Main.jl :: generate_aiml_payload`

After the existing `{TAG}` substitution loop, add a sibling loop:

```
for trigger_name in locked_macros
    trigger = MacroTriggers.get_macro_trigger(trigger_name)
    isnothing(trigger) && continue   # @warn loudly
    resolved = MacroTriggers.resolve_macro(trigger_name)   # may throw
    processed = replace(processed, trigger.placeholder => resolved)
end
```

`locked_macros` is computed inside `ephemeral_aiml_orchestrator` and
stored on `node.json_data["__locked_macros__"]` (or passed via the
`context` arg) so `generate_aiml_payload` can read it without
threading a new parameter through every action family handler.

**Strict-mode handling:** if a `%X%` survives the pass (template
referenced an unlocked macro), default behavior is `@warn` and leave
the placeholder intact in the output. A flag
`MACRO_STRICT_MODE = Ref(false)` flips it to `error`.

---

## Walkthrough: "what is a dog also what time is it?"

End-to-end with no special gate machinery:

| step | actor | result |
|------|-------|--------|
| 1 | normal pipeline | tokenize, lemmatize, pattern bind. `screen_input_complexity` may return mode 1, 2, or 3 — irrelevant to macros. |
| 2 | `cast_vote` for `dog#42` | matches "dog", confidence ≈ 0.42, `macro_signal = ""`. |
| 3 | `cast_vote` for `time#7` | matches "time", confidence ≈ 0.40, `macro_signal = "current_time"` (the node carries it; copied unconditionally to Vote). |
| 4 | `select_aiml_votes` | both clear threshold and fall in top-tier window. Both locked. |
| 5 | orchestrator | `locked_macros = ["current_time"]` (deduped, empty strings dropped). |
| 6 | AIML executive picks template | template has `... and the time is %TIME%.` |
| 7 | `{TAG}` pass | `{MISSION}`, `{PRIMARY_ACTION}`, etc. substituted as today. |
| 8 | new `%X%` pass | `%TIME%` → `resolve_time()` → `"14:32 UTC"`. |
| 9 | reply | both halves rendered. |

Single-input case ("what time is it?"): same flow, `time#7` alone wins,
`locked_macros = ["current_time"]`, macro fires. Simple input, macro
fires.

Single-input case ("what is a dog?"): `time#7` may not even cast (or
casts and loses the cut). Either way, `locked_macros` is empty,
`%X%` pass is a no-op, no macro tax.

Mode-3 doesn't matter to any of this. It's a property of the carrier
node, not the input.

---

## Trade-offs we accept by design

| trade-off                              | rationale                                                |
|----------------------------------------|----------------------------------------------------------|
| Voter node carries one macro at a time | Phase 1 simplicity. Vector upgrade is non-breaking later.|
| Macro fill-in only inside AIML rules   | Single hot spot, single substitution pass, single bug.   |
| No node auto-attach in phase 1         | Keep the user-visible surface explicit before agency.    |
| `%CALC%` is hand-rolled arithmetic     | No `eval`, no remote dependency, no LLM, no surprise.    |
| Strict mode warn-only by default       | Backwards-compat with templates that ref unlocked names. |
| Resolver registry is data-only         | Specimen serialization stays JSON-clean.                 |
| Macro fires on simple OR complex input | Property of the node, not the input. Matches user's directive. |

---

## Phased rollout (concrete deliverables)

### Phase 1 — vertical slice
- `Node.macro_signal`, `Vote.macro_signal`, `VoteCandidate.macro_signal`.
- `MacroTriggers.jl` with built-in `current_time`, `current_date`,
  `calc`.
- Macro propagation in `cast_vote` — unconditional copy from node
  to vote.
- `locked_macros` computed in `ephemeral_aiml_orchestrator` after
  `select_aiml_votes`.
- `%X%` substitution pass in `generate_aiml_payload`.
- Slash commands: `/nodeMacro`, `/nodeMacroClear`, `/macroList`.
- Specimen save/load handles new fields with default-empty fallback.
- Tests:
  - Vote carries macro_signal copied from carrier node
  - locked_macros dedupes across top + sub-top
  - rejected votes' macros do NOT appear in locked_macros
  - `%X%` survives pass when no matching lock (warn)
  - `%X%` resolves cleanly when macro is locked
  - simple-input case: carrier node alone wins → macro fires
  - complex-input case: carrier and pattern node both win → both render
  - non-carrier-only case: no macros locked → `%X%` pass is no-op
  - specimen round-trip preserves macro_signal field

### Phase 2 — remote resolvers
- `RemoteResolverSpec` + `/macroRemote` slash command.
- Built-ins: `weather` (wttr.in), `ip` (api.ipify.org).
- HTTP timeout + per-cycle cache.

### Phase 3 — node agency
- Auto-attach a macro to a top-tier voter when its semantic cues match
  a registered trigger and the node is strong enough on coinflip.
- `/right` reinforcement preserves the macro association; `/wrong`
  decays it on coinflip.

### Phase 4 — semantic auto-suggest
- `Thesaurus.expand_token_set` + `SemanticVerbs.get_verbs_in_class`
  feed cue-class matching so triggers can be expressed as classes
  (e.g. `:temporal_query`) not raw strings.

---

## What I'd defer or skip entirely

- **A separate "macro pass" before action selection** — too invasive,
  duplicates orchestration logic.
- **Macros as their own vote type** — would require a parallel
  `select_aiml_macros` pipeline. Not needed; macros ride existing votes.
- **Putting macro triggers inside `AIMLNodeSystem.jl`** — wrong layer.
  Triggers are world-value resolvers, not executive templates.
- **An LLM-backed resolver** — explicitly off the table per project
  philosophy. No transformer in the loop.
- **Per-lobe macro registries** — phase 1 is global. Per-lobe scoping
  is a phase-4 concern at earliest, and probably never needed.
- **An input-shape gate predicate** — explicitly rejected by the user.
  The macro is a property of the node, not the input. If a voter
  carrying a macro wins, the macro fires.

---

## Risks and mitigations

| risk                                    | mitigation                                                |
|-----------------------------------------|-----------------------------------------------------------|
| Resolver throws inside render path     | wrap each `resolve_macro` in try/catch with `@warn` and leave placeholder intact when not in strict mode |
| Remote API down (phase 2)              | timeout per resolver; cache last-known value in `MacroTrigger`; fall back to `"<unavailable>"` |
| Macro placeholder collides with output text | use double `%` (`%%TIME%%`) if `%TIME%` proves ambiguous in real templates; defer until it bites |
| User registers a macro with `{...}` form | reject at registration with explicit error citing the validator |
| Specimen from old grugbot420 lacks fields | `get(node_dict, "macro_signal", "")` on load |
| Calculator regex grabs the wrong number | restrict to mission text only, not the full message history |
| Macro pass slows render hot path       | pass is `O(locked_macros)` per rule, typically 0–1; negligible vs the existing `replace`-per-tag loop |
| User attaches macro to a node that wins constantly | `/wrong` decays the macro association via existing strength machinery; the user can `/nodeMacroClear` to remove explicitly |

---

## Recommendation

Start phase 1. Keep it boring. The system is well-architected, the hot
spots are obvious, and the macro feature slots in cleanly without
restructuring. With the input-shape gate machinery removed, the slice
is genuinely small.

Two things I want your call on before any code:

1. **Phase 1 built-in resolvers** — `current_time` + `current_date`
   + `calc` enough, or include `weather` in phase 1 so the demo
   landed on the user's "what time is it" example also covers
   "what's the weather"?
2. **Default strict mode** — warn-and-keep-placeholder, or hard-error
   when an unlocked `%X%` survives?
