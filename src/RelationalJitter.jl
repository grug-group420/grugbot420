# ==============================================================================
# RelationalJitter.jl — GRUG Per-Activation Entropy Nudge for Relational Values
# ==============================================================================
# GRUG say: some rocks always land on exact center of target. Too clean!
# GRUG say: add tiny shake to rock right before it lands, then rock snap back.
# GRUG say: shake is different every time, but on average shake is ZERO.
# GRUG say: many throws add up to bullseye still — no drift, just texture.
# GRUG say: this help weaker neighbor votes sometimes beat exact-tie votes.
# GRUG say: NO NaN. NO Inf. NO sign flip. NO silent failure. Grug check all.
# ==============================================================================
#
# ACADEMIC: Per-activation additive perturbation of relational match-score
# components. Each invocation draws a fresh symmetric uniform nudge
#   δ ~ U(-ε·|x|, +ε·|x|)   with   ε = JITTER_RATIO  (default 0.03)
# and returns `x + δ`. The "snap back to normal" property is statistical:
#
#   E[x + δ] = x                        (zero-mean perturbation)
#   Var[x + δ] = ε² · x² / 3            (bounded second moment)
#
# Because the nudge is regenerated on every call and never persisted, any
# given score is displaced at most ±ε·|x| from its deterministic value in
# a single activation, and the empirical mean over many activations
# converges back to the deterministic value by the LLN. In effect the
# bullseye is preserved in expectation while tie-breaking neighborhoods
# around the bullseye become explorable.
#
# The jitter is DISABLED by zero input (0.0 stays 0.0 exactly) and by the
# sentinel −9999.0 (hard requirement miss — must propagate untouched) and
# by the module-level ENABLED flag (for deterministic tests).
# ==============================================================================

module RelationalJitter

using Random
using Base.Threads: ReentrantLock

export JITTER_RATIO_DEFAULT, HARD_REQ_MISS_SENTINEL
export JitterConfig, JitterError
export jitter_value, jitter_score, jitter_weight
export enable_jitter!, disable_jitter!, is_jitter_enabled
export set_jitter_ratio!, get_jitter_ratio

# ==============================================================================
# ERROR TYPE — GRUG hate silent failures
# ==============================================================================

# GRUG: Dedicated error so callers can distinguish jitter bugs from other
# engine errors without string-matching on messages.
struct JitterError <: Exception
    message::String
    context::String
end

function throw_jitter_error(msg::String, ctx::String = "unknown")
    throw(JitterError(msg, ctx))
end

function Base.showerror(io::IO, e::JitterError)
    print(io, "JitterError: $(e.message) (context=$(e.context))")
end

# ==============================================================================
# CONSTANTS — GRUG put magic numbers in one place
# ==============================================================================

# GRUG: Default nudge ratio. 3% means a bullseye value of 1.0 gets shaken
# into [0.97, 1.03]. Small enough to not flip semantic outcomes, big enough
# to break exact ties and let quiet neighbors occasionally win a coinflip.
const JITTER_RATIO_DEFAULT = 0.03

# GRUG: Hard cap on ratio — bigger than this is not a nudge, it's noise.
# ACADEMIC: At 10% the perturbation starts interacting with the
# match_score / orthogonal_penalty ratios in evaluate_relational_dialectics
# (0.5 / 1.0 = 0.5 — a 10% nudge moves both into each other's neighborhoods).
const JITTER_RATIO_MAX = 0.10

# GRUG: Hard cap on absolute nudge for any single value. Prevents a freak
# nudge on a huge score (e.g., 1000.0) from moving it by 30.0.
const JITTER_ABS_CAP = 1.0

# GRUG: Sentinel value from evaluate_relational_dialectics for hard
# requirement miss. MUST propagate untouched — jittering it would turn a
# definitive rejection into a soft signal. See engine.jl §relational.
const HARD_REQ_MISS_SENTINEL = -9999.0

# GRUG: Values with |x| below this are treated as "effectively zero" and
# returned untouched. A nudge on 1e-15 would dominate the value.
const JITTER_EPS_FLOOR = 1e-9

# ==============================================================================
# CONFIG — GRUG keep toggles tight and thread-safe
# ==============================================================================

# GRUG: Ratio lives in a Ref so tests can tune it without mutating a const.
# Lock protects the rare write path; read path is lockless atomic by Julia
# memory model for Ref{Float64} (single-word read).
const _JITTER_RATIO  = Ref{Float64}(JITTER_RATIO_DEFAULT)
const _JITTER_ENABLED = Ref{Bool}(true)
const _CONFIG_LOCK    = ReentrantLock()

"""
    enable_jitter!()

Turn the per-activation jitter ON globally. Default state at module load.
"""
function enable_jitter!()
    lock(_CONFIG_LOCK) do
        _JITTER_ENABLED[] = true
    end
    return nothing
end

"""
    disable_jitter!()

Turn the per-activation jitter OFF globally. Every `jitter_*` call becomes
the identity function. Used by tests that need bit-exact reproducibility.
"""
function disable_jitter!()
    lock(_CONFIG_LOCK) do
        _JITTER_ENABLED[] = false
    end
    return nothing
end

"""
    is_jitter_enabled() -> Bool

Returns the current global jitter state.
"""
is_jitter_enabled()::Bool = _JITTER_ENABLED[]

"""
    set_jitter_ratio!(r::Float64)

Set the maximum nudge ratio. Must satisfy `0.0 <= r <= JITTER_RATIO_MAX`.
Throws `JitterError` on out-of-bounds, NaN, or Inf input — NO silent clamp.
"""
function set_jitter_ratio!(r::Float64)
    if isnan(r)
        throw_jitter_error("ratio is NaN", "set_jitter_ratio!")
    end
    if isinf(r)
        throw_jitter_error("ratio is Inf", "set_jitter_ratio!")
    end
    if r < 0.0
        throw_jitter_error("ratio $r is negative; must be in [0.0, $JITTER_RATIO_MAX]", "set_jitter_ratio!")
    end
    if r > JITTER_RATIO_MAX
        throw_jitter_error("ratio $r exceeds hard cap $JITTER_RATIO_MAX", "set_jitter_ratio!")
    end
    lock(_CONFIG_LOCK) do
        _JITTER_RATIO[] = r
    end
    return nothing
end

"""
    get_jitter_ratio() -> Float64

Returns the current maximum nudge ratio.
"""
get_jitter_ratio()::Float64 = _JITTER_RATIO[]

# ==============================================================================
# CORE PRIMITIVE — GRUG do the actual shake here
# ==============================================================================

"""
    jitter_value(x::Float64; ratio::Float64 = get_jitter_ratio()) -> Float64

Return `x` with a fresh symmetric uniform nudge applied. Zero-mean, so
repeated calls average back to `x` (the "snap-back-to-normal" property).

Behavior:
- If jitter is globally disabled → return `x` unchanged.
- If `x` is NaN or Inf → throw `JitterError` (NO silent failures).
- If `x == HARD_REQ_MISS_SENTINEL` → return sentinel unchanged.
- If `|x| < JITTER_EPS_FLOOR` → return `x` unchanged (no nudge on zero).
- Otherwise: draw δ ~ U(−ε·|x|, +ε·|x|), clamp |δ| ≤ `JITTER_ABS_CAP`,
  return `x + δ`.

The per-call `ratio` kwarg overrides the global setting for this one call,
useful when a specific stage wants a tighter or looser nudge. Out-of-bounds
ratios throw `JitterError` — same as `set_jitter_ratio!`.
"""
function jitter_value(x::Float64; ratio::Float64 = get_jitter_ratio())::Float64
    # GRUG: Fail loud on bad inputs.
    if isnan(x)
        throw_jitter_error("input is NaN", "jitter_value")
    end
    if isinf(x)
        throw_jitter_error("input is Inf", "jitter_value")
    end
    if isnan(ratio) || isinf(ratio)
        throw_jitter_error("ratio is NaN/Inf", "jitter_value")
    end
    if ratio < 0.0 || ratio > JITTER_RATIO_MAX
        throw_jitter_error("ratio $ratio out of [0.0, $JITTER_RATIO_MAX]", "jitter_value")
    end

    # GRUG: Global kill switch — test mode returns identity.
    if !_JITTER_ENABLED[]
        return x
    end

    # GRUG: Sentinel propagates untouched. A nudged -9999.0 would still be
    # a miss numerically, but callers compare by equality, so corruption
    # here would break the hard-requirement contract in dialectics.
    if x == HARD_REQ_MISS_SENTINEL
        return x
    end

    # GRUG: Zero (and effectively-zero) stays zero. Nudging 0.0 by ratio
    # gives 0.0 anyway, but the floor avoids nonsense on denormals like 1e-300.
    ax = abs(x)
    if ax < JITTER_EPS_FLOOR
        return x
    end

    # GRUG: Symmetric uniform nudge on [−ε·|x|, +ε·|x|]. rand() is [0,1),
    # so (2·rand() − 1) is (-1, 1]. Zero-mean by construction.
    span = ratio * ax
    δ = (2.0 * rand() - 1.0) * span

    # GRUG: Absolute cap — a nudge on a big score stays sane.
    if δ > JITTER_ABS_CAP
        δ = JITTER_ABS_CAP
    elseif δ < -JITTER_ABS_CAP
        δ = -JITTER_ABS_CAP
    end

    return x + δ
end

# ==============================================================================
# SEMANTIC WRAPPERS — GRUG name the intent at each call site
# ==============================================================================

"""
    jitter_score(s::Float64) -> Float64

Nudge a match-score component. Thin wrapper around `jitter_value` so call
sites read as intent-carrying ("jitter this score") rather than a bare
primitive. Same contract as `jitter_value`.
"""
jitter_score(s::Float64)::Float64 = jitter_value(s)

"""
    jitter_weight(w::Float64) -> Float64

Nudge a relation weight. Weights are bounded positive multipliers; the
nudge preserves sign because it is strictly smaller in magnitude than `w`
(ratio < 1.0 by the `set_jitter_ratio!` bound). Same contract as
`jitter_value`.
"""
jitter_weight(w::Float64)::Float64 = jitter_value(w)

# ==============================================================================
# CONFIG STRUCT — GRUG for when a caller wants a scoped nudge policy
# ==============================================================================

"""
    JitterConfig(ratio::Float64, enabled::Bool)

Immutable bundle for passing jitter policy through an API without touching
the global state. Use `jitter_value(x; ratio = cfg.ratio)` and guard with
`cfg.enabled` at the call site.
"""
struct JitterConfig
    ratio::Float64
    enabled::Bool

    function JitterConfig(ratio::Float64, enabled::Bool)
        if isnan(ratio) || isinf(ratio)
            throw_jitter_error("config ratio NaN/Inf", "JitterConfig")
        end
        if ratio < 0.0 || ratio > JITTER_RATIO_MAX
            throw_jitter_error("config ratio $ratio out of [0.0, $JITTER_RATIO_MAX]", "JitterConfig")
        end
        new(ratio, enabled)
    end
end

end # module RelationalJitter