#!/usr/bin/env julia
# test_lobe_polarity_sensitivity.jl — v7.35 per-lobe polarity gate overrides

const REPO_ROOT = joinpath(@__DIR__)

# Load Lobe dependencies
include(joinpath(REPO_ROOT, "src", "LobeTable.jl"))
using .LobeTable
include(joinpath(REPO_ROOT, "src", "Lobe.jl"))
using .Lobe

# ── TEST HELPERS ───────────────────────────────────────────
n_pass = 0
n_fail = 0

function tcheck(name::String, result::Bool)
    global n_pass, n_fail
    if result
        n_pass += 1
        println("[$(n_pass + n_fail)] $name ... PASS")
    else
        n_fail += 1
        println("[$(n_pass + n_fail)] $name ... FAIL")
    end
end

# ── CLEAN STATE ──
# Clear the lobe registry before each test
for k in collect(keys(Lobe.LOBE_REGISTRY))
    delete!(Lobe.LOBE_REGISTRY, k)
end
for k in collect(keys(Lobe.NODE_TO_LOBE_IDX))
    delete!(Lobe.NODE_TO_LOBE_IDX, k)
end
# Clear lobe tables
for k in collect(keys(LobeTable.LOBE_TABLE_REGISTRY))
    delete!(LobeTable.LOBE_TABLE_REGISTRY, k)
end

# ── 1. New LobeRecord has nothing for polarity fields ──
tcheck("New LobeRecord has negative_mult=nothing",
    let
        rec = Lobe.create_lobe!("test1", "testing")
        rec.negative_mult === nothing
    end)

tcheck("New LobeRecord has neutral_mult=nothing",
    let
        rec = Lobe.get_lobe("test1")
        rec.neutral_mult === nothing
    end)

# ── 2. get_lobe_polarity_sensitivity returns nothing,nothing ──
tcheck("get_lobe_polarity_sensitivity returns (nothing, nothing) for default lobe",
    let
        neg, neu = Lobe.get_lobe_polarity_sensitivity("test1")
        neg === nothing && neu === nothing
    end)

# ── 3. set_lobe_polarity_sensitivity! works ──
tcheck("set_lobe_polarity_sensitivity! sets negative_mult=0.1",
    let
        Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=0.1)
        neg, neu = Lobe.get_lobe_polarity_sensitivity("test1")
        neg === 0.1 && neu === nothing
    end)

tcheck("set_lobe_polarity_sensitivity! sets neutral_mult=0.5",
    let
        Lobe.set_lobe_polarity_sensitivity!("test1"; neutral_mult=0.5)
        neg, neu = Lobe.get_lobe_polarity_sensitivity("test1")
        neg === 0.1 && neu === 0.5
    end)

# ── 4. reset_lobe_polarity_sensitivity! clears overrides ──
tcheck("reset_lobe_polarity_sensitivity! clears to nothing",
    let
        Lobe.reset_lobe_polarity_sensitivity!("test1")
        neg, neu = Lobe.get_lobe_polarity_sensitivity("test1")
        neg === nothing && neu === nothing
    end)

# ── 5. Invalid multiplier range throws ──
tcheck("set_lobe_polarity_sensitivity! with negative_mult=1.5 throws",
    try; Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=1.5); false
    catch; true; end)

tcheck("set_lobe_polarity_sensitivity! with negative_mult=-0.1 throws",
    try; Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=-0.1); false
    catch; true; end)

tcheck("set_lobe_polarity_sensitivity! with neutral_mult=2.0 throws",
    try; Lobe.set_lobe_polarity_sensitivity!("test1"; neutral_mult=2.0); false
    catch; true; end)

# ── 6. Invalid lobe throws ──
tcheck("set_lobe_polarity_sensitivity! on nonexistent lobe throws",
    try; Lobe.set_lobe_polarity_sensitivity!("nonexistent"; negative_mult=0.1); false
    catch; true; end)

tcheck("get_lobe_polarity_sensitivity on nonexistent lobe throws",
    try; Lobe.get_lobe_polarity_sensitivity("nonexistent"); false
    catch; true; end)

# ── 7. Boundary values are valid ──
tcheck("negative_mult=0.0 is valid (full suppression)",
    try; Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=0.0); true
    catch; false; end)

tcheck("negative_mult=1.0 is valid (no suppression)",
    try; Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=1.0); true
    catch; false; end)

# ── 8. Status summary includes polarity info ──
tcheck("get_lobe_status_summary includes pol[] when overrides set",
    let
        Lobe.set_lobe_polarity_sensitivity!("test1"; negative_mult=0.1, neutral_mult=0.5)
        summary = Lobe.get_lobe_status_summary()
        occursin("pol[neg=0.1x neu=0.5x]", summary)
    end)

tcheck("get_lobe_status_summary omits pol[] when no overrides",
    let
        Lobe.reset_lobe_polarity_sensitivity!("test1")
        summary = Lobe.get_lobe_status_summary()
        !occursin("pol[", summary)
    end)

# ── SUMMARY ──
println()
println("=" ^ 60)
if n_fail == 0
    println("ALL $(n_pass) LOBE POLARITY SENSITIVITY TESTS PASSED")
else
    println("$(n_pass) PASSED, $(n_fail) FAILED")
end
println("=" ^ 60)
