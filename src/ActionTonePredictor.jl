# ActionTonePredictor.jl
# ==============================================================================
# GRUG: This is the reflex prediction cave. Fires BEFORE the vote pool assembles.
#
# NOT token prediction. NOT next-word guessing. NOT an LLM.
# THIS reads raw input structure and predicts:
#   1. What ACTION the user intends (ASSERT / QUERY / COMMAND / NEGATE /
#      SPECULATE / ESCALATE)
#   2. What TONE they carry (HOSTILE / CURIOUS / DECLARATIVE / URGENT /
#      NEUTRAL / REFLECTIVE)
#
# GRUG: Two outputs from this module feed back into the cave:
#   - arousal_nudge  → applied to EyeSystem BEFORE scan runs
#   - action_weight  → multiplied into node confidence scores INSIDE scan_specimens
#
# Neither output is a vote. Neither output is mandatory. If prediction fails,
# the cave scans normally without modulation. No silent failure — failure is
# logged as @warn and execution continues.
#
# INCOMPLETE CAUSAL CHAIN DETECTION:
# If a relational verb appears at the tail of input with no object token
# following it (e.g. "fire causes"), the chain is flagged as dangling.
# This nudges the predicted action toward SPECULATE — the system is being asked
# to complete a partial thought.
#
# TRAJECTORY NORMALIZATION & ATTRACTOR AVOIDANCE:
# Raw lexicon scores are softmax-normalized into proper probability distributions.
# This makes predictions length-invariant: a 3-word and a 30-word input that
# express the same intent produce similar distributions.
#
# A trajectory buffer (ring buffer of last N normalized distributions) tracks
# the system's path through action-tone space over time. Each entry decays
# exponentially by age. The trajectory centroid (time-weighted EMA) is compared
# against a Lorenz/Gini concentration threshold: if one category dominates the
# trajectory history, entropy-restoring damping spreads mass to underrepresented
# categories. This prevents strange attractors — the system cannot lock into
# a single action/tone family indefinitely.
#
# The trajectory system is the Lorenz curve analog: if "wealth" (probability
# mass) concentrates beyond the Gini threshold, redistribute. Fresh input
# always has the strongest voice. Old predictions decay naturally.
# ==============================================================================

module ActionTonePredictor

using Random

export ActionFamily, ToneFamily, PredictionResult,
       predict_action_tone, apply_prediction_to_arousal!,
       get_action_weight_multiplier, format_prediction_summary,
       reset_trajectory!, get_trajectory_state, TrajectoryConfig,
       reset_tonal_buildup!, get_tonal_buildup,
       TONAL_BUILDUP_INCREMENT, TONAL_BUILDUP_HALFLIFE_S,
       TONAL_BUILDUP_AROUSAL_GAIN,
       LORENZ_SNAPBACK_JITTER, LORENZ_SNAPBACK_PULL

# ==============================================================================
# ENUM TYPES
# ==============================================================================

# GRUG: Action families — what is the user trying to DO?
@enum ActionFamily begin
    ACTION_ASSERT     # "X is Y", "X causes Y" — declarative claim, stating a fact
    ACTION_QUERY      # "what", "why", "how", "?" — requesting information
    ACTION_COMMAND    # "run", "stop", "build" — directive, imperative structure
    ACTION_NEGATE     # "not", "never", "wrong" — contradiction or rejection
    ACTION_SPECULATE  # "maybe", "could", "might" — epistemic hedge, incomplete chain
    ACTION_ESCALATE   # ALL CAPS, "!!!", "critical" — emotional spike, urgency burst
end

# GRUG: Tone families — HOW does the user sound while doing it?
@enum ToneFamily begin
    TONE_HOSTILE      # Aggression markers: "wrong", "broken", "garbage", "stupid"
    TONE_CURIOUS      # Exploratory: question words, open-ended framing
    TONE_DECLARATIVE  # Flat assertion, no emotional loading
    TONE_URGENT       # Time pressure: "now", "immediately", "critical", "asap"
    TONE_NEUTRAL      # No strong markers detected — baseline
    TONE_REFLECTIVE   # Hedged language: "i think", "perhaps", "it seems"
end

# GRUG: Full prediction result. Carry this through the cave as a pre-tuning packet.
# It is immutable — created once per input, read many times during scan.
struct PredictionResult
    action_family    ::ActionFamily
    tone_family      ::ToneFamily
    confidence       ::Float64   # Prediction confidence [0.0, 1.0]
    incomplete_chain ::Bool      # True if a dangling relational verb was detected
    dangling_verb    ::Union{String, Nothing}  # Which verb was left dangling, if any
    arousal_nudge    ::Float64   # Signed delta [-1.0, 1.0] to add to current arousal
    action_weight    ::Float64   # Confidence multiplier for aligned nodes [0.5, 2.0]
    timestamp        ::Float64   # Unix timestamp of prediction (time())
    action_distribution ::Dict{ActionFamily, Float64}  # Normalized action probabilities
    tone_distribution   ::Dict{ToneFamily, Float64}    # Normalized tone probabilities
    trajectory_damped   ::Bool   # True if Lorenz damping was applied this prediction
    figurative_dismiss  ::Bool   # GRUG v7.32: True when figurative language detected (easy as 2+2)
    negation_strength   ::Float64  # GRUG v7.32: Raw negation signal magnitude [0.0, ∞)
end

# ==============================================================================
# TRAJECTORY CONFIGURATION
# ==============================================================================

"""
    TrajectoryConfig

Tuning knobs for the trajectory normalization and attractor avoidance system.
All values have sane defaults. Callers can override via `set_trajectory_config!`.

- `buffer_size`:     Ring buffer depth (how many past predictions to remember)
- `decay_halflife`:  Seconds until a past prediction loses half its influence
- `gini_threshold`:  Gini coefficient above which Lorenz damping activates [0.0, 1.0]
- `damping_strength`: How much mass to redistribute when damping fires [0.0, 1.0]
- `softmax_temperature`: Temperature for softmax normalization (lower = sharper)
"""
struct TrajectoryConfig
    buffer_size        ::Int
    decay_halflife     ::Float64
    gini_threshold     ::Float64
    damping_strength   ::Float64
    softmax_temperature::Float64
end

# GRUG: Sane defaults. Buffer of 16 turns, 120s halflife, Gini threshold at 0.72
# (roughly: one category has 60%+ of trajectory mass), mild damping at 0.25,
# softmax temperature of 1.5 (warm — not too sharp, not too flat).
const DEFAULT_TRAJECTORY_CONFIG = TrajectoryConfig(16, 120.0, 0.72, 0.25, 1.5)

# ==============================================================================
# TRAJECTORY STATE (module-level, reset on reload)
# ==============================================================================

# GRUG: Each trajectory entry stores a normalized distribution snapshot + timestamp.
struct TrajectoryEntry
    action_dist ::Dict{ActionFamily, Float64}
    tone_dist   ::Dict{ToneFamily, Float64}
    timestamp   ::Float64
end

# GRUG: Module-level mutable state. Ring buffer of trajectory entries.
# Guarded by ReentrantLock for thread safety (scan can run from multiple tasks).
const _trajectory_lock   = ReentrantLock()
const _trajectory_buffer = Vector{TrajectoryEntry}()
const _trajectory_config = Ref{TrajectoryConfig}(DEFAULT_TRAJECTORY_CONFIG)

"""
    reset_trajectory!()

Clear all trajectory history and reset config to defaults.
Called on module reload or explicit reset. Thread-safe.
"""
function reset_trajectory!()
    lock(_trajectory_lock) do
        empty!(_trajectory_buffer)
        _trajectory_config[] = DEFAULT_TRAJECTORY_CONFIG
    end
    # GRUG: A full reset also wipes mood. Tests that reset trajectory expect
    # a completely fresh predictor — leaving build-up around would mean a
    # ghost mood across "fresh" calls.
    reset_tonal_buildup!()
    return nothing
end

"""
    set_trajectory_config!(config::TrajectoryConfig)

Override trajectory tuning knobs. Thread-safe.
Validates all fields before applying — NO SILENT FAILURES.
"""
function set_trajectory_config!(config::TrajectoryConfig)
    if config.buffer_size < 1
        error("!!! FATAL: TrajectoryConfig buffer_size must be >= 1, got $(config.buffer_size) !!!")
    end
    if config.decay_halflife <= 0.0
        error("!!! FATAL: TrajectoryConfig decay_halflife must be > 0.0, got $(config.decay_halflife) !!!")
    end
    if !(0.0 <= config.gini_threshold <= 1.0)
        error("!!! FATAL: TrajectoryConfig gini_threshold must be in [0.0, 1.0], got $(config.gini_threshold) !!!")
    end
    if !(0.0 <= config.damping_strength <= 1.0)
        error("!!! FATAL: TrajectoryConfig damping_strength must be in [0.0, 1.0], got $(config.damping_strength) !!!")
    end
    if config.softmax_temperature <= 0.0
        error("!!! FATAL: TrajectoryConfig softmax_temperature must be > 0.0, got $(config.softmax_temperature) !!!")
    end
    lock(_trajectory_lock) do
        _trajectory_config[] = config
    end
    return nothing
end

"""
    get_trajectory_state() -> (centroid_action, centroid_tone, gini_action, gini_tone, buffer_len)

Read-only snapshot of current trajectory state for diagnostics.
Returns the time-weighted centroid distributions and their Gini coefficients.
Thread-safe.
"""
function get_trajectory_state()
    lock(_trajectory_lock) do
        config = _trajectory_config[]
        now    = time()

        if isempty(_trajectory_buffer)
            # GRUG: No history — return uniform distributions and zero Gini.
            uniform_a = Dict(f => 1.0 / length(instances(ActionFamily)) for f in instances(ActionFamily))
            uniform_t = Dict(f => 1.0 / length(instances(ToneFamily))   for f in instances(ToneFamily))
            return (uniform_a, uniform_t, 0.0, 0.0, 0)
        end

        centroid_a, centroid_t = _compute_trajectory_centroid(now, config)
        gini_a = _gini_coefficient(collect(values(centroid_a)))
        gini_t = _gini_coefficient(collect(values(centroid_t)))
        return (centroid_a, centroid_t, gini_a, gini_t, length(_trajectory_buffer))
    end
end

# ==============================================================================
# LEXICONS
# GRUG: Surface-level token scoring tables. These are the cave's smell sensors.
# Strong signal = clear action/tone. Weak/absent signal = default to ASSERT/NEUTRAL.
# ==============================================================================

# GRUG: Query markers — tokens that smell like information-seeking
const QUERY_MARKERS = Set([
    "what", "why", "how", "when", "where", "who", "which",
    "explain", "describe", "tell", "show", "define", "clarify"
])

# GRUG: Command markers — imperative/directive tokens
const COMMAND_MARKERS = Set([
    "do", "run", "stop", "start", "make", "create", "build", "delete",
    "remove", "add", "set", "get", "list", "give", "send", "go",
    "generate", "write", "find", "search", "update", "reset", "load"
])

# GRUG: Negation markers — contradiction and rejection tokens
const NEGATE_MARKERS = Set([
    "not", "never", "no", "wrong", "incorrect", "false", "deny",
    "negate", "contradict", "disagree", "refuse", "reject", "invalid",
    # GRUG v7.32: Contraction negations — "don't", "won't", etc.
    # After punctuation strip (removes ,;.!?:) the apostrophe survives,
    # so these are literal token matches.
    "don't", "doesn't", "didn't", "won't", "wouldn't", "can't", "cannot",
    "couldn't", "shouldn't", "isn't", "aren't", "wasn't", "weren't",
    "haven't", "hasn't", "hadn't", "mustn't", "needn't", "shan't"
])

# GRUG: Speculative markers — epistemic hedging tokens
const SPECULATE_MARKERS = Set([
    "maybe", "perhaps", "possibly", "might", "could", "would",
    "probably", "likely", "unlikely", "assume", "hypothetically",
    "suppose", "imagine", "theoretically", "roughly", "approximately"
])

# GRUG: Hostile tone markers — frustration and aggression tokens
const HOSTILE_MARKERS = Set([
    "wrong", "stupid", "useless", "broken", "garbage", "terrible",
    "awful", "horrible", "idiot", "dumb", "bad", "fail", "failed",
    "trash", "ridiculous", "absurd", "pathetic"
])

# GRUG: Urgent tone markers — time pressure and critical framing tokens
const URGENT_MARKERS = Set([
    "now", "immediately", "urgent", "critical", "emergency", "asap",
    "quickly", "fast", "hurry", "instantly", "priority", "crucial",
    "vital", "important", "deadline", "must"
])

# GRUG: Reflective tone markers — hedged, thoughtful language tokens
const REFLECTIVE_MARKERS = Set([
    "interesting", "wonder", "curious", "consider", "reflect",
    "ponder", "notice", "observe", "realize", "seems", "appears",
    "suggests", "implies", "indicates"
])

# GRUG: Multi-word reflective phrase markers. These scan the full lowercased input
# string, not token-by-token. More expensive but catches compound hedges.
const REFLECTIVE_PHRASES = [
    "i think", "i believe", "it seems", "i wonder",
    "one might", "it appears", "it suggests"
]

# GRUG v7.32: FIGURATIVE DISMISS markers — language that uses math-like constructs
# as metaphors or illustrative comparisons, NOT as computation requests.
# "easy as 2+2", "simple as 1+1", "like doing basic math" — the user is
# being figurative, not asking for a calculation. These suppress sigil firing.
const FIGURATIVE_DISMISS_MARKERS = Set([
    "easy", "simple", "trivial", "obvious", "basic", "plain",
    "straightforward", "elementary", "effortless", "commonsense",
    "no-brainer", "natural", "automatic", "instinctive"
])

# GRUG v7.32: Multi-word figurative dismiss phrases. These scan the full
# lowercased input string. Catches "easy as 2+2", "simple as abc", etc.
const FIGURATIVE_DISMISS_PHRASES = [
    "easy as", "simple as", "plain as", "obvious as",
    "trivial as", "basic as", "straightforward as",
    "like doing", "like saying", "like asking",
    "no more than", "nothing more than", "just like",
    "as easy as", "as simple as", "as basic as",
    "common sense", "goes without saying", "of course",
    "basically just", "essentially just", "simply put",
    "it's just", "thats just", "that's just"
]

# ==============================================================================
# MODULATION TABLES
# GRUG: Numbers that turn prediction results into cave pre-tuning values.
# ==============================================================================

# GRUG: Arousal nudge per tone. Positive = more peripheral, Negative = more foveal.
# HOSTILE and URGENT push arousal up — the cave needs wider attention.
# REFLECTIVE and DECLARATIVE pull arousal down — narrow focus, deliberate scan.
const TONE_AROUSAL_NUDGE = Dict{ToneFamily, Float64}(
    TONE_HOSTILE     => +0.35,
    TONE_URGENT      => +0.25,
    TONE_CURIOUS     =>  0.0,
    TONE_DECLARATIVE => -0.10,
    TONE_NEUTRAL     =>  0.0,
    TONE_REFLECTIVE  => -0.15
)

# GRUG: Base confidence weight multiplier per predicted action family.
# Applied to aligned node confidence scores in scan_specimens.
# ESCALATE is highest — cave must respond fast when user is spiking.
# SPECULATE is lowest — uncertain input deserves less aggressive pre-weighting.
const ACTION_WEIGHT_TABLE = Dict{ActionFamily, Float64}(
    ACTION_ASSERT    => 1.4,
    ACTION_QUERY     => 1.6,
    ACTION_COMMAND   => 1.5,
    ACTION_NEGATE    => 1.3,
    ACTION_SPECULATE => 1.2,
    ACTION_ESCALATE  => 1.7
)

# ==============================================================================
# SOFTMAX NORMALIZATION
# GRUG: Converts raw accumulator scores into a proper probability distribution.
# This is the core length-invariance fix. A 3-word query and a 30-word query
# that express the same intent now produce similar distributions instead of
# the longer one having 10x raw score.
#
# Temperature controls sharpness:
#   T < 1.0 → sharper (winner-take-all)
#   T = 1.0 → standard softmax
#   T > 1.0 → flatter (more spread)
# Default T = 1.5 (warm — keeps minority signals alive).
# ==============================================================================

"""
    _softmax_normalize(scores::Dict{K, Float64}, temperature::Float64) -> Dict{K, Float64}

Convert raw scores into a probability distribution via temperature-scaled softmax.
Guarantees: all values in [0,1], sum ≈ 1.0. Throws on non-positive temperature.
"""
function _softmax_normalize(scores::Dict{K, Float64}, temperature::Float64) where K
    if temperature <= 0.0
        error("!!! FATAL: softmax temperature must be > 0.0, got $temperature !!!")
    end

    # GRUG: Subtract max for numerical stability (prevents exp overflow).
    max_score = maximum(values(scores))
    exp_scores = Dict{K, Float64}()
    for (k, v) in scores
        exp_scores[k] = exp((v - max_score) / temperature)
    end

    total = sum(values(exp_scores))
    if total <= 0.0 || !isfinite(total)
        # GRUG: Total is zero or NaN — fall back to uniform distribution.
        # This should never happen with proper exp() but guard against it.
        n = length(scores)
        return Dict(k => 1.0 / n for k in keys(scores))
    end

    return Dict(k => v / total for (k, v) in exp_scores)
end

# ==============================================================================
# GINI COEFFICIENT
# GRUG: The Lorenz concentration measure. Gini = 0 means perfectly uniform
# distribution (all categories equally represented). Gini = 1 means total
# concentration (one category has everything). We use this on the trajectory
# centroid to detect strange attractors.
#
# Formula: Gini = (2 * Σ(i * sorted_val)) / (n * Σ(vals)) - (n+1)/n
# This is the standard normalized Gini for a discrete distribution.
# ==============================================================================

"""
    _gini_coefficient(values::Vector{Float64}) -> Float64

Compute the Gini coefficient of a distribution. Returns 0.0 for empty/zero input.
Range: [0.0, 1.0] where 0 = uniform, 1 = total concentration.
"""
function _gini_coefficient(vals::Vector{Float64})::Float64
    n = length(vals)
    if n <= 1
        return 0.0
    end

    total = sum(vals)
    if total <= 0.0 || !isfinite(total)
        return 0.0
    end

    sorted = sort(vals)
    weighted_sum = sum(i * sorted[i] for i in 1:n)
    gini = (2.0 * weighted_sum) / (n * total) - (n + 1.0) / n
    return clamp(gini, 0.0, 1.0)
end

# ==============================================================================
# TRAJECTORY CENTROID COMPUTATION
# GRUG: The trajectory centroid is the time-weighted exponential moving average
# of all entries in the ring buffer. Recent entries weigh more. Old entries
# decay toward zero influence. The centroid represents "where has the system
# been spending its time in action-tone space?"
#
# Decay formula: weight = exp(-ln(2) * age / halflife)
#   age = 0s  → weight = 1.0
#   age = halflife → weight = 0.5
#   age = 2*halflife → weight = 0.25
# ==============================================================================

# GRUG: Internal — computes time-weighted centroid from the trajectory buffer.
# Caller must hold _trajectory_lock.
function _compute_trajectory_centroid(
    now    ::Float64,
    config ::TrajectoryConfig
)::Tuple{Dict{ActionFamily, Float64}, Dict{ToneFamily, Float64}}

    n_action = length(instances(ActionFamily))
    n_tone   = length(instances(ToneFamily))

    # GRUG: Start with zero accumulators.
    centroid_a = Dict(f => 0.0 for f in instances(ActionFamily))
    centroid_t = Dict(f => 0.0 for f in instances(ToneFamily))
    total_weight = 0.0

    ln2 = log(2.0)

    for entry in _trajectory_buffer
        age = max(now - entry.timestamp, 0.0)
        # GRUG: Exponential decay — halflife-based.
        w   = exp(-ln2 * age / config.decay_halflife)

        for (k, v) in entry.action_dist
            centroid_a[k] += v * w
        end
        for (k, v) in entry.tone_dist
            centroid_t[k] += v * w
        end
        total_weight += w
    end

    # GRUG: Normalize centroid to sum to 1.0. If total_weight is zero (all
    # entries fully decayed), return uniform distribution.
    if total_weight <= 0.0
        return (
            Dict(f => 1.0 / n_action for f in instances(ActionFamily)),
            Dict(f => 1.0 / n_tone   for f in instances(ToneFamily))
        )
    end

    for k in keys(centroid_a); centroid_a[k] /= total_weight; end
    for k in keys(centroid_t); centroid_t[k] /= total_weight; end

    return (centroid_a, centroid_t)
end

# ==============================================================================
# LORENZ DAMPING
# GRUG: When the Gini coefficient of the trajectory centroid exceeds the
# threshold, the system is locked into a strange attractor — one category
# dominates the trajectory history. Lorenz damping redistributes a fraction
# of the winning category's mass to underrepresented categories.
#
# This is NOT applied to the trajectory itself (that's historical record).
# It's applied to the CURRENT prediction's normalized distribution before
# the final winner is selected. The trajectory is the diagnostic. The damping
# is the corrective force on the present prediction.
#
# Damping formula:
#   For each category in the current distribution:
#     if category is overrepresented in trajectory (above uniform share):
#       reduce its current score by damping_strength * overshoot
#     if category is underrepresented in trajectory (below uniform share):
#       boost its current score by damping_strength * undershoot
#   Then re-normalize to sum to 1.0.
#
# This gently steers the system away from concentration while still respecting
# the current input's signal. Strong current signal overcomes damping.
# Weak current signal gets pulled toward diversity.
# ==============================================================================

"""
    _apply_lorenz_damping(current_dist, centroid, gini, config) -> (damped_dist, was_damped)

Apply Lorenz entropy-restoring damping to the current prediction distribution
if the trajectory Gini exceeds threshold. Returns the (possibly damped)
distribution and a boolean flag indicating whether damping was applied.
"""
function _apply_lorenz_damping(
    current_dist ::Dict{K, Float64},
    centroid     ::Dict{K, Float64},
    gini         ::Float64,
    config       ::TrajectoryConfig
)::Tuple{Dict{K, Float64}, Bool} where K

    # GRUG: Below threshold — no damping needed. System is exploring freely.
    if gini < config.gini_threshold
        return (current_dist, false)
    end

    n = length(current_dist)
    uniform_share = 1.0 / n
    strength = config.damping_strength

    # GRUG: Scale damping intensity by how far past the threshold we are.
    # Just barely over threshold → gentle nudge. Way over → stronger correction.
    overshoot_ratio = clamp((gini - config.gini_threshold) / (1.0 - config.gini_threshold), 0.0, 1.0)
    effective_strength = strength * overshoot_ratio

    damped = Dict{K, Float64}()
    for (k, v) in current_dist
        centroid_val = get(centroid, k, uniform_share)
        deviation = centroid_val - uniform_share

        # GRUG: If this category is OVERrepresented in trajectory history,
        # reduce its current prediction score. If UNDERrepresented, boost it.
        # The correction is proportional to the deviation * strength.
        adjustment = -deviation * effective_strength
        damped[k] = max(v + adjustment, 0.0)
    end

    # GRUG: Re-normalize after damping. Must sum to 1.0.
    total = sum(values(damped))
    if total <= 0.0 || !isfinite(total)
        # GRUG: Damping nuked everything — shouldn't happen but guard against it.
        # Fall back to original distribution.
        @warn "[PREDICTOR] Lorenz damping produced zero/NaN total — falling back to undamped distribution"
        return (current_dist, false)
    end

    for k in keys(damped); damped[k] /= total; end
    return (damped, true)
end

# ==============================================================================
# TRAJECTORY BUFFER MANAGEMENT
# ==============================================================================

# GRUG: Internal — push a new entry into the ring buffer, evicting oldest if full.
# Caller must hold _trajectory_lock.
function _push_trajectory_entry!(action_dist::Dict{ActionFamily, Float64},
                                  tone_dist::Dict{ToneFamily, Float64},
                                  ts::Float64)
    config = _trajectory_config[]
    push!(_trajectory_buffer, TrajectoryEntry(action_dist, tone_dist, ts))

    # GRUG: Ring buffer eviction — drop oldest entries beyond buffer_size.
    while length(_trajectory_buffer) > config.buffer_size
        popfirst!(_trajectory_buffer)
    end
end

# ==============================================================================
# INCOMPLETE CAUSAL CHAIN DETECTOR
# ==============================================================================

"""
    detect_incomplete_chain(tokens, all_verbs) -> (Bool, Union{String,Nothing})

Scan the last 1-2 tokens for a relational verb with no object following it.
A verb at end-of-input with only punctuation (or nothing) after it is a
dangling causal chain — the user may be mid-thought or asking the system
to complete the structure.

Returns `(true, dangling_verb)` if dangling, `(false, nothing)` otherwise.
"""
function detect_incomplete_chain(
    tokens   ::Vector{String},
    all_verbs::Set{String}
)::Tuple{Bool, Union{String, Nothing}}

    # GRUG: Need at least subject + verb to call it a chain. Single token = nothing to dangle.
    if length(tokens) < 2
        return (false, nothing)
    end

    n = length(tokens)
    for look_back in [1, 2]
        idx = n - look_back + 1
        if idx >= 1 && tokens[idx] in all_verbs
            # GRUG: Look at everything after the verb. Strip punctuation-only tokens.
            # If nothing meaningful follows, the chain is dangling.
            tail_tokens = tokens[idx+1:end]
            non_punct   = filter(t -> !occursin(r"^[,;.!?:\s]+$", t), tail_tokens)
            if isempty(non_punct)
                return (true, tokens[idx])
            end
        end
    end

    return (false, nothing)
end

# ==============================================================================
# TONAL BUILD-UP + LORENZ SNAP-BACK DYNAMICS  (v7.16+, additive on top of v7.15)
# ==============================================================================
# GRUG say: rock that get hit again and again get HOTTER. Not just same temp
#           every time. But after long quiet, rock COOL DOWN. Rock not stay
#           hot forever just because once was hit hard.
# GRUG say: tonal build-up = consecutive same-tone predictions stack arousal
#           a little each time, capped, with exponential cool-down when tone
#           changes or time passes. This makes the predictor have MOOD across
#           a conversation: someone saying angry things twice in a row is
#           ANGRIER than someone saying one angry thing cold.
# GRUG say: Lorenz snap-back = on EVERY prediction, after softmax (and after
#           any heavy damping), shake the curve a tiny bit (±envelope) and
#           then pull a fraction of the way back toward the uniform baseline.
#           This is the "jitter and snap" property: identical inputs never
#           produce bit-identical curves, AND the curve never stays maximally
#           sharp because there's always a small entropy-restoring tug back
#           toward uniform every call. Build-up changes the *score*; snap-back
#           changes the *shape*. They are independent.
# GRUG say: NO NaN. NO INF. NO SILENT FAILURE. All clamped, all bounded,
#           all return-on-error to the previous-good distribution.
#
# Why this is separate from the trajectory buffer:
#   - Trajectory buffer is a 16-deep ring with 120s halflife. It is for
#     LONG-HORIZON attractor avoidance. It triggers Lorenz damping only when
#     gini > 0.72 (a strong concentration signal across many turns).
#   - Build-up + snap-back is PER-PREDICTION. It runs every call, cheaply,
#     and shapes the immediate arousal/curve regardless of trajectory state.
#   - They are complementary, not redundant. Build-up gives the system
#     short-term mood. Trajectory damping prevents long-term lock-in.
#     Snap-back provides bounded per-call entropy + jitter texture.
# ==============================================================================

# GRUG: Build-up envelope. Each consecutive same-tone prediction adds this
# fraction of (1.0 - current_buildup) to the buildup accumulator. Saturates
# toward 1.0 but never reaches it. 0.20 means after 1 hit you're at 0.20,
# after 2 you're at 0.36, after 3 you're at 0.488, ... reaching ~0.8 at hit 7.
const TONAL_BUILDUP_INCREMENT = 0.20

# GRUG: Cool-down halflife in seconds. After this many seconds with no
# matching tone, build-up loses half its value. 30s ≈ a slow paragraph;
# enough to carry mood across a multi-turn provocation, short enough that
# leaving the convo and coming back resets effectively.
const TONAL_BUILDUP_HALFLIFE_S = 30.0

# GRUG: How much build-up bleeds into arousal_nudge. The base nudge from
# TONE_AROUSAL_NUDGE is a small signed scalar like -0.10..+0.15. Build-up
# multiplies that signal by (1 + BUILDUP_AROUSAL_GAIN * buildup), so a fully
# built-up tone pushes arousal up to ~1.6× the cold nudge. Conservative on
# purpose — we shape, we don't overpower.
const TONAL_BUILDUP_AROUSAL_GAIN = 0.6

# GRUG: Snap-back jitter envelope. Per-family multiplicative noise applied to
# the post-damping distribution before the snap pull. ±2.5% per family — small
# enough that a clear winner stays the winner; loud enough that no two curves
# are identical. (The matching constant in v7.21a/main is 0.03; we go slightly
# tighter here because we ALSO do a snap pull after, and combined effect must
# stay bounded.)
const LORENZ_SNAPBACK_JITTER = 0.025

# GRUG: Snap-back pull fraction. After jitter, every family is pulled this
# fraction of the way toward the uniform 1/N baseline. 0.05 is a 5% tug —
# the curve still has a clear winner, but the entropy floor is enforced
# every call. This is the per-prediction analog of the long-horizon Lorenz
# damper: small, always-on, no Gini threshold, no history.
const LORENZ_SNAPBACK_PULL = 0.05

# GRUG: Single-slot tonal build-up state. NOT a buffer. Just "what mood
# am I in right now, and when did I last update?". One-tone memory.
const _TONAL_BUILDUP = Ref{NamedTuple{
    (:tone, :buildup, :ts),
    Tuple{Union{Nothing, ToneFamily}, Float64, Float64}
}}((tone = nothing, buildup = 0.0, ts = 0.0))
const _TONAL_BUILDUP_LOCK = ReentrantLock()

"""
    reset_tonal_buildup!()

GRUG: Wipe the build-up accumulator. Called on cave wipe and by tests to
guarantee a clean slate. Does NOT touch the trajectory buffer or config.
"""
function reset_tonal_buildup!()
    lock(_TONAL_BUILDUP_LOCK) do
        _TONAL_BUILDUP[] = (tone = nothing, buildup = 0.0, ts = 0.0)
    end
    return nothing
end

"""
    get_tonal_buildup() -> NamedTuple

GRUG: Read-only snapshot of the build-up state. Returns
`(tone, buildup, ts)`. `tone === nothing` means "no prior observation".
`buildup` is in [0.0, 1.0]. Useful for tests and diagnostics.
"""
function get_tonal_buildup()
    lock(_TONAL_BUILDUP_LOCK) do
        _TONAL_BUILDUP[]
    end
end

"""
    serialize_tonal_buildup() -> Dict{String,Any}

GRUG: Snapshot the single-slot tonal-build-up accumulator for persistence.
`tone === nothing` is encoded as the empty string `""`. JSON-friendly.
"""
function serialize_tonal_buildup()::Dict{String, Any}
    snap = get_tonal_buildup()
    tone_str = snap.tone === nothing ? "" : String(Symbol(snap.tone))
    return Dict{String, Any}(
        "tone"    => tone_str,
        "buildup" => snap.buildup,
        "ts"      => snap.ts,
    )
end

"""
    restore_tonal_buildup!(data::AbstractDict) -> Bool

GRUG: Replace the single-slot tonal build-up state from a snapshot.
Tolerant of missing keys (defaults: tone=nothing, buildup=0.0, ts=0.0).
Returns true on a clean restore. Unknown tone strings round-trip as
`nothing` --- safer than failing the whole load.
"""
function restore_tonal_buildup!(data::AbstractDict)::Bool
    tone_raw = String(get(data, "tone", ""))
    tone_val::Union{Nothing, ToneFamily} = nothing
    if !isempty(tone_raw)
        sym = Symbol(tone_raw)
        # GRUG: @enum doesn't have a Symbol constructor in stock Julia. Walk
        # `instances(ToneFamily)` and string-match. Bounded (6 variants) and
        # safe --- unknown tone strings round-trip as nothing.
        for tf in instances(ToneFamily)
            if Symbol(tf) === sym
                tone_val = tf
                break
            end
        end
    end
    buildup = clamp(Float64(get(data, "buildup", 0.0)), 0.0, 1.0)
    ts      = Float64(get(data, "ts", 0.0))
    lock(_TONAL_BUILDUP_LOCK) do
        _TONAL_BUILDUP[] = (tone = tone_val, buildup = buildup, ts = ts)
    end
    return true
end

# GRUG: Update the build-up accumulator given the predicted tone for THIS
# call. Returns the new buildup value. Internal — predict_action_tone is
# the only caller. Cool-down is applied first (decay against time), THEN
# the increment if tone matches the previous, OR the buildup is reset
# (with the same decay first) if tone changed.
function _update_tonal_buildup!(predicted_tone::ToneFamily, now::Float64)::Float64
    lock(_TONAL_BUILDUP_LOCK) do
        prev = _TONAL_BUILDUP[]

        # GRUG: First call ever — seed with a tiny non-zero so a single
        # provocation isn't completely flat in the curve, but well below
        # the second-hit value. 0.05 ≈ a quarter of the first increment.
        if prev.tone === nothing
            new_state = (tone = predicted_tone, buildup = 0.05, ts = now)
            _TONAL_BUILDUP[] = new_state
            return new_state.buildup
        end

        # GRUG: Exponential cool-down based on age, ALWAYS applied first.
        # decayed = old_buildup * 2^(-age / halflife)
        age = max(0.0, now - prev.ts)
        decay = exp(-log(2.0) * age / TONAL_BUILDUP_HALFLIFE_S)
        cooled = prev.buildup * decay

        if predicted_tone == prev.tone
            # GRUG: Same tone — stack on top of the cooled value.
            #   new = cooled + increment * (1 - cooled)
            # This is the saturating-toward-1.0 form. Cap at 0.95 to keep
            # arousal_nudge bounded (gain × 0.95 ≈ 0.57 multiplier headroom).
            new_buildup = clamp(cooled + TONAL_BUILDUP_INCREMENT * (1.0 - cooled), 0.0, 0.95)
            new_state = (tone = predicted_tone, buildup = new_buildup, ts = now)
            _TONAL_BUILDUP[] = new_state
            return new_buildup
        else
            # GRUG: Tone changed — keep the cooled remnant but seed the new
            # tone fresh. The cooled value of the OLD tone is dropped
            # (it doesn't transfer to a different mood) and the new tone
            # starts at the seed value. This is the "snap back" for mood:
            # mood doesn't carry across a tone shift.
            new_state = (tone = predicted_tone, buildup = 0.05, ts = now)
            _TONAL_BUILDUP[] = new_state
            return new_state.buildup
        end
    end
end

# GRUG: Apply Lorenz snap-back to a probability distribution IN PLACE.
# 1. Multiplicative jitter per family: x *= (1 + ε), ε ∈ U[-env, +env].
# 2. Pull every family `pull` of the way toward uniform: x = (1-pull)*x + pull/N.
# 3. Renormalize so values sum to 1.0.
# The effect: identical inputs never produce identical curves (jitter), AND
# the curve always has a small per-call entropy tug toward uniform (snap).
# Bounded, fast, idempotent in expectation.
function _lorenz_snapback!(
    dist     ::Dict{K, Float64};
    envelope ::Float64 = LORENZ_SNAPBACK_JITTER,
    pull     ::Float64 = LORENZ_SNAPBACK_PULL,
) where K
    n = length(dist)
    if n == 0
        return dist
    end
    if envelope < 0.0 || pull < 0.0 || pull > 1.0
        # GRUG: Caller misuse — refuse silently-bad input loudly.
        error("!!! FATAL: _lorenz_snapback! got out-of-range envelope=$envelope or pull=$pull !!!")
    end

    uniform = 1.0 / n

    # GRUG: Step 1 — jitter. Multiplicative, clamped non-negative.
    if envelope > 0.0
        for (k, v) in dist
            ε = (rand() * 2.0 - 1.0) * envelope
            dist[k] = max(0.0, v * (1.0 + ε))
        end
    end

    # GRUG: Step 2 — pull each family toward uniform.
    if pull > 0.0
        one_minus_pull = 1.0 - pull
        for (k, v) in dist
            dist[k] = one_minus_pull * v + pull * uniform
        end
    end

    # GRUG: Step 3 — renormalize. If degenerate (shouldn't happen with
    # bounded jitter + non-negative pull), fall back to uniform.
    total = sum(values(dist))
    if !isfinite(total) || total <= 0.0
        for k in keys(dist)
            dist[k] = uniform
        end
        return dist
    end
    for k in keys(dist)
        dist[k] /= total
    end
    return dist
end



"""
    predict_action_tone(input_text, all_verbs) -> PredictionResult

Main entry point. Scores input text against all action and tone lexicons,
normalizes scores via temperature-scaled softmax into proper probability
distributions, applies Lorenz trajectory damping if the system is locked
into a strange attractor, detects incomplete causal chains, and returns a
`PredictionResult` carrying the predicted action family, tone family,
confidence, arousal nudge, confidence weight multiplier, and the full
normalized distributions.

`all_verbs` should come from `SemanticVerbs.get_all_verbs()` so the live
runtime verb registry is used for chain detection.

This function is thread-safe. Trajectory state is updated atomically under
a ReentrantLock.

Callers apply the results via `apply_prediction_to_arousal!` and
`get_action_weight_multiplier`.
"""
function predict_action_tone(
    input_text::String,
    all_verbs ::Set{String}
)::PredictionResult

    if isempty(strip(input_text))
        error("!!! FATAL: ActionTonePredictor cannot predict on empty input! !!!")
    end

    tokens_raw   = split(strip(input_text))
    tokens_low   = [lowercase(t) for t in tokens_raw]

    # GRUG: Strip trailing punctuation from tokens for clean lexicon lookup.
    # "wrong!" should hit HOSTILE_MARKERS. "what?" should hit QUERY_MARKERS.
    tokens_clean = [replace(t, r"[,;.!?:]+" => "") for t in tokens_low]
    tokens_clean = filter(!isempty, tokens_clean)

    if isempty(tokens_clean)
        error("!!! FATAL: ActionTonePredictor: all tokens vanished after punctuation strip! !!!")
    end

    # ------------------------------------------------------------------
    # STEP 1: Score action families (raw accumulation — same as before)
    # ------------------------------------------------------------------
    action_scores = Dict{ActionFamily, Float64}(
        ACTION_ASSERT    => 0.0,
        ACTION_QUERY     => 0.0,
        ACTION_COMMAND   => 0.0,
        ACTION_NEGATE    => 0.0,
        ACTION_SPECULATE => 0.0,
        ACTION_ESCALATE  => 0.0
    )

    # GRUG: "?" is the strongest query signal. Check raw input, not tokens.
    if contains(input_text, "?")
        action_scores[ACTION_QUERY] += 1.5
    end

    # GRUG: ALL CAPS words (3+ chars, starts with letter) = escalation signal.
    caps_words = count(
        t -> length(t) >= 3 && t == uppercase(t) && isletter(t[1]),
        tokens_raw
    )
    if caps_words > 0
        action_scores[ACTION_ESCALATE] += Float64(caps_words) * 0.8
    end

    # GRUG: Each exclamation mark adds escalation weight.
    excl_count = count(c -> c == '!', input_text)
    if excl_count > 0
        action_scores[ACTION_ESCALATE] += Float64(excl_count) * 0.5
    end

    # GRUG v7.32: FIGURATIVE DISMISS SCORING — language that wraps math/action
    # constructs in dismissive comparisons ("easy as 2+2", "simple as 1+1").
    # This is NOT a computation request — it's a metaphor. We score it into
    # ACTION_NEGATE (the user is negating the literal interpretation) with a
    # separate figurative_dismiss flag so the pre-vote gate can distinguish
    # "don't calculate" (explicit negation) from "easy as 2+2" (figurative dismiss).
    figurative_score = 0.0
    input_low = lowercase(input_text)
    for tok in tokens_clean
        if tok in FIGURATIVE_DISMISS_MARKERS
            figurative_score += 1.0
        end
    end
    for phrase in FIGURATIVE_DISMISS_PHRASES
        if contains(input_low, phrase)
            figurative_score += 1.5  # phrases are stronger signal than single words
        end
    end
    if figurative_score > 0.0
        action_scores[ACTION_NEGATE] += figurative_score * 0.7
    end

    # GRUG: Per-token lexicon scoring.
    for tok in tokens_clean
        tok in QUERY_MARKERS     && (action_scores[ACTION_QUERY]     += 1.0)
        tok in COMMAND_MARKERS   && (action_scores[ACTION_COMMAND]   += 1.0)
        tok in NEGATE_MARKERS    && (action_scores[ACTION_NEGATE]    += 1.0)
        tok in SPECULATE_MARKERS && (action_scores[ACTION_SPECULATE] += 1.0)
    end

    # GRUG: First token is a command marker = strong imperative signal.
    if !isempty(tokens_clean) && tokens_clean[1] in COMMAND_MARKERS
        action_scores[ACTION_COMMAND] += 0.8
    end

    # GRUG: If no action signal found at all, default to ASSERT.
    total_action_signal = sum(values(action_scores))
    if total_action_signal < 0.5
        action_scores[ACTION_ASSERT] += 1.0
    end

    # ------------------------------------------------------------------
    # STEP 2: Score tone families (raw accumulation — same as before)
    # ------------------------------------------------------------------
    tone_scores = Dict{ToneFamily, Float64}(
        TONE_HOSTILE     => 0.0,
        TONE_CURIOUS     => 0.0,
        TONE_DECLARATIVE => 0.0,
        TONE_URGENT      => 0.0,
        TONE_NEUTRAL     => 0.0,
        TONE_REFLECTIVE  => 0.0
    )

    for tok in tokens_clean
        tok in HOSTILE_MARKERS   && (tone_scores[TONE_HOSTILE]    += 1.0)
        tok in URGENT_MARKERS    && (tone_scores[TONE_URGENT]     += 1.0)
        tok in SPECULATE_MARKERS && (tone_scores[TONE_REFLECTIVE] += 0.6)
        tok in QUERY_MARKERS     && (tone_scores[TONE_CURIOUS]    += 0.7)
        tok in REFLECTIVE_MARKERS && (tone_scores[TONE_REFLECTIVE] += 0.5)
    end

    if caps_words >= 2
        tone_scores[TONE_HOSTILE] += 0.5
        tone_scores[TONE_URGENT]  += 0.5
    end

    input_low = lowercase(input_text)
    for phrase in REFLECTIVE_PHRASES
        if contains(input_low, phrase)
            tone_scores[TONE_REFLECTIVE] += 0.8
        end
    end

    if action_scores[ACTION_QUERY] > 0.5 && tone_scores[TONE_HOSTILE] < 0.5
        tone_scores[TONE_CURIOUS] += 0.6
    end

    # GRUG: No strong tone signal? Default to NEUTRAL.
    total_tone_signal = sum(values(tone_scores))
    if total_tone_signal < 0.4
        tone_scores[TONE_NEUTRAL] += 1.0
    end

    # ------------------------------------------------------------------
    # STEP 3: Softmax normalization — raw scores → probability distributions
    # GRUG: This is the length-invariance fix. A 3-word and a 30-word query
    # expressing the same intent now produce similar distributions.
    # ------------------------------------------------------------------
    config = lock(_trajectory_lock) do
        _trajectory_config[]
    end

    action_dist = _softmax_normalize(action_scores, config.softmax_temperature)
    tone_dist   = _softmax_normalize(tone_scores,   config.softmax_temperature)

    # ------------------------------------------------------------------
    # STEP 4: Trajectory damping — Lorenz attractor avoidance
    # GRUG: Check the trajectory centroid's Gini coefficient. If the system
    # has been locked into one action/tone family, apply entropy-restoring
    # damping to the CURRENT prediction (not the history).
    # ------------------------------------------------------------------
    trajectory_damped = false

    lock(_trajectory_lock) do
        now = time()

        if !isempty(_trajectory_buffer)
            centroid_a, centroid_t = _compute_trajectory_centroid(now, config)
            gini_a = _gini_coefficient(collect(values(centroid_a)))
            gini_t = _gini_coefficient(collect(values(centroid_t)))

            # GRUG: Damp action distribution if action trajectory is concentrated.
            action_dist_new, damped_a = _apply_lorenz_damping(action_dist, centroid_a, gini_a, config)
            if damped_a
                for (k, v) in action_dist_new; action_dist[k] = v; end
            end

            # GRUG: Damp tone distribution if tone trajectory is concentrated.
            tone_dist_new, damped_t = _apply_lorenz_damping(tone_dist, centroid_t, gini_t, config)
            if damped_t
                for (k, v) in tone_dist_new; tone_dist[k] = v; end
            end

            trajectory_damped = damped_a || damped_t

            if trajectory_damped
                @info "[PREDICTOR] 🌀 Lorenz damping active — " *
                      "action_gini=$(round(gini_a, digits=3)), " *
                      "tone_gini=$(round(gini_t, digits=3))"
            end
        end

        # GRUG: Record this prediction in the trajectory buffer (post-damping).
        # We record the damped distribution because that's what the system actually used.
        _push_trajectory_entry!(copy(action_dist), copy(tone_dist), now)
    end

    # ------------------------------------------------------------------
    # STEP 4.5: LORENZ SNAP-BACK (per-prediction jitter + entropy tug)
    # GRUG: Always-on, bounded micro-perturbation. Identical inputs never
    # produce bit-identical curves, AND the curve gets a tiny entropy
    # restoration on every call — independent of the long-horizon
    # trajectory damper above. This is the "slight jitter and snap back
    # every time" property: it runs whether or not Step 4 fired.
    # ------------------------------------------------------------------
    _lorenz_snapback!(action_dist)
    _lorenz_snapback!(tone_dist)

    # ------------------------------------------------------------------
    # STEP 5: Pick winners from (possibly damped) normalized distributions
    # ------------------------------------------------------------------
    predicted_action = argmax(action_dist)
    predicted_tone   = argmax(tone_dist)

    # GRUG: Confidence = margin between winner and runner-up in the normalized
    # distribution. High margin = clear signal. Low margin = ambiguous.
    # This is more meaningful than raw score ratio because it's bounded [0,1]
    # and reflects how much the winner stands out after normalization.
    action_vals  = sort(collect(values(action_dist)), rev=true)
    action_confidence = length(action_vals) >= 2 ?
        clamp(action_vals[1] - action_vals[2], 0.05, 1.0) :
        clamp(action_vals[1], 0.05, 1.0)

    # GRUG: Scale confidence so that even a modest margin gives usable weight.
    # Raw margin between softmax values is often small (0.1-0.3). Scale by 2.5
    # to get a useful [0.05, 1.0] confidence range.
    action_confidence = clamp(action_confidence * 2.5, 0.05, 1.0)

    # ------------------------------------------------------------------
    # STEP 6: Incomplete causal chain detection
    # ------------------------------------------------------------------
    is_dangling, dangling_verb = detect_incomplete_chain(tokens_clean, all_verbs)

    # GRUG: Dangling verb = user left a thought incomplete. Nudge toward SPECULATE
    # by boosting its probability in the action distribution.
    if is_dangling
        speculate_boost = 0.15  # Direct probability boost
        action_dist[ACTION_SPECULATE] = get(action_dist, ACTION_SPECULATE, 0.0) + speculate_boost
        # Re-normalize after boost
        total_a = sum(values(action_dist))
        if total_a > 0.0
            for k in keys(action_dist); action_dist[k] /= total_a; end
        end

        new_action = argmax(action_dist)
        if new_action != predicted_action &&
           action_dist[new_action] >= action_dist[predicted_action] + 0.05
            predicted_action = new_action
        end
    end

    # ------------------------------------------------------------------
    # STEP 7: Compute arousal nudge
    # ------------------------------------------------------------------
    arousal_nudge = get(TONE_AROUSAL_NUDGE, predicted_tone, 0.0)

    # GRUG: ESCALATE action adds extra arousal push regardless of tone.
    if predicted_action == ACTION_ESCALATE
        arousal_nudge = clamp(arousal_nudge + 0.20, -1.0, 1.0)
    end

    # ------------------------------------------------------------------
    # STEP 7.5: TONAL BUILD-UP (consecutive same-tone arousal escalation)
    # GRUG: Update the single-slot build-up state for THIS predicted tone,
    # then multiply the cold arousal nudge by (1 + GAIN * buildup). Same
    # tone twice in a row gets stronger; tone change resets and the new
    # tone starts cold; long quiet decays the prior build-up exponentially
    # (TONAL_BUILDUP_HALFLIFE_S). Sign of the nudge is preserved — if the
    # cold nudge was negative (e.g. REFLECTIVE), build-up makes it MORE
    # negative; if positive (URGENT/HOSTILE), MORE positive.
    # ------------------------------------------------------------------
    let buildup = _update_tonal_buildup!(predicted_tone, time())
        gain_factor = 1.0 + TONAL_BUILDUP_AROUSAL_GAIN * buildup
        arousal_nudge = clamp(arousal_nudge * gain_factor, -1.0, 1.0)
    end

    # ------------------------------------------------------------------
    # STEP 8: Compute confidence weight multiplier
    # ------------------------------------------------------------------
    base_weight   = get(ACTION_WEIGHT_TABLE, predicted_action, 1.0)

    # GRUG: Scale weight by confidence. Low confidence = stay near 1.0 (minimal skew).
    scaled_weight = 1.0 + (base_weight - 1.0) * action_confidence

    return PredictionResult(
        predicted_action,
        predicted_tone,
        action_confidence,
        is_dangling,
        dangling_verb,
        arousal_nudge,
        scaled_weight,
        time(),
        action_dist,
        tone_dist,
        trajectory_damped,
        figurative_score > 0.0,           # GRUG v7.32: figurative_dismiss flag
        get(action_scores, ACTION_NEGATE, 0.0)  # GRUG v7.32: raw negation signal magnitude
    )
end

# ==============================================================================
# INTEGRATION HELPERS
# ==============================================================================

"""
    apply_prediction_to_arousal!(prediction, get_arousal_fn, set_arousal_fn!)

Apply the prediction's `arousal_nudge` to the EyeSystem by calling the provided
getter and setter function handles. Caller passes the functions — this module
stays decoupled from EyeSystem and can be tested independently.

No-ops if `arousal_nudge == 0.0` to avoid a pointless EyeSystem write.
Clamps the result to [0.0, 1.0] before setting.
"""
function apply_prediction_to_arousal!(
    prediction     ::PredictionResult,
    get_arousal_fn ::Function,
    set_arousal_fn!::Function
)
    # GRUG: Zero nudge = skip the write. Don't touch EyeSystem for nothing.
    if prediction.arousal_nudge == 0.0
        return
    end

    current = get_arousal_fn()
    new_val = clamp(current + prediction.arousal_nudge, 0.0, 1.0)
    set_arousal_fn!(new_val)

    @info "[PREDICTOR] 👁  Arousal nudged $(round(current, digits=3)) → " *
          "$(round(new_val, digits=3)) ($(prediction.tone_family))"
end

"""
    get_action_weight_multiplier(prediction, node_action_name) -> Float64

Given a `PredictionResult` and a node's winning action name string, return
the confidence multiplier to apply to that node's scan confidence score.

- If node action aligns with predicted family: returns `prediction.action_weight` (> 1.0)
- If node action does NOT align: returns suppression factor (< 1.0, scales with confidence)
- If prediction confidence < 0.3: returns 1.0 (no modulation — prediction too weak)

Alignment is keyword-based: the node's action name is checked for substrings
associated with each action family (e.g. "query", "answer", "respond" for ACTION_QUERY).
"""
function get_action_weight_multiplier(
    prediction      ::PredictionResult,
    node_action_name::String
)::Float64

    # GRUG: Weak prediction = don't skew anything. Let the cave scan naturally.
    if prediction.confidence < 0.3
        return 1.0
    end

    # GRUG: Empty action name = unknown action. No alignment possible. No suppression either.
    action_low = lowercase(strip(node_action_name))
    if isempty(action_low)
        return 1.0
    end

    aligned = _action_name_aligns(action_low, prediction.action_family)

    if aligned
        return prediction.action_weight
    else
        # GRUG: Misaligned node gets gentle suppression. Not a hard block —
        # just a probabilistic lean. Low-confidence predictions suppress less.
        return 0.85 + (0.15 * (1.0 - prediction.confidence))
    end
end

# GRUG: Internal keyword alignment check — does this action name sound like the
# predicted action family? Substring match on known keywords per family.
function _action_name_aligns(action_name::String, family::ActionFamily)::Bool
    if family == ACTION_QUERY
        return any(kw -> contains(action_name, kw),
                   ["query", "answer", "respond", "explain", "describe", "tell", "info"])
    elseif family == ACTION_COMMAND
        return any(kw -> contains(action_name, kw),
                   ["execute", "run", "do", "action", "command", "perform", "trigger"])
    elseif family == ACTION_NEGATE
        return any(kw -> contains(action_name, kw),
                   ["negate", "deny", "reject", "contra", "refute", "wrong"])
    elseif family == ACTION_ASSERT
        return any(kw -> contains(action_name, kw),
                   ["assert", "state", "declare", "confirm", "affirm", "say"])
    elseif family == ACTION_SPECULATE
        return any(kw -> contains(action_name, kw),
                   ["speculate", "predict", "infer", "hypothe", "guess", "maybe"])
    elseif family == ACTION_ESCALATE
        return any(kw -> contains(action_name, kw),
                   ["alert", "warn", "escalate", "urgent", "critical", "flag"])
    end
    return false
end

"""
    format_prediction_summary(prediction) -> String

Return a compact human-readable summary of a `PredictionResult`.
Used by `/status`, debug logging, and the `@info` line in `scan_specimens`.
Now includes trajectory damping status.
"""
function format_prediction_summary(prediction::PredictionResult)::String
    chain_str = prediction.incomplete_chain ?
        " [dangling: '$(prediction.dangling_verb)']" : ""
    damp_str  = prediction.trajectory_damped ? " [LORENZ-DAMPED]" : ""
    return "Action=$(prediction.action_family) | " *
           "Tone=$(prediction.tone_family) | " *
           "Conf=$(round(prediction.confidence, digits=2)) | " *
           "ArousalNudge=$(round(prediction.arousal_nudge, digits=2)) | " *
           "Weight=$(round(prediction.action_weight, digits=2))$(chain_str)$(damp_str)"
end

end # module ActionTonePredictor

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: ACTION+TONE PREDICTION LAYER
#
# 1. PRE-VOTE MODULATION ARCHITECTURE:
# The predictor fires before scan_specimens assembles its vote pool.
# It does not vote, does not create nodes, and does not modify global state
# (except trajectory buffer, which is internal to this module).
# Its two outputs — arousal_nudge and action_weight — are applied by callers:
#   - arousal_nudge: applied in process_mission() via apply_prediction_to_arousal!()
#   - action_weight: applied per-node inside scan_specimens() via
#     get_action_weight_multiplier()
# If the predictor throws for any reason, both callers catch the error, log a
# @warn, and continue with unmodulated behavior. The cave always scans.
#
# 2. ACTION FAMILY SCORING:
# Each action family accumulates a float score from multiple signal sources:
# lexicon token matches, structural signals (first-token imperative, "?"),
# and surface signals (ALL CAPS count, exclamation count). The family with the
# highest score wins. Confidence is the winning score divided by total signal
# magnitude, clamped to [0.1, 1.0]. Default fallback is ACTION_ASSERT when
# total signal is below 0.5.
#
# 3. SOFTMAX NORMALIZATION (NEW):
# Raw accumulated scores are converted into proper probability distributions
# via temperature-scaled softmax. This provides length invariance: a 3-word
# and a 30-word input expressing the same intent produce similar distributions.
# Temperature (default 1.5) controls sharpness — warm enough to keep minority
# signals alive, sharp enough to let clear winners dominate.
#
# 4. TRAJECTORY MEMORY & LORENZ DAMPING (NEW):
# A ring buffer of the last N (default 16) normalized prediction distributions
# tracks the system's path through action-tone space. Each entry decays
# exponentially by age (default halflife 120s). The trajectory centroid
# (time-weighted EMA) is monitored via Gini coefficient:
#   - Gini < threshold (0.72): system is exploring normally, no damping
#   - Gini >= threshold: strange attractor detected — one category dominates
#     the trajectory. Lorenz damping redistributes mass from overrepresented
#     to underrepresented categories in the CURRENT prediction (not history).
# This prevents the system from locking into a single action/tone family
# indefinitely, which is the discrete analog of Lorenz curve wealth
# redistribution to avoid chaotic concentration.
#
# 5. TONE FAMILY SCORING:
# Tone scoring follows the same accumulation + softmax normalization pattern
# but is evaluated independently from action scoring. This allows cross-
# classification: e.g., ACTION_COMMAND with TONE_HOSTILE, or ACTION_QUERY
# with TONE_REFLECTIVE. Multi-word phrase markers scan the full lowercased
# input string for reflective hedges that can't be detected token-by-token.
#
# 6. INCOMPLETE CAUSAL CHAIN DETECTION:
# A dangling chain is defined as a relational verb appearing in the last 1-2
# token positions of the input with no meaningful object token following it.
# Detection uses the live verb set from SemanticVerbs so runtime verb additions
# are immediately included. Dangling chains nudge SPECULATE probability in the
# normalized distribution rather than manipulating raw scores.
#
# 7. CONFIDENCE COMPUTATION (UPDATED):
# Confidence is now derived from the margin between the winner and runner-up
# in the normalized probability distribution. This is more meaningful than raw
# score ratio because it reflects how much the winner stands out after
# normalization and (potential) trajectory damping.
#
# 8. CONFIDENCE WEIGHT SCALING:
# Action weight multipliers from ACTION_WEIGHT_TABLE represent the maximum boost
# at full prediction confidence. The actual applied weight is linearly
# interpolated between 1.0 (zero confidence) and the table value (full confidence).
# Low-confidence predictions produce minimal modulation.
#
# 9. DECOUPLING FROM EYESYSTEM:
# apply_prediction_to_arousal!() accepts EyeSystem's get/set functions as
# parameters rather than importing EyeSystem directly. This keeps ActionTonePredictor
# independently testable and prevents circular module dependencies.
#
# 10. THREAD SAFETY:
# All trajectory state access is guarded by a ReentrantLock. Predictions can
# safely fire from multiple tasks concurrently without corrupting the buffer.
# ==============================================================================