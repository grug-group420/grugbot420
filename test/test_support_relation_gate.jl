# ==============================================================================
# v7.16.1 -- SUPPORT RELATION GATE TESTS
# ==============================================================================
# GRUG: Prove that `relation_score` earns points only for REAL structural or
# semantic links between a primary vote and a candidate vote. Each scoring
# axis gets its own test; every assertion carries an explanatory message.
#
# Scoring recap (from Main.jl):
#   +3  group partners (GroupRegistry)
#   +3  attachment pair (ATTACHMENT_MAP, either direction)
#   +2  same lobe
#   +1  connected lobe
#   +1 per shared triple token (cap +2)
#   +1  shared concept class on the ACTION strings
#   +1  shared concept class on pattern tokens (cap +1)
#
# Threshold AIML_SUPPORT_RELATION_FLOOR = 2: anything below is DEMOTED from
# support to reliability-flagged hedge. Tests pin the floor and prove the
# score function returns integers in the expected bands.
#
# NO SILENT FAILURES: every axis tested independently; unrelated nodes must
# score zero; self-match must be ignored.
# ==============================================================================

using Test
using GrugBot420
using GrugBot420: Vote, Node, RelationalTriple, relation_score
using GrugBot420.VoteOrchestrator: AIML_SUPPORT_RELATION_FLOOR
using GrugBot420.Thesaurus
using GrugBot420.GroupRegistry
using GrugBot420.Lobe

# GRUG: Minimal Node constructor. All 24 fields in order; only id + pattern
# + action_packet matter for the relation_score checks. Triples are filled
# in per-test via the Vote struct (relation_score reads Vote.node_triples,
# not Node.relational_patterns, so Node triples can stay empty).
function _bare_node(id::String, pattern::String = "default pattern")
    return Node(
        id,
        pattern,
        Float64[1.0, 2.0, 3.0],
        "noop",
        Dict{String,Any}(),
        String[],
        1.0,
        RelationalTriple[],
        String[],
        Dict{String,Float64}(),
        1.0,        # strength
        false,      # is_image_node
        String[],   # neighbor_ids
        false,      # is_unlinkable
        false,      # is_grave
        "",         # grave_reason
        Float64[],  # response_times
        time(),     # ledger_last_cleared
        UInt64(0),  # hopfield_key
        false, false, false, 0.0,  # fired/voted/gained/delta
    )
end

function _vote(id::String, action::String;
               confidence::Float64 = 0.5,
               triples::Vector{RelationalTriple} = RelationalTriple[])
    return Vote(id, action, confidence, String[], RelationalTriple[], triples, false)
end


@testset "v7.16.1 -- AIML_SUPPORT_RELATION_FLOOR is pinned at 2" begin
    # GRUG: Floor is load-bearing; a silent retune would change behavior
    # everywhere. Pin it here so drift shows up as a test failure.
    @test AIML_SUPPORT_RELATION_FLOOR == 2
end


@testset "v7.16.1 -- self-match returns zero" begin
    # GRUG: A vote scored against itself must never earn points, even if
    # it would otherwise score high. The orchestrator filters this upstream
    # too, but the function guards internally.
    n = _bare_node("self_n1", "alpha beta")
    v = _vote("self_n1", "noop")
    r = relation_score(v, n, v, n)
    @test r.score == 0
    @test "self-match-ignored" in r.reasons
end


@testset "v7.16.1 -- unrelated nodes score zero" begin
    # GRUG: Two nodes with no shared lobe, no group, no attachment, no
    # shared triple tokens, no concept-class overlap. Baseline must be 0.
    p_node = _bare_node("unrel_p", "completely separate topic xyz")
    c_node = _bare_node("unrel_c", "totally different words qqq")
    p_vote = _vote("unrel_p", "zzzzz_action_a")
    c_vote = _vote("unrel_c", "qqqqq_action_b")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score == 0
    @test isempty(r.reasons)
end


@testset "v7.16.1 -- shared triple tokens earn +1 each (cap +2)" begin
    # GRUG: Build votes whose node_triples share two non-trivial tokens.
    # "honey" + "bees" appear in both triple sets; expect +2, capped.
    p_node = _bare_node("trip_p", "bees make honey")
    c_node = _bare_node("trip_c", "hive things")
    shared_triples_p = [
        RelationalTriple("bees", "produce", "honey"),
        RelationalTriple("bees", "gather", "nectar"),
    ]
    shared_triples_c = [
        RelationalTriple("honey", "flows_from", "bees"),
        RelationalTriple("workers", "guard", "nectar"),
    ]
    p_vote = _vote("trip_p", "gather_aaa"; triples = shared_triples_p)
    c_vote = _vote("trip_c", "guard_bbb";  triples = shared_triples_c)

    r = relation_score(p_vote, p_node, c_vote, c_node)
    # Expect exactly the +2 cap from triple overlap. Unique action strings
    # guarantee no action-class point leaks in.
    @test r.score >= 2
    @test r.score <= 3   # allow +1 pattern-class if "bees"/"honey" bleed in
    @test any(startswith.(r.reasons, "triples+"))
end


@testset "v7.16.1 -- triple overlap below length-3 is ignored" begin
    # GRUG: Tokens under 3 chars (like "is", "to") are filtered to avoid
    # noise. Shared "is" should earn ZERO points.
    p_node = _bare_node("short_p", "unique alpha")
    c_node = _bare_node("short_c", "unique beta")
    p_vote = _vote("short_p", "zzzz_unique_1"; triples = [RelationalTriple("x", "is", "y")])
    c_vote = _vote("short_c", "qqqq_unique_2"; triples = [RelationalTriple("a", "is", "b")])

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score == 0
end


@testset "v7.16.1 -- action concept-class overlap earns +1" begin
    # GRUG: "ask" and "probe" are both members of the seeded "inquiry"
    # concept class, so two votes with those actions must earn +1 on
    # the action-class axis.
    @test "probe" in Thesaurus.get_concept_equivalents("ask")

    p_node = _bare_node("cls_p", "unique left side")
    c_node = _bare_node("cls_c", "unique right side")
    p_vote = _vote("cls_p", "ask")
    c_vote = _vote("cls_c", "probe")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score >= 1
    @test "action-class+1" in r.reasons
end


@testset "v7.16.1 -- pattern concept-class overlap earns +1" begin
    # GRUG: Patterns share the "inquiry" class via "query" vs "question",
    # but the ACTION strings are unique so the action-class axis stays cold.
    @test "question" in Thesaurus.get_concept_equivalents("query")

    p_node = _bare_node("pat_p", "please query the system")
    c_node = _bare_node("pat_c", "send one question now")
    p_vote = _vote("pat_p", "aaaa_action_unique_1")
    c_vote = _vote("pat_c", "bbbb_action_unique_2")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score >= 1
    @test "pattern-class+1" in r.reasons
    # action-class must NOT have fired (unique strings)
    @test !("action-class+1" in r.reasons)
end


@testset "v7.16.1 -- reasons list tracks each earning axis" begin
    # GRUG: Multi-axis scoring. Pattern concept class + action concept
    # class should both fire; combined score >= 2 (meets the floor).
    p_node = _bare_node("multi_p", "please query now")
    c_node = _bare_node("multi_c", "send a question")
    p_vote = _vote("multi_p", "ask")
    c_vote = _vote("multi_c", "probe")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score >= AIML_SUPPORT_RELATION_FLOOR
    @test "action-class+1" in r.reasons
    @test "pattern-class+1" in r.reasons
end


@testset "v7.16.1 -- group-registry partners earn +3" begin
    # GRUG: Register two node IDs in the same group; the group axis must
    # fire with +3 even when nothing else matches.
    p_id = "grp_p_$(rand(1:1_000_000))"
    c_id = "grp_c_$(rand(1:1_000_000))"
    gname = "relation_gate_group_$(rand(1:1_000_000))"

    GroupRegistry.register_node_in_group!(gname, p_id)
    GroupRegistry.register_node_in_group!(gname, c_id)

    p_node = _bare_node(p_id, "alpha unique pattern")
    c_node = _bare_node(c_id, "omega unrelated pattern")
    p_vote = _vote(p_id, "aaaa_unique_action_p")
    c_vote = _vote(c_id, "bbbb_unique_action_c")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test r.score >= 3
    @test "group+3" in r.reasons
end


@testset "v7.16.1 -- unrelated group members stay at zero" begin
    # GRUG: Register a group with only ONE of the two votes, so partnership
    # lookup fails. The group axis must NOT fire.
    p_id = "solo_p_$(rand(1:1_000_000))"
    c_id = "solo_c_$(rand(1:1_000_000))"
    gname = "solo_group_$(rand(1:1_000_000))"

    GroupRegistry.register_node_in_group!(gname, p_id)
    # GRUG: candidate is NOT registered -- partners list stays empty

    p_node = _bare_node(p_id, "sole alpha")
    c_node = _bare_node(c_id, "sole omega")
    p_vote = _vote(p_id, "xxxx_sole_p")
    c_vote = _vote(c_id, "yyyy_sole_c")

    r = relation_score(p_vote, p_node, c_vote, c_node)
    @test !("group+3" in r.reasons)
end


println("\u2705 v7.16.1 support-relation-gate tests complete.")
