#!/usr/bin/env julia --project=.
# Debug test for /answer sonnet recall issue

include("src/GrugBot420.jl")
using .GrugBot420
import .GrugBot420: process_mission, load_specimen_from_file!, save_specimen_to_file!

# Load the specimen
load_specimen_from_file!("grug_comprehensive_full.specimen")

# Step 1: Teach the sonnet via /answer
println("\n=== STEP 1: Teach sonnet ===")
r1 = process_mission("/answer @language :define a sonnet is a fourteen line poem with a specific rhyme scheme and meter")
println("Teach result: ", r1)

# Step 2: Ask about sonnet multiple times to see all variations
println("\n=== STEP 2: Recall sonnet (5 attempts) ===")
for i in 1:5
    r = process_mission("what is a sonnet")
    content = split(r, "--- DEBUG TELEMETRY")[1]
    content = replace(content, r"\n\s*\n" => "\n")
    content = strip(content)
    println("\n--- Trial $i ---")
    println(content)
end
