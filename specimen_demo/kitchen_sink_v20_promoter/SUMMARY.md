# Kitchen Sink v20 — Stage 1.5a + 1.5a-fix-1 + 1.5c (Sigil Promoter)

**Status:** ✅ PASSED — every phase green.

## Three stages, one demo

| Stage | What it adds | Demo phase |
|---|---|---|
| **1.5a**       | Two-layer front-door promoter; population compression. | Phases 1–5 |
| **1.5a-fix-1** | Surface preservation; `.surface` + `.raw_position` on bindings; `current_promotion_raw()` accessor. | Phase 6 |
| **1.5c**       | Conditional `promote_predicate::Function` on registry entries; end-user discretion (functor / token / conditional triplet). | Phase 7 |

## Phase 4 headline (1.5a)

```
node_0   7/7 fires   ★ MATH NODE
```

Seven surface variants of "what is 2+2" — `2+2`, `two plus two`, `WHAT is TWO Plus 2`, mix-and-match — **all collapse to one canonical matcher input** (`what is &n &op &n`) and **fire the same node**. Population compression in real engine plumbing.

## Phase 6 headline (1.5a-fix-1)

```
[caps preserved]
  raw       = "WHAT IS TWO PLUS TWO"
  binding   = name=&n  value=2  surface="TWO"   pos=2 raw_pos=2
  binding   = name=&op value="+" surface="PLUS" pos=3 raw_pos=3
  binding   = name=&n  value=2  surface="TWO"   pos=4 raw_pos=4
```

The user typed `"WHAT IS TWO PLUS TWO"`. The matcher saw `"what is &n &op &n"` (so the math node fired the same way as it would for `"what is 2+2"`). And ATP / AIML can now read:

- `current_promotion_raw()` → `"WHAT IS TWO PLUS TWO"` (verbatim)
- `binding.surface` → `"TWO"`, `"PLUS"`, `"TWO"` (per-binding original tokens)
- `binding.raw_position` → 2, 3, 4 (per-binding index in raw token stream)

So if AIML wants to render back as "TWO PLUS TWO IS FOUR" (matching the user's caps/word register) it can. If ATP wants to read "the user is yelling and writing in words" for tone, it can. Neither was possible in plain Stage 1.5a.

## Phase 7 headline (1.5c)

```
'compute 2 + 3'     → 'compute &n &op &n'   (3 bindings)
'compute 5 + 7'     → 'compute &n &op &n'   (3 bindings)
'compute 500 + 3'   → 'compute 500 &op &n'  (2 bindings)   ← 500 stayed literal
'compute 999 + 888' → 'compute 999 &op 888' (1 bindings)   ← only op promoted
```

The same `&n` registry entry — same name, same `sigil_type=:number` — promotes for `2`, `3`, `5`, `7` but **not** for `500`, `888`, `999`. The end-user-supplied predicate (`v < 100`) gated the promotion per-token. Three treatment modes are now end-user discretion **per sigil entry**:

| Mode | Registry config | Behavior |
|---|---|---|
| **FUNCTOR** | `promote_at_tokenize=false` | Matcher handles entirely at runtime. Front door doesn't touch matching tokens. |
| **TOKEN** | `promote_at_tokenize=true,` `promote_predicate=nothing` | Front door always promotes matching tokens. (Stage 1.5a default for `&n`/`&op`.) |
| **CONDITIONAL** | `promote_at_tokenize=true,` `promote_predicate=fn` | Front door calls `fn(canonical)::Bool`; promotes only when `true`. |

No silent failures: predicate errors and non-`Bool` returns raise `PromoterConfigError`. Setting a predicate without `promote_at_tokenize=true` raises `SigilConfigError` at registration time (would be a silent no-op otherwise).

## Files involved

- `src/SigilRegistry.jl`
  - Stage 1.5a: `promote_at_tokenize::Bool`
  - Stage 1.5c: `promote_predicate::Union{Nothing,Function}` field, validation, `register_sigil!` kwarg
- `src/SigilPromoter.jl`
  - Stage 1.5a: two-layer promoter, `SigilBinding`
  - Stage 1.5a-fix-1: `surface::String` + `raw_position::Int` on `SigilBinding`; tokenizer returns `(token, raw_pos)` tuples
  - Stage 1.5c: `_predicate_allows` gate; `PromoterConfigError` on predicate failure
- `src/engine.jl`
  - Stage 1.5a: `_ENGINE_SIGIL_TABLE`, task-local stash, `scan_and_expand` front-door wire
  - Stage 1.5a-fix-1: `_PROMOTION_RAW_KEY`, `current_promotion_raw()` accessor
- `src/GrugBot420.jl` — re-exports
- `test/test_sigil_registry.jl` — **177/177** ✓
- `test/test_sigil_promoter.jl` — **284/284** ✓

## Stage 1.5b (still parked)

Reads from `current_promotion_bindings()` and `current_promotion_raw()`:

- ATP arithmetic dispatch branch (`ACTION_COMPUTE` action class).
- Render-side substitution using `binding.surface` (echo back in user's register).
- Compound number-words (`twenty-three` → `23`).
- Word-form decimals (`two point five` → `2.5`).
- Context-sensitive `is` (definitional copula vs equality op).
- Multi-character operators (`==`, `<=`, `!=`).
- True signed-numeric tokenization (unary sign vs binary op disambiguation).
