#!/usr/bin/env julia
# run_v736_test.jl — Load GrugBot420 engine, load specimen, fire missions

include("src/GrugBot420.jl")
using .GrugBot420

# Load specimen
println("Loading specimen...")
specimen_result = try
    GrugBot420.load_specimen_from_file!("grug_comprehensive_v736.specimen")
catch e
    "ERROR loading specimen: $e"
end
println(specimen_result)
println()

# Now run test missions
const TEST_MISSIONS = [
    "hello there",
    "who are you",
    "say rock 3 times",
    "repeat hello 2 times",
    "count from 1 to 5",
    "check the date",
    "tell the time",
    "remind me about the weather",
    "announce news",
    "recall ages ago",
    "confirm the time",
    "compare 10",
    "compare 2",
    "verify yes",
    "verify no",
    "search recent and today",
    "say hello 3 times",
    "maybe say hello 3 times",
    "don't say hello 3 times",
    "explain fire and describe water",
    "say hello 3 times and count from 1 to 3",
    "tell the time and check the date",
    "calculate 5 plus 3",
    "maybe calculate 7 minus 2",
    "don't calculate 10 times 4",
    "what is the chemical reaction",
    "perhaps explain the chemical bonds",
    "i feel very sad today",
    "maybe i feel a bit worried",
    "don't worry about my feelings",
    "calculate 3 times 4",
    "compute 8 divided by 2",
    "tell me about recent",
    "tell me about today",
    "search recent + today",
]

println("RUNNING $(length(TEST_MISSIONS)) TEST MISSIONS")

const MISSION_RESULTS = []

for (i, mission) in enumerate(TEST_MISSIONS)
    println()
    println("=== MISSION $i ===")
    println("INPUT: \"$(mission)\"")
    
    result = try
        GrugBot420.process_mission(mission)
    catch e
        "ERROR: $e"
    end
    
    if isnothing(result)
        println("STATUS: SILENT")
        push!(MISSION_RESULTS, (mission, "SILENT", ""))
    else
        println("STATUS: FIRED")
        println("OUTPUT:")
        println(result)
        push!(MISSION_RESULTS, (mission, "FIRED", result))
    end
    flush(stdout)
end

println()
println("ALL MISSIONS COMPLETE")

# Write parsed results
open("v736_parsed_results.txt", "w") do f
    for (i, (mission, status, output)) in enumerate(MISSION_RESULTS)
        println(f, "=== MISSION $i ===")
        println(f, "INPUT: $mission")
        println(f, "STATUS: $status")
        if status == "FIRED"
            println(f, "OUTPUT:")
            println(f, output)
        end
        println(f)
    end
end
println("Results saved to v736_parsed_results.txt")
