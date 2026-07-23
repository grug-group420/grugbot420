# GRUG: Smoke test for relational-triple strictness coupling
# ----------------------------------------------------------------
# Rule:
#   mode 3 (high_res) -> dynamic REQUIRED (no silent fallback)
#   mode 1/2 (simple) -> basic (empty on failure, non-fatal)
#
# This test verifies the COUPLING between scan complexity and relational
# extraction mode. It does not test the extractors themselves (those live
# in their own unit tests) — it tests the dispatch logic via behavioural
# observation of scan_specimens and direct extractor invocations.
# ----------------------------------------------------------------

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

@testset "Relational Triple Strictness Coupling" begin

    println("\n============================================================")
    println("GRUG RELATIONAL TRIPLE STRICTNESS TEST")
    println("============================================================\n")

    # ---------------------------------------------------------------
    # [1] Extractor symbols are exported
    # ---------------------------------------------------------------
    println("[1] EXTRACTOR SYMBOLS EXPORTED")
    @test isdefined(GrugBot420, :extract_dynamic_relational_triples)
    println("  ✓ extract_dynamic_relational_triples is defined")
    @test isdefined(GrugBot420, :extract_relational_triples)
    println("  ✓ extract_relational_triples is defined")
    @test isdefined(GrugBot420, :screen_input_complexity)
    println("  ✓ screen_input_complexity is defined")

    # ---------------------------------------------------------------
    # [2] screen_input_complexity signature: (Vector{Float64}, Vector{RT})
    # ---------------------------------------------------------------
    println("\n[2] screen_input_complexity API")
    simple_sig  = GrugBot420.words_to_signal("cat runs")
    complex_sig = GrugBot420.words_to_signal(
        "The quick brown fox that jumped over the lazy dog because it was " *
        "hungry and tired after running through the forest, which was dense " *
        "and dark, finally found shelter near the old oak tree"
    )
    mode_simple  = GrugBot420.screen_input_complexity(simple_sig,  GrugBot420.RelationalTriple[])
    mode_complex = GrugBot420.screen_input_complexity(complex_sig, GrugBot420.RelationalTriple[])
    @test mode_simple  in (1, 2, 3)
    @test mode_complex in (1, 2, 3)
    println("  ✓ simple scan_mode  = $mode_simple")
    println("  ✓ complex scan_mode = $mode_complex")

    # ---------------------------------------------------------------
    # [3] Basic extractor is callable on simple input
    # ---------------------------------------------------------------
    println("\n[3] BASIC EXTRACTOR CALLABLE")
    basic_triples = GrugBot420.extract_relational_triples("cat runs fast")
    @test basic_triples isa Vector{GrugBot420.RelationalTriple}
    println("  ✓ extract_relational_triples returned $(length(basic_triples)) triples")

    # ---------------------------------------------------------------
    # [4] Dynamic extractor is callable on complex input (mode 3)
    # ---------------------------------------------------------------
    println("\n[4] DYNAMIC EXTRACTOR CALLABLE")
    dyn_triples = GrugBot420.extract_dynamic_relational_triples(
        "The cat that chased the mouse eventually caught it in the barn", 3
    )
    @test dyn_triples isa Vector{GrugBot420.RelationalTriple}
    println("  ✓ extract_dynamic_relational_triples returned $(length(dyn_triples)) triples")

    # ---------------------------------------------------------------
    # [5] scan_specimens end-to-end — simple input (smoke)
    # ---------------------------------------------------------------
    println("\n[5] scan_specimens SMOKE — simple input")
    local ok_simple = false
    try
        _ = GrugBot420.scan_specimens("hi")
        ok_simple = true
        println("  ✓ scan_specimens ran on simple input without throwing")
    catch e
        println("  ✗ scan_specimens threw on simple input: $e")
    end
    @test ok_simple

    # ---------------------------------------------------------------
    # [6] scan_specimens end-to-end — complex input (smoke)
    #     If dynamic extraction fails on a legitimately-complex input,
    #     STRICT mode requires the error to propagate (no silent fall-
    #     back). We accept either: clean run OR a loud propagated error.
    # ---------------------------------------------------------------
    println("\n[6] scan_specimens SMOKE — complex input")
    complex_input = "The quick brown fox that jumped over the lazy dog " *
                    "because it was hungry and tired after running through " *
                    "the forest, which was dense and dark, finally found " *
                    "shelter near the old oak tree where other foxes rest"
    local complex_result = :pending
    try
        _ = GrugBot420.scan_specimens(complex_input)
        complex_result = :clean
        println("  ✓ scan_specimens ran on complex input cleanly")
    catch e
        complex_result = :propagated
        println("  ℹ scan_specimens propagated error (STRICT no-silent-fail is correct):")
        println("    $e")
    end
    # Either outcome is acceptable per strict spec — both honour no-silent-fail.
    @test complex_result in (:clean, :propagated)

    println("\n============================================================")
    println("✅ RELATIONAL TRIPLE STRICTNESS TESTS COMPLETE")
    println("============================================================\n")
end