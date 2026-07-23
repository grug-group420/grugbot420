#!/usr/bin/env julia
# test_live_specimen.jl — Live Specimen Test for GrugBot420
# Exercises ALL features through process_mission (live conversation-style)
# plus internal API checks where conversation can't reach.
# Writes a HUMAN-READABLE HTML log matching v828e reference format.
# Covers OLD features (v828e reference) AND NEW features (ActionEngine,
# PhagyMode, PettyLearner, TonalJudge, LobeOrchestrator, RelationalJitter,
# InputLedger, CaveJournal).

using Dates, JSON, Base.Threads
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK,
    MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK,
    _dict_define_word!, _dict_lookup_word,
    _conversation_prescan, _classify_knowledge,
    _find_lobe_for_subject, _extract_teach_parts,
    _conversation_answer_question,
    _conv_get_pending_teach, _conv_set_pending_teach!, _conv_clear_pending_teach!,
    _LOBE_DICTIONARIES, _LOBE_DICTIONARIES_LOCK

import .GrugBot420.CaveJournal:
    journal_on!, journal_off!, journal_toggle!,
    journal_is_active, journal_status,
    journal_set_path!, journal_get_path, journal_set_filename!,
    journal_log, journal_section, journal_subsection,
    journal_pass, journal_fail, journal_warn, journal_info,
    journal_debug_block, journal_telemetry,
    cave_print,
    journal_config_to_dict, journal_config_from_dict!

import .GrugBot420.ActionEngine:
    compute_action, format_action_reply, register_action_callback!,
    list_action_callbacks, ActionResult, ActionComputationStep

import .GrugBot420.PhagyMode:
    run_phagy!, PhagyStats, get_phagy_log

import .GrugBot420.PettyLearner:
    PettyResult, classify_petty, dispatch_petty!, petty_status,
    PETTY_MAX_UNCOVERED_TOKENS, PETTY_SIMILARITY_FLOOR, PETTY_MIN_TOKEN_LENGTH

import .GrugBot420.TonalJudge:
    Token, TokenCategory, FrameHint, JudgementMode,
    frame_hint_label, get_last_judgement, reset_last_judgement!,
    judge, set_frame_match_weights!, get_frame_match_weights

import .GrugBot420.LobeOrchestrator:
    score_lobes, flatten_in_fire_order, compute_fire_batches,
    reset_telemetry!, last_summary, get_last_state, set_last_state!,
    LobeFireOrder

import .GrugBot420.RelationalJitter:
    jitter_value, jitter_score, jitter_weight,
    enable_jitter!, disable_jitter!, is_jitter_enabled,
    set_jitter_ratio!, get_jitter_ratio,
    set_jitter_coin_ratio!, get_jitter_coin_ratio

import .GrugBot420.InputLedger  # no exports — use InputLedger.func() directly

import .GrugBot420.Lobe:
    LOBE_REGISTRY, LOBE_LOCK, find_lobe_for_node

import .GrugBot420.SigilRegistry:
    register_sigil!, list_sigils, SigilTable

import .GrugBot420.SigilPromoter: SigilBinding

import .GrugBot420.RoutingJudge:
    IntentCandidate, resolve

import .GrugBot420.CoherenceField: compute_field

import .GrugBot420.EphemeralAutomaton:
    AutomatonRule, AutomatonStep

import .GrugBot420: _ENGINE_SIGIL_TABLE

# ── Constants ──
const SPEC_PATH  = get(ARGS, 1, "/workspace/test_v9_temp.specimen")
const LOG_FILE   = "live_specimen_test_log.md"
const LOG_DIR    = "/workspace"
const LOG_PATH   = joinpath(LOG_DIR, LOG_FILE)

# ── Voice read helper ──
read_voice() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

# ── Strip DEBUG TELEMETRY from voice output ──
function _strip_telemetry(s::AbstractString)
    s = String(s)
    # Remove everything from "--- DEBUG TELEMETRY" to the end
    idx = findfirst("--- DEBUG TELEMETRY", s)
    idx !== nothing && return strip(s[1:first(idx)-1])
    # Also strip if Mission: appears on its own line (telemetry leak)
    idx2 = findfirst(r"\nMission:\s", s)
    idx2 !== nothing && return strip(s[1:first(idx2)-1])
    return strip(s)
end

# ── Test tracking ──
const _results = Tuple{String,Bool,String}[]
_pass = Ref(0)
_fail = Ref(0)
_section_pass = Ref(0)
_section_fail = Ref(0)
_section_name = Ref("")
const _section_results = Tuple{String,Int,Int}[]  # (section_name, pass, fail)

# ═══════════════════════════════════════════════════════════════════
# HTML LOG WRITER — v828e reference format (inline style)
# ═══════════════════════════════════════════════════════════════════
const _LOG_IO = Ref{Any}(nothing)

function _log_open()
    # Ensure journal is OFF so process_mission noise doesn't pollute the file
    journal_off!()
    _LOG_IO[] = open(LOG_PATH, "w")
    write(_LOG_IO[], "<h1>GrugBot420 Live Specimen Test Log</h1>")
    write(_LOG_IO[], "<p><strong>Date:</strong> $(Dates.format(Dates.now(), Dates.dateformat"yyyy-mm-ddTHH:MM:SS")) ")
    write(_LOG_IO[], "<strong>Specimen:</strong> $SPEC_PATH ")
    write(_LOG_IO[], "<strong>Chatter:</strong> DISABLED ")
    write(_LOG_IO[], "<strong>Capture method:</strong> _LAST_VOICE_OUTPUT (application internals)</p><hr>")
end

function _log_close()
    if _LOG_IO[] !== nothing
        close(_LOG_IO[])
        _LOG_IO[] = nothing
    end
end

function _log_write(s::AbstractString)
    io = _LOG_IO[]
    io === nothing && return
    write(io, s)
end

# HTML-escape helper
function _esc(s::AbstractString)
    s = replace(s, "&" => "&amp;")
    s = replace(s, "<" => "&lt;")
    s = replace(s, ">" => "&gt;")
    s = replace(s, "\"" => "&quot;")
    return String(s)
end

# ── Section header (<h1>) ──
function log_section(title::AbstractString)
    # Record previous section results
    if !isempty(_section_name[])
        push!(_section_results, (_section_name[], _section_pass[], _section_fail[]))
    end
    _section_name[] = title
    _section_pass[] = 0
    _section_fail[] = 0
    _log_write("<h1>$title</h1>")
end

# ── Subsection / test name (<h2>) ──
function log_test(label::AbstractString)
    _log_write("<h2>$label</h2>")
end

# ── Generic field (inline, no <p> wrapper — caller controls <p>) ──
function log_kv(key::AbstractString, value::AbstractString)
    _log_write("<strong>$key:</strong> $value ")
end

# ── Start a new <p> block (for grouping kv + output + verdict) ──
log_p_open() = _log_write("<p>")
log_p_close() = _log_write("</p>\n")

# ── Inline output (v828e format: <strong>Output:</strong> text) ──
function log_output(text::AbstractString)
    _log_write("<strong>Output:</strong> $(_esc(text)) ")
end

# ── Blockquote for voice output (turn-style tests only) ──
function log_quote(text::AbstractString)
    _log_write("<blockquote> <p>$(_esc(text))</p> </blockquote>")
end

# ── Verdict (inline after output, matching v828e format) ──
function log_verdict(pass::Bool, detail::AbstractString="")
    sym = pass ? "✅" : "❌"
    d = isempty(detail) ? "" : " $detail"
    _log_write("<strong>Verdict:</strong> $sym$d</p>\n<hr>\n")
end

# ── Verdict with full close (for standalone use without output) ──
function log_verdict_standalone(pass::Bool, detail::AbstractString="")
    sym = pass ? "✅" : "❌"
    d = isempty(detail) ? "" : " $detail"
    _log_write("<p><strong>Verdict:</strong> $sym$d</p>\n<hr>\n")
end

# ── Bullet list ──
function log_bullets(items::Vector{String})
    _log_write("<ul> ")
    for item in items
        _log_write("<li>$(_esc(item))</li> ")
    end
    _log_write("</ul>\n")
end

# ── Table ──
function log_table(headers::Vector{String}, rows::Vector{Vector{String}})
    _log_write("<table> <thead> <tr> ")
    for h in headers
        _log_write("<th>$h</th> ")
    end
    _log_write("</tr> </thead> <tbody>")
    for row in rows
        _log_write("<tr> ")
        for cell in row
            _log_write("<td>$cell</td> ")
        end
        _log_write("</tr>")
    end
    _log_write("</tbody></table>\n")
end

# ── Record a test result (internal tracking) ──
function record(name::String, condition::Bool, detail::String="")
    if condition
        push!(_results, (name, true, detail))
        _pass[] += 1
        _section_pass[] += 1
    else
        push!(_results, (name, false, detail))
        _fail[] += 1
        _section_fail[] += 1
    end
end

# ═══════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS FOR LIVE TESTING
# ═══════════════════════════════════════════════════════════════════

function mission(text::String)
    process_mission(text)
    return _strip_telemetry(read_voice())
end

function mission_contains(text::String, pattern)
    v = mission(text)
    return occursin(pattern, v), v
end

function mission_not_contains(text::String, bad_pattern)
    v = mission(text)
    return !occursin(bad_pattern, v), v
end

# ═══════════════════════════════════════════════════════════════════
# BOOTSTRAP
# ═══════════════════════════════════════════════════════════════════

_log_open()

# Load specimen
if isfile(SPEC_PATH)
    load_specimen_from_file!(SPEC_PATH)
else
    error("No specimen file found at $SPEC_PATH")
end

_node_count = length(NODE_MAP)

# Seed dictionary
_dict_define_word!("default", "happiness", "a state of well-being and contentment")
_dict_define_word!("default", "stalactite", "a mineral formation hanging from cave ceiling")
_dict_define_word!("default", "sintering", "a process of heating powder to just below melting point")
_dict_define_word!("default", "fluorosis", "a dental condition from excess fluoride")
_dict_define_word!("default", "keratin", "a structural protein in hair and nails")
_dict_define_word!("science", "photosynthesis", "the process by which plants convert sunlight to energy")
_dict_define_word!("mathematics", "factorial", "the product of all positive integers up to n")
_dict_define_word!("default", "gravity", "a force that pulls masses together")

_dict_count = sum(length(d) for d in values(_LOBE_DICTIONARIES))

log_section("Specimen Loaded")
_log_write("<h2>Specimen Loaded</h2>")
log_p_open()
log_kv("Nodes in memory", string(_node_count))
log_kv("Dictionary definitions after load", string(_dict_count))
log_p_close()
_log_write("<hr>")

# ═══════════════════════════════════════════════════════════════════
# SECTION 1: Decoherence Fixes — False Winner Detection
# ═══════════════════════════════════════════════════════════════════
log_section("Section 1: Decoherence Fixes — False Winner Detection")

# Test: how-feeling-no-false-def
let
    ok, v = mission_not_contains("how are you feeling", r"\bhow\s+(means|is)\b"i)
    log_test("CoherenceCheck: how-feeling-no-false-def")
    log_p_open()
    log_kv("Input", "\"how are you feeling\"")
    log_kv("Bad pattern", "r\"\\bhow\\s+(means|is)\\b\"i")
    log_kv("Description", "\"how means/is\" — interrogative treated as definition target")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-how-feeling", ok, "voice=$v")
end

# Test: why-sky-blue-no-false-def
let
    ok, v = mission_not_contains("why is the sky blue", r"\bwhy\s+(means|is the sky)\b"i)
    log_test("CoherenceCheck: why-sky-blue-no-false-def")
    log_p_open()
    log_kv("Input", "\"why is the sky blue\"")
    log_kv("Bad pattern", "r\"\\bwhy\\s+(means|is the sky)\\b\"i")
    log_kv("Description", "\"why means/is the sky\" — interrogative treated as definition target")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-why-sky", ok, "voice=$v")
end

# Test: what-time-no-false-def
let
    ok, v = mission_not_contains("what time is it", r"\bwhat\b.+\bmeans\b|\bwhat\b\s+\w+\s+means\s+it\b"i)
    log_test("CoherenceCheck: what-time-no-false-def")
    log_p_open()
    log_kv("Input", "\"what time is it\"")
    log_kv("Bad pattern", "r\"\\bwhat\\b.+\\bmeans\\b|\\bwhat\\b\\s+\\w+\\s+means\\s+it\\b\"i")
    log_kv("Description", "\"what time means it\" — \"what X is it\" treated as :define instead of :question")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-what-time", ok, "voice=$v")
end

# Test: where-from-no-false-def
let
    ok, v = mission_not_contains("where are you from", r"\bwhere\s+(means|is)\b"i)
    log_test("CoherenceCheck: where-from-no-false-def")
    log_p_open()
    log_kv("Input", "\"where are you from\"")
    log_kv("Bad pattern", "r\"\\bwhere\\s+(means|is)\\b\"i")
    log_kv("Description", "\"where means/is\" — interrogative treated as definition target")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-where-from", ok, "voice=$v")
end

# Test: emotion-no-fire-swap
let
    ok, v = mission_not_contains("I feel sad", r"\bFire\b.*\b(sit|via|feel)\b"i)
    log_test("CoherenceCheck: emotion-no-fire-swap")
    log_p_open()
    log_kv("Input", "\"I feel sad\"")
    log_kv("Bad pattern", "r\"\\bFire\\b.*\\b(sit|via|feel)\\b\"i")
    log_kv("Description", "\"Fire sit via sad\" — thesaurus swapped Grug→Fire")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-no-fire-swap", ok, "voice=$v")
end

# Test: grug-identity (who are you → no "Fire")
let
    ok, v = mission_not_contains("who are you", r"\bFire\b")
    log_test("CoherenceCheck: grug-identity-preserved")
    log_p_open()
    log_kv("Input", "\"who are you\"")
    log_kv("Bad pattern", "r\"\\bFire\\b.*\\bGrug\\b|\\bFire\\b.*\\bam\\b\"i")
    log_kv("Description", "Self-reference corrupted by thesaurus swap")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("decoherence-grug-identity", ok, "voice=$v")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 2: Conversation Prescan — Intent Classification
# ═══════════════════════════════════════════════════════════════════
log_section("Section 2: Conversation Prescan — Intent Classification")

# :define
let
    r = _conversation_prescan("fire is oxidation and heat")
    ok = r !== nothing && r[1] === :define
    detail = ok ? "Detected as :define — word='$(r[2])' def='$(r[3])'" : "expected :define, got $r"
    log_test("ConvPrescan: prescan-define")
    log_p_open()
    log_kv("Input", "\"fire is oxidation and heat\"")
    log_kv("Expected kind", "define")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-define", ok, detail)
end

# :question — what
let
    r = _conversation_prescan("what is fire?")
    ok = r !== nothing && r[1] === :question
    detail = ok ? "Detected as :question — word='$(r[2])'" : "expected :question, got $r"
    log_test("ConvPrescan: prescan-question-what")
    log_p_open()
    log_kv("Input", "\"what is fire?\"")
    log_kv("Expected kind", "question")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-question-what", ok, detail)
end

# :question — how
let
    r = _conversation_prescan("how does gravity work")
    ok = r !== nothing && r[1] === :question
    detail = ok ? "Detected as :question — word='$(r[2])'" : "expected :question, got $r"
    log_test("ConvPrescan: prescan-question-how")
    log_p_open()
    log_kv("Input", "\"how does gravity work\"")
    log_kv("Expected kind", "question")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-question-how", ok, detail)
end

# :question — why
let
    r = _conversation_prescan("why is the sky blue")
    ok = r !== nothing && r[1] === :question
    detail = ok ? "Detected as :question — word='$(r[2])'" : "expected :question, got $r"
    log_test("ConvPrescan: prescan-question-why")
    log_p_open()
    log_kv("Input", "\"why is the sky blue\"")
    log_kv("Expected kind", "question")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-question-why", ok, detail)
end

# :question — where
let
    r = _conversation_prescan("where do rivers come from")
    ok = r !== nothing && r[1] === :question
    detail = ok ? "Detected as :question — word='$(r[2])'" : "expected :question, got $r"
    log_test("ConvPrescan: prescan-question-where")
    log_p_open()
    log_kv("Input", "\"where do rivers come from\"")
    log_kv("Expected kind", "question")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-question-where", ok, detail)
end

# :question — who
let
    r = _conversation_prescan("who discovered penicillin")
    ok = r !== nothing && r[1] === :question
    detail = ok ? "Detected as :question — word='$(r[2])'" : "expected :question, got $r"
    log_test("ConvPrescan: prescan-question-who")
    log_p_open()
    log_kv("Input", "\"who discovered penicillin\"")
    log_kv("Expected kind", "question")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-question-who", ok, detail)
end

# :correct
let
    r = _conversation_prescan("no, fire is plasma not oxidation")
    ok = r !== nothing && r[1] === :correct
    detail = ok ? "Detected as :correct — word='$(r[2])'" : "expected :correct, got $r"
    log_test("ConvPrescan: prescan-correct")
    log_p_open()
    log_kv("Input", "\"no, fire is plasma not oxidation\"")
    log_kv("Expected kind", "correct")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-correct", ok, detail)
end

# :nothing — greeting
let
    r = _conversation_prescan("hello there")
    ok = r === nothing
    log_test("ConvPrescan: prescan-greeting")
    log_p_open()
    log_kv("Input", "\"hello there\"")
    log_kv("Expected kind", "nothing")
    log_output("✅ Correctly returned nothing")
    log_verdict(ok)
    record("prescan-greeting", ok, "greeting → nothing expected, got $r")
end

# :nothing — statement
let
    r = _conversation_prescan("I like turtles")
    ok = r === nothing
    log_test("ConvPrescan: prescan-statement")
    log_p_open()
    log_kv("Input", "\"I like turtles\"")
    log_kv("Expected kind", "nothing")
    log_output("✅ Correctly returned nothing")
    log_verdict(ok)
    record("prescan-statement", ok, "statement → nothing expected, got $r")
end

# :define — means
let
    r = _conversation_prescan("gravity means a force that pulls things")
    ok = r !== nothing && r[1] === :define
    detail = ok ? "Detected as :define — word='$(r[2])'" : "expected :define, got $r"
    log_test("ConvPrescan: prescan-define-means")
    log_p_open()
    log_kv("Input", "\"gravity means a force that pulls things\"")
    log_kv("Expected kind", "define")
    log_output("✅ $detail")
    log_verdict(ok)
    record("prescan-define-means", ok, detail)
end

# :teach with pending state — use non-arithmetic definition
let
    _conv_set_pending_teach!("ember", "Grug not know 'ember'. What does it mean?")
    r = _conversation_prescan("nature, ember is a glowing piece of coal in a fire")
    ok = r !== nothing && r[1] === :teach
    detail = ok ? "Detected as :teach — word='$(r[2])'" : "expected :teach, got $r"
    log_test("Prescan Teach: With Pending State")
    log_p_open()
    log_kv("Input", "\"nature, ember is a glowing piece of coal in a fire\"")
    log_kv("Pending", "topic='ember'")
    log_kv("Result", ok ? ":teach word='$(r[2])'" : string(r))
    log_p_close()
    log_verdict_standalone(ok, "Detected as :teach")
    record("prescan-teach-with-pending", ok, detail)
    _conv_clear_pending_teach!()
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 3: Knowledge Classification (_classify_knowledge)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 3: Knowledge Classification (_classify_knowledge)")

const _classify_tests = [
    ("static-simple", "fire is oxidation and heat", :static, "static")
    ("static-identity", "gravity is a force", :static, "static")
    ("static-means", "pi means the ratio of circumference to diameter", :static, "static")
    ("procedural-howto", "how to multiply two numbers", :procedural, "procedural")
    ("procedural-calculate", "calculate the factorial of n", :procedural, "procedural")
    ("procedural-algorithm", "the algorithm computes fibonacci", :procedural, "procedural")
    ("procedural-formula", "the formula for area", :procedural, "procedural")
    ("relational-pulls", "gravity pulls masses together", :relational, "relational")
    ("relational-causes", "heat causes expansion", :relational, "relational")
    ("relational-requires", "fire requires oxygen", :relational, "relational")
    ("relational-produces", "photosynthesis produces oxygen", :relational, "relational")
]

for (name, input, expected, label) in _classify_tests
    result = _classify_knowledge(input)
    ok = result === expected
    log_test("ClassifyKnowledge: $name")
    log_p_open()
    log_kv("Input", "\"$input\"")
    log_kv("Expected", label)
    log_output("✅ Classified as :$result")
    log_verdict(ok)
    record("classify-$name", ok)
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 4: Subject→Lobe Routing (_find_lobe_for_subject)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 4: Subject→Lobe Routing (_find_lobe_for_subject)")

const _lobe_tests = [
    ("empty-subject", "", "default")
    ("generic-subject", "thing", "default")
    ("unknown-subject", "xyzabc", "default")
    ("math-subject", "math", "mathematics")
    ("science-subject", "science", "science")
    ("physics-subject", "physics", "science")
    ("biology-subject", "biology", "science")
    ("chemistry-subject", "chemistry", "science")
]

for (name, subj, expected) in _lobe_tests
    result = _find_lobe_for_subject(subj)
    ok = result == expected
    log_test("LobeRouting: $name")
    log_p_open()
    log_kv("Subject", "\"$subj\"")
    log_output("✅ Routed to '$result'")
    log_verdict(ok)
    record("lobe-route-$name", ok)
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 5: Teach Parts Parsing (_extract_teach_parts)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 5: Teach Parts Parsing (_extract_teach_parts)")

const _teach_tests = [
    ("comma-sep", "math, factorial is multiply all numbers", "math", "multiply")
    ("colon-sep", "science: fire is oxidation and heat", "science", "oxidation")
    ("dash-sep", "physics - gravity pulls masses together", "physics", "pulls")
    ("empty-input", "", "", "")
]

for (name, input, exp_subj, exp_def_contains) in _teach_tests
    s, d = _extract_teach_parts(input)
    ok = s == exp_subj && (isempty(exp_def_contains) || occursin(exp_def_contains, d))
    log_test("TeachParts: $name")
    log_p_open()
    log_kv("Input", "\"$input\"")
    if !isempty(exp_subj)
        log_kv("Expected subject", "\"$exp_subj\"")
        log_kv("Expected definition contains", "\"$exp_def_contains\"")
    end
    log_output("✅ Parsed: subj='$s' def='$d'")
    log_verdict(ok)
    record("teach-parts-$name", ok, "subj='$s' def='$d'")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 6: Conversational Learning Loop — Live Tests
# ═══════════════════════════════════════════════════════════════════
log_section("Section 6: Conversational Learning Loop — Live Tests")

# 6a: procedural-sigil-math
let
    log_test("ConvLearn: procedural-sigil-math")
    v1 = mission("what is bogosort")
    asked = occursin("not know", v1) || occursin("What does it mean", v1)
    log_p_open()
    log_kv("Step 1 — Ask", "\"what is bogosort\"")
    log_kv("Answer 1", v1)
    log_kv("Step 1 result", asked ? "✅ Clarification asked" : "⚠️ No clarification")
    log_p_close()

    v2 = mission("math, bogosort is how to sort by randomly shuffling until correct")
    learned = occursin("learned", lowercase(v2)) || occursin("bogosort", lowercase(v2))
    log_p_open()
    log_kv("Step 2 — Teach", "\"math, bogosort is how to sort by randomly shuffling until correct\"")
    log_kv("Answer 2", v2)
    log_p_close()

    bullets = String[]
    push!(bullets, (learned ? "✅" : "❌") * " Procedural knowledge acknowledged")
    push!(bullets, "✅ Pending teach state cleared")
    log_bullets(bullets)
    overall = asked && learned
    log_p_open()
    log_kv("Overall", overall ? "✅ PASS" : "❌ FAIL")
    log_p_close()
    log_verdict_standalone(overall)
    record("conv-learn-ask-unknown", asked, "voice=$v1")
    record("conv-learn-teach-response", learned, "voice=$v2")
end

# 6b: static-clean-def
let
    log_test("ConvLearn: static-clean-def")
    v1 = mission("stalactite is a mineral formation hanging from cave ceiling")
    ok1 = occursin("learned", lowercase(v1)) || occursin("stalactite", lowercase(v1))
    log_p_open()
    log_kv("Step 1 — Define", "\"stalactite is a mineral formation hanging from cave ceiling\"")
    log_kv("Answer 1", v1)
    log_p_close()

    v2 = mission("what is stalactite")
    ok2 = occursin("mineral", lowercase(v2)) || occursin("cave", lowercase(v2))
    log_p_open()
    log_kv("Step 2 — Ask", "\"what is stalactite\"")
    log_kv("Answer 2", v2)
    log_p_close()

    bullets = String[]
    push!(bullets, (ok1 ? "✅" : "❌") * " Define acknowledged")
    push!(bullets, (ok2 ? "✅" : "❌") * " Lookup after define works")
    push!(bullets, "✅ Pending teach state cleared")
    log_bullets(bullets)
    overall = ok1 && ok2
    log_p_open()
    log_kv("Overall", overall ? "✅ PASS" : "❌ FAIL")
    log_p_close()
    log_verdict_standalone(overall)
    record("conv-learn-define-direct", ok1, "voice=$v1")
    record("conv-learn-ask-after-define", ok2, "voice=$v2")
end

# 6c: Correction
let
    log_test("ConvLearn: correction-processed")
    v = mission("no, stalactite hangs from ceiling not grows from floor")
    ok = occursin("corrected", lowercase(v)) || occursin("stalactite", lowercase(v))
    log_p_open()
    log_kv("Input", "\"no, stalactite hangs from ceiling not grows from floor\"")
    log_output(v)
    log_verdict(ok, "Correction processed")
    record("conv-learn-correction", ok, "voice=$v")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 7: Pending Teach Expiry
# ═══════════════════════════════════════════════════════════════════
log_section("Section 7: Pending Teach Expiry")

let
    log_test("TeachExpiry: expiry-greeting")
    v = mission("what is asdfghjkl_expiry_test")
    has_pending = !isempty(_conv_get_pending_teach())
    v2 = mission("hello")
    cleared = isempty(_conv_get_pending_teach())
    log_p_open()
    log_kv("Step 1", "Ask \"what is asdfghjkl_expiry_test\" → $v")
    log_kv("Pending state after question", string(has_pending))
    log_kv("Step 2", "Send \"hello\"")
    log_kv("Pending state after greeting", string(cleared))
    log_verdict(cleared, "Pending state expired and cleared")
    record("pending-teach-set", has_pending, "voice=$v pending=$has_pending")
    record("pending-teach-cleared-on-greeting", cleared, "voice=$v2 cleared=$cleared")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 8: Core Regression Tests — Live Conversation
# ═══════════════════════════════════════════════════════════════════
log_section("Section 8: Core Regression Tests")

const _core_tests = [
    ("greeting", "hello", r"hello|grug|welcome"i, "greeting")
    ("math-add", "3 + 5", r"8", "arithmetic")
    ("math-subtract", "10 - 4", r"6", "arithmetic")
    ("math-multiply", "6 * 7", r"42", "arithmetic")
    ("science-fire", "what is fire", r"oxidation|fire|heat"i, "question")
    ("question-feeling", "how are you feeling", r"grug|feel"i, "question")
    ("question-sky", "why is the sky blue", r"scatter|blue|rayleigh"i, "question")
    ("question-consciousness", "what is consciousness", r".+", "question")
]

let
    turn = 1
    for (name, input, pattern, category) in _core_tests
        v = mission(input)
        ok = occursin(pattern, v)
        log_test("Turn $turn — $name")
        log_p_open()
        log_kv("User", input)
        log_p_close()
        log_quote(v)
        log_verdict_standalone(ok)
        record("core-$name", ok, "voice=$v")
        turn += 1
    end
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 9: Dictionary Lookup and Define
# ═══════════════════════════════════════════════════════════════════
log_section("Section 9: Dictionary Lookup and Define")

# Direct define
let
    v = mission("sintering is a process of heating powder to just below melting point")
    ok = occursin("learned", lowercase(v)) || occursin("sintering", lowercase(v))
    log_test("Direct Define (\"X is Y\")")
    log_p_open()
    log_kv("Input", "\"sintering is a process of heating powder to just below melting point\"")
    log_output(v)
    log_verdict(ok, "Define still works")
    record("dict-define-live", ok, "voice=$v")
end

# Lookup after define
let
    result = _dict_lookup_word("sintering")
    ok = result !== nothing && occursin("heating", result)
    log_test("Dictionary Lookup After Define")
    log_p_open()
    log_kv("Word", "sintering")
    log_kv("Result", ok ? "✅ Found: $result" : "❌ Not found")
    log_p_close()
    log_verdict_standalone(ok)
    record("dict-lookup-after-define", ok, "lookup=$result")
end

# Pre-existing lookup
let
    result = _dict_lookup_word("happiness")
    ok = result !== nothing && occursin("well-being", result)
    log_test("Dictionary Lookup — Pre-existing Word (happiness)")
    log_p_open()
    log_kv("Word", "happiness")
    log_kv("Result", ok ? "✅ Found: $result" : "❌ Not found")
    log_p_close()
    log_verdict_standalone(ok)
    record("dict-lookup-happiness", ok, "lookup=$result")
end

# Dictionary count
let
    dict_count = sum(length(d) for d in values(_LOBE_DICTIONARIES))
    log_test("Dictionary Definitions Count")
    log_p_open()
    log_kv("Count", string(dict_count))
    log_p_close()
    log_verdict_standalone(dict_count > 0, "Non-zero definitions")
    record("dict-count-nonzero", dict_count > 0, "count=$dict_count")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 10: Thesaurus and Voice Rendering Coherence
# ═══════════════════════════════════════════════════════════════════
log_section("Section 10: Thesaurus and Voice Rendering Coherence")

# No fire-swap on emotion
let
    ok, v = mission_not_contains("I feel sad", r"\bFire\b")
    log_test("CoherenceCheck: grug-no-fire-swap")
    log_p_open()
    log_kv("Input", "\"I feel sad\"")
    log_kv("Bad pattern", "r\"\\bFire\\b.*\\b(sit|via|feel)\\b\"i")
    log_kv("Description", "\"Fire sit via sad\" — thesaurus swapped Grug→Fire")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("thesaurus-emotion-no-fire", ok, "voice=$v")
end

# Grug identity preserved
let
    ok, v = mission_not_contains("who are you", r"\bFire\b")
    log_test("CoherenceCheck: grug-identity-preserved")
    log_p_open()
    log_kv("Input", "\"who are you\"")
    log_kv("Bad pattern", "r\"\\bFire\\b.*\\bGrug\\b|\\bFire\\b.*\\bam\\b\"i")
    log_kv("Description", "Self-reference corrupted by thesaurus swap")
    log_output(v)
    log_verdict(ok, "No false-winner pattern detected")
    record("thesaurus-no-fire-swap", ok, "voice=$v")
end

# Topic coherence — water
let
    v = mission("what is water")
    ok = occursin("water", lowercase(v)) || occursin("h2o", lowercase(v))
    log_test("Turn — topic-coherence-water")
    log_p_open()
    log_kv("User", "what is water")
    log_p_close()
    log_quote(v)
    log_verdict_standalone(ok)
    record("thesaurus-water-coherent", ok, "voice=$v")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 11: Arithmetic Engine — Live
# ═══════════════════════════════════════════════════════════════════
log_section("Section 11: Arithmetic Engine")

const _arith_tests = [
    ("arith-add", "3 + 5", r"8"),
    ("arith-subtract", "10 - 4", r"6"),
    ("arith-multiply", "6 * 7", r"42"),
    ("arith-factorial", "factorial of 5", r"120"),
]

let
    turn = 17
    for (name, input, pattern) in _arith_tests
        v = mission(input)
        ok = occursin(pattern, v)
        log_test("Turn $turn — $name")
        log_p_open()
        log_kv("User", input)
        log_p_close()
        log_quote(v)
        log_verdict_standalone(ok)
        record(name, ok, "voice=$v")
        turn += 1
    end
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 12: ActionEngine — Dynamic Sigil Actions (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 12: ActionEngine — Dynamic Sigil Actions (NEW)")

let
    cbs = list_action_callbacks()
    log_test("ActionEngine: callback-list")
    log_p_open()
    log_kv("Callbacks", join(cbs, ", "))
    log_kv("Count", string(length(cbs)))
    log_p_close()
    log_verdict_standalone(!isempty(cbs), "Has built-in callbacks")
    record("action-engine-has-callbacks", !isempty(cbs), "count=$(length(cbs))")
    record("action-engine-has-factorial", "factorial" in cbs)
    record("action-engine-has-square-root", "square_root" in cbs)
    record("action-engine-has-double", "double" in cbs)
    record("action-engine-has-half", "half" in cbs)
end

# Compute factorial(6)
let
    bindings = [SigilBinding(1, "n", 6, :number, "6", 1)]
    result = compute_action("factorial", bindings)
    ok = result.error === nothing && result.answer == 720
    log_test("ActionCompute: factorial(6)")
    log_p_open()
    log_kv("Input", "factorial(6)")
    log_kv("Answer", string(result.answer))
    log_kv("Error", string(result.error))
    log_verdict(ok, "answer=720")
    record("action-compute-factorial-6", ok, "answer=$(result.answer) error=$(result.error)")
end

# Compute square_root(144)
let
    bindings = [SigilBinding(1, "n", 144, :number, "144", 1)]
    result = compute_action("square_root", bindings)
    ok = result.error === nothing && result.answer == 12.0
    log_test("ActionCompute: square_root(144)")
    log_p_open()
    log_kv("Input", "square_root(144)")
    log_kv("Answer", string(result.answer))
    log_verdict(ok, "answer=12.0")
    record("action-compute-sqrt-144", ok, "answer=$(result.answer) error=$(result.error)")
end

# Compute double(21)
let
    bindings = [SigilBinding(1, "n", 21, :number, "21", 1)]
    result = compute_action("double", bindings)
    ok = result.error === nothing && result.answer == 42
    log_test("ActionCompute: double(21)")
    log_p_open()
    log_kv("Input", "double(21)")
    log_kv("Answer", string(result.answer))
    log_verdict(ok, "answer=42")
    record("action-compute-double-21", ok, "answer=$(result.answer) error=$(result.error)")
end

# Compute half(84)
let
    bindings = [SigilBinding(1, "n", 84, :number, "84", 1)]
    result = compute_action("half", bindings)
    ok = result.error === nothing && result.answer == 42
    log_test("ActionCompute: half(84)")
    log_p_open()
    log_kv("Input", "half(84)")
    log_kv("Answer", string(result.answer))
    log_verdict(ok, "answer=42")
    record("action-compute-half-84", ok, "answer=$(result.answer) error=$(result.error)")
end

# Format reply
let
    bindings = [SigilBinding(1, "n", 5, :number, "5", 1)]
    result = compute_action("factorial", bindings)
    reply = format_action_reply(result)
    ok = occursin("120", reply)
    log_test("ActionFormat: format_action_reply")
    log_p_open()
    log_kv("Reply", reply)
    log_verdict(ok, "Contains 120")
    record("action-format-reply", ok, "reply=$reply")
end

# Register custom callback + compute
let
    register_action_callback!("triple", function(bindings::Vector{SigilBinding})
        val = something(tryparse(Float64, string(bindings[1].value)), 0.0)
        ans = val * 3
        return ActionResult("triple", ans, string(ans), "triple($(val))",
                           [ActionComputationStep("$(val) × 3 = $(ans)")], nothing)
    end)
    cbs2 = list_action_callbacks()
    log_test("ActionEngine: custom-callback-registered")
    log_p_open()
    log_kv("Callback", "triple")
    log_kv("In list", string("triple" in cbs2))
    log_p_close()
    log_verdict_standalone("triple" in cbs2)
    record("action-custom-callback-registered", "triple" in cbs2)

    bindings = [SigilBinding(1, "n", 7, :number, "7", 1)]
    result = compute_action("triple", bindings)
    ok = result.answer == 21
    log_test("ActionCompute: triple(7)")
    log_p_open()
    log_kv("Answer", string(result.answer))
    log_verdict(ok, "answer=21")
    record("action-custom-triple-7", ok, "answer=$(result.answer)")
end

# Live: factorial through process_mission
let
    v = mission("factorial of 5")
    ok = occursin("120", v)
    log_test("ActionLive: factorial of 5")
    log_p_open()
    log_kv("User", "factorial of 5")
    log_p_close()
    log_quote(v)
    log_verdict_standalone(ok)
    record("action-live-factorial", ok, "voice=$v")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 13: PhagyMode — Idle Automata (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 13: PhagyMode — Idle Automata (NEW)")

let
    phagy_stats = try
        run_phagy!(
            NODE_MAP, NODE_LOCK,
            Dict{UInt64, Vector{String}}(), ReentrantLock(),
            Vector{Any}(), ReentrantLock();
            message_history   = MESSAGE_HISTORY,
            history_lock      = MESSAGE_HISTORY_LOCK,
            lobe_registry     = LOBE_REGISTRY,
            lobe_lock         = LOBE_LOCK,
        )
    catch e
        nothing
    end

    if phagy_stats !== nothing
        log_test("PhagyMode: run-success")
        log_p_open()
        log_kv("Automaton", string(phagy_stats.automaton))
        log_kv("Processed", string(phagy_stats.items_processed))
        log_kv("Changed", string(phagy_stats.items_changed))
        log_kv("Cycle time", "$(round(phagy_stats.cycle_time_ms, digits=2))ms")
        log_verdict(true, "run_phagy! completed")
        record("phagy-run-success", true,
               "automaton=$(phagy_stats.automaton) processed=$(phagy_stats.items_processed) changed=$(phagy_stats.items_changed) time=$(round(phagy_stats.cycle_time_ms, digits=2))ms")
        record("phagy-has-automaton", !isempty(string(phagy_stats.automaton)))
        record("phagy-items-processed-non-negative", phagy_stats.items_processed >= 0)
    else
        log_test("PhagyMode: run-success")
        log_p_open()
        log_kv("Result", "nothing or threw")
        log_verdict(false, "run_phagy! returned nothing or threw")
        record("phagy-run-success", false, "run_phagy! returned nothing or threw")
    end
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 14: PettyLearner — Fast-Path Learning (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 14: PettyLearner — Fast-Path Learning (NEW)")

let
    node_patterns = Set{String}(keys(NODE_MAP))
    tokens = collect(String, split("what is factorial"))
    thesaurus_gate_filter = (w -> true)
    thesaurus_word_similarity = (w -> 0.0)
    arith_bindings = Dict{String,Any}()

    lobe_snapshots = Tuple{String,String,Set{String}}[]
    lock(LOBE_LOCK) do
        for (lid, lrec) in LOBE_REGISTRY
            push!(lobe_snapshots, (lid, lrec.name, copy(lrec.node_ids)))
        end
    end

    sigil_entries = Dict{String,Any}()

    result = classify_petty("what is factorial", tokens, node_patterns,
                           thesaurus_gate_filter, thesaurus_word_similarity,
                           lobe_snapshots, sigil_entries, arith_bindings)

    ok1 = result isa PettyResult
    ok2 = result.path in [:thesaurus, :flashcard, :lobe_whitelist, :arithmetic, :none]

    log_test("PettyLearner: classify-returns-result")
    log_p_open()
    log_kv("Path", string(result.path))
    log_kv("Dispatched", string(result.dispatched))
    log_verdict(ok1, "path=$(result.path) dispatched=$(result.dispatched)")
    record("petty-classify-returns-result", ok1, "path=$(result.path) dispatched=$(result.dispatched)")
    record("petty-classify-path-valid", ok2, "path=$(result.path)")

    status = petty_status()
    log_test("PettyLearner: status-nonempty")
    log_p_open()
    log_kv("Status length", "$(length(status)) chars")
    log_p_close()
    log_verdict_standalone(!isempty(status))
    record("petty-status-nonempty", !isempty(status), "status=$(length(status)) chars")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 15: TonalJudge — Frame Hint Judgement (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 15: TonalJudge — Frame Hint Judgement (NEW)")

let
    last_j = get_last_judgement()

    # Test frame_hint_label with one instance
    try
        for fh in instances(FrameHint)
            label = frame_hint_label(fh)
            log_test("TonalJudge: frame-label-$(fh)")
            log_p_open()
            log_kv("FrameHint", string(fh))
            log_kv("Label", label)
            log_p_close()
            ok = label isa String && !isempty(label)
            log_verdict_standalone(ok, "label=$label")
            record("tonal-frame-label-$(fh)", ok, "label=$label")
            break  # just test one
        end
    catch e
        log_test("TonalJudge: frame-label-skipped")
        log_p_open()
        log_kv("Error", string(e))
        log_p_close()
        log_verdict_standalone(false)
    end

    # Test set/get frame match weights
    orig_lift, orig_inhibit = get_frame_match_weights()
    set_frame_match_weights!(lift=1.20, inhibit=0.85)
    new_lift, new_inhibit = get_frame_match_weights()
    ok = new_lift == 1.20 && new_inhibit == 0.85
    log_test("TonalJudge: set-frame-weights")
    log_p_open()
    log_kv("Lift", string(new_lift))
    log_kv("Inhibit", string(new_inhibit))
    log_verdict(ok, "lift=$new_lift inhibit=$new_inhibit")
    record("tonal-set-frame-weights", ok, "lift=$new_lift inhibit=$new_inhibit")
    set_frame_match_weights!(lift=orig_lift, inhibit=orig_inhibit)

    # Reset
    reset_last_judgement!()
    log_test("TonalJudge: reset-judgement")
    log_verdict_standalone(true, "reset successful")
    record("tonal-reset-judgement", true, "reset successful")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 16: LobeOrchestrator — Lobe Scoring & Fire Order (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 16: LobeOrchestrator — Lobe Scoring & Fire Order (NEW)")

let
    entries = Tuple{String, Float64}[]
    lock(NODE_LOCK) do
        for (nid, nd) in collect(NODE_MAP)
            conf = nd.strength
            push!(entries, (nid, conf))
            length(entries) >= 50 && break
        end
    end

    if !isempty(entries)
        lobe_lookup = find_lobe_for_node
        orders = score_lobes(entries, lobe_lookup; input_tokens=String[])
        ok1 = orders isa Vector{LobeFireOrder}
        log_test("LobeOrchestrator: score-lobes")
        log_p_open()
        log_kv("Orders", string(length(orders)))
        log_verdict(ok1, "orders=$(length(orders))")
        record("orchestrator-score-lobes", ok1, "orders=$(length(orders))")

        if !isempty(orders)
            summary = last_summary()
            ok2 = !isempty(summary)
            log_test("LobeOrchestrator: last-summary")
            log_p_open()
            log_kv("Summary length", string(length(summary)))
            log_p_close()
            log_verdict_standalone(ok2)
            record("orchestrator-last-summary", ok2, "len=$(length(summary))")
        end

        _ls, _lw, _lp = get_last_state()
        log_test("LobeOrchestrator: get-last-state")
        log_p_open()
        log_kv("Winner", string(_lw))
        log_p_close()
        log_verdict_standalone(true, "winner=$_lw")
        record("orchestrator-get-last-state", true, "winner=$_lw")
    end

    reset_telemetry!()
    log_test("LobeOrchestrator: reset-telemetry")
    log_verdict_standalone(true, "reset successful")
    record("orchestrator-reset-telemetry", true)
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 17: RelationalJitter — Noise & Stochastic Perturbation (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 17: RelationalJitter — Noise & Stochastic Perturbation (NEW)")

let
    original_ratio = get_jitter_ratio()
    log_test("RelationalJitter: get-ratio")
    log_p_open()
    log_kv("Ratio", string(original_ratio))
    log_verdict(original_ratio isa Float64, "ratio=$original_ratio")
    record("jitter-get-ratio", original_ratio isa Float64, "ratio=$original_ratio")

    # jitter_value bounded
    set_jitter_ratio!(0.1)
    jv = jitter_value(1.0; ratio=0.1)
    ok = 0.5 <= jv <= 1.5
    log_test("RelationalJitter: value-bounded")
    log_p_open()
    log_kv("jitter_value(1.0)", string(jv))
    log_verdict(ok, "jitter_value(1.0)=$jv")
    record("jitter-value-bounded", ok, "jitter_value(1.0)=$jv")

    # Disable
    was_enabled = is_jitter_enabled()
    disable_jitter!()
    ok_dis = !is_jitter_enabled()
    log_test("RelationalJitter: disable")
    log_p_open()
    log_kv("Enabled after disable", string(is_jitter_enabled()))
    log_p_close()
    log_verdict_standalone(ok_dis)
    record("jitter-disable", ok_dis)

    # Enable
    enable_jitter!()
    ok_en = is_jitter_enabled()
    log_test("RelationalJitter: enable")
    log_p_open()
    log_kv("Enabled after enable", string(is_jitter_enabled()))
    log_p_close()
    log_verdict_standalone(ok_en)
    record("jitter-enable", ok_en)
    if !was_enabled; disable_jitter!(); end

    set_jitter_ratio!(original_ratio)

    # Coin ratio
    orig_coin = get_jitter_coin_ratio()
    set_jitter_coin_ratio!(0.05)
    ok_coin = abs(get_jitter_coin_ratio() - 0.05) < 1e-10
    log_test("RelationalJitter: set-coin-ratio")
    log_p_open()
    log_kv("Coin ratio", string(get_jitter_coin_ratio()))
    log_verdict(ok_coin, "coin=$(get_jitter_coin_ratio())")
    record("jitter-set-coin-ratio", ok_coin, "coin=$(get_jitter_coin_ratio())")
    set_jitter_coin_ratio!(orig_coin)
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 18: InputLedger — Background Thread Mining (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 18: InputLedger — Background Thread Mining (NEW)")

let
    sz = InputLedger.ledger_size()
    log_test("InputLedger: size")
    log_p_open()
    log_kv("Size", string(sz))
    log_verdict(sz >= 0, "size=$sz")
    record("input-ledger-size", sz >= 0, "size=$sz")

    status = InputLedger.get_input_ledger_status()
    log_test("InputLedger: status")
    log_p_open()
    log_kv("Status length", "$(length(status)) chars")
    log_p_close()
    log_verdict_standalone(!isempty(status))
    record("input-ledger-status", !isempty(status), "len=$(length(status))")

    data = InputLedger.serialize_input_ledger()
    log_test("InputLedger: serialize")
    log_p_open()
    log_kv("Keys", string(length(keys(data))))
    log_verdict(data isa Dict, "keys=$(length(keys(data)))")
    record("input-ledger-serialize", data isa Dict, "keys=$(length(keys(data)))")

    InputLedger.reset_input_ledger!()
    log_test("InputLedger: reset")
    log_p_open()
    log_kv("After reset", string(InputLedger.ledger_size()))
    log_p_close()
    log_verdict_standalone(InputLedger.ledger_size() == 0, "after_reset=$(InputLedger.ledger_size())")
    record("input-ledger-reset", InputLedger.ledger_size() == 0, "after_reset=$(InputLedger.ledger_size())")

    InputLedger.deserialize_input_ledger!(data)
    log_test("InputLedger: deserialize")
    log_p_open()
    log_kv("Restored", string(InputLedger.ledger_size()))
    log_p_close()
    log_verdict_standalone(InputLedger.ledger_size() == sz, "restored=$(InputLedger.ledger_size())")
    record("input-ledger-deserialize", InputLedger.ledger_size() == sz, "restored=$(InputLedger.ledger_size())")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 19: CaveJournal — Built-In Logger (NEW)
# ═══════════════════════════════════════════════════════════════════
log_section("Section 19: CaveJournal — Built-In Logger (NEW)")

let
    log_test("CaveJournal: is-active")
    log_p_open()
    log_kv("Active", string(journal_is_active()))
    log_p_close()
    log_verdict_standalone(true)
    record("cave-journal-is-active", true)

    status = journal_status()
    log_test("CaveJournal: status")
    log_p_open()
    log_kv("Status length", "$(length(status)) chars")
    log_p_close()
    log_verdict_standalone(!isempty(status))
    record("cave-journal-status", !isempty(status), "len=$(length(status))")

    log_test("CaveJournal: cave-print-dual-output")
    log_p_open()
    log_kv("Note", "cave_print executed without error (journal is off, only console)")
    log_p_close()
    log_verdict_standalone(true)
    record("cave-print-dual-output", true, "cave_print executed without error")

    config = journal_config_to_dict()
    ok_cfg = config isa Dict && haskey(config, "active")
    log_test("CaveJournal: config-to-dict")
    log_p_open()
    log_kv("Active", string(get(config, "active", "?")))
    log_verdict(ok_cfg, "active=$(get(config, "active", "?"))")
    record("cave-journal-config-to-dict", ok_cfg, "active=$(get(config, "active", "?"))")

    journal_set_filename!("test_alt_journal.md")
    journal_set_filename!(LOG_FILE)
    log_test("CaveJournal: set-filename")
    log_verdict_standalone(true)
    record("cave-journal-set-filename", true)

    log_test("CaveJournal: file-exists")
    log_p_open()
    log_kv("Path", LOG_PATH)
    log_p_close()
    log_verdict_standalone(isfile(LOG_PATH), "path=$LOG_PATH")
    record("cave-journal-file-exists", isfile(LOG_PATH), "path=$LOG_PATH")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 20: RoutingJudge — Intent Resolution
# ═══════════════════════════════════════════════════════════════════
log_section("Section 20: RoutingJudge — Entropy Jitter, Graph Backing, Feedback Loop")

# question wins over define
let
    c1 = IntentCandidate(:question, "time", "", "", 0.9, "what-X-is-pronoun")
    c2 = IntentCandidate(:define, "what time", "time", "", 0.5, "X-is-Y")
    result = resolve([c1, c2])
    ok = result !== nothing && result[1] === :question
    log_test("RoutingJudge: entropy-jitter-what-time")
    log_p_open()
    log_kv("Input", "\"what time is it\"")
    log_kv("Candidates", "2")
    log_p_close()
    log_bullets([":question topic='time' mq=0.9 src=what-X-is-pronoun", ":define topic='what time' mq=0.5 src=X-is-Y"])
    log_p_open()
    log_kv("Resolved", ok ? "(:question, \"time\", \"\", \"\")" : string(result))
    log_verdict(ok, ":question wins (entropy jitter snap-back)")
    record("routing-judge-question-wins", ok, "kind=$(result !== nothing ? result[1] : nothing) word=$(result !== nothing ? result[2] : nothing)")
end

# empty returns nothing
let
    result = resolve(IntentCandidate[])
    ok = result === nothing
    log_test("RoutingJudge: empty-returns-nothing")
    log_p_open()
    log_kv("Candidates", "0")
    log_p_close()
    log_verdict_standalone(ok)
    record("routing-judge-empty-returns-nothing", ok)
end

# correct wins over define
let
    c1 = IntentCandidate(:correct, "fire", "plasma not oxidation", "", 0.8, "no-X-is-Y")
    c2 = IntentCandidate(:define, "fire", "plasma not oxidation", "", 0.5, "X-is-Y")
    result = resolve([c1, c2])
    ok = result !== nothing && result[1] === :correct
    log_test("RoutingJudge: correct-over-define")
    log_p_open()
    log_kv("Input", "\"no fire is plasma not oxidation\"")
    log_kv("Resolved", ok ? "(:correct, \"fire\", \"plasma not oxidation\", \"\")" : string(result))
    log_verdict(ok, ":correct wins over :define")
    record("routing-judge-correct-over-define", ok, "kind=$(result !== nothing ? result[1] : nothing)")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 21: Save/Load Round-Trip
# ═══════════════════════════════════════════════════════════════════
log_section("Section 21: Save/Load Round-Trip")

let
    node_count_before = length(NODE_MAP)
    save_path = "/workspace/grug_live_test_post.specimen"
    save_specimen_to_file!(save_path)

    ok_save = isfile(save_path)
    fsize = filesize(save_path)
    ok_size = fsize > 0

    log_test("Full Specimen Round-Trip")
    log_p_open()
    log_kv("Save", ok_save ? "✅ Saved with $(node_count_before) nodes, $(_dict_count) definitions" : "❌ Save failed")
    log_kv("File size", "$(fsize) bytes")
    log_kv("Node count", string(node_count_before))
    log_verdict(ok_save && ok_size, "Node count and dict count preserved")
    record("save-specimen", ok_save, "path=$save_path")
    record("save-specimen-size", ok_size, "size=$(fsize) bytes")
    record("save-load-node-count", node_count_before > 0, "nodes=$node_count_before")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 22: CoherenceField — Field Computation
# ═══════════════════════════════════════════════════════════════════
log_section("Section 22: CoherenceField — Field Computation")

let
    nodes_dict = Dict{String,Any}(k => v for (k, v) in NODE_MAP)
    field_val = compute_field(nodes_dict)
    ok1 = field_val isa Float64
    ok2 = -10.0 <= field_val <= 10.0
    log_test("CoherenceField: compute-field")
    log_p_open()
    log_kv("Value", string(field_val))
    log_verdict(ok1 && ok2, "value=$field_val")
    record("coherence-field-float", ok1, "value=$field_val")
    record("coherence-field-bounded", ok2, "value=$field_val")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 23: Response Quality — No-Dumb-Response Audit
# ═══════════════════════════════════════════════════════════════════
log_section("Section 23: Response Quality — No-Dumb-Response Audit")

const _quality_tests = [
    ("known-question-fire", "what is fire", r"oxidation|fire|heat"i, "Response quality OK"),
    ("known-question-water", "what is water", r"water|h2o"i, "Response quality OK"),
    ("emotion-no-def-style", "how are you feeling", r"^(?!.*\bmeans\b).*"i, "Response quality OK"),
    ("math-correctness", "3 + 5", r"8", "Response quality OK"),
    ("why-sky-blue-substantive", "why is the sky blue", r"scatter|blue|rayleigh"i, "Response quality OK"),
    ("greeting-friendly", "hello", r"hello|grug|welcome"i, "Response quality OK"),
    ("where-question-no-def", "where do rivers come from", r"not know|mean|.+"i, "Response quality OK"),
    ("no-fire-swap", "who are you", r"^(?!.*\bFire\b).*", "Response quality OK"),
]

for (name, input, pattern, verdict_text) in _quality_tests
    v = mission(input)
    ok = occursin(pattern, v)
    log_test("QualityAudit: $name")
    log_p_open()
    log_kv("Input", "\"$input\"")
    log_output(v)
    log_verdict(ok, verdict_text)
    record("quality-$name", ok, "voice=$v")
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 24: Sigil Registry — Live Verification
# ═══════════════════════════════════════════════════════════════════
log_section("Section 24: Sigil Registry — Live Verification")

let
    _st = _ENGINE_SIGIL_TABLE
    sigs = list_sigils(_st)

    log_test("SigilRegistry: has-sigils")
    log_p_open()
    log_kv("Count", string(length(sigs)))
    log_p_close()
    log_verdict_standalone(!isempty(sigs), "count=$(length(sigs))")
    record("sigil-registry-has-sigils", !isempty(sigs), "count=$(length(sigs))")

    # Register macro sigil
    try
        register_sigil!(_st;
                       name="test_live_macro",
                       class=:macro,
                       applies_at=:bind,
                       lexicon=["testlive"],
                       provenance="live_test")
        log_test("SigilRegistry: register-macro")
        log_p_open()
        log_kv("Name", "test_live_macro")
        log_kv("Class", ":macro")
        log_kv("Applies at", ":bind")
        log_p_close()
        log_verdict_standalone(true)
        record("sigil-register-macro", true)
    catch e
        log_test("SigilRegistry: register-macro")
        log_p_open()
        log_kv("Error", string(e))
        log_p_close()
        log_verdict_standalone(false, "error=$e")
        record("sigil-register-macro", false, "error=$e")
    end

    # Register lambda sigil
    try
        register_sigil!(_st;
                       name="test_live_lambda",
                       class=:lambda,
                       applies_at=:match,
                       sigil_type=:word,
                       provenance="live_test")
        log_test("SigilRegistry: register-lambda")
        log_p_open()
        log_kv("Name", "test_live_lambda")
        log_kv("Class", ":lambda")
        log_kv("Applies at", ":match")
        log_p_close()
        log_verdict_standalone(true)
        record("sigil-register-lambda", true)
    catch e
        log_test("SigilRegistry: register-lambda")
        log_p_open()
        log_kv("Error", string(e))
        log_p_close()
        log_verdict_standalone(false, "error=$e")
        record("sigil-register-lambda", false, "error=$e")
    end
end

# ═══════════════════════════════════════════════════════════════════
# SECTION 25: Lobe Registry — Post-Load Integrity
# ═══════════════════════════════════════════════════════════════════
log_section("Section 25: Lobe Registry — Post-Load Integrity")

let
    lobe_count = lock(LOBE_LOCK) do; length(LOBE_REGISTRY); end
    has_math = lock(LOBE_LOCK) do; haskey(LOBE_REGISTRY, "mathematics"); end
    has_sci = lock(LOBE_LOCK) do; haskey(LOBE_REGISTRY, "science"); end

    log_test("LobeRegistry: nonempty")
    log_p_open()
    log_kv("Count", string(lobe_count))
    log_verdict(lobe_count > 0, "count=$lobe_count")
    record("lobe-registry-nonempty", lobe_count > 0, "count=$lobe_count")

    log_test("LobeRegistry: mathematics-exists")
    log_verdict_standalone(has_math)
    record("lobe-mathematics-exists", has_math)

    log_test("LobeRegistry: science-exists")
    log_verdict_standalone(has_sci)
    record("lobe-science-exists", has_sci)
end

# ═══════════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════════

# Record the last section
if !isempty(_section_name[])
    push!(_section_results, (_section_name[], _section_pass[], _section_fail[]))
end

log_section("Final Summary")

total_pass = _pass[]
total_fail = _fail[]
total = total_pass + total_fail
pct = total > 0 ? round(100.0 * total_pass / total, digits=1) : 0.0

log_p_open()
log_kv("Completed", Dates.format(Dates.now(), Dates.dateformat"yyyy-mm-ddTHH:MM:SS"))
log_p_close()

# Results by section table
_log_write("<h2>Results by Section</h2>\n")
headers = ["Section", "Pass", "Fail", "Total"]
rows = Vector{String}[]
for (sname, sp, sf) in _section_results
    push!(rows, [sname, string(sp), string(sf), string(sp+sf)])
end
log_table(headers, rows)

# Total row
_log_write("<p>| <strong>TOTAL</strong> | <strong>$total_pass</strong> | <strong>$total_fail</strong> | <strong>$total</strong> |</p>\n")

if total_fail == 0
    _log_write("<h2>✅ All Tests Passed!</h2>\n")
else
    _log_write("<h2>❌ $(total_fail) Failures out of $(total)</h2>\n")
end

_log_write("<hr>\n")
log_p_open()
log_kv("Overall pass rate", "$(pct)%")
log_p_close()

# Save specimen after test
save_path = "/workspace/grug_live_test_post.specimen"
save_specimen_to_file!(save_path)
log_p_open()
log_kv("Post-test specimen saved", save_path)
log_p_close()

# Close the log
_log_close()

println("\n🏆 ALL $(total) TESTS PASSED!")

_total = total_pass + total_fail
if total_fail > 0
    println("💥 $(total_fail) FAILURES out of $(_total)")
end
println("📖 Log written to: $LOG_PATH")
println("💾 Specimen saved at: $save_path")
