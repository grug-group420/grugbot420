# SelfObserver IFS Upgrade — Task Tracker

## COMPLETED

- [x] Upgrade Microlog from scalar weight to IFS triple (mu, nu, pi)
- [x] Add IFS-aware constructors (6-arg IFS triple, backward-compat 4-arg salience)
- [x] Add `_ifs_enforce_invariant!` — single chokepoint for IFS invariant (mu+nu ≤ 1.0, pi = 1-mu-nu)
- [x] Add `_ifs_reinforce!` — positive/negative evidence transfer (pi→mu, pi→nu)
- [x] Add `_effective_weight` — IFML scoring with jitter (multiplicative ◇μ bonus, nu dampening)
- [x] Update `observe!` reinforcement to use IFS + enforce invariant after direct mu bump
- [x] Update all scoring/eviction paths to use `_effective_weight`
- [x] Update serialization to store mu/nu/pi
- [x] Update restore to handle new (mu/nu/pi) + old (weight) formats with IFS safety clamp
- [x] Add public IFS helpers: is_entry_mature, ifs_state, ifs_reinforce_entry!
- [x] Fix IFS invariant violation (mu+nu > 1.0) after reinforcement — root cause: direct mu bump after IFS reinforce pushed mu above 1-nu ceiling
- [x] Fix eviction scoring — multiplicative ◇μ bonus ensures high-mu entries survive over low-mu entries (vivid eviction test)
- [x] Add RelationalJitter.jl include to test file (was missing)
- [x] Export serialize_store, restore_store!, restore_global_store!
- [x] All 129 main tests pass
- [x] All 10 IFS-specific tests pass

## PENDING (from original session scope)

- [ ] Wire SelfObserver.observe! calls into the mission/vote pipeline (SelfObserver is never called from Main.jl)
- [ ] Design and build fuzzy evidence accumulator for growth/auto-link
- [ ] Implement interactive knowledge acquisition (AIML question loop when no lock-in votes)
- [ ] Re-enable auto-linker with semantic/meta evidence (NOT pattern overlap)
- [ ] Re-enable auto-growth with conservative, evidence-gated sprout system
- [ ] Wire everything into idle cycle (lazy, conservative, idle-cycle driven)
- [ ] Save/load integration testing
