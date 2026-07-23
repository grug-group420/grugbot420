#!/usr/bin/env julia
# =============================================================================
# GRUG THREAD-C CONVERSATION TEST — Internal-state telemetry only, NO stdout
# scraping. Loads grug_threadC_comprehensive.specimen, runs 44 turns matching
# the reference CONVERSATION_LOG_v758.md categories, and dumps raw telemetry
# (voice output + fired node + primary action + confidence + voter ids +
# lobe curve) per turn to a JSON file for the coherence pass / log assembly
# step to consume.
# =============================================================================

println("[BOOT] Loading GrugBot420 module …")
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420
using JSON

import .GrugBot420:
    save_specimen_to_file!, load_specimen_from_file!, process_mission,
    NODE_MAP, GROUP_MAP, is_time_node,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    LAST_VOTER_IDS, LAST_VOTER_LOCK, _ENGINE_SIGIL_TABLE

import .GrugBot420: Lobe, LobeOrchestrator
import .GrugBot420.Lobe: LOBE_REGISTRY, NODE_TO_LOBE_IDX

println("[BOOT] GrugBot420 module loaded.")

spec_path = joinpath(@__DIR__, "grug_threadC_comprehensive.specimen")
println("[BOOT] Loading specimen: $spec_path")
load_result = load_specimen_from_file!(spec_path)
println("[BOOT] Specimen loaded: ", load_result)

# ── Snapshot engine config right after load (for the "Engine Configuration" /
#    "Lobe Distribution" report sections) ──────────────────────────────────
function snapshot_engine_config()
    total_nodes  = length(NODE_MAP)
    total_groups = length(GROUP_MAP)
    total_lobes  = length(Lobe.LOBE_REGISTRY)
    total_sigils = length(_ENGINE_SIGIL_TABLE.entries)
    # "AIML nodes" ~ node_type==:sigil executive/template nodes (closest living
    # analog since AIMLNodeSystem was removed in v8.12 — see build script header)
    sigil_node_count = count(n -> n.node_type == :sigil, values(NODE_MAP))

    lobe_rows = Vector{Tuple{String,Int,Int}}()
    for (lobe_id, rec) in Lobe.LOBE_REGISTRY
        n_ids = collect(rec.node_ids)
        n_count = length(n_ids)
        aiml_count = count(id -> begin
            node = get(NODE_MAP, id, nothing)
            node !== nothing && node.node_type == :sigil
        end, n_ids)
        push!(lobe_rows, (lobe_id, n_count, aiml_count))
    end
    sort!(lobe_rows; by = x -> x[1])

    return (
        total_nodes = total_nodes,
        total_groups = total_groups,
        total_lobes = total_lobes,
        total_sigils = total_sigils,
        sigil_node_count = sigil_node_count,
        lobe_rows = lobe_rows,
    )
end

initial_cfg = snapshot_engine_config()
println("[BOOT] Initial config: nodes=$(initial_cfg.total_nodes) groups=$(initial_cfg.total_groups) lobes=$(initial_cfg.total_lobes) sigils=$(initial_cfg.total_sigils) sigil_nodes=$(initial_cfg.sigil_node_count)")
for row in initial_cfg.lobe_rows
    println("    lobe=$(row[1]) nodes=$(row[2]) aiml=$(row[3])")
end

# ── Helper: run process_mission and collect pure internal-state telemetry ──
function run_turn(you_text::String)
    process_mission(you_text)

    output       = _LAST_VOICE_OUTPUT[]
    fired_node   = _LAST_FIRED_NODE[]
    primary_act  = _LAST_PRIMARY_ACTION[]
    confidence   = _LAST_CONFIDENCE[]
    voter_ids    = lock(() -> copy(LAST_VOTER_IDS), LAST_VOTER_LOCK)
    lobe_curve   = LobeOrchestrator.last_summary()

    node_pattern = ""
    node_lobe = ""
    node_strength = 0.0
    node_type = ""
    node_data = Dict{String,Any}()
    if !isempty(fired_node)
        node = get(NODE_MAP, fired_node, nothing)
        if node !== nothing
            node_pattern = node.pattern
            node_strength = node.strength
            node_type = string(node.node_type)
            node_data = node.json_data
            lobe_idx = get(Lobe.NODE_TO_LOBE_IDX, fired_node, nothing)
            if lobe_idx !== nothing
                node_lobe = lobe_idx
            end
        end
    end

    return Dict{String,Any}(
        "you" => you_text,
        "raw_output" => output,
        "fired_node" => fired_node,
        "node_pattern" => node_pattern,
        "node_lobe" => node_lobe,
        "node_strength" => node_strength,
        "node_type" => node_type,
        "node_answer_mode" => get(node_data, "answer_mode", ""),
        "primary_action" => primary_act,
        "confidence" => confidence,
        "voter_ids" => voter_ids,
        "lobe_curve" => lobe_curve,
    )
end

# ── The 44 turns, matching reference-log categories ────────────────────────
turns = String[
    "Hey Grug, what do you know about fire?",                 # 1  reason/default
    "Tell me about water.",                                    # 2  reason/survival
    "How does gravity work?",                                  # 3  explain/science
    "Why does fire burn, Grug?",                                # 4  explain + &similarity
    "Why is the sky blue?",                                     # 5  explain/science
    "Why do we feel sad sometimes?",                            # 6  multi explain+comfort
    "Define gravity for me.",                                   # 7  define/science
    "What is an atom?",                                         # 8  define + &possessive
    "Is fire dangerous?",                                       # 9  alert/survival
    "What about deep water?",                                   # 10 alert/survival
    "I feel sad today, Grug.",                                  # 11 comfort/emotions
    "I'm scared of what's coming.",                             # 12 comfort/emotions
    "I feel so lonely.",                                        # 13 comfort cross-lobe emotions+social
    "What is 2 plus 2?",                                        # 14 arithmetic
    "What is 3 times 4?",                                       # 15 arithmetic
    "What is 10 minus 3?",                                      # 16 arithmetic
    "What comes before the present?",                           # 17 relate + &temporal (time)
    "Tell me about spring and summer.",                         # 18 relate + &temporal, science cross
    "Heat causes evaporation.",                                 # 19 relate + &causal
    "Clouds are in the sky.",                                   # 20 relate + &spatial
    "A tree has branches.",                                     # 21 relate + &possessive
    "How do I make fire?",                                      # 22 procedure chain
    "How do I find water?",                                     # 23 procedure chain
    "Flame combust wood.",                                      # 24 synonym expansion
    "Forage for berries.",                                      # 25 autogrowth novel input
    "Construct a shelter.",                                     # 26 synonym expansion + &similarity
    "Fire makes me feel warm and safe.",                        # 27 cross-lobe survival->emotions
    "I need shelter from the cold.",                            # 28 cross-lobe + &causal
    "Person feels music.",                                      # 29 relate + &emotional
    "Spring season.",                                           # 30 &season macro sigil
    "Friendship brings joy.",                                   # 31 relate/social
    "Cooperation builds trust.",                                # 32 relate/social
    "Wrong bad incorrect stuff.",                                # 33 anti-thesaurus inhibition flavor
    "Fake false nonsense.",                                     # 34 anti-thesaurus inhibition flavor
    "Cooking food makes it safe.",                              # 35 reason/survival
    "Tell me about volcanoes again.",                           # 36 autogrowth recall
    "Volcanoes erupt hot lava.",                                # 37 autogrowth novel input
    "Thunderstorms bring lightning.",                           # 38 autogrowth novel input
    "fire",                                                     # 39 short input high-strength
    "What is water?",                                           # 40 relate + &possessive
    "Define happiness.",                                        # 41 define/emotions
    "I miss someone.",                                          # 42 comfort/social
    "What comes after winter?",                                 # 43 time node + &temporal
    "Thank you Grug, you've been helpful.",                     # 44 gratitude/social
]

results = Vector{Dict{String,Any}}()
for (i, t) in enumerate(turns)
    println("\n[TURN $i] YOU: $t")
    r = run_turn(t)
    println("[TURN $i] RAW: $(r["raw_output"])")
    println("[TURN $i] fired_node=$(r["fired_node"]) pattern=$(r["node_pattern"]) mode=$(r["node_answer_mode"]) conf=$(r["confidence"])")
    push!(results, r)
end

final_cfg = snapshot_engine_config()
println("\n[DONE] Final config: nodes=$(final_cfg.total_nodes) groups=$(final_cfg.total_groups)")

# ── Time-node group isolation audit ─────────────────────────────────────────
function audit_time_node_isolation()
    regular = 0
    time_groups = 0
    mixed = 0
    for (gid, grp) in GROUP_MAP
        member_time_flags = Bool[]
        for nid in grp.members
            node = get(NODE_MAP, nid, nothing)
            node === nothing && continue
            push!(member_time_flags, is_time_node(node))
        end
        isempty(member_time_flags) && continue
        all_time = all(member_time_flags)
        all_reg  = all(x -> !x, member_time_flags)
        if all_time
            time_groups += 1
        elseif all_reg
            regular += 1
        else
            mixed += 1
        end
    end
    return (regular=regular, time_groups=time_groups, mixed=mixed)
end
tni = audit_time_node_isolation()
println("[AUDIT] time-node isolation: regular=$(tni.regular) time=$(tni.time_groups) mixed=$(tni.mixed)")

# ── Top 10 strongest nodes ──────────────────────────────────────────────────
function top_strongest_nodes(n::Int=10)
    all_nodes = collect(values(NODE_MAP))
    sort!(all_nodes; by = x -> -x.strength)
    return [(nd.id, nd.pattern, nd.strength) for nd in all_nodes[1:min(n, length(all_nodes))]]
end
top10 = top_strongest_nodes(10)
println("[TOP10]")
for (id, pat, str) in top10
    println("  $id | $pat | $str")
end

# ── Sigil inventory ──────────────────────────────────────────────────────
function sigil_inventory()
    rows = Vector{Dict{String,Any}}()
    for (name, sig) in _ENGINE_SIGIL_TABLE.entries
        row = Dict{String,Any}(
            "name" => name,
            "class" => string(sig.class),
            "applies_at" => string(sig.applies_at),
        )
        if !isnothing(sig.expansion) && !isempty(sig.expansion)
            row["expansion"] = collect(sig.expansion)
        end
        if !isnothing(sig.lexicon)
            row["lexicon"] = collect(sig.lexicon)
        end
        push!(rows, row)
    end
    sort!(rows; by = x -> x["name"])
    return rows
end
sigils = sigil_inventory()
println("[SIGILS] total=$(length(sigils))")

# ── Dump everything to JSON for the log-assembly step ──────────────────────
# (JSON.jl already `using`'d transitively via Main.jl/engine.jl includes)
out = Dict{String,Any}(
    "initial_cfg" => Dict(
        "total_nodes" => initial_cfg.total_nodes,
        "total_groups" => initial_cfg.total_groups,
        "total_lobes" => initial_cfg.total_lobes,
        "total_sigils" => initial_cfg.total_sigils,
        "sigil_node_count" => initial_cfg.sigil_node_count,
        "lobe_rows" => [Dict("lobe"=>r[1],"nodes"=>r[2],"aiml"=>r[3]) for r in initial_cfg.lobe_rows],
    ),
    "final_cfg" => Dict(
        "total_nodes" => final_cfg.total_nodes,
        "total_groups" => final_cfg.total_groups,
        "total_lobes" => final_cfg.total_lobes,
        "total_sigils" => final_cfg.total_sigils,
        "sigil_node_count" => final_cfg.sigil_node_count,
        "lobe_rows" => [Dict("lobe"=>r[1],"nodes"=>r[2],"aiml"=>r[3]) for r in final_cfg.lobe_rows],
    ),
    "turns" => results,
    "time_node_isolation" => Dict("regular"=>tni.regular, "time_groups"=>tni.time_groups, "mixed"=>tni.mixed),
    "top10" => [Dict("id"=>t[1], "pattern"=>t[2], "strength"=>t[3]) for t in top10],
    "sigils" => sigils,
)

out_path = joinpath(@__DIR__, "threadC_raw_telemetry.json")
open(out_path, "w") do io
    JSON.print(io, out, 2)
end
println("\n[SAVED] Raw telemetry JSON -> $out_path")

# ── Save post-test specimen ─────────────────────────────────────────────────
final_spec_path = joinpath(@__DIR__, "grug_threadC_final.specimen")
save_specimen_to_file!(final_spec_path)
println("[SAVED] Final specimen -> $final_spec_path")

println("\n[DONE] run_conversation_test_c.jl complete.")
