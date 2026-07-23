#!/usr/bin/env julia
# =============================================================================
# GRUG THREAD-C MULTIPART/COMPOUND-QUERY TEST — Internal-state telemetry only,
# NO stdout scraping. Loads grug_threadC_final.specimen (post-44-turn state),
# runs a set of compound/multipart inputs designed to trigger
# InputDecomposer.decompose_input's compound heuristics (conjunction +
# independent-clause / multi-question-mark / sigil boundary), captures BOTH
# the true decomposition structure (direct function call into the loaded
# module — real internal state, not console scraping) AND the actual
# synthesized voice reply + fired-node telemetry per turn.
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

import .GrugBot420: Lobe, LobeOrchestrator, InputDecomposer, MultipartOrchestrator
import .GrugBot420.Lobe: LOBE_REGISTRY, NODE_TO_LOBE_IDX

println("[BOOT] GrugBot420 module loaded.")

spec_path = joinpath(@__DIR__, "grug_threadC_final.specimen")
println("[BOOT] Loading specimen: $spec_path")
load_result = load_specimen_from_file!(spec_path)
println("[BOOT] Specimen loaded: ", load_result)

# ── Helper: get TRUE decomposition structure via direct module call ────────
# This is a real function call into the same InputDecomposer module state
# (including any specimen-owned DecomposerConfig overrides already loaded)
# that process_mission itself invokes internally. Not a stdout scrape.
function inspect_decomposition(you_text::String)
    subs = InputDecomposer.decompose_input(you_text)
    is_compound = length(subs) > 1
    parts = Vector{Dict{String,Any}}()
    for s in subs
        push!(parts, Dict{String,Any}(
            "text" => s.text,
            "multipart_group" => s.multipart_group,
            "role" => string(s.role),
            "index" => s.index,
        ))
    end
    summary = InputDecomposer.summarize_decomposition(subs)
    return Dict{String,Any}(
        "is_compound" => is_compound,
        "n_subjects" => length(subs),
        "sub_subjects" => parts,
        "summary" => summary,
    )
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
        end
    end

    return Dict{String,Any}(
        "you" => you_text,
        "raw_output" => output,
        "fired_node" => fired_node,
        "node_pattern" => node_pattern,
        "node_strength" => node_strength,
        "node_type" => node_type,
        "node_answer_mode" => get(node_data, "answer_mode", ""),
        "primary_action" => primary_act,
        "confidence" => confidence,
        "voter_ids" => voter_ids,
        "n_voters" => length(voter_ids),
        "lobe_curve" => lobe_curve,
    )
end

# ── Multipart test turns ────────────────────────────────────────────────────
# Designed per InputDecomposer heuristics: conjunction ("also"/"and") joining
# TWO INDEPENDENT CLAUSES, each with its own question marker/imperative
# structure, using topics already grown as real nodes in the specimen
# (fire, water, gravity, sky/science, sadness, arithmetic, volcanoes) so each
# sub-subject resolves to an actual answer instead of falling into
# autogrowth fallback. Two CONTROL turns are included (conjunction joining a
# SINGLE subject, no question markers) to prove the heuristic correctly
# does NOT split those — demonstrating selectivity, not just eagerness.
multipart_turns = String[
    "What is fire also what is water?",                                  # MP1: 2-part define/reason, same lobe family
    "Why does fire burn also why is the sky blue?",                      # MP2: 2-part explain/science
    "What is 2 plus 2 also what is 3 times 4?",                          # MP3: 2-part arithmetic sigil boundary
    "What is gravity also I feel sad today?",                            # MP4: 2-part cross-lobe (science + comfort/emotions)
    "What is 2 plus 2 also what is gravity also what is water?",         # MP5: 3-part mixed arithmetic+science+reason
    "Tell me about fire and tell me about volcanoes?",                   # MP6: imperative-style compound (command markers)
    "Bread and butter are tasty.",                                       # CTRL1: single subject conjunction, NOT compound
    "Fire and water are both natural elements.",                         # CTRL2: single subject conjunction, NOT compound
]

annotations = String[
    "MP1: two independent question clauses joined by \"also\" — expect is_compound=true, 2 sub-subjects (mp_1 fire, mp_2 water)",
    "MP2: two \"why\" explain-clauses joined by \"also\" — expect is_compound=true, 2 sub-subjects (fire-burn, sky-blue)",
    "MP3: two arithmetic sigil expressions joined by \"also\" — expect is_compound=true, 2 sub-subjects, each own arithmetic result",
    "MP4: cross-lobe compound — science question + emotional statement joined by \"also\" — expect is_compound=true, 2 sub-subjects spanning different lobes",
    "MP5: THREE-part compound (arithmetic + science + reason) — expect is_compound=true, 3 sub-subjects (mp_1/mp_2/mp_3)",
    "MP6: imperative \"tell me about X and tell me about Y\" compound — expect is_compound=true via command-marker + conjunction heuristic",
    "CTRL1: \"bread and butter\" — conjunction joins ONE subject (a food pairing), no question markers on both sides — expect is_compound=false (heuristic correctly refuses to split)",
    "CTRL2: \"fire and water are both natural elements\" — conjunction joins a single predicate about two nouns treated as ONE clause/subject, no independent question structure — expect is_compound=false",
]

results = Vector{Dict{String,Any}}()
for (i, t) in enumerate(multipart_turns)
    println("\n[MPTURN $i] YOU: $t")
    decomp = inspect_decomposition(t)
    println("[MPTURN $i] DECOMP: $(decomp["summary"])")
    r = run_turn(t)
    println("[MPTURN $i] RAW: $(r["raw_output"])")
    println("[MPTURN $i] voters=$(r["voter_ids"]) fired=$(r["fired_node"]) conf=$(r["confidence"])")
    merged = merge(r, Dict{String,Any}(
        "annotation" => annotations[i],
        "decomposition" => decomp,
    ))
    push!(results, merged)
end

# ── Dump raw telemetry to JSON ──────────────────────────────────────────────
out = Dict{String,Any}(
    "multipart_turns" => results,
)
out_path = joinpath(@__DIR__, "threadC_multipart_telemetry.json")

try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endout_path, "w") do io
    JSON.print(io, out, 2)
end
println("\n[SAVED] Multipart raw telemetry JSON -> $out_path")

# ── Save post-multipart-test specimen ───────────────────────────────────────
final_spec_path = joinpath(@__DIR__, "grug_threadC_multipart_final.specimen")
save_specimen_to_file!(final_spec_path)
println("[SAVED] Final specimen -> $final_spec_path")

println("\n[DONE] run_multipart_test_c.jl complete.")
