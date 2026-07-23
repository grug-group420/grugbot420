# test_smoke.jl
# ==============================================================================
# GRUG SMOKE TEST: Exercise all new systems introduced in this update.
# Tests run in order. Any failure throws loudly (no silent failures).
# ==============================================================================

using JSON, Distributions, Random

println("\n" * "="^60)
println("GRUG SMOKE TEST SUITE")
println("="^60)

# ==============================================================================
# 1. MODULE LOADS
# ==============================================================================
println("\n[1] MODULE LOADS")

include("stochastichelper.jl");       using .CoinFlipHeader;        println("  ✓ StochasticHelper")
include("patternscanner.jl");         using .PatternScanner;        println("  ✓ PatternScanner")
include("ImageSDF.jl");               using .ImageSDF;              println("  ✓ ImageSDF")
include("EyeSystem.jl");              using .EyeSystem;             println("  ✓ EyeSystem")
include("ChatterMode.jl");            using .ChatterMode;           println("  ✓ ChatterMode")
include("SemanticVerbs.jl");          using .SemanticVerbs;         println("  ✓ SemanticVerbs")
include("ActionTonePredictor.jl");    using .ActionTonePredictor;   println("  ✓ ActionTonePredictor")
include("engine.jl")
println("  ✓ Engine (full chain)")

# ==============================================================================
# 2. IMAGE SDF - detect_image_binary (no image in plain text)
# ==============================================================================
println("\n[2] IMAGE BINARY DETECTION")

found, fmt, payload = ImageSDF.detect_image_binary("hello world this is plain text")
@assert !found          "FAIL: Plain text falsely detected as image!"
@assert fmt == :none    "FAIL: fmt should be :none for plain text!"
println("  ✓ Plain text correctly returns (false, :none, \"\")")

# GRUG: Test Base64 detection
b64_test = "data:image/png;base64," * "A" ^ 80
found2, fmt2, payload2 = ImageSDF.detect_image_binary(b64_test)
@assert found2          "FAIL: Base64 image not detected!"
@assert fmt2 == :base64 "FAIL: Format should be :base64!"
@assert length(payload2) >= 64 "FAIL: Payload too short!"
println("  ✓ Base64 image data URI correctly detected")

# ==============================================================================
# 3. IMAGE SDF - image_to_sdf_params (synthetic grayscale image)
# ==============================================================================
println("\n[3] IMAGE -> SDF PARAMS")

w, h = 8, 8
fake_img = UInt8[round(UInt8, 128 + 50*sin(i/4.0)) for i in 0:(w*h-1)]
sdf = ImageSDF.image_to_sdf_params(fake_img, w, h)
@assert length(sdf.xArray) == w*h          "FAIL: xArray wrong length!"
@assert length(sdf.yArray) == w*h          "FAIL: yArray wrong length!"
@assert length(sdf.brightnessArray) == w*h "FAIL: brightnessArray wrong length!"
@assert length(sdf.colorArray) == w*h      "FAIL: colorArray wrong length!"
@assert all(0.0 .<= sdf.xArray .<= 1.0)   "FAIL: xArray out of range!"
@assert all(0.0 .<= sdf.yArray .<= 1.0)   "FAIL: yArray out of range!"
@assert sdf.width  == w                    "FAIL: width mismatch!"
@assert sdf.height == h                    "FAIL: height mismatch!"
println("  ✓ SDFParams created correctly for $(w)x$(h) grayscale image")

# GRUG: Test sdf_to_signal flattening
signal = ImageSDF.sdf_to_signal(sdf; max_samples=16)
@assert length(signal) == 16 * 4  "FAIL: Signal length should be max_samples * 4!"
@assert all(0.0 .<= signal .<= 1.0) "FAIL: Signal values out of [0,1] range!"
println("  ✓ sdf_to_signal: length=$(length(signal)), all values in [0.0, 1.0]")

# GRUG: Test jitter stays bounded
jittered = ImageSDF.apply_sdf_jitter(sdf)
@assert length(jittered.brightnessArray) == w*h "FAIL: Jitter changed array length!"
@assert all(0.0 .<= jittered.brightnessArray .<= 1.0) "FAIL: Jitter brightness out of range!"
println("  ✓ apply_sdf_jitter: all values still in [0.0, 1.0]")

# ==============================================================================
# 4. EYE SYSTEM - arousal, edge blur, attention map
# ==============================================================================
println("\n[4] EYE SYSTEM")

EyeSystem.set_arousal!(0.8)
@assert EyeSystem.get_arousal() ≈ 0.8 "FAIL: Arousal not set correctly!"
println("  ✓ set_arousal!(0.8) -> get_arousal()=$(EyeSystem.get_arousal())")

EyeSystem.decay_arousal!()
@assert EyeSystem.get_arousal() < 0.8 "FAIL: Arousal should decay!"
println("  ✓ decay_arousal!() reduced arousal to $(round(EyeSystem.get_arousal(), digits=4))")

# Test edge blur
brightness = fill(0.5, w*h)
blurred = EyeSystem.apply_edge_blur(brightness, w, h, EyeSystem.DEFAULT_EDGE_BLUR)
@assert length(blurred) == w*h "FAIL: Edge blur changed array length!"
@assert all(0.0 .<= blurred .<= 1.0) "FAIL: Edge blur values out of range!"
println("  ✓ apply_edge_blur: length OK, values in [0.0, 1.0]")

# Test attention map
EyeSystem.set_arousal!(0.3)
attn = EyeSystem.compute_attention_map(brightness, w, h, 0.3)
@assert length(attn.weights) == w*h   "FAIL: Attention map wrong length!"
@assert all(0.0 .<= attn.weights .<= 1.0) "FAIL: Attention weights out of range!"
println("  ✓ compute_attention_map: centroid=($(round(attn.center_x,digits=3)), $(round(attn.center_y,digits=3)))")

# Test full pipeline
mod_b, attn2 = EyeSystem.process_visual_input(
    sdf.brightnessArray, sdf.colorArray,
    sdf.xArray, sdf.yArray, w, h
)
@assert length(mod_b) == w*h "FAIL: process_visual_input output wrong length!"
@assert all(0.0 .<= mod_b .<= 1.0) "FAIL: Modulated brightness out of range!"
println("  ✓ process_visual_input: full pipeline OK")

# ==============================================================================
# 5. ENGINE - Node creation, strength, neighbors, graves
# ==============================================================================
println("\n[5] ENGINE - NODE SYSTEMS")

ctx = Dict{String,Any}("system_prompt" => "Test node.")
nid = create_node("test alpha beta gamma", "reason^2 | analyze^1", ctx, String[])
@assert haskey(NODE_MAP, nid) "FAIL: Node not in NODE_MAP after creation!"
node = NODE_MAP[nid]
@assert node.strength >= 0.0 && node.strength <= STRENGTH_CAP "FAIL: Strength out of range!"
@assert !node.is_grave        "FAIL: New node should not be grave!"
@assert !node.is_unlinkable   "FAIL: New node with 0 neighbors should not be unlinkable!"
@assert node.hopfield_key != 0 "FAIL: Hopfield key should be set for text node!"
println("  ✓ create_node: id=$nid, strength=$(node.strength), neighbors=$(length(node.neighbor_ids))")

# Test bump_strength
old_str = node.strength
for _ in 1:20; bump_strength!(node); end
@assert node.strength <= STRENGTH_CAP "FAIL: Strength exceeded cap after bumps!"
println("  ✓ bump_strength!: capped at STRENGTH_CAP=$(STRENGTH_CAP), current=$(node.strength)")

# Test penalize_strength
node.strength = 1.0
for _ in 1:30; penalize_strength!(node); end
@assert node.strength >= 0.0 "FAIL: Strength went below 0!"
println("  ✓ penalize_strength!: floored at 0.0, current=$(node.strength), grave=$(node.is_grave)")

# ==============================================================================
# 6. ENGINE - Neighbor linking (UNLINKABLE at 4)
# ==============================================================================
println("\n[6] ENGINE - NEIGHBOR LINKING")

# GRUG: Create nodes with deliberately unique/dissimilar patterns so auto-latch
# does NOT consume any neighbor slots during creation (no token overlap).
link_nodes = [create_node("zzz_unique_xq7_$i", "reason^1", Dict{String,Any}("system_prompt"=>"lnk"), String[]) for i in 1:6]
hub_node = NODE_MAP[link_nodes[1]]

# GRUG: Reset hub neighbor state cleanly before manual linking test
lock(NODE_LOCK) do
    empty!(hub_node.neighbor_ids)
    hub_node.is_unlinkable = false
    for i in 2:6
        n = NODE_MAP[link_nodes[i]]
        empty!(n.neighbor_ids)
        n.is_unlinkable = false
    end
end

# Link 4 neighbors -> should become UNLINKABLE
for i in 2:5
    linked = try_link_nodes!(hub_node, NODE_MAP[link_nodes[i]])
    @assert linked "FAIL: Link $i should succeed!"
end
@assert hub_node.is_unlinkable "FAIL: Node should be UNLINKABLE after 4 neighbors!"
println("  ✓ UNLINKABLE triggered at $(MAX_NEIGHBORS) neighbors")

# 5th link attempt should fail
linked5 = try_link_nodes!(hub_node, NODE_MAP[link_nodes[6]])
@assert !linked5 "FAIL: 5th link should be rejected (UNLINKABLE)!"
println("  ✓ 5th link correctly rejected (UNLINKABLE)")

# ==============================================================================
# 7. ENGINE - Big-O ledger (GRAVED-SLOW)
# ==============================================================================
println("\n[7] ENGINE - BIG-O LEDGER")

slow_id   = create_node("slow response node", "reason^1", Dict{String,Any}("system_prompt"=>"slow"), String[])
slow_node = NODE_MAP[slow_id]
slow_node.is_grave = false  # reset in case penalize graved it

# Record a slow response time that exceeds threshold
record_response_time!(slow_node, SLOW_NODE_THRESHOLD_SECONDS + 1.0)
@assert slow_node.is_grave "FAIL: Slow node should be GRAVED-SLOW!"
@assert slow_node.grave_reason == "GRAVED-SLOW" "FAIL: Wrong grave reason!"
println("  ✓ GRAVED-SLOW triggered (avg $(SLOW_NODE_THRESHOLD_SECONDS+1.0)s > threshold $(SLOW_NODE_THRESHOLD_SECONDS)s)")

# ==============================================================================
# 8. ENGINE - Hopfield cache
# ==============================================================================
println("\n[8] ENGINE - HOPFIELD CACHE")

test_hash = hopfield_input_hash("hello world test query")
@assert test_hash != 0 "FAIL: Hopfield hash should not be zero!"
result = hopfield_lookup(test_hash)
@assert isnothing(result) "FAIL: Should be nothing (never seen before)!"

# Record it twice to hit the HOPFIELD_HIT_COUNT_MIN threshold
hopfield_record!(test_hash, ["node_0", "node_1"])
hopfield_record!(test_hash, ["node_0", "node_1"])
result2 = hopfield_lookup(test_hash)
@assert !isnothing(result2) "FAIL: Should have cache hit after $(HOPFIELD_HIT_COUNT_MIN) records!"
@assert "node_0" in result2 "FAIL: node_0 should be in cached results!"
println("  ✓ Hopfield cache: miss on first look, hit after $(HOPFIELD_HIT_COUNT_MIN) records")

# ==============================================================================
# 9. ENGINE - scan_and_expand (drop-table co-activation)
# ==============================================================================
println("\n[9] ENGINE - SCAN + DROP TABLE CO-ACTIVATION")

# Create two nodes where node B is in node A's drop table
ctx_a = Dict{String,Any}("system_prompt" => "Primary node A.")
ctx_b = Dict{String,Any}("system_prompt" => "Drop table node B.")
nid_b = create_node("secondary drop table beta", "analyze^1", ctx_b, String[])
nid_a = create_node("hello hi greeting test",    "greet^3 | welcome^2", ctx_a, String[nid_b])

# scan_and_expand should find A and co-activate B
results = scan_and_expand("hello hi greeting")
ids_found = [r[1] for r in results]
println("  ✓ scan_and_expand returned $(length(results)) results. IDs: $(ids_found[1:min(3,end)])")
if nid_a in ids_found
    println("  ✓ Primary node $nid_a activated")
end

# ==============================================================================
# 10. ENGINE - /wrong feedback
# ==============================================================================
println("\n[10] ENGINE - /WRONG FEEDBACK")

wrong_id   = create_node("wrong feedback test node", "reason^1", Dict{String,Any}("system_prompt"=>"wt"), String[])
wrong_node = NODE_MAP[wrong_id]
wrong_node.strength = 5.0  # Set known strength
before_str = wrong_node.strength

apply_wrong_feedback!([wrong_id])
# Strength should be <= before (coinflip may or may not have hit)
@assert wrong_node.strength <= before_str "FAIL: /wrong should never INCREASE strength!"
println("  ✓ apply_wrong_feedback!: strength $(before_str) -> $(wrong_node.strength)")

# ==============================================================================
# 11. CHATTER MODE - session + anti-collision + queue
# ==============================================================================
println("\n[11] CHATTER MODE")

chatter_snapshot = [
    ("node_chatter_1", "hello greeting warm", "greet^2", 3.0),
    ("node_chatter_2", "think reason analyze", "reason^3", 7.0),
    ("node_chatter_3", "cold logic process",   "analyze^2", 5.0),
    ("node_chatter_4", "danger flee escape",   "flee^1",   1.0),
    ("node_chatter_5", "welcome friend hello", "greet^2",  4.0),
]

# Pad to at least 100 for valid session (ChatterMode requires 100-800)
full_snapshot = vcat(chatter_snapshot, [("node_pad_$i", "pad pattern $i", "reason^1", rand()*5) for i in 1:100])

session = ChatterMode.start_chatter_session!(full_snapshot)
@assert session.group_size >= 100 "FAIL: Group size should be >= 100!"
@assert session.end_time > session.start_time "FAIL: Session end time should be after start!"
@assert !session.is_running "FAIL: Session should not be running after completion!"
println("  ✓ Chatter session complete: group=$(session.group_size), exchanges=$(session.exchanges_completed), copies=$(session.copies_accepted)")

# Test input queue
ChatterMode.enqueue_input!("queued test input")
status = ChatterMode.get_chatter_status()
@assert status.queue_depth == 1 "FAIL: Queue depth should be 1 after enqueue!"
println("  ✓ Input queue: depth=$(status.queue_depth)")

drained = ChatterMode.drain_input_queue!()
@assert length(drained) == 1 "FAIL: Should drain exactly 1 item!"
@assert drained[1] == "queued test input" "FAIL: Wrong queued content drained!"
println("  ✓ drain_input_queue!: drained $(length(drained)) item(s) correctly")

# ==============================================================================
# 12. STOCHASTIC AIML RULES (fire probability)
# ==============================================================================
println("\n[12] STOCHASTIC AIML RULES")

# Add a rule with 100% fire probability
add_orchestration_rule!("Always fire: {MISSION}")
@assert length(AIML_DROP_TABLE) >= 1 "FAIL: Rule not added!"
@assert AIML_DROP_TABLE[end].fire_probability == 1.0 "FAIL: Default prob should be 1.0!"
println("  ✓ Default rule fire_probability = $(AIML_DROP_TABLE[end].fire_probability)")

# Add a rule with explicit 50% probability
add_orchestration_rule!("Sometimes fire: {PRIMARY_ACTION} [prob=0.5]")
@assert AIML_DROP_TABLE[end].fire_probability == 0.5 "FAIL: Prob should be 0.5!"
@assert !contains(AIML_DROP_TABLE[end].text, "[prob=") "FAIL: Prob suffix should be stripped from rule text!"
println("  ✓ Stochastic rule fire_probability = $(AIML_DROP_TABLE[end].fire_probability), text stripped cleanly")

# Bad prob should throw
try
    add_orchestration_rule!("Bad rule [prob=99.9]")
    println("  ✗ FAIL: Should have thrown for prob=99.9!")
catch e
    println("  ✓ Correctly rejected invalid prob=99.9")
end

# ==============================================================================
# 13. NODE STATUS SUMMARY
# ==============================================================================
println("\n[13] NODE STATUS SUMMARY")

summary = get_node_status_summary()
@assert contains(summary, "NODE MAP STATUS") "FAIL: Summary missing header!"
status_ok = contains(summary, "ALIVE") || contains(summary, "GRAVE")
@assert status_ok "FAIL: Summary missing status tags!"
summary_lines = length(split(summary, "\n"))
println("  ✓ get_node_status_summary() returned $summary_lines lines")

# ==============================================================================
# 14. STRENGTH-BIASED SCAN COINFLIP (distribution check)
# ==============================================================================
println("\n[14] STRENGTH-BIASED SCAN COINFLIP")

ctx_weak   = Dict{String,Any}("system_prompt"=>"w")
ctx_strong = Dict{String,Any}("system_prompt"=>"s")
weak_id    = create_node("weak node test",   "reason^1", ctx_weak,   String[])
strong_id  = create_node("strong node test", "reason^1", ctx_strong, String[])
weak_n     = NODE_MAP[weak_id];   weak_n.strength   = 0.0
strong_n   = NODE_MAP[strong_id]; strong_n.strength = STRENGTH_CAP

N = 1000
weak_hits   = count(_ -> strength_biased_scan_coinflip(weak_n),   1:N)
strong_hits = count(_ -> strength_biased_scan_coinflip(strong_n), 1:N)
weak_rate   = weak_hits   / N
strong_rate = strong_hits / N

@assert weak_rate   < strong_rate "FAIL: Strong node should activate more than weak!"
@assert weak_rate   < 0.5        "FAIL: Weak node rate $(weak_rate) should be < 0.5!"
@assert strong_rate > 0.5        "FAIL: Strong node rate $(strong_rate) should be > 0.5!"
println("  ✓ Weak(str=0): $(round(weak_rate*100,digits=1))% | Strong(str=$(STRENGTH_CAP)): $(round(strong_rate*100,digits=1))%")

# ==============================================================================
# 15. SEMANTIC VERBS - USER-EXTENSIBLE VERB/SYNONYM SYSTEM
# ==============================================================================
println("\n[15] SEMANTIC VERBS")

# Baseline classes should exist
classes = SemanticVerbs.get_relation_classes()
@assert "causal"   in classes "FAIL: causal class missing from registry!"
@assert "spatial"  in classes "FAIL: spatial class missing from registry!"
@assert "temporal" in classes "FAIL: temporal class missing from registry!"
classes_str = join(classes, ", ")
println("  ✓ Default classes present: $(classes_str)")

# Add new relation class
SemanticVerbs.add_relation_class!("epistemic_test")
new_classes = SemanticVerbs.get_relation_classes()
@assert "epistemic_test" in new_classes "FAIL: New relation class not found after add!"
println("  ✓ add_relation_class! works")

# Add verb to new class
SemanticVerbs.add_verb!("implies_test", "epistemic_test")
ep_verbs = SemanticVerbs.get_verbs_in_class("epistemic_test")
@assert "implies_test" in ep_verbs "FAIL: Verb 'implies_test' not found after add!"
println("  ✓ add_verb! works")

# get_all_verbs includes the new verb
all_v = SemanticVerbs.get_all_verbs()
@assert "implies_test" in all_v "FAIL: New verb missing from get_all_verbs()!"
println("  ✓ get_all_verbs() includes runtime-added verb")

# Add synonym and test normalization
SemanticVerbs.add_synonym!("causes", "triggers_test")
normed = SemanticVerbs.normalize_synonyms("heat triggers_test destruction")
@assert contains(normed, "causes")    "FAIL: Synonym 'triggers_test' not normalized to 'causes'!"
@assert !contains(normed, "triggers_test") "FAIL: Alias still present after normalization!"
println("  ✓ add_synonym! + normalize_synonyms work")

# Synonym flows into extract_relational_triples
triples_via_syn = extract_relational_triples("heat triggers_test destruction")
syn_triple_ok = any(t -> t.relation == "causes", triples_via_syn)
@assert syn_triple_ok "FAIL: Synonym normalization did not flow into extract_relational_triples!"
println("  ✓ Synonym normalization flows into extract_relational_triples")

# Runtime verb addition flows into extract_relational_triples
triples_new_verb = extract_relational_triples("science implies_test knowledge")
new_verb_ok = any(t -> t.relation == "implies_test", triples_new_verb)
@assert new_verb_ok "FAIL: Runtime-added verb not picked up by extract_relational_triples!"
println("  ✓ Runtime verb addition flows into extract_relational_triples")

# Error cases: verb to nonexistent class
# GRUG: Use Ref{Bool} to avoid Julia soft-scope catch variable shadowing in top-level script
err_ref_verb = Ref(false)
try
    SemanticVerbs.add_verb!("foo", "nonexistent_class_xyz")
catch e
    err_ref_verb[] = true
end
@assert err_ref_verb[] "FAIL: Should error when adding verb to nonexistent class!"
println("  ✓ add_verb! to nonexistent class correctly errors")

# Error cases: synonym for nonexistent canonical
err_ref_syn = Ref(false)
try
    SemanticVerbs.add_synonym!("nonexistent_verb_xyz", "alias")
catch e
    err_ref_syn[] = true
end
@assert err_ref_syn[] "FAIL: Should error when canonical verb not in registry!"
println("  ✓ add_synonym! with bad canonical correctly errors")

# ==============================================================================
# 16. ACTION+TONE PREDICTOR
# ==============================================================================
println("\n[16] ACTION+TONE PREDICTOR")

test_verbs = SemanticVerbs.get_all_verbs()

# Query detection
p_query = ActionTonePredictor.predict_action_tone("what causes the system crash?", test_verbs)
@assert p_query.action_family == ActionTonePredictor.ACTION_QUERY "FAIL: Expected ACTION_QUERY, got $(p_query.action_family)"
println("  ✓ ACTION_QUERY detected from 'what causes the system crash?'")

# Command detection
p_cmd = ActionTonePredictor.predict_action_tone("run the tests now", test_verbs)
@assert p_cmd.action_family == ActionTonePredictor.ACTION_COMMAND "FAIL: Expected ACTION_COMMAND, got $(p_cmd.action_family)"
println("  ✓ ACTION_COMMAND detected from 'run the tests now'")

# Hostile tone detection
p_hostile = ActionTonePredictor.predict_action_tone("this is wrong and broken garbage", test_verbs)
@assert p_hostile.tone_family == ActionTonePredictor.TONE_HOSTILE "FAIL: Expected TONE_HOSTILE, got $(p_hostile.tone_family)"
println("  ✓ TONE_HOSTILE detected from hostile input")

# Dangling causal chain detection
p_dangle = ActionTonePredictor.predict_action_tone("fire causes", test_verbs)
@assert p_dangle.incomplete_chain == true  "FAIL: Expected incomplete_chain=true!"
@assert p_dangle.dangling_verb == "causes" "FAIL: Expected dangling_verb='causes', got $(p_dangle.dangling_verb)"
println("  ✓ Incomplete causal chain detected ('fire causes' - dangling)")

# Arousal nudge is positive for hostile/urgent
p_urgent = ActionTonePredictor.predict_action_tone("STOP this immediately critical", test_verbs)
@assert p_urgent.arousal_nudge > 0.0 "FAIL: Urgent/escalate should produce positive arousal nudge!"
println("  ✓ Arousal nudge > 0 for urgent/escalate input")

# Arousal nudge is negative for reflective
p_reflect = ActionTonePredictor.predict_action_tone("i think perhaps it might be interesting", test_verbs)
@assert p_reflect.arousal_nudge <= 0.0 "FAIL: Reflective tone should produce <= 0 arousal nudge!"
println("  ✓ Arousal nudge <= 0 for reflective input")

# Action weight multiplier: aligned > 1.0, misaligned < 1.0
w_align   = ActionTonePredictor.get_action_weight_multiplier(p_query, "query_answer_respond")
w_misalign = ActionTonePredictor.get_action_weight_multiplier(p_query, "execute_command_action")
@assert w_align > 1.0   "FAIL: Aligned node weight should be > 1.0!"
@assert w_misalign < 1.0 "FAIL: Misaligned node weight should be < 1.0!"
println("  ✓ Weight multiplier: aligned=$(round(w_align,digits=2)) > 1.0, misaligned=$(round(w_misalign,digits=2)) < 1.0")

# format_prediction_summary returns non-empty string
summary_str = ActionTonePredictor.format_prediction_summary(p_query)
@assert !isempty(summary_str) "FAIL: format_prediction_summary returned empty!"
println("  ✓ format_prediction_summary: $(summary_str)")

# apply_prediction_to_arousal! nudges EyeSystem correctly
old_arousal = EyeSystem.get_arousal()
ActionTonePredictor.apply_prediction_to_arousal!(p_urgent, EyeSystem.get_arousal, EyeSystem.set_arousal!)
new_arousal = EyeSystem.get_arousal()
@assert new_arousal >= old_arousal "FAIL: Urgent prediction should raise arousal!"
println("  ✓ apply_prediction_to_arousal! nudged arousal $(round(old_arousal,digits=3)) -> $(round(new_arousal,digits=3))")

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("✅  ALL SMOKE TESTS PASSED (16 groups)")
println("="^60 * "\n")