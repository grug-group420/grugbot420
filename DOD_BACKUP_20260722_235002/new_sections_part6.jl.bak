
# ═══════════════════════════════════════════════════════════════
# 34. FULL LOBE SCANNER — Scanner Lifecycle, Active Nodes
# ═══════════════════════════════════════════════════════════════
section("34. Full Lobe Scanner — Lifecycle & Active Nodes")

subsection("34a. Active Node Set Operations")
try
    global _ans = ActiveNodeSet(1000)
    record("ActiveNodeSet(1000) created", _ans !== nothing)
catch e
    record("ActiveNodeSet creation", false, "$e")
end

try
    _ok = activate_node!(_ans, "node_001", 0.8)
    record("activate_node!('node_001') returns true", _ok == true)
catch e
    record("activate_node!", false, "$e")
end

try
    _is_act = is_active(_ans, "node_001")
    record("is_active('node_001') = true", _is_act == true)
catch e
    record("is_active true", false, "$e")
end

try
    _cnt = active_count(_ans)
    record("active_count == 1", _cnt == 1)
catch e
    record("active_count", false, "$e")
end

try
    deactivate_node!(_ans, "node_001")
    _is_act2 = is_active(_ans, "node_001")
    record("deactivate_node! then is_active = false", _is_act2 == false)
catch e
    record("deactivate_node!", false, "$e")
end

try
    clear_active!(_ans)
    _cnt2 = active_count(_ans)
    record("clear_active! then count == 0", _cnt2 == 0)
catch e
    record("clear_active!", false, "$e")
end

try
    _cap = at_capacity(_ans)
    record("at_capacity returns Bool", _cap isa Bool)
catch e
    record("at_capacity", false, "$e")
end

subsection("34b. Scanner Lifecycle")
try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _lobe_id = _lobe_keys[1]
        _lobe_rec = Lobe.LOBE_REGISTRY[_lobe_id]
        _lobe_node_ids = _lobe_rec.node_ids

        if !isempty(_lobe_node_ids)
            global _scanner = LobeScanner(_lobe_id, Set(_lobe_node_ids))
            record("LobeScanner created", _scanner !== nothing)

            _status = scanner_status(_scanner)
            record("scanner_status returns String", _status isa String)
        else
            record("LobeScanner (no nodes in lobe)", true, "skipped")
        end
    else
        record("LobeScanner (no lobes)", true, "skipped")
    end
catch e
    record("LobeScanner creation", false, "$e")
end

try
    _phase = phase_name(PHASE_INIT)
    record("phase_name(PHASE_INIT) returns String", _phase isa String)
catch e
    record("phase_name", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 35. TEMPORAL GROWTH — Growth Automaton
# ═══════════════════════════════════════════════════════════════
section("35. Temporal Growth — Automaton & Log")

subsection("35a. Growth Automaton Run")
try
    run_growth_automaton!(;
        lobe_registry=Lobe.LOBE_REGISTRY,
        group_map=GrugBot420.AutoGrowth.GROUP_EVIDENCE,
        node_map=NODE_MAP, node_lock=NODE_LOCK)
    record("run_growth_automaton! runs without error", true)
catch e
    record("run_growth_automaton!", false, "$e")
end

subsection("35b. Growth Log")
try
    _gl = get_growth_log()
    record("get_growth_log (AutoGrowth) returns Vector", _gl isa Vector)
catch e
    record("get_growth_log (AutoGrowth)", false, "$e")
end

try
    _tgl = GrugBot420.TemporalGrowth.get_growth_log()
    record("get_growth_log (TemporalGrowth) returns Vector", _tgl isa Vector)
catch e
    record("get_growth_log (TemporalGrowth)", false, "$e")
end
