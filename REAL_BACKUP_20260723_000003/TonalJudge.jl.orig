# TonalJudge.jl
# ==============================================================================
# v7.21b-2: TONAL JUDGE — TOKENS, COMMON-SENSE MODE SELECTION, FRAME HINTS
# ==============================================================================
#
# This module sits BETWEEN the predictor and the scaffold. It does not
# replace either. It is a structure-preserving (functorial in the
# lightweight programmer sense) translation layer that lifts a
# PredictionResult into a token bag, judges the situation, and emits a
# single FrameHint that downstream scaffolds can dispatch on.
#
# DESIGN PRINCIPLE — from the user direction "use common sense; some
# situations call for relational coherence, others just call for basics":
#
#   Most situations get the BASIC path: cheap action→frame lookup, no
#   blending of tone, no observer-state read. This mirrors how most of
#   biology is autopilot.
#
#   The RELATIONAL path fires only when the situation has structure to
#   honor: hostile/urgent/reflective tone, low coherence, dangling
#   chain, big arousal swing. Then we spin up the full token bag and
#   blend reading + observation to pick a frame that respects the felt
#   shape of the moment.
#
# v7.21b-2 IS PLUMBING-ONLY. Like b-1, it ships the surface and the
# diagnostics but does NOT yet change `synthesize_voice_reply`. That's
# b-3 — once we've watched the judge pick frames in the wild and
# verified its choices match what we'd want.
#
# What ships:
#   - Token alphabet (typed, finite, additive)
#   - TonalReading (token bag + scalar mirrors for back-compat)
#   - TonalJudgement (the judge's verdict + reasoning trace)
#   - pick_mode(reading, obs) :: BASIC | RELATIONAL
#   - judge(reading, obs)     — the entry point
#   - LAST_JUDGEMENT global (parallel to LAST_PREDICTION)
#   - [FRAME=...] tag in format_prediction_summary
#
# What does NOT ship in b-2:
#   - synthesize_voice_reply reading the judgement (b-3)
#   - per-tone tolerance bands acting on jitter (b-3 or b-4)
#   - brainstorm-mode global multiplier (b-4)
# ==============================================================================

module TonalJudge

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

using Base.Threads: ReentrantLock

using ..ActionTonePredictor: ActionFamily, ToneFamily,
    ACTION_QUERY, ACTION_COMMAND, ACTION_NEGATE, ACTION_ASSERT,
    ACTION_SPECULATE, ACTION_ESCALATE,
    TONE_HOSTILE, TONE_CURIOUS, TONE_DECLARATIVE, TONE_URGENT,
    TONE_NEUTRAL, TONE_REFLECTIVE,
    PredictionResult, get_tonal_observation

export Token, TokenCategory, FrameHint, JudgementMode,
       TonalReading, TonalJudgement,
       TOK_TONE, TOK_ACTION, TOK_FORM, TOK_INTENSITY, TOK_COHERENCE, TOK_FRAME_HINT,
       FRAME_WARM, FRAME_EXPLORATORY, FRAME_IMPERATIVE, FRAME_CONTEMPLATIVE,
       FRAME_DE_ESCALATING, FRAME_TERSE, FRAME_PLAIN,
       BASIC, RELATIONAL,
       build_reading_from_prediction, pick_mode, judge,
       frame_hint_for_action, frame_hint_label,
       get_last_judgement, reset_last_judgement!,
       set_frame_match_weights!, get_frame_match_weights,
       compute_frame_match_multiplier,
       INCOHERENCE_TAG_THRESHOLD_LOCAL

# ==============================================================================
# TOKEN ALPHABET
# ==============================================================================
#
# Token categories are intentionally few. Each token is (category, name, weight).
# Tokens are ADDITIVE — a reading can carry many of any category — and
# WEIGHTED — the judge can prefer strong claims over weak ones.

@enum TokenCategory begin
    TOK_TONE        # :hostile, :curious, :urgent, :reflective, :declarative, :neutral
    TOK_ACTION      # :query, :command, :negate, :assert, :speculate, :escalate
    TOK_FORM        # :question_form, :imperative_form, :fragment, :dangling_chain
    TOK_INTENSITY   # :high_arousal, :low_arousal, :concentrated, :diffuse
    TOK_COHERENCE   # :coherent, :incoherent, :neutral_coherence
    TOK_FRAME_HINT  # :de_escalating, :exploratory, :imperative, :contemplative, :warm, :terse, :plain
end

struct Token
    category :: TokenCategory
    name     :: Symbol
    weight   :: Float64    # GRUG: [0,1] strength of this token's claim
end

# GRUG: Convenience equality on (category, name) ignoring weight, useful
# for "does the bag contain this token?" without caring about strength.
Base.:(==)(a::Token, b::Token) = a.category === b.category && a.name === b.name && a.weight == b.weight

# ==============================================================================
# FRAME HINTS — the OUTPUT alphabet the judge picks from
# ==============================================================================
#
# This is what the scaffold layer (b-3+) will dispatch on. Small, finite,
# easy to add to. Each one names a *manner of speaking*, not a content type.

@enum FrameHint begin
    FRAME_WARM           # cheerful, open, friendly — for greetings and comfort
    FRAME_EXPLORATORY    # curious, inviting — for queries from a curious user
    FRAME_IMPERATIVE     # terse, directive — for urgent commands
    FRAME_CONTEMPLATIVE  # slower, speculative — for reflective input
    FRAME_DE_ESCALATING  # short, calm, non-defensive — for hostile input
    FRAME_TERSE          # short and factual — for low-arousal informational
    FRAME_PLAIN          # default fallback — no special framing needed
end

# GRUG: Human-readable label for a FrameHint. Used by the [FRAME=...]
# diagnostic tag. Keep these stable — log consumers may grep for them.
function frame_hint_label(f::FrameHint)::String
    f === FRAME_WARM           && return "warm"
    f === FRAME_EXPLORATORY    && return "exploratory"
    f === FRAME_IMPERATIVE     && return "imperative"
    f === FRAME_CONTEMPLATIVE  && return "contemplative"
    f === FRAME_DE_ESCALATING  && return "de-escalating"
    f === FRAME_TERSE          && return "terse"
    f === FRAME_PLAIN          && return "plain"
    return "unknown"
end

# ==============================================================================
# THE TONAL READING — token bag + scalar mirrors
# ==============================================================================
#
# Source of truth: `tokens`. The scalar fields are a derived view kept
# for back-compat with tests and downstream code that already reads
# action_family / tone_family directly. Adding a token to the bag does
# NOT automatically update the scalar mirrors — they reflect the
# predictor's chosen *winners* on each axis, while the bag can carry
# multiple competing claims.

struct TonalReading
    tokens          :: Vector{Token}
    # Scalar projections (mirrors of the predictor's winners):
    action_family   :: ActionFamily
    tone_family     :: ToneFamily
    confidence      :: Float64
    coherence       :: Float64
    arousal_nudge   :: Float64
    # Provenance
    timestamp       :: Float64
end

# ==============================================================================
# JUDGEMENT MODE & VERDICT
# ==============================================================================

@enum JudgementMode BASIC RELATIONAL

struct TonalJudgement
    mode             :: JudgementMode
    frame_hint       :: FrameHint
    promoted_tokens  :: Vector{Token}   # tokens the judge endorsed
    reasoning        :: Vector{Symbol}  # debuggable trace of why
    timestamp        :: Float64
end

# ==============================================================================
# READING BUILDER — lifts PredictionResult to TonalReading + token bag
# ==============================================================================
#
# This is the FUNCTORIAL piece in the programmer sense — a structure-
# preserving map from PredictionResult into the tokenized space.
# PredictionResult is the predictor's view; TonalReading is the judge's
# view. The map preserves: action winner, tone winner, confidence,
# coherence, arousal, timestamp. It ADDS: tokens for form, intensity,
# coherence flags. It does NOT lose information from the prediction.

function build_reading_from_prediction(pred::PredictionResult)::TonalReading
    toks = Token[]

    # GRUG: Tone token — always present, weight = predictor confidence.
    push!(toks, Token(TOK_TONE, _tone_to_sym(pred.tone_family), pred.confidence))

    # GRUG: Action token — always present, weight = predictor confidence.
    push!(toks, Token(TOK_ACTION, _action_to_sym(pred.action_family), pred.confidence))

    # GRUG: Form tokens — derived from predictor flags.
    if pred.incomplete_chain
        push!(toks, Token(TOK_FORM, :dangling_chain, 1.0))
    end

    # GRUG: Intensity tokens — derived from arousal_nudge magnitude.
    # Threshold of 0.3 is mild; below that we don't tag intensity
    # (it's just baseline neutral). Above 0.3 we say so. The sign of
    # the nudge tells us which direction.
    abs_arousal = abs(pred.arousal_nudge)
    if abs_arousal >= 0.3
        if pred.arousal_nudge > 0
            push!(toks, Token(TOK_INTENSITY, :high_arousal, abs_arousal))
        else
            push!(toks, Token(TOK_INTENSITY, :low_arousal, abs_arousal))
        end
    end

    # GRUG: Coherence token — explicit even when neutral. Lets the
    # judge see at a glance whether to trust the action/tone pair.
    coh_name = pred.emotional_coherence >= 0.7 ? :coherent :
               pred.emotional_coherence <= 0.3 ? :incoherent :
               :neutral_coherence
    push!(toks, Token(TOK_COHERENCE, coh_name, pred.emotional_coherence))

    return TonalReading(
        toks,
        pred.action_family,
        pred.tone_family,
        pred.confidence,
        pred.emotional_coherence,
        pred.arousal_nudge,
        pred.timestamp
    )
end

# GRUG: Internal symbol mappings. We keep enums in ActionTonePredictor as
# the source of truth; here we project them to Symbols for token bag use.
function _tone_to_sym(t::ToneFamily)::Symbol
    t === TONE_HOSTILE     && return :hostile
    t === TONE_CURIOUS     && return :curious
    t === TONE_URGENT      && return :urgent
    t === TONE_REFLECTIVE  && return :reflective
    t === TONE_DECLARATIVE && return :declarative
    return :neutral
end

function _action_to_sym(a::ActionFamily)::Symbol
    a === ACTION_QUERY     && return :query
    a === ACTION_COMMAND   && return :command
    a === ACTION_NEGATE    && return :negate
    a === ACTION_ASSERT    && return :assert
    a === ACTION_SPECULATE && return :speculate
    a === ACTION_ESCALATE  && return :escalate
    return :assert  # GRUG: defensive fallback — should never hit
end

# ==============================================================================
# COMMON-SENSE MODE PICKER
# ==============================================================================
#
# The whole architecture rests on this function. It decides whether the
# moment calls for the cheap basic path or the expensive relational path.
#
# Triggers for RELATIONAL (any one is enough):
#   1. Tone is meaningfully non-neutral (HOSTILE / URGENT / REFLECTIVE)
#      — these are the tones that demand we honor *how* the user said it,
#      not just *what* they said.
#   2. Coherence is below neutral (predictor flagged a mismatch).
#   3. Observation says we were just incoherent (running coherence < 0.5).
#   4. Arousal swing — the difference between observed last_arousal and
#      current arousal_nudge crossed the swing threshold. A user going
#      from calm → urgent in one turn is a context shift worth honoring.
#   5. Form: dangling chain present.
#
# Otherwise: BASIC. Greetings, neutral queries, declarations, casual
# inputs all run cheap. This matches the user's directive: "some
# situations call for relational coherence, others just call for basics."

const _RELATIONAL_TONES = Set{ToneFamily}([TONE_HOSTILE, TONE_URGENT, TONE_REFLECTIVE])
const _COHERENCE_TRIGGER_THRESHOLD = 0.5
const _AROUSAL_SWING_THRESHOLD     = 0.4

function pick_mode(reading::TonalReading, observation::NamedTuple)::JudgementMode
    # Trigger 1: non-neutral relational tone
    reading.tone_family in _RELATIONAL_TONES && return RELATIONAL

    # Trigger 2: current coherence below neutral
    reading.coherence < _COHERENCE_TRIGGER_THRESHOLD && return RELATIONAL

    # Trigger 3: previous observation was incoherent
    observation.last_emotional_coherence < _COHERENCE_TRIGGER_THRESHOLD && return RELATIONAL

    # Trigger 4: arousal swing across observation boundary.
    # Only fires if we have a prior observation (ts > 0). On first
    # prediction the observation is at reset defaults — comparing a
    # current arousal nudge against the reset default is meaningless.
    if observation.ts > 0.0
        swing = abs(reading.arousal_nudge - observation.last_arousal)
        swing > _AROUSAL_SWING_THRESHOLD && return RELATIONAL
    end

    # Trigger 5: form-level signals that demand structure-aware handling
    for tok in reading.tokens
        if tok.category === TOK_FORM && tok.name === :dangling_chain
            return RELATIONAL
        end
    end

    return BASIC
end

# ==============================================================================
# THE BASIC JUDGE — cheap action→frame lookup
# ==============================================================================
#
# When the situation is ordinary, just match the action to its default
# frame. No tone blending, no observation read, no token weighting.
# This path is intentionally simple and stable.

function frame_hint_for_action(action::ActionFamily)::FrameHint
    action === ACTION_QUERY     && return FRAME_EXPLORATORY
    action === ACTION_COMMAND   && return FRAME_IMPERATIVE
    action === ACTION_NEGATE    && return FRAME_TERSE
    action === ACTION_ASSERT    && return FRAME_PLAIN
    action === ACTION_SPECULATE && return FRAME_CONTEMPLATIVE
    action === ACTION_ESCALATE  && return FRAME_IMPERATIVE
    return FRAME_PLAIN
end

function _judge_basic(reading::TonalReading)::TonalJudgement
    hint = frame_hint_for_action(reading.action_family)
    return TonalJudgement(
        BASIC,
        hint,
        reading.tokens,                # basic path promotes everything
        Symbol[:basic_path, :action_lookup],
        time()
    )
end

# ==============================================================================
# THE RELATIONAL JUDGE — tone + observation aware
# ==============================================================================
#
# When the situation has structure to honor, blend reading + observation.
# Tone wins over action for frame selection. Observer state can override
# frame choice when the conversation just shifted.
#
# Selection priority (first match wins):
#   HOSTILE tone                  → FRAME_DE_ESCALATING
#   URGENT tone                   → FRAME_IMPERATIVE
#   REFLECTIVE tone               → FRAME_CONTEMPLATIVE
#   incoherent (coh ≤ 0.3)        → FRAME_TERSE   (safety: shut up briefly)
#   dangling_chain                → FRAME_CONTEMPLATIVE (complete the thought)
#   arousal swing detected        → frame from current tone, falling
#                                   back to action lookup if tone is neutral
#   default                       → frame_hint_for_action (action lookup)

function _judge_relational(reading::TonalReading, observation::NamedTuple)::TonalJudgement
    reasoning = Symbol[:relational_path]
    hint::FrameHint = FRAME_PLAIN
    decided = false

    # Priority 1: tone-driven frame selection
    if reading.tone_family === TONE_HOSTILE
        hint = FRAME_DE_ESCALATING
        push!(reasoning, :hostile_tone)
        decided = true
    elseif reading.tone_family === TONE_URGENT
        hint = FRAME_IMPERATIVE
        push!(reasoning, :urgent_tone)
        decided = true
    elseif reading.tone_family === TONE_REFLECTIVE
        hint = FRAME_CONTEMPLATIVE
        push!(reasoning, :reflective_tone)
        decided = true
    end

    # Priority 2: coherence safety net
    if !decided && reading.coherence <= 0.3
        hint = FRAME_TERSE
        push!(reasoning, :low_coherence_safety)
        decided = true
    end

    # Priority 3: dangling chain → invite completion
    if !decided
        for tok in reading.tokens
            if tok.category === TOK_FORM && tok.name === :dangling_chain
                hint = FRAME_CONTEMPLATIVE
                push!(reasoning, :dangling_chain)
                decided = true
                break
            end
        end
    end

    # Priority 4: arousal swing across observation — fall back to action lookup
    # but tag the reasoning so the diagnostic shows what fired us into relational.
    # Same ts > 0 guard as pick_mode.
    if !decided
        if observation.ts > 0.0
            swing = abs(reading.arousal_nudge - observation.last_arousal)
            if swing > _AROUSAL_SWING_THRESHOLD
                push!(reasoning, :arousal_swing)
            end
        end
        hint = frame_hint_for_action(reading.action_family)
        push!(reasoning, :action_lookup_fallback)
    end

    return TonalJudgement(
        RELATIONAL,
        hint,
        reading.tokens,
        reasoning,
        time()
    )
end

# ==============================================================================
# THE JUDGE ENTRY POINT
# ==============================================================================

"""
    judge(reading::TonalReading, observation::NamedTuple) -> TonalJudgement

Pick a judgement mode based on the situation, then dispatch to the
appropriate judge. The judge is deterministic given (reading, observation).
The biology lives in the predictor's jitter; the judge is the calm voice on top.
"""
function judge(reading::TonalReading, observation::NamedTuple)::TonalJudgement
    mode = pick_mode(reading, observation)
    return mode === BASIC ? _judge_basic(reading) : _judge_relational(reading, observation)
end

# ==============================================================================
# LAST JUDGEMENT GLOBAL — parallel to LAST_PREDICTION
# ==============================================================================
#
# Set by the convenience wrapper (or by the engine after each prediction).
# Read by diagnostics, the [FRAME=...] tag, and (in b-3) the scaffold layer.

const LAST_JUDGEMENT = Ref{Union{Nothing, TonalJudgement}}(nothing)
const _JUDGEMENT_LOCK = ReentrantLock()

"""
    judge_from_prediction(pred::PredictionResult) -> TonalJudgement

Convenience: build a reading from the prediction, pull the current
observation state, judge, and stash on `LAST_JUDGEMENT`.
"""
function judge_from_prediction(pred::PredictionResult)::TonalJudgement
    reading = build_reading_from_prediction(pred)
    obs = get_tonal_observation()
    j = judge(reading, obs)
    lock(_JUDGEMENT_LOCK) do
        LAST_JUDGEMENT[] = j
    end
    return j
end

get_last_judgement() = lock(_JUDGEMENT_LOCK) do; LAST_JUDGEMENT[] end

function reset_last_judgement!()
    lock(_JUDGEMENT_LOCK) do
        LAST_JUDGEMENT[] = nothing
    end
    return nothing
end

# ==============================================================================
# v7.21b-3b: FRAME-MATCH MULTIPLIER  (orchestration quorum field, plug-matching)
# ==============================================================================
#
# Per the user direction:
#
#   "AIML is an orchestration quorum field. It just needs matching plugs."
#   "A mismatch should act as inhibitor. In a meta kind of way. It's not
#    doing nothing. It adds a certain richness."
#   Decision (c): "inhibit fires ONLY under relational mode (basic mode =
#                 no inhibit, lift still works on both modes)."
#
# Each node may declare a list of `frame_hints` in its `json_data`:
#
#     "frame_hints": ["de_escalating", "terse"]
#
# These are the "plugs" the node exposes. At vote time we pull the current
# `LAST_JUDGEMENT` and compare its `frame_hint` against the node's plug list:
#
#   match     -> LIFT_MULTIPLIER  (default 1.20)  -- always applies, both modes
#   no plugs  -> NEUTRAL          (1.0)           -- back-compat for legacy nodes
#   mismatch  -> INHIBIT_MULTIPLIER (0.85)        -- ONLY under RELATIONAL mode;
#                                                   under BASIC it stays 1.0 so
#                                                   the 76% basic-mode majority
#                                                   doesn't quietly suppress
#                                                   nodes that just happened to
#                                                   wear a wrong-shaped plug.
#
# The multiplier is applied at the END of `composite_vote_score` (after the
# additive bonuses and anti-match penalty). This keeps it as a clean
# orthogonal dimension: tone-as-tilt at the orchestration layer, mirroring
# tone-as-tilt at the prediction layer.
#
# Multipliers ship as `Ref` (configurable at runtime, tunable from data) NOT
# `const`, so kitchen-sink runs and prod can dial without code surgery.
# ==============================================================================

const _FRAME_LIFT_MULTIPLIER    = Ref{Float64}(1.20)
const _FRAME_INHIBIT_MULTIPLIER = Ref{Float64}(0.85)

"""
    set_frame_match_weights!(; lift::Float64=1.20, inhibit::Float64=0.85)

Tune the frame-match multipliers at runtime.

`lift` must be >= 1.0 (a match should never demote).
`inhibit` must be in (0, 1] (a mismatch should never amplify).
Pass either kwarg alone to tweak just one knob.

Returns the new (lift, inhibit) tuple.
"""
function set_frame_match_weights!(; lift::Union{Nothing,Float64}=nothing,
                                    inhibit::Union{Nothing,Float64}=nothing)
    lock(_JUDGEMENT_LOCK) do
        if lift !== nothing
            lift < 1.0 && error("set_frame_match_weights!: lift must be >= 1.0, got $lift")
            _FRAME_LIFT_MULTIPLIER[] = lift
        end
        if inhibit !== nothing
            (inhibit <= 0.0 || inhibit > 1.0) &&
                error("set_frame_match_weights!: inhibit must be in (0, 1], got $inhibit")
            _FRAME_INHIBIT_MULTIPLIER[] = inhibit
        end
        return (_FRAME_LIFT_MULTIPLIER[], _FRAME_INHIBIT_MULTIPLIER[])
    end
end

"""
    get_frame_match_weights() -> (lift, inhibit)

Read the current multipliers. Mostly for diagnostics and tests.
"""
get_frame_match_weights() = lock(_JUDGEMENT_LOCK) do; (_FRAME_LIFT_MULTIPLIER[], _FRAME_INHIBIT_MULTIPLIER[]) end

"""
    compute_frame_match_multiplier(node_frame_hints, judgement) -> Float64

GRUG: This is the plug-matching step. Given a node's declared `frame_hints`
list (as `Vector{String}`, may be empty) and the current `TonalJudgement`
(may be `nothing`), return the multiplicative factor applied to the
node's vote score.

Decision table:

    judgement is nothing                        -> 1.0  (no judge, no opinion)
    node_frame_hints is empty                   -> 1.0  (no plugs declared = neutral)
    judgement.frame_hint label IN node_hints    -> LIFT
    judgement.frame_hint label NOT IN node_hints AND mode == RELATIONAL -> INHIBIT
    judgement.frame_hint label NOT IN node_hints AND mode == BASIC      -> 1.0
                                                                        (gated per
                                                                         user "(c)")

This is intentionally a pure function so it's trivial to test and reason
about.  The orchestration layer reads node hints + judgement and calls this.
"""
function compute_frame_match_multiplier(node_frame_hints, judgement)::Float64
    judgement === nothing && return 1.0
    isempty(node_frame_hints) && return 1.0  # back-compat: legacy nodes pass through

    # GRUG: Normalize labels — case-insensitive, and hyphens/underscores are
    # interchangeable. The internal `frame_hint_label` uses "de-escalating"
    # (hyphen, log-grep-friendly) while node JSON tends to write
    # "de_escalating" (underscore, identifier-friendly). Fold both to the
    # same canonical form for matching.
    _canon(s) = replace(lowercase(string(s)), '-' => '_')

    judged_label = _canon(frame_hint_label(judgement.frame_hint))

    matched = any(_canon(h) == judged_label for h in node_frame_hints)

    if matched
        return lock(_JUDGEMENT_LOCK) do; _FRAME_LIFT_MULTIPLIER[] end
    end

    # Mismatch path: inhibit fires ONLY under relational mode.  Under basic
    # mode we leave it at neutral so the cheap autopilot path doesn't silently
    # suppress mis-plugged nodes.
    if judgement.mode === RELATIONAL
        return lock(_JUDGEMENT_LOCK) do; _FRAME_INHIBIT_MULTIPLIER[] end
    end

    return 1.0
end

end # module TonalJudge
