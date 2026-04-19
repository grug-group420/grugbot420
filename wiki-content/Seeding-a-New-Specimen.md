# Seeding a New Specimen

The first ~100 nodes are the specimen's DNA. Before hitting 1,000 nodes, automatic neighbor latching is suppressed — you control topology manually.

## Principles

1. **Seed orthogonal archetypes** — distinct semantic poles, not 50 near-identical nodes
2. **Use `required_relations`** as semantic gates from day one so nodes don't fire on noise
3. **Name action packets deliberately** — distinct action families give the orchestrator meaningful material
4. **Wire drop tables manually** for known co-activation pairs

## Example: Building a Well-Rounded Specimen

### Step 1: Core Archetypes

Start with 5-10 broad archetypes covering different domains:

```
/grow {"nodes":[{"pattern":"greeting hello hi welcome","action_packet":"greet^3 | welcome^2 | smile^1","data":{"system_prompt":"Friendly greeting mode."}}]}

/grow {"nodes":[{"pattern":"explain define describe clarify","action_packet":"explain[dont oversimplify]^3 | clarify^2 | elaborate^1","data":{"system_prompt":"Educational explanation mode."}}]}

/grow {"nodes":[{"pattern":"sad unhappy depressed worried","action_packet":"comfort[dont dismiss]^3 | validate^2 | support^1","data":{"system_prompt":"Emotional support mode."}}]}

/grow {"nodes":[{"pattern":"code program debug error","action_packet":"analyze^3 | reason[dont hallucinate]^2 | explain^1","data":{"system_prompt":"Technical debugging mode."}}]}

/grow {"nodes":[{"pattern":"danger warning threat risk","action_packet":"alert^3 | warn^2 | caution^1","data":{"system_prompt":"Safety alert mode."}}]}
```

### Step 2: Create Lobes

```
/newLobe social "greetings and social interaction"
/newLobe technical "code and technical topics"
/newLobe emotional "feelings and emotional support"
/newLobe safety "warnings and risk assessment"
```

### Step 3: Wire Connections

```
/connectLobes social emotional
/connectLobes technical safety
```

### Step 4: Add Rules

```
/addRule Always acknowledge the user's {MISSION} before responding.
/addRule When {VOTE_CERTAINTY} is UNSURE, present alternatives: {TIED_ALTERNATIVES} [prob=0.8]
/addRule Ground technical responses in specifics, not generalities. [prob=0.9]
```

### Step 5: Test and Iterate

```
/mission hello, can you help me debug this error?
```

Watch which nodes fire. Use `/wrong` for bad responses. Use `/nodes` to inspect strengths. Save checkpoints with `/saveSpecimen`.

## Growth Milestones

| Nodes | What Happens |
|-------|-------------|
| 0-100 | DNA phase. Full manual control. Seed carefully. |
| 100-500 | Topology forming. Patterns start competing meaningfully. |
| 500-1,000 | Approaching maturity. Vote resolution becomes richer. |
| 1,000+ | **Immune system activates.** Chatter and phagy begin. Self-maintenance starts. |

## Common Mistakes

- ❌ Planting 50 nodes with similar patterns (they'll all compete, none will be strong)
- ❌ Skipping drop tables (no co-activation means flat topology)
- ❌ Using identical action packets (orchestrator can't differentiate)
- ❌ Growing too fast without testing (save specimens early and often)
- ✅ Start sparse, test often, save checkpoints, expand gradually
