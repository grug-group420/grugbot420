"""Targeted audit: only flag synonyms that are CLEARLY wrong register for grug-voice.
Grug voice = caveman, primal, simple. The test output showed "rationale" for "logic" 
and "shall" for "must" as problems. We focus on:
1. Academic/formal jargon (rationale, deduction, inference, proposition, corollary)
2. Archaic words (shall, thereby, hence)
3. Corporate/bureaucratic jargon (procedure, investigation)
4. Overly elevated/precious language (splendor, magnificence, exquisite, gallantry)
5. Philosophical jargon (fatalism, predestination, necessity, conceptual, hypothetical)
"""

CLEARLY_WRONG = {
    # Academic logic/reasoning terms
    "rationale", "deduction", "inference", "proposition", "corollary",
    # Archaic/formal
    "shall",
    # Corporate/bureaucratic
    "procedure", "investigation",
    # Philosophical jargon
    "fatalism", "predestination", "inevitability", "necessity",
    "conceptual", "hypothetical",
    # Overly elevated/precious
    "splendor", "magnificence", "exquisite", "gallantry", "valor",
    "everlasting", "eternal", "perpetual", "immutable",
    "solace", "consolation",
    # High-register academic
    "differential", "marginal", "summation", "aggregate",
    "mapping", "transformation", "expression", "equality", "identity",
    # Archaic religious
    "revered", "divine", "blessed",
    # Overly formal verbs
    "deliberate", "conceive", "envision",
    # Literary/archaic narrative
    "chronicle",
    # Academic perception
    "inquiry",
    # Formal ethics
    "principled", "virtuous", "honorable", "upright",
    # Academic math
    "lyricism", "poetics", "meter",
}

import re

with open("/workspace/grugbot420/src/Thesaurus.jl", "r") as f:
    content = f.read()

pattern = r'\("(\w+)",\s*\[([^\]]+)\]\)'
entries = re.findall(pattern, content)

flagged = []
for canonical, syns_str in entries:
    syns = [s.strip().strip('"') for s in syns_str.split(",")]
    bad_syns = [s for s in syns if s.lower() in CLEARLY_WRONG]
    if bad_syns:
        # What remains after removal?
        good_syns = [s for s in syns if s.lower() not in CLEARLY_WRONG]
        flagged.append((canonical, bad_syns, good_syns, syns))

print(f"Entries with clearly wrong-register synonyms: {len(flagged)}")
print()
for canonical, bad, good, all_syns in sorted(flagged):
    if good:
        print(f'  ("{canonical}", [{", ".join(repr(s) for s in good)}])  # REMOVE: {bad}')
    else:
        print(f'  # ("{canonical}", [...]) — ALL SYNONYMS WRONG, COMMENT OUT ENTIRE ENTRY')
        print(f'  # Original: {all_syns}')
