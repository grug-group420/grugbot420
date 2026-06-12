using Test
using GrugBot420
using GrugBot420.VoteOrchestrator

# GRUG v7.23/v7.24 SPARSE-ACTIVE FIRE GATE
#
# v7.23: SPARSE_ACTIVE_FIRE_FLOOR set to 0.0 (disabled). Confidence is the
# ONLY gate now. No firing is blocked at the engine fire site. The lock-in
# floor (AIML_TOP_LOCKIN_FLOOR = 0.50) handles confidence gating at the
# AIML/VoteOrchestrator layer. At the engine fire site, everything fires.
#
# These tests verify the v7.23 disabled state.

@testset "SPARSE-ACTIVE FIRE GATE (v7.23: floor=0.0, disabled)" begin

    @testset "Constant is 0.0 (disabled)" begin
        @test SPARSE_ACTIVE_FIRE_FLOOR == 0.0
    end

    @testset "should_fire_sparse_active: everything passes with floor=0.0" begin
        # At-or-above 0.0: always fires.
        @test should_fire_sparse_active(0.0) == true
        @test should_fire_sparse_active(0.01) == true
        @test should_fire_sparse_active(0.10) == true
        @test should_fire_sparse_active(0.50) == true
        @test should_fire_sparse_active(1.0) == true
        @test should_fire_sparse_active(2.5) == true  # post-weighting can exceed 1
    end

    @testset "should_fire_sparse_active rejects NaN/Inf" begin
        @test should_fire_sparse_active(NaN) == false
        @test should_fire_sparse_active(Inf) == false
        @test should_fire_sparse_active(-Inf) == false
    end

    @testset "should_fire_sparse_active: negative finite values pass (floor=0.0)" begin
        # v7.23: With floor=0.0, the gate only rejects non-finite values.
        # Negative finite values pass because the gate is just isfinite().
        # Actual negative confidences shouldn't exist in the pipeline,
        # but if they do, they pass the sparse-active gate (the lock-in
        # floor at 0.50 in VoteOrchestrator will catch them instead).
        @test should_fire_sparse_active(-0.5) == true
        @test should_fire_sparse_active(-0.01) == true
    end

    @testset "Skip counter increments and resets" begin
        reset_sparse_active_skip_count!()
        @test get_sparse_active_skip_count() == 0

        tally_sparse_active_skip!()
        @test get_sparse_active_skip_count() == 1

        tally_sparse_active_skip!()
        tally_sparse_active_skip!()
        @test get_sparse_active_skip_count() == 3

        reset_sparse_active_skip_count!()
        @test get_sparse_active_skip_count() == 0
    end

    @testset "Skip counter is thread-safe" begin
        reset_sparse_active_skip_count!()
        n_threads = max(2, Threads.nthreads())
        n_per = 250
        Threads.@threads for _ in 1:(n_threads * n_per)
            tally_sparse_active_skip!()
        end
        @test get_sparse_active_skip_count() == n_threads * n_per
        reset_sparse_active_skip_count!()
    end

    @testset "Integer confidences accepted" begin
        @test should_fire_sparse_active(1) == true
        @test should_fire_sparse_active(0) == true   # v7.23: 0.0 floor, 0 passes
    end

end
