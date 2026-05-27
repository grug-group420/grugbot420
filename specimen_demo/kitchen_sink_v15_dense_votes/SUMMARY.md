# Kitchen Sink v15 — DENSE VOTE POOLS

**Release tag:** v7.21c-3 (config-only — no engine changes from v7.21c-2)

## Directive driving this release

> "youre not making votes descriptive enough. a vote pool should just be a
> variety of the same explanationss in various wordings with varying inhibitions.
> the idea is that. a vote not only sets the tone it also is a directive."
> — user, the day v15 was conceived

A vote in the action_packet is **not just a verb** — it is a **directive plus a
voicing**. The previous kitchen_sink_v14_prose specimen demonstrated that the
v7.21c-2 engine can route prose-slot actions correctly, but each knowledge node
only had 3–4 slots. That is too thin: the variety layer (thesaurus swap +
phrase reorder) had nothing wide to compose against, so two visits to the same
node produced near-identical replies.

**v15 fixes the configuration, not the engine.** Every node in the demo carries
**8–12 prose slots**, each a complete rewording of the node's core idea, each
in a distinct tonal register, each carrying paired-opposite inhibitions that
keep the slot in its lane.

## Tonal register palette used per node

| register | example slot for "fire" |
|---|---|
| DECLARATIVE | `fire is hot rock that bites and dances` |
| METAPHOR    | `fire is angry sun caught inside wood` |
| FUNCTIONAL  | `fire eats wood and breathes black smoke` |
| SENSORY     | `flame is hungry tongue that licks the night` |
| TERSE       | `fire warm tribe scare wolf cook meat` |
| CAUTIONARY  | `careful fire bite worse than wolf` |
| REVERENT    | `fire is gift from sky kept alive by tribe` |
| NARRATIVE   | `first fire came from lightning long ago` |
| INTERROGATIVE | `what is fire if not sun made small and angry` |

Each slot ships with a **paired-opposite inhibition list**, e.g.
`[tame, gentle, cold, harmless]` for the DECLARATIVE fire slot, so that slot
will not fire when the input frame conflicts with its lane.

## Build

- 13 lobes × 42 nodes seeded (62 total after merging with default specimen).
- `seed_build.log`: 0 FATALs, 0 unknown actions.
- All 9 nodes that v14 had as single-verb stubs (`good job`, `hunt tomorrow`,
  `build cave`, `remember when`, `forgot`, `make tool`, `stop`, `i did it`,
  `we made fire`) were promoted to dense prose pools matching the
  knowledge-lobe density.

## Mission run results (89 missions → 66 spoken replies)

The variety produced is the proof. A few highlights from `spoken_v15.txt`:

```
[Grug warn fire]    flame eats wood and breathes black smoke.
[Grug know fire]    Here is the picture: It dies and fire is friend that must be fed.
[Grug know fire]    Breathes black smoke and fire eats wood.       ← phrase reorder
[Grug know rock]    rock is patient bone of mountain.
[Grug know wolf]    Fur, wolf is teeth, and yellow eye.             ← phrase reorder
[Grug know river]   river carry boat carry fish carry song downstream.
[Grug know sky]     sky is roof of cave that has no walls.
[Grug know food]    meat from hunt root from dig fruit from reach.
[Grug know hammer]  weight in give teach more than ten lessons.    ← thesaurus: hand→give
[Grug know tree]    careful tree fall sudden when wind angry.
[Grug know tree]    tree make shade nut and wood for fire.

[Grug halt]         stop now think later.
[Grug halt]         what hurry can outrun consequence of bad step.
[Grug plan hunt]    sharp spear tonight save tribe tomorrow.
[Grug plan shelter] many hand make cave one hand make grave.
[Grug plan shelter] floor before roof roof before paint.
[Grug make tool]    what is tool if not promise hand make to future hand.

[Grug weigh path]   best plan flex when wind change.               ← original slot
[Grug weigh path]   best design flex when wind change.             ← thesaurus swap
[Grug weigh path]   best notion flex when wind change.             ← thesaurus swap

[Grug rejoice]      tonight the cave will be warm because of you.
[Grug sit with you] grug hear you grug stay near.
[Grug shelter you]  grug here grug not leave.
```

## What v15 proves

1. **Pool density × variety layers compose.** A 9-slot pool surfaces 3–4
   distinct slot phrasings across a mission set, and each surface gets the
   thesaurus swap (≈25%) + phrase reorder (≈40%) on top, multiplying
   apparent-uniqueness without bloating the seed file.
2. **A vote IS a directive.** Each slot's surface form steers the spoken
   register (declarative/metaphor/cautionary/...). The bot doesn't pick a
   verb and improvise — it picks a complete sentence-shape and renders it.
3. **Paired-opposite inhibitions keep slots in lane.** Tame-fire inhibitions
   on the bites-and-dances slot prevent it from firing in calm contexts; the
   reverent slot has its own counter-inhibitions, etc. No cross-talk.
4. **Engine stayed put.** v7.21c-2 already supported prose action names with
   per-slot inhibitions and conservative variety gates. v15 is purely a seed
   re-author. **No engine changes.** No regressions.

## Files

- `specimen_seed.txt` — the 13-lobe / 42-node dense-pool seed (192 lines,
  ~34 KB).
- `seed_cmds.txt` — comments-stripped seed + /saveSpecimen + /quit (88 lines).
- `seed_build.log` — clean build trace.
- `kitchen_sink.specimen.gz` — pre-run specimen (62 nodes, 14 lobes).
- `missions_clean.txt` — 146-line mission script (carried over from v14).
- `run.log` — full mission run trace.
- `spoken_v15.txt` — 66 mission/reply pairs extracted by `extract_spoken.py`.
- `kitchen_sink_post_run.specimen.gz` — post-run specimen with arousal /
  trajectory / hopfield / morph cooldown deltas baked in.

## Comparison vs v14

| metric | v14 prose | v15 dense |
|---|---|---|
| knowledge lobe slots / node | 3–4   | 9–11 |
| invalid-verb stubs          | 0     | 0    |
| FATALs in build             | 0     | 0    |
| distinct phrasings / mission topic | 1–2 | 3–4 |
| engine commits              | v7.21c-2 | v7.21c-2 (unchanged) |

v14 was the proof-of-concept that the engine handles prose. v15 is the proof
that the user's "common sense" directive — fill pools wide — produces
visibly richer talk for free.
