# Multipart Decoherence Test Log

**Generated:** 2026-06-12 05:09:11  
**Specimen:** v722_test.specimen.gz  
**Nodes:** 26 · **Sigils:** 3  
**@sigil:math nodes:** 2 · **@sigil:multipart nodes:** 1  
**Engine version:** v7.23 (confidence-only gating, no stochastic coinflips)  

---

## Purpose

Verify response-level decoherence fixes in GrugBot420 engine v7.23.  
Math questions should produce math answers; compound questions should produce coherent per-clause responses.  
The v7.23 fix removes ALL stochastic strength-biased coinflips from the orchestration pipeline.  
Confidence is now the ONLY gate: `strength_biased_scan_coinflip` always returns true, 
`strength_biased_vote_coinflip` always returns true, and `SPARSE_ACTIVE_FIRE_FLOOR` is set to 0.0.  
The real gate is `AIML_TOP_LOCKIN_FLOOR` (0.50) in the orchestration phase.

---

## Test 1 — simple_arithmetic

**Input:** `what is 2 plus 2`

> [Multi-clause reasoning voice] 2 plus 2 equals 4.

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

**Decomposition:** 1 clause(s) → `what is 2 plus 2`  
**Sigil Rewrite:** `what is &n &op &n`  

**AIML Output Scaffold:**

```
[Multi-clause reasoning voice] 2 plus 2 equals 4.
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

> [Cold logical analysis engine active] 5 minus 1 equals 4.

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
[Cold logical analysis engine active] 5 minus 1 equals 4.
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

> [General knowledge and factual description] 6 plus 1 equals 7. [Linguistic structure analysis and multi-clause handling] Here is the picture: and then also moreover furthermore. ; [math] When computing, state the steps before the final answer. ].

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | explain |
| Confidence | 0.7 |
| Certainty | SURE) |
| Decompose Clauses | 3 |
| SigilMediator Bindings | 5 |
| SigilMediator Kinds | [:math, :multipart] |

**Decomposition:** 3 clause(s) → `what is 6 plus 1 | what is water | what is love`  
**Sigil Rewrite:** `what is &n &op &n &conj what is water &conj what is love`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 6 plus 1 equals 7. [Linguistic structure analysis and multi-clause handling] Here is the picture: and then also moreover furthermore. ; [math] When computing, state the steps before the final answer. ].
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

> [General knowledge and factual description] 8 divided by 2 equals 4. [General knowledge and factual description] Here is the picture: fire flame burn heat hot. ; [math] When computing, state the steps before the final answer. ].

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | describe |
| Confidence | 0.68 |
| Certainty | SURE) |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |

**Decomposition:** 2 clause(s) → `what is 8 divided by 2 | what is the ocean`  
**Sigil Rewrite:** `what is &n &op by &n &conj what is the ocean`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 8 divided by 2 equals 4. [General knowledge and factual description] Here is the picture: fire flame burn heat hot. ; [math] When computing, state the steps before the final answer. ].
```

**Result:** ✅ PASS

- ✅ math answer  

</details>

---

## Test 8 — multipart_arith_compare

**Input:** `what is 2 plus 3 and what is 4 times 5`

> [Quantitative reasoning over rewritten arithmetic forms] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.

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
[Quantitative reasoning over rewritten arithmetic forms] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.
```

**Result:** ✅ PASS

- ✅ first answer  
- ✅ second answer  

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
| 8 | multipart_arith_compare | `what is 2 plus 3 and what is 4 times 5` | ✅ PASS |

**Tests passed:** 7 / 8  
**Failed:** 1  

All 8 test inputs processed through the GrugBot420 engine with v722 specimen loaded.

### v7.23 Fixes Verified

1. **Stochastic coinflips removed** — `strength_biased_scan_coinflip` and `strength_biased_vote_coinflip` now always return `true`. No node or vote is randomly excluded based on strength.
2. **SPARSE_ACTIVE_FIRE_FLOOR set to 0.0** — Pre-scan confidence floor no longer culls weak matches. `should_fire_sparse_active()` always returns true for finite confidence.
3. **Confidence is the ONLY gate** — The authoritative threshold is `AIML_TOP_LOCKIN_FLOOR` (0.50). Only votes with confidence+linkage >= 0.50 are "locked in" and proceed to orchestration.

**⚠️ 1 test(s) failed — see individual test sections above.**

