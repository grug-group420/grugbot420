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

## General

### QoL-002: (reserved for future entries)

---

## Conventions

- **QoL-NNN** numbering for cross-referencing
- **Status** tracks: [ ] Pending → [ ] In Progress → [x] Done
- Each entry is a single small change, not an architectural feature
- Architectural features go in their own plan docs in this folder
