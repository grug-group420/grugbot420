# Test the TELEMETRY stripping logic with various input patterns

function strip_telemetry(r::String)::String
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

# Test 1: Normal output with TELEMETRY at end
test1 = "Here is the picture: Grug speak of fire.\n--- DEBUG TELEMETRY (orchestration internals, not for speech) ---\nMission: 'what is fire'\nPrimary Action: explain\n========================================="
r1 = strip_telemetry(test1)
println("Test 1: ", repr(r1))

# Test 2: Output with blank line between sections
test2 = "Here is the picture: Grug speak of fire.\n--- DEBUG TELEMETRY (orchestration internals, not for speech) ---\nMission: 'what is fire'\n\nHere is more content."
r2 = strip_telemetry(test2)
println("Test 2: ", repr(r2))

# Test 3: Output with ONLY TELEMETRY (no conversational text)
test3 = "\n--- DEBUG TELEMETRY (orchestration internals, not for speech) ---\nMission: 'what do you know'\nPrimary Action: explain\n========================================="
r3 = strip_telemetry(test3)
println("Test 3: ", repr(r3))

# Test 4: Real output from "what do you know" with identity node
test4 = "To acknowledge what matters here: Grug live in cave. Grug think and feel and learn. Grug is friend. You are talking to Grug and Grug is listening. Grug turn to identity.\n--- DEBUG TELEMETRY (orchestration internals, not for speech) ---\nMission: 'what do you know'\nPrimary Action: acknowledge  (conf=0.87, certainty=UNSURE)\nSure Actions: [acknowledge, explain]\nUnsure Actions (Coinflip Side-Features): [None]\nConstraints: [be honest, be humble]\nWinning Node: node_17\nLobe Context: [metacognition (21/0 active (whom | you | &doAction &rest))]\nUser Triples: None\nNode Triples: (grug, is, friend), (you, talk_to, grug)\nAnti-Match Detected: false\nEvaluated Rules (shaping): [explain \"Grug sheds light\"]\nArithmetic: no math bindings this cycle\nTied Alternatives (not selected):\n  🧪 node_256 | action=explain | conf=0.87 | relations=(knowing, requires, learning)\nAIML Memory Bank:\nDeep Memory (Pinned): No pinned rocks\nFresh Memory [threshold=0.75 eligible=6] (Recent): [User]: what is gravity (intensity=1.12)\nMemory-Pull Policy: pull_fresh=false\nLobe Curve (∫base × top² = score):\n  👑 metacognition: base=0.867 × top=0.867 = 0.6992 [hard_votes=2]\nTime Orientation: none\n========================================="
r4 = strip_telemetry(test4)
println("Test 4: ", repr(r4))

# Test 5: UNSURE output that might be empty claim
test5 = " \n--- DEBUG TELEMETRY (orchestration internals, not for speech) ---\nMission: 'what do you know'"
r5 = strip_telemetry(test5)
println("Test 5: ", repr(r5))
