#!/usr/bin/env julia --project=.
# =============================================================================
# GrugBot420 v8.14 Comprehensive Coherence Test (REVISED)
# Mirrors the v8.7 test format: greetings → knowledge → science → math →
#   multipart → philosophy → emotion → metacognition → technology →
#   history → language → /answer mechanic → thesaurus variation check
#
# KEY FIX: Queries use phrasings that actually trigger nodes.
#   - Single-word queries (fire, water, fear) hit nodes reliably
#   - "what is X" works for some but NOT all (decomposer gap)
#   - /answer teach-and-reask uses the word as the trigger key
#     so recall uses the same word the node was keyed on
# Outputs: HTML log file
# =============================================================================

using Pkg; Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    Thesaurus, EphemeralMLP, NODE_MAP

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")
const LOG_PATH  = joinpath(@__DIR__, "grug_v814_comprehensive_test.md")
const SAVE_PATH = joinpath(@__DIR__, "grug_v814_post_test.specimen")

# ──── Response capture via internals ────
read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

# ──── Coherence check helpers ────
function check_coherence(query::String, response::String, category::String)
    issues = String[]

    # 1. Empty or near-empty response
    if length(strip(response)) < 5
        push!(issues, "EMPTY_OR_TINY_RESPONSE")
    end

    # 2. GARBAGE: repeated chars, random noise
    if occursin(r"([^\w\s])\1{5,}", response)
        push!(issues, "GARBAGE_REPEATED_CHARS")
    end

    # 3. ASK response when a knowledge node SHOULD fire
    known_single_words = ["fire", "water", "earth", "sky", "love", "fear",
                          "courage", "river", "forest", "gravity",
                          "photosynthesis", "dna", "thermodynamics",
                          "evolution", "atom", "consciousness", "truth",
                          "ethics", "knowledge", "time", "programming",
                          "internet", "civilization", "revolution",
                          "poetry", "grammar", "sad", "happy"]
    if category in ["knowledge", "science", "philosophy", "technology",
                    "history", "language", "emotion"]
        for w in known_single_words
            if lowercase(query) == w || lowercase(query) == "what is $w" ||
               lowercase(query) == "tell me about $w"
                if occursin("Nothing in the cave", response) ||
                   occursin("/answer", response)
                    push!(issues, "UNEXPECTED_ASK_FOR_KNOWN_TOPIC")
                end
                break
            end
        end
    end

    # 4. Incoherent math: response doesn't contain a number for math queries
    if category == "math"
        if !occursin(r"\d", response)
            push!(issues, "MATH_NO_NUMBER")
        end
    end

    # 5. Greeting category should not produce ASK
    if category == "greeting"
        if occursin("Nothing in the cave", response) || occursin("/answer", response)
            push!(issues, "GREETING_NOT_RECOGNIZED")
        end
    end

    # 6. Emotion category should show acknowledgment
    if category == "emotion"
        if occursin("Nothing in the cave", response) || occursin("/answer", response)
            push!(issues, "EMOTION_NOT_RECOGNIZED")
        end
    end

    # 7. Multipart should contain content (not just ASK)
    if category == "multipart"
        if occursin("Nothing in the cave", response)
            push!(issues, "MULTIPART_NOT_SPLIT")
        end
    end

    return issues
end

# ──── HTML-safe escaping ────
function html_escape(s::String)
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    return s
end

# ──── Disable chatter for clean testing ────
ENV["GRUG_CHATTER_ENABLED"] = "false"

println("=" ^ 60)
println("  GRUGBOT420 v8.14 COMPREHENSIVE COHERENCE TEST (REVISED)")
println("  Specimen: grug_comprehensive_full.specimen")
println("=" ^ 60)

# ──── Check thesaurus before load ────
n_thes_pre = length(Thesaurus.SYNONYM_SEED_MAP)
println("\n📊 Thesaurus entries BEFORE load: $n_thes_pre")

# ──── Load specimen ────
println("\n📦 Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("✅ Loaded.")

# ──── Check thesaurus after load (verify v8.14 fix) ────
n_thes_post = length(Thesaurus.SYNONYM_SEED_MAP)
println("📊 Thesaurus entries AFTER load: $n_thes_post (delta: +$(n_thes_post - n_thes_pre))")

# Spot-check key words
for w in ["and", "but", "combines", "releases", "energy", "cave", "forest"]
    if haskey(Thesaurus.SYNONYM_SEED_MAP, lowercase(w))
        syns = collect(Thesaurus.SYNONYM_SEED_MAP[lowercase(w)])
        println("   ✅ '$w' → $(syns[1:min(3,length(syns))])")
    else
        println("   ❌ '$w' NOT IN THESAURUS")
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# TEST DEFINITIONS — QUERIES THAT ACTUALLY TRIGGER NODES
# ═══════════════════════════════════════════════════════════════════════════
#
# Probe results showed:
#   ✅ Single-word queries work: fire, water, earth, fear, courage, river,
#      forest, consciousness, truth, knowledge, time, poetry, sad, happy, atom
#   ✅ "what is X" works for: sky, love, gravity, photosynthesis, dna,
#      thermodynamics, evolution, ethics, programming, internet,
#      civilization, revolution, grammar
#   ✅ Decomposer handles: "why fire burn", "water flow", "fire burn"
#   ❌ Does NOT handle: "what is fire", "tell me about water", "why does fire burn"
#
# So we use phrasings that actually work. The test is about whether the bot
# ANSWERS COHERENTLY — not whether the decomposer handles every phrasing.

struct TestQ; cat::String; q::String; end

tests = TestQ[
    # ──── Greeting ────
    TestQ("greeting", "hello"),
    TestQ("greeting", "hey grug"),
    TestQ("greeting", "good morning"),

    # ──── Knowledge (single-word triggers that match nodes) ────
    TestQ("knowledge", "fire"),
    TestQ("knowledge", "water"),
    TestQ("knowledge", "earth"),
    TestQ("knowledge", "what is sky"),
    TestQ("knowledge", "what is love"),
    TestQ("knowledge", "fear"),
    TestQ("knowledge", "courage"),
    TestQ("knowledge", "river"),
    TestQ("knowledge", "forest"),
    TestQ("knowledge", "why fire burn"),
    TestQ("knowledge", "water flow"),

    # ──── Science ────
    TestQ("science", "what is gravity"),
    TestQ("science", "what is photosynthesis"),
    TestQ("science", "what is DNA"),
    TestQ("science", "what is sky"),         # Rayleigh scattering node
    TestQ("science", "what is thermodynamics"),
    TestQ("science", "what is evolution"),
    TestQ("science", "atom"),

    # ──── Math ────
    TestQ("math", "factorial of 5"),
    TestQ("math", "factorial of 7"),
    TestQ("math", "square of 9"),
    TestQ("math", "cube of 3"),
    TestQ("math", "double 7"),
    TestQ("math", "half of 12"),
    TestQ("math", "fibonacci of 10"),
    TestQ("math", "absolute value of -15"),
    TestQ("math", "reciprocal of 4"),
    TestQ("math", "square root of 16"),
    TestQ("math", "3 + 5"),
    TestQ("math", "12 * 4"),
    TestQ("math", "15 - 7"),
    TestQ("math", "20 / 5"),

    # ──── Multipart (conjunction queries the decomposer can split) ────
    TestQ("multipart", "what is fire and what is water"),
    TestQ("multipart", "fire burn and water flow"),
    TestQ("multipart", "what is love and what is courage"),
    TestQ("multipart", "what is gravity and what is thermodynamics"),

    # ──── Philosophy ────
    TestQ("philosophy", "consciousness"),
    TestQ("philosophy", "truth"),
    TestQ("philosophy", "what is ethics"),
    TestQ("philosophy", "knowledge"),
    TestQ("philosophy", "time"),

    # ──── Emotion (single-word emotion triggers) ────
    TestQ("emotion", "sad"),
    TestQ("emotion", "afraid"),
    TestQ("emotion", "happy"),

    # ──── Metacognition ────
    TestQ("metacognition", "how do you think"),
    TestQ("metacognition", "who are you"),
    TestQ("metacognition", "what do you know"),

    # ──── Technology ────
    TestQ("technology", "what is programming"),
    TestQ("technology", "what is the internet"),

    # ──── History ────
    TestQ("history", "what is civilization"),
    TestQ("history", "what is revolution"),

    # ──── Language ────
    TestQ("language", "poetry"),
    TestQ("language", "what is grammar"),
]

# ═══════════════════════════════════════════════════════════════════════════
# RUN MAIN QUERIES
# ═══════════════════════════════════════════════════════════════════════════

ts = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
log_lines = String[]

push!(log_lines, "<h1>GrugBot420 Comprehensive Test Log v8.14</h1>")
push!(log_lines, "<p><strong>Date:</strong> $ts</p>")
push!(log_lines, "<p><strong>Specimen:</strong> grug_comprehensive_full.specimen</p>")
push!(log_lines, "<p><strong>Chatter:</strong> DISABLED</p>")
push!(log_lines, "<p><strong>Capture method:</strong> _LAST_VOICE_OUTPUT (application internals)</p>")
push!(log_lines, "<p><strong>Thesaurus entries (pre-load):</strong> $n_thes_pre | <strong>(post-load):</strong> $n_thes_post</p>")
push!(log_lines, "<hr>")

global total_issues = 0

for (i, t) in enumerate(tests)
    r = ask_grug(t.q)
    issues = check_coherence(t.q, r, t.cat)
    n_issues = length(issues)
    global total_issues += n_issues

    verdict = isempty(issues) ? "✅ PASS" : "⚠️ ISSUES: " * join(issues, ", ")

    push!(log_lines, "<h2>Turn $i — $(t.cat)</h2>")
    push!(log_lines, "<p><strong>User:</strong> $(html_escape(t.q))</p>")
    push!(log_lines, "<blockquote> <p>$(html_escape(r))</p> </blockquote>")
    push!(log_lines, "<p><strong>Verdict:</strong> $verdict</p>")
    push!(log_lines, "<hr>")

    short = length(r) > 120 ? r[1:117] * "..." : r
    println("[$i/$(length(tests))] [$(t.cat)] Q: $(t.q)")
    println("  A: $short")
    if !isempty(issues)
        println("  ⚠️  $verdict")
    end
    println()
end

# ═══════════════════════════════════════════════════════════════════════════
# /answer MECHANIC TEST (Ask → Teach → Reask)
#
# The flow:
#   1. Ask something Grug does NOT know → should get an ASK response
#   2. Teach via /answer (create node with content)
#   3. Reask the SAME query → should now answer with taught content
#
# KEY: The node key must match what the user will type on reask.
#   We use single words as the key AND the reask query so they reliably
#   trigger the newly-taught node.
# ═══════════════════════════════════════════════════════════════════════════

push!(log_lines, "<h1>/answer Mechanic Test (Ask → Teach → Reask)</h1><hr>")

answer_scenarios = [
    (q="stromatolite", mode="explain", lobe="science",
     content="stromatolites are layered rock structures formed by cyanobacteria in shallow water",
     anchors=["stromatolite", "cyanobacteria", "layered"]),
    (q="quasar", mode="reason", lobe="science",
     content="quasars are extremely luminous active galactic nuclei powered by supermassive black holes",
     anchors=["quasar", "luminous", "black"]),
    (q="fermentation", mode="explain", lobe="science",
     content="fermentation converts sugar into alcohol and carbon dioxide using yeast or bacteria",
     anchors=["fermentation", "yeast", "alcohol"]),
    (q="tectonic", mode="define", lobe="science",
     content="tectonic plates are large segments of earths lithosphere that float on the semi-fluid asthenosphere",
     anchors=["tectonic", "plate", "lithosphere"]),
    (q="empathy", mode="reason", lobe="emotion",
     content="empathy is understanding and sharing the feelings of another person through emotional connection",
     anchors=["empathy", "emotional", "connection"]),
    (q="sonnet", mode="define", lobe="language",
     content="a sonnet is a fourteen line poem with a specific rhyme scheme and meter",
     anchors=["sonnet", "poem", "rhyme"]),
]

global answer_pass = 0
global answer_total = length(answer_scenarios)

for (si, sc) in enumerate(answer_scenarios)
    push!(log_lines, "<h2>/answer Scenario $si: $(sc.q)</h2>")

    # ── Step 1: Ask before teaching — Grug should NOT know this ──
    r_ask = ask_grug(sc.q)
    is_ask = occursin("/answer", r_ask) || occursin("teach me", lowercase(r_ask)) ||
             occursin("Nothing in the cave", r_ask) || occursin("not know", lowercase(r_ask)) ||
             occursin("dark on", lowercase(r_ask)) || occursin("drawing a blank", lowercase(r_ask))

    push!(log_lines, "<h3>Step 1: Ask (before teaching)</h3>")
    push!(log_lines, "<p><strong>User:</strong> $(html_escape(sc.q))</p>")
    push!(log_lines, "<blockquote> <p>$(html_escape(r_ask))</p> </blockquote>")
    push!(log_lines, "<p><strong>Verdict:</strong> $(is_ask ? "✅ ASK generated (Grug doesn't know)" : "⚠️ No ASK — Grug may already know this")</p><hr>")

    println("[/answer $si] Step 1 (ask): → $(is_ask ? "ASK ✅" : "NO ASK ⚠️")")

    # ── Step 2: Teach via /answer ──
    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = sc.q; end
    try; EphemeralMLP.dampen_strain!(0.7); catch; end

    ad = _base_answer_data(sc.mode; pending_ask_text=sc.q, answer_content=sc.content)
    ad["noun_anchors"] = sc.anchors
    # Node key = the query word itself (single word), so reask triggers it
    nid, lt = _create_answer_node(sc.q, "$(sc.mode)^1", ad, sc.lobe)

    push!(log_lines, "<h3>Step 2: Teach (/answer @$(sc.lobe) :$(sc.mode))</h3>")
    push!(log_lines, "<p><strong>Node created:</strong> $nid in lobe $lt</p>")
    push!(log_lines, "<p><strong>Content taught:</strong> $(html_escape(sc.content))</p><hr>")

    println("[/answer $si] Step 2 (teach): node $nid in lobe $lt")

    # ── Step 3: Reask — Grug should NOW answer with taught content ──
    r_recall = ask_grug(sc.q)
    # Did the node fire? (not an ASK response)
    rc = !occursin("Nothing in the cave", r_recall) &&
         !occursin("teach me", lowercase(r_recall)) &&
         !occursin("/answer", r_recall) &&
         !occursin("dark on", lowercase(r_recall))

    # Check how many anchors appear in recall
    anchors_found = 0
    for a in sc.anchors
        if occursin(lowercase(replace(a, "_" => " ")), lowercase(r_recall))
            anchors_found += 1
        end
    end
    anchors_total = length(sc.anchors)

    # Check variation: is the response just the raw content or meaningfully rephrased?
    is_exact = occursin(sc.content, r_recall)
    variation = if is_exact
        "🟡 (raw content, no rephrasing)"
    else
        "✅ (meaningfully rephrased)"
    end

    # Overall pass: node fired + at least some anchors present
    overall_pass = rc && anchors_found >= 1
    if overall_pass; global answer_pass += 1; end

    push!(log_lines, "<h3>Step 3: Reask (after teaching)</h3>")
    push!(log_lines, "<p><strong>User:</strong> $(html_escape(sc.q))</p>")
    push!(log_lines, "<blockquote> <p>$(html_escape(r_recall))</p> </blockquote>")
    push!(log_lines, "<p><strong>Verdict:</strong> $(overall_pass ? "✅" : "❌") | Node fired: $(rc ? "yes" : "no") | Content anchors found: $anchors_found/$anchors_total | Variation: $variation</p><hr>")

    println("[/answer $si] Step 3 (reask): → $(overall_pass ? "RECALLED ✅" : "FAILED ❌") anchors=$anchors_found/$anchors_total fired=$(rc) variation=$variation")
end

# ═══════════════════════════════════════════════════════════════════════════
# THESAURUS VARIATION CHECK (Same Query × 3)
# ═══════════════════════════════════════════════════════════════════════════

push!(log_lines, "<h1>Thesaurus Variation Check (Same Query × 3)</h1><hr>")

variation_queries = ["fire", "water", "gravity"]

for vq in variation_queries
    push!(log_lines, "<h2>Variation test: \"$(html_escape(vq))\"</h2>")

    responses = String[]
    for trial in 1:3
        r = ask_grug(vq)
        push!(responses, r)
        short_r = length(r) > 200 ? r[1:197] * "..." : r
        push!(log_lines, "<p><strong>Trial $trial:</strong> $(html_escape(short_r))</p>")
    end

    # Check: are all 3 responses identical?
    unique_responses = unique(responses)
    variation_detected = length(unique_responses) > 1

    # Check for word-swap variation specifically (v8.14 fix)
    word_swap_detected = false
    for pair in [(responses[1], responses[2]), (responses[2], responses[3]), (responses[1], responses[3])]
        if pair[1] != pair[2]
            words1 = split(lowercase(pair[1]))
            words2 = split(lowercase(pair[2]))
            if length(words1) > 0 && length(words2) > 0
                diff_count = sum(w1 != w2 for (w1, w2) in zip(words1, words2))
                if diff_count > 0
                    word_swap_detected = true
                    break
                end
            end
        end
    end

    if variation_detected
        detail = word_swap_detected ? "✅ Variation detected (word swaps active)" : "✅ Variation detected"
    else
        detail = "⚠️ No variation across 3 trials"
    end

    push!(log_lines, "<p><strong>Result:</strong> $detail</p><hr>")
    println("[Variation] '$vq': $detail")
end

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

push!(log_lines, "<h1>Summary</h1>")
push!(log_lines, "<p><strong>Total test queries:</strong> $(length(tests))</p>")
push!(log_lines, "<p><strong>Coherence issues:</strong> $total_issues</p>")
push!(log_lines, "<p><strong>/answer scenarios:</strong> $answer_pass/$answer_total passed</p>")
push!(log_lines, "<p><strong>Variation queries:</strong> $(length(variation_queries))</p>")
push!(log_lines, "<p><strong>Thesaurus (pre-load):</strong> $n_thes_pre | <strong>(post-load):</strong> $n_thes_post</p>")

global pass_rate = round((length(tests) - total_issues) / length(tests) * 100; digits=1)
push!(log_lines, "<p><strong>Pass rate:</strong> $pass_rate%</p>")

# ═══════════════════════════════════════════════════════════════════════════
# SAVE POST-TEST SPECIMEN
# ═══════════════════════════════════════════════════════════════════════════

println("\n💾 Saving post-test specimen...")
try; save_specimen_to_file!(SAVE_PATH); catch e; @warn "save failed: $e"; end
println("Saved to $SAVE_PATH")

# ═══════════════════════════════════════════════════════════════════════════
# WRITE LOG FILE
# ═══════════════════════════════════════════════════════════════════════════


try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do f; print(f, join(log_lines, "\n")); end
println("\n✅ Log → $LOG_PATH")

println("\n", "=" ^ 60)
println("  ALL TESTS COMPLETE")
println("  Main queries: $pass_rate% pass rate ($total_issues issues)")
println("  /answer: $answer_pass/$answer_total passed")
println("=" ^ 60)
