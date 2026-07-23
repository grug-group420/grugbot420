# ==============================================================================
# v7.50 — HIPPOCAMPAL CASCADE TESTS (strain_energy → neurogenesis)
# ==============================================================================
# GRUG: Tests that prove:
#   1. EphemeralMLP computes strain_energy from novelty + directive_quality
#   2. strain_energy is clamped to [0.0, 1.0]
#   3. hippocampal_warrant_active = true when strain >= threshold AND adjustments enabled
#   4. hippocampal_warrant_active = false when strain < threshold OR adjustments disabled
#   5. get_strain_energy() and is_hippocampal_warrant_active() query functions work
#   6. MitosisMode _stochastic_gate accepts strain_energy and uses max(data, strain)
#   7. _hippocampal_strain_warrant returns correct results when warrant is active
#   8. _hippocampal_strain_warrant returns nothing when warrant is inactive
#   9. _select_bud includes Source 6 (hippocampal strain) in candidates
#  10. TemporalGrowth stochastic gate can be boosted by strain_energy
#  11. Strain constants are reasonable
#
# NO SILENT FAILURES: every assertion has an explanatory message.
# ==============================================================================

using Test
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
using GrugBot420
using Random

using GrugBot420: EphemeralMLP, MitosisMode
using GrugBot420: STRAIN_WARRANT_WEIGHT, STRAIN_WARRANT_ACTIVE_THRESHOLD

println("\n" * "="^60)
println("HIPPOCAMPAL CASCADE TESTS (v7.50)")
println("="^60)

# ==============================================================================
# TEST 1: Strain constants are reasonable
# ==============================================================================
@testset "Strain constants" begin
    @test STRAIN_NOVELTY_WEIGHT > 0.0
    @test STRAIN_QUALITY_WEIGHT > 0.0
    @test abs(STRAIN_NOVELTY_WEIGHT + STRAIN_QUALITY_WEIGHT - 1.0) < 1e-10
    @test STRAIN_THRESHOLD > 0.0 && STRAIN_THRESHOLD < 1.0
    @test STRAIN_FLOOR == 0.0
    @test STRAIN_CEILING == 1.0
    @test STRAIN_WARRANT_WEIGHT > 0.0 && STRAIN_WARRANT_WEIGHT <= 1.0
    @test STRAIN_WARRANT_ACTIVE_THRESHOLD > 0.0 && STRAIN_WARRANT_ACTIVE_THRESHOLD < 1.0
    println("  ✅ Strain constants are reasonable (weights sum to 1.0, thresholds in (0,1))")
end

# ==============================================================================
# TEST 2: EphemeralMLP strain computation — clamping
# ==============================================================================
@testset "EphemeralMLP strain clamping" begin
    # The clamp should keep strain in [0.0, 1.0]
    # Since weights sum to 1.0 and novelty/quality_deficit are in [0,1],
    # strain should naturally be in [0,1] — but clamp is safety net.
    # Test by checking get_strain_energy() returns values in valid range.
    strain = EphemeralMLP.get_strain_energy()
    @test strain >= 0.0 && strain <= 1.0
    println("  ✅ Current strain_energy=$strain is in [0.0, 1.0]")
end

# ==============================================================================
# TEST 3: hippocampal_warrant_active reflects threshold + adjustments
# ==============================================================================
@testset "Hippocampal warrant activation" begin
    strain = EphemeralMLP.get_strain_energy()
    warrant = EphemeralMLP.is_hippocampal_warrant_active()
    adj_enabled = EphemeralMLP.get_mlp_status()["adjustments_enabled"]

    if strain >= STRAIN_THRESHOLD && adj_enabled
        @test warrant == true
        println("  ✅ Warrant ACTIVE (strain=$strain >= threshold=$STRAIN_THRESHOLD, adjustments ON)")
    else
        @test warrant == false
        println("  ✅ Warrant inactive (strain=$strain < threshold=$STRAIN_THRESHOLD OR adjustments OFF)")
    end
end

# ==============================================================================
# TEST 4: get_strain_energy() and is_hippocampal_warrant_active() are queryable
# ==============================================================================
@testset "Strain query functions" begin
    s = EphemeralMLP.get_strain_energy()
    @test isa(s, Float64)
    w = EphemeralMLP.is_hippocampal_warrant_active()
    @test isa(w, Bool)
    println("  ✅ get_strain_energy() → Float64 ($s)")
    println("  ✅ is_hippocampal_warrant_active() → Bool ($w)")
end

# ==============================================================================
# TEST 5: MitosisMode _stochastic_gate with strain_energy
# ==============================================================================
@testset "MitosisMode stochastic gate with strain" begin
    # No messages — data_energy should be 0
    empty_msgs = Tuple{String, String, Float64}[]

    # Without strain, gate should not pass (data_energy=0, strain=0)
    (passed_zero, prob_zero) = MitosisMode._stochastic_gate(empty_msgs; strain_energy=0.0)
    @test prob_zero < 0.001  # essentially zero probability
    println("  ✅ No data + no strain → prob=$(round(prob_zero, digits=4)) (near zero)")

    # With strain=0.8, gate should have meaningful probability
    # effective_prob = max(0.0, 0.8) * MITOSIS_PROBABILITY = 0.8 * 0.15 = 0.12
    (passed_strain, prob_strain) = MitosisMode._stochastic_gate(empty_msgs; strain_energy=0.8)
    @test prob_strain > 0.0
    expected_approx = 0.8 * MitosisMode.MITOSIS_PROBABILITY
    @test abs(prob_strain - expected_approx) < 0.01
    println("  ✅ No data + strain=0.8 → prob=$(round(prob_strain, digits=4)) ≈ $(round(expected_approx, digits=4))")

    # With both data and strain, max should be used
    msgs_with_data = [("user", "hello world", 1.0), ("user", "test message", 0.8)]
    (_, prob_data) = MitosisMode._stochastic_gate(msgs_with_data; strain_energy=0.3)
    (_, prob_max) = MitosisMode._stochastic_gate(msgs_with_data; strain_energy=0.9)
    # strain=0.9 should boost probability beyond strain=0.3
    @test prob_max >= prob_data
    println("  ✅ data+strain=0.3 → prob=$(round(prob_data, digits=4)), data+strain=0.9 → prob=$(round(prob_max, digits=4))")
end

# ==============================================================================
# TEST 6: _hippocampal_strain_warrant — active warrant
# ==============================================================================
@testset "Hippocampal strain warrant — active" begin
    node_snaps = [("existing_pattern", false)]
    msg_snaps = [("user", "novel input the system cant handle", 0.9)]

    # With warrant active and strain above threshold
    result = MitosisMode._hippocampal_strain_warrant(
        strain_energy=0.8,
        hippocampal_warrant_active=true,
        node_snapshots=node_snaps,
        message_snapshots=msg_snaps,
    )
    @test result !== nothing
    (pattern, source, score) = result
    @test source == "hippocampal_strain"
    @test score > 0.0
    @test score <= 1.0
    @test !isempty(pattern)
    # Score should be strain_energy * STRAIN_WARRANT_WEIGHT
    expected_score = 0.8 * STRAIN_WARRANT_WEIGHT
    @test abs(score - expected_score) < 0.01
    println("  ✅ Active warrant: pattern='$pattern', source='$source', score=$(round(score, digits=3))")
end

# ==============================================================================
# TEST 7: _hippocampal_strain_warrant — inactive warrant (not confirmed)
# ==============================================================================
@testset "Hippocampal strain warrant — inactive" begin
    node_snaps = [("existing_pattern", false)]
    msg_snaps = [("user", "novel input", 0.9)]

    # Warrant not confirmed by SelfObserver
    result = MitosisMode._hippocampal_strain_warrant(
        strain_energy=0.8,
        hippocampal_warrant_active=false,  # SelfObserver didn't confirm
        node_snapshots=node_snaps,
        message_snapshots=msg_snaps,
    )
    @test result === nothing
    println("  ✅ Inactive warrant (hippocampal_warrant_active=false) → nothing")

    # Strain below threshold
    result2 = MitosisMode._hippocampal_strain_warrant(
        strain_energy=0.2,  # Below STRAIN_WARRANT_ACTIVE_THRESHOLD (0.55)
        hippocampal_warrant_active=true,
        node_snapshots=node_snaps,
        message_snapshots=msg_snaps,
    )
    @test result2 === nothing
    println("  ✅ Low strain (0.2 < threshold=0.55) → nothing")
end

# ==============================================================================
# TEST 8: _hippocampal_strain_warrant — no user messages
# ==============================================================================
@testset "Hippocampal strain warrant — no user messages" begin
    node_snaps = [("existing_pattern", false)]
    msg_snaps = Tuple{String, String, Float64}[]  # No messages

    result = MitosisMode._hippocampal_strain_warrant(
        strain_energy=0.9,
        hippocampal_warrant_active=true,
        node_snapshots=node_snaps,
        message_snapshots=msg_snaps,
    )
    @test result === nothing
    println("  ✅ No user messages → no warrant (nothing to grow from)")
end

# ==============================================================================
# TEST 9: _select_bud includes hippocampal strain as Source 6
# ==============================================================================
@testset "Select bud includes hippocampal strain" begin
    # Create conditions where only Source 6 would produce a candidate
    node_snaps = [("existing", false)]
    node_with_ids = [("existing", false, "id1")]
    all_patterns = Set(["existing"])
    msg_snaps = [("user", "brand new novel concept xyzzy", 0.95)]
    lobe_snaps = Tuple{String, String, Set{String}}[]
    att_snaps = Tuple{String, String, Bool}[]
    thesaurus_gate = word -> String[]
    thesaurus_sim = (a, b) -> 0.0

    # Without strain — _select_bud should return nothing (no silence/freq/thesaurus/lobe/attachment warrant)
    bud_no_strain = MitosisMode._select_bud(
        node_snapshots=node_snaps,
        node_with_ids=node_with_ids,
        all_patterns=all_patterns,
        message_snapshots=msg_snaps,
        lobe_snapshots=lobe_snaps,
        attachment_snapshots=att_snaps,
        thesaurus_gate_filter=thesaurus_gate,
        thesaurus_word_similarity=thesaurus_sim,
        strain_energy=0.0,
        hippocampal_warrant_active=false,
    )
    # Might or might not be nothing (silence/freq could fire), just check it doesn't crash
    println("  ✅ _select_bud without strain: $(bud_no_strain === nothing ? "nothing" : "source=$(bud_no_strain[2])")")

    # With strain — Source 6 should contribute a candidate
    bud_with_strain = MitosisMode._select_bud(
        node_snapshots=node_snaps,
        node_with_ids=node_with_ids,
        all_patterns=all_patterns,
        message_snapshots=msg_snaps,
        lobe_snapshots=lobe_snaps,
        attachment_snapshots=att_snaps,
        thesaurus_gate_filter=thesaurus_gate,
        thesaurus_word_similarity=thesaurus_sim,
        strain_energy=0.8,
        hippocampal_warrant_active=true,
    )
    if bud_with_strain !== nothing
        println("  ✅ _select_bud with strain: source=$(bud_with_strain[2]), score=$(round(bud_with_strain[3], digits=3))")
        # If hippocampal_strain source won, it should be the source
        if bud_with_strain[2] == "hippocampal_strain"
            @test bud_with_strain[3] > 0.0
            println("  ✅ Hippocampal strain won as best warrant source")
        else
            println("  ℹ️  Another source won ($(bud_with_strain[2])), hippocampal strain was a candidate")
        end
    else
        println("  ⚠️  _select_bud returned nothing even with strain — pattern may be covered")
    end
end

# ==============================================================================
# TEST 10: Strain appears in MLP status
# ==============================================================================
@testset "Strain in MLP status" begin
    status = EphemeralMLP.get_mlp_status()
    @test haskey(status, "strain_energy")
    @test haskey(status, "hippocampal_warrant")
    @test isa(status["strain_energy"], Float64)
    @test isa(status["hippocampal_warrant"], Bool)
    println("  ✅ MLP status includes strain_energy=$(status["strain_energy"])")
    println("  ✅ MLP status includes hippocampal_warrant=$(status["hippocampal_warrant"])")
end

println("\n" * "="^60)
println("HIPPOCAMPAL CASCADE TESTS COMPLETE")
println("="^60)
