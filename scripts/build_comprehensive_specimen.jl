#!/usr/bin/env julia
# ==============================================================================
# build_comprehensive_specimen.jl
# ------------------------------------------------------------------------------
# GRUG v2.6 -- Build a maximally-loaded GrugBot420 specimen.
#
# This is NOT a vanilla cave with three boot seeds. We light up every lever:
#   - Multiple lobes (math, language, social, survival, reasoning) with
#     cross-lobe cascade connections.
#   - Pattern-reactive nodes spread across all lobes plus the engine-default
#     v2.6 sigil-tagged nodes (math + multipart).
#   - Node attachments (relational fire) pulling support across lobes.
#   - AIML orchestration rules.
#   - AIML node tribes per lobe.
#   - Concept classes + concept inhibitions in the thesaurus.
#   - Group registry with grouped nodes (chatter substrate).
#   - Crystalize tags on hot nodes (auto-NONJITTER).
#   - Inhibitions in the negative thesaurus.
#   - Subconscious microlog with stochastic writes.
#   - Sigil registry with one custom user-defined sigil on top of the
#     6 engine defaults.
#   - Message history primed with a few exchanges.
#   - Eye system arousal + tonal trajectory primed.
#
# Then save the whole thing to <output>.specimen.gz.
#
# Usage:
#   julia --project=. scripts/build_comprehensive_specimen.jl <output_path>
# ==============================================================================

using GrugBot420
using JSON
using Random
const GB = GrugBot420

const OUT_PATH = length(ARGS) > 0 ? ARGS[1] : "/workspace/comprehensive.specimen.gz"

println("="^78)
println("GRUG v2.6 -- BUILDING COMPREHENSIVE SPECIMEN")
println("Target file: $OUT_PATH")
println("="^78)

Random.seed!(42)  # deterministic-ish

# =============================================================================
# Phase 1: lobes + cross-lobe connections
# =============================================================================
println("\n[Phase 1] Creating lobes...")
const LOBE_SPECS = [
    ("lobe_math",      "arithmetic calculation quantitative reasoning compute solve evaluate plus minus times divided add subtract multiply number"),
    ("lobe_language",  "linguistic structure multipart questions conjunctions and then also but or"),
    ("lobe_social",    "greetings empathy social cues comfort hello hi hey"),
    ("lobe_survival",  "danger threat flee fight hide fire smoke burn"),
    ("lobe_reasoning", "logical analysis ponder deduction why think consider reflect"),
    ("lobe_knowledge", "sky ocean water love ecosystem fire nature describe explain what capital france"),
]
for (lid, subj) in LOBE_SPECS
    GB.Lobe.create_lobe!(lid, subj)
    GB.LobeTable.create_lobe_table!(lid)
    println("  ✅ $lid ($subj)")
end

# Cross-lobe cascade connections (math <-> reasoning, language <-> reasoning,
# social <-> language, survival isolated)
function _connect(a::String, b::String)
    rec_a = GB.Lobe.LOBE_REGISTRY[a]
    rec_b = GB.Lobe.LOBE_REGISTRY[b]
    push!(rec_a.connected_lobe_ids, b)
    push!(rec_b.connected_lobe_ids, a)
end
_connect("lobe_math",      "lobe_reasoning")
_connect("lobe_language",  "lobe_reasoning")
_connect("lobe_language",  "lobe_social")
_connect("lobe_math",      "lobe_language")
_connect("lobe_language",  "lobe_knowledge")
_connect("lobe_reasoning", "lobe_knowledge")
println("  🔗 6 cross-lobe cascade edges wired")

# =============================================================================
# Phase 2: pattern-reactive nodes spread across lobes
# =============================================================================
println("\n[Phase 2] Creating pattern-reactive nodes per lobe...")

# helper: create node + attach to a specific lobe
function _node_in_lobe(lobe_id::String, pattern::String, packet::String,
                       data::Dict, drop_table::Vector{String})::String
    nid = GB.create_node(pattern, packet, data, drop_table)
    GB.Lobe.add_node_to_lobe!(lobe_id, nid)
    return nid
end

# --- Math lobe ---
math_ctx = Dict{String,Any}("system_prompt" => "Quantitative reasoning over rewritten arithmetic forms.")
_node_in_lobe("lobe_math", "count number sum total",
    "calculate^4 | reason^2 | analyze^1", math_ctx, String["@nojitter"])
_node_in_lobe("lobe_math", "how many quantity amount",
    "calculate^3 | analyze^2 | ponder^1", math_ctx, String[])
_node_in_lobe("lobe_math", "compute solve evaluate",
    "calculate^5 | reason^2", math_ctx, String[])

# --- Language lobe ---
lang_ctx = Dict{String,Any}("system_prompt" => "Linguistic structure analysis and multi-clause handling.")
_node_in_lobe("lobe_language", "and then also moreover furthermore",
    "explain^3 | clarify^2 | elaborate^1", lang_ctx, String[])
_node_in_lobe("lobe_language", "tell me about describe explain",
    "explain^4 | describe^3 | elaborate^2", lang_ctx, String[])
_node_in_lobe("lobe_language", "what why how when where",
    "explain^3 | clarify^3 | analyze^2", lang_ctx, String[])

# --- Social lobe ---
social_ctx = Dict{String,Any}("system_prompt" => "Polite greeting + empathic response protocols.")
_node_in_lobe("lobe_social", "hello hi hey greetings howdy",
    "greet[dont frown, dont insult]^4 | welcome^3 | smile^2", social_ctx, String[])
_node_in_lobe("lobe_social", "thank thanks appreciate grateful",
    "smile^4 | acknowledge^3 | welcome^2", social_ctx, String[])
_node_in_lobe("lobe_social", "sad upset hurt lonely",
    "comfort^4 | support^3 | reassure^2 | acknowledge^1", social_ctx, String[])

# --- Survival lobe ---
survival_ctx = Dict{String,Any}(
    "system_prompt" => "Threat detection and avoidance.",
    "required_relations" => ["threatens", "attacks"],
    "relation_weights"   => Dict("threatens" => 2.5, "attacks" => 3.0),
)
_node_in_lobe("lobe_survival", "danger threat attack hostile",
    "alert^5 | warn^4 | flee^3", survival_ctx, String["@nojitter"])
_node_in_lobe("lobe_survival", "fire smoke burn flame",
    "alert^4 | warn^3 | flee^2 | hide^1", survival_ctx, String[])

# --- Reasoning lobe ---
reason_ctx = Dict{String,Any}("system_prompt" => "Cold logical analysis engine.")
_node_in_lobe("lobe_reasoning", "think ponder consider reflect",
    "ponder^4 | reason^3 | analyze^2", reason_ctx, String[])
_node_in_lobe("lobe_reasoning", "because therefore thus hence",
    "reason^5 | analyze^3 | explain^2", reason_ctx, String[])
_node_in_lobe("lobe_reasoning", "why does happens occurs",
    "explain^4 | reason^3 | clarify^2", reason_ctx, String[])

# --- Knowledge nodes in knowledge lobe (for multipart test coverage) ---
know_ctx = Dict{String,Any}("system_prompt" => "General knowledge and factual description.")
_node_in_lobe("lobe_knowledge", "sky cloud sun weather atmosphere",
    "describe^4 | explain^3 | clarify^2", know_ctx, String[])
_node_in_lobe("lobe_knowledge", "ocean sea water river lake",
    "describe^4 | explain^3 | elaborate^2", know_ctx, String[])
_node_in_lobe("lobe_knowledge", "water liquid drink rain",
    "describe^4 | explain^2 | clarify^1", know_ctx, String[])
_node_in_lobe("lobe_knowledge", "love emotion feeling heart care",
    "describe^3 | comfort^3 | explain^2", know_ctx, String[])
_node_in_lobe("lobe_knowledge", "ecosystem nature environment forest habitat",
    "describe^4 | explain^3 | elaborate^1", know_ctx, String[])
_node_in_lobe("lobe_knowledge", "fire flame burn heat warm",
    "describe^4 | explain^3 | alert^1", know_ctx, String[])

println("  ✅ 20 pattern-reactive nodes spread across 5 lobes (14 base + 6 knowledge)")

# =============================================================================
# Phase 3: node attachments (relational fire substrate)
# =============================================================================
println("\n[Phase 3] Wiring node attachments (relational fire)...")
# Pick three nodes from different lobes and chain them
math_alive  = collect(GB.Lobe.LOBE_REGISTRY["lobe_math"].node_ids)
lang_alive  = collect(GB.Lobe.LOBE_REGISTRY["lobe_language"].node_ids)
reason_alive = collect(GB.Lobe.LOBE_REGISTRY["lobe_reasoning"].node_ids)

if !isempty(math_alive) && !isempty(reason_alive)
    GB.attach_node!(math_alive[1], reason_alive[1], "compute solve evaluate")
    println("  🔗 attachment: $(math_alive[1]) -> $(reason_alive[1])")
end
if !isempty(lang_alive) && !isempty(reason_alive)
    GB.attach_node!(lang_alive[1], reason_alive[2], "and then also moreover furthermore")
    println("  🔗 attachment: $(lang_alive[1]) -> $(reason_alive[2])")
end

# =============================================================================
# Phase 4: AIML orchestration rules
# =============================================================================
println("\n[Phase 4] Adding AIML orchestration rules...")
try
    GB.add_orchestration_rule!("[empathy] If sad/hurt cues are present, lead with comfort and acknowledge.")
    GB.add_orchestration_rule!("[reasoning] When asked 'why' or 'how', open with reasoning then explanation.")
    GB.add_orchestration_rule!("[math] When computing, state the steps before the final answer.")
    println("  ✅ 3 orchestration rules registered")
catch e
    println("  ⚠️  rule registration: $e")
end

# =============================================================================
# Phase 5: concept classes + concept inhibitions
# =============================================================================
println("\n[Phase 5] Concept classes + inhibitions...")
try
    GB.Thesaurus.add_concept_class!("greeting_words",  ["hello", "hi", "hey", "howdy", "greetings"])
    GB.Thesaurus.add_concept_class!("math_words",      ["plus", "minus", "times", "divided", "equals"])
    GB.Thesaurus.add_concept_class!("question_words",  ["what", "why", "how", "when", "where", "who"])
    GB.Thesaurus.add_concept_class!("comfort_words",   ["sorry", "okay", "alright", "understand", "here"])
    println("  ✅ 4 user-added concept classes (on top of seeded baseline)")
catch e
    println("  ⚠️  concept_class: $e")
end

try
    GB.InputQueue.add_inhibition!("slur1"; reason="user-banned offensive token")
    GB.InputQueue.add_inhibition!("slur2"; reason="user-banned offensive token")
    println("  🚫 2 word-level inhibitions")
catch e
    println("  ⚠️  inhibition: $e")
end

try
    # Pick an existing seeded concept class so the inhibition lands cleanly.
    GB.InputQueue.add_concept_inhibition!("danger"; reason="danger words flagged for survival lobe priority")
    println("  🚫 1 concept-level inhibition")
catch e
    println("  ⚠️  concept_inhibition: $e")
end

# =============================================================================
# Phase 6: group registry (chatter substrate)
# =============================================================================
println("\n[Phase 6] Group registry...")
try
    # Group lobe_math nodes together
    for nid in math_alive
        GB.GroupRegistry.register_node_in_group!("group_math_workers", nid)
    end
    # Group social nodes
    for nid in collect(GB.Lobe.LOBE_REGISTRY["lobe_social"].node_ids)
        GB.GroupRegistry.register_node_in_group!("group_social_pack", nid)
    end
    println("  ✅ 2 groups registered ($(GB.GroupRegistry.group_count()) total)")
catch e
    println("  ⚠️  group: $e")
end

# =============================================================================
# Phase 7: crystalize hot nodes
# =============================================================================
println("\n[Phase 7] Crystalize tags...")
try
    # Crystalize the first math + first survival node manually
    if !isempty(math_alive)
        GB.CrystalizeTag.mark_user_crystalized!(math_alive[1])
        println("  💎 user-crystalized $(math_alive[1])")
    end
    surv_alive = collect(GB.Lobe.LOBE_REGISTRY["lobe_survival"].node_ids)
    if !isempty(surv_alive)
        GB.CrystalizeTag.mark_auto_crystalized!(surv_alive[1])
        println("  💎 auto-crystalized $(surv_alive[1])")
    end
catch e
    println("  ⚠️  crystalize: $e")
end

# =============================================================================
# Phase 8: subconscious microlog (stochastic write a few observations)
# =============================================================================
println("\n[Phase 8] Subconscious microlog...")
try
    # SelfObserver has `observe!` - check exact name
    obs_fn = nothing
    for cand in (:observe!, :record!, :write_observation!, :submit_observation!)
        if isdefined(GB.SelfObserver, cand)
            obs_fn = getfield(GB.SelfObserver, cand)
            break
        end
    end
    if obs_fn !== nothing
        # Use stochastic_write_probability=1.0 by setting the global temporarily? No --
        # just call repeatedly so some land.
        for i in 1:20
            try
                obs_fn("seed observation #$i: cave is calm, weather is mild")
            catch
            end
        end
        println("  ✅ subconscious primed (some observations may have landed via stochastic write)")
    else
        println("  ⚠️  no observe function found in SelfObserver")
    end
catch e
    println("  ⚠️  subconscious: $e")
end

# =============================================================================
# Phase 9: custom sigil on top of defaults
# =============================================================================
println("\n[Phase 9] Custom sigil registration...")
try
    GB.SigilRegistry.register_sigil_global!(
        name = "emoji",
        class = :tag,
        applies_at = :bind,
        provenance = "user",
        promote_at_tokenize = false,
    )
    n_sigils = length(GB.SigilRegistry.default_table().entries)
    println("  ✅ &emoji registered ($n_sigils sigils total in registry)")
catch e
    println("  ⚠️  sigil: $e")
end

# =============================================================================
# Phase 10: AIML node tribes per lobe
# =============================================================================
println("\n[Phase 10] AIML node tribes per lobe...")
try
    for (lid, _) in LOBE_SPECS
        # register_lobe! takes (lobe_id, parent_lobe_cap)
        rec = GB.Lobe.LOBE_REGISTRY[lid]
        GB.AIMLNodeSystem.register_lobe!(lid, rec.node_cap)
    end
    # Add a couple AIML nodes per lobe
    for (lid, subj) in LOBE_SPECS
        try
            GB.AIMLNodeSystem.add_aiml_node!(lid,
                "Considering $subj, the situation suggests a measured response.";
                strength = 1.5)
            GB.AIMLNodeSystem.add_aiml_node!(lid,
                "Within the $subj domain, multiple angles converge here.";
                strength = 1.2)
        catch e
            println("    ⚠️  aiml_node $lid: $e")
        end
    end
    println("  ✅ AIML tribes registered for $(length(LOBE_SPECS)) lobes")
catch e
    println("  ⚠️  aiml_tribe: $e")
end

# =============================================================================
# Phase 11: prime message history + arousal
# =============================================================================
println("\n[Phase 11] Priming message history + arousal...")
try
    GB.add_message_to_history!("User",         "this is a comprehensive cave demo", false)
    GB.add_message_to_history!("Engine_Voice", "ready for inspection",              false)
    GB.add_message_to_history!("User_Pinned",  "all levers should be lit up",       true)  # pinned
    println("  💬 3 messages seeded (1 pinned)")
catch e
    println("  ⚠️  message_history: $e")
end

# nudge eye arousal up so trajectory has signal
try
    GB.EyeSystem.set_arousal!(0.55)
    println("  👁  arousal pre-set to $(GB.EyeSystem.get_arousal())")
catch e
    println("  ⚠️  arousal setter failed: $e")
end

# =============================================================================
# Phase 12: prime tonal build-up by faking a few same-tone calls
# =============================================================================
println("\n[Phase 12] Priming tonal build-up...")
try
    # Run predict_action_tone on the same input a few times so the buildup
    # accumulator gets non-zero state.
    for _ in 1:3
        try
            GB.ActionTonePredictor.predict_action_tone("calm reflective greeting")
        catch
        end
    end
    snap = GB.ActionTonePredictor.get_tonal_buildup()
    println("  🌡  tonal build-up snapshot: tone=$(snap.tone) buildup=$(round(snap.buildup, digits=3))")
catch e
    println("  ⚠️  tonal_buildup prime: $e")
end

# =============================================================================
# Phase 13: SAVE the comprehensive specimen
# =============================================================================
println("\n[Phase 13] Saving specimen to disk...")
println("="^78)
try
    summary = GB.save_specimen_to_file!(OUT_PATH)
    println(summary)
    if isfile(OUT_PATH)
        sz = filesize(OUT_PATH)
        println("\n✅ Saved $OUT_PATH ($(round(sz/1024, digits=1)) KB)")
    end
catch e
    println("!!! save FAILED: $e")
    Base.show_backtrace(stdout, catch_backtrace())
    exit(1)
end

println("="^78)
println("GRUG SPEC BUILD COMPLETE")
println("="^78)
