#!/usr/bin/env julia
# =============================================================================
# Run individual missions against the multi_lobe_v1 specimen.
# Usage: julia run_missions.jl <mission_number>
#   1 = "Hello! What can you do?"
#   2 = "Explain what a derivative is in calculus"
#   3 = "How does Newton's second law work?"
#   4 = "How does quantum physics relate to the nature of reality and consciousness"
#   5 = "Explain integration and antiderivatives"
#   6 = "What is the quadratic formula"
#   7 = "What is epistemology about"
# =============================================================================
using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

ENV["GRUG_NO_AUTOLOAD"] = "1"

include(joinpath(@__DIR__, "..", "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420: process_mission,
    grow_nodes_from_packet, attach_node!,
    add_orchestration_rule!, AIML_DROP_TABLE,
    Lobe, SemanticVerbs, RelationalJitter, AIMLNodeSystem,
    NODE_MAP, NODE_LOCK, ATTACHMENT_MAP, ATTACHMENT_LOCK,
    HOPFIELD_CACHE, HOPFIELD_CACHE_LOCK,
    LAST_VOTER_LOCK, LAST_CONTRIBUTOR_VOTES,
    LAST_CONTRIBUTOR_IDS, LAST_LOCKED_NODE_IDS,
    MESSAGE_HISTORY

RelationalJitter.disable_jitter!()

# --- Build specimen (same as build_specimen.jl) ---
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
{"nodes":[{"pattern":"calculus derivative rate of change slope tangent","action_packet":"explain^5 | analyze^4 | validate^3","data":{"system_prompt":"You are a calculus tutor. Explain derivatives from geometric intuition: slope of tangent line, then formal limit definition, then rules (power, chain, product). Connect to velocity and acceleration.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"integration integral area under curve antiderivative","action_packet":"calculate^5 | explain^4 | elaborate^3","data":{"system_prompt":"You are an integration specialist. Start with area interpretation, then antiderivatives, then computational techniques. Always connect to the fundamental theorem of calculus.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"algebra equation solve variable unknown linear quadratic","action_packet":"calculate^5 | clarify^4 | validate^3","data":{"system_prompt":"You are an algebra tutor. Solve equations step by step. Show factoring, substitution, and the quadratic formula. Verify solutions by substitution.","required_relations":["applies_to","solves"],"relation_weights":{"applies_to":2.0,"solves":2.5}}},{"pattern":"geometry triangle circle polygon area perimeter angle","action_packet":"calculate^5 | reason^4 | elaborate^3","data":{"system_prompt":"You are a geometry specialist. Explain shapes, areas, and proofs. Use visual reasoning. Connect to real-world applications like architecture and navigation.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.0,"describes":2.0}}}]}
"""
ids_math = grow_nodes_from_packet(math_nodes; target_lobe="math")

science_nodes = """
{"nodes":[{"pattern":"physics force motion newton gravity acceleration mass","action_packet":"analyze^5 | ponder^4 | explain^3","data":{"system_prompt":"You are a physics tutor specializing in classical mechanics. Explain Newton's laws, gravitational force, and motion. Use F=ma as the backbone. Connect to real examples like orbits and falling objects.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}},{"pattern":"chemistry element atom molecule bond reaction periodic","action_packet":"define^5 | calculate^4 | ponder^3","data":{"system_prompt":"You are a chemistry tutor. Explain atomic structure, bonding, and reactions. Balance equations. Connect periodic table trends to electron configuration.","required_relations":["applies_to","composes"],"relation_weights":{"applies_to":2.0,"composes":2.5}}},{"pattern":"biology cell DNA gene evolution organism species","action_packet":"describe^5 | analyze^4 | reason^3","data":{"system_prompt":"You are a biology tutor. Explain cell biology, genetics, and evolution. Connect DNA to protein synthesis, and natural selection to adaptation. Use tree-of-life framing.","required_relations":["applies_to","evolves"],"relation_weights":{"applies_to":2.0,"evolves":2.5}}},{"pattern":"quantum mechanics wave particle heisenberg uncertainty superposition","action_packet":"explain^5 | analyze^4 | calculate^3","data":{"system_prompt":"You are a quantum physics specialist. Explain wave-particle duality, the uncertainty principle, and superposition. Use the double-slit experiment as anchor. Connect to measurement problem.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}}]}
"""
ids_science = grow_nodes_from_packet(science_nodes; target_lobe="science")

phil_nodes = """
{"nodes":[{"pattern":"epistemology knowledge truth belief justification evidence","action_packet":"ponder^5 | reason^4 | validate^3","data":{"system_prompt":"You are an epistemology tutor. Explore how we know what we know. Discuss justified true belief, Gettier problems, and foundationalism vs coherentism. Always ask: how can you be sure?","required_relations":["examines","justifies"],"relation_weights":{"examines":2.5,"justifies":2.0}}},{"pattern":"ethics moral right wrong good evil duty virtue","action_packet":"validate^5 | reason^4 | analyze^3","data":{"system_prompt":"You are an ethics tutor. Compare utilitarianism, deontology, and virtue ethics. Apply frameworks to dilemmas. Distinguish descriptive from normative claims.","required_relations":["evaluates","prescribes"],"relation_weights":{"evaluates":2.5,"prescribes":2.0}}},{"pattern":"metaphysics reality existence being consciousness free will","action_packet":"ponder^5 | reason^4 | elaborate^3","data":{"system_prompt":"You are a metaphysics tutor. Explore the nature of reality, consciousness, and free will. Connect to the hard problem of consciousness. Acknowledge when answers are genuinely uncertain.","required_relations":["examines","questions"],"relation_weights":{"examines":2.0,"questions":2.5}}},{"pattern":"logic reasoning argument fallacy syllogism deduction induction","action_packet":"analyze^5 | validate^4 | elaborate^3","data":{"system_prompt":"You are a logic tutor. Identify argument structures, detect fallacies, and evaluate validity. Distinguish deductive from inductive reasoning. Use formal notation when helpful.","required_relations":["analyzes","evaluates"],"relation_weights":{"analyzes":2.5,"evaluates":2.0}}}]}
"""
ids_phil = grow_nodes_from_packet(phil_nodes; target_lobe="philosophy")

conv_nodes = """
{"nodes":[{"pattern":"hello hi hey good morning greetings howdy welcome","action_packet":"greet^5 | welcome^4 | acknowledge^3","data":{"system_prompt":"You are a friendly conversationalist. Greet warmly. Be natural and human. Ask how you can help. Keep it brief — this is a greeting, not a lecture.","required_relations":[],"relation_weights":{}}},{"pattern":"what are you who are you what can you do capabilities","action_packet":"explain^5 | describe^4 | elaborate^3","data":{"system_prompt":"You are explaining yourself. You are GrugBot, a neuromorphic AI with specialized lobes for math, science, philosophy, and conversation. You think in nodes that fire when patterns match, vote on answers, and self-reinforce. Be honest about what you are.","required_relations":[],"relation_weights":{}}},{"pattern":"thank thanks appreciate gratitude goodbye bye farewell","action_packet":"acknowledge^5 | comfort^4 | clarify^3","data":{"system_prompt":"You are a polite conversationalist acknowledging thanks or saying goodbye. Be warm but concise. If it's a farewell, summarize what was discussed if relevant.","required_relations":[],"relation_weights":{}}},{"pattern":"tell me about explain describe what is how does overview","action_packet":"explain^5 | describe^4 | analyze^3","data":{"system_prompt":"You are a general knowledge explainer. Give clear, structured explanations. Start with the big picture, then details. Use analogies when helpful. Acknowledge uncertainty honestly.","required_relations":["describes","explains"],"relation_weights":{"describes":2.0,"explains":2.5}}}]}
"""
ids_conv = grow_nodes_from_packet(conv_nodes; target_lobe="conversation")

# Attachments
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

# AIML
for (lid, _) in lobes_config
    AIMLNodeSystem.register_lobe!(lid, Lobe.LOBE_NODE_CAP)
end
aiml_entries = [
    ("math", "aiml_calculus", "Calculus is the mathematics of CHANGE. Derivative = rate of change at a point. Integral = accumulated change over an interval. Together they form the Fundamental Theorem of Calculus — differentiation and integration are inverse operations."),
    ("science", "aiml_newton", "Newton's three laws: 1) An object at rest stays at rest (inertia). 2) F=ma (force equals mass times acceleration). 3) Every action has an equal and opposite reaction. These govern everything from falling apples to orbiting planets."),
    ("philosophy", "aiml_epistemology", "Epistemology asks: How do we know what we know? The classical answer is Justified True Belief — you know P if P is true, you believe P, and you have justification. But Gettier problems show this isn't enough. Knowledge is harder than it looks."),
    ("conversation", "aiml_greeting", "Hey there! I'm GrugBot — a neuromorphic AI that thinks in nodes and votes. Each node is a pattern-matching torch in the cognitive cave. What can I illuminate for you?"),
]
for (lobe_id, node_id, template) in aiml_entries
    AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template)
end

# Semantic verbs
for cls in ["cognition", "action", "communication"]
    SemanticVerbs.add_relation_class!(cls)
end
for (verb, cls) in [("analyze","cognition"),("explain","cognition"),("validate","cognition"),("ponder","cognition"),("calculate","action"),("reason","cognition"),("describe","communication"),("clarify","communication"),("define","cognition"),("elaborate","communication")]
    SemanticVerbs.add_verb!(verb, cls)
end
for (alias, canonical) in [("compute","calculate"),("examine","analyze"),("illuminate","explain"),("assess","validate"),("contemplate","ponder")]
    SemanticVerbs.add_synonym!(canonical, alias)
end

# Orchestration rules
for rule_text in [
    "Your primary mission is {PRIMARY_ACTION}. Execute with full cognitive resources allocated.",
    "Ground every claim. {CONFIDENCE} determines assertion strength. Low confidence requires explicit qualification.",
    "Cross-domain synthesis activated. Identify connections across {LOBE_CONTEXT} to deepen understanding.",
    "Structure explanations hierarchically: overview → details → synthesis → implications.",
    "Use analogies carefully. State limitations before applying them.",
]
    GrugBot420.add_orchestration_rule!(rule_text)
end

# --- Now run the selected mission ---
const MISSIONS = Dict(
    1 => "Hello! What can you do?",
    2 => "Explain what a derivative is in calculus",
    3 => "How does Newton's second law work?",
    4 => "How does quantum physics relate to the nature of reality and consciousness",
    5 => "Explain integration and antiderivatives",
    6 => "What is the quadratic formula",
    7 => "What is epistemology about",
)

const mission_num = parse(Int, ARGS[1])
const mission_input = MISSIONS[mission_num]

println("\n" * "="^60)
println("MISSION #$(mission_num): \"$(mission_input)\"")
println("="^60)

try
    process_mission(mission_input)
catch e
    println("⚠️ Mission error: $e")
end

println("\n" * "="^60)
println("MISSION #$(mission_num) COMPLETE")
println("="^60)
