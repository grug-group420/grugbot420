#!/usr/bin/env julia
# test_v9_math_routing.jl — Test math question routing and compound question handling
# Verifies that the RoutingJudge correctly classifies arithmetic and compound questions
# and that Main.jl's conversation handler processes them correctly.

using Dates, JSON, Base.Threads
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, _conversation_prescan,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK

import .GrugBot420.RoutingJudge:
    collect_intents, resolve, IntentCandidate, SubIntent,
    _has_arithmetic_tokens, _has_math_bindings_in_topic,
    _split_compound_question, _classify_sub_text,
    CONSERVATIVE_BIAS

import .GrugBot420.ArithmeticEngine:
    has_math_bindings, compute_arithmetic, format_arithmetic_reply

import .GrugBot420.SigilPromoter:
    promote_input, SigilBinding

# ── Helpers ──────────────────────────────────────────────────────────────────

const _log_path = joinpath(@__DIR__, "test_v9_math_routing.log.md")
open(_log_path, "w") do f
    write(f, "# V9 Math Routing Test Log\n\n")
    write(f, "_Generated: $(now())_\n\n")
end

_total = 0
_passed = 0
_failed = 0

function log_md(msg::String)
    open(_log_path, "a") do f
        write(f, msg * "\n")
    end
end

function record(name::String, ok::Bool, detail::String="")
    global _total, _passed, _failed
    _total += 1
    if ok
        _passed += 1
    else
        _failed += 1
    end
    status = ok ? "✅" : "❌"
    msg = "- $status **$name**" * (isempty(detail) ? "" : " — $detail")
    println(msg)
    log_md(msg)
    return ok
end

function summary()::Bool
    log_md("\n---\n\n**Total:** $_total  **Passed:** $_passed  **Failed:** $_failed\n")
    println("\n" * "="^60)
    println("Math Routing Test: $_passed/$_total passed")
    println("="^60)
    return _failed == 0
end

# ── Section 1: Token-level arithmetic detection ──────────────────────────────
log_md("## 1. Token-level arithmetic detection\n")

begin
    ok = _has_arithmetic_tokens("5+5")
    record("5+5 detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("3 - 2")
    record("3 - 2 detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("12/4")
    record("12/4 detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("7*8")
    record("7*8 detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("five plus three")
    record("five plus three detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("two minus one")
    record("two minus one detected as arithmetic", ok)
end

begin
    ok = _has_arithmetic_tokens("3 times 7")
    record("3 times 7 detected as arithmetic", ok)
end

begin
    ok = !_has_arithmetic_tokens("love")
    record("love NOT detected as arithmetic", ok)
end

begin
    ok = !_has_arithmetic_tokens("what is the meaning of life")
    record("meaning of life NOT detected as arithmetic", ok)
end

begin
    ok = !_has_arithmetic_tokens("fire")
    record("fire NOT detected as arithmetic", ok)
end

# ── Section 2: RoutingJudge intent classification ────────────────────────────
log_md("\n## 2. RoutingJudge intent classification\n")

begin
    candidates = collect_intents("what is 5+5")
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"what is 5+5\" → :calculate", has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    candidates = collect_intents("what is 5 plus 5")
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"what is 5 plus 5\" → :calculate", has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    candidates = collect_intents("what is love")
    has_q = any(c -> c.kind === :question, candidates)
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"what is love\" → :question (not :calculate)", has_q && !has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    candidates = collect_intents("what is 12 - 4")
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"what is 12 - 4\" → :calculate", has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    candidates = collect_intents("what is fire")
    has_q = any(c -> c.kind === :question, candidates)
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"what is fire\" → :question (not :calculate)", has_q && !has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    # "sum is 5+5" — X-is-Y where definition side is arithmetic
    candidates = collect_intents("sum is 5+5")
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"sum is 5+5\" → :calculate (arithmetic definition)", has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

# ── Section 3: RoutingJudge resolve ──────────────────────────────────────────
log_md("\n## 3. RoutingJudge resolve (pick winner)\n")

begin
    candidates = collect_intents("what is 5+5")
    result = resolve(candidates; verbose=false)
    ok = result !== nothing && first(result) === :calculate
    record("resolve \"what is 5+5\" → (:calculate, ...)", ok,
           result !== nothing ? "result=$result" : "result=nothing")
end

begin
    candidates = collect_intents("what is love")
    result = resolve(candidates; verbose=false)
    ok = result !== nothing && first(result) === :question
    record("resolve \"what is love\" → (:question, ...)", ok,
           result !== nothing ? "result=$result" : "result=nothing")
end

begin
    candidates = collect_intents("what is 3 plus 4")
    result = resolve(candidates; verbose=false)
    ok = result !== nothing && first(result) === :calculate
    record("resolve \"what is 3 plus 4\" → (:calculate, ...)", ok,
           result !== nothing ? "result=$result" : "result=nothing")
end

# ── Section 4: Compound question splitting ───────────────────────────────────
log_md("\n## 4. Compound question splitting\n")

begin
    subs = _split_compound_question("what is 5+5 and what is love")
    n = length(subs)
    has_calc_sub = any(s -> s.kind === :calculate, subs)
    has_q_sub = any(s -> s.kind === :question, subs)
    record("\"what is 5+5 and what is love\" splits into 2 sub-intents", n >= 2,
           "n=$n, kinds=$(join(string.(s.kind for s in subs), ","))")
    record("  First sub-intent is :calculate", has_calc_sub)
    record("  Second sub-intent is :question", has_q_sub)
end

begin
    subs = _split_compound_question("12 - 4 and why is grass green")
    n = length(subs)
    record("\"12 - 4 and why is grass green\" splits into 2 sub-intents", n >= 2,
           "n=$n, kinds=$(join(string.(s.kind for s in subs), ","))")
end

begin
    # NOT compound — "5 and 3" inside arithmetic context
    subs = _split_compound_question("add 5 and 3")
    n = length(subs)
    # Should NOT split — "and" connects arithmetic operands
    record("\"add 5 and 3\" does NOT split (arithmetic context)", n <= 1,
           "n=$n")
end

begin
    # NOT compound — single question
    subs = _split_compound_question("what is love")
    n = length(subs)
    record("\"what is love\" does NOT split (single question)", n <= 1,
           "n=$n, kinds=$(join(string.(s.kind for s in subs), ","))")
end

# ── Section 5: Sub-text classification ───────────────────────────────────────
log_md("\n## 5. Sub-text classification\n")

begin
    kind, topic, def, hint = _classify_sub_text("what is 5+5")
    record("_classify_sub_text \"what is 5+5\" → :calculate", kind === :calculate,
           "kind=$kind, topic=$topic")
end

begin
    kind, topic, def, hint = _classify_sub_text("what is love")
    record("_classify_sub_text \"what is love\" → :question", kind === :question,
           "kind=$kind, topic=$topic")
end

begin
    kind, topic, def, hint = _classify_sub_text("5+5")
    record("_classify_sub_text \"5+5\" → :calculate", kind === :calculate,
           "kind=$kind, topic=$topic")
end

begin
    kind, topic, def, hint = _classify_sub_text("why is grass green")
    record("_classify_sub_text \"why is grass green\" → :question", kind === :question,
           "kind=$kind, topic=$topic")
end

# ── Section 6: _conversation_prescan integration ────────────────────────────
log_md("\n## 6. _conversation_prescan integration\n")

begin
    result = _conversation_prescan("what is 5+5")
    ok = result !== nothing && first(result) === :calculate
    record("_conversation_prescan \"what is 5+5\" → :calculate", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

begin
    result = _conversation_prescan("what is love")
    ok = result !== nothing && first(result) === :question
    record("_conversation_prescan \"what is love\" → :question", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

begin
    result = _conversation_prescan("what is 5+5 and what is love")
    ok = result !== nothing && first(result) === :compound
    record("_conversation_prescan \"what is 5+5 and what is love\" → :compound", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

begin
    result = _conversation_prescan("what is 3 plus 4")
    ok = result !== nothing && first(result) === :calculate
    record("_conversation_prescan \"what is 3 plus 4\" → :calculate", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

# ── Section 7: End-to-end arithmetic computation via process_mission ─────────
log_md("\n## 7. End-to-end arithmetic via process_mission\n")

begin
    # Define a word first so the bot has something to answer
    # (if "love" is unknown, it'll ask for clarification instead of answering)
    try
        GrugBot420._dict_define_word!("default", "love", "a deep affection")
    catch _
    end

    process_mission("what is 5+5")
    _voice = lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
    # The reply should contain "10" (the computed result)
    has_10 = occursin("10", String(_voice))
    record("process_mission \"what is 5+5\" → answer contains 10", has_10,
           "voice='$_voice'")
end

begin
    process_mission("what is 3 plus 4")
    _voice = lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
    has_7 = occursin("7", String(_voice))
    record("process_mission \"what is 3 plus 4\" → answer contains 7", has_7,
           "voice='$_voice'")
end

begin
    process_mission("what is 12 - 4")
    _voice = lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
    has_8 = occursin("8", String(_voice))
    record("process_mission \"what is 12 - 4\" → answer contains 8", has_8,
           "voice='$_voice'")
end

# ── Section 8: Compound question end-to-end ──────────────────────────────────
log_md("\n## 8. Compound question end-to-end\n")

begin
    process_mission("what is 5+5 and what is love")
    _voice = lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
    # Should contain both "10" and "affection" (or "love")
    has_10 = occursin("10", String(_voice))
    has_love_info = occursin("affection", lowercase(String(_voice))) || occursin("love", lowercase(String(_voice)))
    record("compound \"what is 5+5 and what is love\" → has 10", has_10,
           "voice='$_voice'")
    record("compound \"what is 5+5 and what is love\" → has love info", has_love_info,
           "voice='$_voice'")
end

begin
    process_mission("what is 3 times 2 and why is grass green")
    _voice = lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[]
    end
    has_6 = occursin("6", String(_voice))
    record("compound \"what is 3 times 2 and why is grass green\" → has 6", has_6,
           "voice='$_voice'")
end

# ── Section 9: Edge cases ────────────────────────────────────────────────────
log_md("\n## 9. Edge cases\n")

begin
    # "what is love and happiness" — should NOT split, it's ONE question about a compound topic
    candidates = collect_intents("what is love and happiness")
    # The what-is-X regex should capture "love and happiness" as a single topic
    has_q = any(c -> c.kind === :question, candidates)
    record("\"what is love and happiness\" → :question (single topic)", has_q,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    # Pure arithmetic expression without "what is"
    candidates = collect_intents("5+5")
    has_calc = any(c -> c.kind === :calculate, candidates)
    record("\"5+5\" → :calculate", has_calc,
           "kinds=$(join(string.(c.kind for c in candidates), ","))")
end

begin
    # Definition with arithmetic: "sum is 5+5"
    result = _conversation_prescan("sum is 5+5")
    ok = result !== nothing && first(result) === :calculate
    record("\"sum is 5+5\" → :calculate via prescan", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

begin
    # Normal definition should still work: "fire is oxidation and heat"
    result = _conversation_prescan("fire is oxidation and heat")
    ok = result !== nothing && first(result) === :define
    record("\"fire is oxidation and heat\" → :define (not :calculate)", ok,
           result !== nothing ? "kind=$(first(result))" : "nothing")
end

# ── Summary ──────────────────────────────────────────────────────────────────
log_md("\n---\n\n**Total:** $_total  **Passed:** $_passed  **Failed:** $_failed\n")
println("\n" * "="^60)
println("Math Routing Test: $_passed/$_total passed")
println("Log: $_log_path")
println("="^60)
exit(_failed == 0 ? 0 : 1)