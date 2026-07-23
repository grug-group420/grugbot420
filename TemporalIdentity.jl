# TemporalIdentity.jl
# ==============================================================================
# v9 TEMPORAL IDENTITY — Continuity through change.
# First-class continuant objects that group temporal chains of nodes under a
# single identity. NOT memory — identity. The thing that remains itself while
# changing.
# ==============================================================================
# Seed → sprout → tree → dead_tree → soil. These are different states of
# the SAME thing. A continuant says: "these nodes share an identity that
# persists across temporal transformation."
#
# DESIGN CONSTRAINTS:
#   - Continuants are DERIVED structures — they sit on top of existing
#     temporal triples, they don't replace them.
#   - Discovery is PROPOSED, not FORCED. Same gate as PatternMiner.
#   - Coherence of a continuant comes from the temporal coherence of its
#     stages — stages that fire consistently make strong identities.
#   - All state managed internally. No cross-module global references.
# ==============================================================================

module TemporalIdentity

using Base.Threads: ReentrantLock
using Dates: unix2datetime, datetime2unix, now

# ── Stage: one temporal phase of a continuant ────────────────────────────

struct Stage
    node_id::String              # the node at this temporal phase
    phase::String                # human-readable phase name (e.g. "seed", "tree")
    orientation::Symbol          # :before, :now, or :next — mirrors time sigils
    entered_at::Float64          # unix timestamp when this stage was recorded
end

# ── Continuant: identity that persists across temporal change ────────────

mutable struct Continuant
    id::String                   # unique continuant ID (e.g. "oak_001")
    class::String                # what kind of thing this is (e.g. "oak")
    stages::Vector{Stage}        # ordered temporal stages
    coherence::Float64           # how tightly these stages cohere as one identity [0,1]
    transform_rules::Vector{Tuple{String,String}}  # valid transitions: (from_phase, to_phase)
    created_at::Float64          # when this continuant was created
    last_updated::Float64        # when any stage was added/modified
end

# ── Proposal for auto-discovered continuant ──────────────────────────────

mutable struct ContinuantProposal
    id::String                             # unique proposal ID
    proposed_class::String                 # e.g. "oak"
    proposed_stages::Vector{Stage}        # stages that would form this identity
    chain_coherence::Float64               # coherence of the temporal chain
    example_triples::Vector{String}        # representative temporal triples
    first_seen::Float64
    last_seen::Float64
    status::Symbol                         # :pending, :approved, :rejected
end

# ── Config ───────────────────────────────────────────────────────────────

mutable struct TemporalIdentityConfig
    enabled::Bool
    auto_discover::Bool                    # whether to auto-propose continuants
    coherence_threshold::Float64           # minimum coherence to propose (0.5)
    max_stages::Int                        # max stages per continuant (20)
    max_continuants::Int                   # max continuants to track (100)
    max_proposals::Int                     # max pending proposals (50)
    stage_ttl::Float64                     # seconds before a stage is considered stale (86400)
end

const DEFAULT_TEMPORAL_IDENTITY_CONFIG = TemporalIdentityConfig(
    true,     # enabled
    false,    # auto_discover (off by default — manual creation first)
    0.5,      # coherence_threshold
    20,       # max_stages
    100,      # max_continuants
    50,       # max_proposals
    86400.0   # stage_ttl (24 hours)
)

const TEMPORAL_IDENTITY_CONFIG = Ref{TemporalIdentityConfig}(deepcopy(DEFAULT_TEMPORAL_IDENTITY_CONFIG))
const _CONFIG_LOCK = ReentrantLock()

# ── Storage ──────────────────────────────────────────────────────────────

const _CONTINUANTS = Dict{String, Continuant}()         # continuant_id → Continuant
const _NODE_INDEX = Dict{String, String}()              # node_id → continuant_id (reverse lookup)
const _PROPOSALS = Dict{String, ContinuantProposal}()   # proposal_id → proposal
const _CONTINUANTS_LOCK = ReentrantLock()
const _NODE_INDEX_LOCK = ReentrantLock()
const _PROPOSALS_LOCK = ReentrantLock()

# ── Proposal ID counter ──────────────────────────────────────────────────

const _PROPOSAL_COUNTER = Ref{Int}(0)
const _PROPOSAL_COUNTER_LOCK = ReentrantLock()

function _new_proposal_id()::String
    lock(_PROPOSAL_COUNTER_LOCK) do
        _PROPOSAL_COUNTER[] += 1
        return "cp_$(_PROPOSAL_COUNTER[])"
    end
end

# ── Config management (same pattern as CoherenceField/GeometryKit) ──────

function temporal_identity_config_snapshot()::TemporalIdentityConfig
    lock(_CONFIG_LOCK) do
        deepcopy(TEMPORAL_IDENTITY_CONFIG[])
    end
end

function set_temporal_identity_config!(key::Symbol, value)
    lock(_CONFIG_LOCK) do
        cfg = TEMPORAL_IDENTITY_CONFIG[]
        if key === :enabled
            cfg.enabled = Bool(value)
        elseif key === :auto_discover
            cfg.auto_discover = Bool(value)
        elseif key === :coherence_threshold
            cfg.coherence_threshold = Float64(value)
        elseif key === :max_stages
            cfg.max_stages = Int(value)
        elseif key === :max_continuants
            cfg.max_continuants = Int(value)
        elseif key === :max_proposals
            cfg.max_proposals = Int(value)
        elseif key === :stage_ttl
            cfg.stage_ttl = Float64(value)
        else
            error("unknown config key: $key")
        end
    end
end

function reset_temporal_identity_config!()
    lock(_CONFIG_LOCK) do
        TEMPORAL_IDENTITY_CONFIG[] = deepcopy(DEFAULT_TEMPORAL_IDENTITY_CONFIG)
    end
end

function temporal_identity_config_to_dict()::Dict{String,Any}
    lock(_CONFIG_LOCK) do
        cfg = TEMPORAL_IDENTITY_CONFIG[]
        return Dict{String,Any}(
            "enabled"             => cfg.enabled,
            "auto_discover"       => cfg.auto_discover,
            "coherence_threshold" => cfg.coherence_threshold,
            "max_stages"          => cfg.max_stages,
            "max_continuants"     => cfg.max_continuants,
            "max_proposals"       => cfg.max_proposals,
            "stage_ttl"           => cfg.stage_ttl
        )
    end
end

function temporal_identity_config_from_dict!(d)
    lock(_CONFIG_LOCK) do
        cfg = TEMPORAL_IDENTITY_CONFIG[]
        haskey(d, "enabled")             && (cfg.enabled = Bool(d["enabled"]))
        haskey(d, "auto_discover")       && (cfg.auto_discover = Bool(d["auto_discover"]))
        haskey(d, "coherence_threshold") && (cfg.coherence_threshold = Float64(d["coherence_threshold"]))
        haskey(d, "max_stages")          && (cfg.max_stages = Int(d["max_stages"]))
        haskey(d, "max_continuants")     && (cfg.max_continuants = Int(d["max_continuants"]))
        haskey(d, "max_proposals")       && (cfg.max_proposals = Int(d["max_proposals"]))
        haskey(d, "stage_ttl")           && (cfg.stage_ttl = Float64(d["stage_ttl"]))
    end
end

# ── Continuant CRUD ─────────────────────────────────────────────────────

"""
    create_continuant(class::String; id::String="") → Continuant

Create a new continuant with no stages. If id is empty, auto-generate one.
"""
function create_continuant(class::String; id::String="")::Continuant
    if isempty(id)
        lock(_CONTINUANTS_LOCK) do
            id = "cont_$(length(_CONTINUANTS) + 1)_$(round(Int, time()))"
        end
    end
    now_t = time()
    c = Continuant(id, class, Stage[], 0.0, Tuple{String,String}[], now_t, now_t)
    lock(_CONTINUANTS_LOCK) do
        cfg = temporal_identity_config_snapshot()
        if length(_CONTINUANTS) >= cfg.max_continuants
            error("max_continuants ($(cfg.max_continuants)) reached")
        end
        _CONTINUANTS[id] = c
    end
    return c
end

"""
    add_stage!(continuant_id::String, node_id::String, phase::String,
               orientation::Symbol) → Continuant

Add a stage to a continuant. Updates the node index. Recomputes coherence.
"""
function add_stage!(continuant_id::String, node_id::String, phase::String,
                    orientation::Symbol)::Continuant
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && error("continuant '$continuant_id' not found")
        cfg = temporal_identity_config_snapshot()
        length(c.stages) >= cfg.max_stages && error("max_stages ($(cfg.max_stages)) reached for '$continuant_id'")
        # Check node not already in another continuant
        existing = get(_NODE_INDEX, node_id, "")
        if !isempty(existing) && existing != continuant_id
            error("node '$node_id' already belongs to continuant '$existing'")
        end
        s = Stage(node_id, phase, orientation, time())
        push!(c.stages, s)
        c.last_updated = time()
        # Sort stages by orientation: :before < :now < :next
        orient_order = Dict(:before => 1, :now => 2, :next => 3)
        sort!(c.stages; by=s -> get(orient_order, s.orientation, 0))
        # Recompute coherence
        c.coherence = _compute_continuant_coherence(c)
        # Update node index
        _NODE_INDEX[node_id] = continuant_id
        return c
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

"""
    add_transform_rule!(continuant_id::String, from_phase::String, to_phase::String)

Add a valid transition rule to a continuant.
"""
function add_transform_rule!(continuant_id::String, from_phase::String, to_phase::String)
    lock(_CONTINUANTS_LOCK) do
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && error("continuant '$continuant_id' not found")
        push!(c.transform_rules, (from_phase, to_phase))
        c.last_updated = time()
    end
end

"""
    remove_stage!(continuant_id::String, node_id::String)

Remove a stage by node_id. Cleans up the node index. Recomputes coherence.
"""
function remove_stage!(continuant_id::String, node_id::String)
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && error("continuant '$continuant_id' not found")
        filter!(s -> s.node_id != node_id, c.stages)
        delete!(_NODE_INDEX, node_id)
        c.coherence = _compute_continuant_coherence(c)
        c.last_updated = time()
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

"""
    identity_of(node_id::String) → Union{Continuant, Nothing}

Look up which continuant a node belongs to. O(1) via the node index.
"""
function identity_of(node_id::String)::Union{Continuant,Nothing}
    lock(_NODE_INDEX_LOCK) do
        cid = get(_NODE_INDEX, node_id, "")
        isempty(cid) && return nothing
        return lock(_CONTINUANTS_LOCK) do
            get(_CONTINUANTS, cid, nothing)
        end
    end
end

"""
    get_continuant(continuant_id::String) → Union{Continuant, Nothing}
"""
function get_continuant(continuant_id::String)::Union{Continuant,Nothing}
    lock(_CONTINUANTS_LOCK) do
        get(_CONTINUANTS, continuant_id, nothing)
    end
end

"""
    list_continuants() → Vector{Continuant}

List all continuants, sorted by coherence (highest first).
"""
function list_continuants()::Vector{Continuant}
    lock(_CONTINUANTS_LOCK) do
        sort(collect(values(_CONTINUANTS)); by=c -> c.coherence, rev=true)
    end
end

"""
    stages_of(continuant_id::String) → Vector{Stage}
"""
function stages_of(continuant_id::String)::Vector{Stage}
    lock(_CONTINUANTS_LOCK) do
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && return Stage[]
        return deepcopy(c.stages)
    end
end

"""
    what_was(continuant_id::String, orientation::Symbol=:before) → Vector{Stage}

Get all stages at a given orientation (e.g. :before = past stages).
"""
function what_was(continuant_id::String, orientation::Symbol=:before)::Vector{Stage}
    lock(_CONTINUANTS_LOCK) do
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && return Stage[]
        return filter(s -> s.orientation == orientation, c.stages)
    end
end

"""
    what_becomes(continuant_id::String, from_phase::String) → Vector{Stage}

Get downstream stages reachable from a given phase via transform rules.
"""
function what_becomes(continuant_id::String, from_phase::String)::Vector{Stage}
    lock(_CONTINUANTS_LOCK) do
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && return Stage[]
        # Find all phases reachable from from_phase via transform rules
        reachable_phases = Set{String}([from_phase])
        # BFS through transform rules (max depth = number of rules)
        for _ in 1:length(c.transform_rules)
            new_phases = Set{String}()
            for (src, dst) in c.transform_rules
                if src in reachable_phases
                    push!(new_phases, dst)
                end
            end
            union!(reachable_phases, new_phases)
        end
        # Return stages whose phase is in reachable_phases (excluding from_phase itself)
        filter(s -> s.phase in reachable_phases && s.phase != from_phase, c.stages)
    end
end

"""
    merge_continuants!(a_id::String, b_id::String; new_class::String="")

Merge continuant b into continuant a. All stages of b become stages of a.
B is deleted. Node index is updated. Coherence is recomputed.
"""
function merge_continuants!(a_id::String, b_id::String; new_class::String="")
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        a = get(_CONTINUANTS, a_id, nothing)
        b = get(_CONTINUANTS, b_id, nothing)
        a === nothing && error("continuant '$a_id' not found")
        b === nothing && error("continuant '$b_id' not found")
        # Merge stages
        for s in b.stages
            push!(a.stages, s)
            _NODE_INDEX[s.node_id] = a_id
        end
        # Merge transform rules (deduplicated)
        for rule in b.transform_rules
            if !(rule in a.transform_rules)
                push!(a.transform_rules, rule)
            end
        end
        # Update class if specified
        if !isempty(new_class)
            a.class = new_class
        end
        # Sort stages
        orient_order = Dict(:before => 1, :now => 2, :next => 3)
        sort!(a.stages; by=s -> get(orient_order, s.orientation, 0))
        # Recompute coherence
        a.coherence = _compute_continuant_coherence(a)
        a.last_updated = time()
        # Delete b
        delete!(_CONTINUANTS, b_id)
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

"""
    delete_continuant!(continuant_id::String)

Delete a continuant and clean up the node index.
"""
function delete_continuant!(continuant_id::String)
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        c = get(_CONTINUANTS, continuant_id, nothing)
        c === nothing && return
        for s in c.stages
            delete!(_NODE_INDEX, s.node_id)
        end
        delete!(_CONTINUANTS, continuant_id)
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

# ── Internal: compute coherence of a continuant ─────────────────────────
# Coherence comes from two factors:
#   1. Temporal ordering consistency — stages should progress :before → :now → :next
#   2. Orientation consistency — stages at the same orientation should be close in time
# Result is in [0, 1]. Empty continuant = 0.0, single stage = 1.0.

function _compute_continuant_coherence(c::Continuant)::Float64
    n = length(c.stages)
    n == 0 && return 0.0
    n == 1 && return 1.0

    # Factor 1: Temporal ordering score
    # Stages should be ordered by orientation (:before → :now → :next)
    orient_order = Dict(:before => 1, :now => 2, :next => 3)
    orient_seq = [get(orient_order, s.orientation, 0) for s in c.stages]
    # Count inversions (out-of-order pairs)
    inversions = 0
    for i in 1:length(orient_seq)
        for j in (i+1):length(orient_seq)
            if orient_seq[i] > orient_seq[j]
                inversions += 1
            end
        end
    end
    max_inv = n * (n - 1) ÷ 2
    ordering_score = max_inv == 0 ? 1.0 : 1.0 - (inversions / max_inv)

    # Factor 2: Temporal clustering score
    # Stages at the same orientation should be close in time
    by_orient = Dict{Int, Vector{Float64}}()
    for s in c.stages
        o = get(orient_order, s.orientation, 0)
        if !haskey(by_orient, o)
            by_orient[o] = Float64[]
        end
        push!(by_orient[o], s.entered_at)
    end
    cluster_score = 1.0
    for (_, times) in by_orient
        length(times) > 1 || continue
        # Max spread within an orientation group, normalized by TTL
        spread = maximum(times) - minimum(times)
        cfg = temporal_identity_config_snapshot()
        normalized_spread = min(spread / cfg.stage_ttl, 1.0)
        cluster_score *= (1.0 - normalized_spread * 0.5)  # penalty for large spread
    end

    # Combined coherence (equal weight)
    return clamp(0.5 * ordering_score + 0.5 * cluster_score, 0.0, 1.0)
end

# ── Proposal system_secure(same gate pattern as PatternMiner) ──────────────────

"""
    propose_continuant!(class::String, stages::Vector{Stage};
                        example_triples::Vector{String}=String[]) → ContinuantProposal

Create a proposal for a new continuant. NOT auto-registered.
"""
function propose_continuant!(class::String, stages::Vector{Stage};
                             example_triples::Vector{String}=String[])::ContinuantProposal
    lock(_PROPOSALS_LOCK) do
        cfg = temporal_identity_config_snapshot()
        if length(_PROPOSALS) >= cfg.max_proposals
            error("max_proposals ($(cfg.max_proposals)) reached")
        end
        pid = _new_proposal_id()
        coherence = _compute_stages_coherence(stages)
        now_t = time()
        p = ContinuantProposal(pid, class, stages, coherence,
                               example_triples, now_t, now_t, :pending)
        _PROPOSALS[pid] = p
        return p
    end
end

function _compute_stages_coherence(stages::Vector{Stage})::Float64
    n = length(stages)
    n <= 1 && return 1.0
    orient_order = Dict(:before => 1, :now => 2, :next => 3)
    orient_seq = [get(orient_order, s.orientation, 0) for s in stages]
    inversions = 0
    for i in 1:length(orient_seq)
        for j in (i+1):length(orient_seq)
            if orient_seq[i] > orient_seq[j]
                inversions += 1
            end
        end
    end
    max_inv = n * (n - 1) ÷ 2
    return max_inv == 0 ? 1.0 : 1.0 - (inversions / max_inv)
end

"""
    list_continuant_proposals(; status::Union{Nothing,Symbol}=nothing) → Vector{ContinuantProposal}
"""
function list_continuant_proposals(; status::Union{Nothing,Symbol}=nothing)::Vector{ContinuantProposal}
    lock(_PROPOSALS_LOCK) do
        props = collect(values(_PROPOSALS))
        if status !== nothing
            props = filter(p -> p.status == status, props)
        end
        return props
    end
end

"""
    approve_continuant_proposal!(proposal_id::String) → Union{ContinuantProposal, Nothing}

Approve a proposal → creates the continuant. Returns the proposal (with :approved status).
"""
function approve_continuant_proposal!(proposal_id::String)::Union{ContinuantProposal,Nothing}
    lock(_PROPOSALS_LOCK)
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        p = get(_PROPOSALS, proposal_id, nothing)
        p === nothing && return nothing
        p.status != :pending && return nothing
        # Create the continuant
        c = Continuant(p.id, p.proposed_class, deepcopy(p.proposed_stages),
                       p.chain_coherence, Tuple{String,String}[],
                       p.first_seen, p.last_seen)
        _CONTINUANTS[c.id] = c
        # Update node index
        for s in c.stages
            _NODE_INDEX[s.node_id] = c.id
        end
        p.status = :approved
        return p
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
        unlock(_PROPOSALS_LOCK)
    end
end

"""
    reject_continuant_proposal!(proposal_id::String) → Union{ContinuantProposal, Nothing}
"""
function reject_continuant_proposal!(proposal_id::String)::Union{ContinuantProposal,Nothing}
    lock(_PROPOSALS_LOCK) do
        p = get(_PROPOSALS, proposal_id, nothing)
        p === nothing && return nothing
        p.status != :pending && return nothing
        p.status = :rejected
        return p
    end
end

"""
    clear_continuants!()

Remove all continuants and clean up the node index.
"""
function clear_continuants!()
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        empty!(_NODE_INDEX)
        empty!(_CONTINUANTS)
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

"""
    clear_proposals!()

Remove all proposals.
"""
function clear_proposals!()
    lock(_PROPOSALS_LOCK) do
        empty!(_PROPOSALS)
    end
end

# ── Status overview ──────────────────────────────────────────────────────

function temporal_identity_status()::Dict{String,Any}
    lock(_CONTINUANTS_LOCK)
    lock(_PROPOSALS_LOCK)
    try
        n_cont = length(_CONTINUANTS)
        # GRUG v9.4: COHERENCE FIX — sum() over an empty generator throws
        # ArgumentError("reducing over an empty collection is not allowed;
        # consider supplying `init` to the reducer") in Julia. Specimens with
        # zero temporal continuants (a perfectly normal, common state — most
        # specimens haven't grown any temporal identity continuants yet) used
        # to crash every single call to temporal_identity_status() (and thus
        # every specimen load, since load logs this status right after
        # restoring). Supplying init=0 makes the empty case correctly yield 0
        # instead of throwing, with identical behavior for the non-empty case.
        n_stages = sum((length(c.stages) for c in values(_CONTINUANTS)); init=0)
        n_prop_pending = count(p -> p.status == :pending, values(_PROPOSALS))
        n_prop_approved = count(p -> p.status == :approved, values(_PROPOSALS))
        n_prop_rejected = count(p -> p.status == :rejected, values(_PROPOSALS))
        avg_coherence = n_cont > 0 ? sum(c.coherence for c in values(_CONTINUANTS)) / n_cont : 0.0
        return Dict{String,Any}(
            "total_continuants" => n_cont,
            "total_stages"      => n_stages,
            "avg_coherence"     => round(avg_coherence; digits=3),
            "pending_proposals" => n_prop_pending,
            "approved_proposals"=> n_prop_approved,
            "rejected_proposals"=> n_prop_rejected
        )
    finally
        unlock(_PROPOSALS_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
end

# ── Serialization (for specimen save/load) ───────────────────────────────

function temporal_identity_to_dict()::Dict{String,Any}
    lock(_CONTINUANTS_LOCK)
    try
        continuants = Dict{String,Any}()
        for (cid, c) in _CONTINUANTS
            continuants[cid] = Dict{String,Any}(
                "id"             => c.id,
                "class"          => c.class,
                "coherence"      => c.coherence,
                "created_at"     => c.created_at,
                "last_updated"   => c.last_updated,
                "transform_rules"=> [Dict("from" => r[1], "to" => r[2]) for r in c.transform_rules],
                "stages"         => [Dict{String,Any}(
                    "node_id"     => s.node_id,
                    "phase"       => s.phase,
                    "orientation" => String(s.orientation),
                    "entered_at"  => s.entered_at
                ) for s in c.stages]
            )
        end
        # GRUG v9: Also serialize ContinuantProposals so they survive reload.
        proposals = lock(_PROPOSALS_LOCK) do
            [Dict{String,Any}(
                "id"               => p.id,
                "proposed_class"   => p.proposed_class,
                "proposed_stages"  => [Dict{String,Any}(
                    "node_id"     => s.node_id,
                    "phase"       => s.phase,
                    "orientation" => String(s.orientation),
                    "entered_at"  => s.entered_at
                ) for s in p.proposed_stages],
                "chain_coherence"  => p.chain_coherence,
                "example_triples"  => p.example_triples,
                "first_seen"       => p.first_seen,
                "last_seen"        => p.last_seen,
                "status"           => String(p.status)
            ) for p in values(_PROPOSALS)]
        end
        return Dict{String,Any}(
            "config"      => temporal_identity_config_to_dict(),
            "continuants" => continuants,
            "proposals"   => proposals
        )
    finally
        unlock(_CONTINUANTS_LOCK)
    end
end

function temporal_identity_from_dict!(d)
    # GRUG v9: Clear before restoring so we don't merge/duplicate with stale data.
    # (Phase 3 wipe should have already cleared us, but defense in depth.)
    lock(_CONTINUANTS_LOCK)
    lock(_NODE_INDEX_LOCK)
    try
        empty!(_NODE_INDEX)
        empty!(_CONTINUANTS)
    finally
        unlock(_NODE_INDEX_LOCK)
        unlock(_CONTINUANTS_LOCK)
    end
    lock(_PROPOSALS_LOCK)
    try
        empty!(_PROPOSALS)
    finally
        unlock(_PROPOSALS_LOCK)
    end
    # Restore config
    if haskey(d, "config")
        temporal_identity_config_from_dict!(d["config"])
    end
    # Restore continuants
    if haskey(d, "continuants") && isa(d["continuants"], Dict)
        lock(_CONTINUANTS_LOCK)
        lock(_NODE_INDEX_LOCK)
        try
            for (cid, cd) in d["continuants"]
                isa(cd, Dict) || continue
                stages = Stage[]
                if haskey(cd, "stages") && isa(cd["stages"], Vector)
                    for sd in cd["stages"]
                        isa(sd, Dict) || continue
                        orient_sym = Symbol(get(sd, "orientation", "now"))
                        push!(stages, Stage(
                            get(sd, "node_id", ""),
                            get(sd, "phase", ""),
                            orient_sym,
                            Float64(get(sd, "entered_at", 0.0))
                        ))
                    end
                end
                transform_rules = Tuple{String,String}[]
                if haskey(cd, "transform_rules") && isa(cd["transform_rules"], Vector)
                    for rd in cd["transform_rules"]
                        isa(rd, Dict) || continue
                        push!(transform_rules, (get(rd, "from", ""), get(rd, "to", "")))
                    end
                end
                c = Continuant(
                    get(cd, "id", cid),
                    get(cd, "class", ""),
                    stages,
                    Float64(get(cd, "coherence", 0.0)),
                    transform_rules,
                    Float64(get(cd, "created_at", 0.0)),
                    Float64(get(cd, "last_updated", 0.0))
                )
                _CONTINUANTS[cid] = c
                # Rebuild node index
                for s in c.stages
                    _NODE_INDEX[s.node_id] = cid
                end
            end
        finally
            unlock(_NODE_INDEX_LOCK)
            unlock(_CONTINUANTS_LOCK)
        end
    end
    # GRUG v9: Restore ContinuantProposals so they survive reload.
    if haskey(d, "proposals") && isa(d["proposals"], AbstractVector)
        lock(_PROPOSALS_LOCK)
        try
            for pd in d["proposals"]
                isa(pd, Dict) || continue
                proposed_stages = Stage[]
                if haskey(pd, "proposed_stages") && isa(pd["proposed_stages"], AbstractVector)
                    for sd in pd["proposed_stages"]
                        isa(sd, Dict) || continue
                        orient_sym = Symbol(get(sd, "orientation", "now"))
                        push!(proposed_stages, Stage(
                            get(sd, "node_id", ""),
                            get(sd, "phase", ""),
                            orient_sym,
                            Float64(get(sd, "entered_at", 0.0))
                        ))
                    end
                end
                p = ContinuantProposal(
                    String(get(pd, "id", "cp_0")),
                    String(get(pd, "proposed_class", "")),
                    proposed_stages,
                    Float64(get(pd, "chain_coherence", 0.0)),
                    String.(get(pd, "example_triples", String[])),
                    Float64(get(pd, "first_seen", 0.0)),
                    Float64(get(pd, "last_seen", 0.0)),
                    Symbol(get(pd, "status", "pending"))
                )
                _PROPOSALS[p.id] = p
                # Keep proposal counter ahead
                m = match(r"cp_(\d+)", p.id)
                if m !== nothing
                    n = parse(Int, m.captures[1])
                    if n >= _PROPOSAL_COUNTER[]
                        _PROPOSAL_COUNTER[] = n + 1
                    end
                end
            end
        finally
            unlock(_PROPOSALS_LOCK)
        end
    end
end

# ── Exports ─────────────────────────────────────────────────────────────

export Stage, Continuant, ContinuantProposal
export TemporalIdentityConfig, TEMPORAL_IDENTITY_CONFIG, temporal_identity_config_snapshot
export set_temporal_identity_config!, reset_temporal_identity_config!
export temporal_identity_config_to_dict, temporal_identity_config_from_dict!
export create_continuant, add_stage!, add_transform_rule!, remove_stage!
export identity_of, get_continuant, list_continuants, stages_of
export what_was, what_becomes
export merge_continuants!, delete_continuant!
export propose_continuant!, list_continuant_proposals
export approve_continuant_proposal!, reject_continuant_proposal!
export clear_continuants!, clear_proposals!
export temporal_identity_status
export temporal_identity_to_dict, temporal_identity_from_dict!

end # module TemporalIdentity
