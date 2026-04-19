# Architecture Overview

grugbot420 is a **specimen-based cognitive runtime** — not a chatbot, not a transformer wrapper. It is a field organism made of nodes, lobes, gates, action packets, memory surfaces, upkeep functions, inhibition layers, and alignment events.

## Design Philosophy: Organ-First

Most AI systems start from a central abstract brain and attach helpers afterward. grugbot420 inverts this:

1. **Organs before brain** — Nodes, lobes, gates, upkeep exist first
2. **Structure before narrative** — Topology drives behavior
3. **Signal before symbol** — Pattern matching at the signal level
4. **Resonance before command** — Quorum voting, not deterministic dispatch
5. **Geometry before reduction** — Field alignment over forced exactness

## System Architecture Diagram

```
Input ──→ [InputQueue] ──→ [NegativeThesaurus Filter]
                                    │
                                    ▼
                          [PatternScanner]
                           ┌────┬────┐
                           │    │    │
                        cheap medium high_res
                           │    │    │
                           └────┴────┘
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              [Pass 1]    [Pass 2]    [Pass 3]
             Primary     Lobe       Relational
              Scan      Cascade      Fire
                    │           │           │
                    └───────────┼───────────┘
                                │
                                ▼
                        [Vote Aggregation]
                         sure / unsure
                                │
                                ▼
                        [BrainStem Dispatch]
                                │
                                ▼
                           Response
```

## Core Components

### Nodes (`src/engine.jl`)
The atomic unit. Each node has:
- **Pattern** — text it matches against
- **Signal** — numeric representation for comparison
- **Strength** — local trust/influence (0.0 to cap)
- **Action Packet** — proposed behavioral output
- **Neighbors** — topology connections (drop table)
- **Lobe** — domain partition membership
- **Grave state** — dead nodes waiting for recycling

### Pattern Scanner (`src/patternscanner.jl`)
Three scan tiers selected per-node based on complexity:
- `cheap_scan` — fast token overlap (bidirectional for Tier-1 nodes)
- `medium_scan` — deeper similarity with position awareness
- `high_res_scan` — full structural analysis

### Lobes (`src/Lobe.jl`)
Domain partitions with O(1) reverse index. Cap: 20,000 nodes per lobe, 64 lobes max. Connected lobes propagate signals with 60% decay per hop.

### BrainStem (`src/BrainStem.jl`)
Winner-take-all dispatcher with cross-lobe signal propagation and fire-count decay.

### Vote Resolution
1. **Sure Basket** — votes within 0.05 of max confidence
2. **Tie Detection** — exact ties shuffled randomly
3. **SURE vs UNSURE** classification
4. **Runner-up alternatives** preserved for inspection

## Subsystems

| Subsystem | File | Purpose |
|-----------|------|---------|
| [[Immune System]] | `ImmuneSystem.jl` | Protects mature specimens from funky inputs |
| [[ChatterMode]] | `ChatterMode.jl` | Idle gossip — weak nodes drift toward strong |
| [[PhagyMode]] | `PhagyMode.jl` | Idle maintenance — pruning, decay, recycling |
| [[Thesaurus System]] | `Thesaurus.jl` | Semantic similarity and synonym expansion |
| [[EyeSystem & Image SDF]] | `EyeSystem.jl`, `ImageSDF.jl` | Visual attention and GPU SDF conversion |
| [[Relational Fire]] | `engine.jl` | JIT confidence-baked node attachment chains |
| ActionTonePredictor | `ActionTonePredictor.jl` | Pre-vote action/tone classification |

## Runtime Pipeline

1. **Input** arrives at `InputQueue`
2. **NegativeThesaurus** filters inhibited words
3. **PatternScanner** converts input to signal, selects scan tier per node
4. **Pass 1 (Primary Scan)** — all nodes scanned, top activators collected
5. **Pass 2 (Lobe Cascade)** — connected lobes propagate lateral signals
6. **Pass 3 (Relational Fire)** — attachment chains fire with JIT confidence
7. **Vote Aggregation** — action packets weighted, ties resolved stochastically
8. **BrainStem Dispatch** — final action executed
9. **Hopfield Cache** — successful patterns cached for fast recall

## Idle Behavior (120s ± 30s)

When no input arrives for ~120 seconds:
- **50% chance: ChatterMode** — 50–500 clones gossip (1000+ nodes required)
- **50% chance: PhagyMode** — one maintenance action runs (1000+ nodes required)

## Current vs Planned Scope

**Implemented:** Node cognition, lobe partitioning, quorum voting, brainstem dispatch, specimen persistence, immune system, chatter, phagy, thesaurus, inhibition, relational fire, image SDF.

**Planned:** HTNN-style transcriptional layers, advanced image-to-symbol bridging, JIT fuzzy art generation, deeper nonlinear SDF visual organs, hormone-style modulation systems.
