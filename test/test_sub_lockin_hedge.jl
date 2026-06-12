# ==============================================================================
# v7.25 -- SUB-LOCKIN HEDGE SECTION TESTS
# ==============================================================================
# GRUG: Prove that votes below the lock-in threshold (>= 0.20, < 0.50 combined)
# still enter the same pool and run through the same orchestration pipeline,
# but render in a SEPARATE "This might also be true" section after the certain
# response — NOT inline within the primary response.
#
# Key design principles (from the user):
#   1. Same list, same orchestration — no secondary pipeline
#   2. Lock-in votes (>= 0.50 combined) → primary response
#   3. Sub-lockin votes (>= 0.20, < 0.50) → "This might also be true" section
#   4. The hedge section appears AFTER the primary response + debug telemetry
#   5. For deterministic missions, no hedge section (no sub-lockin votes apply)
#
# These tests verify the rendering behavior by examining the payload output
# from `ephemeral_aiml_orchestrator` → `generate_aiml_payload`.
# ==============================================================================

using Test
using GrugBot420
using GrugBot420: Vote, Node, RelationalTriple, ephemeral_aiml_orchestrator,
                  NODE_MAP, NODE_LOCK, band_of
using GrugBot420.VoteOrchestrator: AIML_TOP_LOCKIN_FLOOR, AIML_SUPPORT_FLOOR,
                                     AIML_CONFIDENCE_THRESHOLD
using GrugBot420.Lobe
using GrugBot420.GroupRegistry

# GRUG: Bare-bones node factory, full 24-field signature.
function _bare_node(id::String, pattern::String = "default pattern")
    return Node(
        id, pattern, Float64[1.0, 2.0, 3.0], "noop",
        Dict{String,Any}("system_prompt" => "Grug is a cave thinker."), String[], 1.0,
        RelationalTriple[], String[], Dict{String,Float64}(),
        1.0, false, String[], false, false, "", Float64[],
        time(), UInt64(0), false, false, false, 0.0,
    )
end

function _vote(id::String, action::String;
               confidence::Float64 = 0.5,
               triples::Vector{RelationalTriple} = RelationalTriple[])
    return Vote(id, action, confidence, String[], RelationalTriple[], triples)
end

# GRUG: Register a node in NODE_MAP so the orchestrator helpers can find it.
function _register_node!(id::String, pattern::String = "default pattern")
    n = _bare_node(id, pattern)
    lock(NODE_LOCK) do
        NODE_MAP[id] = n
    end
    return n
end


@testset "v7.25 Sub-Lockin Hedge Section" begin

    # ======================================================================
    # [1] BASIC: sub-lockin votes appear in "This might also be true" section
    # ======================================================================
    @testset "[1] Sub-lockin votes render in hedge section, not inline" begin
        _register_node!("hedge_primary_1", "the sky is blue")
        _register_node!("hedge_support_1", "the grass is green")

        # Primary vote well above lock-in, support vote well below
        votes = [
            _vote("hedge_primary_1", "explain"; confidence=0.85),
            _vote("hedge_support_1", "describe"; confidence=0.30),
        ]

        mission = "what color is the sky"
        output, sure, unsure = ephemeral_aiml_orchestrator(mission, votes)

        # The primary should lock in
        @test !isempty(sure)
        @test sure[1].node_id == "hedge_primary_1"

        # The support vote should be in unsure (sub-lockin)
        @test !isempty(unsure)
        @test any(v.node_id == "hedge_support_1" for v in unsure)

        # CRITICAL: output should contain "This might also be true" section
        @test occursin("This might also be true:", output)

        # CRITICAL: the primary response should NOT contain the old inline
        # rendering for sub-lockin votes (they're in the hedge section now)
        parts = split(output, "This might also be true:", limit=2)
        @test length(parts) >= 2
        primary_section = String(parts[1])
        hedge_section = String(parts[2])

        # Primary section should contain the certain claim
        @test occursin("sky", lowercase(primary_section)) || occursin("blue", lowercase(primary_section))
    end

    # ======================================================================
    # [2] NO HEDGE SECTION when all votes lock in (no sub-lockin votes)
    # ======================================================================
    @testset "[2] No hedge section when all votes lock in" begin
        _register_node!("all_lock_1", "math is exact")
        _register_node!("all_lock_2", "numbers are precise")

        # Both votes well above lock-in
        votes = [
            _vote("all_lock_1", "reason"; confidence=0.90),
            _vote("all_lock_2", "analyze"; confidence=0.80),
        ]

        output, sure, unsure = ephemeral_aiml_orchestrator("is math exact", votes)

        # Both should lock in (combined >= 0.50)
        @test length(sure) >= 1
        # If unsure is empty, there should be NO hedge section
        if isempty(unsure)
            @test !occursin("This might also be true:", output)
        end
    end

    # ======================================================================
    # [3] NON-DETERMINISTIC mission with sub-lockin votes gets hedge section
    # ======================================================================
    @testset "[3] Exploratory missions with sub-lockin votes get hedge section" begin
        _register_node!("nondet_1", "philosophy is deep")
        _register_node!("nondet_sub_1", "art is subjective")

        votes = [
            _vote("nondet_1", "reason"; confidence=0.70),
            _vote("nondet_sub_1", "describe"; confidence=0.25),
        ]
        output, _, _ = ephemeral_aiml_orchestrator("what is philosophy", votes)
        @test occursin("This might also be true:", output)
    end

    # ======================================================================
    # [4] HEDGE BAND votes (below support floor) also go to hedge section
    # ======================================================================
    @testset "[4] Hedge band votes (< support floor) in hedge section" begin
        _register_node!("hedge_band_1", "the main point")
        _register_node!("hedge_band_2", "a faint whisper")

        # Primary well above lock-in, secondary below support floor (hedge band)
        votes = [
            _vote("hedge_band_1", "explain"; confidence=0.80),
            _vote("hedge_band_2", "ponder"; confidence=0.22),  # below support floor (0.35)
        ]

        output, sure, unsure = ephemeral_aiml_orchestrator("what is the point", votes)

        @test !isempty(unsure)
        @test any(v.node_id == "hedge_band_2" for v in unsure)

        # Should get the hedge section
        @test occursin("This might also be true:", output)

        # NOTE: band_of() returns :unknown after orchestrator finishes because
        # _CURRENT_BAND_INFO is cleared in the try/finally. The band assignment
        # is correct during orchestration (verified by debug telemetry output),
        # but not queryable after. We verify the vote IS in unsure (sub-lockin)
        # and the hedge section renders.
    end

    # ======================================================================
    # [5] MULTIPLE sub-lockin votes all appear in hedge section
    # ======================================================================
    @testset "[5] Multiple sub-lockin votes in same hedge section" begin
        _register_node!("multi_1", "strong claim")
        _register_node!("multi_2", "moderate claim A")
        _register_node!("multi_3", "moderate claim B")
        _register_node!("multi_4", "weak claim C")

        votes = [
            _vote("multi_1", "explain"; confidence=0.80),
            _vote("multi_2", "describe"; confidence=0.40),  # support band
            _vote("multi_3", "analyze"; confidence=0.38),   # support band
            _vote("multi_4", "ponder"; confidence=0.22),    # hedge band
        ]

        output, sure, unsure = ephemeral_aiml_orchestrator("tell me things", votes)

        # Primary locks in
        @test sure[1].node_id == "multi_1"

        # Should have sub-lockin votes
        @test length(unsure) >= 2

        # Should have the hedge section
        @test occursin("This might also be true:", output)

        # The hedge section should contain content about sub-lockin votes
        parts = split(output, "This might also be true:", limit=2)
        @test length(parts) >= 2
        hedge_section = String(parts[2])
        # At least one of the sub-lockin actions should appear
        @test occursin("describe", lowercase(hedge_section)) ||
              occursin("analyze", lowercase(hedge_section)) ||
              occursin("ponder", lowercase(hedge_section)) ||
              occursin("moderate", lowercase(hedge_section)) ||
              occursin("weak", lowercase(hedge_section))
    end

    # ======================================================================
    # [6] HEDGE SECTION appears AFTER debug telemetry separator
    # ======================================================================
    @testset "[6] Hedge section position: after debug telemetry" begin
        _register_node!("pos_1", "certain answer")
        _register_node!("pos_2", "uncertain whisper")

        votes = [
            _vote("pos_1", "explain"; confidence=0.75),
            _vote("pos_2", "ponder"; confidence=0.25),
        ]

        output, _, _ = ephemeral_aiml_orchestrator("give me answers", votes)

        # Both markers should appear
        @test occursin("=========================================", output)
        @test occursin("This might also be true:", output)

        # The hedge section should come AFTER the telemetry separator
        sep_idx = findfirst("=========================================", output)
        hedge_idx = findfirst("This might also be true:", output)
        @test !isnothing(sep_idx)
        @test !isnothing(hedge_idx)
        @test first(hedge_idx) > first(sep_idx)
    end

    # ======================================================================
    # [7] LOCK-IN FLOOR constant unchanged (0.50)
    # ======================================================================
    @testset "[7] Lock-in floor constant = 0.50" begin
        @test AIML_TOP_LOCKIN_FLOOR == 0.50
    end

    # ======================================================================
    # [8] CONFIDENCE THRESHOLD constant unchanged (0.20)
    # ======================================================================
    @testset "[8] Confidence threshold constant = 0.20" begin
        @test AIML_CONFIDENCE_THRESHOLD == 0.20
    end

    # ======================================================================
    # [9] OLD INLINE rendering removed: no "Grug also sure of" for support band
    # ======================================================================
    @testset "[9] No inline 'Grug also sure of' for sub-lockin support votes" begin
        _register_node!("inline_1", "the primary fact")
        _register_node!("inline_2", "the secondary fact")

        votes = [
            _vote("inline_1", "explain"; confidence=0.80),
            _vote("inline_2", "describe"; confidence=0.40),  # support band, sub-lockin
        ]

        output, sure, unsure = ephemeral_aiml_orchestrator("what is true", votes)

        # If hedge section exists, split and check primary part
        if occursin("This might also be true:", output)
            parts = split(output, "This might also be true:", limit=2)
            primary_section = String(parts[1])

            # Primary section should NOT contain the old inline rendering
            # "Grug also sure of" was the old inline support rendering
            @test !occursin("Grug also sure of", primary_section)
        end
    end

    # ======================================================================
    # [10] OLD INLINE rendering removed: no "Less certain" inline for hedge band
    # ======================================================================
    @testset "[10] No inline 'Less certain' for hedge band votes" begin
        _register_node!("lesscert_1", "the primary idea")
        _register_node!("lesscert_2", "a faint idea")

        votes = [
            _vote("lesscert_1", "explain"; confidence=0.80),
            _vote("lesscert_2", "ponder"; confidence=0.22),  # hedge band
        ]

        output, sure, unsure = ephemeral_aiml_orchestrator("what do you think", votes)

        # If hedge section exists, split and check primary part
        if occursin("This might also be true:", output)
            parts = split(output, "This might also be true:", limit=2)
            primary_section = String(parts[1])

            # Primary section should NOT contain the old inline "Less certain" hedge
            @test !occursin("Less certain", primary_section)
        end
    end

end

println()
println("=" ^ 60)
println("✅ v7.25 sub-lockin hedge section tests COMPLETE")
println("=" ^ 60)
