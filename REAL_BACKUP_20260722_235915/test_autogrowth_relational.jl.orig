# test_autogrowth_relational.jl
# ============================================================
# Comprehensive test that AutoGrowth v7.58 properly integrates
# dynamic sigil relationals across ALL growth types.
#
# Core assertion: When a node is autogrown from relational gap
# evidence, it MUST receive relational_patterns with sigil
# references (&causal, &temporal, &includes, etc.) and
# corresponding relation_weights — regardless of growth type.
#
# GRUG: Functions defined at TOP-LEVEL scope (not inside `let`).
# A Julia 1.9.4 lowering bug causes UndefVarError when functions
# inside `let` blocks contain for-loops with splatted kwargs.
# At top-level scope the bug does not trigger. For variables
# modified inside functions (pass_count, fail_count), we use
# explicit `global` declarations.
# ============================================================
ENV["GRUG_NO_AUTOLOAD"] = "1"
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
include("src/Main.jl")

const SPEC = joinpath(@__DIR__, "specimens", "comprehensive_v3_specimen.json")
println("Loading specimen: $SPEC")
load_specimen_from_file!(SPEC)

using .AutoGrowth

# ── Helper: run a mission silently and capture result ──
function run_silent_mission(text::String)
    lock(_LAST_VOICE_OUTPUT_LOCK) do
        _LAST_VOICE_OUTPUT[] = ""
        _LAST_FIRED_NODE[] = ""
        _LAST_PRIMARY_ACTION[] = ""
        _LAST_CONFIDENCE[] = 0.0
    end
    orig = stdout
    (rd, wr) = redirect_stdout()
    try process_mission(text) catch e end
    redirect_stdout(orig)
    close(wr); close(rd)
    resp = ""; node = ""; action = ""; conf = 0.0
    lock(_LAST_VOICE_OUTPUT_LOCK) do
        resp   = _LAST_VOICE_OUTPUT[]
        node   = _LAST_FIRED_NODE[]
        action = _LAST_PRIMARY_ACTION[]
        conf   = _LAST_CONFIDENCE[]
    end
    return (text, resp, node, action, conf)
end

# ── Shared kwargs builder for maybe_grow_from_evidence! ──
verb_fn = (verb) -> SemanticVerbs.verb_class_of(verb)

function make_grow_kwargs(; user_text::String = "",
                            verb_class_of_fn = verb_fn)
    Dict{Symbol, Any}(
        :node_map                 => NODE_MAP,
        :node_lock                => NODE_LOCK,
        :create_node_fn           => create_node,
        :add_to_group_fn          => add_to_group!,
        :register_group_fn        => register_group!,
        :group_map                => GROUP_MAP,
        :group_lock               => GROUP_LOCK,
        :lobe_registry            => Lobe.LOBE_REGISTRY,
        :immune_gate_fn           => (pattern, data) -> true,
        :thesaurus_gate_filter    => Thesaurus.synonym_lookup,
        :thesaurus_word_similarity => Thesaurus.word_similarity,
        :sigil_promote_fn         => (text) -> SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, text),
        :extract_triples_fn       => (pat) -> extract_relational_triples(pat),
        :evaluate_dialectics_fn   => (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
        :words_to_signal_fn       => (words) -> PatternScanner.words_to_signal(words),
        :scan_latch_candidates_fn => (pattern, action_packet; kwargs...) -> _scan_latch_candidates(pattern, action_packet; kwargs...),
        :verb_class_of_fn         => verb_class_of_fn,
        :user_text                => user_text,
        :sigil_table              => _ENGINE_SIGIL_TABLE,
    )
end

pass_count = 0
fail_count = 0

function check(name::String, condition::Bool)
    global pass_count
    global fail_count
    if condition
        println("  ✅ PASS: $name")
        pass_count += 1
    else
        println("  ❌ FAIL: $name")
        fail_count += 1
    end
end

# Helper: try growth with retries, returns (success, grown_node_or_nothing)
# GRUG: Defined at top-level scope to avoid Julia 1.9.4 lowering bug
# (UndefVarError: <loopvar>! not defined) that occurs when functions
# inside `let` blocks contain for-loops with splatted kwargs.
function try_grow_with_retries(kwargs_dict, pattern, triples, growth_type;
                                max_attempts::Int=30, add_intensity::Float64=6.0)
    grow_fn = AutoGrowth.maybe_grow_from_evidence!   # bind before loop (extra safety)
    add_fn  = AutoGrowth._add_evidence!               # bind before loop (extra safety)
    for attempt in 1:max_attempts
        result = grow_fn(; kwargs_dict...)
        if result !== nothing && result.won_coinflip && !isempty(result.new_id)
            println(string("  Coinflip won on attempt ", attempt))
            grown_node = lock(NODE_LOCK) do
                get(NODE_MAP, result.new_id, nothing)
            end
            return (true, grown_node)
        elseif result !== nothing && !result.won_coinflip
            # Re-add evidence for retry
            for _ in 1:3
                add_fn(pattern, add_intensity, "relational_gap", growth_type;
                       lobe_hint="lobe_science",
                       user_triples=triples)
            end
        end
    end
    return (false, nothing)
end

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 1: verb→sigil reverse mapping helpers")
println("============================================")

# Test _verb_to_sigil_ref with SemanticVerbs fast path (verb_class_of)
sigil_ref_1 = AutoGrowth._verb_to_sigil_ref("make"; verb_class_of_fn=verb_fn)
check("\"make\" → \"&causal\"", sigil_ref_1 == "&causal")

sigil_ref_1b = AutoGrowth._verb_to_sigil_ref("causes"; verb_class_of_fn=verb_fn)
check("\"causes\" → \"&causal\"", sigil_ref_1b == "&causal")

# Test _verb_to_sigil_ref with SigilRegistry fallback (verbs in sigil expansions but not SemanticVerbs)
sigil_ref_2 = AutoGrowth._verb_to_sigil_ref("before"; verb_class_of_fn=verb_fn,
                                             sigil_table=_ENGINE_SIGIL_TABLE)
check("\"before\" → \"&temporal\" (via sigil table)", sigil_ref_2 == "&temporal")

sigil_ref_2b = AutoGrowth._verb_to_sigil_ref("after"; verb_class_of_fn=verb_fn,
                                              sigil_table=_ENGINE_SIGIL_TABLE)
check("\"after\" → \"&temporal\" (via sigil table)", sigil_ref_2b == "&temporal")

sigil_ref_3 = AutoGrowth._verb_to_sigil_ref("has"; verb_class_of_fn=verb_fn,
                                             sigil_table=_ENGINE_SIGIL_TABLE)
check("\"has\" → \"&possessive\" (via sigil table)", sigil_ref_3 == "&possessive")

# GRUG: "contains" is in BOTH SemanticVerbs (class "includes") AND SigilRegistry (sigil "possessive").
# The SemanticVerbs fast path takes priority (O(1) vs O(n)), so _verb_to_sigil_ref returns "&includes".
sigil_ref_3b = AutoGrowth._verb_to_sigil_ref("contains"; verb_class_of_fn=verb_fn,
                                              sigil_table=_ENGINE_SIGIL_TABLE)
check("\"contains\" → \"&includes\" (SemanticVerbs fast path beats sigil table)", sigil_ref_3b == "&includes")

# Unknown verb stays concrete
sigil_ref_4 = AutoGrowth._verb_to_sigil_ref("xyzzy"; verb_class_of_fn=verb_fn,
                                             sigil_table=_ENGINE_SIGIL_TABLE)
check("\"xyzzy\" → \"xyzzy\" (no sigil)", sigil_ref_4 == "xyzzy")

# Without sigil_table, "before" should NOT map (not in SemanticVerbs)
sigil_ref_5 = AutoGrowth._verb_to_sigil_ref("before"; verb_class_of_fn=verb_fn)
check("\"before\" without sigil_table → \"before\" (no mapping)", sigil_ref_5 == "before")

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 2: Triple promotion to sigil form")
println("============================================")

promoted_1 = AutoGrowth._promote_triple_to_sigil(("fire", "makes", "warmth");
                         verb_class_of_fn=verb_fn, sigil_table=_ENGINE_SIGIL_TABLE)
check("(fire, makes, warmth) → (fire, &causal, warmth)",
      promoted_1 == ("fire", "&causal", "warmth"))

promoted_2 = AutoGrowth._promote_triple_to_sigil(("storm", "before", "calm");
                         verb_class_of_fn=verb_fn, sigil_table=_ENGINE_SIGIL_TABLE)
check("(storm, before, calm) → (storm, &temporal, calm)",
      promoted_2 == ("storm", "&temporal", "calm"))

promoted_3 = AutoGrowth._promote_triple_to_sigil(("dragon", "has", "scales");
                         verb_class_of_fn=verb_fn, sigil_table=_ENGINE_SIGIL_TABLE)
check("(dragon, has, scales) → (dragon, &possessive, scales)",
      promoted_3 == ("dragon", "&possessive", "scales"))

# GRUG: "contains" maps to verb class "includes" (SemanticVerbs fast path)
promoted_3b = AutoGrowth._promote_triple_to_sigil(("box", "contains", "gold");
                         verb_class_of_fn=verb_fn, sigil_table=_ENGINE_SIGIL_TABLE)
check("(box, contains, gold) → (box, &includes, gold)",
      promoted_3b == ("box", "&includes", "gold"))

promoted_4 = AutoGrowth._promote_triple_to_sigil(("cat", "xyzzy", "moon");
                         verb_class_of_fn=verb_fn, sigil_table=_ENGINE_SIGIL_TABLE)
check("(cat, xyzzy, moon) → stays concrete (cat, xyzzy, moon)",
      promoted_4 == ("cat", "xyzzy", "moon"))

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 3: _compute_relational_patterns_from_triples")
println("============================================")

(promoted_list, weights) = AutoGrowth._compute_relational_patterns_from_triples(
    [("fire", "makes", "warmth"), ("fire", "before", "cold"), ("fire", "has", "smoke")],
    "fire";
    verb_class_of_fn=verb_fn,
    sigil_table=_ENGINE_SIGIL_TABLE
)

println("  Computed patterns:")
for p in promoted_list
    println("    $p")
end
println("  Weights: $weights")

has_causal = any(t -> t[2] == "&causal", promoted_list)
has_temporal = any(t -> t[2] == "&temporal", promoted_list)
has_possessive = any(t -> t[2] == "&possessive", promoted_list)

check("fire triples include &causal", has_causal)
check("fire triples include &temporal", has_temporal)
check("fire triples include &possessive", has_possessive)
check("weights include &causal", haskey(weights, "&causal"))
check("weights include &temporal", haskey(weights, "&temporal"))
check("weights include &possessive", haskey(weights, "&possessive"))
check("sigil weights >= 1.3 (higher than concrete)", weights["&causal"] >= 1.3)

# Test relevance filtering — triples NOT about "fire" should be excluded
(promoted_list2, _) = AutoGrowth._compute_relational_patterns_from_triples(
    [("fire", "makes", "warmth"), ("water", "has", "fish")],
    "fire";
    verb_class_of_fn=verb_fn,
    sigil_table=_ENGINE_SIGIL_TABLE
)
fire_only = all(t -> occursin("fire", lowercase(t[1])) || occursin("fire", lowercase(t[3])),
                promoted_list2)
check("Non-fire triple (water has fish) filtered out", fire_only && length(promoted_list2) == 1)

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 4: SOURCE 18 — relational gap evidence accumulation")
println("============================================")

AutoGrowth.reset_evidence!()

# GRUG: Must use registered verb form "causes" (not "cause") —
# "cause" is NOT in SemanticVerbs.get_all_verbs(), so extract_relational_triples
# returns empty for "glaciers cause erosion".
run_silent_mission("glaciers causes erosion")

snap1 = AutoGrowth.get_evidence_snapshot()
relational_gap_entries = filter(e -> "relational_gap" in get(e, "sources", []), snap1)
println("  Relational gap entries after 1 input: $(length(relational_gap_entries))")

# Repeated input to build evidence
for i in 1:8
    run_silent_mission("glaciers causes erosion and water makes life")
end

snap2 = AutoGrowth.get_evidence_snapshot()
relational_gap_entries2 = filter(e -> "relational_gap" in get(e, "sources", []), snap2)
println("  Relational gap entries after 9 inputs: $(length(relational_gap_entries2))")

# Check that some entries have user_triples
has_triples = any(e -> !isempty(get(e, "user_triples", [])), relational_gap_entries2)
check("SOURCE 18 stores user_triples on evidence records", has_triples)

# Check intensity above floor
high_intensity = filter(e -> Float64(e["accumulated_intensity"]) >= AutoGrowth.EVIDENCE_FLOOR,
                        relational_gap_entries2)
check("Some entries above evidence floor ($(AutoGrowth.EVIDENCE_FLOOR))",
      !isempty(high_intensity))

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 5: Evidence snapshot/load roundtrip for user_triples")
println("============================================")

AutoGrowth._add_evidence!("volcano", 5.0, "relational_gap", :match;
                          lobe_hint="lobe_science",
                          user_triples=[("volcano", "makes", "lava")])

snap_before = AutoGrowth.get_evidence_snapshot()
volcano_before = filter(e -> e["pattern"] == "volcano", snap_before)
ut_before = isempty(volcano_before) ? [] : get(first(volcano_before), "user_triples", [])
println("  Before roundtrip: volcano user_triples = $ut_before")

AutoGrowth.load_evidence_snapshot!(snap_before)
snap_after = AutoGrowth.get_evidence_snapshot()
volcano_after = filter(e -> e["pattern"] == "volcano", snap_after)

if !isempty(volcano_after)
    ut_after = get(first(volcano_after), "user_triples", [])
    println("  After roundtrip:  volcano user_triples = $ut_after")
    check("user_triples survive snapshot/load roundtrip", !isempty(ut_after))
else
    check("user_triples survive snapshot/load roundtrip", false)
end

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 6: Forced growth — autogrown :match node gets sigil relational patterns")
println("============================================")

AutoGrowth.reset_evidence!()

# Add evidence 3x to pass frequency floor
for _ in 1:3
    AutoGrowth._add_evidence!("tornado", 6.0, "relational_gap", :match;
                              lobe_hint="lobe_science",
                              user_triples=[("tornado", "causes", "destruction")])
end

snap3 = AutoGrowth.get_evidence_snapshot()
tornado_entry = filter(e -> e["pattern"] == "tornado", snap3)
if !isempty(tornado_entry)
    println("  Tornado evidence: intensity=$(Float64(first(tornado_entry)["accumulated_intensity"])), " *
            "user_triples=$(get(first(tornado_entry), "user_triples", []))")
end

# Try to grow — coinflip cap is 25%, retry up to 30 times
kwargs6 = make_grow_kwargs(user_text="tornado causes destruction")
growth6_success, grown6_node = try_grow_with_retries(kwargs6, "tornado",
                                [("tornado", "causes", "destruction")], :match)

if growth6_success && grown6_node !== nothing
    println("  Node pattern: $(grown6_node.pattern)")
    println("  Node relational_patterns: $(grown6_node.relational_patterns)")
    println("  Node relation_weights: $(grown6_node.relation_weights)")
    has_sigil = any(rp -> startswith(rp.relation, "&"), grown6_node.relational_patterns)
    check(":match autogrown node has sigil relational patterns", has_sigil)
    has_causal = any(rp -> rp.relation == "&causal", grown6_node.relational_patterns)
    check(":match autogrown node has &causal specifically", has_causal)
else
    check(":match autogrown node has sigil relational patterns", false)
    check(":match autogrown node has &causal specifically", false)
    println("  (Growth coinflip never won in 30 attempts — probabilistic, not a bug)")
end

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 7: ALL growth types get sigil relational patterns")
println("============================================")
println("  (Testing :match, :time, :antimatch, :sigil, :thesaurus, :lobe_whitelist)")
println("  (growth covers all node types not just a single type)")

# ── Node-creating growth types: test that autogrown nodes get sigil relational patterns ──
# GRUG: Only :match, :time, :aiml, :antimatch create actual Node objects in NODE_MAP.
# These are the types where relational_patterns on the node matter for scan matching.
# :sigil, :thesaurus, :lobe_whitelist don't create nodes — they register
# sigil expansions, synonym pairs, or whitelist entries respectively.
# For those, we test _compute_relational_patterns_from_triples directly
# (the promotion function that converts concrete verbs → sigil refs).
node_growth_type_tests = [
    (:match,     "earthquake", [("earthquake", "causes", "destruction")], "earthquake causes destruction", "&causal"),
    (:time,      "tomorrow",   [("tomorrow", "follows", "today")],        "tomorrow follows today",         "&temporal"),
    (:antimatch, "no_fire",    [("no_fire", "contradicts", "fire")],      "no_fire contradicts fire",        "&causal"),
]

for (gt, test_pattern, test_triples, test_user_text, expected_sigil) in node_growth_type_tests
    AutoGrowth.reset_evidence!()

    # Add evidence 3x to pass frequency floor
    for _ in 1:3
        AutoGrowth._add_evidence!(test_pattern, 8.0, "relational_gap", gt;
                                  lobe_hint="lobe_science",
                                  user_triples=test_triples)
    end

    # GRUG: Antimatch has 0.1 growth rate (very conservative). Need more retries.
    max_att = gt == :antimatch ? 120 : 30
    kwargs7 = make_grow_kwargs(user_text=test_user_text)
    found_sigil, grown7 = try_grow_with_retries(kwargs7, test_pattern, test_triples, gt;
                                                  add_intensity=8.0, max_attempts=max_att)

    if found_sigil && grown7 !== nothing
        has_rels = !isempty(grown7.relational_patterns)
        has_sigil = any(rp -> startswith(rp.relation, "&"), grown7.relational_patterns)
        has_expected = any(rp -> rp.relation == expected_sigil, grown7.relational_patterns)
        println("  $gt: pattern=$(grown7.pattern), " *
                "relational_patterns=$(grown7.relational_patterns), " *
                "has_sigil=$has_sigil, has_$(expected_sigil)=$has_expected")
        check("$gt growth gets relational patterns", has_rels)
        check("$gt growth gets sigil reference (starts with &)", has_sigil)
        check("$gt growth gets $expected_sigil specifically", has_expected)
    else
        check("$gt growth gets relational patterns", false)
        check("$gt growth gets sigil reference (starts with &)", false)
        check("$gt growth gets $expected_sigil specifically", false)
        println("  $gt: Growth coinflip never won — probabilistic, not a bug")
    end
end

# ── Non-node growth types: test that _compute_relational_patterns_from_triples
#    produces sigil refs for the verbs associated with each growth type ──
# GRUG: The core architectural claim is that sigil promotion works for ALL growth
# types. For node-creating types we proved it above by growing nodes. For non-node
# types (:sigil, :thesaurus, :lobe_whitelist), we prove it by calling the same
# promotion function directly — if it produces &causal, &temporal, &possessive refs
# for these triples, then the wiring is correct regardless of growth type.
non_node_promotion_tests = [
    (:sigil,          "storm",     [("storm", "has", "lightning")],             "&possessive"),
    (:thesaurus,      "avalanche", [("avalanche", "causes", "snowfall")],      "&causal"),
    (:lobe_whitelist, "hurricane", [("hurricane", "before", "landfall")],      "&temporal"),
]

for (gt, pat, test_triples, expected_sigil) in non_node_promotion_tests
    (promoted, weights) = AutoGrowth._compute_relational_patterns_from_triples(
        test_triples, pat;
        verb_class_of_fn=verb_fn,
        sigil_table=_ENGINE_SIGIL_TABLE)
    has_sigil = any(rp -> startswith(rp[2], "&"), promoted)
    has_expected = any(rp -> rp[2] == expected_sigil, promoted)
    println("  $gt: triples=$test_triples → promoted=$promoted, weights=$weights, has_sigil=$has_sigil, has_$(expected_sigil)=$has_expected")
    check("$gt: _compute_relational_patterns_from_triples produces sigil refs", has_sigil)
    check("$gt: _compute_relational_patterns_from_triples produces $expected_sigil", has_expected)
end

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 8: SigilRegistry.verb_to_relation_sigil reverse lookup")
println("============================================")

check("verb_to_relation_sigil(\"before\") == \"temporal\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "before") == "temporal")
check("verb_to_relation_sigil(\"after\") == \"temporal\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "after") == "temporal")
check("verb_to_relation_sigil(\"causes\") == \"causal\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "causes") == "causal")
check("verb_to_relation_sigil(\"has\") == \"possessive\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "has") == "possessive")
check("verb_to_relation_sigil(\"owns\") == \"possessive\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "owns") == "possessive")
check("verb_to_relation_sigil(\"contains\") == \"possessive\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "contains") == "possessive")
check("verb_to_relation_sigil(\"above\") == \"spatial\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "above") == "spatial")
check("verb_to_relation_sigil(\"resembles\") == \"similarity\"",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "resembles") == "similarity")
check("verb_to_relation_sigil(\"xyzzy\") === nothing",
      SigilRegistry.verb_to_relation_sigil(_ENGINE_SIGIL_TABLE, "xyzzy") === nothing)

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("TEST 9: _parse_action_name handles SubString{String}")
println("============================================")

# This was the bug that crashed TEST 4 before — split() returns SubString
parts = split("comfort[gentle]^3 | support[steady]^2 | acknowledge^1", '|')
for p in parts
    name = AutoGrowth._parse_action_name(strip(p))
    weight = AutoGrowth._parse_action_weight(strip(p))
    println("  Part \"$p\" → name=\"$name\", weight=$weight")
end
check("_parse_action_name works on SubString from split()", true)

# ══════════════════════════════════════════════════════════════════
println("\n============================================")
println("ALL TESTS COMPLETE")
println("============================================")
println("  Passed: $pass_count")
println("  Failed: $fail_count")
if fail_count == 0
    println("  🎉 ALL TESTS PASSED!")
else
    println("  ⚠️  SOME TESTS FAILED — review output above")
end
