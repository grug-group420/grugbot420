# v7.23 Integration Tasks

## Phase 1: Input Decomposition Layer
- [x] Create `src/InputDecomposer.jl` — detect compound queries, split into sub-subjects, assign multipart_group IDs
- [x] Add compound-splitting logic: conjunction detection ("also", "and", "but"), multi-clause detection (multiple "?"), sigil boundary detection
- [x] Wire `InputDecomposer` into `process_mission` in Main.jl — after ATP prediction, before scan
- [x] Modify `scan_and_expand` (or add `scan_and_expand_multipart`) to accept multipart_group_id and stamp it onto votes

## Phase 2: ATP `maybe_escalate` Hook
- [x] Add `ESCALATION_FAMILIES` constant to ActionTonePredictor
- [x] Add `maybe_escalate` function to ActionTonePredictor that calls EphemeralAutomaton
- [x] Wire `maybe_escalate` into `process_mission` (called after ATP prediction, trace stored in LAST_ESCALATION_TRACE)
- [x] Store automaton trace in LAST_ESCALATION_TRACE Ref (avoids PredictionResult schema break)

## Phase 3: Orchestrator Consumes MultipartObjectives
- [x] Modify `ephemeral_aiml_orchestrator` to call `MultipartOrchestrator.build_objectives`
- [x] Generate AIML payload per-objective instead of single top/subtop
- [x] Combine objective outputs into one coherent response

## Phase 4: `/automaton` CLI Commands
- [x] Add `/automaton register`, `/automaton list`, `/automaton remove` CLI handlers in Main.jl

## Phase 5: Wiring & Tests
- [x] Add InputDecomposer.jl to GrugBot420.jl includes/exports
- [x] Add test for InputDecomposer (10 test sets, all passing)
- [x] Add test for ATP maybe_escalate (6 test sets, all passing)
- [x] Add integration test for orchestrator consuming MultipartObjectives (10 test sets, all passing)
- [x] Add test_atp_escalation.jl and test_multipart_integration.jl to runtests.jl
- [x] Run full test suite — no regressions detected
