# Lobe.jl - GRUG Subject-Specific Partitions for the Neuromorphic Cave
# GRUG say: cave too big. Must make small caves inside big cave.
# GRUG say: each small cave has ONE subject. Language rocks go in language cave.
# GRUG say: cave has CAP. When full, no more rocks. Error, not silence.
# GRUG say: NEW - reverse index! O(1) rock-to-cave lookup. No more walking all caves!
# GRUG say: NEW - LobeTable! Every lobe gets its own chunked hash table.
#            Flat lists gone. JSON, drop table, nodes, hopfield all in proper storage.

module Lobe

# GRUG: Load LobeTable before anything else. Lobe needs table ops at creation time.
if !isdefined(@__MODULE__, :LobeTable)
    include("LobeTable.jl")
    using .LobeTable
end

# ============================================================================
# ERROR TYPES - GRUG hate silent failures!
# ============================================================================

struct LobeError <: Exception
    message::String
    context::String
end

function throw_lobe_error(msg::String, ctx::String = "unknown")
    throw(LobeError(msg, ctx))
end

# ============================================================================
# CONSTANTS - GRUG like numbers in one place
# ============================================================================

const LOBE_NODE_CAP = 20000   # GRUG: max rocks per cave bucket
const MAX_LOBES     = 64      # GRUG: max cave buckets total

# ============================================================================
# LOBE RECORD - The cave bucket structure
# ============================================================================

mutable struct LobeRecord
    id                 ::String
    subject            ::String
    node_ids           ::Set{String}
    connected_lobe_ids ::Set{String}
    node_cap           ::Int
    fire_count         ::Int
    inhibit_count      ::Int
    created_at         ::Float64
end

# ============================================================================
# GLOBAL REGISTRY - GRUG keep list of all cave buckets here
# ============================================================================

const LOBE_REGISTRY    = Dict{String, LobeRecord}()
const LOBE_LOCK        = ReentrantLock()

# GRUG: REVERSE INDEX - node_id -> lobe_id
# O(1) exclusive membership check instead of O(N_lobes) scan!
# Must be kept in sync with every add/remove operation. Same lock guards it.
const NODE_TO_LOBE_IDX = Dict{String, String}()

# ============================================================================
# CREATE LOBE - Make new cave bucket
# ============================================================================

function create_lobe!(id::String, subject::String; node_cap::Int = LOBE_NODE_CAP)::LobeRecord
    if isempty(strip(id))
        throw_lobe_error("Lobe id cannot be empty", "create_lobe!")
    end
    if isempty(strip(subject))
        throw_lobe_error("Lobe subject cannot be empty", "create_lobe!")
    end
    if node_cap <= 0
        throw_lobe_error("Lobe node_cap must be positive, got $node_cap", "create_lobe!")
    end
    lock(LOBE_LOCK) do
        if haskey(LOBE_REGISTRY, id)
            throw_lobe_error("Lobe '$id' already exists. Grug not make duplicate cave!", "create_lobe!")
        end
        if length(LOBE_REGISTRY) >= MAX_LOBES
            throw_lobe_error("Maximum lobes ($MAX_LOBES) reached. Cave network full!", "create_lobe!")
        end
        rec = LobeRecord(
            id,
            subject,
            Set{String}(),
            Set{String}(),
            node_cap,
            0,
            0,
            time()
        )
        LOBE_REGISTRY[id] = rec
        # GRUG: Init LobeTable for this lobe immediately on creation.
        # Every lobe gets its own chunked hash table for nodes, json, drop, hopfield, meta.
        # This is NOT optional. Every lobe must have a table or storage ops will fail.
        LobeTable.create_lobe_table!(id)
        return rec
    end
end

# ============================================================================
# ADD NODE TO LOBE - Put rock in cave bucket
# GRUG: Now uses O(1) reverse index for exclusive membership check!
# ============================================================================

"""
    add_node_to_lobe!(lobe_id::String, node_id::String; alive_count::Union{Int, Nothing}=nothing)

GRUG: Put a node into a lobe. Updates node_ids set and reverse index.
Throws LobeError on: empty ids, missing lobe, cap exceeded, duplicate cross-lobe.

GRUG: If alive_count provided, use it for cap check instead of total count.
GRUG say: graves are memory, not bloat. Dead nodes don't eat cap space.
"""
function add_node_to_lobe!(lobe_id::String, node_id::String; alive_count::Union{Int, Nothing}=nothing)
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "add_node_to_lobe!")
    end
    if isempty(strip(node_id))
        throw_lobe_error("Node id cannot be empty", "add_node_to_lobe!")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found. Cannot add node.", "add_node_to_lobe!")
        end
        rec = LOBE_REGISTRY[lobe_id]

        # GRUG: If alive_count provided, use it (graves don't count towards cap!)
        # GRUG say: dead node is memory of failure, not bloat. Cap is for living.
        effective_count = isnothing(alive_count) ? length(rec.node_ids) : alive_count
        if effective_count >= rec.node_cap
            throw_lobe_error("Lobe '$lobe_id' is full (alive=$effective_count, cap=$(rec.node_cap)). Cannot add node '$node_id'.", "add_node_to_lobe!")
        end

        # GRUG: O(1) exclusive membership check via reverse index!
        # Old way was O(N_lobes) - walk every lobe and check its set.
        # New way: one dict lookup. If node already has a home, reject it loudly.
        if haskey(NODE_TO_LOBE_IDX, node_id)
            existing_lobe = NODE_TO_LOBE_IDX[node_id]
            if existing_lobe != lobe_id
                throw_lobe_error("Node '$node_id' already belongs to lobe '$existing_lobe'. Cannot add to '$lobe_id'.", "add_node_to_lobe!")
            end
            # GRUG: Node already in this exact lobe. Not an error, but no-op.
            return
        end

        # GRUG: All clear. Add to lobe set AND update reverse index atomically.
        push!(rec.node_ids, node_id)
        NODE_TO_LOBE_IDX[node_id] = lobe_id
        # GRUG: Register node in this lobe's hash table node chunk.
        # NodeRef gives O(1) per-lobe node index. Engine NODE_MAP is the source of truth.
        LobeTable.node_ref_put!(lobe_id, node_id)
    end
end

# ============================================================================
# REMOVE NODE FROM LOBE - Take rock out of cave bucket
# GRUG: Must keep reverse index in sync on every remove!
# ============================================================================

function remove_node_from_lobe!(lobe_id::String, node_id::String)
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "remove_node_from_lobe!")
    end
    if isempty(strip(node_id))
        throw_lobe_error("Node id cannot be empty", "remove_node_from_lobe!")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found.", "remove_node_from_lobe!")
        end
        rec = LOBE_REGISTRY[lobe_id]
        if !(node_id in rec.node_ids)
            # GRUG: Not an error to remove something not there, but tell caller
            return false
        end
        # GRUG: Remove from lobe set AND scrub from reverse index.
        delete!(rec.node_ids, node_id)
        delete!(NODE_TO_LOBE_IDX, node_id)
        # GRUG: Remove node ref from lobe's hash table node chunk.
        LobeTable.node_ref_remove!(lobe_id, node_id)
        return true
    end
end

# ============================================================================
# LOBE GROW! - Add N nodes to lobe with capacity pre-check
# GRUG: Atomic capacity enforcement! Either all nodes fit or none go in.
# This is the safe batch-grow function used by /lobeGrow CLI command.
# ============================================================================

function lobe_grow!(lobe_id::String, node_ids::Vector{String})::Int
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "lobe_grow!")
    end
    if isempty(node_ids)
        throw_lobe_error("node_ids list cannot be empty", "lobe_grow!")
    end

    added = 0
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found.", "lobe_grow!")
        end
        rec = LOBE_REGISTRY[lobe_id]

        # GRUG: Pre-check: would adding ALL these nodes exceed cap?
        # Count only nodes not already in this lobe (skip duplicates).
        new_nodes = filter(nid -> !(nid in rec.node_ids), node_ids)
        would_be_count = length(rec.node_ids) + length(new_nodes)
        if would_be_count > rec.node_cap
            throw_lobe_error(
                "lobe_grow! would exceed cap for '$lobe_id': current=$(length(rec.node_ids)), adding=$(length(new_nodes)), cap=$(rec.node_cap).",
                "lobe_grow!"
            )
        end

        # GRUG: All nodes fit. Now check exclusive membership for each.
        for nid in new_nodes
            if haskey(NODE_TO_LOBE_IDX, nid)
                existing = NODE_TO_LOBE_IDX[nid]
                if existing != lobe_id
                    throw_lobe_error("Node '$nid' already belongs to lobe '$existing'. Cannot grow into '$lobe_id'.", "lobe_grow!")
                end
            end
        end

        # GRUG: All checks passed. Plant all nodes.
        for nid in new_nodes
            push!(rec.node_ids, nid)
            NODE_TO_LOBE_IDX[nid] = lobe_id
            # GRUG: Register in lobe's hash table node chunk too.
            LobeTable.node_ref_put!(lobe_id, nid)
            added += 1
        end
    end
    return added
end

# ============================================================================
# FIND LOBE FOR NODE - O(1) reverse lookup: which cave does this rock live in?
# ============================================================================

function find_lobe_for_node(node_id::String)::Union{String, Nothing}
    if isempty(strip(node_id))
        throw_lobe_error("Node id cannot be empty", "find_lobe_for_node")
    end
    lock(LOBE_LOCK) do
        return get(NODE_TO_LOBE_IDX, node_id, nothing)
    end
end

# ============================================================================
# LOBE IS FULL - Check if cave bucket is at cap
# ============================================================================

function lobe_is_full(lobe_id::String)::Bool
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "lobe_is_full")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found.", "lobe_is_full")
        end
        rec = LOBE_REGISTRY[lobe_id]
        return length(rec.node_ids) >= rec.node_cap
    end
end

# ============================================================================
# GET LOBE NODE COUNT - How many rocks in cave bucket
# ============================================================================

function get_lobe_node_count(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "get_lobe_node_count")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found.", "get_lobe_node_count")
        end
        return length(LOBE_REGISTRY[lobe_id].node_ids)
    end
end

# ============================================================================
# GET LOBE IDS - List all cave bucket names
# ============================================================================

function get_lobe_ids()::Vector{String}
    lock(LOBE_LOCK) do
        return collect(keys(LOBE_REGISTRY))
    end
end

# ============================================================================
# GET LOBE - Get cave bucket record by id
# ============================================================================

function get_lobe(lobe_id::String)::LobeRecord
    if isempty(strip(lobe_id))
        throw_lobe_error("Lobe id cannot be empty", "get_lobe")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id)
            throw_lobe_error("Lobe '$lobe_id' not found.", "get_lobe")
        end
        return LOBE_REGISTRY[lobe_id]
    end
end

# ============================================================================
# CONNECT LOBES - Wire two cave buckets together (bidirectional)
# ============================================================================

function connect_lobes!(lobe_id_a::String, lobe_id_b::String)
    if lobe_id_a == lobe_id_b
        throw_lobe_error("Cannot connect lobe to itself: '$lobe_id_a'", "connect_lobes!")
    end
    lock(LOBE_LOCK) do
        if !haskey(LOBE_REGISTRY, lobe_id_a)
            throw_lobe_error("Lobe '$lobe_id_a' not found.", "connect_lobes!")
        end
        if !haskey(LOBE_REGISTRY, lobe_id_b)
            throw_lobe_error("Lobe '$lobe_id_b' not found.", "connect_lobes!")
        end
        push!(LOBE_REGISTRY[lobe_id_a].connected_lobe_ids, lobe_id_b)
        push!(LOBE_REGISTRY[lobe_id_b].connected_lobe_ids, lobe_id_a)
    end
end

# ============================================================================
# DISCONNECT LOBES - Remove wire between two cave buckets
# ============================================================================

function disconnect_lobes!(lobe_id_a::String, lobe_id_b::String)
    lock(LOBE_LOCK) do
        if haskey(LOBE_REGISTRY, lobe_id_a)
            delete!(LOBE_REGISTRY[lobe_id_a].connected_lobe_ids, lobe_id_b)
        end
        if haskey(LOBE_REGISTRY, lobe_id_b)
            delete!(LOBE_REGISTRY[lobe_id_b].connected_lobe_ids, lobe_id_a)
        end
    end
end

# ============================================================================
# GET REVERSE INDEX SNAPSHOT - For diagnostics and testing
# ============================================================================

function get_node_to_lobe_snapshot()::Dict{String, String}
    lock(LOBE_LOCK) do
        return copy(NODE_TO_LOBE_IDX)
    end
end

# ============================================================================
# LOBE STATUS SUMMARY - For /status and /lobes commands
# ============================================================================

function get_lobe_status_summary()::String
    lines = String[]
    lock(LOBE_LOCK) do
        if isempty(LOBE_REGISTRY)
            push!(lines, "[LOBE REGISTRY EMPTY]")
            return
        end
        push!(lines, "=== LOBE REGISTRY ($(length(LOBE_REGISTRY)) lobes, $(length(NODE_TO_LOBE_IDX)) nodes indexed) ===")
        for (id, rec) in sort(collect(LOBE_REGISTRY), by = x -> x[1])
            fullness  = "$(length(rec.node_ids))/$(rec.node_cap)"
            connected = isempty(rec.connected_lobe_ids) ? "none" : join(sort(collect(rec.connected_lobe_ids)), ",")
            # GRUG: Show table chunk sizes alongside lobe info
            table_info = if LobeTable.table_exists(id)
                node_sz    = LobeTable.table_size(id, LobeTable.CHUNK_NODES)
                json_sz    = LobeTable.table_size(id, LobeTable.CHUNK_JSON)
                drop_sz    = LobeTable.table_size(id, LobeTable.CHUNK_DROP)
                hopf_sz    = LobeTable.table_size(id, LobeTable.CHUNK_HOPFIELD)
                "tbl[nodes=$node_sz json=$json_sz drop=$drop_sz hopf=$hopf_sz]"
            else
                "tbl[NO TABLE]"
            end
            push!(lines, "  $id | subject='$(rec.subject)' | nodes=$fullness | fires=$(rec.fire_count) | inhibits=$(rec.inhibit_count) | connected=[$connected] | $table_info")
        end
    end
    return join(lines, "\n")
end

# GRUG say: Lobe module done. Cave buckets ready for rocks. Reverse index fast like bird.

end # module Lobe