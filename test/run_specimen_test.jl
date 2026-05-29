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
println("  julia test/build_specimen.jl      # build specimen")
println("  julia test/run_missions.jl N      # run mission #N (1-7)")
println("  julia test/dump_stats.jl          # dump stats")
println("See test/specimen_test_log.md for the full conversation log.")
