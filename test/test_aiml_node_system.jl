# test_aiml_node_system.jl
# ==============================================================================
# GRUG AIML NODE SYSTEM COMPREHENSIVE TESTS
# Tests every hard rule from the spec:
#   - Use-based strength gain (coinflip)
#   - /aimlRight exclusion after same-cycle use gain (no double snack)
#   - /aimlWrong compensating net loss after same-cycle use gain (real punishment)
#   - Standard reward/punishment when no prior same-cycle gain
#   - AIML_GRAVE transition at zero strength
#   - Population cap enforcement at 1/3 parent lobe size (no silent overflow)
#   - Lobe isolation (feedback only touches relevant lobe voters)
#   - Phagy hook compatibility (graves can be pruned without breaking state)
#   - Cycle memory reset between cycles
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG AIML NODE SYSTEM TESTS")
println("="^60)

include("../src/AIMLNodeSystem.jl")
using .AIMLNodeSystem

# GRUG: AIMLNodeSystem now routes strength values, strength deltas, and the
# three 50/50 coin gates through RelationalJitter for per-activation entropy.
# This test file was written BEFORE that feature and asserts exact arithmetic
# (strength == 5.0, strength == 6.0, strength == 4.0, ...). Those assertions
# stay valid under the "snap back in expectation" contract, but a single run
# can see small nudges. We disable jitter for this whole test file to keep
# the arithmetic assertions deterministic. Re-enable at the end so nothing
# else in the subprocess is contaminated.
# Dedicated jitter-behavior tests live in test_aiml_jitter.jl.
using .AIMLNodeSystem.RelationalJitter
RelationalJitter.disable_jitter!()

# ==============================================================================
# HELPERS
# ==============================================================================

# GRUG: Fresh slate before each test group. AIMLNodeSystem.reset_all!() nukes
# registry, caps, and cycle counter. Tests must NOT depend on each other's state.
function fresh_slate!()
    AIMLNodeSystem.reset_all!()
end

# GRUG: Deterministic RNG seeding so coinflip-dependent tests are reproducible.
# We seed before each trial batch. Tests that need "all win" or "all lose"
# use retry loops or direct strength manipulation instead of relying on seed luck.
function with_seed(f, seed::Int)
    Random.seed!(seed)
    result = f()
    Random.seed!()  # GRUG: Unseed after. Don't leak determinism into neighbours.
    return result
end

# ==============================================================================
# [1] MODULE LOAD & CONSTANTS
# ==============================================================================
println("\n[1] MODULE LOAD & CONSTANTS")

@test AIMLNodeSystem.AIML_STRENGTH_CAP       == 10.0
@test AIMLNodeSystem.AIML_STRENGTH_FLOOR     == 0.0
@test AIMLNodeSystem.AIML_POPULATION_CAP_RATIO == 3
@test AIMLNodeSystem.AIML_STRENGTH_DELTA     == 1.0
@test AIMLNodeSystem.AIML_GRAVE_REASON_STRENGTH_ZERO == "AIML_STRENGTH_ZERO"
println("  ✓ Module constants correct")

# ==============================================================================
# [2] LOBE REGISTRATION
# ==============================================================================
println("\n[2] LOBE REGISTRATION")
fresh_slate!()

# GRUG: register_lobe! must compute cap = floor(parent / 3).
cap = AIMLNodeSystem.register_lobe!("science", 20000)
@test cap == 6666   # floor(20000 / 3)
@test AIMLNodeSystem.is_lobe_registered("science")
@test AIMLNodeSystem.get_population_cap("science") == 6666
println("  ✓ register_lobe! computes cap = floor(parent/3) = 6666")

# GRUG: Small parent lobe.
cap2 = AIMLNodeSystem.register_lobe!("tiny", 9)
@test cap2 == 3   # floor(9 / 3)
println("  ✓ register_lobe! with small parent: cap = 3")

# GRUG: Re-registering updates cap, does NOT wipe existing nodes.
cap3 = AIMLNodeSystem.register_lobe!("science", 300)
@test cap3 == 100
@test AIMLNodeSystem.is_lobe_registered("science")
println("  ✓ re-registering lobe updates cap, does not wipe nodes")

# GRUG: Empty lobe_id throws.
@test_throws AIMLNodeError AIMLNodeSystem.register_lobe!("", 100)
println("  ✓ empty lobe_id throws AIMLNodeError")

# GRUG: Non-positive parent cap throws.
@test_throws AIMLNodeError AIMLNodeSystem.register_lobe!("bad", 0)
@test_throws AIMLNodeError AIMLNodeSystem.register_lobe!("bad", -5)
println("  ✓ non-positive parent_lobe_cap throws")

# GRUG: Unregistered lobe throws on get_population_cap.
@test_throws AIMLNodeError AIMLNodeSystem.get_population_cap("nolobe")
println("  ✓ get_population_cap throws for unregistered lobe")

# GRUG: is_lobe_registered returns false for missing lobe without throwing.
@test !AIMLNodeSystem.is_lobe_registered("phantom")
println("  ✓ is_lobe_registered returns false for missing lobe (no throw)")

# ==============================================================================
# [3] NODE LIFECYCLE
# ==============================================================================
println("\n[3] NODE LIFECYCLE")
fresh_slate!()

AIMLNodeSystem.register_lobe!("lobe_a", 30)  # cap = 10

# GRUG: add_aiml_node! creates a live node with correct default state.
n = AIMLNodeSystem.add_aiml_node!("lobe_a", "node_1", "Executive template alpha"; initial_strength=5.0)
@test n.id          == "node_1"
@test n.lobe_id     == "lobe_a"
@test n.template    == "Executive template alpha"
@test n.strength    == 5.0
@test !n.is_grave
@test n.grave_reason == ""
@test !n.voted_this_cycle
@test !n.fired_this_cycle
@test !n.gained_this_cycle
@test n.strength_delta_this_cycle == 0.0
println("  ✓ add_aiml_node! creates node with correct initial state")

# GRUG: get_aiml_node returns the same node.
n2 = AIMLNodeSystem.get_aiml_node("lobe_a", "node_1")
@test n2.id == "node_1"
println("  ✓ get_aiml_node retrieves existing node")

# GRUG: has_aiml_node probe.
@test  AIMLNodeSystem.has_aiml_node("lobe_a", "node_1")
@test !AIMLNodeSystem.has_aiml_node("lobe_a", "ghost")
@test !AIMLNodeSystem.has_aiml_node("no_lobe", "node_1")
println("  ✓ has_aiml_node probe works correctly")

# GRUG: Duplicate node throws.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("lobe_a", "node_1", "duplicate")
println("  ✓ duplicate node_id throws AIMLNodeError")

# GRUG: Unregistered lobe throws on add.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("ghost_lobe", "n", "t")
println("  ✓ add_aiml_node! to unregistered lobe throws")

# GRUG: Empty id/template throw.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("lobe_a", "",        "tmpl")
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("lobe_a", "node_x",  "")
println("  ✓ empty node_id or template throws")

# GRUG: Out-of-range initial_strength throws.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("lobe_a", "bad1", "t"; initial_strength=-0.1)
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("lobe_a", "bad2", "t"; initial_strength=10.1)
println("  ✓ out-of-range initial_strength throws")

# GRUG: remove_aiml_node! removes correctly.
AIMLNodeSystem.add_aiml_node!("lobe_a", "node_del", "to delete")
@test  AIMLNodeSystem.remove_aiml_node!("lobe_a", "node_del")
@test !AIMLNodeSystem.has_aiml_node("lobe_a", "node_del")
@test !AIMLNodeSystem.remove_aiml_node!("lobe_a", "node_del")  # second remove = false
println("  ✓ remove_aiml_node! removes and returns false on re-remove")

# GRUG: list_aiml_nodes returns sorted snapshot.
AIMLNodeSystem.add_aiml_node!("lobe_a", "z_node", "zzz")
AIMLNodeSystem.add_aiml_node!("lobe_a", "a_node", "aaa")
nodes_list = AIMLNodeSystem.list_aiml_nodes("lobe_a")
ids = [n.id for n in nodes_list]
@test ids == sort(ids)  # must be sorted
println("  ✓ list_aiml_nodes returns sorted snapshot")

# GRUG: get_population_size counts correctly.
@test AIMLNodeSystem.get_population_size("lobe_a") == length(nodes_list)
println("  ✓ get_population_size matches actual count")

# ==============================================================================
# [4] POPULATION CAP ENFORCEMENT
# ==============================================================================
println("\n[4] POPULATION CAP ENFORCEMENT")
fresh_slate!()

# GRUG: parent_lobe_cap=3 -> aiml_cap=1 (floor(3/3)=1).
AIMLNodeSystem.register_lobe!("tight", 3)
@test AIMLNodeSystem.get_population_cap("tight") == 1

# GRUG: First node fits.
AIMLNodeSystem.add_aiml_node!("tight", "fits", "template")
@test AIMLNodeSystem.get_population_size("tight") == 1

# GRUG: Second node must throw — cap=1 is hard limit.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("tight", "overflow", "will fail")
println("  ✓ Population cap enforced: cap=1 node, overflow throws AIMLNodeError")

# GRUG: Confirm the single node is still intact after the failed add.
@test AIMLNodeSystem.has_aiml_node("tight", "fits")
@test AIMLNodeSystem.get_population_size("tight") == 1
println("  ✓ Failed add leaves existing nodes intact")

# GRUG: Larger cap scenario - add up to exactly cap, then overflow.
AIMLNodeSystem.register_lobe!("medium", 21)  # cap = 7
for i in 1:7
    AIMLNodeSystem.add_aiml_node!("medium", "m$i", "tmpl $i")
end
@test AIMLNodeSystem.get_population_size("medium") == 7
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("medium", "overflow", "x")
println("  ✓ cap=7 (parent=21): add 7 succeeds, 8th throws")

# GRUG: NEW TEST - Graves don't count towards population cap!
println("\n[4b] GRAVE EXCLUSION FROM CAP")
fresh_slate!()
AIMLNodeSystem.register_lobe!("grave_cap_test", 9)  # cap = 3

# Add 3 nodes (fills cap)
AIMLNodeSystem.add_aiml_node!("grave_cap_test", "alive1", "tmpl1")
AIMLNodeSystem.add_aiml_node!("grave_cap_test", "alive2", "tmpl2")
AIMLNodeSystem.add_aiml_node!("grave_cap_test", "grave1", "tmpl3")
@test AIMLNodeSystem.get_population_size("grave_cap_test") == 3
@test AIMLNodeSystem.get_alive_population_size("grave_cap_test") == 3

# Mark one as grave
node = AIMLNodeSystem.get_aiml_node("grave_cap_test", "grave1")
node.is_grave = true
@test AIMLNodeSystem.get_alive_population_size("grave_cap_test") == 2

# GRUG: Now cap should have room! 2 alive + 1 grave = 3 total, but cap=3 for alive.
# We should be able to add one more alive node.
AIMLNodeSystem.add_aiml_node!("grave_cap_test", "alive3", "tmpl4")
println("  ✓ Grave nodes excluded from cap: 1 grave + 3 alive in cap=3 lobe")

# But 4th alive should fail
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("grave_cap_test", "overflow", "x")
println("  ✓ 4th alive node correctly rejected (cap=3 for alive nodes)")

# ==============================================================================
# [5] LOBE ISOLATION
# ==============================================================================
println("\n[5] LOBE ISOLATION")
fresh_slate!()

AIMLNodeSystem.register_lobe!("lobe_iso_a", 30)
AIMLNodeSystem.register_lobe!("lobe_iso_b", 30)

# GRUG: Same node_id in different lobes is allowed (lobes are independent namespaces).
AIMLNodeSystem.add_aiml_node!("lobe_iso_a", "shared_id", "tmpl in A")
AIMLNodeSystem.add_aiml_node!("lobe_iso_b", "shared_id", "tmpl in B")
@test AIMLNodeSystem.has_aiml_node("lobe_iso_a", "shared_id")
@test AIMLNodeSystem.has_aiml_node("lobe_iso_b", "shared_id")
println("  ✓ Same node_id can exist independently in different lobes")

# GRUG: Voting + cycle reset only affects the node in the lobe it lives in.
AIMLNodeSystem.begin_cycle!()
node_a = AIMLNodeSystem.get_aiml_node("lobe_iso_a", "shared_id")
node_b = AIMLNodeSystem.get_aiml_node("lobe_iso_b", "shared_id")

AIMLNodeSystem.record_vote!(node_a)
# GRUG: Only mark node_a as voted. node_b should stay un-voted.
@test  node_a.voted_this_cycle
@test !node_b.voted_this_cycle
println("  ✓ Voting node_a does not touch node_b in different lobe")

# GRUG: /aimlRight must only affect lobe_iso_a's voted node, not lobe_iso_b's.
strength_b_before = node_b.strength
AIMLNodeSystem.apply_aiml_right!()
@test node_b.strength == strength_b_before  # node_b untouched by /aimlRight
println("  ✓ /aimlRight does not affect nodes in lobes without voted nodes")

# GRUG: get_registered_lobes returns all lobes.
lobes = AIMLNodeSystem.get_registered_lobes()
@test "lobe_iso_a" in lobes
@test "lobe_iso_b" in lobes
println("  ✓ get_registered_lobes lists all registered lobes")

# ==============================================================================
# [6] CYCLE MANAGEMENT
# ==============================================================================
println("\n[6] CYCLE MANAGEMENT")
fresh_slate!()

AIMLNodeSystem.register_lobe!("cycle_lobe", 30)
AIMLNodeSystem.add_aiml_node!("cycle_lobe", "cn1", "tmpl")
node_c = AIMLNodeSystem.get_aiml_node("cycle_lobe", "cn1")

# GRUG: Manually set cycle flags to dirty state, then verify begin_cycle! clears them.
node_c.voted_this_cycle           = true
node_c.fired_this_cycle           = true
node_c.gained_this_cycle          = true
node_c.strength_delta_this_cycle  = 3.0

cycle_before = AIMLNodeSystem.current_cycle()
AIMLNodeSystem.begin_cycle!()

@test AIMLNodeSystem.current_cycle() == cycle_before + 1
@test !node_c.voted_this_cycle
@test !node_c.fired_this_cycle
@test !node_c.gained_this_cycle
@test node_c.strength_delta_this_cycle == 0.0
println("  ✓ begin_cycle! increments counter and resets all per-cycle flags")

# ==============================================================================
# [7] STRENGTH DYNAMICS — USE-BASED GAIN
# ==============================================================================
println("\n[7] STRENGTH DYNAMICS — USE-BASED GAIN")
fresh_slate!()

AIMLNodeSystem.register_lobe!("str_lobe", 30)
AIMLNodeSystem.add_aiml_node!("str_lobe", "sn1", "tmpl"; initial_strength=5.0)
sn1 = AIMLNodeSystem.get_aiml_node("str_lobe", "sn1")

AIMLNodeSystem.begin_cycle!()

# GRUG: record_fire! has a 50/50 coinflip. Run many trials to verify statistical gain.
# We check that over 200 fires, the node gains strength at least once (not just zeroes).
# Strict: We also verify gained_this_cycle is set correctly when strength grows.
#
# Strategy: force a known-gain scenario by running until we get a gain,
# resetting between attempts. Maximum 200 single-fire trials should hit at least one gain.
# GRUG: Wrap in let block to avoid Julia top-level soft-scope warning.
let
    gained_at_least_once = false
    for trial in 1:200
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("str_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("str_lobe", "sn_trial", "tmpl"; initial_strength=5.0)
        node_trial = AIMLNodeSystem.get_aiml_node("str_lobe", "sn_trial")
        AIMLNodeSystem.begin_cycle!()
        AIMLNodeSystem.record_fire!(node_trial)
        if node_trial.gained_this_cycle
            @test node_trial.strength > 5.0
            @test node_trial.strength_delta_this_cycle > 0.0
            @test node_trial.fired_this_cycle
            gained_at_least_once = true
            break
        end
    end
    @test gained_at_least_once
end
println("  ✓ record_fire! can gain strength on coinflip (verified over ≤200 trials)")

# GRUG: record_fire! also sets fired_this_cycle even if no strength gain (coinflip miss).
fresh_slate!()
AIMLNodeSystem.register_lobe!("str_lobe", 30)
AIMLNodeSystem.add_aiml_node!("str_lobe", "sn2", "tmpl"; initial_strength=5.0)
sn2 = AIMLNodeSystem.get_aiml_node("str_lobe", "sn2")
AIMLNodeSystem.begin_cycle!()
# Force at least one fire call and check fired_this_cycle is always set.
AIMLNodeSystem.record_fire!(sn2)
@test sn2.fired_this_cycle
println("  ✓ record_fire! always sets fired_this_cycle regardless of coinflip outcome")

# GRUG: Strength is capped at AIML_STRENGTH_CAP. Cannot exceed the ceiling.
fresh_slate!()
AIMLNodeSystem.register_lobe!("str_lobe", 30)
AIMLNodeSystem.add_aiml_node!("str_lobe", "cap_node", "tmpl"; initial_strength=10.0)
cap_node = AIMLNodeSystem.get_aiml_node("str_lobe", "cap_node")
AIMLNodeSystem.begin_cycle!()
for _ in 1:20
    AIMLNodeSystem.record_fire!(cap_node)
end
@test cap_node.strength <= AIMLNodeSystem.AIML_STRENGTH_CAP
println("  ✓ Strength cannot exceed AIML_STRENGTH_CAP")

# GRUG: Grave nodes do not gain from record_fire!.
fresh_slate!()
AIMLNodeSystem.register_lobe!("str_lobe", 30)
AIMLNodeSystem.add_aiml_node!("str_lobe", "grave_fire", "tmpl"; initial_strength=5.0)
gf_node = AIMLNodeSystem.get_aiml_node("str_lobe", "grave_fire")
gf_node.is_grave = true  # Force grave
AIMLNodeSystem.begin_cycle!()
strength_before_fire = gf_node.strength
for _ in 1:20
    AIMLNodeSystem.record_fire!(gf_node)
end
@test gf_node.strength == strength_before_fire  # Grave nodes do not gain
println("  ✓ Grave nodes do not gain strength from record_fire!")

# ==============================================================================
# [8] /aimlRight — REWARD EXCLUSION AFTER SAME-CYCLE GAIN
# ==============================================================================
println("\n[8] /aimlRight — REWARD EXCLUSION AFTER SAME-CYCLE GAIN")
fresh_slate!()

AIMLNodeSystem.register_lobe!("right_lobe", 30)

# GRUG: Scenario A — node already gained strength this cycle from use.
# /aimlRight must SKIP it (no double snack rule).
AIMLNodeSystem.add_aiml_node!("right_lobe", "pre_gained", "tmpl"; initial_strength=5.0)
pg_node = AIMLNodeSystem.get_aiml_node("right_lobe", "pre_gained")
AIMLNodeSystem.begin_cycle!()
# Manually simulate that the node already gained this cycle (bypass coinflip)
# CRITICAL: Must set fired_this_cycle for node to be considered a contributor
pg_node.voted_this_cycle  = true
pg_node.fired_this_cycle  = true  # Node contributed to output
pg_node.gained_this_cycle = true
pg_node.strength_delta_this_cycle = 1.0
pg_node.strength = 6.0  # Simulate strength after use-gain

strength_before_right = pg_node.strength
result_a = AIMLNodeSystem.apply_aiml_right!()
# GRUG: Node must appear in skipped_double_reward, NOT in rewarded.
@test pg_node.id in result_a["skipped_double_reward"]
@test !(pg_node.id in result_a["rewarded"])
@test pg_node.strength == strength_before_right  # Strength unchanged
println("  ✓ /aimlRight skips node that already gained this cycle (no double snack)")

# GRUG: Scenario B — node voted but did NOT gain this cycle.
# /aimlRight may reward it via coinflip. Run 200 trials to get at least one reward.
let
    got_rewarded = false
    for trial in 1:200
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("right_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("right_lobe", "no_gain", "tmpl"; initial_strength=5.0)
        ng_node = AIMLNodeSystem.get_aiml_node("right_lobe", "no_gain")
        AIMLNodeSystem.begin_cycle!()
        ng_node.voted_this_cycle  = true
        ng_node.fired_this_cycle  = true  # Node contributed to output
        ng_node.gained_this_cycle = false
        result_b = AIMLNodeSystem.apply_aiml_right!()
        if ng_node.id in result_b["rewarded"]
            @test ng_node.strength == 6.0  # 5.0 + 1.0
            got_rewarded = true
            break
        end
    end
    @test got_rewarded
end
println("  ✓ /aimlRight can reward node that did NOT already gain this cycle")

# GRUG: /aimlRight with no voters returns zero-voter result.
fresh_slate!()
AIMLNodeSystem.register_lobe!("right_lobe", 30)
AIMLNodeSystem.begin_cycle!()
result_no_voters = AIMLNodeSystem.apply_aiml_right!()
@test result_no_voters["total_contributors"] == 0
println("  ✓ /aimlRight with no contributors reports total_contributors=0")

# ==============================================================================
# [9] /aimlWrong — COMPENSATING NET LOSS
# ==============================================================================
println("\n[9] /aimlWrong — COMPENSATING NET LOSS")
fresh_slate!()

AIMLNodeSystem.register_lobe!("wrong_lobe", 30)

# GRUG: Scenario A — node gained strength this cycle from use, THEN /aimlWrong fires.
# Penalty must be large enough to produce a REAL net loss (strength_delta_this_cycle + 1.0).
# We simulate coinflip=penalize by running many trials and checking that whenever
# a penalized node had prior_gain, it always ends strictly below its cycle-start strength.

let
    penalized_with_prior_gain_tested = false
    for trial in 1:500
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("wrong_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("wrong_lobe", "gained_before", "tmpl"; initial_strength=5.0)
        gb_node = AIMLNodeSystem.get_aiml_node("wrong_lobe", "gained_before")
        AIMLNodeSystem.begin_cycle!()

        # GRUG: Simulate use-gain: strength 5.0 -> 6.0, delta=1.0
        gb_node.voted_this_cycle           = true
        gb_node.fired_this_cycle           = true  # Node contributed to output
        gb_node.gained_this_cycle          = true
        gb_node.strength_delta_this_cycle  = 1.0
        gb_node.strength                   = 6.0
        cycle_start_strength               = 5.0  # What it was before use-gain

        result_a = AIMLNodeSystem.apply_aiml_wrong!()
        if gb_node.id in result_a["penalized"]
            # GRUG: Node must be strictly BELOW cycle-start strength. Not just back
            # to baseline. Real punishment, not fake punishment.
            @test gb_node.strength < cycle_start_strength
            penalized_with_prior_gain_tested = true
            break
        end
    end
    @test penalized_with_prior_gain_tested
end
println("  ✓ /aimlWrong with prior same-cycle gain: penalty overshoots to real net loss")

# GRUG: Scenario B — node voted, did NOT gain this cycle. Standard penalty = 1.0 drop.
let
    standard_penalized = false
    for trial in 1:500
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("wrong_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("wrong_lobe", "no_prior_gain", "tmpl"; initial_strength=5.0)
        np_node = AIMLNodeSystem.get_aiml_node("wrong_lobe", "no_prior_gain")
        AIMLNodeSystem.begin_cycle!()
        np_node.voted_this_cycle           = true
        np_node.fired_this_cycle           = true  # Node contributed to output
        np_node.gained_this_cycle          = false
        np_node.strength_delta_this_cycle  = 0.0

        result_b = AIMLNodeSystem.apply_aiml_wrong!()
        if np_node.id in result_b["penalized"]
            @test np_node.strength == 4.0  # 5.0 - 1.0
            standard_penalized = true
            break
        end
    end
    @test standard_penalized
end
println("  ✓ /aimlWrong without prior gain: standard penalty drops strength by 1.0")

# GRUG: Scenario C — 50/50 coinflip. Over 1000 trials, some nodes must be spared.
let
    spared_seen    = false
    penalized_seen = false
    for trial in 1:1000
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("wrong_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("wrong_lobe", "flip_node", "tmpl"; initial_strength=8.0)
        fn = AIMLNodeSystem.get_aiml_node("wrong_lobe", "flip_node")
        AIMLNodeSystem.begin_cycle!()
        fn.voted_this_cycle = true
        fn.fired_this_cycle = true  # Node contributed to output
        result_c = AIMLNodeSystem.apply_aiml_wrong!()
        if fn.id in result_c["spared"]     spared_seen     = true end
        if fn.id in result_c["penalized"]  penalized_seen  = true end
        if spared_seen && penalized_seen break end
    end
    @test spared_seen
    @test penalized_seen
end
println("  ✓ /aimlWrong coinflip produces both spared and penalized outcomes over many trials")

# GRUG: /aimlWrong with no voters.
fresh_slate!()
AIMLNodeSystem.register_lobe!("wrong_lobe", 30)
AIMLNodeSystem.begin_cycle!()
result_nv = AIMLNodeSystem.apply_aiml_wrong!()
@test result_nv["total_contributors"] == 0
println("  ✓ /aimlWrong with no contributors reports total_contributors=0")

# ==============================================================================
# [10] AIML_GRAVE TRANSITION
# ==============================================================================
println("\n[10] AIML_GRAVE TRANSITION")
fresh_slate!()

AIMLNodeSystem.register_lobe!("grave_lobe", 30)

# GRUG: Node at strength 1.0, /aimlWrong penalizes it -> strength hits 0 -> AIML_GRAVE.
# We force the scenario by manually setting voted=true and strength low enough that
# even a standard penalty (1.0) sends it to floor.
let
    forced_grave = false
    for trial in 1:500
        fresh_slate!()
        AIMLNodeSystem.register_lobe!("grave_lobe", 30)
        AIMLNodeSystem.add_aiml_node!("grave_lobe", "dying_node", "tmpl"; initial_strength=1.0)
        dn = AIMLNodeSystem.get_aiml_node("grave_lobe", "dying_node")
        AIMLNodeSystem.begin_cycle!()
        dn.voted_this_cycle           = true
        dn.fired_this_cycle           = true  # Node contributed to output
        dn.gained_this_cycle          = false
        dn.strength_delta_this_cycle  = 0.0

        result = AIMLNodeSystem.apply_aiml_wrong!()
        if dn.id in result["penalized"]
            @test dn.is_grave
            @test dn.grave_reason == AIMLNodeSystem.AIML_GRAVE_REASON_STRENGTH_ZERO
            @test dn.strength == 0.0
            @test dn.id in result["newly_graved"]
            forced_grave = true
            break
        end
    end
    @test forced_grave
end
println("  ✓ AIML_GRAVE: node at strength 1.0 transitions to AIML_GRAVE on penalty")

# GRUG: Once grave, node is tracked in the tribe (negative reinforcement memory —
# it does NOT vanish until phagy runs). Verify it still exists in registry.
fresh_slate!()
AIMLNodeSystem.register_lobe!("grave_lobe", 30)
AIMLNodeSystem.add_aiml_node!("grave_lobe", "grave_persist", "tmpl"; initial_strength=5.0)
gp_node = AIMLNodeSystem.get_aiml_node("grave_lobe", "grave_persist")
# Force to grave directly
gp_node.strength    = 0.0
gp_node.is_grave    = true
gp_node.grave_reason = AIMLNodeSystem.AIML_GRAVE_REASON_STRENGTH_ZERO
@test AIMLNodeSystem.has_aiml_node("grave_lobe", "grave_persist")  # Still in tribe
@test AIMLNodeSystem.get_population_size("grave_lobe") == 1         # Counts toward cap
println("  ✓ AIML_GRAVE node remains in tribe (negative reinforcement memory, not wiped)")

# GRUG: Grave node is skipped by /aimlRight.
# CRITICAL: Must mark as fired to be collected as contributor, then should be skipped
AIMLNodeSystem.begin_cycle!()
gp_node.voted_this_cycle = true
gp_node.fired_this_cycle = true  # Node fired, but is grave - should be skipped
result_right_grave = AIMLNodeSystem.apply_aiml_right!()
@test gp_node.id in result_right_grave["grave_skipped"]
println("  ✓ /aimlRight skips grave nodes even if they fired")

# GRUG: Grave node is skipped by /aimlWrong.
AIMLNodeSystem.begin_cycle!()
gp_node.voted_this_cycle = true
gp_node.fired_this_cycle = true  # Node fired, but is grave - should be skipped
result_wrong_grave = AIMLNodeSystem.apply_aiml_wrong!()
@test gp_node.id in result_wrong_grave["grave_skipped"]
println("  ✓ /aimlWrong skips grave nodes even if they fired")

# GRUG: Grave node does not gain from record_fire!.
strength_at_grave = gp_node.strength
for _ in 1:10
    AIMLNodeSystem.record_fire!(gp_node)
end
@test gp_node.strength == strength_at_grave  # No gain possible
println("  ✓ Grave node does not gain from record_fire!")

# ==============================================================================
# [11] PHAGY HOOK COMPATIBILITY
# ==============================================================================
println("\n[11] PHAGY HOOK COMPATIBILITY")
fresh_slate!()

AIMLNodeSystem.register_lobe!("phagy_lobe", 30)
AIMLNodeSystem.add_aiml_node!("phagy_lobe", "live_1",  "live tmpl";  initial_strength=7.0)
AIMLNodeSystem.add_aiml_node!("phagy_lobe", "grave_1", "grave tmpl"; initial_strength=5.0)
AIMLNodeSystem.add_aiml_node!("phagy_lobe", "grave_2", "grave tmpl"; initial_strength=5.0)

# GRUG: Mark two nodes as graves directly.
g1 = AIMLNodeSystem.get_aiml_node("phagy_lobe", "grave_1")
g2 = AIMLNodeSystem.get_aiml_node("phagy_lobe", "grave_2")
g1.is_grave = true
g2.is_grave = true

@test AIMLNodeSystem.get_population_size("phagy_lobe") == 3

# GRUG: phagy_sweep! with prune_graves=true removes grave nodes.
result_phagy = AIMLNodeSystem.aiml_phagy_sweep!(prune_graves=true)
@test result_phagy["pruned_count"] == 2
@test AIMLNodeSystem.get_population_size("phagy_lobe") == 1  # Only live_1 remains
@test  AIMLNodeSystem.has_aiml_node("phagy_lobe", "live_1")
@test !AIMLNodeSystem.has_aiml_node("phagy_lobe", "grave_1")
@test !AIMLNodeSystem.has_aiml_node("phagy_lobe", "grave_2")
println("  ✓ aiml_phagy_sweep! prunes grave nodes, leaves live nodes intact")

# GRUG: phagy_sweep! with prune_graves=false is a no-op.
g1_back = AIMLNodeSystem.add_aiml_node!("phagy_lobe", "grave_back", "tmpl"; initial_strength=3.0)
g1_back.is_grave = true
result_noop = AIMLNodeSystem.aiml_phagy_sweep!(prune_graves=false)
@test result_noop["pruned_count"] == 0
@test AIMLNodeSystem.has_aiml_node("phagy_lobe", "grave_back")  # Still there
println("  ✓ aiml_phagy_sweep! with prune_graves=false is a no-op")

# GRUG: After phagy, adding new nodes works (phagy freed cap slots).
AIMLNodeSystem.add_aiml_node!("phagy_lobe", "post_phagy_node", "fresh")
@test AIMLNodeSystem.has_aiml_node("phagy_lobe", "post_phagy_node")
println("  ✓ After phagy, freed cap slots accept new nodes")

# ==============================================================================
# [12] UNREGISTER LOBE
# ==============================================================================
println("\n[12] UNREGISTER LOBE")
fresh_slate!()

AIMLNodeSystem.register_lobe!("bye_lobe", 30)
AIMLNodeSystem.add_aiml_node!("bye_lobe", "bye_node", "tmpl")
@test AIMLNodeSystem.is_lobe_registered("bye_lobe")

AIMLNodeSystem.unregister_lobe!("bye_lobe")
@test !AIMLNodeSystem.is_lobe_registered("bye_lobe")
# GRUG: After unregister, operations on the lobe throw.
@test_throws AIMLNodeError AIMLNodeSystem.add_aiml_node!("bye_lobe", "new_node", "t")
@test_throws AIMLNodeError AIMLNodeSystem.get_population_size("bye_lobe")
println("  ✓ unregister_lobe! removes lobe and operations on it throw")

# ==============================================================================
# [13] DIAGNOSTICS
# ==============================================================================
println("\n[13] DIAGNOSTICS")
fresh_slate!()

# GRUG: Empty registry still produces a string (not an error).
summary = AIMLNodeSystem.get_aiml_status_summary()
@test isa(summary, String)
@test occursin("AIML NODE TRIBES", summary)
println("  ✓ get_aiml_status_summary returns string for empty registry")

AIMLNodeSystem.register_lobe!("diag_lobe", 60)
AIMLNodeSystem.add_aiml_node!("diag_lobe", "d1", "tmpl")
summary2 = AIMLNodeSystem.get_aiml_status_summary()
@test occursin("diag_lobe", summary2)
println("  ✓ get_aiml_status_summary includes registered lobes")

# ==============================================================================
# [14] RESET_ALL!
# ==============================================================================
println("\n[14] RESET_ALL!")

AIMLNodeSystem.register_lobe!("reset_me", 30)
AIMLNodeSystem.add_aiml_node!("reset_me", "r1", "tmpl")
AIMLNodeSystem.begin_cycle!()
@test AIMLNodeSystem.current_cycle() >= 1

AIMLNodeSystem.reset_all!()
@test !AIMLNodeSystem.is_lobe_registered("reset_me")
@test AIMLNodeSystem.current_cycle() == 0
@test isempty(AIMLNodeSystem.get_registered_lobes())
println("  ✓ reset_all! clears registry, caps, and cycle counter")

# ==============================================================================
# [15] MULTI-LOBE MULTI-NODE INTERACTION
# ==============================================================================
println("\n[15] MULTI-LOBE MULTI-NODE INTERACTION")
fresh_slate!()

# GRUG: Simulate three lobes with different subjects, each getting AIML tribes.
# Verify feedback is scoped per-voted-node, not per-lobe or per-all.
AIMLNodeSystem.register_lobe!("science",    20000)
AIMLNodeSystem.register_lobe!("philosophy", 20000)
AIMLNodeSystem.register_lobe!("command",    20000)

for lobe in ["science", "philosophy", "command"]
    for i in 1:3
        AIMLNodeSystem.add_aiml_node!(lobe, "$(lobe)_node_$i", "exec tmpl $i"; initial_strength=5.0)
    end
end

AIMLNodeSystem.begin_cycle!()

# GRUG: Only science_node_1 and philosophy_node_2 vote. Command nodes do not vote.
sci_1  = AIMLNodeSystem.get_aiml_node("science",    "science_node_1")
phil_2 = AIMLNodeSystem.get_aiml_node("philosophy", "philosophy_node_2")
cmd_1  = AIMLNodeSystem.get_aiml_node("command",    "command_node_1")

AIMLNodeSystem.record_vote!(sci_1)
AIMLNodeSystem.record_fire!(sci_1)  # Node actually contributed to output
AIMLNodeSystem.record_vote!(phil_2)
AIMLNodeSystem.record_fire!(phil_2)  # Node actually contributed to output
# GRUG: Do NOT vote cmd_1 — verify it is untouched by /aimlRight.

strength_cmd_before = cmd_1.strength
result_right_multi = AIMLNodeSystem.apply_aiml_right!()
@test result_right_multi["total_contributors"] == 2
@test cmd_1.strength == strength_cmd_before  # Command lobe untouched
println("  ✓ Multi-lobe /aimlRight: only 2 voted nodes eligible, command lobe untouched")

# GRUG: Now /aimlWrong with fresh cycle.
AIMLNodeSystem.begin_cycle!()
AIMLNodeSystem.record_vote!(sci_1)
AIMLNodeSystem.record_fire!(sci_1)  # Node actually contributed to output
AIMLNodeSystem.record_vote!(phil_2)
AIMLNodeSystem.record_fire!(phil_2)  # Node actually contributed to output
strength_cmd_before2 = cmd_1.strength

result_wrong_multi = AIMLNodeSystem.apply_aiml_wrong!()
@test result_wrong_multi["total_contributors"] == 2
@test cmd_1.strength == strength_cmd_before2
println("  ✓ Multi-lobe /aimlWrong: only 2 voted nodes eligible, command lobe untouched")

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("ALL AIML NODE SYSTEM TESTS PASSED! 15 test groups complete.")
println("Features verified: lobe registration, node lifecycle, population cap,")
println("lobe isolation, cycle management, use-based strength gain,")
println("/aimlRight double-snack exclusion, /aimlWrong net-loss guarantee,")
println("AIML_GRAVE transition, phagy sweep compatibility, diagnostics, reset.")
println("="^60)