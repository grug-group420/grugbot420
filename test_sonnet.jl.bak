include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

load_specimen_from_file!(joinpath(@__DIR__, "grug_comprehensive_full.specimen"))

# Teach sonnet
question = "what is a sonnet"
content = "a sonnet is a fourteen line poem with a specific rhyme scheme and meter"
anchors = ["sonnet", "poem", "rhyme"]
mode = "define"
lobe = "language"

lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = question; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

pattern_text = replace(lowercase(question), r"^what is (a |the )?" => "")
ad = _base_answer_data(mode; pending_ask_text=question, answer_content=content)
ad["noun_anchors"] = anchors
nid, lt = _create_answer_node(pattern_text, "$(mode)^1", ad, lobe)
println("Node created: ", nid, " in lobe: ", lt)

# Re-ask
lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
try; process_mission(question); catch e; @warn "error: $e"; end
r = read_last()
println("=== RAW RECALL ===")
for (i, line) in enumerate(split(r, "\n"))
    println(i, ": ", repr(line))
    i > 25 && break
end
