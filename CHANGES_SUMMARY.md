# GrugBot420 - Documentation Update Summary

**Date:** Session continuation from previous context
**Repository:** https://github.com/grug-group420/grugbot420

---

## What Was Added (This Session - Documentation Audit v7.7)

### Documentation Changes

#### Files Modified:

1. **`README.md`**
   - Updated specimen persistence table from 17 to 21 state categories (v2.4)
   - Added `eye_state` (11.5) and `last_voters` (12.5) categories
   - Added `immune_system` (18) and `aiml_system` (19) categories
   - Updated restore order to include all 21 categories
   - Added **Admin Commands** section (`/login`, `/logout`, `/writeSave`)

2. **`wiki-content/Specimen-Persistence.md`**
   - Updated from 17 to 21 state categories (v2.4)
   - Added all missing categories with descriptions
   - Updated restore order

3. **`wiki-content/CLI-Command-Reference.md`**
   - Added **Admin Commands** section with `/login`, `/logout`, `/writeSave`

4. **`wiki-content/Home.md`**
   - Added AIML Tribes and Immune System to Core Concepts

5. **`grugbot_whitepaper.html`**
   - Updated title to v7.7
   - Updated specimen persistence table from 13 to 21 categories
   - Added `eye_state`, `last_voters`, `immune_system`, `aiml_system` categories
   - Added **Admin Commands** section to CLI reference
   - Updated processing details (all 21 categories, restore order)
   - Added v7.6 and v7.7 changelog entries
   - Updated TOC badges

---

## New State Categories (v2.4)

| # | Category | Description |
|---|----------|-------------|
| 11.5 | **eye_state** | EyeSystem tracking — attention_enabled, blur_enabled, last centroid, last_arousal |
| 12.5 | **last_voters** | LAST_VOTER_IDS — node IDs that voted in last cycle (for /wrong feedback) |
| 18 | **immune_system** | ImmuneSystem Hopfield memory + ledger — safe/funky signatures |
| 19 | **aiml_system** | AIMLNodeSystem per-lobe tribes — AIML nodes, templates, strength |

---

## Admin Commands (New)

| Command | Description |
|---------|-------------|
| `/login <password>` | Authenticate as admin. Session expires after 1 hour of inactivity. |
| `/logout` | End admin session. |
| `/writeSave <filepath> <json>` | Append validated JSON to an existing save file. **Requires admin login.** |

**Default admin password:** `grug_cave_master_420` (change `ADMIN_PASSWORD_HASH` before deployment!)

---

# GrugBot420 - Documentation Update Summary

**Date:** Session continuation from previous context
**Repository:** https://github.com/grug-group420/grugbot420

---

## What Was Added (Previous Session)

### Code Changes (Commit: `c233091`)

**Feature:** AIML Node System with per-lobe tribes and grave exclusion from population caps

#### Files Modified:

1. **`src/AIMLNodeSystem.jl`**
   - Added `get_alive_population_size(lobe_id::String)::Int` function
   - Returns count of ALIVE nodes only (excludes graves)
   - Modified cap check in `add_aiml_node!` to use alive count instead of total count
   - Export: `get_alive_population_size`

2. **`src/engine.jl`**
   - Added `count_alive_nodes_in_lobe(lobe_id::String)::Int` helper function
   - Counts non-grave nodes in a lobe for cap enforcement

3. **`src/Lobe.jl`**
   - Modified `add_node_to_lobe!()` to accept `alive_count` parameter
   - Cap check uses `effective_count` (alive nodes only when provided)

4. **`src/Main.jl`**
   - Updated call site to pass `alive_count` to `add_node_to_lobe!`

5. **`test/test_aiml_node_system.jl`**
   - Added test section [4b] for grave exclusion from caps
   - Tests: 3 alive + 1 grave in cap=3 lobe (should work)
   - Tests: 4th alive node correctly rejected

---

## What Was Added (This Session)

### Documentation Changes (Commit: `cd48fb6`)

#### Files Modified:

1. **`README.md`**
   - Added new "## AIML Node System" section
   - Documents: per-lobe tribes, population caps, grave exclusion
   - Includes API function table and code example

2. **`docs/src/api.md`**
   - Added "## AIML Node System (`AIMLNodeSystem`)" section
   - Full API reference for all 6 functions
   - AIMLNode struct definition
   - Population cap enforcement rules
   - Thread safety notes
   - Error type reference

3. **`docs/src/architecture.md`**
   - Added AIML Node System to subsystems table
   - Added dedicated "## AIML Node System" section
   - Documents: per-lobe tribes, grave exclusion design, cycle-aware reinforcement
   - Added `AIMLNodeSystem.jl` to File Reference table

---

### Documentation Changes (This Session - Round 2)

#### Files Modified:

1. **`grugbot_whitepaper.html`**
   - Added "8.5 AIML Node System: Per-Lobe Tribes" section to table of contents
   - Added full section with:
     - Per-lobe tribes explanation
     - Population cap with grave exclusion
     - AIMLNode structure table
     - API reference table
     - Thread safety notes
   - Version badge: v7.6

2. **`docs/src/index.md`**
   - Added AIML Node System to features list

---

## Key Concepts Documented

### Per-Lobe Tribes
- Each lobe has its own AIML node registry (a "tribe")
- Tribes are isolated from each other
- Population cap = `node_cap ÷ 3`

### Grave Exclusion from Caps
- **Graves don't count towards population caps**
- `get_alive_population_size()` returns only alive nodes
- Prevents "cap lock" where dead nodes block new growth
- Design principle: "graves are memory, not bloat"

### Strength Bounds (Already Implemented)
- **Floor:** `0.0` — triggers grave state (permanent death marker)
- **Ceiling:** `10.0` — hard cap to prevent runaway strength
- **Default initial:** `5.0` (middle of range)
- **Delta per tick:** `1.0` (controlled increments)
- Enforced via `clamp()` in `_apply_strength_delta!`

### API Functions
| Function | Purpose |
|----------|---------|
| `register_lobe!(lobe_id, node_cap)` | Register lobe for AIML |
| `add_aiml_node!(lobe_id, node_id, template_id)` | Add AIML node to tribe |
| `get_aiml_node(lobe_id, node_id)` | Retrieve AIML node |
| `get_population_size(lobe_id)` | Total count (includes graves) |
| `get_alive_population_size(lobe_id)` | Alive count only |
| `remove_aiml_node!(lobe_id, node_id)` | Remove from tribe |

### Constants
| Constant | Value | Purpose |
|----------|-------|---------|
| `AIML_STRENGTH_CAP` | 10.0 | Maximum strength (ceiling) |
| `AIML_STRENGTH_FLOOR` | 0.0 | Minimum strength (triggers grave) |
| `AIML_POPULATION_CAP_RATIO` | 3 | Pop cap = lobe_cap ÷ 3 |
| `AIML_STRENGTH_DELTA` | 1.0 | Strength change per tick |

---

## Remaining Tasks

- [x] Update `grugbot_whitepaper.html` with AIML Node System section
- [x] Check `docs/src/index.md` for references
- [x] Commit and push all remaining documentation

---

## Git Log

```
3d256c0 docs: add AIML Node System to whitepaper and index
cd48fb6 docs: add AIML Node System documentation
c233091 feat(aiml): exclude grave nodes from population caps
832dc1a fix(tests): use pipe-delimited action_packet format in test_comprehensive.jl
202fe95 feat: lobe-specific AIML node tribes with cycle-aware reinforcement
```

---

## Summary

All documentation has been updated to reflect the new AIML Node System features:

1. **Code** (commit c233091): Per-lobe tribes with grave exclusion from caps
2. **README.md** (commit cd48fb6): New section with API overview and examples
3. **docs/src/api.md** (commit cd48fb6): Full API reference
4. **docs/src/architecture.md** (commit cd48fb6): Architecture overview
5. **grugbot_whitepaper.html** (commit 3d256c0): Section 8.5 with full documentation
6. **docs/src/index.md** (commit 3d256c0): Added to features list