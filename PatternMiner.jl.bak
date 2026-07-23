# PatternMiner.jl
# ==============================================================================
# v9 OPERATOR GENESIS — Self-discovery of new primitives from recurring graph
# shapes in the relational triple store.
# ==============================================================================
# Watches the triple store for recurring graph shapes (not just pair-level
# co-firing like RelationalGovernance, but structural motifs):
#   1. Transitivity: (A → R1 → B, B → R2 → C, A → R3 → C)
#   2. Chaining: (A → R → B) where (B → R → C) same verb chains
#   3. Symmetry: (A → R → B) and (B → R → A) co-occurring
#
# When a shape exceeds a threshold, the miner PROPOSES a new :relation sigil.
# Proposals go to a genesis queue — they are NOT auto-registered.
# The approval gate prevents junk sigils from noise.
#
# DESIGN CONSTRAINTS:
#   - Genesis is PROPOSED, not FORCED. Human or meta-cognitive loop approves.
#   - Thresholds default high (10 instances). Conservative.
#   - All state passed as parameters. No cross-module global references.
#   - Proposal/approval gate: queue is visible, nothing auto-registers.
# ==============================================================================

module PatternMiner

using Base.Threads: ReentrantLock

# ── Shape types ───────────────────────────────────────────────────────────────

@enum ShapeType begin
    SHAPE_TRANSITIVITY
    SHAPE_CHAINING
    SHAPE_SYMMETRY
end

const SHAPE_NAMES = Dict{ShapeType, String}(
    SHAPE_TRANSITIVITY => "transitivity",
    SHAPE_CHAINING     => "chaining",
    SHAPE_SYMMETRY     => "symmetry"
)

# ── Shape instance ────────────────────────────────────────────────────────────

struct ShapeInstance
    shape_type::ShapeType
    nodes::Vector{String}       # node IDs involved in this instance
    verbs::Vector{String}       # relation verbs involved
    timestamp::Float64
end

# ── Genesis proposal ───────────────────────────────────────────────────────────

mutable struct GenesisProposal
    id::String                           # unique proposal ID
    shape_type::ShapeType
    proposed_name::String                # e.g. "&transitive_causes"
    proposed_expansion::Vector{String}   # union of alternative verbs
    instance_count::Int                  # how many times this shape appeared
    example_triples::Vector{String}      # representative examples
    first_seen::Float64
    last_seen::Float64
    status::Symbol                       # :pending, :approved, :rejected
end

# ── Config ────────────────────────────────────────────────────────────────────

mutable struct PatternMinerConfig
    enabled::Bool
    transitivity_threshold::Int    # min instances before proposing
    chaining_threshold::Int
    symmetry_threshold::Int
    max_proposals::Int             # max proposals in queue
    scan_interval::Float64         # seconds between automatic scans (0 = manual only)
    instance_ttl::Float64          # seconds before old instances expire
end

const DEFAULT_PATTERN_MINER_CONFIG = PatternMinerConfig(
    true,           # enabled
    10,             # transitivity_threshold
    5,              # chaining_threshold
    5,              # symmetry_threshold
    50,             # max_proposals
    0.0,            # scan_interval (manual only by default)
    3600.0          # instance_ttl (1 hour)
)

const PATTERN_MINER_CONFIG = Ref{PatternMinerConfig}(deepcopy(DEFAULT_PATTERN_MINER_CONFIG))
const _CONFIG_LOCK = ReentrantLock()

# ── State ─────────────────────────────────────────────────────────────────────

const _INSTANCES = Vector{ShapeInstance}()
const _INSTANCES_LOCK = ReentrantLock()

const _PROPOSALS = Dict{String, GenesisProposal}()
const _PROPOSALS_LOCK = ReentrantLock()

let
    global _next_proposal_id = Ref{Int}(1)
end

function _new_proposal_id()::String
    id = _next_proposal_id[]
    _next_proposal_id[] += 1
    return "pm_proposal_$(id)"
end

# ── Config access ─────────────────────────────────────────────────────────────

function pattern_miner_config_snapshot()::PatternMinerConfig
    lock(_CONFIG_LOCK) do
        deepcopy(PATTERN_MINER_CONFIG[])
    end
end

function set_pattern_miner_config!(key::Symbol, value)
    lock(_CONFIG_LOCK) do
        cfg = PATTERN_MINER_CONFIG[]
        if key === :enabled
            cfg.enabled = Bool(value)
        elseif key === :transitivity_threshold
            cfg.transitivity_threshold = max(1, Int(value))
        elseif key === :chaining_threshold
            cfg.chaining_threshold = max(1, Int(value))
        elseif key === :symmetry_threshold
            cfg.symmetry_threshold = max(1, Int(value))
        elseif key === :max_proposals
            cfg.max_proposals = max(1, Int(value))
        elseif key === :scan_interval
            cfg.scan_interval = max(0.0, Float64(value))
        elseif key === :instance_ttl
            cfg.instance_ttl = max(60.0, Float64(value))
        else
            error("unknown PatternMiner config key :$key")
        end
    end
    return nothing
end

function reset_pattern_miner_config!()
    lock(_CONFIG_LOCK) do
        PATTERN_MINER_CONFIG[] = deepcopy(DEFAULT_PATTERN_MINER_CONFIG)
    end
    return nothing
end

# ── Serialization ─────────────────────────────────────────────────────────────

function pattern_miner_config_to_dict()::Dict{String,Any}
    cfg = lock(_CONFIG_LOCK) do; PATTERN_MINER_CONFIG[] end
    return Dict{String,Any}(
        "enabled"               => cfg.enabled,
        "transitivity_threshold" => cfg.transitivity_threshold,
        "chaining_threshold"     => cfg.chaining_threshold,
        "symmetry_threshold"     => cfg.symmetry_threshold,
        "max_proposals"          => cfg.max_proposals,
        "scan_interval"         => cfg.scan_interval,
        "instance_ttl"           => cfg.instance_ttl
    )
end

function pattern_miner_config_from_dict!(d)
    haskey(d, "enabled")                && set_pattern_miner_config!(:enabled, Bool(d["enabled"]))
    haskey(d, "transitivity_threshold") && set_pattern_miner_config!(:transitivity_threshold, Int(d["transitivity_threshold"]))
    haskey(d, "chaining_threshold")     && set_pattern_miner_config!(:chaining_threshold, Int(d["chaining_threshold"]))
    haskey(d, "symmetry_threshold")     && set_pattern_miner_config!(:symmetry_threshold, Int(d["symmetry_threshold"]))
    haskey(d, "max_proposals")          && set_pattern_miner_config!(:max_proposals, Int(d["max_proposals"]))
    haskey(d, "scan_interval")          && set_pattern_miner_config!(:scan_interval, Float64(d["scan_interval"]))
    haskey(d, "instance_ttl")           && set_pattern_miner_config!(:instance_ttl, Float64(d["instance_ttl"]))
    return nothing
end

# ── Instance management ───────────────────────────────────────────────────────

"""
    record_instance!(shape_type, nodes, verbs)

Record a detected shape instance. Called by the scan functions when a
pattern is found in the triple store.
"""
function record_instance!(shape_type::ShapeType, nodes::Vector{String},
                          verbs::Vector{String})
    inst = ShapeInstance(shape_type, nodes, verbs, time())
    lock(_INSTANCES_LOCK) do
        push!(_INSTANCES, inst)
    end
    return nothing
end

"""
    prune_expired_instances!()

Remove instances older than instance_ttl seconds.
"""
function prune_expired_instances!()
    cfg = pattern_miner_config_snapshot()
    cutoff = time() - cfg.instance_ttl
    lock(_INSTANCES_LOCK) do
        filter!(inst -> inst.timestamp >= cutoff, _INSTANCES)
    end
    return nothing
end

"""
    count_instances(shape_type) -> Int

Count how many instances of a given shape type are currently recorded.
"""
function count_instances(shape_type::ShapeType)::Int
    lock(_INSTANCES_LOCK) do
        count(inst -> inst.shape_type === shape_type, _INSTANCES)
    end
end

"""
    get_all_instances() -> Vector{ShapeInstance}

Return a copy of all recorded instances.
"""
function get_all_instances()::Vector{ShapeInstance}
    lock(_INSTANCES_LOCK) do
        copy(_INSTANCES)
    end
end

# ── Shape scanning ────────────────────────────────────────────────────────────
#
# These functions walk the triple store (passed as parameters) and detect
# recurring graph shapes. They do NOT auto-register anything — they just
# record instances. The proposal step is separate.

"""
    scan_transitivity!(relational_triples) -> Int

Walk the triple store looking for transitivity patterns:
(A → R1 → B, B → R2 → C, A → R3 → C) where R1, R2, R3 share a
semantic class. Returns the number of new instances found.

`relational_triples` is a vector of (subject_id, verb, object_id) tuples.
"""
function scan_transitivity!(relational_triples::Vector{Tuple{String,String,String}})::Int
    cfg = pattern_miner_config_snapshot()
    if !cfg.enabled
        return 0
    end

    # Group triples by subject and object for fast lookup
    by_subject = Dict{String, Vector{Tuple{String,String}}}()
    by_object  = Dict{String, Vector{Tuple{String,String}}}()
    for (subj, verb, obj) in relational_triples
        push!(get!(by_subject, subj, Tuple{String,String}[]), (verb, obj))
        push!(get!(by_object, obj, Tuple{String,String}[]), (verb, subj))
    end

    new_count = 0
    # For each triple (A → R1 → B), check if B has outgoing triples
    # (B → R2 → C) and A has a direct triple (A → R3 → C)
    for (a_id, r1, b_id) in relational_triples
        b_outgoing = get(by_subject, b_id, Tuple{String,String}[])
        a_outgoing = get(by_subject, a_id, Tuple{String,String}[])
        for (r2, c_id) in b_outgoing
            # Check if A has a direct link to C
            for (r3, c2_id) in a_outgoing
                if c2_id == c_id
                    # Found transitivity: A→R1→B, B→R2→C, A→R3→C
                    record_instance!(SHAPE_TRANSITIVITY,
                                   [a_id, b_id, c_id],
                                   [r1, r2, r3])
                    new_count += 1
                    break  # one match per (A, B, C) is enough
                end
            end
        end
    end
    return new_count
end

"""
    scan_chaining!(relational_triples) -> Int

Walk the triple store looking for chaining patterns:
(A → R → B) where (B → R → C) — same verb R chains.
Returns the number of new instances found.
"""
function scan_chaining!(relational_triples::Vector{Tuple{String,String,String}})::Int
    cfg = pattern_miner_config_snapshot()
    if !cfg.enabled
        return 0
    end

    # Group triples by verb
    by_verb = Dict{String, Vector{Tuple{String,String}}}()
    for (subj, verb, obj) in relational_triples
        push!(get!(by_verb, verb, Tuple{String,String}[]), (subj, obj))
    end

    new_count = 0
    for (verb, pairs) in by_verb
        # Check for chains: A→verb→B and B→verb→C
        obj_set = Set(p[2] for p in pairs)
        for (a_id, b_id) in pairs
            if b_id in obj_set
                # b_id is both an object (of A→verb→B) and a subject
                # Find C where B→verb→C
                for (subj2, obj2) in pairs
                    if subj2 == b_id
                        record_instance!(SHAPE_CHAINING,
                                       [a_id, b_id, obj2],
                                       [verb])
                        new_count += 1
                    end
                end
            end
        end
    end
    return new_count
end

"""
    scan_symmetry!(relational_triples) -> Int

Walk the triple store looking for symmetry patterns:
(A → R → B) and (B → R → A) co-occurring.
Returns the number of new instances found.
"""
function scan_symmetry!(relational_triples::Vector{Tuple{String,String,String}})::Int
    cfg = pattern_miner_config_snapshot()
    if !cfg.enabled
        return 0
    end

    # Build a set of (A, verb, B) for fast reverse lookup
    triple_set = Set((subj, verb, obj) for (subj, verb, obj) in relational_triples)

    new_count = 0
    seen = Set{Tuple{String,String}}()
    for (a_id, verb, b_id) in relational_triples
        pair = minmax(a_id, b_id)
        if pair ∉ seen && (b_id, verb, a_id) in triple_set
            record_instance!(SHAPE_SYMMETRY,
                           [a_id, b_id],
                           [verb])
            new_count += 1
            push!(seen, pair)
        end
    end
    return new_count
end

"""
    scan_all!(relational_triples) -> Dict{String,Int}

Run all shape scanners and return a summary of new instances found.
"""
function scan_all!(relational_triples::Vector{Tuple{String,String,String}})::Dict{String,Int}
    prune_expired_instances!()
    n_trans = scan_transitivity!(relational_triples)
    n_chain = scan_chaining!(relational_triples)
    n_sym   = scan_symmetry!(relational_triples)
    return Dict{String,Int}(
        "transitivity" => n_trans,
        "chaining"     => n_chain,
        "symmetry"     => n_sym
    )
end

# ── Proposal management ───────────────────────────────────────────────────────

"""
    check_and_propose!() -> Vector{GenesisProposal}

Check if any shape type has enough instances to warrant a proposal.
If so, create a GenesisProposal and add it to the queue.
Returns the newly created proposals (if any).
"""
function check_and_propose!()::Vector{GenesisProposal}
    cfg = pattern_miner_config_snapshot()
    if !cfg.enabled
        return GenesisProposal[]
    end

    new_proposals = GenesisProposal[]

    # Check transitivity
    n_trans = count_instances(SHAPE_TRANSITIVITY)
    if n_trans >= cfg.transitivity_threshold
        # Gather the verbs from transitivity instances
        instances = get_all_instances()
        trans_inst = filter(inst -> inst.shape_type === SHAPE_TRANSITIVITY, instances)
        all_verbs = sort(unique(vcat([inst.verbs for inst in trans_inst]...)))
        prop_name = "&transitive_$(replace(all_verbs[1], " " => "_"))"
        prop = GenesisProposal(
            _new_proposal_id(),
            SHAPE_TRANSITIVITY,
            prop_name,
            all_verbs,
            n_trans,
            ["$(inst.nodes[1]) → $(inst.verbs[1]) → $(inst.nodes[2]) → $(inst.verbs[2]) → $(inst.nodes[3])"
             for inst in trans_inst[1:min(3, length(trans_inst))]],
            minimum(inst.timestamp for inst in trans_inst),
            maximum(inst.timestamp for inst in trans_inst),
            :pending
        )
        lock(_PROPOSALS_LOCK) do
            if length(_PROPOSALS) < cfg.max_proposals
                _PROPOSALS[prop.id] = prop
                push!(new_proposals, prop)
            end
        end
    end

    # Check chaining
    n_chain = count_instances(SHAPE_CHAINING)
    if n_chain >= cfg.chaining_threshold
        instances = get_all_instances()
        chain_inst = filter(inst -> inst.shape_type === SHAPE_CHAINING, instances)
        all_verbs = sort(unique(vcat([inst.verbs for inst in chain_inst]...)))
        prop_name = "&chain_$(replace(all_verbs[1], " " => "_"))"
        prop = GenesisProposal(
            _new_proposal_id(),
            SHAPE_CHAINING,
            prop_name,
            all_verbs,
            n_chain,
            ["$(inst.nodes[1]) → $(inst.verbs[1]) → $(inst.nodes[2]) → $(inst.verbs[1]) → $(inst.nodes[3])"
             for inst in chain_inst[1:min(3, length(chain_inst))]],
            minimum(inst.timestamp for inst in chain_inst),
            maximum(inst.timestamp for inst in chain_inst),
            :pending
        )
        lock(_PROPOSALS_LOCK) do
            if length(_PROPOSALS) < cfg.max_proposals
                _PROPOSALS[prop.id] = prop
                push!(new_proposals, prop)
            end
        end
    end

    # Check symmetry
    n_sym = count_instances(SHAPE_SYMMETRY)
    if n_sym >= cfg.symmetry_threshold
        instances = get_all_instances()
        sym_inst = filter(inst -> inst.shape_type === SHAPE_SYMMETRY, instances)
        all_verbs = sort(unique(vcat([inst.verbs for inst in sym_inst]...)))
        prop_name = "&symmetric_$(replace(all_verbs[1], " " => "_"))"
        prop = GenesisProposal(
            _new_proposal_id(),
            SHAPE_SYMMETRY,
            prop_name,
            all_verbs,
            n_sym,
            ["$(inst.nodes[1]) ↔ $(inst.verbs[1]) ↔ $(inst.nodes[2])"
             for inst in sym_inst[1:min(3, length(sym_inst))]],
            minimum(inst.timestamp for inst in sym_inst),
            maximum(inst.timestamp for inst in sym_inst),
            :pending
        )
        lock(_PROPOSALS_LOCK) do
            if length(_PROPOSALS) < cfg.max_proposals
                _PROPOSALS[prop.id] = prop
                push!(new_proposals, prop)
            end
        end
    end

    return new_proposals
end

"""
    list_proposals(; status::Union{Nothing,Symbol}=nothing) -> Vector{GenesisProposal}

List all proposals, optionally filtered by status (:pending, :approved, :rejected).
"""
function list_proposals(; status::Union{Nothing,Symbol}=nothing)::Vector{GenesisProposal}
    lock(_PROPOSALS_LOCK) do
        props = collect(values(_PROPOSALS))
        if status !== nothing
            filter!(p -> p.status === status, props)
        end
        sort!(props; by=p -> p.first_seen)
        return props
    end
end

"""
    approve_proposal!(proposal_id::String) -> Union{GenesisProposal, Nothing}

Mark a proposal as approved. The caller (Main.jl) then calls
register_relation_sigil! to actually mint the sigil. Returns the
approved proposal, or nothing if not found.
"""
function approve_proposal!(proposal_id::String)::Union{GenesisProposal, Nothing}
    lock(_PROPOSALS_LOCK) do
        if haskey(_PROPOSALS, proposal_id)
            prop = _PROPOSALS[proposal_id]
            prop.status = :approved
            return prop
        end
    end
    return nothing
end

"""
    reject_proposal!(proposal_id::String) -> Union{GenesisProposal, Nothing}

Mark a proposal as rejected. The shape's instance count is NOT reset —
the shape might warrant re-proposal later with more data.
"""
function reject_proposal!(proposal_id::String)::Union{GenesisProposal, Nothing}
    lock(_PROPOSALS_LOCK) do
        if haskey(_PROPOSALS, proposal_id)
            prop = _PROPOSALS[proposal_id]
            prop.status = :rejected
            return prop
        end
    end
    return nothing
end

"""
    clear_instances!()

Clear all recorded instances. Useful for testing or after a proposal cycle.
"""
function clear_instances!()
    lock(_INSTANCES_LOCK) do
        empty!(_INSTANCES)
    end
    return nothing
end

"""
    clear_proposals!()

Clear all proposals. Useful for testing.
"""
function clear_proposals!()
    lock(_PROPOSALS_LOCK) do
        empty!(_PROPOSALS)
    end
    return nothing
end

"""
    pattern_miner_status() -> Dict{String,Any}

Return a summary of the PatternMiner state for display.
"""
function pattern_miner_status()::Dict{String,Any}
    cfg = pattern_miner_config_snapshot()
    n_pending = length(list_proposals(; status=:pending))
    n_approved = length(list_proposals(; status=:approved))
    n_rejected = length(list_proposals(; status=:rejected))
    return Dict{String,Any}(
        "enabled"               => cfg.enabled,
        "transitivity_threshold" => cfg.transitivity_threshold,
        "chaining_threshold"     => cfg.chaining_threshold,
        "symmetry_threshold"     => cfg.symmetry_threshold,
        "instances" => Dict{String,Int}(
            "transitivity" => count_instances(SHAPE_TRANSITIVITY),
            "chaining"     => count_instances(SHAPE_CHAINING),
            "symmetry"     => count_instances(SHAPE_SYMMETRY)
        ),
        "proposals" => Dict{String,Int}(
            "pending"  => n_pending,
            "approved" => n_approved,
            "rejected" => n_rejected
        )
    )
end

# ── Exports ───────────────────────────────────────────────────────────────────

export ShapeType, SHAPE_TRANSITIVITY, SHAPE_CHAINING, SHAPE_SYMMETRY
export SHAPE_NAMES
export ShapeInstance, GenesisProposal
export PatternMinerConfig, PATTERN_MINER_CONFIG, pattern_miner_config_snapshot
export set_pattern_miner_config!, reset_pattern_miner_config!
export pattern_miner_config_to_dict, pattern_miner_config_from_dict!
export record_instance!, prune_expired_instances!, count_instances, get_all_instances
export scan_transitivity!, scan_chaining!, scan_symmetry!, scan_all!
export check_and_propose!, list_proposals
export approve_proposal!, reject_proposal!
export clear_instances!, clear_proposals!
export pattern_miner_status

# ── Serialization: instances + proposals (v9 hook) ──────────────────────────
# GRUG v9: Save/restore PatternMiner instances and proposals so they survive
# specimen save/load. Without this, a reload loses all shape instances and
# genesis proposals — the miner has to start from scratch every boot.

"""
    pattern_miner_data_to_dict() -> Dict{String,Any}

Serialize all ShapeInstances and GenesisProposals to a Dict for specimen storage.
"""
function pattern_miner_data_to_dict()::Dict{String,Any}
    instances = lock(_INSTANCES_LOCK) do
        [Dict{String,Any}(
            "shape_type" => String(SHAPE_NAMES[inst.shape_type]),
            "nodes"      => inst.nodes,
            "verbs"      => inst.verbs,
            "timestamp"  => inst.timestamp
        ) for inst in _INSTANCES]
    end
    proposals = lock(_PROPOSALS_LOCK) do
        [Dict{String,Any}(
            "id"                 => p.id,
            "shape_type"         => String(SHAPE_NAMES[p.shape_type]),
            "proposed_name"      => p.proposed_name,
            "proposed_expansion" => p.proposed_expansion,
            "instance_count"     => p.instance_count,
            "example_triples"    => p.example_triples,
            "first_seen"         => p.first_seen,
            "last_seen"          => p.last_seen,
            "status"             => String(p.status)
        ) for p in values(_PROPOSALS)]
    end
    return Dict{String,Any}(
        "instances" => instances,
        "proposals" => proposals
    )
end

"""
    pattern_miner_data_from_dict!(d)

Restore ShapeInstances and GenesisProposals from a specimen Dict.
"""
function pattern_miner_data_from_dict!(d)
    # GRUG v9: Clear before restoring so we don't merge/duplicate with stale data.
    lock(_INSTANCES_LOCK) do; empty!(_INSTANCES); end
    lock(_PROPOSALS_LOCK) do; empty!(_PROPOSALS); end
    # Restore instances
    if haskey(d, "instances") && isa(d["instances"], AbstractVector)
        lock(_INSTANCES_LOCK) do
            for inst_d in d["instances"]
                isa(inst_d, Dict) || continue
                shape_str = get(inst_d, "shape_type", "transitivity")
                shape_type = shape_str == "chaining" ? SHAPE_CHAINING :
                             shape_str == "symmetry"  ? SHAPE_SYMMETRY :
                             SHAPE_TRANSITIVITY
                nodes = String.(get(inst_d, "nodes", String[]))
                verbs = String.(get(inst_d, "verbs", String[]))
                ts    = Float64(get(inst_d, "timestamp", 0.0))
                push!(_INSTANCES, ShapeInstance(shape_type, nodes, verbs, ts))
            end
        end
    end
    # Restore proposals
    if haskey(d, "proposals") && isa(d["proposals"], AbstractVector)
        lock(_PROPOSALS_LOCK) do
            for prop_d in d["proposals"]
                isa(prop_d, Dict) || continue
                shape_str = get(prop_d, "shape_type", "transitivity")
                shape_type = shape_str == "chaining" ? SHAPE_CHAINING :
                             shape_str == "symmetry"  ? SHAPE_SYMMETRY :
                             SHAPE_TRANSITIVITY
                p = GenesisProposal(
                    String(get(prop_d, "id", "gp_0")),
                    shape_type,
                    String(get(prop_d, "proposed_name", "")),
                    String.(get(prop_d, "proposed_expansion", String[])),
                    Int(get(prop_d, "instance_count", 0)),
                    String.(get(prop_d, "example_triples", String[])),
                    Float64(get(prop_d, "first_seen", 0.0)),
                    Float64(get(prop_d, "last_seen", 0.0)),
                    Symbol(get(prop_d, "status", "pending"))
                )
                _PROPOSALS[p.id] = p
                # Keep proposal counter ahead of loaded IDs
                m = match(r"gp_(\d+)", p.id)
                if m !== nothing
                    n = parse(Int, m.captures[1])
                    if n >= _next_proposal_id[]
                        _next_proposal_id[] = n + 1
                    end
                end
            end
        end
    end
    return nothing
end

export pattern_miner_data_to_dict, pattern_miner_data_from_dict!

end # module PatternMiner
