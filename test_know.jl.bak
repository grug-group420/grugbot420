include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

load_specimen_from_file!(joinpath(@__DIR__, "grug_v86_post_test.specimen"))

lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
try; process_mission("what do you know"); catch e; @warn "error: $e"; end
r = read_last()
println("RAW RESPONSE for what do you know:")
println(repr(r[1:min(800, length(r))]))
println("---")
println("Raw length: ", length(r))
