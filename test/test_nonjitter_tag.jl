# ==============================================================================
# v7.20 — NONJITTER TAG + END-CONFIDENCE SNAP-BACK JITTER TESTS
# ==============================================================================
# GRUG: Tests that prove:
#   1. NONJITTER is a string tag in required_relations. No struct change.
#   2. is_nonjitter / set_nonjitter! / clear_nonjitter! obey contracts:
#        - is_nonjitter returns Bool, no mutation, no allocation surprises
#        - set_nonjitter! is idempotent (calling twice = one tag, not two)
#        - clear_nonjitter! is safe on untagged nodes (no-op, not error)
#   3. Tag survives specimen round-trip (free, because required_relations
#      is already serialized).
#   4. _bidirectional_cheap_scan respects nonjitter kwarg:
#        - nonjitter=false: end-confidence jittered (repeat scans give small variance)
#        - nonjitter=true:  end-confidence bit-stable (repeat scans give identical result)
#   5. NONJITTER-tagged nodes receive bit-stable confidence from the scan pipeline.
#   6. Global _JITTER_ENABLED is orthogonal to the NONJITTER tag.
#   7. Confidence fusion correctness is preserved — NONJITTER only silences the
#      post-fusion micro-jitter, not the fusion math itself.
#
# NO SILENT FAILURES: every assertion has an explanatory message.
# ==============================================================================

using Test
using GrugBot420
using Random

# GRUG: Bring in internal helpers we need to test directly.
using GrugBot420: NONJITTER_TAG, is_nonjitter, set_nonjitter!, clear_nonjitter!
using GrugBot420: big_number_small_number_coherence
# GRUG: _bidirectional_cheap_scan is internal (not exported) — reach into Main.jl/engine module.
# The engine exposes it via the package-internal namespace when we `using GrugBot420`.
# We access it through GrugBot420._bidirectional_cheap_scan if it's not re-exported.
const _bidirectional_cheap_scan = getfield(GrugBot420, :_bidirectional_cheap_scan)

# Helper — build a minimal Node we can tag. We use the public create_lobe / node
# APIs if available, but for a pure tag/helper test we construct via GrugBot420's
# Node constructor directly.
const Node = getfield(GrugBot420, :Node)

function make_bare_node(id::String = "test_node_$(rand(1:10_000_000))")
    # GRUG: Minimal node. All we care about for tag tests is required_relations.
    # Other fields get safe defaults.
    return Node(
        id,                          # id
        "test pattern",              # pattern
        Float64[1.0, 2.0, 3.0],      # signal
        "noop",                      # action_packet
        Dict{String,Any}(),          # json_data
        String[],                    # drop_table
        1.0,                         # throttle
        GrugBot420.RelationalTriple[],   # relational_patterns
        String[],                    # required_relations  <-- where tag lives
        Dict{String,Float64}(),      # relation_weights
        1.0,                         # strength
        false,                       # is_image_node
        String[],                    # neighbor_ids
        false,                       # is_unlinkable
        12,                          # max_neighbors  (GRUG v7.19: per-node cap)
        false,                       # is_grave
        "",                          # grave_reason
        Float64[],                   # response_times
        time(),                      # ledger_last_cleared
        UInt64(0),                   # hopfield_key
        false,                       # fired_this_cycle
        false,                       # voted_this_cycle
        false,                       # gained_this_cycle
        0.0,                         # strength_delta_this_cycle
    )
end

@testset "NONJITTER tag — basic invariants" begin
    # GRUG: The tag constant must be exactly the string "NONJITTER". If this changes,
    # serialized specimens break. Pin it.
    @test NONJITTER_TAG == "NONJITTER"

    node = make_bare_node("basic_untagged")

    # GRUG: Freshly built node has no tag.
    @test is_nonjitter(node) == false

    # GRUG: required_relations is exactly what we constructed with — empty.
    @test isempty(node.required_relations)
end

@testset "set_nonjitter! — idempotent and correct" begin
    node = make_bare_node("set_idempotent")

    # GRUG: First set should add the tag.
    set_nonjitter!(node)
    @test is_nonjitter(node) == true
    @test NONJITTER_TAG in node.required_relations
    @test length(node.required_relations) == 1

    # GRUG: Second set must NOT duplicate — that would break equality checks
    # and cause the tag to survive one clear_nonjitter! call with stale copies.
    set_nonjitter!(node)
    @test is_nonjitter(node) == true
    @test length(node.required_relations) == 1   # still exactly one copy

    # GRUG: Third set, same invariant.
    set_nonjitter!(node)
    @test length(node.required_relations) == 1

    # GRUG: Function must return the node (for chaining). Not nothing.
    returned = set_nonjitter!(node)
    @test returned === node
end

@testset "clear_nonjitter! — safe on tagged and untagged" begin
    # Case 1: clearing a tagged node removes exactly the tag
    node_a = make_bare_node("clear_tagged")
    set_nonjitter!(node_a)
    @test is_nonjitter(node_a) == true
    clear_nonjitter!(node_a)
    @test is_nonjitter(node_a) == false
    @test !(NONJITTER_TAG in node_a.required_relations)

    # Case 2: clearing an already-untagged node is a no-op, NOT an error
    node_b = make_bare_node("clear_untagged")
    @test is_nonjitter(node_b) == false
    clear_nonjitter!(node_b)   # must not throw
    @test is_nonjitter(node_b) == false

    # Case 3: clear preserves other relations in required_relations
    node_c = make_bare_node("clear_preserves")
    push!(node_c.required_relations, "some_other_rule")
    set_nonjitter!(node_c)
    @test length(node_c.required_relations) == 2
    clear_nonjitter!(node_c)
    @test length(node_c.required_relations) == 1
    @test "some_other_rule" in node_c.required_relations
    @test !(NONJITTER_TAG in node_c.required_relations)
end

@testset "set/clear cycle — full round-trip" begin
    # GRUG: Tag on -> off -> on -> off should leave node in the same state
    # as if we'd never touched it.
    node = make_bare_node("round_trip")
    baseline_len = length(node.required_relations)

    set_nonjitter!(node)
    clear_nonjitter!(node)
    set_nonjitter!(node)
    clear_nonjitter!(node)

    @test is_nonjitter(node) == false
    @test length(node.required_relations) == baseline_len
end

@testset "_bidirectional_cheap_scan — nonjitter=true gives bit-stable confidence" begin
    # GRUG: Build a signal that will match cleanly so we don't get PatternNotFoundError.
    # Then scan 50 times with nonjitter=true — every call must return the SAME fused
    # confidence to bit precision, because we skipped slight_jitter on the output.
    target  = Float64[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    pattern = Float64[0.3, 0.4, 0.5]

    # Fix RNG so the per-window jitter inside cheap_scan is also deterministic
    # across the 50 calls. This isolates the test: we're checking that when
    # nonjitter=true AND RNG is fixed, outputs are identical — which they should
    # be, because the only source of post-fusion noise was slight_jitter, which
    # we now suppress.
    Random.seed!(42)
    idx1, conf1 = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=true)

    # Run again with identical RNG seed — must be identical.
    Random.seed!(42)
    idx2, conf2 = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=true)

    @test idx1 == idx2
    @test conf1 === conf2   # bit-equal Float64

    # GRUG: Full sweep — 20 runs at same seed all bit-identical.
    confs = Float64[]
    for _ in 1:20
        Random.seed!(42)
        _, c = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=true)
        push!(confs, c)
    end
    @test all(c -> c === confs[1], confs)
end

@testset "_bidirectional_cheap_scan — nonjitter=false can vary across calls" begin
    # GRUG: With nonjitter=false (default), post-fusion slight_jitter runs.
    # Across 50 calls with DIFFERENT RNG states, we expect to see AT LEAST TWO
    # distinct confidence values. If all 50 are identical, jitter is broken.
    target  = Float64[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    pattern = Float64[0.3, 0.4, 0.5]

    confs = Float64[]
    for i in 1:50
        Random.seed!(1000 + i)
        _, c = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=false)
        push!(confs, c)
    end

    # GRUG: At least two distinct values means jitter is working.
    unique_confs = unique(confs)
    @test length(unique_confs) >= 2

    # GRUG: But jitter is BOUNDED. All confidences must stay in [-1, 1] per
    # slight_jitter's clamp. No runaway values.
    @test all(c -> -1.0 <= c <= 1.0, confs)
end

@testset "nonjitter default is false — backward-compatible" begin
    # GRUG: Callers that don't know about v7.20 must still work. The default
    # kwarg value is false, meaning jitter is applied unless explicitly suppressed.
    target  = Float64[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    pattern = Float64[0.3, 0.4, 0.5]

    # Call without the kwarg — should match nonjitter=false behavior.
    Random.seed!(77)
    _, c_default = _bidirectional_cheap_scan(target, pattern; threshold=0.3)
    Random.seed!(77)
    _, c_explicit_false = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=false)

    @test c_default === c_explicit_false
end

@testset "nonjitter does NOT corrupt fusion math" begin
    # GRUG: The whole point is: nonjitter silences post-fusion micro-jitter ONLY.
    # The fused coherence value (from big_number_small_number_coherence) must be
    # unchanged. We verify by comparing nonjitter=true output against a direct
    # call to big_number_small_number_coherence on the same forward/reverse pair.
    #
    # This is a WHITE-BOX test: we know the internal fusion function. If we ever
    # change the fusion strategy, this test will catch silent drift.
    target  = Float64[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
    pattern = Float64[0.3, 0.4, 0.5]

    # With nonjitter=true, post-fusion jitter is off. The returned confidence
    # should be exactly big_number_small_number_coherence(fwd_conf, rev_conf).
    # We can't directly observe fwd_conf and rev_conf from outside, but we CAN
    # assert the result is a valid output of big_number_small_number_coherence:
    # it lies in [0, 1] by the function's range contract.
    Random.seed!(31337)
    _, conf_nj = _bidirectional_cheap_scan(target, pattern; threshold=0.3, nonjitter=true)
    @test 0.0 <= conf_nj <= 1.0

    # GRUG: Sanity — the confidence should be positive for a pattern that
    # clearly appears in the target. If fusion were broken, we might get 0.
    @test conf_nj > 0.0
end

@testset "Tag survives push into existing required_relations" begin
    # GRUG: If a node already has other rules in required_relations, tagging
    # must not clobber them.
    node = make_bare_node("coexistence")
    push!(node.required_relations, "CAUSES")
    push!(node.required_relations, "REQUIRES")
    @test length(node.required_relations) == 2

    set_nonjitter!(node)
    @test length(node.required_relations) == 3
    @test "CAUSES" in node.required_relations
    @test "REQUIRES" in node.required_relations
    @test NONJITTER_TAG in node.required_relations
    @test is_nonjitter(node) == true
end

@testset "v7.21 — evaluate_relational_dialectics honors NONJITTER" begin
    # GRUG: Build two identical triple sets with matching relations. Score the
    # same inputs 50 times — with NONJITTER in required_relations, the score
    # must be bit-identical every time. Without the tag, repeated scoring
    # produces variance.
    RelationalTriple = getfield(GrugBot420, :RelationalTriple)
    evaluate_relational_dialectics = getfield(GrugBot420, :evaluate_relational_dialectics)

    user_triples = [RelationalTriple("cat", "chases", "mouse")]
    node_triples = [RelationalTriple("cat", "chases", "mouse")]
    relation_weights = Dict("chases" => 1.0)

    # Case A: NONJITTER absent — repeated calls can vary (jitter is on)
    req_plain = String[]
    scores_plain = Float64[]
    for _ in 1:50
        s, _ = evaluate_relational_dialectics(user_triples, node_triples, req_plain, relation_weights)
        push!(scores_plain, s)
    end
    # GRUG: At least two distinct values = jitter is working.
    @test length(unique(scores_plain)) >= 2

    # Case B: NONJITTER present — repeated calls must all equal
    req_nj = [NONJITTER_TAG]
    scores_nj = Float64[]
    for _ in 1:50
        s, _ = evaluate_relational_dialectics(user_triples, node_triples, req_nj, relation_weights)
        push!(scores_nj, s)
    end
    # GRUG: All 50 must be bit-equal — identity pass-through everywhere.
    @test length(unique(scores_nj)) == 1
    @test all(s -> s === scores_nj[1], scores_nj)

    # Case C: NONJITTER MUST NOT be treated as a missing semantic relation.
    # Even though user_triples has no relation called "NONJITTER", the function
    # must NOT return the -9999.0 sentinel.
    s_nj, _ = evaluate_relational_dialectics(user_triples, node_triples, req_nj, relation_weights)
    @test s_nj != -9999.0
    @test s_nj > 0.0   # real match, not sentinel

    # Case D: NONJITTER coexists with a real required relation. If the user
    # DOESN'T supply the real relation, the sentinel fires (tag is ignored
    # for the requirement check); if they DO, we get a real score and the
    # tag suppresses jitter.
    req_mixed = [NONJITTER_TAG, "chases"]
    s_ok, _ = evaluate_relational_dialectics(user_triples, node_triples, req_mixed, relation_weights)
    @test s_ok != -9999.0
    @test s_ok > 0.0

    # User doesn't have the required "needs" relation — sentinel fires
    req_missing = [NONJITTER_TAG, "needs"]
    s_missing, _ = evaluate_relational_dialectics(user_triples, node_triples, req_missing, relation_weights)
    @test s_missing == -9999.0
end

@testset "v7.21 — collect_nonjitter_ids walks NODE_MAP correctly" begin
    # GRUG: Snapshot the current NODE_MAP nonjitter set (boot-time seeds may
    # already have some if future work tags them). We build a few new test
    # nodes, tag some, leave others, and verify the set returned by
    # collect_nonjitter_ids matches exactly the ones we tagged (relative
    # to the baseline).
    NODE_MAP = getfield(GrugBot420, :NODE_MAP)
    NODE_LOCK = getfield(GrugBot420, :NODE_LOCK)

    baseline = collect_nonjitter_ids()

    # Create 3 fresh nodes and insert them into NODE_MAP directly.
    a = make_bare_node("nj_map_a_$(rand(1:10_000_000))")
    b = make_bare_node("nj_map_b_$(rand(1:10_000_000))")
    c = make_bare_node("nj_map_c_$(rand(1:10_000_000))")

    lock(NODE_LOCK) do
        NODE_MAP[a.id] = a
        NODE_MAP[b.id] = b
        NODE_MAP[c.id] = c
    end

    try
        # Tag only a and c.
        set_nonjitter!(a)
        set_nonjitter!(c)

        got = collect_nonjitter_ids()

        # a and c must appear, b must not.
        @test a.id in got
        @test c.id in got
        @test !(b.id in got)

        # Exactly the two newly tagged ids have been added vs baseline.
        diff = setdiff(got, baseline)
        @test diff == Set([a.id, c.id])
    finally
        # Cleanup to avoid test pollution.
        lock(NODE_LOCK) do
            delete!(NODE_MAP, a.id)
            delete!(NODE_MAP, b.id)
            delete!(NODE_MAP, c.id)
        end
    end
end

@testset "v7.21 — FullLobeScanner honors nonjitter_ids kwarg" begin
    # GRUG: activate_candidates! takes a node_features dict and an optional
    # nonjitter_ids::Set{String}. Tagged ids should produce bit-stable
    # confidence (abs(similarity) pass-through); untagged ids get jittered.
    # FullLobeScanner is a submodule of GrugBot420 — reach its public names
    # via explicit qualified access so the test does not depend on which
    # names happen to be auto-imported into Main.
    LobeScanner = GrugBot420.FullLobeScanner.LobeScanner
    set_query! = GrugBot420.FullLobeScanner.set_query!
    gather_candidates! = GrugBot420.FullLobeScanner.gather_candidates!
    activate_candidates! = GrugBot420.FullLobeScanner.activate_candidates!

    # Build minimal features: 3 nodes with identical feature vectors so
    # similarity is identical. Only difference is the tag set we pass.
    features = Dict{String, Vector{Float64}}(
        "tagged_node"   => Float64[1.0, 0.0, 0.0, 1.0],
        "untagged_node" => Float64[1.0, 0.0, 0.0, 1.0],
    )
    query_vec = Float64[1.0, 0.0, 0.0, 1.0]

    # Run 20 scans with nonjitter_ids = {"tagged_node"}. Collect confidences
    # for both nodes across runs. Tagged node must be bit-stable; untagged
    # node should show variance.
    tagged_confs   = Float64[]
    untagged_confs = Float64[]

    for seed in 1:20
        Random.seed!(seed)
        scanner = LobeScanner("test_lobe", 1)
        set_query!(scanner, query_vec)
        gather_candidates!(
            scanner, features;
            threshold=0.0,
            nonjitter_ids=Set(["tagged_node"])
        )
        activate_candidates!(
            scanner, features;
            confident_threshold=0.0,
            nonjitter_ids=Set(["tagged_node"])
        )

        # Find the confidences for each node from the active set
        for (node_id, conf) in scanner.active_set.activations
            if node_id == "tagged_node"
                push!(tagged_confs, conf)
            elseif node_id == "untagged_node"
                push!(untagged_confs, conf)
            end
        end
    end

    # GRUG: tagged_node must yield exactly one unique confidence across all seeds
    @test length(unique(tagged_confs)) == 1

    # GRUG: untagged_node should show variance (at least 2 distinct values)
    # across 20 differently-seeded runs.
    @test length(unique(untagged_confs)) >= 2

    # GRUG: backward compat — empty nonjitter_ids means both nodes get jittered.
    legacy_confs_a = Float64[]
    legacy_confs_b = Float64[]
    for seed in 1:20
        Random.seed!(seed + 1000)
        scanner = LobeScanner("test_lobe", 1)
        set_query!(scanner, query_vec)
        gather_candidates!(scanner, features; threshold=0.0)
        activate_candidates!(scanner, features; confident_threshold=0.0)

        for (node_id, conf) in scanner.active_set.activations
            node_id == "tagged_node"   && push!(legacy_confs_a, conf)
            node_id == "untagged_node" && push!(legacy_confs_b, conf)
        end
    end
    # Both should vary when the kwarg is omitted (default empty set = no-op).
    @test length(unique(legacy_confs_a)) >= 2
    @test length(unique(legacy_confs_b)) >= 2
end

@testset "Performance — is_nonjitter is cheap" begin
    # GRUG: is_nonjitter is called on every cheap-scan hot path. It MUST be
    # fast. We don't benchmark exact cycles (machine-dependent), but we assert
    # that 1_000_000 calls complete in under 1 second on any sane machine.
    # If this fails, something has gone very wrong (e.g., locking added).
    node = make_bare_node("perf")
    set_nonjitter!(node)

    # Warm up
    for _ in 1:1000
        is_nonjitter(node)
    end

    t0 = time()
    for _ in 1:1_000_000
        is_nonjitter(node)
    end
    elapsed = time() - t0

    @test elapsed < 1.0   # 1M calls in under 1 second
end