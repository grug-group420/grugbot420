# Kitchen Sink v12 — Coherence Diff (v11 vs v12)

This file pairs every mission in the kitchen sink v12 run with its v11
counterpart. Both runs use the same seed specimen, the same 89-mission
stream, and the same tonal judge — only the AIML output scaffold +
system_prompt-body wiring changed.

The 🟢 IMPROVED tag fires when v11 produced a known-broken parrot pattern
(`"...what matters here:..."`, `"...here is what matters:..."`, or
`"Thinking it through: <fragment>"`) and v12 replaced it with prose that
isn't that pattern. 🟡 changed = the reply is different but v11's wasn't a
known-broken form. ⚪ same = identical text.

See `SUMMARY.md` for the full run summary, frame distribution, and verdict.

---

# Coherence Delta — v11 (broken scaffold) vs v12 (Fix A + Fix B)

Both runs: same missions, same seed specimen, same tonal judge.

Only the AIML scaffold + system_prompt-body wiring changed.

Pair count: 64

---

### 1. mission: `hello` — 🟢 IMPROVED
- v11: `[Grug greet warm] Hello — here is what matters: hello hi.`
- v12: `[Grug greet warm] Let me think with you. Subsist polite, brief..`

### 2. mission: `hello` — 🟢 IMPROVED
- v11: `[Grug greet warm] Hello — here is what matters: hello hi.`
- v12: `[Grug greet warm] Let me think with you. Remain polite, brief..`

### 3. mission: `hello` — 🟢 IMPROVED
- v11: `[Grug greet warm] Hello — here is what matters: hello hi.`
- v12: `[Grug greet warm] Let me think with you. Be polite, brief..`

### 4. mission: `good morning` — 🟢 IMPROVED
- v11: `[Grug acknowledge time of day with warmth] Hello — here is what matters: good morning.`
- v12: `[Grug acknowledge time of day with warmth] good morning.`

### 5. mission: `howdy partner` — 🟢 IMPROVED
- v11: `[Grug greet casually] Hello — here is what matters: howdy.`
- v12: `[Grug greet casually] Here is the picture: howdy.`

### 6. mission: `what is fire` — 🟡 changed
- v11: `[Grug explain plain] Here is the picture: what is.`
- v12: `[Grug explain plain] Here is the picture: No big words..`

### 7. mission: `tell me about rocks` — ⚪ same
- v11: `[Grug share what grug know] Here is the picture: say me. Pinned note: Many rocks compete. Loudest rock get to talk.`
- v12: `[Grug share what grug know] Here is the picture: say me. Pinned note: Many rocks compete. Loudest rock get to talk.`

### 8. mission: `why does fire burn` — 🟢 IMPROVED
- v11: `[Grug seek cause] Thinking it through: why. Pinned note: Hot rock burn. Soft skin remember.`
- v12: `[Grug seek cause] Here is the picture: Trace from product to source.. Pinned note: Hot rock burn. Soft skin remember.`

### 9. mission: `how does a hammer work` — ⚪ same
- v11: `[Grug talk about hitting-rock-with-handle] Here is the picture: hammer.`
- v12: `[Grug talk about hitting-rock-with-handle] Here is the picture: hammer.`

### 10. mission: `what causes the storm to rumble` — 🟡 changed
- v11: `[Grug explain plain] Here is the picture: what is.`
- v12: `[Grug explain plain] Here is the picture: No huge words..`

### 11. mission: `danger ahead` — 🟡 changed
- v11: `[Grug see threat] A caution: danger.`
- v12: `[Grug see threat] Warn loud and wipe..`

### 12. mission: `run from the wolf now` — 🟡 changed
- v11: `[Grug urge escape from harm] A caution: run.`
- v12: `[Grug urge escape from harm] run.`

### 13. mission: `fire burns my hand` — 🟡 changed
- v11: `[Grug warn of hot rock that bites] A caution: fire burns.`
- v12: `[Grug warn of hot rock that bites] fire burns.`

### 14. mission: `watch out for the cliff` — 🟡 changed
- v11: `[Grug point at incoming thing] A caution: watch out.`
- v12: `[Grug point at incoming thing] Let me think with you. view out.`

### 15. mission: `perhaps the river bends near the old tree` — 🟡 changed
- v11: `[Grug know tree make shade, nut, wood for fire] Here is the picture: tree. A companion frame: river.`
- v12: `[Grug know tree make shade, nut, wood for fire] Let me think with you. tree. A companion frame: river.`

### 16. mission: `maybe we should wait for dawn` — 🟢 IMPROVED
- v11: `[Grug weigh path forward] Thinking it through: should we.`
- v12: `[Grug weigh path forward] Let me think with you. Many possible step..`

### 17. mission: `why is this stupid garbage broken?` — 🟢 IMPROVED
- v11: `[Grug seek cause] Thinking it through: why.`
- v12: `[Grug seek cause] I hear that. Trace from product to source..`

### 18. mission: `what kind of idiot designed this?` — 🟡 changed
- v11: `[Grug explain plain] Here is the picture: what is.`
- v12: `[Grug explain plain] I hear that. No enormous words..`

### 19. mission: `what why how when where which what why how when?` — 🟢 IMPROVED
- v11: `[Grug seek cause] Thinking it through: why. A companion frame: how does.`
- v12: `[Grug seek cause] Here is the picture: Trace from outcome to source.. A companion frame: how does.`

### 20. mission: `STOP STOP STOP NOW NOW NOW DANGER DANGER DANGER!!!` — 🟡 changed
- v11: `[Grug see threat] A caution: danger.`
- v12: `[Grug see threat] Warn loud and wipe..`

### 21. mission: `i feel sad today` — 🟢 IMPROVED
- v11: `[Grug listen to feeling] To acknowledge what matters here: i feel.`
- v12: `[Grug sit close] Let me think with you. Many tribe feel this.. A companion frame: Assess, do not mend..`

### 22. mission: `i feel worried about tomorrow` — 🟢 IMPROVED
- v11: `[Grug sit with sadness] To acknowledge what matters here: downcast. A companion frame: i feel.`
- v12: `[Grug sit close] Let me think with you. Many tribe feel this.. A companion frame: Supply presence not solutions.. I am not fully locked in — comfort is also on the table.`

### 23. mission: `i feel lonely in the cave` — 🟢 IMPROVED
- v11: `[Grug listen to feeling] To acknowledge what matters here: i feel.`
- v12: `[Grug listen to feeling] Let me think with you. Examine, do not fix..`

### 24. mission: `i did it i made fire` — 🟡 changed
- v11: `[Grug warn of hot rock that bites] A caution: fire burns.`
- v12: `[Grug warn of hot rock that bites] fire burns.`

### 25. mission: `victory over the bear` — 🟢 IMPROVED
- v11: `[Grug celebrate with loud good noise] Hello — here is what matters: victory.`
- v12: `[Grug celebrate with loud good noise] Let me think with you. victory.`

### 26. mission: `thank you for the food` — 🟢 IMPROVED
- v11: `[Grug receive thanks with grace] To acknowledge what matters here: thank you.`
- v12: `[Grug receive thanks with grace] Let me think with you. thank you.`

### 27. mission: `should we move camp` — 🟡 changed
- v11: `[Grug name what come after] Here is the picture: next step. A companion frame: should we.`
- v12: `[Grug weigh path forward] Let me think with you. Many possible step..`

### 28. mission: `plan to hunt at dawn` — 🟢 IMPROVED
- v11: `[Grug sketch path in dirt] Thinking it through: proposal to.`
- v12: `[Grug sketch path in dirt] concept to.`

### 29. mission: `next step in the trap` — 🟡 changed
- v11: `[Grug name what come after] Here is the picture: next step.`
- v12: `[Grug name what come after] next step.`

### 30. mission: `the sky looks dark` — 🟡 changed
- v11: `[Grug look up] Here is the picture: the sky.`
- v12: `[Grug look up] Let me think with you. Gigantic blue or grey. Load weather..`

### 31. mission: `the river is high` — 🟡 changed
- v11: `[Grug know water move and life depend on it] Here is the picture: river.`
- v12: `[Grug know water move and life depend on it] Let me think with you. river.`

### 32. mission: `make a tool from this stone` — 🟡 changed
- v11: `[Grug stack and bind] Here is the picture: form. A companion frame: craft a tool.`
- v12: `[Grug stack and bind] Construct shelter, construct trap..`

### 33. mission: `build a shelter before night` — 🟡 changed
- v11: `[Grug stack and bind] Here is the picture: produce.`
- v12: `[Grug stack and bind] Craft shelter, make trap..`

### 34. mission: `danger danger predator near` — 🟡 changed
- v11: `[Grug urge escape from harm] A concern worth raising: sprint.`
- v12: `[Grug urge escape from harm] dash.`

### 35. mission: `tell me a calm story` — 🟡 changed
- v11: `[Grug share what grug know] Here is the picture: converse me.`
- v12: `[Grug share what grug know] Here is the picture: discuss me.`

### 36. mission: `why` — 🟢 IMPROVED
- v11: `[Grug seek cause] Thinking it through: why.`
- v12: `[Grug seek cause] Here is the picture: Trace from effect to source..`

### 37. mission: `tree` — 🟡 changed
- v11: `[Grug know tree make shade, nut, wood for fire] Here is the picture: tree.`
- v12: `[Grug know tree make shade, nut, wood for fire] tree.`

### 38. mission: `sad` — 🟢 IMPROVED
- v11: `[Grug sit with sadness] To acknowledge what matters here: dejected.`
- v12: `[Grug sit with sadness] Deliver presence not solutions..`

### 39. mission: `tell me about the rocks` — 🟡 changed
- v11: `[Grug share what grug know] Here is the picture: chat me. Pinned note: Many rocks compete. Loudest rock get to talk.`
- v12: `[Grug share what grug know] Here is the picture: speak me. Pinned note: Many rocks compete. Loudest rock get to talk.`

### 40. mission: `tell me about the rocks` — 🟡 changed
- v11: `[Grug share what grug know] Here is the picture: chat me. Pinned note: Many rocks compete. Loudest rock get to talk.`
- v12: `[Grug share what grug know] Here is the picture: discuss me. Pinned note: Many rocks compete. Loudest rock get to talk.`

### 41. mission: `tell me about the rocks` — ⚪ same
- v11: `[Grug share what grug know] Here is the picture: chat me. Pinned note: Many rocks compete. Loudest rock get to talk.`
- v12: `[Grug share what grug know] Here is the picture: chat me. Pinned note: Many rocks compete. Loudest rock get to talk.`

### 42. mission: `hello again old friend` — 🟢 IMPROVED
- v11: `[Grug greet warm] Hello — here is what matters: hello hi.`
- v12: `[Grug greet warm] Remain polite, brief..`

### 43. mission: `tell me about fire and stone` — 🟡 changed
- v11: `[Grug share what grug know] Here is the picture: converse me.`
- v12: `[Grug share what grug know] Here is the picture: talk me.`

### 44. mission: `what is the difference between hammer and stone` — 🟡 changed
- v11: `[Grug explain plain] Here is the picture: what is.`
- v12: `[Grug explain plain] Here is the picture: No vast words..`

### 45. mission: `why does the river flow downhill` — ⚪ same
- v11: `[Grug know water move and life depend on it] Here is the picture: river.`
- v12: `[Grug know water move and life depend on it] Here is the picture: river.`

### 46. mission: `could you explain how fire makes warm` — 🟢 IMPROVED
- v11: `[Grug describe mechanism step by step] Thinking it through: how does.`
- v12: `[Grug describe mechanism step by step] Here is the picture: how does.`

### 47. mission: `STOP STOP STOP DANGER` — 🟡 changed
- v11: `[Grug see threat] A caution: danger.`
- v12: `[Grug see threat] Warn loud and erase..`

### 48. mission: `watch out` — 🟡 changed
- v11: `[Grug point at incoming thing] A caution: look out.`
- v12: `[Grug point at incoming thing] observe out.`

### 49. mission: `run now` — 🟡 changed
- v11: `[Grug urge escape from harm] A concern worth raising: jog.`
- v12: `[Grug urge escape from harm] sprint.`

### 50. mission: `warning predator at the edge` — 🟡 changed
- v11: `[Grug raise voice] A caution: warning.`
- v12: `[Grug raise voice] Create sure heard..`

### 51. mission: `fire spreads quick` — 🟡 changed
- v11: `[Grug warn of hot rock that bites] A caution: fire burns.`
- v12: `[Grug warn of hot rock that bites] fire burns.`

### 52. mission: `i feel scared and alone` — 🟢 IMPROVED
- v11: `[Grug sit with sadness] To acknowledge what matters here: dejected. A companion frame: i feel.`
- v12: `[Grug sit with sadness] Give presence not solutions..`

### 53. mission: `i feel angry at the tribe` — 🟢 IMPROVED
- v11: `[Grug sit with sadness] To acknowledge what matters here: unhappy. Pinned note: Tribe stronger than lone hunter.`
- v12: `[Grug calm worried mind] Let me think with you. terrified. A companion frame: Assess, do not fix.. I am not fully locked in — reassure is also on the table. Pinned note: Tribe stronger than lone hunter.`

### 54. mission: `victory at last` — 🟢 IMPROVED
- v11: `[Grug celebrate with loud good noise] Hello — here is what matters: victory.`
- v12: `[Grug celebrate with loud good noise] victory.`

### 55. mission: `thank you for teaching me` — 🟢 IMPROVED
- v11: `[Grug receive thanks with grace] Hello — here is what matters: thank you.`
- v12: `[Grug receive thanks with grace] Let me think with you. thank you.`

### 56. mission: `tell me again about the river` — ⚪ same
- v11: `[Grug know water move and life depend on it] Here is the picture: river.`
- v12: `[Grug know water move and life depend on it] Here is the picture: river.`

### 57. mission: `what is fire what is water what is sky` — 🟢 IMPROVED
- v11: `[Grug look up] To acknowledge what matters here: the sky.`
- v12: `[Grug look up] Here is the picture: Big blue or grey. Fetch weather..`

### 58. mission: `grug hits rock and makes fire` — 🟢 IMPROVED
- v11: `[Causal relational analysis active] Thinking it through: grug hits rock and makes fire. The link is clear: grug hits rock. Pinned note: Grug speak plain. Grug not pretend smart.`
- v12: `[Causal relational analysis active] grug hits rock and makes fire. The link is clear: grug hits rock. Pinned note: Grug speak plain. Grug not pretend smart.`

### 59. mission: `do you know about the stars` — 🟢 IMPROVED
- v11: `[Grug seek cause] Thinking it through: why.`
- v12: `[Grug check own memory rocks] do you know.`

### 60. mission: `can you teach me about hunting` — 🟡 changed
- v11: `[Grug try] Here is the picture: can you.`
- v12: `[Grug try] Let me think with you. Say what grug can do..`

### 61. mission: `should we sleep now` — 🟢 IMPROVED
- v11: `[Grug weigh path forward] Thinking it through: should we.`
- v12: `[Grug weigh path forward] Many possible step..`

### 62. mission: `plan the morning hunt` — 🟢 IMPROVED
- v11: `[Grug sketch path in dirt] Thinking it through: approach to.`
- v12: `[Grug sketch path in dirt] Let me think with you. approach to.`

### 63. mission: `next step is sharpening` — 🟢 IMPROVED
- v11: `[Grug name what come after] Thinking it through: next step.`
- v12: `[Grug name what come after] next step.`

### 64. mission: `tell me a story about the river bending past the old tree` — 🟡 changed
- v11: `[Grug know water move and life depend on it] Here is the picture: river. A companion frame: tree.`
- v12: `[Grug know tree make shade, nut, wood for fire] Here is the picture: tree. A companion frame: river.`


## Tally

- 🟢 IMPROVED (broken pattern echo replaced with system_prompt body): **29**
- 🟡 changed but not from a known broken pattern: **30**
- ⚪ identical: **5**
