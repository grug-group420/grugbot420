# Decoherence Analysis — grug_comprehensive_full.specimen

## Issues Found

### 1. have_faith → should be "trust" (thesaurus synonym leak)
**Turn 8**: "It is care and have_faith and wanting good for another"
- The thesaurus maps "trust" → aliases including "have_faith", but the engine picked the alias instead of the canonical
- FIX: Remove "have_faith" from thesaurus, or ensure the system_prompt uses the word "trust" directly

### 2. "Grug spin to greeting" — nonsense phrase (Turn 2)
- The AIML orchestrator is generating "Grug spin to greeting" from some rule or template
- "spin to" is not meaningful English
- This appears to be from the template construction where it substitutes the lobe name
- FIX: This is an engine behavior — need to check if it's from AIML template interpolation

### 3. "Grug articulate of fire" — wrong verb (Turn 24)
- "articulate of" is not proper Grug-speak
- Should be "speak of" or "think on"
- Appears to be thesaurus/verb_registry substituting "articulate" for "speak"

### 4. "Adore" instead of "Love" (Turn 25)
- Multipart question "what is love and what is courage" → response uses "Adore" instead of "Love"
- Thesaurus is replacing the canonical word with an alias
- FIX: The thesaurus should not override the primary topic word in the response

### 5. Multipart questions only answer ONE part (Turns 23-25)
- "what is fire and what is water" → only answers about fire
- "why does fire burn and why does water flow" → only answers about fire
- "what is love and what is courage" → only answers about love
- Known issue: InputDecomposer splits but voting pipeline only produces votes from one sub-subject
- Partial fix: Decomposer config needs to work, and multipart orchestrator needs both parts scored

### 6. "Grug title grammar" — wrong verb (Turn 41)
- Should be "Grug speak of grammar" or similar
- Another thesaurus leak — "title" is not a verb that fits here

### 7. Some known topics get "Nothing in the cave" responses
- "what is truth" — no node for "truth"
- "i feel sad" — no node for "sad" (only "sadness")
- "i am afraid" — no node for "afraid" (only "fear")
- "who are you" — no node for identity
- "what is physics" — no node for "physics"
- "what is biology" — no node for "biology"
- "what is civilization" — no node for "civilization"
- FIX: Add missing single-token nodes for these concepts

### 8. Algebra response has empty prefix before "The relation" (Turn 14)
- "Here is the picture:  The relation: algebra finds unknowns."
- Double space + missing content before "The relation"
- The AIML scaffold is inserting the relational triple without proper prefix content

### 9. /answer mechanic: Step 1 fails — existing nodes fire before hippocampal ask
- "what is photosynthesis" matches the "photosynthesis" node already in the specimen (science lobe)
- "what is the derivative of x squared" matches "derivative" node (mathematics lobe)
- "what is chlorophyll" matches "photosynthesis" node (via chlorophyll content)
- The /answer test questions are hitting EXISTING nodes, so no ask is generated
- FIX: Use topics that truly have NO nodes for the /answer test

### 10. "righteous noise" instead of "just noise" (Turn 41)
- "Without grammar words are righteous noise"
- "righteous" doesn't fit — should be "just" or "mere"
- Thesaurus/verb substitution issue
