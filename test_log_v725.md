# GrugBot420 v7.25 Test Log — Sub-Lockin Hedge Section

**Date:** 2026-06-12
**Commit:** pending
**Branch:** v7.15-updates

## Feature Summary

v7.25 implements the **sub-lockin hedge section** — votes below lock-in threshold
(>= 0.20, < 0.50 combined) still enter the same pool and run through the same
orchestration pipeline, but now render in a SEPARATE "This might also be true"
section AFTER the certain response + debug telemetry, NOT inline within the
primary response.

### Key Changes

1. **`generate_aiml_payload`** (Main.jl):
   - Added `hedge_pieces = String[]` alongside `support_pieces` in both deterministic
     and exploratory paths
   - Sections (c) confirmed support, (d) unlinked support, and (e) hedge band now
     push to `hedge_pieces` instead of `support_pieces`
   - New "This might also be true" section appended after debug telemetry separator
   - Hedge band rendering no longer restricted to UNSURE certainty only

2. **No changes to VoteOrchestrator.jl, LobeOrchestrator.jl, or the orchestration
   pipeline** — this is a rendering-only change. Same list, same orchestration,
   just separated in output.

3. **New test file**: `test/test_sub_lockin_hedge.jl` — 10 test sets, 27 assertions

## Test Results

| Test File | Status | Assertions |
|-----------|--------|------------|
| test/test_vote_orchestrator.jl | ✅ PASS | 904 |
| test/test_lobe_orchestrator.jl | ✅ PASS | ~6019 |
| test/test_lobe_topicality_gate.jl | ✅ PASS | 7 |
| test/test_sparse_active_fire.jl | ✅ PASS | 19 |
| test/test_lockin_floor.jl | ✅ PASS | ~40 |
| test/test_comprehensive.jl | ✅ PASS | 25 groups |
| test/test_support_relation_gate.jl | ✅ PASS | ~25 |
| test/test_support_composition.jl | ✅ PASS | ~50 |
| test/test_vote_ties.jl | ✅ PASS | ~25 |
| test/test_sub_lockin_hedge.jl | ✅ PASS | 27 |
| test/test_brainstem.jl | ✅ PASS | 39 |

### Sub-Lockin Hedge Test Details (test_sub_lockin_hedge.jl)

| # | Test | Result |
|---|------|--------|
| 1 | Sub-lockin votes render in hedge section, not inline | ✅ 7/7 |
| 2 | No hedge section when all votes lock in | ✅ 2/2 |
| 3 | Exploratory missions with sub-lockin votes get hedge section | ✅ 1/1 |
| 4 | Hedge band votes (< support floor) in hedge section | ✅ 3/3 |
| 5 | Multiple sub-lockin votes in same hedge section | ✅ 5/5 |
| 6 | Hedge section position: after debug telemetry | ✅ 5/5 |
| 7 | Lock-in floor constant = 0.50 | ✅ 1/1 |
| 8 | Confidence threshold constant = 0.20 | ✅ 1/1 |
| 9 | No inline 'Grug also sure of' for sub-lockin support votes | ✅ 1/1 |
| 10 | No inline 'Less certain' for hedge band votes | ✅ 1/1 |

## Example Output

### Before v7.25 (inline rendering):
```
[Grug] Here is the picture: boil the pasta. Grug also sure of: add the sauce.
--- DEBUG TELEMETRY ---
...
=========================================
```

### After v7.25 (separated hedge section):
```
[Grug] Here is the picture: boil the pasta.
--- DEBUG TELEMETRY ---
...
=========================================
This might also be true:
boil the pasta, and add the sauce.
```

## Pre-existing Issues

- test_sigil_pipeline.jl: 3 failures (payload format mismatch from v7.22, not related to v7.25)
