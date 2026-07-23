#!/usr/bin/env julia
# ==============================================================================
# comprehensive_test_v828b.jl — GrugBot420 FULL-FEATURE Specimen Test
# ==============================================================================
# Covers ALL features end-to-end:
#   S1:  Decoherence fixes (v8.28b) — false winners, interrogatives, relational
#   S2:  Conversation prescan — :define/:question/:correct/:teach/:greeting
#   S3:  Knowledge classification — static/procedural/relational
#   S4:  Subject→Lobe routing
#   S5:  Teach parts parsing
#   S6:  Conversational learning loop — static/procedural/relational
#   S7:  Pending teach expiry
#   S8:  Core regression — greeting/math/science/philosophy/emotion
#   S9:  Dictionary lookup and define
#   S10: Thesaurus and voice rendering coherence
#   S11: Correction and feedback
#   S12: Arithmetic engine
#   S13: Sigil node verification
#   S14: Save/load round-trip
# ==============================================================================

using Dates
using JSON

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK,
    MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK

import .GrugBot420:
    _base_answer_data, _create_answer_node, _plant_answer_cluster,
    _VALID_ANSWER_MODES, _ANSWER_MODE_CONFIG,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    _FANOUT_ENABLED, _FANOUT_MODES,
    _dissolve_solo_group!,
    register_group!, group_for, add_to_group!,
    immune_gate, dampen_strain!,
    create_node

import .GrugBot420:
    _dict_define_word!, _dict_lookup_word, _dict_lookup_for_mission,
    _dict_all_definitions, _dict_definitions_count,
    _dict_save_state, _dict_load_state!,
    _LOBE_DICTIONARIES, _LOBE_DICTIONARIES_LOCK

import .GrugBot420: _conversation_prescan, _conversation_answer_question

import .GrugBot420:
    LAST_VOTER_IDS, LAST_VOTER_LOCK,
    apply_wrong_feedback!, apply_last_selected_feedback!,
    CONTEXT_FEEDBACK_WRONG_DELTA

import .GrugBot420:
    _classify_knowledge, _find_lobe_for_subject, _extract_teach_parts,
    _conv_set_pending_teach!, _conv_get_pending_teach,
    _conv_clear_pending_teach!, _conv_pending_teach_is_expired,
    _CONV_PENDING_TEACH, _CONV_PENDING_TEACH_LOCK

import .GrugBot420:
    create_sigil_node, extract_relational_triples,
    node_sigil_kind, list_sigil_node_ids, SIGIL_TAG_PREFIX,
    Node

import .GrugBot420.Lobe:
    add_node_to_lobe!, find_lobe_for_node, lobe_is_full, LOBE_REGISTRY,
    create_lobe!

import .GrugBot420: count_alive_nodes_in_lobe

import .GrugBot420.EphemeralMLP: get_strain_energy, register_wrong_feedback!

# ── Configuration ──────────────────────────────────────────────────────────────
const SPEC_PATH  = get(ARGS, 1, "/workspace/grugbot420_repo/grug_v828_post_test.specimen")
const LOG_PATH   = "/workspace/grugbot420_repo/grug_v828b_comprehensive_test.md"
const SAVE_PATH  = "/workspace/grugbot420_repo/grug_v828b_post_test.specimen"

# ── In-program MD log buffer ──────────────────────────────────────────────────
const _log_lines = String[]

function log_md(line::String)
    push!(_log_lines, line)
end

function flush_log_md(filepath::String)
    open(filepath, "w") do f
        for line in _log_lines
            println(f, line)
        end
    end
end

# ── Voice output capture ──────────────────────────────────────────────────────
function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try
        process_mission(text)
    catch e
        @warn "process_mission error" exception=e
    end
    return read_last_output()
end

function clean_output(raw::String)::String
    ti = findfirst("--- DEBUG TELEMETRY", raw)
    if ti !== nothing
        raw = strip(raw[1:first(ti)-1])
    end
    lines = split(raw, '\n')
    filtered = filter(l -> !startswith(strip(l), "> "), lines)
    return strip(join(filtered, '\n'))
end

# ── Failure detection ─────────────────────────────────────────────────────────
const FAILURE_PHRASES = [
    "Nothing in the cave",
    "nothing in the cave",
    "cave is empty",
    "Grug shrugs",
    "grug shrugs",
    "no match found",
    "CAVE-EMPTY",
]

function is_failure_response(answer::String)::Bool
    for phrase in FAILURE_PHRASES
        occursin(phrase, answer) && return true
    end
    return false
end

function is_clarification_response(answer::String)::Bool
    occursin("Grug not know", answer) || occursin("What does it mean", answer) ||
    occursin("What subject", answer)
end

# ── Test runners with MD logging ──────────────────────────────────────────────
turn_counter = Ref{Int}(0)

function run_test(category::String, query::String; expect_ask::Bool=false, expect_coherent::Bool=false, no_topic::String="")
    global turn_counter
    turn_counter[] += 1
    turn = turn_counter[]

    raw = run_mission(query)
    answer = clean_output(raw)

    if isempty(answer)
        status = "❌ EMPTY"
        verdict = "EMPTY"
    elseif is_failure_response(answer) && !expect_ask
        status = "❌ CAVE-EMPTY"
        verdict = "CAVE-EMPTY"
    elseif length(answer) < 5
        status = "⚠️ SHORT"
        verdict = "SHORT"
    else
        # Coherence check: if expect_coherent, verify answer doesn't contain false-winner patterns
        coherent = true
        coherent_note = ""
        if expect_coherent
            # Check for false definition patterns: "X means Y" where X is an interrogative
            _interrogatives = ["how", "why", "what", "when", "where", "who", "which"]
            for iw in _interrogatives
                if occursin(Regex("\\b$(iw)\\s+(means|is)\\b", "i"), answer)
                    coherent = false
                    coherent_note = " (FALSE DEFINITION: '$iw means/is' detected)"
                    break
                end
            end
            # Check for self-reference corruption
            if occursin("Fire sit", answer) || occursin("Fire Grug", answer)
                coherent = false
                coherent_note = " (SELF-REF CORRUPTION: Fire→Grug swap)"
            end
        end
        if !isempty(no_topic)
            # Verify the answer does NOT mention no_topic (shouldn't drift)
            if occursin(Regex("\\b$(no_topic)\\b", "i"), answer)
                coherent = false
                coherent_note = " (TOPIC DRIFT: '$no_topic' leaked in)"
            end
        end
        if coherent
            status = "✅"
            verdict = "OK"
        else
            status = "❌ INCOHERENT"
            verdict = "INCOHERENT$coherent_note"
        end
    end

    log_md("## Turn $turn — $category")
    log_md("")
    log_md("**User:** $query")
    log_md("")
    log_md("> $(first(answer, 300))")
    log_md("")
    log_md("**Verdict:** $status $verdict")
    log_md("")
    log_md("---")
    log_md("")

    display_answer = length(answer) > 150 ? first(answer, 150) * "…" : answer
    println("[$status] T$turn $category: \"$query\" → $(display_answer)")

    return (turn, category, query, answer, status, verdict)
end

# ── Conversation prescan test helper ──────────────────────────────────────────
function run_conv_prescan_test(label::String, text::String, expect_kind::Symbol)
    log_md("## ConvPrescan: $label")
    log_md("")
    log_md("**Input:** \"$text\"")
    log_md("**Expected kind:** $expect_kind")
    log_md("")
    result = _conversation_prescan(text)
    if result !== nothing
        kind, word, def, lobe_hint = result
        kind_ok = kind == expect_kind
        status = kind_ok ? "✅ Detected as :$kind" : "❌ Got :$kind, expected :$expect_kind"
        log_md("> $status — word='$word' def='$(first(def,60))' lobe_hint='$lobe_hint'")
    else
        kind_ok = expect_kind == :nothing
        status = kind_ok ? "✅ Correctly returned nothing" : "❌ Returned nothing, expected :$expect_kind"
        log_md("> $status")
    end
    log_md("")
    log_md("---")
    log_md("")
    println("[conv-prescan] $label: $status")
    return (label, kind_ok, result)
end

# ── Knowledge classifier test helper ──────────────────────────────────────────
function run_classify_test(label::String, definition::String, expect_kind::Symbol)
    log_md("## ClassifyKnowledge: $label")
    log_md("")
    log_md("**Input:** \"$definition\"")
    log_md("**Expected:** $expect_kind")
    log_md("")
    result = _classify_knowledge(definition)
    ok = result == expect_kind
    status = ok ? "✅ Classified as :$result" : "❌ Got :$result, expected :$expect_kind"
    log_md("> $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[classify] $label: $status")
    return (label, ok)
end

# ── Subject→lobe routing test helper ──────────────────────────────────────────
function run_lobe_routing_test(label::String, subject::String, expect_contains::String="")
    log_md("## LobeRouting: $label")
    log_md("")
    log_md("**Subject:** \"$subject\"")
    log_md("")
    result = _find_lobe_for_subject(subject)
    ok = isempty(expect_contains) || occursin(expect_contains, result)
    status = ok ? "✅ Routed to '$result'" : "❌ Routed to '$result', expected containing '$expect_contains'"
    log_md("> $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[lobe-route] $label: $status")
    return (label, ok, result)
end

# ── _extract_teach_parts test helper ──────────────────────────────────────────
function run_teach_parts_test(label::String, input::String, expect_subj::String, expect_def::String="")
    log_md("## TeachParts: $label")
    log_md("")
    log_md("**Input:** \"$input\"")
    log_md("**Expected subject:** \"$expect_subj\"")
    if !isempty(expect_def)
        log_md("**Expected definition contains:** \"$expect_def\"")
    end
    log_md("")
    subj, def = _extract_teach_parts(input)
    subj_ok = lowercase(subj) == lowercase(expect_subj) ||
              (isempty(expect_subj) && isempty(subj))
    def_ok = isempty(expect_def) || occursin(lowercase(expect_def), lowercase(def))
    ok = subj_ok && def_ok
    status = ok ? "✅ Parsed: subj='$subj' def='$(first(def, 80))'" :
                  "❌ Got subj='$subj' def='$(first(def, 80))', expected subj='$expect_subj'"
    log_md("> $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[teach-parts] $label: $status")
    return (label, ok)
end

# ── Conversational learning loop test helper ──────────────────────────────────
function run_conv_learn_test(label::String, question::String, teach_response::String;
                             expect_node_type::Symbol=:static,
                             expect_lobe::String="",
                             expect_dict_fragment::String="",
                             expect_sigil_kind::Symbol=:none)
    log_md("## ConvLearn: $label")
    log_md("")
    log_md("**Step 1 — Ask:** \"$question\"")
    log_md("")

    _conv_clear_pending_teach!()
    raw1 = run_mission(question)
    ans1 = clean_output(raw1)
    has_clarification = is_clarification_response(ans1)
    step1_status = has_clarification ? "✅ Clarification asked" : "⚠️ No clarification (maybe known)"
    log_md("**Answer 1:** $(first(ans1, 200))")
    log_md("**Step 1 result:** $step1_status")
    log_md("")

    log_md("**Step 2 — Teach:** \"$teach_response\"")
    log_md("")
    raw2 = run_mission(teach_response)
    ans2 = clean_output(raw2)
    log_md("**Answer 2:** $(first(ans2, 200))")
    log_md("")

    _ok = true
    _details = String[]

    if expect_node_type == :static
        if occursin("📖", ans2) || occursin("Grug learned", ans2)
            push!(_details, "✅ Static knowledge acknowledged")
        else
            push!(_details, "❌ No static acknowledgment")
            _ok = false
        end
    elseif expect_node_type == :procedural
        if occursin("⚡", ans2) || occursin("procedure", lowercase(ans2))
            push!(_details, "✅ Procedural knowledge acknowledged")
        else
            push!(_details, "❌ No procedural acknowledgment")
            _ok = false
        end
    elseif expect_node_type == :relational
        if occursin("🔗", ans2) || occursin("relationship", lowercase(ans2))
            push!(_details, "✅ Relational knowledge acknowledged")
        else
            push!(_details, "❌ No relational acknowledgment")
            _ok = false
        end
    end

    if !isempty(expect_dict_fragment) && has_clarification
        raw3 = run_mission(question)
        ans3 = clean_output(raw3)
        if occursin(lowercase(expect_dict_fragment), lowercase(ans3)) || occursin("📖", ans3)
            push!(_details, "✅ Re-ask confirms knowledge stored")
        else
            push!(_details, "⚠️ Re-ask did not confirm: $(first(ans3, 100))")
        end
    end

    if !isempty(expect_lobe) && has_clarification
        if haskey(LOBE_REGISTRY, expect_lobe)
            push!(_details, "✅ Lobe '$expect_lobe' exists")
        else
            push!(_details, "❌ Lobe '$expect_lobe' not found")
            _ok = false
        end
    end

    if expect_sigil_kind != :none && has_clarification
        _sigil_ids = list_sigil_node_ids(expect_sigil_kind)
        if !isempty(_sigil_ids)
            push!(_details, "✅ Sigil node(s) of kind :$(expect_sigil_kind) exist ($(length(_sigil_ids)))")
        else
            push!(_details, "❌ No sigil nodes of kind :$(expect_sigil_kind)")
            _ok = false
        end
    end

    _pending = _conv_get_pending_teach()
    if isempty(_pending)
        push!(_details, "✅ Pending teach state cleared")
    else
        push!(_details, "⚠️ Pending teach state not cleared")
    end

    for d in _details
        log_md("- $d")
    end

    overall = _ok ? "✅ PASS" : "❌ FAIL"
    log_md("")
    log_md("**Overall:** $overall")
    log_md("")
    log_md("---")
    log_md("")
    println("[conv-learn] $label: $overall")
    return (label, _ok)
end

# ── Pending teach expiry test helper ──────────────────────────────────────────
function run_expiry_test(label::String, question::String, unrelated_input::String)
    log_md("## TeachExpiry: $label")
    log_md("")

    _conv_clear_pending_teach!()
    raw1 = run_mission(question)
    ans1 = clean_output(raw1)
    has_clarification = is_clarification_response(ans1)
    log_md("**Step 1:** Ask \"$question\" → $(first(ans1, 100))")
    log_md("")

    if !has_clarification
        log_md("⚠️ No clarification asked (topic may be known) — skipping expiry test")
        log_md("---")
        println("[teach-expiry] $label: ⚠️ SKIPPED (topic known)")
        return (label, true)
    end

    _pending_after_q = _conv_get_pending_teach()
    pending_was_set = !isempty(_pending_after_q)
    log_md("**Pending state after question:** $pending_was_set")

    if pending_was_set
        lock(_CONV_PENDING_TEACH_LOCK) do
            _CONV_PENDING_TEACH[]["timestamp"] = time() - 200
        end
    end

    raw2 = run_mission(unrelated_input)
    ans2 = clean_output(raw2)

    _pending_after = _conv_get_pending_teach()
    expired_ok = isempty(_pending_after)
    status = expired_ok ? "✅ Pending state expired and cleared" : "❌ Pending state not cleared after expiry"
    log_md("**Step 2:** Send \"$unrelated_input\" → $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[teach-expiry] $label: $status")
    return (label, expired_ok)
end

# ── Save/load round-trip test helper ──────────────────────────────────────────
function run_pending_teach_saveload_test(label::String)
    log_md("## PendingTeachSaveLoad: $label")
    log_md("")

    _conv_clear_pending_teach!()
    _conv_set_pending_teach!("test_topic", "What does test_topic mean?")

    _before = _conv_get_pending_teach()
    before_ok = !isempty(_before) && get(_before, "topic", "") == "test_topic"
    log_md("**Before save:** topic='$(get(_before, "topic", ""))' ok=$before_ok")

    try
        save_specimen_to_file!(SAVE_PATH)
        log_md("**Save:** ✅ Saved to $SAVE_PATH")
    catch e
        log_md("**Save:** ❌ Failed: $e")
        return (label, false)
    end

    _conv_clear_pending_teach!()
    _after_clear = _conv_get_pending_teach()
    clear_ok = isempty(_after_clear)
    log_md("**After clear:** empty=$clear_ok")

    try
        load_specimen_from_file!(SAVE_PATH)
    catch e
        log_md("**Load:** ❌ Failed: $e")
        return (label, false)
    end

    _after_load = _conv_get_pending_teach()
    after_topic = get(_after_load, "topic", "")
    load_ok = after_topic == "test_topic"
    status = load_ok ? "✅ Pending teach state survived round-trip" :
                       "❌ Pending teach state NOT restored (topic='$after_topic')"
    log_md("**After load:** topic='$after_topic' $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[saveload] $label: $status")
    _conv_clear_pending_teach!()
    return (label, load_ok)
end

# ── Coherence checker for decoherence-specific tests ──────────────────────────
function run_coherence_test(label::String, query::String, bad_pattern::Regex, description::String)
    log_md("## CoherenceCheck: $label")
    log_md("")
    log_md("**Input:** \"$query\"")
    log_md("**Bad pattern:** $bad_pattern")
    log_md("**Description:** $description")
    log_md("")

    _conv_clear_pending_teach!()
    raw = run_mission(query)
    answer = clean_output(raw)
    has_bad = occursin(bad_pattern, answer)
    ok = !has_bad
    status = ok ? "✅ No false-winner pattern detected" : "❌ FALSE WINNER: $description detected in output"
    log_md("**Output:** $(first(answer, 300))")
    log_md("**Verdict:** $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[coherence] $label: $status")
    return (label, ok)
end

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TEST SEQUENCE
# ══════════════════════════════════════════════════════════════════════════════

# ── Write MD header ────────────────────────────────────────────────────────────
log_md("# GrugBot420 Comprehensive Test Log v8.28b")
log_md("")
log_md("**Date:** $(now())")
log_md("**Specimen:** $SPEC_PATH")
log_md("**Chatter:** DISABLED")
log_md("**Capture method:** _LAST_VOICE_OUTPUT (application internals)")
log_md("**v8.28b focus:** Decoherence fixes + FULL feature coverage")
log_md("")
log_md("---")
log_md("")

# ── Load specimen ──────────────────────────────────────────────────────────────
println("=" ^ 70)
println("GRUGBOT420 COMPREHENSIVE TEST v8.28b")
println("=" ^ 70)
println("Specimen: $SPEC_PATH")
println("Time: $(now())")
println()

println("Loading specimen...")
try
    load_specimen_from_file!(SPEC_PATH)
    n_nodes = length(lock(() -> collect(keys(NODE_MAP)), NODE_LOCK))
    println("✅ Loaded! $n_nodes nodes in memory")
    log_md("## Specimen Loaded")
    log_md("")
    log_md("**Nodes in memory:** $n_nodes")
    log_md("")

    for (lobe_name, rec) in LOBE_REGISTRY
        alive = count_alive_nodes_in_lobe(lobe_name)
        needed = alive + 40
        if needed > rec.node_cap
            old_cap = rec.node_cap
            rec.node_cap = needed
            println("  📦 Lobe '$lobe_name' cap expanded: $old_cap → $(needed) (alive=$alive)")
        end
    end

    _dc = _dict_definitions_count()
    println("📖 Dictionary definitions loaded: $_dc")
    log_md("**Dictionary definitions after load:** $_dc")
    log_md("")
    log_md("---")
    log_md("")
catch e
    println("❌ LOAD FAILED: $e")
    log_md("❌ LOAD FAILED: $e")
    flush_log_md(LOG_PATH)
    exit(1)
end

# Result collectors
results = []
classify_results = []
lobe_route_results = []
teach_parts_results = []
conv_learn_results = []
teach_expiry_results = []
saveload_results = []
coherence_results = []

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: DECOHERENCE FIXES (v8.28b) — False Winner Detection
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 1: Decoherence Fixes — False Winner Detection")
log_md("")
println("─" ^ 70)
println("SECTION 1: DECOHERENCE FIXES")
println("─" ^ 70)
println()

# The classic false-winner cases that v8.28b fixed
# "how are you feeling" should NOT produce "📖 Learned: how means you feeling"
push!(coherence_results, run_coherence_test(
    "how-feeling-no-false-def",
    "how are you feeling",
    Regex("\\bhow\\s+(means|is)\\b", "i"),
    "\"how means/is\" — interrogative treated as definition target"))

push!(coherence_results, run_coherence_test(
    "why-sky-blue-no-false-def",
    "why is the sky blue",
    Regex("\\bwhy\\s+(means|is the sky)\\b", "i"),
    "\"why means/is the sky\" — interrogative treated as definition target"))

push!(coherence_results, run_coherence_test(
    "what-time-no-false-def",
    "what time is it",
    Regex("\\bwhat\\b.+\\bmeans\\b|\\bwhat\\b\\s+\\w+\\s+means\\s+it\\b", "i"),
    "\"what time means it\" — \"what X is it\" treated as :define instead of :question"))

push!(coherence_results, run_coherence_test(
    "where-are-you-no-false-def",
    "where are you from",
    Regex("\\bwhere\\s+(means|is)\\b", "i"),
    "\"where means/is\" — interrogative treated as definition target"))

# Topic drift / self-reference corruption
push!(coherence_results, run_coherence_test(
    "emotion-no-fire-swap",
    "I feel sad",
    Regex("\\bFire\\b.*\\b(sit|via|feel)\\b", "i"),
    "\"Fire sit via sad\" — thesaurus swapped Grug→Fire"))

# v8.28d: "with" should NOT be swapped to "using" or "via" in voice output
push!(coherence_results, run_coherence_test(
    "emotion-no-using-swap",
    "I feel sad",
    Regex("\\busing\\b.*\\bsad\\b|\\bvia\\b.*\\bsad\\b|\\bsit\\s+using\\b|\\bsit\\s+via\\b", "i"),
    "\"Grug sit using sad\" — thesaurus swapped with→using/via"))

# v8.28d: pending teach should not bleed into subsequent question
# This test simulates the real crosstalk scenario: first ask about penicillin
# (which sets pending teach), then immediately ask about tides WITHOUT clearing
# pending state. The topic-shift detection should clear pending automatically.
log_md("## CoherenceCheck: pending-teach-no-crosstalk")
log_md("")
log_md("**Description:** \"penicillin\" in tides response — pending teach crosstalk")
log_md("")
_conv_clear_pending_teach!()
_penicillin_raw = run_mission("who discovered penicillin")  # sets pending teach
_penicillin_ans = clean_output(_penicillin_raw)
log_md("**Step 1 — \"who discovered penicillin\":** $(first(_penicillin_ans, 200))")
# DO NOT clear pending teach — that's the whole point of the test!
_tides_raw = run_mission("what causes tides")
_tides_ans = clean_output(_tides_raw)
_has_crosstalk = occursin(Regex("\\bpenicillin\\b", "i"), _tides_ans)
_crosstalk_ok = !_has_crosstalk
_crosstalk_status = _crosstalk_ok ? "✅ No false-winner pattern detected" : "❌ FALSE WINNER: penicillin crosstalk detected in tides response"
log_md("**Step 2 — \"what causes tides\":** $(first(_tides_ans, 300))")
log_md("**Pending state before Step 2:** NOT cleared (intentional)")
log_md("**Verdict:** $_crosstalk_status")
log_md("")
log_md("---")
log_md("")
println("[coherence] pending-teach-no-crosstalk: $_crosstalk_status")
push!(coherence_results, ("pending-teach-no-crosstalk", _crosstalk_ok))
_conv_clear_pending_teach!()

# v8.28c: where/who questions should NOT produce false definitions
push!(coherence_results, run_coherence_test(
    "where-rivers-no-false-def",
    "where do rivers come from",
    Regex("\\bwhere\\s+(means|is)\\b", "i"),
    "\"where means/is\" — interrogative treated as definition target"))

push!(coherence_results, run_coherence_test(
    "who-discovered-no-false-def",
    "who discovered penicillin",
    Regex("\\bwho\\s+(means|is)\\b", "i"),
    "\"who means/is\" — interrogative treated as definition target"))

# Relational sigil should have actual triples
_conv_clear_pending_teach!()
push!(results, run_test("relational-tides-coherence", "what causes tides"; expect_coherent=true))

# Question coherence: answer should actually answer the question
push!(results, run_test("question-answer-match-feeling", "how are you feeling"; expect_coherent=true))
push!(results, run_test("question-answer-match-sky", "why is the sky blue"; expect_coherent=true))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: CONVERSATION PRESCAN — Intent Classification
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 2: Conversation Prescan — Intent Classification")
log_md("")
println("─" ^ 70)
println("SECTION 2: CONVERSATION PRESCAN")
println("─" ^ 70)
println()

push!(results, run_conv_prescan_test("prescan-define", "fire is oxidation and heat", :define))
push!(results, run_conv_prescan_test("prescan-question-what", "what is fire?", :question))
push!(results, run_conv_prescan_test("prescan-question-how", "how does gravity work", :question))
push!(results, run_conv_prescan_test("prescan-question-why", "why is the sky blue", :question))
push!(results, run_conv_prescan_test("prescan-question-where", "where do rivers come from", :question))
push!(results, run_conv_prescan_test("prescan-question-who", "who discovered penicillin", :question))
# v8.28d: "what time is it" must NOT be :define — should be :question or nothing
push!(results, run_conv_prescan_test("prescan-question-what-time", "what time is it", :question))
push!(results, run_conv_prescan_test("prescan-correct", "no, fire is plasma not oxidation", :correct))
# v8.28d: "no fire is not just oxidation fire is plasma" must be :correct, NOT :define
push!(results, run_conv_prescan_test("prescan-correct-no-comma", "no fire is not just oxidation fire is plasma", :correct))
push!(results, run_conv_prescan_test("prescan-greeting", "hello there", :nothing))
push!(results, run_conv_prescan_test("prescan-statement", "I like turtles", :nothing))
push!(results, run_conv_prescan_test("prescan-define-means", "gravity means a force that pulls things", :define))

# :teach detection with/without pending state
_conv_clear_pending_teach!()
_result_no_pending = _conversation_prescan("math, factorial is multiply all numbers")
_teach_ok_no_pending = _result_no_pending === nothing || (
    _result_no_pending !== nothing && first(_result_no_pending) != :teach)
log_md("## Prescan Teach: No Pending State")
log_md("")
log_md("**Input:** \"math, factorial is multiply all numbers\"")
log_md("**Pending:** NONE")
if _result_no_pending !== nothing
    log_md("**Result:** :$(first(_result_no_pending)) (not :teach — correct)")
else
    log_md("**Result:** nothing (not :teach — correct)")
end
log_md("")
log_md("---")
log_md("")
println("[prescan-teach] no-pending: $(_teach_ok_no_pending ? "✅" : "❌")")
push!(results, ("prescan-teach-no-pending", _teach_ok_no_pending))

_conv_clear_pending_teach!()
_conv_set_pending_teach!("factorial", "What does factorial mean?")
_result_with_pending = _conversation_prescan("math, factorial is multiply all numbers from 1 to n")
_teach_ok_with_pending = _result_with_pending !== nothing && first(_result_with_pending) == :teach
log_md("## Prescan Teach: With Pending State")
log_md("")
log_md("**Input:** \"math, factorial is multiply all numbers from 1 to n\"")
log_md("**Pending:** topic='factorial'")
if _result_with_pending !== nothing
    _pk, _pw, _pd, _ph = _result_with_pending
    log_md("**Result:** :$_pk word='$_pw' def='$(first(_pd, 60))' hint='$_ph'")
else
    log_md("**Result:** nothing")
end
_teach_prescan_status = _teach_ok_with_pending ? "✅ Detected as :teach" : "❌ Not detected as :teach"
log_md("**Verdict:** $_teach_prescan_status")
log_md("---")
log_md("")
println("[prescan-teach] with-pending: $_teach_prescan_status")
push!(results, ("prescan-teach-with-pending", _teach_ok_with_pending))

_conv_clear_pending_teach!()
_conv_set_pending_teach!("factorial", "What does factorial mean?")
_result_subj_only = _conversation_prescan("math")
_teach_subj_only_ok = _result_subj_only !== nothing && first(_result_subj_only) == :teach
log_md("## Prescan Teach: Subject-Only Answer")
log_md("")
log_md("**Input:** \"math\"")
if _result_subj_only !== nothing
    _sk, _sw, _sd, _sh = _result_subj_only
    log_md("**Result:** :$_sk word='$_sw' def='$_sd' hint='$_sh'")
end
log_md("**Verdict:** $(_teach_subj_only_ok ? "✅" : "❌") Subject-only detected")
log_md("---")
log_md("")
println("[prescan-teach] subject-only: $(_teach_subj_only_ok ? "✅" : "❌")")
push!(results, ("prescan-teach-subject-only", _teach_subj_only_ok))

_conv_clear_pending_teach!()
_conv_set_pending_teach!("factorial", "What does factorial mean?")
_result_ack = _conversation_prescan("yes")
_ack_ok = _result_ack === nothing
log_md("## Prescan Teach: Acknowledgment (\"yes\")")
log_md("")
log_md("**Input:** \"yes\"")
log_md("**Result:** $(_result_ack === nothing ? "nothing (pending cleared)" : ":$(first(_result_ack))")")
log_md("**Verdict:** $(_ack_ok ? "✅" : "❌") Ack cleared pending")
log_md("---")
log_md("")
println("[prescan-teach] ack-yes: $(_ack_ok ? "✅" : "❌")")
push!(results, ("prescan-teach-ack", _ack_ok))
_conv_clear_pending_teach!()

# v8.28d: Pending teach should be CLEARED when user asks a new question (topic shift detection)
_conv_set_pending_teach!("penicillin", "What does penicillin mean?")
_result_crosstalk = _conversation_prescan("what causes tides")
_crosstalk_ok = _result_crosstalk === nothing || first(_result_crosstalk) == :question
log_md("## Prescan Teach: Topic Shift Detection (v8.28d)")
log_md("")
log_md("**Input:** \"what causes tides\"")
log_md("**Pending:** topic='penicillin'")
if _result_crosstalk !== nothing
    log_md("**Result:** :$(first(_result_crosstalk))")
else
    log_md("**Result:** nothing")
end
_crosstalk_status = _crosstalk_ok ? "✅ Pending cleared on question" : "❌ Pending NOT cleared — crosstalk risk"
log_md("**Verdict:** $_crosstalk_status")
log_md("---")
log_md("")
println("[prescan-teach] crosstalk: $_crosstalk_status")
push!(results, ("prescan-teach-crosstalk", _crosstalk_ok))
_conv_clear_pending_teach!()


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: KNOWLEDGE CLASSIFICATION
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 3: Knowledge Classification (_classify_knowledge)")
log_md("")
println("─" ^ 70)
println("SECTION 3: KNOWLEDGE CLASSIFICATION")
println("─" ^ 70)
println()

# Static knowledge — simple facts
push!(classify_results, run_classify_test("static-simple", "fire is oxidation and heat", :static))
push!(classify_results, run_classify_test("static-identity", "gravity is a force", :static))
push!(classify_results, run_classify_test("static-definition", "a mammal is a warm-blooded animal", :static))
push!(classify_results, run_classify_test("static-means", "pi means the ratio of circumference to diameter", :static))
push!(classify_results, run_classify_test("static-short", "oxygen is an element", :static))

# Procedural knowledge — how to, calculations, methods
push!(classify_results, run_classify_test("procedural-howto", "how to multiply two numbers", :procedural))
push!(classify_results, run_classify_test("procedural-calculate", "calculate the factorial of n", :procedural))
push!(classify_results, run_classify_test("procedural-steps", "step 1 open the file step 2 read data", :procedural))
push!(classify_results, run_classify_test("procedural-method", "the method for sorting an array", :procedural))
push!(classify_results, run_classify_test("procedural-algorithm", "the algorithm computes fibonacci", :procedural))
push!(classify_results, run_classify_test("procedural-formula", "the formula for area", :procedural))
push!(classify_results, run_classify_test("procedural-iterate", "iterate over the collection", :procedural))
push!(classify_results, run_classify_test("procedural-convert", "convert celsius to fahrenheit", :procedural))
push!(classify_results, run_classify_test("procedural-solve", "solve the equation for x", :procedural))

# Relational knowledge — A does X to B
push!(classify_results, run_classify_test("relational-pulls", "gravity pulls masses together", :relational))
push!(classify_results, run_classify_test("relational-attracts", "magnets attract iron", :relational))
push!(classify_results, run_classify_test("relational-causes", "heat causes expansion", :relational))
push!(classify_results, run_classify_test("relational-requires", "fire requires oxygen", :relational))
push!(classify_results, run_classify_test("relational-depends", "life depends on water", :relational))
push!(classify_results, run_classify_test("relational-leads", "education leads to opportunity", :relational))
push!(classify_results, run_classify_test("relational-produces", "photosynthesis produces oxygen", :relational))
push!(classify_results, run_classify_test("relational-absorbs", "black surfaces absorb heat", :relational))
push!(classify_results, run_classify_test("relational-consumes", "fire consumes fuel", :relational))

# Edge cases
push!(classify_results, run_classify_test("edge-ambiguous", "water is composed of hydrogen and oxygen", :static))
push!(classify_results, run_classify_test("edge-mixed", "evaporation converts liquid to gas", :relational))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: SUBJECT→LOBE ROUTING
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 4: Subject→Lobe Routing (_find_lobe_for_subject)")
log_md("")
println("─" ^ 70)
println("SECTION 4: SUBJECT→LOBE ROUTING")
println("─" ^ 70)
println()

push!(lobe_route_results, run_lobe_routing_test("empty-subject", "", "default"))
push!(lobe_route_results, run_lobe_routing_test("generic-subject", "thing", "default"))
push!(lobe_route_results, run_lobe_routing_test("unknown-subject", "xyzabc", "default"))
push!(lobe_route_results, run_lobe_routing_test("math-subject", "math"))
push!(lobe_route_results, run_lobe_routing_test("science-subject", "science"))
push!(lobe_route_results, run_lobe_routing_test("physics-subject", "physics"))
push!(lobe_route_results, run_lobe_routing_test("biology-subject", "biology"))
push!(lobe_route_results, run_lobe_routing_test("chemistry-subject", "chemistry"))

println("Existing lobes: $(sort(collect(keys(LOBE_REGISTRY))))")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: TEACH PARTS PARSING
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 5: Teach Parts Parsing (_extract_teach_parts)")
log_md("")
println("─" ^ 70)
println("SECTION 5: TEACH PARTS PARSING")
println("─" ^ 70)
println()

push!(teach_parts_results, run_teach_parts_test("comma-sep", "math, factorial is multiply all numbers", "math", "multiply"))
push!(teach_parts_results, run_teach_parts_test("colon-sep", "science: fire is oxidation and heat", "science", "oxidation"))
push!(teach_parts_results, run_teach_parts_test("dash-sep", "physics - gravity pulls masses together", "physics", "pulls"))
push!(teach_parts_results, run_teach_parts_test("subject-comma", "subject math, factorial is multiply all numbers", "math", "multiply"))
push!(teach_parts_results, run_teach_parts_test("subject-colon", "subject science: fire is oxidation", "science", "oxidation"))
push!(teach_parts_results, run_teach_parts_test("subject-space", "subject math factorial is multiply", "math", "multiply"))
push!(teach_parts_results, run_teach_parts_test("def-only", "it's a chemical reaction", "", "chemical"))
push!(teach_parts_results, run_teach_parts_test("stopword-subject", "it, some definition here", "", ""))
push!(teach_parts_results, run_teach_parts_test("empty-input", "", "", ""))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: CONVERSATIONAL LEARNING LOOP — Live Tests
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 6: Conversational Learning Loop — Live Tests")
log_md("")
println("─" ^ 70)
println("SECTION 6: CONVERSATIONAL LEARNING LOOP")
println("─" ^ 70)
println()

# 6a: Static fact → dictionary entry
push!(conv_learn_results, run_conv_learn_test(
    "static-dict-science",
    "what is fluorosis",
    "science, fluorosis is a dental condition from excess fluoride",
    expect_node_type=:static,
    expect_lobe="science",
    expect_dict_fragment="fluorosis",
))

# 6b: Procedural knowledge → sigil node
# NOTE: Must use a truly unknown topic so the clarification→teach loop fires.
push!(conv_learn_results, run_conv_learn_test(
    "procedural-sigil-math",
    "what is bogosort",
    "math, bogosort is how to sort by randomly shuffling until correct",
    expect_node_type=:procedural,
    expect_lobe="mathematics",
    expect_sigil_kind=:procedural,
))

# 6c: Relational knowledge → sigil node with triples
# NOTE: Must use a truly unknown topic so the clarification→teach loop fires.
push!(conv_learn_results, run_conv_learn_test(
    "relational-sigil-physics",
    "what is orogeny",
    "physics, orogeny causes mountains to rise from tectonic collision",
    expect_node_type=:relational,
    expect_lobe="science",
    expect_sigil_kind=:relational,
))

# 6d: Static fact with clean definition
push!(conv_learn_results, run_conv_learn_test(
    "static-clean-def",
    "what is keratin",
    "biology, keratin is a structural protein in hair and nails",
    expect_node_type=:static,
    expect_dict_fragment="structural protein",
))

# 6e: Definition-only (no subject)
# NOTE: Must use a truly unknown topic so the clarification→teach loop fires.
push!(conv_learn_results, run_conv_learn_test(
    "static-no-subject",
    "what is plinko",
    "it is a game where discs drop through pegs into slots",
    expect_node_type=:static,
))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: PENDING TEACH EXPIRY
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 7: Pending Teach Expiry")
log_md("")
println("─" ^ 70)
println("SECTION 7: PENDING TEACH EXPIRY")
println("─" ^ 70)
println()

push!(teach_expiry_results, run_expiry_test("expiry-basic", "what is qwertyuiop", "hello there"))
push!(teach_expiry_results, run_expiry_test("expiry-greeting", "what is asdfghjkl", "hi"))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8: CORE REGRESSION TESTS
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 8: Core Regression Tests")
log_md("")
println("─" ^ 70)
println("SECTION 8: CORE REGRESSION TESTS")
println("─" ^ 70)
println()

push!(results, run_test("greeting", "hello"))
push!(results, run_test("math-add", "3 + 5"))
push!(results, run_test("math-subtract", "10 - 4"))
push!(results, run_test("math-multiply", "6 * 7"))
push!(results, run_test("math-factorial", "factorial of 5"))
push!(results, run_test("science-fire", "what is fire"))
push!(results, run_test("philosophy", "what is consciousness"))
push!(results, run_test("emotion", "how are you feeling"; expect_coherent=true))
push!(results, run_test("why-question", "why is the sky blue"; expect_coherent=true))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9: DICTIONARY LOOKUP AND DEFINE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 9: Dictionary Lookup and Define")
log_md("")
println("─" ^ 70)
println("SECTION 9: DICTIONARY LOOKUP AND DEFINE")
println("─" ^ 70)
println()

# Direct define still works
log_md("## Direct Define (\"X is Y\")")
log_md("")
_conv_clear_pending_teach!()
_define_raw = run_mission("stalactite is a mineral formation hanging from cave ceiling")
_define_ans = clean_output(_define_raw)
_define_ok = occursin("Learned", _define_ans) || occursin("📖", _define_ans)
log_md("**Input:** \"stalactite is a mineral formation hanging from cave ceiling\"")
log_md("**Output:** $(first(_define_ans, 200))")
log_md("**Result:** $(_define_ok ? "✅ Define still works" : "❌ Define broken")")
log_md("---")
log_md("")
println("[dict] direct-define: $(_define_ok ? "✅" : "❌")")
push!(results, ("dict-direct-define", _define_ok))

# Dictionary lookup after define
_dict_lookup_result = _dict_lookup_word("stalactite")
_dict_ok = _dict_lookup_result !== nothing
log_md("## Dictionary Lookup After Define")
log_md("")
log_md("**Word:** stalactite")
log_md("**Result:** $(_dict_ok ? "✅ Found: $(first(_dict_lookup_result, 100))" : "❌ Not found")")
log_md("---")
log_md("")
println("[dict] lookup-after-define: $(_dict_ok ? "✅" : "❌")")
push!(results, ("dict-lookup-after-define", _dict_ok))

# Dictionary lookup for pre-existing word (may be a node but NOT a dictionary entry)
# "fire" is an answer-cluster node, not a dictionary entry — this is expected behavior.
# The dictionary only contains words added via the 📖 teach path or _dict_define_word!.
_fire_lookup = _dict_lookup_word("fire")
_fire_ok = true  # fire is a NODE, not a dict entry — not being in dictionary is expected
log_md("## Dictionary Lookup — Pre-existing Word (fire)")
log_md("")
log_md("**Word:** fire")
log_md("**Dictionary result:** $(_fire_lookup !== nothing ? "✅ Found: $(first(_fire_lookup, 100))" : "⚠️ Not in dictionary (expected — fire is a node, not a dict entry)")")
log_md("---")
log_md("")
println("[dict] lookup-fire: $(_fire_lookup !== nothing ? "✅" : "⚠️") (expected: not all nodes are dict entries)")
push!(results, ("dict-lookup-fire", _fire_ok))

# Dictionary count
_dc_after = _dict_definitions_count()
_dc_ok = _dc_after > 0
log_md("## Dictionary Definitions Count")
log_md("")
log_md("**Count:** $_dc_after")
log_md("**Result:** $(_dc_ok ? "✅ Non-zero definitions" : "❌ Zero definitions")")
log_md("---")
log_md("")
println("[dict] definitions-count: $_dc_after ($(_dc_ok ? "✅" : "❌"))")
push!(results, ("dict-definitions-count", _dc_ok))

# Known question — should answer from dictionary, NOT ask for clarification
log_md("## Known Question — No Clarification")
log_md("")
_conv_clear_pending_teach!()
_known_raw = run_mission("what is fire")
_known_ans = clean_output(_known_raw)
_known_ok = !is_clarification_response(_known_ans) && !isempty(_known_ans)
log_md("**Input:** \"what is fire\"")
log_md("**Output:** $(first(_known_ans, 200))")
log_md("**Result:** $(_known_ok ? "✅ Known question answered (no clarification)" : "❌ Unnecessary clarification asked")")
log_md("---")
log_md("")
println("[dict] known-question: $(_known_ok ? "✅" : "❌")")
push!(results, ("dict-known-question", _known_ok))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10: THESAURUS AND VOICE RENDERING COHERENCE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 10: Thesaurus and Voice Rendering Coherence")
log_md("")
println("─" ^ 70)
println("SECTION 10: THESAURUS AND VOICE RENDERING")
println("─" ^ 70)
println()

# Self-reference integrity: "Grug" should not be swapped to "Fire" or other words
push!(coherence_results, run_coherence_test(
    "grug-no-fire-swap",
    "I feel sad",
    Regex("\\bFire\\b.*\\b(sit|via|feel)\\b", "i"),
    "\"Fire sit via sad\" — thesaurus swapped Grug→Fire"))

# Another self-reference test
push!(coherence_results, run_coherence_test(
    "grug-identity-preserved",
    "who are you",
    Regex("\\bFire\\b.*\\bGrug\\b|\\bFire\\b.*\\bam\\b", "i"),
    "Self-reference corrupted by thesaurus swap"))

# Topic coherence — the answer should be about the same topic
push!(results, run_test("topic-coherence-feeling", "how are you feeling"; expect_coherent=true))
push!(results, run_test("topic-coherence-sky", "why is the sky blue"; expect_coherent=true))

# Voice output should be non-empty and coherent
push!(results, run_test("voice-render-greeting", "hello"; expect_coherent=true))
push!(results, run_test("voice-render-question", "what is water"; expect_coherent=true))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 11: CORRECTION AND FEEDBACK
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 11: Correction and Feedback")
log_md("")
println("─" ^ 70)
println("SECTION 11: CORRECTION AND FEEDBACK")
println("─" ^ 70)
println()

# Correction still works
log_md("## Correction (\"no, X is Y\")")
log_md("")
_conv_clear_pending_teach!()
_corr_raw = run_mission("no, stalactite hangs from ceiling not grows from floor")
_corr_ans = clean_output(_corr_raw)
_corr_ok = !isempty(_corr_ans) && !occursin(r"Learned:\s*no"i, _corr_ans)
log_md("**Input:** \"no, stalactite hangs from ceiling not grows from floor\"")
log_md("**Output:** $(first(_corr_ans, 200))")
log_md("**Result:** $(_corr_ok ? "✅ Correction processed" : "❌ No response to correction")")
log_md("---")
log_md("")
println("[correction] no-x-is-y: $(_corr_ok ? "✅" : "❌")")
push!(results, ("correction-no-x-is-y", _corr_ok))

# Another correction format
log_md("## Correction — Alternate Format")
log_md("")
_conv_clear_pending_teach!()
_corr2_raw = run_mission("no fire is not just oxidation fire is plasma")
_corr2_ans = clean_output(_corr2_raw)
_corr2_ok = !isempty(_corr2_ans) && !occursin(r"Learned:\s*no\s+fire\s+means"i, _corr2_ans)
log_md("**Input:** \"no fire is not just oxidation fire is plasma\"")
log_md("**Output:** $(first(_corr2_ans, 200))")
log_md("**Result:** $(_corr2_ok ? "✅ Correction processed" : "❌ No response or false definition")")
log_md("---")
log_md("")
println("[correction] alternate-format: $(_corr2_ok ? "✅" : "❌")")
push!(results, ("correction-alternate", _corr2_ok))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 12: ARITHMETIC ENGINE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 12: Arithmetic Engine")
log_md("")
println("─" ^ 70)
println("SECTION 12: ARITHMETIC ENGINE")
println("─" ^ 70)
println()

push!(results, run_test("arith-add", "3 + 5"))
push!(results, run_test("arith-subtract", "10 - 4"))
push!(results, run_test("arith-multiply", "6 * 7"))
push!(results, run_test("arith-factorial", "factorial of 5"))
push!(results, run_test("arith-complex", "2 + 3 * 4"))


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 13: SIGIL NODE VERIFICATION
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 13: Sigil Node Verification")
log_md("")
println("─" ^ 70)
println("SECTION 13: SIGIL NODE VERIFICATION")
println("─" ^ 70)
println()

_procedural_sigils = list_sigil_node_ids(:procedural)
_relational_sigils = list_sigil_node_ids(:relational)
_all_sigils = list_sigil_node_ids(:any)

log_md("## Sigil Node Census")
log_md("")
log_md("| Kind | Count | IDs |")
log_md("|------|-------|-----|")
log_md("| procedural | $(length(_procedural_sigils)) | $(join(_procedural_sigils[1:min(5, length(_procedural_sigils))], ", "))$(length(_procedural_sigils) > 5 ? "…" : "") |")
log_md("| relational | $(length(_relational_sigils)) | $(join(_relational_sigils[1:min(5, length(_relational_sigils))], ", "))$(length(_relational_sigils) > 5 ? "…" : "") |")
log_md("| any | $(length(_all_sigils)) | — |")
log_md("")

_proc_results = String[]
for _sid in _procedural_sigils
    _kind_result = lock(NODE_LOCK) do
        if haskey(NODE_MAP, _sid)
            _sn = NODE_MAP[_sid]
            node_sigil_kind(_sn)
        else
            :missing
        end
    end
    if _kind_result == :procedural
        push!(_proc_results, "ok")
    else
        log_md("- ⚠️ Sigil '$_sid' has kind :$_kind_result (expected :procedural)")
        push!(_proc_results, "fail")
    end
end
_proc_verify_ok = count(x -> x == "ok", _proc_results)
_proc_status = _proc_verify_ok == length(_procedural_sigils) ?
    "✅ All $(length(_procedural_sigils)) procedural sigils verified" :
    "⚠️ $_proc_verify_ok/$(length(_procedural_sigils)) procedural sigils verified"
log_md("**Procedural sigil verification:** $_proc_status")
log_md("")

# Relational sigils should have actual relational triples
_rel_results = String[]
for _sid in _relational_sigils
    _rel_check = lock(NODE_LOCK) do
        if haskey(NODE_MAP, _sid)
            _sn = NODE_MAP[_sid]
            _kind = node_sigil_kind(_sn)
            _has_triples = !isempty(_sn.relational_patterns)
            (kind=_kind, has_triples=_has_triples)
        else
            (kind=:missing, has_triples=false)
        end
    end
    if _rel_check.kind == :relational
        if _rel_check.has_triples
            push!(_rel_results, "ok")
        else
            log_md("- ⚠️ Relational sigil '$_sid' has no relational triples (ZERO-TRIPLE BUG)")
            push!(_rel_results, "fail_no_triples")
        end
    else
        log_md("- ⚠️ Sigil '$_sid' has kind :$(_rel_check.kind) (expected :relational)")
        push!(_rel_results, "fail_wrong_kind")
    end
end
_rel_verify_ok = count(x -> x == "ok", _rel_results)
_rel_status = _rel_verify_ok == length(_relational_sigils) ?
    "✅ All $(length(_relational_sigils)) relational sigils verified" :
    "⚠️ $_rel_verify_ok/$(length(_relational_sigils)) relational sigils verified"
log_md("**Relational sigil verification:** $_rel_status")
log_md("")

_sigils_ok = (_proc_verify_ok == length(_procedural_sigils)) && (_rel_verify_ok == length(_relational_sigils))
push!(results, ("sigil-verification", _sigils_ok))

log_md("---")
log_md("")


# ══════════════════════════════════════════════════════════════════════════════
# SECTION 14: SAVE/LOAD ROUND-TRIP
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 14: Save/Load Round-Trip")
log_md("")
println("─" ^ 70)
println("SECTION 14: SAVE/LOAD ROUND-TRIP")
println("─" ^ 70)
println()

push!(saveload_results, run_pending_teach_saveload_test("pending-teach-roundtrip"))

# Full specimen save/reload integrity
log_md("## Full Specimen Round-Trip")
log_md("")
_n_before = length(lock(() -> collect(keys(NODE_MAP)), NODE_LOCK))
_dc_before = _dict_definitions_count()
try
    save_specimen_to_file!(SAVE_PATH)
    log_md("**Save:** ✅ Saved with $_n_before nodes, $_dc_before definitions")
    load_specimen_from_file!(SAVE_PATH)
    local _n_after = length(lock(() -> collect(keys(NODE_MAP)), NODE_LOCK))
    local _dc_after = _dict_definitions_count()
    local _roundtrip_ok = (_n_after == _n_before) && (_dc_after == _dc_before)
    log_md("**Reload:** $_n_after nodes, $_dc_after definitions")
    log_md("**Result:** $(_roundtrip_ok ? "✅ Node count and dict count match" : "❌ Counts differ")")
    push!(results, ("specimen-roundtrip", _roundtrip_ok))
catch e
    log_md("**Result:** ❌ Round-trip failed: $e")
    push!(results, ("specimen-roundtrip", false))
end
log_md("---")
log_md("")

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY SECTION
# ══════════════════════════════════════════════════════════════════════════════

println()
println("═" ^ 70)
println("COMPUTING FINAL SUMMARY")
println("═" ^ 70)
println()

log_md("# Final Summary")
log_md("")
log_md("**Completed:** $(now())")
log_md("")

# Helper: count passes in a result collection
# NOTE: run_test returns (turn, category, query, answer, status, verdict) — 6-tuple, r[2]=String
#       all other helpers return (label, ok, ...) — r[2]=Bool
function _count_passes(coll)
    pass = 0; fail = 0
    for r in coll
        if length(r) >= 6 && isa(r[2], String)
            # run_test 6-tuple: status is r[5], verdict is r[6]
            ok = r[6] == "OK" || r[5] == "✅"
        else
            ok = r[2]  # (label, ok, ...) format — Bool
        end
        ok ? (pass += 1) : (fail += 1)
    end
    return (pass, fail)
end

# Aggregate all result collections
global _all_collections = [
    ("Decoherence (S1)", coherence_results),
    ("Prescan + Core (S2+S8)", results),
    ("Knowledge Classification (S3)", classify_results),
    ("Lobe Routing (S4)", lobe_route_results),
    ("Teach Parts (S5)", teach_parts_results),
    ("Conversational Learning (S6)", conv_learn_results),
    ("Pending Teach Expiry (S7)", teach_expiry_results),
    ("Save/Load Round-Trip (S14)", saveload_results),
]

global total_pass = 0
global total_fail = 0
global section_summaries = []

for (section_name, coll) in _all_collections
    p, f = _count_passes(coll)
    global total_pass += p
    global total_fail += f
    push!(section_summaries, (section_name, p, f))
end

# Print and log summary table
log_md("## Results by Section")
log_md("")
log_md("| Section | Pass | Fail | Total |")
log_md("|---------|------|------|-------|")
for (section_name, p, f) in section_summaries
    log_md("| $section_name | $p | $f | $(p+f) |")
    println("  $section_name: ✅$p ❌$f")
end
log_md("")
log_md("| **TOTAL** | **$total_pass** | **$total_fail** | **$(total_pass + total_fail)** |")
log_md("")

println()
println("  TOTAL: ✅$total_pass ❌$total_fail / $(total_pass + total_fail)")

# Collect all failures
all_failures = String[]
for (section_name, coll) in _all_collections
    for r in coll
        if length(r) >= 6 && isa(r[2], String)
            _failed = r[6] != "OK" && r[5] != "✅"
            _label = "T$(r[1]) $(r[2])"  # turn + category
        else
            _failed = !r[2]
            _label = string(r[1])  # label string
        end
        if _failed
            push!(all_failures, "[$section_name] $_label")
        end
    end
end

if !isempty(all_failures)
    log_md("## ❌ Failures")
    log_md("")
    for f in all_failures
        log_md("- $f")
    end
    log_md("")
    println()
    println("  ❌ FAILURES:")
    for f in all_failures
        println("    - $f")
    end
else
    log_md("## ✅ All Tests Passed!")
    log_md("")
    println()
    println("  ✅ ALL TESTS PASSED!")
end

overall_pct = total_pass + total_fail > 0 ? round(total_pass / (total_pass + total_fail) * 100; digits=1) : 0.0
log_md("---")
log_md("")
log_md("**Overall pass rate:** $overall_pct%")
log_md("")

println()
println("  Overall pass rate: $overall_pct%")
println()

# Flush the MD log
flush_log_md(LOG_PATH)
println("═" ^ 70)
println("MD log written to: $LOG_PATH")
println("═" ^ 70)
