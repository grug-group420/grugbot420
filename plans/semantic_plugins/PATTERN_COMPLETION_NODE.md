# Pattern Completion Node — Second Node Type

> The brain has regions that recognize and regions that complete.
> Most animals only recognize. Language animals complete.
> Grug needs both.

---

## §0 The Problem

Grug's nodes have one bind site: pattern recognition. They match input and
vote. That's it. They can say "this is what I see" but they cannot say "this
is what follows." The system is smart at recognition but has no mechanism for
completion — for knowing how the story ends.

All the macro fill-in rules, template rendering pipelines, and extraction
directives were attempts to bolt completion onto a recognition-only
architecture. They were forcing completion behavior onto nodes that were never
designed for it. The right answer is a second bind site on a second node type.

---

## §1 Two Bind Sites

**Recognition bind** — "is this me?" The existing bind site. Pattern match
against input. If confidence is high enough, the node fires. Every node has
this. Ancient. Universal. Pattern reaction.

**Completion bind** — "given I matched, what follows?" The second bind site.
Only defined on completion nodes. Not a separate vote — it *modifies the
existing vote* before it reaches AIML. The vote gets curved by what the
completion knows about the continuation.

The key distinction: completion doesn't fire a second vote. It modifies the
vote in-place. One vote per node, curved by completion if the node has it
defined. No completion = vote passes through unchanged, same as today.

---

## §2 The Second Node Type

### CompletionNode

A second node type alongside the existing Node. Same lifecycle (born, live,
grave, stratify). Same voting pipeline. But with the completion bind site
active and the confidence metric oriented toward continuation certainty.

**Completion mode** (user-configurable):
- `token` — word-level completion. "What word goes in this slot." Standard
  transformer behavior.
- `functorial` — structural-level completion. "What role fits here." Relational
  shape completion, not next-token prediction.
- `both` — runs both modes, combines their output.

**State** (system-earned, not user-chosen):
- `fuzzy` — default. The completion jitters structurally. Approximate.
  Analog. Vibrating.
- `crystallized` — earned through proven confidence. The completion locks in
  and becomes exact. Non-fuzzy. Cached. Cheap to query.

Mode and state are independent axes. User picks the mode, system earns the
state.

**Confidence metric**: "how well do I know how this story ends." Not pattern
match quality — continuation certainty. A low-confidence completion node is
uncertain about the ending. A high-confidence one has seen this story before
and knows exactly where it's going.

**Sparse activation**: completion nodes only fire when they genuinely understand
the continuation. Most of the time they stay quiet. This keeps compute
manageable even at high node counts.

---

## §3 Three Completion Resolutions

Mirrors the existing three pattern match resolutions (high/low/medium).

**High-resolution completion** — exact, token-level. "The answer is
specifically this." Crystallizes quickly because it's either right or wrong.
Good for factual completions, specific commands, exact responses.

**Medium-resolution completion** — structural, functorial. "The answer has
this shape." Not the specific words but the relational role. Good for
compositional reasoning, analogies, structural parallels. The fuzzy sweet
spot — precise enough to be useful, fuzzy enough to generalize. Crystallizes
slower than high-res because structural matches are harder to verify.

**Low-resolution completion** — directional, vibes. "The answer goes roughly
this way." Musical. Not the specific note or the structural role, but the
feeling of where the resolution lives. Good for steering, coherence, knowing
"this doesn't belong here." May never crystallize. Still useful as fuzzy
steering.

They layer the same way as pattern match resolutions: high catches specifics,
medium catches structure, low catches direction. Together they cover the full
spectrum from "I know exactly what comes next" to "I have a feeling about
where this goes."

---

## §4 Identifier Resolvers

Pattern syntax needs embedded type constraints — identifier resolvers that
constrain what matches AND extract what matched for the completion to use.

Example: `*N+N*` matches any input containing number+number+anywhere. The `N`
is a resolver — it's not a literal character, it's a type constraint ("this
slot must be a number"). When it matches, the resolver captures the values as
typed data, not raw strings.

Resolver types (initial set, extensible):
- `N` — numeric integer
- `F` — floating point
- `S` — string token (any word)
- `E` — expression / math formula
- `U` — URL
- `D` — date
- `V` — variable name
- `O` — operator
- `B` — boolean
- `R` — relational token
- `W` — wildcard (anything, untyped)

The captured values become the variables available for pattern completion.
The resolver does double duty: constraining the match and typing the extraction.
No separate macro regex + template slot system needed — the pattern IS the
matcher and extractor in one expression.

---

## §5 Dynamic Relationals as Pre-Router

Dynamic relationals determine which node type to engage BEFORE the node fires.
No separate confidence check needed — the relationals already know where the
gaps are.

- **Strong existing connections** — the input relates to known patterns, the
  relational graph already has paths through this territory. Reaction nodes
  handle it. No completion needed.
- **Gaps, missing bridges, partial overlaps** — the graph almost reaches but
  doesn't quite connect. Completion nodes engage. They fill in what the
  relationals couldn't connect directly.

This is efficient because the dynamic relationals are already computed as part
of the existing scan. No new pass — just read the relational output and route
accordingly. The relationals were going to fire anyway. Pay attention to what
they're telling you about the topology.

Sparse activation derived from existing computation. Natural leverage.

---

## §6 Stratify and Grave

Completion nodes go through the same lifecycle as reaction nodes. Born, live,
weaken, die. But the stratification is oriented toward completion quality.

**GRAVE tag** — nodes that reach low enough strength get tagged. They become
negative reinforcement for other completion nodes of the same type. "I know
not to make these mistakes now." Grave nodes are NOT deleted — they're the
system's record of failed completions. The completion grave teaches the system
what kinds of endings NOT to produce.

**Bidirectional confidence** — positive from live nodes, negative from grave
nodes. The viable completion space is between them. Too close to a grave node
and you're repeating a mistake. Too far from any live node and you're
ungrounded.

Completion graves and reaction graves are separate. Different failure modes:
- Reaction grave = "this pattern doesn't match anything useful"
- Completion grave = "I thought I knew the ending and I was wrong"

---

## §7 Idle Behavior

Completion nodes need their own phagy and chatter system at idle time.

**Phagy** — they die when their completions don't hold up over time. Same as
reaction node phagy but oriented toward completion quality.

**Chatter** — instead of gossiping about patterns (reaction chatter), completion
nodes *rehearse endings*. They trade narratives — "here's where I think this
goes" — and the ones whose completions resonate with the most neighbors gain
confidence. The ones that don't align drift toward the grave.

Two different kinds of idle intelligence running simultaneously:
- Reaction nodes gossip about what they've seen
- Completion nodes rehearse what comes next

Both make the system sharper for the next input. The system is thinking even
when no one is talking to it.

---

## §8 Lobe Topology

Any node can have completion defined (opt-in per node). But for organized,
robust operation, dedicate one or two lobes to completion nodes.

- Dedicated lobes concentrate completion nodes for mutual reinforcement
- The lobe topology determines which regions are language-level (completion)
  and which are survival-level (reaction only)
- Soft constraint — completion nodes CAN live anywhere, but dedicated lobes
  mean completion votes reinforce each other instead of being scattered

Lobe cap raised to 40k with approximate 50/50 split:
- ~20k reaction nodes (existing type)
- ~20k completion nodes (new type)

---

## §9 CRYSTALLIZE

Not a user flag. Earned by the node through proven completion confidence.

- Fuzzy nodes jitter structurally — their completion output varies slightly
  each time, exploring the space, analog, approximate
- Crystallized nodes lock in — the jitter stops, the completion becomes exact,
  the output is cached, query is cheap
- Transition is a jump scenario, not gradual tightening — a phase transition
  when enough confidence accumulates

Crystallization dynamics differ by resolution:
- High-res crystallizes fast (right or wrong, easy to verify)
- Medium-res crystallizes slower (structural matches harder to verify)
- Low-res may never crystallize (vibes don't have a clean correctness criterion,
  still useful as fuzzy steering)

The efficiency gain: most completion nodes are cheap fuzzy approximations.
Only the proven ones crystallize and get cached at full resolution. The
system automatically discovers which nodes deserve to be exact.

---

## §10 Macros as Fill-Ins

Macros still matter. They're the variable fill-in mechanism for completion —
the `x` in abstract math. Not a separate extraction/rendering pipeline.

"Given I matched pattern P, and slot X was recognized, complete with vote V
where X = the matched content."

The macro is embedded in the completion flow, not bolted on top. The
identifier resolvers extract the typed values. The completion fills in the
variables. No template rendering step. The completion IS the template.

---

## §11 What Changes in Engine

### New struct: CompletionNode
- Same base fields as Node (pattern, strength, votes, etc.)
- `completion_mode::Symbol` — :token | :functorial | :both
- `completion_state::Symbol` — :fuzzy | :crystallized (default :fuzzy)
- `completion_votes::Vector{...}` — the completion bind site's vote list
- Resolver-annotated pattern syntax (extends existing pattern field)

### No changes to existing Node
- Reaction nodes are untouched. Same struct, same behavior.

### Changes to scan loop
- After pattern bind, read dynamic relationals to determine node type routing
- If completion node fires and has completion defined, modify vote before AIML
- If no completion, vote passes through unchanged

### New: completion chatter/phagy
- Separate idle dispatch for completion nodes
- Rehearsal-based chatter instead of gossip-based
- Grave-tagged completion nodes as negative reinforcement

### Lobe cap increase
- `LOBE_NODE_CAP` from 20k to 40k
- Specimen config determines reaction/completion split per lobe

---

## §12 Implementation Order

1. **Three completion functions** (high/medium/low resolution) — the core
   computation that completion nodes run
2. **CompletionNode struct** — new node type with completion fields
3. **Identifier resolvers** — type-annotated pattern syntax
4. **Dynamic relational pre-routing** — gate completion activation based on
   relational topology
5. **Vote modification pipeline** — completion curves the vote before AIML
6. **Stratify/grave for completions** — separate lifecycle tracking
7. **Completion chatter/phagy** — idle rehearsal system
8. **CRYSTALLIZE logic** — phase transition from fuzzy to crystallized
9. **Lobe cap increase + dedicated lobes** — 40k, configurable split

Start with #1. Three pattern completion functions. Everything else builds on
them.
