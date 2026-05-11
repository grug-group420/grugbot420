# test_chatter_vote_swap.jl
# ==============================================================================
# GRUG v7.15 TESTS --- ChatterVoteSwap: cooldown, weak-only, semantic gate,
#                       weight jitter, disk-backed group selection
# ==============================================================================

using Test
using Random

include("../src/ChatterVoteSwap.jl")
using .ChatterVoteSwap

println("\n" * "=" ^ 60)
println("GRUG v7.15 ChatterVoteSwap TEST SUITE")
println("=" ^ 60)

# ==============================================================================
# [1] COOLDOWN --- 1 hour enforced per-node
# ==============================================================================
@testset "cooldown: 1-hour per-node" begin
    clear_chatter_cooldowns!()

    t0 = 1_000_000.0
    @test can_chatter_now("n_a"; now = t0) == true   # never chattered

    record_chatter_time!("n_a"; now = t0)
    @test can_chatter_now("n_a"; now = t0)                 == false
    @test can_chatter_now("n_a"; now = t0 + 1_000)         == false  # 1000s < 3600s
    @test can_chatter_now("n_a"; now = t0 + CHATTER_COOLDOWN_SECONDS - 1.0) == false
    @test can_chatter_now("n_a"; now = t0 + CHATTER_COOLDOWN_SECONDS)       == true
    @test can_chatter_now("n_a"; now = t0 + CHATTER_COOLDOWN_SECONDS + 1.0) == true

    # GRUG: Different node is independent.
    @test can_chatter_now("n_b"; now = t0) == true
end

# ==============================================================================
# [2] SEMANTIC GATE --- zero intensity very-rarely passes; saturating passes often
# ==============================================================================
@testset "should_swap_vote: intensity-biased coinflip" begin
    rng = MersenneTwister(0xBEEF)

    passes_zero = count(_ -> should_swap_vote(0.0; rng = rng), 1:2000)
    passes_sat  = count(_ -> should_swap_vote(SEMANTIC_INTENSITY_CAP; rng = rng),
                         1:2000)

    # Zero intensity -> p = 0.10, expected ~200 / 2000
    @test 100 < passes_zero < 350
    # Cap -> p capped at 0.95, expected ~1900 / 2000
    @test 1700 < passes_sat <= 2000
end

# ==============================================================================
# [3] SEMANTIC GATE --- bad inputs rejected loudly
# ==============================================================================
@testset "should_swap_vote: NaN/Inf/negative rejected" begin
    @test_throws ChatterVoteSwapError should_swap_vote(NaN)
    @test_throws ChatterVoteSwapError should_swap_vote(Inf)
    @test_throws ChatterVoteSwapError should_swap_vote(-0.01)
end

# ==============================================================================
# [4] ROUND RUNNER --- weak-only rule enforced
# ==============================================================================
@testset "run_vote_swap_round!: weak-only receiver" begin
    clear_chatter_cooldowns!()

    # GRUG: Build a stub "engine" with two nodes --- one weak, one strong.
    nodes = Dict(
        "strong" => (exists = true, strength = 9.0, action = "reason",
                     weight = 2.0,  is_weak = false),
        "weak"   => (exists = true, strength = 2.0, action = "greet",
                     weight = 1.0,  is_weak = true),
    )

    get_node(id) = nodes[id]
    # GRUG: Saturate semantic intensity so the gate always passes.
    get_semintensity(a, b) = SEMANTIC_INTENSITY_CAP

    apply_events = VoteSwapEvent[]
    apply_swap!(e) = (push!(apply_events, e); true)
    group_members(g) = ["strong", "weak"]

    stats = run_vote_swap_round!(
        ["g1"],
        get_node, get_semintensity, apply_swap!, group_members;
        rng = MersenneTwister(1), now = 100_000.0,
    )

    @test stats.swaps_accepted == 1   # exactly one weak receiver
    @test length(apply_events) == 1
    e = apply_events[1]
    @test e.sender_id   == "strong"
    @test e.receiver_id == "weak"
    @test e.donated_action == "reason"   # copied from the strong node
end

# ==============================================================================
# [5] ROUND RUNNER --- cooldown blocks second swap same hour
# ==============================================================================
@testset "run_vote_swap_round!: cooldown enforced across rounds" begin
    clear_chatter_cooldowns!()

    nodes = Dict(
        "strong" => (exists = true, strength = 9.0, action = "reason",
                     weight = 2.0, is_weak = false),
        "weak"   => (exists = true, strength = 2.0, action = "greet",
                     weight = 1.0, is_weak = true),
    )
    get_node(id) = nodes[id]
    get_semintensity(a, b) = SEMANTIC_INTENSITY_CAP
    apply_swap!(e) = true
    group_members(g) = ["strong", "weak"]

    # GRUG: Over multiple seeds the weak node must eventually succeed (at
    # saturated intensity the gate passes ~95% of calls). Drive one swap.
    accepted_round1 = false
    for seed in 1:20
        clear_chatter_cooldowns!()
        s = run_vote_swap_round!(
            ["g1"], get_node, get_semintensity, apply_swap!, group_members;
            rng = MersenneTwister(seed), now = 100.0,
        )
        if s.swaps_accepted == 1
            accepted_round1 = true
            break
        end
    end
    @test accepted_round1

    # GRUG: After a successful swap at t=100, the weak node is on cooldown.
    # A round run at t=3000 must reject because (3000 - 100) < 3600.
    # We explicitly record the cooldown to simulate the post-accepted-swap state.
    clear_chatter_cooldowns!()
    record_chatter_time!("weak"; now = 100.0)

    s2 = run_vote_swap_round!(
        ["g1"], get_node, get_semintensity, apply_swap!, group_members;
        rng = MersenneTwister(3), now = 3000.0,
    )
    @test s2.swaps_accepted   == 0
    @test s2.rejected_cooldown >= 1

    # Round 3 after cooldown expires: at least one of many seeds succeeds.
    accepted_round3 = false
    for seed in 1:20
        clear_chatter_cooldowns!()
        # GRUG: still within cooldown from implicit t=100 record in step above
        record_chatter_time!("weak"; now = 100.0)
        s3 = run_vote_swap_round!(
            ["g1"], get_node, get_semintensity, apply_swap!, group_members;
            rng = MersenneTwister(seed),
            now = 100.0 + CHATTER_COOLDOWN_SECONDS + 1.0,
        )
        if s3.swaps_accepted == 1
            accepted_round3 = true
            break
        end
    end
    @test accepted_round3
end

# ==============================================================================
# [6] ROUND RUNNER --- strong receiver rejected
# ==============================================================================
@testset "run_vote_swap_round!: strong receiver never copies" begin
    clear_chatter_cooldowns!()
    # GRUG: Both nodes strong --- no one is weak enough to receive.
    nodes = Dict(
        "A" => (exists = true, strength = 8.0, action = "x",
                weight = 1.0, is_weak = false),
        "B" => (exists = true, strength = 9.0, action = "y",
                weight = 1.0, is_weak = false),
    )
    get_node(id) = nodes[id]
    get_semintensity(a, b) = SEMANTIC_INTENSITY_CAP
    apply_swap!(e) = true
    group_members(g) = ["A", "B"]

    stats = run_vote_swap_round!(
        ["g"], get_node, get_semintensity, apply_swap!, group_members;
        rng = MersenneTwister(0), now = 1.0,
    )
    @test stats.swaps_accepted == 0
    @test stats.rejected_not_weak >= 1
end

# ==============================================================================
# [7] ROUND RUNNER --- per-round swap limit (at most one per node per round)
# ==============================================================================
@testset "run_vote_swap_round!: at most one swap per node per round" begin
    clear_chatter_cooldowns!()

    nodes = Dict(
        "strong_1" => (exists=true, strength=9.0, action="a",
                       weight=1.0, is_weak=false),
        "strong_2" => (exists=true, strength=9.5, action="b",
                       weight=1.0, is_weak=false),
        "weak"     => (exists=true, strength=1.0, action="x",
                       weight=1.0, is_weak=true),
    )
    get_node(id) = nodes[id]
    get_semintensity(a, b) = SEMANTIC_INTENSITY_CAP
    apply_swap!(e) = true
    # GRUG: Same weak node appears in TWO groups this round.
    group_members(g) = g == "g1" ? ["strong_1", "weak"] : ["strong_2", "weak"]

    stats = run_vote_swap_round!(
        ["g1", "g2"], get_node, get_semintensity, apply_swap!, group_members;
        rng = MersenneTwister(0), now = 1.0,
    )
    # GRUG: Weak node is in both groups but must only accept ONE swap per round.
    @test stats.swaps_accepted == 1
end

# ==============================================================================
# [8] WEIGHT JITTER --- zero-mean, bounded, zero passes through
# ==============================================================================
@testset "internal jitter: zero-mean bounded" begin
    # GRUG: Use the internal symbol via fully qualified path.
    jitter = ChatterVoteSwap.jitter_vote_weight
    rng = MersenneTwister(999)

    # Zero passes unchanged.
    @test jitter(0.0; rng = rng) == 0.0

    # Bounded by ratio * |w|.
    w = 2.0
    for _ in 1:500
        out = jitter(w; rng = rng)
        @test abs(out - w) <= WEIGHT_JITTER_RATIO * abs(w) + 1e-12
    end

    # Zero-mean over many samples.
    samples = [jitter(w; rng = rng) for _ in 1:20_000]
    @test isapprox(sum(samples) / length(samples), w; atol = 0.01)
end

# ==============================================================================
# [9] INTERNAL --- bare-weight coinflip attaches default sometimes
# ==============================================================================
@testset "internal: bare weight coinflip" begin
    maybe_attach = ChatterVoteSwap.maybe_attach_default_weight
    rng = MersenneTwister(12345)

    # GRUG: Non-zero weights pass through unchanged.
    for w in [0.1, 1.0, -0.5, 2.5]
        @test maybe_attach(w; rng = rng) == w
    end

    # GRUG: Zero weight flips to DONATED_BARE_WEIGHT on a DONATED_BARE_WEIGHT_PROB coin.
    outcomes = [maybe_attach(0.0; rng = rng) for _ in 1:2000]
    count_attached = count(==(DONATED_BARE_WEIGHT), outcomes)
    # Expected ~1000. Allow slop.
    @test 800 < count_attached < 1200
end

println("\n" * "=" ^ 60)
println("\u2705  ChatterVoteSwap tests COMPLETE")
println("=" ^ 60)
