# Kitchen Sink v18b — Confidence-Isolation Verification Run

**Specimen:** `kitchen_sink.specimen.gz` (copy of v17 descriptive-votes specimen, 126 nodes / 16 lobes).
**Conversation script:** `conversation.txt` (21 live commands, 16 missions).
**Raw log:** `conversation_raw.log` (1 170 lines, 100 KB).
**Formatted transcript:** `conversation.md` (16 cycles).
**Engine state at run:** `main` @ commit `7df04a3` (post v7.21c-5 isolation work + SelfObserver merge).

---

## What this run was for

This is a plain conversation with the engine — no synthetic driver, no bespoke harness — to **eyeball-verify the v7.21c-5 confidence-isolation work**:

- **ActionTonePredictor confidence multiplier** removed.
- **VoteOrchestrator composite-rerank** neutralized to raw confidence.
- **Slow-response graving** turned into telemetry only.
- **Duplicate tell-about config lock-ins** removed.
- **Noun-question relations** added as core parsing.

The expected signature in the captured telemetry: vote confidences should fall into **flat tiers by structural cause** (`token_conf + rel_conf`), with NO sign of `tone_align`, `frame_mult`, `TonalJudge`, `ActionTonePredictor`, composite reranking, or `GRAVED-SLOW` events.

---

## Headline result — clean

| Side-process artifact searched | Occurrences in 1 170-line log |
|---|---:|
| `tone_align` | **0** |
| `frame_mult` | **0** |
| `TonalJudge` | **0** |
| `ActionTonePredictor` | **0** |
| `composite` | **0** |
| `GRAVED-SLOW` | **0** |

Side processes are not present in the telemetry, let alone modifying confidence.

---

## The conversation

16 missions in three groups:

### Group A — Subject-lobe missions (snap-back vs far-jump)
| # | Cmd | Mission | Primary action | conf | certainty |
|---:|---|---|---|---:|---|
| 1 | `/mission` | explain how force relates to acceleration and mass | use word friend already know to teach word friend not know | **0.50** | SURE |
| 2 | `/brainstorm` | (same) | use word friend already know to teach word friend not know | **0.50** | SURE |
| 3 | `/mission` | explain how acid balances richness in a heavy dish | explain | **0.49** | UNSURE |
| 4 | `/brainstorm` | (same) | break big thing into rocks small enough to carry | **0.49** | SURE |
| 5 | `/mission` | describe how melody and harmony work together | what is rock: rock hard stone from earth | **2.28** | UNSURE |
| 6 | `/brainstorm` | (same) | water flows downhill and fills bowl | **2.28** | UNSURE |
| 7 | `/mission` | reason about fairness when cases look similar but feel different | water soft in hand but strong in river | **0.31** | SURE |
| 8 | `/brainstorm` | (same) | wolf hunts in pack and listens to pack | **0.31** | SURE |

### Group B — Direct noun-description prompts (tests the v7.21c-5 alias path)
| # | Cmd | Mission | Primary action | conf | certainty |
|---:|---|---|---|---:|---|
| 9 | `/mission` | tell me about fire | fire eats dry grass and grows fast | **4.83** | UNSURE |
| 10 | `/mission` | what is rock | rock under foot can help or trip grug | **4.74** | UNSURE |
| 11 | `/mission` | describe water | water can save thirst or pull grug under | **5.00** | UNSURE |
| 12 | `/mission` | tell about wolf | wolf is hunger with legs and song | **4.79** | UNSURE |
| 13 | `/mission` | what is food | food is earth changed into body strength | **4.95** | UNSURE |

### Group C — Self / culture prompts (pinned-memory path)
| # | Cmd | Mission | Primary action | conf | certainty |
|---:|---|---|---|---:|---|
| 14 | `/mission` | who are you | grug is helper not master | **2.79** | SURE |
| 15 | `/mission` | what do you do | grug peel layer until heart show | **1.00** | UNSURE |
| 16 | `/mission` | the tribe | what is tribe if not promise to not be alone | **1.00** | SURE |

---

## Why these confidence values are the proof

Every single distinct `conf=` value seen across the entire log:

```
0.31  0.49  0.50  0.53  0.60  0.70  0.79  1.00
2.14  2.27  2.28  2.33  2.36  2.38  2.39  2.40  2.50  2.53  2.55  2.60  2.79
4.73  4.74  4.79  4.83  4.95  5.00
```

These cluster into clear structural tiers:

- **~0.30–0.50** — bare token-overlap matches against off-topic nodes. (`token_conf` only, `rel_conf=0`.)
- **~0.60–1.00** — token + weak triple match.
- **~2.14–2.79** — token + 2-3 triple matches (the descriptive vote pools when prompted with off-topic queries; the words "describe / what is" still match the alias triples).
- **~4.73–5.00** — direct noun-description hit: the alias node's pattern (`"tell about fire"` etc.) matches the input verbatim AND the noun-anchor relation triples all match. This is exactly what the v7.21c-5 spec defined as the alias path.

**The plateaus are flat.** Cycle 9 (`/mission tell me about fire`) shows three winning fire-description nodes all at `conf=4.83`, then a tier of rock/food/water/wolf nodes at `2.55 / 2.53 / 2.50`, then a single generic-fire node at `0.60`. If a tone or frame multiplier were still in play, those plateaus would not be flat — sibling nodes with identical pattern + relation matches would be perturbed by side scores.

The fact that the rendered tier diagram is this clean is the visible signature that **vote confidence is now strictly `token_conf + rel_conf` and nothing else**.

---

## Cycle 9 in detail (the cleanest single example)

`/mission tell me about fire` produced this telemetry block:

```
Primary Action: fire eats dry grass and grows fast  (conf=4.83, certainty=UNSURE)
Tied Alternatives (not selected):
  node_100 | action=fire dangerous because it bites skin       | conf=4.83 | relations=(tell, about, fire), (tell, about, fire), (fire, is, described)
  node_67  | action=fire hot and burns wood                    | conf=4.83 | relations=(tell, about, fire), (tell, about, fire), (fire, is, described)
Other Possibilities:
  node_105 | action=rock can cut when sharp and crush when heavy| conf=2.55 | relations=(tell, about, rock), …
  node_76  | action=rock heavy and useful for tool wall and hammer| conf=2.55 | relations=(tell, about, rock), …
  node_97  | action=food is meat root fruit and berry          | conf=2.53 | relations=(tell, about, food), …
  node_96  | action=food fills belly and gives strength        | conf=2.53 | relations=(tell, about, food), …
  …
  node_23  | action=fire is light that moves and needs food    | conf=0.60 | relations=(fire, makes, heat), (fire, cooks, meat), (fire, scares, wolf), (fire, eats, wood)
```

Three fire-description alias nodes tied at exactly `conf=4.83`. The tie-break went to NONJITTER + coinflip (no multiplier nudged the result). Other-noun alias nodes formed two perfectly flat sibling tiers (2.55 and 2.53) ordered by noun anchor. The generic non-alias `fire` node sat far below at `0.60` — the alias path is doing exactly what it was designed to.

---

## What didn't happen (and that's the point)

- Slow-response telemetry never produced `GRAVED-SLOW` events. (The slow-graving change is hard to verify directly here because no node was actually slow — but the codepath is no longer reachable from this surface, and the absence of any "telemetry only" markers tells us no node tripped the threshold either.)
- No `Tonal*` or `ActionTone*` strings appear anywhere in the raw log.
- No "composite" rerank text appears anywhere in the raw log.
- All 16 cycles completed without a single SYSTEM ERROR.

---

## Reproduction

```sh
cd grugbot420_repo
grep -v '^\s*#' specimen_demo/kitchen_sink_v18b_isolation_check/conversation.txt \
  | grep -v '^\s*$' > /tmp/conv.txt
julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' < /tmp/conv.txt \
  > specimen_demo/kitchen_sink_v18b_isolation_check/conversation_raw.log 2>&1
python3 specimen_demo/format_conversation.py \
  specimen_demo/kitchen_sink_v18b_isolation_check/conversation_raw.log \
  specimen_demo/kitchen_sink_v18b_isolation_check/conversation.md
```

Expected: exit 0, ~1170-line raw log, 16 formatted cycles, zero side-process artifacts when grepped for `tone_align|frame_mult|tonejudge|actiontone|composite|graved-slow`.

---

## Files in this directory

- `kitchen_sink.specimen.gz` — copy of the v17 descriptive-votes specimen used for the run.
- `conversation.txt` — the input script (21 lines, 16 missions).
- `conversation_raw.log` — full CLI transcript captured by `run_cli()`.
- `conversation.md` — formatted markdown transcript (16 cycles, expandable telemetry).
- `SUMMARY.md` — this document.
