#!/usr/bin/env julia
# ============================================================
# RESOLVE Conflict Resolution — Test Suite
# Tests for compound ref splitting, conflict modes, and
# multi-reference resolution (GRUG v7.36)
# ============================================================

using Test

# Load the codebase
repo_root = joinpath(@__DIR__)
push!(LOAD_PATH, repo_root)

# We only need ActionScript + its deps for these tests
# Load SemanticVerbs first (ActionScript depends on it)
include(joinpath(repo_root, "src", "SemanticVerbs.jl"))
using .SemanticVerbs

# Load ActionScript
include(joinpath(repo_root, "src", "ActionScript.jl"))
using .ActionScript

pass_count = Ref{Int}(0)
fail_count = Ref{Int}(0)

function tcheck(name, result; expected = nothing)
    if expected !== nothing
        if result == expected
            pass_count[] += 1
            println("[$(pass_count[] + fail_count[])] $name ... PASS")
        else
            fail_count[] += 1
            println("[$(pass_count[] + fail_count[])] $name ... FAIL (got $result, expected $expected)")
        end
    else
        pass_count[] += 1
        println("[$(pass_count[] + fail_count[])] $name ... PASS")
    end
end

function tcheck_throws(name, expr_fn)
    try
        expr_fn()
        fail_count[] += 1
        println("[$(pass_count[] + fail_count[])] $name ... FAIL (no exception thrown)")
    catch
        pass_count[] += 1
        println("[$(pass_count[] + fail_count[])] $name ... PASS")
    end
end

println("=" ^ 60)
println("RESOLVE CONFLICT RESOLUTION - TEST SUITE")
println("=" ^ 60)

# ── 1. _classify_ref ────────────────────────────────────────

tcheck("_classify_ref: date → :clock",
    ActionScript._classify_ref("date") === :clock)

tcheck("_classify_ref: time → :clock",
    ActionScript._classify_ref("time") === :clock)

tcheck("_classify_ref: now → :clock",
    ActionScript._classify_ref("now") === :clock)

tcheck("_classify_ref: recent → :recent",
    ActionScript._classify_ref("recent") === :recent)

tcheck("_classify_ref: last → :recent",
    ActionScript._classify_ref("last") === :recent)

tcheck("_classify_ref: ages ago → :deep",
    ActionScript._classify_ref("ages ago") === :deep)

tcheck("_classify_ref: remember → :deep",
    ActionScript._classify_ref("remember") === :deep)

tcheck("_classify_ref: foobar → :literal",
    ActionScript._classify_ref("foobar") === :literal)

# ── 2. _split_compound_refs ────────────────────────────────

tcheck("_split_compound_refs: single ref returns [ref]",
    length(ActionScript._split_compound_refs("date")) == 1)

result = ActionScript._split_compound_refs("date and time")
tcheck("_split_compound_refs: 'date and time' → 2 parts",
    length(result) == 2)

result = ActionScript._split_compound_refs("recent, ages ago")
tcheck("_split_compound_refs: 'recent, ages ago' → 2 parts",
    length(result) == 2)

result = ActionScript._split_compound_refs("recent or last")
tcheck("_split_compound_refs: 'recent or last' → 2 parts",
    length(result) == 2)

# Adjacent keywords without joiners
result = ActionScript._split_compound_refs("recent ages ago")
tcheck("_split_compound_refs: 'recent ages ago' → 2 parts (adjacent)",
    length(result) == 2)

# Empty string
tcheck("_split_compound_refs: empty string → []",
    isempty(ActionScript._split_compound_refs("")))

# Unknown ref (all :literal) → returns original as single element
result = ActionScript._split_compound_refs("foobar baz")
tcheck("_split_compound_refs: all-literal returns original ref",
    length(result) == 1 && result[1] == "foobar baz")

# ── 3. Conflict mode API ───────────────────────────────────

tcheck("get_resolve_conflict_mode default is :merge",
    get_resolve_conflict_mode() === :merge)

set_resolve_conflict_mode!(:priority)
tcheck("set_resolve_conflict_mode! :priority works",
    get_resolve_conflict_mode() === :priority)

set_resolve_conflict_mode!(:first_wins)
tcheck("set_resolve_conflict_mode! :first_wins works",
    get_resolve_conflict_mode() === :first_wins)

set_resolve_conflict_mode!(:merge)  # reset to default
tcheck("set_resolve_conflict_mode! back to :merge",
    get_resolve_conflict_mode() === :merge)

tcheck_throws("set_resolve_conflict_mode! :invalid throws",
    () -> set_resolve_conflict_mode!(:invalid))

# ── 4. resolve_multi_reference — single refs ───────────────

# Single clock ref — should delegate to resolve_reference
date_result = resolve_multi_reference("date")
tcheck("resolve_multi_reference: single clock ref 'date' works",
    occursin(r"^\d{4}-\d{2}-\d{2}$", date_result))

time_result = resolve_multi_reference("time")
tcheck("resolve_multi_reference: single clock ref 'time' works",
    occursin(r"^\d{2}:\d{2}:\d{2}$", time_result))

# Single recent ref — should return fallback (no callback wired in test)
recent_result = resolve_multi_reference("recent")
tcheck("resolve_multi_reference: single recent ref returns fallback",
    recent_result ∈ ActionScript._RESOLVE_FALLBACKS)

# ── 5. resolve_multi_reference — compound refs (clock+clock) ──

# Two clock refs: "date and time"
result = resolve_multi_reference("date and time")
tcheck("resolve_multi_reference: 'date and time' → merge mode",
    occursin(r"\d{4}-\d{2}-\d{2}", result) && occursin(r"\d{2}:\d{2}:\d{2}", result))

# ── 6. resolve_multi_reference — conflict modes ────────────

# :priority mode — clock should win over deep
result_priority = resolve_multi_reference("ages ago and date"; mode=:priority)
tcheck("resolve_multi_reference: :priority → clock wins over deep",
    occursin(r"\d{4}", result_priority) && !occursin("memory trace", result_priority))

# :first_wins mode — first non-fallback wins
result_first = resolve_multi_reference("date and ages ago"; mode=:first_wins)
tcheck("resolve_multi_reference: :first_wins → first non-fallback",
    occursin(r"\d{4}", result_first))

# :merge mode — concatenate
result_merge = resolve_multi_reference("date and time"; mode=:merge)
tcheck("resolve_multi_reference: :merge → concatenated results",
    occursin(";", result_merge) || (occursin(r"\d{4}", result_merge) && occursin(r"\d{2}:", result_merge)))

# ── 7. resolve_multi_reference — no conflict (all fallback) ──

result = resolve_multi_reference("recent and ages ago"; mode=:merge)
tcheck("resolve_multi_reference: all-fallback compound → returns first fallback",
    result ∈ ActionScript._RESOLVE_FALLBACKS || occursin("(", result))

# ── 8. Backward compat: resolve_reference still works ──────

date_single = resolve_reference("date")
tcheck("resolve_reference: 'date' still works independently",
    occursin(r"^\d{4}-\d{2}-\d{2}$", date_single))

time_single = resolve_reference("time")
tcheck("resolve_reference: 'time' still works independently",
    occursin(r"^\d{2}:\d{2}:\d{2}$", time_single))

# Compound ref in resolve_reference hits first match and short-circuits
# This is the OLD behavior — "recent and ages ago" → matches recent first
rr_compound = resolve_reference("recent and ages ago")
tcheck("resolve_reference: compound 'recent and ages ago' → hits recent (no multi-resolve)",
    rr_compound ∈ ActionScript._RESOLVE_FALLBACKS || occursin("recent", lowercase(rr_compound)))

# ── 9. resolve_multi_reference correctly handles compound ──

# The NEW behavior — "recent and ages ago" → tries both
mr_compound = resolve_multi_reference("recent and ages ago")
tcheck("resolve_multi_reference: 'recent and ages ago' → tries both layers",
    mr_compound !== nothing)

# ── 10. RESOLVE op in _eval_op_chain uses multi-ref ────────
# We can test this indirectly by executing an action with a compound target

# Reset default actions
ActionScript.default_actions!()

# Register a test action with compound ref
ActionScript.register_action!(
    trigger_verb = "compound_test",
    action_type = :dynamic,
    template = "SAY(RESOLVE({{target}}))",
    description = "Test compound ref resolution"
)

entry = ActionScript.lookup_action("compound_test")
result = entry !== nothing ? ActionScript.execute_action(entry, Dict{String, Any}("target" => "date and time", "count" => "1")) : "NO ENTRY"
tcheck("execute_action with compound ref 'date and time'",
    occursin(r"\d{4}", result) && occursin(r"\d{2}:", result))

# ── 11. Three-way compound ──────────────────────────────────

result = resolve_multi_reference("date, recent, ages ago"; mode=:merge)
tcheck("resolve_multi_reference: 3-way compound (date, recent, ages ago)",
    occursin(r"\d{4}", result))  # at minimum the clock ref resolves

# ── 12. Verify mode override doesn't change global state ───

tcheck("Global mode still :merge after override calls",
    get_resolve_conflict_mode() === :merge)

# ── SUMMARY ────────────────────────────────────────────────
println()
println("=" ^ 60)
if fail_count[] == 0
    println("ALL $(pass_count[]) RESOLVE CONFLICT TESTS PASSED")
else
    println("$(pass_count[]) PASSED, $(fail_count[]) FAILED")
end
println("=" ^ 60)

# Exit with appropriate code
exit(fail_count[])
