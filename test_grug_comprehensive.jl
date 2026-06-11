#!/usr/bin/env julia --project=.
# test_grug_comprehensive.jl — Full-spectrum test battery for GrugBot420
# 80+ inputs covering ALL node types, ALL lobes, multipart compound questions,
# dynamic relational sigils (&causal, &temporal, &spatial, &possessive, &similarity),
# arithmetic, emotional, temporal, spatial, causal, possessive, similarity,
# philosophy, prose, image, antimatch, grave, time nodes, and edge cases.
# Log everything with telemetry to MD file.

using Pkg
Pkg.instantiate()
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    add_message_to_history!, cast_vote, create_node,
    get_node_status_summary, get_bridge_summary,
    _LAST_AIML_OUTPUT, _LAST_AIML_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK, get_alive_node_count,
    maybe_run_idle, AIMLNodeSystem, ChatterMode,
    save_specimen_to_file!

const LOG_PATH = joinpath(@__DIR__, "grug_comprehensive_test_log.md")

function read_last_output()::String
    lock(_LAST_AIML_OUTPUT_LOCK) do
        _LAST_AIML_OUTPUT[]
    end
end

function alive_count()::Int
    lock(NODE_LOCK) do
        count(v -> v.strength > 0.0, values(NODE_MAP))
    end
end

function decoherence_flags(output::String)::Vector{String}
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
    # Check for leaked sigils in output
    occursin(r"&noun|&verb|&temporal|&causal|&spatial|&possessive|&similarity", conversational) && push!(flags, "SIGIL_LEAK")
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

    conversational = output
    telemetry = ""
    telemetry_idx = findfirst("--- DEBUG TELEMETRY", output)
    if telemetry_idx !== nothing
        conversational = strip(output[1:first(telemetry_idx)-1])
        telemetry = output[last(telemetry_idx):end]
    end

    out_disp = isempty(conversational) ? "_(empty)_" : replace(conversational, r"`"=>"\\`")
    println(io, "**Response:** $out_disp")

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
        println(log_io, "# GrugBot420 Comprehensive Test Log")
        println(log_io, "_Generated: $(Dates.format(now(), Dates.dateformat"yyyy-mm-dd HH:MM:SS"))_")
        println(log_io, "")
        println(log_io, "## Specimen Info")
        println(log_io, "- **File:** `$specimen_path`")
        println(log_io, "- **File size:** $(filesize(specimen_path)) bytes")
        println(log_io, "- **Dynamic sigils:** &causal, &temporal, &spatial, &possessive, &similarity in relational triple relation fields")
        println(log_io, "- **Subject/object fields:** Concrete words (no &noun leaks)")
        println(log_io, "")

        if !isfile(specimen_path)
            println(log_io, "**❌ FATAL:** Specimen file not found!")
            println("FATAL: specimen not found at $specimen_path")
            return
        end

        println("Loading specimen: $specimen_path ...")
        try
            result = load_specimen_from_file!(specimen_path)
            println(log_io, "## Specimen Load Result")
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

        println(log_io, "## Input→Response Battery (80+ turns)")
        println(log_io, "")

        inputs = [
            # ── 1. Warm-up / greeting (3) ──
            "hello",
            "hi there",
            "good morning",
            # ── 2. Knowledge / factual across lobes (8) ──
            "what is fire",
            "what is a rock",
            "tell me about water",
            "what is a tree",
            "what is a cat",
            "what is gravity",
            "what is DNA",
            "what is consciousness",
            # ── 3. Arithmetic — math lobe (10) ──
            "what is 2+2",
            "what is 3 times 4",
            "what is 10 minus 3",
            "what is 8 divided by 2",
            "what is 7 plus 5",
            "what is 100 minus 37",
            "what is 6 times 9",
            "what is 15 divided by 3",
            "what is the square root of 16",
            "is 7 greater than 3",
            # ── 4. Multipart compound questions — THE KEY TEST (12) ──
            "what is 2+2 also what is a cat",
            "what is fire and why does it burn",
            "tell me about water and what is 5 plus 3",
            "what is 7 times 6 also what is a tree",
            "where is the ocean and what causes waves",
            "what is gravity also why does ice melt",
            "what is a rock and what is 4 plus 4",
            "how does wind work and what is 9 minus 2",
            "what is DNA also what is consciousness",
            "what is fire also what is the meaning of life",
            "tell me about water also what is a cat",
            "what causes thunder and what is 3 times 7",
            # ── 5. Reasoning / causal (6) ──
            "why does ice melt",
            "how does wind work",
            "why does rain fall",
            "what causes thunder",
            "why does the sun shine",
            "how do magnets work",
            # ── 6. Social / emotional — emotions lobe (6) ──
            "I feel sad today",
            "that makes me happy",
            "I am angry about this",
            "I feel confused",
            "I am worried about tomorrow",
            "I feel grateful for this",
            # ── 7. Temporal — time nodes / &temporal sigil (5) ──
            "what happened before",
            "what is happening now",
            "what will happen next",
            "when was gravity discovered",
            "what happens after sunset",
            # ── 8. Spatial — &spatial sigil (5) ──
            "where is the mountain",
            "where does the river go",
            "where is the ocean",
            "where are the stars located",
            "where is the moon in the sky",
            # ── 9. Causal — &causal sigil (4) ──
            "why does heat cause expansion",
            "what produces light",
            "what generates electricity",
            "what triggers a volcano",
            # ── 10. Possessive — &possessive sigil (4) ──
            "whose rock is this",
            "what does a tree have",
            "what does fire contain",
            "what does the ocean hold",
            # ── 11. Similarity — &similarity sigil (4) ──
            "how is fire like the sun",
            "what resembles water",
            "how is a cat like a lion",
            "what is similar to gravity",
            # ── 12. Philosophy — philosophy lobe (5) ──
            "what is the meaning of life",
            "what is consciousness",
            "what is free will",
            "what is truth",
            "what is reality",
            # ── 13. Science — science lobe (5) ──
            "what is thermodynamics",
            "explain quantum mechanics",
            "what is the periodic table",
            "explain relativity",
            "what is the speed of light",
            # ── 14. Nature — nature lobe (4) ──
            "describe a forest",
            "what is an ecosystem",
            "how do rivers form",
            "what is photosynthesis",
            # ── 15. Prose / descriptive (3) ──
            "describe a sunset",
            "paint me a picture of the ocean",
            "tell me a story about fire",
            # ── 16. Repeated inputs — learning consistency (6) ──
            "what is fire",
            "why does ice melt",
            "I feel sad today",
            "what is 2+2",
            "hello",
            "what is gravity",
            # ── 17. Edge cases / stress (6) ──
            "hi",
            "asdfghjkl",
            "",
            "what what what",
            "why why why",
            "a",
            # ── 18. Triple-multipart — extreme compound (4) ──
            "what is fire and what is water also what is 3 plus 5",
            "why does rain fall and where does the river go also what is a rock",
            "I feel sad and what is 4 times 6 also what is DNA",
            "what is consciousness and how is fire like the sun also what causes thunder",
        ]

        turn = 0
        decoherence_count = 0
        total_flags = String[]
        latencies = Float64[]

        for input in inputs
            turn += 1
            # Skip empty input for processing but still log it
            if isempty(input)
                log_entry(log_io, turn, "_(empty input)_", "_(skipped — empty input)_",
                    ["EMPTY_INPUT"],
                    Dict{String,Any}("latency_s" => "0.0"))
                push!(total_flags, "EMPTY_INPUT")
                decoherence_count += 1
                println("Turn $turn: \"\" ... ⚠ EMPTY_INPUT")
                continue
            end

            print("Turn $turn: \"$input\" ... ")

            lock(_LAST_AIML_OUTPUT_LOCK) do
                _LAST_AIML_OUTPUT[] = ""
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

            sleep(0.1)

            output = read_last_output()
            flags = decoherence_flags(output)
            push!(latencies, _turn_elapsed)

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

        # ── Learning consistency analysis ──
        println(log_io, "## Learning Consistency Check")
        println(log_io, "")
        println(log_io, "Repeated inputs at turns 61-66 should show stable or refined responses.")
        println(log_io, "Compare with their first appearances:")
        println(log_io, "- Turn 4 vs Turn 61: `what is fire`")
        println(log_io, "- Turn 38 vs Turn 62: `why does ice melt`")
        println(log_io, "- Turn 43 vs Turn 63: `I feel sad today`")
        println(log_io, "- Turn 10 vs Turn 64: `what is 2+2`")
        println(log_io, "- Turn 1 vs Turn 65: `hello`")
        println(log_io, "- Turn 26 vs Turn 66: `what is gravity`")
        println(log_io, "")

        # ── Latency statistics ──
        if !isempty(latencies)
            sorted = sort(latencies)
            p50 = sorted[ceil(Int, length(sorted) * 0.5)]
            p90 = sorted[min(ceil(Int, length(sorted) * 0.9), length(sorted))]
            p99 = sorted[min(ceil(Int, length(sorted) * 0.99), length(sorted))]
            avg_lat = sum(latencies) / length(latencies)
            max_lat = maximum(latencies)
            min_lat = minimum(latencies)

            println(log_io, "## Latency Statistics")
            println(log_io, "- Turns measured: $(length(latencies))")
            println(log_io, "- Min: $(round(min_lat, digits=3))s")
            println(log_io, "- P50: $(round(p50, digits=3))s")
            println(log_io, "- P90: $(round(p90, digits=3))s")
            println(log_io, "- P99: $(round(p99, digits=3))s")
            println(log_io, "- Max: $(round(max_lat, digits=3))s")
            println(log_io, "- Mean: $(round(avg_lat, digits=3))s")
            println(log_io, "")
        end

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

        # Save post-test specimen
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

        println("\n════════════════════════════════════════════════════════")
        println("GRUG COMPREHENSIVE TEST COMPLETE")
        println("  Turns: $turn")
        println("  Decoherence events: $decoherence_count")
        if !isempty(latencies)
            println("  Latency P50: $(round(sort(latencies)[ceil(Int,length(latencies)*0.5)], digits=3))s")
            println("  Latency P90: $(round(sort(latencies)[min(ceil(Int,length(latencies)*0.9),length(latencies))], digits=3))s")
        end
        if decoherence_count == 0
            println("  ✅ ALL COHERENT")
        else
            println("  ⚠ DECOHERENCE DETECTED — see log")
        end
        println("  Log: $LOG_PATH")
        println("════════════════════════════════════════════════════════")
    end
end

main()
