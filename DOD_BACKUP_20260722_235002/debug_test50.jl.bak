include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug_debug(text::String)::Tuple{String, String}
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    # Strip
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
    clean = strip(replace(result, r"\n{3,}" => "\n\n"))
    return (clean, r)
end

load_specimen_from_file!(joinpath(@__DIR__, "grug_comprehensive_full.specimen"))

# Run ALL test turns exactly as the comprehensive test does
queries = String[
    "hello", "hey grug", "good morning",          # 1-3 greeting
    "what is fire", "tell me about water", "what is earth", "what is sky",  # 4-7 knowledge
    "what is love", "what is fear", "what is courage",  # 8-10 knowledge
    "what is river", "what is forest",              # 11-12 knowledge
    "why does fire burn", "how does water flow",    # 13-14 knowledge
    "what is gravity", "what is photosynthesis", "what is DNA",  # 15-17 science
    "why is the sky blue", "what is thermodynamics", "what is evolution",  # 18-20 science
    "what is an atom",                              # 21 science
    "factorial of 5", "factorial of 7", "square of 9", "cube of 3",  # 22-25 math
    "double 7", "half of 12", "fibonacci of 10", "absolute value of -15",  # 26-29 math
    "reciprocal of 4", "square root of 16",        # 30-31 math
    "3 + 5", "12 * 4", "15 - 7", "20 / 5",        # 32-35 math
    "what is fire and what is water",               # 36 multipart
    "why does fire burn and why does water flow",   # 37 multipart
    "what is love and what is courage",             # 38 multipart
    "what is gravity and what is thermodynamics",   # 39 multipart
    "what is consciousness", "what is truth", "what is ethics", "what is knowledge",  # 40-43 philosophy
    "what is time",                                 # 44 philosophy
    "i feel sad", "i am afraid", "i feel happy",   # 45-47 emotion
    "how do you think", "who are you",              # 48-49 metacognition
]

for (i, q) in enumerate(queries)
    (clean, raw) = ask_grug_debug(q)
    if i % 10 == 0 || isempty(clean)
        println("Turn $i: $(isempty(clean) ? "EMPTY!" : "OK") q=$(repr(q)) clean_len=$(length(clean))")
    end
end

# Now the critical one
println("\n=== Turn 50: what do you know ===")
(clean50, raw50) = ask_grug_debug("what do you know")
println("Clean length: ", length(clean50))
println("Raw length: ", length(raw50))
if isempty(clean50)
    println("RAW first 500 chars:")
    println(repr(raw50[1:min(500, length(raw50))]))
end
if !isempty(clean50)
    println("CLEAN: ", clean50[1:min(200, length(clean50))])
end
