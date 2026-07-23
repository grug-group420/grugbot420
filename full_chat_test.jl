#!/usr/bin/env julia
# full_chat_test.jl — Comprehensive chat test with all 25 node patterns
# Captures AIML scaffold output (natural language) by spawning a child
# Julia process that runs all 25 missions sequentially. The child process
# stdout is captured and parsed for the 🤖 AIML markers.

# Define all 25 test inputs
test_inputs = [
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
    "derivative",                        # node_math_001
    "integral",                          # node_math_002
    "pythagorean theorem",               # node_math_003
    "what is consciousness",             # node_phil_001
    "meaning of life",                   # node_phil_002
    "free will",                         # node_phil_003
    "danger",                            # node_surv_001
    "hide and seek",                     # node_surv_002
    "fight back",                        # node_surv_003
    "i feel sad",                        # node_emp_001
    "i feel anxious",                    # node_emp_002
    "validate my feelings",              # node_emp_003
    "write a poem",                      # node_crea_001
    "tell me a story",                   # node_crea_002
    "imagine",                           # node_crea_003
    "hello",                             # node_greet_001
    "what time is it",                   # node_time_001
    "what happened before",              # node_time_002
    "ignore mathematics",                # node_anti_001
    "stop empathy",                      # node_anti_002
    "sunset image",                      # node_img_001
    "watch out",                         # node_warn_001
    "why does",                          # node_ask_001
    "obsolete test pattern",             # node_grave_001
    "sacred knowledge",                  # node_unlink_001
]

wrapper_path = joinpath(@__DIR__, "_mission_wrapper.jl")
results_file = joinpath(@__DIR__, "specimens", "chat_results_raw.txt")

println("=" ^ 60)
println("COMPREHENSIVE CHAT TEST — 25 Node Patterns (AIML Capture)")
println("=" ^ 60)
println("\nSpawning child Julia process for all 25 missions...")

# Run all missions in a single child process
cmd = `julia $wrapper_path $test_inputs`
raw_output = ""
try
    raw_output = read(cmd, String)
catch e
    println("FATAL: Child process failed: $e")
    exit(1)
end

println("Captured $(length(raw_output)) bytes of output. Parsing...")

# Parse the output: find each ===MISSION_START:X=== ... ===MISSION_END:X=== block
# and within each block, extract the 🤖 AIML Output Scaffold: section
results = []

lines = split(raw_output, "\n")
current_mission = ""
in_mission = false
mission_lines = String[]

for line in lines
    if startswith(line, "===MISSION_START:")
        # Extract mission text
        m = match(r"===MISSION_START:(.*)===", line)
        current_mission = m !== nothing ? m.captures[1] : "unknown"
        in_mission = true
        mission_lines = String[]
    elseif startswith(line, "===MISSION_END:")
        in_mission = false
        # Parse the mission block for AIML scaffold
        mission_text = join(mission_lines, "\n")
        status, conversational_reply, full_scaffold, digest = parse_mission_output(current_mission, mission_text)
        push!(results, (current_mission, status, conversational_reply, full_scaffold, digest))
        print("  \"$current_mission\" → $status: ")
        display_text = length(conversational_reply) > 100 ? conversational_reply[1:100] * "..." : conversational_reply
        println(display_text)
    elseif in_mission
        push!(mission_lines, line)
    end
end

println("\n" * "=" ^ 60)
println("CHAT TEST COMPLETE — $(length(results)) results")
println("=" ^ 60)

# Save results

try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endresults_file, "w") do f
    for (input_text, status, conversational_reply, full_scaffold, digest) in results
        println(f, "=== INPUT ===")
        println(f, input_text)
        println(f, "=== STATUS ===")
        println(f, status)
        println(f, "=== CONVERSATIONAL_REPLY ===")
        println(f, conversational_reply)
        println(f, "=== DIGEST ===")
        println(f, digest)
        println(f, "=== FULL_SCAFFOLD ===")
        println(f, full_scaffold)
        println(f, "")
    end
end
println("Raw results saved to specimens/chat_results_raw.txt")

"""
    parse_mission_output(mission_name, mission_text) -> (status, conversational_reply, full_scaffold, digest)

Parse the captured stdout from a single process_mission() call.
Extract the AIML scaffold section and split at the DEBUG TELEMETRY divider.
"""
function parse_mission_output(mission_name::String, mission_text::String)
    scaffold_marker = "🤖 AIML Output Scaffold:"
    ask_marker = "🤖 AIML Ask Question:"

    full_scaffold = ""
    conversational_reply = ""
    status = "OK"
    digest = ""

    if occursin(scaffold_marker, mission_text)
        marker_range = findfirst(scaffold_marker, mission_text)
        content_start = marker_range[end] + 1
        full_scaffold = strip(mission_text[content_start:end])

        telemetry_marker = "--- DEBUG TELEMETRY"
        if occursin(telemetry_marker, full_scaffold)
            tel_range = findfirst(telemetry_marker, full_scaffold)
            conversational_reply = strip(full_scaffold[1:tel_range.start - 1])
        else
            conversational_reply = full_scaffold
        end
    elseif occursin(ask_marker, mission_text)
        marker_range = findfirst(ask_marker, mission_text)
        content_start = marker_range[end] + 1
        full_scaffold = strip(mission_text[content_start:end])
        conversational_reply = full_scaffold
        status = "ASK"
    else
        status = "NO_SCAFFOLD"
        conversational_reply = "[No AIML output captured]"
        full_scaffold = mission_text
    end

    # Extract digest from the mission text (the System MESSAGE_HISTORY line)
    digest_pattern = r"Mission \"(.*?)\" → primary=(\w+) conf=([\d.]+) node=(\w+)"
    m = match(digest_pattern, mission_text)
    if m !== nothing
        digest = m.match
    end

    return (status, conversational_reply, full_scaffold, digest)
end
