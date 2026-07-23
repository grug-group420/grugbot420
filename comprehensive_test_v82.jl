#!/usr/bin/env julia --project=.
# ==============================================================================
# GrugBot420 Comprehensive Test v8.7
# Tests: greeting, regular knowledge, math/action, multipart, philosophy,
#         science, technology, emotion, metacognition, teach-and-reask,
#         thesaurus variation check
# Capture: _LAST_VOICE_OUTPUT internals (no stdout scraping)
# ==============================================================================

using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP,
    get_node_status_summary

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")
const LOG_PATH  = joinpath(@__DIR__, "grug_v87_comprehensive_test.md")
const SAVE_PATH = joinpath(@__DIR__, "grug_v87_post_test.specimen")

# ──── Response capture via internals ────
read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    # Strip ALL DEBUG TELEMETRY sections (multipart output may have multiple)
    # Split on the separator, keep only conversational text parts
    parts = split(r, "--- DEBUG TELEMETRY")
    kept = String[]
    for (i, p) in enumerate(parts)
        if i == 1
            s = strip(string(p))
            !isempty(s) && push!(kept, s)
        else
            lines = split(string(p), "\n")
            blank_idx = findfirst(isempty, lines)
            if blank_idx !== nothing && blank_idx < length(lines)
                after_blank = strip(join(lines[blank_idx+1:end], "\n"))
                !isempty(after_blank) && push!(kept, after_blank)
            end
        end
    end
    result = join(kept, "\n\n")
    return strip(replace(result, r"\n{3,}" => "\n\n"))
end

# ──── Disable chatter for clean testing ────
ENV["GRUG_CHATTER_ENABLED"] = "false"

println("=" ^ 60)
println("  GRUGBOT420 COMPREHENSIVE TEST v8.7")
println("  Specimen: grug_comprehensive_full.specimen")
println("=" ^ 60)

# ──── Load specimen ────
println("\n📦 Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("✅ Loaded. Starting tests...\n")

# ==============================================================================
# TEST QUERIES
# ==============================================================================

struct TestQ; cat::String; q::String; end

tests = TestQ[
    # ─── Greeting ───
    TestQ("greeting", "hello"),
    TestQ("greeting", "hey grug"),
    TestQ("greeting", "good morning"),

    # ─── Regular knowledge (nodes exist for these) ───
    TestQ("knowledge", "what is fire"),
    TestQ("knowledge", "tell me about water"),
    TestQ("knowledge", "what is earth"),
    TestQ("knowledge", "what is sky"),
    TestQ("knowledge", "what is love"),
    TestQ("knowledge", "what is fear"),
    TestQ("knowledge", "what is courage"),
    TestQ("knowledge", "what is river"),
    TestQ("knowledge", "what is forest"),
    TestQ("knowledge", "why does fire burn"),
    TestQ("knowledge", "how does water flow"),

    # ─── Science (specimen has these nodes) ───
    TestQ("science", "what is gravity"),
    TestQ("science", "what is photosynthesis"),
    TestQ("science", "what is DNA"),
    TestQ("science", "why is the sky blue"),
    TestQ("science", "what is thermodynamics"),
    TestQ("science", "what is evolution"),
    TestQ("science", "what is an atom"),

    # ─── Math / Action Sigil ───
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

    # ─── Multipart ───
    TestQ("multipart", "what is fire and what is water"),
    TestQ("multipart", "why does fire burn and why does water flow"),
    TestQ("multipart", "what is love and what is courage"),
    TestQ("multipart", "what is gravity and what is thermodynamics"),

    # ─── Philosophy / Emotion / Metacognition ───
    TestQ("philosophy", "what is consciousness"),
    TestQ("philosophy", "what is truth"),
    TestQ("philosophy", "what is ethics"),
    TestQ("philosophy", "what is knowledge"),
    TestQ("philosophy", "what is time"),
    TestQ("emotion", "i feel sad"),
    TestQ("emotion", "i am afraid"),
    TestQ("emotion", "i feel happy"),
    TestQ("metacognition", "how do you think"),
    TestQ("metacognition", "who are you"),
    TestQ("metacognition", "what do you know"),

    # ─── Technology / History / Language ───
    TestQ("technology", "what is programming"),
    TestQ("technology", "what is the internet"),
    TestQ("history", "what is civilization"),
    TestQ("history", "what is revolution"),
    TestQ("language", "what is poetry"),
    TestQ("language", "what is grammar"),
]

# ==============================================================================
# RUN MAIN QUERIES
# ==============================================================================

log = String[]
ts = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
push!(log, "# GrugBot420 Comprehensive Test Log v8.7\n\n")
push!(log, "**Date:** $(ts)\n\n")
push!(log, "**Specimen:** grug_comprehensive_full.specimen\n\n")
push!(log, "**Chatter:** DISABLED\n\n")
push!(log, "**Capture method:** _LAST_VOICE_OUTPUT (application internals)\n\n")
push!(log, "---\n\n")

results = Dict{String, String}()

function flush_log()

try
        open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do f; print(f, join(log, "")); end
end

for (i, t) in enumerate(tests)
    r = ask_grug(t.q)
    results[t.q] = r
    push!(log, "## Turn $i — $(t.cat)\n\n")
    push!(log, "**User:** $(t.q)\n\n")
    push!(log, "> $(replace(r, "\n" => "  \n> "))\n\n")
    push!(log, "---\n\n")
    short = length(r) > 120 ? r[1:117] * "..." : r
    println("[$i/$(length(tests))] [$(t.cat)] Q: $(t.q)\n  A: $(short)\n")
    # Incremental flush every 10 turns
    if i % 10 == 0; flush_log(); end
end

# ==============================================================================
# /answer MECHANIC TEST (Hippocampal ask → teach → recall)
# Tests with lobe assignment AND thesaurus variation check
# ==============================================================================

push!(log, "\n# /answer Mechanic Test (Teach-and-Reask with Lobes)\n\n---\n\n")

answer_scenarios = [
    ("what is a stromatolite", "science", "explain",
     "stromatolites are layered rock structures formed by cyanobacteria in shallow water",
     ["stromatolite", "cyanobacteria", "fossil"]),
    ("what is a quasar", "science", "reason",
     "quasars are extremely luminous active galactic nuclei powered by supermassive black holes",
     ["quasar", "black_hole", "luminous"]),
    ("what is fermentation", "science", "explain",
     "fermentation converts sugar into alcohol and carbon dioxide using yeast or bacteria",
     ["fermentation", "sugar", "yeast"]),
    ("what is the golden ratio", "mathematics", "define",
     "the golden ratio is approximately 1.618 and appears in art architecture and nature",
     ["golden_ratio", "1.618", "proportion"]),
    ("what is empathy", "emotion", "reason",
     "empathy is understanding and sharing the feelings of another person through emotional connection",
     ["empathy", "feeling", "connection"]),
    ("what is a sonnet", "language", "define",
     "a sonnet is a fourteen line poem with a specific rhyme scheme and meter",
     ["sonnet", "poem", "rhyme"]),
]

for (si, (question, lobe, mode, content, anchors)) in enumerate(answer_scenarios)
    push!(log, "## /answer Scenario $si: $(question)\n\n")

    # Step 1: Ask unknown
    r_ask = ask_grug(question)
    push!(log, "### Step 1: Ask (before teaching)\n\n")
    push!(log, "**User:** $(question)\n\n")
    push!(log, "> $(replace(r_ask, "\n" => "  \n> "))\n\n")
    is_ask = occursin("/answer", r_ask) || occursin("teach me", lowercase(r_ask)) ||
             occursin("Nothing in the cave", r_ask) || occursin("not know", lowercase(r_ask)) ||
             occursin("drawing a blank", lowercase(r_ask)) || occursin("cave is dark", lowercase(r_ask)) ||
             occursin("what are you getting at", lowercase(r_ask)) || occursin("help me out", lowercase(r_ask))
    push!(log, "**Verdict:** $(is_ask ? "✅ ASK generated" : "❌ NO ask detected")\n\n---\n\n")
    println("[/answer $si] Step 1: → $(is_ask ? "ASK ✅" : "NO ASK ❌")")

    # Step 2: Teach with /answer + lobe
    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = question; end
    try; EphemeralMLP.dampen_strain!(0.7); catch; end

    # v8.3 FIX: Use the QUESTION TEXT as the node pattern (not anchors[1]).
    # anchors[1] often contains underscores like "golden_ratio" which are
    # single tokens that don't match query words "golden" and "ratio".
    # The question text naturally contains the right tokens for matching.
    pattern_text = replace(lowercase(question), r"^what is (a |the )?" => "")
    ad = _base_answer_data(mode; pending_ask_text=question, answer_content=content)
    ad["noun_anchors"] = anchors
    nid, lt = _create_answer_node(pattern_text, "$(mode)^1", ad, lobe)
    push!(log, "### Step 2: Teach (/answer @$(lobe) :$(mode))\n\n")
    push!(log, "**Node created:** $(nid) in lobe $(lt)\n\n")
    push!(log, "**Content:** $(content)\n\n---\n\n")
    println("[/answer $si] Step 2: node $(nid) in lobe $(lt)")

    # Step 3: Re-ask to test recall
    r_recall = ask_grug(question)
    push!(log, "### Step 3: Recall (after teaching)\n\n")
    push!(log, "**User:** $(question)\n\n")
    push!(log, "> $(replace(r_recall, "\n" => "  \n> "))\n\n")
    rc = !isempty(r_recall) && !occursin("Nothing in the cave", r_recall) && !occursin("teach me", lowercase(r_recall)) &&
         !occursin("drawing a blank", lowercase(r_recall))
    # Check if content keywords appear (may be thesaurus-swapped)
    anchor_hits = [a for a in anchors if occursin(lowercase(replace(a, "_" => " ")), lowercase(r_recall))]
    # GRUG v8.6: Three-tier variation check:
    #   1) EXACT MATCH — recall == content (verbatim parrot, worst)
    #   2) CONTAINS — original content is substring of recall (lightly rephrased, ok)
    #   3) REPHRASED — content is NOT a substring but anchors are present (meaningfully rephrased, best)
    _r_lower = lowercase(r_recall)
    _c_lower = lowercase(content)
    if _r_lower == _c_lower
        variation_tier = "❌ (exact verbatim)"
        is_varied = false
    elseif occursin(_c_lower, _r_lower)
        # Content is a substring but recall has extra framing/hedges
        # Check if there's meaningful structural variation beyond a simple prefix
        # Simple check: if recall is much longer than content, it has substantial framing
        if length(_r_lower) > length(_c_lower) + 30
            variation_tier = "🟡 (rephrased with framing)"
            is_varied = true
        else
            variation_tier = "🟡 (lightly hedged)"
            is_varied = false  # still a parrot, just with a small prefix
        end
    else
        variation_tier = "✅ (meaningfully rephrased)"
        is_varied = true
    end
    push!(log, "**Verdict:** $(rc ? "✅" : "❌") | Content anchors found: $(length(anchor_hits))/$(length(anchors)) | Variation: $(variation_tier)\n\n---\n\n")
    println("[/answer $si] Step 3: → $(rc ? "RECALLED ✅" : "FAILED ❌") variation: $(variation_tier) anchors: $(length(anchor_hits))/$(length(anchors))")
    flush_log()
end

# ==============================================================================
# THESAURUS VARIATION CHECK — ask same question twice, see if output differs
# ==============================================================================

push!(log, "\n# Thesaurus Variation Check (Same Query × 3)\n\n---\n\n")

variation_queries = ["what is fire", "what is water", "what is gravity"]
for vq in variation_queries
    push!(log, "## Variation test: \"$(vq)\"\n\n")
    responses = String[]
    for trial in 1:3
        r = ask_grug(vq)
        push!(responses, r)
        # v8.3 FIX: Use SubString with Unicode-safe indexing —
        # r[1:200] crashes on multi-byte chars like '—' (em dash).
        _preview = length(r) <= 200 ? r : SubString(r, 1, nextind(r, 1, 200))
        push!(log, "**Trial $trial:** $(_preview)$(length(r) > 200 ? "..." : "")\n\n")
    end
    all_same = responses[1] == responses[2] == responses[3]
    any_diff = responses[1] != responses[2] || responses[2] != responses[3]
    push!(log, "**Result:** $(all_same ? "❌ All identical (no variation)" : (any_diff ? "✅ Variation detected" : "⚠️ Partial"))\n\n---\n\n")
    println("[variation] $(vq): $(all_same ? "ALL SAME ❌" : "VARIED ✅")")
end

# ==============================================================================
# SAVE POST-TEST SPECIMEN
# ==============================================================================

println("\n💾 Saving post-test specimen...")
try; save_specimen_to_file!(SAVE_PATH); catch e; @warn "save failed: $e"; end
println("Saved to $(SAVE_PATH)")

# ==============================================================================
# WRITE LOG FILE
# ==============================================================================


try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do f; print(f, join(log, "")); end
println("\n✅ Log → $(LOG_PATH)")

println("\n", "=" ^ 60)
println("  ALL TESTS COMPLETE")
println("=" ^ 60)
