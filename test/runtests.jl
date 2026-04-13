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
    "test_vote_ties.jl",
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