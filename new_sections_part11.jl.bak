
# ═══════════════════════════════════════════════════════════════════════════════
# 53. SIGIL REGISTRY — Deep Registration, Resolution, Structure/Relation
# ═══════════════════════════════════════════════════════════════════════════════
section("53. Sigil Registry — Deep Operations")
try
    global _sig_table = default_registry()
    record("default_registry returns SigilTable", _sig_table isa SigilTable)
catch e
    record("default_registry", false, "$e")
end

try
    register_sigil!(_sig_table, "TestMacro"; name="TestMacro", class=:macro, applies_at=:match,
                    pattern=r"testmacro", lexicon=Set(["test", "macro"]))
    record("register_sigil! macro runs", true)
catch e
    record("register_sigil! macro", false, "$e")
end

try
    _has = has_sigil(_sig_table, "TestMacro")
    record("has_sigil TestMacro returns true", _has == true)
catch e
    record("has_sigil TestMacro", false, "$e")
end

try
    _look = lookup_sigil(_sig_table, "TestMacro")
    record("lookup_sigil TestMacro returns SigilEntry", _look !== nothing)
catch e
    record("lookup_sigil TestMacro", false, "$e")
end

try
    _ls = list_sigils(_sig_table)
    record("list_sigils returns Vector", _ls isa Vector)
catch e
    record("list_sigils", false, "$e")
end

try
    _parse = parse_sigil_token("&TestMacro")
    record("parse_sigil_token '&TestMacro' returns name", _parse == "TestMacro")
catch e
    record("parse_sigil_token", false, "$e")
end

try
    _parse2 = parse_sigil_token("not_a_sigil")
    record("parse_sigil_token 'not_a_sigil' returns nothing", _parse2 === nothing)
catch e
    record("parse_sigil_token non-sigil", false, "$e")
end

try
    register_structure_sigil!(_sig_table, "TestStruct"; name="TestStruct", pattern=r"teststruct",
                              structure_template=Dict("key" => "value"))
    record("register_structure_sigil! runs", true)
catch e
    record("register_structure_sigil!", false, "$e")
end

try
    _is_struct = is_structure_sigil(_sig_table, "TestStruct")
    record("is_structure_sigil TestStruct returns Bool", _is_struct isa Bool)
catch e
    record("is_structure_sigil", false, "$e")
end

try
    register_relation_sigil!(_sig_table; name="TestRelation", head="alpha", tail="beta",
                             relation="is_related_to")
    record("register_relation_sigil! runs", true)
catch e
    record("register_relation_sigil!", false, "$e")
end

try
    _is_rel = is_relation_sigil(_sig_table, "TestRelation")
    record("is_relation_sigil TestRelation returns Bool", _is_rel isa Bool)
catch e
    record("is_relation_sigil", false, "$e")
end

try
    _classes = SIGIL_CLASSES
    record("SIGIL_CLASSES constant is tuple of Symbols", _classes isa NTuple && all(x -> x isa Symbol, _classes))
catch e
    record("SIGIL_CLASSES", false, "$e")
end

try
    _prefix = SIGIL_PREFIX
    record("SIGIL_PREFIX constant is Char '&'", _prefix == '&')
catch e
    record("SIGIL_PREFIX", false, "$e")
end

try
    _name_re = SIGIL_NAME_REGEX
    record("SIGIL_NAME_REGEX is Regex", _name_re isa Regex)
catch e
    record("SIGIL_NAME_REGEX", false, "$e")
end

try
    _token_re = SIGIL_TOKEN_REGEX
    record("SIGIL_TOKEN_REGEX is Regex", _token_re isa Regex)
catch e
    record("SIGIL_TOKEN_REGEX", false, "$e")
end

try
    clear_registry!(_sig_table)
    record("clear_registry! runs", true)
catch e
    record("clear_registry!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 54. SELF OBSERVER — Deep Observe, Peek, Audit, Invariant
# ═══════════════════════════════════════════════════════════════════════════════
section("54. Self Observer — Observe, Peek & Audit")
try
    observe!("test_key_1"; tag=:lexical, payload=Dict("word" => "hello"), p_write=1.0)
    record("observe! with p_write=1.0 runs", true)
catch e
    record("observe! deterministic", false, "$e")
end

try
    observe!("test_key_1"; tag=:lexical, payload=Dict("word" => "world"), p_write=1.0)
    record("observe! second write to same key", true)
catch e
    record("observe! second", false, "$e")
end

try
    observe!("test_key_2"; tag=:mood, payload=Dict("sentiment" => "curious"), p_write=1.0)
    record("observe! different key runs", true)
catch e
    record("observe! different key", false, "$e")
end

try
    _pe = peek_exact("test_key_1")
    record("peek_exact returns Vector", _pe isa Vector)
catch e
    record("peek_exact", false, "$e")
end

try
    _pp = peek_pattern("test_*")
    record("peek_pattern returns Vector", _pp isa Vector)
catch e
    record("peek_pattern", false, "$e")
end

try
    _at = audit_trail()
    record("audit_trail returns something", _at !== nothing)
catch e
    record("audit_trail", false, "$e")
end

try
    _ss = store_size()
    record("store_size returns Int", _ss isa Int)
catch e
    record("store_size", false, "$e")
end

try
    _kc = key_count()
    record("key_count returns Int", _kc isa Int)
catch e
    record("key_count", false, "$e")
end

try
    _ic = invariant_check()
    record("invariant_check returns Bool", _ic isa Bool)
catch e
    record("invariant_check", false, "$e")
end

try
    drop_keys_by_prefix!("test_")
    record("drop_keys_by_prefix! runs", true)
catch e
    record("drop_keys_by_prefix!", false, "$e")
end

try
    reset_audit!()
    record("reset_audit! runs", true)
catch e
    record("reset_audit!", false, "$e")
end

try
    _fb = FUZZY_BUCKETS
    record("FUZZY_BUCKETS constant is Vector", _fb isa Vector)
catch e
    record("FUZZY_BUCKETS", false, "$e")
end

try
    _iov = INVARIANT_OBSERVER_VERSION
    record("INVARIANT_OBSERVER_VERSION is Int", _iov isa Int)
catch e
    record("INVARIANT_OBSERVER_VERSION", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 55. VOTE ORCHESTRATOR — Fire Counter, Composite Score, Task
# ═══════════════════════════════════════════════════════════════════════════════
section("55. Vote Orchestrator — Fire Counter & Composite")
try
    global _fc = FireCounter("test_cycle_001", 100)
    record("FireCounter constructor runs", _fc !== nothing)
catch e
    record("FireCounter constructor", false, "$e")
end

try
    _claim1 = try_claim_fire_slot!(_fc)
    record("try_claim_fire_slot! first claim returns true", _claim1 == true)
catch e
    record("try_claim_fire_slot! first", false, "$e")
end

try
    _cc = current_fire_count(_fc)
    record("current_fire_count returns 1", _cc == 1)
catch e
    record("current_fire_count", false, "$e")
end

try
    _cap = fire_cap_reached(_fc)
    record("fire_cap_reached returns false (1 < 100)", _cap == false)
catch e
    record("fire_cap_reached", false, "$e")
end

try
    # Fill up the fire counter to cap
    for _i in 2:100
        try_claim_fire_slot!(_fc)
    end
    _cap2 = fire_cap_reached(_fc)
    record("fire_cap_reached returns true at cap", _cap2 == true)
catch e
    record("fire_cap_reached at cap", false, "$e")
end

try
    _claim_over = try_claim_fire_slot!(_fc)
    record("try_claim_fire_slot! over cap returns false", _claim_over == false)
catch e
    record("try_claim_fire_slot! over cap", false, "$e")
end

try
    global _vc2 = VoteCandidate("test_node_id", 0.85, "science", 3.5, Dict{String,Any}())
    record("VoteCandidate constructor runs", _vc2 !== nothing)
catch e
    record("VoteCandidate constructor", false, "$e")
end

try
    _cvs = composite_vote_score(_vc2)
    record("composite_vote_score returns Float64", _cvs isa Float64)
catch e
    record("composite_vote_score", false, "$e")
end

try
    _sbvc = strength_biased_vote_coinflip(_vc2)
    record("strength_biased_vote_coinflip returns Bool", _sbvc isa Bool)
catch e
    record("strength_biased_vote_coinflip", false, "$e")
end

try
    _afc = ACTIVE_FIRE_CAP
    record("ACTIVE_FIRE_CAP constant exists", _afc isa Int && _afc > 0)
catch e
    record("ACTIVE_FIRE_CAP", false, "$e")
end

try
    _fbs = FIRE_BATCH_SIZE
    record("FIRE_BATCH_SIZE constant exists", _fbs isa Int && _fbs > 0)
catch e
    record("FIRE_BATCH_SIZE", false, "$e")
end

try
    _aiml_ct = AIML_CONFIDENCE_THRESHOLD
    record("AIML_CONFIDENCE_THRESHOLD constant exists", _aiml_ct isa Float64 && _aiml_ct > 0.0)
catch e
    record("AIML_CONFIDENCE_THRESHOLD", false, "$e")
end

try
    _tid = next_task_id("test")
    record("next_task_id returns string starting with 'test'", startswith(_tid, "test"))
catch e
    record("next_task_id", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 56. PETTY LEARNER — Classify & Dispatch
# ═══════════════════════════════════════════════════════════════════════════════
section("56. Petty Learner — Classify & Dispatch")
try
    # classify_petty requires a lot of context; try with a simple input
    _bindings = Dict{String,Any}("input" => "2 + 2", "has_math" => true, "arithmetic_expr" => "2+2")
    _pr = classify_petty("2 + 2", _bindings, Dict{String,Any}(), Dict{String,Any}())
    record("classify_petty returns PettyResult", _pr !== nothing)
catch e
    record("classify_petty", false, "$e")
end

try
    # Try classify with non-math input
    _pr2 = classify_petty("hello there", Dict{String,Any}(), Dict{String,Any}(), Dict{String,Any}())
    record("classify_petty non-math returns PettyResult", _pr2 !== nothing)
catch e
    record("classify_petty non-math", false, "$e")
end

try
    _ps = GrugBot420.PettyLearner.petty_status()
    record("petty_status returns string", _ps isa String)
catch e
    record("petty_status", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 57. SEMANTIC VERBS — Verbs, Classes, Synonyms, Normalize
# ═══════════════════════════════════════════════════════════════════════════════
section("57. Semantic Verbs — Verbs, Classes & Synonyms")
try
    add_relation_class!("test_relation_class")
    record("add_relation_class! runs", true)
catch e
    record("add_relation_class!", false, "$e")
end

try
    add_verb!("testifies", "test_relation_class")
    record("add_verb! runs", true)
catch e
    record("add_verb!", false, "$e")
end

try
    _all_v = GrugBot420.SemanticVerbs.get_all_verbs()
    record("get_all_verbs returns Set", _all_v isa Set)
catch e
    record("get_all_verbs", false, "$e")
end

try
    _class_v = GrugBot420.SemanticVerbs.get_verbs_in_class("test_relation_class")
    record("get_verbs_in_class returns Set", _class_v isa Set && "testifies" in _class_v)
catch e
    record("get_verbs_in_class", false, "$e")
end

try
    _classes = GrugBot420.SemanticVerbs.get_relation_classes()
    record("get_relation_classes returns Vector", _classes isa Vector && "test_relation_class" in _classes)
catch e
    record("get_relation_classes", false, "$e")
end

try
    add_synonym!("testifies", "attests")
    record("add_synonym! runs", true)
catch e
    record("add_synonym!", false, "$e")
end

try
    _syn_map = GrugBot420.SemanticVerbs.get_synonym_map()
    record("get_synonym_map returns Dict", _syn_map isa Dict && get(_syn_map, "attests", "") == "testifies")
catch e
    record("get_synonym_map", false, "$e")
end

try
    _vclass = GrugBot420.SemanticVerbs.verb_class_of("testifies")
    record("verb_class_of returns class name", _vclass == "test_relation_class")
catch e
    record("verb_class_of", false, "$e")
end

try
    _norm = GrugBot420.SemanticVerbs.normalize_synonyms("the witness attests to the fact")
    record("normalize_synonyms returns string with canonical", occursin("testifies", _norm))
catch e
    record("normalize_synonyms", false, "$e")
end

try
    remove_synonym!("attests")
    record("remove_synonym! runs", true)
catch e
    record("remove_synonym!", false, "$e")
end
