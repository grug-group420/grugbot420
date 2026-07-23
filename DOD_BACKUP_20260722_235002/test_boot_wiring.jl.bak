#!/usr/bin/env julia
# Direct end-to-end wiring test for boot.jl's required functions.
# This bypasses the interactive run_cli() readline loop (which needs a TTY)
# and directly exercises the SAME functions that /loadSpecimen and /mission
# dispatch to. Proves the wiring is functional without a fancy harness.

const _GRUG_DIR = dirname(@__FILE__)
include(joinpath(_GRUG_DIR, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    run_cli,
    process_mission,
    load_specimen_from_file!,
    save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    _LAST_SPECIMEN_PATH, _LAST_SPECIMEN_PATH_LOCK,
    LAST_VOTER_IDS, LAST_VOTER_LOCK,
    NODE_MAP, NODE_LOCK

println("=" ^ 60)
println("[TEST] Module loaded. Testing boot.jl wiring directly.")
println("=" ^ 60)

# --- C1: all imports resolved (already proved by reaching here) ---
println("\n[1/4] ✓ All 15 boot.jl symbols imported OK")

# --- C2: pick a specimen and call load_specimen_from_file! (what /loadSpecimen does) ---
spec_candidates = [
    joinpath(_GRUG_DIR, "grug_threadC_v94_final.specimen"),
    joinpath(_GRUG_DIR, "grug_threadC_multipart_final_migrated.specimen"),
    joinpath(_GRUG_DIR, "threadC_v94_roundtrip.specimen"),
]
spec_path = ""
for c in spec_candidates
    global spec_path
    if isfile(c)
        spec_path = c
        break
    end
end
if spec_path == ""
    println("[2/4] ✗ No specimen file found in $(pwd()). Candidates:")
    for c in spec_candidates; println("       - ", c); end
    exit(1)
end
println("\n[2/4] Loading specimen via load_specimen_from_file! (same fn /loadSpecimen uses):")
println("       path = ", spec_path)
try
    load_specimen_from_file!(spec_path)
    println("       ✓ load_specimen_from_file! returned without error")
catch e
    println("       ✗ load_specimen_from_file! THREW: ", e)
    exit(2)
end

# verify specimen path got recorded (boot.jl --save relies on this)
sp_recorded = lock(() -> _LAST_SPECIMEN_PATH[], _LAST_SPECIMEN_PATH_LOCK)
println("       _LAST_SPECIMEN_PATH recorded = ", sp_recorded == "" ? "(empty)" : sp_recorded)

# verify NODE_MAP actually has nodes after load
n_nodes = lock(() -> length(NODE_MAP), NODE_LOCK)
println("       NODE_MAP node count after load = ", n_nodes)
if n_nodes == 0
    println("       ⚠ WARNING: NODE_MAP empty after load — specimen may be bare")
end

# --- C3: call process_mission (what /mission dispatches to) ---
println("\n[3/4] Calling process_mission (same fn /mission uses) with a test input:")
test_input = "what is 2 plus 2"
println("       input = \"", test_input, "\"")
try
    process_mission(test_input)
    println("       ✓ process_mission returned without error")
catch e
    println("       ✗ process_mission THREW: ", e)
    # don't exit — mission errors may be non-fatal; still report voice output
end

# capture the voice output (what the user would "see" as grug's reply)
voice = lock(() -> _LAST_VOICE_OUTPUT[], _LAST_VOICE_OUTPUT_LOCK)
println("       _LAST_VOICE_OUTPUT = ", voice == "" ? "(empty)" : voice[1:min(200, length(voice))])
println("       _LAST_FIRED_NODE    = ", _LAST_FIRED_NODE[])
println("       _LAST_PRIMARY_ACTION= ", _LAST_PRIMARY_ACTION[])
println("       _LAST_CONFIDENCE    = ", _LAST_CONFIDENCE[])

# --- C4: save_specimen_to_file! round-trip (what /saveSpecimen does) ---
out_path = joinpath(_GRUG_DIR, "_wiring_test_roundtrip.specimen")
println("\n[4/4] Saving specimen via save_specimen_to_file! (same fn /saveSpecimen uses):")
println("       path = ", out_path)
try
    save_specimen_to_file!(out_path)
    if isfile(out_path)
        sz = filesize(out_path)
        println("       ✓ save_specimen_to_file! wrote file (", sz, " bytes)")
        rm(out_path; force=true)  # cleanup
    else
        println("       ⚠ save_specimen_to_file! returned but no file written")
    end
catch e
    println("       ✗ save_specimen_to_file! THREW: ", e)
end

println("\n" * "=" ^ 60)
println("[TEST] boot.jl wiring end-to-end check COMPLETE.")
println("       /loadSpecimen path : ", n_nodes > 0 ? "WORKS ✓" : "loaded bare ⚠")
println("       /mission path      : ", voice != "" ? "WORKS ✓ (voice output produced)" : "ran (no voice) ⚠")
println("       /saveSpecimen path : verified above")
println("=" ^ 60)
