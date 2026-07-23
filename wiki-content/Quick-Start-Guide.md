# Quick Start Guide

This guide walks you through your first session with grugbot420.

## 1. Launch

```bash
./grugbot420
```

You'll see the `Brain >` prompt. The specimen starts empty — zero nodes, zero lobes.

## 2. Grow Your First Nodes

Plant some seed nodes using `/grow`:

```
Brain > /grow {"nodes":[{"pattern":"hello greeting hi","action_packet":"greet^3 | welcome^2 | smile^1","data":{"system_prompt":"Friendly greeting mode."}}]}
```

This creates one node that:
- **Matches** inputs containing "hello", "greeting", or "hi"
- **Proposes** the actions `greet` (weight 3), `welcome` (weight 2), `smile` (weight 1)

## 3. Send Your First Mission

```
Brain > /mission hello there
```

The engine scans all nodes against your input, runs the vote, and produces a response. You'll see which node fired, the action chosen, and the confidence level.

## 4. Give Feedback

If the response was bad:

```
Brain > /wrong
```

This penalizes every node that voted via strength decay. Nodes that reach 0 strength become graves.

## 5. Create Domain Partitions

Organize nodes into lobes for different topics:

```
Brain > /newLobe language "natural language processing"
Brain > /newLobe emotions "emotional intelligence and tone"
Brain > /lobeGrow language {"nodes":[{"pattern":"syntax grammar parse","action_packet":"analyze^3 | explain^2"}]}
```

## 6. Add Orchestration Rules

Rules are injected into every response and support template tags:

```
Brain > /addRule Always ground responses in {MISSION} before expanding.
Brain > /addRule If confidence {CONFIDENCE} is below 0.5, hedge your answer. [prob=0.7]
```

## 7. Save Your Specimen

Once you've grown something worth keeping:

```
Brain > /saveSpecimen my_first_specimen.specimen.gz
```

Load it later:

```
Brain > /loadSpecimen my_first_specimen.specimen.gz
```

## 8. Check System Health

```
Brain > /status
Brain > /nodes
Brain > /lobes
```

## Developmental Stages

| Stage | Node Count | Behavior |
|-------|-----------|----------|
| **New** | < 1,000 | No idle systems. Manual growth only. You control topology. |
| **Maturing** | 1,000+ | Immune system activates. Idle chatter and phagy begin. |
| **Mature** | Large | Self-maintaining. Chatter consolidates. Phagy prunes waste. |

The first ~100 nodes are the specimen's DNA. Seed orthogonal archetypes — distinct semantic poles, not 50 near-identical nodes.

## Next Steps

- [[CLI Command Reference]] — Full command list
- [[Seeding a New Specimen]] — Best practices for early growth
- [[Action Packet Format]] — How to write action packets
- [[Architecture Overview]] — How the engine works under the hood
