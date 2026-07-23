#!/usr/bin/env julia
# Rerun QA tests with specimen-matching prompts, capture internal state

println("[BOOT] Loading Main.jl …")
include("src/Main.jl")
println("[BOOT] Main.jl loaded.")

println("[BOOT] Loading specimen …")
load_specimen_from_file!("grug_comprehensive_full.specimen")
println("[BOOT] Specimen loaded.")

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
    # Also trim at "(Grug also think these infos maybe important)"
    idx2 = findfirst("(Grug also think these infos maybe important)", clean)
    if idx2 !== nothing
        clean = clean[1:first(idx2)-1]
    end
    clean = strip(clean)
    # Remove trailing semicolons
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

# QA tests with topics the specimen has nodes for
qa_tests = [
    ("QA-1: What is gravity", "what is gravity"),
    ("QA-2: How does photosynthesis work", "how does photosynthesis work"),
    ("QA-3: What is DNA", "what is DNA"),
    ("QA-4: Why is the sky blue", "why is the sky blue"),
    ("QA-5: What is consciousness", "what is consciousness"),
    ("QA-6: What is thermodynamics", "what is thermodynamics"),
]

qa_results = []
for (label, input_text) in qa_tests
    println("[QA] Running: $label")
    push!(qa_results, test_mission(label, input_text))
    println("[QA] Done: $label")
end

# Write just the QA section to a temp file
qa_md = String[]
push!(qa_md, "## Category 4: Question / Answer")
push!(qa_md, "")
for r in qa_results
    push!(qa_md, result_to_md(r))
end
push!(qa_md, "")

open("qa_section_tmp.md", "w") do f
    println(f, join(qa_md, "\n"))
end
println("[DONE] QA section written to qa_section_tmp.md")
