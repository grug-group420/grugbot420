#!/usr/bin/env julia --project=.
# test_comprehensive_v81.jl — Full growth & learning systems test
# Uses same include pattern as working test_arithmetic_fix.jl
using Pkg; Pkg.instantiate()
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
using Dates

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    add_message_to_history!, cast_vote, create_node,
    get_node_status_summary, get_bridge_summary,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    NODE_MAP, NODE_LOCK,
    maybe_run_idle, save_specimen_to_file!

const LOG_PATH = joinpath(@__DIR__, "test_log_v81.md")
const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

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

function run_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]=""; end
    t = @elapsed begin; try; process_mission(text); catch e; @warn "err: $e"; end; end
    resp = read_last_output()
    return (resp, t)
end

function main()
    println("Loading specimen...")
    result = load_specimen_from_file!(SPEC_PATH)
    println("Load result: $result")
    n0 = alive_count()
    println("Alive nodes: $n0")

    io = IOBuffer()

    # 1. Arithmetic
    println(io, "## 1. Arithmetic Engine")
    for (c, exp) in [("what is 2+2","4"),("what is 3 plus 4","7"),("what is 10 minus 3","7"),("what is 5 times 6","30")]
        resp, t = run_mission(c)
        found = occursin(exp, resp)
        flags = decoherence_flags(resp)
        println(io, "- `$c` → $exp: $(found ? "✅" : "⚠️") | $(round(t,digits=2))s$(isempty(flags) ? "" : " | flags: $(join(flags,","))")")
    end
    println("  ✓ Arithmetic")

    # 2. AutoGrowth + AutoLinker
    println(io, "\n## 2. AutoGrowth + AutoLinker")
    ag1 = try; GrugBot420.AutoGrowth.get_autogrowth_status_summary(); catch e; "ERR: $e"; end
    al1 = try; GrugBot420.AutoLinker.get_autolink_status_summary(); catch e; "ERR: $e"; end
    println(io, "Before: alive=$n0")
    println(io, "AutoGrowth: $ag1")
    println(io, "AutoLinker: $al1")
    for s in ["tell me about quantum physics","what is photosynthesis"]
        run_mission(s)
    end
    try; maybe_run_idle(); catch e; end
    n1 = alive_count()
    ag2 = try; GrugBot420.AutoGrowth.get_autogrowth_status_summary(); catch e; "ERR: $e"; end
    al2 = try; GrugBot420.AutoLinker.get_autolink_status_summary(); catch e; "ERR: $e"; end
    println(io, "After: alive=$n1 (delta=$(n1-n0))")
    println(io, "AutoGrowth: $ag2")
    println(io, "AutoLinker: $al2")
    println("  ✓ AutoGrowth/AutoLinker")

    # 3. Hippocampal
    println(io, "\n## 3. Hippocampal Ask/Answer")
    for c in ["what is fire and why does it burn","tell me about water and what is 3 plus 5"]
        resp, t = run_mission(c)
        flags = decoherence_flags(resp)
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println(io, "- `$c`: $flag_str | $(round(t,digits=2))s")
    end
    println("  ✓ Hippocampal")

    # 4. Flashcards
    println(io, "\n## 4. Flashcards (PettyLearner)")
    fc0 = try; GrugBot420.LobeTable.flashcard_count("math"); catch; 0; end
    println(io, "Pre math flashcards: $fc0")
    run_mission("what is 2+2"); run_mission("what is 3 times 4")
    fc1 = try; GrugBot420.LobeTable.flashcard_count("math"); catch; 0; end
    println(io, "Post math flashcards: $fc1 (delta=$(fc1-fc0))")
    ps = try; GrugBot420.PettyLearner.petty_status(); catch e; "ERR: $e"; end
    println(io, "PettyLearner: $ps")
    println("  ✓ Flashcards")

    # 5. Thesaurus
    println(io, "\n## 5. Thesaurus Expansion")
    println(io, "- synonym_lookup(fire,flame): $(try;GrugBot420.Thesaurus.synonym_lookup("fire","flame");catch e;"ERR:$e";end)")
    println(io, "- word_similarity(rock,stone): $(try;GrugBot420.Thesaurus.word_similarity("rock","stone");catch e;"ERR:$e";end)")
    println(io, "- word_similarity(happy,sad): $(try;GrugBot420.Thesaurus.word_similarity("happy","sad");catch e;"ERR:$e";end)")
    println("  ✓ Thesaurus")

    # 6. SemanticVerbs
    println(io, "\n## 6. Language-Side Resource (SemanticVerbs)")
    for v in ["is","causes","contains","belongs to"]
        println(io, "- verb_class_of('$v'): $(try;GrugBot420.SemanticVerbs.verb_class_of(v);catch e;"ERR:$e";end)")
    end
    try; GrugBot420.SemanticVerbs.add_relation_class!("&test_rel_comp"); println(io, "- add_relation_class!: ✅"); catch e; println(io, "- add_relation_class!: ⚠️ $e"); end
    println("  ✓ SemanticVerbs")

    # 7. Mitosis
    println(io, "\n## 7. Mitosis Growth")
    println(io, "```"); println(io, try;GrugBot420.MitosisMode.get_mitosis_status_summary();catch e;"ERR:$e";end); println(io, "```")
    println("  ✓ Mitosis")

    # 8. Phagy
    println(io, "\n## 8. Phagy (Node Cleanup)")
    println(io, "- phagy_log_rotate: $(try;GrugBot420.PhagyMode.phagy_log_rotate!();catch e;"ERR:$e";end)")
    println(io, "- Alive nodes: $(alive_count())")
    println("  ✓ Phagy")

    # 9. Immune
    println(io, "\n## 9. Immune System")
    is_ = try; GrugBot420.ImmuneSystem.get_immune_status(); catch e; Dict("ERR"=>string(e)); end
    for (k,v) in collect(is_); println(io, "- $k: $v"); end
    println("  ✓ Immune")

    # 10. Multipart coherence
    println(io, "\n## 10. Multipart Coherence")
    for c in ["what is 2+2 also what is a cat","what is fire and why does it burn","tell me about water and what is 5 plus 3"]
        resp, t = run_mission(c)
        flags = decoherence_flags(resp)
        conv = resp; ti=findfirst("--- DEBUG TELEMETRY",resp); if ti !== nothing; conv=strip(resp[1:first(ti)-1]); end
        flag_str = isempty(flags) ? "✅" : "⚠️ $(join(flags,","))"
        println(io, "- `$c`: $flag_str | $(round(t,digits=2))s | excerpt: $(first(conv,200))")
    end
    println("  ✓ Multipart coherence")

    # Write log
    n_final = alive_count()
    header = "# GrugBot420 Comprehensive Test Log — v81 Specimen\n_Generated: $(Dates.format(now(), Dates.dateformat"yyyy-mm-dd HH:MM:SS"))_\n\nSpecimen: `$SPEC_PATH`\nBaseline alive: $n0 | Final alive: $n_final | Delta: $(n_final - n0)\n"
    write(LOG_PATH, header * String(take!(io)))
    println("\n════════════════════════════════════════")
    println("COMPREHENSIVE TEST COMPLETE")
    println("  Log: $LOG_PATH")
    println("════════════════════════════════════════")

    # Save post-test specimen
    try; save_specimen_to_file!(joinpath(@__DIR__,"specimens","v81_post_test.json")); catch e; println("Save failed: $e"); end
end

main()
