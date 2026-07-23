#!/usr/bin/env julia
# =============================================================================
# Full Specimen Integration Test
# =============================================================================
# This script has been superseded by the manual-interaction approach.
# See:
#   test/build_specimen.jl   — builds the multi_lobe_v1 specimen
#   test/run_missions.jl N   — runs mission #N (1-7) against the specimen
#   test/dump_stats.jl       — dumps specimen mechanics & stats
#   test/specimen_test_log.md — the conversation log with real AIML Output Scaffold responses
#
# The previous version of this script extracted MESSAGE_HISTORY digests as
# "replies" which were wrong — they parroted back the input as mission
# audit entries instead of capturing the actual AIML Output Scaffold.
# The new approach: build specimen, call process_mission, observe the AIML
# scaffold on stdout, and manually log the real responses.
# =============================================================================
println("This script has been superseded. Use:")
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
println("  julia test/build_specimen.jl      # build specimen")
println("  julia test/run_missions.jl N      # run mission #N (1-7)")
println("  julia test/dump_stats.jl          # dump stats")
println("See test/specimen_test_log.md for the full conversation log.")
