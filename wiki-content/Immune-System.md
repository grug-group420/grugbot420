# Immune System

Once a specimen reaches maturity (≥ 1,000 nodes), an automata-based immune system activates to protect the node population from funky inputs. This is biological: tolerance-based, stochastic, and imperfect by design.

## How It Works

1. **AST Scan** — Every structure-storing command gets a structural scan producing an AST signature (structural fingerprint)
2. **Hopfield Immune Memory** — Non-funky signatures stored in attractor memory. Repeated safe inputs strengthen their basin.
3. **Funky Detection** — Signatures not matching known patterns are flagged as funky
4. **Population Coinflip** — Funky inputs trigger automata (1/3 of node count). Each coinflips (50/50) before intervening.
5. **Quarantine → Patch → Delete** — Materialized agents quarantine, attempt patching within stochastic timer, delete on failure.
6. **No Silent Failures** — Every decision logged in append-only immune ledger.

## Key Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `MATURITY_THRESHOLD` | 1,000 | Immune system sleeps below this |
| `AUTOMATA_POPULATION_RATIO` | 1/3 | Automata count = nodes ÷ 3 |
| `COINFLIP_PROBABILITY` | 0.5 | Per-agent materialization chance |
| `PATCH_TIMEOUT_SECONDS` | 2.0 | Max patch time (± 0.5s jitter) |
| `HOPFIELD_FAMILIARITY_THRESHOLD` | 3 | Sightings before "strongly known" |

## Gated Commands

**Critical gates (⚡):**
- `/grow` — modifies node population
- `/lobeGrow` — grows nodes into lobes
- `/loadSpecimen` — replaces entire brain state

**Standard gates:**
`/addRule`, `/pin`, `/addVerb`, `/addRelationClass`, `/addSynonym`, `/newLobe`, `/connectLobes`, `/negativeThesaurus add`, `/nodeAttach`, `/imgnodeAttach`

**Exempt (read-only):**
`/mission`, `/wrong`, `/explicit`, `/nodes`, `/status`, `/lobes`, `/listVerbs`, `/thesaurus`, `/help`, `/arousal`, `/saveSpecimen`, `/attachments`, `/nodeDetach`, `/imgnodeDetach`

## Rejection Example

```
[IMMUNE] ⛔ /grow REJECTED by immune system: Funky input failed patching and was deleted
```

Full specification: [`docs/immune_system.html`](https://github.com/grug-group420/grugbot420/blob/main/docs/immune_system.html)
