# ==============================================================================
# ActionEngine.jl — GRUG Dynamic Sigil Action Evaluator (Stage 2b)
# ==============================================================================
# GRUG say: arithmetic is just ONE kind of computation. Action sigils can do
#           ANYTHING. Factorial, square root, double, negate, cube — any
#           procedure that takes sigil bindings and produces an answer.
#           This module is the bridge between dynamic sigil nodes and
#           computed results. It reads the node's action_callback from
#           json_data, fetches the registered callback function, runs it
#           with the current promotion bindings, and returns a structured
#           ActionResult that the AIML payload builder injects as the claim.
#
# GRUG say: this is the RIGHT way to teach math. Not "factorial of 6 is 720"
#           as a dead knowledge node — but "factorial is a procedure" as a
#           dynamic sigil node that computes ANY factorial on the fly.
#           One node, infinite answers. The cave compresses.
#
# ARCHITECTURE:
#   - ACTION_CALLBACKS: Dict{String, Function} — registry of named compute functions
#   - Each callback: (bindings::Vector{SigilBinding}) -> ActionResult
#   - Built-in callbacks: factorial, square, square_root, double, half,
#     negate, cube, absolute, reciprocal, fibonacci
#   - Users register custom callbacks via /answer :action or /addAction
#   - When a sigil node with action_callback fires, ActionEngine runs
#     the callback and the computed answer becomes the claim at priority 0
#     (above even arithmetic_reply — action sigils are more specific)
#
# PRIORITY CHAIN (updated):
#   0. action_compute_reply  — dynamic sigil action computed a result (NEW)
#   0. arithmetic_reply      — basic arithmetic computed a result (existing)
#   1. action_is_prose       — prose action string
#   2. voice_body            — system_prompt body sentences
#   3. noun_anchors          — topic nouns
#   4. node_pattern          — raw pattern (last resort)
# ==============================================================================

module ActionEngine

using ..SigilPromoter

export ActionResult, ActionComputationStep, compute_action, format_action_reply,
       has_action_callback, register_action_callback!, list_action_callbacks,
       ACTION_CALLBACKS,
       parse_arith_expr, register_learned_arith_callback!

# ==============================================================================
# DATA STRUCTURES
# ==============================================================================

"""
A single step in a dynamic action computation (e.g., "5 × 4 = 20" for factorial).
"""
struct ActionComputationStep
    description::String   # e.g., "5 × 4 = 20"
end

"""
Result from a dynamic action computation.

Fields:
  - `action_name`    — the callback name (e.g., "factorial")
  - `answer`         — the computed value (Number or String)
  - `answer_str`     — human-readable answer string
  - `expression`     — reconstructed expression (e.g., "factorial(5)")
  - `steps`          — computation steps for display
  - `error`          — nothing on success, error message on failure
"""
struct ActionResult
    action_name::String
    answer::Any
    answer_str::String
    expression::String
    steps::Vector{ActionComputationStep}
    error::Union{Nothing,String}
end

# ==============================================================================
# ACTION CALLBACK REGISTRY
# ==============================================================================

"""
Global registry of named action callbacks. Each entry maps an action name
to a function that takes Vector{SigilBinding} and returns ActionResult.
Users can add custom callbacks via register_action_callback! or /addAction.
"""
const ACTION_CALLBACKS::Dict{String, Function} = Dict{String, Function}()

"""
    register_action_callback!(name::String, fn::Function)

Register a named action callback function. Overwrites any existing callback
with the same name. The function must accept Vector{SigilBinding} and return
ActionResult.
"""
function register_action_callback!(name::String, fn::Function)
    ACTION_CALLBACKS[lowercase(strip(name))] = fn
    return nothing
end

"""
    list_action_callbacks() -> Vector{String}

List all registered action callback names, sorted alphabetically.
"""
function list_action_callbacks()::Vector{String}
    return sort(collect(keys(ACTION_CALLBACKS)))
end

"""
    has_action_callback(name::String) -> Bool

Check whether a callback with the given name is registered.
"""
has_action_callback(name::String)::Bool = haskey(ACTION_CALLBACKS, lowercase(strip(name)))

# ==============================================================================
# BUILT-IN ACTION CALLBACKS
# ==============================================================================

# --- Helper: extract first &n binding value as number ---
function _first_number_binding(bindings::Vector{SigilBinding})::Union{Nothing,Number}
    for b in bindings
        if b.name == "n"
            val = b.value
            if val isa Number
                return val
            elseif val isa AbstractString
                try
                    s = String(val)
                    if occursin(r"^[+-]?\d+$", s)
                        return parse(Int, s)
                    elseif occursin(r"^[+-]?\d+\.\d+$", s)
                        return parse(Float64, s)
                    end
                catch
                    return nothing
                end
            end
        end
    end
    return nothing
end

# --- Helper: extract surface form of first &n binding ---
function _first_number_surface(bindings::Vector{SigilBinding})::String
    for b in bindings
        if b.name == "n"
            return isempty(b.surface) ? String(b.value) : b.surface
        end
    end
    return "?"
end

# --- Factorial ---
register_action_callback!("factorial", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("factorial", nothing, "", "factorial($n_surface)",
            ActionComputationStep[], "need a number binding, got nothing")
    end

    n_int = try Int(n) catch _ nothing end
    if n_int === nothing || n_int != n
        return ActionResult("factorial", nothing, "", "factorial($n_surface)",
            ActionComputationStep[], "factorial requires an integer, got $n")
    end

    if n_int < 0
        return ActionResult("factorial", nothing, "", "factorial($n_surface)",
            ActionComputationStep[], "factorial of negative number not defined")
    end

    if n_int > 20
        return ActionResult("factorial", nothing, "", "factorial($n_surface)",
            ActionComputationStep[], "factorial of $n_int too large (max 20)")
    end

    # Compute factorial with step-by-step display
    steps = ActionComputationStep[]
    result = 1
    if n_int <= 1
        # factorial(0) = 1, factorial(1) = 1
    else
        for i in 2:n_int
            prev = result
            result = result * i
            push!(steps, ActionComputationStep("$prev × $i = $result"))
        end
    end

    answer_str = string(result)
    # GRUG: Natural language reply — "factorial of 5 is 120" or "5 factorial is 120"
    reply = "factorial of $(n_surface) is $answer_str"

    return ActionResult("factorial", result, reply, "factorial($n_surface)",
        steps, nothing)
end)

# --- Square ---
register_action_callback!("square", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("square", nothing, "", "square($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    result = n * n
    answer_str = string(result)
    # GRUG: If result is Float64 but integer-valued, show as integer
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "$(n_surface) squared is $answer_str"
    steps = [ActionComputationStep("$(n_surface) × $(n_surface) = $answer_str")]

    return ActionResult("square", result, reply, "square($n_surface)",
        steps, nothing)
end)

# --- Square root ---
register_action_callback!("square_root", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("square_root", nothing, "", "√($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    if n < 0
        return ActionResult("square_root", nothing, "", "√($n_surface)",
            ActionComputationStep[], "square root of negative number not defined")
    end

    result = sqrt(Float64(n))
    # GRUG: Show clean integer if perfect square
    if result == floor(result) && result < typemax(Int)
        answer_str = string(Int(result))
        reply = "square root of $(n_surface) is $answer_str"
    else
        answer_str = string(round(result, digits=4))
        reply = "square root of $(n_surface) is approximately $answer_str"
    end

    steps = [ActionComputationStep("√$(n_surface) = $answer_str")]

    return ActionResult("square_root", result, reply, "√($n_surface)",
        steps, nothing)
end)

# --- Double ---
register_action_callback!("double", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("double", nothing, "", "double($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    result = n * 2
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "double of $(n_surface) is $answer_str"
    steps = [ActionComputationStep("$(n_surface) × 2 = $answer_str")]

    return ActionResult("double", result, reply, "double($n_surface)",
        steps, nothing)
end)

# --- Half ---
register_action_callback!("half", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("half", nothing, "", "half($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    result = n / 2
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    else
        answer_str = string(round(Float64(result), digits=4))
    end

    reply = "half of $(n_surface) is $answer_str"
    steps = [ActionComputationStep("$(n_surface) ÷ 2 = $answer_str")]

    return ActionResult("half", result, reply, "half($n_surface)",
        steps, nothing)
end)

# --- Negate ---
register_action_callback!("negate", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("negate", nothing, "", "negate($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    result = -n
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "negative of $(n_surface) is $answer_str"
    steps = [ActionComputationStep("-$(n_surface) = $answer_str")]

    return ActionResult("negate", result, reply, "negate($n_surface)",
        steps, nothing)
end)

# --- Cube ---
register_action_callback!("cube", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("cube", nothing, "", "cube($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    result = n * n * n
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "$(n_surface) cubed is $answer_str"
    steps = [ActionComputationStep("$(n_surface) × $(n_surface) × $(n_surface) = $answer_str")]

    return ActionResult("cube", result, reply, "cube($n_surface)",
        steps, nothing)
end)

# --- Absolute value ---
register_action_callback!("absolute", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("absolute", nothing, "", "|$n_surface|",
            ActionComputationStep[], "need a number binding")
    end

    result = abs(n)
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "absolute value of $(n_surface) is $answer_str"
    steps = [ActionComputationStep("|$(n_surface)| = $answer_str")]

    return ActionResult("absolute", result, reply, "|$n_surface|",
        steps, nothing)
end)

# --- Reciprocal ---
register_action_callback!("reciprocal", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("reciprocal", nothing, "", "1/$n_surface",
            ActionComputationStep[], "need a number binding")
    end

    if n == 0
        return ActionResult("reciprocal", nothing, "", "1/0",
            ActionComputationStep[], "reciprocal of zero is undefined")
    end

    result = 1.0 / n
    answer_str = string(round(result, digits=6))
    # GRUG: Clean up trailing zeros
    if occursin(r"^\d+\.\d+0+$", answer_str)
        answer_str = string(round(result, digits=4))
    end

    reply = "reciprocal of $(n_surface) is $answer_str"
    steps = [ActionComputationStep("1 ÷ $(n_surface) = $answer_str")]

    return ActionResult("reciprocal", result, reply, "1/$n_surface",
        steps, nothing)
end)

# --- Fibonacci ---
register_action_callback!("fibonacci", function(bindings::Vector{SigilBinding})
    n = _first_number_binding(bindings)
    n_surface = _first_number_surface(bindings)

    if n === nothing
        return ActionResult("fibonacci", nothing, "", "fibonacci($n_surface)",
            ActionComputationStep[], "need a number binding")
    end

    n_int = try Int(n) catch _ nothing end
    if n_int === nothing || n_int != n
        return ActionResult("fibonacci", nothing, "", "fibonacci($n_surface)",
            ActionComputationStep[], "fibonacci requires an integer")
    end

    if n_int < 0
        return ActionResult("fibonacci", nothing, "", "fibonacci($n_surface)",
            ActionComputationStep[], "fibonacci of negative not defined")
    end

    if n_int > 70
        return ActionResult("fibonacci", nothing, "", "fibonacci($n_surface)",
            ActionComputationStep[], "fibonacci of $n_int too large (max 70)")
    end

    # Compute fibonacci
    steps = ActionComputationStep[]
    if n_int == 0
        result = 0
    elseif n_int == 1
        result = 1
    else
        a, b = 0, 1
        for i in 2:n_int
            a, b = b, a + b
            push!(steps, ActionComputationStep("fib($i) = $b"))
        end
        result = b
    end

    answer_str = string(result)
    reply = "fibonacci of $(n_surface) is $answer_str"

    return ActionResult("fibonacci", result, reply, "fibonacci($n_surface)",
        steps, nothing)
end)

# ==============================================================================
# MAIN EVALUATION
# ==============================================================================

"""
    compute_action(action_name::String, bindings::Vector{SigilBinding}) -> ActionResult

Look up a registered action callback by name and execute it with the given
sigil bindings. Returns ActionResult with the computed value or an error.
"""
function compute_action(action_name::String, bindings::Vector{SigilBinding})::ActionResult
    name_key = lowercase(strip(action_name))
    if !haskey(ACTION_CALLBACKS, name_key)
        return ActionResult(name_key, nothing, "", "",
            ActionComputationStep[], "unknown action callback '$name_key'")
    end

    try
        return ACTION_CALLBACKS[name_key](bindings)
    catch e
        return ActionResult(name_key, nothing, "", "",
            ActionComputationStep[], "action '$name_key' threw: $e")
    end
end

"""
    format_action_reply(result::ActionResult) -> String

Format an ActionResult into a natural-language reply string suitable for
the claim_raw pipeline. This is the answer the user sees.
"""
function format_action_reply(result::ActionResult)::String
    if result.error !== nothing
        return "Could not compute $(result.action_name): $(result.error)."
    end

    # GRUG: The answer_str is already natural language from the callback.
    # Just return it directly. Steps are available for telemetry/debug but
    # the claim is the concise answer.
    return result.answer_str
end

"""
    format_action_reply_with_steps(result::ActionResult) -> String

Format an ActionResult with step-by-step breakdown. Used for verbose mode
or when the user explicitly asks for the work.
"""
function format_action_reply_with_steps(result::ActionResult)::String
    if result.error !== nothing
        return "Could not compute $(result.action_name): $(result.error)."
    end

    if isempty(result.steps)
        return result.answer_str
    end

    step_strs = [s.description for s in result.steps]
    steps_prose = join(step_strs, ", then ")
    return "$(result.answer_str). $(steps_prose)"
end

# --- Helper: extract second &n binding ---
function _second_number_binding(bindings::Vector{SigilBinding})::Union{Nothing,Number}
    count_n = 0
    for b in bindings
        if b.name == "n"
            count_n += 1
            if count_n == 2
                val = b.value
                if val isa Number
                    return val
                elseif val isa AbstractString
                    try
                        s = String(val)
                        if occursin(r"^[+-]?\d+$", s)
                            return parse(Int, s)
                        elseif occursin(r"^[+-]?\d+\.\d+$", s)
                            return parse(Float64, s)
                        end
                    catch
                        return nothing
                    end
                end
            end
        end
    end
    return nothing
end

# --- Helper: extract surface form of second &n binding ---
function _second_number_surface(bindings::Vector{SigilBinding})::String
    count_n = 0
    for b in bindings
        if b.name == "n"
            count_n += 1
            if count_n == 2
                return isempty(b.surface) ? String(b.value) : b.surface
            end
        end
    end
    return "?"
end

# ==============================================================================
# GRUG: BINARY OPERATION CALLBACKS — add_two, subtract_two, divide_two
# These handle phrasings like "add 12 and 7", "subtract 3 from 10",
# "divide 20 by 5" where the operator is a literal word (not an &op sigil)
# and the ArithmeticEngine path can't fire (no &op binding).
# ==============================================================================

# --- Add two numbers ---
register_action_callback!("add_two", function(bindings::Vector{SigilBinding})
    a = _first_number_binding(bindings)
    b = _second_number_binding(bindings)
    a_surface = _first_number_surface(bindings)
    b_surface = _second_number_surface(bindings)

    if a === nothing || b === nothing
        return ActionResult("add_two", nothing, "", "add($a_surface, $b_surface)",
            ActionComputationStep[], "need two number bindings")
    end

    result = a + b
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "$(a_surface) plus $(b_surface) equals $answer_str"
    steps = [ActionComputationStep("$(a_surface) + $(b_surface) = $answer_str")]

    return ActionResult("add_two", result, reply, "add($a_surface, $b_surface)",
        steps, nothing)
end)

# --- Subtract two numbers (second from first) ---
register_action_callback!("subtract_two", function(bindings::Vector{SigilBinding})
    a = _first_number_binding(bindings)
    b = _second_number_binding(bindings)
    a_surface = _first_number_surface(bindings)
    b_surface = _second_number_surface(bindings)

    if a === nothing || b === nothing
        return ActionResult("subtract_two", nothing, "", "subtract($a_surface, $b_surface)",
            ActionComputationStep[], "need two number bindings")
    end

    result = a - b
    answer_str = string(result)
    if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    end

    reply = "$(a_surface) minus $(b_surface) equals $answer_str"
    steps = [ActionComputationStep("$(a_surface) - $(b_surface) = $answer_str")]

    return ActionResult("subtract_two", result, reply, "subtract($a_surface, $b_surface)",
        steps, nothing)
end)

# --- Divide two numbers (first by second) ---
register_action_callback!("divide_two", function(bindings::Vector{SigilBinding})
    a = _first_number_binding(bindings)
    b = _second_number_binding(bindings)
    a_surface = _first_number_surface(bindings)
    b_surface = _second_number_surface(bindings)

    if a === nothing || b === nothing
        return ActionResult("divide_two", nothing, "", "divide($a_surface, $b_surface)",
            ActionComputationStep[], "need two number bindings")
    end

    if b == 0
        return ActionResult("divide_two", nothing, "", "divide($a_surface, 0)",
            ActionComputationStep[], "division by zero is undefined")
    end

    result = a / b
    answer_str = string(round(result, digits=6))
    # GRUG: Clean up trailing zeros for clean display
    if result == floor(result) && abs(result) < typemax(Int)
        answer_str = string(Int(result))
    elseif occursin(r"\.\d+0+$", answer_str)
        answer_str = string(round(result, digits=4))
    end

    reply = "$(a_surface) divided by $(b_surface) equals $answer_str"
    steps = [ActionComputationStep("$(a_surface) ÷ $(b_surface) = $answer_str")]

    return ActionResult("divide_two", result, reply, "divide($a_surface, $b_surface)",
        steps, nothing)
end)

# ==============================================================================
# GRUG v9.3: CONVERSATIONAL PROCEDURE LEARNING — parse_arith_expr /
# register_learned_arith_callback!
#
# GRUG say: teaching Grug "factorial" required a human to write Julia code.
#           That's fine for the built-ins, but the user's whole point is
#           Grug should learn NEW math procedures conversationally, on the
#           fly, without a human writing a new register_action_callback!
#           block every time. So: when a taught procedural definition is a
#           simple chain of arithmetic operations on one variable ("n" /
#           "it" / "the number"), we PARSE that chain into a sequence of
#           (op, operand) steps and COMPILE a real, working callback out of
#           it — closing over the parsed ops, not just storing prose.
#
# Supported operation phrasings (case-insensitive, order-independent
# within a step, steps chained by "and"/"then"/","/";"):
#   "multiply (n/it) by K" / "times K" / "multiplied by K"   -> (:mul, K)
#   "divide (n/it) by K"   / "divided by K"                  -> (:div, K)
#   "add K (to it)"        / "plus K"                        -> (:add, K)
#   "subtract K (from it)" / "minus K"                       -> (:sub, K)
#   "square (it)"          / "squared"                       -> (:square, NaN)
#   "double (it)"          / "doubled"                       -> (:mul, 2.0)
#   "half (of it)" / "halve (it)" / "halved"                 -> (:div, 2.0)
#   "negate (it)"          / "negated"                       -> (:negate, NaN)
#   "cube (it)"            / "cubed"                         -> (:cube, NaN)
#
# This is intentionally narrow — a small, safe, composable arithmetic DSL,
# not a general expression parser. Anything it can't confidently parse
# returns `nothing`, and the caller (Main.jl's :teach handler) falls back
# to the old purely-descriptive sigil node. Better to learn NOTHING than
# to learn something WRONG.
# ==============================================================================

"""
    ArithOpStep

A single parsed arithmetic operation step: `op` is one of
`:mul, :div, :add, :sub, :square, :cube, :negate`, and `operand` is the
numeric operand (unused / NaN for the unary ops square/cube/negate).
"""
struct ArithOpStep
    op::Symbol
    operand::Float64
end

const _ARITH_STEP_SPLIT_RE = r"\s*(?:,|;|\band\b|\bthen\b)\s*"

"""
    parse_arith_expr(text::String) -> Union{Nothing, Vector{ArithOpStep}}

GRUG v9.3: Attempt to parse a natural-language arithmetic procedure
description into a sequence of `ArithOpStep`s. Returns `nothing` if the
text doesn't confidently match the supported mini-DSL (see module docs
above) — callers must treat `nothing` as "can't learn this as a working
procedure yet", not as an error.

Examples that parse successfully:
  "multiply n by 2 and add 1"        -> [(:mul, 2.0), (:add, 1.0)]
  "double it then subtract 3"        -> [(:mul, 2.0), (:sub, 3.0)]
  "square it and negate it"          -> [(:square, NaN), (:negate, NaN)]
  "divide by 4"                      -> [(:div, 4.0)]
"""
function parse_arith_expr(text::AbstractString)::Union{Nothing, Vector{ArithOpStep}}
    _t = lowercase(strip(text))
    isempty(_t) && return nothing

    # Strip common leading filler so "to compute X, multiply n by 2" still parses.
    _t = replace(_t, r"^(?:to (?:compute|calculate|find|get) it,?\s*)" => "")

    _clauses = [strip(c) for c in split(_t, _ARITH_STEP_SPLIT_RE)]
    _clauses = filter(!isempty, _clauses)
    isempty(_clauses) && return nothing

    steps = ArithOpStep[]
    for _c in _clauses
        _step = _parse_single_arith_clause(_c)
        _step === nothing && return nothing   # any unparseable clause aborts the whole parse
        push!(steps, _step)
    end
    isempty(steps) && return nothing
    return steps
end

# --- Parse ONE clause like "multiply n by 2" / "squared" / "add 1 to it" ---
function _parse_single_arith_clause(clause::AbstractString)::Union{Nothing, ArithOpStep}
    _c = strip(clause)

    # Unary ops first — these have no numeric operand.
    if occursin(r"^square(?:d)?(?:\s+it)?$", _c) || occursin(r"^square\s+(?:n|it|the number)$", _c)
        return ArithOpStep(:square, NaN)
    end
    if occursin(r"^cube(?:d)?(?:\s+it)?$", _c) || occursin(r"^cube\s+(?:n|it|the number)$", _c)
        return ArithOpStep(:cube, NaN)
    end
    if occursin(r"^negate(?:d)?(?:\s+it)?$", _c) || occursin(r"^negate\s+(?:n|it|the number)$", _c)
        return ArithOpStep(:negate, NaN)
    end
    if occursin(r"^double(?:d)?(?:\s+it)?$", _c) || occursin(r"^double\s+(?:n|it|the number)$", _c)
        return ArithOpStep(:mul, 2.0)
    end
    if occursin(r"^hal(?:f|ve|ved)(?:\s+(?:of\s+)?it)?$", _c) || occursin(r"^hal(?:f|ve)\s+(?:n|it|the number)$", _c)
        return ArithOpStep(:div, 2.0)
    end

    # Binary ops — extract the numeric operand.
    _num_re = r"([+-]?\d+(?:\.\d+)?)"

    m = match(Regex("^multipl(?:y|ied)(?:\\s+(?:n|it|the number))?\\s+by\\s+" * _num_re.pattern * "\$"), _c)
    m === nothing && (m = match(Regex("^times\\s+" * _num_re.pattern * "\$"), _c))
    if m !== nothing
        return ArithOpStep(:mul, parse(Float64, m.captures[1]))
    end

    m = match(Regex("^divid(?:e|ed)(?:\\s+(?:n|it|the number))?\\s+by\\s+" * _num_re.pattern * "\$"), _c)
    if m !== nothing
        return ArithOpStep(:div, parse(Float64, m.captures[1]))
    end

    m = match(Regex("^add\\s+" * _num_re.pattern * "(?:\\s+to\\s+(?:it|n|the number))?\$"), _c)
    m === nothing && (m = match(Regex("^plus\\s+" * _num_re.pattern * "\$"), _c))
    if m !== nothing
        return ArithOpStep(:add, parse(Float64, m.captures[1]))
    end

    m = match(Regex("^subtract\\s+" * _num_re.pattern * "(?:\\s+from\\s+(?:it|n|the number))?\$"), _c)
    m === nothing && (m = match(Regex("^minus\\s+" * _num_re.pattern * "\$"), _c))
    if m !== nothing
        return ArithOpStep(:sub, parse(Float64, m.captures[1]))
    end

    return nothing
end

# --- Apply a parsed op sequence to a starting number, producing steps for display ---
function _apply_arith_ops(ops::Vector{ArithOpStep}, n0::Number)::Tuple{Number, Vector{ActionComputationStep}}
    result = n0
    steps = ActionComputationStep[]
    for s in ops
        prev = result
        if s.op == :mul
            result = prev * s.operand
            push!(steps, ActionComputationStep("$prev × $(s.operand) = $result"))
        elseif s.op == :div
            if s.operand == 0
                error("division by zero")
            end
            result = prev / s.operand
            push!(steps, ActionComputationStep("$prev ÷ $(s.operand) = $result"))
        elseif s.op == :add
            result = prev + s.operand
            push!(steps, ActionComputationStep("$prev + $(s.operand) = $result"))
        elseif s.op == :sub
            result = prev - s.operand
            push!(steps, ActionComputationStep("$prev - $(s.operand) = $result"))
        elseif s.op == :square
            result = prev * prev
            push!(steps, ActionComputationStep("$prev × $prev = $result"))
        elseif s.op == :cube
            result = prev * prev * prev
            push!(steps, ActionComputationStep("$prev × $prev × $prev = $result"))
        elseif s.op == :negate
            result = -prev
            push!(steps, ActionComputationStep("-($prev) = $result"))
        else
            error("unknown arith op $(s.op)")
        end
    end
    return (result, steps)
end

"""
    register_learned_arith_callback!(name::String, ops::Vector{ArithOpStep}) -> Nothing

GRUG v9.3: Compile a parsed arithmetic op-sequence into a REAL, working
ActionEngine callback and register it under `name`. This is what makes
conversational procedural teaching produce a node that can compute ANY
instance of the taught procedure — not just recite the definition text
back. Mirrors the shape of the hand-written built-in callbacks (factorial,
square, ...) above, just constructed dynamically from `ops` instead of
being hand-coded.
"""
function register_learned_arith_callback!(name::AbstractString, ops::Vector{ArithOpStep};
                                           display_name::AbstractString = "")
    _name = String(lowercase(strip(name)))
    # GRUG v9.4: COHERENCE FIX — the registered callback name often carries an
    # internal "learned_" prefix (e.g. "learned_gorbling") to keep the
    # ACTION_CALLBACKS namespace collision-free. Without a separate display
    # name, the spoken reply text ("$(_name) of $(n_surface) is ...") leaked
    # that internal prefix straight into the user-facing answer ("learned_
    # gorbling of 7 is 19" instead of the natural "gorbling of 7 is 19").
    # `display_name` lets the caller supply the clean taught-topic word for
    # the reply while the internal registry key stays untouched — fully
    # backward compatible: when display_name is omitted (as all pre-existing
    # call sites do), it falls back to `_name` exactly as before.
    _display = isempty(strip(display_name)) ? _name : String(lowercase(strip(display_name)))
    register_action_callback!(_name, function(bindings::Vector{SigilBinding})
        n = _first_number_binding(bindings)
        n_surface = _first_number_surface(bindings)

        if n === nothing
            return ActionResult(_name, nothing, "", "$_display($n_surface)",
                ActionComputationStep[], "need a number binding, got nothing")
        end

        try
            result, steps = _apply_arith_ops(ops, n)
            answer_str = string(result)
            if result isa Float64 && result == floor(result) && abs(result) < typemax(Int)
                answer_str = string(Int(result))
            end
            reply = "$(_display) of $(n_surface) is $answer_str"
            return ActionResult(_name, result, reply, "$_display($n_surface)", steps, nothing)
        catch e
            return ActionResult(_name, nothing, "", "$_display($n_surface)",
                ActionComputationStep[], "computation failed: $e")
        end
    end)
    return nothing
end

end # module ActionEngine
