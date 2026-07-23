#!/usr/bin/env julia
# =============================================================================
# Teach-and-Reask Test — Shows the full strain → ask → /answer → recall loop
# =============================================================================
# This tests that when Grug doesn't know something, it asks. When you teach
# it with /answer, it learns. When you ask again, it fires from the new node.
# =============================================================================

println("[BOOT] Loading Main.jl …")
include("src/Main.jl")
println("[BOOT] Main.jl loaded.")

println("[BOOT] Loading specimen …")
load_specimen_from_file!("grug_comprehensive_full.specimen")
println("[BOOT] Specimen loaded.")

# ── Helper: run process_mission and collect telemetry ─────────────────────
function test_mission(label::String, input_text::String)
    process_mission(input_text)

    output       = _LAST_VOICE_OUTPUT[]
    fired_node   = _LAST_FIRED_NODE[]
    primary_act  = _LAST_PRIMARY_ACTION[]
    confidence   = _LAST_CONFIDENCE[]
    voter_ids    = lock(() -> copy(LAST_VOTER_IDS), LAST_VOTER_LOCK)

    node_info = ""
    if !isempty(fired_node)
        node = get(NODE_MAP, fired_node, nothing)
        if node !== nothing
            node_info = "pattern=$(node.pattern) | node_type=$(node.node_type)"
            jd = node.json_data
            if haskey(jd, "action_callback")
                node_info *= " | action_callback=$(jd["action_callback"])"
            end
        end
    end

    # Split output at DEBUG TELEMETRY — keep only clean part
    clean = output
    idx = findfirst("--- DEBUG TELEMETRY", output)
    if idx !== nothing
        clean = output[1:first(idx)-1]
    end
    idx2 = findfirst("(Grug also think these infos maybe important)", clean)
    if idx2 !== nothing
        clean = clean[1:first(idx2)-1]
    end
    clean = strip(clean)
    if endswith(clean, ";")
        clean = clean[1:end-1]
    end
    clean = strip(clean)

    return (;
        label,
        input_text,
        output=clean,
        fired_node,
        primary_act,
        confidence,
        voter_ids,
        node_info
    )
end

# ── Helper: format result to MD ───────────────────────────────────────────
function result_to_md(r)
    lines = String[]
    push!(lines, "### $(r.label)")
    push!(lines, "")
    push!(lines, "**Input:** `$(r.input_text)`")
    push!(lines, "")
    push!(lines, "**Output:** $(r.output)")
    push!(lines, "")
    push!(lines, "| Telemetry | Value |")
    push!(lines, "|---|---|")
    push!(lines, "| Fired Node | `$(r.fired_node)` |")
    push!(lines, "| Confidence | $(round(r.confidence; digits=3)) |")
    push!(lines, "| Primary Action | `$(r.primary_act)` |")
    push!(lines, "| Voter Count | $(length(r.voter_ids)) |")
    voter_preview = length(r.voter_ids) > 5 ? join(r.voter_ids[1:5], ", ") * " …" : join(r.voter_ids, ", ")
    push!(lines, "| Voter IDs | `$(voter_preview)` |")
    if !isempty(r.node_info)
        push!(lines, "| Node Info | $(r.node_info) |")
    end
    push!(lines, "")
    return join(lines, "\n")
end

# ═══════════════════════════════════════════════════════════════════════════
# TEACH-AND-REASK SCENARIOS
# ═══════════════════════════════════════════════════════════════════════════
# Each scenario:
#   1. Ask about a topic the specimen has NO nodes for → should get "ask" response
#   2. Teach grug with /answer → creates a new node
#   3. Ask again → should fire from the new node with knowledge
# ═══════════════════════════════════════════════════════════════════════════

scenarios = [
    (topic="breathing", question="how does breathing work",
     answer_cmd="/answer :explain breathing draws oxygen into the lungs and expels carbon dioxide",
     teach_label="breathing"),
    (topic="hunting", question="what is hunting",
     answer_cmd="/answer :reason hunting is the pursuit and capture of prey for food and survival",
     teach_label="hunting"),
    (topic="cooking", question="what is cooking",
     answer_cmd="/answer :explain cooking applies heat to food to make it safe to eat and easier to digest",
     teach_label="cooking"),
    (topic="music", question="what is music",
     answer_cmd="/answer :define music is organized sound that expresses emotion and rhythm",
     teach_label="music"),
]

results = []

for (i, s) in enumerate(scenarios)
    println("\n[SCENARIO $(i)] Topic: $(s.topic)")
    println("  Step 1: Ask before teaching …")

    # Step 1: Ask — should get "I don't know" response
    r1 = test_mission("Teach-$(i)A [Ask]: $(s.question)", s.question)
    push!(results, r1)
    println("  ✓ Step 1 done. Action=$(r1.primary_act), Confidence=$(round(r1.confidence; digits=3))")

    # Step 2: Teach via /answer — pipe through process_mission
    println("  Step 2: Teaching with /answer …")
    process_mission(s.answer_cmd)
    # After /answer, check what happened
    teach_output = _LAST_VOICE_OUTPUT[]
    teach_fired = _LAST_FIRED_NODE[]
    teach_action = _LAST_PRIMARY_ACTION[]
    teach_conf = _LAST_CONFIDENCE[]
    teach_voters = lock(() -> copy(LAST_VOTER_IDS), LAST_VOTER_LOCK)

    # Clean teach output
    teach_clean = teach_output
    idx_dt = findfirst("--- DEBUG TELEMETRY", teach_output)
    if idx_dt !== nothing
        teach_clean = teach_output[1:first(idx_dt)-1]
    end
    teach_clean = strip(teach_clean)

    push!(results, (;
        label="Teach-$(i)B [Teach]: /answer for $(s.topic)",
        input_text=s.answer_cmd,
        output=teach_clean,
        fired_node=teach_fired,
        primary_act=teach_action,
        confidence=teach_conf,
        voter_ids=teach_voters,
        node_info=haskey(NODE_MAP, teach_fired) ? "pattern=$(NODE_MAP[teach_fired].pattern)" : ""
    ))
    println("  ✓ Step 2 done. Taught $(s.topic). Output preview: $(first(teach_clean, 80))…")

    # Step 3: Ask again — should fire from the new node
    println("  Step 3: Re-asking after teaching …")
    r3 = test_mission("Teach-$(i)C [Re-ask]: $(s.question)", s.question)
    push!(results, r3)
    println("  ✓ Step 3 done. Action=$(r3.primary_act), Confidence=$(round(r3.confidence; digits=3))")

    # Verify the loop worked
    if r1.primary_act == "ask" && r3.primary_act != "ask"
        println("  ✅ LOOP OK: '$(s.topic)' went from ask → taught → recall")
    elseif r1.primary_act != "ask"
        println("  ⚠️  '$(s.topic)' already known before teaching (action=$(r1.primary_act))")
    else
        println("  ❓ '$(s.topic)' still asking after teaching (action=$(r3.primary_act))")
    end
end

# ═══════════════════════════════════════════════════════════════════════════
# WRITE MD LOG
# ═══════════════════════════════════════════════════════════════════════════

log_lines = String[]

push!(log_lines, "# Grugbot Teach-and-Reask Test Log")
push!(log_lines, "")
push!(log_lines, "Tests the full strain → ask → /answer → recall loop.")
push!(log_lines, "Each scenario: (1) ask about unknown topic → grug asks for info, (2) teach with /answer → node created, (3) ask again → grug fires from new node.")
push!(log_lines, "")
push!(log_lines, "All data from internal state (`_LAST_VOICE_OUTPUT`, `NODE_MAP`, `_LAST_FIRED_NODE`, `_LAST_CONFIDENCE`, `LAST_VOTER_IDS`). No stdout scraping.")
push!(log_lines, "")
push!(log_lines, "**Specimen:** `grug_comprehensive_full.specimen`")
push!(log_lines, "")

for r in results
    push!(log_lines, result_to_md(r))
end

# Summary
push!(log_lines, "## Summary")
push!(log_lines, "")
push!(log_lines, "| Scenario | Topic | Before Teach | After Teach |")
push!(log_lines, "|---|---|---|---|")

let
    i = 0
    for s in scenarios
        i += 1
        before = results[i*3 - 2]  # Step A
        after  = results[i*3]      # Step C
        push!(log_lines, "| $(i) | $(s.topic) | action=$(before.primary_act), conf=$(round(before.confidence; digits=3)) | action=$(after.primary_act), conf=$(round(after.confidence; digits=3)) |")
    end
end

push!(log_lines, "")
push!(log_lines, "| Total tests | Count |")
push!(log_lines, "|---|---|")
push!(log_lines, "| Teach-and-Reask scenarios | $(length(scenarios)) |")
push!(log_lines, "| Total result entries | $(length(results)) |")
push!(log_lines, "")

# Write log
log_path = "grug_teach_reask_log.md"
open(log_path, "w") do f
    println(f, join(log_lines, "\n"))
end
println("\n[DONE] Log written to $log_path")
println("[DONE] Total scenarios: $(length(scenarios)), Total result entries: $(length(results))")
