#!/usr/bin/env julia
# =============================================================================
# GRUG THREAD-C v9.4 COMPREHENSIVE SPECIMEN TEST — Internal-state telemetry
# only, NO stdout scraping (per user directive: "dont use std hooks to log
# use in app measures std is slow"). Uses the MIGRATED specimen (thesaurus +
# anti-thesaurus sections updated to the new NegativeThesaurus pair-ledger
# spec) and replicates:
#   PART 1: The same 44 main turns as threadC_conversation_log_(1).md
#   PART 2: The same 8 multipart/compound-query decomposition turns
#   PART 3: The same 10 partial-knowledge clarification/teach turns
#   PART 4: NEW — math learning (procedural/computable teach), action
#           learning, routing self-improvement, and verb/synonym learning —
#           i.e. every self-improvement mechanism in the codebase, to
#           "cover all bases" per user request.
#
# All telemetry captured via direct module Refs (_LAST_VOICE_OUTPUT,
# _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE, LAST_VOTER_IDS,
# _conv_get_pending_teach_queue) exactly as done in run_conversation_test_c.jl
# / run_multipart_test_c.jl / run_multipart_teach_test.jl (the same scripts
# that produced the reference MD), NOT via println/stdout capture.
# =============================================================================

println("[BOOT] Loading GrugBot420 module …")
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420
using JSON

import .GrugBot420:
    save_specimen_to_file!, load_specimen_from_file!, process_mission,
    NODE_MAP, NODE_LOCK, GROUP_MAP, is_time_node,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    LAST_VOTER_IDS, LAST_VOTER_LOCK, _ENGINE_SIGIL_TABLE,
    _conv_get_pending_teach_queue, _conv_pending_teach_queue_size,
    _dict_define_word!, _dict_has_word,
    list_sigil_node_ids, node_sigil_kind, create_sigil_node,
    _set_last_routed_intent!, _get_last_routed_intent

import .GrugBot420: Lobe, LobeOrchestrator, InputDecomposer, MultipartOrchestrator
import .GrugBot420.Lobe: LOBE_REGISTRY, NODE_TO_LOBE_IDX
import .GrugBot420: Thesaurus, InputQueue, SemanticVerbs, ActionEngine, RoutingJudge

println("[BOOT] GrugBot420 module loaded.")

spec_path = joinpath(@__DIR__, "grug_threadC_multipart_final_migrated.specimen")
println("[BOOT] Loading MIGRATED specimen: $spec_path")
load_result = load_specimen_from_file!(spec_path)
println("[BOOT] Specimen loaded.")
println("[BOOT] NegativeThesaurus pair ledger count: ", InputQueue.synonym_exception_count())
for e in InputQueue.list_synonym_exceptions()
    println("    ", e.word, " <-> ", e.synonym, " (bidir=", e.bidirectional, ")")
end

# ── Snapshot engine config (Engine Configuration section) ───────────────────
function snapshot_engine_config()
    total_nodes  = length(NODE_MAP)
    total_groups = length(GROUP_MAP)
    total_lobes  = length(Lobe.LOBE_REGISTRY)
    total_sigils = length(_ENGINE_SIGIL_TABLE.entries)
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

# ── Helper: run process_mission and collect pure internal-state telemetry ──
function run_turn(you_text::String)
    process_mission(you_text)

    output       = lock(() -> _LAST_VOICE_OUTPUT[], _LAST_VOICE_OUTPUT_LOCK)
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
        "n_voters" => length(voter_ids),
        "lobe_curve" => lobe_curve,
    )
end

# =============================================================================
# PART 1: The same 44 main turns
# =============================================================================
turns = String[
    "Hey Grug, what do you know about fire?",
    "Tell me about water.",
    "How does gravity work?",
    "Why does fire burn, Grug?",
    "Why is the sky blue?",
    "Why do we feel sad sometimes?",
    "Define gravity for me.",
    "What is an atom?",
    "Is fire dangerous?",
    "What about deep water?",
    "I feel sad today, Grug.",
    "I'm scared of what's coming.",
    "I feel so lonely.",
    "What is 2 plus 2?",
    "What is 3 times 4?",
    "What is 10 minus 3?",
    "What comes before the present?",
    "Tell me about spring and summer.",
    "Heat causes evaporation.",
    "Clouds are in the sky.",
    "A tree has branches.",
    "How do I make fire?",
    "How do I find water?",
    "Flame combust wood.",
    "Forage for berries.",
    "Construct a shelter.",
    "Fire makes me feel warm and safe.",
    "I need shelter from the cold.",
    "Person feels music.",
    "Spring season.",
    "Friendship brings joy.",
    "Cooperation builds trust.",
    "Wrong bad incorrect stuff.",
    "Fake false nonsense.",
    "Cooking food makes it safe.",
    "Tell me about volcanoes again.",
    "Volcanoes erupt hot lava.",
    "Thunderstorms bring lightning.",
    "fire",
    "What is water?",
    "Define happiness.",
    "I miss someone.",
    "What comes after winter?",
    "Thank you Grug, you've been helpful.",
]

part1_results = Vector{Dict{String,Any}}()
for (i, t) in enumerate(turns)
    println("\n[TURN $i] YOU: $t")
    r = run_turn(t)
    println("[TURN $i] RAW: $(r["raw_output"])")
    println("[TURN $i] fired_node=$(r["fired_node"]) pattern=$(r["node_pattern"]) mode=$(r["node_answer_mode"]) conf=$(r["confidence"])")
    push!(part1_results, r)
end

final_cfg_p1 = snapshot_engine_config()
println("\n[DONE PART 1] Final config: nodes=$(final_cfg_p1.total_nodes) groups=$(final_cfg_p1.total_groups)")

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

# =============================================================================
# PART 2: The same 8 multipart/compound-query turns
# =============================================================================
function inspect_decomposition(you_text::String)
    subs = InputDecomposer.decompose_input(you_text)
    is_compound = length(subs) > 1
    parts_out = Vector{Dict{String,Any}}()
    for s in subs
        push!(parts_out, Dict{String,Any}(
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
        "sub_subjects" => parts_out,
        "summary" => summary,
    )
end

multipart_turns = String[
    "What is fire also what is water?",
    "Why does fire burn also why is the sky blue?",
    "What is 2 plus 2 also what is 3 times 4?",
    "What is gravity also I feel sad today?",
    "What is 2 plus 2 also what is gravity also what is water?",
    "Tell me about fire and tell me about volcanoes?",
    "Bread and butter are tasty.",
    "Fire and water are both natural elements.",
]
mp_annotations = String[
    "MP1: two independent question clauses joined by \"also\"",
    "MP2: two \"why\" explain-clauses joined by \"also\"",
    "MP3: two arithmetic sigil expressions joined by \"also\"",
    "MP4: cross-lobe compound — science question + emotional statement",
    "MP5: THREE-part compound (arithmetic + science + reason)",
    "MP6: imperative \"tell me about X and tell me about Y\" compound",
    "CTRL1: conjunction joins ONE subject, no question markers — expect NOT compound",
    "CTRL2: conjunction joins a single predicate — expect NOT compound",
]

part2_results = Vector{Dict{String,Any}}()
for (i, t) in enumerate(multipart_turns)
    println("\n[MPTURN $i] YOU: $t")
    decomp = inspect_decomposition(t)
    println("[MPTURN $i] DECOMP: $(decomp["summary"])")
    r = run_turn(t)
    println("[MPTURN $i] RAW: $(r["raw_output"])")
    merged = merge(r, Dict{String,Any}(
        "annotation" => mp_annotations[i],
        "decomposition" => decomp,
    ))
    push!(part2_results, merged)
end

# =============================================================================
# PART 3: The same 10 partial-knowledge clarification/teach turns
# =============================================================================
function run_teach_turn(you_text::String)
    process_mission(you_text)
    output = lock(() -> _LAST_VOICE_OUTPUT[], _LAST_VOICE_OUTPUT_LOCK)
    queue = _conv_get_pending_teach_queue()
    return Dict{String,Any}(
        "you" => you_text,
        "raw_output" => output,
        "pending_queue_size" => length(queue),
        "pending_queue_topics" => [get(e, "topic", "") for e in queue],
    )
end

part3_results = Vector{Dict{String,Any}}()
function log_teach!(label::String, you_text::String)
    r = run_teach_turn(you_text)
    r["label"] = label
    println("\n[$label] YOU: $you_text")
    println("[$label] GRUG: $(r["raw_output"])")
    println("[$label] pending_queue=$(r["pending_queue_topics"])")
    push!(part3_results, r)
    return r
end

log_teach!("S1-Q", "What is glorbnak and what is snarfum?")
log_teach!("S1-TEACH1", "biology, a small furry cave creature")
log_teach!("S1-TEACH2", "biology, a glowing cave mushroom")

_dict_define_word!("default", "brontosaurus", "a giant long-necked plant-eating dinosaur")
log_teach!("S2-Q", "What is brontosaurus and what is quaggleworth?")
log_teach!("S2-TEACH", "nature, a rare purple flower that blooms at night")

log_teach!("S3-Q", "What is fexbolt and what is trundlewick and what is ozzmire?")
log_teach!("S3-TEACH1", "technology, a small tool grug uses to sharpen rocks")
log_teach!("S3-TEACH2", "nature, a slow rolling stone that moves downhill")
log_teach!("S3-TEACH3", "nature, a misty swamp full of strange sounds")

_dict_define_word!("default", "gather", "to collect food or items from the land")
Thesaurus.add_seed_synonym!("gather", ["forage"])
log_teach!("S4-Q", "What is forage and what is zubrinthax?")
log_teach!("S4-TEACH", "nature, a tall spiky plant found near rivers")

# =============================================================================
# PART 4: NEW — test ALL learning methods (math, action, routing, verb/synonym)
# =============================================================================
part4_results = Dict{String,Any}()

# ── 4a. MATH/PROCEDURAL LEARNING: teach a NEW computable arithmetic procedure
#        and verify a REAL working callback was compiled (held-out inputs).
println("\n\n" * "="^70)
println("PART 4a: MATH LEARNING (conversational procedural teach)")
println("="^70)

math_topic = "gorbling"
r_math_q = run_teach_turn("what is $math_topic")
println("[MATH-Q] $(r_math_q["raw_output"])")
r_math_teach = run_teach_turn("math, multiply n by 3 and subtract 2")
println("[MATH-TEACH] $(r_math_teach["raw_output"])")

math_action_ids = list_sigil_node_ids(:action)
math_found_nid = nothing
lock(NODE_LOCK) do
    for nid in math_action_ids
        if haskey(NODE_MAP, nid) && occursin(math_topic, lowercase(NODE_MAP[nid].pattern))
            global math_found_nid = nid
        end
    end
end
math_cb_name = ""
math_held_out_7 = nothing
math_held_out_100 = nothing
if math_found_nid !== nothing
    lock(NODE_LOCK) do
        global math_cb_name = String(get(NODE_MAP[math_found_nid].json_data, "action_callback", ""))
    end
    if !isempty(math_cb_name)
        import .GrugBot420.SigilPromoter: SigilBinding
        # SigilBinding(position, name, value, class, surface, raw_position)
        mk_binding(n) = [SigilBinding(0, "n", n, :lambda, string(n), 0)]
        r7 = ActionEngine.compute_action(math_cb_name, mk_binding(7))
        r100 = ActionEngine.compute_action(math_cb_name, mk_binding(100))
        global math_held_out_7 = r7.answer
        global math_held_out_100 = r100.answer
        println("[MATH-VERIFY] $(math_topic)(7) [held-out] = $(r7.answer) (expect 19)")
        println("[MATH-VERIFY] $(math_topic)(100) [held-out] = $(r100.answer) (expect 298)")
    end
end
r_math_use = run_turn("what is $math_topic of 7")
println("[MATH-USE] $(r_math_use["raw_output"])")

part4_results["math_learning"] = Dict{String,Any}(
    "topic" => math_topic,
    "teach_ack" => r_math_teach["raw_output"],
    "action_node_created" => math_found_nid !== nothing,
    "callback_name" => math_cb_name,
    "held_out_7" => math_held_out_7,
    "held_out_100" => math_held_out_100,
    "usage_reply" => r_math_use["raw_output"],
)

# ── 4b. CONSERVATIVE FALLBACK: non-computable procedure prose still creates
#         a descriptive :procedural node, NOT a bogus computable action node.
println("\n" * "="^70)
println("PART 4b: MATH LEARNING — CONSERVATIVE FALLBACK (non-computable prose)")
println("="^70)
fallback_topic = "flibberwocking"
r_fb_q = run_teach_turn("what is $fallback_topic")
println("[FALLBACK-Q] $(r_fb_q["raw_output"])")
r_fb_teach = run_teach_turn("math, the steps to do this are gather all the small pebbles and sort by how shiny they look")
println("[FALLBACK-TEACH] $(r_fb_teach["raw_output"])")

fb_action_ids = list_sigil_node_ids(:action)
fb_found_action = false
lock(NODE_LOCK) do
    for nid in fb_action_ids
        if haskey(NODE_MAP, nid) && occursin(fallback_topic, lowercase(NODE_MAP[nid].pattern))
            global fb_found_action = true
        end
    end
end
fb_proc_ids = list_sigil_node_ids(:procedural)
fb_found_proc = false
lock(NODE_LOCK) do
    for nid in fb_proc_ids
        if haskey(NODE_MAP, nid) && occursin(fallback_topic, lowercase(NODE_MAP[nid].pattern))
            global fb_found_proc = true
        end
    end
end
println("[FALLBACK-VERIFY] computable action node created? $fb_found_action (expect false)")
println("[FALLBACK-VERIFY] descriptive procedural node created? $fb_found_proc (expect true)")

part4_results["math_conservative_fallback"] = Dict{String,Any}(
    "topic" => fallback_topic,
    "teach_ack" => r_fb_teach["raw_output"],
    "computable_action_node_created" => fb_found_action,
    "descriptive_procedural_node_created" => fb_found_proc,
)

# ── 4c. ACTION LEARNING: teach a second, DIFFERENT computable procedure to
#         prove this isn't a one-shot fluke, and exercise a built-in action
#         callback (factorial) for comparison/regression.
println("\n" * "="^70)
println("PART 4c: ACTION LEARNING — second distinct procedure + built-in check")
println("="^70)
action_topic = "quadrupling_thing"
r_act_q = run_teach_turn("what is $action_topic")
println("[ACTION-Q] $(r_act_q["raw_output"])")
r_act_teach = run_teach_turn("math, multiply n by 4")
println("[ACTION-TEACH] $(r_act_teach["raw_output"])")

act_action_ids = list_sigil_node_ids(:action)
act_found_nid = nothing
lock(NODE_LOCK) do
    for nid in act_action_ids
        if haskey(NODE_MAP, nid) && occursin(action_topic, lowercase(NODE_MAP[nid].pattern))
            global act_found_nid = nid
        end
    end
end
act_cb_name = ""
act_held_out_9 = nothing
if act_found_nid !== nothing
    lock(NODE_LOCK) do
        global act_cb_name = String(get(NODE_MAP[act_found_nid].json_data, "action_callback", ""))
    end
    if !isempty(act_cb_name)
        mk_binding2(n) = [SigilBinding(0, "n", n, :lambda, string(n), 0)]
        r9 = ActionEngine.compute_action(act_cb_name, mk_binding2(9))
        global act_held_out_9 = r9.answer
        println("[ACTION-VERIFY] $(action_topic)(9) [held-out] = $(r9.answer) (expect 36)")
    end
end

# built-in factorial regression check
r_fact = run_turn("what is factorial of 5")
println("[BUILTIN-FACTORIAL] $(r_fact["raw_output"])")

part4_results["action_learning"] = Dict{String,Any}(
    "topic" => action_topic,
    "teach_ack" => r_act_teach["raw_output"],
    "action_node_created" => act_found_nid !== nothing,
    "callback_name" => act_cb_name,
    "held_out_9" => act_held_out_9,
    "builtin_factorial_reply" => r_fact["raw_output"],
)

# ── 4d. ROUTING SELF-IMPROVEMENT: record outcomes via RoutingJudge and prove
#         effective_bias() shifts, persists across save/load, and resets on wipe.
println("\n" * "="^70)
println("PART 4d: ROUTING SELF-IMPROVEMENT")
println("="^70)
RoutingJudge.reset_bias_adjustments!()
bias_before = RoutingJudge.effective_bias(:calculate)
println("[ROUTING] bias(:calculate) before any feedback = $bias_before")
for _ in 1:5
    RoutingJudge.record_routing_outcome!(:calculate, true)
end
bias_after_correct = RoutingJudge.effective_bias(:calculate)
println("[ROUTING] bias(:calculate) after 5x correct feedback = $bias_after_correct")
for _ in 1:10
    RoutingJudge.record_routing_outcome!(:calculate, false)
end
bias_after_wrong = RoutingJudge.effective_bias(:calculate)
println("[ROUTING] bias(:calculate) after 10x incorrect feedback (clamp test) = $bias_after_wrong")

# exercise real conversational routing tracking
run_turn("What is 9 plus 9?")
last_kind = _get_last_routed_intent()
println("[ROUTING] _get_last_routed_intent() after arithmetic turn = $last_kind")

part4_results["routing_selfimprovement"] = Dict{String,Any}(
    "bias_before" => bias_before,
    "bias_after_5x_correct" => bias_after_correct,
    "bias_after_10x_incorrect_clamped" => bias_after_wrong,
    "last_routed_intent_after_arith_turn" => string(last_kind),
)

# ── 4e. VERB / SYNONYM LEARNING (SemanticVerbs + Thesaurus)
println("\n" * "="^70)
println("PART 4e: VERB / SYNONYM LEARNING")
println("="^70)
verb_classes_before = SemanticVerbs.get_relation_classes()
println("[VERB] relation classes before: $(length(verb_classes_before))")
SemanticVerbs.add_relation_class!("thermal_test_class")
SemanticVerbs.add_verb!("scorches", "thermal_test_class")
verb_classes_after = SemanticVerbs.get_relation_classes()
println("[VERB] relation classes after adding 'thermal_test_class': $(length(verb_classes_after))")
verb_class_of_scorches = SemanticVerbs.verb_class_of("scorches")
println("[VERB] verb_class_of(\"scorches\") = $verb_class_of_scorches (expect thermal_test_class)")

SemanticVerbs.add_synonym!("scorches", "chars")
println("[VERB] synonym registered: chars -> scorches")

thesaurus_before = Thesaurus.seed_synonym_count()
Thesaurus.add_seed_synonym!("blaze", ["conflagration_test_synonym"])
thesaurus_after = Thesaurus.seed_synonym_count()
println("[THESAURUS] word count before=$(thesaurus_before) after=$(thesaurus_after)")

# NegativeThesaurus pair ledger: add a NEW edge case at runtime, verify gate.
InputQueue.add_synonym_exception!("bright", "incandescent"; reason="incandescent implies heat-based light source specifically, bright is general — register mismatch test", bidirectional=true)
neg_pairs_after_add = InputQueue.synonym_exception_count()
println("[NEGTHESAURUS] pair count after runtime add = $neg_pairs_after_add (expect 5)")
is_blocked_check = InputQueue.is_synonym_blocked("bright", "incandescent")
println("[NEGTHESAURUS] is_synonym_blocked(bright, incandescent) = $is_blocked_check (expect true)")

part4_results["verb_synonym_learning"] = Dict{String,Any}(
    "relation_classes_before" => length(verb_classes_before),
    "relation_classes_after" => length(verb_classes_after),
    "verb_class_of_scorches" => string(verb_class_of_scorches),
    "thesaurus_words_before" => thesaurus_before,
    "thesaurus_words_after" => thesaurus_after,
    "neg_thesaurus_pairs_after_runtime_add" => neg_pairs_after_add,
    "is_synonym_blocked_check" => is_blocked_check,
)

# ── 4f. SAVE/LOAD ROUND-TRIP OF ALL NEW LEARNING STATE ──────────────────────
println("\n" * "="^70)
println("PART 4f: SAVE/LOAD ROUND-TRIP VERIFICATION (all new learning state)")
println("="^70)
roundtrip_path = joinpath(@__DIR__, "threadC_v94_roundtrip.specimen")
save_specimen_to_file!(roundtrip_path)
println("[ROUNDTRIP] Saved to $roundtrip_path")

# Capture pre-reload state
pre_bias = RoutingJudge.effective_bias(:calculate)
pre_neg_count = InputQueue.synonym_exception_count()
pre_verb_classes = length(SemanticVerbs.get_relation_classes())
pre_math_cb_exists = ActionEngine.has_action_callback(math_cb_name)

load_specimen_from_file!(roundtrip_path)

post_bias = RoutingJudge.effective_bias(:calculate)
post_neg_count = InputQueue.synonym_exception_count()
post_verb_classes = length(SemanticVerbs.get_relation_classes())
post_math_cb_exists = ActionEngine.has_action_callback(math_cb_name)
# action callbacks are in-process Function registry, NOT specimen-persisted
# (only the node + callback NAME persist; the callback itself is re-derived
# from parse_arith_expr at... NO — actually action callbacks are registered
# at teach-time only, not restored from specimen on load, since specimen
# does not store the ops chain. This is an intentional current limitation.)

r_math_after_reload = run_turn("what is $math_topic of 7")
println("[ROUNDTRIP-MATH-USE-AFTER-RELOAD] $(r_math_after_reload["raw_output"])")

part4_results["roundtrip_verification"] = Dict{String,Any}(
    "routing_bias_matches" => (pre_bias == post_bias),
    "pre_bias" => pre_bias,
    "post_bias" => post_bias,
    "neg_thesaurus_pairs_matches" => (pre_neg_count == post_neg_count),
    "pre_neg_count" => pre_neg_count,
    "post_neg_count" => post_neg_count,
    "verb_classes_matches" => (pre_verb_classes == post_verb_classes),
    "math_callback_survives_reload_in_process" => post_math_cb_exists,
    "math_use_reply_after_reload" => r_math_after_reload["raw_output"],
)

# =============================================================================
# DUMP EVERYTHING TO JSON
# =============================================================================
out = Dict{String,Any}(
    "initial_cfg" => Dict(
        "total_nodes" => initial_cfg.total_nodes,
        "total_groups" => initial_cfg.total_groups,
        "total_lobes" => initial_cfg.total_lobes,
        "total_sigils" => initial_cfg.total_sigils,
        "sigil_node_count" => initial_cfg.sigil_node_count,
        "lobe_rows" => [Dict("lobe"=>r[1],"nodes"=>r[2],"aiml"=>r[3]) for r in initial_cfg.lobe_rows],
    ),
    "final_cfg_p1" => Dict(
        "total_nodes" => final_cfg_p1.total_nodes,
        "total_groups" => final_cfg_p1.total_groups,
        "total_lobes" => final_cfg_p1.total_lobes,
        "total_sigils" => final_cfg_p1.total_sigils,
        "sigil_node_count" => final_cfg_p1.sigil_node_count,
        "lobe_rows" => [Dict("lobe"=>r[1],"nodes"=>r[2],"aiml"=>r[3]) for r in final_cfg_p1.lobe_rows],
    ),
    "part1_turns" => part1_results,
    "time_node_isolation" => Dict("regular"=>tni.regular, "time_groups"=>tni.time_groups, "mixed"=>tni.mixed),
    "top10" => [Dict("id"=>t[1], "pattern"=>t[2], "strength"=>t[3]) for t in top10],
    "sigils" => sigils,
    "part2_multipart_turns" => part2_results,
    "part3_teach_turns" => part3_results,
    "part4_learning_methods" => part4_results,
)

out_path = joinpath(@__DIR__, "threadC_v94_comprehensive_telemetry.json")
open(out_path, "w") do io
    JSON.print(io, out, 2)
end
println("\n[SAVED] Comprehensive telemetry JSON -> $out_path")

final_spec_path = joinpath(@__DIR__, "grug_threadC_v94_final.specimen")
save_specimen_to_file!(final_spec_path)
println("[SAVED] Final specimen -> $final_spec_path")

println("\n[DONE] run_threadC_comprehensive_v94.jl complete.")
