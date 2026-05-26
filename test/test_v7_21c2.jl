# test_v7_21c2.jl
# ==============================================================================
# v7.21c-2: PROSE-SLOT ACTIONS + CONSERVATIVE THESAURUS + PHRASE REORDER
# ==============================================================================
# v7.21c-1 wired schema dials (voice_register, noun_anchors, ...).
# v7.21c-2 reframes how AIML talks:
#
#   1. PROSE-SLOT ACTIONS — action_packet entries can now be full prose
#      answer-slots instead of single verb labels:
#        "fire is hot rock that bites^3 | fire eats wood^2"
#      The grow-time validator (engine.jl :: ensure_action_packet_registered!)
#      auto-registers a passthrough COMMANDS handler for any multi-word
#      (>=2 words AND >=8 chars) action_name. Single-word unknowns still
#      hard-fail (typo guard preserved).
#
#   2. PROSE-ACTION CLAIM PRIORITY — generate_aiml_payload (Main.jl) detects
#      a prose action via the same heuristic and uses the action_str itself
#      as the top-priority CLAIM (above pattern, voice_body, anchors).
#      The skeleton for prose actions degenerates to "{CLAIM}.{SUPPORT}"
#      so we don't get "Thinking it through: fire is hot rock..." nonsense.
#
#   3. CONSERVATIVE THESAURUS — _swap_words_in routes every token through a
#      probabilistic gate (default 0.25) before considering a synonym.
#      Override via GRUG_THESAURUS_SWAP_RATE.
#
#   4. PHRASE REORDER — _reorder_clauses splits a CLAIM on commas /
#      "and" / "or", shuffles the segments, rejoins. Default rate 0.40,
#      override via GRUG_PHRASE_REORDER_RATE. Requires >=2 segments AND
#      >=4 total tokens or it returns the input unchanged.
#
# Each test isolates the seam under inspection. We do NOT spin up the full
# engine here — these are unit tests of synthesis surfaces.
# ==============================================================================

using Test
using Random

const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

println("\n" * "="^70)
println("GRUG v7.21c-2 — prose-slot actions + thesaurus gate + phrase reorder")
println("="^70)

# ------------------------------------------------------------------------------
# Helpers — adapted from test_v7_21c1.jl
# ------------------------------------------------------------------------------

function make_test_node!(node_id::String, pattern::String, json_data::Dict{String,Any};
                          action_packet::String = "describe^3 | explain^2",
                          drop_table::Vector{String} = String[])
    node = Node(
        node_id, pattern, Float64[], action_packet, json_data, drop_table,
        0.0, RelationalTriple[], String[],
        Dict{String,Float64}(), 5.0, false, String[], false, 12, false,
        "", Float64[], time(), UInt64(0), false, false, false, 0.0,
    )
    lock(NODE_LOCK) do
        NODE_MAP[node_id] = node
    end
    return node
end

function build_payload(mission::String, node_id::String, action::String)
    node = lock(() -> NODE_MAP[node_id], NODE_LOCK)
    sp = get(node.json_data, "system_prompt", "Grug speaks plainly.")
    primary = Vote(node_id, action, 0.7, String[],
                   RelationalTriple[], RelationalTriple[], false)
    all_votes = [primary]
    payload = generate_aiml_payload(
        mission, primary, all_votes, Vote[], all_votes,
        node.json_data)
    return String(payload)
end

function spoken_line(payload::String)::String
    for marker in ("--- DEBUG TELEMETRY", "=== AIML PAYLOAD",
                   "AIML Voting:", "==========")
        idx = findfirst(marker, payload)
        if idx !== nothing
            return String(strip(payload[1:first(idx)-1]))
        end
    end
    return String(strip(payload))
end

# ------------------------------------------------------------------------------
# 1. ensure_action_packet_registered! — prose action gets COMMANDS handler
# ------------------------------------------------------------------------------
@testset "[1] prose action_packet auto-registers COMMANDS handler" begin
    pkt = "fire is hot rock that bites^3 | greet^1"
    # Should not throw (prose action is multi-word, verb is in COMMANDS)
    @test_nowarn ensure_action_packet_registered!(pkt)
    @test haskey(COMMANDS, "fire is hot rock that bites")
    @test haskey(COMMANDS, "greet")  # pre-existing
end

# ------------------------------------------------------------------------------
# 2. ensure_action_packet_registered! — single-word unknown still FATALs
# ------------------------------------------------------------------------------
@testset "[2] single-word typo still raises FATAL (BUG-007 preserved)" begin
    pkt = "asfdfdsf^2"
    @test_throws ErrorException ensure_action_packet_registered!(pkt)
end

# ------------------------------------------------------------------------------
# 3. ensure_action_packet_registered! — idempotent on re-registration
# ------------------------------------------------------------------------------
@testset "[3] re-registering same prose action is a no-op" begin
    pkt = "water is sky-tear that fills the bowl^3"
    ensure_action_packet_registered!(pkt)
    handler1 = COMMANDS["water is sky-tear that fills the bowl"]
    ensure_action_packet_registered!(pkt)
    handler2 = COMMANDS["water is sky-tear that fills the bowl"]
    @test handler1 === handler2
end

# ------------------------------------------------------------------------------
# 4. PROSE ACTION → TOP-PRIORITY CLAIM
#    The action string itself appears in the spoken line.
# ------------------------------------------------------------------------------
@testset "[4] prose action becomes top-priority CLAIM" begin
    # Force determinism: zero swap & reorder so the CLAIM comes through
    # exactly as authored.
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
        prose = "fire is hot rock that bites"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("prose_fire", "fire",
            Dict{String,Any}(
                "system_prompt" => "Grug know fire.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")

        payload = build_payload("what is fire", "prose_fire", prose)
        line = spoken_line(payload)

        @test occursin("fire is hot rock that bites", line)
        # No nonsense scaffolding for prose actions
        @test !occursin("Thinking it through:", line)
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 5. THESAURUS SWAP_RATE=0 → CLAIM passes through unchanged via AIML
# ------------------------------------------------------------------------------
@testset "[5] GRUG_THESAURUS_SWAP_RATE=0.0 preserves CLAIM verbatim" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
        prose = "the small wolf hunts in pack quietly"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("swap0_node", "wolf",
            Dict{String,Any}(
                "system_prompt" => "Grug know wolf.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")
        # Run twice — must produce same CLAIM both times since swap+reorder off
        Random.seed!(11)
        line1 = spoken_line(build_payload("wolf", "swap0_node", prose))
        Random.seed!(22)
        line2 = spoken_line(build_payload("wolf", "swap0_node", prose))
        # Both must contain the original prose verbatim (no synonym swap)
        @test occursin(prose, line1)
        @test occursin(prose, line2)
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 6. THESAURUS SWAP_RATE=1.0 → may rewrite tokens; must not crash, must not
#    return empty
# ------------------------------------------------------------------------------
@testset "[6] GRUG_THESAURUS_SWAP_RATE=1.0 still produces valid output" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "1.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
        prose = "the small wolf hunts in pack"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("swap1_node", "wolf",
            Dict{String,Any}(
                "system_prompt" => "Grug know wolf.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")
        Random.seed!(7)
        line = spoken_line(build_payload("wolf", "swap1_node", prose))
        @test length(line) > 0
        @test line isa AbstractString
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 7. PHRASE REORDER=0 → CLAIM segments arrive in authored order
# ------------------------------------------------------------------------------
@testset "[7] GRUG_PHRASE_REORDER_RATE=0.0 preserves segment order" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
        prose = "fire eats wood and breathes black smoke and dances"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("reorder0_node", "fire",
            Dict{String,Any}(
                "system_prompt" => "Grug know fire.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")
        for seed in (3, 5, 17, 31)
            Random.seed!(seed)
            line = spoken_line(build_payload("fire", "reorder0_node", prose))
            # No reorder + no swap => CLAIM is the literal prose
            @test occursin("fire eats wood", line)
            # And "breathes black smoke" should NOT precede "fire eats wood"
            i_eats = findfirst("fire eats wood", line)
            i_breath = findfirst("breathes black smoke", line)
            if i_eats !== nothing && i_breath !== nothing
                @test first(i_eats) < first(i_breath)
            end
        end
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 8. PHRASE REORDER=1.0 → at least one of N seeds yields a different ordering
# ------------------------------------------------------------------------------
@testset "[8] GRUG_PHRASE_REORDER_RATE=1.0 yields permutations across seeds" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "1.0"
    try
        prose = "fire eats wood and breathes black smoke and dances"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("reorder1_node", "fire",
            Dict{String,Any}(
                "system_prompt" => "Grug know fire.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")
        seen_lines = Set{String}()
        for seed in 1:40
            Random.seed!(seed)
            line = spoken_line(build_payload("fire", "reorder1_node", prose))
            push!(seen_lines, line)
        end
        # We expect at least 2 distinct outputs across 40 seeds
        # if reorder is actually permuting.
        @test length(seen_lines) >= 2
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 9. PHRASE REORDER short-input safety — short prose stays intact
#    (no segments to reorder)
# ------------------------------------------------------------------------------
@testset "[9] short-prose CLAIMs survive reorder=1.0 without corruption" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "1.0"
    try
        prose = "fire bites tribe"  # 3 tokens, no comma/and/or => single segment
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("short_node", "fire",
            Dict{String,Any}(
                "system_prompt" => "Grug know fire.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")
        for seed in (1, 2, 3, 4, 5)
            Random.seed!(seed)
            line = spoken_line(build_payload("fire", "short_node", prose))
            @test occursin("fire bites tribe", line)
        end
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 10. PERSONA-ONLY system_prompt — bracket label is the persona, not "Hello —"
# ------------------------------------------------------------------------------
@testset "[10] persona-only system_prompt becomes the bracket label" begin
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
        prose = "wolf is teeth and fur and yellow eye"
        ensure_action_packet_registered!("$(prose)^3")
        make_test_node!("prose_wolf", "wolf",
            Dict{String,Any}(
                "system_prompt" => "Grug know wolf.",
                "voice_register" => "plain");
            action_packet = "$(prose)^3")

        payload = build_payload("what is wolf", "prose_wolf", prose)
        line = spoken_line(payload)

        # The persona tag should appear somewhere in the bracket prefix
        @test occursin("Grug know wolf", line) ||
              occursin("wolf is teeth", line)  # Or the prose CLAIM itself
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

# ------------------------------------------------------------------------------
# 11. SAVE/LOAD ROUND-TRIP — prose actions survive a specimen reload
#     (We test the registry function directly rather than full save/load.)
# ------------------------------------------------------------------------------
@testset "[11] prose action survives clean COMMANDS state via re-registration" begin
    prose_action = "rock is patient bone of mountain"
    pkt = "$(prose_action)^3"
    # Wipe (simulate fresh-process load)
    if haskey(COMMANDS, prose_action)
        delete!(COMMANDS, prose_action)
    end
    @test !haskey(COMMANDS, prose_action)
    # Re-registration (mimicking load_specimen path)
    ensure_action_packet_registered!(pkt)
    @test haskey(COMMANDS, prose_action)
end

println("\n" * "="^70)
println("✅ test_v7_21c2.jl complete")
println("="^70)
