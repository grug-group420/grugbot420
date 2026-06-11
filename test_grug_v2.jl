#!/usr/bin/env julia --project=.
# test_grug_v2.jl — GrugBot420 v2 test: clean Q->R log, heavy multipart task trails

using Pkg; Pkg.instantiate()
using Dates
include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_AIML_OUTPUT, _LAST_AIML_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK, get_alive_node_count,
    save_specimen_to_file!

const LOG_PATH = joinpath(@__DIR__, "grug_test_log_v2.md")

read_last_output() = lock(_LAST_AIML_OUTPUT_LOCK) do; _LAST_AIML_OUTPUT[]; end
alive_count() = lock(NODE_LOCK) do; count(v -> v.strength > 0.0, values(NODE_MAP)); end

function decoherence_flags(output::String)::Vector{String}
    conv = output
    idx = findfirst("--- DEBUG TELEMETRY", output)
    if idx !== nothing; conv = strip(output[1:first(idx)-1]); end
    flags = String[]
    isempty(conv) && push!(flags, "EMPTY_RESPONSE")
    length(conv) < 3 && push!(flags, "TRUNCATED")
    occursin(r"(.)\1{10,}", conv) && push!(flags, "CHAR_STUTTER")
    occursin(r"(\b\w+\b)\s+\1\s+\1\s+\1", conv) && push!(flags, "WORD_STUTTER")
    occursin(r"undefined|UndefVarError|MethodError|LoadError", conv) && push!(flags, "STACK_LEAK")
    occursin(r"&noun|&verb|&temporal|&causal|&spatial|&possessive|&similarity", conv) && push!(flags, "SIGIL_LEAK")
    words = split(lowercase(conv))
    if length(words) > 6
        trigrams = [join(words[i:i+2]," ") for i in 1:length(words)-2]
        tc = Dict{String,Int}(); for t in trigrams; tc[t]=get(tc,t,0)+1; end
        maximum(values(tc)) > 3 && push!(flags, "PHRASE_LOOP")
    end
    return flags
end

function clean_conversational(output::String)::String
    conv = output
    idx = findfirst("--- DEBUG TELEMETRY", output)
    if idx !== nothing; conv = strip(output[1:first(idx)-1]); end
    return conv
end

function main()
    specimen_path = abspath(joinpath(@__DIR__, "specimens", "comprehensive_kitchensink.json"))
    open(LOG_PATH, "w") do log_io
        println(log_io, "# GrugBot420 Test Log v2")
        println(log_io, "_Generated: $(Dates.format(now(), Dates.dateformat"yyyy-mm-dd HH:MM:SS"))_")
        println(log_io, "")
        println(log_io, "## Specimen")
        println(log_io, "- **File:** `comprehensive_kitchensink.json`")
        println(log_io, "- **Size:** $(filesize(specimen_path)) bytes")
        println(log_io, "")

        println("Loading specimen..."); flush(stdout)
        try; load_specimen_from_file!(specimen_path); catch e; println("LOAD FAIL: $e"); return; end
        n_alive = alive_count()
        println(log_io, "- **Nodes alive:** $n_alive")
        println(log_io, "")
        println(log_io, "---")
        println(log_io, "")

        # ── TEST INPUTS ──
        inputs = [
            # 1. Warm-up (3)
            "hello",
            "hi there",
            "good morning",

            # 2. Simple factual — baseline (8)
            "what is fire",
            "what is a rock",
            "tell me about water",
            "what is a tree",
            "what is a cat",
            "what is gravity",
            "what is DNA",
            "what is consciousness",

            # 3. Arithmetic (8)
            "what is 2 plus 2",
            "what is 3 times 4",
            "what is 10 minus 3",
            "what is 8 divided by 2",
            "what is 7 plus 5",
            "what is 100 minus 37",
            "what is 6 times 9",
            "what is the square root of 16",

            # 4. TWO-PART multipart — task trail (20)
            "what is 2 plus 2 also what is a dog",
            "what is fire and why does it burn",
            "tell me about water and what is 5 plus 3",
            "what is 7 times 6 also what is a tree",
            "where is the ocean and what causes waves",
            "what is gravity also why does ice melt",
            "what is a rock and what is 4 plus 4",
            "how does wind work and what is 9 minus 2",
            "what is DNA also what is consciousness",
            "what is fire also what is the meaning of life",
            "I feel sad and what is 3 plus 3",
            "what is a cat also what is evolution",
            "what causes thunder and what is 3 times 7",
            "where is the moon and what is photosynthesis",
            "why does rain fall and what is a forest",
            "what is thermodynamics also what is pi",
            "I feel happy also what is 10 plus 10",
            "what is free will and what is a river",
            "describe a sunset also what is 8 minus 5",
            "what is DNA and how do magnets work",

            # 5. THREE-PART multipart — heavy task trail (15)
            "what is fire and what is water also what is 3 plus 5",
            "why does rain fall and where does the river go also what is a rock",
            "I feel sad and what is 4 times 6 also what is DNA",
            "what is consciousness and how is fire like the sun also what causes thunder",
            "what is 5 plus 7 and what is a tree also why does ice melt",
            "tell me about water and what is 9 minus 3 also what is gravity",
            "where is the ocean and what is photosynthesis also what is 2 times 8",
            "what is a cat and what is free will also what causes lightning",
            "I am angry and what is 12 divided by 4 also what is DNA",
            "what is thermodynamics and what is a forest also what is 6 plus 6",
            "how does wind work and what is consciousness also what is 3 times 9",
            "what is a rock and what is evolution also why does the sun shine",
            "what is the meaning of life and what is 15 minus 7 also what is water",
            "describe a forest and what is gravity also what is 4 times 5",
            "what is truth and what is a cat also what causes earthquakes",

            # 6. FOUR-PART multipart — extreme task trail (8)
            "what is fire and what is water also what is 2 plus 2 and what is a tree",
            "I feel sad and what is gravity also what is 3 times 4 and why does ice melt",
            "what is DNA and what is consciousness also what is 8 minus 3 and what is a rock",
            "where is the ocean and what causes waves also what is 5 plus 5 and what is a cat",
            "what is thermodynamics and what is a forest also what is 6 times 7 and what is truth",
            "how does wind work and what is evolution also what is 10 minus 4 and what is water",
            "what is the meaning of life and what is fire also what is 9 plus 1 and what is DNA",
            "I feel happy and what is a tree also what is 3 times 8 and what causes thunder",

            # 7. Reasoning / causal (5)
            "why does ice melt",
            "how does wind work",
            "why does rain fall",
            "what causes thunder",
            "how do magnets work",

            # 8. Emotional (5)
            "I feel sad today",
            "that makes me happy",
            "I am angry about this",
            "I feel confused",
            "I feel grateful for this",

            # 9. Temporal (4)
            "what happened before",
            "what will happen next",
            "when was gravity discovered",
            "what happens after sunset",

            # 10. Spatial (3)
            "where is the mountain",
            "where does the river go",
            "where is the ocean",

            # 11. Causal sigil (3)
            "what produces light",
            "what generates electricity",
            "what triggers a volcano",

            # 12. Possessive sigil (3)
            "what does a tree have",
            "what does fire contain",
            "what does the ocean hold",

            # 13. Similarity sigil (3)
            "how is fire like the sun",
            "what resembles water",
            "how is a cat like a lion",

            # 14. Philosophy (4)
            "what is the meaning of life",
            "what is free will",
            "what is truth",
            "what is reality",

            # 15. Science (4)
            "what is thermodynamics",
            "explain quantum mechanics",
            "what is the periodic table",
            "what is the speed of light",

            # 16. Nature (3)
            "describe a forest",
            "what is an ecosystem",
            "what is photosynthesis",

            # 17. Prose (2)
            "describe a sunset",
            "tell me a story about fire",

            # 18. Edge cases (5)
            "asdfghjkl",
            "what what what",
            "why why why",
            "a",
            "what is 999999 plus 999999",

            # 19. Repeated — learning consistency (4)
            "what is fire",
            "what is 2 plus 2",
            "I feel sad today",
            "what is gravity",
        ]

        turn = 0
        decoherence_count = 0
        total_flags = String[]
        latencies = Float64[]

        for input in inputs
            turn += 1
            print("Turn $turn: \"$input\" ... "); flush(stdout)

            lock(_LAST_AIML_OUTPUT_LOCK) do; _LAST_AIML_OUTPUT[] = ""; end

            local elapsed = 0.0
            try; elapsed = @elapsed process_mission(input); catch e
                println(log_io, "### Turn $turn")
                println(log_io, "**Q:** `$(replace(input, r"`"=>"\\`"))`")
                println(log_io, "**A:** ⚠ ERROR: $e")
                println(log_io, "**Coherence:** ❌ PROCESS_ERROR")
                println(log_io, "")
                push!(total_flags, "PROCESS_ERROR"); decoherence_count += 1
                println("ERROR"); continue
            end

            sleep(0.1)
            output = read_last_output()
            conv = clean_conversational(output)
            flags = decoherence_flags(output)
            push!(latencies, elapsed)

            fired = string(_LAST_FIRED_NODE[])
            conf = string(_LAST_CONFIDENCE[])
            coherent = isempty(flags)

            # ── Clean log entry ──
            println(log_io, "### Turn $turn")
            println(log_io, "**Q:** `$(replace(input, r"`"=>"\\`"))`")
            disp = isempty(conv) ? "_(empty)_" : replace(conv, r"`"=>"\\`")
            println(log_io, "**A:** $disp")
            println(log_io, "**Node:** `$fired` | **Conf:** `$conf` | **Latency:** $(round(elapsed,digits=3))s")
            if !isempty(flags)
                println(log_io, "**Coherence:** ⚠ $(join(flags, ", "))")
                decoherence_count += 1; append!(total_flags, flags)
                println("⚠ $(join(flags, ", "))")
            else
                println(log_io, "**Coherence:** ✅")
                println("✅")
            end
            println(log_io, "")
        end

        # ── Summary ──
        println(log_io, "---")
        println(log_io, "")
        println(log_io, "## Summary")
        println(log_io, "- **Turns:** $turn")
        println(log_io, "- **Coherent:** $(turn - decoherence_count)")
        println(log_io, "- **Decoherence events:** $decoherence_count")
        if !isempty(total_flags)
            fc = Dict{String,Int}(); for f in total_flags; fc[f]=get(fc,f,0)+1; end
            println(log_io, "- **Flag breakdown:**")
            for (f,c) in sort(collect(fc), by=x->x[2], rev=true)
                println(log_io, "  - $f: $c")
            end
        end
        if !isempty(latencies)
            s = sort(latencies)
            println(log_io, "- **Latency:** min=$(round(minimum(s),digits=3))s  P50=$(round(s[ceil(Int,length(s)*0.5)],digits=3))s  P90=$(round(s[min(ceil(Int,length(s)*0.9),length(s))],digits=3))s  max=$(round(maximum(s),digits=3))s")
        end
        println(log_io, "")

        # Save post-test specimen
        post_path = abspath(joinpath(@__DIR__, "specimens", "kitchensink_postlive.json"))
        try; save_specimen_to_file!(post_path); catch; end

        println("\n══════════════════════════════════════")
        println("GRUG TEST v2 COMPLETE")
        println("  Turns: $turn | Decoherence: $decoherence_count")
        if !isempty(latencies)
            s=sort(latencies)
            println("  Latency P50: $(round(s[ceil(Int,length(s)*0.5)],digits=3))s")
        end
        println("  Log: $LOG_PATH")
        println("══════════════════════════════════════")
    end
end

main()
