include("src/Main.jl")
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
result = load_specimen_from_file!(joinpath(@__DIR__, "specimens", "comprehensive_v2_specimen.json"))
println("LOAD RESULT: $result")
println("Nodes loaded: ", length(NODE_MAP))
println("Lobes loaded: ", length(Lobe.LOBE_REGISTRY))
println("Bridges loaded: ", length(BRIDGE_MAP))
println("Sigils in table: ", length(_ENGINE_SIGIL_TABLE.entries))
println("Rules loaded: ", length(ORCHESTRATION_RULES))
println("Thesaurus seeds: ", length(Thesaurus._THESAURUS_MAP))
println("Inhibitions: ", length(InputQueue._INHIBITION_SET))
println("AIML lobes: [removed v8.12]")  # AIMLNodeSystem removed
println("MLP rules: ", length(EphemeralMLP._MLP_RULES))
println("Automaton rules: ", length(EphemeralAutomaton._AUTOMATON_RULES))
println("Message history: ", length(_MESSAGE_HISTORY))
println("Coherence config weight: ", CoherenceField.COHERENCE_FIELD_CONFIG.weight)
println("Time orientation: ", _GLOBAL_TIME_ORIENTATION[])
println("Relational jitter enabled: ", RelationalJitter.is_jitter_enabled())
println("Answer modes: ", sort(collect(keys(_ANSWER_MODE_CONFIG))))
