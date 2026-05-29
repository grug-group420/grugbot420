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
    "test_big_number_small_number_coherence.jl",
    # GRUG v7.19: test_lobe_topicality_gate.jl is disabled - the underlying
    # _LAST_MUTED_LOBES telemetry was removed in an earlier refactor and the
    # test references an API surface that no longer exists. Re-enable when
    # the topicality gate is re-introduced or the test is rewritten.
    # "test_lobe_topicality_gate.jl",
    "test_nonjitter_tag.jl",
    "test_strength_solidify.jl",
    "test_chatter_v2.jl",
    "test_v7_20.jl",
    "test_v7_21a.jl",
    "test_v7_21b1.jl",
    "test_v7_21b2.jl",
    "test_v7_21b3b.jl",
    "test_v7_21b3d.jl",
    "test_v7_21c1.jl",
    "test_v7_21c2.jl",
    "test_self_observer.jl",
    "test_sigil_registry.jl",
    "test_sigil_promoter.jl",
    "test_arithmetic_engine.jl",
    # ---- v7.23 additions ----
    "test_multipart_orchestrator.jl",
    "test_ephemeral_automaton.jl",
    "test_procedure_sigil.jl",
    "test_input_decomposer.jl",
    "test_atp_escalation.jl",
    "test_multipart_integration.jl",
    "test_right_feedback_tiered.jl",
    "test_hippocampal_modulator.jl",
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