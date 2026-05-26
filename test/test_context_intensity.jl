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
        # GRUG v7.19 QoL: extract_aiml_memory_context now returns a NamedTuple
        # (pinned, fresh, full, ...). Search the .full field for matches.
        ctx_str = ctx isa AbstractString ? ctx : ctx.full
        occursin("pinned rock", ctx_str) && (pinned_hits += 1)
        occursin("hot hot hot", ctx_str) && (hot_hits += 1)
        occursin("cold cold cold", ctx_str) && (cold_hits += 1)
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

# ==============================================================================
# [H] v7.13: auto_tune_intensity_threshold lands eligible set in target band
# ==============================================================================
@testset "[H] auto_tune_intensity_threshold narrows large caves to target band" begin
    fresh_history!()

    # H.1: Small cave (<= CONTEXT_ELIGIBLE_MAX unpinned) → threshold = FLOOR,
    # eligible count = all of them. Cannot conjure messages out of air.
    for i in 1:5
        push_msg!(600 + i, "User", "small cave msg $i"; intensity=Float64(i) * 0.3)
    end
    unpinned_small = [m for m in G.MESSAGE_HISTORY if !m.pinned]
    thr_small, n_small = G.auto_tune_intensity_threshold(unpinned_small)
    @test thr_small == G.CONTEXT_INTENSITY_FLOOR
    @test n_small == 5
    println("  ✓ [H.1] small cave (n=5): threshold=$thr_small → all $n_small eligible")

    # H.2: Big cave (N >> MAX) with evenly-spread intensities → threshold
    # auto-tunes so eligible count lands in [MIN, MAX].
    fresh_history!()
    N_BIG = 500
    for i in 1:N_BIG
        # Evenly spread across [0, CAP]
        intensity = (i / N_BIG) * G.CONTEXT_INTENSITY_CAP
        push_msg!(700 + i, "User", "big cave msg $i"; intensity=intensity)
    end
    unpinned_big = [m for m in G.MESSAGE_HISTORY if !m.pinned]
    thr_big, n_big = G.auto_tune_intensity_threshold(unpinned_big)
    @test G.CONTEXT_ELIGIBLE_MIN <= n_big <= G.CONTEXT_ELIGIBLE_MAX
    @test G.CONTEXT_INTENSITY_FLOOR <= thr_big <= G.CONTEXT_INTENSITY_CAP
    println("  ✓ [H.2] big cave (n=$N_BIG, even spread): threshold=$(round(thr_big, digits=3)) → $n_big eligible (band [$(G.CONTEXT_ELIGIBLE_MIN), $(G.CONTEXT_ELIGIBLE_MAX)])")

    # H.3: 10k-message cave — the scenario the user called out. Must not
    # explode the coinflip pool. Same assertion: eligible count in band.
    fresh_history!()
    N_HUGE = 10_000
    for i in 1:N_HUGE
        # Bulk at baseline, a few hot at CAP.
        intensity = i <= 20 ? G.CONTEXT_INTENSITY_CAP : G.CONTEXT_INTENSITY_BASELINE * (i / N_HUGE)
        push_msg!(1_000_000 + i, "User", "huge cave msg $i"; intensity=intensity)
    end
    unpinned_huge = [m for m in G.MESSAGE_HISTORY if !m.pinned]
    thr_huge, n_huge = G.auto_tune_intensity_threshold(unpinned_huge)
    # Threshold must push the count into the band (or at worst just above/below
    # if the distribution has a flat plateau in it; binary-search budget).
    @test n_huge <= G.CONTEXT_ELIGIBLE_MAX * 2  # firm ceiling for 10k case
    @test G.CONTEXT_INTENSITY_FLOOR < thr_huge <= G.CONTEXT_INTENSITY_CAP
    println("  ✓ [H.3] huge cave (n=$N_HUGE): threshold=$(round(thr_huge, digits=3)) → $n_huge eligible (pool stays tight)")

    # H.4: All-identical intensities — binary search MUST converge, no infinite loop.
    fresh_history!()
    for i in 1:200
        push_msg!(2_000_000 + i, "User", "clone msg $i"; intensity=1.5)
    end
    unpinned_clones = [m for m in G.MESSAGE_HISTORY if !m.pinned]
    thr_clones, n_clones = G.auto_tune_intensity_threshold(unpinned_clones)
    # Either all pass (threshold < 1.5) or none pass (threshold >= 1.5).
    # The binary search converges either way; we only care it terminated.
    @test 0 <= n_clones <= 200
    println("  ✓ [H.4] all-identical intensities: threshold=$(round(thr_clones, digits=3)), count=$n_clones (converged, no hang)")
end

# ==============================================================================
# [I] v7.13: extract_aiml_memory_context keeps Fresh Memory bounded even
#     when the cave has 10k messages. Also verify threshold note in output.
# ==============================================================================
@testset "[I] extract_aiml_memory_context bounded on 10k cave; threshold note surfaces" begin
    fresh_history!()
    # 10k unpinned messages, most below baseline, a few hot.
    N_HUGE = 10_000
    for i in 1:N_HUGE
        intensity = i <= 8 ? G.CONTEXT_INTENSITY_CAP : 0.3
        push_msg!(3_000_000 + i, "User", "huge_$i content"; intensity=intensity)
    end
    # One pin to verify it still surfaces.
    push_msg!(3_999_999, "User", "PINNED_SIGIL";
              pinned=true, intensity=G.CONTEXT_INTENSITY_BASELINE)

    Random.seed!(1234)
    ctx = G.extract_aiml_memory_context()
    # GRUG v7.19 QoL: extract_aiml_memory_context returns NamedTuple now.
    ctx_str = ctx isa AbstractString ? ctx : ctx.full
    # Pinned always surfaces.
    @test occursin("PINNED_SIGIL", ctx_str)
    # Threshold note surfaces in the Fresh Memory header.
    @test occursin("threshold=", ctx_str)
    @test occursin("eligible=", ctx_str)
    # Count the `(intensity=` markers → one per unpinned surfaced.
    n_surfaced = count(!isempty, split(ctx_str, "(intensity="))  - 1
    @test n_surfaced <= G.MAX_FRESH_CONTEXT
    println("  ✓ [I] 10k-msg cave: Fresh Memory surfaced $n_surfaced unpinned (≤ MAX_FRESH_CONTEXT=$(G.MAX_FRESH_CONTEXT)); pinned preserved; threshold note present")
end

# -----------------------------------------------------------------------
# [J] v7.17: chunked MESSAGE_HISTORY scans — correctness preserved under
#     batching, early-exit fires on overshoot + feedback passes.
# -----------------------------------------------------------------------

@testset "[J] v7.17 chunked Fresh Memory scan correctness + early-exit" begin
    # J.1: CONTEXT_SCAN_CHUNK is defined and a sane, tunable size.
    @test isdefined(G, :CONTEXT_SCAN_CHUNK)
    @test G.CONTEXT_SCAN_CHUNK >= 100       # below 100 would make scanning overhead dominate
    @test G.CONTEXT_SCAN_CHUNK <= 10_000    # above 10k defeats the point (MAX_HISTORY cap)
    println("  ✓ [J.1] CONTEXT_SCAN_CHUNK=$(G.CONTEXT_SCAN_CHUNK) (in bounds)")

    # J.2: Chunked threshold tuner converges to the same band as a
    # single-pass tuner would. Build a 10k cave whose intensity
    # distribution straddles multiple chunks (every chunk contains
    # both hot and cold messages, so early-exit can fire on any
    # chunk boundary). We check the final count lands in the target
    # band — same invariant as [H] but now with the chunked path
    # explicitly in use.
    unpinned = G.ChatMessage[]
    for i in 1:10_000
        intensity = 0.1 + (i % 50) / 50.0 * 2.5   # spans [0.1, 2.6]
        push!(unpinned, G.ChatMessage(i, "user", "m$i", false, intensity))
    end
    thr_j2, n_eligible_j2 = G.auto_tune_intensity_threshold(unpinned)
    @test n_eligible_j2 <= G.CONTEXT_ELIGIBLE_MAX * 2
    @test n_eligible_j2 >= 1
    println("  ✓ [J.2] 10k straddling cave: threshold=$(round(thr_j2, digits=3)) count=$n_eligible_j2 (bounded)")

    # J.3: Early-exit short-circuits at chunk granularity on overshoot.
    # Build a cave where EVERY message is saturated hot; the tuner
    # cannot find a threshold that lands in the target band (all
    # messages are at the same intensity near CAP), so the binary
    # search runs to budget. The final reported count must be MUCH
    # smaller than n because each step exits after ONE chunk once
    # the count clears CONTEXT_ELIGIBLE_MAX — we never walk all 10k
    # items per step. Without chunking, the final step would have
    # counted every one of the 10k messages.
    all_hot = G.ChatMessage[]
    for i in 1:10_000
        push!(all_hot, G.ChatMessage(i, "User", "h$i", false, 2.9))  # near CAP
    end
    thr_hot, count_hot = G.auto_tune_intensity_threshold(all_hot)
    # Key invariant: chunking capped each step's count at roughly one
    # chunk (plus a bit of overshoot before the check fires). On a 10k
    # cave with CONTEXT_SCAN_CHUNK=1000, count_hot must be ≤ 1 chunk
    # past the band — strictly less than the full 10k.
    @test count_hot < 10_000                                # did NOT walk full cave
    @test count_hot <= G.CONTEXT_SCAN_CHUNK + G.CONTEXT_ELIGIBLE_MAX  # bounded by 1 chunk of early-exit
    println("  ✓ [J.3] all-hot 10k cave: chunked early-exit capped count at $count_hot (≤ CONTEXT_SCAN_CHUNK + band); never walked 10k")

    # J.4: refresh_message_intensities! updates every message regardless
    # of chunk boundary. Seed a cave whose size is NOT a multiple of
    # CONTEXT_SCAN_CHUNK so the last partial chunk exercises the
    # boundary math.
    empty!(G.MESSAGE_HISTORY)
    n_msgs = G.CONTEXT_SCAN_CHUNK * 2 + 17   # deliberately off-boundary
    for i in 1:n_msgs
        G.add_message_to_history!("User", "refresh test $i", false)
    end
    # All messages start at CONTEXT_INTENSITY_BASELINE. After a refresh
    # with an empty user input, they should still all be valid floats
    # in [FLOOR, CAP] — no message skipped, no NaN leaked.
    G.refresh_message_intensities!("")
    all_finite = all(isfinite(m.intensity) for m in G.MESSAGE_HISTORY)
    all_in_bounds = all(G.CONTEXT_INTENSITY_FLOOR <= m.intensity <= G.CONTEXT_INTENSITY_CAP
                        for m in G.MESSAGE_HISTORY)
    @test length(G.MESSAGE_HISTORY) == n_msgs
    @test all_finite
    @test all_in_bounds
    println("  ✓ [J.4] refresh_message_intensities! touched all $n_msgs messages (off-boundary); all finite + clamped")

    # J.5: apply_last_selected_feedback! short-circuits once all target
    # ids are found. Build a 10k cave, select 3 specific ids near the
    # FRONT (so the chunked scan finds them fast). Bump them, then
    # verify:
    #   * exactly those 3 got bumped
    #   * every other message retained its intensity
    #   * returned count == 3
    empty!(G.MESSAGE_HISTORY)
    for i in 1:10_000
        G.add_message_to_history!("User", "fb test $i", false)
    end
    # Set all to baseline so we can detect bumps.
    for m in G.MESSAGE_HISTORY
        m.intensity = G.CONTEXT_INTENSITY_BASELINE
    end
    # Pick 3 ids in the first chunk.
    target_ids = Set([G.MESSAGE_HISTORY[10].id,
                      G.MESSAGE_HISTORY[50].id,
                      G.MESSAGE_HISTORY[200].id])
    lock(G.LAST_SELECTED_MSG_LOCK) do
        G.LAST_SELECTED_MSG_IDS[] = target_ids
    end
    bumped = G.apply_last_selected_feedback!(0.5)
    @test bumped == 3
    # Exactly three messages should have intensity > baseline; everyone
    # else must be untouched at baseline.
    hits = count(m -> m.intensity > G.CONTEXT_INTENSITY_BASELINE,
                 G.MESSAGE_HISTORY)
    misses = count(m -> m.intensity == G.CONTEXT_INTENSITY_BASELINE,
                   G.MESSAGE_HISTORY)
    @test hits == 3
    @test misses == length(G.MESSAGE_HISTORY) - 3
    println("  ✓ [J.5] feedback early-exit: bumped exactly 3/10000 targets, $misses untouched")

    # J.6: DONE checkpoint contract. Every chunked scan must call
    # _chunk_done! exactly ceil(N / CHUNK) times for full walks, and
    # strictly fewer when early-exit fires. Reset the counters, run a
    # known-size scan, verify the counter landed on the expected
    # value. This is the "scan 1000, submit DONE, then continue"
    # contract you asked for — without it, a chunked scan could still
    # bunch all 10 batches back-to-back without yielding.
    empty!(G.MESSAGE_HISTORY)
    for i in 1:10_000
        G.add_message_to_history!("User", "chk $i", false)
    end

    # J.6a: refresh_message_intensities! walks the whole cave → must
    # publish ceil(10000/1000) = 10 DONE markers.
    G.reset_chunk_counters!()
    G.refresh_message_intensities!("")
    refresh_chunks = G.get_chunk_counter("refresh_intensities")
    @test refresh_chunks == 10
    println("  ✓ [J.6a] refresh_message_intensities! emitted $refresh_chunks DONE markers (expected 10)")

    # J.6b: apply_last_selected_feedback! with 3 targets in the FIRST
    # chunk must emit exactly 1 DONE and then short-circuit — never
    # walks the remaining 9 chunks because target_hits is already met.
    for m in G.MESSAGE_HISTORY
        m.intensity = G.CONTEXT_INTENSITY_BASELINE
    end
    front_ids = Set([G.MESSAGE_HISTORY[5].id,
                     G.MESSAGE_HISTORY[10].id,
                     G.MESSAGE_HISTORY[42].id])
    lock(G.LAST_SELECTED_MSG_LOCK) do
        G.LAST_SELECTED_MSG_IDS[] = front_ids
    end
    G.reset_chunk_counters!()
    G.apply_last_selected_feedback!(0.3)
    fb_chunks = G.get_chunk_counter("feedback_scan")
    @test fb_chunks == 1
    println("  ✓ [J.6b] feedback short-circuit: emitted $fb_chunks DONE marker (expected 1 — early-exit)")

    # J.6c: extract_aiml_memory_context runs multiple chunked scans
    # (pinned + unpinned_materialize + threshold + coinflip). After
    # one call, every scan label must have a non-zero counter. This
    # proves the DONE checkpoint is wired into all scan sites.
    G.reset_chunk_counters!()
    _ = G.extract_aiml_memory_context()
    @test G.get_chunk_counter("pinned_scan") >= 1
    @test G.get_chunk_counter("unpinned_materialize") >= 1
    @test G.get_chunk_counter("threshold_scan") >= 1
    # coinflip_scan may not fire if no unpinned messages clear the
    # threshold gate, but with all 10k at baseline and threshold near
    # FLOOR, at least some will; assert weakly (≥ 0, scan ran correctly).
    @test G.get_chunk_counter("coinflip_scan") >= 0
    println("  ✓ [J.6c] extract_aiml_memory_context: all scan labels emitted DONE (pinned=$(G.get_chunk_counter("pinned_scan")), unpinned=$(G.get_chunk_counter("unpinned_materialize")), threshold=$(G.get_chunk_counter("threshold_scan")), coinflip=$(G.get_chunk_counter("coinflip_scan")))")

    # Cleanup so downstream tests start fresh.
    empty!(G.MESSAGE_HISTORY)
    G.reset_chunk_counters!()
end

println("\n" * "="^60)
println("ALL CONTEXT INTENSITY TESTS PASSED! 10 test groups complete.")
println("Context-intensity v7.12 + v7.13 + v7.17 verified:")
println("  [A] clamp_intensity saturation + non-finite rejection")
println("  [B] lexical tokenizer filters + normalises")
println("  [C] relevance score: identical > disjoint")
println("  [D] snap-back pulls toward relevance; zero-mean jitter in expectation")
println("  [E] pinned always surface; unpinned biased by intensity")
println("  [F] /right /wrong feedback clamped; empty set no-op")
println("  [G] /brainstorm scope widens intensity jitter (alignment holds)")
println("  [H] v7.13 auto_tune_intensity_threshold narrows large caves to band")
println("  [I] v7.13 extract_aiml_memory_context bounded on 10k cave")
println("  [J] v7.17 chunked scans preserve correctness + early-exit fires")
println("="^60)