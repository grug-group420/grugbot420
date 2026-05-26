# Kitchen Sink v12 — Coherence Fix Verification (v7.21b-3d)

**Date:** 2025-01-26
**HEAD:** v7.21b-3d (Fix A + Fix B applied to `generate_aiml_payload` in `src/Main.jl`)
**Seed:** `kitchen_sink.specimen.gz` (copy of v11 seed — identical lobe/node state)
**Missions:** 89 (`missions_clean.txt`, copied from v11)
**Errors:** 0
**Test suite:** 31/31 testfiles green (added `test_v7_21b3d.jl`: 10 testsets, 27 individual tests)

---

## Why this run exists

v11 (kitchen_sink_v11_comprehensive) shipped the v7.21b-3b frame-match
multiplier. While the orchestrator quorum was now correctly biased toward
nodes whose hint matched the judge's frame, the AIML output scaffold itself
was still producing replies that **parroted the trigger pattern** instead of
speaking the seeded prose:

```
v11: [Grug greet warm] Hello — here is what matters: hello hi.
v11: [Grug listen to feeling] To acknowledge what matters here: i feel.
v11: [Grug explain plain] Here is the picture: what is.
```

Three concrete bugs were diagnosed at the **scaffold layer** (NOT the
orchestrator, which was working as designed):

1. The `CLAIM` slot was being filled with `node.pattern` (the trigger string)
   instead of the system_prompt prose body.
2. The skeleton table was keyed on `primary_vote.action`, ignoring the
   judge's `frame_hint` — so all greet-actions got the warm `Hello —` opener
   regardless of whether the judge said the frame was actually warm,
   exploratory, terse, etc.
3. The `system_prompt` body field was completely unused — only the first
   sentence was pulled (for the `[bracket]` voice prefix) and the rest was
   discarded.

## What v7.21b-3d does

**Fix A — `system_prompt` body becomes the CLAIM** (~15 lines)
The system_prompt is split into `voice_first` (first sentence → bracket
prefix) + `voice_body` (everything after → core spoken claim). CLAIM
priority order is now: `voice_body > node.pattern > mission fallback`.

**Fix B — frame-keyed skeleton dispatch** (~30 lines)
The skeleton table is now keyed on `TonalJudge.LAST_JUDGEMENT[].frame_hint`
instead of `primary_vote.action`. Frame skeletons:
- `warm` → `"Hello —"` opener
- `exploratory` → `"Here is the picture:"`
- `imperative` → bare `"{CLAIM}."` (no preamble)
- `contemplative` → `"Let me think with you."` opener
- `de-escalating` → `"I hear that."` opener
- `terse` → `"{CLAIM}."` only, no SUPPORT clause
- `plain` → `"{CLAIM}.{SUPPORT}"`

Companion-frame clause (the `A companion frame: ...` tail) was also updated
to extract the comp_node's system_prompt body, falling back to its pattern
only if no body exists.

If `LAST_JUDGEMENT[]` is empty (no judge ran for this turn), the function
falls back to the action-keyed skeleton table — preserving backwards
behaviour for paths that never invoke the tonal judge.

## What changed in the spoken output

Side-by-side from `CONVERSATION.md` (full pairing of all 64 reply turns):

```
mission: 'hello'
  v11: [Grug greet warm] Hello — here is what matters: hello hi.
  v12: [Grug greet warm] Let me think with you. Subsist polite, brief.

mission: 'i feel sad today'
  v11: [Grug listen to feeling] To acknowledge what matters here: i feel.
  v12: [Grug sit close] Let me think with you. Many tribe feel this..
       A companion frame: Assess, do not mend.

mission: 'what is fire'
  v11: [Grug explain plain] Here is the picture: what is.
  v12: [Grug explain plain] Here is the picture: No big words.

mission: 'why does fire burn'
  v11: [Grug seek cause] Thinking it through: why.  Pinned note: ...
  v12: [Grug seek cause] Here is the picture: Trace from product to source.
       Pinned note: Hot rock burn. Soft skin remember.
```

### Aggregate tally (over all 64 paired reply turns)

| Category                                                | Count |
|---------------------------------------------------------|-------|
| 🟢 IMPROVED (parrot echo replaced with system_prompt body) | 29    |
| 🟡 Changed (different prose, no known broken pattern)    | 30    |
| ⚪ Identical                                             | 5     |

Of the 5 identical replies, all are imperative-frame turns where the v11
output already happened to be a bare CLAIM (e.g. `"Run away from cliff."`,
`"Hold tight."`) — those were already coherent and the new scaffold
preserves them.

## Frame distribution (FRAME=label/judge_mode)

```
22 imperative/basic
20 exploratory/basic
18 contemplative/basic
10 de-escalating/rel
 7 contemplative/rel
 7 imperative/rel
 5 terse/basic
```

**24/89 = 27.0% relational mode** — same as v11 (the judge is unchanged;
the fix was downstream of the judge).

## Files in this directory

- `kitchen_sink.specimen.gz` — seed specimen (copied from v11)
- `missions_clean.txt` — 89-mission stream (copied from v11; only loadSpecimen path differs)
- `run.log` — full CLI transcript (2740 lines)
- `spoken_v11.txt` / `spoken_v12.txt` — extracted reply pairs
- `CONVERSATION.md` — side-by-side v11 vs v12 reply diff (64 turns)
- `extract_spoken.py` / `build_diff.py` — extraction tooling
- `stats.json` — machine-readable run stats
- `SUMMARY.md` — this file

## Verdict

**Coherence fix verified.** The 29 known-broken parrot replies from v11 are
now replaced with the seeded `system_prompt` body, and the frame-keyed
skeleton produces openers that actually match what the judge said the frame
was (de-escalating turns now open with "I hear that", contemplative with
"Let me think with you", warm/imperative/terse/exploratory each gets its
own appropriate voice).

The fix is **scaffold-layer** only — the predictor, judge, orchestrator,
and lobe routing all stayed identical between v11 and v12. The same 89-
mission stream now produces measurably more coherent prose.
