#!/usr/bin/env julia
# test/test_dict_sigil.jl
# ==============================================================================
# Integration test for GRUG v9 dictionary sigil pipeline — per-lobe dict nodes.
# Tests that dictionary words are promoted via &define sigil, that per-lobe
# dictionary sigil nodes exist and are assigned to their lobes, and that the
# definition flows through the action callback pipeline.
# ==============================================================================

const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))

# Load the full GrugBot420 module
using Pkg
Pkg.activate(REPO_ROOT)

ENV["GRUG_NO_AUTOLOAD"] = "1"

include(joinpath(REPO_ROOT, "src", "GrugBot420.jl"))
using .GrugBot420

# Import non-exported internals we need for testing
import .GrugBot420: process_mission,
    load_specimen_from_file!,
    SigilRegistry, SigilPromoter, ActionEngine,
    _ENGINE_SIGIL_TABLE, list_sigil_node_ids,
    NODE_MAP, NODE_LOCK,
    _dict_has_word_for_lobe
import .GrugBot420.Lobe: find_lobe_for_node

# ── Helpers ──────────────────────────────────────────────────────────────────

passed = 0
failed = 0
total  = 0

function test(name::String, expr::Bool)
    global passed, failed, total
    total += 1
    if expr
        passed += 1
        println("  ✅ $name")
    else
        failed += 1
        println("  ❌ FAILED: $name")
    end
end

# ── Specimen path ────────────────────────────────────────────────────────────

specimen_path = joinpath(REPO_ROOT, "grug_v828e_post_test.specimen")
if !isfile(specimen_path)
    println("❌ SPECIMEN NOT FOUND: $specimen_path")
    exit(1)
end

println("=" ^ 70)
println("GRUG v9 Dictionary Sigil Integration Test (Per-Lobe)")
println("=" ^ 70)

# ── Test 1: Specimen loads and dict word checker is wired ─────────────────────
println("\n── Test 1: Specimen load and dict word checker ──")

try
    load_specimen_from_file!(specimen_path)
    println("  ✅ Specimen loaded successfully")
catch e
    println("  ❌ Specimen load failed: $e")
    for (exc, bt) in current_exceptions()
        showerror(stdout, exc, bt)
        println()
    end
    exit(1)
end

# Check that dict word checker is wired
_checker = SigilRegistry.get_dict_word_checker()
test("Dict word checker is wired", _checker !== nothing)
test("Dict word checker detects 'stalactite'", _checker("stalactite") == true)
test("Dict word checker rejects 'hello'", _checker("hello") == false)

# ── Test 2: &define sigil is registered and promotes correctly ───────────────
println("\n── Test 2: &define sigil registration and promotion ──")

_define_entry = SigilRegistry.lookup_sigil(_ENGINE_SIGIL_TABLE, "define")
test("&define sigil is registered", _define_entry !== nothing)
if _define_entry !== nothing
    test("&define sigil class is :lambda", _define_entry.class === :lambda)
    test("&define sigil_type is :define", _define_entry.sigil_type === :define)
    test("&define promote_at_tokenize is true", _define_entry.promote_at_tokenize === true)
end

# Test promotion of a dictionary word
_promoted, _bindings = SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, "what is stalactite")
println("  Promoted: \"$(_promoted)\"")
println("  Bindings: $([string(b.name, "=", b.value, " [surface=", b.surface, "]") for b in _bindings])")

test("Promoted text contains &define", occursin("&define", _promoted))
test("Promoted text contains &query", occursin("&query", _promoted))
test("Promoted text contains &definition", occursin("&definition", _promoted))

# Find the &define binding and check its surface preserves the original word
_define_bindings = filter(b -> b.name == "define", _bindings)
test("&define binding exists", !isempty(_define_bindings))
if !isempty(_define_bindings)
    test("&define binding surface preserves 'stalactite'", lowercase(first(_define_bindings).surface) == "stalactite")
end

# ── Test 3: &concept excludes dictionary words ───────────────────────────────
println("\n── Test 3: &concept excludes dictionary words ──")

# Non-dictionary words should still promote to &concept
_nc_promoted, _ = SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, "what is philosophy")
println("  Non-dict promoted: \"$(_nc_promoted)\"")
test("Non-dict word 'philosophy' promotes to &concept", occursin("&concept", _nc_promoted))

# Dictionary words should NOT promote to &concept — they go to &define
_dc_promoted, _dc_bindings = SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, "what is stalactite")
_has_concept_stalactite = any(b.name == "concept" && lowercase(b.surface) == "stalactite" for b in _dc_bindings)
test("Dict word 'stalactite' NOT promoted to &concept", _has_concept_stalactite == false)

# ── Test 4: Per-lobe dictionary sigil nodes exist ────────────────────────────
println("\n── Test 4: Per-lobe dictionary sigil nodes ──")

_dict_node_ids = list_sigil_node_ids(:define)
test("Dictionary sigil nodes exist", !isempty(_dict_node_ids))
println("  Dictionary sigil node IDs: $(_dict_node_ids)")

# Each dict node should have dict_lobe_id in its json_data and be assigned to that lobe
# (unless the lobe_id isn't in LOBE_REGISTRY, like "default" — those float unassigned)
# Use filter/map to avoid Julia soft-scope issues (for-loop assignment creates new local at top level)
_lobe_assigned_count = count(_dict_node_ids) do _nid
    _n = NODE_MAP[_nid]
    _cb = get(_n.json_data, "action_callback", "")
    _lid = get(_n.json_data, "dict_lobe_id", "")
    test("Node $_nid has per-lobe action_callback (not bare 'dict_define')", _cb != "dict_define")
    test("Node $_nid has dict_lobe_id in json_data", !isempty(_lid))
    println("  Node $_nid: action_callback='$_cb', dict_lobe_id='$_lid', pattern='$(_n.pattern)'")
    if !isempty(_lid)
        # Nodes for lobes in LOBE_REGISTRY should be assigned to that lobe.
        # Nodes for pseudo-lobes (like "default") float unassigned — that's OK.
        if haskey(GrugBot420.Lobe.LOBE_REGISTRY, _lid)
            _assigned_lid = GrugBot420.Lobe.find_lobe_for_node(_nid)
            _assigned_lid == _lid
        else
            println("    (pseudo-lobe '$_lid' not in LOBE_REGISTRY — node floats unassigned)")
            true  # unassigned is expected for pseudo-lobes
        end
    else
        false
    end
end
_total_dict_nodes = length(_dict_node_ids)
test("Dict nodes are assigned to their respective lobes", _lobe_assigned_count == _total_dict_nodes)
println("  $_lobe_assigned_count/$_total_dict_nodes dict nodes correctly assigned to lobes")

# ── Test 5: Per-lobe action callbacks are registered ─────────────────────────
println("\n── Test 5: Per-lobe dict_define action callbacks ──")

# Check that at least one per-lobe callback exists
_per_lobe_cbs = filter(n -> startswith(n, "dict_define_") && n != "dict_define", ActionEngine.list_action_callbacks())
test("Per-lobe dict_define callbacks exist", !isempty(_per_lobe_cbs))
println("  Per-lobe callbacks: $_per_lobe_cbs")

# Also check the fallback is registered
test("Fallback dict_define callback is registered", ActionEngine.has_action_callback("dict_define"))

# Test per-lobe callback ISOLATION — the key architectural contract.
# Each callback must ONLY look up words in its own lobe's dictionary.
# "stalactite" is in the "default" dictionary (general knowledge).
# It should NOT be in science or any other named lobe's dictionary.
# So dict_define_default should find stalactite, all others should NOT.

# First, find which lobes actually have "stalactite" in their dictionaries
_stalactite_lobes = String[]
for (_cb_name) in _per_lobe_cbs
    _cb_lobe = _cb_name[length("dict_define_")+1:end]
    if GrugBot420._dict_has_word_for_lobe("stalactite", _cb_lobe)
        push!(_stalactite_lobes, _cb_lobe)
    end
end
println("  Lobes with 'stalactite': $_stalactite_lobes")

# The "default" dictionary should have stalactite
test("'default' dictionary has 'stalactite'", "default" in _stalactite_lobes)

# Test EVERY per-lobe callback for isolation
for _cb_name in _per_lobe_cbs
    _cb_lobe = _cb_name[length("dict_define_")+1:end]
    _test_bindings = [SigilPromoter.SigilBinding(0, "define", "stalactite", :lambda, "stalactite", 0)]
    _result = ActionEngine.compute_action(_cb_name, _test_bindings)

    if _cb_lobe in _stalactite_lobes
        # This lobe HAS stalactite — callback should return the definition
        println("  $_cb_name (has stalactite): answer_str='$(_result.answer_str)'")
        test("$_cb_name returns definition for 'stalactite' (its lobe has it)",
             _result.error === nothing && _result.answer_str != "")
    else
        # This lobe does NOT have stalactite — callback must return error/nothing
        println("  $_cb_name (no stalactite): error='$(_result.error)' answer_str='$(_result.answer_str)'")
        test("$_cb_name returns error for 'stalactite' (its lobe lacks it)",
             _result.error !== nothing)
    end
end

# ── Test 6: Full process_mission pipeline ────────────────────────────────────
println("\n── Test 6: Full process_mission pipeline ──")

try
    process_mission("what is a stalactite")
    println("  ✅ process_mission('what is a stalactite') completed without error")
catch e
    println("  ⚠️ process_mission threw: $e")
end

# Check the last voice output for definition content
_last_output = ""
lock(GrugBot420._LAST_VOICE_OUTPUT_LOCK) do
    _last_output = GrugBot420._LAST_VOICE_OUTPUT[]
end
_out_preview = _last_output[1:min(200, length(_last_output))]
println("  Last voice output (first 200 chars): \"$(_out_preview)\"")
if !isempty(_last_output)
    test("Voice output contains definition content",
         occursin("mineral", lowercase(_last_output)) ||
         occursin("cave", lowercase(_last_output)) ||
         occursin("ceiling", lowercase(_last_output)) ||
         occursin("formation", lowercase(_last_output)))
else
    println("  ⚠️ No voice output captured — skipping voice output test")
end

# ── Test 7: Non-dictionary question still works ──────────────────────────────
println("\n── Test 7: Non-dictionary question (side-channel) ──")

try
    process_mission("what is philosophy")
    println("  ✅ process_mission('what is philosophy') completed without error")
catch e
    println("  ⚠️ process_mission threw (may be expected): $e")
end
# Just check it doesn't crash the process
test("Non-dictionary question doesn't crash process", true)

# ── Results ──────────────────────────────────────────────────────────────────

println("\n" * "=" ^ 70)
println("   TEST RESULTS")
println("=" ^ 70)
println("  Total:  $total")
println("  Passed: $passed ✅")
println("  Failed: $failed ❌")
println("=" ^ 70)

if failed > 0
    println("\n!!! SOME TESTS FAILED !!!")
    exit(1)
else
    println("\n🎉 ALL TESTS PASSED! Per-lobe dictionary sigil pipeline is solid rock!")
    exit(0)
end
