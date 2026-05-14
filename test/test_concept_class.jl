# test_concept_class.jl -- v7.16.0 Concept-Class Thesaurus + Inhibition
# GRUG: Concept classes are NAMED equivalence groups. Any member swaps for any
# other. Mirror inhibition: ban the class name, every member becomes inhibited.
# NO SILENT FAILURES -- empty inputs throw, undefined classes throw on ban.

include("../src/Thesaurus.jl")
include("../src/InputQueue.jl")
using .Thesaurus
using .InputQueue
using Test

@testset "Concept Class Thesaurus (v7.16.0)" begin

    @testset "seed classes are loaded" begin
        # GRUG: 13 seed classes baked in at module load
        @test Thesaurus.concept_class_count() >= 13
        # GRUG: inquiry class should contain ask + probe + query
        inquiry_eqs = Thesaurus.get_concept_equivalents("probe")
        @test "ask" in inquiry_eqs
        @test "query" in inquiry_eqs
        @test "question" in inquiry_eqs
        # GRUG: probe itself is NOT in its own equivalents list (excluded)
        @test !("probe" in inquiry_eqs)
    end

    @testset "add_concept_class! bidirectional insert" begin
        n_before = Thesaurus.concept_class_count()
        (name, total) = Thesaurus.add_concept_class!("rhythm",
                                                     ["beat", "pulse", "cadence", "tempo"])
        @test name == "rhythm"
        @test total == 4
        @test Thesaurus.concept_class_count() == n_before + 1

        # every member looks up to all siblings
        beat_eqs = Thesaurus.get_concept_equivalents("beat")
        @test "pulse" in beat_eqs
        @test "cadence" in beat_eqs
        @test "tempo" in beat_eqs
        @test !("beat" in beat_eqs)  # self-exclusion

        # reverse index works
        classes = Thesaurus.concept_classes_of("pulse")
        @test "rhythm" in classes
    end

    @testset "add_concept_class! idempotent merge" begin
        Thesaurus.add_concept_class!("rhythm_merge_test", ["a", "b"])
        (_, t1) = Thesaurus.add_concept_class!("rhythm_merge_test", ["b", "c", "d"])
        @test t1 == 4  # a, b, c, d
        eqs = Thesaurus.get_concept_equivalents("a")
        @test "d" in eqs
    end

    @testset "add_concept_class! validates inputs" begin
        @test_throws Thesaurus.ThesaurusError Thesaurus.add_concept_class!("", ["x"])
        @test_throws Thesaurus.ThesaurusError Thesaurus.add_concept_class!("name", String[])
        @test_throws Thesaurus.ThesaurusError Thesaurus.add_concept_class!("name", ["   "])
    end

    @testset "remove_concept_class! cleans reverse index" begin
        Thesaurus.add_concept_class!("throwaway", ["xyz123", "abc456"])
        @test Thesaurus.remove_concept_class!("throwaway") == true
        @test isempty(Thesaurus.get_concept_equivalents("xyz123"))
        @test Thesaurus.remove_concept_class!("throwaway") == false  # idempotent
    end

    @testset "unknown word returns empty" begin
        @test isempty(Thesaurus.get_concept_equivalents("nonsenseword987"))
        @test isempty(Thesaurus.concept_classes_of("nonsenseword987"))
    end
end

@testset "Concept-Class Inhibition (v7.16.0)" begin

    @testset "add_concept_inhibition! bans all members" begin
        Thesaurus.add_concept_class!("test_ban_group", ["alpha", "beta", "gamma"])
        InputQueue.add_concept_inhibition!("test_ban_group"; reason = "unit test")
        # every member of the class is now is_inhibited
        @test InputQueue.is_inhibited("alpha") == true
        @test InputQueue.is_inhibited("beta")  == true
        @test InputQueue.is_inhibited("gamma") == true
        # non-members unaffected
        @test InputQueue.is_inhibited("delta") == false
        # cleanup
        InputQueue.remove_concept_inhibition!("test_ban_group")
        @test InputQueue.is_inhibited("alpha") == false
    end

    @testset "add_concept_inhibition! rejects unknown class" begin
        @test_throws InputQueue.InputQueueError InputQueue.add_concept_inhibition!("never_defined_class")
    end

    @testset "add_concept_inhibition! rejects duplicate" begin
        Thesaurus.add_concept_class!("dup_test", ["one", "two"])
        InputQueue.add_concept_inhibition!("dup_test")
        @test_throws InputQueue.InputQueueError InputQueue.add_concept_inhibition!("dup_test")
        InputQueue.remove_concept_inhibition!("dup_test")
    end

    @testset "remove_concept_inhibition! returns correct bool" begin
        Thesaurus.add_concept_class!("rm_test", ["qq", "ww"])
        InputQueue.add_concept_inhibition!("rm_test")
        @test InputQueue.remove_concept_inhibition!("rm_test") == true
        @test InputQueue.remove_concept_inhibition!("rm_test") == false
    end

    @testset "word-level and concept-level bans compose (OR)" begin
        Thesaurus.add_concept_class!("compose_test", ["xx1", "yy1"])
        # only yy1 word-banned, not the class
        InputQueue.add_inhibition!("yy1"; reason = "direct word ban")
        @test InputQueue.is_inhibited("yy1") == true
        @test InputQueue.is_inhibited("xx1") == false
        # now concept-ban the class -- both become inhibited
        InputQueue.add_concept_inhibition!("compose_test")
        @test InputQueue.is_inhibited("xx1") == true
        @test InputQueue.is_inhibited("yy1") == true  # still (word ban stays)
        # lift concept ban -- word ban remains
        InputQueue.remove_concept_inhibition!("compose_test")
        @test InputQueue.is_inhibited("yy1") == true
        @test InputQueue.is_inhibited("xx1") == false
        # cleanup
        InputQueue.remove_inhibition!("yy1")
    end

    @testset "concept_inhibition_count" begin
        before = InputQueue.concept_inhibition_count()
        Thesaurus.add_concept_class!("count_test", ["zz1"])
        InputQueue.add_concept_inhibition!("count_test")
        @test InputQueue.concept_inhibition_count() == before + 1
        InputQueue.remove_concept_inhibition!("count_test")
        @test InputQueue.concept_inhibition_count() == before
    end
end
