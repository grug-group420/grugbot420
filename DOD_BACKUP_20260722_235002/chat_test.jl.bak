# GrugBot Comprehensive Specimen — Interactive Chat Test
# Loads the specimen, chats with it, records I/O to transcript MD

include("src/Main.jl")
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

println("\n" * "="^70)
println("  GRUGBOT COMPREHENSIVE SPECIMENT CHAT TEST")
println("="^70)

# ── Load specimen ──
println("\n── Loading comprehensive specimen ──")
spec_path = "specimens/comprehensive_specimen.json"
result = load_specimen_from_file!(spec_path)
println(result)

# ── Helper: process and capture ──
transcript_lines = String[]

function chat(input_text::String)
    push!(transcript_lines, "## USER")
    push!(transcript_lines, input_text)
    push!(transcript_lines, "")
    try
        response = process_mission(input_text)
        push!(transcript_lines, "## GRUGBOT")
        push!(transcript_lines, string(response))
        push!(transcript_lines, "")
        println("USER: $input_text")
        println("GRUG: $response")
        println()
    catch e
        err_msg = "ERROR: $e"
        push!(transcript_lines, "## GRUGBOT (ERROR)")
        push!(transcript_lines, err_msg)
        push!(transcript_lines, "")
        println("USER: $input_text")
        println("GRUG (ERROR): $err_msg")
        println()
    end
end

# ── State snapshot ──
_node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
_msg_count = length(MESSAGE_HISTORY)
_arousal = EyeSystem.get_arousal()
println("  Nodes loaded: $_node_count")
println("  Messages loaded: $_msg_count")
println("  Arousal: $_arousal")

# ── Chat interactions covering all features ──
println("\n── Phase 1: Greeting (greet family) ──")
chat("hello")

println("\n── Phase 2: Mathematics (reason family) ──")
chat("what is a derivative")
chat("define integral")
chat("explain the pythagorean theorem")

println("\n── Phase 3: Philosophy (ponder/analyze family) ──")
chat("what is consciousness")
chat("meaning of life")
chat("do we have free will")

println("\n── Phase 4: Survival (flee/hide/fight family) ──")
chat("danger!")
chat("i need to hide")
chat("fight back")

println("\n── Phase 5: Empathy (comfort/support/validate family) ──")
chat("i feel sad")
chat("i feel anxious")
chat("validate my feelings")

println("\n── Phase 6: Creativity (elaborate family) ──")
chat("write a poem")
chat("tell me a story")
chat("imagine something")

println("\n── Phase 7: Warning (alert family) ──")
chat("watch out")

println("\n── Phase 8: Ask (inquire/question family) ──")
chat("why does the sun shine")

println("\n── Phase 9: Time nodes ──")
chat("what time is it")
chat("what happened before")

println("\n── Phase 10: Antimatch nodes ──")
chat("ignore mathematics and tell me about poetry")
chat("stop empathy i just want facts")

println("\n── Phase 11: Image nodes ──")
chat("sunset image")

println("\n── Phase 12: Cross-lobe queries (bridge testing) ──")
chat("how does consciousness relate to mathematics")
chat("is danger an emotional experience")
chat("can philosophy inspire creative writing")

println("\n── Phase 13: Relational queries ──")
chat("what does calculus include")
chat("how are derivatives and integrals related")

println("\n── Phase 14: Sacred/unlinkable knowledge ──")
chat("sacred knowledge")

println("\n── Phase 15: Compound/chained queries ──")
chat("what is a derivative and what is an integral")
chat("hello, can you explain what consciousness is")

println("\n── Phase 16: Persistence & state check ──")
chat("/status")

# ── Write transcript ──
transcript_path = "specimens/chat_transcript.md"
open(transcript_path, "w") do io
    println(io, "# GrugBot420 Comprehensive Specimen — Chat Transcript")
    println(io, "")
    println(io, "Generated from specimen: `specimens/comprehensive_specimen.json`")
    println(io, "")
    println(io, "## Specimen Overview")
    println(io, "")
    println(io, "- **Nodes**: 25 (regular, time, antimatch, image, grave, unlinkable)")
    println(io, "- **Lobes**: 5 (mathematics, philosophy, survival, empathy, creativity)")
    println(io, "- **Bridges**: 4 (cross-lobe nodeAttach)")
    println(io, "- **AIML Nodes**: 6 (across 4 lobes)")
    println(io, "- **Action Families**: 7 (reason, greet, survival, explain, empathy, warning, ask)")
    println(io, "- **Voice Registers**: 5 (warm, terse, casual, plain, formal)")
    println(io, "- **Frame Hints**: 7 (contemplative, de-escalating, exploratory, imperative, plain, terse, warm)")
    println(io, "- **Config Sections**: 47+ (all knobs, all levers, all state)")
    println(io, "")
    println(io, "---")
    println(io, "")
    for line in transcript_lines
        println(io, line)
    end
end
println("\n── Transcript written to: $transcript_path ──")
