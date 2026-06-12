# test_log_v726.md — Context Topicality Curve

## v7.26 Changes

**Feature:** Context relevance curve for LobeOrchestrator. A lobe whose domain is relevant to the input gets a proportional ordering boost. The formula:

```
curved_avg = avg_conf * (1.0 + CONTEXT_TOPICALITY_CURVE_CAP * topicality)
```

- `topicality` = thesaurus-expanded token overlap between lobe subject and mission text (existing `_compute_lobe_topicality`)
- `CONTEXT_TOPICALITY_CURVE_CAP = 0.25` — max 25% boost at max topicality
- Zero topicality = no boost (v7.24 behavior preserved exactly)
- The curve only affects ORDERING, not admission (no muting, no gating)
- The multi-lobe gate still uses raw `avg_conf`, not `curved_avg`

### Files Modified

| File | Change |
|------|--------|
| `src/LobeOrchestrator.jl` | Added `CONTEXT_TOPICALITY_CURVE_CAP = 0.25`, `topicality` and `curved_avg` fields to `LobeVoteSummary` and `FloorWinner`, updated `summarize_lobe_votes` to accept `topicality_by_lobe` kwarg and compute curved_avg, updated sort to use `curved_avg`, updated `compute_orchestration_plan` to use `curved_avg` for tie detection |
| `src/Main.jl` | Added topicality computation before `summarize_lobe_votes` call using `_compute_lobe_topicality` + `Thesaurus.thesaurus_gate_filter`, updated telemetry println to show topicality/curved_avg |
| `test/test_context_topicality_curve.jl` | NEW — 10 test sets, 42 assertions |

### Test Results

#### test_context_topicality_curve.jl (v7.26 NEW)

| # | Test Set | Pass | Total |
|---|----------|------|-------|
| 1 | curve formula math | 9 | 9 |
| 2 | topical lobe sorts above irrelevant with same raw avg | 4 | 4 |
| 3 | curve doesn't override strong signal | 2 | 2 |
| 4 | topicality can flip close avgs | 3 | 3 |
| 5 | no topicality = v7.24 behavior | 5 | 5 |
| 6 | partial topicality: unspecified lobes get 0.0 | 5 | 5 |
| 7 | FloorWinner carries topicality + curved_avg | 4 | 4 |
| 8 | multi-lobe gate uses raw avg_conf, not curved_avg | 3 | 3 |
| 9 | CONTEXT_TOPICALITY_CURVE_CAP constant | 3 | 3 |
| 10 | curve never penalizes | 4 | 4 |
| | **TOTAL** | **42** | **42** |

#### Regression Tests

| Test Suite | Pass | Total | Status |
|------------|------|-------|--------|
| test_lobe_orchestrator.jl | 6046 | 6046 | ✅ PASS |
| test_vote_orchestrator.jl | 16/16 sets | All | ✅ PASS |
| test_lockin_floor.jl | 56 | 56 | ✅ PASS |
| test_lobe_topicality_gate.jl | 11 | 11 | ✅ PASS |
| test_sparse_active_fire.jl | 19 | 19 | ✅ PASS |
| test_sub_lockin_hedge.jl | 27 | 27 | ✅ PASS |

**Zero regressions.** All existing tests pass unchanged. The `topicality_by_lobe` kwarg defaults to empty dict, so all callers that don't provide it get v7.24 behavior exactly.
