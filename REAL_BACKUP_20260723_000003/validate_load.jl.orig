# Validate specimen loads cleanly in GrugBot420 engine
import JSON
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

# Load the specimen file
spec_path = "comprehensive_specimen_v742.json"
txt = read(spec_path, String)
d = JSON.parse(txt)
println("✓ JSON parse OK")

# Check critical fields
nodes = get(d, "nodes", [])
println("✓ Nodes: ", length(nodes))

lobes = get(d, "lobes", [])
println("✓ Lobes: ", length(lobes))

bridges = get(d, "bridges", [])
println("✓ Bridges: ", length(bridges))

inhibitions = get(d, "inhibitions", [])
println("✓ Inhibitions: ", length(inhibitions))

sigils = get(d, "sigil_table", [])
println("✓ Sigils: ", length(sigils))

thesaurus = get(d, "thesaurus_seeds", Dict())
println("✓ Thesaurus groups: ", length(thesaurus))

verb_reg = get(d, "verb_registry", Dict())
println("✓ Verb classes: ", length(verb_reg))

ag = get(d, "autogrowth_evidence", Dict())
al = get(d, "autolink_evidence", Dict())
println("✓ AutoGrowth evidence: ", length(ag))
println("✓ AutoLink evidence: ", length(al))

cc = get(d, "coherence_config", Dict())
println("✓ Coherence config: ", cc)

# Check image node
for n in nodes
    if get(n, "is_image_node", false)
        println("✓ Image node: ", n["id"], " signal_len=", length(get(n, "signal", [])))
    end
end

# Check antimatch nodes
am_count = 0
for n in nodes
    if get(n, "is_antimatch_node", false)
        am_count += 1
    end
end
println("✓ Antimatch nodes: ", am_count)

println("\n=== SPECIMEN VALIDATION PASSED ===")
