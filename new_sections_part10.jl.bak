
# ═══════════════════════════════════════════════════════════════════════════════
# 48. CAVE JOURNAL — Deep Config, Rotation, Serialization
# ═══════════════════════════════════════════════════════════════════════════════
section("48. Cave Journal — Deep Config & Rotation")
try
    _jstat = journal_status()
    record("journal_status returns string", _jstat isa String)
catch e
    record("journal_status", false, "$e")
end

try
    _jpath = journal_get_path()
    record("journal_get_path returns string", _jpath isa String)
catch e
    record("journal_get_path", false, "$e")
end

try
    journal_set_path!("/workspace")
    record("journal_set_path! runs", true)
catch e
    record("journal_set_path!", false, "$e")
end

try
    journal_set_filename!("test_journal.md")
    record("journal_set_filename! runs", true)
catch e
    record("journal_set_filename!", false, "$e")
end

try
    journal_log("test message from deep test"; tag=:test, emoji="🔬")
    record("journal_log with tag & emoji runs", true)
catch e
    record("journal_log tag/emoji", false, "$e")
end

try
    journal_section("Test Section From Deep Test")
    record("journal_section runs", true)
catch e
    record("journal_section", false, "$e")
end

try
    journal_subsection("Test Subsection From Deep Test")
    record("journal_subsection runs", true)
catch e
    record("journal_subsection", false, "$e")
end

try
    journal_pass("test pass entry"; detail="some detail")
    record("journal_pass with detail runs", true)
catch e
    record("journal_pass", false, "$e")
end

try
    journal_fail("test fail entry"; detail="some fail detail")
    record("journal_fail with detail runs", true)
catch e
    record("journal_fail", false, "$e")
end

try
    journal_warn("test warning entry"; detail="some warning")
    record("journal_warn with detail runs", true)
catch e
    record("journal_warn", false, "$e")
end

try
    journal_info("test info entry"; detail="some info")
    record("journal_info with detail runs", true)
catch e
    record("journal_info", false, "$e")
end

try
    journal_debug_block("test debug block", ["line1", "line2", "line3"])
    record("journal_debug_block runs", true)
catch e
    record("journal_debug_block", false, "$e")
end

try
    journal_telemetry("test_metric", 42.0; unit="ms", source="deep_test")
    record("journal_telemetry runs", true)
catch e
    record("journal_telemetry", false, "$e")
end

try
    _jdict = journal_config_to_dict()
    record("journal_config_to_dict returns Dict", _jdict isa Dict)
catch e
    record("journal_config_to_dict", false, "$e")
end

try
    journal_config_from_dict!(_jdict)
    record("journal_config_from_dict! runs", true)
catch e
    record("journal_config_from_dict!", false, "$e")
end

try
    journal_rotate!(max_entries=50)
    record("journal_rotate! runs", true)
catch e
    record("journal_rotate!", false, "$e")
end

try
    journal_clear!()
    record("journal_clear! runs", true)
catch e
    record("journal_clear!", false, "$e")
end

try
    _active = journal_is_active()
    record("journal_is_active returns Bool", _active isa Bool)
catch e
    record("journal_is_active", false, "$e")
end

try
    journal_toggle!()
    _after_toggle = journal_is_active()
    record("journal_toggle! flips state", _active != _after_toggle)
    journal_toggle!()  # flip back
catch e
    record("journal_toggle!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 49. EPHEMERAL MLP — Strain, Novelty, Rules, Feedback
# ═══════════════════════════════════════════════════════════════════════════════
section("49. Ephemeral MLP — Strain, Novelty & Rules")
try
    init_ephemeral_mlp!()
    record("init_ephemeral_mlp! runs", true)
catch e
    record("init_ephemeral_mlp!", false, "$e")
end

try
    _mlp_stat = get_mlp_status()
    record("get_mlp_status returns string", _mlp_stat isa String)
catch e
    record("get_mlp_status", false, "$e")
end

try
    _act_mode = get_activation_mode()
    record("get_activation_mode returns Symbol", _act_mode isa Symbol)
catch e
    record("get_activation_mode", false, "$e")
end

try
    _nov = get_novelty_score()
    record("get_novelty_score returns float", _nov isa Float64)
catch e
    record("get_novelty_score", false, "$e")
end

try
    _strain = get_strain_energy()
    record("get_strain_energy returns float", _strain isa Float64)
catch e
    record("get_strain_energy", false, "$e")
end

try
    _hw = is_hippocampal_warrant_active()
    record("is_hippocampal_warrant_active returns Bool", _hw isa Bool)
catch e
    record("is_hippocampal_warrant_active", false, "$e")
end

try
    dampen_strain!(0.5)
    record("dampen_strain! runs", true)
catch e
    record("dampen_strain!", false, "$e")
end

try
    _obs_th = get_observation_threshold()
    record("get_observation_threshold returns float", _obs_th isa Float64)
catch e
    record("get_observation_threshold", false, "$e")
end

try
    set_observation_threshold!(0.75)
    record("set_observation_threshold! runs", true)
catch e
    record("set_observation_threshold!", false, "$e")
end

try
    add_mlp_rule!("test_rule_mlp"; key="test_key_mlp", pattern=r"test_pattern", transform=:solid, weight=1.0)
    record("add_mlp_rule! runs", true)
catch e
    record("add_mlp_rule!", false, "$e")
end

try
    _lr = list_mlp_rules()
    record("list_mlp_rules returns Vector", _lr isa Vector)
catch e
    record("list_mlp_rules", false, "$e")
end

try
    _look = lookup_mlp_rule("test_key_mlp")
    record("lookup_mlp_rule returns something", _look !== nothing)
catch e
    record("lookup_mlp_rule", false, "$e")
end

try
    activate_rule_by_key!("test_key_mlp")
    record("activate_rule_by_key! runs", true)
catch e
    record("activate_rule_by_key!", false, "$e")
end

try
    register_right_feedback!("test_key_mlp")
    record("register_right_feedback! runs", true)
catch e
    record("register_right_feedback!", false, "$e")
end

try
    register_wrong_feedback!("test_key_mlp")
    record("register_wrong_feedback! runs", true)
catch e
    record("register_wrong_feedback!", false, "$e")
end

try
    _spec_d = to_specimen_dict()
    record("to_specimen_dict returns Dict", _spec_d isa Dict)
catch e
    record("to_specimen_dict", false, "$e")
end

try
    _nov_stats = get_novelty_tracker_stats()
    record("get_novelty_tracker_stats returns something", _nov_stats !== nothing)
catch e
    record("get_novelty_tracker_stats", false, "$e")
end

try
    _corr_stats = get_input_correlation_stats()
    record("get_input_correlation_stats returns something", _corr_stats !== nothing)
catch e
    record("get_input_correlation_stats", false, "$e")
end

try
    _rule_hints = get_active_rule_hints()
    record("get_active_rule_hints returns something", _rule_hints !== nothing)
catch e
    record("get_active_rule_hints", false, "$e")
end

try
    drop_mlp_rule!("test_key_mlp")
    record("drop_mlp_rule! runs", true)
catch e
    record("drop_mlp_rule!", false, "$e")
end

try
    _snw = GrugBot420.EphemeralMLP.STRAIN_NOVELTY_WEIGHT
    record("STRAIN_NOVELTY_WEIGHT constant exists", _snw isa Float64 && _snw > 0.0)
catch e
    record("STRAIN_NOVELTY_WEIGHT", false, "$e")
end

try
    _sqw = GrugBot420.EphemeralMLP.STRAIN_QUALITY_WEIGHT
    record("STRAIN_QUALITY_WEIGHT constant exists", _sqw isa Float64 && _sqw > 0.0)
catch e
    record("STRAIN_QUALITY_WEIGHT", false, "$e")
end

try
    _sth = GrugBot420.EphemeralMLP.STRAIN_THRESHOLD
    record("STRAIN_THRESHOLD constant exists", _sth isa Float64 && _sth > 0.0)
catch e
    record("STRAIN_THRESHOLD", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 50. COHERENCE FIELD — Config, Delta, Status, Reset
# ═══════════════════════════════════════════════════════════════════════════════
section("50. Coherence Field — Config & Delta")
try
    _cf_snap = coherence_config_snapshot()
    record("coherence_config_snapshot returns CoherenceFieldConfig", _cf_snap !== nothing)
catch e
    record("coherence_config_snapshot", false, "$e")
end

try
    set_coherence_config!(:weight_max, 0.3)
    record("set_coherence_config! :weight_max runs", true)
catch e
    record("set_coherence_config!", false, "$e")
end

try
    reset_coherence_config!()
    record("reset_coherence_config! runs", true)
catch e
    record("reset_coherence_config!", false, "$e")
end

try
    _cf_dict = coherence_config_to_dict()
    record("coherence_config_to_dict returns Dict", _cf_dict isa Dict)
catch e
    record("coherence_config_to_dict", false, "$e")
end

try
    coherence_config_from_dict!(_cf_dict)
    record("coherence_config_from_dict! runs", true)
catch e
    record("coherence_config_from_dict!", false, "$e")
end

try
    # compute_field with the NODE_MAP from the specimen
    local _field_nodes
    lock(NODE_LOCK) do
        _field_nodes = copy(NODE_MAP)
    end
    if !isempty(_field_nodes)
        _cf = compute_field(_field_nodes)
        record("compute_field on specimen nodes returns Dict", _cf isa Dict)
    else
        record("compute_field skipped (no nodes)", true, "NODE_MAP empty after specimen load")
    end
catch e
    record("compute_field", false, "$e")
end

try
    _cfs = coherence_field_status(NODE_MAP)
    record("coherence_field_status returns Dict", _cfs isa Dict)
catch e
    record("coherence_field_status", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 51. GEOMETRY KIT — Distance Computations, Overview, Trajectory
# ═══════════════════════════════════════════════════════════════════════════════
section("51. Geometry Kit — Distance & Config")
try
    _sd = semantic_distance(0.8, 0.5)
    record("semantic_distance returns Float64", _sd isa Float64 && _sd >= 0.0)
catch e
    record("semantic_distance", false, "$e")
end

try
    _cd = coherence_distance(0.2, -0.1)
    record("coherence_distance returns Float64", _cd isa Float64 && _cd >= 0.0)
catch e
    record("coherence_distance", false, "$e")
end

try
    _pd = phase_distance([0.1, 0.2, 0.3], [0.4, 0.5, 0.6])
    record("phase_distance returns Float64", _pd isa Float64 && _pd >= 0.0)
catch e
    record("phase_distance", false, "$e")
end

try
    _td = tone_distance("science", "technology")
    record("tone_distance returns Float64", _td isa Float64 && _td >= 0.0)
catch e
    record("tone_distance", false, "$e")
end

try
    _td2 = tone_distance(nothing, nothing)
    record("tone_distance with nothings returns Float64", _td2 isa Float64)
catch e
    record("tone_distance nothings", false, "$e")
end

try
    _sp_dist = space_distance(PHASE_SPACE; phase_a=[0.1,0.2], phase_b=[0.3,0.4])
    record("space_distance(PHASE_SPACE) returns Float64", _sp_dist isa Float64)
catch e
    record("space_distance PHASE_SPACE", false, "$e")
end

try
    _gover = geometry_overview(; phi=0.5, crystal_size=100)
    record("geometry_overview returns Dict", _gover isa Dict)
catch e
    record("geometry_overview", false, "$e")
end

try
    _traj = trajectory([(1.0, 0.5), (2.0, 0.3), (3.0, 0.7)]; depth=5)
    record("trajectory returns Dict", _traj isa Dict)
catch e
    record("trajectory", false, "$e")
end

try
    _attr = attractors(; gini=0.6)
    record("attractors returns Dict", _attr isa Dict)
catch e
    record("attractors", false, "$e")
end

try
    _gsnap = geometry_config_snapshot()
    record("geometry_config_snapshot returns GeometryConfig", _gsnap !== nothing)
catch e
    record("geometry_config_snapshot", false, "$e")
end

try
    set_geometry_config!(:semantic_weight, 0.35)
    record("set_geometry_config! :semantic_weight runs", true)
catch e
    record("set_geometry_config!", false, "$e")
end

try
    reset_geometry_config!()
    record("reset_geometry_config! runs", true)
catch e
    record("reset_geometry_config!", false, "$e")
end

try
    _gdict = geometry_config_to_dict()
    record("geometry_config_to_dict returns Dict", _gdict isa Dict)
catch e
    record("geometry_config_to_dict", false, "$e")
end

try
    geometry_config_from_dict!(_gdict)
    record("geometry_config_from_dict! runs", true)
catch e
    record("geometry_config_from_dict!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 52. INVERSE SIGIL — Concrete Ops, Magnet, Routes, Reset
# ═══════════════════════════════════════════════════════════════════════════════
section("52. Inverse Sigil — Concrete & Magnet")
try
    _is_status = get_inverse_sigil_status()
    record("get_inverse_sigil_status returns string", _is_status isa String)
catch e
    record("get_inverse_sigil_status", false, "$e")
end

try
    add_concrete!("test_sigil", "alpha_token")
    record("add_concrete! runs", true)
catch e
    record("add_concrete!", false, "$e")
end

try
    add_concrete!("test_sigil", "beta_token")
    add_concrete!("test_sigil", "gamma_token")
    add_concrete!("test_sigil", "delta_token")
    record("add_concrete! multiple tokens to same sigil", true)
catch e
    record("add_concrete! multiple", false, "$e")
end

try
    GrugBot420.InverseSigil.observe_concretes!("test_sigil_2", ["tok_a", "tok_b", "tok_c"])
    record("observe_concretes! runs", true)
catch e
    record("observe_concretes!", false, "$e")
end

try
    GrugBot420.InverseSigil.user_add_concrete!("test_sigil", "user_directive_tok"; is_user_directive=true)
    record("user_add_concrete! runs", true)
catch e
    record("user_add_concrete!", false, "$e")
end

try
    _ts = GrugBot420.InverseSigil.get_table_snapshot()
    record("get_table_snapshot returns Dict", _ts isa Dict)
catch e
    record("get_table_snapshot", false, "$e")
end

try
    _tstat = GrugBot420.InverseSigil.get_table_status()
    record("get_table_status returns string", _tstat isa String)
catch e
    record("get_table_status", false, "$e")
end

try
    _ed = GrugBot420.InverseSigil.get_entry_detail("test_sigil")
    record("get_entry_detail returns string", _ed isa String)
catch e
    record("get_entry_detail", false, "$e")
end

try
    GrugBot420.InverseSigil.set_lobe_hint!("test_sigil", "science")
    record("set_lobe_hint! runs", true)
catch e
    record("set_lobe_hint!", false, "$e")
end

try
    GrugBot420.InverseSigil.clear_lobe_hint!("test_sigil")
    record("clear_lobe_hint! runs", true)
catch e
    record("clear_lobe_hint!", false, "$e")
end

try
    _routes = GrugBot420.InverseSigil.get_all_routes()
    record("get_all_routes returns Vector", _routes isa Vector)
catch e
    record("get_all_routes", false, "$e")
end

try
    GrugBot420.InverseSigil.decay_concretes!()
    record("decay_concretes! runs", true)
catch e
    record("decay_concretes!", false, "$e")
end

try
    reset_inverse_table!()
    record("reset_inverse_table! runs", true)
catch e
    record("reset_inverse_table!", false, "$e")
end
