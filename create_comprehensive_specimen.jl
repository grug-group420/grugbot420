#!/usr/bin/env julia
# ============================================================================
# GRUG: Comprehensive Test Specimen Builder - FIXED VERSION
# ============================================================================
# Creates a full-featured specimen using actual function signatures
# ============================================================================

println("" * "="^70)
println("   COMPREHENSIVE TEST SPECIMEN BUILDER (FIXED)")
println("="^70 * "\n")

# GRUG: Load Main.jl first - it includes all required modules
include("src/Main.jl")

using Base.Threads: Atomic, atomic_add!
using JSON

# ============================================================================
# LOBE SETUP
# ============================================================================
println("[1] Setting up lobes...")

# Create lobes (100 nodes cap each)
Lobe.create_lobe!("science", "scientific concepts"; node_cap=100)
Lobe.create_lobe!("technology", "technology concepts"; node_cap=100)
Lobe.create_lobe!("philosophy", "philosophical concepts"; node_cap=100)
Lobe.create_lobe!("nature", "natural world concepts"; node_cap=100)

println("  ✓ Created 4 lobes: science, technology, philosophy, nature")

# Connect some lobes for cross-domain reasoning
Lobe.connect_lobes!("science", "technology")  # Science ↔ Technology
Lobe.connect_lobes!("philosophy", "nature") # Philosophy ↔ Nature

println("  ✓ Connected lobes for cross-domain reasoning")

# ============================================================================
# NODE CREATION - SCIENCE LOBE
# ============================================================================
println("\n[2] Creating science nodes...")

# Node 1: Quantum mechanics with custom data
science_id_1 = create_node(
    "Quantum mechanics studies subatomic particle behavior",
    "POS_ACTION_PACKET([\"explain\", \"describe\", \"analyze\"], [\"ignore\"], 0.1)",
    Dict("domain" => "physics", "complexity" => "high", "requires_math" => true),
    String[]
)
Lobe.add_node_to_lobe!("science", science_id_1)

println("  ✓ Created: Quantum mechanics")

# Node 2: DNA with relational patterns
science_id_2 = create_node(
    "DNA stores genetic information in cells",
    "POS_ACTION_PACKET([\"explain\", \"describe\"], [\"ignore\"], 0.05)",
    Dict("domain" => "biology", "molecular" => true),
    String[]
)
Lobe.add_node_to_lobe!("science", science_id_2)

println("  ✓ Created: DNA")

# Node 3: Chemical reactions with drop table
science_id_3 = create_node(
    "Chemical reactions transform substances",
    "POS_ACTION_PACKET([\"explain\"], [\"ignore\"], 0.1)",
    Dict("domain" => "chemistry", "process" => true),
    ["oxidation", "reduction", "synthesis", "decomposition"]
)
Lobe.add_node_to_lobe!("science", science_id_3)

println("  ✓ Created: Chemical reactions")

# ============================================================================
# NODE CREATION - TECHNOLOGY LOBE
# ============================================================================
println("\n[3] Creating technology nodes...")

# Node 1: AI with complex features
tech_id_1 = create_node(
    "Artificial intelligence enables machine learning",
    "POS_ACTION_PACKET([\"compute\", \"learn\", \"predict\", \"optimize\"], [\"crash\", \"error\"], 0.05)",
    Dict("domain" => "computer science", "ai_field" => true),
    String[]
)
Lobe.add_node_to_lobe!("technology", tech_id_1)

println("  ✓ Created: Artificial intelligence")

# Node 2: Robots (with attachment to AI)
tech_id_2 = create_node(
    "Robots perform automated tasks",
    "POS_ACTION_PACKET([\"move\", \"manipulate\", \"work\"], [\"break\", \"fail\"], 0.1)",
    Dict("domain" => "engineering", "automation" => true),
    String[]
)
Lobe.add_node_to_lobe!("technology", tech_id_2)

# Attach robots to AI
attach_node!(tech_id_2, tech_id_1, "AI enables robotics")

println("  ✓ Created: Robots (with attachment to AI)")

# ============================================================================
# NODE CREATION - PHILOSOPHY LOBE
# ============================================================================
println("\n[4] Creating philosophy nodes...")

# Node 1: Ethics
phil_id_1 = create_node(
    "Ethics evaluates moral principles",
    "POS_ACTION_PACKET([\"analyze\", \"judge\", \"guide\"], [\"violate\", \"ignore\"], 0.05)",
    Dict("domain" => "ethics", "normative" => true),
    String[]
)
Lobe.add_node_to_lobe!("philosophy", phil_id_1)

println("  ✓ Created: Ethics")

# Node 2: Metaphysics
phil_id_2 = create_node(
    "Metaphysics studies reality and existence",
    "POS_ACTION_PACKET([\"ponder\", \"question\"], [\"ignore\"], 0.1)",
    Dict("domain" => "metaphysics", "abstract" => true),
    ["existence", "being", "consciousness", "reality"]
)
Lobe.add_node_to_lobe!("philosophy", phil_id_2)

println("  ✓ Created: Metaphysics")

# ============================================================================
# NODE CREATION - NATURE LOBE
# ============================================================================
println("\n[5] Creating nature nodes...")

# Node 1: Ecosystems
nature_id_1 = create_node(
    "Ecosystems balance biological communities",
    "POS_ACTION_PACKET([\"analyze\", \"describe\"], [\"ignore\"], 0.05)",
    Dict("domain" => "ecology", "system" => true),
    ["predation", "competition", "symbiosis", "succession"]
)
Lobe.add_node_to_lobe!("nature", nature_id_1)

println("  ✓ Created: Ecosystems")

# Node 2: Evolution
nature_id_2 = create_node(
    "Evolution shapes species over time",
    "POS_ACTION_PACKET([\"explain\", \"describe\"], [\"ignore\"], 0.05)",
    Dict("domain" => "biology", "theory" => true),
    String[];
    initial_strength=8.0
)
Lobe.add_node_to_lobe!("nature", nature_id_2)

println("  ✓ Created: Evolution")

# ============================================================================
# RULES
# ============================================================================
println("\n[6] Creating rules...")

add_orchestration_rule!("What is quantum mechanics [prob=0.9]")
add_orchestration_rule!("Explain DNA [prob=0.85]")
add_orchestration_rule!("How does AI work [prob=0.88]")
add_orchestration_rule!("What is ethics [prob=0.82]")
add_orchestration_rule!("Tell me about ecosystems [prob=0.87]")
add_orchestration_rule!("Describe evolution [prob=0.86]")

println("  ✓ Created 6 AIML rules")

# ============================================================================
# THESAURUS
# ============================================================================
println("\n[7] Adding thesaurus entries...")

Thesaurus.add_seed_synonym!("subatomic", ["particle", "atomic", "fundamental"])
Thesaurus.add_seed_synonym!("machines", ["computers", "robots", "devices", "systems"])
Thesaurus.add_seed_synonym!("moral", ["ethical", "right", "wrong", "virtuous"])

println("  ✓ Created 3 custom thesaurus mappings")

# ============================================================================
# VERB REGISTRY
# ============================================================================
println("\n[8] Enhancing verb registry...")

SemanticVerbs.add_relation_class!("biological")
SemanticVerbs.add_verb!("grows", "biological")
SemanticVerbs.add_verb!("reproduces", "biological")
SemanticVerbs.add_verb!("evolves", "biological")
SemanticVerbs.add_verb!("adapts", "biological")

SemanticVerbs.add_relation_class!("cognitive")
SemanticVerbs.add_verb!("thinks", "cognitive")
SemanticVerbs.add_verb!("learns", "cognitive")
SemanticVerbs.add_verb!("remembers", "cognitive")
SemanticVerbs.add_verb!("understands", "cognitive")
SemanticVerbs.add_verb!("evaluates", "cognitive")

SemanticVerbs.add_synonym!("evaluates", "assess")

println("  ✓ Added biological and cognitive verb classes + synonym")

# ============================================================================
# SAVE SPECIMEN
# ============================================================================
println("\n[9] Saving specimen...")
specimen_path = "comprehensive_test_specimen.json"
result = save_specimen_to_file!(specimen_path)
println("\n$result")

# ============================================================================
# SUMMARY
# ============================================================================
println("\n" * "="^70)
println("   SPECIMEN CREATION COMPLETE")
println("="^70)
println("""
╔─────────────────────────────────────────────────────────────╗
║                      SPECIMEN STATISTICS                     ║
╠─────────────────────────────────────────────────────────────╣
║   Lobes:            4                 (science, technology,  ║
║                                          philosophy, nature) ║
║   Total Nodes:      9 (all alive)                             ║
║   └─ Science:       3                                          ║
║   └─ Technology:    2                                          ║
║   └─ Philosophy:    2                                          ║
║   └─ Nature:        2                                          ║
║   Rules:            6                                          ║
║   Attachments:      1                                          ║
║   Thesaurus:        3 custom mappings                         ║
║   Verb Classes:     2 custom classes                          ║
╚─────────────────────────────────────────────────────────────╝

Nodes created:
  • #{science_id_1} (science) - Quantum mechanics
  • #{science_id_2} (science) - DNA
  • #{science_id_3} (science) - Chemical reactions
  • #{tech_id_1} (technology) - AI
  • #{tech_id_2} (technology) - Robots
  • #{phil_id_1} (philosophy) - Ethics
  • #{phil_id_2} (philosophy) - Metaphysics
  • #{nature_id_1} (nature) - Ecosystems
  • #{nature_id_2} (nature) - Evolution

✓ Specimen ready for comprehensive testing!
  Next: Run ./interact_with_specimen.jl (also needs fixing)
""")