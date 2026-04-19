# Relational Fire

The relational fire system lets you wire nodes into explicit firing chains. When a target fires during `scan_and_expand`, attached nodes coinflip to decide whether they should fire too.

## Text Attachments

```
/nodeAttach node_0 node_1 "machine learning" node_2 "gradient descent"
```

Attaches `node_1` and `node_2` to `node_0` with connector patterns explaining WHY they're related.

## JIT Confidence Baking

Confidence is computed **once at attach time** (not every fire cycle):

1. Jaccard token overlap between connector pattern and attached node's pattern
2. Strength bonus: `(strength / STRENGTH_CAP) × 0.5`
3. Stored as `base_confidence` in `AttachedNode` struct

At fire time:
1. **Coinflip**: `scan_prob = 0.20 + (strength / STRENGTH_CAP) × 0.70`
2. Winners use pre-baked `base_confidence` + stochastic jitter: `max(0.1, base_confidence + randn() × 0.05)`
3. Connector pattern surfaces as `RelationalTriple(target_id, "relay_attached", connector_pattern)`
4. Active cap (`rand(600:1800)`) respected — biological attention bottleneck

## Image Attachments

```
/imgnodeAttach node_0 img_node_1 "data:image/png;base64,..." 64 64
```

Uses real GPU kernel dispatch via `KernelAbstractions.jl`:
- Backend: `CUDABackend()` (NVIDIA), `ROCBackend()` (AMD), `MetalBackend()` (Apple), or `CPU()` fallback
- Two-pass kernel: parallel pixel decode → synchronize → parallel `tanh(3×grad_mag)` SDF activation
- Confidence from SDF cosine similarity

## Constraints

- **Max 4 attachments** per target
- No self-attachment
- No duplicates
- Target and attachment must exist and not be graves
- Image attachments require image nodes

## Pipeline Position

Relational fire runs as **Pass 3** in `scan_and_expand()`, after primary scan (Pass 1) and lobe cascade (Pass 2).
