"""Audit Thesaurus.jl for wrong-register synonyms that don't fit grug-voice.
Grug voice is simple, primal, caveman-like. Words like "rationale", "shall", 
"inference", "deduction" are academic/formal/archaic and decohere the voice.
"""

# Words that are WRONG register for grug-voice — too academic, archaic, formal, corporate
WRONG_REGISTER = {
    # From logic entry
    "rationale", "deduction", "inference",
    # From must entry
    "shall",
    # From experiment entry
    "investigation", "procedure",
    # From analyze entry
    "investigate",
    # From observe entry
    "measure", "detect", "monitor", "record",
    # From belief entry
    "conviction", "stance", "position",
    # From ethical entry
    "principled", "virtuous", "honorable", "upright",
    # From abstract entry
    "conceptual", "hypothetical",
    # From question entry
    "inquiry",
    # From compute entry
    "determine", "tally",
    # From derivative entry
    "differential", "marginal",
    # From integral entry
    "accumulation", "summation", "aggregate",
    # From theorem entry
    "proposition", "corollary",
    # From function entry
    "mapping", "transformation",
    # From equation entry
    "expression", "equality", "identity",
    # From number entry
    "quantity",
    # From survival entry
    "preservation",
    # From danger entry
    "peril", "jeopardy", "menace",
    # From concealment entry
    "camouflage",
    # From courage entry
    "valor", "gallantry", "fortitude",
    # From defend entry
    "safeguard", "secure",
    # From anxiety entry
    "apprehension",
    # From grief entry
    "mourning",
    # From comfort entry
    "solace", "consolation",
    # From feelings entry
    "sentiments",
    # From imagine entry
    "envision", "conceive",
    # From imagination entry
    "inventiveness", "fancy", "originality",
    # From poetry entry
    "verse", "lyricism", "poetics", "meter",
    # From story entry
    "narrative", "account", "chronicle",
    # From weave entry
    "intertwine", "braid",
    # From beauty entry
    "elegance", "splendor", "magnificence",
    # From beautiful entry
    "lovely", "gorgeous", "stunning", "exquisite", "radiant",
    # From explore entry
    "investigate", "delve", "chart",
    # From wonder entry
    "marvel", "amazement", "fascination",
    # From contemplate entry
    "meditate", "muse", "deliberate",
    # From meaning entry
    "purpose",
    # From existence entry
    "reality",
    # From sacred entry
    "revered", "divine", "blessed",
    # From permanent entry
    "enduring", "everlasting", "eternal", "perpetual", "immutable",
    # From determinism entry
    "fatalism", "predestination", "inevitability", "necessity",
    # From choose entry
    "select", "opt",
    # From choice entry
    "decision", "selection", "alternative", "preference",
    # From aware entry
    "mindful", "perceptive", "attentive",
    # From valid entry
    "legitimate", "warranted",
    # From time entry
    "instant", "epoch", "interval",
    # From past entry
    "bygone",
    # From memory entry
    "recollection", "remembrance", "retention",
    # From now entry
    "presently", "currently",
    # From recall entry
    "recollect", "retrieve", "summon",
    # From describe entry
    "depict", "portray", "characterize", "outline", "render",
    # From preserve entry
    "conserve", "safeguard", "maintain",
    # From engage entry
    "involve", "commit", "confront", "tackle",
    # From chaos entry
    "disorder", "turmoil", "entropy",
    # From capacity entry
    "capability", "faculty", "competence",
    # From absence entry
    "void", "dearth", "omission",
    # From quality entry
    "attribute", "characteristic", "trait",
    # From accumulate entry
    "amass", "compile",
    # From rate entry
    "velocity", "tempo",
    # From change entry
    "transformation", "alteration", "transition", "mutation",
    # From justified entry
    "warranted", "defensible",
    # From weakness entry
    "frailty", "deficiency", "shortcoming",
    # From information entry
    "insight", "facts",
    # From get entry
    "obtain", "acquire",
    # From find entry
    "locate",
    # From start entry
    "initiate", "launch",
    # From stop entry
    "cease",
    # From help entry
    "assist", "aid", "serve",
    # From need entry
    "require", "demand", "desire",
    # From show entry
    "display", "present", "reveal",
    # From try entry
    "attempt",
    # From move entry
    "transfer",
    # From send entry
    "transmit", "dispatch", "route", "forward",
    # From delete entry
    "erase", "purge", "wipe",
    # From learn entry
    "train", "adapt",
    # From predict entry
    "forecast", "estimate", "infer", "anticipate", "project",
    # From match entry
    "correspond",
    # From search entry
    "scan",
    # From store entry
    "archive",
    # From load entry
    "fetch",
}

print(f"Total wrong-register words identified: {len(WRONG_REGISTER)}")

# Now read Thesaurus.jl and flag entries
import re

with open("/workspace/grugbot420/src/Thesaurus.jl", "r") as f:
    content = f.read()

# Find all synonym entries
pattern = r'\("(\w+)",\s*\[([^\]]+)\]\)'
entries = re.findall(pattern, content)

flagged = []
for canonical, syns_str in entries:
    syns = [s.strip().strip('"') for s in syns_str.split(",")]
    bad_syns = [s for s in syns if s.lower() in WRONG_REGISTER]
    if bad_syns:
        flagged.append((canonical, bad_syns))

print(f"\nEntries with wrong-register synonyms: {len(flagged)}")
for canonical, bad in sorted(flagged):
    print(f'  ("{canonical}", [...]) — remove: {bad}')
