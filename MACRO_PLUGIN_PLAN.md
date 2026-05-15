# Voter-Carried Semantic Macro Plug-in System — Comprehensive Plan

> **Status:** design plan, no code yet. Synthesis of the full grugbot420
> codebase audit (re-verified against `grug-group420/grugbot420` HEAD
> `21d5687` "v7.22: Strength-driven solidification") and the user's eight
> progressive clarifications across this design session.
>
> **Replaces / supersedes:** `VOTER_MACRO_SIGNAL_DESIGN.md`,
> `MACRO_IMPLEMENTATION_APPRAISAL.md`. Those are kept for history; this
> document is the authoritative plan.
>
> **Scope:** grugbot420 only. No analog-turing.

---

## 0. Problem statement (re-stated cleanly)

The existing pipeline is `pattern bind → cast_vote → select_aiml_votes →
AIML executive → orchestration rules → reply`. Orchestration rules
substitute frame-level `{TAG}` placeholders that describe *the current
voting cycle's statistics* — `{MISSION}`, `{PRIMARY_ACTION}`,
`{CONFIDENCE}`, `{NODE_ID}`, etc.

These tags cannot pull a **live world value**. They are reflections of
the vote, not pulls from the world. The user wants a way for AIML
templates to splice in *world values* — current time, current weather,
the result of an arithmetic expression, the user's IP, a literal canned
response — alongside the existing pattern-bind-driven action vote.

The mechanism is **voter-carried**: a voter node (the population in
`engine.jl`, `mutable struct Node`) optionally carries a **macro
signal** as a secondary payload. When that node's primary vote wins the
AIML lock-in, the macro it carries is in scope for AIML to fill in. The
fill-in step is a second `replace(...)` pass in `generate_aiml_payload`,
substituting `%NAME%` placeholders against live resolver output.

Eight things sharpen this:

1. The macro lives on the **voter node**, not on AIML nodes.
2. The macro fires for **simple OR complex inputs**. No scan_mode gate.
3. **Bioavailability**: only **lock-ins** (top-tier winners, the
   high-confidence hard selections) get to fire macros. The pattern-bind
   peg is more bioavailable than the macro peg.
4. **Single-fire dedup per cycle**. `%TIME%` resolves once per cycle no
   matter how many carriers carry it or how many rules reference it.
5. **Inherited activator**. The macro is a property attached *to* a node,
   but its *eligibility on a given input* does NOT require the node's
   own stored pattern to match the input. The macro consults the
   **input's semantic context**, not the node's pattern.
6. **Coherence not fidelity**. Hippocampal-style: the question is "does
   this input *cohere* with what this macro is about", not "does this
   input contain my keywords". Brittle keyword overlap is rejected.
7. **Multi-modal**. Different macros are about different things. Each
   macro declares which semantic subsystems it consults — action_family,
   tone_family, verb_class, lemma_class, arousal, triple-object class.
   À la carte, not a fixed recipe.
8. **Basic vs dynamic awareness**. Both `ActionTonePredictor` and
   relational-triple extraction have basic (every input) and dynamic
   (richer at scan_mode 3) modes. The coherence dispatcher transparently
   reads whichever signal exists for the cycle.

The plan below honors all eight.

---

## 1. Code-level reality check (verified against fresh HEAD)

Before any new design, here is what currently exists and how the macro
pieces slot in. Line numbers from `21d5687`.

### 1.1 Node struct (`engine.jl:433`)

```
mutable struct Node
    id::String
    pattern::String
    signal::Vector{Float64}
    action_packet::String
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

The macro lives here as one new field. See §3.1.

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
end
```

Adding `macro_signal::String` (default `""`) is one field on `Vote` and
one assignment line in `cast_vote`. See §3.2.

### 1.3 `cast_vote` (`engine.jl:2850`)

```julia
function cast_vote(id, conf, antimatch, u_trips, n_trips)
    ...
    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch)
end
```

The macro propagation is a single line: `node.macro_signal` is read and
threaded into the new `Vote` constructor. **Unconditional copy** — no
input-shape gate, no scan_mode check. The bioavailability gate happens
later, in the AIML lock-in stage. See §4.

### 1.4 `screen_input_complexity` (`engine.jl:2042`)

```
complexity_score = (sig_len * 0.15) + (rel_count * 1.5)
< 1.5 → mode 1
< 4.5 → mode 2
≥ 4.5 → mode 3
```

This **does not gate macros**. It only gates which relational extractor
is used. Documented here only because the macro coherence dispatcher
needs to read the resulting `scan_mode` to pick basic vs dynamic
triples. See §6.4.

### 1.5 `extract_relational_triples` vs `extract_dynamic_relational_triples`
(`engine.jl:132` and `engine.jl:197`)

- `extract_relational_triples(input)` — basic, runs on every input.
- `extract_dynamic_relational_triples(input, scan_mode)` — internally
  short-circuits to basic when `scan_mode < 3`. So calling it always
  returns *something*, but the rich extraction only happens at mode 3.
- Call site in `engine.jl:2396`: `user_triples = if scan_mode >= 3
  extract_dynamic_relational_triples(...)  else extract_relational_triples(...) end`.

For macro coherence: the dispatcher reads the same triples the engine
already produced for the cycle. No re-extraction.

### 1.6 `ActionTonePredictor.predict_action_tone`
(`ActionTonePredictor.jl:594`)

Returns:

```
struct PredictionResult
    action_family       ::ActionFamily          # top-pick
    tone_family         ::ToneFamily            # top-pick
    confidence          ::Float64
    incomplete_chain    ::Bool
    dangling_verb       ::Union{String, Nothing}
    arousal_nudge       ::Float64
    action_weight       ::Float64
    timestamp           ::Float64
    action_distribution ::Dict{ActionFamily, Float64}   # ALWAYS POPULATED
    tone_distribution   ::Dict{ToneFamily, Float64}     # ALWAYS POPULATED
    trajectory_damped   ::Bool
end
```

**Important correction to my earlier drafts**: there is *not* a separate
"dynamic ATP" struct that fires only on complex inputs. The same
`PredictionResult` is returned every time. What changes with complexity
is the *internal* Lorenz-damping behavior (gini-coefficient-driven
trajectory damping for distributions that drift toward attractors). The
distributions are always available regardless of scan_mode.

Practical consequence: the `af:` and `tf:` modalities can read either
the top-pick (`action_family`) or the full distribution
(`action_distribution[FAMILY] >= threshold`). The latter is the more
robust read because it captures situations where the top-pick is borderline
but the family still has substantial mass. **Phase 1 uses top-pick for
simplicity; phase 2 escalates to distribution-mass reads.**

### 1.7 `select_aiml_votes` (`VoteOrchestrator.jl:578`)

Returns three buckets:

- `top_tier::Vector{VoteCandidate}` — within `AIML_TOP_TIER_WINDOW = 0.05`
  of max, above `AIML_CONFIDENCE_THRESHOLD = 0.15`. **Auto-locked**, no
  coinflip.
- `subtop_tier::Vector{VoteCandidate}` — above threshold, below top
  window. **Strength-biased coinflip survivors only.**
- `rejected_tier::Vector{VoteCandidate}` — below threshold or lost the
  coinflip.

The bioavailability rule (§5) reads: **macros fire only from `top_tier`.**
`subtop_tier` survivors contribute their *primary action vote* but their
`macro_signal` is dropped before `locked_macros` is computed.

### 1.8 `VoteCandidate` (`VoteOrchestrator.jl:528`)

```
struct VoteCandidate
    node_id::String
    confidence::Float64
    strength::Float64
    strength_cap::Float64
end
```

Adding `macro_signal::String` here is one field. The candidate is
constructed in `Main.jl::ephemeral_aiml_orchestrator` (line ~1097) and
needs that one extra arg pulled from the source `Vote`.

### 1.9 `ephemeral_aiml_orchestrator` (`Main.jl:1075`)

This is where:
- Votes are sorted by confidence.
- `VoteCandidate`s are built under `NODE_LOCK`.
- `select_aiml_votes` is called.
- `top_tier` / `subtop_tier` / `rejected_tier` are returned.
- `sure_votes` (= top_tier mapped back to Vote) and `unsure_votes` (=
  subtop) are passed into `COMMANDS[action](...)` which routes to
  `generate_aiml_payload`.

The new `locked_macros` computation lives here. The new `CycleContext`
bundle is built **before** `select_aiml_votes` is called and is threaded
through to `COMMANDS[action]` via the same `node.json_data` /
`context::Dict` channel that already plumbs through to
`generate_aiml_payload`.

### 1.10 `generate_aiml_payload` (`Main.jl:1191`)

The hot spot. The existing for-loop:

```julia
for rule in AIML_DROP_TABLE
    if rand() > rule.fire_probability
        continue
    end
    processed = rule.text
    processed = replace(processed, "{MISSION}"        => mission)
    processed = replace(processed, "{PRIMARY_ACTION}" => primary_vote.action)
    ...
    push!(evaluated_rules, processed)
end
```

The macro pass goes **inside this same loop, after the last `{TAG}`
substitution, before `push!`**. Per-rule, so unfired rules don't pay
the macro cost.

### 1.11 `add_orchestration_rule!` validator (`engine.jl:3127`)

```julia
for m in eachmatch(r"\{[A-Z_]+\}", rule_text)
    tag = m.match
    if !(tag in ALLOWED_RULE_TAGS)
        error("!!! FATAL: Grug see fake magic rock: $tag! ...")
    end
end
```

This forces macro syntax to NOT use `{}`. `%NAME%` is the answer — the
validator literally cannot see it, and visually it's distinct from
frame-level `{TAG}` substitutions.

### 1.12 Slash command idiom (`Main.jl` 4290+)

Pattern: regex match against the raw line, optional `immune_gate(...)`
check, then call into the appropriate registry function (`SemanticVerbs.add_verb!`,
`Thesaurus.add_seed_synonym!`, etc.). The new `/macro` command follows
exactly this idiom.

### 1.13 Module load order (`GrugBot420.jl`)

```
stochastichelper → patternscanner → ImageSDF → EyeSystem → SemanticVerbs
→ ActionTonePredictor → LobeTable → Lobe → BrainStem → Thesaurus
→ InputQueue → ChatterMode → PhagyMode → ImmuneSystem → ImmuneThreadPool
→ FullLobeScanner → RelationalJitter → AIMLNodeSystem → VoteOrchestrator
→ engine.jl → Main.jl
```

The new `MacroTriggers.jl` module slots in **after RelationalJitter**
(so it can reference jitter for the coinflip primitives in phase 3) and
**before AIMLNodeSystem** (so AIML can reference it during render). The
new `AIMLResolvers.jl` lives next to it. Both must be loaded before
`engine.jl` since `cast_vote` will need the trigger registry's
existence.

---

## 2. Mental model — the two activation pegs

Borrowing the user's hippocampus / basal ganglia / prefrontal-cortex
metaphor:

| peg                 | bioavailability | scope         | content                     | analog                           |
|---------------------|-----------------|---------------|-----------------------------|----------------------------------|
| **Pattern-bind**    | High            | Per-node      | Node's stored `pattern`     | Hippocampal/basal-ganglia recall |
| **Semantic macro**  | Low             | Universal     | Plug-in name (e.g. `%TIME%`)| Prefrontal executive integration |

**Pattern-bind** is high-bioavailability — many nodes can compete on
their own stored content; their pattern-bind output is unique to each
node; many can fire in the same cycle.

**Semantic macro** is low-bioavailability — only top-tier lock-in
winners qualify, and a given macro can fire only once per cycle no
matter how many carriers exist.

Crucially, **the macro is universal**: `%TIME%` resolves the same way
regardless of which node carried it — `time#7`, `clock#3`, or even
`dog#42` if the user opted that node in. The carrier node's stored
pattern doesn't constrain the macro's content; it only determines who
gets to be eligible to fire it.

This is the "inherited activator" idea: the macro is grafted onto the
node, but its *firing eligibility on the input* is judged by an
input-side coherence check that consults the engine's already-computed
semantic signals — not by the carrier node's pattern.

---

## 3. Struct additions — one field per struct, all defaults are `""`

### 3.1 `engine.jl :: Node`

Add:

```
macro_signal :: String     # default ""
```

`""` means "no macro". Most nodes will never set this.

Specimen save/load: serializes trivially as a JSON string.
Old specimens lacking the field default to `""` on load.

### 3.2 `engine.jl :: Vote`

Add:

```
macro_signal :: String     # default ""
```

`cast_vote` returns:

```julia
Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch, node.macro_signal)
```

Unconditional copy. No gate, no scan_mode check. If the carrier later
loses the AIML lock-in cut, the macro is dropped at the lock-in stage
(§5).

### 3.3 `VoteOrchestrator.jl :: VoteCandidate`

Add:

```
macro_signal :: String     # default ""
```

`ephemeral_aiml_orchestrator` (Main.jl:1097) builds candidates with the
new arg pulled from `v.macro_signal`. `select_aiml_votes` is unchanged
— the macro rides through.

### 3.4 New `MacroTriggers.jl` (module)

Lives between `RelationalJitter.jl` and `AIMLNodeSystem.jl` in the
include order.

Top-level state (all behind a single `ReentrantLock`):

```
const MACRO_TRIGGER_REGISTRY :: Dict{String, MacroTrigger}
const RESOLVER_REGISTRY      :: Dict{String, Function}
const MACRO_TRIGGER_LOCK     :: ReentrantLock
const MACRO_COHERENCE_THRESHOLD :: Ref{Float64}   # default 0.60
const MACRO_STRICT_MODE         :: Ref{Bool}      # default false (warn-only)
```

The two `Ref{...}` config knobs sit alongside `AIML_CONFIDENCE_THRESHOLD`
in spirit — runtime-tunable via `/setMacroCoherence <float>` and
`/setMacroStrict on|off`.

`MacroTrigger` struct:

```
struct MacroTrigger
    name         :: String           # e.g. "current_time"
    placeholder  :: String           # e.g. "%TIME%"
    profile      :: MacroCoherenceProfile
    kind         :: Symbol           # :builtin | :user_resolver | :user_text | :remote
    payload      :: MacroPayload     # discriminated union (see §3.5)
end
```

### 3.5 `MacroFact` and `MacroPayload`

#### 3.5.1 `MacroFact` — the resolver return type

A resolved macro is **not just a string**. It is a small envelope that
carries a canonical phrasing PLUS the structured data behind it, so the
synthesis layer (§7b) can re-phrase organically rather than splice
verbatim:

```
struct MacroFact
    placeholder    :: String                          # e.g. "%TIME%"
    semantic_role  :: Symbol                          # e.g. :current_time
    rendered_text  :: String                          # canonical phrasing fallback
    structured     :: Union{Nothing, Dict{String, Any}}   # rich form for synthesis
end
```

- `placeholder` matches the trigger's `placeholder` field.
- `semantic_role` is the small fixed taxonomy synthesis dispatches on
  (see §3.5.4).
- `rendered_text` is what gets used when synthesis decides to splice
  verbatim, AND what gets used in the rule-board substitution channel
  (§7a). It must always be a non-empty string when the resolver
  succeeds.
- `structured` is optional. World-value resolvers like `time_utc` fill
  it with parsable parts (`Dict("hh"=>14, "mm"=>32, "tz"=>"UTC")`).
  Introspection resolvers like `reflect_self` lean on this heavily so
  synthesis can re-phrase without re-parsing English. Text payloads
  leave it `nothing`.

#### 3.5.2 `MacroPayload` — discriminated union (literal text / resolver / remote)

The third positional arg of `/macro` is *both* a code-backed resolver
*and* a literal text body, auto-detected. Three concrete payload shapes:

```
struct ResolverPayload         # kind == :builtin OR :user_resolver
    resolver_id :: String      # key into RESOLVER_REGISTRY
end

struct TextPayload             # kind == :user_text
    text :: String             # literal substitution body
end

struct RemotePayload           # kind == :remote (phase 2)
    url_template :: String     # e.g. "https://wttr.in/{q}?format=j1"
    json_path    :: String     # e.g. ".current_condition[0].temp_C"
    timeout_s    :: Float64
end

const MacroPayload = Union{ResolverPayload, TextPayload, RemotePayload}
```

The auto-detection at registration time:

1. If the third arg matches a key in `RESOLVER_REGISTRY` →
   `ResolverPayload(resolver_id)`.
2. Else → `TextPayload(literal)`. The literal can be a quoted string
   (recommended: `"hello there friend"`) or an unquoted single token
   (e.g. `hi`).
3. Phase 2: `/macroRemote <name> <url> <jq>` writes a `RemotePayload`.

#### 3.5.3 Resolver signature and resolution

The resolver registry stores **functions of `(CycleContext) -> MacroFact`**:

```
const RESOLVER_REGISTRY :: Dict{String, Function}   # all entries: (ctx::CycleContext) -> MacroFact
```

World-value resolvers (`time_utc`, `calc_eval`) ignore `ctx` for their
own data but use it to build the right `MacroFact` envelope.
Introspection resolvers (`reflect_self`, `mood_summary`) read heavily
from `ctx`. Text payloads bypass the function-call machinery entirely.

```julia
function resolve_payload(p::ResolverPayload, trigger::MacroTrigger, ctx::CycleContext)::MacroFact
    fn = lock(MACRO_TRIGGER_LOCK) do
        get(RESOLVER_REGISTRY, p.resolver_id, nothing)
    end
    isnothing(fn) && error("!!! FATAL: macro resolver '$(p.resolver_id)' not registered !!!")
    fact = fn(ctx)::MacroFact
    # Trust but verify: resolver must populate placeholder + non-empty rendered_text.
    isempty(fact.rendered_text) && error("!!! FATAL: resolver '$(p.resolver_id)' returned empty rendered_text !!!")
    return fact
end

function resolve_payload(p::TextPayload, trigger::MacroTrigger, ctx::CycleContext)::MacroFact
    return MacroFact(trigger.placeholder, :literal_text, p.text, nothing)
end

function resolve_payload(p::RemotePayload, trigger::MacroTrigger, ctx::CycleContext)::MacroFact
    # phase 2: HTTP fetch, JSON-path extract, build MacroFact.
    ...
end
```

This is the only place the resolver registry is consulted at fire time.
Per-cycle caching (§7) wraps this so a resolver function fires at most
once per cycle per macro name.

#### 3.5.4 The `semantic_role` taxonomy (phase 1)

Synthesis dispatches on `semantic_role` to choose how a fact is phrased
under each action-family skeleton. The phase-1 set is small and fixed:

| role             | typical resolver | typical use                                       |
|------------------|------------------|---------------------------------------------------|
| `:current_time`  | `time_utc`       | "the current time is X"                           |
| `:current_date`  | `date_utc`       | "today is X"                                      |
| `:calculation`   | `calc_eval`      | "that comes out to X"                             |
| `:self_narrative`| `reflect_self`   | "leaning toward X over Y"                         |
| `:mood`          | `mood_summary`   | "feeling X right now"                             |
| `:uncertainty`   | `uncertainty_phrase` | "fairly confident" / "a bit torn"             |
| `:literal_text`  | (text payload)   | verbatim substitution, no re-phrasing             |

Phase 2 expands this with `:current_weather`, `:network_self`,
`:topic_summary`, `:session_age`, etc. Adding a new role is purely
additive — a new resolver returns it, and `_macro_fact_to_clause` (§7b)
gets one more dispatch branch.

### 3.6 `MacroCoherenceProfile`

```
struct ModalityCheck
    source :: Symbol             # :action_family | :tone_family | :verb_class
                                 # | :lemma_class | :arousal | :triple_object_class
    match  :: Any                # source-specific (Symbol, String, Float64-comparator, ...)
    weight :: Float64            # default 1.0
end

struct MacroCoherenceProfile
    modalities :: Vector{ModalityCheck}
    combiner   :: Symbol         # :all (phase 1) | :any (phase 2) | :weighted (phase 2)
    threshold  :: Float64        # only used when combiner == :weighted (phase 2)
end
```

Phase 1 ships only `:all` — every declared modality must match. The
threshold knob `MACRO_COHERENCE_THRESHOLD = 0.60` becomes meaningful only
once `:weighted` lands in phase 2; for `:all` it's effectively 1.0.

Reasoning: the user declared "soft tolerance ≥60%" but then immediately
pivoted to "coherence not fidelity, hippocampal not bag-of-keywords".
Coherence means: each declared modality is a separate, semantically
meaningful signal — not a token to be averaged. Treating them
all-must-match in phase 1 is honest about their distinctness. The 0.60
threshold knob is the phase-2 escape hatch when we want to allow a
2-out-of-3 modality match, but **the user-facing default is hard-AND**
because that matches the hippocampal "either the context coheres or it
doesn't" intuition better than a noisy mean.

---

## 4. The slash command — `/macro`

### 4.1 Surface syntax

```
/macro %NAME% <modality_tag> [<modality_tag> ...] <payload>
```

Where:
- `%NAME%` is the placeholder, must match `r"^%[A-Z_]+%$"`.
- Modality tags are `key:value` pairs, space-separated, all AND
  (combiner = `:all`) in phase 1.
- `<payload>` is either a registered resolver name (auto-detected
  against `RESOLVER_REGISTRY`) or a quoted literal string or an
  unquoted single token.

### 4.2 Modality tag prefixes (phase 1 + planned phase 2)

| tag    | source                      | match argument                    | reads from                          | phase |
|--------|-----------------------------|-----------------------------------|-------------------------------------|-------|
| `af:`  | `action_family` (ATP)       | symbol or set: `query`, `query,command` | `prediction.action_family` / `action_distribution` | 1     |
| `tf:`  | `tone_family` (ATP)         | symbol or set: `curious`, `urgent` | `prediction.tone_family` / `tone_distribution`     | 1     |
| `vc:`  | `verb_class` (SemanticVerbs) | class name: `temporal`, `causal`   | `verb_class_of()` over input verbs  | 1     |
| `lc:`  | `lemma_class` (patternscanner+thesaurus) | named class: `numeric`, `pronoun_self` | input token classification | 1     |
| `ar:`  | `arousal` (EyeSystem)       | comparator: `>0.6`, `<0.3`         | `EyeSystem.get_arousal()`           | 1     |
| `to:`  | `triple_object_class`       | class label: `location`, `temporal_anchor` | basic OR dynamic triples (whichever the cycle produced) | 1 |

(Phase 2 adds `clauses:>=2`, `dynamic:on`, `tonemix:weighted`, etc.)

### 4.3 Examples

**Built-in code-backed resolvers** (registered at module init):

```
/macro %TIME%    af:query  vc:temporal               time_utc
/macro %DATE%    af:query  vc:temporal               date_utc
/macro %CALC%    vc:arithmetic  lc:numeric           calc_eval
```

**User-defined literal text** (no code change):

```
/macro %GREETING% af:assert  vc:social_greet         "hello there friend"
/macro %SHRUG%    af:assert  tf:reflective           "i dunno man"
```

**Phase 2 remote resolvers** (separate command):

```
/macroRemote weather_wttr  https://wttr.in/{q}?format=j1  .current_condition[0].temp_C
/macro %WEATHER% af:query  vc:weather                weather_wttr
```

### 4.4 Companion slash commands

```
/macro %NAME% <tags> <payload>     # add (or replace) trigger
/macroRemove %NAME%                # remove trigger
/macroList                         # pretty-print all triggers + their modalities
/macroRemote <id> <url> <json_path>  # phase 2 — register a remote resolver
/nodeMacro <node_id> %NAME%        # attach %NAME% to a voter node
/nodeMacroClear <node_id>          # detach (sets node.macro_signal = "")
/setMacroCoherence <float>         # tune MACRO_COHERENCE_THRESHOLD (phase 2)
/setMacroStrict on|off             # tune MACRO_STRICT_MODE
```

All gated by `immune_gate(...)` like the existing `/addVerb`,
`/addSynonym`, etc.

### 4.5 Why placeholder uniqueness is enforced at registration

Two registered macros pointing at the same `%TIME%` placeholder makes
fire-time substitution ambiguous. So `register_macro_trigger!` does:

```julia
for existing in values(MACRO_TRIGGER_REGISTRY)
    if existing.placeholder == new.placeholder && existing.name != new.name
        error("!!! FATAL: placeholder collision: $(new.placeholder) already used by $(existing.name) !!!")
    end
end
```

Loud failure, no silent ambiguity. Same convention as the rest of
grugbot420.

---

## 5. The bioavailability gate

Re-stated as code logic (sketch, not committed):

```julia
# in ephemeral_aiml_orchestrator, after select_aiml_votes:

# (a) Build the cycle context bundle (see §6).
ctx = build_cycle_context(mission, scan_mode, prediction, basic_triples, dyn_triples)

# (b) Map top-tier candidates back to Votes.
sure_votes = Vote[candidate_to_vote[vc.node_id] for vc in top_tier]

# (c) Bioavailability gate: only top-tier macros even compete.
top_tier_macro_names = unique(filter(!isempty,
    String[v.macro_signal for v in sure_votes]))

# (d) Coherence eligibility: which macros' profiles match the input context?
coherence_eligible = Set{String}()
for name in top_tier_macro_names
    trig = get_macro_trigger(name)
    isnothing(trig) && (@warn "[MACRO] orphaned macro_signal: $name"; continue)
    if check_coherence(trig.profile, ctx)
        push!(coherence_eligible, name)
    end
end

# (e) locked_macros = (carried by top-tier) ∩ (coherence-eligible).
locked_macros = collect(coherence_eligible)

# (f) Pass through to AIML render.
context_dict["__locked_macros__"] = locked_macros
context_dict["__cycle_context__"]  = ctx   # in case AIML wants to inspect
```

Five things to nail down explicitly:

1. **Sub-top survivors do NOT contribute macros.** Their `macro_signal`
   field is read off the `Vote` struct but never enters `top_tier_macro_names`.
   Their primary action vote still counts (they may appear in
   `unsure_votes`), but the macro slot is dropped.

2. **No second selection pass.** No "macro selection coinflip". The
   strength-biased coinflip already happened at vote-time; the
   bioavailability gate is just `top_tier ∩ coherence_eligible`.

3. **Single-fire dedup**. `unique(...)` on the macro names handles
   carrier-side dedup. Per-cycle resolver caching (§7) handles
   render-side dedup so multiple `%TIME%` references in multiple rules
   resolve once.

4. **Orphaned macros warn but don't kill.** A node with
   `macro_signal = "current_time"` but `current_time` not in the
   registry (e.g. user removed the trigger after attaching) emits a
   `@warn` and is skipped. Loud-but-not-fatal — same idiom as other
   non-fatal degradation in the engine (e.g. ATP arousal nudge failure).

5. **Empty `locked_macros` is normal.** Most cycles will have it empty.
   The render pass skips trivially.

---

## 6. The CycleContext — multi-modal signal bundle

Built inside `Main.jl::process_mission`, between `screen_input_complexity`
and the `ephemeral_aiml_orchestrator` call.

### 6.1 Struct shape

```
struct CycleContext
    mission             :: String
    scan_mode           :: Int                          # 1 | 2 | 3
    prediction          :: Union{Nothing, ActionTonePredictor.PredictionResult}
    basic_triples       :: Vector{RelationalTriple}
    dynamic_triples     :: Union{Nothing, Vector{RelationalTriple}}  # only at mode 3
    arousal             :: Float64
    verb_classes_seen   :: Set{String}                  # SemanticVerbs.verb_class_of for each input verb
    lemma_classes_seen  :: Set{String}                  # patternscanner / thesaurus output
    timestamp           :: Float64
end
```

This bundle is constructed **once per cycle**, populated from signals
the engine already produces. No re-extraction. The macro coherence
check is a series of cheap field reads against this struct.

### 6.2 Where it gets built

In `Main.jl::process_mission`, the call sequence is approximately:

1. Parse mission, lemmatize, etc.
2. `screen_input_complexity(...)` → `scan_mode`.
3. ATP `predict_action_tone(...)` → `prediction` (already runs around line 2050).
4. Extract triples (basic always, dynamic at mode 3).
5. **NEW**: `ctx = build_cycle_context(mission, scan_mode, prediction, basic_triples, dynamic_triples, arousal)`.
6. `scan_specimens(...)` — voter scan fires.
7. `ephemeral_aiml_orchestrator(mission, votes, ctx)` — orchestrator
   gets the context bundle and uses it for coherence checks (§5).

The bundle is read-only after construction.

### 6.3 Modality dispatcher

```julia
function check_modality(m::ModalityCheck, ctx::CycleContext)::Bool
    return _check_modality_dispatch(Val(m.source), m.match, ctx)
end

# Dispatched on Val(source) for compile-time selection. Each branch:
function _check_modality_dispatch(::Val{:action_family}, want, ctx)::Bool
    isnothing(ctx.prediction) && return false
    wanted_set = _normalize_action_family_set(want)   # accept :query, [:query,:command], "query,command"
    return ctx.prediction.action_family in wanted_set
end

function _check_modality_dispatch(::Val{:tone_family}, want, ctx)::Bool
    isnothing(ctx.prediction) && return false
    wanted_set = _normalize_tone_family_set(want)
    return ctx.prediction.tone_family in wanted_set
end

function _check_modality_dispatch(::Val{:verb_class}, want_class::String, ctx)::Bool
    return want_class in ctx.verb_classes_seen
end

function _check_modality_dispatch(::Val{:lemma_class}, want_class::String, ctx)::Bool
    return want_class in ctx.lemma_classes_seen
end

function _check_modality_dispatch(::Val{:arousal}, comparator::String, ctx)::Bool
    # comparator is e.g. ">0.6", "<0.3", ">=0.5"
    return _eval_numeric_comparator(comparator, ctx.arousal)
end

function _check_modality_dispatch(::Val{:triple_object_class}, want_class::String, ctx)::Bool
    triples = isnothing(ctx.dynamic_triples) || isempty(ctx.dynamic_triples) ?
              ctx.basic_triples : ctx.dynamic_triples
    return any(t -> _classify_triple_object(t.object) == want_class, triples)
end
```

### 6.4 Basic vs dynamic awareness — the `to:` modality and the `af:`/`tf:` distributions

The `to:` modality reads dynamic triples when they exist (mode 3) and
falls back to basic triples otherwise. **This is automatic**; the user
writing `/macro %FOO% to:location ...` doesn't have to know which
extractor produced the data.

For `af:` and `tf:` (phase 1 reads top-pick `action_family` and
`tone_family`):

- Mode 1/2 inputs: `prediction.action_family` is one symbol, computed
  from the basic ATP scoring. Match against the user's wanted set.
- Mode 3 inputs: same `prediction.action_family` (a single symbol), but
  computed under richer trajectory-damping conditions. The match is
  identical from the macro's perspective.

**Phase 2 escalation (deferred):** ship a richer modality variant
`af-mass:query>=0.4` that reads `prediction.action_distribution[QUERY] >= 0.4`.
This catches "query tendency" even when the top pick was a different
family. Same for `tf-mass:`. Phase 1 ships `af:` / `tf:` only.

### 6.5 Combiner

For phase 1, `combiner == :all`:

```julia
function check_coherence(profile::MacroCoherenceProfile, ctx::CycleContext)::Bool
    if profile.combiner == :all
        return all(m -> check_modality(m, ctx), profile.modalities)
    elseif profile.combiner == :any
        return any(m -> check_modality(m, ctx), profile.modalities)        # phase 2
    elseif profile.combiner == :weighted
        weighted_sum = sum(m.weight * (check_modality(m, ctx) ? 1.0 : 0.0)
                           for m in profile.modalities)
        total_weight = sum(m.weight for m in profile.modalities)
        return (weighted_sum / total_weight) >= profile.threshold           # phase 2
    else
        error("!!! FATAL: unknown coherence combiner: $(profile.combiner) !!!")
    end
end
```

---

## 7. The render pass — two channels, one resolver call

**This is the section the most recent user clarification rewrote.** A
naive single-pass `replace(template, "%TIME%" => "14:32 UTC")` produces
output like *"the time is 14:32 UTC"* glued onto whatever rule text
fired. That works for rule-board directives (which already feel
template-y and end up in the `[Directives: …]` tail), but it is the
wrong shape for the **spoken spine** of the response.

The user's exact framing:

> *"if you asked me what a dog is and what time it is. i wouldnt have
> preset response structures id just say it in a normal sentence."*

So `MacroFact` is consumed by **two channels in the same render pass**,
each fed by the **same per-cycle resolver call** (single-fire dedup
preserved):

| | §7a Rule-board channel | §7b Synthesis weaving channel |
|---|---|---|
| Where it lands | `[Directives: …]` tail of AIML payload | The spoken spine, woven into `support_pieces` |
| What it consumes | `MacroFact.rendered_text` | `MacroFact` as a whole (role + structured) |
| Operation | `replace(rule_text, "%TIME%" => fact.rendered_text)` | `_macro_fact_to_clause(fact, action_family)` → routed through `_swap_words_in` alongside triples / companion patterns / UNSURE hedges |
| Shape of output | Template-like, fine for directive tail | Organic clause, joins the synthesis pipeline at `Main.jl:1497–1527` |
| Purpose | Lets rule authors still write `"the time is %TIME%"` if they want | Default behaviour: macros become a 4th `support_pieces` source so the spine reads naturally |

Both channels see the same locked macro set, both use the same
per-cycle resolver cache, both honour single-fire dedup. The user's
"normal sentence" requirement is satisfied because §7b is the default
path for macros that aren't explicitly referenced by any fired rule's
template text — which is the common case for inherited activators.

### 7.1 Stage A — resolve once per cycle (shared by §7a and §7b)

Inside `generate_aiml_payload`, before the per-rule loop runs, build
the per-cycle macro fact cache:

```julia
locked_macros = get(context, "__locked_macros__", String[])
fact_cache    = get!(() -> Dict{String, MacroTriggers.MacroFact}(), context, "__macro_fact_cache__")
cycle_ctx     = context["__cycle_context__"]::MacroTriggers.CycleContext

for name in locked_macros
    haskey(fact_cache, name) && continue        # single-fire dedup
    trig = MacroTriggers.get_macro_trigger(name)
    isnothing(trig) && continue
    fact_cache[name] = try
        MacroTriggers.resolve_payload(trig.payload, cycle_ctx)
    catch e
        if MacroTriggers.MACRO_STRICT_MODE[]
            rethrow(e)
        else
            @warn "[MACRO] resolver '$(trig.name)' threw (non-fatal): $e"
            MacroTriggers.MacroFact(trig.placeholder, :unavailable, "<unavailable>", Dict{String,Any}())
        end
    end
end
```

This runs **once per cycle, regardless of how many rules reference any
given placeholder**. The cache survives both downstream channels. Each
resolver function is invoked exactly once per cycle even if three rules
all carry `%TIME%`.

### 7.2 Stage B (§7a) — rule-board substitution channel

Inside the existing per-rule loop in `generate_aiml_payload`
(`Main.jl:1216`-ish), after the last `{TAG}` substitution and before
`push!(evaluated_rules, processed)`:

```julia
# Channel §7a: rule-board template substitution.
for (name, fact) in fact_cache
    trig = MacroTriggers.get_macro_trigger(name)
    isnothing(trig) && continue
    processed = replace(processed, trig.placeholder => fact.rendered_text)
end

# Strict-mode survivor check.
if MacroTriggers.MACRO_STRICT_MODE[]
    surviving = collect(eachmatch(r"%[A-Z_]+%", processed))
    if !isempty(surviving)
        error("!!! FATAL: unresolved macro placeholders survived render: $(join([m.match for m in surviving], \", \")) !!!")
    end
else
    for m in eachmatch(r"%[A-Z_]+%", processed)
        @warn "[MACRO] unresolved placeholder $(m.match) left intact (strict mode off)"
    end
end

push!(evaluated_rules, processed)
```

What this preserves from the original design:

1. **Per-rule fire-probability gating preserved.** Rules that lost
   `rand() > rule.fire_probability` `continue`d before reaching the
   macro pass. Zero macro cost on unfired rules.
2. **Per-cycle resolver caching.** Caches now hold `MacroFact` not
   `String`; the substitution uses `fact.rendered_text`.
3. **Strict-mode survivor check.** Catches templates that reference
   `%FOO%` when `FOO` was never registered or didn't make the lock-in.
   Default warns, strict mode errors.

Output of this channel feeds the rule-board the same way every prior
rule-board string does: it lands in the `[Directives: …]` tail of the
AIML payload (see existing v7.16 wiring around `Main.jl:1560–1600`).
Acceptable — that tail has always read like a directive list.

### 7.3 Stage C (§7b) — synthesis weaving channel

This is the new channel. It runs **after** `evaluated_rules` is built
but **inside** `generate_aiml_payload`'s synthesis pipeline, at the
point where `support_pieces` is being assembled (currently
`Main.jl:1497–1527`, where triples / companion patterns / UNSURE hedges
get pushed into the `support_pieces` vector).

**The integration:** macros become a fourth `support_pieces` source.

```julia
# Channel §7b: synthesis weaving.  Macros become support_pieces.
# Runs alongside the existing three sources at Main.jl:1497-1527:
#   1. relational triples (basic / dynamic)
#   2. companion patterns
#   3. UNSURE hedges
# Now adds:
#   4. macro facts

for (name, fact) in fact_cache
    fact.semantic_role === :unavailable && continue
    clause = _macro_fact_to_clause(fact, action_family)   # see §7.4
    isempty(clause) && continue
    woven  = _swap_words_in(clause, swap_ctx)             # existing v7.16
    push!(support_pieces, woven)
end
```

`_swap_words_in` is the existing v7.16 synonym + inhibition router
(`Main.jl:1604`-area). It runs the candidate clause through:

- `Thesaurus.synonym_for(word)` lookup
- `SemanticVerbs.synonyms_for(verb)` for action-family-aware verb swaps
- AIML `drop_table` for filler removal
- `InputQueue` token inhibitions (recently-used-word suppression)

This means a macro-generated clause comes out the other side feeling
varied across cycles, not parroted. Two consecutive `%TIME%` fires
won't say the literal same thing.

### 7.4 The skeleton-aware phrasing dispatcher — `_macro_fact_to_clause`

This is the only genuinely new code in §7. It turns a `MacroFact` into
a short organic clause appropriate to the cycle's `action_family`. The
phase-1 surface is small: 6 semantic roles × ~3 action families that
matter most for fact-bearing utterances ≈ ~20 templates.

```julia
function _macro_fact_to_clause(fact::MacroFact, action_family::Symbol)::String
    role = fact.semantic_role
    txt  = fact.rendered_text
    s    = fact.structured

    # role-by-role dispatch.  Action family further branches phrasing.
    if role === :current_time
        af = action_family
        if af === :ACTION_QUERY
            return "it's $txt right now"
        elseif af === :ACTION_INFORM
            return "the clock reads $txt"
        elseif af === :ACTION_COMMAND
            return "as of $txt"
        else
            return "right now it's $txt"
        end

    elseif role === :current_date
        return action_family === :ACTION_QUERY ?
            "today is $txt" : "as of $txt"

    elseif role === :calculation
        # structured carries the parsed expression and result
        expr = get(s, "expression", "")
        return isempty(expr) ? "that comes out to $txt" : "$expr equals $txt"

    elseif role === :self_narrative
        # %REFLECT% — first-person introspection, no template glue
        return txt   # resolver already produced a sentence-like fragment

    elseif role === :mood
        return "i'm feeling $txt"

    elseif role === :uncertainty
        # %UNCERTAINTY% — hedges into the spine
        return txt   # e.g. "i'm not totally sure but"

    elseif role === :literal_text
        # canned text payloads — drop in as-is
        return txt

    else
        # unknown role: degrade gracefully, no template glue
        return txt
    end
end
```

Three things to note:

1. **No JSON-template scaffolding, no `[Time: %TIME%]` brackets.** The
   output is a clause fragment. The synthesis pipeline downstream
   handles capitalization, punctuation, and joining via the same path
   triples and companion patterns already use.

2. **Action-family branching is shallow on purpose.** Phase 1 covers
   QUERY/INFORM/COMMAND only. Other families fall through to a sane
   default. Phase 2 can extend per-family templates per role as needed.

3. **`:self_narrative`, `:uncertainty`, `:literal_text` pass-through.**
   Their resolvers already produce sentence-shaped output (see §8); the
   dispatcher just hands the string to `_swap_words_in`. This is the
   organic-output requirement honoured: introspective macros never get
   wrapped in a "the answer is X" template.

### 7.5 Conflict resolution between §7a and §7b

If a fired rule's template explicitly contains `%TIME%`, §7a substitutes
it inline. The same `MacroFact` *also* gets woven into `support_pieces`
by §7b. Result: the rule-board tail will mention the time, AND the
spoken spine may also reference it. **This is acceptable and matches
the "say things twice in different shapes" pattern that v7.16 synthesis
already produces** (e.g. claim + supporting triple often restate the
same idea).

Phase 2 can add `MacroTrigger.suppress_in_synthesis::Bool` to opt a
trigger out of §7b when its rule-board placement is sufficient. Phase 1
ships with both channels active for every locked macro.

---

## 8. Built-in resolvers — `AIMLResolvers.jl`

A new sibling module to `MacroTriggers.jl`. **Every resolver returns a
`MacroFact`, not a `String`.** This is the §3.5 contract. The
`rendered_text` field feeds §7a (rule-board); the `semantic_role` and
`structured` fields feed §7b's `_macro_fact_to_clause` dispatcher for
organic synthesis weaving.

The phase-1 surface is six resolvers covering all four macro
categories the user identified (world-value / self-introspective /
literal-text / [user-conversation deferred to phase 2]):

```julia
module AIMLResolvers
using Dates
using ..MacroTriggers: MacroFact, CycleContext

# === Category A: world-value ============================================

function time_utc(ctx::CycleContext)::MacroFact
    n  = now(UTC)
    hh = Dates.hour(n)
    mm = Dates.minute(n)
    rendered = Dates.format(n, "HH:MM \"UTC\"")
    return MacroFact("%TIME%", :current_time, rendered,
                     Dict{String,Any}("hh"=>hh, "mm"=>mm, "tz"=>"UTC"))
end

function date_utc(ctx::CycleContext)::MacroFact
    t = today()
    rendered = Dates.format(t, "yyyy-mm-dd")
    return MacroFact("%DATE%", :current_date, rendered,
                     Dict{String,Any}("y"=>Dates.year(t),
                                      "m"=>Dates.month(t),
                                      "d"=>Dates.day(t)))
end

function calc_eval(ctx::CycleContext)::MacroFact
    # Hand-rolled shunting-yard. Pulls the most recent numeric expression
    # from the cycle's mission text via tight regex. NEVER calls Meta.parse,
    # NEVER calls eval. Supports +, -, *, /, parentheses, decimals.
    expr = _extract_numeric_expression(ctx.mission_text)
    if isnothing(expr)
        return MacroFact("%CALC%", :calculation, "<no expression found>",
                         Dict{String,Any}("expression"=>"", "result"=>nothing))
    end
    result = _safe_arithmetic(expr)
    return MacroFact("%CALC%", :calculation, string(result),
                     Dict{String,Any}("expression"=>expr, "result"=>result))
end

# === Category B: self-introspective ====================================
# These read engine-internal state via `ctx`, NOT mission text.
# Output is sentence-shaped because §7b passes :self_narrative /
# :mood / :uncertainty roles through verbatim.

function reflect_self(ctx::CycleContext)::MacroFact
    # Pull a one-line summary of recent voting behaviour.  Examples:
    #   "i've been mostly agreeing with myself the last few cycles"
    #   "my action choices have drifted toward query lately"
    fragment = _summarize_recent_self(ctx)   # reads ctx.recent_lobe_paths, ctx.recent_action_families
    return MacroFact("%REFLECT%", :self_narrative, fragment,
                     Dict{String,Any}("window"=>ctx.reflection_window))
end

function mood_summary(ctx::CycleContext)::MacroFact
    # ctx.arousal is already in [0,1].  Map to a mood word.
    arousal = ctx.arousal
    word = arousal > 0.7 ? "wired"   :
           arousal > 0.5 ? "engaged" :
           arousal > 0.3 ? "even"    :
                           "low-key"
    return MacroFact("%MOOD%", :mood, word,
                     Dict{String,Any}("arousal"=>arousal))
end

function uncertainty_phrase(ctx::CycleContext)::MacroFact
    # Top-tier confidence of the locked-in vote, inverted.  High
    # confidence -> short hedge; low -> longer hedge.
    conf = ctx.primary_confidence
    fragment = conf > 0.6  ? "i'm fairly sure"           :
               conf > 0.4  ? "i think"                   :
               conf > 0.25 ? "i'm not totally sure but"  :
                             "honestly i'm guessing here"
    return MacroFact("%UNCERTAINTY%", :uncertainty, fragment,
                     Dict{String,Any}("confidence"=>conf))
end

# === Category C: literal-text ==========================================
# Used by /macro %X% ... text:"hello there" payloads.  Resolver
# is built per-trigger by the registration helper, not listed here.
# It returns:
#   MacroFact(placeholder, :literal_text, payload_text, Dict())

end # module
```

`ctx.mission_text` replaces the prior thread-local-based
`_current_mission()`. It's already part of the `CycleContext` bundle
(see §6). Same goes for `ctx.arousal`, `ctx.primary_confidence`,
`ctx.recent_lobe_paths`, `ctx.recent_action_families` — all populated
by the two-stage `build_cycle_context` (pre-vote fields filled before
voting; introspection fields filled after `select_aiml_votes` returns).

**Phase 2 adds (network resolvers, all returning `MacroFact`):**

```julia
function weather_wttr(ctx)::MacroFact   # wttr.in JSON, role :weather
function ip_self(ctx)::MacroFact        # api.ipify.org, role :network_self
function user_recall(ctx)::MacroFact    # most recent user statement matching topic
```

All with hard timeouts and per-cycle caches (already provided by §7.1's
`fact_cache` — resolver fires once even if remote).

### 8.1 Registration — `MacroTriggers.__init__()`

```julia
function __init__()
    lock(MACRO_TRIGGER_LOCK) do
        # Resolver function registry — name => callable.
        RESOLVER_REGISTRY["time_utc"]            = AIMLResolvers.time_utc
        RESOLVER_REGISTRY["date_utc"]            = AIMLResolvers.date_utc
        RESOLVER_REGISTRY["calc_eval"]           = AIMLResolvers.calc_eval
        RESOLVER_REGISTRY["reflect_self"]        = AIMLResolvers.reflect_self
        RESOLVER_REGISTRY["mood_summary"]        = AIMLResolvers.mood_summary
        RESOLVER_REGISTRY["uncertainty_phrase"]  = AIMLResolvers.uncertainty_phrase

        # Phase-1 built-in triggers seeded:
        register_macro_trigger!(MacroTrigger(
            "current_time", "%TIME%",
            MacroCoherenceProfile([
                ModalityCheck(:action_family, [:ACTION_QUERY, :ACTION_COMMAND], 1.0),
                ModalityCheck(:verb_class,    "temporal",                       1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("time_utc")
        ))
        register_macro_trigger!(MacroTrigger(
            "current_date", "%DATE%",
            MacroCoherenceProfile([
                ModalityCheck(:action_family, [:ACTION_QUERY], 1.0),
                ModalityCheck(:verb_class,    "temporal",     1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("date_utc")
        ))
        register_macro_trigger!(MacroTrigger(
            "calc", "%CALC%",
            MacroCoherenceProfile([
                ModalityCheck(:lemma_class, "numeric",    1.0),
                ModalityCheck(:verb_class,  "arithmetic", 1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("calc_eval")
        ))
        register_macro_trigger!(MacroTrigger(
            "reflect", "%REFLECT%",
            MacroCoherenceProfile([
                ModalityCheck(:action_family, [:ACTION_QUERY, :ACTION_REFLECT], 1.0),
                ModalityCheck(:lemma_class,   "self_pronoun",                   1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("reflect_self")
        ))
        register_macro_trigger!(MacroTrigger(
            "mood", "%MOOD%",
            MacroCoherenceProfile([
                ModalityCheck(:action_family, [:ACTION_QUERY],    1.0),
                ModalityCheck(:lemma_class,   "affect_word",      1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("mood_summary")
        ))
        register_macro_trigger!(MacroTrigger(
            "uncertainty", "%UNCERTAINTY%",
            MacroCoherenceProfile([
                ModalityCheck(:tone_family, [:TONE_HEDGED, :TONE_CURIOUS], 1.0),
            ], :all, 1.0),
            :builtin, ResolverPayload("uncertainty_phrase")
        ))
    end
end
```

### 8.2 New verb / lemma classes required

These are small additions to existing registries — none introduce new
infrastructure, just new entries:

| Class | Where it lives | Members (phase 1) |
|---|---|---|
| `arithmetic` (verb_class) | `SemanticVerbs.jl` default registry | `add`, `subtract`, `multiply`, `divide`, `equals`, `compute`, `calculate`, `plus`, `minus`, `sum` |
| `temporal` (verb_class) | `SemanticVerbs.jl` default registry | already partially present; ensure `tell`, `know`, `say` map for "tell me the time" / "what time is it" |
| `numeric` (lemma_class) | thesaurus / patternscanner side | digits, number words `one`–`twenty`, decimal markers |
| `self_pronoun` (lemma_class) | thesaurus / patternscanner side | `i`, `me`, `myself`, `you` (mirrors second-person to first), `your` |
| `affect_word` (lemma_class) | thesaurus / patternscanner side | `feel`, `feeling`, `mood`, `vibe`, `okay`, `alright` |

**All five are small standalone changes.** They don't gate on the macro
plug-in landing — adding them strengthens existing semantic signals
even without macros.

---

## 9. /right and /wrong feedback

No new feedback math.

- A vote that contributed to output is a contributor (existing
  machinery). If that vote carried `macro_signal != ""`, the carrier
  node is reinforced exactly the same way it would be without a macro.
- `/wrong` decays the contributor list. The carrier's `macro_signal`
  field is **NOT cleared on a single `/wrong`** — apoptosis (strength
  → 0 → grave) handles persistent failure for the carrier as a whole,
  same as for any other action choice.
- Phase 3 adds `auto_attach_macro_on_right!` — under specific
  high-coherence conditions, a top-tier carrier can ratchet toward
  carrying a macro it *almost* matched. Disabled in phase 1.

---

## 10. Persistence — specimen save/load

The four touchpoints:

1. **`Node.macro_signal`** — plain string, serializes inside the
   existing node JSON dict. Specimens saved before this feature load
   with `get(node_dict, "macro_signal", "")` defaulting to empty.

2. **`MACRO_TRIGGER_REGISTRY`** — serialized as a top-level array in
   the specimen JSON, alongside the existing top-level sections (verb
   registry, synonym map, AIML drop table, etc.). Each trigger
   serializes its `name`, `placeholder`, `kind`, and `payload`. The
   payload variant tag (`:resolver` / `:text` / `:remote`) and its
   data are written.

3. **`RESOLVER_REGISTRY`** — **NEVER serialized**. It contains
   `Function` values; closures are not specimen-clean. Resolvers are
   re-bound at boot from `AIMLResolvers.__init__()`. Phase-2 remote
   resolvers re-bind from their stored `RemotePayload` descriptor (URL
   + JSON path), which IS serialized.

4. **`MacroCoherenceProfile`** — pure data, serializes trivially.
   Symbols and strings only; no closures inside `ModalityCheck`.

If a specimen loaded from disk references a `resolver_id` that isn't in
the current `RESOLVER_REGISTRY` (e.g. a resolver was renamed or
removed), the trigger is loaded into the registry but `resolve_macro(...)`
will throw at fire time, caught by the strict-mode handler in §7.
**Loud failure preferred over silent corruption.**

---

## 11. Phased rollout — concrete deliverables

### Phase 1 (the vertical slice)

**Files touched:**
- `engine.jl` — `Node.macro_signal`, `Vote.macro_signal`, one line in
  `cast_vote`, default-empty handling in specimen load.
- `VoteOrchestrator.jl` — `VoteCandidate.macro_signal`, threaded
  through the constructor.
- `Main.jl` — `ephemeral_aiml_orchestrator` builds `CycleContext`,
  computes `locked_macros`, threads via `context["__locked_macros__"]`;
  `generate_aiml_payload` adds the `%X%` substitution loop with cache;
  `process_mission` calls `build_cycle_context` between
  `screen_input_complexity` and the orchestrator dispatch.
- `SemanticVerbs.jl` — add `arithmetic` verb class to the default
  registry.
- New file `MacroTriggers.jl` — the registry, structs, and registration
  API.
- New file `AIMLResolvers.jl` — `time_utc`, `date_utc`, `calc_eval`.
- `GrugBot420.jl` — include the two new files between `RelationalJitter`
  and `AIMLNodeSystem`.

**Slash commands:**
- `/macro`, `/macroRemove`, `/macroList`
- `/nodeMacro`, `/nodeMacroClear`
- `/setMacroStrict on|off`

**Tests:**
- Vote carries macro_signal copied from carrier node (unconditional copy).
- locked_macros = top_tier carriers ∩ coherence-eligible (sub-top
  carriers' macros excluded).
- Single-fire dedup when same macro carried by multiple top-tier nodes.
- Per-cycle resolver caching: `%TIME%` referenced N times resolves once.
- Coherence: macro fires when ALL declared modalities match, doesn't
  fire when ANY missed.
- Strict mode: unresolved `%X%` throws; non-strict warns and leaves
  intact.
- Specimen round-trip preserves `macro_signal`, registry, and
  coherence profiles.
- Validator regex still rejects misuse: `/macro %time%` (lowercase)
  rejected; `{TIME}` syntax for macros rejected.
- Placeholder collision rejected at registration.
- Calc resolver: `"what is 12 * (3 + 4)"` returns `"84"`. NEVER calls
  `Meta.parse` or `eval`.
- Built-in `%TIME%`, `%DATE%`, `%CALC%` work end-to-end with their
  default profiles.

### Phase 2 — remote resolvers + richer modalities
- `/macroRemote` slash command.
- `weather_wttr`, `ip_self` resolvers (with HTTP timeouts and per-cycle cache).
- `af-mass:`, `tf-mass:` modalities reading
  `prediction.action_distribution` / `tone_distribution`.
- `:any` and `:weighted` combiners.
- `MACRO_COHERENCE_THRESHOLD` becomes meaningful (used by `:weighted`).
- `/setMacroCoherence` command.

### Phase 3 — node agency
- During a cycle where a top-tier carrier was within ε of one of its
  declared modalities (e.g. coherence score 0.55 against a 0.60
  threshold), a strength-modulated coinflip can ratchet the node's
  `macro_signal` toward that macro. Same coinflip family as
  `bump_strength!`.
- `/right` reinforces; `/wrong` decays the macro association on coinflip.

### Phase 4 — semantic auto-suggest
- `Thesaurus.expand_token_set` + `SemanticVerbs.get_verbs_in_class`
  feed cue-class matching so a `vc:temporal` modality automatically
  expands to all verbs in the temporal class without user maintenance
  of the class.
- New modality `:concept_neighborhood` reads `Thesaurus` similarity to
  a named anchor concept rather than literal verb-class membership.

---

## 12. What this plan deliberately rejects

| rejected idea                                   | why                                                                |
|-------------------------------------------------|--------------------------------------------------------------------|
| Macro fires only at `scan_mode == 3`            | User explicit: "fires for simple or complex input"                 |
| `ActionTonePredictor` query family as gate      | ATP runs every input; this isn't a complex-input gate              |
| Sub-top survivors fire macros                   | Bioavailability gate is top-tier only; user's "lock-ins" language  |
| Macro is a vote in its own right                | Macros ride existing votes; adding parallel selection is bloat     |
| Macros consult node's stored pattern            | "Inherited activator" — input-side coherence, not node content     |
| Keyword-overlap percentage matching             | "Coherence not fidelity" — bag-of-words is brittle                 |
| Fixed coherence recipe for all macros           | "Multi-modal" — each macro picks its own subsystems                |
| Tracking ATP basic vs dynamic separately        | Same `PredictionResult` struct returned regardless of scan_mode    |
| LLM-backed resolver                             | Project philosophy: no transformers in the loop                    |
| Closures in registry                            | Specimen JSON serialization invariant                              |
| `Meta.parse` / `eval` in calc resolver          | Code execution from user input is forbidden                        |
| Per-lobe macro registries                       | Phase 1 is global; per-lobe is at most a phase-4 concern           |
| Macros inside `AIMLNodeSystem.jl`               | Wrong layer — triggers are world-value resolvers, not templates    |

---

## 13. Open questions still requiring sign-off before code

1. **Phase 1 resolver scope (expanded).** Phase 1 now ships SIX
   resolvers: `time_utc`, `date_utc`, `calc_eval`, `reflect_self`,
   `mood_summary`, `uncertainty_phrase`. Confirm this is the right
   surface — or trim to a smaller subset (e.g. drop `mood_summary` if
   `arousal` plumbing into `CycleContext` isn't ready).

2. **Default strict mode.** Warn-and-keep-placeholder, or hard-error,
   when an unlocked `%X%` survives the §7a substitution pass? The doc
   defaults to warn.

3. **New verb / lemma classes (five additions).** §8.2 lists:
   `arithmetic` (verb), `temporal` (verb, augmentation), `numeric`
   (lemma), `self_pronoun` (lemma), `affect_word` (lemma). Confirm all
   five land in phase 1, or defer the introspection-related ones
   (`self_pronoun`, `affect_word`) along with `%REFLECT%` / `%MOOD%`.

4. **`/nodeMacro` placement.** Phase 1 assumes the user explicitly
   attaches a macro to a node via slash command. Confirm that's the
   user-facing path (vs. an auto-attach heuristic at registration time
   that scans existing nodes for cue overlap).

5. **`CycleContext` two-stage build location.** Pre-vote fields
   (mission_text, prediction, basic_triples, dynamic_triples,
   verb_classes_seen, lemma_classes_seen, arousal) populate at the top
   of `process_mission` after ATP / triple extraction. Post-vote fields
   (sure_votes, primary_vote, primary_confidence, lobe_path,
   recent_lobe_paths, recent_action_families) populate inside
   `ephemeral_aiml_orchestrator` after `select_aiml_votes` returns,
   *before* `generate_aiml_payload` runs. Confirm this split.

6. **§7b synthesis weaving — opt-out switch.** Phase 1 weaves every
   locked macro into `support_pieces`. Should `MacroTrigger` carry an
   optional `suppress_in_synthesis::Bool` for triggers whose
   rule-board placement (§7a) is sufficient on its own? Default-off
   means the §7b path is unconditional in phase 1.

7. **`_macro_fact_to_clause` template breadth.** Phase 1 covers 6
   semantic roles × 3 most-common action families (QUERY, INFORM,
   COMMAND) ≈ ~20 templates. Other action families fall through to a
   generic clause. Confirm that's acceptable as the phase-1 ceiling, or
   commit to broader per-family coverage up front.

8. **AIMLNodeSystem-level macros (out of scope, just confirming).**
   This plan attaches macros to *voter* `Node`s only. AIML nodes don't
   get their own macros. Confirm that's still the model.

---

## 14. Quick-reference change-summary table

| location                                  | change                                                                                                  |
|-------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `engine.jl :: Node`                       | + `macro_signal::String` field                                                                          |
| `engine.jl :: Vote`                       | + `macro_signal::String` field                                                                          |
| `engine.jl :: cast_vote`                  | thread `node.macro_signal` into Vote constructor                                                        |
| `engine.jl` (specimen save/load)          | default-empty fallback for old specimens                                                                |
| `VoteOrchestrator.jl :: VoteCandidate`    | + `macro_signal::String` field                                                                          |
| `Main.jl :: process_mission`              | call `build_cycle_context(...)` (pre-vote stage) before orchestrator dispatch                           |
| `Main.jl :: ephemeral_aiml_orchestrator`  | finish `CycleContext` (post-vote stage), compute `locked_macros`, thread via `context["__cycle_context__"]` |
| `Main.jl :: generate_aiml_payload` §7.1   | per-cycle `MacroFact` cache built once                                                                  |
| `Main.jl :: generate_aiml_payload` §7.2   | per-rule `%X%` substitution loop using `fact.rendered_text` → rule-board / `[Directives:]` tail         |
| `Main.jl :: generate_aiml_payload` §7.3   | macros become 4th `support_pieces` source at `Main.jl:1497-1527`, routed through `_swap_words_in`       |
| `Main.jl :: _macro_fact_to_clause`        | NEW skeleton-aware phrasing dispatcher (~20 templates, 6 roles × QUERY/INFORM/COMMAND)                  |
| `Main.jl` (slash command parser)          | regex matchers for `/macro`, `/macroList`, `/macroRemove`, `/nodeMacro`, `/nodeMacroClear`, `/setMacroStrict` |
| `SemanticVerbs.jl`                        | + `arithmetic` verb class default; `temporal` augmentation                                              |
| `patternscanner.jl` (or new helper)       | + `numeric`, `self_pronoun`, `affect_word` lemma classes                                                |
| **NEW** `MacroTriggers.jl`                | `MacroFact`, `MacroPayload` union, `MacroTrigger`, `MacroCoherenceProfile`, `ModalityCheck`, `CycleContext`, registry, dispatcher |
| **NEW** `AIMLResolvers.jl`                | `time_utc`, `date_utc`, `calc_eval`, `reflect_self`, `mood_summary`, `uncertainty_phrase` — all returning `MacroFact` |
| `GrugBot420.jl`                           | include `MacroTriggers.jl` + `AIMLResolvers.jl` between `RelationalJitter.jl` and `AIMLNodeSystem.jl`    |

---

*End of plan. No code lands until the §13 open questions are
resolved. Architecturally settled: voter-carried signal, bioavailability
gate, single-fire dedup, multi-modal coherence dispatcher, `MacroFact`
envelope, two-channel render (§7a rule-board + §7b synthesis weaving),
six phase-1 resolvers spanning world-value / introspection / literal
text.*
