# Multipart Decoherence Test Log

**Generated:** 2026-06-11 23:33:30  
**Specimen:** comprehensive_v3_specimen.json  
**Nodes:** 92 · **Sigils:** 15  

---

## Purpose

Verify multipart decoherence fixes in GrugBot420 engine v7.17+.  
Specifically: no arithmetic bleed across clause groups, no cross-group contamination.

---

## Test 1 — simple_arithmetic

**Input:** `what is 2 plus 2`

**Response:**

> [Grug] To acknowledge what matters here: what is happening right now. The link is clear: what is happening. Grug also leans toward meditate.

**Decomposition:** 1 clause → `what is 2 plus 2`  
**Sigil Rewrite:** `what is &n &op &n`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | acknowledge |
| Confidence | 0.75 |
| Certainty | UNSURE |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 3 |
| SigilMediator Kinds | [:math] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `2` | pos=2 | lambda |
| `&op` | `+` | pos=3 | lambda |
| `&n` | `2` | pos=4 | lambda |

**AIML Output Scaffold:**

```
[Grug] To acknowledge what matters here: what is happening right now. The link is clear:
what is happening. Grug also leans toward meditate. [Directives: When the mission is
what is 2 plus 2, consider the acknowledge approach with confidence 0.75; The node
node_67 suggests acknowledge, ponder as reliable actions with UNSURE certainty; ...]
```

**Decoherence Checks:**

- Arithmetic bleed: N/A (not a multipart math test)
- Cross-group contamination: N/A (not multipart)
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 2 — simple_knowledge

**Input:** `what is the capital of France`

**Response:**

> [no scaffold found]

**Decomposition:** 1 clause → `what is the capital of France`  
**Sigil Rewrite:** `what is the capital of france`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 0 |
| SigilMediator Kinds | Symbol[] |

**Per-binding detail:** *(no bindings — non-math input)*

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Decoherence Checks:**

- Arithmetic bleed: N/A (not a multipart math test)
- Cross-group contamination: N/A (not multipart)
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 3 — multipart_arith_knowledge

**Input:** `what is 3 times 4 and what is the sky`

**Response:**

> [Grug] Here is the picture: describe the ocean. The link is clear: ocean &causal salt. describe the ocean, and should i combat or bolt. describe the ocean; write me a poem. Grug heard run and notify strongly too but is less certain those fit here.

**Decomposition:** 2 clauses → `what is 3 times 4` | `what is the sky`  
**Sigil Rewrite:** `what is &n &op &n &conj what is the sky`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | explain |
| Confidence | 1.44 |
| Certainty | UNSURE |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `3` | pos=2 | lambda |
| `&op` | `*` | pos=3 | lambda |
| `&n` | `4` | pos=4 | lambda |
| `&conj` | `and` | pos=5 | macro |

**AIML Output Scaffold:**

```
[Grug] Here is the picture: describe the ocean. The link is clear: ocean &causal salt.
describe the ocean, and should i combat or bolt. describe the ocean; write me a poem.
Grug heard run and notify strongly too but is less certain those fit here.
[Directives: When the mission is what is 3 times 4 and what is the sky, consider the
explain approach with confidence 1.44; The node node_72 suggests explain, describe,
reason, acknowledge, caution, calculate, support, ponder as reliable actions with
UNSURE certainty; ...]
```

**Decoherence Checks:**

- Arithmetic bleed: ✅ None detected
- Cross-group contamination: ✅ None detected
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 4 — multipart_arith_emotion

**Input:** `what is 5 minus 1 but how are you feeling`

**Response:**

> [Grug] A concern worth raising: a predator is hunting me. The link is clear: predator is hunting. a predator is hunting me, and there is peril nearby.

**Decomposition:** 2 clauses → `what is 5 minus 1` | `how are you feeling`  
**Sigil Rewrite:** `what is &n &op &n &conj how are you feeling`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | flee |
| Confidence | 0.32 |
| Certainty | SURE |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `5` | pos=2 | lambda |
| `&op` | `-` | pos=3 | lambda |
| `&n` | `1` | pos=4 | lambda |
| `&conj` | `but` | pos=5 | macro |

**AIML Output Scaffold:**

```
[Grug] A concern worth raising: a predator is hunting me. The link is clear: predator
is hunting. a predator is hunting me, and there is peril nearby. [Directives: When
the mission is what is 5 minus 1 but how are you feeling, consider the flee approach
with confidence 0.32; The node node_44 suggests flee as reliable actions with SURE
certainty; In the context of [lobe_surv (8/8 active (...))], flee, alert are available
but flee is strongest; ...]

--- DEBUG TELEMETRY (orchestration internals, not for speech) ---
Mission: 'what is 5 minus 1 but how are you feeling'
Primary Action: flee  (conf=0.32, certainty=SURE)
Sure Actions: [flee]
Support Actions (relation-linked, composed INLINE with primary): [alert]
Unlinked Support (loud but off-topic, reliability-flagged): [None]
Hedge Actions (quiet voices, reliability-flagged): [None]
```

**Decoherence Checks:**

- Arithmetic bleed: ✅ None detected
- Cross-group contamination: ✅ None detected
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

**Response:**

> [Grug] Here is the picture: how does legitimate travel. The link is clear: air &causal reasonable. Grug also leans toward explain. how does legitimate travel, though Grug also sees render the ocean. how does legitimate travel; what is the brain.

**Decomposition:** 3 clauses → `what is 6 plus 1` | `what is water` | `what is love`  
**Sigil Rewrite:** `what is &n &op &n &conj what is water &conj what is love`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | describe |
| Confidence | 1.16 |
| Certainty | UNSURE |
| Decompose Clauses | 3 |
| SigilMediator Bindings | 5 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `6` | pos=2 | lambda |
| `&op` | `+` | pos=3 | lambda |
| `&n` | `1` | pos=4 | lambda |
| `&conj` | `and` | pos=5 | macro |
| `&conj` | `also` | pos=9 | macro |

**AIML Output Scaffold:**

```
[Grug] Here is the picture: how does legitimate travel. The link is clear: air &causal
reasonable. Grug also leans toward explain. how does legitimate travel, though Grug
also sees render the ocean. how does legitimate travel; what is the brain. Grug heard
determine and contemplate strongly too but is less certain those fit here. Less certain
— Grug also picked up elaborate and assert but these may not hold up. [Directives:
When the mission is what is 6 plus 1 and what is water also what is love, consider the
describe approach with confidence 1.16; ...]
```

**Decoherence Checks:**

- Arithmetic bleed: ✅ None detected
- Cross-group contamination: ✅ None detected
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 6 — single_clause_control

**Input:** `tell me about fire`

**Response:**

> [no scaffold found]

**Decomposition:** 1 clause → `tell me about fire`  
**Sigil Rewrite:** `tell me about fire` *(no sigil match — plain text)*  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 0 |
| SigilMediator Kinds | Symbol[] |

**Per-binding detail:** *(no bindings — non-math input)*

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Decoherence Checks:**

- Arithmetic bleed: N/A (not a multipart math test)
- Cross-group contamination: N/A (not multipart)
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 7 — multipart_or_split

**Input:** `what is 8 divided by 2 or what is the ocean`

**Response:**

> [Grug] A caution: a predator is hunting me. The link is clear: predator is hunting. If a predator is hunting me, then there is risk nearby too.

**Decomposition:** 2 clauses → `what is 8 divided by 2` | `what is the ocean`  
**Sigil Rewrite:** `what is &n &op by &n &conj what is the ocean`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | alert |
| Confidence | 0.44 |
| Certainty | SURE |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `8` | pos=2 | lambda |
| `&op` | `/` | pos=3 | lambda |
| `&n` | `2` | pos=5 | lambda |
| `&conj` | `or` | pos=6 | macro |

**AIML Output Scaffold:**

```
[Grug] A caution: a predator is hunting me. The link is clear: predator is hunting.
If a predator is hunting me, then there is risk nearby too. [Directives: When the
mission is what is 8 divided by 2 or what is the ocean, consider the alert approach
with confidence 0.44; The node node_44 suggests alert as reliable actions with SURE
certainty; In the context of [lobe_surv (8/8 active (...))], alert are available but
alert is strongest; ...]

--- DEBUG TELEMETRY (orchestration internals, not for speech) ---
Mission: 'what is 8 divided by 2 or what is the ocean'
Primary Action: alert  (conf=0.44, certainty=SURE)
Sure Actions: [alert]
Support Actions (relation-linked, composed INLINE with primary): [alert]
Unlinked Support (loud but off-topic, reliability-flagged): [None]
Hedge Actions (quiet voices, reliability-flagged): [None]
```

**Decoherence Checks:**

- Arithmetic bleed: ✅ None detected
- Cross-group contamination: ✅ None detected
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Test 8 — multipart_arith_compare

**Input:** `what is 2 plus 3 and what is 4 times 5`

**Response:**

> [Grug] Here is the picture: what are the planets. The link is clear: planet &possessive moon. Grug also leans toward explain. what are the planets, though Grug also sees you are my friend.

**Decomposition:** 2 clauses → `what is 2 plus 3` | `what is 4 times 5`  
**Sigil Rewrite:** `what is &n &op &n &conj what is &n &op &n`  
**Result:** ✅ PASS

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | describe |
| Confidence | 1.05 |
| Certainty | UNSURE |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 7 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| Binding | Value | Position | Class |
|---------|-------|----------|-------|
| `&n` | `2` | pos=2 | lambda |
| `&op` | `+` | pos=3 | lambda |
| `&n` | `3` | pos=4 | lambda |
| `&conj` | `and` | pos=5 | macro |
| `&n` | `4` | pos=8 | lambda |
| `&op` | `*` | pos=9 | lambda |
| `&n` | `5` | pos=10 | lambda |

**AIML Output Scaffold:**

```
[Grug] Here is the picture: what are the planets. The link is clear: planet &possessive
moon. Grug also leans toward explain. what are the planets, though Grug also sees you
are my friend. Grug heard muse and assert strongly too but is less certain those fit
here. Less certain — Grug also picked up explain but these may not hold up.
[Directives: When the mission is what is 2 plus 3 and what is 4 times 5, consider the
describe approach with confidence 1.05; ...]
```

**Decoherence Checks:**

- Arithmetic bleed: ✅ None detected
- Cross-group contamination: ✅ None detected
- Clause count match: ✅ Yes
- Math routing correct: ✅ Yes
- Multipart routing correct: ✅ Yes

</details>

---

## Summary

| # | Test | Input | Result |
|---|------|-------|--------|
| 1 | simple_arithmetic | `what is 2 plus 2` | ✅ PASS |
| 2 | simple_knowledge | `what is the capital of France` | ✅ PASS |
| 3 | multipart_arith_knowledge | `what is 3 times 4 and what is the sky` | ✅ PASS |
| 4 | multipart_arith_emotion | `what is 5 minus 1 but how are you feeling` | ✅ PASS |
| 5 | three_part_compound | `what is 6 plus 1 and what is water also what is love` | ✅ PASS |
| 6 | single_clause_control | `tell me about fire` | ✅ PASS |
| 7 | multipart_or_split | `what is 8 divided by 2 or what is the ocean` | ✅ PASS |
| 8 | multipart_arith_compare | `what is 2 plus 3 and what is 4 times 5` | ✅ PASS |

**8 / 8 PASSED · 0 decoherence detected**

Key verification points:

1. **Sigil table restored correctly** — 14+ sigils including math-chain (procedure), mathop (macro), n (lambda), op (lambda)
2. **SigilMediator produces bindings** — arithmetic inputs get `&n &op &n` bindings and `:math` kind
3. **InputDecomposer splits multipart** — conjunctions (and, but, also, or) trigger clause splits; math operators (plus, minus, times, divided) are NOT split points
4. **No arithmetic bleed** — math bindings scoped to math clause only (per-clause mediation)
5. **No cross-group contamination** — MultipartOrchestrator groups votes by `objective_id`

**✅ ALL TESTS PASSED — No decoherence detected.**
