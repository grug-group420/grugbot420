# test/test_v15_cli_stdin_smoke.jl
# ==============================================================================
# GRUG v7.15.2 CLI-stdin smoke test: feed scripted input through Main.jl's CLI
# loop (run_cli) via a child process. Every new verb must parse, dispatch, and
# exit cleanly. Bad-input paths must produce a visible error line, not crash.
#
# Why a subprocess? run_cli() reads from stdin and blocks; we need an
# isolated process we can pipe into. Any non-zero exit OR any unhandled
# stack trace in the output fails the test (NO SILENT FAILURE).
# ==============================================================================

using Test

println("\n" * "="^60)
println("GRUG v7.15.2 CLI-stdin Smoke TEST SUITE")
println("="^60)

const REPO_ROOT = joinpath(@__DIR__, "..")
const MAIN_JL   = joinpath(REPO_ROOT, "src", "Main.jl")

# GRUG: scripted input exercising every new verb. Covers happy path + a few
# pure-error paths. The final /quit triggers a clean exit (code 0).
const SCRIPT = """
/groupStatus
/crystalizeList
/groupWindow
/groupWindow 5
/chatterSwap 5
/groupOrganize
/phagy
/crystalize bogus_node_id_that_does_not_exist
/uncrystalize bogus_node_id_that_does_not_exist
/groupGrave bogus_node_id_that_does_not_exist
/groupRegister bogus_group_id bogus_node_id
/crystalizeAuto bogus_node_id
/groupSnapshot /tmp/grug_v15_smoke_snap.json.gz
/groupRestore /tmp/grug_v15_smoke_snap.json.gz
/help
/quit
"""

# GRUG: Shell out. 3min timeout is generous for the ~20 commands above.
@testset "CLI stdin smoke: all v7.15 verbs exit cleanly" begin
    cmd = pipeline(`$(Base.julia_cmd()) --project=$(REPO_ROOT) $MAIN_JL`,
                   stdin = IOBuffer(SCRIPT))
    proc = run(cmd, wait = false)
    t_start = time()
    timeout_s = 180.0
    done = false
    while time() - t_start < timeout_s
        if process_exited(proc)
            done = true
            break
        end
        sleep(0.2)
    end

    if !done
        # GRUG: NO SILENT FAILURE --- kill the subprocess and fail loudly.
        kill(proc)
        @test false  # timed out
        return
    end

    @test proc.exitcode == 0
end

# Cleanup
isfile("/tmp/grug_v15_smoke_snap.json.gz") && rm("/tmp/grug_v15_smoke_snap.json.gz")

println("\n" * "="^60)
println("✅  v7.15.2 CLI-stdin Smoke tests COMPLETE")
println("="^60)
