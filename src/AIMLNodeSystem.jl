# ==============================================================================
# AIMLNodeSystem.jl — GRUG Lobe-Specific Executive Node Tribes
# ==============================================================================
# GRUG say: old AIML one giant blob. Bad. Now each lobe gets own AIML tribe.
# GRUG say: AIML node has own strength. Can get stronger. Can get weaker. Can die.
# GRUG say: AIML globally activates. So cap at 1/3 parent lobe size. No bloat demon.
# GRUG say: /aimlRight and /aimlWrong update voted nodes this cycle ONLY.
# GRUG say: cycle memory mandatory. Without it, punishment not honest.
# GRUG say: dead AIML node becomes AIML_GRAVE. Remember executive failures.
# GRUG say: NO SILENT FAILURES. If invariant broken, scream loud.
# ==============================================================================

module AIMLNodeSystem

using Base.Threads: ReentrantLock
using Random

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

# GRUG: One error type for whole module. Carries message + context breadcrumb.
struct AIMLNodeError <: Exception
    message::String
    context::String
end

# GRUG: Helper that throws a properly-tagged error. Always use this, never bare error().
function throw_aiml_error(msg::String, ctx::String = "unknown")
    throw(AIMLNodeError(msg, ctx))
end

# ==============================================================================
# CONSTANTS — GRUG keep magic numbers in one place
# ==============================================================================

# GRUG: Strength bounds. Mirrors engine.jl STRENGTH_CAP so executive layer is not
# special-cased from main-node plasticity. Floor is 0.0 = AIML_GRAVE trigger.
const AIML_STRENGTH_CAP   = 10.0
const AIML_STRENGTH_FLOOR = 0.0

# GRUG: Population cap ratio. AIML per lobe <= floor(parent_lobe_cap / 3).
# Executive layer globally activates so it MUST be kept bounded. 1/3 is the rule.
const AIML_POPULATION_CAP_RATIO = 3

# GRUG: Strength delta per reward/penalty tick. Kept as named const so later
# tuning (or phagy pruning weights) has one place to touch.
const AIML_STRENGTH_DELTA = 1.0

# GRUG: Grave reason strings. Short codes for downstream consumers.
const AIML_GRAVE_REASON_STRENGTH_ZERO = "AIML_STRENGTH_ZERO"

# ==============================================================================
# AIML NODE RECORD
# ==============================================================================

# GRUG: One AIML node. Belongs to exactly one lobe. Has own strength, own grave,
# own cycle bookkeeping. Template text is the AIML "payload" the node owns.
#
# Cycle fields (voted_this_cycle, fired_this_cycle, gained_this_cycle,
# strength_delta_this_cycle) are MANDATORY. Without honest cycle memory
# /aimlWrong cannot deliver a real net loss after a prior same-cycle gain.
# These fields are reset by reset_cycle!() at the start of every cycle.
mutable struct AIMLNode
    id::String
    lobe_id::String
    template::String                 # GRUG: AIML rule text / executive payload
    strength::Float64                # GRUG: [0.0, AIML_STRENGTH_CAP]
    is_grave::Bool                   # GRUG: True when strength hit 0.0 once
    grave_reason::String             # GRUG: Code from AIML_GRAVE_REASON_* consts

    # GRUG: Per-cycle bookkeeping. Without this punishment is dishonest.
    voted_this_cycle::Bool           # GRUG: Did this node vote in current cycle?
    fired_this_cycle::Bool           # GRUG: Did this node fire/get used in cycle?
    gained_this_cycle::Bool          # GRUG: Did strength go UP from use this cycle?
    strength_delta_this_cycle::Float64  # GRUG: Net strength change this cycle

    created_at::Float64
end

# GRUG: Constructor. Clamps strength to legal range and zeroes cycle fields.
# Validates non-empty id/lobe_id/template loudly — no quiet coercion.
function AIMLNode(id::String, lobe_id::String, template::String;
                  initial_strength::Float64 = 5.0)
    if isempty(strip(id))
        throw_aiml_error("AIMLNode id cannot be empty", "AIMLNode constructor")
    end
    if isempty(strip(lobe_id))
        throw_aiml_error("AIMLNode lobe_id cannot be empty", "AIMLNode constructor")
    end
    if isempty(strip(template))
        throw_aiml_error("AIMLNode template cannot be empty", "AIMLNode constructor")
    end
    if initial_strength < AIML_STRENGTH_FLOOR || initial_strength > AIML_STRENGTH_CAP
        throw_aiml_error(
            "initial_strength=$initial_strength out of [$(AIML_STRENGTH_FLOOR), $(AIML_STRENGTH_CAP)]",
            "AIMLNode constructor"
        )
    end
    return AIMLNode(
        id, lobe_id, template,
        initial_strength,
        false, "",
        false, false, false, 0.0,
        time()
    )
end

# ==============================================================================
# GLOBAL REGISTRY — per-lobe AIML node populations
# ==============================================================================

# GRUG: lobe_id -> Dict{aiml_node_id -> AIMLNode}. Per-lobe isolation is a
# hard rule: one lobe's tribe never touches another. The outer dict is the
# mechanism for that isolation — it also gives O(1) lookup by lobe.
const AIML_REGISTRY = Dict{String, Dict{String, AIMLNode}}()

# GRUG: lobe_id -> population cap (computed from parent lobe cap at registration).
# Stored so we never need to re-import Lobe.jl just to enforce the 1/3 rule.
const AIML_POPULATION_CAP = Dict{String, Int}()

# GRUG: One lock to rule them all. Protects AIML_REGISTRY,
# AIML_POPULATION_CAP, and the CURRENT_CYCLE counter below. Single lock keeps
# cycle updates and population writes sequentially consistent — simpler than
# fine-grained locking and no faster to break.
const AIML_LOCK = ReentrantLock()

# GRUG: Monotonic cycle counter. Bumped by begin_cycle!(). Each node tracks the
# last cycle it saw via its flags, and reset_cycle! zeroes those flags.
# Counter is diagnostic only — correctness comes from the reset, not the number.
const CURRENT_CYCLE = Ref{Int}(0)

# ==============================================================================
# LOBE POPULATION REGISTRATION
# ==============================================================================

"""
register_lobe!(lobe_id::String, parent_lobe_cap::Int)::Int

GRUG: Register a lobe so AIML nodes can live there. Computes the cap as
floor(parent_lobe_cap / 3). Returns the computed cap so caller can verify.
Re-registering an existing lobe updates the cap — it does NOT wipe nodes.

Hard rule: every AIML lobe must be registered before nodes can be added.
No silent fallback to "some default cap" — missing registration is a fatal error.
"""
function register_lobe!(lobe_id::String, parent_lobe_cap::Int)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "register_lobe!")
    end
    if parent_lobe_cap <= 0
        throw_aiml_error("parent_lobe_cap must be positive, got $parent_lobe_cap", "register_lobe!")
    end
    # GRUG: Integer floor division. Cap = 1/3 parent lobe population.
    aiml_cap = div(parent_lobe_cap, AIML_POPULATION_CAP_RATIO)
    if aiml_cap <= 0
        throw_aiml_error(
            "Computed AIML cap is non-positive for lobe '$lobe_id' (parent cap=$parent_lobe_cap). Lobe too small for AIML tribe.",
            "register_lobe!"
        )
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            AIML_REGISTRY[lobe_id] = Dict{String, AIMLNode}()
        end
        AIML_POPULATION_CAP[lobe_id] = aiml_cap
    end
    return aiml_cap
end

"""
unregister_lobe!(lobe_id::String)

GRUG: Remove a lobe's AIML tribe entirely. Wipes population + cap.
Used when the parent lobe itself is being torn down. Not for casual use.
"""
function unregister_lobe!(lobe_id::String)
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "unregister_lobe!")
    end
    lock(AIML_LOCK) do
        delete!(AIML_REGISTRY, lobe_id)
        delete!(AIML_POPULATION_CAP, lobe_id)
    end
end

"""
is_lobe_registered(lobe_id::String)::Bool

GRUG: True if lobe has been registered for AIML. Safe read — no throw.
"""
function is_lobe_registered(lobe_id::String)::Bool
    lock(AIML_LOCK) do
        return haskey(AIML_REGISTRY, lobe_id)
    end
end

"""
get_population_cap(lobe_id::String)::Int

GRUG: Return configured 1/3 cap for this lobe. Throws if lobe not registered.
"""
function get_population_cap(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_population_cap")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_POPULATION_CAP, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_population_cap")
        end
        return AIML_POPULATION_CAP[lobe_id]
    end
end

"""
get_population_size(lobe_id::String)::Int

GRUG: Total number of AIML nodes in this lobe (alive + grave).
For cap enforcement, use get_alive_population_size() instead.
"""
function get_population_size(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_population_size")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_population_size")
        end
        return length(AIML_REGISTRY[lobe_id])
    end
end

"""
get_alive_population_size(lobe_id::String)::Int

GRUG: Number of ALIVE AIML nodes in this lobe (excludes graves).
This is the number used for population cap enforcement.
GRUG say: graves are memory, not bloat. Dead nodes don't eat cap space.
"""
function get_alive_population_size(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_alive_population_size")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_alive_population_size")
        end
        tribe = AIML_REGISTRY[lobe_id]
        return count(n -> !n.is_grave, values(tribe))
    end
end

# ==============================================================================
# NODE LIFECYCLE — add, get, remove
# ==============================================================================

"""
add_aiml_node!(lobe_id::String, node_id::String, template::String; initial_strength=5.0)::AIMLNode

GRUG: Plant a new AIML node in a lobe's tribe. Enforces:
  1. Lobe must be registered.
  2. Population cap must NOT be exceeded (throws loudly — no silent overflow).
  3. Node id must not already exist in this lobe.

Returns the created AIMLNode. On any failure, throws AIMLNodeError.
"""
function add_aiml_node!(lobe_id::String, node_id::String, template::String;
                        initial_strength::Float64 = 5.0)::AIMLNode
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "add_aiml_node!")
    end
    if isempty(strip(node_id))
        throw_aiml_error("node_id cannot be empty", "add_aiml_node!")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML. Call register_lobe! first.", "add_aiml_node!")
        end
        tribe = AIML_REGISTRY[lobe_id]
        cap = AIML_POPULATION_CAP[lobe_id]

        # GRUG: Hard cap check — ALIVE nodes only, graves don't count!
        # GRUG say: dead executive is memory, not bloat. Cap is for living.
        alive_count = count(n -> !n.is_grave, values(tribe))
        if alive_count >= cap
            throw_aiml_error(
                "AIML population cap exceeded for lobe '$lobe_id' (alive=$alive_count, grave=$(length(tribe)-alive_count), cap=$cap). Top brain not allowed to become big bloated demon.",
                "add_aiml_node!"
            )
        end
        if haskey(tribe, node_id)
            throw_aiml_error(
                "AIML node '$node_id' already exists in lobe '$lobe_id'. No duplicates.",
                "add_aiml_node!"
            )
        end

        node = AIMLNode(node_id, lobe_id, template; initial_strength=initial_strength)
        tribe[node_id] = node
        return node
    end
end

"""
get_aiml_node(lobe_id::String, node_id::String)::AIMLNode

GRUG: Fetch a node. Throws if lobe unregistered or node missing.
"""
function get_aiml_node(lobe_id::String, node_id::String)::AIMLNode
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_aiml_node")
        end
        tribe = AIML_REGISTRY[lobe_id]
        if !haskey(tribe, node_id)
            throw_aiml_error("AIML node '$node_id' not found in lobe '$lobe_id'", "get_aiml_node")
        end
        return tribe[node_id]
    end
end

"""
has_aiml_node(lobe_id::String, node_id::String)::Bool

GRUG: Cheap membership probe. No throw on missing lobe — just false.
"""
function has_aiml_node(lobe_id::String, node_id::String)::Bool
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            return false
        end
        return haskey(AIML_REGISTRY[lobe_id], node_id)
    end
end

"""
remove_aiml_node!(lobe_id::String, node_id::String)::Bool

GRUG: Delete a node entirely (e.g. future phagy cleanup). Returns true if removed,
false if it wasn't there. Missing lobe throws — phagy must know its lobes.
"""
function remove_aiml_node!(lobe_id::String, node_id::String)::Bool
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "remove_aiml_node!")
        end
        tribe = AIML_REGISTRY[lobe_id]
        if !haskey(tribe, node_id)
            return false
        end
        delete!(tribe, node_id)
        return true
    end
end

"""
list_aiml_nodes(lobe_id::String)::Vector{AIMLNode}

GRUG: Snapshot vector of AIML nodes in a lobe. Sorted by id for stable iteration.
"""
function list_aiml_nodes(lobe_id::String)::Vector{AIMLNode}
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "list_aiml_nodes")
        end
        nodes = collect(values(AIML_REGISTRY[lobe_id]))
        sort!(nodes; by = n -> n.id)
        return nodes
    end
end

"""
get_registered_lobes()::Vector{String}

GRUG: List every lobe that has an AIML tribe registered. Sorted for stability.
"""
function get_registered_lobes()::Vector{String}
    lock(AIML_LOCK) do
        return sort(collect(keys(AIML_REGISTRY)))
    end
end

# ==============================================================================
# CYCLE MANAGEMENT — mandatory per-cycle bookkeeping
# ==============================================================================

"""
begin_cycle!()

GRUG: Start a new cycle. Bumps CURRENT_CYCLE and resets all per-cycle flags
on every node in every registered lobe. Call this at the TOP of every mission
BEFORE any AIML firing / voting happens. Without this, cycle-aware reward/
punishment is meaningless.
"""
function begin_cycle!()
    lock(AIML_LOCK) do
        CURRENT_CYCLE[] += 1
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                node.voted_this_cycle = false
                node.fired_this_cycle = false
                node.gained_this_cycle = false
                node.strength_delta_this_cycle = 0.0
            end
        end
    end
end

"""
current_cycle()::Int

GRUG: The monotonic cycle counter. Diagnostic only.
"""
function current_cycle()::Int
    lock(AIML_LOCK) do
        return CURRENT_CYCLE[]
    end
end

# ==============================================================================
# STRENGTH DYNAMICS — use-based gain, feedback-based change
# ==============================================================================

# GRUG: Internal strength mutator. Clamps, updates cycle delta, and transitions
# the node to AIML_GRAVE if strength hits the floor. Caller holds AIML_LOCK.
# NOT exported — external callers must go through the feedback API.
function _apply_strength_delta!(node::AIMLNode, delta::Float64)
    if node.is_grave
        # GRUG: Grave nodes are permanent negative reinforcement. No resurrection
        # via passive strength nudges. Phagy or explicit revive would be needed.
        return
    end
    old_strength = node.strength
    new_strength = clamp(node.strength + delta, AIML_STRENGTH_FLOOR, AIML_STRENGTH_CAP)
    applied_delta = new_strength - old_strength
    node.strength = new_strength
    node.strength_delta_this_cycle += applied_delta
    if applied_delta > 0.0
        node.gained_this_cycle = true
    end
    if node.strength <= AIML_STRENGTH_FLOOR
        # GRUG: Strength floor hit. Mark AIML_GRAVE. Dead executive pattern
        # becomes anti-pattern memory — it does NOT just vanish. Phagy may
        # later remove graves, but that is a separate idle-time event.
        node.is_grave = true
        node.grave_reason = AIML_GRAVE_REASON_STRENGTH_ZERO
        println("[AIML] ⚰  Node '$(node.id)' in lobe '$(node.lobe_id)' marked AIML_GRAVE (strength -> 0).")
    end
end

"""
record_fire!(node::AIMLNode)

GRUG: Mark that an AIML node fired this cycle. Coinflip for strength gain
(same spirit as engine.jl bump_strength!). This is the ONLY path that sets
gained_this_cycle = true via use-reward. /aimlRight must check this flag to
avoid double-snacking the same node.

Thread-safe: takes AIML_LOCK for the strength mutation.
"""
function record_fire!(node::AIMLNode)
    lock(AIML_LOCK) do
        node.fired_this_cycle = true
        if node.is_grave
            # GRUG: Grave nodes may still be referenced during generative
            # phase as anti-pattern anchors, but they DO NOT receive rewards.
            return
        end
        if rand() < 0.5
            _apply_strength_delta!(node, AIML_STRENGTH_DELTA)
        end
    end
end

"""
record_vote!(node::AIMLNode)

GRUG: Mark that an AIML node cast a vote this cycle. /aimlRight and /aimlWrong
apply ONLY to voters — not to the whole universe. This is how we keep feedback
targeted.
"""
function record_vote!(node::AIMLNode)
    lock(AIML_LOCK) do
        node.voted_this_cycle = true
    end
end

# ==============================================================================
# FEEDBACK COMMANDS — /aimlRight and /aimlWrong
# ==============================================================================

# GRUG: Shared helper to collect all voted-this-cycle AIML nodes across registered
# lobes. Used by both feedback commands. Caller does NOT hold the lock — this
# function takes it internally and returns a plain vector for iteration outside.
function _collect_voters()::Vector{AIMLNode}
    voters = AIMLNode[]
    lock(AIML_LOCK) do
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                if node.voted_this_cycle
                    push!(voters, node)
                end
            end
        end
    end
    return voters
end

"""
apply_aiml_right!()::Dict{String, Any}

GRUG: /aimlRight feedback. For each AIML node that voted this cycle:
  - If node already GAINED strength this cycle from use -> skip (no double snack).
  - Else coinflip; on success, node gains strength.

Returns a diagnostic dict for logging / test assertions.
"""
function apply_aiml_right!()::Dict{String, Any}
    voters = _collect_voters()
    rewarded = String[]
    skipped_double_reward = String[]
    coinflip_missed = String[]
    grave_skipped = String[]

    lock(AIML_LOCK) do
        for node in voters
            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end
            if node.gained_this_cycle
                # GRUG: Node already snacked this cycle. No double reward.
                push!(skipped_double_reward, node.id)
                continue
            end
            if rand() < 0.5
                _apply_strength_delta!(node, AIML_STRENGTH_DELTA)
                push!(rewarded, node.id)
            else
                push!(coinflip_missed, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_voters"          => length(voters),
        "rewarded"              => rewarded,
        "skipped_double_reward" => skipped_double_reward,
        "coinflip_missed"       => coinflip_missed,
        "grave_skipped"         => grave_skipped,
    )
    println("[AIML] ✅ /aimlRight: voters=$(length(voters)) rewarded=$(length(rewarded)) double_skip=$(length(skipped_double_reward)) coinflip_miss=$(length(coinflip_missed)) grave_skip=$(length(grave_skipped))")
    return result
end

"""
apply_aiml_wrong!()::Dict{String, Any}

GRUG: /aimlWrong feedback. For each AIML node that voted this cycle:
  - 50/50 coinflip decides whether this node is penalized at all.
  - If coinflip says penalize:
      * If node GAINED strength this cycle from use, penalty must be
        large enough to (a) cancel that gain AND (b) leave a net loss.
        Penalty magnitude = strength_delta_this_cycle + AIML_STRENGTH_DELTA.
      * Otherwise standard penalty = AIML_STRENGTH_DELTA.

Returns a diagnostic dict. If strength reaches 0.0, the node is transitioned
to AIML_GRAVE by _apply_strength_delta! — no special casing here.

Hard rule: /aimlWrong must produce a REAL net loss for any node penalized.
If node had already gained in-cycle, we over-compensate. This is the honest
punishment rule from the spec.
"""
function apply_aiml_wrong!()::Dict{String, Any}
    voters = _collect_voters()
    penalized = String[]
    spared = String[]
    graved = String[]
    grave_skipped = String[]

    lock(AIML_LOCK) do
        for node in voters
            if node.is_grave
                # GRUG: Already dead. Cannot penalize the already-dead.
                push!(grave_skipped, node.id)
                continue
            end
            if rand() < 0.5
                # GRUG: Coinflip said penalize. Figure out magnitude.
                # If node already snacked this cycle, over-compensate to
                # guarantee strength ends BELOW cycle-start strength.
                prior_gain = max(node.strength_delta_this_cycle, 0.0)
                penalty_magnitude = AIML_STRENGTH_DELTA + prior_gain
                # GRUG: Apply as negative delta. _apply_strength_delta! clamps
                # and handles grave transition.
                was_grave_before = node.is_grave
                _apply_strength_delta!(node, -penalty_magnitude)
                push!(penalized, node.id)
                if node.is_grave && !was_grave_before
                    push!(graved, node.id)
                end
            else
                push!(spared, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_voters"  => length(voters),
        "penalized"     => penalized,
        "spared"        => spared,
        "newly_graved"  => graved,
        "grave_skipped" => grave_skipped,
    )
    println("[AIML] ❌ /aimlWrong: voters=$(length(voters)) penalized=$(length(penalized)) spared=$(length(spared)) newly_graved=$(length(graved)) grave_skip=$(length(grave_skipped))")
    return result
end

# ==============================================================================
# PHAGY HOOK — future stochastic maintenance
# ==============================================================================

"""
aiml_phagy_sweep!(; prune_graves::Bool = true)::Dict{String, Any}

GRUG: Future stochastic idle-time AIML phagy. For now, minimal:
prune AIML_GRAVE nodes on request. Real phagy will coinflip weak nodes,
stale templates, etc. — but that is a later event. Signature is stable so
callers can schedule it now without breaking when the real body lands.

If prune_graves is true, every AIML_GRAVE node is removed from its tribe.
Grave-state negative-reinforcement semantics persist until phagy runs —
this is the idle-time garbage collection for the executive layer.
"""
function aiml_phagy_sweep!(; prune_graves::Bool = true)::Dict{String, Any}
    pruned = Tuple{String, String}[]  # (lobe_id, node_id)
    lock(AIML_LOCK) do
        if prune_graves
            for (lobe_id, tribe) in AIML_REGISTRY
                grave_ids = [nid for (nid, n) in tribe if n.is_grave]
                for nid in grave_ids
                    delete!(tribe, nid)
                    push!(pruned, (lobe_id, nid))
                end
            end
        end
    end
    result = Dict{String, Any}(
        "pruned_count" => length(pruned),
        "pruned"       => pruned,
    )
    println("[AIML] 🧹 phagy_sweep: pruned $(length(pruned)) grave node(s).")
    return result
end

# ==============================================================================
# DIAGNOSTICS — status summary for /status and tests
# ==============================================================================

"""
get_aiml_status_summary()::String

GRUG: Human-readable snapshot for /status. Shows population vs cap per lobe,
live/grave counts, and current cycle number.
"""
function get_aiml_status_summary()::String
    lines = String[]
    lock(AIML_LOCK) do
        push!(lines, "=== AIML NODE TRIBES (cycle=$(CURRENT_CYCLE[])) ===")
        if isempty(AIML_REGISTRY)
            push!(lines, "  [no lobes registered]")
            return
        end
        for lobe_id in sort(collect(keys(AIML_REGISTRY)))
            tribe = AIML_REGISTRY[lobe_id]
            cap   = get(AIML_POPULATION_CAP, lobe_id, 0)
            live  = count(n -> !n.is_grave, values(tribe))
            grave = length(tribe) - live
            push!(lines, "  $lobe_id | pop=$(length(tribe))/$cap | live=$live | grave=$grave")
        end
    end
    return join(lines, "\n")
end

"""
reset_all!()

GRUG: Wipe the whole AIML registry + population caps + cycle counter.
For tests and clean-slate restarts only. In production this is a nuclear option.
"""
function reset_all!()
    lock(AIML_LOCK) do
        empty!(AIML_REGISTRY)
        empty!(AIML_POPULATION_CAP)
        CURRENT_CYCLE[] = 0
    end
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export AIMLNode, AIMLNodeError
export AIML_STRENGTH_CAP, AIML_STRENGTH_FLOOR, AIML_POPULATION_CAP_RATIO, AIML_STRENGTH_DELTA
export AIML_GRAVE_REASON_STRENGTH_ZERO
export register_lobe!, unregister_lobe!, is_lobe_registered
export get_population_cap, get_population_size, get_alive_population_size
export add_aiml_node!, get_aiml_node, has_aiml_node, remove_aiml_node!
export list_aiml_nodes, get_registered_lobes
export begin_cycle!, current_cycle
export record_fire!, record_vote!
export apply_aiml_right!, apply_aiml_wrong!
export aiml_phagy_sweep!
export get_aiml_status_summary, reset_all!

# GRUG say: AIML node tribes ready. Executive layer is now nodes, not blob.

end # module AIMLNodeSystem