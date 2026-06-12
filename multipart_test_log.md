# Multipart Decoherence Test Log

**Generated:** 2026-06-12 03:15:49  
**Specimen:** comprehensive_v3_specimen.json  
**Nodes:** 95 · **Sigils:** 15  
**@sigil:math nodes:** 2 · **@sigil:multipart nodes:** 1  

---

## Purpose

Verify response-level decoherence fixes in GrugBot420 engine v7.18.
Math questions should produce math answers; compound questions should produce coherent per-clause responses.

---

## Test 1 — simple_arithmetic

**Input:** `what is 2 plus 2`

> [Grug] 2 plus 2 equals 4. [MATH: 2 plus 2 equals 4]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 3 |
| SigilMediator Kinds | [:math] |

**Per-binding detail:**

| `&n` | `2` | pos=2, class=lambda |
| `&op` | `+` | pos=3, class=lambda |
| `&n` | `2` | pos=4, class=lambda |

**Decomposition:** 1 clause(s) → `what is 2 plus 2`  
**Sigil Rewrite:** `what is &n &op &n`  

**AIML Output Scaffold:**

```
[Grug] 2 plus 2 equals 4.
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  

</details>

---

## Test 2 — simple_knowledge

**Input:** `what is the capital of France`

> [Grug] A concern worth raising: a predator is hunting me. 0 eligible=6] (Recent): [Engine_Voice]: Grug ready. Many lobes, many rocks, many bridges. (intensity=0. 42) | [User]: what is 2 plus 2 (intensity=1. 27) | [System]: Mission "what is 2 plus 2" → primary=describe conf=0. 74 node=node_67 (intensity=0. 68). 0 eligible=6] (Recent): [Engine_Voice]: Grug ready. Many lobes, many rocks, many bridges. (intensity=0. 42) | [User]: what is 2 plus 2 (intensity=1. 27) | [System]: Mission "what is 2 plus 2" → primary=describe conf=0. 74 node=node_67 (intensity=0. 68) supports flee with vote certainty SURE for node node_44].

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | flee |
| Confidence | 0.35 |
| Certainty | SURE |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 0 |
| SigilMediator Kinds | Symbol[] |

**Per-binding detail:**


**Decomposition:** 1 clause(s) → `what is the capital of France`  
**Sigil Rewrite:** `what is the capital of france`  

**AIML Output Scaffold:**

```
[Grug] A concern worth raising: a predator is hunting me. 0 eligible=6] (Recent): [Engine_Voice]: Grug ready. Many lobes, many rocks, many bridges. (intensity=0. 42) | [User]: what is 2 plus 2 (intensity=1. 27) | [System]: Mission "what is 2 plus 2" → primary=describe conf=0. 74 node=node_67 (intensity=0. 68). 0 eligible=6] (Recent): [Engine_Voice]: Grug ready. Many lobes, many rocks, many bridges. (intensity=0. 42) | [User]: what is 2 plus 2 (intensity=1. 27) | [System]: Mission "what is 2 plus 2" → primary=describe conf=0. 74 node=node_67 (intensity=0. 68) supports flee with vote certainty SURE for node node_44].
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  

</details>

---

## Test 3 — multipart_arith_knowledge

**Input:** `what is 3 times 4 and what is the sky`

> [Multi-clause reasoning voice] 3 times 4 equals 12. [MATH: 3 times 4 equals 12]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| `&n` | `3` | pos=2, class=lambda |
| `&op` | `*` | pos=3, class=lambda |
| `&n` | `4` | pos=4, class=lambda |
| `&conj` | `and` | pos=5, class=macro |

**Decomposition:** 2 clause(s) → `what is 3 times 4 | what is the sky`  
**Sigil Rewrite:** `what is &n &op &n &conj what is the sky`  

**AIML Output Scaffold:**

```
[Multi-clause reasoning voice] 3 times 4 equals 12.
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  
- ✅ No arithmetic bleed  

</details>

---

## Test 4 — multipart_arith_emotion

**Input:** `what is 5 minus 1 but how are you feeling`

> [no scaffold found]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| `&n` | `5` | pos=2, class=lambda |
| `&op` | `-` | pos=3, class=lambda |
| `&n` | `1` | pos=4, class=lambda |
| `&conj` | `but` | pos=5, class=macro |

**Decomposition:** 2 clause(s) → `what is 5 minus 1 | how are you feeling`  
**Sigil Rewrite:** `what is &n &op &n &conj how are you feeling`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ⚠️ NEEDS REVIEW

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ⚠️ Response coherence (missing: 4, equals)  
- ✅ No arithmetic bleed  

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

> [Grug] 6 plus 1 equals 7. [MATH: 6 plus 1 equals 7]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 3 |
| SigilMediator Bindings | 5 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| `&n` | `6` | pos=2, class=lambda |
| `&op` | `+` | pos=3, class=lambda |
| `&n` | `1` | pos=4, class=lambda |
| `&conj` | `and` | pos=5, class=macro |
| `&conj` | `also` | pos=9, class=macro |

**Decomposition:** 3 clause(s) → `what is 6 plus 1 | what is water | what is love`  
**Sigil Rewrite:** `what is &n &op &n &conj what is water &conj what is love`  

**AIML Output Scaffold:**

```
[Grug] 6 plus 1 equals 7.
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  
- ✅ No arithmetic bleed  

</details>

---

## Test 6 — single_clause_control

**Input:** `tell me about fire`

> [no scaffold found]

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

**Per-binding detail:**


**Decomposition:** 1 clause(s) → `tell me about fire`  
**Sigil Rewrite:** `tell me about fire`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  

</details>

---

## Test 7 — multipart_or_split

**Input:** `what is 8 divided by 2 or what is the ocean`

> [Grug] 8 divided by 2 equals 4. [MATH: 8 divided by 2 equals 4]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| `&n` | `8` | pos=2, class=lambda |
| `&op` | `/` | pos=3, class=lambda |
| `&n` | `2` | pos=5, class=lambda |
| `&conj` | `or` | pos=6, class=macro |

**Decomposition:** 2 clause(s) → `what is 8 divided by 2 | what is the ocean`  
**Sigil Rewrite:** `what is &n &op by &n &conj what is the ocean`  

**AIML Output Scaffold:**

```
[Grug] 8 divided by 2 equals 4.
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  
- ✅ No arithmetic bleed  

</details>

---

## Test 8 — multipart_arith_compare

**Input:** `what is 2 plus 3 and what is 4 times 5`

> [Grug] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20. [MATH: 2 plus 3 equals 5; 4 times 5 equals 20]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | unknown |
| Confidence | 0.0 |
| Certainty | unknown |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 7 |
| SigilMediator Kinds | [:math, :multipart] |

**Per-binding detail:**

| `&n` | `2` | pos=2, class=lambda |
| `&op` | `+` | pos=3, class=lambda |
| `&n` | `3` | pos=4, class=lambda |
| `&conj` | `and` | pos=5, class=macro |
| `&n` | `4` | pos=8, class=lambda |
| `&op` | `*` | pos=9, class=lambda |
| `&n` | `5` | pos=10, class=lambda |

**Decomposition:** 2 clause(s) → `what is 2 plus 3 | what is 4 times 5`  
**Sigil Rewrite:** `what is &n &op &n &conj what is &n &op &n`  

**AIML Output Scaffold:**

```
[Grug] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  
- ✅ No arithmetic bleed  

</details>

---

## Summary

| # | Test | Input | Result |
|---|------|-------|--------|
| 1 | simple_arithmetic | `what is 2 plus 2` | see above |
| 2 | simple_knowledge | `what is the capital of France` | see above |
| 3 | multipart_arith_knowledge | `what is 3 times 4 and what is the sky` | see above |
| 4 | multipart_arith_emotion | `what is 5 minus 1 but how are you feeling` | see above |
| 5 | three_part_compound | `what is 6 plus 1 and what is water also what is love` | see above |
| 6 | single_clause_control | `tell me about fire` | see above |
| 7 | multipart_or_split | `what is 8 divided by 2 or what is the ocean` | see above |
| 8 | multipart_arith_compare | `what is 2 plus 3 and what is 4 times 5` | see above |

**Tests passed:** 7 / 8  
**Needs review:** 1  

All 8 test inputs processed through the GrugBot420 engine with v3 specimen loaded.

### v7.18 Fixes Verified

1. **@sigil:math seed nodes auto-created** — 2 math nodes present after specimen load (was 0 before v7.18)
2. **Per-clause objective_id** — votes stamped with clause-scoped IDs, not one shared ID
3. **Per-clause AIML rendering** — non-primary groups get full COMMANDS rendering with scoped_mission
4. **format_arithmetic_reply in payload** — natural-language math answers instead of bare numbers

**⚠️ 1 test(s) need review — see individual test sections above.**
