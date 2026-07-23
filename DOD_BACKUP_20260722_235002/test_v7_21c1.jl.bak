# test_v7_21c1.jl
# ==============================================================================
# v7.21c-1: SCHEMA UTILIZATION — voice_register, noun_anchors,
#           companion_node_pref, aux_triples
# ==============================================================================
# v7.21b-3d wired voice_body and frame_skeleton. v7.21c-1 extends the seed
# schema with four new dials the scaffold can now consume:
#
#   - voice_register      (warm / terse / casual / plain / formal) — modulates
#                         skeleton TEXTURE (terse drops SUPPORT, formal
#                         em-dash → colon)
#   - noun_anchors        ([nouns…])           — fallback CLAIM when pattern
#                         is too short and system_prompt body is empty
#   - companion_node_pref ([node_ids…])        — overrides "first tied alt"
#                         heuristic for the companion-frame clause
#   - aux_triples         ([[s,r,o]…])         — engine-side triple injection
#                         for short patterns where extract_relational_triples
#                         can't auto-detect (engine.jl:create_node)
#
# Each test uses isolated synthetic nodes, mirrors the pattern from
# test_v7_21b3d.jl. We don't spin up the whole engine — these are unit
# tests of the new schema-consumption seams.
# ==============================================================================

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

const REPO_ROOT = dirname(@__DIR__)
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(REPO_ROOT, "src", "Main.jl"))

const TJ  = TonalJudge
const ATP = ActionTonePredictor

println("\n" * "="^70)
println("GRUG v7.21c-1 — schema utilization (voice_register/noun_anchors/...)")
println("="^70)

# ------------------------------------------------------------------------------
# Helpers — adapted from test_v7_21b3d.jl. Builds a node with arbitrary
# json_data and exercises the synthesis path.
# ------------------------------------------------------------------------------

function make_test_node!(node_id::String, pattern::String, json_data::Dict{String,Any};
                          action_packet::String = "describe^3 | explain^2",
                          drop_table::Vector{String} = String[],
                          relational_patterns::Vector{RelationalTriple} = RelationalTriple[],
                          required_relations::Vector{String} = String[])
    node = Node(
        node_id, pattern, Float64[], action_packet, json_data, drop_table,
        0.0, relational_patterns, required_relations,
        Dict{String,Float64}(), 5.0, false, false, String[], false, 12, false,
        "", Float64[], time(), UInt64(0), false, false, false, 0.0,
        pattern, action_packet,  # BUG-010b: original_pattern, original_action_packet
    )
    lock(NODE_LOCK) do
        NODE_MAP[node_id] = node
    end
    return node
end

function build_payload(mission::String, node_id::String, action::String;
                       tied_alt_ids::Vector{String} = String[])
    node = lock(() -> NODE_MAP[node_id], NODE_LOCK)
    sp = get(node.json_data, "system_prompt", "Grug speaks plainly.")
    primary = Vote(node_id, action, 0.7, String[],
                   RelationalTriple[], RelationalTriple[], false)
    # Build tied alternatives — same action-family is fine for the
    # companion-pref test
    tied = Vote[]
    for aid in tied_alt_ids
        push!(tied, Vote(aid, action, 0.6, String[],
                         RelationalTriple[], RelationalTriple[], false))
    end
    all_votes = vcat([primary], tied)
    payload = synthesize_voice_reply(
        mission, primary, all_votes, Vote[], all_votes,
        Dict{String,Any}("system_prompt" => sp))
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
# 1. voice_register=terse — drops SUPPORT clause
# ------------------------------------------------------------------------------
@testset "[1] voice_register=terse strips SUPPORT" begin
    TJ.reset_last_judgement!()
    # Use a multi-sentence prompt so the body is non-empty (skeleton applies).
    make_test_node!("vr_terse", "danger",
        Dict{String,Any}(
            "system_prompt" => "Grug warn. Threat near. Run now.",
            "voice_register" => "terse",
            "frame_hints" => ["terse"]);
        action_packet = "alert^3")
    # Inject terse frame so the frame skeleton kicks in
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.BASIC, TJ.FRAME_TERSE, TJ.Token[],
        Symbol[:test_inject], time())

    payload = build_payload("danger", "vr_terse", "alert")
    line = spoken_line(payload)

    # Body becomes claim. Terse register => skeleton is "{CLAIM}." (no support)
    @test occursin("Threat near", line)
    # No "Hello —" or "Let me think" or "I hear that" prefixes
    @test !occursin("Hello —", line)
    @test !occursin("Let me think with you", line)
    TJ.reset_last_judgement!()
end

# ------------------------------------------------------------------------------
# 2. voice_register=formal — em-dash becomes colon
# ------------------------------------------------------------------------------
@testset "[2] voice_register=formal converts em-dash to colon" begin
    # Inject warm frame so the skeleton is "Hello — {CLAIM}.{SUPPORT}"
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_WARM, TJ.Token[],
        Symbol[:test_inject], time())

    make_test_node!("vr_formal", "greetings",
        Dict{String,Any}(
            "system_prompt" => "Grug welcome. Tribemate be honored.",
            "voice_register" => "formal",
            "frame_hints" => ["warm"]);
        action_packet = "greet^3")

    payload = build_payload("greetings", "vr_formal", "greet")
    line = spoken_line(payload)

    # Formal register: " — " replaced with ": "
    @test occursin("Hello: ", line) || occursin("Hello :", line)
    # No em-dash should remain in the warm opener
    @test !occursin("Hello — ", line)
    TJ.reset_last_judgement!()
end

# ------------------------------------------------------------------------------
# 3. noun_anchors fallback — when pattern is bare AND body is empty
# ------------------------------------------------------------------------------
@testset "[3] noun_anchors fallback wraps a noun when pattern is bare" begin
    TJ.reset_last_judgement!()
    # Single-sentence prompt → empty voice_body
    # Single-token pattern → pattern fallback path goes to noun_anchors[1]
    make_test_node!("na_node", "hammer",
        Dict{String,Any}(
            "system_prompt" => "Grug describe tool.",   # no body
            "noun_anchors" => ["hammer", "tool", "stone"]);
        action_packet = "describe^3")

    payload = build_payload("hammer", "na_node", "describe")
    line = spoken_line(payload)

    # The noun-anchor path wraps the first anchor as "the hammer"
    # (or, if synonym swap fires, "the {synonym}"). Either way, it
    # must NOT be a bare "hammer." claim, AND must contain "the".
    @test occursin("the ", line)
    # v7.24 BUG-6: voice prefix is internal-only, not speech.
    # It must NOT appear in the spoken output.
    @test !occursin("[Grug describe tool]", line)
end

# ------------------------------------------------------------------------------
# 4. companion_node_pref — tied alternative is overridden to preferred id
# ------------------------------------------------------------------------------
@testset "[4] companion_node_pref selects the preferred companion" begin
    TJ.reset_last_judgement!()
    # Primary node with companion_node_pref pointing at the SECOND tied alt
    make_test_node!("cnp_primary", "i feel",
        Dict{String,Any}(
            "system_prompt" => "Grug listen. Validate, do not fix.",
            "companion_node_pref" => ["cnp_alt2"]);
        action_packet = "validate^3")
    # Two tied alternatives — pref points at the second
    make_test_node!("cnp_alt1", "feel cold",
        Dict{String,Any}(
            "system_prompt" => "Grug speak first companion. Cold body, warm hut.");
        action_packet = "validate^3")
    make_test_node!("cnp_alt2", "feel safe",
        Dict{String,Any}(
            "system_prompt" => "Grug speak second companion. Safe by fire, tribe close.");
        action_packet = "validate^3")

    payload = build_payload("i feel scared", "cnp_primary", "validate";
                            tied_alt_ids = ["cnp_alt1", "cnp_alt2"])
    line = spoken_line(payload)

    # The preferred companion (alt2)'s body should appear in the support clause
    # The non-preferred companion (alt1)'s prose must NOT appear
    @test occursin("Safe by fire", line) || occursin("tribe close", line)
    @test !occursin("Cold body", line)
end

# ------------------------------------------------------------------------------
# 5. aux_triples — engine.create_node consumes [[s,r,o]…] from json_data
# ------------------------------------------------------------------------------
@testset "[5] aux_triples are absorbed into relational_patterns at create" begin
    # Direct call to create_node with aux_triples in data dict.
    data = Dict{String,Any}(
        "system_prompt" => "Grug warn of harm.",
        "aux_triples" => Any[
            Any["danger", "causes", "harm"],
            Any["predator", "threatens", "tribe"],
        ],
    )
    new_id = create_node("danger_aux", "alert^3", data, ["fire", "snake"])
    node = lock(() -> NODE_MAP[new_id], NODE_LOCK)
    # Node should now carry both aux_triples in its relational_patterns
    rels = node.relational_patterns
    @test length(rels) >= 2
    rel_strs = [string(t.subject, " ", t.relation, " ", t.object) for t in rels]
    @test any(s -> occursin("danger causes harm", s), rel_strs)
    @test any(s -> occursin("predator threatens tribe", s), rel_strs)
end

# ------------------------------------------------------------------------------
# 6. Smoke: a node carrying ALL four new keys still produces coherent output
# ------------------------------------------------------------------------------
@testset "[6] smoke — full schema node produces coherent reply" begin
    # GRUG v7.21c-2: pin swap+reorder to 0 so the assertions on exact
    # body fragments ("Sun is up" / "tribe gather") aren't randomly
    # broken by a synonym swap of "Sun"/"tribe".
    prev_swap = get(ENV, "GRUG_THESAURUS_SWAP_RATE", "")
    prev_reorder = get(ENV, "GRUG_PHRASE_REORDER_RATE", "")
    ENV["GRUG_THESAURUS_SWAP_RATE"] = "0.0"
    ENV["GRUG_PHRASE_REORDER_RATE"] = "0.0"
    try
    TJ.reset_last_judgement!()
    make_test_node!("smoke_full", "good morning",
        Dict{String,Any}(
            "system_prompt" => "Grug acknowledge time of day. Sun is up, tribe gather.",
            "voice_register" => "warm",
            "noun_anchors" => ["morning", "sun"],
            "frame_hints" => ["warm"]);
        action_packet = "greet^3 | smile^2")
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_WARM, TJ.Token[],
        Symbol[:test_inject], time())

    payload = build_payload("good morning", "smoke_full", "greet")
    line = spoken_line(payload)

    # Voice prefix from first sentence
    @test occursin("[Grug acknowledge time of day]", line)
    # Body wins over pattern
    @test occursin("Sun is up", line) || occursin("tribe gather", line)
    # Trigger pattern is NOT echoed as the bare claim
    @test !occursin(": good morning.", line)
    @test !occursin("matters: good morning", line)
    TJ.reset_last_judgement!()
    finally
        if isempty(prev_swap); delete!(ENV, "GRUG_THESAURUS_SWAP_RATE"); else ENV["GRUG_THESAURUS_SWAP_RATE"] = prev_swap; end
        if isempty(prev_reorder); delete!(ENV, "GRUG_PHRASE_REORDER_RATE"); else ENV["GRUG_PHRASE_REORDER_RATE"] = prev_reorder; end
    end
end

println("="^70)
println("✅ v7.21c-1 schema utilization tests complete")
println("="^70)
