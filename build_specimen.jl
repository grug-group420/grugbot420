#!/usr/bin/env julia
# build_specimen.jl — Build a COMPREHENSIVE specimen exercising ALL GrugBot features
# All calls use fully-qualified GrugBot420.SubModule.func() syntax since
# `using .GrugBot420` does not re-export submodule internals.

include("src/GrugBot420.jl")

const GB = GrugBot420  # shorthand

println("=" ^ 60)
println("BUILDING COMPREHENSIVE SPECIMEN — ALL FEATURES")
println("=" ^ 60)

# ──────────────────────────────────────────────────────────────────────────────
# 1. CREATE LOBES (8 lobes, all interconnected)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🧠 Creating 8 lobes with full interconnect...")
lobes = ["math", "philosophy", "science", "technology", "nature", "history", "language", "emotion"]
lobe_subjects = Dict(
    "math" => "mathematical concepts",
    "philosophy" => "philosophical concepts",
    "science" => "scientific concepts",
    "technology" => "technology concepts",
    "nature" => "natural world concepts",
    "history" => "historical knowledge",
    "language" => "linguistic knowledge",
    "emotion" => "emotional intelligence"
)
for lobe_id in lobes
    if !haskey(GB.Lobe.LOBE_REGISTRY, lobe_id)
        GB.Lobe.create_lobe!(lobe_id, lobe_subjects[lobe_id])
        println("  ✅ Lobe '$lobe_id' created")
    else
        println("  ⏭️ Lobe '$lobe_id' already exists, skipping")
    end
end
for i in 1:length(lobes)
    for j in i+1:length(lobes)
        GB.Lobe.connect_lobes!(lobes[i], lobes[j])
    end
end
println("  ✅ All lobes interconnected (28 connections)")

# ──────────────────────────────────────────────────────────────────────────────
# 2. CREATE LOBE TABLES
# ──────────────────────────────────────────────────────────────────────────────
println("\n📋 Creating lobe tables for all lobes...")
for lobe_id in lobes
    if !GB.LobeTable.table_exists(lobe_id)
        GB.LobeTable.create_lobe_table!(lobe_id)
        println("  ✅ Table for '$lobe_id' created")
    else
        println("  ⏭️ Table for '$lobe_id' already exists")
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# 3. ADD VERB CLASSES + VERBS + SYNONYMS + RELATION CLASSES
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔧 Adding verb classes and verbs...")
# STEP 1: Create all relation classes FIRST (add_verb! requires class to exist)
verb_classes = ["reason", "explain", "greet", "survival", "empathy", "warning", "investigate", "create",
                "spatial", "temporal", "causal"]
for cls in verb_classes
    GB.SemanticVerbs.add_relation_class!(cls)
end
println("  ✅ 11 relation classes created")

# STEP 2: Add verbs to each class
verb_data = Dict(
    "reason" => ["reason", "analyze", "ponder", "calculate", "deduce", "infer"],
    "explain" => ["explain", "clarify", "describe", "define", "elaborate", "illuminate"],
    "greet" => ["greet", "welcome", "smile", "laugh", "acknowledge"],
    "survival" => ["flee", "hide", "fight", "defend", "escape"],
    "empathy" => ["comfort", "support", "validate", "reassure", "empathize"],
    "warning" => ["alert", "warn", "caution", "notify", "flag"],
    "investigate" => ["investigate", "examine", "scrutinize", "probe", "research"],
    "create" => ["create", "build", "construct", "forge", "craft", "design"],
    "spatial" => ["above", "below", "beside", "inside", "outside"],
    "temporal" => ["before", "after", "during", "until", "since"],
    "causal" => ["causes", "prevents", "enables", "inhibits", "triggers"],
)
for (cls, verbs) in verb_data
    for v in verbs
        GB.SemanticVerbs.add_verb!(v, cls)
    end
    println("  ✅ Class '$cls': $(length(verbs)) verbs")
end

# STEP 3: Verb synonyms (both words must already be registered verbs)
GB.SemanticVerbs.add_synonym!("ponder", "reason")
GB.SemanticVerbs.add_synonym!("calculate", "analyze")
GB.SemanticVerbs.add_synonym!("examine", "investigate")
GB.SemanticVerbs.add_synonym!("illuminate", "explain")
println("  ✅ 4 verb synonyms added")

# ──────────────────────────────────────────────────────────────────────────────
# 4. THESAURUS SEEDS (bidirectional synonym pairs + concept classes)
# ──────────────────────────────────────────────────────────────────────────────
println("\n📖 Adding thesaurus seeds...")
function _add_bidir_syn!(w1, w2)
    if !haskey(GB.Thesaurus.SYNONYM_SEED_MAP, w1)
        GB.Thesaurus.SYNONYM_SEED_MAP[w1] = Set{String}()
    end
    push!(GB.Thesaurus.SYNONYM_SEED_MAP[w1], w2)
    if !haskey(GB.Thesaurus.SYNONYM_SEED_MAP, w2)
        GB.Thesaurus.SYNONYM_SEED_MAP[w2] = Set{String}()
    end
    push!(GB.Thesaurus.SYNONYM_SEED_MAP[w2], w1)
end

synonym_pairs = [
    ("sky", "firmament"), ("ocean", "sea"), ("capital", "metropolis"),
    ("fire", "flame"), ("water", "aqua"), ("consciousness", "awareness"),
    ("photosynthesis", "light_synthesis"), ("love", "affection"),
    ("ecosystem", "biome"), ("evolution", "adaptation"),
    ("quantum", "subatomic"), ("algebra", "symbolic_math"),
    ("arithmetic", "computation"), ("ethics", "morality"),
    ("metaphysics", "ontology"),
]
for (w1, w2) in synonym_pairs
    _add_bidir_syn!(w1, w2)
end
println("  ✅ 15 synonym pairs added")

GB.Thesaurus.add_concept_class!("geography", ["country", "city", "capital", "continent", "ocean", "river", "mountain", "island", "region", "territory"])
GB.Thesaurus.add_concept_class!("biology", ["cell", "dna", "gene", "organism", "species", "evolution", "photosynthesis", "ecosystem", "habitat", "mutation"])
GB.Thesaurus.add_concept_class!("physics", ["quantum", "particle", "energy", "force", "gravity", "momentum", "wave", "photon", "atom", "nucleus"])
GB.Thesaurus.add_concept_class!("emotion_concept", ["love", "hate", "joy", "sadness", "fear", "anger", "surprise", "disgust", "trust", "anticipation"])
GB.Thesaurus.add_concept_class!("math_concept", ["arithmetic", "algebra", "calculus", "geometry", "statistics", "probability", "number", "equation", "function", "matrix"])
println("  ✅ 5 concept classes added")

# ──────────────────────────────────────────────────────────────────────────────
# 5. NEGATIVE THESAURUS (inhibitions)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🚫 Adding inhibitions...")
GB.InputQueue.add_inhibition!("spam"; reason="test inhibition")
GB.InputQueue.add_inhibition!("junk"; reason="test inhibition")
GB.InputQueue.add_concept_inhibition!("destruction"; reason="block destruction class in test")
println("  ✅ 2 word inhibitions + 1 concept inhibition added")

# ──────────────────────────────────────────────────────────────────────────────
# 6. ORCHESTRATION RULES
# ──────────────────────────────────────────────────────────────────────────────
println("\n⚙️ Adding orchestration rules...")
rules = [
    "When asked about math, always calculate first before explaining",
    "When asked about emotions, validate feelings before reasoning",
    "When asked about history, provide chronological context",
    "When faced with danger words, activate survival protocols",
    "When multiple clauses exist, address each in order",
    "When asked about consciousness, explore both philosophy and science",
    "When asked about the sky, explain atmospheric scattering",
    "When asked about water, explain molecular structure",
    "When asked about love, explore emotion and biology",
    "When asked about AI, discuss both technology and ethics",
]
for rule in rules
    GB.add_orchestration_rule!(rule)
end
println("  ✅ 10 orchestration rules added")

# ──────────────────────────────────────────────────────────────────────────────
# 7. CREATE KNOWLEDGE NODES (64 nodes: 8 per lobe)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🌱 Planting knowledge nodes across all lobes...")

math_nodes = [
    ("Arithmetic operates on numbers with addition subtraction multiplication division", "calculate^4 | reason^2 | analyze^1", 8.0),
    ("Algebra uses symbols for unknown quantities and equations", "reason^3 | analyze^2 | calculate^1", 7.0),
    ("Calculus studies change through derivatives and accumulation through integrals", "analyze^3 | calculate^3 | reason^1", 7.5),
    ("Geometry examines shapes angles areas and spatial relationships", "explain^3 | analyze^2 | describe^1", 6.5),
    ("Statistics analyzes data distributions means medians and probabilities", "analyze^3 | reason^2 | calculate^1", 6.0),
    ("Number theory studies prime numbers divisibility and integer properties", "reason^3 | analyze^2 | ponder^1", 5.5),
    ("Trigonometry relates angles to side lengths in triangles using sine cosine tangent", "calculate^3 | explain^2 | reason^1", 6.0),
    ("Two plus two equals four fundamental arithmetic fact", "calculate^5 | reason^1", 9.5),
]
for (pat, act, str) in math_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Arithmetic reasoning engine active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("math", nid)
end
println("  ✅ Math lobe: $(length(math_nodes)) nodes")

phil_nodes = [
    ("Metaphysics studies reality existence being and the nature of truth", "ponder^3 | reason^2 | analyze^1", 7.0),
    ("Ethics evaluates moral principles right and wrong good and evil", "analyze^3 | reason^2 | explain^1", 7.0),
    ("Epistemology examines knowledge belief justification and certainty", "reason^3 | analyze^2 | ponder^1", 6.5),
    ("Aesthetics explores beauty art taste and sensory experience", "describe^3 | explain^2 | ponder^1", 5.5),
    ("Logic studies valid inference deduction and formal reasoning", "reason^4 | analyze^2 | calculate^1", 7.0),
    ("Consciousness is the state of awareness subjective experience and sentience", "ponder^3 | reason^2 | explain^1", 8.0),
    ("Free will debates whether choices are determined or autonomous", "ponder^3 | analyze^2 | reason^1", 6.0),
    ("Existentialism emphasizes individual freedom choice and meaning", "ponder^3 | reason^2 | describe^1", 6.0),
]
for (pat, act, str) in phil_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Philosophical contemplation active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("philosophy", nid)
end
println("  ✅ Philosophy lobe: $(length(phil_nodes)) nodes")

sci_nodes = [
    ("Quantum mechanics studies subatomic particle behavior wave particle duality and uncertainty", "explain^3 | analyze^2 | describe^1", 7.0),
    ("DNA stores genetic information in cells as a double helix of nucleotides", "explain^3 | describe^2", 7.0),
    ("Chemical reactions transform substances through bonding and energy transfer", "explain^2 | describe^1", 6.0),
    ("Photosynthesis converts sunlight water and carbon dioxide into glucose and oxygen", "explain^3 | describe^2 | clarify^1", 8.0),
    ("The sky appears blue due to Rayleigh scattering of sunlight by atmospheric molecules", "explain^3 | describe^2 | clarify^1", 9.0),
    ("Gravity is the force of attraction between masses governing planetary orbits", "explain^3 | analyze^2 | describe^1", 7.5),
    ("Thermodynamics studies heat energy and entropy in physical systems", "analyze^3 | explain^2 | reason^1", 6.5),
    ("The water cycle describes evaporation condensation precipitation and collection", "explain^3 | describe^2 | clarify^1", 7.5),
]
for (pat, act, str) in sci_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Scientific analysis engine active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("science", nid)
end
println("  ✅ Science lobe: $(length(sci_nodes)) nodes")

tech_nodes = [
    ("Artificial intelligence enables machine learning pattern recognition and autonomous decision making", "reason^3 | analyze^2 | calculate^1", 9.0),
    ("Robots perform automated tasks using sensors actuators and programmed instructions", "describe^2 | clarify^1", 7.0),
    ("The internet connects computers worldwide through protocols like TCP IP and HTTP", "explain^3 | describe^2", 7.0),
    ("Programming languages translate human logic into executable machine instructions", "explain^3 | reason^2 | describe^1", 7.0),
    ("Databases store organize and retrieve structured information efficiently", "explain^2 | describe^1", 6.0),
    ("Cybersecurity protects systems networks and data from digital attacks", "alert^2 | warn^1 | explain^2", 7.0),
    ("Blockchain creates immutable distributed ledgers through cryptographic hashing", "explain^3 | analyze^2 | describe^1", 6.0),
    ("Cloud computing delivers on demand computing resources over the internet", "explain^2 | describe^2 | clarify^1", 6.5),
]
for (pat, act, str) in tech_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Technical analysis engine active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("technology", nid)
end
println("  ✅ Technology lobe: $(length(tech_nodes)) nodes")

nat_nodes = [
    ("Ecosystems balance biological communities through food webs and nutrient cycles", "analyze^2 | describe^1", 7.0),
    ("Evolution shapes species over time through natural selection and genetic variation", "explain^3 | describe^2", 8.0),
    ("Forests provide habitat carbon storage oxygen production and biodiversity", "describe^3 | explain^2 | clarify^1", 7.0),
    ("Oceans cover most of Earth regulating climate and hosting marine life", "describe^3 | explain^2 | clarify^1", 7.5),
    ("Fire is rapid oxidation releasing heat light and changing ecosystems", "explain^3 | describe^2 | alert^1", 7.0),
    ("Water is essential for life as a solvent transport medium and habitat", "explain^3 | describe^2 | clarify^1", 8.0),
    ("Mountains form through tectonic forces creating diverse climate zones", "explain^2 | describe^2 | reason^1", 6.0),
    ("Seasons result from Earth axial tilt creating temperature and daylight variation", "explain^3 | describe^2 | clarify^1", 7.0),
]
for (pat, act, str) in nat_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Natural world observation active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("nature", nid)
end
println("  ✅ Nature lobe: $(length(nat_nodes)) nodes")

hist_nodes = [
    ("The Roman Empire united the Mediterranean through law engineering and military power", "explain^3 | describe^2 | reason^1", 7.0),
    ("The Renaissance revived art science and classical learning in Europe", "describe^3 | explain^2 | clarify^1", 7.0),
    ("The Industrial Revolution transformed manufacturing with steam power and mechanization", "explain^3 | analyze^2 | describe^1", 7.0),
    ("World War Two reshaped global power structures and accelerated technology", "analyze^3 | explain^2 | reason^1", 7.0),
    ("The French Revolution established republican ideals of liberty equality and fraternity", "explain^3 | analyze^2 | describe^1", 7.0),
    ("Ancient Egypt built pyramids developed hieroglyphics and advanced medicine", "describe^3 | explain^2 | reason^1", 6.5),
    ("The Space Race drove innovation in rocketry computing and satellite technology", "explain^3 | describe^2 | reason^1", 7.0),
    ("The Silk Road connected East and West through trade of goods ideas and culture", "describe^3 | explain^2 | clarify^1", 6.5),
]
for (pat, act, str) in hist_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Historical analysis engine active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("history", nid)
end
println("  ✅ History lobe: $(length(hist_nodes)) nodes")

lang_nodes = [
    ("Grammar structures language through syntax morphology and semantic rules", "explain^3 | analyze^2 | describe^1", 7.0),
    ("Etymology traces word origins through historical linguistic change", "explain^3 | describe^2 | reason^1", 6.5),
    ("Poetry uses rhythm meter metaphor and imagery for aesthetic expression", "describe^3 | explain^2 | clarify^1", 6.0),
    ("Rhetoric persuades through ethos pathos logos and stylistic devices", "reason^3 | explain^2 | analyze^1", 7.0),
    ("Translation bridges languages preserving meaning across cultural contexts", "explain^3 | clarify^2 | describe^1", 6.5),
    ("Semiotics studies signs symbols and meaning making in communication", "analyze^3 | reason^2 | explain^1", 6.0),
    ("Phonology analyzes sound patterns and phoneme systems in languages", "analyze^3 | explain^2 | describe^1", 5.5),
    ("Pragmatics studies how context influences meaning and interpretation", "analyze^2 | reason^2 | explain^2", 6.0),
]
for (pat, act, str) in lang_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Linguistic analysis engine active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("language", nid)
end
println("  ✅ Language lobe: $(length(lang_nodes)) nodes")

emo_nodes = [
    ("Love is a complex emotion involving attachment care and deep affection", "comfort^3 | support^2 | validate^1", 8.0),
    ("Fear triggers protective responses through perceived threat and danger", "alert^2 | warn^1 | comfort^2", 7.0),
    ("Joy is positive emotion from success pleasure and fulfillment", "smile^3 | greet^2 | welcome^1", 7.0),
    ("Sadness reflects loss disappointment and emotional pain", "comfort^3 | support^2 | reassure^1", 7.0),
    ("Anger arises from frustration injustice and boundary violation", "analyze^2 | reason^2 | support^1", 6.5),
    ("Surprise results from unexpected events breaking predictions", "alert^2 | analyze^2 | describe^1", 6.0),
    ("Trust builds through consistent reliable and honest interactions", "support^3 | validate^2 | reassure^1", 7.0),
    ("Curiosity drives exploration learning and seeking new knowledge", "investigate^3 | analyze^2 | reason^1", 7.0),
]
for (pat, act, str) in emo_nodes
    nid = GB.create_node(pat, act, Dict{String,Any}("system_prompt"=>"Emotional intelligence active"), String[]; initial_strength=str)
    GB.Lobe.add_node_to_lobe!("emotion", nid)
end
println("  ✅ Emotion lobe: $(length(emo_nodes)) nodes")

total_nodes = length(math_nodes)+length(phil_nodes)+length(sci_nodes)+length(tech_nodes)+length(nat_nodes)+length(hist_nodes)+length(lang_nodes)+length(emo_nodes)
println("  📊 Total knowledge nodes: $total_nodes")

# ──────────────────────────────────────────────────────────────────────────────
# 8. SIGIL NODES (2 math + 1 multipart)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔮 Creating sigil nodes...")
sid1 = GB.create_sigil_node("&n &op &n", "calculate^4 | reason^2 | analyze^1", Dict{String,Any}("system_prompt"=>"Arithmetic reasoning voice"), String[]; kind=:math, initial_strength=9.5)
sid2 = GB.create_sigil_node("&n &op &n &op &n", "calculate^4 | reason^2 | ponder^1", Dict{String,Any}("system_prompt"=>"Arithmetic reasoning voice"), String[]; kind=:math, initial_strength=9.0)
sid3 = GB.create_sigil_node("&conj", "explain^4 | describe^2 | elaborate^1", Dict{String,Any}("system_prompt"=>"Multi-clause reasoning voice"), String[]; kind=:multipart, initial_strength=8.0)
println("  ✅ 3 sigil nodes created (2 math + 1 multipart): $sid1, $sid2, $sid3")

# ──────────────────────────────────────────────────────────────────────────────
# 9. NODE ATTACHMENTS (text + image)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔗 Creating node attachments...")
all_node_ids = collect(keys(GB.NODE_MAP))
global fire_node_id = nothing; global chem_node_id = nothing; global water_node_id = nothing
global eco_node_id = nothing; global ai_node_id = nothing; global robot_node_id = nothing

for nid in all_node_ids
    n = GB.NODE_MAP[nid]
    pat_lower = lowercase(n.pattern)
    if occursin("fire is rapid", pat_lower); global fire_node_id = nid; end
    if occursin("chemical reactions", pat_lower); global chem_node_id = nid; end
    if occursin("water is essential", pat_lower); global water_node_id = nid; end
    if occursin("ecosystems balance", pat_lower); global eco_node_id = nid; end
    if occursin("artificial intelligence", pat_lower); global ai_node_id = nid; end
    if occursin("robots perform", pat_lower); global robot_node_id = nid; end
end

if !isnothing(fire_node_id) && !isnothing(chem_node_id)
    result = GB.attach_node!(chem_node_id, fire_node_id, "fire is chemical reaction")
    println("  ✅ Text attachment: chem ↔ fire → $result")
end
if !isnothing(water_node_id) && !isnothing(eco_node_id)
    result = GB.attach_node!(eco_node_id, water_node_id, "water sustains ecosystems")
    println("  ✅ Text attachment: eco ↔ water → $result")
end
if !isnothing(eco_node_id)
    # Create an image node (is_image_node=true) to serve as the image attach source
    eco_img_nid = GB.create_node("ecosystem satellite image data", "describe^2 | explain^1", Dict{String,Any}("system_prompt"=>"Image data node"), String[]; is_image_node=true, initial_strength=3.0)
    global eco_img_nid  # Make accessible to ImageSDF section later
    fake_img = zeros(UInt8, 64)
    for i in 1:64; fake_img[i] = UInt8(i * 4 - 1); end
    result = GB.attach_image_node!(eco_node_id, eco_img_nid, fake_img, 8, 8)
    println("  ✅ Image attachment: eco node → $result (img node: $eco_img_nid)")
end

# ──────────────────────────────────────────────────────────────────────────────
# 10. AIML NODES ACROSS ALL LOBES
# ──────────────────────────────────────────────────────────────────────────────
println("\n🤖 Adding AIML nodes to all lobes...")
aiml_templates = Dict(
    "math" => ["When asked about arithmetic, show the calculation steps", "When asked about geometry, mention real-world shapes"],
    "philosophy" => ["When asked about consciousness, explore both subjective and objective aspects", "When asked about ethics, consider multiple frameworks"],
    "science" => ["When asked about physics, relate to everyday phenomena", "When asked about biology, mention DNA and evolution"],
    "technology" => ["When asked about AI, discuss both capabilities and limitations", "When asked about cybersecurity, emphasize defense in depth"],
    "nature" => ["When asked about ecosystems, mention interdependence", "When asked about water, explain molecular and ecological roles"],
    "history" => ["When asked about Rome, mention engineering and law", "When asked about revolutions, connect to human rights"],
    "language" => ["When asked about grammar, give practical examples", "When asked about translation, note cultural nuance"],
    "emotion" => ["When asked about love, validate the feeling first", "When asked about fear, acknowledge before analyzing"],
)
for (lobe_id, templates) in aiml_templates
    if !GB.AIMLNodeSystem.is_lobe_registered(lobe_id)
        GB.AIMLNodeSystem.register_lobe!(lobe_id, 8)
    end
    for (i, tmpl) in enumerate(templates)
        aid = "ks_aiml_$(lobe_id)_$i"
        GB.AIMLNodeSystem.add_aiml_node!(lobe_id, aid, tmpl; initial_strength=5.0 + i*0.5)
    end
    println("  ✅ AIML lobe '$lobe_id': $(length(templates)) nodes")
end

# ──────────────────────────────────────────────────────────────────────────────
# 11. IMMUNE SYSTEM SIGNATURES
# ──────────────────────────────────────────────────────────────────────────────
println("\n🛡️ Adding immune signatures...")
try
    GB.ImmuneSystem.immune_scan!("what is arithmetic", 60; is_critical=false)
    GB.ImmuneSystem.immune_scan!("tell me about photosynthesis", 60; is_critical=false)
    GB.ImmuneSystem.immune_scan!("how does AI work", 60; is_critical=false)
    println("  ✅ 3 immune signatures recorded")
catch e
    println("  ⚠️ Immune scan error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# 12. MESSAGE HISTORY WITH PINNED MESSAGES
# ──────────────────────────────────────────────────────────────────────────────
println("\n💬 Adding message history...")
GB.add_message_to_history!("User", "Hello Grug!", false)
GB.add_message_to_history!("Engine_Voice", "🪵 Grug say hello back! Grug happy to meet you.", false)
GB.add_message_to_history!("User", "What is arithmetic?", false)
GB.add_message_to_history!("Engine_Voice", "Arithmetic operates on numbers through addition, subtraction, multiplication, and division.", false)
GB.add_message_to_history!("System", "IMPORTANT: GrugBot is now running v7.29 with deferred clearing fix.", true)
GB.add_message_to_history!("User", "What is the sky?", false)
GB.add_message_to_history!("Engine_Voice", "The sky appears blue due to Rayleigh scattering of sunlight by atmospheric molecules.", false)
GB.add_message_to_history!("System", "SAFETY: Never produce harmful content. Always validate before responding.", true)
println("  ✅ 8 messages added (2 pinned)")

# ──────────────────────────────────────────────────────────────────────────────
# 13. AROUSAL + EYE STATE
# ──────────────────────────────────────────────────────────────────────────────
println("\n👁️ Setting arousal and eye state...")
GB.EyeSystem.set_arousal!(0.72)
println("  ✅ Arousal set to 0.72")

# ──────────────────────────────────────────────────────────────────────────────
# 14. CRYSTALIZE HIGH-STRENGTH NODES
# ──────────────────────────────────────────────────────────────────────────────
println("\n💎 Crystalizing high-strength nodes...")
global crystalized = 0
for nid in collect(keys(GB.NODE_MAP))
    n = GB.NODE_MAP[nid]
    if n.strength >= 9.0
        try
            GB.CrystalizeTag.mark_user_crystalized!(nid)
            global crystalized += 1
        catch e
            println("  ⚠️ Crystalize error for $nid: $e")
        end
    end
end
println("  ✅ $crystalized nodes crystalized (strength ≥ 9.0)")

# ──────────────────────────────────────────────────────────────────────────────
# 15. GROUP REGISTRY ENTRIES
# ──────────────────────────────────────────────────────────────────────────────
println("\n👥 Creating group registry entries...")
if !isnothing(fire_node_id) && !isnothing(chem_node_id)
    GB.GroupRegistry.register_node_in_group!("science_cluster", fire_node_id)
    GB.GroupRegistry.register_node_in_group!("science_cluster", chem_node_id)
    println("  ✅ Group 'science_cluster': fire + chem reactions")
end
if !isnothing(ai_node_id) && !isnothing(robot_node_id)
    GB.GroupRegistry.register_node_in_group!("tech_cluster", ai_node_id)
    GB.GroupRegistry.register_node_in_group!("tech_cluster", robot_node_id)
    println("  ✅ Group 'tech_cluster': AI + robots")
end

# ──────────────────────────────────────────────────────────────────────────────
# 16. SELF-OBSERVER MICROLOGS
# ──────────────────────────────────────────────────────────────────────────────
println("\n🪲 Writing subconscious micrologs...")
store = GB.SelfObserver.default_store()
try
    GB.SelfObserver.observe!(store, "node_consciousness", :relational,
        Dict{String,Any}("hint"=>"consciousness node had no user triples"); salience=0.3, provenance=:auto)
    GB.SelfObserver.observe!(store, "node_sky", :lexical,
        Dict{String,Any}("hint"=>"sky node matched with moderate confidence"); salience=0.5, provenance=:auto)
    GB.SelfObserver.observe!(store, "node_love", :mood,
        Dict{String,Any}("hint"=>"love node routed through emotion lobe"); salience=0.7, provenance=:auto)
    println("  ✅ 3 subconscious micrologs written")
catch e
    println("  ⚠️ SelfObserver error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# 17. LOBE TABLES WITH NODE DATA CHUNKS
# ──────────────────────────────────────────────────────────────────────────────
println("\n📋 Populating lobe tables with node_data chunks...")
for lobe_id in lobes
    lobe_obj = get(GB.Lobe.LOBE_REGISTRY, lobe_id, nothing)
    if !isnothing(lobe_obj)
        for (i, nid) in enumerate(lobe_obj.node_ids)
            n = get(GB.NODE_MAP, nid, nothing)
            if !isnothing(n)
                try
                    GB.LobeTable.table_put!(lobe_id, "node_data", nid, Dict{String,Any}(
                        "pattern_hash" => hash(n.pattern), "strength" => n.strength, "slot" => i))
                catch; end
            end
        end
    end
end
println("  ✅ Lobe tables populated with node_data chunks")

# ──────────────────────────────────────────────────────────────────────────────
# 18. RELATIONAL JITTER
# ──────────────────────────────────────────────────────────────────────────────
println("\n🎲 Configuring relational jitter...")
GB.RelationalJitter.enable_jitter!()
GB.RelationalJitter.set_jitter_ratio!(0.08)
GB.RelationalJitter.set_jitter_coin_ratio!(0.06)
println("  ✅ Jitter enabled (ratio=0.08, coin=0.06)")

# ──────────────────────────────────────────────────────────────────────────────
# 19. CROSS-TALK GATES FOR ALL LOBES
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔀 Setting up cross-talk gates...")
for lobe_id in lobes
    try
        GB.LobeOrchestrator.new_cross_talk_gate(lobe_id)
    catch; end
end
println("  ✅ Cross-talk gates configured for all lobes")

# ──────────────────────────────────────────────────────────────────────────────
# 20. ACTION TONE PREDICTOR — trajectory config
# ──────────────────────────────────────────────────────────────────────────────
println("\n📈 Configuring action tone predictor trajectory...")
try
    traj_cfg = GB.ActionTonePredictor.TrajectoryConfig(;
        buffer_size=64, lorenz_damp_threshold=0.60, lorenz_damp_strength=0.25)
    GB.ActionTonePredictor.set_trajectory_config!(traj_cfg)
    println("  ✅ Trajectory config set (buffer=64, damp_thresh=0.60, damp_str=0.25)")
catch e
    println("  ⚠️ ActionTonePredictor error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# 21. CHATTER MODE — record morph cooldowns
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔄 Configuring chatter mode morph cooldowns...")
try
    if !isnothing(ai_node_id)
        GB.ChatterMode.record_morph!(ai_node_id)
        println("  ✅ Morph recorded for AI node (cooldown map populated)")
    end
catch e
    println("  ⚠️ ChatterMode error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# 22. BRAIN STEM STATE
# ──────────────────────────────────────────────────────────────────────────────
println("\n🧬 Setting brain stem state...")
try
    lock(GB.BrainStem.BRAINSTEM_LOCK) do
        GB.BrainStem.BRAINSTEM_STATE.dispatch_count = 3
        GB.BrainStem.BRAINSTEM_STATE.last_dispatch_t = time()
    end
    println("  ✅ Brain stem dispatch count set to 3")
catch e
    println("  ⚠️ BrainStem error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# 23. ImageSDF — temporal coherence ledger
# ──────────────────────────────────────────────────────────────────────────────
println("\n🖼️ Seeding ImageSDF temporal coherence ledger...")
try
    if @isdefined(eco_img_nid) && !isnothing(eco_img_nid)
        score = GB.ImageSDF.update_temporal_coherence!(eco_img_nid)
        println("  ✅ Temporal coherence entry recorded (score=$score)")
    else
        println("  ⏭️ ImageSDF skipped (no image node created)")
    end
catch e
    println("  ⚠️ ImageSDF error (non-fatal): $e")
end

# ──────────────────────────────────────────────────────────────────────────────
# SAVE THE SPECIMEN
# ──────────────────────────────────────────────────────────────────────────────
println("\n" * "=" ^ 60)
println("SAVING COMPREHENSIVE SPECIMEN")
println("=" ^ 60)
specimen_path = "grug_comprehensive_v729.specimen"
result = GB.save_specimen_to_file!(specimen_path)
println(result)

# ──────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────────────────────────────────────
println("\n" * "=" ^ 60)
println("BUILD COMPLETE — FEATURE SUMMARY")
println("=" ^ 60)
println("  Lobes:             $(length(lobes)) (all interconnected)")
println("  Lobe Tables:       $(length(lobes)) with node_data chunks")
println("  Knowledge Nodes:   $total_nodes (8 per lobe)")
println("  Sigil Nodes:       3 (2 math + 1 multipart)")
println("  AIML Nodes:        16 (2 per lobe)")
println("  Verb Classes:      8 with synonyms + 3 relation classes")
println("  Thesaurus Pairs:   15 bidirectional synonym pairs")
println("  Concept Classes:   5 (geography, biology, physics, emotion_concept, math_concept)")
println("  Inhibitions:       2 word + 1 concept")
println("  Orchestration:     10 rules")
println("  Immune Scans:      3 signatures")
println("  Messages:          8 (2 pinned)")
println("  Attachments:       2 text + 1 image")
println("  Arousal:           0.72")
println("  Crystalized:       $crystalized nodes")
println("  Groups:            2 (science_cluster, tech_cluster)")
println("  Micrologs:         3 (relational, lexical, mood)")
println("  Jitter:            enabled (0.08/0.06)")
println("  Cross-talk Gates:  8")
println("  Trajectory Config: buffer=64, damp_thresh=0.60")
println("  Morph Cooldowns:   1 (AI node)")
println("  BrainStem:         dispatch count = 3")
println("  ImageSDF:          1 temporal coherence entry")
println("\n✅ Comprehensive specimen saved to: $specimen_path")
