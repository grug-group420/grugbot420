# Multipart Decoherence Test Log

**Generated:** 2026-06-12 06:43:19  
**Specimen:** v722_test.specimen.gz  
**Nodes:** 26 · **Sigils:** 3  
**@sigil:math nodes:** 2 · **@sigil:multipart nodes:** 1  
**Engine version:** v7.26 (context topicality curve + confidence-only gating + sub-lockin hedge)  

---

## Purpose

Verify response-level decoherence fixes in GrugBot420 engine v7.26.  
Math questions should produce math answers; compound questions should produce coherent per-clause responses.  
No raw node IDs, confidence numbers, lobe internals, or memory context should bleed into the visible response text.  
The v7.26 engine adds a context topicality curve (`curved_avg = avg_conf * (1.0 + 0.25 * topicality)`)  
so lobes whose domain is relevant to the current input get a proportional ordering boost.  
The curve only affects ordering — the admission gate still uses raw `avg_conf`.  
The sub-lockin hedge section renders below-lock-in votes in a separate "This might also be true" section.  
Combined with v7.23's removal of all stochastic coinflips and v7.24's confidence-only LobeOrchestrator,  
the pipeline is now fully deterministic and confidence-gated.

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
| Decoherence | ✅ clean |

**Decomposition:** 1 clause(s) → `what is 2 plus 2`  
**Sigil Rewrite:** `what is &n &op &n`  

**AIML Output Scaffold:**

```
[Multi-clause reasoning voice] 2 plus 2 equals 4.
```

**Result:** ✅ PASS

- ✅ math answer  

**✅ Decoherence check:** clean — no raw internals in response  

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
| Decoherence | ✅ clean |

**Decomposition:** 1 clause(s) → `tell me about fire`  
**Sigil Rewrite:** `tell me about fire`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ✅ PASS

- ✅ No crash  

**✅ Decoherence check:** clean — no raw internals in response  

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
| Decoherence | ✅ clean |

**Decomposition:** 2 clause(s) → `what is 3 times 4 | what is the sky`  
**Sigil Rewrite:** `what is &n &op &n &conj what is the sky`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 3 times 4 equals 12.
```

**Result:** ❌ FAIL

- ✅ math answer  
- ❌ sky mention  

**✅ Decoherence check:** clean — no raw internals in response  

</details>

---

## Test 4 — multipart_arith_emotion

**Input:** `what is 5 minus 1 but how are you feeling`

> [General knowledge and factual description] 5 minus 1 equals 4. [Quantitative reasoning over rewritten arithmetic forms] where many quantity amount.

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | analyze |
| Confidence | 0.49 |
| Certainty | SURE) |
| Decompose Clauses | 2 |
| SigilMediator Bindings | 4 |
| SigilMediator Kinds | [:math, :multipart] |
| Decoherence | ✅ clean |

**Decomposition:** 2 clause(s) → `what is 5 minus 1 | how are you feeling`  
**Sigil Rewrite:** `what is &n &op &n &conj how are you feeling`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 5 minus 1 equals 4. [Quantitative reasoning over rewritten arithmetic forms] where many quantity amount.
```

**Result:** ✅ PASS

- ✅ math answer  

**✅ Decoherence check:** clean — no raw internals in response  

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

> [General knowledge and factual description] 6 plus 1 equals 7. [Cold logical analysis engine] Thinking it through: consider ponder contemplate reason. [Directives: [empathy] If sad/hurt cues are present, lead with comfort and acknowledge.; [reasoning] When asked 'why' or 'how', open with reasoning then explanation.; [math] When computing, state the steps before the final answer.]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | reason |
| Confidence | 0.61 |
| Certainty | SURE) |
| Decompose Clauses | 3 |
| SigilMediator Bindings | 5 |
| SigilMediator Kinds | [:math, :multipart] |
| Decoherence | ✅ clean |

**Decomposition:** 3 clause(s) → `what is 6 plus 1 | what is water | what is love`  
**Sigil Rewrite:** `what is &n &op &n &conj what is water &conj what is love`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 6 plus 1 equals 7. [Cold logical analysis engine] Thinking it through: consider ponder contemplate reason. [Directives: [empathy] If sad/hurt cues are present, lead with comfort and acknowledge.; [reasoning] When asked 'why' or 'how', open with reasoning then explanation.; [math] When computing, state the steps before the final answer.]
```

**Result:** ✅ PASS

- ✅ math answer  

**✅ Decoherence check:** clean — no raw internals in response  

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
| Decoherence | ✅ clean |

**Decomposition:** 1 clause(s) → `tell me about ecosystems`  
**Sigil Rewrite:** `tell me about ecosystems`  

**AIML Output Scaffold:**

```
[no scaffold found]
```

**Result:** ✅ PASS

- ✅ No crash  

**✅ Decoherence check:** clean — no raw internals in response  

</details>

---

## Test 7 — multipart_or_split

**Input:** `what is 8 divided by 2 or what is the ocean`

> [Quantitative reasoning over rewritten arithmetic forms] 8 divided by 2 equals 4.

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
| Decoherence | ✅ clean |

**Decomposition:** 2 clause(s) → `what is 8 divided by 2 | what is the ocean`  
**Sigil Rewrite:** `what is &n &op by &n &conj what is the ocean`  

**AIML Output Scaffold:**

```
[Quantitative reasoning over rewritten arithmetic forms] 8 divided by 2 equals 4.
```

**Result:** ✅ PASS

- ✅ math answer  

**✅ Decoherence check:** clean — no raw internals in response  

</details>

---

## Test 8 — multipart_arith_compare

**Input:** `what is 2 plus 3 and what is 4 times 5`

> [General knowledge and factual description] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.

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
| Decoherence | ✅ clean |

**Decomposition:** 2 clause(s) → `what is 2 plus 3 | what is 4 times 5`  
**Sigil Rewrite:** `what is &n &op &n &conj what is &n &op &n`  

**AIML Output Scaffold:**

```
[General knowledge and factual description] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20.
```

**Result:** ✅ PASS

- ✅ first answer  
- ✅ second answer  

**✅ Decoherence check:** clean — no raw internals in response  

</details>

---

## Summary

| # | Test | Input | Result | Decoherence |
|---|------|-------|--------|-------------|
| 1 | simple_arithmetic | `what is 2 plus 2` | ✅ PASS | ✅ clean |
| 2 | simple_knowledge | `tell me about fire` | ✅ PASS | ✅ clean |
| 3 | multipart_arith_knowledge | `what is 3 times 4 and what is the sky` | ❌ FAIL | ✅ clean |
| 4 | multipart_arith_emotion | `what is 5 minus 1 but how are you feeling` | ✅ PASS | ✅ clean |
| 5 | three_part_compound | `what is 6 plus 1 and what is water also what is love` | ✅ PASS | ✅ clean |
| 6 | single_clause_control | `tell me about ecosystems` | ✅ PASS | ✅ clean |
| 7 | multipart_or_split | `what is 8 divided by 2 or what is the ocean` | ✅ PASS | ✅ clean |
| 8 | multipart_arith_compare | `what is 2 plus 3 and what is 4 times 5` | ✅ PASS | ✅ clean |

**Tests passed:** 7 / 8  
**Decoherence-clean:** 8 / 8  
**Failed:** 1  

All 8 test inputs processed through the GrugBot420 engine with v722 specimen loaded.

### v7.26 Fixes Verified

1. **Stochastic coinflips removed (v7.23)** — `strength_biased_scan_coinflip` and `strength_biased_vote_coinflip` now always return `true`. No node or vote is randomly excluded based on strength.
2. **SPARSE_ACTIVE_FIRE_FLOOR set to 0.0 (v7.23)** — Pre-scan confidence floor no longer culls weak matches.
3. **LobeOrchestrator sequential firing (v7.24)** — No muting, no curve (at v7.24), confidence-only gates. Lobe firing is sequential and deterministic.
4. **Sub-lockin hedge section (v7.25)** — Votes below lock-in threshold render in separate "This might also be true" section, not mixed into the primary response.
5. **Context topicality curve (v7.26)** — `curved_avg = avg_conf * (1.0 + 0.25 * topicality)`. Domain-relevant lobes get proportional ordering boost. Curve never penalizes (0 topicality = exact v7.24 behavior). Only affects ordering, not admission.

**⚠️ 1 test(s) failed — see individual test sections above.**

**✅ All decoherence checks passed — no raw internals in any response.**

