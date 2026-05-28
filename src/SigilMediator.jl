# ==============================================================================
# SigilMediator.jl  -  GRUG v7.16+
# ==============================================================================
# GRUG: Thin coordinator between user input and the sigil routing layer.
#
# WHY: process_mission() needs ONE call site that says "if this input has
#       structure that warrants sigil routing, give me back the rewritten
#       text + bindings + a verdict on what kind of routing applies." That's
#       this module. It does NOT touch nodes, votes, or the engine \u2014 it just
#       turns raw user text into a structured handle the rest of the engine
#       can act on.
#
# WHAT IT DOES:
#   1. Calls promote_input(default_table(), raw) once per mission.
#   2. Inspects the resulting bindings to decide what kinds of sigil-routed
#      nodes (if any) should be considered for direct firing.
#   3. Returns a SigilMediation handle carrying:
#        - rewritten text (what scan_specimens sees)
#        - bindings (what cast_sigil_votes consumes)
#        - original text (what action-tone / arithmetic look at)
#        - kinds :: Vector{Symbol} (e.g. [:math], [:multipart], or [])
#
# WHAT IT DOESN'T DO:
#   - Compute math (that's ArithmeticEngine, called by the multi-vote caster).
#   - Decide which nodes fire (that's the engine fire path).
#   - Rewrite saved data (the original text is preserved for downstream use).
#
# NO SILENT FAILURES: promote_input throws on malformed registry; we let
# those propagate. Empty/whitespace input throws ArgumentError up front.
# ==============================================================================

module SigilMediator

using ..SigilRegistry
using ..SigilPromoter
using ..ArithmeticEngine

export SigilMediation, mediate, has_math, has_multipart, kinds_for_bindings

# ==============================================================================
# DATA SHAPE
# ==============================================================================

"""
    SigilMediation

Handle returned by `mediate(raw)`. All fields are read-only references to
strings/vectors the caller is free to share across the cycle.

Fields:
  - `original::String`   : the raw user input, unchanged.
  - `rewritten::String`  : the sigil-promoted form (e.g. "&n &op &n").
  - `bindings::Vector{SigilBinding}` : value bindings from promotion.
  - `kinds::Vector{Symbol}` : routing kinds detected (e.g. [:math, :multipart]).
"""
struct SigilMediation
    original::String
    rewritten::String
    bindings::Vector{SigilBinding}
    kinds::Vector{Symbol}
end

# ==============================================================================
# KIND DETECTION
# ==============================================================================
# GRUG: closed taxonomy of routing kinds. Add to this enum (and update
# kinds_for_bindings) when wiring a new structured-reasoning lane.
#
# Current kinds:
#   :math      \u2014 has at least 2 &n + 1 &op (delegates to has_math_bindings)
#   :multipart \u2014 has at least 1 &conj binding (clause-boundary detected)
#
# A single input can carry multiple kinds (e.g. "what is 2+2 and 3-1" \u2192
# [:math, :multipart]). Caller is free to dispatch to multiple node lanes.

"""
    has_math(bindings) -> Bool

True when the bindings contain enough math sigils to attempt arithmetic.
Thin wrapper over `ArithmeticEngine.has_math_bindings` so callers don't
need to reach into ArithmeticEngine directly.
"""
has_math(bindings::Vector{SigilBinding})::Bool = has_math_bindings(bindings)

"""
    has_multipart(bindings) -> Bool

True when the bindings contain at least one `&conj` binding, indicating
a clause-boundary in the input.
"""
has_multipart(bindings::Vector{SigilBinding})::Bool =
    any(b -> b.name == "conj", bindings)

"""
    kinds_for_bindings(bindings) -> Vector{Symbol}

Inspect `bindings` and return the deterministic-order list of routing kinds
that apply. Order is fixed: [:math, :multipart] (when both apply) so that
downstream dispatch is stable across runs.
"""
function kinds_for_bindings(bindings::Vector{SigilBinding})::Vector{Symbol}
    out = Symbol[]
    has_math(bindings)      && push!(out, :math)
    has_multipart(bindings) && push!(out, :multipart)
    return out
end

# ==============================================================================
# MEDIATE — the one-call entry point
# ==============================================================================

"""
    mediate(raw) -> SigilMediation

Promote `raw` against the process-wide singleton table and return a
SigilMediation handle. Throws ArgumentError on empty/whitespace input.
PromoterError variants surface from promote_input unchanged.
"""
function mediate(raw::AbstractString)::SigilMediation
    s = String(raw)
    if isempty(strip(s))
        throw(ArgumentError("SigilMediator.mediate: input must be non-empty"))
    end
    rewritten, bindings = promote_input(default_table(), s)
    return SigilMediation(s, rewritten, bindings, kinds_for_bindings(bindings))
end

end # module SigilMediator
