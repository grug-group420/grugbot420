# MACRO PLUG-IN PLAN — votes optionally carry macro enforcement

**Status:** plan only. No code lands until §11 open questions are
resolved.

**Revision history (most recent first):**
- *current* — complexity-coupled extraction ladder folded into §1
  reality-check. The substrate's `screen_input_complexity` →
  `scan_mode` ∈ {1,2,3} → `extract_relational_triples` (basic) vs
  `extract_dynamic_relational_triples` (compound / nested / causal-
  chain / multi-clause) coupling is load-bearing for any voter
  whose `relational_patterns` reference complex shapes. Such voters
  naturally act as complexity-gated activators — and any macro tail
  they declare fires only on inputs complex enough to trigger
  mode 3. New §1.10 documents the coupling; §5 activation-pathway
  list now distinguishes basic-vs-dynamic triples; §11 gains an
  open question on a phase-2 `:relational_triples` macro scope.
- *prior* — Hopfield familiarity correction. The Hopfield fast-path
  is disabled in current grug (`engine.jl:2453` call site commented
  out, functions retained for test compat only); the savings were
  sub-microsecond at the 1000-nodes-per-cycle lobe cap and didn't
  justify the cache-coherence bookkeeping. §1 gains a §1.9
  subsection making this explicit; §5's activation-pathway list
  drops the obsolete "Hopfield familiarity" entry.
- *prior* — radical simplification. Macros are not functors; they
  are `(regex, scope, template)` enforcement directives optionally
  attached to a vote. Pattern-bind already identifies that the input
  contains a macro-relevant structure (existing engine surface, no
  new infrastructure). The macro then regex-extracts the exact
  triggering substring (or looks it up against the Memory Cave) and
  resolves to a plain string **before AIML even runs**. AIML weaves
  the resolved string like any other support_piece — no plug-in,
  no kwargs, no envelope. Resolver registry, arg-parser registry,
  `MacroFact`, `repl_eval` sandbox, `semantic_role` taxonomy, and
  the skeleton-aware clause dispatcher all collapse into a single
  regex-and-substitute step.
- *prior* — macros as mandatory follow-ons to a primary action,
  `>>` separator, `Vote.macro_action` field, sandboxed Julia REPL
  eval for lambda-grade meta-programming, system-clock and
  `MacroFact`-returning resolvers, two-channel render with AIML
  kwargs.
- *prior* — collapsed cycle-level coherence-gate into voter-pattern-bind.
  Macros as user-defined `COMMANDS` entries selected by weighted
  coinflip alongside grug-defined actions.
- *prior* — sigil-tagged sum-type variants, JSON registration,
  snap-rounding, meta-arrows.
- *prior* — `MacroFact` envelope, two-channel render, organic
  synthesis weaving.
- *initial* — voter-carried `macro_signal` field, custom coherence gate.

---

## 0. Problem statement

The user wants to extend grugbot420 with a **plug-in macro system**
that lets voters optionally enforce extraction of a relevant
substring from the user input — or a relevant value from the Memory
Cave — and surface that substring in the response, without having
to hand-write a per-input handler.

The user's exact final framing, in three pieces, in order:

1. *"what registered macros should do is regex on the user input to
   derive the exact string that set off the need for plugins in the
   first place. no functor or whackyness needed. so if i ask what is
   2+2 also what time is it? for both cases it just grabs the exact
   string needed."*
2. *"there should also be a general %reflect%(pattern to look up in
   memory hash table derived from user input regex) but yeah a way
   to register macros on the fly that work like this. so aiml before
   it even gets the macro the macro is resolved to its coherent
   value. aiml doesnt even have to plugin really."*
3. *"because its going by pattern bind identification of structures
   like this uses normal methods we already have. its just votes can
   now optionally have macro enforcement."*

These three sentences specify the entire feature surface. The macro
system is **regex-extract-or-memory-lookup, resolve to string,
weave like any other support_piece**. Pattern-bind is reused as-is;
nothing new is invented for activation. AIML is unchanged. Votes
gain one optional field carrying enforcement directives.

---

## 1. Code-level reality check (verified against fresh HEAD `89d79b0`)

### 1.1 Node struct (`engine.jl:433`)

```
mutable struct Node
    id::String
    pattern::String                      # ← existing pattern-bind matches input structure (e.g. "{NUMBER} plus {NUMBER}")
    signal::Vector{Float64}
    action_packet::String                # ← gains optional `>> macro1 | macro2 | ...` tail
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
    hopfield_key::UInt64                 # ← legacy field; Hopfield fast-path is disabled in current engine (functions retained for test compat only — see §1.9)
    fired_this_cycle::Bool
    voted_this_cycle::Bool
    gained_this_cycle::Bool
    strength_delta_this_cycle::Float64
end
```

**No new field.** The voter's `pattern` is what identifies that the
input contains a macro-relevant structure — pattern-bind already
does that work with `{NUMBER}`, lemma-classes, verb-classes, lexical
patterns, and triple-relations. The `action_packet` gains an
optional `>>` tail listing which macros to enforce when this voter
wins. See §3.

### 1.2 Vote struct (`engine.jl:473`)

```
struct Vote
    node_id::String
    action::String
    confidence::Float64
    negatives::Vector{String}
    user_triples::Vector{RelationalTriple}
    node_triples::Vector{RelationalTriple}
    antimatch::Bool
    macro_actions::Vector{String}        # ← NEW: zero or more macro invocations
end
```

**One new field: `macro_actions::Vector{String}`.** A vote optionally
carries macro enforcement. Empty vector = no enforcement (all existing
voters). Non-empty = these macros must resolve and contribute to the
output. Each entry is the verbatim macro invocation string from after
`>>` — e.g. `"%calculate%"` or `"%reflect%(turtles)"`. Specimens that
predate this field default to `String[]` on load.

### 1.3 `cast_vote` (`engine.jl:2850`)

```julia
function cast_vote(id, conf, antimatch, u_trips, n_trips)
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("...")

    winning_action, negatives, macro_tails = select_action(node.action_packet)
    #                                  ^^^^^^^^^^^ NEW: list of enforcement strings

    if !haskey(COMMANDS, winning_action)
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! ...")
    end

    # NEW: validate every macro in the tail resolves in MACRO_SPEC_REGISTRY.
    for m in macro_tails
        action_name = _extract_macro_action_name(m)
        if !MacroPlugins.has_spec(action_name)
            error("!!! FATAL: voter $(id) referenced unregistered macro [$(action_name)] !!!")
        end
    end

    bump_strength!(node)
    return Vote(id, winning_action, conf, negatives, u_trips, n_trips,
                antimatch, macro_tails)
end
```

Two added lines: receive `macro_tails` from the parser, store it on
the `Vote`. Validation keeps the loud-fail convention.

### 1.4 `parse_action_packet` (`engine.jl:1912`)

The action-packet grammar gains exactly one new piece: a `>>`
separator dividing the packet into a primary half (existing
pipe-delimited weighted-coinflip pool) and a macro-tail half
(pipe-delimited list of macro invocations, all unconditional).

```
"primary_action[neg]^weight | other_primary^weight  >>  %macro1% | %macro2%(arg) | %macro3%"
                primary half (coinflip pool)              macro-tail half (all fire)
```

`parse_action_packet` splits on `>>` first, parses the primary half
exactly as today, then splits the macro-tail half on `|` and trims
each entry. Returns `(positives, negatives, action_items, macro_tails::Vector{String})`.

**Constraints on the macro half:**
- No `[`, `]`, `|`, `^`, `>` inside an individual macro invocation.
  These are action-packet metasyntax. Macro arg-strings (between the
  `(` and `)`) likewise cannot contain them.
- Each invocation must reference a registered `MacroSpec`
  (validated at `cast_vote` time, see §1.3).
- The `>>` separator is exact. Whitespace around it is fine; `>>>`,
  `→`, `==>` are parse errors.

### 1.5 `select_action` (`engine.jl:2011`)

Returns 3-tuple `(winning_action::String, negatives::Vector{String}, macro_tails::Vector{String})`.
The weighted-coinflip logic operates only on the primary half (same
as today); the macro-tail half is passed through verbatim. **The
macros are never in the coinflip pool** — they're not candidates,
they're enforcement.

### 1.6 `COMMANDS` registry (`engine.jl:486`, `Main.jl:1666+`)

```julia
const COMMANDS = Dict{String, Function}()
```

**Macros are NOT COMMANDS entries.** This is the structural shift
from the prior revision. `COMMANDS` continues to hold only
grug-defined action families (`reason`, `greet`, `inform`, etc.).
Macro resolution is a separate dispatch step that runs *between*
the primary handler and AIML synthesis — see §4.

### 1.7 Memory Cave — `MESSAGE_HISTORY` (`Main.jl:81`, `Main.jl:221`)

```julia
mutable struct ChatMessage
    id::Int
    role::String          # "user" | "assistant" | "system"
    text::String
    pinned::Bool
    intensity::Float64
end

const MESSAGE_HISTORY      = Vector{ChatMessage}()        # capped at MAX_HISTORY (10k)
const MESSAGE_HISTORY_LOCK = ReentrantLock()
```

This is the engine surface the `memory_hash` scope (§3.3) reads
against. Pinned messages persist; unpinned messages are eligible for
oldest-non-pinned eviction once the 10k cap is hit. `intensity`
gates which unpinned messages are considered "fresh" by the
Fresh-Memory machinery; macros may opt in or out of that gating
(see §3.3).

### 1.8 `generate_aiml_payload` (`Main.jl:1191`)

Unchanged. **AIML doesn't know macros exist.** Resolved macro
strings flow into the synthesis pipeline as ordinary
`support_pieces` entries, joining the existing four sources
(action-family skeleton claims, supporting triples, companion
patterns, UNSURE hedges). No new keyword arguments. No envelope.
No skeleton-aware clause dispatcher.

### 1.9 Hopfield familiarity cache — disabled, not load-bearing

`engine.jl` retains the Hopfield surface (`HOPFIELD_CACHE`,
`HOPFIELD_CACHE_LOCK`, `hopfield_input_hash`, `hopfield_lookup`,
`hopfield_record!`, plus `Node.hopfield_key`) **for test-suite
compatibility only**. The actual fast-path call site that would
short-circuit a full lobe scan with a precomputed node-id list
is commented out at `engine.jl:2453`. The disabling rationale is
in the comment block above that call site:

> *"Hopfield caching should only be used for RIDICULOUSLY LARGE
> lobe sizes (50,000+ nodes per lobe) where memory access becomes
> a bottleneck. Current lobe architecture with 1000 node cap per
> cycle makes this obsolete."*

In practice the cache was saving sub-microsecond per cycle on the
current architecture while introducing cache-coherence bookkeeping
(stale signatures when patterns mutated, hit-count thresholds,
LobeTable-shard fanout) that cost more in maintenance and
edge-case bugs than it returned in throughput.

**Implications for this plan:**

1. **§5's activation-pathway list omits Hopfield familiarity.**
   The voter's pattern-bind reaches it via the standard scan
   pathways (lexical / lemma / verb / relational / neighbor /
   lobe / immune); Hopfield is not a real shortcut today.
2. **Macros do not interact with `HOPFIELD_*` symbols.** The
   `MacroPlugins` module does not read or write the cache.
3. **`Node.hopfield_key` is a legacy field that survives in the
   struct.** This plan does not propose removing it. If a future
   cleanup pass deletes the field, no macro-side code is
   affected.
4. **`Main.jl` save/load and stats still touch `HOPFIELD_CACHE`**
   for inventory purposes (counting entries, draining on `/clear`,
   reporting in `/sandboxStatus`). Specimen JSON may still carry
   a hopfield section. None of this is on the macro hot path; the
   existing serialization stays as-is.

This plan was originally drafted referencing Hopfield familiarity
as a live activation pathway; that reference has been corrected.

### 1.10 Complexity-driven scan mode and dynamic relational triples (`engine.jl:181`, `engine.jl:2371`)

The substrate has a **deterministic complexity-coupled extraction
ladder** that's load-bearing for any voter whose `relational_patterns`
reference compound, nested, or causal structure. This was missing from
earlier drafts of the §1 reality-check; flagging it here because it's
a real activation pathway macros piggyback on (see §5).

The flow:

1. `screen_input_complexity(target_signal, RelationalTriple[])` at
   `engine.jl:2372` computes `scan_mode :: Int` ∈ `{1, 2, 3}` from
   the input's signal density.
   - **mode 1** = `cheap_scan`
   - **mode 2** = `medium_scan`
   - **mode 3** = `high_res_scan` (input was complex enough to
     warrant deep parsing)
2. The relational-extraction call site at `engine.jl:2396` is
   **deterministically gated on `scan_mode`**:
   ```julia
   user_triples = if scan_mode >= 3
       extract_dynamic_relational_triples(input_text, scan_mode)
   else
       extract_relational_triples(input_text)
   end
   ```
   - **basic triples** (mode 1, 2): subject-verb-object surface
     extraction.
   - **dynamic triples** (mode 3): per `engine.jl:181-195`'s
     contract — *"compound subjects/objects across multiple
     tokens, nested relations (A causes B which causes C),
     implicit relations through conjunctions and prepositions,
     causal chains and temporal sequences, multiple clauses with
     proper scope."*
3. Mode-3 failure is **fatal** (`@error` + rethrow). The engine
   refuses to silently degrade complex inputs to basic extraction;
   the input "earned" high-res scanning. Mode-1/2 failure is
   non-fatal (warn + empty triples).

**Why this matters for macros:**

The voter's `relational_patterns` / `required_relations` /
`relation_weights` (existing fields on `Node`) match against the
extracted triples. Triples extracted by `extract_dynamic_relational_triples`
include shapes that `extract_relational_triples` *cannot* produce
(causal chains, multi-clause structures). So a voter whose relational
pattern is `(X, causes, (Y, causes, Z))` **only activates on inputs
complex enough to trigger mode 3**. That activation pathway is
implicit, deterministic, and zero-cost from the macro side — it's
just the existing relational-pattern match running against a richer
triple set.

This means the §5 activation-pathway list has a sixth real pathway:
"relational triples — basic on simple inputs, dynamic on complex
inputs (mode 3)." A voter with a complex-shaped relational pattern
acts as a **complexity-gated activator**, and any macro tail it
declares fires only when the input is genuinely complex.

**Implications for this plan:**

1. **No new pattern-bind machinery for macros to invent.** This is
   already in the engine, working today, deterministic.
2. **Macros do not see `scan_mode` directly in phase 1.** The macro
   spec has a `:current_input` scope, not a `:dynamic_triples`
   scope. If a macro author wants their macro to fire only on
   complex inputs, they put a complex-shaped relational pattern on
   the *voter*, not on the macro.
3. **Phase 2 may add a `:relational_triples` scope** that lets a
   macro regex against the carrier `Vote.user_triples` (which the
   engine has already extracted at the appropriate complexity
   level) — see §11 open question 9. Phase 1 doesn't add it.
4. **No code change in this plan touches `screen_input_complexity`,
   `_effective_scan_mode`, or `extract_dynamic_relational_triples`.**
   They're load-bearing for activation but the macro plug-in is
   transparent to all three.

---

## 2. Mental model — votes optionally carry macro enforcement

The clean restatement (this is the final one):

> **Votes already carry an `action`, a confidence, negatives, and
> triples. Now they optionally also carry one or more macro
> enforcement directives.** Each directive is a registered
> `(regex, scope, template)` recipe. At dispatch time, after the
> primary handler runs and before AIML synthesis runs, each macro
> applies its regex against its scope (the user input, a recent
> message, or the Memory Cave), substitutes the captured groups
> into its template, and emits a plain resolved string. That string
> joins the support_pieces list for AIML to weave. AIML doesn't
> know it came from a macro.

### 2.1 Two-stage activation, both stages reusing existing infrastructure

**Stage 1 — Pattern-bind (existing, unchanged).** The substrate's
existing pattern-match machinery decides which voters are relevant
to the input. `{NUMBER} plus {NUMBER}` matches arithmetic input;
`tell me about {TOPIC}` matches recall queries; `what now` matches
follow-up cues. **Macros do not invent new pattern-match
infrastructure.** If pattern-bind already says "this voter is
relevant," it has already decided "this input contains the
structure the voter cares about."

**Stage 2 — Macro enforcement (new, but trivial).** Once a voter
wins the cycle and its primary action is selected by the existing
weighted coinflip, *if* the voter declared a `>>` macro-tail, those
macros fire. Each macro's regex extracts the specific substring from
its scope. Each macro's template substitutes the capture into a
final resolved string. The list of resolved strings joins the
support_pieces stream.

The two stages compose: pattern-bind does **broad activation**
("this kind of input matches this voter"); the macro's regex does
**fine extraction** ("the specific substring inside that input that
needs surfacing"). They use the same regex-and-string toolkit. The
voter author writes the broad pattern once on the voter and writes
the fine pattern once on each macro. Both are reusable across many
voters once registered.

### 2.2 The motivating example, end to end

User input: *"what is 2+2 also what time is it"*.

Voter:
```
pattern: "what is {NUMBER} plus {NUMBER}"   ← may be a multi-pattern voter or a duplicated voter
action_packet: "inform^1.0 | reason^0.5 >> %calculate% | %timeOf%"
```

`MacroSpec` registry contains:
```
%calculate%:  regex=(\d+\s*[+\-*/]\s*\d+)            scope=current_input   template="$1"
%timeOf%:     regex=(what(?:'s| is) the time|what time is it)
                                                      scope=current_input   template="the time question: $1"
```

Cycle runs:

1. Pattern-bind: voter's `pattern` matches (substring `2+2` rendered
   as "2 plus 2" via existing tokenization, or via a sibling
   `{NUMBER}+{NUMBER}` pattern — that's pattern-bind's job).
2. `select_action`: coinflips between `inform` (1.0) and `reason`
   (0.5). Suppose `inform` wins.
3. Primary handler runs: `COMMANDS["inform"](mission, node, vote, ...)` →
   produces the spoken-spine output, same as today.
4. **Macro enforcement (new):**
   - `%calculate%`: regex `(\d+\s*[+\-*/]\s*\d+)` against `current_input`
     captures `"2+2"`. Template `"$1"` resolves to `"2+2"`. Push
     `"2+2"` onto `support_pieces`.
   - `%timeOf%`: regex against `current_input` captures
     `"what time is it"`. Template resolves to
     `"the time question: what time is it"`. Push onto `support_pieces`.
5. AIML synthesis runs as today. Sees the existing supporting triples
   plus two new support_pieces entries. Weaves them organically.
   Output something like: *"thinking about 2+2 — and there's also
   the time question: what time is it."*

No functor, no eval, no special envelope. Just regex + substitute +
push-into-support-pieces.

### 2.3 The `%reflect%` example — memory hash scope

User input: *"remember when we talked about turtles"*.

Voter:
```
pattern: "remember when we"   ← lexical pattern, existing
action_packet: "reason^1.0 >> %reflect%(turtles)"
```

`%reflect%` spec:
```
regex=(\w+)        scope=memory_hash    template="$MEMORY"
```

(The literal `$MEMORY` token in the template is the resolution
sentinel — meaning "substitute the looked-up value." See §3.4.)

Cycle runs:

1. Pattern-bind matches `"remember when we"` lexically.
2. Primary `reason` fires, produces spine.
3. Macro: `%reflect%` regex captures `"turtles"` from the macro
   invocation's own arg-string `"(turtles)"` (yes, the regex can
   target the arg-string too — see §3.3 scope `arg`). The captured
   key looks up `"turtles"` against `MESSAGE_HISTORY` (the Memory
   Cave) — finds prior `ChatMessage`s where the text matches.
   Resolution returns the matching message text. Template
   substitutes that text in.
4. Resolved string lands in `support_pieces`.
5. AIML weaves: *"i think we said earlier — turtles can live for
   over a hundred years. you were curious about that."*

The macro reduced to **regex against memory hash → return matched
message → AIML weaves**. No functors. No `MacroFact`. No special
synthesis path.

### 2.4 What this rejects, definitively

- **No functor registry.** No `RESOLVER_REGISTRY`. The macro is
  defined entirely by its `(regex, scope, template)` triple plus
  optional fallback text.
- **No arg-parser registry.** The macro's regex IS the arg parser.
  If you want number-word resolution (`"two plus two"` → `2+2`),
  you write a regex that handles word-forms (or you preprocess at
  pattern-bind time using existing thesaurus machinery, which
  happens before macros run anyway).
- **No `MacroFact` envelope.** Macro output is `String`. Either it
  resolved (non-empty) or it didn't (empty / fallback string).
- **No `semantic_role` taxonomy.** No roles. No skeleton-aware
  dispatcher. AIML treats the resolved string like any other
  support_piece.
- **No `repl_eval` / sandboxed Julia eval.** The user explicitly
  walked back the "lambda-grade meta-programming" framing: *"no
  functor or whackyness needed."* If a user wants computation
  (e.g. actually computing `2+2 = 4`), they handle it
  downstream — the macro's job is to surface the substring, not
  to compute over it.
- **No `CycleContext` bundle.** Macros read `mission` directly,
  read `MESSAGE_HISTORY` directly under its existing lock, read
  the carrier `Vote` directly. Nothing else.
- **No AIML kwargs.** `generate_aiml_payload` signature is
  unchanged. Macros resolve before AIML runs; resolved strings
  are pushed into the existing `support_pieces` Vector.

### 2.5 Comparison table

| Concern                      | Prior framing (functor + MacroFact)         | New framing (regex + substitute)                 |
|------------------------------|---------------------------------------------|--------------------------------------------------|
| What the macro DOES          | Calls a registered functor with parsed args | Runs a regex; substitutes captures into template |
| Output type                  | `MacroFact(placeholder, role, text, struct)`| `String`                                         |
| AIML integration             | New kwargs `primary_output`, `macro_fact`   | None. Macro output joins `support_pieces`        |
| Activation gate              | Voter pattern-bind                          | Voter pattern-bind. Same.                        |
| Mandatory or optional        | Mandatory once `>>` declared                | Mandatory once `>>` declared. Same.              |
| Number per voter             | One                                         | Many (pipe-delimited tail)                       |
| Memory access                | Out of scope                                | First-class via `memory_hash` scope              |
| Sandboxed eval               | `_repl_eval` whitelist                      | None. No eval. No computation.                   |
| Persisted spec               | `(action_name, kind, fn, arg_parser, seed_text, …)` | `(action_name, regex, scope, template, fallback)` |
| Lines of new resolver code   | ~150 (8 resolvers + sandbox + AST validator)| ~30 (regex apply, scope lookup, template sub)    |

---

## 3. The `MacroSpec` and the `/macro` slash command

### 3.1 `MacroSpec` — the entire data shape

```julia
struct MacroSpec
    action_name :: String          # e.g. "%calculate%" — sigil-bracketed; what voters write after >>
    regex       :: Regex           # compiled once at registration
    scope       :: Symbol          # see §3.3 — where the regex runs
    template    :: String          # substitution template; see §3.4
    fallback    :: String          # emitted when regex finds nothing or scope yields nothing
    notes       :: String          # human-readable description (optional)
end
```

That's it. Five fields plus notes. No closures, no functors, no
arg-parsers, no kinds, no placeholders separate from the action_name.

### 3.2 `/macro <json>` — registration surface

```
/macro {
  "action_name": "%calculate%",
  "regex":       "(\\d+\\s*[+\\-*/]\\s*\\d+)",
  "scope":       "current_input",
  "template":    "$1",
  "fallback":    "",
  "notes":       "extracts a literal arithmetic expression"
}
```

Slash command parser inflates to `MacroSpec`, validates:
- `action_name` non-empty, sigil-bracketed (`%X%`, `&X&`, `@X@`).
- `regex` compiles cleanly (Julia `Regex(s)` doesn't throw).
- `scope` is one of the registered scope symbols (§3.3).
- `template` is a `String`. `$0` / `$1` / `$N` reference whole-match
  and capture groups; `$MEMORY` is the memory-resolution sentinel
  (§3.4); literal `$` requires `$$`.
- `action_name` not already in `MACRO_SPEC_REGISTRY` (collision
  unless `/macroForce`).

On success: insert into `MACRO_SPEC_REGISTRY`. Persist via
specimen-save (§7).

Companion commands:
```
/macro <json>                       # add a new macro spec
/macroForce <json>                  # add, overriding existing collision
/macroRemove <action_name>          # remove a registered macro
/macroList                          # pretty-print all registered MacroSpecs
/macroTest <action_name> "test input"   # dry-run regex against given input, show resolution
```

All gated by `immune_gate(...)`.

### 3.3 Scope primitives — phase 1

A macro's `scope` symbol selects what the regex runs against and what
"resolution" means once a capture is found:

| `scope`                | Source                                                   | Resolution semantic                          |
|------------------------|----------------------------------------------------------|----------------------------------------------|
| `:current_input`       | `mission` (the current cycle's user message)             | Apply template to capture groups verbatim    |
| `:arg`                 | The macro invocation's arg-string (between `(` and `)`)  | Apply template to capture groups verbatim    |
| `:last_user_message`   | Most recent `MESSAGE_HISTORY` entry where `role=="user"` other than the current  | Apply template to capture groups |
| `:last_assistant_message` | Most recent entry where `role=="assistant"`           | Apply template to capture groups             |
| `:last_n_messages`     | Last N entries (N from spec, default 3)                  | Apply template; if multiple matches, join with " "  |
| `:pinned_only`         | Only `MESSAGE_HISTORY` entries where `pinned == true`    | Apply template across all matches            |
| `:memory_hash`         | All of `MESSAGE_HISTORY` (under lock)                    | The capture is a **lookup key**; resolution is the matching message's text. Template's `$MEMORY` substitutes that text. |

All scopes that read `MESSAGE_HISTORY` acquire `MESSAGE_HISTORY_LOCK`
for the duration of the read. Resolution copies the matching text
out of the lock; no `ChatMessage` reference escapes.

`:memory_hash` is the special one — the regex captures a *key*
rather than text-to-substitute, and resolution does a lookup against
`MESSAGE_HISTORY` for messages whose `text` contains the key
(case-insensitive substring match in phase 1). The first match wins
in phase 1; phase 2 may add intensity-weighted ranking or
pinned-priority. The found message's `text` is what gets substituted
where the template says `$MEMORY`.

### 3.4 Template syntax

The template is a plain `String` with three substitution forms:

- `$0` — the whole regex match.
- `$1`, `$2`, … `$N` — capture groups by index.
- `$MEMORY` — only meaningful for `:memory_hash` scope; substitutes
  the looked-up message text.
- `$$` — literal `$`.

Substitution is mechanical and total. If the regex didn't match (or
`memory_hash` lookup found nothing), the macro emits `fallback`
verbatim (which may be empty, in which case the macro contributes
nothing to `support_pieces`).

Examples:

```
regex=(\d+\s*[+\-*/]\s*\d+)     template="$1"                     → "2+2"
regex=(\d+)\s*plus\s*(\d+)      template="$1 + $2"                → "2 + 2"
regex=(\w+)                     template="$MEMORY"                → looked-up text
regex=(\w+)                     template="earlier we said: $MEMORY" → "earlier we said: turtles can live..."
```

### 3.5 Sigil-bracketed action_name

Action names must be sigil-bracketed. Phase 1 sigil conventions
(carried forward from the prior revision; now purely cosmetic):

| Sigil | Suggested semantic                            |
|-------|-----------------------------------------------|
| `%X%` | Direct extraction from input (`%calculate%`, `%timeOf%`, `%greet%`) |
| `&X&` | Memory or external lookup (`&reflect&`, `&recall&`)  |
| `@X@` | Mixed / composite (`@summarize@`, `@continue@`)      |

The sigil is **not load-bearing in phase 1.** The substrate doesn't
dispatch on it; voter authors and reviewers use it as a visual hint.
A `%X%` macro and a `&X&` macro have identical mechanics. (A future
phase may use the sigil to enforce stylistic consistency, e.g.
warning if a `%X%` macro uses `:memory_hash` scope.)

---

## 4. Activation flow — one beat after the primary

Pattern-bind runs as today. `select_action` runs as today,
returning `(winning_action, negatives, macro_tails)`. `cast_vote`
returns a `Vote` with `macro_actions = macro_tails`. AIML votes are
selected as today. The dispatch site in Main.jl (~line 1173) gains
**one new beat** between the primary handler call and the AIML
synthesis call:

```julia
# Beat 1: primary handler runs (unchanged).
primary_output = COMMANDS[primary_vote.action](
    mission, node, primary_vote, sure_votes, unsure_votes, votes)

# Beat 2 (NEW): macro enforcement.  For every vote in top_tier with
# a non-empty macro_actions list, resolve each macro and push the
# resolved string onto a macro_pieces vector that flows into AIML.
macro_pieces = String[]
for v in top_tier_votes
    isempty(v.macro_actions) && continue
    for invocation in v.macro_actions
        resolved = MacroPlugins.resolve(invocation, mission, v)
        isempty(resolved) || push!(macro_pieces, resolved)
    end
end

# Beat 3: AIML synthesis (unchanged signature; macro_pieces threaded
# in via the support_pieces assembly site at Main.jl:1497-1527).
output = generate_aiml_payload(
    mission, primary_vote, sure_votes, unsure_votes, votes, node.json_data;
    extra_support_pieces = macro_pieces)
```

`MacroPlugins.resolve` is the entire macro runtime:

```julia
function resolve(invocation::String, mission::String, vote::Vote)::String
    action_name = _extract_macro_action_name(invocation)   # e.g. "%calculate%"
    arg_string  = _extract_macro_args(invocation)          # e.g. "" or "turtles"

    spec = lock(MACRO_LOCK) do
        get(MACRO_SPEC_REGISTRY, action_name, nothing)
    end
    isnothing(spec) && error("!!! FATAL: unregistered macro $(action_name) — should have been caught at cast_vote !!!")

    source_text = _load_scope(spec.scope, mission, vote, arg_string)
    isempty(source_text) && return spec.fallback

    m = match(spec.regex, source_text)
    isnothing(m) && return spec.fallback

    return _apply_template(spec.template, m, spec.scope, source_text)
end
```

The two helpers `_load_scope` and `_apply_template` are small
(~20–30 lines each). `_load_scope` looks up `MESSAGE_HISTORY`
(under lock) for memory-scoped specs, returns `mission` for
input-scoped specs, returns `arg_string` for arg-scoped specs.
`_apply_template` does mechanical `$0` / `$N` / `$MEMORY` / `$$`
substitution against the regex match (and memory lookup for
`memory_hash` scope).

That's the whole runtime.

### 4.1 `extra_support_pieces` plumbing in `generate_aiml_payload`

The only AIML touch needed: at `Main.jl:1497-1527` where
`support_pieces` is assembled from triples / companion patterns /
UNSURE hedges, append the keyword-arg `extra_support_pieces` to
the same `Vector{String}` before it gets routed through
`_swap_words_in`. Six lines of glue. AIML doesn't know or care
that some of those entries came from macros.

```julia
# inside generate_aiml_payload, just after the existing support_pieces
# is assembled:
if !isempty(extra_support_pieces)
    for piece in extra_support_pieces
        push!(support_pieces, _swap_words_in(piece, swap_ctx))
    end
end
```

The existing v7.16 synonym / inhibition router (`_swap_words_in`,
`Thesaurus.synonym_for`, etc.) runs over macro pieces just like
over triples. Output reads varied across cycles, not parroted.

### 4.2 Multi-macro independence

Each entry in `Vote.macro_actions` resolves independently. If one's
regex matches and another's doesn't, the matching one contributes,
the non-matching one emits its fallback (which may be empty).
There's no "all or nothing" semantics across the list. There's no
cross-macro communication; each is its own `(regex, scope, template)`
applied in isolation.

### 4.3 Multi-voter independence

If two top-tier voters each declare macro-tails, both fire.
Resolution is per-vote, so the same `%reflect%` invocation called
from two different voters resolves twice — but each call's regex
runs against the same scope, so unless the two voters wrote
different macro args, the resolutions are identical and AIML's
existing dedup machinery (synonym + drop-table) handles repetition.

### 4.4 Pre-render resolution — AIML doesn't plug in

The user's exact words: *"so aiml before it even gets the macro
the macro is resolved to its coherent value. aiml doesnt even have
to plugin really."*

This is the structural payoff. AIML synthesis sees only fully
resolved strings in its `support_pieces` vector. The `%calculate%`
sigil never reaches AIML; it was already substituted out in beat 2.
There's no two-channel render, no rule-board substitution pass,
no skeleton-aware clause dispatcher, no envelope unpacking. AIML
weaves resolved strings the same way it weaves triple-derived
strings.

---

## 5. Pattern-bind as the activation gate (existing infrastructure)

The user's exact words: *"because its going by pattern bind
identification of structures like this uses normal methods we
already have."*

**Macros add zero pattern-match infrastructure.** Every
identification step the substrate already does becomes an
activation pathway for macros for free:

- Lexical patterns (`"what is {NUMBER} plus {NUMBER}"`).
- Lemma classes (`{NUMERIC}`, `{TEMPORAL}`, `{SELF_PRONOUN}`).
- Verb classes (`{ARITHMETIC}`, `{INTROSPECTIVE}`).
- Relational triples — **basic** (subject-verb-object) on simple
  inputs (scan_mode 1/2), and **dynamic** (compound, nested,
  causal-chain, multi-clause) on complex inputs (scan_mode 3,
  via `extract_dynamic_relational_triples`). A voter whose
  `relational_patterns` reference complex shapes naturally acts
  as a complexity-gated activator. See §1.10.
- Neighbor links (the voter activated because a sibling activated).
- Lobe routing.
- Immune gates.

(Hopfield familiarity was a sixth pathway in earlier engine
revisions but the fast-path is disabled in current grug —
`hopfield_lookup` / `hopfield_record!` are still exported for
test-suite compatibility, but the call site at `engine.jl:2453`
is commented out. The savings were sub-microsecond at the current
1000-nodes-per-cycle lobe cap and the cache-coherence bookkeeping
created more headaches than it removed. See §1.9 for context.)

If pattern-bind activates the voter, the voter is "relevant" and
its macro tail (if any) fires. If pattern-bind doesn't activate
the voter, nothing about that voter contributes to the cycle —
including its macros.

**Voter authors are encouraged to put the broad activation logic
in the voter's `pattern` and the fine extraction logic in the
macro's `regex`.** The voter's pattern is where you say "this
input is about arithmetic"; the macro's regex is where you say
"and the specific arithmetic expression is this substring." The
two work in tandem: pattern-bind already filters out 99% of
irrelevant cycles before the macro's regex ever has to run.

### 5.1 Time / event coherence — *"what now?"* and follow-ups

The user's worked example: a voter tuned to `"what now"` as a
follow-up question, whose macro `%reflect%`s against
`:last_assistant_message`. Cycle plays out:

1. Voter pattern: `"what now"` (lexical, existing).
2. Pattern-bind: matches on the literal string.
3. `select_action`: primary is something like `inform` or `reason`.
4. Macro: `%reflect%` with `scope=:last_assistant_message`,
   `regex=(.+)`, `template="last we touched on: $1"`.
5. `_load_scope` reads the most recent `role=="assistant"`
   `ChatMessage` from `MESSAGE_HISTORY`. The regex `(.+)` captures
   its full text. Template wraps it: `"last we touched on: <text>"`.
6. AIML weaves: *"last we touched on: turtles can live for over a
   hundred years. — and now you want to keep going on that?"*

No new "time/event coherence rule engine." The coherence is just
**which scope you point the regex at**. `:current_input` for
input-relative; `:last_assistant_message` for "the last thing I
said"; `:pinned_only` for "the things you marked important";
`:memory_hash` for "find me the memory that mentions this thing."

### 5.2 What pattern-bind helpers might still want phase-1 enrichment

The earlier revision proposed adding `arithmetic`, `temporal`,
`numeric`, `self_pronoun`, `affect_word` lemma/verb classes. Those
are still useful — but **for richer pattern-bind, not for macro
mechanics**. They strengthen the activation step, which means
voters can be more selective about when they fire, which means
macro tails fire on more relevant cycles. Adding them is purely
additive to the existing `SemanticVerbs.jl` and lemma-class
registries; phase 1 of *macros specifically* does not require
them.

---

## 6. Built-in macro specs — phase 1

Three macros seed `MACRO_SPEC_REGISTRY` at `__init__()`:

```julia
register_spec!(MacroSpec(
    "%calculate%",
    r"(\d+\s*[+\-*/]\s*\d+)",
    :current_input,
    "$1",
    "",
    "extracts a literal arithmetic expression from the user input"
))

register_spec!(MacroSpec(
    "%timeOf%",
    r"(what(?:'s| is) the time|what time is it|tell me the time)"i,
    :current_input,
    "$1",
    "",
    "extracts a time-question phrase from the user input"
))

register_spec!(MacroSpec(
    "%reflect%",
    r"(\w+(?:\s+\w+){0,3})",
    :memory_hash,
    "earlier we touched on — $MEMORY",
    "",
    "regex captures a 1-4 word key; looks up against MESSAGE_HISTORY; substitutes matching message text"
))
```

The user can `/macroRemove` any of these and replace with a
custom regex tuned to their voice. The seed set is small on
purpose — the registration surface is the load-bearing thing,
not the seed list.

There is no `&CALC&` doing actual arithmetic. The macro extracts
`"2+2"` as a substring; if the user wants the bot to *say* `4`,
they handle that downstream of macros (e.g. an AIML rule that
detects `"$DIGIT$ + $DIGIT$"` in the resolved support_piece and
rewrites it). Phase-1 macros surface the substring; computation
over substrings is out of scope.

---

## 7. Persistence — specimen save/load

Only `MACRO_SPEC_REGISTRY` persists. The `Vote.macro_actions`
field is per-cycle and not persisted (votes are not persisted in
general). The `>>` tail in each voter's `action_packet` persists
because `action_packet` is a `Node` field that already serializes.

Specimen JSON gets a new top-level section:

```json
{
  "MACRO_SPEC_REGISTRY": [
    {"action_name": "%calculate%", "regex": "(\\d+\\s*[+\\-*/]\\s*\\d+)",
     "scope": "current_input", "template": "$1", "fallback": "", "notes": "..."},
    {"action_name": "%timeOf%",    "regex": "...", "scope": "current_input", ...},
    ...
  ]
}
```

Save: walk `MACRO_SPEC_REGISTRY`, serialize each spec's fields
(regex serializes as its source string, not the compiled `Regex`
object). Load: reverse — read each entry, recompile regex with
`Regex(...)`, insert into `MACRO_SPEC_REGISTRY`. Built-in seeds
from `__init__()` run only when the loaded specimen has no
`MACRO_SPEC_REGISTRY` section (greenfield boot); otherwise the
loaded specs are the source of truth.

A specimen written under the prior revision (with the old
`(action_name, kind, fn, arg_parser, ...)` shape) is incompatible
and must be migrated. Phase-1 migration: a one-time `/macroMigrate
<old_spec_json>` command that drops everything except `action_name`
and `notes` and prompts the user to specify `regex` / `scope` /
`template` interactively. (Or simpler: the prior revision never
landed code, so there are no extant specimens. Migration is a
non-issue.)

---

## 8. /right and /wrong feedback

Unchanged. A vote that contributed to output is a contributor; if
that vote's `macro_actions` is non-empty, the carrier voter is
reinforced exactly the same way it would be without macros. The
macro contributing or failing to contribute doesn't differentiate
the contributor reinforcement — only the carrier vote's
participation matters.

`/wrong` decays the contributor list. Persistent failure of a
voter that always declares a `>>` tail causes that voter's
strength to decay through the existing apoptosis pathway, exactly
like any other underperforming voter.

**Macro-resolution failures** (regex matches nothing, scope
empty, memory lookup miss): the macro emits `fallback` (which
may be empty). Empty fallback contributes nothing to
`support_pieces`; the cycle proceeds without that piece. There's
no "macro punishment" path because there's nothing to punish —
the macro is just a regex that didn't match.

---

## 9. Phased rollout — concrete deliverables

**Phase 1 — minimal viable macro.**

1. Add `Vote.macro_actions::Vector{String}` field with `String[]`
   default for backward compat. (`engine.jl:473`)
2. Extend `parse_action_packet` to split on `>>` and return the
   macro-tail list. (`engine.jl:1912`)
3. Extend `select_action` to return the macro-tail list as a
   3-tuple. (`engine.jl:2011`)
4. Extend `cast_vote` to receive macro tails, validate against
   `MACRO_SPEC_REGISTRY`, store on `Vote`. (`engine.jl:2850`)
5. New module `MacroPlugins.jl`:
   - `MacroSpec` struct
   - `MACRO_SPEC_REGISTRY :: Dict{String, MacroSpec}`
   - `MACRO_LOCK :: ReentrantLock`
   - `register_spec!`, `unregister_spec!`, `has_spec`,
     `_extract_macro_action_name`, `_extract_macro_args`,
     `_load_scope`, `_apply_template`, `resolve`
   - Built-in seeds (`%calculate%`, `%timeOf%`, `%reflect%`)
6. New beat-2 dispatch site in `Main.jl` (~line 1173): for each
   top-tier vote with non-empty `macro_actions`, call
   `MacroPlugins.resolve` per invocation, accumulate `macro_pieces`.
7. Add `extra_support_pieces` keyword arg to
   `generate_aiml_payload`; thread into the support_pieces
   assembly at `Main.jl:1497-1527`.
8. Slash-command surface: `/macro`, `/macroForce`, `/macroRemove`,
   `/macroList`, `/macroTest`. JSON parser; immune-gated.
9. Specimen save/load: serialize `MACRO_SPEC_REGISTRY`; load on
   boot if present, else seed defaults from `__init__()`.

**Phase 2 — quality-of-life.**
- `/macroTest` becomes interactive (live-step through a regex
  against a sample input).
- `:memory_hash` lookup gains intensity-weighted ranking and
  pinned-priority.
- Add `:since_event` scope (read `MESSAGE_HISTORY` from the last
  occurrence of a tagged event marker).
- Add `arithmetic`, `temporal`, `numeric`, `self_pronoun`,
  `affect_word` classes to enrich pattern-bind (orthogonal to
  macros but unblocks more selective voter patterns).

**Phase 3 — composition (deferred; do not design until phase 1
and 2 ship).**
- Macro-of-macros (one macro's resolution feeds another's regex).
- Conditional macros (a macro with multiple `(regex, scope,
  template)` branches that try in order until one matches).

---

## 10. What this plan deliberately rejects

- **A new `Node` subtype for macros.** Macros are votes' enforcement.
  Voter nodes are voter nodes.
- **A cycle-level macro registry iteration.** Activation is voter
  pattern-bind; macros only run for voters that won the cycle.
- **A custom multi-modal coherence dispatcher.** Not needed; scope
  selection (`current_input` / `last_*` / `memory_hash` / etc.)
  covers the practical coherence cases the user named.
- **Per-node `macro_signal` field.** Macros are written into
  voter `action_packet`s after `>>`, carried on `Vote.macro_actions`
  through dispatch, and never persist anywhere else.
- **Functor / resolver registry.** Removed. Macro is `(regex,
  scope, template)`. No closures, no Julia-side pluggable behaviors.
- **Arg-parser registry.** Removed. The macro's regex IS the
  arg parser.
- **`MacroFact` envelope.** Removed. Macro output is `String`.
- **`semantic_role` taxonomy and the skeleton-aware clause
  dispatcher.** Removed. AIML doesn't know macros exist.
- **Sandboxed Julia REPL eval / lambda-grade meta-programming.**
  Removed. *"no functor or whackyness needed."* If the user wants
  computation, they handle it downstream of the macro's substring
  surfacing.
- **Two-channel render (rule-board + synthesis weaving).** Removed.
  One channel: macros resolve before render, resolved strings join
  `support_pieces`, AIML weaves.
- **AIML keyword arguments for macros.** None. The only AIML touch
  is the existing `support_pieces` Vector receiving more entries
  via the `extra_support_pieces` kwarg.
- **Template-paste output.** Macros never produce rigid sentence
  structures; the resolved string goes through `_swap_words_in`
  and the existing organic synthesis machinery.
- **Macros as `COMMANDS` entries.** Removed. Macros are NOT in
  `COMMANDS`. They're a separate `MACRO_SPEC_REGISTRY`. Primary
  actions remain `COMMANDS` entries.

---

## 11. Open questions still requiring sign-off before code

1. **`memory_hash` ranking on multi-match.** Phase 1 returns the
   first match. Acceptable, or do we need pinned-priority +
   intensity-weighted from day one?

2. **Empty-resolution semantic.** When a macro's regex matches
   nothing and `fallback` is empty, the macro contributes nothing.
   Should it instead contribute a sentinel string like
   `"<no match for %macro%>"` so AIML can voice-over its absence?
   Phase 1 does silent nothing.

3. **Multi-match within a single scope.** When the regex has multiple
   matches in `:current_input` (e.g. `"what is 2+2 and 3+3"`), phase
   1 takes the first. Should we instead push one resolved string per
   match into `macro_pieces`? (This would let a single
   `%calculate%` macro surface both arithmetic expressions in a
   compound query.)

4. **Sigil enforcement.** Phase 1 sigils are cosmetic. Should we
   warn (or hard-error) if a `%X%` macro uses `:memory_hash` scope,
   given the `&X&` convention? Default to no enforcement.

5. **Built-in seed set.** Three macros seed at `__init__()`:
   `%calculate%`, `%timeOf%`, `%reflect%`. Add `%greet%`,
   `%recallTopic%`, `%dateOf%`? Or keep the seed set minimal and
   let users register their own?

6. **Inhibition strings on macro invocations.** The prior revision
   allowed `%calculate%[don't show work]^2.0` syntax. The new
   model has no concept of "weight" on a macro (they all fire
   unconditionally). Inhibitions could still be passed through to
   AIML's existing inhibition router. Phase 1: drop inhibitions
   on macro tails entirely, force voters to put them on the
   primary half. Confirm.

7. **Specimen migration.** No prior-revision specimens exist
   (this plan never landed code). Confirm migration is a non-issue.

8. **`MACRO_SPEC_REGISTRY` scope.** Specimen-local (per-specimen
   macros), or global (cross-specimen)? Phase 1: specimen-local,
   following the same convention as nodes.

9. **`:relational_triples` scope (deferred to phase 2).** A macro
   regex against the carrier `Vote.user_triples` would let macros
   surface complex relational structure (causal chains,
   multi-clause subjects) that mode-3 `extract_dynamic_relational_triples`
   has already extracted. Phase 1 does not include this scope —
   complexity-gated activation is handled by the voter's
   `relational_patterns` (existing) rather than at the macro level.
   Confirm phase deferral, or promote to phase 1 if there's a
   concrete use case the existing scopes can't cover.

---

## 12. Quick-reference change-summary table

| location                                  | change                                                                                                  |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `engine.jl :: Vote`                       | + `macro_actions::Vector{String}` field (defaults `String[]`)                                          |
| `engine.jl :: parse_action_packet`        | + split on `>>` first; return `(positives, negatives, action_items, macro_tails)`                       |
| `engine.jl :: select_action`              | + return 3-tuple `(winning_action, negatives, macro_tails)`; coinflip over primary half only           |
| `engine.jl :: cast_vote`                  | + receive `macro_tails`; validate each against `MACRO_SPEC_REGISTRY`; store on `Vote`                  |
| `engine.jl` (snap helpers, §15)           | + `_snap` and `_snap_to_any` helpers (orthogonal hygiene; see prior revisions)                          |
| `Main.jl` (dispatch site, ~line 1173)     | + beat 2: for each top-tier vote, resolve every macro in `vote.macro_actions`, accumulate `macro_pieces` |
| `Main.jl :: generate_aiml_payload`        | + `extra_support_pieces::Vector{String}=String[]` kwarg; appended to `support_pieces` after `_swap_words_in` |
| `Main.jl` (slash command parser)          | JSON parser for `/macro` + `/macroForce`; literal matchers for `/macroRemove`, `/macroList`, `/macroTest` |
| **NEW** `MacroPlugins.jl`                 | `MacroSpec`, `MACRO_SPEC_REGISTRY`, `MACRO_LOCK`, `register_spec!`, `unregister_spec!`, `has_spec`, `_extract_macro_action_name`, `_extract_macro_args`, `_load_scope`, `_apply_template`, `resolve`, `__init__()` seeds |
| `GrugBot420.jl`                           | include `MacroPlugins.jl` between `engine.jl` and `AIMLNodeSystem.jl`                                   |
| Specimen JSON                             | + top-level `MACRO_SPEC_REGISTRY` array (specs persist; built-ins seeded only on greenfield boot)       |

**REMOVED from the prior revision (no longer in this plan):**
- `RESOLVER_REGISTRY`, `ARG_PARSER_REGISTRY`, `MacroFact`,
  `_repl_eval`, `_MacroEvalSandbox`, `_validate_ast`,
  `CycleContext` (as a struct), `_macro_fact_to_clause`,
  `semantic_role` taxonomy, two-channel render, `primary_output`
  AIML kwarg, `macro_fact` AIML kwarg, `AIMLResolvers.jl` module
  (becomes unnecessary — there are no resolvers to gather).

---

*End of plan. No code lands until §11 open questions are resolved.
Architecturally settled: macros are `(regex, scope, template)`
enforcement directives optionally attached to a vote via the
`>>` action_packet tail; pattern-bind handles activation using
existing engine surfaces; resolution is regex-extract-or-memory-
lookup-and-substitute, producing a plain string that joins the
`support_pieces` stream pre-AIML; AIML synthesis is unchanged.
The whole macro runtime is one small module, ~150 lines including
JSON parsing, scope dispatch, template substitution, and slash
command surface.*

---

## 13. Relational delta and meta-arrows

(Carried forward from prior revisions; orthogonal to macro
internals and unchanged by this revision.)

The substrate's deeper move is that *meaning is relational delta,
not absolute label*. Two arrows pointing at the same target with
different tails carry different role-context. This plan preserves
that principle: macros do not assign roles; they extract substrings
or look up memories, and the substrate's existing relational
machinery interprets those strings in their relational context.

A future phase 2 could add a `:relational_delta` scope that
extracts the delta-vector between two arrows in the cycle's
`basic_triples` / `dynamic_triples`, but phase 1 has no such scope.
The existing scopes already cover the user-named use cases.

---

## 14. Sigils — visual discipline for user-defined action names

(Carried forward; cosmetic only in phase 1.)

The three sigil pairs `%X%`, `&X&`, `@X@` are conventions for
human readers of action_packet strings, not load-bearing parser
distinctions. Phase 1 enforces only that the action_name be
sigil-bracketed (so a future phase can add semantic enforcement
without breaking existing specs). The substrate's macro
resolution is sigil-agnostic.

---

## 15. Fuzzy snap-rounding at decision boundaries

(Carried forward; orthogonal hygiene unchanged by this revision.)

`_snap(x, eps=0.01)` rounds floating-point comparisons at decision
boundaries to prevent borderline-flicker. Insert at:
- bioavailability gates (already removed for macros, but still
  used elsewhere for tier selection)
- top-tier window comparisons
- apoptosis strength thresholds
- confidence-threshold gates for AIML eligibility

The macro resolution path itself uses no floating-point comparisons
(regex match is boolean), so snap-rounding has no macro-specific
sites. It's listed here because it remains an engine-wide hygiene
deliverable independent of the macro plugin.
