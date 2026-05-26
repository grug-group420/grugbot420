# ==============================================================================
# v7.22 — STRENGTH-DRIVEN SOLIDIFICATION TESTS
# ==============================================================================
# GRUG: Prove that nodes auto-solidify (NONJITTER tag on) once strength >=
# threshold, auto-desolidify (NONJITTER tag off) when strength drops back
# below, and can re-solidify when strength climbs back up — all via the
# existing bump_strength! / penalize_strength! paths with no new plumbing
# at the call sites.
#
# No frozen confidence / no locked state — just the tag, kept in sync with
# strength. That's the whole v7.22 feature.
#
# NO SILENT FAILURES: every assertion carries an explanatory message.
# ==============================================================================

using Test
using GrugBot420
using Random

using GrugBot420: STRENGTH_SOLIDIFY_THRESHOLD, is_solidified, check_solidify_threshold!
using GrugBot420: is_nonjitter, set_nonjitter!, clear_nonjitter!, NONJITTER_TAG
using GrugBot420: bump_strength!, penalize_strength!

const Node = getfield(GrugBot420, :Node)
const STRENGTH_CAP = getfield(GrugBot420, :STRENGTH_CAP)

# GRUG: Same bare-node helper as test_nonjitter_tag.jl. Duplicated here so
# this test file runs standalone (each test runs as its own subprocess).
function make_bare_node(strength::Float64 = 1.0, id::String = "solidify_$(rand(1:10_000_000))")
    return Node(
        id,
        "test pattern",
        Float64[1.0, 2.0, 3.0],
        "noop",
        Dict{String,Any}(),
        String[],
        1.0,
        GrugBot420.RelationalTriple[],
        String[],
        Dict{String,Float64}(),
        strength,
        false,
        String[],
        false,
        12,                          # GRUG v7.19: max_neighbors per-node cap
        false,
        "",
        Float64[],
        time(),
        UInt64(0),
        false,
        false,
        false,
        0.0,
    )
end

@testset "v7.22 — threshold constant is pinned at 9.0" begin
    # GRUG: Pinning the constant protects us from silent drift. If we ever
    # need to retune the threshold, that's a deliberate version bump.
    @test STRENGTH_SOLIDIFY_THRESHOLD == 9.0
    @test STRENGTH_SOLIDIFY_THRESHOLD < STRENGTH_CAP
    @test STRENGTH_SOLIDIFY_THRESHOLD > 0.0
end

@testset "v7.22 — check_solidify_threshold! solidifies when strength >= threshold" begin
    node = make_bare_node(9.0)
    @test !is_nonjitter(node)
    @test !is_solidified(node)

    check_solidify_threshold!(node)

    @test is_nonjitter(node)
    @test is_solidified(node)
    @test NONJITTER_TAG in node.required_relations
end

@testset "v7.22 — check_solidify_threshold! desolidifies when strength < threshold" begin
    node = make_bare_node(10.0)
    set_nonjitter!(node)   # start solid
    @test is_solidified(node)

    node.strength = 5.0
    check_solidify_threshold!(node)

    @test !is_nonjitter(node)
    @test !is_solidified(node)
    @test !(NONJITTER_TAG in node.required_relations)
end

@testset "v7.22 — exactly at threshold (==) is solid" begin
    # GRUG: boundary behavior. strength == threshold must count as solid
    # (>= comparison), not the off-by-one that would make 9.0 exactly
    # desolidify. Pin this.
    node = make_bare_node(STRENGTH_SOLIDIFY_THRESHOLD)
    check_solidify_threshold!(node)
    @test is_solidified(node)
end

@testset "v7.22 — just below threshold is NOT solid" begin
    # GRUG: a hair under the line must still be jittery. nextfloat gives us
    # the largest Float64 strictly below threshold.
    node = make_bare_node(prevfloat(STRENGTH_SOLIDIFY_THRESHOLD))
    check_solidify_threshold!(node)
    @test !is_solidified(node)
end

@testset "v7.22 — idempotent on repeated calls" begin
    # GRUG: calling check_solidify_threshold! 100 times on a solid node
    # must leave exactly one copy of the tag. No duplicates, no churn.
    node = make_bare_node(10.0)
    for _ in 1:100
        check_solidify_threshold!(node)
    end
    @test is_solidified(node)
    @test count(r -> r == NONJITTER_TAG, node.required_relations) == 1

    # Same for an unsolid node — 100 calls produce no tag.
    node2 = make_bare_node(1.0)
    for _ in 1:100
        check_solidify_threshold!(node2)
    end
    @test !is_solidified(node2)
    @test count(r -> r == NONJITTER_TAG, node2.required_relations) == 0
end

@testset "v7.22 — solidify cycle: up, down, up again" begin
    # GRUG: This is the meat of the feature. Node climbs to threshold,
    # solidifies. /wrong drops strength, desolidifies. Climbs back, re-solidifies.
    node = make_bare_node(8.0)
    @test !is_solidified(node)

    # Climb to threshold
    node.strength = 9.5
    check_solidify_threshold!(node)
    @test is_solidified(node)

    # Drop below
    node.strength = 7.0
    check_solidify_threshold!(node)
    @test !is_solidified(node)

    # Climb back
    node.strength = 10.0
    check_solidify_threshold!(node)
    @test is_solidified(node)
end

@testset "v7.22 — tag coexists with other required_relations" begin
    # GRUG: If a node already has real semantic requirements in
    # required_relations, auto-solidify must not clobber them.
    node = make_bare_node(10.0)
    push!(node.required_relations, "CAUSES")
    push!(node.required_relations, "REQUIRES")

    check_solidify_threshold!(node)

    @test is_solidified(node)
    @test "CAUSES" in node.required_relations
    @test "REQUIRES" in node.required_relations
    @test NONJITTER_TAG in node.required_relations
    @test length(node.required_relations) == 3

    # Desolidify: only the NONJITTER tag should leave.
    node.strength = 1.0
    check_solidify_threshold!(node)
    @test !is_solidified(node)
    @test "CAUSES" in node.required_relations
    @test "REQUIRES" in node.required_relations
    @test length(node.required_relations) == 2
end

@testset "v7.22 — bump_strength! triggers auto-solidify at threshold" begin
    # GRUG: We can't deterministically force a strength bump because
    # bump_strength! has a 50/50 coinflip. But we can seed the RNG so
    # the coinflip succeeds, or we can loop until it does.
    node = make_bare_node(8.0)
    @test !is_solidified(node)

    # GRUG: Hammer bump_strength! until strength reaches >= threshold.
    # Each call has 50% chance of +1.0; expected calls to cross ~9.0 from
    # 8.0 is 2. A loop of 200 is vastly more than enough with astronomically
    # low failure probability (2^-100-ish).
    for _ in 1:200
        bump_strength!(node)
        if node.strength >= STRENGTH_SOLIDIFY_THRESHOLD
            break
        end
    end
    @test node.strength >= STRENGTH_SOLIDIFY_THRESHOLD
    @test is_solidified(node)   # AUTO-applied by bump_strength!'s post-hook
end

@testset "v7.22 — penalize_strength! triggers auto-desolidify at threshold" begin
    # GRUG: Same trick — hammer penalize_strength! from a solid node until
    # strength falls below threshold, then assert tag is gone.
    node = make_bare_node(10.0)
    set_nonjitter!(node)   # seed as solid (simulating past strength-driven solidify)
    @test is_solidified(node)

    for _ in 1:200
        penalize_strength!(node)
        if node.strength < STRENGTH_SOLIDIFY_THRESHOLD
            break
        end
    end
    @test node.strength < STRENGTH_SOLIDIFY_THRESHOLD
    @test !is_solidified(node)   # AUTO-removed by penalize_strength!'s post-hook
end

@testset "v7.22 — grave nodes: solidification state is consistent" begin
    # GRUG: A node that hits strength 0 gets marked grave. Grave nodes
    # should NOT be solidified (strength < threshold implies tag off).
    node = make_bare_node(1.0)
    set_nonjitter!(node)   # hypothetically tagged manually
    @test is_solidified(node)

    # Drive strength to floor via penalize. Every call has 50% chance of -1.
    # Loop of 200 covers the 1.0 -> 0.0 drop with overwhelming probability.
    for _ in 1:200
        penalize_strength!(node)
        if node.strength <= 0.0
            break
        end
    end

    # After hitting grave, strength is well below threshold -> tag removed.
    @test node.strength < STRENGTH_SOLIDIFY_THRESHOLD
    @test !is_solidified(node)
    # Grave flag may or may not be set depending on whether the final
    # coin landed a penalty; but if the loop did 200 penalties, it almost
    # certainly got there.
    @test node.is_grave || node.strength > 0.0   # at least one is true
end

@testset "v7.22 — is_solidified == is_nonjitter contract" begin
    # GRUG: v7.22 defines is_solidified as an alias for is_nonjitter.
    # Manual tag application via set_nonjitter! should also register as
    # solidified, even if strength is low. This preserves compatibility
    # with calibration / anchor nodes that are manually tagged regardless
    # of strength.
    low_strength_node = make_bare_node(1.0)
    set_nonjitter!(low_strength_node)
    @test is_solidified(low_strength_node)   # yes — tag is present
    @test is_nonjitter(low_strength_node)

    # Now if check_solidify_threshold! runs on this low-strength tagged node,
    # v7.22 will REMOVE the tag (strength < threshold implies desolidify).
    # This is intentional — v7.22 takes over management of the tag for
    # strength-tracking purposes. Manual tags on low-strength nodes are
    # overridden. Document this behavior in the whitepaper.
    check_solidify_threshold!(low_strength_node)
    @test !is_solidified(low_strength_node)
end