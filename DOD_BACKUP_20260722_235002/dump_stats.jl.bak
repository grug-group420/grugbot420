#!/usr/bin/env julia
# =============================================================================
# Dump stats from a specimen build (no missions)
# =============================================================================
using Pkg
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
Pkg.activate(joinpath(@__DIR__, ".."))
ENV["GRUG_NO_AUTOLOAD"] = "1"
include(joinpath(@__DIR__, "..", "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420: grow_nodes_from_packet, attach_node!,
    add_orchestration_rule!, ORCHESTRATION_RULES,
    Lobe, EyeSystem, SemanticVerbs, RelationalJitter, InputDecomposer,
    HippocampalModulator, AIMLNodeSystem,
    NODE_MAP, NODE_LOCK, ATTACHMENT_MAP, ATTACHMENT_LOCK,
    HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK

RelationalJitter.disable_jitter!()

# Build specimen
lobes_config = [
    ("math", "Pure mathematics — algebra, calculus, geometry, logic"),
    ("science", "Natural sciences — physics, chemistry, biology"),
    ("philosophy", "Abstract thought — epistemology, ethics, metaphysics"),
    ("conversation", "General conversation — greetings, small talk, meta-questions"),
]
for (lid, subj) in lobes_config
    Lobe.create_lobe!(lid, subj)
end
Lobe.connect_lobes!("math", "science")
Lobe.connect_lobes!("science", "philosophy")
Lobe.connect_lobes!("philosophy", "conversation")

math_nodes = """
{"nodes":[{"pattern":"calculus derivative rate of change slope tangent","action_packet":"explain^5 | analyze^4 | validate^3","data":{"system_prompt":"You are a calculus tutor.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"integration integral area under curve antiderivative","action_packet":"calculate^5 | explain^4 | elaborate^3","data":{"system_prompt":"You are an integration specialist.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"algebra equation solve variable unknown linear quadratic","action_packet":"calculate^5 | clarify^4 | validate^3","data":{"system_prompt":"You are an algebra tutor.","required_relations":["applies_to","solves"],"relation_weights":{"applies_to":2.0,"solves":2.5}}},{"pattern":"geometry triangle circle polygon area perimeter angle","action_packet":"calculate^5 | reason^4 | elaborate^3","data":{"system_prompt":"You are a geometry specialist.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.0,"describes":2.0}}}]}
"""
ids_math = grow_nodes_from_packet(math_nodes; target_lobe="math")

science_nodes = """
{"nodes":[{"pattern":"physics force motion newton gravity acceleration mass","action_packet":"analyze^5 | ponder^4 | explain^3","data":{"system_prompt":"You are a physics tutor.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}},{"pattern":"chemistry element atom molecule bond reaction periodic","action_packet":"define^5 | calculate^4 | ponder^3","data":{"system_prompt":"You are a chemistry tutor.","required_relations":["applies_to","composes"],"relation_weights":{"applies_to":2.0,"composes":2.5}}},{"pattern":"biology cell DNA gene evolution organism species","action_packet":"describe^5 | analyze^4 | reason^3","data":{"system_prompt":"You are a biology tutor.","required_relations":["applies_to","evolves"],"relation_weights":{"applies_to":2.0,"evolves":2.5}}},{"pattern":"quantum mechanics wave particle heisenberg uncertainty superposition","action_packet":"explain^5 | analyze^4 | calculate^3","data":{"system_prompt":"You are a quantum physics specialist.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}}]}
"""
ids_science = grow_nodes_from_packet(science_nodes; target_lobe="science")

phil_nodes = """
{"nodes":[{"pattern":"epistemology knowledge truth belief justification evidence","action_packet":"ponder^5 | reason^4 | validate^3","data":{"system_prompt":"You are an epistemology tutor.","required_relations":["examines","justifies"],"relation_weights":{"examines":2.5,"justifies":2.0}}},{"pattern":"ethics moral right wrong good evil duty virtue","action_packet":"validate^5 | reason^4 | analyze^3","data":{"system_prompt":"You are an ethics tutor.","required_relations":["evaluates","prescribes"],"relation_weights":{"evaluates":2.5,"prescribes":2.0}}},{"pattern":"metaphysics reality existence being consciousness free will","action_packet":"ponder^5 | reason^4 | elaborate^3","data":{"system_prompt":"You are a metaphysics tutor.","required_relations":["examines","questions"],"relation_weights":{"examines":2.0,"questions":2.5}}},{"pattern":"logic reasoning argument fallacy syllogism deduction induction","action_packet":"analyze^5 | validate^4 | elaborate^3","data":{"system_prompt":"You are a logic tutor.","required_relations":["analyzes","evaluates"],"relation_weights":{"analyzes":2.5,"evaluates":2.0}}}]}
"""
ids_phil = grow_nodes_from_packet(phil_nodes; target_lobe="philosophy")

conv_nodes = """
{"nodes":[{"pattern":"hello hi hey good morning greetings howdy welcome","action_packet":"greet^5 | welcome^4 | acknowledge^3","data":{"system_prompt":"You are a friendly conversationalist.","required_relations":[],"relation_weights":{}}},{"pattern":"what are you who are you what can you do capabilities","action_packet":"explain^5 | describe^4 | elaborate^3","data":{"system_prompt":"You are explaining yourself. You are GrugBot.","required_relations":[],"relation_weights":{}}},{"pattern":"thank thanks appreciate gratitude goodbye bye farewell","action_packet":"acknowledge^5 | comfort^4 | clarify^3","data":{"system_prompt":"You are a polite conversationalist.","required_relations":[],"relation_weights":{}}},{"pattern":"tell me about explain describe what is how does overview","action_packet":"explain^5 | describe^4 | analyze^3","data":{"system_prompt":"You are a general knowledge explainer.","required_relations":["describes","explains"],"relation_weights":{"describes":2.0,"explains":2.5}}}]}
"""
ids_conv = grow_nodes_from_packet(conv_nodes; target_lobe="conversation")

if length(ids_math) >= 1 && length(ids_science) >= 1
    attach_node!(ids_math[1], ids_science[1], "rate of change force acceleration derivative velocity")
end
if length(ids_science) >= 4 && length(ids_phil) >= 3
    attach_node!(ids_science[4], ids_phil[3], "quantum reality consciousness observation measurement")
end
if length(ids_math) >= 3 && length(ids_math) >= 1
    attach_node!(ids_math[3], ids_math[1], "equation solve derivative limit function variable")
end
if length(ids_science) >= 3 && length(ids_science) >= 2
    attach_node!(ids_science[3], ids_science[2], "molecular bond protein DNA reaction organic")
end
if length(ids_phil) >= 2 && length(ids_phil) >= 4
    attach_node!(ids_phil[2], ids_phil[4], "reasoning argument evaluation fallacy justification")
end

for (lid, _) in lobes_config
    AIMLNodeSystem.register_lobe!(lid, Lobe.LOBE_NODE_CAP)
end
for (lobe_id, node_id, template) in [
    ("math", "aiml_calculus", "Calculus is the mathematics of CHANGE."),
    ("science", "aiml_newton", "Newton's three laws govern mechanics."),
    ("philosophy", "aiml_epistemology", "Epistemology asks: How do we know?"),
    ("conversation", "aiml_greeting", "Hey there! I'm GrugBot."),
]
    AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template)
end

for cls in ["cognition", "action", "communication"]
    SemanticVerbs.add_relation_class!(cls)
end
for (verb, cls) in [("analyze","cognition"),("explain","cognition"),("validate","cognition"),("ponder","cognition"),("calculate","action"),("reason","cognition"),("describe","communication"),("clarify","communication"),("define","cognition"),("elaborate","communication")]
    SemanticVerbs.add_verb!(verb, cls)
end
for (alias, canonical) in [("compute","calculate"),("examine","analyze"),("illuminate","explain"),("assess","validate"),("contemplate","ponder")]
    SemanticVerbs.add_synonym!(canonical, alias)
end

for rule_text in [
    "Your primary mission is {PRIMARY_ACTION}. Execute with full cognitive resources allocated.",
    "Ground every claim. {CONFIDENCE} determines assertion strength. Low confidence requires explicit qualification.",
    "Cross-domain synthesis activated. Identify connections across {LOBE_CONTEXT} to deepen understanding.",
    "Structure explanations hierarchically: overview → details → synthesis → implications.",
    "Use analogies carefully. State limitations before applying them.",
]
    GrugBot420.add_orchestration_rule!(rule_text)
end

# Now dump stats
println("\n=== LOBE REGISTRY ===")
for lid in sort(collect(keys(Lobe.LOBE_REGISTRY)))
    rec = Lobe.LOBE_REGISTRY[lid]
    n_nodes = length(rec.node_ids)
    n_connected = length(rec.connected_lobe_ids)
    println("  $(lid): subject=\"$(rec.subject)\", nodes=$(n_nodes), connected_to=$(n_connected) lobes, fires=$(rec.fire_count), inhibits=$(rec.inhibit_count)")
end

println("\n=== NODE CENSUS ===")
total_ref = Ref(0)
alive_ref = Ref(0)
grave_ref = Ref(0)
str_ref = Ref(0.0)
lobe_counts_ref = Ref(Dict{String, Int}())
lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        total_ref[] += 1
        if node.is_grave
            grave_ref[] += 1
        else
            alive_ref[] += 1
            str_ref[] += node.strength
        end
        lobe_id = get(Lobe.NODE_TO_LOBE_IDX, id, "unassigned")
        lobe_counts_ref[][lobe_id] = get(lobe_counts_ref[], lobe_id, 0) + 1
    end
end
println("  Total: $(total_ref[]), Alive: $(alive_ref[]), Grave: $(grave_ref[])")
avg = alive_ref[] > 0 ? round(str_ref[] / alive_ref[], digits=3) : 0.0
println("  Avg strength (alive): $(avg)")
println("  Per lobe:")
for (lid, count) in sort(collect(lobe_counts_ref[]))
    println("    $(lid): $(count)")
end

println("\n=== ATTACHMENT GRAPH ===")
total_att_ref = Ref(0)
lock(ATTACHMENT_LOCK) do
    for (target_id, atts) in ATTACHMENT_MAP
        n = length(atts)
        total_att_ref[] += n
        println("  $(target_id) → $(n) attachment(s): $([a.node_id for a in atts])")
    end
end
println("  Total edges: $(total_att_ref[])")

println("\n=== HOPFIELD CACHE ===")
n_cache_ref = Ref(0)
lock(HOPFIELD_CACHE_LOCK) do
    n_cache_ref[] = length(HOPFIELD_CACHE)
end
println("  Entries: $(n_cache_ref[])")

println("\n=== AIML STATUS ===")
try
    summary = AIMLNodeSystem.get_aiml_status_summary()
    for line in split(summary, "\n")
        cleaned = strip(replace(line, r"[║╔╗╚╝╠╣╬╦╩═]" => ""))
        if !isempty(cleaned)
            println("  $(cleaned)")
        end
    end
catch e
    println("  Failed: $e")
end

println("\n=== SEMANTIC VERBS ===")
for cls in sort(SemanticVerbs.get_relation_classes())
    verbs = SemanticVerbs.get_verbs_in_class(cls)
    println("  $(cls): $(join(sort(collect(verbs)), ", "))")
end
syns = SemanticVerbs.get_synonym_map()
if !isempty(syns)
    println("  Synonyms:")
    for (alias, canonical) in sort(collect(syns))
        println("    $(alias) → $(canonical)")
    end
end

println("\n=== EYE SYSTEM ===")
println("  Arousal: $(round(EyeSystem.get_arousal(), digits=3))")

println("\n=== HIPPOCAMPAL MODULATOR ===")
try
    demo_log = HippocampalModulator.create_action_log!()
    println("  ActionLog type: $(typeof(demo_log))")
    println("  Empty log summary: $(HippocampalModulator.log_summary(demo_log))")
catch e
    println("  Failed: $e")
end

println("\n=== RELATIONAL JITTER ===")
println("  Enabled: $(RelationalJitter.is_jitter_enabled())")

println("\n=== INPUT DECOMPOSER ===")
test_input = "What is calculus and also explain Newton's laws and what is truth"
chunks = InputDecomposer.chunk_boundaries(test_input)
println("  Test: \"$(test_input)\"")
println("  $(length(chunks)) chunk(s):")
for ch in chunks
    println("    Chunk $(ch.chunk_index): tokens [$(ch.first_token)..$(ch.last_token)], text=\"$(first(ch.text, 50))$(length(ch.text) > 50 ? "..." : "")\"")
end

println("\n=== ORCHESTRATION RULES ===")
try
    println("  Active: $(length(ORCHESTRATION_RULES))")
    for (i, rule) in enumerate(ORCHESTRATION_RULES)
        println("    Rule $(i): prob=$(rule.fire_probability), text=\"$(first(rule.text, 70))$(length(rule.text) > 70 ? "..." : "")\"")
    end
catch e
    println("  Failed: $e")
end
