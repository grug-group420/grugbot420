# QoL Update List

Small quality-of-life improvements and fixes that aren't large architectural
changes. Things to knock out when doing a pass on the codebase.

---

## Image Pipeline

### QoL-001: 4-angle SDF comparison for image verification
**Status:** [ ] Pending  
**Area:** Image reaction / identification  
**Problem:** SDF parameter comparison between two images fails on rotational
mismatches. An upside-down cat vs a right-side-up cat produces the same SDF
topology but the distance metric says "no match" because the fields are
oriented differently in the comparison frame.  
**Fix:** At comparison time, rotate the query SDF at 0°, 90°, 180°, 270°
against the reference SDF and take the best score. Four dot products instead
of one — negligible cost on GPU since SDF parameterization is already
JIT-accelerated.  
**Notes:** 4 angles catches the vast majority of real cases (flipped, rotated,
mirrored). Finer grain (8 angles, continuous) possible but diminishing returns.
The shapes are the same — the comparison frame was just wrong.

---

## Pattern Bind

### QoL-002: Thesaurus-expanded input at pattern bind phase
**Status:** [ ] Pending  
**Area:** Pattern bind / user input processing  
**Problem:** Pattern bind runs user input as-is — one phrasing, one pass. If the
nodes don't match on that exact wording, you miss. "Big cat" and "large cat"
are the same sentence but only one door opens per pass.  
**Fix:** At pattern bind phase, run the user input through the thesaurus
(word-level synonym substitution only — no concept expansion, no intensity
relations, no semantic inference). Generate multiple rephrasings of the same
sentence and try each one. The meaning doesn't change — the input deforms to
fit the topology that's already there. Natural leverage: don't force the nodes
to handle every phrasing, let the query route to them.  
**Constraints:**
- Thesaurus is words only, not concepts. Matches only, not intensity relations.
- Each rephrasing gets its own thread through pattern bind (no cross-contamination
  between wordings). Results merge or compete downstream.
- Cap limit on number of variations per input. Prevents combinatorial explosion.
  Exact cap TBD — likely in the low single digits per word, total variations
  bounded by a small constant N.
- Only substitute words that contribute to coverage. Don't rephrase for no gain.

---

## General

### QoL-003: (reserved for future entries)

---

## Conventions

- **QoL-NNN** numbering for cross-referencing
- **Status** tracks: [ ] Pending → [ ] In Progress → [x] Done
- Each entry is a single small change, not an architectural feature
- Architectural features go in their own plan docs in this folder
