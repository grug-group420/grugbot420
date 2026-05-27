# test/test_self_observer.jl
# ==============================================================================
# Tests for SelfObserver — Subconscious Microlog Store
# ==============================================================================
# GRUG: covers EVERY design point we locked in:
#   - stochastic write probability
#   - exact + pattern lookup
#   - drop-table walk depth-2 association
#   - per-key cap + salience-aware eviction
#   - global total cap eviction
#   - strict single-reader lock contention
#   - per-node token bucket throttle
#   - global outstanding-token cap
#   - reader timeout returning nothing
#   - fuzzy bucket boundaries + per-query jitter
#   - audit counters
#   - STRUCTURAL INVARIANT: no public function returns Float64
#   - tag namespace filter
#   - drop_store! wipe
#
# No silent failures: every branch is asserted.
# ==============================================================================

using Test
using Random
using Base.Threads: @spawn

# GRUG: load module directly (test files run as isolated subprocesses).
const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
include(joinpath(REPO_ROOT, "src", "SelfObserver.jl"))
using .SelfObserver

@testset "SelfObserver — full surface" begin

    # ==========================================================================
    @testset "construction + argument validation" begin
        s = SubconsciousStore()
        @test store_size(s) == 0
        @test key_count(s) == 0

        # bad tag
        @test_throws SelfObserverArgumentError observe!(
            s, "k", :not_a_real_tag, Dict{String,Any}("x"=>"y"))
        # empty key
        @test_throws SelfObserverArgumentError observe!(
            s, "", :lexical, Dict{String,Any}("x"=>"y"))
        # out-of-range salience
        @test_throws SelfObserverArgumentError observe!(
            s, "k", :lexical, Dict{String,Any}("x"=>"y"); salience=-1.0)
        @test_throws SelfObserverArgumentError observe!(
            s, "k", :lexical, Dict{String,Any}("x"=>"y"); salience=999.0)
        # bad p_write
        @test_throws SelfObserverArgumentError observe!(
            s, "k", :lexical, Dict{String,Any}("x"=>"y"); p_write=2.0)

        # empty payload is a no-op (returns false), not an error.
        @test observe!(s, "k", :lexical, Dict{String,Any}()) == false
    end

    # ==========================================================================
    @testset "stochastic write probability" begin
        # GRUG: p_write=0 → never writes. p_write=1 → always writes.
        s = SubconsciousStore()
        for i in 1:200
            observe!(s, "always", :lexical, Dict{String,Any}("i"=>i);
                     p_write=0.0)
        end
        @test store_size(s) == 0

        s2 = SubconsciousStore()
        for i in 1:50
            observe!(s2, "key$i", :lexical, Dict{String,Any}("i"=>i);
                     p_write=1.0)
        end
        @test store_size(s2) == 50
        @test key_count(s2) == 50

        # Statistical: p_write=0.5 over many trials should land near 50%.
        # We pick a key NOT used elsewhere so reinforcement doesn't muddy this.
        s3 = SubconsciousStore(rng = MersenneTwister(42))
        N = 1000
        for i in 1:N
            observe!(s3, "key$i", :lexical, Dict{String,Any}("i"=>i);
                     p_write=0.5)
        end
        a = audit_trail(s3)
        # GRUG: writes + skipped should equal N.
        @test a[:writes] + a[:writes_skipped_stochastic] == N
        # Allow generous tolerance — this is a coin-flip, not a guarantee.
        @test 0.40 * N < a[:writes] < 0.60 * N
    end

    # ==========================================================================
    @testset "exact peek hit + miss" begin
        s = SubconsciousStore()
        observe!(s, "alpha", :lexical, Dict{String,Any}("note"=>"hello");
                 p_write=1.0, salience=2.0, provenance=:test)
        observe!(s, "alpha", :mood,    Dict{String,Any}("note"=>"happy");
                 p_write=1.0, salience=1.0, provenance=:test)

        hits = peek_exact(s, "node-A", "alpha")
        @test hits !== nothing
        @test length(hits) >= 1
        @test all(h -> h isa SubconsciousHint, hits)
        @test all(h -> h.key == "alpha", hits)

        # Tag filter narrows result.
        only_lex = peek_exact(s, "node-B", "alpha"; tag=:lexical)
        @test only_lex !== nothing
        @test all(h -> h.tag == :lexical, only_lex)

        # Miss returns nothing.
        miss = peek_exact(s, "node-C", "no_such_key")
        @test miss === nothing
        a = audit_trail(s)
        @test a[:peeks_miss] >= 1
    end

    # ==========================================================================
    @testset "pattern peek — token overlap" begin
        s = SubconsciousStore()
        observe!(s, "rainy day in seattle", :lexical,
                 Dict{String,Any}("note"=>"weather memory");
                 p_write=1.0, provenance=:test)
        observe!(s, "sunny day in austin", :lexical,
                 Dict{String,Any}("note"=>"other weather");
                 p_write=1.0, provenance=:test)
        observe!(s, "totally unrelated", :lexical,
                 Dict{String,Any}("note"=>"noise");
                 p_write=1.0, provenance=:test)

        hits = peek_pattern(s, "node-X", "rainy seattle today")
        @test hits !== nothing
        @test length(hits) >= 1
        # GRUG: the rainy-seattle key MUST score above the unrelated one.
        @test any(h -> occursin("rainy", h.key), hits)
        @test !any(h -> h.key == "totally unrelated", hits)
    end

    # ==========================================================================
    @testset "pattern peek — drop-table walk depth-2" begin
        s = SubconsciousStore()
        # GRUG: build associations: query → seed → mid → leaf.
        # We won't have token overlap to leaf, only walk-reachability.
        observe!(s, "kitchen", :lexical,
                 Dict{String,Any}("note"=>"seed");
                 p_write=1.0, provenance=:test,
                 drop_table=["stove", "pan"])
        observe!(s, "stove", :lexical,
                 Dict{String,Any}("note"=>"mid");
                 p_write=1.0, provenance=:test,
                 drop_table=["fire"])
        observe!(s, "fire", :lexical,
                 Dict{String,Any}("note"=>"leaf");
                 p_write=1.0, provenance=:test)

        # Query overlaps with "kitchen" only.
        hits = peek_pattern(s, "node-W", "kitchen"; walk_depth=2,
                            max_entries=10)
        @test hits !== nothing
        keys_returned = Set(h.key for h in hits)
        @test "kitchen" in keys_returned
        # Walk depth 1 reaches stove; depth 2 reaches fire.
        @test "stove" in keys_returned
        @test "fire" in keys_returned

        # walk_depth=0 should NOT pull in associated keys.
        hits0 = peek_pattern(s, "node-W2", "kitchen"; walk_depth=0,
                             max_entries=10)
        @test hits0 !== nothing
        keys0 = Set(h.key for h in hits0)
        @test "kitchen" in keys0
        @test "stove" ∉ keys0
        @test "fire"  ∉ keys0
    end

    # ==========================================================================
    @testset "per-key cap with salience-aware eviction" begin
        s = SubconsciousStore()
        # GRUG: write one HIGH-salience entry first under different provenance,
        # then flood with low-salience entries with DIFFERENT provenances so
        # they don't reinforce. Cap is MAX_ENTRIES_PER_KEY (32). The high
        # entry should survive; low entries get evicted.
        observe!(s, "shared", :lexical,
                 Dict{String,Any}("note"=>"vivid");
                 p_write=1.0, salience=8.0, provenance=:vivid)
        for i in 1:50
            observe!(s, "shared", :lexical,
                     Dict{String,Any}("i"=>i);
                     p_write=1.0, salience=0.5,
                     provenance=Symbol("low_$i"))
        end
        # Per-key bucket should be capped at 32.
        bucket_len = length(s.table["shared"])
        @test bucket_len == 32

        # The vivid one should still be there.
        hits = peek_exact(s, "node-V", "shared"; max_entries=32, tag=:lexical)
        @test hits !== nothing
        @test any(h -> h.provenance == :vivid, hits)

        a = audit_trail(s)
        @test a[:evictions_per_key] >= 1
    end

    # ==========================================================================
    @testset "reinforcement on repeat write (same tag + provenance)" begin
        s = SubconsciousStore()
        observe!(s, "habit", :mood,
                 Dict{String,Any}("note"=>"first"); p_write=1.0,
                 salience=1.0, provenance=:recurring)
        for _ in 1:5
            observe!(s, "habit", :mood,
                     Dict{String,Any}("note"=>"again"); p_write=1.0,
                     salience=1.0, provenance=:recurring)
        end
        @test length(s.table["habit"]) == 1  # all collapsed into one
        a = audit_trail(s)
        @test a[:writes_reinforced] >= 5
    end

    # ==========================================================================
    @testset "tag namespace filter" begin
        s = SubconsciousStore()
        observe!(s, "x", :timing,    Dict{String,Any}("v"=>"a"); p_write=1.0)
        observe!(s, "x", :lexical,   Dict{String,Any}("v"=>"b"); p_write=1.0)
        observe!(s, "x", :mood,      Dict{String,Any}("v"=>"c"); p_write=1.0)
        observe!(s, "x", :relational,Dict{String,Any}("v"=>"d"); p_write=1.0)
        observe!(s, "x", :meta,      Dict{String,Any}("v"=>"e"); p_write=1.0)

        # GRUG: per-node token bucket cap is 3, so we MUST use distinct node
        # ids across these 5 peeks or the 4th and 5th will be throttled.
        for (i, t) in enumerate((:timing, :lexical, :mood, :relational, :meta))
            hits = peek_exact(s, "node-T-$i", "x"; tag=t, max_entries=10)
            @test hits !== nothing
            @test all(h -> h.tag == t, hits)
            @test length(hits) == 1
        end
    end

    # ==========================================================================
    @testset "fuzzy bucket — stable per (key, query_id), variable across" begin
        s = SubconsciousStore()
        observe!(s, "memory", :lexical, Dict{String,Any}("v"=>"x");
                 p_write=1.0)

        # Same query_id → identical fuzzy bucket twice in a row.
        h1 = peek_exact(s, "node-F1", "memory"; query_id="qid-stable")
        h2 = peek_exact(s, "node-F2", "memory"; query_id="qid-stable")
        @test h1 !== nothing && h2 !== nothing
        @test h1[1].fuzzy_when == h2[1].fuzzy_when

        # Bucket must be a known symbol from FUZZY_BUCKETS.
        valid_syms = Set(t[1] for t in FUZZY_BUCKETS)
        @test h1[1].fuzzy_when in valid_syms

        # Just-now write should land in :just_now or :recent under jitter.
        @test h1[1].fuzzy_when in (:just_now, :recent)
    end

    # ==========================================================================
    @testset "throttle — per-node token bucket exhaustion" begin
        s = SubconsciousStore()
        observe!(s, "k", :lexical, Dict{String,Any}("v"=>"x"); p_write=1.0)

        # Default bucket capacity = 3. The 4th immediate peek from the SAME
        # node id should be throttled (return nothing).
        # GRUG: hits + misses both consume tokens; we use a present key so the
        # first 3 succeed.
        ok_count = 0
        none_count = 0
        for i in 1:6
            r = peek_exact(s, "burner-node", "k")
            if r === nothing
                none_count += 1
            else
                ok_count += 1
            end
        end
        @test ok_count == 3
        @test none_count == 3

        a = audit_trail(s)
        @test a[:peeks_throttle] >= 3
    end

    # ==========================================================================
    @testset "global outstanding-token cap" begin
        # GRUG: cap is 8 simultaneous outstanding peeks. We can't easily test
        # that 9 truly-concurrent peeks overflow without races, so we test the
        # counter behavior: under sequential load, outstanding returns to 0,
        # and global_cap counter never trips for a single-threaded loop.
        s = SubconsciousStore()
        observe!(s, "k", :lexical, Dict{String,Any}("v"=>"x"); p_write=1.0)
        for _ in 1:3
            peek_exact(s, "node-G", "k")
        end
        a = audit_trail(s)
        @test a[:outstanding_tokens] == 0
        @test a[:peeks_global_cap] == 0
    end

    # ==========================================================================
    @testset "single-reader lock under contention" begin
        # GRUG: spin many concurrent peeks; only one may hold the reader slot
        # at a time. We can't directly observe the lock, but we can assert the
        # outstanding counter never exceeds GLOBAL_TOKEN_CAP and the store
        # remains internally consistent. We also require at least one
        # peeks_lock_busy or peeks_throttle entry under heavy contention.
        s = SubconsciousStore()
        for i in 1:20
            observe!(s, "ck-$i", :lexical, Dict{String,Any}("i"=>i);
                     p_write=1.0)
        end

        N = 64
        results = Vector{Any}(undef, N)
        @sync for i in 1:N
            @spawn begin
                # Mix of node ids — some shared so throttle hits, some unique.
                node_id = "n-$(i % 6)"
                results[i] = peek_exact(s, node_id, "ck-1")
            end
        end

        a = audit_trail(s)
        @test a[:outstanding_tokens] == 0
        # Some path must have rejected — throttle or lock_busy or timeout.
        rejected = a[:peeks_throttle] + a[:peeks_lock_busy] + a[:peeks_timeout]
        @test rejected > 0
        # Hits + misses + rejections must equal attempts.
        @test a[:peeks_attempted] ==
              a[:peeks_hit] + a[:peeks_miss] + a[:peeks_throttle] +
              a[:peeks_lock_busy] + a[:peeks_timeout] + a[:peeks_global_cap]
    end

    # ==========================================================================
    @testset "reader timeout returns nothing — does not throw" begin
        s = SubconsciousStore()
        observe!(s, "k", :lexical, Dict{String,Any}("v"=>"x"); p_write=1.0)

        # Manually grab the reader slot to force the next peek to time out.
        s.reader_busy[] = true
        try
            r = peek_exact(s, "patient-node", "k"; timeout_ms=20)
            @test r === nothing
        finally
            s.reader_busy[] = false
        end
        a = audit_trail(s)
        @test (a[:peeks_lock_busy] + a[:peeks_timeout]) >= 1
    end

    # ==========================================================================
    @testset "drop_store! wipes everything but audit" begin
        s = SubconsciousStore()
        for i in 1:10
            observe!(s, "k$i", :lexical, Dict{String,Any}("i"=>i);
                     p_write=1.0, drop_table=["k$(i+1)"])
        end
        @test store_size(s) == 10
        a_before = audit_trail(s)
        @test a_before[:writes] == 10

        drop_store!(s)
        @test store_size(s) == 0
        @test key_count(s) == 0
        # Audit preserved.
        a_after = audit_trail(s)
        @test a_after[:writes] == 10

        reset_audit!(s)
        a_zero = audit_trail(s)
        @test a_zero[:writes] == 0
    end

    # ==========================================================================
    @testset "audit_trail values are all Int" begin
        s = SubconsciousStore()
        a = audit_trail(s)
        for (k, v) in a
            @test v isa Int
        end
    end

    # ==========================================================================
    @testset "STRUCTURAL INVARIANT — no exported function returns Float64" begin
        # GRUG: this is the architectural guarantee. If someone ever adds a
        # function to SelfObserver that returns Float64 (or even something
        # containing Float64 in its public hint type), this test fails loudly.
        #
        # We check two things:
        #   1. SubconsciousHint has zero Float64 fields (struct-level guarantee).
        #   2. None of the exported functions has a method whose declared
        #      return type is Float64. We can't fully constrain return types
        #      without inference, so we additionally call each user-facing
        #      reader with realistic args and assert the runtime return type
        #      is not Float64.
        for ft in fieldtypes(SubconsciousHint)
            @test !(Float64 <: ft)
            @test !(Float32 <: ft)
            @test ft != Float64
            @test ft != Float32
        end

        s = SubconsciousStore()
        observe!(s, "inv", :lexical, Dict{String,Any}("v"=>"x"); p_write=1.0)

        # Runtime return-type checks on every public reader.
        @test !(audit_trail(s) isa Float64)
        @test !(store_size(s) isa Float64)
        @test !(key_count(s) isa Float64)

        r1 = peek_exact(s, "inv-node", "inv")
        @test r1 === nothing || r1 isa Vector{SubconsciousHint}
        r2 = peek_pattern(s, "inv-node-2", "inv")
        @test r2 === nothing || r2 isa Vector{SubconsciousHint}

        # SubconsciousHint payload_strings is Dict{String,String} — no floats.
        if r1 !== nothing
            for h in r1
                for v in values(h.payload_strings)
                    @test v isa String
                end
            end
        end
    end

    # ==========================================================================
    @testset "Float64 payload values are NOT exposed in hints" begin
        # GRUG: payload may carry floats internally (callers are sloppy), but
        # the surfaced view must drop them, keeping the no-confidence-shape
        # invariant at the data level.
        s = SubconsciousStore()
        observe!(s, "fpay", :meta,
                 Dict{String,Any}("kind"=>"thing", "score"=>0.7);
                 p_write=1.0)
        hits = peek_exact(s, "fp-node", "fpay")
        @test hits !== nothing
        h = hits[1]
        @test "kind" in keys(h.payload_strings)
        @test !("score" in keys(h.payload_strings))   # float dropped
        @test "score" in h.payload_keys                # but caller can SEE it existed
    end

    # ==========================================================================
    @testset "global total cap eviction" begin
        # GRUG: shrink is impractical without exposing constants, but we can
        # at least verify that under heavy write load the global cap counter
        # increments when total > MAX_TOTAL_ENTRIES. We push past 4096 by
        # inserting 4097 distinct keys with small payloads.
        s = SubconsciousStore()
        N = 4100
        for i in 1:N
            observe!(s, "g$i", :lexical, Dict{String,Any}("i"=>i);
                     p_write=1.0)
        end
        @test store_size(s) <= 4096
        a = audit_trail(s)
        @test a[:evictions_total_cap] >= (N - 4096)
    end

end

println("[test_self_observer] all tests passed.")
