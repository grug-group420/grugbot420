# Grugbot v8.2 Changelog

## Changes

### 1. New Function: `_hippocampal_touch`

**Location:** `src/Main.jl`, inserted between `_light_thesaurus_touch` and `_swap_words_in`

**Problem:** When grug is taught via `/answer`, the resulting hippocampal_answer node fires with the exact answer content verbatim — "breathing draws oxygen into the lungs and expels carbon dioxide" comes back word-for-word every time. The existing `_light_thesaurus_touch` only swaps 10% of eligible words (and only those with 2+ synonyms), which is too conservative for taught answers.

**Solution:** New `_hippocampal_touch` function applies moderate thesaurus variation specifically for hippocampal_answer voice_body claims:
- **Swap rate:** 45% (configurable via `GRUG_HIPPOCAMPAL_TOUCH_RATE` env var) — nearly half of eligible words get swapped
- **Synonym threshold:** 1+ synonyms (vs 2+ for `_light_thesaurus_touch`) — domain words like "breathe" (has "inhale/exhale/respire") get swapped even though they only have a few alternatives
- **Same protections:** inhibited words, drop_table entries, and required_relations are still protected from swapping
- **Case preservation:** follows the same capitalization rules as the other thesaurus functions

**Example effect:**
- Before: "breathing draws oxygen into the lungs and expels carbon dioxide" (verbatim parrot)
- After: "inhaling pulls oxygen into the lungs and removes carbon dioxide" (rephrased, same meaning)

### 2. New Variable: `node_growth_source`

**Location:** `src/Main.jl`, in the `generate_aiml_payload` function's winning_node.json_data reads

**Added:** `node_growth_source` reads `growth_source` from the winning node's json_data. Possible values:
- `"hippocampal_answer"` — created via `/answer` command
- `"hippocampal_anti_answer"` — created via `/antiAnswer` command
- `""` (empty) — pre-seeded nodes, AutoGrowth nodes, etc.

**Default:** `""` when `winning_node === nothing` or when `growth_source` key is absent from json_data.

### 3. Modified Claim Construction Logic

**Location:** `src/Main.jl`, `_claim_is_voice_body` section

**Before:**
```julia
claim = if judged_frame_test_inject
    String(claim_raw)
elseif _claim_is_voice_body
    _light_thesaurus_touch(String(claim_raw), node_drop_table, node_required)
else
    claim = _swap_words_in(String(claim_raw), node_drop_table, node_required)
    _reorder_clauses(claim)
end
```

**After:**
```julia
_is_hippocampal_answer = !isempty(node_growth_source) && (
    node_growth_source == "hippocampal_answer" ||
    node_growth_source == "hippocampal_anti_answer"
)
claim = if judged_frame_test_inject
    String(claim_raw)
elseif _claim_is_voice_body && _is_hippocampal_answer
    _hippocampal_touch(String(claim_raw), node_drop_table, node_required)
elseif _claim_is_voice_body
    _light_thesaurus_touch(String(claim_raw), node_drop_table, node_required)
else
    claim = _swap_words_in(String(claim_raw), node_drop_table, node_required)
    _reorder_clauses(claim)
end
```

The new branch sits between the test-inject override and the existing voice_body branch. When a hippocampal_answer node fires with voice_body, it gets the moderate 45% swap instead of the conservative 10% touch. Non-answer voice_body (pre-seeded nodes) keeps the light touch.

### 4. Updated Test Commands with Lobe Specification

**File:** `teach_reask_commands_v2.txt`

**Problem:** Previous test commands used `/answer :mode content` without specifying a lobe, creating nodes with no lobe assignment.

**Fix:** All `/answer` commands now include `@lobe_id`:

| Scenario | Command |
|---|---|
| Breathing | `/answer @nature :explain breathing draws oxygen into the lungs and expels carbon dioxide` |
| Hunting | `/answer @nature :reason hunting is the pursuit and capture of prey for food and survival` |
| Cooking | `/answer @nature :explain cooking applies heat to food to make it safe and easier to digest` |
| Music | `/answer @language :define music is organized sound that expresses emotion and rhythm` |

**Lobe mapping:**
- breathing → `@nature` (natural world: breath, body, survival)
- hunting → `@nature` (natural world: predator-prey, survival)
- cooking → `@nature` (natural world: fire, food, transformation)
- music → `@language` (language and communication: expression, rhythm, sound)

## Thesaurus Swap Rate Comparison

| Function | Swap Rate | Synonym Threshold | Applied To |
|---|---|---|---|
| `_pick_synonym` (via `_swap_words_in`) | 15% (every token) | 1+ | Mechanical claims (patterns, noun_anchors) |
| `_light_thesaurus_touch` | 10% | 2+ | Pre-seeded voice_body claims |
| **`_hippocampal_touch`** | **45%** | **1+** | **Hippocampal_answer voice_body claims** |

## Run Instructions

To test the teach-and-reask loop with lobe assignment and thesaurus rephrasing:

```bash
cd grugbot420
julia --project=. src/Main.jl < teach_reask_commands_v2.txt > teach_reask_raw_output_v2.txt 2>&1
```

Then parse the output:
```bash
python3 parse_teach_reask.py teach_reask_raw_output_v2.txt > grug_teach_reask_log_v2.md
```

The re-ask outputs should now show variation from the taught answer instead of verbatim parroting.
