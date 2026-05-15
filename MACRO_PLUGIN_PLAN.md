# MACRO PLUG-IN PLAN — voter-defined commands with macro action handlers

**Status:** plan only. No code lands until §13 open questions are
resolved.

**Revision history (most recent first):**
- *current* — collapsed cycle-level coherence-gate into voter-pattern-bind.
  Macros are user-defined `COMMANDS` entries. Activation is voter
  pattern-bind; selection is `select_action` weighted coinflip. The macro
  system stops being a parallel gate; the substrate is the gate.
- *prior* — sigil-tagged sum-type variants, JSON registration,
  snap-rounding, meta-arrows. (Most still applies; structure shifted.)
- *prior* — `MacroFact` envelope, two-channel render, organic synthesis
  weaving.
- *initial* — voter-carried macro_signal field, custom coherence gate.

---

## 0. Problem statement

The user wants to extend grugbot420 with a **plug-in macro system** that
lets voter nodes invoke specialized handlers — for things like *current
time*, *math evaluation*, *self-introspection*, *canned responses* —
which produce **organic, naturally-phrased output** woven into the bot's
existing synthesis pipeline rather than template-pasted.

The user's exact final framing of activation: *"macros work the same,
just now you have infinite ways to pattern match activate them."*

The macro system stops being a parallel subsystem with its own
eligibility gate. Macros become **first-class entries in voter
`action_packet`s**. Pattern-bind activates the voter; weighted coinflip
in `select_action` selects the macro action; the existing
`COMMANDS[action]` dispatch runs the user-registered macro handler;
the handler's `MacroFact` flows through the existing two-channel
render. Every pattern-match capability the substrate already has —
lexical, signal-scan, relational, lobe-routed, immune-gated — becomes
an activation path for macros for free.

---

## 1. Code-level reality check (verified against fresh HEAD `598808f`)

### 1.1 Node struct (`engine.jl:433`)

```
mutable struct Node
    id::String
    pattern::String
    signal::Vector{Float64}
    action_packet::String                # ← macros live here as legal entries
    json_data::Dict{String, Any}
    drop_table::Vector{String}
    throttle::Float64
    relational_patterns::Vector{RelationalTriple}
    required_relations::Vector{String}
    relation_weights::Dict{String, Float64}
    strength::Float64
    is_image_node::Bool
    neighbor_ids::Vector{String}
    is_unlinkable::Bool
    is_grave::Bool
    grave_reason::String
    response_times::Vector{Float64}
    ledger_last_cleared::Float64
    hopfield_key::UInt64
    fired_this_cycle::Bool
    voted_this_cycle::Bool
    gained_this_cycle::Bool
    strength_delta_this_cycle::Float64
end
```

**No new field needed for macros.** The `action_packet::String` already
holds the pipe-delimited candidate-action list. Macro action names are
just additional legal entries. See §3.1.

### 1.2 Vote struct (`engine.jl:473`)

```
struct Vote
    node_id::String
    action::String                       # ← carries the chosen macro action verbatim
    confidence::Float64
    negatives::Vector{String}
    user_triples::Vector{RelationalTriple}
    node_triples::Vector{RelationalTriple}
    antimatch::Bool
end
```

**No changes.** When `select_action` rolls the coinflip and picks a
macro entry from the action packet, `Vote.action` holds the raw macro
string (e.g. `"&calculate&(parse math from input)"`). Downstream
`COMMANDS[primary_vote.action]` lookup finds the user-registered
handler.

### 1.3 `cast_vote` (`engine.jl:2850`)

```julia
function cast_vote(id, conf, antimatch, u_trips, n_trips)
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("...")

    winning_action, negatives = select_action(node.action_packet)

    if !haskey(COMMANDS, winning_action)
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! ...")
    end

    bump_strength!(node)
    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch)
end
```

**No changes.** The `COMMANDS` lookup just works once macro handlers
are registered. The fatal error becomes a user-friendly "you tried to
use macro `&X&` but never registered it" — same idiom as the rest of
the engine. See §4 for handler registration.

### 1.4 `parse_action_packet` (`engine.jl:1912`)

The action-packet grammar:

```
"action_name[neg1, neg2]^weight | action_name[neg]^weight | action_name"
```

The action-name regex is `r"^(.+?)\[..."` — non-greedy match before `[`.
A macro entry like `"&calculate&(parse math from input)[don't assume]^2.0"`
parses cleanly: action_name = `"&calculate&(parse math from input)"`,
negatives = `["don't assume"]`, weight = `2.0`.

**Constraint to document:** macro arg-strings must not contain `[`,
`]`, `|`, or `^`. These are action-packet metasyntax. Document and
move on; no parser change needed.

### 1.5 `COMMANDS` registry (`engine.jl:486`, `Main.jl:1666+`)

```julia
const COMMANDS = Dict{String, Function}()
```

Currently populated at module init time with hardcoded action families:

```julia
reason_family   = ["reason", "analyze", "ponder", "calculate"]
greet_family    = ["greet", "welcome", "smile", "laugh"]
survival_family = ["flee", "hide", "fight"]
# ...etc
```

Each family registers handlers with the same closure shape:

```julia
COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> ...
```

The handlers all delegate to `generate_aiml_payload(...)` for the
actual synthesis, with small per-family bookkeeping (throttle reset,
node `json_data` updates).

**This is the integration point.** User-registered macro handlers
land in this same `COMMANDS` dict, with the same closure shape, and
delegate to the same synthesis pipeline. No new dispatch path; no
parallel system.

### 1.6 `select_action` (`engine.jl:2011`)

Weighted coinflip over the parsed action items. Returns
`(winning_action::String, negatives)`. **No changes.**

### 1.7 ATP, triples, EyeSystem, scan tiers

Unchanged. These already feed `CycleContext`-shaped data into the
synthesis layer. Macro handlers can read them via the existing
`node.json_data` and `primary_vote` arguments to the `COMMANDS`
closure, plus a small `CycleContext` bundle (see §6).

### 1.8 `generate_aiml_payload` (`Main.jl:1191`)

The shared synthesis pipeline. Macros become a 4th `support_pieces`
source here (§7b). The existing v7.16 synthesis machinery — action-family
skeletons, claim+support assembly, `_swap_words_in` / `_pick_synonym` —
runs unchanged.

---

## 2. Mental model — macros are user-defined commands

The clean restatement:

> **Every voter node has a `pattern` (what activates it) and an
> `action_packet` (what it can do when it wins).** Pattern-bind handles
> activation. `select_action` picks one of the action packet's entries
> as the winning action. `COMMANDS[winning_action]` is the handler that
> produces output text. **Macros are user-registered entries in
> `COMMANDS`**, with arbitrary internal logic — regex parsers, functor
> calls, thesaurus lookups — composed declaratively at registration
> time.

Three properties this commits to:

1. **No new node type.** Macros do not introduce a new `Node` subclass.
   Voter nodes write macro action names into their action packets like
   any other action.

2. **No cycle-level eligibility gate.** Activation is voter-pattern-bind;
   selection is `select_action` weighted coinflip. If the macro's
   containing voter loses, the macro doesn't fire. The lock-in
   bioavailability concept is subsumed entirely by the voting machinery.

3. **No parallel registry.** `COMMANDS` is the registry. Macro handlers
   live alongside `"reason"`, `"greet"`, etc. The user's `/macro`
   command registers a new `COMMANDS[action_name]` entry built from
   declaratively-composed parts (functor + arg-parser + optional output
   shaper).

### Why this is better than every prior framing

I'd been forcing macros to be a parallel system bolted onto voting:
cycle-level registry iteration, separate eligibility check, separate
dispatcher, separate persistence, separate feedback path. **Every one
of those redundancies disappears under the user-definable-COMMANDS
model**, because `COMMANDS` already has all of it.

| Concern                | Old framing (parallel)                        | New framing (user-defined COMMANDS)                |
|------------------------|-----------------------------------------------|----------------------------------------------------|
| Pattern matching       | Custom multi-modal coherence dispatcher       | **Voter pattern-bind. Same as every other node.**  |
| Eligibility            | Cycle-level registry iteration + coherence    | **`select_action` picks the macro entry. Done.**   |
| Firing predicate       | "Top-tier non-empty" cycle gate               | **Vote lock-in. Same as text-node actions.**       |
| Dedup                  | Per-cycle `MacroFact` cache by name           | **Each macro action is one COMMANDS entry; runs once if selected.** |
| Multiple per cycle     | Awkward "first carrier ferries all"           | **Each top-tier voter contributes whatever its action is, including macro actions.** |
| Reinforcement          | Phase 3 self-tuning of coherence profiles     | **Existing strength/apoptosis/contributor-chain machinery.** |
| Persistence            | New top-level registry section                | **Persist the `/macro` JSON spec list; replay at boot to rebuild COMMANDS entries.** |
| Sigil discipline       | Parser-level type tag                         | **Naming convention for user-registered actions.** |

The macro plug-in becomes a **specialization of the existing command
system**, not a parallel system.

---

## 3. Struct additions — none

**The phase-1 surface area on engine-side mutable state is zero new
fields.** `Node`, `Vote`, `VoteCandidate`, `cast_vote`, `select_action`,
`parse_action_packet` are all unchanged. Specimens loaded from before
this feature lands are forward-compatible with no migration.

The only new module-level state is two new registries inside the new
`MacroTriggers.jl` module (see §4):

```
const RESOLVER_REGISTRY     :: Dict{String, ResolverFn}   # functor implementations
const ARG_PARSER_REGISTRY   :: Dict{String, ArgParserFn}  # arg-string preprocessors
const MACRO_SPEC_REGISTRY   :: Dict{String, MacroSpec}    # JSON specs persisted to specimen
const MACRO_TRIGGER_LOCK    :: ReentrantLock
const MACRO_STRICT_MODE     :: Ref{Bool}                  # default false
```

The `COMMANDS` dict in `engine.jl` is not duplicated — it's extended
by `register_macro!` calls (which add closures into the existing
`COMMANDS`).

### 3.1 `MacroFact` envelope — return type for resolvers

```
struct MacroFact
    placeholder    :: String                          # e.g. "&TIME&"
    semantic_role  :: Symbol                          # e.g. :current_time
    rendered_text  :: String                          # canonical phrasing fallback
    structured     :: Union{Nothing, Dict{String, Any}}   # rich form for synthesis
end
```

- `placeholder` matches the macro's action-name sigil shell
  (`&TIME&` for `&TIME&(args)` invocations).
- `semantic_role` is the small fixed taxonomy synthesis dispatches on
  (see §3.4).
- `rendered_text` is the canonical phrasing — used by §7a rule-board
  substitution. Must be non-empty when the resolver succeeds.
- `structured` is optional. World-value resolvers like `time_utc` fill
  it with parsable parts. Introspection resolvers lean on it heavily
  so synthesis can re-phrase without re-parsing English. Token
  payloads leave it `nothing`.

### 3.2 `MacroSpec` — the persisted JSON-spec record

A `MacroSpec` is what `/macro` registers. It's pure data, serializes
trivially in specimens, and is the recipe from which the substrate
constructs the actual `COMMANDS` closure at registration / specimen-load
time.

```
struct MacroSpec
    action_name   :: String           # e.g. "&calculate&"  (sigil-bracketed; what appears in action_packets)
    placeholder   :: String           # canonical sigil shell — usually equal to action_name without args
    kind          :: Symbol           # :token | :functor | :both | :remote
    fn            :: String           # key into RESOLVER_REGISTRY (used by :functor and :both)
    arg_parser    :: String           # key into ARG_PARSER_REGISTRY (default "passthrough")
    seed_text     :: String           # used by :token and :both; "" otherwise
    notes         :: String           # human-readable description (optional)
end
```

The substrate stores `MacroSpec`s in `MACRO_SPEC_REGISTRY` and uses
each spec to build a `COMMANDS[action_name]` closure (see §4.2).

### 3.3 Resolver and arg-parser signatures

**Resolver functions** (registered in `RESOLVER_REGISTRY`):

```
# functor-mode signature (used by :functor specs):
(parsed_args::Any, ctx::CycleContext) -> MacroFact

# both-mode signature (used by :both specs — receives seed_text + parsed_args):
(seed::String, parsed_args::Any, ctx::CycleContext) -> MacroFact
```

**Arg-parser functions** (registered in `ARG_PARSER_REGISTRY`):

```
# arg-string preprocessor signature:
(arg_string::String, mission::String, primary_vote::Vote) -> Any
```

The arg-parser turns the natural-language arg-string from the action
invocation into whatever shape the resolver expects. This is the
"meta-programming" knob the user named: regex extraction, thesaurus
lookups, topic extraction, math expression discovery, all live behind
a single registry of named preprocessors.

### 3.4 The `semantic_role` taxonomy (phase 1)

Synthesis dispatches on `semantic_role` to choose how a fact is
phrased under each action-family skeleton. Phase-1 set:

| role             | typical resolver       | typical use                            |
|------------------|------------------------|----------------------------------------|
| `:current_time`  | `time_utc`             | "the current time is X"                |
| `:current_date`  | `date_utc`             | "today is X"                           |
| `:calculation`   | `calc_eval`            | "that comes out to X"                  |
| `:self_narrative`| `reflect_self`         | "leaning toward X over Y"              |
| `:mood`          | `mood_summary`         | "feeling X right now"                  |
| `:uncertainty`   | `uncertainty_phrase`   | "fairly confident" / "a bit torn"      |
| `:literal_text`  | (token kind)           | verbatim, no re-phrasing               |

Phase 2 expands with `:current_weather`, `:network_self`,
`:topic_summary`, `:session_age`, plus the arrow-relative roles in
§15. Adding a role is purely additive.

---

## 4. The slash command — `/macro` (JSON registration → COMMANDS entry)

### 4.1 Surface syntax

```
/macro <json_object>
```

The JSON object describes how to **construct a `COMMANDS` handler
closure**. Required and optional fields:

| field         | type   | required for                | meaning                                         |
|---------------|--------|-----------------------------|-------------------------------------------------|
| `action_name` | string | all variants                | sigil-bracketed key into `COMMANDS`. e.g. `"&calculate&"` |
| `kind`        | string | all variants                | one of `"token"`, `"functor"`, `"both"`, `"remote"` |
| `fn`          | string | `functor`, `both`, `remote` | resolver name in `RESOLVER_REGISTRY`            |
| `arg_parser`  | string | optional, defaults `"passthrough"` | preprocessor name in `ARG_PARSER_REGISTRY` |
| `seed_text`   | string | `token`, `both`             | literal seed text                               |
| `url`         | string | `remote` only (phase 2)     | URL template                                    |
| `json_path`   | string | `remote` only (phase 2)     | extraction path                                 |
| `notes`       | string | optional                    | human-readable description                      |

The `action_name` is what voter authors literally type into their
`action_packet` strings. The sigil chars (`%`, `&`, `@`) at the
brackets serve as visual discipline — `%` for token, `&` for functor
(or remote), `@` for both. The substrate enforces sigil ↔ kind
agreement at registration.

### 4.2 What `/macro <json>` does — handler-closure construction

When a `/macro` command runs, the substrate:

1. **Parses the JSON into a `MacroSpec`.** Validates required fields,
   sigil-kind agreement, that `fn` resolves to a registered resolver
   (when applicable), that `arg_parser` resolves to a registered
   parser.
2. **Rejects collisions.** If `action_name` is already a key in
   `COMMANDS` (whether grug-defined or previously user-registered),
   the command is rejected unless `force` flag is set. Same loud-fail
   convention as the rest of the engine.
3. **Stores the `MacroSpec`** in `MACRO_SPEC_REGISTRY` keyed by
   `action_name`. This is the persisted-to-specimen state.
4. **Builds the handler closure** and inserts it into `COMMANDS`:

```julia
function _build_macro_handler(spec::MacroSpec)::Function
    return (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        # 1. Extract arg-string from the action invocation.
        #    primary_vote.action is e.g. "&calculate&(parse math from input)".
        arg_string = _extract_macro_args(primary_vote.action, spec.placeholder)

        # 2. Apply registered arg-parser.
        parser_fn = lock(MACRO_TRIGGER_LOCK) do
            get(ARG_PARSER_REGISTRY, spec.arg_parser, nothing)
        end
        isnothing(parser_fn) && error("!!! FATAL: arg_parser '$(spec.arg_parser)' not registered !!!")
        parsed_args = parser_fn(arg_string, mission, primary_vote)

        # 3. Build CycleContext (see §6).
        ctx = build_cycle_context(mission, node, primary_vote, sure_votes, unsure_votes, all_votes)

        # 4. Call the resolver per kind.
        fact = if spec.kind === :token
            MacroFact(spec.placeholder, :literal_text, spec.seed_text, nothing)
        elseif spec.kind === :functor
            entry = lock(MACRO_TRIGGER_LOCK) do
                get(RESOLVER_REGISTRY, spec.fn, nothing)
            end
            isnothing(entry) && error("!!! FATAL: resolver '$(spec.fn)' not registered !!!")
            entry.fn(parsed_args, ctx)::MacroFact
        elseif spec.kind === :both
            entry = lock(MACRO_TRIGGER_LOCK) do
                get(RESOLVER_REGISTRY, spec.fn, nothing)
            end
            isnothing(entry) && error("!!! FATAL: resolver '$(spec.fn)' not registered !!!")
            entry.fn(spec.seed_text, parsed_args, ctx)::MacroFact
        elseif spec.kind === :remote
            _resolve_remote(spec, parsed_args, ctx)::MacroFact   # phase 2
        else
            error("!!! FATAL: unknown macro kind: $(spec.kind) !!!")
        end

        # 5. Trust but verify.
        isempty(fact.rendered_text) && error("!!! FATAL: resolver '$(spec.fn)' returned empty rendered_text !!!")

        # 6. Funnel through generate_aiml_payload, threading the MacroFact
        #    in as a synthesis input. Two-channel render handles both
        #    rule-board substitution (§7a) and synthesis weaving (§7b).
        return generate_aiml_payload(
            mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data;
            macro_fact = fact
        )
    end
end
```

The closure is a normal function. The substrate inserts it into
`COMMANDS[spec.action_name]`. From `cast_vote`'s perspective, it's
indistinguishable from a grug-defined command.

### 4.3 Examples — one per kind

**Token (`%X%`) — literal text, no computation:**

```
/macro {
  "action_name": "%GREETING%",
  "kind":        "token",
  "seed_text":   "hey there friend",
  "notes":       "canned greeting for casual openers"
}
```

A voter node that writes `"%GREETING%[don't be too formal]^1.5"` into
its action packet uses this. When the voter wins and `select_action`
picks the macro entry, `COMMANDS["%GREETING%"]` runs the closure,
which produces a `MacroFact` with `rendered_text="hey there friend"`,
and the synthesis pipeline weaves it organically.

**Functor (`&X&`) — computation over `CycleContext`:**

```
/macro {
  "action_name": "&TIME&",
  "kind":        "functor",
  "fn":          "time_utc",
  "arg_parser":  "passthrough"
}
```

Voter: `"&TIME&[don't say utc unless asked]^2.0 | reason^1.0"`.

**Both (`@X@`) — seed text plus a transforming functor:**

```
/macro {
  "action_name": "@MOOD_PHRASE@",
  "kind":        "both",
  "seed_text":   "i'm",
  "fn":          "mood_word_for_arousal",
  "arg_parser":  "passthrough"
}
```

Voter: `"@MOOD_PHRASE@(emphasize current state)[don't be melodramatic]^1.5"`.
The both-mode resolver `mood_word_for_arousal` has signature
`(seed::String, parsed_args::Any, ctx::CycleContext) -> MacroFact`.
It might return `MacroFact("@MOOD_PHRASE@", :mood, "$seed wired",
Dict("arousal"=>0.78))`.

**Functor with custom arg-parser — math-from-natural-language:**

```
/macro {
  "action_name": "&calculate&",
  "kind":        "functor",
  "fn":          "calc_eval",
  "arg_parser":  "regex_math_or_thesaurus",
  "notes":       "extracts math expressions from user input incl word forms"
}
```

Voter: `"&calculate&(parse math operation from user input, use thesaurus to identify word-forms)[don't make up numbers]^2.5"`.

The `regex_math_or_thesaurus` arg-parser reads the voter's arg-string
as a directive, looks at the user's mission text, runs a math-shaped
regex pass, falls back to thesaurus number-word resolution, hands the
extracted expression to `calc_eval`. `calc_eval` evaluates safely (no
`Meta.parse`, no `eval`) and returns a `MacroFact` with the result.

### 4.4 Companion slash commands

```
/macro <json>                       # add a new macro handler to COMMANDS
/macroForce <json>                  # add, overriding existing collision
/macroRemove <action_name>          # remove a registered macro (deletes from MACRO_SPEC_REGISTRY and COMMANDS)
/macroList                          # pretty-print all registered MacroSpecs
/argParserList                      # pretty-print registered arg-parsers (read-only in phase 1)
/resolverList                       # pretty-print registered resolvers (read-only in phase 1)
/setMacroStrict on|off              # toggle MACRO_STRICT_MODE
```

All gated by `immune_gate(...)`.

**No `/nodeMacro` or `/nodeMacroClear`.** Macros are not attached to
nodes. They're entries in `COMMANDS` that any voter author can write
into their `action_packet`.

### 4.5 Sigil ↔ kind agreement

Enforced at registration. The `action_name` must have matched
sigil brackets, and the bracketing character must agree with `kind`:

| Sigil pair    | Required kind                        |
|---------------|--------------------------------------|
| `%X%`         | `token`                              |
| `&X&`         | `functor` or `remote`                |
| `@X@`         | `both`                               |

Mismatch is a hard error at registration. The sigil is visual
discipline — voter authors reading a foreign action_packet immediately
know which kind of macro they're looking at.

### 4.6 Action-packet author constraints

Voter authors writing macro entries into action packets must respect:

- **No `[`, `]`, `|`, `^` inside the macro arg-string.** These are
  action-packet metasyntax. The arg-parser receives the arg-string
  verbatim and can do whatever regex/thesaurus work it likes, but
  the action-packet parser must be able to find the entry boundaries.
- **No nested macro invocations.** `&outer&(&inner&(x))` is not
  supported in phase 1. The arg-parser reads the arg-string as
  natural language, not as a recursive macro-language.
- **Action-name uniqueness.** Two macros cannot share an action name.
  Two voters can both reference the same macro action; the registered
  closure runs identically for both.

---

## 5. Activation = voter pattern-bind. (Bioavailability gate removed.)

**The cycle-level bioavailability gate is gone.** Earlier drafts had a
separate post-vote check ("only fire macros if `top_tier` non-empty"),
plus a coherence-eligibility iteration over the registry. Both are
**subsumed entirely by the existing voting machinery**.

The actual flow:

1. **Pattern-bind activates voter nodes** that match the input. Lexical
   patterns, signal scanning, relational triples, neighbor links,
   immune gates, lobe routing, Hopfield familiarity — every existing
   activation pathway works for macros, because macros are just legal
   `action_packet` entries on those voters.

2. **`select_action` picks the winning action** for each activated
   voter via weighted coinflip. If the voter's action_packet contained
   a macro entry, the coinflip might pick it. If picked, `Vote.action`
   carries the macro string verbatim.

3. **`select_aiml_votes` produces `top_tier`, `subtop_tier`,
   `rejected_tier`.** Standard. Macros that ride on rejected-tier
   voters are dropped because their carrier vote is dropped — not
   because of a separate macro gate.

4. **`COMMANDS[primary_vote.action]` dispatches.** If the action is a
   macro, the user-registered closure (§4.2) runs; otherwise a
   grug-defined family handler runs. Either way the synthesis
   pipeline is the same.

5. **Multiple top-tier macros in one cycle.** If two top-tier voters
   each had a different macro action selected, both run during their
   respective `COMMANDS` invocations. The synthesis pipeline weaves
   both `MacroFact`s into the support_pieces stream (§7b). Single-fire
   dedup is automatic — each voter votes once, each macro action runs
   at most once per cycle by virtue of the voting structure.

6. **No cycle-level coherence check.** Coherence-of-input-to-macro is
   handled by the voter's own pattern: if the voter doesn't match the
   input, it doesn't activate, its action_packet is never read, the
   macro never even competes. The substrate's pattern-bind IS the
   coherence gate.

### 5.1 Snap-rounded thresholds (see §17)

Existing voting thresholds (`AIML_TOP_TIER_WINDOW = 0.05`,
`AIML_CONFIDENCE_THRESHOLD = 0.15`) get snap-rounded inputs to
prevent borderline-flicker. This is engine-wide hygiene, not
macro-specific. See §17 for the catalog of snap points.

### 5.2 What the meta-programming feels like to a voter author

The user creates a node like this (existing slash command, unchanged):

```
/createNode "what is 2 plus 2"
  pattern: "what is {NUMBER} plus {NUMBER}"
  action_packet: "&calculate&(extract two number tokens from user input, compute sum)[don't show work unless asked]^2.5 | reason^1.0"
```

The first action_packet entry is a macro invocation. Pattern-bind
matches the input. `select_action` weighted-coinflips between the macro
(weight 2.5) and `reason` (weight 1.0); 71% of the time, the macro
wins. `cast_vote` returns a `Vote` whose action is the macro string.
The macro handler runs, computes the answer, returns a `MacroFact`,
synthesis weaves it into a natural-sounding sentence. Done.

The voter author **never wrote a coherence profile**. The voter's
pattern-bind handled coherence by activating only on matching inputs.
The voter author just **wrote a regular action packet that happened to
include a macro entry**. Identical to writing a normal action packet
with `reason` or `greet`.

---

## 6. CycleContext — the read-only bundle resolvers consume

`CycleContext` is the bundle of cycle-level signals that resolvers
read when computing their `MacroFact`. It's not an eligibility gate;
it's a **convenience read-only handle** so functors don't have to
reach into a dozen module globals.

### 6.1 Struct shape

```
struct CycleContext
    mission             :: String
    scan_mode           :: Int                          # 1 | 2 | 3
    prediction          :: PredictionResult             # ATP top-pick + distributions
    basic_triples       :: Vector{RelationalTriple}
    dynamic_triples     :: Union{Nothing, Vector{RelationalTriple}}    # mode 3 only
    arousal             :: Float64                      # EyeSystem.get_arousal()
    primary_vote        :: Vote
    sure_votes          :: Vector{Vote}
    unsure_votes        :: Vector{Vote}
    verb_classes_seen   :: Set{String}                  # cached lookup over input verbs
    lemma_classes_seen  :: Set{String}                  # cached lookup over input lemmas
    triple_object_classes :: Set{String}                # cached classification over triple objects
    cycle_counter       :: Int                          # monotonic across cycles
end
```

### 6.2 Built where, lazily

`build_cycle_context(...)` is called inside the macro handler closure
(§4.2). It's called once per macro-action invocation, so a cycle with
two distinct macro actions builds the context twice — but each build
is cheap (it reads cached values from already-computed engine state).
A future optimization can memoize per-cycle, but phase 1 doesn't bother.

### 6.3 Read by resolvers, never by the substrate

The substrate doesn't dispatch on `CycleContext` fields. Only resolver
implementations read them. Multi-modal coherence machinery
(`action_family`, `tone_family`, `verb_class`, `lemma_class`,
`arousal`, `triple_object_class`) becomes **optional internal tooling**
that resolver authors can use to phrase their `MacroFact` based on
input shape — not a system-level gate that decides whether the macro
fires.

For example, `mood_summary` reads `ctx.arousal` to pick a mood word.
`reflect_self` reads `ctx.recent_lobe_paths` (phase 2). `calc_eval`
reads `ctx.mission` to find the math expression. None of these reads
gate firing — firing was already decided by the voter's pattern-bind.

### 6.4 The deferred multi-modal helpers (phase 2)

The earlier multi-modal coherence dispatcher (`af:`, `tf:`, `vc:`,
`lc:`, `ar:`, `to:` modality checks) is **deferred to phase 2**. When
it lands, it ships as a *helper library for resolver authors* — a set
of functions that take `CycleContext` and a modality spec, return
boolean. Resolvers that want to behave differently based on input
shape can use it; resolvers that don't, don't.

Example phase-2 helper:

```julia
# (phase 2) optional helper for resolver authors
function modality_matches(ctx::CycleContext, source::Symbol, want)::Bool
    # ...as previously specced...
end

# usage in a phase-2 resolver:
function fancy_time_resolver(args, ctx)::MacroFact
    if modality_matches(ctx, :tone_family, [:TONE_URGENT])
        return MacroFact("&TIME&", :current_time, "$(_now()) — and we're running late", ...)
    else
        return MacroFact("&TIME&", :current_time, "$(_now())", ...)
    end
end
```

Phase 1 ships without this helper; resolvers do whatever inline logic
they want over `CycleContext`.

---

## 7. The render pass — `MacroFact` flows through synthesis

The two-channel render is unchanged from the prior plan revision. The
only difference: `MacroFact` arrives at synthesis through the
`generate_aiml_payload` keyword argument `macro_fact`, set by the macro
handler closure (§4.2), instead of via a separate `locked_macros` list.

### 7.1 The user's "normal sentence" requirement

> *"if you asked me what a dog is and what time it is. i wouldnt have
> preset response structures id just say it in a normal sentence."*

A naive `replace(template, "&TIME&" => "14:32 UTC")` produces output
like *"the time is 14:32 UTC"* glued onto whatever rule text fired.
That's fine for rule-board directives but wrong for the spoken spine
of the response.

So `MacroFact` is consumed by **two channels in the same render pass**:

| | §7a Rule-board channel | §7b Synthesis weaving channel |
|---|---|---|
| Where it lands | `[Directives: …]` tail of AIML payload | The spoken spine, woven into `support_pieces` |
| What it consumes | `MacroFact.rendered_text` | `MacroFact` as a whole (role + structured) |
| Operation | `replace(rule_text, "&TIME&" => fact.rendered_text)` | `_macro_fact_to_clause(fact, action_family)` → routed through `_swap_words_in` alongside triples / companion patterns / UNSURE hedges |
| Shape of output | Template-like, fine for directive tail | Organic clause, joins synthesis at `Main.jl:1497–1527` |
| Purpose | Lets rule authors write `"the time is &TIME&"` if they want | Default behaviour: macros become a 4th `support_pieces` source |

### 7.2 Stage A — rule-board substitution (§7a)

Inside `generate_aiml_payload`'s per-rule loop, after the existing
`{TAG}` substitutions and before `push!(evaluated_rules, processed)`:

```julia
# Channel §7a: rule-board template substitution.
if !isnothing(macro_fact)
    processed = replace(processed, macro_fact.placeholder => macro_fact.rendered_text)
end

# Strict-mode survivor check.  Regex matches all three sigil shapes.
const _MACRO_SIGIL_RE = r"[%&@][A-Z_]+[%&@]"

if MacroTriggers.MACRO_STRICT_MODE[]
    surviving = collect(eachmatch(_MACRO_SIGIL_RE, processed))
    surviving = filter(m -> first(m.match) == last(m.match), surviving)
    if !isempty(surviving)
        error("!!! FATAL: unresolved macro placeholders survived render: $(join([m.match for m in surviving], \", \")) !!!")
    end
else
    for m in eachmatch(_MACRO_SIGIL_RE, processed)
        first(m.match) == last(m.match) || continue
        @warn "[MACRO] unresolved placeholder $(m.match) left intact (strict mode off)"
    end
end

push!(evaluated_rules, processed)
```

What this preserves:

1. **Per-rule fire-probability gating preserved.** Rules that lost
   `rand() > rule.fire_probability` `continue`d before reaching the
   macro pass.
2. **Strict-mode survivor check.** Catches rule-board templates that
   reference unregistered macro placeholders.

### 7.3 Stage B — synthesis weaving (§7b)

After `evaluated_rules` is built, inside the synthesis pipeline at
`Main.jl:1497–1527` where `support_pieces` is assembled:

```julia
# Channel §7b: synthesis weaving.  Macros become a 4th support_pieces source.
if !isnothing(macro_fact) && macro_fact.semantic_role !== :unavailable
    clause = _macro_fact_to_clause(macro_fact, action_family)
    if !isempty(clause)
        woven = _swap_words_in(clause, swap_ctx)
        push!(support_pieces, woven)
    end
end
```

`_swap_words_in` is the existing v7.16 synonym + inhibition router. It
runs the candidate clause through `Thesaurus.synonym_for`,
`SemanticVerbs.synonyms_for`, the AIML drop_table, and InputQueue
inhibitions. Output reads varied across cycles, not parroted.

### 7.4 The skeleton-aware phrasing dispatcher

```julia
function _macro_fact_to_clause(fact::MacroFact, action_family::Symbol)::String
    role = fact.semantic_role
    txt  = fact.rendered_text
    s    = fact.structured

    if role === :current_time
        af = action_family
        if af === :ACTION_QUERY     return "it's $txt right now"
        elseif af === :ACTION_INFORM   return "the clock reads $txt"
        elseif af === :ACTION_COMMAND  return "as of $txt"
        else                            return "right now it's $txt"
        end
    elseif role === :current_date
        return action_family === :ACTION_QUERY ? "today is $txt" : "as of $txt"
    elseif role === :calculation
        expr = isnothing(s) ? "" : get(s, "expression", "")
        return isempty(expr) ? "that comes out to $txt" : "$expr equals $txt"
    elseif role === :self_narrative
        return txt   # already sentence-shaped
    elseif role === :mood
        return "i'm feeling $txt"
    elseif role === :uncertainty
        return txt   # already sentence-shaped
    elseif role === :literal_text
        return txt   # canned text — drop in as-is
    else
        return txt   # unknown role: degrade gracefully
    end
end
```

Three things to note:

1. **No JSON-template scaffolding.** Output is a clause fragment.
   Synthesis handles capitalization, punctuation, joining via the same
   path triples and companion patterns already use.
2. **Action-family branching is shallow on purpose.** Phase 1 covers
   QUERY/INFORM/COMMAND only; other families fall through to a sane
   default. Phase 2 expands per-family per role.
3. **`:self_narrative`, `:uncertainty`, `:literal_text` pass-through.**
   Their resolvers already produce sentence-shaped output; the
   dispatcher hands them straight to `_swap_words_in`.

### 7.5 Conflict between §7a and §7b

If a rule-board template explicitly contains `&TIME&`, §7a substitutes
it inline. The same `MacroFact` *also* gets woven into `support_pieces`
by §7b. The rule-board tail will mention the time, AND the spoken
spine may also reference it. **This is acceptable** — matches the
"say things twice in different shapes" pattern v7.16 synthesis already
produces (claim + supporting triple often restate the same idea).

Phase 2 can add `MacroSpec.suppress_in_synthesis::Bool` to opt a
trigger out of §7b.

---

## 8. Built-in resolvers and arg-parsers — `AIMLResolvers.jl`

A new module containing the phase-1 set of registered functors and
arg-parsers.

### 8.1 Resolvers (registered in `RESOLVER_REGISTRY`)

```julia
module AIMLResolvers
using Dates
using ..MacroTriggers: MacroFact, CycleContext

# === Category A: world-value =============================================

function time_utc(args, ctx::CycleContext)::MacroFact
    n  = now(UTC)
    return MacroFact("&TIME&", :current_time, Dates.format(n, "HH:MM \"UTC\""),
                     Dict{String,Any}("hh"=>Dates.hour(n), "mm"=>Dates.minute(n), "tz"=>"UTC"))
end

function date_utc(args, ctx::CycleContext)::MacroFact
    t = today()
    return MacroFact("&DATE&", :current_date, Dates.format(t, "yyyy-mm-dd"),
                     Dict{String,Any}("y"=>Dates.year(t), "m"=>Dates.month(t), "d"=>Dates.day(t)))
end

function calc_eval(args, ctx::CycleContext)::MacroFact
    # `args` is the parsed expression string from the arg-parser.
    # Hand-rolled shunting-yard. NEVER calls Meta.parse, NEVER calls eval.
    expr_str = args isa String ? args : string(args)
    if isempty(expr_str)
        return MacroFact("&CALC&", :calculation, "<no expression found>",
                         Dict{String,Any}("expression"=>"", "result"=>nothing))
    end
    result = _safe_arithmetic(expr_str)
    return MacroFact("&CALC&", :calculation, string(result),
                     Dict{String,Any}("expression"=>expr_str, "result"=>result))
end

# === Category B: self-introspective =====================================

function reflect_self(args, ctx::CycleContext)::MacroFact
    fragment = _summarize_recent_self(ctx)
    return MacroFact("&REFLECT&", :self_narrative, fragment, Dict{String,Any}())
end

function mood_summary(args, ctx::CycleContext)::MacroFact
    arousal = ctx.arousal
    word = arousal > 0.7 ? "wired"   :
           arousal > 0.5 ? "engaged" :
           arousal > 0.3 ? "even"    :
                           "low-key"
    return MacroFact("&MOOD&", :mood, word, Dict{String,Any}("arousal"=>arousal))
end

function uncertainty_phrase(args, ctx::CycleContext)::MacroFact
    conf = ctx.primary_vote.confidence
    fragment = conf > 0.6  ? "i'm fairly sure"           :
               conf > 0.4  ? "i think"                   :
               conf > 0.25 ? "i'm not totally sure but"  :
                             "honestly i'm guessing here"
    return MacroFact("&UNCERTAINTY&", :uncertainty, fragment,
                     Dict{String,Any}("confidence"=>conf))
end

# === Category C: both-mode ==============================================

function mood_word_for_arousal(seed::String, args, ctx::CycleContext)::MacroFact
    arousal = ctx.arousal
    word = arousal > 0.7 ? "wired"   :
           arousal > 0.5 ? "engaged" :
           arousal > 0.3 ? "even"    :
                           "low-key"
    return MacroFact("@MOOD_PHRASE@", :mood, "$seed $word",
                     Dict{String,Any}("arousal"=>arousal, "seed"=>seed))
end

end # module
```

### 8.2 Arg-parsers (registered in `ARG_PARSER_REGISTRY`)

```julia
function passthrough_parser(arg_string::String, mission::String, primary_vote::Vote)
    return arg_string   # give the resolver the raw arg-string verbatim
end

function none_parser(arg_string::String, mission::String, primary_vote::Vote)
    return nothing      # discard arg-string, resolver gets only ctx
end

function regex_math_or_thesaurus_parser(arg_string::String, mission::String, primary_vote::Vote)
    # 1. Try direct math regex on the user mission.
    direct = _extract_math_regex(mission)
    !isnothing(direct) && return direct

    # 2. Fall back to thesaurus number-word resolution.
    converted = _resolve_number_words(mission)
    !isnothing(converted) && return _extract_math_regex(converted)

    return ""   # let calc_eval handle the empty case
end

function extract_topic_parser(arg_string::String, mission::String, primary_vote::Vote)
    # Find the topic the user is asking about.  Phase 1: pluck the first
    # noun-phrase from the cycle's basic triples.
    return _first_subject_or_object(primary_vote.user_triples)
end
```

The four phase-1 starter parsers cover the main shapes: raw-passthrough,
discard, math-from-natural-language, topic-extraction. Phase 2 lets users
register their own arg-parsers via a separate slash command.

### 8.3 Registration — `MacroTriggers.__init__()`

```julia
function __init__()
    lock(MACRO_TRIGGER_LOCK) do
        # Resolvers
        RESOLVER_REGISTRY["time_utc"]              = FunctorResolver(AIMLResolvers.time_utc)
        RESOLVER_REGISTRY["date_utc"]              = FunctorResolver(AIMLResolvers.date_utc)
        RESOLVER_REGISTRY["calc_eval"]             = FunctorResolver(AIMLResolvers.calc_eval)
        RESOLVER_REGISTRY["reflect_self"]          = FunctorResolver(AIMLResolvers.reflect_self)
        RESOLVER_REGISTRY["mood_summary"]          = FunctorResolver(AIMLResolvers.mood_summary)
        RESOLVER_REGISTRY["uncertainty_phrase"]    = FunctorResolver(AIMLResolvers.uncertainty_phrase)
        RESOLVER_REGISTRY["mood_word_for_arousal"] = BothResolver(AIMLResolvers.mood_word_for_arousal)

        # Arg-parsers
        ARG_PARSER_REGISTRY["passthrough"]              = passthrough_parser
        ARG_PARSER_REGISTRY["none"]                     = none_parser
        ARG_PARSER_REGISTRY["regex_math_or_thesaurus"]  = regex_math_or_thesaurus_parser
        ARG_PARSER_REGISTRY["extract_topic"]            = extract_topic_parser

        # Seed phase-1 built-in macros into MACRO_SPEC_REGISTRY and COMMANDS.
        register_macro!(MacroSpec("&TIME&",         "&TIME&",         :functor,
                                   "time_utc",      "passthrough",    "", ""))
        register_macro!(MacroSpec("&DATE&",         "&DATE&",         :functor,
                                   "date_utc",      "passthrough",    "", ""))
        register_macro!(MacroSpec("&CALC&",         "&CALC&",         :functor,
                                   "calc_eval",     "regex_math_or_thesaurus", "", ""))
        register_macro!(MacroSpec("&REFLECT&",      "&REFLECT&",      :functor,
                                   "reflect_self",  "passthrough",    "", ""))
        register_macro!(MacroSpec("&MOOD&",         "&MOOD&",         :functor,
                                   "mood_summary",  "passthrough",    "", ""))
        register_macro!(MacroSpec("&UNCERTAINTY&",  "&UNCERTAINTY&",  :functor,
                                   "uncertainty_phrase", "passthrough", "", ""))
    end
end
```

### 8.4 New verb / lemma classes

Five small additions to existing registries:

| Class                       | Where                                | Members (phase 1)                                                  |
|-----------------------------|--------------------------------------|--------------------------------------------------------------------|
| `arithmetic` (verb_class)   | `SemanticVerbs.jl` default registry  | `add`, `subtract`, `multiply`, `divide`, `equals`, `compute`, `calculate`, `plus`, `minus`, `sum` |
| `temporal` (verb_class)     | `SemanticVerbs.jl` default registry  | augment with `tell`, `know`, `say`                                 |
| `numeric` (lemma_class)     | thesaurus / patternscanner side      | digits, number words `one`–`twenty`, decimal markers               |
| `self_pronoun` (lemma_class)| thesaurus / patternscanner side      | `i`, `me`, `myself`, `you`, `your`                                 |
| `affect_word` (lemma_class) | thesaurus / patternscanner side      | `feel`, `feeling`, `mood`, `vibe`, `okay`, `alright`               |

These strengthen existing semantic signals even without macros. Phase
1 adds them so phase-2 resolver helpers (the multi-modal helpers in
§6.4) have richer signals to read.

---

## 9. /right and /wrong feedback

No new feedback math.

- A vote that contributed to output is a contributor (existing
  machinery). If the vote's action was a macro, the carrier node is
  reinforced exactly the same way it would be if the action were
  `"reason"` or `"greet"`.
- `/wrong` decays the contributor list. Persistent failure of a
  particular voter that always picks a macro from its action_packet
  causes that voter's strength to decay through the existing apoptosis
  pathway.
- **Macro-handler-internal failures** (e.g. the resolver throws): the
  closure either rethrows under strict mode, or returns a
  graceful-degradation `MacroFact` with `semantic_role=:unavailable`
  under non-strict mode. Either way, the carrier vote isn't punished
  for handler bugs — only the user's `/wrong` flag does that.

---

## 10. Persistence — specimen save/load

The persistent macro state is **the list of `/macro` JSON specs**.
Closures don't serialize, so the substrate persists the recipes
(`MacroSpec` records) and re-builds the closures on boot.

Three touchpoints:

1. **`MACRO_SPEC_REGISTRY`** — serialized as a top-level array in
   the specimen JSON, alongside existing top-level sections (verb
   registry, synonym map, AIML drop table, etc.). Each spec serializes
   trivially (only strings and a symbol).

2. **`RESOLVER_REGISTRY`** — **NEVER serialized**. It contains
   `Function` values; closures aren't specimen-clean. Resolvers are
   re-bound at boot from `AIMLResolvers.__init__()`. Phase-2 remote
   resolvers re-bind from their stored `RemotePayload` descriptor (URL
   + JSON path), which IS serialized as part of the spec.

3. **`ARG_PARSER_REGISTRY`** — NEVER serialized, same reason.
   Re-bound at boot. Phase 2 lets users register their own arg-parsers,
   at which point the *user-level recipe* (a small DSL?) becomes
   persistable while the *function* still re-binds at boot.

**`COMMANDS`** is rebuilt at boot:

```julia
function rebuild_macro_commands_from_specs!()
    lock(MACRO_TRIGGER_LOCK) do
        for spec in values(MACRO_SPEC_REGISTRY)
            COMMANDS[spec.action_name] = _build_macro_handler(spec)
        end
    end
end
```

Called from boot after `AIMLResolvers.__init__()` has populated the
resolver and arg-parser registries.

If a specimen loaded from disk references a `fn` or `arg_parser` that
isn't registered (e.g. resolver was renamed), the closure-build throws
at registration time — caught and reported as a loud-but-non-fatal
warning, the spec is dropped from `MACRO_SPEC_REGISTRY`, the user is
told. **Loud failure preferred over silent corruption.**

**Forward compatibility:** specimens saved before this feature lands
have no `MACRO_SPEC_REGISTRY` section; the loader treats that as
"registry starts with phase-1 built-ins seeded by `__init__()`". No
node-level migration is needed — `Node` and `Vote` are unchanged.

---

## 11. Phased rollout — concrete deliverables

### Phase 1 (the vertical slice)

**Files touched:**
- `engine.jl` — **no struct changes.** Add `_snap` / `_snap_to_any`
  helpers (§17) and insert snap calls at the bioavailability /
  top-tier-window / apoptosis comparison sites.
- `Main.jl :: generate_aiml_payload` — add optional `macro_fact`
  keyword argument; thread it through the per-rule loop (§7.2) and
  into the synthesis weaving point (§7.3); add `_macro_fact_to_clause`
  dispatcher.
- `SemanticVerbs.jl` — add `arithmetic` verb class default; augment
  `temporal`.
- `patternscanner.jl` (or new helper) — add `numeric`, `self_pronoun`,
  `affect_word` lemma classes.
- New file `MacroTriggers.jl` — `MacroFact`, `MacroSpec`,
  `CycleContext`, `RESOLVER_REGISTRY`, `ARG_PARSER_REGISTRY`,
  `MACRO_SPEC_REGISTRY`, `register_macro!`, `_build_macro_handler`,
  `_extract_macro_args`, `rebuild_macro_commands_from_specs!`.
- New file `AIMLResolvers.jl` — phase-1 resolvers (§8.1) and
  arg-parsers (§8.2) with their `__init__()` registration.
- `GrugBot420.jl` — include the two new files between `engine.jl`
  and `AIMLNodeSystem.jl`.

**Slash commands:**
- `/macro <json>`, `/macroForce <json>`, `/macroRemove <action_name>`
- `/macroList`, `/argParserList`, `/resolverList`
- `/setMacroStrict on|off`

**Tests:**
- `cast_vote` accepts a macro action when registered; throws when not.
- `select_action` weighted-coinflips between macro and non-macro
  entries with correct weight ratios.
- Macro-handler closure correctly extracts args, dispatches to
  resolver, threads `MacroFact` into synthesis.
- §7a substitution lands `rendered_text` in rule-board templates.
- §7b synthesis weaving lands clause in `support_pieces`.
- Single voter with multiple action_packet entries — macro wins
  coinflip, non-macro wins coinflip, behaviour correct in both cases.
- Multiple voters with different macros — both run, both `MacroFact`s
  woven into output.
- Sigil-kind agreement enforced at registration.
- Action-name collision rejected unless `/macroForce`.
- Specimen round-trip: `/macro {...}`, save, load, voter activates,
  macro fires same way.
- `&CALC&` resolver: `"what is 12 * (3 + 4)"` returns `"84"`. NEVER
  calls `Meta.parse` or `eval`.
- `regex_math_or_thesaurus` arg-parser: `"two plus two"` → resolves
  to `"2+2"` via thesaurus → calc_eval → `"4"`.
- Strict mode: unresolved sigil placeholder in rule-board throws;
  non-strict warns and leaves intact.
- Snap-rounding: confidence values 0.149, 0.150, 0.151 all snap to
  0.15 and produce the same gate decision.

### Phase 2 — remote resolvers, multi-modal helpers, arrow-relative roles

- `:remote` kind for HTTP-backed resolvers (URL template +
  JSON-path extraction + per-cycle cache + hard timeout).
- `weather_wttr`, `ip_self`, etc. resolvers.
- The multi-modal helpers (`modality_matches(ctx, source, want)`)
  shipped as a library for resolver authors (§6.4).
- Arrow-relative semantic roles (§15.3): `:elapsed_cycles`,
  `:strength_shift`, `:habituation_level`, `:confidence_shift`,
  `:recency_position`, `:topic_drift`, `:commitment_age`. Requires
  the engine-level delta plumbing in `RELATIONAL_DELTA_NOTES.md`
  (separate plan doc, not yet written).

### Phase 3 — user-defined arg-parsers

- `/argParser <json>` to register user-defined arg-parsers via a
  small declarative DSL (regex extraction + thesaurus ops + topic
  pulls). Lets users compose new pre-processing pipelines without
  writing Julia.

### Phase 4 — semantic auto-suggest

- `Thesaurus.expand_token_set` + `SemanticVerbs.get_verbs_in_class`
  feed cue-class matching so a `vc:temporal` modality automatically
  expands to all verbs in the temporal class without user
  maintenance.

---

## 12. What this plan deliberately rejects

- **A new `Node` subtype for macros.** Macros are not a node type. They
  are user-registered entries in `COMMANDS`, dispatched via the same
  `cast_vote` → `select_action` → `COMMANDS[action]` pipeline that
  every other action uses.
- **A cycle-level macro registry iteration.** Activation is voter
  pattern-bind, not a separate eligibility loop over registered
  macros. The substrate's pattern-bind IS the eligibility filter.
- **A custom multi-modal coherence dispatcher as a system gate.** The
  multi-modal machinery becomes optional internal tooling for
  resolver authors (phase 2), not a system-level eligibility gate.
- **Per-node `macro_signal` field.** Macros are written into voter
  `action_packet`s as legal action-name entries. No per-node
  attachment, no parallel field.
- **Template-paste output.** Macros never produce rigid sentence
  structures. The two-channel render (§7) routes `MacroFact`s through
  the existing organic synthesis pipeline.
- **`Meta.parse` / `eval` for math.** `calc_eval` uses a hand-rolled
  shunting-yard, never Julia's evaluator.

---

## 13. Open questions still requiring sign-off before code

1. **Phase 1 resolver scope.** Phase 1 ships SEVEN resolvers:
   `time_utc`, `date_utc`, `calc_eval`, `reflect_self`, `mood_summary`,
   `uncertainty_phrase`, `mood_word_for_arousal`. Confirm scope, or
   trim if any of `reflect_self` / `mood_summary` need engine-level
   plumbing not yet present.

2. **Default strict mode.** Warn-and-keep-placeholder, or hard-error,
   when an unlocked sigil placeholder survives the §7a substitution
   pass? The doc defaults to warn.

3. **New verb / lemma classes.** §8.4 lists five additions
   (`arithmetic`, `temporal` aug, `numeric`, `self_pronoun`,
   `affect_word`). Confirm all five land in phase 1, or defer the
   introspection-related ones along with the introspection resolvers.

4. **`CycleContext` build location.** Inside the macro handler closure
   (§4.2 step 3), or at `process_mission` top with caching for re-use?
   Phase 1 does it inside the closure (cheap, no caching needed).

5. **§7b unconditional weaving.** Phase 1 weaves every macro
   `MacroFact` into `support_pieces`. Should `MacroSpec` carry an
   optional `suppress_in_synthesis::Bool` for triggers whose §7a
   placement is sufficient?

6. **`_macro_fact_to_clause` template breadth.** Phase 1 covers 6
   semantic roles × 3 most-common action families ≈ ~20 templates.
   Other action families fall through to a generic clause. Confirm
   that's acceptable as the phase-1 ceiling.

7. **AIMLNodeSystem-level macros.** Out of scope. This plan attaches
   macros to **voter `Node`s only** via their action_packet. AIML
   nodes don't have action_packets in the same sense. Confirm that's
   still the model.

8. **User-defined arg-parsers in phase 1?** Phase 1 ships the four
   built-in arg-parsers and a read-only `/argParserList`. Adding
   `/argParser <json>` for user-defined parsers is deferred to phase
   3. Confirm phase deferral.

---

## 14. Quick-reference change-summary table

| location                                  | change                                                                                                  |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `engine.jl`                               | **no struct changes.** `Node`, `Vote`, `cast_vote`, `select_action`, `parse_action_packet` untouched.   |
| `engine.jl` (snap helpers, §17)           | + `_snap` and `_snap_to_any` helpers; insert at bioavailability / top-tier / apoptosis comparison sites |
| `VoteOrchestrator.jl`                     | **no changes.**                                                                                         |
| `Main.jl :: generate_aiml_payload`        | + optional `macro_fact::Union{Nothing,MacroFact}` keyword arg; §7a inline substitution; §7b synthesis weaving at line ~1497–1527 |
| `Main.jl :: _macro_fact_to_clause`        | NEW skeleton-aware phrasing dispatcher (~20 templates, 6 roles × QUERY/INFORM/COMMAND)                  |
| `Main.jl` (slash command parser)          | JSON parser for `/macro` + `/macroForce`; literal matchers for `/macroRemove`, `/macroList`, `/argParserList`, `/resolverList`, `/setMacroStrict`. **No `/nodeMacro` / `/nodeMacroClear`.** |
| `SemanticVerbs.jl`                        | + `arithmetic` verb class default; `temporal` augmentation                                              |
| `patternscanner.jl` (or new helper)       | + `numeric`, `self_pronoum`, `affect_word` lemma classes                                                |
| **NEW** `MacroTriggers.jl`                | `MacroFact`, `MacroSpec`, `CycleContext`, `RESOLVER_REGISTRY`, `ARG_PARSER_REGISTRY`, `MACRO_SPEC_REGISTRY`, `register_macro!`, `_build_macro_handler`, `_extract_macro_args`, `rebuild_macro_commands_from_specs!` |
| **NEW** `AIMLResolvers.jl`                | `time_utc`, `date_utc`, `calc_eval`, `reflect_self`, `mood_summary`, `uncertainty_phrase`, `mood_word_for_arousal`, plus `__init__()` that seeds phase-1 specs into `MACRO_SPEC_REGISTRY` and `COMMANDS` |
| `GrugBot420.jl`                           | include `MacroTriggers.jl` + `AIMLResolvers.jl` between `engine.jl` and `AIMLNodeSystem.jl`              |
| Specimen JSON                             | + top-level `MACRO_SPEC_REGISTRY` section (specs persist; closures rebuild on boot)                     |

---

*End of plan. No code lands until §13 open questions are resolved.
Architecturally settled: macros are user-defined `COMMANDS` entries;
activation is voter pattern-bind; selection is `select_action`
weighted coinflip; dispatch is `COMMANDS[action]` exactly as for
grug-defined actions. The substrate's existing pattern-bind /
voting / lock-in / contributor / persistence / feedback machinery
handles macros for free. The macro-specific machinery is purely
render-time: `MacroFact` envelope, two-channel render
(§7a rule-board substitution + §7b synthesis weaving), six phase-1
resolvers spanning world-value / introspection / both-mode, four
phase-1 arg-parsers covering passthrough / discard / math-extraction
/ topic-extraction.*

---

## 15. Relational delta and meta-arrows

**This section is conceptual scaffolding, not a code change.** It
names the principle the engine is already enacting and pre-lists the
phase-2 resolver roles that will expose it.

### 15.1 The relational-delta principle

Every meta-concept the engine cares about — time, knowledge, identity,
context, evaluation, commitment — is *a delta between two states of
the same relational field*, not an absolute position. The arrow exists
because the delta has a preferred sign at the boundary conditions even
though the substrate rules are symmetric.

This is the same trick a transformer uses, with two differences:

| Transformer                                  | grugbot420                                                       |
|----------------------------------------------|------------------------------------------------------------------|
| Soft attention over fixed token positions    | Voter pattern-bind + weighted-coinflip selection over evolving concepts |
| Multi-head, each head reading one projection | Multi-modal helpers (phase 2), each modality reading one semantic subsystem |
| Differentiable softmax weights               | Threshold-gated discrete locks-in (with snap-rounding, §17)      |
| Residual stream                              | Node strength accumulating across cycles                         |
| Layer-N → Layer-N+1 delta                    | Cycle-N → Cycle-N+1 lobe-path delta                              |
| Position encoding                            | InputQueue recency + cycle counter                               |
| Gradient backprop                            | `/right` / `/wrong` strength shifts (local, not global)          |

**Where grugbot diverges by design:**

- **Discrete identity per concept.** `dog#42` has a name and a history.
- **Hard forgetting via apoptosis.** Strength → 0 → grave is real
  deletion.
- **Refusal to commit.** No top-tier lock-in → no fire (or UNSURE
  hedge).
- **Reorganizable substrate.** Nodes spawn, link, die.
- **Nonlinear gates.** Threshold-and-snap, not smooth sigmoid.

### 15.2 Meta-arrows the engine already implicitly tracks

| Meta-arrow                  | Where it lives in current code                                                  |
|-----------------------------|---------------------------------------------------------------------------------|
| **Time**                    | Cycle counter, recency-weighted recent-lobe-paths, InputQueue token decay      |
| **Knowledge / information** | Node strength accumulating, contributor lists growing, drop_table learning     |
| **Commitment / decision**   | Vote → lock-in pipeline; once `cast_vote` fires, the vote is recorded          |
| **Identity / individuation**| Nodes refining over their lifetime; apoptosis as the only de-individuation     |
| **Context / habituation**   | InputQueue inhibitions (recently-said-words get suppressed)                    |
| **Evaluation**              | `/right` / `/wrong` shifting strength                                          |
| **Causation**               | Contributor chains: votes that contributed to output are recorded as upstream  |

### 15.3 Phase-2 arrow-relative resolver roles

| role                     | snapshot or delta            | typical use                                        |
|--------------------------|------------------------------|----------------------------------------------------|
| `:elapsed_cycles`        | delta                        | "a few cycles back you said X"                     |
| `:strength_shift`        | delta                        | "i've been warming up to that idea"                |
| `:habituation_level`     | snapshot of delta-history    | "i've been thinking about that a lot lately"      |
| `:confidence_shift`      | delta                        | "i used to be more sure"                           |
| `:recency_position`      | snapshot near head of arrow  | "you just mentioned X"                             |
| `:topic_drift`           | delta                        | "we were on Y, now we're on X"                     |
| `:commitment_age`        | delta                        | "i decided that a while ago"                       |

Each delta resolver returns a `MacroFact` whose `structured` carries
the **numeric delta** but whose `rendered_text` is **qualitative**
("a while ago", "warming up", "lately"). The fuzzy-nonlinear character
pays off here: the user never sees a number, just the arrow's
direction projected into language.

### 15.4 Engine-level prerequisite (deferred)

Implementing arrow-relative resolvers requires lightweight delta
plumbing in the engine — minimally `previous_strength` on `Node`,
`previous_inhibition` on InputQueue tokens, and a `deltas` sub-bundle
on `CycleContext`. **This is a separate plan doc** (working title:
`RELATIONAL_DELTA_NOTES.md`) to be written when phase 2 starts. It
isn't on the phase-1 critical path.

---

## 16. Sigils — visual discipline for user-defined action names

The three sigils are no longer parser-level type tags (the JSON
`kind` field carries the variant). They are **visual conventions for
user-registered action names** that make foreign action_packets
self-documenting at a glance.

### 16.1 The three sigils

| Sigil      | Convention   | Resolver signature                                          | Computation? | Seed?  |
|------------|--------------|-------------------------------------------------------------|--------------|--------|
| `%NAME%`   | `token`      | (none — literal text via `seed_text` field)                 | no           | yes    |
| `&NAME&`   | `functor`    | `(parsed_args, ctx::CycleContext) -> MacroFact`             | yes          | no     |
| `@NAME@`   | `both`       | `(seed::String, parsed_args, ctx::CycleContext) -> MacroFact` | yes        | yes    |

A `&NAME&` whose JSON `kind` is `"remote"` (phase 2) shares the
functor sigil but bypasses the resolver registry — it owns its own
HTTP/JSON-path machinery from the spec's `url` and `json_path` fields.

### 16.2 Why sigils

Two reasons sigils still matter:

1. **Self-documenting action_packets.** A voter author reading
   `"&calculate&(...)[neg]^2.0 | %GREETING%^1.0"` immediately sees
   that the first entry is a functor (computes something), the second
   is a token (canned text), and a third would be `@X@` if it were
   both-mode. No registry lookup needed to read code.

2. **Strict-mode survivor regex.** §7a's strict-mode check matches
   `r"[%&@][A-Z_]+[%&@]"` against rendered output to catch
   unresolved placeholders. The sigil convention makes that regex
   sound and complete — any sigil-bracketed sequence in the output
   is either a resolved-and-substituted value or a bug.

### 16.3 Sigil ↔ kind agreement

Enforced at registration (§4.5):

```julia
sigil_pair = (first(spec.action_name), last(spec.action_name))
ok = sigil_pair == ('%', '%') ? spec.kind === :token        :
     sigil_pair == ('&', '&') ? spec.kind in (:functor, :remote) :
     sigil_pair == ('@', '@') ? spec.kind === :both         :
                                false
ok || error("!!! FATAL: sigil $(sigil_pair) inconsistent with kind $(spec.kind) !!!")
```

---

## 17. Fuzzy snap-rounding at decision boundaries

Engine-wide numerical hygiene. Continuous values that feed discrete
decisions get **snapped to the nearest round point** when they're
within a small epsilon. This eliminates borderline-flicker without
changing the *shape* of any decision boundary.

### 17.1 The principle

```julia
function _snap(x::Real, point::Real, eps::Real = 0.01)::Real
    return abs(x - point) < eps ? point : x
end

function _snap_to_any(x::Real, points::Vector{<:Real}, eps::Real = 0.01)::Real
    for p in points
        abs(x - p) < eps && return p
    end
    return x
end
```

Default epsilon: `0.01` (1% of the `[0, 1]` range that most engine
continuous values live in). Per-snap-point overrides allowed.

### 17.2 Snap points

| Consumer                              | Continuous value             | Snap points                                 |
|---------------------------------------|------------------------------|---------------------------------------------|
| Bioavailability gate (§5)             | vote confidence              | `{0, AIML_CONFIDENCE_THRESHOLD, 1}`         |
| Top-tier window                       | confidence delta from max    | `{0, AIML_TOP_TIER_WINDOW}`                 |
| Apoptosis                             | node strength                | `{0, APOPTOSIS_THRESHOLD, 1}`               |
| Coherence weighted score (phase 2)    | modality match score         | `{0, MACRO_COHERENCE_THRESHOLD, 1}`         |
| InputQueue inhibition                 | decay value                  | `{0, 1}`                                    |
| Arousal mood-band edges               | EyeSystem arousal            | `{0, 0.3, 0.5, 0.7, 1}`                     |

### 17.3 Why this is engine-wide hygiene, not macro-specific

Snap-rounding belongs in the engine because every continuous-to-
discrete decision boundary has the same boundary-flicker problem.
The macro plan documents it because §5 (and phase-2 §6 multi-modal
helpers) read these thresholds.

### 17.4 What snapping is NOT

- Not a smoothstep / sigmoid envelope. Decisions stay discrete.
- Not a band-pass filter. No upper-saturation roll-off.
- Not a change to threshold values. Numbers stay; their evaluation
  gains epsilon-tolerance.
- Not a replacement for `:weighted` coherence (when that lands in
  phase 2 helpers).

### 17.5 Worked example

Without snapping:

```
cycle N:    confidence = 0.1497   →  below threshold (0.15) → no fire
cycle N+1:  confidence = 0.1503   →  above threshold       → fire
cycle N+2:  confidence = 0.1499   →  below threshold       → no fire
```

A user observes the engine flickering at the edge.

With snapping (eps = 0.01):

```
cycle N:    confidence = 0.1497   →  snaps to 0.15 → tie-broken consistently
cycle N+1:  confidence = 0.1503   →  snaps to 0.15 → same outcome
cycle N+2:  confidence = 0.1499   →  snaps to 0.15 → same outcome
```

The tie-breaking rule (`>=` vs `>`) determines behaviour at the
snapped point; floating-point noise at the boundary no longer does.

---

*Plan revisions complete: §3 (zero engine struct changes), §4 (JSON
registers a `COMMANDS` handler closure built from `MacroSpec` recipe),
§5 (bioavailability gate removed; voter pattern-bind is the gate),
§6 (CycleContext is a read-only resolver tool, not an eligibility
gate), §10 (persist `MacroSpec`s, replay at boot to rebuild
`COMMANDS`); §7 (two-channel render, `MacroFact` arrives via keyword
arg), §8 (resolvers + arg-parsers, registered at module init),
§15 (relational delta + meta-arrows), §16 (sigils as visual
discipline), §17 (snap-rounding hygiene) — all retained from prior
revision with framing adjusted for the user-defined-COMMANDS model.*
