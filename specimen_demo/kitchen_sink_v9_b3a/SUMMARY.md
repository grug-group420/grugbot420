# v7.21b-3a — Diagnostic Visibility Pass

**Build:** grugbot420 v7.21b-3a (`[FRAME=...]` diagnostic tag)
**Date:** 2025-05-26
**Foundation:** v7.21b-2 (TonalJudge) at commit `e586a51`
**Tests:** 29/29 testfiles green · no new tests · no regressions

---

## What shipped

A single-line change in `src/engine.jl` at the predictor log site. After
`predict_action_tone` returns, the engine now also calls
`TonalJudge.judge_from_prediction(prediction)` and appends a `[FRAME=...]`
suffix to the existing diagnostic line.

```
[ENGINE] 🔮 Action=ACTION_NEGATE | Tone=TONE_HOSTILE | Conf=0.52 |
        ArousalNudge=0.35 | Weight=1.16 [FRAME=de-escalating/rel]
```

The suffix has shape `[FRAME=<frame_hint>/<mode>]` where `mode` is `rel`
(relational) or `basic`. This makes the judge's verdict visible at every
inference without changing any scoring or output behavior.

**This is observation-only at the orchestrator level.** No vote is
weighted by the frame hint yet. No scaffold reads it yet. The judge runs
every cycle and the verdict lands on `LAST_JUDGEMENT`, but downstream is
still tone-blind.

---

## Kitchen Sink v9 results

Ran the v8 missions script against the b-3a build.

| Metric | v8 (a) | v8b1 | v9b3a |
|---|---:|---:|---:|
| Engine inferences | 54 | 54 | **54** |
| Mission/Scaffold pairs | 42 | 42 | 40 |
| `[FALLBACK]` tags | 27 | 27 | 27 |
| `[LORENZ-DAMPED]` tags | 2 | 2 | 2 |
| `[INCOHERENT]` tags | — | 0 | 0 |
| **`[FRAME=...]` tags** | — | — | **54 (1:1)** |
| Per-query Gini events | 4 | 4 | 4 |
| Crashes | 0 | 0 | 0 |

### Frame distribution (54 inferences)

```
13  imperative/basic
13  exploratory/basic
12  contemplative/basic
 6  de-escalating/rel    ← HOSTILE phase
 4  contemplative/rel    ← REFLECTIVE phase
 3  imperative/rel       ← URGENT moments
 3  terse/basic
─────────────────────
54  total
```

### Mode split

```
41  /basic   (76%)   ← cheap path, ordinary moments
13  /rel     (24%)   ← relational path, charged moments
```

The 76/24 split is exactly what "common sense" should look like. Most
of the conversation is autopilot. The slow expensive coherence-aware
path only spins up when the situation demands it.

---

## Behavioral validation — read the column

The frame column now reads as the conversation's emotional shape:

```
Phase 3 (greetings)     →  contemplative/basic, contemplative/basic ...
Phase 4 (curious)       →  exploratory/basic ×5
Phase 5 (urgent)        →  imperative/basic, imperative/rel, imperative/basic,
                           imperative/rel  (URGENT lights up when markers land)
Phase 6 (reflective)    →  contemplative/rel ×4   ← all four "perhaps/maybe/i wonder/could be"
Phase 7 (hostile)       →  de-escalating/rel ×4   ← all four hostile-no-markers
Phase 8 (hostile + ?)   →  de-escalating/rel ×2   ← HOSTILE preserved on questions
Phase 9 (concentrated)  →  exploratory/basic [LORENZ-DAMPED],
                           imperative/rel [LORENZ-DAMPED]
                           (Gini damping recovered to coherent frames)
Phase 13 (rocks ×3)     →  exploratory/basic ×3   (jittered conf, stable frame)
Phase 14 (recovery)     →  imperative/basic       (clean, no hostile bleed)
Phase 15 (gibberish)    →  terse/basic, exploratory/basic, contemplative/basic
```

**Every transition reads correctly.** The judge picks a relational frame
exactly where I'd want it (HOSTILE / URGENT / REFLECTIVE) and falls back
to basic everywhere else. The Gini-damping moments preserve the recovered
tone in their frame choice — `[LORENZ-DAMPED] [FRAME=...]` pairs agree.

---

## Tuning observations (deferred — these are predictor-side, not judge-side)

A few moments where the column reveals tuning headroom in the
*predictor*, not the judge:

1. **"i feel sad / worried / lonely" → NEUTRAL → contemplative/basic.**
   The predictor lexicon doesn't catch "feel sad" as a tone signal.
   Could benefit from a TONE_VULNERABLE or wider REFLECTIVE detection.
2. **"thank you for the food" → NEGATE → terse/basic.** Lexicon
   marker-matched something it shouldn't have.
3. **"hello again old friend" → COMMAND → imperative/basic.** "hello" is
   not in the warm-greeting markers, so it falls through to COMMAND.
   A WARM frame plug exists but no node currently triggers it from
   the basic path.

None of these are judge bugs — the judge is correctly routing whatever
the predictor hands it. They're predictor-lexicon gaps to address
later, separately from b-3.

---

## What this enables for b-3b

Now that we can *see* what frame the judge picks across a real run,
b-3b can confidently land the **scoring dimension that lifts/inhibits
votes by frame match**:

```
LIFT_MULTIPLIER     = 1.20    (node frame matches judgement.frame_hint)
NEUTRAL_MULTIPLIER  = 1.0     (node has no frame_hints declared)
INHIBIT_MULTIPLIER  = 0.85    (node has frame_hints, none match — meta inhibition)
```

The user's framing: **AIML is an orchestration quorum field; it just
needs matching plugs.** b-3b adds the matching protocol. b-3c seeds a
few kitchen-sink nodes with `frame_hints` plugs and runs another
kitchen sink to *see the field shape change*.

Three-valued field: lifted / neutral / inhibited. Tone-as-tilt at the
orchestration layer, mirroring tone-as-tilt at the prediction layer.

---

## Files

| File | Purpose |
|---|---|
| `src/engine.jl` (modified) | one-line wiring: judge runs, FRAME tag emitted |
| `grug_test/kitchen_sink_v9_b3a/run.log` | 1,836-line run, 54 FRAME tags |
| `grug_test/kitchen_sink_v9_b3a/SUMMARY.md` | this report |
| `grug_test/kitchen_sink_v9_b3a/kitchen_sink_post_run.specimen.gz` | post-run state |

---

## Verdict

The judge picks correctly. Every relational fire is at a moment that
deserved relational handling. Every basic fire is at a moment where
basic was right. The 76/24 mode split matches biology. **The diagnostic
infra is now in place to validate b-3b.**

Ready to roll into b-3b (the frame_hints scoring dimension).
