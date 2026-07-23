#!/usr/bin/env julia --project=.
# Quick multipart diagnostic test - v8.4

using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    # Strip ALL DEBUG TELEMETRY sections (multipart output may have multiple)
    # Strategy: split on the telemetry separator, keep only text before first separator
    # and between separator end (double newline) and next separator.
    parts = split(r, "--- DEBUG TELEMETRY")
    kept = String[]
    for (i, p) in enumerate(parts)
        if i == 1
            # First part is always pure entry text (before any telemetry)
            s = strip(string(p))
            !isempty(s) && push!(kept, s)
        else
            # Subsequent parts start with telemetry content.
            # Find the blank line that ends the telemetry block.
            lines = split(string(p), "\n")
            blank_idx = findfirst(isempty, lines)
            if blank_idx !== nothing && blank_idx < length(lines)
                # Content after blank line is the next entry's conversational text
                after_blank = strip(join(lines[blank_idx+1:end], "\n"))
                !isempty(after_blank) && push!(kept, after_blank)
            end
        end
    end
    result = join(kept, "\n\n")
    return strip(replace(result, r"\n{3,}" => "\n\n"))
end

ENV["GRUG_CHATTER_ENABLED"] = "false"

# Load the v8.4 post-test specimen
specimen_path = joinpath(@__DIR__, "grug_v84_post_test.specimen")
if isfile(specimen_path)
    load_specimen_from_file!(specimen_path)
    println("[TEST] Loaded specimen from $(specimen_path)")
else
    # Try the comprehensive full specimen
    specimen_path2 = joinpath(@__DIR__, "grug_comprehensive_full.specimen")
    if isfile(specimen_path2)
        load_specimen_from_file!(specimen_path2)
        println("[TEST] Loaded specimen from $(specimen_path2)")
    else
        println("[TEST] WARNING: No specimen found, using boot seeds only")
    end
end

# Test single multipart query
println("\n[TEST] ========================================")
println("[TEST] QUERY: what is fire and what is water")
println("[TEST] ========================================")
result = ask_grug("what is fire and what is water")
println("[TEST] RESULT LENGTH: ", length(result))
println("[TEST] CONTAINS FIRE: ", occursin("fire", lowercase(result)))
println("[TEST] CONTAINS WATER: ", occursin("water", lowercase(result)))
# Print each line of the result
for line in split(result, "\n")
    println("[RESULT] ", line)
end
println("[TEST] ========================================\n")
