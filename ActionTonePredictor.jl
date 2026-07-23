# ActionTonePredictor.jl
# ==============================================================================
# GRUG: This is the reflex prediction cave. Fires BEFORE the vote pool assembles.
#
# v8.22 — LAZY CONSERVATIVE REBASING. Old ATP was too eager: every tone
# nudged arousal, every action family boosted aligned nodes (1.2–1.7x),
# and suppression of misaligned nodes was aggressive (0.85x floor).
# The result: ATP ALWAYS skewed the vote pool, even for calm inputs where
# the cave should just scan normally. New philosophy: DON'T MODULATE
# UNLESS THERE'S URGENCY. Non-urgent families get weight=1.0 (no boost),
# non-urgent tones get arousal_nudge=0.0 (no push), the confidence gate
# for modulation is raised from 0.3 to 0.5, misaligned suppression is
# gentler (0.92x floor), and escalation requires 0.7 confidence (up from
# 0.6). The cave should trust its own scan over ATP's guess unless ATP
# is genuinely confident and the input is genuinely urgent.
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

using Random
using Base.Threads: ReentrantLock

export ActionFamily, ToneFamily, PredictionResult,
       predict_action_tone, apply_prediction_to_arousal!,
       get_action_weight_multiplier, format_prediction_summary,
       reset_trajectory!, get_trajectory_state, TrajectoryConfig,
       LAST_PREDICTION,
       get_last_prediction, get_last_escalation_trace,
       # GRUG v7.20: heavy-fallback classifier surface
       LOW_SIGNAL_THRESHOLD, FALLBACK_DAMP_THRESHOLD,
       get_predictor_telemetry, reset_predictor_telemetry!,
       # GRUG v7.23: ATP→automaton escalation hook
       maybe_escalate, ESCALATION_FAMILIES, LAST_ESCALATION_TRACE

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
    # GRUG v7.20: Which classifier path produced this result.
    #   :lexicon  → keyword/marker lexicon (the default path; cheap and accurate
    #              when the input contains explicit family markers).
    #   :fallback → character-bigram fingerprint scoring (heavier; activated
    #              when the lexicon shrugs because the input is a fragment,
    #              jargon, or otherwise marker-poor). Pure Julia, no LLM.
    # Why not a Bool? More modes may follow (e.g. :embedding, :phonetic);
    # Symbol keeps the field future-proof and self-documenting in logs.
    mode             ::Symbol
    # GRUG v7.21b-1: Emotional coherence — how well does the chosen action
    # match the chosen tone's prior tilt? This is the OBSERVATION half of
    # the predict/observe pair. v7.21a put tone first so it could TILT the
    # action. v7.21b-1 measures the result of that tilt and surfaces it.
    #   1.0 → action is in tone's primary tilt set (e.g. HOSTILE+NEGATE)
    #   0.5 → tone has no prior for this action (NEUTRAL or unmapped pair)
    #   0.0 → action OPPOSES the tone's primary tilt (e.g. HOSTILE+welcome)
    # b-1 is observation-only: this field is computed and logged as
    # [INCOHERENT] when low, but does NOT modify prediction behavior.
    # b-2 will read the running observation state and let it influence
    # the next prediction's jitter envelope.
    emotional_coherence ::Float64
end

# GRUG: Last prediction stash. Set by predict_action_tone after a successful
# prediction so downstream consumers (vote orchestrator's matching-dimension
# scorer) can read the same prediction without re-running classification.
# Cleared to nothing on module init; never NaN'd in place — a fresh Ref each
# call keeps the read race-free without a lock.
const LAST_PREDICTION = Ref{Union{Nothing, PredictionResult}}(nothing)

# GRUG v10: Lock guarding LAST_PREDICTION, _TONAL_OBSERVATION,
# PREDICTOR_TELEMETRY, and LAST_ESCALATION_TRACE. These are read/written
# from the main cycle and from diagnostic readers without synchronization.
const _STATE_LOCK = ReentrantLock()

# ==============================================================================
# v7.21b-1: TONAL OBSERVATION RUNNING STATE (observation-only)
# ==============================================================================
# GRUG: This is the OBSERVATION half of the predict/observe pair.
#
# Unlike the trajectory buffer (which v7.21a killed for prediction purposes),
# this is a SINGLE-SLOT running state — what state am I currently in? — not
# a session-spanning history. It is updated AFTER each prediction completes
# and read at the START of the next prediction. Decay is fast (~5s halflife)
# so a fresh conversation starts effectively-clean.
#
# In v7.21b-1 this state is OBSERVATION ONLY:
#   - written by predict_action_tone at the end (after PredictionResult built)
#   - read by get_tonal_observation() for diagnostics and logging
#   - NOT read by the prediction logic itself (that comes in b-2)
#
# The point of b-1 is to make incoherence VISIBLE before we let it act.
# We need to see "[INCOHERENT]" tags fire in a kitchen sink run before
# we wire the running state into the jitter-envelope computation.
const _TONAL_OBSERVATION = Ref{NamedTuple{
    (:last_tone, :last_action, :last_arousal, :last_emotional_coherence, :ts),
    Tuple{ToneFamily, ActionFamily, Float64, Float64, Float64}
}}((
    last_tone = TONE_NEUTRAL,
    last_action = ACTION_ASSERT,
    last_arousal = 0.0,
    last_emotional_coherence = 0.5,
    ts = 0.0
))

# GRUG v7.21b-1: Coherence threshold below which the [INCOHERENT] tag fires.
# Conservative starting value — only flag clear mismatches (action opposes
# tone's tilt). 0.5 is "no prior either way" so we DON'T flag those —
# only flag when coherence is meaningfully below neutral.
const INCOHERENCE_TAG_THRESHOLD = 0.4

# GRUG v7.21b-1: Compute emotional coherence between an action and a tone.
# This is the load-bearing measurement: how well does the chosen action
# match what the tone's prior would have wanted?
#
# Reads TONE_ACTION_PRIOR (the same table that tilts action scoring during
# prediction) and asks: "is the winner in the tilt set, against it, or
# unmentioned?"
#
# Mapping:
#   prior > 0  for this action  → coherent       → return 1.0
#   prior < 0  for this action  → incoherent     → return 0.0
#   prior == 0 (or absent)      → no opinion     → return 0.5
#
# NEUTRAL tone has an empty prior dict, so it always returns 0.5 (no opinion).
# That's correct — NEUTRAL means we have no tonal frame to be coherent or
# incoherent with.
function _compute_emotional_coherence(action::ActionFamily, tone::ToneFamily)::Float64
    tone_priors = get(TONE_ACTION_PRIOR, Symbol(tone), Dict{Symbol, Float64}())
    isempty(tone_priors) && return 0.5   # GRUG: no prior = no opinion = neutral coherence

    prior_value = get(tone_priors, Symbol(action), 0.0)

    if prior_value > 0.0
        return 1.0   # action is in tone's tilt set → coherent
    elseif prior_value < 0.0
        return 0.0   # action opposes tone's tilt → incoherent
    else
        return 0.5   # no prior for this specific action under this tone
    end
end

"""
    get_tonal_observation() -> NamedTuple

Read the current tonal observation state. Returns the named tuple
`(last_tone, last_action, last_arousal, last_emotional_coherence, ts)`.

In v7.21b-1 this is observation-only — useful for diagnostics, logging,
and tests. v7.21b-2 will let prediction read this to modulate jitter
envelopes per-tone.
"""
get_tonal_observation() = lock(_STATE_LOCK) do; _TONAL_OBSERVATION[] end

"""
    get_last_prediction() -> Union{Nothing, PredictionResult}

Thread-safe read of LAST_PREDICTION. Returns the most recent ATP result
or nothing if no prediction has been computed yet this session.
"""
get_last_prediction() = lock(_STATE_LOCK) do; LAST_PREDICTION[] end

"""
    get_last_escalation_trace() -> Any

Thread-safe read of LAST_ESCALATION_TRACE. Returns the most recent
escalation trace dict or nothing.
"""
get_last_escalation_trace() = lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] end

"""
    reset_tonal_observation!()

Reset the tonal observation running state to defaults. Called by tests
and on cave wipe. Does not affect the trajectory buffer (separate state).
"""
function reset_tonal_observation!()
    _TONAL_OBSERVATION[] = (
        last_tone = TONE_NEUTRAL,
        last_action = ACTION_ASSERT,
        last_arousal = 0.0,                    # GRUG: 0 nudge = "no prior observation"
        last_emotional_coherence = 0.5,
        ts = 0.0                               # GRUG: ts==0.0 is the "never observed" sentinel
    )
    return nothing
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
    "negate", "contradict", "disagree", "refuse", "reject", "invalid"
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

# ==============================================================================
# v7.20 — HEAVY-FALLBACK CHARACTER-BIGRAM CLASSIFIER
# ==============================================================================
# GRUG: When the lexicon shrugs (no marker tokens hit, total_action_signal <
# LOW_SIGNAL_THRESHOLD), the old code defaulted to ASSERT and gave up. The
# input might be a fragment, jargon, code, a typo'd command, or just text
# that doesn't use any of our hand-curated marker words. Defaulting to
# ASSERT in those cases is wrong twice: it's wrong about the action, and
# it's wrong about the *confidence* — we report a confidence as if we
# classified properly when we didn't.
#
# The fix: when the lexicon shrugs, run a heavier path that scores the
# input's character bigrams against per-family fingerprints built from the
# marker sets at module load time. This is NOT an LLM, NOT a transformer.
# It's a tiny, fully-deterministic substring-shape classifier: pure Julia,
# no deps, < 1ms per call, no network. The point is: when keywords don't
# fire, *shape* still tells us something. "wat happen?" has no QUERY marker
# (we don't have "wat") but its bigrams overlap heavily with the QUERY
# fingerprint built from {"what","why","how",...}.
#
# Mode telemetry rides on PredictionResult.mode (:lexicon vs :fallback) so
# downstream consumers can see which path produced the call. Counters are
# kept in PREDICTOR_TELEMETRY for diagnostic readout.
#
# Trigger conditions (any of):
#   1. total_action_signal < LOW_SIGNAL_THRESHOLD (the existing tripwire)
#   2. Lorenz damping fired AND top-family confidence < FALLBACK_DAMP_THRESHOLD
#      (i.e. the trajectory is locked into a strange attractor and the
#      lexicon isn't pulling us out)
#
# Why the second trigger? Without it, a marker-rich input that happens to
# be in a damped regime would never escape the attractor — the lexicon
# would always return enough signal to skip the fallback. The damped-low-
# conf trigger lets the heavier path break the loop.
# ==============================================================================

# GRUG: When raw action signal sums to less than this, the lexicon has
# nothing to say and the heavy fallback takes over. Was implicit at 0.5
# in the original code; now named so it's tunable + searchable.
const LOW_SIGNAL_THRESHOLD = 0.5

# GRUG: Top-family confidence below this, when combined with active Lorenz
# damping, also triggers the heavy fallback. 0.4 is "the system isn't sure
# even after damping was applied" — a strong signal that the lexicon path
# has run out of road.
const FALLBACK_DAMP_THRESHOLD = 0.4

# GRUG v7.21a: CURVE SNAP-BACK JITTER ENVELOPE.
# Bounded multiplicative noise applied to each family's post-softmax mass
# before Gini damping. Same biology principle as the substrate-level
# slight_jitter: identical inputs must not produce bit-identical curves.
# 0.03 = ±3% per family. Small enough that a clear winner stays the winner
# on real signals; loud enough that the curve shape is never twice the same.
# Tunable. If brainstorm mode wants louder curves we'll widen this in v7.21b.
const CURVE_JITTER_ENVELOPE = 0.03

# GRUG v7.21a: TONE → ACTION PRIOR.
# Tone runs FIRST. The observed tone biases which action families are even
# plausible BEFORE action lexicon scoring runs. This is the load-bearing
# reorder: emotional read of the room precedes and conditions the action
# decision, instead of action and tone being scored independently and
# emotional coherence being a post-hoc check.
#
# Each entry is (tone_family) => Dict(action_family => additive_prior).
# The prior is added to action_scores BEFORE softmax, so it shifts the
# distribution proportionally rather than overriding marker evidence.
# Magnitudes are deliberately moderate (0.4–0.8) — strong enough to tilt
# ambiguous inputs, weak enough that a clear action marker still wins.
const TONE_ACTION_PRIOR = Dict{Symbol, Dict{Symbol, Float64}}(
    :TONE_HOSTILE     => Dict(:ACTION_NEGATE => 0.7, :ACTION_QUERY => 0.4, :ACTION_ASSERT => -0.3),
    :TONE_CURIOUS     => Dict(:ACTION_QUERY => 0.7, :ACTION_SPECULATE => 0.4),
    :TONE_URGENT      => Dict(:ACTION_COMMAND => 0.6, :ACTION_ESCALATE => 0.5, :ACTION_SPECULATE => -0.3),
    :TONE_REFLECTIVE  => Dict(:ACTION_SPECULATE => 0.7, :ACTION_QUERY => 0.3, :ACTION_COMMAND => -0.3),
    :TONE_DECLARATIVE => Dict(:ACTION_ASSERT => 0.5),
    :TONE_NEUTRAL     => Dict{Symbol, Float64}()   # neutral tone = no prior tilt
)

# GRUG: Build a character-bigram fingerprint from a set of marker words.
# Returns Dict{String, Int} of bigram → count. Pure helper; called once
# per family at module load. Uses 2-char windows over the lowercased word
# with a leading/trailing space marker so word-boundary bigrams are
# captured (`"^w"` and `"t$"` for "what" become `" w"` and `"t "`).
function _build_bigram_fingerprint(words::Set{String})::Dict{String, Int}
    fp = Dict{String, Int}()
    for w in words
        wl = " " * lowercase(w) * " "    # GRUG: pad with spaces so word-boundary bigrams count
        if length(wl) < 2
            continue
        end
        # GRUG: Iterate in BYTE space, not char space. ASCII markers only,
        # so byte-bigrams are safe and let us avoid Char→String conversions
        # on the hot path. nextind/prevind keep us valid even if a marker
        # has unicode (none do today, but a future addition wouldn't crash).
        idx = firstindex(wl)
        while true
            nxt = nextind(wl, idx)
            nxt > lastindex(wl) && break
            bg = wl[idx:nxt]
            fp[bg] = get(fp, bg, 0) + 1
            idx = nxt
        end
    end
    return fp
end

# GRUG: Pre-built fingerprints for every action family. Built ONCE at
# module load (these are `const`) — the marker sets never change at
# runtime. If a future version exposes a "register marker" API, these
# would need to become Refs and the API would rebuild them, but for now
# the static const path is the fastest and simplest.
const _ACTION_FAMILY_FINGERPRINTS = Dict{ActionFamily, Dict{String, Int}}(
    ACTION_QUERY     => _build_bigram_fingerprint(QUERY_MARKERS),
    ACTION_COMMAND   => _build_bigram_fingerprint(COMMAND_MARKERS),
    ACTION_NEGATE    => _build_bigram_fingerprint(NEGATE_MARKERS),
    ACTION_SPECULATE => _build_bigram_fingerprint(SPECULATE_MARKERS),
    # GRUG: ASSERT and ESCALATE have no dedicated marker set in the
    # lexicon — ASSERT is the default fallthrough and ESCALATE is signaled
    # by punctuation/caps. Give them empty fingerprints so the fallback
    # never *favors* them just because they have nothing to compete
    # against; if no other family scores, ASSERT remains the default.
    ACTION_ASSERT    => Dict{String, Int}(),
    ACTION_ESCALATE  => Dict{String, Int}()
)

"""
    _heavy_fallback_score(input_text::String) -> Dict{ActionFamily, Float64}

GRUG v7.20: Score an input's character bigrams against each per-family
fingerprint. Returns a Dict of family → raw score (NOT normalized — the
caller folds these into action_scores and re-normalizes there).

Score formula: for each bigram in the input that appears in a family's
fingerprint, add `min(1.0, fp_count / 3.0)` to that family's score. The
cap means a family with one heavily-recurring bigram doesn't dominate;
breadth wins over depth, which matches the spirit of "shape-overlap"
rather than "literal word match."

PURE: no I/O, no allocation beyond the result dict, deterministic.

NO SILENT FAILURES: empty input is a contract violation (the caller has
already validated tokens_clean is non-empty by the time we reach the
fallback), but we still defensively return an all-zero dict instead of
crashing — the fallback is a *recovery* path and should never be the
thing that crashes the predictor.
"""
function _heavy_fallback_score(input_text::String)::Dict{ActionFamily, Float64}
    scores = Dict{ActionFamily, Float64}(
        ACTION_ASSERT    => 0.0,
        ACTION_QUERY     => 0.0,
        ACTION_COMMAND   => 0.0,
        ACTION_NEGATE    => 0.0,
        ACTION_SPECULATE => 0.0,
        ACTION_ESCALATE  => 0.0
    )

    # GRUG: Defensive — empty input would be a caller bug, but recovery
    # paths should never crash. Return an all-zero dict so the upstream
    # softmax falls through to the neutral default.
    if isempty(strip(input_text))
        return scores
    end

    # GRUG: Same padding scheme as fingerprint builder so bigrams align.
    padded = " " * lowercase(input_text) * " "
    if length(padded) < 2
        return scores
    end

    # GRUG: Walk byte-bigrams over the input.
    idx = firstindex(padded)
    while true
        nxt = nextind(padded, idx)
        nxt > lastindex(padded) && break
        bg = padded[idx:nxt]
        # GRUG: Score this bigram against every family fingerprint. Hot
        # path; the dict lookups are O(1) average.
        for (fam, fp) in _ACTION_FAMILY_FINGERPRINTS
            cnt = get(fp, bg, 0)
            if cnt > 0
                # GRUG: Cap per-bigram contribution so high-recurrence
                # bigrams don't dominate. Divisor=3 picks "small but
                # non-trivial" — most marker bigrams appear 1-3 times
                # across their family.
                scores[fam] += min(1.0, cnt / 3.0)
            end
        end
        idx = nxt
    end

    return scores
end

# GRUG: Module-level diagnostic counters. Read by /status or test code.
# Not lock-protected — single increment-per-call, last-write wins is fine
# for telemetry. If we ever care about exact counts we can wrap a lock.
const PREDICTOR_TELEMETRY = Dict{Symbol, Int}(
    :predictions_total => 0,
    :lexicon_path      => 0,
    :fallback_path     => 0,
    :fallback_low_sig  => 0,    # fallback fired due to LOW_SIGNAL_THRESHOLD
    :fallback_damp_lc  => 0     # fallback fired due to damped + low conf
)

"""
    get_predictor_telemetry()::Dict{Symbol, Int}

GRUG v7.20: Return a copy of the predictor telemetry counters. Copy so
callers can't mutate our internal counter dict.
"""
function get_predictor_telemetry()::Dict{Symbol, Int}
    return lock(_STATE_LOCK) do; copy(PREDICTOR_TELEMETRY) end
end

"""
    reset_predictor_telemetry!()

GRUG v7.20: Zero the predictor telemetry. Used by tests to isolate runs;
not called during normal operation (counters accumulate over a session).
"""
function reset_predictor_telemetry!()
    lock(_STATE_LOCK) do
        for k in keys(PREDICTOR_TELEMETRY)
            PREDICTOR_TELEMETRY[k] = 0
        end
    end
    return nothing
end

# ==============================================================================
# MODULATION TABLES
# GRUG: Numbers that turn prediction results into cave pre-tuning values.
# ==============================================================================

# GRUG v8.22: LAZY CONSERVATIVE AROUSAL NUDGE.
# Old values were too aggressive — every tone pushed arousal around.
# New philosophy: don't nudge unless there's GENUINE URGENCY.
# URGENT and HOSTILE keep their nudge (that's real urgency).
# Everything else stays at 0.0 — the cave scans normally without
# pre-tuning from tone prediction unless the user is actually urgent.
# DECLARATIVE/REFLECTIVE used to pull arousal DOWN, which is just as
# aggressive as pushing it up — let the scan decide on its own.
const TONE_AROUSAL_NUDGE = Dict{ToneFamily, Float64}(
    TONE_HOSTILE     => +0.20,   # reduced from +0.35 — still alerts, less violently
    TONE_URGENT      => +0.20,   # reduced from +0.25 — urgency still matters, gentler
    TONE_CURIOUS     =>  0.0,    # unchanged — no urgency signal
    TONE_DECLARATIVE =>  0.0,    # was -0.10 — removed, let scan run naturally
    TONE_NEUTRAL     =>  0.0,    # unchanged — no urgency signal
    TONE_REFLECTIVE  =>  0.0     # was -0.15 — removed, let scan run naturally
)

# GRUG v8.22: LAZY CONSERVATIVE ACTION WEIGHT TABLE.
# Old values ALL boosted aligned nodes (1.2–1.7), meaning ATP ALWAYS
# skewed the vote pool. That's the opposite of lazy. New philosophy:
#   - Non-urgent families: weight = 1.0 (NO boost, NO skew)
#   - ESCALATE only: weight = 1.3 (mild boost, genuine urgency signal)
# The cave should scan normally unless the user is spiking. A calm
# ASSERT or QUERY doesn't need ATP inflating its aligned nodes.
# The old "always boost" approach was causing false confidence inflation
# — every prediction made the winning family look stronger than it was.
const ACTION_WEIGHT_TABLE = Dict{ActionFamily, Float64}(
    ACTION_ASSERT    => 1.0,   # was 1.4 — no boost for declarative claims
    ACTION_QUERY     => 1.0,   # was 1.6 — no boost for questions
    ACTION_COMMAND   => 1.0,   # was 1.5 — no boost for directives
    ACTION_NEGATE    => 1.0,   # was 1.3 — no boost for negations
    ACTION_SPECULATE => 1.0,   # was 1.2 — no boost for hedging
    ACTION_ESCALATE  => 1.3    # was 1.7 — mild boost ONLY for urgency
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
# CURVE SNAP-BACK JITTER (v7.21a)
# ==============================================================================
# GRUG: Bounded multiplicative micro-noise on a probability distribution,
# followed by re-normalization to preserve the sum-to-1 invariant.
#
# Same biology principle as the per-window slight_jitter inside cheap_scan:
# identical inputs must NOT produce bit-identical curves. The world is
# noisy; the system's curves should be noisy in the same bounded way.
#
# Mutates `dist` in place. `envelope` is the per-family multiplicative
# bound: each value is multiplied by (1 + ε) where ε ∈ [-envelope, +envelope]
# uniform. After the noise pass, the dict is re-normalized so values still
# sum to 1.0.
#
# Why multiplicative not additive: additive noise can flip small values
# negative, breaking the probability invariant. Multiplicative noise scales
# with current mass, so a 0.01 family stays a tiny family (becomes 0.0097
# to 0.0103) while a 0.6 family gets the proportionally larger absolute
# wiggle it deserves. Re-normalization at the end folds out any small drift.
# ==============================================================================
function _jitter_curve!(dist::Dict{K, Float64}; envelope::Float64=CURVE_JITTER_ENVELOPE) where K
    if envelope <= 0.0
        return dist  # no-op for non-positive envelope
    end

    # GRUG: Apply per-family multiplicative noise.
    for (k, v) in dist
        eps = (rand() * 2.0 - 1.0) * envelope   # uniform in [-envelope, +envelope]
        dist[k] = max(0.0, v * (1.0 + eps))
    end

    # GRUG: Re-normalize. If the noise drove everything to zero (impossible
    # in practice unless envelope is grossly misconfigured), fall back to
    # uniform to preserve the sum-to-1 invariant.
    total = sum(values(dist))
    if total <= 0.0 || !isfinite(total)
        n = length(dist)
        for k in keys(dist); dist[k] = 1.0 / n; end
        return dist
    end

    for k in keys(dist); dist[k] /= total; end
    return dist
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
# CORE PREDICTOR
# ==============================================================================

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
    # STEP 0 (v7.21a): SHARED SIGNALS — used by both tone and action.
    # GRUG: caps_words and excl_count were originally computed inside the
    # action block. Now that tone runs FIRST, they need to be available
    # before tone scoring (caps and excl are tonal signals as much as
    # actional ones — a HOSTILE tone benefits from the same caps/excl
    # data the ESCALATE action does).
    # ------------------------------------------------------------------
    caps_words = count(
        t -> length(t) >= 3 && t == uppercase(t) && isletter(t[1]),
        tokens_raw
    )
    excl_count       = count(c -> c == '!', input_text)
    q_marker_present = contains(input_text, "?") ||
                       any(t -> t in QUERY_MARKERS, tokens_clean)
    input_low        = lowercase(input_text)

    # ------------------------------------------------------------------
    # STEP 1 (v7.21a): TONE FIRST — tone is the observer; it runs before
    # action so the observed tone can condition which action families are
    # even plausible. This is the load-bearing reorder for emotional
    # coherence: the affective read of the room precedes the action
    # decision, not the other way around.
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
        tok in HOSTILE_MARKERS    && (tone_scores[TONE_HOSTILE]    += 1.0)
        tok in URGENT_MARKERS     && (tone_scores[TONE_URGENT]     += 1.0)
        tok in SPECULATE_MARKERS  && (tone_scores[TONE_REFLECTIVE] += 0.6)
        tok in QUERY_MARKERS      && (tone_scores[TONE_CURIOUS]    += 0.7)
        tok in REFLECTIVE_MARKERS && (tone_scores[TONE_REFLECTIVE] += 0.5)
    end

    if caps_words >= 2
        tone_scores[TONE_HOSTILE] += 0.5
        tone_scores[TONE_URGENT]  += 0.5
    end

    if excl_count >= 2
        # GRUG: Multi-bang is an urgency signal in its own right.
        tone_scores[TONE_URGENT] += 0.4
    end

    for phrase in REFLECTIVE_PHRASES
        if contains(input_low, phrase)
            tone_scores[TONE_REFLECTIVE] += 0.8
        end
    end

    # GRUG v7.21a: The old code boosted CURIOUS when ACTION_QUERY > 0.5 AND
    # HOSTILE < 0.5. With tone-first ordering action_scores doesn't exist
    # yet, so we use the raw `q_marker_present` signal directly. Same
    # semantics: question markers without hostility = curious.
    if q_marker_present && tone_scores[TONE_HOSTILE] < 0.5
        tone_scores[TONE_CURIOUS] += 0.6
    end

    # GRUG: No strong tone signal? Default to NEUTRAL.
    total_tone_signal = sum(values(tone_scores))
    if total_tone_signal < 0.4
        tone_scores[TONE_NEUTRAL] += 1.0
    end

    # GRUG v7.21a: OBSERVED TONE (raw, pre-softmax). This is what
    # conditions the action prior. We use raw argmax rather than the
    # post-softmax winner because softmax is length-invariant smoothing
    # and we want the *strongest raw evidence* to drive the prior — even
    # a small tone signal should tilt the action prior slightly. Ties
    # break to NEUTRAL since the Dict preserves insertion order and
    # NEUTRAL was inserted with mass 0.0 before the default boost.
    observed_tone = argmax(tone_scores)

    # ------------------------------------------------------------------
    # STEP 2 (v7.21a): ACTION — runs AFTER tone, with tone-derived prior
    # folded in BEFORE marker scoring. The prior moderately tilts which
    # action families are plausible given the observed tone; marker
    # evidence then competes against (or reinforces) that tilt.
    # ------------------------------------------------------------------
    action_scores = Dict{ActionFamily, Float64}(
        ACTION_ASSERT    => 0.0,
        ACTION_QUERY     => 0.0,
        ACTION_COMMAND   => 0.0,
        ACTION_NEGATE    => 0.0,
        ACTION_SPECULATE => 0.0,
        ACTION_ESCALATE  => 0.0
    )

    # GRUG v7.21a: Fold tone→action prior. The prior keys are Symbols (so
    # the const can be declared at compile time without enum dependencies);
    # we look up by Symbol(observed_tone) here.
    tone_prior = get(TONE_ACTION_PRIOR, Symbol(observed_tone), Dict{Symbol,Float64}())
    for (action_sym, bias) in tone_prior
        # GRUG: Map Symbol → enum value. We only have six action families,
        # so a small if-ladder is faster than building a lookup table.
        action_fam = action_sym === :ACTION_ASSERT    ? ACTION_ASSERT    :
                     action_sym === :ACTION_QUERY     ? ACTION_QUERY     :
                     action_sym === :ACTION_COMMAND   ? ACTION_COMMAND   :
                     action_sym === :ACTION_NEGATE    ? ACTION_NEGATE    :
                     action_sym === :ACTION_SPECULATE ? ACTION_SPECULATE :
                     action_sym === :ACTION_ESCALATE  ? ACTION_ESCALATE  :
                     nothing
        if action_fam !== nothing
            action_scores[action_fam] += bias
        end
    end

    # GRUG: "?" is the strongest query signal. Check raw input, not tokens.
    if contains(input_text, "?")
        action_scores[ACTION_QUERY] += 1.5
    end

    # GRUG: ALL CAPS words (3+ chars, starts with letter) = escalation signal.
    if caps_words > 0
        action_scores[ACTION_ESCALATE] += Float64(caps_words) * 0.8
    end

    # GRUG: Each exclamation mark adds escalation weight.
    if excl_count > 0
        action_scores[ACTION_ESCALATE] += Float64(excl_count) * 0.5
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

    # GRUG v7.20: LOW-SIGNAL FALLBACK TRIGGER (path 1 of 2).
    # Old code: if the lexicon hit nothing, just default to ASSERT and shrug.
    # New code: kick into the heavy character-bigram fallback FIRST. Only if
    # the fallback also produces no signal do we keep the ASSERT default —
    # at which point we're honestly ASSERTing because we genuinely have no
    # idea, not because we silently gave up. Mode telemetry tracks which
    # path produced the result so /status can show fallback hit-rate.
    total_action_signal = sum(values(action_scores))
    classifier_mode = :lexicon
    if total_action_signal < LOW_SIGNAL_THRESHOLD
        # GRUG: Lexicon shrugged. Run the bigram fallback and fold its
        # scores into action_scores. We ADD instead of REPLACE so that any
        # tiny signal from the lexicon (e.g. a single ! pushing ESCALATE)
        # still counts — the fallback is a recovery layer on top, not a
        # replacement.
        fallback_scores = _heavy_fallback_score(input_text)
        fallback_total  = sum(values(fallback_scores))
        if fallback_total > 0.0
            for (fam, s) in fallback_scores
                action_scores[fam] += s
            end
            classifier_mode = :fallback
            lock(_STATE_LOCK) do
                PREDICTOR_TELEMETRY[:fallback_path]    += 1
                PREDICTOR_TELEMETRY[:fallback_low_sig] += 1
            end
        else
            # GRUG: Even the fallback found nothing. Honest ASSERT default
            # with the original boost preserved (so downstream confidence
            # math still works the same when both paths are silent).
            action_scores[ACTION_ASSERT] += 1.0
        end
    end

    # GRUG v7.21a: Tone scoring used to live here as STEP 2; it now runs
    # FIRST (see STEP 1 above) so the observed tone can condition the
    # action prior. This block is intentionally empty — tone_scores has
    # already been built and the tone→action prior has already been
    # folded into action_scores.

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
    # STEP 3.5 (v7.21a): CURVE SNAP-BACK JITTER
    # GRUG: Apply bounded multiplicative micro-noise to each family's
    # post-softmax mass, then re-normalize. Same biological principle as
    # the per-window slight_jitter in cheap_scan: identical inputs must
    # not produce bit-identical curves. The envelope is small enough that
    # winner-family identity is preserved on real signals (a clear winner
    # stays the winner) but the curve shape is never twice the same.
    #
    # Applied BEFORE Gini damping so the damper sees the jittered curve —
    # we want the noise to participate in the concentration check, not be
    # smoothed back out by it.
    # ------------------------------------------------------------------
    _jitter_curve!(action_dist; envelope=CURVE_JITTER_ENVELOPE)
    _jitter_curve!(tone_dist;   envelope=CURVE_JITTER_ENVELOPE)

    # ------------------------------------------------------------------
    # STEP 4 (v7.21a): PER-QUERY GINI DAMPING — no cross-query memory
    # GRUG: The old code computed a centroid from a 16-turn ring buffer
    # with 120s halflife and damped the current prediction against THAT
    # centroid. Result: five questions in the same family loaded the
    # centroid, and query six got damped because of historical mass — the
    # system over-normalized, suppressing clean signal because of past
    # concentration.
    #
    # v7.21a: damping fires on the CURRENT query's distribution directly.
    # If THIS query is itself heavily concentrated (one family > Gini
    # threshold of mass), entropy-restoring damping spreads mass to
    # underrepresented categories. No history. No bleed. The curve fires,
    # damps if it must, then snaps back — nothing persists between calls.
    #
    # The trajectory buffer stays alive as an empty (or test-injected)
    # vector for API/specimen compatibility; predict_action_tone simply
    # does not read from it or write to it during normal operation.
    # `reset_trajectory!`, `get_trajectory_state`, `set_trajectory_config!`,
    # and `TrajectoryConfig` keep working — only the IN-LINE accumulation
    # behavior is gone. Tests asserting buffer-zero-after-reset still pass.
    # ------------------------------------------------------------------
    trajectory_damped = false

    # GRUG: Build a "self-centroid" from the current query's distribution —
    # this lets _apply_lorenz_damping run unchanged. Conceptually: the
    # centroid the damper compares against is just the prediction itself,
    # so we're asking "is THIS prediction concentrated enough to need
    # entropy restoration?" rather than "has the conversation been
    # concentrated?".
    self_action = copy(action_dist)
    self_tone   = copy(tone_dist)
    gini_a = _gini_coefficient(collect(values(self_action)))
    gini_t = _gini_coefficient(collect(values(self_tone)))

    action_dist_new, damped_a = _apply_lorenz_damping(action_dist, self_action, gini_a, config)
    if damped_a
        for (k, v) in action_dist_new; action_dist[k] = v; end
    end

    tone_dist_new, damped_t = _apply_lorenz_damping(tone_dist, self_tone, gini_t, config)
    if damped_t
        for (k, v) in tone_dist_new; tone_dist[k] = v; end
    end

    trajectory_damped = damped_a || damped_t

    if trajectory_damped
        @info "[PREDICTOR] 🌀 Per-query Gini damping active — " *
              "action_gini=$(round(gini_a, digits=3)), " *
              "tone_gini=$(round(gini_t, digits=3))"
    end

    # GRUG v7.21a: NOTE — _push_trajectory_entry! is intentionally NOT called.
    # Per-query semantics means nothing persists between predictions. The
    # trajectory buffer stays at whatever the test/specimen layer left it
    # at; predict_action_tone is no longer a writer.

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

    # GRUG v7.20: LOW-SIGNAL FALLBACK TRIGGER (path 2 of 2).
    # Even if the lexicon DID produce signal, if Lorenz damping fired and the
    # post-damping confidence is still weak, we're stuck in a strange-attractor
    # rut that the lexicon alone can't break. Run the heavy fallback as a
    # second-chance corrective. Only re-classify if the fallback would change
    # the winner — otherwise we'd be paying the cost for nothing.
    if trajectory_damped &&
       action_confidence < FALLBACK_DAMP_THRESHOLD &&
       classifier_mode === :lexicon
        fallback_scores = _heavy_fallback_score(input_text)
        if sum(values(fallback_scores)) > 0.0
            # GRUG: Re-fold fallback into raw scores and re-distribute.
            for (fam, s) in fallback_scores
                action_scores[fam] += s
            end
            new_dist = _softmax_normalize(action_scores, config.softmax_temperature)
            new_action = argmax(new_dist)
            new_vals   = sort(collect(values(new_dist)), rev=true)
            new_conf   = length(new_vals) >= 2 ?
                clamp((new_vals[1] - new_vals[2]) * 2.5, 0.05, 1.0) :
                clamp(new_vals[1] * 2.5, 0.05, 1.0)

            # GRUG: Adopt fallback only if it gives us strictly better
            # confidence. Otherwise the original (lexicon-damped) result
            # stays — the fallback is a recovery layer, not a mandatory
            # override.
            if new_conf > action_confidence
                action_dist       = new_dist
                predicted_action  = new_action
                action_confidence = new_conf
                classifier_mode   = :fallback
                lock(_STATE_LOCK) do
                    PREDICTOR_TELEMETRY[:fallback_path]   += 1
                    PREDICTOR_TELEMETRY[:fallback_damp_lc] += 1
                end
                @info "[PREDICTOR] 🌀 damped+low-conf → heavy fallback adopted " *
                      "(action=$(predicted_action), conf=$(round(action_confidence, digits=3)))"
            end
        end
    end

    # GRUG v7.20: Telemetry — every prediction increments total + path.
    lock(_STATE_LOCK) do
        PREDICTOR_TELEMETRY[:predictions_total] += 1
        if classifier_mode === :lexicon
            PREDICTOR_TELEMETRY[:lexicon_path] += 1
        end
    end

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
    # STEP 8: Compute confidence weight multiplier
    # ------------------------------------------------------------------
    base_weight   = get(ACTION_WEIGHT_TABLE, predicted_action, 1.0)

    # GRUG: Scale weight by confidence. Low confidence = stay near 1.0 (minimal skew).
    scaled_weight = 1.0 + (base_weight - 1.0) * action_confidence

    # GRUG v7.21b-1: Compute emotional coherence as a measurement on top
    # of the already-finalized winner pair. This is observation, not action —
    # the coherence value rides along on the result for downstream visibility
    # but does not change predicted_action or predicted_tone.
    coherence = _compute_emotional_coherence(predicted_action, predicted_tone)

    result = PredictionResult(
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
        classifier_mode,    # GRUG v7.20: which path produced this result
        coherence           # GRUG v7.21b-1: emotional coherence measurement
    )

    # GRUG: Stash for downstream consumers (vote orchestrator scoring,
    # diagnostic readers) so they don't have to re-run classification.
    lock(_STATE_LOCK) do
        LAST_PREDICTION[] = result
    end

    # GRUG v7.21b-1: Update the tonal observation running state AFTER the
    # result is fully built. b-1 only writes here — nothing in this call
    # READ the state before this point. b-2 will add a read at the top of
    # predict_action_tone to let the previous observation modulate the
    # current jitter envelope.
    lock(_STATE_LOCK) do
        _TONAL_OBSERVATION[] = (
            last_tone = predicted_tone,
            last_action = predicted_action,
            last_arousal = arousal_nudge,
            last_emotional_coherence = coherence,
            ts = result.timestamp
        )
    end

    return result
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

    # GRUG v8.22: LAZY CONSERVATIVE GATE — raised from 0.3 to 0.5.
    # Old gate: modulate at 30% confidence. Too eager — ATP was skewing
    # the vote pool even when it wasn't sure what the user wanted.
    # New gate: don't modulate unless 50% confident. Below that, let
    # the cave scan naturally without ATP interference. This is the
    # "lazy" part — ATP stays out of the way unless it has a real read.
    if prediction.confidence < 0.5
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
        # GRUG v8.22: LAZY CONSERVATIVE SUPPRESSION — was 0.85 + 0.15*(1-conf),
        # now 0.92 + 0.08*(1-conf). Old value suppressed misaligned nodes to
        # 0.85–1.0 range. That's too aggressive for a system that should stay
        # out of the way unless there's urgency. New range: 0.92–1.0. A
        # misaligned node gets at most an 8% tap-down, not 15%. The cave
        # should trust its own scan results more than ATP's prediction about
        # what the user probably wants.
        return 0.92 + (0.08 * (1.0 - prediction.confidence))
    end
end

# GRUG: Internal keyword alignment check — does this action name sound like the
# predicted action family? Substring match on known keywords per family.
#
# The keyword lists are intentionally broad: they cover the canonical
# action-family verbs PLUS the cave-vocabulary verbs we expect to see in
# action_packet entries on real specimen nodes. The vote orchestrator uses
# this as a soft "matching knob" — a hit boosts a candidate's composite
# score, a miss does not penalize. So generosity is fine here.
function _action_name_aligns(action_name::String, family::ActionFamily)::Bool
    if family == ACTION_QUERY
        # interrogative / sense-making / inspection verbs
        return any(kw -> contains(action_name, kw),
                   ["query", "ask", "answer", "respond", "explain", "describe",
                    "tell", "info", "elaborate", "clarify", "define",
                    "analyze", "analyse", "examine", "inspect", "study",
                    "reason", "ponder", "think", "consider", "wonder",
                    "investigate", "explore", "review", "look", "check",
                    "calculate", "compute", "evaluate", "assess"])
    elseif family == ACTION_COMMAND
        # imperative / build / make / fix / move verbs
        return any(kw -> contains(action_name, kw),
                   ["execute", "run", "do", "action", "command", "perform",
                    "trigger", "make", "build", "craft", "forge", "shape",
                    "fix", "mend", "repair", "patch", "restore",
                    "plan", "prepare", "setup", "set", "configure",
                    "move", "go", "fetch", "get", "bring", "carry",
                    "find", "seek", "hunt", "track", "gather", "collect",
                    "use", "apply", "wield", "operate"])
    elseif family == ACTION_NEGATE
        return any(kw -> contains(action_name, kw),
                   ["negate", "deny", "reject", "contra", "refute", "wrong",
                    "no", "not", "never", "stop", "halt", "block", "forbid",
                    "cancel", "abort", "dismiss"])
    elseif family == ACTION_ASSERT
        return any(kw -> contains(action_name, kw),
                   ["assert", "state", "declare", "confirm", "affirm", "say",
                    "claim", "report", "announce", "proclaim", "note",
                    "observe", "recall", "remember", "remind", "recount",
                    "log", "record"])
    elseif family == ACTION_SPECULATE
        return any(kw -> contains(action_name, kw),
                   ["speculate", "predict", "infer", "hypothe", "guess",
                    "maybe", "suppose", "imagine", "envision", "dream",
                    "wonder", "muse", "theorize", "estimate", "forecast",
                    "anticipate", "expect"])
    elseif family == ACTION_ESCALATE
        return any(kw -> contains(action_name, kw),
                   ["alert", "warn", "escalate", "urgent", "critical", "flag",
                    "danger", "threat", "fear", "scare", "flee", "hide",
                    "run", "evade", "avoid", "shout", "yell", "panic",
                    "emergency", "caution", "watch"])
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
    # GRUG v7.20: Surface the classifier mode so /status and the diagnostic
    # log line make it obvious when fallback fired. Lexicon path is the
    # default and silent; fallback gets an explicit tag.
    mode_str  = prediction.mode === :fallback ? " [FALLBACK]" : ""
    # GRUG v7.21b-1: Surface emotional incoherence the same way LORENZ-DAMPED
    # surfaces concentration damping. Only fires when coherence is meaningfully
    # below neutral (0.5) — ignoring the absent-prior case keeps the tag
    # quiet for NEUTRAL-tone predictions where it doesn't apply.
    incoh_str = prediction.emotional_coherence < INCOHERENCE_TAG_THRESHOLD ?
        " [INCOHERENT coh=$(round(prediction.emotional_coherence, digits=2))]" : ""
    return "Action=$(prediction.action_family) | " *
           "Tone=$(prediction.tone_family) | " *
           "Conf=$(round(prediction.confidence, digits=2)) | " *
           "ArousalNudge=$(round(prediction.arousal_nudge, digits=2)) | " *
           "Weight=$(round(prediction.action_weight, digits=2))$(chain_str)$(damp_str)$(mode_str)$(incoh_str)"
end

# ==============================================================================
# v7.23: ATP → EPHEMERAL AUTOMATON ESCALATION HOOK
# ==============================================================================
# GRUG: Basal ganglia decide if brain need working-memory scratch loop.
# If ATP prediction says "this is REASON/EXPLAIN/PLAN/COMPUTE" AND confidence
# is high enough, we check if an automaton rule matches. If it does, run it.
# The trace folds into arousal/weight so multi-step paths get extra kick.
#
# GRUG: ONLY ATP calls automaton. Nodes NEVER call it. This is the basal
# ganglia → prefrontal cortex escalation pathway. Sparse activation —
# most queries don't need it, and that's fine. Zero cost when idle.
# ==============================================================================

"""
Action families that, when predicted with high confidence, MAY trigger an
automaton escalation. These are the families where multi-step pattern
COMPLETION (rather than simple pattern REACTION) is likely needed.
"""
const ESCALATION_FAMILIES = Set{Symbol}([
    :ACTION_QUERY,      # "explain why X" → may need step-by-step
    :ACTION_SPECULATE,  # "what if X then Y" → may need chain completion
])

"""
Minimum ATP confidence to even consider escalation. Below this, the
automaton is never consulted — zero cost. Raised from 0.6 to 0.7 in
v8.22: escalation is expensive (automaton scratch loop), only fire
when ATP is genuinely confident. Lazy conservative principle: the
automaton should be a rare event, not a common path.
"""
const ESCALATION_CONFIDENCE_FLOOR = 0.7

"""
Last escalation trace produced by `maybe_escalate`. `nothing` if no
escalation occurred this cycle. Downstream consumers (orchestrator,
diagnostics) read this without re-running the automaton.
"""
const LAST_ESCALATION_TRACE = Ref{Any}(nothing)

"""
    maybe_escalate(prediction; automaton_module) -> Union{AutomatonTrace, Nothing}

Check whether ATP should escalate to the ephemeral automaton. Returns an
AutomatonTrace if escalation occurred, `nothing` otherwise.

Conditions for escalation:
1. predicted action family is in ESCALATION_FAMILIES
2. prediction confidence ≥ ESCALATION_CONFIDENCE_FLOOR
3. a matching automaton rule exists for the action family

When escalation fires:
- The automaton trace is stored in LAST_ESCALATION_TRACE
- Arousal nudge is boosted by the trace's step count (more steps = more
  deliberation = higher arousal to keep attention focused)
- Action weight is multiplied by a trace-derived factor

When escalation does NOT fire (the common case):
- LAST_ESCALATION_TRACE is set to nothing
- No cost — the function returns immediately
"""
function maybe_escalate(prediction::PredictionResult;
                        automaton_module::Union{Module, Nothing} = nothing)::Any
    # GRUG: No automaton module provided? Can't escalate. Return nothing.
    if automaton_module === nothing
        lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = nothing end
        return nothing
    end

    # GRUG: Check condition 1 — is this action family escalation-worthy?
    action_sym = Symbol(prediction.action_family)
    if !(action_sym in ESCALATION_FAMILIES)
        lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = nothing end
        return nothing
    end

    # GRUG: Check condition 2 — is confidence high enough?
    if prediction.confidence < ESCALATION_CONFIDENCE_FLOOR
        lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = nothing end
        return nothing
    end

    # GRUG: Check condition 3 — does a matching rule exist?
    # Use the provided automaton module's dispatch helper.
    trace = try
        automaton_module.run_for_action_family(
            action_sym, prediction.confidence
        )
    catch e
        @warn "[ATP-ESCALATE] Automaton dispatch failed (non-fatal): $e"
        lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = nothing end
        return nothing
    end

    if trace === nothing
        # GRUG: No matching rule. Not an error — sparse activation.
        lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = nothing end
        return nothing
    end

    # GRUG: ESCALATION FIRED! Store trace and log.
    lock(_STATE_LOCK) do; LAST_ESCALATION_TRACE[] = trace end
    @info "[ATP-ESCALATE] Automaton rule '$(trace.rule_id)' fired " *
          "($(length(trace.sequence)) steps, $(length(trace.jittered)) jittered) " *
          "for action=$(prediction.action_family) conf=$(round(prediction.confidence, digits=3))"

    return trace
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