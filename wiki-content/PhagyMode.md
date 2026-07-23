# PhagyMode

PhagyMode (`src/PhagyMode.jl`) is the maintenance and cleanup layer — the specimen's metabolism.

## Trigger

- **Idle timer**: 120 seconds ± 30s (shared with ChatterMode)
- **Population gate**: 1,000+ alive non-image nodes
- **50% chance** per idle event

## Maintenance Actions

One bounded action per idle event:

| Action | Purpose |
|--------|---------|
| Orphan pruning | Remove disconnected nodes with no topology |
| Strength decay | Gradually weaken unused nodes |
| Grave recycling | Reclaim dead node slots |
| Cache validation | Verify Hopfield cache integrity |
| Drop table compaction | Clean up stale neighbor references |
| Rule pruning | Remove rules that never fire |
| Memory forensics | Audit memory usage and flag anomalies |

## Design

Phagy performs **one** action per cycle. This keeps complexity manageable while maintaining specimen health over time. It reduces clutter, decay, and structural waste.

Like chatter, phagy is gated behind specimen maturity (1,000+ nodes).
