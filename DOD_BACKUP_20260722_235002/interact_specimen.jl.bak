#!/usr/bin/env julia
# Interact with comprehensive GrugBot420 specimen
# Loads the specimen, fires missions, captures responses + telemetry
# Usage: julia --project=. interact_specimen.jl

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

# Disable auto-load so we load our specimen
ENV["GRUG_NO_AUTOLOAD"] = "1"

# Load the full engine
include(joinpath(@__DIR__, "src", "Main.jl"))

using JSON
using Dates

println("="^70)
println("GRUG INTERACTION HARNESS v2.0")
println("="^70)

# ============================================================
# Load the comprehensive specimen
# ============================================================
specimen_path = joinpath(@__DIR__, "specimens", "comprehensive_v2_specimen.json")
println("\n📦 Loading specimen: $specimen_path")

load_result = load_specimen_from_file!(specimen_path)
println("  ✅ Specimen loaded: $load_result")

# Verify load
total_nodes = length(NODE_MAP)
total_lobes = length(Lobe.LOBE_REGISTRY)
println("  📊 Post-load: $total_nodes nodes, $total_lobes lobes")

# ============================================================
# Helper: count bridges by scanning BRIDGE_MAP
# ============================================================
function count_bridges()::Int
    seen_pairs = Set{Tuple{String,String}}()
    lock(BRIDGE_LOCK) do
        for (node_id, bridge_list) in BRIDGE_MAP
            for br in bridge_list
                a, b = minmax(node_id, br.partner_id)
                push!(seen_pairs, (a, b))
            end
        end
    end
    return length(seen_pairs)
end

# ============================================================
# Interaction missions — covers ALL lobes and ALL node types
# ============================================================
missions = [
    # Math lobe tests (includes solidified + image nodes)
    "what is 2 plus 2",
    "calculate 7 times 8",
    "explain subtraction",
    "solve for x in the equation",
    "what is geometry",

    # Philosophy lobe tests
    "what is consciousness",
    "why do we exist",
    "what is truth",
    "is there free will",
    "what is the meaning of life",

    # Survival lobe tests (includes antimatch + drop_table)
    "there is danger nearby",
    "how do I stay safe",
    "I feel calm and peaceful",      # hits antimatch node
    "should I flee or fight",
    "I need to protect my friends",

    # Empathy lobe tests (includes antimatch + drop_table)
    "I am feeling very sad",
    "I am so happy today",
    "show me compassion",            # has drop_table: stupid/dumb/idiot/hate/ugly
    "I am angry and frustrated",
    "I feel joy and delight",

    # Creativity lobe tests
    "write me a poem",
    "describe a painting",
    "what if I could imagine anything",
    "compose some music",
    "I want to create something beautiful",

    # Social lobe tests (includes solidified greeting + drop_table)
    "hello grug",                    # hits solidified (str 9.5) greeting node
    "you are my friend",
    "can I trust you",
    "let us cooperate",
    "I need help with something",

    # Temporal lobe tests
    "tell me about the past",
    "what does the future hold",
    "what is happening right now",
    "how do things change over time",

    # Nature lobe tests (includes image + grave nodes)
    "tell me about the forest",
    "describe the ocean",
    "what are mountains like",       # hits image node
    "what happened to extinct animals",  # hits grave node
    "what is the weather today",

    # Cross-lobe / bridge / edge-case tests
    "I wonder if math has meaning",          # math -> phil bridge
    "is danger beautiful",                   # surv -> crea nature bridge
    "can sadness create art",                # emp -> crea bridge
    "hello I need to calculate survival",    # social -> math + surv
    "think about time and consciousness",    # temporal -> phil bridge

    # New special-field node tests
    "emergency protocol activated",          # response_times node in surv
    "the absolute unknowable void",          # is_unlinkable node in phil
    "gathering of many friends",             # max_neighbors=12 node in social
    "SDF:sunset_over_water",                 # SDF image node in nature
]

# ============================================================
# Run interactions and collect telemetry
# ============================================================
results = []

println("\n" * "="^70)
println("🎯 FIRING $(length(missions)) MISSIONS...")
println("="^70)

for (i, mission) in enumerate(missions)
    println("\n--- Mission $i/$(length(missions)): \"$mission\" ---")

    # Capture pre-fire state
    pre_node_count = length(NODE_MAP)

    # Fire the mission
    start_time = time()
    try
        process_mission(mission)
    catch e
        @warn "Mission error" exception=e
    end
    elapsed = time() - start_time

    # Capture post-fire state
    post_node_count = length(NODE_MAP)

    # Get the last Engine_Voice message from history
    last_response = ""
    lock(MESSAGE_HISTORY_LOCK) do
        if length(MESSAGE_HISTORY) > 0
            for m in reverse(MESSAGE_HISTORY)
                if m.role == "Engine_Voice"
                    last_response = m.text
                    break
                end
            end
        end
    end

    # Get which node fired this cycle
    fired_node = "unknown"
    fired_pattern = ""
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if node.fired_this_cycle
                fired_node = id
                fired_pattern = node.pattern
                break
            end
        end
    end

    # Get telemetry
    global _arousal_val = 0.0
    try
        lock(EyeSystem.AROUSAL_LOCK) do
            _arousal_val = EyeSystem.AROUSAL_STATE.baseline
        end
    catch
    end

    inhibition_count = length(InputQueue.list_inhibitions())
    bridge_count_val = count_bridges()
    thesaurus_count = Thesaurus.seed_synonym_count()
    rule_count = length(ORCHESTRATION_RULES)

    result = Dict(
        "mission_id" => i,
        "input" => mission,
        "response" => last_response,
        "fired_node" => fired_node,
        "fired_pattern" => fired_pattern,
        "elapsed_sec" => round(elapsed; digits=3),
        "pre_nodes" => pre_node_count,
        "post_nodes" => post_node_count,
        "nodes_grown" => post_node_count - pre_node_count,
        "arousal" => _arousal_val,
        "inhibitions" => inhibition_count,
        "bridges" => bridge_count_val,
        "thesaurus_seeds" => thesaurus_count,
        "rules" => rule_count,
    )
    push!(results, result)

    # Print summary
    resp_preview = length(last_response) > 80 ? last_response[1:80] * "..." : last_response
    println("  ⏱  $(round(elapsed; digits=2))s | Node: $fired_node | Grown: $(post_node_count - pre_node_count)")
    println("  🗣️  $resp_preview")
end

# ============================================================
# Get tonal judge weights
# ============================================================
global _lift_val, _inhibit_val
_lift_val, _inhibit_val = TonalJudge.get_frame_match_weights()

# Capture final arousal
global _final_arousal = 0.0
try
    lock(EyeSystem.AROUSAL_LOCK) do
        _final_arousal = EyeSystem.AROUSAL_STATE.baseline
    end
catch
end

# ============================================================
# Generate Markdown report
# ============================================================
println("\n" * "="^70)
println("📝 GENERATING INTERACTION REPORT...")
println("="^70)

report_path = joinpath(@__DIR__, "interaction_results.md")

open(report_path, "w") do f
    println(f, "# GrugBot420 Comprehensive Interaction Results")
    println(f, "")
    println(f, "_Generated: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))_")
    println(f, "")
    println(f, "## Specimen Overview")
    println(f, "")
    println(f, "- **Specimen**: comprehensive_v2_specimen.json")
    println(f, "- **Total nodes**: $total_nodes")
    println(f, "- **Total lobes**: $total_lobes")
    println(f, "- **Missions fired**: $(length(missions))")
    println(f, "- **Features exercised**: text nodes, image nodes (including SDF), antimatch nodes, grave nodes, solidified nodes, lobes with whitelists, lobe connections, bridges (CascadeBridge), stochastic rules, thesaurus seeds, inhibitions (negative thesaurus), automaton escalation rules, decomposer conjunctions, TonalJudge knobs, flashcards (multi-lobe), semantic verbs + relation classes + verb synonyms, relational patterns, drop tables (side word rules), required relations, relation weights, arousal, message history, chatter groups, curiosity, coherence field, hopfield cache, immune system, AIML system, sigil table (lambda/macro/tag/procedure/relation), MLP transformer rules, RelationalGovernance co-activation, HippocampalModulator pending ask, TimeOrientation + time nodes, RelationalJitter, AutoGrowth evidence + co-occurrence, AutoLinker evidence, PhaseAccumulator crystal, answer modes (incl. custom poetry), fan-out config, node response_times, is_unlinkable, max_neighbors, json_data enrichment")
    println(f, "")

    # Pre-compute node type counters before open() to avoid Julia soft-scope issues
    global n_image = 0; global n_anti = 0; global n_grave = 0; global n_solid = 0
    global n_drop = 0; global n_relat = 0; global n_req = 0; global n_wt = 0
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if node.is_image_node; global n_image += 1; end
            if node.is_antimatch_node; global n_anti += 1; end
            if node.is_grave; global n_grave += 1; end
            if node.strength >= 9.0; global n_solid += 1; end
            if !isempty(node.drop_table); global n_drop += 1; end
            if !isempty(node.relational_patterns); global n_relat += 1; end
            if !isempty(node.required_relations); global n_req += 1; end
            if !isempty(node.relation_weights); global n_wt += 1; end
        end
    end

    println(f, "## Node Type Coverage")
    println(f, "")
    println(f, "| Type | Count |")
    println(f, "|------|-------|")
    println(f, "| Total nodes | $total_nodes |")
    println(f, "| Image nodes (is_image_node) | $n_image |")
    println(f, "| Antimatch nodes (is_antimatch_node) | $n_anti |")
    println(f, "| Grave nodes (is_grave) | $n_grave |")
    println(f, "| Solidified nodes (strength >= 9) | $n_solid |")
    println(f, "| With drop_table (side word rules) | $n_drop |")
    println(f, "| With relational_patterns | $n_relat |")
    println(f, "| With required_relations | $n_req |")
    println(f, "| With relation_weights | $n_wt |")
    println(f, "")

    println(f, "## Lobe Distribution")
    println(f, "")
    println(f, "| Lobe | Nodes | Connected To | Whitelist Size |")
    println(f, "|------|-------|-------------|---------------|")
    for (lobe_id, lobe_rec) in Lobe.LOBE_REGISTRY
        n_count = length(lobe_rec.node_ids)
        connected = join(lobe_rec.connected_lobe_ids, ", ")
        wl_size = length(lobe_rec.subject_whitelist)
        println(f, "| $lobe_id | $n_count | $connected | $wl_size |")
    end
    println(f, "")

    println(f, "## Side Systems Status")
    println(f, "")
    println(f, "| System | State |")
    println(f, "|--------|-------|")
    println(f, "| Thesaurus seeds | $(Thesaurus.seed_synonym_count()) synonym groups |")
    println(f, "| Inhibitions (neg thesaurus) | $(length(InputQueue.list_inhibitions())) words inhibited |")
    println(f, "| Automaton escalation rules | $(length(ORCHESTRATION_RULES)) stochastic rules in table |")
    println(f, "| Stochastic rules | $(length(ORCHESTRATION_RULES)) |")
    println(f, "| Cross-lobe bridges | $(count_bridges()) |")
    println(f, "| Chatter groups | $(length(GROUP_MAP)) groups |")
    println(f, "| Arousal baseline | $_final_arousal |")
    println(f, "| TonalJudge lift | $_lift_val |")
    println(f, "| TonalJudge inhibit | $_inhibit_val |")
    verb_count = length(SemanticVerbs.get_all_verbs())
    cls_count = length(SemanticVerbs._VERB_REGISTRY)
    syn_count = length(SemanticVerbs._SYNONYM_MAP)
    println(f, "| Semantic verbs | $verb_count verbs across $cls_count classes |")
    println(f, "| Verb synonyms | $syn_count registered |")
    println(f, "| Decomposer custom conjunctions | 3 (although, whereas, nevertheless) |")
    println(f, "| Decomposer compound pairs | 1 (not+only) |")
    println(f, "")

    # Sigil table status
    sigil_count = length(_ENGINE_SIGIL_TABLE.entries)
    sigil_names = sort(collect(keys(_ENGINE_SIGIL_TABLE.entries)))
    println(f, "## Sigil Registry")
    println(f, "")
    println(f, "- **Total sigils**: $sigil_count")
    println(f, "- **Sigil names**: $(join(sigil_names, ", "))")
    println(f, "")

    # MLP rules
    mlp_rules = EphemeralMLP.list_mlp_rules()
    mlp_count = length(mlp_rules)
    mlp_status = EphemeralMLP.get_mlp_status()
    println(f, "## EphemeralMLP Rules")
    println(f, "")
    println(f, "- **Active MLP rules**: $mlp_count")
    for r in mlp_rules
        println(f, "- **$(r.id)**: key=$(r.key), weight=$(r.weight.value), type=$(r.transform_type), fires=$(r.fire_count)")
    end
    println(f, "")

    # Relational jitter
    jitter_on = RelationalJitter.is_jitter_enabled()
    jitter_ratio = RelationalJitter.get_jitter_ratio()
    jitter_coin = RelationalJitter.get_jitter_coin_ratio()
    println(f, "## RelationalJitter Config")
    println(f, "")
    println(f, "- **Enabled**: $jitter_on")
    println(f, "- **Jitter ratio**: $jitter_ratio")
    println(f, "- **Coin ratio**: $jitter_coin")
    println(f, "")

    # Time orientation
    time_orient = _GLOBAL_TIME_ORIENTATION[]
    println(f, "## Time Orientation")
    println(f, "")
    println(f, "- **Global orientation**: $(time_orient[1])")
    println(f, "- **Config**: $(time_orient[2])")
    # Count time nodes
    global n_time = 0
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if haskey(node.json_data, "time_node") && node.json_data["time_node"] === true
                global n_time += 1
            end
        end
    end
    println(f, "- **Time-oriented nodes**: $n_time")
    println(f, "")

    # Hippocampal pending ask
    hippo_ask = ""
    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        hippo_ask = _HIPPOCAMPAL_PENDING_ASK[]
    end
    println(f, "## HippocampalModulator")
    println(f, "")
    println(f, "- **Pending ask**: $hippo_ask")
    println(f, "")

    # Answer modes
    am_count = length(_ANSWER_MODE_CONFIG)
    am_modes = sort(collect(keys(_ANSWER_MODE_CONFIG)))
    println(f, "## Answer Modes")
    println(f, "")
    println(f, "- **Total modes**: $am_count")
    println(f, "- **Mode names**: $(join(am_modes, ", "))")
    println(f, "")

    println(f, "## Interaction Log Summary")
    println(f, "")
    println(f, "| # | Input | Response (truncated) | Fired Node | Time (s) | Grown |")
    println(f, "|---|-------|----------------------|------------|----------|-------|")
    for r in results
        input_esc = replace(r["input"], "|" => "\\|")
        resp_esc = replace(replace(r["response"], "|" => "\\|"), "\n" => " ")
        if length(resp_esc) > 80
            resp_esc = resp_esc[1:80] * "..."
        end
        println(f, "| $(r["mission_id"]) | $input_esc | $resp_esc | $(r["fired_node"]) | $(r["elapsed_sec"]) | $(r["nodes_grown"]) |")
    end
    println(f, "")

    println(f, "## Detailed Telemetry Per Mission")
    println(f, "")
    for r in results
        println(f, "### Mission $(r["mission_id"]): \"$(r["input"])\"")
        println(f, "")
        resp_full = replace(r["response"], "\n" => "  ")
        println(f, "- **Full response**: $(resp_full)")
        println(f, "- **Fired node**: $(r["fired_node"]) (pattern: \"$(r["fired_pattern"])\"])")
        println(f, "- **Elapsed**: $(r["elapsed_sec"])s")
        println(f, "- **Nodes before**: $(r["pre_nodes"]), **after**: $(r["post_nodes"]) (grown: $(r["nodes_grown"]))")
        println(f, "- **Arousal at time**: $(r["arousal"])")
        println(f, "- **Active inhibitions**: $(r["inhibitions"])")
        println(f, "- **Bridges active**: $(r["bridges"])")
        println(f, "- **Thesaurus seeds**: $(r["thesaurus_seeds"])")
        println(f, "- **Stochastic rules**: $(r["rules"])")
        println(f, "")
    end

    println(f, "## Auto-Learning Evidence (Post-Interaction)")
    println(f, "")
    ag_ev = AutoGrowth.get_evidence_snapshot()
    ag_co = AutoGrowth.get_co_occur_snapshot()
    al_ev = AutoLinker.get_link_evidence_snapshot()
    println(f, "- **AutoGrowth evidence entries**: $(length(ag_ev))")
    println(f, "- **AutoGrowth co-occurrence entries**: $(length(ag_co))")
    println(f, "- **AutoLinker evidence entries**: $(length(al_ev))")
    println(f, "")

    println(f, "## Curiosity State (Post-Interaction)")
    println(f, "")
    cur = AutoGrowth.get_curiosity_status()
    for (k, v) in sort(collect(cur); by=first)
        println(f, "- **$k**: $v")
    end
    println(f, "")

    println(f, "## Coherence Field Config")
    println(f, "")
    cfs = CoherenceField.coherence_config_snapshot()
    println(f, "- **weight**: $(cfs.weight)")
    println(f, "- **depth**: $(cfs.depth)")
    println(f, "- **decay**: $(cfs.decay)")
    println(f, "- **recency_window**: $(cfs.recency_window)")
    println(f, "- **cache_ttl**: $(cfs.cache_ttl)")
    println(f, "- **cached_phi**: $(cfs.cached_phi)")
    println(f, "")

    # Immune system status
    println(f, "## Immune System Status")
    println(f, "")
    imm = ImmuneSystem.get_immune_status()
    for (k, v) in sort(collect(imm); by=first)
        println(f, "- **$k**: $v")
    end
    println(f, "")

    # Final node count
    final_count = length(NODE_MAP)
    println(f, "## Growth Summary")
    println(f, "")
    println(f, "- **Starting nodes**: $total_nodes")
    println(f, "- **Final nodes**: $final_count")
    println(f, "- **Total grown during interaction**: $(final_count - total_nodes)")
    total_grown = sum([r["nodes_grown"] for r in results])
    println(f, "- **Sum of per-mission growth**: $total_grown")
    println(f, "")
end

println("  ✅ Report saved: $report_path")

# ============================================================
# Save post-interaction specimen
# ============================================================
post_path = joinpath(@__DIR__, "specimens", "comprehensive_v2_post_interaction.json")
save_specimen_to_file!(post_path)
println("  ✅ Post-interaction specimen saved: $post_path")

println("\n" * "="^70)
println("🎉 INTERACTION HARNESS COMPLETE")
println("="^70)
