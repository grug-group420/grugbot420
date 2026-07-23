# GrugBot420 Dynamic Sigil Actions

## Problem: /answer :math creates static per-instance nodes instead of dynamic sigil action nodes
- Current: `/answer :math the factorial of 6 is 720` → creates ONE dead node for "the factorial of 6 is 720"
- Goal: `/answer @mathematics :action factorial factorial of &n` → creates a DYNAMIC sigil action node that computes ANY factorial
- Action sigils can do ANYTHING — the node pattern uses sigil holes (&n, &word), bindings carry values, and an action_callback computes the result at match time

## Architecture Plan
- [x] 1. Design the `:action` mode for `/answer` — user-facing syntax
- [x] 2. Add _compute_action callback system — Julia functions that compute from bindings
- [x] 3. Register built-in math actions (factorial, square, square_root, double, half, negate, cube, absolute, reciprocal, fibonacci)
- [x] 4. Wire `/answer :action` to create sigil nodes with action callbacks
- [x] 5. Wire ActionEngine to check action_callbacks when sigil node fires (in generate_aiml_payload)
- [x] 6. Update claim_raw priority chain — action_compute_reply at priority 0a (above arithmetic_reply at 0b)
- [x] 7. Register action sigil patterns in specimen seeds (Phase 4.5 of load_specimen)
- [x] 8. Test: "factorial of 5" → computes 120 dynamically (PASS)
- [x] 9. Test: "double 7" → computes 14 dynamically (PASS)
- [x] 10. Add dynamic action sigil nodes to generate_specimen.py
- [x] 11. Add noun_anchors to action seed nodes (fix coherence warning)
- [x] 12. Deliver final MD log
