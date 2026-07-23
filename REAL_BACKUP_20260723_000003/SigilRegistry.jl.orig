# ==============================================================================
# SigilRegistry.jl — GRUG Sigil Registry Kernel (Stage 1)
# ==============================================================================
# !!! GRUG REMINDER — RELATIONAL TRIPLES CAN USE SIGILS !!!
# Sigils are not only for flat patterns. A RelationalTriple's subject /
# relation / object fields may ALSO contain sigil tokens (&n, &word, &noun,
# specimen macros). When resolving / matching relational triples, run the same
# sigil resolution path you use for patterns. Triple fields are NOT guaranteed
# to be literal words.
# ==============================================================================
# GRUG say: every smart system have many small word-pictures (verbs, thesaurus,
#           drops, AIML keys, lobe subjects). Each one have its OWN little
#           dictionary. They drift apart over time. Bug in one, no help to other.
# GRUG say: sigil is one little name shared by all. Write once, look up many.
# GRUG say: token sigil = hole in pattern. "&n" mean "any number here".
#           "&noun" mean "any noun from list". Lambda or macro, registry says.
# GRUG say: registry kernel — small, dumb, well-tested, fail loud. Other modules
#           layer on top. If kernel break, everything break, so kernel must
#           be tiny and right.
# GRUG say: NO SILENT FAILURES. Unknown sigil at bind-time = THROW.
#           Bad class = THROW. Bad applies_at = THROW. Empty name = THROW.
#           Nothing here returns nothing-on-error. Errors are loud.
# GRUG say: ZERO RUNTIME COST when no sigils used. Pattern with no `&` walks
#           a fast path that does not allocate. Old specimens behave bit-identical.
# ==============================================================================
#
# ACADEMIC: This module implements the sigil registry kernel — a single source
# of truth for typed symbolic handles used across pattern matching and (in
# later stages) cross-subsystem semantic propagation. Stage 1 scope:
#   - Registry data model (entry struct, registry struct, error types).
#   - Token-sigil classes activated: :lambda, :macro, :tag.
#     (:glue, :functor, :procedure are reserved enum values, not implemented.)
#   - Pattern-string parsing: extract `&name` tokens, resolve against registry,
#     fail loud on unknown.
#   - Engine-default registry shipping `&n`, `&word`, `&rest`, `&noun`.
#   - Backward compat: zero-sigil patterns get a fast-path "no sigils" return.
#   - `expansion::Union{Nothing,Vector}` field reserved on every entry for the
#     Stage 6 :procedure class — adding procedure entries later is purely
#     additive, no schema change.
#
# What is INTENTIONALLY out of scope for Stage 1 (deferred to later stages):
#   - Glue-class semantics (compound prompts, sub-vote splitting).
#   - Functor-class semantics (phase-pipeline morphisms).
#   - Procedure-class expansion (named ordered chains).
#   - Macro lexicon expansion at bind time (the macro class is recognized,
#     but actual alternation expansion is a Stage 2 concern).
#   - Cross-subsystem propagation (thesaurus, drop-tables, inhibitions, etc.).
#   - Runtime evaluator system / computed votes.
#   - Dynamic relational triples.
#
# This module is the FOUNDATION. Every later stage extends it without revising
# the schema. The class enum is open (`Symbol`-typed); the entry struct already
# has the fields later stages will fill in.
# ==============================================================================

module SigilRegistry

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ==============================================================================
# EXPORTS
# ==============================================================================

export SigilEntry, SigilTable, SigilTokenRef
export SigilError, SigilConfigError, SigilArgumentError, SigilResolutionError
export register_sigil!, lookup_sigil, has_sigil, list_sigils, clear_registry!
export resolve_sigils_in_pattern, parse_sigil_token
export default_registry, merge_registry!
export SIGIL_CLASSES, SIGIL_APPLIES_AT, SIGIL_PREFIX
export SIGIL_NAME_REGEX, SIGIL_TOKEN_REGEX
export set_dict_word_checker!, get_dict_word_checker

# GRUG v9: Dictionary word checker Ref — set by Main.jl after dictionaries load.
# The &define sigil's promote_predicate reads this Ref at promote time.
# Initially returns false (no dictionary words known). Main.jl sets this
# to _dict_has_word once _LOBE_DICTIONARIES is populated.
const _DICT_WORD_CHECKER::Ref{Function} = Ref{Function}((_ -> false))

"""
    set_dict_word_checker!(fn::Function)

Set the dictionary word checker function used by &define sigil's
promote_predicate. Call this after dictionaries are loaded so the
sigil can promote tokens that have dictionary entries.
"""
function set_dict_word_checker!(fn::Function)
    _DICT_WORD_CHECKER[] = fn
end

"""
    get_dict_word_checker() -> Function

Return the current dictionary word checker function.
"""
function get_dict_word_checker()::Function
    return _DICT_WORD_CHECKER[]
end

# ==============================================================================
# ERROR TYPES — GRUG: NO SILENT FAILURES on programmer errors.
# ==============================================================================
# GRUG: Same shape as SelfObserver: distinct types per category so callers can
# pattern-match. Public API throws on bad input or unknown sigil — these are
# always programmer errors. There is no "fall back to no-op" branch, ever.

"""
Generic SigilRegistry error. Carries `message` and a free-form `context`
string for log/audit traces.
"""
struct SigilError <: Exception
    message::String
    context::String
end

"""
Configuration error — bad class name, bad applies_at value, malformed entry
shape, schema violation. Indicates the registry was assembled wrong.
"""
struct SigilConfigError <: Exception
    message::String
    field::String
end

"""
Argument error — caller passed bad type, empty name, nil registry, etc.
Indicates the caller used the API wrong.
"""
struct SigilArgumentError <: Exception
    message::String
    arg::String
end

"""
Resolution error — a pattern referenced a sigil that doesn't exist in the
registry. This is a bind-time programmer error: every `&name` in a pattern
MUST resolve, or the node refuses to load.
"""
struct SigilResolutionError <: Exception
    message::String
    sigil_name::String
    pattern::String
end

function Base.showerror(io::IO, e::SigilError)
    print(io, "SigilError: ", e.message, " (context=", e.context, ")")
end
function Base.showerror(io::IO, e::SigilConfigError)
    print(io, "SigilConfigError: ", e.message, " (field=", e.field, ")")
end
function Base.showerror(io::IO, e::SigilArgumentError)
    print(io, "SigilArgumentError: ", e.message, " (arg=", e.arg, ")")
end
function Base.showerror(io::IO, e::SigilResolutionError)
    print(io, "SigilResolutionError: ", e.message,
          " (sigil=&", e.sigil_name, ", pattern=\"", e.pattern, "\")")
end

# ==============================================================================
# CONSTANTS — GRUG: small closed sets, locked at engine version. Adding to
# either set is an engine-version event, not a runtime knob.
# ==============================================================================

# GRUG: sigil prefix character. Single ASCII byte chosen to avoid collision
# with Julia's `@` (macros) and `:` (symbols). Reads naturally in patterns.
const SIGIL_PREFIX::Char = '&'

# GRUG: closed enum of sigil classes. Stage 1 implements :lambda, :macro, :tag.
# :glue, :functor, :procedure are RESERVED — their registry entries are accepted
# but cannot yet appear in a pattern (would throw at parse time). Reservation
# is so Stage 2+ can add them without revising the registry schema.
const SIGIL_CLASSES::NTuple{8,Symbol} = (
    :lambda,    # parametric position; binds value at match time. Stage 1.
    :macro,     # alternation family; expands to alternatives at bind. Stage 1.
    :tag,       # annotation; carries no value, no expansion. Stage 1.
    :glue,      # connector; sub-vote boundary at match time. RESERVED for Stage 2.
    :functor,   # phase morphism; applies to phase data. RESERVED for Stage 6.
    :procedure, # named ordered chain of sigils+literals. RESERVED for Stage 6.
    :relation,  # relational triple macro; expands to alternative relation names. Stage 4.
    :structure, # meta-sigil; expands to ordered sequence of sigil refs + literals. v9.
)

# GRUG: closed enum of phases a sigil can `applies_at`. Stage 1 only really
# uses :bind and :match (via pattern parsing). Other values are reserved for
# later stages but accepted on registration so registries are forward-compat.
const SIGIL_APPLIES_AT::NTuple{9,Symbol} = (
    :bind,        # bind-time pattern compilation. Stage 1.
    :match,       # runtime pattern matching. Stage 1.
    :vote_shape,  # vote record construction. RESERVED for Stage 3.
    :tone,        # tone metadata attachment. RESERVED for Stage 7.
    :render,      # AIML scaffold synthesis. RESERVED for Stage 7.
    :thesaurus,   # cross-subsystem: thesaurus expansion. RESERVED for Stage 8.
    :drop_table,  # cross-subsystem: drop tables. RESERVED for Stage 8.
    :inhibit,     # cross-subsystem: inhibition rules. RESERVED for Stage 8.
    :relation,    # cross-subsystem: relational triples. RESERVED for Stage 4-5.
)

# GRUG: which classes are activated in Stage 1. Patterns referencing reserved
# classes throw at parse time with a clear "reserved for stage N" message.
const STAGE1_ACTIVE_CLASSES::NTuple{5,Symbol} = (:lambda, :macro, :tag, :relation, :structure)

# GRUG: which applies_at values are activated in Stage 1 (now including :relation
# for dynamic relational triples — Stage 4 feature activated early).
const STAGE1_ACTIVE_PHASES::NTuple{3,Symbol} = (:bind, :match, :relation)

# GRUG: regex for a valid sigil name. Letters, digits, dash, underscore. No
# spaces, no other punctuation. Greek letters allowed (for the eventual
# procedure-class Σ-naming convention) but engine does not REQUIRE Greek.
# Names are case-sensitive: `&Noun` and `&noun` are distinct sigils.
const SIGIL_NAME_REGEX::Regex = r"^[A-Za-z\u0370-\u03FF][A-Za-z0-9_\-\u0370-\u03FF]*$"

# GRUG: regex for a sigil TOKEN as it appears inside a pattern string. Matches
# `&name` where name conforms to SIGIL_NAME_REGEX. Used by pattern parser.
# Greek block U+0370–U+03FF supports Σ, Π, λ, etc. as prefix letters.
const SIGIL_TOKEN_REGEX::Regex =
    r"&([A-Za-z\u0370-\u03FF][A-Za-z0-9_\-\u0370-\u03FF]*)"

# GRUG: hard upper bound on number of sigils per pattern. Patterns far above
# this are almost certainly malformed; throw rather than allocate forever.
const MAX_SIGILS_PER_PATTERN::Int = 64

# GRUG: hard upper bound on registry entries. 4096 is generous — beyond it,
# the user is using sigils as a database and should not be.
const MAX_REGISTRY_ENTRIES::Int = 4096

# GRUG: hard upper bound on macro lexicon size per entry. Macros expand at
# bind time and can blow up the pattern table; cap to prevent accidents.
const MAX_LEXICON_SIZE::Int = 1024

# ==============================================================================
# DATA MODEL — Sigil entry + registry table.
# ==============================================================================
# GRUG: SigilEntry is the single row in the registry. ALL fields are present
# on EVERY entry, even when they don't apply — `nothing` means "not used by
# this class". This makes serialization/deserialization predictable: same
# JSON shape for every entry, same Julia struct for every entry. No subtypes,
# no abstract base. Flat, dumb, fast.
#
# Field-by-field:
#
#   name        — the sigil's bare name, no `&` prefix (e.g. "n", "noun", "Σ-greet").
#                 Must match SIGIL_NAME_REGEX.
#   class       — one of SIGIL_CLASSES. Stage 1 actively uses :lambda, :macro, :tag.
#   applies_at  — one of SIGIL_APPLIES_AT. Stage 1 actively uses :bind, :match.
#   sigil_type  — for :lambda class only: a Symbol describing what value is
#                 bound (:number, :word, :slurp, ...). Stage 1 ships :number,
#                 :word, :slurp. nothing for non-lambda classes.
#   lexicon     — for :macro class only: vector of strings making up the
#                 alternation. Bounded by MAX_LEXICON_SIZE. nothing for
#                 non-macro classes.
#   params      — optional Dict of param-name => value. Used (in later stages)
#                 for parameterized sigils like &fuzzy-match(max=2). Stage 1
#                 stores them but doesn't consume them. nothing if no params.
#   expansion   — RESERVED for Stage 6 :procedure class. Will hold the chain
#                 of sigils+literals that the procedure expands to. nothing
#                 for all other classes. Field is present on every entry so
#                 the schema is forward-compatible.
#   provenance  — free-form string describing where this entry came from
#                 (e.g. "engine-default", "specimen:foo.json", "test").
#                 Used in error messages and audit logs.
#   promote_at_tokenize
#               — Stage 1.5 ingest hook. When true, the SigilPromoter front
#                 door will rewrite raw input tokens that match this sigil's
#                 shape predicate into the canonical `&name` form, with the
#                 captured value stashed on a side-channel bindings list.
#                 Default false. Only :lambda and :macro classes meaningfully
#                 use this flag (a :tag has no value to capture, a reserved
#                 class is gated out of pattern resolution anyway). The flag
#                 is purely additive — patterns and pattern-bind confidence
#                 do not consult it; only the front-door promoter does.
#   promote_predicate
#               — Stage 1.5c conditional-promotion hook. Optional. When
#                 set AND promote_at_tokenize=true, the front-door promoter
#                 calls `promote_predicate(canonical_token)::Bool` per
#                 candidate token; only promotes when the predicate returns
#                 true. Lets end-users opt sigils into a third treatment
#                 mode beyond the binary token-vs-functor split:
#
#                   promote_at_tokenize=false                      → FUNCTOR
#                       (matcher handles entirely at runtime; the front
#                        door doesn't touch matching tokens.)
#                   promote_at_tokenize=true,  predicate=nothing   → TOKEN
#                       (front door always rewrites matching tokens; this
#                        is the Stage 1.5a default for &n and &op.)
#                   promote_at_tokenize=true,  predicate=fn        → CONDITIONAL
#                       (front door calls fn; rewrite only when fn returns
#                        true. e.g. promote &n only inside a math context,
#                        leave bare numerics alone everywhere else.)
#
#                 Predicate must be callable as `fn(::String)::Bool`. If it
#                 errors or returns a non-Bool the promoter raises
#                 PromoterConfigError — no silent fallbacks. Default nothing.
#
# All fields are immutable. Updating an entry means re-registering it, which
# (by default) throws on collision unless the caller passes overwrite=true.
"""
A single row in the sigil registry. All fields present on every entry; fields
not relevant to the entry's class are `nothing`.
"""
struct SigilEntry
# REMINDER: Sigils appear in relational triples — &n is_greater_than &n is dynamic.
    name::String
    class::Symbol
    applies_at::Symbol
    sigil_type::Union{Nothing,Symbol}
    lexicon::Union{Nothing,Vector{String}}
    params::Union{Nothing,Dict{String,Any}}
    expansion::Union{Nothing,Vector{Any}}  # Stage 6 reserved.
    provenance::String
    promote_at_tokenize::Bool              # Stage 1.5 ingest hook. Default false.
    promote_predicate::Union{Nothing,Function}  # Stage 1.5c conditional gate. Default nothing.
end

"""
The registry table. A small hash map from sigil name to entry. Wrapped in a
struct so we can attach metadata (provenance label, lock for thread safety
in later stages) without changing the call sites.

Stage 1 is single-threaded at the registry level — registries are built at
specimen load and read during pattern parsing; concurrent mutation is not a
supported pattern. If a later stage needs concurrent registration we add a
`ReentrantLock` field; today we don't, to keep the kernel simple.
"""
mutable struct SigilTable
    entries::Dict{String,SigilEntry}
    label::String  # human-readable name for logs (e.g. "engine-default", "specimen-foo")
end

SigilTable() = SigilTable(Dict{String,SigilEntry}(), "unlabeled")
SigilTable(label::AbstractString) = SigilTable(Dict{String,SigilEntry}(), String(label))

# ==============================================================================
# REGISTRATION — `register_sigil!` is the only way to add a row.
# ==============================================================================
# GRUG: register_sigil! validates EVERY field. Bad input throws. The validation
# table is exhaustive on purpose — Stage 1's job is to make the kernel
# bullet-proof so later stages can trust their inputs.

"""
    register_sigil!(table; name, class, applies_at, ...) -> SigilEntry

Validate and insert a sigil entry into `table`. Throws on any malformed input.

Required keyword args:
  - `name::AbstractString` — sigil name, no `&` prefix. Must match SIGIL_NAME_REGEX.
  - `class::Symbol` — one of SIGIL_CLASSES.
  - `applies_at::Symbol` — one of SIGIL_APPLIES_AT.

Optional keyword args:
  - `sigil_type::Union{Nothing,Symbol}=nothing` — only valid when class==:lambda.
  - `lexicon::Union{Nothing,AbstractVector}=nothing` — only valid when class==:macro.
  - `params::Union{Nothing,Dict}=nothing` — optional param dict.
  - `expansion::Union{Nothing,AbstractVector}=nothing` — RESERVED for :procedure.
  - `provenance::AbstractString="unspecified"` — origin tag for audit.
  - `overwrite::Bool=false` — if true, replace existing entry; else throw on collision.
  - `promote_at_tokenize::Bool=false` — Stage 1.5 ingest hook. When true, the
    front-door promoter rewrites raw input tokens matching this sigil's shape
    predicate (for :lambda) or lexicon membership (for :macro) into the
    canonical `&name` form. Only meaningful for :lambda and :macro classes;
    setting it on :tag or any reserved class throws SigilConfigError.
  - `promote_predicate::Union{Nothing,Function}=nothing` — Stage 1.5c
    conditional-promotion gate. When set AND `promote_at_tokenize=true`,
    the front-door promoter calls `predicate(canonical_token)::Bool` per
    candidate token; only promotes when the predicate returns true. Setting
    this without `promote_at_tokenize=true` throws SigilConfigError (the
    flag has no effect without ingest-time promotion enabled, and silent
    no-ops are bugs). The predicate must be callable; argument-arity errors
    surface at promote time as PromoterConfigError, not here.

Returns the newly-registered SigilEntry.
"""
function register_sigil!(
    table::SigilTable;
    name::AbstractString,
    class::Symbol,
    applies_at::Symbol,
    sigil_type::Union{Nothing,Symbol}=nothing,
    lexicon::Union{Nothing,AbstractVector}=nothing,
    params::Union{Nothing,Dict}=nothing,
    expansion::Union{Nothing,AbstractVector}=nothing,
    provenance::AbstractString="unspecified",
    overwrite::Bool=false,
    promote_at_tokenize::Bool=false,
    promote_predicate::Union{Nothing,Function}=nothing,
)::SigilEntry
    # GRUG: name validation — present, non-empty, matches name regex.
    nm = String(name)
    if isempty(nm)
        throw(SigilArgumentError("sigil name must be non-empty", "name"))
    end
    if !occursin(SIGIL_NAME_REGEX, nm)
        throw(SigilArgumentError(
            "sigil name does not match required pattern (letters/digits/dash/underscore, must start with letter): \"$nm\"",
            "name"))
    end

    # GRUG: class validation — must be one of the closed enum.
    if !(class in SIGIL_CLASSES)
        throw(SigilConfigError(
            "unknown sigil class :$class (allowed: $(SIGIL_CLASSES))",
            "class"))
    end

    # GRUG: applies_at validation — must be one of the closed enum.
    if !(applies_at in SIGIL_APPLIES_AT)
        throw(SigilConfigError(
            "unknown applies_at :$applies_at (allowed: $(SIGIL_APPLIES_AT))",
            "applies_at"))
    end

    # GRUG: class/field-coherence validation. Each class has rules about
    # which optional fields make sense. Reject incoherent combinations LOUDLY.
    _validate_class_fields(class, sigil_type, lexicon, expansion, nm)

    # GRUG: lexicon size cap.
    lex_clean::Union{Nothing,Vector{String}} = nothing
    if lexicon !== nothing
        if length(lexicon) > MAX_LEXICON_SIZE
            throw(SigilConfigError(
                "macro lexicon for &$nm has $(length(lexicon)) entries, exceeds MAX_LEXICON_SIZE=$MAX_LEXICON_SIZE",
                "lexicon"))
        end
        # GRUG: convert to Vector{String} and validate each entry is non-empty.
        clean = String[]
        for (i, e) in enumerate(lexicon)
            s = String(e)
            if isempty(s)
                throw(SigilConfigError(
                    "macro lexicon for &$nm contains empty string at index $i",
                    "lexicon"))
            end
            push!(clean, s)
        end
        lex_clean = clean
    end

    # GRUG: params normalization to Dict{String,Any} if provided.
    params_clean::Union{Nothing,Dict{String,Any}} = nothing
    if params !== nothing
        d = Dict{String,Any}()
        for (k, v) in params
            d[String(k)] = v
        end
        params_clean = d
    end

    # GRUG: expansion field is for :procedure class (ordered chains),
    # :relation class (alternative relation names), and :structure class
    # (meta-sigil expansion sequences). Other classes must not carry expansion.
    exp_clean::Union{Nothing,Vector{Any}} = nothing
    if expansion !== nothing
        if class !== :procedure && class !== :relation && class !== :structure
            throw(SigilConfigError(
                "expansion field is reserved for :procedure and :relation classes (got class :$class)",
                "expansion"))
        end
        exp_clean = Vector{Any}(expansion)
    end

    # GRUG: promote_at_tokenize gating. The front-door promoter only knows how
    # to capture values for :lambda (shape predicate) and :macro (lexicon
    # membership). Setting the flag on a :tag (no value) or a reserved class
    # (gated out of pattern resolution) is a programmer error.
    if promote_at_tokenize && !(class in (:lambda, :macro))
        throw(SigilConfigError(
            "promote_at_tokenize=true is only valid for :lambda and :macro classes (got class :$class for &$nm)",
            "promote_at_tokenize"))
    end

    # GRUG: promote_predicate validation (Stage 1.5c). Two rules:
    #   1. If predicate is set, promote_at_tokenize MUST also be true.
    #      A predicate without ingest-time promotion does nothing — that's
    #      a silent no-op and silent no-ops are bugs.
    #   2. The predicate must be a callable Function (Julia's type system
    #      already enforces this via the kwarg type, but we keep the check
    #      for the error-message clarity it gives downstream debuggers).
    # We do NOT call the predicate here — argument-arity errors and
    # non-Bool returns surface at promote time as PromoterConfigError,
    # attributable to the actual offending input token.
    if promote_predicate !== nothing && !promote_at_tokenize
        throw(SigilConfigError(
            "promote_predicate set on &$nm but promote_at_tokenize=false; predicate would never run_secure(silent no-ops are forbidden — set promote_at_tokenize=true or drop the predicate)",
            "promote_predicate"))
    end

    # GRUG: registry size cap.
    if length(table.entries) >= MAX_REGISTRY_ENTRIES && !haskey(table.entries, nm)
        throw(SigilConfigError(
            "registry has reached MAX_REGISTRY_ENTRIES=$MAX_REGISTRY_ENTRIES; refuse to add &$nm",
            "table.entries"))
    end

    # GRUG: collision check. Default behavior is THROW on collision —
    # silently overwriting an existing sigil is exactly the kind of subtle
    # bug we are trying to prevent. Caller must opt in with overwrite=true.
    if haskey(table.entries, nm) && !overwrite
        existing = table.entries[nm]
        throw(SigilConfigError(
            "sigil &$nm already registered (existing class=:$(existing.class), provenance=\"$(existing.provenance)\"); pass overwrite=true to replace",
            "name"))
    end

    entry = SigilEntry(
        nm,
        class,
        applies_at,
        sigil_type,
        lex_clean,
        params_clean,
        exp_clean,
        String(provenance),
        promote_at_tokenize,
        promote_predicate,
    )
    table.entries[nm] = entry
    return entry
end

# GRUG: per-class field-coherence rules. Centralized so adding a new class
# requires touching exactly one function. Throws SigilConfigError on any
# inconsistency.
function _validate_class_fields(
    class::Symbol,
    sigil_type::Union{Nothing,Symbol},
    lexicon::Union{Nothing,AbstractVector},
    expansion::Union{Nothing,AbstractVector},
    name::String,
)
    if class === :lambda
        # GRUG: lambdas need a sigil_type (number/word/slurp/...).
        if sigil_type === nothing
            throw(SigilConfigError(
                ":lambda sigil &$name requires sigil_type (e.g. :number, :word, :slurp)",
                "sigil_type"))
        end
        if lexicon !== nothing
            throw(SigilConfigError(
                ":lambda sigil &$name must not carry a lexicon (lexicons are for :macro)",
                "lexicon"))
        end
    elseif class === :macro
        # GRUG: macros need a lexicon. Empty lexicon is allowed (specimen-overridable).
        if lexicon === nothing
            throw(SigilConfigError(
                ":macro sigil &$name requires a lexicon (use [] for empty/specimen-overridable)",
                "lexicon"))
        end
        if sigil_type !== nothing
            throw(SigilConfigError(
                ":macro sigil &$name must not carry sigil_type (sigil_type is for :lambda)",
                "sigil_type"))
        end
    elseif class === :tag
        # GRUG: tags carry neither type nor lexicon. They are pure annotations.
        if sigil_type !== nothing
            throw(SigilConfigError(
                ":tag sigil &$name must not carry sigil_type",
                "sigil_type"))
        end
        if lexicon !== nothing
            throw(SigilConfigError(
                ":tag sigil &$name must not carry lexicon",
                "lexicon"))
        end
    elseif class === :glue
        # GRUG: Stage 2 reserved. Accept the entry shape but later stages
        # will tighten the rules. For Stage 1 we accept any shape so a
        # registry can pre-declare glue sigils that will activate in Stage 2.
        # (No fields are required yet; we just don't error out.)
    elseif class === :functor
        # GRUG: Stage 6 reserved. Same forward-compat policy as :glue.
    elseif class === :procedure
        # GRUG: Stage 6 reserved. expansion field is the procedure's chain.
        # Stage 1 won't be able to USE these but we let them register so a
        # specimen can ship them ahead of Stage 6.
    elseif class === :structure
        # GRUG v9: Structure-class sigils (meta-sigils) expand to ordered
        # sequences of other sigil names. They require an expansion list,
        # must not carry sigil_type or lexicon, and apply at :structure phase.
        if expansion === nothing
            throw(SigilConfigError(
                ":structure sigil &$name requires an expansion list of sigil names (e.g. [\"noun\", \"verb\", \"adjective\"])",
                "expansion"))
        end
        if sigil_type !== nothing
            throw(SigilConfigError(
                ":structure sigil &$name must not carry sigil_type",
                "sigil_type"))
        end
        if lexicon !== nothing
            throw(SigilConfigError(
                ":structure sigil &$name must not carry lexicon",
                "lexicon"))
        end
    elseif class === :relation
        # GRUG v7.55: Relation-class sigils expand to alternative relation names
        # for dynamic relational triples. They require an expansion list (the
        # relation verb alternatives), must not have sigil_type or lexicon,
        # and apply at :relation phase.
        if expansion === nothing
            throw(SigilConfigError(
                ":relation sigil &$name requires an expansion list of alternative relation names (e.g. [\"causes\", \"produces\", \"creates\"])",
                "expansion"))
        end
        if sigil_type !== nothing
            throw(SigilConfigError(
                ":relation sigil &$name must not carry sigil_type",
                "sigil_type"))
        end
        if lexicon !== nothing
            throw(SigilConfigError(
                ":relation sigil &$name must not carry lexicon",
                "lexicon"))
        end
    else
        # Unreachable: class was already validated against SIGIL_CLASSES.
        throw(SigilError("unreachable: unhandled class :$class in field validation",
                         "_validate_class_fields"))
    end
    return nothing
end

# ==============================================================================
# LOOKUP — small, predictable.
# ==============================================================================

"""
    lookup_sigil(table, name) -> SigilEntry

Return the entry for `name`. Throws SigilResolutionError if not found.

The bare-name form (no `&` prefix) is canonical. Callers that have a token
string should call `parse_sigil_token` first.
"""
function lookup_sigil(table::SigilTable, name::AbstractString)::SigilEntry
    if isempty(name)
        throw(SigilArgumentError("sigil name must be non-empty", "name"))
    end
    nm = String(name)
    if !haskey(table.entries, nm)
        throw(SigilResolutionError(
            "no such sigil in registry \"$(table.label)\"",
            nm,
            ""))
    end
    return table.entries[nm]
end

"""
    has_sigil(table, name) -> Bool

Non-throwing existence check. For probe / inspect use only — the bind-time
path always uses `lookup_sigil` so unknown sigils fail loud.
"""
function has_sigil(table::SigilTable, name::AbstractString)::Bool
    return haskey(table.entries, String(name))
end

"""
    list_sigils(table; class=nothing, applies_at=nothing) -> Vector{SigilEntry}

Return entries, optionally filtered by class and/or applies_at. Returned
order is deterministic: lexicographically by name.
"""
function list_sigils(
    table::SigilTable;
    class::Union{Nothing,Symbol}=nothing,
    applies_at::Union{Nothing,Symbol}=nothing,
)::Vector{SigilEntry}
    if class !== nothing && !(class in SIGIL_CLASSES)
        throw(SigilArgumentError(
            "filter class :$class is not a known SIGIL_CLASSES value",
            "class"))
    end
    if applies_at !== nothing && !(applies_at in SIGIL_APPLIES_AT)
        throw(SigilArgumentError(
            "filter applies_at :$applies_at is not a known SIGIL_APPLIES_AT value",
            "applies_at"))
    end

    out = SigilEntry[]
    for k in sort!(collect(keys(table.entries)))
        e = table.entries[k]
        if class !== nothing && e.class !== class
            continue
        end
        if applies_at !== nothing && e.applies_at !== applies_at
            continue
        end
        push!(out, e)
    end
    return out
end

"""
    clear_registry!(table) -> Nothing

Wipe every entry. Used by tests and by specimen-reload paths.
"""
function clear_registry!(table::SigilTable)
    empty!(table.entries)
    return nothing
end

# ==============================================================================
# PATTERN PARSING — extract sigil tokens from a pattern string.
# ==============================================================================
# GRUG: This is the kernel routine that the pattern matcher will call. Given
# a pattern string, return the list of sigil names found in it. The matcher
# then resolves each name against the registry and validates per-position
# semantics. Stage 1 returns the names + offsets; later stages will produce
# a full compiled-pattern struct.

"""
A reference to a sigil token inside a pattern string.

Fields:
  - `name::String` — sigil name (no `&` prefix).
  - `start_byte::Int` — byte offset of `&` in the pattern (1-based).
  - `end_byte::Int` — byte offset of last name char (1-based, inclusive).
  - `entry::SigilEntry` — resolved registry entry.
"""
struct SigilTokenRef
    name::String
    start_byte::Int
    end_byte::Int
    entry::SigilEntry
end

"""
    parse_sigil_token(s) -> Union{Nothing,String}

Convenience: if `s` looks like a single sigil token (`&name`), return `name`.
Otherwise return `nothing`. Used by callers that want to test "is this a
literal or a sigil reference?" without scanning a whole pattern.

This function does NOT consult the registry; it's pure syntax.
"""
function parse_sigil_token(s::AbstractString)::Union{Nothing,String}
    str = String(s)
    if isempty(str) || str[1] !== SIGIL_PREFIX
        return nothing
    end
    rest = str[2:end]
    if isempty(rest) || !occursin(SIGIL_NAME_REGEX, rest)
        return nothing
    end
    return rest
end

"""
    resolve_sigils_in_pattern(table, pattern; allow_reserved=false)
        -> Vector{SigilTokenRef}

Scan `pattern` for `&name` tokens and resolve each against `table`.

Behavior:
  - Pattern with no `&` character returns `SigilTokenRef[]` immediately.
    (Fast path. Old patterns pay zero cost.)
  - Each `&name` is resolved; unknown name throws SigilResolutionError.
  - If the resolved entry's `class` is not in STAGE1_ACTIVE_CLASSES and
    `allow_reserved=false`, throws SigilConfigError. Callers that are
    intentionally pre-registering reserved-class sigils (e.g. tests) can
    pass `allow_reserved=true`.
  - If the pattern contains more than MAX_SIGILS_PER_PATTERN sigil tokens,
    throws SigilConfigError.

Returns the list of resolved tokens in pattern-position order.
"""
function resolve_sigils_in_pattern(
    table::SigilTable,
    pattern::AbstractString;
    allow_reserved::Bool=false,
)::Vector{SigilTokenRef}
    pat = String(pattern)

    # GRUG: fast path — no `&` anywhere, no work to do, allocate nothing.
    if !occursin(SIGIL_PREFIX, pat)
        return SigilTokenRef[]
    end

    refs = SigilTokenRef[]
    count = 0
    for m in eachmatch(SIGIL_TOKEN_REGEX, pat)
        count += 1
        if count > MAX_SIGILS_PER_PATTERN
            throw(SigilConfigError(
                "pattern contains more than MAX_SIGILS_PER_PATTERN=$MAX_SIGILS_PER_PATTERN sigil tokens; pattern=\"$pat\"",
                "pattern"))
        end
        name = String(m.captures[1])
        # GRUG: registry lookup — throws SigilResolutionError on miss with
        # the pattern attached for context.
        entry = if haskey(table.entries, name)
            table.entries[name]
        else
            throw(SigilResolutionError(
                "no such sigil in registry \"$(table.label)\"",
                name,
                pat))
        end
        # GRUG: reserved-class gate. Stage 1 only allows :lambda, :macro, :tag
        # in patterns. Other classes can be REGISTERED but not USED yet.
        if !allow_reserved && !(entry.class in STAGE1_ACTIVE_CLASSES)
            throw(SigilConfigError(
                "sigil &$name has class :$(entry.class) which is reserved for a later stage; Stage 1 only activates classes $(STAGE1_ACTIVE_CLASSES)",
                "class"))
        end
        # GRUG: phase gate. Stage 1 only activates :bind and :match.
        if !allow_reserved && !(entry.applies_at in STAGE1_ACTIVE_PHASES)
            throw(SigilConfigError(
                "sigil &$name has applies_at :$(entry.applies_at) which is reserved for a later stage; Stage 1 only activates phases $(STAGE1_ACTIVE_PHASES)",
                "applies_at"))
        end
        push!(refs, SigilTokenRef(name, m.offset, m.offset + length(m.match) - 1, entry))
    end
    return refs
end

# ==============================================================================
# DEFAULT REGISTRY — the engine ships this. Specimens extend it.
# ==============================================================================
# GRUG: The default registry contains the small set of sigils that every
# specimen can rely on without extra configuration. It is rebuilt fresh on
# each call (specimens get their own copy and can mutate freely).

"""
    default_registry() -> SigilTable

Build a fresh SigilTable populated with the engine-default sigils.

Stage 1 ships:
  &n     — :lambda, sigil_type=:number, applies_at=:match. Matches a numeric token.
  &word  — :lambda, sigil_type=:word,   applies_at=:match. Matches a single word.
  &rest  — :lambda, sigil_type=:slurp,  applies_at=:match. Slurps remaining tokens.
  &noun  — :macro,  lexicon=[],         applies_at=:bind.  Specimen-overridable list.

Stage 1.5 adds:
  &op    — :lambda, sigil_type=:op,     applies_at=:match. Matches a math operator
           from the closed set {+, -, *, /, =, <, >, %, ^}. promote_at_tokenize=true.
  &n     gets promote_at_tokenize=true so the front-door promoter rewrites bare
         numeric tokens into &n with the value bound on the side-channel.

Specimens that want a populated `&noun` lexicon merge a specimen-level
registry on top using `merge_registry!`.
"""

# GRUG v7.56: Relation sigil helpers — defined BEFORE default_registry()
# so that default_registry() can register built-in relation sigils.

function register_relation_sigil!(table::SigilTable;
                                  name::AbstractString,
                                  expansion::AbstractVector,
                                  provenance::AbstractString = "user-relation",
                                  overwrite::Bool = false)::SigilEntry
    if isempty(expansion)
        throw(SigilConfigError(
            "register_relation_sigil!: expansion cannot be empty for &$name",
            "expansion"))
    end
    for (i, el) in enumerate(expansion)
        if !(el isa AbstractString)
            throw(SigilConfigError(
                "register_relation_sigil!: expansion[$i] must be a String, got $(typeof(el))",
                "expansion"))
        end
        if isempty(strip(String(el)))
            throw(SigilConfigError(
                "register_relation_sigil!: expansion[$i] is empty/whitespace",
                "expansion"))
        end
    end
    return register_sigil!(table;
                           name = name,
                           class = :relation,
                           applies_at = :relation,
                           expansion = collect(String, expansion),
                           provenance = String(provenance),
                           overwrite = overwrite)
end

"""
    expand_relation_sigil(table, name) -> Vector{String}

Expand a `:relation` class sigil into its flat list of alternative relation
verb strings. Unlike procedure sigils, relation sigils do NOT recurse — the
expansion list contains only literal verb strings.

Throws:
  - SigilResolutionError when the named sigil is not in the table.
  - SigilConfigError when the sigil exists but is not :relation class.
"""
function expand_relation_sigil(table::SigilTable,
                               name::AbstractString)::Vector{String}
    nm = String(name)
    haskey(table.entries, nm) || throw(SigilResolutionError(
        "no such sigil in registry \"$(table.label)\"", nm, "<relation-expand>"))
    entry = table.entries[nm]
    entry.class === :relation || throw(SigilConfigError(
        "expand_relation_sigil: &$nm has class :$(entry.class), expected :relation",
        "class"))
    entry.expansion === nothing && throw(SigilConfigError(
        "expand_relation_sigil: &$nm has no expansion list", "expansion"))
    # GRUG: Return as pure Vector{String}. Relation expansions are flat — no nesting.
    return [String(el) for el in entry.expansion]
end

"""
    is_relation_sigil(table, name) -> Bool

Cheap check: does the named sigil exist and have class :relation?
"""
function is_relation_sigil(table::SigilTable, name::AbstractString)::Bool
    nm = String(name)
    haskey(table.entries, nm) || return false
    return table.entries[nm].class === :relation
end

"""
    verb_to_relation_sigil(table, verb) -> Union{String, Nothing}

Reverse lookup: given a concrete verb (e.g. "before", "has"), find the
name of the :relation sigil whose expansion list contains it.
Returns the sigil name WITHOUT the & prefix (e.g. "temporal"), or nothing.
Used by AutoGrowth to promote concrete verbs to sigil references.
"""
function verb_to_relation_sigil(table::SigilTable, verb::AbstractString)::Union{String, Nothing}
    v = lowercase(strip(String(verb)))
    isempty(v) && return nothing
    for (name, entry) in table.entries
        entry.class === :relation || continue
        entry.expansion === nothing && continue
        for alt in entry.expansion
            if lowercase(strip(String(alt))) == v
                return String(name)
            end
        end
    end
    return nothing
end

"""
    expand_relation_if_sigil(table, relation_str) -> Vector{String}

If `relation_str` starts with `&` and names a registered :relation sigil,
expand it and return the alternatives. Otherwise return `[relation_str]`
as a singleton. This is the main call site helper for evaluate_relational_dialectics.
"""
function expand_relation_if_sigil(table::SigilTable,
                                  relation_str::AbstractString)::Vector{String}
    s = String(relation_str)
    if isempty(s) || s[1] != SIGIL_PREFIX
        return [s]  # Plain literal — no expansion needed.
    end
    nm = s[2:end]  # Strip & prefix
    if is_relation_sigil(table, nm)
        return expand_relation_sigil(table, nm)
    end
    # GRUG: Unknown &name that isn't a relation sigil — return as-is.
    # Pattern resolution will throw if it's an unknown sigil in a pattern,
    # but in a triple's relation field we're permissive: it could be a
    # lambda/macro sigil that the user explicitly placed. Return literal.
    return [s]
end

function default_registry()::SigilTable
    t = SigilTable("engine-default")

    register_sigil!(t;
        name="n",
        class=:lambda,
        applies_at=:match,
        sigil_type=:number,
        provenance="engine-default",
        promote_at_tokenize=true)

    register_sigil!(t;
        name="word",
        class=:lambda,
        applies_at=:match,
        sigil_type=:word,
        provenance="engine-default")

    register_sigil!(t;
        name="rest",
        class=:lambda,
        applies_at=:match,
        sigil_type=:slurp,
        provenance="engine-default")

    register_sigil!(t;
        name="noun",
        class=:macro,
        applies_at=:bind,
        lexicon=String[],
        provenance="engine-default")

    register_sigil!(t;
        name="op",
        class=:lambda,
        applies_at=:match,
        sigil_type=:op,
        provenance="engine-default",
        promote_at_tokenize=true)

    # GRUG v8.18: Knowledge-layer sigils — partition pattern space so that
    # math sigil nodes (&n &op &n) don't compete with knowledge/definition
    # nodes. Each sigil has a shape predicate in SigilPromoter that gates
    # which tokens can be promoted. This prevents greedy over-matching
    # where &n swallows concept words like "golden" or "ratio".

    # GRUG v8.18: &concept — knowledge concept placeholder.
    # promote_predicate excludes: stopwords, operators, numbers (matching &n),
    # query words (matching &query), definition verbs (matching &definition),
    # and action verbs (matching &action). This ensures &concept only captures
    # genuine content words (nouns, adjectives, domain terms) that don't belong
    # to a more specific sigil class.
    register_sigil!(t;
        name="concept",
        class=:lambda,
        applies_at=:match,
        sigil_type=:concept,
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> (
            # Must contain at least one alphabetic character
            any(c -> isletter(c), t) &&
            # Not a number (let &n catch these)
            !occursin(r"^[+-]?\d+(?:\.\d+)?$", t) &&
            # Not an operator symbol (let &op catch these)
            !(t in ["+","-","*","/","=","<<",">","%","^"]) &&
            # Not a query word (let &query catch these)
            !(t in ["what","who","how","why","when","where","which","whom","whose","whether"]) &&
            # Not a definition verb (let &definition catch these)
            !(t in ["is","are","means","refers","represents","defines","denotes","signifies","embodies","constitutes","characterizes"]) &&
            # Not an action verb (let &action catch these)
            !(t in ["explain","describe","tell","define","reason","discuss","elaborate","clarify","illustrate","analyze","interpret","compare","contrast","evaluate","assess","summarize","outline"]) &&
            # GRUG v8.19: Not a math action keyword (let action sigil nodes match these
            # as literal tokens in their patterns, not as &concept placeholders).
            # Without this exclusion, "half" → &concept, "reciprocal" → &concept,
            # "double" → &concept, etc. — destroying pattern specificity so that
            # "half of 20" and "reciprocal of 20" both promote to "&concept of &n"
            # and become indistinguishable. Now they stay as literal tokens and
            # match their respective node patterns correctly.
            !(t in ["half","reciprocal","double","square","cube","factorial",
                    "fibonacci","absolute","negate","negative"]) &&
            # Not a stopword
            !(t in ["the","a","an","was","were","be","been","have","has","had",
                    "do","does","did","will","would","could","should","may",
                    "might","shall","can","to","of","in","for","on","with",
                    "at","by","from","as","into","through","during","after",
                    "above","below","between","out","off","over","under","again",
                    "further","then","once","and","but","or","nor","not","so",
                    "yet","both","either","neither","each","every","all","any",
                    "few","more","most","other","some","such","no","only","own",
                    "same","than","too","very","just","because","if","this",
                    "that","these","those","it","its"]) &&
            # GRUG v9: Not a dictionary word (let &define catch these).
            # Without this exclusion, "dog" → &concept and the dictionary
            # sigil node never fires. By excluding dict words from &concept,
            # they fall through to &define which has the dictionary-check
            # predicate and routes them to the definition voting pipeline.
            !_DICT_WORD_CHECKER[](t)
        )))

    register_sigil!(t;
        name="query",
        class=:lambda,
        applies_at=:match,
        sigil_type=:query,
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["what","who","how","why","when","where",
                                     "which","whom","whose","whether"]))

    register_sigil!(t;
        name="definition",
        class=:lambda,
        applies_at=:match,
        sigil_type=:definition,
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["is","are","means","refers","represents",
                                     "defines","denotes","signifies","embodies",
                                     "constitutes","characterizes"]))

    # GRUG v9: &define — dictionary-defined word placeholder.
    # promote_predicate checks if the token has a dictionary entry via
    # the _DICT_WORD_CHECKER Ref (set by Main.jl after dictionaries load).
    # This sigil captures the WORD BEING DEFINED (e.g., "dog" → &define),
    # not the definition verb (that's &definition). Alphabetical promotion
    # order ensures &definition (d-e-f-i) is checked before &define (d-e-f),
    # so definition verbs like "is" are caught first, then the target word
    # falls through to &define. Also, &concept's predicate now excludes
    # dictionary words so they don't get swallowed by &concept either.
    register_sigil!(t;
        name="define",
        class=:lambda,
        applies_at=:match,
        sigil_type=:define,
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> _DICT_WORD_CHECKER[](t)))

    register_sigil!(t;
        name="action",
        class=:lambda,
        applies_at=:match,
        sigil_type=:action,
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["explain","describe","tell","define","reason",
                                     "discuss","elaborate","clarify","illustrate",
                                     "analyze","interpret","compare","contrast",
                                     "evaluate","assess","summarize","outline"]))

    # GRUG v7.56: Pre-registered relation sigils — semantic category macros
    # for dynamic relational triples. Each :relation sigil's expansion lists
    # alternative verbs that share the same semantic category. At evaluation
    # time, a triple with &temporal in its relation slot matches ANY temporal
    # verb the user supplies. This is semantic abstraction at the relational
    # level: the node doesn't enumerate every time verb, it just says
    # &temporal and the expansion covers them all.

    register_relation_sigil!(t;
        name="temporal",
        expansion=["before", "after", "during", "since", "until", "now",
                   "then", "precedes", "follows", "while", "when"],
        provenance="engine-default")

    register_relation_sigil!(t;
        name="causal",
        expansion=["causes", "produces", "creates", "generates", "leads_to",
                   "results_in", "triggers", "enables", "brings_about"],
        provenance="engine-default")

    register_relation_sigil!(t;
        name="spatial",
        expansion=["above", "below", "inside", "outside", "near", "beside",
                   "around", "between", "through", "across", "behind",
                   "in_front_of"],
        provenance="engine-default")

    register_relation_sigil!(t;
        name="possessive",
        expansion=["has", "owns", "contains", "holds", "carries", "possesses",
                   "includes", "comprises"],
        provenance="engine-default")

    register_relation_sigil!(t;
        name="similarity",
        expansion=["resembles", "mirrors", "echoes", "parallels", "mimics",
                   "approximates", "is_like"],
        provenance="engine-default")

    # GRUG v8.16: &being — identity/existence verbs. Used as required_relations
    # on node_17 (pattern "you") to prevent greedy over-matching. Identity
    # questions like "what are you" / "what is grug" supply "is"/"are" as
    # relation verbs, but emotion questions like "do you have feelings" supply
    # "have", and "what do you know about fear" supplies "know". Without this
    # gate, node_17 captures any input containing "you" regardless of intent.
    register_relation_sigil!(t;
        name="being",
        expansion=["is", "are", "am", "be", "was", "were"],
        provenance="engine-default")

    # GRUG v8.16: &arithmetic — math operation verbs. Used as required_relations
    # on node_sigil_0/1 to prevent them from firing as low-confidence side-features
    # on non-math questions. Math inputs like "2 + 3" or "what is 5 times 7"
    # produce triples with "plus"/"times"/"minus" etc. as relation verbs, but
    # non-math inputs like "what is AI" produce "is"/"about" verbs.
    register_relation_sigil!(t;
        name="arithmetic",
        expansion=["plus", "minus", "times", "divided", "multiply", "add",
                   "subtract", "over", "mod", "modulo", "power", "equals"],
        provenance="engine-default")

    # ── GRUG v8.1: TIME NODE SIGILS ──
    # Time coherence signaling for temporal orientation. Three base entries
    # that the user can extend by registering more :macro/:tone sigils with
    # their own lexicons and params. When the promoter rewrites a temporal
    # word (e.g. "now" → "&now"), the binding carries :orientation and
    # :vote_flags in params. Downstream, the engine reads these flags from
    # the binding to signal the orchestrator and hippocampal lever.
    #
    # The :tone applies_at domain means these sigils participate in the
    # tone/reasoning-mode layer, not the pattern-matching layer. They
    # don't change WHAT the system answers — they change HOW it reasons.
    #
    # Vote flags: :reflect (past), :assess (present), :project (future).
    # These are booleans that the orchestrator reads to determine which
    # AIML reasoning mode to activate for the response.

    register_sigil!(t;
        name="now",
        class=:macro,
        applies_at=:tone,
        lexicon=["now", "currently", "right now", "what now",
                 "whats happening", "current state", "presently",
                 "at the moment", "at present"],
        params=Dict(
            "orientation"  => "present",
            "vote_flags"   => Dict("reflect" => false, "assess" => true, "project" => false),
            "signal"       => ["assess_current"]
        ),
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["now", "currently", "right now",
                                       "what now", "whats happening",
                                       "current state", "presently",
                                       "at the moment", "at present"]))

    register_sigil!(t;
        name="before",
        class=:macro,
        applies_at=:tone,
        lexicon=["before", "earlier", "previously", "what happened",
                 "in the past", "back then", "beforehand", "formerly",
                 "lately", "recently"],
        params=Dict(
            "orientation"  => "past",
            "vote_flags"   => Dict("reflect" => true, "assess" => false, "project" => false),
            "signal"       => ["reflect_past"]
        ),
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["before", "earlier", "previously",
                                       "what happened", "in the past",
                                       "back then", "beforehand", "formerly",
                                       "lately", "recently"]))

    register_sigil!(t;
        name="next",
        class=:macro,
        applies_at=:tone,
        lexicon=["next", "after", "later", "what will", "whats next",
                 "in the future", "going forward", "soon", "eventually",
                 "afterward", "upcoming"],
        params=Dict(
            "orientation"  => "future",
            "vote_flags"   => Dict("reflect" => false, "assess" => false, "project" => true),
            "signal"       => ["project_future"]
        ),
        provenance="engine-default",
        promote_at_tokenize=true,
        promote_predicate=(t -> t in ["next", "after", "later", "what will",
                                       "whats next", "in the future",
                                       "going forward", "soon", "eventually",
                                       "afterward", "upcoming"]))

    return t
end

"""
    merge_registry!(target, source; conflict=:error) -> SigilTable

Merge entries from `source` into `target`. Three conflict policies:

  - `:error` (default) — collision throws. Specimens that intend to override
    an engine-default sigil must explicitly pass `:overwrite`.
  - `:overwrite` — source entry replaces target entry. Provenance carries
    the source's value.
  - `:keep`     — target entry is preserved. Source entry is dropped silently
                  (this is the ONE place we silently drop; documented and
                  intentional, and only on explicit caller opt-in).

Returns `target` (mutated in place).
"""
function merge_registry!(
    target::SigilTable,
    source::SigilTable;
    conflict::Symbol=:error,
)::SigilTable
    if !(conflict in (:error, :overwrite, :keep))
        throw(SigilArgumentError(
            "conflict policy must be :error, :overwrite, or :keep (got :$conflict)",
            "conflict"))
    end

    for (nm, src_entry) in source.entries
        if haskey(target.entries, nm)
            if conflict === :error
                tgt_entry = target.entries[nm]
                throw(SigilConfigError(
                    "merge collision on &$nm: target provenance=\"$(tgt_entry.provenance)\", source provenance=\"$(src_entry.provenance)\"; pass conflict=:overwrite or :keep",
                    "name"))
            elseif conflict === :overwrite
                target.entries[nm] = src_entry
            elseif conflict === :keep
                # GRUG: explicit, opt-in silent drop. This is the documented
                # exception to the no-silent-failures rule. The caller asked
                # for it.
                continue
            end
        else
            target.entries[nm] = src_entry
        end
    end
    return target
end

# ==============================================================================
# v7.23 — :procedure CLASS ACTIVATION (math-acronym sigils)
# ==============================================================================
# GRUG say: Stage 6 said "procedure reserved". v7.23 light it up. Procedure
#           sigil is small ordered chain of literals and other sigil names
#           that the engine expand inline at promotion time. End user define
#           them. Acts like a math acronym: write `&Sigma`, mean "sum of".
#           Engine expand to the chain at promotion. Pattern matching itself
#           still runs through resolve_sigils_in_pattern with allow_reserved
#           toggled to true ONLY for procedure-aware paths.
# GRUG say: NO SILENT FAILURES. Unknown nested sigil throws. Recursive
#           expansion bounded by MAX_PROCEDURE_DEPTH so a cyclic definition
#           cannot lock the engine.

const MAX_PROCEDURE_DEPTH::Int = 8

"""
    register_procedure_sigil!(table; name, expansion, provenance="user-procedure")
        -> SigilEntry

Register a `:procedure` class sigil whose body is an ordered `expansion`
chain of literal `String`s and `&name` references to other registered sigils.
This is the v7.23 entry point for math-acronym style sigils.

Example:
    register_procedure_sigil!(tbl;
        name = "Sigma-then-double",
        expansion = ["sum", "&n", "&op", "&n", "then double"])

Throws SigilConfigError on empty expansion or any non-String element.
"""
function register_procedure_sigil!(table::SigilTable;
                                   name::AbstractString,
                                   expansion::AbstractVector,
                                   provenance::AbstractString = "user-procedure",
                                   overwrite::Bool = false)::SigilEntry
    if isempty(expansion)
        throw(SigilConfigError(
            "register_procedure_sigil!: expansion cannot be empty for &$name",
            "expansion"))
    end
    for (i, el) in enumerate(expansion)
        if !(el isa AbstractString)
            throw(SigilConfigError(
                "register_procedure_sigil!: expansion[$i] must be a String, got $(typeof(el))",
                "expansion"))
        end
        if isempty(strip(String(el)))
            throw(SigilConfigError(
                "register_procedure_sigil!: expansion[$i] is empty/whitespace",
                "expansion"))
        end
    end
    return register_sigil!(table;
                           name = name,
                           class = :procedure,
                           applies_at = :bind,
                           expansion = collect(String, expansion),
                           provenance = String(provenance),
                           overwrite = overwrite)
end

"""
    expand_procedure_sigil(table, name; depth=0) -> Vector{String}

Recursively expand a `:procedure` sigil into a flat vector of literal tokens.
Nested `&xxx` references inside the expansion are looked up; if the nested
sigil is also a `:procedure`, it is expanded recursively (bounded by
MAX_PROCEDURE_DEPTH). Non-procedure nested sigils are emitted as their
canonical `&name` token (so downstream pattern code still sees a sigil).

Throws:
  - SigilResolutionError when a referenced sigil is not in the table.
  - SigilConfigError when recursion exceeds MAX_PROCEDURE_DEPTH (cycle guard).
  - SigilConfigError when the named sigil exists but is not :procedure class.
"""
function expand_procedure_sigil(table::SigilTable,
                                name::AbstractString;
                                depth::Int = 0)::Vector{String}
    if depth > MAX_PROCEDURE_DEPTH
        throw(SigilConfigError(
            "procedure expansion depth exceeded MAX_PROCEDURE_DEPTH=$MAX_PROCEDURE_DEPTH (cycle?) at &$name",
            "expansion"))
    end
    nm = String(name)
    haskey(table.entries, nm) || throw(SigilResolutionError(
        "no such sigil in registry \"$(table.label)\"", nm, "<expand>"))
    entry = table.entries[nm]
    entry.class === :procedure || throw(SigilConfigError(
        "expand_procedure_sigil: &$nm has class :$(entry.class), expected :procedure",
        "class"))
    entry.expansion === nothing && throw(SigilConfigError(
        "expand_procedure_sigil: &$nm has no expansion chain", "expansion"))

    out = String[]
    prefix_str = string(SIGIL_PREFIX)
    prefix_len = length(prefix_str)
    for el in entry.expansion
        s = String(el)
        if startswith(s, prefix_str)
            inner_str = String(SubString(s, prefix_len + 1))
            if haskey(table.entries, inner_str) &&
               table.entries[inner_str].class === :procedure
                append!(out, expand_procedure_sigil(table, inner_str; depth = depth + 1))
            else
                # Non-procedure nested sigil: emit canonical token unchanged.
                # Pattern resolver will validate it later when this expansion
                # is fed through normal channels.
                if !haskey(table.entries, inner_str)
                    throw(SigilResolutionError(
                        "procedure &$nm references unknown sigil &$inner_str",
                        inner_str, s))
                end
                push!(out, s)
            end
        else
            push!(out, s)
        end
    end
    return out
end

"""
    is_procedure_sigil(table, name) -> Bool

Cheap check used by the promoter to decide whether to call the expander.
"""
function is_procedure_sigil(table::SigilTable, name::AbstractString)::Bool
    nm = String(name)
    haskey(table.entries, nm) || return false
    return table.entries[nm].class === :procedure
end

# Re-export the new public surface so callers can `using` them.
export register_procedure_sigil!, expand_procedure_sigil, is_procedure_sigil,
       MAX_PROCEDURE_DEPTH

# ==============================================================================
# v9: STRUCTURE-CLASS SIGIL — meta-sigils that expand to ordered sequences
# ==============================================================================
# GRUG: A :structure sigil is a meta-sigil whose expansion is an ordered
# sequence of sigil references plus literal tokens. When the pattern matcher
# encounters a :structure sigil, it expands the structure inline — effectively
# inlining the sub-pattern. This is compressible: structures can reference
# other structures, building hierarchical pattern compression.
#
# Example:
#   &cause_structure  → [&entity &causal &entity]
#   &narrative_arc     → [&cause_structure &enable_structure &cause_structure]
#
# The expansion field (already present on every SigilEntry) holds the chain.
# This parallels the :procedure class but :structure applies at :bind time
# (for pattern compilation) rather than :match time.
# ==============================================================================

"""
    register_structure_sigil!(table; name, expansion, provenance="user-structure",
                              overwrite=false) -> SigilEntry

Register a `:structure` class sigil whose body is an ordered `expansion`
chain of literal `String`s and `&name` references to other registered sigils.
This is the v9 entry point for meta-sigil compression.

Example:
    register_structure_sigil!(tbl;
        name = "cause_structure",
        expansion = ["&entity", "&causal", "&entity"])

Throws SigilConfigError on empty expansion or any non-String element.
"""
function register_structure_sigil!(table::SigilTable;
                                   name::AbstractString,
                                   expansion::AbstractVector,
                                   provenance::AbstractString = "user-structure",
                                   overwrite::Bool = false)::SigilEntry
    if isempty(expansion)
        throw(SigilConfigError(
            "register_structure_sigil!: expansion cannot be empty for &$name",
            "expansion"))
    end
    for (i, el) in enumerate(expansion)
        if !(el isa AbstractString)
            throw(SigilConfigError(
                "register_structure_sigil!: expansion[$i] must be a String, got $(typeof(el))",
                "expansion"))
        end
        if isempty(strip(String(el)))
            throw(SigilConfigError(
                "register_structure_sigil!: expansion[$i] is empty/whitespace",
                "expansion"))
        end
    end
    return register_sigil!(table;
                           name = name,
                           class = :structure,
                           applies_at = :bind,
                           expansion = collect(String, expansion),
                           provenance = provenance,
                           overwrite = overwrite)
end

"""
    expand_structure_sigil(table, name; depth=0) -> Vector{String}

Recursively expand a `:structure` sigil into a flat vector of literal tokens.
Nested `&xxx` references inside the expansion are looked up; if the nested
sigil is also a `:structure`, it is expanded recursively (bounded by
MAX_PROCEDURE_DEPTH). Non-structure nested sigils are emitted as their
canonical `&name` token.

Throws:
  - SigilResolutionError when a referenced sigil is not in the table.
  - SigilConfigError when recursion exceeds MAX_PROCEDURE_DEPTH (cycle guard).
  - SigilConfigError when the named sigil exists but is not :structure class.
"""
function expand_structure_sigil(table::SigilTable,
                                name::AbstractString;
                                depth::Int = 0)::Vector{String}
    if depth > MAX_PROCEDURE_DEPTH
        throw(SigilConfigError(
            "structure expansion depth exceeded MAX_PROCEDURE_DEPTH=$MAX_PROCEDURE_DEPTH (cycle?) at &$name",
            "expansion"))
    end
    nm = String(name)
    haskey(table.entries, nm) || throw(SigilResolutionError(
        "no such sigil in registry \"$(table.label)\"", nm, "<expand>"))
    entry = table.entries[nm]
    entry.class === :structure || throw(SigilConfigError(
        "expand_structure_sigil: &$nm has class :$(entry.class), expected :structure",
        "class"))
    entry.expansion === nothing && throw(SigilConfigError(
        "expand_structure_sigil: &$nm has no expansion chain", "expansion"))

    out = String[]
    prefix_str = string(SIGIL_PREFIX)
    prefix_len = length(prefix_str)
    for el in entry.expansion
        s = String(el)
        if startswith(s, prefix_str)
            inner_str = String(SubString(s, prefix_len + 1))
            if haskey(table.entries, inner_str) &&
               table.entries[inner_str].class === :structure
                append!(out, expand_structure_sigil(table, inner_str; depth = depth + 1))
            else
                # Non-structure nested sigil: emit canonical token unchanged.
                if !haskey(table.entries, inner_str)
                    throw(SigilResolutionError(
                        "structure &$nm references unknown sigil &$inner_str",
                        inner_str, s))
                end
                push!(out, s)
            end
        else
            push!(out, s)
        end
    end
    return out
end

"""
    is_structure_sigil(table, name) -> Bool

Cheap check: does this name refer to a :structure sigil?
"""
function is_structure_sigil(table::SigilTable, name::AbstractString)::Bool
    nm = String(name)
    haskey(table.entries, nm) || return false
    return table.entries[nm].class === :structure
end

export register_structure_sigil!, expand_structure_sigil, is_structure_sigil

# ==============================================================================
# v7.55: RELATION-CLASS SIGIL — dynamic relational triple macros
# ==============================================================================
# GRUG: A :relation-class sigil expands to a list of alternative relation verb
# strings. When a node triple's relation field contains a `&relName` reference,
# the evaluation code expands it and matches against ANY of the alternatives.
#
# The functions are defined above (before default_registry) so that the engine
# can register built-in relation sigils at startup.
#
# User-facing registration: /addRelRelation <name> <alt1 alt2 ...>
# ==============================================================================

export register_relation_sigil!, expand_relation_sigil, is_relation_sigil,
       expand_relation_if_sigil, verb_to_relation_sigil

end # module SigilRegistry
