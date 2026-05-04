# test_vote_orchestrator.jl
# ==============================================================================
# GRUG: Tests for the Vote Orchestrator architecture.
#   - Unique non-colliding Task dispatch
#   - FireCounter hard-cap atomic enforcement across parallel threads
#   - Parallel batched fire with shared counter
#   - DONE signalling channel with timeout
#   - AIML vote selection (threshold + top-tier direct + sub-top coinflip)
# Tests run in order. Any failure throws loudly. NO SILENT FAILURES.
# ==============================================================================

using Test
using Base.Threads: nthreads
using Random

include("../src/VoteOrchestrator.jl")
using .VoteOrchestrator

println("\n" * "="^60)
println("GRUG VOTE ORCHESTRATOR TEST SUITE")
println("  nthreads = $(nthreads())")
println("="^60)

# ==============================================================================
# [1] TASK DISPATCHER - unique non-colliding Task names
# ==============================================================================

@testset "[1] Task Dispatcher — unique non-colliding names" begin
    # GRUG: 10000 rapid-fire task names must all be distinct.
    names = Set{String}()
    for _ in 1:10000
        push!(names, VoteOrchestrator.next_task_id("stress"))
    end
    @test length(names) == 10000

    # GRUG: Different prefixes must produce different namespaces.
    a = VoteOrchestrator.next_task_id("alpha")
    b = VoteOrchestrator.next_task_id("beta")
    @test startswith(a, "alpha#")
    @test startswith(b, "beta#")
    @test a != b

    # GRUG: Empty prefix rejected loudly.
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.next_task_id("")
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.next_task_id("   ")
end

# ==============================================================================
# [2] dispatch_task - runs closure in unique Task, surfaces errors
# ==============================================================================

@testset "[2] dispatch_task — Task execution and error surfacing" begin
    # GRUG: Happy path — returns value through fetch.
    name, t = VoteOrchestrator.dispatch_task(() -> 42, "happy"; context = "test_2a")
    @test startswith(name, "happy#")
    @test fetch(t) == 42

    # GRUG: Errors inside Task must be rethrown on fetch, not swallowed.
    _, bad_t = VoteOrchestrator.dispatch_task(
        () -> error("boom"),
        "sad";
        context = "test_2b"
    )
    @test_throws TaskFailedException fetch(bad_t)

    # GRUG: Lots of tasks, all unique names, all finish.
    tasks = Tuple{String, Task}[]
    for i in 1:200
        push!(tasks, VoteOrchestrator.dispatch_task(() -> i * 2, "bulk"; context = "test_2c"))
    end
    task_names = Set(n for (n, _) in tasks)
    @test length(task_names) == 200
    results = [fetch(t) for (_, t) in tasks]
    @test sort(results) == collect(2:2:400)
end

# ==============================================================================
# [3] FireCounter - atomic hard-cap enforcement
# ==============================================================================

@testset "[3] FireCounter — atomic hard-cap enforcement" begin
    # GRUG: Basic claim/reject flow.
    fc = VoteOrchestrator.FireCounter("unit3a", 5)
    for _ in 1:5
        @test VoteOrchestrator.try_claim_fire_slot!(fc) == true
    end
    # GRUG: Over cap — refuse every further claim.
    for _ in 1:10
        @test VoteOrchestrator.try_claim_fire_slot!(fc) == false
    end
    @test VoteOrchestrator.current_fire_count(fc) == 5
    @test VoteOrchestrator.fire_cap_reached(fc)

    # GRUG: Zero cap rejected on construction.
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.FireCounter("x", 0)
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.FireCounter("x", -1)
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.FireCounter("", 10)
end

@testset "[4] FireCounter — concurrent atomic contention" begin
    # GRUG: 16 Tasks each try to claim 200 slots on a 500-cap counter.
    # Exactly 500 total claims should succeed. Atomicity guarantees no over-claim.
    fc = VoteOrchestrator.FireCounter("unit4", 500)
    task_list = Task[]
    results_refs = [Ref(0) for _ in 1:16]
    for i in 1:16
        push!(task_list, Threads.@spawn begin
            local_count = 0
            for _ in 1:200
                if VoteOrchestrator.try_claim_fire_slot!(fc)
                    local_count += 1
                end
            end
            results_refs[i][] = local_count
        end)
    end
    for t in task_list
        wait(t)
    end
    total = sum(r[] for r in results_refs)
    @test total == 500
    @test VoteOrchestrator.current_fire_count(fc) == 500
end

# ==============================================================================
# [5] parallel_fire_batches - respects cap across parallel Tasks
# ==============================================================================

@testset "[5] parallel_fire_batches — cap respected across batches" begin
    fc = VoteOrchestrator.FireCounter("unit5", 100)
    ids = ["id$i" for i in 1:1000]
    results = VoteOrchestrator.parallel_fire_batches(
        ids, fc,
        (nid, counter) -> VoteOrchestrator.try_claim_fire_slot!(counter) ? nid : nothing;
        batch_size = 32
    )
    @test length(results) == 100
    @test VoteOrchestrator.current_fire_count(fc) == 100
    # GRUG: No duplicate ids (each chunk only processes its own ids).
    @test length(unique(results)) == 100
end

@testset "[6] parallel_fire_batches — error surfaces through fetch" begin
    fc = VoteOrchestrator.FireCounter("unit6", 1000)
    ids = ["id$i" for i in 1:100]
    # GRUG: fire_one that throws at id10. Some batches will hit it, others not.
    # The failing batch should re-raise via VoteOrchestratorError.
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.parallel_fire_batches(
        ids, fc,
        (nid, counter) -> begin
            if nid == "id10"
                error("synthetic explosion")
            end
            VoteOrchestrator.try_claim_fire_slot!(counter) ? nid : nothing
        end;
        batch_size = 16
    )
end

# ==============================================================================
# [7] DoneSignal channel - basic put/take
# ==============================================================================

@testset "[7] DoneSignal channel — put, take, collect" begin
    ch = VoteOrchestrator.make_done_channel(4)
    # GRUG: Three lobes finish, one never fires.
    VoteOrchestrator.send_done!(ch, VoteOrchestrator.DoneSignal("lobeA", 10, 8, 0.1, nothing))
    VoteOrchestrator.send_done!(ch, VoteOrchestrator.DoneSignal("lobeB", 5, 4, 0.05, nothing))
    VoteOrchestrator.send_done!(ch, VoteOrchestrator.DoneSignal("lobeC", 12, 10, 0.08, nothing))

    collected = VoteOrchestrator.wait_for_done(ch, 3; timeout_s = 2.0)
    @test length(collected) == 3
    @test Set(s.lobe_id for s in collected) == Set(["lobeA", "lobeB", "lobeC"])
    @test sum(s.fires_count for s in collected) == 27
end

@testset "[8] DoneSignal channel — timeout on missing DONE" begin
    ch = VoteOrchestrator.make_done_channel(4)
    VoteOrchestrator.send_done!(ch, VoteOrchestrator.DoneSignal("lobeX", 1, 1, 0.01, nothing))
    # GRUG: Expect 2 signals, only 1 arrives — must time out with error.
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.wait_for_done(ch, 2; timeout_s = 0.5)
end

# ==============================================================================
# [9] AIML vote selection - threshold filter
# ==============================================================================

@testset "[9] select_aiml_votes — threshold filter" begin
    # GRUG: All below threshold -> top + subtop empty, all rejected.
    cands = [
        VoteOrchestrator.VoteCandidate("a", 0.05, 5.0),
        VoteOrchestrator.VoteCandidate("b", 0.10, 5.0),
        VoteOrchestrator.VoteCandidate("c", 0.12, 5.0),
    ]
    top, subtop, rej = VoteOrchestrator.select_aiml_votes(cands; threshold = 0.15)
    @test isempty(top)
    @test isempty(subtop)
    @test length(rej) == 3
end

@testset "[10] select_aiml_votes — top tier always included" begin
    # GRUG: Two candidates within top_window of max -> both in top tier.
    cands = [
        VoteOrchestrator.VoteCandidate("top1", 0.90, 5.0),
        VoteOrchestrator.VoteCandidate("top2", 0.88, 5.0),  # within 0.05 of 0.90
        VoteOrchestrator.VoteCandidate("sub1", 0.50, 5.0),  # below top_window
    ]
    top, subtop, rej = VoteOrchestrator.select_aiml_votes(cands; threshold = 0.15, top_window = 0.05)
    top_ids = Set(vc.node_id for vc in top)
    @test top_ids == Set(["top1", "top2"])
    # GRUG: sub1 is above threshold so it lands in subtop (may be kept or rejected by coinflip).
    all_ids = Set(vc.node_id for vc in vcat(top, subtop, rej))
    @test all_ids == Set(["top1", "top2", "sub1"])
end

@testset "[11] select_aiml_votes — sub-top coinflip strength bias" begin
    # GRUG: Repeat many times. Strong sub-top should survive more often than weak.
    strong_kept = 0
    weak_kept   = 0
    trials = 2000
    for _ in 1:trials
        cands = [
            VoteOrchestrator.VoteCandidate("top",     1.00, 10.0),
            VoteOrchestrator.VoteCandidate("strong",  0.50, 10.0),  # max strength
            VoteOrchestrator.VoteCandidate("weak",    0.50,  0.5),  # near floor
        ]
        _, subtop, _ = VoteOrchestrator.select_aiml_votes(cands; threshold = 0.15, top_window = 0.05)
        kept_ids = Set(vc.node_id for vc in subtop)
        "strong" in kept_ids && (strong_kept += 1)
        "weak"   in kept_ids && (weak_kept += 1)
    end
    println("  strong kept = $strong_kept / $trials, weak kept = $weak_kept / $trials")
    # GRUG: Strong neuron wins the bias. Expect strong kept rate noticeably above weak.
    @test strong_kept > weak_kept
    # GRUG: Strong should be kept ~90% (base 0.20 + bonus 0.70 * 1.0 = 0.90).
    # Tolerance band chosen conservatively for 2000 trials.
    @test strong_kept > 1600   # roughly >= 80% empirical rate
    # GRUG: Weak near-floor should be kept ~23% (base 0.20 + bonus 0.70 * 0.05 = 0.235).
    @test weak_kept < 600      # roughly <= 30% empirical rate
end

@testset "[12] select_aiml_votes — input validation" begin
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.select_aiml_votes(
        VoteOrchestrator.VoteCandidate[]
    )
    # GRUG: Negative threshold rejected.
    cands = [VoteOrchestrator.VoteCandidate("a", 0.5, 5.0)]
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.select_aiml_votes(
        cands; threshold = -0.1
    )
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.select_aiml_votes(
        cands; top_window = -0.1
    )
end

# ==============================================================================
# [13] VoteCandidate validation
# ==============================================================================

@testset "[13] VoteCandidate — input validation" begin
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.VoteCandidate("", 0.5, 5.0)
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.VoteCandidate("x", 0.5, 5.0; strength_cap = 0.0)
end

# ==============================================================================
# [14] Integration: parallel_fire_batches + FireCounter + select_aiml_votes
# ==============================================================================

@testset "[14] End-to-end: fire 1000 nodes, cap enforced, threshold selection" begin
    fc = VoteOrchestrator.FireCounter("e2e", 1000)
    ids = ["node$i" for i in 1:5000]  # 5000 candidates but cap is 1000
    # GRUG: Simulate fire_one that produces (id, confidence, strength).
    results = VoteOrchestrator.parallel_fire_batches(
        ids, fc,
        (nid, counter) -> begin
            if !VoteOrchestrator.try_claim_fire_slot!(counter)
                return nothing
            end
            # Deterministic confidence/strength from id for repeatability.
            n = parse(Int, nid[5:end])
            conf   = 0.1 + (n % 100) / 100.0        # 0.10 .. 1.09
            stren  = Float64((n % 10) + 1)           # 1.0 .. 10.0
            return (nid, conf, stren)
        end;
        batch_size = 64
    )
    @test length(results) == 1000
    @test VoteOrchestrator.current_fire_count(fc) == 1000

    # GRUG: Convert to VoteCandidates, run AIML selection.
    candidates = [VoteOrchestrator.VoteCandidate(r[1], r[2], r[3]) for r in results]
    top, subtop, rej = VoteOrchestrator.select_aiml_votes(candidates)
    @test !isempty(top)
    @test length(top) + length(subtop) + length(rej) == 1000
    # GRUG: Every retained vote must be >= threshold.
    for vc in vcat(top, subtop)
        @test vc.confidence >= VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD
    end
    println("  e2e: top=$(length(top)) subtop=$(length(subtop)) rejected=$(length(rej))")
end

# ==============================================================================
# [15] TIMEOUT-BOUNDED TASK DISPATCH
# ==============================================================================

@testset "[15A] dispatch_task with timeout — fast task returns value" begin
    # GRUG: Task finishes well before timeout.
    name, t = VoteOrchestrator.dispatch_task(
        () -> (sleep(0.01); 123),
        "fast_timeout";
        timeout_s = 1.0,
        context = "test_15A"
    )
    @test VoteOrchestrator.fetch_with_timeout(name, t) == 123
end

@testset "[15B] dispatch_task with timeout — slow task throws TaskTimeoutError" begin
    # GRUG: Task exceeds timeout — TaskTimeoutError must fire.
    name, t = VoteOrchestrator.dispatch_task(
        () -> (sleep(2.0); :never),
        "slow_timeout";
        timeout_s = 0.2,
        context = "test_15B"
    )
    @test_throws VoteOrchestrator.TaskTimeoutError VoteOrchestrator.fetch_with_timeout(name, t)
end

@testset "[15C] dispatch_task with timeout — internal error still propagates" begin
    # GRUG: If Task throws before timeout, original error surfaces (not timeout).
    name, t = VoteOrchestrator.dispatch_task(
        () -> error("boom_inside"),
        "err_timeout";
        timeout_s = 1.0,
        context = "test_15C"
    )
    # GRUG: Must NOT be TaskTimeoutError — must be original TaskFailedException.
    err_ref = Ref{Any}(nothing)
    try
        VoteOrchestrator.fetch_with_timeout(name, t)
    catch e
        err_ref[] = e
    end
    @test !isnothing(err_ref[])
    @test !(err_ref[] isa VoteOrchestrator.TaskTimeoutError)
end

@testset "[15D] fetch_with_timeout — no timeout = plain fetch" begin
    # GRUG: Task dispatched without timeout, fetch_with_timeout without arg —
    # behaves like plain fetch. No timeout enforced.
    name, t = VoteOrchestrator.dispatch_task(() -> 77, "notimeout"; context = "test_15D")
    @test VoteOrchestrator.fetch_with_timeout(name, t) == 77
end

@testset "[15E] dispatch_task_with_timeout — convenience wrapper" begin
    name, t = VoteOrchestrator.dispatch_task_with_timeout(
        () -> 555, "conv", 1.0;
        context = "test_15E"
    )
    @test VoteOrchestrator.fetch_with_timeout(name, t) == 555

    # GRUG: Zero/negative timeout rejected loudly.
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.dispatch_task_with_timeout(
        () -> 1, "bad", 0.0
    )
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.dispatch_task_with_timeout(
        () -> 1, "bad", -5.0
    )
end

@testset "[15F] parallel_fire_batches — per-batch timeout catches stuck batch" begin
    # GRUG: A batch with a stuck fire_one must TaskTimeoutError-out cleanly.
    fc = VoteOrchestrator.FireCounter("timeout_batch", 1000)
    ids = ["n$i" for i in 1:30]
    @test_throws VoteOrchestrator.TaskTimeoutError VoteOrchestrator.parallel_fire_batches(
        ids, fc,
        (nid, counter) -> begin
            if nid == "n5"
                sleep(5.0)  # Force batch to blow deadline.
            end
            VoteOrchestrator.try_claim_fire_slot!(counter) ? nid : nothing
        end;
        batch_size = 10,
        batch_timeout_s = 0.4
    )
end

@testset "[15G] parallel_fire_batches — happy path with tight timeout" begin
    # GRUG: Normal fast batches never hit timeout.
    fc = VoteOrchestrator.FireCounter("tight_timeout", 1000)
    ids = ["n$i" for i in 1:200]
    results = VoteOrchestrator.parallel_fire_batches(
        ids, fc,
        (nid, counter) -> VoteOrchestrator.try_claim_fire_slot!(counter) ? nid : nothing;
        batch_size = 32,
        batch_timeout_s = 2.0
    )
    @test length(results) == 200
end

@testset "[15H] dispatch_task — negative or zero timeout rejected" begin
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.dispatch_task(
        () -> 1, "x"; timeout_s = -0.1
    )
    @test_throws VoteOrchestrator.VoteOrchestratorError VoteOrchestrator.dispatch_task(
        () -> 1, "x"; timeout_s = 0.0
    )
end

@testset "[15I] TaskTimeoutError — showerror renders useful message" begin
    err = VoteOrchestrator.TaskTimeoutError("test#42", "ctx_name", 1.234)
    msg = sprint(showerror, err)
    @test occursin("test#42", msg)
    @test occursin("ctx_name", msg)
    @test occursin("1.234", msg)
end

# ==============================================================================
# [16] Integration: DONE signal from multiple "lobes" in parallel Tasks
# ==============================================================================

@testset "[16] End-to-end: simulated lobes send DONE after firing" begin
    lobe_ids = ["lobe_alpha", "lobe_beta", "lobe_gamma", "lobe_delta"]
    fc = VoteOrchestrator.FireCounter("e2e_lobe", 1000)
    done_ch = VoteOrchestrator.make_done_channel(length(lobe_ids))

    # GRUG: Each "lobe" runs in its own Task, fires its nodes against the shared
    # FireCounter, then sends a DONE signal. Orchestrator waits for all DONEs.
    for lid in lobe_ids
        VoteOrchestrator.dispatch_task(
            () -> begin
                t0 = time()
                fires = 0
                votes = 0
                try
                    for _ in 1:50
                        if VoteOrchestrator.try_claim_fire_slot!(fc)
                            fires += 1
                            if rand() < 0.7
                                votes += 1
                            end
                        end
                    end
                    VoteOrchestrator.send_done!(done_ch, VoteOrchestrator.DoneSignal(
                        lid, fires, votes, time() - t0, nothing
                    ))
                catch e
                    VoteOrchestrator.send_done!(done_ch, VoteOrchestrator.DoneSignal(
                        lid, fires, votes, time() - t0, e
                    ))
                end
            end,
            "sim_lobe_$(lid)";
            context = "test_15"
        )
    end

    signals = VoteOrchestrator.wait_for_done(done_ch, length(lobe_ids); timeout_s = 5.0)
    @test length(signals) == length(lobe_ids)
    @test Set(s.lobe_id for s in signals) == Set(lobe_ids)
    @test all(isnothing(s.error) for s in signals)
    total_fires = sum(s.fires_count for s in signals)
    @test total_fires == VoteOrchestrator.current_fire_count(fc)
    @test total_fires <= 1000
    println("  $(length(signals)) lobes sent DONE, total fires = $total_fires")
end

println("\n" * "="^60)
println("✅ ALL VOTE ORCHESTRATOR TESTS PASSED")
println("="^60)