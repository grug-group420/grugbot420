# ==============================================================================
# test/test_arithmetic_engine.jl — Tests for Stage 2 Arithmetic Computation
# ==============================================================================

using Test

# GRUG: Load the modules the same way test_sigil_promoter.jl does.
# ArithmeticEngine uses `using ..SigilPromoter`, so it expects to live inside
# a parent module. We create a dummy parent module here so the include works
# exactly like it does inside the GrugBot420 package.
module _ArithTestParent
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    include(joinpath(@__DIR__, "..", "src", "SigilPromoter.jl"))
    include(joinpath(@__DIR__, "..", "src", "ArithmeticEngine.jl"))
    using .SigilRegistry
    using .SigilPromoter
    using .ArithmeticEngine
end

using ._ArithTestParent.SigilRegistry
using ._ArithTestParent.SigilPromoter
using ._ArithTestParent.ArithmeticEngine

@testset "ArithmeticEngine — Stage 2 Computation" begin

    # =========================================================================
    # has_math_bindings
    # =========================================================================
    @testset "has_math_bindings" begin
        # Empty bindings → false
        @test has_math_bindings(SigilBinding[]) == false

        # Only &n bindings, no &op → false
        only_numbers = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        @test has_math_bindings(only_numbers) == false

        # Only &op, no &n → false
        only_ops = [
            SigilBinding(1, "op", "+", :lambda, "+", 1),
        ]
        @test has_math_bindings(only_ops) == false

        # Two &n and one &op → true
        math_bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        @test has_math_bindings(math_bindings) == true

        # Three &n and two &op → true (multi-step)
        multi_bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
            SigilBinding(3, "op", "*", :lambda, "*", 3),
            SigilBinding(4, "n", 4, :lambda, "4", 4),
        ]
        @test has_math_bindings(multi_bindings) == true

        # One &n and one &op → false (need 2 numbers)
        one_number = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
        ]
        @test has_math_bindings(one_number) == false
    end

    # =========================================================================
    # compute_arithmetic — basic operations
    # =========================================================================
    @testset "compute_arithmetic — addition" begin
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 2, :lambda, "2", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 4
        @test result.answer_str == "4"
        @test result.is_comparison == false
        @test length(result.steps) == 1
        @test result.steps[1].lhs == 2
        @test result.steps[1].operator == "+"
        @test result.steps[1].rhs == 2
        @test result.steps[1].result == 4
    end

    @testset "compute_arithmetic — subtraction" begin
        bindings = [
            SigilBinding(0, "n", 10, :lambda, "10", 0),
            SigilBinding(1, "op", "-", :lambda, "-", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 7
        @test result.answer_str == "7"
    end

    @testset "compute_arithmetic — multiplication" begin
        bindings = [
            SigilBinding(0, "n", 6, :lambda, "6", 0),
            SigilBinding(1, "op", "*", :lambda, "*", 1),
            SigilBinding(2, "n", 7, :lambda, "7", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 42
        @test result.answer_str == "42"
    end

    @testset "compute_arithmetic — division (exact)" begin
        bindings = [
            SigilBinding(0, "n", 20, :lambda, "20", 0),
            SigilBinding(1, "op", "/", :lambda, "/", 1),
            SigilBinding(2, "n", 4, :lambda, "4", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 5
        @test result.answer_str == "5"
    end

    @testset "compute_arithmetic — division (fractional)" begin
        bindings = [
            SigilBinding(0, "n", 7, :lambda, "7", 0),
            SigilBinding(1, "op", "/", :lambda, "/", 1),
            SigilBinding(2, "n", 2, :lambda, "2", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 3.5
        @test occursin("3.5", result.answer_str)
    end

    @testset "compute_arithmetic — division by zero" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
            SigilBinding(1, "op", "/", :lambda, "/", 1),
            SigilBinding(2, "n", 0, :lambda, "0", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error !== nothing
        @test occursin("division by zero", result.error)
    end

    @testset "compute_arithmetic — modulo" begin
        bindings = [
            SigilBinding(0, "n", 10, :lambda, "10", 0),
            SigilBinding(1, "op", "%", :lambda, "%", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 1
    end

    @testset "compute_arithmetic — power" begin
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "^", :lambda, "^", 1),
            SigilBinding(2, "n", 10, :lambda, "10", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 1024
        @test result.answer_str == "1024"
    end

    # =========================================================================
    # compute_arithmetic — comparisons
    # =========================================================================
    @testset "compute_arithmetic — equality" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
            SigilBinding(1, "op", "=", :lambda, "=", 1),
            SigilBinding(2, "n", 5, :lambda, "5", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == "true"
        @test result.is_comparison == true
    end

    @testset "compute_arithmetic — inequality" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
            SigilBinding(1, "op", "=", :lambda, "=", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == "false"
        @test result.is_comparison == true
    end

    @testset "compute_arithmetic — less than" begin
        bindings = [
            SigilBinding(0, "n", 3, :lambda, "3", 0),
            SigilBinding(1, "op", "<", :lambda, "<", 1),
            SigilBinding(2, "n", 5, :lambda, "5", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == "true"
        @test result.is_comparison == true
    end

    @testset "compute_arithmetic — greater than" begin
        bindings = [
            SigilBinding(0, "n", 7, :lambda, "7", 0),
            SigilBinding(1, "op", ">", :lambda, ">", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == "true"
        @test result.is_comparison == true
    end

    # =========================================================================
    # compute_arithmetic — multi-step
    # =========================================================================
    @testset "compute_arithmetic — multi-step (left-to-right)" begin
        # 2 + 3 * 4 — without operator precedence, this is (2+3)*4 = 20
        # With precedence it would be 2+(3*4) = 14. Stage 2 does left-to-right.
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 3, :lambda, "3", 2),
            SigilBinding(3, "op", "*", :lambda, "*", 3),
            SigilBinding(4, "n", 4, :lambda, "4", 4),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        # Left-to-right: (2 + 3) = 5, then 5 * 4 = 20
        @test result.answer == 20
        @test length(result.steps) == 2
        @test result.steps[1].result == 5
        @test result.steps[2].result == 20
    end

    # =========================================================================
    # compute_arithmetic — edge cases
    # =========================================================================
    @testset "compute_arithmetic — empty bindings" begin
        result = compute_arithmetic(SigilBinding[])
        @test result.error !== nothing
        @test result.answer === nothing
    end

    @testset "compute_arithmetic — only one number" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
        ]
        result = compute_arithmetic(bindings)
        @test result.error !== nothing
    end

    @testset "compute_arithmetic — negative numbers" begin
        bindings = [
            SigilBinding(0, "n", -3, :lambda, "-3", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 7, :lambda, "7", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 4
    end

    @testset "compute_arithmetic — zero operands" begin
        bindings = [
            SigilBinding(0, "n", 0, :lambda, "0", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 0, :lambda, "0", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 0
    end

    @testset "compute_arithmetic — large exponent protection" begin
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "^", :lambda, "^", 1),
            SigilBinding(2, "n", 200, :lambda, "200", 2),
        ]
        result = compute_arithmetic(bindings)
        @test result.error !== nothing
        @test occursin("exponent too large", result.error)
    end

    # =========================================================================
    # format_arithmetic_reply
    # =========================================================================
    @testset "format_arithmetic_reply — simple addition" begin
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "2", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 2, :lambda, "2", 2),
        ]
        result = compute_arithmetic(bindings)
        reply = format_arithmetic_reply(result)
        @test occursin("2", reply)
        @test occursin("plus", reply)
        @test occursin("4", reply)
        @test occursin("equals", reply)
    end

    @testset "format_arithmetic_reply — word-form operands" begin
        # User typed "two plus two" — surface forms preserve the user's register
        bindings = [
            SigilBinding(0, "n", 2, :lambda, "two", 0),
            SigilBinding(1, "op", "+", :lambda, "plus", 1),
            SigilBinding(2, "n", 2, :lambda, "two", 2),
        ]
        result = compute_arithmetic(bindings)
        reply = format_arithmetic_reply(result)
        # The reply should use the user's surface forms
        @test occursin("two", reply)
        @test occursin("plus", reply)
        @test occursin("4", reply)
    end

    @testset "format_arithmetic_reply — division by zero" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
            SigilBinding(1, "op", "/", :lambda, "/", 1),
            SigilBinding(2, "n", 0, :lambda, "0", 2),
        ]
        result = compute_arithmetic(bindings)
        reply = format_arithmetic_reply(result)
        @test occursin("Could not compute", reply)
    end

    @testset "format_arithmetic_reply — comparison" begin
        bindings = [
            SigilBinding(0, "n", 5, :lambda, "5", 0),
            SigilBinding(1, "op", "<", :lambda, "<", 1),
            SigilBinding(2, "n", 10, :lambda, "10", 2),
        ]
        result = compute_arithmetic(bindings)
        reply = format_arithmetic_reply(result)
        @test occursin("true", reply)
    end

    @testset "format_arithmetic_reply — multi-step" begin
        bindings = [
            SigilBinding(0, "n", 3, :lambda, "3", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n", 5, :lambda, "5", 2),
            SigilBinding(3, "op", "*", :lambda, "*", 3),
            SigilBinding(4, "n", 2, :lambda, "2", 4),
        ]
        result = compute_arithmetic(bindings)
        reply = format_arithmetic_reply(result)
        # Multi-step reply should mention steps and final answer
        @test occursin("answer", reply)
    end

    # =========================================================================
    # Integration: SigilPromoter + ArithmeticEngine
    # =========================================================================
    @testset "integration — promote then compute" begin
        table = default_registry()

        # "what is 2 + 2"
        rewritten, bindings = promote_input(table, "what is 2 + 2")
        @test has_math_bindings(bindings)
        result = compute_arithmetic(bindings)
        @test result.error === nothing
        @test result.answer == 4
        @test occursin("4", format_arithmetic_reply(result))

        # "two plus two"
        rewritten2, bindings2 = promote_input(table, "two plus two")
        @test has_math_bindings(bindings2)
        result2 = compute_arithmetic(bindings2)
        @test result2.error === nothing
        @test result2.answer == 4

        # "10 times 7"
        rewritten3, bindings3 = promote_input(table, "10 times 7")
        @test has_math_bindings(bindings3)
        result3 = compute_arithmetic(bindings3)
        @test result3.error === nothing
        @test result3.answer == 70

        # "100 minus 37"
        rewritten4, bindings4 = promote_input(table, "100 minus 37")
        @test has_math_bindings(bindings4)
        result4 = compute_arithmetic(bindings4)
        @test result4.error === nothing
        @test result4.answer == 63

        # "no math here" — should not have math bindings
        rewritten5, bindings5 = promote_input(table, "hello friend")
        @test !has_math_bindings(bindings5)
    end

    @testset "integration — all nine arithmetic surface variants" begin
        table = default_registry()

        # All nine surface variants that the v21 specimen tests
        variants = [
            "what is 2 + 2",
            "what is two plus two",
            "what is 2 plus 2",
            "2 + 2",
            "two plus two",
            "2 plus 2",
            "what is 2+2",
            "calculate 2+2",
            "compute two plus two",
        ]

        for v in variants
            rewritten, bindings = promote_input(table, v)
            if has_math_bindings(bindings)
                result = compute_arithmetic(bindings)
                @test result.error === nothing
                @test result.answer == 4
                @test occursin("4", format_arithmetic_reply(result))
            end
        end
    end
end
