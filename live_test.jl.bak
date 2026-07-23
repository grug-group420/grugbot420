#!/usr/bin/env julia --project=.
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    scan_specimens, Lobe, NODE_MAP, NODE_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_v740.specimen")
const LOG_PATH = joinpath(@__DIR__, "grug_v740_coherence_test_log.md")
const JSON_PATH = joinpath(@__DIR__, "grug_v740_coherence_test_results.json")
const SAVE_PATH = joinpath(@__DIR__, "grug_v740_post_coherence_test.specimen")

read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    try; process_mission(text); catch e; @warn "err: $e"; end
    r = read_last()
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

ENV["GRUG_CHATTER_ENABLED"] = "false"

println("Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("Loaded. Running tests...\n")

# ═══════════════════════════════════════
# COLLECT ALL TEST QUERIES
# ═══════════════════════════════════════

struct TestQ; cat::String; q::String; end

tests = TestQ[
    TestQ("knowledge","what is fire"),
    TestQ("knowledge","what is water"),
    TestQ("knowledge","what is earth"),
    TestQ("knowledge","what is sky"),
    TestQ("knowledge","what is love"),
    TestQ("knowledge","what is courage"),
    TestQ("knowledge","why does fire burn"),
    TestQ("knowledge","why is sky blue"),
    TestQ("knowledge","why does water flow"),
    TestQ("knowledge","how does grug think"),
    TestQ("knowledge","how does fire work"),
    TestQ("knowledge","hello"),
    TestQ("knowledge","what is gravity"),
    TestQ("knowledge","what is river"),
    TestQ("math","what is 2 plus 2"),
    TestQ("math","what is 3 times 4"),
    TestQ("math","what is 7 plus 8"),
    TestQ("math","what is 9 times 6"),
    TestQ("math","what is 20 minus 8"),
    TestQ("multipart","what is fire and what is water"),
    TestQ("multipart","why does fire burn and why does water flow"),
    TestQ("multipart","what is love and what is courage"),
    TestQ("multipart","how does grug think and what is sky"),
    TestQ("q_and_a","what is photosynthesis"),
    TestQ("q_and_a","what is quantum computing"),
    TestQ("q_and_a","tell me about rocks"),
    TestQ("q_and_a","what is a computer"),
    TestQ("q_and_a","who are you"),
    TestQ("edge","what is air"),
    TestQ("edge","what is beauty"),
    TestQ("edge","danger"),
    TestQ("edge","i feel sad"),
]

# ═══════════════════════════════════════
# RUN MAIN QUERIES
# ═══════════════════════════════════════

log = String[]
ts = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
push!(log, "# GrugBot420 Live Coherence Test\n")
push!(log, "**Date:** $(ts)\n")
push!(log, "**Specimen:** grug_comprehensive_v740.specimen (82 nodes)\n")
push!(log, "**Chatter:** DISABLED\n\n---\n")

results = Dict{String,String}()

for (i,t) in enumerate(tests)
    r = ask_grug(t.q)
    results[t.q] = r
    push!(log, "## Turn $(i) — $(t.cat)\n")
    push!(log, "**User:** $(t.q)\n")
    push!(log, "> $(r)\n\n---\n")
    short = length(r)>120 ? r[1:117]*"..." : r
    println("[$i/$(length(tests))] [$(t.cat)] Q: $(t.q)\n  A: $(short)\n")
end

# ═══════════════════════════════════════
# /answer MECHANIC TEST
# ═══════════════════════════════════════

push!(log, "\n# /answer Mechanic Test\n\n---\n")

# --- :explain mode ---
q1 = "what is photosynthesis"
r_ask1 = ask_grug(q1)
push!(log, "## /answer Step 1: Ask Unknown (explain)\n")
push!(log, "**User:** $(q1)\n> $(r_ask1)\n")
is_ask1 = occursin("/answer", r_ask1) || occursin("teach me", lowercase(r_ask1)) || occursin("Nothing in the cave", r_ask1)
push!(log, "**Verdict:** $(is_ask1 ? "✅ ASK generated" : "❌ NO ask")\n\n---\n")
println("[/answer explain] Step 1: → $(is_ask1 ? "ASK ✅" : "NO ASK ❌")")

# Teach via :explain
lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q1; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad1 = _base_answer_data("explain"; pending_ask_text=q1)
ad1["response"] = "plants use sunlight to make food"
ad1["noun_anchors"] = ["photosynthesis", "plants", "sunlight"]
nid1, lt1 = _create_answer_node("photosynthesis", "explain^1", ad1, nothing)
push!(log, "## /answer Step 2: Teach (explain)\n")
push!(log, "**Cmd:** /answer :explain plants use sunlight to make food\n")
push!(log, "**Node:** $(nid1)$(lt1)\n\n---\n")
println("[/answer explain] Step 2: node $(nid1)$(lt1)")

# Re-ask
r_recall1 = ask_grug(q1)
push!(log, "## /answer Step 3: Recall (explain)\n")
push!(log, "**User:** $(q1)\n> $(r_recall1)\n")
rc1 = !occursin("Nothing in the cave", r_recall1) && !occursin("teach me", lowercase(r_recall1))
mt1 = occursin("photosynthesis", lowercase(r_recall1)) || occursin("plant", lowercase(r_recall1))
push!(log, "**Verdict:** $(rc1 ? "✅" : "❌") $(mt1 ? "(topic mentioned)" : "(topic NOT mentioned)")\n\n---\n")
println("[/answer explain] Step 3: → $(rc1 ? "RECALLED ✅" : "FAILED ❌")")

# --- :math mode ---
q2 = "what is the derivative of x squared"
r_ask2 = ask_grug(q2)
push!(log, "## /answer Step 1: Ask Unknown (math)\n")
push!(log, "**User:** $(q2)\n> $(r_ask2)\n")
is_ask2 = occursin("/answer", r_ask2) || occursin("teach me", lowercase(r_ask2)) || occursin("Nothing in the cave", r_ask2)
push!(log, "**Verdict:** $(is_ask2 ? "✅ ASK generated" : "❌ NO ask")\n\n---\n")
println("[/answer math] Step 1: → $(is_ask2 ? "ASK ✅" : "NO ASK ❌")")

lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q2; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad2 = _base_answer_data("math"; pending_ask_text=q2)
ad2["response"] = "the derivative of x squared is 2x"
ad2["noun_anchors"] = ["derivative", "x", "2x"]
nid2, lt2 = _create_answer_node("derivative of x squared", "reason^1", ad2, nothing)
push!(log, "## /answer Step 2: Teach (math)\n")
push!(log, "**Cmd:** /answer :math the derivative of x squared is 2x\n")
push!(log, "**Node:** $(nid2)$(lt2)\n\n---\n")
println("[/answer math] Step 2: node $(nid2)$(lt2)")

r_recall2 = ask_grug(q2)
push!(log, "## /answer Step 3: Recall (math)\n")
push!(log, "**User:** $(q2)\n> $(r_recall2)\n")
rc2 = !occursin("Nothing in the cave", r_recall2) && !occursin("teach me", lowercase(r_recall2))
mt2 = occursin("derivative", lowercase(r_recall2)) || occursin("2x", r_recall2) || occursin("x squared", lowercase(r_recall2))
push!(log, "**Verdict:** $(rc2 ? "✅" : "❌") $(mt2 ? "(math content mentioned)" : "(math content NOT mentioned)")\n\n---\n")
println("[/answer math] Step 3: → $(rc2 ? "RECALLED ✅" : "FAILED ❌")")

# --- :reason mode (simple) ---
q3 = "what is chlorophyll"
r_ask3 = ask_grug(q3)
push!(log, "## /answer Step 1: Ask Unknown (reason)\n")
push!(log, "**User:** $(q3)\n> $(r_ask3)\n")
is_ask3 = occursin("/answer", r_ask3) || occursin("teach me", lowercase(r_ask3)) || occursin("Nothing in the cave", r_ask3)
push!(log, "**Verdict:** $(is_ask3 ? "✅ ASK generated" : "❌ NO ask")\n\n---\n")
println("[/answer reason] Step 1: → $(is_ask3 ? "ASK ✅" : "NO ASK ❌")")

lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q3; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad3 = _base_answer_data("reason"; pending_ask_text=q3)
ad3["response"] = "chlorophyll is the green pigment in plants that captures light"
ad3["noun_anchors"] = ["chlorophyll", "green", "pigment"]
nid3, lt3 = _create_answer_node("chlorophyll", "reason^1", ad3, nothing)
push!(log, "## /answer Step 2: Teach (reason)\n")
push!(log, "**Cmd:** /answer :reason chlorophyll is the green pigment in plants\n")
push!(log, "**Node:** $(nid3)$(lt3)\n\n---\n")
println("[/answer reason] Step 2: node $(nid3)$(lt3)")

r_recall3 = ask_grug(q3)
push!(log, "## /answer Step 3: Recall (reason)\n")
push!(log, "**User:** $(q3)\n> $(r_recall3)\n")
rc3 = !occursin("Nothing in the cave", r_recall3) && !occursin("teach me", lowercase(r_recall3))
mt3 = occursin("chlorophyll", lowercase(r_recall3)) || occursin("green", lowercase(r_recall3)) || occursin("pigment", lowercase(r_recall3))
push!(log, "**Verdict:** $(rc3 ? "✅" : "❌") $(mt3 ? "(content mentioned)" : "(content NOT mentioned)")\n\n---\n")
println("[/answer reason] Step 3: → $(rc3 ? "RECALLED ✅" : "FAILED ❌")")

# ═══════════════════════════════════════
# SAVE SPECIMEN
# ═══════════════════════════════════════

println("\nSaving specimen...")
try; save_specimen_to_file!(SAVE_PATH); catch e; @warn "save failed: $e"; end
println("Saved to $(SAVE_PATH)")

# ═══════════════════════════════════════
# WRITE FILES
# ═══════════════════════════════════════

open(LOG_PATH, "w") do f; print(f, join(log, "")); end
println("✅ Log → $(LOG_PATH)")

json_out = Dict(
    "queries" => results,
    "answer_explain" => Dict("ask"=>r_ask1,"recall"=>r_recall1),
    "answer_math"    => Dict("ask"=>r_ask2,"recall"=>r_recall2),
    "answer_reason"  => Dict("ask"=>r_ask3,"recall"=>r_recall3),
)
open(JSON_PATH, "w") do f; JSON.print(f, json_out, 2); end
println("✅ JSON → $(JSON_PATH)")

println("\n═══ DONE ═══")
