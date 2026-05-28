# v7.23 Implementation TODO

## Discovery
- [x] Clone repo, inventory src/ and test/
- [x] Read `SigilRegistry.jl` — confirm `:procedure` is reserved, Greek allowed
- [x] Read `VoteOrchestrator.jl` — confirm `select_aiml_votes` shape
- [x] Read `engine.jl::Vote` — confirm extension points
- [x] Confirm `ActionTonePredictor` exposes prediction result
- [x] Skim `ArithmeticEngine.jl` — confirm step model
- [x] Plan written to `plans/v7_23_multipart_automaton.md`

## Implementation
- [x] Extend `Vote` struct with `multipart_group`, `multipart_role` (default-safe)
- [x] Create `src/MultipartOrchestrator.jl`
- [x] Create `src/EphemeralAutomaton.jl`
- [x] Activate `:procedure` class in `SigilRegistry.jl` + `register_procedure_sigil!`
- [x] Add ATP `maybe_escalate` hook
- [x] Wire modules into `GrugBot420.jl`
- [x] Hook AIML payload builder to objectives (via passthrough wrapper)

## Tests
- [x] `test/test_multipart_orchestrator.jl`
- [x] `test/test_ephemeral_automaton.jl`
- [x] `test/test_procedure_sigil.jl`
- [x] Append to `test/runtests.jl`
- [x] Run full test suite, ensure new tests green
  - All 3 new files green in harness (multipart 24/24, automaton 23/23,
    procedure 10/10).
  - Two pre-existing failures (`test_smoke.jl`, `test_v7_21b3b.jl`)
    confirmed unchanged from clean main; not caused by v7.23.

## Polish
- [x] Append v7.23 section to plan with final API
- [x] Commit + push to feature branch
