# V9.3 Routing Self-Improvement Test Log

_Generated: 2026-07-08T22:34:00.273_


## Section 1: effective_bias baseline (no adjustment yet)

- ✅ **PASS**: effective_bias(:teach) == CONSERVATIVE_BIAS[:teach] when adjustment is 0 — effective_bias=0.1 base=0.1

## Section 2: record_routing_outcome! nudging

- ✅ **PASS**: record_routing_outcome!(kind, true) increases effective_bias by BIAS_LEARN_RATE — after_success=0.12000000000000001 expected=0.12000000000000001
- ✅ **PASS**: two subsequent record_routing_outcome!(kind, false) calls decrease bias correctly — after_two_fail=0.08 expected=0.08000000000000002

## Section 3: clamp behavior

- ✅ **PASS**: BIAS_ADJUSTMENT clamps at +BIAS_ADJUSTMENT_CLAMP after many successes — clamped_high=0.3 clamp=0.3
- ✅ **PASS**: BIAS_ADJUSTMENT clamps at -BIAS_ADJUSTMENT_CLAMP after many failures — clamped_low=-0.3 clamp=-0.3
- ✅ **PASS**: effective_bias respects overall [0.0, 1.5] clamp at extreme adjustment — effective_at_low_clamp=0.0 expected=0.0

## Section 4: get_bias_adjustments/set_bias_adjustments!/reset round-trip

- ✅ **PASS**: snapshot captures :question positive nudge 
- ✅ **PASS**: snapshot captures :calculate negative nudge 
- ✅ **PASS**: reset_bias_adjustments! zeroes every kind 
- ✅ **PASS**: set_bias_adjustments! restores :question value 
- ✅ **PASS**: set_bias_adjustments! restores :calculate value 
- ✅ **PASS**: set_bias_adjustments! accepts string keys and converts to Symbol — teach=0.1 question=-0.05

## Section 5: last-routed-intent tracking

- ✅ **PASS**: default last routed intent is :none before any routing 
- ✅ **PASS**: _set_last_routed_intent!(:teach) then _get_last_routed_intent() == :teach 
- ✅ **PASS**: _set_last_routed_intent!(:question) then _get_last_routed_intent() == :question 
- ✅ **PASS**: _set_last_routed_intent!(:none) resets tracking 

## Section 6: specimen save/load round-trip

- ✅ **PASS**: save_specimen_to_file! succeeds 
- ✅ **PASS**: bias adjustments reset to zero before load (sanity) 
- ✅ **PASS**: post-load :teach bias matches pre-save value — post=0.04 pre=0.04
- ✅ **PASS**: post-load :define bias matches pre-save value — post=-0.02 pre=-0.02

## Section 7: load_specimen_from_file! wipes stale bias before restore

- ✅ **PASS**: :question polluted in-memory before load (sanity) 
- ✅ **PASS**: load_specimen_from_file! wipe zeroes stale :question adjustment not present in saved specimen — post_load[:question]=0.0
- ✅ **PASS**: load_specimen_from_file! correctly restores saved :teach adjustment — post_load[:teach]=0.02

## Summary

**23 / 23 passed** (0 failed)

