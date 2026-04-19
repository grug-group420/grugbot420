# Pattern Scanner

The PatternScanner (`src/patternscanner.jl`) converts input text to signals and matches them against node patterns using tiered scanning.

## Scan Tiers

The scanner selects tier per-node based on input + pattern complexity:

| Tier | Function | Use Case |
|------|----------|----------|
| Tier 1 | `cheap_scan` | Fast token overlap. Uses `_bidirectional_cheap_scan` (forward + reverse, smoothed confidence). |
| Tier 2 | `medium_scan` | Deeper similarity with position awareness. |
| Tier 3 | `high_res_scan` | Full structural analysis for complex patterns. |

## Signal Conversion

Human-readable text patterns are converted into simplified signal representations used for:
- Overlap detection
- Similarity checks
- Activation latching
- Vote triggering

These are **not** giant black-box semantic embeddings. They are local field representations — inspectable and portable.

## Pipeline Position

```
Input → InputQueue → NegativeThesaurus Filter → PatternScanner → Pass 1/2/3 → Votes
```

The scanner runs before all three passes:
1. **Pass 1 (Primary)** — all nodes scanned, top activators collected
2. **Pass 2 (Lobe Cascade)** — connected lobes propagate lateral signals
3. **Pass 3 (Relational Fire)** — attachment chains fire with JIT confidence
