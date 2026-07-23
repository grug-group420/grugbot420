# Validate comprehensive specimen loads cleanly
using JSON
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

println("=== VALIDATING comprehensive_specimen_v742.json ===")

# First, JSON parse check
txt = read("comprehensive_specimen_v742.json", String)
d = JSON.parse(txt)
println("JSON parse: OK")

# Check top-level keys
println("Top-level keys (", length(keys(d)), "): ", sort(collect(keys(d)))[1:20]))

# Check nodes
nodes = get(d, "nodes", [])
println("Nodes: ", length(nodes))

# Check node types
type_counts = Dict{String,Int}()
for n in nodes
    tp = string(get(n, "answer_mode", "match"))
    type_counts[tp] = get(type_counts, tp, 0) + 1
end
println("Node types: ", type_counts)

# Check image node
img_nodes = filter(n -> get(n, "is_image_node", false), nodes)
println("Image nodes: ", length(img_nodes))
for n in img_nodes
    println("  id=", n["id"], " is_image_node=", n["is_image_node"], " signal_len=", length(get(n, "signal", [])), " lobe=", get(n, "lobe", "?"))
end

# Check lobes
lobes = get(d, "lobes", [])
println("Lobes: ", length(lobes))
for l in lobes
    println("  ", l["id"], " (", l["name"], ")")
end

# Check bridges
bridges = get(d, "bridges", [])
println("Bridges: ", length(bridges))
for b in bridges
    println("  ", get(b, "source_lobe", "?"), " -> ", get(b, "target_lobe", "?"), " crystalized=", get(b, "crystalized", false))
end

# Check inhibitions
inhib = get(d, "inhibitions", [])
println("Inhibitions: ", length(inhib))

# Check sigils
sigils = get(d, "sigil_table", [])
println("Sigils: ", length(sigils))

# Check thesaurus
thes = get(d, "thesaurus_seeds", Dict())
println("Thesaurus seed groups: ", length(thes), " total words: ", sum(length(v) for v in values(thes)))

# Check verb registry
verbs = get(d, "verb_registry", Dict())
println("Verb classes: ", length(verbs))

# Check autogrowth/autolink evidence (should be 0 at start)
ag = get(d, "autogrowth_evidence", Dict())
al = get(d, "autolink_evidence", Dict())
println("AutoGrowth evidence entries: ", length(ag))
println("AutoLink evidence entries: ", length(al))

# Check coherence_config
cc = get(d, "coherence_config", Dict())
println("Coherence config: ", cc)

# Check AIML nodes
aiml_nodes = filter(n -> get(n, "answer_mode", "") == "aiml", nodes)
println("AIML nodes: ", length(aiml_nodes))

# Check antimatch nodes  
anti_nodes = filter(n -> get(n, "is_antimatch", false), nodes)
println("Antimatch nodes: ", length(anti_nodes))

# Check time nodes
time_nodes = filter(n -> get(n, "answer_mode", "") == "time", nodes)
println("Time nodes: ", length(time_nodes))

# Check grave nodes
grave_nodes = filter(n -> get(n, "is_grave", false), nodes)
println("Grave nodes: ", length(grave_nodes))

println("=== VALIDATION COMPLETE ===")
