# v9 Meta-Cognitive Extensions — Design Document

Five proposals for the next evolutionary step of the GrugBot architecture, each grounded in what already exists and what's missing. Written to be implemented as independent, composable modules.

---

## 1. Operator Genesis — Self-Discovery of New Primitives

### What the feedback said

> A → B, B → C, A → C appears thousands of times. At what point does Grug invent a new relation sigil representing transitivity itself? Not learn it. Create it.

### What Grug already has

Grug already has the **mechanism** for creating new relation sigils. The `/addRelRelation` command calls `register_relation_sigil!` which inserts a `:relation`-class sigil into `_ENGINE_SIGIL_TABLE` with a name and an expansion list of alternative verbs. The SigilRegistry validates it, the SigilPromoter promotes tokens that match the lexicon, and the engine's relational scanner expands `&causes` into `["causes", "produces", "leads_to", ...]` at match time. This is all live code. The system also has `relational_governance` which tracks triple frequency and applies Hebbian strengthening.

What Grug does **NOT** have is the *loop*: a process that watches for recurring structural patterns in the triple store, recognizes them as candidates for abstraction, and **automatically** calls `register_relation_sigil!` without human intervention. Right now every new sigil comes from a `/addRelRelation` command typed by a user.

### The missing piece: a Pattern Miner

The architecture needs a background process — call it `PatternMiner` — that periodically walks the relational triple store looking for structural motifs. Not frequency of individual verbs (governance already does that), but frequency of **graph shapes**. The simplest entry point:

1. **Transitivity detection**: Count occurrences of `(A → R1 → B, B → R2 → C, A → R3 → C)` where R1, R2, R3 are all in the same semantic class. When this shape exceeds a threshold (say 10 independent instances), the miner proposes a new `:relation` sigil whose expansion is the union of {R1, R2, R3} alternatives, and whose name is a compressed token like `&transitive_R1`. This isn't learning transitivity as a concept — it's **recognizing that the pattern has enough warrant to become a primitive**, then minting the primitive.

2. **Chaining detection**: `(A → R → B)` where B is also `(B → R → C)` and the same relation R chains. When a single relation verb chains across ≥5 node pairs, the miner proposes `&chain_R` whose expansion adds the chain-verb to the original R's alternatives.

3. **Symmetry detection**: `(A → R → B)` and `(B → R → A)` co-occurring. Propose `&symmetric_R`.

### Implementation approach

```
PatternMiner.jl (new module)
  - Runs on a timer (every N messages or every T seconds)
  - Reads the triple store from engine (read-only snapshot)
  - Counts graph-shape occurrences
  - When a shape exceeds threshold:
      1. Propose a new :relation sigil name + expansion
      2. Write the proposal to a "genesis queue" (not auto-registered)
      3. The queue is consumed by /answer pipeline
      4. User says "yes" → register_relation_sigil! is called
      5. User says "no" → proposal discarded, shape's count reset
  - Genesis proposals carry: proposed_name, shape_type, instance_count,
    example_triples, proposed_expansion
```

The key design constraint: **genesis is proposed, not forced**. The system discovers the pattern and presents it. A human (or a later meta-cognitive loop) approves registration. This prevents the system from minting junk sigils from noise. Once the meta-cognitive loop (section 3) is mature enough, the approval gate can be automated based on coherence impact — does registering this sigil improve global coherence scores?

### Why this is different from learning

Learning a pattern means recognizing it next time. Genesis means the pattern becomes a **first-class operator** that other patterns can reference. After genesis, `&transitive_causes` is on the same footing as `&causes` — it can appear in patterns, be promoted by the SigilPromoter, and expand during relational scanning. The pattern went from recurring observation to named primitive. That's invention, not recognition.

---

## 2. Coherence-Gradient Routing

### What the feedback said

> What if routing happened based on coherence gradients? Activation spreads, candidate interpretations form, the system measures which interpretation produces the highest global coherence score, routing follows the coherence field. Almost like energy minimization except the energy function is coherence itself.

### What Grug already has

Grug already computes coherence in at least four separate places:

- **PatternScanner**: `big_number_small_number_coherence(forward, backward)` fuses bidirectional scan confidences into a single [0,1] value. This is per-pattern, per-node.
- **ActionTonePredictor**: `_compute_emotional_coherence(action, tone)` measures whether the predicted action and tone are compatible. Per-prediction.
- **ImageSDF**: `coherence_score` tracks temporal stability of SDF alignments over time. Per-SDF, accumulates across timesteps.
- **TemporalCoherenceRecord**: Tracks `avg_interval`, `fire_count`, `coherence_score` per SDF. This is the closest thing to a running coherence field that already exists.

The voting system (`VoteOrchestrator`) also does something adjacent: it computes a composite score per candidate that includes lobe affinity, relational hits, tone match, peak recency, and frame_match_multiplier. But this composite is computed **per candidate in isolation** — it doesn't measure how a candidate's activation affects the coherence of the *rest* of the field.

What Grug does **NOT** have is: a process that says "if I activate node X, what happens to the global coherence of the entire network?" Right now, routing picks the highest-scoring candidate. It doesn't ask whether picking that candidate makes the overall state more or less coherent.

### The missing piece: a coherence field

The idea is to treat coherence not as a per-node score but as a **scalar field** over the activation state. When a node fires, it perturbs the field. The perturbation has a sign — it either increases or decreases global coherence. Routing should prefer candidates whose activation increases the field.

Concretely:

1. **Define the field**: At any point in time, the coherence field Φ is:

   ```
   Φ = Σ_i coherence(i) × activation(i)
   ```

   where `coherence(i)` is the node's stored coherence (from scanner + SDF + temporal records) and `activation(i)` is its current activation level (fired/not-fired, with recency decay).

2. **Compute the gradient**: When candidate X is about to be routed, compute:

   ```
   ΔΦ_X = Φ(after X fires) − Φ(before X fires)
   ```

   The "after" state includes secondary effects: nodes connected to X via triples, nodes in the same lobe, nodes sharing inhibition links. This is a bounded-depth graph walk — depth 2 is probably sufficient.

3. **Use the gradient as a routing modifier**: Add `ΔΦ_X` as a term in the VoteOrchestrator's composite score. If activating X would increase global coherence, X gets a bonus. If it would decrease coherence (e.g., X inhibits several high-coherence nodes), X gets a penalty.

4. **The field self-organizes**: Over time, routing preferentially activates nodes that make the overall state more coherent. This creates positive feedback: coherent regions become more coherent (basins of attraction), while incoherent regions get suppressed. The system naturally gravitates toward coherent interpretations without any explicit "select the coherent one" step.

### Why this is different from current voting

Current voting is **local**: each candidate is scored independently. The coherence gradient is **global**: it measures how a candidate affects the entire field. The difference is like hill-climbing vs. gradient descent — hill-climbing picks the steepest local step, gradient descent follows the global slope.

The existing strange-attractor detection in ActionTonePredictor is the closest analog — it detects when one category dominates and damps it. But that's a **negative** mechanism (prevent lock-in). The coherence gradient is a **positive** mechanism (actively seek coherent states). Both are needed.

### Implementation approach

```
CoherenceField.jl (new module)
  - compute_field(nodes, triples, coherence_records) → Float64
  - compute_delta(candidate, nodes, triples, coherence_records) → Float64
  - Both are O(depth² × |neighbors|) — bounded by depth-2 walk
  - Integration point: VoteOrchestrator adds coherence_delta to composite score
  - Weight starts at 0.1 (10% of score contribution) and can be tuned
```

The critical design constraint: this must be **cheap to compute**. A depth-2 walk from a candidate touches maybe 20-50 nodes. Computing coherence deltas for the top-10 candidates means ~500 coherence lookups. If coherence is cached per-node (it already is in multiple places), this is a hash-map read, not a scan. Total overhead: sub-millisecond per cycle.

---

## 3. Meta-Sigils — Sigils for Patterns of Sigils

### What the feedback said

> &entity &causal &entity becomes &cause_structure. Then structures themselves become compressible. Eventually reasoning starts operating on motifs rather than individual relations.

### What Grug already has

The SigilRegistry already supports `:procedure`-class sigils (reserved for Stage 6) — "named ordered chain of sigils+literals." The `SIGIL_CLASSES` tuple includes `:procedure` and `:functor` as reserved slots. The `expand_procedure_sigil` function already exists as a stub. The `SIGIL_APPLIES_AT` enum includes `:vote_shape` (reserved for Stage 3).

What Grug does **NOT** have is: a mechanism for a sigil to contain **other sigils as its expansion**, where the contained sigils are evaluated in sequence and the composite result is treated as a single unit. Right now, a `:macro` sigil expands to a list of alternative **strings**. A `:relation` sigil expands to alternative **verbs**. Neither expands to a **structured pattern of sigils**.

### The missing piece: structural sigils

A meta-sigil (call the class `:structure`) is a sigil whose expansion is an **ordered sequence of sigil references plus literal tokens**. When the pattern matcher encounters a `:structure` sigil, it expands the structure inline — effectively inlining the sub-pattern.

Example:

```
&cause_structure expands to: [&entity &causal &entity]
```

When the matcher sees `&cause_structure` in a pattern, it's as if the pattern contained `&entity &causal &entity` at that position. The bindings from the sub-sigils propagate upward.

This is compressible:

```
&cause_structure → [&entity &causal &entity]
&enable_structure → [&entity &enables &entity]
&narrative_arc → [&cause_structure &enable_structure &cause_structure]
```

At the third level, `&narrative_arc` expands through two layers of structure sigils to a flat pattern of 9 tokens. But reasoning can operate on `&narrative_arc` directly — it doesn't need to decompose it unless it wants to.

### How this connects to Operator Genesis

When the PatternMiner (section 1) detects a recurring graph shape, it currently proposes a `:relation` sigil. But some shapes aren't just relation alternatives — they're **structural motifs**. Transitivity is a structural motif: "A causes B, B causes C, therefore A causes C." This isn't a single relation verb; it's a three-triple pattern with a logical consequence.

With `:structure` sigils, the PatternMiner can propose:

```
&transitive_causes → [&causes &causes &implies]
```

This is a meta-sigil that compresses the transitive chain into a named operator. When the engine encounters this sigil in a pattern, it knows to look for chains. When it encounters it in a triple, it knows to infer the transitive closure.

### Implementation approach

```
1. Add :structure to SIGIL_CLASSES (7 → 8 classes)
2. Add :structure_expansion field to SigilEntry:
     structure_expansion::Union{Nothing, Vector{SigilToken}}  # nil for non-structure
3. SigilToken = Union{String, Symbol}  # literal text or &sigil reference
4. expand_structure_sigil(table, name) → Vector{String}
     - Recursively expand any sigil references in the expansion
     - Return flat token list for pattern matcher
5. Pattern matcher: when &name is :structure class, inline the expansion
6. This is the Stage 6 that's already reserved — we're just defining its shape
```

The key insight: `:structure` sigils are **not a new mechanism**. They're the natural completion of the existing sigil hierarchy: `:lambda` binds a value, `:macro` binds an alternative, `:relation` binds a verb class, `:structure` binds a sub-pattern. Each level compresses more. The SigilPromoter already does layer-2 compression (surface variants → canonical form). Structure sigils do layer-3 compression (sub-patterns → named motifs).

---

## 4. Temporal Identity — Continuity Through Change

### What the feedback said

> Seed → plant → tree → dead tree → rotting log → soil. Humans can see continuity there. Most systems treat them as different objects. If Grug already has strong temporal coherence, I'd be curious whether it can build object identity as a first-class structure. Not memory. Identity. The thing that remains itself while changing.

### What Grug already has

Time node sigils (`&now`, `&before`, `&next`) orient nodes in temporal space. The `time_orientation_config` section preserves orientation metadata across save/load. `TemporalCoherenceRecord` tracks firing regularity per SDF. The `ImageSDF` module has `coherence_score` that measures temporal stability — how consistently an SDF fires at the same interval.

What Grug does **NOT** have is: a concept of **identity** that persists across state change. Right now, `seed → plant → tree` would be three separate nodes connected by `&temporal` relation triples. The engine treats them as three things. It has no representation of "these are the same thing at different times."

### The missing piece: identity continuants

An identity continuant (borrowing from BFO ontology terminology) is a first-class object that represents **the thing that persists** across temporal transformation. It's not a node — it's a higher-order structure that groups a temporal chain of nodes under a single identity.

Concretely:

```
Continuant:
  id: "oak_001"
  class: "oak"                  # what kind of thing this is
  stages: [                      # ordered temporal stages
    {node_id: "seed_42",  phase: "seed",       orientation: :before}
    {node_id: "sprout_7", phase: "sprout",     orientation: :before}
    {node_id: "tree_93",  phase: "tree",       orientation: :now}
    {node_id: "stump_12", phase: "dead_tree",  orientation: :next}
  ]
  coherence: 0.87               # how tightly these stages cohere as one identity
  transform_rules: [             # what transitions are valid
    "seed → sprout"    (natural)
    "sprout → tree"    (natural)
    "tree → dead_tree" (natural)
    "dead_tree → soil" (natural)
  ]
```

The continuant is NOT the union of its stages. It's the **identity** that the stages share. When the engine encounters `tree_93`, it can ask "what is this thing?" and get back `oak_001` — which also includes `seed_42`, `sprout_7`, and `stump_12`. The answer to "what was this?" and "what will this become?" comes from the continuant's stage list, not from walking temporal triples.

### How this connects to existing time nodes

Time nodes already have `orientation` (`:before`, `:now`, `:next`). A continuant groups time-oriented nodes that share an identity. The `time_orientation` on each node becomes the **phase index** within the continuant.

Current flow:
```
seed_42 → [&temporal] → sprout_7 → [&temporal] → tree_93
```

With continuants:
```
oak_001.continuant → stages = [seed_42(:before), sprout_7(:before), tree_93(:now), ...]
```

The temporal triples still exist (they're the raw graph). The continuant is a **derived structure** that sits on top of them — a named, queryable identity that composes over the temporal chain.

### The key property: identity ≠ memory

Memory is "I remember that X was Y." Identity is "X **is** Y, just at a different time." The difference matters for routing:

- **Memory-based retrieval**: "What was seed_42 before?" → walk triples, find sprout_7.
- **Identity-based retrieval**: "What is seed_42?" → `oak_001`. The answer is the identity, not the history.

With identity, the engine can answer "is seed_42 the same thing as tree_93?" without walking the graph. It just checks: do they share a continuant? This is O(1) instead of O(depth).

### Implementation approach

```
TemporalIdentity.jl (new module)
  - Continuant struct: id, class, stages, coherence, transform_rules
  - ContinuantStore: Dict{String, Continuant}  # keyed by continuant id
  - Stage index: Dict{String, String}          # node_id → continuant_id (reverse lookup)
  - create_continuant(class, stage_nodes) → Continuant
  - add_stage!(continuant, node_id, phase, orientation)
  - identity_of(node_id) → Union{Continuant, Nothing}
  - stages_of(continuant_id) → Vector{Stage}
  - what_was(continuant_id, orientation) → Vector{Node}  # all stages at that orientation
  - what_becomes(continuant_id, from_phase) → Vector{Stage}  # downstream stages
  - coherence_of(continuant_id) → Float64  # how tightly stages cohere

  - Discovery: background process that walks temporal chains and proposes
    continuant groupings when chain coherence exceeds threshold.
    Same proposal/approval pattern as PatternMiner.
```

The continuant's `coherence` field is key — it's computed from the temporal coherence records of its stages. If the stages fire in a consistent temporal pattern, the continuant has high coherence and is a strong identity. If the stages are temporally scattered, the continuant is weak and may not deserve to exist.

---

## 5. State-Space Geometry — Cognition as Spatial Operation

### What the feedback said

> Instead of "find related concept" you do "find nearest stable region." Instead of "resolve ambiguity" you do "collapse competing geometries." Everything should become a spatial operation.

### What Grug already has

Grug is already more geometric than it appears. The comments in the code say it directly:

- `ImageSDF.jl` line 9: "Temporal coherence uses timestep as **meta-geometry** to organize alignments."
- `ImageSDF.jl` line 71: "Time step is **meta-geometry**! Grug use timestamps to organize SDF alignments."
- `EphemeralAutomaton.jl`: Phase vectors are distributions in a metric space, with Jensen-Shannon distance as the metric. High-coherence entries cluster near each other in phase space.
- `ActionTonePredictor.jl`: Strange-attractor detection treats the action-tone space as a dynamical system. Category dominance → attractor. Damping → escape from attractor.
- `VoteOrchestrator.jl`: Composite scores effectively define a scalar field over the candidate set. Peak detection finds local maxima.
- `patternscanner.jl`: `big_number_small_number_coherence` treats forward/backward confidences as a 2D measurement that differentiates signal from noise based on where the point falls in the (forward, backward) plane.

What Grug does **NOT** have is: a **unified** geometric framework that makes these separate spaces interoperable. Right now, the action-tone space, the phase space, the coherence space, and the relational graph are four separate geometries. The engine doesn't have a way to say "the nearest stable region in action-tone space corresponds to this basin in coherence space."

### The missing piece: a unified state-space

The proposal isn't to build a new geometry from scratch — it's to **recognize that the geometries already exist** and make them explicit, named, and navigable.

1. **Name the spaces**:

   - `SemanticSpace`: The graph of nodes + triples. Distance = shortest path weighted by triple strength. Nearest stable region = most strongly connected cluster.
   - `CoherenceSpace`: The field Φ from section 2. Distance = difference in coherence. Basins = high-coherence regions. Ridges = low-coherence boundaries.
   - `PhaseSpace`: The EphemeralAutomaton's phase vectors. Distance = JS divergence. Stable regions = high-coherence phase clusters.
   - `ToneSpace`: The ActionTonePredictor's action×tone categories. Distance = confusion probability. Attractors = dominant categories. Basins = balanced distributions.

2. **Define cross-space mappings**:

   Each node exists in all four spaces simultaneously. A node has a position in SemanticSpace (its graph neighborhood), a position in CoherenceSpace (its coherence score), a position in PhaseSpace (its SDF phase vector), and a position in ToneSpace (its action-tone prediction).

   The cross-space mapping is: **a region in one space corresponds to a region in another space via the shared node set**. If nodes {A, B, C} form a cluster in SemanticSpace (they're graph-adjacent), then their corresponding points in CoherenceSpace form a region (their coherence scores are similar because they fire together).

3. **Operations become spatial**:

   | Current operation | Spatial reformulation |
   |---|---|
   | Find related concept | Find nearest stable region in SemanticSpace |
   | Resolve ambiguity | Collapse competing basins in CoherenceSpace |
   | Detect lock-in | Find attractor in ToneSpace |
   | Choose routing path | Follow coherence gradient in CoherenceSpace |
   | Infer temporal identity | Trace trajectory in SemanticSpace through temporal dimension |
   | Discover new operator | Find recurring shape in SemanticSpace, mint as named region |

4. **The geometric primitive**: All operations reduce to three spatial primitives:

   - **nearest**(point, space) → find the closest stable region
   - **gradient**(point, space) → compute the local slope of the coherence field
   - **collapse**(competing, space) → merge overlapping regions into one

   Everything else is composition of these three.

### Why this matters

Right now, the engine's code is organized around **mechanisms** (voting, scanning, cascading, inhibiting) that each implement their own spatial intuition. The geometry is implicit — buried in the math of each module. Making it explicit means:

- New features are expressed as spatial operations, not new mechanisms.
- Debugging is inspecting the geometry, not tracing mechanism flow.
- Optimization is tuning the geometry (distances, gradients), not tuning individual module parameters.
- The system becomes **geometrically coherent** — all its operations share the same spatial vocabulary.

### Implementation approach

This is the most ambitious proposal and should be approached incrementally:

```
Phase 1: Name the spaces
  - Add SemanticSpace, CoherenceSpace, PhaseSpace, ToneSpace as named
    concepts in the codebase (types + documentation, not yet implementations)
  - Document which existing modules already compute in each space
  - Define the cross-space mapping formally (shared node set as the bridge)

Phase 2: Explicit distances
  - Extract distance functions from existing modules into a shared
    GeometryKit module
  - SemanticSpace distance: already in graph traversal (engine.jl)
  - CoherenceSpace distance: already in big_number_small_number_coherence
  - PhaseSpace distance: already in _distribution_js_distance
  - ToneSpace distance: already in ActionTonePredictor confusion matrix

Phase 3: Navigation operations
  - nearest(point, space) → implemented per space
  - gradient(point, space) → depends on CoherenceField (section 2)
  - collapse(competing, space) → merge basins, resolve to winner

Phase 4: Cross-space queries
  - project(space_a, space_b, region_a) → region_b
  - This is the bridge: given a cluster in one space, find the
    corresponding cluster in another space via shared nodes
```

The end state: every cognitive operation is a spatial operation on a named geometry, and the geometries are connected through the shared node substrate. The system isn't just *like* a dynamical system — it **is** a dynamical system, and all its operations are geometrically grounded.

---

## Dependency Graph

```
Section 1 (Operator Genesis)    → independent, can build first
Section 2 (Coherence Gradient)  → independent, can build first
Section 3 (Meta-Sigils)         → depends on Section 1 (PatternMiner proposes :structure sigils)
Section 4 (Temporal Identity)   → depends on existing time nodes (already built)
Section 5 (State-Space Geometry)→ depends on Section 2 (coherence field is one of the spaces)
```

Sections 1 and 2 can be built in parallel. Section 3 builds on 1. Section 4 is standalone. Section 5 is the capstone that unifies everything.

---

## Architectural Philosophy

All five proposals share a common move: **take something the system already does implicitly and make it explicit, named, and first-class**.

- Operator Genesis: the system already *has* recurring patterns — make them nameable primitives.
- Coherence Gradient: the system already *computes* coherence — make it a navigable field.
- Meta-Sigils: the system already *has* reserved slots for :structure — fill them with real compression.
- Temporal Identity: the system already *tracks* temporal chains — give them identity, not just history.
- State-Space Geometry: the system already *operates in* geometric spaces — name them and navigate them explicitly.

This is the Grug way: no new magic, just making existing mechanisms do more by making them visible to themselves.
