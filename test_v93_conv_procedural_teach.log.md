# V9.3 Conversational Procedural/Math Teaching Test Log

_Generated: 2026-07-08T22:32:59.263_


## Section 1: parse_arith_expr positive cases

- ✅ **PASS**: 'multiply n by 2 and add 1' parses to 2 steps — ops=ArithOpStep[ArithOpStep(:mul, 2.0), ArithOpStep(:add, 1.0)]
- ✅ **PASS**:   step 1 is (:mul, 2.0) 
- ✅ **PASS**:   step 2 is (:add, 1.0) 
- ✅ **PASS**: 'double it then subtract 3' parses to 2 steps — ops=ArithOpStep[ArithOpStep(:mul, 2.0), ArithOpStep(:sub, 3.0)]
- ✅ **PASS**:   step 1 is (:mul, 2.0) [double] 
- ✅ **PASS**:   step 2 is (:sub, 3.0) 
- ✅ **PASS**: 'square it and negate it' parses to 2 steps — ops=ArithOpStep[ArithOpStep(:square, NaN), ArithOpStep(:negate, NaN)]
- ✅ **PASS**:   step 1 is (:square, NaN) 
- ✅ **PASS**:   step 2 is (:negate, NaN) 
- ✅ **PASS**: 'divide by 4' parses to 1 step — ops=ArithOpStep[ArithOpStep(:div, 4.0)]
- ✅ **PASS**:   step 1 is (:div, 4.0) 
- ✅ **PASS**: 'cube it' parses to 1 step (:cube) — ops=ArithOpStep[ArithOpStep(:cube, NaN)]
- ✅ **PASS**: 'half of it' parses to 1 step (:div, 2.0) — ops=ArithOpStep[ArithOpStep(:div, 2.0)]

## Section 2: parse_arith_expr conservative negative cases

- ✅ **PASS**: conservative refusal: vague prose with no arithmetic structure — text='it pulls all the smaller rocks toward it over time' got=nothing
- ✅ **PASS**: conservative refusal: procedure prose using unsupported verbs — text='gather the numbers and combine them somehow' got=nothing
- ✅ **PASS**: conservative refusal: ambiguous partial arithmetic phrase — text='multiply the values together in some order' got=nothing
- ✅ **PASS**: conservative refusal: empty string — text='' got=nothing
- ✅ **PASS**: conservative refusal: just a topic word, no operation — text='math' got=nothing
- ✅ **PASS**: conservative refusal: relational-sounding text (should never be treated as arithmetic) — text='gravity causes objects to fall toward the ground' got=nothing

## Section 3: register_learned_arith_callback! produces working callbacks

- ✅ **PASS**: callback registered 
- ✅ **PASS**: f(5) = 5*2+1 = 11 — got=11.0 error=nothing
- ✅ **PASS**: f(10) = 10*2+1 = 21 (held-out input never seen during 'teaching') — got=21.0
- ✅ **PASS**: f(0) = 0*2+1 = 1 — got=1.0
- ✅ **PASS**: f(-3) = -3*2+1 = -5 — got=-5.0
- ✅ **PASS**: neg_square(4) = -(4*4) = -16 — got=-16
- ✅ **PASS**: neg_square(-3) = -((-3)*(-3)) = -9 — got=-9
- ✅ **PASS**: division-by-zero taught procedure fails gracefully (error set, no crash) — error=computation failed: ErrorException("division by zero") answer=nothing

## Section 4: end-to-end conversational teaching creates a COMPUTABLE action node

- ✅ **PASS**: unknown topic 'gorbling' triggers a clarification/teach prompt — voice='Grug not know 'gorbling'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)'
- ✅ **PASS**: teaching created an :action sigil node for 'gorbling' (not a purely descriptive :procedural node) — action_ids=["node_3"]
- ✅ **PASS**: action node has a non-empty action_callback wired — cb_name='learned_gorbling'
- ✅ **PASS**: learned callback computes gorbling(7) = 7*3-2 = 19 correctly (held-out input) — got=19.0 error=nothing
- ✅ **PASS**: learned callback computes gorbling(100) = 100*3-2 = 298 correctly (held-out input) — got=298.0 error=nothing

## Section 5: non-computable procedure still falls back to descriptive :procedural node

- ✅ **PASS**: non-computable procedure prose does NOT create a computable :action node 
- ✅ **PASS**: non-computable procedure prose DOES fall back to a descriptive :procedural sigil node — proc_ids=["node_4"]

## Summary

**34 / 34 passed** (0 failed)

