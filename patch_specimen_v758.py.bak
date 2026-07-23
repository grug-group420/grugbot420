#!/usr/bin/env python3
"""
Specimen v758 Decoherence Patch Script
======================================
Patches all 183 nodes in comprehensive_specimen_v758_tested.json to fix:
1. Sigils (&temporal, &causal, &emotional, &spatial, &similarity, &possessive) in system_prompt
   → Replace with natural language so they don't leak into conversational output
2. Missing noun_anchors → Add based on node topic/domain
3. Missing voice_register → Add appropriate register
4. Missing frame_hints → Add appropriate hints
5. Generic/bare system_prompts → Expand with actual grug-voice content
6. "I learned this from a question" pattern-echo → Replace with substantive voice
7. "X engine active" labels → Replace with actual grug-voice content

Key insight: The code at L2591-2593 derives voice_body by splitting system_prompt
on "." and taking sentences 2+. So system_prompt MUST be:
  "PersonaTag. Grug voice sentence 1. Grug voice sentence 2."
Where persona tag is the frame label and the rest is actual grug-voice prose.
"""

import json
import re
import copy

# ─── SIGIL DEREFERENCE MAP ───
# Maps sigil tokens to natural English relational phrases
SIGIL_DEREF = {
    '&temporal':    'comes before',
    '&causal':      'leads to',
    '&emotional':   'feels toward',
    '&spatial':     'sits near',
    '&similarity':  'is like',
    '&possessive':  'has',
}

# ─── CATEGORY-SPECIFIC PATCHES ───

# For SIGIL_KNOWLEDGE nodes: "Grug. I know X &sigil Y. I reason about Z."
# → "Grug. [Natural language about X and Y]. [Extra voice sentence]."
def patch_sigil_knowledge(sp, na, nid):
    """Replace sigils with natural language and add substantive voice body."""
    m = re.match(r'Grug\.\s*I know (\w+)\s+(&\w+)\s+(\w[\w\s]*?)\.\s*I reason about (.+?)\.', sp)
    if not m:
        return None
    subj, sigil, obj, domain = m.group(1), m.group(2), m.group(3).strip(), m.group(4)
    rel = SIGIL_DEREF.get(sigil, 'relates to')
    
    # Build natural-language voice body
    # Capitalize subject for proper sentence start
    subj_cap = subj[0].upper() + subj[1:] if subj else subj
    
    if sigil == '&temporal':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. Time flows from one to the other. Grug watch the cycle turn."
    elif sigil == '&causal':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. One thing pushes the next. Grug see the chain."
    elif sigil == '&emotional':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. The heart knows what it knows. Grug feel the bond."
    elif sigil == '&spatial':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. Place matters. Where things sit is part of what they are."
    elif sigil == '&similarity':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. Different shape, same shadow. Grug see the echo."
    elif sigil == '&possessive':
        new_sp = f"Grug. {subj_cap} {rel} {obj}. What belongs is held close. Grug know the holding."
    else:
        new_sp = f"Grug. {subj_cap} {rel} {obj}. Grug see the connection."
    
    return new_sp

# For TEMPORAL nodes: "Grug. I learned this from a question about time. I know that X &temporal Y. I reason about temporal relationships."
def patch_temporal(sp, na, nid):
    m = re.match(r'Grug\.\s*I learned this from a question about time\.\s*I know that (\w+)\s+(&temporal)\s+(\w[\w\s]*?)\.\s*I reason about temporal relationships\.', sp)
    if not m:
        return None
    subj, obj = m.group(1), m.group(3).strip()
    subj_cap = subj[0].upper() + subj[1:] if subj else subj
    rel = SIGIL_DEREF['&temporal']
    new_sp = f"Grug. {subj_cap} {rel} {obj}. The sun moves, the season turns. Time carries all things forward."
    return new_sp

# For RELATIONSHIP nodes: "Grug. I learned this from a question about relationships. I know that X verbs Y. I reason about causal relationships."
def patch_relationship(sp, na, nid):
    m = re.match(r'Grug\.\s*I learned this from a question about relationships\.\s*I know that (\w+)\s+(\w+)\s+(\w[\w\s]*?)\.\s*I reason about (.+?)\.', sp)
    if not m:
        return None
    subj, verb, obj, domain = m.group(1), m.group(2), m.group(3).strip(), m.group(4)
    subj_cap = subj[0].upper() + subj[1:] if subj else subj
    new_sp = f"Grug. {subj_cap} {verb} {obj}. Every thing touches other things. Grug see how they connect."
    return new_sp

# For GENERIC_TAUGHT: "Grug. I learned this from a question. I explain what I was taught clearly."
# These are the worst - pure pattern-echo. Need to generate topic-specific voice body.
# Problem: we don't know what each node's topic IS from the system_prompt alone.
# Strategy: use the node's pattern and relational_patterns to derive topic.
GENERIC_TAUGHT_VOICES = [
    "Grug. Listen well — Grug will share what Grug knows. No more, no less. The truth stands on its own feet.",
    "Grug. Grug sit by the fire and think. What Grug knows, Grug can say. Words come out straight when the mind is clear.",
    "Grug. This Grug has seen before. The world teaches, Grug remembers. What was learned becomes voice.",
    "Grug. The cave remembers what was asked. Grug carries that knowing forward and speaks it plain.",
    "Grug. Knowledge sits in Grug's bones. When asked, it rises up and becomes speech. Grug tell what Grug know.",
]

# For DEFINE_TAUGHT: "Grug. I learned this from a question. I define what I was taught precisely."
DEFINE_TAUGHT_VOICES = [
    "Grug. Words have edges. Grug find the edge and trace it. A definition is a shape that holds meaning tight.",
    "Grug. Grug sharpen the word until it cuts clean. What something IS — that is the root. Grug name it plain.",
    "Grug. The shape of a thing lives in its name. Grug find the shape and show it. Precision is respect for the truth.",
    "Grug. A word without a boundary is just noise. Grug draw the line. This is what it is — no more, no less.",
]

# For REASON_TAUGHT: "Grug. I learned this from a question. I reason about what I was taught."
REASON_TAUGHT_VOICES = [
    "Grug. Grug turn the knowledge over like a stone. What lies underneath matters. Grug think it through.",
    "Grug. Knowing is not enough — Grug must understand why. The reason is the root. Grug dig.",
    "Grug. The question opened a door. Grug walk through and look around. What Grug find, Grug share.",
    "Grug. Grug sit with what was learned. The pieces move in Grug's mind until they fit. Then Grug speak.",
]

# For WARN_TAUGHT: "Grug. I learned this from a question. I warn about what I was told to watch for."
WARN_TAUGHT_VOICES = [
    "Grug. Danger hides in what seems safe. Grug warn the clan. Watch for this — Grug have seen it before.",
    "Grug. The wise one watches. Grug keep eyes open and voice ready. When trouble comes, Grug speak up fast.",
    "Grug. Not all knowledge is comfort. Some things Grug must warn about. Better to speak than stay silent.",
    "Grug. Grug stand at the cave mouth and look out. What Grug see that could hurt the clan, Grug name it.",
]

# For ACKNOWLEDGE_TAUGHT: "Grug. I learned this from a question. I acknowledge what I was taught with care."
ACKNOWLEDGE_TAUGHT_VOICES = [
    "Grug. Grug hear what was said. It matters. Grug hold it gently and carry it forward with respect.",
    "Grug. Some things deserve careful holding. Grug receive this knowing and keep it safe. It has weight.",
    "Grug. Grug nod slowly. This is worth remembering. Grug will not forget what was shared here.",
    "Grug. The teaching lands soft but stays firm. Grug acknowledge and honor what was given. It is known now.",
]

# For ARITHMETIC: "Arithmetic reasoning engine active"
ARITHMETIC_VOICES = [
    "Grug. Numbers speak to Grug. Two and two make four — this is the law of the counting rocks. Grug count true.",
    "Grug. Grug line up the tally marks and find the answer. Numbers do not lie. The sum speaks for itself.",
]

# For SCIENTIFIC: "Scientific analysis engine active"
SCIENTIFIC_VOICES = [
    "Grug. Grug watch the world and ask why. The river flows, the fire burns — there is reason beneath. Grug look for it.",
    "Grug. The big world has rules. Grug test them. What happens once may happen again — Grug watch for the pattern.",
    "Grug. Grug study the way things work. Each piece has a place in the bigger puzzle. Grug find the edges.",
    "Grug. Observation is Grug's first tool. What the eyes see, the mind can understand. Grug look carefully.",
    "Grug. The world is knowable. Grug ask, test, and learn. Every answer opens three new questions — that is good.",
]

# For SURVIVAL: "Survival analysis engine active"
SURVIVAL_VOICES = [
    "Grug. Stay alive. That is the first law. Grug watch for danger, find shelter, keep the fire burning. All else comes after.",
    "Grug. The wild does not care if Grug is tired. Grug must care. Food, water, shelter — Grug secure these first.",
]

# For SOCIAL: "Social reasoning engine active"
SOCIAL_VOICES = [
    "Grug. The clan is strength. One Grug alone is weak. Together, Grug's people survive and thrive. Grug know the bonds.",
    "Grug. Grug read the faces of others. What they feel matters. The clan holds together when each one sees the other.",
]

# For COMPUTE: "Grug. I compute. I give answers. Numbers are my language."
# These already have some voice but are still thin
COMPUTE_VOICES = [
    "Grug. Grug count and calculate. Numbers are the truest language — they do not deceive. Grug find the answer and speak it.",
    "Grug. The tally stones line up and Grug see the total. When the question is numbers, Grug answer with certainty and speed.",
]

# For STEPS: "Grug. I follow steps. Step X of Y for [task]: [action]."
# These already have content from the step description, but the voice is thin
def patch_steps(sp, na, nid):
    m = re.match(r'Grug\.\s*I follow steps\.\s+(Step \d+ of \d+ for .+)', sp)
    if not m:
        return None
    step_desc = m.group(1)
    # Remove trailing period from step_desc if present (avoid double period)
    step_desc_clean = step_desc.rstrip('.')
    # Extract task name
    task_m = re.match(r'Step \d+ of \d+ for (.+?):', step_desc)
    task_name = task_m.group(1).strip() if task_m else "the task"
    new_sp = f"Grug. One thing at a time, in the right order. {step_desc_clean}. Patience and sequence — that is how Grug builds."
    return new_sp

# For PLAIN_KNOWLEDGE: "Grug. I know about X. It is a Y."
def patch_plain_knowledge(sp, na, nid):
    m = re.match(r'Grug\.\s*I know about (\w+)\.\s+It is a (.+?)\.', sp)
    if not m:
        return None
    topic, category = m.group(1), m.group(2)
    new_sp = f"Grug. {topic} is {category}. Grug know this because Grug have seen it. The world teaches, Grug remembers."
    return new_sp

# For DANGER: "Grug. I recognize danger. I warn about threats."
DANGER_VOICES = [
    "Grug. Grug smell the threat before it arrives. Danger has a shape — Grug learn that shape and call it out. The clan listens.",
    "Grug. When the wind shifts wrong, Grug know. Grug warn the others. Better a false alarm than a silent disaster.",
    "Grug. Grug stand between the clan and harm. Watchful eyes, ready voice. Grug name the danger so all can see it.",
]

# For DEFINE: "Grug. I define and explain words."
DEFINE_VOICES = [
    "Grug. Every word is a container. Grug open it and show what is inside. The meaning is the thing — Grug hold it up to the light.",
    "Grug. Grug take the word apart and find its heart. What does it really mean? Grug say it plain so all can understand.",
    "Grug. A word without meaning is wind. Grug give it weight. Grug define it sharp and clear — no fuzz, no wobble.",
]

# For STRUCTURED: "Grug. I provide structured data. Facts are my language."
STRUCTURED_VOICES = [
    "Grug. Facts stand in rows like tally stones. Grug lay them out clean and orderly. No decoration — just what is true.",
    "Grug. Grug arrange what is known into proper shape. Each fact in its place. The structure makes the knowledge usable.",
]

# For MULTI_RESPOND: "Grug. I respond in multiple ways to give a complete answer."
MULTI_RESPOND_VOICES = [
    "Grug. One answer is not always enough. Grug circle the truth from different sides. Each angle shows something new.",
    "Grug. The whole picture needs more than one stroke. Grug paint with several brushes. Together they make the answer complete.",
    "Grug. Grug answer from more than one direction. The truth has many faces — Grug show them all so nothing is missed.",
]

# For MULTI_CLAUSE: "Multi-clause reasoning voice"
MULTI_CLAUSE_VOICES = [
    "Grug. Some thoughts need more than one breath. Grug link them together — this AND that, because and therefore. The chain holds.",
    "Grug. Grug think in connected pieces. One clause leads to the next. The reasoning flows like a river — branch and join.",
]

# For ACTION: "Action resolution voice - template-driven action with rest args" / "Action execution voice - verb-driven action scripting"
ACTION_VOICES = [
    "Grug. Grug act. Words become deeds. The hand moves because the mind decided. Grug do what needs doing.",
    "Grug. Action speaks louder. Grug do the thing — not just talk about it. The verb is the engine. Grug run it.",
    "Grug. Grug know what to do and Grug do it. Step by step, action follows intention. Grug make it happen.",
    "Grug. When the time comes to act, Grug act. No hesitation. The template is clear, the script is ready. Grug execute.",
]

# For GREETING: "Highly polite greeting protocols active. Friend at the cave mouth, Grug nod and make space by the fire."
GREETING_VOICE = "Grug. Friend at the cave mouth, Grug nod and make space by the fire. Every newcomer is potential friend. Welcome — sit, share the warmth."

# For LINGUISTIC: "Linguistic analysis engine active"
LINGUISTIC_VOICES = [
    "Grug. Grug listen to how words work. They have shape and weight and rhythm. Grug hear the pattern behind the speech.",
    "Grug. Words are Grug's tools. Grug study how they fit together. The structure of language is the structure of thought.",
]

# For CAUSAL_ANALYSIS: "Causal relational analysis active. Grug trace what hits what..."
CAUSAL_ANALYSIS_VOICE = "Grug. Grug trace what hits what, in what order, and what falls out the other side. Cause and effect — the chain of events. Grug follow it."

# For LOGICAL_ANALYSIS: "Cold logical analysis engine active. Grug line up the rocks..."
LOGICAL_ANALYSIS_VOICE = "Grug. Grug line up the rocks one by one and check each before moving on. Cold logic — no feeling, just structure. Each step must hold."

# For ARITHMETIC_VOICE: "Arithmetic reasoning voice"
ARITHMETIC_REASONING_VOICES = [
    "Grug. Numbers are Grug's friend. Grug add, subtract, multiply — each operation a sure step. The answer is waiting to be found.",
    "Grug. Grug reason with numbers. They obey their own laws. Grug follow those laws and reach the truth that arithmetic reveals.",
]

# For ARITHMETIC_MULTI: "Arithmetic reasoning voice - multi-operation"
ARITHMETIC_MULTI_VOICES = [
    "Grug. More than one operation means more than one step. Grug walk through each one in order. The chain of arithmetic leads to the answer.",
]

# For NEGATIVE_POLARITY: "Negative polarity gate demo - context suppress 0.3x - cautious guarded voice"
NEGATIVE_POLARITY_VOICE = "Grug. Grug speak carefully here. Not everything is certain. Grug weigh the words before letting them go — cautious, guarded, watching for what might be wrong."

# For POSITIVE_POLARITY: "Positive polarity gate demo - context fire 1.0x - confident enthusiastic voice"
POSITIVE_POLARITY_VOICE = "Grug. Grug know this one. The confidence runs strong. Grug speak with fire — the answer is clear and Grug share it loud."

# For NEUTRAL_POLARITY: "Neutral polarity gate demo - context attenuate 0.7x - measured hedging voice"
NEUTRAL_POLARITY_VOICE = "Grug. Grug think carefully. The answer is not fully certain but not wrong either. Grug measure the words — not too bold, not too timid."

# For TWO_CLAUSE: "Two-clause comparison and conjunction reasoning"
TWO_CLAUSE_VOICE = "Grug. Two sides to consider. Grug hold them both up and see how they relate. Comparison reveals what either side alone cannot show."

# For NO_PROMPT nodes
NO_PROMPT_VOICE = "Grug. Grug sit with the question. Something stirs in the knowing. Grug will speak what rises up."

# ─── VOICE REGISTER DEFAULTS ───
# For nodes missing voice_register
REGISTER_DEFAULTS = {
    'ARITHMETIC': 'terse',
    'SCIENTIFIC': 'explanatory',
    'SURVIVAL': 'alert',
    'SOCIAL': 'warm',
    'COMPUTE': 'terse',
    'STEPS': 'imperative',
    'GENERIC_TAUGHT': 'explanatory',
    'DEFINE_TAUGHT': 'terse',
    'REASON_TAUGHT': 'plain',
    'WARN_TAUGHT': 'terse',
    'ACKNOWLEDGE_TAUGHT': 'warm',
    'TEMPORAL': 'plain',
    'RELATIONSHIP': 'plain',
    'SIGIL_CAUSAL': 'plain',
    'SIGIL_EMOTIONAL': 'warm',
    'SIGIL_SPATIAL': 'plain',
    'SIGIL_SIMILARITY': 'plain',
    'SIGIL_POSSESSIVE': 'plain',
    'PLAIN_KNOWLEDGE': 'plain',
    'DANGER': 'terse',
    'DEFINE': 'terse',
    'STRUCTURED': 'terse',
    'MULTI_RESPOND': 'plain',
    'MULTI_CLAUSE': 'multi',
    'ACTION': 'imperative',
    'GREETING': 'warm',
    'LINGUISTIC': 'explanatory',
    'CAUSAL_ANALYSIS': 'plain',
    'LOGICAL_ANALYSIS': 'plain',
    'ARITHMETIC_REASONING': 'terse',
    'ARITHMETIC_MULTI': 'terse',
    'NEGATIVE_POLARITY': 'cautious',
    'POSITIVE_POLARITY': 'confident',
    'NEUTRAL_POLARITY': 'reflective',
    'TWO_CLAUSE': 'multi',
    'NO_PROMPT': 'plain',
}

# ─── FRAME HINTS DEFAULTS ───
FRAME_HINTS_DEFAULTS = {
    'ARITHMETIC': ['imperative', 'plain'],
    'SCIENTIFIC': ['exploratory', 'plain'],
    'SURVIVAL': ['imperative', 'terse'],
    'SOCIAL': ['warm', 'plain'],
    'COMPUTE': ['imperative', 'plain'],
    'STEPS': ['imperative', 'plain'],
    'GENERIC_TAUGHT': ['exploratory', 'plain'],
    'DEFINE_TAUGHT': ['imperative', 'plain'],
    'REASON_TAUGHT': ['plain', 'exploratory'],
    'WARN_TAUGHT': ['imperative', 'terse'],
    'ACKNOWLEDGE_TAUGHT': ['warm', 'de-escalating'],
    'TEMPORAL': ['plain', 'exploratory'],
    'RELATIONSHIP': ['plain', 'exploratory'],
    'SIGIL_CAUSAL': ['plain', 'exploratory'],
    'SIGIL_EMOTIONAL': ['warm', 'exploratory'],
    'SIGIL_SPATIAL': ['plain', 'exploratory'],
    'SIGIL_SIMILARITY': ['plain', 'exploratory'],
    'SIGIL_POSSESSIVE': ['plain', 'exploratory'],
    'PLAIN_KNOWLEDGE': ['plain', 'exploratory'],
    'DANGER': ['imperative', 'terse'],
    'DEFINE': ['imperative', 'plain'],
    'STRUCTURED': ['imperative', 'plain'],
    'MULTI_RESPOND': ['plain', 'exploratory'],
    'MULTI_CLAUSE': ['exploratory', 'plain'],
    'ACTION': ['imperative', 'plain'],
    'GREETING': ['warm', 'plain'],
    'LINGUISTIC': ['exploratory', 'plain'],
    'CAUSAL_ANALYSIS': ['plain', 'exploratory'],
    'LOGICAL_ANALYSIS': ['plain', 'exploratory'],
    'ARITHMETIC_REASONING': ['imperative', 'plain'],
    'ARITHMETIC_MULTI': ['imperative', 'plain'],
    'NEGATIVE_POLARITY': ['cautious', 'plain'],
    'POSITIVE_POLARITY': ['affirmative', 'plain'],
    'NEUTRAL_POLARITY': ['reflective', 'plain'],
    'TWO_CLAUSE': ['comparative', 'plain'],
    'NO_PROMPT': ['plain', 'exploratory'],
}

# ─── NOUN ANCHOR DERIVATION ───
# For nodes missing noun_anchors, derive from system_prompt or category
def derive_noun_anchors(sp, category, existing_na):
    """Extract key nouns from system_prompt for noun_anchors."""
    if existing_na:
        return existing_na  # Already has anchors
    
    # Use the possibly-patched system_prompt for derivation
    # Try to extract from the system_prompt
    # For SIGIL nodes: already have anchors from original, check current
    m = re.search(r'I know (?:that )?(\w+)\s+(?:&\w+|\w+)\s+(\w[\w\s]*?)\.', sp)
    if m:
        return [m.group(1).lower(), m.group(2).strip().lower()]
    
    # For dereferenced sigil nodes: "X [rel] Y." at start of voice
    m = re.match(r'Grug\.\s+(\w+)\s+(comes before|leads to|feels toward|sits near|is like|has)\s+(\w[\w\s]*?)\.', sp)
    if m:
        return [m.group(1).lower(), m.group(3).strip().lower()]
    
    # For STEPS nodes: "Step X of Y for TASK: ACTION" → [task keyword, action keyword]
    # Match both original format and patched format
    m = re.search(r'Step \d+ of \d+ for (\w[\w\s]*?):\s*(\w[\w\s]*?)(?:\.|$)', sp)
    if m:
        task = m.group(1).strip().lower()
        action = m.group(2).strip().lower()
        # Take last meaningful word from task and first from action
        task_words = [w for w in task.split() if len(w) > 2]
        action_words = [w for w in action.split() if len(w) > 2]
        if task_words and action_words:
            return [task_words[-1], action_words[0]]
        elif task_words:
            return task_words[:2] if len(task_words) >= 2 else task_words[:1] + ['step']
        else:
            return ['task', 'step']
    
    # For COMPUTE nodes with numbers in the original pattern
    m = re.search(r'(\d+)\s*(plus|minus|times|divided)\s*(\d+)', sp)
    if m:
        return [m.group(1), m.group(3)]
    
    # For RELATIONSHIP: "X verbs Y"
    m = re.match(r'Grug\.\s+(\w+)\s+(\w+)\s+(\w[\w\s]*?)\.\s+Every thing touches', sp)
    if m:
        return [m.group(1).lower(), m.group(3).strip().lower()]
    
    # For PLAIN_KNOWLEDGE: "X is a Y"
    m = re.match(r'Grug\.\s+(\w+)\s+is\s+a\s+(\w+.*?)\.', sp)
    if m:
        return [m.group(1).lower(), m.group(2).strip().lower()]
    
    # Category-based defaults
    category_anchors = {
        'ARITHMETIC': ['numbers', 'calculation'],
        'SCIENTIFIC': ['observation', 'pattern'],
        'SURVIVAL': ['danger', 'shelter'],
        'SOCIAL': ['clan', 'bond'],
        'GENERIC_TAUGHT': ['knowledge', 'teaching'],
        'DEFINE_TAUGHT': ['definition', 'meaning'],
        'REASON_TAUGHT': ['reason', 'understanding'],
        'WARN_TAUGHT': ['danger', 'warning'],
        'ACKNOWLEDGE_TAUGHT': ['care', 'acknowledgment'],
        'DANGER': ['threat', 'warning'],
        'DEFINE': ['word', 'meaning'],
        'STRUCTURED': ['fact', 'structure'],
        'MULTI_RESPOND': ['answer', 'perspective'],
        'MULTI_CLAUSE': ['clause', 'connection'],
        'ACTION': ['action', 'deed'],
        'GREETING': ['friend', 'welcome'],
        'LINGUISTIC': ['language', 'pattern'],
        'CAUSAL_ANALYSIS': ['cause', 'effect'],
        'LOGICAL_ANALYSIS': ['logic', 'structure'],
        'ARITHMETIC_REASONING': ['number', 'reasoning'],
        'ARITHMETIC_MULTI': ['operation', 'sequence'],
        'NEGATIVE_POLARITY': ['caution', 'doubt'],
        'POSITIVE_POLARITY': ['confidence', 'certainty'],
        'NEUTRAL_POLARITY': ['measure', 'hedge'],
        'TWO_CLAUSE': ['comparison', 'conjunction'],
        'NO_PROMPT': ['question', 'wonder'],
    }
    return category_anchors.get(category, ['knowledge', 'grug'])


def classify_node(sp):
    """Classify a node by its system_prompt pattern."""
    if not sp:
        return 'NO_PROMPT'
    if 'Arithmetic reasoning engine active' in sp:
        return 'ARITHMETIC'
    if 'Scientific analysis engine active' in sp:
        return 'SCIENTIFIC'
    if 'Survival analysis engine active' in sp:
        return 'SURVIVAL'
    if 'Social reasoning engine active' in sp:
        return 'SOCIAL'
    if sp == 'Grug. I learned this from a question. I explain what I was taught clearly.':
        return 'GENERIC_TAUGHT'
    if 'I learned this from a question. I warn about' in sp:
        return 'WARN_TAUGHT'
    if 'I learned this from a question. I acknowledge' in sp:
        return 'ACKNOWLEDGE_TAUGHT'
    if 'I learned this from a question. I define what I was taught precisely' in sp:
        return 'DEFINE_TAUGHT'
    if 'I learned this from a question. I define what I was taught precisely' in sp:
        return 'DEFINE_TAUGHT'
    if 'I learned this from a question. I reason about' in sp:
        return 'REASON_TAUGHT'
    if 'I learned this from a question about time' in sp:
        return 'TEMPORAL'
    if 'I learned this from a question about relationships' in sp:
        return 'RELATIONSHIP'
    if 'I learned this from a question about survival' in sp:
        return 'SURVIVAL_Q'
    if 'I follow steps' in sp:
        return 'STEPS'
    if 'I know' in sp and '&' in sp:
        m = re.search(r'&(\w+)', sp)
        return f'SIGIL_{m.group(1).upper()}' if m else 'SIGIL_UNKNOWN'
    if 'I know about' in sp:
        return 'PLAIN_KNOWLEDGE'
    if 'I compute' in sp:
        return 'COMPUTE'
    if 'I provide structured' in sp:
        return 'STRUCTURED'
    if 'I define and explain' in sp:
        return 'DEFINE'
    if 'I respond in multiple' in sp:
        return 'MULTI_RESPOND'
    if 'I recognize danger' in sp:
        return 'DANGER'
    if 'Action resolution' in sp or 'Action execution' in sp:
        return 'ACTION'
    if 'Highly polite greeting' in sp:
        return 'GREETING'
    if 'Linguistic analysis engine' in sp:
        return 'LINGUISTIC'
    if 'Causal relational analysis' in sp:
        return 'CAUSAL_ANALYSIS'
    if 'Cold logical analysis' in sp:
        return 'LOGICAL_ANALYSIS'
    if sp == 'Arithmetic reasoning voice':
        return 'ARITHMETIC_REASONING'
    if 'Arithmetic reasoning voice' in sp:
        return 'ARITHMETIC_MULTI'
    if 'Negative polarity gate' in sp:
        return 'NEGATIVE_POLARITY'
    if 'Positive polarity gate' in sp:
        return 'POSITIVE_POLARITY'
    if 'Neutral polarity gate' in sp:
        return 'NEUTRAL_POLARITY'
    if 'Two-clause comparison' in sp:
        return 'TWO_CLAUSE'
    if 'Multi-clause reasoning' in sp:
        return 'MULTI_CLAUSE'
    return 'OTHER'


def pick_voice(voices, nid, counter=None):
    """Pick a voice from a list, using node_id hash for determinism."""
    idx = hash(nid) % len(voices)
    return voices[idx]


def patch_system_prompt(sp, category, nid):
    """Patch a system_prompt based on its category."""
    # Category-specific patchers that need the full prompt
    if category == 'SIGIL_TEMPORAL' or category == 'TEMPORAL':
        result = patch_temporal(sp, [], nid)
        if result: return result
        result = patch_sigil_knowledge(sp, [], nid)
        if result: return result
    
    if category.startswith('SIGIL_'):
        result = patch_sigil_knowledge(sp, [], nid)
        if result: return result
    
    if category == 'RELATIONSHIP':
        result = patch_relationship(sp, [], nid)
        if result: return result
    
    if category == 'STEPS':
        result = patch_steps(sp, [], nid)
        if result: return result
    
    if category == 'PLAIN_KNOWLEDGE':
        result = patch_plain_knowledge(sp, [], nid)
        if result: return result
    
    # Categories that map to fixed voice lists
    voice_map = {
        'GENERIC_TAUGHT': GENERIC_TAUGHT_VOICES,
        'DEFINE_TAUGHT': DEFINE_TAUGHT_VOICES,
        'REASON_TAUGHT': REASON_TAUGHT_VOICES,
        'WARN_TAUGHT': WARN_TAUGHT_VOICES,
        'ACKNOWLEDGE_TAUGHT': ACKNOWLEDGE_TAUGHT_VOICES,
        'ARITHMETIC': ARITHMETIC_VOICES,
        'SCIENTIFIC': SCIENTIFIC_VOICES,
        'SURVIVAL': SURVIVAL_VOICES,
        'SOCIAL': SOCIAL_VOICES,
        'COMPUTE': COMPUTE_VOICES,
        'DANGER': DANGER_VOICES,
        'DEFINE': DEFINE_VOICES,
        'STRUCTURED': STRUCTURED_VOICES,
        'MULTI_RESPOND': MULTI_RESPOND_VOICES,
        'MULTI_CLAUSE': MULTI_CLAUSE_VOICES,
        'ACTION': ACTION_VOICES,
        'LINGUISTIC': LINGUISTIC_VOICES,
        'ARITHMETIC_REASONING': ARITHMETIC_REASONING_VOICES,
        'ARITHMETIC_MULTI': ARITHMETIC_MULTI_VOICES,
        'NO_PROMPT': [NO_PROMPT_VOICE],
    }
    
    if category in voice_map:
        return pick_voice(voice_map[category], nid)
    
    # Special single-voice categories
    if category == 'GREETING':
        return GREETING_VOICE
    if category == 'CAUSAL_ANALYSIS':
        return CAUSAL_ANALYSIS_VOICE
    if category == 'LOGICAL_ANALYSIS':
        return LOGICAL_ANALYSIS_VOICE
    if category == 'NEGATIVE_POLARITY':
        return NEGATIVE_POLARITY_VOICE
    if category == 'POSITIVE_POLARITY':
        return POSITIVE_POLARITY_VOICE
    if category == 'NEUTRAL_POLARITY':
        return NEUTRAL_POLARITY_VOICE
    if category == 'TWO_CLAUSE':
        return TWO_CLAUSE_VOICE
    
    # SURVIVAL_Q: similar to relationship but about survival
    if category == 'SURVIVAL_Q':
        m = re.match(r'Grug\.\s*I learned this from a question about survival\.\s*I know that (.+?)\.\s*I reason about (.+?)\.', sp)
        if m:
            fact, domain = m.group(1), m.group(2)
            return f"Grug. {fact}. Survival is the first law. Grug know what keeps the clan alive and Grug remember it well."
        return pick_voice(SURVIVAL_VOICES, nid)
    
    # If nothing matched, check for sigils still present and dereference them
    if '&' in sp:
        for sigil, replacement in SIGIL_DEREF.items():
            sp = sp.replace(sigil, replacement)
        return sp
    
    # If the prompt is already decent (has multiple sentences with substance), keep it
    sentences = [s.strip() for s in sp.split('.') if s.strip()]
    if len(sentences) >= 3:
        return sp
    
    # Last resort: if it's a thin prompt, add substance
    return sp + " Grug speak from what Grug know. The truth is the foundation."


def main():
    input_path = '/workspace/grugbot420/comprehensive_specimen_v758_tested.json'
    output_path = '/workspace/grugbot420/comprehensive_specimen_v758_patched.json'
    
    with open(input_path) as f:
        data = json.load(f)
    
    nodes = data.get('nodes', [])
    print(f"Loaded {len(nodes)} nodes from {input_path}")
    
    stats = {
        'total': len(nodes),
        'prompt_patched': 0,
        'sigil_derefed': 0,
        'na_added': 0,
        'vr_added': 0,
        'fh_added': 0,
    }
    
    for n in nodes:
        jd = n.get('json_data', {})
        nid = n.get('id', '?')
        sp = jd.get('system_prompt', '')
        na = jd.get('noun_anchors', [])
        vr = jd.get('voice_register', '')
        fh = jd.get('frame_hints', [])
        
        category = classify_node(sp)
        
        # 1. Fix sigils in system_prompt
        had_sigils = '&' in sp
        
        # 2. Patch system_prompt if needed
        needs_patch = False
        if not sp:
            needs_patch = True
        elif category in ['GENERIC_TAUGHT', 'DEFINE_TAUGHT', 'REASON_TAUGHT', 'WARN_TAUGHT', 
                          'ACKNOWLEDGE_TAUGHT', 'ARITHMETIC', 'SCIENTIFIC', 'SURVIVAL', 'SOCIAL',
                          'NO_PROMPT', 'ARITHMETIC_REASONING', 'ARITHMETIC_MULTI',
                          'LINGUISTIC', 'GREETING']:
            needs_patch = True
        elif had_sigils:
            needs_patch = True
        elif category in ['DANGER', 'DEFINE', 'STRUCTURED', 'MULTI_RESPOND', 'MULTI_CLAUSE',
                          'ACTION', 'CAUSAL_ANALYSIS', 'LOGICAL_ANALYSIS', 'NEGATIVE_POLARITY',
                          'POSITIVE_POLARITY', 'NEUTRAL_POLARITY', 'TWO_CLAUSE', 'SURVIVAL_Q']:
            needs_patch = True
        elif category == 'COMPUTE' and len([s for s in sp.split('.') if s.strip()]) < 4:
            needs_patch = True
        elif category == 'STEPS' and 'One thing at a time' not in sp:
            needs_patch = True
        elif category == 'PLAIN_KNOWLEDGE' and 'Grug know this because' not in sp:
            needs_patch = True
        elif category == 'TEMPORAL' and '&' in sp:
            needs_patch = True
        elif category == 'RELATIONSHIP' and 'Every thing touches' not in sp:
            needs_patch = True
        
        if needs_patch:
            new_sp = patch_system_prompt(sp, category, nid)
            if new_sp != sp:
                jd['system_prompt'] = new_sp
                stats['prompt_patched'] += 1
                if had_sigils:
                    stats['sigil_derefed'] += 1
        
        # 3. Add missing noun_anchors
        if not na:
            new_na = derive_noun_anchors(sp if not needs_patch else jd.get('system_prompt', sp), 
                                         category, na)
            if new_na:
                jd['noun_anchors'] = new_na
                stats['na_added'] += 1
        
        # 4. Add missing voice_register
        if not vr:
            default_vr = REGISTER_DEFAULTS.get(category, 'plain')
            jd['voice_register'] = default_vr
            stats['vr_added'] += 1
        
        # 5. Add missing frame_hints
        if not fh:
            default_fh = FRAME_HINTS_DEFAULTS.get(category, ['plain', 'exploratory'])
            jd['frame_hints'] = default_fh
            stats['fh_added'] += 1
        
        n['json_data'] = jd
    
    data['nodes'] = nodes
    
    # Save patched specimen
    with open(output_path, 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"\nPatching complete!")
    print(f"  Total nodes: {stats['total']}")
    print(f"  System prompts patched: {stats['prompt_patched']}")
    print(f"  Sigils dereferenced: {stats['sigil_derefed']}")
    print(f"  Noun anchors added: {stats['na_added']}")
    print(f"  Voice registers added: {stats['vr_added']}")
    print(f"  Frame hints added: {stats['fh_added']}")
    print(f"\nSaved to: {output_path}")
    
    # Verification pass
    print("\n--- Verification ---")
    sigils_remaining = 0
    missing_vb = 0
    missing_na = 0
    missing_vr = 0
    missing_fh = 0
    
    for n in nodes:
        jd = n.get('json_data', {})
        sp = jd.get('system_prompt', '')
        na = jd.get('noun_anchors', [])
        vr = jd.get('voice_register', '')
        fh = jd.get('frame_hints', [])
        
        if '&' in sp:
            sigils_remaining += 1
            print(f"  WARNING: Sigils still in {n['id']}: {sp[:80]}")
        
        # Check voice_body (derived from system_prompt)
        sentences = [s.strip() for s in sp.split('.') if s.strip()]
        has_voice_body = len(sentences) >= 2
        if not has_voice_body:
            missing_vb += 1
            print(f"  WARNING: No voice_body for {n['id']}: {sp[:80]}")
        
        if not na:
            missing_na += 1
        if not vr:
            missing_vr += 1
        if not fh:
            missing_fh += 1
    
    print(f"\nSigils remaining in system_prompts: {sigils_remaining}")
    print(f"Nodes still missing voice_body: {missing_vb}")
    print(f"Nodes still missing noun_anchors: {missing_na}")
    print(f"Nodes still missing voice_register: {missing_vr}")
    print(f"Nodes still missing frame_hints: {missing_fh}")


if __name__ == '__main__':
    main()
