# Orchestration Rules

Rules are injected into every response payload. They fire stochastically and support template tags.

## Adding Rules

```
/addRule Always ground responses in {MISSION} before expanding.
/addRule If confidence {CONFIDENCE} is below 0.5, hedge your answer. [prob=0.7]
/addRule Current lobe state: {LOBE_CONTEXT} — use cross-domain reasoning. [prob=0.5]
```

Rules with no `[prob=X]` suffix default to `prob=1.0` (always fire).

## Template Tags

| Tag | Expands To |
|-----|-----------|
| `{MISSION}` | Current input text |
| `{PRIMARY_ACTION}` | Winning action |
| `{SURE_ACTIONS}` | Sure basket actions |
| `{UNSURE_ACTIONS}` | Unsure actions |
| `{ALL_ACTIONS}` | All proposed actions |
| `{CONFIDENCE}` | Vote confidence |
| `{NODE_ID}` | Winning node ID |
| `{MEMORY}` | Recent memory context |
| `{LOBE_CONTEXT}` | Active lobe state |
| `{VOTE_CERTAINTY}` | `SURE` or `UNSURE` |
| `{TIED_ALTERNATIVES}` | Non-winning tied actions |

## Examples

**Grounding rule:**
```
/addRule Always acknowledge {MISSION} directly before offering analysis.
```

**Uncertainty handling:**
```
/addRule When {VOTE_CERTAINTY} is UNSURE, also consider: {TIED_ALTERNATIVES} [prob=0.8]
```

**Domain awareness:**
```
/addRule Current lobe state: {LOBE_CONTEXT} — leverage cross-domain patterns. [prob=0.5]
```

**Confidence gating:**
```
/addRule If {CONFIDENCE} exceeds 0.8, respond with high conviction. [prob=1.0]
/addRule If {CONFIDENCE} is below 0.3, explicitly state uncertainty. [prob=0.9]
```

## Immune Gating

Rules are gated by the [[Immune System]] (standard gate, not critical). In mature specimens (1,000+ nodes), funky rule inputs may be rejected.
