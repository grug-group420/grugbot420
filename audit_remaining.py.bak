"""Second-pass audit: look for remaining elevated synonyms that could decohere grug voice
when swapped in during _light_thesaurus_touch or _pick_synonym calls.
"""

# Borderline words that are still questionable for grug-voice
BORDERLINE = {
    # Elevated literary
    "anguish", "despair", "heartbreak", "heartache",
    # Academic
    "assess", "evaluate", "investigate", 
    # Formal
    "confront", "resist",
    # Corporate
    "commit",
    # Spiritual
    "meditate",
    # Overly specific
    "jeopardy", "menace",
    # Elevated adjectives
    "stunning", "radiant",
    # High-register
    "virtue", "endurance", "persistence",
    # Academic math
    "topology",
    # Formal
    "affirm",
    # Still elevated
    "fancy", "originality",
}

import re

with open("/workspace/grugbot420/src/Thesaurus.jl", "r") as f:
    content = f.read()

pattern = r'\("(\w+)",\s*\[([^\]]+)\]\)'
entries = re.findall(pattern, content)

flagged = []
for canonical, syns_str in entries:
    syns = [s.strip().strip('"') for s in syns_str.split(",")]
    bad_syns = [s for s in syns if s.lower() in BORDERLINE]
    if bad_syns:
        good_syns = [s for s in syns if s.lower() not in BORDERLINE]
        flagged.append((canonical, bad_syns, good_syns, syns))

print(f"Entries with borderline synonyms: {len(flagged)}")
for canonical, bad, good, all_syns in sorted(flagged):
    print(f'  ("{canonical}", [...]) — borderline: {bad}')
