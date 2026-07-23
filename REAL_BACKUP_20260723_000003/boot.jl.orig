#!/usr/bin/env julia
# ==============================================================================
# boot.jl — GrugBot420 single-entry-point launcher
# ==============================================================================
# Usage:
#   julia boot.jl                          ← bare boot (no specimen)
#   julia boot.jl mybrain.specimen         ← boot + load specimen
#   julia boot.jl mybrain.specimen --save  ← boot + load + auto-save on exit
#   julia boot.jl --help                   ← show this usage
#
# That's it. No packagepath gymnastics, no "using .GrugBot420" rituals.
# This script handles the entire include/import chain internally.
#
# Once the "Brain >" prompt appears you can run any CLI command, e.g.:
#   /loadSpecimen <filepath>      ← restore a saved specimen at runtime
#   /mission <input>              ← ask grug something
#   /status                       ← see system state
#   /quit                         ← exit
# ==============================================================================

# ── 0. Immediate user feedback BEFORE the (slow) engine compile ───────────────
# GrugBot420 is a large codebase (~15k lines across 47 source files). Julia
# compiles it all on first load — this takes ~60-90s and prints NOTHING during
# that window, which looks like a hang. Print this banner up-front and flush
# so the user knows the boot is alive and working.
println("[BOOT] GrugBot420 starting up...")
println("[BOOT] Compiling engine (first run ~60-90s, subsequent runs faster) — please wait...")
flush(stdout)
flush(stderr)
const _BOOT_T0 = time()

# ── 1. Load the engine ─────────────────────────────────────────────────────────
const _GRUG_DIR = dirname(@__FILE__)
include(joinpath(_GRUG_DIR, "src", "GrugBot420.jl"))
using .GrugBot420

# ── 2. Import the functions the CLI needs ──────────────────────────────────────
import .GrugBot420:
    run_cli,
    process_mission,
    load_specimen_from_file!,
    save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    _LAST_SPECIMEN_PATH, _LAST_SPECIMEN_PATH_LOCK,
    LAST_VOTER_IDS, LAST_VOTER_LOCK,
    NODE_MAP, NODE_LOCK

const _BOOT_COMPILE_SECS = round(Int, time() - _BOOT_T0)
println("[BOOT] Engine compiled in $(_BOOT_COMPILE_SECS)s ✓")
flush(stdout)

# ── 3. --help: print usage and exit without launching the CLI ──────────────────
if "--help" in ARGS || "-h" in ARGS
    println("""
    GrugBot420 boot.jl — usage:
      julia boot.jl                          bare boot (no specimen)
      julia boot.jl <specimen>               boot + load specimen up-front
      julia boot.jl <specimen> --save        boot + load + auto-save on exit
      julia boot.jl --help                   this message

    Once the "Brain >" prompt appears, run any CLI command:
      /loadSpecimen <filepath>    restore a saved specimen at runtime
      /mission <input>            ask grug something
      /status                     system state
      /nodes                      node map status
      /saveSpecimen <filepath>    save current state
      /help                       full command reference
      /quit                       exit
    """)
    exit(0)
end

# ── 4. Optional specimen load from CLI arg ─────────────────────────────────────
# NOTE: the old form `something(try get(ARGS, 1); catch; nothing end, "")` is
# BROKEN — 2-arg get() on a Vector does NOT index like a Dict; it silently
# returns "" so `julia boot.jl <specimen>` never loaded the specimen. Use an
# explicit length-checked index instead.
const _SPEC_ARG  = length(ARGS) >= 1 ? String(ARGS[1]) : ""
const _SAVE_FLAG = "--save" in ARGS || "--save-on-exit" in ARGS

if _SPEC_ARG != "" && _SPEC_ARG != "--save" && _SPEC_ARG != "--save-on-exit" && _SPEC_ARG != "--help" && _SPEC_ARG != "-h"
    spec_path = _SPEC_ARG
    if !isfile(spec_path)
        # Try relative to script dir
        spec_path = joinpath(_GRUG_DIR, _SPEC_ARG)
    end
    if isfile(spec_path)
        println("[BOOT] Loading specimen: $spec_path")
        flush(stdout)
        load_specimen_from_file!(spec_path)
        println("[BOOT] Specimen loaded ✓")
        flush(stdout)
    else
        println("[BOOT] ⚠ Specimen not found: $(_SPEC_ARG) — starting bare")
        println("[BOOT]   (you can still /loadSpecimen <file> from inside the CLI)")
        flush(stdout)
    end
else
    println("[BOOT] No specimen specified — starting bare brain")
    println("[BOOT]   (use /loadSpecimen <file> from inside the CLI to load one)")
    flush(stdout)
end

# ── 5. Auto-save hook (if --save flag) ─────────────────────────────────────────
if _SAVE_FLAG
    atexit() do
        sp = lock(() -> _LAST_SPECIMEN_PATH[], _LAST_SPECIMEN_PATH_LOCK)
        if sp != "" && isfile(sp)
            try
                save_specimen_to_file!(sp)
                println("[EXIT] Auto-saved specimen: $sp ✓")
            catch e
                println("[EXIT] ⚠ Auto-save failed: $e")
            end
        else
            println("[EXIT] No specimen path recorded — skipping auto-save")
        end
    end
end

# ── 6. Launch CLI ──────────────────────────────────────────────────────────────
println("[BOOT] Launching GrugBot420 CLI...")
println()
flush(stdout)
run_cli()
