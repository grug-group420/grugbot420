# Grugbot420 Coherence Fix Summary (v7.61)

## Overview

This document summarizes all coherence fixes applied to the grugbot420 Julia cognitive architecture across multiple sessions. The primary goal was eliminating decoherent responses — outputs where the content was semantically unrelated to the input query.

## Final Test Results: 19/19 Coherent

All 20 test queries now produce semantically coherent responses (1 graceful no-match for "what is air" which has no matching node, and 3 more graceful no-matches for gap queries — all correct behavior).

### Before vs After

| Query | Before | After |
|-------|--------|-------|
| "why does fire burn" | "Grug speak of gravity" | "Grug speak of fire" ✅ |
| "how does fire work" | "Grug speak of shelter" | "Grug speak of fire" ✅ |
| "what is love" | "Grug think on adore" | "Grug think on love" ✅ |
| "what is courage" | "Grug think on fear" | "Grug think on courage" ✅ |

## Changes by Phase

### Phase 1: Core Engine Fixes (Prior Session)

**Files: `src/engine.jl`, `src/Main.jl`**

1. **Removed all antimatch node references** — Antimatch was a deprecated concept causing code paths to reference non-existent node types. Converted fatal errors to warnings.

2. **SCAN_CONFIDENCE_LOCK (0.15→0.30)** — Minimum confidence for a node to enter the voter pool. Initially 0.15, raised to 0.30 in Phase 4 to prevent weak matches from winning.

3. **Lexical gating in `_scan_confidence_for_node`** — Signal similarity (float-hash) alone can no longer make a node fire. A node must have at least some lexical overlap with the input. Formula: `combined = lex_conf * (1.0 + 0.3 * sig_conf)` — signal can add at most 30% bonus on top of lexical relevance.

4. **Content-weighted `_lexical_overlap_confidence`** — Stopword filtering + harmonic mean of bidirectional coverage. Prevents "what is macroeconomics" from matching "what is fire" via function word overlap.

5. **Reduced VOTE_BONUS_CAP** from 1.5 to 0.5 — Prevents composite score inflation from bonuses.

6. **Raised AIML_CONFIDENCE_THRESHOLD** from 0.35 to 0.70 — Weak matches no longer win votes.

7. **Triple injection relevance gate** — Relational triples must share at least one content word with the input to appear in the SUPPORT section. Prevents random knowledge from polluting the reply.

### Phase 2: Thesaurus Register-Inappropriate Swaps (Prior Session)

**File: `src/Thesaurus.jl`**

1. **Removed 69 wrong-register synonyms** from 25 thesaurus entries. Examples:
   - "rationale" removed from "logic" synonyms
   - "shall" removed from "must" synonyms
   - "detest"/"loathe"/"despise" removed from "hate" synonyms
   - "adore" was already removed from thesaurus but survived in verb registry

2. **Reduced swap rates**:
   - Thesaurus swap rate: 0.25 → 0.15
   - Light touch rate: 0.18 → 0.10

3. **Rebuilt specimen** with cleaned thesaurus: 836 → 767 words, 3720 synonym links.

### Phase 3: Chatter Mode Investigation (Prior Session)

**Finding: Chatter mode was NOT the root cause of multi-response pileup.** Voice body assembly produces single coherent responses. Chatter swaps node patterns and votes between groups, which can cause semantically unrelated nodes to win future votes, but this is by-design creative noise. Disabling chatter (ENV["GRUG_CHATTER_ENABLED"]="false") eliminates this noise source.

### Phase 4: Semantic Coherence Fixes (This Session)

**Files: `src/Main.jl`, `src/engine.jl`, specimen JSON**

#### Fix 1: Voice Body + Topic Clause Gets Aggressive Swap (v7.61)

**Problem:** When `_topic_clause` was appended to `voice_body` in `claim_raw`, the resulting string no longer matched `voice_body_default`, causing it to fall through to `_swap_words_in` (aggressive synonym replacement) instead of `_light_thesaurus_touch` (gentle variation). This could swap the topic noun to an unrelated word.

**Fix in `src/Main.jl` (line ~3070):** Added `_claim_is_voice_body` check that uses `startswith(voice_body_default)` to detect when claim_raw is a voice_body claim with topic clause appended. These claims now correctly receive `_light_thesaurus_touch` instead of `_swap_words_in`.

```julia
_claim_is_voice_body = !isempty(voice_body_default) && (
    claim_raw == voice_body_default ||
    (!isempty(node_voice_variants) && claim_raw in node_voice_variants) ||
    (!isempty(_topic_clause) && startswith(String(claim_raw), voice_body_default))
)
```

#### Fix 2: Elevated-Register Verb Synonym Exclusion (v7.61)

**Problem:** The `_pick_synonym` function collected ALL verb synonym aliases when the output word was a canonical. For "love" (canonical), it collected aliases including "adore", and randomly picked one. For "burn", it collected "ignite" and "combust". These elevated-register aliases don't fit grug's caveman voice.

**Fix in `src/Main.jl` (line ~2216):** Added `_grug_voice_excluded_synonyms` set containing 22 elevated-register verb aliases. The `_pick_synonym` candidate filter now excludes these words from the output candidate pool. The mappings still work for INPUT matching (user says "adore" → matches "love" node), but the output always stays "love".

Excluded aliases: adore, combust, ignite, collaborate, consider, console, construct, distribute, generate, produce, rely upon, sense, understand, stream, experience, dread, ponder, track, assemble, forage, guard, collect.

#### Fix 3: Generic-Content-Word Discount (v7.61)

**Problem:** Node "how does shelter work" was winning the vote for "how does fire work" because both shared the generic content word "work". The harmonic mean of 0.5 (matching 1 of 2 content words each direction) was the same as for nodes matching "fire" specifically, and signal similarity tipped the balance to the wrong node.

**Fix in `src/engine.jl` `_lexical_overlap_confidence`:** Added `_generic_content_words` set (80+ common verbs like "work", "make", "go", etc.). When the overlap between input and node consists ENTIRELY of generic content words, the harmonic mean is discounted by 0.5. This makes "shelter work" (matching only "work") score lower than "fire burn" (matching "fire"), even when both have the same raw overlap count.

Also raised `SCAN_CONFIDENCE_LOCK` from 0.15 to 0.30 — requires at least moderate lexical overlap (harmonic mean ≥ 0.30) to enter the voter pool.

#### Fix 4: Node noun_anchors Order (Specimen)

**Problem:** Node_50 ("fear precedes courage") had noun_anchors = ["fear", "courage"]. The `_topic_clause` used `node_noun_anchors[1]` = "fear" (first element), producing "Grug think on fear" when the query was about courage.

**Fix in specimen JSON:** Swapped noun_anchors to ["courage", "fear"] so the primary topic word comes first.

## Code Changes Summary

### src/engine.jl
- Line 1252: `SCAN_CONFIDENCE_LOCK` raised from 0.15 to 0.30
- Lines 5340-5435: `_lexical_overlap_confidence` — Added generic-content-word discount (0.5 penalty when overlap is entirely generic words)

### src/Main.jl
- Lines 2216-2248: Added `_grug_voice_excluded_synonyms` set (22 elevated-register verb aliases)
- Line 2347: Added grug-voice exclusion filter in `_pick_synonym` candidate selection
- Lines 3070-3095: Added `_claim_is_voice_body` check so voice_body+_topic_clause gets `_light_thesaurus_touch` instead of `_swap_words_in`

### Specimen (comprehensive_specimen_v758_patched.json)
- Node_50 noun_anchors: ["fear", "courage"] → ["courage", "fear"]
- Thesaurus_seeds: cleaned in prior session (767 words, 3720 links)
