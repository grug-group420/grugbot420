# test_crystalize_tag.jl
# ==============================================================================
# GRUG v7.15 TESTS --- CrystalizeTag: user + auto, hysteresis release,
#                       thread-safe set operations, auto-revoke
# ==============================================================================

using Test

include("../src/CrystalizeTag.jl")
using .CrystalizeTag

println("\n" * "=" ^ 60)
println("GRUG v7.15 CrystalizeTag TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] USER-TAGGED --- mark + query + clear
# ==============================================================================
@testset "user crystalize: mark + query + clear" begin
    clear_all_crystalized!()

    mark_user_crystalized!("n_strong_1")
    @test is_crystalized("n_strong_1") == true
    @test is_auto_crystalized("n_strong_1") == false
    @test "n_strong_1" in list_crystalized()

    # GRUG: Idempotent re-mark.
    mark_user_crystalized!("n_strong_1")
    @test crystalized_count() == 1  # still just one

    # GRUG: Clear.
    uncrystalize!("n_strong_1")
    @test is_crystalized("n_strong_1") == false
    @test crystalized_count() == 0
end

# ==============================================================================
# [2] AUTO-TAGGED --- separate set, fire-path still says crystalized
# ==============================================================================
@testset "auto crystalize: independent set, same fire effect" begin
    clear_all_crystalized!()

    mark_auto_crystalized!("n_auto_1")
    @test is_crystalized("n_auto_1") == true
    @test is_auto_crystalized("n_auto_1") == true

    # GRUG: uncrystalize! by default clears both. Use auto=false to spare user tags.
    mark_user_crystalized!("n_both")
    mark_auto_crystalized!("n_both")
    uncrystalize!("n_both"; user = false, auto = true)
    @test is_crystalized("n_both") == true       # user tag survives
    @test is_auto_crystalized("n_both") == false # auto was cleared
end

# ==============================================================================
# [3] AUTO GATE --- promote / maintain / release decisions
# ==============================================================================
@testset "should_auto_crystalize: promote / hysteresis / release" begin
    # GRUG: Promote: both floors cleared.
    @test should_auto_crystalize(8.0, 0.80; already_auto = false) == true
    @test should_auto_crystalize(AUTO_STRENGTH_FLOOR, AUTO_SEMANTIC_FLOOR;
                                  already_auto = false) == true

    # GRUG: Don't promote: strength too low.
    @test should_auto_crystalize(7.0, 0.90; already_auto = false) == false

    # GRUG: Don't promote: semantic truth too low.
    @test should_auto_crystalize(9.0, 0.50; already_auto = false) == false

    # GRUG: Hysteresis: already auto, strength dropped into release-floor band,
    # semantic still above floor. Should STAY crystalized.
    @test should_auto_crystalize(
        AUTO_STRENGTH_RELEASE_FLOOR, AUTO_SEMANTIC_FLOOR;
        already_auto = true,
    ) == true

    # GRUG: Hysteresis does NOT save you if semantic drops.
    @test should_auto_crystalize(
        AUTO_STRENGTH_RELEASE_FLOOR, 0.50;
        already_auto = true,
    ) == false

    # GRUG: Below release floor -> always release regardless of history.
    @test should_auto_crystalize(
        AUTO_STRENGTH_RELEASE_FLOOR - 0.5, 0.90;
        already_auto = true,
    ) == false
end

# ==============================================================================
# [4] AUTO GATE --- bad inputs throw loudly
# ==============================================================================
@testset "should_auto_crystalize: NaN/Inf rejected" begin
    @test_throws CrystalizeError should_auto_crystalize(NaN, 0.8)
    @test_throws CrystalizeError should_auto_crystalize(8.0, NaN)
    @test_throws CrystalizeError should_auto_crystalize(Inf, 0.8)
    @test_throws CrystalizeError should_auto_crystalize(8.0, Inf)
end

# ==============================================================================
# [5] EMPTY IDS --- every public mutator rejects empty ids
# ==============================================================================
@testset "empty id rejection across API" begin
    @test_throws CrystalizeError mark_user_crystalized!("")
    @test_throws CrystalizeError mark_auto_crystalized!("")
    @test_throws CrystalizeError uncrystalize!("")
    @test_throws CrystalizeError is_crystalized("")
    @test_throws CrystalizeError is_auto_crystalized("")
end

# ==============================================================================
# [6] LIST --- sorted + deduped across user/auto sets
# ==============================================================================
@testset "list_crystalized: sorted + deduped" begin
    clear_all_crystalized!()
    mark_user_crystalized!("zebra")
    mark_user_crystalized!("alpha")
    mark_auto_crystalized!("alpha")     # overlap
    mark_auto_crystalized!("mango")

    lst = list_crystalized()
    @test lst == ["alpha", "mango", "zebra"]
    @test length(lst) == 3  # alpha deduped
end

# ==============================================================================
# [7] UNCRYSTALIZE --- on unknown node is no-op, not error
# ==============================================================================
@testset "uncrystalize! unknown node = no-op" begin
    clear_all_crystalized!()
    # GRUG: Silent no-op is the CORRECT behavior here --- operator may clear
    # a node that was never tagged. This is NOT a silent failure (there was
    # nothing to fail on).
    uncrystalize!("never_tagged")
    @test is_crystalized("never_tagged") == false
end

println("\n" * "=" ^ 60)
println("\u2705  CrystalizeTag tests COMPLETE")
println("=" ^ 60)
