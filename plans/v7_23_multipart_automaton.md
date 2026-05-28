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
- `test/test_multipart_orchestrator.jl`
- `test/test_ephemeral_automaton.jl`
- `test/test_procedure_sigil.jl`
- `plans/v7_23_multipart_automaton.md` (this file)

## Files modified
- `src/engine.jl` — extend `Vote` with two optional fields (default values
  preserve back-compat).
- `src/SigilRegistry.jl` — promote `:procedure` from reserved to active +
  add `register_procedure_sigil!`.
- `src/ActionTonePredictor.jl` — add `maybe_escalate` hook + automaton trace
  consumption.
- `src/Main.jl` — `ephemeral_aiml_orchestrator` consumes multipart objectives;
  `/automaton` CLI commands for rule add/list/remove.
- `src/GrugBot420.jl` — register the two new modules.
- `test/runtests.jl` — include the three new test files.

## Test plan
1. Singleton votes still produce identical AIML output (no regression).
2. A 1-node-3-part vote group produces ONE objective with 1 primary +
   2 supports, all under one subject.
3. Mixed singleton + multipart groups orchestrate independently.
4. ATP escalation only fires when family is in `ESCALATION_FAMILIES` and
   confidence ≥ threshold; otherwise zero cost.
5. Automaton with `jitter_targets = [:value]` produces different `value` on
   repeated fires but same `step_index` and `operator`.
6. Procedure sigil `&Σ` expands at promotion to its registered chain.
7. Unknown procedure sigil throws `SigilResolutionError` (no silent fallback).

## Done = green tests, no warnings beyond pre-existing, doc updated.
