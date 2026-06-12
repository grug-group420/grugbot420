# GrugBot /coder Mode — Future Design Notes

## Concept
- New module: `Coder` — activated via `/coder` command
- Enters a dedicated Grug phase for pseudocode → execution
- No AIML orchestration needed — once step-wise logic is handled, it goes straight through
- "Vibe coding with no waiting"

## Architecture
- **Training**: Grug trained on nothing but C pseudocode
- **Thesaurus**: Maps C constructs → bash equivalents (translation layer)
- **Dual routing**: Low-level ops → native memory directly | High-level ops → batch/bash
- **One-pass parse**: Pseudocode converted ONE time, both execution paths available simultaneously
- **C as universal pivot**: Every language maps to C-adjacent constructs, so C pseudocode becomes the universal translation hub

## Thesaurus Mappings (C → Bash)
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

## Lobes (planned)
- memory_ops, control_flow, io_ops, data_structures, syscalls, types, functions, concurrency

## Sigil Kinds (planned)
- `:pseudocode_var` — variable declaration patterns
- `:pseudocode_assign` — assignment patterns
- `:pseudocode_call` — function call patterns
- `:pseudocode_loop` — loop constructs
- `:pseudocode_cond` — conditional constructs
- `:pseudocode_func` — function definition patterns

## Key Principle
No AIML orchestration in /coder mode. Step-wise logic handled → straight through to execution. This is what makes it "vibe coding with no waiting."

## Status
FUTURE — not being built now. More pressing matters take priority.
