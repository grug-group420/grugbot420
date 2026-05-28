using Test
using GrugBot420
using GrugBot420.VoteOrchestrator

# GRUG v7.16.x SPARSE-ACTIVE FIRE GATE
#
# User directive: "a pattern bind below a high threshold shouldn't even fire
# really. its sparse active. shouldn't handle that from the aiml layer."
#
# These tests verify the sparse-active gate that lives in VoteOrchestrator
# and is called from the engine fire sites (scan_specimens fire_one and
# fire_attachments!). The AIML layer does NOT filter sub-threshold binds;
# the engine culls them at the fire site so they never claim a fire slot.

@testset "SPARSE-ACTIVE FIRE GATE" begin

    @testset "Constant is in legal range" begin
        # Must be above the relay hard floor (0.1) and below the AIML lock-in
        # floor (0.50) so it doesn't break either machinery.
        @test SPARSE_ACTIVE_FIRE_FLOOR > 0.1
        @test SPARSE_ACTIVE_FIRE_FLOOR < AIML_TOP_LOCKIN_FLOOR
        @test SPARSE_ACTIVE_FIRE_FLOOR == 0.20
    end

    @testset "should_fire_sparse_active threshold behavior" begin
        # At-or-above floor: fires.
        @test should_fire_sparse_active(SPARSE_ACTIVE_FIRE_FLOOR) == true
        @test should_fire_sparse_active(SPARSE_ACTIVE_FIRE_FLOOR + 0.01) == true
        @test should_fire_sparse_active(0.5) == true
        @test should_fire_sparse_active(1.0) == true
        @test should_fire_sparse_active(2.5) == true  # post-weighting can exceed 1

        # Below floor: culled.
        @test should_fire_sparse_active(SPARSE_ACTIVE_FIRE_FLOOR - 0.01) == false
        @test should_fire_sparse_active(0.10) == false
        @test should_fire_sparse_active(0.0) == false
        @test should_fire_sparse_active(-0.5) == false
    end

    @testset "should_fire_sparse_active rejects NaN/Inf" begin
        @test should_fire_sparse_active(NaN) == false
        @test should_fire_sparse_active(Inf) == false
        @test should_fire_sparse_active(-Inf) == false
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
        # Engine paths normally pass Float64 but the helper must accept any
        # Real (the union the engine itself uses for confidence math).
        @test should_fire_sparse_active(1) == true
        @test should_fire_sparse_active(0) == false
    end

    @testset "Floor is below relay max(0.1, ...) hard floor combined with jitter" begin
        # The relay path floors at 0.1, then sparse-active culls below 0.20.
        # An attachment whose base_confidence is, say, 0.05 with no jitter
        # would land at 0.10 (the hard floor) which is BELOW sparse-active
        # \u2014 so it gets culled. This is the intended behavior: the
        # "always have SOME voice" floor is overridden by the sparse-active
        # gate when the underlying signal is genuinely weak.
        floored_value = max(0.1, 0.05)  # mirrors engine.jl line ~1624
        @test floored_value == 0.1
        @test should_fire_sparse_active(floored_value) == false
    end

end
