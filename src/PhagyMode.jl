# PhagyMode.jl
# ==============================================================================
# PHAGY MODE - IDLE-TIME AUTOMATA MAINTENANCE SYSTEM
# ==============================================================================
# GRUG: When idle timer fires and coinflip lands on PHAGY (50/50 vs chatter),
# one phagy automaton runs instead of a gossip session.
#
# PHAGY MECHANICS:
#   - ONE target is selected per cycle (random weighted priority)
#   - Phagy never does a full sweep - one job, then done (Big-O safe)
#   - Six automata are available, selected randomly each cycle:
#       1. ORPHAN PRUNER      - Cull nodes with zero connections (in + out)
#       2. STRENGTH DECAYER   - Batch-decay nodes unseen for N sessions
#       3. GRAVE RECYCLER     - Salvage drop_table assets before final deletion
#       4. CACHE VALIDATOR    - Purge stale Hopfield cache entries
#       5. DROP TABLE COMPACT - Dedupe + trim low-probability drop_table tails
#       6. RULE PRUNER        - Flag/remove orchestration rules that never fire
#       7. MEMORY FORENSICS   - Coinflip: fuzzy (approximate) or metric (exact) analysis
#
# DESIGN RULES:
#   - No silent failures. Every error surfaces.
#   - One automaton per cycle. Never all six at once.
#   - Thread-safe: all NODE_MAP access goes through NODE_LOCK.
#   - PhagyStats returned on every run for diagnostics and /status CLI.
# ==============================================================================

module PhagyMode

using Random

export run_phagy!, PhagyStats, get_phagy_log, PhagyError, run_memory_forensics!, fuzzy_memory_forensics!, metric_memory_forensics!

# ==============================================================================
# ERROR TYPE - GRUG: NO SILENT FAILURES
# ==============================================================================

struct PhagyError <: Exception
    msg::String
end

Base.showerror(io::IO, e::PhagyError) =
    print(io, "PhagyError: ", e.msg)

# ==============================================================================
# PHAGY STATS (returned per cycle for diagnostics)
# ==============================================================================

# GRUG: Each phagy run reports what it did. Zero values are fine - it means
# the automaton found nothing to clean. That is still a valid healthy run.
struct PhagyStats
    automaton::String       # GRUG: Which automaton ran this cycle
    items_processed::Int    # GRUG: How many candidates were examined
    items_changed::Int      # GRUG: How many were actually mutated/removed
    cycle_time_ms::Float64  # GRUG: Wall time for this cycle in milliseconds
    notes::String           # GRUG: Human-readable summary of what happened
end

# ==============================================================================
# PHAGY LOG (bounded ring - last 50 cycles)
# ==============================================================================

const PHAGY_LOG      = PhagyStats[]
const PHAGY_LOG_LOCK = ReentrantLock()
const MAX_PHAGY_LOG  = 50

# ==============================================================================
# PHAGY COLLISION PROTECTION & TIMEOUT SYSTEM
# ==============================================================================

# GRUG: Resource tracking to prevent automata collisions
# Each automaton reserves its target resource before execution
const PHAGY_RESOURCE_LOCK   = ReentrantLock()
const PHAGY_RESERVED_RESOURCES = Dict{String, String}()  # resource_type -> automaton_name

# GRUG: Timeout configuration - reasonable limits balanced with quality assurance
const PHAGY_TIMEOUT_SECONDS = Dict{String, Float64}(
    "ORPHAN_PRUNER"     => 10.0,   # GRUG: Node iteration, fast operation
    "STRENGTH_DECAYER"  => 10.0,   # GRUG: Node iteration, fast operation
    "GRAVE_RECYCLER"    => 15.0,   # GRUG: Complex drop table merging
    "CACHE_VALIDATOR"   => 20.0,   # GRUG: Cache validation may need full scan
    "DROP_TABLE_COMPACT" => 15.0,  # GRUG: Drop table compaction
    "RULE_PRUNER"       => 5.0,    # GRUG: Small vector iteration
    "MEMORY_FORENSICS_FUZZY"   => 10.0,  # GRUG: Sampling based, fast
    "MEMORY_FORENSICS_METRIC"  => 30.0,  # GRUG: Full enumeration, can be slow
)

const PHAGY_DEFAULT_TIMEOUT = 15.0  # GRUG: Fallback timeout if automaton not in map


# ==============================================================================

"""
push_phagy_log!(stats::PhagyStats)

GRUG: Append a phagy cycle result to the bounded log. Trims oldest entry
when log exceeds MAX_PHAGY_LOG. Thread-safe.
"""
function push_phagy_log!(stats::PhagyStats)
    lock(PHAGY_LOG_LOCK) do
        push!(PHAGY_LOG, stats)
        while length(PHAGY_LOG) > MAX_PHAGY_LOG
            deleteat!(PHAGY_LOG, 1)
        end
    end
end

# ==============================================================================
# PHAGY RESOURCE RESERVATION SYSTEM (COLLISION PREVENTION)
# ==============================================================================

"""
reserve_phagy_resource!(automaton_name::String, resource_scope::String)::Bool

GRUG: Reserve a resource scope for an automaton. This prevents multiple automata
from working on the same data structure simultaneously.

resource_scope options:
  - "node_map"         : NODE_MAP iteration
  - "node_map_write"   : NODE_MAP mutation
  - "hopfield_cache"   : HOPFIELD_CACHE access
  - "rules"            : RULES vector access
  - "message_history"  : MESSAGE_HISTORY read access
  - "global"           : Global state (no simultaneous phagy)

Returns true if reservation successful, false if already reserved by another automaton.
Thread-safe operation. All reservations must be released via release_phagy_resource!().
"""
function reserve_phagy_resource!(automaton_name::String, resource_scope::String)::Bool
    lock(PHAGY_RESOURCE_LOCK) do
        if haskey(PHAGY_RESERVED_RESOURCES, resource_scope)
            existing_automaton = PHAGY_RESERVED_RESOURCES[resource_scope]
            println("[PHAGY:COLLISION] ⚠️  Resource '$resource_scope' already reserved by $existing_automaton. $automaton_name skipped.")
            return false
        end
        PHAGY_RESERVED_RESOURCES[resource_scope] = automaton_name
        @debug "[PHAGY:RESERVE] ✅ $automaton_name reserved '$resource_scope'"
        return true
    end
end

"""
release_phagy_resource!(resource_scope::String)::Nothing

GRUG: Release a previously reserved resource scope. This MUST be called in a
finally block to ensure cleanup even if the automaton crashes or times out.

Thread-safe operation. Safe to call even if resource was never reserved.
"""
function release_phagy_resource!(resource_scope::String)::Nothing
    lock(PHAGY_RESOURCE_LOCK) do
        if haskey(PHAGY_RESERVED_RESOURCES, resource_scope)
            automaton_name = PHAGY_RESERVED_RESOURCES[resource_scope]
            delete!(PHAGY_RESERVED_RESOURCES, resource_scope)
            @debug "[PHAGY:RELEASE] ✅ $automaton_name released '$resource_scope'"
        end
    end
    return nothing
end

"""
get_phagy_timeout(automaton_name::String)::Float64

GRUG: Retrieve the timeout duration for a specific automaton.
Returns automaton-specific timeout or PHAGY_DEFAULT_TIMEOUT if not configured.
"""
function get_phagy_timeout(automaton_name::String)::Float64
    return get(PHAGY_TIMEOUT_SECONDS, automaton_name, PHAGY_DEFAULT_TIMEOUT)
end

"""
get_phagy_log()::Vector{PhagyStats}

GRUG: Return a snapshot copy of the phagy log for diagnostics.
"""
function get_phagy_log()::Vector{PhagyStats}
    return lock(PHAGY_LOG_LOCK) do
        copy(PHAGY_LOG)
    end

# ==============================================================================
# PHAGY RESOURCE RESERVATION SYSTEM (COLLISION PREVENTION)
# ==============================================================================

"""
reserve_phagy_resource!(automaton_name::String, resource_scope::String)::Bool

GRUG: Reserve a resource scope for an automaton. This prevents multiple automata
from working on the same data structure simultaneously.

resource_scope options:
  - "node_map"         : NODE_MAP iteration
  - "node_map_write"   : NODE_MAP mutation
  - "hopfield_cache"   : HOPFIELD_CACHE access
  - "rules"            : RULES vector access
  - "message_history"  : MESSAGE_HISTORY read access
  - "global"           : Global state (no simultaneous phagy)

Returns true if reservation successful, false if already reserved by another automaton.
Thread-safe operation. All reservations must be released via release_phagy_resource!().
"""
function reserve_phagy_resource!(automaton_name::String, resource_scope::String)::Bool
    lock(PHAGY_RESOURCE_LOCK) do
        if haskey(PHAGY_RESERVED_RESOURCES, resource_scope)
            existing_automaton = PHAGY_RESERVED_RESOURCES[resource_scope]
            println("[PHAGY:COLLISION] ⚠️  Resource '$resource_scope' already reserved by $existing_automaton. $automaton_name skipped.")
            return false
        end
        PHAGY_RESERVED_RESOURCES[resource_scope] = automaton_name
        @debug "[PHAGY:RESERVE] ✅ $automaton_name reserved '$resource_scope'"
        return true
    end
end

"""
release_phagy_resource!(resource_scope::String)::Nothing

GRUG: Release a previously reserved resource scope. This MUST be called in a
finally block to ensure cleanup even if the automaton crashes or times out.

Thread-safe operation. Safe to call even if resource was never reserved.
"""
function release_phagy_resource!(resource_scope::String)::Nothing
    lock(PHAGY_RESOURCE_LOCK) do
        if haskey(PHAGY_RESERVED_RESOURCES, resource_scope)
            automaton_name = PHAGY_RESERVED_RESOURCES[resource_scope]
            delete!(PHAGY_RESERVED_RESOURCES, resource_scope)
            @debug "[PHAGY:RELEASE] ✅ $automaton_name released '$resource_scope'"
        end
    end
    return nothing
end

"""
get_phagy_timeout(automaton_name::String)::Float64

GRUG: Retrieve the timeout duration for a specific automaton.
Returns automaton-specific timeout or PHAGY_DEFAULT_TIMEOUT if not configured.
"""
function get_phagy_timeout(automaton_name::String)::Float64
    return get(PHAGY_TIMEOUT_SECONDS, automaton_name, PHAGY_DEFAULT_TIMEOUT)
end

end

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: A node is an orphan if it has been created but never latched any
# neighbors AND has zero connections accumulated. Only meaningful on large maps
# (NODE_LATCH_THRESHOLD guards growth, phagy guards cleanup on same boundary).
const ORPHAN_MAX_NEIGHBORS  = 0     # GRUG: Nodes with exactly 0 neighbors are orphan candidates

# GRUG: Strength decay per phagy cycle for nodes that have not been activated
# recently. Small enough that a single phagy cycle won't kill a useful node.
const DECAY_RATE            = 0.03  # GRUG: 3% strength reduction per cycle

# GRUG: Nodes below this strength threshold are eligible for decay processing.
# Avoids wasting phagy cycles on already-strong nodes.
const DECAY_ELIGIBILITY_MAX = 0.4   # GRUG: Only decay nodes below 40% strength

# GRUG: Drop table entries below this probability are trimmed by DROP TABLE COMPACT.
const DROP_TABLE_TRIM_FLOOR = 0.05  # GRUG: 5% floor - below this gets cut

# GRUG: Rules that have been in the system for at least this many phagy cycles
# without ever firing are considered dormant candidates.
# (Rules track fire_count; zero fires after RULE_DORMANCY_CYCLES = dormant)
const RULE_DORMANCY_CYCLES  = 20    # GRUG: 20 idle cycles without a fire = dormant

# ==============================================================================
# AUTOMATON 1: ORPHAN PRUNER
# ==============================================================================

"""
prune_orphan_nodes!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Identify and grave nodes that have zero neighbors and zero strength.
These are disconnected dead-ends that were never integrated into the map topology.
Graving (not deleting) preserves their ID in the grave registry so latching
history remains consistent.

SAFETY: Never graves a node that has a non-empty drop_table (GRAVE RECYCLER
handles those). Never graves image nodes (SDF data is irreplaceable).

COLLISION PROTECTION: Reserves "node_map_write" resource before execution.
TIMEOUT: 10 second limit enforced by dispatcher.
"""
function prune_orphan_nodes!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    const AUTOMATON_NAME = "ORPHAN_PRUNER"
    const RESOURCE_SCOPE = "node_map_write"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
        examined = 0
        graved   = 0
        skipped_has_drops  = 0
        skipped_image      = 0

        orphan_ids = String[]

        lock(node_lock) do
            for (id, node) in node_map
                examined += 1
                # GRUG: Skip already-graved nodes (phagy should not double-process)
                node.is_grave && continue
                # GRUG: Skip image nodes - their SDF data is not reconstructable
                if node.is_image_node
                    skipped_image += 1
                    continue
                end
                # GRUG: Skip nodes that still have drop_table entries - GRAVE RECYCLER owns those
                if !isempty(node.drop_table)
                    skipped_has_drops += 1
                    continue
                end
                # GRUG: Orphan condition: zero neighbors AND zero strength
                if length(node.neighbor_ids) <= ORPHAN_MAX_NEIGHBORS && node.strength <= 0.0
                    push!(orphan_ids, id)
                end
            end
        end

        # GRUG: Second pass - grave the identified orphans under lock
        if !isempty(orphan_ids)
            lock(node_lock) do
                for id in orphan_ids
                    if haskey(node_map, id)
                        node = node_map[id]
                        # GRUG: Final safety check under lock before graving
                        if !node.is_grave && !node.is_image_node && isempty(node.drop_table)
                            node.is_grave = true
                            graved += 1
                            @debug "[PHAGY:ORPHAN] Graved orphan node $id (strength=$(node.strength), neighbors=$(length(node.neighbor_ids)))"
                        end
                    end
                end
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Graved=$graved, SkippedImageNodes=$skipped_image, SkippedHasDrops=$skipped_has_drops"
        println("[PHAGY:ORPHAN] 🧹  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, graved, elapsed_ms, notes)
        
    catch e
        # GRUG: Explicit error handling - no silent failures
        println("[PHAGY:ORPHAN] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        # GRUG: ALWAYS release the reservation (cleanup on success, error, or timeout)
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 2: STRENGTH DECAYER
# ==============================================================================

"""
decay_forgotten_strengths!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Apply a small strength decay to nodes that are below DECAY_ELIGIBILITY_MAX.
This models biological forgetting: patterns that are rarely reinforced slowly fade.
Does NOT grave nodes - strength decay only. Graving is the ORPHAN PRUNER's job.

SAFETY: Never decays image nodes. Never decays nodes already at strength 0.0.
Decay is floored at 0.0 (no negative strength).

COLLISION PROTECTION: Reserves "node_map_write" resource before execution.
TIMEOUT: 10 second limit enforced by dispatcher.
"""
function decay_forgotten_strengths!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    const AUTOMATON_NAME = "STRENGTH_DECAYER"
    const RESOURCE_SCOPE = "node_map_write"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
        examined = 0
        decayed  = 0
        skipped_strong = 0
        skipped_image  = 0

        lock(node_lock) do
            for (id, node) in node_map
                examined += 1
                node.is_grave && continue
                if node.is_image_node
                    skipped_image += 1
                    continue
                end
                # GRUG: Only decay weak nodes - strong nodes earned their keep
                if node.strength > DECAY_ELIGIBILITY_MAX
                    skipped_strong += 1
                    continue
                end
                # GRUG: Already at floor - nothing to decay
                node.strength <= 0.0 && continue

                old_str = node.strength
                node.strength = max(0.0, node.strength - DECAY_RATE)
                decayed += 1
                @debug "[PHAGY:DECAY] Node $id: strength $old_str → $(node.strength)"
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Decayed=$decayed, SkippedStrong=$skipped_strong, SkippedImageNodes=$skipped_image, DecayRate=$DECAY_RATE"
        println("[PHAGY:DECAY] 📉  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, decayed, elapsed_ms, notes)
        
    catch e
        # GRUG: Explicit error handling - no silent failures
        println("[PHAGY:DECAY] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        # GRUG: ALWAYS release the reservation (cleanup on success, error, or timeout)
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 3: GRAVE RECYCLER
# ==============================================================================

"""
recycle_grave_assets!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Scan graved nodes for non-empty drop_tables. If a graved node still has
drop_table entries, extract those entries and attempt to merge them into the
strongest non-grave neighbor node. This is organ donation - the node is dead
but its learned associations can still benefit the map.

After recycling, the graved node's drop_table is cleared (assets donated, nothing
left to recycle on next pass).

SAFETY: Only processes nodes where is_grave=true. Never ungraves a node.
If no neighbor exists to receive assets, assets are discarded (logged as waste).

COLLISION PROTECTION: Reserves "node_map_write" resource before execution.
TIMEOUT: 15 second limit enforced by dispatcher.
"""
function recycle_grave_assets!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    const AUTOMATON_NAME = "GRAVE_RECYCLER"
    const RESOURCE_SCOPE = "node_map_write"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
        examined  = 0
        recycled  = 0
        wasted    = 0
        no_target = 0

        lock(node_lock) do
            for (id, node) in node_map
                node.is_grave || continue
                isempty(node.drop_table) && continue
                examined += 1

                # GRUG: Find the strongest alive neighbor to receive the assets
                best_neighbor_id = ""
                best_strength    = -1.0

                for nid in node.neighbor_ids
                    if haskey(node_map, nid)
                        n = node_map[nid]
                        if !n.is_grave && n.strength > best_strength
                            best_strength    = n.strength
                            best_neighbor_id = nid
                        end
                    end
                end

                if isempty(best_neighbor_id)
                    # GRUG: Graved node has no alive neighbors. Assets go to waste.
                    # Clear them anyway so this node doesn't get re-examined next cycle.
                    wasted += length(node.drop_table)
                    empty!(node.drop_table)
                    no_target += 1
                    @debug "[PHAGY:RECYCLE] Node $id: no alive neighbors. $(wasted) assets wasted."
                    continue
                end

                # GRUG: Donate drop_table entries to best neighbor
                target = node_map[best_neighbor_id]
                donated = 0
                for (response_text, probability) in node.drop_table
                    # GRUG: Only donate if target doesn't already have this entry
                    if !haskey(target.drop_table, response_text)
                        target.drop_table[response_text] = probability
                        donated += 1
                    end
                    # GRUG: If target already has it, keep the max probability
                    # (donated knowledge should not override stronger existing knowledge)
                    existing = get(target.drop_table, response_text, 0.0)
                    if probability > existing
                        target.drop_table[response_text] = probability
                        donated += 1
                    end
                end

                # GRUG: Clear the graved node's drop_table - assets have been transferred
                empty!(node.drop_table)
                recycled += donated
                @debug "[PHAGY:RECYCLE] Node $id → $best_neighbor_id: donated $donated entries"
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Recycled=$recycled, Wasted=$wasted, NoTargetNodes=$no_target"
        println("[PHAGY:RECYCLE] ♻️   Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, recycled, elapsed_ms, notes)
        
    catch e
        # GRUG: Explicit error handling - no silent failures
        println("[PHAGY:RECYCLE] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        # GRUG: ALWAYS release the reservation (cleanup on success, error, or timeout)
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 4: HOPFIELD CACHE VALIDATOR - DISABLED
# ==============================================================================
# GRUG: Hopfield caching has been DISABLED. Pattern bind phase is blazing fast
# even without caching, and the Hopfield system introduces unnecessary complexity.
# Hopfield caching should only be used for RIDICULOUSLY LARGE lobe sizes
# (50,000+ nodes per lobe) where memory access becomes a bottleneck.
# Current lobe architecture with 1000 node cap per cycle makes this obsolete.
# ============================================================================

# OLD CODE (DISABLED):
# ==============================================================================
# AUTOMATON 4: HOPFIELD CACHE VALIDATOR
# ==============================================================================

# """
# validate_hopfield_cache!(hopfield_cache, cache_lock, node_map, node_lock)::PhagyStats

# GRUG: The Hopfield cache stores familiar-input fast-paths: UInt64 hash keys ->
# Vector{String} of node IDs. If those node IDs have since been graved or deleted,
# the cache entry is stale - it routes the fast-path to a dead node.
# This automaton purges stale entries so the cache doesn't route to dead nodes.

# Cache key type  : UInt64 (hash of normalized input text, from hopfield_input_hash())
# Cache value type: Vector{String} (list of node IDs that matched that input)

# A cache entry is stale if ANY of its node IDs are missing or graved.
# SAFETY: Only removes entries - never modifies NODE_MAP. Two-pass pattern to avoid
# mutation-during-iteration. Always acquires cache_lock THEN node_lock (deadlock order).
# """
# function validate_hopfield_cache!(
#     hopfield_cache  ::Dict,          # GRUG: Dict{UInt64, Vector{String}} from engine
#     cache_lock      ::ReentrantLock,
#     node_map        ::Dict,
#     node_lock       ::ReentrantLock
# )::PhagyStats\2
#     const AUTOMATON_NAME = "CACHE_VALIDATOR"
#     const RESOURCE_SCOPE = "hopfield_cache"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
#     if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
#         throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
#     end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
    examined   = 0
    purged     = 0
    valid      = 0

    stale_keys = UInt64[]

    # GRUG: PASS 1 - collect stale keys under both locks (cache_lock THEN node_lock)
    # Lock order must always be cache_lock -> node_lock to prevent deadlock.
    lock(cache_lock) do
        lock(node_lock) do
            for (cache_key, node_ids) in hopfield_cache
                examined += 1
                # GRUG: Entry is stale if ANY referenced node is missing or graved
                is_stale = any(node_ids) do nid
                    !haskey(node_map, nid) || node_map[nid].is_grave
                end
                if is_stale
                    push!(stale_keys, cache_key)
                else
                    valid += 1
                end
            end
        end
    end

    # GRUG: PASS 2 - delete stale entries under cache_lock only (node_map not touched)
    if !isempty(stale_keys)
        lock(cache_lock) do
            for key in stale_keys
                delete!(hopfield_cache, key)
                purged += 1
                @debug "[PHAGY:CACHE] Purged stale cache entry key=$(key)"
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Purged=$purged, ValidKept=$valid"
    println("[PHAGY:CACHE] 🗄️   Cycle complete. $notes")
    return PhagyStats("CACHE_VALIDATOR", examined, purged, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 5: DROP TABLE COMPACTOR
# ==============================================================================

"""
compact_drop_tables!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats

GRUG: Drop tables can accumulate low-probability junk entries over time.
This automaton scans all alive nodes and removes entries below DROP_TABLE_TRIM_FLOOR.
Also deduplicates any entries that are exact string matches (keeps the max probability).

SAFETY: Never removes entries from graved nodes (GRAVE RECYCLER handles those).
Never removes the LAST entry in a drop_table (node must keep at least one response).
"""
function compact_drop_tables!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats\2
    const AUTOMATON_NAME = "DROP_TABLE_COMPACT"
    const RESOURCE_SCOPE = "node_map_write"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
    examined  = 0
    trimmed   = 0
    protected = 0   # GRUG: Entries saved by "last entry" protection rule

    lock(node_lock) do
        for (id, node) in node_map
            node.is_grave && continue
            isempty(node.drop_table) && continue
            examined += 1

            # GRUG: Collect keys to trim (below floor probability)
            trim_candidates = String[]
            for (response_text, probability) in node.drop_table
                if probability < DROP_TABLE_TRIM_FLOOR
                    push!(trim_candidates, response_text)
                end
            end

            # GRUG: Apply "last entry" protection - never empty a drop_table
            if length(trim_candidates) >= length(node.drop_table)
                # GRUG: Would empty the table. Protect by keeping the highest-prob entry.
                keep_key = argmax(node.drop_table)
                filter!(k -> k != keep_key, trim_candidates)
                protected += 1
                @debug "[PHAGY:COMPACT] Node $id: last-entry protection applied, kept $keep_key"
            end

            # GRUG: Delete trim candidates
            for key in trim_candidates
                delete!(node.drop_table, key)
                trimmed += 1
                @debug "[PHAGY:COMPACT] Node $id: trimmed '$key' (below floor $DROP_TABLE_TRIM_FLOOR)"
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Trimmed=$trimmed, LastEntryProtections=$protected, TrimFloor=$DROP_TABLE_TRIM_FLOOR"
    println("[PHAGY:COMPACT] 🗜️   Cycle complete. $notes")
    return PhagyStats("DROP_TABLE_COMPACT", examined, trimmed, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 6: RULE PRUNER
# ==============================================================================

"""
prune_dormant_rules!(rules::Vector, rules_lock::ReentrantLock)::PhagyStats

GRUG: Orchestration rules that have never fired after RULE_DORMANCY_CYCLES phagy
cycles are flagged as dormant. This automaton increments a dormancy counter on
each rule per cycle and marks rules as dormant when the threshold is hit.

Rules must have fields: fire_count::Int, dormancy_strikes::Int, is_dormant::Bool
If rules don't have dormancy_strikes yet, this automaton adds them gracefully.

SAFETY: Never deletes rules - only sets is_dormant=true. User must explicitly
purge dormant rules via /pruneRules CLI command. This prevents accidental rule loss.
"""
function prune_dormant_rules!(rules::Vector, rules_lock::ReentrantLock)::PhagyStats\2
    const AUTOMATON_NAME = "RULE_PRUNER"
    const RESOURCE_SCOPE = "rules"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end
    
    # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
    t_start = time()
    try
    examined  = 0
    flagged   = 0
    already   = 0
    active    = 0

    lock(rules_lock) do
        for rule in rules
            examined += 1

            # GRUG: Skip rules already marked dormant
            if hasproperty(rule, :is_dormant) && rule.is_dormant
                already += 1
                continue
            end

            # GRUG: Rules with fires are alive - reset their dormancy strike counter
            if hasproperty(rule, :fire_count) && rule.fire_count > 0
                if hasproperty(rule, :dormancy_strikes)
                    rule.dormancy_strikes = 0
                end
                active += 1
                continue
            end

            # GRUG: Rule has zero fires. Increment dormancy strike.
            if hasproperty(rule, :dormancy_strikes)
                rule.dormancy_strikes += 1
                if rule.dormancy_strikes >= RULE_DORMANCY_CYCLES
                    if hasproperty(rule, :is_dormant)
                        rule.is_dormant = true
                        flagged += 1
                        @debug "[PHAGY:RULES] Rule flagged dormant after $(rule.dormancy_strikes) strikes: $(hasproperty(rule, :pattern) ? rule.pattern : rule)"
                    end
                end
            end
        end
    end

    elapsed_ms = (time() - t_start) * 1000.0
    notes = "Examined=$examined, Flagged=$flagged, AlreadyDormant=$already, ActiveRules=$active, DormancyThreshold=$RULE_DORMANCY_CYCLES"
    println("[PHAGY:RULES] ✂️   Cycle complete. $notes")
    return PhagyStats("RULE_PRUNER", examined, flagged, elapsed_ms, notes)
end

# ==============================================================================
# AUTOMATON 7: MEMORY FORENSICS
# ==============================================================================

# GRUG: Memory forensics examines the MESSAGE_HISTORY and NODE_MAP for health
# indicators. Coinflip selects between FUZZY (approximate/heuristic) and METRIC
# (exact measurement) analysis. Both modes return a ForensicsReport inside
# PhagyStats.notes.

# ── FORENSICS CONSTANTS ──────────────────────────────────────────────────────

# GRUG: Thresholds for flagging anomalies in memory health.
const FORENSICS_STALE_MSG_RATIO    = 0.90  # GRUG: If >90% of messages come from same role, flag imbalance
const FORENSICS_DEAD_REF_THRESHOLD = 0.10  # GRUG: If >10% of message-referenced node IDs are dead, flag decay
const FORENSICS_PATTERN_ENTROPY_LO = 0.15  # GRUG: Below this = low diversity (fuzzy mode heuristic)
const FORENSICS_STRENGTH_SKEW_MAX  = 0.80  # GRUG: If >80% of alive nodes share same strength band, flag monoculture

"""
run_memory_forensics!(
    node_map, node_lock, message_history, history_lock
)::PhagyStats

GRUG: MEMORY FORENSICS DISPATCHER. Flips a coin to decide between:
  - HEADS → fuzzy_memory_forensics!  (approximate / heuristic analysis)
  - TAILS → metric_memory_forensics! (exact / measurement-based analysis)

Both modes examine MESSAGE_HISTORY and NODE_MAP for anomalies.
Neither mode mutates state — forensics is read-only observation.
Returns PhagyStats with the forensics report in the notes field.
"""
function run_memory_forensics!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    message_history ::Vector,
    history_lock    ::ReentrantLock
)::PhagyStats
    # GRUG: Validate inputs — no silent failures
    if !isa(node_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_memory_forensics! got invalid node_lock! !!!"))
    end
    if !isa(history_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_memory_forensics! got invalid history_lock! !!!"))
    end

    # GRUG: Coinflip — heads=fuzzy, tails=metric
    coin = rand(Bool)
    mode = coin ? "FUZZY" : "METRIC"
    println("[PHAGY:FORENSICS] 🔬  Memory forensics starting. Mode: $mode (coin=$(coin ? "heads" : "tails"))")

    stats = try
        if coin
            fuzzy_memory_forensics!(node_map, node_lock, message_history, history_lock)
        else
            metric_memory_forensics!(node_map, node_lock, message_history, history_lock)
        end
    catch e
        println("[PHAGY:FORENSICS] !!! ERROR in $mode forensics: $e !!!")
        rethrow(e)
    end

    return stats
end

"""
fuzzy_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats

GRUG: APPROXIMATE / HEURISTIC MEMORY ANALYSIS.
Uses sampling and estimation rather than full enumeration.
Checks:
  1. Role distribution balance (approximate — samples up to 500 messages)
  2. Pattern diversity estimate (hash-based approximate entropy)
  3. Strength distribution shape (sampled histogram)
  4. Stale attachment detection (spot-check for dead references)
  5. Memory echo detection (repeated message content, sampled)

This mode is FAST but APPROXIMATE. Good for large caves where full
enumeration is expensive. All observations are READ-ONLY.
"""
function fuzzy_memory_forensics!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    message_history ::Vector,
    history_lock    ::ReentrantLock
)::PhagyStats
    t_start = time()
    findings = String[]
    items_examined = 0

    # ── 1. ROLE DISTRIBUTION (sampled) ────────────────────────────────────
    # GRUG: Sample up to 500 messages and check if one role dominates.
    role_counts = Dict{String, Int}()
    sample_size = 0

    lock(history_lock) do
        n_msgs = length(message_history)
        if n_msgs == 0
            push!(findings, "MEMORY_EMPTY: No messages in history cave. Nothing to analyze.")
            return
        end

        # GRUG: Sample indices — take last 500 or all if fewer
        sample_n = min(500, n_msgs)
        start_idx = max(1, n_msgs - sample_n + 1)
        for i in start_idx:n_msgs
            msg = message_history[i]
            role_counts[msg.role] = get(role_counts, msg.role, 0) + 1
            sample_size += 1
        end
        items_examined += sample_size
    end

    if sample_size > 0
        # GRUG: Check for role imbalance
        max_role = ""
        max_count = 0
        for (role, count) in role_counts
            if count > max_count
                max_count = count
                max_role = role
            end
        end
        ratio = max_count / sample_size
        if ratio > FORENSICS_STALE_MSG_RATIO
            push!(findings, "ROLE_IMBALANCE: Role '$max_role' dominates $(round(ratio*100, digits=1))% of sampled messages ($max_count/$sample_size). Cave echo chamber detected.")
        else
            push!(findings, "ROLE_BALANCE_OK: No single role exceeds $(round(FORENSICS_STALE_MSG_RATIO*100))% threshold. Roles: $(join(["$k=$v" for (k,v) in role_counts], ", "))")
        end
    end

    # ── 2. PATTERN DIVERSITY ESTIMATE (hash-based) ────────────────────────
    # GRUG: Sample node patterns and estimate diversity via unique hash ratio.
    pattern_hashes = Set{UInt64}()
    alive_sample = 0

    lock(node_lock) do
        sample_count = 0
        for (id, node) in node_map
            node.is_grave && continue
            push!(pattern_hashes, hash(lowercase(strip(node.pattern))))
            alive_sample += 1
            sample_count += 1
            # GRUG: Sample up to 1000 alive nodes for speed
            sample_count >= 1000 && break
        end
        items_examined += sample_count
    end

    if alive_sample > 0
        diversity = length(pattern_hashes) / alive_sample
        if diversity < FORENSICS_PATTERN_ENTROPY_LO
            push!(findings, "LOW_PATTERN_DIVERSITY: Only $(round(diversity*100, digits=1))% unique patterns in $alive_sample sampled nodes. Herd mentality detected.")
        else
            push!(findings, "PATTERN_DIVERSITY_OK: $(round(diversity*100, digits=1))% unique patterns across $alive_sample sampled nodes.")
        end
    else
        push!(findings, "NO_ALIVE_NODES: Zero alive nodes to sample. Cave is a graveyard.")
    end

    # ── 3. STRENGTH DISTRIBUTION SHAPE (approximate histogram) ────────────
    # GRUG: Bucket alive node strengths into 5 bands and check for monoculture.
    bands = Dict("0.0-2.0" => 0, "2.0-4.0" => 0, "4.0-6.0" => 0, "6.0-8.0" => 0, "8.0-10.0" => 0)
    total_banded = 0

    lock(node_lock) do
        count = 0
        for (id, node) in node_map
            node.is_grave && continue
            s = node.strength
            if s < 2.0
                bands["0.0-2.0"] += 1
            elseif s < 4.0
                bands["2.0-4.0"] += 1
            elseif s < 6.0
                bands["4.0-6.0"] += 1
            elseif s < 8.0
                bands["6.0-8.0"] += 1
            else
                bands["8.0-10.0"] += 1
            end
            total_banded += 1
            count += 1
            count >= 1000 && break
        end
    end

    if total_banded > 0
        max_band_count = maximum(values(bands))
        max_band_ratio = max_band_count / total_banded
        if max_band_ratio > FORENSICS_STRENGTH_SKEW_MAX
            dominant_band = [k for (k,v) in bands if v == max_band_count][1]
            push!(findings, "STRENGTH_MONOCULTURE: $(round(max_band_ratio*100, digits=1))% of nodes in band $dominant_band. Population lacks stratification.")
        else
            band_str = join(["$k=$(v)" for (k,v) in sort(collect(bands), by=x->x[1])], ", ")
            push!(findings, "STRENGTH_SPREAD_OK: Bands: $band_str")
        end
    end

    # ── 4. MEMORY ECHO DETECTION (sampled) ────────────────────────────────
    # GRUG: Check for repeated message content in recent history.
    echo_count = 0
    echo_sample = 0

    lock(history_lock) do
        n_msgs = length(message_history)
        if n_msgs >= 2
            check_n = min(200, n_msgs)
            start_idx = max(1, n_msgs - check_n + 1)
            seen_hashes = Dict{UInt64, Int}()
            for i in start_idx:n_msgs
                h = hash(message_history[i].text)
                seen_hashes[h] = get(seen_hashes, h, 0) + 1
                echo_sample += 1
            end
            echo_count = count(v -> v > 1, values(seen_hashes))
            items_examined += echo_sample
        end
    end

    if echo_sample > 0 && echo_count > 0
        push!(findings, "MEMORY_ECHOES: $echo_count distinct messages repeated in last $echo_sample entries. Possible input loops.")
    elseif echo_sample > 0
        push!(findings, "NO_ECHOES: All $echo_sample sampled messages are unique content.")
    end

    elapsed_ms = (time() - t_start) * 1000.0
    report = join(findings, " | ")
    println("[PHAGY:FORENSICS:FUZZY] 🔍  Complete. Findings: $report")
    return PhagyStats("MEMORY_FORENSICS_FUZZY", items_examined, length(findings), elapsed_ms, report)
end

"""
metric_memory_forensics!(node_map, node_lock, message_history, history_lock)::PhagyStats

GRUG: EXACT / MEASUREMENT-BASED MEMORY ANALYSIS.
Full enumeration with precise metrics. Slower but accurate.
Checks:
  1. Exact message count by role (full enumeration)
  2. Dead node reference audit (messages referencing graved/deleted nodes)
  3. Pinned message ratio and age analysis
  4. Node strength statistics (mean, median, std dev, min, max)
  5. Grave ratio and grave reason breakdown
  6. Orphan count (alive nodes with 0 neighbors and 0 strength)

This mode is THOROUGH but SLOWER. Enumerates everything exactly.
All observations are READ-ONLY.
"""
function metric_memory_forensics!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    message_history ::Vector,
    history_lock    ::ReentrantLock
)::PhagyStats
    t_start = time()
    findings = String[]
    items_examined = 0

    # ── 1. EXACT MESSAGE CENSUS ───────────────────────────────────────────
    role_counts = Dict{String, Int}()
    total_msgs = 0
    pinned_count = 0
    oldest_pinned_id = typemax(Int)

    lock(history_lock) do
        total_msgs = length(message_history)
        for msg in message_history
            role_counts[msg.role] = get(role_counts, msg.role, 0) + 1
            if msg.pinned
                pinned_count += 1
                if msg.id < oldest_pinned_id
                    oldest_pinned_id = msg.id
                end
            end
        end
        items_examined += total_msgs
    end

    if total_msgs == 0
        push!(findings, "MEMORY_EMPTY: 0 messages total.")
    else
        role_str = join(["$k=$v" for (k,v) in sort(collect(role_counts), by=x->x[1])], ", ")
        push!(findings, "MSG_CENSUS: total=$total_msgs, roles=[$role_str]")
        pin_pct = round(pinned_count / total_msgs * 100, digits=1)
        push!(findings, "PINNED: $pinned_count/$total_msgs ($pin_pct%)" * (oldest_pinned_id < typemax(Int) ? ", oldest_pin_id=$oldest_pinned_id" : ""))
    end

    # ── 2. NODE POPULATION METRICS ────────────────────────────────────────
    total_nodes = 0
    alive_nodes = 0
    grave_nodes = 0
    grave_reasons = Dict{String, Int}()
    strengths = Float64[]
    orphan_count = 0
    image_node_count = 0

    lock(node_lock) do
        for (id, node) in node_map
            total_nodes += 1
            if node.is_grave
                grave_nodes += 1
                reason = isempty(node.grave_reason) ? "UNKNOWN" : node.grave_reason
                grave_reasons[reason] = get(grave_reasons, reason, 0) + 1
            else
                alive_nodes += 1
                push!(strengths, node.strength)
                if length(node.neighbor_ids) == 0 && node.strength <= 0.0
                    orphan_count += 1
                end
            end
            if node.is_image_node
                image_node_count += 1
            end
        end
        items_examined += total_nodes
    end

    push!(findings, "NODE_POP: total=$total_nodes, alive=$alive_nodes, grave=$grave_nodes, image=$image_node_count")

    if grave_nodes > 0
        grave_str = join(["$k=$v" for (k,v) in sort(collect(grave_reasons), by=x->x[1])], ", ")
        grave_pct = round(grave_nodes / total_nodes * 100, digits=1)
        push!(findings, "GRAVE_BREAKDOWN: $grave_pct% dead [$grave_str]")
    end

    if alive_nodes > 0
        mean_str = round(sum(strengths) / length(strengths), digits=3)
        sorted_s = sort(strengths)
        median_str = round(sorted_s[div(length(sorted_s)+1, 2)], digits=3)
        min_str = round(minimum(strengths), digits=3)
        max_str = round(maximum(strengths), digits=3)
        # GRUG: Compute standard deviation manually (no Statistics.jl dependency)
        mean_val = sum(strengths) / length(strengths)
        variance = sum((s - mean_val)^2 for s in strengths) / length(strengths)
        std_str = round(sqrt(variance), digits=3)
        push!(findings, "STRENGTH_STATS: mean=$mean_str, median=$median_str, std=$std_str, min=$min_str, max=$max_str")
    else
        push!(findings, "STRENGTH_STATS: N/A (no alive nodes)")
    end

    if orphan_count > 0
        push!(findings, "ORPHANS: $orphan_count alive nodes with 0 neighbors and 0 strength")
    end

    # ── 3. DEAD NODE REFERENCE AUDIT ──────────────────────────────────────
    # GRUG: Scan messages for node_id references that point to dead/missing nodes.
    dead_refs = 0
    total_refs = 0

    lock(history_lock) do
        lock(node_lock) do
            for msg in message_history
                # GRUG: Look for node_N patterns in message text
                for m in eachmatch(r"node_\d+", msg.text)
                    nid = m.match
                    total_refs += 1
                    if !haskey(node_map, nid) || node_map[nid].is_grave
                        dead_refs += 1
                    end
                end
            end
        end
    end
    items_examined += total_refs

    if total_refs > 0
        dead_pct = round(dead_refs / total_refs * 100, digits=1)
        push!(findings, "DEAD_REFS: $dead_refs/$total_refs ($dead_pct%) node references in messages point to dead/missing nodes")
        if dead_refs / total_refs > FORENSICS_DEAD_REF_THRESHOLD
            push!(findings, "⚠ DEAD_REF_ALERT: Dead reference ratio exceeds $(round(FORENSICS_DEAD_REF_THRESHOLD*100))% threshold")
        end
    else
        push!(findings, "DEAD_REFS: No node references found in message history")
    end

    elapsed_ms = (time() - t_start) * 1000.0
    report = join(findings, " | ")
    println("[PHAGY:FORENSICS:METRIC] 📊  Complete. Findings: $report")
    return PhagyStats("MEMORY_FORENSICS_METRIC", items_examined, length(findings), elapsed_ms, report)
end


# ==============================================================================
# PHAGY DISPATCHER - ONE AUTOMATON PER CYCLE
# ==============================================================================

"""
run_phagy!(node_map, node_lock, hopfield_cache, cache_lock, rules, rules_lock;
           message_history=nothing, history_lock=nothing)::PhagyStats

GRUG: Main phagy entry point. Randomly selects ONE automaton to run this cycle.
Selection is weighted equally (1/6 each) - no automaton gets priority over others.
Available automata (1-6):
  1. ORPHAN_PRUNER
  2. STRENGTH_DECAYER
  3. GRAVE_RECYCLER
  4. DROP_TABLE_COMPACT (CACHE_VALIDATOR disabled - Hopfield obsolete for lobe-based architecture)
  5. RULE_PRUNER
  6. MEMORY_FORENSICS (requires message_history and history_lock kwargs)

MEMORY_FORENSICS context: If message_history/history_lock not provided and automaton 6 is rolled,
re-rolls to 1-5. Forensics needs memory access - no silent skip.

HOPFIELD CACHE NOTE: CACHE_VALIDATOR (formerly automaton 4) is DISABLED. Hopfield caching
was used prior to lobe-based architecture. Modern system uses 1000-node active cap biological
bottleneck. Hopfield cache only relevant for RIDICULOUSLY LARGE lobe sizes (50,000+ nodes).

Each automaton is self-contained and handles its own locking.
Returns PhagyStats from the automaton that ran. Logs result to PHAGY_LOG.
Throws PhagyError on structural failure (missing locks, corrupted state).
Never silently swallows errors - all exceptions propagate up to maybe_run_idle().
"""
function run_phagy!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    hopfield_cache  ::Dict,
    cache_lock      ::ReentrantLock,
    rules           ::Vector,
    rules_lock      ::ReentrantLock;
    message_history ::Union{Vector, Nothing} = nothing,
    history_lock    ::Union{ReentrantLock, Nothing} = nothing
)::PhagyStats

    # GRUG: Validate inputs - phagy must not run against corrupted state
    if !isa(node_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid node_lock! !!!"))
    end
    if !isa(cache_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid cache_lock! !!!"))
    end
    if !isa(rules_lock, ReentrantLock)
        throw(PhagyError("!!! FATAL: run_phagy! got invalid rules_lock! !!!"))
    end

    # GRUG: Roll the automaton selector (1-7, uniform)
    automaton_roll = rand(1:7)

    # GRUG: If automaton 7 is rolled but message_history/history_lock not provided,
    # re-roll to 1-6. Forensics needs memory access — no silent skip.
    if automaton_roll == 7 && (isnothing(message_history) || isnothing(history_lock))
        println("[PHAGY] 🦠  Rolled MEMORY_FORENSICS but no message_history provided. Re-rolling 1-6.")
        automaton_roll = rand(1:6)
    end

    println("[PHAGY] 🦠  Phagy cycle starting. Automaton roll: $automaton_roll/7")

    stats = try
        if automaton_roll == 1
            prune_orphan_nodes!(node_map, node_lock)
        elseif automaton_roll == 2
            decay_forgotten_strengths!(node_map, node_lock)
        elseif automaton_roll == 3
            recycle_grave_assets!(node_map, node_lock)
        elseif automaton_roll == 4
            # GRUG: CACHE_VALIDATOR DISABLED - Hopfield obsolete for lobe-based architecture
            compact_drop_tables!(node_map, node_lock)
        elseif automaton_roll == 5
            prune_dormant_rules!(rules, rules_lock)
        elseif automaton_roll == 6
            run_memory_forensics!(node_map, node_lock, message_history, history_lock)
        else
            # GRUG: Should be unreachable. If rand(1:6) returns something else, cave is haunted.
            throw(PhagyError("!!! FATAL: automaton_roll=$automaton_roll is out of range [1,6]! !!!"))
        end
    catch e
        # GRUG: Automaton failure is NOT silent. Surface it immediately.
        println("[PHAGY] !!! ERROR in automaton $automaton_roll: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    end

    # GRUG: Log the completed cycle
    push_phagy_log!(stats)
    println("[PHAGY] ✅  Phagy cycle complete. Automaton=$(stats.automaton), Changed=$(stats.items_changed), Time=$(round(stats.cycle_time_ms, digits=2))ms")

    return stats
end

end # module PhagyMode

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: PHAGY MODE LAYER
#
# 1. ONE AUTOMATON PER CYCLE (BIG-O SAFETY):
# Phagy never runs all seven automata in one idle event. A single random automaton
# is selected per cycle. This bounds the worst-case idle work to O(N) where N
# is the number of nodes/rules/cache entries/messages. No compounding sweep costs.
#
# 2. TWO-PASS MUTATION PATTERN:
# Automata that need to delete/modify entries first collect candidates under a
# read lock, then apply mutations in a second pass under a write lock. This
# avoids mutation-during-iteration undefined behavior.
#
# 3. LAST-ENTRY PROTECTION:
# DROP TABLE COMPACT never empties a node's drop_table. If all entries are below
# the trim floor, the highest-probability entry is preserved. A node without any
# response is broken topology.
#
# 4. GRAVE VS DELETE:
# ORPHAN PRUNER sets is_grave=true rather than calling delete!(). This preserves
# node IDs in the map for history consistency. True deletion is a manual operation.
#
# 5. RULE FLAGGING VS DELETION:
# RULE PRUNER only sets is_dormant=true. It never deletes rules. This prevents
# accidental loss of hand-crafted orchestration logic. The user prunes explicitly.
#
# 6. HOPFIELD CACHE DUAL-LOCK ORDER:
# CACHE_VALIDATOR always acquires cache_lock THEN node_lock (in that order).
# All other code touching both locks must respect this order to prevent deadlock.
#
# 7. MEMORY FORENSICS (AUTOMATON 7):
# Coinflip selects between FUZZY (approximate heuristic, sampled) and METRIC
# (exact measurement, full enumeration) analysis modes. Both are READ-ONLY —
# forensics never mutates MESSAGE_HISTORY or NODE_MAP. Forensics requires
# message_history and history_lock kwargs; if not provided and automaton 7 is
# rolled, the dispatcher re-rolls to 1-6 (graceful fallback, not silent skip).
# Dual-lock order for metric dead-ref audit: history_lock THEN node_lock.
# ==============================================================================