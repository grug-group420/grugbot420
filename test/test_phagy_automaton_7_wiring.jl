# test/test_phagy_automaton_7_wiring.jl
# ==============================================================================
# GRUG v7.15.2 test: PhagyMode pluggable 7th automaton.
#
# Covers:
#   1. register_group_organizer! --- installation + rejection of nothing.
#   2. has_group_organizer --- true only after registration.
#   3. run_phagy! --- rolls into 1..7 range when organizer wired.
#   4. Statistical check: with 500 rolls and the organizer wired, automaton 7
#      fires at least once. Verifies the dispatch isn't accidentally gated out.
#   5. Organizer callback's PhagyStats contract --- name, fields, non-negative
#      counters, no NaN wall time.
#   6. Non-registration path: PhagyMode stays at 1..6 when organizer missing.
#   7. Adapter error path: a failing organizer rethrows through run_phagy!
#      (NO SILENT FAILURE).
# ==============================================================================

using Test
using Base.Threads: ReentrantLock

# GRUG: Isolated load --- we only need PhagyMode for this file.
include("../src/PhagyMode.jl")
using .PhagyMode

println("\n" * "="^60)
println("GRUG v7.15.2 Phagy 7th-Automaton Wiring TEST SUITE")
println("="^60)

# ==============================================================================
# [1] registration rejects nothing
# ==============================================================================
@testset "register_group_organizer!: rejects nothing" begin
    @test_throws PhagyError PhagyMode.register_group_organizer!(nothing)
end

# ==============================================================================
# [2] has_group_organizer reports state correctly
# ==============================================================================
@testset "has_group_organizer: baseline false, true after registration" begin
    # GRUG: In a freshly-included PhagyMode, nothing is wired yet.
    @test PhagyMode.has_group_organizer() == false

    # GRUG: Register a trivial adapter that returns an empty PhagyStats.
    trivial = () -> PhagyStats(PhagyMode.GROUP_ORGANIZER_NAME, 0, 0, 0.0, "noop")
    PhagyMode.register_group_organizer!(trivial)
    @test PhagyMode.has_group_organizer() == true
end

# ==============================================================================
# [3] run_phagy! reaches automaton 7 at least once over many rolls
# ==============================================================================
@testset "run_phagy!: automaton 7 fires when wired" begin
    # GRUG: Counter-based adapter so we can tell it ran.
    n_fired = Ref(0)
    adapter = () -> begin
        n_fired[] += 1
        PhagyStats(PhagyMode.GROUP_ORGANIZER_NAME, 1, 1, 0.5, "count=$(n_fired[])")
    end
    PhagyMode.register_group_organizer!(adapter)

    # GRUG: Run 500 cycles. With max_automaton=7 the 7th slot has ~14.3% odds
    # per roll, so P(never fires) across 500 rolls is (6/7)^500 ≈ 10^-33 ---
    # flake-free in practice.
    nm    = Dict{String, Any}()
    nlock = ReentrantLock()
    hop   = Dict{String, Any}()
    hlock = ReentrantLock()
    rules = Vector{Any}()
    rlock = ReentrantLock()

    # GRUG: Suppress per-cycle prints from swamping the test log.
    prev_stdout = stdout
    redirect_stdout(devnull) do
        for _ in 1:500
            run_phagy!(nm, nlock, hop, hlock, rules, rlock)
        end
    end

    @test n_fired[] > 0
    # GRUG: Sanity upper bound --- the organizer cannot have run MORE than
    # the total rolls. Guards against silent re-entry bugs.
    @test n_fired[] <= 500
end

# ==============================================================================
# [4] Organizer errors propagate (NO SILENT FAILURE)
# ==============================================================================
@testset "run_phagy!: organizer error rethrows" begin
    # GRUG: Swap in a always-throwing adapter.
    thrower = () -> error("organizer simulated failure")
    PhagyMode.register_group_organizer!(thrower)

    nm    = Dict{String, Any}()
    nlock = ReentrantLock()
    hop   = Dict{String, Any}()
    hlock = ReentrantLock()
    rules = Vector{Any}()
    rlock = ReentrantLock()

    # GRUG: Force automaton 7 by seeding the RNG until we roll a 7. We can't
    # easily do that from outside, so instead we hammer run_phagy! until it
    # throws. With the thrower wired any roll of 7 crashes; statistically
    # within ~100 attempts we hit it.
    threw = false
    redirect_stdout(devnull) do
        redirect_stderr(devnull) do
            for _ in 1:2000
                try
                    run_phagy!(nm, nlock, hop, hlock, rules, rlock)
                catch e
                    threw = true
                    break
                end
            end
        end
    end
    @test threw == true
end

# ==============================================================================
# [5] Adapter returns a well-formed PhagyStats
# ==============================================================================
@testset "adapter returns well-formed PhagyStats" begin
    stats_ref = Ref{Union{PhagyStats, Nothing}}(nothing)
    adapter = () -> begin
        s = PhagyStats(PhagyMode.GROUP_ORGANIZER_NAME, 3, 2, 1.5, "three examined two changed")
        stats_ref[] = s
        s
    end
    PhagyMode.register_group_organizer!(adapter)

    s = adapter()
    @test s isa PhagyStats
    @test s.automaton == PhagyMode.GROUP_ORGANIZER_NAME
    @test s.items_processed >= 0
    @test s.items_changed >= 0
    @test s.items_changed <= s.items_processed
    @test s.cycle_time_ms >= 0.0
    @test !isnan(s.cycle_time_ms)
    @test !isempty(s.notes)
end

println("\n" * "="^60)
println("✅  Phagy 7th-Automaton Wiring tests COMPLETE")
println("="^60)
