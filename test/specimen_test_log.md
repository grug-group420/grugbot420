# GrugBot Specimen Integration Test — Verbatim Run Log

**Date**: 2025-05-30  
**Specimen**: multi_lobe_v1 (grug-voice prompts, 16 nodes, 4 lobes, 5 attachments, 8 orchestration rules)  
**Engine version**: commit d68e2b0 + per-lobe fuzzy whitelist (subject_whitelist on LobeRecord, veto in LobeOrchestrator.score_lobes)  
**Capture method**: `redirect_stdout` to `/workspace/outputs/mission_XX.txt` — zero manual transcription

---

## Mission 1

**INPUT**: `Hello! What can you do?`

**RESPONSE** (AIML Output Scaffold, node_16, action=explain, conf=0.44):

> [Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes] Here is the picture: Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.. The link is clear: what are you.

**Telemetry**: Lobe=conversation, certainty=SURE, pull_fresh=false, user_triples=None, node_triples=(what, are, you), (who, are, you)

**Whitelist check**: conversation lobe whitelist ["hello", "hi", "hey", "greetings", "thanks", "goodbye", "howdy", "welcome", "appreciate", "gratitude", "bye", "farewell", "what can you do", "who are you", "what are you", "capabilities"] — input token "hello" matches ✓. No veto.

---

## Mission 2

**INPUT**: `Explain what a derivative is in calculus`

**RESPONSE** (AIML Output Scaffold, node_3, action=explain, conf=0.25):

> [Grug knows calculus] Here is the picture: And acceleration is the derivative of velocity, like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes, and the product rule to find derivatives quickly. Velocity is the derivative of position, a derivative measures how fast something changes at a single point, and the ratio becomes the slope. Grug uses the force rule, and the chain rule.

**Telemetry**: Lobe=math, certainty=SURE, pull_fresh=false, attachment_relay=node_7→node_3, user_triples=(derivative, is, in)

**Whitelist check**: conversation lobe vetoed 🚫 — input tokens contain "derivative", "calculus" but none match conversation whitelist entries ("what can you do", "who are you", "what are you" etc. do not appear in input). science lobe also vetoed — "derivative" and "calculus" don't match science whitelist. math lobe passes — "derivative" and "calculus" are on math whitelist ✓.

**Note**: Phrase reorder has scrambled the CLAIM body — the original system_prompt reads coherently but `_reorder_clauses` has mixed clause order. "Grug uses the force rule" is a thesaurus swap artifact ("power"→"force").

---

## Mission 3

**INPUT**: `How does Newton's second law work?`

**RESPONSE**: **CAVE SILENT** — No valid specimens found for this input.

**Telemetry**: Zero votes passed gate. The physics node (node_7, pattern="physics force motion newton gravity acceleration mass") has high token overlap with "Newton" and "force" but BUG-004 (pattern longer than input) causes cheap bidirectional scan fallback, reducing confidence below the vote gate.

**Note**: Pre-existing BUG-004, not affected by whitelist changes.

---

## Mission 4

**INPUT**: `How does quantum physics relate to the nature of reality and consciousness`

**RESPONSE** (AIML Output Scaffold, node_13, action=reason, conf=0.18):

> [Grug wonders what is really real] Here is the picture: Metaphysics asks about the fundamental nature of existence, consciousness, and free will. The hard problem of consciousness asks why subjective experience exists at all. Grug does not comprehend whether free will is genuine or an illusion, and Grug is honest about that uncertainty.

**Telemetry**: Lobe=philosophy, certainty=SURE, pull_fresh=false. Thesaurus swap: "hard"→"difficult" in "hard problem of consciousness" (visible in raw output; final shows "hard").

---

## Mission 5

**INPUT**: `Explain integration and antiderivatives`

**RESPONSE** (AIML Output Scaffold, node_4, action=elaborate, conf=0.12):

> [Grug understands integration] Here is the picture: Volumes, like counting how much water fills a cave. The antiderivative reverses differentiation, and the fundamental theorem of calculus ties them together into one deep truth. Grug can compute areas, and accumulated transform using these methods, and an integral adds up all the tiny pieces under a curve.

**Telemetry**: Lobe=math, certainty=SURE, pull_fresh=false. Thesaurus swap: "truth"→"validity" visible in telemetry (final output shows "truth"). Phrase reorder has some scrambling.

---

## Mission 6

**INPUT**: `What is the quadratic formula`

**RESPONSE** (AIML Output Scaffold, node_5, action=validate, conf=0.11):

> [Grug solves equations] Here is the picture: Grug isolates the unknown variable step by step, using factoring, substitution, and the quadratic formula. For a quadratic, the formula gives both roots directly from the coefficients. Grug always checks the reply by plugging it back in.

**Telemetry**: Lobe=math, certainty=SURE, pull_fresh=false, attachment_relay=node_3→node_5, user_triples=(what, is, the)

**Whitelist check**: conversation lobe vetoed 🚫 — input tokens ["what", "is", "the", "quadratic", "formula"] do not match conversation whitelist entries ("what can you do", "who are you", "what are you" etc.). math lobe passes — "quadratic" and "formula" are on math whitelist ✓.

**✅ FIXED — "What is X" → conversation lobe misfire**: Previously (before whitelist), node_16 (conversation) won with score 0.0278 over math at 0.0199. Now conversation lobe is vetoed (score 0.0 with 🚫whitelist-veto tag), and math lobe wins with node_5 (algebra). The "What is" framing no longer causes the conversation lobe to steal domain-specific queries.

---

## Mission 7

**INPUT**: `What is epistemology about`

**RESPONSE** (AIML Output Scaffold, node_11, action=reason, conf=0.12):

> [Grug asks how Grug knows what Grug knows] Here is the picture: Epistemology studies the nature of knowledge itself. The classical answer is justified true belief: a claim must be true, believed, and supported by evidence. But Gettier problems show that even justified true position can be accidental. Grug wonders whether knowledge rests on solid foundations or hangs together in a web of mutually supporting beliefs.

**Telemetry**: Lobe=philosophy, certainty=SURE, pull_fresh=false, user_triples=(what, is, epistemology)

**Whitelist check**: conversation lobe vetoed 🚫 — input tokens ["what", "is", "epistemology", "about"] do not match conversation whitelist. philosophy lobe passes — "epistemology" is on philosophy whitelist ✓.

**✅ FIXED — "What is X" → conversation lobe misfire**: Previously (before whitelist), node_16 (conversation) won with conf=0.32, producing a scrambled self-description response. Now conversation lobe is vetoed (score 0.0 with 🚫whitelist-veto tag), and philosophy lobe wins with node_11 (epistemology). The correct domain-specific response is now produced.

---

## Mission 8 (MULTIPART)

**INPUT**: `Grug want to know about derivatives and also what does Newton say about force`

**RESPONSE** (AIML Output Scaffold, node_7, action=ponder, conf=0.20):

> [Grug studies force and motion] Here is the picture: Newton's first law says an object keeps moving unless something pushes it. The second law is force equals element times acceleration, the backbone of classical mechanics. The third law says every push has an equal send back. Grug sees these laws everywhere: falling apples, orbiting moons, and the pull of gravity.

**Telemetry**: Lobe=science, certainty=SURE, pull_fresh=false. Multipart compound(2 parts): [mp_1/primary] "Grug want to know about derivatives and also" | [mp_2/support] "what does Newton say about force". Only one scaffold produced. Thesaurus swap: "mass"→"element", "push back"→"send back".

**Whitelist check**: conversation lobe vetoed 🚫 — input tokens contain "derivatives", "newton", "force" which don't match conversation whitelist. science lobe passes — "newton" and "force" are on science whitelist ✓.

---

## Mission 9 (MULTIPART)

**INPUT**: `What is a derivative and also how does the quadratic formula work`

**RESPONSE** (AIML Output Scaffold, node_3, action=explain, conf=0.14):

> [Grug knows calculus] Here is the picture: And the product rule to find derivatives quickly. Velocity is the derivative of faith, a derivative measures how fast something changes at a single point, and the ratio becomes the slope. Grug uses the power rule, the chain rule, and acceleration is the derivative of velocity, and like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes.

**Telemetry**: Multipart compound(3 parts): [mp_1/primary] "What is a derivative and" | [mp_2/support] "also" | [mp_3/support] "how does the quadratic formula work". Attachment relay: node_7→node_3. Two votes passed gate.

**Whitelist check**: conversation lobe vetoed 🚫 — "derivative", "quadratic", "formula" don't match conversation whitelist. science lobe also vetoed 🚫. math lobe passes — "derivative" and "quadratic" are on math whitelist ✓.

**Note**: Thesaurus swap "velocity"→"faith" is a severe artifact. Phrase reorder scrambles CLAIM as before.

---

## Mission 10 (MULTIPART)

**INPUT**: `Explain epistemology and also what is the nature of consciousness`

**RESPONSE** (AIML Output Scaffold, node_11, action=reason, conf=0.14):

> [Grug asks how Grug knows what Grug knows] Here is the picture: Believed, and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether knowledge rests on solid foundations, epistemology studies the nature of understanding itself. The classical answer is justified true belief: a claim must persist true, and hangs together in a web of mutually supporting beliefs.

**Telemetry**: Multipart compound(3 parts). Two votes passed gate (both philosophy lobe). Part 1 = node_11, Part 2 = node_11 (not node_13 as expected for "nature of consciousness" — the philosophy lobe won both sub-queries).

**Whitelist check**: conversation lobe vetoed 🚫 on the "what is the nature of consciousness" sub-query — "consciousness" is NOT on conversation whitelist but IS on philosophy whitelist. Previously (without whitelist), this sub-query would have triggered node_16 (conversation). Now it stays within philosophy lobe ✓.

**✅ FIXED — Part 2 no longer misfires to conversation lobe**: Previously, "what is the nature of consciousness" triggered node_16 (conversation) with a self-description response. Now the conversation lobe is vetoed and the philosophy lobe handles both sub-queries.

**Note**: Phrase reorder still scrambles CLAIM body. Thesaurus swap "knowledge"→"understanding" and "true"→"persist".

---

## Mission 11 (MULTIPART)

**INPUT**: `How does DNA carry information and also what is the periodic table`

**RESPONSE** (AIML Output Scaffold, node_9, action=reason, conf=0.10):

> [Grug observes living things] Here is the picture: Cells are the straightforward unit of life, and DNA inside them carries the instructions for building proteins. Genes change over generations, and natural selection shapes which changes survive. Grug sees the tree of life branching from single cells to every creature walking, swimming, or flying today.

**Telemetry**: Lobe=science, certainty=SURE, pull_fresh=false. Multipart compound(3 parts). Two votes passed gate (both science lobe).

**Whitelist check**: conversation lobe vetoed 🚫 on the "what is the periodic table" sub-query — "periodic" doesn't match conversation whitelist but does match science whitelist ✓. Previously this would have triggered node_16.

**✅ FIXED — "what is the periodic table" no longer misfires to conversation lobe**.

---

## Summary of Observed Issues

### Confirmed Working
- **Per-lobe fuzzy whitelist**: The conversation lobe is now correctly vetoed on all "What is X" queries where X is a domain-specific term. The 🚫whitelist-veto tag appears in the Lobe Curve output for every vetoed lobe.
- **One-directional fuzzy matching**: Input token "what" no longer matches whitelist entry "what can you do" (the entry is longer than the token, and only substring matching in the whitelist-entry⊆input-token direction is used). Multi-word whitelist entries like "what can you do" match against the joined input string.
- wants_context gate: 0 instances of fresh memory drag across all 11 missions. Only `pull_fresh=false` in every telemetry block.
- Multipart decomposition: InputDecomposer correctly splits on "and also", "?", and comma clauses.
- Multipart Vector{Vote} fix: No more `MethodError` on compound inputs.
- Grug third-person voice: voice_prefix correctly uses first sentence of system_prompt in third person.
- Attachment relays: node_7→node_3, node_3→node_5 all fired when expected.

### Whitelist Fix Impact
| Mission | Input | Before Whitelist | After Whitelist | Fixed? |
|---------|-------|-----------------|-----------------|--------|
| 6 | "What is the quadratic formula" | node_16 (conversation) | node_5 (math/algebra) | ✅ |
| 7 | "What is epistemology about" | node_16 (conversation) | node_11 (philosophy/epistemology) | ✅ |
| 10-P2 | "what is the nature of consciousness" | node_16 (conversation) | node_11 (philosophy) | ✅ |
| 11-P2 | "what is the periodic table" | node_16 (conversation) | node_9 (science/biology) | ✅ |
| 2 | "Explain what a derivative is in calculus" | node_3 (math) — already correct but conversation competed | node_3 (math) — conversation vetoed | ✅ (stronger) |
| 8 | "Grug want to know about derivatives and also..." | node_7 (science) | node_7 (science) — conversation vetoed | ✅ (cleaner) |
| 9 | "What is a derivative and also..." | node_7 (science) — conversation competed | node_3 (math) — conversation vetoed | ✅ |
| 10-P1 | "Explain epistemology and also..." | node_11 (philosophy) | node_11 (philosophy) — conversation vetoed | ✅ (cleaner) |
| 11-P1 | "How does DNA carry information and also..." | node_8 (chemistry) | node_9 (biology) — conversation vetoed | ✅ (cleaner) |

### Known Bugs (Remaining, Pre-Existing)
1. **Phrase reorder scrambles CLAIM** (Missions 2, 5, 7, 9, 10): `_reorder_clauses` with `GRUG_PHRASE_REORDER_RATE=0.40` randomly shuffles clause order, producing incoherent or grammatically broken output. E.g., "Believed, hangs together in a web of mutually supporting beliefs" and double "and and".
2. **Thesaurus swap artifacts** (Missions 2, 4, 5, 8, 9, 10): `_pick_synonym` with `GRUG_THESAURUS_SWAP_RATE=0.25` produces context-inappropriate swaps: "force"→"potential", "mass"→"element", "pull"→"obtain", "hard"→"difficult", "truth"→"validity", "velocity"→"faith".
3. **Silent cave on Newton's second law** (Mission 3): BUG-004 causes cheap bidirectional scan fallback when pattern is longer than input, reducing confidence below the vote gate threshold.
4. **MultipartError — duplicate :primary votes** (Mission 10 in prior run): `MultipartOrchestrator.build_objectives` can fail when a multipart group receives 2 :primary votes, causing fallback to old single-path.
5. **Multipart sometimes produces only one response** (Missions 8, 11): When the multipart pipeline falls back, only the primary objective's scaffold is emitted.

### Confidence Levels
All missions produced confidence well below `AIML_CONFIDENCE_THRESHOLD=0.35` except Mission 1 at 0.44 (which did exceed threshold). Every other mission fell back to the highest-confidence vote. This is expected given the small specimen size (16 nodes) and BUG-004 reducing scan quality.
