#!/usr/bin/env julia --project=.
# ==============================================================================
# GrugBot420 Diagnostic: Empty Recall for Fermentation & Sonnet
# Only runs the /answer teach-and-recall scenarios to reproduce the bug
# ==============================================================================

using Pkg; Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP,
    get_node_status_summary

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")

# ────── Response capture via internals ──────
read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    println("[CAPTURE-DEBUG-TEST] Raw capture for '$text': length=$(length(r)) isempty=$(isempty(r)) first100='$(first(r, min(100, length(r))))'")
    # Strip TELEMETRY
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

ENV["GRUG_CHATTER_ENABLED"] = "false"

println("=" ^ 60)
println("  DIAGNOSTIC: Empty Recall for Fermentation & Sonnet")
println("=" ^ 60)

println("\n📦 Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("✅ Loaded.\n")

# ────── Run the failing /answer scenarios ──────

# Scenario 3: fermentation
println("\n" * "=" ^ 60)
println("  SCENARIO 3: Fermentation")
println("=" ^ 60)

println("\n[Step 1] Ask 'what is fermentation' (should get ASK)")
r1 = ask_grug("what is fermentation")
println("\n[Step 1 Result]: '$r1'")

println("\n[Step 2] Teach with /answer")
answer3 = "/answer @science :define Fermentation is a metabolic process where microorganisms convert sugars into alcohol, gases, or organic acids under anaerobic conditions. Yeast and bacteria are common fermentation agents used in brewing, baking, and preserving food."
r2 = ask_grug(answer3)
println("\n[Step 2 Result]: '$r2'")

println("\n[Step 3] Re-ask 'what is fermentation' (should recall)")
r3 = ask_grug("what is fermentation")
println("\n[Step 3 Result]: '$r3'")
if isempty(r3)
    println("❌ EMPTY RECALL for fermentation!")
else
    println("✅ Fermentation recall works! Length=$(length(r3))")
end

# Scenario 6: sonnet
println("\n" * "=" ^ 60)
println("  SCENARIO 6: Sonnet")
println("=" ^ 60)

println("\n[Step 1] Ask 'what is a sonnet' (should get ASK)")
r4 = ask_grug("what is a sonnet")
println("\n[Step 1 Result]: '$r4'")

println("\n[Step 2] Teach with /answer")
answer6 = "/answer @arts :explain A sonnet is a fourteen-line poem with a specific rhyme scheme, traditionally written in iambic pentameter. The two main types are the Petrarchan with an octave and sestet, and the Shakespearean with three quatrains and a couplet."
r5 = ask_grug(answer6)
println("\n[Step 2 Result]: '$r5'")

println("\n[Step 3] Re-ask 'what is a sonnet' (should recall)")
r6 = ask_grug("what is a sonnet")
println("\n[Step 3 Result]: '$r6'")
if isempty(r6)
    println("❌ EMPTY RECALL for sonnet!")
else
    println("✅ Sonnet recall works! Length=$(length(r6))")
end

# ────── Also test a known-working scenario for comparison ──────
println("\n" * "=" ^ 60)
println("  CONTROL: Stromatolite (known working)")
println("=" ^ 60)

println("\n[Step 1] Ask 'what are stromatolites' (should get ASK)")
r7 = ask_grug("what are stromatolites")
println("\n[Step 1 Result]: '$r7'")

println("\n[Step 2] Teach with /answer")
answer_ctrl = "/answer @science :define Stromatolites are layered sedimentary structures formed by the activity of cyanobacteria. They represent some of the oldest evidence of life on Earth, dating back over 3.5 billion years."
r8 = ask_grug(answer_ctrl)
println("\n[Step 2 Result]: '$r8'")

println("\n[Step 3] Re-ask 'what are stromatolites' (should recall)")
r9 = ask_grug("what are stromatolites")
println("\n[Step 3 Result]: '$r9'")
if isempty(r9)
    println("❌ EMPTY RECALL for stromatolites!")
else
    println("✅ Stromatolite recall works! Length=$(length(r9))")
end

println("\n" * "=" ^ 60)
println("  DIAGNOSTIC COMPLETE")
println("=" ^ 60)
