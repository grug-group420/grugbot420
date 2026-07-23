include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug_raw(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    return read_last()
end

function ask_grug(text::String)::String
    r = ask_grug_raw(text)
    parts = split(r, "--- DEBUG TELEMETRY")
    kept = String[]
    for (i, p) in enumerate(parts)
        if i == 1
            s = strip(string(p))
            !isempty(s) && push!(kept, s)
        else
            lines = split(string(p), "\n")
            blank_idx = findfirst(isempty, lines)
            if blank_idx !== nothing && blank_idx < length(lines)
                after_blank = strip(join(lines[blank_idx+1:end], "\n"))
                !isempty(after_blank) && push!(kept, after_blank)
            end
        end
    end
    result = join(kept, "\n\n")
    return strip(replace(result, r"\n{3,}" => "\n\n"))
end

load_specimen_from_file!(joinpath(@__DIR__, "grug_comprehensive_full.specimen"))

# Run the first 49 turns quickly
queries = [
    "hello", "hey grug", "good morning",
    "what is fire", "tell me about water", "what is earth", "what is sky",
    "what is love", "what is fear", "what is courage",
    "what is river", "what is forest",
    "why does fire burn", "how does water flow",
    "what is gravity", "what is photosynthesis", "what is DNA",
    "why is the sky blue", "what is thermodynamics", "what is evolution",
    "what is an atom",
    "factorial of 5", "factorial of 7", "square of 9", "cube of 3",
    "double 7", "half of 12", "fibonacci of 10", "absolute value of -15",
    "reciprocal of 4", "square root of 16",
    "3 + 5", "12 * 4", "15 - 7", "20 / 5",
    "what is fire and what is water",
    "why does fire burn and why does water flow",
    "what is love and what is courage",
    "what is gravity and what is thermodynamics",
    "what is consciousness", "what is truth", "what is ethics", "what is knowledge",
    "what is time",
    "i feel sad", "i am afraid", "i feel happy",
    "how do you think", "who are you"
]

for (i, q) in enumerate(queries)
    ask_grug(q)
    if i % 10 == 0
        println("Turn $(i) done")
    end
end

# Now test Turn 50
println("\n=== Turn 50: what do you know ===")
raw = ask_grug_raw("what do you know")
clean = ask_grug("what do you know")
println("CLEAN: ", repr(clean[1:min(200, length(clean))]))
println("RAW first 300: ", repr(raw[1:min(300, length(raw))]))
