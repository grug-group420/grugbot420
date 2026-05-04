# LobeTable.jl - GRUG Per-Lobe Chunked Hash Table Storage
# GRUG say: flat lists are dumb rock piles. Hash tables are smart rock organizers.
# GRUG say: every lobe gets its OWN table. No mixing caves!
# GRUG say: table is chunked into sections. Each section has ONE job.
# GRUG say: pattern-activated lookup! Key or prefix or token match. No blind scanning.
# GRUG say: JSON goes in as proper chunk storage. Drop table goes in as hash. No vectors!
# GRUG say: error first. No silent failures. If chunk missing, Grug screams.

module LobeTable

# ============================================================================
# ERROR TYPES - GRUG hate silent failures!
# ============================================================================

struct LobeTableError <: Exception
    message::String
    context::String
end

function throw_table_error(msg::String, ctx::String = "unknown")
    throw(LobeTableError(msg, ctx))
end

# ============================================================================
# CHUNK NAMES - GRUG like named sections. No magic strings in caller code.
# ============================================================================

# GRUG: These are the valid chunk names for a LobeTable.
# Each chunk is a separate hash table with its own key space.
# - CHUNK_NODES     : node_id -> NodeRef (lightweight handle, not full Node copy)
# - CHUNK_JSON      : "field_name:node_id" -> Any  (json_data per node per lobe)
# - CHUNK_DROP      : pattern_hash_key -> Set{String} of node_ids (drop table lookup)
# - CHUNK_HOPFIELD  : input_hash_str -> Vector{String} of node_ids (familiar input cache)
# - CHUNK_META      : arbitrary lobe-level metadata key -> Any
const CHUNK_NODES    = "nodes"
const CHUNK_JSON     = "json"
const CHUNK_DROP     = "drop"
const CHUNK_HOPFIELD = "hopfield"
const CHUNK_META     = "meta"

const VALID_CHUNKS = Set{String}([CHUNK_NODES, CHUNK_JSON, CHUNK_DROP, CHUNK_HOPFIELD, CHUNK_META])

# ============================================================================
# NODE REF - Lightweight handle stored in CHUNK_NODES
# GRUG: We do NOT store full Node copies. We store a ref: id + lobe_id + alive flag.
# The actual Node lives in engine.jl NODE_MAP. This chunk is the lobe's index.
# ============================================================================

mutable struct NodeRef
    node_id   ::String
    lobe_id   ::String
    is_active ::Bool          # GRUG: false when node is graved or removed
    inserted_at::Float64      # GRUG: unix timestamp of insertion
end

# ============================================================================
# LOBE TABLE CHUNK - One named section of a lobe's hash table
# GRUG: Each chunk is just a Dict with a name and a lock.
# The lock is per-chunk so different chunks don't block each other.
# ============================================================================

mutable struct LobeTableChunk
    name    ::String
    store   ::Dict{String, Any}   # GRUG: The actual hash table storage
    lock    ::ReentrantLock
end

function new_chunk(name::String)::LobeTableChunk
    if !(name in VALID_CHUNKS)
        valid_list = join(sort(collect(VALID_CHUNKS)), ", ")
        throw_table_error("Unknown chunk name '$name'. Valid: $valid_list", "new_chunk")
    end
    return LobeTableChunk(name, Dict{String, Any}(), ReentrantLock())
end

# ============================================================================
# LOBE TABLE - Collection of all chunks for one lobe
# GRUG: One LobeTable per lobe. Chunks are pre-allocated at creation time.
# ============================================================================

mutable struct LobeTableRecord
    lobe_id    ::String
    chunks     ::Dict{String, LobeTableChunk}
    created_at ::Float64
end

# ============================================================================
# GLOBAL TABLE REGISTRY - GRUG keep all lobe tables here
# ============================================================================

const LOBE_TABLE_REGISTRY = Dict{String, LobeTableRecord}()
const TABLE_REGISTRY_LOCK = ReentrantLock()

# ============================================================================
# CREATE LOBE TABLE - Init all chunks for a new lobe
# GRUG: Called when a lobe is created. Pre-allocates all chunk buckets.
# Idempotent: calling twice for same lobe is a no-op (not an error).
# ============================================================================

function create_lobe_table!(lobe_id::String)::LobeTableRecord
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "create_lobe_table!")
    end
    lock(TABLE_REGISTRY_LOCK) do
        if haskey(LOBE_TABLE_REGISTRY, lobe_id)
            # GRUG: Idempotent. Already exists, return existing.
            return LOBE_TABLE_REGISTRY[lobe_id]
        end
        chunks = Dict{String, LobeTableChunk}()
        for cname in VALID_CHUNKS
            chunks[cname] = new_chunk(cname)
        end
        rec = LobeTableRecord(lobe_id, chunks, time())
        LOBE_TABLE_REGISTRY[lobe_id] = rec
        return rec
    end
end

# ============================================================================
# INTERNAL: GET CHUNK - Resolve lobe + chunk name to LobeTableChunk
# GRUG: Used by all table_* functions. Fails loudly if lobe or chunk missing.
# ============================================================================

function _get_chunk(lobe_id::String, chunk_name::String)::LobeTableChunk
    # GRUG: Validate chunk name first (cheap check before lock)
    if !(chunk_name in VALID_CHUNKS)
        throw_table_error("Unknown chunk '$chunk_name'", "_get_chunk")
    end
    lock(TABLE_REGISTRY_LOCK) do
        if !haskey(LOBE_TABLE_REGISTRY, lobe_id)
            throw_table_error("No table found for lobe '$lobe_id'. Call create_lobe_table! first.", "_get_chunk")
        end
        return LOBE_TABLE_REGISTRY[lobe_id].chunks[chunk_name]
    end
end

# ============================================================================
# TABLE PUT - Insert or update a key in a chunk
# GRUG: O(1) insert. Key must be non-empty string. Value can be anything.
# ============================================================================

function table_put!(lobe_id::String, chunk_name::String, key::String, value::Any)
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "table_put!")
    end
    if isempty(strip(key))
        throw_table_error("key cannot be empty", "table_put!")
    end
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        chunk.store[key] = value
    end
end

# ============================================================================
# TABLE GET - O(1) key lookup in a chunk
# GRUG: Returns value or nothing. Never throws on missing key.
# Use table_get! if you want an error on missing key.
# ============================================================================

function table_get(lobe_id::String, chunk_name::String, key::String)::Union{Any, Nothing}
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "table_get")
    end
    if isempty(strip(key))
        throw_table_error("key cannot be empty", "table_get")
    end
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        return get(chunk.store, key, nothing)
    end
end

# ============================================================================
# TABLE GET! - O(1) key lookup that throws if key missing
# GRUG: Use when missing key is always a programmer error.
# ============================================================================

function table_get!(lobe_id::String, chunk_name::String, key::String)::Any
    val = table_get(lobe_id, chunk_name, key)
    if isnothing(val)
        throw_table_error("Key '$key' not found in chunk '$chunk_name' for lobe '$lobe_id'", "table_get!")
    end
    return val
end

# ============================================================================
# TABLE HAS - Check key existence in a chunk
# ============================================================================

function table_has(lobe_id::String, chunk_name::String, key::String)::Bool
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "table_has")
    end
    if isempty(strip(key))
        throw_table_error("key cannot be empty", "table_has")
    end
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        return haskey(chunk.store, key)
    end
end

# ============================================================================
# TABLE DELETE - Remove a key from a chunk
# GRUG: Returns true if key existed and was deleted. False if key wasn't there.
# Not an error to delete a nonexistent key - just returns false.
# ============================================================================

function table_delete!(lobe_id::String, chunk_name::String, key::String)::Bool
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "table_delete!")
    end
    if isempty(strip(key))
        throw_table_error("key cannot be empty", "table_delete!")
    end
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        if haskey(chunk.store, key)
            delete!(chunk.store, key)
            return true
        end
        return false
    end
end

# ============================================================================
# TABLE KEYS - All keys in a chunk
# GRUG: Returns snapshot of keys at call time. Safe copy, not live reference.
# ============================================================================

function table_keys(lobe_id::String, chunk_name::String)::Vector{String}
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        return collect(keys(chunk.store))
    end
end

# ============================================================================
# TABLE SIZE - How many entries in a chunk
# ============================================================================

function table_size(lobe_id::String, chunk_name::String)::Int
    chunk = _get_chunk(lobe_id, chunk_name)
    lock(chunk.lock) do
        return length(chunk.store)
    end
end

# ============================================================================
# TABLE MATCH - Pattern-activated lookup
# GRUG: The smart lookup. Finds all keys in a chunk that match a pattern.
# mode = :exact   -> exact key match (same as table_get but returns Dict)
# mode = :prefix  -> all keys starting with prefix string
# mode = :token   -> all keys containing any token from pattern (space-split)
# mode = :regex   -> all keys matching a Regex pattern
# Returns Dict{String, Any} of matching key->value pairs.
# GRUG: This is the "activation" part. Input pattern activates matching entries.
# ============================================================================

function table_match(
    lobe_id    ::String,
    chunk_name ::String,
    pattern    ::String;
    mode       ::Symbol = :token
)::Dict{String, Any}

    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "table_match")
    end
    if isempty(strip(pattern))
        throw_table_error("pattern cannot be empty", "table_match")
    end
    if !(mode in (:exact, :prefix, :token, :regex))
        throw_table_error("Unknown match mode '$mode'. Use :exact, :prefix, :token, or :regex", "table_match")
    end

    chunk = _get_chunk(lobe_id, chunk_name)
    results = Dict{String, Any}()

    lock(chunk.lock) do
        if mode == :exact
            # GRUG: Single key lookup wrapped in dict for uniform return type
            if haskey(chunk.store, pattern)
                results[pattern] = chunk.store[pattern]
            end

        elseif mode == :prefix
            # GRUG: All keys that start with the pattern string
            p_lower = lowercase(pattern)
            for (k, v) in chunk.store
                if startswith(lowercase(k), p_lower)
                    results[k] = v
                end
            end

        elseif mode == :token
            # GRUG: Split pattern into tokens. Key matches if it contains ANY token.
            # Case-insensitive. This is the "associative activation" mode.
            tokens = filter(!isempty, map(t -> lowercase(strip(t)), split(pattern)))
            if isempty(tokens)
                throw_table_error("pattern produced no tokens after split", "table_match :token")
            end
            for (k, v) in chunk.store
                k_lower = lowercase(k)
                for tok in tokens
                    if occursin(tok, k_lower)
                        results[k] = v
                        break  # GRUG: One token match is enough to activate
                    end
                end
            end

        elseif mode == :regex
            # GRUG: Full regex match. Pattern is treated as regex string.
            # Grug warn: bad regex throws LobeTableError, not raw Julia error.
            rx = try
                Regex(pattern)
            catch e
                throw_table_error("Invalid regex pattern '$pattern': $e", "table_match :regex")
            end
            for (k, v) in chunk.store
                if occursin(rx, k)
                    results[k] = v
                end
            end
        end
    end

    return results
end

# ============================================================================
# JSON TO TABLE CHUNK - Convert json_data Dict into proper chunk storage
# GRUG: json_data from node creation is a flat Dict{String,Any}.
# We store each field as: key = "field_name:node_id" -> value
# This lets us look up ALL fields for a node OR all nodes with a field name.
# Pattern: table_match(lobe_id, CHUNK_JSON, node_id, mode=:prefix) gets all fields.
# Pattern: table_match(lobe_id, CHUNK_JSON, "field_name", mode=:token) gets all nodes with field.
# ============================================================================

function json_to_table_chunk!(lobe_id::String, node_id::String, json_data::Dict)
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "json_to_table_chunk!")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "json_to_table_chunk!")
    end
    if isempty(json_data)
        # GRUG: Empty json_data is fine. Nothing to store. Not an error.
        return 0
    end

    count = 0
    for (field, value) in json_data
        # GRUG: Key format: "node_id:field_name" for easy prefix lookup per node
        composite_key = "$(node_id):$(string(field))"
        table_put!(lobe_id, CHUNK_JSON, composite_key, value)
        count += 1
    end
    return count
end

# ============================================================================
# GET JSON FOR NODE - Reconstruct json_data dict from chunk for a node
# GRUG: Reverse of json_to_table_chunk!. Pulls all fields back into a Dict.
# Uses prefix match on node_id to find all "node_id:field_name" entries.
# ============================================================================

function get_json_for_node(lobe_id::String, node_id::String)::Dict{String, Any}
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "get_json_for_node")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "get_json_for_node")
    end

    # GRUG: Prefix match: "node_id:" finds all fields for this node
    prefix = "$(node_id):"
    matches = table_match(lobe_id, CHUNK_JSON, prefix, mode=:prefix)
    result = Dict{String, Any}()
    prefix_len = length(prefix)
    for (composite_key, value) in matches
        # GRUG: Strip "node_id:" prefix to recover field name
        field_name = composite_key[prefix_len+1:end]
        result[field_name] = value
    end
    return result
end

# ============================================================================
# DROP TABLE TO CHUNK - Convert drop_table Vector{String} to hash chunk
# GRUG: drop_table is a list of node_ids that co-activate with this node.
# Old way: Vector{String} scanned linearly. New way: hash table.
# Key format: "drop:node_id:target_id" -> true (existence = relationship)
# Also index by pattern hash: pattern_hash -> Set{String} of target node_ids
# This enables O(1) existence check AND pattern-based activation of drop neighbors.
# ============================================================================

function drop_table_to_chunk!(lobe_id::String, node_id::String, drop_table::Vector{String})
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "drop_table_to_chunk!")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "drop_table_to_chunk!")
    end
    if isempty(drop_table)
        # GRUG: Empty drop table is fine. Not an error.
        return 0
    end

    count = 0
    for target_id in drop_table
        if isempty(strip(target_id))
            # GRUG: Skip empty target ids in drop table. Warn but don't crash.
            @warn "[LobeTable] drop_table_to_chunk!: empty target_id in drop table for node '$node_id', skipping."
            continue
        end
        # GRUG: Key = "node_id:target_id" -> true. O(1) existence check.
        drop_key = "$(node_id):$(target_id)"
        table_put!(lobe_id, CHUNK_DROP, drop_key, true)
        count += 1
    end
    return count
end

# ============================================================================
# GET DROP NEIGHBORS - Retrieve all drop table targets for a node from chunk
# GRUG: Prefix match on "node_id:" to find all drop relationships for this node.
# Returns Vector{String} of target node_ids. Equivalent to old drop_table field.
# ============================================================================

function get_drop_neighbors(lobe_id::String, node_id::String)::Vector{String}
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "get_drop_neighbors")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "get_drop_neighbors")
    end

    prefix = "$(node_id):"
    matches = table_match(lobe_id, CHUNK_DROP, prefix, mode=:prefix)
    prefix_len = length(prefix)
    result = String[]
    for (drop_key, _) in matches
        target_id = drop_key[prefix_len+1:end]
        push!(result, target_id)
    end
    return result
end

# ============================================================================
# HOPFIELD CHUNK OPS - Per-lobe familiar input cache
# GRUG: Replaces global HOPFIELD_CACHE. Each lobe has its own hopfield chunk.
# Key = string(input_hash::UInt64) -> Vector{String} of node_ids
# ============================================================================
# GRUG: HOPFIELD CHUNK OPS - DISABLED
# ==============================================================================
# Hopfield caching has been DISABLED for per-lobe chunk operations.
# Pattern bind phase is blazing fast even without caching, and the Hopfield
# system introduces unnecessary complexity. Hopfield caching should only be used
# for RIDICULOUSLY LARGE lobe sizes (50,000+ nodes per lobe) where memory access
# becomes a bottleneck. Current lobe architecture with 1000 node cap per cycle
# makes this obsolete.
# ============================================================================
#
function hopfield_put!(lobe_id::String, input_hash::UInt64, node_ids::Vector{String})
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "hopfield_put!")
    end
    if isempty(node_ids)
        throw_table_error("node_ids cannot be empty for hopfield_put!", "hopfield_put!")
    end
    key = string(input_hash)
    table_put!(lobe_id, CHUNK_HOPFIELD, key, node_ids)
end

function hopfield_get(lobe_id::String, input_hash::UInt64)::Union{Vector{String}, Nothing}
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "hopfield_get")
    end
    key = string(input_hash)
    val = table_get(lobe_id, CHUNK_HOPFIELD, key)
    if isnothing(val)
        return nothing
    end
    # GRUG: Sanity check - stored value must be a Vector{String}
    if !(val isa Vector)
        throw_table_error("Hopfield chunk entry for key '$key' is not a Vector. Data corruption!", "hopfield_get")
    end
    return val
end

function hopfield_has(lobe_id::String, input_hash::UInt64)::Bool
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "hopfield_has")
    end
    return table_has(lobe_id, CHUNK_HOPFIELD, string(input_hash))
end

# ============================================================================
# NODE CHUNK OPS - Per-lobe node index
# GRUG: Stores NodeRef in CHUNK_NODES. Key = node_id. Value = NodeRef.
# The actual Node lives in engine.jl NODE_MAP. This is the lobe's O(1) index.
# ============================================================================

function node_ref_put!(lobe_id::String, node_id::String)
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "node_ref_put!")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "node_ref_put!")
    end
    ref = NodeRef(node_id, lobe_id, true, time())
    table_put!(lobe_id, CHUNK_NODES, node_id, ref)
end

function node_ref_deactivate!(lobe_id::String, node_id::String)
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "node_ref_deactivate!")
    end
    if isempty(strip(node_id))
        throw_table_error("node_id cannot be empty", "node_ref_deactivate!")
    end
    val = table_get(lobe_id, CHUNK_NODES, node_id)
    if isnothing(val)
        # GRUG: Node not in this lobe's chunk. Not an error - may have been removed.
        return false
    end
    if !(val isa NodeRef)
        throw_table_error("Node chunk entry for '$node_id' is not a NodeRef. Data corruption!", "node_ref_deactivate!")
    end
    val.is_active = false
    return true
end

function node_ref_remove!(lobe_id::String, node_id::String)::Bool
    return table_delete!(lobe_id, CHUNK_NODES, node_id)
end

function get_active_node_ids(lobe_id::String)::Vector{String}
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "get_active_node_ids")
    end
    chunk = _get_chunk(lobe_id, CHUNK_NODES)
    result = String[]
    lock(chunk.lock) do
        for (nid, val) in chunk.store
            if val isa NodeRef && val.is_active
                push!(result, nid)
            end
        end
    end
    return result
end

# ============================================================================
# DELETE LOBE TABLE - Remove all chunks for a lobe (lobe was deleted)
# GRUG: Called when lobe is fully removed. Cleans up all memory.
# ============================================================================

function delete_lobe_table!(lobe_id::String)::Bool
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "delete_lobe_table!")
    end
    lock(TABLE_REGISTRY_LOCK) do
        if !haskey(LOBE_TABLE_REGISTRY, lobe_id)
            return false
        end
        delete!(LOBE_TABLE_REGISTRY, lobe_id)
        return true
    end
end

# ============================================================================
# GET TABLE SUMMARY - Human-readable dump for /status and /tableStatus
# ============================================================================

function get_table_summary(lobe_id::String)::String
    if isempty(strip(lobe_id))
        throw_table_error("lobe_id cannot be empty", "get_table_summary")
    end
    lock(TABLE_REGISTRY_LOCK) do
        if !haskey(LOBE_TABLE_REGISTRY, lobe_id)
            throw_table_error("No table found for lobe '$lobe_id'", "get_table_summary")
        end
        rec = LOBE_TABLE_REGISTRY[lobe_id]
        lines = String[]
        push!(lines, "=== LOBE TABLE: $lobe_id ===")
        for cname in sort(collect(keys(rec.chunks)))
            chunk = rec.chunks[cname]
            sz = lock(chunk.lock) do; length(chunk.store); end
            push!(lines, "  [$cname] $sz entries")
        end
        return join(lines, "\n")
    end
end

# ============================================================================
# GET ALL TABLE SUMMARIES - For global /status command
# ============================================================================

function get_all_table_summaries()::String
    lock(TABLE_REGISTRY_LOCK) do
        if isempty(LOBE_TABLE_REGISTRY)
            return "[LOBE TABLE REGISTRY EMPTY]"
        end
        lines = String[]
        push!(lines, "=== ALL LOBE TABLES ($(length(LOBE_TABLE_REGISTRY)) lobes) ===")
        for lobe_id in sort(collect(keys(LOBE_TABLE_REGISTRY)))
            rec = LOBE_TABLE_REGISTRY[lobe_id]
            chunk_summary = join([
                "$(cname):$(lock(rec.chunks[cname].lock) do; length(rec.chunks[cname].store); end)"
                for cname in sort(collect(keys(rec.chunks)))
            ], " | ")
            push!(lines, "  $lobe_id -> $chunk_summary")
        end
        return join(lines, "\n")
    end
end

# ============================================================================
# TABLE EXISTS - Check if a lobe has a table
# ============================================================================

function table_exists(lobe_id::String)::Bool
    lock(TABLE_REGISTRY_LOCK) do
        return haskey(LOBE_TABLE_REGISTRY, lobe_id)
    end
end

# GRUG say: LobeTable done. Every lobe has its own chunked hash table.
# Flat lists are gone. Pattern activation works. JSON intake converts clean.
# Drop table is now O(1). Hopfield is per-lobe. Node refs indexed by lobe.
# No silent failures. Grug very happy with organized cave storage.

end # module LobeTable