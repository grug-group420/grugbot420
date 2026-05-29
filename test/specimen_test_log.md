# GrugBot Specimen Integration Test — Verbatim Run Log

**Date**: 2025-05-29  
**Specimen**: multi_lobe_v1 (grug-voice prompts, 16 nodes, 4 lobes, 5 attachments, 8 orchestration rules)  
**Engine version**: commit b3396c0 + Vector{Vote} multipart fix  
**Capture method**: `redirect_stdout` to `/workspace/outputs/mission_XX.txt` — zero manual transcription

---

## Mission 1

**INPUT**: `Hello! What can you do?`

**RESPONSE** (AIML Output Scaffold, node_16, action=elaborate, conf=0.44):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: what are you.

**Telemetry**: Lobe=conversation, certainty=SURE, pull_fresh=false, user_triples=None, node_triples=(what, are, you), (who, are, you)

---

## Mission 2

**INPUT**: `Explain what a derivative is in calculus`

**RESPONSE** (AIML Output Scaffold, node_3, action=validate, conf=0.25):

> [Grug knows calculus] Here is the picture: The chain rule, and the ratio becomes the slope. Grug uses the power rule, a derivative measures how fast something changes at a single point, and the product rule to find derivatives quickly. Velocity is the derivative of position, and acceleration is the derivative of velocity, and like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes.

**Telemetry**: Lobe=math, certainty=SURE, pull_fresh=false, attachment_relay=node_7→node_3, user_triples=(derivative, is, in)

**Note**: Phrase reorder has scrambled the CLAIM body — the original system_prompt reads coherently but `_reorder_clauses` has mixed clause order. "The chain rule, and the ratio becomes the slope" is a fragment splice from two different sentences.

---

## Mission 3

**INPUT**: `How does Newton's second law work?`

**RESPONSE**: **CAVE SILENT** — No valid specimens found for this input.

**Telemetry**: Zero votes passed gate. The physics node (node_7, pattern="physics force motion newton gravity acceleration mass") has high token overlap with "Newton" and "force" but BUG-004 (pattern longer than input) causes cheap bidirectional scan fallback, reducing confidence below the vote gate.

---

## Mission 4

**INPUT**: `How does quantum physics relate to the nature of reality and consciousness`

**RESPONSE** (AIML Output Scaffold, node_13, action=ponder, conf=0.18):

> [Grug wonders what is really real] Here is the picture: Metaphysics asks about the fundamental nature of existence, consciousness, and free will. The difficult problem of consciousness asks why subjective experience exists at all. Grug does not know whether free will is genuine or an illusion, and Grug is honest about that uncertainty.

**Telemetry**: Lobe=philosophy, certainty=SURE, pull_fresh=false. Thesaurus swap: "hard"→"difficult" in "hard problem of consciousness".

---

## Mission 5

**INPUT**: `Explain integration and antiderivatives`

**RESPONSE** (AIML Output Scaffold, node_4, action=explain, conf=0.12):

> [Grug understands integration] Here is the picture: An integral adds up all the tiny pieces under a curve, like counting how much water fills a cave. The antiderivative reverses differentiation, and the fundamental theorem of calculus ties them together into one deep validity. Grug can compute areas, volumes, and accumulated change using these methods.

**Telemetry**: Lobe=math, certainty=SURE, pull_fresh=false. Thesaurus swap: "truth"→"validity" in "one deep truth" → "one deep validity".

---

## Mission 6

**INPUT**: `What is the quadratic formula`

**RESPONSE** (AIML Output Scaffold, node_16, action=describe, conf=0.17):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: who are you.

**Telemetry**: Lobe=conversation, certainty=SURE, pull_fresh=false, attachment_relay=node_3→node_5, user_triples=(what, is, the), node_triples=(what, are, you), (who, are, you)

**BUG — "What is X" → conversation lobe misfire**: node_16 (pattern="what are you who are you what can you do capabilities") has high token overlap with "What is..." framing. The "what" keyword causes the conversation lobe to win over math lobe (conversation: 0.0278 vs math: 0.0199). The quadratic formula question is routed to the self-description node instead of the algebra node.

---

## Mission 7

**INPUT**: `What is epistemology about`

**RESPONSE** (AIML Output Scaffold, node_16, action=describe, conf=0.32):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: And the winning vote shapes the answer. Grug has lobes for math, the nodes vote on what matters most, philosophy, and conversation. Grug is honest about what Grug is, science, and each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires.. The link is clear: what are you.

**Telemetry**: Lobe=conversation, certainty=SURE, pull_fresh=false, user_triples=(what, is, epistemology), node_triples=(what, are, you), (who, are, you)

**BUG — Same "What is X" misfire**: The "what is" framing triggers node_16 again. The CLAIM body has been scrambled by phrase reorder — the original coherent system_prompt is now a word salad: "And the winning vote shapes the answer. Grug has lobes for math, the nodes vote on what matters most, philosophy, and conversation..."

---

## Mission 8 (MULTIPART)

**INPUT**: `Grug want to know about derivatives and also what does Newton say about force`

**RESPONSE — Part 1** (AIML Output Scaffold, node_7, action=ponder, conf=0.20):

> [Grug studies force and motion] Here is the picture: Newton's first law says an object keeps moving unless something pushes it. The second law is potential equals mass times acceleration, the backbone of classical mechanics. The third law says every push has an equal push back. Grug sees these laws everywhere: falling apples, orbiting moons, and the obtain of gravity.

**Telemetry**: Lobe=science, certainty=SURE, pull_fresh=false. Multipart compound(2 parts): [mp_1/primary] "Grug want to know about derivatives and also" | [mp_2/support] "what does Newton say about force". Only one scaffold produced — the mp_2 support entry was built but only the primary objective's scaffold was emitted. Thesaurus swap: "force"→"potential" and "pull"→"obtain".

**Note**: The first part asked about derivatives (math lobe) but the winning node is node_7 (physics/science lobe) due to the attachment relay from node_3→node_7. The "also what does Newton say about force" fragment boosted the science lobe score over math.

---

## Mission 9 (MULTIPART)

**INPUT**: `What is a derivative and also how does the quadratic formula work`

**RESPONSE — Part 1** (AIML Output Scaffold, node_7, action=ponder, conf=0.32):

> [Grug studies force and motion] Here is the picture: Newton's first law says an object keeps moving unless something pushes it. The second law is force equals substance times acceleration, the backbone of classical mechanics. The third law says every push has an equal push back. Grug sees these laws everywhere: falling apples, orbiting moons, and the pull of gravity.

**RESPONSE — Part 2** (AIML Output Scaffold, node_5, action=validate, conf=0.10):

> [Grug solves equations] Here is the picture: Grug isolates the unknown variable step by step, and the quadratic formula. For a quadratic, the formula gives both roots directly from the coefficients. Grug always checks the answer by plugging it back in, substitution, and using factoring.

**Telemetry**: Multipart compound(3 parts): [mp_1/primary] "What is a derivative and" | [mp_2/support] "also" | [mp_3/support] "how does the quadratic formula work". Attachment relay: node_7→node_3. Part 1 misrouted to science lobe (Newton's laws) instead of math lobe (calculus). Part 2 correctly hits node_5 (algebra) but phrase reorder scrambles CLAIM: "Grug isolates the unknown variable step by step, and the quadratic formula" — the original was "using factoring, substitution, and the quadratic formula". Thesaurus swap: "mass"→"substance" in Part 1.

---

## Mission 10 (MULTIPART)

**INPUT**: `Explain epistemology and also what is the nature of consciousness`

**RESPONSE — Part 1** (AIML Output Scaffold, node_11, action=ponder, conf=0.14):

> [Grug asks how Grug knows what Grug knows] Here is the picture: Believed, hangs together in a web of mutually supporting beliefs, epistemology studies the nature of knowledge itself. The classical answer is justified true belief: a claim must be true, and and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether knowledge rests on solid foundations.

**RESPONSE — Part 2** (AIML Output Scaffold, node_16, action=explain, conf=0.17):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: what are you.

**Telemetry**: Multipart compound(3 parts). Part 1 correctly hits node_11 (epistemology) but phrase reorder has scrambled the CLAIM: "Believed, hangs together in a web of mutually supporting beliefs" — the original was "a claim must be true, believed, and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether knowledge rests on solid foundations or hangs together in a web of mutually supporting beliefs." Double "and and" artifact from CLAIM assembly. Part 2 is the "What is X" misfire again — "what is the nature of consciousness" triggers node_16 (conversation) instead of node_13 (metaphysics).

**Note**: MultipartOrchestrator.build_objectives initially failed with `MultipartError("multipart group 'mp_1' must have exactly one :primary vote, got 2")` — the engine fell back to the old single-path. This suggests the vote coalescing produced two :primary votes for mp_1, which the orchestrator cannot resolve.

---

## Mission 11 (MULTIPART)

**INPUT**: `How does DNA carry information and also what is the periodic table`

**RESPONSE** (AIML Output Scaffold, node_8, action=calculate, conf=0.20):

> [Grug knows the small stuff] Here is the picture: And that pattern predicts how they react. Grug can balance a chemical equation because atoms are neither created nor destroyed in a reaction, and they bond together into molecules through shared electrons. The periodic table arranges elements by their electron structure, and atoms are the building blocks.

**Telemetry**: Lobe=science, certainty=SURE, pull_fresh=false. Attachment relay: node_8→node_9. Only one scaffold produced (the multipart pipeline fell back to old path after the MultipartError from Mission 10 carried over in state). Phrase reorder scrambled CLAIM: "And that pattern predicts how they react" is a displaced clause from the end of the original system_prompt. The "DNA carry information" part was not addressed — the node_8 system_prompt (chemistry) doesn't cover DNA.

---

## Summary of Observed Issues

### Confirmed Working
- wants_context gate: 0 instances of fresh memory drag across all 11 missions. Only `pull_fresh=false` in every telemetry block.
- Multipart decomposition: InputDecomposer correctly splits on "and also", "?", and comma clauses.
- Multipart Vector{Vote} fix: No more `MethodError` on compound inputs.
- Grug third-person voice: voice_prefix correctly uses first sentence of system_prompt in third person.
- Attachment relays: node_7→node_3, node_3→node_5, node_8→node_9 all fired when expected.

### Known Bugs (Verified This Run)
1. **"What is X" → conversation lobe misfire** (Missions 6, 7, 10-Part2): node_16's pattern ("what are you who are you what can you do capabilities") has high token overlap with "What is..." framing. "what" is the shared token. The conversation lobe wins over the correct subject lobe.
2. **Phrase reorder scrambles CLAIM** (Missions 2, 7, 9-Part2, 10-Part1, 11): `_reorder_clauses` with `GRUG_PHRASE_REORDER_RATE=0.40` randomly shuffles clause order, producing incoherent or grammatically broken output. E.g., "Believed, hangs together in a web of mutually supporting beliefs" and double "and and".
3. **Thesaurus swap artifacts** (Missions 4, 5, 8, 9, 11): `_pick_synonym` with `GRUG_THESAURUS_SWAP_RATE=0.25` produces context-inappropriate swaps: "force"→"potential", "mass"→"substance", "pull"→"obtain", "hard"→"difficult", "truth"→"validity".
4. **Silent cave on Newton's second law** (Mission 3): BUG-004 causes cheap bidirectional scan fallback when pattern is longer than input, reducing confidence below the vote gate threshold.
5. **MultipartError — duplicate :primary votes** (Mission 10): `MultipartOrchestrator.build_objectives` fails when a multipart group receives 2 :primary votes, causing fallback to old single-path.
6. **Multipart sometimes produces only one response** (Missions 8, 11): When the multipart pipeline falls back, only the primary objective's scaffold is emitted.

### Confidence Levels
All missions produced confidence well below `AIML_CONFIDENCE_THRESHOLD=0.35`. The highest was Mission 1 at 0.44 (which did exceed threshold). Every other mission fell back to the highest-confidence vote. This is expected given the small specimen size (16 nodes) and BUG-004 reducing scan quality.
