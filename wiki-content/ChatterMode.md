# ChatterMode

ChatterMode (`src/ChatterMode.jl`) is the idle gossip and consolidation system. During quiet periods, nodes exchange patterns and weak nodes drift toward stronger ones.

## Trigger Conditions

- **Idle timer**: 120 seconds ± 30s jitter (shared with PhagyMode)
- **Population gate**: 1,000+ alive non-image nodes required
- **50% chance** per idle event (coinflip vs PhagyMode)

## How It Works

1. Random subset of 50–500 eligible nodes selected
2. Ephemeral clones created (originals untouched)
3. Clones gossip — exchange limited pattern influence
4. **Only weaker receivers morph** — receivers must be weaker than senders
5. Blend is partial, not total overwrite
6. Anti-collision prevents repeated pair exchanges in one round
7. User input queued until session completes

## Morph Cooldown

Each node can morph **only once every 24 hours**. Tracked in `MORPH_COOLDOWN_MAP`. Prevents repeated overwriting of weak nodes and preserves long-term identity.

## Purpose

Chatter is **consolidation** — low-flow internal adjustment during quiet periods. It lets the specimen self-organize without external input. Strong patterns gradually influence weak neighbors, creating emergent clustering.

## Constraints

- Group size: 50–500 nodes
- If fewer than 50 eligible nodes exist, floors at whatever is available
- New specimens (< 1,000 nodes) skip chatter entirely
- Runs between CLI prompts — no manual trigger needed
