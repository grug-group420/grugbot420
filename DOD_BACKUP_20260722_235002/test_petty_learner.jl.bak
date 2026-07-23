# test_petty_learner.jl - GRUG v10 PettyLearner Fast-Path Tests
# GRUG say: petty learning is for small gaps. Not every hole needs new node.
# GRUG say: classifier must find ONE uncovered token. Two tokens = NOT petty.
# GRUG say: three paths: thesaurus, flashcard, lobe_whitelist. Test all three.

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

module _PettyLearnerTestParent
    include(joinpath(@__DIR__, "..", "src", "PettyLearner.jl"))
end

using ._PettyLearnerTestParent.PettyLearner: PettyResult, classify_petty, dispatch_petty!
using ._PettyLearnerTestParent.PettyLearner

println("🧪 Running PettyLearner tests...")

# =========================================================================
# HELPERS
# =========================================================================

# _is_covered uses occursin(token, pattern), so "happy" in patterns covers "happy"
const COVERED = Set(["happy", "big", "cat", "gravity", "photosynthesis"])
# uncovered_lobe has patterns that cover only a few tokens, leaving lobe subjects exposed
const COVERED_SPARSE = Set(["happy"])

function mock_gate_filter(word::String)::Vector{String}
    return String[]  # not needed for classifier
end

function mock_word_sim(a::String, b::String)::Float64
    pairs = Dict(
        ("glad", "happy") => 0.85,
        ("joyful", "happy") => 0.80,
        ("huge", "big") => 0.90,
        ("large", "big") => 0.82,
    )
    key = (lowercase(a), lowercase(b))
    rev = (lowercase(b), lowercase(a))
    return get(pairs, key, get(pairs, rev, 0.0))
end

const LOBE_SNAPS = [
    ("physics_lobe", "gravity mechanics relativity", Set(["n101", "n106"])),
    ("biology_lobe", "photosynthesis evolution biodiversity", Set(["n105", "n102"])),
    ("emotion_lobe", "happy sad emotion feeling", Set(["n113"])),
    ("math_lobe", "calculate integral equation", Set(["n115"])),
]

@testset "PettyLearner - Full Test Suite" begin

    # ── PATH 1: THESAURUS ──
    # GRUG: Need uncovered token + covered similar token IN THE SAME INPUT.
    # "glad" uncovered, "happy" covered, sim=0.85 >= 0.70.
    # Only ONE uncovered non-stopword token → eligible.

    @testset "Path 1: thesaurus fast-path" begin
        # "glad" is uncovered (1 uncovered non-stopword), "happy" is covered, sim=0.85
        result = classify_petty(
            "glad and happy",
            ["glad", "and", "happy"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result.dispatched
        @test result.path == :thesaurus
        @test result.candidate_token == "glad"
        @test result.similarity >= 0.70

        # "huge" is uncovered, "big" is covered, sim=0.90
        # But "things" is ALSO uncovered → 2 uncovered → NOT petty!
        # So use input where only "huge" is uncovered
        result2 = classify_petty(
            "huge big",
            ["huge", "big"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result2.dispatched
        @test result2.path == :thesaurus
        @test result2.candidate_token == "huge"
        @test result2.similarity >= 0.70
    end

    # ── PATH 2: FLASHCARD ──

    @testset "Path 2: flashcard fast-path" begin
        arith_bindings = Dict{String,Any}("&n1" => "3", "&op1" => "+", "&n2" => "5")
        result = classify_petty(
            "what is 3+5",
            ["what", "is", "3+5"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            arith_bindings,
        )
        @test result.dispatched
        @test result.path == :flashcard
        @test length(result.arithmetic_expr) > 0

        # No numbers → no flashcard
        no_nums = Dict{String,Any}("&op1" => "+")
        result2 = classify_petty(
            "just an operator",
            ["just", "an", "operator"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            no_nums,
        )
        @test result2.path != :flashcard
    end

    # ── PATH 3: LOBE WHITELIST ──
    # GRUG: Uncovered token that matches a lobe subject token.
    # Need EXACTLY ONE uncovered non-stopword token that appears in a lobe subject.
    # "relativity" appears in physics_lobe subject string.

    @testset "Path 3: lobe_whitelist fast-path" begin
        # "relativity" is uncovered, matches physics_lobe subject (2 nodes < 5)
        # Stopwords "what" and "is" are filtered out, so only 1 uncovered token
        result = classify_petty(
            "what is relativity",
            ["what", "is", "relativity"],
            COVERED_SPARSE,   # doesn't cover "relativity"
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result.dispatched
        @test result.path == :lobe_whitelist
        @test result.candidate_token == "relativity"
        @test result.target_lobe == "physics_lobe"

        # "mechanics" is in physics_lobe subject, uncovered
        # Use just "mechanics" alone — no other uncovered non-stopword tokens
        result2 = classify_petty(
            "mechanics",
            ["mechanics"],
            COVERED_SPARSE,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test result2.dispatched
        @test result2.path == :lobe_whitelist
        @test result2.candidate_token == "mechanics"
        @test result2.target_lobe == "physics_lobe"
    end

    # ── NO PETTY: MULTIPLE UNCOVERED ──

    @testset "No petty: multiple uncovered tokens" begin
        # Both "quantum" and "relativity" are uncovered non-stopwords
        result = classify_petty(
            "quantum and relativity",
            ["quantum", "and", "relativity"],
            COVERED_SPARSE,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test !result.dispatched
        @test result.path == :none
    end

    # ── NO PETTY: FULLY COVERED ──

    @testset "No petty: fully covered input" begin
        result = classify_petty(
            "happy big cat",
            ["happy", "big", "cat"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test !result.dispatched
        @test result.path == :none
    end

    # ── NO PETTY: LOW SIMILARITY ──

    @testset "No petty: similarity too low" begin
        # "quantum" uncovered, no similar covered token, not in any lobe subject
        result = classify_petty(
            "what is quantum",
            ["what", "is", "quantum"],
            COVERED,
            mock_gate_filter,
            mock_word_sim,
            LOBE_SNAPS,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        @test !result.dispatched
    end

    # ── NO PETTY: LOBE TOO POPULATED ──

    @testset "No petty: lobe has too many nodes" begin
        # If the lobe has >= 5 nodes, it's not under-populated → no whitelist
        big_lobe_snaps = [
            ("fat_lobe", "testing domain stuff", Set(["n1","n2","n3","n4","n5"])),
        ]
        result = classify_petty(
            "what is testing",
            ["what", "is", "testing"],
            COVERED_SPARSE,
            mock_gate_filter,
            mock_word_sim,
            big_lobe_snaps,
            Dict{String,Any}(),
            Dict{String,Any}(),
        )
        # "testing" is in the lobe subject, but lobe has 5 nodes → NOT petty whitelist
        @test !result.dispatched || result.path != :lobe_whitelist
    end

    # ── DISPATCH: THESAURUS ──

    @testset "dispatch_petty! — thesaurus" begin
        result = PettyResult(true, :thesaurus, "glad ≈ happy → synonym pair",
                             "glad", "emotion_lobe", 0.85, "", "")
        thesaurus_called = Ref(false)
        mock_register = (a, b) -> (thesaurus_called[] = true; true)
        dispatched = dispatch_petty!(result; thesaurus_register_fn=mock_register)
        @test thesaurus_called[]
        @test occursin("registered=true", dispatched.detail)
    end

    # ── DISPATCH: FLASHCARD ──

    @testset "dispatch_petty! — flashcard" begin
        result = PettyResult(true, :flashcard, "3+5 → flashcard",
                             "math", "math_lobe", 0.0, "3+5", "")
        fc_written = Ref(false)
        mock_fc_put = (lobe, expr, res; kwargs...) -> (fc_written[] = true; Dict("expr"=>expr))
        mock_arith = (bindings) -> Dict(:formatted => "8", :value => 8.0)
        dispatched = dispatch_petty!(result;
            flashcard_put_fn=mock_fc_put,
            arithmetic_compute_fn=mock_arith,
            arithmetic_bindings=Dict("&n1"=>"3", "&op1"=>"+", "&n2"=>"5"),
        )
        @test fc_written[]
        @test occursin("flashcard", dispatched.detail)
    end

    # ── DISPATCH: LOBE WHITELIST ──

    @testset "dispatch_petty! — lobe_whitelist" begin
        result = PettyResult(true, :lobe_whitelist, "relativity → physics_lobe",
                             "relativity", "physics_lobe", 0.0, "", "")
        wl_count = Ref(0)
        mock_wl = (lobe_id, token) -> (wl_count[] += 1; 1)
        dispatched = dispatch_petty!(result; lobe_whitelist_fn=mock_wl)
        @test wl_count[] == 1
        @test occursin("whitelist", dispatched.detail)
    end

    # ── DISPATCH: UNDISPATCHED ──

    @testset "dispatch_petty! — not dispatched" begin
        result = PettyResult(false, :none, "", "", "", 0.0, "", "")
        dispatched = dispatch_petty!(result)
        @test !dispatched.dispatched
    end

    # ── PETTY STATUS ──

    @testset "petty_status" begin
        status = PettyLearner.petty_status()
        @test occursin("max_uncovered_tokens", status)
        @test occursin("similarity_floor", status)
        @test occursin("min_token_length", status)
        @test occursin("max_arith_ops", status)
    end
end

println("✅ PettyLearner tests complete.")
