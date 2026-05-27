# kitchen_sink_v18d — Full-coverage conversation against real handles

## Why this run exists

v18b/v18c used invented prompts (force/acceleration, acid balances richness,
melody/harmony, fairness) that have **no matching nodes** in this specimen.
Those cycles fell back to thin generic baselines from the `default` lobe —
which made the reply quality look weaker than it actually is.

This run audits the specimen JSON directly, picks one or more **real**
handles from each lobe, and drives a 40-cycle conversation that actually
exercises the graph.

## Lobe coverage matrix

Every lobe in the specimen got at least one targeted prompt:

| Lobe | Nodes | Prompts hit |
|---|---|---|
| greeting | 6 | `hello hi`, `good morning`, `howdy` |
| comfort | 7 | `i feel sad`, `thank you` |
| survival | 7 | `danger`, `fire burns` |
| alert | 5 | `watch out` |
| memory | 2 | `remember when`, `forgot` |
| reasoning | 7 | `why`, `how does fire work`, `think about wolf` |
| inquiry | 3 | `do you know`, `can you` |
| planning | 3 | `what should we`, `hunt tomorrow`, `build cave` |
| celebration | 2 | `we made fire`, `i did it` |
| nature | 3 | `sky`, `river`, `tree` |
| craft | 2 | `hammer`, `make tool` |
| knowledge | 23 | `tell about` × {fire, water, wolf, rock, food} |
| identity | 24 | `who are you`, `what do you do`, `are you smart`, `the tribe`, `the cave`, `goodness` |
| core_rules | 4 | `speak plain`, `listen first`, `never harm tribe` |

## Run inputs

| Item | Value |
|---|---|
| Specimen | `kitchen_sink.specimen.gz` (54 407 bytes, 126 nodes) |
| Conversation script | `conversation.txt` (46 live commands) |
| Exit code | **0** |
| Raw log lines | 1 904 |
| Raw log size | 155 954 bytes |
| Markdown lines | 1 867 |
| Cycles formatted | **40** |

## Side-process artifact grep (must all be 0)

```
tone_align          : 0
frame_mult          : 0
TonalJudge          : 0
ActionTonePredictor : 0
composite           : 0
GRAVED-SLOW         : 0
```

✅ Clean across 1 904 lines of telemetry.

## Routing diversity

- **40 cycles, 40 distinct winning nodes.** No degenerate collapse, no
  one-node-wins-everything pattern. The orchestrator is routing each
  prompt to its semantically-correct node.

## Confidence distribution

| Bucket | Count | Cause |
|---|---|---|
| 0.x baseline | 68 | thin / generic matches in `Other Possibilities` |
| 1.x | 32 | mid-low alternates |
| 2.x | 93 | noun-question relations (rock/water/wolf/food sibling tier) |
| 3.x | 3 | transition tier |
| 4.x | 18 | direct-noun-description aliases (fire/water/wolf/rock/food) |
| 5.0 | 6 | ceiling (alias + token-conf saturation) |

Distinct winning-conf values:
```
0.38, 0.43, 0.50, 0.53, 0.59, 0.60, 0.70, 0.78, 0.79, 1.00,
2.33, 2.38, 2.39, 2.40, 2.48, 2.49, 2.53, 2.55, 2.56, 2.60, 2.79,
3.55,
4.73, 4.74, 4.78, 4.79,
5.00
```

Tiers stay cleanly separated. There is no `0.95-ish noise tier from a
multiplier` and no `composite re-rank pulling values together`. The
arithmetic is `token_conf + rel_conf` only.

## Reply-quality spot check (40 cycles)

| Cycle | Prompt | Winning node intent | Reply head |
|---|---|---|---|
| 1 | `hello hi` | Grug greet warm | "Let me think with you. hello hi. A companion frame: Be polite, brief." |
| 4 | `i feel sad` | Grug sit with you | "every sad-night ends in some kind of morning. A companion frame: Validate, do not fix." |
| 6 | `danger` | Grug see threat | "Warn loud and clear." |
| 9 | `remember when` | Grug remember | claim + **Pinned note: Hot rock burn. Soft skin remember.** |
| 11 | `why` | Grug seek cause | "ask what came before what came before. A companion frame: Trace from effect to source." |
| 16 | `what should we` | Grug weigh path | "grug favor path with least sharp rock." |
| 19 | `we made fire` | Grug rejoice | "fire is up because tribe-hand made it so. The link is clear: tribe made fire." |
| 21 | `river` | Grug know river | "river carry boat carry fish carry song downstream. The link is clear: river carves valley." |
| 24 | `make tool` | Grug make tool | "grug make tool slow tool last long." |
| 26 | `tell about water` | Grug describe water directly | full multi-clause descriptive reply (14 supporting clauses) |
| 30 | `describe fire` (`/brainstorm`) | Grug describe fire directly | full multi-clause descriptive reply (11 supporting clauses) |
| 32 | `who are you` | Grug introduce | "Mouth that try and what is grug if not ear that listen. The link is clear: grug listens tribe." |
| 38 | `speak plain` | Grug pin: plain talk | claim + **Pinned note: Grug speak plain. Grug not pretend smart.** |

Every cycle has a coherent claim threaded to its lobe's intent. Where
the node has a `companion frame` it gets surfaced. Pinned-memory paths
fire on `remember when` and `speak plain`. The high-tier descriptive
prompts (`tell about water`, `describe fire`) produce the full
multi-clause expansion.

## Verdict

✅ Confidence-isolation is intact — zero side-process artifacts in 1904
lines.
✅ Tier separation is clean (0.x baseline / 2.x noun-question /
4.x–5.x alias).
✅ Routing diversity is total — 40 cycles, 40 distinct winning nodes.
✅ Reply quality across **all 14 lobes** lands on coherent in-character
output (greeting / comfort / survival / alert / memory / reasoning /
inquiry / planning / celebration / nature / craft / knowledge /
identity / core_rules).
✅ Pinned-memory threading works (cycles 9 and 38).
✅ Multi-clause descriptive expansion works on `tell about X` /
`describe X` (cycles 26, 30 and others).

This is the verification we wanted. Reply quality is at the level
expected for this specimen size — and the prior thin baselines in
v18b/v18c were specimen-mismatch, not engine regression.
