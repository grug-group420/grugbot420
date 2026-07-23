# test/test_procedure_sigil.jl
# v7.23 — :procedure class activation in SigilRegistry.
#
# Loads SigilRegistry source directly, matching the pattern used by
# test_sigil_registry.jl, so we are independent of the package precompile
# cache.

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

module _ProcSigilTestParent
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    using .SigilRegistry
end

using ._ProcSigilTestParent.SigilRegistry

@testset "Procedure sigil — register and expand flat" begin
    tbl = SigilTable("test-proc-flat")
    register_procedure_sigil!(tbl;
        name = "Sum-pair",
        expansion = ["sum", "of", "two", "values"])
    @test is_procedure_sigil(tbl, "Sum-pair")
    out = expand_procedure_sigil(tbl, "Sum-pair")
    @test out == ["sum", "of", "two", "values"]
end

@testset "Procedure sigil — register and expand nested with non-procedure ref" begin
    tbl = SigilTable("test-proc-nested")
    register_sigil!(tbl;
        name = "n",
        class = :lambda,
        applies_at = :match,
        sigil_type = :number)
    register_procedure_sigil!(tbl;
        name = "Add-one",
        expansion = ["&n", "plus", "one"])
    out = expand_procedure_sigil(tbl, "Add-one")
    @test out == ["&n", "plus", "one"]
end

@testset "Procedure sigil — recursive expansion of nested :procedure" begin
    tbl = SigilTable("test-proc-recursive")
    register_procedure_sigil!(tbl;
        name = "inner",
        expansion = ["a", "b"])
    register_procedure_sigil!(tbl;
        name = "outer",
        expansion = ["x", "&inner", "y"])
    out = expand_procedure_sigil(tbl, "outer")
    @test out == ["x", "a", "b", "y"]
end

@testset "Procedure sigil — empty expansion rejected" begin
    tbl = SigilTable("test-proc-empty")
    @test_throws SigilConfigError register_procedure_sigil!(tbl;
        name = "empty",
        expansion = String[])
end

@testset "Procedure sigil — non-string element rejected" begin
    tbl = SigilTable("test-proc-bad")
    @test_throws SigilConfigError register_procedure_sigil!(tbl;
        name = "badtype",
        expansion = ["ok", 123])
end

@testset "Procedure sigil — unknown nested sigil throws on expand" begin
    tbl = SigilTable("test-proc-unknown")
    register_procedure_sigil!(tbl;
        name = "ref-ghost",
        expansion = ["known", "&missing"])
    @test_throws SigilResolutionError expand_procedure_sigil(tbl, "ref-ghost")
end

@testset "Procedure sigil — cycle guard fires" begin
    tbl = SigilTable("test-proc-cycle")
    register_procedure_sigil!(tbl;
        name = "A",
        expansion = ["a", "&B"])
    register_procedure_sigil!(tbl;
        name = "B",
        expansion = ["b", "&A"])
    @test_throws SigilConfigError expand_procedure_sigil(tbl, "A")
end

@testset "Procedure sigil — Greek-letter math acronym names" begin
    tbl = SigilTable("test-proc-greek")
    register_procedure_sigil!(tbl;
        name = "Σ",
        expansion = ["sum", "of"])
    @test is_procedure_sigil(tbl, "Σ")
    @test expand_procedure_sigil(tbl, "Σ") == ["sum", "of"]
end
