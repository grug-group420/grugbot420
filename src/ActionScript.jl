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
# Built-in operations:
#   REPEAT(n)      — loop output n times
#   SAY(text)      — emit text verbatim
#   RESOLVE(ref)   — look up a reference (date, now, recent, etc.)
#   COMPUTE(expr)  — delegate to math sigil (future)
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
       ACTION_OPS, is_action_trigger, get_action_triggers

# ── BUILT-IN OPERATION TYPES ────────────────────────────────

const ACTION_OPS = Set{String}([
    "REPEAT", "SAY", "RESOLVE", "COMPUTE"
])

# ── ACTION ENTRY ────────────────────────────────────────────
# One row in the user's "side list". Defines a trigger verb,
# whether the action is static (fixed output) or dynamic (template
# with capture slots), and the execution template.

struct ActionEntry
    trigger_verb::String           # Primary verb: "say", "repeat", etc.
    action_type::Symbol            # :static or :dynamic
    template::String               # Execution template: "REPEAT({{target}}, {{count}})"
                                   # For static: just "SAY(some fixed text)"
    description::String            # Human-readable description for /help
end

# ── ACTION REGISTRY (THE SIDE LIST) ────────────────────────

mutable struct ActionRegistry
    entries::Dict{String, ActionEntry}   # keyed by trigger_verb (lowercase)
    label::String
end

ActionRegistry() = ActionRegistry(Dict{String, ActionEntry}(), "unlabeled")
ActionRegistry(label::AbstractString) = ActionRegistry(Dict{String, ActionEntry}(), String(label))

# ── GLOBAL SINGLETON ────────────────────────────────────────
# One ActionRegistry per cave, same pattern as SigilTable singleton.

const _GLOBAL_REGISTRY = Ref{ActionRegistry}(ActionRegistry("engine-default"))

action_registry()::ActionRegistry = _GLOBAL_REGISTRY[]
reset_action_registry!() = (_GLOBAL_REGISTRY[] = ActionRegistry("engine-default"); nothing)

# ── REGISTRATION ────────────────────────────────────────────

"""
    register_action!(; trigger_verb, action_type, template, description="")

Add an action entry to the global registry. The trigger_verb must
already be a registered verb in SemanticVerbs (or be added first).
Throws on empty trigger or unknown op in template.
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
    _validate_template(template)

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

# ── TEMPLATE VALIDATION ─────────────────────────────────────

function _validate_template(template::AbstractString)
    # Scan for operation calls — word followed by (
    for m in eachmatch(r"([A-Z]+)\s*\(", template)
        op = m.captures[1]
        if op ∉ ACTION_OPS
            error("register_action!: unknown operation '$op' in template (allowed: $(collect(ACTION_OPS)))")
        end
    end
end

# ── TEMPLATE RENDERING ──────────────────────────────────────
# Fill {{slot}} placeholders from a dict of bindings.

function render_template(template::AbstractString, slots::Dict{String, Any})::String
    result = template
    for (key, val) in slots
        result = replace(result, "{{$(key)}}" => string(val))
    end
    return result
end

# ── EXECUTION ───────────────────────────────────────────────

"""
    execute_action(entry, slots) -> String

Execute an ActionEntry's template with the given slot values.
Parses the operation chain and runs each one, concatenating results.

For static actions: just evaluates SAY(content).
For dynamic actions: fills slots first, then evaluates.
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
        inner = _eval_op_chain(args_str)
        return resolve_reference(inner)

    elseif op == "REPEAT"
        # REPEAT(content, count) — repeat content n times
        # Split on the LAST comma to separate content from count
        # (content itself might contain commas from inner ops)
        last_comma = findlast(',', args_str)
        if isnothing(last_comma)
            return _eval_op_chain(args_str)  # no count? just eval content
        end
        content_str = strip(args_str[1:last_comma-1])
        count_str = strip(args_str[last_comma+1:end])

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

    else
        # Unknown op — return literal
        return chain
    end
end

# ── RESOLVE SYSTEM ──────────────────────────────────────────
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

    # ── SYSTEM CLOCK ────────────────────────────────────
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

    # ── REGULAR 10K BUFFER (THE NOW) ───────────────────
    recent_refs = Set(["recent", "last", "what now", "what's new",
                       "latest", "happening"])
    if r in recent_refs || startswith(r, "recent") || startswith(r, "last ")
        try
            return _RECENT_CALLBACK[](r)
        catch
            return "(recent context unavailable)"
        end
    end

    # ── SUBCONSCIOUS SIGNAL LAYER (AGES AGO) ───────────
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

    # ── FALLBACK: return the ref as literal ─────────────
    return ref
end

# ── DEFAULT ACTIONS ─────────────────────────────────────────
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

    return registry
end

# ── SERIALIZATION HELPERS ───────────────────────────────────
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
