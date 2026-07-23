#!/usr/bin/env python3
"""
Comprehensive Specimen Generator v10 (complete).

Imports the voice system + make_node from gen_specimen_v10_part1.py and builds
the full specimen: all node types, all answer modes, 11 lobes, bridges, sigils,
automaton rules, chatter groups, MLP, autolearning evidence, and all sections.

Key improvement over v9: every node has a TOPIC-SPECIFIC system_prompt,
voice_variants, and noun_anchors (via voice_key) so Grug produces coherent,
differentiated responses per topic.
"""
import json, time as time_mod, random

# Import voice system + helpers from part1
from gen_specimen_v10_part1 import (
    NODE_VOICES, make_node, make_signal, make_triple, next_node_id, _next_id,
)

# ── MLP / engine constants ──
VOTE_FEATURE_DIM = 24
HIDDEN_DIM = 64
FFN_DIM = 128
ATTENTION_HEADS = 4
NUM_TRANSFORMER_BLOCKS = 2
NUM_OUTPUT_HEADS = 4
LEGACY_VOTE_FEATURE_DIM = 12
LEGACY_HIDDEN_DIM = 16

STRENGTH_CAP = 10.0
STRENGTH_FLOOR = 0.1
STRENGTH_SOLIDIFY_THRESHOLD = 5.0
JITTER_CONFIDENCE_FLOOR = 0.3
MAX_NEIGHBORS = 16
LATCH_PARTNER_CAP_MIN = 8
LATCH_PARTNER_CAP_MAX = 16
ANTIMATCH_DRAIN_FIXED = 0.15
ANTIMATCH_DRAIN_MAX_JITTER = 0.05

random.seed(420)

_msg_counter = [1]
def next_msg_id():
    _msg_counter[0] += 1
    return _msg_counter[0]

def rand_weights(n, low=-0.1, high=0.1):
    return [{"value": round(random.uniform(low, high), 6),
             "jitter_eligible": random.random() < 0.3,
             "last_wobble": 0.0} for _ in range(n)]

def rand_positive(n, low=0.01, high=0.5):
    return [{"value": round(random.uniform(low, high), 6),
             "jitter_eligible": random.random() < 0.3,
             "last_wobble": 0.0} for _ in range(n)]

# ════════════════════════════════════════════════════════════════════
# LOBES
# ════════════════════════════════════════════════════════════════════
lobes = [
    {"id": "lobe_math", "subject": "mathematics", "name": "Number Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_physics", "lobe_logic"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000000.0,
     "subject_whitelist": ["math", "calculus", "algebra", "number", "equation", "integral", "derivative"]},
    {"id": "lobe_physics", "subject": "physics", "name": "Force Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_math", "lobe_chemistry"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000001.0,
     "subject_whitelist": ["physics", "force", "energy", "motion", "gravity", "velocity", "momentum"]},
    {"id": "lobe_chemistry", "subject": "chemistry", "name": "Element Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_physics", "lobe_biology"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000002.0,
     "subject_whitelist": ["chemistry", "element", "molecule", "reaction", "bond", "atom", "compound"]},
    {"id": "lobe_biology", "subject": "biology", "name": "Life Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_chemistry", "lobe_ecology"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000003.0,
     "subject_whitelist": ["biology", "cell", "dna", "protein", "organism", "evolution", "gene"]},
    {"id": "lobe_ecology", "subject": "ecology", "name": "Forest Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_biology", "lobe_climate"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000004.0,
     "subject_whitelist": ["ecology", "ecosystem", "habitat", "biodiversity", "predator", "prey", "species"]},
    {"id": "lobe_climate", "subject": "climate", "name": "Weather Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_ecology"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000005.0,
     "subject_whitelist": ["climate", "weather", "temperature", "atmosphere", "rain", "storm", "wind"]},
    {"id": "lobe_logic", "subject": "logic", "name": "Reason Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_math", "lobe_philosophy"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000006.0,
     "subject_whitelist": ["logic", "reason", "proof", "argument", "deduction", "induction", "syllogism"]},
    {"id": "lobe_philosophy", "subject": "philosophy", "name": "Thought Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_logic", "lobe_emotion"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000007.0,
     "subject_whitelist": ["philosophy", "ethics", "metaphysics", "consciousness", "truth", "existence", "meaning"]},
    {"id": "lobe_emotion", "subject": "emotion", "name": "Heart Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_philosophy"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000008.0,
     "subject_whitelist": ["emotion", "feeling", "fear", "joy", "sadness", "anger", "love"]},
    {"id": "lobe_tech", "subject": "technology", "name": "Machine Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_math", "lobe_logic"],
     "node_cap": 500, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000009.0,
     "subject_whitelist": ["technology", "computer", "software", "hardware", "algorithm", "data", "network"]},
    {"id": "lobe_general", "subject": "general", "name": "Common Cave",
     "node_ids": [], "connected_lobe_ids": ["lobe_math", "lobe_physics", "lobe_chemistry",
                                            "lobe_biology", "lobe_logic", "lobe_philosophy",
                                            "lobe_emotion", "lobe_tech", "lobe_ecology", "lobe_climate"],
     "node_cap": 2000, "fire_count": 0, "inhibit_count": 0, "created_at": 1700000010.0,
     "subject_whitelist": ["general", "hello", "hi", "help", "what", "how", "why", "grug"]},
]
lobe_id_map = {l["id"]: l for l in lobes}

nodes = []
node_map = {}
def add(node, lobe_id):
    nodes.append(node)
    node_map[node["id"]] = node
    if lobe_id in lobe_id_map:
        lobe_id_map[lobe_id]["node_ids"].append(node["id"])
    return node

# ════════════════════════════════════════════════════════════════════
# NODES — each uses a voice_key for topic-specific content
# ════════════════════════════════════════════════════════════════════

# ── 1. REASON nodes ──
n1 = add(make_node(next_node_id(), "what is gravity", "reason^1",
        json_data={"mode": "reason"}, voice_key="gravity", strength=7.5), "lobe_physics")
n2 = add(make_node(next_node_id(), "what is evolution", "reason^1",
        json_data={"mode": "reason"}, voice_key="evolution", strength=6.8), "lobe_biology")
n3 = add(make_node(next_node_id(), "what is a derivative", "reason^1",
        json_data={"mode": "reason"}, voice_key="derivative", strength=7.0), "lobe_math")
n4 = add(make_node(next_node_id(), "what is climate change", "reason^1",
        json_data={"mode": "reason"}, voice_key="climate_change", strength=6.5), "lobe_climate")

# ── 2. EXPLAIN nodes ──
n5 = add(make_node(next_node_id(), "explain photosynthesis", "explain^1",
        json_data={"mode": "explain"}, voice_key="photosynthesis", strength=8.0), "lobe_biology")
n6 = add(make_node(next_node_id(), "explain newtons laws", "explain^1",
        json_data={"mode": "explain"}, voice_key="newtons_laws", strength=7.2), "lobe_physics")
n7 = add(make_node(next_node_id(), "explain how computers work", "explain^1",
        json_data={"mode": "explain"}, voice_key="computers", strength=6.5), "lobe_tech")

# ── 3. DEFINE nodes ──
n8 = add(make_node(next_node_id(), "define entropy", "define^1",
        json_data={"mode": "define"}, voice_key="entropy", strength=7.5), "lobe_physics")
n9 = add(make_node(next_node_id(), "define algorithm", "define^1",
        json_data={"mode": "define"}, voice_key="algorithm", strength=7.0), "lobe_tech")
n10 = add(make_node(next_node_id(), "define species", "define^1",
        json_data={"mode": "define"}, voice_key="species", strength=6.8), "lobe_biology")

# ── 4. ALERT nodes ──
n11 = add(make_node(next_node_id(), "danger radiation", "alert^1",
        json_data={"mode": "alert"}, voice_key="radiation", strength=8.5), "lobe_physics")
n12 = add(make_node(next_node_id(), "danger toxin chemical", "alert^1",
        json_data={"mode": "alert"}, voice_key="toxin", strength=8.0), "lobe_chemistry")

# ── 5. COMFORT nodes ──
n13 = add(make_node(next_node_id(), "i am sad", "comfort^1",
        json_data={"mode": "comfort"}, voice_key="sadness", strength=7.0), "lobe_emotion")
n14 = add(make_node(next_node_id(), "i am scared afraid", "comfort^1",
        json_data={"mode": "comfort"}, voice_key="fear", strength=7.5), "lobe_emotion")

# ── 6. MATH nodes ──
n15 = add(make_node(next_node_id(), "calculate integral", "reason^1",
        json_data={"mode": "math", "math_expression": "integral(x^2, x, 0, 1)"},
        voice_key="integral", strength=8.0), "lobe_math")
n16 = add(make_node(next_node_id(), "calculate fibonacci", "reason^1",
        json_data={"mode": "math", "math_expression": "fibonacci(n)"},
        voice_key="fibonacci", strength=7.5), "lobe_math")
n17 = add(make_node(next_node_id(), "calculate pi digits", "reason^1",
        json_data={"mode": "math", "math_expression": "pi"},
        voice_key="pi", strength=7.0), "lobe_math")

# ── 7. RELATE nodes ──
n18 = add(make_node(next_node_id(), "sun causes warmth", "reason^1",
        json_data={"answer_mode": "relate"}, voice_key="sun_warmth",
        relational_patterns=[make_triple("sun", "causes", "warmth"),
                             make_triple("sun", "produces", "light")],
        required_relations=["causes"], relation_weights={"causes": 1.0, "produces": 0.8},
        strength=7.0), "lobe_physics")
n19 = add(make_node(next_node_id(), "predator eats prey", "reason^1",
        json_data={"answer_mode": "relate"}, voice_key="predator_prey",
        relational_patterns=[make_triple("predator", "eats", "prey"),
                             make_triple("predator", "hunts", "prey")],
        required_relations=[], relation_weights={"eats": 1.0, "hunts": 0.7},
        strength=7.5), "lobe_ecology")
n20 = add(make_node(next_node_id(), "learning requires practice", "reason^1",
        json_data={"answer_mode": "relate"}, voice_key="learning_practice",
        relational_patterns=[make_triple("learning", "requires", "practice"),
                             make_triple("practice", "improves", "skill")],
        required_relations=["requires"], relation_weights={"requires": 1.0, "improves": 0.6},
        strength=6.5), "lobe_philosophy")

# ── 8. TIME nodes ──
n21 = add(make_node(next_node_id(), "what happens in spring", "reason^1",
        json_data={"answer_mode": "time", "time_node": True, "time_orientation": "now",
                   "time_sigil": "&now", "time_gate_start": "march", "time_gate_end": "june",
                   "temporal_label": "spring"}, voice_key="spring", strength=6.5), "lobe_ecology")
n22 = add(make_node(next_node_id(), "what happened before big bang", "reason^1",
        json_data={"answer_mode": "time", "time_node": True, "time_orientation": "before",
                   "time_sigil": "&before", "temporal_label": "pre-universe"},
        voice_key="before_big_bang", strength=5.5), "lobe_physics")
n23 = add(make_node(next_node_id(), "next technological revolution", "reason^1",
        json_data={"answer_mode": "time", "time_node": True, "time_orientation": "next",
                   "time_sigil": "&next", "temporal_label": "future-tech"},
        voice_key="tech_revolution", strength=5.0), "lobe_tech")

# ── 9. PROC nodes ──
n24 = add(make_node(next_node_id(), "how to solve quadratic equation", "reason^1",
        json_data={"answer_mode": "proc", "proc_chain": True, "step_count": 4,
                   "steps": ["write equation in standard form ax2+bx+c=0",
                             "identify coefficients a, b, c",
                             "apply quadratic formula x = (-b +/- sqrt(b2-4ac)) / 2a",
                             "simplify and find both solutions"]},
        voice_key="quadratic", strength=7.5), "lobe_math")
n25 = add(make_node(next_node_id(), "how to do scientific experiment", "reason^1",
        json_data={"answer_mode": "proc", "proc_chain": True, "step_count": 5,
                   "steps": ["observe and ask question", "form hypothesis",
                             "design experiment with controls", "collect and analyze data",
                             "draw conclusion and communicate results"]},
        voice_key="experiment", strength=6.5), "lobe_general")

# ── 10. JSON nodes ──
n26 = add(make_node(next_node_id(), "periodic table data", "reason^1",
        json_data={"answer_mode": "json", "json_passthrough": True,
                   "json_payload": {"elements": ["H", "He", "Li", "Be", "B"],
                                    "counts": [1, 2, 3, 4, 5]}},
        voice_key="periodic_table", strength=6.0), "lobe_chemistry")
n27 = add(make_node(next_node_id(), "population statistics", "reason^1",
        json_data={"answer_mode": "json", "json_passthrough": True,
                   "json_payload": {"world_population": 8000000000, "growth_rate": 1.0, "continents": 7}},
        voice_key="population_stats", strength=5.5), "lobe_general")

# ── 11. MULTI nodes ──
n28 = add(make_node(next_node_id(), "compare dna and rna", "reason^1",
        json_data={"answer_mode": "multi", "multipart_group": "dna_rna_compare", "multipart_role": "primary"},
        voice_key="dna_rna", strength=7.0), "lobe_biology")
n29 = add(make_node(next_node_id(), "compare heat and temperature", "reason^1",
        json_data={"answer_mode": "multi", "multipart_group": "heat_temp_compare", "multipart_role": "primary"},
        voice_key="heat_temperature", strength=6.5), "lobe_physics")

# ── 12. ANTIMATCH nodes ──
n30 = add(make_node(next_node_id(), "not a bug", "reason^1",
        json_data={"mode": "reason"}, is_antimatch_node=True, strength=0.0,
        drop_table=["bug", "error", "fault"]), "lobe_tech")
n31 = add(make_node(next_node_id(), "not dangerous safe", "reason^1",
        json_data={"mode": "reason"}, is_antimatch_node=True, strength=0.0,
        drop_table=["danger", "hazard", "risk"]), "lobe_general")

# ── 13. IMAGE (SDF) nodes ──
n32 = add(make_node(next_node_id(), "circle_sdf", "reason^1",
        json_data={"mode": "reason", "is_image_node": True, "sdf_type": "circle",
                   "sdf_params": {"radius": 1.0, "cx": 0.0, "cy": 0.0}},
        is_image_node=True, strength=5.0), "lobe_math")
n33 = add(make_node(next_node_id(), "rectangle_sdf", "reason^1",
        json_data={"mode": "reason", "is_image_node": True, "sdf_type": "rectangle",
                   "sdf_params": {"width": 2.0, "height": 1.0}},
        is_image_node=True, strength=5.0), "lobe_math")

# ── 14. GRAVE nodes ──
n34 = add(make_node(next_node_id(), "obsolete theory phlogiston", "reason^1",
        json_data={"mode": "reason"}, is_grave=True, grave_reason="STRENGTH_ZERO", strength=0.0), "lobe_chemistry")
n35 = add(make_node(next_node_id(), "deprecated flat earth", "reason^1",
        json_data={"mode": "reason"}, is_grave=True, grave_reason="GRAVED-SLOW", strength=0.0,
        response_times=[5.2, 6.1, 7.8, 8.3]), "lobe_general")

# ── 15. PLAIN MATCH / greeting / philosophy nodes ──
n36 = add(make_node(next_node_id(), "hello", "reason^1",
        json_data={"mode": "reason"}, voice_key="hello", strength=9.0), "lobe_general")
n37 = add(make_node(next_node_id(), "hi greetings hey", "reason^1",
        json_data={"mode": "reason"}, voice_key="hi_greetings", strength=8.5,
        drop_table=["hello", "greetings", "hey"]), "lobe_general")
n38 = add(make_node(next_node_id(), "what is the meaning of life", "reason^1",
        json_data={"mode": "reason"}, voice_key="meaning_of_life", strength=6.0), "lobe_philosophy")
n39 = add(make_node(next_node_id(), "what is consciousness", "reason^1",
        json_data={"mode": "reason"}, voice_key="consciousness", strength=6.0), "lobe_philosophy")

# ── 16. ADDITIONAL coverage nodes ──
n40 = add(make_node(next_node_id(), "what is a chemical bond", "reason^1",
        json_data={"mode": "reason"}, voice_key="chemical_bond", strength=7.0), "lobe_chemistry")
n41 = add(make_node(next_node_id(), "what is biodiversity", "reason^1",
        json_data={"mode": "reason"}, voice_key="biodiversity", strength=6.5), "lobe_ecology")
n42 = add(make_node(next_node_id(), "explain relativity", "explain^1",
        json_data={"mode": "explain"}, voice_key="relativity", strength=7.5), "lobe_physics")
n43 = add(make_node(next_node_id(), "explain the water cycle", "explain^1",
        json_data={"mode": "explain"}, voice_key="water_cycle", strength=7.0), "lobe_climate")
n44 = add(make_node(next_node_id(), "define ecosystem", "define^1",
        json_data={"mode": "define"}, voice_key="ecosystem", strength=6.5), "lobe_ecology")
n45 = add(make_node(next_node_id(), "define justice", "define^1",
        json_data={"mode": "define"}, voice_key="justice", strength=5.5), "lobe_philosophy")
n46 = add(make_node(next_node_id(), "i feel lost confused", "comfort^1",
        json_data={"mode": "comfort"}, voice_key="lost", strength=6.5), "lobe_emotion")
n47 = add(make_node(next_node_id(), "calculate euler number", "reason^1",
        json_data={"mode": "math", "math_expression": "e"}, voice_key="euler", strength=7.0), "lobe_math")
n48 = add(make_node(next_node_id(), "fire causes heat", "reason^1",
        json_data={"answer_mode": "relate"}, voice_key="fire_heat",
        relational_patterns=[make_triple("fire", "causes", "heat"),
                             make_triple("fire", "consumes", "fuel")],
        required_relations=["causes"], relation_weights={"causes": 1.0, "consumes": 0.7},
        strength=7.0), "lobe_physics")
n49 = add(make_node(next_node_id(), "education enables progress", "reason^1",
        json_data={"answer_mode": "relate"}, voice_key="education_progress",
        relational_patterns=[make_triple("education", "enables", "progress"),
                             make_triple("progress", "requires", "effort")],
        required_relations=["enables"], relation_weights={"enables": 1.0, "requires": 0.6},
        strength=6.0), "lobe_philosophy")
n50 = add(make_node(next_node_id(), "winter seasonal cold", "reason^1",
        json_data={"answer_mode": "time", "time_node": True, "time_orientation": "now",
                   "time_sigil": "&now", "time_gate_start": "december", "time_gate_end": "february",
                   "temporal_label": "winter"}, voice_key="winter", strength=5.5), "lobe_climate")
n51 = add(make_node(next_node_id(), "danger extinction", "alert^1",
        json_data={"mode": "alert"}, voice_key="extinction", strength=8.0), "lobe_ecology")
n52 = add(make_node(next_node_id(), "how to build a fire", "reason^1",
        json_data={"answer_mode": "proc", "proc_chain": True, "step_count": 3,
                   "steps": ["gather dry tinder", "create spark with flint",
                             "feed flame gradually with kindling"]},
        voice_key="build_fire", strength=7.5), "lobe_general")


# ── 17. NOVEL-QUERY COVERAGE nodes (ML, quantum, dark matter) ──
n53 = add(make_node(next_node_id(), "explain machine learning", "explain^1",
        json_data={"mode": "explain"},
        voice_key="machine_learning", strength=6.5), "lobe_tech")
n54 = add(make_node(next_node_id(), "what is quantum computing", "reason^1",
        json_data={"mode": "reason"},
        voice_key="quantum_computing", strength=6.0), "lobe_tech")
n55 = add(make_node(next_node_id(), "what is dark matter", "reason^1",
        json_data={"mode": "reason"},
        voice_key="dark_matter", strength=6.0), "lobe_physics")

# ════════════════════════════════════════════════════════════════════
# NEIGHBOR LINKING
# ════════════════════════════════════════════════════════════════════
n1["neighbor_ids"] = [n6["id"], n8["id"], n42["id"], n48["id"], n22["id"]]
n6["neighbor_ids"] = [n1["id"], n8["id"], n42["id"]]
n8["neighbor_ids"] = [n1["id"], n6["id"], n42["id"]]
n42["neighbor_ids"] = [n1["id"], n6["id"], n8["id"]]
n48["neighbor_ids"] = [n1["id"], n11["id"]]
n11["neighbor_ids"] = [n48["id"], n1["id"]]
n22["neighbor_ids"] = [n1["id"]]
n3["neighbor_ids"] = [n15["id"], n16["id"], n17["id"], n47["id"], n24["id"]]
n15["neighbor_ids"] = [n3["id"], n16["id"], n47["id"]]
n16["neighbor_ids"] = [n3["id"], n15["id"], n47["id"]]
n17["neighbor_ids"] = [n3["id"], n15["id"]]
n47["neighbor_ids"] = [n3["id"], n15["id"], n16["id"]]
n24["neighbor_ids"] = [n3["id"]]
n2["neighbor_ids"] = [n5["id"], n10["id"], n28["id"]]
n5["neighbor_ids"] = [n2["id"], n10["id"]]
n10["neighbor_ids"] = [n2["id"], n5["id"]]
n28["neighbor_ids"] = [n2["id"], n5["id"]]
n40["neighbor_ids"] = [n12["id"], n26["id"]]
n12["neighbor_ids"] = [n40["id"]]
n26["neighbor_ids"] = [n40["id"]]
n41["neighbor_ids"] = [n19["id"], n44["id"], n51["id"]]
n19["neighbor_ids"] = [n41["id"], n44["id"], n51["id"]]
n44["neighbor_ids"] = [n41["id"], n19["id"]]
n51["neighbor_ids"] = [n41["id"], n19["id"]]
n38["neighbor_ids"] = [n39["id"], n20["id"], n45["id"], n49["id"]]
n39["neighbor_ids"] = [n38["id"], n20["id"], n45["id"]]
n20["neighbor_ids"] = [n38["id"], n49["id"]]
n45["neighbor_ids"] = [n38["id"], n39["id"]]
n49["neighbor_ids"] = [n38["id"], n20["id"]]
n13["neighbor_ids"] = [n14["id"], n46["id"]]
n14["neighbor_ids"] = [n13["id"], n46["id"]]
n46["neighbor_ids"] = [n13["id"], n14["id"]]
n36["neighbor_ids"] = [n37["id"], n25["id"], n52["id"]]
n37["neighbor_ids"] = [n36["id"]]
n25["neighbor_ids"] = [n36["id"], n52["id"]]
n52["neighbor_ids"] = [n36["id"], n25["id"]]
n9["neighbor_ids"] = [n7["id"], n23["id"]]
n7["neighbor_ids"] = [n9["id"], n23["id"]]
n23["neighbor_ids"] = [n9["id"], n7["id"]]
n4["neighbor_ids"] = [n43["id"], n50["id"]]
n43["neighbor_ids"] = [n4["id"], n50["id"]]
n50["neighbor_ids"] = [n4["id"], n43["id"]]
n53["neighbor_ids"] = [n7["id"], n54["id"], n9["id"]]
n54["neighbor_ids"] = [n53["id"], n55["id"], n7["id"]]
n55["neighbor_ids"] = [n1["id"], n54["id"], n42["id"]]


# ════════════════════════════════════════════════════════════════════
# BUILD SPECIMEN
# ════════════════════════════════════════════════════════════════════
specimen = {}
specimen["nodes"] = nodes

specimen["hopfield_cache"] = [
    {"hash": "1234567890", "node_ids": [n1["id"], n6["id"]], "hit_count": 5},
    {"hash": "9876543210", "node_ids": [n3["id"], n15["id"]], "hit_count": 3},
    {"hash": "5555555555", "node_ids": [n36["id"]], "hit_count": 12},
]
specimen["rules"] = [
    {"text": "when user asks about force, explain newtons laws", "prob": 0.7},
    {"text": "when user asks about math, compute precisely", "prob": 0.6},
    {"text": "when user expresses fear, respond with comfort", "prob": 0.8},
    {"text": "when user mentions danger, alert with caution", "prob": 0.75},
]
specimen["message_history"] = [
    {"id": next_msg_id(), "role": "user", "text": "hello", "pinned": False, "intensity": 0.5},
    {"id": next_msg_id(), "role": "assistant", "text": "Grug greet you! Grug happy you visit cave.", "pinned": False, "intensity": 0.3},
]

for lobe in lobes:
    lobe["node_ids"] = sorted(lobe["node_ids"])
specimen["lobes"] = lobes

node_to_lobe_idx = {}
for lobe in lobes:
    for nid in lobe["node_ids"]:
        node_to_lobe_idx[nid] = lobe["id"]
specimen["node_to_lobe_idx"] = node_to_lobe_idx

lobe_tables = []
for lobe in lobes:
    # v10-coherence-fix: NodeRefs MUST live in the "nodes" chunk (CHUNK_NODES
    # in LobeTable.jl) — that is the chunk get_active_node_ids() reads. The
    # earlier version wrote them under "json", so get_active_node_ids raised
    # KeyError("nodes") and the cross-lobe cascade (PASS 2) silently produced
    # no candidates from named lobes, which after AutoGrowth let orphan learned
    # nodes win. Also include ALL node IDs (was capped at [:3]) so every node in
    # the lobe is discoverable by the cascade.
    chunks = {"nodes": {}, "json": {}, "drop": {}, "hopfield": {},
              "meta": {"lobe_created": lobe["created_at"], "lobe_subject": lobe["subject"]}}
    for nid in lobe["node_ids"]:
        chunks["nodes"][nid] = {"_type": "NodeRef", "node_id": nid, "lobe_id": lobe["id"],
                                "is_active": True, "inserted_at": time_mod.time()}
    lobe_tables.append({"lobe_id": lobe["id"], "chunks": chunks, "created_at": lobe["created_at"]})
specimen["lobe_tables"] = lobe_tables

specimen["verb_registry"] = {
    "classes": {
        "causal": sorted(["causes", "produces", "enables", "prevents", "requires", "creates", "destroys", "generates"]),
        "spatial": sorted(["contains", "inside", "near", "far", "above", "below", "between", "around", "through"]),
        "temporal": sorted(["before", "after", "during", "while", "until", "since", "simultaneous", "precedes", "follows"]),
    },
    "synonyms": {"produces": "causes", "generates": "causes", "creates": "causes",
                 "holds": "contains", "encompasses": "contains", "precedes": "before", "prior to": "before"}
}
specimen["thesaurus_seeds"] = {
    "gravity": sorted(["force", "attraction", "pull", "weight"]),
    "evolution": sorted(["adaptation", "natural selection", "change", "descent"]),
    "math": sorted(["mathematics", "calculation", "computation", "arithmetic"]),
    "energy": sorted(["power", "force", "vigor", "strength"]),
    "dna": sorted(["deoxyribonucleic acid", "genetic code", "genome"]),
    "atom": sorted(["particle", "molecule", "element"]),
    "computer": sorted(["machine", "processor", "calculation device"]),
    "logic": sorted(["reason", "rationality", "deduction"]),
    "emotion": sorted(["feeling", "sentiment", "affect"]),
    "climate": sorted(["weather", "atmosphere", "conditions"]),
    "photosynthesis": sorted(["light reaction", "carbon fixation", "plant energy"]),
    "entropy": sorted(["disorder", "chaos", "randomness"]),
    "algorithm": sorted(["procedure", "method", "process", "recipe"]),
    "ecosystem": sorted(["habitat", "biome", "environment"]),
    "fear": sorted(["terror", "dread", "anxiety", "fright"]),
    "integral": sorted(["antiderivative", "integration", "area under curve"]),
    "derivative": sorted(["rate of change", "slope", "differential"]),
}
specimen["inhibitions"] = [
    {"word": "hate", "reason": "hostile language filter", "added_at": 1700000000.0},
    {"word": "kill", "reason": "violent language filter", "added_at": 1700000001.0},
    {"word": "stupid", "reason": "derogatory language filter", "added_at": 1700000002.0},
]
specimen["arousal"] = {"level": 0.3, "decay_rate": 0.05, "baseline": 0.3}
specimen["eye_state"] = {"attention_enabled": True, "blur_enabled": True,
                         "last_centroid_x": 0.5, "last_centroid_y": 0.5, "last_arousal": 0.3}
specimen["id_counters"] = {"node_id_counter": _next_id[0] + 1, "msg_id_counter": _msg_counter[0] + 1}
specimen["last_voters"] = [n1["id"], n6["id"]]
specimen["brainstem"] = {
    "dispatch_count": 10, "last_winner_id": "lobe_physics", "last_dispatch_t": 1700000050.0,
    "propagation_history": [
        {"source_lobe_id": "lobe_physics", "target_lobe_id": "lobe_math", "confidence": 0.6, "dispatch_count": 3},
        {"source_lobe_id": "lobe_biology", "target_lobe_id": "lobe_chemistry", "confidence": 0.55, "dispatch_count": 2},
    ]
}

bridges = [
    {"node_a": n1["id"], "node_b": n3["id"], "seam_tokens": ["force", "math", "field"],
     "base_confidence_ab": 0.7, "base_confidence_ba": 0.65, "source_lobe": "lobe_physics",
     "is_crystalized": True, "crystal_origin": "auto"},
    {"node_a": n5["id"], "node_b": n40["id"], "seam_tokens": ["molecule", "reaction", "energy"],
     "base_confidence_ab": 0.6, "base_confidence_ba": 0.55, "source_lobe": "lobe_biology",
     "is_crystalized": False, "crystal_origin": "none"},
    {"node_a": n1["id"], "node_b": n4["id"], "seam_tokens": ["atmosphere", "force", "energy"],
     "base_confidence_ab": 0.5, "base_confidence_ba": 0.45, "source_lobe": "lobe_physics",
     "is_crystalized": False, "crystal_origin": "none"},
    {"node_a": n41["id"], "node_b": n2["id"], "seam_tokens": ["species", "adaptation", "diversity"],
     "base_confidence_ab": 0.65, "base_confidence_ba": 0.6, "source_lobe": "lobe_ecology",
     "is_crystalized": True, "crystal_origin": "user"},
    {"node_a": n9["id"], "node_b": n16["id"], "seam_tokens": ["computation", "sequence", "number"],
     "base_confidence_ab": 0.55, "base_confidence_ba": 0.5, "source_lobe": "lobe_tech",
     "is_crystalized": False, "crystal_origin": "none"},
    {"node_a": n53["id"], "node_b": n7["id"], "seam_tokens": ["algorithm", "data", "computation"],
     "base_confidence_ab": 0.6, "base_confidence_ba": 0.55, "source_lobe": "lobe_tech",
     "is_crystalized": False, "crystal_origin": "none"},
    {"node_a": n54["id"], "node_b": n55["id"], "seam_tokens": ["quantum", "physics", "cosmos"],
     "base_confidence_ab": 0.65, "base_confidence_ba": 0.6, "source_lobe": "lobe_physics",
     "is_crystalized": False, "crystal_origin": "none"},
    {"node_a": n55["id"], "node_b": n1["id"], "seam_tokens": ["gravity", "mass", "universe"],
     "base_confidence_ab": 0.55, "base_confidence_ba": 0.5, "source_lobe": "lobe_physics",
     "is_crystalized": False, "crystal_origin": "none"},
]
specimen["bridges"] = bridges

attachments = []
for b in bridges:
    pat_str = " ".join(b["seam_tokens"]) if b["seam_tokens"] else ""
    attachments.append({"target_id": b["node_a"], "node_id": b["node_b"], "pattern": pat_str,
                        "signal": [], "base_confidence": b["base_confidence_ab"],
                        "is_crystalized": b["is_crystalized"], "crystal_origin": b["crystal_origin"]})
specimen["attachments"] = attachments

chatter_groups = [
    {"id": "grp_physics", "members": [n1["id"], n6["id"], n8["id"], n42["id"], n48["id"]],
     "centroid_pattern": "physics force energy", "created_at": 1700000100.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_math", "members": [n3["id"], n15["id"], n16["id"], n17["id"], n47["id"], n24["id"]],
     "centroid_pattern": "math calculate number", "created_at": 1700000101.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_bio", "members": [n2["id"], n5["id"], n10["id"], n28["id"]],
     "centroid_pattern": "biology life dna", "created_at": 1700000102.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_chem", "members": [n40["id"], n12["id"], n26["id"]],
     "centroid_pattern": "chemistry element molecule", "created_at": 1700000103.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_eco", "members": [n41["id"], n19["id"], n44["id"], n51["id"]],
     "centroid_pattern": "ecology ecosystem habitat", "created_at": 1700000104.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_phil", "members": [n38["id"], n39["id"], n20["id"], n45["id"], n49["id"]],
     "centroid_pattern": "philosophy truth meaning", "created_at": 1700000105.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_emo", "members": [n13["id"], n14["id"], n46["id"]],
     "centroid_pattern": "emotion feeling fear", "created_at": 1700000106.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_general", "members": [n36["id"], n37["id"], n25["id"], n52["id"]],
     "centroid_pattern": "general hello help", "created_at": 1700000107.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},
    {"id": "grp_time", "members": [n21["id"], n50["id"], n22["id"], n23["id"]],
     "centroid_pattern": "time temporal seasonal", "created_at": 1700000108.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": True, "is_chatter_eligible": True},    {"id": "grp_tech", "members": [n7["id"], n53["id"], n54["id"], n55["id"]],
     "centroid_pattern": "computer technology quantum data", "created_at": 1700000110.0, "last_chatter_at": 0.0,
     "chatter_count": 0, "has_grave_slot": False, "max_occupancy": 32, "is_time_node_group": False, "is_chatter_eligible": True},

]
specimen["chatter_groups"] = chatter_groups
specimen["chatter_cooldowns"] = []

specimen["trajectory"] = {
    "config": {"buffer_size": 128, "decay_halflife": 25.0, "gini_threshold": 0.65,
               "damping_strength": 0.3, "softmax_temperature": 1.0},
    "buffer": [{"action_dist": {"ACTION_QUERY": 0.5, "ACTION_COMMAND": 0.1, "ACTION_NEGATE": 0.05,
                                "ACTION_ASSERT": 0.2, "ACTION_SPECULATE": 0.1, "ACTION_ESCALATE": 0.05},
                "tone_dist": {"TONE_HOSTILE": 0.02, "TONE_CURIOUS": 0.4, "TONE_DECLARATIVE": 0.3,
                              "TONE_URGENT": 0.05, "TONE_NEUTRAL": 0.2, "TONE_REFLECTIVE": 0.03},
                "timestamp": 1700000040.0}]
}
specimen["temporal_coherence"] = [
    {"sdf_id": n32["id"], "last_fired": 1700000030.0, "fire_count": 3, "avg_interval": 10.0, "coherence_score": 0.8},
    {"sdf_id": n33["id"], "last_fired": 1700000035.0, "fire_count": 2, "avg_interval": 15.0, "coherence_score": 0.6},
]
specimen["morph_cooldowns"] = {}
specimen["immune_system"] = {
    "ledger": [{"timestamp": 1700000000.0, "kind": "scan_pass", "signature": 0, "info": "initial scan clean"}],
    "hopfield_memory": [], "aiml_quarantine": []
}
specimen["aiml_system"] = {
    "registry": {
        "lobe_physics": [{"id": "aiml_phys_1", "lobe_id": "lobe_physics",
            "template": "Grug explain gravity. Gravity is force that pulls things together. Big things pull harder.",
            "strength": 7.0, "is_grave": False, "grave_reason": "", "voted_this_cycle": False,
            "fired_this_cycle": False, "gained_this_cycle": False, "strength_delta_this_cycle": 0.0, "created_at": 1700000000.0}],
        "lobe_math": [{"id": "aiml_math_1", "lobe_id": "lobe_math",
            "template": "Grug compute. Numbers are language. Grug add and subtract with care.",
            "strength": 7.0, "is_grave": False, "grave_reason": "", "voted_this_cycle": False,
            "fired_this_cycle": False, "gained_this_cycle": False, "strength_delta_this_cycle": 0.0, "created_at": 1700000000.0}],
        "lobe_biology": [{"id": "aiml_bio_1", "lobe_id": "lobe_biology",
            "template": "Grug explain life. Living things grow and change. Sun gives energy to plants.",
            "strength": 6.5, "is_grave": False, "grave_reason": "", "voted_this_cycle": False,
            "fired_this_cycle": False, "gained_this_cycle": False, "strength_delta_this_cycle": 0.0, "created_at": 1700000000.0}],
    },
    "tribes": {"physics_tribe": {"population_cap": 50, "voice_preference": "explanatory"},
               "math_tribe": {"population_cap": 50, "voice_preference": "terse"},
               "bio_tribe": {"population_cap": 50, "voice_preference": "explanatory"}},
    "population_caps": {"lobe_physics": 50, "lobe_math": 50, "lobe_biology": 50},
    "cycle": 0, "stochastic_growth_prob": 0.15, "cycle_count": 0
}
specimen["sigil_table"] = [
    {"name": "noun", "class": "macro", "applies_at": "bind", "sigil_type": None,
     "lexicon": sorted(["thing", "object", "concept", "entity", "item"]), "params": {},
     "expansion": None, "provenance": "specimen-override", "promote_at_tokenize": True},
    {"name": "verb", "class": "macro", "applies_at": "bind", "sigil_type": None,
     "lexicon": sorted(["action", "process", "do", "make", "create"]), "params": {},
     "expansion": None, "provenance": "specimen-custom", "promote_at_tokenize": True},
    {"name": "temporal", "class": "macro", "applies_at": "bind", "sigil_type": None,
     "lexicon": sorted(["now", "before", "after", "during", "while", "next", "soon", "later"]), "params": {},
     "expansion": None, "provenance": "specimen-custom", "promote_at_tokenize": True},
    {"name": "question", "class": "tag", "applies_at": "match", "sigil_type": None, "lexicon": None,
     "params": {}, "expansion": None, "provenance": "specimen-custom", "promote_at_tokenize": False},
    {"name": "causal", "class": "relation", "applies_at": "relation", "sigil_type": None, "lexicon": None,
     "params": {}, "expansion": sorted(["causes", "produces", "enables", "prevents"]),
     "provenance": "specimen-custom", "promote_at_tokenize": False},
    {"name": "math_exp", "class": "macro", "applies_at": "bind", "sigil_type": None,
     "lexicon": sorted(["calculate", "compute", "solve", "evaluate", "integrate", "derive"]), "params": {},
     "expansion": None, "provenance": "specimen-custom", "promote_at_tokenize": True},
    {"name": "adj", "class": "macro", "applies_at": "bind", "sigil_type": None,
     "lexicon": sorted(["big", "small", "fast", "slow", "hot", "cold", "heavy", "light"]), "params": {},
     "expansion": None, "provenance": "specimen-custom", "promote_at_tokenize": True},
]
specimen["automaton_rules"] = [
    {"id": "rule_escalate_query", "trigger_action": "ACTION_QUERY",
     "steps": [{"label": "assess_confidence", "op": "threshold_check", "payload": {"min": 0.3}},
               {"label": "boost_signal", "op": "amplify", "payload": {"factor": 1.2}},
               {"label": "emit_result", "op": "emit", "payload": {}}],
     "jitter_targets": ["boost_signal"], "min_confidence": 0.3},
    {"id": "rule_escalate_command", "trigger_action": "ACTION_COMMAND",
     "steps": [{"label": "verify_intent", "op": "validate", "payload": {"schema": "command"}},
               {"label": "execute_step", "op": "execute", "payload": {}},
               {"label": "report_back", "op": "emit", "payload": {}}],
     "jitter_targets": ["execute_step"], "min_confidence": 0.5},
    {"id": "rule_escalate_speculate", "trigger_action": "ACTION_SPECULATE",
     "steps": [{"label": "gather_evidence", "op": "lookup", "payload": {"source": "thesaurus"}},
               {"label": "hypothesize", "op": "blend", "payload": {"mode": "markov"}},
               {"label": "present", "op": "emit", "payload": {}}],
     "jitter_targets": ["gather_evidence", "hypothesize"], "min_confidence": 0.4},
]
specimen["phase_accumulator"] = {
    "snapshots": [{"action_dist": {"ACTION_QUERY": 0.6, "ACTION_COMMAND": 0.1, "ACTION_NEGATE": 0.05,
                                   "ACTION_ASSERT": 0.15, "ACTION_SPECULATE": 0.05, "ACTION_ESCALATE": 0.05},
                   "tone_dist": {"TONE_HOSTILE": 0.02, "TONE_CURIOUS": 0.5, "TONE_DECLARATIVE": 0.2,
                                 "TONE_URGENT": 0.03, "TONE_NEUTRAL": 0.2, "TONE_REFLECTIVE": 0.05},
                   "timestamp": 1700000020.0}],
    "pull_threshold": 0.5, "surface_count": 3, "enabled": True
}
specimen["last_contributor_votes"] = [
    {"node_id": n1["id"], "action": "reason^1", "confidence": 0.85, "negatives": [], "user_triples": [],
     "node_triples": [], "antimatch": False, "multipart_group": "", "multipart_role": "none", "input_chunks": [1]},
    {"node_id": n6["id"], "action": "explain^1", "confidence": 0.75, "negatives": [], "user_triples": [],
     "node_triples": [], "antimatch": False, "multipart_group": "", "multipart_role": "none", "input_chunks": [2, 3]},
]
node_to_group = {}
for grp in chatter_groups:
    for mid in grp["members"]:
        node_to_group[mid] = grp["id"]
specimen["node_to_group_idx"] = node_to_group
specimen["tonal_judge_knobs"] = {"frame_lift_multiplier": 1.2, "frame_inhibit_multiplier": 0.8}

_ih_size = VOTE_FEATURE_DIM * HIDDEN_DIM
_ffn1_size = HIDDEN_DIM * FFN_DIM
_ffn2_size = FFN_DIM * HIDDEN_DIM
_ln_size = HIDDEN_DIM
specimen["ephemeral_mlp"] = {
    "weights": {
        "w_input_hidden": rand_weights(_ih_size, -0.05, 0.05),
        "b_hidden": rand_weights(HIDDEN_DIM, -0.01, 0.01),
        "w_hidden_output": rand_weights(HIDDEN_DIM, -0.05, 0.05),
        "b_output": {"value": 0.0, "jitter_eligible": False, "last_wobble": 0.0},
        "w_attention": rand_weights(HIDDEN_DIM * ATTENTION_HEADS, -0.03, 0.03),
        "w_qk": [rand_weights(2 * HIDDEN_DIM * HIDDEN_DIM, -0.03, 0.03) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "w_v": [rand_weights(HIDDEN_DIM * HIDDEN_DIM, -0.03, 0.03) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "w_ffn1": [rand_weights(_ffn1_size, -0.03, 0.03) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "b_ffn1": [rand_weights(FFN_DIM, -0.01, 0.01) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "w_ffn2": [rand_weights(_ffn2_size, -0.03, 0.03) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "b_ffn2": [rand_weights(HIDDEN_DIM, -0.01, 0.01) for _ in range(NUM_TRANSFORMER_BLOCKS)],
        "w_ln_scale": [rand_positive(_ln_size, 0.9, 1.1) for _ in range(NUM_TRANSFORMER_BLOCKS * 2)],
        "w_ln_bias": [rand_weights(_ln_size, -0.01, 0.01) for _ in range(NUM_TRANSFORMER_BLOCKS * 2)],
        "w_output_heads": [rand_weights(HIDDEN_DIM, -0.05, 0.05) for _ in range(NUM_OUTPUT_HEADS)],
        "b_output_heads": rand_weights(NUM_OUTPUT_HEADS, -0.01, 0.01),
    },
    "rules": [
        {"id": "rule_high_curiosity", "pattern": "curiosity", "key": "curiosity",
         "weight": {"value": 1.1, "jitter_eligible": True}, "transform_type": "fuzzy",
         "payload": {"w_exploratory": 0.1, "w_query": 0.05}, "drop_table": [], "fire_count": 0,
         "last_fire_time": 0.0, "enabled": True},
        {"id": "rule_low_confidence", "pattern": "confidence", "key": "confidence",
         "weight": {"value": 0.9, "jitter_eligible": True}, "transform_type": "fuzzy",
         "payload": {"w_contemplative": 0.15, "w_deescalate": 0.08}, "drop_table": [], "fire_count": 0,
         "last_fire_time": 0.0, "enabled": True},
    ],
    "novelty_tracker": {"seen_patterns": {}, "total_seen": 0, "novelty_threshold": 0.7},
    "statistics": {"total_forward_passes": 0, "total_rule_firings": 0, "avg_confidence": 0.5}
}
specimen["mlp_observer_store"] = {"total_entries": 0, "key_count": 0}
specimen["mlp_cached_phi"] = {"last_phi": 0.0}
specimen["decomposer_config"] = {
    "split_conjunctions": sorted(["and", "but", "or", "however", "also", "additionally", "moreover", "furthermore"]),
    "compound_pairs": {"not": ["only", "but"], "neither": ["nor"], "either": ["or"], "both": ["and"]},
    "context_conjunction": "but",
    "question_markers": sorted(["what", "why", "how", "when", "where", "who", "which"]),
    "command_markers": sorted(["please", "can you", "could you", "would you", "tell me", "explain", "define", "calculate"]),
    "conjugation_rules": {"calculate": ["calculates", "calculated", "calculating"],
                          "explain": ["explains", "explained", "explaining"],
                          "define": ["defines", "defined", "defining"],
                          "tell": ["tells", "told", "telling"],
                          "compute": ["computes", "computed", "computing"],
                          "investigate": ["investigates", "investigated", "investigating"]},
}
specimen["vigilance_config"] = {
    "max_agents_per_cycle": 4, "min_confidence_for_injection": 0.3, "feedback_probability": 0.2,
    "context_weight_base": 0.5,
    "injector_dispositions": {"amplifier": {"weight": 1.0, "active": True},
                              "dampener": {"weight": 0.8, "active": True},
                              "redirector": {"weight": 0.6, "active": True}}
}
specimen["injector_stats"] = {"total_dispatched": 0, "total_completed": 0, "total_timed_out": 0,
                              "total_entries_injected": 0, "total_feedback_written": 0}
specimen["relational_jitter_config"] = {"jitter_ratio": 0.1, "jitter_coin_ratio": 0.3, "jitter_enabled": True}
specimen["brainstem_config"] = {"propagation_decay": 0.6, "fire_count_decay_factor": 0.85,
                                "fire_count_decay_interval": 50, "propagation_min_confidence": 0.1}
specimen["engine_config"] = {
    "strength_cap": STRENGTH_CAP, "strength_floor": STRENGTH_FLOOR,
    "strength_solidify_threshold": STRENGTH_SOLIDIFY_THRESHOLD, "jitter_confidence_floor": JITTER_CONFIDENCE_FLOOR,
    "max_neighbors": MAX_NEIGHBORS, "latch_partner_cap_min": LATCH_PARTNER_CAP_MIN,
    "latch_partner_cap_max": LATCH_PARTNER_CAP_MAX, "antimatch_drain_fixed": ANTIMATCH_DRAIN_FIXED,
    "antimatch_drain_max_jitter": ANTIMATCH_DRAIN_MAX_JITTER
}
specimen["lobe_orchestrator_knobs"] = {"hard_fire_batch_cap": 8, "min_pass_through_score": 0.1,
                                       "min_winning_votes_per_lobe": 1, "top_k_fraction": 0.3,
                                       "hard_selection_conf_threshold": 0.7, "default_lobe_demotion_factor": 0.85}
specimen["vote_orchestrator_knobs"] = {
    "aiml_confidence_threshold": 0.4, "aiml_top_tier_window": 0.05, "aiml_subtop_base_prob": 0.3,
    "aiml_subtop_bonus_prob": 0.2, "vote_w_lobe_alignment": 0.15, "vote_w_relational_match": 0.2,
    "vote_w_recency_bonus": 0.1, "vote_w_action_tone_align": 0.15, "vote_w_anti_match_penalty": 0.25,
    "vote_w_peak_dominance": 0.1, "vote_bonus_cap": 0.5, "vote_score_floor": 0.05,
    "active_fire_cap": 20, "fire_batch_size": 5
}
specimen["mitosis_config"] = {
    "mitosis_probability": 0.15, "data_energy_msg_scale": 0.1, "data_energy_intensity_scale": 0.5,
    "max_mitosis_per_cycle": 1, "min_population_gate": 10, "max_population_cap": 10000,
    "mitosis_cooldown_cycles": 5, "silence_warrant_threshold": 0.8, "silence_warrant_min_accum": 3.0,
    "frequency_warrant_min": 5, "thesaurus_warrant_threshold": 0.8, "lobe_coverage_ratio_min": 0.3,
    "min_warrant_threshold": 2, "mitosis_strength_default": 3.0, "pattern_sim_floor": 0.6,
    "vote_sim_floor": 0.5, "group_max_occupancy": 32, "strain_warrant_weight": 0.3,
    "strain_warrant_active_threshold": 0.5
}
specimen["growth_config"] = {"growth_batch_size": 3, "growth_probability_ceiling": 0.2,
                             "group_strength_floor": 3.0, "min_fresh_entries": 5,
                             "data_energy_msg_scale": 0.1, "growth_node_strength": 3.0}
specimen["phagy_config"] = {"orphan_max_neighbors": 3, "decay_rate": 0.95, "decay_eligibility_max": 30,
                            "drop_table_trim_floor": 0.1, "rule_dormancy_cycles": 100}
specimen["chatter_config"] = {
    "min_population_for_chatter": 1000, "idle_threshold_seconds": 120.0, "idle_jitter_seconds": 30.0,
    "chatter_group_sample_min": 8, "chatter_group_sample_max": 16, "chatter_weak_floor": 2.0,
    "chatter_strong_floor": 6.0, "chatter_grave_floor": 0.5, "chatter_weight_jitter_sigma": 0.1,
    "strong_low_conf_override": 0.3, "morph_cooldown_seconds": 86400.0
}
specimen["immune_config"] = {
    "maturity_threshold": 1000, "automata_population_ratio": "1//3", "coinflip_probability": 0.5,
    "patch_timeout_seconds": 2.0, "patch_timeout_jitter": 0.5, "max_ledger_entries": 10000,
    "max_quarantine_size": 256, "hopfield_familiarity_threshold": 0.85
}
specimen["scanner_config"] = {"max_active_nodes": 100, "confident_threshold": 0.7, "default_candidate_threshold": 0.3}
specimen["action_tone_knobs"] = {"incoherence_tag_threshold": 0.4, "low_signal_threshold": 0.2,
                                 "fallback_damp_threshold": 0.3, "curve_jitter_envelope": 0.1,
                                 "escalation_confidence_floor": 0.5}
specimen["co_activation"] = {"pairs": [
    {"node_a": n1["id"], "node_b": n6["id"], "intensity": 3.5, "observations": 10},
    {"node_a": n3["id"], "node_b": n15["id"], "intensity": 2.8, "observations": 7},
    {"node_a": n5["id"], "node_b": n2["id"], "intensity": 2.2, "observations": 5},
]}
specimen["autogrowth_evidence"] = [
    {"word": "quantum", "intensity": 2.5, "frequency": 4, "last_seen": 1700000040.0},
    {"word": "cellular", "intensity": 1.8, "frequency": 3, "last_seen": 1700000035.0},
    {"word": "respiration", "intensity": 3.0, "frequency": 5, "last_seen": 1700000045.0},
]
specimen["autogrowth_co_occur"] = [
    {"word_a": "quantum", "word_b": "physics", "count": 3},
    {"word_a": "cellular", "word_b": "biology", "count": 2},
    {"word_a": "respiration", "word_b": "cellular", "count": 4},
]
specimen["autolink_evidence"] = [
    {"node_a": n1["id"], "node_b": n4["id"], "intensity": 3.5, "frequency": 5, "same_lobe": False, "last_seen": 1700000040.0},
    {"node_a": n5["id"], "node_b": n40["id"], "intensity": 2.8, "frequency": 4, "same_lobe": False, "last_seen": 1700000035.0},
    {"node_a": n1["id"], "node_b": n48["id"], "intensity": 4.2, "frequency": 6, "same_lobe": True, "last_seen": 1700000045.0},
]
specimen["fanout_config"] = {"enabled": True, "max_shadows": 3, "modes": ["reason", "explain"]}
specimen["hippocampal_pending_ask"] = {"pending_text": ""}
specimen["admin_session"] = {"is_logged_in": False, "login_time": 0.0, "last_activity": 0.0}
specimen["lobe_orch_last"] = {
    "scores": [{"lobe_id": "lobe_physics", "score": 0.85, "rank": 1},
               {"lobe_id": "lobe_math", "score": 0.6, "rank": 2},
               {"lobe_id": "lobe_general", "score": 0.4, "rank": 3}],
    "winner": "lobe_physics", "passthrough": False
}
specimen["chatter_cursor"] = {"cursor": 0}
specimen["answer_mode_config"] = {
    "reason": {"action": "reason^1", "voice": "plain", "frame": ["plain", "exploratory"],
               "prompt": "Grug. I learned this from a question. I reason about what I was taught."},
    "explain": {"action": "explain^1", "voice": "explanatory", "frame": ["exploratory", "plain"],
                "prompt": "Grug. I learned this from a question. I explain what I was taught clearly."},
    "define": {"action": "define^1", "voice": "terse", "frame": ["imperative", "plain"],
               "prompt": "Grug. I learned this from a question. I define what I was taught precisely."},
    "alert": {"action": "alert^1", "voice": "terse", "frame": ["imperative", "terse"],
              "prompt": "Grug. I learned this from a question. I warn about what I was told to watch for."},
    "comfort": {"action": "comfort^1", "voice": "warm", "frame": ["warm", "de-escalating"],
                "prompt": "Grug. I learned this from a question. I acknowledge what I was taught with care."},
    "math": {"action": "reason^1", "voice": "terse", "frame": ["imperative", "plain"],
             "prompt": "Grug. I compute. I give answers. Numbers are my language."},
    "multi": {}, "relate": {}, "time": {}, "proc": {}, "json": {},
}
specimen["phagy_rules_ref"] = []
specimen["time_orientation_config"] = {
    "global_orientation": "now", "global_meta": {},
    "time_node_index": {
        n21["id"]: {"orientation": "now", "sigil": "&now", "pattern": n21["pattern"]},
        n22["id"]: {"orientation": "before", "sigil": "&before", "pattern": n22["pattern"]},
        n23["id"]: {"orientation": "next", "sigil": "&next", "pattern": n23["pattern"]},
        n50["id"]: {"orientation": "now", "sigil": "&now", "pattern": n50["pattern"]},
    }
}
specimen["coherence_config"] = {"weight": 0.15, "drain_rate": 0.05, "boost_rate": 0.1}
specimen["input_ledger"] = {"consumed_hashes": []}
specimen["chatter_residuals"] = {"consumed_hashes": []}
specimen["_meta"] = {"version": "2.11", "saved_at": time_mod.time(), "format": "grugbot420-specimen-v2.11"}

# ── WRITE ──
output_path = "comprehensive_specimen_v10.json"
json_str = json.dumps(specimen, indent=2)
with open(output_path, "w") as f:
    f.write(json_str)

print(f"Specimen written to {output_path}")
print(f"  Nodes: {len(nodes)}")
print(f"  Lobes: {len(lobes)}")
print(f"  Bridges: {len(bridges)}")
print(f"  Chatter groups: {len(chatter_groups)}")
print(f"  Sigils: {len(specimen['sigil_table'])}")
print(f"  Voice-keyed nodes: {sum(1 for n in nodes if 'voice_variants' in n['json_data'])}")
print(f"  File size: {len(json_str)} bytes")

# Verify each voice-keyed node has unique system_prompt
prompts = [n["json_data"].get("system_prompt", "") for n in nodes if "voice_variants" in n["json_data"]]
print(f"  Unique system_prompts among voiced nodes: {len(set(prompts))}/{len(prompts)}")
