# Specimen Persistence

grugbot420 supports full long-term persistence via specimen files — gzip-compressed JSON snapshots of the entire cave state.

## Saving

```
/saveSpecimen mycave.specimen.gz
```

## Loading (Restoring)

```
/loadSpecimen mycave.specimen.gz
```

⚠️ **Destructive operation** — current state is completely wiped and replaced. File is validated before any state is wiped. If validation fails, zero changes are made.

## What Gets Saved

| # | Category | Description |
|---|----------|-------------|
| 1 | **nodes** | Full Node structs — id, pattern, signal, action_packet, strength, neighbors, graves, drop_table, response_times, hopfield_key, relational_patterns, throttle, json_data |
| 2 | **hopfield_cache** | Familiar input fast-path cache (UInt64 hash → node IDs) |
| 3 | **rules** | Stochastic orchestration rules (text + fire probability) |
| 4 | **message_history** | Up to 10,000 ChatMessage entries with pin flags |
| 5 | **lobes** | Subject, node_ids, connected_lobe_ids, fire/inhibit counts |
| 6 | **node_to_lobe_idx** | Reverse index (node → lobe mapping) |
| 7 | **lobe_tables** | All chunks (nodes, json, drop, hopfield, meta) |
| 8 | **verb_registry** | Verb classes, verbs, and synonym normalizations |
| 9 | **thesaurus_seeds** | Synonym seed map (defaults + runtime additions) |
| 10 | **inhibitions** | NegativeThesaurus entries (word, reason, timestamp) |
| 11 | **arousal** | EyeSystem state (level, decay_rate, baseline) |
| 12 | **id_counters** | NODE ID_COUNTER and MSG_ID_COUNTER |
| 13 | **brainstem** | Dispatch count and propagation history |
| 14 | **attachments** | Target → attached node mappings with patterns and signals |
| 15 | **trajectory** | ActionTonePredictor ring buffer + config |
| 16 | **temporal_coherence** | ImageSDF timing patterns and coherence scores |
| 17 | **morph_cooldowns** | ChatterMode 24h morph cooldown timestamps |

## Restore Order

```
id_counters → verb_registry → thesaurus_seeds → lobes → lobe_tables → nodes →
node_to_lobe_idx → hopfield_cache → rules → inhibitions → message_history →
arousal → brainstem → attachments → trajectory → temporal_coherence → morph_cooldowns
```

Upstream entities are restored before downstream references (e.g., lobes exist before nodes reference them).

## File Format

- **Extension:** `.specimen.gz` (convention, not enforced)
- **Compression:** gzip (system `gzip`/`gunzip` via pipeline)
- **Content:** Pretty-printed JSON (human-readable when decompressed)
- **Metadata:** `_meta` section records version, timestamp, format identifier
