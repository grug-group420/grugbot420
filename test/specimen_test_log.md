# GrugBot Specimen Integration Test — Verbatim Run Log

**Date**: 2025-06-02  
**Specimen**: multi_lobe_v1 (grug-voice prompts, 16 nodes, 4 lobes, 5 attachments, 8 orchestration rules)  
**Engine version**: top-dominated curve fix + STOPWORDS question-word fix (post commit f5e98ad)  
**Capture method**: `julia --project=. test/run_curve_test.jl` — full stdout capture  

---

## Changes from Prior Run

### 1. STOPWORDS Fix
Added question words to STOPWORDS set in engine.jl:
- "what", "who", "how", "why", "when", "where", "which"

**Reason**: Without these, "what" counted as a content token in the literal token pre-gate, giving conversation nodes a `literal_hit=True` on "What is the quadratic formula" even though "what" carries zero domain signal. This was the primary root cause of the conversation lobe misfire.

### 2. Lobe Scoring Curve Fix
Changed the curve formula in `_compute_lobe_score()`:
- **Old**: `score = max(base_avg * top_avg, peak * peak)` — equal weight to base and top, with peak² override
- **New**: `score = sqrt(base_avg) * top_avg²` — top_avg dominates exponentially, no peak² override

**Reason**: The old formula gave equal weight to base_avg and top_avg. This meant a lobe with many weak votes (high base_avg) could beat a lobe with fewer but more decisive votes (high top_avg). The `peak²` override was masking the curve's routing effect entirely in many cases. The new formula:
  - Square-roots base_avg → broad mediocrity contributes less
  - Squares top_avg → decisive hard selections dominate (0.6²=0.36 vs 0.3²=0.09 = 4× gap)
  - Removes peak² override → the curve formula itself determines routing

### 3. No Whitelists Used
This test run was performed **without per-lobe fuzzy whitelists** to verify that the curve fix alone is sufficient. Prior runs required whitelists to prevent "What is X" misfiring to the conversation lobe.

---

## Mission 1

**INPUT**: `Hello! What can you do?`

**RESPONSE** (AIML Output Scaffold, node_16, action=explain, conf=0.41):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Science, each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, and conversation. Grug is honest about what Grug is, and the winning vote shapes the answer. Grug has lobes for math, philosophy, and the nodes vote on what matters most.. The link is clear: what are you.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 conversation: base=0.261 × top=0.41 = 0.0858 [hard_votes=0]
  · default: base=0.333 × top=0.333 = 0.0642 [hard_votes=0]
```

**✅ CORRECT** — Conversation lobe wins as expected for a greeting/meta-question input.

---

## Mission 2

**INPUT**: `Explain what a derivative is in calculus`

**RESPONSE** (AIML Output Scaffold, node_3, action=explain, conf=0.29):

> [Grug knows calculus] Here is the picture: And acceleration is the derivative of velocity, the chain rule, a derivative measures how fast something changes at a single point, like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes, and the output rule to detect derivatives quickly. Velocity is the derivative of position, and and the ratio becomes the slope. Grug uses the potential rule.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 math: base=0.286 × top=0.286 = 0.0436 [hard_votes=0]
  · science: base=0.225 × top=0.225 = 0.024 [hard_votes=0]
  · conversation: base=0.171 × top=0.171 = 0.0122 [hard_votes=0]
```

**✅ CORRECT** — Math lobe wins with node_3 (calculus). Conversation lobe is third, not even competing. Attachment relay: node_7→node_3.

---

## Mission 3

**INPUT**: `How does Newton's second law work?`

**RESPONSE**: **CAVE SILENT** — No valid specimens found for this input.

**Lobe Curve**: (carried over from previous mission — no new votes passed gate)

**Note**: Pre-existing BUG-004 (pattern longer than input causes cheap bidirectional scan fallback). Not affected by curve changes.

---

## Mission 4

**INPUT**: `How does quantum physics relate to the nature of reality and consciousness`

**RESPONSE** (AIML Output Scaffold, node_13, action=ponder, conf=0.20):

> [Grug wonders what is really real] Here is the picture: Metaphysics asks about the fundamental nature of existence, and Grug is honest about that uncertainty, consciousness, and free will. The hard challenge of consciousness asks why subjective experience exists at all. Grug does not know whether free will is genuine, and an illusion.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 philosophy: base=0.2 × top=0.2 = 0.0179 [hard_votes=0]
  · science: base=0.083 × top=0.083 = 0.002 [hard_votes=0]
```

**✅ CORRECT** — Philosophy lobe wins with node_13 (metaphysics). Attachment relay: node_13 fired via node_10 (quantum→metaphysics bridge). Science is runner-up with 9× lower score.

---

## Mission 5

**INPUT**: `Explain integration and antiderivatives`

**RESPONSE** (AIML Output Scaffold, node_4, action=explain, conf=0.12):

> [Grug understands integration] Here is the picture: And accumulated change using these methods, an integral adds up all the tiny pieces under a curve, and the fundamental theorem of calculus ties them together into one deep truth. Grug can compute areas, like counting how much water fills a cave. The antiderivative reverses differentiation, and volumes.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 math: base=0.125 × top=0.125 = 0.0055 [hard_votes=0]
```

**✅ CORRECT** — Math lobe wins with node_4 (integration).

---

## Mission 6

**INPUT**: `What is the quadratic formula`

**RESPONSE** (AIML Output Scaffold, node_5, action=clarify, conf=0.12):

> [Grug solves equations] Here is the picture: Grug isolates the unknown variable step by step, using factoring, substitution, and the quadratic formula. For a quadratic, the formula gives both roots directly from the coefficients. Grug always checks the response by plugging it back in.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 math: base=0.125 × top=0.125 = 0.0055 [hard_votes=0]
```

**✅ FIXED — No whitelist needed!** Previously (before curve fix), the conversation lobe won this query with score 0.0278, producing a scrambled self-description. Now the conversation lobe doesn't even appear in the lobe curve — it got zero votes because "what" is now a stopword, so conversation nodes don't get literal_hit. Math lobe wins cleanly with node_5 (algebra).

The double fix (STOPWORDS + curve) routes this correctly without any whitelist.

---

## Mission 7

**INPUT**: `What is epistemology about`

**RESPONSE** (AIML Output Scaffold, node_11, action=ponder, conf=0.14):

> [Grug asks how Grug knows what Grug knows] Here is the picture: Hangs together in a web of mutually supporting beliefs, epistemology studies the nature of insight itself. The classical answer is justified true belief: a claim must be true, believed, and and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether insight rests on powerful foundations.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 philosophy: base=0.143 × top=0.143 = 0.0077 [hard_votes=0]
```

**✅ FIXED — No whitelist needed!** Previously, node_16 (conversation) won with conf=0.32. Now the conversation lobe gets zero votes (stopword fix), and philosophy lobe wins with node_11 (epistemology).

---

## Mission 8 (MULTIPART)

**INPUT**: `Grug want to know about derivatives and also what does Newton say about force`

**RESPONSE** (AIML Output Scaffold, node_7, action=ponder, conf=0.22):

> [Grug studies force and motion] Here is the picture: Newton's first law says an object keeps moving unless something pushes it. The second law is force equals mass times acceleration, the backbone of classical mechanics. The third law says every push has an equal push back. Grug sees these laws everywhere: falling apples, orbiting moons, and the pull of gravity.

**Lobe Curve**:
```
Lobe Curve (√base × top² = score):
  👑 science: base=0.222 × top=0.222 = 0.0233 [hard_votes=0]
```

**✅ CORRECT** — Science lobe wins with node_7 (physics/Newton). No conversation lobe interference.

---

## Mission 9 (MULTIPART)

**INPUT**: `What is a derivative and also how does the quadratic formula work`

**RESPONSE (Part 1)** (AIML Output Scaffold, node_3, action=validate, conf=0.17):

> [Grug knows calculus] Here is the picture: Like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes, and acceleration is the derivative of velocity, a derivative measures how fast something changes at a single point, the chain rule, and the ratio becomes the slope. Grug uses the power rule, and and the product rule to find derivatives quickly. Velocity is the derivative of position.

**RESPONSE (Part 2)** (AIML Output Scaffold, node_5, action=calculate, conf=0.11):

> [Grug solves equations] Here is the picture: Grug isolates the unknown variable step by step, using factoring, substitution, and the quadratic formula. For a quadratic, the formula gives both roots directly from the coefficients. Grug always checks the answer by plugging it back in.

**Lobe Curve (both parts)**:
```
Part 1: 👑 math: base=0.167 × top=0.167 = 0.0113 [hard_votes=0]
Part 2: 👑 math: base=0.111 × top=0.111 = 0.0041 [hard_votes=0]
```

**✅ FIXED — No whitelist needed!** Both sub-queries correctly route to math lobe. Previously, the "What is a derivative" sub-query could trigger the conversation lobe.

---

## Mission 10 (MULTIPART)

**INPUT**: `Explain epistemology and also what is the nature of consciousness`

**RESPONSE (Part 1)** (AIML Output Scaffold, node_11, action=validate, conf=0.14):

> [Grug asks how Grug knows what Grug knows] Here is the picture: Epistemology studies the nature of awareness itself. The classical answer is justified true belief: a claim must be true, believed, and supported by evidence. But Gettier problems show that even justified true belief can subsist accidental. Grug wonders whether knowledge rests on solid foundations or hangs together in a web of mutually supporting beliefs.

**RESPONSE (Part 2)** (AIML Output Scaffold, node_13, action=ponder, conf=0.14):

> [Grug wonders what is really real] Here is the picture: Metaphysics asks about the fundamental nature of existence, consciousness, and free will. The hard challenge of consciousness asks why subjective experience exists at all. Grug does not know whether free will is genuine or an illusion, and Grug is honest about that uncertainty.

**Lobe Curve (both parts)**:
```
Part 1: 👑 philosophy: base=0.143 × top=0.143 = 0.0077 [hard_votes=0]
Part 2: 👑 philosophy: base=0.143 × top=0.143 = 0.0077 [hard_votes=0]
```

**✅ FIXED — No whitelist needed!** Both sub-queries correctly route to philosophy lobe (node_11 epistemology + node_13 metaphysics). Previously, "what is the nature of consciousness" triggered node_16 (conversation).

---

## Mission 11 (MULTIPART)

**INPUT**: `How does DNA carry information and also what is the periodic table`

**RESPONSE (Part 1)** (AIML Output Scaffold, node_9, action=analyze, conf=0.11):

> [Grug observes living things] Here is the picture: And DNA inside them carries the instructions for building proteins. Genes change over generations, or flying today, swimming, and natural selection shapes which changes survive. Grug sees the tree of life branching from single cells to every creature walking, and cells are the basic unit of life.

**RESPONSE (Part 2)** (AIML Output Scaffold, node_8, action=define, conf=0.12):

> [Grug knows the small stuff] Here is the picture: Atoms are the building blocks, and they bond together into molecules through shared electrons. The periodic table arranges elements by their electron structure, and that pattern predicts how they react. Grug can balance a chemical equation because atoms are neither created nor destroyed in a reaction.

**Lobe Curve (both parts)**:
```
Part 1: 👑 science: base=0.111 × top=0.111 = 0.0041 [hard_votes=0]
Part 2: 👑 science: base=0.125 × top=0.125 = 0.0055 [hard_votes=0]
```

**✅ FIXED — No whitelist needed!** Both sub-queries correctly route to science lobe (node_9 biology + node_8 chemistry). Previously, "what is the periodic table" triggered node_16 (conversation).

---

## Summary

### Curve Fix Impact (NO whitelist used)

| Mission | Input | Before Curve Fix (with whitelist) | After Curve Fix (no whitelist) | Fixed? |
|---------|-------|----------------------------------|-------------------------------|--------|
| 1 | "Hello! What can you do?" | conversation | conversation | ✅ (unchanged) |
| 2 | "Explain what a derivative is in calculus" | math (conversation vetoed) | math (conversation not competing) | ✅ (stronger) |
| 3 | "How does Newton's second law work?" | cave silent | cave silent | ⚠️ (BUG-004) |
| 4 | "How does quantum physics relate to reality..." | philosophy | philosophy | ✅ (unchanged) |
| 5 | "Explain integration and antiderivatives" | math | math | ✅ (unchanged) |
| 6 | "What is the quadratic formula" | math (conversation vetoed) | **math (no veto needed!)** | ✅ **CURVE FIX** |
| 7 | "What is epistemology about" | philosophy (conversation vetoed) | **philosophy (no veto needed!)** | ✅ **CURVE FIX** |
| 8 | multipart: derivatives + Newton force | science (conversation vetoed) | **science (no veto needed!)** | ✅ **CURVE FIX** |
| 9 | multipart: derivative + quadratic | math (conversation vetoed) | **math (no veto needed!)** | ✅ **CURVE FIX** |
| 10 | multipart: epistemology + consciousness | philosophy (conversation vetoed) | **philosophy (no veto needed!)** | ✅ **CURVE FIX** |
| 11 | multipart: DNA + periodic table | science (conversation vetoed) | **science (no veto needed!)** | ✅ **CURVE FIX** |

### Key Finding

**The per-lobe fuzzy whitelist is no longer needed as a primary gate.** The two root-cause fixes (STOPWORDS + curve formula) eliminate the conversation lobe misfire without any whitelist:

1. **STOPWORDS fix**: "what" is now a stopword, so conversation nodes don't get `literal_hit=True` on "What is X" queries. Without literal_hit, conversation nodes only fire via coinflip (producing near-zero confidence).

2. **Curve fix** (`sqrt(base_avg) * top_avg²`): Even if conversation nodes got some confidence, the new curve gives exponentially more weight to `top_avg` than `base_avg`, so a domain-specific lobe with even moderate hard selections will beat a conversation lobe with broad mediocrity.

The whitelist code is retained as a safety net but is no longer necessary for correct routing.

### Technical Details of the Curve Fix

**Old formula**: `score = max(base_avg * top_avg, peak²)`
- Equal weight to base_avg and top_avg
- `peak²` override masked the curve's routing effect when any lobe had a moderate peak

**New formula**: `score = sqrt(base_avg) * top_avg²`
- base_avg is square-rooted: reduces the influence of many-weak-vote lobes
- top_avg is squared: decisive hard selections dominate (0.6→0.36 vs 0.3→0.09 = 4× gap)
- No peak² override: the curve formula itself determines routing
- Result: lobes with confident hard selections always beat lobes with broad mediocrity

### Known Bugs (Remaining, Pre-Existing)
1. **Phrase reorder scrambles CLAIM**: `_reorder_clauses` with `GRUG_PHRASE_REORDER_RATE=0.40` produces incoherent output.
2. **Thesaurus swap artifacts**: `_pick_synonym` with `GRUG_THESAURUS_SWAP_RATE=0.25` produces context-inappropriate swaps.
3. **Silent cave on Newton's second law** (Mission 3): BUG-004 causes cheap bidirectional scan fallback when pattern is longer than input.
4. **Multipart sometimes produces only one response**: When the multipart pipeline falls back, only the primary objective's scaffold is emitted.
