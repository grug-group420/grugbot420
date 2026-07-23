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

# Load the comprehensive specimen directly
println("\n=== Loading comprehensive specimen ===")
result = load_specimen_from_file!("comprehensive_specimen_v742.json")
println("Load result: $result")

# Send a few messages to test auto-learning
println("\n=== Sending test messages ===")
process_mission("hello grug how are you today")
process_mission("tell me about emotions and feelings") 
process_mission("what is the meaning of life and consciousness")
process_mission("explain the concept of gravity and physics")
process_mission("calculate 42 plus 17 for me please")

# Check AutoGrowth status
println("\n=== AUTOGROWTH STATUS ===")
println(AutoGrowth.get_autogrowth_status_summary())

# Check AutoLinker status
println("\n=== AUTOLINKER STATUS ===")
println(AutoLinker.get_autolink_status_summary())
