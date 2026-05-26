# QoL Sweep — Live Tracker

## ✅ Done & verified
- BUG-001 MESSAGE_LOCK typo
- BUG-002 LobeTable double-include
- BUG-003 Lobe subject snake_case normalization
- BUG-004 Long-pattern bidirectional swap
- BUG-005 `/addVerb` accept either argument order
- BUG-006 `/grow` accepts both `data` and `json_data`
- BUG-007 action_packet validation at grow time
- BUG-008 Unified `/grow <lobe_id> <json>`
- BUG-009 Auto-create `default` lobe at boot + auto-load default specimen
- BUG-010 Default system_prompt injection
- **BUG-011 Hard-mute gate REMOVED, replaced with averages curve (LobeOrchestrator)**
- SMELL-003 Hopfield dead-code block removed
- SMELL-004 Magic scan thresholds promoted to named constants
- Default specimen built (`grug-binary/default.specimen.gz`, 20 nodes / 7 lobes)
- **CRYSTALIZE engine + CLI** (`/crystalize`, `/decrystalize`) — sticky attachments
- **Latch partner cap 8–16 per-node** — `Node.max_neighbors` rolled at construction
- Hardcore retest after CRYSTALIZE + latch cap: **10/10, 10/10, 9/10** Grug replies (1 silent across 30 missions)

## Remaining from user's spec (this turn)
3. **Chatter mode rewrite** — vote-copy not pattern-copy; group hash table; 100–400 round-robin window; per-node 1h cooldown; 1 vote-swap per event; semantic-gated swap; jitter weights; NONJITTER carve-out for low-conf votes on strong nodes
4. **Phagy idle role** — group-id hygiene + UNLINKABLE-clear-on-graved-in-group
5. **Action tone predictor** — dynamic only on semantically complex inputs
6. **Auto-crystalize-sweep wiring** — call `auto_crystalize_sweep!()` from idle/chatter loop
7. **Push to github.com/grug-group420/grugbot420** with PAT
8. **Tell user to revoke PAT** after push
