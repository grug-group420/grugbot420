module PatternScanner

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

export cheap_scan, medium_scan, high_res_scan
export PatternScanError, PatternNotFoundError
export big_number_small_number_coherence
export slight_jitter

# GRUG: Bring magic random bones for math (jitter).
using Random

# ==============================================================================
# 1. STRICT ERROR HANDLING (NO SILENT FAILURES)
# ==============================================================================

# GRUG: Grug no like quiet failures. If rock is bad or pattern missing, Grug scream loud!
# No return false, no return nothing. ONLY SCREAM!
abstract type AbstractScannerError <: Exception end

"""
Thrown when logical inputs to the scanner are invalid (e.g., empty arrays or mismatched lengths).
"""
struct PatternScanError <: AbstractScannerError
    msg::String
end

"""
Thrown when the target pattern cannot be resolved within the provided threshold limits.
Includes the highest confidence found before failing, for debug visibility.
"""
struct PatternNotFoundError <: AbstractScannerError
    msg::String
    highest_confidence::Float64
end

Base.showerror(io::IO, e::PatternScanError) = print(io, "PatternScanError: ", e.msg)
Base.showerror(io::IO, e::PatternNotFoundError) = print(io, "PatternNotFoundError: $(e.msg) (Highest Confidence: $(round(e.highest_confidence, digits=4)))")

# ==============================================================================
# 2. CORE LOGIC & JITTER
# ==============================================================================

# GRUG: Perfect bullseye is fake! Nature always shakes.
# Grug use bounded uniform shake so math tails don't reach infinity.
function slight_jitter(confidence::Float64)::Float64
    # Jitter scales slightly with how close to 1.0 (bullseye) we are
    jitter_magnitude = 0.005 + (0.01 * (1.0 - abs(confidence)))
    
    # GRUG FIX: randn() can draw infinitely long tails. 
    # Grug use rand() to keep noise strictly inside the box! [-1.0 to 1.0]
    jitter = (rand() * 2.0 - 1.0) * jitter_magnitude
    
    # Clamp between -1.0 and 1.0 so Grug math doesn't explode
    return clamp(confidence + jitter, -1.0, 1.0)
end

# GRUG: Grug look at window of rocks. 
# If rock look like pattern rock, Grug happy (similarity).
# If rock look different, Grug mad (dissimilarity).
# Confidence = Happy minus Mad. Then Grug shake it!
function evaluate_window(window::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}, tolerance::Real)::Float64
    if length(window) != length(pattern)
        throw(PatternScanError("Window size and pattern size do not match. Internal logic error."))
    end

    sim_count = 0
    dissim_count = 0
    total = length(pattern)

    @inbounds for i in 1:total
        diff = abs(window[i] - pattern[i])
        if diff <= tolerance
            sim_count += 1
        else
            dissim_count += 1
        end
    end

    similarity = sim_count / total
    dissimilarity = dissim_count / total

    # GRUG COHERENCE FIX: Large number small number coherence!
    # If Grug see ANY matching rocks (similarity > 0), Grug put a hard floor of 0.1.
    # Why? Grug want intrinsic matches to stay alive even if user throws a giant pile 
    # of garbage (dissimilarity) rocks around it.
    # If purely noise (similarity == 0), Grug let confidence fall completely negative.
    if similarity > 0
        raw_confidence = max(0.1, similarity - (dissimilarity * 0.1))
    else
        raw_confidence = -dissimilarity
    end
    
    return slight_jitter(raw_confidence)
end

# GRUG: Make sure rocks are real before Grug look at them.
# If pattern bigger than cave, Grug scream.
function _validate_inputs(target::AbstractVector, pattern::AbstractVector)
    if isempty(target) || isempty(pattern)
        throw(PatternScanError("Target or Pattern array cannot be empty."))
    end
    if length(pattern) > length(target)
        throw(PatternScanError("Pattern is larger than the target array."))
    end
end

# ==============================================================================
# 3. SCAN IMPLEMENTATIONS
# ==============================================================================

# GRUG: Fast scan. Grug skip over some rocks (stride) to run fast.
# Lazy but fast! If Grug find nothing, Grug no stay quiet—Grug throw error!
function cheap_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
                    tolerance::Real=0.1, threshold::Real=0.6)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    
    # GRUG FIX: Grug legs only so long. Skip some rocks based on length, 
    # but hard clamp the max stride at 8 so Grug doesn't accidentally jump entirely over a mountain.
    stride = clamp(pat_len ÷ 4, 1, 8)
    
    best_conf = -1.0
    best_idx = 0

    # Sliding window with stride
    for i in 1:stride:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance)
        
        if conf > best_conf
            best_conf = conf
            best_idx = i
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("Cheap scan failed to find pattern.", best_conf))
    end

    return (best_idx, best_conf)
end

# GRUG: Normal look. Grug check every single rock. Good balance.
function medium_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
# REMINDER: HOPFIELD CACHING WAS REMOVED. No cache check before scan.
                     tolerance::Real=0.1, threshold::Real=0.75)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    best_conf = -1.0
    best_idx = 0

    # Check every index
    for i in 1:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance)
        
        if conf > best_conf
            best_conf = conf
            best_idx = i
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("Medium scan failed to find pattern.", best_conf))
    end

    return (best_idx, best_conf)
end

# GRUG: High resolution! Grug squint real hard.
# First pass: Grug look for blurry maybe-spots.
# Second pass: Grug measure exact variance. If rocks too weird, Grug punish confidence!
function high_res_scan(target::AbstractVector{<:Real}, pattern::AbstractVector{<:Real}; 
# REMINDER: HOPFIELD CACHING WAS REMOVED. No cache check before scan.
                       tolerance::Real=0.05, threshold::Real=0.90)::Tuple{Int, Float64}
    _validate_inputs(target, pattern)
    
    pat_len = length(pattern)
    candidates = Int[]
    
    # GRUG FIX: Pass 1 uses a mathematically looser threshold (threshold - 0.2)
    # so Grug can find blurry candidate zones before doing heavy variance math.
    looser_threshold = threshold - 0.2
    
    for i in 1:(length(target) - pat_len + 1)
        window = view(target, i:(i + pat_len - 1))
        conf = evaluate_window(window, pattern, tolerance * 2.0) 
        if conf > looser_threshold
            push!(candidates, i)
        end
    end

    if isempty(candidates)
        throw(PatternNotFoundError("High-Res scan pass 1 found no candidate zones.", -1.0))
    end

    # Pass 2: Strict High-Res validation
    best_conf = -1.0
    best_idx = 0

    for idx in candidates
        window = view(target, idx:(idx + pat_len - 1))
        
        # Calculate strict confidence
        conf = evaluate_window(window, pattern, tolerance)
        
        # Penalty for high variance (High Res feature)
        variance = sum(abs2, window .- pattern) / pat_len
        
        # GRUG COHERENCE FIX: Just like the window evaluation, don't let 
        # a high variance penalty completely nuke an already positive tool match.
        if conf > 0
            penalized_conf = max(0.1, conf - (variance * 0.1))
        else
            penalized_conf = conf - (variance * 0.1)
        end
        
        final_conf = slight_jitter(penalized_conf)

        if final_conf > best_conf
            best_conf = final_conf
            best_idx = idx
        end
    end

    if best_conf < threshold
        throw(PatternNotFoundError("High-Res scan pass 2 rejected all candidates.", best_conf))
    end

    return (best_idx, best_conf)
end

# ==============================================================================
# BIG NUMBER SMALL NUMBER COHERENCE
# ==============================================================================

"""
    big_number_small_number_coherence(forward_conf::Real, backward_conf::Real)::Float64

GRUG: Big rock and small rock coherence check. When Grug scan rock forward
and scan rock backward, Grug get two confidence numbers. If Grug just
average them, Grug lose info. Two tiny confidences that "agree" look the
same as two huge confidences that "agree". That is a lie. Big rocks matter
more than small rocks.

This function looks at BOTH the difference AND the magnitudes:
  - Both big and close          -> high coherence (real agreement, strong signal)
  - Both small and close        -> LOW coherence (agreement on noise, no signal)
  - Big but far apart           -> low coherence (scans disagreed on a real thing)
  - One big, one zero           -> moderate coherence (partial match only)

WHY NOT JUST AVERAGE:
  Averaging is broken for two reasons:
  (1) It hides asymmetry. Forward=0.9 / Backward=0.1 and Forward=0.5 /
      Backward=0.5 both average to 0.5, but one is a real disagreement
      and the other is a real agreement.
  (2) Subtraction of close floats loses precision (catastrophic cancellation).
      If both confidences are ~0.847, their difference may be noise in the
      trailing digits. This function normalizes against magnitude so the
      noise does not drive the result.

FORMULA:
  magnitude_floor  = max(|forward|, |backward|)           # strongest signal either side
  magnitude_mean   = (|forward| + |backward|) / 2         # average signal strength
  absolute_delta   = |forward - backward|                 # raw disagreement
  relative_delta   = absolute_delta / magnitude_floor     # delta as fraction of signal
  agreement        = 1.0 - clamp(relative_delta, 0.0, 1.0)
  coherence        = agreement * magnitude_mean           # scale by signal strength

  Special case: if magnitude_floor < COHERENCE_EPSILON (both near zero), return 0.0.
                Two scans that both saw nothing cannot agree on something.

OUTPUT RANGE: [0.0, 1.0]
  1.0  -> both scans saw the same thing with full confidence
  0.5  -> moderate agreement on moderate signal, OR strong agreement on weak signal
  0.0  -> either no signal at all, or flat disagreement

NO SILENT FAILURES: rejects NaN, Inf inputs with PatternScanError.
"""
function big_number_small_number_coherence(forward_conf::Real, backward_conf::Real)::Float64
    # GRUG: Cast to Float64 once so downstream math is consistent.
    fwd = Float64(forward_conf)
    bwd = Float64(backward_conf)

    # GRUG: Reject poison values loudly. NaN and Inf never belong in a
    # confidence score. If they arrive, something upstream is broken and
    # Grug must scream, not quietly propagate rot.
    if isnan(fwd) || isnan(bwd)
        throw(PatternScanError(
            "big_number_small_number_coherence received NaN (forward=$fwd, backward=$bwd)."
        ))
    end
    if isinf(fwd) || isinf(bwd)
        throw(PatternScanError(
            "big_number_small_number_coherence received Inf (forward=$fwd, backward=$bwd)."
        ))
    end

    # GRUG: Absolute magnitudes. Negative confidences are legal (evaluate_window
    # can return negative values when similarity == 0). We compare absolute
    # signal strength, not signed values, so a strong negative and a strong
    # positive still count as "big number" contexts.
    abs_fwd = abs(fwd)
    abs_bwd = abs(bwd)

    magnitude_floor = max(abs_fwd, abs_bwd)
    magnitude_mean  = (abs_fwd + abs_bwd) / 2.0

    # GRUG: Both numbers essentially zero -> no signal at all. Cannot infer
    # coherence from silence. Return 0.0 so downstream routing treats it as
    # "no match" rather than "perfect agreement on nothing".
    COHERENCE_EPSILON = 1.0e-9
    if magnitude_floor < COHERENCE_EPSILON
        return 0.0
    end

    # GRUG: Raw disagreement, measured against the strongest signal.
    # This is the catastrophic-cancellation protection: if abs_fwd and abs_bwd
    # are both ~0.8 and their signed difference is 1e-12 garbage, relative_delta
    # is ~1e-12 which clamps to 0 and agreement stays ~1.0. Noise does not
    # corrupt the result.
    absolute_delta = abs(fwd - bwd)
    relative_delta = absolute_delta / magnitude_floor

    # GRUG: Clamp in case numerical drift pushes it slightly out of [0.0, 1.0].
    agreement = 1.0 - clamp(relative_delta, 0.0, 1.0)

    # GRUG: Scale agreement by signal strength. Two scans agreeing weakly
    # is still weak. Two scans agreeing strongly is strong. This is the
    # "big rock / small rock" differentiator.
    coherence = agreement * magnitude_mean

    # GRUG: Final clamp so downstream consumers always see [0.0, 1.0].
    # agreement is already in [0,1] and magnitude_mean is bounded by the
    # confidences it was built from, so this is defence-in-depth only.
    return clamp(coherence, 0.0, 1.0)
end

end # module

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: PERCEPTUAL SCANNER LAYER
#
# 1. STRICT NO-SILENT-FAILURE ARCHITECTURE:
# The module is completely deterministic in its error routing. It abandons traditional 
# silent returns (e.g., `nothing`, `-1`, or `false`) in favor of explicitly unwinding 
# the stack via `AbstractScannerError`. 
#
# 2. LARGE NUMBER / SMALL NUMBER COHERENCE:
# `evaluate_window` calculates discrete proportional similarity but safely dampens 
# localized dissimilarity. If any positive semantic signal exists (`similarity > 0`),
# a mathematical floor `max(0.1, ...)` acts as a circuit breaker so that excessive 
# user noise does not artificially negate intrinsic structural matches.
#
# 3. DYNAMIC EPHEMERAL JITTER (BULLSEYE RUN):
# `slight_jitter` injects a randomized, bounded uniform micro-variance into the final 
# confidence score. This mathematically models hardware/sensor variance ("running from 
# the bullseye") without allowing infinite Gaussian tails to destabilize output.
#
# 4. BIG-NUMBER / SMALL-NUMBER COHERENCE (v7.19):
# `big_number_small_number_coherence(forward, backward)` fuses paired confidence
# scores into a single coherence value in [0.0, 1.0]. Unlike a naive average, it
# (a) differentiates agreement-on-noise (two tiny confidences) from agreement-on-
# signal (two large confidences), and (b) is immune to catastrophic floating-
# point cancellation between close values. The output is `agreement * mean_magnitude`
# where `agreement = 1 - |forward - backward| / max(|forward|, |backward|)`. This
# replaces the former averaging smoother in `_bidirectional_cheap_scan`.
# ==============================================================================