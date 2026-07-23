#!/usr/bin/env julia
# GrugBot420 — Comprehensive Interaction Harness v9
# Loads comprehensive_specimen_v9.json and runs diverse missions
# covering ALL node types, ALL answer modes, ALL lobes
# Then checks AutoGrowth/AutoLinker and saves post-learning specimen

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
println("=== ENGINE LOADED ===")

# ── Load the comprehensive specimen ──
println("\n╔══════════════════════════════════════════════════════════════╗")
println("║         LOADING COMPREHENSIVE SPECIMEN v9                  ║")
println("╚══════════════════════════════════════════════════════════════╝")
load_specimen_from_file!("comprehensive_specimen_v9.json")

# ── Pre-interaction state snapshot ──
println("\n━━━ PRE-INTERACTION STATE ━━━")
node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
lobe_count = length(Lobe.LOBE_REGISTRY)
bridge_count = lock(() -> length(BRIDGE_MAP), BRIDGE_LOCK)
sigil_count = length(_ENGINE_SIGIL_TABLE.entries)
println("Nodes: $node_count")
println("Lobes: $lobe_count")
println("Bridges: $bridge_count")
println("Sigil entries: $sigil_count")

# Check initial autogrowth evidence (via exported snapshot)
println("\n── Initial AutoGrowth Evidence ──")
initial_evidence = AutoGrowth.get_evidence_snapshot()
initial_ag_count = length(initial_evidence)
println("Evidence entries: $initial_ag_count")
for rec in initial_evidence
    println("  \"$(rec["pattern"])\" => score=$(rec["accumulated_intensity"]), freq=$(rec["frequency"])")
end

# Check initial autolink evidence
println("\n── Initial AutoLinker Evidence ──")
initial_link_evidence = AutoLinker.get_link_evidence_snapshot()
initial_al_count = length(initial_link_evidence)
println("Link evidence entries: $initial_al_count")
for rec in initial_link_evidence
    # link_evidence is Dict{String, Dict}, values are records
    data = rec.second
    println("  \"$(rec.first)\" => score=$(data["accumulated_intensity"]), freq=$(data["frequency"])")
end

# ── Define missions covering ALL features ──
missions = [
    # === REASON mode (plain match nodes) ===
    (1,  "reason",   "what is gravity",                    "lobe_physics",     "n101"),
    (2,  "reason",   "what is evolution",                  "lobe_biology",     "n102"),
    (3,  "reason",   "what is a derivative",               "lobe_math",        "n103"),
    (4,  "reason",   "what is climate change",             "lobe_climate",     "n104"),
    (5,  "reason",   "what is the meaning of life",        "lobe_philosophy",  "n138"),
    (6,  "reason",   "what is consciousness",              "lobe_philosophy",  "n139"),
    (7,  "reason",   "what is a chemical bond",            "lobe_chemistry",   "n140"),
    (8,  "reason",   "what is biodiversity",               "lobe_ecology",     "n141"),
    (9,  "reason",   "hello grug",                         "lobe_general",     "n136"),
    (10, "reason",   "hi there greetings hey",             "lobe_general",     "n137"),

    # === EXPLAIN mode ===
    (11, "explain",  "explain photosynthesis",              "lobe_biology",     "n105"),
    (12, "explain",  "explain newtons laws",               "lobe_physics",     "n106"),
    (13, "explain",  "explain how computers work",         "lobe_tech",        "n107"),
    (14, "explain",  "explain relativity",                 "lobe_physics",     "n142"),
    (15, "explain",  "explain the water cycle",            "lobe_climate",     "n143"),

    # === DEFINE mode ===
    (16, "define",   "define entropy",                     "lobe_physics",     "n108"),
    (17, "define",   "define algorithm",                   "lobe_tech",        "n109"),
    (18, "define",   "define species",                     "lobe_biology",     "n110"),
    (19, "define",   "define ecosystem",                   "lobe_ecology",     "n144"),
    (20, "define",   "define justice",                     "lobe_philosophy",  "n145"),

    # === ALERT mode ===
    (21, "alert",    "danger radiation",                   "lobe_physics",     "n111"),
    (22, "alert",    "danger toxin chemical",              "lobe_chemistry",   "n112"),
    (23, "alert",    "danger extinction",                  "lobe_ecology",     "n151"),

    # === COMFORT mode ===
    (24, "comfort",  "i am sad",                           "lobe_emotion",     "n113"),
    (25, "comfort",  "i am scared afraid",                 "lobe_emotion",     "n114"),
    (26, "comfort",  "i feel lost confused",               "lobe_emotion",     "n146"),

    # === MATH mode (reason^1 + answer_mode=math) ===
    (27, "math",     "calculate integral",                 "lobe_math",        "n115"),
    (28, "math",     "calculate fibonacci",                "lobe_math",        "n116"),
    (29, "math",     "calculate pi digits",               "lobe_math",        "n117"),
    (30, "math",     "calculate euler number",             "lobe_math",        "n147"),

    # === RELATE mode (reason^1 + answer_mode=relate + relational_patterns) ===
    (31, "relate",   "sun causes warmth",                  "lobe_physics",     "n118"),
    (32, "relate",   "predator eats prey",                 "lobe_ecology",     "n119"),
    (33, "relate",   "learning requires practice",         "lobe_philosophy",  "n120"),
    (34, "relate",   "fire causes heat",                   "lobe_physics",     "n148"),
    (35, "relate",   "education enables progress",         "lobe_philosophy",  "n149"),

    # === TIME mode (reason^1 + answer_mode=time) ===
    (36, "time",     "what happens in spring",             "lobe_ecology",     "n121"),
    (37, "time",     "what happened before big bang",      "lobe_physics",     "n122"),
    (38, "time",     "next technological revolution",      "lobe_tech",        "n123"),
    (39, "time",     "winter seasonal cold",               "lobe_climate",     "n150"),

    # === PROC mode (reason^1 + answer_mode=proc) ===
    (40, "proc",     "how to solve quadratic equation",    "lobe_math",        "n124"),
    (41, "proc",     "how to do scientific experiment",    "lobe_general",     "n125"),
    (42, "proc",     "how to build a fire",                "lobe_general",     "n152"),

    # === JSON mode (reason^1 + answer_mode=json) ===
    (43, "json",     "periodic table data",                "lobe_chemistry",   "n126"),
    (44, "json",     "population statistics",              "lobe_general",     "n127"),

    # === MULTI mode (reason^1 + answer_mode=multi) ===
    (45, "multi",    "compare dna and rna",                "lobe_biology",     "n128"),
    (46, "multi",    "compare heat and temperature",       "lobe_physics",     "n129"),

    # === ANTIMATCH nodes (confidence drain) ===
    (47, "antimatch","not a bug",                          "lobe_tech",        "n130"),
    (48, "antimatch","not dangerous safe",                 "lobe_general",     "n131"),

    # === IMAGE nodes (SDF-based) ===
    (49, "image",    "circle_sdf",                         "lobe_math",        "n132"),
    (50, "image",    "rectangle_sdf",                      "lobe_math",        "n133"),

    # === GRAVE nodes (dead/suppressed) ===
    (51, "grave",    "obsolete theory phlogiston",         "lobe_chemistry",   "n134"),
    (52, "grave",    "deprecated flat earth",              "lobe_general",     "n135"),

    # === Repeated missions for AutoGrowth/AutoLinker evidence building ===
    (53, "reason",   "what is gravity",                    "lobe_physics",     "n101"),
    (54, "reason",   "what is gravity and force",           "lobe_physics",     "n101"),
    (55, "reason",   "tell me about gravity again",         "lobe_physics",     "n101"),
    (56, "explain",  "explain photosynthesis again",       "lobe_biology",     "n105"),
    (57, "explain",  "explain photosynthesis process",      "lobe_biology",     "n105"),
    (58, "reason",   "what is evolution and species",      "lobe_biology",     "n102"),
    (59, "reason",   "evolution and natural selection",    "lobe_biology",     "n102"),
    (60, "comfort",  "i am sad and lonely",                 "lobe_emotion",     "n113"),

    # === Cross-lobe queries (for AutoLinker bridge building) ===
    (61, "cross",    "gravity and climate are related",     "cross_physics_climate", "n101+n104"),
    (62, "cross",    "evolution and biodiversity connect",  "cross_biology_ecology", "n102+n141"),
    (63, "cross",    "math and physics overlap",            "cross_math_physics",    "n103+n101"),
    (64, "cross",    "chemistry and biology share molecules","cross_chem_bio",       "n140+n105"),
    (65, "cross",    "philosophy and logic are intertwined","cross_phil_logic",     "n138+n117"),

    # === Novel queries (not matching any node — should trigger AutoGrowth) ===
    (66, "novel",    "what is quantum computing",           "lobe_tech",        "none"),
    (67, "novel",    "what is quantum computing",           "lobe_tech",        "none"),
    (68, "novel",    "what is quantum computing",           "lobe_tech",        "none"),
    (69, "novel",    "explain machine learning",             "lobe_tech",        "none"),
    (70, "novel",    "explain machine learning",             "lobe_tech",        "none"),
    (71, "novel",    "explain machine learning",             "lobe_tech",        "none"),
    (72, "novel",    "what is dark matter",                  "lobe_physics",     "none"),
    (73, "novel",    "what is dark matter",                  "lobe_physics",     "none"),
    (74, "novel",    "what is dark matter",                  "lobe_physics",     "none"),
    (75, "novel",    "what is synthetic biology",            "lobe_biology",     "none"),
    (76, "novel",    "what is synthetic biology",            "lobe_biology",     "none"),
    (77, "novel",    "what is synthetic biology",            "lobe_biology",     "none"),

    # === Edge cases and conversational ===
    (78, "reason",   "hello",                              "lobe_general",     "n136"),
    (79, "reason",   "greetings friend",                    "lobe_general",     "n137"),
    (80, "reason",   "what do you think about life grug",  "lobe_philosophy",  "n138"),
]

println("\n╔══════════════════════════════════════════════════════════════╗")
println("║         BEGINNING INTERACTION SESSION                       ║")
println("║         Total missions: $(length(missions))                               ║")
println("╚══════════════════════════════════════════════════════════════╝")

# ── Process each mission and log ──
for (i, mode, input_text, target_lobe, target_node) in missions
    println("\n$('═'^70)")
    println("MISSION #$i [$mode] → $target_lobe (target: $target_node)")
    println("  INPUT: \"$input_text\"")
    println("─"^70)
    try
        result = process_mission(input_text)
        println("  RESPONSE: $result")
    catch e
        println("  ERROR: $e")
        for (fi, frame) in enumerate(stacktrace(catch_backtrace()))
            println("    [$fi] $frame")
            fi > 5 && break
        end
    end
end

# ── Post-interaction state ──
println("\n$('═'^70)")
println("POST-INTERACTION STATE")
println("═"^70)
final_node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
final_lobe_count = length(Lobe.LOBE_REGISTRY)
final_bridge_count = lock(() -> length(BRIDGE_MAP), BRIDGE_LOCK)
println("Nodes: $final_node_count (was $node_count)")
println("Lobes: $final_lobe_count (was $lobe_count)")
println("Bridges: $final_bridge_count (was $bridge_count)")

# ── AutoGrowth status ──
println("\n$('─'^70)")
println("AUTOGROWTH STATUS")
println("─"^70)
try
    println(AutoGrowth.get_autogrowth_status_summary())
catch e
    println("Error getting AutoGrowth status: $e")
end

# ── AutoLinker status ──
println("\n$('─'^70)")
println("AUTOLINKER STATUS")
println("─"^70)
try
    println(AutoLinker.get_autolink_status_summary())
catch e
    println("Error getting AutoLinker status: $e")
end

# ── Additional status summaries ──
println("\n$('─'^70)")
println("AIML STATUS")
println("─"^70)
try
    println(AIMLNodeSystem.get_aiml_status_summary())
catch e
    println("Error: $e")
end

println("\n$('─'^70)")
println("LOBE STATUS")
println("─"^70)
try
    println(Lobe.get_lobe_status_summary())
catch e
    println("Error: $e")
end

println("\n$('─'^70)")
println("MITOSIS STATUS")
println("─"^70)
try
    println(MitosisMode.get_mitosis_status_summary())
catch e
    println("Error: $e")
end

println("\n$('─'^70)")
println("TEMPORAL GROWTH STATUS")
println("─"^70)
try
    println(TemporalGrowth.get_growth_status_summary())
catch e
    println("Error: $e")
end

println("\n$('─'^70)")
println("RELATIONAL GOVERNANCE STATUS")
println("─"^70)
try
    println(RelationalGovernance.get_relational_gov_status_summary())
catch e
    println("Error: $e")
end

# ── Check AutoGrowth evidence changes ──
println("\n$('─'^70)")
println("AUTOGROWTH EVIDENCE CHANGES")
println("─"^70)
final_evidence = AutoGrowth.get_evidence_snapshot()
final_ag_count = length(final_evidence)
println("Initial evidence entries: $initial_ag_count")
println("Final evidence entries: $final_ag_count")
println("New entries: $(final_ag_count - initial_ag_count)")
for rec in final_evidence
    println("  \"$(rec["pattern"])\" => score=$(rec["accumulated_intensity"]), freq=$(rec["frequency"])")
end

# ── Check AutoLinker evidence changes ──
println("\n$('─'^70)")
println("AUTOLINKER EVIDENCE CHANGES")
println("─"^70)
final_link_evidence = AutoLinker.get_link_evidence_snapshot()
final_al_count = length(final_link_evidence)
println("Initial link evidence entries: $initial_al_count")
println("Final link evidence entries: $final_al_count")
println("New link entries: $(final_al_count - initial_al_count)")
for rec in final_link_evidence
    data = rec.second
    println("  \"$(rec.first)\" => score=$(data["accumulated_intensity"]), freq=$(data["frequency"])")
end

# ── Check growth log ──
println("\n$('─'^70)")
println("AUTOGROWTH LOG (nodes created)")
println("─"^70)
try
    growth_log = AutoGrowth.get_growth_log()
    println("Growth events: $(length(growth_log))")
    for entry in growth_log
        println("  $entry")
    end
catch e
    println("Error: $e")
end

# ── Check link log ──
println("\n$('─'^70)")
println("AUTOLINKER LOG (bridges created)")
println("─"^70)
try
    link_log = AutoLinker.get_link_log()
    println("Link events: $(length(link_log))")
    for entry in link_log
        println("  $entry")
    end
catch e
    println("Error: $e")
end

# ── Save post-learning specimen ──
println("\n$('═'^70)")
println("SAVING POST-LEARNING SPECIMEN")
println("═"^70)
save_specimen_to_file!("comprehensive_specimen_v9_postlearn.json")
println("Post-learning specimen saved to comprehensive_specimen_v9_postlearn.json")

println("\n╔══════════════════════════════════════════════════════════════╗")
println("║         INTERACTION SESSION COMPLETE                        ║")
println("╚══════════════════════════════════════════════════════════════╝")
