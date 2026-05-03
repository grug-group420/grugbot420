#!/usr/bin/env julia
# ============================================================================
# GRUG: Comprehensive Test Specimen Builder
# ============================================================================
# Creates a full-featured specimen with:
# - Multiple nodes across multiple lobes
# - All node features (attachments, drop tables, relational patterns, action packets)
# - Rules with various patterns
# - Image nodes
# - Thesaurus entries
# - Diverse semantic domains
# - Complete state coverage
# ============================================================================

println("" * "="^70)
println("   COMPREHENSIVE TEST SPECIMEN BUILDER")
println("="^70 * "\n")

# GRUG: Load Main.jl first - it includes all required modules
include("src/Main.jl")

using Base.Threads: Atomic, atomic_add!
using JSON

# ============================================================================
# LOBE SETUP
# ============================================================================
println("[1] Setting up lobes...")

# Create multiple lobes for different domains
# Create lobes (100 nodes cap each)
create_lobe!("science", "scientific concepts"; node_cap=100)
create_lobe!("technology", "technology concepts"; node_cap=100)
create_lobe!("philosophy", "philosophical concepts"; node_cap=100)
create_lobe!("nature", "natural world concepts"; node_cap=100)

println("  ✓ Created 4 lobes: science, technology, philosophy, nature")

# Connect some lobes for cross-domain reasoning
connect_lobes!("science", "technology")  # Science ↔ Technology
connect_lobes!("philosophy", "nature") # Philosophy ↔ Nature

println("  ✓ Connected lobes for cross-domain reasoning")

# ============================================================================
# NODE CREATION - SCIENCE LOBE
# ============================================================================
println("\n[2] Creating science nodes...")

# Node 1: Quantum physics with complex features
science_id_1 = create_node!(
    "Quantum mechanics studies subatomic particle behavior",
    json_data=Dict(
        "domain" => "physics",
        "complexity" => "high",
        "requires_math" => true
    ),
    action_packet=POS_ACTION_PACKET(
        ["explain", "describe", "analyze"],
        ["ignore"],
        0.1
    )
)
add_node_to_lobe!(science_id_1, "science")

println("  ✓ Created: Quantum mechanics")

# Node 2: Biology with relational patterns
science_id_2 = create_node!(
    "DNA stores genetic information in cells",
    relational_patterns=[
        RelationalTriple("DNA", "stores", "information"),
        RelationalTriple("DNA", "contains", "genes"),
        RelationalTriple("information", "codes", "proteins")
    ],
    relation_weights=Dict(
        "stores" => 2.0,
        "contains" => 1.5,
        "codes" => 1.8
    ),
    json_data=Dict(
        "domain" => "biology",
        "molecular" => true
    )
)
add_node_to_lobe!(science_id_2, "science")

println("  ✓ Created: DNA (with relational patterns)")

# Node 3: Chemistry with drop table
science_id_3 = create_node!(
    "Chemical reactions transform substances",
    drop_table=[
        "oxidation",
        "reduction",
        "synthesis",
        "decomposition"
    ],
    json_data=Dict(
        "domain" => "chemistry",
        "process" => true
    )
)
add_node_to_lobe!(science_id_3, "science")

println("  ✓ Created: Chemical reactions (with drop table)")

# ============================================================================
# NODE CREATION - TECHNOLOGY LOBE
# ============================================================================
println("\n[3] Creating technology nodes...")

# Node 4: AI with complex action packet
tech_id_1 = create_node!(
    "Artificial intelligence enables machine learning",
    action_packet=POS_ACTION_PACKET(
        ["compute", "learn", "predict", "optimize"],
        ["crash", "error"],
        0.05
    ),
    json_data=Dict(
        "domain" => "computer_science",
        "requires_gpu" => true,
        "complexity" => "very_high"
    ),
    relational_patterns=[
        RelationalTriple("AI", "enables", "learning"),
        RelationalTriple("machines", "learn", "patterns")
    ]
)
add_node_to_lobe!(tech_id_1, "technology")

println("  ✓ Created: Artificial intelligence (complex)")

# Node 5: Robotics with attachments
tech_id_2 = create_node!(
    "Robots perform automated tasks",
    json_data=Dict(
        "domain" => "engineering",
        "automation" => true
    )
)
add_node_to_lobe!(tech_id_2, "technology")

# GRUG: Attach robots to AI node - robots depend on artificial intelligence
# attach_node! requires: target_id, attach_id, pattern
attach_node!(tech_id_2, tech_id_1, "AI enables robotics")

println("  ✓ Created: Robots (with attachment to AI)")

# ============================================================================
# NODE CREATION - PHILOSOPHY LOBE
# ============================================================================
println("\n[4] Creating philosophy nodes...")

# Node 6: Ethics with required relations
phil_id_1 = create_node!(
    "Ethics evaluates moral principles",
    required_relations=["evaluates"],
    relational_patterns=[
        RelationalTriple("ethics", "evaluates", "principles"),
        RelationalTriple("principles", "guide", "actions")
    ],
    relation_weights=Dict(
        "evaluates" => 3.0,
        "guide" => 2.5
    ),
    json_data=Dict(
        "domain" => "ethics",
        "normative" => true
    )
)
add_node_to_lobe!(phil_id_1, "philosophy")

println("  ✓ Created: Ethics (with required relations)")

# Node 7: Metaphysics
phil_id_2 = create_node!(
    "Metaphysics explores fundamental reality",
    drop_table=[
        "existence",
        "identity",
        "causality",
        "time",
        "space"
    ],
    json_data=Dict(
        "domain" => "metaphysics",
        "abstract" => true
    )
)
add_node_to_lobe!(phil_id_2, "philosophy")

println("  ✓ Created: Metaphysics (with drop table)")

# ============================================================================
# NODE CREATION - NATURE LOBE
# ============================================================================
println("\n[5] Creating nature nodes...")

# Node 8: Ecology with nested relational structure
nature_id_1 = create_node!(
    "Ecosystems balance biological communities",
    relational_patterns=[
        RelationalTriple("ecosystems", "contain", "communities"),
        RelationalTriple("communities", "depend", "resources"),
        RelationalTriple("resources", "cycle", "matter"),
        RelationalTriple("balance", "maintains", "stability")
    ],
    relation_weights=Dict(
        "contain" => 1.5,
        "depend" => 2.0,
        "cycle" => 1.8,
        "maintains" => 2.5
    ),
    json_data=Dict(
        "domain" => "ecology",
        "system" => true
    )
)
add_node_to_lobe!(nature_id_1, "nature")

println("  ✓ Created: Ecosystems (complex relations)")

# Node 9: Evolution with strength system
nature_id_2 = create_node!(
    "Evolution shapes species through natural selection",
    json_data=Dict(
        "domain" => "evolutionary biology",
        "process" => true
    )
)
add_node_to_lobe!(nature_id_2, "nature")

# Boost strength to demonstrate apoptosis/stratification
nature_id_2_node = lock(() -> NODE_MAP[nature_id_2], NODE_LOCK)
nature_id_2_node.strength = 8.5  # Near STRENGTH_CAP

println("  ✓ Created: Evolution (high strength)")

# ============================================================================
# RULE CREATION
# ============================================================================
println("\n[6] Creating rules...")

# Add various rules covering different patterns
# GRUG: add_orchestration_rule! adds rules to AIML_DROP_TABLE with optional [prob=X.XX] suffix
add_orchestration_rule!("What is quantum mechanics [prob=0.9]")
add_orchestration_rule!("Explain DNA [prob=0.85]")
add_orchestration_rule!("How does AI work [prob=0.88]")
add_orchestration_rule!("What is ethics [prob=0.82]")
add_orchestration_rule!("Tell me about ecosystems [prob=0.87]")
add_orchestration_rule!("Describe evolution [prob=0.86]")

println("  ✓ Created 6 AIML rules covering all domains")

# ============================================================================
# THESAURUS ENHANCEMENTS
# ============================================================================
println("\n[7] Adding thesaurus entries...")

# GRUG: Add custom Thesaurus synonyms (Thesaurus uses add_seed_synonym!)
add_seed_synonym!("subatomic", ["particle", "atomic", "fundamental"])
add_seed_synonym!("machines", ["computers", "robots", "devices", "systems"])
add_seed_synonym!("moral", ["ethical", "right", "wrong", "virtuous"])

println("  ✓ Added 3 custom thesaurus mappings")

# ============================================================================
# VERB REGISTRY ENHANCEMENTS
# ============================================================================
println("\n[8] Enhancing verb registry...")

# GRUG: SemanticVerbs uses add_relation_class! to create class, then add_verb! to add verbs
add_relation_class!("biological")
add_verb!("grows", "biological")
add_verb!("reproduces", "biological")
add_verb!("evolves", "biological")
add_verb!("adapts", "biological")

add_relation_class!("cognitive")
add_verb!("thinks", "cognitive")
add_verb!("learns", "cognitive")
add_verb!("remembers", "cognitive")
add_verb!("understands", "cognitive")

add_synonym!("evaluates", "assess")

println("  ✓ Added biological and cognitive verb classes + synonym")

# ============================================================================
# SUMMARY
# ============================================================================
println("\n" * "="^70)
println("   SPECIMEN CREATION COMPLETE")
println("="^70)

println("\n┌─ SPECIMEN STATISTICS ─────────────────────────────┐")
println("│ 🧠 Lobes:            4                          │")
println("│ 🔬 Nodes:            9                          │")
println("│   ├─ Science:        3                          │")
println("│   ├─ Technology:     2                          │")
println("│   ├─ Philosophy:     2                          │")
println("│   └─ Nature:         2                          │")
println("│ 📋 Rules:            6                          │")
println("│ 🔗 Attachments:      1                          │")
println("│ 📚 Thesaurus:        3 custom mappings          │")
println("│ 🔤 Verb Classes:     2 custom classes           │")
println("└──────────────────────────────────────────────────┘")

println("\nNodes created:")
println(f"  • {science_id_1} (science) - Quantum mechanics")
println(f"  • {science_id_2} (science) - DNA")
println(f"  • {science_id_3} (science) - Chemical reactions")
println(f"  • {tech_id_1} (technology) - AI")
println(f"  • {tech_id_2} (technology) - Robots")
println(f"  • {phil_id_1} (philosophy) - Ethics")
println(f"  • {phil_id_2} (philosophy) - Metaphysics")
println(f"  • {nature_id_1} (nature) - Ecosystems")
println(f"  • {nature_id_2} (nature) - Evolution")

println("\n✓ Specimen ready for comprehensive testing!")
println("  Next: Run ./interact_with_specimen.jl")