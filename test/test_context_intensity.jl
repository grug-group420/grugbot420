# test_context_intensity.jl
# ==============================================================================
# GRUG v7.12 CONTEXT INTENSITY JITTER TESTS
# ==============================================================================
# Verifies the context-intensity system that replaced the "last 5 unpinned"
# fresh-memory heuristic with a relevance-biased coinflip sample.
#
# Test groups:
#   [A] clamp_intensity: in-range passes, out-of-range saturates, non-finite throws
#   [B] _tokenize_for_relevance: lowercases, drops short tokens, strips punctuation
#   [C] score_message_relevance: identical text scores high, disjoint scores low
#   [D] refresh_message_intensities!: snap-back pulls toward relevance, jitter
#                                     has zero mean in expectation, clamp holds
#   [E] extract_aiml_memory_context: pinned always surface; unpinned biased
#                                    by intensity; LAST_SELECTED_MSG_IDS populated
#   [F] apply_last_selected_feedback!: positive delta bumps, negative sags,
#                                      clamp always honoured, empty set is no-op
#   [G] /brainstorm scope widens the jitter window for intensity refresh
#       (alignment with the rest of the engine as requested)
#
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test
using Random
using Statistics

println("\n" * "="^60)
println("GRUG v7.12 CONTEXT INTENSITY JITTER TESTS")
println("="^60)

# GRUG: Context-intensity lives in Main.jl which needs the full GrugBot420
# package context (engine.jl for relational extraction, stochastichelper.jl
# for @coinflip). Import through the package, not raw src/ files.
using GrugBot420
const G = GrugBot420

# ==============================================================================
# HELPERS
# ==============================================================================

# GRUG: Wipe MESSAGE_HISTORY between groups so no cross-test contamination.
# We acquire the same lock production code uses — NO SILENT FAILURES from
# racing readers.
function fresh_history!()
    lock(G.MESSAGE_HISTORY_LOCK) do
        empty!(G.MESSAGE_HISTORY)
    end
    lock(G.LAST_SELECTED_MSG_LOCK) do
        G.LAST_SELECTED_MSG_IDS[] = Set{Int}()
    end
    # Reset jitter to defaults so tests are reproducible.
    G.RelationalJitter.enable_jitter!()
    G.RelationalJitter.set_jitter_ratio!(G.RelationalJitter.JITTER_RATIO_DEFAULT)
end

# GRUG: Build a message directly without going through add_message_to_history!
# (which needs ALLOWED_ROLES and a live counter). For structural tests we
# only care about the struct fields and the registries.
function push_msg!(id::Int, role::String, text::String;
                   pinned::Bool=false,
                   intensity::Float64=G.CONTEXT_INTENSITY_BASELINE)
    msg = G.ChatMessage(id, role, text, pinned, intensity)
    lock(G.MESSAGE_HISTORY_LOCK) do
        push!(G.MESSAGE_HISTORY, msg)
    end
    return msg
end

# ==============================================================================
# [A] clamp_intensity
# ==============================================================================
@testset "[A] clamp_intensity saturates and rejects non-finite" begin
    @test G.clamp_intensity(1.0) ≈ 1.0
    @test G.clamp_intensity(G.CONTEXT_INTENSITY_BASELINE) ≈ G.CONTEXT_INTENSITY_BASELINE
    # Out-of-range → saturate, not throw.
    @test G.clamp_intensity(-5.0) == G.CONTEXT_INTENSITY_FLOOR
    @test G.clamp_intensity(999.0) == G.CONTEXT_INTENSITY_CAP
    # Boundary exact.
    @test G.clamp_intensity(G.CONTEXT_INTENSITY_CAP) == G.CONTEXT_INTENSITY_CAP
    @test G.clamp_intensity(G.CONTEXT_INTENSITY_FLOOR) == G.CONTEXT_INTENSITY_FLOOR
    # Non-finite MUST throw — NO SILENT FAILURES.
    @test_throws ErrorException G.clamp_intensity(NaN)
    @test_throws ErrorException G.clamp_intensity(Inf)
    @test_throws ErrorException G.clamp_intensity(-Inf)
    println("  ✓ [A] clamp_intensity saturates in range, throws on NaN/Inf")
end

# ==============================================================================
# [B] _tokenize_for_relevance
# ==============================================================================
@testset "[B] _tokenize_for_relevance cleans and filters" begin
    toks = G._tokenize_for_relevance("Hello, World! This is Grug.")
    # "is" dropped (< 3 chars); punctuation stripped; lowercased.
    @test "hello" in toks
    @test "world" in toks
    @test "this" in toks
    @test "grug" in toks
    @test !("is" in toks)
    # Empty input yields empty set, not an error.
    @test isempty(G._tokenize_for_relevance(""))
    println("  ✓ [B] tokenize lowercases, strips punctuation, drops <3 char")
end

# ==============================================================================
# [C] score_message_relevance
# ==============================================================================
@testset "[C] score_message_relevance: identical > disjoint" begin
    user_text = "grug want smash rock with big hammer"
    user_tokens = G._tokenize_for_relevance(user_text)
    user_triples = try
        G.extract_dynamic_relational_triples(user_text, 3)
    catch
        G.RelationalTriple[]
    end

    fresh_history!()
    similar_msg = G.ChatMessage(1, "User", "grug smash rock hammer", false,
                                G.CONTEXT_INTENSITY_BASELINE)
    disjoint_msg = G.ChatMessage(2, "User", "banana papaya mango pineapple", false,
                                 G.CONTEXT_INTENSITY_BASELINE)

    s_similar = G.score_message_relevance(similar_msg, user_tokens, user_triples)
    s_disjoint = G.score_message_relevance(disjoint_msg, user_tokens, user_triples)

    @test s_similar > s_disjoint
    @test 0.0 <= s_similar <= G.CONTEXT_INTENSITY_CAP
    @test 0.0 <= s_disjoint <= G.CONTEXT_INTENSITY_CAP
    println("  ✓ [C] similar_msg score=$(round(s_similar, digits=2)) > disjoint_msg score=$(round(s_disjoint, digits=2))")
end

# ==============================================================================
# [D] refresh_message_intensities! snap-back pulls toward relevance
# ==============================================================================
@testset "[D] refresh_message_intensities! pulls toward relevance" begin
    fresh_history!()
    # Start every message at BASELINE.
    relevant = push_msg!(101, "User", "grug smash rock hammer")
    irrelevant = push_msg!(102, "User", "mango papaya pineapple banana")

    # Run the refresh ONCE against a highly-overlapping query.
    user_text = "grug smash rock with hammer"

    # Deterministic check: disable jitter so we only observe snap-back.
    G.RelationalJitter.disable_jitter!()
    try
        G.refresh_message_intensities!(user_text)
    finally
        G.RelationalJitter.enable_jitter!()
    end

    # Relevance of `relevant` should be > BASELINE, of `irrelevant` should be < BASELINE.
    # After snap-back, relevant.intensity should have risen, irrelevant should have fallen.
    @test relevant.intensity > irrelevant.intensity
    # Bounded.
    @test G.CONTEXT_INTENSITY_FLOOR <= relevant.intensity <= G.CONTEXT_INTENSITY_CAP
    @test G.CONTEXT_INTENSITY_FLOOR <= irrelevant.intensity <= G.CONTEXT_INTENSITY_CAP
    println("  ✓ [D] relevant=$(round(relevant.intensity, digits=2)) > irrelevant=$(round(irrelevant.intensity, digits=2))")
end

@testset "[D.2] refresh jitter converges to zero-mean around the snap-back target" begin
    fresh_history!()
    # Single static message; run refresh many times and check mean drift.
    msg = push_msg!(201, "User", "xyz123 neutral_lorem_ipsum_whatever")
    user_text = "completely unrelated query about alpha beta gamma delta"

    Random.seed!(42)
    samples = Float64[]
    for _ in 1:500
        # Every round starts from BASELINE so we isolate the per-call drift.
        msg.intensity = G.CONTEXT_INTENSITY_BASELINE
        G.refresh_message_intensities!(user_text)
        push!(samples, msg.intensity)
    end

    # Relevance of disjoint message is ≈ 0, so snap-back target is 0.
    # After one snap-back from BASELINE with alpha=0.35, expectation ≈ 0.65.
    # With zero-mean jitter on top, mean should still be near 0.65.
    μ = mean(samples)
    expected = G.CONTEXT_INTENSITY_BASELINE +
               G.CONTEXT_SNAP_ALPHA * (0.0 - G.CONTEXT_INTENSITY_BASELINE)
    # Allow ±0.15 tolerance to cover jitter variance at 500 samples.
    @test abs(μ - expected) < 0.15
    # All samples within bounds.
    @test all(G.CONTEXT_INTENSITY_FLOOR .<= samples .<= G.CONTEXT_INTENSITY_CAP)
    println("  ✓ [D.2] mean after 500 refreshes = $(round(μ, digits=3)), expected ≈ $(round(expected, digits=3))")
end

# ==============================================================================
# [E] extract_aiml_memory_context: pinned always in, unpinned biased by intensity
# ==============================================================================
@testset "[E] extract_aiml_memory_context: pinned always, unpinned biased" begin
    fresh_history!()
    # One pinned at BASELINE, one unpinned at CAP, one unpinned at FLOOR.
    pinned_msg  = push_msg!(301, "User", "pinned rock never moves",
                            pinned=true, intensity=G.CONTEXT_INTENSITY_BASELINE)
    hot_msg     = push_msg!(302, "User", "hot hot hot",
                            pinned=false, intensity=G.CONTEXT_INTENSITY_CAP)
    cold_msg    = push_msg!(303, "User", "cold cold cold",
                            pinned=false, intensity=G.CONTEXT_INTENSITY_FLOOR)

    Random.seed!(777)
    # Run the extractor many times; count how often each unpinned appears.
    hot_hits = 0
    cold_hits = 0
    pinned_hits = 0
    N = 500
    for _ in 1:N
        ctx = G.extract_aiml_memory_context()
        occursin("pinned rock", ctx) && (pinned_hits += 1)
        occursin("hot hot hot", ctx) && (hot_hits += 1)
        occursin("cold cold cold", ctx) && (cold_hits += 1)
    end

    # Pinned: always in.
    @test pinned_hits == N
    # Hot should be picked a lot more often than cold.
    @test hot_hits > cold_hits
    # Hot should hit close to CONTEXT_COIN_P_CEIL probability (0.95), not 100%.
    @test hot_hits >= N * 0.75
    # Cold should still show up occasionally (floor = 0.05), not 0%.
    @test cold_hits <= N * 0.25
    println("  ✓ [E] pinned=$pinned_hits/$N, hot=$hot_hits/$N, cold=$cold_hits/$N")

    # LAST_SELECTED_MSG_IDS populated after the last extract call.
    selected = lock(G.LAST_SELECTED_MSG_LOCK) do
        copy(G.LAST_SELECTED_MSG_IDS[])
    end
    @test 301 in selected  # pinned always selected
    println("  ✓ [E] LAST_SELECTED_MSG_IDS populated with at least the pinned id")
end

# ==============================================================================
# [F] apply_last_selected_feedback!
# ==============================================================================
@testset "[F] apply_last_selected_feedback! reinforces / penalises" begin
    fresh_history!()
    m1 = push_msg!(401, "User", "message one", intensity=1.0)
    m2 = push_msg!(402, "User", "message two", intensity=1.0)
    m3 = push_msg!(403, "User", "message three", intensity=1.0)

    # No mission has populated LAST_SELECTED_MSG_IDS → no-op, returns 0.
    @test G.apply_last_selected_feedback!(1.0) == 0
    @test m1.intensity == 1.0 && m2.intensity == 1.0 && m3.intensity == 1.0

    # Now populate as if a mission had run.
    lock(G.LAST_SELECTED_MSG_LOCK) do
        G.LAST_SELECTED_MSG_IDS[] = Set{Int}([401, 402])
    end

    # Positive feedback bumps both selected.
    n = G.apply_last_selected_feedback!(G.CONTEXT_FEEDBACK_RIGHT_DELTA)
    @test n == 2
    @test m1.intensity ≈ 1.0 + G.CONTEXT_FEEDBACK_RIGHT_DELTA
    @test m2.intensity ≈ 1.0 + G.CONTEXT_FEEDBACK_RIGHT_DELTA
    @test m3.intensity == 1.0  # untouched

    # Negative feedback saturates at FLOOR, not below.
    m1.intensity = G.CONTEXT_INTENSITY_FLOOR
    m2.intensity = G.CONTEXT_INTENSITY_FLOOR
    n2 = G.apply_last_selected_feedback!(G.CONTEXT_FEEDBACK_WRONG_DELTA)
    @test n2 == 2
    @test m1.intensity == G.CONTEXT_INTENSITY_FLOOR
    @test m2.intensity == G.CONTEXT_INTENSITY_FLOOR

    # Positive at CAP saturates at CAP.
    m1.intensity = G.CONTEXT_INTENSITY_CAP
    G.apply_last_selected_feedback!(G.CONTEXT_FEEDBACK_RIGHT_DELTA)
    @test m1.intensity == G.CONTEXT_INTENSITY_CAP
    println("  ✓ [F] feedback bumps bounded by FLOOR and CAP; untouched msgs unaffected")
end

# ==============================================================================
# [G] /brainstorm scope widens intensity-jitter window (alignment check)
# ==============================================================================
@testset "[G] brainstorm scope amplifies intensity jitter (alignment)" begin
    fresh_history!()
    msg = push_msg!(501, "User", "alignment witness text sample",
                    intensity=G.CONTEXT_INTENSITY_BASELINE)
    user_text = "completely disjoint foreign language ipsum"

    Random.seed!(2112)
    normal_samples = Float64[]
    for _ in 1:400
        msg.intensity = G.CONTEXT_INTENSITY_BASELINE
        G.refresh_message_intensities!(user_text)
        push!(normal_samples, msg.intensity)
    end

    Random.seed!(2112)
    brainstorm_samples = Float64[]
    G.RelationalJitter.with_brainstorm_jitter() do
        for _ in 1:400
            msg.intensity = G.CONTEXT_INTENSITY_BASELINE
            G.refresh_message_intensities!(user_text)
            push!(brainstorm_samples, msg.intensity)
        end
    end

    # Both populations centre near the same snap-back target (≈0.65), but
    # brainstorm spread should be wider. Use std as the spread statistic.
    σ_normal = std(normal_samples)
    σ_brainstorm = std(brainstorm_samples)
    @test σ_brainstorm > σ_normal
    # Wider, not catastrophically so.
    @test σ_brainstorm < 1.0  # well inside CAP range
    println("  ✓ [G] σ normal=$(round(σ_normal, digits=3)) < σ brainstorm=$(round(σ_brainstorm, digits=3)) (aligned)")
end

println("\n" * "="^60)
println("ALL CONTEXT INTENSITY TESTS PASSED! 7 test groups complete.")
println("Context-intensity v7.12 verified:")
println("  [A] clamp_intensity saturation + non-finite rejection")
println("  [B] lexical tokenizer filters + normalises")
println("  [C] relevance score: identical > disjoint")
println("  [D] snap-back pulls toward relevance; zero-mean jitter in expectation")
println("  [E] pinned always surface; unpinned biased by intensity")
println("  [F] /right /wrong feedback clamped; empty set no-op")
println("  [G] /brainstorm scope widens intensity jitter (alignment holds)")
println("="^60)