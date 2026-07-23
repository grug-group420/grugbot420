#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP,
    Thesaurus,
    NODE_MAP,
    Lobe

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

ENV["GRUG_CHATTER_ENABLED"] = "false"

println("Loading specimen...")
load_specimen_from_file!(joinpath(@__DIR__, "grug_comprehensive_full.specimen"))
println("Loaded.")

# Check thesaurus for key words in the answer content
for word in ["layered", "rock", "structures", "formed", "cyanobacteria", "shallow", "water",
             "luminous", "active", "galactic", "nuclei", "powered", "supermassive", "black", "holes",
             "sugar", "alcohol", "carbon", "dioxide", "yeast", "bacteria",
             "understanding", "sharing", "feelings", "person", "emotional", "connection",
             "fourteen", "line", "poem", "rhyme", "scheme", "meter"]
    n_syns = haskey(Thesaurus.SYNONYM_SEED_MAP, word) ? length(Thesaurus.SYNONYM_SEED_MAP[word]) : 0
    if n_syns > 0
        syns = collect(Thesaurus.SYNONYM_SEED_MAP[word])
        println("  $word: $n_syns synonyms → $syns")
    end
end

# Now test: teach then recall
question = "what is a stromatolite"
content = "stromatolites are layered rock structures formed by cyanobacteria in shallow water"
lobe = "science"
mode = "explain"

println("\n=== Step 1: Ask before teaching ===")
r1 = ask_grug(question)
println("Response: $r1")

# Teach
lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = question; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

anchors = ["stromatolite"]
ad = _base_answer_data(mode; pending_ask_text=question, answer_content=content)
ad["noun_anchors"] = anchors
nid, lt = _create_answer_node(anchors[1], "$(mode)^1", ad, lobe)

println("\n=== Node created: $nid $lt ===")
println("Node json_data keys: $(keys(NODE_MAP[nid].json_data))")
println("growth_source: $(get(NODE_MAP[nid].json_data, "growth_source", "MISSING"))")
println("system_prompt: $(get(NODE_MAP[nid].json_data, "system_prompt", "MISSING"))")
println("answer_mode: $(get(NODE_MAP[nid].json_data, "answer_mode", "MISSING"))")

# Now recall multiple times
println("\n=== Step 2: Recall after teaching (3 times) ===")
for i in 1:3
    r = ask_grug(question)
    println("Recall $i: $r")
    # Check if content appears verbatim
    if occursin(content, r)
        println("  ⚠️ VERBATIM CONTENT FOUND in output")
    end
end
