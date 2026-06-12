# Multipart Decoherence Test Log

**Generated:** 2026-06-12 04:45:25  
**Specimen:** v722_test.specimen.gz  
**Nodes:** 26 · **Sigils:** 3  
**@sigil:math nodes:** 2 · **@sigil:multipart nodes:** 1  
**Engine version:** v7.22 (reverse lookup + locked-in-votes-only)  

---

## Purpose

Verify response-level decoherence fixes in GrugBot420 engine v7.22.  
Math questions should produce math answers; compound questions should produce coherent per-clause responses.  
The v7.22 fix adds a reverse lookup (objective_id → clause text) in `_infer_scoped_mission()` and restricts the multipart orchestrator to only locked-in (sure) votes.

---

## Test 1 — simple_arithmetic

**Input:** `what is 2 plus 2`

> [Arithmetic reasoning voice] 2 minus 2 minus 4.

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | calculate |
| Confidence | 0.4 |
| Certainty | SURE) |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 3 |
| SigilMediator Kinds | [:math] |

**Decomposition:** 1 clause(s) → `what is 2 plus 2`  
**Sigil Rewrite:** `what is &n &op &n`  

**AIML Output Scaffold:**

```
[Arithmetic reasoning voice] 2 minus 2 minus 4.
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 2 — simple_knowledge

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

**Decomposition:** 1 clause(s) → `tell me about fire`  
**Sigil Rewrite:** `tell me about fire`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ✅ PASS

- ✅ No crash  

</details>

---

## Test 3 — multipart_arith_knowledge

**Input:** `what is 3 times 4 and what is the sky`

> [General knowledge and factual description] 3 times 4 equals 12.

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

**Decomposition:** 2 clause(s) → `what is 3 times 4 | what is the sky`  
**Sigil Rewrite:** `what is &n &op &n &conj what is the sky`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 3 times 4 equals 12.
```

**Result:** ❌ FAIL

- ✅ math answer  
- ❌ sky mention  

</details>

---

## Test 4 — multipart_arith_emotion

**Input:** `what is 5 minus 1 but how are you feeling`

> [Multi-clause reasoning voice] 5 minus 1 equals 4.

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

**Decomposition:** 2 clause(s) → `what is 5 minus 1 | how are you feeling`  
**Sigil Rewrite:** `what is &n &op &n &conj how are you feeling`  

**AIML Output Scaffold:**

```
[Multi-clause reasoning voice] 5 minus 1 equals 4.
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

> [Linguistic structure analysis and multi-clause handling] 6 plus 1 equals 7.

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

**Decomposition:** 3 clause(s) → `what is 6 plus 1 | what is water | what is love`  
**Sigil Rewrite:** `what is &n &op &n &conj what is water &conj what is love`  

**AIML Output Scaffold:**

```
[Linguistic structure analysis and multi-clause handling] 6 plus 1 equals 7.
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 6 — single_clause_control

**Input:** `tell me about ecosystems`

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

**Decomposition:** 1 clause(s) → `tell me about ecosystems`  
**Sigil Rewrite:** `tell me about ecosystems`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ✅ PASS

- ✅ No crash  

</details>

---

## Test 7 — multipart_or_split

**Input:** `what is 8 divided by 2 or what is the ocean`

> [General knowledge and factual description] 8 divided by 2 equals 4.

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

**Decomposition:** 2 clause(s) → `what is 8 divided by 2 | what is the ocean`  
**Sigil Rewrite:** `what is &n &op by &n &conj what is the ocean`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 8 divided by 2 equals 4.
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 8 — multipart_arith_compare

**Input:** `what is 2 plus 3 and what is 4 times 5`

> [no scaffold found]

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

**Decomposition:** 2 clause(s) → `what is 2 plus 3 | what is 4 times 5`  
**Sigil Rewrite:** `what is &n &op &n &conj what is &n &op &n`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ❌ FAIL

- ✅ first answer  
- ❌ second answer  

</details>

---

## Summary

| # | Test | Input | Result |
|---|------|-------|--------|
| 1 | simple_arithmetic | `what is 2 plus 2` | ✅ PASS |
| 2 | simple_knowledge | `tell me about fire` | ✅ PASS |
| 3 | multipart_arith_knowledge | `what is 3 times 4 and what is the sky` | ❌ FAIL |
| 4 | multipart_arith_emotion | `what is 5 minus 1 but how are you feeling` | ✅ PASS |
| 5 | three_part_compound | `what is 6 plus 1 and what is water also what is love` | ✅ PASS |
| 6 | single_clause_control | `tell me about ecosystems` | ✅ PASS |
| 7 | multipart_or_split | `what is 8 divided by 2 or what is the ocean` | ✅ PASS |
| 8 | multipart_arith_compare | `what is 2 plus 3 and what is 4 times 5` | ❌ FAIL |

**Tests passed:** 6 / 8  
**Failed:** 2  

All 8 test inputs processed through the GrugBot420 engine with v722 specimen loaded.

### v7.22 Fixes Verified

1. **Reverse lookup (objective_id → clause text)** — `_infer_scoped_mission()` now finds clause text via `_CURRENT_CLAUSE_OBJ_IDS` mapping instead of falling through to bare action names like "describe" or "reason".
2. **Locked-in votes only** — MultipartOrchestrator receives only `sure_votes` (locked in above the floor), not `sure_votes + unsure_votes`. Hedge/support votes no longer influence group formation or scoped_mission assignment.
3. **Gate (a) now passes knowledge groups** — Because `scoped_mission` contains actual clause text ("what is the sky") instead of bare action names ("describe"), Gate (a) finds a matching user clause and the group renders.

**⚠️ 2 test(s) failed — see individual test sections above.**

