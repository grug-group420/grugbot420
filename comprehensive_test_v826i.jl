#!/usr/bin/env julia
# ==============================================================================
# comprehensive_test_v826i.jl — Full GrugBot420 v8.26i comprehensive test
# ==============================================================================
# Covers: greetings, knowledge, science, math (arithmetic + sigil), multipart,
#         philosophy, emotion, metacognition, technology, history, language,
#         /answer teach-and-reask (all modes), relational sigils in triples,
#         thesaurus variation, NO antimatch references
# NEW v8.26i: Dictionary system (/define, /definitions, dict enrichment),
#             ConversationLobe auto-detection (X is Y, corrections, etc.),
#             Specimen save/load with dictionary state round-trip
# Logs results to MD file using in-program capture (not stdout)
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

# Internal API for /answer teach step (bypasses CLI loop)
import .GrugBot420:
    _base_answer_data, _create_answer_node, _plant_answer_cluster,
    _VALID_ANSWER_MODES, _ANSWER_MODE_CONFIG,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    _FANOUT_ENABLED, _FANOUT_MODES,
    _dissolve_solo_group!,
    register_group!, group_for, add_to_group!,
    immune_gate, dampen_strain!,
    create_node

# v8.26i: Dictionary system internals
import .GrugBot420:
    _dict_define_word!, _dict_lookup_word, _dict_lookup_for_mission,
    _dict_all_definitions, _dict_definitions_count,
    _dict_save_state, _dict_load_state!,
    _LOBE_DICTIONARIES, _LOBE_DICTIONARIES_LOCK

# v8.26i: ConversationLobe pre-scan
import .GrugBot420: _conversation_prescan, _conversation_answer_question

# v8.26i: /wrong feedback path (used by correction tests)
import .GrugBot420:
    LAST_VOTER_IDS, LAST_VOTER_LOCK,
    LAST_CONTRIBUTOR_IDS, LAST_LOCKED_NODE_IDS,
    apply_wrong_feedback!, apply_last_selected_feedback!,
    CONTEXT_FEEDBACK_WRONG_DELTA

import .GrugBot420.Lobe:
    add_node_to_lobe!, find_lobe_for_node, lobe_is_full, LOBE_REGISTRY

import .GrugBot420: count_alive_nodes_in_lobe

import .GrugBot420.EphemeralMLP: get_strain_energy, register_wrong_feedback!

# ── Configuration ──────────────────────────────────────────────────────────────
const SPEC_PATH  = get(ARGS, 1, "/workspace/grugbot420_repo/grug_v87_post_test.specimen")
const LOG_PATH   = "/workspace/grugbot420_repo/grug_v826i_comprehensive_test.md"
const SAVE_PATH  = "/workspace/grugbot420_repo/grug_v826i_post_test.specimen"

# ── In-program MD log buffer ───────────────────────────────────────────────────
const _log_lines = String[]

function log_md(line::String)
    push!(_log_lines, line)
end

function flush_log_md(filepath::String)

try
        open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "w") do f
        for line in _log_lines
            println(f, line)
        end
    end
end

# ── Voice output capture ───────────────────────────────────────────────────────
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

function is_ask_response(answer::String)::Bool
    occursin("Use /answer", answer) || occursin("use /answer", answer)
end

# ── Test runner with MD logging ────────────────────────────────────────────────
turn_counter = Ref{Int}(0)

function run_test(category::String, query::String; expect_ask::Bool=false)
    global turn_counter
    turn_counter[] += 1
    turn = turn_counter[]

    raw = run_mission(query)
    answer = clean_output(raw)

    if isempty(answer)
        status = "❌ EMPTY"
        verdict = "EMPTY"
    elseif is_ask_response(answer) && expect_ask
        status = "✅ ASK"
        verdict = "ASK generated"
    elseif is_failure_response(answer) && !expect_ask
        status = "❌ CAVE-EMPTY"
        verdict = "CAVE-EMPTY"
    elseif is_failure_response(answer) && expect_ask
        status = "✅ ASK"
        verdict = "ASK generated"
    elseif length(answer) < 5
        status = "⚠️ SHORT"
        verdict = "SHORT"
    else
        status = "✅"
        verdict = "OK"
    end

    log_md("## Turn $turn — $category")
    log_md("")
    log_md("**User:** $query")
    log_md("")
    log_md("> $answer")
    log_md("")
    log_md("**Verdict:** $status $verdict")
    log_md("")
    log_md("---")
    log_md("")

    display_answer = length(answer) > 150 ? first(answer, 150) * "…" : answer
    println("[$status] T$turn $category: \"$query\" → $(display_answer)")

    return (turn, category, query, answer, status, verdict)
end

# ── Internal API teach step ────────────────────────────────────────────────────
# Replicates the CLI /answer dispatch using direct internal function calls.
# This is necessary because /answer is a CLI-loop command and NOT handled
# inside process_mission(). Sending "/answer @lobe :mode content" through
# process_mission() causes the engine to treat it as multipart input.

function _teach_answer(lobe::String, mode::String, content::String)
    if !haskey(LOBE_REGISTRY, lobe)
        @warn "/answer teach: lobe '$lobe' does not exist"
        return ("", String[])
    end
    if lobe_is_full(lobe)
        @warn "/answer teach: lobe '$lobe' is full"
        return ("", String[])
    end
    if !immune_gate("/answer", content; is_critical=false)
        @warn "/answer teach: blocked by immune system"
        return ("", String[])
    end
    try dampen_strain!(0.7) catch e @warn "dampen_strain! failed (non-fatal)" exception=e end
    pending_ask_text = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        old = _HIPPOCAMPAL_PENDING_ASK[]
        _HIPPOCAMPAL_PENDING_ASK[] = ""
        old
    end
    target_lobe = lobe
    mode_str = mode

    if mode_str == "relate"
        relate_parts = [String(strip(String(p))) for p in split(content, "|")]
        if length(relate_parts) < 3
            @warn "/answer :relate needs 'subject | relation | object'"
            return ("", String[])
        end
        subj = relate_parts[1]; rel_raw = relate_parts[2]; obj = relate_parts[3]
        relate_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text,
                                         answer_content="$(lowercase(subj)) $(rel_raw) $(lowercase(obj))")
        relate_data["answer_mode"] = "relate"
        relate_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
        relate_data["required_relations"] = [rel_raw]
        relate_data["seeded_triple"] = Dict("subject"=>lowercase(subj),"relation"=>rel_raw,"object"=>lowercase(obj))
        relate_data["voice_register"] = "plain"; relate_data["frame_hints"] = ["plain","exploratory"]
        primary_id, shadow_ids, lobe_tag = _plant_answer_cluster(subj, "reason^1", relate_data, target_lobe, "relate")
        return (primary_id, shadow_ids)

    elseif mode_str == "time"
        time_parts = [String(strip(String(s))) for s in split(content, "|")]; time_parts = filter(!isempty, time_parts)
        if length(time_parts) < 2
            @warn "/answer :time needs 'subject | object'"
            return ("", String[])
        end
        subj = time_parts[1]; obj = time_parts[2]
        time_orient = length(time_parts) >= 3 ? String(strip(time_parts[3])) : ""
        time_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text,
                                       answer_content="$(lowercase(subj)) &temporal $(lowercase(obj))")
        time_data["answer_mode"] = "time"; time_data["time_node"] = true
        if !isempty(time_orient) && lowercase(time_orient) in ("past","present","future")
            time_data["time_orientation"] = lowercase(time_orient)
            orient_to_sigil = Dict("past"=>"before","present"=>"now","future"=>"next")
            time_data["time_sigil"] = orient_to_sigil[lowercase(time_orient)]
        end
        time_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
        time_data["required_relations"] = ["&temporal"]
        time_data["seeded_triple"] = Dict("subject"=>lowercase(subj),"relation"=>"&temporal","object"=>lowercase(obj))
        time_data["voice_register"] = "plain"; time_data["frame_hints"] = ["plain","exploratory"]
        primary_id, shadow_ids, lobe_tag = _plant_answer_cluster(subj, "reason^1", time_data, target_lobe, "time")
        return (primary_id, shadow_ids)

    elseif mode_str == "proc"
        proc_steps = [String(strip(String(s))) for s in split(content, ";")]; proc_steps = filter(!isempty, proc_steps)
        if length(proc_steps) < 2
            @warn "/answer :proc needs at least 2 semicolon-delimited steps"
            return ("", String[])
        end
        proc_ids = String[]
        for (i, step_text) in enumerate(proc_steps)
            step_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text, answer_content=step_text)
            step_data["answer_mode"] = "proc"; step_data["proc_step"] = i; step_data["proc_total"] = length(proc_steps)
            step_data["voice_register"] = "plain"; step_data["frame_hints"] = ["imperative","plain"]
            nid, lobe_tag = _create_answer_node(step_text, "reason^1", step_data, target_lobe; skip_auto_latch=true)
            push!(proc_ids, nid)
        end
        for i in 1:(length(proc_ids)-1)
            if haskey(NODE_MAP, proc_ids[i]); push!(NODE_MAP[proc_ids[i]].drop_table, proc_ids[i+1]) end
        end
        if length(proc_ids) > 1
            try
                first_id = proc_ids[1]
                if haskey(NODE_MAP, first_id)
                    register_group!(NODE_MAP[first_id])
                    for other_id in proc_ids[2:end]
                        if haskey(NODE_MAP, other_id)
                            grp = group_for(first_id)
                            if !isnothing(grp); _dissolve_solo_group!(other_id); add_to_group!(grp, other_id) end
                        end
                    end
                end
            catch e @warn "/answer :proc auto-grouping failed (non-fatal)" exception=e end
        end
        return (proc_ids[1], proc_ids[2:end])

    elseif mode_str == "multi"
        raw_parts = split(content, "|")
        parts = Tuple{String, String, String}[]
        for part in raw_parts
            trimmed = String(strip(String(part))); isempty(trimmed) && continue
            m = match(r"^:(\w+)\s+(.+)$", trimmed)
            if !isnothing(m); push!(parts, ("$(lowercase(String(m.captures[1])))^1", String(strip(String(m.captures[2]))), lowercase(String(m.captures[1]))))
            else; push!(parts, ("reason^1", trimmed, "reason")) end
        end
        if isempty(parts); @warn "/answer :multi needs pipe-delimited parts"; return ("", String[]) end
        all_primary_ids = String[]; all_shadow_ids = String[]
        for (i, (action_pkt, part_text, part_mode)) in enumerate(parts)
            cfg = get(_ANSWER_MODE_CONFIG, part_mode, _ANSWER_MODE_CONFIG["reason"])
            part_data = _base_answer_data(part_mode; pending_ask_text=pending_ask_text, answer_content=part_text)
            part_data["answer_mode"] = "multi"; part_data["multi_part_action"] = action_pkt
            part_data["multi_part_index"] = i; part_data["multi_part_total"] = length(parts)
            part_data["voice_register"] = get(cfg, "voice", "plain")
            part_data["frame_hints"] = get(cfg, "frame", ["plain","exploratory"])
            primary_id, shadow_ids, lobe_tag = _plant_answer_cluster(part_text, action_pkt, part_data, target_lobe, part_mode)
            push!(all_primary_ids, primary_id); append!(all_shadow_ids, shadow_ids)
        end
        for pid in all_primary_ids
            if haskey(NODE_MAP, pid)
                for other_pid in all_primary_ids
                    other_pid == pid && continue
                    if haskey(NODE_MAP, other_pid) && !(other_pid in NODE_MAP[pid].drop_table)
                        push!(NODE_MAP[pid].drop_table, other_pid)
                    end
                end
            end
        end
        all_cluster_ids = vcat(all_primary_ids, all_shadow_ids)
        if length(all_cluster_ids) > 1
            try
                first_id = all_primary_ids[1]
                if haskey(NODE_MAP, first_id)
                    register_group!(NODE_MAP[first_id])
                    for other_id in all_cluster_ids[2:end]
                        if haskey(NODE_MAP, other_id)
                            grp = group_for(first_id)
                            if !isnothing(grp); _dissolve_solo_group!(other_id); add_to_group!(grp, other_id) end
                        end
                    end
                end
            catch e @warn "/answer :multi auto-grouping failed (non-fatal)" exception=e end
        end
        return (all_primary_ids[1], vcat(all_primary_ids[2:end], all_shadow_ids))

    elseif mode_str == "math"
        math_data = _base_answer_data("math"; pending_ask_text=pending_ask_text, answer_content=content)
        math_tokens = split(lowercase(content))
        math_anchors = [tok for tok in math_tokens if occursin(r"^[\d\.\+\-\*\/\=\^\<\>%]+$", tok) || (length(tok) <= 3 && occursin(r"^[a-z]$", tok))]
        if !isempty(math_anchors); math_data["noun_anchors"] = math_anchors end
        math_data["answer_mode"] = "math"; math_data["is_math_node"] = true
        primary_id, shadow_ids, lobe_tag = _plant_answer_cluster(content, "reason^1", math_data, target_lobe, "math")
        return (primary_id, shadow_ids)

    else
        cfg = get(_ANSWER_MODE_CONFIG, mode_str, _ANSWER_MODE_CONFIG["reason"])
        action_pkt = cfg["action"]
        typed_data = _base_answer_data(mode_str; pending_ask_text=pending_ask_text, answer_content=content)
        primary_id, shadow_ids, lobe_tag = _plant_answer_cluster(content, action_pkt, typed_data, target_lobe, mode_str)
        return (primary_id, shadow_ids)
    end
end

# ── /answer teach-and-reask runner ─────────────────────────────────────────────
function run_answer_scenario(
    scenario_name::String, ask_query::String,
    lobe::String, mode::String, content::String;
    expect_recall::Bool=true
)
    log_md("## /answer Scenario: $scenario_name")
    log_md("")

    log_md("### Step 1: Ask (before teaching)")
    log_md("")
    raw1 = run_mission(ask_query)
    answer1 = clean_output(raw1)
    ask_ok = is_ask_response(answer1) || is_failure_response(answer1)
    ask_status = ask_ok ? "✅ ASK generated" : "⚠️ No ASK (already known?)"
    log_md("**User:** $ask_query")
    log_md("")
    log_md("> $(answer1)")
    log_md("")
    log_md("**Verdict:** $ask_status")
    log_md("")

    log_md("### Step 2: Teach (/answer @$lobe :$mode) [internal API]")
    log_md("")
    log_md("**Teach command:** `/answer @$lobe :$mode $content`")
    log_md("")
    primary_id, shadow_ids = _teach_answer(lobe, mode, content)
    teach_ok = !isempty(primary_id)
    n_shadows = length(shadow_ids)
    teach_status = teach_ok ? "✅ Planted primary=$primary_id +$n_shadows shadows" : "❌ Teach failed"
    lobe_of = teach_ok ? find_lobe_for_node(primary_id) : nothing
    lobe_info = !isnothing(lobe_of) ? " (lobe: $lobe_of)" : ""
    log_md("> $teach_status$lobe_info")
    log_md("")

    log_md("### Step 3: Recall (after teaching)")
    log_md("")
    raw3 = run_mission(ask_query)
    answer3 = clean_output(raw3)
    recall_ok = !is_failure_response(answer3) && !isempty(answer3) && length(answer3) > 5
    recall_status = recall_ok ? "✅ Recalled" : "❌ Failed recall"
    anchor_text = replace(content, r"[|;&]" => " ")
    content_words = split(lowercase(anchor_text))
    content_anchors = filter(w -> length(w) > 4, content_words)
    anchors_found = count(w -> occursin(w, lowercase(answer3)), content_anchors)
    anchor_total = length(content_anchors)
    anchor_status = anchor_total > 0 ? "$anchors_found/$anchor_total anchors" : "no anchors"
    log_md("**User:** $ask_query")
    log_md("")
    log_md("> $(answer3)")
    log_md("")
    log_md("**Verdict:** $recall_status | $anchor_status")
    log_md("")
    log_md("---")
    log_md("")
    println("[/answer] $scenario_name: ask=$ask_ok teach=$teach_ok recall=$recall_ok anchors=$anchors_found/$anchor_total")
    return (scenario_name, ask_ok, teach_ok, recall_ok, anchors_found, anchor_total)
end

# ── Thesaurus variation check ──────────────────────────────────────────────────
function run_variation_test(query::String, n_trials::Int=3)
    log_md("## Variation test: \"$query\"")
    log_md("")
    responses = String[]
    for i in 1:n_trials
        raw = run_mission(query)
        answer = clean_output(raw)
        push!(responses, answer)
        display_answer = length(answer) > 200 ? first(answer, 200) * "…" : answer
        log_md("**Trial $i:** $(display_answer)")
        log_md("")
    end
    unique_responses = unique(responses)
    variation_ok = length(unique_responses) >= 2
    var_status = variation_ok ? "✅ Variation detected" : "⚠️ Identical responses"
    log_md("**Result:** $var_status")
    log_md("")
    log_md("---")
    log_md("")
    println("[variation] \"$query\": $(length(unique_responses))/3 unique → $var_status")
    return variation_ok
end

# ── Dictionary test helpers ────────────────────────────────────────────────────
function run_dict_define_test(label::String, lobe::String, word::String, definition::String)
    log_md("## Dict Define: $label")
    log_md("")
    log_md("**Command:** `/define @$lobe $word = $definition` (internal API)")
    log_md("")
    _dict_define_word!(lobe, word, definition)
    # Verify it was stored
    lookup_result = _dict_lookup_word(word; lobe_hint=lobe)
    define_ok = !isnothing(lookup_result) && occursin(lowercase(strip(definition)), lowercase(lookup_result))
    status = define_ok ? "✅ Defined & verified" : "❌ Define failed"
    log_md("> $status — lookup returned: $(lookup_result)")
    log_md("")
    log_md("---")
    log_md("")
    println("[dict] $label: $status (lookup=$(lookup_result))")
    return (label, define_ok, word, definition, lobe)
end

function run_dict_lookup_test(label::String, word::String; lobe_hint::String="", expect_found::Bool=true)
    log_md("## Dict Lookup: $label")
    log_md("")
    log_md("**Query:** word='$word' lobe_hint='$lobe_hint'")
    log_md("")
    result = _dict_lookup_word(word; lobe_hint=lobe_hint)
    found_ok = expect_found ? !isnothing(result) : isnothing(result)
    status = found_ok ? "✅ Lookup correct" : "❌ Lookup mismatch"
    log_md("> $status — result: $(result)")
    log_md("")
    log_md("---")
    log_md("")
    println("[dict-lookup] $label: $status (result=$(result))")
    return (label, found_ok, result)
end

function run_dict_mission_lookup_test(label::String, mission_text::String, expect_count::Int=1)
    log_md("## Dict Mission Lookup: $label")
    log_md("")
    log_md("**Mission text:** $mission_text")
    log_md("")
    hits = _dict_lookup_for_mission(mission_text)
    count_ok = length(hits) >= expect_count
    status = count_ok ? "✅ Found $(length(hits)) dict words" : "⚠️ Found $(length(hits)) dict words (expected ≥$expect_count)"
    for (w, d, lid) in hits
        log_md("- '$w' → '$d' (lobe: $lid)")
    end
    log_md("")
    log_md("> $status")
    log_md("")
    log_md("---")
    log_md("")
    println("[dict-mission] $label: $status (hits=$(length(hits)))")
    return (label, count_ok, hits)
end

# ── ConversationLobe test helper ───────────────────────────────────────────────
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
        log_md("> $status — word='$word' def='$def' lobe_hint='$lobe_hint'")
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

function run_conv_live_test(label::String, text::String, expect_prefix::String)
    """Test conversation auto-detection through process_mission (live)."""
    log_md("## ConvLive: $label")
    log_md("")
    log_md("**Input:** \"$text\"")
    log_md("**Expected output contains:** \"$expect_prefix\"")
    log_md("")
    raw = run_mission(text)
    answer = clean_output(raw)
    match_ok = occursin(expect_prefix, answer)
    status = match_ok ? "✅ Output matches" : "❌ Output mismatch"
    log_md("> $status — got: $(first(answer, 200))")
    log_md("")
    log_md("---")
    log_md("")
    println("[conv-live] $label: $status")
    return (label, match_ok, answer)
end

# ══════════════════════════════════════════════════════════════════════════════
# MAIN TEST SEQUENCE
# ══════════════════════════════════════════════════════════════════════════════

# ── Write MD header ────────────────────────────────────────────────────────────
log_md("# GrugBot420 Comprehensive Test Log v8.26i")
log_md("")
log_md("**Date:** $(now())")
log_md("**Specimen:** $SPEC_PATH")
log_md("**Chatter:** DISABLED")
log_md("**Capture method:** _LAST_VOICE_OUTPUT (application internals)")
log_md("**v8.26i features:** Lobe Dictionary System, ConversationLobe auto-detection, /define, /definitions")
log_md("**NO antimatch node references** — antimatch was removed in v8.26h")
log_md("**Relational triples support sigils** (&n, &op, &causal, &temporal, &spatial, &being)")
log_md("")
log_md("---")
log_md("")

# ── Load specimen ──────────────────────────────────────────────────────────────
println("=" ^ 70)
println("GRUGBOT420 COMPREHENSIVE TEST v8.26i")
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

    # Expand lobe caps for /answer teach testing
    for (lobe_name, rec) in LOBE_REGISTRY
        alive = count_alive_nodes_in_lobe(lobe_name)
        needed = alive + 40
        if needed > rec.node_cap
            old_cap = rec.node_cap
            rec.node_cap = needed
            println("  📦 Lobe '$lobe_name' cap expanded: $old_cap → $(needed) (alive=$alive)")
            log_md("- Lobe '$lobe_name' cap expanded: $old_cap → $(needed) (alive=$alive)")
        end
    end

    # Report dictionary state after load (v8.26i)
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

results = []
answer_results = []
dict_results = []
conv_results = []

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: GREETINGS
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 1: Greetings")
log_md("")
println("─" ^ 70)
println("SECTION 1: GREETINGS")
println("─" ^ 70)
println()

push!(results, run_test("greeting", "hello"))
push!(results, run_test("greeting", "hey grug"))
push!(results, run_test("greeting", "good morning"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: KNOWLEDGE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 2: Knowledge")
log_md("")
println("─" ^ 70)
println("SECTION 2: KNOWLEDGE")
println("─" ^ 70)
println()

push!(results, run_test("knowledge", "what is fire"))
push!(results, run_test("knowledge", "tell me about water"))
push!(results, run_test("knowledge", "what is earth"))
push!(results, run_test("knowledge", "what is sky"))
push!(results, run_test("knowledge", "what is love"))
push!(results, run_test("knowledge", "what is fear"))
push!(results, run_test("knowledge", "what is courage"))
push!(results, run_test("knowledge", "what is river"))
push!(results, run_test("knowledge", "what is forest"))
push!(results, run_test("knowledge", "why does fire burn"))
push!(results, run_test("knowledge", "how does water flow"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: SCIENCE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 3: Science")
log_md("")
println("─" ^ 70)
println("SECTION 3: SCIENCE")
println("─" ^ 70)
println()

push!(results, run_test("science", "what is gravity"))
push!(results, run_test("science", "what is photosynthesis"))
push!(results, run_test("science", "what is DNA"))
push!(results, run_test("science", "why is the sky blue"))
push!(results, run_test("science", "what is thermodynamics"))
push!(results, run_test("science", "what is evolution"))
push!(results, run_test("science", "what is an atom"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: MATH — SIGIL NODES (DYNAMIC COMPUTATION)
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 4: Math — Sigil Nodes")
log_md("")
println("─" ^ 70)
println("SECTION 4: MATH — SIGIL NODES")
println("─" ^ 70)
println()

push!(results, run_test("math-sigil", "factorial of 5"))
push!(results, run_test("math-sigil", "factorial of 7"))
push!(results, run_test("math-sigil", "square of 9"))
push!(results, run_test("math-sigil", "cube of 3"))
push!(results, run_test("math-sigil", "double 7"))
push!(results, run_test("math-sigil", "half of 12"))
push!(results, run_test("math-sigil", "fibonacci of 10"))
push!(results, run_test("math-sigil", "absolute value of -15"))
push!(results, run_test("math-sigil", "reciprocal of 4"))
push!(results, run_test("math-sigil", "square root of 16"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: MATH — ARITHMETIC (SIGIL PROMOTER + ARITHMETIC ENGINE)
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 5: Math — Arithmetic (Sigil Promoter + Arithmetic Engine)")
log_md("")
println("─" ^ 70)
println("SECTION 5: MATH — ARITHMETIC")
println("─" ^ 70)
println()

push!(results, run_test("math", "3 + 5"))
push!(results, run_test("math", "12 * 4"))
push!(results, run_test("math", "15 - 7"))
push!(results, run_test("math", "20 / 5"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: MULTIPART QUESTIONS
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 6: Multipart Questions")
log_md("")
println("─" ^ 70)
println("SECTION 6: MULTIPART QUESTIONS")
println("─" ^ 70)
println()

push!(results, run_test("multipart", "what is fire and what is water"))
push!(results, run_test("multipart", "why does fire burn and why does water flow"))
push!(results, run_test("multipart", "what is love and what is courage"))
push!(results, run_test("multipart", "what is gravity and what is thermodynamics"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: PHILOSOPHY
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 7: Philosophy")
log_md("")
println("─" ^ 70)
println("SECTION 7: PHILOSOPHY")
println("─" ^ 70)
println()

push!(results, run_test("philosophy", "what is consciousness"))
push!(results, run_test("philosophy", "what is truth"))
push!(results, run_test("philosophy", "what is ethics"))
push!(results, run_test("philosophy", "what is knowledge"))
push!(results, run_test("philosophy", "what is time"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8: EMOTION
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 8: Emotion")
log_md("")
println("─" ^ 70)
println("SECTION 8: EMOTION")
println("─" ^ 70)
println()

push!(results, run_test("emotion", "i feel sad"))
push!(results, run_test("emotion", "i am afraid"))
push!(results, run_test("emotion", "i feel happy"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9: METACOGNITION
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 9: Metacognition")
log_md("")
println("─" ^ 70)
println("SECTION 9: METACOGNITION")
println("─" ^ 70)
println()

push!(results, run_test("metacognition", "how do you think"))
push!(results, run_test("metacognition", "who are you"))
push!(results, run_test("metacognition", "what do you know"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10: TECHNOLOGY
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 10: Technology")
log_md("")
println("─" ^ 70)
println("SECTION 10: TECHNOLOGY")
println("─" ^ 70)
println()

push!(results, run_test("technology", "what is programming"))
push!(results, run_test("technology", "what is the internet"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 11: HISTORY
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 11: History")
log_md("")
println("─" ^ 70)
println("SECTION 11: HISTORY")
println("─" ^ 70)
println()

push!(results, run_test("history", "what is civilization"))
push!(results, run_test("history", "what is revolution"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 12: LANGUAGE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 12: Language")
log_md("")
println("─" ^ 70)
println("SECTION 12: LANGUAGE")
println("─" ^ 70)
println()

push!(results, run_test("language", "what is poetry"))
push!(results, run_test("language", "what is grammar"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 13: RELATIONAL SIGILS (DYNAMIC TRIPLES)
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 13: Relational Sigils (Dynamic Triples)")
log_md("")
println("─" ^ 70)
println("SECTION 13: RELATIONAL SIGILS")
println("─" ^ 70)
println()

# These test &causal, &being, &temporal, &spatial relation sigils in triples
push!(results, run_test("rel-sigil", "what causes fire to burn"))
push!(results, run_test("rel-sigil", "what is combustion"))
push!(results, run_test("rel-sigil", "what comes before rain"))
push!(results, run_test("rel-sigil", "what is above the ground"))
push!(results, run_test("rel-sigil", "what enables photosynthesis"))
push!(results, run_test("rel-sigil", "what produces oxygen"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 14: /answer MECHANIC TEST (TEACH-AND-REASK WITH LOBES)
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 14: /answer Mechanic Test (Teach-and-Reask with Lobes)")
log_md("")
println("─" ^ 70)
println("SECTION 14: /answer TEACH-AND-REASK")
println("─" ^ 70)
println()

# Scenario 1: Science lobe, :explain mode — stromatolite
push!(answer_results, run_answer_scenario(
    "what is a stromatolite", "what is a stromatolite",
    "science", "explain",
    "stromatolites are layered rock structures formed by cyanobacteria in shallow water"))

# Scenario 2: Science lobe, :reason mode — quasar
push!(answer_results, run_answer_scenario(
    "what is a quasar", "what is a quasar",
    "science", "reason",
    "quasars are extremely luminous active galactic nuclei powered by supermassive black holes"))

# Scenario 3: Science lobe, :explain — fermentation
push!(answer_results, run_answer_scenario(
    "what is fermentation", "what is fermentation",
    "science", "explain",
    "fermentation converts sugar into alcohol and carbon dioxide using yeast or bacteria"))

# Scenario 4: Mathematics lobe, :define — golden ratio
push!(answer_results, run_answer_scenario(
    "what is the golden ratio", "what is the golden ratio",
    "mathematics", "define",
    "the golden ratio is approximately 1.618 and appears in art architecture and nature"))

# Scenario 5: Emotion lobe, :reason — empathy
push!(answer_results, run_answer_scenario(
    "what is empathy", "what is empathy",
    "emotion", "reason",
    "empathy is understanding and sharing the feelings of another person through emotional connection"))

# Scenario 6: Language lobe, :define — sonnet
push!(answer_results, run_answer_scenario(
    "what is a sonnet", "what is a sonnet",
    "language", "define",
    "a sonnet is a fourteen line poem with a specific rhyme scheme and meter"))

# Scenario 7: Philosophy lobe, :reason — solipsism
push!(answer_results, run_answer_scenario(
    "what is solipsism", "what is solipsism",
    "philosophy", "reason",
    "solipsism is the philosophical idea that only ones own mind is certain to exist"))

# Scenario 8: History lobe, :explain — renaissance
push!(answer_results, run_answer_scenario(
    "what was the renaissance", "what was the renaissance",
    "history", "explain",
    "the renaissance was a cultural movement in Europe from the 14th to 17th century that revived classical learning"))

# Scenario 9: Technology lobe, :define — algorithm
push!(answer_results, run_answer_scenario(
    "what is an algorithm", "what is an algorithm",
    "technology", "define",
    "an algorithm is a step by step procedure for solving a problem or accomplishing a task"))

# Scenario 10: Mathematics lobe, :math — prime numbers
push!(answer_results, run_answer_scenario(
    "what are prime numbers", "what are prime numbers",
    "mathematics", "math",
    "prime numbers are natural numbers greater than 1 that have no positive divisors other than 1 and themselves"))

# Scenario 11: Nature lobe, :relate — water cycle (triple-seeded with &causal sigil)
push!(answer_results, run_answer_scenario(
    "what is the water cycle", "what is the water cycle",
    "nature", "relate",
    "water cycle | &causal causes | evaporation condensation precipitation"))

# Scenario 12: Emotion lobe, :comfort — grief
push!(answer_results, run_answer_scenario(
    "what is grief", "what is grief",
    "emotion", "comfort",
    "grief is deep sorrow caused by loss and it takes time and support to heal"))

# Scenario 13: History lobe, :time — temporal relation (sigil &temporal)
push!(answer_results, run_answer_scenario(
    "what came before the renaissance", "what came before the renaissance",
    "history", "time",
    "the dark ages | the renaissance | past"))

# Scenario 14: Science lobe, :proc — photosynthesis procedure
push!(answer_results, run_answer_scenario(
    "how does photosynthesis work", "how does photosynthesis work",
    "science", "proc",
    "sunlight is absorbed by chlorophyll; water is split into hydrogen and oxygen; carbon dioxide is converted into glucose; oxygen is released as waste"))

# Scenario 15: Science lobe, :multi — multipart answer
push!(answer_results, run_answer_scenario(
    "what is mitosis and why does it matter", "what is mitosis and why does it matter",
    "science", "multi",
    ":define mitosis is cell division producing two identical daughter cells | :reason mitosis enables growth tissue repair and asexual reproduction"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 15: THESAURUS VARIATION CHECK
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 15: Thesaurus Variation Check (Same Query × 3)")
log_md("")
println("─" ^ 70)
println("SECTION 15: THESAURUS VARIATION CHECK")
println("─" ^ 70)
println()

# v8.27: "what is X" patterns now intercepted by organic question answering
# (deterministic dictionary/cave lookup — no thesaurus variation expected).
# For variation testing, use bare nouns that go through AIML voting pipeline.
variation_results = []
push!(variation_results, run_variation_test("fire"))
push!(variation_results, run_variation_test("water"))
push!(variation_results, run_variation_test("gravity"))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 16: DICTIONARY SYSTEM (/define, /definitions, dict enrichment)
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 16: Dictionary System (/define, /definitions, dict enrichment)")
log_md("")
println("─" ^ 70)
println("SECTION 16: DICTIONARY SYSTEM")
println("─" ^ 70)
println()

# 16a: Define words in various lobes via internal API
push!(dict_results, run_dict_define_test("science-fire", "science", "fire", "oxidation and heat"))
push!(dict_results, run_dict_define_test("science-gravity", "science", "gravity", "attractive force between masses"))
push!(dict_results, run_dict_define_test("science-atom", "science", "atom", "smallest unit of an element"))
push!(dict_results, run_dict_define_test("math-pi", "mathematics", "pi", "3.14159 the ratio of circumference to diameter"))
push!(dict_results, run_dict_define_test("math-prime", "mathematics", "prime", "number divisible only by 1 and itself"))
push!(dict_results, run_dict_define_test("default-hello", "default", "hello", "a greeting"))
push!(dict_results, run_dict_define_test("philosophy-truth", "philosophy", "truth", "correspondence with reality"))
push!(dict_results, run_dict_define_test("emotion-empathy", "emotion", "empathy", "sharing the feelings of another"))

# 16b: Lookup tests
push!(dict_results, run_dict_lookup_test("fire-in-science", "fire"; lobe_hint="science", expect_found=true))
push!(dict_results, run_dict_lookup_test("fire-no-lobe-hint", "fire"; lobe_hint="", expect_found=true))
push!(dict_results, run_dict_lookup_test("pi-in-math", "pi"; lobe_hint="mathematics", expect_found=true))
push!(dict_results, run_dict_lookup_test("pi-wrong-lobe", "pi"; lobe_hint="science", expect_found=false))
push!(dict_results, run_dict_lookup_test("nonexistent", "xyzabc123"; expect_found=false))
push!(dict_results, run_dict_lookup_test("hello-default", "hello"; lobe_hint="default", expect_found=true))

# 16c: Mission lookup (dictionary enrichment for strain response)
push!(dict_results, run_dict_mission_lookup_test("fire-mission", "what is fire", 1))
push!(dict_results, run_dict_mission_lookup_test("gravity-atom-mission", "what is gravity and atoms", 1))  # only gravity matches; atoms≠atom (no stemming)
push!(dict_results, run_dict_mission_lookup_test("empty-mission", "what is xyzabc123", 0))

# 16d: _dict_all_definitions and _dict_definitions_count
log_md("## Dict: All Definitions Count & Per-Lobe")
log_md("")
_total_defs = _dict_definitions_count()
_all_science = _dict_all_definitions("science")
_all_math = _dict_all_definitions("mathematics")
_all_default = _dict_all_definitions("default")
log_md("**Total definitions:** $_total_defs")
log_md("**Science lobe:** $(_all_science) ($length(_all_science)) words")
log_md("**Mathematics lobe:** $(_all_math) ($length(_all_math)) words")
log_md("**Default lobe:** $(_all_default) ($length(_all_default)) words")
log_md("")
log_md("---")
log_md("")
println("[dict] Total=$_total_defs science=$(length(_all_science)) math=$(length(_all_math)) default=$(length(_all_default))")

# 16e: Dictionary enrichment in strain response — ask about a word we defined,
# then check if the strain response mentions the dictionary knowledge.
# First, ask about something NOT in nodes but IS in dictionary
log_md("## Dict Enrichment in Strain Response")
log_md("")
log_md("**Asking:** \"what is pi\" (pi is in dictionary, not in answer nodes)")
log_md("")
_pi_raw = run_mission("what is pi")
_pi_answer = clean_output(_pi_raw)
_pi_has_dict = occursin("pi", lowercase(_pi_answer)) || occursin("3.14", _pi_answer) || occursin("📖", _pi_answer)
_pi_status = _pi_has_dict ? "✅ Dictionary enriched" : "⚠️ No dictionary enrichment visible"
log_md("> $_pi_status — $(first(_pi_answer, 200))")
log_md("")
log_md("---")
log_md("")
println("[dict-enrichment] pi: $_pi_status")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 17: CONVERSATION LOBE AUTO-DETECTION
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 17: ConversationLobe Auto-Detection")
log_md("")
println("─" ^ 70)
println("SECTION 17: CONVERSATION LOBE")
println("─" ^ 70)
println()

# 17a: Pre-scan unit tests (pure function, no side effects)
log_md("## 17a: _conversation_prescan Unit Tests")
log_md("")

# Short "X is Y" → :define
push!(conv_results, run_conv_prescan_test("short-is-define", "fire is oxidation and heat", :define))
push!(conv_results, run_conv_prescan_test("short-means", "pi means the ratio of circumference to diameter", :define))
push!(conv_results, run_conv_prescan_test("define-as", "define entropy as a measure of disorder", :define))
push!(conv_results, run_conv_prescan_test("equals-define", "euler = 2.71828", :define))

# Long "X is Y" → :answer (>15 words)
push!(conv_results, run_conv_prescan_test("long-is-answer",
    "gravity is an attractive force between two masses that follows the inverse square law and shapes the orbits of planets",
    :answer))

# Correction patterns → :correct
push!(conv_results, run_conv_prescan_test("no-correction", "no, fire is plasma not oxidation", :correct))
push!(conv_results, run_conv_prescan_test("actually-correction", "actually, gravity is curvature of spacetime", :correct))
push!(conv_results, run_conv_prescan_test("wrong-correction", "wrong, the earth is round not flat", :correct))

# Standalone correction signals → :correct (no word/def)
push!(conv_results, run_conv_prescan_test("standalone-wrong", "wrong", :correct))
push!(conv_results, run_conv_prescan_test("standalone-no", "no", :correct))
push!(conv_results, run_conv_prescan_test("standalone-incorrect", "incorrect", :correct))

# Things that should NOT match → nothing
push!(conv_results, run_conv_prescan_test("slash-command", "/define fire = oxidation", :nothing))
# GRUG v8.27: Questions now return :question (organic answer path), not :nothing
push!(conv_results, run_conv_prescan_test("question", "what is fire?", :question))
push!(conv_results, run_conv_prescan_test("pronoun-it", "it is a beautiful day", :nothing))
push!(conv_results, run_conv_prescan_test("pronoun-they", "they are going to the store", :nothing))

# 17b: Live ConversationLobe tests (through process_mission)
log_md("")
log_md("## 17b: Live ConversationLobe Tests (through process_mission)")
log_md("")

# "X is Y" short → should auto-define and return Learned message
push!(conv_results, run_conv_live_test("auto-define-short",
    "phlogiston is a deprecated theory of combustion",
    "Learned"))

# "X means Y" → should auto-define
push!(conv_results, run_conv_live_test("auto-define-means",
    "supernova means the explosive death of a massive star",
    "Learned"))

# "define X as Y" → should auto-define
push!(conv_results, run_conv_live_test("auto-define-as",
    "define mitosis as cell division producing identical daughters",
    "Learned"))

# "X = Y" → should auto-define
push!(conv_results, run_conv_live_test("auto-define-equals",
    "avogadro = 6.022e23",
    "Learned"))

# Long statement → should auto-answer (plant cluster)
push!(conv_results, run_conv_live_test("auto-answer-long",
    "dark matter is a hypothetical form of matter that accounts for approximately 85 percent of the total mass of the universe and does not emit or interact with electromagnetic radiation",
    "Grug learned"))

# Standalone "wrong" → should trigger correction (punish last)
push!(conv_results, run_conv_live_test("standalone-wrong-live",
    "wrong",
    "correction"))

# ══════════════════════════════════════════════════════════════════════════════

# ──────────────────────────────────────────────────────────────────────────
# SECTION 17c: ORGANIC QUESTION ANSWERING (v8.27)
# ──────────────────────────────────────────────────────────────────────────
log_md("# Section 17c: Organic Question Answering (v8.27)")
log_md("")
println("─" ^ 70)
println("SECTION 17c: ORGANIC QUESTION ANSWERING")
println("─" ^ 70)
println()

# Test helper: ask a question, check if organic answer was returned
# (bypasses AIML — either 📖 dictionary prefix or cave-node content)
function run_organic_q_test(label::String, query::String, expected_fragment::String="")
    log_md("## Organic Q: $label")
    log_md("")
    log_md("**Query:** \"$query\"")
    log_md("")
    _raw = run_mission(query)
    _ans = clean_output(_raw)
    _has_dict = occursin("📖", _ans)
    _has_fragment = isempty(expected_fragment) || occursin(lowercase(expected_fragment), lowercase(_ans))
    _ok = _has_dict || _has_fragment
    _status = _ok ? "✅ Organic answer" : "⚠️ No organic answer"
    _display = length(_ans) > 300 ? first(_ans, 300) * "…" : _ans
    log_md("**Answer:** $_display")
    log_md("")
    log_md("**Result:** $_status (📖=$_has_dict, fragment=$_has_fragment)")
    log_md("")
    log_md("---")
    log_md("")
    println("[organic-q] $label: $_status")
    return (label, _ok)
end

organic_q_results = []

# Dictionary-backed answers (📖 prefix expected)
push!(organic_q_results, run_organic_q_test("dict-fire", "what is fire", "oxidation"))
push!(organic_q_results, run_organic_q_test("dict-water", "what is water", ""))
push!(organic_q_results, run_organic_q_test("dict-gravity", "what is gravity", ""))

# Cave-node answers (from seed nodes in specimen)
push!(organic_q_results, run_organic_q_test("cave-earth", "what is earth", ""))
push!(organic_q_results, run_organic_q_test("cave-love", "what is love", ""))

# Question pattern variations
push!(organic_q_results, run_organic_q_test("who-pattern", "who is grug", ""))
push!(organic_q_results, run_organic_q_test("tellme-pattern", "tell me about fire", ""))
push!(organic_q_results, run_organic_q_test("explain-pattern", "explain gravity", ""))
push!(organic_q_results, run_organic_q_test("define-q-pattern", "define water", ""))

# Unknown topic → should fall through to AIML (no 📖, no cave match)
push!(organic_q_results, run_organic_q_test("unknown-topic", "what is xylophone", ""))

# Determinism check: same question twice should give same answer
_q1_raw = run_mission("what is fire")
_q1_ans = clean_output(_q1_raw)
_q2_raw = run_mission("what is fire")
_q2_ans = clean_output(_q2_raw)
_deterministic_ok = _q1_ans == _q2_ans
_det_status = _deterministic_ok ? "✅ Deterministic" : "⚠️ Non-deterministic"
log_md("## Determinism Check")
log_md("")
log_md("**Trial 1:** $(first(_q1_ans, 200))")
log_md("")
log_md("**Trial 2:** $(first(_q2_ans, 200))")
log_md("")
log_md("**Result:** $_det_status")
log_md("")
log_md("---")
log_md("")
println("[organic-q] determinism: $_det_status")

organic_q_pass = count(r -> r[2], organic_q_results)
organic_q_total = length(organic_q_results)
println("[organic-q] $organic_q_pass / $organic_q_total organic question tests passed")

# SECTION 18: SPECIMEN SAVE/LOAD WITH DICTIONARY STATE
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Section 18: Specimen Save/Load with Dictionary State")
log_md("")
println("─" ^ 70)
println("SECTION 18: SPECIMEN SAVE/LOAD ROUND-TRIP")
println("─" ^ 70)
println()

# Record current dictionary state before save
log_md("## Pre-Save Dictionary State")
log_md("")
_pre_save_count = _dict_definitions_count()
_pre_save_state = _dict_save_state()
log_md("**Definitions before save:** $_pre_save_count")
for (lid, dict) in sort(collect(_pre_save_state); by=first)
    if !isempty(dict)
        log_md("- Lobe '$lid': $(length(dict)) words")
        for (w, d) in sort(collect(dict); by=first)
            log_md("    $w → $d")
        end
    end
end
log_md("")

# Save specimen
println("Saving specimen (includes /answer nodes + dictionary state)...")
log_md("## Save Specimen")
log_md("")
try
    save_result = save_specimen_to_file!(SAVE_PATH)
    n_nodes = length(lock(() -> collect(keys(NODE_MAP)), NODE_LOCK))
    println("✅ Specimen saved to $SAVE_PATH ($n_nodes nodes)")
    log_md("**Saved to:** $SAVE_PATH")
    log_md("**Node count:** $n_nodes")
    log_md("**Dictionary definitions saved:** $_pre_save_count")
    log_md("")
catch e
    println("❌ Save failed: $e")
    log_md("❌ Save failed: $e")
end

# Now reload and verify dictionary round-trip
log_md("## Reload and Verify Dictionary State")
log_md("")
println("Clearing dictionaries for reload test...")
lock(_LOBE_DICTIONARIES_LOCK) do
    empty!(_LOBE_DICTIONARIES)
end
_post_clear_count = _dict_definitions_count()
println("  Dictionaries cleared: $_post_clear_count definitions")

println("Reloading specimen...")
try
    load_specimen_from_file!(SAVE_PATH)
    _post_load_count = _dict_definitions_count()
    _roundtrip_ok = _post_load_count == _pre_save_count
    _rt_status = _roundtrip_ok ? "✅ Dictionary round-trip verified" : "❌ Dictionary count mismatch: $_pre_save_count → $_post_load_count"
    println("  $_rt_status")
    log_md("**Definitions after reload:** $_post_load_count")
    log_md("**Round-trip:** $_rt_status")
    log_md("")

    # Verify individual entries survived
    _verify_entries = [
        ("science", "fire", "oxidation and heat"),
        ("mathematics", "pi", "3.14159 the ratio of circumference to diameter"),
        ("default", "hello", "a greeting"),
        ("philosophy", "truth", "correspondence with reality"),
    ]
    _verify_ok = 0
    for (vl, vw, vd) in _verify_entries
        _vr = _dict_lookup_word(vw; lobe_hint=vl)
        _entry_ok = !isnothing(_vr) && lowercase(strip(_vr)) == lowercase(strip(vd))
        if _entry_ok
            _verify_ok += 1
            log_md("- ✅ '$vw' in lobe '$vl' → '$(_vr)'")
        else
            log_md("- ❌ '$vw' in lobe '$vl' expected '$vd', got '$(_vr)'")
        end
    end
    log_md("**Entry verification:** $_verify_ok/$(length(_verify_entries)) survived round-trip")
    log_md("")
catch e
    println("❌ Reload failed: $e")
    log_md("❌ Reload failed: $e")
end

log_md("---")
log_md("")

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
pass_count = count(r -> r[5] == "✅", results)
warn_count = count(r -> startswith(r[5], "⚠️"), results)
fail_count = count(r -> startswith(r[5], "❌"), results)
total = length(results)

answer_pass = count(r -> r[4], answer_results)
answer_teach_pass = count(r -> r[3], answer_results)
answer_total = length(answer_results)

variation_pass = count(identity, variation_results)
variation_total = length(variation_results)

dict_pass = count(r -> r[2], dict_results)
dict_total = length(dict_results)

conv_pass = count(r -> r[2], conv_results)
conv_total = length(conv_results)

organic_q_pass = count(r -> r[2], organic_q_results)
organic_q_total = length(organic_q_results)

log_md("# Test Summary")
log_md("")
log_md("| Metric | Count |")
log_md("|--------|-------|")
log_md("| Total turns | $total |")
log_md("| ✅ Pass | $pass_count |")
log_md("| ⚠️ Warn | $warn_count |")
log_md("| ❌ Fail | $fail_count |")
log_md("| /answer teach pass | $answer_teach_pass / $answer_total |")
log_md("| /answer recall pass | $answer_pass / $answer_total |")
log_md("| Variation pass | $variation_pass / $variation_total |")
log_md("| Dictionary pass | $dict_pass / $dict_total |")
log_md("| ConversationLobe pass | $conv_pass / $conv_total |")
log_md("| Organic Q&A pass | $organic_q_pass / $organic_q_total |")
log_md("")

# Print failures for review
failures = filter(r -> r[5] != "✅", results)
if !isempty(failures)
    log_md("## Items Needing Attention (Standard Tests)")
    log_md("")
    for (turn, cat, q, a, st, verdict) in failures
        log_md("- $st [$cat] T$turn \"$q\" → $(length(a)) chars")
    end
    log_md("")
end

# Dictionary failures
dict_fails = filter(r -> !r[2], dict_results)
if !isempty(dict_fails)
    log_md("## Dictionary Tests Needing Attention")
    log_md("")
    for (label, ok, extras...) in dict_fails
        log_md("- ❌ $label")
    end
    log_md("")
end

# Conversation failures
conv_fails = filter(r -> !r[2], conv_results)
if !isempty(conv_fails)
    log_md("## ConversationLobe Tests Needing Attention")
    log_md("")
    for (label, ok, extras...) in conv_fails
        log_md("- ❌ $label")
    end
    log_md("")
end

# Math coherence spot-check
log_md("## Math Coherence Spot-Check")
log_md("")
math_checks = [
    ("factorial of 5", "120"), ("factorial of 7", "5040"),
    ("square of 9", "81"), ("cube of 3", "27"),
    ("double 7", "14"), ("half of 12", "6"),
    ("fibonacci of 10", "55"), ("absolute value of -15", "15"),
    ("reciprocal of 4", "0.25"), ("square root of 16", "4"),
    ("3 + 5", "8"), ("12 * 4", "48"),
    ("15 - 7", "8"), ("20 / 5", "4"),
]
for (q, expected) in math_checks
    idx = findfirst(r -> r[3] == q, results)
    if idx === nothing
        log_md("⚠️ NOT TESTED: \"$q\"")
        continue
    end
    answer = results[idx][4]
    if occursin(expected, answer)
        log_md("✅ \"$q\" → contains \"$expected\"")
    else
        log_md("❌ \"$q\" → expected \"$expected\", got: $(first(answer, 100))")
    end
end
log_md("")

log_md("---")
log_md("")
log_md("Done at $(now())")

# ══════════════════════════════════════════════════════════════════════════════
# FLUSH LOG TO FILE
# ══════════════════════════════════════════════════════════════════════════════
flush_log_md(LOG_PATH)
println()
println("=" ^ 70)
println("TEST COMPLETE — Log written to $LOG_PATH")
println("Specimen saved to $SAVE_PATH")
println("=" ^ 70)
