# ==============================================================================
# CoherenceField.jl — GRUG Global Coherence Field + Gradient Router
# ==============================================================================
# GRUG say: cave have many rocks. Each rock know own coherence. But no rock
#           know WHOLE CAVE coherence. Cave not have field. Now cave have field.
# GRUG say: field is simple. Sum of every rock's coherence times how awake it is.
#           Awake rock with high coherence = strong contribution. Sleeping rock
#           with low coherence = weak contribution. Sum is the field value Φ.
# GRUG say: gradient is also simple. "What happens to Φ if I wake THIS rock?"
#           Walk 2 hops from rock. See how neighbors change. ΔΦ = after − before.
#           Positive = this rock makes cave MORE coherent. Negative = less.
# GRUG say: vote system can USE gradient. Rock with positive ΔΦ gets bonus.
#           Rock with negative ΔΦ gets penalty. Cave naturally flows toward
#           coherent states. Not forced. Just nudged.
# GRUG say: WEIGHT DEFAULTS TO ZERO. Old behavior unchanged. User must
#           /coherenceConfig weight 0.05 to turn on. No surprise activations.
# GRUG say: NO SILENT FAILURES. Bad config throws. Gradient overflow clamps.
#           Every function returns something useful even on empty input.
# ==============================================================================
#
# ACADEMIC: This module implements a scalar coherence field over the entire
# activation state, with bounded-depth gradient computation for routing
# modulation. The field Φ = Σ coherence(i) × activation(i) aggregates
# per-node coherence (from PatternScanner, ImageSDF, TemporalCoherenceRecord)
# weighted by recency-based activation. The gradient ΔΦ_X measures the
# coherence impact of activating candidate X via a depth-bounded graph walk.
# Integration with VoteOrchestrator is additive: score += weight × ΔΦ.
# Weight=0.0 (default) means zero influence on existing behavior.
#
# DANGER: With weight > 0, the system develops genuine attractor dynamics.
# It will prefer coherent states and resist incoherent ones. This is the
# intended behavior (it's the whole point of coherence-gradient routing)
# but it means the system can become resistant to correction. Weight above
# 0.3 risks "quantum Zeno effect" — frequent routing locks the state.
# Recommended starting weight: 0.05. Always start low.
# ==============================================================================

module CoherenceField

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

using JSON
using Base.Threads: ReentrantLock

# ── Exports ──────────────────────────────────────────────────────────────────
export compute_field, compute_delta, coherence_field_status
export CoherenceFieldConfig, COHERENCE_FIELD_CONFIG
export set_coherence_config!, reset_coherence_config!, coherence_config_snapshot
export CoherenceFieldError

# ── Constants ────────────────────────────────────────────────────────────────
const COHERENCE_WEIGHT_MAX   = 0.5   # Hard ceiling on routing weight
const COHERENCE_DEPTH_MAX    = 3     # Max graph-walk depth for gradient
const COHERENCE_DECAY_MAX    = 0.1   # Max activation decay rate
const COHERENCE_RECENCY_MIN  = 10.0  # Min recency window (seconds)
const COHERENCE_RECENCY_MAX  = 3600.0 # Max recency window (1 hour)

# ── Safe node field accessor ──────────────────────────────────────────────────
# GRUG FIX: get(node, :is_grave, false) throws MethodError when node is a
# Node struct (not a Dict).  This helper works with both Node structs and
# Dicts by trying getproperty first, then falling back to get().
function _node_get(node, sym::Symbol, default)
    try
        val = getproperty(node, sym)
        return val
    catch
        # Not a struct field — try Dict-style get, then json_data, then default
        if isa(node, AbstractDict)
            return get(node, sym, default)
        end
        # Last resort: check json_data if it exists
        try
            jd = getproperty(node, :json_data)
            if isa(jd, AbstractDict) && haskey(jd, String(sym))
                return jd[String(sym)]
            end
        catch
        end
        return default
    end
end

# ── Error type ───────────────────────────────────────────────────────────────
struct CoherenceFieldError <: Exception
    msg::String
end
Base.show(io::IO, e::CoherenceFieldError) = print(io, "CoherenceFieldError: $(e.msg)")

# ── Configuration ───────────────────────────────────────────────────────────
mutable struct CoherenceFieldConfig
    weight::Float64           # 0.0 = off (default), max COHERENCE_WEIGHT_MAX
    depth::Int                # graph walk depth (1-COHERENCE_DEPTH_MAX, default 2)
    decay::Float64            # activation decay rate (0.0-COHERENCE_DECAY_MAX, default 0.01)
    recency_window::Float64   # seconds for "recently fired" (default 300.0)
    cached_phi::Float64       # last computed field value (cache)
    cache_timestamp::Float64  # when cache was set (epoch seconds)
    cache_ttl::Float64        # cache expiry in seconds (default 2.0)
end

const COHERENCE_FIELD_CONFIG = CoherenceFieldConfig(
    0.0,    # weight: OFF by default
    2,      # depth: 2-hop walk
    0.01,   # decay: gentle
    300.0,  # recency: 5 minutes
    0.0,    # cached_phi: no cache yet
    0.0,    # cache_timestamp: never computed
    2.0,    # cache_ttl: 2 seconds
)
const _CONFIG_LOCK = ReentrantLock()

# ── Config mutation ──────────────────────────────────────────────────────────

"""
    set_coherence_config!(field::Symbol, value)

Set a single configuration parameter. Throws CoherenceFieldError on invalid values.
Valid fields: :weight, :depth, :decay, :recency_window, :cache_ttl
"""
function set_coherence_config!(field::Symbol, value)
    lock(_CONFIG_LOCK) do
        if field === :weight
            if value < 0.0 || value > COHERENCE_WEIGHT_MAX
                throw(CoherenceFieldError(
                    "weight must be in [0.0, $(COHERENCE_WEIGHT_MAX)], got $value"))
            end
            COHERENCE_FIELD_CONFIG.weight = Float64(value)
        elseif field === :depth
            iv = Int(value)
            if iv < 1 || iv > COHERENCE_DEPTH_MAX
                throw(CoherenceFieldError(
                    "depth must be in [1, $(COHERENCE_DEPTH_MAX)], got $iv"))
            end
            COHERENCE_FIELD_CONFIG.depth = iv
        elseif field === :decay
            if value < 0.0 || value > COHERENCE_DECAY_MAX
                throw(CoherenceFieldError(
                    "decay must be in [0.0, $(COHERENCE_DECAY_MAX)], got $value"))
            end
            COHERENCE_FIELD_CONFIG.decay = Float64(value)
        elseif field === :recency_window
            if value < COHERENCE_RECENCY_MIN || value > COHERENCE_RECENCY_MAX
                throw(CoherenceFieldError(
                    "recency_window must be in [$(COHERENCE_RECENCY_MIN), $(COHERENCE_RECENCY_MAX)], got $value"))
            end
            COHERENCE_FIELD_CONFIG.recency_window = Float64(value)
        elseif field === :cache_ttl
            if value < 0.0
                throw(CoherenceFieldError("cache_ttl must be >= 0.0, got $value"))
            end
            COHERENCE_FIELD_CONFIG.cache_ttl = Float64(value)
        else
            throw(CoherenceFieldError("unknown config field: $field"))
        end
        # Invalidate cache on any config change
        COHERENCE_FIELD_CONFIG.cache_timestamp = 0.0
    end
    return nothing
end

"""
    reset_coherence_config!()

Reset all configuration to defaults. Weight goes back to 0.0 (off).
"""
function reset_coherence_config!()
    lock(_CONFIG_LOCK) do
        COHERENCE_FIELD_CONFIG.weight          = 0.0
        COHERENCE_FIELD_CONFIG.depth           = 2
        COHERENCE_FIELD_CONFIG.decay           = 0.01
        COHERENCE_FIELD_CONFIG.recency_window  = 300.0
        COHERENCE_FIELD_CONFIG.cache_ttl       = 2.0
        COHERENCE_FIELD_CONFIG.cached_phi      = 0.0
        COHERENCE_FIELD_CONFIG.cache_timestamp = 0.0
    end
    return nothing
end

"""
    coherence_config_snapshot() -> CoherenceFieldConfig

Thread-safe snapshot of COHERENCE_FIELD_CONFIG under _CONFIG_LOCK.
Returns a deep copy so callers can read fields without holding the lock.
"""
function coherence_config_snapshot()
    lock(_CONFIG_LOCK) do
        # Build a new struct from the current field values
        CoherenceFieldConfig(
            COHERENCE_FIELD_CONFIG.weight,
            COHERENCE_FIELD_CONFIG.depth,
            COHERENCE_FIELD_CONFIG.decay,
            COHERENCE_FIELD_CONFIG.recency_window,
            COHERENCE_FIELD_CONFIG.cache_ttl,
            COHERENCE_FIELD_CONFIG.cached_phi,
            COHERENCE_FIELD_CONFIG.cache_timestamp
        )
    end
end

# ── Internal: Activation function ────────────────────────────────────────────

"""
    _activation(node; now=time()) -> Float64

Compute recency-based activation: 1.0 for just-fired, decaying exponentially
with time since last fire. Nodes with no fire record get 0.0 activation.

Formula: a(t) = e^(-3 × (now - last_fire) / recency_window)
  - Just fired: a ≈ 1.0
  - Half recency_window ago: a ≈ e^(-1.5) ≈ 0.22
  - Full recency_window ago: a ≈ e^(-3) ≈ 0.05
  - Beyond window: ≈ 0 (contribution negligible)
"""
function _activation(node; now::Float64=time())
    window = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG.recency_window end
    if window <= 0.0
        return 0.0
    end
    last_fire = _node_get(node, :last_fire_time, nothing)
    if last_fire === nothing
        # Try json_data path for fire time
        jd = _node_get(node, :json_data, nothing)
        if jd !== nothing && isa(jd, AbstractDict)
            lft = get(jd, "last_fire_time", nothing)
            if lft === nothing
                return 0.0
            end
            last_fire = Float64(lft)
        else
            return 0.0
        end
    end
    if !isa(last_fire, Number) || last_fire <= 0.0
        return 0.0
    end
    elapsed = now - Float64(last_fire)
    if elapsed < 0.0
        return 1.0  # future timestamp? treat as just-fired
    end
    if elapsed > window * 2
        return 0.0  # well beyond window, skip expensive exp
    end
    return exp(-3.0 * elapsed / window)
end

# ── Internal: Node coherence extraction ───────────────────────────────────────

"""
    _node_coherence(node) -> Float64

Extract the best available coherence signal from a node. Multiple sources
are checked; the maximum is used (not average — we want the strongest
signal, not diluted by missing sources).

Sources checked (in priority order):
  1. scan_coherence — from PatternScanner's bidirectional coherence
  2. strength proxy — strength/max_strength as coherence approximation
  3. relational truth — how well this node's triples are anchored

Returns a value in [0.0, 1.0]. Returns 0.0 if no source available.
"""
function _node_coherence(node)
    best = 0.0

    # Source 1: scan_coherence (PatternScanner bidirectional)
    sc = _node_get(node, :scan_coherence, nothing)
    if sc !== nothing && isa(sc, Number) && isfinite(Float64(sc))
        best = max(best, Float64(sc))
    end

    # Source 2: strength proxy
    str = _node_get(node, :strength, nothing)
    if str !== nothing && isa(str, Number) && Float64(str) > 0.0
        cap = _node_get(node, :strength_cap, nothing)
        if cap !== nothing && isa(cap, Number) && Float64(cap) > 0.0
            ratio = Float64(str) / Float64(cap)
            best = max(best, clamp(ratio, 0.0, 1.0))
        end
    end

    # Source 3: coherence_score (ImageSDF temporal coherence)
    cs = _node_get(node, :coherence_score, nothing)
    if cs !== nothing && isa(cs, Number) && isfinite(Float64(cs))
        best = max(best, clamp(Float64(cs), 0.0, 1.0))
    end

    return best
end

# ── Public: Compute field value Φ ────────────────────────────────────────────

"""
    compute_field(nodes_dict; force=false) -> Float64

Compute the global coherence field value Φ = Σ coherence(i) × activation(i).

The sum aggregates every node's coherence weighted by its recency-based
activation level. Recently-fired high-coherence nodes dominate; dormant
low-coherence nodes contribute nearly nothing.

With `force=false`, returns cached value if within cache_ttl. With `force=true`,
always recomputes.

Returns 0.0 on empty input. Never throws.
"""
function compute_field(nodes_dict::Dict{<:AbstractString,<:Any};
                       force::Bool=false)
    now = time()

    # Snapshot config under lock for the duration of this computation
    weight = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG.weight end
    decay  = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG.decay end

    # Cache check
    if !force
        cache_hit = lock(_CONFIG_LOCK) do
            cfg = COHERENCE_FIELD_CONFIG
            cfg.cache_timestamp > 0.0 && (now - cfg.cache_timestamp) < cfg.cache_ttl && cfg.cached_phi
        end
        if cache_hit !== false
            return Float64(cache_hit)
        end
    end

    phi = 0.0
    for (nid, node) in nodes_dict
        # Skip grave nodes — they don't contribute to the field
        is_grave = _node_get(node, :is_grave, false)
        if is_grave === true || is_grave == 1
            continue
        end

        coherence = _node_coherence(node)
        activation = _activation(node; now=now)

        # Apply decay: reduce activation for very old nodes further
        if decay > 0.0 && activation > 0.0
            activation *= exp(-decay * (1.0 - activation))
        end

        contribution = coherence * activation

        # Clamp individual contributions to prevent overflow
        contribution = clamp(contribution, -1e6, 1e6)

        phi += contribution
    end

    # Update cache
    lock(_CONFIG_LOCK) do
        COHERENCE_FIELD_CONFIG.cached_phi = phi
        COHERENCE_FIELD_CONFIG.cache_timestamp = now
    end

    return phi
end

# ── Internal: Secondary and tertiary delta ────────────────────────────────────

"""
    _secondary_delta(candidate_id, nodes_dict, bridge_map) -> Float64

Compute depth-2 contribution to ΔΦ: the coherence impact of activating
the candidate's direct bridge partners and neighbors.

For each bridge partner: contribution = partner_coherence × 0.10 × partner_activation_delta
For each neighbor: contribution = neighbor_coherence × 0.05 × neighbor_activation_delta

The coupling factors (0.10, 0.05) are intentionally small — secondary
effects should be subtle nudges, not strong forces.
"""
function _secondary_delta(candidate_id::AbstractString,
                          nodes_dict::Dict{<:AbstractString,<:Any},
                          bridge_map::Dict{<:AbstractString,<:Any})::Float64
    delta = 0.0
    candidate = get(nodes_dict, candidate_id, nothing)
    if candidate === nothing
        return 0.0
    end

    # Bridge partners: 10% coupling
    if haskey(bridge_map, candidate_id)
        partners = bridge_map[candidate_id]
        if isa(partners, AbstractVector)
            for partner_entry in partners
                partner_id = nothing
                if isa(partner_entry, AbstractString)
                    partner_id = partner_entry
                elseif isa(partner_entry, AbstractDict)
                    partner_id = get(partner_entry, "target_id",
                              get(partner_entry, :target_id, nothing))
                end
                if partner_id !== nothing
                    partner_node = get(nodes_dict, partner_id, nothing)
                    if partner_node !== nothing
                        pc = _node_coherence(partner_node)
                        pa = _activation(partner_node)
                        delta += pc * 0.10 * max(0.0, 1.0 - pa)
                    end
                end
            end
        end
    end

    # Neighbors from node's neighbor_ids: 5% coupling
    neighbor_ids = _node_get(candidate, :neighbor_ids, nothing)
    if neighbor_ids !== nothing && isa(neighbor_ids, AbstractVector)
        for neighbor_id in neighbor_ids
            nid_str = String(neighbor_id)
            neighbor = get(nodes_dict, nid_str, nothing)
            if neighbor !== nothing
                nc = _node_coherence(neighbor)
                na = _activation(neighbor)
                delta += nc * 0.05 * max(0.0, 1.0 - na)
            end
        end
    end

    return delta
end

"""
    _tertiary_delta(candidate_id, nodes_dict, bridge_map) -> Float64

Compute depth-3 contribution to ΔΦ. Only used when config.depth >= 3.
Walks one more hop beyond secondary partners.

Coupling factor is 1% — tertiary effects are barely perceptible.
This exists for completeness; most users should stick with depth=2.
"""
function _tertiary_delta(candidate_id::AbstractString,
                         nodes_dict::Dict{<:AbstractString,<:Any},
                         bridge_map::Dict{<:AbstractString,<:Any})::Float64
    delta = 0.0

    # Walk bridge partners of bridge partners
    if haskey(bridge_map, candidate_id)
        partners = bridge_map[candidate_id]
        if isa(partners, AbstractVector)
            for partner_entry in partners
                partner_id = nothing
                if isa(partner_entry, AbstractString)
                    partner_id = partner_entry
                elseif isa(partner_entry, AbstractDict)
                    partner_id = get(partner_entry, "target_id",
                              get(partner_entry, :target_id, nothing))
                end
                if partner_id !== nothing && haskey(bridge_map, partner_id)
                    # Walk one more hop
                    sub_partners = bridge_map[partner_id]
                    if isa(sub_partners, AbstractVector)
                        for sub_entry in sub_partners
                            sub_id = nothing
                            if isa(sub_entry, AbstractString)
                                sub_id = sub_entry
                            elseif isa(sub_entry, AbstractDict)
                                sub_id = get(sub_entry, "target_id",
                                      get(sub_entry, :target_id, nothing))
                            end
                            if sub_id !== nothing && sub_id != candidate_id
                                sub_node = get(nodes_dict, sub_id, nothing)
                                if sub_node !== nothing
                                    sc = _node_coherence(sub_node)
                                    sa = _activation(sub_node)
                                    delta += sc * 0.01 * max(0.0, 1.0 - sa)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return delta
end

# ── Internal: Inhibition awareness ────────────────────────────────────────────

"""
    _inhibition_delta(candidate, nodes_dict) -> Float64

Strong nodes may suppress weaker neighbors. If the candidate is strong,
activating it may DECREASE the effective activation of its neighbors
(competitive inhibition). This contributes a negative ΔΦ term.

Only applies when candidate strength > 0.5 (relative to cap).
The negative contribution is proportional to the strength excess.
"""
function _inhibition_delta(candidate, nodes_dict)::Float64
    str = _node_get(candidate, :strength, 0.0)
    cap = _node_get(candidate, :strength_cap, 1.0)
    if !isa(str, Number) || !isa(cap, Number) || Float64(cap) <= 0.0
        return 0.0
    end
    rel_str = Float64(str) / Float64(cap)
    if rel_str < 0.5
        return 0.0  # Not strong enough to inhibit
    end

    # Count weaker neighbors
    neighbor_ids = _node_get(candidate, :neighbor_ids, nothing)
    if neighbor_ids === nothing || !isa(neighbor_ids, AbstractVector) || isempty(neighbor_ids)
        return 0.0
    end

    inhibition = 0.0
    for nid in neighbor_ids
        nstr = nothing
        neighbor = get(nodes_dict, String(nid), nothing)
        if neighbor !== nothing
            ns = _node_get(neighbor, :strength, 0.0)
            nc = _node_get(neighbor, :strength_cap, 1.0)
            if isa(ns, Number) && isa(nc, Number) && Float64(nc) > 0.0
                nrel = Float64(ns) / Float64(nc)
                if nrel < rel_str
                    # This neighbor would be inhibited
                    inhibition -= 0.02 * (rel_str - nrel) * _node_coherence(neighbor)
                end
            end
        end
    end

    return inhibition
end

# ── Public: Compute gradient ΔΦ ──────────────────────────────────────────────

"""
    compute_delta(candidate_id, nodes_dict, bridge_map; force=false) -> Float64

Compute the coherence gradient ΔΦ_X: the change in the global field value
if candidate X were to become fully activated.

Method:
  1. Compute baseline Φ (before activation)
  2. Simulate activation of candidate (activation → 1.0)
  3. Walk depth-bounded graph from candidate, accumulating secondary/tertiary
  4. Account for inhibition (strong nodes suppress neighbors)
  5. ΔΦ = simulated_Φ - baseline_Φ

Returns 0.0 if candidate not found. Never throws.

The gradient is the KEY signal for coherence-gradient routing:
  - ΔΦ > 0: activating this node increases coherence (good)
  - ΔΦ < 0: activating this node decreases coherence (bad)
  - ΔΦ ≈ 0: neutral

With weight=0.0 (default), this has NO effect on voting.
"""
function compute_delta(candidate_id::AbstractString,
                       nodes_dict::Dict{<:AbstractString,<:Any},
                       bridge_map::Dict{<:AbstractString,<:Any};
                       force::Bool=false)
    # Baseline field value
    phi_before = compute_field(nodes_dict; force=force)

    candidate = get(nodes_dict, candidate_id, nothing)
    if candidate === nothing
        return 0.0
    end

    # Skip grave nodes — they can't contribute
    is_grave = _node_get(candidate, :is_grave, false)
    if is_grave === true || is_grave == 1
        return 0.0
    end

    # Direct contribution: if this node were fully activated
    coherence = _node_coherence(candidate)
    # Currently: coherence × current_activation
    current_activation = _activation(candidate)
    current_contribution = coherence * current_activation
    # If activated: coherence × 1.0
    activated_contribution = coherence * 1.0

    delta = activated_contribution - current_contribution

    # Secondary: depth-2 walk (bridge partners + neighbors)
    depth = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG.depth end
    if depth >= 2
        delta += _secondary_delta(candidate_id, nodes_dict, bridge_map)
    end

    # Tertiary: depth-3 walk (only if depth >= 3)
    if depth >= 3
        delta += _tertiary_delta(candidate_id, nodes_dict, bridge_map)
    end

    # Inhibition: strong nodes may suppress weaker neighbors
    delta += _inhibition_delta(candidate, nodes_dict)

    # Clamp to prevent extreme values
    delta = clamp(delta, -10.0, 10.0)

    return delta
end

# ── Public: Field status report ───────────────────────────────────────────────

"""
    coherence_field_status(nodes_dict; force=false) -> Dict{String,Any}

Generate a comprehensive status report for the coherence field.

Returns:
  - "phi": current field value Φ
  - "n_nodes": total node count
  - "n_active": number of nodes with activation > 0.01
  - "n_coherent": number of nodes with coherence > 0.5
  - "top_contributors": top 5 contributors (id + contribution)
  - "bottom_contributors": bottom 5 contributors (id + contribution)
  - "config": current configuration snapshot
"""
function coherence_field_status(nodes_dict::Dict{<:AbstractString,<:Any};
                                force::Bool=false)
    phi = compute_field(nodes_dict; force=force)
    now = time()

    n_nodes = length(nodes_dict)
    n_active = 0
    n_coherent = 0
    contributions = Vector{Dict{String,Any}}()

    for (nid, node) in nodes_dict
        is_grave = _node_get(node, :is_grave, false)
        if is_grave === true || is_grave == 1
            continue
        end

        coherence = _node_coherence(node)
        activation = _activation(node; now=now)

        decay = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG.decay end
        if decay > 0.0 && activation > 0.0
            activation *= exp(-decay * (1.0 - activation))
        end

        if activation > 0.01
            n_active += 1
        end
        if coherence > 0.5
            n_coherent += 1
        end

        contribution = coherence * activation
        push!(contributions, Dict{String,Any}(
            "id" => String(nid),
            "contribution" => contribution,
            "coherence" => coherence,
            "activation" => activation,
        ))
    end

    # Sort by contribution (descending)
    sort!(contributions; by=c -> c["contribution"], rev=true)

    top5 = length(contributions) >= 5 ? contributions[1:5] : contributions
    bot_candidates = filter(c -> c["contribution"] > 0.0, contributions)
    # Bottom 5 among non-zero contributors (most negative or smallest positive)
    sort!(bot_candidates; by=c -> c["contribution"])
    bot5 = length(bot_candidates) >= 5 ? bot_candidates[1:5] : bot_candidates

    cfg_snap = lock(_CONFIG_LOCK) do
        (weight=COHERENCE_FIELD_CONFIG.weight,
         depth=COHERENCE_FIELD_CONFIG.depth,
         decay=COHERENCE_FIELD_CONFIG.decay,
         recency_window=COHERENCE_FIELD_CONFIG.recency_window,
         cache_ttl=COHERENCE_FIELD_CONFIG.cache_ttl)
    end

    return Dict{String,Any}(
        "phi"              => phi,
        "n_nodes"          => n_nodes,
        "n_active"         => n_active,
        "n_coherent"       => n_coherent,
        "top_contributors" => top5,
        "bottom_contributors" => bot5,
        "config" => Dict{String,Any}(
            "weight"          => cfg_snap.weight,
            "depth"           => cfg_snap.depth,
            "decay"           => cfg_snap.decay,
            "recency_window"  => cfg_snap.recency_window,
            "cache_ttl"       => cfg_snap.cache_ttl,
        ),
    )
end

# ── Serialization helpers ────────────────────────────────────────────────────

"""
    coherence_config_to_dict() -> Dict{String,Any}

Serialize the current CoherenceField config to a dictionary suitable for
specimen save. Only serializes non-default values to keep specimens clean.
"""
function coherence_config_to_dict()
    cfg = lock(_CONFIG_LOCK) do; COHERENCE_FIELD_CONFIG end
    d = Dict{String,Any}()
    # Always save weight (most important lever)
    d["weight"] = cfg.weight
    if cfg.depth != 2
        d["depth"] = cfg.depth
    end
    if cfg.decay != 0.01
        d["decay"] = cfg.decay
    end
    if cfg.recency_window != 300.0
        d["recency_window"] = cfg.recency_window
    end
    if cfg.cache_ttl != 2.0
        d["cache_ttl"] = cfg.cache_ttl
    end
    return d
end

"""
    coherence_config_from_dict!(d::Dict)

Restore CoherenceField config from a dictionary (specimen load).
Only sets values that are present in the dict; defaults are preserved.
"""
function coherence_config_from_dict!(d)
    if haskey(d, "weight")
        set_coherence_config!(:weight, Float64(d["weight"]))
    end
    if haskey(d, "depth")
        set_coherence_config!(:depth, Int(d["depth"]))
    end
    if haskey(d, "decay")
        set_coherence_config!(:decay, Float64(d["decay"]))
    end
    if haskey(d, "recency_window")
        set_coherence_config!(:recency_window, Float64(d["recency_window"]))
    end
    if haskey(d, "cache_ttl")
        set_coherence_config!(:cache_ttl, Float64(d["cache_ttl"]))
    end
    return nothing
end

end # module CoherenceField
