# Kitchen Sink v14 — Prose-Slot Actions (v7.21c-2)

**Date:** 2025-05-26
**HEAD:** v7.21c-2
**Seed:** `kitchen_sink.specimen.gz` — 66 nodes, 14 lobes (knowledge lobe added)
**Missions:** 89 (`missions_clean.txt`, identical to v11/v12/v13 for fair comparison)
**Errors:** 0
**Test suite:** 33/33 testfiles green (added `test_v7_21c2.jl`: 11 testsets, 28 individual tests)

---

## The reframing that cracked v14 open

Three messages from the user reset the entire mental model:

> "when you have a question like what is fire? the action should signal
>  to aiml an explanaition of what fire is. see nodes work like this.
>  2+2=4 they can answer 4. aiml orchestrates all of this into language
>  output. think about what i mean. youre still not using votes properly.
>  votes can be a ton of things be creative and use common sense. 'what
>  is fire?' the nodes voting here should actually explain what fire in
>  in the vote responses"

Then immediately:

> "the system can already do all of this youre configuring things stupidly.
>  think about it"

And the clincher:

> "in other words lets say a node responds to what is fire. the vote
>  should just explain what fire is and then it has an inhibition rule
>  and you just have many slots like this so it doesnt feel static. its
>  very simple what i am saying. an action to take with an inhibition can
>  be anything"

Then two layers were added on top:

> "also AIML should make more use of the thesaurus. the idea is that it
>  replaces random words in the response. random structures. so it
>  doesnt feel static. flowing conversation. aiml = prefrontal cortex
>  quorum. it orchestrattes things into natural language"

> "should be morre conservative yes. also think about this. you can
>  change the ordering of wording too. it doesnt have to mirror the vote
>  in ordering either. i think you know what to do now"

---

## The crystallized insight

`action_packet` slots are not verb labels. They are **answer slots**.

```
old (v13):  "explain^3 | clarify^2 | describe[parrot,echo]^1"
new (v14):  "fire is hot rock that bites and dances^3 |
             fire eats wood and breathes black smoke^3 |
             fire warm tribe scare wolf cook meat^2 |
             fire is sun-thing that lives on ground^1"
```

The engine's `select_action` already supports arbitrary string action names
via `Symbol(name) + bias() + @coinflip`. The `action_packet` parser is
already permissive about whitespace inside slot names. The `[neg1,neg2]`
inhibition syntax already attaches to any slot, so each "answer" can
exclude its own clichés.

**The system already did all of this.** v14 is purely seed reconfiguration
plus three thin engine-side guards that recognize the new pattern.

---

## What v7.21c-2 ships (engine side)

### 1. `ensure_action_packet_registered!` — prose-slot registry

```julia
# engine.jl :: ~3556
function ensure_action_packet_registered!(action_packet::AbstractString)
    for entry in split(action_packet, '|')
        ...
        action_name = String(strip(split(no_brackets, '^')[1]))
        haskey(COMMANDS, action_name) && continue
        is_prose_slot = (length(split(action_name)) >= 2) &&
                        (length(action_name) >= 8)
        if is_prose_slot
            COMMANDS[action_name] = (mission, node, primary_vote,
                                     sure_votes, unsure_votes, all_votes) -> begin
                return Base.invokelatest(generate_aiml_payload, mission,
                                         primary_vote, sure_votes,
                                         unsure_votes, all_votes,
                                         node.json_data)
            end
        else
            error("!!! FATAL: action_packet contains unknown action ...")
        end
    end
end
```

- **Multi-word, ≥8 chars** ⇒ prose answer, auto-register a passthrough
  handler that funnels through `generate_aiml_payload`.
- **Single-word unknown** ⇒ FATAL (typo guard from QoL-2025 BUG-007 is
  preserved).
- Idempotent — re-registering the same prose action is a no-op.
- Called from **two** sites:
  1. `grow_nodes_from_packet` (seed-time)
  2. `load_specimen_from_file!` (restore-time)

The second hook is critical. `COMMANDS` is a runtime dict, not serialized.
Without re-registration on load, every loaded prose-slot node would
`TaskFailedException` at vote time. Found this the hard way during the
first v14 build — kitchen sink ran with 60+ task failures and exactly 17
AIML scaffolds before the load-time hook was added.

### 2. Prose-action becomes top-priority CLAIM

```julia
# Main.jl :: generate_aiml_payload :: ~1985
action_str = String(primary_vote.action)
action_is_prose = length(split(action_str)) >= 2 && length(action_str) >= 8

claim_raw = if action_is_prose
    action_str                                # NEW: prose IS the answer
elseif !isempty(voice_body)                   # c-1: system_prompt body
    voice_body
elseif !isempty(node_pattern) && length(split(node_pattern)) >= 2
    node_pattern                              # legacy v7.16
elseif !isempty(node_noun_anchors)
    "the $(node_noun_anchors[1])"             # c-1: anchor wrap
elseif !isempty(node_pattern)
    node_pattern
else
    "the mission \"$mission\" touches unseeded territory"
end
```

For verb actions (`greet`, `explain`, `flee`...) the priority order from
v7.21c-1 is **unchanged**. Only when the engine picks a prose slot does
the prose itself float to the top.

### 3. Prose-action skeleton degeneracy

```julia
# Main.jl :: ~1925
action_is_prose_skel = length(split(...)) >= 2 && length(...) >= 8
if action_is_prose_skel
    skeleton = "{CLAIM}.{SUPPORT}"            # bare — let prose breathe
end
```

Without this, a prose CLAIM gets wrapped in `"Thinking it through: fire
is hot rock that bites."` which reads as if the engine is narrating its
own surprise at the answer.

### 4. Conservative thesaurus gate (`GRUG_THESAURUS_SWAP_RATE`)

```julia
# Main.jl :: _pick_synonym :: ~1645
swap_rate = parse(Float64, get(ENV, "GRUG_THESAURUS_SWAP_RATE", "0.25"))
if rand() > swap_rate
    return word
end
```

v7.20 routed *every* token through the synonym table. With a beefy
thesaurus (~500 words) that produced `[Grug greet warm] Hi — sun is
ascending, clan amasses` for `"Sun is up, tribe gather"`. Conservative
gate (default **0.25**) trades coverage for naturalness. Override per-run
to dial randomness up or down.

### 5. Phrase reorder layer (`GRUG_PHRASE_REORDER_RATE`)

New function `_reorder_clauses` (default **0.40**):

```julia
# Main.jl :: _reorder_clauses :: ~1728
parts = split(s, r",\s*|\s+and\s+|\s+or\s+")
length(parts) < 2 && return s
sum(length(split(p)) for p in parts) < 4 && return s
shuffle!(parts)
# rejoin "A, B, and C" pattern, preserving head capitalization
```

Multi-clause CLAIMs no longer always speak in seed order. Single-clause
prose passes through unchanged.

---

## Side-by-side: v13 vs v14

The same 89 missions ran against both specimens. Same engine binary
(modulo the four diffs above). The pattern is consistent: **v13 narrates
the answer's shape; v14 just gives the answer**.

| Mission | v13 (schema utilization) | v14 (prose slots) |
|---|---|---|
| `what is fire` | `[Grug explain plain] Here is the picture: No massive words. Show shape of thing first, name it second.` | `[Grug explain plain] Here is the picture: No massive words.` *(short pattern, fell back to verb-action explainer node)* |
| `i did it i made fire` | `[Grug warn of hot rock that bites] Skin remember even if mind forget.` | `[Grug know fire] Breathes black smoke and fire eats wood.` |
| `the sky looks dark` | `[Grug look up] Big blue or grey. Read weather like reading tracks.` | `[Grug know sky] Let me think with you. sky is roof of cave that has no walls. The link is clear: star lives sky.` |
| `the river is high` | `[Grug know water move and life depend on it] Let me think with you. Where river bend, fish gather.` | `[Grug know river] Let me think with you. river is water-snake that never tire. The link is clear: river feeds fish.` |
| `tree` | `[Grug know tree make shade, nut, wood for fire] Tree older than grandfather.` | `[Grug know tree] tree make shade nut and wood for fire.` |
| `fire burns my hand` | (v13 not directly comparable) | `[Grug warn fire] heat steals moisture leaves only ash.` |
| `thank you for the food` | (v13 not directly comparable) | `[Grug know food] Let me think with you. food is gift between earth and tribe. The link is clear: dish feeds tribe.` |

A few things to notice:

1. **Bracket prefix is the persona**, not a description of the answer.
   v13 had `[Grug know water move and life depend on it]` — that was the
   first sentence of the system_prompt being mined for a label. v14
   shortens system_prompt to `"Grug know river."` so the bracket reads
   `[Grug know river]` — clean.

2. **CLAIM is the slot's prose**. v13 sometimes echoed `"tell me"` or
   `"watch out"` — the trigger pattern leaking. v14 either floats the
   prose-slot to top priority OR (when no prose slot fired) uses the
   v7.21c-1 voice_body path exactly as before.

3. **Phrase reorder visible**: `"i did it i made fire"` →
   `"Breathes black smoke and fire eats wood"` is the slot
   `"fire eats wood and breathes black smoke"` shuffled. The conservative
   thesaurus + reorder layers compose into utterance-level variety
   without breaking grammar.

---

## What is intentionally NOT new

- `select_action` was not touched. Prose Symbols flow through
  `bias(Symbol(name), prob)` and `@coinflip` exactly like verb Symbols.
- `parse_action_packet` was not touched. It already accepted whitespace
  in slot names. The grow-time validator was the only blocker.
- The schema dials from v7.21c-1 (`voice_register`, `noun_anchors`,
  `companion_node_pref`, `aux_triples`) all still work and are still
  consumed when the picked slot is a verb-action and the voice_body
  path lights up.
- Test surface: every existing test from v7.16 through v7.21c-1 still
  passes. `test_v7_21c1.jl :: [6] smoke` was given a deterministic
  swap/reorder pin so the assertions on exact body fragments
  (`"Sun is up"` / `"tribe gather"`) aren't flapped by the now-random
  thesaurus.

---

## Test deltas

Added: `test/test_v7_21c2.jl` (11 testsets, 28 individual tests).

| # | testset | what it locks down |
|---|---|---|
| 1 | prose action_packet auto-registers COMMANDS handler | `ensure_action_packet_registered!` actually creates the entry |
| 2 | single-word typo still raises FATAL | BUG-007 typo guard preserved |
| 3 | re-registering same prose action is a no-op | idempotency |
| 4 | prose action becomes top-priority CLAIM | the action_str appears verbatim in spoken line |
| 5 | `GRUG_THESAURUS_SWAP_RATE=0.0` preserves CLAIM verbatim | gate has an off switch |
| 6 | `GRUG_THESAURUS_SWAP_RATE=1.0` still produces valid output | gate has an on switch, doesn't crash |
| 7 | `GRUG_PHRASE_REORDER_RATE=0.0` preserves segment order | reorder has an off switch |
| 8 | `GRUG_PHRASE_REORDER_RATE=1.0` yields permutations across seeds | reorder is actually reordering |
| 9 | short-prose CLAIMs survive reorder=1.0 without corruption | min-tokens guard works |
| 10 | persona-only system_prompt becomes the bracket label | v14 seed shape is round-tripped |
| 11 | prose action survives clean COMMANDS state via re-registration | save/load round-trip safety |

Also patched: `test/test_v7_21c1.jl :: [6]` — added env pins for
deterministic assertion on body fragments.

---

## Files in this directory

| file | what it is |
|---|---|
| `specimen_seed.txt` | the v14 seed file (full /grow + /addRelationClass + /addVerb + /pin) |
| `seed_cmds.txt` | seed file with comments stripped + `/saveSpecimen` + `/quit` (90 cmds) |
| `seed_build.log` | output of piping `seed_cmds.txt` through `run_cli` |
| `kitchen_sink.specimen.gz` | the saved 66-node specimen |
| `missions_clean.txt` | the 89 mission stress-test |
| `run.log` | output of running `missions_clean.txt` against the specimen |
| `extract_spoken.py` | strips AIML scaffold blocks → `(mission, reply)` pairs |
| `spoken_v11.txt` / `spoken_v12.txt` / `spoken_v13.txt` | prior runs for diffing |
| `spoken_v14.txt` | this run, 64 mission/reply pairs |
| `SUMMARY.md` | this document |

---

## Reproducing

```bash
cd grugbot420_repo
julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' \
    < specimen_demo/kitchen_sink_v14_prose/seed_cmds.txt \
    > specimen_demo/kitchen_sink_v14_prose/seed_build.log 2>&1
julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' \
    < specimen_demo/kitchen_sink_v14_prose/missions_clean.txt \
    > specimen_demo/kitchen_sink_v14_prose/run.log 2>&1
python3 specimen_demo/kitchen_sink_v14_prose/extract_spoken.py \
    specimen_demo/kitchen_sink_v14_prose/run.log v14 \
    > specimen_demo/kitchen_sink_v14_prose/spoken_v14.txt
```

To dial the variety knobs at runtime:

```bash
GRUG_THESAURUS_SWAP_RATE=0.10 GRUG_PHRASE_REORDER_RATE=0.20 \
    julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' \
    < missions.txt
```

---

## What's next

The user has now exposed the lever the engine had all along. Open
questions for v7.21d:

1. **Inhibition density** — the v14 seed still uses inhibitions
   sparingly. With prose slots, each slot can be inhibited against its
   own cliché form (`"fire is hot rock that bites^3 [overheat,inferno]"`)
   — could turn that into a per-slot diversity multiplier.
2. **Slot strength dynamics** — currently `^3` / `^2` / `^1` are
   static. Could decay weight on a slot after it fires N times in a
   row to force rotation.
3. **Cross-slot mixing** — pick the head of one slot and the tail of
   another, when they share an anchor noun. Sub-phrase recombination.
4. **Multi-node co-firing** — when "fire" and "wood" both win, weave
   their slots: `fire eats wood` + `wood feeds fire` → `fire and wood
   feed each other`. Would need a new compose pass in
   `generate_aiml_payload`.
