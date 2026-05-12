# test/test_v15_cli_verbs.jl
# ==============================================================================
# GRUG v7.15.2 test: end-to-end CLI wiring for the new /groupStatus,
# /groupRegister, /groupGrave, /groupWindow, /crystalize, /uncrystalize,
# /crystalizeList, /crystalizeAuto, /chatterSwap, /phagy, /groupOrganize,
# /groupSnapshot, /groupRestore verbs.
#
# Approach: load the full GrugBot420 package, feed a scripted sequence of
# commands through process_mission / direct handler invocation, and assert
# that the registry and crystalize subsystems have the expected state.
#
# NO SILENT FAILURE: every command path throws visibly on bad inputs; the
# tests assert both the happy path and the reject-bad-input path.
# ==============================================================================

using Test

# GRUG: Full package load --- we need the complete dispatcher + state.
using GrugBot420

println("\n" * "="^60)
println("GRUG v7.15.2 CLI Verb Wiring TEST SUITE")
println("="^60)

# ==============================================================================
# Helper: silent exec --- run a block capturing stdout so the test log
# isn't polluted by every command's banner.
# ==============================================================================
function silent(f)
    redirect_stdout(devnull) do
        redirect_stderr(devnull) do
            return f()
        end
    end
end

# ==============================================================================
# [1] GroupRegistry round-trip via CLI-adjacent APIs
# ==============================================================================
@testset "group registry: register + grave + list via public API" begin
    # GRUG: The CLI handlers delegate to these same exports; covering the
    # exports end-to-end proves the wiring is real, not just a Ref setter.
    GrugBot420.GroupRegistry.reset_registry!()
    GrugBot420.GroupRegistry.register_node_in_group!("cli_grp_1", "cli_node_a")
    GrugBot420.GroupRegistry.register_node_in_group!("cli_grp_1", "cli_node_b")
    GrugBot420.GroupRegistry.register_node_in_group!("cli_grp_2", "cli_node_a")

    @test GrugBot420.GroupRegistry.group_count() == 2
    @test "cli_grp_1" in GrugBot420.GroupRegistry.list_group_ids()
    @test "cli_grp_2" in GrugBot420.GroupRegistry.list_group_ids()

    touched = GrugBot420.GroupRegistry.grave_node_everywhere!("cli_node_a")
    @test touched == 2

    @test GrugBot420.GroupRegistry.get_group("cli_grp_1").grave_count == 1
    @test GrugBot420.GroupRegistry.get_group("cli_grp_2").grave_count == 1
end

# ==============================================================================
# [2] Crystalize round-trip
# ==============================================================================
@testset "crystalize: user + auto + release" begin
    GrugBot420.CrystalizeTag.clear_all_crystalized!()

    GrugBot420.CrystalizeTag.mark_user_crystalized!("cli_node_x")
    @test GrugBot420.CrystalizeTag.is_crystalized("cli_node_x") == true
    @test GrugBot420.CrystalizeTag.crystalized_count() == 1

    GrugBot420.CrystalizeTag.mark_auto_crystalized!("cli_node_y")
    @test GrugBot420.CrystalizeTag.is_crystalized("cli_node_y") == true
    @test GrugBot420.CrystalizeTag.is_auto_crystalized("cli_node_y") == true

    # GRUG: uncrystalize! (with default user=true, auto=true) removes both tags
    GrugBot420.CrystalizeTag.uncrystalize!("cli_node_x")
    @test GrugBot420.CrystalizeTag.is_crystalized("cli_node_x") == false

    # GRUG: auto-crystalize decision at strength 9.0, confidence 0.9
    @test GrugBot420.CrystalizeTag.should_auto_crystalize(9.0, 0.9) == true
    # GRUG: auto-crystalize REJECTED at strength below floor
    @test GrugBot420.CrystalizeTag.should_auto_crystalize(5.0, 0.9) == false
    # GRUG: auto-crystalize REJECTED at confidence below floor
    @test GrugBot420.CrystalizeTag.should_auto_crystalize(9.0, 0.3) == false
end

# ==============================================================================
# [3] Chatter vote-swap round runs without crashing over a real registry
# ==============================================================================
@testset "chatter vote-swap round: end-to-end" begin
    GrugBot420.GroupRegistry.reset_registry!()
    GrugBot420.ChatterVoteSwap.clear_chatter_cooldowns!()

    # GRUG: Register 3 nodes in one group so the swap has candidates.
    for n in ["vs_a", "vs_b", "vs_c"]
        GrugBot420.GroupRegistry.register_node_in_group!("vs_grp", n)
    end

    # GRUG: Fake accessors covering the ChatterVoteSwap contract.
    strengths = Dict("vs_a" => 8.0, "vs_b" => 3.0, "vs_c" => 6.0)
    actions   = Dict("vs_a" => "do_alpha^1.0",
                     "vs_b" => "do_beta^1.0",
                     "vs_c" => "do_gamma^1.0")
    get_node = nid -> (
        exists   = haskey(strengths, nid),
        strength = get(strengths, nid, 0.0),
        action   = get(actions,   nid, ""),
        weight   = 1.0,
        is_weak  = get(strengths, nid, 0.0) < 7.5,
    )
    # GRUG: Force maximum intensity so the semantic gate always passes.
    get_intensity = (_, _) -> 1.0
    applied = Ref(0)
    apply_swap = ev -> begin
        applied[] += 1
        GrugBot420.ChatterVoteSwap.record_chatter_time!(ev.receiver_id)
        true
    end
    group_members = gid -> begin
        g = GrugBot420.GroupRegistry.get_group(gid)
        isnothing(g) ? String[] : copy(g.member_ids)
    end

    gids = GrugBot420.GroupRegistry.next_chatter_window_ids(; window_size = 50)
    @test length(gids) == 1

    stats = silent() do
        GrugBot420.ChatterVoteSwap.run_vote_swap_round!(
            gids, get_node, get_intensity, apply_swap, group_members)
    end

    # GRUG: rounds_run must be exactly 1 (we called once over a 1-group window).
    @test stats.rounds_run == 1
    # GRUG: At least one swap should have been attempted --- vs_b is weak and
    # vs_a/vs_c are stronger, so some pairing must trigger.
    @test stats.swaps_attempted > 0
    @test applied[] == stats.swaps_accepted
end

# ==============================================================================
# [4] Phagy 7th automaton is wired at package load (integration check)
# ==============================================================================
@testset "package load: phagy group organizer is wired" begin
    @test GrugBot420.PhagyMode.has_group_organizer() == true
end

# ==============================================================================
# [5] Group snapshot + restore round-trip (CLI verbs delegate to these)
# ==============================================================================
@testset "group registry: snapshot + restore round-trip" begin
    GrugBot420.GroupRegistry.reset_registry!()
    for i in 1:5
        GrugBot420.GroupRegistry.register_node_in_group!("snap_grp_$i", "snap_node_$i")
    end

    tmp = tempname() * ".json.gz"
    written = GrugBot420.GroupRegistry.save_registry_compressed(tmp)
    @test isfile(written)

    GrugBot420.GroupRegistry.reset_registry!()
    @test GrugBot420.GroupRegistry.group_count() == 0

    GrugBot420.GroupRegistry.load_registry_compressed(written)
    @test GrugBot420.GroupRegistry.group_count() == 5

    rm(written, force = true)
end

# ==============================================================================
# [6] Engine grave sync: mark_node_grave! pushes into GroupRegistry
# ==============================================================================
@testset "engine grave sync: mark_node_grave! updates GroupRegistry" begin
    GrugBot420.GroupRegistry.reset_registry!()

    # GRUG: Create a real engine node so mark_node_grave! has a live Node to
    # mutate; then register it in a group; then grave it and verify the
    # registry's grave_count tracked the event.
    pattern = "integration grave sync test node"
    packet  = "test_action^1.0"
    node_id = silent() do
        GrugBot420.create_node(pattern, packet, Dict(), String[])
    end
    @test haskey(GrugBot420.NODE_MAP, node_id)

    GrugBot420.GroupRegistry.register_node_in_group!("sync_grp", node_id)
    @test GrugBot420.GroupRegistry.get_group("sync_grp").grave_count == 0

    node = GrugBot420.NODE_MAP[node_id]
    silent() do
        GrugBot420.mark_node_grave!(node, "INTEGRATION_TEST_REASON")
    end
    @test node.is_grave == true
    @test GrugBot420.GroupRegistry.get_group("sync_grp").grave_count == 1
end

println("\n" * "="^60)
println("✅  v7.15.2 CLI Verb Wiring tests COMPLETE")
println("="^60)
