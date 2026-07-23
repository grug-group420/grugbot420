#!/usr/bin/env python3
"""
Generate a comprehensive GrugBot420 specimen JSON (v2.11) that exercises
ALL systems: every node type, every sigil class, every lobe, bridges,
AIML nodes, image nodes, antimatch nodes, time nodes, prose nodes,
relational triples with sigils, thesaurus, verb registry, inhibitions,
arousal, eye state, brainstem, trajectory, temporal coherence,
morph cooldowns, immune system, AIML system, sigil table, automaton rules,
phase accumulator, decomposer config, vigilance config, injector stats,
relational jitter, brainstem config, engine config, lobe orchestrator knobs,
vote orchestrator knobs, mitosis config, growth config, phagy config,
chatter config, immune config, scanner config, action tone knobs,
co-activation, input ledger, chatter residuals, autogrowth evidence,
autolink evidence, flashcards, curiosity, fanout config, hippocampal pending,
admin session, lobe orchestrator last state, chatter cursor, answer mode config,
phagy rules ref, time orientation config, coherence config — the kitchen sink.
"""

import json
import time
import hashlib
import os

now = time.time()

specimen = {}

# ═══════════════════════════════════════════════════════════════════════
# 1. NODES — every type: regular, AIML, image, antimatch, time, prose
# ═══════════════════════════════════════════════════════════════════════

nodes = []
node_counter = 500

def next_node_id():
    global node_counter
    node_counter += 1
    return f"node_{node_counter}"

def make_node(pat, signal, action, json_data=None, drop_table=None, throttle=1.0,
              relational_patterns=None, required_relations=None, relation_weights=None,
              strength=5.0, is_image_node=False, is_antimatch_node=False,
              neighbor_ids=None, is_unlinkable=False, max_neighbors=12,
              is_grave=False, grave_reason="", hopfield_key="0",
              original_pattern=None, original_action_packet=None):
    nid = next_node_id()
    if json_data is None:
        json_data = {}
    if drop_table is None:
        drop_table = []
    if neighbor_ids is None:
        neighbor_ids = []
    if required_relations is None:
        required_relations = []
    if relation_weights is None:
        relation_weights = {}
    if original_pattern is None:
        original_pattern = pat
    if original_action_packet is None:
        original_action_packet = action
    # Ensure frame_hints and voice_register always present (coherence requirement)
    if "frame_hints" not in json_data:
        json_data["frame_hints"] = []
    if "voice_register" not in json_data:
        json_data["voice_register"] = "default"
    if "system_prompt" not in json_data:
        json_data["system_prompt"] = ""
    if "noun_anchors" not in json_data:
        json_data["noun_anchors"] = []
    if "companion_node_pref" not in json_data:
        json_data["companion_node_pref"] = ""
    if "aux_triples" not in json_data:
        json_data["aux_triples"] = []

    # GRUG: COHERENCE FIX — every node MUST have a multi-sentence system_prompt
    # (sentence 1 = persona tag, rest = grug voice body) AND noun_anchors.
    # Without these, the engine falls back to raw pattern echo = garbage.
    if not json_data["system_prompt"].strip() or len([s for s in json_data["system_prompt"].split(".") if s.strip()]) < 2:
        # Auto-generate voice based on pattern and frame_hints
        pat_lower = pat.lower()
        if any(kw in pat_lower for kw in ["plus","times","minus","divided","calculate","solve","math","matrix","vector"]):
            persona = "Grug count stones. Numbers are truth."
            body = "Grug know numbers. Each number tells story of how many. Count carefully, speak precisely."
            anchors = json_data["noun_anchors"] or ["number", "calculation", "result"]
            vr = json_data.get("voice_register", "precise")
        elif any(kw in pat_lower for kw in ["fire","rock","water","tree","ocean","mountain","river","cat","dog","bird","ecosystem","sun","sunset","wind","ice","rain","thunder","wave","nature"]):
            persona = "Grug watch sky and earth. Nature speaks if Grug listen."
            body = "Grug see world outside cave. Fire warm, water flow, rock solid. Every thing in nature has way and reason."
            anchors = json_data["noun_anchors"] or ["nature", "element", "earth"]
            vr = json_data.get("voice_register", "thoughtful")
        elif any(kw in pat_lower for kw in ["feel","sad","happy","angry","emotion","fear","joy","calm"]):
            persona = "Grug feel deeply. Feeling is not weakness, it is knowing."
            body = "Grug understand feeling. Sadness pass like cloud, joy come like sunrise. Grug sit with feeling, not run from it."
            anchors = json_data["noun_anchors"] or ["feeling", "emotion", "heart"]
            vr = json_data.get("voice_register", "warm")
        elif any(kw in pat_lower for kw in ["gravity","quantum","evolution","atom","chemistry","physics","biology","hypothesis","energy","force"]):
            persona = "Grug ask why. Curiosity is fire that burn bright."
            body = "Grug seek understanding. World has patterns and rules. Grug test and learn, not guess and hope."
            anchors = json_data["noun_anchors"] or ["science", "discovery", "pattern"]
            vr = json_data.get("voice_register", "analytical")
        elif any(kw in pat_lower for kw in ["meaning","consciousness","truth","existence","self","soul","purpose","ethics"]):
            persona = "Grug think big thoughts. Why is sky? What is self?"
            body = "Grug ponder deep questions. Not all questions have answer, but asking itself is worthy. Grug sit with mystery."
            anchors = json_data["noun_anchors"] or ["meaning", "existence", "thought"]
            vr = json_data.get("voice_register", "reflective")
        else:
            persona = "Grug speak plain. Simple words carry far."
            body = "Grug share what Grug know. Truth in small words. Listen first, then speak."
            anchors = json_data["noun_anchors"] or ["answer", "knowledge", "idea"]
            vr = json_data.get("voice_register", "friendly")

        # Handle special node types
        if is_grave:
            persona = "Grug forget what is dead."
            body = "Old knowledge buried. New knowledge grows from its bones."
        elif is_antimatch_node:
            persona = "Grug know when NOT to speak."
            body = "Silence is wisdom too. This path is wrong, Grug step back."
        elif is_image_node:
            persona = "Grug see with mind eye."
            body = "Shape and color tell truth. Picture worth many words."
        elif "prose" in str(json_data.get("frame_hints", [])):
            persona = "Grug tell story."
            body = "Words paint picture in mind. Let story flow like river."

        json_data["system_prompt"] = f"{persona} {body}"
        if not json_data["noun_anchors"]:
            json_data["noun_anchors"] = anchors
        if json_data.get("voice_register", "default") == "default":
            json_data["voice_register"] = vr

    return {
        "id": nid,
        "pattern": pat,
        "signal": signal,
        "action_packet": action,
        "json_data": json_data,
        "drop_table": drop_table,
        "throttle": throttle,
        "relational_patterns": relational_patterns or [],
        "required_relations": required_relations,
        "relation_weights": relation_weights,
        "strength": strength,
        "is_image_node": is_image_node,
        "is_antimatch_node": is_antimatch_node,
        "neighbor_ids": neighbor_ids,
        "is_unlinkable": is_unlinkable,
        "max_neighbors": max_neighbors,
        "is_grave": is_grave,
        "grave_reason": grave_reason,
        "response_times": [],
        "ledger_last_cleared": now - 3600,
        "hopfield_key": hopfield_key,
        "original_pattern": original_pattern,
        "original_action_packet": original_action_packet
    }

# ─── LOBE 1: "math" — arithmetic + logic ─────────────────────────────
math_nodes = []

# Regular math nodes with &noun sigils
n = make_node("what is &n plus &n", [0.8, 0.2, 0.0], "ponder|explain|calculate|explain|validate|explain",
              json_data={"frame_hints": ["arithmetic"], "voice_register": "precise",
                         "system_prompt": "You are a math helper. Give concise answers.",
                         "noun_anchors": ["number", "sum"], "companion_node_pref": "math"},
              drop_table=["explain"], throttle=0.95,
              relational_patterns=[
                  {"subject": "&noun", "relation": "causes", "object": "result"},
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"}
              ],
              required_relations=["causal"], relation_weights={"causal": 1.5},
              strength=8.0)
math_nodes.append(n)

n = make_node("calculate &n times &n", [0.7, 0.3, 0.0], "ponder|explain|calculate|explain",
              json_data={"frame_hints": ["arithmetic", "multiplication"], "voice_register": "precise",
                         "noun_anchors": ["product", "factor"]},
              drop_table=["explain"], throttle=0.9,
              relational_patterns=[
                  {"subject": "&noun", "relation": "produces", "object": "&noun"},
              ],
              strength=7.0)
math_nodes.append(n)

n = make_node("what is &n minus &n", [0.75, 0.25, 0.0], "ponder|explain|calculate|explain",
              json_data={"frame_hints": ["arithmetic", "subtraction"], "voice_register": "precise"},
              drop_table=["explain"], strength=6.5)
math_nodes.append(n)

n = make_node("solve &n divided by &n", [0.7, 0.3, 0.0], "ponder|explain|calculate|explain|validate|explain",
              json_data={"frame_hints": ["arithmetic", "division"], "voice_register": "precise"},
              strength=6.0)
math_nodes.append(n)

# Prose node — narrative math explanation
n = make_node("explain &word in math", [0.5, 0.3, 0.2], "ponder|explain|elaborate|explain",
              json_data={"frame_hints": ["prose", "math"], "voice_register": "thoughtful",
                         "system_prompt": "Explain the concept in plain language with examples.",
                         "noun_anchors": ["concept", "explanation"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "resembles", "object": "&noun"},
                  {"subject": "&noun", "relation": "&similarity", "object": "&noun"}
              ],
              strength=5.5)
math_nodes.append(n)

# Antimatch node for math — prevents wrong paths
n = make_node("i feel &word about math", [0.1, 0.9, 0.0], "caution|explain",
              json_data={"frame_hints": ["antimatch"], "voice_register": "default"},
              is_antimatch_node=True, strength=3.0)
math_nodes.append(n)

# Node with &temporal relational triple — dynamic sigil in triple
n = make_node("when was &word discovered", [0.4, 0.2, 0.4], "ponder|explain|ponder|explain",
              json_data={"frame_hints": ["temporal", "math"], "voice_register": "reflective",
                         "noun_anchors": ["discovery", "history"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "&noun"},
                  {"subject": "&noun", "relation": "precedes", "object": "&noun"}
              ],
              required_relations=["temporal"], relation_weights={"temporal": 2.0},
              strength=5.0)
math_nodes.append(n)

# Node with &spatial relational triple
n = make_node("where is &word located in math", [0.3, 0.2, 0.5], "ponder|explain|describe|explain",
              json_data={"frame_hints": ["spatial", "math"], "voice_register": "precise"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&spatial", "object": "&noun"},
              ],
              required_relations=["spatial"], relation_weights={"spatial": 1.8},
              strength=4.5)
math_nodes.append(n)

# Node with &causal relational triple
n = make_node("why does &word cause &word", [0.5, 0.2, 0.3], "ponder|explain|explain|explain|validate|explain",
              json_data={"frame_hints": ["causal", "math"], "voice_register": "analytical",
                         "noun_anchors": ["cause", "effect"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"},
                  {"subject": "&noun", "relation": "leads_to", "object": "&noun"}
              ],
              required_relations=["causal"], relation_weights={"causal": 2.0},
              strength=6.0)
math_nodes.append(n)

# Time node — past orientation
n = make_node("what happened before in math", [0.3, 0.1, 0.6], "ponder|explain|ponder|explain",
              json_data={"frame_hints": ["time", "math"], "voice_register": "reflective",
                         "time_node": True, "time_orientation": "past",
                         "time_sigil": "before"},
              relational_patterns=[
                  {"subject": "math", "relation": "&temporal", "object": "history"}
              ],
              strength=4.0)
math_nodes.append(n)

# Time node — future orientation
n = make_node("what comes next in math", [0.3, 0.1, 0.6], "ponder|explain|wonder|explain",
              json_data={"frame_hints": ["time", "math"], "voice_register": "projective",
                         "time_node": True, "time_orientation": "future",
                         "time_sigil": "next"},
              relational_patterns=[
                  {"subject": "math", "relation": "&temporal", "object": "future"}
              ],
              strength=4.0)
math_nodes.append(n)

# Time node — present orientation
n = make_node("what is now in mathematics", [0.3, 0.1, 0.6], "ponder|explain|analyze|explain",
              json_data={"frame_hints": ["time", "math"], "voice_register": "assessing",
                         "time_node": True, "time_orientation": "present",
                         "time_sigil": "now"},
              strength=4.0)
math_nodes.append(n)

# Image node (SDF-based, not text)
n = make_node("SDF:visual_pattern_math_grid", [0.9, 0.1, 0.0], "describe|explain",
              json_data={"frame_hints": ["image", "math"], "voice_register": "visual",
                         "is_image_node": True, "sdf_binary": "0101010101010101"},
              is_image_node=True, strength=3.0)
math_nodes.append(n)

# Grave node (dead, should not fire)
n = make_node("obsolete math formula &n", [0.0, 0.0, 0.0], "caution|explain",
              json_data={"frame_hints": ["grave"], "voice_register": "default"},
              is_grave=True, grave_reason="STRENGTH_ZERO", strength=0.0)
math_nodes.append(n)

# More regular math nodes for breadth
for pattern, action, hints in [
    ("what is the square root of &n", "ponder|explain|calculate|explain", ["arithmetic", "sqrt"]),
    ("is &n greater than &n", "ponder|explain|analyze|explain", ["arithmetic", "comparison"]),
    ("convert &n to binary", "ponder|explain|calculate|explain", ["arithmetic", "conversion"]),
    ("what is the factorial of &n", "ponder|explain|calculate|explain", ["arithmetic", "factorial"]),
    ("what is pi", "ponder|explain|define|explain", ["arithmetic", "constant"]),
    ("define prime number", "ponder|explain|define|explain|validate|explain", ["arithmetic", "definition"]),
    ("list fibonacci numbers", "ponder|explain|describe|explain", ["arithmetic", "sequence"]),
    ("what is the derivative of &word", "ponder|explain|calculate|explain", ["calculus"]),
    ("integrate &word", "ponder|explain|calculate|explain", ["calculus", "integration"]),
    ("what is a matrix", "ponder|explain|define|explain", ["linear_algebra"]),
    ("explain eigenvalues", "ponder|explain|elaborate|explain", ["linear_algebra", "eigen"]),
    ("what is a vector space", "ponder|explain|define|explain", ["linear_algebra", "vector"]),
]:
    n = make_node(pattern, [0.6, 0.3, 0.1], action,
                  json_data={"frame_hints": hints, "voice_register": "precise"},
                  strength=5.0 + hash(pattern) % 30 / 10.0)
    math_nodes.append(n)

# Link up some neighbors
for i in range(min(5, len(math_nodes))):
    for j in range(i+1, min(8, len(math_nodes))):
        if math_nodes[j]["id"] not in math_nodes[i]["neighbor_ids"]:
            math_nodes[i]["neighbor_ids"].append(math_nodes[j]["id"])
        if math_nodes[i]["id"] not in math_nodes[j]["neighbor_ids"]:
            math_nodes[j]["neighbor_ids"].append(math_nodes[i]["id"])

nodes.extend(math_nodes)

# ─── LOBE 2: "nature" — biology, animals, plants ─────────────────────
nature_nodes = []

n = make_node("what is a &word", [0.4, 0.3, 0.3], "ponder|explain|define|explain|validate|explain",
              json_data={"frame_hints": ["nature", "definition"], "voice_register": "thoughtful",
                         "system_prompt": "Define the concept clearly with examples from nature.",
                         "noun_anchors": ["organism", "species"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "is_like", "object": "&noun"},
                  {"subject": "&noun", "relation": "&similarity", "object": "&noun"},
                  {"subject": "&noun", "relation": "&possessive", "object": "&noun"}
              ],
              required_relations=["similarity"], relation_weights={"similarity": 1.5, "possessive": 1.0},
              strength=7.0)
nature_nodes.append(n)

n = make_node("describe a cat", [0.5, 0.3, 0.2], "ponder|explain|describe|explain",
              json_data={"frame_hints": ["nature", "animal", "cat"], "voice_register": "warm",
                         "system_prompt": "Describe the animal vividly with personality.",
                         "noun_anchors": ["cat", "feline", "pet"]},
              relational_patterns=[
                  {"subject": "cat", "relation": "has", "object": "fur"},
                  {"subject": "cat", "relation": "&possessive", "object": "whiskers"},
                  {"subject": "cat", "relation": "&similarity", "object": "lion"}
              ],
              required_relations=["possessive"], relation_weights={"possessive": 2.0},
              strength=8.5)
nature_nodes.append(n)

n = make_node("describe a dog", [0.5, 0.3, 0.2], "ponder|explain|describe|explain",
              json_data={"frame_hints": ["nature", "animal", "dog"], "voice_register": "warm",
                         "noun_anchors": ["dog", "canine", "pet"]},
              relational_patterns=[
                  {"subject": "dog", "relation": "has", "object": "bark"},
                  {"subject": "dog", "relation": "&possessive", "object": "loyalty"},
                  {"subject": "dog", "relation": "&similarity", "object": "wolf"}
              ],
              strength=8.0)
nature_nodes.append(n)

# Prose nature node — storytelling
n = make_node("tell me about &word in nature", [0.3, 0.3, 0.4], "ponder|explain|elaborate|explain|describe|explain",
              json_data={"frame_hints": ["prose", "nature"], "voice_register": "storyteller",
                         "system_prompt": "Tell a vivid story about this aspect of nature."},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "&noun"},
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"}
              ],
              required_relations=["temporal"], relation_weights={"temporal": 1.5},
              strength=6.0)
nature_nodes.append(n)

# Spatial nature node
n = make_node("where do &word live", [0.3, 0.2, 0.5], "ponder|explain|describe|explain",
              json_data={"frame_hints": ["spatial", "nature"], "voice_register": "descriptive"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&spatial", "object": "habitat"},
                  {"subject": "&noun", "relation": "inhabits", "object": "&noun"}
              ],
              required_relations=["spatial"], relation_weights={"spatial": 2.0},
              strength=5.5)
nature_nodes.append(n)

# Causal nature node
n = make_node("why do &word migrate", [0.4, 0.2, 0.4], "ponder|explain|explain|explain",
              json_data={"frame_hints": ["causal", "nature"], "voice_register": "analytical"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "migration"},
                  {"subject": "season", "relation": "triggers", "object": "&noun"}
              ],
              required_relations=["causal"], relation_weights={"causal": 2.0},
              strength=5.0)
nature_nodes.append(n)

# Temporal nature node
n = make_node("when do &word bloom", [0.3, 0.1, 0.6], "ponder|explain|ponder|explain",
              json_data={"frame_hints": ["temporal", "nature"], "voice_register": "reflective",
                         "time_node": True, "time_orientation": "present", "time_sigil": "now"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "season"},
              ],
              required_relations=["temporal"],
              strength=5.0)
nature_nodes.append(n)

# Antimatch nature node — prevents emotional tangent on factual queries
n = make_node("i hate &word in nature", [0.1, 0.9, 0.0], "caution|explain",
              json_data={"frame_hints": ["antimatch"], "voice_register": "default"},
              is_antimatch_node=True, strength=3.0)
nature_nodes.append(n)

# Image node for nature
n = make_node("SDF:visual_pattern_nature_tree", [0.1, 0.1, 0.8], "describe|explain",
              json_data={"frame_hints": ["image", "nature"], "voice_register": "visual",
                         "is_image_node": True, "sdf_binary": "1010101010101010"},
              is_image_node=True, strength=3.5)
nature_nodes.append(n)

# More nature nodes
for pattern, action, hints in [
    ("what is photosynthesis", "ponder|explain|define|explain|explain|explain", ["nature", "plants", "photosynthesis"]),
    ("how do trees grow", "ponder|explain|explain|explain", ["nature", "plants", "growth"]),
    ("describe the ocean ecosystem", "ponder|explain|describe|explain|elaborate|explain", ["nature", "ocean", "ecosystem"]),
    ("what is evolution", "ponder|explain|define|explain", ["nature", "biology", "evolution"]),
    ("how do birds fly", "ponder|explain|explain|explain", ["nature", "animals", "flight"]),
    ("what is a forest", "ponder|explain|define|explain|describe|explain", ["nature", "plants", "forest"]),
    ("explain symbiosis", "ponder|explain|define|explain|elaborate|explain", ["nature", "biology", "symbiosis"]),
    ("what is biodiversity", "ponder|explain|define|explain", ["nature", "ecology"]),
    ("describe a rainforest", "ponder|explain|describe|explain", ["nature", "biome"]),
    ("what is an ecosystem", "ponder|explain|define|explain|explain|explain", ["nature", "ecology"]),
    ("how does pollination work", "ponder|explain|explain|explain", ["nature", "plants", "pollination"]),
    ("what are predators", "ponder|explain|define|explain", ["nature", "animals", "predator"]),
]:
    n = make_node(pattern, [0.4, 0.3, 0.3], action,
                  json_data={"frame_hints": hints, "voice_register": "thoughtful"},
                  strength=5.0 + hash(pattern) % 25 / 10.0)
    nature_nodes.append(n)

# Link neighbors
for i in range(min(4, len(nature_nodes))):
    for j in range(i+1, min(7, len(nature_nodes))):
        if nature_nodes[j]["id"] not in nature_nodes[i]["neighbor_ids"]:
            nature_nodes[i]["neighbor_ids"].append(nature_nodes[j]["id"])
        if nature_nodes[i]["id"] not in nature_nodes[j]["neighbor_ids"]:
            nature_nodes[j]["neighbor_ids"].append(nature_nodes[i]["id"])

nodes.extend(nature_nodes)

# ─── LOBE 3: "emotions" — feelings, empathy, self-reflection ─────────
emotion_nodes = []

n = make_node("i feel &word today", [0.2, 0.3, 0.5], "ponder|explain|comfort|explain|validate|explain",
              json_data={"frame_hints": ["emotion", "empathy"], "voice_register": "warm",
                         "system_prompt": "You are empathetic. Acknowledge the feeling and offer understanding.",
                         "noun_anchors": ["feeling", "emotion"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"},
                  {"subject": "&noun", "relation": "&temporal", "object": "today"},
              ],
              required_relations=["causal"], relation_weights={"causal": 1.5},
              strength=9.0)
emotion_nodes.append(n)

n = make_node("i am &word", [0.2, 0.3, 0.5], "ponder|explain|comfort|explain",
              json_data={"frame_hints": ["emotion", "state"], "voice_register": "warm",
                         "noun_anchors": ["state", "mood"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&possessive", "object": "mood"},
              ],
              strength=8.5)
emotion_nodes.append(n)

n = make_node("i feel sad", [0.1, 0.3, 0.6], "ponder|explain|comfort|explain|comfort|explain",
              json_data={"frame_hints": ["emotion", "sadness", "empathy"], "voice_register": "gentle",
                         "system_prompt": "Be gentle and supportive. Acknowledge the sadness without dismissing it."},
              relational_patterns=[
                  {"subject": "sadness", "relation": "&causal", "object": "change"},
                  {"subject": "sadness", "relation": "&temporal", "object": "passing"},
              ],
              required_relations=["causal"],
              strength=9.0)
emotion_nodes.append(n)

n = make_node("i feel happy", [0.1, 0.2, 0.7], "ponder|explain|validate|explain|validate|explain",
              json_data={"frame_hints": ["emotion", "happiness"], "voice_register": "joyful"},
              relational_patterns=[
                  {"subject": "happiness", "relation": "&causal", "object": "connection"},
              ],
              strength=8.0)
emotion_nodes.append(n)

# Prose emotion node — reflective
n = make_node("tell me about feeling &word", [0.2, 0.2, 0.6], "ponder|explain|ponder|explain|describe|explain",
              json_data={"frame_hints": ["prose", "emotion"], "voice_register": "reflective",
                         "system_prompt": "Reflect deeply on this feeling. Use metaphor and imagery."},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&similarity", "object": "weather"},
                  {"subject": "&noun", "relation": "&temporal", "object": "season"},
              ],
              required_relations=["similarity"], relation_weights={"similarity": 1.8},
              strength=6.0)
emotion_nodes.append(n)

# Time node for emotions — past reflection
n = make_node("i felt &word before", [0.2, 0.2, 0.6], "ponder|explain|ponder|explain",
              json_data={"frame_hints": ["emotion", "time"], "voice_register": "reflective",
                         "time_node": True, "time_orientation": "past", "time_sigil": "before"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "past"},
              ],
              strength=5.5)
emotion_nodes.append(n)

# Time node for emotions — future projection
n = make_node("will i feel &word later", [0.2, 0.2, 0.6], "ponder|explain|wonder|explain",
              json_data={"frame_hints": ["emotion", "time"], "voice_register": "projective",
                         "time_node": True, "time_orientation": "future", "time_sigil": "next"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "future"},
              ],
              strength=5.0)
emotion_nodes.append(n)

# Antimatch — prevents analytical response to emotional input
n = make_node("calculate my feelings", [0.1, 0.9, 0.0], "caution|explain",
              json_data={"frame_hints": ["antimatch"], "voice_register": "default"},
              is_antimatch_node=True, strength=4.0)
emotion_nodes.append(n)

# Image node for emotions
n = make_node("SDF:visual_pattern_emotion_wave", [0.2, 0.2, 0.6], "describe|explain",
              json_data={"frame_hints": ["image", "emotion"], "voice_register": "visual",
                         "is_image_node": True, "sdf_binary": "1100110011001100"},
              is_image_node=True, strength=3.0)
emotion_nodes.append(n)

# More emotion nodes
for pattern, action, hints in [
    ("i am anxious", "ponder|explain|comfort|explain|comfort|explain", ["emotion", "anxiety"]),
    ("i feel lonely", "ponder|explain|comfort|explain|support|explain", ["emotion", "loneliness"]),
    ("i am angry", "ponder|explain|comfort|explain|validate|explain", ["emotion", "anger"]),
    ("i feel confused", "ponder|explain|comfort|explain|clarify|explain", ["emotion", "confusion"]),
    ("i feel grateful", "ponder|explain|validate|explain|validate|explain", ["emotion", "gratitude"]),
    ("i am worried about &word", "ponder|explain|comfort|explain|reassure|explain", ["emotion", "worry"]),
    ("i feel overwhelmed", "ponder|explain|comfort|explain|clarify|explain", ["emotion", "overwhelm"]),
    ("describe joy", "ponder|explain|define|explain|elaborate|explain", ["emotion", "joy"]),
    ("what is grief", "ponder|explain|define|explain|comfort|explain", ["emotion", "grief"]),
    ("how to handle stress", "ponder|explain|reason|explain|validate|explain", ["emotion", "stress"]),
]:
    n = make_node(pattern, [0.2, 0.3, 0.5], action,
                  json_data={"frame_hints": hints, "voice_register": "warm"},
                  strength=5.0 + hash(pattern) % 30 / 10.0)
    emotion_nodes.append(n)

# Link neighbors
for i in range(min(4, len(emotion_nodes))):
    for j in range(i+1, min(6, len(emotion_nodes))):
        if emotion_nodes[j]["id"] not in emotion_nodes[i]["neighbor_ids"]:
            emotion_nodes[i]["neighbor_ids"].append(emotion_nodes[j]["id"])
        if emotion_nodes[i]["id"] not in emotion_nodes[j]["neighbor_ids"]:
            emotion_nodes[j]["neighbor_ids"].append(emotion_nodes[i]["id"])

nodes.extend(emotion_nodes)

# ─── LOBE 4: "science" — physics, chemistry, general science ────────
science_nodes = []

n = make_node("what is &word in science", [0.5, 0.3, 0.2], "ponder|explain|define|explain|explain|explain",
              json_data={"frame_hints": ["science", "definition"], "voice_register": "academic",
                         "system_prompt": "Explain the scientific concept precisely with examples.",
                         "noun_anchors": ["concept", "phenomenon"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"},
                  {"subject": "&noun", "relation": "&possessive", "object": "properties"},
              ],
              required_relations=["causal"], relation_weights={"causal": 1.5},
              strength=7.5)
science_nodes.append(n)

# Spatial science node
n = make_node("where is &word in the solar system", [0.3, 0.2, 0.5], "ponder|explain|describe|explain|explain|explain",
              json_data={"frame_hints": ["spatial", "science", "astronomy"], "voice_register": "academic"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&spatial", "object": "orbit"},
                  {"subject": "&noun", "relation": "around", "object": "sun"},
              ],
              required_relations=["spatial"], relation_weights={"spatial": 2.0},
              strength=6.0)
science_nodes.append(n)

# Causal science node
n = make_node("why does &word happen", [0.5, 0.2, 0.3], "ponder|explain|explain|explain|validate|explain",
              json_data={"frame_hints": ["causal", "science"], "voice_register": "analytical",
                         "noun_anchors": ["cause", "effect"]},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "&noun"},
                  {"subject": "&noun", "relation": "produces", "object": "&noun"},
              ],
              required_relations=["causal"], relation_weights={"causal": 2.0},
              strength=6.5)
science_nodes.append(n)

# Prose science node
n = make_node("explain &word like im five", [0.3, 0.3, 0.4], "ponder|explain|clarify|explain|describe|explain",
              json_data={"frame_hints": ["prose", "science", "simplified"], "voice_register": "friendly",
                         "system_prompt": "Explain in very simple terms, like talking to a curious child."},
              strength=5.5)
science_nodes.append(n)

# Time node — science
n = make_node("when was &word discovered", [0.3, 0.1, 0.6], "ponder|explain|ponder|explain",
              json_data={"frame_hints": ["time", "science"], "voice_register": "reflective",
                         "time_node": True, "time_orientation": "past", "time_sigil": "before"},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&temporal", "object": "discovery"},
              ],
              strength=5.0)
science_nodes.append(n)

# Antimatch science node
n = make_node("science is boring", [0.1, 0.9, 0.0], "caution|explain",
              json_data={"frame_hints": ["antimatch"], "voice_register": "default"},
              is_antimatch_node=True, strength=3.0)
science_nodes.append(n)

# More science nodes
for pattern, action, hints in [
    ("what is gravity", "ponder|explain|define|explain|explain|explain", ["science", "physics", "gravity"]),
    ("explain quantum mechanics", "ponder|explain|define|explain|clarify|explain", ["science", "physics", "quantum"]),
    ("what is the speed of light", "ponder|explain|define|explain", ["science", "physics", "constant"]),
    ("how does electricity work", "ponder|explain|explain|explain", ["science", "physics", "electricity"]),
    ("what is dna", "ponder|explain|define|explain|explain|explain", ["science", "biology", "genetics"]),
    ("describe chemical reactions", "ponder|explain|explain|explain", ["science", "chemistry"]),
    ("what is thermodynamics", "ponder|explain|define|explain", ["science", "physics", "thermo"]),
    ("how do magnets work", "ponder|explain|explain|explain", ["science", "physics", "magnetism"]),
    ("what is the periodic table", "ponder|explain|define|explain|describe|explain", ["science", "chemistry"]),
    ("explain relativity", "ponder|explain|define|explain|clarify|explain", ["science", "physics", "relativity"]),
]:
    n = make_node(pattern, [0.5, 0.3, 0.2], action,
                  json_data={"frame_hints": hints, "voice_register": "academic"},
                  strength=5.0 + hash(pattern) % 25 / 10.0)
    science_nodes.append(n)

# Link neighbors
for i in range(min(4, len(science_nodes))):
    for j in range(i+1, min(7, len(science_nodes))):
        if science_nodes[j]["id"] not in science_nodes[i]["neighbor_ids"]:
            science_nodes[i]["neighbor_ids"].append(science_nodes[j]["id"])
        if science_nodes[i]["id"] not in science_nodes[j]["neighbor_ids"]:
            science_nodes[j]["neighbor_ids"].append(science_nodes[i]["id"])

nodes.extend(science_nodes)

# ─── LOBE 5: "philosophy" — deep questions, meaning ─────────────────
phil_nodes = []

n = make_node("what is the meaning of &word", [0.2, 0.2, 0.6], "ponder|explain|ponder|explain|elaborate|explain",
              json_data={"frame_hints": ["philosophy", "meaning"], "voice_register": "contemplative",
                         "system_prompt": "Reflect deeply. Explore multiple perspectives."},
              relational_patterns=[
                  {"subject": "&noun", "relation": "&causal", "object": "purpose"},
                  {"subject": "&noun", "relation": "&similarity", "object": "&noun"},
              ],
              required_relations=["causal"], relation_weights={"causal": 1.5},
              strength=6.0)
phil_nodes.append(n)

n = make_node("why do we exist", [0.1, 0.2, 0.7], "ponder|explain|ponder|explain|wonder|explain",
              json_data={"frame_hints": ["philosophy", "existence"], "voice_register": "contemplative"},
              relational_patterns=[
                  {"subject": "existence", "relation": "&causal", "object": "consciousness"},
              ],
              strength=7.0)
phil_nodes.append(n)

n = make_node("what is consciousness", [0.2, 0.2, 0.6], "ponder|explain|define|explain|ponder|explain",
              json_data={"frame_hints": ["philosophy", "consciousness"], "voice_register": "deep"},
              relational_patterns=[
                  {"subject": "consciousness", "relation": "&similarity", "object": "awareness"},
                  {"subject": "consciousness", "relation": "&possessive", "object": "qualia"},
              ],
              strength=6.5)
phil_nodes.append(n)

# Prose philosophy
n = make_node("contemplate &word", [0.1, 0.2, 0.7], "ponder|explain|ponder|explain|describe|explain",
              json_data={"frame_hints": ["prose", "philosophy"], "voice_register": "poetic",
                         "system_prompt": "Write a contemplative meditation on this topic."},
              strength=5.0)
phil_nodes.append(n)

# Time node — philosophy
n = make_node("what is time really", [0.2, 0.1, 0.7], "ponder|explain|ponder|explain|analyze|explain",
              json_data={"frame_hints": ["time", "philosophy"], "voice_register": "contemplative",
                         "time_node": True, "time_orientation": "present", "time_sigil": "now"},
              strength=5.0)
phil_nodes.append(n)

# More philosophy nodes
for pattern, action, hints in [
    ("what is free will", "ponder|explain|define|explain|ponder|explain", ["philosophy", "free_will"]),
    ("what is truth", "ponder|explain|define|explain", ["philosophy", "epistemology"]),
    ("what is justice", "ponder|explain|define|explain|ponder|explain", ["philosophy", "ethics"]),
    ("what is beauty", "ponder|explain|ponder|explain|elaborate|explain", ["philosophy", "aesthetics"]),
    ("what is knowledge", "ponder|explain|define|explain|explain|explain", ["philosophy", "epistemology"]),
    ("what is morality", "ponder|explain|define|explain|ponder|explain", ["philosophy", "ethics"]),
    ("what is the self", "ponder|explain|ponder|explain|elaborate|explain", ["philosophy", "identity"]),
    ("what is reality", "ponder|explain|define|explain|ponder|explain", ["philosophy", "metaphysics"]),
]:
    n = make_node(pattern, [0.2, 0.2, 0.6], action,
                  json_data={"frame_hints": hints, "voice_register": "contemplative"},
                  strength=5.0 + hash(pattern) % 20 / 10.0)
    phil_nodes.append(n)

# Link neighbors
for i in range(min(3, len(phil_nodes))):
    for j in range(i+1, min(5, len(phil_nodes))):
        if phil_nodes[j]["id"] not in phil_nodes[i]["neighbor_ids"]:
            phil_nodes[i]["neighbor_ids"].append(phil_nodes[j]["id"])
        if phil_nodes[i]["id"] not in phil_nodes[j]["neighbor_ids"]:
            phil_nodes[j]["neighbor_ids"].append(phil_nodes[i]["id"])

nodes.extend(phil_nodes)

specimen["nodes"] = nodes

# ═══════════════════════════════════════════════════════════════════════
# 2. HOPFIELD CACHE
# ═══════════════════════════════════════════════════════════════════════
hopfield_entries = []
for i in range(10):
    h = hashlib.md5(f"pattern_{i}".encode()).hexdigest()
    h_uint = str(int(h[:16], 16))
    hopfield_entries.append({
        "hash": h_uint,
        "node_ids": [f"node_{501+i}", f"node_{510+i}"],
        "hit_count": i * 3
    })
specimen["hopfield_cache"] = hopfield_entries

# ═══════════════════════════════════════════════════════════════════════
# 3. RULES (AIML_DROP_TABLE)
# ═══════════════════════════════════════════════════════════════════════
# GRUG: Shaping rules use [action_tag] prefix format. The tag must match
# a locked-in action (from sure_votes) to fire. Rules without a tag always
# fire. Only use VALID action names: acknowledge, alert, analyze, ask,
# calculate, caution, clarify, comfort, define, describe, elaborate,
# explain, fight, flag, flee, greet, hide, inquire, laugh, notify,
# ponder, question, reason, reassure, smile, support, validate, warn,
# welcome, wonder.
specimen["rules"] = [
    {"text": "[ponder] Stay inside the {LOBE_CONTEXT} frame. Think deeply before speaking.", "prob": 0.8},
    {"text": "[calculate] Give the exact numerical answer first. Show work if asked.", "prob": 0.7},
    {"text": "[define] Provide a clear, concise definition. One sentence then examples.", "prob": 0.75},
    {"text": "[explain] Break it down step by step. Use simple words.", "prob": 0.65},
    {"text": "[describe] Paint a picture with words. Focus on what the senses perceive.", "prob": 0.7},
    {"text": "[comfort] Acknowledge the feeling. Do not try to fix, just be present.", "prob": 0.85},
    {"text": "[comfort] Use warm and gentle language. Validate before suggesting.", "prob": 0.6},
    {"text": "[validate] Confirm what was heard. Mirror back before adding new content.", "prob": 0.5},
    {"text": "[ponder] Let silence have its place. Not every gap needs filling.", "prob": 0.55},
    {"text": "[describe] Keep it vivid and concrete. Avoid abstraction when possible.", "prob": 0.45},
    {"text": "[elaborate] Expand on the core idea with one supporting detail.", "prob": 0.5},
    {"text": "[describe] Locate it in space. Where does it sit in the world?", "prob": 0.6},
    {"text": "[clarify] Simplify without losing truth. One idea at a time.", "prob": 0.55},
    {"text": "[validate] Mark the moment of understanding.", "prob": 0.65},
    {"text": "[wonder] Project forward. What might come next?", "prob": 0.5},
    {"text": "[analyze] Assess the evidence. What holds up and what does not?", "prob": 0.55},
    {"text": "[caution] Hold back. Not everything needs an immediate response.", "prob": 0.1},
    {"text": "[describe] Render the scene. What does it look like from here?", "prob": 0.3},
    {"text": "[reason] Advise with caution. Offer options, not commands.", "prob": 0.6},
    {"text": "[reassure] Reassure with honesty. Hope grounded in truth.", "prob": 0.7},
]

# ═══════════════════════════════════════════════════════════════════════
# 4. MESSAGE HISTORY
# ═══════════════════════════════════════════════════════════════════════
messages = [
    {"id": 1, "role": "system", "text": "GrugBot420 initialized. All systems online.", "pinned": True, "intensity": 1.0},
    {"id": 2, "role": "assistant", "text": "Hello! I am Grug. I think about things.", "pinned": False, "intensity": 0.5},
    {"id": 3, "role": "user", "text": "what is 2+2", "pinned": False, "intensity": 0.8},
    {"id": 4, "role": "assistant", "text": "2+2 equals 4. Basic addition.", "pinned": False, "intensity": 0.6},
    {"id": 5, "role": "user", "text": "what is a cat", "pinned": False, "intensity": 0.7},
    {"id": 6, "role": "assistant", "text": "A cat is a small furry feline, a beloved companion animal.", "pinned": False, "intensity": 0.6},
    {"id": 7, "role": "user", "text": "I feel sad today", "pinned": False, "intensity": 0.9},
    {"id": 8, "role": "assistant", "text": "I hear you. Sadness is a natural feeling, and it's okay to sit with it for a while.", "pinned": False, "intensity": 0.8},
]
specimen["message_history"] = messages

# ═══════════════════════════════════════════════════════════════════════
# 5. LOBES
# ═══════════════════════════════════════════════════════════════════════
math_node_ids = [n["id"] for n in math_nodes]
nature_node_ids = [n["id"] for n in nature_nodes]
emotion_node_ids = [n["id"] for n in emotion_nodes]
science_node_ids = [n["id"] for n in science_nodes]
phil_node_ids = [n["id"] for n in phil_nodes]

lobes = [
    {"id": "lobe_math", "subject": "mathematics", "node_ids": sorted(math_node_ids),
     "connected_lobe_ids": ["lobe_science", "lobe_philosophy"], "node_cap": 50,
     "fire_count": 42, "inhibit_count": 3, "created_at": now - 86400,
     "subject_whitelist": ["math", "arithmetic", "calculus", "algebra", "number", "calculate"],
     "name": "Math Lodge"},
    {"id": "lobe_nature", "subject": "nature", "node_ids": sorted(nature_node_ids),
     "connected_lobe_ids": ["lobe_science", "lobe_emotions"], "node_cap": 50,
     "fire_count": 38, "inhibit_count": 2, "created_at": now - 86400,
     "subject_whitelist": ["nature", "animal", "plant", "ecology", "biology", "species"],
     "name": "Nature Den"},
    {"id": "lobe_emotions", "subject": "emotions", "node_ids": sorted(emotion_node_ids),
     "connected_lobe_ids": ["lobe_nature", "lobe_philosophy"], "node_cap": 40,
     "fire_count": 55, "inhibit_count": 5, "created_at": now - 86400,
     "subject_whitelist": ["feel", "emotion", "sad", "happy", "anxious", "mood"],
     "name": "Heart Cave"},
    {"id": "lobe_science", "subject": "science", "node_ids": sorted(science_node_ids),
     "connected_lobe_ids": ["lobe_math", "lobe_nature", "lobe_philosophy"], "node_cap": 50,
     "fire_count": 30, "inhibit_count": 1, "created_at": now - 86400,
     "subject_whitelist": ["science", "physics", "chemistry", "astronomy", "experiment"],
     "name": "Science Lab"},
    {"id": "lobe_philosophy", "subject": "philosophy", "node_ids": sorted(phil_node_ids),
     "connected_lobe_ids": ["lobe_emotions", "lobe_science", "lobe_math"], "node_cap": 30,
     "fire_count": 15, "inhibit_count": 0, "created_at": now - 86400,
     "subject_whitelist": ["philosophy", "meaning", "existence", "truth", "consciousness"],
     "name": "Deep Chamber"},
]
specimen["lobes"] = lobes

# ═══════════════════════════════════════════════════════════════════════
# 6. NODE_TO_LOBE_IDX
# ═══════════════════════════════════════════════════════════════════════
node_to_lobe = {}
for n in math_nodes: node_to_lobe[n["id"]] = "lobe_math"
for n in nature_nodes: node_to_lobe[n["id"]] = "lobe_nature"
for n in emotion_nodes: node_to_lobe[n["id"]] = "lobe_emotions"
for n in science_nodes: node_to_lobe[n["id"]] = "lobe_science"
for n in phil_nodes: node_to_lobe[n["id"]] = "lobe_philosophy"
specimen["node_to_lobe_idx"] = node_to_lobe

# ═══════════════════════════════════════════════════════════════════════
# 7. LOBE TABLES (with flashcard data for arithmetic)
# ═══════════════════════════════════════════════════════════════════════

def make_lobe_table(lobe_id, flashcards=None):
    """Create a lobe table with all chunk types populated."""
    chunks = {
        "json": {},  # pattern -> json_data lookups
        "drop": {},  # pattern -> drop_table
        "hopfield": {},  # hopfield_key -> node_id
        "meta": {},  # node_id -> metadata
    }
    # Add NodeRef entries for some nodes
    for i in range(3):
        nid = f"node_{501 + hash(lobe_id) % 100 + i}"
        chunks["json"][f"ref_{i}"] = {
            "_type": "NodeRef",
            "node_id": nid,
            "lobe_id": lobe_id,
            "is_active": True,
            "inserted_at": now - 3600
        }
    
    # Flashcards (for math lobe — arithmetic lookup tables)
    fc = {}
    if flashcards:
        fc = flashcards
    
    return {
        "lobe_id": lobe_id,
        "chunks": chunks,
        "created_at": now - 86400,
        "flashcards": fc  # embedded in chunks during load but we put it separate for clarity
    }

# Build math flashcards — arithmetic lookup tables
math_flashcards = {}
for a in range(0, 13):
    for b in range(0, 13):
        key_add = f"{a}+{b}"
        key_mul = f"{a}*{b}"
        math_flashcards[key_add] = {"question": f"{a}+{b}", "answer": str(a + b), "type": "addition"}
        math_flashcards[key_mul] = {"question": f"{a}*{b}", "answer": str(a * b), "type": "multiplication"}
for a in range(0, 21):
    for b in range(0, 11):
        if b <= a:
            key_sub = f"{a}-{b}"
            math_flashcards[key_sub] = {"question": f"{a}-{b}", "answer": str(a - b), "type": "subtraction"}
        if b > 0 and a % b == 0:
            key_div = f"{a}/{b}"
            math_flashcards[key_div] = {"question": f"{a}/{b}", "answer": str(a // b), "type": "division"}

lobe_tables = [
    make_lobe_table("lobe_math", math_flashcards),
    make_lobe_table("lobe_nature"),
    make_lobe_table("lobe_emotions"),
    make_lobe_table("lobe_science"),
    make_lobe_table("lobe_philosophy"),
]
specimen["lobe_tables"] = lobe_tables

# ═══════════════════════════════════════════════════════════════════════
# 8. VERB REGISTRY
# ═══════════════════════════════════════════════════════════════════════
specimen["verb_registry"] = {
    "classes": {
        "causal": sorted(["causes", "produces", "creates", "generates", "leads_to",
                          "results_in", "triggers", "enables", "brings_about",
                          "caused", "produced", "created", "generated", "led_to"]),
        "spatial": sorted(["above", "below", "inside", "outside", "near", "beside",
                           "around", "between", "through", "across", "behind",
                           "in_front_of", "beneath", "upon", "within"]),
        "temporal": sorted(["before", "after", "during", "since", "until", "now",
                            "then", "precedes", "follows", "while", "when",
                            "previously", "subsequently", "simultaneously"]),
        "possessive": sorted(["has", "owns", "contains", "holds", "carries", "possesses",
                              "includes", "comprises", "had", "owned"]),
        "similarity": sorted(["resembles", "mirrors", "echoes", "parallels", "mimics",
                              "approximates", "is_like", "resembled", "mirrored"]),
        "emotional": sorted(["feels", "experiences", "senses", "perceives",
                             "empathizes", "resonates", "affects"]),
        "cognitive": sorted(["thinks", "knows", "understands", "believes", "remembers",
                             "imagines", "considers", "reasons", "infers"]),
    },
    "synonyms": {
        "produces": "causes",
        "creates": "causes",
        "generates": "causes",
        "holds": "contains",
        "includes": "contains",
        "comprises": "contains",
        "mirrors": "resembles",
        "echoes": "resembles",
        "parallels": "resembles",
        "previously": "before",
        "earlier": "before",
        "prior": "before",
        "subsequently": "after",
        "later": "after",
        "afterward": "after",
        "beside": "near",
        "close": "near",
        "adjacent": "near",
        "experiences": "feels",
        "senses": "feels",
        "perceives": "feels",
        "considers": "thinks",
        "reasons": "thinks",
        "reflects": "thinks",
    }
}

# ═══════════════════════════════════════════════════════════════════════
# 9. THESAURUS SEEDS
# ═══════════════════════════════════════════════════════════════════════
specimen["thesaurus_seeds"] = {
    "happy": sorted(["joyful", "glad", "cheerful", "delighted", "content", "pleased", "elated"]),
    "sad": sorted(["unhappy", "sorrowful", "melancholy", "gloomy", "dejected", "downcast"]),
    "angry": sorted(["furious", "enraged", "irate", "annoyed", "livid", "incensed"]),
    "scared": sorted(["afraid", "frightened", "terrified", "anxious", "fearful", "alarmed"]),
    "big": sorted(["large", "huge", "enormous", "vast", "immense", "gigantic", "massive"]),
    "small": sorted(["tiny", "little", "minute", "miniature", "petite", "diminutive"]),
    "fast": sorted(["quick", "rapid", "swift", "speedy", "hasty", "brisk"]),
    "slow": sorted(["sluggish", "leisurely", "gradual", "unhurried", "deliberate"]),
    "smart": sorted(["intelligent", "clever", "brilliant", "wise", "astute", "sharp"]),
    "beautiful": sorted(["gorgeous", "stunning", "lovely", "attractive", "elegant", "radiant"]),
    "good": sorted(["excellent", "great", "fine", "wonderful", "superb", "outstanding"]),
    "bad": sorted(["terrible", "awful", "dreadful", "poor", "horrible", "atrocious"]),
    "old": sorted(["ancient", "aged", "elderly", "vintage", "antique", "mature"]),
    "new": sorted(["fresh", "novel", "recent", "modern", "contemporary", "original"]),
    "strong": sorted(["powerful", "mighty", "robust", "sturdy", "resilient", "tough"]),
    "weak": sorted(["feeble", "frail", "fragile", "delicate", "flimsy", "vulnerable"]),
    "hot": sorted(["warm", "scorching", "blazing", "fiery", "sweltering", "heated"]),
    "cold": sorted(["chilly", "freezing", "frigid", "icy", "frosty", "cool"]),
    "cat": sorted(["feline", "kitten", "tomcat", "pussycat", "moggy"]),
    "dog": sorted(["canine", "puppy", "hound", "mutt", "pooch"]),
    "tree": sorted(["oak", "pine", "elm", "birch", "maple", "willow", "cedar"]),
    "ocean": sorted(["sea", "marine", "depths", "waters", "briny", "deep"]),
    "math": sorted(["mathematics", "arithmetic", "calculus", "algebra", "geometry"]),
    "science": sorted(["physics", "chemistry", "biology", "astronomy", "geology"]),
    "feeling": sorted(["emotion", "sensation", "sentiment", "mood", "affect"]),
    "think": sorted(["ponder", "consider", "reflect", "contemplate", "muse", "deliberate"]),
    "know": sorted(["understand", "comprehend", "grasp", "perceive", "recognize"]),
    "see": sorted(["observe", "perceive", "notice", "witness", "behold"]),
    "walk": sorted(["stroll", "stride", "amble", "saunter", "trudge"]),
    "talk": sorted(["speak", "converse", "chat", "discuss", "communicate"]),
    "eat": sorted(["consume", "devour", "ingest", "munch", "dine", "feast"]),
    "make": sorted(["create", "build", "construct", "craft", "forge", "produce"]),
    "find": sorted(["discover", "locate", "uncover", "detect", "identify"]),
    "give": sorted(["bestow", "grant", "present", "donate", "contribute"]),
    "love": sorted(["adore", "cherish", "affection", "devotion", "fondness"]),
    "hate": sorted(["detest", "loathe", "despise", "abhor", "revile"]),
}

# ═══════════════════════════════════════════════════════════════════════
# 10. INHIBITIONS (NegativeThesaurus)
# ═══════════════════════════════════════════════════════════════════════
specimen["inhibitions"] = [
    {"word": "stupid", "reason": "negative self-label inhibitor", "added_at": now - 7200},
    {"word": "worthless", "reason": "negative self-label inhibitor", "added_at": now - 7200},
    {"word": "hopeless", "reason": "despair inhibitor — redirect to empathy", "added_at": now - 3600},
    {"word": "impossible", "reason": "defeatist inhibitor — redirect to possibility", "added_at": now - 3600},
    {"word": "boring", "reason": "disengagement inhibitor", "added_at": now - 1800},
    {"word": "harmful", "reason": "safety inhibitor — requires validation", "added_at": now - 1800},
    {"word": "kill", "reason": "safety critical inhibitor", "added_at": now - 900},
    {"word": "die", "reason": "safety critical inhibitor", "added_at": now - 900},
]

# ═══════════════════════════════════════════════════════════════════════
# 11. AROUSAL STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["arousal"] = {
    "level": 0.45,
    "decay_rate": 0.05,
    "baseline": 0.3
}

# ═══════════════════════════════════════════════════════════════════════
# 11.5 EYE STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["eye_state"] = {
    "attention_enabled": True,
    "blur_enabled": True,
    "last_centroid_x": 0.5,
    "last_centroid_y": 0.5,
    "last_arousal": 0.45
}

# ═══════════════════════════════════════════════════════════════════════
# 12. ID COUNTERS
# ═══════════════════════════════════════════════════════════════════════
specimen["id_counters"] = {
    "node_id_counter": node_counter + 1,
    "msg_id_counter": 20
}

# ═══════════════════════════════════════════════════════════════════════
# 12.5 LAST VOTER IDS
# ═══════════════════════════════════════════════════════════════════════
specimen["last_voters"] = [math_nodes[0]["id"], nature_nodes[0]["id"]]

# ═══════════════════════════════════════════════════════════════════════
# 13. BRAINSTEM STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["brainstem"] = {
    "dispatch_count": 127,
    "last_winner_id": emotion_nodes[0]["id"],
    "last_dispatch_t": now - 60,
    "propagation_history": [
        {"source_lobe_id": "lobe_math", "target_lobe_id": "lobe_science", "confidence": 0.72, "dispatch_count": 15},
        {"source_lobe_id": "lobe_nature", "target_lobe_id": "lobe_science", "confidence": 0.65, "dispatch_count": 12},
        {"source_lobe_id": "lobe_emotions", "target_lobe_id": "lobe_philosophy", "confidence": 0.58, "dispatch_count": 8},
        {"source_lobe_id": "lobe_science", "target_lobe_id": "lobe_math", "confidence": 0.70, "dispatch_count": 10},
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# 14. BRIDGES (CASCADE BRIDGE SYSTEM — bidirectional)
# ═══════════════════════════════════════════════════════════════════════
bridges = []
# Bridge math↔science
if len(math_nodes) > 0 and len(science_nodes) > 0:
    bridges.append({
        "node_a": math_nodes[0]["id"],
        "node_b": science_nodes[0]["id"],
        "seam_tokens": ["number", "equation", "formula"],
        "base_confidence_ab": 0.75,
        "base_confidence_ba": 0.68,
        "source_lobe": "lobe_math",
        "is_crystalized": False,
        "crystal_origin": "AUTO"
    })
# Bridge nature↔science
if len(nature_nodes) > 1 and len(science_nodes) > 1:
    bridges.append({
        "node_a": nature_nodes[1]["id"],
        "node_b": science_nodes[1]["id"],
        "seam_tokens": ["life", "organism", "cell"],
        "base_confidence_ab": 0.82,
        "base_confidence_ba": 0.75,
        "source_lobe": "lobe_nature",
        "is_crystalized": True,
        "crystal_origin": "MANUAL"
    })
# Bridge emotions↔philosophy
if len(emotion_nodes) > 0 and len(phil_nodes) > 0:
    bridges.append({
        "node_a": emotion_nodes[0]["id"],
        "node_b": phil_nodes[0]["id"],
        "seam_tokens": ["feeling", "meaning", "reflection"],
        "base_confidence_ab": 0.70,
        "base_confidence_ba": 0.62,
        "source_lobe": "lobe_emotions",
        "is_crystalized": False,
        "crystal_origin": "AUTO"
    })
# Bridge math↔nature (cross-domain)
if len(math_nodes) > 2 and len(nature_nodes) > 3:
    bridges.append({
        "node_a": math_nodes[2]["id"],
        "node_b": nature_nodes[3]["id"],
        "seam_tokens": ["pattern", "sequence", "growth"],
        "base_confidence_ab": 0.55,
        "base_confidence_ba": 0.48,
        "source_lobe": "lobe_math",
        "is_crystalized": False,
        "crystal_origin": "AUTO"
    })
# More bridges for connectivity
if len(math_nodes) > 3 and len(math_nodes) > 4:
    bridges.append({
        "node_a": math_nodes[3]["id"],
        "node_b": math_nodes[4]["id"],
        "seam_tokens": ["arithmetic", "compute", "solve"],
        "base_confidence_ab": 0.90,
        "base_confidence_ba": 0.88,
        "source_lobe": "lobe_math",
        "is_crystalized": True,
        "crystal_origin": "AUTO"
    })
if len(nature_nodes) > 1 and len(nature_nodes) > 2:
    bridges.append({
        "node_a": nature_nodes[1]["id"],
        "node_b": nature_nodes[2]["id"],
        "seam_tokens": ["animal", "describe", "furry"],
        "base_confidence_ab": 0.85,
        "base_confidence_ba": 0.80,
        "source_lobe": "lobe_nature",
        "is_crystalized": False,
        "crystal_origin": "AUTO"
    })
if len(emotion_nodes) > 2 and len(emotion_nodes) > 3:
    bridges.append({
        "node_a": emotion_nodes[2]["id"],
        "node_b": emotion_nodes[3]["id"],
        "seam_tokens": ["feel", "empathy", "comfort"],
        "base_confidence_ab": 0.78,
        "base_confidence_ba": 0.72,
        "source_lobe": "lobe_emotions",
        "is_crystalized": False,
        "crystal_origin": "AUTO"
    })
specimen["bridges"] = bridges

# ═══════════════════════════════════════════════════════════════════════
# 14b. CHATTER GROUPS
# ═══════════════════════════════════════════════════════════════════════
chatter_groups = []
# Math chatter group
chatter_groups.append({
    "id": "grp_math_1",
    "members": [math_nodes[i]["id"] for i in range(min(5, len(math_nodes)))],
    "centroid_pattern": "what is &n plus &n",
    "created_at": now - 7200,
    "last_chatter_at": now - 300,
    "chatter_count": 12,
    "has_grave_slot": True,
    "grave_count": 1,
    "max_occupancy": 8,
    "is_time_node_group": False,
    "is_chatter_eligible": True,
    "inhibition_tokens": ["number", "compute", "sum"]
})
# Nature chatter group
chatter_groups.append({
    "id": "grp_nature_1",
    "members": [nature_nodes[i]["id"] for i in range(min(4, len(nature_nodes)))],
    "centroid_pattern": "describe a cat",
    "created_at": now - 7200,
    "last_chatter_at": now - 600,
    "chatter_count": 8,
    "has_grave_slot": False,
    "grave_count": 0,
    "max_occupancy": 8,
    "is_time_node_group": False,
    "is_chatter_eligible": True,
    "inhibition_tokens": ["animal", "describe", "species"]
})
# Emotion chatter group
chatter_groups.append({
    "id": "grp_emotion_1",
    "members": [emotion_nodes[i]["id"] for i in range(min(4, len(emotion_nodes)))],
    "centroid_pattern": "i feel &word today",
    "created_at": now - 3600,
    "last_chatter_at": now - 180,
    "chatter_count": 15,
    "has_grave_slot": True,
    "grave_count": 0,
    "max_occupancy": 6,
    "is_time_node_group": False,
    "is_chatter_eligible": True,
    "inhibition_tokens": ["feel", "empathy", "comfort"]
})
# Time node chatter group
chatter_groups.append({
    "id": "grp_time_1",
    "members": [n["id"] for n in nodes if n.get("json_data", {}).get("time_node", False)][:4],
    "centroid_pattern": "when was &word discovered",
    "created_at": now - 1800,
    "last_chatter_at": now - 120,
    "chatter_count": 5,
    "has_grave_slot": False,
    "grave_count": 0,
    "max_occupancy": 6,
    "is_time_node_group": True,
    "is_chatter_eligible": True,
    "inhibition_tokens": ["time", "when", "temporal"]
})
specimen["chatter_groups"] = chatter_groups

# Chatter cooldowns
specimen["chatter_cooldowns"] = [
    {"node_id": math_nodes[0]["id"], "last_chatter_at": now - 300},
    {"node_id": nature_nodes[0]["id"], "last_chatter_at": now - 600},
    {"node_id": emotion_nodes[0]["id"], "last_chatter_at": now - 180},
]

# ═══════════════════════════════════════════════════════════════════════
# 14 compat. ATTACHMENTS (backward compat for v7.x loads)
# ═══════════════════════════════════════════════════════════════════════
attachment_list = []
for b in bridges:
    attachment_list.append({
        "target_id": b["node_a"],
        "node_id": b["node_b"],
        "pattern": " ".join(b["seam_tokens"]),
        "signal": [],
        "base_confidence": b["base_confidence_ab"],
        "is_crystalized": b["is_crystalized"],
        "crystal_origin": b["crystal_origin"]
    })
specimen["attachments"] = attachment_list

# ═══════════════════════════════════════════════════════════════════════
# 15. TRAJECTORY STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["trajectory"] = {
    "config": {
        "buffer_size": 64,
        "decay_halflife": 300.0,
        "gini_threshold": 0.65,
        "damping_strength": 0.3,
        "softmax_temperature": 0.8
    },
    "buffer": [
        {"action_dist": {"ACTION_ASSERT": 0.4, "ACTION_QUERY": 0.35, "ACTION_SPECULATE": 0.15, "ACTION_COMMAND": 0.1},
         "tone_dist": {"TONE_DECLARATIVE": 0.3, "TONE_CURIOUS": 0.25, "TONE_NEUTRAL": 0.25, "TONE_REFLECTIVE": 0.2},
         "timestamp": now - 300},
        {"action_dist": {"ACTION_ASSERT": 0.3, "ACTION_QUERY": 0.4, "ACTION_SPECULATE": 0.2, "ACTION_COMMAND": 0.1},
         "tone_dist": {"TONE_CURIOUS": 0.4, "TONE_REFLECTIVE": 0.25, "TONE_NEUTRAL": 0.2, "TONE_DECLARATIVE": 0.15},
         "timestamp": now - 240},
        {"action_dist": {"ACTION_ASSERT": 0.35, "ACTION_QUERY": 0.3, "ACTION_SPECULATE": 0.2, "ACTION_COMMAND": 0.15},
         "tone_dist": {"TONE_NEUTRAL": 0.35, "TONE_DECLARATIVE": 0.25, "TONE_REFLECTIVE": 0.25, "TONE_CURIOUS": 0.15},
         "timestamp": now - 180},
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# 16. TEMPORAL COHERENCE LEDGER
# ═══════════════════════════════════════════════════════════════════════
specimen["temporal_coherence"] = [
    {"sdf_id": "SDF:visual_pattern_math_grid", "last_fired": now - 120, "fire_count": 5,
     "avg_interval": 180.0, "coherence_score": 0.72},
    {"sdf_id": "SDF:visual_pattern_nature_tree", "last_fired": now - 300, "fire_count": 3,
     "avg_interval": 450.0, "coherence_score": 0.55},
    {"sdf_id": "SDF:visual_pattern_emotion_wave", "last_fired": now - 60, "fire_count": 8,
     "avg_interval": 120.0, "coherence_score": 0.85},
]

# ═══════════════════════════════════════════════════════════════════════
# 17. MORPH COOLDOWN MAP
# ═══════════════════════════════════════════════════════════════════════
specimen["morph_cooldowns"] = {
    math_nodes[0]["id"]: now - 7200,
    nature_nodes[0]["id"]: now - 3600,
    emotion_nodes[0]["id"]: now - 1800,
}

# ═══════════════════════════════════════════════════════════════════════
# 18. IMMUNE SYSTEM STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["immune_system"] = {
    "hopfield_memory": {
        str(hashlib.md5(f"safe_{i}".encode()).hexdigest()[:16]): {"signature": f"safe_pattern_{i}", "verdict": "safe", "count": 5 + i}
        for i in range(8)
    },
    "ledger": [
        {"pattern_hash": "abc123", "verdict": "safe", "timestamp": now - 3600, "detail": "standard input"},
        {"pattern_hash": "def456", "verdict": "safe", "timestamp": now - 1800, "detail": "emotional input"},
        {"pattern_hash": "ghi789", "verdict": "quarantined", "timestamp": now - 900, "detail": "anomalous pattern"},
    ],
    "maturity_counter": 42,
    "quarantine": [
        {"pattern": "garbage_input_123", "reason": "incoherent", "added_at": now - 600}
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# 19. AIML NODE SYSTEM STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["aiml_system"] = {
    "registry": {
        "lobe_math": [
            {"id": "aiml_math_1", "lobe_id": "lobe_math", "template": "The answer is {result}. Let me think step by step.",
             "strength": 7.5, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
            {"id": "aiml_math_2", "lobe_id": "lobe_math", "template": "Mathematically speaking, {concept} is fundamental.",
             "strength": 6.0, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
            {"id": "aiml_math_3", "lobe_id": "lobe_math", "template": "To compute {operation}: I apply the relevant formula.",
             "strength": 5.5, "is_grave": False, "grave_reason": "", "created_at": now - 43200},
        ],
        "lobe_nature": [
            {"id": "aiml_nature_1", "lobe_id": "lobe_nature", "template": "In nature, {subject} exhibits fascinating properties.",
             "strength": 7.0, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
            {"id": "aiml_nature_2", "lobe_id": "lobe_nature", "template": "A {species} is characterized by its {trait}.",
             "strength": 6.5, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
        ],
        "lobe_emotions": [
            {"id": "aiml_emotion_1", "lobe_id": "lobe_emotions", "template": "I hear you. {feeling} is a natural response. You're not alone.",
             "strength": 8.5, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
            {"id": "aiml_emotion_2", "lobe_id": "lobe_emotions", "template": "It takes courage to share that. {feeling} can be overwhelming.",
             "strength": 7.0, "is_grave": False, "grave_reason": "", "created_at": now - 43200},
        ],
        "lobe_science": [
            {"id": "aiml_science_1", "lobe_id": "lobe_science", "template": "Scientifically, {concept} can be understood as {definition}.",
             "strength": 6.5, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
        ],
        "lobe_philosophy": [
            {"id": "aiml_phil_1", "lobe_id": "lobe_philosophy", "template": "Philosophers have long pondered {question}. There are many perspectives.",
             "strength": 5.5, "is_grave": False, "grave_reason": "", "created_at": now - 86400},
        ],
    },
    "population_caps": {
        "lobe_math": 20, "lobe_nature": 15, "lobe_emotions": 15,
        "lobe_science": 15, "lobe_philosophy": 10
    },
    "cycle": 127
}

# ═══════════════════════════════════════════════════════════════════════
# 20. SIGIL TABLE
# ═══════════════════════════════════════════════════════════════════════
specimen["sigil_table"] = [
    # :lambda sigils
    {"name": "n", "class": ":lambda", "applies_at": ":match", "sigil_type": ":number",
     "lexicon": None, "params": None, "expansion": None, "provenance": "engine-default",
     "promote_at_tokenize": True},
    {"name": "word", "class": ":lambda", "applies_at": ":match", "sigil_type": ":word",
     "lexicon": None, "params": None, "expansion": None, "provenance": "engine-default",
     "promote_at_tokenize": False},
    {"name": "rest", "class": ":lambda", "applies_at": ":match", "sigil_type": ":slurp",
     "lexicon": None, "params": None, "expansion": None, "provenance": "engine-default",
     "promote_at_tokenize": False},
    {"name": "op", "class": ":lambda", "applies_at": ":match", "sigil_type": ":op",
     "lexicon": None, "params": None, "expansion": None, "provenance": "engine-default",
     "promote_at_tokenize": True},
    # :macro sigils
    {"name": "noun", "class": ":macro", "applies_at": ":bind",
     "sigil_type": None,
     "lexicon": ["cat", "dog", "tree", "ocean", "number", "equation", "feeling",
                 "gravity", "quantum", "consciousness", "species", "cell", "planet",
                 "atom", "molecule", "force", "energy", "light", "heat", "mass"],
     "params": None, "expansion": None, "provenance": "specimen",
     "promote_at_tokenize": False},
    # :tag sigils
    {"name": "question", "class": ":tag", "applies_at": ":match",
     "sigil_type": None, "lexicon": None, "params": None, "expansion": None,
     "provenance": "specimen", "promote_at_tokenize": False},
    {"name": "emotional", "class": ":tag", "applies_at": ":match",
     "sigil_type": None, "lexicon": None, "params": {"tone": "empathy"},
     "expansion": None, "provenance": "specimen", "promote_at_tokenize": False},
    # :relation sigils — dynamic relational triple macros
    {"name": "temporal", "class": ":relation", "applies_at": ":relation",
     "sigil_type": None, "lexicon": None, "params": None,
     "expansion": ["before", "after", "during", "since", "until", "now",
                   "then", "precedes", "follows", "while", "when"],
     "provenance": "engine-default", "promote_at_tokenize": False},
    {"name": "causal", "class": ":relation", "applies_at": ":relation",
     "sigil_type": None, "lexicon": None, "params": None,
     "expansion": ["causes", "produces", "creates", "generates", "leads_to",
                   "results_in", "triggers", "enables", "brings_about"],
     "provenance": "engine-default", "promote_at_tokenize": False},
    {"name": "spatial", "class": ":relation", "applies_at": ":relation",
     "sigil_type": None, "lexicon": None, "params": None,
     "expansion": ["above", "below", "inside", "outside", "near", "beside",
                   "around", "between", "through", "across", "behind", "in_front_of"],
     "provenance": "engine-default", "promote_at_tokenize": False},
    {"name": "possessive", "class": ":relation", "applies_at": ":relation",
     "sigil_type": None, "lexicon": None, "params": None,
     "expansion": ["has", "owns", "contains", "holds", "carries", "possesses",
                   "includes", "comprises"],
     "provenance": "engine-default", "promote_at_tokenize": False},
    {"name": "similarity", "class": ":relation", "applies_at": ":relation",
     "sigil_type": None, "lexicon": None, "params": None,
     "expansion": ["resembles", "mirrors", "echoes", "parallels", "mimics",
                   "approximates", "is_like"],
     "provenance": "engine-default", "promote_at_tokenize": False},
    # :macro time sigils (:tone applies_at)
    {"name": "now", "class": ":macro", "applies_at": ":tone",
     "sigil_type": None,
     "lexicon": ["now", "currently", "right now", "what now", "whats happening",
                 "current state", "presently", "at the moment", "at present"],
     "params": {"orientation": "present",
                "vote_flags": {"reflect": False, "assess": True, "project": False},
                "signal": ["assess_current"]},
     "expansion": None, "provenance": "engine-default", "promote_at_tokenize": True},
    {"name": "before", "class": ":macro", "applies_at": ":tone",
     "sigil_type": None,
     "lexicon": ["before", "earlier", "previously", "what happened",
                 "in the past", "back then", "beforehand", "formerly",
                 "lately", "recently"],
     "params": {"orientation": "past",
                "vote_flags": {"reflect": True, "assess": False, "project": False},
                "signal": ["reflect_past"]},
     "expansion": None, "provenance": "engine-default", "promote_at_tokenize": True},
    {"name": "next", "class": ":macro", "applies_at": ":tone",
     "sigil_type": None,
     "lexicon": ["next", "after", "later", "what will", "whats next",
                 "in the future", "going forward", "soon", "eventually",
                 "afterward", "upcoming"],
     "params": {"orientation": "future",
                "vote_flags": {"reflect": False, "assess": False, "project": True},
                "signal": ["project_future"]},
     "expansion": None, "provenance": "engine-default", "promote_at_tokenize": True},
]

# ═══════════════════════════════════════════════════════════════════════
# 21. EPHEMERAL AUTOMATON REGISTRY
# ═══════════════════════════════════════════════════════════════════════
specimen["automaton_rules"] = [
    {"id": "auto_escalate_comfort",
     "trigger_action": "comfort",
     "steps": [
         {"label": "acknowledge", "op": "explain", "payload": "I hear you."},
         {"label": "validate", "op": "explain", "payload": "Your feelings are valid."},
         {"label": "comfort", "op": "comfort", "payload": ""},
     ],
     "jitter_targets": sorted(["lobe_emotions"]),
     "min_confidence": 0.4},
    {"id": "auto_escalate_calculate",
     "trigger_action": "calculate",
     "steps": [
         {"label": "parse", "op": "explain", "payload": "Let me work through this."},
         {"label": "calculate", "op": "calculate", "payload": ""},
         {"label": "validate", "op": "validate", "payload": ""},
     ],
     "jitter_targets": sorted(["lobe_math"]),
     "min_confidence": 0.5},
    {"id": "auto_escalate_define",
     "trigger_action": "define",
     "steps": [
         {"label": "identify", "op": "explain", "payload": "I can define that."},
         {"label": "define", "op": "define", "payload": ""},
         {"label": "elaborate", "op": "elaborate", "payload": ""},
     ],
     "jitter_targets": sorted(["lobe_science", "lobe_nature"]),
     "min_confidence": 0.3},
]

# ═══════════════════════════════════════════════════════════════════════
# 21.5 PHASE ACCUMULATOR
# ═══════════════════════════════════════════════════════════════════════
specimen["phase_accumulator"] = {
    "crystal": [
        {"snapshot_id": 1, "atp_distribution": {"ponder": 0.35, "explain": 0.30, "comfort": 0.20, "calculate": 0.15},
         "timestamp": now - 600},
        {"snapshot_id": 2, "atp_distribution": {"ponder": 0.25, "explain": 0.35, "define": 0.25, "calculate": 0.15},
         "timestamp": now - 300},
    ],
    "phase_lock_counter": 7
}

# ═══════════════════════════════════════════════════════════════════════
# 22. LAST CONTRIBUTOR VOTES
# ═══════════════════════════════════════════════════════════════════════
specimen["last_contributor_votes"] = [
    {"node_id": emotion_nodes[2]["id"], "action": "comfort", "confidence": 0.85,
     "negatives": [], "user_triples": [{"subject": "sadness", "relation": "causes", "object": "change"}],
     "node_triples": [{"subject": "sadness", "relation": "temporal", "object": "passing"}],
     "antimatch": False, "multipart_group": "", "multipart_role": ":singleton", "input_chunks": []},
    {"node_id": math_nodes[0]["id"], "action": "calculate", "confidence": 0.72,
     "negatives": [], "user_triples": [{"subject": "2", "relation": "plus", "object": "2"}],
     "node_triples": [{"subject": "&noun", "relation": "causes", "object": "result"}],
     "antimatch": False, "multipart_group": "", "multipart_role": ":singleton", "input_chunks": []},
]

# ═══════════════════════════════════════════════════════════════════════
# 23. NODE_TO_GROUP INDEX
# ═══════════════════════════════════════════════════════════════════════
node_to_group = {}
for i in range(min(5, len(math_nodes))):
    node_to_group[math_nodes[i]["id"]] = "grp_math_1"
for i in range(min(4, len(nature_nodes))):
    node_to_group[nature_nodes[i]["id"]] = "grp_nature_1"
for i in range(min(4, len(emotion_nodes))):
    node_to_group[emotion_nodes[i]["id"]] = "grp_emotion_1"
specimen["node_to_group_idx"] = node_to_group

# ═══════════════════════════════════════════════════════════════════════
# 24. TONAL JUDGE KNOBS
# ═══════════════════════════════════════════════════════════════════════
specimen["tonal_judge_knobs"] = {
    "frame_lift_multiplier": 1.2,
    "frame_inhibit_multiplier": 0.8
}

# ═══════════════════════════════════════════════════════════════════════
# 25. EPHEMERAL MLP STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["ephemeral_mlp"] = {
    "weights": {},   # Let engine use defaults — MLPWeights are arrays, not simple dicts
    "rules": [],     # Let engine use defaults — rules have complex structure
    "novelty_tracker": {
        "total_observations": 127,
        "recent_novelty": 0.15,
        "baseline_novelty": 0.3
    },
    "statistics": {
        "total_cycles": 127,
        "average_coherence": 0.72,
        "last_adjustment": now - 3600
    }
}

# MLP observer store
specimen["mlp_observer_store"] = {
    "total_entries": 127,
    "key_count": 45
}

# MLP cached phi
specimen["mlp_cached_phi"] = {
    "last_phi": 0.72
}

# ═══════════════════════════════════════════════════════════════════════
# META
# ═══════════════════════════════════════════════════════════════════════
specimen["_meta"] = {
    "version": "2.11",
    "saved_at": now,
    "format": "grugbot420-specimen-v2.11"
}

# ═══════════════════════════════════════════════════════════════════════
# DECOMPOSER CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["decomposer_config"] = {
    "split_conjunctions": sorted(["also", "additionally", "furthermore", "moreover",
                                  "besides", "likewise", "similarly",
                                  "but", "however", "yet", "nevertheless", "nonetheless",
                                  "alternatively", "instead",
                                  "or", "then",
                                  "while", "whilst", "since", "unless", "except",
                                  "plus", "independently", "separately"]),
    "compound_pairs": {
        "and": sorted(["then", "also", "additionally", "furthermore", "moreover"]),
        "or": sorted(["else"]),
        "but": sorted(["rather", "instead"]),
        "then": sorted(["additionally"])
    },
    "context_conjunction": "and",
    "question_markers": sorted(["what", "who", "where", "when", "why", "how",
                                 "which", "whose", "whom",
                                 "can", "could", "would", "shall", "will",
                                 "do", "does", "did",
                                 "is", "are", "was", "were", "am"]),
    "command_markers": sorted(["tell", "show", "give", "explain", "describe",
                               "calculate", "compute", "solve", "define",
                               "list", "name", "find", "count",
                               "compare", "contrast", "analyze", "evaluate",
                               "summarize", "determine", "identify",
                               "convert", "translate", "search", "lookup"]),
    "conjugation_rules": {
        "tell": ["tells", "told", "telling"],
        "show": ["shows", "showed", "showing"],
        "give": ["gives", "gave", "giving"],
        "explain": ["explains", "explained", "explaining"],
        "describe": ["describes", "described", "describing"],
        "calculate": ["calculates", "calculated", "calculating"],
        "compute": ["computes", "computed", "computing"],
        "solve": ["solves", "solved", "solving"],
        "define": ["defines", "defined", "defining"],
        "list": ["lists", "listed", "listing"],
        "name": ["names", "named", "naming"],
        "find": ["finds", "found", "finding"],
        "count": ["counts", "counted", "counting"],
        "compare": ["compares", "compared", "comparing"],
        "contrast": ["contrasts", "contrasted", "contrasting"],
        "analyze": ["analyzes", "analyzed", "analyzing"],
        "evaluate": ["evaluates", "evaluated", "evaluating"],
        "summarize": ["summarizes", "summarized", "summarizing"],
        "determine": ["determines", "determined", "determining"],
        "identify": ["identifies", "identified", "identifying"],
        "convert": ["converts", "converted", "converting"],
        "translate": ["translates", "translated", "translating"],
        "search": ["searches", "searched", "searching"],
        "lookup": ["lookups", "lookedup"],
    }
}

# ═══════════════════════════════════════════════════════════════════════
# 26. VIGILANCE CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["vigilance_config"] = {
    "max_cap": 5,
    "min_cap": 1,
    "dispatch_probability": 0.3,
    "feedback_probability": 0.15,
    "confidence_threshold": 0.5,
    "timeout_seconds": 30.0,
    "timeout_jitter": 5.0,
    "batch_size": 3
}

# ═══════════════════════════════════════════════════════════════════════
# 27. INJECTOR STATS
# ═══════════════════════════════════════════════════════════════════════
specimen["injector_stats"] = {
    "total_dispatched": 42,
    "total_completed": 38,
    "total_timed_out": 2,
    "total_entries_injected": 127,
    "total_feedback_written": 15,
    "last_dispatch_at": now - 300
}

# ═══════════════════════════════════════════════════════════════════════
# 28. RELATIONAL JITTER CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["relational_jitter_config"] = {
    "jitter_ratio": 0.05,
    "jitter_coin_ratio": 0.1,
    "jitter_enabled": True
}

# ═══════════════════════════════════════════════════════════════════════
# 29. BRAINSTEM CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["brainstem_config"] = {
    "propagation_decay": 0.95,
    "fire_count_decay_factor": 0.9,
    "fire_count_decay_interval": 3600,
    "propagation_min_confidence": 0.3
}

# ═══════════════════════════════════════════════════════════════════════
# 30. ENGINE CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["engine_config"] = {
    "strength_cap": 10.0,
    "strength_floor": 0.0,
    "strength_solidify_threshold": 6.0,
    "jitter_confidence_floor": 0.15,
    "max_neighbors": 16,
    "latch_partner_cap_min": 8,
    "latch_partner_cap_max": 16,
    "antimatch_drain_fixed": 0.5,
    "antimatch_drain_max_jitter": 0.25
}

# ═══════════════════════════════════════════════════════════════════════
# 31. LOBE ORCHESTRATOR KNOBS
# ═══════════════════════════════════════════════════════════════════════
specimen["lobe_orchestrator_knobs"] = {
    "hard_fire_batch_cap": 3,
    "min_pass_through_score": 0.1,
    "min_winning_votes_per_lobe": 1,
    "top_k_fraction": 0.5,
    "hard_selection_conf_threshold": 0.7,
    "default_lobe_demotion_factor": 0.85
}

# ═══════════════════════════════════════════════════════════════════════
# 32. VOTE ORCHESTRATOR KNOBS
# ═══════════════════════════════════════════════════════════════════════
specimen["vote_orchestrator_knobs"] = {
    "aiml_confidence_threshold": 0.5,
    "aiml_top_tier_window": 0.05,
    "aiml_subtop_base_prob": 0.3,
    "aiml_subtop_bonus_prob": 0.2,
    "vote_w_lobe_alignment": 0.25,
    "vote_w_relational_match": 0.2,
    "vote_w_recency_bonus": 0.15,
    "vote_w_action_tone_align": 0.2,
    "vote_w_anti_match_penalty": 0.3,
    "vote_w_peak_dominance": 0.1,
    "vote_bonus_cap": 0.5,
    "vote_score_floor": 0.05,
    "active_fire_cap": 5,
    "fire_batch_size": 3
}

# ═══════════════════════════════════════════════════════════════════════
# 33. MITOSIS CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["mitosis_config"] = {
    "mitosis_probability": 0.15,
    "data_energy_msg_scale": 0.1,
    "data_energy_intensity_scale": 0.2,
    "max_mitosis_per_cycle": 2,
    "min_population_gate": 5,
    "max_population_cap": 200,
    "mitosis_cooldown_cycles": 10,
    "silence_warrant_threshold": 0.6,
    "silence_warrant_min_accum": 3,
    "frequency_warrant_min": 3,
    "thesaurus_warrant_threshold": 0.7,
    "lobe_coverage_ratio_min": 0.3,
    "min_warrant_threshold": 0.5,
    "mitosis_strength_default": 5.0,
    "pattern_sim_floor": 0.6,
    "vote_sim_floor": 0.5,
    "group_max_occupancy": 8,
    "strain_warrant_weight": 0.3,
    "strain_warrant_active_threshold": 0.7
}

# ═══════════════════════════════════════════════════════════════════════
# 33b. GROWTH CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["growth_config"] = {
    "growth_batch_size": 2,
    "growth_probability_ceiling": 0.3,
    "group_strength_floor": 4.0,
    "min_fresh_entries": 3,
    "data_energy_msg_scale": 0.1,
    "growth_node_strength": 5.0,
}

# ═══════════════════════════════════════════════════════════════════════
# 34. PHAGY CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["phagy_config"] = {
    "orphan_max_neighbors": 2,
    "decay_rate": 0.02,
    "decay_eligibility_max": 3,
    "drop_table_trim_floor": 0.1,
    "rule_dormancy_cycles": 50
}

# ═══════════════════════════════════════════════════════════════════════
# 35. CHATTER CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["chatter_config"] = {
    "min_population_for_chatter": 6,
    "idle_threshold_seconds": 120.0,
    "idle_jitter_seconds": 30.0,
    "chatter_group_sample_min": 2,
    "chatter_group_sample_max": 4,
    "chatter_weak_floor": 2.0,
    "chatter_strong_floor": 6.0,
    "chatter_grave_floor": 0.0,
    "chatter_weight_jitter_sigma": 0.1,
    "strong_low_conf_override": 0.3,
    "morph_cooldown_seconds": 86400.0
}

# ═══════════════════════════════════════════════════════════════════════
# 36. IMMUNE CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["immune_config"] = {
    "maturity_threshold": 10,
    "automata_population_ratio": "3:1",
    "coinflip_probability": 0.3,
    "patch_timeout_seconds": 300.0,
    "patch_timeout_jitter": 60.0,
    "max_ledger_entries": 1000,
    "max_quarantine_size": 50,
    "hopfield_familiarity_threshold": 0.6
}

# ═══════════════════════════════════════════════════════════════════════
# 37. FULL LOBE SCANNER CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["scanner_config"] = {
    "max_active_nodes": 20,
    "confident_threshold": 0.7,
    "default_candidate_threshold": 0.3
}

# ═══════════════════════════════════════════════════════════════════════
# 38. ACTION TONE PREDICTOR KNOBS
# ═══════════════════════════════════════════════════════════════════════
specimen["action_tone_knobs"] = {
    "incoherence_tag_threshold": 0.4,
    "low_signal_threshold": 0.2,
    "fallback_damp_threshold": 0.15,
    "curve_jitter_envelope": 0.1,
    "escalation_confidence_floor": 0.3
}

# ═══════════════════════════════════════════════════════════════════════
# 39. CO-ACTIVATION ACCUMULATOR
# ═══════════════════════════════════════════════════════════════════════
co_activation = {}
for i in range(min(5, len(math_nodes))):
    for j in range(i+1, min(5, len(math_nodes))):
        key = f"{math_nodes[i]['id']}|{math_nodes[j]['id']}"
        co_activation[key] = {"intensity": 0.3 + i * 0.1, "co_fire_count": 5 + i * 2}
for i in range(min(4, len(nature_nodes))):
    for j in range(i+1, min(4, len(nature_nodes))):
        key = f"{nature_nodes[i]['id']}|{nature_nodes[j]['id']}"
        co_activation[key] = {"intensity": 0.25 + i * 0.1, "co_fire_count": 3 + i * 2}
for i in range(min(3, len(emotion_nodes))):
    for j in range(i+1, min(3, len(emotion_nodes))):
        key = f"{emotion_nodes[i]['id']}|{emotion_nodes[j]['id']}"
        co_activation[key] = {"intensity": 0.35 + i * 0.1, "co_fire_count": 7 + i * 2}
specimen["co_activation"] = co_activation

# ═══════════════════════════════════════════════════════════════════════
# INPUT LEDGER
# ═══════════════════════════════════════════════════════════════════════
specimen["input_ledger"] = {
    "consumed_hashes": [hashlib.md5(f"msg_{i}".encode()).hexdigest() for i in range(8)],
    "total_consumed": 8
}

# ═══════════════════════════════════════════════════════════════════════
# CHATTER RESIDUALS
# ═══════════════════════════════════════════════════════════════════════
specimen["chatter_residuals"] = {
    "consumed_hashes": [hashlib.md5(f"swap_{i}".encode()).hexdigest() for i in range(5)],
    "total_consumed": 5
}

# ═══════════════════════════════════════════════════════════════════════
# 39b. AUTOGROWTH EVIDENCE + CO-OCCURRENCE
# ═══════════════════════════════════════════════════════════════════════
evidence_list = []
sources = ["scan_miss", "frequency_warrant", "thesaurus_warrant", "silence_warrant",
           "strain_warrant", "curiosity_warrant", "vote_warrant", "temporal_warrant",
           "relational_warrant", "co_activation_warrant", "bridge_warrant",
           "aiml_warrant", "multipart_warrant", "decomposer_warrant",
           "immune_warrant", "phase_warrant", "growth_warrant"]
for i, src in enumerate(sources):
    evidence_list.append({
        "source": src,
        "pattern": f"evidence_pattern_{i}",
        "count": 3 + i,
        "last_seen": now - 3600 + i * 200,
        "lobe_id": ["lobe_math", "lobe_nature", "lobe_emotions", "lobe_science", "lobe_philosophy"][i % 5]
    })
specimen["autogrowth_evidence"] = evidence_list

co_occur = {}
for i in range(10):
    key = f"word_{i}|word_{i+1}"
    co_occur[key] = {"count": 2 + i, "last_seen": now - 1800 + i * 100}
specimen["autogrowth_co_occur"] = [{"pair": k, **v} for k, v in co_occur.items()]

# ═══════════════════════════════════════════════════════════════════════
# 39c. AUTOLINKER LINK EVIDENCE
# ═══════════════════════════════════════════════════════════════════════
link_evidence = []
for i in range(5):
    n1 = nodes[i % len(nodes)]["id"]
    n2 = nodes[(i + 5) % len(nodes)]["id"]
    link_evidence.append({
        "node_a": n1, "node_b": n2,
        "co_fire_count": 4 + i,
        "bridge_strength": 0.3 + i * 0.1,
        "last_seen": now - 2400 + i * 300
    })
specimen["autolink_evidence"] = link_evidence

# ═══════════════════════════════════════════════════════════════════════
# 39d. FLASHCARD DATA (per-lobe)
# ═══════════════════════════════════════════════════════════════════════
specimen["flashcards"] = {
    "lobe_math": [
        {"question": "2+2", "answer": "4", "type": "addition"},
        {"question": "3+5", "answer": "8", "type": "addition"},
        {"question": "7*8", "answer": "56", "type": "multiplication"},
        {"question": "9*9", "answer": "81", "type": "multiplication"},
        {"question": "10-3", "answer": "7", "type": "subtraction"},
        {"question": "15/3", "answer": "5", "type": "division"},
        {"question": "0+0", "answer": "0", "type": "addition"},
        {"question": "1*1", "answer": "1", "type": "multiplication"},
        {"question": "6+7", "answer": "13", "type": "addition"},
        {"question": "8*7", "answer": "56", "type": "multiplication"},
    ]
}

# ═══════════════════════════════════════════════════════════════════════
# 39e. CURIOSITY ACCUMULATOR
# ═══════════════════════════════════════════════════════════════════════
specimen["curiosity"] = {
    "intensity": 0.35,
    "buffer": [
        {"topic": "quantum_entanglement", "novelty_score": 0.8, "timestamp": now - 600},
        {"topic": "deep_sea_creatures", "novelty_score": 0.65, "timestamp": now - 300},
    ],
    "quench_timestamp": now - 7200
}

# ═══════════════════════════════════════════════════════════════════════
# 40. FAN-OUT CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["fanout_config"] = {
    "enabled": True,
    "max_shadows": 3,
    "modes": ["mirror", "diverge", "contrast"]
}

# ═══════════════════════════════════════════════════════════════════════
# 41. HIPPOCAMPAL PENDING ASK
# ═══════════════════════════════════════════════════════════════════════
specimen["hippocampal_pending_ask"] = {
    "pending_text": ""
}

# ═══════════════════════════════════════════════════════════════════════
# 42. ADMIN SESSION
# ═══════════════════════════════════════════════════════════════════════
specimen["admin_session"] = {
    "is_logged_in": False,
    "login_time": 0.0,
    "last_activity": 0.0
}

# ═══════════════════════════════════════════════════════════════════════
# 43. LOBE ORCHESTRATOR LAST STATE
# ═══════════════════════════════════════════════════════════════════════
specimen["lobe_orch_last"] = {
    "scores": [
        {"lobe_id": "lobe_math", "score": 0.65, "fire_count": 42},
        {"lobe_id": "lobe_nature", "score": 0.55, "fire_count": 38},
        {"lobe_id": "lobe_emotions", "score": 0.78, "fire_count": 55},
        {"lobe_id": "lobe_science", "score": 0.45, "fire_count": 30},
        {"lobe_id": "lobe_philosophy", "score": 0.35, "fire_count": 15},
    ],
    "winner": "lobe_emotions",
    "passthrough": 0.12
}

# ═══════════════════════════════════════════════════════════════════════
# 44. CHATTER CURSOR
# ═══════════════════════════════════════════════════════════════════════
specimen["chatter_cursor"] = {
    "cursor": 5
}

# ═══════════════════════════════════════════════════════════════════════
# 45. ANSWER MODE CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["answer_mode_config"] = {
    "default": {"action": "ponder|explain", "voice": "default", "frame": [], "prompt": ""},
    "precise": {"action": "calculate|explain|validate|explain", "voice": "precise", "frame": ["arithmetic"], "prompt": "Give concise, accurate answers."},
    "warm": {"action": "comfort|explain|comfort|explain", "voice": "warm", "frame": ["empathy"], "prompt": "Be empathetic and supportive."},
    "academic": {"action": "define|explain|explain|explain", "voice": "academic", "frame": ["science"], "prompt": "Explain with precision and depth."},
    "contemplative": {"action": "ponder|explain|elaborate|explain", "voice": "contemplative", "frame": ["philosophy"], "prompt": "Reflect deeply on this."},
    "storyteller": {"action": "describe|explain|elaborate|explain", "voice": "storyteller", "frame": ["prose"], "prompt": "Tell a vivid narrative."},
}

# ═══════════════════════════════════════════════════════════════════════
# 46. PHAGY RULES REF
# ═══════════════════════════════════════════════════════════════════════
specimen["phagy_rules_ref"] = [
    {"id": "prule_decay_weak", "action": "DECAY", "threshold": 2.0, "lobe": "all"},
    {"id": "prule_trim_orphans", "action": "TRIM", "threshold": 0.0, "lobe": "all"},
    {"id": "prule_consolidate_strong", "action": "CONSOLIDATE", "threshold": 8.0, "lobe": "lobe_math"},
]

# ═══════════════════════════════════════════════════════════════════════
# 47. TIME ORIENTATION CONFIG
# ═══════════════════════════════════════════════════════════════════════
time_node_index = {}
for n in nodes:
    jd = n.get("json_data", {})
    if jd.get("time_node", False):
        time_node_index[n["id"]] = {
            "orientation": jd.get("time_orientation", "present"),
            "sigil": jd.get("time_sigil", ""),
            "pattern": n["pattern"]
        }

specimen["time_orientation_config"] = {
    "global_orientation": "present",
    "global_meta": {},
    "time_node_index": time_node_index
}

# ═══════════════════════════════════════════════════════════════════════
# 26 (again). COHERENCE FIELD CONFIG
# ═══════════════════════════════════════════════════════════════════════
specimen["coherence_config"] = {
    "weight": 0.15,
    "window_size": 5,
    "min_pairs": 3
}

# ═══════════════════════════════════════════════════════════════════════
# WRITE TO FILE
# ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
# RESOLVE RELATIONAL-TRIPLE SIGILS (coherence). The engine resolves relation-field
# sigils (&causal etc.) but NOT &noun in subject/object — those leak as literal
# "&noun" text. Bake concrete words in here so the generator is the source of truth.
_RELATION_SIGIL_MAP = {"&causal": "causes", "&temporal": "precedes", "&spatial": "contains",
                       "&similarity": "resembles", "&possessive": "has"}
_TOPIC_WORDS = {
    "math": ["number", "equation", "formula", "quantity"], "fire": ["fire", "flame", "heat", "ember"],
    "water": ["water", "liquid", "stream", "rain"], "rock": ["rock", "stone", "boulder", "mineral"],
    "ice": ["ice", "frost", "crystal", "glacier"], "wind": ["wind", "breeze", "gust", "air"],
    "nature": ["nature", "forest", "tree", "mountain"], "emotion": ["feeling", "emotion", "heart", "soul"],
    "sad": ["sadness", "sorrow", "grief", "melancholy"], "happy": ["joy", "happiness", "delight", "bliss"],
    "angry": ["anger", "fury", "rage", "wrath"], "science": ["phenomenon", "theory", "experiment", "observation"],
    "philosophy": ["concept", "idea", "thought", "wisdom"], "time": ["moment", "era", "epoch", "instant"],
    "history": ["event", "civilization", "era", "artifact"], "future": ["possibility", "destiny", "prospect", "horizon"],
    "cat": ["cat", "feline", "kitten", "whiskers"], "dog": ["dog", "canine", "puppy", "loyalty"]}
def _concrete_word(node, idx):
    pat = node.get("pattern", "").lower()
    anchors = node.get("json_data", {}).get("noun_anchors", [])
    for topic, words in _TOPIC_WORDS.items():
        if topic in pat or any(topic in a.lower() for a in anchors):
            return words[idx % len(words)]
    if anchors:
        return anchors[idx % len(anchors)]
    return ["thing", "entity", "object", "phenomenon"][idx % 4]
for _n in nodes:
    _idx = 0
    for _t in _n.get("relational_patterns", []):
        for _f in ("subject", "relation", "object"):
            _v = _t.get(_f, "")
            if _v == "&noun":
                _t[_f] = _concrete_word(_n, _idx); _idx += 1
            elif _v in _RELATION_SIGIL_MAP:
                _t[_f] = _RELATION_SIGIL_MAP[_v]
# ═══════════════════════════════════════════════════════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════════════
output_path = "/workspace/grugbot420/specimens/comprehensive_kitchensink.json"
json_str = json.dumps(specimen, indent=2, ensure_ascii=False)
with open(output_path, "w") as f:
    f.write(json_str)

file_size = os.path.getsize(output_path)
print(f"Specimen written to: {output_path}")
print(f"File size: {file_size} bytes ({file_size/1024:.1f} KB)")
print(f"Total nodes: {len(nodes)}")
print(f"Total lobes: {len(lobes)}")
print(f"Total bridges: {len(bridges)}")
print(f"Total chatter groups: {len(chatter_groups)}")
print(f"Total top-level keys: {len(specimen)}")
print(f"Sigil table entries: {len(specimen['sigil_table'])}")
print(f"Verb classes: {len(specimen['verb_registry']['classes'])}")
print(f"Thesaurus words: {len(specimen['thesaurus_seeds'])}")
print(f"Inhibitions: {len(specimen['inhibitions'])}")
print(f"AIML nodes: {sum(len(v) for v in specimen['aiml_system']['registry'].values())}")
print(f"Flashcards: {sum(len(v) for v in specimen['flashcards'].values())}")
print(f"AutoGrowth evidence sources: {len(specimen['autogrowth_evidence'])}")
print(f"Automaton rules: {len(specimen['automaton_rules'])}")

if file_size < 50 * 1024:
    print(f"\n⚠️  WARNING: File is only {file_size/1024:.1f} KB — below the 50KB target!")
else:
    print(f"\n✅ File meets the 50KB target ({file_size/1024:.1f} KB)")
