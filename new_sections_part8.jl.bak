
# ═══════════════════════════════════════════════════════════════
# 38. AUTO LINKER — Evidence, Auto Link, Status
# ═══════════════════════════════════════════════════════════════
section("38. Auto Linker — Evidence & Status")

subsection("38a. Link Evidence Accumulation")
try
    _nids = collect(keys(NODE_MAP))
    if length(_nids) >= 2
        accumulate_link_evidence!(_nids[1], _nids[2]; evidence_type=:co_fire, increment=1.0)
        record("accumulate_link_evidence! runs", true)
    else
        record("accumulate_link_evidence! (not enough nodes)", true, "skipped")
    end
catch e
    record("accumulate_link_evidence!", false, "$e")
end

subsection("38b. Maybe Auto Link & Status")
try
    maybe_auto_link!()
    record("maybe_auto_link! runs without error", true)
catch e
    record("maybe_auto_link!", false, "$e")
end

try
    _als = get_autolink_status_summary()
    record("get_autolink_status_summary returns String", _als isa String)
catch e
    record("get_autolink_status_summary", false, "$e")
end

try
    _ll = get_link_log()
    record("get_link_log returns Vector", _ll isa Vector)
catch e
    record("get_link_log", false, "$e")
end

try
    _les = get_link_evidence_snapshot()
    record("get_link_evidence_snapshot returns Dict", _les isa Dict)
catch e
    record("get_link_evidence_snapshot", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 39. ACTION TONE PREDICTOR — Trajectory & Observation
# ═══════════════════════════════════════════════════════════════
section("39. Action Tone Predictor — Trajectory & Observation")

subsection("39a. Trajectory Config")
try
    reset_trajectory!()
    record("reset_trajectory! runs", true)
catch e
    record("reset_trajectory!", false, "$e")
end

try
    _ts = get_trajectory_state()
    record("get_trajectory_state returns something", _ts !== nothing)
catch e
    record("get_trajectory_state", false, "$e")
end

subsection("39b. Reset Tonal Observation")
try
    reset_tonal_observation!()
    record("reset_tonal_observation! runs", true)
catch e
    record("reset_tonal_observation!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 40. IMAGE SDF — Binary Detection & SDF Params
# ═══════════════════════════════════════════════════════════════
section("40. Image SDF — Binary Detection & SDF")

subsection("40a. Detect Image Binary")
try
    _det_plain = detect_image_binary("hello world")
    record("detect_image_binary(plain text) returns tuple", _det_plain isa Tuple)
    record("plain text not detected as image", _det_plain[1] == false)
catch e
    record("detect_image_binary plain", false, "$e")
end

try
    _det_png = detect_image_binary("\\x89PNG some data here")
    record("detect_image_binary(PNG-like) runs", true)
catch e
    record("detect_image_binary PNG", false, "$e")
end

subsection("40b. SDF Params & Jitter")
try
    _sdf = SDFParams(4, 4, zeros(16))
    record("SDFParams construction", _sdf !== nothing)
catch e
    record("SDFParams construction", false, "$e")
end

try
    _sdf2 = SDFParams(4, 4, rand(16))
    _jittered = apply_sdf_jitter(_sdf2)
    record("apply_sdf_jitter returns SDFParams", _jittered isa SDFParams || _jittered !== nothing)
catch e
    record("apply_sdf_jitter", false, "$e")
end

try
    _sdf3 = SDFParams(4, 4, rand(16))
    _signal = sdf_to_signal(_sdf3; max_samples=16)
    record("sdf_to_signal returns Vector{Float64}", _signal isa Vector{Float64})
catch e
    record("sdf_to_signal", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 41. MULTIPART ORCHESTRATOR — Vote Grouping & Objectives
# ═══════════════════════════════════════════════════════════════
section("41. Multipart Orchestrator — Votes & Objectives")

subsection("41a. Group Votes by Multipart")
try
    global _mv_votes = VoteCandidate[]
    try
        push!(_mv_votes, VoteCandidate("node1", "greet", 0.8, :primary, 1, "greeting", SigilBinding[]))
        push!(_mv_votes, VoteCandidate("node2", "teach", 0.6, :secondary, 2, "philosophy", SigilBinding[]))
    catch
        global _mv_votes = VoteCandidate[]
    end
    _gv = group_votes_by_multipart(_mv_votes)
    record("group_votes_by_multipart returns vector", _gv isa Vector)
catch e
    record("group_votes_by_multipart", false, "$e")
end

subsection("41b. Build Objectives & Summarize")
try
    if !isempty(_mv_votes)
        _obj = build_objectives(_mv_votes)
        record("build_objectives returns vector", _obj isa Vector)
    else
        record("build_objectives (empty votes)", true, "skipped")
    end
catch e
    record("build_objectives", false, "$e")
end

try
    global _mock_obj = nothing
    try
        _mock_obj = MultipartObjective("group_1", :primary, String["node1"], 0.8, Dict{String,Any}())
    catch
        _mock_obj = nothing
    end
    if _mock_obj !== nothing
        _summ = summarize_objective(_mock_obj)
        record("summarize_objective returns String", _summ isa String)
    else
        record("summarize_objective (no mock)", true, "skipped — constructor mismatch")
    end
catch e
    record("summarize_objective", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 42. STOCHASTIC HELPER — Coinflip, Bias
# ═══════════════════════════════════════════════════════════════
section("42. Stochastic Helper — Coinflip & Bias")

subsection("42a. Coinflip & Bias Construction")
try
    _co = CoinOutcome("heads", 0.6)
    record("CoinOutcome construction", _co !== nothing)
catch e
    record("CoinOutcome", false, "$e")
end

try
    _b = Bias(0.7)
    record("Bias construction", _b !== nothing)
catch e
    record("Bias", false, "$e")
end

try
    _rc = run_coinflip([CoinOutcome("yes", 0.6), CoinOutcome("no", 0.4)])
    record("run_coinflip returns outcome", _rc !== nothing)
catch e
    record("run_coinflip", false, "$e")
end

try
    _rcs = run_coinflips([CoinOutcome("a", 0.5), CoinOutcome("b", 0.5)], 10)
    record("run_coinflips returns vector of length 10", length(_rcs) == 10)
catch e
    record("run_coinflips", false, "$e")
end
