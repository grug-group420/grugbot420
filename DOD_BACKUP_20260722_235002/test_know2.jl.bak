include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

# Load fresh specimen (not the post-test one that has test debris)
load_specimen_from_file!(joinpath(@__DIR__, "grug_comprehensive_full.specimen"))

lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
try; process_mission("what do you know"); catch e; @warn "error: $e"; end
r = read_last()

# Show the raw output with visible control chars
println("=== RAW OUTPUT ===")
for (i, line) in enumerate(split(r, "\n"))
    println(i, ": ", repr(line))
    i > 15 && break
end
println("===")
