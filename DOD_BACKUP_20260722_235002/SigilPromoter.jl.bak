# ==============================================================================
# SigilPromoter.jl — GRUG Sigil Front-Door Input Promoter (Stage 1.5a)
# ==============================================================================
# !!! GRUG REMINDER — RELATIONAL TRIPLES CAN USE SIGILS !!!
# Promotion/canonicalization here can feed sigil tokens into BOTH flat patterns
# AND relational triples. A RelationalTriple's subject / relation / object may
# carry sigil holes (&n, &word, &noun, specimen macros). Anything downstream
# consuming promoted triples must NOT assume the fields are literal words.
# ==============================================================================
# GRUG say: user say "two plus two", user say "2 + 2", user say "2 plus two".
#           All same thing. All should land in same place. So before pattern
#           bind even sees input, we rewrite to canonical form.
# GRUG say: layer 1 — language-aware. "two" -> "2". "plus" -> "+". Word-level
#           canonicalization driven by closed lookup table.
# GRUG say: layer 2 — shape-aware. "2" -> "&n=2". "+" -> "&op=plus". Shape
#           predicate driven by sigil registry's promote_at_tokenize flag.
# GRUG say: matcher and confidence math UNCHANGED. They see canonical string.
#           &n in input matches &n in pattern same as "the" matches "the".
# GRUG say: ZERO COST when no promotable token. Pure-text input passes through
#           with empty bindings list. Old specimens bit-identical.
# GRUG say: NO SILENT FAILURES. Every malformed input throws a typed error.
#           Idempotent — promote(promote(x)) == promote(x) so re-entrant paths
#           (debug, A/B tests) don't double-promote.
#
# THE BIG INSIGHT (this is the thing that makes the cave compress):
#
#   Without promotion, every lobe needs a separate node for every surface
#   variant of the same shape:
#       node A: "what is 2 + 2"
#       node B: "what is two plus two"
#       node C: "what is 2 plus 2"
#       ... (combinatorial explosion)
#
#   After promotion, all of those become the SAME string at the matcher's
#   input: "what is &n &op &n". One node carries all variants. The bindings
#   side-channel carries the actual values. ATP (Stage 1.5b) and the Stage 3
#   evaluator are downstream consumers of the bindings — never see the raw
#   string, never touch confidence.
#
#   Linear → constant population for shape-equivalent prompts. The matcher
#   doesn't need any dedup logic; the front door makes the matcher's input
#   self-deduplicating.
# ==============================================================================
#
# ACADEMIC: This module implements the input-side half of the sigil bridge.
# Stage 1.5a scope:
#   - Closed canonical-form maps for number-words (0–100) and unambiguous
#     op-words (plus, minus, times, divided, over, equals).
#   - Shape predicates: :number (integer or signed integer), :op (math op
#     from the closed set {+, -, *, /, =, <, >, %, ^}).
#   - Macro membership: tokens whose canonical form sits in a :macro sigil's
#     lexicon are promoted to that sigil's name.
#   - Two-pass promoter: layer 1 (canonicalize) → layer 2 (shape-promote).
#   - Position-keyed `Vector{SigilBinding}` as the primary side-channel
#     (ordered, lossless). Name-keyed view is computed on demand.
#   - Idempotency: tokens that already look like `&knownsigil` pass through.
#   - Fast path: input with no canonicalizable, shape-eligible, or
#     macro-eligible tokens returns the input unchanged with empty bindings.
#
# What is INTENTIONALLY out of scope for Stage 1.5a (deferred):
#   - Compound number parsing ("twenty-three", "one hundred fifty"). Stage 1.5b.
#   - Decimal-word parsing ("two point five"). Stage 1.5b.
#   - Context-ambiguous op-words ("is" → "=" only when between numerics). 1.5b.
#   - ATP arithmetic dispatch (consumes bindings but is its own push). 1.5b.
#   - Render-time substitution back into the reply string.            Stage 3.
# ==============================================================================

module SigilPromoter

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

# GRUG: SigilPromoter consumes SigilRegistry. The include is done at the
# package level; here we just `using` the sibling module.
using ..SigilRegistry

# ==============================================================================
# EXPORTS
# ==============================================================================

export SigilBinding
export PromoterError, PromoterArgumentError, PromoterConfigError
export promote_input
export bindings_by_name
export NUMBER_WORD_MAP, OP_WORD_MAP, OP_SYMBOL_SET
export NUMBER_TOKEN_REGEX
export canonicalize_token

# ==============================================================================
# ERROR TYPES — GRUG: NO SILENT FAILURES on programmer errors.
# ==============================================================================
# GRUG: Same shape as SigilRegistry / SelfObserver. Distinct types per
# category so callers can pattern-match. Promoter-side errors are always
# programmer errors (bad caller input or bad registry config). There is
# never a "fall back silently" branch.

"""
Generic SigilPromoter error. Carries `message` and a free-form `context`.
"""
struct PromoterError <: Exception
    message::String
    context::String
end

"""
Argument error — caller passed bad type, nil registry, etc.
Indicates the caller used the API wrong.
"""
struct PromoterArgumentError <: Exception
    message::String
    arg::String
end

"""
Configuration error — registry is missing a required sigil for promotion,
or a sigil's class/sigil_type is incoherent with promote_at_tokenize=true.
"""
struct PromoterConfigError <: Exception
    message::String
    field::String
end

function Base.showerror(io::IO, e::PromoterError)
    print(io, "PromoterError: ", e.message, " (context=", e.context, ")")
end
function Base.showerror(io::IO, e::PromoterArgumentError)
    print(io, "PromoterArgumentError: ", e.message, " (arg=", e.arg, ")")
end
function Base.showerror(io::IO, e::PromoterConfigError)
    print(io, "PromoterConfigError: ", e.message, " (field=", e.field, ")")
end

# ==============================================================================
# LAYER 1 — CANONICAL-FORM MAPS (number-words and op-words)
# ==============================================================================
# GRUG: These are CLOSED tables. The Stage 1.5a scope locks the small finite
# set: numbers 0–100, unambiguous English op-words, and a couple of negative
# markers. Compound number parsing ("twenty-three") and context-sensitive
# words ("is") are explicitly deferred.

# GRUG: word -> digit string. Every entry pre-lowercased so the lookup is
# case-folded by walking the canonicalize_token routine first.
const NUMBER_WORD_MAP::Dict{String,String} = Dict(
    "zero"      => "0",
    "one"       => "1",
    "two"       => "2",
    "three"     => "3",
    "four"      => "4",
    "five"      => "5",
    "six"       => "6",
    "seven"     => "7",
    "eight"     => "8",
    "nine"      => "9",
    "ten"       => "10",
    "eleven"    => "11",
    "twelve"    => "12",
    "thirteen"  => "13",
    "fourteen"  => "14",
    "fifteen"   => "15",
    "sixteen"   => "16",
    "seventeen" => "17",
    "eighteen"  => "18",
    "nineteen"  => "19",
    "twenty"    => "20",
    "thirty"    => "30",
    "forty"     => "40",
    "fifty"     => "50",
    "sixty"     => "60",
    "seventy"   => "70",
    "eighty"    => "80",
    "ninety"    => "90",
    "hundred"   => "100",
)

# GRUG: word -> operator symbol. Only UNAMBIGUOUS English op-words. "is" is
# deliberately omitted (it's a definitional copula in most contexts; promoting
# it unconditionally to "=" breaks every English sentence). 1.5b adds context.
const OP_WORD_MAP::Dict{String,String} = Dict(
    "plus"        => "+",
    "minus"       => "-",
    "times"       => "*",
    "multiplied"  => "*",
    "divided"     => "/",
    "over"        => "/",
    "equals"      => "=",
    "equal"       => "=",
    # GRUG v8.19: Verb-form operators. "add 12 and 7" must produce &op binding,
    # not &concept. Without these, the SigilPromoter promotes "add" to &concept
    # (generic content word), destroying pattern specificity for action sigil nodes.
    # Adding them here means "add 12 and 7" → "&op &n and &n" with &op=add,
    # which matches node_sigil_14's updated pattern "&op &n and &n".
    "add"         => "+",
    "subtract"    => "-",
    "multiply"    => "*",
    "divide"      => "/",
)

# GRUG: closed set of operator surface forms the :op shape predicate accepts.
# Single-char ASCII. If you add a multi-char op later (== >= !=), it lives
# here AND in the regex tokenizer rules.
const OP_SYMBOL_SET::Set{String} = Set([
    "+", "-", "*", "/", "=", "<", ">", "%", "^",
])

# GRUG: NUMBER shape predicate. Optional leading minus, then digits, optional
# decimal point + more digits. We allow "+3" too (rare but valid in math text).
const NUMBER_TOKEN_REGEX::Regex = r"^[+-]?\d+(?:\.\d+)?$"

# GRUG: prefix marker. "negative three" -> "-3". The promoter peeks ahead by
# one token when it sees one of these and merges with the next token's value.
const SIGN_PREFIX_MAP::Dict{String,String} = Dict(
    "negative"  => "-",
    "positive"  => "+",
)

# ==============================================================================
# BINDING — the side-channel value record.
# ==============================================================================
# GRUG: A SigilBinding is one (position, sigil-name, value) triple. The
# promoter returns a Vector{SigilBinding} in left-to-right order. Order is
# preserved because Stage 6 procedure-class expansion needs it (the
# Antikythera idea — capture order IS the procedure step order).
#
# Position is the rewritten-string token index (0-based), NOT the byte
# offset. This makes position arithmetic cheap for downstream consumers and
# decouples it from string layout (e.g. multi-char ops don't shift offsets).

"""
A single sigil capture from the front-door promoter.

Fields:
  - `position::Int`     — 0-based token index in the REWRITTEN string.
  - `name::String`      — sigil name (no `&` prefix).
  - `value::Any`        — captured value. For :number → Int or Float64.
                          For :op → String (single-char operator).
                          For :macro → String (the canonical surface form
                          that matched the lexicon).
  - `class::Symbol`     — class of the producing sigil (mirrors SigilEntry.class).
  - `surface::String`   — the ORIGINAL surface token(s) the binding replaced
                          (e.g. "two" vs "2", "plus" vs "+"). For sign-prefix
                          merges this is the joined raw text ("negative three").
                          AIML/render phases use this to echo back in the
                          user's own register; ATP uses it for tone signals
                          (caps, word-vs-digit, written-out-vs-symbolic).
  - `raw_position::Int` — 0-based token index in the RAW input stream
                          (post-tokenize, pre-promote). Lets downstream
                          phases map a binding back to its source position
                          even after Layer 1 canonicalization rewrote tokens.
                          For sign-prefix merges, points at the FIRST raw
                          token consumed (the sign word).

The two position fields differ when canonicalization changes token count:
sign-prefix merge consumes 2 raw tokens ("negative", "three") but emits 1
rewritten token ("&n"), so `raw_position` and `position` diverge for any
binding that follows. Multi-token surface forms (currently just sign-prefix)
are the only case where 1 binding maps to >1 raw token.
"""
struct SigilBinding
    position::Int
    name::String
    value::Any
    class::Symbol
    surface::String
    raw_position::Int
end

# ==============================================================================
# CANONICALIZE — Layer 1 helper.
# ==============================================================================

"""
    canonicalize_token(tok) -> String

Apply Layer 1 canonicalization to a single token: lowercase + strip, then
look up in NUMBER_WORD_MAP / OP_WORD_MAP. Unknown tokens pass through with
just the case-fold + strip applied.

This function does NOT consult the registry. It's pure language-side
surface canonicalization. Returns the canonical form ready for Layer 2
shape promotion.
"""
function canonicalize_token(tok::AbstractString)::String
    s = lowercase(strip(String(tok)))
    if isempty(s)
        return s
    end
    if haskey(NUMBER_WORD_MAP, s)
        return NUMBER_WORD_MAP[s]
    end
    if haskey(OP_WORD_MAP, s)
        return OP_WORD_MAP[s]
    end
    return s
end

# ==============================================================================
# TOKENIZE — split raw input into tokens, treating ops as separate tokens.
# ==============================================================================
# GRUG: splitting on whitespace alone is not enough because users write
# "2+2" with no spaces. We pre-pad single-char operators with spaces, then
# split on whitespace. This is the simplest defensible tokenizer for Stage
# 1.5a; multi-char operators (==, <=, !=) and proper Unicode tokenization
# are 1.5b concerns.

# GRUG: regex that captures runs of letters, digits (with optional decimal
# part), or a single-char operator. We use one master regex via eachmatch
# so the tokenizer doesn't have to do its own splitting.
#
# CRITICAL DESIGN NOTE (Stage 1.5a): the number alternative does NOT accept a
# leading sign. Why: alternation order would make "2+2" greedily tokenize as
# ["2", "+2"] instead of ["2", "+", "2"], which collapses the binary-op shape.
# Signs in raw input are ALWAYS standalone op tokens here — that means a
# user-typed "-3" tokenizes as ["-", "3"] and the matcher sees it as a unary
# usage of &op &n. Word-form signs ("negative three") still merge to a signed
# numeric via SIGN_PREFIX_MAP + sign-prefix peek, which is the canonical path
# for true negative literals. True signed-numeric tokenization (context-aware:
# unary sign vs binary op) is a Stage 1.5b concern.
const _TOKENIZE_REGEX::Regex =
    r"&[A-Za-z\u0370-\u03FF][A-Za-z0-9_\-\u0370-\u03FF]*|\d+(?:\.\d+)?|[A-Za-z][A-Za-z'\-]*|[+\-*/=<>%^]"

# GRUG: split raw input into a Vector{Tuple{String,Int}}. Each tuple is
# (token, raw_position) where raw_position is the 0-based index of this
# token in the raw token stream (NOT a byte offset — token index).
# Each token is one of:
#   - existing sigil token (preserved verbatim, idempotency hook)
#   - signed/unsigned integer or decimal (preserved as one token)
#   - a word (letters, possibly with apostrophe or hyphen interior)
#   - a single-char operator
# Anything that doesn't match (punctuation like ?, ., commas) is dropped at
# the tokenizer. The matcher already strips those downstream so dropping
# here matches existing behaviour.
#
# raw_position is what downstream phases (ATP, AIML render) use to map a
# binding back to its origin in the user's actual input. Critical for
# preserving "two" vs "2" intent — see SigilBinding.surface / raw_position.
function _tokenize(raw::AbstractString)::Vector{Tuple{String,Int}}
    out = Tuple{String,Int}[]
    idx = 0
    for m in eachmatch(_TOKENIZE_REGEX, String(raw))
        push!(out, (String(m.match), idx))
        idx += 1
    end
    return out
end

# ==============================================================================
# PROMOTE — the main entry point.
# ==============================================================================

"""
    promote_input(table, raw) -> (rewritten::String, bindings::Vector{SigilBinding})

Front-door input promoter. Two passes:

  Layer 1 — Canonicalize each token via NUMBER_WORD_MAP / OP_WORD_MAP +
            sign-prefix handling ("negative three" → "-3").
  Layer 2 — For each canonicalized token, walk registry sigils with
            `promote_at_tokenize=true` and rewrite to the canonical sigil
            form if the token matches the sigil's shape predicate or
            macro lexicon.

Returns `(rewritten, bindings)`:
  - `rewritten` is the matcher-ready string with sigils inlined.
  - `bindings` is the position-ordered list of SigilBinding records.

NO SILENT FAILURES:
  - empty registry  → throws PromoterArgumentError (caller should pass a
    real registry, even if it's just `default_registry()`).
  - nil raw         → throws PromoterArgumentError.

FAST PATH:
  - if no token in `raw` is canonicalizable, shape-eligible, or
    macro-eligible, the rewritten string is the joined (whitespace-collapsed)
    version of `raw` with no `&` tokens added, and bindings is empty.

IDEMPOTENCY:
  - tokens that already look like `&knownsigil` are preserved verbatim and
    NOT re-promoted. `promote_input(table, promote_input(table, x).rewritten)`
    produces the same rewritten string and the same bindings as the second
    call would on raw input that has the sigils already substituted.
"""
function promote_input(
# REMINDER: Promoted sigils end up in relational triples — triples are dynamic.
    table::SigilTable,
    raw::AbstractString,
)::Tuple{String,Vector{SigilBinding}}
    if !isa(table, SigilTable)
        # Defensive — Julia's dispatch already guarantees this, but the
        # explicit check makes the error message helpful when someone
        # calls with a Dict by mistake.
        throw(PromoterArgumentError(
            "table must be a SigilTable (got $(typeof(table)))",
            "table"))
    end

    raw_str = String(raw)

    # GRUG: tokenize and run sign-merge in a single pass to keep token
    # positions correct in the bindings list. Each entry is (token, raw_pos)
    # so SigilBinding.raw_position survives Layer 1 canonicalization
    # collapsing/dropping tokens.
    raw_tokens = _tokenize(raw_str)

    # GRUG: collect the entries the registry says we should consider for
    # promotion, ONCE, before the per-token loop. Order is deterministic
    # by name so two runs against the same registry produce identical
    # results.
    promote_lambdas = SigilEntry[]
    promote_macros  = SigilEntry[]
    for e in list_sigils(table)
        if e.promote_at_tokenize
            if e.class === :lambda
                push!(promote_lambdas, e)
            elseif e.class === :macro
                push!(promote_macros, e)
            end
            # GRUG: any other class with promote_at_tokenize=true was rejected
            # at registration time — we trust the registry kernel.
        end
    end

    # GRUG: result accumulators.
    out_tokens = String[]
    bindings   = SigilBinding[]

    # GRUG: layer 1.5 — peek-ahead sign merge. We walk raw_tokens with an
    # explicit cursor so we can swallow a sign-prefix word and merge it
    # into the following number-word's canonicalization.
    i = 1
    while i <= length(raw_tokens)
        tok, raw_pos = raw_tokens[i]

        # GRUG: idempotency hook — preserve already-promoted sigil tokens.
        if !isempty(tok) && tok[1] == SIGIL_PREFIX
            # Verify it's a known sigil. If unknown, we still preserve it
            # rather than throwing — the matcher itself is the place where
            # unknown sigils in patterns throw. The promoter is permissive
            # about input it doesn't understand (raw user input could
            # legitimately contain a stray '&'). Idempotency is the goal.
            push!(out_tokens, tok)
            i += 1
            continue
        end

        lc = lowercase(tok)

        # GRUG: unary-minus peek. "-15" tokenizes as ["-", "15"] because
        # the tokenizer can't distinguish unary from binary minus. If the
        # current token is "-" and the PREVIOUS token is NOT a number, and
        # the NEXT token IS a number, merge them into a signed numeric.
        # This handles "absolute value of -15" correctly without breaking
        # "5 - 3" (where the previous token IS a number → binary op).
        if tok == "-" && i < length(raw_tokens) && (i == 1 || !occursin(NUMBER_TOKEN_REGEX, canonicalize_token(raw_tokens[i-1][1])))
            next_tok, _next_pos = raw_tokens[i+1]
            next_can = canonicalize_token(next_tok)
            if occursin(NUMBER_TOKEN_REGEX, next_can)
                stripped = lstrip(next_can, ['+', '-'])
                merged = string("-", stripped)
                merged_surface = string("-", next_tok)
                _promote_layer2!(out_tokens, bindings, merged,
                                 merged_surface, raw_pos,
                                 promote_lambdas, promote_macros)
                i += 2
                continue
            end
        end

        # GRUG: sign-prefix peek. "negative three" → "-3". Only fires when
        # the next token canonicalizes to a number-word OR is already a
        # numeric token.
        if haskey(SIGN_PREFIX_MAP, lc) && i < length(raw_tokens)
            sign = SIGN_PREFIX_MAP[lc]
            next_tok, _next_pos = raw_tokens[i+1]
            next_can = canonicalize_token(next_tok)
            if occursin(NUMBER_TOKEN_REGEX, next_can)
                # GRUG: merge into a single signed numeric. If next_can already
                # has its own sign, the sign-prefix word wins (last-prefix-wins
                # is the simplest rule and matches English usage).
                stripped = lstrip(next_can, ['+', '-'])
                merged = string(sign, stripped)
                # Surface = the user's actual two raw tokens joined ("negative three"),
                # not the canonicalized "-3". Render/ATP read this to echo back
                # in the user's register.
                merged_surface = string(tok, " ", next_tok)
                # Run layer-2 promotion on the merged numeric directly. The
                # binding's raw_position points at the FIRST raw token (the
                # sign word) — that's the user's anchor for this concept.
                _promote_layer2!(out_tokens, bindings, merged,
                                 merged_surface, raw_pos,
                                 promote_lambdas, promote_macros)
                i += 2
                continue
            end
        end

        # GRUG: Layer 1 canonicalization.
        canonical = canonicalize_token(tok)
        if isempty(canonical)
            i += 1
            continue
        end

        # GRUG: Layer 2 promotion. Pass the ORIGINAL surface token (not the
        # canonicalized form) so the binding remembers what the user typed.
        _promote_layer2!(out_tokens, bindings, canonical,
                         tok, raw_pos,
                         promote_lambdas, promote_macros)
        i += 1
    end

    rewritten = join(out_tokens, " ")
    return (rewritten, bindings)
end

# GRUG: Layer 2 helper. Given a canonicalized token (already lowercased and
# number-word-resolved), walk the registry's promotable lambdas and macros
# in deterministic order, capture the first match, append the resulting
# sigil-or-literal token + binding to the accumulators.
#
# `surface` is the ORIGINAL raw token (or joined tokens for sign-prefix
# merges). `raw_pos` is the 0-based index of that token in the raw stream.
# Both feed straight into SigilBinding so downstream phases can read them.
#
# In-place mutation of out_tokens and bindings keeps the main loop simple
# and avoids per-token allocation churn.
function _promote_layer2!(
    out_tokens::Vector{String},
    bindings::Vector{SigilBinding},
    canonical::String,
    surface::AbstractString,
    raw_pos::Int,
    promote_lambdas::Vector{SigilEntry},
    promote_macros::Vector{SigilEntry},
)
    # GRUG: try each promotable lambda's shape predicate.
    for e in promote_lambdas
        # Stage 1.5c conditional gate. If the registry entry carries a
        # user-supplied promote_predicate, ask it first; only run the
        # shape predicate when the gate allows.
        if !_predicate_allows(e, canonical)
            continue
        end
        captured = _try_lambda_promote(e, canonical)
        if captured !== nothing
            pos = length(out_tokens)
            push!(out_tokens, string(SIGIL_PREFIX, e.name))
            push!(bindings, SigilBinding(
                pos, e.name, captured, :lambda,
                String(surface), raw_pos))
            return nothing
        end
    end

    # GRUG: try each promotable macro's lexicon membership.
    for e in promote_macros
        # Stage 1.5c conditional gate (same rule as lambdas above).
        if !_predicate_allows(e, canonical)
            continue
        end
        if e.lexicon !== nothing && canonical in e.lexicon
            pos = length(out_tokens)
            push!(out_tokens, string(SIGIL_PREFIX, e.name))
            push!(bindings, SigilBinding(
                pos, e.name, canonical, :macro,
                String(surface), raw_pos))
            return nothing
        end
    end

    # GRUG: nothing matched — token passes through as a literal. No binding
    # is recorded; the literal lands in out_tokens at the canonicalized
    # form (lowercased + number-word-resolved). surface/raw_pos go unused
    # for fast-path tokens because there's nothing to map back to.
    push!(out_tokens, canonical)
    return nothing
end

# GRUG: Stage 1.5c — per-entry conditional gate. If the registry entry has
# a promote_predicate set, call it with the canonical token. The predicate
# MUST return Bool; anything else is a PromoterConfigError attributable to
# the registry author. If the predicate raises, we wrap and rethrow with
# context so the user can see which sigil and which token tripped it.
#
# Returns true when the entry should be considered for promotion (either
# because no predicate is set, or because the predicate returned true).
# Returns false when the predicate returned false.
#
# No silent failures: predicate exceptions and non-Bool returns both raise.
function _predicate_allows(e::SigilEntry, canonical::String)::Bool
    pred = e.promote_predicate
    pred === nothing && return true
    result = try
        pred(canonical)
    catch err
        throw(PromoterConfigError(
            "promote_predicate for &$(e.name) raised on token $(repr(canonical)): $(err)",
            "promote_predicate"))
    end
    if !(result isa Bool)
        throw(PromoterConfigError(
            "promote_predicate for &$(e.name) returned $(typeof(result)) ($(repr(result))) on token $(repr(canonical)); must return Bool",
            "promote_predicate"))
    end
    return result
end

# GRUG: per-sigil_type shape predicate. Returns the captured value or nothing.
# Centralized here so adding a new shape (e.g. :date) in 1.5b is a single
# additive branch.
function _try_lambda_promote(
    e::SigilEntry,
    canonical::String,
)::Union{Nothing,Any}
    st = e.sigil_type
    if st === :number
        if occursin(NUMBER_TOKEN_REGEX, canonical)
            # GRUG: parse to Int when integer, Float64 when decimal. The
            # bound value is what Stage 3's evaluator will actually compute
            # on, so it should be a real numeric type, not a string.
            return occursin('.', canonical) ? parse(Float64, canonical) :
                                              parse(Int, canonical)
        end
        return nothing
    elseif st === :op
        return canonical in OP_SYMBOL_SET ? canonical : nothing
    elseif st === :word
        # :word is NOT promote-eligible by policy (every word would match,
        # defeating the purpose). The registry validation should have
        # rejected promote_at_tokenize=true on a :word lambda — but we
        # belt-and-suspenders here in case a future schema change permits it.
        return nothing
    elseif st === :slurp
        # :slurp is multi-token by definition; can't promote a single token.
        return nothing
    # GRUG v8.18: Knowledge-layer shape predicates. These partition pattern
    # space so math sigils (&n &op &n) don't compete with knowledge/definition
    # nodes. Each shape predicate checks the token against a closed set of
    # qualifying words.
    elseif st === :concept
        # :concept — any non-stopword, non-operator token. The promote_predicate
        # in the registry already filters out stopwords and operators, so if
        # the promote_predicate passed, this token qualifies as a concept.
        # We just return the canonical string (no numeric parsing needed).
        return canonical
    elseif st === :query
        # :query — question words (what, who, how, why, when, where, etc.)
        # The promote_predicate already gates the closed set, so if we reach
        # here the token matched. Return the canonical string.
        return canonical
    elseif st === :definition
        # :definition — definition verbs (is, are, means, refers, etc.)
        # The promote_predicate already gates the closed set. Return canonical.
        return canonical
    elseif st === :action
        # :action — action verbs (explain, describe, tell, define, etc.)
        # The promote_predicate already gates the closed set. Return canonical.
        return canonical
    elseif st === :define
        # GRUG v9: :define — dictionary-defined word placeholder.
        # The promote_predicate (via _DICT_WORD_CHECKER) already gated that
        # this token has a dictionary entry. Return the canonical string —
        # the binding's .surface field preserves the original word for
        # dictionary lookup at vote time.
        return canonical
    else
        # GRUG v8.19: user-registered sigils (via /sigil add) may carry
        # custom sigil_types that have no hardcoded shape branch here.
        # Instead of throwing, fall back to the promote_predicate: if the
        # predicate already passed (it's checked before this function in the
        # promote pipeline), the token qualifies and we return canonical.
        # If no predicate exists either, THEN it's a config error.
        if e.promote_predicate !== nothing
            # The predicate already gated acceptance upstream; return the
            # canonical string as the captured value (same as &concept etc.)
            return canonical
        end
        # GRUG: no shape branch AND no promote_predicate — genuine config error.
        throw(PromoterConfigError(
            "sigil &$(e.name) has promote_at_tokenize=true but unknown sigil_type :$(st) and no promote_predicate; promoter has no shape predicate for it",
            "sigil_type"))
    end
end

# ==============================================================================
# CONVENIENCE — name-keyed view of bindings (computed lazily).
# ==============================================================================

"""
    bindings_by_name(bindings) -> Dict{String, Vector{Any}}

Group `bindings` by sigil name, preserving left-to-right order within each
group. Useful for consumers that don't care about absolute position
(e.g. a thesaurus context-shaper) but do care about per-name occurrence
order (e.g. an arithmetic evaluator that wants `n=[2, 7]`).

The position-keyed Vector{SigilBinding} returned by `promote_input` is the
authoritative structure. This view is a derived projection — NEVER use it
as the sole storage of bindings; always carry the position-keyed list.
"""
function bindings_by_name(
    bindings::Vector{SigilBinding},
)::Dict{String,Vector{Any}}
    out = Dict{String,Vector{Any}}()
    for b in bindings
        v = get!(out, b.name) do
            Any[]
        end
        push!(v, b.value)
    end
    return out
end

end # module SigilPromoter
