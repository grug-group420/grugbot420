# v7.23 — ActionLog + HippocampalModulator

## Design
- Votes write to an ActionLog (ordered, numbered entries) instead of being submitted directly to AIML
- Each ActionEntry carries only its objective's scoped votes
- HippocampalModulator writes log entries from MultipartOrchestrator's output
- AIML reads one entry at a time from the log, never sees the full vote pile
- Context carry-forward: prior entry outputs available for dependent entries
- Log is wiped every cycle (ephemeral, like cycle flags)
- User-extensible ordering rules layer on top later (slot exists, not built yet)

## Tasks
- [x] Create ActionEntry struct
- [x] Create ActionLog struct (with cycle wipe)
- [x] Create HippocampalModulator module
- [x] HippocampalModulator: write log entries from MultipartOrchestrator output
- [x] Hook ActionLog into existing flow (replace direct vote → AIML with vote → log → AIML)
- [x] Wire cycle wipe into existing cycle reset logic
- [x] Update ephemeral_aiml_orchestrator to read from ActionLog entries
- [x] Write tests for ActionLog + HippocampalModulator (14 test sets)
- [x] Run regression tests (hippocampal, multipart_integration, right_feedback_tiered, input_decomposer, vote_orchestrator — all green)
- [x] Update plans doc
- [x] Add test_hippocampal_modulator.jl to runtests.jl
- [x] Commit
