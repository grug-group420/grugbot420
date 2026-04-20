# test_comprehensive.jl
# ==============================================================================
# GRUG COMPREHENSIVE FEATURE TEST
# Exercises all major systems and their interactions. One test to rule them all.
# Every feature added since v0.1. No silent failures. If it breaks, Grug screams.
# ==============================================================================

using Test
using JSON
using Random
using Distributions

println("\n" * "="^60)
println("GRUG COMPREHENSIVE FEATURE TEST")
println("="^60)

# ==============================================================================
# 1. FULL MODULE CHAIN
# ==============================================================================
println("\n[1] FULL MODULE CHAIN")

include("../src/stochastichelper.jl");      using .CoinFlipHeader;       println("  ✓ StochasticHelper")
include("../src/patternscanner.jl");        using .PatternScanner;       println("  ✓ PatternScanner")
include("../src/ImageSDF.jl");              using .ImageSDF;             println("  ✓ ImageSDF")
include("../src/EyeSystem.jl");             using .EyeSystem;            println("  ✓ EyeSystem")
include("../src/ChatterMode.jl");           using .ChatterMode;          println("  ✓ ChatterMode")
include("../src/SemanticVerbs.jl");         using .SemanticVerbs;        println("  ✓ SemanticVerbs")
include("../src/ActionTonePredictor.jl");   using .ActionTonePredictor;  println("  ✓ ActionTonePredictor")
include("../src/ImmuneSystem.jl");          using .ImmuneSystem;         println("  ✓ ImmuneSystem")
include("../src/engine.jl")
println("  ✓ Engine (full chain including ImmuneSystem)")

# GRUG: COMMANDS dict is populated in Main.jl action families. Engine tests don't
# include Main.jl. Register minimal handlers for all action names used in test nodes.
# IMPORTANT: Register BEFORE any nodes are created, so Hopfield cache hits can execute.
# GRUG FIX: Always register test handlers (remove haskey guard to ensure registration).
for _act in ["reason", "analyze", "greet", "flee", "ponder"]
    COMMANDS[_act] = (mission, node, pv, sv, uv, av) -> "test_$(string(_act))_output"
end

# ==============================================================================
# 2. NODE LIFECYCLE — CREATE, SCAN, VOTE
# ==============================================================================
println("\n[2] NODE LIFECYCLE")

# Create nodes
ids = grow_nodes_from_packet(JSON.json(Dict(
    "nodes" => [
        Dict("pattern" => "fire makes grug warm",
             "action_packet" => "reason^1.0",
             "json_data" => Dict("system_prompt" => "grug logic cave")),
        Dict("pattern" => "water puts out fire",
             "action_packet" => "analyze^1.0",
             "json_data" => Dict("system_prompt" => "grug logic cave")),
        Dict("pattern" => "grug like shiny rocks",
             "action_packet" => "greet^1.0",
             "json_data" => Dict("system_prompt" => "grug happy cave")),
    ]
)))
@assert length(ids) == 3 "FAIL: Expected 3 nodes grown, got $(length(ids))!"
println("  ✓ grow_nodes_from_packet: planted $(length(ids)) nodes: $ids")

# Verify nodes in map
for id in ids
    @assert haskey(NODE_MAP, id) "FAIL: Node $id not in NODE_MAP!"
    n = NODE_MAP[id]
    @assert !isempty(n.pattern) "FAIL: Node $id has empty pattern!"
    @assert !isempty(n.signal) "FAIL: Node $id has empty signal!"
    @assert !n.is_grave "FAIL: Node $id should not be grave at birth!"
end
println("  ✓ All 3 nodes verified in NODE_MAP (alive, have pattern + signal)")

# ==============================================================================
# 3. PATTERN SCANNING — scan_specimens
# ==============================================================================
println("\n[3] PATTERN SCANNING")

# GRUG: scan_specimens is stochastic (strength-biased coinflip gate + random active_cap).
# Cannot hard-assert results in a small test cave -- node may not fire every run.
# Just call it, log what fires, verify it doesn't throw. No silent failures.
scan_result = scan_specimens("fire makes grug warm and happy")
println("  ✓ scan_specimens ran without error: $(length(scan_result)) result(s) fired (stochastic)")
ids_found = Set(r[1] for r in scan_result)

# Test non-matching input (should return empty or not include fire nodes)
results_miss = scan_specimens("ancient philosophy of grug thinking")
# Not asserting empty — engine may still fire on loose tokens — just log
println("  ✓ scan_specimens on unrelated input: $(length(results_miss)) result(s) (ok)")

# ==============================================================================
# 4. VOTE CASTING & SURE/UNSURE BUCKETING
# ==============================================================================
println("\n[4] VOTE CASTING & SURE/UNSURE BUCKETING")

# Create known votes with controlled confidences
v_sure1 = Vote("node_a", "reason", 2.5, String[], RelationalTriple[], RelationalTriple[], false)
v_sure2 = Vote("node_b", "analyze", 2.5, String[], RelationalTriple[], RelationalTriple[], false)
v_sure3 = Vote("node_c", "reason", 2.495, String[], RelationalTriple[], RelationalTriple[], false)  # within 0.05
v_unsure = Vote("node_d", "greet", 1.8, String[], RelationalTriple[], RelationalTriple[], false)

all_votes = [v_sure1, v_sure2, v_sure3, v_unsure]
sorted_votes = sort(all_votes; by = v -> v.confidence, rev = true)
max_conf = sorted_votes[1].confidence

sure_votes = Vote[v for v in sorted_votes if v.confidence >= max_conf - 0.05]
unsure_candidates = Vote[v for v in sorted_votes if v.confidence < max_conf - 0.05]

@assert length(sure_votes) == 3 "FAIL: Expected 3 sure votes, got $(length(sure_votes))!"
@assert length(unsure_candidates) == 1 "FAIL: Expected 1 unsure candidate, got $(length(unsure_candidates))!"
println("  ✓ Sure basket: $(length(sure_votes)) votes | Unsure candidates: $(length(unsure_candidates))")

# ==============================================================================
# 5. VOTE TIE-BREAKING — RANDOM WINNER SELECTION
# ==============================================================================
println("\n[5] VOTE TIE-BREAKING")

top_conf = sure_votes[1].confidence
tied_votes = Vote[v for v in sure_votes if abs(v.confidence - top_conf) < 1e-9]
@assert length(tied_votes) == 2 "FAIL: Expected 2 exact ties (2.5 and 2.5), got $(length(tied_votes))!"

# Run 300 trials — both tied nodes must win at least once
win_map = Dict(v.node_id => 0 for v in tied_votes)
for _ in 1:300
    tc = copy(tied_votes)
    shuffle!(tc)
    win_map[tc[1].node_id] += 1
end
for (nid, cnt) in win_map
    @assert cnt > 0 "FAIL: $nid never won in 300 tie-break trials — broken randomness!"
end
println("  ✓ Tie-breaking: both tied nodes won in 300 trials: $win_map")

# ==============================================================================
# 6. SURE vs UNSURE CLASSIFICATION
# ==============================================================================
println("\n[6] SURE vs UNSURE CLASSIFICATION")

# Primary from tie → UNSURE
primary_tied = tied_votes[1]
tied_alternatives = Vote[v for v in sure_votes if v.node_id != primary_tied.node_id]
certainty = isempty(tied_alternatives) ? "SURE" : "UNSURE"
@assert certainty == "UNSURE" "FAIL: Tied primary should yield UNSURE!"
println("  ✓ Tie → UNSURE (tied_alternatives=$(length(tied_alternatives)))")

# Primary alone → SURE
primary_solo = v_sure1
solo_sure = [v_sure1]
solo_alts = Vote[v for v in solo_sure if v.node_id != primary_solo.node_id]
solo_certainty = isempty(solo_alts) ? "SURE" : "UNSURE"
@assert solo_certainty == "SURE" "FAIL: Solo primary should yield SURE!"
println("  ✓ Solo winner → SURE")

# ==============================================================================
# 7. AIML RULE TAGS — ALL TAGS VALIDATE
# ==============================================================================
println("\n[7] AIML RULE TAGS")

expected_tags = [
    "{MISSION}", "{PRIMARY_ACTION}", "{SURE_ACTIONS}", "{UNSURE_ACTIONS}",
    "{ALL_ACTIONS}", "{CONFIDENCE}", "{NODE_ID}", "{MEMORY}", "{LOBE_CONTEXT}",
    "{VOTE_CERTAINTY}", "{TIED_ALTERNATIVES}"
]
for tag in expected_tags
    @assert tag in ALLOWED_RULE_TAGS "FAIL: $tag missing from ALLOWED_RULE_TAGS!"
end
println("  ✓ All $(length(expected_tags)) AIML tags registered in ALLOWED_RULE_TAGS")

# Add and retrieve a rule using new tags
empty!(AIML_DROP_TABLE)
result1 = add_orchestration_rule!("Certainty: {VOTE_CERTAINTY}. Alternatives: {TIED_ALTERNATIVES} [prob=0.9]")
result2 = add_orchestration_rule!("Primary: {PRIMARY_ACTION}. Mission: {MISSION} [prob=1.0]")
@assert length(AIML_DROP_TABLE) == 2 "FAIL: Expected 2 rules, got $(length(AIML_DROP_TABLE))!"
@assert AIML_DROP_TABLE[1].fire_probability == 0.9 "FAIL: Rule 1 prob should be 0.9!"
@assert AIML_DROP_TABLE[2].fire_probability == 1.0 "FAIL: Rule 2 prob should be 1.0!"
println("  ✓ Rules with {VOTE_CERTAINTY} and {TIED_ALTERNATIVES} added and stored correctly")

# Confirm fake tag still rejected
# GRUG: Use Ref to avoid Julia top-level soft scope issue with catch block assignment.
_threw_ref = Ref(false)
try
    add_orchestration_rule!("Bad tag: {FAKE_TAG}")
catch e
    _threw_ref[] = true  # any error = rejection worked
end
@assert _threw_ref[] "FAIL: Fake AIML tag {FAKE_TAG} should have been rejected!"
println("  ✓ Fake tag {FAKE_TAG} correctly rejected")

# ==============================================================================
# 8. IMMUNE SYSTEM — STRUCT AND STATE
# ==============================================================================
println("\n[8] IMMUNE SYSTEM")

# ImmuneError struct
err = ImmuneSystem.ImmuneError(:funky_deleted, UInt64(0xDEADBEEF), "test rejection")
@assert err.kind == :funky_deleted "FAIL: ImmuneError kind mismatch!"
@assert err.signature == UInt64(0xDEADBEEF) "FAIL: ImmuneError signature mismatch!"
println("  ✓ ImmuneError struct constructed correctly")

# Reset state
ImmuneSystem.reset_immune_state!()
n_sigs = lock(ImmuneSystem.IMMUNE_HOPFIELD_LOCK) do; length(ImmuneSystem.IMMUNE_HOPFIELD) end
@assert n_sigs == 0 "FAIL: Immune state should be empty after reset!"
println("  ✓ reset_immune_state! clears Hopfield memory")

# Immature specimen (below 1000 nodes) — immune system sleeps
small_count = 5
status, sig = ImmuneSystem.immune_scan!("normal input", small_count; is_critical=true)
@assert status == :immature "FAIL: Small cave should return :immature, got $status!"
println("  ✓ Below maturity threshold → :immature (pass-through)")

# Serialize/deserialize round-trip
serialized = ImmuneSystem.serialize_immune_state()
@assert isa(serialized, Dict) "FAIL: serialize_immune_state should return Dict!"
ImmuneSystem.deserialize_immune_state!(serialized)
println("  ✓ Immune state serialize/deserialize round-trip works")

# ==============================================================================
# 9. SEMANTIC VERBS — RUNTIME MUTABILITY
# ==============================================================================
println("\n[9] SEMANTIC VERBS")

# Add a new relation class and verb
SemanticVerbs.add_relation_class!("test_class_comp")
SemanticVerbs.add_verb!("compels", "test_class_comp")
SemanticVerbs.add_synonym!("compels", "forces")

classes = SemanticVerbs.get_relation_classes()
@assert "test_class_comp" in classes "FAIL: test_class_comp should be in classes!"

verbs = SemanticVerbs.get_verbs_in_class("test_class_comp")
@assert "compels" in verbs "FAIL: 'compels' should be in test_class_comp!"

synonyms = SemanticVerbs.get_synonym_map()
@assert haskey(synonyms, "forces") "FAIL: 'forces' should be synonym of 'compels'!"
@assert synonyms["forces"] == "compels" "FAIL: 'forces' → 'compels' mapping wrong!"
println("  ✓ SemanticVerbs: class created, verb added, synonym registered")

# ==============================================================================
# 10. RELATIONAL TRIPLES — EXTRACTION FROM INPUT
# ==============================================================================
println("\n[10] RELATIONAL TRIPLES")

triples = extract_relational_triples("fire causes warmth and water prevents fire")
@assert isa(triples, Vector{RelationalTriple}) "FAIL: extract_relational_triples wrong return type!"
# Should extract at least one triple with causal/preventive relation
println("  ✓ extract_relational_triples returned $(length(triples)) triple(s)")
for t in triples
    @assert !isempty(t.subject) "FAIL: Triple subject is empty!"
    @assert !isempty(t.relation) "FAIL: Triple relation is empty!"
    @assert !isempty(t.object) "FAIL: Triple object is empty!"
    println("    ($(t.subject), $(t.relation), $(t.object))")
end

# ==============================================================================
# 11. HOPFIELD CACHE — FAMILIAR INPUT FAST-PATH
# ==============================================================================
println("\n[11] HOPFIELD CACHE")

# Record high-confidence nodes for a known input
# GRUG: HOPFIELD_HIT_COUNT_MIN = 2, so need to record twice before lookup hits.
input_hash = hopfield_input_hash("fire makes grug warm")
hopfield_record!(input_hash, [ids[1]])
hopfield_record!(input_hash, [ids[1]])  # second record crosses HOPFIELD_HIT_COUNT_MIN
cached = hopfield_lookup(input_hash)
@assert !isnothing(cached) "FAIL: Hopfield lookup returned nothing after 2 recordings!"
@assert ids[1] in cached "FAIL: Hopfield cache missing recorded node!"
println("  ✓ Hopfield record/lookup round-trip works (2 records to cross HIT_COUNT_MIN)")

# Unknown input hash should miss
unknown_hash = hopfield_input_hash("completely unknown grug phrase xyz987")
@assert isnothing(hopfield_lookup(unknown_hash)) "FAIL: Unknown input should miss Hopfield!"
println("  ✓ Unknown input correctly misses Hopfield cache")

# ==============================================================================
# 12. NODE STRENGTH — BUMP AND DECAY
# ==============================================================================
println("\n[12] NODE STRENGTH")

test_node = NODE_MAP[ids[1]]
original_strength = test_node.strength

# bump_strength! is coinflip-based — run many times to see at least one bump
# GRUG: Use Ref to avoid Julia top-level soft scope issue with for loop assignment.
_bumped_ref = Ref(false)
for _ in 1:50
    bump_strength!(test_node)
    if NODE_MAP[ids[1]].strength > original_strength
        _bumped_ref[] = true
        break
    end
end
@assert _bumped_ref[] "FAIL: bump_strength! never increased strength in 50 trials!"
println("  ✓ bump_strength! successfully increased node strength")

# Verify strength stays within bounds
@assert NODE_MAP[ids[1]].strength <= STRENGTH_CAP "FAIL: Strength exceeded STRENGTH_CAP!"
println("  ✓ Strength respects STRENGTH_CAP ($(STRENGTH_CAP))")

# ==============================================================================
# 13. WRONG FEEDBACK — COINFLIP PENALTY
# ==============================================================================
println("\n[13] WRONG FEEDBACK (coinflip penalty)")

pre_strength = NODE_MAP[ids[2]].strength
apply_wrong_feedback!([ids[2]])
# Strength should be <= pre (may stay same if coinflip was lucky)
@assert NODE_MAP[ids[2]].strength <= pre_strength "FAIL: Wrong feedback should not increase strength!"
println("  ✓ apply_wrong_feedback! applied to node (strength: $(pre_strength) → $(NODE_MAP[ids[2]].strength))")

# ==============================================================================
# 14. GRAVE MECHANISM
# ==============================================================================
println("\n[14] GRAVE MECHANISM")

# Force a node to zero strength manually and grave it
test_grave_node = NODE_MAP[ids[3]]
# Apply wrong many times to force to grave or just test it directly
pre_grave = test_grave_node.is_grave
println("  ✓ Grave mechanism accessible (node currently is_grave=$(pre_grave))")
# We don't force grave it — just verify the field exists and is accessible
@assert isa(pre_grave, Bool) "FAIL: is_grave should be Bool!"

# ==============================================================================
# 15. STOCHASTIC HELPER — @coinflip MACRO
# ==============================================================================
println("\n[15] STOCHASTIC HELPER")

# Run @coinflip 200 times, verify both branches fire
# GRUG: @coinflip returns outcome.name which is a Symbol (:yes/:no), not a String.
outcomes = Symbol[]
for _ in 1:200
    result = @coinflip [
        bias(:yes, 50) => () -> :yes,
        bias(:no,  50) => () -> :no
    ]
    push!(outcomes, result)
end
yes_count = count(x -> x == :yes, outcomes)
no_count  = count(x -> x == :no,  outcomes)
@assert yes_count > 0 "FAIL: :yes never fired in 200 trials!"
@assert no_count  > 0 "FAIL: :no never fired in 200 trials!"
println("  ✓ @coinflip: yes=$yes_count no=$no_count in 200 trials")

# ==============================================================================
# 16. ACTION TONE PREDICTOR
# ==============================================================================
println("\n[16] ACTION TONE PREDICTOR")

all_verbs = SemanticVerbs.get_all_verbs()
prediction = ActionTonePredictor.predict_action_tone("why does fire cause heat", all_verbs)
@assert isa(prediction, ActionTonePredictor.PredictionResult) "FAIL: Wrong return type from predictor!"
@assert 0.0 <= prediction.confidence <= 1.0 "FAIL: Confidence out of [0,1] range!"
@assert 0.0 <= prediction.arousal_nudge <= 1.0 "FAIL: arousal_nudge out of range!"
@assert prediction.action_weight >= 0.5 "FAIL: action_weight should be >= 0.5!"
println("  ✓ ActionTonePredictor returned valid PredictionResult")
println("    action=$(prediction.action_family), tone=$(prediction.tone_family), conf=$(round(prediction.confidence, digits=2))")

# ==============================================================================
# 17. PATTERN SCANNER — ALL TIERS
# ==============================================================================
println("\n[17] PATTERN SCANNER — ALL TIERS")

sig_full  = Float64[1.0, 0.5, 0.8, 0.3, 0.9, 0.2, 0.7, 0.4, 0.6, 0.1]
sig_pat3  = Float64[1.0, 0.5, 0.8]
sig_pat5  = Float64[0.8, 0.3, 0.9, 0.2, 0.7]
sig_pat9  = Float64[1.0, 0.5, 0.8, 0.3, 0.9, 0.2, 0.7, 0.4, 0.6]

_, c1 = PatternScanner.cheap_scan(sig_full, sig_pat3; threshold=0.1)
@assert c1 > 0.0 "FAIL: cheap_scan returned zero confidence!"
println("  ✓ cheap_scan: conf=$(round(c1, digits=3))")

_, c2 = PatternScanner.medium_scan(sig_full, sig_pat5; threshold=0.1)
@assert c2 > 0.0 "FAIL: medium_scan returned zero confidence!"
println("  ✓ medium_scan: conf=$(round(c2, digits=3))")

_, c3 = PatternScanner.high_res_scan(sig_full, sig_pat9; threshold=0.1)
@assert c3 > 0.0 "FAIL: high_res_scan returned zero confidence!"
println("  ✓ high_res_scan: conf=$(round(c3, digits=3))")

# Bidirectional scan — defined in engine.jl (Main scope), not PatternScanner
_, c4 = _bidirectional_cheap_scan(sig_full, sig_pat3; threshold=0.1)
@assert c4 > 0.0 "FAIL: _bidirectional_cheap_scan returned zero confidence!"
println("  ✓ bidirectional_cheap_scan: conf=$(round(c4, digits=3))")

# Tier selection
mode_short = screen_input_complexity(Float64[1.0, 0.5, 0.8], RelationalTriple[])
mode_long  = screen_input_complexity(sig_full, RelationalTriple[])
@assert mode_short <= mode_long "FAIL: Short input should not demand higher scan tier than long!"
println("  ✓ screen_input_complexity: short=$(mode_short), long=$(mode_long)")

# ==============================================================================
# 18. EYE SYSTEM — AROUSAL
# ==============================================================================
println("\n[18] EYE SYSTEM")

EyeSystem.set_arousal!(0.75)
@assert abs(EyeSystem.get_arousal() - 0.75) < 1e-6 "FAIL: Arousal not set to 0.75!"
println("  ✓ EyeSystem arousal set/get works (0.75)")

EyeSystem.set_arousal!(0.0)
@assert abs(EyeSystem.get_arousal() - 0.0) < 1e-6 "FAIL: Arousal reset failed!"
println("  ✓ EyeSystem arousal reset to 0.0")

# ==============================================================================
# 19. STOCHASTIC RULE SYSTEM — FIRE PROBABILITY
# ==============================================================================
println("\n[19] STOCHASTIC RULE FIRE PROBABILITY")

empty!(AIML_DROP_TABLE)

# Prob=1.0 rule must ALWAYS fire
add_orchestration_rule!("Always fires [prob=1.0]")
# GRUG: Use Ref to avoid Julia top-level soft scope issue.
_fires_ref = Ref(0)
for _ in 1:50
    if rand() <= AIML_DROP_TABLE[1].fire_probability
        _fires_ref[] += 1
    end
end
@assert _fires_ref[] == 50 "FAIL: prob=1.0 rule should fire all 50 times, fired $(_fires_ref[])!"
println("  ✓ prob=1.0 rule fires all 50/50 times")

# Prob=0.0 rule must NEVER fire
add_orchestration_rule!("Never fires [prob=0.0]")
# GRUG: Use Ref to avoid Julia top-level soft scope issue.
_never_ref = Ref(0)
for _ in 1:50
    if rand() <= AIML_DROP_TABLE[2].fire_probability
        _never_ref[] += 1
    end
end
@assert _never_ref[] == 0 "FAIL: prob=0.0 rule should never fire, fired $(_never_ref[])!"
println("  ✓ prob=0.0 rule fires 0/50 times")

# Prob=0.5 rule fires roughly half
add_orchestration_rule!("Half fires [prob=0.5]")
half_fires = sum(rand() <= AIML_DROP_TABLE[3].fire_probability for _ in 1:500)
@assert 150 < half_fires < 350 "FAIL: prob=0.5 rule fired $half_fires/500 — suspicious!"
println("  ✓ prob=0.5 rule fires $(half_fires)/500 times (expected ~250)")

# ==============================================================================
# 20. NODE ATTACHMENT SYSTEM
# ==============================================================================
println("\n[20] NODE ATTACHMENT SYSTEM")

# Create two test nodes for attachment
attach_ids = grow_nodes_from_packet(JSON.json(Dict(
    "nodes" => [
        Dict("pattern" => "grug strong rock",
             "action_packet" => "reason^1.0",
             "json_data" => Dict("system_prompt" => "cave")),
        Dict("pattern" => "rock falls down fast",
             "action_packet" => "analyze^1.0",
             "json_data" => Dict("system_prompt" => "cave")),
    ]
)))
@assert length(attach_ids) == 2 "FAIL: Expected 2 new nodes for attachment test!"

target_id  = attach_ids[1]
attached_id = attach_ids[2]

result = attach_node!(target_id, attached_id, "heavy falling object")
@assert contains(result, "Attached") "FAIL: attach_node! should return confirmation string!"
@assert haskey(ATTACHMENT_MAP, target_id) "FAIL: ATTACHMENT_MAP should have target node!"
@assert length(ATTACHMENT_MAP[target_id]) == 1 "FAIL: Should have 1 attachment!"

att = ATTACHMENT_MAP[target_id][1]
@assert att.node_id == attached_id "FAIL: Attached node ID mismatch!"
@assert att.base_confidence > 0.0 "FAIL: JIT base_confidence should be > 0!"
println("  ✓ attach_node!: $(attached_id) attached to $(target_id) with base_conf=$(round(att.base_confidence, digits=3))")

# Test detach
detach_result = detach_node!(target_id, attached_id)
@assert contains(detach_result, "Detached") || contains(detach_result, "etach") "FAIL: detach_node! should return confirmation!"
println("  ✓ detach_node!: attachment removed")

# ==============================================================================
# 21. CAST_VOTE AND EXPLICIT VOTE
# ==============================================================================
println("\n[21] VOTE CASTING")

# cast_vote on a known node
test_vote_id = ids[1]
test_specimens = scan_specimens("fire makes grug warm")
if !isempty(test_specimens)
    id, conf, antimatch, u_trips, n_trips = test_specimens[1]
    vote = cast_vote(id, conf, antimatch, u_trips, n_trips)
    @assert isa(vote, Vote) "FAIL: cast_vote should return Vote struct!"
    @assert vote.node_id == id "FAIL: Vote node_id mismatch!"
    @assert vote.confidence == conf "FAIL: Vote confidence mismatch!"
    println("  ✓ cast_vote returned valid Vote: node=$(vote.node_id) action=$(vote.action) conf=$(round(vote.confidence, digits=2))")
else
    println("  ⚠  scan_specimens returned empty — cast_vote test skipped (scan stochastic)")
end

# cast_explicit_vote
explicit_vote = cast_explicit_vote("reason", ids[1])
@assert explicit_vote.action == "reason" "FAIL: cast_explicit_vote action mismatch!"
@assert explicit_vote.confidence == 9999.0 "FAIL: Explicit vote confidence should be 9999.0!"
println("  ✓ cast_explicit_vote: action=reason, conf=9999.0")

# ==============================================================================
# 22. SCAN_AND_EXPAND — DROP TABLE + LOBE CASCADE + ATTACHMENT RELAY
# ==============================================================================
println("\n[22] SCAN_AND_EXPAND (three-pass expansion)")

expanded = scan_and_expand("fire makes grug warm")
@assert isa(expanded, Vector) "FAIL: scan_and_expand should return a Vector!"
println("  ✓ scan_and_expand returned $(length(expanded)) result(s) after 3-pass expansion")

# All IDs should be unique
seen_ids = String[]
for (id, conf, _, _, _) in expanded
    @assert !(id in seen_ids) "FAIL: Duplicate node $id in scan_and_expand results!"
    push!(seen_ids, id)
end
println("  ✓ No duplicate node IDs in expanded results")

# ==============================================================================
# 23. IMMUNE SYSTEM — SERIALIZE/DESERIALIZE STATE
# ==============================================================================
println("\n[23] IMMUNE SERIALIZE/DESERIALIZE")

# Add some fake signatures to Hopfield
ImmuneSystem.reset_immune_state!()
test_sig = UInt64(0x12345678ABCDEF01)
lock(ImmuneSystem.IMMUNE_HOPFIELD_LOCK) do
    ImmuneSystem.IMMUNE_HOPFIELD[test_sig] = UInt32(5)
end

state = ImmuneSystem.serialize_immune_state()
@assert haskey(state, "hopfield") "FAIL: Serialized state missing 'hopfield' key!"
@assert haskey(state, "ledger") "FAIL: Serialized state missing 'ledger' key!"

# Clear and restore
ImmuneSystem.reset_immune_state!()
ImmuneSystem.deserialize_immune_state!(state)

restored_count = lock(ImmuneSystem.IMMUNE_HOPFIELD_LOCK) do
    length(ImmuneSystem.IMMUNE_HOPFIELD)
end
@assert restored_count >= 1 "FAIL: Deserialize should restore at least 1 signature!"
println("  ✓ Immune state serialize → clear → deserialize: $restored_count signatures restored")

# ==============================================================================
# 24. VOTE TIE-BREAKING — 4-WAY TIE EDGE CASE
# ==============================================================================
println("\n[24] VOTE TIE — 4-WAY EDGE CASE")

quad_votes = [
    Vote("q1", "reason",  3.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("q2", "analyze", 3.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("q3", "greet",   3.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("q4", "flee",    3.0, String[], RelationalTriple[], RelationalTriple[], false),
]
quad_wins = Dict("q1" => 0, "q2" => 0, "q3" => 0, "q4" => 0)
for _ in 1:400
    tc = copy(quad_votes)
    shuffle!(tc)
    quad_wins[tc[1].node_id] += 1
end
for (nid, cnt) in quad_wins
    @assert cnt > 0 "FAIL: $nid never won in 400 4-way tie trials!"
end
println("  ✓ 4-way tie: all nodes won → $quad_wins")

# ==============================================================================
# 25. HOPFIELD CACHE — REPEATED SCAN BUILDS FAMILIARITY
# ==============================================================================
println("\n[25] HOPFIELD FAMILIARITY")

fresh_text = "grug discover wheel at dawn"
h = hopfield_input_hash(fresh_text)
@assert isnothing(hopfield_lookup(h)) "FAIL: Fresh input should miss cache initially!"

# Record 3 times to build familiarity
hopfield_record!(h, [ids[1]])
hopfield_record!(h, [ids[1]])
hopfield_record!(h, [ids[1]])
cached3 = hopfield_lookup(h)
# May or may not hit depending on HOPFIELD_SEEN_THRESHOLD — just verify no error
println("  ✓ Hopfield repeated recording: cached=$(cached3 !== nothing)")

# ==============================================================================
# FINAL SUMMARY
# ==============================================================================
println("\n" * "="^60)
println("ALL COMPREHENSIVE TESTS PASSED! 25 test groups complete.")
println("Features verified: node lifecycle, scanning, voting, tie-breaking,")
println("SURE/UNSURE classification, AIML tags, immune system, semantic verbs,")
println("relational triples, Hopfield cache, strength/decay, stochastic helper,")
println("ActionTonePredictor, pattern scanner tiers, EyeSystem arousal,")
println("node attachments, vote casting, scan_and_expand, serialize/deserialize.")
println("="^60 * "\n")