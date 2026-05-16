# RELEVANCE GATE PLAN — second-order activation gate for stochastic node firing

**Status:** plan only. No code lands until §10 open questions are resolved.

**Sibling doc:** `MACRO_PLUGIN_PLAN.md` (regex+scope+template macros). The
relevance gate consumes macro-activation state as one of its floor
artifacts but is otherwise independent.

**Revision history (most recent first):**
- *current* — initial draft. Captures the converged framing from the
  Nov 2024 design conversation: a *second-order activation gate* sitting
  one step after `strength_biased_scan_coinflip` (engine.jl:2341), reading
  per-input floor artifacts and modulating which candidate nodes earn
  the cost of firing this cycle. Math is weighted-pros-vs-cons with
  margin-as-intensity and jitter scaled to the weaker side. Layered
  shape (does not replace strength coinflip) chosen over wholesale
  replacement.

---

## 0. Problem statement

Today's stochastic firing decision (`strength_biased_scan_coinflip`,
engine.jl:2341) gates every node scan on a single variable: long-run
strength.

```julia
scan_prob = 0.20 + (node.strength / STRENGTH_CAP) * 0.70   # range 0.20–0.90
return rand() < scan_prob
```

This does a real job — keeps strong nodes prominent, lets weak nodes
occasionally surprise, prevents monopolies — but it treats every input
the same. A node with strength 8.0 fires ~76% regardless of whether
the current input actually fits it.

Strength is a **trait** (long-run usefulness average). It is not a
**state** (this-input contextual relevance). The engine already
computes a great deal of per-input contextual signal during scan —
relational triples, required_relations matches, inhibition history,
macro-activation regions, hot pinned-memory tokens, sibling fire
state — and `strength_biased_scan_coinflip` ignores all of it.

**Goal:** add a per-input modulator after the strength coinflip that
reads already-computed floor artifacts and decides whether to override
the coinflip outcome upward (let a weak-but-relevant node punch up) or
downward (cut a strong-but-irrelevant node), defaulting to the
strength coinflip's verdict when the signal is ambiguous.

**Non-goal:** semantic reasoning. The gate does not generate, weigh,
or interpret meaning. It tallies *pointers to existing engine state*
with mechanically-computed weights. Every pro and every con must
point back to a specific floor artifact already populated by upstream
machinery. Confabulation is the failure mode this discipline prevents.

---

## 1. Code-level reality check (verified against fresh HEAD `412c767`)

### 1.1 The existing gate site (engine.jl:2531)

```julia
# inside the per-node scan worker body (engine.jl:~2520-2535):
if node.is_grave
    return nothing
end

# GRUG NEW: STRENGTH-BIASED COINFLIP before even scanning pattern!
# Strong nodes are biased to activate. Weak nodes may be skipped.
if !strength_biased_scan_coinflip(node)
    return nothing
end

# ... pattern scan proceeds ...
```

This is the single hot insertion point. The relevance gate runs
**immediately after** the strength coinflip and **before** the
expensive pattern scan, so it can cut work as well as override
participation.

### 1.2 The strength coinflip itself (engine.jl:2341)

```julia
function strength_biased_scan_coinflip(node::Node)::Bool
    base_prob  = 0.20
    bonus_prob = 0.70
    scan_prob  = base_prob + (node.strength / STRENGTH_CAP) * bonus_prob
    return rand() < clamp(scan_prob, 0.0, 1.0)
end
```

Pure function of `node.strength`. **No changes** to this function —
the relevance gate is layered on top, not folded in. See §3 for the
layering shape.

### 1.3 Floor artifacts already available at scan time

The scan worker has already computed (or has cheap access to) all of
the following before the per-node loop body runs:

| Artifact | Source | Cost to look up per node |
|---|---|---|
| User-input relational triples | `extract_relational_triples` (engine.jl:~2380) | O(1) — passed in |
| Dynamic relational triples (mode 3 only) | `extract_dynamic_relational_triples` (engine.jl:181) | O(1) — passed in |
| Hot pinned-memory token set | `MESSAGE_HISTORY` filtered by pinned + intensity | O(1) — precomputed |
| Macro-activation pattern hits | macro layer (sibling doc, MacroPlugins) | O(1) — precomputed |
| Recent-cycle inhibition history | engine state (per-node `negatives` from last fire) | O(1) — node lookup |
| Sibling-fire bitmap (this-cycle so far) | running scan state | O(1) — bit check |
| Node `required_relations` | `node.required_relations` | O(1) — node field |
| Node `drop_table` | `node.drop_table` | O(1) — node field |
| Node `relation_weights` | `node.relation_weights` | O(1) — node field |

**Every floor artifact is either passed into the scan worker or
trivially retrievable from the candidate node's struct.** The gate
does not introduce new computation paths; it reads what's already
there.

### 1.4 Per-cycle scan context (does not exist yet)

The scan worker today doesn't bundle per-cycle context into a single
struct — each piece is referenced ad-hoc. The relevance gate needs
a `ScanContext` struct (§4) populated **once per scan** before the
per-node loop, then passed in by reference for O(1) lookups during
gate evaluation. This is the only new shared state the design
introduces.

### 1.5 What does *not* exist and is *not* needed

- A semantic-role taxonomy. (Walked back earlier; not resurrected.)
- A free-form pros/cons populator. The gate's emitter list is fixed
  and lives in one function.
- A new node field. All inputs are derived from existing node state
  or per-cycle context.
- A new feedback loop. The gate's effects propagate naturally through
  the existing strength dynamic — nodes that get gated up will fire
  more, win more, and accrue strength more. No special bookkeeping.

---

## 2. Mental model — second-order activation gate

The clean restatement:

> Grug already has three first-order bind operations:
> **pattern-bind** (input tokens ↔ node patterns),
> **relational-bind** (user triples ↔ node `required_relations`),
> **context-bind** (input ↔ MESSAGE_HISTORY via intensity refresh).
>
> The relevance gate is a **second-order bind** — it binds *across
> the results* of those three. It does not create new associations;
> it judges the value of associations that already exist, and uses
> that judgment to modulate stochastic firing.

### Three properties this commits to

1. **The gate is layered, not replacing.** Strength coinflip stays as
   the cheap first gate. The relevance gate runs second, with three
   regions:
   - **Pros wide-margin** → `:fire` (override upward — weak node fires)
   - **Cons wide-margin** → `:skip` (override downward — strong node cuts)
   - **Narrow margin** → `:let_strength_decide` (pass through; the
     strength coinflip's earlier `true` already authorized the fire,
     so this region is a no-op)

2. **Adjudication has already happened upstream.** This gate is not
   deciding what the bot believes. It is curating which long-term
   pattern nodes get to participate in this cycle's vote-cast. The
   semantic outcome is set later by `cast_vote` and tier selection.

3. **Every pro and every con is a pointer.** No emitted reason exists
   independently of an engine artifact. The artifact's weight is
   computed mechanically from existing engine quantities — vote
   tally counts, intensity floors, weight fields, presence/absence
   booleans. If it can't point to an artifact, it can't enter the
   tally.

### What the gate is *not*

- Not a render modulator. (Earlier draft framing; superseded.)
- Not a hippocampus feature. Hippocampus-proper is `MESSAGE_HISTORY` +
  `refresh_message_intensities!` in Main.jl. This gate *consumes*
  hippocampal signal as one input among many but lives in cortex-layer
  code (`engine.jl`).
- Not a macro feature. The macro system (sibling doc) is
  pattern-extraction over user input. The relevance gate is
  participation-gating over candidate nodes. They share zero state
  except that one of the gate's emitters reads macro-activation
  results as a floor artifact.
- Not deliberation. There is no "weighing reasons" step. There is
  weighted summing of pointers, and a margin comparison.

---

## 3. The layering shape

The full per-node scan flow becomes:

```
for each candidate node:
    if node.is_grave: skip
    if !strength_biased_scan_coinflip(node): skip       # cheap first gate, EXISTING
    decision = relevance_gate(node, scan_context)        # NEW second-order bind
    match decision:
        :fire             → continue to pattern scan    # override upward
        :skip             → return nothing              # override downward
        :let_strength_decide → continue                 # strength already said yes
    # ... pattern scan proceeds as today ...
```

The strength coinflip gate is the *floor* — anything it skips, the
relevance gate never sees. This is intentional: it preserves the
existing apoptosis / familiarity dynamics for the bottom 20% of
weakest nodes (which still get a 20% baseline scan rate) and avoids
spending gate-tally cost on nodes already filtered out.

The relevance gate's `:fire` decision can override that floor,
**but only for nodes that the strength coinflip rejected** — wait,
no: the strength coinflip happens first. If it returns `false`, we
already returned. So the relevance gate cannot override the strength
coinflip's `false`.

**This is a real design choice and it's worth surfacing.** Two options:

- **Option A — strength is hard floor.** Strength `false` → skip,
  relevance gate never runs. Simpler, cheaper, but means a strength-0
  node with maximum contextual relevance still has only a 20% chance
  of being seen. Acceptable if we trust strength as a long-run signal.
- **Option B — strength is soft prior.** Strength coinflip becomes one
  pro (or its complement, a con) inside the relevance gate; the gate
  is the only firing decision. More expressive, more expensive
  (gate-tally runs on every candidate), changes long-term dynamics.

**Recommendation: Option A for phase 1.** It's the conservative
layering, preserves existing behavior on the floor, costs less per
scan, and is trivially reversible. Option B can be considered if
phase 1 reveals that genuinely-relevant weak nodes are being starved.
See §10 Q1.

---

## 4. The `ScanContext` and `relevance_gate` function

### 4.1 `ScanContext` — populated once per scan

```julia
struct ScanContext
    # First-order bind results, computed once before per-node loop
    user_triples::Vector{RelationalTriple}
    dynamic_triples::Vector{RelationalTriple}    # empty unless scan_mode == 3
    scan_mode::Int                                # 1, 2, or 3

    # Hippocampal signal
    hot_pinned_tokens::Set{String}                # tokens from pinned + high-intensity messages

    # Macro-layer signal (sibling doc)
    macro_activated_node_ids::Set{String}         # nodes whose pattern was hit by an active macro

    # Per-cycle running state
    fired_node_ids::Set{String}                   # nodes that have already fired this scan
    recent_inhibitor_ids::Set{String}             # node IDs that inhibited others last cycle
end
```

**This struct is built once per scan**, passed by reference to every
per-node gate evaluation. All fields are O(1) lookups via set
membership, vector iteration, or scalar reads.

### 4.2 `relevance_gate` — the gate itself

```julia
@enum GateDecision FIRE SKIP LET_STRENGTH_DECIDE

function relevance_gate(node::Node, ctx::ScanContext)::GateDecision
    pros, cons = emit_pros_cons(node, ctx)        # §5 — fixed registry

    pros_sum = sum(w for (_, w) in pros; init=0.0)
    cons_sum = sum(w for (_, w) in cons; init=0.0)

    margin = pros_sum - cons_sum

    # Jitter scales with the weaker side. Cannot flip a wide margin;
    # can flip a tied or near-tied result.
    weaker = min(pros_sum, cons_sum)
    epsilon = 0.10 * weaker
    jittered_margin = margin + (rand() * 2 - 1) * epsilon

    # Three-region decision. Thresholds tunable; see §10 Q3.
    if jittered_margin >  RELEVANCE_GATE_FIRE_THRESHOLD
        return FIRE
    elseif jittered_margin < -RELEVANCE_GATE_SKIP_THRESHOLD
        return SKIP
    else
        return LET_STRENGTH_DECIDE
    end
end
```

**Three constants** govern the gate's behavior, all phase-1 tunable:

| Constant | Default | What it controls |
|---|---|---|
| `RELEVANCE_GATE_FIRE_THRESHOLD` | `2.0` | How dominant pros must be to override upward |
| `RELEVANCE_GATE_SKIP_THRESHOLD` | `2.0` | How dominant cons must be to override downward |
| `RELEVANCE_GATE_JITTER_FRACTION` | `0.10` | Jitter as fraction of weaker side |

Defaults are placeholders. Tuning happens in phase 2 (§9).

---

## 5. The emitter registry — single source of truth for pros/cons

This is the **firewall against confabulation**. Every pro and every
con emitted by the gate originates here. There is exactly one
function. Nothing outside this function may emit a pro or con. The
function is short and grep-auditable.

```julia
"""
emit_pros_cons(node::Node, ctx::ScanContext)
    -> (pros::Vector{Tuple{Symbol, Float64}},
        cons::Vector{Tuple{Symbol, Float64}})

Single registry of all relevance signals. Each entry is a (symbol, weight)
tuple where the symbol identifies which floor artifact contributed the
signal — every entry MUST point back to a real engine quantity. The
symbol is for auditing and /right /wrong feedback; the weight is what
the gate sums.

INVARIANT: this function reads only from `node` (passed-in struct) and
`ctx` (passed-in scan context). It must not call into NODE_MAP,
MESSAGE_HISTORY, COMMANDS, or any global registry. All inputs come
through the parameters.
"""
function emit_pros_cons(node::Node, ctx::ScanContext)
    pros = Tuple{Symbol, Float64}[]
    cons = Tuple{Symbol, Float64}[]

    # ── Relational signal ──────────────────────────────────────────
    # Pro: user-input triple's relation matches one of node's required_relations.
    # Weight: count of matches × node's relation_weight for that relation.
    for t in ctx.user_triples
        rel = lowercase(strip(t.relation))
        if rel in node.required_relations
            w = get(node.relation_weights, rel, 1.0)
            push!(pros, (:relation_match, w))
        end
    end

    # Pro: dynamic-triple match (mode 3 inputs only — bigger reward, rarer).
    for t in ctx.dynamic_triples
        rel = lowercase(strip(t.relation))
        if rel in node.required_relations
            w = get(node.relation_weights, rel, 1.0) * 1.5    # mode-3 bonus
            push!(pros, (:dynamic_relation_match, w))
        end
    end

    # ── Hippocampal signal ─────────────────────────────────────────
    # Pro: node's pattern shares tokens with hot pinned memory.
    pattern_tokens = Set(split(lowercase(node.pattern)))
    pinned_overlap = length(intersect(pattern_tokens, ctx.hot_pinned_tokens))
    if pinned_overlap > 0
        push!(pros, (:pinned_memory_resonance, Float64(pinned_overlap) * 0.5))
    end

    # ── Macro-layer signal ─────────────────────────────────────────
    # Pro: this node was pattern-hit by an active macro this cycle.
    if node.id in ctx.macro_activated_node_ids
        push!(pros, (:macro_activation, 2.0))
    end

    # ── Cycle-state signal ─────────────────────────────────────────
    # Con: a sibling node with the same pattern already fired this scan
    # — redundant participation costs us reply diversity.
    for fired_id in ctx.fired_node_ids
        # cheap pattern-equality check requires a NODE_MAP lookup which
        # the invariant forbids; instead, ScanContext should pre-bundle
        # a Set of "patterns already fired" — see §10 Q4.
    end
    # (placeholder — see Q4)

    # Con: this node was inhibited last cycle by a node firing now.
    if node.id in ctx.recent_inhibitor_ids
        push!(cons, (:recent_inhibition, 1.5))
    end

    # ── Drop-table collision ───────────────────────────────────────
    # Con: a token in this node's drop_table is hot in user input.
    user_tokens = Set{String}()
    for t in ctx.user_triples
        union!(user_tokens, lowercase.(split(t.subject)))
        union!(user_tokens, lowercase.(split(t.object)))
    end
    drop_collision = length(intersect(Set(node.drop_table), user_tokens))
    if drop_collision > 0
        push!(cons, (:drop_table_collision, Float64(drop_collision)))
    end

    return (pros, cons)
end
```

**This is the entire intelligence of the relevance gate.** ~50
lines. Every signal is a literal pointer. Every weight is computed
from a number that was already in the engine (relation_weight,
overlap count, intensity, fixed constant tied to a specific source).

To add a new signal: edit this function, document it in this section,
add a tuning entry to phase 2 of §9. Nowhere else.

---

## 6. Activation flow — where it slots into scan

The patch to `engine.jl` is essentially additive:

```diff
   # inside scan_specimens worker body (engine.jl:~2531):
   if node.is_grave
       return nothing
   end

   if !strength_biased_scan_coinflip(node)
       return nothing
   end

+  # NEW: second-order relevance gate.
+  decision = relevance_gate(node, scan_ctx)
+  if decision == SKIP
+      return nothing
+  end
+  # FIRE and LET_STRENGTH_DECIDE both fall through to the scan.

   if !node.is_image_node
       if length(target_signal) < length(node.signal)
           return nothing
       end
   end
   # ... existing pattern scan ...
```

`scan_ctx::ScanContext` is built once at the top of `scan_specimens`,
**before** the per-node loop, and passed in via closure or
threadlocal.

In phase 1, FIRE and LET_STRENGTH_DECIDE behave identically (both
fall through to pattern scan). The distinction matters for telemetry
(was this fire forced upward? was it just allowed?) and for future
phase 2 tuning where FIRE could trigger a small confidence bump or
similar. Phase 1 logs the distinction, doesn't act on it.

---

## 7. Persistence — none

The relevance gate has **no persistent state**. It is a pure
function of `(node, scan_ctx)`. Nothing to save, nothing to load,
no specimen migration, no JSON registry. The three tuning constants
live in `engine.jl` next to `STRENGTH_CAP` and `RELAY_CONF_JITTER_SIGMA`.

This is one of the cleanest properties of the design and is worth
preserving. If we ever need per-node relevance memory ("this node
gets relevance-overridden upward 80% of the time — promote it"), that
is a phase-3 idea, not a phase-1 one, and it would fold into the
existing strength dynamic rather than introducing new persistence.

---

## 8. Feedback — `/right` and `/wrong` integration

The gate's decisions are logged per-cycle in a small
`relevance_gate_log::Vector{Tuple{String, Symbol, GateDecision, Float64}}`
attached to the cycle telemetry, holding `(node_id, top_signal_symbol,
decision, jittered_margin)` for every node the gate evaluated.

On `/right`:
- For every node that fired with decision `FIRE`: small bonus to
  whatever weight constant in `emit_pros_cons` produced its top signal
  (e.g., if `:macro_activation` was top, increment a learned multiplier
  on that signal). Same coinflip-gated approach as existing
  `/right` strength bumping.
- For every node that fired with `LET_STRENGTH_DECIDE`: existing
  strength bump. No relevance-gate change.

On `/wrong`:
- For every node that fired with `FIRE`: small penalty to top-signal
  weight (the gate over-promoted this node).
- For every node that was `SKIP`'d: no action — we don't know if the
  skip was correct or not without more info.

This keeps the feedback loop **localized to the same emitter
function** — tuning the weights in `emit_pros_cons` is the only
learning surface. No new learning subsystems.

**Phase 1 deliberately ships without /right /wrong wiring.** Get the
gate working with hardcoded weights first, observe behavior, then
wire feedback in phase 2. Premature feedback loops on an unmeasured
signal are how systems acquire mysterious drift.

---

## 9. Phased rollout

### Phase 1 — gate scaffold, no tuning, telemetry only
- [ ] Add `ScanContext` struct in `engine.jl` near scan_specimens.
- [ ] Populate `ScanContext` once at top of `scan_specimens`.
- [ ] Implement `relevance_gate` and `emit_pros_cons` per §4 and §5.
- [ ] Wire into per-node loop per §6.
- [ ] Add cycle-level telemetry vector, log every gate evaluation.
- [ ] Hardcode all weights and thresholds at proposed defaults.
- [ ] Run existing tests; verify no regressions in vote outcomes for
      a representative input corpus.
- [ ] Add a `/relevanceStatus` command that prints last cycle's gate
      decisions: how many FIRE, how many SKIP, how many
      LET_STRENGTH_DECIDE, top-signal histogram.

### Phase 2 — observe and tune
- [ ] Run the bot for a few hundred cycles across diverse inputs.
- [ ] Inspect `/relevanceStatus` histograms — are the override rates
      sensible? (Rough target: 5–15% FIRE, 5–15% SKIP, 70–90%
      LET_STRENGTH_DECIDE in normal use.)
- [ ] Tune `RELEVANCE_GATE_FIRE_THRESHOLD`,
      `RELEVANCE_GATE_SKIP_THRESHOLD`, and per-signal weights to hit
      target ratios.
- [ ] Spot-check a handful of FIRE and SKIP cases manually — was the
      gate's decision defensible?

### Phase 3 — feedback wiring (optional, gated on phase 2 results)
- [ ] Wire `/right` and `/wrong` per §8.
- [ ] Add per-signal learned multipliers (one float per emitter
      symbol, persists in specimen save like strength does).
- [ ] Reassess after several feedback cycles.

### Phase 4 — consider Option B (deferred)
- [ ] Only if phase 2 reveals that genuinely-relevant weak nodes are
      starving (i.e., the strength coinflip floor is hurting more than
      helping), revisit collapsing the strength coinflip into a
      relevance-gate signal. See §10 Q1.

---

## 10. Open questions still requiring sign-off before code

**Q1 — strength as hard floor or soft prior?**
Phase 1 commits to Option A (strength is hard floor; gate runs only
after strength coinflip says yes). This is conservative and reversible.
Sign off: do you want phase 1 to ship Option A as proposed, or jump
straight to Option B (strength-as-pro)?

**Q2 — should `emit_pros_cons` be allowed to read NODE_MAP?**
The §5 invariant forbids global lookups inside `emit_pros_cons` so
the function stays pure and parallelizable. The cost is that some
signals (like "a sibling with the same pattern already fired") need
to be pre-bundled into `ScanContext` instead of computed per-node.
Sign off: keep the invariant, or relax it for phase 1 ergonomics?

**Q3 — default thresholds.**
Proposed: `FIRE_THRESHOLD = SKIP_THRESHOLD = 2.0`,
`JITTER_FRACTION = 0.10`. These are guesses. They will get tuned in
phase 2 by observing histograms. Are these starting points acceptable,
or do you want to constrain the FIRE/SKIP ratio asymmetrically from
day one (e.g. easier to skip than to promote)?

**Q4 — sibling-fire con signal.**
The §5 sketch left this as a placeholder. To implement it without
breaking the no-globals invariant, `ScanContext` would need a
`fired_patterns::Set{String}` field that the scan loop updates as
nodes fire. This means the scan_ctx is mutable in one specific way.
Sign off: add the mutable field, or drop this signal from phase 1?

**Q5 — does this make hippocampal signal "double-counted"?**
Pinned-memory resonance is one of the gate's pros. The intensity
refresh (Main.jl:715) already biases which messages survive in
MESSAGE_HISTORY. If a memory survives because it's relevant, and
then *also* boosts a node's relevance via the gate, are we
double-counting that signal? Probably not — they affect different
substrates (memory survival vs. node firing) — but worth confirming
intent.

---

## 11. Design boundaries — what this plan deliberately rejects

- **No semantic-role taxonomy.** Pros/cons are pointers to engine
  artifacts, not annotations of meaning.
- **No new persistent state.** Gate is a pure function. Tuning
  constants live as module constants.
- **No replacement of the strength coinflip in phase 1.** Layering,
  not folding. Reversibility preserved.
- **No free-form pros/cons populator.** All emission lives in
  `emit_pros_cons`. Adding a signal means editing that one function
  and updating §5.
- **No render-side pros/cons system.** The earlier "AIML modulator"
  framing is superseded; this gate replaces it entirely. Better gates
  beat better renderers — fix the input to AIML, not the post-process.
- **No deliberation / reasoning step.** Sums and comparisons only.
  Anything that looks like weighing reasons is, by definition, out
  of scope for this layer.
- **No global state reads inside `emit_pros_cons`.** Everything flows
  through the `ScanContext` parameter. This is what makes the
  function auditable and parallel-safe.
- **No coupling with the macro layer beyond one read.** The gate
  reads `ctx.macro_activated_node_ids` and that's it. The macro
  system is otherwise fully independent.

---

## 12. Quick-reference change-summary table

| Site | Change | Lines (est.) |
|---|---|---|
| `engine.jl` — new `ScanContext` struct | additive | ~12 |
| `engine.jl` — new `relevance_gate` function | additive | ~25 |
| `engine.jl` — new `emit_pros_cons` function | additive | ~50 |
| `engine.jl` — three new tuning constants | additive | ~3 |
| `engine.jl` — `scan_specimens` populates `ScanContext` | additive | ~10 |
| `engine.jl` — per-node loop calls `relevance_gate` | 4-line insert | ~4 |
| `engine.jl` — cycle telemetry vector | additive | ~8 |
| `Main.jl` — `/relevanceStatus` command | additive | ~20 |
| `Vote` struct | unchanged | 0 |
| `Node` struct | unchanged | 0 |
| `parse_action_packet` | unchanged | 0 |
| `cast_vote` | unchanged | 0 |
| `generate_aiml_payload` | unchanged | 0 |
| Persistence layer | unchanged | 0 |
| Feedback (`/right`, `/wrong`) | unchanged in phase 1 | 0 |

**Net phase-1 change: ~130 lines of additive code in `engine.jl`,
~20 lines in `Main.jl`, zero changes to existing structs or
synthesis pipeline.**
