using Pkg; Pkg.activate(".")
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
include("src/Main.jl")

# Load the comprehensive specimen
println("\n=== LOADING COMPREHENSIVE SPECIMEN ===")
result = load_specimen_from_file!("comprehensive_specimen_v742.json")
println("Load result: $result")

# Define mission inputs covering all lobes and node types
missions = [
    "hello grug how are you today",
    "tell me about emotions and feelings",
    "what is the meaning of life and consciousness",
    "explain the concept of gravity and physics",
    "calculate 42 plus 17 for me please",
    "why do we feel sad sometimes",
    "describe the process of photosynthesis",
    "what is love and why does it matter",
    "how do birds navigate during migration",
    "define the word epistemology",
    "alert there is a predator nearby",
    "comfort me I am feeling lonely",
    "reason about why the sky is blue",
    "explain quantum mechanics simply",
    "what happens before and after an earthquake",
    "I need help with survival skills",
    "tell me about friendship and trust",
    "why does music make us feel emotions",
    "describe how volcanoes erupt",
    "what is the difference between knowledge and belief",
    "how does memory work in the brain",
    "tell me about the ocean tides",
    "what are the laws of thermodynamics",
    "why should we care about philosophy",
    "how do computers process information",
    "grug what time is it now",
    "I feel happy when the sun shines",
    "what is math and why is it important",
    "explain the nature of reality and existence",
    "tell me about weather patterns and storms",
]

println("\n=== BEGINNING INTERACTION SESSION ===")
println("Total missions: $(length(missions))")

# Process each mission and log
for (i, mission) in enumerate(missions)
    println("\n" * "="^70)
    println("MISSION #$i: \"$mission\"")
    println("="^70)
    try
        result = process_mission(mission)
        println("RESPONSE: $result")
    catch e
        println("ERROR: $e")
    end
end

# Check AutoGrowth status
println("\n" * "="^70)
println("AUTOGROWTH STATUS")
println("="^70)
println(AutoGrowth.get_autogrowth_status_summary())

# Check AutoLinker status
println("\n" * "="^70)
println("AUTOLINKER STATUS")
println("="^70)
println(AutoLinker.get_autolink_status_summary())

# Save post-learning specimen
println("\n" * "="^70)
println("SAVING POST-LEARNING SPECIMEN")
println("="^70)
save_specimen_to_file!("comprehensive_specimen_v742_postlearn.json")
println("Specimen saved!")

println("\n=== INTERACTION SESSION COMPLETE ===")
