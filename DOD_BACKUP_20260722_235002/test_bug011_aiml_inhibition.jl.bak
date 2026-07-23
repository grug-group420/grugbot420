# test_bug011_aiml_inhibition.jl
# BUG-011: AIML growth inhibition is orchestration-focused and thesaurus-expanded.

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
using GrugBot420
const ANS = GrugBot420.AIMLNodeSystem

@testset "BUG-011 AIML growth inhibition" begin
    ANS.reset_all!()
    ANS.register_lobe!("aiml_inhibit", 30)

    contributor = ANS.add_aiml_node!("aiml_inhibit", "contrib", "Executive scaffold for: alpha planner route"; initial_strength=5.0)
    fired_only = ANS.add_aiml_node!("aiml_inhibit", "fired_only", "Executive scaffold for: beta distraction"; initial_strength=5.0)

    ANS.begin_cycle!()
    ANS.record_fire!(fired_only)

    @test !ANS.is_aiml_growth_inhibited("aiml_inhibit", "beta"; threshold=1.0)
    @test !ANS.is_aiml_growth_inhibited("aiml_inhibit", "alpha"; threshold=1.0)

    ANS.record_orchestration_contribution!(contributor)

    @test ANS.is_aiml_growth_inhibited("aiml_inhibit", "alpha"; threshold=1.0)
    @test !ANS.is_aiml_growth_inhibited("aiml_inhibit", "beta"; threshold=1.0)
    @test ANS.is_aiml_growth_inhibited("aiml_inhibit", "synalpha"; threshold=1.0, thesaurus_fn=(tok -> tok == "alpha" ? ["synalpha"] : String[]))

    before = ANS.get_alive_population_size("aiml_inhibit")
    grown = ANS.stochastic_aiml_growth!("aiml_inhibit", "synalpha"; data_warrant=1.0, thesaurus_fn=(tok -> tok == "alpha" ? ["synalpha"] : String[]))
    @test grown === nothing
    @test ANS.get_alive_population_size("aiml_inhibit") == before

    ANS.begin_cycle!()
    @test !ANS.is_aiml_growth_inhibited("aiml_inhibit", "alpha"; threshold=1.0)

    ANS.reset_all!()
end
