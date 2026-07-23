# ImageSDF.jl
# ==============================================================================
# JIT GPU-ACCELERATED IMAGE -> NONLINEAR SDF PARAMETER CONVERSION
# ==============================================================================
# GRUG: This cave converts raw image binary into SDF (Signed Distance Field)
# parameter arrays that image nodes can use as their pattern signal.
# All arrays are ROW-ALIGNED: xArray[i] aligns with yArray[i], brightnessArray[i], colorArray[i].
# Key values get a PINEAL DRIP jitter every time they fire (run from bullseye, snap back).
# Temporal coherence uses timestep as meta-geometry to organize alignments.
#
# GPU ACCELERATION (JITGPU):
# JITGPU(binary) is the real GPU-dispatch path. It uses KernelAbstractions.jl
# to write a single @kernel function that runs identically on:
#   - NVIDIA GPUs via CUDABackend() when CUDA.jl is loaded
#   - AMD GPUs via ROCBackend() when AMDGPU.jl is loaded
#   - Apple Silicon via MetalBackend() when Metal.jl is loaded
#   - All CPU-only machines via CPU() backend (multithreaded kernel dispatch)
# The kernel IS the GPU code. CPU() is not a fake fallback — it's genuine
# KernelAbstractions kernel dispatch running on Julia threads.
# ==============================================================================

module ImageSDF

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
using KernelAbstractions

export detect_image_binary, image_to_sdf_params, SDFParams, apply_sdf_jitter
export sdf_to_signal, JITGPU

# GRUG: TemporalCoherenceRecord and update_temporal_coherence! are defined below
# but NOT exported — they are unwired (no caller in the codebase). Kept as
# future-facing infrastructure for temporal SDF tracking. Wire them before exporting.

# ==============================================================================
# ERROR TYPES - GRUG: NO SILENT FAILURES!
# ==============================================================================

struct ImageSDFError <: Exception
    msg::String
end

struct ImageBinaryDetectionError <: Exception
    msg::String
end

Base.showerror(io::IO, e::ImageSDFError) =
    print(io, "ImageSDFError: ", e.msg)
Base.showerror(io::IO, e::ImageBinaryDetectionError) =
    print(io, "ImageBinaryDetectionError: ", e.msg)

# ==============================================================================
# SDF PARAMETER STRUCT
# ==============================================================================

# GRUG: All arrays are ROW-ALIGNED. Index i in all arrays = same pixel.
# xArray[i], yArray[i], brightnessArray[i], colorArray[i] all describe pixel i.
struct SDFParams
    xArray::Vector{Float64}          # GRUG: Normalized x position [0.0, 1.0]
    yArray::Vector{Float64}          # GRUG: Normalized y position [0.0, 1.0]
    brightnessArray::Vector{Float64} # GRUG: Brightness value [0.0, 1.0]
    colorArray::Vector{Float64}      # GRUG: Color scalar (hue-derived) [0.0, 1.0]
    width::Int                       # GRUG: Original image width in pixels
    height::Int                      # GRUG: Original image height in pixels
    timestamp::Float64               # GRUG: When this SDF was born (for temporal coherence)
end

# ==============================================================================
# TEMPORAL COHERENCE RECORD — UNWIRED (future-facing, no caller in codebase)
# ==============================================================================

# GRUG: Time step is meta-geometry! Grug use timestamps to organize SDF alignments.
# When SDF params fire at similar timesteps, they are temporally coherent.
# NOTE: This infrastructure is defined but NOT wired into any fire path.
# Wire update_temporal_coherence! into fire_attachments! before using.
mutable struct TemporalCoherenceRecord
    sdf_id::String
    last_fired::Float64              # GRUG: Unix timestamp of last activation
    fire_count::Int                  # GRUG: How many times this SDF has fired
    avg_interval::Float64            # GRUG: Rolling average interval between fires
    coherence_score::Float64         # GRUG: How temporally stable this SDF is [0.0, 1.0]
end

# GRUG: Keep a global temporal coherence ledger so Grug can track SDF timing patterns.
const TEMPORAL_COHERENCE_LEDGER = Dict{String, TemporalCoherenceRecord}()
const TCL_LOCK = ReentrantLock()

# GRUG: Update the temporal coherence record for an SDF when it fires.
function update_temporal_coherence!(sdf_id::String)::Float64
    if strip(sdf_id) == ""
        throw(ImageSDFError("!!! FATAL: Cannot update temporal coherence for empty SDF id! !!!"))
    end

    now_t = time()

    lock(TCL_LOCK) do
        if haskey(TEMPORAL_COHERENCE_LEDGER, sdf_id)
            rec = TEMPORAL_COHERENCE_LEDGER[sdf_id]
            interval = now_t - rec.last_fired

            # GRUG: Rolling average update. New avg = (old avg * count + new interval) / (count + 1)
            rec.fire_count += 1
            rec.avg_interval = (rec.avg_interval * (rec.fire_count - 1) + interval) / rec.fire_count
            rec.last_fired = now_t

            # GRUG: Coherence score = stability of intervals.
            # If intervals are very regular, score -> 1.0. Chaotic -> 0.0.
            # Use inverse coefficient of variation as coherence proxy.
            if rec.avg_interval > 0.0
                # GRUG: Low variance around mean = high coherence.
                # Bounded between 0.1 and 1.0 so Grug never fully loses coherence.
                variance_proxy = abs(interval - rec.avg_interval) / rec.avg_interval
                rec.coherence_score = clamp(1.0 - variance_proxy, 0.1, 1.0)
            end

            return rec.coherence_score
        else
            # GRUG: First fire! Create record with baseline coherence.
            TEMPORAL_COHERENCE_LEDGER[sdf_id] = TemporalCoherenceRecord(
                sdf_id, now_t, 1, 0.0, 0.5
            )
            return 0.5
        end
    end
end

# ==============================================================================
# IMAGE BINARY DETECTION (REGEX-BASED)
# ==============================================================================

# GRUG: Regex patterns for detecting image binary in messages.
# Grug look for Base64-encoded image data URIs and raw binary magic bytes.
# These are the most common ways image data arrives in text messages.

# GRUG: Base64 image data URI pattern (e.g. "data:image/png;base64,iVBORw0KGgo...")
const BASE64_IMAGE_REGEX = r"data:image/(?:png|jpeg|jpg|gif|webp|bmp);base64,([A-Za-z0-9+/=]{64,})"

# GRUG: PNG magic bytes in hex string representation (89504E47...)
const PNG_HEX_REGEX = r"(?:^|[^A-Fa-f0-9])89504[Ee]47(?:[A-Fa-f0-9]{2}){4,}"

# GRUG: JPEG magic bytes (FFD8FF...)
const JPEG_HEX_REGEX = r"(?:^|[^A-Fa-f0-9])[Ff][Ff][Dd]8[Ff][Ff](?:[A-Fa-f0-9]{2}){4,}"

# GRUG: Raw binary blob marker (often used in protocol buffers or custom formats)
const RAW_BINARY_REGEX = r"\\x89PNG|\\xFF\\xD8\\xFF"

"""
detect_image_binary(input::String)::Tuple{Bool, Symbol, String}

GRUG: Sniff the input for image binary. Returns (found, format, extracted_data).
format is :base64, :hex_png, :hex_jpeg, :raw, or :none.
extracted_data is the raw image payload string if found, else "".
NO SILENT FAILURES: throws ImageBinaryDetectionError on malformed input.
"""
function detect_image_binary(input::String)::Tuple{Bool, Symbol, String}
    if strip(input) == ""
        throw(ImageBinaryDetectionError(
            "!!! FATAL: detect_image_binary got empty input string! !!!"
        ))
    end

    # GRUG: Check Base64 data URI first (most common, most structured)
    m = match(BASE64_IMAGE_REGEX, input)
    if !isnothing(m)
        return (true, :base64, String(m.captures[1]))
    end

    # GRUG: Check PNG hex dump
    m = match(PNG_HEX_REGEX, input)
    if !isnothing(m)
        return (true, :hex_png, String(m.match))
    end

    # GRUG: Check JPEG hex dump
    m = match(JPEG_HEX_REGEX, input)
    if !isnothing(m)
        return (true, :hex_jpeg, String(m.match))
    end

    # GRUG: Check raw binary escape sequences
    m = match(RAW_BINARY_REGEX, input)
    if !isnothing(m)
        return (true, :raw, String(m.match))
    end

    # GRUG: No image found. Not an error, just no image.
    return (false, :none, "")
end

# ==============================================================================
# JITGPU: REAL GPU-ACCELERATED NONLINEAR SDF CONVERSION
# ==============================================================================
# GRUG: This is the real GPU dispatch path using KernelAbstractions.jl.
#
# The @kernel macro compiles ONCE to the best available backend:
#   - CPU()            : multithreaded Julia threads (always available)
#   - CUDABackend()    : NVIDIA via CUDA.jl (loaded at runtime if present)
#   - ROCBackend()     : AMD via AMDGPU.jl (loaded at runtime if present)
#   - MetalBackend()   : Apple Silicon via Metal.jl (loaded at runtime if present)
#
# Kernel code is IDENTICAL across all backends — KernelAbstractions handles
# the dispatch. This is not a "fake GPU" — it IS the GPU kernel, and the CPU
# backend runs the same @kernel code on Julia threads for CI compatibility.
#
# GRUG PIPELINE (per pixel, parallel across all n_pixels threads):
#   1. Decode RGB/RGBA/gray -> brightness, color_scalar
#   2. Central-difference gradient (Sobel-like) on brightness
#   3. tanh(3 * grad_mag) nonlinear activation -> SDF value
#   4. Store to output arrays (x, y, brightness_sdf, color)
#
# All arrays are ROW-ALIGNED as per SDFParams contract.
# ==============================================================================

# ------------------------------------------------------------------------------
# GPU BACKEND SELECTION — detect available hardware at runtime
# ------------------------------------------------------------------------------

"""
_select_ka_backend()

GRUG: Detect the best available KernelAbstractions backend at runtime.
Priority: CUDABackend > ROCBackend > MetalBackend > CPU (multithreaded).
Returns a KernelAbstractions backend instance.

This is runtime detection — no compile-time hard dependency on CUDA.jl etc.
On CI (ubuntu-latest, no GPU), always returns CPU() which dispatches the same
@kernel code on Julia threads.
"""
function _select_ka_backend()
    # GRUG: Try CUDA first. isdefined check avoids hard CUDA.jl compile dep.
    # If user has CUDA.jl loaded in their environment, we use it. Otherwise skip.
    if isdefined(Main, :CUDA) && Main.CUDA.functional()
        return Main.CUDA.CUDABackend()
    end

    # GRUG: Try AMD GPU second.
    if isdefined(Main, :AMDGPU) && Main.AMDGPU.functional()
        return Main.AMDGPU.ROCBackend()
    end

    # GRUG: Try Metal (Apple Silicon) third.
    if isdefined(Main, :Metal) && Main.Metal.functional()
        return Main.Metal.MetalBackend()
    end

    # GRUG: No GPU detected. Use KernelAbstractions CPU() backend.
    # This is NOT a dummy fallback — CPU() dispatches the @kernel on Julia
    # threads using the same kernel code. Real kernel dispatch, just on CPU.
    return KernelAbstractions.CPU()
end

# ------------------------------------------------------------------------------
# PIXEL DECODE KERNEL — one thread per pixel
# ------------------------------------------------------------------------------

"""
_sdf_pixel_kernel!

GRUG: KernelAbstractions @kernel for parallel pixel processing.
Each thread handles one pixel: decode -> gradient -> tanh SDF.

Kernel signature (all arrays are flat, length = n_pixels):
  raw          — UInt8 array of raw image bytes (length = n_pixels * channels)
  x_out        — Float32 output: normalized x position [0, 1]
  y_out        — Float32 output: normalized y position [0, 1]
  bright_raw   — Float32 scratch: raw brightness before gradient pass
  color_out    — Float32 output: hue-proxy color scalar [0, 1]
  width, height, channels — image dimensions and channel count

Note: bright_raw is populated in this kernel, then a second kernel (_sdf_gradient_kernel!)
reads it to compute gradients. Two-pass because gradient needs neighbor pixels —
those neighbors must already be decoded before we can diff them.
"""
@kernel function _sdf_pixel_decode_kernel!(
    raw,
    x_out, y_out, bright_raw, color_out,
    width, height, channels
)
    # GRUG: KernelAbstractions gives each thread its global linear index.
    i = @index(Global, Linear)

    # GRUG: KA kernels cannot use bare `return` — wrap body in bounds guard instead.
    # Last workgroup may be partial (over-launched), so skip out-of-bounds threads.
    if i <= width * height
        # GRUG: Row and column from linear index (0-based arithmetic, then back to 1-based)
        row_0 = (i - 1) ÷ width   # 0-based row
        col_0 = (i - 1) % width   # 0-based col

        # GRUG: Normalized spatial coordinates [0.0, 1.0]
        x_out[i] = Float32(col_0) / Float32(max(width  - 1, 1))
        y_out[i] = Float32(row_0) / Float32(max(height - 1, 1))

        # GRUG: Decode pixel color from raw bytes
        base_idx = (i - 1) * channels + 1

        if channels == 1
            b = Float32(raw[base_idx]) / 255f0
            bright_raw[i] = b
            color_out[i]  = b   # no color info in grayscale
        elseif channels == 3
            r = Float32(raw[base_idx])     / 255f0
            g = Float32(raw[base_idx + 1]) / 255f0
            b = Float32(raw[base_idx + 2]) / 255f0
            # GRUG: ITU-R BT.709 luminance
            bright_raw[i] = 0.2126f0 * r + 0.7152f0 * g + 0.0722f0 * b
            # GRUG: Hue proxy: R-B spread normalized to [0,1]
            color_out[i]  = clamp((r - b + 1f0) / 2f0, 0f0, 1f0)
        else  # channels == 4 (RGBA) or channels > 4 (ignore extra)
            r = Float32(raw[base_idx])     / 255f0
            g = Float32(raw[base_idx + 1]) / 255f0
            b = Float32(raw[base_idx + 2]) / 255f0
            bright_raw[i] = 0.2126f0 * r + 0.7152f0 * g + 0.0722f0 * b
            color_out[i]  = clamp((r - b + 1f0) / 2f0, 0f0, 1f0)
            # GRUG: Alpha channel ignored — brightness is what matters for SDF structure
        end
    end
end

"""
_sdf_gradient_kernel!

GRUG: Second KernelAbstractions @kernel pass — compute nonlinear SDF value per pixel.
Reads bright_raw (from _sdf_pixel_decode_kernel!) and writes bright_sdf.

NONLINEAR SDF MATH (per pixel):
  gx = bright_raw[right] - bright_raw[left]   (central difference X)
  gy = bright_raw[down]  - bright_raw[up]     (central difference Y)
  grad_mag = sqrt(gx² + gy²)
  bright_sdf[i] = tanh(3 * grad_mag)

tanh(3 * grad) maps gradient [0, ~1.4] -> [0, ~0.99].
High gradients (edges) activate strongly. Flat regions suppress to near zero.
This is the "nonlinear" in "nonlinear SDF" — structural edges pop, noise recedes.
"""
@kernel function _sdf_gradient_kernel!(
    bright_raw, bright_sdf,
    width, height
)
    i = @index(Global, Linear)

    # GRUG: KA kernels cannot use bare `return` — wrap body in bounds guard instead.
    if i <= width * height
        row_0 = (i - 1) ÷ width
        col_0 = (i - 1) % width

        # GRUG: Clamp-to-boundary neighbor lookup (no wrap-around, mirror at edges)
        row_up    = max(row_0 - 1, 0)
        row_down  = min(row_0 + 1, height - 1)
        col_left  = max(col_0 - 1, 0)
        col_right = min(col_0 + 1, width - 1)

        idx_up    = row_up    * width + col_0       + 1
        idx_down  = row_down  * width + col_0       + 1
        idx_left  = row_0     * width + col_left    + 1
        idx_right = row_0     * width + col_right   + 1

        gx = bright_raw[idx_right] - bright_raw[idx_left]
        gy = bright_raw[idx_down]  - bright_raw[idx_up]

        # GRUG: Gradient magnitude then nonlinear tanh activation
        grad_mag = sqrt(gx * gx + gy * gy)
        bright_sdf[i] = tanh(3f0 * grad_mag)
    end
end

# ------------------------------------------------------------------------------
# JITGPU — PUBLIC ENTRY POINT
# ------------------------------------------------------------------------------

"""
JITGPU(binary::Vector{UInt8}; width::Int, height::Int)::SDFParams

GRUG: Real GPU-accelerated nonlinear SDF computation via KernelAbstractions.jl.

This is the JIT GPU-accelerated replacement for image_to_sdf_params(). Called
once at /imgnodeAttach time — expensive GPU kernel compiles and runs HERE so
fire-time is just jitter on pre-baked base_confidence.

BACKEND SELECTION (runtime, no compile-time hard dep on CUDA/ROC/Metal):
  • CUDA.jl loaded + functional()  → CUDABackend()   (NVIDIA)
  • AMDGPU.jl loaded + functional() → ROCBackend()   (AMD)
  • Metal.jl loaded + functional()  → MetalBackend() (Apple Silicon)
  • Otherwise                       → CPU()           (Julia threads, CI-safe)

KERNEL PIPELINE (two-pass, one thread per pixel):
  Pass 1 (_sdf_pixel_decode_kernel!):
    decode UInt8 RGB/RGBA/gray → brightness_raw, color_scalar, x, y
  Pass 2 (_sdf_gradient_kernel!):
    central-difference gradient on brightness_raw → tanh(3*grad_mag) → SDF brightness

RETURN: SDFParams with the same row-aligned array contract as image_to_sdf_params().

ERRORS: throws ImageSDFError on empty binary, invalid dimensions, or channel mismatch.
        NO SILENT FAILURES.

ARRAY PROTOCOL:
  CPU backend  → KernelAbstractions.allocate(CPU(), ...) returns plain Vector{T}.
                 No H2D/D2H copies needed. Array(result) is a no-op.
  GPU backends → allocate() returns a device array (CuArray, ROCArray, etc.).
                 Array(gpu_array) triggers the D2H copy back to host.
"""
function JITGPU(binary::Vector{UInt8}; width::Int, height::Int)::SDFParams
    if isempty(binary)
        throw(ImageSDFError("!!! FATAL: JITGPU got empty binary! Cannot compute SDF from nothing! !!!"))
    end
    if width <= 0 || height <= 0
        throw(ImageSDFError(
            "!!! FATAL: JITGPU got invalid dimensions: $(width)x$(height)! Both must be > 0! !!!"
        ))
    end

    n_pixels = width * height
    expected_gray = n_pixels
    expected_rgb  = n_pixels * 3
    expected_rgba = n_pixels * 4

    channels = if length(binary) >= expected_rgba
        4
    elseif length(binary) >= expected_rgb
        3
    elseif length(binary) >= expected_gray
        1
    else
        throw(ImageSDFError(
            "!!! FATAL: JITGPU binary length $(length(binary)) too small for $(width)x$(height)! !!!"
        ))
    end

    # GRUG: Select best available backend at runtime.
    backend = _select_ka_backend()

    # GRUG: Allocate working arrays on the target device.
    # KernelAbstractions.allocate() returns a device-local array:
    #   - CPU()        → plain Vector{T}  (no copies needed)
    #   - CUDABackend  → CuArray{T}       (lives in GPU VRAM)
    #   - ROCBackend   → ROCArray{T}
    #   - MetalBackend → MtlArray{T}
    # raw_ka is a copy of binary on device so the kernel can read it.
    raw_ka     = KernelAbstractions.allocate(backend, UInt8,   length(binary))
    x_ka       = KernelAbstractions.allocate(backend, Float32, n_pixels)
    y_ka       = KernelAbstractions.allocate(backend, Float32, n_pixels)
    bright_raw = KernelAbstractions.allocate(backend, Float32, n_pixels)
    color_ka   = KernelAbstractions.allocate(backend, Float32, n_pixels)
    bright_sdf = KernelAbstractions.allocate(backend, Float32, n_pixels)

    # GRUG: Copy binary to device array.
    # For CPU backend: copyto!(dst::Vector, src::Vector) — plain Julia memcopy.
    # For GPU backends: triggers host-to-device (H2D) DMA transfer.
    copyto!(raw_ka, binary)

    # GRUG: PASS 1 — decode all pixels in parallel.
    # One KernelAbstractions thread per pixel: UInt8 decode → brightness_raw, color, x, y.
    # Kernel instantiation: _sdf_pixel_decode_kernel!(backend, workgroup_size)
    # Workgroup size 256 is conventional for GPU; CPU backend ignores it (runs sequentially
    # within each task, or multi-threaded via Julia's thread pool).
    decode_kernel! = _sdf_pixel_decode_kernel!(backend, 256)
    decode_kernel!(
        raw_ka,
        x_ka, y_ka, bright_raw, color_ka,
        width, height, channels;
        ndrange = n_pixels
    )

    # GRUG: Synchronize after pass 1 — ALL pixels must be decoded before pass 2 reads
    # their neighbors. KernelAbstractions.synchronize(backend) is a device barrier:
    # blocks host until all launched kernels on this backend have completed.
    KernelAbstractions.synchronize(backend)

    # GRUG: PASS 2 — compute central-difference gradient + tanh SDF activation.
    # Reads bright_raw (guaranteed complete after synchronize above) and writes bright_sdf.
    grad_kernel! = _sdf_gradient_kernel!(backend, 256)
    grad_kernel!(
        bright_raw, bright_sdf,
        width, height;
        ndrange = n_pixels
    )

    # GRUG: Final synchronize — all SDF values written before we copy back to host.
    KernelAbstractions.synchronize(backend)

    # GRUG: Copy results from device back to host Vector{Float32}.
    # For CPU backend: x_ka etc are already plain Vector{Float32} — Array() is a no-op.
    # For GPU backends: Array(gpu_array) triggers device-to-host (D2H) DMA copy.
    x_host      = Array(x_ka)
    y_host      = Array(y_ka)
    bright_host = Array(bright_sdf)
    color_host  = Array(color_ka)

    # GRUG: Convert Float32 -> Float64 for SDFParams contract compatibility.
    # All downstream consumers (sdf_to_signal, cosine similarity) expect Float64.
    return SDFParams(
        Float64.(x_host),
        Float64.(y_host),
        Float64.(bright_host),
        Float64.(color_host),
        width, height,
        time()  # GRUG: Stamp birth time for temporal coherence
    )
end

# ==============================================================================
# image_to_sdf_params — CPU REFERENCE PATH (kept for tests + backward compat)
# ==============================================================================

"""
image_to_sdf_params(image_data::Vector{UInt8}, width::Int, height::Int)::SDFParams

GRUG: CPU reference implementation of the nonlinear SDF transform.
Kept for backward compatibility and as the ground-truth reference for tests.
Production image attach path uses JITGPU() instead.

Algorithm is identical to JITGPU kernels (same decode + central-diff + tanh)
so results should match within Float32 rounding tolerance.
"""
function image_to_sdf_params(image_data::Vector{UInt8}, width::Int, height::Int)::SDFParams
    if isempty(image_data)
        throw(ImageSDFError("!!! FATAL: image_to_sdf_params got empty image_data! !!!"))
    end
    if width <= 0 || height <= 0
        throw(ImageSDFError(
            "!!! FATAL: image_to_sdf_params got invalid dimensions: $(width)x$(height)! !!!"
        ))
    end

    expected_gray = width * height
    expected_rgb  = width * height * 3
    expected_rgba = width * height * 4

    channels = if length(image_data) >= expected_rgba
        4
    elseif length(image_data) >= expected_rgb
        3
    elseif length(image_data) >= expected_gray
        1
    else
        throw(ImageSDFError(
            "!!! FATAL: image_data length $(length(image_data)) too small for $(width)x$(height)! !!!"
        ))
    end

    n_pixels = width * height

    xArray          = Vector{Float64}(undef, n_pixels)
    yArray          = Vector{Float64}(undef, n_pixels)
    brightnessArray = Vector{Float64}(undef, n_pixels)
    colorArray      = Vector{Float64}(undef, n_pixels)

    for i in 1:n_pixels
        row = (i - 1) ÷ width
        col = (i - 1) % width

        xArray[i] = col / max(width  - 1, 1)
        yArray[i] = row / max(height - 1, 1)

        base_idx = (i - 1) * channels + 1
        if base_idx > length(image_data)
            throw(ImageSDFError(
                "!!! FATAL: Pixel index out of range at pixel $i, base_idx $base_idx! !!!"
            ))
        end

        if channels == 1
            brightness = Float64(image_data[base_idx]) / 255.0
            brightnessArray[i] = brightness
            colorArray[i] = brightness
        elseif channels == 3
            r = Float64(image_data[base_idx])     / 255.0
            g = Float64(image_data[base_idx + 1]) / 255.0
            b = Float64(image_data[base_idx + 2]) / 255.0
            brightnessArray[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            colorArray[i] = clamp((r - b + 1.0) / 2.0, 0.0, 1.0)
        elseif channels == 4
            r = Float64(image_data[base_idx])     / 255.0
            g = Float64(image_data[base_idx + 1]) / 255.0
            b = Float64(image_data[base_idx + 2]) / 255.0
            brightnessArray[i] = 0.2126 * r + 0.7152 * g + 0.0722 * b
            colorArray[i] = clamp((r - b + 1.0) / 2.0, 0.0, 1.0)
        end
    end

    brightnessArray = _apply_nonlinear_sdf_transform(brightnessArray, width, height)

    return SDFParams(
        xArray, yArray, brightnessArray, colorArray,
        width, height,
        time()
    )
end

"""
_apply_nonlinear_sdf_transform(brightness::Vector{Float64}, width::Int, height::Int)::Vector{Float64}

GRUG: Core nonlinear SDF transform for the CPU reference path.
Compute local gradient magnitude for each pixel using a 3x3 central-difference
approximation. High gradient = edge = high SDF activation.
Same math as _sdf_gradient_kernel! — tanh(3 * grad_mag).
"""
function _apply_nonlinear_sdf_transform(
    brightness::Vector{Float64}, width::Int, height::Int
)::Vector{Float64}
    n = length(brightness)
    if n != width * height
        throw(ImageSDFError(
            "!!! FATAL: brightness array size $n != width*height=$(width*height)! !!!"
        ))
    end

    sdf_out = Vector{Float64}(undef, n)

    for i in 1:n
        row = (i - 1) ÷ width
        col = (i - 1) % width

        row_up   = max(row - 1, 0)
        row_down = min(row + 1, height - 1)
        col_left = max(col - 1, 0)
        col_right = min(col + 1, width - 1)

        idx_up    = row_up   * width + col + 1
        idx_down  = row_down * width + col + 1
        idx_left  = row * width + col_left  + 1
        idx_right = row * width + col_right + 1

        gx = brightness[idx_right] - brightness[idx_left]
        gy = brightness[idx_down]  - brightness[idx_up]
        grad_mag = sqrt(gx * gx + gy * gy)

        sdf_out[i] = tanh(grad_mag * 3.0)
    end

    return sdf_out
end

# ==============================================================================
# SDF JITTER (PINEAL DRIP MODULATION)
# ==============================================================================

"""
apply_sdf_jitter(params::SDFParams)::SDFParams

GRUG: Every time SDF fires, key values get a slight jitter (pineal drip modulation).
They run slightly from the bullseye then snap back to baseline.
This is the same principle as slight_jitter in PatternScanner but applied to
the full SDF parameter arrays for temporal coherence texture.
"""
function apply_sdf_jitter(params::SDFParams)::SDFParams
    if isempty(params.xArray)
        throw(ImageSDFError("!!! FATAL: apply_sdf_jitter received empty SDFParams! !!!"))
    end

    n = length(params.xArray)

    # GRUG: Generate a single small random offset for this fire event.
    # Pineal drip: slight deviation, then snap back. We model the deviation here;
    # the snap-back is implicit since next call starts fresh from stored values.
    jitter_magnitude = 0.008 + (0.004 * rand())  # GRUG: Small bounded jitter [0.008, 0.012]

    # GRUG: Apply per-element bounded jitter. Different pixel gets slightly different shake.
    jitter_brightness = [clamp(b + (rand() * 2.0 - 1.0) * jitter_magnitude, 0.0, 1.0)
                         for b in params.brightnessArray]
    jitter_color      = [clamp(c + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.5, 0.0, 1.0)
                         for c in params.colorArray]

    # GRUG: Spatial coords (x, y) get minimal jitter to avoid spatial drift.
    jitter_x = [clamp(x + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.1, 0.0, 1.0)
                for x in params.xArray]
    jitter_y = [clamp(y + (rand() * 2.0 - 1.0) * jitter_magnitude * 0.1, 0.0, 1.0)
                for y in params.yArray]

    return SDFParams(
        jitter_x, jitter_y, jitter_brightness, jitter_color,
        params.width, params.height,
        params.timestamp  # GRUG: Preserve original birth timestamp, jitter doesn't change birth!
    )
end

# ==============================================================================
# SDF -> FLAT SIGNAL VECTOR (FOR PATTERN SCANNER COMPATIBILITY)
# ==============================================================================

"""
sdf_to_signal(params::SDFParams; max_samples::Int=256)::Vector{Float64}

GRUG: Convert SDFParams into a flat Float64 signal vector compatible with PatternScanner.
Grug cannot feed 4 arrays of 10,000 pixels into the scanner directly (cave fire!).
So Grug samples max_samples pixels uniformly, then interleaves [x, y, brightness, color]
for each sampled pixel. Result is a signal of length (4 * max_samples).
"""
function sdf_to_signal(params::SDFParams; max_samples::Int=256)::Vector{Float64}
    if isempty(params.xArray)
        throw(ImageSDFError("!!! FATAL: sdf_to_signal received empty SDFParams! !!!"))
    end
    if max_samples <= 0
        throw(ImageSDFError(
            "!!! FATAL: sdf_to_signal max_samples must be > 0, got $max_samples! !!!"
        ))
    end

    n_pixels = length(params.xArray)
    # GRUG: Sample uniformly. If fewer pixels than max_samples, just use all pixels.
    sample_count = min(max_samples, n_pixels)
    step = max(1, n_pixels ÷ sample_count)

    # GRUG: Pre-allocate output signal: 4 values per sampled pixel (x, y, brightness, color)
    signal = Vector{Float64}(undef, sample_count * 4)

    out_idx = 1
    for i in 1:step:(step * sample_count)
        pixel_i = min(i, n_pixels)  # GRUG: Safety clamp
        signal[out_idx]     = params.xArray[pixel_i]
        signal[out_idx + 1] = params.yArray[pixel_i]
        signal[out_idx + 2] = params.brightnessArray[pixel_i]
        signal[out_idx + 3] = params.colorArray[pixel_i]
        out_idx += 4
    end

    return signal
end

# ==============================================================================
# BASE64 -> RAW BYTES HELPER
# ==============================================================================

"""
base64_to_bytes(b64_str::String)::Vector{UInt8}

GRUG: Decode a Base64 string into raw bytes for JITGPU / image_to_sdf_params.
Uses Julia's built-in base64decode. Throws ImageSDFError on failure.
"""
function base64_to_bytes(b64_str::String)::Vector{UInt8}
    if strip(b64_str) == ""
        throw(ImageSDFError("!!! FATAL: base64_to_bytes got empty string! !!!"))
    end
    try
        return base64decode(b64_str)
    catch e
        throw(ImageSDFError("!!! FATAL: base64_to_bytes failed to decode: $e !!!"))
    end
end

end # module ImageSDF

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: IMAGE SDF LAYER
#
# 1. ROW-ALIGNED PARAMETER ARRAYS:
# All SDFParams arrays (xArray, yArray, brightnessArray, colorArray) are strictly
# row-aligned. Index i in all arrays maps to the same source pixel. This enables
# vectorized pattern matching in PatternScanner without index misalignment errors.
#
# 2. NONLINEAR SDF TRANSFORM:
# Raw brightness is transformed via a central-difference gradient magnitude + tanh
# activation: bright_sdf[i] = tanh(3 * sqrt(gx² + gy²)).
# This creates edge-emphasized, flat-suppressed representations that capture structural
# image features (edges, textures) rather than raw pixel values. Edges become
# high-activation zones; uniform regions fade to near-zero. Algorithm is identical
# in both JITGPU kernels and the CPU reference path (image_to_sdf_params).
#
# 3. GPU KERNEL ARCHITECTURE (JITGPU):
# Two-pass @kernel design required by data dependency:
#   Pass 1: decode all pixels to brightness_raw in parallel (no inter-pixel deps)
#   synchronize() — ALL pixels decoded before any gradient reads neighbors
#   Pass 2: central-difference gradient reads ±1 neighbors (needs pass 1 complete)
# KernelAbstractions.synchronize() is a real device barrier on GPU backends
# and a no-op on CPU() backend (threads are already sequential per-element).
#
# 4. BACKEND PORTABILITY:
# JITGPU uses runtime detection (_select_ka_backend) — no compile-time dep on
# CUDA.jl/AMDGPU.jl/Metal.jl. Those packages are optional; the code checks
# isdefined(Main, :CUDA) before using them. On CI (no GPU hardware) the CPU()
# backend runs the same @kernel code on Julia threads.
#
# 5. PINEAL DRIP JITTER (TEMPORAL COHERENCE TEXTURE):
# apply_sdf_jitter() injects small bounded per-element noise every time an SDF fires.
# This models biological sensor noise (slightly different retinal activation each view)
# while preserving structural identity. TemporalCoherenceRecord tracks firing intervals
# to measure whether SDF activations are rhythmically stable.
#
# 6. JIT COMPATIBILITY:
# sdf_to_signal() bridges SDFParams -> PatternScanner-compatible Float64 vectors.
# Uniform subsampling (max 256 pixels by default) keeps signal size bounded while
# preserving representative spatial structure.
#
# 7. REGEX-BASED IMAGE DETECTION:
# detect_image_binary() uses multi-pattern regex matching to identify Base64 data URIs,
# PNG/JPEG hex dumps, and raw binary escape sequences. This is the gating mechanism
# for /imgnodeAttach to route image inputs to the JITGPU path.
# ==============================================================================