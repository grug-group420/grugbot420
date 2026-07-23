# GeometryKit.jl
# ==============================================================================
# v9 STATE-SPACE GEOMETRY — Unified interface over four named geometric spaces
# ==============================================================================
# Thin wrapper that cross-references the four spaces that already exist
# implicitly in the codebase and makes them explicit, named, and navigable.
#
# The four spaces:
#   SemanticSpace  — graph of nodes + triples. Distance = semantic truth anchoring.
#   CoherenceSpace — scalar field Φ. Distance = coherence difference.
#   PhaseSpace     — 12-dim ATP vectors. Distance = JS divergence.
#   ToneSpace      — action×tone categories. Distance = confusion proxy.
#
# All distance functions already exist in other modules. GeometryKit just
# names the spaces and provides a unified query interface.
#
# DESIGN CONSTRAINTS:
#   - NO new algorithmic modules. All computation delegates to existing code.
#   - Weight defaults to 0.0 (OFF). No surprise activations.
#   - Additive (not multiplicative) integration.
#   - All state passed as parameters, no cross-module global references.
#   - Same pattern as CoherenceField: receive data, compute, return.
# ==============================================================================

module GeometryKit

using Base.Threads: ReentrantLock

# ── Named spaces ──────────────────────────────────────────────────────────────

@enum SpaceName begin
    SEMANTIC_SPACE
    COHERENCE_SPACE
    PHASE_SPACE
    TONE_SPACE
end

const SPACE_NAMES = Dict{SpaceName, String}(
    SEMANTIC_SPACE  => "semantic",
    COHERENCE_SPACE => "coherence",
    PHASE_SPACE     => "phase",
    TONE_SPACE      => "tone"
)

const SPACE_FROM_NAME = Dict{String, SpaceName}(
    "semantic"  => SEMANTIC_SPACE,
    "coherence" => COHERENCE_SPACE,
    "phase"     => PHASE_SPACE,
    "tone"      => TONE_SPACE
)

# ── Config ────────────────────────────────────────────────────────────────────

mutable struct GeometryConfig
    enabled::Bool                # master switch for geometry CLI
    default_space::SpaceName     # which space /phaseSpace uses when unspecified
    nearest_k::Int               # how many neighbors /phaseSpace nearest returns
    trajectory_depth::Int        # how many PhaseSnapshots for trajectory
end

const DEFAULT_GEOMETRY_CONFIG = GeometryConfig(
    true,                        # enabled
    PHASE_SPACE,                 # default space
    5,                           # nearest_k
    10                           # trajectory_depth
)

const GEOMETRY_CONFIG = Ref{GeometryConfig}(deepcopy(DEFAULT_GEOMETRY_CONFIG))
const _CONFIG_LOCK = ReentrantLock()

function geometry_config_snapshot()::GeometryConfig
    lock(_CONFIG_LOCK) do
        deepcopy(GEOMETRY_CONFIG[])
    end
end

function set_geometry_config!(key::Symbol, value)
    lock(_CONFIG_LOCK) do
        cfg = GEOMETRY_CONFIG[]
        if key === :enabled
            cfg.enabled = Bool(value)
        elseif key === :default_space
            if value isa SpaceName
                cfg.default_space = value
            elseif value isa AbstractString
                sn = get(SPACE_FROM_NAME, lowercase(strip(String(value))), nothing)
                sn === nothing && error("unknown space '$value'")
                cfg.default_space = sn
            else
                error("default_space expects SpaceName or String")
            end
        elseif key === :nearest_k
            cfg.nearest_k = max(1, Int(value))
        elseif key === :trajectory_depth
            cfg.trajectory_depth = max(1, Int(value))
        else
            error("unknown GeometryKit config key :$key")
        end
    end
    return nothing
end

function reset_geometry_config!()
    lock(_CONFIG_LOCK) do
        GEOMETRY_CONFIG[] = deepcopy(DEFAULT_GEOMETRY_CONFIG)
    end
    return nothing
end

# ── Serialization ─────────────────────────────────────────────────────────────

function geometry_config_to_dict()::Dict{String,Any}
    cfg = lock(_CONFIG_LOCK) do; GEOMETRY_CONFIG[] end
    d = Dict{String,Any}()
    d["enabled"] = cfg.enabled
    d["default_space"] = SPACE_NAMES[cfg.default_space]
    d["nearest_k"] = cfg.nearest_k
    d["trajectory_depth"] = cfg.trajectory_depth
    return d
end

function geometry_config_from_dict!(d)
    haskey(d, "enabled")    && set_geometry_config!(:enabled, Bool(d["enabled"]))
    haskey(d, "default_space") && set_geometry_config!(:default_space, String(d["default_space"]))
    haskey(d, "nearest_k")  && set_geometry_config!(:nearest_k, Int(d["nearest_k"]))
    haskey(d, "trajectory_depth") && set_geometry_config!(:trajectory_depth, Int(d["trajectory_depth"]))
    return nothing
end

# ── Distance functions ───────────────────────────────────────────────────────
#
# These compute distances directly from node data passed as parameters.
# No cross-module references. The CLI handler in Main.jl calls these with
# the appropriate data from NODE_MAP, BRIDGE_MAP, etc.
#
# Each function takes node objects (whatever the caller provides) and
# extracts the relevant field. This follows CoherenceField's pattern:
# all state passed in, no hidden globals.

"""
    semantic_distance(score_a::Float64, score_b::Float64) -> Float64

Distance in SemanticSpace. Given two pre-computed semantic truth scores,
return |score_a - score_b| in [0, 1]. The caller obtains the scores from
`engine._semantic_truth_score(node)` or the fallback triple-count proxy.
"""
function semantic_distance(score_a::Float64, score_b::Float64)::Float64
    return clamp(abs(score_a - score_b), 0.0, 1.0)
end

"""
    coherence_distance(delta_a::Float64, delta_b::Float64) -> Float64

Distance in CoherenceSpace. Given two pre-computed coherence deltas (ΔΦ),
return |delta_a - delta_b| normalized to [0, 1].
"""
function coherence_distance(delta_a::Float64, delta_b::Float64)::Float64
    return clamp(abs(delta_a - delta_b), 0.0, 1.0)
end

"""
    phase_distance(phase_a::Vector{Float64}, phase_b::Vector{Float64}) -> Float64

Distance in PhaseSpace between two 12-dim ATP phase vectors.
Computes JS divergence distance directly (same formula as
EphemeralAutomaton._distribution_js_distance). Returns value in [0, 1]
where 0 = identical phase.
"""
function phase_distance(phase_a::Vector{Float64}, phase_b::Vector{Float64})::Float64
    if length(phase_a) != length(phase_b)
        return 1.0
    end
    isempty(phase_a) && return 1.0
    # M = (a + b) / 2 — the midpoint distribution
    m = [(phase_a[i] + phase_b[i]) * 0.5 for i in eachindex(phase_a)]
    # KL(a || M)
    kl_am = 0.0
    for i in eachindex(phase_a)
        if phase_a[i] > 0.0 && m[i] > 0.0
            kl_am += phase_a[i] * log(phase_a[i] / m[i])
        end
    end
    # KL(b || M)
    kl_bm = 0.0
    for i in eachindex(phase_b)
        if phase_b[i] > 0.0 && m[i] > 0.0
            kl_bm += phase_b[i] * log(phase_b[i] / m[i])
        end
    end
    # JS divergence = (KL(a||M) + KL(b||M)) / 2
    js_div = (kl_am + kl_bm) * 0.5
    # JS distance = sqrt(JS divergence), bounded to [0, 1]
    js_dist = sqrt(clamp(js_div, 0.0, 1.0))
    return isnan(js_dist) ? 1.0 : js_dist
end

"""
    tone_distance(lobe_a::Union{Nothing,String}, lobe_b::Union{Nothing,String}) -> Float64

Distance in ToneSpace between two nodes. Uses the lobe assignment as a
coarse proxy: same lobe = 0.0, different lobe = 0.5, unknown = 1.0.
This is intentionally coarse — the full confusion matrix lives in ATP
and shouldn't be duplicated here.
"""
function tone_distance(lobe_a::Union{Nothing,String}, lobe_b::Union{Nothing,String})::Float64
    lobe_a === nothing && return 1.0
    lobe_b === nothing && return 1.0
    return lobe_a == lobe_b ? 0.0 : 0.5
end

# ── Unified distance dispatch ─────────────────────────────────────────────────

"""
    space_distance(space::SpaceName; kwargs...) -> Float64

Compute distance in the named space. Keyword args depend on the space:
  - SEMANTIC_SPACE:  score_a, score_b (Float64)
  - COHERENCE_SPACE: delta_a, delta_b (Float64)
  - PHASE_SPACE:     phase_a, phase_b (Vector{Float64})
  - TONE_SPACE:      lobe_a, lobe_b (Union{Nothing,String})
"""
function space_distance(space::SpaceName;
                        score_a::Float64=0.0, score_b::Float64=0.0,
                        delta_a::Float64=0.0, delta_b::Float64=0.0,
                        phase_a::Union{Nothing,Vector{Float64}}=nothing,
                        phase_b::Union{Nothing,Vector{Float64}}=nothing,
                        lobe_a::Union{Nothing,String}=nothing,
                        lobe_b::Union{Nothing,String}=nothing)::Float64
    if space === SEMANTIC_SPACE
        return semantic_distance(score_a, score_b)
    elseif space === COHERENCE_SPACE
        return coherence_distance(delta_a, delta_b)
    elseif space === PHASE_SPACE
        phase_a === nothing && return 1.0
        phase_b === nothing && return 1.0
        return phase_distance(phase_a, phase_b)
    elseif space === TONE_SPACE
        return tone_distance(lobe_a, lobe_b)
    else
        return 1.0
    end
end

function space_distance(space_str::AbstractString; kwargs...)::Float64
    sn = get(SPACE_FROM_NAME, lowercase(strip(String(space_str))), nothing)
    sn === nothing && error("unknown space '$space_str'")
    return space_distance(sn; kwargs...)
end

# ── Space overview ─────────────────────────────────────────────────────────────

"""
    geometry_overview(; phi::Float64=0.0, crystal_size::Int=0, n_nodes::Int=0)
        -> Dict{String,Any}

Overview of all four spaces: names, node counts, active status.
The caller provides phi, crystal_size, n_nodes from the live system.
"""
function geometry_overview(; phi::Float64=0.0, crystal_size::Int=0,
                             n_nodes::Int=0)::Dict{String,Any}
    cfg = geometry_config_snapshot()
    return Dict{String,Any}(
        "enabled"       => cfg.enabled,
        "default_space" => SPACE_NAMES[cfg.default_space],
        "n_nodes"       => n_nodes,
        "phi"           => round(phi; digits=4),
        "crystal_size"  => crystal_size,
        "spaces"        => ["semantic", "coherence", "phase", "tone"]
    )
end

"""
    trajectory(phase_entries::Vector; depth::Int=10) -> Dict{String,Any}

Current trajectory through PhaseSpace. Takes a vector of (id, confidence, timestamp)
tuples (provided by the caller from the PhaseAccumulator) and returns the
last `depth` entries as a trajectory.
"""
function trajectory(phase_entries::Vector; depth::Int=10)::Dict{String,Any}
    cfg = geometry_config_snapshot()
    depth = max(1, min(depth, cfg.trajectory_depth))
    n = min(depth, length(phase_entries))
    return Dict{String,Any}(
        "depth"   => depth,
        "count"   => n,
        "entries" => phase_entries[1:n]
    )
end

"""
    attractors(; gini::Float64=1.0) -> Dict{String,Any}

Detect attractor basins from pre-computed Gini coefficient on
ActionTonePredictor category distribution. Caller provides gini.
"""
function attractors(; gini::Float64=1.0)::Dict{String,Any}
    return Dict{String,Any}(
        "tone_attractor" => gini < 0.3 ? "STRONG (Gini=$(round(gini; digits=3)))" :
                            gini < 0.5 ? "MODERATE (Gini=$(round(gini; digits=3)))" :
                                         "NONE (Gini=$(round(gini; digits=3)))",
        "gini"           => round(gini; digits=4)
    )
end

# ── Exports ───────────────────────────────────────────────────────────────────

export SpaceName, SEMANTIC_SPACE, COHERENCE_SPACE, PHASE_SPACE, TONE_SPACE
export SPACE_NAMES, SPACE_FROM_NAME
export GeometryConfig, GEOMETRY_CONFIG, geometry_config_snapshot
export set_geometry_config!, reset_geometry_config!
export geometry_config_to_dict, geometry_config_from_dict!
export semantic_distance, coherence_distance, phase_distance, tone_distance
export space_distance
export geometry_overview, trajectory, attractors

end # module GeometryKit
