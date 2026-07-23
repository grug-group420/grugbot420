
# ═══════════════════════════════════════════════════════════════
# 36. CHATTER RESIDUALS — Ledger, Status, Serialization
# ═══════════════════════════════════════════════════════════════
section("36. Chatter Residuals — Ledger & Status")

subsection("36a. Ledger Operations")
try
    _rls = residual_ledger_size()
    record("residual_ledger_size returns Int", _rls isa Int)
catch e
    record("residual_ledger_size", false, "$e")
end

try
    _test_hash = hash(("test_session", "test_node", "test_donor"))
    _ic1 = is_consumed(_test_hash)
    record("is_consumed returns Bool", _ic1 isa Bool)
    mark_consumed!(_test_hash)
    _ic2 = is_consumed(_test_hash)
    record("mark_consumed! then is_consumed = true", _ic2 == true)
catch e
    record("is_consumed / mark_consumed!", false, "$e")
end

subsection("36b. Status & Serialization")
try
    _crs = get_chatter_residuals_status()
    record("get_chatter_residuals_status returns String", _crs isa String)
catch e
    record("get_chatter_residuals_status", false, "$e")
end

try
    _crd = serialize_chatter_residuals()
    record("serialize_chatter_residuals returns Dict", _crd isa Dict)
catch e
    record("serialize_chatter_residuals", false, "$e")
end

try
    reset_chatter_residuals!()
    record("reset_chatter_residuals! runs", true)
catch e
    record("reset_chatter_residuals!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 37. LOBE TABLE — Chunk Operations, Put/Get, Drop Tables
# ═══════════════════════════════════════════════════════════════
section("37. Lobe Table — Chunks, Put/Get & Drop Tables")

subsection("37a. Create Table & Basic Ops")
try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _tbl_lobe = _lobe_keys[1]
        _tbl = create_lobe_table!(_tbl_lobe)
        record("create_lobe_table! returns LobeTableRecord", _tbl !== nothing)
    else
        record("create_lobe_table! (no lobes)", true, "skipped")
    end
catch e
    record("create_lobe_table!", false, "$e")
end

subsection("37b. Table Put / Get / Has")
try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _tbl_lobe = _lobe_keys[1]
        create_lobe_table!(_tbl_lobe)
        table_put!(_tbl_lobe, "json", "test_key", Dict{String,Any}("value" => 42))
        _got = table_get(_tbl_lobe, "json", "test_key")
        record("table_put! then table_get returns value", _got !== nothing)
        _has = table_has(_tbl_lobe, "json", "test_key")
        record("table_has returns true", _has == true)
    else
        record("table put/get (no lobes)", true, "skipped")
    end
catch e
    record("table put/get", false, "$e")
end

subsection("37c. Table Delete, Keys, Size")
try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _tbl_lobe = _lobe_keys[1]
        create_lobe_table!(_tbl_lobe)
        table_put!(_tbl_lobe, "json", "del_key", "to_be_deleted")
        _del_ok = table_delete!(_tbl_lobe, "json", "del_key")
        record("table_delete! returns true", _del_ok == true)
        _has2 = table_has(_tbl_lobe, "json", "del_key")
        record("after delete, table_has = false", _has2 == false)
        _keys = table_keys(_tbl_lobe, "json")
        record("table_keys returns Vector{String}", _keys isa Vector{String})
        _sz = table_size(_tbl_lobe, "json")
        record("table_size returns Int", _sz isa Int)
    else
        record("table delete (no lobes)", true, "skipped")
    end
catch e
    record("table delete/keys/size", false, "$e")
end

subsection("37d. Drop Table to Chunk & Get Drop Neighbors")
try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _tbl_lobe = _lobe_keys[1]
        create_lobe_table!(_tbl_lobe)
        _nids = collect(keys(NODE_MAP))
        if !isempty(_nids)
            _nid = _nids[1]
            _nd = NODE_MAP[_nid]
            if !isempty(_nd.drop_table)
                drop_table_to_chunk!(_tbl_lobe, _nid, _nd.drop_table)
                _dn = get_drop_neighbors(_tbl_lobe, _nid)
                record("drop_table_to_chunk! then get_drop_neighbors", _dn !== nothing)
                record("drop neighbors is Vector{String}", _dn isa Vector{String})
            else
                record("drop_table_to_chunk (empty drop_table)", true, "skipped — node has empty drop_table")
            end
        else
            record("drop_table_to_chunk (no nodes)", true, "skipped")
        end
    else
        record("drop_table_to_chunk (no lobes)", true, "skipped")
    end
catch e
    record("drop_table_to_chunk", false, "$e")
end
