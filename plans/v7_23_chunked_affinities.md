# v7.23 — Chunked Affinities: Pattern-Bind Scoping

## Core Idea
Right now, when a node fires on input "what is the capital of France and what is 2+2",
the vote says "I matched" but doesn't know WHICH PART it matched. The only way to
scope votes to sub-subjects is the multipart_group tag that InputDecomposer stamps
on the specimen BEFORE scan.

The fix: make the pattern bind phase chunk the input, and have each vote carry
which input chunk(s) it resolved. This is biologically coherent — place cells fire
for a specific location, not "the environment." Object cells fire for a specific
object, not "the scene."

## Architecture

### 1. InputChunk — a span of the input
A lightweight representation of a contiguous region of the input. Not a string
copy — just a (first_token, last_token, chunk_index, text) struct + a chunk_index
for fast comparison. Chunks are produced by the InputDecomposer's
`chunk_boundaries()` function BEFORE scan.

```julia
struct InputChunk
    first_token::Int
    last_token::Int
    chunk_index::Int
    text::String
end
```

### 2. Vote gets `input_chunks::Vector{Int}` field
Instead of (or in addition to) `multipart_group::String`, each vote carries the
indices of the input chunks it matched. A vote that matched chunk 1 gets
`input_chunks = [1]`. A vote that matched chunks 1 and 2 (overlapping pattern)
gets `input_chunks = [1, 2]`. Empty = singleton / unchunked input.

### 3. Pattern bind phase produces chunked affinities
In scan_specimens / scan_and_expand, when the scanner matches a node against
the input, it also computes WHICH CHUNK(S) of the input the match covers.
This is the key change — the scanner already knows the span it matched; we
just need to cross-reference that span against the chunk boundaries.

The `_match_to_chunks()` helper in engine.jl computes chunk overlap given the
match's token position and the chunk boundaries. It returns the list of
overlapping chunk indices.

### 4. MultipartOrchestrator groups by chunk, not by tag
`group_votes_by_multipart` currently groups by `multipart_group` string.
With chunked affinities, `group_votes_by_chunks` groups by `input_chunks` —
votes that resolved overlapping chunks are coalesced into the same objective.
Union-Find / Connected Components algorithm handles transitive overlap: if
vote A covers chunks [1,2] and vote B covers chunks [2,3], they share chunk 2
and land in the same group `"chk_1_2_3"`.

When `cast_vote_chunked` stamps all votes as `:primary`, the new
`_objective_from_chunk_group` reassigns roles: highest-confidence vote becomes
the objective's primary, the rest become supports. This avoids the
MultipartError that the legacy path throws for multiple primaries.

### 5. InputDecomposer becomes the chunk boundary provider
Instead of assigning group IDs, InputDecomposer produces chunk boundaries
(token ranges). It still does the same heuristic detection (conjunctions,
question markers, commas), but its output is boundaries, not group tags.
The scanner uses these boundaries to determine which chunk(s) each match
covers.

### 6. HippocampalModulator uses chunk-aware dependencies
Instead of the conservative "every multipart objective depends on all prior
multipart objectives," the modulator now computes dependencies from chunk
overlap. Objectives whose chunks don't overlap are independent and can execute
in parallel. Legacy objectives (no chunk info) still use the conservative
dependency path.

The `_chunks_from_group_id()` helper parses `"chk_1_2_3"` → `Set([1,2,3])`
for dependency computation. Two objectives depend on each other only if their
chunk sets intersect.

## Benefits
- Votes are self-scoping — grounded in what the node ACTUALLY matched
- MultipartOrchestrator groups by ground truth (match span), not guess (tag)
- HippocampalModulator gets real dependency info (chunk 2 references "its"
  which means chunk 1's output)
- InputDecomposer's heuristic is still used but for BOUNDARY detection,
  not for authoritative grouping — the match phase has the final say
- Bio-coherent: place cells / object cells carry their own scope
- Parallelism: objectives about disjoint input chunks can run concurrently

## Migration Path
- Add `input_chunks::Vector{Int}` to Vote (default empty = old behavior) ✅
- InputDecomposer gains `chunk_boundaries()` that returns token ranges ✅
- scan_specimens receives chunk boundaries, cross-references match spans ✅
- cast_vote / cast_vote_with_group get new variants that accept chunks ✅
- MultipartOrchestrator gains `group_votes_by_chunks` alongside existing
  `group_votes_by_multipart` — both work, old path preserved ✅
- HippocampalModulator uses chunk-based grouping when available ✅
- process_mission updated to use chunk-aware pipeline ✅

## Implementation Details

### Union-Find for chunk grouping
`group_votes_by_chunks` uses a Union-Find (disjoint set) data structure with
path compression and union by rank. Each vote's chunk indices form a set;
votes whose chunk sets share any index are transitively connected. The
connected components then define the objective groups.

### group_id naming convention
- `"chk_1_2_3"` — chunk-derived groups (chunks 1, 2, and 3)
- `"mp_1"` — legacy decomposer-derived groups (unchanged from before)
- `""` — singletons (unchanged)

### Role reassignment in chunk groups
When `cast_vote_chunked` always stamps `:primary`, multiple chunked votes in
the same connected component would all be `:primary`. The
`_reassign_roles!` helper picks the highest-confidence vote as the objective's
primary and demotes the rest to `:support`, then `_objective_from_chunk_group`
builds the objective with the standard locked/unsure partitioning.

### Backward compatibility
- Votes without `input_chunks` (empty vector) fall through to the legacy
  `group_votes_by_multipart` path
- `build_objectives` auto-detects which path to use: if any vote has non-empty
  `input_chunks`, it uses the chunk path; otherwise the legacy path
- `process_mission` checks both `multipart_group` and `input_chunks` for the
  `has_multipart` flag

## Tasks
- [x] Design InputChunk representation (token range + chunk_index + text)
- [x] Add `input_chunks::Vector{Int}` to Vote struct (back-compat default)
- [x] InputDecomposer: add `chunk_boundaries()` function
- [x] scan_specimens: accept chunk boundaries, compute per-match chunk affinity
- [x] cast_vote variants: accept input_chunks parameter (`cast_vote_chunked`)
- [x] MultipartOrchestrator: add `group_votes_by_chunks` path
- [x] HippocampalModulator: use chunk-based dependencies when available
- [x] Update process_mission to use chunk-aware pipeline
- [x] Write tests (23 test cases across 3 parts)
- [x] Update plans doc
- [ ] Commit and push
