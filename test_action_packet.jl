# test_action_packet.jl
# ==============================================================================
# GRUG TEST: Action packet parser — pipe-delimited format with inline negatives.
# GRUG say: parser is cave gate. Must handle clean input AND messy input.
# Format: "action[neg1, neg2]^weight | action2^weight | action3[neg3]^3.5"
#
# Return signature:
#   positives    :: Vector{Tuple{String, Float64}}           — (name, weight) pairs
#   all_negatives:: Vector{String}                           — deduped union of all negs
#   action_items :: Vector{Tuple{String, Float64, Vector{String}}} — (name, weight, per-action negs)
# ==============================================================================

include("stochastichelper.jl"); using .CoinFlipHeader
include("patternscanner.jl");   using .PatternScanner
include("ImageSDF.jl");         using .ImageSDF
include("EyeSystem.jl");        using .EyeSystem
include("ChatterMode.jl");      using .ChatterMode
include("SemanticVerbs.jl");    using .SemanticVerbs
include("ActionTonePredictor.jl"); using .ActionTonePredictor

using JSON, Distributions, Random, Test

include("engine.jl")

println("\n" * "="^60)
println("GRUG ACTION PACKET PARSER TEST SUITE")
println("="^60)

# ==============================================================================
# 1. BASIC — Single action, no negatives, no weight
# ==============================================================================
@testset "Parser - Single Action (bare)" begin
    pos, neg, items = parse_action_packet("greet")
    @test length(pos) == 1
    @test pos[1][1] == "greet"      # name
    @test pos[1][2] ≈ 1.0           # default weight
    @test isempty(neg)
    @test length(items) == 1
    @test items[1][1] == "greet"    # name
    @test items[1][2] ≈ 1.0         # weight
    @test isempty(items[1][3])       # negatives

    println("  ✓ [1] Single bare action: 'greet' → weight=1.0, no negatives")
end

# ==============================================================================
# 2. BASIC — Single action with weight
# ==============================================================================
@testset "Parser - Single Action + Weight" begin
    pos, neg, items = parse_action_packet("reason^3.5")
    @test pos[1][1] == "reason"
    @test pos[1][2] ≈ 3.5
    @test isempty(neg)
    @test items[1][1] == "reason"
    @test items[1][2] ≈ 3.5

    println("  ✓ [2] Single action with weight: 'reason^3.5' → weight=3.5")
end

# ==============================================================================
# 3. BASIC — Single action with inline negatives
# ==============================================================================
@testset "Parser - Single Action + Negatives" begin
    pos, neg, items = parse_action_packet("greet[dont frown, dont insult]^2")
    @test pos[1][1] == "greet"
    @test pos[1][2] ≈ 2.0
    @test "dont frown" in neg
    @test "dont insult" in neg
    @test length(neg) == 2
    @test items[1][1] == "greet"
    @test items[1][2] ≈ 2.0
    @test "dont frown" in items[1][3]
    @test "dont insult" in items[1][3]

    println("  ✓ [3] Single action + negatives: 'greet[dont frown, dont insult]^2'")
end

# ==============================================================================
# 4. PIPE — Multiple actions, pipe-delimited
# ==============================================================================
@testset "Parser - Multiple Pipe-Delimited Actions" begin
    pos, neg, items = parse_action_packet("greet^3 | reason^2 | analyze^1")
    @test length(pos) == 3
    names = [p[1] for p in pos]
    @test "greet" in names
    @test "reason" in names
    @test "analyze" in names
    @test isempty(neg)
    @test length(items) == 3

    # Check individual items by finding them
    greet_item = filter(i -> i[1] == "greet", items)[1]
    @test greet_item[2] ≈ 3.0

    reason_item = filter(i -> i[1] == "reason", items)[1]
    @test reason_item[2] ≈ 2.0

    analyze_item = filter(i -> i[1] == "analyze", items)[1]
    @test analyze_item[2] ≈ 1.0

    println("  ✓ [4] Multiple pipe-delimited: 'greet^3 | reason^2 | analyze^1'")
end

# ==============================================================================
# 5. PIPE — Multiple actions with mixed negatives
# ==============================================================================
@testset "Parser - Pipe + Mixed Negatives" begin
    packet = "greet[dont frown]^3 | reason^2 | warn[dont panic, dont scream]^1"
    pos, neg, items = parse_action_packet(packet)

    @test length(pos) == 3
    @test length(items) == 3

    # All negatives collected in deduped union
    @test "dont frown" in neg
    @test "dont panic" in neg
    @test "dont scream" in neg
    @test length(neg) == 3

    # Per-action negatives
    greet_item = filter(i -> i[1] == "greet", items)[1]
    @test "dont frown" in greet_item[3]
    @test length(greet_item[3]) == 1

    warn_item = filter(i -> i[1] == "warn", items)[1]
    @test "dont panic" in warn_item[3]
    @test "dont scream" in warn_item[3]
    @test length(warn_item[3]) == 2

    reason_item = filter(i -> i[1] == "reason", items)[1]
    @test isempty(reason_item[3])

    println("  ✓ [5] Pipe + mixed negatives: per-action negatives collected correctly")
end

# ==============================================================================
# 6. EDGE — Action names with commas (the whole reason for pipe format!)
# ==============================================================================
@testset "Parser - Action Names Containing Commas" begin
    packet = "plan, execute^2 | greet^1"
    pos, neg, items = parse_action_packet(packet)

    @test length(items) == 2
    plan_item = filter(i -> contains(i[1], "plan"), items)[1]
    @test plan_item[1] == "plan, execute"
    @test plan_item[2] ≈ 2.0

    println("  ✓ [6] Action name with comma: 'plan, execute^2' parsed correctly via pipe delimiter")
end

# ==============================================================================
# 7. EDGE — Whitespace handling (extra spaces around pipes)
# ==============================================================================
@testset "Parser - Whitespace Tolerance" begin
    packet = "  greet^2  |  reason^1  |  analyze^3  "
    pos, neg, items = parse_action_packet(packet)

    @test length(items) == 3
    names = [i[1] for i in items]
    @test "greet" in names
    @test "reason" in names
    @test "analyze" in names

    # No leading/trailing whitespace in action names
    for item in items
        @test item[1] == strip(item[1])
    end

    println("  ✓ [7] Whitespace tolerance: extra spaces around pipes handled correctly")
end

# ==============================================================================
# 8. EDGE — Negatives with extra whitespace
# ==============================================================================
@testset "Parser - Negative Whitespace" begin
    packet = "greet[  dont frown , dont insult  ]^2"
    pos, neg, items = parse_action_packet(packet)

    @test "dont frown" in neg
    @test "dont insult" in neg
    @test items[1][1] == "greet"

    println("  ✓ [8] Negatives with extra whitespace stripped correctly")
end

# ==============================================================================
# 9. EDGE — Action with negatives but no weight (defaults to 1.0)
# ==============================================================================
@testset "Parser - Negatives Without Weight" begin
    packet = "comfort[dont dismiss]"
    pos, neg, items = parse_action_packet(packet)

    @test pos[1][1] == "comfort"
    @test pos[1][2] ≈ 1.0
    @test "dont dismiss" in neg
    @test items[1][1] == "comfort"
    @test items[1][2] ≈ 1.0

    println("  ✓ [9] Negatives without weight: defaults to 1.0")
end

# ==============================================================================
# 10. EDGE — Empty negatives bracket (no actual negatives listed)
# ==============================================================================
@testset "Parser - Empty Negatives Bracket" begin
    packet = "greet[]^2"
    pos, neg, items = parse_action_packet(packet)

    @test pos[1][1] == "greet"
    @test pos[1][2] ≈ 2.0
    @test isempty(neg)
    @test isempty(items[1][3])

    println("  ✓ [10] Empty negatives bracket: 'greet[]^2' → no negatives, weight=2.0")
end

# ==============================================================================
# 11. ERROR — Bad weight (negative number, zero, non-numeric)
# ==============================================================================
@testset "Parser - Bad Weight Rejection" begin
    @test_throws ErrorException parse_action_packet("greet^-1")
    @test_throws ErrorException parse_action_packet("greet^0")
    @test_throws ErrorException parse_action_packet("greet^abc")

    println("  ✓ [11] Bad weights (negative, zero, non-numeric) correctly rejected")
end

# ==============================================================================
# 12. ERROR — Empty packet
# ==============================================================================
@testset "Parser - Empty Packet Rejection" begin
    @test_throws ErrorException parse_action_packet("")
    @test_throws ErrorException parse_action_packet("   ")

    println("  ✓ [12] Empty/whitespace packets correctly rejected")
end

# ==============================================================================
# 13. REAL-WORLD — Seed node format from Main.jl
# ==============================================================================
@testset "Parser - Real-World Seed Packets" begin
    # From the actual Main.jl seed nodes
    packet1 = "greet[dont frown, dont insult]^3 | welcome[dont be rude]^2 | smile^1"
    pos1, neg1, items1 = parse_action_packet(packet1)
    @test length(items1) == 3
    @test "dont frown" in neg1
    @test "dont insult" in neg1
    @test "dont be rude" in neg1

    packet2 = "reason[dont guess]^3 | analyze[dont oversimplify]^2 | deduce^1"
    pos2, neg2, items2 = parse_action_packet(packet2)
    @test length(items2) == 3
    @test "dont guess" in neg2
    @test "dont oversimplify" in neg2

    packet3 = "warn[dont ignore]^3 | alert[dont panic]^2 | caution^1"
    pos3, neg3, items3 = parse_action_packet(packet3)
    @test length(items3) == 3
    @test "dont ignore" in neg3
    @test "dont panic" in neg3

    println("  ✓ [13] Real-world seed packets from Main.jl parse correctly")
end

# ==============================================================================
# 14. WEIGHT BIAS — Higher weight actions should be selected more often
# ==============================================================================
@testset "Parser - Weight-Biased Selection" begin
    packet = "heavy^10 | light^1"

    # select_action returns (action_name::String, negatives::Vector{String})
    heavy_count = 0
    trials = 2000
    for _ in 1:trials
        action_name, _ = select_action(packet)
        if action_name == "heavy"
            heavy_count += 1
        end
    end
    heavy_rate = heavy_count / trials

    # heavy has 10x the weight of light, so should be selected ~91% of the time
    @test heavy_rate > 0.75
    @test heavy_rate < 0.99

    println("  ✓ [14] Weight-biased selection: heavy(^10)=$(round(heavy_rate*100, digits=1))%, light(^1)=$(round((1-heavy_rate)*100, digits=1))%")
end

# ==============================================================================
# 15. INTEGRATION — parse_action_packet return values used by engine functions
# ==============================================================================
@testset "Parser - Integration with Engine Functions" begin
    ctx = Dict{String,Any}("system_prompt" => "Integration test node.")
    nid = create_node("integration test alpha", "comfort[dont dismiss]^3 | reason[dont guess]^2", ctx, String[])

    @test haskey(NODE_MAP, nid)
    node = NODE_MAP[nid]

    # select_action returns (action_name, negatives) tuple
    action_name, action_negs = select_action(node.action_packet)
    @test action_name in ["comfort", "reason"]
    @test isa(action_negs, Vector{String})

    # cast_explicit_vote takes (cmd_name, node_id) — should work with new format
    vote = cast_explicit_vote("comfort", nid)
    @test vote.node_id == nid
    @test vote.confidence > 0.0

    println("  ✓ [15] Engine integration: create_node + select_action + cast_explicit_vote work with new format")
end

# ==============================================================================
# 16. SINGLE ACTION — No pipe, no bracket, just weight
# ==============================================================================
@testset "Parser - Minimal Single Actions" begin
    # Just action name, no weight, no negatives
    _, _, items1 = parse_action_packet("flee")
    @test items1[1][1] == "flee"
    @test items1[1][2] ≈ 1.0

    # Integer weight
    _, _, items2 = parse_action_packet("think^5")
    @test items2[1][1] == "think"
    @test items2[1][2] ≈ 5.0

    # Decimal weight
    _, _, items3 = parse_action_packet("ponder^0.5")
    @test items3[1][1] == "ponder"
    @test items3[1][2] ≈ 0.5

    println("  ✓ [16] Minimal single actions: bare, integer weight, decimal weight")
end

# ==============================================================================
# 17. DEDUPLICATION — Same negative across multiple actions
# ==============================================================================
@testset "Parser - Negative Deduplication" begin
    packet = "greet[dont yell]^2 | warn[dont yell, dont panic]^1"
    pos, neg, items = parse_action_packet(packet)

    # "dont yell" appears in both actions but should be deduped in all_negatives
    @test count(n -> n == "dont yell", neg) == 1
    @test "dont panic" in neg
    @test length(neg) == 2

    # But per-action negatives should still have their own copies
    greet_item = filter(i -> i[1] == "greet", items)[1]
    @test "dont yell" in greet_item[3]

    warn_item = filter(i -> i[1] == "warn", items)[1]
    @test "dont yell" in warn_item[3]
    @test "dont panic" in warn_item[3]

    println("  ✓ [17] Negative deduplication: shared neg appears once in all_negatives, preserved per-action")
end

# ==============================================================================
# 18. MANY ACTIONS — Stress test with 10 pipe-delimited actions
# ==============================================================================
@testset "Parser - Many Actions Stress" begin
    parts = ["action_$i^$(i)" for i in 1:10]
    packet = join(parts, " | ")
    pos, neg, items = parse_action_packet(packet)

    @test length(items) == 10
    @test isempty(neg)

    # Verify each action has correct weight
    for i in 1:10
        item = filter(x -> x[1] == "action_$i", items)[1]
        @test item[2] ≈ Float64(i)
    end

    println("  ✓ [18] Stress: 10 pipe-delimited actions, all weights correct")
end

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("✅  ALL ACTION PACKET PARSER TESTS PASSED")
println("="^60 * "\n")