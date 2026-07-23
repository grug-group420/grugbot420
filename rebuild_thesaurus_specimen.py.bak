#!/usr/bin/env python3
"""
Rebuild specimen thesaurus_seeds from cleaned Thesaurus.jl
===========================================================
Reads _SEED_SYNONYMS_RAW from Thesaurus.jl, builds the full bidirectional
map (same as Julia's _build_seed_map!), and writes it into the specimen.
"""

import json
import re
import copy
import shutil

SPECIMEN_SRC = "/workspace/grugbot420/comprehensive_specimen_v758_patched.json"
SPECIMEN_DST = "/workspace/grugbot420/comprehensive_specimen_v758_patched.json"  # in-place
THESAURUS_FILE = "/workspace/grugbot420/src/Thesaurus.jl"

def parse_synonyms_from_jl(filepath):
    """Parse _SEED_SYNONYMS_RAW entries from Thesaurus.jl"""
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Match active (non-commented) synonym entries:
    # ("canonical", ["syn1", "syn2", ...])
    # Skip lines starting with # (comments)
    pattern = r'^\s*\("(\w+)",\s*\[([^\]]+)\]\)'
    
    entries = []
    for line in content.split('\n'):
        # Skip comment-only lines
        stripped = line.strip()
        if stripped.startswith('#') or stripped.startswith(']'):
            continue
        m = re.match(pattern, line)
        if m:
            canonical = m.group(1).lower().strip()
            syns_str = m.group(2)
            syns = [s.strip().strip('"').lower() for s in syns_str.split(',') if s.strip().strip('"')]
            entries.append((canonical, syns))
    
    return entries

def build_bidirectional_map(entries):
    """Build full bidirectional map (same as Julia's _build_seed_map!)"""
    seed_map = {}
    
    for canonical, synonyms in entries:
        can = canonical.lower().strip()
        syns = set(s.lower().strip() for s in synonyms)
        
        # canonical -> all its synonyms
        if can not in seed_map:
            seed_map[can] = set()
        seed_map[can].update(syns)
        
        # each synonym -> canonical AND all other synonyms (full bidirectional)
        for syn in syns:
            if syn not in seed_map:
                seed_map[syn] = set()
            seed_map[syn].add(can)
            seed_map[syn].update(syns)
            seed_map[syn].discard(syn)  # remove self
    
    return seed_map

def main():
    # Parse Thesaurus.jl
    entries = parse_synonyms_from_jl(THESAURUS_FILE)
    print(f"Parsed {len(entries)} active synonym entries from Thesaurus.jl")
    
    # Build bidirectional map
    seed_map = build_bidirectional_map(entries)
    print(f"Bidirectional map: {len(seed_map)} words, {sum(len(v) for v in seed_map.values())} total synonym links")
    
    # Convert sets to sorted lists for JSON
    seed_map_json = {k: sorted(list(v)) for k, v in sorted(seed_map.items())}
    
    # Load specimen
    with open(SPECIMEN_SRC, 'r') as f:
        specimen = json.load(f)
    
    old_count = len(specimen.get('thesaurus_seeds', {}))
    old_links = sum(len(v) for v in specimen.get('thesaurus_seeds', {}).values())
    print(f"Old thesaurus_seeds: {old_count} words, {old_links} synonym links")
    
    # Backup and replace
    specimen['thesaurus_seeds'] = seed_map_json
    
    new_count = len(seed_map_json)
    new_links = sum(len(v) for v in seed_map_json.values())
    print(f"New thesaurus_seeds: {new_count} words, {new_links} synonym links")
    
    # Check for removed words
    old_words = set(specimen.get('thesaurus_seeds', {}).keys()) if old_count > 0 else set()
    # Re-read old for comparison
    with open(SPECIMEN_SRC, 'r') as f:
        old_spec = json.load(f)
    old_words = set(old_spec.get('thesaurus_seeds', {}).keys())
    new_words = set(seed_map_json.keys())
    removed = old_words - new_words
    added = new_words - old_words
    print(f"Removed words: {len(removed)}")
    print(f"Added words: {len(added)}")
    
    # List critical removed words
    CRITICAL_REMOVED = {"rationale", "shall", "deduction", "inference", "proposition",
                        "corollary", "differential", "marginal", "summation", "aggregate",
                        "accumulation", "conceptual", "hypothetical", "fatalism",
                        "predestination", "inevitability", "necessity", "expression",
                        "equality", "identity", "mapping", "transformation", "topology",
                        "splendor", "magnificence", "exquisite", "everlasting", "eternal",
                        "perpetual", "immutable", "solace", "consolation", "valor",
                        "gallantry", "revered", "divine", "blessed", "envision", "conceive",
                        "chronicle", "inquiry", "principled", "virtuous", "honorable",
                        "upright", "investigation", "procedure", "deliberate", "verse",
                        "lyricism", "poetics", "meter"}
    
    found_critical = removed & CRITICAL_REMOVED
    if found_critical:
        print(f"  Critical removed: {sorted(found_critical)}")
    else:
        print("  No critical words found in removed set (may have already been gone)")
    
    # Save
    with open(SPECIMEN_DST, 'w') as f:
        json.dump(specimen, f, indent=2)
    
    print(f"\nSpecimen saved to {SPECIMEN_DST}")
    print("Done!")

if __name__ == "__main__":
    main()
