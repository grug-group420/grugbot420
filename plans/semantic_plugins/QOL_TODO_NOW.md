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
- Hardcore boot test: 0–2/10 silent (down from 8/10)

## Remaining from user's spec (this turn)
1. **CRYSTALIZE tag for attached nodes** — manual + auto-from-semantic-truth
2. **Latch partner cap 8–16** — verify or implement randomly-rolled per-node cap with UNLINKABLE flag
3. **Chatter mode rewrite** — vote-copy not pattern-copy; group hash table; 100–400 round-robin window; per-node 1h cooldown; 1 vote-swap per event; semantic-gated swap; jitter weights; NONJITTER carve-out for low-conf votes on strong nodes
4. **Phagy idle role** — group-id hygiene + UNLINKABLE-clear-on-graved-in-group
5. **Action tone predictor** — dynamic only on semantically complex inputs
6. **Hardcore retest** — confirm the orchestrator + remaining changes still hit 0/10 silent
7. **Commit grouped (BUG-NNN per commit)** + push to github.com/grug-group420/grugbot420
8. **Tell user to revoke PAT**
