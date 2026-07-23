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

export JITTER_RATIO_DEFAULT, HARD_REQ_MISS_SENTINEL
export JITTER_COIN_RATIO_DEFAULT, JITTER_COIN_FLOOR, JITTER_COIN_CEILING
export JITTER_BRAINSTORM_RATIO, JITTER_BRAINSTORM_COIN_RATIO
export JitterConfig, JitterError, JitterScopeError
export jitter_value, jitter_score, jitter_weight
export jitter_strength, jitter_delta, jitter_coin_threshold
export enable_jitter!, disable_jitter!, is_jitter_enabled
export set_jitter_ratio!, get_jitter_ratio
export set_jitter_coin_ratio!, get_jitter_coin_ratio
export with_brainstorm_jitter, is_brainstorm_active, get_brainstorm_depth

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

# GRUG: Separate error type for scope-policy violations (nested brainstorm,
# unbalanced enter/exit, etc.). Distinct from JitterError so callers can
# special-case scope misuse without touching NaN/Inf handling.
struct JitterScopeError <: Exception
    message::String
    context::String
end

function throw_jitter_scope_error(msg::String, ctx::String = "unknown")
    throw(JitterScopeError(msg, ctx))
end

function Base.showerror(io::IO, e::JitterScopeError)
    print(io, "JitterScopeError: $(e.message) (context=$(e.context))")
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
# COIN-THRESHOLD JITTER — GRUG nudge the 50/50 bias, not just the payout
# ==============================================================================
# ACADEMIC: Coin-threshold jitter is an ADDITIVE perturbation on probabilities
# like `rand() < 0.5`. It differs from `jitter_value`:
#   (a) the "bullseye" is typically 0.5 — a value near zero under the ratio
#       interpretation — so proportional nudging is useless here.
#   (b) the result MUST stay in [0, 1] to remain a valid probability.
#   (c) we want a tight absolute-magnitude window by default, not a %-of-value
#       window. 50 ± 1% is the right feel for AIML reward gates.
#
# Formula for jitter_coin_threshold:
#   δ ~ U(-ρ, +ρ)  with  ρ = JITTER_COIN_RATIO   (default 0.01 = ±1 percentage point)
#   result = clamp(p + δ, JITTER_COIN_FLOOR, JITTER_COIN_CEILING)
#
# The floor/ceiling (default 0.01/0.99) guard against accidentally producing a
# gate that fires either NEVER or ALWAYS — both of which would silently break
# downstream coin-gated logic. A gate becoming a permanent yes/no is a
# catastrophic behavior shift, so we refuse to let jitter produce it.

# GRUG: Default ± percentage-point swing on coin-threshold. 0.01 means a 0.5
# gate fluctuates in [0.49, 0.51] — enough to break locked-in 50/50 streaks
# but not enough to meaningfully shift the long-run fire/skip ratio.
const JITTER_COIN_RATIO_DEFAULT = 0.01

# GRUG: Maximum coin-ratio accepted. Beyond this we are not "nudging" the
# gate — we are deciding for it.
const JITTER_COIN_RATIO_MAX = 0.10

# GRUG: Lower / upper clamps so the result never becomes a degenerate
# gate (always-yes or always-no). ACADEMIC: corresponds to requiring the
# Bernoulli parameter to stay interior to (0, 1).
const JITTER_COIN_FLOOR    = 0.01
const JITTER_COIN_CEILING  = 0.99

# ==============================================================================
# BRAINSTORM MODE — GRUG take bigger jumps, then snap back
# ==============================================================================
# ACADEMIC: "Brainstorm" is a scoped policy override that temporarily raises
# both the value-jitter ratio and the coin-threshold ratio to their
# "far-jump" settings for the duration of a single scope (typically one
# mission). Outside the scope the ratios are bit-exact restored to whatever
# they were before scope entry. The intuition is simulated-annealing-lite:
# a short burst of higher variance lets the engine escape a local minimum
# it would otherwise stay trapped in under the default small-nudge ratio.
#
# Constraints on the defaults:
#   (a) Both brainstorm ratios MUST stay within the permanent hard caps
#       (JITTER_RATIO_MAX = 0.10, JITTER_COIN_RATIO_MAX = 0.10) so that
#       any code path that validates against the caps still sees a legal
#       value during the scope.
#   (b) The coin brainstorm ratio kept well below 0.5 so even a full
#       negative swing cannot drag the 50/50 gate across the 0/1 boundary
#       (the floor/ceiling clamp would catch it anyway, but we want the
#       clamp to be a safety net, not the normal operating point).
#   (c) Proportional brainstorm ratio kept below 0.10 so sign preservation
#       on deltas still holds mathematically (|δ| < ratio·|x| < |x|).

# GRUG: Far-jump value-jitter ratio. 8% means a bullseye of 5.0 gets shaken
# into [4.6, 5.4] — wide enough to occasionally let a weaker neighbor at
# 4.5 actually beat it on a single activation, but still under the 10%
# hard cap so no validator explodes mid-scope.
const JITTER_BRAINSTORM_RATIO = 0.08

# GRUG: Far-jump coin-threshold ratio. 5 percentage points means a 0.5
# gate fluctuates in [0.45, 0.55] per activation — enough swing to break
# the 50/50 lockstep firmly, still well inside the [0.01, 0.99] interior.
const JITTER_BRAINSTORM_COIN_RATIO = 0.05

# ==============================================================================
# CONFIG — GRUG keep toggles tight and thread-safe
# ==============================================================================

# GRUG: Ratio lives in a Ref so tests can tune it without mutating a const.
# Lock protects the rare write path; read path is lockless atomic by Julia
# memory model for Ref{Float64} (single-word read).
const _JITTER_RATIO      = Ref{Float64}(JITTER_RATIO_DEFAULT)
const _JITTER_COIN_RATIO = Ref{Float64}(JITTER_COIN_RATIO_DEFAULT)
const _JITTER_ENABLED    = Ref{Bool}(true)
const _CONFIG_LOCK       = ReentrantLock()

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

"""
    set_jitter_coin_ratio!(r::Float64)

Set the maximum ± percentage-point swing for coin-threshold jitter. Must
satisfy `0.0 <= r <= JITTER_COIN_RATIO_MAX`. Throws `JitterError` on NaN,
Inf, or out-of-range input — NO silent clamp.
"""
function set_jitter_coin_ratio!(r::Float64)
    if isnan(r)
        throw_jitter_error("coin ratio is NaN", "set_jitter_coin_ratio!")
    end
    if isinf(r)
        throw_jitter_error("coin ratio is Inf", "set_jitter_coin_ratio!")
    end
    if r < 0.0
        throw_jitter_error("coin ratio $r is negative; must be in [0.0, $JITTER_COIN_RATIO_MAX]",
                           "set_jitter_coin_ratio!")
    end
    if r > JITTER_COIN_RATIO_MAX
        throw_jitter_error("coin ratio $r exceeds hard cap $JITTER_COIN_RATIO_MAX",
                           "set_jitter_coin_ratio!")
    end
    lock(_CONFIG_LOCK) do
        _JITTER_COIN_RATIO[] = r
    end
    return nothing
end

"""
    get_jitter_coin_ratio() -> Float64

Returns the current ± coin-threshold swing.
"""
get_jitter_coin_ratio()::Float64 = _JITTER_COIN_RATIO[]

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

"""
    jitter_strength(s::Float64) -> Float64

Nudge an AIML node strength value. Intent-carrying wrapper around
`jitter_value` for the executive-layer strength field. Same contract:
NaN/Inf throw, zero passes through, sentinel propagates, result stays
within ratio·|s| of `s`. The AIML layer itself is responsible for the
final `clamp(.., AIML_STRENGTH_FLOOR, AIML_STRENGTH_CAP)` that keeps
strength inside its legal range — jitter does not perform that clamp
because it does not know the caller's legal range.
"""
jitter_strength(s::Float64)::Float64 = jitter_value(s)

"""
    jitter_delta(d::Float64) -> Float64

Nudge a strength-delta value (reward or penalty magnitude). Wrapper around
`jitter_value` carrying intent at the AIML call site. Sign is preserved
because ratio is bounded below 1.0, so a +1.0 delta stays positive and a
−1.0 delta stays negative. The grave-transition behavior in
`_apply_strength_delta!` is preserved because: (a) the grave-trigger
condition is `strength <= FLOOR`, which is checked on the clamped new
strength, not on the delta itself; and (b) zero deltas pass through
unchanged, so a caller requesting exactly-zero change still gets zero.
"""
jitter_delta(d::Float64)::Float64 = jitter_value(d)

"""
    jitter_coin_threshold(p::Float64; ratio::Float64 = get_jitter_coin_ratio()) -> Float64

Return `p` perturbed by a uniform ± `ratio` additive nudge, then clamped
into `[JITTER_COIN_FLOOR, JITTER_COIN_CEILING]`. Intended for thresholds
used in `rand() < p` coin gates (e.g. AIML reward/penalty gates).

Contract:
- If jitter is globally disabled → return `p` unchanged.
- If `p` is NaN or Inf → throw `JitterError`.
- If `p < 0.0` or `p > 1.0` → throw `JitterError` (it is not a probability).
- Out-of-range `ratio` kwarg → throw `JitterError`.
- Otherwise: draw δ ~ U(−ratio, +ratio), clamp `p + δ` to
  [`JITTER_COIN_FLOOR`, `JITTER_COIN_CEILING`].

The clamp to (0, 1) interior prevents the nudge from silently turning a
50/50 gate into a degenerate always-fire or never-fire gate. This is the
coin-threshold analogue of the sentinel pass-through rule for scores.
"""
function jitter_coin_threshold(p::Float64; ratio::Float64 = get_jitter_coin_ratio())::Float64
    # GRUG: Fail loud on bad inputs. A coin threshold that is NaN would
    # silently make every `rand() < p` fail because NaN comparisons are false.
    if isnan(p)
        throw_jitter_error("probability is NaN", "jitter_coin_threshold")
    end
    if isinf(p)
        throw_jitter_error("probability is Inf", "jitter_coin_threshold")
    end
    if p < 0.0 || p > 1.0
        throw_jitter_error("probability $p is outside [0.0, 1.0]", "jitter_coin_threshold")
    end
    if isnan(ratio) || isinf(ratio)
        throw_jitter_error("coin ratio is NaN/Inf", "jitter_coin_threshold")
    end
    if ratio < 0.0 || ratio > JITTER_COIN_RATIO_MAX
        throw_jitter_error("coin ratio $ratio out of [0.0, $JITTER_COIN_RATIO_MAX]",
                           "jitter_coin_threshold")
    end

    # GRUG: Global kill switch — test mode returns identity.
    if !_JITTER_ENABLED[]
        return p
    end

    # GRUG: Symmetric uniform on (-ratio, +ratio]. Zero-mean.
    δ = (2.0 * rand() - 1.0) * ratio

    # GRUG: Clamp to legal interior. The floor/ceiling guards against
    # a single freak nudge turning the gate into always-yes or always-no.
    nudged = p + δ
    if nudged < JITTER_COIN_FLOOR
        nudged = JITTER_COIN_FLOOR
    elseif nudged > JITTER_COIN_CEILING
        nudged = JITTER_COIN_CEILING
    end
    return nudged
end

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

# ==============================================================================
# BRAINSTORM SCOPE — GRUG scoped heavy-jitter policy override
# ==============================================================================
# GRUG: Brainstorm state uses a depth counter instead of a bare Bool so that
# a future change to support nested-but-coalesced scopes is a one-line edit.
# Today we REFUSE nested scopes and throw JitterScopeError on the second
# entry — that's the safe default because nested ratio restoration would
# otherwise have to track the push/pop history in full. If the need for
# nesting arises, switch "depth != 0" to "push saved ratios onto a stack".
const _BRAINSTORM_DEPTH = Ref{Int}(0)

"""
    is_brainstorm_active() -> Bool

Returns `true` if execution is currently inside a `with_brainstorm_jitter`
scope (including the body of the caller's function).
"""
is_brainstorm_active()::Bool = _BRAINSTORM_DEPTH[] > 0

"""
    get_brainstorm_depth() -> Int

Returns the current brainstorm nesting depth. 0 means inactive. The public
API refuses depths > 1 today; this accessor exists primarily for
diagnostics and for tests that assert clean enter/exit symmetry.
"""
get_brainstorm_depth()::Int = _BRAINSTORM_DEPTH[]

"""
    with_brainstorm_jitter(f;
                           ratio = JITTER_BRAINSTORM_RATIO,
                           coin_ratio = JITTER_BRAINSTORM_COIN_RATIO) -> Any

Execute `f()` with the value-jitter and coin-threshold ratios temporarily
raised to `ratio` and `coin_ratio`. On exit — whether `f` returns normally
or throws — the previous ratios are restored exactly. This is the
"far jump, then snap back" primitive: a scoped policy override that widens
the per-activation nudge window for the duration of one mission so the
engine can escape a local minimum it would otherwise stay stuck in.

Invariants enforced:
- Nested calls throw `JitterScopeError` with context `"with_brainstorm_jitter"`.
  Nesting would require stacking saved ratios; we refuse rather than
  silently take the outermost setting.
- Ratio arguments are validated against the permanent hard caps
  (`JITTER_RATIO_MAX` and `JITTER_COIN_RATIO_MAX`). Out-of-range, NaN, or
  Inf values throw `JitterError` (same type as `set_jitter_ratio!`) —
  no silent clamp.
- If `f` throws, the saved ratios are restored AND the exception rethrows.
  The `try/finally` block guarantees bit-exact restoration of both the
  ratios and the depth counter regardless of exit path.
- The global `enable_jitter!` / `disable_jitter!` toggle is orthogonal to
  brainstorm scope — if jitter is globally disabled, brainstorm still
  returns identity from every `jitter_*` primitive. Brainstorm only
  controls the *magnitude* when jitter is enabled; it does not force
  jitter on.

Returns whatever `f()` returns.

Example:

    with_brainstorm_jitter() do
        process_mission(user_prompt)
    end
"""
function with_brainstorm_jitter(
    f;
    ratio::Float64 = JITTER_BRAINSTORM_RATIO,
    coin_ratio::Float64 = JITTER_BRAINSTORM_COIN_RATIO,
)
    # GRUG: Validate ratios BEFORE touching any state. If they're bad, we
    # throw without having mutated anything — caller can retry with sane
    # values without worrying about leaked state.
    if isnan(ratio) || isinf(ratio)
        throw_jitter_error("brainstorm ratio NaN/Inf", "with_brainstorm_jitter")
    end
    if ratio < 0.0 || ratio > JITTER_RATIO_MAX
        throw_jitter_error(
            "brainstorm ratio $ratio out of [0.0, $JITTER_RATIO_MAX]",
            "with_brainstorm_jitter",
        )
    end
    if isnan(coin_ratio) || isinf(coin_ratio)
        throw_jitter_error("brainstorm coin_ratio NaN/Inf", "with_brainstorm_jitter")
    end
    if coin_ratio < 0.0 || coin_ratio > JITTER_COIN_RATIO_MAX
        throw_jitter_error(
            "brainstorm coin_ratio $coin_ratio out of [0.0, $JITTER_COIN_RATIO_MAX]",
            "with_brainstorm_jitter",
        )
    end

    # GRUG: Enter-scope critical section. Depth check + ratio save + ratio
    # push must be atomic relative to other scope attempts, otherwise two
    # concurrent missions could both see depth==0, both push, and the
    # second's finally block would restore wrong saved ratios.
    saved_ratio::Float64       = 0.0
    saved_coin_ratio::Float64  = 0.0
    lock(_CONFIG_LOCK) do
        if _BRAINSTORM_DEPTH[] != 0
            # GRUG: Nested scope. Refuse loudly — silent coalescing would
            # mean an inner scope's "restore" undoes an outer scope's
            # heavy ratios, which is a correctness bug masquerading as
            # a convenience feature.
            throw_jitter_scope_error(
                "nested with_brainstorm_jitter is not supported (current depth=$(_BRAINSTORM_DEPTH[]))",
                "with_brainstorm_jitter",
            )
        end
        saved_ratio       = _JITTER_RATIO[]
        saved_coin_ratio  = _JITTER_COIN_RATIO[]
        _JITTER_RATIO[]      = ratio
        _JITTER_COIN_RATIO[] = coin_ratio
        _BRAINSTORM_DEPTH[]  = 1
    end

    # GRUG: Try/finally guarantees exit-scope runs on every exit path:
    # normal return, exception, or early return inside f.
    try
        return f()
    finally
        lock(_CONFIG_LOCK) do
            # GRUG: Restore ratios first, THEN drop depth. Ordering matters
            # only if somebody mid-teardown tried to enter a new scope,
            # but the lock serializes that anyway.
            _JITTER_RATIO[]      = saved_ratio
            _JITTER_COIN_RATIO[] = saved_coin_ratio
            _BRAINSTORM_DEPTH[]  = 0
        end
    end
end

end # module RelationalJitter