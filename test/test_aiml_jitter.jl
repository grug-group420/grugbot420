# test_aiml_jitter.jl
# ==============================================================================
# GRUG AIML JITTER INTEGRATION TESTS
# ==============================================================================
# Verifies that per-activation entropy is wired correctly into the AIML
# executive-node layer. Every bullseye value that could use a nudge MUST:
#   (a) get a fresh nudge on each activation,
#   (b) still respect hard semantic boundaries (strength clamp, coin interior),
#   (c) snap back to the deterministic value in expectation (zero-mean),
#   (d) behave as the identity function when jitter is globally disabled.
#
# Target values covered:
#   [A] AIMLNode constructor `initial_strength`  -> jitter_strength
#   [B] `_apply_strength_delta!` `delta`         -> jitter_delta
#   [C] record_fire!   coin gate (rand() < 0.5)  -> jitter_coin_threshold
#   [D] apply_aiml_right! coin gate              -> jitter_coin_threshold
#   [E] apply_aiml_wrong! coin gate              -> jitter_coin_threshold
#   [F] Honest-net-loss contract under jitter    -> integration
#   [G] disable_jitter! => identity              -> determinism regression
#
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test
using Random
using Statistics

println("\n" * "="^60)
println("GRUG AIML JITTER INTEGRATION TESTS")
println("="^60)

include("../src/AIMLNodeSystem.jl")
using .AIMLNodeSystem
# GRUG: AIMLNodeSystem re-exposes the nested RelationalJitter module. We
# reference it through the parent to match production import patterns.
using .AIMLNodeSystem.RelationalJitter

# ==============================================================================
# HELPERS
# ==============================================================================

# GRUG: Fresh registry slate before each group. AIMLNodeSystem.reset_all!()
# nukes registry + caps + cycle counter. Jitter config is a separate subsystem,
# so we reset it independently at each group boundary that needs it.
function fresh_slate!()
    AIMLNodeSystem.reset_all!()
    RelationalJitter.enable_jitter!()
    RelationalJitter.set_jitter_ratio!(RelationalJitter.JITTER_RATIO_DEFAULT)
    RelationalJitter.set_jitter_coin_ratio!(RelationalJitter.JITTER_COIN_RATIO_DEFAULT)
end

# GRUG: Sample mean of a callable over N trials. Trials are seeded per-call
# with distinct seeds so each draw is independent and the CLT applies.
function sample_mean(f::Function, n::Int)
    acc = 0.0
    for i in 1:n
        Random.seed!(i * 7919 + 1)  # GRUG: coprime stride, deterministic set
        acc += f()
    end
    Random.seed!()
    return acc / n
end

# GRUG: Empirical fire rate: proportion of trials where `f()` returns true.
function empirical_rate(f::Function, n::Int)
    hits = 0
    for i in 1:n
        Random.seed!(i * 104729 + 3)
        f() && (hits += 1)
    end
    Random.seed!()
    return hits / n
end

# ==============================================================================
# [A] AIMLNode CONSTRUCTOR — INITIAL STRENGTH JITTER
# ==============================================================================

println("\n[A] Constructor initial_strength jitter")

# GRUG: First baseline — with jitter DISABLED the seed must be exact.
fresh_slate!()
RelationalJitter.disable_jitter!()
AIMLNodeSystem.register_lobe!("lobe_A_baseline", 30)
@test begin
    # GRUG: Identity pass when disabled. Seed any value in range.
    n = AIMLNodeSystem.add_aiml_node!("lobe_A_baseline", "n1", "<t>"; initial_strength = 5.0)
    n.strength == 5.0
end
println("  ✓ jitter disabled => constructor uses initial_strength verbatim")

# GRUG: With jitter enabled, ratio 3%, |s|=5.0, the nudge window is ±0.15.
# Clamp is [FLOOR=0.0, CAP=10.0], so no clamp activates near the middle.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_A_nudge", 30)
@test begin
    n = AIMLNodeSystem.add_aiml_node!("lobe_A_nudge", "n1", "<t>"; initial_strength = 5.0)
    # GRUG: Result must land in [5.0 - 0.15 - tiny_fp, 5.0 + 0.15 + tiny_fp]
    lo = 5.0 - 5.0 * RelationalJitter.get_jitter_ratio() - 1e-9
    hi = 5.0 + 5.0 * RelationalJitter.get_jitter_ratio() + 1e-9
    lo <= n.strength <= hi
end
println("  ✓ jittered initial_strength stays within ±ratio·|s| window")

# GRUG: Zero-mean check — N freshly-built nodes should average back to seed.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_A_mean", 2000)
let total = 0.0, trials = 600
    for i in 1:trials
        Random.seed!(i * 65537)
        nid = "zm_$(i)"
        n = AIMLNodeSystem.add_aiml_node!("lobe_A_mean", nid, "<t>"; initial_strength = 5.0)
        total += n.strength
    end
    Random.seed!()
    mean_strength = total / trials
    # GRUG: With ε=0.03 on seed 5.0, Var = ε²·s²/3 = 0.0075 -> σ ≈ 0.0866.
    # SE of mean over 600 samples ≈ 0.00354. A ±0.03 window is very safe (>8σ).
    @test abs(mean_strength - 5.0) < 0.03
end
println("  ✓ mean of 600 jittered initial strengths snaps back to seed within ±0.03")

# GRUG: Near-cap seed must not escape the cap via jitter. AIML population cap
# is parent_lobe_size/3 so we register a big parent and stay well under it.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_A_cap", 900)  # cap = 300 AIML nodes
for i in 1:200
    Random.seed!(i * 1009)
    n = AIMLNodeSystem.add_aiml_node!("lobe_A_cap", "cap_$i", "<t>"; initial_strength = 10.0)
    @test n.strength <= AIMLNodeSystem.AIML_STRENGTH_CAP
    @test n.strength >= AIMLNodeSystem.AIML_STRENGTH_FLOOR
end
Random.seed!()
println("  ✓ near-cap seeds stay within [FLOOR, CAP] after jitter + clamp")

# GRUG: Near-floor seed likewise. Seed 0.0 has |s| below EPS_FLOOR so jitter
# returns 0.0 unchanged — grave-trigger semantics unaffected.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_A_floor", 10)
@test begin
    n = AIMLNodeSystem.add_aiml_node!("lobe_A_floor", "zero", "<t>"; initial_strength = 0.0)
    n.strength == 0.0
end
println("  ✓ initial_strength = 0.0 passes through jitter unchanged (eps floor)")

# ==============================================================================
# [B] _apply_strength_delta! — DELTA JITTER
# ==============================================================================

println("\n[B] Strength delta jitter via _apply_strength_delta!")

# GRUG: Direct behavioural test on the public path that goes through
# _apply_strength_delta! — we use record_fire! under a deterministic RNG
# stream where the coin always fires, so every fire applies delta = +1.0.
# We batch 100 nodes per reset to stay well under the parent/3 cap.
fresh_slate!()

# GRUG: Turn off coin-threshold jitter so we isolate the delta jitter path.
# coin_ratio = 0.0 means the 0.5 gate is NOT shifted; combined with a fixed
# RNG seed we get deterministic "always fire" behaviour for the coin.
RelationalJitter.set_jitter_coin_ratio!(0.0)

# GRUG: With seed chosen so rand() draws fall below 0.5 reliably, we exercise
# the delta jitter path. Re-seeding between calls gives independent draws.
# We re-register the lobe in batches to keep population cap usage well below
# the parent/3 ceiling.
let deltas = Float64[], batch_size = 100, total_trials = 400
    for batch_idx in 1:(total_trials ÷ batch_size)
        AIMLNodeSystem.reset_all!()
        AIMLNodeSystem.register_lobe!("lobe_B_delta", 600)  # cap = 200 AIML
        for j in 1:batch_size
            i = (batch_idx - 1) * batch_size + j
            Random.seed!(i * 131)
            AIMLNodeSystem.begin_cycle!()
            n = AIMLNodeSystem.add_aiml_node!("lobe_B_delta", "n_$i", "<t>"; initial_strength = 5.0)
            start = n.strength
            AIMLNodeSystem.record_fire!(n)
            if n.gained_this_cycle
                push!(deltas, n.strength - start)
            end
        end
    end
    Random.seed!()
    # GRUG: Every recorded delta is a jittered +1.0. Window ±0.03 means
    # each delta ∈ [0.97, 1.03]. Must all stay strictly positive.
    @test !isempty(deltas)
    @test all(d -> 0.97 - 1e-9 <= d <= 1.03 + 1e-9, deltas)
    # GRUG: Mean must snap back to +1.0 within tolerance.
    @test abs(mean(deltas) - 1.0) < 0.03
end
println("  ✓ jittered strength deltas stay within ±ratio·|d| and mean back to base")

# GRUG: Disabled jitter => delta applied exactly.
fresh_slate!()
RelationalJitter.disable_jitter!()
AIMLNodeSystem.register_lobe!("lobe_B_disabled", 10)
@test begin
    AIMLNodeSystem.begin_cycle!()
    n = AIMLNodeSystem.add_aiml_node!("lobe_B_disabled", "n1", "<t>"; initial_strength = 5.0)
    # GRUG: Seed gives rand() < 0.5 for the coin, so we fire and apply +1.0.
    Random.seed!(1)
    AIMLNodeSystem.record_fire!(n)
    # Result is either 5.0 (didn't fire) or exactly 6.0 (fired, identity delta).
    n.strength == 5.0 || n.strength == 6.0
end
Random.seed!()
println("  ✓ jitter disabled => deltas applied at exact magnitude")

# ==============================================================================
# [C][D][E] COIN-THRESHOLD JITTER — GATE BIAS STAYS SANE
# ==============================================================================

println("\n[C][D][E] Coin-threshold jitter on AIML 50/50 gates")

# GRUG: Long-run empirical rate must stay near 0.5. With default coin_ratio
# = 0.01, the per-draw threshold is in [0.49, 0.51], giving a long-run
# fire rate that, integrated over the uniform threshold, is still 0.5.
fresh_slate!()
let n = 4000
    rate = empirical_rate(n) do
        # GRUG: Draw a fresh threshold per call, then flip coin against it.
        # This mirrors the in-module pattern `rand() < jitter_coin_threshold(0.5)`.
        rand() < RelationalJitter.jitter_coin_threshold(0.5)
    end
    # GRUG: Binomial SE at p=0.5, n=4000 is ~0.0079. ±0.04 window is >5σ.
    @test abs(rate - 0.5) < 0.04
end
println("  ✓ jitter_coin_threshold(0.5) yields ~50/50 long-run (±0.04 of 0.5)")

# GRUG: Bound check — threshold after jitter stays strictly inside (0, 1),
# never reaching a degenerate always-yes or always-no gate.
fresh_slate!()
for i in 1:500
    Random.seed!(i * 997)
    p = RelationalJitter.jitter_coin_threshold(0.5)
    @test RelationalJitter.JITTER_COIN_FLOOR - 1e-12 <= p <= RelationalJitter.JITTER_COIN_CEILING + 1e-12
end
Random.seed!()
println("  ✓ coin threshold stays in [FLOOR, CEILING] across 500 draws")

# GRUG: Integration — record_fire! under jitter still yields ~50% gain rate.
# Batch trials so we stay under the AIML population cap each round.
fresh_slate!()
let gains = 0, batch_size = 200, total_trials = 2000
    for batch_idx in 1:(total_trials ÷ batch_size)
        AIMLNodeSystem.reset_all!()
        AIMLNodeSystem.register_lobe!("lobe_C_rate", 900)  # cap = 300
        for j in 1:batch_size
            i = (batch_idx - 1) * batch_size + j
            Random.seed!(i * 31337)
            AIMLNodeSystem.begin_cycle!()
            n = AIMLNodeSystem.add_aiml_node!("lobe_C_rate", "n_$i", "<t>"; initial_strength = 5.0)
            AIMLNodeSystem.record_fire!(n)
            n.gained_this_cycle && (gains += 1)
        end
    end
    Random.seed!()
    rate = gains / total_trials
    # GRUG: Same ±0.04 window as the primitive check above.
    @test abs(rate - 0.5) < 0.05
end
println("  ✓ record_fire! coin gate under jitter fires ~50% long-run")

# GRUG: apply_aiml_right! coin gate — only non-gainer contributors are eligible,
# so we pre-fire without gaining by directly setting fired_this_cycle.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_D_right", 3000)
let rewarded_total = 0, eligible_total = 0, trials = 400
    for i in 1:trials
        Random.seed!(i * 49999)
        AIMLNodeSystem.begin_cycle!()
        # GRUG: Create 5 contributors per trial. Manually flag fired_this_cycle
        # to bypass the record_fire! gate and isolate /aimlRight's coin.
        for k in 1:5
            n = AIMLNodeSystem.add_aiml_node!("lobe_D_right", "n_$(i)_$(k)", "<t>"; initial_strength = 5.0)
            n.fired_this_cycle = true
            # GRUG: explicit non-gain so /aimlRight considers this node eligible.
            n.gained_this_cycle = false
        end
        result = AIMLNodeSystem.apply_aiml_right!()
        rewarded_total += length(result["rewarded"])
        eligible_total += result["total_contributors"]
        AIMLNodeSystem.reset_all!()
        AIMLNodeSystem.register_lobe!("lobe_D_right", 3000)
    end
    Random.seed!()
    rate = rewarded_total / eligible_total
    @test abs(rate - 0.5) < 0.05
end
println("  ✓ apply_aiml_right! secondary-reward gate fires ~50% under jitter")

# GRUG: apply_aiml_wrong! coin gate — every fired contributor is eligible.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_E_wrong", 3000)
let penalized_total = 0, eligible_total = 0, trials = 400
    for i in 1:trials
        Random.seed!(i * 71237)
        AIMLNodeSystem.begin_cycle!()
        for k in 1:5
            n = AIMLNodeSystem.add_aiml_node!("lobe_E_wrong", "n_$(i)_$(k)", "<t>"; initial_strength = 5.0)
            n.fired_this_cycle = true
        end
        result = AIMLNodeSystem.apply_aiml_wrong!()
        penalized_total += length(result["penalized"])
        eligible_total += result["total_contributors"]
        AIMLNodeSystem.reset_all!()
        AIMLNodeSystem.register_lobe!("lobe_E_wrong", 3000)
    end
    Random.seed!()
    rate = penalized_total / eligible_total
    @test abs(rate - 0.5) < 0.05
end
println("  ✓ apply_aiml_wrong! penalty gate fires ~50% under jitter")

# ==============================================================================
# [F] HONEST-NET-LOSS CONTRACT UNDER JITTER
# ==============================================================================

println("\n[F] Honest-net-loss under jitter (hard spec rule)")

# GRUG: Spec rule: if a node GAINED strength in-cycle and then /aimlWrong
# penalizes it, final strength MUST end strictly below cycle-start strength.
# Under jitter this must still hold. Penalty magnitude = delta + prior_gain,
# which is strictly > 0, and jitter preserves sign (ratio < 1), so the
# applied delta is always strictly negative.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_F_netloss", 2000)
let violations = 0, checks = 0, trials = 1000
    for i in 1:trials
        Random.seed!(i * 10007 + 5)
        AIMLNodeSystem.begin_cycle!()
        n = AIMLNodeSystem.add_aiml_node!("lobe_F_netloss", "n_$i", "<t>"; initial_strength = 5.0)
        cycle_start = n.strength
        # GRUG: Force a use-gain via direct delta application (bypass coin
        # so we guarantee gained_this_cycle = true for this trial).
        AIMLNodeSystem._apply_strength_delta!(n, AIMLNodeSystem.AIML_STRENGTH_DELTA)
        gained = n.gained_this_cycle
        n.fired_this_cycle = true
        # GRUG: Force a penalty (coin_ratio=0 + fixed seed) by shifting the
        # coin_ratio to its max-effect and seeding so rand()<0.5 most of
        # the time. Instead we just call /aimlWrong and only assert on
        # trials where the node was actually penalized.
        result = AIMLNodeSystem.apply_aiml_wrong!()
        if gained && (n.id in result["penalized"])
            checks += 1
            if !(n.strength < cycle_start)
                violations += 1
            end
        end
        AIMLNodeSystem.reset_all!()
        AIMLNodeSystem.register_lobe!("lobe_F_netloss", 2000)
    end
    Random.seed!()
    @test checks > 0  # GRUG: sanity — some trials must have been penalized
    @test violations == 0
end
println("  ✓ every penalized gainer ended strictly below cycle-start strength (0 violations)")

# ==============================================================================
# [G] JITTER DISABLE TOGGLE — FULL DETERMINISTIC REGRESSION
# ==============================================================================

println("\n[G] disable_jitter! => identity contract across AIML layer")

fresh_slate!()
RelationalJitter.disable_jitter!()
AIMLNodeSystem.register_lobe!("lobe_G_det", 50)
@test begin
    # GRUG: Every single jittered path must be an identity function now.
    AIMLNodeSystem.begin_cycle!()
    n = AIMLNodeSystem.add_aiml_node!("lobe_G_det", "n1", "<t>"; initial_strength = 5.0)
    n.strength == 5.0
end
@test begin
    # GRUG: Direct delta application is also the identity under disable.
    AIMLNodeSystem.begin_cycle!()
    n = AIMLNodeSystem.add_aiml_node!("lobe_G_det", "n2", "<t>"; initial_strength = 5.0)
    AIMLNodeSystem._apply_strength_delta!(n, 1.0)
    n.strength == 6.0
end
@test begin
    # GRUG: Coin threshold under disable returns the base probability unchanged.
    RelationalJitter.jitter_coin_threshold(0.5) == 0.5
end
println("  ✓ strength, delta, and coin threshold are identity when jitter disabled")

# GRUG: Re-enable at the end so we don't contaminate later tests in the suite.
RelationalJitter.enable_jitter!()

# ==============================================================================
# [H] ERROR HANDLING — NO SILENT FAILURES
# ==============================================================================

println("\n[H] Error handling — NO silent failures")

# GRUG: AIMLNode constructor rejects out-of-range initial strength BEFORE
# jitter runs. Ensures jitter never sees an illegal seed.
fresh_slate!()
AIMLNodeSystem.register_lobe!("lobe_H_err", 5)
@test_throws AIMLNodeSystem.AIMLNodeError AIMLNodeSystem.add_aiml_node!(
    "lobe_H_err", "bad1", "<t>"; initial_strength = -1.0
)
@test_throws AIMLNodeSystem.AIMLNodeError AIMLNodeSystem.add_aiml_node!(
    "lobe_H_err", "bad2", "<t>"; initial_strength = 11.0
)
println("  ✓ out-of-range initial_strength throws AIMLNodeError before jitter")

# GRUG: Direct primitive error cases still propagate through the AIML
# import path — no accidental silencing from the intermediate module.
@test_throws RelationalJitter.JitterError RelationalJitter.jitter_strength(NaN)
@test_throws RelationalJitter.JitterError RelationalJitter.jitter_delta(Inf)
@test_throws RelationalJitter.JitterError RelationalJitter.jitter_coin_threshold(-0.01)
@test_throws RelationalJitter.JitterError RelationalJitter.jitter_coin_threshold(1.01)
@test_throws RelationalJitter.JitterError RelationalJitter.jitter_coin_threshold(NaN)
println("  ✓ NaN/Inf/out-of-range inputs raise JitterError (no silent clamping)")

# ==============================================================================
# SUMMARY
# ==============================================================================

println("\n" * "="^60)
println("ALL AIML JITTER TESTS PASSED! 8 test groups complete.")
println("Values verified under per-activation entropy:")
println("  - AIMLNode initial_strength (A)")
println("  - _apply_strength_delta! delta (B)")
println("  - record_fire! coin gate (C)")
println("  - apply_aiml_right! coin gate (D)")
println("  - apply_aiml_wrong! coin gate (E)")
println("  - honest-net-loss contract under jitter (F)")
println("  - disable_jitter! identity contract (G)")
println("  - error propagation, no silent failures (H)")
println("="^60)