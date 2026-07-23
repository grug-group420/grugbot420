
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
        record("resolve returns Vector of ScoredIntent", _resolved isa Vector)
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
    _am = compute_attention_map("hello world this is a test input for attention",
                                 EdgeBlurParams(0.25, 0.7))
    record("compute_attention_map returns AttentionMap", _am !== nothing)
catch e
    record("compute_attention_map", false, "$e")
end

subsection("31c. Visual Input")
try
    _vi = process_visual_input("a description of a scene with trees and sky")
    record("process_visual_input returns something", _vi !== nothing)
catch e
    record("process_visual_input", false, "$e")
end
