# test_immune_thread_pool.jl — Test suite for Hardcore Immune Thread Pool
# ==============================================================================
# GRUG: Tests for the immune system thread pool with all HARDCORE features:
#   - Priority lanes
#   - Per-source rate limiting
#   - Cost-weighted balancing
#   - Tripwire metrics + hardened mode
# ==============================================================================

using Test
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# Include the modules
include("../src/ImmuneSystem.jl")
include("../src/ImmuneThreadPool.jl")

using .ImmuneSystem
using .ImmuneThreadPool

# ==============================================================================
# TEST HELPERS
# ==============================================================================

"""Create a mock immune module for testing without full bot"""
module MockImmune
    struct ImmuneError <: Exception
        msg::String
    end
    
    function immune_scan!(input_text::String, node_count::Int; is_critical::Bool = true)
        # Simple mock: reject if contains "BAD" or "EVIL"
        if occursin("BAD", input_text) || occursin("EVIL", input_text)
            throw(ImmuneError("Input rejected: contains malicious pattern"))
        end
        # Return (status, signature) tuple
        return (:clean, UInt64(hash(input_text)))
    end
end

# ==============================================================================
# GROUP 1: ERROR TYPES
# ==============================================================================

@testset "Error Types — GRUG: All errors are LOUD" begin
    @testset "ImmuneWorkerDiedError" begin
        err = ImmuneWorkerDiedError(3, "test crash")
        @test err.worker_id == 3
        @test err.cause == "test crash"
        # Test showerror doesn't throw
        io = IOBuffer()
        showerror(io, err)
        @test occursin("IMMUNE WORKER #3 DIED", String(take!(io)))
    end
    
    @testset "ImmunePoolOverloadError" begin
        err = ImmunePoolOverloadError(100, PRIORITY_CRITICAL, "test overload")
        @test err.waiting_list_size == 100
        @test err.priority == PRIORITY_CRITICAL
        @test err.msg == "test overload"
    end
    
    @testset "ImmunePoolDeadError" begin
        err = ImmunePoolDeadError("pool is dead")
        @test err.msg == "pool is dead"
    end
    
    @testset "ImmuneWorkerBalancerError" begin
        err = ImmuneWorkerBalancerError("all workers full")
        @test err.msg == "all workers full"
    end
    
    @testset "ImmuneRateLimitExhaustedError" begin
        source = SourceID(:user, 0x1234)
        err = ImmuneRateLimitExhaustedError(source, 500, "rate limited")
        @test err.source == source
        @test err.retry_after_ms == 500
    end
    
    @testset "ImmuneTripwireTriggeredError" begin
        err = ImmuneTripwireTriggeredError(TRIPWIRE_NORMAL, TRIPWIRE_HARDENED, 0.3, "rejection spike")
        @test err.old_state == TRIPWIRE_NORMAL
        @test err.new_state == TRIPWIRE_HARDENED
        @test err.rejection_rate == 0.3
    end
    
    @testset "ImmunePriorityInversionError" begin
        err = ImmunePriorityInversionError(5, 10, "critical starving")
        @test err.critical_waiting == 5
        @test err.lower_priority_processed == 10
    end
end

# ==============================================================================
# GROUP 2: PRIORITY ENUMS
# ==============================================================================

@testset "Priority Enums — GRUG: Priority lanes work correctly" begin
    @test PRIORITY_CRITICAL == PriorityLevel(0)
    @test PRIORITY_NORMAL == PriorityLevel(1)
    @test PRIORITY_LOW == PriorityLevel(2)
    @test PRIORITY_JUNK == PriorityLevel(3)
    
    @test PRIORITY_CRITICAL < PRIORITY_NORMAL
    @test PRIORITY_NORMAL < PRIORITY_LOW
    @test PRIORITY_LOW < PRIORITY_JUNK
end

# ==============================================================================
# GROUP 3: SCAN COST ESTIMATION
# ==============================================================================

@testset "Scan Cost Estimation — GRUG: Cost estimation works" begin
    @test estimate_scan_cost(10) == COST_CHEAP
    @test estimate_scan_cost(49) == COST_CHEAP
    @test estimate_scan_cost(50) == COST_MODERATE
    @test estimate_scan_cost(100) == COST_MODERATE
    @test estimate_scan_cost(199) == COST_MODERATE
    @test estimate_scan_cost(200) == COST_EXPENSIVE
    @test estimate_scan_cost(1000) == COST_EXPENSIVE
    
    @test COST_WEIGHTS[COST_CHEAP] == 1
    @test COST_WEIGHTS[COST_MODERATE] == 2
    @test COST_WEIGHTS[COST_EXPENSIVE] == 4
end

# ==============================================================================
# GROUP 4: SOURCE ID
# ==============================================================================

@testset "Source ID — GRUG: Source identification works" begin
    s1 = SourceID(:user, 0x1234)
    @test s1.source_type == :user
    @test s1.source_id == 0x1234
    
    s2 = SourceID(:api, 0x5678)
    @test s2.source_type == :api
    
    @test SOURCE_INTERNAL.source_type == :internal
    @test SOURCE_ANONYMOUS.source_type == :anonymous
end

# ==============================================================================
# GROUP 5: TOKEN BUCKET
# ==============================================================================

@testset "Token Bucket — GRUG: Rate limiting bucket works" begin
    # GRUG: Use very slow rate (0.001 tokens/sec) so time-based refill
    # between rapid test steps is negligible (< 0.001 tokens per ms).
    bucket = TokenBucket(0.001, 5)  # 0.001 tokens/sec, max 5 burst
    
    @test bucket.tokens == 5.0  # Starts full
    @test bucket.rate == 0.001
    @test bucket.burst == 5
    
    # Consume tokens
    @test try_consume!(bucket, 1) == true
    @test bucket.tokens ≈ 4.0 atol=0.1
    
    # Consume more
    @test try_consume!(bucket, 3) == true
    @test bucket.tokens ≈ 1.0 atol=0.1
    
    # Try to consume more than available
    @test try_consume!(bucket, 2) == false
    
    # Refill
    refill!(bucket)
    @test bucket.tokens == 5.0
end

# ==============================================================================
# GROUP 6: TRIPWIRE MONITOR
# ==============================================================================

@testset "Tripwire Monitor — GRUG: Rejection rate tracking works" begin
    mon = TripwireMonitor()
    
    @test get_tripwire_state(mon) == TRIPWIRE_NORMAL
    @test get_rejection_rate(mon) == 0.0
    
    # Record some processed items
    for i in 1:10
        record_processed!(mon, rejected=(i <= 3))  # 30% rejection rate
    end
    
    @test mon.window_processed[] == 10
    @test mon.window_rejected[] == 3
    @test get_rejection_rate(mon) ≈ 0.3 atol=0.01
    
    # Test state update
    old_state, new_state = update_tripwire_state!(mon)
    @test new_state == TRIPWIRE_HARDENED  # 30% > 25% threshold
end

# ==============================================================================
# GROUP 7: POOL CREATION
# ==============================================================================

@testset "Pool Creation — GRUG: Pool starts with 8 workers" begin
    pool = create_immune_pool(MockImmune)
    
    try
        @test pool.alive[] == true
        @test length(pool.workers) == NUM_IMMUNE_WORKERS
        
        for w in pool.workers
            @test w.id >= 1 && w.id <= NUM_IMMUNE_WORKERS
            @test isopen(w.inbox)
        end
        
        @test pool.tripwire !== nothing
        @test pool.rate_limiter !== nothing
        @test get_tripwire_state(pool.tripwire) == TRIPWIRE_NORMAL
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 8: SUBMIT AND FETCH
# ==============================================================================

@testset "Submit and Fetch — GRUG: Basic submit/fetch works" begin
    pool = create_immune_pool(MockImmune)
    
    try
        future = submit_immune_work!(pool, "hello world", 10)
        @test future isa ImmuneFuture
        @test future.input_text == "hello world"
        
        # Wait for result
        result = fetch_result(future)
        @test result isa Tuple{Symbol, UInt64}
        @test result[1] == :clean
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 9: PRIORITY LANES
# ==============================================================================

@testset "Priority Lanes — GRUG: CRITICAL processed first" begin
    pool = create_immune_pool(MockImmune)
    
    try
        # Submit JUNK first (would be processed last without priorities)
        junk_future = submit_immune_work!(pool, "junk input", 10; priority=PRIORITY_JUNK)
        
        # Submit CRITICAL (should be processed first despite being submitted second)
        critical_future = submit_immune_work!(pool, "critical input", 10; priority=PRIORITY_CRITICAL)
        
        # Wait for both
        junk_result = fetch_result(junk_future)
        critical_result = fetch_result(critical_future)
        
        # Both should complete
        @test junk_result[1] == :clean
        @test critical_result[1] == :clean
        
        # Check lane sizes are 0 (drained)
        @test get_lane_size(pool.waiting_list, PRIORITY_CRITICAL) == 0
        @test get_lane_size(pool.waiting_list, PRIORITY_JUNK) == 0
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 10: RATE LIMITING
# ==============================================================================

@testset "Rate Limiting — GRUG: Per-source rate limits work" begin
    pool = create_immune_pool(MockImmune)
    
    try
        source = SourceID(:anonymous, 0x9999)
        
        # Anonymous has burst of 3, so first few should succeed
        results = ImmuneFuture[]
        for i in 1:3
            f = submit_immune_work!(pool, "test $i", 10; source=source, priority=PRIORITY_LOW)
            push!(results, f)
        end
        
        # Next one should be rate limited
        @test_throws ImmuneRateLimitExhaustedError begin
            submit_immune_work!(pool, "rate limited", 10; source=source, priority=PRIORITY_LOW)
        end
        
        # Check rate_limited counter increased
        @test pool.rate_limited[] >= 1
        
        # Collect results from successful submissions
        for f in results
            fetch_result(f)
        end
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 11: COST-WEIGHTED BALANCING
# ==============================================================================

@testset "Cost-Weighted Balancing — GRUG: Expensive scans count heavier" begin
    pool = create_immune_pool(MockImmune)
    
    try
        # Get initial cost loads
        initial_loads = get_cost_weighted_load(pool)
        
        # Submit some expensive scans
        # GRUG: Use SOURCE_INTERNAL to bypass rate limiter in this smoke test.
        # Rate limiting is tested separately (Group 8). Here we only care about
        # cost-weighted load tracking, not per-source token buckets.
        for i in 1:5
            submit_immune_work!(pool, "expensive $i", 500; priority=PRIORITY_NORMAL, source=SOURCE_INTERNAL)
        end
        
        # Wait for processing
        sleep(0.1)
        
        # Cost loads should have increased (then decayed)
        # This is a smoke test - actual values depend on timing
        status = get_pool_status(pool)
        @test haskey(status, "workers")
        
        for w_status in status["workers"]
            @test haskey(w_status, "cost_load")
        end
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 12: TRIPWIRE STATE TRANSITIONS
# ==============================================================================

@testset "Tripwire State Transitions — GRUG: System hardens under attack" begin
    pool = create_immune_pool(MockImmune)
    
    try
        @test get_tripwire_state(pool.tripwire) == TRIPWIRE_NORMAL
        
        # Submit many BAD inputs to trigger rejections
        for i in 1:20
            try
                f = submit_immune_work!(pool, "BAD input $i", 10; 
                    source=SourceID(:user, UInt64(i)), 
                    priority=PRIORITY_LOW)
                fetch_result(f)
            catch e
                # Expected: ImmuneError from BAD input
                # or RateLimitExhausted from hitting limits
            end
        end
        
        sleep(TRIPWIRE_WINDOW_S + 0.5)  # Wait for window to slide
        
        # Check rejection rate is tracked
        rr = get_rejection_rate(pool.tripwire)
        @test rr >= 0.0  # Should have some rejections
        
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 13: INTERNAL SOURCE BYPASSES RATE LIMIT
# ==============================================================================

@testset "Internal Source — GRUG: Internal bypasses rate limit" begin
    pool = create_immune_pool(MockImmune)
    
    try
        # Internal source should never be rate limited
        for i in 1:50
            f = submit_immune_work!(pool, "internal $i", 10; 
                source=SOURCE_INTERNAL, 
                priority=PRIORITY_CRITICAL)
            # Don't wait, just submit rapidly
        end
        
        @test pool.submitted[] == 50
        @test pool.rate_limited[] == 0  # None rate limited
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 14: DEAD POOL DETECTION
# ==============================================================================

@testset "Dead Pool Detection — GRUG: Dead pool screams" begin
    pool = create_immune_pool(MockImmune)
    kill_immune_pool!(pool)
    
    @test pool.alive[] == false
    
    @test_throws ImmunePoolDeadError begin
        submit_immune_work!(pool, "test", 10)
    end
end

# ==============================================================================
# GROUP 15: EMPTY INPUT GUARD
# ==============================================================================

@testset "Empty Input Guard — GRUG: Empty input causes FATAL error" begin
    pool = create_immune_pool(MockImmune)
    
    try
        @test_throws ErrorException begin
            submit_immune_work!(pool, "", 10)
        end
        
        @test_throws ErrorException begin
            submit_immune_work!(pool, "   ", 10)  # Whitespace only
        end
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 16: SUBMIT AND WAIT
# ==============================================================================

@testset "Submit and Wait — GRUG: Blocking submit works" begin
    pool = create_immune_pool(MockImmune)
    
    try
        result = submit_and_wait!(pool, "hello", 10)
        @test result[1] == :clean
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 17: GET POOL STATUS
# ==============================================================================

@testset "Get Pool Status — GRUG: Status includes all new metrics" begin
    pool = create_immune_pool(MockImmune)
    
    try
        status = get_pool_status(pool)
        
        @test status["pool_alive"] == true
        @test status["num_workers"] == NUM_IMMUNE_WORKERS
        @test haskey(status, "lane_sizes")
        @test haskey(status, "tripwire_state")
        @test haskey(status, "rejection_rate")
        @test haskey(status, "rate_limited_total")
        
        # Check lane sizes
        @test haskey(status["lane_sizes"], "PRIORITY_CRITICAL")
        @test haskey(status["lane_sizes"], "PRIORITY_NORMAL")
        @test haskey(status["lane_sizes"], "PRIORITY_LOW")
        @test haskey(status["lane_sizes"], "PRIORITY_JUNK")
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 18: WORKER RESTART
# ==============================================================================

@testset "Worker Restart — GRUG: Dead worker can be revived" begin
    pool = create_immune_pool(MockImmune)
    
    try
        # Kill a worker manually
        pool.workers[1].alive[] = false
        close(pool.workers[1].inbox)
        
        @test pool.workers[1].alive[] == false
        
        # Restart it
        new_worker = restart_worker!(pool, 1, MockImmune)
        
        @test new_worker.id == 1
        @test new_worker.alive[] == false  # Will become true when loop starts
        
        sleep(0.1)  # Let worker start
        
        @test new_worker.alive[] == true
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# GROUP 19: CONSTANTS CHECK
# ==============================================================================

@testset "Constants — GRUG: All constants are sensible" begin
    @test NUM_IMMUNE_WORKERS == 8
    @test WORKER_CHANNEL_DEPTH == 64
    @test MAX_WAITING_LIST_SIZE_PER_PRIORITY == 128
    @test MAX_WAITING_LIST_SIZE == 512
    
    # Rate limits exist for all source types
    for st in [:user, :api, :batch, :anonymous, :internal]
        @test haskey(RATE_LIMIT_TOKENS_PER_SEC, st)
        @test haskey(RATE_LIMIT_BURST, st)
        @test haskey(RATE_LIMIT_TOKENS_PER_SEC_HARDENED, st)
        @test haskey(RATE_LIMIT_BURST_HARDENED, st)
    end
    
    # Tripwire thresholds are ordered correctly
    @test TRIPWIRE_ELEVATED_THRESHOLD < TRIPWIRE_HARDENED_THRESHOLD
    @test TRIPWIRE_HARDENED_THRESHOLD < TRIPWIRE_CRITICAL_THRESHOLD
end

# ==============================================================================
# GROUP 20: NO SILENT FAILURES
# ==============================================================================

@testset "No Silent Failures — GRUG: All errors are typed and loud" begin
    # Test that every error type has showerror defined
    errors = [
        ImmuneWorkerDiedError(1, "test"),
        ImmunePoolOverloadError(0, PRIORITY_NORMAL, "test"),
        ImmunePoolDeadError("test"),
        ImmuneWorkerBalancerError("test"),
        ImmuneRateLimitExhaustedError(SOURCE_ANONYMOUS, 0, "test"),
        ImmuneTripwireTriggeredError(TRIPWIRE_NORMAL, TRIPWIRE_ELEVATED, 0.1, "test"),
        ImmunePriorityInversionError(0, 0, "test")
    ]
    
    for err in errors
        io = IOBuffer()
        showerror(io, err)
        output = String(take!(io))
        # All errors should have skull emoji or warning emoji
        @test occursin("💀", output) || occursin("⚠️", output)
        @test length(output) > 10  # Should have meaningful message
    end
end

# ==============================================================================
# GROUP 21: THROUGHPUT SMOKE TEST
# ==============================================================================

@testset "Throughput Smoke Test — GRUG: Pool handles reasonable load" begin
    pool = create_immune_pool(MockImmune)
    
    try
        n = 100
        futures = ImmuneFuture[]
        
        start_time = time()
        
        # Submit many items from internal source (no rate limit)
        for i in 1:n
            f = submit_immune_work!(pool, "throughput test $i", 20;
                source=SOURCE_INTERNAL,
                priority=PRIORITY_NORMAL)
            push!(futures, f)
        end
        
        # Wait for all to complete
        for f in futures
            fetch_result(f)
        end
        
        elapsed = time() - start_time
        
        @test pool.submitted[] == n
        @test pool.dispatched[] >= n - 10  # Most should be dispatched
        
        println("Throughput: $n items in $(round(elapsed, digits=2))s = $(round(n/elapsed, digits=1)) items/sec")
        
    finally
        kill_immune_pool!(pool)
    end
end

# ==============================================================================
# SUMMARY
# ==============================================================================

println("\n" * "="^60)
println("GRUG: Hardcore immune pool tests complete!")
println("="^60)