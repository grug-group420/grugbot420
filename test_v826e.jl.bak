#!/usr/bin/env julia
# test_v826e.jl — Focused test for v8.26e strength-confidence separation
# Tests: 1. Thermodynamics domination  2. "Who are you"  3. :time recall

using Dates, JSON
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK,
    _base_answer_data, _plant_answer_cluster,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    immune_gate, dampen_strain!, create_node,
    count_alive_nodes_in_lobe

import .GrugBot420.Lobe: add_node_to_lobe!, find_lobe_for_node, lobe_is_full, LOBE_REGISTRY
import .GrugBot420.EphemeralMLP: get_strain_energy
import .GrugBot420.SigilRegistry: expand_relation_sigil, _ENGINE_SIGIL_TABLE

const SPEC_PATH = get(ARGS, 1, "/workspace/test.specimen")
const LOG_PATH  = "/workspace/test_v826e_log.md"
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
    ti = findfirst("--- DEBUG TELEMETRY", s)
    ti !== nothing && (s = strip(s[1:first(ti)-1]))
    replace(replace(s, r"\s+" => " "), "\n" => " ")
end

function teach_answer(lobe, mode, content)
    if lobe !== nothing && !haskey(LOBE_REGISTRY, lobe); @warn "lobe missing"; return ("", String[]); end
    if lobe !== nothing && lobe_is_full(lobe); @warn "lobe full"; return ("", String[]); end
    if !immune_gate("/answer", content; is_critical=false); @warn "immune blocked"; return ("", String[]); end
    try dampen_strain!(0.7); catch; end
    pending = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; old=_HIPPOCAMPAL_PENDING_ASK[]; _HIPPOCAMPAL_PENDING_ASK[]=""; old; end

    if mode == "time"
        parts = [strip(String(s)) for s in split(content, "|")]
        filter!(!isempty, parts)
        length(parts) < 2 && (@warn ":time needs subj|obj"; return ("", String[]))
        subj, obj = parts[1], parts[2]
        orient = length(parts) >= 3 ? strip(parts[3]) : ""
        td = _base_answer_data("reason"; pending_ask_text=pending,
            answer_content="$(lowercase(subj)) &temporal $(lowercase(obj))")
        td["answer_mode"] = "time"
        td["time_node"] = true
        if !isempty(orient) && lowercase(orient) in ("past","present","future")
            td["time_orientation"] = lowercase(orient)
            td["time_sigil"] = Dict("past"=>"before","present"=>"now","future"=>"next")[lowercase(orient)]
        end
        td["noun_anchors"] = [lowercase(subj), lowercase(obj)]
        td["required_relations"] = ["&temporal"]
        td["seeded_triple"] = Dict("subject"=>lowercase(subj),"relation"=>"&temporal","object"=>lowercase(obj))
        td["voice_register"] = "plain"
        td["frame_hints"] = ["plain","exploratory"]
        # v8.26e: pattern includes BOTH subj and obj
        pat = strip("$(lowercase(subj)) $(lowercase(obj))")
        nid, sids, lt = _plant_answer_cluster(pat, "reason^1", td, lobe, "time")
        return (nid, sids)
    elseif mode == "explain"
        ed = _base_answer_data("explain"; pending_ask_text=pending, answer_content=content)
        ed["answer_mode"] = "explain"
        ed["noun_anchors"] = split(lowercase(content), r"[\s,.;]+") |> x -> filter(w -> length(w) > 3, x) |> x -> x[1:min(3, length(x))]
        ed["voice_register"] = "warm"
        ed["frame_hints"] = ["warm", "narrative"]
        pat = lowercase(content) |> s -> split(s, r"[\s,.;]+") |> xs -> filter(w -> length(w) > 3, xs) |> xs -> join(xs[1:min(4,length(xs))], " ")
        nid, sids, lt = _plant_answer_cluster(pat, "explain^3", ed, lobe, "explain")
        return (nid, sids)
    else
        @warn "teach_answer: unsupported mode $mode"
        return ("", String[])
    end
end

# ════════════════════════════════════════════════════════
# MAIN TEST
# ════════════════════════════════════════════════════════

log_md("# GrugBot420 v8.26e — Strength-Confidence Separation Test")
log_md("Date: $(now())  |  Specimen: $SPEC_PATH")
log_md("")

load_specimen_from_file!(SPEC_PATH)
log_md("Loaded: $(length(NODE_MAP)) nodes\n")

# ─── Test 1: Multipart — Fire + Water ──────────────────
log_md("## Test 1: Multipart — Fire + Water (No Thermo Domination)")
mp1 = clean(run_mission("what is fire and what is water"))
log_md("- **Q**: \"what is fire and what is water\"")
log_md("- **A**: \"$mp1\"")
ml = lowercase(mp1)
f1 = occursin("fire",ml)||occursin("burn",ml)||occursin("oxidation",ml)||occursin("combustion",ml)||occursin("heat",ml)||occursin("flame",ml)
w1 = occursin("water",ml)||occursin("liquid",ml)||occursin("solvent",ml)||occursin("h2o",ml)||occursin("hydrogen",ml)
t1 = occursin("thermodynamic",ml) && !f1 && !w1
r1 = f1 && w1 ? "✅ PASS" : t1 ? "❌ FAIL (thermo)" : f1||w1 ? "⚠️ PARTIAL" : "❌ FAIL"
log_md("- **Result**: $r1  (fire=$f1, water=$w1, thermo=$t1)\n")

mp2 = clean(run_mission("why does fire burn and why does water flow"))
log_md("- **Q**: \"why does fire burn and why does water flow\"")
log_md("- **A**: \"$mp2\"")
ml2 = lowercase(mp2)
f2 = occursin("fire",ml2)||occursin("burn",ml2)||occursin("heat",ml2)
w2 = occursin("water",ml2)||occursin("flow",ml2)||occursin("liquid",ml2)
r2 = f2&&w2 ? "✅ PASS" : "⚠️ PARTIAL/FAIL"
log_md("- **Result**: $r2  (fire=$f2, water=$w2)\n")

# ─── Test 2: "Who are you" ─────────────────────────────
log_md("## Test 2: \"Who are you\" — Identity Node")
way = clean(run_mission("who are you"))
log_md("- **Q**: \"who are you\"  |  **A**: \"$way\"")
wl = lowercase(way)
id1 = occursin("grug",wl)||occursin("cave",wl)||occursin("friend",wl)||occursin("i am",wl)||occursin("i live",wl)||occursin("i think",wl)
are1 = occursin("words of being",wl)||occursin("are and is",wl)
r_way = id1 && !are1 ? "✅ PASS" : are1 ? "❌ FAIL (are node)" : "⚠️ UNCLEAR"
log_md("- **Result**: $r_way\n")

way2 = clean(run_mission("what are you"))
log_md("- **Q**: \"what are you\"  |  **A**: \"$way2\"")
wl2 = lowercase(way2)
id2 = occursin("grug",wl2)||occursin("cave",wl2)||occursin("friend",wl2)
r2 = id2 ? "✅ PASS" : "❌ FAIL"
log_md("- **Result**: $r2\n")

# ─── Test 3: :time Recall ──────────────────────────────
log_md("## Test 3: :time Recall — Temporal Node")
pre_t = clean(run_mission("what came before the renaissance"))
log_md("- **Before teach**: \"$pre_t\"")
# Use default lobe (no @history since it's full)
nid, sids = teach_answer(nothing, "time", "the dark ages | the renaissance | past")
log_md("- **Taught**: node=$nid shadows=$sids")
# Clear cycle state so new node can be found
sleep(0.5)
time_recall = clean(run_mission("what came before the renaissance"))
log_md("- **Recall**: \"$time_recall\"")
tl = lowercase(time_recall)
da = occursin("dark ages",tl)||occursin("dark age",tl)
tp = occursin("before",tl)||occursin("past",tl)||occursin("preceded",tl)||occursin("came before",tl)
beauty = occursin("beauty",tl) && !da
ren_only = occursin("renaissance",tl) && !da && !tp
r3 = da ? "✅ PASS" : beauty ? "❌ FAIL (beauty)" : ren_only ? "❌ FAIL (ren only)" : "⚠️ UNCLEAR"
log_md("- **Result**: $r3  (dark_ages=$da, temporal=$tp, beauty=$beauty, ren_only=$ren_only)\n")

# ─── Test 4: Sanity ────────────────────────────────────
log_md("## Test 4: Sanity Checks")
g = clean(run_mission("hello")); gl=lowercase(g)
g_ok = occursin("grug",gl) || occursin("hello",gl) || occursin("hi",gl)
log_md("- hello: \"$g\" → $(g_ok ? "✅" : "❌")")
m1 = clean(run_mission("what is 5 plus 3"))
log_md("- 5+3: \"$m1\" → $(occursin("8",m1) ? "✅" : "❌")")
m2 = clean(run_mission("what is 20 divided by 5"))
log_md("- 20/5: \"$m2\" → $(occursin("4",m2) ? "✅" : "❌")")
gb = clean(run_mission("xyzzy plugh plover")); gbl=lowercase(gb)
gb_ok = occursin("strain",gbl) || occursin("?",gb)
log_md("- gibberish: \"$(gb[1:min(80,length(gb))])\" → $(gb_ok ? "✅" : "⚠️")\n")

# ─── Summary ───────────────────────────────────────────
log_md("## Summary\n")
log_md("| # | Test | Result |")
log_md("|---|------|--------|")
log_md("| 1a | Multipart fire+water | $r1 |")
log_md("| 1b | Multipart burn+flow | $r2 |")
log_md("| 2a | Who are you → identity | $r_way |")
log_md("| 2b | What are you → identity | $r2 |")
log_md("| 3 | :time recall → dark ages | $r3 |")
log_md("")

flush_log_md(LOG_PATH)
println("\n✅ Test complete. Log: $LOG_PATH")
try save_specimen_to_file!("/workspace/test_v826e_saved.specimen"); catch; end
