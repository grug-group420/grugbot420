
# ═══════════════════════════════════════════════════════════════
# 32. EPHEMERAL AUTOMATON — Rules, Phase, Vigilance
# ═══════════════════════════════════════════════════════════════
section("32. Ephemeral Automaton — Rules, Phase & Vigilance")

subsection("32a. Automaton Rules CRUD")
try
    _rule = AutomatonRule("test_rule", :greet, 0.5,
                          [AutomatonStep(:boost_confidence, Dict{String,Any}("factor" => 1.1))])
    register_automaton_rule!(_rule)
    record("register_automaton_rule! runs", true)
catch e
    record("register_automaton_rule!", false, "$e")
end

try
    _lookup = lookup_automaton_rule("test_rule")
    record("lookup_automaton_rule returns rule", _lookup !== nothing)
catch e
    record("lookup_automaton_rule", false, "$e")
end

try
    _list = list_automaton_rules()
    record("list_automaton_rules returns vector", _list isa Vector)
catch e
    record("list_automaton_rules", false, "$e")
end

try
    _match = find_matching_rule(:greet, 0.5)
    record("find_matching_rule(:greet, 0.5)", _match !== nothing)
catch e
    record("find_matching_rule", false, "$e")
end

subsection("32b. Run Automaton")
try
    _rule2 = lookup_automaton_rule("test_rule")
    if _rule2 !== nothing
        _trace = run_automaton(_rule2; confidence=0.6, context=Dict{String,Any}("input" => "hello"))
        record("run_automaton returns trace", _trace !== nothing)
    else
        record("run_automaton (no rule)", true, "skipped")
    end
catch e
    record("run_automaton", false, "$e")
end

try
    _af_result = run_for_action_family(:greet, 0.6; context=Dict{String,Any}("input"=>"hi"))
    record("run_for_action_family(:greet) runs", true)
catch e
    record("run_for_action_family", false, "$e")
end

subsection("32c. Phase Accumulator")
try
    reset_phase_accumulator!()
    record("reset_phase_accumulator! runs", true)
catch e
    record("reset_phase_accumulator!", false, "$e")
end

try
    _phase_vec = zeros(12)
    _phase_vec[1] = 0.8
    record_phase!(_phase_vec, :greet, 0.7)
    record("record_phase! runs", true)
catch e
    record("record_phase!", false, "$e")
end

try
    _pq = phase_pull_query(zeros(12))
    record("phase_pull_query returns something", _pq !== nothing)
catch e
    record("phase_pull_query", false, "$e")
end

try
    _ps = phase_pull_status()
    record("phase_pull_status returns Dict", _ps isa Dict)
catch e
    record("phase_pull_status", false, "$e")
end

try
    set_phase_pull_threshold!(0.6)
    record("set_phase_pull_threshold!(0.6) runs", true)
    _pt = get_phase_pull_threshold()
    record("get_phase_pull_threshold ≈ 0.6", abs(_pt - 0.6) < 0.01)
catch e
    record("phase_pull_threshold", false, "$e")
end

try
    set_phase_surface_count!(5)
    record("set_phase_surface_count!(5) runs", true)
    _sc = get_phase_surface_count()
    record("get_phase_surface_count == 5", _sc == 5)
catch e
    record("phase_surface_count", false, "$e")
end

try
    _pad = phase_accumulator_to_dict()
    record("phase_accumulator_to_dict returns Dict", _pad isa Dict)
catch e
    record("phase_accumulator_to_dict", false, "$e")
end

subsection("32d. Vigilance & Context Injectors")
try
    _cw = compute_context_weight(0.5, 0.3, 0.8)
    record("compute_context_weight returns Float64", _cw isa Float64)
catch e
    record("compute_context_weight", false, "$e")
end

try
    _vc = get_vigilance_config()
    record("get_vigilance_config returns Dict", _vc isa Dict)
catch e
    record("get_vigilance_config", false, "$e")
end

try
    set_vigilance_config!(; injector_count=2)
    record("set_vigilance_config! runs", true)
catch e
    record("set_vigilance_config!", false, "$e")
end

try
    _vs = vigilance_status()
    record("vigilance_status returns Dict", _vs isa Dict)
catch e
    record("vigilance_status", false, "$e")
end

try
    _vss = vigilance_status_string()
    record("vigilance_status_string returns String", _vss isa String)
catch e
    record("vigilance_status_string", false, "$e")
end

try
    _mc = get_automaton_max_cap()
    record("get_automaton_max_cap returns Int", _mc isa Int)
    set_automaton_max_cap!(50)
    record("set_automaton_max_cap!(50) runs", true)
catch e
    record("automaton_max_cap", false, "$e")
end

try
    _si = serialize_vigilance_config()
    record("serialize_vigilance_config returns Dict", _si isa Dict)
catch e
    record("serialize_vigilance_config", false, "$e")
end

try
    _is = serialize_injector_stats()
    record("serialize_injector_stats returns Dict", _is isa Dict)
catch e
    record("serialize_injector_stats", false, "$e")
end

try
    reset_injector_stats!()
    record("reset_injector_stats! runs", true)
catch e
    record("reset_injector_stats!", false, "$e")
end

# Clean up test rule
try
    unregister_automaton_rule!("test_rule")
    record("unregister_automaton_rule!('test_rule') runs", true)
catch e
    record("unregister_automaton_rule!", false, "$e")
end
