# GrugBot420.jl

*A neuromorphic cognitive engine written in Julia.*

GrugBot420 models cognition through competing populations of pattern nodes — not if-else waterfalls, not transformers, not lookup tables. Many rocks compete to be loudest. Loudest rock gets to talk. Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.

## Features

- **Neuromorphic Pattern Nodes** — Atomic cognitive units with pattern matching, action packets, and competitive voting
- **Hopfield Cache** — Familiar-input fast-path for previously-seen patterns
- **Multi-Resolution Scanning** — `cheap_scan` → `medium_scan` → `high_res_scan` signal-level pattern matching
- **Subject-Specific Lobes** — Partitioned node groups with O(1) reverse index and per-lobe chunked hash tables
- **BrainStem Dispatcher** — Winner-take-all with cross-lobe signal propagation and fire-count decay
- **Dimensional Thesaurus** — Multi-axis similarity engine (semantic, contextual, associative) with seed synonym dictionary
- **Visual Attention (EyeSystem)** — Edge blurring, arousal-gated cutout, attention modulation on SDF image signals
- **Stochastic Orchestration** — Coinflip-weighted probabilistic rules injected into every response
- **Idle Gossip (ChatterMode)** — Ephemeral node clones exchange patterns during quiet periods (1000+ node gate)
- **Self-Healing (PhagyMode)** — Seven maintenance automata for orphan pruning, cache validation, memory forensics, and more
- **Specimen Persistence** — Full cave state freeze/restore via gzip-compressed JSON snapshots
- **Relational Fire (Node Attachments)** — User-defined relay circuitry: attach up to 4 nodes to any target; when the target fires, attachments coinflip to join the vote pool with pattern-derived confidence
- **Specimen Immune System** — Automata-based anomaly detection gates all structure-storing commands: AST scan → Hopfield immune memory → quarantine → patch → delete pipeline. Activates at ≥ 1000 nodes
- **Vote Tie-Breaking & Certainty** — Tied votes resolved randomly via `shuffle!`; responses classified SURE/UNSURE; tied alternatives and runner-ups listed with relational context; AIML tags `{VOTE_CERTAINTY}` and `{TIED_ALTERNATIVES}`
- **AIML Node System** — Per-lobe AIML node tribes with isolated populations and independent population caps; graves excluded from caps to prevent "cap lock"

## Installation

```julia
using Pkg
Pkg.add("GrugBot420")
```

Or from the repository directly:

```julia
Pkg.add(url="https://github.com/marshalldavidson61-arch/grugbot420")
```

## Quick Start

```julia
using GrugBot420
# Launch the interactive Brain> REPL
GrugBot420.main()
```

## Table of Contents

```@contents
Pages = ["architecture.md", "cli.md", "api.md"]
Depth = 2
```
