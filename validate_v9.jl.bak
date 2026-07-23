#!/usr/bin/env julia
# Validate that the comprehensive specimen v9 can be loaded into GrugBot420

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
Pkg.activate(".")

using JSON

println("=== GrugBot420 Specimen v9 Validation ===")
println()

# Read the specimen
filepath = "comprehensive_specimen_v9.json"
println("Reading specimen: $filepath")
json_str = read(filepath, String)
specimen = JSON.parse(json_str)

println("Parsed OK. Checking sections...")
println()

# Check all required sections
required_sections = [
    "nodes", "hopfield_cache", "rules", "message_history", "lobes",
    "node_to_lobe_idx", "lobe_tables", "verb_registry", "thesaurus_seeds",
    "inhibitions", "arousal", "eye_state", "id_counters", "last_voters",
    "brainstem", "bridges", "attachments", "chatter_groups", "chatter_cooldowns",
    "trajectory", "temporal_coherence", "morph_cooldowns", "immune_system",
    "aiml_system", "sigil_table", "automaton_rules", "phase_accumulator",
    "last_contributor_votes", "node_to_group_idx", "tonal_judge_knobs",
    "ephemeral_mlp", "mlp_observer_store", "mlp_cached_phi",
    "decomposer_config", "vigilance_config", "injector_stats",
    "relational_jitter_config", "brainstem_config", "engine_config",
    "lobe_orchestrator_knobs", "vote_orchestrator_knobs", "mitosis_config",
    "growth_config", "phagy_config", "chatter_config", "immune_config",
    "scanner_config", "action_tone_knobs", "co_activation",
    "autogrowth_evidence", "autogrowth_co_occur", "autolink_evidence",
    "fanout_config", "hippocampal_pending_ask", "admin_session",
    "lobe_orch_last", "chatter_cursor", "answer_mode_config",
    "phagy_rules_ref", "time_orientation_config", "coherence_config",
    "input_ledger", "chatter_residuals", "_meta"
]

missing = String[]
for section in required_sections
    if haskey(specimen, section)
        println("  ✓ $section")
    else
        println("  ✗ MISSING: $section")
        push!(missing, section)
    end
end

println()
println("Nodes: $(length(specimen["nodes"]))")
println("Lobes: $(length(specimen["lobes"]))")
println("Bridges: $(length(specimen["bridges"]))")
println("Sigil entries: $(length(specimen["sigil_table"]))")
println("Automaton rules: $(length(specimen["automaton_rules"]))")

# Check MLP dimensions
mlp = specimen["ephemeral_mlp"]
w_ih = mlp["weights"]["w_input_hidden"]
b_h = mlp["weights"]["b_hidden"]
println()
println("MLP w_input_hidden: $(length(w_ih)) (expected 1536 = 24*64)")
println("MLP b_hidden: $(length(b_h)) (expected 64)")

# Check node types
modes = Set{String}()
for node in specimen["nodes"]
    if get(node, "is_image_node", false)
        push!(modes, "image")
    elseif get(node, "is_antimatch_node", false)
        push!(modes, "antimatch")
    elseif get(node, "is_grave", false)
        push!(modes, "grave")
    elseif haskey(node, "json_data") && haskey(node["json_data"], "mode")
        push!(modes, node["json_data"]["mode"])
    else
        push!(modes, "match")
    end
end
println()
println("Node modes present: $(sort(collect(modes)))")

if isempty(missing)
    println("\n=== ALL SECTIONS PRESENT — SPECIMEN VALID ===")
else
    println("\n=== MISSING SECTIONS: $missing ===")
end
