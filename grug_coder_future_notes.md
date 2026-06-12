# GrugBot Future Design Notes

---

## 1. /coder Module — C Pseudocode → Dual Execution

**Status**: FUTURE

**Concept**: New module activated via `/coder` — enters a Grug phase for pseudocode → execution.

- **Training**: Grug trained on nothing but C pseudocode
- **Thesaurus**: Maps C constructs → bash equivalents (translation layer)
- **Dual routing**: Low-level ops → native memory directly | High-level ops → batch/bash
- **One-pass parse**: Pseudocode converted ONE time, both execution paths available simultaneously
- **C as universal pivot**: Every language maps to C-adjacent constructs
- **No AIML orchestration**: Once step-wise logic is handled, straight through to execution
- "Vibe coding with no waiting"

**Thesaurus Mappings (C → Bash)**:
| C Construct | Bash Equivalent | Level |
|---|---|---|
| fopen | cat | High |
| fgets | read -r | High |
| fork/exec | & | High |
| regex | grep | High |
| malloc | declare | Low |
| pointer arithmetic | array indexing | Low |
| struct access | variable expansion | Low |
| bitwise ops | arithmetic expansion | Low |
| strcmp | [[ = ]] | Low |
| sprintf | printf/echo | Low |

**Planned Lobes**: memory_ops, control_flow, io_ops, data_structures, syscalls, types, functions, concurrency

---

## 2. Verb-Driven Improvisation — Votes ARE Action Signals

**Status**: FUTURE — core insight captured

**Key Insight**: No new infrastructure needed. The system already has everything.

**Votes = Action Signals**: 
- Verbs already fire votes with class signals
- The verb class IS the routing mechanism
- The vote propagation IS the dispatch
- The action_packet on the catching node IS the execution plan
- Whatever the vote hits *improvs* the response

**How it works — "say pork 200 times"**:
1. Verb "say" fires a vote carrying its class signal
2. "pork" and "200" ride along as bindings in the vote
3. Whatever node catches that vote improvises based on its action_packet
4. The node doesn't need a rigid pattern for "say X N times" — it just needs to know it's a "say" class vote, and it fills in the blanks from the bindings

**The depth comes from vote cascading**:
- One verb vote triggers another node
- That node's vote triggers another
- Multi-step improvisation chains off a single sentence
- Grug doesn't "plan" the improvisation — it *emerges* from vote propagation through the network
- The verb is the seed, the network is the instrument

**Why no new sigil kinds are needed**:
- Verb classes already exist in SemanticVerbs
- Votes already carry action signals
- Sigil nodes already bind patterns for structural matching
- Improvisation doesn't need new structure — it needs *less* structure, more propagation
- The verb IS the sigil kind — it's already in the system, just lean into it harder

**Philosophy**: Don't add layers. Lean into what's already there. The vote cascade IS the improvisation. The deeper the network, the deeper the improv.
