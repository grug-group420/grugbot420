# QoL Sweep — 2025 Audit

This document captures every petty-but-real friction point found during the
hardcore-specimen build + conversation test, plus systematic codebase scan.
Each entry has: **Issue**, **Evidence**, **Severity**, **Fix**.

---

## CONFIRMED BUGS (found during silence-bug investigation)

### BUG-001: `MESSAGE_LOCK` typo — pinned memory citation broken everywhere
- **File:** `src/Main.jl:1556`
- **Symptom:** `UndefVarError(:MESSAGE_LOCK)` thrown on every `/mission`,
  swallowed by surrounding `catch` block, silently disabling pinned-memory
  citation in synthesis.
- **Severity:** HIGH — breaks a documented feature for every specimen.
- **Fix:** `MESSAGE_LOCK` → `MESSAGE_HISTORY_LOCK` (1 char change).
- **Status:** ✅ FIXED in this sweep.

### BUG-002: LobeTable double-include — `/lobeGrow` chokes on populated `data:{...}`
- **Files:** `src/Lobe.jl:13` and `src/Main.jl:50`
- **Symptom:** `Lobe.jl` includes `LobeTable.jl` into `Lobe`'s submodule
  scope. `Main.jl` includes it AGAIN into `Main`'s scope. Two separate
  `LobeTable` instances exist at runtime, with separate `LOBE_TABLE_REGISTRY`
  Dicts. `Lobe.create_lobe!` registers the table in **Lobe's** copy.
  `/lobeGrow` calls `LobeTable.json_to_table_chunk!` which resolves to
  **Main's** copy — registry empty → `LobeTableError("No table found")`.
- **Severity:** HIGH — any `/lobeGrow` with non-empty `data` field crashes.
  Only saved by `json_to_table_chunk!` early-returning on empty Dict.
- **Fix:** Single shared `LobeTable` module. Lobe.jl should NOT re-include;
  use a forward-declared interface or move `LobeTable` to a shared parent.
- **Status:** TO FIX in this sweep.

### BUG-003: Lobe topicality gate tokenizes subject by whitespace only
- **File:** `src/engine.jl:1080` → `src/Thesaurus.jl:269`
- **Symptom:** Lobe subjects like `"greetings_and_intros"` become a single
  un-splittable token with no thesaurus entries. Topicality always 0.0,
  lobe always muted. Total lobe deafness.
- **Severity:** HIGH — silent footgun that mutes the entire lobe.
- **Fix:** Normalize subject (`_`, `-` → space) before thesaurus expansion.
  Also: print a warning at `/newLobe` time if subject contains `_` or `-`.
- **Status:** TO FIX in this sweep.

### BUG-004: Pattern scan rejects nodes longer than user input
- **File:** `src/engine.jl:2538`
- **Symptom:** `if length(target_signal) < length(node.signal) return nothing`
  short-circuits BEFORE pattern matching. Long-pattern seed nodes
  (e.g. 7+ tokens of synonyms) are silently skipped on short missions
  (e.g. 3-token `/mission hello there grug`). No diagnostic logging.
- **Severity:** MEDIUM — design choice, but undocumented and silent.
  Footgun for new users seeding rich patterns.
- **Fix:**
  - (a) Add a one-time WARN when this skip fires, with mission/node lengths.
  - (b) Document in `/lobeGrow` and `/grow` help text: keep patterns SHORT
    (1-3 anchor tokens). Thesaurus + relational triples handle the rest.
  - (c) Consider: bidirectional cheap_scan should accept the
    "short-input-vs-long-pattern" case and just match on the shorter side.
- **Status:** TO FIX (a + b, defer c as a design discussion).

### BUG-005: `/addVerb` argument order documented as `<verb> <class>` but seed
files commonly write `<class> <verb>`
- **Symptom:** Confusing because `/addRelationClass <name>` registers a
  class, then `/addVerb <verb> <class>` adds a verb to it. Visually the
  natural reading order is "add verb {class}: {verb}".
- **Severity:** LOW — annoying, not breaking. Errors are loud.
- **Fix:** Add an alias `/addVerbToClass <class> <verb>` for clarity, OR
  accept either order at parse time (detect which is registered as a class).
- **Status:** TO FIX (accept either order).

### BUG-006: `/grow` uses `json_data` key, `/lobeGrow` uses `data` key — same
field, different names
- **Files:** `src/Main.jl:4408` (`get(packet, "data", ...)`) vs
  `src/engine.jl:3019` (`n["json_data"]`)
- **Symptom:** Identical concept (per-node json metadata) named two
  different things in two different commands. Users hit silent loss of
  data when they use the wrong key.
- **Severity:** MEDIUM — silent data drop.
- **Fix:** Accept BOTH `data` and `json_data` keys in both commands. Warn
  if both are present. Standardize on `data` going forward (shorter, less
  redundant — the packet IS json data, calling a sub-field json_data is
  redundant).
- **Status:** TO FIX.

### BUG-007: `action_packet` action names not validated at grow time
- **File:** `src/engine.jl:create_node` (or wherever node creation happens)
- **Symptom:** User can `/lobeGrow` with `action_packet:"FROBNICATE^5"`,
  the node creates fine, but on first vote the COMMANDS dictionary
  doesn't have `FROBNICATE` and the engine throws
  `FATAL: Grug rolled unknown action [FROBNICATE]!` — at vote time, far
  from the seed-time mistake.
- **Severity:** MEDIUM — late error far from cause.
- **Fix:** Validate every action name in the action_packet against
  `COMMANDS` keys at node creation time. Reject growth if any action is
  unknown. Print the list of valid action names for help.
- **Status:** TO FIX.

### BUG-008: `/grow` doesn't accept a lobe target (user request)
- **Symptom:** `/grow` drops nodes into the unassigned pool. The
  topicality gate then can't reason about them. Two near-identical commands
  exist (`/grow` and `/lobeGrow`) doing 90% the same thing.
- **Severity:** MEDIUM — design wart.
- **Fix:** Unify: `/grow <lobe_id> <json_packet>` becomes the One True
  Way. Accept BOTH single-node packets `{"pattern":...}` AND multi-node
  packets `{"nodes":[...]}` in same command. `/lobeGrow` becomes a
  deprecated alias that prints a deprecation warning then routes to `/grow`.
  `default` lobe auto-created at boot for boot-seed nodes (formerly
  unassigned).
- **Status:** TO FIX.

### BUG-009: No `default` lobe — boot seeds float in unassigned pool
- **File:** `src/Main.jl` cave population block (~line 3625-3650)
- **Symptom:** Boot seeds (node_0..node_2) live in no lobe. Topicality
  gate has special "Unassigned nodes - no lobe context" pathway. This is
  what was winning votes during the silence test (because all custom
  lobes were muted).
- **Severity:** LOW — design oddity, not breaking.
- **Fix:** Auto-create a `default` lobe at boot with subject
  `"general thinking reasoning conversation"`, register all boot seeds
  into it. Remove the "unassigned" special case from topicality gate
  (make it just a normal lobe).
- **Status:** TO FIX.

### BUG-010: Subject-pinning of `system_prompt` is required but undocumented
- **Symptom:** Nodes without `system_prompt` in their `data`/`json_data`
  field crash voting with `FATAL: Node dictionary missing 'system_prompt'!`.
  This is not surfaced anywhere in `/lobeGrow` help.
- **Severity:** MEDIUM — undocumented required field, late error.
- **Fix:**
  - (a) Default `system_prompt` to a generic value
    (`"Grug speaks plainly."`) if missing at node creation time.
  - (b) Document `system_prompt` as a recommended `data` field in help.
- **Status:** TO FIX (a).

### BUG-011: Total-mute silence — when no lobe matches, all lobes mute and grug goes silent
- **File:** `src/engine.jl:_compute_muted_lobes`
- **Symptom:** Every lobe has a narrow subject. Casual mission text ("warning
  the bear is coming", "good morning grug") doesn't overlap any subject above
  LOBE_TOPICALITY_FLOOR. Every lobe gets muted. Result: 0 eligible nodes,
  cave silent.
- **Severity:** HIGH — explains 8/10 silent missions in hardcore test even
  with the default specimen loaded.
- **Original bandaid (rejected):** Promote `default` to eligible when all
  muted. User pointed out the entire mute gate is the wrong abstraction —
  lobes should be selected by averages curves, not membership tests.
- **Final fix (LobeOrchestrator rewrite):**
  - Removed `LOBE_TOPICALITY_FLOOR`, `BRIDGED_NODE_CONF_WEIGHT`,
    `_compute_lobe_topicality`, `_compute_muted_lobes`,
    `_node_has_semantic_bridge`, `apply_lobe_topicality_gate!`, the
    `_LAST_MUTED_LOBES` and `_LAST_BRIDGED_NODES` telemetry refs (319 lines).
  - Added `src/LobeOrchestrator.jl` with the spec'd averages curve:
    - `score = base_avg × top_avg` per lobe (base over all confs, top over
      the top-K=ceil(N/2) confs).
    - Winner lobe always fires. Runner-ups fire only if
      `score >= MIN_PASS_THROUGH_SCORE (0.10)` AND
      `hard_votes >= MIN_WINNING_VOTES_PER_LOBE (2)` (a hard vote is conf ≥ 0.5).
    - Tie handling: equal scores → 50/50 coinflip via Fisher-Yates shuffle
      across the tied run.
    - `HARD_FIRE_BATCH_CAP = 1000` for the firing pipeline.
    - Telemetry: `LAST_LOBE_SCORES` (all lobes), `LAST_WINNER`,
      `LAST_PASSTHROUGH`. Surfaced in scaffold via `last_summary()` with
      👑 marking winner, ↗ marking pass-through.
  - Replaced scaffold "Muted Lobes / Bridged Nodes" block with the
    Lobe Curve readout.
- **Test result:** Hardcore 10-mission run drops from 8/10 silent → 0–2/10
  silent (residual is just the strength-biased scan coinflip, which is
  intentional stochastic behavior).
- **Status:** ✅ FIXED in this sweep.

---

## SYSTEMATIC SCAN — codebase smell hunt

### SMELL-001: Many places use `try ... catch` and swallow the exception
- See: `src/Main.jl:1568` (catch e — pinned memory check, just warns)
- See: `src/engine.jl:2832` (catch e — topicality gate fallback)
- See: dozens of others
- **Recommendation:** Audit each: if it's truly recoverable, fine; if it
  hides bugs, replace with explicit handling. Tag the swallowing with a
  `# SAFE_SWALLOW: reason` comment so future devs know.
- **Status:** AUDIT (defer; not critical).

### SMELL-002: 5000-line `Main.jl` is a monolith
- The CLI loop, AIML synthesis, COMMANDS dict, and orchestration glue
  all live in one file. Hard to navigate.
- **Recommendation:** Split into:
  - `Main.jl` — CLI loop only
  - `CommandRegistry.jl` — COMMANDS dict + family registration
  - `Synthesis.jl` — AIML payload construction
- **Status:** DEFER (cosmetic, big surgery).

### SMELL-003: Dead/disabled code blocks left as comments
- `src/engine.jl:2557-2575` — Hopfield fast-path disabled but commented
  out instead of removed. ~50 lines of dead code per place.
- **Recommendation:** Delete; git history preserves it.
- **Status:** TO FIX (sweep these).

### SMELL-004: Magic numbers without named constants
- `LOBE_TOPICALITY_FLOOR = 0.15` ✓ named
- `0.5` (BRIDGED_NODE_CONF_WEIGHT) ✓ named
- But: `0.3`, `0.4`, `0.5` thresholds in `_bidirectional_cheap_scan`,
  `medium_scan`, `high_res_scan` are inline numbers
- **Recommendation:** Promote to named constants.
- **Status:** TO FIX (small).

### SMELL-005: `println` for all logging instead of `@info`/`@warn`
- Mixed: some places use `@info`/`@warn`/`@error`, others use `println`.
  Harder to filter telemetry from speech.
- **Recommendation:** All telemetry should go through Julia's logging.
  CLI can capture+display selectively. Conversation output stays
  `println` (it's user-facing speech).
- **Status:** DEFER (large).

---

## FIX ORDER (this sweep)

1. ✅ BUG-001: `MESSAGE_LOCK` typo (already done)
2. BUG-002: Single shared LobeTable module
3. BUG-003: Subject normalization + warning
4. BUG-004: Logging when long-pattern skip fires + help text
5. BUG-005: `/addVerb` accept either order
6. BUG-006: `/grow` and `/lobeGrow` accept both `data` and `json_data`
7. BUG-007: Validate action_packet names at grow time
8. BUG-008: Unify `/grow <lobe_id> <json>` (the user's main request)
9. BUG-009: Auto-create `default` lobe at boot
10. BUG-010: Default `system_prompt` if missing
11. SMELL-003: Sweep dead-code comment blocks
12. SMELL-004: Promote magic scan thresholds to named constants

After all fixes: ship a default specimen the engine can boot with, run
the hardcore conversation test, and commit/push.
