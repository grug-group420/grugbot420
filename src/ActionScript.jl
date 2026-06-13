# ============================================================
# ActionScript.jl — &doAction reserved sigil macro system
# ============================================================
# GRUG v7.31: Verb-driven action scripting. Users define action
# entries (the "side list") that map trigger verbs to execution
# templates. &doAction is a RESERVED :procedure-class sigil —
# not user-definable as a sigil name, but its action entries ARE
# user-definable. The thesaurus expands trigger verbs so "say",
# "repeat", "chant" all hit the same entry.
#
# GRUG v7.35: CONDITIONAL OPERATIONS. Dynamic templates can now
# branch on runtime values. This closes the biggest gap between
# :static and :dynamic — dynamic entries can inspect slot values
# and RESOLVE results before deciding what to emit.
#
# Built-in operations:
#   REPEAT(n)       — loop output n times
#   SAY(text)       — emit text verbatim
#   RESOLVE(ref)    — look up a reference (date, now, recent, etc.)
#   COMPUTE(expr)   — delegate to math sigil (future)
#
# Conditional operations (dynamic only):
#   IF(pred, then, else)   — branch on predicate truth
#   WHEN(pred, then)       — branch with empty else
#   UNLESS(pred, then)     — inverse WHEN (true when pred is false)
#
# Predicate operations (return Bool, used inside conditionals):
#   EQUALS(a, b)     — string equality after evaluation
#   CONTAINS(hay, needle) — substring test after evaluation
#   PRESENT(expr)    — true if evaluated expression is non-empty & not a fallback
#   EMPTY(expr)      — inverse of PRESENT
#   HAS(ref)         — true if RESOLVE(ref) returns meaningful content
#   GT(a, b)         — numeric greater-than
#   LT(a, b)         — numeric less-than
#   GTE(a, b)        — numeric greater-or-equal
#   LTE(a, b)        — numeric less-or-equal
#
# Template slots: {{target}}, {{count}}, {{n}}, {{word}}, {{rest}}
# filled from SigilBinding values at execution time.
#
# MEMORY SPLIT (replaces time nodes):
#   - Subconscious signal: deep memory traces (ages ago), influences
#     confidence weighting without explicit recall.
#   - Regular 10k buffer: "the now", recent context, active stuff.
#   RESOLVE knows which layer to query based on the reference word.
# ============================================================

module ActionScript

using Dates
using ..SemanticVerbs

export ActionEntry, ActionRegistry,
       register_action!, unregister_action!, lookup_action,
       list_actions, execute_action, resolve_reference,
       resolve_multi_reference, set_resolve_conflict_mode!,
       get_resolve_conflict_mode,
       ACTION_OPS, CONDITIONAL_OPS, PREDICATE_OPS, ALL_OPS,
       is_action_trigger, get_action_triggers

# ── OPERATION TYPE CLASSIFICATION ──────────────────────────

# Core operations — linear, always valid
const ACTION_OPS = Set{String}([
    "REPEAT", "SAY", "RESOLVE", "COMPUTE"
])

# Conditional operations — only valid in :dynamic templates
const CONDITIONAL_OPS = Set{String}([
    "IF", "WHEN", "UNLESS"
])

# Predicate operations — only valid inside conditionals
const PREDICATE_OPS = Set{String}([
    "EQUALS", "CONTAINS", "PRESENT", "EMPTY", "HAS",
    "GT", "LT", "GTE", "LTE"
])

# Union of all known operations
const ALL_OPS = union(ACTION_OPS, CONDITIONAL_OPS, PREDICATE_OPS)

# Fallback strings that indicate a RESOLVE didn't find real content
const _RESOLVE_FALLBACKS = Set([
    "(no recent context available)",
    "(recent context unavailable)",
    "(no deep memory trace found)",
    "(deep memory trace unavailable)",
    "(deep memory trace: not yet wired)",
    "(nothing recent)",
    "(deep memory trace not found)",
])

# ── CONFLICT RESOLUTION FOR COMPOUND REFS ────────────────────
# GRUG v7.36: When a single resolve_reference call contains
# multiple ref keywords (e.g. "recent and ages ago"), we need
# a strategy for combining results from different memory layers.

# Valid conflict resolution modes
const CONFLICT_MODES = Set{Symbol}([:merge, :priority, :first_wins])

# Current global conflict mode (default :merge)
const _CONFLICT_MODE = Ref{Symbol}(:merge)

# Priority order for :priority mode — clock > recent > deep > literal
const _REF_PRIORITY = [:clock, :recent, :deep, :literal]

# Compound joiners that indicate multiple refs in one string
const _COMPOUND_JOINERS = [", ", " and ", " or ", "; ", " plus "]

# All known ref keywords grouped by category for compound detection
const _CLOCK_KEYWORDS = Set(["date", "time", "now", "today", "datetime",
                             "clock", "timestamp", "day", "year"])
const _RECENT_KEYWORDS = Set(["recent", "last", "latest", "happening"])
const _DEEP_KEYWORDS = Set(["ages ago", "long ago", "back then", "remember",
                            "ago", "earlier", "before", "past",
                            "old memory", "distant", "far back", "way back"])

# ── ACTION ENTRY ───────────────────────────────────────────
# One row in the user's "side list". Defines a trigger verb,
# whether the action is static (fixed output) or dynamic (template
# with capture slots and/or conditional branching), and the
# execution template.

struct ActionEntry
    trigger_verb::String           # Primary verb: "say", "repeat", etc.
    action_type::Symbol            # :static or :dynamic
    template::String               # Execution template: "REPEAT({{target}}, {{count}})"
                                   # For static: just "SAY(some fixed text)"
                                   # For dynamic: may include IF/WHEN/UNLESS
    description::String            # Human-readable description for /help
end

# ── ACTION REGISTRY (THE SIDE LIST) ────────────────────────

mutable struct ActionRegistry
    entries::Dict{String, ActionEntry}   # keyed by trigger_verb (lowercase)
    label::String
end

ActionRegistry() = ActionRegistry(Dict{String, ActionEntry}(), "unlabeled")
ActionRegistry(label::AbstractString) = ActionRegistry(Dict{String, ActionEntry}(), String(label))

# ── GLOBAL SINGLETON ───────────────────────────────────────
# One ActionRegistry per cave, same pattern as SigilTable singleton.

const _GLOBAL_REGISTRY = Ref{ActionRegistry}(ActionRegistry("engine-default"))

action_registry()::ActionRegistry = _GLOBAL_REGISTRY[]
reset_action_registry!() = (_GLOBAL_REGISTRY[] = ActionRegistry("engine-default"); nothing)

# ── REGISTRATION ───────────────────────────────────────────

"""
    register_action!(; trigger_verb, action_type, template, description="")

Add an action entry to the global registry. The trigger_verb must
already be a registered verb in SemanticVerbs (or be added first).
Throws on empty trigger or unknown op in template.

Validation rules:
  - All ops in template must be in ALL_OPS
  - CONDITIONAL_OPS only allowed in :dynamic templates
  - PREDICATE_OPS only allowed in :dynamic templates (they only
    make sense inside conditionals, but we allow them at the top
    level too for extensibility — the predicate itself will return
    a string "true"/"false" when used outside a conditional)
"""
function register_action!(;
    trigger_verb::AbstractString,
    action_type::Symbol,
    template::AbstractString,
    description::AbstractString = ""
)::ActionEntry
    tv = lowercase(strip(trigger_verb))
    if isempty(tv)
        error("register_action!: trigger_verb must be non-empty")
    end
    if action_type ∉ (:static, :dynamic)
        error("register_action!: action_type must be :static or :dynamic (got :$action_type)")
    end
    # Validate template contains only known ops
    _validate_template(template, action_type)

    entry = ActionEntry(tv, action_type, String(template), String(description))
    _GLOBAL_REGISTRY[].entries[tv] = entry

    # Also register under all synonyms of the trigger verb
    syns = SemanticVerbs.synonyms_of(tv)
    for s in syns
        _GLOBAL_REGISTRY[].entries[lowercase(s)] = entry
    end

    return entry
end

"""
    unregister_action!(trigger_verb)

Remove an action entry and all its synonym aliases.
"""
function unregister_action!(trigger_verb::AbstractString)
    tv = lowercase(strip(trigger_verb))
    entry = get(_GLOBAL_REGISTRY[].entries, tv, nothing)
    isnothing(entry) && return nothing

    # Remove the primary + all synonym aliases
    syns = SemanticVerbs.synonyms_of(tv)
    delete!(_GLOBAL_REGISTRY[].entries, tv)
    for s in syns
        delete!(_GLOBAL_REGISTRY[].entries, lowercase(s))
    end
    return entry
end

"""
    lookup_action(verb) -> ActionEntry or nothing
"""
function lookup_action(verb::AbstractString)::Union{ActionEntry, Nothing}
    return get(_GLOBAL_REGISTRY[].entries, lowercase(strip(verb)), nothing)
end

"""
    list_actions() -> Vector{ActionEntry}
"""
function list_actions()::Vector{ActionEntry}
    return collect(unique(values(_GLOBAL_REGISTRY[].entries)))
end

"""
    is_action_trigger(token) -> Bool

True when the token is a registered action trigger verb (or synonym).
Used by the sigil promoter's promote_predicate for &doAction.
"""
function is_action_trigger(token::AbstractString)::Bool
    return haskey(_GLOBAL_REGISTRY[].entries, lowercase(strip(token)))
end

"""
    get_action_triggers() -> Set{String}

All tokens that should trigger &doAction promotion.
"""
function get_action_triggers()::Set{String}
    return Set(keys(_GLOBAL_REGISTRY[].entries))
end

# ── TEMPLATE VALIDATION ────────────────────────────────────

function _validate_template(template::AbstractString, action_type::Symbol=:dynamic)
    # Scan for operation calls — word followed by (
    for m in eachmatch(r"([A-Z]+)\s*\(", template)
        op = m.captures[1]
        if op ∉ ALL_OPS
            error("register_action!: unknown operation '$op' in template (allowed: $(sort(collect(ALL_OPS))))")
        end
        # Conditional and predicate ops only allowed in :dynamic templates
        if op in CONDITIONAL_OPS && action_type === :static
            error("register_action!: conditional op '$op' not allowed in :static template (use :dynamic)")
        end
        if op in PREDICATE_OPS && action_type === :static
            error("register_action!: predicate op '$op' not allowed in :static template (use :dynamic)")
        end
    end
end

# ── TEMPLATE RENDERING ─────────────────────────────────────
# Fill {{slot}} placeholders from a dict of bindings.

function render_template(template::AbstractString, slots::Dict{String, Any})::String
    result = template
    for (key, val) in slots
        result = replace(result, "{{$(key)}}" => string(val))
    end
    return result
end

# ── ARGUMENT SPLITTING ─────────────────────────────────────
# Split a comma-separated argument list at top-level commas,
# respecting nested parentheses. "IF(EQUALS(a, b), SAY(x), SAY(y))"
# splits into ["EQUALS(a, b)", "SAY(x)", "SAY(y)"].
# Without this, the comma inside EQUALS(a, b) would cause a
# wrong split.

function _split_args(args_str::AbstractString)::Vector{String}
    args_str = strip(args_str)
    if isempty(args_str)
        return String[]
    end
    parts = String[]
    depth = 0
    buf = IOBuffer()
    for c in args_str
        if c == '('
            depth += 1
            write(buf, c)
        elseif c == ')'
            depth = max(0, depth - 1)
            write(buf, c)
        elseif c == ',' && depth == 0
            push!(parts, strip(String(take!(buf))))
        else
            write(buf, c)
        end
    end
    remainder = strip(String(take!(buf)))
    if !isempty(remainder)
        push!(parts, remainder)
    end
    return parts
end

# ── PREDICATE EVALUATION ───────────────────────────────────
# Predicates return Bool. They are used inside IF/WHEN/UNLESS
# to decide which branch to take. When a predicate op appears
# outside a conditional (e.g. at the top level of a string chain),
# it returns "true" or "false" as a string for backward compat.

"""
    _eval_predicate(chain) -> Bool

Evaluate a predicate expression and return a boolean.
Used by IF/WHEN/UNLESS to decide branching.
"""
function _eval_predicate(chain::AbstractString)::Bool
    chain = strip(chain)

    # Base case: no operation call — treat as truthy check
    if !occursin(r"[A-Z]+\s*\(", chain)
        return _is_truthy(chain)
    end

    # Try to match outermost op
    m = match(r"^([A-Z]+)\s*\((.+)\)\s*$", chain)
    if isnothing(m)
        return _is_truthy(chain)
    end

    op = String(m.captures[1])
    args_str = String(m.captures[2])

    if op == "EQUALS"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        a = _eval_op_chain(parts[1])
        b = _eval_op_chain(parts[2])
        return lowercase(strip(a)) == lowercase(strip(b))

    elseif op == "CONTAINS"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        haystack = _eval_op_chain(parts[1])
        needle = _eval_op_chain(parts[2])
        return occursin(lowercase(strip(needle)), lowercase(strip(haystack)))

    elseif op == "PRESENT"
        val = _eval_op_chain(args_str)
        return _is_present(val)

    elseif op == "EMPTY"
        val = _eval_op_chain(args_str)
        return !_is_present(val)

    elseif op == "HAS"
        # HAS(ref) — test if RESOLVE returns meaningful content
        val = resolve_reference(_eval_op_chain(args_str))
        return _is_present(val)

    elseif op == "GT"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        a = tryparse(Float64, _eval_op_chain(parts[1]))
        b = tryparse(Float64, _eval_op_chain(parts[2]))
        (isnothing(a) || isnothing(b)) && return false
        return a > b

    elseif op == "LT"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        a = tryparse(Float64, _eval_op_chain(parts[1]))
        b = tryparse(Float64, _eval_op_chain(parts[2]))
        (isnothing(a) || isnothing(b)) && return false
        return a < b

    elseif op == "GTE"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        a = tryparse(Float64, _eval_op_chain(parts[1]))
        b = tryparse(Float64, _eval_op_chain(parts[2]))
        (isnothing(a) || isnothing(b)) && return false
        return a >= b

    elseif op == "LTE"
        parts = _split_args(args_str)
        if length(parts) < 2
            return false
        end
        a = tryparse(Float64, _eval_op_chain(parts[1]))
        b = tryparse(Float64, _eval_op_chain(parts[2]))
        (isnothing(a) || isnothing(b)) && return false
        return a <= b

    else
        # Unknown predicate — evaluate as string and check truthiness
        return _is_truthy(_eval_op_chain(chain))
    end
end

"""
    _is_truthy(s) -> Bool

Coerce a string to boolean for predicate evaluation.
Empty string, "false", "0", "no", fallback strings → false.
Everything else → true.
"""
function _is_truthy(s::AbstractString)::Bool
    s = strip(s)
    if isempty(s)
        return false
    end
    ls = lowercase(s)
    if ls in ("false", "0", "no", "null", "nothing", "none")
        return false
    end
    if s in _RESOLVE_FALLBACKS
        return false
    end
    return true
end

"""
    _is_present(s) -> Bool

True if the string is non-empty and not a RESOLVE fallback placeholder.
Used by PRESENT/EMPTY/HAS predicates.
"""
function _is_present(s::AbstractString)::Bool
    s = strip(s)
    isempty(s) && return false
    return s ∉ _RESOLVE_FALLBACKS
end

# ── EXECUTION ──────────────────────────────────────────────

"""
    execute_action(entry, slots) -> String

Execute an ActionEntry's template with the given slot values.
Parses the operation chain and runs each one, concatenating results.

For static actions: just evaluates SAY(content).
For dynamic actions: fills slots first, then evaluates (including
conditional branching via IF/WHEN/UNLESS).
"""
function execute_action(entry::ActionEntry, slots::Dict{String, Any} = Dict{String, Any}())::String
    rendered = render_template(entry.template, slots)
    return _eval_op_chain(rendered)
end

"""
    _eval_op_chain(chain) -> String

Parse and evaluate a chain of operations like:
  REPEAT(RESOLVE(date), 200)
  SAY(hello world)
  IF(EQUALS({{target}}, "date"), SAY(Today is RESOLVE(date)), SAY(Not sure))

Operations are evaluated innermost-first (like function calls).
Returns the final assembled output string.
"""
function _eval_op_chain(chain::AbstractString)::String
    chain = strip(string(chain))

    # Base case: no operation call — just return as literal text
    if !occursin(r"[A-Z]+\s*\(", chain)
        return chain
    end

    # Find the outermost operation
    m = match(r"^([A-Z]+)\s*\((.+)\)\s*$", chain)
    if isnothing(m)
        # Maybe it's a compound — try to parse just the outermost
        # For now, return as-is if we can't parse
        return chain
    end

    op = String(m.captures[1])
    args_str = String(m.captures[2])

    if op == "SAY"
        # SAY(text) — evaluate inner args, return as string
        inner = _eval_op_chain(args_str)
        return inner

    elseif op == "RESOLVE"
        # RESOLVE(reference) — look up a reference
        # GRUG v7.36: Detect compound refs and use multi-reference
        # resolution when multiple ref keywords appear in one input.
        inner = _eval_op_chain(args_str)
        return resolve_multi_reference(inner)

    elseif op == "REPEAT"
        # REPEAT(content, count) — repeat content n times
        # Split on the LAST comma to separate content from count
        # (content itself might contain commas from inner ops)
        # GRUG v7.35: Use _split_args for nested-paren safety.
        # But REPEAT conventionally takes (content, count) where
        # count is the LAST arg. If _split_args gives >2 parts
        # (from nested ops), the last part is count and everything
        # before it is content.
        parts = _split_args(args_str)
        if isempty(parts)
            return ""
        elseif length(parts) == 1
            return _eval_op_chain(parts[1])  # no count? just eval content
        end

        # Last part is count, everything before is content
        count_str = strip(parts[end])
        content_parts = parts[1:end-1]
        content_str = strip(join(content_parts, ","))

        content = _eval_op_chain(content_str)
        count = tryparse(Int, count_str)
        if isnothing(count)
            # count might be a slot that didn't get filled — try eval
            count_eval = _eval_op_chain(count_str)
            count = tryparse(Int, count_eval)
        end
        if isnothing(count) || count <= 0
            return content  # can't repeat? just return content once
        end

        # Cap at 500 to prevent abuse
        count = min(count, 500)
        return repeat(content * " ", count) |> strip |> String

    elseif op == "COMPUTE"
        # Future: delegate to ArithmeticEngine
        # For now, just return the expression as-is
        return _eval_op_chain(args_str)

    # ── CONDITIONAL OPERATIONS ──────────────────────────────
    # These branch on predicates. The _split_args parser handles
    # nested parentheses so IF(EQUALS(a, b), SAY(x), SAY(y))
    # correctly splits into 3 args, not 5.

    elseif op == "IF"
        # IF(predicate, then_expr[, else_expr])
        parts = _split_args(args_str)
        if isempty(parts)
            return ""
        end
        pred_str = strip(parts[1])
        then_str = length(parts) >= 2 ? strip(parts[2]) : ""
        else_str = length(parts) >= 3 ? strip(parts[3]) : ""

        if _eval_predicate(pred_str)
            return isempty(then_str) ? "" : _eval_op_chain(then_str)
        else
            return isempty(else_str) ? "" : _eval_op_chain(else_str)
        end

    elseif op == "WHEN"
        # WHEN(predicate, then_expr) — IF with empty else
        parts = _split_args(args_str)
        if isempty(parts)
            return ""
        end
        pred_str = strip(parts[1])
        then_str = length(parts) >= 2 ? strip(parts[2]) : ""

        if _eval_predicate(pred_str)
            return isempty(then_str) ? "" : _eval_op_chain(then_str)
        else
            return ""
        end

    elseif op == "UNLESS"
        # UNLESS(predicate, then_expr) — inverse WHEN
        parts = _split_args(args_str)
        if isempty(parts)
            return ""
        end
        pred_str = strip(parts[1])
        then_str = length(parts) >= 2 ? strip(parts[2]) : ""

        if !_eval_predicate(pred_str)
            return isempty(then_str) ? "" : _eval_op_chain(then_str)
        else
            return ""
        end

    # ── PREDICATE OPS AT TOP LEVEL ──────────────────────────
    # When a predicate appears outside a conditional (unusual but
    # not invalid), return "true"/"false" as a string so the chain
    # continues to work.

    elseif op in PREDICATE_OPS
        result = _eval_predicate(chain)
        return result ? "true" : "false"

    else
        # Unknown op — return literal
        return chain
    end
end

# ── RESOLVE SYSTEM ─────────────────────────────────────────
# The reference lookup system. Replaces time nodes.
# "date" / "time" / "now" → system clock
# "recent" / "what now" → regular 10k buffer (set by engine at runtime)
# "ages ago" / "long ago" / "back then" → subconscious signal layer

# Mutable ref so the engine can inject the recent-messages callback
# and the subconscious-signal callback at runtime without circular deps.
const _RECENT_CALLBACK = Ref{Function}(function(endpoint)
    return "(no recent context available)"
end)
const _SUBCONSCIOUS_CALLBACK = Ref{Function}(function(query)
    return "(no deep memory trace found)"
end)

function set_recent_callback!(fn::Function)
    _RECENT_CALLBACK[] = fn
end

function set_subconscious_callback!(fn::Function)
    _SUBCONSCIOUS_CALLBACK[] = fn
end

"""
    resolve_reference(ref) -> String

Look up a reference by keyword. This is the RESOLVE operation engine.
Routes to the appropriate memory layer:
  - System clock refs: "date", "time", "now", "today", "datetime"
  - Regular 10k buffer (the now): "recent", "last", "what now"
  - Subconscious signal layer (ages ago): "ago", "ages ago", "long ago", "back then", "remember"
"""
function resolve_reference(ref::AbstractString)::String
    r = lowercase(strip(ref))

    # ── SYSTEM CLOCK ───────────────────────────────────────
    clock_refs = Set(["date", "time", "now", "today", "datetime",
                      "clock", "timestamp", "day", "year"])
    if r in clock_refs
        now = Dates.now()
        if r in Set(["date", "today", "day"])
            return Dates.format(now, "yyyy-mm-dd")
        elseif r == "time"
            return Dates.format(now, "HH:MM:SS")
        elseif r in Set(["now", "datetime", "clock", "timestamp"])
            return Dates.format(now, "yyyy-mm-dd HH:MM:SS")
        elseif r == "year"
            return string(Dates.year(now))
        end
    end

    # ── REGULAR 10K BUFFER (THE NOW) ──────────────────────
    recent_refs = Set(["recent", "last", "what now", "what's new",
                       "latest", "happening"])
    if r in recent_refs || startswith(r, "recent") || startswith(r, "last ")
        try
            return _RECENT_CALLBACK[](r)
        catch
            return "(recent context unavailable)"
        end
    end

    # ── SUBCONSCIOUS SIGNAL LAYER (AGES AGO) ──────────────
    deep_refs = Set(["ages ago", "long ago", "back then", "remember",
                     "ago", "earlier", "before", "past", "old memory",
                     "distant", "far back", "way back"])
    if r in deep_refs || occursin("ago", r) || occursin("remember", r) ||
       occursin("back then", r) || occursin("long ago", r)
        try
            return _SUBCONSCIOUS_CALLBACK[](r)
        catch
            return "(deep memory trace unavailable)"
        end
    end

    # ── FALLBACK: return the ref as literal ───────────────
    return ref
end

# ── COMPOUND REF CONFLICT RESOLUTION ────────────────────────
# GRUG v7.36: resolve_multi_reference handles inputs containing
# multiple ref keywords from different memory layers.

"""
    _classify_ref(ref) -> Symbol

Classify a single ref keyword into its memory layer category.
Returns :clock, :recent, :deep, or :literal.
"""
function _classify_ref(ref::AbstractString)::Symbol
    r = lowercase(strip(ref))
    if r in _CLOCK_KEYWORDS
        return :clock
    end
    if r in _RECENT_KEYWORDS || startswith(r, "recent") || startswith(r, "last ")
        return :recent
    end
    if r in _DEEP_KEYWORDS || occursin("ago", r) || occursin("remember", r) ||
       occursin("back then", r) || occursin("long ago", r)
        return :deep
    end
    return :literal
end

"""
    _split_compound_refs(ref) -> Vector{String}

Split a compound reference string into individual ref keywords.
Handles "recent and ages ago", "date, time", "recent or last" etc.
Also detects adjacent-category keywords even without explicit joiners
(e.g. "recent ages ago" is split if both keywords are recognized).
"""
function _split_compound_refs(ref::AbstractString)::Vector{String}
    r = strip(lowercase(ref))
    if isempty(r)
        return String[]
    end

    # Pass 1: split on known compound joiners
    parts = String[]
    remaining = r
    for joiner in _COMPOUND_JOINERS
        if occursin(joiner, remaining)
            splits = split(remaining, joiner; keepempty=false)
            for s in splits
                push!(parts, strip(String(s)))
            end
            remaining = ""  # consumed
            break
        end
    end

    # If no joiner found, try detecting adjacent known keywords
    if isempty(parts)
        # Scan for known multi-word phrases first (longest match)
        found = String[]
        rest = r
        while !isempty(rest)
            rest = strip(rest)
            matched = false
            # Try multi-word deep refs first (longest match)
            for kw in sort(collect(_DEEP_KEYWORDS); by=length, rev=true)
                if startswith(rest, kw)
                    push!(found, kw)
                    rest = strip(rest[length(kw)+1:end])
                    matched = true
                    break
                end
            end
            matched && continue
            # Try recent keywords
            for kw in sort(collect(_RECENT_KEYWORDS); by=length, rev=true)
                if startswith(rest, kw)
                    push!(found, kw)
                    rest = strip(rest[length(kw)+1:end])
                    matched = true
                    break
                end
            end
            matched && continue
            # Try clock keywords
            for kw in sort(collect(_CLOCK_KEYWORDS); by=length, rev=true)
                if startswith(rest, kw)
                    push!(found, kw)
                    rest = strip(rest[length(kw)+1:end])
                    matched = true
                    break
                end
            end
            matched && continue
            # No known keyword at start - take one word and try again
            tokens = split(rest; limit=2)
            if length(tokens) >= 2
                candidate = String(tokens[1])
                rest = strip(String(tokens[2]))
                push!(found, candidate)
            else
                push!(found, strip(rest))
                rest = ""
            end
        end
        parts = found
    end

    # Filter: only keep parts that classify as a known category
    # (not :literal, since literal refs don't conflict)
    classified_parts = filter(p -> _classify_ref(p) !== :literal, parts)

    # If no classified parts found, return the original ref as a single element
    # so the caller can fall back to single-ref resolution.
    return isempty(classified_parts) ? [ref] : classified_parts
end

"""
    set_resolve_conflict_mode!(mode::Symbol)

Set the global conflict resolution mode for compound refs.
Valid modes: :merge (concat all), :priority (highest-priority layer wins),
:first_wins (first non-fallback result wins).
"""
function set_resolve_conflict_mode!(mode::Symbol)
    if mode ∉ CONFLICT_MODES
        throw(ArgumentError("Invalid conflict mode :$mode. Valid: $(collect(CONFLICT_MODES))"))
    end
    _CONFLICT_MODE[] = mode
end

"""
    get_resolve_conflict_mode() -> Symbol

Return the current global conflict resolution mode.
"""
function get_resolve_conflict_mode()::Symbol
    return _CONFLICT_MODE[]
end

"""
    resolve_multi_reference(ref; mode=nothing) -> String

Resolve a compound reference that may contain multiple ref keywords
from different memory layers. When multiple keywords are detected,
applies the configured conflict resolution mode:

- :merge - concatenate all results with "; " separator (default)
- :priority - return only the result from the highest-priority layer
  (priority order: clock > recent > deep > literal)
- :first_wins - return the first non-fallback result

If no compound joiners are detected, falls through to resolve_reference.
Records SelfObserver audit when multiple refs conflict.
"""
function resolve_multi_reference(ref::AbstractString;
                                 mode::Union{Symbol,Nothing} = nothing)::String
    effective_mode = mode !== nothing ? mode : _CONFLICT_MODE[]
    if effective_mode ∉ CONFLICT_MODES
        throw(ArgumentError("Invalid conflict mode :$effective_mode. Valid: $(collect(CONFLICT_MODES))"))
    end

    # Split the compound ref into individual ref keywords
    parts = _split_compound_refs(ref)

    # If only one part (or could not split), delegate to single-ref resolution
    if length(parts) <= 1
        return resolve_reference(ref)
    end

    # Resolve each part individually
    results = Tuple{String, Symbol, String}[]  # (ref, category, resolved_value)
    for p in parts
        cat = _classify_ref(p)
        val = resolve_reference(p)
        push!(results, (p, cat, val))
    end

    # Filter out fallback results for conflict detection
    non_fallback = filter(r -> r[3] ∉ _RESOLVE_FALLBACKS, results)

    # If 0 or 1 non-fallback results, no real conflict
    if length(non_fallback) <= 1
        if isempty(non_fallback)
            # All fell back - return the first fallback
            return results[1][3]
        end
        return non_fallback[1][3]
    end

    # Multiple non-fallback results - conflict resolution
    # Record audit in SelfObserver if available
    _audit_ref_conflict(ref, results, effective_mode)

    if effective_mode === :merge
        # Concatenate all non-fallback results
        return join([r[3] for r in non_fallback], "; ")
    elseif effective_mode === :priority
        # Find the highest-priority category among non-fallback results
        best_priority = Inf
        best_result = non_fallback[1][3]
        for r in non_fallback
            pri = findfirst(isequal(r[2]), _REF_PRIORITY)
            if pri !== nothing && pri < best_priority
                best_priority = pri
                best_result = r[3]
            end
        end
        return best_result
    elseif effective_mode === :first_wins
        # Return the first non-fallback result
        return non_fallback[1][3]
    end

    # Should not reach here
    return results[1][3]
end

"""
    _audit_ref_conflict(ref, results, mode)

Record a SelfObserver audit entry when multiple refs conflict.
This is a no-op if SelfObserver is not loaded.
"""
function _audit_ref_conflict(ref::String,
                             results::Vector{Tuple{String, Symbol, String}},
                             mode::Symbol)
    try
        # GRUG: Try to use SelfObserver if it is available in the parent module.
        # This is optional - if SelfObserver is not loaded, we silently skip.
        so = getfield(parentmodule(@__MODULE__), :SelfObserver)
        store = so.default_store()
        categories = join([r[2] for r in results], ",")
        resolved_values = join([r[3] for r in results if r[3] ∉ _RESOLVE_FALLBACKS], ";")
        so.observe!(store,
                    "resolve_conflict://$(lowercase(ref))",
                    :resolve_conflict,
                    (compound_ref = ref,
                     categories = categories,
                     mode = string(mode),
                     resolved = resolved_values))
    catch
        # SelfObserver not loaded or not available - silent no-op
    end
end

# ── DEFAULT ACTIONS ────────────────────────────────────────
# Built-in action entries shipped with every cave. Users can
# add more via register_action! and they persist in specimen saves.

function default_actions!()
    registry = _GLOBAL_REGISTRY[]

    # SAY/REPEAT — the core "say X N times" pattern
    register_action!(
        trigger_verb = "say",
        action_type = :dynamic,
        template = "REPEAT(RESOLVE({{target}}), {{count}})",
        description = "Say something N times. 'say pork 200 times' → repeats 'pork' 200x"
    )

    register_action!(
        trigger_verb = "repeat",
        action_type = :dynamic,
        template = "REPEAT(RESOLVE({{target}}), {{count}})",
        description = "Repeat something N times. Synonym for SAY."
    )

    register_action!(
        trigger_verb = "count",
        action_type = :dynamic,
        template = "REPEAT({{target}}, {{count}})",
        description = "Count something N times."
    )

    # RESOLVE — direct reference lookup (replaces time nodes)
    register_action!(
        trigger_verb = "check",
        action_type = :dynamic,
        template = "SAY(RESOLVE({{target}}))",
        description = "Check a reference. 'check the date' → resolves to current date."
    )

    register_action!(
        trigger_verb = "tell",
        action_type = :dynamic,
        template = "SAY(RESOLVE({{target}}))",
        description = "Tell me about a reference. 'tell the time' → current time."
    )

    # ── v7.35: CONDITIONAL DEFAULTS ───────────────────────
    # These showcase the new conditional ops in default actions.

    # "remind" — branch on whether the target reference is available
    register_action!(
        trigger_verb = "remind",
        action_type = :dynamic,
        template = "IF(HAS({{target}}), SAY(RESOLVE({{target}})), SAY(I don't recall that))",
        description = "Remind me about something. Branches on whether the reference is available."
    )

    # "announce" — only announce if there's recent context, otherwise say nothing's new
    register_action!(
        trigger_verb = "announce",
        action_type = :dynamic,
        template = "IF(PRESENT(RESOLVE(recent)), SAY(RESOLVE(recent)), SAY(Nothing new to announce))",
        description = "Announce what's new. Checks recent context first."
    )

    # "recall" — deep memory lookup with fallback
    register_action!(
        trigger_verb = "recall",
        action_type = :dynamic,
        template = "WHEN(PRESENT(RESOLVE(ages ago)), SAY(RESOLVE(ages ago)))",
        description = "Recall something from deep memory. Returns empty if no trace found."
    )

    # "confirm" — confirm a reference value exists (pure conditional)
    register_action!(
        trigger_verb = "confirm",
        action_type = :dynamic,
        template = "IF(PRESENT({{target}}), SAY(Confirmed: {{target}}), SAY(Not confirmed))",
        description = "Confirm whether a slot value is present. Tests PRESENT on a slot."
    )

    return registry
end

# ── SERIALIZATION HELPERS ──────────────────────────────────
# For specimen save/load. Action entries serialize to/from Dict.

function action_to_dict(entry::ActionEntry)::Dict{String, Any}
    return Dict{String, Any}(
        "trigger_verb" => entry.trigger_verb,
        "action_type"  => string(entry.action_type),
        "template"     => entry.template,
        "description"  => entry.description
    )
end

function dict_to_action(d::Dict{String, Any})::ActionEntry
    return ActionEntry(
        d["trigger_verb"],
        Symbol(d["action_type"]),
        d["template"],
        get(d, "description", "")
    )
end

function serialize_registry()::Vector{Dict{String, Any}}
    # De-duplicate: only serialize unique entries (not synonym aliases)
    seen = Set{String}()
    out = Dict{String, Any}[]
    for (verb, entry) in _GLOBAL_REGISTRY[].entries
        if entry.trigger_verb ∉ seen
            push!(seen, entry.trigger_verb)
            push!(out, action_to_dict(entry))
        end
    end
    return out
end

function restore_registry!(entries::Vector{Dict{String, Any}})
    reset_action_registry!()
    for d in entries
        entry = dict_to_action(d)
        _GLOBAL_REGISTRY[].entries[entry.trigger_verb] = entry
        # Re-register synonyms
        syns = SemanticVerbs.synonyms_of(entry.trigger_verb)
        for s in syns
            _GLOBAL_REGISTRY[].entries[lowercase(s)] = entry
        end
    end
end

end # module ActionScript
