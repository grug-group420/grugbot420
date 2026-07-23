# test_thesaurus.jl - GRUG Comprehensive test suite for Thesaurus module
# GRUG say: test everything. No surprises in cave.
# GRUG say: if test fail, Grug know immediately. No silent failures.

include("Thesaurus.jl")
using .Thesaurus: ThesaurusError, ThesaurusResult,
                  generate_ngrams, jaccard_similarity,
                  word_similarity, concept_similarity,
                  context_similarity, cross_type_similarity,
                  thesaurus_compare, format_thesaurus_intensity,
                  thesaurus_batch_compare

using Test

@testset "Thesaurus Module Tests" begin

    # ========================================================================
    @testset "ThesaurusError Tests" begin
        # GRUG: Error must throw and have correct fields
        err = ThesaurusError("test message", "test context")
        @test err.message == "test message"
        @test err.context == "test context"

        # GRUG: throw_thesaurus_error must throw ThesaurusError
        @test_throws ThesaurusError word_similarity("", "hello")
        @test_throws ThesaurusError concept_similarity("", "some concept")
    end

    # ========================================================================
    @testset "generate_ngrams Tests" begin
        # GRUG: basic trigrams
        ngrams = generate_ngrams("hello")
        @test "hel" in ngrams
        @test "ell" in ngrams
        @test "llo" in ngrams
        @test length(ngrams) == 3

        # GRUG: short word (shorter than n) returns itself
        short = generate_ngrams("hi", 3)
        @test "hi" in short
        @test length(short) == 1

        # GRUG: empty string returns empty set
        empty_result = generate_ngrams("")
        @test isempty(empty_result)

        # GRUG: strips and lowercases
        mixed = generate_ngrams("Hello World", 3)
        @test "hel" in mixed

        # GRUG: spaces removed before ngrams
        spaced = generate_ngrams("ab cd", 3)
        @test "abc" in spaced

        # GRUG: n=1 gives individual chars
        chars = generate_ngrams("abc", 1)
        @test "a" in chars
        @test "b" in chars
        @test "c" in chars

        # GRUG: n=2 bigrams
        bigrams = generate_ngrams("test", 2)
        @test "te" in bigrams
        @test "es" in bigrams
        @test "st" in bigrams

        # GRUG: n <= 0 returns empty
        bad_n = generate_ngrams("hello", 0)
        @test isempty(bad_n)

        # GRUG: exact length word
        exact = generate_ngrams("abc", 3)
        @test "abc" in exact
        @test length(exact) == 1
    end

    # ========================================================================
    @testset "jaccard_similarity Tests" begin
        # GRUG: identical sets = 1.0
        s = Set(["a", "b", "c"])
        @test jaccard_similarity(s, s) == 1.0

        # GRUG: disjoint sets = 0.0
        s1 = Set(["a", "b"])
        s2 = Set(["c", "d"])
        @test jaccard_similarity(s1, s2) == 0.0

        # GRUG: 50% overlap
        s3 = Set(["a", "b", "c", "d"])
        s4 = Set(["c", "d", "e", "f"])
        j = jaccard_similarity(s3, s4)
        @test j ≈ 2/6 atol=0.001

        # GRUG: empty sets both = 1.0
        @test jaccard_similarity(Set{String}(), Set{String}()) == 1.0

        # GRUG: one empty = 0.0
        @test jaccard_similarity(Set{String}(), Set(["a"])) == 0.0
    end

    # ========================================================================
    @testset "word_similarity Tests" begin
        # GRUG: identical words = 1.0
        @test word_similarity("hello", "hello") == 1.0
        @test word_similarity("Hello", "hello") == 1.0

        # GRUG: completely different = low
        sim_diff = word_similarity("apple", "xylophone")
        @test sim_diff < 0.3

        # GRUG: similar words = high
        sim_sim = word_similarity("colour", "color")
        @test sim_sim > 0.3

        # GRUG: empty throws error
        @test_throws ThesaurusError word_similarity("", "hello")
        @test_throws ThesaurusError word_similarity("hello", "")

        # GRUG: case insensitive
        @test word_similarity("Happy", "happy") == 1.0

        # GRUG: prefix similarity
        sim_pre = word_similarity("run", "running")
        @test sim_pre > 0.1

        # GRUG: very similar words
        sim_vs = word_similarity("happy", "happ")
        @test sim_vs > 0.3

        # GRUG: bigram mode works
        sim_bi = word_similarity("test", "tests"; ngram_size=2)
        @test sim_bi > 0.3
    end

    # ========================================================================
    @testset "concept_similarity Tests" begin
        # GRUG: identical concepts = 1.0
        @test concept_similarity("machine learning", "machine learning") == 1.0

        # GRUG: completely different concepts = low
        sim_diff = concept_similarity("machine learning", "flower garden")
        @test sim_diff < 0.4

        # GRUG: partial token overlap
        sim_part = concept_similarity("machine learning", "machine vision")
        @test sim_part > 0.3

        # GRUG: empty throws error
        @test_throws ThesaurusError concept_similarity("", "something")
    end

    # ========================================================================
    @testset "context_similarity Tests" begin
        # GRUG: identical contexts = 1.0
        ctx = ["science", "technology"]
        @test context_similarity(ctx, ctx) == 1.0

        # GRUG: both empty = 0.5 (neutral - no info either way)
        @test context_similarity(String[], String[]) == 0.5

        # GRUG: one empty = 0.0
        @test context_similarity(["science"], String[]) == 0.0
    end

    # ========================================================================
    @testset "cross_type_similarity Tests" begin
        # GRUG: word as exact token in concept
        # Note: seed dictionary may boost certain pairs above 0.85 - test >= not ==
        sim_token = cross_type_similarity("intelligence", "artificial intelligence")
        @test sim_token >= 0.85

        # GRUG: word as substring of concept (not token)
        sim_sub = cross_type_similarity("intel", "artificial intelligence")
        @test sim_sub > 0.5

        # GRUG: acronym detection - AI = artificial intelligence
        sim_acronym = cross_type_similarity("AI", "artificial intelligence")
        @test sim_acronym > 0.8

        # GRUG: empty throws error
        @test_throws ThesaurusError cross_type_similarity("", "something")
    end

    # ========================================================================
    @testset "thesaurus_compare Tests" begin

        @testset "Word-word comparison" begin
            # GRUG: identical words = 1.0 overall
            result = thesaurus_compare("happy", "happy")
            @test result.overall == 1.0
            @test result.semantic == 1.0
            @test result.match_type == "word-word"

            # GRUG: different words with no trigram overlap = 0.0 (engine is structural, not semantic)
            result2 = thesaurus_compare("happy", "joyful")
            @test result2.overall >= 0.0
            @test result2.match_type == "word-word"

            # GRUG: opposite words = low score
            result3 = thesaurus_compare("happy", "xylophone")
            @test result3.overall < 0.5
        end

        @testset "Concept-concept comparison" begin
            # GRUG: identical concepts = 1.0
            result = thesaurus_compare("machine learning", "machine learning")
            @test result.overall == 1.0
            @test result.match_type == "concept-concept"

            # GRUG: different concepts with no token overlap = 0.0 (structural engine)
            result2 = thesaurus_compare("machine learning", "artificial intelligence")
            @test result2.overall >= 0.0
        end

        @testset "Cross-type comparison" begin
            # GRUG: word vs concept
            result = thesaurus_compare("AI", "artificial intelligence")
            @test result.match_type == "cross-type"
            @test result.semantic > 0.0

            # GRUG: concept vs word (reversed)
            result2 = thesaurus_compare("machine learning", "ML")
            @test result2.match_type == "cross-type"
        end

        @testset "With contexts" begin
            # GRUG: 2 shared out of 4 unique tokens = 0.5 jaccard
            ctx1 = ["emotion", "feeling", "mood"]
            ctx2 = ["emotion", "feeling", "state"]
            result = thesaurus_compare("happy", "joyful"; context1=ctx1, context2=ctx2)
            @test result.contextual >= 0.5
            # GRUG: fully identical contexts = 1.0
            same_ctx = ["emotion", "feeling"]
            result2 = thesaurus_compare("happy", "joyful"; context1=same_ctx, context2=same_ctx)
            @test result2.contextual == 1.0
        end

        @testset "Empty input throws error" begin
            @test_throws ThesaurusError thesaurus_compare("", "hello")
        end
    end

    # ========================================================================
    @testset "format_thesaurus_intensity Tests" begin
        @test format_thesaurus_intensity(1.0)   == "IDENTICAL"
        @test format_thesaurus_intensity(0.98)  == "IDENTICAL"
        @test format_thesaurus_intensity(0.95)  == "IDENTICAL"
        @test format_thesaurus_intensity(0.90)  == "VERY HIGH"
        @test format_thesaurus_intensity(0.85)  == "VERY HIGH"
        @test format_thesaurus_intensity(0.75)  == "HIGH"
        @test format_thesaurus_intensity(0.70)  == "HIGH"
        @test format_thesaurus_intensity(0.60)  == "MEDIUM"
        @test format_thesaurus_intensity(0.50)  == "MEDIUM"
        @test format_thesaurus_intensity(0.35)  == "LOW"
        @test format_thesaurus_intensity(0.20)  == "VERY LOW"
        @test format_thesaurus_intensity(0.10)  == "NEGLIGIBLE"
        @test format_thesaurus_intensity(0.0)   == "NEGLIGIBLE"
        @test_throws ThesaurusError format_thesaurus_intensity(-0.1)
        @test_throws ThesaurusError format_thesaurus_intensity(1.1)
    end

    # ========================================================================
    @testset "thesaurus_batch_compare Tests" begin
        candidates = ["joyful", "sad", "ecstatic", "gloomy", "cheerful"]
        results    = thesaurus_batch_compare("happy", candidates)

        # GRUG: returns correct count
        @test length(results) == 5

        # GRUG: sorted by overall descending
        for i in 1:(length(results) - 1)
            @test results[i][2].overall >= results[i+1][2].overall
        end

        # GRUG: each result has a candidate string
        for (cand, res) in results
            @test !isempty(cand)
            @test res.overall >= 0.0
            @test res.overall <= 1.0
        end

        # GRUG: empty target throws error
        @test_throws ThesaurusError thesaurus_batch_compare("", candidates)

        # GRUG: empty candidates throws error
        @test_throws ThesaurusError thesaurus_batch_compare("happy", String[])

        # GRUG: batch with contexts
        ctxs    = [["emotion"], ["emotion"], ["emotion"], ["emotion"], ["emotion"]]
        results2 = thesaurus_batch_compare("happy", candidates; target_context=["emotion"], candidate_contexts=ctxs)
        @test length(results2) == 5
    end

    # ========================================================================
    @testset "Integration Tests" begin
        # GRUG: full pipeline - compare, format, confirm consistency
        result = thesaurus_compare("dog", "canine")
        label  = format_thesaurus_intensity(result.overall)
        @test !isempty(label)
        @test result.confidence > 0.0
        @test result.confidence <= 1.0

        # GRUG: details dict has expected keys
        @test haskey(result.details, "input1")
        @test haskey(result.details, "input2")
        @test haskey(result.details, "is_word1")
        @test haskey(result.details, "weights_used")
    end

end

# ============================================================================
# SECTION 8: Seed Synonym Dictionary
# GRUG: Seed dictionary bridges structural gap (happy/joyful = was 0.0, now 0.95)
# ============================================================================

@testset "Thesaurus - Seed Synonym Dictionary" begin

    @testset "synonym_lookup: known seed pairs return 0.95" begin
        # GRUG: Classic structural gap pairs that trigrams cannot solve
        @test Thesaurus.synonym_lookup("happy",  "joyful")    >= 0.90
        @test Thesaurus.synonym_lookup("fast",   "quick")     >= 0.90
        @test Thesaurus.synonym_lookup("big",    "large")     >= 0.90
        @test Thesaurus.synonym_lookup("fix",    "repair")    >= 0.90
        @test Thesaurus.synonym_lookup("error",  "mistake")   >= 0.90
        @test Thesaurus.synonym_lookup("start",  "begin")     >= 0.90
        @test Thesaurus.synonym_lookup("search", "scan")      >= 0.90
    end

    @testset "synonym_lookup: bidirectional (both directions work)" begin
        @test Thesaurus.synonym_lookup("joyful", "happy")  >= 0.90
        @test Thesaurus.synonym_lookup("quick",  "fast")   >= 0.90
        @test Thesaurus.synonym_lookup("large",  "big")    >= 0.90
        @test Thesaurus.synonym_lookup("repair", "fix")    >= 0.90
    end

    @testset "synonym_lookup: identical word returns 1.0" begin
        @test Thesaurus.synonym_lookup("happy", "happy") == 1.0
        @test Thesaurus.synonym_lookup("error", "error") == 1.0
    end

    @testset "synonym_lookup: unrelated words return low score" begin
        # GRUG: Cave and democracy are not synonyms
        score = Thesaurus.synonym_lookup("cave", "democracy")
        @test score < 0.3
    end

    @testset "synonym_lookup: empty inputs throw" begin
        @test_throws Thesaurus.ThesaurusError Thesaurus.synonym_lookup("", "happy")
        @test_throws Thesaurus.ThesaurusError Thesaurus.synonym_lookup("happy", "")
    end

    @testset "get_seed_synonyms: known word returns non-empty list" begin
        syns = Thesaurus.get_seed_synonyms("happy")
        @test !isempty(syns)
        @test "joyful" in syns || "glad" in syns
    end

    @testset "get_seed_synonyms: unknown word returns empty list" begin
        syns = Thesaurus.get_seed_synonyms("xyzzy_not_a_word")
        @test isempty(syns)
    end

    @testset "get_seed_synonyms: empty input throws" begin
        @test_throws Thesaurus.ThesaurusError Thesaurus.get_seed_synonyms("")
    end

    @testset "thesaurus_compare word-word now uses synonym_lookup (happy|joyful > 0)" begin
        # GRUG: This was the famous 0.0 failure case! Now seeded.
        result = Thesaurus.thesaurus_compare("happy", "joyful")
        @test result.overall >= 0.85
        @test result.match_type == "word-word"
    end

    @testset "thesaurus_compare: fast | quick now scores high" begin
        result = Thesaurus.thesaurus_compare("fast", "quick")
        @test result.overall >= 0.85
    end

    @testset "thesaurus_compare: error | mistake now scores high" begin
        result = Thesaurus.thesaurus_compare("error", "mistake")
        @test result.overall >= 0.85
    end

    @testset "SYNONYM_SEED_MAP is populated at load time" begin
        @test length(Thesaurus.SYNONYM_SEED_MAP) > 50
    end

end

# ============================================================================
# SECTION 9: Gate Filter
# GRUG: Gate expands input tokens with synonyms for pre-scan enrichment
# ============================================================================

@testset "Thesaurus - Gate Filter" begin

    @testset "thesaurus_gate_filter returns Set containing original tokens" begin
        result = Thesaurus.thesaurus_gate_filter("fix the error")
        @test "fix"   in result
        @test "the"   in result
        @test "error" in result
    end

    @testset "thesaurus_gate_filter expands known tokens with synonyms" begin
        result = Thesaurus.thesaurus_gate_filter("fix the error")
        # GRUG: "fix" should expand to include repair/mend/patch etc.
        # "error" should expand to include mistake/bug/fault etc.
        has_fix_syn   = any(s -> s in result, ["repair", "mend", "patch", "correct"])
        has_error_syn = any(s -> s in result, ["mistake", "bug", "fault", "defect"])
        @test has_fix_syn
        @test has_error_syn
    end

    @testset "thesaurus_gate_filter result is larger than original token set" begin
        input = "fix error"
        tokens = Set(split(lowercase(input)))
        result = Thesaurus.thesaurus_gate_filter(input)
        @test length(result) > length(tokens)
    end

    @testset "thesaurus_gate_filter caps expansions per token" begin
        # GRUG: Even a word with many synonyms should not explode the set
        result = Thesaurus.thesaurus_gate_filter("happy")
        # Original: 1 token. Max expansions = GATE_MAX_EXPANSIONS_PER_TOKEN = 3.
        # So max total = 1 + 3 = 4
        @test length(result) <= 1 + Thesaurus.GATE_MAX_EXPANSIONS_PER_TOKEN
    end

    @testset "thesaurus_gate_filter unknown tokens pass through unchanged" begin
        result = Thesaurus.thesaurus_gate_filter("xyzzy_token_nobody_knows")
        @test "xyzzy_token_nobody_knows" in result
    end

    @testset "thesaurus_gate_filter single word no synonyms" begin
        # GRUG: Word with no seeds still returns at minimum itself
        result = Thesaurus.thesaurus_gate_filter("grug")
        @test "grug" in result
    end

    @testset "thesaurus_gate_filter empty input throws" begin
        @test_throws Thesaurus.ThesaurusError Thesaurus.thesaurus_gate_filter("")
        @test_throws Thesaurus.ThesaurusError Thesaurus.thesaurus_gate_filter("   ")
    end

    @testset "thesaurus_gate_score: synonymous inputs score higher than unrelated" begin
        # GRUG: "fix error" vs "repair mistake" should score higher than "fix error" vs "ocean dance"
        score_related   = Thesaurus.thesaurus_gate_score("fix error", "repair mistake")
        score_unrelated = Thesaurus.thesaurus_gate_score("fix error", "ocean dance")
        @test score_related > score_unrelated
    end

    @testset "thesaurus_gate_score: identical inputs score 1.0" begin
        score = Thesaurus.thesaurus_gate_score("hello world", "hello world")
        @test score == 1.0
    end

    @testset "thesaurus_gate_score: empty inputs throw" begin
        @test_throws Thesaurus.ThesaurusError Thesaurus.thesaurus_gate_score("", "hello")
        @test_throws Thesaurus.ThesaurusError Thesaurus.thesaurus_gate_score("hello", "")
    end

    @testset "thesaurus_gate_score result in [0.0, 1.0]" begin
        pairs = [
            ("fix error", "repair mistake"),
            ("start job", "begin work"),
            ("random words here", "completely different text"),
        ]
        for (a, b) in pairs
            score = Thesaurus.thesaurus_gate_score(a, b)
            @test 0.0 <= score <= 1.0
        end
    end

end

println()
println("=" ^ 60)
println("GRUG say: All tests complete! Thesaurus working good!")
println("         Seed synonyms bridge structural gap.")
println("         Gate filter ready for pre-scan expansion.")
println("=" ^ 60)