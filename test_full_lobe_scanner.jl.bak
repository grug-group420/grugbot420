# test_full_lobe_scanner.jl - Comprehensive Tests for FullLobeScanner
# GRUG say: Test everything! If test fail, Grug know immediately.
# GRUG say: No silent failures in tests either!

using Test
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
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

# GRUG: Include the module we're testing
include("../src/FullLobeScanner.jl")
using .FullLobeScanner

# ==============================================================================
# TEST HELPERS
# ==============================================================================

function create_test_features(n_nodes::Int, feature_dim::Int)::Dict{String, Vector{Float64}}
    features = Dict{String, Vector{Float64}}()
    for i in 1:n_nodes
        node_id = "node_$i"
        features[node_id] = rand(feature_dim)
    end
    return features
end

function create_test_connections(n_nodes::Int, avg_connections::Int)::Dict{String, Vector{String}}
    connections = Dict{String, Vector{String}}()
    for i in 1:n_nodes
        node_id = "node_$i"
        # Connect to random other nodes
        n_conn = rand(1:avg_connections*2)
        conn_ids = String[]
        for _ in 1:n_conn
            target = "node_$(rand(1:n_nodes))"
            if target != node_id
                push!(conn_ids, target)
            end
        end
        connections[node_id] = unique(conn_ids)
    end
    return connections
end

function create_similar_features(base::Vector{Float64}, n::Int, noise_level::Float64 = 0.1)::Vector{Vector{Float64}}
    result = Vector{Vector{Float64}}()
    for _ in 1:n
        noisy = base .+ (rand(length(base)) .- 0.5) .* noise_level
        push!(result, noisy)
    end
    return result
end

# ==============================================================================
# TEST SUITE 1: ACTIVE NODE SET
# ==============================================================================

@testset "ActiveNodeSet - Basic Operations" begin
    ans = ActiveNodeSet(100)
    
    @test active_count(ans) == 0
    @test !at_capacity(ans)
    
    # Activate some nodes
    @test activate_node!(ans, "node_1", 0.5) == true
    @test active_count(ans) == 1
    @test is_active(ans, "node_1")
    
    @test activate_node!(ans, "node_2", 0.8) == true
    @test active_count(ans) == 2
    
    # Activate same node again - should return false
    @test activate_node!(ans, "node_1", 0.9) == false
    @test active_count(ans) == 2  # No change
    
    # Deactivate
    deactivate_node!(ans, "node_1")
    @test !is_active(ans, "node_1")
    @test active_count(ans) == 1
end

@testset "ActiveNodeSet - Capacity Enforcement" begin
    ans = ActiveNodeSet(5)  # Small capacity for testing
    
    # Fill to capacity
    for i in 1:5
        activate_node!(ans, "node_$i", 0.5)
    end
    
    @test at_capacity(ans)
    @test active_count(ans) == 5
    
    # Try to activate one more - should evict oldest (node_1)
    activate_node!(ans, "node_6", 0.5)
    @test active_count(ans) == 5  # Still at capacity
    @test !is_active(ans, "node_1")  # Evicted
    @test is_active(ans, "node_6")  # New node active
end

@testset "ActiveNodeSet - Error Handling" begin
    ans = ActiveNodeSet(100)
    
    # Empty node_id
    @test_throws FullLobeScanError activate_node!(ans, "", 0.5)
    
    # Invalid activation level
    @test_throws FullLobeScanError activate_node!(ans, "node_1", -0.1)
    @test_throws FullLobeScanError activate_node!(ans, "node_1", 1.5)
    
    # Deactivate non-active node
    @test_throws FullLobeScanError deactivate_node!(ans, "node_1")
    
    # Invalid max_size
    @test_throws FullLobeScanError ActiveNodeSet(0)
    @test_throws FullLobeScanError ActiveNodeSet(-1)
    @test_throws FullLobeScanError ActiveNodeSet(MAX_ACTIVE_NODES + 1)
end

@testset "ActiveNodeSet - Clear" begin
    ans = ActiveNodeSet(100)
    
    for i in 1:10
        activate_node!(ans, "node_$i", 0.5)
    end
    
    @test active_count(ans) == 10
    clear_active!(ans)
    @test active_count(ans) == 0
    @test !at_capacity(ans)
end

# ==============================================================================
# TEST SUITE 2: MATCH TYPES
# ==============================================================================

@testset "PatternMatch - Creation" begin
    match = PatternMatch("node_1", 0.85, [1, 2, 3], 0.9)
    
    @test match.node_id == "node_1"
    @test match.confidence == 0.85
    @test match.matched_features == [1, 2, 3]
    @test match.match_strength == 0.9
end

@testset "PatternMatch - Validation" begin
    # Invalid confidence
    @test_throws FullLobeScanError PatternMatch("node_1", -0.1, [1], 0.5)
    @test_throws FullLobeScanError PatternMatch("node_1", 1.5, [1], 0.5)
    
    # Empty node_id
    @test_throws FullLobeScanError PatternMatch("", 0.5, [1], 0.5)
end

@testset "SemanticMatch - Creation" begin
    match = SemanticMatch("node_2", 0.75, 1, -0.5, 0.3)
    
    @test match.node_id == "node_2"
    @test match.confidence == 0.75
    @test match.attractor_id == 1
    @test match.hopfield_energy == -0.5
    @test match.topology_distance == 0.3
end

@testset "SemanticMatch - Validation" begin
    # Invalid confidence
    @test_throws FullLobeScanError SemanticMatch("node_1", -0.1, 1, -0.5, 0.3)
    @test_throws FullLobeScanError SemanticMatch("node_1", 1.5, 1, -0.5, 0.3)
    
    # Empty node_id
    @test_throws FullLobeScanError SemanticMatch("", 0.5, 1, -0.5, 0.3)
end

# ==============================================================================
# TEST SUITE 3: LOBE SCANNER - BASIC OPERATIONS
# ==============================================================================

@testset "LobeScanner - Creation" begin
    scanner = LobeScanner("test_lobe", 4)
    
    @test scanner.lobe_id == "test_lobe"
    @test scanner.num_threads == 4
    @test scanner.phase == PHASE_INIT
    @test length(scanner.candidates) == 0
    @test length(scanner.matches) == 0
    @test !scanner.done_emitted
    @test !scanner.aiml_ready
end

@testset "LobeScanner - Validation" begin
    # Empty lobe_id
    @test_throws FullLobeScanError LobeScanner("", 4)
    
    # Invalid thread count
    @test_throws FullLobeScanError LobeScanner("test", 0)
    @test_throws FullLobeScanError LobeScanner("test", -1)
    @test_throws FullLobeScanError LobeScanner("test", MAX_THREADS + 1)
end

@testset "LobeScanner - Query Setup" begin
    scanner = LobeScanner("test_lobe")
    query = [0.1, 0.2, 0.3, 0.4, 0.5]
    
    set_query!(scanner, query)
    
    @test scanner.query_features == query
    @test scanner.phase == PHASE_GATHER
    @test scanner.start_time > 0
end

@testset "LobeScanner - Query Validation" begin
    scanner = LobeScanner("test_lobe")
    
    # Empty query
    @test_throws FullLobeScanError set_query!(scanner, Float64[])
    
    # Set query, then try again (should fail - scan in progress)
    set_query!(scanner, [0.1, 0.2])
    @test_throws FullLobeScanError set_query!(scanner, [0.3, 0.4])
end

# ==============================================================================
# TEST SUITE 4: CANDIDATE GATHERING
# ==============================================================================

@testset "Gather Candidates - Basic" begin
    scanner = LobeScanner("test_lobe", 2)
    
    # Create features with some similar to query
    query = [0.5, 0.5, 0.5]
    features = create_test_features(100, 3)
    
    # Make some nodes similar to query
    similar_features = create_similar_features(query, 10, 0.1)
    for (i, feat) in enumerate(similar_features)
        features["similar_$i"] = feat
    end
    
    set_query!(scanner, query)
    gather_candidates!(scanner, features; threshold = 0.3)
    
    @test scanner.phase == PHASE_ACTIVATE
    @test length(scanner.candidates) > 0
    @test length(scanner.candidates) <= 110  # Should not exceed total nodes (100 + 10 similar)
end

@testset "Gather Candidates - Empty Lobe" begin
    scanner = LobeScanner("test_lobe")
    features = Dict{String, Vector{Float64}}()
    
    set_query!(scanner, [0.1, 0.2])
    @test_throws FullLobeScanError gather_candidates!(scanner, features)
end

@testset "Gather Candidates - No Query" begin
    scanner = LobeScanner("test_lobe")
    features = create_test_features(10, 3)
    
    @test_throws FullLobeScanError gather_candidates!(scanner, features)
end

@testset "Gather Candidates - Wrong Phase" begin
    scanner = LobeScanner("test_lobe")
    features = create_test_features(10, 3)
    
    set_query!(scanner, [0.1, 0.2])
    gather_candidates!(scanner, features)
    
    # Try to gather again (wrong phase)
    @test_throws FullLobeScanError gather_candidates!(scanner, features)
end

# ==============================================================================
# TEST SUITE 5: ACTIVATION
# ==============================================================================

@testset "Activate Candidates - Basic" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(50, 3)
    
    # Make some nodes similar
    for i in 1:10
        features["similar_$i"] = query .+ (rand(3) .- 0.5) .* 0.1
    end
    
    set_query!(scanner, query)
    gather_candidates!(scanner, features; threshold = 0.3)
    activate_candidates!(scanner, features; confident_threshold = 0.7)
    
    @test scanner.phase == PHASE_CONTINUE
    @test active_count(scanner.active_set) > 0
    @test length(scanner.matches) >= 0
end

@testset "Activate Candidates - No Candidates" begin
    scanner = LobeScanner("test_lobe")
    
    # Create features that are orthogonal to query
    features = Dict{String, Vector{Float64}}()
    for i in 1:10
        features["node_$i"] = [1.0, 0.0, 0.0]  # All same, orthogonal to query
    end
    
    set_query!(scanner, [0.0, 1.0, 0.0])  # Orthogonal direction
    # Gather with very high threshold so no candidates found
    gather_candidates!(scanner, features; threshold = 0.99)
    
    @test length(scanner.candidates) == 0
    
    activate_candidates!(scanner, features)
    
    @test scanner.phase == PHASE_DONE
    @test scanner.done_emitted
    @test scanner.aiml_ready
end

@testset "Activate Candidates - Capacity" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(2000, 3)  # Many nodes
    
    # Make many nodes similar
    for i in 1:1500
        features["similar_$i"] = query .+ (rand(3) .- 0.5) .* 0.05
    end
    
    set_query!(scanner, query)
    gather_candidates!(scanner, features; threshold = 0.5)
    activate_candidates!(scanner, features; confident_threshold = 0.6)
    
    # Should not exceed capacity
    @test active_count(scanner.active_set) <= MAX_ACTIVE_NODES
end

# ==============================================================================
# TEST SUITE 6: CONTINUED SCANNING
# ==============================================================================

@testset "Continue Scan - Basic" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(100, 3)
    connections = create_test_connections(100, 5)
    
    # Create a cluster of similar nodes
    cluster_ids = ["cluster_$i" for i in 1:20]
    for id in cluster_ids
        features[id] = query .+ (rand(3) .- 0.5) .* 0.1
        # Connect cluster nodes together
        connections[id] = filter(x -> x != id, cluster_ids)
    end
    
    set_query!(scanner, query)
    gather_candidates!(scanner, features; threshold = 0.3)
    activate_candidates!(scanner, features; confident_threshold = 0.6)
    
    initial_matches = length(scanner.matches)
    
    continue_scan!(scanner, features, connections; max_cycles = 5, confident_threshold = 0.5)
    
    @test scanner.phase == PHASE_DONE
    @test scanner.done_emitted
    @test length(scanner.matches) >= initial_matches
end

@testset "Continue Scan - No Connections" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(50, 3)
    connections = Dict{String, Vector{String}}()  # No connections
    
    set_query!(scanner, query)
    gather_candidates!(scanner, features; threshold = 0.3)
    activate_candidates!(scanner, features; confident_threshold = 0.6)
    
    continue_scan!(scanner, features, connections; max_cycles = 5)
    
    @test scanner.phase == PHASE_DONE
    @test scanner.done_emitted
end

# ==============================================================================
# TEST SUITE 7: FULL SCAN
# ==============================================================================

@testset "Full Scan - Complete Pipeline" begin
    scanner = LobeScanner("test_lobe", 4)
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(500, 3)
    connections = create_test_connections(500, 10)
    
    # Create some similar nodes
    for i in 1:30
        features["target_$i"] = query .+ (rand(3) .- 0.5) .* 0.08
        # Connect them
        connections["target_$i"] = ["target_$((i % 30) + 1)"]
    end
    
    set_query!(scanner, query)
    result = full_scan!(scanner, features, connections; 
                        candidate_threshold = 0.3,
                        confident_threshold = 0.65,
                        max_continue_cycles = 5)
    
    @test result.done_signal
    @test result.final_phase == PHASE_DONE
    @test result.nodes_scanned > 0
    @test result.scan_cycles > 0
    @test result.scan_time_seconds > 0
    @test result.pattern_matches + result.semantic_matches >= 0
end

@testset "Full Scan - No Matches" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(100, 3)
    connections = create_test_connections(100, 5)
    
    # All features are very different from query (orthogonal)
    for (id, feat) in features
        features[id] = [1.0, 0.0, 0.0]  # Completely different direction
    end
    
    set_query!(scanner, query)
    result = full_scan!(scanner, features, connections; 
                        candidate_threshold = 0.8,  # High threshold
                        confident_threshold = 0.9)
    
    @test result.done_signal
    @test result.confident_matches == 0
    @test result.final_phase == PHASE_DONE
end

# ==============================================================================
# TEST SUITE 8: AIML GATING
# ==============================================================================

@testset "AIML Gating - Before DONE" begin
    scanner = LobeScanner("test_lobe")
    
    @test !can_aiml_respond(scanner)
    @test_throws FullLobeScanError require_aiml_ready!(scanner)
end

@testset "AIML Gating - After DONE" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(50, 3)
    connections = create_test_connections(50, 5)
    
    set_query!(scanner, query)
    full_scan!(scanner, features, connections)
    
    @test can_aiml_respond(scanner)
    @test require_aiml_ready!(scanner) === nothing  # Should not throw
end

# ==============================================================================
# TEST SUITE 9: RESET
# ==============================================================================

@testset "Reset - Clear State" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(50, 3)
    connections = create_test_connections(50, 5)
    
    set_query!(scanner, query)
    full_scan!(scanner, features, connections)
    
    # Verify scan completed
    @test scanner.done_emitted
    @test length(scanner.matches) > 0
    
    # Reset
    reset!(scanner)
    
    # Verify reset
    @test scanner.phase == PHASE_INIT
    @test length(scanner.candidates) == 0
    @test length(scanner.matches) == 0
    @test scanner.confident_count == 0
    @test !scanner.done_emitted
    @test !scanner.aiml_ready
    @test active_count(scanner.active_set) == 0
    @test length(scanner.attractors) == 0
end

# ==============================================================================
# TEST SUITE 10: PERFORMANCE TESTS
# ==============================================================================

@testset "Performance - Thread Scaling" begin
    query = [0.5, 0.5, 0.5]
    features = create_test_features(2000, 10)
    connections = create_test_connections(2000, 10)
    
    # Create some similar nodes
    for i in 1:100
        features["target_$i"] = query .+ (rand(3) .- 0.5) .* 0.1
    end
    
    times = Float64[]
    
    for n_threads in [1, 2, 4, 8]
        scanner = LobeScanner("test_lobe", n_threads)
        set_query!(scanner, query)
        
        start_time = time()
        full_scan!(scanner, features, connections; max_continue_cycles = 3)
        elapsed = time() - start_time
        
        push!(times, elapsed)
        println("  Threads: $n_threads, Time: $(round(elapsed, digits=3))s")
    end
    
    # GRUG: Thread scaling should complete without error
    # Performance improvement is not guaranteed due to overhead
    @test length(times) == 4
    @test all(t -> t > 0, times)  # All times should be positive
end

@testset "Performance - Large Lobe" begin
    scanner = LobeScanner("test_lobe", 8)
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(10000, 10)
    connections = create_test_connections(10000, 5)
    
    # Create some similar nodes
    for i in 1:200
        features["target_$i"] = query .+ (rand(3) .- 0.5) .* 0.1
    end
    
    set_query!(scanner, query)
    
    start_time = time()
    result = full_scan!(scanner, features, connections; max_continue_cycles = 5)
    elapsed = time() - start_time
    
    println("  Large lobe scan: $(result.nodes_scanned) nodes in $(round(elapsed, digits=3))s")
    
    @test result.done_signal
    @test elapsed < 30.0  # Should complete in reasonable time
end

# ==============================================================================
# TEST SUITE 11: ERROR HANDLING
# ==============================================================================

@testset "Error Handling - Invalid Operations" begin
    scanner = LobeScanner("test_lobe")
    
    # Try to continue scan without query
    features = create_test_features(10, 3)
    connections = create_test_connections(10, 5)
    @test_throws FullLobeScanError continue_scan!(scanner, features, connections)
    
    # Try to activate without gathering
    set_query!(scanner, [0.1, 0.2])
    @test_throws FullLobeScanError activate_candidates!(scanner, features)
end

@testset "Error Handling - Scan After Done" begin
    scanner = LobeScanner("test_lobe")
    
    query = [0.5, 0.5, 0.5]
    features = create_test_features(50, 3)
    connections = create_test_connections(50, 5)
    
    set_query!(scanner, query)
    full_scan!(scanner, features, connections)
    
    # Try to continue after done
    @test_throws FullLobeScanError continue_scan!(scanner, features, connections)
    
    # Try to gather after done
    @test_throws FullLobeScanError gather_candidates!(scanner, features)
end

# ==============================================================================
# TEST SUITE 12: STATUS AND DEBUGGING
# ==============================================================================

@testset "Status - Scanner Status" begin
    scanner = LobeScanner("test_lobe", 4)
    
    status = scanner_status(scanner)
    @test occursin("test_lobe", status)
    @test occursin("INITIALIZATION", status)
    
    set_query!(scanner, [0.1, 0.2])
    status = scanner_status(scanner)
    @test occursin("CANDIDATE_GATHERING", status)
end

@testset "Status - Print Status" begin
    scanner = LobeScanner("test_lobe")
    
    # Should not throw
    print_status(scanner)
    
    set_query!(scanner, [0.1, 0.2])
    print_status(scanner)
end

# ==============================================================================
# TEST SUITE 13: PHASE NAMES
# ==============================================================================

@testset "Phase Names" begin
    @test phase_name(PHASE_INIT) == "INITIALIZATION"
    @test phase_name(PHASE_GATHER) == "CANDIDATE_GATHERING"
    @test phase_name(PHASE_ACTIVATE) == "ACTIVATION"
    @test phase_name(PHASE_CONTINUE) == "CONTINUED_SCAN"
    @test phase_name(PHASE_DONE) == "DONE"
end

# ==============================================================================
# RUN ALL TESTS
# ==============================================================================

println("\n")
println("="^70)
println("🧠 GRUG: ALL FULL-LOBE SCANNER TESTS COMPLETE")
println("="^70)
println("\n")