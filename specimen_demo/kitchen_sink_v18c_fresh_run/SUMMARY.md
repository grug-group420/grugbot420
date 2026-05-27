# kitchen_sink_v18c — Fresh confidence-isolation conversation

## Purpose

Re-run the v18b mix from a clean Julia invocation against the same v17
descriptive-votes specimen (126 nodes), to verify that:

1. The v7.21c-5 confidence-isolation work is **stable across runs** —
   confidence values reproduce structurally across re-invocations.
2. Reply quality on the descriptive prompts continues to look as
   intended (multi-clause claims with Pinned-memory and supporting
   clauses on the high-tier hits, thin generic baselines on the
   subject-lobe missions where the specimen is sparse).
3. No side-process artifacts (`tone_align`, `frame_mult`, `TonalJudge`,
   `ActionTonePredictor`, `composite`, `GRAVED-SLOW`) appear in the
   raw log.

## Run inputs

| Item | Value |
|---|---|
| Specimen | `specimen_demo/kitchen_sink_v18c_fresh_run/kitchen_sink.specimen.gz` |
| Specimen size | 54 407 bytes |
| Specimen nodes | 126 |
| Conversation script | `conversation.txt` (21 live commands) |
| CLI invocation | `julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()'` |
| Exit code | **0** |
| Raw log lines | 1 169 |
| Raw log size | 102 694 bytes |
| Markdown lines | 936 |
| Cycles formatted | **16** |

## Side-process artifact grep (must all be 0)

```
tone_align          : 0
frame_mult          : 0
TonalJudge          : 0
ActionTonePredictor : 0
composite           : 0
GRAVED-SLOW         : 0
```

✅ Clean. The v7.21c-5 isolation work is intact in this fresh run.

## Confidence tiers (winning-node `conf=` values, distinct, sorted)

| Tier | Values | Cause |
|---|---|---|
| Baseline | 0.31, 0.48, 0.50, 0.53, 0.60, 0.70, 0.79, 1.00 | Generic non-alias matches, low-token prompts |
| Noun-question relations | 2.14 – 2.79 (cluster around 2.50–2.55) | v7.21c-5 noun-question relation parsing on rock/water/wolf/food |
| Direct-noun-description aliases | 4.74, 4.78, 4.79, **4.83**, 4.95, 5.00 | v7.21c-5 alias nodes (`describe X directly`) |

Tier separation is clean — there is no smearing, no fractional drift
caused by a multiplier, no composite re-rank pulling values together.
The high tier (≥4.74) is exactly where the descriptive aliases live
and the middle tier (≈2.5) is exactly where the noun-question
relation parses live; that is the structural arithmetic
`token_conf + rel_conf` doing its job alone.

## Cross-run comparison vs. v18b

| | v18b | v18c | match |
|---|---|---|---|
| Exit code | 0 | 0 | ✅ |
| Cycles | 16 | 16 | ✅ |
| Raw log lines | 1 170 | 1 169 | ≈ |
| Raw log size | 100 KB | 100 KB | ≈ |
| `conf=4.83` (fire siblings) | 3 | 3 | ✅ |
| Side-process artifacts | 0 | 0 | ✅ |
| Cycle 9 winning node | node_66 @ 4.83 | node_66 @ 4.83 | ✅ |
| Cycle 9 ties (same conf) | node_67, node_100 @ 4.83 | node_67, node_100 @ 4.83 | ✅ |

Run-to-run determinism on confidence values is exact at the alias
tier. The lobe-curve scoring and AIML memory bank also reproduce.
This is what we expect when no stochastic side-process is poking the
arithmetic.

## Headline cycle: cycle 9 — `/mission tell me about fire`

```
Primary Action: fire eats dry grass and grows fast  (conf=4.83, certainty=UNSURE)
Sure Actions:   [fire eats dry grass and grows fast,
                 fire bright and makes smoke,
                 fire dangerous because it bites skin]
Winning Node:   node_66
Tied Alternatives (not selected):
  🪨 node_67  | fire bright and makes smoke           | conf=4.83
  🪨 node_100 | fire dangerous because it bites skin  | conf=4.83
Other Possibilities (rock tier @ 2.55):
  🔸 node_76  | rock hard earth that holds shape
  🔸 node_77  | what is rock: rock hard stone from earth
Other Possibilities (food tier @ 2.53):
  🔸 node_115 | what is food: food thing tribe eats to live
  🔸 node_97  | food fills belly and gives strength
  🔸 node_96  | food fills belly and gives strength
Other Possibilities (water/wolf/rocks tier @ 2.50): ...
Generic non-alias (conf=0.60):
  🔸 node_23  | fire dangerous because it bites skin
```

Three fire-alias nodes are exactly tied at 4.83 — that is direct
evidence the multiplier path has been cut. With the old
ActionTonePredictor multiplier in place, three separately-keyed
descriptions of fire would never land at the same float; one of them
would have been kicked up or down by tone alignment.

The `Here is the picture: …` reply consumes the primary claim plus
all 14 unsure side-features as supporting clauses, which is the
intended descriptive-mode behaviour (not anti-match, certainty=UNSURE,
fresh-mem gate eligible=6).

## Reply-quality spot check

| Cycle | Prompt | Conf | Reply head | Read |
|---|---|---|---|---|
| 1 | `/mission` force/accel/mass | 0.31 | "grug make picture in air with words" | Thin generic — sparse subject-lobe specimen, expected baseline |
| 4 | `/mission` acid balances richness | low | "how does" | Thin generic — same cause |
| 9 | `/mission` tell me about fire | **4.83** | full multi-clause claim + 14 supporting clauses | Rich, intended |
| 14 | `/mission` who are you | mid | "grug is grug grug is here grug listen / grug is helper" | Landed correctly on identity lobe |
| 16 | `/mission` the tribe | mid | claim + link + **Pinned note** "Tribe stronger than lone hunter." | Pinned-memory path clean |

The quality split is **structural, not stochastic**: prompts that hit
descriptive-alias or pinned-memory paths produce rich replies; prompts
on the sparse subject lobes produce thin baselines. That is the
expected post-isolation behaviour — there is no longer a side-process
multiplier puffing up otherwise-thin matches.

## Verdict

✅ Confidence-isolation work is stable across fresh runs.
✅ Reply quality on the descriptive / identity / pinned paths is at
the level we want (multi-clause, supported, pinned-note threaded).
✅ Reply thinness on the sparse subject-lobe missions reflects
specimen sparsity, not a regression.
✅ Zero side-process artifacts in 1 169 lines of telemetry.

This is where we wanted to be.
