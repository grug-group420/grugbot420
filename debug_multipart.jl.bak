# Debug multipart decomposition
include("src/Main.jl")

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_v740.specimen")
load_specimen_from_file!(SPEC_PATH)
ENV["GRUG_CHATTER_ENABLED"] = "false"

# Test decomposition directly
test_inputs = [
    "what is fire and what is water",
    "why does fire burn and why does water flow",
    "what is love and what is courage",
    "how does grug think and what is sky",
]

for inp in test_inputs
    println("\n=== INPUT: \"$inp\" ===")
    sub_subjects = try
        InputDecomposer.decompose_input(inp)
    catch e
        @warn "Decomposition failed: $e"
        [InputDecomposer.DecomposedSubSubject(inp, "", :singleton, 1)]
    end
    println("  Sub-subjects: $(length(sub_subjects))")
    for (i, sub) in enumerate(sub_subjects)
        println("    [$i] text=\"$(sub.text)\" group=\"$(sub.multipart_group)\" role=$(sub.role)")
    end
end
