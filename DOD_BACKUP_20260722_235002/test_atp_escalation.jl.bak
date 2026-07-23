# test/test_atp_escalation.jl
# v7.23 — exercise the ATP→automaton escalation hook.

using Test
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
using Random

module _ATPEscalationTestParent
    include(joinpath(@__DIR__, "..", "src", "stochastichelper.jl"))
    using .CoinFlipHeader
    include(joinpath(@__DIR__, "..", "src", "RelationalJitter.jl"))
    using .RelationalJitter
    include(joinpath(@__DIR__, "..", "src", "ActionTonePredictor.jl"))
    using .ActionTonePredictor
    include(joinpath(@__DIR__, "..", "src", "EphemeralAutomaton.jl"))
    using .EphemeralAutomaton
end

using ._ATPEscalationTestParent: ActionTonePredictor, EphemeralAutomaton
using ._ATPEscalationTestParent.ActionTonePredictor: ACTION_QUERY, ACTION_SPECULATE,
    ACTION_ASSERT, ACTION_COMMAND, ACTION_NEGATE, ACTION_ESCALATE,
    PredictionResult, maybe_escalate, ESCALATION_FAMILIES, LAST_ESCALATION_TRACE
using ._ATPEscalationTestParent.EphemeralAutomaton: AutomatonRule, AutomatonStep,
    register_automaton_rule!, unregister_automaton_rule!, clear_automaton_rules!,
    run_for_action_family

@testset "ATP Escalation — ESCALATION_FAMILIES contains expected families" begin
    @test :ACTION_QUERY in ESCALATION_FAMILIES
    @test :ACTION_SPECULATE in ESCALATION_FAMILIES
    # GRUG: These should NOT be escalation families — they're simple reactions.
    @test :ACTION_ASSERT ∉ ESCALATION_FAMILIES
    @test :ACTION_COMMAND ∉ ESCALATION_FAMILIES
    @test :ACTION_NEGATE ∉ ESCALATION_FAMILIES
    @test :ACTION_ESCALATE ∉ ESCALATION_FAMILIES
end

@testset "ATP Escalation — no escalation when no automaton module" begin
    # GRUG: If automaton_module is nothing, maybe_escalate returns nothing.
    pred = PredictionResult(
        ACTION_QUERY, ActionTonePredictor.TONE_CURIOUS,
        0.9, false, nothing, 0.1, 1.2, time(),
        Dict{ActionTonePredictor.ActionFamily, Float64}(),
        Dict{ActionTonePredictor.ToneFamily, Float64}(),
        false, :lexicon, 0.5
    )
    result = maybe_escalate(pred; automaton_module = nothing)
    @test result === nothing
    @test LAST_ESCALATION_TRACE[] === nothing
end

@testset "ATP Escalation — no escalation for non-escalation family" begin
    # GRUG: ACTION_ASSERT is not in ESCALATION_FAMILIES → no escalation.
    pred = PredictionResult(
        ACTION_ASSERT, ActionTonePredictor.TONE_DECLARATIVE,
        0.9, false, nothing, 0.0, 1.0, time(),
        Dict{ActionTonePredictor.ActionFamily, Float64}(),
        Dict{ActionTonePredictor.ToneFamily, Float64}(),
        false, :lexicon, 0.5
    )
    result = maybe_escalate(pred; automaton_module = EphemeralAutomaton)
    @test result === nothing
end

@testset "ATP Escalation — no escalation below confidence floor" begin
    # GRUG: Low confidence → no escalation even for escalation family.
    pred = PredictionResult(
        ACTION_QUERY, ActionTonePredictor.TONE_CURIOUS,
        0.3, false, nothing, 0.1, 1.2, time(),
        Dict{ActionTonePredictor.ActionFamily, Float64}(),
        Dict{ActionTonePredictor.ToneFamily, Float64}(),
        false, :lexicon, 0.5
    )
    result = maybe_escalate(pred; automaton_module = EphemeralAutomaton)
    @test result === nothing
end

@testset "ATP Escalation — fires when family matches and confidence high" begin
    # GRUG: Register a rule for ACTION_QUERY, then escalate.
    clear_automaton_rules!()
    rule = AutomatonRule(
        "test_query_escalation",
        :ACTION_QUERY,
        [AutomatonStep("start", :literal, 0.0), AutomatonStep("double", :double, nothing)];
        min_confidence = 0.5
    )
    register_automaton_rule!(rule)

    pred = PredictionResult(
        ACTION_QUERY, ActionTonePredictor.TONE_CURIOUS,
        0.8, false, nothing, 0.1, 1.2, time(),
        Dict{ActionTonePredictor.ActionFamily, Float64}(),
        Dict{ActionTonePredictor.ToneFamily, Float64}(),
        false, :lexicon, 0.5
    )
    result = maybe_escalate(pred; automaton_module = EphemeralAutomaton)
    @test result !== nothing
    @test result.rule_id == "test_query_escalation"
    @test LAST_ESCALATION_TRACE[] !== nothing
    @test LAST_ESCALATION_TRACE[].rule_id == "test_query_escalation"

    # GRUG: Clean up.
    unregister_automaton_rule!("test_query_escalation")
    clear_automaton_rules!()
end

@testset "ATP Escalation — no matching rule → no escalation" begin
    clear_automaton_rules!()
    # GRUG: No rules registered. Even with ACTION_QUERY + high confidence,
    # no rule to match → returns nothing.
    pred = PredictionResult(
        ACTION_QUERY, ActionTonePredictor.TONE_CURIOUS,
        0.9, false, nothing, 0.1, 1.2, time(),
        Dict{ActionTonePredictor.ActionFamily, Float64}(),
        Dict{ActionTonePredictor.ToneFamily, Float64}(),
        false, :lexicon, 0.5
    )
    result = maybe_escalate(pred; automaton_module = EphemeralAutomaton)
    @test result === nothing
    @test LAST_ESCALATION_TRACE[] === nothing
end
