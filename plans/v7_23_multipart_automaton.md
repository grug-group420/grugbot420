# v7.23 — Multipart Vote Orchestration + ATP-Driven Ephemeral Automata

## What user asked for (verbatim, distilled)

1. **Multipart votes from the same node.** AIML always gets multiple votes; today
   they all come from *different* nodes. We need to also support the case where
   a single node emits *multiple parts of one answer* and tag them so AIML
   knows: "these K votes are jointly answering ONE thing — orchestrate them
   together as one objective with internal sure/unsure structure."
   - Old shape: hard lock-ins (top tier) + coinflipped unsures (sub-top).
   - New shape **per multipart group**: lock-ins and non-lock-ins are *both*
     treated as belonging to the same **solid objective**. AIML produces ONE
     multipart-aware response per group.
   - Singleton-multi (today's case) stays unchanged.

2. **Basal-ganglia → prefrontal-cortex escalation: ATP can pull in a
   just-in-time, ephemeral automaton.**
   - Sparse activation: only triggered when ATP confidence is high *and* the
     winning action family wants step-by-step expansion (multi-step linguistic
     pattern *completion*, not just pattern *reaction*).
   - Automaton has *no* sub-population, *no* persistent nodes — pure JIT,
     ephemeral, dies after the cycle.
   - User-extensible rule set (add at runtime).
   - Some automaton internal values get **jitter snap-back** every fire; values
     that would corrupt step coherence stay deterministic.
   - Automaton **influences ATP**, not the nodes. Nodes never call it; ATP does.

3. **Math-acronym sigils (Greek/symbol-class).**
   - Already partly supported by `SigilRegistry` (Greek letters in name regex,
     `:macro` class active, `:procedure` class reserved).
   - Add user-definable math-acronym sigils that can resolve to either:
     - a **token** (literal expansion, current behavior), or
     - a **functor** (small ordered chain of automaton steps).
   - Lights up the reserved `:procedure` class (Stage 6 in registry comments).
   - Used to compress automaton stepping rules.

4. **Pattern reaction vs. pattern completion.**
   - Reaction: today's path. Most queries.
   - Completion: needs the automaton + sigil system. Multi-step.
   - In between: reaction-completion hybrid. Same path; automaton optional.

## Bio-coherence framing

- Nodes = cortex. Lots of them. Sparse activation. Vote.
- AIML = prefrontal cortex. Integrates votes into one response.
- ATP = basal ganglia. Decides *whether* to escalate to a deliberative
  multi-step process, and shapes action tone accordingly.
- Ephemeral automaton = working-memory scratch loop spun up by basal ganglia
  for one objective, then released. NOT a population — no persistence.
- Multipart vote group = one "thought" decomposed into parts within a single
  node, recombined under one objective at the AIML layer.

## Architecture (additive, no schema breakage)

### A. `Vote` struct gets two new optional fields
```
struct Vote
  ... existing ...
  multipart_group::String          # "" = singleton (default; back-compat)
  multipart_role::Symbol           # :singleton, :primary, :support
end
```
- `multipart_group == ""` → behaves exactly as today.
- `multipart_group != ""` → AIML groups all votes sharing this id.
- Within a group: `:primary` is the locked-in claim, `:support` are the
  associated sure/unsure parts.

### B. New module `MultipartOrchestrator.jl`
- `group_votes_by_multipart(votes) -> Dict{String, Vector{Vote}}`
- `orchestrate_multipart_group(group_id, votes; threshold, top_window)`
  → returns `MultipartObjective(group_id, primary, locked_supports, unsure_supports)`.
- AIML payload builder consumes objectives instead of (top, subtop) directly.
- Singleton votes flow through a passthrough that wraps each in a one-element
  objective so the downstream code only sees objectives.

### C. New module `EphemeralAutomaton.jl`
- Pure JIT. Built once per call from current rule registry. No persistence.
- `AutomatonRule(id, trigger, steps, jitter_targets)`.
- `AutomatonStep(label, op, payload)`.
- `run_automaton(rule, ctx) -> AutomatonTrace`.
- Trace contains step labels + values; ATP reads it to nudge tone weights.
- **Jitter snap-back**: only fields tagged in `jitter_targets` are passed
  through `RelationalJitter.jitter_value`. Step indices, operator symbols,
  and final-state booleans stay exact.
- User adds rules with `register_automaton_rule!`, removes with
  `unregister_automaton_rule!`. Ephemeral execution; the *rule* is persistent
  in a small registry, the *trace* is not.

### D. ATP gets a pre-vote escalation hook
- New function `maybe_escalate(prediction, input)` runs after primary
  prediction. If action family is in `ESCALATION_FAMILIES` (e.g. `:reason`,
  `:explain`, `:plan`, `:compute`) AND confidence ≥ threshold, AND a matching
  automaton rule exists, run it.
- Trace folds into `weight_multiplier`/arousal nudge so high-confidence
  multi-step paths get extra kick.

### F. InputDecomposer — compound-query input decomposition (v7.23 integration)
- When user input contains multiple distinct subjects (e.g. "what time is it
  ALSO what is a dinosaur AND what is 2+2"), the multipart system triggers
  because the INPUT ITSELF decomposes into multiple independent scan targets,
  each needing its own vote pool but coordinated as one response.
- `decompose_input(input) -> Vector{DecomposedSubSubject}` — splits on
  conjunction boundaries ("also", "but", "and" with question markers) and
  multiple "?" markers.
- Each sub-subject gets a deterministic multipart_group ID (mp_1, mp_2, ...).
- The decomposer's role field (:primary for first, :support for subsequent)
  is for OUTPUT ORDERING in the orchestrator's combined response, NOT for
  vote role assignment. Each sub-subject's winning vote is :primary within
  its own group.
- `is_compound(input) -> Bool` — quick check for process_mission branching.
- Wired into process_mission: if compound, each sub-subject gets its own
  scan pass; specimen tuples expanded from 5-tuple to 7-tuple adding
  (multipart_group, multipart_role); votes use `cast_vote_with_group`.

### E. Sigil registry: activate `:procedure` class for math-acronym sigils
- Add `register_procedure_sigil!(name, steps)`.
- Steps are a `Vector{Union{String, SigilTokenRef}}` — a chain of literals and
  other sigils.
- Promoter learns to expand procedure sigils inline at bind time.
- Examples ship in a default math acronym pack: `&Σ` (sum-of), `&Δ`
  (difference-of), `&π` (ratio circumference/diameter — illustrative, expands
  to a number token), user-extensible.

## What we will NOT do in this patch
- We will not rip out the existing top/subtop bucketing — multipart sits
  *next to it*, not in place of.
- We will not add automaton sub-populations or strength tracking. Pure JIT.
- We will not let nodes call automata directly. Only ATP does.
- We will not make procedure sigils computational — they expand to ordered
  literal/sigil chains; *evaluation* stays in `ArithmeticEngine` /
  automaton steps.

## Files added
- `src/MultipartOrchestrator.jl`
- `src/EphemeralAutomaton.jl`
- `src/InputDecomposer.jl` — compound-query input decomposition layer (v7.23 integration)
- `test/test_multipart_orchestrator.jl`
- `test/test_ephemeral_automaton.jl`
- `test/test_procedure_sigil.jl`
- `test/test_input_decomposer.jl` — 12 test sets for InputDecomposer (including comma-based splitting)
- `test/test_atp_escalation.jl` — 6 test sets for ATP→automaton escalation hook
- `test/test_multipart_integration.jl` — 13 test sets for InputDecomposer→MultipartOrchestrator pipeline (including regression tests for sub.role bug and comma splitting)
- `plans/v7_23_multipart_automaton.md` (this file)

## Files modified
- `src/engine.jl` — extend `Vote` with two optional fields (default values
  preserve back-compat); add `cast_vote_with_group` for 7-tuple specimen
  expansion.
- `src/SigilRegistry.jl` — promote `:procedure` from reserved to active +
  add `register_procedure_sigil!`.
- `src/ActionTonePredictor.jl` — add `maybe_escalate` hook + automaton trace
  consumption; `ESCALATION_FAMILIES`, `LAST_ESCALATION_TRACE`, 
  `ESCALATION_CONFIDENCE_FLOOR`.
- `src/Main.jl` — `ephemeral_aiml_orchestrator` consumes multipart objectives;
  `/automaton` CLI commands for rule add/list/remove; `process_mission` wired
  with InputDecomposer multi-scan + ATP→automaton escalation hook; specimen
  tuple expanded from 5-tuple to 7-tuple (multipart_group, multipart_role).
- `src/GrugBot420.jl` — register MultipartOrchestrator, EphemeralAutomaton,
  InputDecomposer modules + all new exports.
- `test/runtests.jl` — include all six new test files.

## Test plan
1. ✅ Singleton votes still produce identical AIML output (no regression).
2. ✅ A 1-node-3-part vote group produces ONE objective with 1 primary +
   2 supports, all under one subject.
3. ✅ Mixed singleton + multipart groups orchestrate independently.
4. ✅ ATP escalation only fires when family is in `ESCALATION_FAMILIES` and
   confidence ≥ threshold; otherwise zero cost.
5. ✅ Automaton with `jitter_targets = [:value]` produces different `value` on
   repeated fires but same `step_index` and `operator`.
6. ✅ Procedure sigil `&Σ` expands at promotion to its registered chain.
7. ✅ Unknown procedure sigil throws `SigilResolutionError` (no silent fallback).
8. ✅ InputDecomposer detects compound queries via conjunction boundaries
   ("also", "but", "and" with question markers) and multiple "?" markers.
9. ✅ InputDecomposer assigns deterministic mp_1/mp_2/... group IDs.
10. ✅ Integration: InputDecomposer → MultipartOrchestrator pipeline produces
    one objective per sub-subject, each with its own :primary vote.
11. ✅ ATP→automaton escalation hook: `maybe_escalate` returns trace when
    family+confidence+rule match; returns nothing otherwise. LAST_ESCALATION_TRACE
    stores result for downstream consumers without PredictionResult schema break.
12. ✅ No regressions in existing test suite (sampled: smoke, vote_orchestrator,
    arithmetic_engine, aiml_node_system, comprehensive, sigil_registry,
    sigil_promoter, self_observer, v7_20, v7_21a, v7_21c1, v7_21c2).
13. ✅ Regression: using `sub.role` as vote multipart_role causes MultipartError
    for non-first sub-subjects (Test 11 in test_multipart_integration.jl).
14. ✅ Comma-based splitting: "what is X, what is Y" decomposes into two
    sub-subjects; "bread, butter, and cheese" stays singleton.
15. ✅ Unicode-safe string indexing in `_split_on_question_markers`.

## Done = green tests, no warnings beyond pre-existing, doc updated.

## Post-Integration Architectural Review (post-commit 8dbea59)

### Critical Bug Fixed: `sub.role` → `:primary` for ALL sub-subjects

In `process_mission` (Main.jl line ~2828), the original code stamped specimens with
`sub.role` from InputDecomposer. For the first sub-subject, `.role` is `:primary`;
for subsequent sub-subjects, `.role` is `:support`. But MultipartOrchestrator requires
exactly one `:primary` vote per group. So when mp_2's votes all carried `:support`
role, `build_objectives` would throw `MultipartError("must have exactly one :primary
vote, got 0")`.

**Root cause**: The decomposer's `.role` field was being used for two different
purposes. It was designed for OUTPUT ORDERING (first sub-subject's output appears
first in the combined response), but process_mission was using it as the vote's
`multipart_role` within each MultipartOrchestrator group.

**Fix**: In process_mission, every sub-subject's specimens are now stamped with
`:primary` as the vote role. Each sub-subject is an independent question — within
its own group, the winning vote is always `:primary`. The decomposer's `.role` field
is only for output ordering.

**Regression test added**: test_multipart_integration.jl now includes Test 11
("regression: every group needs :primary vote") which explicitly verifies that
using `sub.role` as the vote role would cause MultipartError.

### Improvements Applied

1. **Comma-based splitting in InputDecomposer**: Added `_split_on_comma_clauses()`
   which detects compound queries separated by commas — "what is X, what is Y" —
   a common pattern that lacks explicit conjunctions. Only splits when the token
   after the comma starts a question/command clause, avoiding false splits on
   simple lists like "bread, butter, and cheese". Tests added in both
   test_input_decomposer.jl and test_multipart_integration.jl.

2. **Unicode-safe string indexing in `_split_on_question_markers`**: Replaced
   `end_idx + 1` with `nextind(input_text, end_idx)` and `length(input_text)`
   with `lastindex(input_text)` to handle multi-byte characters correctly.

3. **InputDecomposer docstrings clarified**: The struct docstring and the
   `decompose_input` function docstring now explicitly state that `.role` is for
   OUTPUT ORDERING only, not for vote role assignment within MultipartOrchestrator.

### Known Limitations (deferred)

- **Sub-subject → output tracking for /right /wrong feedback**: Currently `/right`
  rewards ALL contributors. For multipart responses, there's no way to reward just
  one part (e.g., `/right mp_1`). This is a future enhancement — the current
  behavior (reward all) is reasonable since `/right` implicitly confirms the whole
  response.

- **Objective-scoped votes in COMMANDS calls**: The `ephemeral_aiml_orchestrator`
  passes ALL votes to each objective's COMMANDS handler. Ideally, each objective
  would only receive its own group's votes. However, the COMMANDS interface is
  used broadly, and changing it would require updating all handlers. The current
  approach works because COMMANDS already receives the primary + sure/unsure from
  the objective, and the full vote list is just background context.

- **LAST_ESCALATION_TRACE is a global Ref**: No thread-safety guarantees. This is
  acceptable for now since GrugBot runs single-threaded per cycle, but a future
  concurrent architecture would need thread-local or atomic storage.

- **`\n\n` join separator**: The `\n\n` separator between multi-objective output
  parts may not render well in all contexts (e.g., Discord, web chat). A more
  sophisticated separator (numbered sections, bullet headers) would improve
  readability but is a presentation-layer concern, not an architecture one.

---

## v7.23 — Tiered /right Feedback (confidence-biased coinflip)

### Design (from user)

Locked-in (top tier / high confidence) votes get a reward PERIOD — no coinflip.
The rest of the votes get a reward on a BIASED coinflip, biased by confidence.
Nodes ONLY get a reward if they didn't ALREADY gain strength from their use
coinflip this cycle (`gained_this_cycle == false`).

### Implementation

1. **New primary signature**: `apply_right_feedback!(contributor_votes::Vector{Vote}, locked_node_ids::Set{String} = Set{String}())::Dict{String, Any}`
   - Locked votes (node_id in `locked_node_ids`) → guaranteed `STRENGTH_DELTA` reward
   - Unsure votes (not locked) → `rand() < vote.confidence` coinflip for reward
   - Both tiers: skip if `gained_this_cycle` is already true
   - Grave nodes always skipped
   - Deduplication via `seen_nodes` set — a node only gets one chance even if it appears in multiple votes

2. **Backward-compat wrapper**: `apply_right_feedback!(contributor_ids::Vector{String})` creates stub Votes with `confidence=0.5` and empty locked set, preserving old 50/50 behavior

3. **Storage in Main.jl**:
   - `LAST_CONTRIBUTOR_VOTES::Vector{Vote}` — stores full Vote objects from contributing voters
   - `LAST_LOCKED_NODE_IDS::Set{String}` — stores node IDs that were in `sure_votes` (locked tier)
   - `LAST_CONTRIBUTOR_IDS::Vector{String}` — DEPRECATED, kept for /wrong compat
   - All three are thread-safe behind `LAST_VOTER_LOCK`

4. **Result dictionary** extended with:
   - `"locked_rewarded"` — Node IDs from locked tier that gained strength
   - `"unsure_rewarded"` — Node IDs from unsure tier that won the coinflip
   - Existing keys preserved: `"rewarded"`, `"skipped_double_reward"`, `"coinflip_missed"`, `"grave_skipped"`

5. **Docstring fix**: The `"""..."""` docstring before `apply_right_feedback!` caused Julia's docsystem error because it was placed immediately after another `"""..."""` docstring (for `apply_wrong_feedback!`). Julia can only attach one docstring to the next expression. Fixed by converting the right-feedback docstring to a `#=` block comment.

### Test Coverage

`test/test_right_feedback_tiered.jl` — 11 test sets:
1. Locked votes guaranteed reward
2. High confidence unsure votes likely rewarded (statistical, n=100)
3. Low confidence unsure votes rarely rewarded (statistical, n=100)
4. Mixed locked + unsure tiers
5. `gained_this_cycle` skips even locked votes
6. Grave nodes skipped even if locked
7. Backward compat: old `Vector{String}` signature
8. Deduplication: same node in multiple votes
9. Confidence=1.0 always rewarded (unsure tier)
10. Confidence=0.0 never rewarded (unsure tier)
11. Locked vote at low confidence still guaranteed
