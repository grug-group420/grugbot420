# test/runtests.jl — GrugBot420 Package Test Runner
# ==============================================================================
# GRUG: All test files include src/ modules directly (not via GrugBot420 package).
# Running multiple such files in the same Julia process causes module redefinition
# errors. Each test file runs as an isolated subprocess.
# Non-zero exit code = test failure. No silent swallowing.
# ==============================================================================

using Test

const REPO_ROOT = joinpath(@__DIR__, "..")
const TEST_DIR  = @__DIR__

# All test files run as isolated subprocesses
const ALL_TESTS = [
    "test_lobe_table.jl",
    "test_lobes.jl",
    "test_brainstem.jl",
    "test_thesaurus.jl",
    "test_input_queue.jl",
    "test_concept_class.jl",
    "test_action_packet.jl",
    "test_smoke.jl",
    "test_phagy.jl",
    "test_node_attach.jl",
    "test_immune.jl",
    "test_immune_thread_pool.jl",
    "test_full_lobe_scanner.jl",
    "test_vote_ties.jl",
    "test_comprehensive.jl",
    "test_aiml_node_system.jl",
    "test_vote_orchestrator.jl",
    "test_relational_strict.jl",
    "test_relational_jitter.jl",
    "test_aiml_jitter.jl",
    "test_brainstorm_jitter.jl",
    "test_context_intensity.jl",
    "test_lobe_topicality_gate.jl",
    "test_big_number_small_number_coherence.jl",
    "test_nonjitter_tag.jl",
    "test_strength_solidify.jl",
    # GRUG v7.15 additions --- sequential lobe orchestration, group registry,
    # crystalize, vote-swap chatter, dynamic action-tone, strong-low-conf
    # jitter override, and the phagy group organizer.
    "test_lobe_orchestrator.jl",
    "test_group_registry.jl",
    "test_crystalize_tag.jl",
    "test_chatter_vote_swap.jl",
    "test_dynamic_action_tone.jl",
    "test_jitter_strong_low_conf_override.jl",
    "test_phagy_group_organizer.jl",
    # GRUG v7.15.2 wiring tests --- phagy 7th-automaton plug hook,
    # GroupRegistry grave_node_everywhere! single-call sync, end-to-end
    # CLI verb integration suite, and CLI stdin smoke test.
    "test_phagy_automaton_7_wiring.jl",
    "test_group_registry_grave_everywhere.jl",
    "test_v15_cli_verbs.jl",
    "test_v15_cli_stdin_smoke.jl",
    # GRUG v7.16.1 --- relation-gated support band for AIML orchestration.
    # Proves each axis of relation_score earns points only for real links.
    "test_support_relation_gate.jl",
    # GRUG v7.16.2 --- composition-roll for confirmed-support claims.
    # Confirmed supports get WOVEN into the primary sentence via a
    # weighted random stitch pick from a strictly-gated registry.
    "test_support_composition.jl",
    # GRUG v7.16.3 --- absolute lock-in floor with semantic weighting.
    # Top tier membership is now combined(confidence + 0.15 * linkage)
    # >= 0.50, so complex questions with multiple strong+linked peers
    # all lock in together instead of only the top 2 via relative window.
    "test_lockin_floor.jl",
    # GRUG (ported from main): SelfObserver subconscious microlog,
    # SigilRegistry kernel + SigilPromoter front-door rewriter +
    # ArithmeticEngine sigil-bound math. All four are additive on top of
    # the v7.15/v7.16 stack — none of them touch confidence math or
    # disturb the existing lock-in / relation-gate tests.
    "test_self_observer.jl",
    "test_sigil_registry.jl",
    "test_sigil_promoter.jl",
    "test_arithmetic_engine.jl",
    # GRUG (v7.16+): tonal build-up over consecutive same-tone predictions
    # + per-prediction Lorenz snap-back jitter. Locks in the new dynamics
    # added on top of the v7.15-updates ActionTonePredictor.
    "test_tonal_buildup_and_snapback.jl",
]

@testset "GrugBot420 Tests" begin
    for f in ALL_TESTS
        @testset "$f" begin
            fpath = joinpath(TEST_DIR, f)
            cmd = `$(Base.julia_cmd()) --project=$(REPO_ROOT) $fpath`
            ok = success(pipeline(cmd, stdout=stdout, stderr=stderr))
            @test ok
        end
    end
end