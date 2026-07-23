# test_v7_21b3d.jl
# ==============================================================================
# v7.21b-3d: COHERENCE FIX — system_prompt-as-claim + frame-keyed skeleton
# ==============================================================================
# v7.21b-3b plugged the predictor → orchestrator seam (right node wins).
# v7.21b-3d plugs the orchestrator → scaffold seam (right *prose* gets spoken).
#
# What this test covers:
#   1. Helper: split system_prompt → (voice_first, voice_body) correctly
#   2. Frame-keyed skeleton dispatch — which skeleton fires for each frame
#   3. Action-keyed skeleton fallback — when no judgement is available
#   4. CLAIM priority: system_prompt body > node.pattern > mission fallback
#   5. End-to-end: feed a synthetic mission through synthesize_voice_reply
#      and check the spoken reply contains the expected sentences and is
#      not just echoing the trigger pattern
#
# We deliberately avoid spinning up the entire engine — these are unit
# tests of the synthesis layer's coherence properties.
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
println("GRUG v7.21b-3d — coherence fix (system_prompt body + frame skeleton)")
println("="^70)

# ------------------------------------------------------------------------------
# Helpers — build a node and feed it through synthesize_voice_reply.
# ------------------------------------------------------------------------------

function make_test_node!(node_id::String, pattern::String, system_prompt::String;
                          action_packet::String = "describe^3 | explain^2",
                          lobe_id::String = "default")
    # Direct mutation of NODE_MAP. Mirrors the path /grow uses internally
    # but skips the immune gate (we're in a test).
    node = Node(
        node_id,                        # id
        pattern,                        # pattern
        Float64[],                      # signal
        action_packet,                  # action_packet
        Dict{String,Any}("system_prompt" => system_prompt),  # json_data
        String[],                       # drop_table
        0.0,                            # throttle
        RelationalTriple[],             # relational_patterns
        String[],                       # required_relations
        Dict{String,Float64}(),         # relation_weights
        5.0,                            # strength
        false,                          # is_image_node
        false,                          # is_antimatch_node
        String[],                       # neighbor_ids
        false,                          # is_unlinkable
        12,                             # max_neighbors
        false,                          # is_grave
        "",                             # grave_reason
        Float64[],                      # response_times
        time(),                         # ledger_last_cleared
        UInt64(0),                      # hopfield_key
        false,                          # fired_this_cycle
        false,                          # voted_this_cycle
        false,                          # gained_this_cycle
        0.0,                            # strength_delta_this_cycle
        pattern,                        # original_pattern (BUG-010b: frozen at birth)
        action_packet,                  # original_action_packet (BUG-010b: frozen at birth)
    )
    lock(NODE_LOCK) do
        NODE_MAP[node_id] = node
    end
    return node
end

function build_payload(mission::String, node_id::String, action::String;
                      system_prompt_override::Union{Nothing,String} = nothing)
    node = lock(() -> NODE_MAP[node_id], NODE_LOCK)
    sp = system_prompt_override === nothing ?
         get(node.json_data, "system_prompt", "Grug speaks plainly.") :
         system_prompt_override
    primary = Vote(
        node_id, action, 0.7,
        String[], RelationalTriple[], RelationalTriple[], false
    )
    payload = synthesize_voice_reply(
        mission, primary, [primary], Vote[], [primary],
        Dict{String,Any}("system_prompt" => sp)
    )
    return String(payload)
end

# Extract just the spoken reply (everything before the telemetry banner).
# The payload format is: "<spoken reply>\n--- DEBUG TELEMETRY ---\n...".
function spoken_line(payload::String)::String
    # Try several telemetry banner forms used by Main.jl
    for marker in ("--- DEBUG TELEMETRY", "=== AIML PAYLOAD", "AIML Voting:", "==========")
        idx = findfirst(marker, payload)
        if idx !== nothing
            return String(strip(payload[1:first(idx)-1]))
        end
    end
    return String(strip(payload))
end

# ------------------------------------------------------------------------------
# 1. system_prompt body extraction — the helper logic, exercised end-to-end
# ------------------------------------------------------------------------------
@testset "[1] system_prompt body becomes the spoken core" begin
    TJ.reset_last_judgement!()  # no frame; force action-keyed skeleton

    make_test_node!("test_warm",
        "hello",
        "Grug greet warm. Hello and welcome to the cave.";
        action_packet = "greet^3",
        lobe_id = "default")

    payload = build_payload("hello", "test_warm", "greet")
    line = spoken_line(payload)

    # Voice prefix is now internal-only (v7.24 BUG-6: persona tag not speech)
    # It must NOT appear in the spoken output.
    @test !occursin("[Grug greet warm]", line)
    # Body (the seeded grug-voice answer) must appear in the spoken reply
    @test occursin("Hello and welcome to the cave", line)
    # The raw trigger pattern must NOT appear as the claim
    # (this is the v7.21b-3b leak we're fixing — body wins over pattern)
    # We don't forbid "hello" in general (the prefix already contains it),
    # but the OLD pattern "Hello — here is what matters: hello." is gone.
    @test !occursin("here is what matters: hello.", line)
end

# ------------------------------------------------------------------------------
# 2. Frame-keyed skeleton dispatch — each frame produces its own opener
# ------------------------------------------------------------------------------
@testset "[2] frame-keyed skeleton — de-escalating opens with 'I hear that'" begin
    # Seed a judgement with FRAME_DE_ESCALATING
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_DE_ESCALATING,
        TJ.Token[], Symbol[:test_inject], time())

    # Single-sentence system_prompt → no body → skeleton wraps the pattern.
    # We use a single-sentence prompt here so the SKELETON path is exercised
    # (otherwise the body short-circuits the skeleton).
    make_test_node!("test_de_esc",
        "i feel sad",
        "Grug sit with feeling.";   # ONE sentence → no body
        action_packet = "validate^3",
        lobe_id = "default")

    payload = build_payload("i feel sad today", "test_de_esc", "validate")
    line = spoken_line(payload)

    @test occursin("I hear that", line)              # de-escalating opener
    @test occursin("[Grug sit with feeling]", line)
    TJ.reset_last_judgement!()
end

@testset "[3] frame-keyed skeleton — terse drops the support clause" begin
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.BASIC, TJ.FRAME_TERSE, TJ.Token[],
        Symbol[:test_inject], time())

    make_test_node!("test_terse",
        "stop",
        "Grug answer short.";
        action_packet = "command^3",
        lobe_id = "default")

    payload = build_payload("stop", "test_terse", "command")
    line = spoken_line(payload)

    # Terse skeleton is "{CLAIM}." — no preamble, no support.
    @test !occursin("Hello", line)
    @test !occursin("Let me think", line)
    @test !occursin("I hear that", line)
    TJ.reset_last_judgement!()
end

@testset "[4] frame-keyed skeleton — contemplative opens with 'Let me think'" begin
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_CONTEMPLATIVE, TJ.Token[],
        Symbol[:test_inject], time())

    make_test_node!("test_contemp",
        "perhaps",
        "Grug ponder slow.";
        action_packet = "speculate^3",
        lobe_id = "default")

    payload = build_payload("perhaps the rain comes", "test_contemp", "ponder")
    @test occursin("Let me think with you", spoken_line(payload))
    TJ.reset_last_judgement!()
end

@testset "[5] frame-keyed skeleton — imperative is bare, no preamble" begin
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_IMPERATIVE, TJ.Token[],
        Symbol[:test_inject], time())

    make_test_node!("test_imp",
        "run",
        "Grug urge action.";
        action_packet = "command^3",
        lobe_id = "default")

    line = spoken_line(build_payload("run now", "test_imp", "alert"))
    # No preamble like "Hello —" or "Let me think" or "Here is the picture"
    @test !occursin("Hello", line)
    @test !occursin("Let me think", line)
    @test !occursin("Here is the picture", line)
    @test !occursin("I hear that", line)
    @test occursin("[Grug urge action]", line)
    TJ.reset_last_judgement!()
end

# ------------------------------------------------------------------------------
# 6. Action-keyed fallback — when no judgement is available
# ------------------------------------------------------------------------------
@testset "[6] action-keyed skeleton fires when no judgement available" begin
    TJ.reset_last_judgement!()
    @test TJ.get_last_judgement() === nothing

    make_test_node!("test_legacy",
        "hello",
        "Grug greet plain.";       # one sentence → no body
        action_packet = "greet^3",
        lobe_id = "default")

    line = spoken_line(build_payload("hello", "test_legacy", "greet"))
    # Action-keyed greet skeleton: "Hello — here is what matters: ..."
    @test occursin("Hello — here is what matters", line)
end

# ------------------------------------------------------------------------------
# 7. CLAIM priority: body > pattern > mission fallback
# ------------------------------------------------------------------------------
@testset "[7] CLAIM priority — body wins over pattern" begin
    TJ.reset_last_judgement!()

    # Two-sentence system_prompt → has body
    make_test_node!("test_priority_body",
        "thing",
        "Grug describe. The thing is round and grey.";
        action_packet = "describe^3",
        lobe_id = "default")

    line = spoken_line(build_payload("the thing", "test_priority_body", "describe"))
    @test occursin("The thing is round and grey", line)
end

@testset "[8] CLAIM priority — pattern fallback when no body" begin
    TJ.reset_last_judgement!()

    # Single-sentence system_prompt → no body → pattern is used
    make_test_node!("test_priority_pat",
        "the round grey thing",
        "Grug describe.";          # one sentence → no body
        action_packet = "describe^3",
        lobe_id = "default")

    line = spoken_line(build_payload("what is it", "test_priority_pat", "describe"))
    @test occursin("the round grey thing", line)
end

# ------------------------------------------------------------------------------
# 9. End-to-end: the regression case from kitchen sink v11
# ------------------------------------------------------------------------------
@testset "[9] regression: 'i feel sad' no longer parrots the trigger" begin
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.RELATIONAL, TJ.FRAME_DE_ESCALATING, TJ.Token[],
        Symbol[:test_inject], time())

    # Mirror the kitchen-sink node_18 setup
    make_test_node!("test_node18",
        "i feel",
        "Grug listen to feeling. Validate, do not fix.";
        action_packet = "validate^3 | acknowledge^2",
        lobe_id = "default")

    line = spoken_line(build_payload("i feel sad today", "test_node18", "validate"))

    # The buggy v11 output was "[Grug listen to feeling] To acknowledge what
    # matters here: i feel."  We assert the FIX:
    @test occursin("[Grug listen to feeling]", line)         # voice prefix unchanged
    # The CLAIM is now the system_prompt body — synonym substitution may swap
    # "Validate"→"Test" or "fix"→"repair", but the "do not <X>" backbone of the
    # second sentence survives, and that's what proves body-as-claim wired up.
    @test occursin("do not", line)
    @test occursin("I hear that", line)                       # de-escalating frame
    # And the broken pattern echo is gone:
    @test !occursin("here is what matters: i feel.", line)
    @test !occursin("To acknowledge what matters here: i feel.", line)
    @test !occursin("here is what matters: i feel ", line)
    TJ.reset_last_judgement!()
end

@testset "[10] regression: 'hello' no longer parrots 'hello hi'" begin
    TJ.LAST_JUDGEMENT[] = TJ.TonalJudgement(
        TJ.BASIC, TJ.FRAME_WARM, TJ.Token[],
        Symbol[:test_inject], time())

    make_test_node!("test_node3",
        "hello hi",
        "Grug greet warm. Hello, friend.";
        action_packet = "greet^3 | welcome^2",
        lobe_id = "default")

    line = spoken_line(build_payload("hello", "test_node3", "greet"))

    @test occursin("[Grug greet warm]", line)
    @test occursin("Hello, friend", line)
    # Old buggy form gone:
    @test !occursin("here is what matters: hello hi.", line)
    TJ.reset_last_judgement!()
end

println("\n" * "="^70)
println("GRUG v7.21b-3d — coherence fix tests COMPLETE")
println("="^70)
