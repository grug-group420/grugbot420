# GrugBot420 — Enhanced AutoGrowth + EphemeralMLP + Petty Learning Architecture

## Design Document — Phase 2 Output

---


<!-- ⚠️ ARCHITECTURE REMINDERS ⚠️ -->
<!-- 1. ANTIMATCH NODES WERE REMOVED — do not reference, implement, or assume they exist -->
<!-- 2. SIGILS CAN APPEAR IN RELATIONAL TRIPLES — triples are dynamic, not just literal strings -->
<!-- 3. HOPFIELD CACHING WAS REMOVED — hopfield_key is a dead field for specimen compat only -->
## 1. EphemeralMLP → AutoGrowth Signal Pipeline

### Current State
- AutoGrowth `accumulate_evidence!` receives `strain_energy` (Float64) as Source 5 — but uses it only as one evidence increment when `hippocampal_warrant_active && strain_energy > 0.55`.
- `hippococampal_warrant_active` is passed as `false` hardcoded in Main.jl line ~5748.
- The 3 unused MLP output heads (semantic_score, relevance_score, disambiguation) are computed, logged, and written to SelfObserver — but never influence any decision system.

### New Evidence Sources

**SOURCE 9: SEMANTIC COHERENCE GAP** (`semantic_score`)
- When EphemeralMLP reports low `semantic_score` (< 0.35), the system recognizes it doesn't semantically understand the input.
- Low semantic_score on non-trivial input → evidence that uncovered tokens need node coverage.
- Implementation: After MLP transform, extract `semantic_score` from `mlp_result`. Pass to `accumulate_evidence!` as new kwarg `mlp_semantic_score::Float64 = 0.5`.
- Inside `accumulate_evidence!`: if `mlp_semantic_score < 0.35 && intensity > 0.5`, each uncovered token gets `intensity * (1.0 - mlp_semantic_score) * 0.4` evidence tagged as `"semantic_gap"`.
- Rationale: Low semantic_score means the brain's pattern-matching couldn't find semantically coherent matches. This is a stronger signal than mere silence — it's the brain saying "I found something but it doesn't make sense."

**SOURCE 10: RELEVANCE DROPOUT** (`relevance_score`)
- When EphemeralMLP reports low `relevance_score` (< 0.30), the system's responses aren't relevant to the user's input context.
- Low relevance_score → evidence for :thesaurus growth type (synonym expansion bridges relevance gaps).
- Implementation: Pass `mlp_relevance_score::Float64 = 0.5` to `accumulate_evidence!`.
- Inside: if `mlp_relevance_score < 0.30`, existing thesaurus gap evidence gets a `1.0 - mlp_relevance_score` multiplier boost. Also generates `intensity * (1.0 - mlp_relevance_score) * 0.3` evidence for uncovered tokens tagged as `"relevance_dropout"`.
- Rationale: If responses are irrelevant, the thesaurus is likely incomplete — missing synonym connections that would let patterns fire.

**SOURCE 11: DISAMBIGUATION PRESSURE** (`disambiguation`)
- When EphemeralMLP reports high `disambiguation` (> 0.65), the system sees ambiguous input that it can't resolve.
- High disambiguation → evidence for :sigil growth (new sigil expansion would help resolve ambiguity) and for specific patterns that disambiguate.
- Implementation: Pass `mlp_disambiguation::Float64 = 0.5` to `accumulate_evidence!`.
- Inside: if `mlp_disambiguation > 0.65`, for each token that has sigil overlap, add `intensity * mlp_disambiguation * 0.3` evidence tagged as `"disambiguation_pressure"` with growth_type `:sigil`. Also add evidence for the full pattern as `:match` with `disambiguation * 0.25` intensity.
- Rationale: The brain detected ambiguity. New sigil entries (noun lexicon entries, relation sigils) provide more resolution paths. New nodes for the ambiguous pattern give future scans more specificity.

**SOURCE 12: COHERENCE FIELD DELTA** (ΔΦ from CoherenceField)
- When ΔΦ is large and negative (coherence dropping), the system is losing integration — evidence for growth to restore coherence.
- Implementation: Pass `coherence_delta_phi::Float64 = 0.0` to `accumulate_evidence!`.
- Inside: if `coherence_delta_phi < -0.15`, uncovered tokens get `abs(coherence_delta_phi) * 0.5 * intensity` evidence tagged as `"coherence_drop"`. This is a WEAK evidence source — it supplements but doesn't dominate.
- Rationale: Coherence drop means the system's existing structure can't integrate the new input. Growth fills the gaps.

**SOURCE 13: SELF-OBSERVER PATTERN** (from SelfObserver peek)
- SelfObserver records MLP cycle observations. If a pattern recurs in observations (same user_input_hash with low quality), that's cumulative evidence of a persistent gap.
- Implementation: Before calling `accumulate_evidence!`, peek SelfObserver for recent low-quality cycles. Pass `observer_recurring_gap::Bool = false` and `observer_gap_pattern::String = ""`.
- Inside: if `observer_recurring_gap`, add `intensity * 0.5` evidence for `observer_gap_pattern` tagged as `"observer_pattern"`.
- Rationale: The subconscious noticed the same gap repeatedly. This is an independent signal from the conscious scan — it validates other evidence sources.

### Main.jl Wiring Changes

At the `accumulate_evidence!` call site (~line 5745):
```julia
# Extract MLP head scores from the mlp_result computed earlier
_ag_semantic = try Float64(get(mlp_result, "semantic_score", 0.5)) catch _ 0.5 end
_ag_relevance = try Float64(get(mlp_result, "relevance_score", 0.5)) catch _ 0.5 end
_ag_disambiguation = try Float64(get(mlp_result, "disambiguation", 0.5)) catch _ 0.5 end

# Extract coherence delta
_ag_delta_phi = try CoherenceField.compute_delta("", NODE_MAP) catch _ 0.0 end
# (Use the already-computed _delta_phi from earlier in the pipeline)

# Check SelfObserver for recurring gaps
_ag_obs_gap = false
_ag_obs_pattern = ""
try
    _ag_obs_peek = SelfObserver.peek_pattern(_MLP_OBSERVER_STORE, "low_quality")
    if !isempty(_ag_obs_peek)
        _ag_obs_gap = true
        _ag_obs_pattern = first(_ag_obs_peek).pattern
    end
catch; end

AutoGrowth.accumulate_evidence!(
    user_text                 = mission_text,
    intensity                 = 1.0,
    node_patterns             = _ag_node_patterns,
    node_ids_patterns         = _ag_node_ids_patterns,
    thesaurus_gate_filter     = Thesaurus.synonym_lookup,
    thesaurus_word_similarity = Thesaurus.word_similarity,
    lobe_snapshots            = _ag_lobe_snapshots,
    attachment_snapshots      = _ag_attach_snapshots,
    sigil_table_entries       = _ag_sigil_entries,
    strain_energy             = _ag_strain,
    hippocampal_warrant_active = _ag_strain > 0.55,  # FIX: was hardcoded false!
    mlp_semantic_score        = _ag_semantic,          # NEW
    mlp_relevance_score       = _ag_relevance,          # NEW
    mlp_disambiguation        = _ag_disambiguation,     # NEW
    coherence_delta_phi       = _ag_delta_phi,           # NEW
    observer_recurring_gap    = _ag_obs_gap,             # NEW
    observer_gap_pattern      = _ag_obs_pattern,        # NEW
)
```

### EvidenceRecord.growth_type Expansion
Add new growth types:
- `:flashcard` — for arithmetic/math facts (see §3)

---

## 2. EphemeralMLP → AutoLinker Signal Pipeline

### Current State
- AutoLinker `accumulate_link_evidence!` receives `strain_nodes=String[]` — always empty. The strain_pair evidence source (Source 5) is dead code.
- Zero EphemeralMLP integration. The Linker doesn't know what the brain thinks.

### New Evidence Sources

**SOURCE 9: DISAMBIGUATION BRIDGE** (`disambiguation`)
- High disambiguation (> 0.65) means the brain sees ambiguity between candidate nodes.
- If two co-fired nodes both partially matched the same ambiguous input, they should be linked — the bridge creates a resolution path.
- Implementation: Pass `mlp_disambiguation::Float64 = 0.5` to `accumulate_link_evidence!`.
- Inside: if `mlp_disambiguation > 0.65 && length(co_fired_ids) >= 2`, each co-fired pair gets `mlp_disambiguation * 0.4` extra evidence tagged as `"disambiguation_bridge"`.
- Rationale: Ambiguous input activates multiple candidates. Linking them creates a disambiguation pathway — next time, the bridge carries the resolution signal.

**SOURCE 10: RELEVANCE CROSS-LOBE** (`relevance_score`)
- Low relevance_score (< 0.30) combined with cross-lobe co-firing suggests the lobes aren't communicating well.
- Implementation: Pass `mlp_relevance_score::Float64 = 0.5`.
- Inside: if `mlp_relevance_score < 0.30`, cross-lobe co-fired pairs get `(1.0 - mlp_relevance_score) * 0.5` bonus evidence tagged as `"relevance_cross_lobe"`.
- Rationale: When the brain can't find relevant responses AND cross-lobe nodes co-fired, it means the cross-lobe connection is weak. Strengthening the bridge improves relevance.

**SOURCE 11: STRAIN NODES** (fix the empty string[])
- Currently `strain_nodes=String[]` is hardcoded. Fix: extract actual strain nodes from the MLP result.
- When strain_energy > threshold, the nodes that contributed to the strain (low-confidence activated nodes) should be passed as strain_nodes.
- Implementation: After MLP transform, identify nodes with confidence below JITTER_CONFIDENCE_FLOOR (0.50) that still fired. These are the strain nodes.
- Pass `strain_nodes = _strain_node_ids` (non-empty when strain is active).
- This resurrects the dead Source 5 (strain_pair) in AutoLinker.

**SOURCE 12: CHATTER RESIDUAL CO-OCCURRENCE**
- ChatterResiduals mines co-occurrence from swap history. These pairs represent "the system chose these nodes together" — a strong signal for linking.
- Implementation: Call `ChatterResiduals.get_co_occur_snapshot()` before `accumulate_link_evidence!`. Pass as `chatter_co_occur_pairs::Vector{Tuple{String,String,Float64}}`.
- Inside: each pair gets `CHATTER_CO_OCCUR_INCREMENT * pair_intensity * 0.5` evidence tagged as `"chatter_residual"`.
- Rationale: ChatterResiduals sees patterns the active path doesn't — background mining catches slow relationship drift.

### Main.jl Wiring Changes

At the `accumulate_link_evidence!` call site (~line 5845):
```julia
# Extract MLP signals for AutoLinker
_al_disambig = try Float64(get(mlp_result, "disambiguation", 0.5)) catch _ 0.5 end
_al_relevance = try Float64(get(mlp_result, "relevance_score", 0.5)) catch _ 0.5 end

# FIX: Compute strain nodes instead of passing empty String[]
_al_strain_nodes = String[]
if _ag_strain > 0.55
    _al_strain_nodes = filter(v -> v.confidence < 0.50, contributing_votes) |> vs -> map(v -> v.node_id, vs) |> ids -> unique(ids)
end

# Get ChatterResiduals co-occurrence pairs
_al_chatter_pairs = Tuple{String,String,Float64}[]
try
    _al_chatter_raw = ChatterResiduals.get_co_occur_snapshot()
    for entry in _al_chatter_raw
        a = get(entry, "a", ""); b = get(entry, "b", ""); c = Float64(get(entry, "intensity", 0.0))
        if !isempty(a) && !isempty(b) && c > 0.0
            push!(_al_chatter_pairs, (a, b, c))
        end
    end
catch; end

AutoLinker.accumulate_link_evidence!(
    co_fired_ids              = fired_ids,
    input_touched_ids         = String[],
    node_ids_patterns         = _ag_node_ids_patterns,
    bridge_map_snapshot       = _al_bridge_snap,
    thesaurus_gate_filter     = Thesaurus.synonym_lookup,
    thesaurus_word_similarity = Thesaurus.word_similarity,
    lobe_of_fn                = _al_lobe_of,
    strain_nodes              = _al_strain_nodes,              # FIXED: was String[]
    co_occur_map              = _al_co_occur,
    co_activation_pairs       = Tuple{String,String,Float64}[],
    mlp_disambiguation        = _al_disambig,                  # NEW
    mlp_relevance_score       = _al_relevance,                  # NEW
    chatter_co_occur_pairs    = _al_chatter_pairs,              # NEW
)
```

---

## 3. Flashcard Subsystem

### Purpose
Simple arithmetic facts and lookup tables don't need new nodes. Writing "3+5=8" as a flashcard in LobeTable is cheaper than growing a node, and the ArithmeticEngine can read it back instantly.

### CHUNK_FLASHCARD

Add to `LobeTable.jl`:
```julia
const CHUNK_FLASHCARD = "flashcard"
```

Add to `VALID_CHUNKS`:
```julia
const VALID_CHUNKS = Set{String}([CHUNK_NODES, CHUNK_JSON, CHUNK_DROP, CHUNK_HOPFIELD, CHUNK_META, CHUNK_FLASHCARD])
```

Since `create_lobe_table!` iterates `VALID_CHUNKS`, flashcard chunks will be auto-created for every lobe.

### Flashcard Data Format

Key: `"<expression_hash>"` (e.g., hash of "3+5" or "capital:france")
Value: `Dict{String, Any}` with fields:
```julia
Dict(
    "expression"  => "3+5",          # Original expression
    "result"      => "8",            # Computed result
    "result_num"  => 8.0,            # Numeric result (if applicable)
    "type"        => :arithmetic,    # :arithmetic, :lookup, :fact
    "lobe_id"     => "math",         # Which lobe owns this card
    "created_at"  => 1720000000.0,   # Timestamp
    "hits"        => 0,              # Read count (for hot-card tracking)
    "ttl"         => 0,              # 0 = no expiry, >0 = seconds until expiry
)
```

### Flashcard API Functions (in LobeTable.jl)

```julia
# Write a flashcard
function flashcard_put!(lobe_id::String, expression::String, result::String;
                        result_num::Float64=NaN, card_type::Symbol=:arithmetic, ttl::Float64=0.0)

# Read a flashcard (returns Dict or nothing)
function flashcard_get(lobe_id::String, expression::String)::Union{Dict{String,Any}, Nothing}

# Check if a flashcard exists
function flashcard_has(lobe_id::String, expression::String)::Bool

# Delete a flashcard
function flashcard_delete!(lobe_id::String, expression::String)::Bool

# Query flashcards by prefix (e.g., all arithmetic cards)
function flashcard_query(lobe_id::String; card_type::Symbol=nothing, min_hits::Int=0)::Vector{Dict{String,Any}}

# Increment hit counter
function flashcard_hit!(lobe_id::String, expression::String)::Bool

# Evict expired flashcards (ttl > 0 and past expiry)
function flashcard_evict!(lobe_id::String)::Int
```

### ArithmeticEngine → Flashcard Integration

In `Main.jl`, after `ArithmeticEngine.compute_arithmetic` succeeds:
1. Check if flashcard already exists via `flashcard_has`
2. If not, write via `flashcard_put!` with `card_type=:arithmetic`
3. On subsequent inputs with the same expression, `flashcard_get` returns the cached result — no re-computation needed.

### Flashcard as Evidence Source for AutoGrowth

**SOURCE 14: FLASHCARD GAP**
- When ArithmeticEngine detects math bindings but no flashcard exists for the expression, that's evidence for `:flashcard` growth type.
- Implementation: In `accumulate_evidence!`, after tokenization, check if any token pair looks like an arithmetic expression. If so and no flashcard exists, add `"fc:<expression>"` evidence with `intensity * 0.3` tagged as `"flashcard_gap"` and growth_type `:flashcard`.
- Growth action for `:flashcard` type: compute the arithmetic result and write it to the flashcard chunk. No node creation needed.

---

## 4. Petty Learning Fast-Paths

### Purpose
Not everything needs a node. Simple learning should be INSTANT — no coinflip, no evidence accumulation, no growth delay. The classifier detects petty cases and dispatches to the appropriate fast-path.

### PettyLearner Module (new file: `PettyLearner.jl`)

```julia
module PettyLearner

export classify_petty, dispatch_petty!, PettyResult

struct PettyResult
    dispatched::Bool          # Was a petty fast-path taken?
    path::Symbol              # :thesaurus, :flashcard, :lobe_whitelist, :none
    detail::String            # Human-readable description of what happened
end

"""
    classify_petty(user_text, tokens, node_patterns, thesaurus_fn, sigil_entries) -> PettyResult

Determine if the input represents a "petty" learning opportunity —
something so simple it doesn't need node growth. Three categories:

1. NEW WORD → THESAURUS: A single uncovered token that is a known synonym
   of a covered token. Just add the synonym pair — instant learning.

2. SIMPLE MATH → FLASHCARD: An arithmetic expression with bindings.
   Compute the result, write to flashcard — instant lookup table.

3. DOMAIN TOKEN → LOBE WHITELIST: A single uncovered token that overlaps
   with an under-populated lobe's subject. Add to whitelist — instant gating.

Returns PettyResult with dispatched=true if a fast-path was taken.
"""
function classify_petty(
    user_text::String,
    tokens::Vector{String},
    node_patterns::Set{String},
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    lobe_snapshots::Vector{Tuple{String,String,Set{String}}},
    sigil_entries::Dict,
    arithmetic_bindings::Dict,
)::PettyResult
    # ... implementation ...
end

"""
    dispatch_petty!(result::PettyResult; kwargs...) -> PettyResult

Execute the fast-path action based on classification result.
"""
function dispatch_petty!(result::PettyResult;
    thesaurus_register_fn::Function,
    flashcard_put_fn::Function,
    lobe_whitelist_fn::Function,
    arithmetic_compute_fn::Function,
)::PettyResult
    # ... implementation ...
end
```

### Classification Logic

**Path 1: New Word → Thesaurus**
- Condition: Exactly ONE uncovered non-stopword token in input. That token has `word_similarity > SYNONYM_SEED_THRESHOLD (0.70)` to a covered token.
- Action: Call `add_seed_synonym!(new_word, [covered_word])`. Instant bidirectional synonym registration.
- Skip condition: If 2+ uncovered tokens, this isn't petty — it's a real gap.

**Path 2: Simple Math → Flashcard**
- Condition: `ArithmeticEngine.has_math_bindings(bindings)` returns true. Expression is computable.
- Action: Compute result, write to `CHUNK_FLASHCARD`. No node growth.
- Skip condition: If the expression is too complex (3+ operators, nested), let normal flow handle it.

**Path 3: Domain Token → Lobe Whitelist**
- Condition: Exactly ONE uncovered token that belongs to an under-populated lobe's subject area (checked via `lobe_snapshots` overlap). The lobe has < 5 nodes.
- Action: Call `add_lobe_whitelist!(lobe_id, token)`. Instant scan gating.
- Skip condition: If the token could belong to multiple lobes, skip — ambiguity needs evidence.

### Integration in Main.jl

In `process_mission`, AFTER AutoGrowth `accumulate_evidence!` but BEFORE `maybe_grow_from_evidence!`:
```julia
# GRUG v10: Petty Learning — instant fast-paths for simple stuff.
# If the classifier dispatches, we SKIP maybe_grow_from_evidence! this turn
# because the gap was already filled by a fast-path. No coinflip needed.
_petty_result = PettyLearner.classify_petty(
    mission_text, _ag_tokens, _ag_node_patterns,
    Thesaurus.synonym_lookup, Thesaurus.word_similarity,
    _ag_lobe_snapshots, _ag_sigil_entries, _arithmetic_bindings
)
if _petty_result.path != :none
    _petty_result = PettyLearner.dispatch_petty!(_petty_result;
        thesaurus_register_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
        flashcard_put_fn = (lobe, expr, res; kwargs...) -> LobeTable.flashcard_put!(lobe, expr, res; kwargs...),
        lobe_whitelist_fn = (lobe_id, token) -> Lobe.add_lobe_whitelist!(lobe_id, token),
        arithmetic_compute_fn = ArithmeticEngine.compute_arithmetic,
    )
    println("[PETTY] ⚡ Fast-path: $(_petty_result.path) — $(_petty_result.detail)")
end
```

---

## 5. Curiosity Accumulator

### Purpose
Passively accumulate unknown context. When curiosity overflows, the system asks a question autonomously via `_HIPPOCAMPAL_PENDING_ASK`.

### Design

Store in `CHUNK_META` under key `"curiosity_accumulator"`:
```julia
Dict(
    "buffer"     => String[],           # Queued unknown tokens/patterns
    "intensity"  => 0.0,                # Accumulated curiosity intensity (0.0-1.0)
    "quenched_at" => 0.0,               # Timestamp of last quench
    "overflow_count" => 0,              # How many times overflow has fired
)
```

### Curiosity Accumulation Rules
1. Each uncovered token from `accumulate_evidence!` Source 1 (silence_map) also feeds curiosity: `intensity += 0.05` per uncovered token.
2. High novelty_score (> 0.70) from MLP: `intensity += novelty * 0.1`.
3. Low semantic_score (< 0.35) from MLP: `intensity += (1.0 - semantic) * 0.08`.
4. Evidence records that pass frequency floor but NOT intensity floor: their patterns enter the buffer.

### Overflow Mechanism
- `CURIOSITY_OVERFLOW_THRESHOLD = 0.85`
- When `intensity >= CURIOSITY_OVERFLOW_THRESHOLD` and buffer is non-empty:
  1. Pick the highest-frequency pattern from the buffer.
  2. Generate a question: `"I'm curious about [pattern]. Can you tell me more?"`
  3. Store in `_HIPPOCAMPAL_PENDING_ASK` via the existing mechanism.
  4. Quench: `intensity = 0.0`, `buffer = String[]`, `quenched_at = time()`.

### Quench Behavior
- After quenching, there's a cooldown: `CURIOSITY_COOLDOWN = 300.0` seconds (5 minutes).
- During cooldown, accumulation continues but overflow cannot fire.
- This prevents question-spam.

### Integration
- In `AutoGrowth.accumulate_evidence!`, after all evidence sources: call `_accumulate_curiosity!(tokens, node_patterns, mlp_semantic_score, mlp_novelty_score)`.
- In `Main.jl`, after AutoGrowth call: check `AutoGrowth.check_curiosity_overflow()`. If overflow, write to `_HIPPOCAMPAL_PENDING_ASK`.
- Save/load: serialize `curiosity_accumulator` Dict in the AutoGrowth save section.

---

## 6. Input Decomposition Enhancement

### Current Gaps
- Missing conjunctions: "while", "whilst", "since" (temporal), "unless", "except", "apart from" (exclusion), "plus", "along with" (additive), "on the other hand" (contrastive)
- No sigil-boundary splitting: arithmetic expressions like "what is 2+3 and what is a dog" should split at the math boundary
- No EphemeralMLP-assisted decomposition: the MLP's `is_compound` flag exists but isn't used by the decomposer
- Missing question markers: "can", "could", "would", "shall", "will", "do", "does", "did", "is", "are", "was", "were", "am"
- Missing command markers: "compare", "contrast", "analyze", "evaluate", "summarize", "determine", "identify", "convert", "translate"

### New Conjunctions
```julia
# Add to _DEFAULT_SPLIT_CONJUNCTIONS:
"while", "whilst", "since",     # temporal conjunctions
"unless", "except",             # exclusive conjunctions
"plus",                         # additive ("what is X plus what is Y")
"independently",                # "do X and independently do Y"
"separately",                   # "tell me X and separately tell me Y"
```

### New Compound Pairs
```julia
# Add to _DEFAULT_COMPOUND_PAIRS:
"plus"    => Set(["and", "also"]),
"while"   => Set(["and", "also", "but"]),
"since"   => Set(["and", "also"]),
```

### New Question Markers
```julia
# Add to _DEFAULT_QUESTION_MARKERS:
"can", "could", "would", "shall", "will",
"do", "does", "did",
"is", "are", "was", "were", "am"
```

### New Command Markers + Conjugations
```julia
# Add to _DEFAULT_COMMAND_MARKERS:
"compare", "contrast", "analyze", "evaluate",
"summarize", "determine", "identify",
"convert", "translate", "search", "lookup"

# Add to _DEFAULT_CONJUGATION_RULES:
"compare"    => ["compares", "compared", "comparing"],
"contrast"   => ["contrasts", "contrasted", "contrasting"],
"analyze"    => ["analyzes", "analyzed", "analyzing"],
"evaluate"   => ["evaluates", "evaluated", "evaluating"],
"summarize"  => ["summarizes", "summarized", "summarizing"],
"determine"  => ["determines", "determined", "determining"],
"identify"   => ["identifies", "identified", "identifying"],
"convert"    => ["converts", "converted", "converting"],
"translate"  => ["translates", "translated", "translating"],
"search"     => ["searches", "searched", "searching"],
"lookup"     => ["lookups", "looked up", "looking up"],
```

### Strategy 4: Sigil-Boundary Splitting
New splitting strategy that detects arithmetic/math sigil boundaries.

```julia
function _split_on_sigil_boundaries(input_text::String, config::DecomposerConfig)::Vector{String}
    # GRUG: When input contains arithmetic expressions mixed with
    # non-arithmetic content, split at the math boundary.
    # "what is 2+3 and what is a dog" → ["what is 2+3", "what is a dog"]
    # Already handled by conjunction "and" in most cases, but:
    # "compute 5*3 tell me about dogs" → needs sigil boundary split
    #
    # Detection: look for &n/&op sigil regions in the tokenized input.
    # If tokens transition from math-bound tokens to non-math tokens
    # (or vice versa), that's a split point.
end
```

### Strategy 5: EphemeralMLP-Assisted Decomposition
The MLP's `is_compound` flag is already computed in Main.jl. Pass it to the decomposer.

```julia
function decompose_input(input_text::String, config::DecomposerConfig;
                         mlp_is_compound::Bool=false)::Vector{DecomposedSubSubject}
    # If MLP says compound but heuristics found no split,
    # apply AGGRESSIVE splitting: try comma clauses with lower threshold,
    # try clause-structure at every conjunction (not just split_conjunctions).
    if mlp_is_compound && length(clauses) <= 1
        clauses = _aggressive_split(input_text, config)
    end
end
```

### Comma-Clause Enhancement
Current `_split_on_comma_clauses` requires question markers on both sides of the comma. Enhance to also accept command markers and partial clause structure.

---

## 7. Enhanced Evidence Source Wiring Summary

| Source # | Name | Signal | Target System | New? |
|----------|------|--------|--------------|------|
| 1 | silence_map | uncovered tokens | AutoGrowth | Existing |
| 2 | thesaurus_gap | uncovered synonyms | AutoGrowth | Existing |
| 3 | lobe_coverage | under-populated lobes | AutoGrowth | Existing |
| 4 | attachment | crystalized connectors | AutoGrowth | Existing |
| 5 | strain | MLP strain_energy | AutoGrowth | Existing (fix warrant) |
| 6 | time_gap | temporal keywords | AutoGrowth | Existing |
| 7 | sigil_gap | sigils with no expansion | AutoGrowth | Existing |
| 8 | co_occurrence | token co-occurrence | AutoGrowth | Existing |
| **9** | **semantic_gap** | **MLP semantic_score < 0.35** | **AutoGrowth** | **NEW** |
| **10** | **relevance_dropout** | **MLP relevance_score < 0.30** | **AutoGrowth** | **NEW** |
| **11** | **disambiguation_pressure** | **MLP disambiguation > 0.65** | **AutoGrowth** | **NEW** |
| **12** | **coherence_drop** | **ΔΦ < -0.15** | **AutoGrowth** | **NEW** |
| **13** | **observer_pattern** | **SelfObserver recurring gap** | **AutoGrowth** | **NEW** |
| **14** | **flashcard_gap** | **arithmetic expr, no card** | **AutoGrowth** | **NEW** |
| L1 | co_firing | same-cycle activation | AutoLinker | Existing |
| L2 | input_co_occurrence | same-input activation | AutoLinker | Existing |
| L3 | synonym_bridge | thesaurus synonyms | AutoLinker | Existing |
| L4 | opposing_lobe_co_act | cross-lobe co-fire | AutoLinker | Existing |
| L5 | strain_pair | co-stressed nodes | AutoLinker | Existing (FIX: populate) |
| L6 | attach_neighbor | bridge neighbor | AutoLinker | Existing |
| L7 | word_co_occur | word co-occurrence | AutoLinker | Existing |
| L8 | co_activation_pair | explicit CO_ACC | AutoLinker | Existing |
| **L9** | **disambiguation_bridge** | **MLP disambiguation > 0.65** | **AutoLinker** | **NEW** |
| **L10** | **relevance_cross_lobe** | **MLP relevance < 0.30** | **AutoLinker** | **NEW** |
| **L11** | **chatter_residual** | **ChatterResiduals pairs** | **AutoLinker** | **NEW** |

---

## 8. Save/Load Additions

### New allowed_keys (for specimen validation)
- `"curiosity_accumulator"` — in AutoGrowth section
- `"flashcard_data"` — per-lobe flashcard chunk data

### AutoGrowth Save Section Additions
```julia
# After existing autogrowth_evidence save:
if haskey(AutoGrowth._CURIOSITY, "buffer")
    spec["curiosity_accumulator"] = AutoGrowth.serialize_curiosity()
end
```

### AutoGrowth Load Section Additions
```julia
# After existing autogrowth evidence load:
if haskey(spec, "curiosity_accumulator")
    AutoGrowth.deserialize_curiosity!(spec["curiosity_accumulator"])
end
```

### Flashcard Save/Load
```julia
# In save_specimen:
fc_data = LobeTable.serialize_flashcards()
if !isempty(fc_data)
    spec["flashcard_data"] = fc_data
end

# In load_specimen:
if haskey(spec, "flashcard_data")
    LobeTable.deserialize_flashcards!(spec["flashcard_data"])
end
```

---

## 9. CLI Commands

### New Flashcard Commands
- `/flashcard list [lobe_id]` — show all flashcards (or for one lobe)
- `/flashcard add <expression> <result>` — manually add a flashcard
- `/flashcard delete <expression>` — remove a flashcard
- `/flashcard stats` — show flashcard hit counts and coverage

### New Curiosity Commands
- `/curiosity status` — show accumulator intensity and buffer
- `/curiosity quench` — manually quench the accumulator
- `/curiosity clear` — clear the buffer

### Enhanced Decomposer Commands
- `/decomposer addQuestionMarker <marker>` — add a question marker at runtime
- `/decomposer removeQuestionMarker <marker>` — remove a question marker
- `/decomposer addSplitConjunction <conj>` — already exists
- `/decomposer aggressiveMode <on|off>` — enable aggressive MLP-assisted decomposition

### Enhanced Autogrowth Commands
- `/autogrowth sources` — show all 14 evidence sources with their current contribution stats
- `/autogrowth mlpHeads` — show current MLP head values and their evidence contributions

---

## 10. Implementation Order

The implementation should follow this dependency order:

1. **LobeTable** — Add `CHUNK_FLASHCARD` + flashcard API (foundation for everything else)
2. **PettyLearner.jl** — New module with classifier + dispatcher
3. **AutoGrowth** — Add 5 new evidence sources (9-13) + flashcard_gap (14) + curiosity accumulator + 1 new growth type (:flashcard) + fix hippocampal_warrant_active
4. **AutoLinker** — Add 3 new evidence sources (L9-L11) + fix strain_nodes
5. **InputDecomposer** — Add conjunctions, markers, sigil-boundary splitting, MLP-assisted mode
6. **Main.jl** — Wire all new kwargs, add PettyLearner dispatch, add curiosity overflow check, save/load for new state
7. **CLI commands** — Add /flashcard, /curiosity, enhanced /decomposer, /autogrowth sources

---

## 11. Constants Reference

New constants to add:

```julia
# In AutoGrowth.jl:
const SEMANTIC_GAP_THRESHOLD    = 0.35   # below this = semantic gap
const RELEVANCE_DROPOUT_THRESHOLD = 0.30 # below this = relevance dropout
const DISAMBIGUATION_PRESSURE_THRESHOLD = 0.65 # above this = disambiguation pressure
const COHERENCE_DROP_THRESHOLD  = -0.15 # below this = coherence drop
const FLASHCARD_EVIDENCE_INCREMENT = 0.3 # evidence per flashcard gap
const CURIOSITY_OVERFLOW_THRESHOLD = 0.85 # above this = overflow → question
const CURIOSITY_COOLDOWN         = 300.0 # seconds after quench before next overflow
const CURIOSITY_PER_TOKEN        = 0.05  # intensity per uncovered token
const CURIOSITY_NOVELTY_WEIGHT   = 0.10  # novelty contribution
const CURIOSITY_SEMANTIC_WEIGHT  = 0.08  # low-semantic contribution
const PETTY_MAX_UNCOVERED_TOKENS = 1     # only 1 uncovered → petty thesaurus path
const PETTY_SIMILARITY_FLOOR     = 0.70  # SYNONYM_SEED_THRESHOLD for petty path

# In AutoLinker.jl:
const DISAMBIGUATION_BRIDGE_THRESHOLD = 0.65
const RELEVANCE_CROSS_LOBE_THRESHOLD = 0.30
const CHATTER_RESIDUAL_INCREMENT     = 1.0
```
