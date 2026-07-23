#!/usr/bin/env julia
using Dates, JSON, Base.Threads
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK

read_voice() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

# Load specimen
load_specimen_from_file!("/workspace/test_v9_temp.specimen")

# Test 1: "what is 5+5"
println("=" ^ 60)
println("TEST 1: what is 5+5")
println("=" ^ 60)
r1 = process_mission("what is 5+5")
v1 = read_voice()
println("VOICE: $(v1[1:min(500, length(v1))])")
println()

# Test 2: "what is 5+5 and what is love"
println("=" ^ 60)
println("TEST 2: what is 5+5 and what is love")
println("=" ^ 60)
r2 = process_mission("what is 5+5 and what is love")
v2 = read_voice()
println("VOICE: $(v2[1:min(500, length(v2))])")
println()

# Test 3: "what is 5 + 5"
println("=" ^ 60)
println("TEST 3: what is 5 + 5")
println("=" ^ 60)
r3 = process_mission("what is 5 + 5")
v3 = read_voice()
println("VOICE: $(v3[1:min(500, length(v3))])")
println()

# Test 4: "what is love"
println("=" ^ 60)
println("TEST 4: what is love")
println("=" ^ 60)
r4 = process_mission("what is love")
v4 = read_voice()
println("VOICE: $(v4[1:min(500, length(v4))])")
println()

# Test 5: "what is 7*3"
println("=" ^ 60)
println("TEST 5: what is 7*3")
println("=" ^ 60)
r5 = process_mission("what is 7*3")
v5 = read_voice()
println("VOICE: $(v5[1:min(500, length(v5))])")
println()

# Test 6: "what is 12 - 4 and why is grass green"
println("=" ^ 60)
println("TEST 6: what is 12 - 4 and why is grass green")
println("=" ^ 60)
r6 = process_mission("what is 12 - 4 and why is grass green")
v6 = read_voice()
println("VOICE: $(v6[1:min(500, length(v6))])")

println("\nDone.")
