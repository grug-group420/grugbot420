#!/usr/bin/env julia
# ==============================================================================
# build_comprehensive_specimen_c.jl — Thread C comprehensive specimen builder
# ==============================================================================
# Builds a specimen exercising EVERY current GrugBot420 feature the user asked
# about: sigils (lambda/macro/tag/relation/procedure, built-in + custom
# registered), relational triples with dynamic sigil evaluation, thesaurus
# (word-level seed synonyms + concept-level registration), anti-thesaurus
# (/negativeThesaurus input inhibition), semantic verbs + relation classes +
# verb synonyms, per-lobe dictionary, time nodes with isolation, procedure
# chain sigil nodes, cross-lobe connected nodes, and 8 lobes matching the
# reference log's shape (default/emotions/language/math/science/social/
# survival/time).
#
# NOTE ON TWO KNOWN GAPS vs the user's literal description (documented
# honestly rather than faked):
#   1. "register two concepts with a synonymity intensity set by end user":
#      no dedicated graded-intensity concept registry exists in the codebase.
#      The closest real mechanism is Thesaurus.add_seed_synonym!(canonical,
#      synonyms) which supports multi-word CONCEPT strings (not just single
#      words) registered bidirectionally — we use this for concept-level
#      registration, and separately demonstrate thesaurus_compare()'s
#      algorithmic (non-user-set) concept similarity scoring so both facets
#      of "thesaurus for concepts" are covered.
#   2. "anti-thesaurus... same in reverse": the actual current feature named
#      this way is /negativeThesaurus — an INPUT INHIBITION/blocklist system
#      (words tagged with a reason are filtered out of input tokens before
#      pattern scanning), not a graded antonym-intensity registry. We use it
#      as-is since it is the only feature with that literal name.
#
# ANTIMATCH NODES ARE REMOVED (confirmed repeatedly in the codebase) — this
# specimen does NOT create any antimatch nodes. The reference log's Turns
# 33-34 "anti-match" flavor is reinterpreted using /negativeThesaurus
# inhibition in the conversation test script instead.
# ==============================================================================

ENV["GRUG_NO_AUTOLOAD"] = "1"

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420
using JSON

# GRUG: Main.jl is include()'d *inside* GrugBot420.jl's module scope, so its
# top-level bindings (save_specimen_to_file!, load_specimen_from_file!,
# process_mission, NODE_MAP, register_relation_sigil!, etc.) live in
# GrugBot420, not Main. Pull in everything this script touches explicitly
# (mirrors the pattern used by comprehensive_test_v828e.jl).
import .GrugBot420:
    save_specimen_to_file!, load_specimen_from_file!, process_mission,
    NODE_MAP, NODE_LOCK, GROUP_MAP, GROUP_LOCK,
    _ENGINE_SIGIL_TABLE, _dict_define_word!, _dict_definitions_count,
    grow_nodes_from_packet, create_node, is_time_node,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    LAST_VOTER_IDS, LAST_VOTER_LOCK

# GRUG: import the submodules themselves (not exported by GrugBot420.jl
# except SigilRegistry) so this script can use qualified calls like
# SigilRegistry.register_sigil!(...), Lobe.create_lobe!(...), etc.
import .GrugBot420: Lobe, SigilRegistry, SemanticVerbs, Thesaurus, InputQueue,
                     LobeOrchestrator

import .GrugBot420.Lobe: LOBE_REGISTRY, NODE_TO_LOBE_IDX

println("="^78)
println("GRUG THREAD-C COMPREHENSIVE SPECIMEN BUILD")
println("="^78)

# ──────────────────────────────────────────────────────────────────────────
# PHASE 0: Lobes — match reference log's 8-lobe shape
# ──────────────────────────────────────────────────────────────────────────
println("\n🧠 Phase 0: Lobes")

function ensure_lobe(lobe_id::String, subject::String, whitelist::Vector{String})
    try
        Lobe.create_lobe!(lobe_id, subject; subject_whitelist=Set{String}(whitelist))
        println("  ✓ created $lobe_id")
    catch e
        try
            Lobe.add_lobe_whitelist!(lobe_id, whitelist...)
            println("  · $lobe_id already exists, topped up whitelist")
        catch e2
            @warn "ensure_lobe($lobe_id) failed both create and whitelist top-up" e e2
        end
    end
end

# "default" lobe already exists from Main.jl boot (line ~13607). Others we add.
ensure_lobe("emotions", "feelings and emotional states",
    ["sad","happy","fear","scared","lonely","joy","love","comfort","grief","emotion","feeling","miss"])
ensure_lobe("language", "words meaning and definitions",
    ["word","define","definition","meaning","synonym","concept","thesaurus"])
ensure_lobe("math", "numbers and arithmetic",
    ["math","number","plus","minus","times","calculate","equation","add","subtract","multiply"])
ensure_lobe("science", "natural science and physical world",
    ["science","gravity","atom","sky","physics","evaporation","water","fire","light"])
ensure_lobe("social", "friendship trust and community",
    ["friend","trust","cooperation","community","social","gratitude","thank"])
ensure_lobe("survival", "danger safety and survival skills",
    ["fire","danger","shelter","water","survival","forage","hunt","cook","volcano","lightning"])
ensure_lobe("time", "temporal orientation and seasons",
    ["time","before","after","now","season","spring","summer","autumn","winter","past","future"])

# Cross-lobe connections (used by cross-lobe-activation test turns)
function connect(a::String, b::String)
    try
        Lobe.connect_lobes!(a, b)
    catch e
        @warn "connect_lobes! $a<->$b failed (may already be connected): $e"
    end
end
connect("survival", "emotions")
connect("emotions", "social")
connect("science", "math")
connect("science", "survival")
connect("time", "science")
connect("time", "social")
connect("language", "science")
connect("math", "time")

println("  ✓ lobes ready")

# ──────────────────────────────────────────────────────────────────────────
# PHASE 1: Custom sigil registration
#   - :relation class custom sigil (/addRelRelation equivalent):  &emotional
#     (matches reference log's inventory) — register directly via
#     SigilRegistry.register_relation_sigil! (same call the CLI uses).
#   - :procedure class custom sigil — a math-acronym-style ordered chain,
#     demonstrating the "registerable functorial/token sigils" the user
#     described. Procedure chains are ALSO exercised via dedicated sigil
#     nodes below (fire-making / water-finding step sequences).
# ──────────────────────────────────────────────────────────────────────────
println("\n🔮 Phase 1: Custom sigil registration")

# &emotional relation sigil — present in reference log's Sigil Inventory.
# Built-in default_registry() does NOT include &emotional, so we register it
# here exactly as /addRelRelation would, proving user-registerable relation
# sigils work.
try
    SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE;
        name = "emotional",
        expansion = ["loves","hates","fears","desires","resents","admires","misses","longs_for"],
        provenance = "user-relation",
        overwrite = true)
    println("  ✓ &emotional relation sigil registered (custom, user-relation provenance)")
catch e
    @warn "register &emotional failed" e
end

# &season macro sigil — present in reference log's Sigil Inventory (macro class,
# lexicon of seasons). Not in engine default_registry(), so register it here.
try
    SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
        name = "season",
        class = :macro,
        applies_at = :bind,
        lexicon = ["spring","summer","autumn","winter"],
        provenance = "user-macro",
        overwrite = true)
    println("  ✓ &season macro sigil registered (custom lexicon: spring/summer/autumn/winter)")
catch e
    @warn "register &season failed" e
end

# &danger tag sigil — present in reference log's Sigil Inventory (simple tag class).
try
    SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
        name = "danger",
        class = :tag,
        applies_at = :bind,
        provenance = "user-tag",
        overwrite = true)
    println("  ✓ &danger tag sigil registered")
catch e
    @warn "register &danger failed" e
end

# :procedure class custom sigil — the "functorial math acronym" style chain.
# &Firestarter expands to an ordered chain of literal + nested sigil tokens.
try
    SigilRegistry.register_procedure_sigil!(_ENGINE_SIGIL_TABLE;
        name = "Firestarter",
        expansion = ["find dry wood", "make spark", "shield from wind", "feed flame", "build up fire"],
        provenance = "user-procedure",
        overwrite = true)
    println("  ✓ &Firestarter procedure sigil registered (5-step chain)")
catch e
    @warn "register &Firestarter failed" e
end

# ──────────────────────────────────────────────────────────────────────────
# PHASE 2: Semantic verbs — built-ins already exist; register custom verb +
# custom relation class + custom synonym to prove the registration path.
# ──────────────────────────────────────────────────────────────────────────
println("\n📖 Phase 2: Semantic verbs")
try
    SemanticVerbs.add_relation_class!("nourishing")
    println("  ✓ relation class 'nourishing' registered")
catch e
    @warn "add_relation_class! nourishing failed" e
end
try
    SemanticVerbs.add_verb!("nourishes", "nourishing")
    SemanticVerbs.add_verb!("sustains", "nourishing")
    println("  ✓ verbs 'nourishes','sustains' added to class 'nourishing'")
catch e
    @warn "add_verb! nourishing failed" e
end
try
    SemanticVerbs.add_synonym!("nourishes", "feeds")
    println("  ✓ synonym 'feeds' -> canonical 'nourishes' registered")
catch e
    @warn "add_synonym! failed" e
end
# Also confirm built-ins are present (no-op check, informative log only).
try
    all_verbs = SemanticVerbs.get_all_verbs()
    println("  · total verbs registered (built-in + custom): $(length(all_verbs))")
catch e
    @warn "get_all_verbs failed" e
end

# ──────────────────────────────────────────────────────────────────────────
# PHASE 3: Thesaurus — word-level seed synonyms + concept-level registration
# ──────────────────────────────────────────────────────────────────────────
println("\n📚 Phase 3: Thesaurus (word + concept level)")

# Word-level EXACT synonymity registrations (bidirectional).
try
    n1 = Thesaurus.add_seed_synonym!("gather", ["forage", "collect"])
    println("  ✓ word seed synonym: gather <-> [forage, collect] ($(n1) synonyms)")
catch e
    @warn "add_seed_synonym! gather failed" e
end
try
    n2 = Thesaurus.add_seed_synonym!("build", ["construct", "assemble"])
    println("  ✓ word seed synonym: build <-> [construct, assemble] ($(n2) synonyms)")
catch e
    @warn "add_seed_synonym! build failed" e
end
try
    n3 = Thesaurus.add_seed_synonym!("burn", ["combust"])
    println("  ✓ word seed synonym: burn <-> [combust] ($(n3) synonyms)")
catch e
    @warn "add_seed_synonym! burn failed" e
end

# CONCEPT-level registration (multi-word canonical/synonym strings). This is
# the closest real analog to "register two concepts as synonymous" since
# add_seed_synonym! accepts arbitrary strings, not just single words. We also
# run thesaurus_compare() afterward to show the algorithmic intensity score
# for a concept pair that was NOT explicitly registered, illustrating the
# difference between explicit registration (binary, high score) and
# algorithmic scoring (graded, computed).
try
    n4 = Thesaurus.add_seed_synonym!("artificial intelligence", ["machine intelligence"])
    println("  ✓ concept seed synonym: 'artificial intelligence' <-> ['machine intelligence'] ($(n4))")
catch e
    @warn "add_seed_synonym! concept failed" e
end

try
    cmp1 = Thesaurus.thesaurus_compare("artificial intelligence", "machine intelligence")
    println("  · thesaurus_compare(registered concept pair) -> $(Thesaurus.format_thesaurus_intensity(cmp1.overall)) (score=$(round(cmp1.overall, digits=3)), type=$(cmp1.match_type))")
catch e
    @warn "thesaurus_compare registered concept pair failed" e
end

try
    cmp2 = Thesaurus.thesaurus_compare("friendship", "companionship")
    println("  · thesaurus_compare(unregistered concept pair, algorithmic) -> $(Thesaurus.format_thesaurus_intensity(cmp2.overall)) (score=$(round(cmp2.overall, digits=3)), type=$(cmp2.match_type))")
catch e
    @warn "thesaurus_compare unregistered concept pair failed" e
end

# ──────────────────────────────────────────────────────────────────────────
# PHASE 4: Anti-thesaurus (/negativeThesaurus input inhibition)
# ──────────────────────────────────────────────────────────────────────────
println("\n🚫 Phase 4: Anti-thesaurus (negative thesaurus inhibition)")
try
    InputQueue.add_inhibition!("nonsense"; reason="filtered as falsehood marker")
    InputQueue.add_inhibition!("fake"; reason="filtered as falsehood marker")
    InputQueue.add_inhibition!("incorrect"; reason="filtered as negation marker")
    println("  ✓ inhibitions registered: nonsense, fake, incorrect")
    println("  · inhibition_count() = $(InputQueue.inhibition_count())")
catch e
    @warn "negativeThesaurus registration failed" e
end

# ──────────────────────────────────────────────────────────────────────────
# PHASE 5: Dictionary (per-lobe word -> definition)
# ──────────────────────────────────────────────────────────────────────────
println("\n📖 Phase 5: Per-lobe dictionary")
try
    ok1 = _dict_define_word!("science", "gravity", "the force that pulls all things toward each other")
    ok2 = _dict_define_word!("emotions", "happiness", "a feeling of warmth and light inside")
    ok3 = _dict_define_word!("survival", "shelter", "a structure that protects from cold rain and danger")
    println("  ✓ dictionary entries defined: gravity(science)=$ok1, happiness(emotions)=$ok2, shelter(survival)=$ok3")
    println("  · total definitions: $(_dict_definitions_count())")
catch e
    @warn "dictionary define failed" e
end

# ──────────────────────────────────────────────────────────────────────────
# PHASE 6: Nodes — natural-language patterns across all 8 lobes, exercising
# relational triples w/ dynamic sigils, time nodes, procedure chain nodes,
# cross-lobe patterns, synonym-expansion-friendly patterns, and answer modes.
# ──────────────────────────────────────────────────────────────────────────
println("\n🌱 Phase 6: Growing nodes")

const _STOP = Set(["what","is","are","the","a","an","do","i","how","why","me",
                   "you","to","of","for","in","on","my","we","does","can",
                   "if","over","like","with","and","there","should","comes"])
function pattern_signal(pat::String)
    toks = [t for t in split(lowercase(pat), r"[^a-z0-9]+") if !isempty(t) && !(t in _STOP)]
    isempty(toks) && (toks = split(lowercase(pat)))
    v = zeros(Float64, 8)
    for tok in toks
        h = hash(tok)
        for d in 1:8
            hd = hash((h, d))
            v[d] += (hd % 1000) / 1000.0
        end
    end
    for d in 1:8
        v[d] = v[d] - floor(v[d])
        v[d] = clamp(0.05 + 0.9 * v[d], 0.0, 1.0)
    end
    return round.(v; digits=4)
end

all_node_ids = String[]

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
        if haskey(extra, "relational_patterns")
            data["aux_triples"] = [[String(t[1]), String(t[2]), String(t[3])] for t in extra["relational_patterns"]]
        end
        if haskey(extra, "relation_weights"); data["relation_weights"] = extra["relation_weights"]; end
        if haskey(extra, "required_relations"); data["required_relations"] = extra["required_relations"]; end
        for k in ("time_node","time_orientation","wants_context")
            if haskey(extra, k); data[k] = extra[k]; end
        end
        node = Dict{String,Any}(
            "pattern"       => pat,
            "action_packet" => act,
            "data"          => data,
            "signal"        => pattern_signal(pat),
        )
        for k in ("is_image_node","drop_table")
            if haskey(extra, k); node[k] = extra[k]; end
        end
        push!(nodes, node)
    end
    packet = JSON.json(Dict("nodes" => nodes))
    ids = grow_nodes_from_packet(packet; target_lobe=lobe_id)
    append!(all_node_ids, ids)
    println("  ✓ $lobe_id: $(length(ids)) nodes")
    return ids
end

E() = Dict{String,Any}()

# ── DEFAULT LOBE ──
grow_lobe("default", [
    ("hey grug what do you know about fire", "reason^5 | explain^3",
     "Grug. Fire question. Grug know fire! Fire burns wood. Fire is hot. Fire give light in dark. Grug respect fire — fire powerful but dangerous.",
     ["fire","burn","wood","hot","light"], 6.0,
     Dict{String,Any}("relational_patterns"=>[("fire","&causal","heat"),("fire","burns","wood")])),
    ("thank you grug you have been helpful", "reason^4",
     "Grug. Gratitude words. Grug glad to help. Grug always here when you need. Come back and talk anytime — Grug learn from you, you learn from Grug. That what friends do.",
     ["thanks","help","friend","gratitude"], 5.0, E()),
    ("tell me about breathing", "explain^4 | reason^3",
     "Grug. Breathing question. Grug breathe air in, breathe air out. Air keep Grug alive. Lungs fill like bag, then empty.",
     ["breathe","air","lungs","life"], 4.5, E()),
    ("what is hunting", "explain^4 | reason^3",
     "Grug. Hunting question. Hunting is finding and catching animal for food. Grug track footprint, move quiet, strike fast.",
     ["hunt","animal","food","track"], 4.5, E()),
    ("hello grug", "reason^3",
     "Grug. Greeting words. Grug say hello back! Good to see you.",
     ["greeting","hello"], 4.0, E()),
])

# ── SCIENCE LOBE (relational triples w/ dynamic sigils: &similarity, &causal, &spatial, &possessive) ──
grow_lobe("science", [
    ("how does gravity work", "explain^5 | reason^3",
     "Grug. Gravity question. Gravity pulls objects down. Everything fall to ground. Big things pull harder — sun pull earth, earth pull Grug. That why Grug not float away.",
     ["gravity","pull","earth","fall"], 6.5,
     Dict{String,Any}("relational_patterns"=>[("gravity","&causal","fall"),("earth","&possessive","gravity")])),
    ("why does fire burn", "explain^5 | reason^3",
     "Grug. Fire-burning question. Fire like star — both burn bright. Fire need wood and air. Wood is fuel, air feeds flame. Without air, fire die. Without wood, fire starve.",
     ["fire","star","burn","fuel"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("fire","&similarity","star"),("fire","&causal","light")])),
    ("why is the sky blue", "explain^5 | reason^3",
     "Grug. Sky question. Sky blue because of how light scatter. Sun light is all colors. Blue light bounce around most in air — that what Grug see when Grug look up.",
     ["sky","blue","light","scatter"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("sky","&spatial","clouds"),("light","&causal","color")])),
    ("define gravity for me", "define^5 | explain^3",
     "Grug. Define gravity. Gravity: the force that pulls all things toward each other. Big things pull harder. Earth pull Grug down. Sun pull Earth around. Gravity hold world together.",
     ["gravity","force","pull"], 6.0, E()),
    ("what is an atom", "define^5 | explain^3",
     "Grug. Atom question. Atom is tiny — very very small. Atom has electrons that orbit around it, like moon around earth. Everything made of atoms. Grug made of atoms. Rock made of atoms.",
     ["atom","electron","tiny","orbit"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("atom","&possessive","electron")])),
    ("heat causes evaporation", "reason^5 | explain^3",
     "Grug. Heat-evaporation link. Yes — heat causes water to become vapor. That is cause and effect. Heat → evaporation → clouds → rain → water again. Cycle of water, driven by sun's heat.",
     ["heat","evaporation","cause","cycle"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("heat","&causal","evaporation")])),
    ("clouds are in the sky", "reason^5 | explain^3",
     "Grug. Cloud-sky relation. Clouds above, in the sky. Sky is where clouds live, where rain comes from. Below the sky is the ground, above the ground is the air, and in the air float the clouds.",
     ["cloud","sky","above","rain"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("cloud","&spatial","sky")])),
    ("cooking food makes it safe", "reason^5",
     "Grug. Cooking-safety link. Cooking make food safe — Grug know this. Fire kill bad things in meat. Cooked food not make Grug sick. This is why fire so important — not just warmth, but safety in food too.",
     ["cook","food","safe","fire"], 4.5,
     Dict{String,Any}("relational_patterns"=>[("cooking","&causal","safety")])),
])

# ── MATH LOBE (arithmetic sigils &n, &op, plus procedure sigil node) ──
grow_lobe("math", [
    ("what is 2 plus 2", "calculate^5",
     "Grug. Arithmetic. Let me lay it out: 2 plus 2 equals 4",
     ["addition","two","four"], 6.0, E()),
    ("what is 3 times 4", "calculate^5",
     "Grug. Arithmetic. 3 times 4 equals 12",
     ["multiply","three","four","twelve"], 6.0, E()),
    ("what is 10 minus 3", "calculate^5",
     "Grug. Arithmetic. The shape of it: 10 minus 3 equals 7.",
     ["subtract","ten","three","seven"], 6.0, E()),
    ("what is &n times &n", "calculate^5",
     "Grug. Generic multiplication sigil match. Grug multiply the two numbers together.",
     ["multiply","number","sigil"], 5.0, E()),
])

# ── EMOTIONS LOBE (comfort mode, cross-lobe w/ social) ──
grow_lobe("emotions", [
    ("why do we feel sad sometimes", "comfort^5 | explain^3",
     "Grug. Sadness question. Sadness is heavy feeling. Sometimes things not go right, sometimes Grug lose something important. But sadness not forever — after sadness, can come understanding. Grug here for you.",
     ["sad","feeling","understanding"], 5.5, E()),
    ("i feel sad today grug", "comfort^5",
     "Grug. Comfort. Grug hear you. Sadness okay — everyone feel sad sometimes. Grug sit with you. When you ready, Grug help find what make you smile again.",
     ["sad","comfort","today"], 5.0, E()),
    ("i am scared of what is coming", "comfort^5",
     "Grug. Comfort. Fear is natural. Fear keep Grug alive — fear of danger, fear of unknown. But Grug not let fear stop Grug. Grug face what comes, and Grug face it with you.",
     ["fear","scared","comfort"], 5.0, E()),
    ("i feel so lonely", "comfort^5",
     "Grug. Comfort, cross-lobe with social. Loneliness hurt. But you not alone — Grug here. Grug understand loneliness. Finding companion, sharing story — that how loneliness go away. Community heal.",
     ["lonely","comfort","community"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("loneliness","&causal","hurt")])),
    ("define happiness", "define^5",
     "Grug. Define. Happiness: a feeling of warmth and light inside. When things go right, when you are with friends, when you are safe and fed — that is happiness. It feels good, like warmth from fire.",
     ["happiness","warmth","feeling"], 5.5, E()),
    ("i miss someone", "comfort^5",
     "Grug. Comfort. Grug understand missing someone. That feeling — they were here, now they not. It hurt, but it mean you loved them. Missing someone is proof of connection. Grug sit with you.",
     ["miss","comfort","connection"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("person","&emotional","memory")])),
    ("person feels music", "reason^5",
     "Grug. Emotional-relation sigil. Yes — person connects to music through feeling. Music makes Grug feel things — joy, sadness, energy, calm. The bond between person and music is emotional, deep, real.",
     ["person","music","emotion"], 4.5,
     Dict{String,Any}("relational_patterns"=>[("person","&emotional","music")])),
])

# ── SURVIVAL LOBE (alert mode, procedure chains, autogrowth novel terms) ──
grow_lobe("survival", [
    ("tell me about water", "reason^5 | explain^3",
     "Grug. Water question. Water essential for life. Water flows downhill — always find lowest place. Grug drink water, Grug find water in streams and rivers.",
     ["water","life","flow"], 6.0, E()),
    ("is fire dangerous", "alert^5",
     "Grug. Alert. ⚠️ Yes! Fire is dangerous. Fire burn skin. Fire spread fast. Fire destroy shelter. Grug respect fire but always careful — never touch, never leave alone.",
     ["fire","danger","careful"], 6.0, E()),
    ("what about deep water", "alert^5",
     "Grug. Alert. ⚠️ Deep water very dangerous. Water can pull Grug under. Current strong. Cannot see bottom. Grug stay near shore, Grug respect deep water.",
     ["water","deep","danger"], 5.5, E()),
    ("how do i make fire", "reason^5",
     "Grug. Procedure chain. Grug teach you: 1) Find dry wood and tinder. 2) Make spark with flint or friction. 3) Shield spark from wind. 4) Feed small flame carefully. 5) Build up with bigger wood. Be patient — fire take time to grow.",
     ["fire","procedure","steps"], 6.5, E()),
    ("how do i find water", "reason^5",
     "Grug. Procedure chain. Grug know how: 1) Look for low ground — water flow downhill. 2) Follow animal tracks — they know where water is. 3) Watch for green plants — they need water too. 4) Listen for running water — river sound carry far.",
     ["water","procedure","steps"], 6.0, E()),
    ("flame combust wood", "reason^5",
     "Grug. Synonym expansion (flame→fire, combust→burn). Yes — flame burns wood. Same thing Grug already know. Fire and flame are one. Burn and combust are one. The fire consumes the wood, turns it to ash and heat.",
     ["flame","fire","burn"], 5.0, E()),
    ("construct a shelter", "reason^5",
     "Grug. Synonym expansion (construct→build), similarity sigil. Build shelter, yes. Cave is like shelter — shelter is like cave. Grug build shelter from branches and leaves and mud. Protection from cold and rain.",
     ["shelter","build","cave"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("cave","&similarity","shelter")])),
    ("fire makes me feel warm and safe", "reason^5",
     "Grug. Cross-lobe: survival -> emotions. Yes — fire gives warmth and protection. Grug understand. Fire keep cold away, fire keep dark away. Fire make cave feel like home. Warmth is comfort.",
     ["fire","warmth","safety"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("fire","&causal","warmth")])),
    ("i need shelter from the cold", "reason^5",
     "Grug. Cross-lobe: survival -> emotions, causal sigil. Cold causes freezing — Grug understand. You need shelter. Build shelter with walls, make fire inside. Warmth and safety together. Grug help.",
     ["shelter","cold","warmth"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("cold","&causal","freezing")])),
    ("a tree has branches", "reason^5",
     "Grug. Possessive sigil. Tree has branches, yes. Tree also has roots in ground. Roots hold tree, branches reach for sky. Tree contains life within its wood — birds nest, squirrels climb, leaves catch sun.",
     ["tree","branch","root"], 4.5,
     Dict{String,Any}("relational_patterns"=>[("tree","&possessive","branch")])),
])

# ── SOCIAL LOBE ──
grow_lobe("social", [
    ("friendship brings joy", "reason^5",
     "Grug. Social relation. Friendship brings joy — yes! When Grug have friend, Grug feel warm inside. Sharing, trusting, cooperating — these build bonds. Joy from friendship is deepest kind.",
     ["friend","joy","bond"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("friendship","&causal","joy")])),
    ("cooperation builds trust", "reason^5",
     "Grug. Social relation. Cooperation builds trust — Grug agree. When people work together, they learn to rely on each other. Trust enable cooperation, and cooperation strengthen trust. Circle of strength.",
     ["cooperation","trust","strength"], 5.0,
     Dict{String,Any}("relational_patterns"=>[("cooperation","&causal","trust")])),
])

# ── TIME LOBE (time_node=true nodes, isolated into time-node-only groups, &temporal sigil, &season macro) ──
grow_lobe("time", [
    ("what comes before the present", "reason^5",
     "Grug. Time node, temporal sigil. Before the present is the past. Past → present → future — time always flow forward. What was becomes what is, and what is becomes what will be.",
     ["past","present","future"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("past","&temporal","present")], "time_node"=>true, "time_orientation"=>"past")),
    ("tell me about spring and summer", "reason^5 | explain^3",
     "Grug. Time node, temporal sigil, science cross-lobe. Spring comes, then summer follows. Spring is when plants grow, when rain falls and seeds sprout. Summer is warm and bright — time of plenty, time of growth.",
     ["spring","summer","season"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("spring","&temporal","summer")], "time_node"=>true, "time_orientation"=>"present")),
    ("spring season", "reason^5",
     "Grug. Season macro sigil, time node. Spring! Season of new beginning. Spring → summer → autumn → winter → spring again. Cycle of seasons, cycle of life. In spring, snow melt, plants grow, animals wake.",
     ["spring","season","cycle"], 5.0,
     Dict{String,Any}("time_node"=>true, "time_orientation"=>"present")),
    ("what comes after winter", "reason^5",
     "Grug. Time node, temporal sigil. After winter comes spring! Winter → spring — the cycle turns. Cold ends, warmth returns, snow melts, plants grow again. Nothing stays winter forever.",
     ["winter","spring","cycle"], 5.5,
     Dict{String,Any}("relational_patterns"=>[("winter","&temporal","spring")], "time_node"=>true, "time_orientation"=>"future")),
])

println("\n  Total nodes grown: $(length(all_node_ids))")

# ──────────────────────────────────────────────────────────────────────────
# PHASE 7: Verify sigil count + save specimen
# ──────────────────────────────────────────────────────────────────────────
println("\n💾 Phase 7: Saving specimen")
n_sigils = length(_ENGINE_SIGIL_TABLE.entries)
println("  · Total sigils registered: $n_sigils")
for (nm, entry) in sort(collect(_ENGINE_SIGIL_TABLE.entries); by=x->x[1])
    println("    &$nm — class=$(entry.class), applies_at=$(entry.applies_at)")
end

SAVE_PATH = joinpath(@__DIR__, "grug_threadC_comprehensive.specimen")
save_result = save_specimen_to_file!(SAVE_PATH)
println("\n  ✓ Specimen saved: $save_result")
println("  Path: $SAVE_PATH")
println("\n[DONE] build_comprehensive_specimen_c.jl complete.")
