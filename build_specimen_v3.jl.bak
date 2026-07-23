#!/usr/bin/env julia
# ============================================================================
# GrugBot420 COMPREHENSIVE SPECIMEN BUILD v3.0
# ============================================================================
# Fixes decoherence by using NATURAL-LANGUAGE phrase patterns (resembling real
# user input) instead of multi-keyword bag patterns. Multi-keyword bags trigger
# BUG-004 (pattern longer than input) which crushes confidence to ~0.09 and
# forces every mission into the generic fallback response.
#
# This build is MUCH more comprehensive: 12 lobes, 120+ nodes across dozens of
# subjects, and EVERY engine feature wired into the save file.
# ============================================================================

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

using Pkg
Pkg.activate(".")

include(joinpath(@__DIR__, "src", "Main.jl"))
using JSON

println("="^70)
println("GRUG COMPREHENSIVE SPECIMEN BUILD v3.0  (decoherence-fixed)")
println("="^70)

all_node_ids = String[]

# ============================================================
# PHASE 1: Register lobes (12 custom + default)
# ============================================================
println("\n🧠 Phase 1: Registering lobes...")

# create_lobe!(id, subject; subject_whitelist=Set) and add_lobe_whitelist!(id, entries...)
function ensure_lobe(lobe_id::String, subject::String, whitelist::Vector{String})
    try
        Lobe.create_lobe!(lobe_id, subject; subject_whitelist=Set{String}(whitelist))
    catch e
        @warn "create_lobe! failed for $lobe_id (may already exist): $e"
        # If it exists, just top up the whitelist
        try
            Lobe.add_lobe_whitelist!(lobe_id, whitelist...)
        catch
        end
    end
end

lobe_defs = [
    ("lobe_math",      "mathematics and numbers",
        ["math","number","calculate","add","subtract","multiply","divide","equation","geometry","algebra","fraction","sum","count","arithmetic"]),
    ("lobe_science",   "natural science and physics",
        ["science","physics","gravity","energy","atom","force","motion","chemistry","molecule","electric","light","sound","heat"]),
    ("lobe_biology",   "life and living things",
        ["biology","cell","dna","evolution","organism","plant","animal","life","body","brain","blood","gene","species"]),
    ("lobe_phil",      "philosophy and meaning",
        ["philosophy","meaning","truth","consciousness","existence","reality","mind","knowledge","free","will","ethics","good","virtue"]),
    ("lobe_surv",      "survival and danger",
        ["survival","danger","threat","safe","protect","flee","fight","hide","fire","predator","shelter","escape","warn"]),
    ("lobe_emp",       "emotions and empathy",
        ["emotion","feeling","sad","happy","angry","fear","love","grief","joy","comfort","care","compassion","empathy"]),
    ("lobe_crea",      "creativity and art",
        ["creativity","art","imagine","create","poem","music","paint","story","design","dream","invent","craft","beauty"]),
    ("lobe_social",    "social bonds and people",
        ["social","friend","trust","help","cooperate","greet","hello","community","people","talk","share","together","kind"]),
    ("lobe_temporal",  "time and change",
        ["time","past","future","present","change","history","memory","clock","season","age","before","after","moment"]),
    ("lobe_nature",    "nature and the world",
        ["nature","forest","ocean","mountain","river","weather","tree","sky","earth","wind","rain","sun","animal"]),
    ("lobe_tech",      "technology and machines",
        ["technology","computer","machine","robot","code","internet","tool","engine","data","software","build","wire","signal"]),
    ("lobe_food",      "food and cooking",
        ["food","eat","cook","hungry","meat","fruit","fire","taste","recipe","meal","water","drink","sweet"]),
]

for (lid, subj, wl) in lobe_defs
    ensure_lobe(lid, subj, wl)
end
println("  ✅ $(length(lobe_defs)) custom lobes registered + default")

# ============================================================
# PHASE 2: Connect lobes (bidirectional adjacency)
# ============================================================
println("\n🔗 Phase 2: Connecting lobes...")

function connect(a::String, b::String)
    try
        Lobe.connect_lobes!(a, b)
    catch e
        @warn "connect_lobes! $a<->$b failed: $e"
    end
end

connect("lobe_math", "lobe_science")
connect("lobe_math", "lobe_temporal")
connect("lobe_science", "lobe_biology")
connect("lobe_science", "lobe_nature")
connect("lobe_science", "lobe_tech")
connect("lobe_biology", "lobe_nature")
connect("lobe_biology", "lobe_emp")
connect("lobe_phil", "lobe_math")
connect("lobe_phil", "lobe_emp")
connect("lobe_phil", "lobe_temporal")
connect("lobe_surv", "lobe_nature")
connect("lobe_surv", "lobe_emp")
connect("lobe_surv", "lobe_food")
connect("lobe_emp", "lobe_social")
connect("lobe_crea", "lobe_nature")
connect("lobe_crea", "lobe_emp")
connect("lobe_crea", "lobe_tech")
connect("lobe_social", "lobe_food")
connect("lobe_temporal", "lobe_nature")
connect("lobe_tech", "lobe_math")
connect("lobe_food", "lobe_nature")
println("  ✅ Lobe adjacency graph connected")

# ============================================================
# PHASE 3: Grow nodes — NATURAL-LANGUAGE PATTERNS
# ============================================================
println("\n🌱 Phase 3: Growing nodes (natural-language patterns)...")

# Deterministic 8-dim signal from a pattern's content words. The engine's
# matcher needs a consistent-dimension signal; the auto-deriver produced
# short, near-identical vectors for terse patterns ("what is zero") which got
# out-competed and pruned to empty-cave. We build an 8-float vector by hashing
# content tokens (stopwords removed) into 8 buckets, mirroring the v10 spec.
const _STOP = Set(["what","is","are","the","a","an","do","i","how","why","me",
                   "you","to","of","for","in","on","my","we","does","can",
                   "if","over","like","with","and","there","should"])
function pattern_signal(pat::String)
    toks = [t for t in split(lowercase(pat), r"[^a-z0-9]+") if !isempty(t) && !(t in _STOP)]
    isempty(toks) && (toks = split(lowercase(pat)))
    v = zeros(Float64, 8)
    for tok in toks
        h = hash(tok)
        for d in 1:8
            # mix the hash per-dimension deterministically
            hd = hash((h, d))
            v[d] += (hd % 1000) / 1000.0
        end
    end
    # normalize each dim into (0,1)
    for d in 1:8
        v[d] = v[d] - floor(v[d])
        v[d] = clamp(0.05 + 0.9 * v[d], 0.0, 1.0)
    end
    return round.(v; digits=4)
end

# Helper: grow a batch of natural-language nodes into a lobe.
# Each entry: (pattern, action_packet, system_prompt, noun_anchors, strength, extra::Dict)
# `extra` may carry: voice_register, frame_hints, voice_variants, is_image_node,
# is_antimatch_node, is_grave, grave_reason, drop_table, relational_patterns,
# required_relations, relation_weights, response_times, is_unlinkable, max_neighbors, signal.
# Registry of special node-struct fields to apply post-grow (pattern => fields).
const _SPECIAL_FIELDS = Dict{String,Dict{String,Any}}()

function grow_lobe(lobe_id::String, entries::Vector)
    nodes = Any[]
    for e in entries
        pat, act, prompt, anchors, strength, extra = e
        data = Dict{String,Any}(
            "system_prompt"  => prompt,
            "noun_anchors"   => anchors,
            "voice_register" => get(extra, "voice_register", "plain"),
            "frame_hints"    => get(extra, "frame_hints", ["plain"]),
            "initial_strength" => strength,
        )
        if haskey(extra, "voice_variants"); data["voice_variants"] = extra["voice_variants"]; end
        # TIME COHERENCE: grow_nodes_from_packet copies the whole `data` dict into
        # the node's json_data, so time_node / time_orientation / wants_context ride
        # through grow directly. wants_context=true makes the node opt into Fresh
        # Memory (requesting_nodes gate, Main.jl:1871) so "what now" probes recent context.
        for k in ("time_node","time_orientation","wants_context","time_sigil")
            if haskey(extra, k); data[k] = extra[k]; end
        end
        node = Dict{String,Any}(
            "pattern"       => pat,
            "action_packet" => act,
            "data"          => data,
            # Always provide an explicit, consistent 8-dim signal (decoherence fix).
            "signal"        => haskey(extra, "signal") ? extra["signal"] : pattern_signal(pat),
        )
        # Top-level node-struct fields grow DOES read.
        for k in ("is_image_node","is_antimatch_node","drop_table")
            if haskey(extra, k); node[k] = extra[k]; end
        end
        push!(nodes, node)
    end
    packet = JSON.json(Dict("nodes" => nodes))
    ids = grow_nodes_from_packet(packet; target_lobe=lobe_id)
    append!(all_node_ids, ids)
    # Record special node-struct fields keyed by pattern so we can apply them
    # to the live Node objects after grow (grow_nodes_from_packet does NOT read
    # is_unlinkable / is_grave / response_times / max_neighbors / required_relations
    # from the packet — this is a wiring gap we close in the post-grow pass).
    for e in entries
        pat, _, _, _, _, extra = e
        special = Dict{String,Any}()
        for k in ("is_grave","grave_reason","response_times","is_unlinkable",
                  "max_neighbors","required_relations","relational_patterns",
                  "relation_weights")
            if haskey(extra, k); special[k] = extra[k]; end
        end
        if !isempty(special); _SPECIAL_FIELDS[pat] = special; end
    end
    println("  ✅ $lobe_id: $(length(ids)) nodes")
    return ids
end

# Include the big node dataset (kept in a separate file for readability)
include(joinpath(@__DIR__, "specimen_v3_nodes.jl"))


# ============================================================
# PHASE 4: Stochastic orchestration rules (side word templates)
# ============================================================
println("\n📜 Phase 4: Adding stochastic orchestration rules (side word templates)...")
rules_added = 0
rule_texts = [
    "When the mission is {MISSION}, consider the {PRIMARY_ACTION} approach with confidence {CONFIDENCE}",
    "The node {NODE_ID} suggests {SURE_ACTIONS} as reliable actions with {VOTE_CERTAINTY} certainty",
    "In the context of {LOBE_CONTEXT}, {ALL_ACTIONS} are available but {PRIMARY_ACTION} is strongest",
    "Recall from memory: {MEMORY}. The current mission {MISSION} aligns with {SURE_ACTIONS}",
    "When {TIED_ALTERNATIVES} compete, the lobe context {LOBE_CONTEXT} breaks the tie toward {PRIMARY_ACTION}",
    "Action {PRIMARY_ACTION} fired with confidence {CONFIDENCE} in lobe {LOBE_CONTEXT}",
    "The grug brain considers {ALL_ACTIONS} and selects {PRIMARY_ACTION} for mission {MISSION}",
    "Memory {MEMORY} supports {SURE_ACTIONS} with vote certainty {VOTE_CERTAINTY} for node {NODE_ID}",
]
for (i, rt) in enumerate(rule_texts)
    try
        add_orchestration_rule!(rt)
        global rules_added; rules_added += 1
    catch e
        println("  ⚠️  Rule $i failed: $e")
    end
end
println("  ✅ $rules_added stochastic rules added")

# ============================================================
# PHASE 5: Bridge nodes across lobes (node attach with seam tokens)
# ============================================================
println("\n🌈 Phase 5: Bridging nodes across lobes...")
function find_node_by_pattern(substr::String; lobe_hint::String="")
    found = Ref{String}("")
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if occursin(lowercase(substr), lowercase(node.pattern))
                if lobe_hint == "" || get(Lobe.NODE_TO_LOBE_IDX, id, "") == lobe_hint
                    found[] = id
                    return
                end
            end
        end
    end
    return isempty(found[]) ? nothing : found[]
end

bridges_created = 0
bridge_specs = [
    ("what is addition",             "lobe_math",     "do we have free will",      "lobe_phil",     ["reason","logic"]),
    ("should i fight or flee",      "lobe_surv",     "i feel scared and afraid",  "lobe_emp",      ["distress","emotion"]),
    ("what is good and evil",       "lobe_phil",     "tell me a story",           "lobe_crea",     ["meaning","expression"]),
    ("i am feeling very sad",       "lobe_emp",      "why do rivers flow",        "lobe_nature",   ["feeling","physical"]),
    ("how do i make friends",       "lobe_social",   "how do i comfort someone",  "lobe_emp",      ["care","connect"]),
    ("what does the future hold",   "lobe_temporal", "what is geometry",          "lobe_math",     ["sequence","order"]),
    ("how do i make music",         "lobe_crea",     "describe the ocean",        "lobe_nature",   ["wonder","imagine"]),
    ("what is gravity",             "lobe_science",  "how do computers work",     "lobe_tech",     ["force","system"]),
    ("what is the brain",           "lobe_biology",  "i am feeling very sad",     "lobe_emp",      ["body","feeling"]),
    ("what should i eat",           "lobe_food",     "how do i find clean water", "lobe_food",     ["nourish","survive"]),
    ("what is an atom",             "lobe_science",  "what is a cell",            "lobe_biology",  ["matter","structure"]),
    ("how do computers work",       "lobe_tech",     "how do i solve an equation","lobe_math",     ["logic","compute"]),
    ("you are my friend",           "lobe_social",   "how do things change over time","lobe_temporal",["bond","memory"]),
]
for (pat_a, lobe_a, pat_b, lobe_b, tokens) in bridge_specs
    id_a = find_node_by_pattern(pat_a; lobe_hint=lobe_a)
    id_b = find_node_by_pattern(pat_b; lobe_hint=lobe_b)
    if !isnothing(id_a) && !isnothing(id_b) && id_a != id_b
        try
            bridge_nodes!(id_a, id_b; seam_tokens=tokens)
            global bridges_created; bridges_created += 1
        catch e
            println("  ⚠️  Bridge ($pat_a ↔ $pat_b) failed: $e")
        end
    else
        println("  ⚠️  Bridge skipped: nodes ($id_a, $id_b) for ($pat_a ↔ $pat_b)")
    end
end
println("  ✅ $bridges_created cross-lobe bridges created")

# ============================================================
# PHASE 6: Thesaurus seeds (side word synonyms)
# ============================================================
println("\n🌿 Phase 6: Adding thesaurus seeds (side word synonyms)...")
syns_added = 0
thesaurus_entries = [
    ("think", ["consider","ponder","reflect","muse"]),
    ("know", ["understand","comprehend","grasp","realize"]),
    ("say", ["state","declare","express","articulate"]),
    ("big", ["large","great","vast","immense"]),
    ("small", ["tiny","little","minute","diminutive"]),
    ("fast", ["quick","rapid","swift","speedy"]),
    ("slow", ["gradual","unhurried","measured","leisurely"]),
    ("good", ["excellent","fine","worthy","virtuous"]),
    ("bad", ["poor","inferior","dreadful","awful"]),
    ("happy", ["joyful","cheerful","elated","content"]),
    ("sad", ["sorrowful","melancholy","grieving","downcast"]),
    ("danger", ["peril","hazard","threat","menace"]),
    ("beautiful", ["lovely","gorgeous","exquisite","stunning"]),
    ("strong", ["powerful","mighty","robust","resilient"]),
    ("wise", ["sagacious","astute","prudent","insightful"]),
    ("water", ["stream","river","drink","liquid"]),
    ("food", ["meal","nourishment","sustenance","meat"]),
    ("star", ["sun","light","celestial","glow"]),
    ("grow", ["sprout","flourish","develop","thrive"]),
    ("time", ["moment","season","epoch","duration"]),
]
for (canonical, synonyms) in thesaurus_entries
    try
        Thesaurus.add_seed_synonym!(canonical, synonyms)
        global syns_added; syns_added += 1
    catch e
        println("  ⚠️  Thesaurus seed '$canonical' failed: $e")
    end
end
println("  ✅ $syns_added synonym groups added")

# ============================================================
# PHASE 7: Semantic verbs, verb synonyms, relation classes
# ============================================================
println("\n🔥 Phase 7: Adding semantic verbs and relation classes...")
for cls in ["cognitive","causal","spatial","temporal","social","emotional","creative",
            "includes","measures","contrasts_with","responds_to"]
    try
        SemanticVerbs.add_relation_class!(cls)
    catch e
        println("  ⚠️  Relation class '$cls' failed: $e")
    end
end
verbs_added = 0
verb_specs = [
    ("compute","cognitive"), ("wonder","cognitive"), ("caution","causal"),
    ("navigate","spatial"), ("recall","temporal"), ("anticipate","temporal"),
    ("empathize","social"), ("celebrate","emotional"), ("compose","creative"),
    ("illustrate","creative"), ("nourish","social"), ("photosynthesize","causal"),
    # DYNAMIC RELATIONAL TRIPLES: register the verbs that the engine's relation
    # sigils expand to, so user-side extract_relational_triples() actually
    # recognizes them. Without this, "fire produces heat" extracts no triple
    # (produces is unknown) and the dynamic node never gets its relational bonus.
    # &causal expansion:
    ("produces","causal"), ("creates","causal"), ("generates","causal"),
    ("triggers","causal"), ("enables","causal"), ("brings_about","causal"),
    ("leads_to","causal"), ("results_in","causal"),
    # &causal expansion (user-facing): common verbs users ACTUALLY type in
    # queries like "how do i make fire", "how do i find shelter", etc.
    # Without these, extract_relational_triples() returns 0 triples for
    # natural user queries, making relational anchoring useless for
    # cross-lobe disambiguation (BUG-005: lobe decoherence).
    ("make","causal"), ("find","causal"),
    ("get","causal"), ("give","causal"),
    # &temporal expansion:
    ("precedes","temporal"), ("follows","temporal"), ("during","temporal"),
    ("since","temporal"),
    # &possessive expansion:
    ("controls","includes"), ("owns","includes"), ("contains","includes"),
    ("holds","includes"), ("carries","includes"),
    # &similarity expansion:
    ("resembles","contrasts_with"), ("mirrors","contrasts_with"),
    ("balances","contrasts_with"),
]
for (verb, cls) in verb_specs
    try
        SemanticVerbs.add_verb!(verb, cls)
        global verbs_added; verbs_added += 1
    catch e
        println("  ⚠️  Verb '$verb' failed: $e")
    end
end
syns_verbs_added = 0
verb_syn_specs = [
    ("compute","calc"), ("compute","figure"), ("wonder","speculate"), ("wonder","question"),
    ("caution","warn"), ("navigate","chart"), ("recall","remember"), ("anticipate","foresee"),
    ("empathize","care"), ("celebrate","rejoice"), ("compose","craft"), ("illustrate","draw"),
]
for (canonical, synonym) in verb_syn_specs
    try
        SemanticVerbs.add_synonym!(canonical, synonym)
        global syns_verbs_added; syns_verbs_added += 1
    catch e
        println("  ⚠️  Synonym '$synonym→$canonical' failed: $e")
    end
end
println("  ✅ $verbs_added verbs, $syns_verbs_added verb synonyms, 11 relation classes added")

# ============================================================
# PHASE 8: Inhibitions (negative thesaurus)
# ============================================================
println("\n🚫 Phase 8: Adding inhibitions (negative thesaurus)...")
inhib_added = 0
inhib_specs = [
    ("stupid", "Grug does not use hurtful intelligence slurs"),
    ("dumb", "Grug does not use hurtful intelligence slurs"),
    ("idiot", "Grug does not use hurtful intelligence slurs"),
    ("hate", "Grug prefers constructive language"),
    ("ugly", "Grug sees beauty in all things"),
]
for (word, reason) in inhib_specs
    try
        InputQueue.add_inhibition!(word; reason=reason)
        global inhib_added; inhib_added += 1
    catch e
        println("  ⚠️  Inhibition '$word' failed: $e")
    end
end
println("  ✅ $inhib_added inhibitions added")

# ============================================================
# PHASE 9: Arousal baseline + eye state
# ============================================================
println("\n👁 Phase 9: Setting arousal and eye state...")
EyeSystem.set_arousal!(0.4)
lock(EyeSystem.AROUSAL_LOCK) do
    EyeSystem.AROUSAL_STATE.baseline = 0.4
end
println("  ✅ Arousal level and baseline set to 0.4 (moderate)")

# ============================================================
# PHASE 10: Automaton escalation rules
# ============================================================
println("\n🤖 Phase 10: Adding automaton escalation rules...")
auto_added = 0
try
    steps_alert = [
        EphemeralAutomaton.AutomatonStep("boost_threat", :bump_strength, 0.5),
        EphemeralAutomaton.AutomatonStep("nudge_arousal", :set_arousal, 0.8),
    ]
    rule_alert = EphemeralAutomaton.AutomatonRule("auto_alert_escalation", :alert, steps_alert;
        jitter_targets=Set(["boost_threat"]), min_confidence=0.6)
    EphemeralAutomaton.register_automaton_rule!(rule_alert)
    global auto_added; auto_added += 1
catch e; println("  ⚠️  Automaton alert rule failed: $e"); end
try
    steps_empathy = [
        EphemeralAutomaton.AutomatonStep("deepen_care", :bump_strength, 0.3),
        EphemeralAutomaton.AutomatonStep("soften_tone", :set_arousal, 0.3),
    ]
    rule_empathy = EphemeralAutomaton.AutomatonRule("auto_empathy_escalation", :comfort, steps_empathy;
        jitter_targets=Set(["deepen_care"]), min_confidence=0.5)
    EphemeralAutomaton.register_automaton_rule!(rule_empathy)
    global auto_added; auto_added += 1
catch e; println("  ⚠️  Automaton empathy rule failed: $e"); end
try
    steps_creative = [
        EphemeralAutomaton.AutomatonStep("inspire", :bump_strength, 0.2),
        EphemeralAutomaton.AutomatonStep("widen_scope", :literal, "brainstorm"),
    ]
    rule_creative = EphemeralAutomaton.AutomatonRule("auto_creative_escalation", :elaborate, steps_creative;
        jitter_targets=Set(["inspire"]), min_confidence=0.4)
    EphemeralAutomaton.register_automaton_rule!(rule_creative)
    global auto_added; auto_added += 1
catch e; println("  ⚠️  Automaton creative rule failed: $e"); end
println("  ✅ $auto_added automaton escalation rules registered")

# ============================================================
# PHASE 11: Decomposer config
# ============================================================
println("\n✂️ Phase 11: Setting decomposer config...")
decomp_added = 0
for conj in ["although","whereas","nevertheless"]
    try
        InputDecomposer.add_split_conjunction!(conj)
        global decomp_added; decomp_added += 1
    catch e; println("  ⚠️  Decomposer conjunction '$conj' failed: $e"); end
end
try
    InputDecomposer.add_compound_pair!("not", "only")
    global decomp_added; decomp_added += 1
catch e; println("  ⚠️  Decomposer compound failed: $e"); end
println("  ✅ Decomposer config set ($decomp_added additions)")

# ============================================================
# PHASE 12: TonalJudge knobs
# ============================================================
println("\n⚖️ Phase 12: Setting TonalJudge knobs...")
try
    TonalJudge.set_frame_match_weights!(; lift=1.3, inhibit=0.7)
    println("  ✅ TonalJudge frame match weights: lift=1.3, inhibit=0.7")
catch e; println("  ⚠️  TonalJudge issue: $e"); end

# ============================================================
# PHASE 13: Flashcards across multiple lobes
# ============================================================
println("\n🃏 Phase 13: Adding flashcards across lobes...")
flashcards_added = 0
math_flash = [
    ("2+2","4",4.0), ("3+5","8",8.0), ("7+3","10",10.0), ("10-4","6",6.0),
    ("9-3","6",6.0), ("6*7","42",42.0), ("8*8","64",64.0), ("12/4","3",3.0), ("100/10","10",10.0),
]
for (expr, result, rn) in math_flash
    try
        LobeTable.flashcard_put!("lobe_math", expr, result; result_num=rn, card_type=:arithmetic)
        global flashcards_added; flashcards_added += 1
    catch e; println("  ⚠️  Flashcard '$expr' failed: $e"); end
end
phil_flash = [
    ("what is consciousness","Consciousness is the quality or state of awareness of oneself and the world."),
    ("what is truth","Truth is the property of being in accord with fact or reality."),
    ("what is free will","Free will is the ability to choose between possible courses of action unimpeded."),
]
surv_flash = [
    ("how to survive danger","Assess the threat, find shelter, secure resources, and stay alert."),
    ("fight or flight response","An instinctive physiological response to a perceived threat."),
]
emp_flash = [
    ("what is compassion","Compassion is the feeling that arises when confronted with another's suffering."),
    ("how to comfort someone","Listen without judgment, acknowledge feelings, offer presence and support."),
]
nature_flash = [
    ("what is a forest","A large area dominated by trees providing habitat for countless species."),
    ("what causes weather","Weather is driven by temperature, pressure, humidity, and wind patterns."),
]
crea_flash = [("what is imagination","The faculty of forming new ideas, images, or concepts not present to the senses.")]
sci_flash = [
    ("what is gravity","Gravity is the force that pulls objects toward each other."),
    ("speed of light","Light travels about 300,000 kilometers per second."),
]
bio_flash = [("what is dna","DNA is the molecule that carries genetic instructions for life.")]
tech_flash = [("what is a computer","A machine that stores and processes information using logic.")]
food_flash = [("what is protein","A nutrient that builds and repairs the body, found in meat and beans.")]
for (lid, cards) in [("lobe_phil",phil_flash),("lobe_surv",surv_flash),("lobe_emp",emp_flash),
                     ("lobe_nature",nature_flash),("lobe_crea",crea_flash),("lobe_science",sci_flash),
                     ("lobe_biology",bio_flash),("lobe_tech",tech_flash),("lobe_food",food_flash)]
    for tup in cards
        try
            LobeTable.flashcard_put!(lid, tup[1], tup[2])
            global flashcards_added; flashcards_added += 1
        catch e; println("  ⚠️  Flashcard '$(tup[1])' in $lid failed: $e"); end
    end
end
println("  ✅ $flashcards_added flashcards added across 10 lobes")

# ============================================================
# PHASE 14: Message history
# ============================================================
println("\n💬 Phase 14: Adding initial message history...")
add_message_to_history!("System", "Comprehensive specimen v3.0 initialized: 12 lobes, 80+ nodes, bridges, sigils, thesaurus, all features", true)
add_message_to_history!("Engine_Voice", "Grug ready. Many lobes, many rocks, many bridges. Grug think good and clear.", false)
add_message_to_history!("User", "Hello Grug, what can you think about?", false)
add_message_to_history!("Engine_Voice", "Grug think about math, science, life, mind, danger, feeling, art, friends, time, nature, tool, food. Grug brain big!", false)
println("  ✅ Initial messages added")

# ============================================================
# PHASE 15: Custom sigils (all classes)
# ============================================================
println("\n🔮 Phase 15: Adding custom sigils...")
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE; name="mood", class=:lambda, applies_at=:bind,
    sigil_type=:string, provenance="specimen-build-v3", promote_at_tokenize=false)
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE; name="mathop", class=:macro, applies_at=:bind,
    lexicon=["add","subtract","multiply","divide","calculate"], provenance="specimen-build-v3", promote_at_tokenize=false)
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE; name="emotion", class=:macro, applies_at=:bind,
    lexicon=["happy","sad","angry","calm","excited","afraid"], provenance="specimen-build-v3", promote_at_tokenize=false)
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE; name="element", class=:macro, applies_at=:bind,
    lexicon=["water","fire","earth","air","light"], provenance="specimen-build-v3", promote_at_tokenize=false)
SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE; name="philosophical", class=:tag, applies_at=:match,
    provenance="specimen-build-v3")
SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE; name="produces",
    expansion=["produces","generates","creates","yields"], provenance="specimen-build-v3")
SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE; name="opposes",
    expansion=["opposes","contradicts","negates","blocks"], provenance="specimen-build-v3")
SigilRegistry.register_procedure_sigil!(_ENGINE_SIGIL_TABLE; name="math-chain",
    expansion=["&mathop","&n","then","verify"], provenance="specimen-build-v3")

# BUG-005 FIX: Extend &causal sigil expansion with user-facing verbs.
# The engine default &causal only has formal verbs (produces, creates, etc.).
# Users type "how do i MAKE fire" not "how does fire PRODUCE warmth".
# Without "make" in the expansion, extract_relational_triples() extracts the
# triple (i, make, fire) but evaluate_relational_dialectics can't match it to
# (fire, &causal, warmth) because "make" isn't in the &causal alternatives.
# Adding user-facing verbs here + the cross-field partial match in engine.jl
# (v7.57) gives relational anchoring the power to disambiguate cross-lobe
# confusion (e.g. "how do i make fire" → lobe_surv not lobe_crea).
SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE; name="causal",
    expansion=["causes","produces","creates","generates","leads_to",
               "results_in","triggers","enables","brings_about",
               "make","makes","find","finds","get","gets","give","gives"],
    provenance="specimen-build-v3-BUG005", overwrite=true)

println("  ✅ 8 custom sigils registered (1 lambda, 3 macro, 1 tag, 1 procedure, 2 relation) + &causal extended")

# ============================================================
# PHASE 16: EphemeralMLP transformer rules
# ============================================================
println("\n🧬 Phase 16: Adding EphemeralMLP rules...")
EphemeralMLP.init_ephemeral_mlp!()
EphemeralMLP.add_mlp_rule!(EphemeralMLP.MLPTransformerRule("math_boost", "math|calculate|number|equation";
    key="math_pattern", weight_value=1.3, weight_jitter=true, transform_type=EphemeralMLP.MLP_TRANSFORM_FUZZY,
    payload=Dict{String,Any}("lobe_hint"=>"lobe_math","boost_factor"=>0.15), drop_table=String[]))
EphemeralMLP.add_mlp_rule!(EphemeralMLP.MLPTransformerRule("empathy_boost", "feel|sad|happy|care|compassion";
    key="empathy_pattern", weight_value=1.2, weight_jitter=true, transform_type=EphemeralMLP.MLP_TRANSFORM_FUZZY,
    payload=Dict{String,Any}("lobe_hint"=>"lobe_emp","boost_factor"=>0.12), drop_table=String["math_boost"]))
EphemeralMLP.add_mlp_rule!(EphemeralMLP.MLPTransformerRule("survival_priority", "danger|threat|flee|fight|protect";
    key="survival_pattern", weight_value=1.5, weight_jitter=false, transform_type=EphemeralMLP.MLP_TRANSFORM_SOLID,
    payload=Dict{String,Any}("lobe_hint"=>"lobe_surv","boost_factor"=>0.25), drop_table=String[]))
EphemeralMLP.add_mlp_rule!(EphemeralMLP.MLPTransformerRule("science_boost", "science|gravity|energy|atom|physics";
    key="science_pattern", weight_value=1.25, weight_jitter=true, transform_type=EphemeralMLP.MLP_TRANSFORM_FUZZY,
    payload=Dict{String,Any}("lobe_hint"=>"lobe_science","boost_factor"=>0.13), drop_table=String[]))
println("  ✅ 4 MLP transformer rules added")

# ============================================================
# PHASE 17: CoherenceField config
# ============================================================
println("\n🌀 Phase 17: Setting CoherenceField config...")
CoherenceField.set_coherence_config!(:weight, 0.45)
CoherenceField.set_coherence_config!(:depth, 3)
CoherenceField.set_coherence_config!(:decay, 0.008)
CoherenceField.set_coherence_config!(:recency_window, 180.0)
CoherenceField.set_coherence_config!(:cache_ttl, 3.0)
println("  ✅ CoherenceField config set (weight=0.45, depth=3, decay=0.008, recency=180s)")

# ============================================================
# PHASE 18: RelationalGovernance co-activation
# ============================================================
println("\n🔗 Phase 18: Seeding RelationalGovernance co-activation...")
co_pairs = [
    ("what is addition","lobe_math","do we have free will","lobe_phil"),
    ("should i fight or flee","lobe_surv","i feel scared and afraid","lobe_emp"),
    ("tell me a story","lobe_crea","describe the ocean","lobe_nature"),
    ("what is gravity","lobe_science","how do computers work","lobe_tech"),
]
cofire = 0
for (pa, la, pb, lb) in co_pairs
    ia = find_node_by_pattern(pa; lobe_hint=la)
    ib = find_node_by_pattern(pb; lobe_hint=lb)
    if !isnothing(ia) && !isnothing(ib)
        try
            RelationalGovernance.observe_co_firing!([ia, ib])
            global cofire; cofire += 1
        catch e; println("  ⚠️  co-firing failed: $e"); end
    end
end
println("  ✅ $cofire co-activation pairs observed")

# ============================================================
# PHASE 19: HippocampalModulator pending ask
# ============================================================
println("\n🦛 Phase 19: Seeding HippocampalModulator pending ask...")
lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
    _HIPPOCAMPAL_PENDING_ASK[] = "What is the relationship between mathematics and philosophy?"
end
println("  ✅ Hippocampal pending ask seeded")

# ============================================================
# PHASE 20: TimeOrientation + time nodes
# ============================================================
println("\n⏳ Phase 20: Setting time orientation + verifying temporal nodes...")
lock(_GLOBAL_PROMOTION_LOCK) do
    _GLOBAL_TIME_ORIENTATION[] = ("present", Dict{String,Any}("source"=>"specimen-build-v3","confidence"=>0.8))
end
# TIME COHERENCE: temporal nodes already carry correct per-node time_orientation
# (past / present / future) and wants_context through grow (see specimen_v3_nodes.jl).
# Do NOT blanket-override to "past" — that was the bug. Just verify and tally here.
_tn_count = 0; _wc_count = 0
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if get(node.json_data, "time_node", false) === true
            global _tn_count; _tn_count += 1
            # ensure a time_sigil tag is present for serialization
            haskey(node.json_data, "time_sigil") || (node.json_data["time_sigil"] = "temporal_anchor")
            if get(node.json_data, "wants_context", false) === true
                global _wc_count; _wc_count += 1
            end
        end
    end
end
println("  ✅ Global orientation 'present'; $_tn_count time-nodes ($_wc_count opt into Fresh Memory via wants_context)")

# ============================================================
# PHASE 21: RelationalJitter
# ============================================================
println("\n🎲 Phase 21: Setting RelationalJitter config...")
RelationalJitter.enable_jitter!()
RelationalJitter.set_jitter_ratio!(0.08)
RelationalJitter.set_jitter_coin_ratio!(0.05)
println("  ✅ RelationalJitter enabled (ratio=0.08, coin=0.05)")

# ============================================================
# PHASE 22: AutoGrowth + AutoLinker evidence
# ============================================================
println("\n🌱 Phase 22: Seeding AutoGrowth + AutoLinker evidence...")
AutoGrowth.load_evidence_snapshot!([
    Dict("pattern"=>"quantum","growth_type"=>"match","lobe_hint"=>"lobe_science","accumulated_intensity"=>0.7,"frequency"=>3,"sources"=>["silence_map"]),
    Dict("pattern"=>"ethics","growth_type"=>"match","lobe_hint"=>"lobe_phil","accumulated_intensity"=>0.6,"frequency"=>2,"sources"=>["silence_map"]),
    Dict("pattern"=>"grief","growth_type"=>"match","lobe_hint"=>"lobe_emp","accumulated_intensity"=>0.65,"frequency"=>4,"sources"=>["thesaurus_gap"]),
    Dict("pattern"=>"venom","growth_type"=>"match","lobe_hint"=>"lobe_surv","accumulated_intensity"=>0.8,"frequency"=>5,"sources"=>["silence_map"]),
    Dict("pattern"=>"sculpture","growth_type"=>"match","lobe_hint"=>"lobe_crea","accumulated_intensity"=>0.55,"frequency"=>2,"sources"=>["silence_map"]),
    Dict("pattern"=>"algorithm","growth_type"=>"match","lobe_hint"=>"lobe_tech","accumulated_intensity"=>0.6,"frequency"=>3,"sources"=>["silence_map"]),
    Dict("pattern"=>"enzyme","growth_type"=>"match","lobe_hint"=>"lobe_biology","accumulated_intensity"=>0.5,"frequency"=>2,"sources"=>["silence_map"]),
])
AutoGrowth.load_co_occur_snapshot!([
    Dict("a"=>"math","b"=>"calculate","count"=>5),
    Dict("a"=>"think","b"=>"philosophy","count"=>3),
    Dict("a"=>"feel","b"=>"empathy","count"=>4),
    Dict("a"=>"danger","b"=>"survival","count"=>6),
    Dict("a"=>"create","b"=>"imagine","count"=>3),
    Dict("a"=>"gravity","b"=>"force","count"=>4),
])
AutoLinker.load_link_evidence_snapshot!(Dict(
    "math_phil_link" => Dict("node_a"=>"math_concept","node_b"=>"phil_inquiry","accumulated_intensity"=>0.5,"frequency"=>3,"sources"=>["co_firing"],"is_cross_lobe"=>true,"lobe_a"=>"lobe_math","lobe_b"=>"lobe_phil"),
    "surv_emp_link" => Dict("node_a"=>"empathy_care","node_b"=>"survival_instinct","accumulated_intensity"=>0.4,"frequency"=>2,"sources"=>["co_firing"],"is_cross_lobe"=>true,"lobe_a"=>"lobe_emp","lobe_b"=>"lobe_surv"),
))
println("  ✅ 7 AutoGrowth evidence + 6 co-occur + 2 AutoLinker pairs seeded")

# ============================================================
# PHASE 23: AIML executive nodes per lobe
# ============================================================
println("\n🤖 Phase 23: Registering AIML executive nodes...")
for (lobe_id, lobe_rec) in Lobe.LOBE_REGISTRY
    cap = length(lobe_rec.node_ids)
    if cap > 0
        try
            AIMLNodeSystem.register_lobe!(lobe_id, cap)
            aiml_id = "aiml_$(lobe_id)_exec_1"
            template = "Executive scaffold for $(lobe_rec.subject)"
            AIMLNodeSystem.add_aiml_node!(lobe_id, aiml_id, template; initial_strength=5.0)
        catch e
            @warn "AIML register failed for $lobe_id" exception=e
        end
    end
end
n_aiml_lobes = length(AIMLNodeSystem.get_registered_lobes())
println("  ✅ AIML tribes registered for $n_aiml_lobes lobes with executive nodes")

# ============================================================
# PHASE 24: PhaseAccumulator crystal
# ============================================================
println("\n💎 Phase 24: Seeding PhaseAccumulator crystal...")
EphemeralAutomaton.set_phase_enabled!(true)
EphemeralAutomaton.set_phase_pull_threshold!(0.55)
EphemeralAutomaton.set_phase_surface_count!(4)
println("  ✅ PhaseAccumulator configured (enabled, threshold=0.55, surfaces=4)")

# ============================================================
# PHASE 25: Answer mode config (custom poetry mode)
# ============================================================
println("\n⚙️ Phase 25: Setting answer mode config...")
_ANSWER_MODE_CONFIG["poetry"] = Dict(
    "action" => "elaborate^1",
    "voice" => "warm",
    "frame" => ["exploratory","warm"],
    "prompt" => "Grug. I speak in beauty. I weave words into art. I create from what I have learned."
)
println("  ✅ Answer mode config: added 'poetry' mode")

# ============================================================
# PHASE 26: Special-field nodes (response_times, unlinkable, max_neighbors, SDF image)
# ============================================================
println("\n🔧 Phase 26: Adding special-field nodes...")
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict("pattern"=>"what do i do in an emergency", "action_packet"=>"alert",
        "json_data"=>Dict("category"=>"emergency","priority"=>"critical","response_type"=>"immediate",
            "system_prompt"=>"Grug speaks with urgency. Emergency means act now. Grug tell you fast and clear what to do. No long talk. Move, protect, survive.",
            "noun_anchors"=>["emergency","danger","safety","act"],
            "voice_register"=>"urgent", "frame_hints"=>["imperative","terse"]),
        "strength"=>8.5, "response_times"=>[0.12,0.15,0.11,0.13,0.14], "throttle"=>0.3)
])); target_lobe="lobe_surv")
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict("pattern"=>"what is the unknowable void", "action_packet"=>"ponder",
        "json_data"=>Dict("category"=>"metaphysics","unknowable"=>true,
            "system_prompt"=>"Grug ponders deep. Void is the great nothing Grug cannot know. Some things stay dark to Grug mind. Grug sit with the mystery and feel small under big sky.",
            "noun_anchors"=>["void","nothing","mystery","unknown"],
            "voice_register"=>"contemplative", "frame_hints"=>["contemplative","plain"]),
        "strength"=>4.0, "is_unlinkable"=>true, "max_neighbors"=>2)
])); target_lobe="lobe_phil")
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict("pattern"=>"can i join the gathering of friends", "action_packet"=>"welcome",
        "json_data"=>Dict("category"=>"social_event","group_size"=>"large",
            "system_prompt"=>"Grug welcomes warm. Yes, come join the fire. Many friends gather, share food, share story. Grug glad you here. Sit close, you belong with the tribe.",
            "noun_anchors"=>["gathering","friends","tribe","welcome"],
            "voice_register"=>"warm", "frame_hints"=>["warm","plain"]),
        "strength"=>6.0, "max_neighbors"=>12, "neighbor_ids"=>String[])
])); target_lobe="lobe_social")
grow_nodes_from_packet(JSON.json(Dict("nodes" => [
    Dict("pattern"=>"show me a picture of a sunset over water", "action_packet"=>"describe",
        "json_data"=>Dict("is_image"=>true,"sdf_id"=>"sunset_over_water",
            "sdf_params"=>Dict("complexity"=>0.7,"symmetry"=>0.4,"warmth"=>0.9),
            "image_description"=>"A warm sunset reflected across calm water, orange and purple hues at the horizon",
            "system_prompt"=>"Grug describes the picture. Grug see big orange sun fall into water. Sky turn purple and gold. Water hold the light like shiny stone. Grug think it beautiful and calm.",
            "noun_anchors"=>["sunset","water","sky","light"],
            "voice_register"=>"warm", "frame_hints"=>["warm","exploratory"]),
        "is_image_node"=>true, "strength"=>7.0)
])); target_lobe="lobe_nature")
println("  ✅ 4 special-field nodes added")

# ============================================================
# PHASE 27: Apply special node-struct fields (wiring-gap fix)
# ============================================================
# grow_nodes_from_packet does NOT read is_grave / grave_reason / response_times /
# is_unlinkable / max_neighbors / required_relations from the packet, so these
# node-type features were silently dropped and never persisted. Here we apply
# them directly to the live Node objects by matching on pattern.
println("\n🔩 Phase 27: Applying special node-struct fields (post-grow wiring)...")

# Phase-26 special nodes (grown via raw packet, not grow_lobe) also need fields applied.
_SPECIAL_FIELDS["what do i do in an emergency"] = Dict{String,Any}(
    "response_times" => [0.12,0.15,0.11,0.13,0.14], "max_neighbors" => 16)
_SPECIAL_FIELDS["what is the unknowable void"] = Dict{String,Any}(
    "is_unlinkable" => true, "max_neighbors" => 2)
_SPECIAL_FIELDS["can i join the gathering of friends"] = Dict{String,Any}(
    "max_neighbors" => 12)

_applied = 0
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if haskey(_SPECIAL_FIELDS, node.pattern)
            sf = _SPECIAL_FIELDS[node.pattern]
            if haskey(sf, "is_grave");        node.is_grave        = Bool(sf["is_grave"]); end
            if haskey(sf, "grave_reason");    node.grave_reason    = String(sf["grave_reason"]); end
            if haskey(sf, "is_unlinkable");   node.is_unlinkable   = Bool(sf["is_unlinkable"]); end
            if haskey(sf, "max_neighbors");   node.max_neighbors   = Int(sf["max_neighbors"]); end
            if haskey(sf, "response_times")
                empty!(node.response_times)
                append!(node.response_times, Float64.(sf["response_times"]))
            end
            if haskey(sf, "required_relations")
                empty!(node.required_relations)
                append!(node.required_relations, String.(sf["required_relations"]))
            end
            # DYNAMIC RELATIONAL TRIPLES: relational_patterns are (subject, relation, object)
            # tuples where `relation` may be a sigil reference like "&causal" / "&temporal".
            # At match time the engine calls expand_relation_if_sigil so the node matches
            # ANY verb in the sigil's expansion (engine.jl:583). grow_nodes_from_packet does
            # NOT read relational_patterns, so we build RelationalTriple objects here.
            if haskey(sf, "relational_patterns")
                empty!(node.relational_patterns)
                for tup in sf["relational_patterns"]
                    subj, rel, obj = String(tup[1]), String(tup[2]), String(tup[3])
                    push!(node.relational_patterns, RelationalTriple(subj, rel, obj))
                end
            end
            if haskey(sf, "relation_weights")
                empty!(node.relation_weights)
                for (k, v) in sf["relation_weights"]
                    node.relation_weights[String(k)] = Float64(v)
                end
            end
            global _applied; _applied += 1
        end
    end
end
println("  ✅ Applied special fields to $_applied nodes")


println("="^70)
filepath = joinpath(@__DIR__, "specimens", "comprehensive_v3_specimen.json")
result = save_specimen_to_file!(filepath)
println("\n✅ SPECIMEN SAVED: $result")

# Quick stats
total_nodes = lock(NODE_LOCK) do; length(NODE_MAP); end
total_lobes = length(Lobe.LOBE_REGISTRY)
println("\n📊 FINAL STATS: $total_nodes nodes across $total_lobes lobes")
