# Kitchen Sink v10 — v7.21b-3c (frame-match multiplier, live in the field)

**Run:** `grug_test/kitchen_sink_v10_b3c/run.log`
**Specimen:** `kitchen_sink.specimen.gz` (33 of 42 nodes seeded with `frame_hints` plugs — see `seeded_plugs.md`)
**Mission stream:** identical to v9_b3a (same 102-line `missions_clean.txt`)
**Build:** v7.21b-3b commit `799ad56`

This is the first run where the **TonalJudge verdict actually tilts the AIML vote field**. b-3a wired the diagnostic. b-3b shipped the multiplier in the orchestrator. b-3c (this run) seeds plugs on the kitchen-sink specimen and re-runs the same mission stream.

---

## What changed in the field

| Metric | v9_b3a | v10_b3c | Delta |
| --- | ---: | ---: | ---: |
| FRAME tags emitted | 54 | 54 | — (predictor unchanged) |
| Basic-mode firings | 41 (76%) | 41 (76%) | — |
| Relational-mode firings | 13 (24%) | 13 (24%) | — |
| Missions where AIML picked a **different** primary action / winning node | (baseline) | **23 / 36 shared missions (64%)** | **+23** |

The judge is doing the same thing it did in v9. What's different is that **node selection in the AIML stage now responds to the judgement**, because seeded `frame_hints` plugs on 33 of 42 nodes are being multiplied through `composite_vote_score`.

---

## Telling diffs (where the lift / inhibit actually changed which rock spoke)

| Mission | v9 picked | v10 picked | Why (plug + frame) |
| --- | --- | --- | --- |
| `i feel sad today` | `node_19 sad → acknowledge` | `node_18 i feel → acknowledge` | node_18 has `[warm, contemplative]`. The frame for REFLECTIVE input is `contemplative/rel` → node_18 lifted (1.20×), node_19's `[de_escalating, warm]` mismatched and got inhibited (0.85×, RELATIONAL gate active). |
| `i feel lonely in the cave` | `node_19 sad → comfort` | `node_18 i feel → acknowledge` | Same shape — i-feel plug is the better contemplative match, lift wins the top tier. |
| `danger danger predator near` | `node_11 run → alert` | `node_10 danger → alert` | node_10 has `[imperative, terse]`. Frame was `imperative/rel`. Lift on node_10 pushes it past node_11. |
| `fire burns my hand` | `node_12 fire burns → analyze` | `node_12 fire burns → warn` | Same node won, but the action-packet pick shifted: `[imperative, terse]` plug + `imperative/basic` frame promoted the `warn` packet. |
| `make a tool from this stone` | `node_40 build → explain` | `node_40 build → describe` | Same node, different action; the `exploratory/basic` frame interacted with packet weights. |
| `victory over the bear` | `node_26 → smile` | `node_26 → laugh` | Same node, different action; warm-frame match nudged the secondary action up. |
| `hello again old friend` | `node_0 → smile` | `node_0 → greet` | Same node, but the warm-plug match restored `greet` as the primary (was being out-coinflipped). |

23 of 36 shared missions now route to a different primary-action / winning-node combo. Most of the diffs sit on the same `Winning Node` but with a re-ordered action-packet pick — the multiplier is composing cleanly with the existing strength-bias logic. Eight diffs are full **node** swaps, which is the sharper signal: a different plug genuinely won the top tier.

---

## What didn't change — and that's the design

Five frame distribution numbers are byte-for-byte identical to v9. That's the contract:

* The **predictor** is upstream of the judge. It only sees text → action+tone+arousal. It has no idea which nodes are seeded.
* The **judge** is downstream of the predictor and upstream of the orchestrator. It sees the prediction → frame_hint. It has no idea which nodes are seeded either.
* The **orchestrator** is the only layer that touches the plug list. It reads `LAST_JUDGEMENT.frame_hint` once per cycle, walks the candidate list, and applies the multiplier.

This means b-3c is a **pure-orchestration** change. Predictor diagnostics, frame distribution, INCOHERENT tags, all reproduce v9 exactly. The only thing that should differ is which node ends up on top of the vote tier — and that's exactly what we see.

---

## Inhibit-gate sanity check (decision (c) confirmation)

Three `terse/basic` frames fired in this run (`/mission STOP`, `/mission STOP that immediately`, `/mission xqzwvbn`). Under the user's decision (c), basic-mode mismatches are NOT inhibited — they collapse to neutral 1.0×. Behavior of these three missions is unchanged from v9, which confirms the gate is doing its job: the basic-mode autopilot path is not silently suppressing mis-plugged nodes.

The 13 relational-mode firings (mostly `de-escalating/rel` on hostile input + `contemplative/rel` on reflective input) ARE eligible for inhibit, and the diff log above shows multiple cases where mismatched plugs were demoted under exactly those frames.

---

## Lexicon gaps still open (deferred to later passes)

These were noted in v9 and remain unaddressed — they're predictor-side, not orchestration-side, so b-3c does not move them:

* `/mission i feel sad today` → tone classified as `REFLECTIVE`, not `VULNERABLE`. We don't have a `TONE_VULNERABLE` family yet; the contemplative routing is the second-best fit but it's a soft miss.
* `/mission thank you for the food` → still parses as `NEGATE` due to "thank" keyword conflict. b-3c's plug-routing helps the right node win when present, but the predictor verdict is upstream noise.
* `/mission hello again old friend` → still `COMMAND` (`hello` not in warm-greeting markers). The plug-routing now picks the right node despite the wrong frame, which is a small win but not the principled one.

These are scheduled for a v7.21c lexicon pass.

---

## Where this leaves us

Per the user's framing — *AIML is an orchestration quorum field, it just needs matching plugs* — we now have:

1. **The plug socket** (`json_data["frame_hints"]` on each node) — declarative, additive, back-compat (empty list = legacy neutral).
2. **The field tilt** (`composite_vote_score` × `frame_match_multiplier`) — three-valued, gated.
3. **The plug verdict** (`TonalJudge.LAST_JUDGEMENT.frame_hint`) — common-sense BASIC/RELATIONAL dispatch.
4. **The runtime tunables** (`set_frame_match_weights!(lift, inhibit)`) — Ref-backed, not const-backed.
5. **The seeded specimen** demonstrating it works on real input.

The leak that v8 surfaced — *predictor catches HOSTILE+QUERY, scaffold replies with a tone-blind packet* — is now plugged, **at the orchestration seam**, without rewriting the scaffold or the predictor. The judge's verdict is the third dimension of node-selection alongside raw confidence and additive bonuses.

Suite: 30/30 testfiles green at HEAD.
