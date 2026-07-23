# EphemeralMLP Multi-Purpose Organ Spec
# The LLM Is Not Just Transient Memory — It's the Brain's Consultant Organ

---

## Current Capabilities (What EphemeralMLP Already Does)

The EphemeralMLP (`::M`, "the LLM") is currently a **vote-list consultant organ** that wakes up, processes the current vote list, writes adjustments, and goes dormant. Its persistent state survives across cycles and specimen save/load. Specifically it does:

1. **Action/Tone Prediction** — Sigmoid/ReLU dual-path transformer processes vote features (24-dim) through 2 transformer blocks with multi-head attention, producing 4 output heads: directive_quality, semantic_score, relevance_score, disambiguation.

2. **Novelty Detection** — Rolling window of vote-list hashes tracks input familiarity. Novel inputs route through ReLU/fuzzy transformers (exploratory); familiar inputs route through Sigmoid/solid transformers (refining).

3. **Hippocampal Strain Signal** — When the MLP encounters novel input it can't handle well (high novelty + low directive_quality), strain_energy rises (0.0–1.0). At strain >= 0.55 with SelfObserver confirmation, hippocampal_warrant_active fires, signaling that the system hurts and needs growth.

4. **Input→Directive Correlation Tracking** — Learns which user inputs tend to produce good or bad directive quality, so it can route familiar inputs through the solid path with confidence.

5. **Phase Mix (Hippocampal Retrieval)** — ATP phase snapshots from the automaton's time crystal blend into the hidden state. 12-dim ATP distributions projected to 64-dim hidden space. The automaton's voice in the MLP's brain.

6. **User Rules** — Pattern/key-activated hash table with drop tables for cascading activation. User-extensible directives that bias transformer output.

7. **Right/Wrong Feedback** — `/right` and `/wrong` nudges adjust weights (learning rates 0.05/0.08).

8. **Jitter Snap-Back** — Zero-mean perturbation on jitter-eligible weights. Exploration without drift. Same principle as RelationalJitter.

---

## Proposed Multi-Purpose Capabilities

### 1. CURIOSITY ACCUMULATOR (replaces "curiosity node type")

**What:** A per-lobe curiosity accumulator that lives in LobeTable's CHUNK_META, maintained by the EphemeralMLP during its strain computation pass. Not a node type. Not a separate module. A function of the MLP organ itself.

**How it works:**
- Each lobe gets a `curiosity_buffer` entry in its CHUNK_META: `Dict{String, Any}` with keys `{buffer: Vector{String}, intensity: Float64, last_overflow: Float64, subject: String}`
- During `transform_vote_list`, the MLP already computes novelty and strain. When strain is high AND there are uncovered tokens in the input relevant to a lobe's subject, the MLP writes those tokens to that lobe's curiosity buffer
- **Thesaurus coherence gate:** before writing a token, check thesaurus similarity against ALL existing curiosity buffer entries across ALL lobes. If any existing entry has similarity >= SYNONYM_SEED_THRESHOLD (0.70), skip — the concept is already being tracked somewhere
- **Intensity accumulation:** each recurrence of a buffered token (or its thesaurus neighbors) increments intensity. Intensity decays with half-life (same as AutoGrowth: 3600s)
- **Overflow threshold:** when intensity >= CURIOSITY_OVERFLOW_THRESHOLD (e.g. 5.0), the MLP generates a hippocampal ask-question using the buffered context. The existing `_HIPPOCAMPAL_PENDING_ASK` mechanism in Main.jl already handles this
- **Quench:** after asking, the entire curiosity entry resets — buffer empties, intensity zeros. The answer goes through the normal hippocampal cycle (`_plant_answer_cluster`) and becomes a regular match node
- **Answer fuels growth:** the quenched answer becomes AutoGrowth evidence during idle, which can trigger node growth via the existing `maybe_grow_from_evidence!` pipeline

**Why the MLP owns this:** Curiosity is a *strain phenomenon*. The MLP already computes strain_energy and novelty. The MLP already knows which inputs it can't handle. Curiosity is just strain with memory — the same signal, accumulated over time until it overflows into action. No other organ has both the strain signal and the persistent state to accumulate it.

**Storage:** LobeTable CHUNK_META, not a new data structure. The MLP reads/writes it during its cycle. Existing `table_put!` / `table_get` API. Zero new infrastructure.

---

### 2. PETTY LEARNING FAST-PATH (side-system writes, no node growth)

**What:** When the MLP encounters a "petty thing" — a new word, a simple math fact, a spelling variant — it writes directly to the appropriate side system instantly. No evidence accumulation, no coinflip, no node growth. Just immediate side-effect.

**Petty categories and their targets:**

| Category | Detection | Target System | Write Operation |
|----------|-----------|--------------|-----------------|
| New word (unknown token, user defines it) | Token not in any node pattern + user says "X means Y" or "X is Y" | Thesaurus | `register_thesaurus_pair_fn(new_word, definition_keyword)` — instant synonym seed |
| Spelling variant | Token has trigram similarity >= 0.5 to existing pattern but no match | Thesaurus | `register_thesaurus_pair_fn(variant, canonical)` — instant synonym |
| Simple math fact | ArithmeticEngine already computed the answer (has_math_bindings() == true) | SigilRegistry expansion | Write result to `&noun` lexicon under the expression string (e.g. "two plus two" → "4") |
| Domain token for lobe | Token matches lobe subject but not in lobe's subject_whitelist | Lobe.whitelist | `add_lobe_whitelist_fn(lobe_id, token)` — instant whitelist entry |
| Pronoun/connector pattern | Recurring short pattern (1-2 words) that co-occurs with existing nodes | Co-occurrence map | `_CO_OCCUR_MAP` update (already happens in AutoGrowth, but petty path skips evidence floor) |
| Negation pattern | User explicitly says "don't X" or "not X" and X is an existing pattern | Antimatch side-channel | Record negation in CHUNK_META as a "soft antimatch hint" — not a full antimatch node, just a confidence dampener flag |

**The gate:** The MLP already computes `directive_quality` and `semantic_score`. When the answer is simple (high directive_quality, low novelty, simple structure), the MLP tags it as "petty" during its forward pass. The petty tag routes through a fast path that writes directly to side systems instead of feeding AutoGrowth evidence.

**Why this matters:** Currently, even learning the word "cat" when you already know "feline" goes through the full evidence → coinflip → node growth pipeline. That's 3+ observations over an hour before the thesaurus gets the pair. With the petty fast-path, it happens on the first mention. The system learns simple things instantly and complex things conservatively. That's how real brains work — you don't need to hear a synonym three times to learn it, but you DO need to hear a complex concept three times before you build a node for it.

---

### 3. CONVERSATION RHYTHM DETECTION

**What:** The MLP already tracks `last_transform_time`, `total_transforms`, and input correlation history. Extend it to detect conversational rhythms — is the user asking rapid-fire questions? Are they in a slow reflective mode? Are they testing the system? Are they bored?

**Rhythm signals the MLP can compute from existing data:**
- **Turn cadence:** time between consecutive `transform_vote_list` calls. Fast = rapid-fire. Slow = reflective.
- **Novelty streak:** consecutive high-novelty inputs = user is exploring. Consecutive low-novelty = user is drilling.
- **Strain trajectory:** is strain rising, falling, or stable? Rising = system is falling behind. Stable = comfortable. Falling = recovering from growth.
- **Feedback pattern:** consecutive `/wrong` = user is correcting. Consecutive `/right` = user is validating. No feedback = user is just talking.

**What the rhythm signal can modulate:**
- AutoGrowth rate: in reflective mode, grow faster (user is patient, give them more). In rapid-fire mode, grow slower (user wants answers, not growth).
- Curiosity overflow threshold: in reflective mode, overflow sooner (ask more questions). In rapid-fire mode, hold back (don't interrupt with questions).
- AIML voice register: in reflective mode, use deeper/philosophical voice. In rapid-fire mode, use terse/factual voice.

**Why the MLP owns this:** It already has the novelty tracker, the strain signal, and the timing data. It just needs to compute a rhythm score as a 5th output head (or derive it from existing heads). No new data structures — just a new readout of existing state.

---

### 4. SEMANTIC DRIFT DETECTOR

**What:** The MLP's input correlation tracker already learns input→directive quality correlations. Extend it to detect when the system's understanding of a topic is drifting — when the same input pattern starts producing different directive quality over time.

**How:** The `input_quality_ema` Dict already stores per-input-hash EMA of quality. Add a drift detector: when the EMA for a frequently-seen input changes by more than DIRECTION_DRIFT_THRESHOLD in either direction, flag it. Rising EMA = the system is getting better at this input (learning). Falling EMA = the system is getting worse (forgetting, or context changed).

**What drift signals can do:**
- Falling EMA on a previously-stable input → trigger targeted hippocampal strain for that topic, even if global strain is low. The system should notice when it's getting worse, not just when it's overwhelmed.
- Rising EMA → positive reinforcement. No action needed, but log it for `/status` display.
- Oscillating EMA → unstable topic. The system can't make up its mind. Flag for AutoGrowth as "this topic needs more structure" evidence.

**Why the MLP owns this:** It already has the EMA data. It just needs a comparison pass against historical baselines. The novelty tracker already stores hash counts — add quality trend as a second dimension.

---

### 5. AMBIGUITY RESOLVER (already partially built)

**What:** The MLP's 4th output head already computes `disambiguation` signal. Currently it's just a scalar that nobody reads. Activate it.

**How:** When two or more nodes score similarly in the scan (confidence within 0.1 of each other), the MLP's disambiguation head should break the tie. The head already receives features about the vote distribution — it can learn that "when I see these two nodes tied, the user probably means X based on the input correlation history."

**Integration:** In `select_aiml_votes` (or wherever ties are resolved), read `last_disambiguation` from the MLP state. If it's above 0.5, it favors the first-place node. Below 0.5, it favors the second-place node. This gives the MLP a real vote in the scan outcome, not just a quality commentary.

**Why the MLP owns this:** It already computes the signal. It already has the input correlation history to learn which node tends to be right in tied situations. Just wire the existing output into the existing pipeline.

---

### 6. FORGETTING SIGNAL

**What:** The MLP's novelty tracker already records how many times each vote-list hash has been seen. Use the inverse — patterns that WERE frequent but HAVEN'T appeared recently — as a forgetting signal.

**How:** Track `last_seen` per hash in the novelty tracker (already has `hash_counts`). When a hash that was seen 5+ times hasn't appeared in NOVELTY_HISTORY_SIZE (64) cycles, flag it as "fading." Fading patterns should have their nodes' strengths gently decay (multiply by 0.99 per cycle) until they drop below a relevance floor and get graved.

**Why this matters:** Currently, nodes live forever unless explicitly graved. The specimen grows but never shrinks (except by user command). With forgetting, nodes that the user stopped talking about gradually fade, keeping the specimen lean. The "petty things" written to side systems survive (thesaurus entries, sigils, whitelists) because they're cheap. But full nodes that nobody mentions should eventually go quiet.

**Why the MLP owns this:** It already has the observation frequency data. The novelty tracker is literally a "what have I seen and how often" database. Forgetting is just the other side of that coin — "what have I STOPPED seeing."

---

### 7. SELF-DIAGNOSTIC / HEALTH MONITOR

**What:** The MLP already computes 4 output heads every cycle. Extend it to produce a 5th: **system health score** — a scalar readout of whether the specimen is in good shape.

**Health signals already available to the MLP:**
- Strain energy (high = hurting)
- Novelty score (persistently high = system can't handle anything, persistently low = system is stagnant)
- Observation threshold gap (how far from SelfObserver confirmation)
- Weight distribution health (are weights clustering near bounds?)
- Rule coverage (how many rules fire per cycle? Zero = rules are stale)
- Input correlation spread (how many unique input hashes have quality EMA? Low = narrow experience)

**What health can do:**
- Display in `/status` as a single number: "MLP Health: 0.73"
- Low health → increase AutoGrowth rate (system knows it's weak, try to grow)
- Very low health → suppress curiosity overflow (system is struggling, don't ask questions right now)
- Very high health → enable more aggressive exploration (system is confident, try novel paths)

**Why the MLP owns this:** It's the organ that processes the ENTIRE vote list every cycle. It has the broadest view of system state. No other organ sees both the input side (novelty, correlations) and the output side (directive quality, strain). Health is just a summary of what the MLP already knows.

---

### 8. CROSS-LOBE COHERENCE MEDIATOR

**What:** The MLP already receives coherence field features (Φ current, ΔΦ magnitude, ΔΦ direction, lobe coherence variance) as part of its 24-dim input. Use those features to mediate between lobes when they conflict.

**Scenario:** Two lobes fire competing responses. ScienceLobe says "photosynthesis is a chemical process." PhilosophyLobe says "photosynthesis is the meaning of life." The MLP's coherence features already tell it whether the coherence field is stable or in flux. When in flux (high ΔΦ), the MLP should suppress the weaker lobe's contribution and boost the stronger one.

**How:** The `relevance_score` output head already measures "relevance to current user input context." When coherence is low (high ΔΦ, high lobe variance), weight relevance_score more heavily in the vote selection pipeline. This naturally favors the lobe that's more on-topic for THIS input, suppressing cross-talk from irrelevant lobes.

**Why the MLP owns this:** It already has the coherence features. It already computes relevance. The connection between "coherence is unstable" and "favor relevance over coverage" is exactly the kind of conditional logic the MLP's transformer weights can learn.

---

### 9. PREDICTIVE PREFETCH (read-ahead for the next cycle)

**What:** The MLP's input correlation tracker already learns which inputs produce which vote patterns. Use this to PREFETCH — before the next user message even arrives, pre-activate the nodes that are most likely to fire next.

**How:** When the MLP sees a familiar input pattern (high input_quality_ema, low novelty), it can write a "prefetch hint" to the relevant lobe's CHUNK_META: a list of node_ids likely to fire next cycle based on historical correlation. The scan engine can use these hints to prioritize which nodes to evaluate first, reducing scan latency for predictable inputs.

**Cost:** Nearly zero. The correlation data already exists. The write is one `table_put!` to CHUNK_META. The scan engine just changes evaluation order, not content.

**Why the MLP owns this:** It's the organ that knows what's COMING based on what's ALREADY HAPPENED. That's literally what the input correlation tracker does — learn input→outcome mappings. Prefetch is just reading those mappings proactively instead of reactively.

---

### 10. EMOTIONAL TINTING (affective coloring of responses)

**What:** The MLP already computes `directive_quality` and `semantic_score`. Add an affective dimension: is the current conversation context positive, negative, or neutral? This isn't a full emotion engine (the EmotionLobe handles that) — it's a TINT that the MLP applies to its own outputs based on conversational trajectory.

**How:** Track the trajectory of `directive_quality` over the last N cycles. Rising = positive (system is getting more confident). Falling = negative (system is losing confidence). Flat = neutral. This trajectory tints the MLP's recommendations:
- Positive trajectory → bias toward exploration (fuzzy paths, more additive entries, more curiosity)
- Negative trajectory → bias toward conservatism (solid paths, fewer additives, less curiosity)
- Neutral → default behavior

**Why the MLP owns this:** The MLP's job is to be a consultant. A good consultant doesn't just evaluate the current situation — they read the room. The trajectory of its own quality scores over time IS the room. Rising quality means the system is "getting it" — encourage more exploration. Falling quality means the system is "losing it" — retreat to known patterns.

---

## Architecture Summary

The EphemeralMLP is NOT just "transient memory." It's the **brain's consultant organ** — the part that wakes up, looks at everything, and makes recommendations. Its persistent state + ephemeral processing architecture makes it uniquely suited for:

1. **Things that need BOTH real-time signal AND accumulated memory** (curiosity: real-time strain + accumulated intensity)
2. **Things that need a BROAD VIEW of system state** (health: it sees the whole vote list, not just one node's perspective)
3. **Things that need TEMPORAL REASONING** (rhythm detection, drift detection, forgetting: it tracks time-series of its own operations)
4. **Things that need to BREAK TIES or MEDIATE** (ambiguity resolution, cross-lobe coherence: it sees competing signals and can arbitrate)
5. **Things that need PREDICTIVE POWER** (prefetch: it learns input→outcome correlations and can project forward)

None of these require new node types, new modules, or new data structures. They require:
- New output heads (already supported by the multi-head architecture)
- New entries in LobeTable CHUNK_META (already supported by the hash table API)
- New readouts of EXISTING state (novelty tracker, correlation tracker, strain, timing)
- Wiring existing MLP outputs into existing pipeline decision points

The MLP is the organ that ALREADY sees the whole picture. Making it multi-purpose just means reading more of what it already knows.

---

## Petty Things → Side Systems (Fast-Path Reference)

The key insight: **not every unknown requires a node.** Nodes are expensive (they fire, they vote, they consume scan time, they need groups and lobes). Side systems are cheap (thesaurus lookups, sigil expansions, lobe whitelists — O(1) reads, no cycle cost).

**Fast-path flow:**
```
User input → scan → MLP forward pass
                              ↓
                    MLP tags answer as "petty"?
                    (high quality, low novelty, simple structure)
                         ↓ YES                    ↓ NO
                  Side-system write          Normal AutoGrowth
                  (instant, no coinflip)     (evidence → coinflip → maybe grow)
                         ↓
                  Thesaurus / Sigil /
                  Whitelist / Co-occurrence
```

**Classification rules for "petty":**
- New word + definition → thesaurus (instant)
- Spelling variant of known word → thesaurus (instant)
- Simple math fact (ArithmeticEngine computed) → sigil expansion (instant)
- Domain token for under-populated lobe → whitelist (instant)
- Short co-occurrence pattern → co-occurrence map (instant, already happens but skips evidence floor)
- Negation of known pattern → soft antimatch hint in CHUNK_META (instant, not a full node)

**What stays in the slow path (evidence → coinflip → maybe grow):**
- Entirely new concepts (no existing pattern nearby)
- Multi-word patterns that need full node structure (AIML templates, json_data)
- Time-orientation patterns (need time_node structure)
- Complex relationships (need RelationalTriple wiring)

The fast/slow split keeps the specimen lean. Petty learnings don't inflate the node count. They quietly make the existing side systems smarter without touching the scan pipeline.
