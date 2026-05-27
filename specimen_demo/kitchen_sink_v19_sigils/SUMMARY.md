# Kitchen Sink v19 — SigilRegistry (Stage 1) End-to-End Demo

**Module:** `src/SigilRegistry.jl`
**Tests:** `test/test_sigil_registry.jl` (158 assertions, all green)
**Demo run log:** `run.log` (190 lines)
**Audit dump:** `audit_dump.json` (machine-readable snapshot)

## What this validates

The Stage 1 sigil registry kernel — a single source of truth for typed
symbolic handles (`&n`, `&word`, `&rest`, `&noun`, etc.) used in pattern
matching and (in later stages) cross-subsystem semantic propagation.

Stage 1 scope (locked in):

- **Active classes:** `:lambda`, `:macro`, `:tag`
- **Active phases:** `:bind`, `:match`
- **Reserved classes** (registered for forward-compat, rejected in patterns):
  `:glue` (Stage 2), `:functor` (Stage 6), `:procedure` (Stage 6)
- **Reserved phases:** `:vote_shape`, `:tone`, `:render`, `:thesaurus`,
  `:drop_table`, `:inhibit`, `:relation`
- **Engine-default registry ships:** `&n`, `&word`, `&rest`, `&noun`
- **Zero-cost fast path:** patterns with no `&` allocate nothing — old
  specimens are bit-identical to pre-sigil behaviour.
- **NO SILENT FAILURES:** every malformed input throws a typed error.

## Phases exercised

1. **Engine default registry** — 4 entries built and listed.
2. **Specimen-level registry + merge policies** — built a 6-entry
   specimen (3 active classes + 2 reserved-class forward-compat entries),
   merged it on top of the engine default with all three policies:
   - `:error` (default) — collision throws, target unchanged.
   - `:keep` — engine retained on collision (opt-in silent drop).
   - `:overwrite` — specimen wins (typical specimen-load path).
3. **Per-class counts and filter discipline** — `list_sigils` filtered by
   each class and each phase, deterministic lexicographic ordering verified.
4. **Pattern parsing battery** — zero-sigil fast path; single-sigil; the
   canonical multi-sigil math pattern (`what is &n + &n equal to`); mixed
   lambda+macro patterns; Greek-letter sigil parsing (`&Σ_greet`) with
   reserved-class gating + `allow_reserved=true` bypass.
5. **Error-path battery (24 typed throws)** — every documented error path
   exercised: bad name shapes, bad class/phase, class/field coherence
   violations, lexicon size+content violations, collision-without-overwrite,
   lookup misses, unknown sigils in patterns, reserved-class gating in
   patterns, MAX_SIGILS_PER_PATTERN cap, bad filter values, bad merge policy.
6. **Audit dump** — JSON snapshot of merged registry + error log.

## Test suite parity

`test/test_sigil_registry.jl` covers the same surface as a unit-test suite,
mirroring the `test_self_observer.jl` discipline:

- 158 assertions across 22 testsets
- Every documented error path asserted with `@test_throws` on the specific
  error type
- Schema invariants (`SigilEntry` immutability, exact field tuple, closed
  enum arity) asserted

```
SigilRegistry — full surface
  constants + closed enums                                        22 / 22
  SigilTable construction                                          4 /  4
  register_sigil! — name validation                                6 /  6
  register_sigil! — class & applies_at validation                  3 /  3
  register_sigil! — class/field coherence                          7 /  7
  register_sigil! — happy paths for active classes                19 / 19
  register_sigil! — collision policy                               4 /  4
  register_sigil! — lexicon size + content validation              3 /  3
  register_sigil! — expansion field is reserved                    3 /  3
  register_sigil! — registry size cap                              3 /  3
  lookup_sigil + has_sigil                                         6 /  6
  list_sigils — filters and deterministic order                    6 /  6
  clear_registry!                                                  3 /  3
  parse_sigil_token — pure syntax                                 10 / 10
  resolve_sigils_in_pattern — fast path                            4 /  4
  resolve_sigils_in_pattern — happy path                          11 / 11
  resolve_sigils_in_pattern — unknown sigil throws with context    4 /  4
  resolve_sigils_in_pattern — reserved class gating                3 /  3
  resolve_sigils_in_pattern — reserved phase gating                3 /  3
  resolve_sigils_in_pattern — MAX_SIGILS_PER_PATTERN               2 /  2
  default_registry — exact contents + provenance                  16 / 16
  merge_registry! — three conflict policies                       10 / 10
  Greek-letter names accepted                                      3 /  3
  SigilEntry immutability + schema shape                           3 /  3
                                                              -------------
                                                              158 / 158
```

## Public API surface (re-exported by GrugBot420)

**Types:**
- `SigilEntry` (immutable, 8 fields)
- `SigilTable` (mutable, holds entries dict + label)
- `SigilTokenRef` (resolved sigil reference inside a pattern)

**Errors:**
- `SigilError` — generic
- `SigilConfigError` — bad class, malformed shape, schema violation
- `SigilArgumentError` — bad caller input
- `SigilResolutionError` — pattern referenced unknown sigil

**Functions:**
- `register_sigil!`, `lookup_sigil`, `has_sigil`, `list_sigils`,
  `clear_registry!`
- `parse_sigil_token`, `resolve_sigils_in_pattern`
- `default_registry`, `merge_registry!`

**Constants:**
- `SIGIL_PREFIX`, `SIGIL_CLASSES`, `SIGIL_APPLIES_AT`
- `SIGIL_NAME_REGEX`, `SIGIL_TOKEN_REGEX`

## What is INTENTIONALLY out of scope (parked for later stages)

- **Stage 2:** `:glue` semantics (compound-prompt sub-vote splitting), macro
  lexicon expansion at bind time.
- **Stage 3:** runtime evaluator system / computed votes (math values
  actually parsed and evaluated, not pulled from a static pool).
- **Stage 4-5:** dynamic relational triples (advanced relational input).
- **Stage 6:** `:functor` semantics (phase-pipeline morphisms), `:procedure`
  expansion (Antikythera-style event-alignment compression — the user's
  ancient-mechanical-computers / Greek-math-acronym idea — already has its
  `expansion::Vector{Any}` field reserved on every entry, so adding the
  procedure runtime in Stage 6 is purely additive, no schema change).
- **Stage 7:** ActionTonePredictor v2 — sigil-aware tone metadata.
- **Stage 8:** cross-subsystem propagation (thesaurus, drop-tables,
  inhibitions, etc. consuming sigils directly).

The `expansion` field is present on every `SigilEntry` today, even though
only `:procedure` will use it; this is the locked-in forward-compat hook
so the schema does not need to change between Stage 1 and Stage 6.
