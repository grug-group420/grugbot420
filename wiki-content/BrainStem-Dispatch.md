# BrainStem Dispatch

The BrainStem (`src/BrainStem.jl`) is the central action dispatcher — the final stage of the vote pipeline.

## Role

The BrainStem is **not** the whole mind. It is the action organizer. Its job:

1. Receive resolved vote state from the quorum
2. Interpret the dominant action packet
3. Route through cross-lobe signal propagation
4. Execute the correct output path
5. Track dispatch counts and propagation history

## Vote Resolution Flow

```
All active nodes → Vote aggregation → Sure/Unsure classification → BrainStem → Response
```

### Sure vs Unsure

- **Sure Basket**: All votes within 0.05 of max confidence
- **Exact ties**: Shuffled randomly (no deterministic first-in-sort bias)
- **SURE**: Primary winner stands alone at top
- **UNSURE**: Ties existed — winner picked randomly from tied group
- **Tied alternatives**: Listed with node ID, action, confidence, and relational triples
- **Runner-ups**: Below-threshold votes kept via coinflip, listed as "Other Possibilities"

## Cross-Lobe Propagation

When connected lobes are involved, the BrainStem propagates signals laterally with **60% decay per hop**. This allows domain knowledge to influence adjacent domains without overwhelming them.

## Fire-Count Decay

The BrainStem tracks fire counts over time. Repeated firing patterns gradually decay, preventing stale routing from dominating.
