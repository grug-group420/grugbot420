#!/usr/bin/env julia
# =============================================================================
# Run all 11 missions with the NEW curve formula (√base × top²) and WITHOUT
# the per-lobe fuzzy whitelist, to verify the curve fix alone routes correctly.
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
    MESSAGE_HISTORY,
    LobeOrchestrator

RelationalJitter.disable_jitter!()

# --- Build specimen (same as run_missions.jl but WITHOUT whitelists) ---
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

# GRUG: NO WHITELISTS! Testing whether the curve fix alone is sufficient.
println("⚠️  NO per-lobe whitelists set — curve-only routing test")

# Nodes (same as run_missions.jl)
math_nodes = """
{"nodes":[{"pattern":"calculus derivative rate of change slope tangent","action_packet":"explain^5 | analyze^4 | validate^3","data":{"system_prompt":"Grug knows calculus. A derivative measures how fast something changes at a single point, like the slope of a hill under Grug's feet. The limit definition says: shrink the gap until it vanishes, and the ratio becomes the slope. Grug uses the power rule, the chain rule, and the product rule to find derivatives quickly. Velocity is the derivative of position, and acceleration is the derivative of velocity.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"integration integral area under curve antiderivative","action_packet":"calculate^5 | explain^4 | elaborate^3","data":{"system_prompt":"Grug understands integration. An integral adds up all the tiny pieces under a curve, like counting how much water fills a cave. The antiderivative reverses differentiation, and the fundamental theorem of calculus ties them together into one deep truth. Grug can compute areas, volumes, and accumulated change using these methods.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.5,"describes":2.0}}},{"pattern":"algebra equation solve variable unknown linear quadratic","action_packet":"calculate^5 | clarify^4 | validate^3","data":{"system_prompt":"Grug solves equations. Grug isolates the unknown variable step by step, using factoring, substitution, and the quadratic formula. For a quadratic, the formula gives both roots directly from the coefficients. Grug always checks the answer by plugging it back in.","required_relations":["applies_to","solves"],"relation_weights":{"applies_to":2.0,"solves":2.5}}},{"pattern":"geometry triangle circle polygon area perimeter angle","action_packet":"calculate^5 | reason^4 | elaborate^3","data":{"system_prompt":"Grug knows shapes and spaces. A triangle has three sides and angles that always sum to 180 degrees. A circle is every point at a fixed distance from the center, and its area is pi times the radius squared. Grug uses geometric reasoning to measure land, build structures, and navigate the world.","required_relations":["applies_to","describes"],"relation_weights":{"applies_to":2.0,"describes":2.0}}}]}
"""
ids_math = grow_nodes_from_packet(math_nodes; target_lobe="math")

science_nodes = """
{"nodes":[{"pattern":"physics force motion newton gravity acceleration mass","action_packet":"analyze^5 | ponder^4 | explain^3","data":{"system_prompt":"Grug studies force and motion. Newton's first law says an object keeps moving unless something pushes it. The second law is force equals mass times acceleration, the backbone of classical mechanics. The third law says every push has an equal push back. Grug sees these laws everywhere: falling apples, orbiting moons, and the pull of gravity.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}},{"pattern":"chemistry element atom molecule bond reaction periodic","action_packet":"define^5 | calculate^4 | ponder^3","data":{"system_prompt":"Grug knows the small stuff. Atoms are the building blocks, and they bond together into molecules through shared electrons. The periodic table arranges elements by their electron structure, and that pattern predicts how they react. Grug can balance a chemical equation because atoms are neither created nor destroyed in a reaction.","required_relations":["applies_to","composes"],"relation_weights":{"applies_to":2.0,"composes":2.5}}},{"pattern":"biology cell DNA gene evolution organism species","action_packet":"describe^5 | analyze^4 | reason^3","data":{"system_prompt":"Grug observes living things. Cells are the basic unit of life, and DNA inside them carries the instructions for building proteins. Genes change over generations, and natural selection shapes which changes survive. Grug sees the tree of life branching from single cells to every creature walking, swimming, or flying today.","required_relations":["applies_to","evolves"],"relation_weights":{"applies_to":2.0,"evolves":2.5}}},{"pattern":"quantum mechanics wave particle heisenberg uncertainty superposition","action_packet":"explain^5 | analyze^4 | calculate^3","data":{"system_prompt":"Grug ponders the very small. In quantum mechanics, particles behave like waves and waves behave like particles, and Grug cannot measure both position and momentum precisely at the same time. The double-slit experiment shows that observation changes the outcome. Superposition means a system exists in multiple states until measured, and the measurement problem asks what measurement really means.","required_relations":["applies_to","governs"],"relation_weights":{"applies_to":2.0,"governs":2.5}}}]}
"""
ids_science = grow_nodes_from_packet(science_nodes; target_lobe="science")

phil_nodes = """
{"nodes":[{"pattern":"epistemology knowledge truth belief justification evidence","action_packet":"ponder^5 | reason^4 | validate^3","data":{"system_prompt":"Grug asks how Grug knows what Grug knows. Epistemology studies the nature of knowledge itself. The classical answer is justified true belief: a claim must be true, believed, and supported by evidence. But Gettier problems show that even justified true belief can be accidental. Grug wonders whether knowledge rests on solid foundations or hangs together in a web of mutually supporting beliefs.","required_relations":["examines","justifies"],"relation_weights":{"examines":2.5,"justifies":2.0}}},{"pattern":"ethics moral right wrong good evil duty virtue","action_packet":"validate^5 | reason^4 | analyze^3","data":{"system_prompt":"Grug weighs right and wrong. Utilitarianism says the right action produces the most good for the most people. Deontology says certain duties must be followed regardless of consequences. Virtue ethics says a good character naturally produces good actions. Grug sees that each framework illuminates a different part of the moral landscape, and none captures the whole truth alone.","required_relations":["evaluates","prescribes"],"relation_weights":{"evaluates":2.5,"prescribes":2.0}}},{"pattern":"metaphysics reality existence being consciousness free will","action_packet":"ponder^5 | reason^4 | elaborate^3","data":{"system_prompt":"Grug wonders what is really real. Metaphysics asks about the fundamental nature of existence, consciousness, and free will. The hard problem of consciousness asks why subjective experience exists at all. Grug does not know whether free will is genuine or an illusion, and Grug is honest about that uncertainty.","required_relations":["examines","questions"],"relation_weights":{"examines":2.0,"questions":2.5}}},{"pattern":"logic reasoning argument fallacy syllogism deduction induction","action_packet":"analyze^5 | validate^4 | elaborate^3","data":{"system_prompt":"Grug follows the thread of reasoning. Logic identifies the structure of arguments and detects when reasoning goes astray. Deductive reasoning guarantees its conclusion if its premises are true. Inductive reasoning generalizes from examples, which is powerful but never certain. Grug spots fallacies by checking whether each step actually follows from the one before it.","required_relations":["analyzes","evaluates"],"relation_weights":{"analyzes":2.5,"evaluates":2.0}}}]}
"""
ids_phil = grow_nodes_from_packet(phil_nodes; target_lobe="philosophy")

conv_nodes = """
{"nodes":[{"pattern":"hello hi hey good morning greetings howdy welcome","action_packet":"greet^5 | welcome^4 | acknowledge^3","data":{"system_prompt":"Grug greets you warmly. Grug is happy to see another mind in the cave. What does Grug want to know? Grug is ready to think together.","required_relations":[],"relation_weights":{}}},{"pattern":"what are you who are you what can you do capabilities","action_packet":"explain^5 | describe^4 | elaborate^3","data":{"system_prompt":"Grug is GrugBot, a neuromorphic mind that thinks in nodes and votes. Each node is a pattern-recognizing torch in Grug's cognitive cave. When a pattern fires, the nodes vote on what matters most, and the winning vote shapes the answer. Grug has lobes for math, science, philosophy, and conversation. Grug is honest about what Grug is.","required_relations":[],"relation_weights":{}}},{"pattern":"thank thanks appreciate gratitude goodbye bye farewell","action_packet":"acknowledge^5 | comfort^4 | clarify^3","data":{"system_prompt":"Grug appreciates the kind words. Grug enjoyed thinking together. May the path ahead be clear and well-lit.","required_relations":[],"relation_weights":{}}},{"pattern":"tell me about explain describe what is how does overview","action_packet":"explain^5 | describe^4 | analyze^3","data":{"system_prompt":"Grug gives clear explanations. Grug starts with the big picture, then fills in the details that matter. Grug uses analogies when they help and admits when Grug is uncertain rather than guessing. A good explanation is like a well-built fire: it illuminates without burning.","required_relations":["describes","explains"],"relation_weights":{"describes":2.0,"explains":2.5}}}]}
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
    "Grug's primary mission is {PRIMARY_ACTION}. Grug commits full cognitive resources to this task.",
    "Grug grounds every claim with evidence. {CONFIDENCE} determines how strongly Grug asserts. Low confidence means Grug qualifies explicitly rather than guessing.",
    "Grug looks for connections across {LOBE_CONTEXT}. Cross-domain insight deepens understanding when the links are genuine.",
    "Grug structures explanations from the big picture down to the details, then synthesizes and draws out implications.",
    "Grug uses analogies carefully and states their limitations before applying them.",
    "Grug speaks in complete sentences. Each sentence carries one idea. Grug does not pile fragments together.",
    "Grug does not repeat what was already said. Grug moves forward and adds new substance to each reply.",
    "Grug refers to Grug in the third person. Grug does not say I or me. Grug says Grug.",
]
    GrugBot420.add_orchestration_rule!(rule_text)
end

# --- Run all 11 missions ---
const MISSIONS = Dict(
    1  => "Hello! What can you do?",
    2  => "Explain what a derivative is in calculus",
    3  => "How does Newton's second law work?",
    4  => "How does quantum physics relate to the nature of reality and consciousness",
    5  => "Explain integration and antiderivatives",
    6  => "What is the quadratic formula",
    7  => "What is epistemology about",
    8  => "Grug want to know about derivatives and also what does Newton say about force",
    9  => "What is a derivative and also how does the quadratic formula work",
    10 => "Explain epistemology and also what is the nature of consciousness",
    11 => "How does DNA carry information and also what is the periodic table",
)

println("\n", "="^60)
println("RUNNING ALL 11 MISSIONS — CURVE FIX ONLY (NO WHITELIST)")
println("="^60)

for mission_num in sort(collect(keys(MISSIONS)))
    mission_input = MISSIONS[mission_num]
    println("\n", "="^60)
    println("MISSION #$(mission_num): \"$(mission_input)\"")
    println("="^60)
    try
        process_mission(mission_input)
        # Show lobe curve telemetry
        println("\n📊 LOBE CURVE: ", LobeOrchestrator.last_summary())
    catch e
        println("⚠️ Mission error: $e")
        for (exc, bt) in current_exceptions()
            showerror(stdout, exc, bt)
            println()
        end
    end
end

println("\n", "="^60)
println("ALL MISSIONS COMPLETE")
println("="^60)
