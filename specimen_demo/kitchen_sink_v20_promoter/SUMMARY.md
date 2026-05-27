# Kitchen Sink v20 — Stage 1.5a Sigil Promoter (Front-Door Compression)

**Status:** ✅ PASSED — 7/7 surface variants → 1 node fires (population compression).

## What this demo proves

Stage 1.5a wires a **two-layer input promoter** at the engine's front door
(the very top of `scan_and_expand`). Before the matcher sees anything, raw
user input flows through:

1. **Layer 1 — thesaurus canonicalization.** `"two plus two"` → `"2 + 2"`,
   case-folded, whitespace-normalized. Closed maps: `NUMBER_WORD_MAP` (0–100),
   `OP_WORD_MAP` (`plus`/`minus`/`times`/`divided by`/`equals`),
   `SIGN_PREFIX_MAP` (`negative`/`positive`).

2. **Layer 2 — registry shape promotion.** `"2 + 2"` → `"&n &op &n"`. Driven
   by `SigilEntry.promote_at_tokenize::Bool` flag on the registry — only
   sigils that opt in get promoted. Stage 1.5a flags `&n` and `&op`.

The matcher downstream just compares strings. Many surface variants of the
same shape collapse onto **one pattern bucket → one node**.

## The headline

| Raw Input | Promoted | Node Fired |
|-----------|----------|-----------:|
| `what is 2 + 2`             | `what is &n &op &n` | `node_0` |
| `what is 2+2`               | `what is &n &op &n` | `node_0` |
| `what is two plus two`      | `what is &n &op &n` | `node_0` |
| `what is 2 plus two`        | `what is &n &op &n` | `node_0` |
| `what is two plus 2`        | `what is &n &op &n` | `node_0` |
| `WHAT is TWO Plus 2`        | `what is &n &op &n` | `node_0` |
| `  what is  2  +  2  `      | `what is &n &op &n` | `node_0` |

**`node_0`: 7/7 fires.** One pattern, one node, every variant.

## Bindings (position-keyed side-channel)

For all 7 variants the promoter produces an identical
`Vector{SigilBinding}`:

```
[ pos=2  &n=2     class=:lambda
  pos=3  &op="+"  class=:lambda
  pos=4  &n=2     class=:lambda ]
```

Stashed in task-local storage by `scan_and_expand`. Read with
`current_promotion_bindings()` from any downstream phase. Stage 1.5b will
have ActionTonePredictor consume these for arithmetic dispatch.

## Confidence-equivalence guarantee

Pure-text inputs (no digits, no math-words) round-trip **byte-identical**
with empty bindings:

| Input | Promoted | Bindings |
|-------|----------|----------|
| `hello world`                     | `hello world`                     | `[]` |
| `the cat sat on the mat`          | `the cat sat on the mat`          | `[]` |
| `fire makes grug warm and happy`  | `fire makes grug warm and happy`  | `[]` |
| `sun shine bright today`          | `sun shine bright today`          | `[]` |

Every existing test in the suite — none of which uses arithmetic input —
sees byte-identical scanner inputs before and after wiring. Confirmed by
running `test_comprehensive.jl`, `test_chatter_v2.jl`, `test_v7_21c2.jl`
post-wire: all pass.

## Idempotency

```
promote(promote("what is 2 + 2"))
  == promote("what is 2 + 2")
  == "what is &n &op &n"
```

The second pass produces the same string with **zero new bindings** — sigil
tokens (`&n`, `&op`) are preserved verbatim by the tokenizer's first-alt
regex match. Critical for safe re-application during the matcher's
expansion passes.

## Files involved

- `src/SigilRegistry.jl` — added `promote_at_tokenize::Bool` field,
  validation, default-registry entry for `&op`, `&n` flagged true.
- `src/SigilPromoter.jl` (NEW) — two-layer promoter, closed canonical
  maps, sign-prefix peek, position-keyed bindings, error types.
- `src/engine.jl` — guarded include of registry+promoter, const
  `_ENGINE_SIGIL_TABLE`, task-local stash, `scan_and_expand` wired at
  the front door.
- `test/test_sigil_registry.jl` — 171/171 ✓
- `test/test_sigil_promoter.jl` (NEW) — 226/226 ✓
- `test/runtests.jl` — added `test_sigil_promoter.jl` to ALL_TESTS

## Stage 1.5b (parked)

Reads from `current_promotion_bindings()`:

- ATP arithmetic dispatch branch (`ACTION_COMPUTE` action class).
- Render-side substitution (rebuild reply text from bindings).
- Compound number-words (`twenty-three` → `23`).
- Word-form decimals (`two point five` → `2.5`).
- Context-sensitive `is` (definitional copula vs equality op).
- Multi-character operators (`==`, `<=`, `!=`).
- True signed-numeric tokenization (unary sign vs binary op disambiguation).
