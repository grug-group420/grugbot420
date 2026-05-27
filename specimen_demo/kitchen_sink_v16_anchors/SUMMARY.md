# Kitchen Sink v16 — ANCHOR NODES (NONJITTER + tiered strength)

**Release tag:** v7.21c-4 (config-only — no engine changes from v7.21c-2)

## Directive driving this release

> "should have more nodes with nonjitter and high strength for confidence
> lock ins"

v15 demonstrated that **dense vote pools** give the bot variety. v16 adds
**confidence anchors** — specific bedrock nodes the bot must answer reliably
on. NONJITTER + high strength = a node that wins its frame consistently and
returns bit-stable confidence on repeat scans.

## What's new in v16

### Two new lobes

- **`identity`** (6 nodes, strength 4.0, NONJITTER): who is grug, the tribe,
  the cave, what do you do, are you smart, goodness.
- **`core_rules`** (4 nodes, strength 5.0, NONJITTER): speak plain, listen
  first, not pretend, never harm tribe.

### 7 existing knowledge/comfort/alert nodes promoted to anchored

- Knowledge bedrock (strength 3.0 + NONJITTER): `fire`, `wolf`
- Comfort bedrock (strength 3.0 + NONJITTER): `sad`, `scared`
- Alert urgent (strength 4.0 + NONJITTER): `watch out`, `warning`, `stop`

### Tiered strength strategy

Engine cap = 10.0. Default = 1.0. Auto-crystallize floor = 5.0.

| tier | strength | meaning |
|---|---|---|
| `core_rules`     | 5.0 | meta-rules, also auto-crystallized |
| `identity`       | 4.0 | self-talk, only for self queries |
| alert bedrock    | 4.0 | urgent must-fire on threat words |
| knowledge bedrock| 3.0 | topic-locked, doesn't outvote peers |
| comfort bedrock  | 3.0 | emotional must-fire |
| (everything else) | 1.0 | default, full jitter, full pool variety |

All 17 anchors carry `required_relations: ["NONJITTER"]` so their end-confidence
is bit-stable on repeat scans. The variety layers (multiple prose slots in the
action_packet, thesaurus swap ≈25%, phrase reorder ≈40%) **still apply inside
the action_packet** — the anchor only locks *which node wins*, not *which slot
inside the node fires*.

## Lessons learned during this build

The first v16 draft used strength=8–10 on identity/core_rules and naively
re-used "what is X" as patterns for the identity nodes. Two failure modes
appeared in the run logs:

1. **Strength theft.** Identity nodes at strength 9 outvoted topic-correct
   peers (e.g. "what is fire" routed to `[Grug know tribe]` because tribe at
   str=9 beat fire at str=8). **Fix:** dropped strengths to 3–5 across the
   board. NONJITTER alone gives the confidence lock-in; strength only biases
   the coinflip and a small bias is enough.
2. **Pattern prefix collision.** Patterns "what is tribe" / "what is cave" /
   "what is good" shared the "what is" prefix with topic queries. The pattern
   matcher gave them partial-match credit and the strength bias did the rest.
   **Fix:** identity patterns are now noun-only (`the tribe`, `the cave`,
   `goodness`); the "what is X" surface forms live in `drop_table` where they
   contribute partial-match scoring without dominating exact-pattern hits.

These two corrections turned the first run's 6 hijacks into the final run's 0
hijacks. **No engine code changed**; everything was reconfigurable in the
seed file alone.

## Verification — anchor probe results

```
who are you            → [Grug introduce]      grug is grug grug is here grug listen
who are you            → [Grug introduce]      grug is helper not master
who are you            → [Grug introduce]      grug is friend who consider slow and say plain
the tribe              → [Grug know tribe]     tribe is bigger than self smaller than world
the tribe              → [Grug know tribe]     tribe carry each other through long winter
the cave               → [Grug know cave]      cave is wall around fire wall around sleep
are you smart          → [Grug stay humble]    grug know small things deep grug know big things little
goodness               → [Grug know good]      good is fact said gently truth still
speak plain please     → [Grug pin: plain talk]    what is plain if not respect for ear of listener
listen first to me     → [Grug pin: listen]        what is listening if not letting other voice land first
do not pretend         → [Grug pin: honesty]       not-know is honest answer when grug not know
never harm the tribe   → [Grug pin: protect tribe] grug refuse harm even when asked
i am sad               → [Grug sit with you]   grug hear you grug stay near
i am scared            → [Grug shelter you]    fear is shadow of thing not thing itself
watch out behind you   → [Grug point at incoming]  watch out
warning incoming       → [Grug raise voice]    the warning
stop right now         → [Grug halt]           foot up hand up eye up
```

Every anchor frame routed to its anchor node. Three calls to `who are you`
returned three different prose slots from the dense pool — confirming that
**variety inside the pool still works on top of node-level anchoring.**

## What v16 proves

1. **Confidence anchors are config, not engine.** NONJITTER + initial_strength
   are first-class fields in `data{}` already shipped in v7.21c-2. v16 just
   uses them with intent.
2. **Anchors and dense pools compose.** A NONJITTER node still picks a slot
   from its pool stochastically and still gets thesaurus + reorder layers
   applied. The anchor stabilizes *which node fires*, not *what it says*.
3. **Strength must be measured.** A small lift (3–5) is plenty. Anything
   above 5 starts stealing topic queries via partial-match scoring.
4. **Patterns are part of the anchor design.** Identity-class anchors must
   not share token prefixes with topic queries. Use `drop_table` for the
   alternate surface forms instead of competing patterns.

## Files

- `specimen_seed.txt` — v15 dense pools + anchor promotions + 2 new anchor lobes (206 lines).
- `promote_anchors.py` — the script that produces the seed from the v15 base.
- `seed_cmds.txt` — comments-stripped seed + /saveSpecimen + /quit.
- `seed_build.log` — clean build trace, 0 FATALs.
- `kitchen_sink.specimen.gz` — pre-run specimen (72 nodes, 15 lobes, 17 anchors).
- `missions_clean.txt` — 175-line mission script (v15 + 24 anchor probes).
- `anchor_probes.txt` — the 24 anchor-probe missions standalone.
- `run.log` — full mission run trace.
- `spoken_v16.txt` — 91 mission/reply pairs.
- `kitchen_sink_post_run.specimen.gz` — post-run specimen.

## Comparison vs v15

| metric | v15 dense | v16 anchors |
|---|---|---|
| total nodes              | 62 | 72 |
| lobes                    | 14 | 15 (added identity, core_rules) |
| anchored nodes (NONJITTER) | 0 | 17 |
| FATALs in build          | 0  | 0 |
| anchor-probe success     | n/a | 17/17 |
| topic-query hijacks      | 0 (no anchors) | 0 (after tier fix) |
| engine commits           | v7.21c-2 | v7.21c-2 (unchanged) |

v15 made the bot speak more variedly. v16 makes it answer reliably on the
things that must not drift — identity, ground rules, urgent alerts, raw
emotion. Together they produce a bot that is **flexible where it should be
and rigid where it should be.**
