# Kitchen Sink v21 — Full-Coverage Specimen with Sigil Architecture

**Status:** ✅ PASSED — 35/35 conversation cycles completed, all lobes exercised, sigil population compression confirmed.

## What this is

The definitive kitchen sink specimen for GrugBot420. It exercises every subsystem in the engine through a coherent, semantically-connected cave graph — including the new Stage 1.5a / 1.5a-fix-1 / 1.5c sigil architecture that makes arithmetic population compression work end-to-end.

## Specimen inventory

| Item | Value |
|---|---|
| Nodes | 46 |
| Lobes | 10 (greeting, comfort, survival, math, knowledge, identity + 4 boot seeds) |
| Lobe tables | 10 |
| Orchestration rules | 10 |
| AIML tribe nodes | 12 (2 per user-created lobe) |
| Relational attachments | 12 (6 targets × 2 siblings) |
| Pinned memories | 6 |
| Negative thesaurus inhibitions | 5 |
| Verb classes | 6 |
| Thesaurus words | 499 |
| Arousal | 0.35 |
| Compressed size | 19,879 bytes |

## Lobe coverage matrix

Every lobe in the specimen got multiple targeted prompts across both `/mission` (standard jitter) and `/brainstorm` (heavy scoped jitter):

| Lobe | Nodes | Prompts hit | Modes |
|---|---|---|---|
| greeting | 3 | `hello hi`, `good morning`, `goodbye see you` | mission + brainstorm |
| comfort | 4 | `i feel sad`, `i am worried`, `i feel lonely`, `thank you` | mission |
| survival | 4 | `danger threat`, `fire burns hot`, `run flee hide`, `watch out careful` | mission + brainstorm |
| **math** | **3** | **9 arithmetic variants** + 2 conditional + 1 pure-text | **mission + brainstorm** |
| knowledge | 6 | `tell about {fire, water, wolf, rock, sky, food}` | mission + brainstorm |
| identity | 6 | `who are you`, `what do you do`, `the tribe`, `the cave`, `speak plain`, `listen first` | mission + brainstorm |

## The headline: Sigil population compression (Stage 1.5a)

The math lobe contains three nodes with sigil patterns:

- `what is &n &op &n` — the canonical arithmetic query
- `compute &n &op &n` — the imperative compute form
- `&n &op &n equals` — the equation form

Nine surface variants of "what is 2+2" were fed through the front-door promoter. Every single one collapsed to the canonical `compute &n &op &n` matcher input and fired **the same node (node_32)**:

| User input | Promoted to | Winning node |
|---|---|---|
| `what is 2 + 2` | `what is &n &op &n` | node_32 |
| `what is two plus two` | `what is &n &op &n` | node_32 |
| `what is 2 plus 2` | `what is &n &op &n` | node_32 |
| `what is two + 2` | `what is &n &op &n` | node_32 |
| `WHAT IS FIVE TIMES THREE` | `what is &n &op &n` | node_32 |
| `what is 7 minus 4` | `what is &n &op &n` | node_32 |
| `what is 3 times 8` | `what is &n &op &n` | node_32 |
| `compute 3 plus 5` | `compute &n &op &n` | node_32 |
| `compute 500 plus 3` | `compute &n &op &n` | node_32 |

**One node per shape, not per variant.** That is population compression.

### Surface preservation (Stage 1.5a-fix-1)

While the matcher sees the canonical form, `current_promotion_raw()` and `binding.surface` preserve the original user tokens. ATP can read tone signals from caps/words/digits. AIML can echo back in the user's register. For `"WHAT IS FIVE TIMES THREE"`:

- `current_promotion_raw()` → `"WHAT IS FIVE TIMES THREE"` (verbatim)
- `binding.surface` → `"FIVE"`, `"TIMES"`, `"THREE"` (per-binding original tokens)

### Conditional predicate (Stage 1.5c)

With a `v < 100` predicate on `&n`, small numbers promote while large ones stay literal:

- `compute 3 plus 5` → `compute &n &op &n` (3 bindings — full promotion)
- `compute 500 plus 3` → `compute 500 &op &n` (2 bindings — 500 stayed literal, 3 promoted)

Three treatment modes per sigil entry, end-user discretion:

| Mode | Registry config | Behavior |
|---|---|---|
| **FUNCTOR** | `promote_at_tokenize=false` | Matcher handles at runtime; front door passes tokens through |
| **TOKEN** | `promote_at_tokenize=true`, `promote_predicate=nothing` | Front door always promotes (Stage 1.5a default for `&n`/`&op`) |
| **CONDITIONAL** | `promote_at_tokenize=true`, `promote_predicate=fn` | Front door calls `fn(canonical)::Bool`; promotes only on `true` |

## Confidence-equivalence guarantee

The pure-text prompt `"what is the meaning of life"` has no math tokens. The promoter passes it through unchanged (empty bindings vector, byte-identical rewrite). The confidence-equivalence guarantee holds in real engine plumbing — the same fallback node that would have fired without the promoter still fires.

## Cross-lobe bridges

The conversation also exercises cross-lobe semantic connections:

- `greeting ↔ comfort`: `"hello i feel sad today"` activates both lobes
- `survival ↔ knowledge`: `"how does fire work"` bridges danger-awareness and factual knowledge
- `math ↔ knowledge`: arithmetic queries carry the `sigil_aware` flag in their json_data

## Routing diversity

35 cycles, 22 distinct winning nodes. No degenerate one-node-wins-everything pattern. The math lobe accounts for 9 cycles (all correctly routed to node_32 via sigil compression), with the remaining 26 cycles distributed across greeting (3), comfort (4), survival (4), knowledge (6), and identity (6) plus 3 cross-lobe cycles.

## Files in this directory

| File | Purpose |
|---|---|
| `seed_v21.txt` | Full seed script — lobe creation, node growth, AIML tribes, attachments, rules, verbs, thesaurus, memory, arousal, save |
| `seed_build.log` | Complete CLI transcript from specimen build |
| `conversation_v21.txt` | Conversation script — 35 missions across all lobes |
| `conversation.md` | Human-readable formatted transcript (1,963 lines) |
| `conversation_raw.log.gz` | Compressed raw CLI log (12,546 bytes) |
| `kitchen_sink_v21.specimen.gz` | The specimen file (19,879 bytes) |

## Subsystems exercised

| Subsystem | How exercised |
|---|---|
| **LobeTable** | 6 user lobes + 4 boot seeds; `create_lobe!`, `connect_lobes!` |
| **Lobe** | All 10 lobes with node counts, lobe-attached growth |
| **LobeOrchestrator** | Cross-lobe connections: greeting↔comfort, survival↔knowledge, math↔knowledge, identity↔comfort |
| **PatternScanner** | Every `/mission` triggers pattern scanning across the node graph |
| **VoteOrchestrator** | Parallel 1000-cap fire + threshold vote pick for all 35 cycles |
| **AIMLNodeSystem** | 12 AIML tribe nodes (2 per user lobe) voting alongside regular nodes |
| **ActionTonePredictor** | Arousal-weighted confidence + tone prediction on every cycle |
| **TonalJudge** | Frame skeleton hints between predictor and scaffold |
| **RelationalJitter** | `/mission` uses standard jitter (0.03); `/brainstorm` uses heavy scoped (0.08) |
| **SemanticVerbs** | 3 relation classes (epistemic, causal, affective), 6 verbs, 3 synonyms |
| **Thesaurus** | 499 words indexed; 5 negative-thesaurus inhibitions (maybe, probably, somewhat, arguably, quite) |
| **BrainStem** | Dispatch + propagation on every scan_and_expand call |
| **ImmuneSystem** | All growth/ledger inputs scanned before touching the graph |
| **SelfObserver** | Subconscious microlog store available (architecturally isolated from vote ranking) |
| **SigilRegistry** | Default 4-sigil registry (`&n`, `&word`, `&rest`, `&noun`); math patterns resolved with `&n` + `&op` |
| **SigilPromoter** | Two-layer front-door promoter; 9 surface variants compressed to canonical form; surface preservation; conditional predicate |
| **ChatterMode** | Idle chatter pipeline available (not exercised in this scripted run) |
| **PhagyMode** | Maintenance pruning available (not exercised in this scripted run) |
| **FullLobeScanner** | Bounded activation scanning for associative memory |
| **ImageSDF / EyeSystem** | Image processing pipeline available (not exercised in this text-only run) |
| **InputQueue** | Queued input processing for chatter mode |
