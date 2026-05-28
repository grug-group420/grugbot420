# ==============================================================================
# EphemeralAutomaton.jl — v7.23 ATP-Callable JIT Step Machine
# ==============================================================================
# GRUG say: most rocks just react. Question come in, rock match pattern, rock
#           shout answer. That is pattern REACTION. But some questions need
#           STEPS. "Take 3, double it, add 5, then square." That is pattern
#           COMPLETION. Old grug had no completion. New grug have small JIT
#           machine: tiny rule-set, lives only for one question, dies after.
#
# GRUG say: NOT a sub-population. NOT persistent. NO strength. NO grave. Pure
#           working-memory loop. Basal-ganglia (ATP) decides if escalate. Few
#           rocks ever fire at one time, so this is sparse — no thread storm.
#
# GRUG say: jitter snap-back is per-step, on values caller TAGS as safe to
#           wobble. Step indices, operator names, final state booleans never
#           wobble — that would corrupt step coherence. Numeric values that
#           are accumulators or weights CAN wobble, mean snaps back to true
#           value.
#
# GRUG say: user can add rules at runtime. Rules tiny. Pattern-trigger plus
#           ordered step list. End user ships rules; engine does not bake any
#           policy.
# ==============================================================================
#
# ACADEMIC: This module implements an ephemeral automaton — a transient,
# rule-driven step executor invoked by ActionTonePredictor when escalation
# is warranted. Rules are persistent (registered with `register_automaton_rule!`
# and stored in a process-wide registry); traces are not (each call returns
# a fresh AutomatonTrace whose lifetime is the caller's). The automaton
# performs no cross-call state sharing and creates no nodes. Stochastic
# perturbation is opt-in per step output via the `jitter_targets` field;
# fields not in this set are returned bit-exact, preserving the deterministic
# step sequence required for downstream coherence.
# ==============================================================================

module EphemeralAutomaton

using ..RelationalJitter: jitter_value, JitterError

export AutomatonRule, AutomatonStep, AutomatonTrace
export AutomatonError, AutomatonRuleError
export register_automaton_rule!, unregister_automaton_rule!,
       list_automaton_rules, lookup_automaton_rule, clear_automaton_rules!
export run_automaton, find_matching_rule, run_for_action_family

# ==============================================================================
# ERROR TYPES
# ==============================================================================

struct AutomatonError <: Exception
    message::String
    context::String
end

struct AutomatonRuleError <: Exception
    message::String
    context::String
end

@inline _err(msg, ctx) = throw(AutomatonError(msg, ctx))
@inline _rerr(msg, ctx) = throw(AutomatonRuleError(msg, ctx))

# ==============================================================================
# STEP & RULE STRUCTS
# ==============================================================================

"""
A single deterministic step in an automaton rule. `op` is a Symbol naming the
operation (e.g. :literal, :add, :double, :tag), `payload` is anything the
op needs (most often a Number, a String, or a NamedTuple). `label` is a
human-readable name surfaced in the trace.
"""
struct AutomatonStep
    label::String
    op::Symbol
    payload::Any
end

"""
An automaton rule. `id` is unique per registry. `trigger_action` is the
ActionFamily that, in combination with confidence ≥ threshold, makes ATP
escalate to this rule. `steps` is the ordered list of AutomatonStep.
`jitter_targets` is the set of step labels whose numeric output is allowed
to wobble through RelationalJitter; outputs of unlisted steps are exact.
`min_confidence` is the ATP confidence floor below which the rule will not
fire even if the action family matches.
"""
struct AutomatonRule
    id::String
    trigger_action::Symbol
    steps::Vector{AutomatonStep}
    jitter_targets::Set{String}
    min_confidence::Float64
end

function AutomatonRule(id::String, trigger_action::Symbol,
                       steps::Vector{AutomatonStep};
                       jitter_targets::Set{String} = Set{String}(),
                       min_confidence::Float64 = 0.5)
    if isempty(strip(id))
        _rerr("automaton rule id cannot be empty", "AutomatonRule")
    end
    if isempty(steps)
        _rerr("automaton rule '$id' has zero steps", "AutomatonRule")
    end
    if !(min_confidence >= 0.0 && min_confidence <= 1.0)
        _rerr("automaton rule '$id' min_confidence must be in [0,1], got $min_confidence",
              "AutomatonRule")
    end
    return AutomatonRule(id, trigger_action, steps, jitter_targets, min_confidence)
end

"""
Trace of one rule execution. `values` maps step label -> evaluated output
(post-jitter where applicable). `sequence` is the labels in order so callers
that want the linear story can iterate it deterministically. `jittered`
records which labels were perturbed this run.
"""
struct AutomatonTrace
    rule_id::String
    sequence::Vector{String}
    values::Dict{String, Any}
    jittered::Set{String}
end

# ==============================================================================
# REGISTRY
# ==============================================================================

const _AUTOMATON_REGISTRY      = Dict{String, AutomatonRule}()
const _AUTOMATON_REGISTRY_LOCK = ReentrantLock()

"""
    register_automaton_rule!(rule) -> AutomatonRule

Add a rule under its `id`. Throws if `id` already exists — explicit
overwrite is required via `unregister_automaton_rule!` first to make
double-register accidents impossible.
"""
function register_automaton_rule!(rule::AutomatonRule)::AutomatonRule
    lock(_AUTOMATON_REGISTRY_LOCK) do
        if haskey(_AUTOMATON_REGISTRY, rule.id)
            _rerr("automaton rule '$(rule.id)' already registered; unregister first",
                  "register_automaton_rule!")
        end
        _AUTOMATON_REGISTRY[rule.id] = rule
    end
    return rule
end

"""
    unregister_automaton_rule!(id) -> Bool

Remove the rule. Returns true if removed, false if was not present (this
case is non-fatal; a delete that finds nothing is idempotent).
"""
function unregister_automaton_rule!(id::String)::Bool
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        if haskey(_AUTOMATON_REGISTRY, id)
            delete!(_AUTOMATON_REGISTRY, id)
            return true
        end
        return false
    end
end

function list_automaton_rules()::Vector{AutomatonRule}
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        collect(values(_AUTOMATON_REGISTRY))
    end
end

function lookup_automaton_rule(id::String)::Union{AutomatonRule, Nothing}
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        get(_AUTOMATON_REGISTRY, id, nothing)
    end
end

function clear_automaton_rules!()
    lock(_AUTOMATON_REGISTRY_LOCK) do
        empty!(_AUTOMATON_REGISTRY)
    end
    return nothing
end

# ==============================================================================
# STEP EVALUATOR — small builtin op set; extensible by users via :userfn
# ==============================================================================

# GRUG: the eval table is intentionally tiny. Each op is a pure function over
# (payload, accum, ctx) returning a value. :userfn lets the caller stash an
# arbitrary callable in the payload for things the builtin set does not cover.
function _eval_step(step::AutomatonStep, accum::Any, ctx::Dict{String, Any})
    op = step.op
    p  = step.payload
    if op === :literal
        return p
    elseif op === :tag
        # Tag steps record a label-string; do not affect accum.
        return p
    elseif op === :add
        return _as_number(accum) + _as_number(p)
    elseif op === :sub
        return _as_number(accum) - _as_number(p)
    elseif op === :mul
        return _as_number(accum) * _as_number(p)
    elseif op === :div
        d = _as_number(p)
        d == 0 && _err("divide by zero in step '$(step.label)'", "_eval_step")
        return _as_number(accum) / d
    elseif op === :pow
        return _as_number(accum) ^ _as_number(p)
    elseif op === :double
        return _as_number(accum) * 2.0
    elseif op === :half
        return _as_number(accum) / 2.0
    elseif op === :setctx
        # payload must be a Pair{String,Any}: write into ctx, return accum unchanged
        if !(p isa Pair)
            _err("op :setctx requires a Pair payload, got $(typeof(p))",
                 "_eval_step")
        end
        ctx[String(first(p))] = last(p)
        return accum
    elseif op === :getctx
        # payload is a String key; missing key is a loud error
        if !(p isa AbstractString)
            _err("op :getctx requires a String key, got $(typeof(p))",
                 "_eval_step")
        end
        haskey(ctx, String(p)) || _err(
            "op :getctx missing key '$(String(p))'", "_eval_step")
        return ctx[String(p)]
    elseif op === :userfn
        # payload must be a callable taking (accum, ctx)
        if !(p isa Function)
            _err("op :userfn requires a callable payload, got $(typeof(p))",
                 "_eval_step")
        end
        return p(accum, ctx)
    else
        _err("unknown automaton op :$(op) in step '$(step.label)'",
             "_eval_step")
    end
end

@inline function _as_number(x)
    if x isa Number
        return float(x)
    elseif x isa AbstractString
        v = tryparse(Float64, x)
        v === nothing && _err("could not parse '$x' as a number", "_as_number")
        return v
    else
        _err("expected number, got $(typeof(x))", "_as_number")
    end
end

# ==============================================================================
# RUN
# ==============================================================================

"""
    run_automaton(rule, ctx; seed=0.0) -> AutomatonTrace

Execute every step in order. The accumulator starts at `seed` (or whatever
the first :literal step writes) and threads through subsequent ops.
Steps whose label is in `rule.jitter_targets` AND whose output is numeric
get a zero-mean nudge via `RelationalJitter.jitter_value`. All other step
outputs are exact.

`ctx` is a mutable Dict that survives across steps within this run only —
each call to `run_automaton` constructs a fresh ctx if not supplied.

Throws AutomatonError on any step failure. Never silently drops a step.
"""
function run_automaton(rule::AutomatonRule;
                       ctx::Dict{String, Any} = Dict{String, Any}(),
                       seed::Any = 0.0)::AutomatonTrace
    sequence = String[]
    values   = Dict{String, Any}()
    jittered = Set{String}()
    accum    = seed

    for step in rule.steps
        if haskey(values, step.label)
            _err("duplicate step label '$(step.label)' in rule '$(rule.id)'",
                 "run_automaton")
        end
        result = try
            _eval_step(step, accum, ctx)
        catch e
            if e isa AutomatonError
                rethrow()
            else
                _err("step '$(step.label)' (op=$(step.op)) raised $(typeof(e)): $(sprint(showerror, e))",
                     "run_automaton")
            end
        end

        # Optional jitter: only on numeric results AND only if label is tagged.
        if step.label in rule.jitter_targets && result isa Number
            try
                result = jitter_value(float(result))
                push!(jittered, step.label)
            catch e
                # JitterError on non-finite or out-of-range — surface loudly.
                _err("jitter failed on step '$(step.label)': $(sprint(showerror, e))",
                     "run_automaton")
            end
        end

        push!(sequence, step.label)
        values[step.label] = result
        # The accumulator only updates for ops that participate in arithmetic.
        # Tag/setctx leave accum unchanged.
        if !(step.op in (:tag, :setctx))
            accum = result
        end
    end

    return AutomatonTrace(rule.id, sequence, values, jittered)
end

# ==============================================================================
# DISPATCH HELPERS
# ==============================================================================

"""
    find_matching_rule(action_family, confidence) -> Union{AutomatonRule,Nothing}

Find the highest-confidence-bar rule whose trigger matches and whose
min_confidence is satisfied. If multiple rules tie, the one registered
earliest wins (registry ordering). Returns nothing if no match.
"""
function find_matching_rule(action_family::Symbol, confidence::Float64)
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        best::Union{AutomatonRule, Nothing} = nothing
        best_bar = -Inf
        for r in values(_AUTOMATON_REGISTRY)
            r.trigger_action === action_family || continue
            confidence >= r.min_confidence || continue
            if r.min_confidence > best_bar
                best = r
                best_bar = r.min_confidence
            end
        end
        return best
    end
end

"""
    run_for_action_family(action_family, confidence; ctx, seed)
        -> Union{AutomatonTrace, Nothing}

Convenience: look up a matching rule, run it, return its trace. Returns
`nothing` (not an error) when no rule matches — callers treat that as
"no escalation, proceed with reaction-only path".
"""
function run_for_action_family(action_family::Symbol,
                               confidence::Float64;
                               ctx::Dict{String, Any} = Dict{String, Any}(),
                               seed::Any = 0.0)::Union{AutomatonTrace, Nothing}
    rule = find_matching_rule(action_family, confidence)
    rule === nothing && return nothing
    return run_automaton(rule; ctx = ctx, seed = seed)
end

end # module
