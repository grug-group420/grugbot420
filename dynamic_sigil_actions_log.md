# Dynamic Sigil Actions — Implementation Log

## Problem

The user's exact words: *"sigil actions can be way more dynamic. you could have answered the factorial question with a node that handles all factorials not just one."*

Before this change, `/answer :math the factorial of 6 is 720` created a single static knowledge node — a dead string that only knew one fact. Asking "factorial of 5" would fail because that node only matched "factorial of 6 is 720". The node was a snapshot, not a procedure.

## Solution

Dynamic sigil action nodes. Instead of planting one dead answer per instance, we create a sigil node whose pattern uses sigil holes (`&n`) and whose `action_callback` in `json_data` names a registered compute function. When the pattern matches any input, ActionEngine runs the callback with the current bindings and the computed answer becomes the claim at the highest priority (0a, above even arithmetic).

One node, infinite answers. The cave compresses.

## Architecture

### ActionEngine.jl (NEW)
- Module with `ACTION_CALLBACKS::Dict{String, Function}` registry
- `register_action_callback!(name, fn)` — adds named compute functions
- `compute_action(name, bindings)` — looks up and runs the callback
- `format_action_reply(result)` — converts `ActionResult` to natural language claim
- 10 built-in callbacks: factorial, square, square_root, double, half, negate, cube, absolute, reciprocal, fibonacci
- Each callback: extracts `&n` binding, validates, computes, returns `ActionResult` with `answer_str` (e.g. "factorial of 5 is 120"), step-by-step breakdown, and expression

### Stage 2b Hook (Main.jl generate_aiml_payload)
- NEW block before Stage 2 arithmetic computation
- Reads winning node's `action_callback` from `json_data`
- Gets current promotion bindings (multipart-aware)
- Runs `ActionEngine.compute_action()` with callback name and bindings
- Stores result in `action_compute_result` and reply in `action_compute_reply`
- On error: non-fatal, falls back to normal claim pipeline

### claim_raw Priority Chain (updated)
```
0a. action_compute_reply  — dynamic sigil action computed a result (NEW)
0b. arithmetic_reply      — basic arithmetic computed a result
 1. action_is_prose       — prose action string
 2. voice_body            — system_prompt body sentences
 3. noun_anchors          — topic nouns
 4. node_pattern          — raw pattern (last resort)
```

### /answer :action Mode (Main.jl)
- Syntax: `/answer @mathematics :action <callback_name> <sigil_pattern>`
- Example: `/answer @mathematics :action factorial factorial of &n`
- Validates callback exists in `ActionEngine.ACTION_CALLBACKS`
- Creates sigil node with `action_callback` in json_data, `node_type=:sigil`, NOCHAT, singleton
- Extracts noun_anchors from pattern (non-sigil tokens)
- Assigns to target lobe

### Specimen Seeds (Phase 4.5 of load_specimen)
- 9 action sigil seed nodes auto-created when specimen has none:
  - "factorial of &n" (callback=factorial)
  - "square of &n" (callback=square)
  - "square root of &n" (callback=square_root)
  - "double &n" (callback=double)
  - "half of &n" (callback=half)
  - "cube of &n" (callback=cube)
  - "absolute value of &n" (callback=absolute)
  - "reciprocal of &n" (callback=reciprocal)
  - "fibonacci of &n" (callback=fibonacci)
- Each seed has noun_anchors extracted from pattern, terse voice_register, imperative frame_hints

### generate_specimen.py (updated)
- Added 9 action sigil node definitions to `SIGIL_NODE_DEFS`
- Updated `make_node` to accept `extra_data` parameter (for `action_callback`, `is_math_node`)
- Updated sigil node builder to derive `:action` kind from "dynamic" in noun_anchors
- Fixed `drop_table` to include `@sigil:{kind}` tag when `sigil_kind` is set

## How It Works End-to-End

1. User types "factorial of 5"
2. SigilPromoter rewrites to "factorial of &n" with binding `&n=5`
3. Voting: "factorial of &n" pattern node (node_265) gets perfect lexical overlap → confidence 1.0
4. generate_aiml_payload Stage 2b: reads `action_callback="factorial"` from node_265's json_data
5. ActionEngine.compute_action("factorial", [SigilBinding(n=5)]) → factorial(5)=120
6. format_action_reply → "factorial of 5 is 120"
7. claim_raw priority 0a: action_compute_reply wins → output: "Thinking it through: factorial of 5 is 120."

Next time user asks "factorial of 7", the SAME node_265 fires and computes 5040. One node, infinite answers.

## Test Results

### Direct ActionEngine Tests (all PASS)
| Callback | Input | Answer | Reply |
|----------|-------|--------|-------|
| factorial | 5 | 120 | "factorial of 5 is 120" |
| factorial | 0 | 1 | "factorial of 0 is 1" |
| factorial | 1 | 1 | "factorial of 1 is 1" |
| square | 7 | 49 | "7 squared is 49" |
| double | 7 | 14 | "double of 7 is 14" |
| half | 10 | 5 | "half of 10 is 5" |
| cube | 3 | 27 | "3 cubed is 27" |
| fibonacci | 10 | 55 | "fibonacci of 10 is 55" |
| square_root | 49 | 7 | "square root of 49 is 7" |
| absolute | -5 | 5 | "absolute value of -5 is 5" |
| reciprocal | 4 | 0.25 | "reciprocal of 4 is 0.25" |

### Full Pipeline Tests (all PASS)
| Input | Expected | Node | Confidence | Output |
|-------|----------|------|------------|--------|
| "factorial of 5" | 120 | node_265 | 1.0 | "factorial of 5 is 120" |
| "factorial of 7" | 5040 | node_265 | 1.0 | "factorial of 7 is 5040" |
| "square of 9" | 81 | node_266 | 1.0 | "9 squared is 81" |
| "cube of 3" | 27 | node_270 | 1.0 | "3 cubed is 27" |
| "double 7" | 14 | node_268 | 1.0 | "double of 7 is 14" |
| "fibonacci of 10" | 55 | node_273 | 1.0 | "fibonacci of 10 is 55" |

**Dynamic proof**: factorial(5) and factorial(7) both fire node_265 — the same node computes different answers from different bindings. One node, infinite answers.

## Files Modified

1. **src/ActionEngine.jl** — NEW: dynamic action evaluator module with 10 built-in callbacks
2. **src/engine.jl** — Added ActionEngine include/using block
3. **src/Main.jl** — Three changes:
   - Stage 2b action computation block in generate_aiml_payload
   - action_compute_reply at priority 0a in claim_raw chain
   - /answer :action mode handler
   - Action sigil seed nodes in Phase 4.5 of load_specimen (with noun_anchors)
4. **generate_specimen.py** — Added action sigil nodes, extra_data parameter, dynamic drop_table
