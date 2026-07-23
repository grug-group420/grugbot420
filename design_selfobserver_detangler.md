# Self-Observer Detangler — Design Document v2

## Problem: False Winners

The core issue is false winners — votes that win on a technicality but fail
a coherence check against broader context. Every false winner shares the same
profile: wins a local pattern match, but the result doesn't make sense when
you step back and look at what the input actually means.

Examples:
- "how are you feeling" → :define with word="how" (X-is-Y regex matched)
- "why is the sky blue" → :define with word="why"
- "tides are caused by the moon pulling" → relational sigil with 0 triples
- "I feel sad" → "Fire sit via sad" (thesaurus swaps "Grug" → "Fire")
- "what is fire and what is water" → only fire answered (multipart garble)

The v8.28b patches fixed each symptom. The structural gap is that no
observer watches the whole pipeline and says "that doesn't make sense."

## Key Insight: ATP and Detangler Must Stack

ActionTonePredictor (ATP) already provides one coherence signal:
action-family alignment. It predicts whether the input is a QUERY, ASSERT,
COMMAND, etc., then boosts nodes whose action_packet aligns and mildly
suppresses (max 8%) misaligned ones. This is a **structural coherence** signal
—"does this node's action type match the input's action type?"

But ATP cannot catch semantic incoherence. When "how are you feeling" hits
the X-is-Y regex, ATP sees a QUERY-aligned node and boosts it — because the
node's action IS explain/describe. But the node's *meaning* is wrong: it's
defining "how" as if "how" were a vocabulary word, not answering the question.

The detangler provides **semantic coherence** — "does this node's meaning
make sense for what was asked?" These two signals must STACK into the same
composite score, not operate as independent layers:

| Signal | Checks | Weight Slot | Current Weight |
|--------|--------|-------------|----------------|
| ATP action_tone_align | Action-family match (QUERY/ASSERT/COMMAND) | VOTE_W_ACTION_TONE_ALIGN | 0.10 |
| Detangler coherence_audit | Semantic intent match (:question vs :define pathway) | VOTE_W_COHERENCE_AUDIT (NEW) | 0.15 |

When they AGREE (action-aligned AND semantically coherent), the node gets
both bonuses — strong endorsement. When they DISAGREE (action-aligned but
semantically incoherent), the detangler's penalty overrides ATP's boost —
because semantic coherence is a stronger truth than action-family alignment.

### How the Override Works

The coherence_audit signal is bipolar: it can be positive (candidate
semantically aligns with intent) or negative (candidate contradicts intent).
This is different from all existing bonus signals, which are [0,1] positive-only.

- Positive coherence_audit: candidate's pathway matches intent → bonus
  (e.g., :question input, :answer pathway node → +0.15 * audit_score)
- Negative coherence_audit: candidate's pathway contradicts intent → penalty
  (e.g., :question input, :define pathway node → -0.15 * audit_score)

This means a :define-pathway node on a :question input gets:
- ATP: +0.10 * action_tone_align (QUERY node, ATP boosts it)
- Detangler: -0.15 * coherence_audit (semantic mismatch, detangler penalizes)
- Net: the detangler OVERRIDES ATP's boost, producing a net penalty

The composite_vote_score formula becomes:

```
bonus_pos += _add(vc.action_tone_align, VOTE_W_ACTION_TONE_ALIGN)   # existing
bonus_pos += _add(vc.coherence_audit,   VOTE_W_COHERENCE_AUDIT)     # NEW (can be negative)
```

When coherence_audit is negative, it eats into bonus_pos. If it's negative
enough, it can flip the total bonus_pos negative, which then means
`confidence * (1 + negative_bonus)` = score BELOW raw confidence. The node
that ATP boosted now scores worse than having no bonuses at all.

This is the biological "inhibitory interneuron" — not a hard gate, but a
signal that can override excitation when the semantic readout says "this
doesn't make sense."

## Existing Infrastructure

### SelfObserver (SelfObserver.jl)
- Subconscious microlog store — fuzzy, stochastic, throttled
- Tags: :timing, :lexical, :mood, :relational, :meta
- INVARIANT: no Float64 leaks to public API (no confidence shaping)
- Writes are probabilistic (p_write gate), reads are throttled (token bucket)
- Currently used for: output self-observation, MLP cycle observation,
  hippocampal ask observation, vigilance dispatch context probing

### VoteOrchestrator (VoteOrchestrator.jl)
- composite_vote_score: confidence * (1 + bonuses) - confidence * penalties
- Bonuses: lobe_alignment (0.20), relational_match (0.15), recency (0.05),
  action_tone_align (0.10), peak_dominance (0.00)
- VOTE_BONUS_CAP = 0.5 — total positive bonus capped here
- Penalties: anti_match (0.00, zeroed since v8.26h)
- **NEW**: coherence_audit bonus/penalty slot (weight 0.15, bipolar)

### ActionTonePredictor (ActionTonePredictor.jl)
- Predicts action family and tone family from raw input structure
- get_action_weight_multiplier: aligned → boost, misaligned → 0.92-1.0 tap-down
- Lazy conservative: only modulates at 50%+ confidence
- Feeds into composite_vote_score via action_tone_align (weight 0.10)
- **KEY LIMITATION**: Only checks action-family alignment. Cannot detect
  semantic incoherence (a QUERY-aligned node can still be a false definition)

### EphemeralMLP / HippocampalModulator / CoherenceField
- EphemeralMLP: transforms vote confidence, gated by SelfObserver
- HippocampalModulator: confidence-ordered dispatch, ephemeral per cycle
- CoherenceField: global Phi field, weight defaults to ZERO

## The Gap: No Semantic Coherence Signal

The pipeline has structural coherence (ATP checks action-family alignment)
but lacks semantic coherence (does this answer make sense for what was asked).

Current vote signals:
1. lobe_alignment — is this node in the right lobe? (structural)
2. relational_match — does the node's triples overlap with input? (structural)
3. recency_bonus — was this node recently active? (temporal)
4. action_tone_align — does the node's action match the input's action? (structural)
5. peak_dominance — ZEROED
6. frame_match — does the node's frame match the input's frame? (structural)
7. grave_shadow — is this node in a dead-knowledge shadow? (structural)

Missing: "does this node's MEANING make sense for the input's INTENT?"

The detangler fills this gap with a signal that STACKS with ATP, not a
separate gate. ATP is the fast first layer (action-family check), the
detangler is the slower but more accurate second layer (semantic check).

## Design: Two-Stage Detangler

### PRE-VOTE: Coherence Audit (before select_aiml_votes)

Purpose: Compute a semantic coherence signal for each candidate that
STACKS with ATP's action-family signal in composite_vote_score.

Location: Between candidate assembly and select_aiml_votes.
The coherence_audit value is stored on VoteCandidate and consumed by
composite_vote_score just like action_tone_align.

Checks:
1. **Intent-pathway coherence**: Does the candidate's activation pathway
   match the ConversationIntent's classification?
   - :question input + :answer/:explain pathway → positive (coherent)
   - :question input + :define pathway → negative (contradicts intent)
   - :define input + :define pathway → positive (coherent)
   - :greeting input + :define pathway → negative (contradicts intent)
   - Score magnitude scales with ConversationIntent.confidence

2. **Topic coherence**: Does the candidate's pattern relate to the input's topic?
   - Input topic matches candidate's primary topic → positive
   - Input topic is unrelated to candidate's topic → negative
   - Score magnitude scales with topic drift distance

3. **Historical false-winner pattern**: Has SelfObserver seen this
   (input_pattern, candidate_pattern) combination before and recorded it
   as producing incoherent output? Historical false-winner match → negative.

4. **Question-word guard**: If ConversationIntent has question_words,
   are any of them being treated as definition targets by the candidate?
   - Question word appears as definition target → strong negative
   - This directly catches the "how means you feeling" class

coherence_audit = intent_pathway + topic_coherence + historical_pattern + question_word_guard
Each component in [-1, 1]. Total clamped to [-1, 1].

Implementation:
- New VoteCandidate field: coherence_audit::Float64 (default NaN = no opinion)
- New VOTE_W_COHERENCE_AUDIT = 0.15 weight constant
- New SelfObserver tag: :coherence_audit, provenance: :pre_vote_audit
- Observation written AFTER prescan, BEFORE vote selection
- Peek before selection for historical false-winner patterns

### POST-VOTE: Output Detangler (after voice rendering)

Purpose: Catch incoherent output AFTER it's been assembled, before it
reaches the user. This is the "did I just say something stupid?" check.

Location: After voice rendering, before the final output is returned.

Checks:
1. **Subject drift**: Did the output's subject drift from the input's topic?
2. **Self-reference corruption**: Did the output replace "Grug" incorrectly?
3. **Question-answer mismatch**: If the input was a question, does the
   output actually answer it?
4. **Repetition/loop**: Is the output substantially the same as recent output?

Repair is SOFT — patch specific incoherence, don't rewrite whole output.
Write observation to SelfObserver so pre-vote audit can learn from detangle events.

## The Missing Backbone: ConversationIntent

Both stages need a shared intent object. Right now each subsystem
re-derives intent independently. The ConversationIntent would be:

```julia
struct ConversationIntent
    raw_input::String
    intent::Symbol           # :question, :define, :teach, :correct, :answer, :greeting, :statement
    topic::String            # what the input is ABOUT
    question_words::Set{String}  # interrogatives detected
    subject_hint::String     # which lobe/subject
    knowledge_type::Symbol   # :static, :procedural, :relational
    confidence::Float64      # how confident the classification
    indicators::Set{String}  # which words triggered classification
end
```

Built ONCE by _conversation_prescan, flows through the entire pipeline.
Pre-vote audit checks candidates against it. Post-vote detangler checks
output against it. ATP can also read it in the future for better predictions.

## Stacking Architecture: How Signals Compose

```
1. _conversation_prescan → ConversationIntent (intent, topic, question_words)
2. ActionTonePredictor → PredictionResult (action_family, tone_family, confidence)
3. For each candidate:
   a. ATP: compute action_tone_align (action-family match) → [0, 1]
   b. Detangler: compute coherence_audit (semantic intent match) → [-1, 1]
   c. composite_vote_score:
      bonus_pos += action_tone_align * 0.10   # ATP boost
      bonus_pos += coherence_audit * 0.15     # Detangler (can be NEGATIVE)
      ... other bonuses ...
      bonus_pos = min(bonus_pos, 0.5)         # CAP
      score = eff_conf * (1 + bonus_pos) - eff_conf * penalty
      score *= frame_match_multiplier
      score *= grave_shadow_multiplier
4. select_aiml_votes → winners
5. Voice rendering
6. Post-vote detangler → repair if needed
7. Output self-observation (existing)
```

When ATP and Detangler AGREE (both positive):
- action_tone_align=0.8, coherence_audit=0.7
- bonus: 0.8*0.10 + 0.7*0.15 = 0.08 + 0.105 = 0.185 → strong endorsement

When ATP positive but Detangler negative (the false winner case):
- action_tone_align=0.8, coherence_audit=-0.6
- bonus: 0.8*0.10 + (-0.6)*0.15 = 0.08 - 0.09 = -0.01 → net NEGATIVE
- Score falls below raw confidence → node likely rejected at threshold

When Detangler positive but ATP neutral:
- action_tone_align=0.5, coherence_audit=0.8
- bonus: 0.5*0.10 + 0.8*0.15 = 0.05 + 0.12 = 0.17 → semantically coherent lift

This is the biological model: layered inhibition where deeper layers can
override shallower ones. ATP is the fast first layer, the detangler is the
slower but more accurate second layer.

## Implementation Order

1. Add ConversationIntent struct
2. Build ConversationIntent in _conversation_prescan (replace 4-tuple return)
3. Flow ConversationIntent through process_mission
4. Add :coherence_audit and :output_coherence tags to SelfObserver
5. Add coherence_audit field to VoteCandidate (default NaN)
6. Add VOTE_W_COHERENCE_AUDIT = 0.15 weight constant
7. Implement pre_vote_audit: compute coherence_audit per candidate
8. Wire coherence_audit into composite_vote_score
9. Implement post_vote_detangle: check output against intent, repair
10. Wire post-vote detangle into voice rendering pipeline
11. Test suite
12. Commit as v8.29

## Key Design Principles

1. **STACK, don't side-by-side**: The detangler's signal composes with
   ATP's signal in the same score formula. It doesn't run as a separate
   gate or checkpoint. Both coherence layers shape the same composite score.

2. **OVERRIDE, not veto**: When the detangler disagrees with ATP, it
   doesn't hard-veto the vote. It produces a negative bonus that makes
   the score lower. The node can still win if its confidence is high enough.
   This is loosey-goosey — biology's inhibitory interneurons don't hard-gate,
   they modulate firing rates.

3. **SOFT over HARD**: No hard gates. Damping, not rejection.

4. **FUZZY over CRISP**: Stochastic, throttled, bounded. Same spirit as
   SelfObserver. Sometimes the observer doesn't notice. That's okay.

5. **OBSERVE over CONTROL**: The detangler observes and suggests, it doesn't
   command. It writes observations that other systems can read. It peeks at
   history to inform its suggestions. But it never directly overrides a vote
   or rewrites output without going through the normal pipeline.

6. **SHARED INTENT**: The ConversationIntent is the backbone. Without it,
   the detangler is just more patchwork. With it, the whole pipeline gains
   a shared understanding of what the input means.

7. **NO FLOAT64 LEAKS**: The detangler respects SelfObserver's invariant.
   Its coherence_audit is an internal Float64 on VoteCandidate (which already
   uses Float64 internally), but the observations it writes to SelfObserver
   carry only Symbol/String/Int/Bool.
