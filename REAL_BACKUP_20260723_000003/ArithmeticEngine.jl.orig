# ==============================================================================
# ArithmeticEngine.jl — GRUG Sigil-Bound Arithmetic Evaluator (Stage 2)
# ==============================================================================
# GRUG say: sigils are MACROS. When user say "what is 2+2", promoter rewrite
#           to "what is &n &op &n". Bindings carry operands and operator on
#           the side-channel. But nobody was READING the bindings to compute
#           the answer! Grug just say "Execute the calculation" like dumb rock.
#           NOW Grug READ bindings. Grug COMPUTE. Grug say "2 plus 2 equals 4".
#
# GRUG say: this module is the bridge between sigil capture and spoken answer.
#           It reads current_promotion_bindings(), extracts &n and &op values,
#           evaluates the arithmetic expression, and returns a structured result
#           that the AIML payload builder can inject into the reply.
#
# GRUG say: NO SILENT FAILURES. If bindings are present but can't compute, we
#           scream loud. If no bindings, we return nothing — caller falls back
#           to the normal claim path. Zero cost when no math is present.
#
# GRUG say: multi-step voting architecture. A single evaluation can produce
#           multiple steps (e.g. "3 + 5 * 2" → step 1: 5*2=10, step 2: 3+10=13).
#           Each step is a ComputationStep. The final answer is the last step.
#           The AIML layer can choose to show all steps or just the answer.
#
# DESIGN PRINCIPLES:
#   - Reads from current_promotion_bindings() — the existing side-channel
#   - Returns structured ArithmeticResult, not a string — caller decides format
#   - Zero cost when no math bindings present — nothing computed, nothing allocated
#   - Idempotent — compute_arithmetic() called twice returns same result
#   - All operators from OP_SYMBOL_SET are supported: + - * / = < > % ^
#   - Division by zero returns an error string, not a crash
#   - Comparison operators return boolean words: "true" / "false"
# ==============================================================================

module ArithmeticEngine

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

# GRUG: ArithmeticEngine lives inside the GrugBot420 package module.
# current_promotion_bindings is defined in engine.jl which is a sibling.
using ..SigilPromoter

export ArithmeticResult, ComputationStep, compute_arithmetic
export format_arithmetic_reply, has_math_bindings

# ==============================================================================
# ERROR TYPES — GRUG: NO SILENT FAILURES on programmer errors.
# ==============================================================================

struct ArithmeticEngineError <: Exception
    message::String
    context::String
end

function Base.showerror(io::IO, e::ArithmeticEngineError)
    print(io, "ArithmeticEngineError: ", e.message, " (context=", e.context, ")")
end

# ==============================================================================
# DATA STRUCTURES
# ==============================================================================

"""
A single step in a multi-step computation.

Fields:
  - `lhs`       — left-hand side (numeric value or string representation)
  - `operator`  — the operator applied (e.g. "+", "*", "/")
  - `rhs`       — right-hand side
  - `result`    — the computed result of this step
  - `lhs_surface` — original surface form from the binding (e.g. "two", "2")
  - `rhs_surface` — original surface form from the binding
  - `op_surface`  — original surface form of the operator (e.g. "plus", "+")
"""
struct ComputationStep
    lhs::Any
    operator::String
    rhs::Any
    result::Any
    lhs_surface::String
    rhs_surface::String
    op_surface::String
end

"""
The result of an arithmetic evaluation.

Fields:
  - `answer`       — the final computed value (Number, String for comparisons,
                      or nothing if evaluation failed)
  - `steps`        — ordered list of ComputationSteps (1 for simple, N for multi-step)
  - `expression`   — the full expression as reconstructed from bindings (e.g. "2 + 2")
  - `answer_str`   — human-readable answer string (e.g. "4", "true", "undefined (division by zero)")
  - `is_comparison` — whether this was a comparison operation (=, <, >)
  - `error`        — nothing on success, error string on failure
"""
struct ArithmeticResult
    answer::Any
    steps::Vector{ComputationStep}
    expression::String
    answer_str::String
    is_comparison::Bool
    error::Union{Nothing,String}
end

# ==============================================================================
# PUBLIC API
# ==============================================================================

"""
    has_math_bindings(bindings) -> Bool

Check whether the given bindings contain enough math sigils to attempt
arithmetic evaluation. Needs at least 2 `&n` bindings and 1 `&op` binding.
Returns false for empty bindings or non-math bindings (e.g. only `&word`).
"""
function has_math_bindings(bindings::Vector{SigilBinding})::Bool
    n_count = count(b -> b.name == "n", bindings)
    op_count = count(b -> b.name == "op", bindings)
    return n_count >= 2 && op_count >= 1
end

"""
    compute_arithmetic(bindings) -> ArithmeticResult

Read sigil bindings and evaluate the arithmetic expression they encode.

The evaluation follows positional order:
  - The first two `&n` bindings are the operands (left, right)
  - The first `&op` binding is the operator
  - For simple binary operations (2 operands, 1 operator), one ComputationStep
  - For chained operations (3+ operands, 2+ operators), multiple ComputationSteps

Returns an ArithmeticResult with:
  - `.answer` = the computed numeric value (or string for comparisons)
  - `.steps` = the list of computation steps
  - `.expression` = reconstructed expression string
  - `.answer_str` = human-readable answer
  - `.is_comparison` = whether this was a comparison op
  - `.error` = nothing on success, error message on failure

NO SILENT FAILURES: malformed bindings (wrong types, missing values) produce
an ArithmeticResult with .error set, not an exception. Only programmer errors
(calling with wrong types) throw.
"""
function compute_arithmetic(bindings::Vector{SigilBinding})::ArithmeticResult
    if isempty(bindings)
        return ArithmeticResult(
            nothing, ComputationStep[], "", "",
            false, "no bindings provided"
        )
    end

    # GRUG: Extract &n and &op bindings in positional order.
    number_bindings = filter(b -> b.name == "n", bindings)
    op_bindings     = filter(b -> b.name == "op", bindings)

    if length(number_bindings) < 2
        return ArithmeticResult(
            nothing, ComputationStep[], "", "",
            false, "need at least 2 number bindings, got $(length(number_bindings))"
        )
    end

    if isempty(op_bindings)
        return ArithmeticResult(
            nothing, ComputationStep[], "", "",
            false, "need at least 1 operator binding, got 0"
        )
    end

    # GRUG: Build the evaluation. Simple case: 2 numbers, 1 operator.
    # Multi-step case: 3+ numbers with 2+ operators (left-to-right evaluation).
    # For Stage 2 we implement left-to-right without operator precedence.
    # Operator precedence (BOMDAS/PEMDAS) is a future enhancement.
    steps = ComputationStep[]
    current_value = _to_numeric(number_bindings[1].value)
    if current_value === nothing
        return ArithmeticResult(
            nothing, ComputationStep[], "", "",
            false, "first operand is not a number: $(repr(number_bindings[1].value))"
        )
    end

    # GRUG: Build expression string for telemetry/display.
    expr_parts = String[_surface_form(number_bindings[1])]
    is_comparison = false

    # GRUG: Iterate over (operator, next_operand) pairs.
    # Number of operations = min(len(ops), len(numbers)-1)
    n_ops = min(length(op_bindings), length(number_bindings) - 1)

    for i in 1:n_ops
        op_val = String(op_bindings[i].value)
        rhs_val = _to_numeric(number_bindings[i + 1].value)

        if rhs_val === nothing
            return ArithmeticResult(
                nothing, steps, join(expr_parts, " "), "",
                is_comparison, "operand $(i+1) is not a number: $(repr(number_bindings[i + 1].value))"
            )
        end

        push!(expr_parts, _op_display(op_val))
        push!(expr_parts, _surface_form(number_bindings[i + 1]))

        # GRUG: Actually compute the result.
        step_result, step_error = _apply_op(current_value, op_val, rhs_val)

        if step_error !== nothing
            return ArithmeticResult(
                nothing, steps, join(expr_parts, " "), step_error,
                is_comparison, step_error
            )
        end

        # GRUG: Check if this is a comparison operator.
        if op_val in ("=", "<", ">")
            is_comparison = true
        end

        push!(steps, ComputationStep(
            current_value, op_val, rhs_val, step_result,
            _surface_form(number_bindings[i]),
            _surface_form(number_bindings[i + 1]),
            op_bindings[i].surface
        ))

        current_value = step_result
    end

    # GRUG: Format the final answer.
    answer_str = _format_answer(current_value, is_comparison)
    expression = join(expr_parts, " ")

    return ArithmeticResult(
        current_value,
        steps,
        expression,
        answer_str,
        is_comparison,
        nothing
    )
end

"""
    format_arithmetic_reply(result::ArithmeticResult) -> String

Format an ArithmeticResult into a natural-language reply string.
Examples:
  - "2 plus 2 equals 4"
  - "10 divided by 3 equals 3.333..."
  - "5 is greater than 3: true"
  - "3 + 5 × 2 = 13 (steps: 5 × 2 = 10, then 3 + 10 = 13)"

For multi-step computations, shows the step-by-step breakdown.
For simple computations, shows a single sentence.
"""
function format_arithmetic_reply(result::ArithmeticResult)::String
    if result.error !== nothing
        return "Could not compute: $(result.error)."
    end

    if isempty(result.steps)
        return "No computation performed."
    end

    # GRUG: Single-step computation — speak it as one sentence.
    if length(result.steps) == 1
        step = result.steps[1]
        op_word = _op_to_word(step.operator)
        lhs_str = _speak_number(step.lhs, step.lhs_surface)
        rhs_str = _speak_number(step.rhs, step.rhs_surface)
        ans_str = result.answer_str

        if result.is_comparison
            return "$lhs_str $op_word $rhs_str: $ans_str"
        else
            return "$lhs_str $op_word $rhs_str equals $ans_str"
        end
    end

    # GRUG: Multi-step computation — show steps then final answer.
    step_strs = String[]
    for (i, step) in enumerate(result.steps)
        lhs_s = _speak_number(step.lhs, step.lhs_surface)
        rhs_s = _speak_number(step.rhs, step.rhs_surface)
        op_w  = _op_to_word(step.operator)
        ans_s = _format_answer(step.result, result.is_comparison)
        push!(step_strs, "$lhs_s $op_w $rhs_s = $ans_s")
    end

    steps_prose = join(step_strs, ", then ")
    return "$steps_prose, so the answer is $(result.answer_str)"
end

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

# GRUG: Convert a binding value to a numeric type.
# The promoter already parses "2" → Int(2) and "2.5" → Float64(2.5).
# But we need to handle the case where the value is still a string
# (shouldn't happen with correct promoter, but defensive).
function _to_numeric(val)::Union{Number,Nothing}
    if val isa Number
        return val
    end
    if val isa AbstractString
        try
            s = String(val)
            # GRUG: strip sign prefix from the value if the promoter left it
            # (shouldn't happen but defensive).
            if occursin(r"^[+-]?\d+$", s)
                return parse(Int, s)
            elseif occursin(r"^[+-]?\d+\.\d+$", s)
                return parse(Float64, s)
            end
        catch
            return nothing
        end
    end
    return nothing
end

# GRUG: Apply a single binary operator. Returns (result, error_string).
function _apply_op(lhs::Number, op::String, rhs::Number)::Tuple{Any,Union{Nothing,String}}
    if op == "+"
        return lhs + rhs, nothing
    elseif op == "-"
        return lhs - rhs, nothing
    elseif op == "*"
        return lhs * rhs, nothing
    elseif op == "/"
        if rhs == 0
            return nothing, "division by zero (cannot divide $(lhs) by zero)"
        end
        # GRUG: Integer division that would truncate → Float64 for honest answer.
        # e.g. 7 / 2 = 3.5, not 3.
        result = lhs / rhs
        # GRUG: If both inputs were Int and the result is exact, keep it as Int
        # so "6 / 3" gives "2" not "2.0".
        if lhs isa Integer && rhs isa Integer && result == floor(result) && abs(result) < typemax(Int)
            return Int(result), nothing
        end
        return result, nothing
    elseif op == "%"
        if rhs == 0
            return nothing, "modulo by zero (cannot compute $(lhs) mod zero)"
        end
        return lhs % rhs, nothing
    elseif op == "^"
        # GRUG: Power. Protect against insane exponents.
        if rhs > 100 || rhs < -100
            return nothing, "exponent too large ($rhs) — Grug not burn down hut with big number"
        end
        try
            result = lhs ^ rhs
            # GRUG: If result is Float64 but represents an integer, convert.
            if result isa Float64 && result == floor(result) && abs(result) < typemax(Int) && isfinite(result)
                return Int(result), nothing
            end
            return result, nothing
        catch e
            return nothing, "power computation failed: $e"
        end
    elseif op == "="
        # GRUG: Equality comparison. Return string "true"/"false".
        return lhs == rhs ? "true" : "false", nothing
    elseif op == "<"
        return lhs < rhs ? "true" : "false", nothing
    elseif op == ">"
        return lhs > rhs ? "true" : "false", nothing
    else
        return nothing, "unknown operator '$op'"
    end
end

# GRUG: Format the answer for display.
function _format_answer(val::Any, is_comparison::Bool)::String
    if val === nothing
        return "undefined"
    end
    if val isa AbstractString
        return String(val)  # "true" / "false" from comparisons
    end
    if val isa Float64
        # GRUG: Round to reasonable precision to avoid Float64 noise.
        # e.g. 0.1 + 0.2 = 0.30000000000000004 → show "0.3"
        if val == floor(val) && abs(val) < 1e15
            return string(Int(val))
        end
        # GRUG: Show up to 6 decimal places, strip trailing zeros.
        s = string(round(val, digits=6))
        s = replace(s, r"\.?0+$" => "")
        return s
    end
    return string(val)
end

# GRUG: Get the surface form of a binding for display.
# Falls back to the value string if surface is empty.
function _surface_form(binding::SigilBinding)::String
    if !isempty(binding.surface)
        return binding.surface
    end
    return string(binding.value)
end

# GRUG: Convert operator symbol to English word for spoken reply.
function _op_to_word(op::String)::String
    if op == "+"; return "plus"
    elseif op == "-"; return "minus"
    elseif op == "*"; return "times"
    elseif op == "/"; return "divided by"
    elseif op == "%"; return "modulo"
    elseif op == "^"; return "to the power of"
    elseif op == "="; return "equals"
    elseif op == "<"; return "is less than"
    elseif op == ">"; return "is greater than"
    else; return op
    end
end

# GRUG: Display-friendly operator for expression strings.
function _op_display(op::String)::String
    if op == "*"; return "×"
    elseif op == "/"; return "÷"
    else; return op
    end
end

# GRUG: Speak a number, preferring the user's own surface form
# when available (so "two plus two" stays "two" not "2").
function _speak_number(val::Any, surface::String)::String
    if !isempty(surface)
        return surface
    end
    return string(val)
end

end # module ArithmeticEngine
