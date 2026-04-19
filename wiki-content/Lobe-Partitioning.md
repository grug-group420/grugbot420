# Lobe Partitioning

Lobes are domain-specific partitions that group related nodes and reduce cross-domain noise.

## Why Lobes?

Without lobes, all nodes compete in one flat global arena. Lobes improve:
- **Search locality** — scan only relevant nodes
- **Routing quality** — signals stay in-domain
- **Cross-domain propagation** — connected lobes share signals with controlled decay
- **Debugging** — inspect per-domain behavior independently

## Limits

- **20,000 nodes** per lobe (hard cap)
- **64 lobes** maximum

## Creating Lobes

```
/newLobe language "natural language processing"
/newLobe emotions "emotional intelligence and tone"
/newLobe vision "visual and image processing"
```

## Connecting Lobes

```
/connectLobes language emotions
```

Connected lobes propagate signals bidirectionally with **60% decay per hop**.

## Growing Nodes Into Lobes

```
/lobeGrow language {"nodes":[{"pattern":"syntax grammar parse","action_packet":"analyze^3"}]}
```

## Inspecting

```
/lobes                          # All lobes: node counts, connections, fire counts
/tableStatus <lobe_id>          # Hash table chunk sizes
/tableMatch <lobe_id> <chunk> <pattern>   # Pattern-activate entries
```

## Lobe Tables (`src/LobeTable.jl`)

Each lobe has a chunked hash table with:
- **nodes** chunk — node references
- **json** chunk — JSON data storage
- **drop** chunk — drop table entries
- **hopfield** chunk — per-lobe Hopfield cache
- **meta** chunk — metadata
