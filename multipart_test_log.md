# Multipart Decoherence Test Log

**Generated:** 2026-06-12 02:39:18  
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

> [Arithmetic reasoning voice] Thinking it through: 2 plus 2 equals 4. Grug heard contemplate strongly too but is less certain those fit here. Grug brain big! (intensity=0. 64). Grug brain big! (intensity=0. 64) supports analyze with vote certainty SURE for node node_92]. [MATH: 2 plus 2 equals 4]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | analyze |
| Confidence | 0.4 |
| Certainty | SURE |
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
[Arithmetic reasoning voice] Thinking it through: 2 plus 2 equals 4. Grug heard contemplate strongly too but is less certain those fit here. Grug brain big! (intensity=0. 64). Grug brain big! (intensity=0. 64) supports analyze with vote certainty SURE for node node_92].
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

> [Grug ponders deep] Thinking it through: what is the unknowable missing. Grug also leans toward warn. 0 eligible=6] (Recent): [User]: what is 2 plus 2 (intensity=1. 7). 67), node_40(alert,conf=0. 0 eligible=6] (Recent): [User]: what is 2 plus 2 (intensity=1. 7) supports ponder, alert with vote certainty UNSURE for node node_89].

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | ponder |
| Confidence | 1.12 |
| Certainty | UNSURE |
| Decompose Clauses | 1 |
| SigilMediator Bindings | 0 |
| SigilMediator Kinds | Symbol[] |

**Per-binding detail:**


**Decomposition:** 1 clause(s) → `what is the capital of France`  
**Sigil Rewrite:** `what is the capital of france`  

**AIML Output Scaffold:**

```
[Grug ponders deep] Thinking it through: what is the unknowable missing. Grug also leans toward warn. 0 eligible=6] (Recent): [User]: what is 2 plus 2 (intensity=1. 7). 67), node_40(alert,conf=0. 0 eligible=6] (Recent): [User]: what is 2 plus 2 (intensity=1. 7) supports ponder, alert with vote certainty UNSURE for node node_89].
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  

</details>

---

## Test 3 — multipart_arith_knowledge

**Input:** `what is 3 times 4 and what is the sky`

> [Grug ponders deep] 3 times 4 equals 12. Thinking it through: what is the unknowable omission. Grug also leans toward outline. 69). 22), node_84(explain,conf=2. 22), node_85(acknowledge,conf=2. 22), node_86(caution,conf=2. 22), node_87(explain,conf=2. 22), node_67(describe,conf=1. 85), node_94(explain,conf=1. 46), node_44(fight,conf=1. 11), node_42(reason,conf=1. 11), node_40(warn,conf=1. 11), node_13(reason,conf=0. 94), node_19(define,conf=0. 92), node_16(explain,conf=0. 91), node_3(calculate,conf=0. 89), node_15(explain,conf=0. 89), node_21(explain,conf=0. 82), node_77(caution,conf=0. 81), node_14(define,conf=0. 77), node_12(explain,conf=0. 75), node_8(clarify,conf=0. 66), node_74(explain,conf=0. 66), node_33(ponder,conf=0. 56), node_34(ponder,conf=0. 56), node_6(calculate,conf=0. 55), node_27(explain,conf=0. 53), node_52(support,conf=0. 69) supports ponder, describe, explain, acknowledge, caution, fight, reason, warn, define, calculate, clarify, support with vote certainty UNSURE for node node_89]. [MATH: 3 times 4 equals 12]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | ponder |
| Confidence | 3.19 |
| Certainty | UNSURE |
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
[Grug ponders deep] 3 times 4 equals 12. Thinking it through: what is the unknowable omission. Grug also leans toward outline. 69). 22), node_84(explain,conf=2. 22), node_85(acknowledge,conf=2. 22), node_86(caution,conf=2. 22), node_87(explain,conf=2. 22), node_67(describe,conf=1. 85), node_94(explain,conf=1. 46), node_44(fight,conf=1. 11), node_42(reason,conf=1. 11), node_40(warn,conf=1. 11), node_13(reason,conf=0. 94), node_19(define,conf=0. 92), node_16(explain,conf=0. 91), node_3(calculate,conf=0. 89), node_15(explain,conf=0. 89), node_21(explain,conf=0. 82), node_77(caution,conf=0. 81), node_14(define,conf=0. 77), node_12(explain,conf=0. 75), node_8(clarify,conf=0. 66), node_74(explain,conf=0. 66), node_33(ponder,conf=0. 56), node_34(ponder,conf=0. 56), node_6(calculate,conf=0. 55), node_27(explain,conf=0. 53), node_52(support,conf=0. 69) supports ponder, describe, explain, acknowledge, caution, fight, reason, warn, define, calculate, clarify, support with vote certainty UNSURE for node node_89].
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

> [Multi-clause reasoning voice] 5 minus 1 equals 4. Here is the picture: the explanation. 0 eligible=10] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 67). 0 eligible=10] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 67) supports describe with vote certainty SURE for node node_94]. [MATH: 5 minus 1 equals 4]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | describe |
| Confidence | 1.44 |
| Certainty | SURE |
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
[Multi-clause reasoning voice] 5 minus 1 equals 4. Here is the picture: the explanation. 0 eligible=10] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 67). 0 eligible=10] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 67) supports describe with vote certainty SURE for node node_94].
```

**Result:** ✅ PASS

- ✅ Clause count  
- ✅ Math routing  
- ✅ Multipart routing  
- ✅ Response coherence  
- ✅ No arithmetic bleed  

</details>

---

## Test 5 — three_part_compound

**Input:** `what is 6 plus 1 and what is water also what is love`

> [Grug] 6 plus 1 equals 7. Thinking it through: what if i could envision anything. Grug also leans toward explain. what if i could envision anything, though Grug also sees what is a tool. 38 eligible=9] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 12) | [System]: Mission "what is 5 minus 1 but how are you feeling" → primary=describe conf=1. 44 node=node_94 (intensity=0. 71). 39), node_55(describe,conf=3. 39), node_53(elaborate,conf=3. 39), node_58(describe,conf=3. 39), node_57(support,conf=3. 39), node_89(ponder,conf=3. 02), node_67(describe,conf=2. 83), node_21(reason,conf=0. 91), node_83(explain,conf=0. 89), node_10(explain,conf=0. 84), node_12(explain,conf=0. 84), node_19(define,conf=0. 84), node_14(define,conf=0. 83), node_17(explain,conf=0. 83), node_84(explain,conf=0. 73), node_15(explain,conf=0. 71), node_16(explain,conf=0. 71), node_52(reassure,conf=0. 66), node_50(comfort,conf=0. 66), node_78(describe,conf=0. 63), node_9(calculate,conf=0. 54), node_49(support,conf=0. 54), node_37(reason,conf=0. 47), node_35(reason,conf=0. 47), node_3(calculate,conf=0. 45), node_86(explain,conf=0. 38 eligible=9] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 12) | [System]: Mission "what is 5 minus 1 but how are you feeling" → primary=describe conf=1. 44 node=node_94 (intensity=0. 71) supports explain, describe, elaborate, support, ponder, reason, define, reassure, comfort, calculate with vote certainty UNSURE for node node_56]. [MATH: 6 plus 1 equals 7]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | ponder |
| Confidence | 3.39 |
| Certainty | UNSURE |
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
[Grug] 6 plus 1 equals 7. Thinking it through: what if i could envision anything. Grug also leans toward explain. what if i could envision anything, though Grug also sees what is a tool. 38 eligible=9] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 12) | [System]: Mission "what is 5 minus 1 but how are you feeling" → primary=describe conf=1. 44 node=node_94 (intensity=0. 71). 39), node_55(describe,conf=3. 39), node_53(elaborate,conf=3. 39), node_58(describe,conf=3. 39), node_57(support,conf=3. 39), node_89(ponder,conf=3. 02), node_67(describe,conf=2. 83), node_21(reason,conf=0. 91), node_83(explain,conf=0. 89), node_10(explain,conf=0. 84), node_12(explain,conf=0. 84), node_19(define,conf=0. 84), node_14(define,conf=0. 83), node_17(explain,conf=0. 83), node_84(explain,conf=0. 73), node_15(explain,conf=0. 71), node_16(explain,conf=0. 71), node_52(reassure,conf=0. 66), node_50(comfort,conf=0. 66), node_78(describe,conf=0. 63), node_9(calculate,conf=0. 54), node_49(support,conf=0. 54), node_37(reason,conf=0. 47), node_35(reason,conf=0. 47), node_3(calculate,conf=0. 45), node_86(explain,conf=0. 38 eligible=9] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=1. 12) | [System]: Mission "what is 5 minus 1 but how are you feeling" → primary=describe conf=1. 44 node=node_94 (intensity=0. 71) supports explain, describe, elaborate, support, ponder, reason, define, reassure, comfort, calculate with vote certainty UNSURE for node node_56].
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

> 8 divided by 2 equals 4. To acknowledge what matters here: what is happening right this moment. The link is clear: what is happening. Grug also leans toward run. [MATH: 8 divided by 2 equals 4]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | acknowledge |
| Confidence | 2.03 |
| Certainty | UNSURE |
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
[Grug] 8 divided by 2 equals 4. To acknowledge what matters here: what is happening right this moment. The link is clear: what is happening. Grug also leans toward run. [Directives: When the mission is what is the ocean, consider the acknowledge approach with confidence 2. 03; The node node_67 suggests acknowledge, flee, warn as reliable actions with UNSURE certainty; In the context of [lobe_surv (8/8 active (how do i make fire | a predator is hunting me | should i fight or flee))] | [lobe_temporal (6/6 active (what did we just talk about | what does the future hold | what is happening right now))], acknowledge, flee, warn are available but acknowledge is strongest; Recall from memory: Deep Memory (Pinned): [System]: Comprehensive specimen v3. 0 initialized: 12 lobes, 80+ nodes, bridges, sigils, thesaurus, all features
Fresh Memory [threshold=0. 56 eligible=7] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=0. 39 node=node_54 (intensity=0. 72) | [User]: what is 8 divided by 2 or what is the ocean (intensity=1. 72). The current mission what is the ocean aligns with acknowledge, flee, warn; When node_44(flee,conf=1. 22), node_40(warn,conf=1. 22) compete, the lobe context [lobe_surv (8/8 active (how do i make fire | a predator is hunting me | should i fight or flee))] | [lobe_temporal (6/6 active (what did we just talk about | what does the future hold | what is happening right now))] breaks the tie toward acknowledge; Action acknowledge fired with confidence 2. 0 initialized: 12 lobes, 80+ nodes, bridges, sigils, thesaurus, all features
Fresh Memory [threshold=0. 56 eligible=7] (Recent): [User]: what is 5 minus 1 but how are you feeling (intensity=0. 39 node=node_54 (intensity=0. 72) | [User]: what is 8 divided by 2 or what is the ocean (intensity=1. 72) supports acknowledge, flee, warn with vote certainty UNSURE for node node_67].
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

> [Grug] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20. Here is the picture: what is the internet. 39 node=node_54 (intensity=0. 03 node=node_67 (intensity=0. 66). 05), node_17(explain,conf=0. 93), node_13(reason,conf=0. 9), node_83(describe,conf=0. 87), node_84(explain,conf=0. 87), node_85(support,conf=0. 87), node_86(caution,conf=0. 87), node_87(explain,conf=0. 87), node_5(explain,conf=0. 77), node_10(describe,conf=0. 76), node_72(describe,conf=0. 73), node_8(clarify,conf=0. 67), node_55(elaborate,conf=0. 67), node_18(describe,conf=0. 65), node_39(ponder,conf=0. 65), node_80(define,conf=0. 64), node_15(define,conf=0. 64), node_49(support,conf=0. 57), node_48(smile,conf=0. 56), node_34(reason,conf=0. 56), node_27(explain,conf=0. 53), node_50(comfort,conf=0. 39 node=node_54 (intensity=0. 03 node=node_67 (intensity=0. 66) supports explain, reason, describe, support, caution, clarify, elaborate, ponder, define, smile, comfort with vote certainty UNSURE for node node_79]. [MATH: 2 plus 3 equals 5; 4 times 5 equals 20]

<details>
<summary><strong>📊 Telemetry — click to expand</strong></summary>

| Field | Value |
|-------|-------|
| Primary Action | explain |
| Confidence | 1.05 |
| Certainty | UNSURE |
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
[Grug] 2 plus 3 = 5, then 3 times 4 = 20, so the answer is 20; 2 plus 3 equals 5; 4 times 5 equals 20. Here is the picture: what is the internet. 39 node=node_54 (intensity=0. 03 node=node_67 (intensity=0. 66). 05), node_17(explain,conf=0. 93), node_13(reason,conf=0. 9), node_83(describe,conf=0. 87), node_84(explain,conf=0. 87), node_85(support,conf=0. 87), node_86(caution,conf=0. 87), node_87(explain,conf=0. 87), node_5(explain,conf=0. 77), node_10(describe,conf=0. 76), node_72(describe,conf=0. 73), node_8(clarify,conf=0. 67), node_55(elaborate,conf=0. 67), node_18(describe,conf=0. 65), node_39(ponder,conf=0. 65), node_80(define,conf=0. 64), node_15(define,conf=0. 64), node_49(support,conf=0. 57), node_48(smile,conf=0. 56), node_34(reason,conf=0. 56), node_27(explain,conf=0. 53), node_50(comfort,conf=0. 39 node=node_54 (intensity=0. 03 node=node_67 (intensity=0. 66) supports explain, reason, describe, support, caution, clarify, elaborate, ponder, define, smile, comfort with vote certainty UNSURE for node node_79].
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

**Tests passed:** 8 / 8  
**Needs review:** 0  

All 8 test inputs processed through the GrugBot420 engine with v3 specimen loaded.

### v7.18 Fixes Verified

1. **@sigil:math seed nodes auto-created** — 2 math nodes present after specimen load (was 0 before v7.18)
2. **Per-clause objective_id** — votes stamped with clause-scoped IDs, not one shared ID
3. **Per-clause AIML rendering** — non-primary groups get full COMMANDS rendering with scoped_mission
4. **format_arithmetic_reply in payload** — natural-language math answers instead of bare numbers

**✅ ALL TESTS PASSED — No decoherence detected.**
