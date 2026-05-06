# FullLobeScanner.jl - GRUG Full-Lobe Scanning System
# GRUG say: This scan WHOLE lobe. Not just peek. ALL rocks get look.
# GRUG say: But not all rocks at once! Only 1000 lit up at time.
# GRUG say: Scan complete = DONE signal. Then AIML can talk.
# GRUG say: NO SILENT FAILURES. If something wrong, GRUG SCREAM LOUD!

module FullLobeScanner

# GRUG: Need random for coinflip mechanics (like rest of GrugBot)
using Random

# ==============================================================================
# 1. STRICT ERROR HANDLING (NO SILENT FAILURES)
# ==============================================================================
# GRUG: Grug no like quiet failures. If brain break, Grug scream loud!

abstract type AbstractScannerError <: Exception end

"""
Thrown when scanner inputs are invalid (empty lobe, bad config, etc.).
"""
struct FullLobeScanError <: AbstractScannerError
    msg::String
    context::String
end

"""
Thrown when scan cannot find any matches within threshold limits.
Includes the highest confidence found for debug visibility.
"""
struct NoMatchFoundError <: AbstractScannerError
    msg::String
    highest_confidence::Float64
    nodes_scanned::Int
end

Base.showerror(io::IO, e::FullLobeScanError) = 
    print(io, "FullLobeScanError: ", e.msg, " [", e.context, "]")
Base.showerror(io::IO, e::NoMatchFoundError) = 
    print(io, "NoMatchFoundError: ", e.msg, " (highest_conf=", round(e.highest_confidence, digits=4), ", scanned=", e.nodes_scanned, ")")

function throw_scan_error(msg::String, ctx::String = "unknown")
    throw(FullLobeScanError(msg, ctx))
end

# ==============================================================================
# 2. CONSTANTS - GRUG like numbers in one place
# ==============================================================================

const MAX_ACTIVE_NODES = 1000      # GRUG: Max nodes lit up at once
const DEFAULT_THREADS = 4          # GRUG: Default thread count
const MAX_THREADS = 8              # GRUG: Max threads allowed
const CONFIDENT_THRESHOLD = 0.75   # GRUG: When match is "good enough"
const DEFAULT_CANDIDATE_THRESHOLD = 0.3  # GRUG: Minimum to be candidate
const MAX_CONTINUE_CYCLES = 10     # GRUG: Max spread cycles

# ==============================================================================
# 3. MATCH TYPES - Pattern and Semantic
# ==============================================================================
# GRUG say: Two kinds of matches:
#            1. PATTERN MATCH - Direct, like seeing same rock shape
#            2. SEMANTIC MATCH - Indirect, like knowing rock is for smashing

abstract type AbstractMatch end

"""
PatternMatch: Direct feature correlation match.
GRUG: This rock look like query rock. Same shape, same color.
"""
struct PatternMatch <: AbstractMatch
    node_id::String                   # GRUG: Which node matched
    confidence::Float64               # GRUG: How sure? (0.0 to 1.0)
    matched_features::Vector{Int}     # GRUG: Which features matched
    match_strength::Float64           # GRUG: Raw similarity score
    
    function PatternMatch(node_id::String, confidence::Float64, 
                          features::Vector{Int}, strength::Float64)
        if confidence < 0.0 || confidence > 1.0
            throw_scan_error("Confidence must be in [0,1], got $confidence", "PatternMatch")
        end
        if isempty(strip(node_id))
            throw_scan_error("Node ID cannot be empty", "PatternMatch")
        end
        new(node_id, confidence, features, strength)
    end
end

"""
SemanticMatch: Indirect topology/attractor-based match.
GRUG: This rock connected to query rock through friend network.
"""
struct SemanticMatch <: AbstractMatch
    node_id::String                   # GRUG: Which node matched
    confidence::Float64               # GRUG: How sure?
    attractor_id::Int                 # GRUG: Which semantic attractor
    hopfield_energy::Float64          # GRUG: Energy in attractor basin
    topology_distance::Float64        # GRUG: Distance in semantic space
    
    function SemanticMatch(node_id::String, confidence::Float64,
                           attractor::Int, energy::Float64, topo_dist::Float64)
        if confidence < 0.0 || confidence > 1.0
            throw_scan_error("Confidence must be in [0,1], got $confidence", "SemanticMatch")
        end
        if isempty(strip(node_id))
            throw_scan_error("Node ID cannot be empty", "SemanticMatch")
        end
        new(node_id, confidence, attractor, energy, topo_dist)
    end
end

# ==============================================================================
# 4. ACTIVE NODE SET - Bounded Activation Management
# ==============================================================================
# GRUG: Can't have all nodes active at once. Brain would explode.
#       This keeps track of which nodes are "lit up" right now.
#       Max 1000 active at any time. Enforced HARD.

mutable struct ActiveNodeSet
    active_ids::Set{String}           # GRUG: Currently active node IDs
    activation_order::Vector{String}  # GRUG: Order of activation (for eviction)
    activations::Dict{String, Float64}# GRUG: Activation level per node
    max_size::Int                     # GRUG: Hard limit on active nodes
    
    function ActiveNodeSet(max_size::Int = MAX_ACTIVE_NODES)
        if max_size < 1
            throw_scan_error("max_size must be positive, got $max_size", "ActiveNodeSet")
        end
        if max_size > MAX_ACTIVE_NODES
            throw_scan_error("max_size $max_size exceeds system limit $MAX_ACTIVE_NODES", "ActiveNodeSet")
        end
        new(Set{String}(), String[], Dict{String, Float64}(), max_size)
    end
end

# GRUG: Check if node is active
function is_active(ans::ActiveNodeSet, node_id::String)::Bool
    return node_id in ans.active_ids
end

# GRUG: Get current active count
function active_count(ans::ActiveNodeSet)::Int
    return length(ans.active_ids)
end

# GRUG: Check if at capacity
function at_capacity(ans::ActiveNodeSet)::Bool
    return length(ans.active_ids) >= ans.max_size
end

# GRUG: Activate a node. If at capacity, evict oldest.
#       Returns true if newly activated, false if already active.
function activate_node!(ans::ActiveNodeSet, node_id::String, level::Float64 = 1.0)::Bool
    if isempty(strip(node_id))
        throw_scan_error("Cannot activate empty node_id", "activate_node!")
    end
    if level < 0.0 || level > 1.0
        throw_scan_error("Activation level must be in [0,1], got $level", "activate_node!")
    end
    
    # Already active? Just update level.
    if node_id in ans.active_ids
        ans.activations[node_id] = level
        return false
    end
    
    # At capacity? Evict oldest (first-in-first-out).
    if at_capacity(ans)
        evicted = popfirst!(ans.activation_order)
        delete!(ans.active_ids, evicted)
        delete!(ans.activations, evicted)
    end
    
    # Add new active node
    push!(ans.active_ids, node_id)
    push!(ans.activation_order, node_id)
    ans.activations[node_id] = level
    return true
end

# GRUG: Deactivate a specific node. SCREAM if not active!
function deactivate_node!(ans::ActiveNodeSet, node_id::String)
    if !(node_id in ans.active_ids)
        throw_scan_error("Cannot deactivate '$node_id' - not currently active", "deactivate_node!")
    end
    delete!(ans.active_ids, node_id)
    filter!(id -> id != node_id, ans.activation_order)
    delete!(ans.activations, node_id)
end

# GRUG: Clear all active nodes
function clear_active!(ans::ActiveNodeSet)
    empty!(ans.active_ids)
    empty!(ans.activation_order)
    empty!(ans.activations)
end

# ==============================================================================
# 5. SCAN PHASES - The Brain States
# ==============================================================================
# GRUG: Scanning happens in phases. Like sleep stages but for thinking.
#       Each phase does different thing. Must follow order.

@enum ScanPhase begin
    PHASE_INIT          # GRUG: Getting ready to scan
    PHASE_GATHER        # GRUG: Collecting candidate nodes
    PHASE_ACTIVATE      # GRUG: Turning on the best candidates
    PHASE_CONTINUE      # GRUG: Keep scanning from active nodes
    PHASE_DONE          # GRUG: Scan complete, ready for AIML
end

function phase_name(phase::ScanPhase)::String
    names = Dict(
        PHASE_INIT => "INITIALIZATION",
        PHASE_GATHER => "CANDIDATE_GATHERING",
        PHASE_ACTIVATE => "ACTIVATION",
        PHASE_CONTINUE => "CONTINUED_SCAN",
        PHASE_DONE => "DONE"
    )
    return get(names, phase, "UNKNOWN")
end

# ==============================================================================
# 6. SCAN RESULT - What the scan found
# ==============================================================================

struct ScanResult
    matches::Vector{AbstractMatch}   # GRUG: All matches found
    pattern_matches::Int             # GRUG: Count of pattern matches
    semantic_matches::Int            # GRUG: Count of semantic matches
    nodes_scanned::Int               # GRUG: How many nodes we looked at
    scan_cycles::Int                 # GRUG: How many scan cycles
    final_phase::ScanPhase           # GRUG: Where did we end up?
    confident_matches::Int           # GRUG: How many confident matches
    done_signal::Bool                # GRUG: Was DONE signal emitted?
    scan_time_seconds::Float64       # GRUG: How long did it take?
    
    function ScanResult(matches::Vector{AbstractMatch}, pattern_count::Int, 
                        semantic_count::Int, scanned::Int, cycles::Int, 
                        phase::ScanPhase, confident::Int, done::Bool, time_sec::Float64)
        new(matches, pattern_count, semantic_count, scanned, cycles, phase, confident, done, time_sec)
    end
end

# ==============================================================================
# 7. LOBE SCANNER - The Main Brain
# ==============================================================================
# GRUG: This is the scanner that runs through a lobe and finds matches.
#       It uses multiple threads to scan faster.
#       NO AIML until DONE signal. IMPORTANT!

mutable struct LobeScanner
    lobe_id::String                  # GRUG: The lobe to scan
    phase::ScanPhase                 # GRUG: Current phase
    candidates::Vector{String}       # GRUG: Candidate node IDs
    matches::Vector{AbstractMatch}   # GRUG: All matches found
    pattern_count::Int               # GRUG: Pattern match count
    semantic_count::Int              # GRUG: Semantic match count
    scan_cycle::Int                  # GRUG: Current scan cycle
    num_threads::Int                 # GRUG: Number of threads to use
    query_features::Vector{Float64}  # GRUG: What we're looking for
    confident_count::Int             # GRUG: Count of confident matches
    done_emitted::Bool               # GRUG: Has DONE signal been emitted?
    aiml_ready::Bool                 # GRUG: Is AIML allowed to respond?
    active_set::ActiveNodeSet        # GRUG: Active node management
    attractors::Dict{Int, Vector{Float64}}  # GRUG: Semantic attractor centers
    start_time::Float64              # GRUG: When scan started
    
    function LobeScanner(lobe_id::String, num_threads::Int = DEFAULT_THREADS)
        if isempty(strip(lobe_id))
            throw_scan_error("lobe_id cannot be empty", "LobeScanner")
        end
        if num_threads < 1
            throw_scan_error("Must have at least 1 thread, got $num_threads", "LobeScanner")
        end
        if num_threads > MAX_THREADS
            throw_scan_error("Max threads is $MAX_THREADS, got $num_threads", "LobeScanner")
        end
        new(lobe_id, PHASE_INIT, String[], AbstractMatch[], 0, 0, 0, 
            num_threads, Float64[], 0, false, false, ActiveNodeSet(),
            Dict{Int, Vector{Float64}}(), 0.0)
    end
end

# ==============================================================================
# 8. VALIDATION HELPERS
# ==============================================================================
# GRUG: Check everything before scanning. No silent failures!

function _require_nodes!(node_ids::Set{String})
    if isempty(node_ids)
        throw_scan_error("Lobe has no nodes. Nothing to scan.", "_require_nodes!")
    end
end

function _require_query_features!(features::Vector{Float64})
    if isempty(features)
        throw_scan_error("No query features set. What is GrugBot looking for?", "_require_query_features!")
    end
end

function _require_not_done!(scanner::LobeScanner)
    if scanner.done_emitted
        throw_scan_error("Scan is DONE. Cannot continue scanning. Start a new scan instead.", "_require_not_done!")
    end
end

function _require_phase!(scanner::LobeScanner, expected::ScanPhase)
    if scanner.phase != expected
        throw_scan_error(
            "Wrong phase. Expected $(phase_name(expected)) but in $(phase_name(scanner.phase))",
            "_require_phase!"
        )
    end
end

# ==============================================================================
# 9. QUERY SETUP
# ==============================================================================
# GRUG: Set what we're looking for. Must be done before scanning.

function set_query!(scanner::LobeScanner, features::Vector{Float64})
    _require_not_done!(scanner)
    if scanner.phase != PHASE_INIT
        throw_scan_error(
            "Cannot set query in $(phase_name(scanner.phase)) phase. Must be in INIT phase.",
            "set_query!"
        )
    end
    if isempty(features)
        throw_scan_error("Query features cannot be empty.", "set_query!")
    end
    
    scanner.query_features = copy(features)
    scanner.phase = PHASE_GATHER  # GRUG: Ready to gather candidates
    scanner.start_time = time()
    println("🧠 GRUG: Query set. Ready to scan lobe '$(scanner.lobe_id)' for matching patterns.")
end

# ==============================================================================
# 10. SIMILARITY COMPUTATION
# ==============================================================================
# GRUG: How similar are two feature vectors? Cosine similarity.

function _compute_similarity(a::Vector{Float64}, b::Vector{Float64})::Float64
    if length(a) != length(b)
        # GRUG: Different length vectors = pad shorter one with zeros
        max_len = max(length(a), length(b))
        a_padded = vcat(a, zeros(max_len - length(a)))
        b_padded = vcat(b, zeros(max_len - length(b)))
        return _cosine_similarity(a_padded, b_padded)
    end
    return _cosine_similarity(a, b)
end

function _cosine_similarity(a::Vector{Float64}, b::Vector{Float64})::Float64
    norm_a = sqrt(sum(x -> x^2, a))
    norm_b = sqrt(sum(x -> x^2, b))
    
    if norm_a < 1e-12 || norm_b < 1e-12
        return 0.0  # GRUG: Zero vector = no similarity
    end
    
    dot_product = sum(a .* b)
    return dot_product / (norm_a * norm_b)
end

# ==============================================================================
# 11. JITTER - Same pattern as PatternScanner
# ==============================================================================
# GRUG: Perfect bullseye is fake! Nature always shakes.
# GRUG: Unlike PatternScanner which allows [-1, 1] for signed similarity,
#       FullLobeScanner confidences are always [0, 1] (probability-style).
#       Clamp to [0, 1] here so downstream code never sees negative confidence.

function slight_jitter(confidence::Float64)::Float64
    jitter_magnitude = 0.005 + (0.01 * (1.0 - abs(confidence)))
    jitter = (rand() * 2.0 - 1.0) * jitter_magnitude
    return clamp(confidence + jitter, 0.0, 1.0)
end

# ==============================================================================
# 12. PHASE 1: CANDIDATE GATHERING (MULTITHREADED)
# ==============================================================================
# GRUG: Go through all nodes and find candidates that might match.
#       Uses multithreading for speed. Static chunking.

function gather_candidates!(scanner::LobeScanner, node_features::Dict{String, Vector{Float64}}; 
                            threshold::Float64 = DEFAULT_CANDIDATE_THRESHOLD,
                            nonjitter_ids::Set{String} = Set{String}())
    # GRUG v7.21: nonjitter_ids is the set of node ids tagged NONJITTER at the
    # engine layer. FullLobeScanner is its own module and does not see Node
    # objects — it only sees node_features by id. So the caller (engine-layer
    # orchestrator) is responsible for harvesting the tag from NODE_MAP and
    # passing the id set in. If empty (default), every node gets jittered as
    # before — this preserves backward compatibility.
    _require_not_done!(scanner)
    _require_query_features!(scanner.query_features)
    
    if scanner.phase == PHASE_INIT
        scanner.phase = PHASE_GATHER
    elseif scanner.phase != PHASE_GATHER
        throw_scan_error(
            "Cannot gather from $(phase_name(scanner.phase)) phase",
            "gather_candidates! - must start from INIT phase"
        )
    end
    
    all_ids = collect(keys(node_features))
    _require_nodes!(Set(all_ids))
    
    query = scanner.query_features
    n_threads = scanner.num_threads
    
    # GRUG: Thread-local storage for candidates
    thread_candidates = [Vector{String}() for _ in 1:n_threads]
    thread_scores = [Vector{Float64}() for _ in 1:n_threads]
    
    # GRUG: Static chunking - divide nodes evenly among threads
    chunk_size = cld(length(all_ids), n_threads)
    
    # GRUG: Use Threads.@threads for parallel scanning
    Threads.@threads for t in 1:n_threads
        start_idx = (t - 1) * chunk_size + 1
        end_idx = min(t * chunk_size, length(all_ids))
        
        for i in start_idx:end_idx
            node_id = all_ids[i]
            features = node_features[node_id]
            
            # GRUG: Compute similarity score
            score = _compute_similarity(query, features)
            # GRUG v7.21: NONJITTER honor — if this node_id is tagged NONJITTER
            # at the engine layer, skip the candidate-gathering score jitter
            # so its gate is bit-stable across runs. Set membership check is
            # O(1); empty default set means no-op for legacy callers.
            if !(node_id in nonjitter_ids)
                score = slight_jitter(score)  # GRUG: Add natural variation
            end

            if score >= threshold
                push!(thread_candidates[t], node_id)
                push!(thread_scores[t], score)
            end
        end
    end
    
    # GRUG: Merge results from all threads
    all_candidates = String[]
    all_scores = Float64[]
    for t in 1:n_threads
        append!(all_candidates, thread_candidates[t])
        append!(all_scores, thread_scores[t])
    end
    
    # GRUG: Sort by score (descending) - best candidates first
    score_pairs = collect(zip(all_candidates, all_scores))
    sort!(score_pairs, by = x -> x[2], rev = true)
    scanner.candidates = [p[1] for p in score_pairs]
    
    println("🧠 GRUG: Gathered $(length(scanner.candidates)) candidate nodes using $n_threads threads.")
    scanner.phase = PHASE_ACTIVATE
end

# ==============================================================================
# 13. PHASE 2: ACTIVATION
# ==============================================================================
# GRUG: Activate the best candidates. Max 1000 active at once.
#       Create matches for confident activations.

function activate_candidates!(scanner::LobeScanner, node_features::Dict{String, Vector{Float64}};
                              confident_threshold::Float64 = CONFIDENT_THRESHOLD,
                              nonjitter_ids::Set{String} = Set{String}())
    # GRUG v7.21: see note on gather_candidates! — same plumbing, same
    # semantics. Default empty set = full backward compatibility.
    _require_not_done!(scanner)
    _require_phase!(scanner, PHASE_ACTIVATE)
    
    if isempty(scanner.candidates)
        println("🧠 GRUG: No candidates to activate. Moving to DONE phase.")
        _emit_done!(scanner)
        return
    end
    
    query = scanner.query_features
    activated_count = 0
    
    for node_id in scanner.candidates
        # GRUG: Check if we can activate more
        if at_capacity(scanner.active_set)
            println("🧠 GRUG: Active set at capacity ($(scanner.active_set.max_size)). Stopping activation.")
            break
        end
        
        features = node_features[node_id]
        similarity = _compute_similarity(query, features)
        # GRUG v7.21: NONJITTER honor — activation confidence is bit-stable
        # for tagged nodes. abs(similarity) is already in [0, 1], so skipping
        # slight_jitter is safe (no clamp-edge surprises).
        confidence = (node_id in nonjitter_ids) ? abs(similarity) : slight_jitter(abs(similarity))

        # GRUG: Activate the node
        activate_node!(scanner.active_set, node_id, confidence)
        activated_count += 1
        
        # GRUG: Create match if confident enough
        if confidence >= confident_threshold
            match = PatternMatch(node_id, confidence, Int[], similarity)
            push!(scanner.matches, match)
            scanner.confident_count += 1
            scanner.pattern_count += 1
        end
    end
    
    scanner.scan_cycle += 1
    println("🧠 GRUG: Activated $activated_count nodes. $(scanner.confident_count) confident matches so far.")
    scanner.phase = PHASE_CONTINUE
end

# ==============================================================================
# 14. PHASE 3: CONTINUED SCANNING (SPREADING ACTIVATION)
# ==============================================================================
# GRUG: Spread activation through connected nodes.
#       Look for semantic matches in the neighborhood.

function continue_scan!(scanner::LobeScanner, 
                         node_features::Dict{String, Vector{Float64}},
                         node_connections::Dict{String, Vector{String}};
                         max_cycles::Int = MAX_CONTINUE_CYCLES, 
                         decay::Float64 = 0.9, 
                         confident_threshold::Float64 = CONFIDENT_THRESHOLD)
    _require_not_done!(scanner)
    
    if scanner.phase != PHASE_ACTIVATE && scanner.phase != PHASE_CONTINUE
        throw_scan_error(
            "Cannot continue from $(phase_name(scanner.phase)) phase",
            "continue_scan! - must be in ACTIVATE or CONTINUE phase"
        )
    end
    
    scanner.phase = PHASE_CONTINUE
    query = scanner.query_features
    
    for cycle in 1:max_cycles
        # GRUG: Get currently active nodes
        active_ids = collect(scanner.active_set.active_ids)
        
        if isempty(active_ids)
            println("🧠 GRUG: No active nodes. Scan complete.")
            _emit_done!(scanner)
            return
        end
        
        # GRUG: Track new activations this cycle
        new_activations = 0
        
        for node_id in active_ids
            current_activation = scanner.active_set.activations[node_id]
            
            # GRUG: Get connections for this node
            connections = get(node_connections, node_id, String[])
            
            for conn_id in connections
                if at_capacity(scanner.active_set)
                    break
                end
                
                if !is_active(scanner.active_set, conn_id) && haskey(node_features, conn_id)
                    conn_features = node_features[conn_id]
                    new_activation = current_activation * decay
                    
                    # GRUG: Check similarity for semantic match
                    similarity = _compute_similarity(query, conn_features)
                    
                    if new_activation > 0.1 && similarity > 0.2
                        activate_node!(scanner.active_set, conn_id, new_activation)
                        new_activations += 1
                        
                        # GRUG: Create semantic match if confident
                        confidence = min(abs(new_activation), abs(similarity))
                        if confidence >= confident_threshold
                            attractor_id = _find_attractor(scanner, conn_features)
                            
                            match = SemanticMatch(
                                conn_id, confidence, attractor_id,
                                -new_activation,  # Negative energy = stable
                                1.0 - abs(similarity)   # Topology distance
                            )
                            push!(scanner.matches, match)
                            scanner.confident_count += 1
                            scanner.semantic_count += 1
                        end
                    end
                end
            end
        end
        
        scanner.scan_cycle += 1
        println("🧠 GRUG: Cycle $cycle complete. $new_activations new activations. $(scanner.confident_count) confident matches.")
        
        # GRUG: Check for DONE condition
        # DONE when: no new activations AND we have confident matches
        if new_activations == 0 && scanner.confident_count > 0
            println("🧠 GRUG: No new activations and have confident matches. Scan complete.")
            _emit_done!(scanner)
            return
        end
        
        if new_activations == 0
            println("🧠 GRUG: Activation spread exhausted. Scan complete.")
            _emit_done!(scanner)
            return
        end
    end
    
    # GRUG: Max cycles reached
    println("🧠 GRUG: Max scan cycles ($max_cycles) reached.")
    _emit_done!(scanner)
end

# ==============================================================================
# 15. SEMANTIC ATTRACTOR MANAGEMENT
# ==============================================================================
# GRUG: Attractors are stable states in semantic space.
#       Like "basins" that thoughts fall into.

function _find_attractor(scanner::LobeScanner, features::Vector{Float64})::Int
    best_id = 0
    best_dist = Inf
    
    for (id, center) in scanner.attractors
        dist = sqrt(sum((features .- center).^2))
        if dist < best_dist
            best_dist = dist
            best_id = id
        end
    end
    
    # GRUG: If close enough to existing attractor, use it
    if best_dist < 0.5 && best_id > 0
        return best_id
    end
    
    # GRUG: Create new attractor
    new_id = length(scanner.attractors) + 1
    scanner.attractors[new_id] = copy(features)
    return new_id
end

# ==============================================================================
# 16. DONE SIGNAL EMISSION
# ==============================================================================
# GRUG: The DONE signal tells AIML it's okay to respond now.
#       NOT when all nodes visited, but when confident matches exhausted.

function _emit_done!(scanner::LobeScanner)
    scanner.phase = PHASE_DONE
    scanner.done_emitted = true
    scanner.aiml_ready = true
    
    elapsed = time() - scanner.start_time
    
    println("🧠 ============================================")
    println("🧠 DONE SIGNAL EMITTED")
    println("🧠 Lobe: $(scanner.lobe_id)")
    println("🧠 Confident matches: $(scanner.confident_count)")
    println("🧠 Pattern matches: $(scanner.pattern_count)")
    println("🧠 Semantic matches: $(scanner.semantic_count)")
    println("🧠 Total matches: $(length(scanner.matches))")
    println("🧠 Scan cycles: $(scanner.scan_cycle)")
    println("🧠 Scan time: $(round(elapsed, digits=3)) seconds")
    println("🧠 AIML CAN NOW RESPOND")
    println("🧠 ============================================")
end

# ==============================================================================
# 17. FULL SCAN - DO EVERYTHING IN ONE CALL
# ==============================================================================
# GRUG: Run the complete scan pipeline in one call.
#       Returns ScanResult with all findings.

function full_scan!(scanner::LobeScanner,
                    node_features::Dict{String, Vector{Float64}},
                    node_connections::Dict{String, Vector{String}};
                    candidate_threshold::Float64 = DEFAULT_CANDIDATE_THRESHOLD,
                    confident_threshold::Float64 = CONFIDENT_THRESHOLD,
                    max_continue_cycles::Int = MAX_CONTINUE_CYCLES)
    
    _require_not_done!(scanner)
    _require_query_features!(scanner.query_features)
    _require_nodes!(Set(keys(node_features)))
    
    println("🧠 GRUG: Starting full scan of lobe '$(scanner.lobe_id)'...")
    
    # Phase 1: Gather candidates
    gather_candidates!(scanner, node_features; threshold = candidate_threshold)
    
    # Phase 2: Activate candidates
    activate_candidates!(scanner, node_features; confident_threshold = confident_threshold)
    
    # Phase 3: Continue scanning (if not already done)
    if !scanner.done_emitted
        continue_scan!(scanner, node_features, node_connections; 
                       max_cycles = max_continue_cycles, 
                       confident_threshold = confident_threshold)
    end
    
    elapsed = time() - scanner.start_time
    
    # Build result
    result = ScanResult(
        scanner.matches,
        scanner.pattern_count,
        scanner.semantic_count,
        length(scanner.candidates),
        scanner.scan_cycle,
        scanner.phase,
        scanner.confident_count,
        scanner.done_emitted,
        elapsed
    )
    
    return result
end

# ==============================================================================
# 18. RESET - START OVER
# ==============================================================================
# GRUG: Clear everything and start fresh.

function reset!(scanner::LobeScanner)
    scanner.phase = PHASE_INIT
    empty!(scanner.candidates)
    empty!(scanner.matches)
    scanner.pattern_count = 0
    scanner.semantic_count = 0
    scanner.scan_cycle = 0
    empty!(scanner.query_features)
    scanner.confident_count = 0
    scanner.done_emitted = false
    scanner.aiml_ready = false
    clear_active!(scanner.active_set)
    empty!(scanner.attractors)
    scanner.start_time = 0.0
    
    println("🧠 GRUG: Scanner reset. Ready for new scan.")
end

# ==============================================================================
# 19. AIML GATING - CHECK IF AIML CAN RESPOND
# ==============================================================================
# GRUG: AIML not allowed until DONE signal. This checks that.

function can_aiml_respond(scanner::LobeScanner)::Bool
    return scanner.aiml_ready && scanner.done_emitted
end

function require_aiml_ready!(scanner::LobeScanner)
    if !can_aiml_respond(scanner)
        throw_scan_error(
            "AIML NOT ALLOWED YET. Wait for DONE signal.",
            "require_aiml_ready! - current phase: $(phase_name(scanner.phase)), done: $(scanner.done_emitted)"
        )
    end
end

# ==============================================================================
# 20. STATISTICS AND DEBUGGING
# ==============================================================================
# GRUG: What's going on in there?

function scanner_status(scanner::LobeScanner)::String
    lines = String[]
    push!(lines, "🧠 ========== SCANNER STATUS ==========")
    push!(lines, "🧠 Lobe: $(scanner.lobe_id)")
    push!(lines, "🧠 Phase: $(phase_name(scanner.phase))")
    push!(lines, "🧠 Candidates: $(length(scanner.candidates))")
    push!(lines, "🧠 Active nodes: $(active_count(scanner.active_set)) / $(scanner.active_set.max_size)")
    push!(lines, "🧠 Total matches: $(length(scanner.matches))")
    push!(lines, "🧠 Pattern matches: $(scanner.pattern_count)")
    push!(lines, "🧠 Semantic matches: $(scanner.semantic_count)")
    push!(lines, "🧠 Confident matches: $(scanner.confident_count)")
    push!(lines, "🧠 Scan cycles: $(scanner.scan_cycle)")
    push!(lines, "🧠 Threads: $(scanner.num_threads)")
    push!(lines, "🧠 Attractors: $(length(scanner.attractors))")
    push!(lines, "🧠 DONE emitted: $(scanner.done_emitted)")
    push!(lines, "🧠 AIML ready: $(scanner.aiml_ready)")
    push!(lines, "🧠 ====================================")
    return join(lines, "\n")
end

function print_status(scanner::LobeScanner)
    println(scanner_status(scanner))
end

# ==============================================================================
# 21. EXPORTS
# ==============================================================================

export FullLobeScanError, NoMatchFoundError
export PatternMatch, SemanticMatch, AbstractMatch
export ActiveNodeSet, LobeScanner, ScanResult, ScanPhase
export PHASE_INIT, PHASE_GATHER, PHASE_ACTIVATE, PHASE_CONTINUE, PHASE_DONE
export MAX_ACTIVE_NODES, MAX_THREADS, CONFIDENT_THRESHOLD
export set_query!, gather_candidates!, activate_candidates!
export continue_scan!, full_scan!, reset!
export can_aiml_respond, require_aiml_ready!
export scanner_status, print_status
export is_active, active_count, at_capacity
export activate_node!, deactivate_node!, clear_active!
export phase_name

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: FULL-LOBE SCANNING SYSTEM
#
# 1. BOUNDED ACTIVATION ARCHITECTURE:
#    - Max 20,000 nodes per lobe (enforced by Lobe.jl)
#    - Max 1,000 active nodes at any time (enforced by ActiveNodeSet)
#    - FIFO eviction when at capacity (oldest activated gets removed)
#
# 2. PHASE-GATED SCANNING:
#    - INIT → GATHER → ACTIVATE → CONTINUE → DONE
#    - Each phase has strict entry requirements
#    - DONE signal required before AIML can respond
#
# 3. MATCH TYPES:
#    - PatternMatch: Direct feature correlation (cosine similarity)
#    - SemanticMatch: Topology/attractor-based (spreading activation)
#
# 4. MULTITHREADING:
#    - Static chunking for candidate gathering
#    - 4-8 threads (configurable)
#    - Thread-local result collection, merge after
#
# 5. NO SILENT FAILURES:
#    - All errors throw loudly (FullLobeScanError, NoMatchFoundError)
#    - Validation helpers check preconditions
#    - Context included in all error messages
#
# 6. NATURAL JITTER:
#    - Bounded uniform jitter clamped to [0, 1] (confidence-safe)
#    - Models hardware/sensor variance
#    - Prevents artificial "perfect" matches
# ==============================================================================

end # module FullLobeScanner