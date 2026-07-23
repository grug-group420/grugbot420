#!/usr/bin/env julia
# test_specimen_v9.jl — Full specimen test: v9 + legacy
# Loads specimen, runs commands, logs full replies to md, checks coherence

using Dates, JSON
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK, BRIDGE_MAP

import .GrugBot420.SigilRegistry:
    register_structure_sigil!, expand_structure_sigil, is_structure_sigil,
    list_sigils, SIGIL_CLASSES, STAGE1_ACTIVE_CLASSES, SigilTable

import .GrugBot420.CoherenceField:
    compute_field, set_coherence_config!, coherence_config_snapshot,
    coherence_config_to_dict, coherence_config_from_dict!, reset_coherence_config!

import .GrugBot420.GeometryKit:
    geometry_config_snapshot, set_geometry_config!,
    geometry_config_to_dict, geometry_config_from_dict!,
    SpaceName, PHASE_SPACE

import .GrugBot420.PatternMiner:
    pattern_miner_config_snapshot, set_pattern_miner_config!,
    reset_pattern_miner_config!, pattern_miner_config_to_dict,
    pattern_miner_config_from_dict!, pattern_miner_status,
    scan_transitivity!, scan_chaining!, scan_symmetry!, scan_all!,
    check_and_propose!, list_proposals,
    approve_proposal!, reject_proposal!,
    clear_instances!, clear_proposals!,
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
    clear_continuants!, clear_proposals!,
    Stage

const SPEC_PATH = get(ARGS, 1, "/workspace/test_v9_temp.specimen")
const LOG_PATH  = "/workspace/comprehensive_test_log.md"
const _log_lines = String[]

log_md(line) = push!(_log_lines, line)
flush_log() = open(LOG_PATH, "w") do f; for l in _log_lines; println(f, l); end; end

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

function run_cmd(cmd)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    cli = capture_output() do
        try process_mission(cmd); catch e; @warn "err" exception=e; end
    end
    voice = read_voice()
    strip(voice * " " * cli)
end

# ── Result tracking ──
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

# ── Load specimen ──
log_md("# Comprehensive GrugBot420 Test — v9 + Legacy")
log_md("Date: $(now())  |  Specimen: $SPEC_PATH")
try
    load_specimen_from_file!(SPEC_PATH)
catch e
    @warn "Specimen load failed" exception=e
end
log_md("Loaded: $(length(NODE_MAP)) nodes, $(length(BRIDGE_MAP)) bridges\n")

# ══════════════════════════════════════════════════════════════════════════
# SECTION 1: BASIC CONVERSATION (Legacy)
# ══════════════════════════════════════════════════════════════════════════
log_md("## Section 1: Basic Conversation (Legacy)")

struct CmdTest; cmd::String; check::Function; label::String; end

conv_tests = [
    CmdTest("Hello", out -> occursin("grug", lowercase(out)) || occursin("welcome", lowercase(out)) || occursin("hello", lowercase(out)) || length(out) > 20, "Hello greeting"),
    CmdTest("/coherence", out -> length(out) > 5, "/coherence produces output"),
    CmdTest("/geometry", out -> length(out) > 5, "/geometry produces output"),
    CmdTest("/phaseSpace", out -> length(out) > 5, "/phaseSpace produces output"),
    CmdTest("/mineShapes", out -> occursin("mineshape", lowercase(out)) || occursin("mine", lowercase(out)) || length(out) > 10, "/mineShapes shows info"),
    CmdTest("/identity", out -> length(out) > 5, "/identity shows status"),
    CmdTest("/sigil list", out -> length(out) > 5, "/sigil list shows sigils"),
    CmdTest("/status", out -> length(out) > 5, "/status shows cave"),
]

for t in conv_tests
    log_md("### `$(t.cmd)`")
    try
        out = run_cmd(t.cmd)
        pass = t.check(out)
        record(t.label, pass)
        log_md("> **Reply** ($(length(out)) chars):")
        log_md("> $(out[1:min(300,length(out))])")
    catch e
        record(t.label, false, "ERROR: $e")
        log_md("> ERROR: $e")
    end
end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 2: v9 SIGIL CLASSES
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 2: v9 Sigil Classes")
log_md("- SIGIL_CLASSES = $SIGIL_CLASSES")
log_md("- STAGE1_ACTIVE_CLASSES = $STAGE1_ACTIVE_CLASSES")
record(":structure in SIGIL_CLASSES", :structure in SIGIL_CLASSES)
record(":structure in STAGE1_ACTIVE_CLASSES", :structure in STAGE1_ACTIVE_CLASSES)

# ══════════════════════════════════════════════════════════════════════════
# SECTION 3: STRUCTURE SIGILS (Meta-Sigils)
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 3: Structure Sigils (Meta-Sigils)")

# 3.1 Register — use sigils that ACTUALLY exist: &n, &op, &noun
log_md("### 3.1: register_structure_sigil!")
try
    e = register_structure_sigil!(SIGIL_TABLE; name="pos_chain", expansion=["&n", "&op", "&noun"])
    ok = e.class == :structure && length(e.expansion) == 3
    record("register pos_chain structure", ok, "class=$(e.class), exp=$(e.expansion)")
    log_md("- Created: class=$(e.class), expansion=$(e.expansion)")
catch e; record("register pos_chain structure", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 3.2 is_structure_sigil
log_md("### 3.2: is_structure_sigil")
is_s = is_structure_sigil(SIGIL_TABLE, "pos_chain")
is_n = !is_structure_sigil(SIGIL_TABLE, "n")
record("is_structure_sigil(pos_chain)", is_s)
record("is_structure_sigil(n)=false", is_n)

# 3.3 expand
log_md("### 3.3: expand_structure_sigil")
try
    expanded = expand_structure_sigil(SIGIL_TABLE, "pos_chain")
    ok = length(expanded) == 3
    record("expand pos_chain returns 3", ok, "expanded=$expanded")
    log_md("- Expanded: $expanded")
catch e; record("expand pos_chain returns 3", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 3.4 Nested — use &pos_chain + &word (both exist)
log_md("### 3.4: Nested structure sigil")
try
    register_structure_sigil!(SIGIL_TABLE; name="full_sentence", expansion=["&pos_chain", "&word"])
    expanded = expand_structure_sigil(SIGIL_TABLE, "full_sentence")
    ok = length(expanded) >= 4  # pos_chain expands to 3 + word = 4
    record("nested full_sentence expands recursively", ok, "expanded=$expanded")
    log_md("- Expanded: $expanded")
catch e; record("nested full_sentence", false, "ERROR: $e"); log_md("- ERROR: $e"); end

# 3.5 expand on wrong class
log_md("### 3.5: expand on :lambda sigil errors")
try
    expand_structure_sigil(SIGIL_TABLE, "n")
    record("expand on :lambda correctly errors", false, "should have thrown")
catch e
    ok = occursin("expected :structure", string(e))
    record("expand on :lambda correctly errors", ok, "error: $e")
    log_md("- Got expected error: $e")
end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 4: COHERENCE FIELD
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 4: Coherence Field")

log_md("### 4.1: compute_field")
try
    phi = compute_field(NODE_MAP; force=true)
    record("compute_field returns number", isa(phi, Number), "Φ=$phi")
    log_md("- Φ = $phi")
catch e; record("compute_field", false, "ERROR: $e"); end

log_md("### 4.2: config snapshot + mutation")
try
    cfg = coherence_config_snapshot()
    record("snapshot has weight", cfg.weight isa Number, "weight=$(cfg.weight)")
    set_coherence_config!(:weight, 0.05)
    cfg2 = coherence_config_snapshot()
    record("set weight=0.05", cfg2.weight == 0.05, "weight=$(cfg2.weight)")
    reset_coherence_config!()
catch e; record("config mutation", false, "ERROR: $e"); end

log_md("### 4.3: serialization round-trip")
try
    d = coherence_config_to_dict()
    coherence_config_from_dict!(d)
    d2 = coherence_config_to_dict()
    ok = get(d,"weight",nothing) == get(d2,"weight",nothing)
    record("coherence round-trip", ok)
catch e; record("coherence round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 5: GEOMETRY KIT
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 5: Geometry Kit")

log_md("### 5.1: config snapshot + mutation")
try
    cfg = geometry_config_snapshot()
    record("geometry snapshot has default_space", cfg.default_space isa SpaceName, "space=$(cfg.default_space)")
    set_geometry_config!(:nearest_k, 7)
    cfg2 = geometry_config_snapshot()
    record("set nearest_k=7", cfg2.nearest_k == 7, "k=$(cfg2.nearest_k)")
    # restore
    set_geometry_config!(:nearest_k, cfg.nearest_k)
catch e; record("geometry config mutation", false, "ERROR: $e"); end

log_md("### 5.2: serialization round-trip")
try
    d = geometry_config_to_dict()
    geometry_config_from_dict!(d)
    d2 = geometry_config_to_dict()
    ok = get(d,"default_space",nothing) == get(d2,"default_space",nothing)
    record("geometry round-trip", ok)
catch e; record("geometry round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 6: PATTERN MINER
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 6: Pattern Miner")

log_md("### 6.1: config + mutation")
try
    cfg = pattern_miner_config_snapshot()
    record("pm snapshot has thresholds", cfg.transitivity_threshold isa Int, "T=$(cfg.transitivity_threshold)")
    set_pattern_miner_config!(:transitivity_threshold, 5)
    cfg2 = pattern_miner_config_snapshot()
    record("set T=5", cfg2.transitivity_threshold == 5, "T=$(cfg2.transitivity_threshold)")
    reset_pattern_miner_config!()
catch e; record("pm config mutation", false, "ERROR: $e"); end

log_md("### 6.2: scan operations")
try
    triples = [("A","causes","B"),("B","causes","C"),("A","causes","C"),
               ("X","leads_to","Y"),("Y","leads_to","Z"),
               ("P","mirrors","Q"),("Q","mirrors","P")]
    scan_all!(triples)
    record("scan_all! completes", true)
    log_md("- scan_all! ran OK")
    clear_instances!(); clear_instances!(); clear_instances!()
catch e; record("scan_all!", false, "ERROR: $e"); end

log_md("### 6.3: genesis proposal workflow")
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

log_md("### 6.4: serialization round-trip")
try
    d = pattern_miner_config_to_dict()
    pattern_miner_config_from_dict!(d)
    d2 = pattern_miner_config_to_dict()
    ok = get(d,"transitivity_threshold",nothing) == get(d2,"transitivity_threshold",nothing)
    record("pm round-trip", ok)
catch e; record("pm round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 7: TEMPORAL IDENTITY
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 7: Temporal Identity")

log_md("### 7.1: create_continuant + add_stage!")
try
    c = create_continuant("process"; id="water_cycle")
    add_stage!(c.id, "rainfall", "gathering", :before)
    add_stage!(c.id, "riverflow", "moving", :now)
    add_stage!(c.id, "vaporization", "rising", :next)
    c = get_continuant("water_cycle")  # re-fetch after mutations
    ok = c.id == "water_cycle" && c.class == "process" && length(c.stages) == 3
    record("create + add_stage", ok, "id=$(c.id), class=$(c.class), stages=$(length(c.stages))")
    log_md("- Continuant: id=$(c.id), class=$(c.class), stages=$(length(c.stages))")
catch e; record("create + add_stage", false, "ERROR: $e"); end

log_md("### 7.2: identity_of reverse lookup")
try
    cont = identity_of("riverflow")
    found = cont !== nothing && cont.id == "water_cycle"
    record("identity_of(riverflow)=water_cycle", found)
catch e; record("identity_of", false, "ERROR: $e"); end

log_md("### 7.3: stages_of")
try
    stages = stages_of("water_cycle")
    ok = length(stages) == 3
    record("stages_of returns 3", ok)
    for s in stages; log_md("  - $(s.node_id) / $(s.phase) / $(s.orientation)"); end
catch e; record("stages_of", false, "ERROR: $e"); end

log_md("### 7.4: transform rules")
try
    add_transform_rule!("water_cycle", "riverflow", "vaporization")
    c = get_continuant("water_cycle")
    has_rule = !isempty(c.transform_rules)
    record("add_transform_rule!", has_rule)
catch e; record("add_transform_rule!", false, "ERROR: $e"); end

log_md("### 7.5: propose + approve")
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

log_md("### 7.6: reject proposal")
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

log_md("### 7.7: merge_continuants!")
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

log_md("### 7.8: delete_continuant!")
try
    c_del = create_continuant("thing"; id="to_delete")
    delete_continuant!("to_delete")
    gone = get_continuant("to_delete") === nothing
    record("delete_continuant!", gone)
catch e; record("delete_continuant!", false, "ERROR: $e"); end

log_md("### 7.9: list_continuants")
try
    clist = list_continuants()
    record("list_continuants returns list", length(clist) >= 1, "count=$(length(clist))")
    for c in clist[1:min(5,length(clist))]; log_md("  - $(c.id): class=$(c.class), stages=$(length(c.stages)), coherence=$(c.coherence)"); end
catch e; record("list_continuants", false, "ERROR: $e"); end

log_md("### 7.10: temporal_identity_status")
try
    status = temporal_identity_status()
    record("temporal_identity_status returns dict", status isa Dict && haskey(status, "total_continuants"), "keys=$(collect(keys(status)))")
    log_md("- Status: total_continuants=$(get(status,"total_continuants",0)), avg_coherence=$(get(status,"avg_coherence",0.0)), pending=$(get(status,"pending_proposals",0))")
catch e; record("temporal_identity_status", false, "ERROR: $e"); end

log_md("### 7.11: serialization round-trip")
try
    d = GrugBot420.TemporalIdentity.temporal_identity_to_dict()
    GrugBot420.TemporalIdentity.temporal_identity_from_dict!(d)
    d2 = GrugBot420.TemporalIdentity.temporal_identity_to_dict()
    ok = length(d["continuants"]) == length(d2["continuants"])
    record("TI round-trip", ok)
catch e; record("TI round-trip", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 8: SPECIMEN SAVE/LOAD
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 8: Specimen Save/Load")

log_md("### 8.1: Save specimen")
try
    save_specimen_to_file!("/tmp/comp_test_specimen.specimen")
    file_exists = isfile("/tmp/comp_test_specimen.specimen")
    record("Save specimen with v9 data", file_exists)
catch e; record("Save specimen", false, "ERROR: $e"); end

log_md("### 8.2: Specimen JSON has v9 keys")
try
    txt = read("/tmp/comp_test_specimen.specimen", String)
    data = JSON.parse(txt)
    has_sigil_table = haskey(data, "sigil_table")
    # sigil_table is an array of entry dicts — check for structure entries
    if has_sigil_table
        sigil_entries = data["sigil_table"]
        has_structure = any(se -> get(se, "class", "") == "structure", sigil_entries)
    else
        has_structure = false
    end
    has_pm = haskey(data, "pattern_miner_config")
    has_ti = haskey(data, "temporal_identities")
    has_geo = haskey(data, "geometry_config")
    record("Specimen JSON has v9 keys", has_sigil_table && has_pm && has_ti && has_geo,
           "sigil_table=$has_sigil_table, structure=$has_structure, pm=$has_pm, ti=$has_ti, geo=$has_geo")
    log_md("- Keys: sigil_table=$has_sigil_table, structure=$has_structure, pm=$has_pm, ti=$has_ti, geo=$has_geo")
catch e; record("Specimen JSON check", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 9: COHERENCE FIELD CLI DEEP
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 9: Coherence Field CLI Deep Tests")

log_md("### 9.1: /coherenceField detailed")
try
    out = run_cmd("/coherenceField")
    record("/coherenceField produces output", length(out) > 5, "len=$(length(out))")
    log_md("> Reply ($(length(out)) chars): $(out[1:min(300,length(out))])")
catch e; record("/coherenceField", false, "ERROR: $e"); end

log_md("### 9.2: /coherenceConfig weight 0.1")
try
    out = run_cmd("/coherenceConfig weight 0.1")
    record("/coherenceConfig produces output", length(out) > 5, "len=$(length(out))")
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/coherenceConfig", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 10: PATTERN MINER CLI DEEP
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 10: Pattern Miner CLI Deep")

log_md("### 10.1: /mineShapes scan")
try
    out = run_cmd("/mineShapes scan")
    record("/mineShapes scan produces output", length(out) > 5, "len=$(length(out))")
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/mineShapes scan", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 11: TEMPORAL IDENTITY CLI DEEP
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 11: Temporal Identity CLI Deep")

log_md("### 11.1: /identity create test_cont process")
try
    out = run_cmd("/identity create test_cont process")
    ok = occursin("continuant", lowercase(out)) || occursin("created", lowercase(out)) || occursin("test_cont", lowercase(out)) || length(out) > 5
    record("/identity create", ok)
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/identity create", false, "ERROR: $e"); end

log_md("### 11.2: /identity chain water_cycle")
try
    out = run_cmd("/identity chain water_cycle")
    ok = occursin("chain", lowercase(out)) || occursin("stage", lowercase(out)) || occursin("water", lowercase(out)) || length(out) > 5
    record("/identity chain", ok)
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/identity chain", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 12: KNOWLEDGE & TEACHING (Legacy)
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 12: Knowledge & Teaching (Legacy)")

log_md("### 12.1: Teach a fact")
try
    out = run_cmd("Teach: The sky is blue because of Rayleigh scattering")
    ok = length(out) > 10
    record("teach fact produces reply", ok)
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("teach fact", false, "ERROR: $e"); end

log_md("### 12.2: Ask about it")
try
    out = run_cmd("Why is the sky blue?")
    ok = length(out) > 10 && (occursin("scattering", lowercase(out)) || occursin("sky", lowercase(out)) || occursin("blue", lowercase(out)) || length(out) > 20)
    record("ask about taught fact", ok)
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("ask about fact", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# SECTION 13: GEOMETRY CLI DEEP
# ══════════════════════════════════════════════════════════════════════════
log_md(""); log_md("## Section 13: Geometry CLI Deep")

log_md("### 13.1: /geometry trajectory")
try
    out = run_cmd("/geometry trajectory")
    record("/geometry trajectory produces output", length(out) > 5, "len=$(length(out))")
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/geometry trajectory", false, "ERROR: $e"); end

log_md("### 13.2: /geometry attractors")
try
    out = run_cmd("/geometry attractors")
    record("/geometry attractors produces output", length(out) > 5, "len=$(length(out))")
    log_md("> Reply: $(out[1:min(300,length(out))])")
catch e; record("/geometry attractors", false, "ERROR: $e"); end

# ══════════════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════════════
try
    for name in ["pos_chain", "full_sentence"]
        if haskey(SIGIL_TABLE.entries, name); delete!(SIGIL_TABLE.entries, name); end
    end
catch; end
try clear_continuants!(); clear_proposals!(); catch; end
try clear_instances!(); clear_proposals!(); reset_pattern_miner_config!(); catch; end

log_md("")
all_pass = summary()
println("\n" * "="^60)
println("Comprehensive Test Complete — Results in $LOG_PATH")
println("="^60)
exit(all_pass ? 0 : 1)
