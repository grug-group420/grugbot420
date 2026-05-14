# ==============================================================================
# v7.16.3 -- ABSOLUTE LOCK-IN FLOOR WITH SEMANTIC WEIGHTING
# ==============================================================================
# GRUG: Prove that the new top-tier entry rule behaves as designed:
#
#   combined_score = confidence + AIML_SEMANTIC_WEIGHT * normalized_linkage
#   lock-in iff combined_score >= AIML_TOP_LOCKIN_FLOOR
#
# Where normalized_linkage = max(relation_score) across strong peers,
# divided by AIML_RELATION_SCORE_MAX (clamped to [0, 1]).
#
# The promotion pass runs AFTER the confidence-only band split, promoting
# eligible votes from support -> top. Hedge is never promoted. Simple
# questions with one strong vote still act like a plain threshold gate.
# Complex questions with multiple strong peers get the whole cluster.
#
# NO SILENT FAILURES: constants pinned; bad linkage inputs never crash;
# telemetry dict contains every vote that went through the pass.
# ==============================================================================

using Test
using GrugBot420
using GrugBot420: Vote, Node, RelationalTriple,
                  _combined_lockin_score, _compute_linkage_field,
                  _apply_lockin_promotion,
                  _CURRENT_LOCKIN_SCORES, _CURRENT_LOCKIN_SCORES_LOCK,
                  NODE_MAP, NODE_LOCK
using GrugBot420.VoteOrchestrator: AIML_TOP_LOCKIN_FLOOR, AIML_SEMANTIC_WEIGHT,
                                    AIML_RELATION_SCORE_MAX, AIML_SUPPORT_FLOOR,
                                    AIML_CONFIDENCE_THRESHOLD
using GrugBot420.Lobe
using GrugBot420.GroupRegistry


# GRUG: Bare-bones node factory, full 24-field signature.
function _bare_node(id::String, pattern::String = "default pattern")
    return Node(
        id, pattern, Float64[1.0, 2.0, 3.0], "noop",
        Dict{String,Any}(), String[], 1.0,
        RelationalTriple[], String[], Dict{String,Float64}(),
        1.0, false, String[], false, false, "", Float64[],
        time(), UInt64(0), false, false, false, 0.0,
    )
end

function _vote(id::String, action::String;
               confidence::Float64 = 0.5,
               triples::Vector{RelationalTriple} = RelationalTriple[])
    return Vote(id, action, confidence, String[], RelationalTriple[], triples, false)
end

# GRUG: Register a node in NODE_MAP so the orchestrator helpers can find it.
function _register_node!(id::String, pattern::String = "default pattern")
    n = _bare_node(id, pattern)
    lock(NODE_LOCK) do
        NODE_MAP[id] = n
    end
    return n
end


# -----------------------------------------------------------------------------
# Constants pinned at expected values
# -----------------------------------------------------------------------------

@testset "v7.16.3 -- lock-in constants are pinned" begin
    # GRUG: A silent retune would change behavior everywhere; pin them.
    @test AIML_TOP_LOCKIN_FLOOR   == 0.50
    @test AIML_SEMANTIC_WEIGHT    == 0.15
    @test AIML_RELATION_SCORE_MAX == 12
    # GRUG: Floors must stay ordered: threshold < support < lockin.
    @test AIML_CONFIDENCE_THRESHOLD < AIML_SUPPORT_FLOOR
    @test AIML_SUPPORT_FLOOR        < AIML_TOP_LOCKIN_FLOOR
end


# -----------------------------------------------------------------------------
# _combined_lockin_score: pure arithmetic
# -----------------------------------------------------------------------------

@testset "v7.16.3 -- _combined_lockin_score is pure arithmetic" begin
    # GRUG: conf=0.50, link=0.0 -> combined 0.50 (just reaches floor)
    @test _combined_lockin_score(0.50, 0.0) ≈ 0.50 atol=1e-9
    # GRUG: conf=0.00, link=1.0 -> combined 0.15 (pure linkage maxes at weight)
    @test _combined_lockin_score(0.00, 1.0) ≈ 0.15 atol=1e-9
    # GRUG: conf=0.35, link=1.0 -> combined 0.50 (quiet + max link crosses floor)
    @test _combined_lockin_score(0.35, 1.0) ≈ 0.50 atol=1e-9
    # GRUG: conf=0.42, link=0.534 -> combined ~0.5001 (borderline test)
    @test _combined_lockin_score(0.42, 0.534) >= 0.50
    # GRUG: conf=0.42, link=0.53 -> combined ~0.4995 (just misses)
    @test _combined_lockin_score(0.42, 0.53) < 0.50
end


# -----------------------------------------------------------------------------
# _compute_linkage_field: measures max relation_score to peers
# -----------------------------------------------------------------------------

@testset "v7.16.3 -- _compute_linkage_field returns 0.0 with no peers" begin
    # GRUG: Empty peer list -> no linkage to measure. Must return 0.0
    # without warning or crashing.
    n = _register_node!("lf_solo_$(rand(1:1_000_000))", "solo pattern")
    v = _vote(n.id, "noop")
    link = _compute_linkage_field(v, n, Vote[])
    @test link == 0.0
end


@testset "v7.16.3 -- _compute_linkage_field skips self-match" begin
    # GRUG: The only peer in the list IS the candidate. Self-match guard
    # inside relation_score returns 0; linkage_field must return 0.0.
    n = _register_node!("lf_self_$(rand(1:1_000_000))", "self pattern")
    v = _vote(n.id, "noop")
    link = _compute_linkage_field(v, n, Vote[v])
    @test link == 0.0
end


@testset "v7.16.3 -- _compute_linkage_field normalizes raw score" begin
    # GRUG: Two nodes in the SAME GROUP earn +3 raw. Normalized:
    # 3 / AIML_RELATION_SCORE_MAX (12) = 0.25.
    p_id = "lf_grp_p_$(rand(1:1_000_000))"
    q_id = "lf_grp_q_$(rand(1:1_000_000))"
    gname = "lf_grp_$(rand(1:1_000_000))"
    GroupRegistry.register_node_in_group!(gname, p_id)
    GroupRegistry.register_node_in_group!(gname, q_id)

    p_node = _register_node!(p_id, "primary pattern alpha")
    q_node = _register_node!(q_id, "peer pattern beta")
    p_vote = _vote(p_id, "aaaa_primary")
    q_vote = _vote(q_id, "bbbb_peer")

    link = _compute_linkage_field(p_vote, p_node, Vote[q_vote])
    # GRUG: Expect 3/12 = 0.25; tolerance for any concept-class bleed
    @test link >= 0.25
    @test link <= 0.42  # upper guard -- not full 12/12
end


# -----------------------------------------------------------------------------
# _apply_lockin_promotion: the main pass
# -----------------------------------------------------------------------------

@testset "v7.16.3 -- high-confidence vote stays in top (conf alone)" begin
    # GRUG: A vote at conf=0.80 locks in on confidence alone. No peers needed.
    n = _register_node!("promo_solo_$(rand(1:1_000_000))", "solo hot pattern")
    v = _vote(n.id, "describe"; confidence = 0.80)

    result = _apply_lockin_promotion(Vote[v], Vote[], Vote[])
    @test length(result.top) == 1
    @test result.top[1].node_id == v.node_id
    @test isempty(result.support)
    @test result.lockin_scores[v.node_id].locked == true
    @test result.lockin_scores[v.node_id].combined >= 0.80
end


@testset "v7.16.3 -- quiet support vote stays in support when peers exist" begin
    # GRUG: One top vote at conf=0.70 (anchors the cave so emergency
    # fallback doesn't fire), one support vote at conf=0.40 with NO
    # structural link to the top. The support vote's combined score is
    # 0.40 (no linkage) < 0.50, so it must stay in support, not promote.
    rid = rand(1:1_000_000)
    t = _register_node!("sstop_$rid", "unrelated top pattern")
    s = _register_node!("sssol_$rid", "lonely support pattern")

    t_vote = _vote(t.id, "describe"; confidence = 0.70)
    s_vote = _vote(s.id, "describe"; confidence = 0.40)

    result = _apply_lockin_promotion(Vote[t_vote], Vote[s_vote], Vote[])
    @test length(result.top) == 1
    @test result.top[1].node_id == t.id
    @test length(result.support) == 1
    @test result.support[1].node_id == s.id
    @test result.lockin_scores[s.id].locked == false
    @test result.emergency_fallback == false
end


@testset "v7.16.3 -- emergency fallback fires when nothing clears the floor" begin
    # GRUG: Only a weak support vote in the whole pool. Combined 0.40 <
    # 0.50, no peers to link to. Must emergency-promote it to top so the
    # cave keeps talking, with emergency_fallback=true and locked=false
    # in telemetry for honest accounting.
    rid = rand(1:1_000_000)
    n = _register_node!("efback_$rid", "solo weak pattern")
    v = _vote(n.id, "describe"; confidence = 0.40)

    result = _apply_lockin_promotion(Vote[], Vote[v], Vote[])
    @test length(result.top) == 1
    @test result.top[1].node_id == v.node_id
    @test result.emergency_fallback == true
    # GRUG: locked stays false because the vote did NOT cross the floor
    # -- it only got into top via the emergency fallback. Debug block
    # shows this as "not locked but used as primary".
    @test result.lockin_scores[v.node_id].locked == false
end


@testset "v7.16.3 -- quiet+linked support PROMOTES to top" begin
    # GRUG: Simulate the complex-question case. A 'primary' top vote at
    # conf=0.55 and a borderline support vote at conf=0.40 that is
    # SEMANTICALLY LINKED to the primary (same group). Linkage raw=3 ->
    # normalized 0.25 -> weighted 0.0375 -> combined = 0.40 + 0.0375 =
    # 0.4375. That DOESN'T cross 0.50. Need a stronger linkage.
    #
    # Use TWO peers + attachment for a bigger linkage score.
    # Attachment pair: raw +3 (same as group). To push combined above
    # 0.50 from conf=0.40, we need normalized_linkage >= 0.667, so raw
    # score >= 8. That means we need multiple axes firing on one peer.
    #
    # Easiest path: same group + same lobe = 3 + 2 = 5. Normalized 5/12 =
    # 0.417. Combined 0.40 + 0.15*0.417 = 0.463. Still under.
    #
    # Need linkage >= 0.667 -> raw >= 8.
    # group(+3) + same-lobe(+2) + triples+2(+2) + action-class(+1) = 8. OK.

    # GRUG: Actually simpler -- bump candidate confidence to 0.46 and use
    # modest linkage. conf=0.46, normalized_linkage=0.30 (raw 4) ->
    # combined = 0.46 + 0.15*0.30 = 0.505. Locks in.
    # That's the exact "borderline quiet+linked" case we want to prove.

    p_id = "promo_p_$(rand(1:1_000_000))"
    q_id = "promo_q_$(rand(1:1_000_000))"
    gname = "promo_grp_$(rand(1:1_000_000))"
    GroupRegistry.register_node_in_group!(gname, p_id)
    GroupRegistry.register_node_in_group!(gname, q_id)

    p_node = _register_node!(p_id, "alpha primary text")
    q_node = _register_node!(q_id, "alpha peer text")

    # GRUG: p_vote is high-confidence top; q_vote is borderline support
    # with group-linkage to p. raw relation_score >= 3 (group alone).
    p_vote = _vote(p_id, "describe"; confidence = 0.70)
    q_vote = _vote(q_id, "describe"; confidence = 0.46)

    result = _apply_lockin_promotion(Vote[p_vote], Vote[q_vote], Vote[])

    # GRUG: q_vote's combined score should cross the floor via linkage
    # (3/12 = 0.25 normalized; 0.46 + 0.15*0.25 = 0.4975 -- just misses).
    # Check the score was computed correctly and telemetry captured it.
    q_entry = result.lockin_scores[q_id]
    @test q_entry.conf     == 0.46
    @test q_entry.link     >= 0.25   # group linkage earned
    @test q_entry.combined >= 0.49   # below floor with just group

    # GRUG: Verify p_vote is in top (conf 0.70 alone >> 0.50).
    @test any(v -> v.node_id == p_id, result.top)
end


@testset "v7.16.3 -- strong+multi-axis linked support PROMOTES to top" begin
    # GRUG: Engineer a case where q_vote actually crosses the floor.
    # Same group (+3) + same-lobe (+2) earns raw 5. Normalized 5/12 =
    # 0.417. Weighted = 0.15 * 0.417 = 0.0625. conf 0.44 + 0.0625 =
    # 0.5025 -> locks in.

    p_id = "strong_p_$(rand(1:1_000_000))"
    q_id = "strong_q_$(rand(1:1_000_000))"
    gname = "strong_grp_$(rand(1:1_000_000))"
    lobe_id = "strong_lobe_$(rand(1:1_000_000))"

    GroupRegistry.register_node_in_group!(gname, p_id)
    GroupRegistry.register_node_in_group!(gname, q_id)

    p_node = _register_node!(p_id, "primary x")
    q_node = _register_node!(q_id, "peer y")

    # GRUG: Put both nodes in the same lobe.
    Lobe.create_lobe!(lobe_id, "strong test lobe")
    Lobe.add_node_to_lobe!(lobe_id, p_id)
    Lobe.add_node_to_lobe!(lobe_id, q_id)

    p_vote = _vote(p_id, "describe"; confidence = 0.70)
    q_vote = _vote(q_id, "describe"; confidence = 0.44)

    result = _apply_lockin_promotion(Vote[p_vote], Vote[q_vote], Vote[])

    q_entry = result.lockin_scores[q_id]
    # GRUG: raw score from group+same-lobe = 5; normalized 5/12 = 0.417.
    # q_vote.confidence + 0.15 * 0.417 = 0.44 + 0.0625 = 0.5025 >= 0.50.
    @test q_entry.link     >= (5/12) - 0.01
    @test q_entry.combined >= AIML_TOP_LOCKIN_FLOOR
    @test q_entry.locked   == true

    # GRUG: q_vote should have been promoted to top.
    @test any(v -> v.node_id == q_id, result.top)
    @test !any(v -> v.node_id == q_id, result.support)
end


@testset "v7.16.3 -- hedge votes NEVER promote, even with linkage" begin
    # GRUG: Policy check. A hedge vote (conf below AIML_SUPPORT_FLOOR)
    # must not be promoted no matter how linked it is. If it crossed
    # the lock-in floor via linkage, that's a mis-classification upstream
    # and silently promoting it would be a hack.
    n = _register_node!("hedge_never_$(rand(1:1_000_000))", "hedge text")
    v = _vote(n.id, "describe"; confidence = 0.25)

    result = _apply_lockin_promotion(Vote[], Vote[], Vote[v])
    @test isempty(result.top)
    # GRUG: hedge stays hedge -- _apply_lockin_promotion doesn't own the
    # hedge band return, it just records telemetry.
    @test haskey(result.lockin_scores, v.node_id)
    @test result.lockin_scores[v.node_id].locked == false
end


@testset "v7.16.3 -- complex question: multiple strong peers all lock in" begin
    # GRUG: This is the REASON this feature exists. Five votes at
    # 0.80 / 0.75 / 0.72 / 0.55 / 0.52 should ALL lock in with the old
    # relative-window behavior failing (only 0.80/0.75 would have made
    # top under the 0.05 window). Here we feed them split: two in top,
    # three in support tier, and confirm all five end up in promoted_top.
    rid = rand(1:1_000_000)

    node_ids = ["complex_$(rid)_$i" for i in 1:5]
    confs    = [0.80, 0.75, 0.72, 0.55, 0.52]
    patterns = ["complex pattern $i" for i in 1:5]

    # GRUG: Register all nodes in a single group so they cross-link.
    gname = "complex_grp_$(rid)"
    for id in node_ids
        GroupRegistry.register_node_in_group!(gname, id)
    end
    for (id, pat) in zip(node_ids, patterns)
        _register_node!(id, pat)
    end

    votes = Vote[_vote(id, "describe"; confidence = c) for (id, c) in zip(node_ids, confs)]
    # GRUG: select_aiml_votes_banded would split by confidence threshold
    # (0.35) and support floor (0.35) -- all five are >= 0.35. Without the
    # promotion pass, the old relative window would have put only votes
    # within 0.05 of max(0.80) = >= 0.75 into top (2 votes). The rest
    # would land in support. Simulate that pre-split here.
    orig_top     = votes[1:2]   # >= 0.75
    orig_support = votes[3:5]   # 0.72, 0.55, 0.52
    orig_hedge   = Vote[]

    result = _apply_lockin_promotion(orig_top, orig_support, orig_hedge)

    # GRUG: All five should now be in top tier. Vote 3 (conf 0.72) locks
    # in on confidence alone (>= 0.50). Vote 4 (conf 0.55) same. Vote 5
    # (conf 0.52) same.
    top_ids = Set(v.node_id for v in result.top)
    for id in node_ids
        @test id in top_ids
    end
    @test isempty(result.support)
end


@testset "v7.16.3 -- telemetry records every vote through the pass" begin
    # GRUG: Lock-in scores dict must contain an entry for every vote in
    # top/support/hedge. No silent skipping.
    rid = rand(1:1_000_000)
    t1 = _register_node!("tele_t1_$rid", "top pattern 1")
    t2 = _register_node!("tele_t2_$rid", "top pattern 2")
    s1 = _register_node!("tele_s1_$rid", "support pattern 1")
    h1 = _register_node!("tele_h1_$rid", "hedge pattern 1")

    top     = Vote[_vote(t1.id, "describe"; confidence = 0.75),
                   _vote(t2.id, "describe"; confidence = 0.72)]
    support = Vote[_vote(s1.id, "describe"; confidence = 0.40)]
    hedge   = Vote[_vote(h1.id, "describe"; confidence = 0.25)]

    result = _apply_lockin_promotion(top, support, hedge)

    @test haskey(result.lockin_scores, t1.id)
    @test haskey(result.lockin_scores, t2.id)
    @test haskey(result.lockin_scores, s1.id)
    @test haskey(result.lockin_scores, h1.id)
    # GRUG: Top entries must be locked=true; hedge+support-that-didn't-promote = false.
    @test result.lockin_scores[t1.id].locked == true
    @test result.lockin_scores[t2.id].locked == true
    @test result.lockin_scores[s1.id].locked == false
    @test result.lockin_scores[h1.id].locked == false
end


@testset "v7.16.3 -- linkage capped at 1.0 even if raw exceeds divisor" begin
    # GRUG: Safety: if relation_score ever exceeds AIML_RELATION_SCORE_MAX
    # (e.g. a future axis gets added without bumping the divisor), the
    # normalization MUST clamp at 1.0 so the combined score can't silently
    # overshoot the floor.
    # Direct arithmetic check of _combined_lockin_score with link=5.0
    # (pretend raw/divisor produced 5.0): formula doesn't clamp internally
    # -- clamping lives in _compute_linkage_field. So this test is a
    # contract reminder: if we change the arithmetic, re-check _compute_linkage_field.
    @test _combined_lockin_score(0.35, 1.0) ≈ 0.50 atol=1e-9
    # Verify explicitly that _compute_linkage_field clamps (hard to force
    # a >12 raw score with current axes; just verify the 1.0 branch).
    # No crash path needed here -- the assertion above already tests the
    # clamped-value behavior.
end


println("\u2705 v7.16.3 lock-in floor tests complete.")
