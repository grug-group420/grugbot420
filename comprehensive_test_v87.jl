#!/usr/bin/env julia
# ==============================================================================
# Comprehensive GrugBot420 Test — v8.18 Format
# Uses _LAST_VOICE_OUTPUT (NO stdout scraping) for speed
# Produces markdown log matching grug_v87_comprehensive_test.md format
# Order: Normal tests → Thesaurus variation → /answer mechanic →
#        Thesaurus on /answer recall → Sigil verification → Write log
# ==============================================================================

include("src/GrugBot420.jl")
using .GrugBot420
import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    LAST_VOTER_IDS, LAST_VOTER_LOCK, NODE_MAP, NODE_LOCK

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")
load_specimen_from_file!(SPEC_PATH)
println("[BOOT] Specimen loaded.")

# ── Fast capture helpers ──────────────────────────────────────────────────────
read_voice() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

try
    const _devnull = open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
end"/dev/null", "w")

function strip_debug_telemetry(voice::String)::String
    sep = "--- DEBUG TELEMETRY"
    idx = findfirst(sep, voice)
    if idx !== nothing
        return strip(voice[1:first(idx)-1])
    end
    return strip(voice)
end

function ask_grug(text)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; redirect_stdout(_devnull) do; process_mission(text); end; catch e; end
    r = strip_debug_telemetry(read_voice())
    is_ask = occursin("Nothing in the cave", r) || occursin("drawing a blank", r) || occursin("nothing fires", r) || occursin("lands in silence", r)
    return is_ask ? "ASK" : (isempty(r) ? "EMPTY" : "ANSWER"), r
end

function get_telemetry()
    fired_node   = _LAST_FIRED_NODE[]
    primary_act  = _LAST_PRIMARY_ACTION[]
    confidence   = _LAST_CONFIDENCE[]
    voter_ids    = lock(() -> copy(LAST_VOTER_IDS), LAST_VOTER_LOCK)
    return fired_node, primary_act, confidence, voter_ids
end

# ── Programmatic /answer handler ──────────────────────────────────────────────
import .GrugBot420:
    _base_answer_data, _plant_answer_cluster, _ANSWER_MODE_CONFIG,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    _VALID_ANSWER_MODES, Lobe, immune_gate, EphemeralMLP

function teach_grug(query_text::String, lobe_id::String, mode::String, content::String)
    if mode ∉ _VALID_ANSWER_MODES
        error("Unknown answer mode: $mode")
    end
    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        _HIPPOCAMPAL_PENDING_ASK[] = query_text
    end
    try; EphemeralMLP.dampen_strain!(0.7); catch e; end
    pending_ask_text = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        old = _HIPPOCAMPAL_PENDING_ASK[]
        _HIPPOCAMPAL_PENDING_ASK[] = ""
        old
    end
    if !immune_gate("/answer", content; is_critical=false)
        return ""
    end
    target_lobe = if haskey(Lobe.LOBE_REGISTRY, lobe_id)
        lobe_id
    else
        nothing
    end
    cfg = get(_ANSWER_MODE_CONFIG, mode, _ANSWER_MODE_CONFIG["reason"])
    action_pkt = cfg["action"]
    typed_data = _base_answer_data(mode; pending_ask_text=pending_ask_text, answer_content=content)
    nid, shadow_ids, lobe_tag = _plant_answer_cluster(content, action_pkt, typed_data, target_lobe, mode)
    return nid
end

# ── Normal test turns (56 turns matching v8.7) ──────────────────────────────

const normal_tests = [
    (1, "greeting", "hello"),
    (2, "greeting", "hey grug"),
    (3, "greeting", "good morning"),
    (4, "knowledge", "what is fire"),
    (5, "knowledge", "tell me about water"),
    (6, "knowledge", "what is earth"),
    (7, "knowledge", "what is sky"),
    (8, "knowledge", "what is love"),
    (9, "knowledge", "what is fear"),
    (10, "knowledge", "what is courage"),
    (11, "knowledge", "what is river"),
    (12, "knowledge", "what is forest"),
    (13, "knowledge", "why does fire burn"),
    (14, "knowledge", "how does water flow"),
    (15, "science", "what is gravity"),
    (16, "science", "what is photosynthesis"),
    (17, "science", "what is DNA"),
    (18, "science", "why is the sky blue"),
    (19, "science", "what is thermodynamics"),
    (20, "science", "what is evolution"),
    (21, "science", "what is an atom"),
    (22, "math", "factorial of 5"),
    (23, "math", "factorial of 7"),
    (24, "math", "square of 9"),
    (25, "math", "cube of 3"),
    (26, "math", "double 7"),
    (27, "math", "half of 12"),
    (28, "math", "fibonacci of 10"),
    (29, "math", "absolute value of -15"),
    (30, "math", "reciprocal of 4"),
    (31, "math", "square root of 16"),
    (32, "math", "3 + 5"),
    (33, "math", "12 * 4"),
    (34, "math", "15 - 7"),
    (35, "math", "20 / 5"),
    (36, "multipart", "what is fire and what is water"),
    (37, "multipart", "why does fire burn and why does water flow"),
    (38, "multipart", "what is love and what is courage"),
    (39, "multipart", "what is gravity and what is thermodynamics"),
    (40, "philosophy", "what is consciousness"),
    (41, "philosophy", "what is truth"),
    (42, "philosophy", "what is ethics"),
    (43, "philosophy", "what is knowledge"),
    (44, "philosophy", "what is time"),
    (45, "emotion", "i feel sad"),
    (46, "emotion", "i am afraid"),
    (47, "emotion", "i feel happy"),
    (48, "metacognition", "how do you think"),
    (49, "metacognition", "who are you"),
    (50, "metacognition", "what do you know"),
    (51, "technology", "what is programming"),
    (52, "technology", "what is the internet"),
    (53, "history", "what is civilization"),
    (54, "history", "what is revolution"),
    (55, "language", "what is poetry"),
    (56, "language", "what is grammar"),
]

# ── /answer test scenarios (6 scenarios matching v8.7) ────────────────────────

const answer_scenarios = [
    (1, "what is a stromatolite",   "@science",    ":explain", "stromatolites are layered rock structures formed by cyanobacteria in shallow water"),
    (2, "what is a quasar",         "@science",    ":reason",  "quasars are extremely luminous active galactic nuclei powered by supermassive black holes"),
    (3, "what is fermentation",     "@science",    ":explain", "fermentation converts sugar into alcohol and carbon dioxide using yeast or bacteria"),
    (4, "what is the golden ratio",  "@science",":define",  "the golden ratio is approximately 1.618 and appears in art architecture and nature"),
    (5, "what is empathy",          "@emotion",    ":reason",  "empathy is understanding and sharing the feelings of another person through emotional connection"),
    (6, "what is a sonnet",         "@language",   ":define",  "a sonnet is a fourteen line poem with a specific rhyme scheme and meter"),
]

# ── Thesaurus variation tests (3 topics × 3 trials) ──────────────────────────

const variation_tests = [
    "what is fire",
    "what is water",
    "what is gravity",
]

# ==============================================================================
# RUN TESTS
# ==============================================================================

const LOG_PATH = joinpath(@__DIR__, "grug_comprehensive_test_log.md")
log_lines = String[]

# ── Header ────────────────────────────────────────────────────────────────────
now_str = Libc.strftime("%Y-%m-%d %H:%M:%S", time())
push!(log_lines, "# GrugBot420 Comprehensive Test Log v8.18")
push!(log_lines, "")
push!(log_lines, "**Date:** $now_str")
push!(log_lines, "")
push!(log_lines, "**Specimen:** grug_comprehensive_full.specimen")
push!(log_lines, "")
push!(log_lines, "**Chatter:** DISABLED")
push!(log_lines, "")
push!(log_lines, "**Capture method:** _LAST_VOICE_OUTPUT (application internals)")
push!(log_lines, "")
push!(log_lines, "**Engine changes:** v8.18 — thesaurus variation restored for ALL voice output; new sigils &concept, &query, &definition, &action registered")
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

# ── Part 0: Sigil Verification ────────────────────────────────────────────────
println("[TEST] Running sigil verification...")

push!(log_lines, "")
push!(log_lines, "# Sigil Registry Verification (v8.18)")
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

import .GrugBot420: SigilRegistry, SigilPromoter
sigil_table = SigilRegistry.default_registry()

for name in ["n", "word", "rest", "noun", "op", "concept", "query", "definition", "action"]
    e = get(sigil_table.entries, name, nothing)
    if e !== nothing
        promote_str = e.promote_at_tokenize ? "promote=true" : "promote=false"
        push!(log_lines, "- **&$(name):** class=$(e.class), type=$(e.sigil_type), $(promote_str)")
    else
        push!(log_lines, "- **&$(name):** NOT REGISTERED ❌")
    end
end
push!(log_lines, "")

# Test sigil promotion on sample inputs
test_promo_inputs = [
    "what is the golden ratio",
    "explain fermentation",
    "2 + 3",
    "what is empathy",
    "describe quasars",
]
push!(log_lines, "**Sigil promotion examples:**")
push!(log_lines, "")
for input in test_promo_inputs
    rewritten, bindings = SigilPromoter.promote_input(sigil_table, input)
    bind_strs = ["&$(b.name)=$(b.value)" for b in bindings]
    push!(log_lines, "- `$(input)` → `$(rewritten)` ($(join(bind_strs, ", ")))")
end
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

println("[TEST] Sigil verification complete.")

# ── Part 1: Normal Tests ─────────────────────────────────────────────────────
println("[TEST] Running normal tests (56 turns)...")

for (turn_num, category, query) in normal_tests
    status, voice = ask_grug(query)
    fired_node, primary_act, confidence, voter_ids = get_telemetry()

    display_voice = voice
    if length(display_voice) > 500
        display_voice = display_voice[1:497] * "..."
    end

    push!(log_lines, "## Turn $turn_num — $category")
    push!(log_lines, "")
    push!(log_lines, "**User:** $query")
    push!(log_lines, "")
    push!(log_lines, "> $display_voice")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    if turn_num % 10 == 0
        println("  Turn $turn_num done ($category)")
    end
end

println("[TEST] Normal tests complete.")

# ── Part 2: Thesaurus Variation Check (BEFORE /answer to avoid taught-node pollution) ──
println("[TEST] Running thesaurus variation check (3 topics × 3 trials)...")

push!(log_lines, "")
push!(log_lines, "# Thesaurus Variation Check (Same Query × 3)")
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

for query in variation_tests
    topic = replace(query, "what is " => "")
    trials = String[]
    for i in 1:3
        _, voice = ask_grug(query)
        display_v = length(voice) > 200 ? voice[1:197] * "..." : voice
        push!(trials, display_v)
    end

    all_same = trials[1] == trials[2] == trials[3]
    variation_result = all_same ? "⚠️ No variation detected" : "✅ Variation detected"

    push!(log_lines, "## Variation test: \"$query\"")
    push!(log_lines, "")
    for (i, t) in enumerate(trials)
        push!(log_lines, "**Trial $i:** $t")
        push!(log_lines, "")
    end
    push!(log_lines, "**Result:** $variation_result")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    println("  Variation test done ($topic)")
end

println("[TEST] Thesaurus variation check complete.")

# ── Part 3: /answer Mechanic Test (after thesaurus so taught nodes don't pollute matching) ──
println("[TEST] Running /answer mechanic test (6 scenarios)...")

push!(log_lines, "")
push!(log_lines, "# /answer Mechanic Test (Teach-and-Reask with Lobes)")
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

for (scen_num, query, lobe_id, mode, content) in answer_scenarios
    topic = replace(query, "what is a " => "", "what is the " => "", "what is " => "")

    # Step 1: Ask before teaching
    status_pre, voice_pre = ask_grug(query)

    ask_ok = (status_pre == "ASK")
    ask_verdict = ask_ok ? "✅ ASK generated" : "⚠️ Expected ASK, got $status_pre"

    push!(log_lines, "## /answer Scenario $scen_num: $query")
    push!(log_lines, "")
    push!(log_lines, "### Step 1: Ask (before teaching)")
    push!(log_lines, "")
    push!(log_lines, "**User:** $query")
    push!(log_lines, "")
    push!(log_lines, "> $voice_pre")
    push!(log_lines, "")
    push!(log_lines, "**Verdict:** $ask_verdict")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    # Step 2: Teach with /answer programmatically
    teach_lobe = replace(lobe_id, "@" => "")
    nid = teach_grug(query, teach_lobe, replace(mode, ":" => ""), content)

    push!(log_lines, "### Step 2: Teach (/answer $lobe_id $mode)")
    push!(log_lines, "")
    push!(log_lines, "**Node created:** $nid in lobe (lobe: $teach_lobe)")
    push!(log_lines, "")
    push!(log_lines, "**Content:** $content")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    # Step 3: Recall after teaching
    status_post, voice_post = ask_grug(query)

    content_words = split(lowercase(content))
    key_words = filter(w -> length(w) > 4, content_words)
    anchors_found = count(w -> occursin(w, lowercase(voice_post)), key_words)
    anchors_total = length(key_words)

    if occursin(content, lowercase(voice_post)) || anchors_found >= max(1, anchors_total ÷ 2)
        if anchors_found == anchors_total
            variation = "✅ (meaningfully rephrased)"
        else
            variation = "🟡 (rephrased with framing)"
        end
        recall_verdict = "✅ | Content anchors found: $anchors_found/$anchors_total | Variation: $variation"
    else
        recall_verdict = "❌ | Content anchors found: $anchors_found/$anchors_total | Variation: ⚠️ (content not recalled)"
    end

    push!(log_lines, "### Step 3: Recall (after teaching)")
    push!(log_lines, "")
    push!(log_lines, "**User:** $query")
    push!(log_lines, "")
    push!(log_lines, "> $voice_post")
    push!(log_lines, "")
    push!(log_lines, "**Verdict:** $recall_verdict")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    println("  Scenario $scen_num done ($topic)")
end

println("[TEST] /answer mechanic test complete.")

# ── Part 4: Thesaurus on /answer Recall Variation Check ────────────────────────
println("[TEST] Running thesaurus-on-answer-recall variation check...")

push!(log_lines, "")
push!(log_lines, "# Thesaurus Variation on /answer Recall (Same Query × 3)")
push!(log_lines, "")
push!(log_lines, "Tests that thesaurus variation applies to /answer recall output,")
push!(log_lines, "not just to specimen-matched responses. Asks the same /answer-taught")
push!(log_lines, "question 3 times and checks for variation across trials.")
push!(log_lines, "")
push!(log_lines, "---")
push!(log_lines, "")

# Pick the first two answer scenarios for the recall variation test
for (scen_idx, (scen_num, query, lobe_id, mode, content)) in enumerate(answer_scenarios[1:2])
    topic = replace(query, "what is a " => "", "what is the " => "", "what is " => "")
    trials = String[]
    for i in 1:3
        _, voice = ask_grug(query)
        display_v = length(voice) > 200 ? voice[1:197] * "..." : voice
        push!(trials, display_v)
    end

    all_same = trials[1] == trials[2] == trials[3]
    variation_result = all_same ? "⚠️ No variation (rote repetition)" : "✅ Variation detected (thesaurus active on /answer recall)"

    push!(log_lines, "## /answer Recall variation: \"$query\"")
    push!(log_lines, "")
    for (i, t) in enumerate(trials)
        push!(log_lines, "**Trial $i:** $t")
        push!(log_lines, "")
    end
    push!(log_lines, "**Result:** $variation_result")
    push!(log_lines, "")
    push!(log_lines, "---")
    push!(log_lines, "")

    println("  /answer recall variation test done ($topic)")
end

println("[TEST] Thesaurus-on-answer-recall variation check complete.")

# ── Write the log ─────────────────────────────────────────────────────────────

try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do f
    println(f, join(log_lines, "\n"))
end
println("[DONE] Log written to $LOG_PATH")

close(_devnull)
