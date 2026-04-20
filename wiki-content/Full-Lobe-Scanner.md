# Full Lobe Scanner

The **FullLobeScanner** is a phase-gated associative memory scanner that sweeps an entire lobe's feature-vector space to find pattern matches and semantically related nodes. It operates independently of the flat `NODE_MAP` scan used by `scan_specimens` — instead, it works on a `Dict{String, Vector{Float64}}` feature dictionary and produces typed match results with spreading-activation semantics.

All activations are hard-bounded at `MAX_ACTIVE_NODES = 1000` to prevent runaway expansion regardless of lobe size.

## Design Principles

- **Phase gating** — the scanner is a strict one-way state machine. You cannot jump phases or go backwards. This eliminates entire classes of race conditions and makes the scan pipeline auditable.
- **AIML gating** — results are blocked from the AIML orchestrator until the DONE signal is explicitly emitted. The orchestrator checks `is_aiml_gated(scanner)` before consuming results.
- **Bounded activation** — the active node set is capped at 1,000 entries. When the cap is reached, only the highest-confidence candidates are retained.
- **Typed matches** — `PatternMatch` (direct cosine hit) and `SemanticMatch` (spreading-activation neighbor) are distinct types. Downstream consumers know exactly how each result was found.
- **No silent failures** — all structural violations throw `FullLobeScannerError` immediately (GRUG style).

## Scan Phases

The scanner advances through five phases in strict order:

```
PHASE_INIT → PHASE_GATHER → PHASE_ACTIVATE → PHASE_CONTINUE → PHASE_DONE
```

| Phase | Constant | Entered by | What happens |
|-------|----------|-----------|-------------|
| Init | `PHASE_INIT` | `FullLobeScannerState(...)` | Scanner constructed, no query yet |
| Gather | `PHASE_GATHER` | `set_query!(scanner, vec)` | Cosine similarity scored for all features |
| Activate | `PHASE_ACTIVATE` | `gather_candidates!(scanner, dict)` | Candidates ranked, jitter applied |
| Continue | `PHASE_CONTINUE` | `activate_candidates!(scanner)` | Spreading activation walks neighbors |
| Done | `PHASE_DONE` | `spread_activation!(scanner, dict)` | AIML gate unlocked by `emit_done_signal!` |

## Match Types

### PatternMatch

A direct cosine similarity hit between the query vector and a stored feature vector.

```julia
struct PatternMatch
    node_id        :: String     # ID of the matched node
    confidence     :: Float64    # cosine similarity score ∈ [0, 1]
    matched_pattern:: String     # human-readable pattern label
    source_lobe    :: String     # lobe this node belongs to
end
```

### SemanticMatch

A secondary hit found via spreading activation — a node that is similar to a `PatternMatch` winner but did not directly match the query.

```julia
struct SemanticMatch
    node_id          :: String   # ID of the semantically related node
    confidence       :: Float64  # propagated confidence ∈ [0, 1]
    seed_node_id     :: String   # PatternMatch node that triggered this
    semantic_distance:: Float64  # cosine distance from seed ∈ [0, 1]
    source_lobe      :: String   # lobe this node belongs to
end
```

## Usage

### Basic Scan

```julia
using GrugBot420

# Build your feature dictionary (node_id → signal vector)
features = Dict(
    "node_1" => [0.8, 0.2, 0.6, 0.9],
    "node_2" => [0.1, 0.9, 0.3, 0.2],
    "node_3" => [0.7, 0.3, 0.5, 0.8],
)

query = [0.75, 0.25, 0.55, 0.85]

# Create scanner for the "science" lobe
scanner = FullLobeScannerState("science"; threshold=0.65, max_hops=3)

# Run the pipeline
set_query!(scanner, query)
gather_candidates!(scanner, features)
activate_candidates!(scanner)
spread_activation!(scanner, features)
emit_done_signal!(scanner)

# AIML gate check — always do this before consuming results
if !is_aiml_gated(scanner)
    pattern_hits = get_pattern_matches(scanner)
    semantic_hits = get_semantic_matches(scanner)
    
    for m in pattern_hits
        println("$(m.node_id): conf=$(round(m.confidence, digits=3))")
    end
end
```

### Reusing a Scanner

Call `reset_scanner!` to return to `PHASE_INIT` without reallocating:

```julia
reset_scanner!(scanner)
set_query!(scanner, new_query)
gather_candidates!(scanner, features)
activate_candidates!(scanner)
spread_activation!(scanner, features)
emit_done_signal!(scanner)
```

### Error Handling

```julia
try
    emit_done_signal!(scanner)  # throws if called out of sequence
catch e
    if e isa FullLobeScannerError
        @warn "Scan phase error: $(e.msg)"
    else
        rethrow(e)
    end
end
```

## Key Constants

| Constant | Default | Description |
|----------|---------|-------------|
| `MAX_ACTIVE_NODES` | `1000` | Hard cap on candidates entering the active set |
| `SCANNER_CONFIDENCE_THRESHOLD` | `0.65` | Minimum cosine similarity to include a candidate |
| `SCANNER_MAX_HOPS` | `3` | Maximum spreading-activation depth |
| `SCANNER_THREADS` | `4` | Worker threads for parallel candidate gathering |
| `SEMANTIC_DISTANCE_THRESHOLD` | `0.70` | Cosine distance cutoff for semantic neighbor inclusion |

## API Reference

### Constructor

```julia
FullLobeScannerState(lobe_id::String; threshold::Float64=SCANNER_CONFIDENCE_THRESHOLD, max_hops::Int=SCANNER_MAX_HOPS)
```

Creates a new scanner for the given lobe ID. `threshold` controls the minimum cosine similarity for a candidate to enter the active set. `max_hops` controls how many spreading-activation steps are taken during `spread_activation!`.

### Pipeline Functions

| Function | Requires phase | Advances to | Description |
|----------|---------------|-------------|-------------|
| `set_query!(scanner, vec)` | `PHASE_INIT` | `PHASE_GATHER` | Set query signal vector |
| `gather_candidates!(scanner, dict)` | `PHASE_GATHER` | `PHASE_ACTIVATE` | Score all features against query |
| `activate_candidates!(scanner)` | `PHASE_ACTIVATE` | `PHASE_CONTINUE` | Rank candidates, apply jitter |
| `spread_activation!(scanner, dict)` | `PHASE_CONTINUE` | `PHASE_DONE` | Walk neighbors for semantic hits |
| `emit_done_signal!(scanner)` | `PHASE_DONE` | — | Unlock AIML gate |
| `reset_scanner!(scanner)` | any | `PHASE_INIT` | Clear results, reuse scanner |

### Query Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `get_pattern_matches(scanner)` | `Vector{PatternMatch}` | Direct cosine hits (available after `PHASE_ACTIVATE`) |
| `get_semantic_matches(scanner)` | `Vector{SemanticMatch}` | Spreading-activation hits (available after `PHASE_DONE`) |
| `is_aiml_gated(scanner)` | `Bool` | `true` until `emit_done_signal!` is called |

## Integration with the Vote Pipeline

FullLobeScanner results are consumed by the vote aggregation layer **after** `emit_done_signal!` has been called. The typical integration point is in the BrainStem dispatch path, after the three-pass `scan_and_expand` completes:

1. Three-pass `scan_and_expand` completes (Pass 1 primary scan, Pass 2 lobe cascade, Pass 3 relational fire)
2. FullLobeScanner runs on any lobes that produced high-confidence passes
3. `emit_done_signal!` unlocks AIML gate
4. PatternMatches and SemanticMatches merge into the vote pool with their confidence scores
5. Orchestrator selects winner, classifies SURE/UNSURE

## Relationship to PatternScanner

| | PatternScanner | FullLobeScanner |
|--|---------------|----------------|
| **Input** | `Vector{Float64}` signal + `NODE_MAP` | `Vector{Float64}` query + `Dict{String, Vector{Float64}}` features |
| **Matching** | Sliding window (cheap/medium/high-res tiers) | Cosine similarity + spreading activation |
| **Output** | `(best_index, confidence)` | `Vector{PatternMatch}`, `Vector{SemanticMatch}` |
| **Threading** | Single-threaded | Multi-threaded (up to `SCANNER_THREADS` tasks) |
| **Bounding** | None (scans all nodes) | `MAX_ACTIVE_NODES = 1000` hard cap |
| **AIML gating** | None | Blocked until `emit_done_signal!` |
| **Phase machine** | None | Strict 5-phase one-way machine |

## See Also

- [[Pattern Scanner]] — sliding-window signal matching used in `scan_and_expand`
- [[Architecture Overview]] — full system diagram showing where FullLobeScanner fits
- [[Lobe Partitioning]] — lobe structure that FullLobeScanner sweeps
- [[Immune System]] — immune gate that FullLobeScanner works alongside