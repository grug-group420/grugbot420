#!/usr/bin/env julia --project=.
# Quick diagnostic: test sonnet recall with raw output capture

include("src/GrugBot420.jl")
using .GrugBot420
import .GrugBot420: process_mission, load_specimen_from_file!, save_specimen_to_file!
import .GrugBot420: _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK
import .GrugBot420: _base_answer_data, _create_answer_node, NODE_MAP, NODE_LOCK

# Load specimen
load_specimen_from_file!("grug_comprehensive_full.specimen")

# Create sonnet hippocampal answer node directly
println("=== Creating sonnet hippocampal answer node ===")
ad = _base_answer_data("define"; answer_content="a sonnet is a fourteen line poem with a specific rhyme scheme and meter")
ad["noun_anchors"] = ["sonnet", "poem", "rhyme"]
nid, lt = _create_answer_node("sonnet", "define^1", ad, "language")
println("Node: $nid in $lt")

# Check if there's a graved duplicate
println("\n=== Checking for duplicate sonnet nodes ===")
lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        if lowercase(strip(node.pattern)) == "sonnet"
            jd = node.json_data
            gs = get(jd, "growth_source", get(jd, "autogrowth_source", "?"))
            println("  $id: pattern=$(node.pattern), strength=$(node.strength), is_grave=$(node.is_grave), source=$gs")
        end
    end
end

clear_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end

# Now query and capture RAW output
println("\n=== Querying 'what is a sonnet' ===")
clear_last()
process_mission("what is a sonnet")
raw = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
println("RAW OUTPUT ($(length(raw)) chars):")
println(repr(raw))
println("\n=== END RAW OUTPUT ===")

# Check the stripped version
parts = split(raw, "--- DEBUG TELEMETRY")
println("\nTELEMETRY split parts: $(length(parts))")
for (i, p) in enumerate(parts)
    println("--- PART $i ($(length(string(p))) chars) ---")
    println(repr(string(p)[1:min(200, length(string(p)))]))
end
