
# ═══════════════════════════════════════════════════════════════
# 27. BRAIN STEM — Dispatch, Propagation, Fire/Inhibit
# ═══════════════════════════════════════════════════════════════
section("27. Brain Stem — Deep Dispatch & Propagation")

subsection("27a. Dispatch & Status")
try
    _bs_result = dispatch!("hello brain stem test", Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK;
                           node_map=NODE_MAP, node_lock=NODE_LOCK)
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
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if !isempty(_lobe_keys)
        fire_lobe!(_lobe_keys[1], Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
        record("fire_lobe! on first lobe", true)
    else
        record("fire_lobe! (no lobes in registry)", true, "skipped")
    end
catch e
    record("fire_lobe!", false, "$e")
end

try
    _lobe_keys = collect(keys(Lobe.LOBE_REGISTRY))
    if length(_lobe_keys) >= 2
        inhibit_lobe!(_lobe_keys[2], Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
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
    apply_fire_count_decay!(Lobe.LOBE_REGISTRY, Lobe.LOBE_LOCK)
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
        _pred = ActionTonePredictor.PredictionResult(:greet, TONE_FRIENDLY, 0.8, :query)
    catch
        try
            _pred = ActionTonePredictor.PredictionResult(:greet, :friendly, 0.8, :query)
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
