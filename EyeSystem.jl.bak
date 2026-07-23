# EyeSystem.jl
# ==============================================================================
# VISUAL ATTENTION & PERIPHERAL PROCESSING SYSTEM
# ==============================================================================
# GRUG: This cave handles all eye-related processing:
#   1. Edge blurring (peripheral vision softening)
#   2. Peripheral center-out convex/concave cutout for center-most object
#   3. Arousal-gated cutout (high arousal = center object cut out of peripheral field)
#   4. Attention modulation (scan + attention modulation hooks into image pipeline)
#
# GRUG: The eye system operates on SDFParams from ImageSDF.jl.
# It modulates the SDF signal BEFORE it is sent to image nodes for voting.
# ==============================================================================

module EyeSystem
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

# GRUG: Bring SDF tools from the image cave!
# (ImageSDF must be included before EyeSystem in Main.jl)

export EyeState, process_visual_input, set_arousal!, get_arousal
export EdgeBlurParams, AttentionMap, compute_attention_map

# ==============================================================================
# ERROR TYPES - GRUG: NO SILENT FAILURES!
# ==============================================================================

struct EyeSystemError <: Exception
    msg::String
end

Base.showerror(io::IO, e::EyeSystemError) =
    print(io, "EyeSystemError: ", e.msg)

# ==============================================================================
# AROUSAL STATE
# ==============================================================================

# GRUG: Arousal is a global float [0.0, 1.0].
# Low arousal = calm, peripheral field intact.
# High arousal = center object gets cut out of peripheral field (hyper-focus on periphery).
# Arousal is set externally (e.g. by /wrong feedback, surprise, novel input).

mutable struct ArousalState
    level::Float64         # GRUG: Current arousal [0.0, 1.0]
    decay_rate::Float64    # GRUG: How fast arousal falls back to baseline per step
    baseline::Float64      # GRUG: Resting arousal level
end

# GRUG: One global arousal state for the whole eye system.
const AROUSAL_STATE = ArousalState(0.3, 0.05, 0.3)
const AROUSAL_LOCK = ReentrantLock()

"""
set_arousal!(level::Float64)

GRUG: Externally set arousal. Clamped to [0.0, 1.0]. Cannot be negative or over 1.
"""
function set_arousal!(level::Float64)
    if isnan(level) || isinf(level)
        throw(EyeSystemError("!!! FATAL: set_arousal! got NaN or Inf level! !!!"))
    end
    lock(AROUSAL_LOCK) do
        AROUSAL_STATE.level = clamp(level, 0.0, 1.0)
    end
end

"""
get_arousal()::Float64

GRUG: Read current arousal level.
"""
function get_arousal()::Float64
    return lock(AROUSAL_LOCK) do
        AROUSAL_STATE.level
    end
end

"""
decay_arousal!()

GRUG: Each processing step, arousal drifts back toward baseline.
Like adrenaline wearing off. Call this after each visual processing cycle.
"""
function decay_arousal!()
    lock(AROUSAL_LOCK) do
        current = AROUSAL_STATE.level
        baseline = AROUSAL_STATE.baseline
        rate = AROUSAL_STATE.decay_rate
        # GRUG: Exponential decay toward baseline
        AROUSAL_STATE.level = baseline + (current - baseline) * (1.0 - rate)
        AROUSAL_STATE.level = clamp(AROUSAL_STATE.level, 0.0, 1.0)
    end
end

# ==============================================================================
# EDGE BLUR PARAMETERS
# ==============================================================================

# GRUG: Edge blurring softens the peripheral field by applying a weighted
# Gaussian-like blur to pixels near the image boundary.
# Center pixels are unaffected. Peripheral pixels get progressively blurred.

struct EdgeBlurParams
    blur_radius::Float64     # GRUG: How far from edge blurring starts [0.0, 0.5] of image dims
    blur_strength::Float64   # GRUG: Max blur weight at the very edge [0.0, 1.0]
end

# GRUG: Default edge blur settings. Grug blur the outer 25% of image at up to 70% strength.
const DEFAULT_EDGE_BLUR = EdgeBlurParams(0.25, 0.7)

"""
apply_edge_blur(brightness::Vector{Float64}, width::Int, height::Int,
                params::EdgeBlurParams)::Vector{Float64}

GRUG: Apply peripheral edge blur to brightness array.
Pixels near image boundary are mixed with their local average (blur effect).
Pixels near center are untouched.
Result array is same length as input, row-aligned.
"""
function apply_edge_blur(
    brightness::Vector{Float64}, width::Int, height::Int,
    params::EdgeBlurParams
)::Vector{Float64}
    if isempty(brightness)
        throw(EyeSystemError("!!! FATAL: apply_edge_blur received empty brightness array! !!!"))
    end
    if width <= 0 || height <= 0
        throw(EyeSystemError(
            "!!! FATAL: apply_edge_blur received invalid dimensions $(width)x$(height)! !!!"
        ))
    end
    if length(brightness) != width * height
        throw(EyeSystemError(
            "!!! FATAL: brightness array length $(length(brightness)) != $(width*height)! !!!"
        ))
    end

    blurred = copy(brightness)
    n = length(brightness)

    for i in 1:n
        row = (i - 1) ÷ width    # GRUG: 0-based row
        col = (i - 1) % width    # GRUG: 0-based col

        # GRUG: Compute distance from nearest edge, normalized [0.0, 0.5]
        # 0.0 = at the edge, 0.5 = exactly at center
        dist_from_edge_x = min(col, width  - 1 - col) / Float64(width)
        dist_from_edge_y = min(row, height - 1 - row) / Float64(height)
        dist_from_edge = min(dist_from_edge_x, dist_from_edge_y)

        # GRUG: If pixel is inside the blur-free zone, skip it
        if dist_from_edge >= params.blur_radius
            continue
        end

        # GRUG: Blur weight: 1.0 at edge (dist=0), 0.0 at blur_radius boundary
        blur_weight = params.blur_strength * (1.0 - dist_from_edge / params.blur_radius)
        blur_weight = clamp(blur_weight, 0.0, 1.0)

        # GRUG: Simple 3x3 neighborhood average as blur kernel
        neighbor_sum = 0.0
        neighbor_count = 0
        for dr in -1:1
            for dc in -1:1
                nr = row + dr
                nc = col + dc
                if nr >= 0 && nr < height && nc >= 0 && nc < width
                    neighbor_sum += brightness[nr * width + nc + 1]
                    neighbor_count += 1
                end
            end
        end
        local_avg = neighbor_count > 0 ? neighbor_sum / neighbor_count : brightness[i]

        # GRUG: Blend original pixel with local average by blur_weight
        blurred[i] = (1.0 - blur_weight) * brightness[i] + blur_weight * local_avg
    end

    return blurred
end

# ==============================================================================
# ATTENTION MAP & CENTER DETECTION
# ==============================================================================

# GRUG: Attention map stores per-pixel attention weights [0.0, 1.0].
# High attention weight = node votes here count more.
# Low attention weight = peripheral / suppressed region.
struct AttentionMap
    weights::Vector{Float64}   # GRUG: Per-pixel attention weight, row-aligned with SDF
    width::Int
    height::Int
    center_x::Float64          # GRUG: Detected center-most object centroid, normalized [0,1]
    center_y::Float64
end

"""
compute_attention_map(brightness::Vector{Float64}, width::Int, height::Int,
                      arousal::Float64)::AttentionMap

GRUG: Build attention map using brightness-weighted centroid detection.
Steps:
  1. Find center-most object centroid (weighted average of high-brightness pixels)
  2. Build a convex/concave cutout mask around that centroid
  3. If arousal is high, cut out (suppress) center object in peripheral field
  4. Return per-pixel attention weights

GRUG: "convex/concave" means: Grug carve out center object with a radial mask.
Convex = smooth round cutout. Concave = the cutout edge curves inward (sharper).
Arousal modulates the curvature: low arousal = convex (soft), high arousal = concave (sharp cutout).
"""
function compute_attention_map(
    brightness::Vector{Float64}, width::Int, height::Int,
    arousal::Float64
)::AttentionMap
    if isempty(brightness)
        throw(EyeSystemError("!!! FATAL: compute_attention_map received empty brightness! !!!"))
    end
    if width <= 0 || height <= 0
        throw(EyeSystemError(
            "!!! FATAL: compute_attention_map received invalid dimensions $(width)x$(height)! !!!"
        ))
    end
    if length(brightness) != width * height
        throw(EyeSystemError(
            "!!! FATAL: brightness array length $(length(brightness)) != $(width*height)! !!!"
        ))
    end

    n = length(brightness)
    arousal_c = clamp(arousal, 0.0, 1.0)

    # GRUG: STEP 1 - Find center-most object centroid.
    # Threshold brightness to find "object" pixels (above mean brightness).
    mean_brightness = sum(brightness) / n
    # GRUG: Avoid divide-by-zero if image is entirely dark
    if mean_brightness < 1e-6
        mean_brightness = 0.1
    end

    weighted_x = 0.0
    weighted_y = 0.0
    total_weight = 0.0

    for i in 1:n
        if brightness[i] > mean_brightness
            row = Float64((i - 1) ÷ width) / Float64(height - 1)
            col = Float64((i - 1) % width) / Float64(width  - 1)
            # GRUG: Weight by how close to image center (0.5, 0.5) this bright pixel is
            dist_from_img_center = sqrt((col - 0.5)^2 + (row - 0.5)^2)
            center_bias = max(0.0, 1.0 - dist_from_img_center * 2.0)
            w = brightness[i] * center_bias
            weighted_x += col * w
            weighted_y += row * w
            total_weight += w
        end
    end

    # GRUG: If no bright objects found, default centroid to image center
    centroid_x = total_weight > 0.0 ? weighted_x / total_weight : 0.5
    centroid_y = total_weight > 0.0 ? weighted_y / total_weight : 0.5

    # GRUG: STEP 2 - Build cutout mask around centroid.
    # Cutout radius scales with arousal: higher arousal = larger cutout.
    # Base radius = 15% of image, max radius = 40% at full arousal.
    cutout_radius = 0.15 + arousal_c * 0.25

    # GRUG: Curvature power: controls convex/concave shape.
    # Low arousal: power < 1.0 -> convex (soft, rounded) cutout edge
    # High arousal: power > 1.0 -> concave (sharp, pinched) cutout edge
    curvature_power = 0.5 + arousal_c * 2.0  # GRUG: Range [0.5, 2.5]

    weights = Vector{Float64}(undef, n)

    for i in 1:n
        row = Float64((i - 1) ÷ width) / max(Float64(height - 1), 1.0)
        col = Float64((i - 1) % width) / max(Float64(width  - 1), 1.0)

        # GRUG: Radial distance from centroid, normalized by cutout_radius
        dx = col - centroid_x
        dy = row - centroid_y
        dist = sqrt(dx * dx + dy * dy)
        norm_dist = dist / cutout_radius

        # GRUG: Convex/concave mask via power function on normalized distance.
        # norm_dist < 1.0 means inside cutout zone.
        # Mask = 0.0 at center, 1.0 at cutout boundary (and beyond).
        if norm_dist >= 1.0
            # GRUG: Outside cutout zone = full attention
            weights[i] = 1.0
        else
            # GRUG: Inside cutout zone: compute suppression based on curvature
            # convex (power<1): gradual, smooth falloff from center
            # concave (power>1): steep suppression near center, sharp edge
            suppression = norm_dist ^ curvature_power

            if arousal_c > 0.5
                # GRUG: HIGH AROUSAL: CUT OUT center object from peripheral field!
                # High arousal = hyper-focus on periphery, center gets suppressed.
                weights[i] = suppression  # GRUG: Low weight at center = center cut out
            else
                # GRUG: LOW AROUSAL: Normal foveation - center gets MORE attention.
                # Invert: center has high weight, edges have lower weight.
                weights[i] = 1.0 - (1.0 - suppression) * 0.5
            end
        end
    end

    return AttentionMap(weights, width, height, centroid_x, centroid_y)
end

# ==============================================================================
# EYE STATE & FULL VISUAL PROCESSING PIPELINE
# ==============================================================================

# GRUG: EyeState bundles all current visual processing configuration.
mutable struct EyeState
    edge_blur_params::EdgeBlurParams
    attention_enabled::Bool      # GRUG: If false, skip attention modulation
    blur_enabled::Bool           # GRUG: If false, skip edge blurring
    last_centroid_x::Float64     # GRUG: Most recent detected object centroid
    last_centroid_y::Float64
    last_arousal::Float64        # GRUG: Arousal at last processing step
end

# GRUG: Default eye state. Grug sees with full attention and edge blur.
const DEFAULT_EYE_STATE = EyeState(DEFAULT_EDGE_BLUR, true, true, 0.5, 0.5, 0.3)
const EYE_STATE_LOCK = ReentrantLock()

"""
process_visual_input(brightness::Vector{Float64}, color::Vector{Float64},
                     x_arr::Vector{Float64}, y_arr::Vector{Float64},
                     width::Int, height::Int)::Tuple{Vector{Float64}, AttentionMap}

GRUG: Full visual processing pipeline.
Takes raw SDF brightness/color arrays, applies:
  1. Edge blurring (peripheral softening)
  2. Attention map computation (center detection + arousal-gated cutout)
  3. Attention-weighted brightness modulation
Returns (modulated_brightness, attention_map).
The modulated_brightness is what gets used as the image node's final signal.
"""
function process_visual_input(
    brightness::Vector{Float64},
    color::Vector{Float64},
    x_arr::Vector{Float64},
    y_arr::Vector{Float64},
    width::Int,
    height::Int
)::Tuple{Vector{Float64}, AttentionMap}

    if isempty(brightness) || isempty(color)
        throw(EyeSystemError(
            "!!! FATAL: process_visual_input received empty brightness or color arrays! !!!"
        ))
    end
    if length(brightness) != length(color)
        throw(EyeSystemError(
            "!!! FATAL: brightness and color array length mismatch in process_visual_input! !!!"
        ))
    end
    if width <= 0 || height <= 0
        throw(EyeSystemError(
            "!!! FATAL: process_visual_input got invalid dimensions $(width)x$(height)! !!!"
        ))
    end

    current_arousal = get_arousal()

    eye_state = lock(EYE_STATE_LOCK) do
        DEFAULT_EYE_STATE
    end

    # GRUG: STEP 1 - Apply edge blurring to peripheral pixels
    blurred_brightness = if eye_state.blur_enabled
        apply_edge_blur(brightness, width, height, eye_state.edge_blur_params)
    else
        copy(brightness)
    end

    # GRUG: STEP 2 - Compute attention map (centroid detection + cutout)
    attn_map = if eye_state.attention_enabled
        compute_attention_map(blurred_brightness, width, height, current_arousal)
    else
        # GRUG: If attention disabled, flat uniform attention (all 1.0)
        AttentionMap(ones(Float64, length(brightness)), width, height, 0.5, 0.5)
    end

    # GRUG: STEP 3 - Modulate brightness by attention weights.
    # High attention weight -> pixel signal amplified.
    # Low attention weight (cutout) -> pixel signal suppressed.
    modulated_brightness = Vector{Float64}(undef, length(brightness))
    for i in 1:length(brightness)
        modulated_brightness[i] = clamp(blurred_brightness[i] * attn_map.weights[i], 0.0, 1.0)
    end

    # GRUG: Update eye state with latest centroid and arousal for external inspection
    lock(EYE_STATE_LOCK) do
        DEFAULT_EYE_STATE.last_centroid_x = attn_map.center_x
        DEFAULT_EYE_STATE.last_centroid_y = attn_map.center_y
        DEFAULT_EYE_STATE.last_arousal    = current_arousal
    end

    # GRUG: Decay arousal after each visual processing step
    decay_arousal!()

    return (modulated_brightness, attn_map)
end

end # module EyeSystem

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: EYE SYSTEM LAYER
#
# 1. PERIPHERAL EDGE BLURRING:
# apply_edge_blur() implements a distance-weighted local averaging blur.
# Pixels within blur_radius of any image edge are mixed with their 3x3 neighborhood
# average, weighted by their proximity to the edge. Center pixels are unaffected.
# This models the reduced acuity of peripheral vision vs. foveal (center) vision.
#
# 2. CONVEX/CONCAVE CENTER CUTOUT:
# compute_attention_map() uses brightness-weighted centroid detection to find the
# "center-most object" in the visual field. A radial mask is carved around it.
# The mask shape is controlled by a curvature power parameter driven by arousal:
# - Low arousal: power < 1.0 -> convex (soft, rounded) boundary (gentle foveation)
# - High arousal: power > 1.0 -> concave (sharp, pinched) boundary (aggressive suppression)
#
# 3. AROUSAL-GATED PERIPHERAL SUPPRESSION:
# When arousal > 0.5, the center object is CUT OUT of the peripheral field:
# attention weights near the centroid are LOW, meaning the image node's signal
# in that region is suppressed. This forces processing to focus on peripheral
# content rather than the salient center object (threat-response behavior).
#
# 4. ATTENTION MODULATION PIPELINE:
# process_visual_input() orchestrates the full pipeline: blur -> attend -> modulate.
# The output modulated_brightness feeds back into sdf_to_signal() in ImageSDF.jl
# for final pattern scanner compatibility.
#
# 5. AROUSAL DECAY:
# Arousal naturally decays toward baseline after each visual processing cycle,
# modeling the biological return to calm after a threat or surprise event.
# ==============================================================================