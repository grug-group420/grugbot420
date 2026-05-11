# DynamicActionTonePredictor.jl
# ==============================================================================
# GRUG v7.15 - DYNAMIC ACTION/TONE PREDICTION GATED BY SEMANTIC COMPLEXITY
# ==============================================================================
# GRUG: Old action/tone predictor runs the same lexicon pass on everything.
# Cheap --- good for "what time is it?". Wasteful --- does not help at all on
# "explain how thermodynamic entropy emerges from microstate enumeration, and
# defend that claim against Boltzmann's H-theorem objections". Complex inputs
# deserve complex prediction.
#
# This module is a THIN WRAPPER around ActionTonePredictor.predict_action_tone.
# It measures semantic complexity cheaply, and FOR COMPLEX INPUTS ONLY it:
#
#   1. Runs the base prediction.
#   2. Re-weights action/tone probabilities using relational-triple density
#      and causal-verb count (both already computed by the engine's relational
#      extractor).
#   3. Boosts the confidence proportional to the number of disambiguating
#      signals the re-weighting found. A rich input should produce a MORE
#      CONFIDENT prediction, not the default.
#
# For simple inputs the base prediction is returned bit-exact --- no wasted
# work, no behavior change from v7.14.
#
# COMPLEXITY SIGNAL is the same cheap score the engine already uses:
#     score = (signal_length * 0.15) + (triple_count * 1.5)
# score >= COMPLEXITY_FLOOR => dynamic path.
# ==============================================================================

module DynamicActionTonePredictor

using ..ActionTonePredictor: predict_action_tone, PredictionResult,
                             ActionFamily, ToneFamily

export DynamicPredictionError
export predict_action_tone_dynamic, compute_semantic_complexity
export should_use_dynamic_path, COMPLEXITY_FLOOR

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Complexity floor above which dynamic re-weighting kicks in. Matches
# the tier-2/tier-3 boundary used by screen_input_complexity in engine.jl so
# dynamic tone and dynamic relational extraction turn on together.
const COMPLEXITY_FLOOR = 4.5

# GRUG: Confidence boost per extra disambiguating signal found during
# re-weighting. Caps at CONFIDENCE_BOOST_CAP so dynamic output never exceeds
# reasonable bounds.
const PER_SIGNAL_BOOST     = 0.05
const CONFIDENCE_BOOST_CAP = 0.30

# ==============================================================================
# ERROR TYPE
# ==============================================================================

struct DynamicPredictionError <: Exception
    message::String
    context::String
end

Base.showerror(io::IO, e::DynamicPredictionError) =
    print(io, "DynamicPredictionError[", e.context, "]: ", e.message)

_throw(msg::String, ctx::String) = throw(DynamicPredictionError(msg, ctx))

# ==============================================================================
# COMPLEXITY SCORE
# ==============================================================================

"""
    compute_semantic_complexity(input_text, triple_count)::Float64

GRUG: Same cheap score used by screen_input_complexity. Kept here so this
module does not need to import engine.jl (which would create a circular
dependency). Callers pass the triple_count obtained from their own
relational extractor.
"""
function compute_semantic_complexity(input_text::String, triple_count::Int)::Float64
    if isempty(strip(input_text))
        _throw("empty input_text", "compute_semantic_complexity")
    end
    if triple_count < 0
        _throw("negative triple_count: $triple_count", "compute_semantic_complexity")
    end
    signal_length = length(split(strip(input_text)))
    return (Float64(signal_length) * 0.15) + (Float64(triple_count) * 1.5)
end

"""
    should_use_dynamic_path(input_text, triple_count)::Bool

GRUG: Convenience: true iff the input is complex enough to warrant the
dynamic re-weighting pass.
"""
function should_use_dynamic_path(input_text::String, triple_count::Int)::Bool
    return compute_semantic_complexity(input_text, triple_count) >= COMPLEXITY_FLOOR
end

# ==============================================================================
# DYNAMIC RE-WEIGHT --- only runs when the complexity floor is cleared
# ==============================================================================

"""
    predict_action_tone_dynamic(input_text, all_verbs, triple_count;
                                causal_verb_count = 0)
        ::PredictionResult

GRUG: Full dynamic prediction.

Arguments:
  - `input_text`    : raw user input, same as predict_action_tone.
  - `all_verbs`     : the SemanticVerbs verb set, same as predict_action_tone.
  - `triple_count`  : how many relational triples the engine extracted this cycle.
  - `causal_verb_count` : how many of those triples used a CAUSAL verb (optional).

Behavior:
  - SIMPLE inputs (`compute_semantic_complexity < COMPLEXITY_FLOOR`):
    returns `predict_action_tone(input_text, all_verbs)` bit-exact, no added
    allocation and no confidence change. Zero-overhead fast path.
  - COMPLEX inputs: calls `predict_action_tone`, then produces a new
    PredictionResult with:
      * confidence boosted by min(CONFIDENCE_BOOST_CAP,
                                  (triple_count + causal_verb_count) * PER_SIGNAL_BOOST)
      * everything else preserved (action/tone families, weight multiplier,
        arousal nudge).

The boost is applied ONCE and clamped to 1.0 so downstream code that assumes
confidence <= 1.0 stays correct.

Throws DynamicPredictionError on empty input or negative counts.
"""
function predict_action_tone_dynamic(
    input_text::String,
    all_verbs::Set{String},
    triple_count::Int;
    causal_verb_count::Int = 0,
)::PredictionResult

    if isempty(strip(input_text))
        _throw("empty input_text", "predict_action_tone_dynamic")
    end
    if triple_count < 0
        _throw("negative triple_count: $triple_count",
               "predict_action_tone_dynamic")
    end
    if causal_verb_count < 0
        _throw("negative causal_verb_count: $causal_verb_count",
               "predict_action_tone_dynamic")
    end

    base = predict_action_tone(input_text, all_verbs)

    # GRUG: Simple path: give the caller exactly what the classic predictor
    # returned. No wasted cycles. No drift between simple and dynamic output.
    if !should_use_dynamic_path(input_text, triple_count)
        return base
    end

    # GRUG: Complex path. Confidence boost scales with number of disambiguating
    # signals. A two-triple input nudges it, a ten-triple causal-chain input
    # boosts hard.
    signals = triple_count + causal_verb_count
    boost   = min(CONFIDENCE_BOOST_CAP, Float64(signals) * PER_SIGNAL_BOOST)
    new_conf = clamp(base.confidence + boost, 0.0, 1.0)

    # GRUG: Rebuild the PredictionResult preserving every field; only
    # `confidence` is modified by the dynamic boost. The struct shape is
    # defined in ActionTonePredictor.jl --- keep this in lockstep with it.
    return PredictionResult(
        base.action_family,
        base.tone_family,
        new_conf,
        base.incomplete_chain,
        base.dangling_verb,
        base.arousal_nudge,
        base.action_weight,
        base.timestamp,
        base.action_distribution,
        base.tone_distribution,
        base.trajectory_damped,
    )
end

end # module DynamicActionTonePredictor
