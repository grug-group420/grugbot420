# test_flashcard.jl - GRUG v10 Comprehensive Flashcard Subsystem Tests
# GRUG say: flashcard must work like cave painting. Write once, read many.
# GRUG say: hit counter must count hits. TTL must expire old cards. Query must filter.
# GRUG say: serialize/deserialize must round-trip perfectly.

if !isdefined(Main, :LobeTable)
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
    include(joinpath(@__DIR__, "..", "src", "LobeTable.jl"))
end
using .LobeTable
using Test

println("🧪 Running Flashcard subsystem tests...")

@testset "Flashcard - Full Test Suite" begin

    function fresh_lobe(suffix::String = "")::String
        lid = "fc_lobe_$(suffix)_$(round(Int, time() * 1000) % 1_000_000)"
        LobeTable.create_lobe_table!(lid)
        return lid
    end

    # ── PUT ──

    @testset "flashcard_put!" begin
        lid = fresh_lobe("put")

        card = LobeTable.flashcard_put!(lid, "2+3", "5"; result_num=5.0, card_type=:arithmetic)
        @test card !== nothing
        @test card["expression"] == "2+3"
        @test card["result"] == "5"
        @test card["result_num"] == 5.0
        @test card["type"] == "arithmetic"
        @test card["lobe_id"] == lid
        @test card["hits"] == 0
        @test card["ttl"] == 0.0
        @test card["created_at"] > 0.0

        lid2 = "fc_auto_$(round(Int, time() * 1000) % 1_000_000)"
        LobeTable.create_lobe_table!(lid2)
        card2 = LobeTable.flashcard_put!(lid2, "7*8", "56"; result_num=56.0)
        @test card2 !== nothing
        @test card2["expression"] == "7*8"

        @test LobeTable.flashcard_put!(lid, "", "0") === nothing
        @test LobeTable.flashcard_put!(lid, "   ", "0") === nothing

        # overwrite preserves hit count
        LobeTable.flashcard_hit!(lid, "2+3")
        LobeTable.flashcard_hit!(lid, "2+3")
        updated = LobeTable.flashcard_put!(lid, "2+3", "5"; result_num=5.0, card_type=:arithmetic, ttl=300.0)
        @test updated["hits"] == 2
        @test updated["ttl"] == 300.0

        # different card_type
        card_lookup = LobeTable.flashcard_put!(lid, "pi", "3.14159"; card_type=:lookup)
        @test card_lookup["type"] == "lookup"
    end

    # ── GET ──

    @testset "flashcard_get" begin
        lid = fresh_lobe("get")

        LobeTable.flashcard_put!(lid, "9*9", "81"; result_num=81.0)
        card = LobeTable.flashcard_get(lid, "9*9")
        @test card !== nothing
        @test card["result"] == "81"

        # case-insensitive
        LobeTable.flashcard_put!(lid, "ABC", "def")
        @test LobeTable.flashcard_get(lid, "abc") !== nothing
        @test LobeTable.flashcard_get(lid, "abc")["result"] == "def"

        # non-existent
        @test LobeTable.flashcard_get(lid, "nonexistent_xyz") === nothing
        @test LobeTable.flashcard_get(lid, "") === nothing

        # TTL expiry
        LobeTable.flashcard_put!(lid, "ephemeral", "gone"; ttl=0.01)
        sleep(0.05)
        @test LobeTable.flashcard_get(lid, "ephemeral") === nothing

        # long TTL survives
        LobeTable.flashcard_put!(lid, "persistent", "here"; ttl=3600.0)
        @test LobeTable.flashcard_get(lid, "persistent") !== nothing

        # ttl=0 never expires
        LobeTable.flashcard_put!(lid, "forever", "immortal"; ttl=0.0)
        @test LobeTable.flashcard_get(lid, "forever") !== nothing
    end

    # ── HAS ──

    @testset "flashcard_has" begin
        lid = fresh_lobe("has")
        LobeTable.flashcard_put!(lid, "4*5", "20"; result_num=20.0)
        @test LobeTable.flashcard_has(lid, "4*5")
        @test !LobeTable.flashcard_has(lid, "nothing_here")
        @test !LobeTable.flashcard_has(lid, "")
    end

    # ── DELETE ──

    @testset "flashcard_delete!" begin
        lid = fresh_lobe("del")
        LobeTable.flashcard_put!(lid, "6*7", "42"; result_num=42.0)
        @test LobeTable.flashcard_delete!(lid, "6*7")
        @test LobeTable.flashcard_get(lid, "6*7") === nothing
        @test !LobeTable.flashcard_has(lid, "6*7")
        @test !LobeTable.flashcard_delete!(lid, "never_existed")
        @test !LobeTable.flashcard_delete!(lid, "")
    end

    # ── HIT ──

    @testset "flashcard_hit!" begin
        lid = fresh_lobe("hit")
        LobeTable.flashcard_put!(lid, "8*8", "64"; result_num=64.0)
        LobeTable.flashcard_hit!(lid, "8*8")
        LobeTable.flashcard_hit!(lid, "8*8")
        LobeTable.flashcard_hit!(lid, "8*8")
        card = LobeTable.flashcard_get(lid, "8*8")
        @test card["hits"] == 3
        @test !LobeTable.flashcard_hit!(lid, "ghost_card")
        @test !LobeTable.flashcard_hit!(lid, "")
    end

    # ── QUERY ──

    @testset "flashcard_query" begin
        lid = fresh_lobe("query")
        LobeTable.flashcard_put!(lid, "1+1", "2"; result_num=2.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "2+2", "4"; result_num=4.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "3+3", "6"; result_num=6.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid, "euler", "2.71828"; card_type=:lookup)
        LobeTable.flashcard_put!(lid, "pi", "3.14159"; card_type=:lookup)

        LobeTable.flashcard_hit!(lid, "2+2")
        LobeTable.flashcard_hit!(lid, "2+2")
        LobeTable.flashcard_hit!(lid, "2+2")
        LobeTable.flashcard_hit!(lid, "3+3")

        all_cards = LobeTable.flashcard_query(lid)
        @test length(all_cards) == 5

        arith_cards = LobeTable.flashcard_query(lid; card_type=:arithmetic)
        @test length(arith_cards) == 3

        lookup_cards = LobeTable.flashcard_query(lid; card_type=:lookup)
        @test length(lookup_cards) == 2

        popular = LobeTable.flashcard_query(lid; min_hits=3)
        @test length(popular) == 1

        arith_popular = LobeTable.flashcard_query(lid; card_type=:arithmetic, min_hits=1)
        @test length(arith_popular) >= 1

        @test isempty(LobeTable.flashcard_query("no_such_lobe_fc"))
        @test isempty(LobeTable.flashcard_query(lid; min_hits=999))
    end

    # ── EVICT ──

    @testset "flashcard_evict!" begin
        lid = fresh_lobe("evict")
        LobeTable.flashcard_put!(lid, "expire_me", "poof"; ttl=0.01)
        LobeTable.flashcard_put!(lid, "expire_too", "pfft"; ttl=0.01)
        LobeTable.flashcard_put!(lid, "keep_me", "forever"; ttl=3600.0)
        LobeTable.flashcard_put!(lid, "no_ttl", "stays"; ttl=0.0)
        sleep(0.05)

        evicted = LobeTable.flashcard_evict!(lid)
        @test evicted == 2
        @test LobeTable.flashcard_has(lid, "keep_me")
        @test LobeTable.flashcard_has(lid, "no_ttl")
        @test !LobeTable.flashcard_has(lid, "expire_me")
        @test !LobeTable.flashcard_has(lid, "expire_too")

        lid_empty = fresh_lobe("evict_empty")
        @test LobeTable.flashcard_evict!(lid_empty) == 0
    end

    # ── COUNT ──

    @testset "flashcard_count" begin
        lid = fresh_lobe("count")
        @test LobeTable.flashcard_count(lid) == 0
        LobeTable.flashcard_put!(lid, "a", "1")
        @test LobeTable.flashcard_count(lid) == 1
        LobeTable.flashcard_put!(lid, "b", "2")
        @test LobeTable.flashcard_count(lid) == 2
        LobeTable.flashcard_delete!(lid, "b")
        @test LobeTable.flashcard_count(lid) == 1
        LobeTable.flashcard_put!(lid, "a", "updated")
        @test LobeTable.flashcard_count(lid) == 1
        @test LobeTable.flashcard_count("no_such_lobe_cnt") == 0
    end

    # ── SERIALIZE / DESERIALIZE ──

    @testset "serialize/deserialize round-trip" begin
        lid_a = fresh_lobe("ser_a")
        lid_b = fresh_lobe("ser_b")

        LobeTable.flashcard_put!(lid_a, "10*10", "100"; result_num=100.0, card_type=:arithmetic)
        LobeTable.flashcard_put!(lid_a, "sqrt2", "1.41421"; card_type=:lookup)
        LobeTable.flashcard_hit!(lid_a, "10*10")
        LobeTable.flashcard_hit!(lid_a, "10*10")

        LobeTable.flashcard_put!(lid_b, "7+3", "10"; result_num=10.0)

        data = LobeTable.serialize_flashcards()
        @test data !== nothing
        @test haskey(data, lid_a)
        @test haskey(data, lid_b)
        @test length(data[lid_a]) == 2
        @test length(data[lid_b]) == 1

        LobeTable.flashcard_delete!(lid_a, "10*10")
        LobeTable.flashcard_delete!(lid_a, "sqrt2")
        LobeTable.flashcard_delete!(lid_b, "7+3")

        LobeTable.deserialize_flashcards!(data)

        @test LobeTable.flashcard_has(lid_a, "10*10")
        @test LobeTable.flashcard_has(lid_a, "sqrt2")
        @test LobeTable.flashcard_has(lid_b, "7+3")

        restored = LobeTable.flashcard_get(lid_a, "10*10")
        @test restored !== nothing
        @test restored["hits"] == 2

        LobeTable.deserialize_flashcards!(nothing)
        LobeTable.deserialize_flashcards!(Dict{String, Any}())
    end

    # ── CROSS-LOBE ISOLATION ──

    @testset "cross-lobe isolation" begin
        lid_x = fresh_lobe("iso_x")
        lid_y = fresh_lobe("iso_y")

        LobeTable.flashcard_put!(lid_x, "test_expr", "result_x"; card_type=:arithmetic)
        LobeTable.flashcard_put!(lid_y, "test_expr", "result_y"; card_type=:lookup)

        cx = LobeTable.flashcard_get(lid_x, "test_expr")
        cy = LobeTable.flashcard_get(lid_y, "test_expr")
        @test cx["result"] == "result_x"
        @test cy["result"] == "result_y"
        @test cx["type"] == "arithmetic"
        @test cy["type"] == "lookup"

        LobeTable.flashcard_delete!(lid_x, "test_expr")
        @test !LobeTable.flashcard_has(lid_x, "test_expr")
        @test LobeTable.flashcard_has(lid_y, "test_expr")
    end

    # ── STRESS ──

    @testset "stress: many flashcards" begin
        lid = fresh_lobe("stress")
        n = 200
        for i in 1:n
            LobeTable.flashcard_put!(lid, "$(i)+$(i)", string(2i); result_num=Float64(2i))
        end
        @test LobeTable.flashcard_count(lid) == n
        for i in [1, 50, 100, 150, 200]
            card = LobeTable.flashcard_get(lid, "$(i)+$(i)")
            @test card !== nothing
            @test card["result_num"] == Float64(2i)
        end
        all_arith = LobeTable.flashcard_query(lid; card_type=:arithmetic)
        @test length(all_arith) == n
    end
end

println("✅ Flashcard tests complete.")
