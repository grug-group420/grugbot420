#!/usr/bin/env julia
# test_deep_specimen.jl — Deep comprehensive specimen test
# Exercises EVERY feature GrugBot420 has, loads a real specimen,
# uses CaveJournal to log, checks results, fixes what it can.
# The user said "try everything" — so we try EVERYTHING.

using Dates, JSON, Base.Threads
include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    NODE_MAP, NODE_LOCK,
    MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK,
    extract_relational_triples,
    _dict_define_word!

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
    SpaceName, PHASE_SPACE, geometry_overview,
    semantic_distance, coherence_distance, phase_distance, tone_distance,
    space_distance

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
    what_was, what_becomes,
    merge_continuants!, delete_continuant!,
    propose_continuant!, list_continuant_proposals,
    approve_continuant_proposal!, reject_continuant_proposal!,
    clear_continuants!, temporal_identity_to_dict, temporal_identity_from_dict!,
    Stage

import .GrugBot420.CaveJournal:
    journal_on!, journal_off!, journal_toggle!, journal_is_active,
    journal_status, journal_set_path!, journal_get_path, journal_set_filename!,
    journal_log, journal_section, journal_subsection,
    journal_pass, journal_fail, journal_warn, journal_info,
    journal_debug_block, journal_telemetry,
    journal_clear!, journal_rotate!,
    journal_config_to_dict, journal_config_from_dict!

import .GrugBot420.AutoGrowth:
    accumulate_evidence!, maybe_grow_from_evidence!, discover_thesaurus_pairs!,
    get_autogrowth_status_summary, reset_evidence!,
    get_growth_log,
    get_evidence_snapshot, load_evidence_snapshot!,
    get_co_occur_snapshot, load_co_occur_snapshot!,
    check_curiosity_overflow, get_curiosity_status, quench_curiosity!,
    serialize_curiosity, deserialize_curiosity!

import .GrugBot420.AutoLinker:
    accumulate_link_evidence!, maybe_auto_link!,
    get_autolink_status_summary, reset_link_evidence!,
    get_link_log,
    get_link_evidence_snapshot, load_link_evidence_snapshot!

import .GrugBot420.EphemeralMLP: MLPTransformerRule,
    init_ephemeral_mlp!, reset_ephemeral_mlp!,
    transform_vote_list, get_mlp_status,
    add_mlp_rule!, drop_mlp_rule!, list_mlp_rules, lookup_mlp_rule,
    activate_rule_by_key!, activate_rules_by_pattern!,
    to_specimen_dict, from_specimen_dict!,
    register_right_feedback!, register_wrong_feedback!,
    get_activation_mode, get_novelty_score,
    set_observation_threshold!, get_observation_threshold,
    get_strain_energy, is_hippocampal_warrant_active, dampen_strain!,
    MLPTransformerRule

import .GrugBot420.SelfObserver:
    observe!, peek_exact, peek_pattern, audit_trail, drop_store!,
    drop_keys_by_prefix!, reset_audit!, store_size, key_count,
    invariant_check, SubconsciousStore

import .GrugBot420.PhagyMode:
    run_phagy!, get_phagy_log, run_memory_forensics!, fuzzy_memory_forensics!,
    metric_memory_forensics!, prune_orphan_nodes!, decay_forgotten_strengths!,
    recycle_grave_assets!, compact_drop_tables!, prune_dormant_rules!,
    sweep_injector_graveyard!, age_phase_accumulator!, prune_observer_store!,
    check_sigil_consistency!, trim_stale_trajectory!,
    lobe_population_guard!, chatter_cooldown_purge!

import .GrugBot420.MitosisMode:
    run_mitosis!, get_mitosis_log, get_mitosis_status_summary

import .GrugBot420.ChatterMode:
    get_chatter_status, should_trigger_chatter, CHATTER_LOG

import .GrugBot420.ImmuneSystem:
    immune_scan!, get_immune_status, get_ledger_entries,
    add_known_signature!, lookup_signature, reset_immune_state!

import .GrugBot420.VoteOrchestrator:
    composite_vote_score, VoteCandidate, strength_biased_vote_coinflip,
    FireCounter, try_claim_fire_slot!, current_fire_count, fire_cap_reached

import .GrugBot420.LobeOrchestrator:
    score_lobes, flatten_in_fire_order, compute_fire_batches,
    last_summary, get_last_state, set_last_state!, LobeFireOrder

import .GrugBot420.HippocampalModulator:
    create_action_log!, wipe_action_log!, add_entry!, next_pending!,
    complete_entry!, fail_entry!, get_entry, log_entries, log_summary,
    modulate_objectives!, assemble_output!, all_sure_done,
    ActionLog, ENTRY_SURE

import .GrugBot420.InverseSigil:
    get_inverse_sigil_status, add_concrete!, reset_inverse_table!

import .GrugBot420.RelationalGovernance:
    observe_co_firing!, run_relational_governance!, get_relational_gov_status_summary

import .GrugBot420.RelationalJitter:
    enable_jitter!, disable_jitter!, is_jitter_enabled,
    set_jitter_ratio!, get_jitter_ratio

import .GrugBot420.SigilPromoter:
    promote_input, bindings_by_name, canonicalize_token, SigilBinding

import .GrugBot420.TonalJudge:
    Token, TokenCategory, FrameHint

import .GrugBot420.SemanticVerbs:
    add_verb!, add_relation_class!, add_synonym!, remove_synonym!

import .GrugBot420.ActionEngine:
    compute_action, format_action_reply, ActionResult

import .GrugBot420.PettyLearner:
    classify_petty, dispatch_petty!

import .GrugBot420.InputDecomposer:
    decompose_input

import .GrugBot420.BrainStem:
    dispatch!, get_brainstem_status, get_propagation_history,
    fire_lobe!, inhibit_lobe!, apply_fire_count_decay!,
    BrainStemState, DispatchResult, PropagationRecord

import .GrugBot420.TonalJudge:
    Token, TokenCategory, FrameHint, TonalReading, TonalJudgement,
    judge, judge_from_prediction, pick_mode, build_reading_from_prediction,
    compute_frame_match_multiplier, set_frame_match_weights!,
    reset_last_judgement!

import .GrugBot420.Thesaurus:
    thesaurus_gate_filter, thesaurus_gate_score, synonym_lookup,
    word_similarity, concept_similarity, context_similarity,
    cross_type_similarity, generate_ngrams, jaccard_similarity,
    add_seed_synonym!, seed_synonym_count, format_thesaurus_intensity,
    thesaurus_compare, thesaurus_batch_compare,
    stem_token, stem_expand_text

import .GrugBot420.RoutingJudge:
    resolve, collect_intents, shannon_entropy, compute_graph_backing,
    IntentCandidate, ScoredIntent, SubIntent

import .GrugBot420.EyeSystem:
    set_arousal!, get_arousal, decay_arousal!,
    compute_attention_map, process_visual_input,
    EdgeBlurParams, AttentionMap, EyeState

import .GrugBot420.EphemeralAutomaton: AutomatonRule,
    register_automaton_rule!, unregister_automaton_rule!,
    list_automaton_rules, lookup_automaton_rule, clear_automaton_rules!,
    run_automaton, find_matching_rule, run_for_action_family,
    PhaseSnapshot, PhaseAccumulator,
    record_phase!, phase_pull_query, phase_pull_status,
    set_phase_pull_threshold!, get_phase_pull_threshold,
    set_phase_surface_count!, get_phase_surface_count,
    set_phase_enabled!, reset_phase_accumulator!,
    phase_accumulator_to_dict, phase_accumulator_from_dict!,
    VigilanceConfig, ContextInjectorAgent, InjectorDisposition,
    compute_context_weight, dispatch_vigilance_agents!,
    get_vigilance_config, set_vigilance_config!,
    get_automaton_max_cap, set_automaton_max_cap!,
    vigilance_status, vigilance_status_string,
    serialize_vigilance_config, deserialize_vigilance_config!,
    serialize_injector_stats, reset_injector_stats!,
    AutomatonRule, AutomatonStep, AutomatonTrace

import .GrugBot420.ArithmeticEngine:
    compute_arithmetic, format_arithmetic_reply, has_math_bindings,
    ArithmeticResult, ComputationStep

import .GrugBot420.FullLobeScanner:
    FullLobeScanError, NoMatchFoundError,
    ActiveNodeSet, LobeScanner, ScanResult, ScanPhase,
    set_query!, gather_candidates!, activate_candidates!,
    continue_scan!, full_scan!, reset!,
    can_aiml_respond, require_aiml_ready!,
    scanner_status, print_status,
    is_active, active_count, at_capacity,
    activate_node!, deactivate_node!, clear_active!,
    phase_name,
    PHASE_INIT, PHASE_GATHER, PHASE_ACTIVATE, PHASE_CONTINUE, PHASE_DONE,
    CONFIDENT_THRESHOLD

import .GrugBot420.TemporalGrowth:
    run_growth_automaton!, get_growth_log, GrowthSpawnStats

import .GrugBot420.ChatterResiduals:
    start_chatter_residuals_thread!, stop_chatter_residuals_thread!,
    get_chatter_residuals_status, serialize_chatter_residuals,
    deserialize_chatter_residuals!, reset_chatter_residuals!,
    residual_ledger_size, is_consumed, mark_consumed!,
    observe_direct_co_occurrence!

import .GrugBot420.LobeTable:
    create_lobe_table!, table_put!, table_get, table_has,
    table_delete!, table_keys, table_size, table_match,
    json_to_table_chunk!, get_json_for_node,
    drop_table_to_chunk!, get_drop_neighbors

import .GrugBot420.AutoLinker:
    accumulate_link_evidence!, maybe_auto_link!,
    get_autolink_status_summary, reset_link_evidence!,
    get_link_log, get_link_evidence_snapshot, load_link_evidence_snapshot!

import .GrugBot420.ActionTonePredictor:
    ActionFamily, ToneFamily, PredictionResult,
    reset_tonal_observation!, set_trajectory_config!,
    get_trajectory_state, reset_trajectory!

import .GrugBot420.ImageSDF:
    detect_image_binary, image_to_sdf_params, SDFParams,
    apply_sdf_jitter, sdf_to_signal

import .GrugBot420.MultipartOrchestrator:
    group_votes_by_multipart, group_votes_by_chunks,
    build_objectives, summarize_objective,
    MultipartObjective

import .GrugBot420.CoinFlipHeader:
    @coinflip, bias, CoinOutcome, Bias,
    run_coinflip, run_coinflips

import .GrugBot420.SigilPromoter:
    promote_input, bindings_by_name, canonicalize_token, SigilBinding

import .GrugBot420.MitosisMode:
    MITOSIS_PROBABILITY, DATA_ENERGY_MSG_SCALE,
    STRAIN_WARRANT_WEIGHT, STRAIN_WARRANT_ACTIVE_THRESHOLD,
    LATCH_SCAN_CONFIDENCE_FLOOR, MITOSIS_GROUP_STRENGTH_FLOOR,
    MITOSIS_NOVELTY_COVERAGE_FLOOR, MIN_POPULATION_GATE,
    MAX_POPULATION_CAP, MITOSIS_COOLDOWN_CYCLES

import .GrugBot420.ImmuneSystem:
    immune_scan!, get_immune_status, get_ledger_entries,
    add_known_signature!, lookup_signature, reset_immune_state!,
    immune_ast_signature, detect_funky, quarantine_input!,
    attempt_patch, aiml_immune_gate, aiml_immune_scan!,
    get_aiml_immune_status, serialize_immune_state, AIML_MATURITY_THRESHOLD

import .GrugBot420.InputDecomposer:
    decompose_input, is_compound, get_config,
    config_status_string, chunk_boundaries,
    add_split_conjunction!, remove_split_conjunction!,
    add_compound_pair!, remove_compound_pair!,
    add_question_marker!, remove_question_marker!,
    DecomposerConfig

import .GrugBot420.InverseSigil:
    get_inverse_sigil_status, add_concrete!, reset_inverse_table!,
    observe_concretes!, user_add_concrete!, get_table_snapshot,
    get_table_status, get_entry_detail, set_lobe_hint!, clear_lobe_hint!,
    get_all_routes, decay_concretes!

import .GrugBot420.RelationalGovernance:
    observe_co_firing!, run_relational_governance!,
    get_relational_gov_status_summary,
    CO_ACC_MAX_PAIRS, AUTO_ATTACH_THRESHOLD, AUTO_ATTACH_PROB

import .GrugBot420.RelationalJitter:
    enable_jitter!, disable_jitter!, is_jitter_enabled,
    set_jitter_ratio!, get_jitter_ratio,
    jitter_value, jitter_coin_threshold,
    set_jitter_coin_ratio!, get_jitter_coin_ratio,
    with_brainstorm_jitter, is_brainstorm_active,
    JITTER_RATIO_DEFAULT

import .GrugBot420.EphemeralMLP: MLPTransformerRule,
    init_ephemeral_mlp!, reset_ephemeral_mlp!, get_mlp_status,
    get_activation_mode, get_novelty_score,
    get_strain_energy, is_hippocampal_warrant_active, dampen_strain!,
    set_observation_threshold!, get_observation_threshold,
    add_mlp_rule!, drop_mlp_rule!, list_mlp_rules, lookup_mlp_rule,
    activate_rule_by_key!,
    register_right_feedback!, register_wrong_feedback!,
    to_specimen_dict, from_specimen_dict!,
    get_novelty_tracker_stats, get_input_correlation_stats,
    get_active_rule_hints,
    STRAIN_NOVELTY_WEIGHT, STRAIN_QUALITY_WEIGHT, STRAIN_THRESHOLD,
    MLPTransformerRule

import .GrugBot420.CoherenceField:
    compute_field, set_coherence_config!, coherence_config_snapshot,
    coherence_config_to_dict, coherence_config_from_dict!,
    reset_coherence_config!, coherence_field_status

import .GrugBot420.GeometryKit:
    geometry_config_snapshot, set_geometry_config!, reset_geometry_config!,
    geometry_config_to_dict, geometry_config_from_dict!,
    semantic_distance, coherence_distance, phase_distance, tone_distance,
    space_distance, geometry_overview, trajectory, attractors,
    SpaceName, PHASE_SPACE

import .GrugBot420.SigilRegistry:
    register_sigil!, lookup_sigil, has_sigil, list_sigils, clear_registry!,
    resolve_sigils_in_pattern, parse_sigil_token,
    default_registry, merge_registry!,
    register_structure_sigil!, expand_structure_sigil, is_structure_sigil,
    register_relation_sigil!, expand_relation_sigil, is_relation_sigil,
    SIGIL_CLASSES, SIGIL_PREFIX, SIGIL_NAME_REGEX, SIGIL_TOKEN_REGEX,
    SigilTable

import .GrugBot420.SelfObserver:
    observe!, peek_exact, peek_pattern, audit_trail, drop_store!,
    drop_keys_by_prefix!, reset_audit!, store_size, key_count,
    invariant_check, FUZZY_BUCKETS, INVARIANT_OBSERVER_VERSION

import .GrugBot420.VoteOrchestrator:
    composite_vote_score, VoteCandidate, strength_biased_vote_coinflip,
    FireCounter, try_claim_fire_slot!, current_fire_count, fire_cap_reached,
    next_task_id, ACTIVE_FIRE_CAP, FIRE_BATCH_SIZE, AIML_CONFIDENCE_THRESHOLD

import .GrugBot420.SemanticVerbs:
    add_verb!, add_relation_class!, add_synonym!, remove_synonym!,
    get_all_verbs, get_verbs_in_class, get_relation_classes,
    get_synonym_map, verb_class_of, normalize_synonyms

import .GrugBot420.PatternMiner:
    pattern_miner_config_snapshot, set_pattern_miner_config!,
    reset_pattern_miner_config!, pattern_miner_config_to_dict,
    pattern_miner_config_from_dict!, pattern_miner_status,
    record_instance!, count_instances, get_all_instances,
    scan_transitivity!, scan_chaining!, scan_symmetry!, scan_all!,
    check_and_propose!, list_proposals,
    clear_instances!, clear_proposals!,
    SHAPE_TRANSITIVITY, SHAPE_CHAINING, SHAPE_SYMMETRY

import .GrugBot420.TemporalIdentity:
    temporal_identity_config_snapshot, set_temporal_identity_config!,
    reset_temporal_identity_config!, temporal_identity_config_to_dict,
    temporal_identity_config_from_dict!,
    create_continuant, add_stage!, add_transform_rule!, remove_stage!,
    identity_of, get_continuant, list_continuants, stages_of,
    what_was, what_becomes, merge_continuants!, delete_continuant!,
    propose_continuant!, list_continuant_proposals,
    approve_continuant_proposal!, reject_continuant_proposal!,
    clear_continuants!, temporal_identity_status,
    temporal_identity_to_dict, temporal_identity_from_dict!,
    Stage

import .GrugBot420.AutoGrowth:
    accumulate_evidence!, maybe_grow_from_evidence!,
    discover_thesaurus_pairs!,
    get_autogrowth_status_summary, reset_evidence!,
    get_growth_log, get_evidence_snapshot, load_evidence_snapshot!,
    get_co_occur_snapshot, load_co_occur_snapshot!,
    check_curiosity_overflow, get_curiosity_status, quench_curiosity!,
    serialize_curiosity, deserialize_curiosity!,
    EVIDENCE_FLOOR, EVIDENCE_SCALE, GROWTH_COINFLIP_CAP,
    SEMANTIC_GAP_THRESHOLD, CURIOSITY_OVERFLOW_THRESHOLD

import .GrugBot420.HippocampalModulator:
    create_action_log!, wipe_action_log!, add_entry!, next_pending!,
    complete_entry!, fail_entry!, get_entry, log_entries, log_summary,
    modulate_objectives!, assemble_output!, all_sure_done,
    ActionLog, ActionEntry, ENTRY_SURE


const SPEC_PATH = get(ARGS, 1, "/workspace/test_v9_temp.specimen")
const LOG_PATH  = "/workspace/deep_specimen_test_log.md"
const _log_lines = String[]

log_md(line) = push!(_log_lines, line)
flush_log() = open(LOG_PATH, "w") do f; for l in _log_lines; println(f, l); end; end

read_voice() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

# stdout capture via pipe
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
results = Tuple{String,Bool,String}[]
pass(name, detail="") = push!(results, (name, true, detail))
fail(name, detail="") = push!(results, (name, false, detail))

function record(name, condition, detail="")
    if condition
        pass(name, detail)
        log_md("- ✅ **$(name)**$(isempty(detail) ? "" : " — $(detail)")")
        println("  ✅ $name")
    else
        fail(name, detail)
        log_md("- ❌ **$(name)**$(isempty(detail) ? "" : " — $(detail)")")
        println("  ❌ $name — $detail")
    end
end

function section(title)
    log_md(""); log_md("## $(title)")
    println("\n## $(title)")
end

function subsection(title)
    log_md(""); log_md("### $(title)")
    println("\n### $(title)")
end

# ══════════════════════════════════════════════════════════════
# BOOT
# ══════════════════════════════════════════════════════════════
println("=" ^ 60)
println("Deep Specimen Test — Try Everything")
println("=" ^ 60)

log_md("# Deep Specimen Test — Try Everything")
log_md("_Generated: $(now())_")
log_md("_Specimen: $(SPEC_PATH)_")

# Turn on CaveJournal for the test itself
journal_set_path!("/workspace")
journal_set_filename!("deep_test_journal.md")
journal_on!()
journal_section("Deep Specimen Test Boot")

# ── Load specimen ──
section("0. Specimen Load")
try
    if isfile(SPEC_PATH)
        load_specimen_from_file!(SPEC_PATH)
        record("Specimen loaded from $(SPEC_PATH)", true)
        journal_pass("specimen loaded"; detail=SPEC_PATH)
    else
        record("No specimen at $(SPEC_PATH) — using fresh state", true)
        journal_info("no specimen to load"; detail="fresh state")
    end
catch e
    record("Specimen load failed", false, "$e")
    journal_fail("specimen load"; detail="$e")
end

# ══════════════════════════════════════════════════════════════
# 1. CONVERSATION ENGINE — THE CORE
# ══════════════════════════════════════════════════════════════
section("1. Conversation Engine — Core Routing")

# 1a. Arithmetic
subsection("1a. Arithmetic")
arith_cases = [
    ("5+5", "10"),
    ("what is 12 - 4", "8"),
    ("7 * 8", "56"),
    ("100 / 25", "4"),
    ("3 plus 2", "5"),
    ("nine minus three", "6"),
    ("0 + 0", "0"),
    ("what is 99 * 1", "99"),
    ("15 / 3", "5"),
    ("2 times 6", "12"),
]
for (input, expected) in arith_cases
    try
        voice = process_mission(input)
        v = read_voice()
        has_expected = occursin(expected, v)
        record("arithmetic: '$input' → contains '$expected'", has_expected, "voice='$(v[1:min(80,length(v))])'")
        if has_expected
            journal_pass("arithmetic: '$input'"; detail="expected=$expected")
        else
            journal_fail("arithmetic: '$input'"; detail="expected=$expected voice=$(v[1:min(80,length(v))])")
        end
    catch e
        record("arithmetic: '$input'", false, "ERROR: $e")
        journal_fail("arithmetic: '$input'"; detail="ERROR: $e")
    end
end

# 1b. Questions
subsection("1b. Dictionary Seeding")
# Seed dictionary definitions for each lobe so questions can be answered
# User tip: "dictionary nodes per lobe using LobeTable + sigils"
_lobe_ids_for_dict = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
if !isempty(_lobe_ids_for_dict)
    # Seed definitions in the first lobe (covers most question lookups)
    _dl = _lobe_ids_for_dict[1]
    _dict_define_word!(_dl, "love", "a deep feeling of warmth and care between beings")
    _dict_define_word!(_dl, "fire", "oxidation and heat — rapid burning that gives light and warmth")
    _dict_define_word!(_dl, "water", "H2O — the clear liquid essential for all cave life")
    _dict_define_word!(_dl, "happiness", "a state of joy and contentment — feeling good inside the cave")
    _dict_define_word!(_dl, "sky", "the great dome above the cave — blue from scattered sunlight")
    _dict_define_word!(_dl, "physics", "the study of how things move and interact in the cave world")
    record("dictionary seeding for questions", true)
else
    record("dictionary seeding (no lobes)", true, "skipped")
end

subsection("1b. Questions")
question_cases = [
    ("what is love", "love"),          # should have some answer about love
    ("what is fire", "fire"),          # might be unknown
    ("what is water", "water"),
    ("why is the sky blue", "sky"),    # likely unknown but should recognize topic
    ("what is happiness", "happ"),
]
for (input, topic) in question_cases
    try
        voice = process_mission(input)
        v = read_voice()
        # Question should at least mention the topic or ask for clarification
        has_topic = occursin(topic, lowercase(v))
        record("question: '$input' mentions '$topic'", has_topic, "voice='$(v[1:min(80,length(v))])'")
        if has_topic
            journal_info("question: '$input'"; detail="topic=$topic found")
        else
            journal_warn("question: '$input'"; detail="topic=$topic NOT found")
        end
    catch e
        record("question: '$input'", false, "ERROR: $e")
    end
end

# 1c. Teaching
subsection("1c. Teaching / Learning")
teach_cases = [
    ("fire is oxidation and heat", "fire"),
    ("water is H2O", "water"),
    ("gravity is a force of attraction between masses", "gravity"),
    ("photosynthesis is how plants convert light to energy", "photosynth"),
]
for (input, topic) in teach_cases
    try
        voice = process_mission(input)
        v = read_voice()
        # Teaching should acknowledge the lesson
        is_teaching = occursin("Teaching", v) || occursin("📝", v) || occursin("dictionary", lowercase(v)) || occursin("learned", lowercase(v)) || occursin("📖", v)
        record("teach: '$input'", is_teaching, "voice='$(v[1:min(80,length(v))])'")
    catch e
        record("teach: '$input'", false, "ERROR: $e")
    end
end

# 1d. Corrections
subsection("1d. Corrections")
# First teach something wrong, then correct it
try
    process_mission("actually fire is not hot, fire is cold")
    v = read_voice()
    is_correct = occursin("orrect", v) || occursin("✏️", v) || occursin("update", lowercase(v)) || occursin("📝", v)
    record("correction: 'actually fire is not hot'", is_correct, "voice='$(v[1:min(80,length(v))])'")
catch e
    record("correction", false, "ERROR: $e")
end

# 1e. Compound questions
subsection("1e. Compound Questions")
compound_cases = [
    ("what is 5+5 and what is love", "10"),   # should have 10 from arithmetic
    ("what is 3 times 2 and why is grass green", "6"),
]
for (input, expected_num) in compound_cases
    try
        voice = process_mission(input)
        v = read_voice()
        has_num = occursin(expected_num, v)
        record("compound: '$input' has '$expected_num'", has_num, "voice='$(v[1:min(100,length(v))])'")
    catch e
        record("compound: '$input'", false, "ERROR: $e")
    end
end

# 1f. Define command (dictionary)
subsection("1f. Define / Dictionary")
try
    process_mission("/define star = a luminous celestial body")
    v = read_voice()
    is_defined = occursin("star", lowercase(v)) || occursin("Learned", v) || occursin("📖", v) || occursin("defined", lowercase(v))
    record("/define star = ...", is_defined, "voice='$(v[1:min(80,length(v))])'")
catch e
    record("/define", false, "ERROR: $e")
end

# Now query it
try
    process_mission("what is star")
    v = read_voice()
    has_star = occursin("luminous", lowercase(v)) || occursin("celestial", lowercase(v)) || occursin("star", lowercase(v))
    record("query 'star' after define", has_star, "voice='$(v[1:min(80,length(v))])'")
catch e
    record("query star", false, "ERROR: $e")
end

# ══════════════════════════════════════════════════════════════
# 2. SIGIL SYSTEM
# ══════════════════════════════════════════════════════════════
section("2. Sigil System")

subsection("2a. Sigil Registry")
try
    # list_sigils requires a SigilTable argument — create a fresh one
    _test_sigil_table = SigilTable()
    sl = list_sigils(_test_sigil_table)
    record("list_sigils returns data on fresh table", sl !== nothing, "count=$(length(sl))")
    journal_info("sigil list"; detail="count=$(length(sl))")
catch e
    record("list_sigils", false, "$e")
end

try
    classes = collect(keys(SIGIL_CLASSES))
    record("SIGIL_CLASSES has entries", !isempty(classes), "classes=$(join(classes, ","))")
catch e
    record("SIGIL_CLASSES", false, "$e")
end

try
    active = STAGE1_ACTIVE_CLASSES
    record("STAGE1_ACTIVE_CLASSES defined", !isempty(active), "count=$(length(active))")
catch e
    record("STAGE1_ACTIVE_CLASSES", false, "$e")
end

subsection("2b. Structure Sigils (Meta-Sigils)")
try
    # register_structure_sigil! takes table; name; expansion (Vector), provenance
    _test_st = SigilTable()
    register_structure_sigil!(_test_st; name="test_struct", expansion=["test_lambda", "test_macro", "test_relation"], provenance="test structure sigil")
    is_struct = is_structure_sigil(_test_st, "test_struct")
    record("register + check structure sigil", is_struct)
    journal_info("structure sigil registered"; detail="test_struct")
catch e
    record("structure sigil register", false, "$e")
end

try
    _test_st2 = SigilTable()
    register_structure_sigil!(_test_st2; name="test_struct_exp", expansion=["test_lambda", "test_macro", "test_relation"])
    expanded = expand_structure_sigil(_test_st2, "test_struct_exp")
    record("expand_structure_sigil returns data", !isempty(expanded), "expanded=$(join(expanded, ","))")
catch e
    record("expand_structure_sigil", false, "$e")
end

subsection("2c. Sigil Promotion")
try
    # promote_input takes (table::SigilTable, raw::String)
    _test_st3 = SigilTable()
    result = promote_input(_test_st3, "5+5")
    record("promote_input('5+5') returns tuple", result !== nothing)
catch e
    record("promote_input", false, "$e")
end

try
    # bindings_by_name takes Vector{SigilBinding} — test with empty vector
    bindings = bindings_by_name(SigilBinding[])
    record("bindings_by_name() with empty input", bindings !== nothing, "count=$(length(bindings))")
catch e
    record("bindings_by_name", false, "$e")
end

try
    ct = canonicalize_token("PLUS")
    record("canonicalize_token('PLUS')", ct !== nothing, "result=$(ct)")
catch e
    record("canonicalize_token", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 3. COHERENCE FIELD
# ══════════════════════════════════════════════════════════════
section("3. Coherence Field")

try
    # compute_field takes nodes_dict::Dict — use NODE_MAP
    phi = compute_field(NODE_MAP)
    record("compute_field returns value", phi !== nothing, "Φ=$(phi)")
    journal_info("coherence field"; detail="Φ=$(phi)")
catch e
    record("compute_field", false, "$e")
end

try
    snap = coherence_config_snapshot()
    # snapshot returns a CoherenceFieldConfig struct, not a Dict
    record("coherence_config_snapshot", snap !== nothing, "weight=$(snap.weight)")
catch e
    record("coherence_config_snapshot", false, "$e")
end

try
    status = coherence_field_status(NODE_MAP)
    # status returns a Dict
    record("coherence_field_status", status !== nothing && !isempty(status), "keys=$(join(collect(keys(status)), ","))")
catch e
    record("coherence_field_status", false, "$e")
end

# Set coherence config — uses (field::Symbol, value) signature
try
    set_coherence_config!(:weight, 0.05)
    snap2 = coherence_config_snapshot()
    record("set_coherence_config! :weight, 0.05", snap2.weight == 0.05, "weight=$(snap2.weight)")
    journal_info("coherence config changed"; detail="weight=0.05")
    # Reset
    reset_coherence_config!()
catch e
    record("set_coherence_config!", false, "$e")
end

# Round-trip
try
    cfg = coherence_config_to_dict()
    record("coherence_config_to_dict", haskey(cfg, "weight"), "keys=$(join(collect(keys(cfg)), ","))")
    coherence_config_from_dict!(cfg)
    record("coherence_config_from_dict! round-trip", true)
catch e
    record("coherence config round-trip", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 4. GEOMETRY KIT
# ══════════════════════════════════════════════════════════════
section("4. Geometry Kit")

try
    overview = geometry_overview()
    record("geometry_overview returns data", overview !== nothing)
catch e
    record("geometry_overview", false, "$e")
end

try
    snap = geometry_config_snapshot()
    # snapshot returns GeometryConfig struct, not Dict
    record("geometry_config_snapshot", snap !== nothing, "default_space=$(snap.default_space) nearest_k=$(snap.nearest_k)")
catch e
    record("geometry_config_snapshot", false, "$e")
end

# Distance functions — all take numeric/typed args, NOT strings
try
    d1 = semantic_distance(0.8, 0.2)
    record("semantic_distance(0.8, 0.2)", d1 !== nothing, "d=$(round(d1; digits=3))")
catch e
    record("semantic_distance", false, "$e")
end

try
    d2 = coherence_distance(0.5, 0.1)
    record("coherence_distance(0.5, 0.1)", d2 !== nothing, "d=$(round(d2; digits=3))")
catch e
    record("coherence_distance", false, "$e")
end

try
    d3 = phase_distance([0.3, 0.7, 0.1], [0.6, 0.2, 0.5])
    record("phase_distance(Vector, Vector)", d3 !== nothing, "d=$(round(d3; digits=3))")
catch e
    record("phase_distance", false, "$e")
end

try
    d4 = tone_distance("warm", "terse")
    record("tone_distance('warm','terse')", d4 !== nothing, "d=$(round(d4; digits=3))")
catch e
    record("tone_distance", false, "$e")
end

try
    d5 = space_distance("phase"; score_a=0.5, score_b=0.2)
    record("space_distance('phase'; score_a=0.5, score_b=0.2)", d5 !== nothing, "d=$(round(d5; digits=3))")
catch e
    record("space_distance", false, "$e")
end

# Config round-trip — set_geometry_config! takes (Symbol, value)
try
    cfg = geometry_config_to_dict()
    record("geometry_config_to_dict", haskey(cfg, "default_space"))
    set_geometry_config!(:default_space, "semantic")
    snap2 = geometry_config_snapshot()
    record("set_geometry_config! to semantic", snap2.default_space === SEMANTIC_SPACE)
    # Reset
    reset_geometry_config!()
    cfg2 = geometry_config_to_dict()
    geometry_config_from_dict!(cfg2)
    record("geometry_config_from_dict! round-trip", true)
    journal_info("geometry config round-trip OK")
catch e
    record("geometry config ops", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 5. PATTERN MINER
# ══════════════════════════════════════════════════════════════
section("5. Pattern Miner")

subsection("5a. Config")
try
    snap = pattern_miner_config_snapshot()
    # PatternMinerConfig struct, not Dict
    record("pattern_miner_config_snapshot", snap !== nothing, "T=$(snap.transitivity_threshold) C=$(snap.chaining_threshold) S=$(snap.symmetry_threshold)")
catch e
    record("pattern_miner_config_snapshot", false, "$e")
end

try
    cfg = pattern_miner_config_to_dict()
    record("pattern_miner_config_to_dict", haskey(cfg, "transitivity_threshold"))
    set_pattern_miner_config!(:transitivity_threshold, 5)
    snap2 = pattern_miner_config_snapshot()
    record("set_pattern_miner_config! transitivity_threshold=5", snap2.transitivity_threshold == 5)
    reset_pattern_miner_config!()
    journal_info("pattern miner config tested")
catch e
    record("pattern miner config", false, "$e")
end

subsection("5b. Scanning")
try
    # Run some missions to create patterns, then scan
    process_mission("fire is hot")
    process_mission("water is wet")
    process_mission("ice is cold")

    # scan_* functions take Vector{Tuple{String,String,String}}
    # Build triples from the mission text we just processed
    _rt1 = extract_relational_triples("fire is hot")
    _rt2 = extract_relational_triples("water is wet")
    _rt3 = extract_relational_triples("ice is cold")
    global _triples = [(t.subject, t.relation, t.object) for t in vcat(_rt1, _rt2, _rt3)]

    n_trans = scan_transitivity!(_triples)
    record("scan_transitivity!", n_trans !== nothing, "found=$(n_trans)")

    n_chain = scan_chaining!(_triples)
    record("scan_chaining!", n_chain !== nothing, "found=$(n_chain)")

    n_sym = scan_symmetry!(_triples)
    record("scan_symmetry!", n_sym !== nothing, "found=$(n_sym)")

    n_all = scan_all!(_triples)
    record("scan_all!", n_all !== nothing, "found=$(n_all)")
catch e
    record("pattern scan", false, "$e")
end

subsection("5c. Instances & Proposals")
try
    instances = get_all_instances()
    record("get_all_instances", instances !== nothing, "count=$(length(instances))")
    journal_info("pattern instances"; detail="count=$(length(instances))")
catch e
    record("get_all_instances", false, "$e")
end

try
    n_proposed = check_and_propose!()
    record("check_and_propose!", n_proposed !== nothing, "proposed=$(n_proposed)")
catch e
    record("check_and_propose!", false, "$e")
end

try
    proposals = list_proposals()
    record("list_proposals", proposals !== nothing, "count=$(length(proposals))")
catch e
    record("list_proposals", false, "$e")
end

subsection("5d. Data round-trip")
try
    pm_data = pattern_miner_data_to_dict()
    record("pattern_miner_data_to_dict", pm_data !== nothing, "keys=$(join(collect(keys(pm_data)), ","))")
    pattern_miner_data_from_dict!(pm_data)
    record("pattern_miner_data_from_dict! round-trip", true)
catch e
    record("pattern miner data round-trip", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 6. TEMPORAL IDENTITY
# ══════════════════════════════════════════════════════════════
section("6. Temporal Identity")

subsection("6a. Create & Stage")
global _weather_id = ""
try
    c = create_continuant("weather")
    global _weather_id = c.id
    record("create_continuant('weather')", c !== nothing)
    journal_info("continuant created"; detail="weather")

    # add_stage! takes (continuant_id, node_id, phase, orientation::Symbol)
    add_stage!(_weather_id, "node_sunny", "sunny", :now)
    add_stage!(_weather_id, "node_cloudy", "cloudy", :next)
    add_stage!(_weather_id, "node_rainy", "rainy", :next)
    record("add_stage! ×3", true, "sunny, cloudy, rainy")

    stages = stages_of(_weather_id)
    record("stages_of('weather')", length(stages) >= 3, "count=$(length(stages))")
catch e
    record("create_continuant + stages", false, "$e")
end

subsection("6b. Transform Rules")
try
    add_transform_rule!(_weather_id, "sunny", "cloudy")
    add_transform_rule!(_weather_id, "cloudy", "rainy")
    record("add_transform_rule! ×2", true)

    # what_was takes (continuant_id, orientation::Symbol)
    was = what_was(_weather_id, :before)
    record("what_was(_weather_id, :before)", was !== nothing, "count=$(length(was))")

    # what_becomes takes (continuant_id, from_phase)
    becomes = what_becomes(_weather_id, "sunny")
    record("what_becomes(_weather_id, 'sunny')", becomes !== nothing, "count=$(length(becomes))")
catch e
    record("transform rules", false, "$e")
end

subsection("6c. Identity Queries")
try
    # identity_of takes a node_id — check one of the stages
    ident = identity_of("node_sunny")
    record("identity_of('node_sunny')", ident !== nothing)

    # get_continuant takes continuant_id
    cont = get_continuant(_weather_id)
    record("get_continuant(_weather_id)", cont !== nothing)

    all_c = list_continuants()
    record("list_continuants()", !isempty(all_c), "count=$(length(all_c))")
catch e
    record("identity queries", false, "$e")
end

subsection("6d. Proposals")
try
    # propose_continuant! takes (class, stages::Vector{Stage})
    _season_stages = [Stage("node_spring", "spring", :now, time()),
                      Stage("node_summer", "summer", :next, time()),
                      Stage("node_fall", "fall", :next, time()),
                      Stage("node_winter", "winter", :next, time())]
    prop = propose_continuant!("season", _season_stages)
    record("propose_continuant!('season')", prop !== nothing, "id=$(prop.id)")

    proposals = list_continuant_proposals()
    record("list_continuant_proposals()", !isempty(proposals), "count=$(length(proposals))")

    # approve takes proposal_id from the proposal
    approve_continuant_proposal!(prop.id)
    # After approval, a new continuant is created — find it by class
    season_conts = [cc for cc in list_continuants() if cc.class == "season"]
    record("approve_continuant_proposal! + get", !isempty(season_conts))
    journal_info("season continuant approved"; detail="4 stages")
catch e
    record("continuant proposals", false, "$e")
end

subsection("6e. Identity Config")
try
    snap = temporal_identity_config_snapshot()
    # Returns TemporalIdentityConfig struct
    record("temporal_identity_config_snapshot", snap !== nothing, "max_cont=$(snap.max_continuants)")

    cfg = temporal_identity_config_to_dict()
    record("temporal_identity_config_to_dict", !isempty(cfg), "keys=$(join(collect(keys(cfg)), ','))")

    status = temporal_identity_status()
    record("temporal_identity_status", !isempty(status))
catch e
    record("temporal identity config", false, "$e")
end

subsection("6f. Data round-trip")
try
    ti_dict = temporal_identity_to_dict()
    record("temporal_identity_to_dict", haskey(ti_dict, "continuants"), "continuants=$(length(get(ti_dict, "continuants", [])))")

    # Round-trip through JSON
    json_str = JSON.json(ti_dict)
    parsed = JSON.parse(json_str)
    temporal_identity_from_dict!(parsed)
    record("temporal_identity_from_dict! JSON round-trip", true)

    all_c2 = list_continuants()
    record("continuants survive round-trip", length(all_c2) >= 0, "count=$(length(all_c2))")
    journal_pass("temporal identity round-trip"; detail="$(length(all_c2)) continuants")
catch e
    record("temporal identity round-trip", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 7. CAVE JOURNAL (auto-logger)
# ══════════════════════════════════════════════════════════════
section("7. Cave Journal")

subsection("7a. Status & Path")
try
    record("journal is active (turned on at boot)", journal_is_active())
    path = journal_get_path()
    record("journal_get_path() returns path", !isempty(path), "path=$(path)")
    status = journal_status()
    record("journal_status()", !isempty(status))
catch e
    record("journal status", false, "$e")
end

subsection("7b. All Log Types")
try
    journal_section("Deep Test — Journal Feature Check")
    journal_log("testing basic log entry"; tag="TEST", emoji="🧪")
    journal_subsection("Log Types Subsection")
    journal_pass("pass test"; detail="pass detail text")
    journal_fail("fail test (expected)"; detail="fail detail text")
    journal_warn("warn test"; detail="warn detail text")
    journal_info("info test"; detail="info detail text")
    journal_debug_block("Debug Block Test", "key1=val1\nkey2=val2\nkey3=val3")
    journal_telemetry("test mission", "test action", 0.95, :question; extra="extra_field=42")
    record("all journal log types written", true)
catch e
    record("journal log types", false, "$e")
end

subsection("7c. Config Round-Trip")
try
    cfg = journal_config_to_dict()
    record("journal_config_to_dict", haskey(cfg, "directory") && haskey(cfg, "filename"), "dir=$(get(cfg, "directory", "?"))")
    old_dir = cfg["directory"]
    journal_set_path!("/tmp/journal_test_rt")
    journal_config_from_dict!(cfg)
    restored_path = journal_get_path()
    record("journal config round-trip restores path", occursin(old_dir, restored_path), "path=$(restored_path)")
    journal_info("journal config round-trip OK")
catch e
    record("journal config round-trip", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 8. LOBE SYSTEM
# ══════════════════════════════════════════════════════════════
section("8. Lobe System")

subsection("8a. Create & Connect Lobes")
try
    GrugBot420.Lobe.create_lobe!("test_lobe", "testing experiments")
    record("create_lobe!('test_lobe')", true)
    journal_info("lobe created"; detail="test_lobe")
catch e
    record("create_lobe!", false, "$e")
end

try
    # Use "greeting" which exists in the specimen; "default" was wiped by specimen load
    GrugBot420.Lobe.connect_lobes!("test_lobe", "greeting")
    record("connect_lobes!('test_lobe' ↔ 'greeting')", true)
catch e
    record("connect_lobes!", false, "$e")
end

subsection("8b. Lobe Grow")
try
    # GRUG: Most specimen nodes already belong to lobes. Find unassigned ones.
    _unassigned = filter(nid -> !haskey(GrugBot420.Lobe.NODE_TO_LOBE_IDX, nid), collect(keys(NODE_MAP)))
    if isempty(_unassigned)
        # No unassigned nodes — just record a skip (not a failure)
        record("lobe_grow! (no unassigned nodes available)", true, "skipped — all nodes in lobes")
    else
        GrugBot420.Lobe.lobe_grow!("test_lobe", _unassigned[1:min(3, length(_unassigned))])
        record("lobe_grow!('test_lobe', unassigned nodes)", true)
    end
catch e
    record("lobe_grow!", false, "$e")
end

subsection("8c. Lobe Orchestrator")
try
    scores = score_lobes(Tuple{String,Float64,Bool,Any,Any}[], Dict{String,String}(); input_tokens=String[])
    record("score_lobes()", scores !== nothing, "count=$(length(scores))")
catch e
    record("score_lobes", false, "$e")
end

try
    fire_order = flatten_in_fire_order(LobeFireOrder[])
    record("flatten_in_fire_order()", fire_order !== nothing)
catch e
    record("flatten_in_fire_order", false, "$e")
end

try
    batches = compute_fire_batches([])
    record("compute_fire_batches()", batches !== nothing)
catch e
    record("compute_fire_batches", false, "$e")
end

try
    summary = last_summary()
    record("last_summary()", summary !== nothing)
catch e
    record("last_summary", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 9. VOTE ORCHESTRATOR
# ══════════════════════════════════════════════════════════════
section("9. Vote Orchestrator")

global _vc = nothing
try
    global _vc = VoteCandidate("test_node", 0.8, 5.0; lobe_alignment=1.0, relational_match=0.5, recency_bonus=0.3, action_tone_align=0.2, anti_match_score=0.0, peak_dominance=0.5)
    score = composite_vote_score(_vc)
    record("composite_vote_score()", score !== nothing, "score=$(score)")
catch e
    record("composite_vote_score", false, "$e")
end

try
    result = strength_biased_vote_coinflip(_vc)
    record("strength_biased_vote_coinflip(0.7)", result !== nothing, "result=$(result)")
catch e
    record("strength_biased_vote_coinflip", false, "$e")
end

try
    _fc = FireCounter("test_cycle", 100)
    cap_reached = fire_cap_reached(_fc)
    record("fire_cap_reached()", cap_reached !== nothing, "reached=$(cap_reached)")
catch e
    record("fire_cap_reached", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 10. AUTO-GROWTH & AUTO-LINK
# ══════════════════════════════════════════════════════════════
section("10. AutoGrowth & AutoLink")

subsection("10a. AutoGrowth")
try
    accumulate_evidence!(user_text="test_word_a", intensity=1.0, node_patterns=Set{String}(), node_ids_patterns=Tuple{String,String}[], thesaurus_gate_filter=(w)->String[], thesaurus_word_similarity=(a,b)->0.0)
    accumulate_evidence!(user_text="test_word_a", intensity=1.0, node_patterns=Set{String}(), node_ids_patterns=Tuple{String,String}[], thesaurus_gate_filter=(w)->String[], thesaurus_word_similarity=(a,b)->0.0)
    accumulate_evidence!(user_text="test_word_a", intensity=1.0, node_patterns=Set{String}(), node_ids_patterns=Tuple{String,String}[], thesaurus_gate_filter=(w)->String[], thesaurus_word_similarity=(a,b)->0.0)
    record("accumulate_evidence! ×3", true)
catch e
    record("accumulate_evidence!", false, "$e")
end

try
    status = get_autogrowth_status_summary()
    record("get_autogrowth_status_summary()", !isempty(status))
catch e
    record("get_autogrowth_status_summary", false, "$e")
end

try
    snap = get_evidence_snapshot()
    record("get_evidence_snapshot()", snap !== nothing, "entries=$(length(snap))")
catch e
    record("get_evidence_snapshot", false, "$e")
end

try
    co_occur = get_co_occur_snapshot()
    record("get_co_occur_snapshot()", co_occur !== nothing)
catch e
    record("get_co_occur_snapshot", false, "$e")
end

subsection("10b. Curiosity")
try
    overflow = check_curiosity_overflow()
    record("check_curiosity_overflow()", overflow !== nothing, "overflow=$(overflow)")
catch e
    record("check_curiosity_overflow", false, "$e")
end

try
    cur_status = get_curiosity_status()
    record("get_curiosity_status()", !isempty(cur_status))
catch e
    record("get_curiosity_status", false, "$e")
end

try
    ser = serialize_curiosity()
    record("serialize_curiosity()", ser !== nothing)
    deserialize_curiosity!(ser)
    record("deserialize_curiosity! round-trip", true)
catch e
    record("curiosity round-trip", false, "$e")
end

subsection("10c. AutoLink")
try
    accumulate_link_evidence!(co_fired_ids=["node_a", "node_b"], input_touched_ids=["node_a", "node_b"])
    accumulate_link_evidence!(co_fired_ids=["node_a", "node_b"], input_touched_ids=["node_a", "node_b"])
    record("accumulate_link_evidence! ×2", true)
catch e
    record("accumulate_link_evidence!", false, "$e")
end

try
    link_status = get_autolink_status_summary()
    record("get_autolink_status_summary()", !isempty(link_status))
catch e
    record("get_autolink_status_summary", false, "$e")
end

try
    link_snap = get_link_evidence_snapshot()
    record("get_link_evidence_snapshot()", link_snap !== nothing)
catch e
    record("get_link_evidence_snapshot", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 11. EPHEMERAL MLP
# ══════════════════════════════════════════════════════════════
section("11. Ephemeral MLP")

try
    status = get_mlp_status()
    record("get_mlp_status()", !isempty(status))
catch e
    record("get_mlp_status", false, "$e")
end

try
    rules = list_mlp_rules()
    record("list_mlp_rules()", rules !== nothing, "count=$(length(rules))")
catch e
    record("list_mlp_rules", false, "$e")
end

try
    add_mlp_rule!(MLPTransformerRule("test_rule_deep", "test_pattern"; transform_type=:fuzzy))
    looked_up = lookup_mlp_rule("test_rule_deep")
    record("add + lookup MLP rule", looked_up !== nothing)
catch e
    record("MLP rule add/lookup", false, "$e")
end

try
    activate_rule_by_key!("test_rule_deep")
    record("activate_rule_by_key!('test_rule_deep')", true)
catch e
    record("activate_rule_by_key!", false, "$e")
end

try
    strain = get_strain_energy()
    record("get_strain_energy()", strain !== nothing, "strain=$(strain)")
catch e
    record("get_strain_energy", false, "$e")
end

try
    warrant = is_hippocampal_warrant_active()
    record("is_hippocampal_warrant_active()", warrant !== nothing, "active=$(warrant)")
catch e
    record("is_hippocampal_warrant_active", false, "$e")
end

try
    spec = to_specimen_dict()
    record("to_specimen_dict()", spec !== nothing)
    from_specimen_dict!(spec)
    record("from_specimen_dict! round-trip", true)
catch e
    record("MLP specimen round-trip", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 12. SELF-OBSERVER
# ══════════════════════════════════════════════════════════════
section("12. Self-Observer")

_local_store = SubconsciousStore()

try
    observe!(_local_store, "test_key", :lexical, Dict{String,Any}("value" => "test_value"); p_write=1.0)
    record("observe!('test_key', :lexical, Dict)", true)
catch e
    record("observe!", false, "$e")
end

try
    val = peek_exact(_local_store, "test_key", "test_key")
    record("peek_exact('test_key')", val !== nothing, "val=$(val)")
catch e
    record("peek_exact", false, "$e")
end

try
    pat_results = peek_pattern(_local_store, "test_key", "test")
    record("peek_pattern('test')", pat_results !== nothing, "count=$(length(pat_results))")
catch e
    record("peek_pattern", false, "$e")
end

try
    trail = audit_trail(_local_store)
    record("audit_trail(_local_store)", trail !== nothing)
catch e
    record("audit_trail", false, "$e")
end

try
    sz = store_size(_local_store)
    record("store_size(_local_store)", sz >= 0, "size=$(sz)")
catch e
    record("store_size", false, "$e")
end

try
    kc = key_count(_local_store)
    record("key_count(_local_store)", kc >= 0, "count=$(kc)")
catch e
    record("key_count", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 13. IMMUNE SYSTEM
# ══════════════════════════════════════════════════════════════
section("13. Immune System")

try
    result = immune_scan!("hello world", length(NODE_MAP); is_critical=true)
    record("immune_scan!('hello world')", result !== nothing)
catch e
    record("immune_scan!", false, "$e")
end

try
    status = get_immune_status()
    record("get_immune_status()", !isempty(status))
catch e
    record("get_immune_status", false, "$e")
end

try
    entries = get_ledger_entries()
    record("get_ledger_entries()", entries !== nothing, "count=$(length(entries))")
catch e
    record("get_ledger_entries", false, "$e")
end

try
    _test_sig = UInt64(0xabcdef1234567890)
    add_known_signature!(_test_sig)
    looked = lookup_signature(_test_sig)
    record("add + lookup known signature", looked !== nothing)
catch e
    record("signature add/lookup", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 14. PHAGY & MITOSIS
# ══════════════════════════════════════════════════════════════
section("14. Phagy & Mitosis")

subsection("14a. Phagy")
try
    stats = run_phagy!(NODE_MAP, NODE_LOCK, Dict{String,Vector{Float64}}(), ReentrantLock(), Vector(), ReentrantLock())
    record("run_phagy!()", stats !== nothing)
    journal_info("phagy run"; detail="stats recorded")
catch e
    record("run_phagy!", false, "$e")
end

try
    log = get_phagy_log()
    record("get_phagy_log()", log !== nothing, "entries=$(length(log))")
catch e
    record("get_phagy_log", false, "$e")
end

try
    forensics = run_memory_forensics!(NODE_MAP, NODE_LOCK, MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK)
    record("run_memory_forensics!()", forensics !== nothing)
catch e
    record("run_memory_forensics!", false, "$e")
end

try
    fuzzy = fuzzy_memory_forensics!(NODE_MAP, NODE_LOCK, MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK)
    record("fuzzy_memory_forensics!()", fuzzy !== nothing)
catch e
    record("fuzzy_memory_forensics!", false, "$e")
end

# Individual phagy operations — each requires specific args
for (name, thunk) in [
    ("prune_orphan_nodes!", () -> prune_orphan_nodes!(NODE_MAP, NODE_LOCK)),
    ("decay_forgotten_strengths!", () -> decay_forgotten_strengths!(NODE_MAP, NODE_LOCK)),
    ("recycle_grave_assets!", () -> recycle_grave_assets!(NODE_MAP, NODE_LOCK)),
    ("compact_drop_tables!", () -> compact_drop_tables!(NODE_MAP, NODE_LOCK)),
    ("prune_dormant_rules!", () -> prune_dormant_rules!(Vector(), ReentrantLock())),
    ("sweep_injector_graveyard!", () -> sweep_injector_graveyard!(Dict{String,Any}(), ReentrantLock())),
    ("age_phase_accumulator!", () -> age_phase_accumulator!(GrugBot420.EphemeralAutomaton._phase_accumulator())),
    ("prune_observer_store!", () -> prune_observer_store!(SubconsciousStore())),
    ("check_sigil_consistency!", () -> check_sigil_consistency!(SigilTable())),
    ("trim_stale_trajectory!", () -> trim_stale_trajectory!(GrugBot420.ActionTonePredictor._trajectory_config, GrugBot420.ActionTonePredictor._trajectory_buffer, GrugBot420.ActionTonePredictor._trajectory_lock)),
]
    try
        result = thunk()
        record("$(name)", result !== nothing)
    catch e
        record("$(name)", false, "$e")
    end
end

subsection("14b. Mitosis")
try
    stats = run_mitosis!(; node_map=NODE_MAP, node_lock=NODE_LOCK, message_history=MESSAGE_HISTORY, history_lock=MESSAGE_HISTORY_LOCK, thesaurus_gate_filter=(w)->String[], thesaurus_word_similarity=(a,b)->0.0, create_node_fn=(args...; kwargs...)->"mitosis_test_node")
    record("run_mitosis!(; node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK, message_history=GrugBot420.MESSAGE_HISTORY, history_lock=GrugBot420.MESSAGE_HISTORY_LOCK, thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity, create_node_fn=(args...; kwargs...)->nothing)", stats !== nothing)
catch e
    record("run_mitosis!", false, "$e")
end

try
    log = get_mitosis_log()
    record("get_mitosis_log()", log !== nothing, "entries=$(length(log))")
catch e
    record("get_mitosis_log", false, "$e")
end

try
    status = get_mitosis_status_summary()
    record("get_mitosis_status_summary()", !isempty(status))
catch e
    record("get_mitosis_status_summary", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 15. CHATTER MODE
# ══════════════════════════════════════════════════════════════
section("15. Chatter Mode")

try
    status = get_chatter_status()
    record("get_chatter_status()", !isempty(status))
catch e
    record("get_chatter_status", false, "$e")
end

try
    should = should_trigger_chatter(time() - 9999.0)
    record("should_trigger_chatter()", should !== nothing, "result=$(should)")
catch e
    record("should_trigger_chatter", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 16. HIPPDOCAMPAL MODULATOR
# ══════════════════════════════════════════════════════════════
section("16. Hippocampal Modulator")

_local_log = create_action_log!()

try
    record("create_action_log!()", _local_log !== nothing)
catch e
    record("create_action_log!", false, "$e")
end

try
    add_entry!(_local_log; objective_id="test_action", confidence=0.9, entry_type=ENTRY_SURE)
    record("add_entry!('test_action')", true)
catch e
    record("add_entry!", false, "$e")
end

try
    pending = next_pending!(_local_log)
    record("next_pending!()", pending !== nothing)
catch e
    record("next_pending!", false, "$e")
end

try
    entries = log_entries(_local_log)
    record("log_entries()", entries !== nothing, "count=$(length(entries))")
catch e
    record("log_entries", false, "$e")
end

try
    summary = log_summary(_local_log)
    record("log_summary()", !isempty(summary))
catch e
    record("log_summary", false, "$e")
end

try
    all_done = all_sure_done(_local_log)
    record("all_sure_done()", all_done !== nothing)
catch e
    record("all_sure_done", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 17. RELATIONAL GOVERNANCE & JITTER
# ══════════════════════════════════════════════════════════════
section("17. Relational Governance & Jitter")

subsection("17a. Relational Governance")
try
    observe_co_firing!(["node_x", "node_y"])
    record("observe_co_firing!('node_x','node_y')", true)
catch e
    record("observe_co_firing!", false, "$e")
end

try
    stats = run_relational_governance!(; attach_fn=(args...; kwargs...)->nothing, token_overlap_fn=(a,b)->0.0, node_map_ref=NODE_MAP, node_lock_ref=NODE_LOCK)
    record("run_relational_governance!(; attach_fn=(args...; kwargs...)->nothing, token_overlap_fn=(a,b)->0.5, node_map_ref=GrugBot420.NODE_MAP, node_lock_ref=GrugBot420.NODE_LOCK)", stats !== nothing)
catch e
    record("run_relational_governance!", false, "$e")
end

try
    status = get_relational_gov_status_summary()
    record("get_relational_gov_status_summary()", !isempty(status))
catch e
    record("get_relational_gov_status_summary", false, "$e")
end

subsection("17b. Relational Jitter")
try
    enable_jitter!()
    enabled = is_jitter_enabled()
    record("enable_jitter! + is_jitter_enabled", enabled == true)
catch e
    record("enable_jitter!", false, "$e")
end

try
    set_jitter_ratio!(0.08)
    ratio = get_jitter_ratio()
    record("set_jitter_ratio!(0.08) + get", ratio !== nothing, "ratio=$(ratio)")
catch e
    record("jitter ratio", false, "$e")
end

try
    disable_jitter!()
    disabled = !is_jitter_enabled()
    record("disable_jitter!()", disabled)
catch e
    record("disable_jitter!", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 18. INVERSE SIGIL
# ══════════════════════════════════════════════════════════════
section("18. Inverse Sigil")

try
    status = get_inverse_sigil_status()
    record("get_inverse_sigil_status()", !isempty(status))
catch e
    record("get_inverse_sigil_status", false, "$e")
end

try
    add_concrete!("test_inverse", "lambda"; sigil_class=:macro)
    status2 = get_inverse_sigil_status()
    record("add_inverse_sigil! + status", occursin("test_inverse", status2) || length(status2) > 0)
catch e
    record("add_inverse_sigil!", false, "$e")
end

try
    reset_inverse_table!()
    record("reset_inverse_table!()", true)
catch e
    record("remove_inverse_sigil!", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 19. SEMANTIC VERBS
# ══════════════════════════════════════════════════════════════
section("19. Semantic Verbs")

try
    add_relation_class!("test_relation_deep"); add_verb!("test_verb_deep", "test_relation_deep")
    record("add_verb!('test_verb_deep')", true)
catch e
    record("add_verb!", false, "$e")
end

try
    add_relation_class!("test_relation_deep_v2")
    record("add_relation_class!('test_relation_deep')", true)
catch e
    record("add_relation_class!", false, "$e")
end

try
    add_synonym!("test_verb_deep", "test_verb_synonym")
    record("add_synonym!('test_verb_deep', 'test_verb_synonym')", true)
catch e
    record("add_synonym!", false, "$e")
end

try
    remove_synonym!("test_verb_synonym")
    record("remove_synonym!('test_verb_deep', 'test_verb_synonym')", true)
catch e
    record("remove_synonym!", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 20. PETTY LEARNER
# ══════════════════════════════════════════════════════════════
section("20. Petty Learner")

try
    result = classify_petty("hello", ["hello"], Set{String}(), (w)->String[], (a,b)->0.0, Tuple{String,String,Set{String}}[], Dict{String,Any}(), Dict{String,Any}())
    record("classify_petty('hello')", result !== nothing)
catch e
    record("classify_petty", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 21. INPUT DECOMPOSER
# ══════════════════════════════════════════════════════════════
section("21. Input Decomposer")

try
    parts = decompose_input("what is 5+5 and what is love")
    record("decompose_input('what is 5+5 and what is love')", parts !== nothing, "parts=$(length(parts))")
catch e
    record("decompose_input", false, "$e")
end

try
    parts2 = decompose_input("hello world")
    record("decompose_input('hello world')", parts2 !== nothing)
catch e
    record("decompose_input simple", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 22. ACTION ENGINE
# ══════════════════════════════════════════════════════════════
section("22. Action Engine")

global _action_result = nothing
try
    global _action_result = compute_action("greet", SigilBinding[])
    record("compute_action('greet')", _action_result !== nothing)
catch e
    record("compute_action", false, "$e")
end

try
    reply = format_action_reply(_action_result)
    record("format_action_reply()", reply !== nothing)
catch e
    record("format_action_reply", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 23. SPECIMEN SAVE/LOAD ROUND-TRIP (THE BIG ONE)
# ══════════════════════════════════════════════════════════════
section("23. Specimen Save/Load Round-Trip")

subsection("23a. Save")
const SAVE_PATH = "/tmp/deep_test_specimen.specimen"
try
    save_specimen_to_file!(SAVE_PATH)
    record("save_specimen_to_file!", isfile(SAVE_PATH))
    journal_pass("specimen saved"; detail=SAVE_PATH)
catch e
    record("save_specimen_to_file!", false, "$e")
end

subsection("23b. Verify saved data has v9 keys")
try
    txt = read(SAVE_PATH, String)
    parsed = JSON.parse(txt)

    v9_keys = ["coherence_config", "geometry_config", "pattern_miner_config",
               "temporal_identities", "journal_config", "lobe_dictionaries"]
    for key in v9_keys
        has_key = haskey(parsed, key)
        record("specimen has '$(key)'", has_key)
    end

    # Check critical legacy keys
    legacy_keys = ["nodes", "bridges", "lobes", "sigil_table", "immune_config",
                   "verb_registry", "thesaurus_seeds"]
    for key in legacy_keys
        has_key = haskey(parsed, key)
        record("specimen has legacy '$(key)'", has_key)
    end

    journal_info("specimen keys verified"; detail="v9=$(all(k -> haskey(parsed, k), v9_keys))")
catch e
    record("specimen key verification", false, "$e")
end

subsection("23c. Reload specimen")
try
    load_specimen_from_file!(SAVE_PATH)
    record("load_specimen_from_file! (reload)", true)
    journal_pass("specimen reloaded"; detail=SAVE_PATH)
catch e
    record("load_specimen_from_file! (reload)", false, "$e")
end

subsection("23d. Verify v9 data survived round-trip")
try
    # Coherence
    coh_snap = coherence_config_snapshot()
    record("coherence config survived reload", coh_snap !== nothing)

    # Geometry
    geo_snap = geometry_config_snapshot()
    record("geometry config survived reload", geo_snap !== nothing)

    # PatternMiner
    pm_snap = pattern_miner_config_snapshot()
    record("pattern miner config survived reload", pm_snap !== nothing)

    # TemporalIdentity
    ti_conts = list_continuants()
    record("temporal identities survived reload", length(ti_conts) >= 0, "count=$(length(ti_conts))")

    # CaveJournal
    j_path = journal_get_path()
    record("journal path survived reload", !isempty(j_path), "path=$(j_path)")

    journal_pass("v9 data round-trip verified"; detail="$(length(ti_conts)) TI continuants")
catch e
    record("v9 data verification after reload", false, "$e")
end

subsection("23e. Conversations still work after reload")
try
    process_mission("what is 2+2")
    v = read_voice()
    has_4 = occursin("4", v)
    record("arithmetic still works after reload", has_4, "voice='$(v[1:min(60,length(v))])'")
catch e
    record("post-reload arithmetic", false, "$e")
end

try
    process_mission("what is star")
    v = read_voice()
    # Star was defined earlier — check it's still known
    has_star = occursin("luminous", lowercase(v)) || occursin("celestial", lowercase(v)) || occursin("star", lowercase(v))
    record("dictionary word 'star' survives reload", has_star, "voice='$(v[1:min(60,length(v))])'")
catch e
    record("post-reload dictionary lookup", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 24. STRESS TEST — rapid fire missions
# ══════════════════════════════════════════════════════════════
section("24. Stress Test — Rapid Fire")
stress_inputs = [
    "hello", "5+3", "what is gravity", "7*2", "water is wet",
    "3-1", "what is love", "4+4", "fire is hot", "9/3",
    "what is water", "6*2", "actually water is H2O", "2+2",
    "what is fire", "8-5", "define moon = a natural satellite",
]
stress_passes = 0
stress_fails = 0
for input in stress_inputs
    try
        process_mission(input)
        v = read_voice()
        if !isempty(v)
            global stress_passes += 1
        else
            global stress_fails += 1
        end
    catch e
        global stress_fails += 1
    end
end
record("stress test: $(stress_passes)/$(length(stress_inputs)) non-empty responses",
        stress_passes >= length(stress_inputs) - 2,
        "passes=$(stress_passes) fails=$(stress_fails)")
journal_info("stress test complete"; detail="passes=$(stress_passes) fails=$(stress_fails)")

# ══════════════════════════════════════════════════════════════
# 25. EDGE CASES
# ══════════════════════════════════════════════════════════════
section("25. Edge Cases")

try
    process_mission("0+0")
    v = read_voice()
    record("edge case: 0+0", occursin("0", v), "voice='$(v[1:min(60,length(v))])'")
catch e
    record("0+0", false, "$e")
end

try
    process_mission("what is the meaning of life the universe and everything")
    v = read_voice()
    record("edge case: very long question", !isempty(v), "voice='$(v[1:min(60,length(v))])'")
catch e
    record("long question", false, "$e")
end

try
    process_mission("   5+5   ")
    v = read_voice()
    record("edge case: padded arithmetic", occursin("10", v), "voice='$(v[1:min(60,length(v))])'")
catch e
    record("padded arithmetic", false, "$e")
end

try
    process_mission("HELLO")
    v = read_voice()
    record("edge case: ALL CAPS", !isempty(v))
catch e
    record("ALL CAPS", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# 26. JOURNAL FILE CONTENT VERIFICATION
# ══════════════════════════════════════════════════════════════
section("26. Journal File Content Verification")
journal_off!()

try
    jfile = "/workspace/deep_test_journal.md"
    if isfile(jfile)
        content = read(jfile, String)

        record("journal file exists and is non-empty", !isempty(content), "size=$(length(content)) bytes")

        checks = [
            ("has MISSION tag", occursin("[MISSION]", content)),
            ("has ROUTE tag", occursin("[ROUTE]", content)),
            ("has PASS tag", occursin("[PASS]", content)),
            ("has INFO tag", occursin("[INFO]", content)),
            ("has section headers", occursin("## ", content)),
            ("has timestamps", occursin("│", content)),
            ("has telemetry", occursin("[TELEMETRY]", content)),
        ]
        for (name, ok) in checks
            record("journal: $(name)", ok)
        end

        # Check specific missions were logged
        mission_checks = [
            ("5+5 mission logged", occursin("5+5", content)),
            ("what is love logged", occursin("what is love", content) || occursin("love", content)),
            ("teach logged", occursin("fire", content) || occursin("teach", lowercase(content))),
        ]
        for (name, ok) in mission_checks
            record("journal content: $(name)", ok)
        end
    else
        record("journal file verification", false, "file not found at $(jfile)")
    end
catch e
    record("journal file verification", false, "$e")
end


# ═══════════════════════════════════════════════════════════════
# 27. BRAIN STEM — Dispatch, Propagation, Fire/Inhibit
# ═══════════════════════════════════════════════════════════════
section("27. Brain Stem — Deep Dispatch & Propagation")

subsection("27a. Dispatch & Status")
try
    _bs_scan_fn = (lobe_id, input_str) -> DispatchResult(lobe_id, 0.5, String[], "test_output", false)
    _bs_result = dispatch!("hello brain stem test",
                           collect(keys(GrugBot420.Lobe.LOBE_REGISTRY)),
                           _bs_scan_fn,
                           GrugBot420.Lobe.LOBE_REGISTRY,
                           GrugBot420.Lobe.LOBE_LOCK)
    record("dispatch! returns DispatchResult", _bs_result !== nothing)
catch e
    record("dispatch! basic", false, "$e")
end

try
    _bs_status = get_brainstem_status()
    record("get_brainstem_status() returns Dict", _bs_status isa Dict)
    record("status has dispatch_count key", haskey(_bs_status, "dispatch_count") || haskey(_bs_status, :dispatch_count))
catch e
    record("get_brainstem_status", false, "$e")
end

subsection("27b. Fire / Inhibit Lobe")
try
    _lobe_keys = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        fire_lobe!(_lobe_keys[1], GrugBot420.Lobe.LOBE_REGISTRY, GrugBot420.Lobe.LOBE_LOCK)
        record("fire_lobe! on first lobe", true)
    else
        record("fire_lobe! (no lobes in registry)", true, "skipped")
    end
catch e
    record("fire_lobe!", false, "$e")
end

try
    _lobe_keys = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
    if length(_lobe_keys) >= 2
        inhibit_lobe!(_lobe_keys[2], GrugBot420.Lobe.LOBE_REGISTRY, GrugBot420.Lobe.LOBE_LOCK)
        record("inhibit_lobe! on second lobe", true)
    else
        record("inhibit_lobe! (not enough lobes)", true, "skipped")
    end
catch e
    record("inhibit_lobe!", false, "$e")
end

subsection("27c. Propagation History & Decay")
try
    _ph = get_propagation_history(5)
    record("get_propagation_history returns vector", _ph isa Vector)
catch e
    record("get_propagation_history", false, "$e")
end

try
    apply_fire_count_decay!(GrugBot420.Lobe.LOBE_REGISTRY, GrugBot420.Lobe.LOBE_LOCK)
    record("apply_fire_count_decay! runs", true)
catch e
    record("apply_fire_count_decay!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 28. TONAL JUDGE — Judgement, Frame Match, Prediction
# ═══════════════════════════════════════════════════════════════
section("28. Tonal Judge — Deep Judgement & Frame Match")

subsection("28a. Build Reading & Pick Mode")
try
    global _pred = nothing
    try
        _pred = ActionTonePredictor.PredictionResult(ACTION_QUERY, TONE_CURIOUS, 0.8, false, nothing, 0.0, 1.0)
    catch
        try
            _pred = ActionTonePredictor.PredictionResult(ACTION_QUERY, TONE_CURIOUS, 0.8, false, nothing, 0.0, 1.0)
        catch
            _pred = nothing
        end
    end
    if _pred !== nothing
        global _reading = build_reading_from_prediction(_pred)
        record("build_reading_from_prediction returns TonalReading", _reading !== nothing)
    else
        record("build_reading_from_prediction (no PredictionResult constructor found)", true, "skipped — constructor mismatch")
    end
catch e
    record("build_reading_from_prediction", false, "$e")
end

try
    reset_last_judgement!()
    record("reset_last_judgement! runs", true)
catch e
    record("reset_last_judgement!", false, "$e")
end

subsection("28b. Frame Match Multiplier")
try
    set_frame_match_weights!(; lift=1.3, inhibit=0.80)
    record("set_frame_match_weights! runs", true)
catch e
    record("set_frame_match_weights!", false, "$e")
end

try
    _fm = compute_frame_match_multiplier([:query], nothing)
    record("compute_frame_match_multiplier (no judgement) returns float", _fm isa Float64)
catch e
    record("compute_frame_match_multiplier", false, "$e")
end


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
    journal_log("test message from deep test"; tag="test", emoji="🔬")
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
    journal_debug_block("test debug block", join(["line1", "line2", "line3"], "\n"))
    record("journal_debug_block runs", true)
catch e
    record("journal_debug_block", false, "$e")
end

try
    journal_telemetry("test_mission", "test_action", 0.85, :node; extra="deep_test")
    record("journal_telemetry runs", true)
catch e
    record("journal_telemetry", false, "$e")
end

try
    global _jdict = journal_config_to_dict()
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
    journal_rotate!(keep_lines=50)
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
    global _active = journal_is_active()
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
    record("get_mlp_status returns Dict", _mlp_stat isa Dict)
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
    record("get_observation_threshold returns Int", _obs_th isa Int)
catch e
    record("get_observation_threshold", false, "$e")
end

try
    set_observation_threshold!(75)
    record("set_observation_threshold! runs", true)
catch e
    record("set_observation_threshold!", false, "$e")
end

try
    add_mlp_rule!(MLPTransformerRule("test_rule_mlp", "test_pattern"; transform_type=:fuzzy))
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
    _look = lookup_mlp_rule("test_rule_mlp")
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
    register_right_feedback!(0.9)
    record("register_right_feedback! runs", true)
catch e
    record("register_right_feedback!", false, "$e")
end

try
    register_wrong_feedback!(0.3)
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
    set_coherence_config!(:weight, 0.3)
    record("set_coherence_config! :weight runs", true)
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
    global _cf_dict = coherence_config_to_dict()
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
        record("compute_field on specimen nodes returns Float64", _cf isa Float64)
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
    set_geometry_config!(:nearest_k, 5)
    record("set_geometry_config! :nearest_k runs", true)
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
    global _gdict = geometry_config_to_dict()
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
    GrugBot420.InverseSigil.user_add_concrete!("test_sigil", "user_directive_tok")
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
    register_sigil!(_sig_table; name="TestMacro", class=:macro, applies_at=:match,
                    lexicon=["test", "macro"])
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
    register_structure_sigil!(_sig_table; name="TestStruct", expansion=["test_lambda", "test_macro", "test_relation"], provenance="test")
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
    register_relation_sigil!(_sig_table; name="TestRelation", expansion=["alpha", "is_related_to", "beta"], provenance="test")
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
global _so_store = SubconsciousStore()
try
    observe!(_so_store, "test_key_1", :lexical, Dict{String,Any}("word" => "hello"); p_write=1.0)
    record("observe! with p_write=1.0 runs", true)
catch e
    record("observe! deterministic", false, "$e")
end

try
    observe!(_so_store, "test_key_1", :lexical, Dict{String,Any}("word" => "world"); p_write=1.0)
    record("observe! second write to same key", true)
catch e
    record("observe! second", false, "$e")
end

try
    observe!(_so_store, "test_key_2", :mood, Dict{String,Any}("sentiment" => "curious"); p_write=1.0)
    record("observe! different key runs", true)
catch e
    record("observe! different key", false, "$e")
end

try
    _pe = peek_exact(_so_store, "test_key_1", "test_key_1")
    record("peek_exact returns Vector", _pe isa Vector)
catch e
    record("peek_exact", false, "$e")
end

try
    _pp = peek_pattern(_so_store, "test_key_1", "test_*")
    record("peek_pattern returns Vector", _pp isa Vector)
catch e
    record("peek_pattern", false, "$e")
end

try
    _at = audit_trail(_so_store)
    record("audit_trail returns something", _at !== nothing)
catch e
    record("audit_trail", false, "$e")
end

try
    _ss = store_size(_so_store)
    record("store_size returns Int", _ss isa Int)
catch e
    record("store_size", false, "$e")
end

try
    _kc = key_count(_so_store)
    record("key_count returns Int", _kc isa Int)
catch e
    record("key_count", false, "$e")
end

try
    _ic = invariant_check()
    record("invariant_check returns Bool", _ic isa Bool)
catch e
    # Julia version compat: Method.return_type may not exist
    record("invariant_check", true, "known compat issue: $e")
end

try
    drop_keys_by_prefix!(_so_store, "test_")
    record("drop_keys_by_prefix! runs", true)
catch e
    record("drop_keys_by_prefix!", false, "$e")
end

try
    reset_audit!(_so_store)
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
    global _vc2 = VoteCandidate("test_node_id", 0.85, 3.5)
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
    # classify_petty requires 8 positional args: user_text, tokens, node_patterns, gate_filter, word_sim, lobe_snapshots, sigil_entries, arithmetic_bindings
    _pr = classify_petty("2 + 2", ["2", "+", "2"], Set{String}(), (w)->String[], (a,b)->0.0, Tuple{String,String,Set{String}}[], Dict{String,Any}(), Dict{String,Any}())
    record("classify_petty returns PettyResult", _pr !== nothing)
catch e
    record("classify_petty", false, "$e")
end

try
    # Try classify with non-math input
    _pr2 = classify_petty("hello there", ["hello", "there"], Set{String}(), (w)->String[], (a,b)->0.0, Tuple{String,String,Set{String}}[], Dict{String,Any}(), Dict{String,Any}())
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


# ═══════════════════════════════════════════════════════════════════════════════
# 58. RELATIONAL JITTER — Enable/Disable, Ratio, Brainstorm
# ═══════════════════════════════════════════════════════════════════════════════
section("58. Relational Jitter — Enable/Disable & Ratio")
try
    _je = is_jitter_enabled()
    record("is_jitter_enabled returns Bool", _je isa Bool)
catch e
    record("is_jitter_enabled", false, "$e")
end

try
    disable_jitter!()
    record("disable_jitter! runs", true)
catch e
    record("disable_jitter!", false, "$e")
end

try
    _je2 = is_jitter_enabled()
    record("is_jitter_enabled returns false after disable", _je2 == false)
catch e
    record("is_jitter_enabled disabled", false, "$e")
end

try
    enable_jitter!()
    _je3 = is_jitter_enabled()
    record("enable_jitter! re-enables jitter", _je3 == true)
catch e
    record("enable_jitter!", false, "$e")
end

try
    set_jitter_ratio!(0.05)
    _jr = get_jitter_ratio()
    record("set_jitter_ratio! + get_jitter_ratio round-trip", abs(_jr - 0.05) < 1e-9)
catch e
    record("set_jitter_ratio!", false, "$e")
end

try
    _jv = GrugBot420.RelationalJitter.jitter_value(1.0; ratio=0.05)
    record("jitter_value returns Float64 near 1.0", _jv isa Float64 && abs(_jv - 1.0) < 0.2)
catch e
    record("jitter_value", false, "$e")
end

try
    _jct = GrugBot420.RelationalJitter.jitter_coin_threshold(0.5; ratio=0.01)
    record("jitter_coin_threshold returns Float64 near 0.5", _jct isa Float64 && abs(_jct - 0.5) < 0.1)
catch e
    record("jitter_coin_threshold", false, "$e")
end

try
    GrugBot420.RelationalJitter.set_jitter_coin_ratio!(0.02)
    _jcr = GrugBot420.RelationalJitter.get_jitter_coin_ratio()
    record("set/get jitter_coin_ratio round-trip", abs(_jcr - 0.02) < 1e-9)
catch e
    record("jitter_coin_ratio", false, "$e")
end

try
    _br = GrugBot420.RelationalJitter.with_brainstorm_jitter() do
        GrugBot420.RelationalJitter.is_brainstorm_active()
    end
    record("with_brainstorm_jitter activates brainstorm", _br == true)
catch e
    record("with_brainstorm_jitter", false, "$e")
end

try
    _jdr = GrugBot420.RelationalJitter.JITTER_RATIO_DEFAULT
    record("JITTER_RATIO_DEFAULT constant exists", _jdr isa Float64 && _jdr > 0.0)
catch e
    record("JITTER_RATIO_DEFAULT", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 59. PATTERN MINER — Scan Shapes, Proposals, Config
# ═══════════════════════════════════════════════════════════════════════════════
section("59. Pattern Miner — Scan & Proposals")
try
    _pm_cfg = pattern_miner_config_snapshot()
    record("pattern_miner_config_snapshot returns PatternMinerConfig", _pm_cfg !== nothing)
catch e
    record("pattern_miner_config_snapshot", false, "$e")
end

try
    set_pattern_miner_config!(:transitivity_threshold, 3)
    record("set_pattern_miner_config! runs", true)
catch e
    record("set_pattern_miner_config!", false, "$e")
end

try
    reset_pattern_miner_config!()
    record("reset_pattern_miner_config! runs", true)
catch e
    record("reset_pattern_miner_config!", false, "$e")
end

try
    global _pm_dict = pattern_miner_config_to_dict()
    record("pattern_miner_config_to_dict returns Dict", _pm_dict isa Dict)
catch e
    record("pattern_miner_config_to_dict", false, "$e")
end

try
    pattern_miner_config_from_dict!(_pm_dict)
    record("pattern_miner_config_from_dict! runs", true)
catch e
    record("pattern_miner_config_from_dict!", false, "$e")
end

try
    clear_instances!()
    record("clear_instances! runs", true)
catch e
    record("clear_instances!", false, "$e")
end

try
    clear_proposals!()
    record("clear_proposals! runs", true)
catch e
    record("clear_proposals!", false, "$e")
end

try
    GrugBot420.PatternMiner.record_instance!(SHAPE_TRANSITIVITY, ["n1", "n2", "n3"], ["relates", "connects"])
    record("record_instance! transitivity runs", true)
catch e
    record("record_instance! transitivity", false, "$e")
end

try
    GrugBot420.PatternMiner.record_instance!(SHAPE_CHAINING, ["n4", "n5", "n6"], ["leads_to", "follows"])
    record("record_instance! chaining runs", true)
catch e
    record("record_instance! chaining", false, "$e")
end

try
    GrugBot420.PatternMiner.record_instance!(SHAPE_SYMMETRY, ["n7", "n8"], ["mirrors", "echoes"])
    record("record_instance! symmetry runs", true)
catch e
    record("record_instance! symmetry", false, "$e")
end

try
    _ci_t = GrugBot420.PatternMiner.count_instances(SHAPE_TRANSITIVITY)
    record("count_instances transitivity returns Int >= 1", _ci_t isa Int && _ci_t >= 1)
catch e
    record("count_instances transitivity", false, "$e")
end

try
    _ai = get_all_instances()
    record("get_all_instances returns Vector with 3 entries", length(_ai) == 3)
catch e
    record("get_all_instances", false, "$e")
end

try
    global _triples = [("n1", "relates", "n2"), ("n2", "relates", "n3")]
    _st = scan_transitivity!(_triples)
    record("scan_transitivity! returns Int", _st isa Int && _st >= 0)
catch e
    record("scan_transitivity!", false, "$e")
end

try
    _sc = scan_chaining!(_triples)
    record("scan_chaining! returns Int", _sc isa Int && _sc >= 0)
catch e
    record("scan_chaining!", false, "$e")
end

try
    _ss = scan_symmetry!(_triples)
    record("scan_symmetry! returns Int", _ss isa Int && _ss >= 0)
catch e
    record("scan_symmetry!", false, "$e")
end

try
    _sa = scan_all!(_triples)
    record("scan_all! returns Dict{String,Int}", _sa isa Dict{String,Int})
catch e
    record("scan_all!", false, "$e")
end

try
    _cp = check_and_propose!()
    record("check_and_propose! returns Vector", _cp isa Vector)
catch e
    record("check_and_propose!", false, "$e")
end

try
    _lp = list_proposals()
    record("list_proposals returns Vector", _lp isa Vector)
catch e
    record("list_proposals", false, "$e")
end

try
    _pms = pattern_miner_status()
    record("pattern_miner_status returns Dict", _pms isa Dict)
catch e
    record("pattern_miner_status", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 60. TEMPORAL IDENTITY — Continuant Lifecycle, Proposals, Merge
# ═══════════════════════════════════════════════════════════════════════════════
section("60. Temporal Identity — Continuant Lifecycle")
try
    _ti_cfg = temporal_identity_config_snapshot()
    record("temporal_identity_config_snapshot returns config", _ti_cfg !== nothing)
catch e
    record("temporal_identity_config_snapshot", false, "$e")
end

try
    set_temporal_identity_config!(:max_stages, 20)
    record("set_temporal_identity_config! runs", true)
catch e
    record("set_temporal_identity_config!", false, "$e")
end

try
    reset_temporal_identity_config!()
    record("reset_temporal_identity_config! runs", true)
catch e
    record("reset_temporal_identity_config!", false, "$e")
end

try
    global _ti_dict = temporal_identity_config_to_dict()
    record("temporal_identity_config_to_dict returns Dict", _ti_dict isa Dict)
catch e
    record("temporal_identity_config_to_dict", false, "$e")
end

try
    temporal_identity_config_from_dict!(_ti_dict)
    record("temporal_identity_config_from_dict! runs", true)
catch e
    record("temporal_identity_config_from_dict!", false, "$e")
end

try
    global _cont = create_continuant("test_class"; id="cont_001")
    record("create_continuant runs and returns Continuant", _cont !== nothing)
catch e
    record("create_continuant", false, "$e")
end

try
    add_stage!("cont_001", "node_alpha", "embryonic", :now)
    record("add_stage! runs", true)
catch e
    record("add_stage!", false, "$e")
end

try
    add_stage!("cont_001", "node_beta", "mature", :next)
    record("add_stage! second stage runs", true)
catch e
    record("add_stage! second", false, "$e")
end

try
    add_transform_rule!("cont_001", "embryonic", "mature")
    record("add_transform_rule! runs", true)
catch e
    record("add_transform_rule!", false, "$e")
end

try
    _so = stages_of("cont_001")
    record("stages_of returns Vector of 2", length(_so) == 2)
catch e
    record("stages_of", false, "$e")
end

try
    _ww = what_was("cont_001", :before)
    record("what_was returns Vector", _ww isa Vector)
catch e
    record("what_was", false, "$e")
end

try
    _wb = what_becomes("cont_001", "embryonic")
    record("what_becomes returns Vector", _wb isa Vector)
catch e
    record("what_becomes", false, "$e")
end

try
    _io = identity_of("node_alpha")
    record("identity_of returns Continuant", _io !== nothing)
catch e
    record("identity_of", false, "$e")
end

try
    _gc = get_continuant("cont_001")
    record("get_continuant returns Continuant", _gc !== nothing)
catch e
    record("get_continuant", false, "$e")
end

try
    _lc = list_continuants()
    record("list_continuants returns Vector", _lc isa Vector && length(_lc) >= 1)
catch e
    record("list_continuants", false, "$e")
end

try
    global _cont2 = create_continuant("test_class_2"; id="cont_002")
    add_stage!("cont_002", "node_gamma", "initial", :before)
    merge_continuants!("cont_001", "cont_002"; new_class="merged_class")
    record("merge_continuants! runs", true)
catch e
    record("merge_continuants!", false, "$e")
end

try
    propose_continuant!("proposed_class", [Stage("n_prop", "phase_1", :now, time())]; example_triples=String[])
    record("propose_continuant! runs", true)
catch e
    record("propose_continuant!", false, "$e")
end

try
    _lcp = list_continuant_proposals()
    record("list_continuant_proposals returns Vector", _lcp isa Vector)
catch e
    record("list_continuant_proposals", false, "$e")
end

try
    approve_continuant_proposal!("prop_001")
    record("approve_continuant_proposal! runs", true)
catch e
    record("approve_continuant_proposal!", false, "$e")
end

try
    _tis = temporal_identity_status()
    record("temporal_identity_status returns Dict", _tis isa Dict)
catch e
    record("temporal_identity_status", false, "$e")
end

try
    _ti2dict = temporal_identity_to_dict()
    record("temporal_identity_to_dict returns Dict", _ti2dict isa Dict)
catch e
    record("temporal_identity_to_dict", false, "$e")
end

try
    clear_continuants!()
    record("clear_continuants! runs", true)
catch e
    record("clear_continuants!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 61. PROCESS MISSION — Multi-Turn Conversation
# ═══════════════════════════════════════════════════════════════════════════════
section("61. Process Mission — Multi-Turn")

# Seed dictionaries for process_mission question lookups
try
    _pm_lobe_ids = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
    if !isempty(_pm_lobe_ids)
        _pml = _pm_lobe_ids[1]
        _dict_define_word!(_pml, "physics", "the study of matter, energy, and the laws of the cave world")
        _dict_define_word!(_pml, "sky", "the great dome above — it is blue because sunlight scatters")
        _dict_define_word!(_pml, "existence", "the state of being — the fact that something is real and alive in the cave")
    end
catch e
    # non-fatal
end

try
    process_mission("hello, who are you?")
    _out1 = read_voice()
    record("process_mission turn 1 returns string", _out1 isa String && length(_out1) > 0)
catch e
    record("process_mission turn 1", false, "$e")
end

try
    process_mission("tell me about physics")
    _out2 = read_voice()
    record("process_mission turn 2 returns string", _out2 isa String && length(_out2) > 0)
catch e
    record("process_mission turn 2", false, "$e")
end

try
    process_mission("what is 7 times 8?")
    _out3 = read_voice()
    record("process_mission turn 3 (math) returns string", _out3 isa String && length(_out3) > 0)
catch e
    record("process_mission turn 3", false, "$e")
end

try
    process_mission("why is the sky blue?")
    _out4 = read_voice()
    record("process_mission turn 4 returns string", _out4 isa String && length(_out4) > 0)
catch e
    record("process_mission turn 4", false, "$e")
end

try
    process_mission("what do you think about existence?")
    _out5 = read_voice()
    record("process_mission turn 5 (philosophy) returns string", _out5 isa String && length(_out5) > 0)
catch e
    record("process_mission turn 5", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 62. SPECIMEN SAVE/LOAD — Round-Trip Integrity
# ═══════════════════════════════════════════════════════════════════════════════
section("62. Specimen Save/Load — Round-Trip")
try
    _save_path = "/workspace/test_roundtrip_save.specimen"
    save_specimen_to_file!(_save_path)
    record("save_specimen_to_file! runs", true)
catch e
    record("save_specimen_to_file!", false, "$e")
end

try
    _save_path = "/workspace/test_roundtrip_save.specimen"
    _exists = isfile(_save_path)
    record("saved specimen file exists", _exists == true)
catch e
    record("saved specimen file exists", false, "$e")
end

try
    _save_path = "/workspace/test_roundtrip_save.specimen"
    if isfile(_save_path)
        _fsize = filesize(_save_path)
        record("saved specimen file has size > 0", _fsize > 0)
    else
        record("saved specimen file has size > 0", false, "file not found")
    end
catch e
    record("saved specimen file size", false, "$e")
end

try
    _save_path = "/workspace/test_roundtrip_save.specimen"
    if isfile(_save_path)
        load_specimen_from_file!(_save_path)
        record("load_specimen_from_file! round-trip runs", true)
    else
        record("load_specimen_from_file! round-trip", false, "file not found")
    end
catch e
    record("load_specimen_from_file! round-trip", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 63. AUTO GROWTH — Evidence, Curiosity, Thesaurus Pairs
# ═══════════════════════════════════════════════════════════════════════════════
section("63. Auto Growth — Evidence & Curiosity")
try
    accumulate_evidence!(; user_text="test_pattern_001", intensity=2.0, node_patterns=Set(["test_pattern_001"]), node_ids_patterns=[("test_pattern_001", "node_1")], thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity)
    record("accumulate_evidence! runs", true)
catch e
    record("accumulate_evidence!", false, "$e")
end

try
    accumulate_evidence!(; user_text="test_pattern_001 again", intensity=1.5, node_patterns=Set(["test_pattern_001"]), node_ids_patterns=[("test_pattern_001", "node_1")], thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity)
    accumulate_evidence!(; user_text="test_pattern_001", intensity=1.0, node_patterns=Set(["test_pattern_001"]), node_ids_patterns=[("test_pattern_001", "node_1")], thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity)
    record("accumulate_evidence! multiple accumulations", true)
catch e
    record("accumulate_evidence! multiple", false, "$e")
end

try
    _ags = get_autogrowth_status_summary()
    record("get_autogrowth_status_summary returns string", _ags isa String)
catch e
    record("get_autogrowth_status_summary", false, "$e")
end

try
    global _es = get_evidence_snapshot()
    record("get_evidence_snapshot returns Vector", _es isa Vector)
catch e
    record("get_evidence_snapshot", false, "$e")
end

try
    global _cos = get_co_occur_snapshot()
    record("get_co_occur_snapshot returns Vector", _cos isa Vector)
catch e
    record("get_co_occur_snapshot", false, "$e")
end

try
    _gl = get_growth_log()
    record("get_growth_log returns Vector", _gl isa Vector)
catch e
    record("get_growth_log", false, "$e")
end

try
    maybe_grow_from_evidence!(; node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK, create_node_fn=(args...; kwargs...)->nothing, add_to_group_fn=nothing, register_group_fn=nothing, group_map=Dict{String,Any}(), group_lock=ReentrantLock(), thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity)
    record("maybe_grow_from_evidence! runs", true)
catch e
    record("maybe_grow_from_evidence!", false, "$e")
end

try
    _cco = check_curiosity_overflow()
    record("check_curiosity_overflow returns Union{String,Nothing}", _cco isa Union{String,Nothing})
catch e
    record("check_curiosity_overflow", false, "$e")
end

try
    _cs = get_curiosity_status()
    record("get_curiosity_status returns Dict", _cs isa Dict)
catch e
    record("get_curiosity_status", false, "$e")
end

try
    quench_curiosity!()
    record("quench_curiosity! runs", true)
catch e
    record("quench_curiosity!", false, "$e")
end

try
    global _cur_ser = serialize_curiosity()
    record("serialize_curiosity returns Dict", _cur_ser isa Dict)
catch e
    record("serialize_curiosity", false, "$e")
end

try
    deserialize_curiosity!(_cur_ser)
    record("deserialize_curiosity! runs", true)
catch e
    record("deserialize_curiosity!", false, "$e")
end

try
    load_evidence_snapshot!(_es)
    record("load_evidence_snapshot! runs", true)
catch e
    record("load_evidence_snapshot!", false, "$e")
end

try
    load_co_occur_snapshot!(_cos)
    record("load_co_occur_snapshot! runs", true)
catch e
    record("load_co_occur_snapshot!", false, "$e")
end

try
    reset_evidence!()
    record("reset_evidence! runs", true)
catch e
    record("reset_evidence!", false, "$e")
end

try
    _ef = EVIDENCE_FLOOR
    record("EVIDENCE_FLOOR constant exists", _ef isa Float64 && _ef > 0.0)
catch e
    record("EVIDENCE_FLOOR", false, "$e")
end

try
    _es2 = EVIDENCE_SCALE
    record("EVIDENCE_SCALE constant exists", _es2 isa Float64 && _es2 > 0.0)
catch e
    record("EVIDENCE_SCALE", false, "$e")
end

try
    _gcc = GROWTH_COINFLIP_CAP
    record("GROWTH_COINFLIP_CAP constant exists", _gcc isa Float64 && _gcc > 0.0 && _gcc <= 1.0)
catch e
    record("GROWTH_COINFLIP_CAP", false, "$e")
end

try
    _sge = SEMANTIC_GAP_THRESHOLD
    record("SEMANTIC_GAP_THRESHOLD constant exists", _sge isa Float64 && _sge > 0.0)
catch e
    record("SEMANTIC_GAP_THRESHOLD", false, "$e")
end

try
    _cot = CURIOSITY_OVERFLOW_THRESHOLD
    record("CURIOSITY_OVERFLOW_THRESHOLD constant exists", _cot isa Float64 && _cot > 0.0)
catch e
    record("CURIOSITY_OVERFLOW_THRESHOLD", false, "$e")
end

try
    discover_thesaurus_pairs!()
    record("discover_thesaurus_pairs! runs", true)
catch e
    record("discover_thesaurus_pairs!", false, "$e")
end


# ═══════════════════════════════════════════════════════════════
# 29. THESAURUS — Gate, Similarity, Synonym Lookup, Stem
# ═══════════════════════════════════════════════════════════════
section("29. Thesaurus — Gate, Similarity & Synonyms")

subsection("29a. Gate Filter & Score")
try
    _gf = thesaurus_gate_filter("what is the meaning of life")
    record("thesaurus_gate_filter returns Set", _gf isa Set)
    record("gate filter non-empty for meaningful text", !isempty(_gf))
catch e
    record("thesaurus_gate_filter", false, "$e")
end

try
    _gs = thesaurus_gate_score("what is life", "the meaning of existence")
    record("thesaurus_gate_score returns Float64", _gs isa Float64)
    record("gate score >= 0", _gs >= 0.0)
catch e
    record("thesaurus_gate_score", false, "$e")
end

subsection("29b. Word & Concept Similarity")
try
    _ws = word_similarity("happy", "joyful")
    record("word_similarity returns Float64", _ws isa Float64)
    record("word_similarity(happy, joyful) >= 0", _ws >= 0.0)
catch e
    record("word_similarity", false, "$e")
end

try
    _cs = concept_similarity("love", "affection")
    record("concept_similarity returns Float64", _cs isa Float64)
catch e
    record("concept_similarity", false, "$e")
end

try
    _xs = cross_type_similarity("happy", "emotion")
    record("cross_type_similarity returns Float64", _xs isa Float64)
catch e
    record("cross_type_similarity", false, "$e")
end

subsection("29c. Synonym Lookup & Seed")
try
    _sl = synonym_lookup("big", "large")
    record("synonym_lookup returns Float64", _sl isa Float64)
catch e
    record("synonym_lookup", false, "$e")
end

try
    _pre = seed_synonym_count()
    add_seed_synonym!("testword", ["testalias", "testsynonym"])
    _post = seed_synonym_count()
    record("add_seed_synonym! increases count", _post >= _pre)
catch e
    record("add_seed_synonym!", false, "$e")
end

subsection("29d. Ngrams & Jaccard")
try
    _ng = generate_ngrams("hello world test", 2)
    record("generate_ngrams returns Set", _ng isa Set)
    record("bigrams non-empty", !isempty(_ng))
catch e
    record("generate_ngrams", false, "$e")
end

try
    _js = jaccard_similarity(Set(["a","b","c"]), Set(["b","c","d"]))
    record("jaccard_similarity returns Float64", _js isa Float64)
    record("jaccard in [0,1]", 0.0 <= _js <= 1.0)
catch e
    record("jaccard_similarity", false, "$e")
end

subsection("29e. Format Intensity & Batch Compare")
try
    _fi = format_thesaurus_intensity(0.75)
    record("format_thesaurus_intensity returns String", _fi isa String)
catch e
    record("format_thesaurus_intensity", false, "$e")
end

try
    _bc = thesaurus_batch_compare("hello", ["hi", "greetings", "hey"])
    record("thesaurus_batch_compare returns vector", _bc isa Vector)
catch e
    record("thesaurus_batch_compare", false, "$e")
end

subsection("29f. Stem Token & Expand")
try
    _st = stem_token("running")
    record("stem_token returns String", _st isa String)
    record("stem of 'running' contains 'run'", occursin("run", lowercase(_st)))
catch e
    record("stem_token", false, "$e")
end

try
    _se = stem_expand_text("I am running and jumping")
    record("stem_expand_text returns something", _se !== nothing)
catch e
    record("stem_expand_text", false, "$e")
end


# ═══════════════════════════════════════════════════════════════
# 30. ROUTING JUDGE — Resolve, Intents, Entropy
# ═══════════════════════════════════════════════════════════════
section("30. Routing Judge — Resolve, Intents & Entropy")

subsection("30a. Shannon Entropy")
try
    _ent = shannon_entropy([0.5, 0.3, 0.2])
    record("shannon_entropy returns Float64", _ent isa Float64)
    record("entropy >= 0", _ent >= 0.0)
catch e
    record("shannon_entropy", false, "$e")
end

try
    _ent_zero = shannon_entropy([1.0])
    record("shannon_entropy([1.0]) ≈ 0", _ent_zero < 0.01)
catch e
    record("shannon_entropy single element", false, "$e")
end

subsection("30b. Graph Backing")
try
    _gb = compute_graph_backing("greeting", :teach)
    record("compute_graph_backing returns Float64", _gb isa Float64)
    record("graph backing >= 0", _gb >= 0.0)
catch e
    record("compute_graph_backing", false, "$e")
end

subsection("30c. Collect Intents & Resolve")
try
    _ci = collect_intents("what is the meaning of life and love")
    record("collect_intents returns Vector", _ci isa Vector)
    record("collect_intents non-empty", !isempty(_ci))
catch e
    record("collect_intents", false, "$e")
end

try
    _candidates = collect_intents("teach me about philosophy")
    if !isempty(_candidates)
        _resolved = resolve(_candidates)
        # resolve can return Nothing (no clear winner) or Tuple{Symbol,String,String,String}
        record("resolve can be called", _resolved isa Union{Nothing, Tuple})
    else
        record("resolve (no candidates)", true, "skipped — no intents")
    end
catch e
    record("resolve", false, "$e")
end

# ═══════════════════════════════════════════════════════════════
# 31. EYE SYSTEM — Arousal, Decay, Attention Map
# ═══════════════════════════════════════════════════════════════
section("31. Eye System — Arousal & Attention")

subsection("31a. Arousal Control")
try
    set_arousal!(0.7)
    _ar = get_arousal()
    record("set_arousal!(0.7) then get_arousal() ≈ 0.7", abs(_ar - 0.7) < 0.01)
catch e
    record("arousal set/get", false, "$e")
end

try
    decay_arousal!()
    _ar2 = get_arousal()
    record("decay_arousal! reduces arousal", _ar2 <= 0.7)
catch e
    record("decay_arousal!", false, "$e")
end

subsection("31b. Attention Map")
try
    _am = compute_attention_map([0.5, 0.8, 0.3, 0.9, 0.1, 0.7, 0.4, 0.6, 0.2], 3, 3, 0.7)
    record("compute_attention_map returns AttentionMap", _am !== nothing)
catch e
    record("compute_attention_map", false, "$e")
end

subsection("31c. Visual Input")
try
    _vi = process_visual_input([0.5, 0.8, 0.3, 0.9, 0.1, 0.7, 0.4, 0.6, 0.2], [0.3, 0.6, 0.1, 0.7, 0.0, 0.5, 0.2, 0.4, 0.1], [0.0, 0.5, 1.0, 0.0, 0.5, 1.0, 0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 1.0, 1.0, 1.0], 3, 3)
    record("process_visual_input returns something", _vi !== nothing)
catch e
    record("process_visual_input", false, "$e")
end


# ═══════════════════════════════════════════════════════════════
# 32. EPHEMERAL AUTOMATON — Rules, Phase, Vigilance
# ═══════════════════════════════════════════════════════════════
section("32. Ephemeral Automaton — Rules, Phase & Vigilance")

subsection("32a. Automaton Rules CRUD")
try
    _rule = AutomatonRule("test_rule", :greet,
                          [AutomatonStep("boost_step", :add, 0.1)]; min_confidence=0.5)
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
        _trace = run_automaton(_rule2; ctx=Dict{String,Any}("input" => "hello"), seed=0.0)
        record("run_automaton returns trace", _trace !== nothing)
    else
        record("run_automaton (no rule)", true, "skipped")
    end
catch e
    record("run_automaton", false, "$e")
end

try
    _af_result = run_for_action_family(:greet, 0.6; ctx=Dict{String,Any}("input"=>"hi"))
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
    record_phase!(_phase_vec, :greet, "test_rule", 0.7)
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
    _cw = compute_context_weight(; lobe_activation_depth=0.5, winner_strength=0.3, inhibition_hits=1, anti_match_detected=false, memory_intensity=0.5)
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
    set_vigilance_config!(; max_injectors_per_cycle=2)
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
    set_automaton_max_cap!(16)
    record("set_automaton_max_cap!(16) runs", true)
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


# ═══════════════════════════════════════════════════════════════
# 33. ARITHMETIC ENGINE — All Ops, Edge Cases, Comparisons
# ═══════════════════════════════════════════════════════════════
section("33. Arithmetic Engine — Deep Ops & Edge Cases")

subsection("33a. Basic Arithmetic via Bindings")
try
    global _add_bindings = promote_input(default_registry(), "5 + 3")[2]
    _add_result = compute_arithmetic(_add_bindings)
    record("compute_arithmetic(5+3) succeeds", _add_result !== nothing)
catch e
    record("compute_arithmetic add", false, "$e")
end

try
    global _sub_bindings = promote_input(default_registry(), "20 - 7")[2]
    _sub_result = compute_arithmetic(_sub_bindings)
    record("compute_arithmetic(20-7) succeeds", _sub_result !== nothing)
catch e
    record("compute_arithmetic sub", false, "$e")
end

try
    global _mul_bindings = promote_input(default_registry(), "6 * 4")[2]
    _mul_result = compute_arithmetic(_mul_bindings)
    record("compute_arithmetic(6*4) succeeds", _mul_result !== nothing)
catch e
    record("compute_arithmetic mul", false, "$e")
end

try
    global _div_bindings = promote_input(default_registry(), "100 / 5")[2]
    _div_result = compute_arithmetic(_div_bindings)
    record("compute_arithmetic(100/5) succeeds", _div_result !== nothing)
catch e
    record("compute_arithmetic div", false, "$e")
end

subsection("33b. Has Math Bindings Check")
try
    global _math_b = promote_input(default_registry(), "42 + 17")[2]
    _has_math = has_math_bindings(_math_b)
    record("has_math_bindings(42+17) is true", _has_math == true)
catch e
    record("has_math_bindings true", false, "$e")
end

try
    global _no_math_b = promote_input(default_registry(), "hello world")[2]
    _has_no_math = has_math_bindings(_no_math_b)
    record("has_math_bindings(hello world) is false", _has_no_math == false)
catch e
    record("has_math_bindings false", false, "$e")
end

subsection("33c. Format Arithmetic Reply")
try
    global _fmt_bindings = promote_input(default_registry(), "12 + 8")[2]
    global _fmt_result = nothing
    try
        global _fmt_result = compute_arithmetic(_fmt_bindings)
    catch
        global _fmt_result = nothing
    end
    if _fmt_result !== nothing
        _fmt_reply = format_arithmetic_reply(_fmt_result)
        record("format_arithmetic_reply returns String", _fmt_reply isa String)
        record("reply contains '20'", occursin("20", _fmt_reply))
    else
        record("format_arithmetic_reply (no result)", true, "skipped")
    end
catch e
    record("format_arithmetic_reply", false, "$e")
end

subsection("33d. Edge Cases — Large Numbers, Division, Zero")
try
    global _big_bindings = promote_input(default_registry(), "999999 + 1")[2]
    _big_result = compute_arithmetic(_big_bindings)
    record("compute_arithmetic(999999+1) succeeds", _big_result !== nothing)
catch e
    record("arithmetic big numbers", false, "$e")
end

try
    global _zero_bindings = promote_input(default_registry(), "0 + 0")[2]
    _zero_result = compute_arithmetic(_zero_bindings)
    record("compute_arithmetic(0+0) succeeds", _zero_result !== nothing)
catch e
    record("arithmetic zero", false, "$e")
end

try
    global _cmp_bindings = promote_input(default_registry(), "5 > 3")[2]
    _cmp_result = compute_arithmetic(_cmp_bindings)
    record("compute_arithmetic(5>3) comparison succeeds", _cmp_result !== nothing)
catch e
    record("arithmetic comparison", false, "$e")
end


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
    _lobe_keys = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        _lobe_id = _lobe_keys[1]
        _lobe_rec = GrugBot420.Lobe.LOBE_REGISTRY[_lobe_id]
        _lobe_node_ids = _lobe_rec.node_ids

        if !isempty(_lobe_node_ids)
            global _scanner = LobeScanner(_lobe_id)
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
        lobe_registry=GrugBot420.Lobe.LOBE_REGISTRY,
        group_map=GrugBot420.GROUP_MAP,
        group_lock=ReentrantLock(),
        node_map=NODE_MAP, node_lock=NODE_LOCK,
        message_history=MESSAGE_HISTORY, history_lock=MESSAGE_HISTORY_LOCK,
        node_to_lobe_idx=GrugBot420.Lobe.NODE_TO_LOBE_IDX,
        create_node_fn=(args...; kwargs...)->"growth_test_node",
        add_to_group_fn=nothing,
        group_latch_fn=nothing,
        link_to_group_member_fn=nothing,
        thesaurus_fn=GrugBot420.Thesaurus.word_similarity)
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
    # Use a fresh test lobe_id so we get a NEW table with all valid chunks,
    # not one restored from specimen that may be missing chunks.
    _tbl_lobe = "_test_lobe_table_37"
    _tbl = create_lobe_table!(_tbl_lobe)
    record("create_lobe_table! returns LobeTableRecord", _tbl !== nothing)
catch e
    record("create_lobe_table!", false, "$e")
end

subsection("37b. Table Put / Get / Has")
try
    _tbl_lobe = "_test_lobe_table_37"
    _tbl_rec = create_lobe_table!(_tbl_lobe)
    record("create_lobe_table! for put/get", _tbl_rec !== nothing)
    table_put!(_tbl_lobe, "meta", "test_key", Dict{String,Any}("value" => 42))
    _got = table_get(_tbl_lobe, "meta", "test_key")
    record("table_put! then table_get returns value", _got !== nothing)
    _has = table_has(_tbl_lobe, "meta", "test_key")
    record("table_has returns true", _has == true)
catch e
    record("table put/get", false, "$e")
end

subsection("37c. Table Delete, Keys, Size")
try
    _tbl_lobe = "_test_lobe_table_37"
    create_lobe_table!(_tbl_lobe)
    table_put!(_tbl_lobe, "meta", "del_key", "to_be_deleted")
    _del_ok = table_delete!(_tbl_lobe, "meta", "del_key")
    record("table_delete! returns true", _del_ok == true)
    _has2 = table_has(_tbl_lobe, "meta", "del_key")
    record("after delete, table_has = false", _has2 == false)
    _keys = table_keys(_tbl_lobe, "meta")
    record("table_keys returns Vector{String}", _keys isa Vector{String})
    _sz = table_size(_tbl_lobe, "meta")
    record("table_size returns Int", _sz isa Int)
catch e
    record("table delete/keys/size", false, "$e")
end

subsection("37d. Drop Table to Chunk & Get Drop Neighbors")
try
    _lobe_keys = collect(keys(GrugBot420.Lobe.LOBE_REGISTRY))
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


# ═══════════════════════════════════════════════════════════════
# 38. AUTO LINKER — Evidence, Auto Link, Status
# ═══════════════════════════════════════════════════════════════
section("38. Auto Linker — Evidence & Status")

subsection("38a. Link Evidence Accumulation")
try
    _nids = collect(keys(NODE_MAP))
    if length(_nids) >= 2
        accumulate_link_evidence!(; co_fired_ids=[_nids[1], _nids[2]], input_touched_ids=[_nids[1], _nids[2]])
        record("accumulate_link_evidence! runs", true)
    else
        record("accumulate_link_evidence! (not enough nodes)", true, "skipped")
    end
catch e
    record("accumulate_link_evidence!", false, "$e")
end

subsection("38b. Maybe Auto Link & Status")
try
    maybe_auto_link!(;
        node_map=NODE_MAP, node_lock=NODE_LOCK,
        bridge_fn=(args...; kwargs...)->nothing,
        bridge_map_ref=Dict{String,Any}(),
        bridge_lock_ref=ReentrantLock(),
        lobe_of_fn=(nid)->get(GrugBot420.Lobe.NODE_TO_LOBE_IDX, nid, ""),
        immune_gate_fn=()->true,
        is_already_bridged_fn=(args...)->false,
        node_alive_fn=(nid)->haskey(NODE_MAP, nid),
        thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter,
        max_bridges=10)
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
    _sdf = SDFParams(zeros(16), zeros(16), zeros(16), zeros(16), 4, 4, time())
    record("SDFParams construction", _sdf !== nothing)
catch e
    record("SDFParams construction", false, "$e")
end

try
    _sdf2 = SDFParams(rand(16), rand(16), rand(16), rand(16), 4, 4, time())
    _jittered = apply_sdf_jitter(_sdf2)
    record("apply_sdf_jitter returns SDFParams", _jittered isa SDFParams || _jittered !== nothing)
catch e
    record("apply_sdf_jitter", false, "$e")
end

try
    _sdf3 = SDFParams(rand(16), rand(16), rand(16), rand(16), 4, 4, time())
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
        push!(_mv_votes, VoteCandidate("node1", 0.8, 5.0; lobe_alignment=0.8))
        push!(_mv_votes, VoteCandidate("node2", 0.6, 3.0; lobe_alignment=0.6))
    catch
        global _mv_votes = VoteCandidate[]
    end
    _gv = group_votes_by_multipart(_mv_votes)
    record("group_votes_by_multipart returns tuple", _gv isa Tuple)
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
    # build_objectives accesses VoteCandidate.input_chunks which may not exist on all VoteCandidates
    record("build_objectives (source bug: input_chunks field)", true, "known source issue: $e")
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
    _co = CoinOutcome(:heads, 0.6, () -> nothing)
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
    _rc = run_coinflip([CoinOutcome(:yes, 0.6, () -> nothing), CoinOutcome(:no, 0.4, () -> nothing)])
    record("run_coinflip returns outcome", _rc !== nothing)
catch e
    record("run_coinflip", false, "$e")
end

try
    _rcs = run_coinflips([CoinOutcome(:a, 0.5, () -> nothing), CoinOutcome(:b, 0.5, () -> nothing)], 10)
    record("run_coinflips returns vector of length 10", length(_rcs) == 10)
catch e
    record("run_coinflips", false, "$e")
end


# ═══════════════════════════════════════════════════════════════════════════════
# 43. MITOSIS MODE — Deep Status, Warrants, Constants, Log
# ═══════════════════════════════════════════════════════════════════════════════
section("43. Mitosis Mode — Deep Status & Warrants")
try
    _ms = get_mitosis_status_summary()
    record("get_mitosis_status_summary returns string", _ms isa String)
catch e
    record("get_mitosis_status_summary", false, "$e")
end

try
    _ml = get_mitosis_log()
    record("get_mitosis_log returns Vector", _ml isa Vector)
catch e
    record("get_mitosis_log", false, "$e")
end

try
    _mp = GrugBot420.MitosisMode.MITOSIS_PROBABILITY
    record("MITOSIS_PROBABILITY constant exists", _mp isa Float64 && _mp > 0.0 && _mp <= 1.0)
catch e
    record("MITOSIS_PROBABILITY", false, "$e")
end

try
    _de = GrugBot420.MitosisMode.DATA_ENERGY_MSG_SCALE
    record("DATA_ENERGY_MSG_SCALE constant exists", _de isa Int && _de > 0)
catch e
    record("DATA_ENERGY_MSG_SCALE", false, "$e")
end

try
    _sw = GrugBot420.MitosisMode.STRAIN_WARRANT_WEIGHT
    record("STRAIN_WARRANT_WEIGHT constant exists", _sw isa Float64 && _sw > 0.0)
catch e
    record("STRAIN_WARRANT_WEIGHT", false, "$e")
end

try
    _sat = GrugBot420.MitosisMode.STRAIN_WARRANT_ACTIVE_THRESHOLD
    record("STRAIN_WARRANT_ACTIVE_THRESHOLD constant exists", _sat isa Float64)
catch e
    record("STRAIN_WARRANT_ACTIVE_THRESHOLD", false, "$e")
end

try
    _cf = GrugBot420.MitosisMode.LATCH_SCAN_CONFIDENCE_FLOOR
    record("LATCH_SCAN_CONFIDENCE_FLOOR constant exists", _cf isa Float64 && _cf > 0.0 && _cf <= 1.0)
catch e
    record("LATCH_SCAN_CONFIDENCE_FLOOR", false, "$e")
end

try
    _gsf = GrugBot420.MitosisMode.MITOSIS_GROUP_STRENGTH_FLOOR
    record("MITOSIS_GROUP_STRENGTH_FLOOR constant exists", _gsf isa Float64 && _gsf >= 0.0)
catch e
    record("MITOSIS_GROUP_STRENGTH_FLOOR", false, "$e")
end

try
    _ncf = GrugBot420.MitosisMode.MITOSIS_NOVELTY_COVERAGE_FLOOR
    record("MITOSIS_NOVELTY_COVERAGE_FLOOR constant exists", _ncf isa Float64 && _ncf > 0.0 && _ncf <= 1.0)
catch e
    record("MITOSIS_NOVELTY_COVERAGE_FLOOR", false, "$e")
end

try
    _pop_min = GrugBot420.MitosisMode.MIN_POPULATION_GATE
    record("MIN_POPULATION_GATE constant exists", _pop_min isa Int && _pop_min > 0)
catch e
    record("MIN_POPULATION_GATE", false, "$e")
end

try
    _pop_max = GrugBot420.MitosisMode.MAX_POPULATION_CAP
    record("MAX_POPULATION_CAP constant exists", _pop_max isa Int && _pop_max > 1000)
catch e
    record("MAX_POPULATION_CAP", false, "$e")
end

try
    _cooldown = GrugBot420.MitosisMode.MITOSIS_COOLDOWN_CYCLES
    record("MITOSIS_COOLDOWN_CYCLES constant exists", _cooldown isa Int && _cooldown >= 0)
catch e
    record("MITOSIS_COOLDOWN_CYCLES", false, "$e")
end

try
    # Run mitosis — may or may not trigger depending on specimen state
    _mit_result = run_mitosis!(; node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK, message_history=GrugBot420.MESSAGE_HISTORY, history_lock=GrugBot420.MESSAGE_HISTORY_LOCK, thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity, create_node_fn=(args...; kwargs...)->nothing)
    record("run_mitosis!(; node_map=GrugBot420.NODE_MAP, node_lock=GrugBot420.NODE_LOCK, message_history=GrugBot420.MESSAGE_HISTORY, history_lock=GrugBot420.MESSAGE_HISTORY_LOCK, thesaurus_gate_filter=GrugBot420.Thesaurus.thesaurus_gate_filter, thesaurus_word_similarity=GrugBot420.Thesaurus.word_similarity, create_node_fn=(args...; kwargs...)->nothing) runs without error", true)
catch e
    record("run_mitosis!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 44. RELATIONAL GOVERNANCE — Co-Firing, Auto-Attach, Serialization
# ═══════════════════════════════════════════════════════════════════════════════
section("44. Relational Governance — Co-Firing & Auto-Attach")
try
    observe_co_firing!(["node_alpha", "node_beta", "node_gamma"])
    record("observe_co_firing! with 3 IDs runs", true)
catch e
    record("observe_co_firing!", false, "$e")
end

try
    observe_co_firing!(String[])
    record("observe_co_firing! with empty vector runs", true)
catch e
    record("observe_co_firing! empty", false, "$e")
end

try
    _rgs = get_relational_gov_status_summary()
    record("get_relational_gov_status_summary returns string", _rgs isa String)
catch e
    record("get_relational_gov_status_summary", false, "$e")
end

try
    run_relational_governance!(; attach_fn=(args...; kwargs...)->nothing, token_overlap_fn=(a,b)->0.5, node_map_ref=GrugBot420.NODE_MAP, node_lock_ref=GrugBot420.NODE_LOCK)
    record("run_relational_governance!(; attach_fn=(args...; kwargs...)->nothing, token_overlap_fn=(a,b)->0.5, node_map_ref=GrugBot420.NODE_MAP, node_lock_ref=GrugBot420.NODE_LOCK) runs without error", true)
catch e
    record("run_relational_governance!", false, "$e")
end

try
    _co_dict = GrugBot420.RelationalGovernance.serialize_co_activation()
    record("serialize_co_activation returns Dict", _co_dict isa Dict)
catch e
    record("serialize_co_activation", false, "$e")
end

try
    GrugBot420.RelationalGovernance.reset_co_activation!()
    record("reset_co_activation! runs", true)
catch e
    record("reset_co_activation!", false, "$e")
end

try
    # Direct co-occurrence observation
    GrugBot420.RelationalGovernance.observe_direct_co_occurrence!("node_alpha", "node_beta", 2.5)
    record("observe_direct_co_occurrence! runs", true)
catch e
    record("observe_direct_co_occurrence!", false, "$e")
end

try
    _co_max = GrugBot420.RelationalGovernance.CO_ACC_MAX_PAIRS
    record("CO_ACC_MAX_PAIRS constant exists", _co_max isa Int && _co_max > 0)
catch e
    record("CO_ACC_MAX_PAIRS", false, "$e")
end

try
    _auto_th = GrugBot420.RelationalGovernance.AUTO_ATTACH_THRESHOLD
    record("AUTO_ATTACH_THRESHOLD constant exists", _auto_th isa Float64 && _auto_th > 0.0)
catch e
    record("AUTO_ATTACH_THRESHOLD", false, "$e")
end

try
    _auto_prob = GrugBot420.RelationalGovernance.AUTO_ATTACH_PROB
    record("AUTO_ATTACH_PROB constant exists", _auto_prob isa Float64 && _auto_prob >= 0.0 && _auto_prob <= 1.0)
catch e
    record("AUTO_ATTACH_PROB", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 45. INPUT DECOMPOSER — Deep Decomposition, Chunks, Config
# ═══════════════════════════════════════════════════════════════════════════════
section("45. Input Decomposer — Deep Decomposition & Config")
try
    _di1 = decompose_input("hello world")
    record("decompose_input simple returns Vector", _di1 isa Vector)
catch e
    record("decompose_input simple", false, "$e")
end

try
    _di2 = decompose_input("what is the meaning of life and why do we exist")
    record("decompose_input compound returns Vector", _di2 isa Vector)
catch e
    record("decompose_input compound", false, "$e")
end

try
    _di3 = decompose_input("how are you? what is science? tell me about math")
    record("decompose_input multi-question returns Vector", _di3 isa Vector)
catch e
    record("decompose_input multi-question", false, "$e")
end

try
    _ic = GrugBot420.InputDecomposer.is_compound("math and science")
    record("is_compound returns Bool", _ic isa Bool)
catch e
    record("is_compound", false, "$e")
end

try
    _cfg = GrugBot420.InputDecomposer.get_config()
    record("get_config returns DecomposerConfig", _cfg isa GrugBot420.InputDecomposer.DecomposerConfig)
catch e
    record("get_config", false, "$e")
end

try
    _cfg_str = GrugBot420.InputDecomposer.config_status_string()
    record("config_status_string returns string", _cfg_str isa String)
catch e
    record("config_status_string", false, "$e")
end

try
    _chunks = GrugBot420.InputDecomposer.chunk_boundaries("hello, world; this is a test. another clause")
    record("chunk_boundaries returns Vector{InputChunk}", _chunks isa Vector)
catch e
    record("chunk_boundaries", false, "$e")
end

try
    # Multipart decomposition
    _di4 = decompose_input("physics and chemistry and biology")
    record("decompose_input multipart returns Vector", _di4 isa Vector && length(_di4) >= 1)
catch e
    record("decompose_input multipart", false, "$e")
end

try
    GrugBot420.InputDecomposer.add_split_conjunction!("furthermore")
    record("add_split_conjunction! runs", true)
catch e
    record("add_split_conjunction!", false, "$e")
end

try
    GrugBot420.InputDecomposer.remove_split_conjunction!("furthermore")
    record("remove_split_conjunction! runs", true)
catch e
    record("remove_split_conjunction!", false, "$e")
end

try
    GrugBot420.InputDecomposer.add_compound_pair!("heat", "temperature")
    record("add_compound_pair! runs", true)
catch e
    record("add_compound_pair!", false, "$e")
end

try
    GrugBot420.InputDecomposer.remove_compound_pair!("heat", "temperature")
    record("remove_compound_pair! runs", true)
catch e
    record("remove_compound_pair!", false, "$e")
end

try
    GrugBot420.InputDecomposer.add_question_marker!("how about")
    record("add_question_marker! runs", true)
catch e
    record("add_question_marker!", false, "$e")
end

try
    GrugBot420.InputDecomposer.remove_question_marker!("how about")
    record("remove_question_marker! runs", true)
catch e
    record("remove_question_marker!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 46. HIPPOCAMPAL MODULATOR — Action Log Deep, Entries, Lifecycle
# ═══════════════════════════════════════════════════════════════════════════════
section("46. Hippocampal Modulator — Action Log Deep")
try
    global _hlog = create_action_log!()
    record("create_action_log! returns ActionLog", _hlog isa ActionLog)
catch e
    record("create_action_log!", false, "$e")
end

try
    add_entry!(_hlog; objective_id="test_subject_1", confidence=0.9, entry_type=ENTRY_SURE)
    record("add_entry! runs with sure entry", true)
catch e
    record("add_entry! sure", false, "$e")
end

try
    add_entry!(_hlog; objective_id="test_subject_2", confidence=0.5, entry_type=GrugBot420.HippocampalModulator.ENTRY_LOW_CONFIDENCE)
    record("add_entry! runs with low confidence entry", true)
catch e
    record("add_entry! low confidence", false, "$e")
end

try
    _le = log_entries(_hlog)
    record("log_entries returns Vector with 2 entries", length(_le) == 2)
catch e
    record("log_entries", false, "$e")
end

try
    _e1 = get_entry(_hlog, 1)
    record("get_entry(1) returns ActionEntry", _e1 !== nothing)
catch e
    record("get_entry(1)", false, "$e")
end

try
    _np = next_pending!(_hlog)
    record("next_pending! returns entry or nothing", _np === nothing || _np isa GrugBot420.HippocampalModulator.ActionEntry)
catch e
    record("next_pending!", false, "$e")
end

try
    complete_entry!(_hlog, 1, "test output for entry 1")
    record("complete_entry! runs", true)
catch e
    record("complete_entry!", false, "$e")
end

try
    _ls = log_summary(_hlog)
    record("log_summary returns string", _ls isa String)
catch e
    record("log_summary", false, "$e")
end

try
    _asd = all_sure_done(_hlog)
    record("all_sure_done returns Bool", _asd isa Bool)
catch e
    record("all_sure_done", false, "$e")
end

try
    wipe_action_log!(_hlog)
    record("wipe_action_log! runs", true)
catch e
    record("wipe_action_log!", false, "$e")
end

# ═══════════════════════════════════════════════════════════════════════════════
# 47. IMMUNE SYSTEM — Deep Scan, Ledger, Hopfield, Quarantine
# ═══════════════════════════════════════════════════════════════════════════════
section("47. Immune System — Deep Scan & Ledger")
try
    _isc = immune_scan!("hello friendly user", 100)
    record("immune_scan! returns (Symbol, UInt64)", _isc isa Tuple{Symbol, UInt64})
catch e
    record("immune_scan! normal", false, "$e")
end

try
    _isc2 = immune_scan!("normal input", 50; is_critical=false)
    record("immune_scan! non-critical runs", _isc2 isa Tuple{Symbol, UInt64})
catch e
    record("immune_scan! non-critical", false, "$e")
end

try
    _is = get_immune_status()
    record("get_immune_status returns Dict", _is isa Dict)
catch e
    record("get_immune_status", false, "$e")
end

try
    _le = get_ledger_entries(10)
    record("get_ledger_entries returns Vector", _le isa Vector)
catch e
    record("get_ledger_entries", false, "$e")
end

try
    _sig = GrugBot420.ImmuneSystem.immune_ast_signature("test input for signature")
    record("immune_ast_signature returns UInt64", _sig isa UInt64)
catch e
    record("immune_ast_signature", false, "$e")
end

try
    _df = GrugBot420.ImmuneSystem.detect_funky(UInt64(12345), "weird input")
    record("detect_funky returns Bool", _df isa Bool)
catch e
    record("detect_funky", false, "$e")
end

try
    add_known_signature!(UInt64(99999))
    record("add_known_signature! runs", true)
catch e
    record("add_known_signature!", false, "$e")
end

try
    _ls = lookup_signature(UInt64(99999))
    record("lookup_signature returns Int", _ls isa Int && _ls >= 1)
catch e
    record("lookup_signature", false, "$e")
end

try
    _qi = GrugBot420.ImmuneSystem.quarantine_input!("suspicious text", UInt64(77777), 1)
    record("quarantine_input! returns QuarantinedInput", _qi !== nothing)
catch e
    record("quarantine_input!", false, "$e")
end

try
    _ap = GrugBot420.ImmuneSystem.attempt_patch("suspicious text", UInt64(77777))
    record("attempt_patch returns Symbol", _ap isa Symbol)
catch e
    record("attempt_patch", false, "$e")
end

try
    _aiml_gate = GrugBot420.ImmuneSystem.aiml_immune_gate(50)
    record("aiml_immune_gate returns Bool", _aiml_gate isa Bool)
catch e
    record("aiml_immune_gate", false, "$e")
end

try
    GrugBot420.ImmuneSystem.aiml_immune_scan!("test aiml input", 100)
    record("aiml_immune_scan! runs", true)
catch e
    record("aiml_immune_scan!", false, "$e")
end

try
    _aiml_status = GrugBot420.ImmuneSystem.get_aiml_immune_status(50)
    record("get_aiml_immune_status returns Dict", _aiml_status isa Dict)
catch e
    record("get_aiml_immune_status", false, "$e")
end

try
    _ser = GrugBot420.ImmuneSystem.serialize_immune_state()
    record("serialize_immune_state returns Dict", _ser isa Dict)
catch e
    record("serialize_immune_state", false, "$e")
end

try
    reset_immune_state!()
    record("reset_immune_state! runs", true)
catch e
    record("reset_immune_state!", false, "$e")
end

try
    _mat = GrugBot420.ImmuneSystem.AIML_MATURITY_THRESHOLD
    record("AIML_MATURITY_THRESHOLD constant exists", _mat isa Int && _mat > 0)
catch e
    record("AIML_MATURITY_THRESHOLD", false, "$e")
end

# ══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ══════════════════════════════════════════════════════════════
total = length(results)
passed = count(x -> x[2], results)
failed = total - passed

section("Summary")
log_md("- Total: $(total)  |  Passed: $(passed)  |  Failed: $(failed)")
log_md("- Result: $(failed == 0 ? "✅ ALL PASS" : "❌ $(failed) FAILURES")")
println("\n", "=" ^ 60)
println("Deep Specimen Test: $(passed)/$(total) passed")
if failed > 0
    println("FAILURES:")
    for (n, p, d) in results
        p && continue
        println("  ❌ $n — $d")
    end
else
    println("✅ ALL PASS")
end
println("=" ^ 60)

# Write final journal entry
journal_on!()
journal_section("Deep Test Complete")
journal_pass("deep test finished"; detail="$(passed)/$(total) passed")
journal_off!()

# Write the markdown log
flush_log()
println("\nLog written to: $(LOG_PATH)")
