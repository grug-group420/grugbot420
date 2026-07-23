# test_lobe_table.jl - GRUG Comprehensive Tests for LobeTable.jl
# GRUG say: hash table must be tested like cave walls. Bang on every chunk.
# GRUG say: per-lobe isolation must be airtight. Cave A never bleeds into Cave B.
# GRUG say: error paths tested first. No silent failures tolerated.

if !isdefined(Main, :LobeTable)
    include("LobeTable.jl")
end
using .LobeTable
using Test

println("🧪 Running LobeTable.jl tests...")

@testset "LobeTable - Full Test Suite" begin

    # =========================================================================
    # HELPERS - Reset state between test groups
    # =========================================================================

    function fresh_lobe(suffix::String = "")::String
        lid = "test_lobe_$(suffix)_$(round(Int, time() * 1000) % 1_000_000)"
        LobeTable.create_lobe_table!(lid)
        return lid
    end

    # =========================================================================
    # SECTION 1: CREATE LOBE TABLE
    # =========================================================================

    @testset "create_lobe_table!" begin
        lid = "ctl_lobe_$(round(Int, time() * 1000) % 1_000_000)"

        # GRUG: Creating a new table returns a record
        rec = LobeTable.create_lobe_table!(lid)
        @test rec.lobe_id == lid
        @test rec.created_at > 0.0
        @test length(rec.chunks) == length(LobeTable.VALID_CHUNKS)

        # GRUG: All valid chunk names pre-allocated
        for cname in LobeTable.VALID_CHUNKS
            @test haskey(rec.chunks, cname)
        end

        # GRUG: Idempotent - calling twice returns same record, no error
        rec2 = LobeTable.create_lobe_table!(lid)
        @test rec2.lobe_id == lid

        # GRUG: table_exists returns true after creation
        @test LobeTable.table_exists(lid)

        # GRUG: Non-existent lobe returns false
        @test !LobeTable.table_exists("no_such_lobe_xyz")

        # GRUG: Empty lobe_id throws
        @test_throws LobeTable.LobeTableError LobeTable.create_lobe_table!("")
        @test_throws LobeTable.LobeTableError LobeTable.create_lobe_table!("   ")
    end

    # =========================================================================
    # SECTION 2: TABLE PUT / GET / HAS / DELETE
    # =========================================================================

    @testset "table_put! / table_get / table_has / table_delete!" begin
        lid = fresh_lobe("crud")

        # GRUG: Put and get back a string value
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "color", "blue")
        val = LobeTable.table_get(lid, LobeTable.CHUNK_META, "color")
        @test val == "blue"

        # GRUG: Put and get back a numeric value
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "count", 42)
        @test LobeTable.table_get(lid, LobeTable.CHUNK_META, "count") == 42

        # GRUG: Put and get back a dict value
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "nested", Dict("a" => 1))
        nested = LobeTable.table_get(lid, LobeTable.CHUNK_META, "nested")
        @test nested isa Dict
        @test nested["a"] == 1

        # GRUG: Missing key returns nothing (not an error)
        @test isnothing(LobeTable.table_get(lid, LobeTable.CHUNK_META, "nonexistent"))

        # GRUG: table_has returns true for existing key
        @test LobeTable.table_has(lid, LobeTable.CHUNK_META, "color")

        # GRUG: table_has returns false for missing key
        @test !LobeTable.table_has(lid, LobeTable.CHUNK_META, "missing_key")

        # GRUG: table_delete! returns true when key existed
        deleted = LobeTable.table_delete!(lid, LobeTable.CHUNK_META, "color")
        @test deleted == true
        @test !LobeTable.table_has(lid, LobeTable.CHUNK_META, "color")

        # GRUG: table_delete! returns false when key doesn't exist (not an error)
        deleted2 = LobeTable.table_delete!(lid, LobeTable.CHUNK_META, "already_gone")
        @test deleted2 == false

        # GRUG: Update existing key (put again)
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "count", 99)
        @test LobeTable.table_get(lid, LobeTable.CHUNK_META, "count") == 99

        # GRUG: table_get! throws on missing key
        @test_throws LobeTable.LobeTableError LobeTable.table_get!(lid, LobeTable.CHUNK_META, "definitely_missing")

        # GRUG: table_get! returns value when key exists
        @test LobeTable.table_get!(lid, LobeTable.CHUNK_META, "count") == 99
    end

    # =========================================================================
    # SECTION 3: ERROR HANDLING - Missing lobe, bad chunk, empty keys
    # =========================================================================

    @testset "Error handling - missing lobe / bad chunk / empty key" begin
        lid = fresh_lobe("err")

        # GRUG: Operations on non-existent lobe throw LobeTableError
        @test_throws LobeTable.LobeTableError LobeTable.table_put!("no_lobe_xyz", LobeTable.CHUNK_META, "k", "v")
        @test_throws LobeTable.LobeTableError LobeTable.table_get("no_lobe_xyz", LobeTable.CHUNK_META, "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_has("no_lobe_xyz", LobeTable.CHUNK_META, "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_delete!("no_lobe_xyz", LobeTable.CHUNK_META, "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_keys("no_lobe_xyz", LobeTable.CHUNK_META)
        @test_throws LobeTable.LobeTableError LobeTable.table_size("no_lobe_xyz", LobeTable.CHUNK_META)

        # GRUG: Bad chunk name throws LobeTableError
        @test_throws LobeTable.LobeTableError LobeTable.table_put!(lid, "BAD_CHUNK", "k", "v")
        @test_throws LobeTable.LobeTableError LobeTable.table_get(lid, "BAD_CHUNK", "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_has(lid, "BAD_CHUNK", "k")

        # GRUG: Empty key throws LobeTableError
        @test_throws LobeTable.LobeTableError LobeTable.table_put!(lid, LobeTable.CHUNK_META, "", "v")
        @test_throws LobeTable.LobeTableError LobeTable.table_put!(lid, LobeTable.CHUNK_META, "  ", "v")
        @test_throws LobeTable.LobeTableError LobeTable.table_get(lid, LobeTable.CHUNK_META, "")
        @test_throws LobeTable.LobeTableError LobeTable.table_has(lid, LobeTable.CHUNK_META, "")
        @test_throws LobeTable.LobeTableError LobeTable.table_delete!(lid, LobeTable.CHUNK_META, "")

        # GRUG: Empty lobe_id in all ops throws
        @test_throws LobeTable.LobeTableError LobeTable.table_put!("", LobeTable.CHUNK_META, "k", "v")
        @test_throws LobeTable.LobeTableError LobeTable.table_get("", LobeTable.CHUNK_META, "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_has("", LobeTable.CHUNK_META, "k")
        @test_throws LobeTable.LobeTableError LobeTable.table_delete!("", LobeTable.CHUNK_META, "k")
    end

    # =========================================================================
    # SECTION 4: TABLE KEYS + SIZE
    # =========================================================================

    @testset "table_keys / table_size" begin
        lid = fresh_lobe("keys")

        # GRUG: Empty chunk has 0 size and no keys
        @test LobeTable.table_size(lid, LobeTable.CHUNK_META) == 0
        @test isempty(LobeTable.table_keys(lid, LobeTable.CHUNK_META))

        # GRUG: After inserts, size and keys match
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "a", 1)
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "b", 2)
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "c", 3)

        @test LobeTable.table_size(lid, LobeTable.CHUNK_META) == 3
        ks = LobeTable.table_keys(lid, LobeTable.CHUNK_META)
        @test length(ks) == 3
        @test "a" in ks
        @test "b" in ks
        @test "c" in ks

        # GRUG: After delete, size decrements
        LobeTable.table_delete!(lid, LobeTable.CHUNK_META, "b")
        @test LobeTable.table_size(lid, LobeTable.CHUNK_META) == 2
        @test !("b" in LobeTable.table_keys(lid, LobeTable.CHUNK_META))

        # GRUG: Keys returns a copy (not a live reference)
        ks_copy = LobeTable.table_keys(lid, LobeTable.CHUNK_META)
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "d", 4)
        @test length(ks_copy) == 2  # snapshot, not updated
    end

    # =========================================================================
    # SECTION 5: TABLE MATCH - Pattern Activation
    # =========================================================================

    @testset "table_match :exact mode" begin
        lid = fresh_lobe("match_exact")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "hello_world", "value1")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "goodbye",     "value2")

        # GRUG: Exact match finds the key
        hits = LobeTable.table_match(lid, LobeTable.CHUNK_META, "hello_world", mode=:exact)
        @test length(hits) == 1
        @test hits["hello_world"] == "value1"

        # GRUG: Exact match misses non-matching key
        hits2 = LobeTable.table_match(lid, LobeTable.CHUNK_META, "hello", mode=:exact)
        @test isempty(hits2)
    end

    @testset "table_match :prefix mode" begin
        lid = fresh_lobe("match_prefix")
        LobeTable.table_put!(lid, LobeTable.CHUNK_JSON, "node_0:color",  "red")
        LobeTable.table_put!(lid, LobeTable.CHUNK_JSON, "node_0:weight", 1.5)
        LobeTable.table_put!(lid, LobeTable.CHUNK_JSON, "node_1:color",  "blue")
        LobeTable.table_put!(lid, LobeTable.CHUNK_JSON, "node_1:size",   "large")

        # GRUG: Prefix "node_0:" finds all node_0 fields
        hits = LobeTable.table_match(lid, LobeTable.CHUNK_JSON, "node_0:", mode=:prefix)
        @test length(hits) == 2
        @test haskey(hits, "node_0:color")
        @test haskey(hits, "node_0:weight")
        @test !haskey(hits, "node_1:color")

        # GRUG: Prefix "node_1:" finds all node_1 fields only
        hits2 = LobeTable.table_match(lid, LobeTable.CHUNK_JSON, "node_1:", mode=:prefix)
        @test length(hits2) == 2
        @test haskey(hits2, "node_1:color")
        @test haskey(hits2, "node_1:size")

        # GRUG: Non-matching prefix returns empty
        hits3 = LobeTable.table_match(lid, LobeTable.CHUNK_JSON, "node_99:", mode=:prefix)
        @test isempty(hits3)
    end

    @testset "table_match :token mode" begin
        lid = fresh_lobe("match_token")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "happy_feeling",   "joy")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "sadness_feeling", "grief")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "angry_emotion",   "rage")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "joyful_state",    "bliss")

        # GRUG: Token "feeling" activates both feeling entries
        hits = LobeTable.table_match(lid, LobeTable.CHUNK_META, "feeling", mode=:token)
        @test length(hits) == 2
        @test haskey(hits, "happy_feeling")
        @test haskey(hits, "sadness_feeling")

        # GRUG: Token "happy" activates only happy entry
        hits2 = LobeTable.table_match(lid, LobeTable.CHUNK_META, "happy", mode=:token)
        @test length(hits2) == 1
        @test haskey(hits2, "happy_feeling")

        # GRUG: Multiple tokens - ANY match activates entry
        hits3 = LobeTable.table_match(lid, LobeTable.CHUNK_META, "happy angry", mode=:token)
        @test length(hits3) == 2
        @test haskey(hits3, "happy_feeling")
        @test haskey(hits3, "angry_emotion")

        # GRUG: No match returns empty
        hits4 = LobeTable.table_match(lid, LobeTable.CHUNK_META, "zzznomatch", mode=:token)
        @test isempty(hits4)

        # GRUG: Token match is case-insensitive
        hits5 = LobeTable.table_match(lid, LobeTable.CHUNK_META, "FEELING", mode=:token)
        @test length(hits5) == 2
    end

    @testset "table_match :regex mode" begin
        lid = fresh_lobe("match_regex")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "node_001", "alpha")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "node_002", "beta")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "edge_001", "gamma")

        # GRUG: Regex matches node_ prefix entries only
        hits = LobeTable.table_match(lid, LobeTable.CHUNK_META, "^node_", mode=:regex)
        @test length(hits) == 2
        @test haskey(hits, "node_001")
        @test haskey(hits, "node_002")
        @test !haskey(hits, "edge_001")

        # GRUG: Regex digit pattern - raw string avoids $ interpolation
        hits2 = LobeTable.table_match(lid, LobeTable.CHUNK_META, raw"_001$", mode=:regex)
        @test length(hits2) == 2
        @test haskey(hits2, "node_001")
        @test haskey(hits2, "edge_001")

        # GRUG: Bad regex throws LobeTableError
        @test_throws LobeTable.LobeTableError LobeTable.table_match(lid, LobeTable.CHUNK_META, "[invalid", mode=:regex)
    end

    @testset "table_match error cases" begin
        lid = fresh_lobe("match_err")

        # GRUG: Empty pattern throws
        @test_throws LobeTable.LobeTableError LobeTable.table_match(lid, LobeTable.CHUNK_META, "")
        @test_throws LobeTable.LobeTableError LobeTable.table_match(lid, LobeTable.CHUNK_META, "   ")

        # GRUG: Unknown mode throws
        @test_throws LobeTable.LobeTableError LobeTable.table_match(lid, LobeTable.CHUNK_META, "pat", mode=:badmode)

        # GRUG: Non-existent lobe throws
        @test_throws LobeTable.LobeTableError LobeTable.table_match("no_lobe", LobeTable.CHUNK_META, "pat")
    end

    # =========================================================================
    # SECTION 6: JSON TO TABLE CHUNK
    # =========================================================================

    @testset "json_to_table_chunk!" begin
        lid = fresh_lobe("json_chunk")

        # GRUG: Store json_data for a node
        json_data = Dict{String,Any}("color" => "red", "weight" => 1.5, "tags" => ["a", "b"])
        count = LobeTable.json_to_table_chunk!(lid, "node_10", json_data)
        @test count == 3

        # GRUG: Each field stored as "node_id:field_name"
        @test LobeTable.table_has(lid, LobeTable.CHUNK_JSON, "node_10:color")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_JSON, "node_10:weight")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_JSON, "node_10:tags")

        # GRUG: Values stored correctly
        @test LobeTable.table_get(lid, LobeTable.CHUNK_JSON, "node_10:color") == "red"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_JSON, "node_10:weight") == 1.5

        # GRUG: Empty json_data returns 0, no error
        count2 = LobeTable.json_to_table_chunk!(lid, "node_11", Dict{String,Any}())
        @test count2 == 0

        # GRUG: Multiple nodes in same lobe don't interfere
        json2 = Dict{String,Any}("color" => "blue", "size" => "large")
        LobeTable.json_to_table_chunk!(lid, "node_12", json2)
        @test LobeTable.table_get(lid, LobeTable.CHUNK_JSON, "node_12:color") == "blue"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_JSON, "node_10:color") == "red"  # unchanged

        # GRUG: Error on empty lobe_id or node_id
        @test_throws LobeTable.LobeTableError LobeTable.json_to_table_chunk!("", "node_10", json_data)
        @test_throws LobeTable.LobeTableError LobeTable.json_to_table_chunk!(lid, "", json_data)
    end

    @testset "get_json_for_node" begin
        lid = fresh_lobe("json_recon")

        # GRUG: Store then reconstruct json_data
        json_data = Dict{String,Any}("alpha" => 1, "beta" => "two", "gamma" => 3.0)
        LobeTable.json_to_table_chunk!(lid, "node_20", json_data)

        recovered = LobeTable.get_json_for_node(lid, "node_20")
        @test length(recovered) == 3
        @test recovered["alpha"] == 1
        @test recovered["beta"] == "two"
        @test recovered["gamma"] == 3.0

        # GRUG: Node with no json data returns empty dict
        empty_rec = LobeTable.get_json_for_node(lid, "node_99")
        @test isempty(empty_rec)

        # GRUG: Two nodes don't bleed into each other
        json2 = Dict{String,Any}("x" => 100)
        LobeTable.json_to_table_chunk!(lid, "node_21", json2)
        rec1 = LobeTable.get_json_for_node(lid, "node_20")
        rec2 = LobeTable.get_json_for_node(lid, "node_21")
        @test length(rec1) == 3
        @test length(rec2) == 1

        # GRUG: Error on empty args
        @test_throws LobeTable.LobeTableError LobeTable.get_json_for_node("", "node_20")
        @test_throws LobeTable.LobeTableError LobeTable.get_json_for_node(lid, "")
    end

    # =========================================================================
    # SECTION 7: DROP TABLE TO CHUNK
    # =========================================================================

    @testset "drop_table_to_chunk!" begin
        lid = fresh_lobe("drop_chunk")

        # GRUG: Store drop table for a node
        drop_table = ["node_b", "node_c", "node_d"]
        count = LobeTable.drop_table_to_chunk!(lid, "node_a", drop_table)
        @test count == 3

        # GRUG: Each entry stored as "node_a:target_id" -> true
        @test LobeTable.table_has(lid, LobeTable.CHUNK_DROP, "node_a:node_b")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_DROP, "node_a:node_c")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_DROP, "node_a:node_d")
        @test LobeTable.table_get(lid, LobeTable.CHUNK_DROP, "node_a:node_b") == true

        # GRUG: Empty drop table returns 0, no error
        count2 = LobeTable.drop_table_to_chunk!(lid, "node_a", String[])
        @test count2 == 0

        # GRUG: Error on empty lobe_id or node_id
        @test_throws LobeTable.LobeTableError LobeTable.drop_table_to_chunk!("", "node_a", drop_table)
        @test_throws LobeTable.LobeTableError LobeTable.drop_table_to_chunk!(lid, "", drop_table)
    end

    @testset "get_drop_neighbors" begin
        lid = fresh_lobe("drop_get")

        # GRUG: Store then retrieve drop neighbors
        LobeTable.drop_table_to_chunk!(lid, "node_x", ["node_y", "node_z"])
        neighbors = LobeTable.get_drop_neighbors(lid, "node_x")
        @test length(neighbors) == 2
        @test "node_y" in neighbors
        @test "node_z" in neighbors

        # GRUG: Node with no drop entries returns empty
        empty_n = LobeTable.get_drop_neighbors(lid, "node_lonely")
        @test isempty(empty_n)

        # GRUG: Two nodes' drop tables don't interfere
        LobeTable.drop_table_to_chunk!(lid, "node_q", ["node_r"])
        nx = LobeTable.get_drop_neighbors(lid, "node_x")
        nq = LobeTable.get_drop_neighbors(lid, "node_q")
        @test length(nx) == 2
        @test length(nq) == 1

        # GRUG: Error on empty args
        @test_throws LobeTable.LobeTableError LobeTable.get_drop_neighbors("", "node_x")
        @test_throws LobeTable.LobeTableError LobeTable.get_drop_neighbors(lid, "")
    end

    # =========================================================================
    # SECTION 8: HOPFIELD CHUNK OPS
    # =========================================================================

    @testset "hopfield_put! / hopfield_get / hopfield_has" begin
        lid = fresh_lobe("hopfield")

        h1 = UInt64(12345)
        h2 = UInt64(99999)
        ids1 = ["node_a", "node_b"]
        ids2 = ["node_c"]

        # GRUG: Store and retrieve hopfield entries
        LobeTable.hopfield_put!(lid, h1, ids1)
        result = LobeTable.hopfield_get(lid, h1)
        @test !isnothing(result)
        @test result == ids1

        # GRUG: Different hash stored independently
        LobeTable.hopfield_put!(lid, h2, ids2)
        r2 = LobeTable.hopfield_get(lid, h2)
        @test r2 == ids2

        # GRUG: hopfield_has returns true for stored hash
        @test LobeTable.hopfield_has(lid, h1)
        @test LobeTable.hopfield_has(lid, h2)

        # GRUG: hopfield_has returns false for unstored hash
        @test !LobeTable.hopfield_has(lid, UInt64(77777))

        # GRUG: hopfield_get returns nothing for unstored hash
        @test isnothing(LobeTable.hopfield_get(lid, UInt64(88888)))

        # GRUG: Error on empty lobe_id
        @test_throws LobeTable.LobeTableError LobeTable.hopfield_put!("", h1, ids1)
        @test_throws LobeTable.LobeTableError LobeTable.hopfield_get("", h1)
        @test_throws LobeTable.LobeTableError LobeTable.hopfield_has("", h1)

        # GRUG: Error on empty node_ids
        @test_throws LobeTable.LobeTableError LobeTable.hopfield_put!(lid, h1, String[])
    end

    # =========================================================================
    # SECTION 9: NODE REF CHUNK OPS
    # =========================================================================

    @testset "node_ref_put! / node_ref_deactivate! / node_ref_remove! / get_active_node_ids" begin
        lid = fresh_lobe("noderef")

        # GRUG: Register nodes
        LobeTable.node_ref_put!(lid, "node_100")
        LobeTable.node_ref_put!(lid, "node_101")
        LobeTable.node_ref_put!(lid, "node_102")

        # GRUG: All three are in the node chunk
        @test LobeTable.table_has(lid, LobeTable.CHUNK_NODES, "node_100")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_NODES, "node_101")
        @test LobeTable.table_has(lid, LobeTable.CHUNK_NODES, "node_102")

        # GRUG: NodeRef stored with correct fields
        ref = LobeTable.table_get(lid, LobeTable.CHUNK_NODES, "node_100")
        @test ref isa LobeTable.NodeRef
        @test ref.node_id == "node_100"
        @test ref.lobe_id == lid
        @test ref.is_active == true

        # GRUG: get_active_node_ids returns all active nodes
        active = LobeTable.get_active_node_ids(lid)
        @test length(active) == 3
        @test "node_100" in active

        # GRUG: Deactivate a node - still in chunk but is_active=false
        result = LobeTable.node_ref_deactivate!(lid, "node_101")
        @test result == true
        ref101 = LobeTable.table_get(lid, LobeTable.CHUNK_NODES, "node_101")
        @test ref101.is_active == false

        # GRUG: get_active_node_ids excludes deactivated nodes
        active2 = LobeTable.get_active_node_ids(lid)
        @test length(active2) == 2
        @test !("node_101" in active2)
        @test "node_100" in active2
        @test "node_102" in active2

        # GRUG: node_ref_remove! fully removes from chunk
        removed = LobeTable.node_ref_remove!(lid, "node_102")
        @test removed == true
        @test !LobeTable.table_has(lid, LobeTable.CHUNK_NODES, "node_102")

        # GRUG: get_active_node_ids now only has node_100
        active3 = LobeTable.get_active_node_ids(lid)
        @test length(active3) == 1
        @test "node_100" in active3

        # GRUG: Deactivate non-existent node returns false (not an error)
        r2 = LobeTable.node_ref_deactivate!(lid, "node_999")
        @test r2 == false

        # GRUG: Remove non-existent node returns false
        r3 = LobeTable.node_ref_remove!(lid, "node_999")
        @test r3 == false

        # GRUG: Error on empty args
        @test_throws LobeTable.LobeTableError LobeTable.node_ref_put!("", "node_100")
        @test_throws LobeTable.LobeTableError LobeTable.node_ref_put!(lid, "")
        @test_throws LobeTable.LobeTableError LobeTable.get_active_node_ids("")
    end

    # =========================================================================
    # SECTION 10: PER-LOBE ISOLATION
    # =========================================================================

    @testset "Per-lobe isolation - Cave A never bleeds into Cave B" begin
        lobe_a = fresh_lobe("iso_a")
        lobe_b = fresh_lobe("iso_b")

        # GRUG: Put in lobe A
        LobeTable.table_put!(lobe_a, LobeTable.CHUNK_META, "shared_key", "from_a")
        LobeTable.table_put!(lobe_b, LobeTable.CHUNK_META, "shared_key", "from_b")

        # GRUG: Each lobe has its own value - no bleeding
        @test LobeTable.table_get(lobe_a, LobeTable.CHUNK_META, "shared_key") == "from_a"
        @test LobeTable.table_get(lobe_b, LobeTable.CHUNK_META, "shared_key") == "from_b"

        # GRUG: Delete from A doesn't affect B
        LobeTable.table_delete!(lobe_a, LobeTable.CHUNK_META, "shared_key")
        @test !LobeTable.table_has(lobe_a, LobeTable.CHUNK_META, "shared_key")
        @test LobeTable.table_has(lobe_b, LobeTable.CHUNK_META, "shared_key")

        # GRUG: Node refs are per-lobe
        LobeTable.node_ref_put!(lobe_a, "node_shared")
        @test LobeTable.table_has(lobe_a, LobeTable.CHUNK_NODES, "node_shared")
        @test !LobeTable.table_has(lobe_b, LobeTable.CHUNK_NODES, "node_shared")

        # GRUG: JSON chunks are per-lobe
        LobeTable.json_to_table_chunk!(lobe_a, "node_j", Dict{String,Any}("x" => 1))
        @test LobeTable.table_has(lobe_a, LobeTable.CHUNK_JSON, "node_j:x")
        @test !LobeTable.table_has(lobe_b, LobeTable.CHUNK_JSON, "node_j:x")

        # GRUG: Drop chunks are per-lobe
        LobeTable.drop_table_to_chunk!(lobe_a, "node_d", ["node_e"])
        @test LobeTable.table_has(lobe_a, LobeTable.CHUNK_DROP, "node_d:node_e")
        @test !LobeTable.table_has(lobe_b, LobeTable.CHUNK_DROP, "node_d:node_e")

        # GRUG: Hopfield is per-lobe
        LobeTable.hopfield_put!(lobe_a, UInt64(11111), ["node_x"])
        @test LobeTable.hopfield_has(lobe_a, UInt64(11111))
        @test !LobeTable.hopfield_has(lobe_b, UInt64(11111))
    end

    # =========================================================================
    # SECTION 11: DELETE LOBE TABLE
    # =========================================================================

    @testset "delete_lobe_table!" begin
        lid = fresh_lobe("del")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "k", "v")
        @test LobeTable.table_exists(lid)

        # GRUG: Delete removes the table
        result = LobeTable.delete_lobe_table!(lid)
        @test result == true
        @test !LobeTable.table_exists(lid)

        # GRUG: Delete of non-existent table returns false (not an error)
        result2 = LobeTable.delete_lobe_table!("never_existed_xyz")
        @test result2 == false

        # GRUG: Operations on deleted lobe throw
        @test_throws LobeTable.LobeTableError LobeTable.table_get(lid, LobeTable.CHUNK_META, "k")

        # GRUG: Empty lobe_id throws
        @test_throws LobeTable.LobeTableError LobeTable.delete_lobe_table!("")
    end

    # =========================================================================
    # SECTION 12: STATUS / SUMMARY
    # =========================================================================

    @testset "get_table_summary / get_all_table_summaries" begin
        lid = fresh_lobe("summary")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "k1", "v1")
        LobeTable.table_put!(lid, LobeTable.CHUNK_META, "k2", "v2")
        LobeTable.node_ref_put!(lid, "snode_1")

        summary = LobeTable.get_table_summary(lid)
        @test occursin(lid, summary)
        @test occursin("meta", summary)
        @test occursin("nodes", summary)

        # GRUG: Summary includes at least the meta count
        @test occursin("2", summary)  # 2 meta entries

        # GRUG: get_all_table_summaries includes this lobe
        all_summary = LobeTable.get_all_table_summaries()
        @test occursin(lid, all_summary)

        # GRUG: Error on non-existent lobe
        @test_throws LobeTable.LobeTableError LobeTable.get_table_summary("nonexistent_lobe_xyz")

        # GRUG: Error on empty lobe_id
        @test_throws LobeTable.LobeTableError LobeTable.get_table_summary("")
    end

    # =========================================================================
    # SECTION 13: ALL CHUNKS INDEPENDENT PER LOBE
    # =========================================================================

    @testset "All 5 chunks operate independently in same lobe" begin
        lid = fresh_lobe("allchunks")

        # GRUG: Each chunk has its own key space - same key in different chunks is fine
        LobeTable.table_put!(lid, LobeTable.CHUNK_META,     "key1", "meta_val")
        LobeTable.table_put!(lid, LobeTable.CHUNK_JSON,     "key1", "json_val")
        LobeTable.table_put!(lid, LobeTable.CHUNK_DROP,     "key1", "drop_val")
        LobeTable.table_put!(lid, LobeTable.CHUNK_HOPFIELD, "key1", "hopf_val")
        LobeTable.table_put!(lid, LobeTable.CHUNK_NODES,    "key1", "node_val")

        @test LobeTable.table_get(lid, LobeTable.CHUNK_META,     "key1") == "meta_val"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_JSON,     "key1") == "json_val"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_DROP,     "key1") == "drop_val"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_HOPFIELD, "key1") == "hopf_val"
        @test LobeTable.table_get(lid, LobeTable.CHUNK_NODES,    "key1") == "node_val"

        # GRUG: Delete from one chunk doesn't affect others
        LobeTable.table_delete!(lid, LobeTable.CHUNK_META, "key1")
        @test !LobeTable.table_has(lid, LobeTable.CHUNK_META,     "key1")
        @test  LobeTable.table_has(lid, LobeTable.CHUNK_JSON,     "key1")
        @test  LobeTable.table_has(lid, LobeTable.CHUNK_DROP,     "key1")
        @test  LobeTable.table_has(lid, LobeTable.CHUNK_HOPFIELD, "key1")
        @test  LobeTable.table_has(lid, LobeTable.CHUNK_NODES,    "key1")
    end

end # @testset LobeTable - Full Test Suite

println("✅ LobeTable.jl tests complete.")