# ActionScript Conditional Ops — Design Document

## Current State
- 4 ops: REPEAT, SAY, RESOLVE, COMPUTE
- All linear/sequential — no branching
- Static actions: SAY(fixed text) — no slots, no branching
- Dynamic actions: template with {{slots}} — slots filled at runtime, but execution is still linear

## New Operations

### Conditional Ops (Dynamic Only)
These branch based on runtime values. Only valid in `:dynamic` action_type entries.

1. **IF(predicate, then_expr, else_expr)**
   - Classic ternary conditional
   - predicate is a boolean expression (one of the comparison ops below)
   - then_expr and else_expr are operation chains
   - Example: `IF(EQUALS({{target}}, "date"), SAY(Today is RESOLVE(date)), SAY(I don't know what that is))`
   - else_expr is optional — if omitted, returns empty string when predicate is false

2. **WHEN(predicate, then_expr)**
   - Shorthand for IF with no else branch
   - If predicate is true, evaluate then_expr; otherwise return empty string
   - Example: `WHEN(PRESENT({{count}}), REPEAT({{target}}, {{count}}))`

3. **UNLESS(predicate, then_expr)**
   - Inverse of WHEN — evaluate only when predicate is FALSE
   - Example: `UNLESS(EMPTY({{target}}), SAY(RESOLVE({{target}})))`

### Predicate Ops (Return Boolean, Used Inside IF/WHEN/UNLESS)
These don't produce output — they return true/false for the conditional ops to test.

4. **EQUALS(a, b)**
   - String equality test after both sides are evaluated
   - Example: `EQUALS({{target}}, "now")`

5. **CONTAINS(haystack, needle)**
   - Substring test after evaluation
   - Example: `CONTAINS(RESOLVE(recent), "weather")`

6. **PRESENT(expr)**
   - True if the evaluated expression is non-empty and not a fallback string
   - Fallback strings: "(no recent context available)", "(deep memory trace unavailable)", etc.
   - Example: `PRESENT(RESOLVE({{target}}))`

7. **EMPTY(expr)**
   - Inverse of PRESENT
   - Example: `EMPTY({{target}})`

8. **HAS(ref_keyword)**
   - Tests whether a RESOLVE reference returns meaningful content
   - Similar to PRESENT(RESOLVE(x)) but more semantic
   - Example: `HAS(recent)`

9. **GT(a, b)** / **LT(a, b)** / **GTE(a, b)** / **LTE(a, b)**
   - Numeric comparison after evaluation
   - Useful for COMPUTE results or count values
   - Example: `GT({{count}}, 3)`

## Implementation Strategy

The key challenge is that `_eval_op_chain` currently returns `String` everywhere.
Predicates need to return `Bool`, but they're embedded in a string-returning chain.

Solution: Two-tier evaluation.
- `_eval_op_chain(chain)` → `String` (existing, unchanged for backward compat)
- `_eval_predicate(chain)` → `Bool` (new, for IF/WHEN/UNLESS conditions)
- `_eval_any(chain)` → `Union{String, Bool}` (new, for mixed contexts)

When `_eval_op_chain` encounters IF/WHEN/UNLESS, it evaluates the predicate
using `_eval_predicate`, then picks the appropriate branch and continues
evaluating that branch as a string chain.

When `_eval_predicate` encounters EQUALS/CONTAINS/PRESENT/EMPTY/HAS/GT/LT,
it evaluates both sides as strings first, then returns the boolean result.

This keeps the existing string-returning contract intact while adding
conditional branching cleanly.

## Validation Rules
- IF/WHEN/UNLESS only valid in `:dynamic` entries (enforced in `register_action!`)
- Predicates (EQUALS, CONTAINS, etc.) only valid inside conditionals (enforced in `_validate_template`)
- Nested conditionals are allowed: `IF(PRESENT(x), WHEN(EQUALS(x,y), SAY(match)), SAY(no))`

## ACTION_OPS Update
Add to set: IF, WHEN, UNLESS, EQUALS, CONTAINS, PRESENT, EMPTY, HAS, GT, LT, GTE, LTE
