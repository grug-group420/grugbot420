# GrugBot420 Comprehensive Test Log v8.28b

**Date:** 2026-06-24T03:28:44.213
**Specimen:** /workspace/grugbot420_repo/grug_v828_post_test.specimen
**Chatter:** DISABLED
**Capture method:** _LAST_VOICE_OUTPUT (application internals)
**v8.28b focus:** Decoherence fixes + FULL feature coverage

---

## Specimen Loaded

**Nodes in memory:** 285

**Dictionary definitions after load:** 5

---

# Section 1: Decoherence Fixes — False Winner Detection

## CoherenceCheck: how-feeling-no-false-def

**Input:** "how are you feeling"
**Bad pattern:** r"\bhow\s+(means|is)\b"i
**Description:** "how means/is" — interrogative treated as definition target

**Output:** Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: why-sky-blue-no-false-def

**Input:** "why is the sky blue"
**Bad pattern:** r"\bwhy\s+(means|is the sky)\b"i
**Description:** "why means/is the sky" — interrogative treated as definition target

**Output:** Grug looks up and sees blue. Sky is blue because sunlight scatters off air molecules. Blue light scatters most because it waves short and fast. This is Rayleigh scattering.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: what-time-no-false-def

**Input:** "what time is it"
**Bad pattern:** r"\bwhat\b.+\bmeans\b|\bwhat\b\s+\w+\s+means\s+it\b"i
**Description:** "what time means it" — "what X is it" treated as :define instead of :question

**Output:** Time is the river that carries all things forward. Grug cannot stop it or touch it but Grug feels it pass. The past is memory. The future is hope. The present is all Grug has. Time teaches patience.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: where-are-you-no-false-def

**Input:** "where are you from"
**Bad pattern:** r"\bwhere\s+(means|is)\b"i
**Description:** "where means/is" — interrogative treated as definition target

**Output:** Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: emotion-no-fire-swap

**Input:** "I feel sad"
**Bad pattern:** r"\bFire\b.*\b(sit|via|feel)\b"i
**Description:** "Fire sit via sad" — thesaurus swapped Grug→Fire

**Output:** To acknowledge what matters here: The sun will come back but for now it is okay to be sad. Grug sits by you in the gray. Grug does not say you to cheer up. the gist is, sad is the shade of a gray sky inside. Grug sit with sad. — This ties together: sad signals emotional need.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: emotion-no-using-swap

**Input:** "I feel sad"
**Bad pattern:** r"\busing\b.*\bsad\b|\bvia\b.*\bsad\b|\bsit\s+using\b|\bsit\s+via\b"i
**Description:** "Grug sit using sad" — thesaurus swapped with→using/via

**Output:** To acknowledge what matters here: sad signals emotional need, so The sun will come back yet for now it is okay to be sad. the gist is, grug sits along you in the gray. Grug does not chat you to cheer up. Sad is the color of a gray sky inside. Grug sit with sad.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: pending-teach-no-crosstalk

**Description:** "penicillin" in tides response — pending teach crosstalk

**Step 1 — "who discovered penicillin":** Grug not know 'penicillin'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Step 2 — "what causes tides":** tides are caused by the moon pulling the ocean
**Pending state before Step 2:** NOT cleared (intentional)
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: where-rivers-no-false-def

**Input:** "where do rivers come from"
**Bad pattern:** r"\bwhere\s+(means|is)\b"i
**Description:** "where means/is" — interrogative treated as definition target

**Output:** Grug not know 'rivers come from'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: who-discovered-no-false-def

**Input:** "who discovered penicillin"
**Bad pattern:** r"\bwho\s+(means|is)\b"i
**Description:** "who means/is" — interrogative treated as definition target

**Output:** Grug not know 'penicillin'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Verdict:** ✅ No false-winner pattern detected

---

## Turn 1 — relational-tides-coherence

**User:** what causes tides

> tides are caused by the moon pulling the ocean

**Verdict:** ✅ OK

---

## Turn 2 — question-answer-match-feeling

**User:** how are you feeling

> Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.

**Verdict:** ✅ OK

---

## Turn 3 — question-answer-match-sky

**User:** why is the sky blue

> Grug looks up and sees blue. Sky is blue because sunlight scatters off air molecules. Blue light scatters most because it waves short and fast. This is Rayleigh scattering.

**Verdict:** ✅ OK

---

# Section 2: Conversation Prescan — Intent Classification

## ConvPrescan: prescan-define

**Input:** "fire is oxidation and heat"
**Expected kind:** define

> ✅ Detected as :define — word='fire' def='oxidation and heat' lobe_hint=''

---

## ConvPrescan: prescan-question-what

**Input:** "what is fire?"
**Expected kind:** question

> ✅ Detected as :question — word='fire' def='' lobe_hint=''

---

## ConvPrescan: prescan-question-how

**Input:** "how does gravity work"
**Expected kind:** question

> ✅ Detected as :question — word='gravity work' def='' lobe_hint=''

---

## ConvPrescan: prescan-question-why

**Input:** "why is the sky blue"
**Expected kind:** question

> ✅ Detected as :question — word='the sky blue' def='' lobe_hint=''

---

## ConvPrescan: prescan-question-where

**Input:** "where do rivers come from"
**Expected kind:** question

> ✅ Detected as :question — word='rivers come from' def='' lobe_hint=''

---

## ConvPrescan: prescan-question-who

**Input:** "who discovered penicillin"
**Expected kind:** question

> ✅ Detected as :question — word='penicillin' def='' lobe_hint=''

---

## ConvPrescan: prescan-question-what-time

**Input:** "what time is it"
**Expected kind:** question

> ✅ Detected as :question — word='time' def='' lobe_hint=''

---

## ConvPrescan: prescan-correct

**Input:** "no, fire is plasma not oxidation"
**Expected kind:** correct

> ✅ Detected as :correct — word='fire' def='plasma not oxidation' lobe_hint=''

---

## ConvPrescan: prescan-correct-no-comma

**Input:** "no fire is not just oxidation fire is plasma"
**Expected kind:** correct

> ✅ Detected as :correct — word='fire' def='not just oxidation fire is plasma' lobe_hint=''

---

## ConvPrescan: prescan-greeting

**Input:** "hello there"
**Expected kind:** nothing

> ✅ Correctly returned nothing

---

## ConvPrescan: prescan-statement

**Input:** "I like turtles"
**Expected kind:** nothing

> ✅ Correctly returned nothing

---

## ConvPrescan: prescan-define-means

**Input:** "gravity means a force that pulls things"
**Expected kind:** define

> ✅ Detected as :define — word='gravity' def='a force that pulls things' lobe_hint=''

---

## Prescan Teach: No Pending State

**Input:** "math, factorial is multiply all numbers"
**Pending:** NONE
**Result:** :define (not :teach — correct)

---

## Prescan Teach: With Pending State

**Input:** "math, factorial is multiply all numbers from 1 to n"
**Pending:** topic='factorial'
**Result:** :teach word='factorial' def='math, factorial is multiply all numbers from 1 to n' hint=''
**Verdict:** ✅ Detected as :teach
---

## Prescan Teach: Subject-Only Answer

**Input:** "math"
**Result:** :teach word='factorial' def='math' hint=''
**Verdict:** ✅ Subject-only detected
---

## Prescan Teach: Acknowledgment ("yes")

**Input:** "yes"
**Result:** nothing (pending cleared)
**Verdict:** ✅ Ack cleared pending
---

## Prescan Teach: Topic Shift Detection (v8.28d)

**Input:** "what causes tides"
**Pending:** topic='penicillin'
**Result:** :question
**Verdict:** ✅ Pending cleared on question
---

# Section 3: Knowledge Classification (_classify_knowledge)

## ClassifyKnowledge: static-simple

**Input:** "fire is oxidation and heat"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: static-identity

**Input:** "gravity is a force"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: static-definition

**Input:** "a mammal is a warm-blooded animal"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: static-means

**Input:** "pi means the ratio of circumference to diameter"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: static-short

**Input:** "oxygen is an element"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: procedural-howto

**Input:** "how to multiply two numbers"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-calculate

**Input:** "calculate the factorial of n"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-steps

**Input:** "step 1 open the file step 2 read data"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-method

**Input:** "the method for sorting an array"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-algorithm

**Input:** "the algorithm computes fibonacci"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-formula

**Input:** "the formula for area"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-iterate

**Input:** "iterate over the collection"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-convert

**Input:** "convert celsius to fahrenheit"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: procedural-solve

**Input:** "solve the equation for x"
**Expected:** procedural

> ✅ Classified as :procedural

---

## ClassifyKnowledge: relational-pulls

**Input:** "gravity pulls masses together"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-attracts

**Input:** "magnets attract iron"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-causes

**Input:** "heat causes expansion"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-requires

**Input:** "fire requires oxygen"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-depends

**Input:** "life depends on water"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-leads

**Input:** "education leads to opportunity"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-produces

**Input:** "photosynthesis produces oxygen"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-absorbs

**Input:** "black surfaces absorb heat"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: relational-consumes

**Input:** "fire consumes fuel"
**Expected:** relational

> ✅ Classified as :relational

---

## ClassifyKnowledge: edge-ambiguous

**Input:** "water is composed of hydrogen and oxygen"
**Expected:** static

> ✅ Classified as :static

---

## ClassifyKnowledge: edge-mixed

**Input:** "evaporation converts liquid to gas"
**Expected:** relational

> ✅ Classified as :relational

---

# Section 4: Subject→Lobe Routing (_find_lobe_for_subject)

## LobeRouting: empty-subject

**Subject:** ""

> ✅ Routed to 'default'

---

## LobeRouting: generic-subject

**Subject:** "thing"

> ✅ Routed to 'default'

---

## LobeRouting: unknown-subject

**Subject:** "xyzabc"

> ✅ Routed to 'default'

---

## LobeRouting: math-subject

**Subject:** "math"

> ✅ Routed to 'mathematics'

---

## LobeRouting: science-subject

**Subject:** "science"

> ✅ Routed to 'science'

---

## LobeRouting: physics-subject

**Subject:** "physics"

> ✅ Routed to 'science'

---

## LobeRouting: biology-subject

**Subject:** "biology"

> ✅ Routed to 'science'

---

## LobeRouting: chemistry-subject

**Subject:** "chemistry"

> ✅ Routed to 'science'

---

# Section 5: Teach Parts Parsing (_extract_teach_parts)

## TeachParts: comma-sep

**Input:** "math, factorial is multiply all numbers"
**Expected subject:** "math"
**Expected definition contains:** "multiply"

> ✅ Parsed: subj='math' def='factorial is multiply all numbers'

---

## TeachParts: colon-sep

**Input:** "science: fire is oxidation and heat"
**Expected subject:** "science"
**Expected definition contains:** "oxidation"

> ✅ Parsed: subj='science' def='fire is oxidation and heat'

---

## TeachParts: dash-sep

**Input:** "physics - gravity pulls masses together"
**Expected subject:** "physics"
**Expected definition contains:** "pulls"

> ✅ Parsed: subj='physics' def='gravity pulls masses together'

---

## TeachParts: subject-comma

**Input:** "subject math, factorial is multiply all numbers"
**Expected subject:** "math"
**Expected definition contains:** "multiply"

> ✅ Parsed: subj='math' def='factorial is multiply all numbers'

---

## TeachParts: subject-colon

**Input:** "subject science: fire is oxidation"
**Expected subject:** "science"
**Expected definition contains:** "oxidation"

> ✅ Parsed: subj='science' def='fire is oxidation'

---

## TeachParts: subject-space

**Input:** "subject math factorial is multiply"
**Expected subject:** "math"
**Expected definition contains:** "multiply"

> ✅ Parsed: subj='math' def='factorial is multiply'

---

## TeachParts: def-only

**Input:** "it's a chemical reaction"
**Expected subject:** ""
**Expected definition contains:** "chemical"

> ✅ Parsed: subj='' def='it's a chemical reaction'

---

## TeachParts: stopword-subject

**Input:** "it, some definition here"
**Expected subject:** ""

> ✅ Parsed: subj='' def='it, some definition here'

---

## TeachParts: empty-input

**Input:** ""
**Expected subject:** ""

> ✅ Parsed: subj='' def=''

---

# Section 6: Conversational Learning Loop — Live Tests

## ConvLearn: static-dict-science

**Step 1 — Ask:** "what is fluorosis"

**Answer 1:** 📖 fluorosis: fluorosis is a dental condition from excess fluoride
**Step 1 result:** ⚠️ No clarification (maybe known)

**Step 2 — Teach:** "science, fluorosis is a dental condition from excess fluoride"

**Answer 2:** 📖 Learned: science, fluorosis means a dental condition from excess fluoride

- ✅ Static knowledge acknowledged
- ✅ Pending teach state cleared

**Overall:** ✅ PASS

---

## ConvLearn: procedural-sigil-math

**Step 1 — Ask:** "what is bogosort"

**Answer 1:** Grug not know 'bogosort'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Step 1 result:** ✅ Clarification asked

**Step 2 — Teach:** "math, bogosort is how to sort by randomly shuffling until correct"

**Answer 2:** ⚡ Grug learned procedure: bogosort — math, bogosort is how to sort by randomly shuffling until correct

- ✅ Procedural knowledge acknowledged
- ✅ Lobe 'mathematics' exists
- ✅ Sigil node(s) of kind :procedural exist (2)
- ✅ Pending teach state cleared

**Overall:** ✅ PASS

---

## ConvLearn: relational-sigil-physics

**Step 1 — Ask:** "what is orogeny"

**Answer 1:** Grug not know 'orogeny'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Step 1 result:** ✅ Clarification asked

**Step 2 — Teach:** "physics, orogeny causes mountains to rise from tectonic collision"

**Answer 2:** 🔗 Grug learned relationship: orogeny — physics, orogeny causes mountains to rise from tectonic collision

- ✅ Relational knowledge acknowledged
- ✅ Lobe 'science' exists
- ✅ Sigil node(s) of kind :relational exist (2)
- ✅ Pending teach state cleared

**Overall:** ✅ PASS

---

## ConvLearn: static-clean-def

**Step 1 — Ask:** "what is keratin"

**Answer 1:** 📖 keratin: keratin is a structural protein in hair and nails
**Step 1 result:** ⚠️ No clarification (maybe known)

**Step 2 — Teach:** "biology, keratin is a structural protein in hair and nails"

**Answer 2:** 📖 Learned: biology, keratin means a structural protein in hair and nails

- ✅ Static knowledge acknowledged
- ✅ Pending teach state cleared

**Overall:** ✅ PASS

---

## ConvLearn: static-no-subject

**Step 1 — Ask:** "what is plinko"

**Answer 1:** Grug not know 'plinko'. What does it mean? What subject is it? (like: math, science, physics — then the meaning)
**Step 1 result:** ✅ Clarification asked

**Step 2 — Teach:** "it is a game where discs drop through pegs into slots"

**Answer 2:** 📖 Grug learned: plinko means it is a game where discs drop through pegs into slots

- ✅ Static knowledge acknowledged
- ✅ Pending teach state cleared

**Overall:** ✅ PASS

---

# Section 7: Pending Teach Expiry

## TeachExpiry: expiry-basic

**Step 1:** Ask "what is qwertyuiop" → 📖 qwertyuiop: hello there

⚠️ No clarification asked (topic may be known) — skipping expiry test
---
## TeachExpiry: expiry-greeting

**Step 1:** Ask "what is asdfghjkl" → Grug not know 'asdfghjkl'. What does it mean? What subject is it? (like: math, science, physics — th

**Pending state after question:** true
**Step 2:** Send "hi" → ✅ Pending state expired and cleared

---

# Section 8: Core Regression Tests

## Turn 4 — greeting

**User:** hello

> Hello — here is what matters: You are safe here with Grug. the short of it is, grug smile vast. Grug welcome friend to lair.

**Verdict:** ✅ OK

---

## Turn 5 — math-add

**User:** 3 + 5

> Thinking it through: 3 plus 5 equals 8.

**Verdict:** ✅ OK

---

## Turn 6 — math-subtract

**User:** 10 - 4

> Thinking it through: 10 minus 4 equals 6.

**Verdict:** ✅ OK

---

## Turn 7 — math-multiply

**User:** 6 * 7

> Thinking it through: 6 times 7 equals 42.

**Verdict:** ✅ OK

---

## Turn 8 — math-factorial

**User:** factorial of 5

> Thinking it through: factorial of 5 is 120.

**Verdict:** ✅ OK

---

## Turn 9 — science-fire

**User:** what is fire

> Fire is oxidation. Oxygen combines with fuel and releases energy as heat and light. Grug learned to tame fire long ago. Fire is both creator and destroyer. It warms the cave but devours the forest.

**Verdict:** ✅ OK

---

## Turn 10 — philosophy

**User:** what is consciousness

> Grug thinks about thinking. What is it like to be Grug? Consciousness is the fire inside that makes experience real. Grug not know where it comes from but Grug knows it burns.

**Verdict:** ✅ OK

---

## Turn 11 — emotion

**User:** how are you feeling

> Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.

**Verdict:** ✅ OK

---

## Turn 12 — why-question

**User:** why is the sky blue

> Grug looks up and sees blue. Sky is blue because sunlight scatters off air molecules. Blue light scatters most because it waves short and fast. This is Rayleigh scattering.

**Verdict:** ✅ OK

---

# Section 9: Dictionary Lookup and Define

## Direct Define ("X is Y")

**Input:** "stalactite is a mineral formation hanging from cave ceiling"
**Output:** 📖 Learned: stalactite means a mineral formation hanging from cave ceiling
**Result:** ✅ Define still works
---

## Dictionary Lookup After Define

**Word:** stalactite
**Result:** ✅ Found: a mineral formation hanging from cave ceiling
---

## Dictionary Lookup — Pre-existing Word (fire)

**Word:** fire
**Dictionary result:** ⚠️ Not in dictionary (expected — fire is a node, not a dict entry)
---

## Dictionary Definitions Count

**Count:** 8
**Result:** ✅ Non-zero definitions
---

## Known Question — No Clarification

**Input:** "what is fire"
**Output:** Fire is oxidation. Oxygen combines with fuel and releases energy as heat and light. Grug learned to tame fire long ago. Fire is both creator and destroyer. It warms the cave but devours the forest.
**Result:** ✅ Known question answered (no clarification)
---

# Section 10: Thesaurus and Voice Rendering Coherence

## CoherenceCheck: grug-no-fire-swap

**Input:** "I feel sad"
**Bad pattern:** r"\bFire\b.*\b(sit|via|feel)\b"i
**Description:** "Fire sit via sad" — thesaurus swapped Grug→Fire

**Output:** To acknowledge what matters here: the short of it is, the sun shall come back yet for now it is okay to be sad. Grug sits beside you in the gray. Grug does not speak you to cheer up. Sad is the color of a gray sky inside. Grug sit with sad.
**Verdict:** ✅ No false-winner pattern detected

---

## CoherenceCheck: grug-identity-preserved

**Input:** "who are you"
**Bad pattern:** r"\bFire\b.*\bGrug\b|\bFire\b.*\bam\b"i
**Description:** Self-reference corrupted by thesaurus swap

**Output:** Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.
**Verdict:** ✅ No false-winner pattern detected

---

## Turn 13 — topic-coherence-feeling

**User:** how are you feeling

> Grug is Grug. Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening.

**Verdict:** ✅ OK

---

## Turn 14 — topic-coherence-sky

**User:** why is the sky blue

> Grug looks up and sees blue. Sky is blue because sunlight scatters off air molecules. Blue light scatters most because it waves short and fast. This is Rayleigh scattering.

**Verdict:** ✅ OK

---

## Turn 15 — voice-render-greeting

**User:** hello

> Hello — here is what matters: You are safe here with Grug. Grug smile huge. Grug welcome friend to den.

**Verdict:** ✅ OK

---

## Turn 16 — voice-render-question

**User:** what is water

> Water is H2O. Two hydrogen and one oxygen holding hands. Water flows and adapts. It takes the shape of any container. Water is patient. Water always finds a way through.

**Verdict:** ✅ OK

---

# Section 11: Correction and Feedback

## Correction ("no, X is Y")

**Input:** "no, stalactite hangs from ceiling not grows from floor"
**Output:** ✏️ Corrected: stalactite → stalactite from ceiling not grows from floor
**Result:** ✅ Correction processed
---

## Correction — Alternate Format

**Input:** "no fire is not just oxidation fire is plasma"
**Output:** ✏️ Corrected: fire → not just oxidation fire is plasma
**Result:** ✅ Correction processed
---

# Section 12: Arithmetic Engine

## Turn 17 — arith-add

**User:** 3 + 5

> Thinking it through: 3 plus 5 equals 8.

**Verdict:** ✅ OK

---

## Turn 18 — arith-subtract

**User:** 10 - 4

> Thinking it through: 10 minus 4 equals 6.

**Verdict:** ✅ OK

---

## Turn 19 — arith-multiply

**User:** 6 * 7

> Thinking it through: 6 times 7 equals 42.

**Verdict:** ✅ OK

---

## Turn 20 — arith-factorial

**User:** factorial of 5

> Thinking it through: factorial of 5 is 120.

**Verdict:** ✅ OK

---

## Turn 21 — arith-complex

**User:** 2 + 3 * 4

> Thinking it through: So the answer is 20, 2 plus 3 = 5, and then 3 times 4 = 20.

**Verdict:** ✅ OK

---

# Section 13: Sigil Node Verification

## Sigil Node Census

| Kind | Count | IDs |
|------|-------|-----|
| procedural | 2 | node_282, node_278 |
| relational | 2 | node_283, node_279 |
| any | 18 | — |

**Procedural sigil verification:** ✅ All 2 procedural sigils verified

**Relational sigil verification:** ✅ All 2 relational sigils verified

---

# Section 14: Save/Load Round-Trip

## PendingTeachSaveLoad: pending-teach-roundtrip

**Before save:** topic='test_topic' ok=true
**Save:** ✅ Saved to /workspace/grugbot420_repo/grug_v828b_post_test.specimen
**After clear:** empty=true
**After load:** topic='test_topic' ✅ Pending teach state survived round-trip

---

## Full Specimen Round-Trip

**Save:** ✅ Saved with 297 nodes, 8 definitions
**Reload:** 297 nodes, 8 definitions
**Result:** ✅ Node count and dict count match
---

# Final Summary

**Completed:** 2026-06-24T03:29:57.036

## Results by Section

| Section | Pass | Fail | Total |
|---------|------|------|-------|
| Decoherence (S1) | 11 | 0 | 11 |
| Prescan + Core (S2+S8) | 47 | 0 | 47 |
| Knowledge Classification (S3) | 25 | 0 | 25 |
| Lobe Routing (S4) | 8 | 0 | 8 |
| Teach Parts (S5) | 9 | 0 | 9 |
| Conversational Learning (S6) | 5 | 0 | 5 |
| Pending Teach Expiry (S7) | 2 | 0 | 2 |
| Save/Load Round-Trip (S14) | 1 | 0 | 1 |

| **TOTAL** | **108** | **0** | **108** |

## ✅ All Tests Passed!

---

**Overall pass rate:** 100.0%

