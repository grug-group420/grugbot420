#!/usr/bin/env julia --project=.
# test_comprehensive_v82.jl — Full interaction test with v758 specimen
# Tests: multipart questions, regular questions, action sigil votes, regular votes,
#        arithmetic (post-fix verification), grug questioning mechanism
using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    add_message_to_history!, cast_vote, create_node,
    get_node_status_summary, get_bridge_summary,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK,
    maybe_run_idle, save_specimen_to_file!,
    RelationalTriple

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v758_patched.json")
const SPEC_SAVE_PATH = joinpath(@__DIR__, "specimens", "v82_post_test.json")
const LOG_JSON_PATH = joinpath(@__DIR__, "test_results_v82.json")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function alive_count()::Int
    lock(NODE_LOCK) do; count(v -> v.strength > 0.0, values(NODE_MAP)); end
end

function decoherence_flags(output::String)::Vector{String}
    conv = output
    ti = findfirst("--- DEBUG TELEMETRY", output)
    if ti !== nothing; conv = strip(output[1:first(ti)-1]); end
    flags = String[]
    isempty(conv) && push!(flags, "EMPTY_RESPONSE")
    occursin(r"(.)\1{10,}", conv) && push!(flags, "CHAR_STUTTER")
    occursin(r"(\b\w+\b)\s+\1\s+\1\s+\1", conv) && push!(flags, "WORD_STUTTER")
    occursin(r"undefined|UndefVarError|MethodError|LoadError", conv) && push!(flags, "STACK_LEAK")
    words = split(lowercase(conv))
    if length(words) > 6
        trigrams = [join(words[i:i+2]," ") for i in 1:length(words)-2]
        tc = Dict{String,Int}(); for t in trigrams; tc[t]=get(tc,t,0)+1; end
        maximum(values(tc)) > 3 && push!(flags, "PHRASE_LOOP")
    end
    return flags
end

function extract_arithmetic(output::String)::String
    m = match(r"Arithmetic Computed:\s*(.+)", output)
    return m !== nothing ? m.captures[1] : ""
end

function extract_primary_action(output::String)::String
    m = match(r"Primary Action:\s*(\w+)", output)
    return m !== nothing ? String(m.captures[1]) : ""
end

function extract_confidence(output::String)::String
    m = match(r"conf=([\d.]+)", output)
    return m !== nothing ? String(m.captures[1]) : ""
end

function extract_winning_node(output::String)::String
    m = match(r"Winning Node:\s*(\S+)", output)
    return m !== nothing ? String(m.captures[1]) : ""
end

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    t = @elapsed begin; try; process_mission(text); catch e; @warn "err: $e"; end; end
    resp = read_last_output()
    return (resp, t)
end

function main()
    println("=" ^ 60)
    println("GRUGBOT420 COMPREHENSIVE TEST v82")
    println("Specimen: $SPEC_PATH")
    println("=" ^ 60)

    # Load specimen
    println("\n[1] Loading specimen...")
    result = load_specimen_from_file!(SPEC_PATH)
    println("  Load result: $result")
    n0 = alive_count()
    println("  Alive nodes: $n0")

    # Collect all results for JSON export
    results = Dict{String,Any}()
    results["timestamp"] = Dates.format(now(), Dates.dateformat"yyyy-mm-dd HH:MM:SS")
    results["specimen"] = SPEC_PATH
    results["baseline_alive"] = n0

    # ============================================================
    # CATEGORY 1: Arithmetic (post-fix verification)
    # ============================================================
    println("\n[2] Arithmetic Engine Tests...")
    arith_tests = [
        ("what is 2 plus 2", "4"),
        ("what is 3 plus 4", "7"),
        ("what is 10 minus 3", "7"),
        ("what is 5 times 6", "30"),
        ("what is 8 plus 9", "17"),
    ]
    arith_results = []
    for (query, expected) in arith_tests
        resp, t = run_mission(query)
        found = occursin(expected, resp)
        flags = decoherence_flags(resp)
        arith_computed = extract_arithmetic(resp)
        entry = Dict(
            "query" => query,
            "expected" => expected,
            "pass" => found,
            "time_s" => round(t, digits=2),
            "decoherence_flags" => flags,
            "arithmetic_computed" => arith_computed,
            "response_excerpt" => first(resp, 300)
        )
        push!(arith_results, entry)
        println("  [$query] → $expected: $(found ? "✅" : "⚠️") ($(round(t,digits=2))s) arith=$arith_computed$(isempty(flags) ? "" : " flags=$(join(flags,","))")")
    end
    results["arithmetic"] = arith_results

    # ============================================================
    # CATEGORY 2: Regular Questions
    # ============================================================
    println("\n[3] Regular Questions...")
    regular_tests = [
        "hello",
        "what is fire",
        "tell me about rocks",
        "what is water",
        "how does grug think",
    ]
    regular_results = []
    for query in regular_tests
        resp, t = run_mission(query)
        flags = decoherence_flags(resp)
        conv = resp; ti=findfirst("--- DEBUG TELEMETRY",resp); if ti !== nothing; conv=strip(resp[1:first(ti)-1]); end
        action = extract_primary_action(resp)
        conf = extract_confidence(resp)
        node = extract_winning_node(resp)
        entry = Dict(
            "query" => query,
            "time_s" => round(t, digits=2),
            "decoherence_flags" => flags,
            "primary_action" => action,
            "confidence" => conf,
            "winning_node" => node,
            "response_excerpt" => first(conv, 300)
        )
        push!(regular_results, entry)
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println("  [$query]: $flag_str ($(round(t,digits=2))s) action=$action conf=$conf node=$node")
    end
    results["regular_questions"] = regular_results

    # ============================================================
    # CATEGORY 3: Multipart Questions
    # ============================================================
    println("\n[4] Multipart Questions...")
    multipart_tests = [
        "what is 2 plus 2 also what is fire",
        "what is fire and why does it burn",
        "tell me about water and what is 5 plus 3",
        "hello and what is 8 minus 2",
    ]
    multipart_results = []
    for query in multipart_tests
        resp, t = run_mission(query)
        flags = decoherence_flags(resp)
        conv = resp; ti=findfirst("--- DEBUG TELEMETRY",resp); if ti !== nothing; conv=strip(resp[1:first(ti)-1]); end
        arith = extract_arithmetic(resp)
        action = extract_primary_action(resp)
        entry = Dict(
            "query" => query,
            "time_s" => round(t, digits=2),
            "decoherence_flags" => flags,
            "arithmetic_computed" => arith,
            "primary_action" => action,
            "response_excerpt" => first(conv, 300)
        )
        push!(multipart_results, entry)
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println("  [$query]: $flag_str ($(round(t,digits=2))s) arith=$arith action=$action")
    end
    results["multipart_questions"] = multipart_results

    # ============================================================
    # CATEGORY 4: Action Sigil Votes (!, ?, ~)
    # ============================================================
    println("\n[5] Action Sigil Votes...")
    action_tests = [
        "!think about fire",
        "?what is water",
        "~ponder the nature of rocks",
        "!calculate 3 plus 5",
        "?tell me about grug",
    ]
    action_results = []
    for query in action_tests
        resp, t = run_mission(query)
        flags = decoherence_flags(resp)
        conv = resp; ti=findfirst("--- DEBUG TELEMETRY",resp); if ti !== nothing; conv=strip(resp[1:first(ti)-1]); end
        action = extract_primary_action(resp)
        conf = extract_confidence(resp)
        entry = Dict(
            "query" => query,
            "time_s" => round(t, digits=2),
            "decoherence_flags" => flags,
            "primary_action" => action,
            "confidence" => conf,
            "response_excerpt" => first(conv, 300)
        )
        push!(action_results, entry)
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println("  [$query]: $flag_str ($(round(t,digits=2))s) action=$action conf=$conf")
    end
    results["action_sigil_votes"] = action_results

    # ============================================================
    # CATEGORY 5: Regular Votes (cast_vote)
    # ============================================================
    println("\n[6] Regular Votes (explicit cast_vote)...")
    vote_results = []
    try
        for node_id in ["node_1", "node_2"]
            try
                vote_id, confidence, certainty, action = cast_vote(node_id, 0.8, false, RelationalTriple[], Int[])
                entry = Dict(
                    "node_id" => node_id,
                    "vote_id" => vote_id,
                    "confidence" => confidence,
                    "certainty" => string(certainty),
                    "action" => action,
                    "pass" => true
                )
                push!(vote_results, entry)
                println("  [$node_id] vote=$vote_id conf=$confidence cert=$certainty action=$action ✅")
            catch e
                entry = Dict("node_id" => node_id, "error" => string(e), "pass" => false)
                push!(vote_results, entry)
                println("  [$node_id] ERROR: $e ⚠️")
            end
        end
    catch e
        println("  Vote test error: $e")
    end
    results["regular_votes"] = vote_results

    # ============================================================
    # CATEGORY 6: Grug Questioning Mechanism
    # ============================================================
    println("\n[7] Grug Questioning Mechanism...")
    questioning_tests = [
        "why does fire burn",
        "how does water become ice",
        "why is sky blue",
    ]
    questioning_results = []
    for query in questioning_tests
        resp, t = run_mission(query)
        flags = decoherence_flags(resp)
        conv = resp; ti=findfirst("--- DEBUG TELEMETRY",resp); if ti !== nothing; conv=strip(resp[1:first(ti)-1]); end
        has_question_word = occursin(r"\b(why|how|what|where|when)\b", lowercase(conv))
        entry = Dict(
            "query" => query,
            "time_s" => round(t, digits=2),
            "decoherence_flags" => flags,
            "response_has_question_word" => has_question_word,
            "response_excerpt" => first(conv, 300)
        )
        push!(questioning_results, entry)
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println("  [$query]: $flag_str ($(round(t,digits=2))s) question_word=$has_question_word")
    end
    results["grug_questioning"] = questioning_results

    # ============================================================
    # Summary
    # ============================================================
    n_final = alive_count()
    results["final_alive"] = n_final
    results["node_delta"] = n_final - n0

    # Count passes
    arith_pass = count(r -> r["pass"], arith_results)
    arith_total = length(arith_results)
    all_responses = vcat(
        [Dict("query"=>r["query"],"flags"=>r["decoherence_flags"]) for r in arith_results],
        [Dict("query"=>r["query"],"flags"=>r["decoherence_flags"]) for r in regular_results],
        [Dict("query"=>r["query"],"flags"=>r["decoherence_flags"]) for r in multipart_results],
        [Dict("query"=>r["query"],"flags"=>r["decoherence_flags"]) for r in action_results],
        [Dict("query"=>r["query"],"flags"=>r["decoherence_flags"]) for r in questioning_results]
    )
    coherent_count = count(r -> isempty(r["flags"]), all_responses)
    total_count = length(all_responses)

    results["summary"] = Dict(
        "arithmetic_pass_rate" => "$arith_pass/$arith_total",
        "coherence_rate" => "$coherent_count/$total_count",
        "baseline_alive" => n0,
        "final_alive" => n_final,
        "node_delta" => n_final - n0
    )

    # Write JSON results

try
        open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_JSON_PATH, "w") do f
        JSON.print(f, results, 2)
    end
    println("\n" * "=" ^ 60)
    println("COMPREHENSIVE TEST v82 COMPLETE")
    println("  Arithmetic: $arith_pass/$arith_total passed")
    println("  Coherence: $coherent_count/$total_count clean")
    println("  Nodes: $n0 → $n_final (delta=$(n_final - n0))")
    println("  Results: $LOG_JSON_PATH")
    println("=" ^ 60)

    # Save post-test specimen
    try
        mkpath(joinpath(@__DIR__, "specimens"))
        save_specimen_to_file!(SPEC_SAVE_PATH)
        println("  Post-test specimen: $SPEC_SAVE_PATH")
    catch e
        println("  Save failed: $e")
    end
end

main()
