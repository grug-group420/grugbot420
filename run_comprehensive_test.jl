#!/usr/bin/env julia
# =============================================================================
# Comprehensive Grugbot Test — Internal State, NO stdout scraping
# =============================================================================

println("[BOOT] Loading Main.jl …")
include("src/Main.jl")
println("[BOOT] Main.jl loaded.")

println("[BOOT] Loading specimen …")
spec_path = "grug_comprehensive_full.specimen"
load_result = load_specimen_from_file!(spec_path)
println("[BOOT] Specimen loaded: ", load_result)

# ── Count action nodes in memory ──────────────────────────────────────────────
let
    global _action_count = 0
    global _action_details = String[]
    for (id, node) in NODE_MAP
        jd = node.json_data
        if haskey(jd, "action_callback")
            _action_count += 1
            push!(_action_details, "  $id | pattern=$(node.pattern) | action_callback=$(jd["action_callback"]) | drop_table=$(node.drop_table) | node_type=$(node.node_type)")
        end
    end
    println("[BOOT] Action callback nodes in memory: $_action_count")
    for d in _action_details
        println(d)
    end
end

# ── Save specimen (with action nodes) ─────────────────────────────────────────
save_path = "grug_with_actions.specimen"
save_result = save_specimen_to_file!(save_path)
println("[SAVE] Specimen saved: ", save_result)

# ── Helper: run process_mission and collect telemetry ─────────────────────────
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
            node_info = "pattern=$(node.pattern) | signal=$(node.signal) | strength=$(node.strength) | node_type=$(node.node_type)"
            jd = node.json_data
            if haskey(jd, "action_callback")
                node_info *= " | action_callback=$(jd["action_callback"])"
            end
            if !isempty(node.drop_table)
                node_info *= " | drop_table=$(node.drop_table)"
            end
        else
            node_info = "NODE NOT FOUND IN MAP"
        end
    end

    return (;
        label,
        input_text,
        output,
        fired_node,
        primary_act,
        confidence,
        voter_ids,
        node_info
    )
end

# ── Helper: format result to MD ───────────────────────────────────────────────
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

# ══════════════════════════════════════════════════════════════════════════════
# TEST CATEGORIES
# ══════════════════════════════════════════════════════════════════════════════

results = []

# ── Category 1: Regular Prompts ────────────────────────────────────────────────
println("\n[TEST] Category 1: Regular Prompts")

push!(results, test_mission("Regular-1: What is fire", "what is fire"))
println("  ✓ Regular-1 done")

push!(results, test_mission("Regular-2: Tell me about water", "tell me about water"))
println("  ✓ Regular-2 done")

push!(results, test_mission("Regular-3: How does breathing work", "how does breathing work"))
println("  ✓ Regular-3 done")

push!(results, test_mission("Regular-4: What is hunting", "what is hunting"))
println("  ✓ Regular-4 done")

# ── Category 2: Multipart Prompts ──────────────────────────────────────────────
println("\n[TEST] Category 2: Multipart Prompts")

push!(results, test_mission("Multipart-1: What is fire and how does it keep you warm", "what is fire and how does it keep you warm"))
println("  ✓ Multipart-1 done")

push!(results, test_mission("Multipart-2: How does water flow and where does it go", "how does water flow and where does it go"))
println("  ✓ Multipart-2 done")

push!(results, test_mission("Multipart-3: What is sleep and why is it important", "what is sleep and why is it important"))
println("  ✓ Multipart-3 done")

# ── Category 3: Math / Action Prompts ─────────────────────────────────────────
println("\n[TEST] Category 3: Math / Action Sigil Prompts")

push!(results, test_mission("Math-1: Factorial of 5", "factorial of 5"))
println("  ✓ Math-1 done")

push!(results, test_mission("Math-2: Factorial of 7", "factorial of 7"))
println("  ✓ Math-2 done")

push!(results, test_mission("Math-3: Square of 9", "square of 9"))
println("  ✓ Math-3 done")

push!(results, test_mission("Math-4: Cube of 3", "cube of 3"))
println("  ✓ Math-4 done")

push!(results, test_mission("Math-5: Double 7", "double 7"))
println("  ✓ Math-5 done")

push!(results, test_mission("Math-6: Half of 12", "half of 12"))
println("  ✓ Math-6 done")

push!(results, test_mission("Math-7: Fibonacci of 10", "fibonacci of 10"))
println("  ✓ Math-7 done")

push!(results, test_mission("Math-8: Absolute value of -15", "absolute value of -15"))
println("  ✓ Math-8 done")

push!(results, test_mission("Math-9: Reciprocal of 4", "reciprocal of 4"))
println("  ✓ Math-9 done")

push!(results, test_mission("Math-10: Square root of 16", "square root of 16"))
println("  ✓ Math-10 done")

push!(results, test_mission("Math-Arithmetic-11: 3 + 5", "3 + 5"))
println("  ✓ Math-11 done")

push!(results, test_mission("Math-Arithmetic-12: 12 * 4", "12 * 4"))
println("  ✓ Math-12 done")

# ── Category 4: Question / Answer ──────────────────────────────────────────────
println("\n[TEST] Category 4: Question / Answer")

push!(results, test_mission("QA-1: What makes rain fall from the sky", "what makes rain fall from the sky"))
println("  ✓ QA-1 done")

push!(results, test_mission("QA-2: How do animals survive winter", "how do animals survive winter"))
println("  ✓ QA-2 done")

push!(results, test_mission("QA-3: Why is the sky blue", "why is the sky blue"))
println("  ✓ QA-3 done")

push!(results, test_mission("QA-4: What causes thunder", "what causes thunder"))
println("  ✓ QA-4 done")

# ══════════════════════════════════════════════════════════════════════════════
# WRITE MD LOG
# ══════════════════════════════════════════════════════════════════════════════

log_lines = String[]

push!(log_lines, "# Grugbot Comprehensive Test Log")
push!(log_lines, "")
push!(log_lines, "Generated from internal state (`_LAST_VOICE_OUTPUT`, `NODE_MAP`, `_LAST_FIRED_NODE`, `_LAST_CONFIDENCE`, `LAST_VOTER_IDS`).")
push!(log_lines, "No stdout scraping. All telemetry from program internals.")
push!(log_lines, "")
push!(log_lines, "**Specimen:** `grug_with_actions.specimen` (saved after boot with action sigil nodes)")
push!(log_lines, "**Action callback nodes in memory:** $(_action_count)")
push!(log_lines, "")

# Action node inventory
push!(log_lines, "## Action Sigil Node Inventory")
push!(log_lines, "")
push!(log_lines, "| Node ID | Pattern | Action Callback | Drop Table |")
push!(log_lines, "|---|---|---|---|")
for (id, node) in NODE_MAP
    jd = node.json_data
    if haskey(jd, "action_callback")
        push!(log_lines, "| `$id` | `$(node.pattern)` | `$(jd["action_callback"])` | `$(node.drop_table)` |")
    end
end
push!(log_lines, "")

# Category sections
push!(log_lines, "## Category 1: Regular Prompts")
push!(log_lines, "")
for r in results
    if startswith(r.label, "Regular")
        push!(log_lines, result_to_md(r))
    end
end

push!(log_lines, "## Category 2: Multipart Prompts")
push!(log_lines, "")
for r in results
    if startswith(r.label, "Multipart")
        push!(log_lines, result_to_md(r))
    end
end

push!(log_lines, "## Category 3: Math / Action Sigil Prompts")
push!(log_lines, "")
for r in results
    if startswith(r.label, "Math")
        push!(log_lines, result_to_md(r))
    end
end

push!(log_lines, "## Category 4: Question / Answer")
push!(log_lines, "")
for r in results
    if startswith(r.label, "QA")
        push!(log_lines, result_to_md(r))
    end
end

# Summary
push!(log_lines, "## Summary")
push!(log_lines, "")
push!(log_lines, "| Category | Count |")
push!(log_lines, "|---|---|")
let
    reg_count  = count(r -> startswith(r.label, "Regular"), results)
    mp_count   = count(r -> startswith(r.label, "Multipart"), results)
    math_count = count(r -> startswith(r.label, "Math"), results)
    qa_count   = count(r -> startswith(r.label, "QA"), results)
    push!(log_lines, "| Regular | $reg_count |")
    push!(log_lines, "| Multipart | $mp_count |")
    push!(log_lines, "| Math / Action | $math_count |")
    push!(log_lines, "| Question / Answer | $qa_count |")
    push!(log_lines, "| **Total** | **$(length(results))** |")
end
push!(log_lines, "")

# Write log
log_path = "grug_comprehensive_test_log.md"

try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endlog_path, "w") do f
    println(f, join(log_lines, "\n"))
end
println("\n[DONE] Log written to $log_path")
println("[DONE] Specimen saved to $save_path")
println("[DONE] Total tests: $(length(results))")
