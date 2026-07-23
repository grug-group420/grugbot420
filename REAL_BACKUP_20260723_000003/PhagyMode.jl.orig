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
#   - Twelve automata are available, selected randomly each cycle:
#       1. ORPHAN PRUNER          - Cull nodes with zero connections (in + out)
#       2. STRENGTH DECAYER       - Batch-decay nodes unseen for N sessions
#       3. GRAVE RECYCLER         - Salvage drop_table assets before final deletion
#       4. DROP TABLE COMPACT     - Dedupe + trim low-probability drop_table tails
#       5. RULE PRUNER            - Flag/remove orchestration rules that never fire
#       6. MEMORY FORENSICS       - Coinflip: fuzzy (approximate) or metric (exact) analysis
#       7. (reserved — CACHE_VALIDATOR disabled, Hopfield obsolete)
#       8. INJECTOR GRAVEYARD SWEEP  - Reap zombie vigilance injector agents (v7.30)
#       9. PHASE ACCUMULATOR AGING   - Trim oldest crystal snapshots (v7.30)
#      10. OBSERVER STORE PRUNING    - Evict low-salience subconscious entries (v7.30)
#      11. SIGIL CONSISTENCY CHECK   - Flag malformed sigil table entries (v7.30, read-only)
#      12. TRAJECTORY STALE TRIM     - Trim stale trajectory buffer entries (v7.30)
#
# DESIGN RULES:
#   - No silent failures. Every error surfaces.
#   - One automaton per cycle. Never all twenty-two at once.
#   - Thread-safe: all shared-state access goes through proper locks.
#   - PhagyStats returned on every run for diagnostics and /status CLI.
#   - New v7.30 automata (8-12) are SLOW and CAUTIOUS. Night janitor, not bulldozer.
# ==============================================================================

module PhagyMode

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
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

using Random

export run_phagy!, PhagyStats, get_phagy_log, PhagyError, run_memory_forensics!, fuzzy_memory_forensics!, metric_memory_forensics!
# GRUG v7.30: New automata for idle-time phagy maintenance of v7.27-7.29 systems.
export prune_orphan_nodes!, decay_forgotten_strengths!, recycle_grave_assets!, compact_drop_tables!, prune_dormant_rules!
export sweep_injector_graveyard!, age_phase_accumulator!, prune_observer_store!, check_sigil_consistency!, trim_stale_trajectory!
# GRUG v7.31: Full organ coverage — automata 13-23 for every unbounded system.
export lobe_population_guard!, chatter_cooldown_purge!, attachment_grave_sweep!, group_grave_sweep!, immune_state_trim!
export chatter_log_rotate!, phagy_log_rotate!, mitosis_log_rotate!, lobe_connection_audit!, mlp_rule_grave_sweep!
export relational_triple_audit!

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
    # GRUG v7.30: New automata for idle-time maintenance of v7.27-7.29 systems.
    "INJECTOR_GRAVEYARD_SWEEP" => 5.0,   # GRUG: Dict iteration, fast
    "PHASE_ACCUMULATOR_AGING"  => 5.0,   # GRUG: Small dict, fast
    "OBSERVER_STORE_PRUNING"   => 15.0,  # GRUG: May iterate up to 4096 entries
    "SIGIL_CONSISTENCY_CHECK"  => 5.0,   # GRUG: Small dict, fast
    "TRAJECTORY_STALE_TRIM"    => 5.0,   # GRUG: Small ring buffer, fast
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
  - "node_map"            : NODE_MAP iteration
  - "node_map_write"      : NODE_MAP mutation
  - "hopfield_cache"      : HOPFIELD_CACHE access
  - "rules"               : RULES vector access
  - "message_history"     : MESSAGE_HISTORY read access
  - "injector_registry"   : _ACTIVE_INJECTORS dict access (v7.30)
  - "phase_accumulator"   : PhaseAccumulator entries access (v7.30)
  - "observer_store"      : SubconsciousStore table access (v7.30)
  - "sigil_table"         : SigilTable entries access (v7.30)
  - "trajectory"          : Trajectory buffer access (v7.30)
  - "global"              : Global state (no simultaneous phagy)

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
# GRUG v7.30: NEW CONSTANTS FOR IDLE-TIME MAINTENANCE OF v7.27-7.29 SYSTEMS
# ==============================================================================
# These are SLOW, CAUTIOUS thresholds. Idle phagy is not an aggressive sweeper.
# It's a night janitor. One slow pass, one small change, then done.

# GRUG: AUTOMATON 8 — INJECTOR GRAVEYARD SWEEP
# How far past timeout an injector agent must be before we call it a zombie.
# Agents that are merely AT their timeout might still be finishing up —
# we only clean up ones that are well past their expiration.
const INJECTOR_ZOMBIE_MARGIN_SECONDS = 10.0  # GRUG: 10s past timeout = zombie

# GRUG: AUTOMATON 9 — PHASE ACCUMULATOR AGING
# Maximum snapshots in the crystal before aging kicks in. The crystal grows
# as ATP escalates and snapshots accumulate. Without a cap, the crystal
# becomes an expensive O(N) scan for every phase_pull_query.
const MAX_PHASE_SNAPSHOTS = 200     # GRUG: 200 snapshots = plenty of temporal memory
# How many oldest snapshots to trim per aging cycle. SLOW — one cycle, small cut.
const PHASE_AGING_TRIM_COUNT = 5    # GRUG: Trim 5 oldest per cycle (cautious)

# GRUG: AUTOMATON 10 — SELF-OBSERVER STORE PRUNING
# Pruning only activates when the store is above this fill ratio. Below this,
# the store is healthy and pruning is unnecessary waste.
const OBSERVER_PRUNE_FILL_RATIO = 0.85  # GRUG: Only prune when >85% full
# How many lowest-salience entries to evict per pruning cycle. SLOW.
const OBSERVER_PRUNE_EVICT_COUNT = 8    # GRUG: Evict 8 entries per cycle (gentle)

# GRUG: AUTOMATON 11 — SIGIL TABLE CONSISTENCY CHECK
# This automaton is READ-ONLY — it only flags inconsistencies, never mutates.
# It checks that sigil entries reference valid classes and scopes, and that
# lexicons don't contain empty strings.

# GRUG: AUTOMATON 12 — TRAJECTORY STALE TRIM
# How many halflives must pass without a new entry before the trajectory is
# considered stale. Stale trajectory means the system hasn't been predicting
# recently and the old predictions may be misleading.
const TRAJECTORY_STALE_HALFLIVES = 3.0  # GRUG: 3 halflives = very stale
# How many oldest entries to trim when trajectory is stale. Cautious.
const TRAJECTORY_STALE_TRIM_COUNT = 2   # GRUG: Trim 2 oldest per cycle

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
    AUTOMATON_NAME = "ORPHAN_PRUNER"
    RESOURCE_SCOPE = "node_map_write"
    
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
    AUTOMATON_NAME = "STRENGTH_DECAYER"
    RESOURCE_SCOPE = "node_map_write"
    
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
    AUTOMATON_NAME = "GRAVE_RECYCLER"
    RESOURCE_SCOPE = "node_map_write"
    
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
# )::PhagyStats
#     const AUTOMATON_NAME = "CACHE_VALIDATOR"
#     const RESOURCE_SCOPE = "hopfield_cache"
    
    # GRUG: Reserve resource to prevent collision with other phagy automata
#     if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
#         throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
#     end
    
#     # GRUG: Ensure cleanup happens no matter what (success, error, or timeout)
#     t_start = time()
#     try
#     examined   = 0
#     purged     = 0
#     valid      = 0
# 
#     stale_keys = UInt64[]
# 
#     # GRUG: PASS 1 - collect stale keys under both locks (cache_lock THEN node_lock)
#     # Lock order must always be cache_lock -> node_lock to prevent deadlock.
#     lock(cache_lock) do
#         lock(node_lock) do
#             for (cache_key, node_ids) in hopfield_cache
#                 examined += 1
#                 # GRUG: Entry is stale if ANY referenced node is missing or graved
#                 is_stale = any(node_ids) do nid
#                     !haskey(node_map, nid) || node_map[nid].is_grave
#                 end
#                 if is_stale
#                     push!(stale_keys, cache_key)
#                 else
#                     valid += 1
#                 end
#             end
#         end
#     end
# 
#     # GRUG: PASS 2 - delete stale entries under cache_lock only (node_map not touched)
#     if !isempty(stale_keys)
#         lock(cache_lock) do
#             for key in stale_keys
#                 delete!(hopfield_cache, key)
#                 purged += 1
#                 @debug "[PHAGY:CACHE] Purged stale cache entry key=$(key)"
#             end
#         end
#     end
# 
#     elapsed_ms = (time() - t_start) * 1000.0
#     notes = "Examined=$examined, Purged=$purged, ValidKept=$valid"
#     println("[PHAGY:CACHE] 🗄️   Cycle complete. $notes")
#     return PhagyStats("CACHE_VALIDATOR", examined, purged, elapsed_ms, notes)
# end  # DISABLED: validate_hopfield_cache! is commented out

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
function compact_drop_tables!(node_map::Dict, node_lock::ReentrantLock)::PhagyStats
    AUTOMATON_NAME = "DROP_TABLE_COMPACT"
    RESOURCE_SCOPE = "node_map_write"
    
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

                # GRUG: drop_table is Vector{String} — no probability data.
                # Deduplicate exact string matches instead.
                seen = Set{String}()
                deduped = String[]
                for entry in node.drop_table
                    if entry ∉ seen
                        push!(seen, entry)
                        push!(deduped, entry)
                    else
                        trimmed += 1
                    end
                end

                # GRUG: Apply "last entry" protection - never empty a drop_table
                if isempty(deduped) && !isempty(node.drop_table)
                    # Keep the last entry as fallback
                    deduped = [node.drop_table[end]]
                    protected += 1
                    @debug "[PHAGY:COMPACT] Node $id: last-entry protection applied"
                end

                # GRUG: Replace drop_table with deduplicated version
                if length(deduped) < length(node.drop_table)
                    node.drop_table = deduped
                end
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Trimmed=$trimmed, LastEntryProtections=$protected, TrimFloor=$DROP_TABLE_TRIM_FLOOR"
        println("[PHAGY:COMPACT] 🗜️   Cycle complete. $notes")
        return PhagyStats("DROP_TABLE_COMPACT", examined, trimmed, elapsed_ms, notes)
    catch e
        println("[PHAGY:COMPACT] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
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
function prune_dormant_rules!(rules::Vector, rules_lock::ReentrantLock)::PhagyStats
    AUTOMATON_NAME = "RULE_PRUNER"
    RESOURCE_SCOPE = "rules"
    
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
    catch e
        println("[PHAGY:RULES] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
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
# AUTOMATON 8: INJECTOR GRAVEYARD SWEEP (v7.30)
# ==============================================================================

"""
    sweep_injector_graveyard!(injector_dict, injector_lock)::PhagyStats

GRUG: Clean up stale/zombie injector agents from the _ACTIVE_INJECTORS dict.
Agents that are past their timeout_at by INJECTOR_ZOMBIE_MARGIN_SECONDS are
considered zombies — they should have finished long ago but didn't clean up
(e.g., their @async task crashed or was orphaned). This automaton removes
them so the dispatch cap isn't artificially reduced by dead agents.

SAFETY: Only removes agents with status :probing or :spawning that are well
past their timeout. Agents with status :done or :timed_out are left for the
normal completion path. Never removes agents that are merely AT their timeout.

COLLISION PROTECTION: Reserves "injector_registry" resource before execution.
TIMEOUT: 5 second limit enforced by dispatcher.
"""
function sweep_injector_graveyard!(injector_dict::Dict, injector_lock::ReentrantLock)::PhagyStats
    AUTOMATON_NAME = "INJECTOR_GRAVEYARD_SWEEP"
    RESOURCE_SCOPE = "injector_registry"

    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end

    t_start = time()
    try
        examined = 0
        reaped   = 0
        skipped_alive = 0
        now = time()

        zombie_ids = String[]

        lock(injector_lock) do
            for (id, agent) in injector_dict
                examined += 1
                # GRUG: Only reap agents that are STUCK in probing/spawning AND
                # are well past their timeout. Done/timed_out agents clean up
                # through the normal dispatch path.
                if agent.status != :probing && agent.status != :spawning
                    skipped_alive += 1
                    continue
                end
                timeout_at = agent.timeout_at
                if now > timeout_at + INJECTOR_ZOMBIE_MARGIN_SECONDS
                    push!(zombie_ids, id)
                else
                    skipped_alive += 1
                end
            end
        end

        # GRUG: Second pass — remove the identified zombies under lock.
        if !isempty(zombie_ids)
            lock(injector_lock) do
                for id in zombie_ids
                    if haskey(injector_dict, id)
                        delete!(injector_dict, id)
                        reaped += 1
                        @debug "[PHAGY:INJECTOR] Reaped zombie injector agent $id"
                    end
                end
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Reaped=$reaped, SkippedAlive=$skipped_alive, ZombieMargin=$(INJECTOR_ZOMBIE_MARGIN_SECONDS)s"
        println("[PHAGY:INJECTOR] 🧹  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, reaped, elapsed_ms, notes)

    catch e
        println("[PHAGY:INJECTOR] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 9: PHASE ACCUMULATOR AGING (v7.30)
# ==============================================================================

"""
    age_phase_accumulator!(phase_acc)::PhagyStats

GRUG: Trim oldest phase snapshots when the crystal grows beyond
MAX_PHASE_SNAPSHOTS. The crystal accumulates ATP distribution snapshots
over time. Without aging, every phase_pull_query scans an ever-growing
Dict — O(N) where N grows monotonically. This automaton keeps N bounded.

SAFETY: Only trims when crystal exceeds MAX_PHASE_SNAPSHOTS. Trims exactly
PHASE_AGING_TRIM_COUNT oldest entries per cycle (cautious, never aggressive).
Never trims below 10 entries (minimum viable crystal). Entries are sorted by
timestamp and the oldest are removed first — natural forgetting.

COLLISION PROTECTION: Reserves "phase_accumulator" resource before execution.
TIMEOUT: 5 second limit enforced by dispatcher.
"""
function age_phase_accumulator!(phase_acc)::PhagyStats
    AUTOMATON_NAME = "PHASE_ACCUMULATOR_AGING"
    RESOURCE_SCOPE = "phase_accumulator"

    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end

    t_start = time()
    try
        examined = 0
        trimmed   = 0
        skipped   = 0

        # GRUG: Check crystal size under the accumulator's own lock.
        # phase_acc.entries is a Dict{String, PhaseSnapshot}
        current_count = lock(phase_acc.lock) do
            length(phase_acc.entries)
        end
        examined = current_count

        if current_count <= MAX_PHASE_SNAPSHOTS
            # GRUG: Crystal is healthy — no aging needed.
            skipped = current_count
            elapsed_ms = (time() - t_start) * 1000.0
            notes = "Examined=$examined, Trimmed=0, SkippedHealthy=$skipped, Cap=$MAX_PHASE_SNAPSHOTS"
            println("[PHAGY:PHASE] 💎  Crystal healthy ($current_count ≤ $MAX_PHASE_SNAPSHOTS). No aging needed.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        # GRUG: Sort entries by age and trim the oldest ones.
        # PhaseSnapshot has an id that typically includes a timestamp.
        # We sort by the id string (which is monotonic with creation time)
        # and trim the first PHASE_AGING_TRIM_COUNT.
        trim_count = min(PHASE_AGING_TRIM_COUNT, current_count - 10)  # never below 10
        trim_count = max(trim_count, 0)  # safety clamp

        if trim_count == 0
            elapsed_ms = (time() - t_start) * 1000.0
            notes = "Examined=$examined, Trimmed=0, NearMinimum=10, Cap=$MAX_PHASE_SNAPSHOTS"
            println("[PHAGY:PHASE] 💎  Crystal near minimum ($current_count). No trim safe.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        lock(phase_acc.lock) do
            # GRUG: Sort keys by id (timestamp-embedded) and take the oldest.
            sorted_keys = sort(collect(keys(phase_acc.entries)))
            to_remove = sorted_keys[1:trim_count]
            for key in to_remove
                delete!(phase_acc.entries, key)
                trimmed += 1
            end
            # GRUG: Adjust the lifetime counter so diagnostics stay accurate.
            phase_acc.total_snapshots_recorded = max(0, phase_acc.total_snapshots_recorded - trimmed)
        end

        elapsed_ms = (time() - t_start) * 1000.0
        remaining = current_count - trimmed
        notes = "Examined=$examined, Trimmed=$trimmed, Remaining=$remaining, Cap=$MAX_PHASE_SNAPSHOTS"
        println("[PHAGY:PHASE] 🕰️  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, trimmed, elapsed_ms, notes)

    catch e
        println("[PHAGY:PHASE] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 10: SELF-OBSERVER STORE PRUNING (v7.30)
# ==============================================================================

"""
    prune_observer_store!(observer_store)::PhagyStats

GRUG: Gently prune the SelfObserver SubconsciousStore when it approaches
capacity. The store has a hard cap (MAX_TOTAL_ENTRIES = 4096) and its own
internal eviction, but that eviction is LRU-style and fires on every write.
This automaton does a gentler, broader sweep — evicting the globally
lowest-salience entries across ALL keys, not just the bucket being written to.

SAFETY: Only activates when store is above OBSERVER_PRUNE_FILL_RATIO (85%).
Evicts exactly OBSERVER_PRUNE_EVICT_COUNT (8) lowest-salience entries per
cycle. Never empties a bucket entirely (last-entry protection). This is
SLOWER and BROADER than the write-path eviction — it considers the whole
store, not just one key's bucket.

COLLISION PROTECTION: Reserves "observer_store" resource before execution.
TIMEOUT: 15 second limit enforced by dispatcher (may iterate up to 4096 entries).
"""
function prune_observer_store!(observer_store)::PhagyStats
    AUTOMATON_NAME = "OBSERVER_STORE_PRUNING"
    RESOURCE_SCOPE = "observer_store"

    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end

    t_start = time()
    try
        examined = 0
        evicted  = 0
        skipped  = 0

        # GRUG: Check store fill level. observer_store.total_entries is the
        # current count. MAX_TOTAL_ENTRIES (4096) is the hard cap.
        # We only prune when fill ratio > OBSERVER_PRUNE_FILL_RATIO.
        current_entries = observer_store.total_entries
        max_entries = 4096  # GRUG: SelfObserver.MAX_TOTAL_ENTRIES — hardcoded to avoid cross-module dep

        examined = current_entries

        if max_entries == 0
            elapsed_ms = (time() - t_start) * 1000.0
            notes = "Examined=$examined, Evicted=0, MaxEntries=0 (store not initialized)"
            println("[PHAGY:OBSERVER] ⚠️  Store max_entries is 0. Skipping.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        fill_ratio = Float64(current_entries) / Float64(max_entries)

        if fill_ratio <= OBSERVER_PRUNE_FILL_RATIO
            skipped = current_entries
            elapsed_ms = (time() - t_start) * 1000.0
            fill_pct = round(fill_ratio * 100, digits=1)
            notes = "Examined=$examined, Evicted=0, FillRatio=$(fill_pct)% ≤ $(round(OBSERVER_PRUNE_FILL_RATIO*100))%, SkippedHealthy"
            println("[PHAGY:OBSERVER] 🧠  Store healthy ($fill_pct% fill). No pruning needed.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        # GRUG: Find the globally lowest-salience entries across all keys.
        # We need to iterate the table, score each entry, and evict the
        # lowest OBSERVER_PRUNE_EVICT_COUNT entries.
        # SelfObserver.Microlog has fields: text, tag, weight, timestamp.
        # Score = weight * recency_factor (same as SelfObserver._evict_lowest!).
        # Recency factor decays exponentially with age.

        now = time()
        candidates = Tuple{Float64, String, Int}[]  # (score, key, index_in_bucket)

        lock(observer_store.write_lock) do
            for (key, bucket) in observer_store.table
                for (idx, entry) in enumerate(bucket)
                    # GRUG: Score using the same formula as SelfObserver._evict_lowest!
                    # weight * exp(-age / 60.0) — newer entries score higher.
                    age = now - entry.timestamp
                    recency = exp(-age / 60.0)
                    score = entry.weight * recency
                    push!(candidates, (score, key, idx))
                end
            end
        end

        # GRUG: Sort by score ascending — lowest salience first.
        sort!(candidates; by = c -> c[1])

        # GRUG: Group eviction by key so we can check bucket-level protection.
        # Never empty a bucket entirely (last-entry protection).
        keys_with_evictions = Dict{String, Vector{Int}}()
        for i in 1:min(OBSERVER_PRUNE_EVICT_COUNT, length(candidates))
            _, key, idx = candidates[i]
            if !haskey(keys_with_evictions, key)
                keys_with_evictions[key] = Int[]
            end
            push!(keys_with_evictions[key], idx)
        end

        # GRUG: Apply evictions under write lock with last-entry protection.
        actually_evicted = 0
        lock(observer_store.write_lock) do
            for (key, indices) in keys_with_evictions
                bucket = get(observer_store.table, key, nothing)
                isnothing(bucket) && continue
                # GRUG: Last-entry protection — never empty a bucket.
                if length(bucket) <= length(indices)
                    # Would empty the bucket. Skip this key entirely.
                    continue
                end
                # Sort indices descending so we can delete from back without
                # shifting subsequent indices.
                sorted_idx = sort(indices; rev=true)
                for idx in sorted_idx
                    if idx <= length(bucket)
                        deleteat!(bucket, idx)
                        actually_evicted += 1
                        observer_store.total_entries -= 1
                    end
                end
                # GRUG: If bucket is now empty, remove the key entirely.
                isempty(bucket) && delete!(observer_store.table, key)
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        fill_pct = round(fill_ratio * 100, digits=1)
        remaining = observer_store.total_entries
        notes = "Examined=$examined, Evicted=$actually_evicted, FillRatio=$(fill_pct)%, Remaining=$remaining"
        println("[PHAGY:OBSERVER] 🧠  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, actually_evicted, elapsed_ms, notes)

    catch e
        println("[PHAGY:OBSERVER] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 11: SIGIL TABLE CONSISTENCY CHECK (v7.30)
# ==============================================================================

"""
    check_sigil_consistency!(sigil_table)::PhagyStats

GRUG: Verify sigil entries reference valid classes and scopes, and that
lexicons don't contain empty strings. This automaton is READ-ONLY — it
only flags inconsistencies, never mutates. The operator must fix issues
manually via CLI commands.

Checks:
  1. Sigil class is one of the known valid classes (noun, verb, adj, etc.)
  2. Applies_at scope is one of the known valid scopes (bind, promote, expand)
  3. Lexicon entries (if present) are non-empty strings
  4. Expansion is non-empty for expand-type sigils
  5. Name is non-empty and unique (checked by registry already, but double-check)

SAFETY: READ-ONLY. Never adds, removes, or modifies sigil entries.
         Only reports findings for operator review.

COLLISION PROTECTION: Reserves "sigil_table" resource before execution.
TIMEOUT: 5 second limit enforced by dispatcher.
"""
function check_sigil_consistency!(sigil_table)::PhagyStats
    AUTOMATON_NAME = "SIGIL_CONSISTENCY_CHECK"
    RESOURCE_SCOPE = "sigil_table"

    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end

    t_start = time()
    try
        examined = 0
        findings = 0
        healthy  = 0

        # GRUG: Known valid classes and scopes. These are the engine-defined
        # set. Custom classes are allowed but flagged as non-standard.
        valid_classes = Set(["noun", "verb", "adj", "adv", "prep", "conj", "det", "pron", "punct", "num", "custom"])
        valid_scopes  = Set(["bind", "promote", "expand", "tokenize", "postbind"])

        for (name, entry) in sigil_table.entries
            examined += 1
            issues = String[]

            # GRUG: Check class validity
            entry_class = string(entry.class)
            if isempty(entry_class)
                push!(issues, "empty_class")
            elseif !(lowercase(entry_class) in valid_classes)
                push!(issues, "nonstandard_class:'$entry_class'")
            end

            # GRUG: Check applies_at scope validity
            entry_scope = string(entry.applies_at)
            if isempty(entry_scope)
                push!(issues, "empty_scope")
            elseif !(lowercase(entry_scope) in valid_scopes)
                push!(issues, "nonstandard_scope:'$entry_scope'")
            end

            # GRUG: Check lexicon entries are non-empty
            if entry.lexicon !== nothing
                for word in entry.lexicon
                    if isempty(strip(word))
                        push!(issues, "empty_lexicon_entry")
                        break  # one flag is enough per sigil
                    end
                end
            end

            # GRUG: Check expansion is non-empty for expand-type sigils
            if entry_scope == "expand" && (entry.expansion === nothing || isempty(entry.expansion))
                push!(issues, "expand_sigil_with_no_expansion")
            end

            # GRUG: Check name is non-empty
            if isempty(entry.name)
                push!(issues, "empty_name")
            end

            if !isempty(issues)
                findings += 1
                @debug "[PHAGY:SIGIL] Sigil '$name' issues: $(join(issues, ", "))"
            else
                healthy += 1
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        notes = "Examined=$examined, Issues=$findings, Healthy=$healthy"
        if findings > 0
            println("[PHAGY:SIGIL] 🔍  Cycle complete. $notes (READ-ONLY — operator must fix)")
        else
            println("[PHAGY:SIGIL] ✅  Cycle complete. All $examined sigils healthy.")
        end
        return PhagyStats(AUTOMATON_NAME, examined, findings, elapsed_ms, notes)

    catch e
        println("[PHAGY:SIGIL] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end

# ==============================================================================
# AUTOMATON 12: TRAJECTORY STALE TRIM (v7.30)
# ==============================================================================

"""
    trim_stale_trajectory!(trajectory_config_ref, trajectory_buffer, trajectory_lock)::PhagyStats

GRUG: If the ActionTonePredictor trajectory buffer hasn't received a new entry
for TRAJECTORY_STALE_HALFLIVES times the decay_halflife, it's stale. Old
predictions that haven't been reinforced may mislead the Lorenz damping system.
This automaton gently trims the oldest entries when the trajectory is stale,
letting the buffer "forget" outdated behavioral patterns.

SAFETY: Only trims when trajectory is stale (no recent entries). Trims exactly
TRAJECTORY_STALE_TRIM_COUNT (2) oldest entries per cycle. Never empties the
buffer — at least 2 entries are always preserved. The trajectory lock is
acquired for the entire operation.

COLLISION PROTECTION: Reserves "trajectory" resource before execution.
TIMEOUT: 5 second limit enforced by dispatcher.
"""
function trim_stale_trajectory!(trajectory_config_ref, trajectory_buffer, trajectory_lock)::PhagyStats
    AUTOMATON_NAME = "TRAJECTORY_STALE_TRIM"
    RESOURCE_SCOPE = "trajectory"

    if !reserve_phagy_resource!(AUTOMATON_NAME, RESOURCE_SCOPE)
        throw(PhagyError("!!! COLLISION: $AUTOMATON_NAME cannot reserve '$RESOURCE_SCOPE' - already in use! !!!"))
    end

    t_start = time()
    try
        examined = 0
        trimmed  = 0
        now = time()

        buffer_len = lock(trajectory_lock) do
            length(trajectory_buffer)
        end
        examined = buffer_len

        if buffer_len == 0
            elapsed_ms = (time() - t_start) * 1000.0
            notes = "Examined=0, Trimmed=0, BufferEmpty"
            println("[PHAGY:TRAJECTORY] 📊  Buffer empty. Nothing to trim.")
            return PhagyStats(AUTOMATON_NAME, 0, 0, elapsed_ms, notes)
        end

        # GRUG: Check staleness. If the most recent entry's timestamp is
        # more than TRAJECTORY_STALE_HALFLIVES * decay_halflife seconds ago,
        # the trajectory is stale.
        decay_halflife = lock(trajectory_lock) do
            trajectory_config_ref[].decay_halflife
        end
        staleness_threshold = TRAJECTORY_STALE_HALFLIVES * decay_halflife

        latest_ts = lock(trajectory_lock) do
            trajectory_buffer[end].timestamp
        end

        age = now - latest_ts
        is_stale = age > staleness_threshold

        if !is_stale
            elapsed_ms = (time() - t_start) * 1000.0
            age_rounded = round(age, digits=1)
            notes = "Examined=$examined, Trimmed=0, NotStale (age=$(age_rounded)s < $(round(staleness_threshold, digits=1))s)"
            println("[PHAGY:TRAJECTORY] 📊  Trajectory fresh (age=$(age_rounded)s). No trim needed.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        # GRUG: Trajectory is stale. Trim oldest entries, but never below 2.
        trim_count = min(TRAJECTORY_STALE_TRIM_COUNT, buffer_len - 2)
        trim_count = max(trim_count, 0)  # safety clamp

        if trim_count == 0
            elapsed_ms = (time() - t_start) * 1000.0
            notes = "Examined=$examined, Trimmed=0, NearMinimum=2"
            println("[PHAGY:TRAJECTORY] 📊  Buffer near minimum ($buffer_len). No trim safe.")
            return PhagyStats(AUTOMATON_NAME, examined, 0, elapsed_ms, notes)
        end

        lock(trajectory_lock) do
            for _ in 1:trim_count
                if length(trajectory_buffer) > 2
                    popfirst!(trajectory_buffer)
                    trimmed += 1
                end
            end
        end

        elapsed_ms = (time() - t_start) * 1000.0
        remaining = buffer_len - trimmed
        age_rounded = round(age, digits=1)
        notes = "Examined=$examined, Trimmed=$trimmed, Remaining=$remaining, Staleness=$(age_rounded)s"
        println("[PHAGY:TRAJECTORY] 📊  Cycle complete. $notes")
        return PhagyStats(AUTOMATON_NAME, examined, trimmed, elapsed_ms, notes)

    catch e
        println("[PHAGY:TRAJECTORY] !!! ERROR: $e !!!")
        Base.show_backtrace(stdout, catch_backtrace())
        rethrow(e)
    finally
        release_phagy_resource!(RESOURCE_SCOPE)
    end
end



# ==============================================================================

# ==============================================================================
# GRUG v7.31: NEW AUTOMATA 13-23 — FULL ORGAN COVERAGE
# ==============================================================================
# Every organ that grows without bounds now has a phagy groundskeeper.
# Philosophy: HIGH COHERENCE (speak the language of the system), LOW FIDELITY
# (light touch, preserve big-O bounds, never aggressively reshape).
# Phagy is a groundskeeper, not a renovator. Trim the hedge, don't uproot it.
# ==============================================================================

# ── AUTOMATON 13: LOBE POPULATION GUARD ──────────────────────────────────────
# Tier 1: Urgent — lobes can exceed node_cap if grave nodes accumulate.
# Soft enforcement: dampen weakest alive nodes in over-cap lobes toward grave.
# Max dampens: LOBE_POP_GUARD_MAX_DAMPENS (3) per cycle. Never graves a node
# with strength > LOBE_POP_GUARD_SPARE_FLOOR (0.3) — those are too healthy.

const LOBE_POP_GUARD_MAX_DAMPENS = 3
const LOBE_POP_GUARD_SPARE_FLOOR = 0.3   # don't dampen nodes above this strength

"""
    lobe_population_guard!(node_map, node_lock, lobe_registry, lobe_lock)::PhagyStats

GRUG: Soft cap enforcement for lobes. When a lobe's alive count exceeds its
node_cap, the weakest alive nodes (below LOBE_POP_GUARD_SPARE_FLOOR) get their
strength dampened by half — pushing them toward grave. This is NOT deletion;
it's a gentle nudge so the next STRENGTH_DECAYER or natural decay finishes the
job. Max LOBE_POP_GUARD_MAX_DAMPENS (3) per cycle. Never touches healthy nodes.
"""
function lobe_population_guard!(
    node_map      ::Dict,
    node_lock     ::ReentrantLock,
    lobe_registry ::Dict,
    lobe_lock     ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    overcap_lobes = String[]
    lock(lobe_lock) do
        for (lobe_id, rec) in lobe_registry
            alive_count = count(nid -> haskey(node_map, nid) && !node_map[nid].is_grave, rec.node_ids)
            items_examined += 1
            if alive_count > rec.node_cap
                push!(overcap_lobes, lobe_id)
            end
        end
    end

    if isempty(overcap_lobes)
        elapsed_ms = (time() - t0) * 1000
        return PhagyStats("LOBE_POPULATION_GUARD", items_examined, 0, elapsed_ms,
                          "All lobes within cap. No action needed.")
    end

    dampen_candidates = Tuple{String, String, Float64}[]  # (lobe_id, node_id, strength)
    for lobe_id in overcap_lobes
        rec = lock(lobe_lock) do; lobe_registry[lobe_id]; end
        lock(node_lock) do
            for nid in rec.node_ids
                haskey(node_map, nid) || continue
                node = node_map[nid]
                node.is_grave && continue
                if node.strength < LOBE_POP_GUARD_SPARE_FLOOR
                    push!(dampen_candidates, (lobe_id, nid, node.strength))
                end
            end
        end
    end

    sort!(dampen_candidates, by = x -> x[3])  # weakest first
    applied = 0
    for (lobe_id, nid, _str) in dampen_candidates
        applied >= LOBE_POP_GUARD_MAX_DAMPENS && break
        lock(node_lock) do
            haskey(node_map, nid) || return  # could have been removed
            node = node_map[nid]
            node.is_grave && return
            node.strength = node.strength * 0.5
            items_changed += 1
        end
        applied += 1
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "$(length(overcap_lobes)) lobe(s) over cap. Dampened $applied weak node(s)."
    return PhagyStats("LOBE_POPULATION_GUARD", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 14: CHATTER COOLDOWN PURGE ─────────────────────────────────────
# Tier 1: Urgent — CHATTER_NODE_COOLDOWN and MORPH_COOLDOWN_MAP grow without
# bounds as nodes accumulate cooldown entries. Purge expired entries.
# CHATTER_NODE_COOLDOWN_SECONDS = 3600.0 (1hr), MORPH_COOLDOWN_SECONDS = 86400.0 (24hr).

const CHATTER_COOLDOWN_PURGE_MAX = 50  # max entries to purge per cycle

"""
    chatter_cooldown_purge!(chatter_node_cooldown, chatter_node_cooldown_lock,
                            morph_cooldown_map, morph_cooldown_lock)::PhagyStats

GRUG: Expire stale cooldown entries from both CHATTER_NODE_COOLDOWN (1hr window)
and MORPH_COOLDOWN_MAP (24hr window). These dicts only grow — entries are set
but never cleaned up. This automaton removes entries whose cooldown window has
elapsed, freeing memory and keeping lookups fast. Max CHATTER_COOLDOWN_PURGE_MAX
(50) entries purged per cycle across both maps.
"""
function chatter_cooldown_purge!(
    chatter_node_cooldown      ::Dict,
    chatter_node_cooldown_lock ::ReentrantLock,
    morph_cooldown_map         ::Dict,
    morph_cooldown_lock        ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""
    now = time()

    # GRUG: Purge expired chatter cooldowns (1hr window)
    chatter_expired = String[]
    lock(chatter_node_cooldown_lock) do
        for (nid, ts) in chatter_node_cooldown
            items_examined += 1
            if (now - ts) >= 3600.0
                push!(chatter_expired, nid)
            end
        end
    end

    # GRUG: Purge expired morph cooldowns (24hr window)
    morph_expired = String[]
    lock(morph_cooldown_lock) do
        for (nid, ts) in morph_cooldown_map
            items_examined += 1
            if (now - ts) >= 86400.0
                push!(morph_expired, nid)
            end
        end
    end

    # GRUG: Apply deletions — two-pass to avoid mutation-during-iteration
    purge_count = 0
    for nid in chatter_expired
        purge_count >= CHATTER_COOLDOWN_PURGE_MAX && break
        lock(chatter_node_cooldown_lock) do
            delete!(chatter_node_cooldown, nid)
        end
        items_changed += 1
        purge_count += 1
    end

    for nid in morph_expired
        purge_count >= CHATTER_COOLDOWN_PURGE_MAX && break
        lock(morph_cooldown_lock) do
            delete!(morph_cooldown_map, nid)
        end
        items_changed += 1
        purge_count += 1
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Examined $(items_examined) entries. Purged $items_changed expired cooldown(s)."
    return PhagyStats("CHATTER_COOLDOWN_PURGE", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 15: ATTACHMENT GRAVE SWEEP ─────────────────────────────────────
# Tier 1: Urgent — ATTACHMENT_MAP grows as nodes get attached. When nodes die,
# their attachment entries remain forever. This removes attachments for grave nodes.

const ATTACHMENT_GRAVE_SWEEP_MAX = 20  # max grave attachment vectors to clean per cycle

"""
    attachment_grave_sweep!(node_map, node_lock, attachment_map, attachment_lock)::PhagyStats

GRUG: When a node goes grave, its ATTACHMENT_MAP entry still has attached nodes
pointing at it — and the grave node may still have attachment vectors of its own.
This automaton removes the attachment vector for any target node that is grave,
since grave nodes never fire and their attachments are dead weight. Also removes
individual AttachedNode entries where the attached node_id references a grave node.
Max ATTACHMENT_GRAVE_SWEEP_MAX (20) target entries cleaned per cycle.
"""
function attachment_grave_sweep!(
    node_map        ::Dict,
    node_lock       ::ReentrantLock,
    attachment_map  ::Dict,
    attachment_lock ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    # GRUG v8.0: attachment_map is now BRIDGE_MAP (Dict{String, Vector{CascadeBridge}}).
    # CascadeBridge uses .partner_id instead of .node_id.
    # Bidirectional: when we remove a bridge from A's list, we must also remove
    # the reverse entry from B's list to keep BRIDGE_MAP consistent.

    # GRUG: Pass 1 — find bridge-holding nodes that are grave
    grave_targets = String[]
    lock(attachment_lock) do
        for (node_id, _bridges) in attachment_map
            items_examined += 1
            lock(node_lock) do
                if haskey(node_map, node_id) && node_map[node_id].is_grave
                    push!(grave_targets, node_id)
                end
            end
        end
    end

    # GRUG: Pass 2 — find alive nodes with grave partner bridges
    grave_partners = Tuple{String, Vector{String}}[]  # (node_id, [partner_ids_that_are_grave])
    lock(attachment_lock) do
        for (node_id, bridge_vec) in attachment_map
            skip_node = lock(node_lock) do
                haskey(node_map, node_id) && node_map[node_id].is_grave
            end
            skip_node && continue  # already counted in Pass 1
            grave_partner_ids = String[]
            for br in bridge_vec
                lock(node_lock) do
                    # GRUG v8.0: CascadeBridge uses .partner_id
                    pid = getfield(br, :partner_id)
                    if haskey(node_map, pid) && node_map[pid].is_grave
                        push!(grave_partner_ids, pid)
                    end
                end
            end
            if !isempty(grave_partner_ids)
                push!(grave_partners, (node_id, grave_partner_ids))
            end
        end
    end

    # GRUG: Apply — remove grave node entries entirely (and their reverse entries)
    applied = 0
    for node_id in grave_targets
        applied >= ATTACHMENT_GRAVE_SWEEP_MAX && break
        lock(attachment_lock) do
            if haskey(attachment_map, node_id)
                # GRUG v8.0: Before deleting, remove reverse entries from each partner
                for br in attachment_map[node_id]
                    pid = getfield(br, :partner_id)
                    if haskey(attachment_map, pid)
                        filter!(b -> getfield(b, :partner_id) != node_id, attachment_map[pid])
                        # GRUG: If partner's bridge list is now empty, remove the key
                        if isempty(attachment_map[pid])
                            delete!(attachment_map, pid)
                        end
                    end
                end
                delete!(attachment_map, node_id)
                items_changed += 1
                applied += 1
            end
        end
    end

    # GRUG: Apply — filter out grave-partner bridges from alive nodes (bidirectional)
    for (node_id, grave_pids) in grave_partners
        applied >= ATTACHMENT_GRAVE_SWEEP_MAX && break
        has_key = lock(attachment_lock) do; haskey(attachment_map, node_id); end
        has_key || continue
        lock(attachment_lock) do
            for gpid in grave_pids
                # Remove the bridge to grave partner from this node's list
                filter!(b -> getfield(b, :partner_id) != gpid, attachment_map[node_id])
                # GRUG v8.0: Also remove the reverse entry from the grave partner's list
                if haskey(attachment_map, gpid)
                    filter!(b -> getfield(b, :partner_id) != node_id, attachment_map[gpid])
                    if isempty(attachment_map[gpid])
                        delete!(attachment_map, gpid)
                    end
                end
                items_changed += 1
            end
            # GRUG: If this node's bridge list is now empty, remove the key
            if isempty(attachment_map[node_id])
                delete!(attachment_map, node_id)
            end
        end
        applied += 1
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "$(length(grave_targets)) grave target(s), $(length(grave_attached)) targets with grave attachments. Cleaned $items_changed."
    return PhagyStats("ATTACHMENT_GRAVE_SWEEP", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 16: GROUP GRAVE SWEEP ──────────────────────────────────────────
# Tier 1: Urgent — GROUP_MAP and NODE_TO_GROUP grow without bounds. Groups
# whose members are all grave are dead weight. Also prune grave members from
# partially-alive groups and clean NODE_TO_GROUP for grave nodes.

const GROUP_GRAVE_DISSOLVE_MAX = 5     # max fully-dead groups to dissolve per cycle
const GROUP_GRAVE_PRUNE_MAX    = 20    # max grave-member prunes per cycle

"""
    group_grave_sweep!(node_map, node_lock, group_map, group_lock, node_to_group)::PhagyStats

GRUG: Groups can accumulate grave members and never shrink. This automaton:
1. Dissolves groups where ALL members are grave (removes from GROUP_MAP + NODE_TO_GROUP).
2. Prunes grave member IDs from partially-alive groups.
3. Removes NODE_TO_GROUP entries for nodes no longer in any group.
Max GROUP_GRAVE_DISSOLVE_MAX (5) dissolutions and GROUP_GRAVE_PRUNE_MAX (20)
member prunes per cycle.
"""
function group_grave_sweep!(
    node_map      ::Dict,
    node_lock     ::ReentrantLock,
    group_map     ::Dict,
    group_lock    ::ReentrantLock,
    node_to_group ::Dict
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    # GRUG: Pass 1 — classify groups as fully-dead or partially-alive
    fully_dead_groups = String[]
    partially_alive   = Tuple{String, Vector{String}}[]  # (group_id, grave_member_ids)

    lock(group_lock) do
        for (gid, grp) in group_map
            items_examined += 1
            grave_members = String[]
            alive_found = false
            for mid in grp.members
                lock(node_lock) do
                    if haskey(node_map, mid)
                        if node_map[mid].is_grave
                            push!(grave_members, mid)
                        else
                            alive_found = true
                        end
                    else
                        # Node not in NODE_MAP at all — treat as grave
                        push!(grave_members, mid)
                    end
                end
            end

            if !alive_found && !isempty(grave_members)
                push!(fully_dead_groups, gid)
            elseif !isempty(grave_members)
                push!(partially_alive, (gid, grave_members))
            end
        end
    end

    # GRUG: Dissolve fully-dead groups
    dissolved = 0
    for gid in fully_dead_groups
        dissolved >= GROUP_GRAVE_DISSOLVE_MAX && break
        lock(group_lock) do
            haskey(group_map, gid) || return
            grp = group_map[gid]
            for mid in grp.members
                # Only remove NODE_TO_GROUP if it still points to this group
                if get(node_to_group, mid, nothing) == gid
                    delete!(node_to_group, mid)
                end
            end
            delete!(group_map, gid)
            items_changed += 1
            dissolved += 1
        end
    end

    # GRUG: Prune grave members from partially-alive groups
    pruned = 0
    for (gid, grave_ids) in partially_alive
        (dissolved + pruned) >= (GROUP_GRAVE_DISSOLVE_MAX + GROUP_GRAVE_PRUNE_MAX) && break
        lock(group_lock) do
            haskey(group_map, gid) || return
            grp = group_map[gid]
            for mid in grave_ids
                pruned >= GROUP_GRAVE_PRUNE_MAX && break
                if mid in grp.members
                    filter!(m -> m != mid, grp.members)
                    # Clean NODE_TO_GROUP if it still points here
                    if get(node_to_group, mid, nothing) == gid
                        delete!(node_to_group, mid)
                    end
                    items_changed += 1
                    pruned += 1
                end
            end
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "$(length(fully_dead_groups)) dead group(s), $(length(partially_alive)) partial. Dissolved=$dissolved, Pruned=$pruned."
    return PhagyStats("GROUP_GRAVE_SWEEP", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 17: IMMUNE STATE TRIM ──────────────────────────────────────────
# Tier 1: Urgent — IMMUNE_LEDGER grows without bounds (auto-trims at 10K but
# entries within that window can be very old). This trims entries older than
# IMMUNE_TRIM_WINDOW_SECONDS (24h), complementing the existing cap-based trim.

const IMMUNE_TRIM_WINDOW_SECONDS = 86400.0   # 24 hours
const IMMUNE_TRIM_MAX_ENTRIES    = 100        # max entries to trim per cycle

"""
    immune_state_trim!(immune_ledger, ledger_lock)::PhagyStats

GRUG: The immune ledger already auto-trims at MAX_LEDGER_ENTRIES (10000) by
dropping 10%. But entries within that cap can be arbitrarily old. This automaton
removes entries older than IMMUNE_TRIM_WINDOW_SECONDS (24h), keeping the ledger
fresh and relevant. Max IMMUNE_TRIM_MAX_ENTRIES (100) removed per cycle.
Complements the cap-based trim — both are needed.
"""
function immune_state_trim!(
    immune_ledger ::Vector,
    ledger_lock   ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""
    now = time()

    # GRUG: Find old entries — ledger is append-only so old entries are at the front
    old_count = 0
    lock(ledger_lock) do
        for entry in immune_ledger
            items_examined += 1
            if (now - entry.timestamp) > IMMUNE_TRIM_WINDOW_SECONDS
                old_count += 1
            else
                # Since ledger is time-ordered, once we find a recent entry we can stop
                break
            end
        end
    end

    old_count == 0 && begin
        elapsed_ms = (time() - t0) * 1000
        return PhagyStats("IMMUNE_STATE_TRIM", items_examined, 0, elapsed_ms,
                          "All ledger entries within $(IMMUNE_TRIM_WINDOW_SECONDS)s window.")
    end

    # GRUG: Trim — delete from front (oldest first), capped
    trim_count = min(old_count, IMMUNE_TRIM_MAX_ENTRIES)
    lock(ledger_lock) do
        for _ in 1:trim_count
            isempty(immune_ledger) && break
            deleteat!(immune_ledger, 1)
            items_changed += 1
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Found $old_count old entries. Trimmed $items_changed."
    return PhagyStats("IMMUNE_STATE_TRIM", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 18: CHATTER LOG ROTATE ─────────────────────────────────────────
# Tier 2: ChatterSession ring has MAX_CHATTER_LOG (200) cap, but sessions with
# zero swaps (no productive chatter) waste ring slots. Prune them.

const CHATTER_LOG_ROTATE_MAX = 10  # max stale sessions to prune per cycle

"""
    chatter_log_rotate!(chatter_log, chatter_log_lock)::PhagyStats

GRUG: The CHATTER_LOG ring is capped at MAX_CHATTER_LOG (200), but zero-swap
sessions (where no votes were exchanged) are dead weight. This automaton prunes
sessions where swaps_attempted == 0, freeing ring slots for productive sessions.
Max CHATTER_LOG_ROTATE_MAX (10) pruned per cycle. The ring's own cap-based
rotation handles overflow — this handles quality.
"""
function chatter_log_rotate!(
    chatter_log      ::Vector,
    chatter_log_lock ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    # GRUG: Find zero-swap sessions (stale sessions with no productive chatter)
    stale_indices = Int[]
    lock(chatter_log_lock) do
        for (i, session) in enumerate(chatter_log)
            items_examined += 1
            if session.swaps_attempted == 0
                push!(stale_indices, i)
            end
        end
    end

    isempty(stale_indices) && begin
        elapsed_ms = (time() - t0) * 1000
        return PhagyStats("CHATTER_LOG_ROTATE", items_examined, 0, elapsed_ms,
                          "All sessions have swaps. No stale entries.")
    end

    # GRUG: Prune oldest stale sessions first. Delete from back to preserve indices.
    prune_count = min(length(stale_indices), CHATTER_LOG_ROTATE_MAX)
    lock(chatter_log_lock) do
        for idx in reverse(stale_indices[1:prune_count])
            isempty(chatter_log) && break
            idx > length(chatter_log) && continue
            deleteat!(chatter_log, idx)
            items_changed += 1
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Found $(length(stale_indices)) stale session(s). Pruned $items_changed."
    return PhagyStats("CHATTER_LOG_ROTATE", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 19: PHAGY LOG ROTATE ───────────────────────────────────────────
# Tier 2: PHAGY_LOG is capped at MAX_PHAGY_LOG (50), but no-op cycles (0 items_changed)
# waste slots. Compact them.

const PHAGY_LOG_ROTATE_MAX = 5  # max no-op entries to compact per cycle

"""
    phagy_log_rotate!(phagy_log, phagy_log_lock)::PhagyStats

GRUG: The PHAGY_LOG ring is capped at MAX_PHAGY_LOG (50), but no-op cycles
(items_changed == 0) don't tell us anything useful. This automaton compacts
zero-change entries, keeping the log informative. Max PHAGY_LOG_ROTATE_MAX (5)
compacted per cycle. Note: this automaton's OWN result is logged AFTER rotation,
so this cycle's stats won't be self-deleted.
"""
function phagy_log_rotate!(
    phagy_log      ::Vector,
    phagy_log_lock ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    noop_indices = Int[]
    lock(phagy_log_lock) do
        for (i, entry) in enumerate(phagy_log)
            items_examined += 1
            if entry.items_changed == 0
                push!(noop_indices, i)
            end
        end
    end

    isempty(noop_indices) && begin
        elapsed_ms = (time() - t0) * 1000
        return PhagyStats("PHAGY_LOG_ROTATE", items_examined, 0, elapsed_ms,
                          "All phagy entries have changes. No no-ops to compact.")
    end

    prune_count = min(length(noop_indices), PHAGY_LOG_ROTATE_MAX)
    lock(phagy_log_lock) do
        for idx in reverse(noop_indices[1:prune_count])
            isempty(phagy_log) && break
            idx > length(phagy_log) && continue
            deleteat!(phagy_log, idx)
            items_changed += 1
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Found $(length(noop_indices)) no-op entry/entries. Compacted $items_changed."
    return PhagyStats("PHAGY_LOG_ROTATE", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 20: MITOSIS LOG ROTATE ─────────────────────────────────────────
# Tier 2: MITOSIS_LOG is capped at MAX_MITOSIS_LOG (50), but no-growth cycles
# (empty new_node_id) waste slots. Compact them.

const MITOSIS_LOG_ROTATE_MAX = 5  # max no-growth entries to compact per cycle

"""
    mitosis_log_rotate!(mitosis_log, mitosis_log_lock)::PhagyStats

GRUG: The MITOSIS_LOG ring is capped at MAX_MITOSIS_LOG (50), but no-growth
cycles (where new_node_id == "") are uninformative — they just say "didn't grow."
This automaton compacts no-growth entries, keeping the log focused on actual
mitosis events. Max MITOSIS_LOG_ROTATE_MAX (5) compacted per cycle.
"""
function mitosis_log_rotate!(
    mitosis_log      ::Vector,
    mitosis_log_lock ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    nogrowth_indices = Int[]
    lock(mitosis_log_lock) do
        for (i, entry) in enumerate(mitosis_log)
            items_examined += 1
            if isempty(entry.new_node_id)
                push!(nogrowth_indices, i)
            end
        end
    end

    isempty(nogrowth_indices) && begin
        elapsed_ms = (time() - t0) * 1000
        return PhagyStats("MITOSIS_LOG_ROTATE", items_examined, 0, elapsed_ms,
                          "All mitosis entries show growth. No no-growth to compact.")
    end

    prune_count = min(length(nogrowth_indices), MITOSIS_LOG_ROTATE_MAX)
    lock(mitosis_log_lock) do
        for idx in reverse(nogrowth_indices[1:prune_count])
            isempty(mitosis_log) && break
            idx > length(mitosis_log) && continue
            deleteat!(mitosis_log, idx)
            items_changed += 1
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Found $(length(nogrowth_indices)) no-growth entry/entries. Compacted $items_changed."
    return PhagyStats("MITOSIS_LOG_ROTATE", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 21: LOBE CONNECTION AUDIT ───────────────────────────────────────
# Tier 2: LobeRecord.connected_lobe_ids can reference lobes that no longer exist.
# READ-ONLY — reports ghost connections and one-way links but does NOT mutate.

const LOBE_AUDIT_MAX = 30  # max connections to audit per cycle

"""
    lobe_connection_audit!(lobe_registry, lobe_lock)::PhagyStats

GRUG: LobeRecord.connected_lobe_ids is a Set{String} that can reference lobes
removed from LOBE_REGISTRY (ghost connections), or be one-way (A→B exists but
B→A doesn't). This automaton is READ-ONLY — it reports issues but does NOT
mutate. Fixing ghost connections is a manual operation (too risky to auto-delete).
Max LOBE_AUDIT_MAX (30) connections audited per cycle.
"""
function lobe_connection_audit!(
    lobe_registry ::Dict,
    lobe_lock     ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    issues         = String[]

    lock(lobe_lock) do
        for (lobe_id, rec) in lobe_registry
            for connected_id in rec.connected_lobe_ids
                items_examined += 1
                items_examined > LOBE_AUDIT_MAX && break

                # GRUG: Ghost connection — references a lobe that doesn't exist
                if !haskey(lobe_registry, connected_id)
                    push!(issues, "Ghost: $lobe_id → $connected_id (target missing)")
                    continue
                end

                # GRUG: One-way connection — A→B but not B→A
                other = lobe_registry[connected_id]
                if !(lobe_id in other.connected_lobe_ids)
                    push!(issues, "One-way: $lobe_id → $connected_id (not reciprocal)")
                end
            end
            items_examined > LOBE_AUDIT_MAX && break
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = if isempty(issues)
        "Audited $items_examined connection(s). All healthy."
    else
        "Audited $items_examined connection(s). Found $(length(issues)) issue(s): $(join(issues, "; "))"
    end
    # GRUG: Read-only audit — items_changed is always 0
    return PhagyStats("LOBE_CONNECTION_AUDIT", items_examined, 0, elapsed_ms, notes)
end


# ── AUTOMATON 22: MLP RULE GRAVE SWEEP ────────────────────────────────────────
# Tier 2: RuleHashTable.rules can accumulate disabled rules and zero-weight rules
# that never fire. Remove them from the hash table and key index.

const MLP_RULE_GRAVE_SWEEP_MAX = 10  # max dead rules to remove per cycle

"""
    mlp_rule_grave_sweep!(mlp_state)::PhagyStats

GRUG: MLPTransformerRule entries can be disabled (!enabled) or have zero weight
(weight.value == 0.0). These rules never contribute to transforms and just waste
lookup time. This automaton removes disabled/zero-weight rules from the
RuleHashTable, cleaning both the rules dict and the key_index. Max
MLP_RULE_GRAVE_SWEEP_MAX (10) removed per cycle.
"""
function mlp_rule_grave_sweep!(
    mlp_state ::Any  # EphemeralMLPState — typed as Any for dependency-gating flexibility
)::PhagyStats
    t0 = time()
    items_examined = 0
    items_changed  = 0
    notes          = ""

    dead_rule_ids = String[]

    lock(mlp_state.lock) do
        rule_table = mlp_state.rules
        lock(rule_table.lock) do
            for (rid, rule) in rule_table.rules
                items_examined += 1
                if !rule.enabled || rule.weight.value == 0.0
                    push!(dead_rule_ids, rid)
                end
            end
        end

        # GRUG: Apply deletions — two-pass
        applied = 0
        for rid in dead_rule_ids
            applied >= MLP_RULE_GRAVE_SWEEP_MAX && break
            rule_table = mlp_state.rules
            lock(rule_table.lock) do
                if haskey(rule_table.rules, rid)
                    rule = rule_table.rules[rid]
                    # Clean key_index
                    if !isempty(rule.key) && haskey(rule_table.key_index, rule.key)
                        filter!(id -> id != rid, rule_table.key_index[rule.key])
                        if isempty(rule_table.key_index[rule.key])
                            delete!(rule_table.key_index, rule.key)
                        end
                    end
                    delete!(rule_table.rules, rid)
                    items_changed += 1
                    applied += 1
                end
            end
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = "Found $(length(dead_rule_ids)) dead rule(s). Removed $items_changed."
    return PhagyStats("MLP_RULE_GRAVE_SWEEP", items_examined, items_changed, elapsed_ms, notes)
end


# ── AUTOMATON 23: RELATIONAL TRIPLE AUDIT ──────────────────────────────────────
# Tier 3: Nodes have required_relations (Vector{String}) and neighbor_ids
# (Vector{String}) that can reference deleted/grave nodes. READ-ONLY audit.

const RELATIONAL_AUDIT_MAX_NODES = 50  # max nodes to audit per cycle

"""
    relational_triple_audit!(node_map, node_lock)::PhagyStats

GRUG: Nodes accumulate required_relations and neighbor_ids over their lifetime.
These references can become stale — pointing at nodes that are grave or missing
from NODE_MAP entirely. This automaton is READ-ONLY — it scans and reports
dangling references but does NOT mutate. Fixing stale relations is a manual
operation (too risky to auto-delete neighbor links that might be intentional).
Max RELATIONAL_AUDIT_MAX_NODES (50) nodes audited per cycle.
"""
function relational_triple_audit!(
    node_map  ::Dict,
    node_lock ::ReentrantLock
)::PhagyStats
    t0 = time()
    items_examined = 0
    issues         = String[]

    lock(node_lock) do
        for (nid, node) in node_map
            items_examined >= RELATIONAL_AUDIT_MAX_NODES && break
            node.is_grave && continue  # skip grave nodes — not worth auditing
            items_examined += 1

            # GRUG: Check required_relations
            for ref_id in node.required_relations
                if !haskey(node_map, ref_id)
                    push!(issues, "$nid required_relations → $ref_id (MISSING)")
                elseif node_map[ref_id].is_grave
                    push!(issues, "$nid required_relations → $ref_id (GRAVE)")
                end
            end

            # GRUG: Check neighbor_ids
            for ref_id in node.neighbor_ids
                if !haskey(node_map, ref_id)
                    push!(issues, "$nid neighbor_ids → $ref_id (MISSING)")
                elseif node_map[ref_id].is_grave
                    push!(issues, "$nid neighbor_ids → $ref_id (GRAVE)")
                end
            end
        end
    end

    elapsed_ms = (time() - t0) * 1000
    notes = if isempty(issues)
        "Audited $items_examined node(s). All relations healthy."
    else
        # GRUG: Truncate if too many issues to avoid log spam
        display_issues = length(issues) > 10 ? vcat(issues[1:10], ["... and $(length(issues)-10) more"]) : issues
        "Audited $items_examined node(s). Found $(length(issues)) issue(s): $(join(display_issues, "; "))"
    end
    # GRUG: Read-only audit — items_changed is always 0
    return PhagyStats("RELATIONAL_TRIPLE_AUDIT", items_examined, 0, elapsed_ms, notes)
end
# PHAGY DISPATCHER - ONE AUTOMATON PER CYCLE
# ==============================================================================

"""
run_phagy!(node_map, node_lock, hopfield_cache⚠️DEAD, cache_lock⚠️DEAD, rules, rules_lock;
           message_history=nothing, history_lock=nothing,
           injector_dict=nothing, injector_lock=nothing,
           phase_acc=nothing,
           observer_store=nothing,
           sigil_table=nothing,
           trajectory_config_ref=nothing, trajectory_buffer=nothing, trajectory_lock=nothing,
           lobe_registry=nothing, lobe_lock=nothing,
           chatter_node_cooldown=nothing, chatter_node_cooldown_lock=nothing,
           morph_cooldown_map=nothing, morph_cooldown_lock=nothing,
           attachment_map=nothing, attachment_lock=nothing,
           group_map=nothing, group_lock=nothing, node_to_group=nothing,
           immune_ledger=nothing, ledger_lock=nothing,
           chatter_log=nothing, chatter_log_lock=nothing,
           mitosis_log=nothing, mitosis_log_lock=nothing,
           mlp_state=nothing
           )::PhagyStats

GRUG: Main phagy entry point. Randomly selects ONE automaton to run this cycle.
Selection is weighted equally across available automata - no priority bias.

Available automata (1-23, #7 reserved):
  1. ORPHAN_PRUNER              - Grave nodes with zero neighbors and zero strength
  2. STRENGTH_DECAYER           - Small decay on weak nodes not recently activated
  3. GRAVE_RECYCLER             - Donate graved-node drop_tables to alive neighbors
  4. DROP_TABLE_COMPACT         - Trim low-probability drop_table entries
  5. RULE_PRUNER                - Flag rules that never fire as dormant
  6. MEMORY_FORENSICS           - Coinflip fuzzy/metric memory health analysis
  7. (reserved - CACHE_VALIDATOR disabled, Hopfield obsolete)
  8. INJECTOR_GRAVEYARD_SWEEP   - Reap zombie vigilance injector agents (v7.30)
  9. PHASE_ACCUMULATOR_AGING    - Trim oldest crystal snapshots (v7.30)
  10. OBSERVER_STORE_PRUNING    - Evict low-salience subconscious entries (v7.30)
  11. SIGIL_CONSISTENCY_CHECK   - Flag malformed sigil table entries (v7.30)
  12. TRAJECTORY_STALE_TRIM     - Trim stale trajectory buffer entries (v7.30)
  --- v7.31: Full organ coverage (13-23) ---
  13. LOBE_POPULATION_GUARD     - Soft cap enforcement for over-cap lobes (v7.31)
  14. CHATTER_COOLDOWN_PURGE    - Expire stale chatter/morph cooldown entries (v7.31)
  15. ATTACHMENT_GRAVE_SWEEP    - Remove attachments for grave nodes (v7.31)
  16. GROUP_GRAVE_SWEEP         - Dissolve all-dead groups, prune grave members (v7.31)
  17. IMMUNE_STATE_TRIM         - Expire old immune ledger entries past 24h (v7.31)
  18. CHATTER_LOG_ROTATE        - Prune zero-swap chatter sessions from ring (v7.31)
  19. PHAGY_LOG_ROTATE          - Compact no-op phagy log entries (v7.31)
  20. MITOSIS_LOG_ROTATE        - Compact no-growth mitosis log entries (v7.31)
  21. LOBE_CONNECTION_AUDIT     - Read-only ghost/one-way lobe connection audit (v7.31)
  22. MLP_RULE_GRAVE_SWEEP      - Remove disabled/zero-weight MLP rules (v7.31)
  23. RELATIONAL_TRIPLE_AUDIT   - Read-only dangling relation/neighbor audit (v7.31)

DEPENDENCY GATING:
  - Automaton 6 (MEMORY_FORENSICS) requires message_history + history_lock.
  - Automaton 8 (INJECTOR_GRAVEYARD_SWEEP) requires injector_dict + injector_lock.
  - Automaton 9 (PHASE_ACCUMULATOR_AGING) requires phase_acc.
  - Automaton 10 (OBSERVER_STORE_PRUNING) requires observer_store.
  - Automaton 11 (SIGIL_CONSISTENCY_CHECK) requires sigil_table.
  - Automaton 12 (TRAJECTORY_STALE_TRIM) requires trajectory_config_ref + trajectory_buffer + trajectory_lock.
  - Automaton 13 (LOBE_POPULATION_GUARD) requires lobe_registry + lobe_lock.
  - Automaton 14 (CHATTER_COOLDOWN_PURGE) requires chatter_node_cooldown + chatter_node_cooldown_lock + morph_cooldown_map + morph_cooldown_lock.
  - Automaton 15 (ATTACHMENT_GRAVE_SWEEP) requires attachment_map + attachment_lock.
  - Automaton 16 (GROUP_GRAVE_SWEEP) requires group_map + group_lock + node_to_group.
  - Automaton 17 (IMMUNE_STATE_TRIM) requires immune_ledger + ledger_lock.
  - Automaton 18 (CHATTER_LOG_ROTATE) requires chatter_log + chatter_log_lock.
  - Automaton 19 (PHAGY_LOG_ROTATE) uses internal PHAGY_LOG + PHAGY_LOG_LOCK (always available).
  - Automaton 20 (MITOSIS_LOG_ROTATE) requires mitosis_log + mitosis_log_lock.
  - Automaton 21 (LOBE_CONNECTION_AUDIT) requires lobe_registry + lobe_lock.
  - Automaton 22 (MLP_RULE_GRAVE_SWEEP) requires mlp_state.
  - Automaton 23 (RELATIONAL_TRIPLE_AUDIT) uses node_map + node_lock (always available).
  If a rolled automaton's dependencies are missing, it is excluded from the roll.
  Available set is pre-filtered before the random selection.

HOPFIELD CACHE NOTE: CACHE_VALIDATOR (formerly automaton 4) is DISABLED. Hopfield caching
was used prior to lobe-based architecture. Modern system uses 1000-node active cap biological
bottleneck. Hopfield cache only relevant for RIDICULOUSLY LARGE lobe sizes (50,000+ nodes).
⚠️  HOPFIELD_CACHE / CACHE_LOCK positional params are DEAD AND IRRELEVANT. They remain in
    the signature only because removing them would break all call sites. Automaton 7
    (CACHE_VALIDATOR) is permanently disabled. DO NOT waste time on Hopfield anything.

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
    history_lock    ::Union{ReentrantLock, Nothing} = nothing,
    # GRUG v7.30: New kwargs for idle-time maintenance of v7.27-7.29 systems.
    injector_dict   ::Union{Dict, Nothing} = nothing,
    injector_lock   ::Union{ReentrantLock, Nothing} = nothing,
    phase_acc       ::Any = nothing,
    observer_store  ::Any = nothing,
    sigil_table     ::Any = nothing,
    trajectory_config_ref ::Any = nothing,
    trajectory_buffer     ::Any = nothing,
    trajectory_lock       ::Union{ReentrantLock, Nothing} = nothing,
    # GRUG v7.31: Full organ coverage — kwargs for automata 13-23.
    lobe_registry               ::Union{Dict, Nothing} = nothing,
    lobe_lock                   ::Union{ReentrantLock, Nothing} = nothing,
    chatter_node_cooldown       ::Union{Dict, Nothing} = nothing,
    chatter_node_cooldown_lock  ::Union{ReentrantLock, Nothing} = nothing,
    morph_cooldown_map          ::Union{Dict, Nothing} = nothing,
    morph_cooldown_lock         ::Union{ReentrantLock, Nothing} = nothing,
    attachment_map              ::Union{Dict, Nothing} = nothing,
    attachment_lock             ::Union{ReentrantLock, Nothing} = nothing,
    group_map                   ::Union{Dict, Nothing} = nothing,
    group_lock                  ::Union{ReentrantLock, Nothing} = nothing,
    node_to_group               ::Union{Dict, Nothing} = nothing,
    immune_ledger               ::Union{Vector, Nothing} = nothing,
    ledger_lock                 ::Union{ReentrantLock, Nothing} = nothing,
    chatter_log                 ::Union{Vector, Nothing} = nothing,
    chatter_log_lock            ::Union{ReentrantLock, Nothing} = nothing,
    mitosis_log                 ::Union{Vector, Nothing} = nothing,
    mitosis_log_lock            ::Union{ReentrantLock, Nothing} = nothing,
    mlp_state                   ::Any = nothing
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

    # GRUG v7.30: Build the available automaton set based on which dependencies are provided.
    # Automata whose dependencies are missing are excluded from the roll. This is clean -
    # no re-roll surprises, just a deterministic available set before the dice throw.
    available = collect(1:23)

    # GRUG: Automaton 7 is permanently reserved (CACHE_VALIDATOR disabled).
    filter!(a -> a != 7, available)

    # GRUG: Gate automaton 6 on message_history/history_lock
    if isnothing(message_history) || isnothing(history_lock)
        filter!(a -> a != 6, available)
    end

    # GRUG v7.30: Gate automaton 8 on injector_dict/injector_lock
    if isnothing(injector_dict) || isnothing(injector_lock)
        filter!(a -> a != 8, available)
    end

    # GRUG v7.30: Gate automaton 9 on phase_acc
    if isnothing(phase_acc)
        filter!(a -> a != 9, available)
    end

    # GRUG v7.30: Gate automaton 10 on observer_store
    if isnothing(observer_store)
        filter!(a -> a != 10, available)
    end

    # GRUG v7.30: Gate automaton 11 on sigil_table
    if isnothing(sigil_table)
        filter!(a -> a != 11, available)
    end

    # GRUG v7.30: Gate automaton 12 on trajectory_config_ref/trajectory_buffer/trajectory_lock
    if isnothing(trajectory_config_ref) || isnothing(trajectory_buffer) || isnothing(trajectory_lock)
        filter!(a -> a != 12, available)
    end

    # GRUG v7.31: Gate automaton 13 on lobe_registry/lobe_lock
    if isnothing(lobe_registry) || isnothing(lobe_lock)
        filter!(a -> a != 13, available)
    end

    # GRUG v7.31: Gate automaton 14 on chatter_node_cooldown/chatter_node_cooldown_lock/morph_cooldown_map/morph_cooldown_lock
    if isnothing(chatter_node_cooldown) || isnothing(chatter_node_cooldown_lock) || isnothing(morph_cooldown_map) || isnothing(morph_cooldown_lock)
        filter!(a -> a != 14, available)
    end

    # GRUG v7.31: Gate automaton 15 on attachment_map/attachment_lock
    if isnothing(attachment_map) || isnothing(attachment_lock)
        filter!(a -> a != 15, available)
    end

    # GRUG v7.31: Gate automaton 16 on group_map/group_lock/node_to_group
    if isnothing(group_map) || isnothing(group_lock) || isnothing(node_to_group)
        filter!(a -> a != 16, available)
    end

    # GRUG v7.31: Gate automaton 17 on immune_ledger/ledger_lock
    if isnothing(immune_ledger) || isnothing(ledger_lock)
        filter!(a -> a != 17, available)
    end

    # GRUG v7.31: Gate automaton 18 on chatter_log/chatter_log_lock
    if isnothing(chatter_log) || isnothing(chatter_log_lock)
        filter!(a -> a != 18, available)
    end

    # GRUG v7.31: Automaton 19 (PHAGY_LOG_ROTATE) uses internal PHAGY_LOG/PHAGY_LOG_LOCK — always available.

    # GRUG v7.31: Gate automaton 20 on mitosis_log/mitosis_log_lock
    if isnothing(mitosis_log) || isnothing(mitosis_log_lock)
        filter!(a -> a != 20, available)
    end

    # GRUG v7.31: Gate automaton 21 on lobe_registry/lobe_lock (same as 13)
    if isnothing(lobe_registry) || isnothing(lobe_lock)
        filter!(a -> a != 21, available)
    end

    # GRUG v7.31: Gate automaton 22 on mlp_state
    if isnothing(mlp_state)
        filter!(a -> a != 22, available)
    end

    # GRUG v7.31: Automaton 23 (RELATIONAL_TRIPLE_AUDIT) uses node_map/node_lock — always available.

    if isempty(available)
        throw(PhagyError("!!! FATAL: run_phagy! has zero available automata - all dependencies missing! !!!"))
    end

    # GRUG: Roll the automaton selector from available set (uniform)
    automaton_roll = rand(available)

    n_available = length(available)
    println("[PHAGY] 🧹  Phagy cycle starting. Automaton roll: $automaton_roll ($n_available available)")

    stats = try
        if automaton_roll == 1
            prune_orphan_nodes!(node_map, node_lock)
        elseif automaton_roll == 2
            decay_forgotten_strengths!(node_map, node_lock)
        elseif automaton_roll == 3
            recycle_grave_assets!(node_map, node_lock)
        elseif automaton_roll == 4
            # GRUG: Automaton 4 is DROP_TABLE_COMPACT (CACHE_VALIDATOR disabled)
            compact_drop_tables!(node_map, node_lock)
        elseif automaton_roll == 5
            prune_dormant_rules!(rules, rules_lock)
        elseif automaton_roll == 6
            run_memory_forensics!(node_map, node_lock, message_history, history_lock)
        # elseif automaton_roll == 7 - reserved (CACHE_VALIDATOR disabled)
        elseif automaton_roll == 8
            sweep_injector_graveyard!(injector_dict, injector_lock)
        elseif automaton_roll == 9
            age_phase_accumulator!(phase_acc)
        elseif automaton_roll == 10
            prune_observer_store!(observer_store)
        elseif automaton_roll == 11
            check_sigil_consistency!(sigil_table)
        elseif automaton_roll == 12
            trim_stale_trajectory!(trajectory_config_ref, trajectory_buffer, trajectory_lock)
        # ── GRUG v7.31: Full organ coverage automata (13-23) ──
        elseif automaton_roll == 13
            lobe_population_guard!(node_map, node_lock, lobe_registry, lobe_lock)
        elseif automaton_roll == 14
            chatter_cooldown_purge!(chatter_node_cooldown, chatter_node_cooldown_lock,
                                    morph_cooldown_map, morph_cooldown_lock)
        elseif automaton_roll == 15
            attachment_grave_sweep!(node_map, node_lock, attachment_map, attachment_lock)
        elseif automaton_roll == 16
            group_grave_sweep!(node_map, node_lock, group_map, group_lock, node_to_group)
        elseif automaton_roll == 17
            immune_state_trim!(immune_ledger, ledger_lock)
        elseif automaton_roll == 18
            chatter_log_rotate!(chatter_log, chatter_log_lock)
        elseif automaton_roll == 19
            phagy_log_rotate!(PHAGY_LOG, PHAGY_LOG_LOCK)
        elseif automaton_roll == 20
            mitosis_log_rotate!(mitosis_log, mitosis_log_lock)
        elseif automaton_roll == 21
            lobe_connection_audit!(lobe_registry, lobe_lock)
        elseif automaton_roll == 22
            mlp_rule_grave_sweep!(mlp_state)
        elseif automaton_roll == 23
            relational_triple_audit!(node_map, node_lock)
        else
            # GRUG: Should be unreachable. If rand returns something outside available, cave is haunted.
            throw(PhagyError("!!! FATAL: automaton_roll=$automaton_roll is not in available set! !!!"))
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
# Phagy never runs all twenty-two active automata in one idle event. A single random automaton
# is selected from the dependency-gated available set per cycle. This bounds the
# worst-case idle work to O(N) where N is the number of nodes/rules/cache entries/
# messages/injectors/snapshots/micrologs/sigils/trajectory-entries. No compounding
# sweep costs.
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
# 7. MEMORY FORENSICS (AUTOMATON 6):
# Coinflip selects between FUZZY (approximate heuristic, sampled) and METRIC
# (exact measurement, full enumeration) analysis modes. Both are READ-ONLY —
# forensics never mutates MESSAGE_HISTORY or NODE_MAP. Forensics requires
# message_history and history_lock kwargs; if not provided, automaton 6 is
# excluded from the available set (graceful, deterministic — no re-roll needed).
# Dual-lock order for metric dead-ref audit: history_lock THEN node_lock.
#
# 8. DEPENDENCY-GATED DISPATCH (v7.30):
# The dispatcher builds an available set from automata 1-12, excludes 7 (reserved),
# then filters out automata whose required kwargs are nothing. The roll is from
# this available set only — no surprises, no re-rolls. If all dependencies are
# provided, all 22 active automata are eligible. If a subsystem is offline, its
# automaton simply isn't in the pool this cycle.
#
# 9. V7.30 AUTOMATA (8-12) — SLOW AND CAUTIOUS:
# INJECTOR_GRAVEYARD_SWEEP (8): Marks zombie injectors (timed out but not cleaned
#   up) as :dead and releases their resources. Margin of INJECTOR_ZOMBIE_MARGIN_SECONDS
#   (10s) beyond timeout before sweeping. Max sweep: 3 per cycle.
# PHASE_ACCUMULATOR_AGING (9): Trims old phase snapshots when total exceeds
#   MAX_PHASE_SNAPSHOTS (200). Removes the oldest PHASE_AGING_TRIM_COUNT (5) per cycle.
# OBSERVER_STORE_PRUNE (10): When SubconsciousStore exceeds MAX_TOTAL_ENTRIES (4096),
#   evicts OBSERVER_PRUNE_EVICT_COUNT (8) oldest micrologs, then prunes empty keys
#   to maintain OBSERVER_PRUNE_FILL_RATIO (0.85). Never drops below 1 entry per key.
# SIGIL_CONSISTENCY_CHECK (11): Scans SigilTable for entries with missing/empty
#   required fields. Reports inconsistencies but does NOT mutate — read-only audit.
# STALE_TRAJECTORY_TRIM (12): Removes trajectory entries older than
#   TRAJECTORY_STALE_HAL * decay_halflife per config. Removes at most
#   TRAJECTORY_STALE_TRIM_COUNT (2) per cycle. Read-only if nothing is stale.
#
# 10. V7.31 FULL ORGAN COVERAGE AUTOMATA (13-23) — EVERY ORGAN MAINTAINED:
# LOBE_POPULATION_GUARD (13): Dampens weakest alive nodes in over-cap lobes.
#   Max LOBE_POP_GUARD_MAX_DAMPENS (3) per cycle. Never touches strength > 0.3.
# CHATTER_COOLDOWN_PURGE (14): Purges expired cooldown entries from both
#   CHATTER_NODE_COOLDOWN (1hr) and MORPH_COOLDOWN_MAP (24hr). Max 50 per cycle.
# ATTACHMENT_GRAVE_SWEEP (15): Removes attachment vectors for grave target nodes,
#   and filters grave AttachedNode entries from alive targets. Max 20 per cycle.
# GROUP_GRAVE_SWEEP (16): Dissolves fully-dead groups, prunes grave members from
#   partial groups, cleans NODE_TO_GROUP. Max 5 dissolutions + 20 prunes per cycle.
# IMMUNE_STATE_TRIM (17): Trims immune ledger entries older than 24h.
#   Max 100 entries per cycle. Complements cap-based trim at 10K.
# CHATTER_LOG_ROTATE (18): Prunes zero-swap (stale) ChatterSession entries from
#   ring. Max 10 per cycle. Ring cap (200) handles overflow; this handles quality.
# PHAGY_LOG_ROTATE (19): Compacts no-op (0 items_changed) PHAGY_LOG entries.
#   Max 5 per cycle. Uses internal PHAGY_LOG/PHAGY_LOG_LOCK (always available).
# MITOSIS_LOG_ROTATE (20): Compacts no-growth (empty new_node_id) MITOSIS_LOG entries.
#   Max 5 per cycle.
# LOBE_CONNECTION_AUDIT (21): READ-ONLY audit of ghost and one-way lobe connections.
#   Reports issues but does NOT mutate. Max 30 connections audited per cycle.
# MLP_RULE_GRAVE_SWEEP (22): Removes disabled/zero-weight MLPTransformerRule entries
#   from RuleHashTable, cleans key_index. Max 10 per cycle.
# RELATIONAL_TRIPLE_AUDIT (23): READ-ONLY audit of dangling required_relations and
#   neighbor_ids pointing to grave/missing nodes. Max 50 nodes per cycle.
# ==============================================================================