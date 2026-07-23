# test_brainstem.jl - GRUG Comprehensive Tests for BrainStem.jl
# GRUG say: winner-take-all dispatcher needs hard testing.
# GRUG say: test dispatch, propagation, decay, fault isolation, tie-breaking, error paths.

if !isdefined(Main, :Lobe)
    include("Lobe.jl")
end
using .Lobe

if !isdefined(Main, :BrainStem)
    include("BrainStem.jl")
end
using .BrainStem

using Test

println("🧪 Running BrainStem.jl tests...")

# ============================================================================
# HELPERS - Build minimal DispatchResult mocks and a fake lobe registry
# ============================================================================

function _make_dispatch_result(lobe_id::String, confidence::Float64; silent::Bool = false)
    return BrainStem.DispatchResult(lobe_id, confidence, String[], "", silent)
end

function _make_fresh_registry(lobe_ids::Vector{String})
    # GRUG: Build a fresh Dict{String, Lobe.LobeRecord} for each test
    reg = Dict{String, Lobe.LobeRecord}()
    lk  = ReentrantLock()
    for lid in lobe_ids
        reg[lid] = Lobe.LobeRecord(
            lid, "subject_$lid",
            Set{String}(), Set{String}(),
            1000, 0, 0, time()
        )
    end
    return reg, lk
end

# GRUG: Mock lobe_scan_fn factory - returns a configurable result per lobe
function _make_scan_fn(results::Dict{String, BrainStem.DispatchResult})
    return function(lid::String, _input::String)
        if haskey(results, lid)
            return results[lid]
        end
        # GRUG: Lobe not in results = silent
        return BrainStem.DispatchResult(lid, 0.0, String[], "", true)
    end
end

# ============================================================================
# RESET BRAINSTEM STATE between tests
# ============================================================================
function _reset_brainstem!()
    lock(BrainStem.BRAINSTEM_LOCK) do
        BrainStem.BRAINSTEM_STATE.dispatch_count      = 0
        BrainStem.BRAINSTEM_STATE.last_winner_id      = ""
        BrainStem.BRAINSTEM_STATE.last_dispatch_t     = 0.0
        BrainStem.BRAINSTEM_STATE.is_dispatching      = false
        empty!(BrainStem.BRAINSTEM_STATE.propagation_history)
    end
end

function _clear_lobe_registry!()
    lock(Lobe.LOBE_LOCK) do
        empty!(Lobe.LOBE_REGISTRY)
        empty!(Lobe.NODE_TO_LOBE_IDX)
    end
end

@testset "BrainStem.jl - Full Test Suite" begin

    # ========================================================================
    # SECTION 1: Basic dispatch - winner selection
    # ========================================================================
    @testset "dispatch! selects highest confidence winner" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["A", "B", "C"])

        scan_results = Dict(
            "A" => _make_dispatch_result("A", 0.9),
            "B" => _make_dispatch_result("B", 0.5),
            "C" => _make_dispatch_result("C", 0.3),
        )

        result = BrainStem.dispatch!("test input", ["A","B","C"], _make_scan_fn(scan_results), reg, lk)
        @test result.lobe_id    == "A"
        @test result.confidence == 0.9
        @test !result.silent
    end

    @testset "dispatch! increments winner fire_count" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["W", "L"])

        scan_results = Dict(
            "W" => _make_dispatch_result("W", 1.0),
            "L" => _make_dispatch_result("L", 0.2),
        )

        BrainStem.dispatch!("input", ["W","L"], _make_scan_fn(scan_results), reg, lk)
        @test reg["W"].fire_count    == 1
        @test reg["W"].inhibit_count == 0
    end

    @testset "dispatch! increments loser inhibit_count" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["W", "L1", "L2"])

        scan_results = Dict(
            "W"  => _make_dispatch_result("W",  1.0),
            "L1" => _make_dispatch_result("L1", 0.3),
            "L2" => _make_dispatch_result("L2", 0.1),
        )

        BrainStem.dispatch!("input", ["W","L1","L2"], _make_scan_fn(scan_results), reg, lk)
        @test reg["L1"].inhibit_count == 1
        @test reg["L2"].inhibit_count == 1
        @test reg["W"].inhibit_count  == 0
    end

    @testset "dispatch! silent lobes also get inhibited" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["W", "SILENT"])

        scan_results = Dict(
            "W" => _make_dispatch_result("W", 0.8),
            # GRUG: SILENT not in results -> scan_fn returns silent result
        )

        BrainStem.dispatch!("input", ["W","SILENT"], _make_scan_fn(scan_results), reg, lk)
        @test reg["SILENT"].inhibit_count == 1
    end

    # ========================================================================
    # SECTION 2: All-silent dispatch
    # ========================================================================
    @testset "dispatch! returns silent result when all lobes silent" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["A", "B"])

        # GRUG: All lobes return silent
        scan_results = Dict{String, BrainStem.DispatchResult}()

        result = BrainStem.dispatch!("input", ["A","B"], _make_scan_fn(scan_results), reg, lk)
        @test result.silent
        @test result.lobe_id == ""
        @test result.confidence == 0.0
    end

    # ========================================================================
    # SECTION 3: Tie-breaking by fire_count (fairness)
    # ========================================================================
    @testset "dispatch! tie-break: lower fire_count wins" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["HIGH_FIRES", "LOW_FIRES"])

        # GRUG: Give HIGH_FIRES a big fire count already
        reg["HIGH_FIRES"].fire_count = 100
        reg["LOW_FIRES"].fire_count  = 1

        # GRUG: Equal confidence -> should pick LOW_FIRES (fewer fires = fairer)
        scan_results = Dict(
            "HIGH_FIRES" => _make_dispatch_result("HIGH_FIRES", 0.7),
            "LOW_FIRES"  => _make_dispatch_result("LOW_FIRES",  0.7),
        )

        result = BrainStem.dispatch!("input", ["HIGH_FIRES","LOW_FIRES"], _make_scan_fn(scan_results), reg, lk)
        @test result.lobe_id == "LOW_FIRES"
    end

    # ========================================================================
    # SECTION 4: Fire count decay
    # ========================================================================
    @testset "apply_fire_count_decay! reduces counts by decay factor" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["A", "B"])
        reg["A"].fire_count = 100
        reg["B"].fire_count = 50

        BrainStem.apply_fire_count_decay!(reg, lk)

        expected_a = floor(Int, 100 * BrainStem.FIRE_COUNT_DECAY_FACTOR)
        expected_b = floor(Int, 50  * BrainStem.FIRE_COUNT_DECAY_FACTOR)
        @test reg["A"].fire_count == expected_a
        @test reg["B"].fire_count == expected_b
    end

    @testset "apply_fire_count_decay! floors at 0" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["Z"])
        reg["Z"].fire_count = 0

        BrainStem.apply_fire_count_decay!(reg, lk)
        @test reg["Z"].fire_count == 0
    end

    @testset "dispatch! triggers decay at FIRE_COUNT_DECAY_INTERVAL" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["W"])
        reg["W"].fire_count = 1000  # GRUG: Big fire count

        scan_results = Dict("W" => _make_dispatch_result("W", 0.5))
        scan_fn = _make_scan_fn(scan_results)

        # GRUG: Reset dispatch count to just before decay threshold
        lock(BrainStem.BRAINSTEM_LOCK) do
            BrainStem.BRAINSTEM_STATE.dispatch_count = BrainStem.FIRE_COUNT_DECAY_INTERVAL - 1
        end

        # GRUG: This dispatch pushes count to exactly FIRE_COUNT_DECAY_INTERVAL -> decay fires
        BrainStem.dispatch!("input", ["W"], scan_fn, reg, lk)
        # GRUG: fire_count was 1000, after dispatch it got +1 from fire_lobe!, then decay
        # The order is: count incremented first, decay fires if divisible, then fire_lobe!
        # So 1000 (pre-decay) -> floor(1000 * 0.85) = 850, then fire_lobe! adds 1 = 851
        @test reg["W"].fire_count < 1000  # GRUG: Must be lower than start
    end

    # ========================================================================
    # SECTION 5: Signal propagation
    # ========================================================================
    @testset "propagate_signal! populates propagation history" begin
        _reset_brainstem!()
        _clear_lobe_registry!()

        Lobe.create_lobe!("SRC", "source lobe")
        Lobe.create_lobe!("TGT", "target lobe")
        Lobe.connect_lobes!("SRC", "TGT")

        # GRUG: Run dispatch with connected lobes
        reg = Lobe.LOBE_REGISTRY
        lk  = Lobe.LOBE_LOCK

        scan_results = Dict("SRC" => _make_dispatch_result("SRC", 1.0))
        BrainStem.dispatch!("input", ["SRC","TGT"], _make_scan_fn(scan_results), reg, lk)

        history = BrainStem.get_propagation_history(10)
        @test length(history) >= 1
        @test history[end].source_lobe_id == "SRC"
        @test history[end].target_lobe_id == "TGT"
        @test history[end].confidence     == 1.0 * BrainStem.PROPAGATION_DECAY
    end

    @testset "propagate_signal! decays confidence by PROPAGATION_DECAY" begin
        _reset_brainstem!()
        _clear_lobe_registry!()

        Lobe.create_lobe!("W", "winner")
        Lobe.create_lobe!("N", "neighbor")
        Lobe.connect_lobes!("W", "N")

        winner_conf = 0.8
        records = BrainStem.propagate_signal!("W", winner_conf, Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)

        @test length(records) == 1
        @test isapprox(records[1].confidence, winner_conf * BrainStem.PROPAGATION_DECAY, atol=1e-9)
    end

    @testset "propagate_signal! skips below PROPAGATION_MIN_CONFIDENCE" begin
        _reset_brainstem!()
        _clear_lobe_registry!()

        Lobe.create_lobe!("W", "winner")
        Lobe.create_lobe!("N", "neighbor")
        Lobe.connect_lobes!("W", "N")

        # GRUG: Confidence so low that after decay it's below min threshold
        # PROPAGATION_MIN_CONFIDENCE = 0.1, PROPAGATION_DECAY = 0.6
        # 0.1 * 0.6 = 0.06 < 0.1 -> should skip
        tiny_conf = BrainStem.PROPAGATION_MIN_CONFIDENCE / BrainStem.PROPAGATION_DECAY * 0.5
        records = BrainStem.propagate_signal!("W", tiny_conf, Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
        @test isempty(records)
    end

    @testset "propagate_signal! no-op when winner has no connections" begin
        _reset_brainstem!()
        _clear_lobe_registry!()

        Lobe.create_lobe!("LONE", "lonely lobe")
        records = BrainStem.propagate_signal!("LONE", 1.0, Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
        @test isempty(records)
    end

    @testset "propagate_signal! empty winner id throws" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["X"])
        @test_throws BrainStem.BrainStemError BrainStem.propagate_signal!("", 1.0, reg, lk)
    end

    @testset "propagation_history capped at 100 entries" begin
        _reset_brainstem!()
        _clear_lobe_registry!()

        Lobe.create_lobe!("SRC2", "source")
        Lobe.create_lobe!("TGT2", "target")
        Lobe.connect_lobes!("SRC2", "TGT2")

        # GRUG: Flood the propagation history with >100 entries
        for _ in 1:110
            BrainStem.propagate_signal!("SRC2", 1.0, Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
        end

        history = BrainStem.get_propagation_history(200)
        @test length(history) <= 100
    end

    # ========================================================================
    # SECTION 6: Fault isolation
    # ========================================================================
    @testset "dispatch! fault isolation: bad lobe doesn't abort dispatch" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["GOOD", "BAD"])

        bad_fired = false
        good_result = _make_dispatch_result("GOOD", 0.7)

        scan_fn = function(lid::String, _input::String)
            if lid == "BAD"
                error("!!! SIMULATED LOBE EXPLOSION !!!")
            end
            return good_result
        end

        # GRUG: BAD lobe throws, but GOOD lobe should still win
        result = BrainStem.dispatch!("input", ["GOOD","BAD"], scan_fn, reg, lk)
        @test result.lobe_id == "GOOD"
        @test !result.silent
    end

    # ========================================================================
    # SECTION 7: Error paths
    # ========================================================================
    @testset "dispatch! empty input throws" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["A"])
        scan_fn = _make_scan_fn(Dict{String, BrainStem.DispatchResult}())
        @test_throws BrainStem.BrainStemError BrainStem.dispatch!("", ["A"], scan_fn, reg, lk)
    end

    @testset "dispatch! empty lobe list throws" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(String[])
        scan_fn = _make_scan_fn(Dict{String, BrainStem.DispatchResult}())
        @test_throws BrainStem.BrainStemError BrainStem.dispatch!("input", String[], scan_fn, reg, lk)
    end

    @testset "get_propagation_history n<=0 throws" begin
        _reset_brainstem!()
        @test_throws BrainStem.BrainStemError BrainStem.get_propagation_history(0)
        @test_throws BrainStem.BrainStemError BrainStem.get_propagation_history(-1)
    end

    # ========================================================================
    # SECTION 8: get_brainstem_status
    # ========================================================================
    @testset "get_brainstem_status returns correct fields" begin
        _reset_brainstem!()
        reg, lk = _make_fresh_registry(["A"])
        scan_results = Dict("A" => _make_dispatch_result("A", 0.5))

        BrainStem.dispatch!("hello", ["A"], _make_scan_fn(scan_results), reg, lk)

        status = BrainStem.get_brainstem_status()
        @test status["dispatch_count"]  == 1
        @test status["last_winner_id"]  == "A"
        @test status["is_dispatching"]  == false
        @test haskey(status, "propagation_events")
        @test haskey(status, "propagation_decay")
        @test haskey(status, "decay_interval")
    end

    # ========================================================================
    # CLEANUP
    # ========================================================================
    _reset_brainstem!()
    _clear_lobe_registry!()

end # @testset

println("✅ BrainStem.jl tests complete.")