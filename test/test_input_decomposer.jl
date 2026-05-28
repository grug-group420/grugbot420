# test/test_input_decomposer.jl
# v7.23 — exercise the compound-query input decomposition layer.

using Test

module _InputDecomposerTestParent
    include(joinpath(@__DIR__, "..", "src", "InputDecomposer.jl"))
    using .InputDecomposer
end

using ._InputDecomposerTestParent: DecomposedSubSubject
using ._InputDecomposerTestParent.InputDecomposer

@testset "InputDecomposer — singleton passthrough" begin
    # GRUG: Simple input with no compound structure → single sub-subject, singleton.
    subs = decompose_input("what is a rock")
    @test length(subs) == 1
    @test subs[1].multipart_group == ""
    @test subs[1].role == :singleton
    @test subs[1].text == "what is a rock"
    @test subs[1].index == 1
    @test !is_compound("what is a rock")
end

@testset "InputDecomposer — also-split compound" begin
    # GRUG: "also" between two independent questions → two sub-subjects.
    subs = decompose_input("what time is it also what is a dinosaur")
    @test length(subs) == 2
    @test subs[1].multipart_group == "mp_1"
    @test subs[1].role == :primary
    @test subs[2].multipart_group == "mp_2"
    @test subs[2].role == :support
    @test occursin("time", lowercase(subs[1].text))
    @test occursin("dinosaur", lowercase(subs[2].text))
    @test is_compound("what time is it also what is a dinosaur")
end

@testset "InputDecomposer — and-split compound (both sides question)" begin
    # GRUG: "and" splits when both sides have question markers.
    subs = decompose_input("what is bread and what is butter")
    @test length(subs) == 2
    @test subs[1].multipart_group == "mp_1"
    @test subs[2].multipart_group == "mp_2"
    @test occursin("bread", lowercase(subs[1].text))
    @test occursin("butter", lowercase(subs[2].text))
    @test is_compound("what is bread and what is butter")
end

@testset "InputDecomposer — and-no-split (no question markers)" begin
    # GRUG: "bread and butter" with no question markers → one subject.
    subs = decompose_input("bread and butter")
    @test length(subs) == 1
    @test subs[1].multipart_group == ""
    @test subs[1].role == :singleton
    @test !is_compound("bread and butter")
end

@testset "InputDecomposer — multi-question-mark split" begin
    # GRUG: Multiple "?" markers → each question becomes its own sub-subject.
    subs = decompose_input("what time is it? what is a dinosaur? what is 2+2?")
    @test length(subs) >= 2  # at least 2 sub-subjects
    @test is_compound("what time is it? what is a dinosaur? what is 2+2?")
end

@testset "InputDecomposer — triple compound (also + and)" begin
    # GRUG: The canonical example: "what time is it ALSO what is a dinosaur AND what is 2+2"
    subs = decompose_input("what time is it also what is a dinosaur and what is 2+2")
    @test length(subs) == 3
    @test subs[1].role == :primary
    @test subs[2].role == :support
    @test subs[3].role == :support
    @test subs[1].index == 1
    @test subs[2].index == 2
    @test subs[3].index == 3
end

@testset "InputDecomposer — but-split compound" begin
    # GRUG: "but" with question on right side → split.
    subs = decompose_input("what is fire but what is ice")
    @test length(subs) == 2
    @test subs[1].multipart_group == "mp_1"
    @test subs[2].multipart_group == "mp_2"
end

@testset "InputDecomposer — empty input" begin
    subs = decompose_input("")
    @test length(subs) == 1
    @test subs[1].multipart_group == ""
    @test subs[1].role == :singleton
end

@testset "InputDecomposer — summarize_decomposition" begin
    subs = decompose_input("what is time also what is space")
    summary = InputDecomposer.summarize_decomposition(subs)
    @test occursin("compound", summary)
    @test occursin("mp_1", summary)
    @test occursin("mp_2", summary)
end

@testset "InputDecomposer — summarize singleton" begin
    subs = decompose_input("hello world")
    summary = InputDecomposer.summarize_decomposition(subs)
    @test occursin("singleton", summary)
end

@testset "InputDecomposer — comma-based splitting" begin
    # Comma between two question clauses should split.
    subs = decompose_input("what is fire, what is ice")
    @test length(subs) == 2
    @test subs[1].multipart_group == "mp_1"
    @test subs[2].multipart_group == "mp_2"
    @test occursin("fire", subs[1].text)
    @test occursin("ice", subs[2].text)
end

@testset "InputDecomposer — comma list stays together" begin
    # Comma in a list (no question markers) should NOT split.
    subs = decompose_input("bread, butter, and cheese")
    @test length(subs) == 1
    @test subs[1].role == :singleton
end
