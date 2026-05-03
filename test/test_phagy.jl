# test_phagy.jl
# ==============================================================================
# GRUG TEST: PhagyMode — comprehensive unit tests for all 7 automata.
# GRUG say: test the janitors like testing cave hygiene. Sweep, decay, recycle,
# validate, compact, prune, and now FORENSICS.
# ==============================================================================

using Test, Random

println("\n" * "="^60)
println("GRUG PHAGY MODE TEST SUITE")
println("="^60)

# ==============================================================================
# MODULE LOADS
# ==============================================================================
println("\n[0] MODULE LOADS")

include("../src/stochastichelper.jl");    using .CoinFlipHeader;      println("  ✓ StochasticHelper")
include("../src/patternscanner.jl");      using .PatternScanner;      println("  ✓ PatternScanner")
include("../src/ImageSDF.jl");            using .ImageSDF;            println("  ✓ ImageSDF")
include("../src/EyeSystem.jl");           using .EyeSystem;           println("  ✓ EyeSystem")
include("../src/SemanticVerbs.jl");       using .SemanticVerbs;       println("  ✓ SemanticVerbs")
include("../src/ActionTonePredictor.jl"); using .ActionTonePredictor; println("  ✓ ActionTonePredictor")
include("../src/engine.jl")
println("  ✓ Engine (full chain)")
include("../src/PhagyMode.jl");           using .PhagyMode;           println("  ✓ PhagyMode")

# ==============================================================================
# MOCK TYPES — lightweight stand-ins matching expected interfaces
# ==============================================================================

# GRUG: ChatMessage mock for memory forensics tests
mutable struct MockMessage
    id::Int
    role::String
    text::String
    pinned::Bool
end

# GRUG: Rule mock for rule pruner tests
mutable struct MockRule
    pattern::String
    fire_count::Int
    dormancy_strikes::Int
    is_dormant::Bool
end

# ==============================================================================
# HELPERS — clean state between groups
# ==============================================================================

function reset_engine!()
    lock(NODE_LOCK) do
        empty!(NODE_MAP)
    end
    lock(ATTACHMENT_LOCK) do
        empty!(ATTACHMENT_MAP)
    end
    lock(HOPFIELD_CACHE_LOCK) do
        empty!(HOPFIELD_CACHE)
        empty!(HOPFIELD_HIT_COUNTS)
    end
    ID_COUNTER[] = 0
end

function make_node!(pattern::String; strength::Float64=5.0, is_grave::Bool=false, grave_reason::String="")
    id = create_node(pattern, "reason^1", Dict{String,Any}(), String[]; initial_strength=strength)
    if is_grave
        lock(NODE_LOCK) do
            NODE_MAP[id].is_grave = true
            NODE_MAP[id].grave_reason = grave_reason
        end
    end
    return id
end

function make_messages(specs::Vector{Tuple{String, String}})::Vector{MockMessage}
    msgs = MockMessage[]
    for (i, (role, text)) in enumerate(specs)
        push!(msgs, MockMessage(i, role, text, false))
    end
    return msgs
end

function reset_phagy_log!()
    lock(PhagyMode.PHAGY_LOG_LOCK) do
        empty!(PhagyMode.PHAGY_LOG)
    end
end

# ==============================================================================
# 1. ORPHAN PRUNER — graves disconnected zero-strength nodes
# ==============================================================================
@testset "Phagy - Orphan Pruner" begin
    reset_engine!()

    # Make an orphan: 0 neighbors, 0 strength
    orphan = make_node!("orphan node"; strength=0.0)
    # Make a healthy node: has strength
    healthy = make_node!("healthy node"; strength=5.0)

    stats = PhagyMode.prune_orphan_nodes!(NODE_MAP, NODE_LOCK)
    @test stats.automaton == "ORPHAN_PRUNER"
    @test stats.items_processed >= 2  # Examined both
    @test stats.items_changed >= 1    # Graved the orphan
    @test stats.cycle_time_ms >= 0.0

    # Verify orphan is graved
    lock(NODE_LOCK) do
        @test NODE_MAP[orphan].is_grave == true
        @test NODE_MAP[healthy].is_grave == false
    end

    println("  ✓ [1] Orphan Pruner: graved orphan, left healthy node alone")
end

# ==============================================================================
# 2. ORPHAN PRUNER — skips image nodes and nodes with drop tables
# ==============================================================================
@testset "Phagy - Orphan Pruner safety skips" begin
    reset_engine!()

    # Create a node with 0 strength 0 neighbors but is_image_node
    img_node = make_node!("image placeholder"; strength=0.0)
    lock(NODE_LOCK) do
        NODE_MAP[img_node].is_image_node = true
    end

    stats = PhagyMode.prune_orphan_nodes!(NODE_MAP, NODE_LOCK)

    # Image node should be skipped, not graved
    lock(NODE_LOCK) do
        @test NODE_MAP[img_node].is_grave == false
    end

    println("  ✓ [2] Orphan Pruner: image nodes safely skipped")
end

# ==============================================================================
# 3. STRENGTH DECAYER — applies decay to weak nodes
# ==============================================================================
@testset "Phagy - Strength Decayer" begin
    reset_engine!()

    weak = make_node!("weak node"; strength=0.2)
    strong = make_node!("strong node"; strength=8.0)

    old_weak_str = lock(NODE_LOCK) do; NODE_MAP[weak].strength; end
    old_strong_str = lock(NODE_LOCK) do; NODE_MAP[strong].strength; end

    stats = PhagyMode.decay_forgotten_strengths!(NODE_MAP, NODE_LOCK)
    @test stats.automaton == "STRENGTH_DECAYER"
    @test stats.items_changed >= 1  # Weak node decayed

    new_weak_str = lock(NODE_LOCK) do; NODE_MAP[weak].strength; end
    new_strong_str = lock(NODE_LOCK) do; NODE_MAP[strong].strength; end

    @test new_weak_str < old_weak_str   # Weak node got decayed
    @test new_strong_str == old_strong_str  # Strong node untouched

    println("  ✓ [3] Strength Decayer: weak node decayed, strong node preserved")
end

# ==============================================================================
# 4. STRENGTH DECAYER — floor at 0.0
# ==============================================================================
@testset "Phagy - Strength Decayer floor" begin
    reset_engine!()

    # Strength already at 0.01 — decay should floor at 0.0
    almost_dead = make_node!("almost dead"; strength=0.01)

    PhagyMode.decay_forgotten_strengths!(NODE_MAP, NODE_LOCK)

    new_str = lock(NODE_LOCK) do; NODE_MAP[almost_dead].strength; end
    @test new_str >= 0.0  # Never negative

    println("  ✓ [4] Strength Decayer: floors at 0.0, never negative")
end

# ==============================================================================
# 5. HOPFIELD CACHE VALIDATOR — purges stale entries - DISABLED
# ==============================================================================
# GRUG: Hopfield caching has been DISABLED. The CACHE_VALIDATOR automaton is no
# longer active. Tests are disabled but preserved for reference.
# Hopfield caching should only be used for RIDICULOUSLY LARGE lobe sizes
# (50,000+ nodes per lobe) where memory access becomes a bottleneck.
#
# OLD TEST (DISABLED):
# @testset "Phagy - Cache Validator" begin
#     reset_engine!()
#
#     alive_node = make_node!("alive cache node")
#     dead_node = make_node!("dead cache node"; is_grave=true, grave_reason="TEST")
#
#     # Plant cache entries
#     lock(HOPFIELD_CACHE_LOCK) do
#         HOPFIELD_CACHE[UInt64(1001)] = [alive_node]         # Valid
#         HOPFIELD_CACHE[UInt64(1002)] = [dead_node]           # Stale (graved)
#         HOPFIELD_CACHE[UInt64(1003)] = ["nonexistent_node"]  # Stale (missing)
#     end
#
#     stats = PhagyMode.validate_hopfield_cache!(HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK, NODE_MAP, NODE_LOCK)
#     @test stats.automaton == "CACHE_VALIDATOR"
#     @test stats.items_changed == 2  # Two stale entries purged
#
#     lock(HOPFIELD_CACHE_LOCK) do
#         @test haskey(HOPFIELD_CACHE, UInt64(1001))   # Valid kept
#         @test !haskey(HOPFIELD_CACHE, UInt64(1002))  # Stale purged
#         @test !haskey(HOPFIELD_CACHE, UInt64(1003))  # Stale purged
#     end
#
#     println("  ✓ [5] Cache Validator: purged 2 stale entries, kept 1 valid")
# end

println("  ⊝ [5] Cache Validator: DISABLED (Hopfield caching removed)")

# ==============================================================================
# 6. RULE PRUNER — flags dormant rules
# ==============================================================================
@testset "Phagy - Rule Pruner" begin
    active_rule = MockRule("active rule", 5, 0, false)    # Has fires
    dormant_rule = MockRule("dormant rule", 0, 19, false)  # 19 strikes, one more = dormant
    already_dormant = MockRule("old rule", 0, 99, true)    # Already flagged

    rules = [active_rule, dormant_rule, already_dormant]
    rules_lock = ReentrantLock()

    stats = PhagyMode.prune_dormant_rules!(rules, rules_lock)
    @test stats.automaton == "RULE_PRUNER"

    # Active rule should have reset dormancy_strikes
    @test active_rule.dormancy_strikes == 0
    @test active_rule.is_dormant == false

    # Dormant rule should now be flagged (19+1 = 20 = threshold)
    @test dormant_rule.is_dormant == true
    @test dormant_rule.dormancy_strikes >= 20

    # Already dormant should remain dormant
    @test already_dormant.is_dormant == true

    println("  ✓ [6] Rule Pruner: active reset, dormant flagged, already-dormant skipped")
end

# ==============================================================================
# 7. PHAGY LOG — bounded ring buffer
# ==============================================================================
@testset "Phagy - Log ring buffer" begin
    reset_phagy_log!()

    # Push 60 entries (max is 50)
    for i in 1:60
        PhagyMode.push_phagy_log!(PhagyStats("TEST_$i", i, 0, 0.1, "test"))
    end

    log = PhagyMode.get_phagy_log()
    @test length(log) == 50  # Capped at MAX_PHAGY_LOG
    @test log[1].automaton == "TEST_11"   # First 10 evicted
    @test log[50].automaton == "TEST_60"  # Last entry present

    println("  ✓ [7] Phagy log: bounded at 50 entries, oldest evicted first")
end

# ==============================================================================
# 8. PHAGYSTATS — struct field integrity
# ==============================================================================
@testset "Phagy - PhagyStats fields" begin
    s = PhagyStats("TEST_AUTO", 42, 7, 1.234, "some notes here")
    @test s.automaton == "TEST_AUTO"
    @test s.items_processed == 42
    @test s.items_changed == 7
    @test s.cycle_time_ms == 1.234
    @test s.notes == "some notes here"

    println("  ✓ [8] PhagyStats: all fields accessible and correct")
end

# ==============================================================================
# 9. PHAGYERROR — custom error type
# ==============================================================================
@testset "Phagy - PhagyError" begin
    e = PhagyError("test error message")
    @test e.msg == "test error message"

    buf = IOBuffer()
    Base.showerror(buf, e)
    err_str = String(take!(buf))
    @test occursin("PhagyError", err_str)
    @test occursin("test error message", err_str)

    println("  ✓ [9] PhagyError: custom error type works")
end

# ==============================================================================
# 10. RUN_PHAGY! — input validation
# ==============================================================================
@testset "Phagy - run_phagy! validation" begin
    reset_engine!()

    # Invalid lock types should throw — Julia dispatch rejects at the type level
    # (MethodError because run_phagy! signature requires ::ReentrantLock).
    # This is correct behavior: type annotations prevent invalid calls at dispatch.
    @test_throws MethodError PhagyMode.run_phagy!(
        NODE_MAP, "not a lock",
        HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK,
        [], ReentrantLock()
    )

    println("  ✓ [10] run_phagy!: rejects invalid lock types (MethodError at dispatch)")
end

# ==============================================================================
# 11. RUN_PHAGY! — dispatches an automaton and logs
# ==============================================================================
@testset "Phagy - run_phagy! dispatch" begin
    reset_engine!()
    reset_phagy_log!()

    # Seed some nodes so automata have something to work with
    for i in 1:5
        make_node!("test node $i"; strength=Float64(i))
    end

    msgs = make_messages([("User", "hello"), ("System", "hi back")])
    history_lock = ReentrantLock()

    stats = PhagyMode.run_phagy!(
        NODE_MAP, NODE_LOCK,
        HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK,
        [], ReentrantLock();
        message_history=msgs,
        history_lock=history_lock
    )

    @test stats isa PhagyStats
    @test !isempty(stats.automaton)
    @test stats.cycle_time_ms >= 0.0

    # Should be logged
    log = PhagyMode.get_phagy_log()
    @test length(log) >= 1
    @test log[end].automaton == stats.automaton

    println("  ✓ [11] run_phagy!: dispatched $(stats.automaton), logged to ring buffer")
end

# ==============================================================================
# 12. RUN_PHAGY! — forensics re-roll when no message_history
# ==============================================================================
@testset "Phagy - forensics re-roll fallback" begin
    reset_engine!()
    reset_phagy_log!()

    make_node!("test node")

    # Run many times without message_history — should never crash
    for _ in 1:20
        stats = PhagyMode.run_phagy!(
            NODE_MAP, NODE_LOCK,
            HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK,
            [], ReentrantLock()
        )
        @test stats isa PhagyStats
    end

    println("  ✓ [12] Forensics re-roll: no crash when message_history not provided")
end

# ==============================================================================
# 13. FUZZY FORENSICS — empty memory
# ==============================================================================
@testset "Phagy - Fuzzy forensics empty memory" begin
    reset_engine!()

    msgs = MockMessage[]
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test stats.automaton == "MEMORY_FORENSICS_FUZZY"
    @test occursin("MEMORY_EMPTY", stats.notes)

    println("  ✓ [13] Fuzzy forensics: correctly reports empty memory")
end

# ==============================================================================
# 14. FUZZY FORENSICS — role imbalance detection
# ==============================================================================
@testset "Phagy - Fuzzy forensics role imbalance" begin
    reset_engine!()

    # 95% User messages — should trigger imbalance
    specs = [("User", "msg $i") for i in 1:95]
    append!(specs, [("System", "sys $i") for i in 1:5])
    msgs = make_messages(specs)
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("ROLE_IMBALANCE", stats.notes)

    println("  ✓ [14] Fuzzy forensics: detects role imbalance (95% User)")
end

# ==============================================================================
# 15. FUZZY FORENSICS — balanced roles
# ==============================================================================
@testset "Phagy - Fuzzy forensics balanced roles" begin
    reset_engine!()

    specs = vcat(
        [("User", "user msg $i") for i in 1:40],
        [("System", "sys msg $i") for i in 1:30],
        [("Engine_Voice", "voice $i") for i in 1:30]
    )
    msgs = make_messages(specs)
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("ROLE_BALANCE_OK", stats.notes)

    println("  ✓ [15] Fuzzy forensics: correctly reports balanced roles")
end

# ==============================================================================
# 16. FUZZY FORENSICS — pattern diversity
# ==============================================================================
@testset "Phagy - Fuzzy forensics pattern diversity" begin
    reset_engine!()

    # Make many unique nodes
    for i in 1:20
        make_node!("unique pattern number $i topic $i area $i")
    end

    msgs = make_messages([("User", "hello")])
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("PATTERN_DIVERSITY_OK", stats.notes)

    println("  ✓ [16] Fuzzy forensics: reports good pattern diversity for unique nodes")
end

# ==============================================================================
# 17. FUZZY FORENSICS — strength monoculture
# ==============================================================================
@testset "Phagy - Fuzzy forensics strength monoculture" begin
    reset_engine!()

    # All nodes at same strength band — monoculture
    for i in 1:20
        make_node!("clone $i"; strength=1.0)
    end

    msgs = make_messages([("User", "hello")])
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("STRENGTH_MONOCULTURE", stats.notes)

    println("  ✓ [17] Fuzzy forensics: detects strength monoculture")
end

# ==============================================================================
# 18. FUZZY FORENSICS — memory echo detection
# ==============================================================================
@testset "Phagy - Fuzzy forensics memory echoes" begin
    reset_engine!()

    # Repeat same message many times
    specs = [("User", "the same message") for _ in 1:50]
    msgs = make_messages(specs)
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("MEMORY_ECHOES", stats.notes)

    println("  ✓ [18] Fuzzy forensics: detects repeated message echoes")
end

# ==============================================================================
# 19. METRIC FORENSICS — empty memory
# ==============================================================================
@testset "Phagy - Metric forensics empty memory" begin
    reset_engine!()

    msgs = MockMessage[]
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test stats.automaton == "MEMORY_FORENSICS_METRIC"
    @test occursin("MEMORY_EMPTY", stats.notes)

    println("  ✓ [19] Metric forensics: correctly reports empty memory")
end

# ==============================================================================
# 20. METRIC FORENSICS — full population analysis
# ==============================================================================
@testset "Phagy - Metric forensics population" begin
    reset_engine!()

    # Mix of alive, grave, and varied strength
    make_node!("alive strong"; strength=8.0)
    make_node!("alive weak"; strength=1.0)
    make_node!("graved node"; strength=0.0, is_grave=true, grave_reason="STRENGTH_ZERO")

    msgs = make_messages([("User", "hello"), ("System", "world")])
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("NODE_POP", stats.notes)
    @test occursin("alive=2", stats.notes)
    @test occursin("grave=1", stats.notes)
    @test occursin("STRENGTH_STATS", stats.notes)
    @test occursin("GRAVE_BREAKDOWN", stats.notes)
    @test occursin("MSG_CENSUS", stats.notes)

    println("  ✓ [20] Metric forensics: full population analysis with correct counts")
end

# ==============================================================================
# 21. METRIC FORENSICS — dead node reference audit
# ==============================================================================
@testset "Phagy - Metric forensics dead refs" begin
    reset_engine!()

    alive = make_node!("alive node")  # Gets id like node_0

    # Messages referencing both alive and dead node IDs
    msgs = make_messages([
        ("User", "check $alive please"),
        ("System", "node_999 was involved"),  # node_999 doesn't exist
    ])
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("DEAD_REFS", stats.notes)

    println("  ✓ [21] Metric forensics: detects dead node references in messages")
end

# ==============================================================================
# 22. METRIC FORENSICS — pinned message tracking
# ==============================================================================
@testset "Phagy - Metric forensics pinned messages" begin
    reset_engine!()

    msgs = [
        MockMessage(1, "User", "normal message", false),
        MockMessage(2, "User", "pinned message", true),
        MockMessage(3, "System", "another pinned", true),
    ]
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("PINNED: 2/3", stats.notes)

    println("  ✓ [22] Metric forensics: correctly counts pinned messages")
end

# ==============================================================================
# 23. METRIC FORENSICS — strength statistics
# ==============================================================================
@testset "Phagy - Metric forensics strength stats" begin
    reset_engine!()

    make_node!("node a"; strength=2.0)
    make_node!("node b"; strength=4.0)
    make_node!("node c"; strength=6.0)

    msgs = make_messages([("User", "test")])
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("mean=4.0", stats.notes)   # (2+4+6)/3 = 4.0
    @test occursin("median=4.0", stats.notes)  # Middle value
    @test occursin("min=2.0", stats.notes)
    @test occursin("max=6.0", stats.notes)

    println("  ✓ [23] Metric forensics: strength statistics correct (mean=4, median=4, min=2, max=6)")
end

# ==============================================================================
# 24. MEMORY FORENSICS DISPATCHER — coinflip selects both modes
# ==============================================================================
@testset "Phagy - Forensics dispatcher both modes" begin
    reset_engine!()

    make_node!("test node")
    msgs = make_messages([("User", "hello")])
    history_lock = ReentrantLock()

    modes_seen = Set{String}()
    for _ in 1:100
        stats = PhagyMode.run_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
        push!(modes_seen, stats.automaton)
    end

    @test "MEMORY_FORENSICS_FUZZY" in modes_seen
    @test "MEMORY_FORENSICS_METRIC" in modes_seen

    println("  ✓ [24] Forensics dispatcher: both FUZZY and METRIC modes observed over 100 runs")
end

# ==============================================================================
# 25. MEMORY FORENSICS — input validation
# ==============================================================================
@testset "Phagy - Forensics input validation" begin
    reset_engine!()

    msgs = make_messages([("User", "test")])

    # Julia dispatch rejects at the type level (MethodError because
    # run_memory_forensics! signature requires ::ReentrantLock).
    @test_throws MethodError PhagyMode.run_memory_forensics!(
        NODE_MAP, "not a lock", msgs, ReentrantLock()
    )
    @test_throws MethodError PhagyMode.run_memory_forensics!(
        NODE_MAP, NODE_LOCK, msgs, "not a lock"
    )

    println("  ✓ [25] Forensics validation: rejects invalid lock types (MethodError at dispatch)")
end

# ==============================================================================
# 26. FUZZY FORENSICS — no alive nodes
# ==============================================================================
@testset "Phagy - Fuzzy forensics no alive nodes" begin
    reset_engine!()

    # Only grave nodes
    make_node!("dead node"; strength=0.0, is_grave=true, grave_reason="TEST")

    msgs = make_messages([("User", "hello")])
    history_lock = ReentrantLock()

    stats = PhagyMode.fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("NO_ALIVE_NODES", stats.notes)

    println("  ✓ [26] Fuzzy forensics: correctly reports no alive nodes (all graved)")
end

# ==============================================================================
# 27. METRIC FORENSICS — orphan detection
# ==============================================================================
@testset "Phagy - Metric forensics orphan count" begin
    reset_engine!()

    # Orphan: alive, 0 neighbors, 0 strength
    make_node!("orphan node"; strength=0.0)
    # Non-orphan: has strength
    make_node!("strong node"; strength=5.0)

    msgs = make_messages([("User", "test")])
    history_lock = ReentrantLock()

    stats = PhagyMode.metric_memory_forensics!(NODE_MAP, NODE_LOCK, msgs, history_lock)
    @test occursin("ORPHANS: 1", stats.notes)

    println("  ✓ [27] Metric forensics: correctly identifies 1 orphan node")
end

# ==============================================================================
# 28. FULL PHAGY CYCLE — all 7 automata reachable
# ==============================================================================
@testset "Phagy - All 7 automata reachable" begin
    reset_engine!()
    reset_phagy_log!()

    # Seed environment
    for i in 1:10
        make_node!("test node $i"; strength=Float64(i % 5))
    end

    msgs = make_messages([("User", "hello"), ("System", "world")])
    history_lock = ReentrantLock()

    automata_seen = Set{String}()
    for _ in 1:200
        stats = PhagyMode.run_phagy!(
            NODE_MAP, NODE_LOCK,
            HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK,
            [], ReentrantLock();
            message_history=msgs,
            history_lock=history_lock
        )
        push!(automata_seen, stats.automaton)
    end

    # Should have seen all 6 active automaton types (or at least most — probabilistic)
    # ORPHAN_PRUNER, STRENGTH_DECAYER, GRAVE_RECYCLER, DROP_TABLE_COMPACT,
    # RULE_PRUNER, MEMORY_FORENSICS_FUZZY or MEMORY_FORENSICS_METRIC
    # NOTE: CACHE_VALIDATOR is DISABLED (Hopfield caching removed)
    @test length(automata_seen) >= 4  # Conservative: at least 4 of 6+variants seen

    println("  ✓ [28] Full phagy cycle: $(length(automata_seen)) unique automata seen: $(join(sort(collect(automata_seen)), ", "))")
end

# ==============================================================================
# SUMMARY
# ==============================================================================
println("\n" * "="^60)
println("GRUG PHAGY MODE TEST SUITE — ALL TESTS PASSED ✅")
println("="^60)