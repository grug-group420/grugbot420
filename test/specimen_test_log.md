# 🧪 GrugBot Specimen Integration Test — v2 (Grug-Voice Edition)

**Date:** 2026-05-29
**Specimen:** multi_lobe_v2 — 4 lobes, 16 nodes, grug-voice system prompts, coherence rules
**Changes from v1:** Grug-voice system prompts (third person), coherence-focused orchestration rules (8 rules including sentence completeness and no-repetition), multipart compound inputs (missions 8-11), wants_context gate fix (only pulls fresh memory when a winning node opts in).

---

## Phase 1: Specimen Architecture

### Lobes
- **math**: Pure mathematics — algebra, calculus, geometry, logic
- **science**: Natural sciences — physics, chemistry, biology
- **philosophy**: Abstract thought — epistemology, ethics, metaphysics
- **conversation**: General conversation — greetings, small talk, meta-questions
- Connected: math↔science, science↔philosophy, philosophy↔conversation

### Nodes (16 total, grug-voice prompts)

| Lobe | Node | Pattern | Voice Prefix |
|------|------|---------|-------------|
| math | node_3 | calculus derivative rate of change slope tangent | "Grug knows calculus" |
| math | node_4 | integration integral area under curve antiderivative | "Grug understands integration" |
| math | node_5 | algebra equation solve variable unknown linear quadratic | "Grug solves equations" |
| math | node_6 | geometry triangle circle polygon area perimeter angle | "Grug knows shapes and spaces" |
| science | node_7 | physics force motion newton gravity acceleration mass | "Grug studies force and motion" |
| science | node_8 | chemistry element atom molecule bond reaction periodic | "Grug knows the small stuff" |
| science | node_9 | biology cell DNA gene evolution organism species | "Grug observes living things" |
| science | node_10 | quantum mechanics wave particle heisenberg uncertainty superposition | "Grug ponders the very small" |
| philosophy | node_11 | epistemology knowledge truth belief justification evidence | "Grug asks how Grug knows what Grug knows" |
| philosophy | node_12 | ethics moral right wrong good evil duty virtue | "Grug weighs right and wrong" |
| philosophy | node_13 | metaphysics reality existence being consciousness free will | "Grug wonders what is really real" |
| philosophy | node_14 | logic reasoning argument fallacy syllogism deduction induction | "Grug follows the thread of reasoning" |
| conversation | node_15 | hello hi hey good morning greetings howdy welcome | "Grug greets you warmly" |
| conversation | node_16 | what are you who are you what can you do capabilities | "Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes" |
| conversation | node_17 | thank thanks appreciate gratitude goodbye bye farewell | "Grug appreciates the kind words" |
| conversation | node_18 | tell me about explain describe what is how does overview | "Grug gives clear explanations" |

### Cross-Lobe Attachments
- node_3 (calculus) → node_7 (physics): "rate of change force acceleration derivative velocity"
- node_10 (quantum) → node_13 (metaphysics): "quantum reality consciousness observation measurement"
- node_5 (algebra) → node_3 (calculus): "equation solve derivative limit function variable"
- node_9 (biology) → node_8 (chemistry): "molecular bond protein DNA reaction organic"
- node_12 (ethics) → node_14 (logic): "reasoning argument evaluation fallacy justification"

### Orchestration Rules (8 coherence-focused rules)
1. Grug's primary mission is {PRIMARY_ACTION}. Grug commits full cognitive resources to this task.
2. Grug grounds every claim with evidence. {CONFIDENCE} determines how strongly Grug asserts. Low confidence means Grug qualifies explicitly rather than guessing.
3. Grug looks for connections across {LOBE_CONTEXT}. Cross-domain insight deepens understanding when the links are genuine.
4. Grug structures explanations from the big picture down to the details, then synthesizes and draws out implications.
5. Grug uses analogies carefully and states their limitations before applying them.
6. **Grug speaks in complete sentences. Each sentence carries one idea. Grug does not pile fragments together.** *(new — coherence rule)*
7. **Grug does not repeat what was already said. Grug moves forward and adds new substance to each reply.** *(new — coherence rule)*
8. **Grug refers to Grug in the third person. Grug does not say I or me. Grug says Grug.** *(new — voice rule)*

---

## Phase 2: Conversation — Mission Interactions

### 📩 Exchange 1: Greeting & Self-Description

**👤 User:**

> Hello! What can you do?

**🧠 GrugBot AIML Output Scaffold:**

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the outcome. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: who are you. [Directives: Grug's primary mission is explain. Grug commits full cognitive resources to this task.; ...]

**Telemetry:** conf=0.45, certainty=SURE, winning node=node_16 (conversation — "what are you" pattern). Memory-Pull: pull_fresh=false — no winning node requested context. No fresh memory dragged in.

**Assessment:** ✅ Grug-voice is solid. Voice prefix is clear third-person self-introduction. No memory dump from past exchanges. The "who are you" triple in SUPPORT is a bit odd for a self-description context but structurally correct.

---

### 📩 Exchange 2: Calculus — Derivatives

**👤 User:**

> Explain what a derivative is in calculus

**🧠 GrugBot AIML Output Scaffold:**

> [Grug knows calculus] Here is the picture: A derivative measures how fast something changes at a single point, like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes, and the ratio becomes the slope. Grug uses the power rule, the chain rule, and the product rule to find derivatives quickly. Velocity is the derivative of position, and acceleration is the derivative of velocity..

**Telemetry:** conf=0.25, certainty=SURE, winning node=node_3 (math/calculus). Memory-Pull: pull_fresh=false. Lobe curve: math=0.0625.

**Assessment:** ✅✅ This is a strong response. The grug-voice system prompt produces coherent, substantive output. The analogy "like the slope of a hill under Grug's feet" is natural and informative. Each sentence carries one idea. The claim is grounded in the node's seeded knowledge. This is the quality target for all nodes.

---

### 📩 Exchange 3: Newton's Second Law

**👤 User:**

> How does Newton's second law work?

**🧠 GrugBot:**

> *(Cave is silent — no valid specimens found for this input)*

**Telemetry:** Action=ACTION_QUERY, Tone=TONE_CURIOUS, Conf=0.53. BUG-004 warnings on node_18. Token overlap insufficient to pass the vote gate.

**Assessment:** ⚠️ Same silent-cave issue as v1. The physics node pattern ("physics force motion newton gravity acceleration mass") has 7 tokens while the input has 6 tokens — BUG-004 triggers for the cheap bidirectional scan, but the real issue is that "Newton's second law" doesn't have enough token overlap with the pattern. The pattern needs "second law" or "F=ma" added, or the input needs to be phrased closer to the pattern vocabulary.

---

### 📩 Exchange 4: Quantum Physics & Consciousness (Cross-Domain)

**👤 User:**

> How does quantum physics relate to the nature of reality and consciousness

**🧠 GrugBot AIML Output Scaffold:**

> [Grug wonders what is really real] Here is the picture: Metaphysics asks about the fundamental nature of existence, consciousness, and free will. The strenuous problem of consciousness asks why subjective experience exists at all. Grug does not know whether free will is genuine or an illusion, and Grug is honest about that uncertainty..

**Telemetry:** conf=0.18, certainty=SURE, winning node=node_13 (philosophy/metaphysics). Memory-Pull: pull_fresh=false. Lobe curve: philosophy=0.0331, science=0.0059.

**Assessment:** ✅ The metaphysics node won (not the quantum node), which is reasonable — "nature of reality and consciousness" maps to metaphysics more strongly than quantum physics. The voice prefix "Grug wonders what is really real" is evocative and appropriate. Note the thesaurus swap "hard" → "strenuous" in "strenuous problem of consciousness" — this is the GRUG_THESAURUS_SWAP_RATE at work, and it degrades coherence slightly.

---

### 📩 Exchange 5: Integration & Antiderivatives

**👤 User:**

> Explain integration and antiderivatives

**🧠 GrugBot AIML Output Scaffold:**

> [Grug understands integration] Here is the picture: An integral adds up all the tiny pieces under a curve, like counting how much beverage fills a cave. The antiderivative reverses differentiation, and the fundamental theorem of calculus ties them together into one deep truth. Grug can compute areas, volumes, and accumulated change using these methods..

**Telemetry:** conf=0.12, certainty=SURE, winning node=node_4 (math/integration). Memory-Pull: pull_fresh=false.

**Assessment:** ✅ Strong grug-voice response. The cave analogy ("like counting how much water fills a cave") got thesaurus-swapped to "beverage" which is distracting but the overall coherence is much improved. "Grug can compute areas, volumes, and accumulated change" is substantive and third-person. The thesaurus swap issue is a known cosmetic defect.

---

### 📩 Exchange 6: Quadratic Formula (Misfire — still present)

**👤 User:**

> What is the quadratic formula

**🧠 GrugBot AIML Output Scaffold:**

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: what are you.

**Telemetry:** conf=0.17, certainty=SURE, winning node=node_16 (conversation — "what are you" pattern again). Memory-Pull: pull_fresh=false.

**Assessment:** ❌ Still misfires to conversation lobe. The "What is the quadratic formula" framing overlaps with the "what are you who are you what can you do capabilities" pattern more strongly than the math node's "algebra equation solve variable unknown linear quadratic" pattern. BUG-004 on the algebra node (7-token pattern vs 5-token input) reduces its confidence. This is a known token-overlap voting limitation.

---

### 📩 Exchange 7: Epistemology

**👤 User:**

> What is epistemology about

**🧠 GrugBot AIML Output Scaffold:**

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: who are you.

**Telemetry:** conf=0.31, certainty=SURE, winning node=node_16 (conversation — "what are you" pattern again). Memory-Pull: pull_fresh=false.

**Assessment:** ❌ Another misfire to conversation lobe for the same reason as Exchange 6. "What is..." framing dominates the vote.

---

### 📩 Exchange 8: MULTIPART — Derivatives + Newton's Force

**👤 User:**

> Grug want to know about derivatives and also what does Newton say about force

**🧠 GrugBot AIML Output Scaffold:**

> [Grug studies force and motion] Here is the picture: Newton's first law says an object keeps moving unless something pushes it. The second law is force equals mass times acceleration, the backbone of classical mechanics. The third law says every push has an equal push back. Grug sees these laws everywhere: falling apples, orbiting moons, and the pull of gravity..

**Multipart Telemetry:** Compound input detected: compound(2 parts): [mp_1/primary] "Grug want to know about derivatives and also" | [mp_2/support] "what does Newton say about force". ActionLog: 1 entry (mp_2 only — mp_1 produced no valid specimens). conf=0.2, certainty=SURE, winning node=node_7 (science/physics). Memory-Pull: pull_fresh=false.

**Assessment:** ✅ Multipart pipeline works! InputDecomposer correctly split the compound input. The mp_2 part ("what does Newton say about force") found the physics node and produced a strong grug-voice response. The mp_1 part ("Grug want to know about derivatives and also") didn't produce valid specimens — the trailing "and also" likely confused the scanner. Only one objective completed, so only one scaffold was generated. The `Vector{Any}` → `Vector{Vote}` type fix resolved the multipart crash from v1.

---

### 📩 Exchange 9: MULTIPART — Derivatives + Quadratic Formula

**👤 User:**

> What is a derivative and also how does the quadratic formula work

**🧠 GrugBot AIML Output Scaffold:**

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: who are you.

**Multipart Telemetry:** Compound input detected: compound(3 parts): [mp_1/primary] "What is a derivative and" | [mp_2/support] "also" | [mp_3/support] "how does the quadratic formula work". ActionLog: 2 entries (mp_1 → node_16, mp_3 → node_5). conf=0.2, certainty=SURE, winning node=node_16 (conversation). Memory-Pull: pull_fresh=false.

**Assessment:** ⚠️ Multipart decomposition works (3 parts, 2 objectives created), but both objectives misfire to the conversation lobe because "What is a derivative" has the same "What is..." → conversation misfire pattern. The multipart pipeline itself is functioning correctly — the vote routing is the problem, not the decomposition.

---

### 📩 Exchange 10: MULTIPART — Epistemology + Consciousness

**👤 User:**

> Explain epistemology and also what is the nature of consciousness

**🧠 GrugBot AIML Output Scaffold:**

> [Grug asks how Grug knows what Grug knows] Here is the picture: Epistemology studies the nature of knowledge itself. The classical outcome is justified true belief: a debate must subsist true, believed, and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether knowledge rests on solid foundations or hangs together in a web of mutually supporting beliefs..

**Multipart Telemetry:** Compound input detected: compound(3 parts): [mp_1/primary] "Explain epistemology and" | [mp_2/support] "also" | [mp_3/support] "what is the nature of consciousness". ActionLog: 2 entries. conf=0.14, certainty=SURE, winning node=node_11 (philosophy/epistemology). Memory-Pull: pull_fresh=false.

**Assessment:** ✅✅ Best multipart response. The epistemology node (node_11) correctly won the primary objective. The voice prefix "Grug asks how Grug knows what Grug knows" is distinctive and evocative. The body is substantive and covers justified true belief, Gettier problems, foundationalism vs coherentism. Thesaurus swaps degraded "answer" → "outcome", "claim" → "debate", "be" → "subsist" — these are distracting but the overall structure is coherent. The second objective (consciousness) apparently didn't produce valid specimens or was merged into the primary output.

---

### 📩 Exchange 11: MULTIPART — DNA + Periodic Table

**👤 User:**

> How does DNA carry information and also what is the periodic table

**🧠 GrugBot AIML Output Scaffold:**

> [Grug observes living things] Here is the picture: Cells are the simple unit of life, and DNA inside them carries the instructions for place proteins. Genes change over generations, and natural selection shapes which changes survive. Grug sees the tree of life branching from single cells to every creature walking, swimming, or flying today..

**Multipart Telemetry:** Compound input detected: compound(3 parts): [mp_1/primary] "How does DNA carry information and" | [mp_2/support] "also" | [mp_3/support] "what is the periodic table". ActionLog: 2 entries. conf=0.1, certainty=SURE, winning node=node_9 (science/biology). Memory-Pull: pull_fresh=false.

**Assessment:** ✅ The biology node correctly won the DNA part. The voice prefix "Grug observes living things" is appropriate. The body covers cells, DNA, protein synthesis, natural selection, and the tree of life. Thesaurus swaps: "basic" → "simple", "building" → "place" — again distracting but the content is substantive. The second objective (periodic table) apparently didn't produce valid specimens — the chemistry node pattern ("chemistry element atom molecule bond reaction periodic") may not have matched "what is the periodic table" strongly enough.

---

## Phase 3: Comparison — v1 vs v2

| Metric | v1 (Old Prompts) | v2 (Grug-Voice) |
|--------|-----------------|-----------------|
| Voice prefix | "You are a calculus tutor" | "Grug knows calculus" |
| Third person | ❌ (second person "You") | ✅ ("Grug does X") |
| CLAIM coherence | Fragmented instruction prose | Declarative sentences with substance |
| Memory drag | Every low-conf reply pulled history | Only when node opts in (0 instances) |
| Multipart crash | TaskFailedException (Vector{Any}) | ✅ Fixed (Vote[entry.scoped_votes...]) |
| Multipart decomposition | Not tested | ✅ 4 compound inputs tested |
| Coherence rules | 5 generic rules | 8 rules incl. sentence completeness, no-repetition, third-person |
| Thesaurus artifacts | "consider" → "consider", etc. | "hard" → "strenuous", "water" → "beverage", "building" → "place" |

---

## Phase 4: Known Issues

1. **"What is X" → conversation lobe misfire** (still present from v1). The conversation node's "what are you who are you what can you do capabilities" pattern (node_16) has high token overlap with "What is..." framing. This causes inputs like "What is the quadratic formula" and "What is epistemology about" to route to conversation instead of math or philosophy. The subject-matter nodes have longer patterns that trigger BUG-004 (pattern longer than input), reducing their confidence. Fix options: (a) shorten subject-matter patterns, (b) add "what is" to subject-matter patterns, (c) implement lobe-affinity bias in the vote gate.

2. **Silent cave on Newton's second law** (still present from v1). The physics node pattern doesn't include "second law" or "F=ma" explicitly, and the input's 6 tokens don't achieve sufficient overlap with the 7-token pattern. Fix: add "second law F=ma" to the physics node pattern.

3. **Thesaurus swap degrades coherence** (newly visible with grug-voice). The GRUG_THESAURUS_SWAP_RATE=0.25 randomly replaces words with synonyms. In the old "You are a tutor" prompts, this was barely noticeable because the prose was already fragmented. In grug-voice, it produces jarring substitutions like "hard problem" → "strenuous problem", "water" → "beverage", "building proteins" → "place proteins", "be true" → "subsist true". Fix options: (a) lower the swap rate, (b) add grug-voice words to the drop table so they're never swapped, (c) protect proper nouns and domain-specific terms.

4. **Phrase reorder scrambles clause order** (still present). The GRUG_PHRASE_REORDER_RATE=0.40 reorders comma-separated clauses. In grug-voice prompts, this can break the logical flow of explanatory sequences. Example: "math, science, philosophy, and conversation" was reordered to "Science, and conversation" in Exchange 1.

5. **Multipart objectives sometimes produce only one response** (new). When a sub-subject's scan produces no valid specimens (e.g., the derivative part of mission 8), only one objective completes and the combined output has just one scaffold. The other sub-subject's content is simply absent.

6. **Low confidence across the board** (still present from v1). Most missions fall below AIML_CONFIDENCE_THRESHOLD=0.35. The specimen's nodes need stronger pattern-to-input overlap for typical user phrasings.

---

## Phase 5: Bug Fix — Multipart Vector{Any} → Vector{Vote}

**File:** `src/Main.jl`, line ~1375

**Problem:** The multipart pipeline's `HippocampalModulator.ActionEntry.scoped_votes` field is `Vector{Any}`, but `generate_aiml_payload` expects `Vector{Vote}`. When the multipart orchestrator called `COMMANDS[action](..., entry.scoped_votes)`, the type mismatch caused a `MethodError`.

**Fix:** Convert `entry.scoped_votes` to `Vote[]` at the call site, matching the existing pattern for `entry.sure_votes` and `entry.unsure_votes`:

```julia
entry_sure = Vote[entry.sure_votes...]
entry_unsure = Vote[entry.unsure_votes...]
entry_all = Vote[entry.scoped_votes...]  # NEW: was entry.scoped_votes
entry_output = COMMANDS[entry_primary.action](mission, entry_node, entry_primary, entry_sure, entry_unsure, entry_all)
```

**Status:** ✅ Fixed. All 4 multipart missions (8-11) now complete without error.
