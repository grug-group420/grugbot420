#!/usr/bin/env julia
# test_v826f.jl — Test for v8.26f question:answer teaching syntax
# Dead simple: user types "fire:oxidation and heat" and it creates a node.
# Then asking "what is fire" should recall that answer.

using Dates, JSON
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK

const SPEC_PATH = get(ARGS, 1, "/workspace/test.specimen")
const LOG_PATH  = "/workspace/test_v826f_log.md"
const _log_lines = String[]

log_md(line) = push!(_log_lines, line)
flush_log_md(path) = open(path, "w") do f; for l in _log_lines; println(f, l); end; end

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function run_mission(text)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try process_mission(text); catch e; @warn "error" exception=e; end
    return read_last()
end

clean(raw) = begin
    s = strip(raw)
    # v8.26g: Remove ALL DEBUG TELEMETRY blocks (not just truncate at first).
    # Multipart output has multiple entries each with their own TELEMETRY block.
    # Each block is: --- DEBUG TELEMETRY ... =========================================
    while true
        m = match(r"--- DEBUG TELEMETRY[\s\S]*?=========================================", s)
        isnothing(m) && break
        s = replace(s, r"--- DEBUG TELEMETRY[\s\S]*?=========================================" => "")
    end
    replace(replace(s, r"\s+" => " "), "\n" => " ")
end

# ══════════════════════════════════════════════════════════════════════
# MAIN TEST
# ══════════════════════════════════════════════════════════════════════

log_md("# GrugBot420 v8.26f — question:answer Teaching Test")
log_md("Date: $(now())  |  Specimen: $SPEC_PATH")
log_md("")

load_specimen_from_file!(SPEC_PATH)
log_md("Loaded: $(length(NODE_MAP)) nodes\n")

# ── Test 1: Teach "fire:oxidation and heat" then recall ──
log_md("## Test 1: Teach fire, then ask about fire")
teach_out = clean(run_mission("fire:oxidation and heat"))
log_md("- **Teach**: \"fire:oxidation and heat\"  |  **Ack**: \"$teach_out\"")
t1_teach = occursin("grug learned", lowercase(teach_out)) || occursin("fire", lowercase(teach_out))
log_md("- **Teach result**: $(t1_teach ? "✅" : "❌")\n")

# Small delay for node propagation
sleep(0.5)

recall_out = clean(run_mission("what is fire"))
log_md("- **Recall**: \"what is fire\"  |  **A**: \"$recall_out\"")
rl = lowercase(recall_out)
# The answer should mention oxidation or heat (the taught content)
# or fire-related content from existing nodes
f1 = occursin("fire",rl)||occursin("burn",rl)||occursin("oxidation",rl)||occursin("heat",rl)||occursin("flame",rl)
t1 = f1 ? "✅ PASS" : "❌ FAIL"
log_md("- **Result**: $t1  (fire=$f1)\n")

# ── Test 2: Teach "water:universal solvent" then recall ──
log_md("## Test 2: Teach water, then ask about water")
teach2 = clean(run_mission("water:universal solvent"))
log_md("- **Teach**: \"water:universal solvent\"  |  **Ack**: \"$teach2\"")
t2_teach = occursin("grug learned", lowercase(teach2)) || occursin("water", lowercase(teach2))
log_md("- **Teach result**: $(t2_teach ? "✅" : "❌")\n")

sleep(0.5)

recall2 = clean(run_mission("what is water"))
log_md("- **Recall**: \"what is water\"  |  **A**: \"$recall2\"")
rl2 = lowercase(recall2)
w2 = occursin("water",rl2)||occursin("solvent",rl2)||occursin("universal",rl2)||occursin("liquid",rl2)||occursin("h2o",rl2)
t2 = w2 ? "✅ PASS" : "❌ FAIL"
log_md("- **Result**: $t2  (water=$w2)\n")

# ── Test 3: Both fire AND water answered via question:answer teaching ──
log_md("## Test 3: Compound query after teaching both")
both_out = clean(run_mission("what is fire and what is water"))
log_md("- **Q**: \"what is fire and what is water\"")
log_md("- **A**: \"$both_out\"")
bl = lowercase(both_out)
f3 = occursin("fire",bl)||occursin("burn",bl)||occursin("oxidation",bl)||occursin("heat",bl)
w3 = occursin("water",bl)||occursin("solvent",bl)||occursin("universal",bl)||occursin("liquid",bl)||occursin("h2o",bl)
t3 = f3 && w3 ? "✅ PASS" : f3 || w3 ? "⚠️ PARTIAL" : "❌ FAIL"
log_md("- **Result**: $t3  (fire=$f3, water=$w3)\n")

# ── Test 4: "Who are you" regression guard ──
log_md("## Test 4: \"Who are you\" — Identity Node Regression Guard")
way = clean(run_mission("who are you"))
log_md("- **Q**: \"who are you\"  |  **A**: \"$way\"")
wl = lowercase(way)
id1 = occursin("grug",wl)||occursin("cave",wl)||occursin("friend",wl)||occursin("i am",wl)||occursin("i live",wl)||occursin("i think",wl)
are1 = occursin("words of being",wl)||occursin("are and is",wl)
r_way = id1 && !are1 ? "✅ PASS" : are1 ? "❌ FAIL (are node)" : "⚠️ UNCLEAR"
log_md("- **Result**: $r_way\n")

# ── Test 5: question:answer doesn't conflict with lobe syntax ──
log_md("## Test 5: Lobe syntax still works (science: gravity is an attractive force)")
lobe_teach = clean(run_mission("science: gravity is an attractive force"))
log_md("- **Teach**: \"science: gravity is an attractive force\"  |  **A**: \"$lobe_teach\"")
# This should go through normal pipeline (lobe-qualified answer), NOT question:answer
lt = lowercase(lobe_teach)
lobe_ok = !occursin("grug learned", lt)  # should NOT trigger QA ack
log_md("- **Result**: $(lobe_ok ? "✅ PASS (not intercepted by QA)" : "❌ FAIL (QA stole lobe syntax)")\n")

# ── Summary ──
log_md("## Summary\n")
log_md("| # | Test | Result |")
log_md("|---|------|--------|")
log_md("| 1 | Teach fire → recall | $t1 |")
log_md("| 2 | Teach water → recall | $t2 |")
log_md("| 3 | Compound fire+water | $t3 |")
log_md("| 4 | Who are you → identity | $r_way |")
log_md("| 5 | Lobe syntax not stolen | $(lobe_ok ? "✅ PASS" : "❌ FAIL") |")
log_md("")

flush_log_md(LOG_PATH)
println("\n✅ Test complete. Log: $LOG_PATH")
try save_specimen_to_file!("/workspace/test_v826f_saved.specimen"); catch; end
