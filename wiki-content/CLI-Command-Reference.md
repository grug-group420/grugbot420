# CLI Command Reference

Complete reference for all grugbot420 CLI commands.

## Core Commands

| Command | Description |
|---------|-------------|
| `/mission <text>` | Send input to the engine. Main command. Also accepts image binary (Base64/hex). |
| `/wrong` | Penalize every node that voted. Nodes reaching 0 strength become graves. |
| `/explicit <cmd> [<node_id>] <text>` | Force a specific command+node, bypassing the vote system. |
| `/grow <json>` | Plant new nodes from a JSON packet. See [[Action Packet Format]]. |
| `/addRule <rule> [prob=0.0-1.0]` | Add a stochastic orchestration rule. See [[Orchestration Rules]]. |
| `/pin <text>` | Pin text to memory cave wall. Survives the 10,000-message rolling window. |
| `/help` | Print full command reference. |

## Status & Inspection

| Command | Description |
|---------|-------------|
| `/nodes` | Show all nodes: ID, pattern, strength, neighbor count, grave status. |
| `/status` | Full health snapshot: node count, Hopfield cache, memory, lobe summary, subsystem stats. |
| `/arousal <0.0-1.0>` | Set EyeSystem arousal level. Higher = tighter visual attention cutout. |

## Semantic Verbs

| Command | Description |
|---------|-------------|
| `/addVerb <verb> <class>` | Add a verb to a relation class (e.g., `/addVerb triggers causal`). |
| `/addRelationClass <name>` | Create a new verb class bucket. |
| `/addSynonym <canonical> <alias>` | Register synonym normalization. |
| `/listVerbs` | Dump all verb classes, verbs, and synonym mappings. |

## Lobes & Tables

| Command | Description |
|---------|-------------|
| `/newLobe <id> <subject>` | Create a subject partition. Cap: 20,000 nodes/lobe, 64 lobes max. |
| `/connectLobes <id_a> <id_b>` | Link two lobes bidirectionally. 60% decay per hop. |
| `/lobeGrow <lobe_id> <json>` | Grow a node into a specific lobe. |
| `/lobes` | Show all lobes: node counts, connections, fire counts. |
| `/tableStatus <lobe_id>` | Show hash table chunk sizes for a lobe. |
| `/tableMatch <lobe_id> <chunk> <pattern>` | Pattern-activate entries in a lobe's hash table. |

## Thesaurus

| Command | Description |
|---------|-------------|
| `/thesaurus <w1> \| <w2>` | Dimensional similarity: overall, semantic, contextual, associative, confidence %. |
| `/thesaurus <w1> \| <w2> :: <ctx1> :: <ctx2>` | Similarity with context modulation. |

## Negative Thesaurus (Inhibition)

| Command | Description |
|---------|-------------|
| `/negativeThesaurus add <word> [--reason <text>]` | Register inhibited word. |
| `/negativeThesaurus remove <word>` | Remove from inhibition list. |
| `/negativeThesaurus list` | Show all inhibited words. |
| `/negativeThesaurus check <word>` | Check if word is inhibited. |
| `/negativeThesaurus flush` | Clear all inhibitions. |

## Relational Fire (Node Attachments)

| Command | Description |
|---------|-------------|
| `/nodeAttach <target> <id1> <pattern1> [...]` | Attach up to 4 nodes to a target. Patterns support quoted multi-word. |
| `/nodeDetach <target> <attach_id>` | Remove attachment from target. |
| `/imgnodeAttach <target> <img_id> <data> [w] [h]` | Attach image node with SDF conversion. |
| `/imgnodeDetach <target> <img_id>` | Remove image attachment. |
| `/attachments` | Show full attachment map. |

## Specimen Persistence

| Command | Description |
|---------|-------------|
| `/saveSpecimen <filepath>` | Freeze entire cave state to gzip-compressed JSON. |
| `/loadSpecimen <filepath>` | Restore cave state from specimen file. **Destructive** — full brain transplant. |

See [[Specimen Persistence]] for full details on what gets saved.

## Template Tags (for `/addRule`)

| Tag | Expands To |
|-----|-----------|
| `{MISSION}` | Current input text |
| `{PRIMARY_ACTION}` | Winning action |
| `{SURE_ACTIONS}` | Sure basket actions |
| `{UNSURE_ACTIONS}` | Unsure actions |
| `{ALL_ACTIONS}` | All proposed actions |
| `{CONFIDENCE}` | Vote confidence |
| `{NODE_ID}` | Winning node ID |
| `{MEMORY}` | Recent memory context |
| `{LOBE_CONTEXT}` | Active lobe state |
| `{VOTE_CERTAINTY}` | `SURE` or `UNSURE` |
| `{TIED_ALTERNATIVES}` | Non-winning tied actions |
