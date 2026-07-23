#!/usr/bin/env julia --project=.
# test_grug_live.jl — Load comprehensive kitchensink specimen, run input→response
# battery including multipart questions, arithmetic, emotional, temporal, spatial,
# causal inputs. Log all telemetry to MD file. Check for decoherence.

using Pkg
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
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
Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    add_message_to_history!, cast_vote, create_node,
    get_node_status_summary, get_bridge_summary,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK, get_alive_node_count,
    maybe_run_idle, AIMLNodeSystem, ChatterMode,
    save_specimen_to_file!

const LOG_PATH = joinpath(@__DIR__, "grug_live_test_log.md")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
end

function alive_count()::Int
    lock(NODE_LOCK) do
        count(v -> v.strength > 0.0, values(NODE_MAP))
    end
end

function decoherence_flags(output::String)::Vector{String}
    # GRUG: Strip DEBUG TELEMETRY section before checking coherence.
    # The telemetry is internal diagnostic data, NOT part of the user-visible
    # response. Checking it for repetition/stutter produces false positives.
    conversational = output
    telemetry_idx = findfirst("--- DEBUG TELEMETRY", output)
    if telemetry_idx !== nothing
        conversational = output[1:first(telemetry_idx)-1]
    end
    conversational = strip(conversational)

    flags = String[]
    isempty(conversational) && push!(flags, "EMPTY_RESPONSE")
    length(conversational) < 3 && push!(flags, "TRUNCATED")
    occursin(r"(.)\1{10,}", conversational) && push!(flags, "CHAR_STUTTER")
    occursin(r"(\b\w+\b)\s+\1\s+\1\s+\1", conversational) && push!(flags, "WORD_STUTTER")
    occursin(r"[\x00-\x08\x0e-\x1f]", conversational) && push!(flags, "CONTROL_CHARS")
    occursin(r"undefined|UndefVarError|MethodError|LoadError", conversational) && push!(flags, "STACK_LEAK")
    words = split(lowercase(conversational))
    if length(words) > 6
        trigrams = [join(words[i:i+2], " ") for i in 1:length(words)-2]
        tri_counts = Dict{String,Int}()
        for t in trigrams
            tri_counts[t] = get(tri_counts, t, 0) + 1
        end
        if maximum(values(tri_counts)) > 3
            push!(flags, "PHRASE_LOOP")
        end
    end
    return flags
end

function log_entry(io::IO, idx::Int, input::String, output::String,
                   flags::Vector{String}, extras::Dict=Dict{String,Any}())
    println(io, "### Turn $idx")
    println(io, "**Input:** `$(replace(input, r"`"=>"\\`"))`")

    # Split conversational reply from debug telemetry
    conversational = output
    telemetry = ""
    telemetry_idx = findfirst("--- DEBUG TELEMETRY", output)
    if telemetry_idx !== nothing
        conversational = strip(output[1:first(telemetry_idx)-1])
        telemetry = output[last(telemetry_idx):end]
    end

    out_disp = isempty(conversational) ? "_(empty)_" : replace(conversational, r"`"=>"\\`")
    println(io, "**Response:** $out_disp")

    # Log telemetry in a collapsible block for operator inspection
    if !isempty(telemetry)
        println(io, "<details><summary>🔍 Debug Telemetry</summary>")
        println(io, "```")
        println(io, replace(telemetry, r"`"=>"\\`"))
        println(io, "```")
        println(io, "</details>")
    end

    if !isempty(flags)
        println(io, "**⚠ Decoherence Flags:** $(join(flags, ", "))")
    else
        println(io, "**✅ Coherent**")
    end
    for (k, v) in extras
        println(io, "- $k: `$v`")
    end
    println(io, "")
end

function main()
    specimen_path = abspath(joinpath(@__DIR__, "specimens", "comprehensive_kitchensink.json"))

    open(LOG_PATH, "w") do log_io
        println(log_io, "# Grug Live Test Log — Comprehensive Kitchensink Specimen")
        println(log_io, "_Generated: $(Dates.format(now(), Dates.dateformat"yyyy-mm-dd HH:MM:SS"))_")
        println(log_io, "")
        println(log_io, "## Specimen Load")
        println(log_io, "")
        println(log_io, "**File:** `$specimen_path`")
        println(log_io, "")

        if !isfile(specimen_path)
            println(log_io, "**❌ FATAL:** Specimen file not found!")
            println("FATAL: specimen not found at $specimen_path")
            return
        end

        println("Loading specimen: $specimen_path ...")
        try
            result = load_specimen_from_file!(specimen_path)
            println(log_io, "**Load Result:**")
            println(log_io, "```")
            println(log_io, result)
            println(log_io, "```")
            println(log_io, "")
        catch e
            println(log_io, "**❌ Load Error:** $e")
            println("Load error: $e")
            return
        end

        n_alive = alive_count()
        summary = get_node_status_summary()
        bridges = get_bridge_summary()

        println(log_io, "## Baseline Telemetry")
        println(log_io, "- Alive nodes: $n_alive")
        println(log_io, "- Node summary: `$summary`")
        println(log_io, "- Bridge summary: `$bridges`")
        println(log_io, "")

        println(log_io, "## Input→Response Battery")
        println(log_io, "")

        inputs = [
            # ── Warm-up / greeting ──
            "hello",
            "hi there",
            # ── Knowledge / factual ──
            "what is fire",
            "what is a rock",
            "tell me about water",
            # ── Arithmetic (flashcard) ──
            "what is 2+2",
            "what is 3 times 4",
            "what is 10 minus 3",
            "what is 8 divided by 2",
            # ── Multipart / compound questions ──
            "what is 2+2 also what is a cat",
            "what is fire and why does it burn",
            "tell me about water and what is 5 plus 3",
            # ── Reasoning ──
            "why does ice melt",
            "how does wind work",
            # ── Social / emotional ──
            "I feel sad today",
            "that makes me happy",
            "I am angry about this",
            # ── Temporal ──
            "what happened before",
            "what is happening now",
            "what will happen next",
            # ── Spatial ──
            "where is the mountain",
            "where does the river go",
            # ── Causal ──
            "why does rain fall",
            "what causes thunder",
            # ── Possessive ──
            "whose rock is this",
            # ── Similarity ──
            "how is fire like the sun",
            # ── Novel / philosophy ──
            "describe a sunset",
            "what is the meaning of life",
            "what is consciousness",
            # ── Edge: short ──
            "hi",
            # ── Repeated (learning check) ──
            "what is fire",
            "why does ice melt",
            "I feel sad today",
            # ── Revisit greeting ──
            "hello",
            # ── Compound multipart ──
            "what is 7 times 6 also what is a tree",
            "where is the ocean and what causes waves",
        ]

        turn = 0
        decoherence_count = 0
        total_flags = String[]

        for input in inputs
            turn += 1
            print("Turn $turn: \"$input\" ... ")

            lock(_LAST_VOICE_OUTPUT_LOCK) do
                _LAST_VOICE_OUTPUT[] = ""
            end

            local _turn_elapsed = 0.0
            try
                _turn_elapsed = @elapsed process_mission(input)
            catch e
                output = "ERROR: $e"
                flags = ["PROCESS_ERROR"]
                log_entry(log_io, turn, input, output, flags,
                    Dict("exception"=>string(typeof(e)), "message"=>string(e)))
                push!(total_flags, flags...)
                decoherence_count += 1
                println("ERROR: $e")
                continue
            end

            sleep(0.3)

            output = read_last_output()
            flags = decoherence_flags(output)

            extras = Dict{String,Any}(
                "fired_node" => string(_LAST_FIRED_NODE[]),
                "primary_action" => string(_LAST_PRIMARY_ACTION[]),
                "confidence" => string(_LAST_CONFIDENCE[]),
                "latency_s" => string(round(_turn_elapsed, digits=3)),
            )

            log_entry(log_io, turn, input, output, flags, extras)

            if !isempty(flags)
                decoherence_count += 1
                append!(total_flags, flags)
                println("⚠ $(join(flags, ", "))")
            else
                println("✅")
            end
        end

        println(log_io, "## Learning Consistency Check")
        println(log_io, "")
        println(log_io, "Repeated inputs at turns 36-38 should show stable or refined responses.")
        println(log_io, "")

        n_alive_post = alive_count()
        summary_post = get_node_status_summary()

        println(log_io, "## Post-Test Telemetry")
        println(log_io, "- Alive nodes: $n_alive_post (was $n_alive)")
        println(log_io, "- Node summary: `$summary_post`")
        println(log_io, "")

        println(log_io, "## Summary")
        println(log_io, "- Total turns: $turn")
        println(log_io, "- Decoherence events: $decoherence_count")
        if !isempty(total_flags)
            flag_counts = Dict{String,Int}()
            for f in total_flags
                flag_counts[f] = get(flag_counts, f, 0) + 1
            end
            println(log_io, "- Flag breakdown:")
            for (f, c) in sort(collect(flag_counts), by=x->x[2], rev=true)
                println(log_io, "  - $f: $c")
            end
        else
            println(log_io, "- **✅ All responses coherent — zero decoherence detected**")
        end
        println(log_io, "")

        post_path = abspath(joinpath(@__DIR__, "specimens", "kitchensink_postlive.json"))
        try
            save_specimen_to_file!(post_path)
            println(log_io, "## Post-Test Specimen")
            println(log_io, "Saved to: `$post_path`")
            println(log_io, "")
        catch e
            println(log_io, "## Post-Test Specimen")
            println(log_io, "Save failed: $e")
            println(log_io, "")
        end

        println("\n══════════════════════════════════════════════════")
        println("GRUG LIVE TEST COMPLETE")
        println("  Turns: $turn")
        println("  Decoherence events: $decoherence_count")
        if decoherence_count == 0
            println("  ✅ ALL COHERENT")
        else
            println("  ⚠ DECOHERENCE DETECTED — see log")
        end
        println("  Log: $LOG_PATH")
        println("══════════════════════════════════════════════════")
    end
end

main()
