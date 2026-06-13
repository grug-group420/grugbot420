# Grug Notice Soft Spots — Task Tracker

## 1. ActionScript Dynamic vs Static — More Operations (Especially Conditional) ✅
- [x] Design conditional ops (IF, WHEN, UNLESS) that respect the static/dynamic distinction
- [x] Design predicate ops (EQUALS, CONTAINS, PRESENT, EMPTY, HAS, GT, LT, GTE, LTE) for introspection before branching
- [x] Add new ops to ALL_OPS/CONDITIONAL_OPS/PREDICATE_OPS sets and _validate_template (static rejects conditionals)
- [x] Implement _split_args for nested-paren-aware argument splitting
- [x] Implement _eval_predicate for Bool-returning predicate evaluation
- [x] Implement _eval_op_chain branches for IF/WHEN/UNLESS + all predicate ops
- [x] Update ActionEntry docs/comments (v7.35 header)
- [x] Add default action entries using new ops (remind, announce, recall, confirm)
- [x] Test: 44/44 ActionScript conditional tests pass
- [x] No regressions: 129/129 main tests, 10/10 IFS tests still pass

## 2. Polarity Gate Multipliers — Tunable Per-Lobe Sensitivity ✅
- [x] Design PolaritySensitivity config struct (per-lobe multiplier overrides)
- [x] Replace hardcoded 0.3/0.7/1.0 in knowledge node polarity gate with configurable values
- [x] Replace hardcoded 0.3/0.7/1.0 in sigil polarity gate with configurable values
- [x] Add LobeTable integration — lobes can register their own sensitivity profile
- [x] Default values match current behavior (0.3/0.7/1.0) — zero regression
- [x] Test with custom per-lobe sensitivities (15/15 tests pass)

## 3. RESOLVE Callbacks — Stronger Conflict Resolution for Multiple Refs ✅
- [x] Design multi-ref resolution strategy (priority ordering, merge, or first-wins with warning)
- [x] Update resolve_reference to handle compound queries with multiple ref keywords
- [x] Add conflict resolution modes (:first_wins, :merge, :priority)
- [x] Wire subconscious callback to SelfObserver (via peek_pattern)
- [x] Add audit trail in SelfObserver when refs conflict (_audit_ref_conflict)
- [x] Test multi-ref conflict scenarios (35/35 tests pass)

## VERIFICATION ✅
- [x] All 129 main tests still pass after all changes
- [x] All 10 IFS tests still pass after all changes
- [x] All 44 ActionScript conditional tests pass
- [x] All 15 Lobe polarity sensitivity tests pass
- [x] All 35 RESOLVE conflict resolution tests pass
