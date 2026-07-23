#!/usr/bin/env julia
# ==============================================================================
# comprehensive_test.jl — Full GrugBot420 specimen test suite
# ==============================================================================
# Tests: greetings, multipart questions, math, relational triples with sigils,
#        coherence, reasoning chains, cross-topic queries
# ==============================================================================

using Dates
using JSON

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK

const SPEC_PATH = get(ARGS, 1, "/workspace/test.specimen")

function read_last_output()::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end
end

function run_mission(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try
        process_mission(text)
    catch e
        @warn "process_mission error" exception=e
    end
    return read_last_output()
end

function clean_output(raw::String)::String
    # Strip debug telemetry if present
    ti = findfirst("--- DEBUG TELEMETRY", raw)
    if ti !== nothing
        raw = strip(raw[1:first(ti)-1])
    end
    # Strip command echoes like "> hello"
    lines = split(raw, '\n')
    filtered = filter(l -> !startswith(strip(l), "> "), lines)
    return strip(join(filtered, '\n'))
end

const FAILURE_PHRASES = [
    "Nothing in the cave",
    "nothing in the cave",
    "cave is empty",
    "Grug shrugs",
    "grug shrugs",
    "no match found",
]

function is_failure_response(answer::String)::Bool
    for phrase in FAILURE_PHRASES
        occursin(phrase, answer) && return true
    end
    return false
end

function run_test(category::String, query::String)
    raw = run_mission(query)
    answer = clean_output(raw)
    if isempty(answer)
        status = "❌ EMPTY"
    elseif is_failure_response(answer)
        status = "❌ CAVE-EMPTY"
    elseif length(answer) < 5
        status = "⚠️ SHORT"
    else
        status = "✅"
    end
    println("[$status] $category: \"$query\"")
    # Truncate long answers for display
    display_answer = length(answer) > 200 ? first(answer, 200) * "…" : answer
    println("  → $display_answer")
    println()
    return (category, query, answer, status)
end

# ── Load specimen ──────────────────────────────────────────────────────
println("=" ^ 70)
println("GRUGBOT420 COMPREHENSIVE SPECIMEN TEST")
println("=" ^ 70)
println("Specimen: $SPEC_PATH")
println("Time: $(now())")
println()

println("Loading specimen...")
try
    load_specimen_from_file!(SPEC_PATH)
    n_nodes = length(lock(() -> collect(keys(NODE_MAP)), NODE_LOCK))
    println("✅ Loaded! $n_nodes nodes in memory")
catch e
    println("❌ LOAD FAILED: $e")
    exit(1)
end
println()

results = []

# ═══════════════════════════════════════════════════════════════════════
# SECTION 1: GREETINGS
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 1: GREETINGS")
println("─" ^ 70)
println()

push!(results, run_test("greeting", "hello"))
push!(results, run_test("greeting", "hi"))
push!(results, run_test("greeting", "hey"))
push!(results, run_test("greeting", "howdy"))
push!(results, run_test("greeting", "goodbye"))
push!(results, run_test("greeting", "morning"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 2: SIMPLE FACTUAL
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 2: SIMPLE FACTUAL")
println("─" ^ 70)
println()

push!(results, run_test("factual", "what is fire"))
push!(results, run_test("factual", "why is the sky blue"))
push!(results, run_test("factual", "what is photosynthesis"))
push!(results, run_test("factual", "what is mathematics"))
push!(results, run_test("factual", "what is language"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 3: MATH — ARITHMETIC (SIGIL RELATIONAL TRIPLES)
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 3: MATH — ARITHMETIC (SIGIL RELATIONAL TRIPLES)")
println("─" ^ 70)
println()

push!(results, run_test("math", "what is 2 plus 3"))
push!(results, run_test("math", "what is 10 minus 4"))
push!(results, run_test("math", "what is 5 times 6"))
push!(results, run_test("math", "what is 20 divided by 5"))
push!(results, run_test("math", "what is 7 plus 8"))
push!(results, run_test("math", "what is 3 times 4"))
push!(results, run_test("math", "calculate 15 minus 9"))
push!(results, run_test("math", "add 12 and 7"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 4: MATH — SIGIL NODES (DYNAMIC COMPUTATION)
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 4: MATH — SIGIL NODES (DYNAMIC COMPUTATION)")
println("─" ^ 70)
println()

push!(results, run_test("math-sigil", "what is the square of 7"))
push!(results, run_test("math-sigil", "what is the cube of 3"))
push!(results, run_test("math-sigil", "what is the factorial of 5"))
push!(results, run_test("math-sigil", "double 8"))
push!(results, run_test("math-sigil", "half of 20"))
push!(results, run_test("math-sigil", "square root of 49"))
push!(results, run_test("math-sigil", "absolute value of -12"))
push!(results, run_test("math-sigil", "reciprocal of 4"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 5: MULTIPART QUESTIONS
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 5: MULTIPART QUESTIONS")
println("─" ^ 70)
println()

push!(results, run_test("multipart", "what is fire and why is the sky blue"))
push!(results, run_test("multipart", "tell me about photosynthesis and evaporation"))
push!(results, run_test("multipart", "how does fire relate to chemistry and what is combustion"))
push!(results, run_test("multipart", "what is math and what is language"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 6: RELATIONAL TRIPLES WITH SIGILS
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 6: RELATIONAL TRIPLES WITH SIGILS")
println("─" ^ 70)
println()

# These test &causal, &being, &temporal, &spatial relation sigils
push!(results, run_test("rel-sigil", "what causes fire to burn"))
push!(results, run_test("rel-sigil", "what is combustion"))
push!(results, run_test("rel-sigil", "what comes before rain"))
push!(results, run_test("rel-sigil", "what is above the ground"))
push!(results, run_test("rel-sigil", "what enables photosynthesis"))
push!(results, run_test("rel-sigil", "what produces oxygen"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 7: REASONING / EXPLANATION
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 7: REASONING / EXPLANATION")
println("─" ^ 70)
println()

push!(results, run_test("reason", "why does water evaporate"))
push!(results, run_test("reason", "how do plants grow"))
push!(results, run_test("reason", "explain what biology studies"))
push!(results, run_test("reason", "why do rivers flow"))
push!(results, run_test("reason", "how does soil form"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 8: EMOTION / EMPATHY
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 8: EMOTION / EMPATHY")
println("─" ^ 70)
println()

push!(results, run_test("emotion", "I feel frustrated"))
push!(results, run_test("emotion", "I am happy today"))
push!(results, run_test("emotion", "I am scared of the dark"))
push!(results, run_test("emotion", "I feel lonely"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 9: PHILOSOPHY / METACOGNITION
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 9: PHILOSOPHY / METACOGNITION")
println("─" ^ 70)
println()

push!(results, run_test("philosophy", "what is knowledge"))
push!(results, run_test("philosophy", "do we have free will"))
push!(results, run_test("philosophy", "what is beauty"))
push!(results, run_test("metacognition", "how do you think"))
push!(results, run_test("metacognition", "what are you"))

# ═══════════════════════════════════════════════════════════════════════
# SECTION 10: CROSS-TOPIC / COMPOUND
# ═══════════════════════════════════════════════════════════════════════
println("─" ^ 70)
println("SECTION 10: CROSS-TOPIC / COMPOUND")
println("─" ^ 70)
println()

push!(results, run_test("cross-topic", "is math related to language"))
push!(results, run_test("cross-topic", "how does technology affect nature"))
push!(results, run_test("cross-topic", "what connects fire and life"))
push!(results, run_test("cross-topic", "can philosophy help with emotions"))

# ═══════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════
println()
println("=" ^ 70)
println("TEST SUMMARY")
println("=" ^ 70)

pass_count = count(r -> r[4] == "✅", results)
warn_count = count(r -> startswith(r[4], "⚠️"), results)
fail_count = count(r -> startswith(r[4], "❌"), results)
total = length(results)

println("Total: $total | ✅ Pass: $pass_count | ⚠️ Warn: $warn_count | ❌ Fail: $fail_count")
println()

# Print failures for review
failures = filter(r -> r[4] != "✅", results)
if !isempty(failures)
    println("ITEMS NEEDING ATTENTION:")
    for (cat, q, a, st) in failures
        println("  $st [$cat] \"$q\" → $(length(a)) chars")
    end
end

# Math coherence spot-check: verify key arithmetic answers
println()
println("MATH COHERENCE SPOT-CHECK:")
math_checks = [
    ("what is 2 plus 3", "5", "+"),
    ("what is 10 minus 4", "6", "-"),
    ("what is 5 times 6", "30", "*"),
    ("what is 20 divided by 5", "4", "/"),
    ("add 12 and 7", "19", "+"),
    ("half of 20", "10", "half"),
    ("what is the square of 7", "49", "sq"),
    ("what is the factorial of 5", "120", "!"),
    ("reciprocal of 4", "0.25", "1/"),
]
for (q, expected, op) in math_checks
    idx = findfirst(r -> r[2] == q, results)
    if idx === nothing
        println("  ⚠️ NOT TESTED: \"$q\"")
        continue
    end
    answer = results[idx][3]
    if occursin(expected, answer)
        println("  ✅ \"$q\" → contains \"$expected\"")
    else
        println("  ❌ \"$q\" → expected \"$expected\", got: $(first(answer, 100))")
    end
end

println()
println("Done at $(now())")
