# kitchen_sink_v17_descriptive_votes — v7.21c-5

## Purpose

This release corrects noun-question vote semantics and enforces the architectural rule that side processes must not affect vote confidences. Noun questions such as `what is fire`, `describe fire`, and `tell me about fire` now route to direct noun-description vote actions such as `fire hot and burns wood` instead of generic explanation/share actions.

## User-facing correction

The explicit target was that `what is fire?` should return vote-shaped noun answers like `fire hot and burns wood`. The v17 specimen changes the fire, rock, water, wolf, and food knowledge pools so their `action_packet` entries are direct noun-description candidates rather than generic mood or explanation commands. Exact noun-question aliases are mirrored through knowledge, explanation, and identity lobes so stochastic lobe selection still has direct noun candidates available.

The previously inconsistent forms `tell me about fire` and `tell me about rocks` are now fixed without duplicate config lock-ins or side-process boosting. The engine now treats `tell me about <noun>`, `tell about <noun>`, `describe <noun>`, and `what about <noun>` as core relation-extraction surfaces. This makes `tell me about fire` produce a normal relational triple such as `(tell, about, fire)`, allowing the existing relational matcher to score noun-specific aliases honestly.

## Side-process isolation

The user clarified: side processes should never affect vote confidences. The engine now follows that rule in the primary voting path.

In `src/engine.jl`, ActionTonePredictor remains diagnostic only. The previous confidence multiplier was removed, so scan confidence is now the raw core score:

```julia
confidence = token_conf + rel_conf
```

No ActionTonePredictor, TonalJudge, memory, lobe-routing, timing-ledger, or other auxiliary process multiplies that confidence.

In `src/VoteOrchestrator.jl`, `composite_vote_score` now returns raw confidence only. Optional fields such as lobe alignment, relational match telemetry, action-tone alignment, peak dominance, recency, and frame multipliers remain in the compatibility struct, but they do not alter primary ranking.

In `src/Main.jl`, action-tone alignment and frame multipliers are explicitly neutralized when building vote candidates. They are diagnostic only and cannot lift or suppress a candidate.

In `src/engine.jl`, the slow-response ledger was changed to telemetry-only. Slow averages are logged but no longer mark voting nodes as `GRAVED-SLOW`, preventing response timing from removing future voters.

## Specimen cleanup

Earlier troubleshooting had added duplicate `direct_noun_description_tell_lockin` explanation-lobe nodes to force `tell me about fire/rocks` above the generic built-in node. Those lock-ins were removed. The clean v17 seed now contains 54 normal noun-description alias nodes and 0 tell-lockin duplicates. The rebuilt clean specimen has 126 nodes.

## Verification

Clean-load focused verification passed after side-process isolation and lock-in cleanup:

```text
- mission : 'tell me about fire'
  reply   : [Grug describe fire directly] Here is the picture: fire scares wolf but must stay in ring. The link is clear: say about fire.

- mission : 'tell me about rocks'
  reply   : [Grug describe rock directly] Here is the picture: rock comes from mountain and keeps old memory. The link is clear: converse about rocks.
```

Telemetry confirmed the generic built-in node remained below the noun aliases:

```text
Mission: 'tell me about fire'
Primary Action: fire scares wolf but must stay in ring  (conf=4.83, certainty=UNSURE)
User Triples: (tell, about, fire)
node_13 | action=describe | conf=0.6 | relations=None

Mission: 'tell me about rocks'
Primary Action: rock comes from mountain and keeps old memory  (conf=3.83, certainty=UNSURE)
User Triples: (tell, about, rocks)
node_13 | action=describe | conf=0.6 | relations=None
```

Broad clean-load noun verification also passed. The important examples include:

```text
what is fire        -> fire eats dry grass and grows fast / fire is light that moves and needs food
what is fire again  -> direct fire description
connective describe fire -> fire hot and burns wood
tell me about fire  -> fire hot and burns wood
what is rock        -> rock is sleeping mountain piece in grug hand
what are rocks      -> rock heavy and useful for tool wall and hammer
describe rocks      -> what is rock: rock hard stone from earth
tell me about rocks -> rock hard earth that holds shape
what is water       -> water soft in hand but strong in river
describe water      -> water soft in hand but strong in river
what is wolf        -> wolf dangerous near dark edge of camp
describe wolf       -> wolf fur teeth and hungry eyes
what is food        -> food shared tastes better than food alone
describe food       -> food fills belly and gives strength
```

## Key files

- `specimen_seed.txt` — clean v17 seed generated from v16 with direct noun-description pools and aliases.
- `seed_cmds.txt` — cleaned CLI command stream with `/saveSpecimen kitchen_sink.specimen.gz` and `/quit` appended.
- `kitchen_sink.specimen.gz` — rebuilt clean v17 specimen, 126 nodes.
- `patch_descriptive_votes.py` — v16-to-v17 specimen patcher with duplicate tell-lockins removed.
- `tell_about_clean_after_isolation.log` and `tell_about_clean_after_isolation_spoken.txt` — focused verification for the formerly failing `tell me about` forms.
- `noun_description_clean_after_isolation.log` and `noun_description_clean_after_isolation_spoken.txt` — broad clean-load verification.
