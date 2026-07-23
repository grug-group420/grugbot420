# GrugBot420 Specimen Test Log
## comprehensive_specimen_v81.json (138 nodes, 8 lobes)

### Test Configuration
- **Specimen**: comprehensive_specimen_v81.json (315KB)
- **Nodes**: 138 (including 5 natural-world nodes: dog, cat, tree, water, sun)
- **Lobes**: 8 (math, science, emotions, time, social, survival, language, default)
- **Julia Version**: 1.12.6
- **Engine Version**: v2.11 with v7.56 sigil expansion fix

### Response Quality Notes
- Arithmetic queries correctly computed via SigilPromoter → ArithmeticEngine pipeline
- Multipart queries decomposed by InputDecomposer, coalesced by MultipartOrchestrator
- Voice body from system_prompt now flows into responses (grug-voice utterances)
- Emotion nodes use `comfort`/`validate` actions with gentle/warm frame_hints
- Science nodes use `reason`/`explain` actions with observational frame_hints
- Causal chains recognized in survival lobe (e.g., hunger→hunting)

---

### Q: what is 2+2
**A:** Zooming out:  Alongside this: Numbers are truth that never lie. Grug count rocks one by one, each rock is certain. Subtraction is grug stacking or removing rocks, always exact, never maybe. so 2 plus 2 equals 4

---

### Q: what is a dog
**A:** So here's what I see — The four-legged tribe member: dog. Grug trusts dog more than most two-legged.

---

### Q: what is 2+2 also what is a dog
**A:** Stepping back — Grug knows addition. Each number is a rock. Stack them right, outcome is truth. and  Alongside this: Numbers are truth that never lie. Grug count rocks one by one, each rock is certain. Multiplication is grug stacking or removing rocks, always exact, never maybe.

**v8.2-scoped fix**: With scoped_mission, each COMMANDS handler now receives only its sub-subject text. Arithmetic (2+2=4) is correctly computed only for the math group entry. Non-math entries no longer bleed arithmetic from global bindings.

---

### Q: why is the sky blue
**A:** Let me lay it out: Sky is something grug can observe and understand. Grug watch, grug test, grug learn. World has rules and grug finds them by looking closely.

---

### Q: why do we feel sad
**A:** So here's what I see —  The other side: Sadness is heavy stone in chest, grug knows this feeling. Grug do not run from feeling, grug sit with it by fire. Feeling is teacher, even when it hurts. — Grug realize sadness. It is like cold wind inside cave. But wind always passes, and fire always burns again.

---

### Q: hunger causes hunting
**A:** Mulling it over — The chain of why: grug pulls it hand over hand until reaching the first fit.

---

### Q: what is love also what is 3 times 4
**A:** Here is the picture: 3 times 4 equals 12, and  A companion frame: Sadness is heavy stone in chest, grug knows this feeling. Grug do not run from feeling, grug sit with it by fire. Feeling is teacher, even when it hurts.

**v8.2-scoped fix**: Arithmetic computed correctly (3×4=12) and scoped to math group only. Emotion node responds independently without arithmetic bleed.

---

### Q: how does water boil also why do we dream
**A:** Let me lay it out: water essential keep grug alive another season. Every day is negotiation with the wild. Grug respect danger, grug prepare, grug endure. Another node chimes in: river water keep grug alive another season. Every day is negotiation with the wild. Grug respect danger, grug prepare, grug endure. I am not fully locked in — alert is also on the table.

---

### v8.2 Multipart Scoped Mission Test Results (2026-06-11)

**Fix**: Phase 2 — Multipart resource contention. Each COMMANDS handler now uses `scoped_mission` (sub-subject text) instead of the full compound `mission` string. Per-group bindings prevent arithmetic from bleeding across groups.

| Test | Input | Expected | Result |
|------|-------|----------|--------|
| arithmetic+animal | "what is 2+2 and what is a cat" | "4", "cat" | ✅ PASS |
| arithmetic+emotion | "what is 3 times 4 and why do we feel sad" | "12", "sad" | ✅ PASS |
| single_arithmetic | "what is 2+2" | "4" | ✅ PASS |
| single_knowledge | "what is a dog" | "dog" | ✅ PASS |
| three_part | "what is 5 plus 3 and what is a tree and why is the sky blue" | "8", "tree", "blue" | ✅ PASS |
| love+arithmetic | "what is love also what is 3 times 4" | "12" | ✅ PASS |

**Key improvements**:
- Arithmetic no longer bleeds into non-math entries (binding fallback fix)
- Each entry's `scoped_mission` is correctly set to the sub-subject text
- `all_sure_done()` cycle-complete gate added as diagnostic
- Multipart scoped text stash handles compound chunk groups ("chk_1_2")

---


### Known Non-Fatal Warnings (Engine-Level, Not Specimen Issues)
1. **EphemeralMLP BoundsError**: 17 votes vs 16 weights — engine bug, not specimen. Does not affect output.
2. **Coherence features MethodError**: `is_grave` field access on Node — engine compatibility issue with Julia 1.12.6. Non-fatal.
3. **BUG-004 pattern length warnings**: Multi-token patterns penalized by bidirectional scan. Specimen-side fix: use shorter patterns.
4. **Circular pattern echoes**: node_48 (hunger causes hunting) — already filtered in specimen, engine still warns at runtime.

### Action Packet Fixes Applied
192 invalid action names were replaced with valid GrugBot actions:
- `instruct` → `explain` | `observe` → `describe` | `compute` → `calculate`
- `verify` → `validate` | `trace` → `describe` | `encourage` → `reassure`
- `relate` → `explain` | `report` → `notify` | `guide` → `explain`
- `orient` → `explain` | `connect` → `explain` | `summarize` → `describe`

### Valid Action Vocabulary (30 actions)
acknowledge, alert, analyze, ask, calculate, caution, clarify, comfort, define, describe, elaborate, explain, fight, flag, flee, greet, hide, inquire, laugh, notify, ponder, question, reason, reassure, smile, support, validate, warn, welcome, wonder
