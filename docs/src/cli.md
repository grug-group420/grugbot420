# CLI Reference

Launch GrugBot420 with `julia Main.jl` (standalone) or `GrugBot420.main()` (from the module). You'll see the `Brain >` prompt.

## Core Commands

| Command | Description |
|---------|-------------|
| `/mission <text>` | Send input to the engine (main command) — exempt from immune gates |
| `/wrong` | Penalize only contributing nodes (fired) from the last response |
| `/right` | Secondary reinforcement: contributors get another coinflip chance to gain strength |
| `/explicit <cmd> [<node_id>] <text>` | Force a specific command+node, bypassing votes |
| `/grow <json>` | Plant new nodes from a JSON packet — immune gated (critical) |
| `/addRule <rule> [prob=X]` | Add a stochastic orchestration rule — immune gated |
| `/pin <text>` | Pin text permanently to the memory cave wall — immune gated |

## Status & Inspection

| Command | Description |
|---------|-------------|
| `/nodes` | Show all nodes with ID, pattern, strength, neighbors, grave status |
| `/status` | Full system health snapshot |
| `/arousal <0.0-1.0>` | Set the EyeSystem arousal level |

## Semantic Verbs

| Command | Description |
|---------|-------------|
| `/addVerb <verb> <class>` | Add a verb to a relation class — immune gated |
| `/addRelationClass <name>` | Create a new verb class bucket — immune gated |
| `/addSynonym <canonical> <alias>` | Register a synonym normalization — immune gated |
| `/listVerbs` | Dump all verb classes and synonyms |

## Lobes & Tables

| Command | Description |
|---------|-------------|
| `/newLobe <id> <subject>` | Create a new subject partition — immune gated |
| `/connectLobes <id_a> <id_b>` | Link two lobes bidirectionally — immune gated |
| `/lobeGrow <lobe_id> <json>` | Grow a node into a specific lobe — immune gated (critical) |
| `/lobes` | Show all lobes |
| `/tableStatus <lobe_id>` | Show hash table chunk sizes |

## Thesaurus

| Command | Description |
|---------|-------------|
| `/thesaurus <w1> \| <w2>` | Dimensional similarity comparison |
| `/negativeThesaurus add <word>` | Inhibit a word from input scanning — immune gated |
| `/negativeThesaurus remove <word>` | Remove a word from inhibition list |
| `/negativeThesaurus list` | Show all inhibited words |
| `/negativeThesaurus check <word>` | Check if a word is inhibited |
| `/negativeThesaurus flush` | Clear all inhibitions |

## Relational Fire (Node Attachments)

| Command | Description |
|---------|-------------|
| `/nodeAttach <target> <id1> <pattern1> [...]` | Attach up to 4 text nodes to a target with connector patterns (middleman reasons). Confidence JIT-baked at attach time. Quoted multi-word patterns supported. — immune gated |
| `/nodeDetach <target> <id>` | Remove a specific text attachment from a target node |
| `/imgnodeAttach <target> <id> <b64> [w h]` | Attach an image node to a target with SDF-based relational fire. Image→SDF conversion at attach time (JIT GPU accel). Width/height optional (default 8×8). — immune gated |
| `/imgnodeDetach <target> <id>` | Remove a specific image attachment from a target node |
| `/attachments` | Show the full attachment map (all targets, attached nodes, base_confidence) |

When the target node fires during `scan_and_expand`, each attached node does a strength-biased coinflip. Winners get their connector pattern (middleman) scanned against the **attached node's own pattern** — not the target's — to determine voting confidence. The connector pattern also surfaces as generative context explaining WHY the relay fired. The active cap (biological attention bottleneck) is respected. See the Relational Fire System section in the project README for full details.

## Specimen Persistence

| Command | Description |
|---------|-------------|
| `/saveSpecimen <path>` | Freeze entire cave state to gzip JSON (includes attachments) |
| `/loadSpecimen <path>` | Restore cave state from specimen file (includes attachments) — immune gated (critical) |

## Vote Certainty & Tie-Breaking

When multiple nodes reach the same confidence, the orchestrator resolves ties randomly rather than always picking the first sorted result.

The response output includes a **Vote Certainty** section at the bottom:

- **SURE** — the winning node had a clear confidence lead (no exact ties)
- **UNSURE** — ties existed; a random winner was picked from the tied group

Tied alternatives (non-selected tied winners) are listed with their node ID, action, confidence, and relational triples. Strong runner-ups (unsure votes that survived the coinflip) are listed as "Other Possibilities."

### AIML Rule Tags for Certainty

Two additional tags are available in `/addRule` templates:

| Tag | Expands To |
|-----|-----------|
| `{VOTE_CERTAINTY}` | `SURE` or `UNSURE` |
| `{TIED_ALTERNATIVES}` | Comma-separated tied non-winners with actions and confidence |

Example: `/addRule When certainty is {VOTE_CERTAINTY}, alternatives were: {TIED_ALTERNATIVES} [prob=0.7]`

## Immune System Gate

All commands that store structure are automatically scanned by the immune system before executing. Gates are classified as **critical** (full immune scan) or **standard** (structural scan, lower threshold).

| Severity | Commands |
|----------|---------|
| Critical | `/grow`, `/lobeGrow`, `/loadSpecimen` |
| Standard | `/addRule`, `/pin`, `/addVerb`, `/addRelationClass`, `/addSynonym`, `/newLobe`, `/connectLobes`, `/negativeThesaurus add`, `/nodeAttach`, `/imgnodeAttach` |
| Exempt | `/mission`, `/wrong`, all read-only and remove-only commands |

When the immune system blocks a command:
```
[IMMUNE] ⛔ /grow REJECTED by immune system: Funky input failed patching and was deleted
```

See [README immune system section](https://github.com/grug-group420/grugbot420#specimen-immune-system) for the full pipeline (AST scan → Hopfield memory → quarantine → patch → delete).

## Help

```
/help
```

Prints the full command reference inside the CLI.
