# test/test_ephemeral_automaton.jl
# v7.23 — JIT, ephemeral, ATP-callable step machine.
#
# GRUG: Like sibling tests, this loads source modules directly inside a
# private parent module so we don't pay the package-precompile dance and
# we don't fight with Julia's caching across the runtests subprocess fleet.

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

module _AutomatonTestParent
    include(joinpath(@__DIR__, "..", "src", "RelationalJitter.jl"))
    include(joinpath(@__DIR__, "..", "src", "EphemeralAutomaton.jl"))
    using .RelationalJitter
    using .EphemeralAutomaton
end

using ._AutomatonTestParent.EphemeralAutomaton
using ._AutomatonTestParent.RelationalJitter

@testset "EphemeralAutomaton — registry add/remove/list" begin
    clear_automaton_rules!()
    @test isempty(list_automaton_rules())

    rule = AutomatonRule("triple_then_add", :reason,
        [AutomatonStep("seed",   :literal, 3.0),
         AutomatonStep("triple", :mul,     3.0),
         AutomatonStep("offset", :add,     1.0)])
    register_automaton_rule!(rule)

    @test length(list_automaton_rules()) == 1
    @test lookup_automaton_rule("triple_then_add") === rule

    # Double-register must throw.
    @test_throws AutomatonRuleError register_automaton_rule!(rule)

    @test unregister_automaton_rule!("triple_then_add") == true
    @test unregister_automaton_rule!("triple_then_add") == false  # idempotent miss

    clear_automaton_rules!()
end

@testset "EphemeralAutomaton — deterministic run, no jitter" begin
    clear_automaton_rules!()
    rule = AutomatonRule("doubler", :compute,
        [AutomatonStep("seed",  :literal, 4.0),
         AutomatonStep("dbl",   :double,  nothing),
         AutomatonStep("plus1", :add,     1.0)];
        min_confidence = 0.5)
    register_automaton_rule!(rule)

    trace = run_for_action_family(:compute, 0.9)
    @test trace !== nothing
    @test trace.sequence == ["seed", "dbl", "plus1"]
    @test trace.values["seed"]  == 4.0
    @test trace.values["dbl"]   == 8.0
    @test trace.values["plus1"] == 9.0
    @test isempty(trace.jittered)

    clear_automaton_rules!()
end

@testset "EphemeralAutomaton — jitter snap-back on tagged steps only" begin
    clear_automaton_rules!()
    rule = AutomatonRule("noisy", :reason,
        [AutomatonStep("seed",   :literal, 100.0),
         AutomatonStep("scale",  :mul,     1.0)];
        jitter_targets = Set(["scale"]))
    register_automaton_rule!(rule)

    set_jitter_ratio!(0.05)
    enable_jitter!()
    try
        seeds  = Float64[]
        scales = Float64[]
        for _ in 1:200
            t = run_for_action_family(:reason, 0.9)
            push!(seeds, t.values["seed"])
            push!(scales, t.values["scale"])
        end
        @test all(s == 100.0 for s in seeds)
        @test all(abs(s - 100.0) <= 5.0 + 1e-9 for s in scales)
        @test maximum(abs.(scales .- 100.0)) > 0.0
        @test abs(sum(scales)/length(scales) - 100.0) < 1.0
    finally
        set_jitter_ratio!(0.03)
        clear_automaton_rules!()
    end
end

@testset "EphemeralAutomaton — userfn op + ctx" begin
    clear_automaton_rules!()
    f = (accum, ctx) -> begin
        ctx["seen"] = get(ctx, "seen", 0) + 1
        return accum + 10.0
    end
    rule = AutomatonRule("with_userfn", :plan,
        [AutomatonStep("seed",  :literal, 0.0),
         AutomatonStep("user",  :userfn,  f)])
    register_automaton_rule!(rule)
    ctx = Dict{String,Any}()
    t = run_automaton(rule; ctx = ctx)
    @test t.values["user"] == 10.0
    @test ctx["seen"] == 1
    clear_automaton_rules!()
end

@testset "EphemeralAutomaton — escalation gating by min_confidence" begin
    clear_automaton_rules!()
    rule = AutomatonRule("gated", :reason,
        [AutomatonStep("seed", :literal, 1.0)];
        min_confidence = 0.8)
    register_automaton_rule!(rule)
    @test run_for_action_family(:reason, 0.7) === nothing
    @test run_for_action_family(:reason, 0.9) !== nothing
    @test run_for_action_family(:greet,  0.9) === nothing
    clear_automaton_rules!()
end

@testset "EphemeralAutomaton — divide-by-zero loud" begin
    rule = AutomatonRule("dz", :compute,
        [AutomatonStep("seed", :literal, 1.0),
         AutomatonStep("bad",  :div,     0.0)])
    @test_throws AutomatonError run_automaton(rule)
end

@testset "EphemeralAutomaton — duplicate label loud" begin
    rule = AutomatonRule("dup", :compute,
        [AutomatonStep("a", :literal, 1.0),
         AutomatonStep("a", :add,     2.0)])
    @test_throws AutomatonError run_automaton(rule)
end
