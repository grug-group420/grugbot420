# Decoherence Analysis — v8.28 + v826i Logs

## Root Cause Map

### Bug 1: Questions misclassified as definitions
**"how are you feeling" → `📖 Learned: how means you feeling`**
**"why is the sky blue" → `📖 Learned: why means the sky blue`**

Root cause: `_conversation_prescan` has no **intent guard** before the `X is/are Y` regex.
The order is: `:question` patterns → `:correct` → `:define` → `X is/are Y`. But "how are you feeling"
doesn't match any `:question` pattern (not "what is...", "who is...", "tell me about...", etc.),
so it falls through to `X is/are Y` → `("how", "you feeling")` → `:define`.

The fix is NOT just adding more question patterns. The real gap is:
**There is no guard that says "question words (how, why, when, where, who) should NEVER
be definition targets."** This is a governance/intent classification problem — the prescan
needs a lightweight "is this even a definition candidate?" gate before the regex fires.

### Bug 2: Relational triples not extracted
**"tides are caused by the moon pulling the ocean" → 0 meaningful triples**

Root cause: `_classify_knowledge` uses a RICH set of relational indicators (pulls, attracts,
requires, consumes, produces, etc.) but `extract_relational_triples` only finds triples
where the verb is in `SemanticVerbs.get_all_verbs()` — which has only 27 verbs (mostly
math operators). The two systems are DISCONNECTED:

- `_classify_knowledge` says "this is relational!" based on indicator words
- `extract_relational_triples` says "I can't find any triples" because those same
  indicator words aren't in the verb registry

The fix is NOT just adding more verbs to SemanticVerbs. The real gap is:
**The classification system and the extraction system share no vocabulary.**
`_classify_knowledge` identifies WHAT KIND of knowledge it is, but that classification
doesn't FEED INTO the extraction system. The classification should PASS its findings
to the extraction step — "I found 'pulling' as a relational verb, here's the triple
(tides, pulling, ocean)" — instead of hoping the extraction independently rediscovers
the same relationship.

### Bug 3: Dictionary pollution
**"why" → "the sky blue", "xylophone" → "what is fire"**

Root cause: Same as Bug 1 — the prescan treats question-starting statements as definitions.
But even after fixing Bug 1, there's a deeper issue: the dictionary system has no
**definition quality gate**. When `_dict_define_word!` is called, it stores whatever
it's given without checking:
- Is the word a question word? (why, how, when, where, who, what)
- Is the definition longer than the word it's defining? (absurd definitions)
- Does the definition contain the original question? (circular definition)
- Is the word already defined in this lobe? (should it update or reject?)

### Bug 4: Multipart answers garbled / missing topics
**"what is fire and what is water" → only fire answered**

Root cause: The MultipartOrchestrator decomposes and re-synthesizes, but the
recombination step doesn't guarantee coverage of ALL decomposed parts. This is
a pre-existing issue in the multipart system, not v8.28-specific.

### Bug 5: "Fire" self-reference in emotion responses
**"I feel sad" → "Fire sit via sad"**

Root cause: The voice rendering system applies thesaurus swaps to node content.
The node's system_prompt uses "Grug" but when the topic is about fire/emotion,
the thesaurus swaps "grug" → some synonym that ends up as "Fire" in context.
Actually — looking more carefully, this is the voice_register + drop_table interaction.
The emotional response nodes have "fire" as a key concept in their drop_table,
and the thesaurus is substituting "Grug" with "Fire" because they're in the same
semantic cluster. This is a thesaurus context-blindness problem.

## The Structural Insight: What Governance Tool Is Missing?

All five bugs share a common theme: **individual subsystems make local decisions
without consulting a shared intent/context model.**

1. The prescan decides "this is a definition" without checking intent
2. The classifier decides "this is relational" without connecting to extraction
3. The dictionary accepts definitions without quality gates
4. The thesaurus swaps words without understanding context role
5. The multipart system decomposes without tracking coverage

What's missing is a **ConversationIntent** layer — a lightweight context object
that gets built ONCE per input and then flows through the entire processing pipeline.
Right now, each subsystem independently re-derives what the input "means":

- `_conversation_prescan` derives intent (question/define/teach/correct)
- `_classify_knowledge` re-derives knowledge type from the definition text
- `extract_relational_triples` re-derives relationships from the text again
- The thesaurus has no access to intent at all
- The dictionary has no access to intent at all

A ConversationIntent object would carry:
- `raw_input`: the original text
- `intent`: :question / :define / :teach / :correct / :answer / :greeting / :statement
- `topic`: what the input is ABOUT (extracted noun phrase)
- `question_words`: any interrogatives detected (how, why, when, where)
- `subject_hint`: which lobe/subject area (if specified)
- `relational_indicators`: which words triggered relational classification
- `knowledge_type`: :static / :procedural / :relational
- `confidence`: how confident the classification is

This intent object would be built by the prescan and then PASSED DOWN to every
subsystem that currently re-derives its own classification. The key insight is:

**CLASSIFY ONCE, USE EVERYWHERE**

Instead of each subsystem independently trying to understand the input,
the prescan does it once and the result flows through the pipeline. This:
- Prevents contradictions (prescan says "question" but define handler says "definition")
- Enables cross-subsystem awareness (thesaurus knows this is a question, don't swap key words)
- Makes the classification+extraction pipeline coherent (classification feeds extraction)
- Enables quality gates (dictionary can check "was this word a question word in the intent?")

## Implementation Priority

1. **Immediate fix**: Add question-word guard to prescan `X is/are Y` pattern
   - If the matched "word" is in {"how", "why", "when", "where", "who", "what"},
     return `nothing` instead of `:define`
   - This fixes Bugs 1 and 3 immediately

2. **Medium fix**: Feed classification indicators to triple extraction
   - When `_classify_knowledge` returns `:relational`, also return WHICH
     indicator words were found and WHERE they are in the text
   - Pass these to `extract_relational_triples` as hints so it can extract
     (subject, indicator_verb, object) even when the verb isn't in the registry
   - This fixes Bug 2

3. **Structural fix**: Build a ConversationIntent object
   - This is the governance tool that's missing
   - It would replace the scattered 4-tuple return from prescan
   - It would flow through process_mission and be accessible to all handlers
   - It would enable the dictionary quality gate, the thesaurus context gate, etc.
