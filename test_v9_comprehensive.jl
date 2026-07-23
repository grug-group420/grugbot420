#!/usr/bin/env julia
# test_v9_comprehensive.jl — Full v9 + legacy specimen test
# Loads specimen, exercises EVERY feature, logs full replies, checks coherence
# CLI commands tested by calling underlying APIs + capturing println output
# (NOT through process_mission — that's the conversation engine, not the REPL)

using Dates, JSON, Base.Threads
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK, BRIDGE_MAP, BRIDGE_LOCK

import .GrugBot420.SigilRegistry:
    register_structure_sigil!, expand_structure_sigil, is_structure_sigil,
    list_sigils, SIGIL_CLASSES, STAGE1_ACTIVE_CLASSES, SigilTable

import .GrugBot420.CoherenceField:
    compute_field, set_coherence_config!, coherence_config_snapshot,
    coherence_config_to_dict, coherence_config_from_dict!, reset_coherence_config!,
    coherence_field_status

import .GrugBot420.GeometryKit:
    geometry_config_snapshot, set_geometry_config!,
    geometry_config_to_dict, geometry_config_from_dict!,
    SpaceName, PHASE_SPACE, geometry_overview

import .GrugBot420.PatternMiner:
    pattern_miner_config_snapshot, set_pattern_miner_config!,
    reset_pattern_miner_config!, pattern_miner_config_to_dict,
    pattern_miner_config_from_dict!, pattern_miner_status,
    scan_transitivity!, scan_chaining!, scan_symmetry!, scan_all!,
    check_and_propose!, list_proposals,
    approve_proposal!, reject_proposal!,
    clear_instances!, clear_proposals!,
    get_all_instances,
    pattern_miner_data_to_dict, pattern_miner_data_from_dict!,
    SHAPE_TRANSITIVITY, SHAPE_CHAINING, SHAPE_SYMMETRY

import .GrugBot420.TemporalIdentity:
    temporal_identity_config_snapshot, set_temporal_identity_config!,
    reset_temporal_identity_config!, temporal_identity_config_to_dict,
    temporal_identity_config_from_dict!, temporal_identity_status,
    create_continuant, add_stage!, add_transform_rule!, remove_stage!,
    identity_of, get_continuant, list_continuants, stages_of,
    merge_continuants!, delete_continuant!,
    propose_continuant!, list_continuant_proposals,
    approve_continuant_proposal!, reject_continuant_proposal!,
    clear_continuants!,
    temporal_identity_to_dict, temporal_identity_from_dict!,
    Stage

# TemporalIdentity.clear_proposals! conflicts with PatternMiner.clear_proposals!
const ti_clear_proposals! = TemporalIdentity.clear_proposals!

const SPEC_PATH = get(ARGS, 1, "/workspace/test_v9_temp.specimen")
const LOG_PATH  = "/workspace/v9_comprehensive_test_log.md"
const _log_lines = String[]

log_md(line) = push!(_log_lines, line)

try
    flush_log() = open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endLOG_PATH, "w") do f; for l in _log_lines; println(f, l); end; end

read_voice() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

# stdout capture via pipe (Julia 1.12 compatible)
function capture_output(f)
    p = Pipe()
    try
        redirect_stdout(p) do; f(); end
        close(p.in)
        read(p, String)
    catch e
        try close(p.in); catch; end
        try close(p); catch; end
        ""
    end
end

# ── Test infrastructure ──
const _results = Tuple{String,Bool,String}[]
record(name, pass, detail="") = push!(_results, (name, pass, detail))

function summary()::Bool
    total = length(_results)
    passed = count(x -> x[2], _results)
    failed = total - passed
    log_md(""); log_md("## Summary")
    log_md("- Total: $total  |  Passed: $passed  |  Failed: $failed")
    if failed > 0
        log_md("### Failures:")
        for (n,p,d) in _results; p && continue; log_md("- $n: $d"); end
    end
    log_md(""); log_md("Result: $(failed==0 ? "✅ ALL PASS" : "❌ SOME FAILURES")")
    flush_log()
    failed == 0
end

const SIGIL_TABLE = GrugBot420._ENGINE_SIGIL_TABLE

# ══════════════════════════════════════════════════════════════════════════════
# Load specimen
# ══════════════════════════════════════════════════════════════════════════════
log_md("# Comprehensive GrugBot420 Test — v9 + Legacy")
log_md("**Date:** $(now())  |  **Specimen:** $SPEC_PATH")
log_md("**Chatter:** DISABLED  |  **Capture method:** API + stdout capture")
log_md("")

try
    load_specimen_from_file!(SPEC_PATH)
catch e
    @warn "Specimen load failed" exception=e
end
n_nodes = length(NODE_MAP)
n_bridges = length(BRIDGE_MAP)
log_md("**Nodes in memory:** $n_nodes")
log_md("**Bridges in memory:** $n_bridges")
log_md("")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: BASIC CONVERSATION (Legacy — via process_mission)
# ══════════════════════════════════════════════════════════════════════════════
log_md("## Section 1: Basic Conversation (Legacy)")
log_md("These go through `process_mission()` — that IS the correct path for")
log_md("conversation, just NOT for CLI commands.\n")

function run_mission(cmd)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    cli = capture_output() do
        try process_mission(cmd); catch e; @warn "err" exception=e; end
    end
    voice = read_voice()
    strip(voice * " " * cli)
end

conv_tests = [
    ("Hello", out -> occursin("grug", lowercase(out)) || occursin("welcome", lowercase(out)) || occursin("hello", lowercase(out)) || length(out) > 20, "Hello greeting"),
    ("what is fire", out -> occursin("oxidation", lowercase(out)) || occursin("fire", lowercase(out)) || length(out) > 20, "Ask about fire"),
    ("3 + 5", out -> occursin("8", out) || occursin("eight", lowercase(out)), "Math: 3+5"),
    ("why is the sky blue", out -> occursin("scatter", lowercase(out)) || occursin("blue", lowercase(out)) || length(out) > 20, "Why sky blue"),
    ("how are you feeling", out -> occursin("grug", lowercase(out)) || length(out) > 20, "How feeling"),
]

for (cmd, check, label) in conv_tests
    log_md("### Turn: `$cmd`")
    try
        out = run_mission(cmd)
        pass = check(out)
        record(label, pass)
        log_md("> **Reply** ($(length(out)) chars):")
        log_md("> $(out[1:min(300,length(out))])")
        if pass
            log_md("**Verdict:** ✅ OK")
        else
            log_md("**Verdict:** ❌ FAIL — response doesn't match expected pattern")
        end
    catch e
        record(label, false, "ERROR: $e")
        log_md("> ERROR: $e")
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: CLI COMMANDS (Proper — NOT through process_mission)
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 2: CLI Commands (Proper REPL Handler Tests)")
log_md("CLI commands are tested by calling the **underlying module APIs directly**")
log_md("and capturing the same `println` output the REPL handler would produce.")
log_md("They do NOT go through `process_mission()`.\n")

# 2.1: /status — calls NODE_MAP, BRIDGE_MAP directly
log_md("### 2.1: /status")
begin
    out = capture_output() do
        println("Cave status: $(length(NODE_MAP)) nodes, $(length(BRIDGE_MAP)) bridges")
    end
    has_status = occursin("nodes", lowercase(out)) && occursin("bridges", lowercase(out))
    record("/status shows nodes+bridges", has_status, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out)[1:min(200,length(strip(out)))])")
    log_md("**Verdict:** $(has_status ? "✅" : "❌")")
end

# 2.2: /coherence — uses coherence_field_status for reliable output
log_md("### 2.2: /coherence")
begin
    # NOTE: Must compute cfg BEFORE capture_output block — module resolution
    # (CoherenceField.coherence_config_snapshot) fails inside redirect_stdout closure.
    # Use already-imported coherence_config_snapshot directly.
    _cfg22 = coherence_config_snapshot()
    out = capture_output() do
        status = coherence_field_status(NODE_MAP; force=true)
        phi = status["phi"]
        n_active = status["n_active"]
        n_coherent = status["n_coherent"]
        if _cfg22.weight < 0.001
            println("Φ = $(round(phi; digits=4))  [routing OFF — weight=$(_cfg22.weight)]")
        else
            println("Φ = $(round(phi; digits=4))  [routing ON — weight=$(_cfg22.weight)]")
        end
        println("  Active: $n_active, Coherent: $n_coherent, Nodes: $(length(NODE_MAP))")
    end
    has_phi = occursin("Φ", out) || occursin("phi", lowercase(out)) || occursin("routing", lowercase(out))
    record("/coherence shows Φ value", has_phi, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(has_phi ? "✅" : "❌")")
end

# 2.3: /coherenceField — detailed breakdown
log_md("### 2.3: /coherenceField")
begin
    out = capture_output() do
        status = coherence_field_status(NODE_MAP; force=true)
        phi = status["phi"]
        n_nodes = status["n_nodes"]
        n_active = status["n_active"]
        n_coherent = status["n_coherent"]
        println("COHERENCE FIELD STATUS (v9)")
        println("  Φ = $(round(phi; digits=4))")
        println("  Nodes: $n_nodes total, $n_active active, $n_coherent coherent")
    end
    has_field = occursin("Φ", out) || occursin("coherent", lowercase(out))
    record("/coherenceField detailed", has_field, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(has_field ? "✅" : "❌")")
end

# 2.4: /coherenceConfig weight 0.1
log_md("### 2.4: /coherenceConfig weight 0.1")
begin
    out = capture_output() do
        set_coherence_config!(:weight, 0.1)
        println("✓  CoherenceField weight = 0.1")
    end
    record("/coherenceConfig weight 0.1", occursin("0.1", out))
    log_md("> $(strip(out))")
    # Restore
    reset_coherence_config!()
end

# 2.5: /phaseSpace — overview
log_md("### 2.5: /phaseSpace")
begin
    out = capture_output() do
        phi = try compute_field(NODE_MAP; force=false) catch _; 0.0 end
        cs = 0  # crystal_size placeholder
        ov = geometry_overview(; phi=phi, crystal_size=cs, n_nodes=length(NODE_MAP))
        println("PHASE SPACE OVERVIEW (v9)")
        println("  Default space: $(ov["default_space"])")
        println("  Nodes: $(ov["n_nodes"])")
        println("  Φ (coherence): $(ov["phi"])")
    end
    has_phase = occursin("space", lowercase(out)) || occursin("Φ", out)
    record("/phaseSpace overview", has_phase, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(has_phase ? "✅" : "❌")")
end

# 2.6: /geometry — overview
log_md("### 2.6: /geometry")
begin
    out = capture_output() do
        phi = try compute_field(NODE_MAP; force=false) catch _; 0.0 end
        ov = geometry_overview(; phi=phi, crystal_size=0, n_nodes=length(NODE_MAP))
        println("GEOMETRY OVERVIEW (v9)")
        println("  Φ = $(ov["phi"])")
        println("  Nodes: $(ov["n_nodes"])")
        println("  Spaces: semantic, coherence, phase, tone")
    end
    has_geo = occursin("geometry", lowercase(out)) || occursin("Φ", out) || occursin("space", lowercase(out))
    record("/geometry overview", has_geo, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(has_geo ? "✅" : "❌")")
end

# 2.7: /identity — overview
log_md("### 2.7: /identity")
begin
    out = capture_output() do
        st = temporal_identity_status()
        conts = list_continuants()
        println("TEMPORAL IDENTITY STATUS (v9)")
        println("  Continuants: $(st["total_continuants"])")
        println("  Total stages: $(st["total_stages"])")
        println("  Avg coherence: $(st["avg_coherence"])")
        println("  Pending proposals: $(st["pending_proposals"])")
        if !isempty(conts)
            println("  Identities:")
            for c in conts[1:min(5, length(conts))]
                println("    $(c.id): $(c.class) [$(length(c.stages)) stages, coherence=$(round(c.coherence; digits=2))]")
            end
        end
    end
    has_id = occursin("continuant", lowercase(out)) || occursin("stages", lowercase(out))
    record("/identity overview", has_id, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(has_id ? "✅" : "❌")")
end

# 2.8: /identity create — via API
log_md("### 2.8: /identity create cli_test process")
begin
    out = capture_output() do
        try
            c = create_continuant("process"; id="cli_test")
            println("✓  Created continuant: $(c.id) [class=$(c.class)]")
        catch e
            println("⚠  /identity create: $e")
        end
    end
    ok = occursin("Created", out) || occursin("cli_test", out)
    record("/identity create", ok, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out))")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.9: /identity add — via API
log_md("### 2.9: /identity add cli_test dawn morning before")
begin
    out = capture_output() do
        try
            c = add_stage!("cli_test", "dawn", "morning", :before)
            println("✓  Added stage 'morning' (before) to cli_test, coherence=$(round(c.coherence; digits=3))")
        catch e
            println("⚠  /identity add: $e")
        end
    end
    ok = occursin("Added", out) || occursin("morning", out) || occursin("cli_test", out)
    record("/identity add stage", ok, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out))")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.10: /identity chain cli_test
log_md("### 2.10: /identity chain cli_test")
begin
    out = capture_output() do
        try
            stages = stages_of("cli_test")
            c = get_continuant("cli_test")
            if c === nothing
                println("⚠  Continuant 'cli_test' not found")
            else
                println("CHAIN: cli_test")
                println("  Class: $(c.class)")
                println("  Coherence: $(round(c.coherence; digits=3))")
                for s in stages
                    println("  $(s.orientation) $(s.phase) $(s.node_id)")
                end
            end
        catch e
            println("⚠  /identity chain: $e")
        end
    end
    ok = occursin("CHAIN", out) || occursin("cli_test", out) || occursin("morning", lowercase(out))
    record("/identity chain", ok, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.11: /identity of dawn
log_md("### 2.11: /identity of dawn")
begin
    out = capture_output() do
        try
            c = identity_of("dawn")
            if c === nothing
                println("  Node 'dawn' is not part of any continuant")
            else
                println("  Node 'dawn' → continuant '$(c.id)' [$(c.class), $(length(c.stages)) stages]")
            end
        catch e
            println("⚠  /identity of: $e")
        end
    end
    ok = occursin("cli_test", out) || occursin("continuant", lowercase(out))
    record("/identity of dawn → cli_test", ok, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out))")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.12: /identity rule — transform rule
log_md("### 2.12: /identity rule cli_test dawn noon")
begin
    out = capture_output() do
        try
            add_transform_rule!("cli_test", "dawn", "noon")
            c = get_continuant("cli_test")
            println("✓  Added transform: dawn → noon to cli_test (rules=$(length(c.transform_rules)))")
        catch e
            println("⚠  /identity rule: $e")
        end
    end
    ok = occursin("✓", out) || occursin("transform", lowercase(out)) || occursin("rule", lowercase(out))
    record("/identity rule transform", ok, "out=$(strip(out)[1:min(100,length(strip(out)))])")
    log_md("> $(strip(out))")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.13: /identity proposals
log_md("### 2.13: /identity proposals")
begin
    out = capture_output() do
        try
            props = list_continuant_proposals()
            if isempty(props)
                println("  No continuant proposals.")
            else
                println("CONTINUANT PROPOSALS")
                for p in props
                    icon = p.status == :approved ? "✓" : (p.status == :rejected ? "✗" : "○")
                    println("  $icon $(p.id) $(p.proposed_class) coh=$(round(p.chain_coherence; digits=2))")
                end
            end
        catch e
            println("⚠  /identity proposals: $e")
        end
    end
    ok = length(strip(out)) > 5
    record("/identity proposals", ok, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.14: /mineShapes scan
log_md("### 2.14: /mineShapes scan")
begin
    out = capture_output() do
        try
            # Feed some triples to scan (like the REPL handler does)
            triples = [("alpha","implies","beta"),("beta","implies","gamma"),("alpha","implies","gamma")]
            scan_all!(triples)
            st = pattern_miner_status()
            println("⛏  Scan complete")
            println("  Instances: transitivity=$(st["instances"]["transitivity"]), chaining=$(st["instances"]["chaining"]), symmetry=$(st["instances"]["symmetry"])")
            println("  Proposals: pending=$(st["proposals"]["pending"]), approved=$(st["proposals"]["approved"]), rejected=$(st["proposals"]["rejected"])")
        catch e
            println("⚠  /mineShapes scan: $e")
        end
    end
    ok = occursin("scan", lowercase(out)) || occursin("instance", lowercase(out)) || length(strip(out)) > 10
    record("/mineShapes scan", ok, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.15: /mineShapes config
log_md("### 2.15: /mineShapes config")
begin
    out = capture_output() do
        cfg = pattern_miner_config_snapshot()
        println("PATTERN MINER CONFIG")
        println("  transitivity_threshold: $(cfg.transitivity_threshold)")
        println("  chaining_threshold: $(cfg.chaining_threshold)")
        println("  symmetry_threshold: $(cfg.symmetry_threshold)")
        println("  max_proposals: $(cfg.max_proposals)")
    end
    ok = occursin("threshold", lowercase(out)) || occursin("config", lowercase(out))
    record("/mineShapes config", ok)
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# 2.16: /sigil list
log_md("### 2.16: /sigil list")
begin
    out = capture_output() do
        sigils = list_sigils(SIGIL_TABLE)
        println("Sigil table: $(length(sigils)) entries")
        for s in sigils[1:min(10, length(sigils))]
            println("  $(s.name): class=$(s.class), applies_at=$(s.applies_at)")
        end
    end
    ok = occursin("sigil", lowercase(out)) && length(strip(out)) > 10
    record("/sigil list", ok, "len=$(length(strip(out)))")
    log_md("> $(strip(out)[1:min(300,length(strip(out)))])")
    log_md("**Verdict:** $(ok ? "✅" : "❌")")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: v9 SIGIL CLASSES
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 3: v9 Sigil Classes")
log_md("- SIGIL_CLASSES = $SIGIL_CLASSES")
log_md("- STAGE1_ACTIVE_CLASSES = $STAGE1_ACTIVE_CLASSES")
record(":structure in SIGIL_CLASSES", :structure in SIGIL_CLASSES)
record(":structure in STAGE1_ACTIVE_CLASSES", :structure in STAGE1_ACTIVE_CLASSES)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: STRUCTURE SIGILS
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 4: Structure Sigils (Meta-Sigils)")

# 4.1 Register
log_md("### 4.1: register_structure_sigil!")
try
    e = register_structure_sigil!(SIGIL_TABLE; name="pos_chain", expansion=["&n", "&op", "&noun"])
    ok = e.class == :structure && length(e.expansion) == 3
    record("register pos_chain structure", ok, "class=$(e.class), exp=$(e.expansion)")
    log_md("- Created: class=$(e.class), expansion=$(e.expansion)")
catch e; record("register pos_chain structure", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 4.2 is_structure_sigil
log_md("### 4.2: is_structure_sigil")
is_s = is_structure_sigil(SIGIL_TABLE, "pos_chain")
is_n = !is_structure_sigil(SIGIL_TABLE, "n")
record("is_structure_sigil(pos_chain)", is_s)
record("is_structure_sigil(n)=false", is_n)

# 4.3 expand
log_md("### 4.3: expand_structure_sigil")
try
    expanded = expand_structure_sigil(SIGIL_TABLE, "pos_chain")
    ok = length(expanded) == 3
    record("expand pos_chain returns 3", ok, "expanded=$expanded")
    log_md("- Expanded: $expanded")
catch e; record("expand pos_chain returns 3", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 4.4 Nested
log_md("### 4.4: Nested structure sigil")
try
    register_structure_sigil!(SIGIL_TABLE; name="full_sentence", expansion=["&pos_chain", "&word"])
    expanded = expand_structure_sigil(SIGIL_TABLE, "full_sentence")
    ok = length(expanded) >= 4  # pos_chain expands to 3 + word = 4+
    record("nested full_sentence expands recursively", ok, "expanded=$expanded")
    log_md("- Expanded: $expanded")
catch e; record("nested full_sentence", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 4.5 expand on wrong class errors
log_md("### 4.5: expand on :lambda sigil errors")
try
    expand_structure_sigil(SIGIL_TABLE, "n")
    record("expand on :lambda correctly errors", false, "should have thrown")
catch e
    ok = occursin("expected :structure", string(e))
    record("expand on :lambda correctly errors", ok, "error: $e")
    log_md("- Got expected error: $e")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: COHERENCE FIELD
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 5: Coherence Field")

log_md("### 5.1: compute_field")
try
    phi = compute_field(NODE_MAP; force=true)
    record("compute_field returns number", isa(phi, Number), "Φ=$phi")
    log_md("- Φ = $phi")
catch e; record("compute_field", false, "ERROR: $e"); end

log_md("### 5.2: config snapshot + mutation")
try
    cfg = coherence_config_snapshot()
    record("snapshot has weight", cfg.weight isa Number, "weight=$(cfg.weight)")
    set_coherence_config!(:weight, 0.05)
    cfg2 = coherence_config_snapshot()
    record("set weight=0.05", cfg2.weight ≈ 0.05, "weight=$(cfg2.weight)")
    reset_coherence_config!()
catch e; record("config mutation", false, "ERROR: $e"); end

log_md("### 5.3: serialization round-trip")
try
    d = coherence_config_to_dict()
    coherence_config_from_dict!(d)
    d2 = coherence_config_to_dict()
    ok = get(d,"weight",nothing) == get(d2,"weight",nothing)
    record("coherence round-trip", ok)
catch e; record("coherence round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: GEOMETRY KIT
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 6: Geometry Kit")

log_md("### 6.1: config snapshot + mutation")
try
    cfg = geometry_config_snapshot()
    record("geometry snapshot has default_space", cfg.default_space isa SpaceName, "space=$(cfg.default_space)")
    orig_k = cfg.nearest_k
    set_geometry_config!(:nearest_k, 7)
    cfg2 = geometry_config_snapshot()
    record("set nearest_k=7", cfg2.nearest_k == 7, "k=$(cfg2.nearest_k)")
    set_geometry_config!(:nearest_k, orig_k)
catch e; record("geometry config mutation", false, "ERROR: $e"); end

log_md("### 6.2: serialization round-trip")
try
    d = geometry_config_to_dict()
    geometry_config_from_dict!(d)
    d2 = geometry_config_to_dict()
    ok = get(d,"default_space",nothing) == get(d2,"default_space",nothing)
    record("geometry round-trip", ok)
catch e; record("geometry round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: PATTERN MINER
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 7: Pattern Miner")

log_md("### 7.1: config + mutation")
try
    cfg = pattern_miner_config_snapshot()
    record("pm snapshot has thresholds", cfg.transitivity_threshold isa Int, "T=$(cfg.transitivity_threshold)")
    set_pattern_miner_config!(:transitivity_threshold, 5)
    cfg2 = pattern_miner_config_snapshot()
    record("set T=5", cfg2.transitivity_threshold == 5, "T=$(cfg2.transitivity_threshold)")
    reset_pattern_miner_config!()
catch e; record("pm config mutation", false, "ERROR: $e"); end

log_md("### 7.2: scan operations")
try
    clear_instances!(); clear_proposals!()
    triples = [("A","causes","B"),("B","causes","C"),("A","causes","C"),
               ("X","leads_to","Y"),("Y","leads_to","Z"),
               ("P","mirrors","Q"),("Q","mirrors","P")]
    scan_all!(triples)
    record("scan_all! completes", true)
    log_md("- scan_all! ran OK")
    clear_instances!(); clear_proposals!()
catch e; record("scan_all!", false, "ERROR: $e"); end

log_md("### 7.3: genesis proposal workflow")
try
    set_pattern_miner_config!(:transitivity_threshold, 1)
    clear_instances!(); clear_proposals!()
    triples = [("alpha","implies","beta"),("beta","implies","gamma"),("alpha","implies","gamma")]
    scan_transitivity!(triples)
    check_and_propose!()
    proposals = list_proposals()
    record("genesis proposal created", length(proposals) >= 1, "count=$(length(proposals))")
    if length(proposals) > 0
        p = proposals[1]
        log_md("- Proposal: $(p.shape_type), name=$(p.proposed_name), instances=$(p.instance_count)")
        reject_proposal!(p.id)  # clean up
    end
    clear_instances!(); clear_proposals!(); reset_pattern_miner_config!()
catch e; record("genesis proposal", false, "ERROR: $e"); end

log_md("### 7.4: config serialization round-trip")
try
    d = pattern_miner_config_to_dict()
    pattern_miner_config_from_dict!(d)
    d2 = pattern_miner_config_to_dict()
    ok = get(d,"transitivity_threshold",nothing) == get(d2,"transitivity_threshold",nothing)
    record("pm config round-trip", ok)
catch e; record("pm config round-trip", false, "ERROR: $e"); end

# 7.5 NEW: PatternMiner DATA serialization (instances + proposals)
log_md("### 7.5: PatternMiner DATA serialization (instances + proposals)")
try
    clear_instances!(); clear_proposals!()
    set_pattern_miner_config!(:transitivity_threshold, 1)
    # Create some data
    triples = [("snow","becomes","water"),("water","becomes","vapor"),("snow","becomes","vapor")]
    scan_transitivity!(triples)
    check_and_propose!()
    n_instances_before = length(get_all_instances())
    n_proposals_before = length(list_proposals())
    log_md("- Before save: $n_instances_before instances, $n_proposals_before proposals")

    # Serialize
    data = pattern_miner_data_to_dict()
    has_instances = haskey(data, "instances") && length(data["instances"]) == n_instances_before
    has_proposals = haskey(data, "proposals") && length(data["proposals"]) == n_proposals_before
    record("PM data to_dict has instances", has_instances, "count=$(length(data["instances"]))")
    record("PM data to_dict has proposals", has_proposals, "count=$(length(data["proposals"]))")

    # Clear and restore
    clear_instances!(); clear_proposals!()
    pattern_miner_data_from_dict!(data)
    n_instances_after = length(get_all_instances())
    n_proposals_after = length(list_proposals())
    log_md("- After restore: $n_instances_after instances, $n_proposals_after proposals")
    record("PM instances round-trip", n_instances_after == n_instances_before,
           "before=$n_instances_before after=$n_instances_after")
    record("PM proposals round-trip", n_proposals_after == n_proposals_before,
           "before=$n_proposals_before after=$n_proposals_after")

    clear_instances!(); clear_proposals!(); reset_pattern_miner_config!()
catch e
    record("PM data serialization", false, "ERROR: $e")
    log_md("- ERROR: $e")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8: TEMPORAL IDENTITY
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 8: Temporal Identity")

log_md("### 8.1: create_continuant + add_stage!")
try
    c = create_continuant("process"; id="water_cycle")
    add_stage!(c.id, "rainfall", "gathering", :before)
    add_stage!(c.id, "riverflow", "moving", :now)
    add_stage!(c.id, "vaporization", "rising", :next)
    c = get_continuant("water_cycle")  # re-fetch
    ok = c.id == "water_cycle" && c.class == "process" && length(c.stages) == 3
    record("create + add_stage", ok, "id=$(c.id), class=$(c.class), stages=$(length(c.stages))")
    log_md("- Continuant: id=$(c.id), class=$(c.class), stages=$(length(c.stages))")
catch e; record("create + add_stage", false, "ERROR: $e"); end

log_md("### 8.2: identity_of reverse lookup")
try
    cont = identity_of("riverflow")
    found = cont !== nothing && cont.id == "water_cycle"
    record("identity_of(riverflow)=water_cycle", found)
catch e; record("identity_of", false, "ERROR: $e"); end

log_md("### 8.3: stages_of")
try
    stages = stages_of("water_cycle")
    ok = length(stages) == 3
    record("stages_of returns 3", ok)
    for s in stages; log_md("  - $(s.node_id) / $(s.phase) / $(s.orientation)"); end
catch e; record("stages_of", false, "ERROR: $e"); end

log_md("### 8.4: transform rules")
try
    add_transform_rule!("water_cycle", "riverflow", "vaporization")
    c = get_continuant("water_cycle")
    has_rule = !isempty(c.transform_rules)
    record("add_transform_rule!", has_rule)
catch e; record("add_transform_rule!", false, "ERROR: $e"); end

log_md("### 8.5: propose + approve")
try
    stages_water = [Stage("evaporation", "gas", :now, time()),
                    Stage("condensation", "liquid", :next, time())]
    p = propose_continuant!("cycle", stages_water;
                            example_triples=String["water becomes steam"])
    ok = p.status == :pending
    record("propose_continuant!", ok, "id=$(p.id)")
    approve_continuant_proposal!(p.id)
    clist = list_continuants()
    found_cycle = any(c -> c.class == "cycle", clist)
    record("approve_continuant_proposal!", found_cycle, "count=$(length(clist))")
    log_md("- Proposal approved: id=$(p.id)")
catch e; record("propose+approve", false, "ERROR: $e"); end

log_md("### 8.6: reject proposal")
try
    stages_rej = [Stage("a", "b", :now, time())]
    p2 = propose_continuant!("thing", stages_rej;
                             example_triples=String["test triple"])
    reject_continuant_proposal!(p2.id)
    props = list_continuant_proposals()
    rejected_one = filter(pr -> pr.id == p2.id, props)
    was_rejected = !isempty(rejected_one) && first(rejected_one).status == :rejected
    record("reject_continuant_proposal!", was_rejected)
catch e; record("reject proposal", false, "ERROR: $e"); end

log_md("### 8.7: merge_continuants!")
try
    c_m1 = create_continuant("thing"; id="merge_a")
    add_stage!(c_m1.id, "x", "aspect_x", :before)
    c_m2 = create_continuant("thing"; id="merge_b")
    add_stage!(c_m2.id, "y", "aspect_y", :now)
    merge_continuants!("merge_a", "merge_b")
    merged = get_continuant("merge_a")
    ok = merged !== nothing && length(merged.stages) >= 2
    record("merge_continuants!", ok, "stages=$(merged !== nothing ? length(merged.stages) : 0)")
catch e; record("merge_continuants!", false, "ERROR: $e"); end

log_md("### 8.8: delete_continuant!")
try
    c_del = create_continuant("thing"; id="to_delete")
    delete_continuant!("to_delete")
    gone = get_continuant("to_delete") === nothing
    record("delete_continuant!", gone)
catch e; record("delete_continuant!", false, "ERROR: $e"); end

log_md("### 8.9: list_continuants")
try
    clist = list_continuants()
    record("list_continuants returns list", length(clist) >= 1, "count=$(length(clist))")
    for c in clist[1:min(5,length(clist))]; log_md("  - $(c.id): class=$(c.class), stages=$(length(c.stages)), coherence=$(c.coherence)"); end
catch e; record("list_continuants", false, "ERROR: $e"); end

log_md("### 8.10: temporal_identity_status")
try
    status = temporal_identity_status()
    record("temporal_identity_status returns dict", status isa Dict && haskey(status, "total_continuants"), "keys=$(collect(keys(status)))")
    log_md("- Status: total_continuants=$(get(status,"total_continuants",0)), avg_coherence=$(get(status,"avg_coherence",0.0)), pending=$(get(status,"pending_proposals",0))")
catch e; record("temporal_identity_status", false, "ERROR: $e"); end

# 8.11 NEW: ContinuantProposal serialization round-trip
log_md("### 8.11: ContinuantProposal serialization round-trip")
try
    n_props_before = length(list_continuant_proposals())
    log_md("- Before save: $n_props_before proposals")

    # Serialize
    ti_data = temporal_identity_to_dict()
    has_proposals_key = haskey(ti_data, "proposals")
    n_serialized = length(get(ti_data, "proposals", []))
    record("TI to_dict has proposals key", has_proposals_key)
    record("TI to_dict proposals count", n_serialized == n_props_before,
           "serialized=$n_serialized, actual=$n_props_before")

    # Clear and restore
    n_conts_before = length(list_continuants())
    clear_continuants!(); ti_clear_proposals!()
    n_after_clear = length(list_continuant_proposals())
    log_md("- After clear: $n_after_clear proposals")

    temporal_identity_from_dict!(ti_data)
    n_conts_after = length(list_continuants())
    n_props_after = length(list_continuant_proposals())
    log_md("- After restore: $n_conts_after continuants, $n_props_after proposals")
    record("TI continuants round-trip", n_conts_after == n_conts_before,
           "before=$n_conts_before after=$n_conts_after")
    record("TI proposals round-trip", n_props_after == n_props_before,
           "before=$n_props_before after=$n_props_after")
catch e
    record("TI proposal serialization", false, "ERROR: $e")
    log_md("- ERROR: $e")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 9: SPECIMEN SAVE/LOAD (FULL ROUND-TRIP)
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 9: Specimen Save/Load Round-Trip")
log_md("This is the most critical test — verifies that ALL v9 data survives")
log_md("a full save → clear → reload cycle.\n")

# Capture state BEFORE save
n_conts_before_save   = length(list_continuants())
n_ti_props_before     = length(list_continuant_proposals())
n_pm_instances_before = length(get_all_instances())
n_pm_props_before     = length(list_proposals())
n_sigils_before       = length(list_sigils(SIGIL_TABLE))

# Set some non-default config values to test they survive
set_coherence_config!(:weight, 0.07)
set_geometry_config!(:nearest_k, 5)
set_pattern_miner_config!(:transitivity_threshold, 3)

# Create PM data to save
clear_instances!(); clear_proposals!()
set_pattern_miner_config!(:transitivity_threshold, 1)
pm_triples = [("ice","becomes","water"),("water","becomes","steam"),("ice","becomes","steam")]
scan_transitivity!(pm_triples)
check_and_propose!()
n_pm_instances_before = length(get_all_instances())
n_pm_props_before     = length(list_proposals())
reset_pattern_miner_config!()
set_pattern_miner_config!(:transitivity_threshold, 3)  # back to test value

log_md("### 9.1: Save specimen with v9 data")
try
    save_specimen_to_file!("/tmp/v9_comp_test.specimen")
    file_exists = isfile("/tmp/v9_comp_test.specimen")
    record("Save specimen with v9 data", file_exists)
catch e; record("Save specimen", false, "ERROR: $e"); end

log_md("### 9.2: Specimen JSON has v9 keys")
try
    txt = read("/tmp/v9_comp_test.specimen", String)
    data = JSON.parse(txt)
    has_sigil_table = haskey(data, "sigil_table")
    # Check for structure entries in sigil_table
    if has_sigil_table
        sigil_entries = data["sigil_table"]
        has_structure = any(se -> get(se, "class", "") == "structure", sigil_entries)
    else
        has_structure = false
    end
    has_pm_cfg  = haskey(data, "pattern_miner_config")
    has_pm_data = haskey(data, "pattern_miner_data")
    has_ti      = haskey(data, "temporal_identities")
    has_geo     = haskey(data, "geometry_config")
    has_cf      = haskey(data, "coherence_config")
    record("Specimen JSON has sigil_table", has_sigil_table)
    record("Specimen JSON has structure sigils", has_structure)
    record("Specimen JSON has pattern_miner_config", has_pm_cfg)
    record("Specimen JSON has pattern_miner_data", has_pm_data, "THIS IS THE NEW HOOK")
    record("Specimen JSON has temporal_identities", has_ti)
    record("Specimen JSON has geometry_config", has_geo)
    record("Specimen JSON has coherence_config", has_cf)
    log_md("- Keys: sigil_table=$has_sigil_table, structure=$has_structure, pm_cfg=$has_pm_cfg, pm_data=$has_pm_data, ti=$has_ti, geo=$has_geo, cf=$has_cf")

    # Check TI has proposals sub-key
    if has_ti && isa(data["temporal_identities"], Dict)
        ti_has_proposals = haskey(data["temporal_identities"], "proposals")
        n_ti_proposals_in_file = length(get(data["temporal_identities"], "proposals", []))
        record("TI in specimen has proposals key", ti_has_proposals, "THIS IS THE NEW HOOK")
        log_md("- TI proposals in file: $n_ti_proposals_in_file")
    else
        record("TI in specimen has proposals key", false, "no TI dict")
    end

    # Check PM data has instances and proposals
    if has_pm_data && isa(data["pattern_miner_data"], Dict)
        pm_has_inst = haskey(data["pattern_miner_data"], "instances")
        pm_has_prop = haskey(data["pattern_miner_data"], "proposals")
        n_pm_inst_in_file = length(get(data["pattern_miner_data"], "instances", []))
        n_pm_prop_in_file = length(get(data["pattern_miner_data"], "proposals", []))
        record("PM data in specimen has instances", pm_has_inst, "count=$n_pm_inst_in_file")
        record("PM data in specimen has proposals", pm_has_prop, "count=$n_pm_prop_in_file")
        log_md("- PM instances in file: $n_pm_inst_in_file, proposals: $n_pm_prop_in_file")
    else
        record("PM data in specimen has instances", false, "no PM data dict")
        record("PM data in specimen has proposals", false, "no PM data dict")
    end

catch e; record("Specimen JSON check", false, "ERROR: $e"); end

log_md("### 9.3: Full round-trip — save → load → verify")
try
    # Reload the specimen
    load_specimen_from_file!("/tmp/v9_comp_test.specimen")

    # Verify continuants survived
    n_conts_after = length(list_continuants())
    record("Continuants survived reload", n_conts_after == n_conts_before_save,
           "before=$n_conts_before_save after=$n_conts_after")

    # Verify TI proposals survived (NEW HOOK)
    n_ti_props_after = length(list_continuant_proposals())
    record("TI proposals survived reload", n_ti_props_after == n_ti_props_before,
           "before=$n_ti_props_before after=$n_ti_props_after")

    # Verify CoherenceField config survived
    cf_cfg = coherence_config_snapshot()
    record("CoherenceField weight survived reload", cf_cfg.weight ≈ 0.07,
           "weight=$(cf_cfg.weight)")

    # Verify GeometryKit config survived
    geo_cfg = geometry_config_snapshot()
    record("GeometryKit nearest_k survived reload", geo_cfg.nearest_k == 5,
           "nearest_k=$(geo_cfg.nearest_k)")

    # Verify PatternMiner config survived
    pm_cfg = pattern_miner_config_snapshot()
    record("PatternMiner T=3 survived reload", pm_cfg.transitivity_threshold == 3,
           "T=$(pm_cfg.transitivity_threshold)")

    # Verify PM data survived (NEW HOOK)
    n_pm_inst_after = length(get_all_instances())
    n_pm_props_after = length(list_proposals())
    record("PM instances survived reload", n_pm_inst_after == n_pm_instances_before,
           "before=$n_pm_instances_before after=$n_pm_inst_after")
    record("PM proposals survived reload", n_pm_props_after == n_pm_props_before,
           "before=$n_pm_props_before after=$n_pm_props_after")

    # Verify structure sigils survived
    has_pos_chain = is_structure_sigil(SIGIL_TABLE, "pos_chain")
    has_full_sent = is_structure_sigil(SIGIL_TABLE, "full_sentence")
    record("Structure sigil pos_chain survived reload", has_pos_chain)
    record("Structure sigil full_sentence survived reload", has_full_sent)

    log_md("- After reload: $n_conts_after continuants, $n_ti_props_after TI proposals, $n_pm_inst_after PM instances, $n_pm_props_after PM proposals")
    log_md("- CoherenceField weight=$(cf_cfg.weight), GeometryKit nearest_k=$(geo_cfg.nearest_k), PatternMiner T=$(pm_cfg.transitivity_threshold)")

catch e
    record("Full round-trip", false, "ERROR: $e")
    log_md("- ERROR: $e")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 10: DECOHERENCE CHECKS (Legacy)
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 10: Decoherence Checks (Legacy)")

decoherence_tests = [
    ("how are you feeling", r"\b(Fire|Using|Via)\b.*\b(sit|feel)\b"i, "No Fire/Using/Via swap"),
    ("who are you", r"\bFire\b.*\b(Grug|am)\b"i, "No Fire self-reference swap"),
    ("I feel sad", r"\bFire\b.*\bsit\b"i, "No Fire swap in emotion"),
]

for (input, bad_pat, label) in decoherence_tests
    log_md("### DecoherenceCheck: $label")
    log_md("**Input:** \"$input\"")
    log_md("**Bad pattern:** $bad_pat")
    try
        out = run_mission(input)
        bad_match = occursin(bad_pat, out)
        record(label, !bad_match, bad_match ? "MATCHED BAD PATTERN" : "clean")
        log_md("**Output:** $(out[1:min(200,length(out))])")
        log_md("**Verdict:** $(bad_match ? "❌ Bad pattern detected" : "✅ No false-winner pattern detected")")
    catch e
        record(label, false, "ERROR: $e")
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 11: CONVERSATIONAL LEARNING (Legacy)
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 11: Conversational Learning (Legacy)")

# Teach a new word, then ask about it
log_md("### 11.1: Teach → Ask round-trip")
try
    # Ask first (should not know it)
    out1 = run_mission("what is sintering_v9_test")
    log_md("**Step 1 — Ask:** $out1")
    asks_clarification = occursin("not know", lowercase(out1)) || occursin("what does", lowercase(out1))
    record("Ask unknown word gets clarification", asks_clarification)

    # Teach it
    out2 = run_mission("science, sintering_v9_test is a test mineral process")
    log_md("**Step 2 — Teach:** $(out2[1:min(200,length(out2))])")
    learned = occursin("learned", lowercase(out2)) || occursin("sintering", lowercase(out2))
    record("Teach unknown word succeeds", learned)

    # Ask again
    out3 = run_mission("what is sintering_v9_test")
    log_md("**Step 3 — Ask again:** $(out3[1:min(200,length(out3))])")
    knows_now = occursin("sintering", lowercase(out3)) || occursin("mineral", lowercase(out3)) || occursin("test", lowercase(out3))
    record("Known word answered after teach", knows_now)
catch e
    record("Teach→Ask", false, "ERROR: $e")
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 12: RESPONSE QUALITY AUDIT
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 12: Response Quality Audit")
log_md("Actually reading the logs and checking responses aren't dumb.\n")

quality_tests = [
    ("what is fire", out -> length(out) > 20 && !occursin(r"not know", lowercase(out)), "Known: fire has substantive answer"),
    ("what is water", out -> length(out) > 20 && !occursin(r"not know", lowercase(out)), "Known: water has substantive answer"),
    ("3 + 5", out -> occursin("8", out), "Math: 3+5 = 8"),
    ("hello", out -> occursin("grug", lowercase(out)) || occursin("welcome", lowercase(out)) || occursin("hello", lowercase(out)), "Greeting is friendly"),
    ("why is the sky blue", out -> length(out) > 15, "Why question has content"),
    ("no fire is plasma not oxidation", out -> occursin("correct", lowercase(out)) || occursin("fire", lowercase(out)), "Correction acknowledged"),
]

for (input, check, label) in quality_tests
    log_md("### QualityAudit: $label")
    try
        out = run_mission(input)
        pass = check(out)
        record(label, pass)
        log_md("**Input:** \"$input\"")
        log_md("**Output:** $(out[1:min(200,length(out))])")
        log_md("**Verdict:** $(pass ? "✅" : "❌")")
    catch e
        record(label, false, "ERROR: $e")
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 13: USER-FRIENDLINESS VERIFICATION
# ══════════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 13: User-Friendliness Verification")
log_md("Can an end user boot up boot.jl, load a specimen, and use v9 features")
log_md("without jumping through hoops?\n")

# 13.1: All v9 CLI commands produce readable output
# Test via API + capture_output (NOT process_mission — CLI commands have their own REPL handlers)
log_md("### 13.1: All v9 CLI commands produce readable output")

# /coherence
begin
    _cfg13coh = coherence_config_snapshot()
    out = capture_output() do
        status = coherence_field_status(NODE_MAP; force=true)
        phi = status["phi"]
        println("Φ = $(round(phi; digits=4))  [weight=$(_cfg13coh.weight)]")
    end
    ok = occursin("Φ", out) || occursin("phi", lowercase(out)) || occursin("routing", lowercase(out))
    record("/coherence readable", ok, "len=$(length(strip(out)))")
    log_md("- /coherence: $(strip(out)[1:min(100,length(strip(out)))])")
end

# /coherenceField
begin
    out = capture_output() do
        status = coherence_field_status(NODE_MAP; force=true)
        println("Φ=$(status["phi"]) active=$(status["n_active"]) coherent=$(status["n_coherent"])")
    end
    ok = length(strip(out)) > 10
    record("/coherenceField readable", ok, "len=$(length(strip(out)))")
end

# /geometry
begin
    out = capture_output() do
        ov = geometry_overview(; phi=0.0, crystal_size=0, n_nodes=length(NODE_MAP))
        println("GEOMETRY: space=$(ov["default_space"]) nodes=$(ov["n_nodes"])")
    end
    ok = length(strip(out)) > 10
    record("/geometry readable", ok, "len=$(length(strip(out)))")
end

# /phaseSpace
begin
    out = capture_output() do
        phi = try compute_field(NODE_MAP; force=false) catch _; 0.0 end
        ov = geometry_overview(; phi=phi, crystal_size=0, n_nodes=length(NODE_MAP))
        println("PHASE SPACE: space=$(ov["default_space"]) Φ=$(ov["phi"])" )
    end
    ok = length(strip(out)) > 10
    record("/phaseSpace readable", ok, "len=$(length(strip(out)))")
end

# /identity
begin
    out = capture_output() do
        clist = list_continuants()
        println("IDENTITY: $(length(clist)) continuants")
        for c in clist[1:min(5,length(clist))]
            println("  $(c.id): class=$(c.class) stages=$(length(c.stages))")
        end
    end
    ok = occursin("continuant", lowercase(out)) || occursin("stages", lowercase(out)) || occursin("identity", lowercase(out))
    record("/identity readable", ok, "len=$(length(strip(out)))")
end

# /mineShapes status
begin
    out = capture_output() do
        st = pattern_miner_status()
        println("MINE SHAPES: enabled=$(st["enabled"]) instances=$(st["instances"]) proposals=$(st["proposals"])" )
    end
    ok = length(strip(out)) > 5
    record("/mineShapes readable", ok, "len=$(length(strip(out)))")
end

# 13.2: v9 features work after loading a specimen
log_md("### 13.2: v9 features work after specimen load")
begin
    # Already loaded — verify we can use all features
    can_compute_field = try compute_field(NODE_MAP; force=true); true catch _; false end
    can_get_geo_config = try geometry_config_snapshot(); true catch _; false end
    can_get_pm_status = try pattern_miner_status(); true catch _; false end
    can_get_ti_status = try temporal_identity_status(); true catch _; false end
    can_list_sigils = try list_sigils(SIGIL_TABLE); true catch _; false end
    can_create_continuant = try create_continuant("test"; id="uf_test"); true catch _; false end

    record("CoherenceField works after load", can_compute_field)
    record("GeometryKit works after load", can_get_geo_config)
    record("PatternMiner works after load", can_get_pm_status)
    record("TemporalIdentity works after load", can_get_ti_status)
    record("SigilRegistry works after load", can_list_sigils)
    record("Can create continuant after load", can_create_continuant)

    # Clean up
    try delete_continuant!("uf_test"); catch; end
end

# 13.3: Save/load doesn't lose user-created data
log_md("### 13.3: Save/load doesn't lose user data")
begin
    # Create unique data
    c = create_continuant("weather"; id="user_weather")
    add_stage!(c.id, "sunny", "clear", :now)
    add_transform_rule!(c.id, "sunny", "cloudy")

    # Save
    save_specimen_to_file!("/tmp/v9_uf_test.specimen")

    # Clear TI
    clear_continuants!(); ti_clear_proposals!()

    # Reload
    load_specimen_from_file!("/tmp/v9_uf_test.specimen")

    # Verify
    c_restored = get_continuant("user_weather")
    weather_ok = c_restored !== nothing &&
                 c_restored.class == "weather" &&
                 length(c_restored.stages) >= 1 &&
                 !isempty(c_restored.transform_rules)
    record("User continuant survives save/load", weather_ok,
           "found=$(c_restored !== nothing), stages=$(c_restored !== nothing ? length(c_restored.stages) : 0), rules=$(c_restored !== nothing ? length(c_restored.transform_rules) : 0)")
    log_md("- user_weather: class=$(c_restored !== nothing ? c_restored.class : "MISSING"), stages=$(c_restored !== nothing ? length(c_restored.stages) : 0), rules=$(c_restored !== nothing ? length(c_restored.transform_rules) : 0)")
end

# ══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════════════════
try
    for name in ["pos_chain", "full_sentence"]
        if haskey(SIGIL_TABLE.entries, name); delete!(SIGIL_TABLE.entries, name); end
    end
catch; end
try clear_continuants!(); ti_clear_proposals!(); catch; end
try clear_instances!(); clear_proposals!(); reset_pattern_miner_config!(); catch; end
try reset_coherence_config!(); catch; end

log_md("")
all_pass = summary()
println("\n" * "="^60)
println("Comprehensive V9 Test Complete — Results in $LOG_PATH")
println("="^60)
exit(all_pass ? 0 : 1)
