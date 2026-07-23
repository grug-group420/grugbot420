# EyeSystem & Image SDF

The visual subsystem handles image processing through arousal-gated attention and GPU-accelerated Signed Distance Field conversion.

## EyeSystem (`src/EyeSystem.jl`)

Controls visual attention:
- **Arousal level** (0.0–1.0) — higher = tighter center cutout
- **Edge blurring** — peripheral de-emphasis
- **Attention modulation** — focus based on arousal state

Set manually:
```
/arousal 0.7
```

## ImageSDF (`src/ImageSDF.jl`)

Converts image binary to nonlinear SDF via `JITGPU(binary; width, height)`:

1. Image binary detected (Base64 data URI, hex, or raw bytes)
2. Real `KernelAbstractions.jl` GPU kernel dispatch
3. Backend selected at runtime: CUDA (NVIDIA), ROC (AMD), Metal (Apple Silicon), CPU fallback
4. Two-pass kernel: parallel pixel decode → `synchronize` → parallel `tanh(3×grad_mag)` SDF activation
5. Flattened to signal vector via `sdf_to_signal()` for PatternScanner compatibility

## Temporal Coherence

`TEMPORAL_COHERENCE_LEDGER` tracks SDF timing patterns and coherence scores across sequential image inputs. Saved/restored with specimens (section 16).

## Integration

Image nodes participate in the same vote pipeline as text nodes. Image attachments use SDF cosine similarity for confidence baking (see [[Relational Fire]]).
