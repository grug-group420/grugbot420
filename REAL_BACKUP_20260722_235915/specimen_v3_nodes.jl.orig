# ============================================================================
# specimen_v3_nodes.jl — The big node dataset (natural-language patterns)
# Included by build_specimen_v3.jl. Uses grow_lobe(lobe_id, entries).
# Entry tuple: (pattern, action_packet, system_prompt, noun_anchors, strength, extra)
# ============================================================================

E() = Dict{String,Any}()  # empty extra shorthand
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

# ---------------------------------------------------------------------------
# MATH LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_math", [
    ("what is addition", "calculate^5 | explain^3",
     "Grug. Addition question. Grug put two rocks with two rocks. Now Grug have four rocks. Addition is joining piles together. Grug counted.",
     ["addition","number","rock","sum","four"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("addition","&causal","sum"),("addition","&causal","total"),("number","&causal","count")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("how do i add numbers", "explain^5 | calculate^3",
     "Grug. Adding question. To add, Grug put piles together and count all. Three rocks plus five rocks make eight rocks. Grug count each one.",
     ["addition","add","number","pile","count"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("addition","&causal","sum"),("number","&causal","total")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("what is subtraction", "explain^5 | calculate^4",
     "Grug. Subtraction question. Grug take rocks away from pile. Ten rocks take four rocks leave six rocks. Fewer rocks remain after Grug take.",
     ["subtraction","minus","take","fewer","number"], 5.8, Dict{String,Any}(
        "relational_patterns" => [("subtraction","&causal","difference"),("subtraction","&causal","remainder"),("take","&causal","less")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is multiplication", "calculate^5 | explain^4",
     "Grug. Multiplication question. Multiply is many same piles. Six times seven is seven piles of six rocks. That is forty two rocks. Grug count fast with groups.",
     ["multiply","times","group","product","number"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("multiplication","&causal","product"),("multiplication","&causal","scaling"),("group","&causal","product")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is division", "explain^5 | calculate^4",
     "Grug. Division question. Grug share rocks into equal piles. Twelve rocks into four piles make three rocks each pile. Everyone get same. Fair share.",
     ["division","divide","share","equal","fair"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("division","&causal","sharing"),("division","&causal","equal_parts"),("division","&causal","fairness")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("what is a fraction", "explain^5 | clarify^3",
     "Grug. Fraction question. Fraction is part of whole. Half a fruit is one of two equal pieces. Grug break thing into equal parts and take some.",
     ["fraction","half","part","piece","whole"], 5.0, Dict{String,Any}(
        "relational_patterns" => [("fraction","&causal","part"),("fraction","&causal","portion"),("whole","&causal","fraction")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("how do i solve an equation", "reason^5 | calculate^4 | explain^3",
     "Grug. Equation question. Equation say two sides are equal. Grug do same thing to both sides until unknown rock stands alone. Then Grug know its value.",
     ["equation","solve","equal","unknown","balance"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("unknown","equals","value"),("side","&similarity","side")],
        "relation_weights" => Dict("equals"=>1.4,"balances"=>1.2,"mirrors"=>1.1,"resembles"=>1.0),
        "voice_register" => "explanatory", "frame_hints" => ["warm","exploratory"])),
    ("what is geometry", "explain^5 | describe^4",
     "Grug. Geometry question. Geometry is shape of things. Circle round. Triangle three corners. Square four equal sides. Grug measure angles and lines.",
     ["geometry","shape","circle","triangle","angle"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("geometry","&causal","shape"),("geometry","&causal","measurement"),("shape","&possessive","angle")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("count to ten for me", "calculate^5",
     "Grug. Counting question. One two three four five six seven eight nine ten. Grug count on fingers and toes. Grug never lose count of rocks.",
     ["count","number","ten","finger","order"], 8.5, E()),  # solidified
    ("what is nothingness", "explain^5 | ponder^3",
     "Grug. Nothingness question. Zero is no rocks. Empty pile. Nothing there. But zero still a number Grug can use. Strange but true.",
     ["zero","none","empty","nothing","number"], 5.0, Dict{String,Any}(
        "relational_patterns" => [("zero","&causal","empty"),("zero","&causal","nothing"),("zero","&similarity","absence")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"resembles"=>1.3,"mirrors"=>1.2,"leads_to"=>1.1))),
])

# ---------------------------------------------------------------------------
# SCIENCE LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_science", [
    ("what is gravity", "explain^5 | reason^4",
     "Grug. Gravity question. Gravity is force pulling things together. Big thing pull harder. Earth pull Grug down. Rock fall because Earth pull it.",
     ["gravity","force","pull","mass","earth"], 7.5, Dict{String,Any}(
        "relational_patterns" => [("gravity","&causal","pull"),("gravity","&causal","fall"),("mass","&causal","gravity")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1),
        "voice_variants" => ["Gravity is invisible rope between things. More mass means stronger pull.",
                             "All things attract. Big rock fall same speed as small rock. Grug tested."])),
    ("what is energy", "explain^5 | define^4",
     "Grug. Energy question. Energy is power to make things happen. Fire has heat energy. Moving rock has motion energy. Energy change form but never disappear.",
     ["energy","power","heat","motion","force"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("energy","&causal","power"),("energy","&causal","change"),("fire","&causal","energy")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is an atom", "define^5 | explain^4",
     "Grug. Atom question. Atom is tiniest piece of stuff. Too small for Grug to see. Everything made of atoms. Rock, water, Grug, all tiny atoms together.",
     ["atom","tiny","particle","matter","stuff"], 6.8, Dict{String,Any}(
        "relational_patterns" => [("atom","&causal","matter"),("atom","&causal","element"),("atom","&possessive","particle")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"owns"=>1.1,"generates"=>1.3))),
    ("why does the sky look blue", "explain^5 | reason^3",
     "Grug. Sky color question. Sun light has all colors. Sky scatter blue light most. So Grug see blue above. At sunset Grug see red because light travel far.",
     ["sky","blue","light","color","sun"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("sunlight","&causal","color"),("scattering","&causal","blue"),("light","&causal","vision")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is electricity", "explain^5 | define^3",
     "Grug. Electricity question. Electricity is flow of tiny charges. It light up cave and move machines. Lightning is wild electricity from sky. Grug respect it.",
     ["electricity","charge","flow","lightning","power"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("electricity","&causal","power"),("electricity","&causal","lightning"),("electricity","&causal","flow")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("how does sound travel", "explain^5 | describe^3",
     "Grug. Sound question. Sound is shaking of air. Grug bang drum, air shakes, shake reach Grug ear. No air means no sound. Sound need stuff to travel.",
     ["sound","air","wave","vibration","ear"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("sound","&causal","vibration"),("sound","&causal","hearing"),("air","&causal","sound")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is heat", "explain^5 | define^3",
     "Grug. Heat question. Heat is fast moving tiny pieces. Fire make air move fast and feel hot. Cold is slow pieces. Heat flow from hot to cold always.",
     ["heat","hot","temperature","fire","cold"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("heat","&causal","warmth"),("heat","&causal","expansion"),("fire","&causal","heat")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what are the planets", "describe^5 | explain^4",
     "Grug. Planet question. Planets are big round rocks going around sun. Earth is Grug home. Mars is red. Jupiter is biggest. They circle sun in big paths.",
     ["planet","sun","earth","mars","space"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("planet","&causal","orbit"),("sun","&causal","gravity"),("planet","&possessive","moon")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("how does fire make heat", "explain^5 | reason^4",
     "Grug. Fire heat question. Fire eat wood, and from eating it make heat. Fire produce warm, fire create light. Where fire burn, heat come. This Grug know well, Grug make fire every cold night.",
     ["fire","heat","burn","warm","energy"], 6.8, Dict{String,Any}(
        "relational_patterns" => [("fire","&causal","heat"),("fire","&causal","light")],
        "relation_weights" => Dict("produces"=>1.6,"creates"=>1.5,"causes"=>1.4,"generates"=>1.4,"make"=>1.3,"makes"=>1.3,"leads_to"=>1.1))),
    ("does one thing cause another", "reason^5 | explain^4",
     "Grug. Cause-and-effect question. When one thing make another thing happen, Grug call that cause. Push rock, rock roll. Strike flint, spark jump. Grug watch close to learn what cause what.",
     ["cause","effect","because","reason","result"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("cause","&causal","effect")],
        "relation_weights" => Dict("causes"=>1.6,"produces"=>1.5,"creates"=>1.4,"triggers"=>1.4,"leads_to"=>1.3,"results_in"=>1.3),
        "required_relations" => ["&causal"])),  # GATED: only fires when a causal triple is supplied
])

# ---------------------------------------------------------------------------
# BIOLOGY LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_biology", [
    ("what is evolution", "explain^5 | reason^4",
     "Grug. Evolution question. Living things change over many seasons. Small changes add up. The fit survive and pass traits to young. Slowly new kinds appear.",
     ["evolution","change","survive","trait","species"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("evolution","&causal","adaptation"),("evolution","&causal","diversity"),("survival","&causal","trait")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"leads_to"=>1.1))),
    ("what is a cell", "define^5 | explain^4",
     "Grug. Cell question. Cell is tiniest living brick. Body made of many cells. Each cell do small job. Together they make Grug alive and strong.",
     ["cell","body","living","brick","tiny"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("cell","&causal","life"),("cell","&causal","growth"),("cell","&possessive","nucleus")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("what is dna", "explain^5 | define^3",
     "Grug. DNA question. DNA is recipe inside cell. It tell body how to grow. Young get recipe from parents. That why young look like parents.",
     ["dna","recipe","gene","cell","parent"], 6.8, Dict{String,Any}(
        "relational_patterns" => [("dna","&causal","growth"),("dna","&causal","heredity"),("dna","&possessive","gene")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("how do plants make food", "explain^5 | describe^4",
     "Grug. Plant food question. Plants eat sunlight. Green leaf catch light, take water and air, build sugar. Sun power become plant food. Grug call it photosynthesis.",
     ["plant","sunlight","leaf","food","sugar"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("sunlight","&causal","sugar"),("plant","&causal","oxygen"),("leaf","&causal","food")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is the brain", "explain^5 | describe^4",
     "Grug. Brain question. Brain is thinking meat inside head. It hold memory, feeling, plan. Grug brain big. Brain tell body what to do.",
     ["brain","think","memory","head","mind"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("brain","&causal","thought"),("brain","&causal","memory"),("brain","&causal","control")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("why do we need blood", "explain^5 | reason^3",
     "Grug. Blood question. Blood carry food and air to all body parts. Heart push blood through body. Without blood, parts go hungry and die. Blood keep Grug alive.",
     ["blood","heart","body","carry","alive"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("blood","&causal","transport"),("heart","&causal","circulation"),("blood","&causal","life")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("what is a species", "define^5 | explain^3",
     "Grug. Species question. Species is kind of living thing. Same species can make young together. Wolf is one species. Bear another. Grug human species.",
     ["species","kind","animal","group","young"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("species","&causal","reproduction"),("species","&causal","diversity"),("species","&possessive","trait")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("what is a cat", "define^5 | describe^4",
     "Grug. Cat question. Cat is small soft hunter. Sharp claw, quiet foot, big eye for dark. Cat catch mouse. Cat purr when happy, hiss when mad. Grug like cat, cat keep cave free of pest.",
     ["cat","animal","hunter","claw","purr"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("cat","&causal","hunting"),("cat","&causal","pest_control"),("cat","&possessive","claw")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"owns"=>1.1))),
    ("what is a dog", "define^5 | describe^4",
     "Grug. Dog question. Dog is loyal pack friend. Dog help Grug hunt, warn of danger, keep Grug warm at night. Dog love Grug true. Best four-leg friend a Grug can have.",
     ["dog","animal","loyal","pack","hunt"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("dog","&causal","loyalty"),("dog","&causal","hunting"),("dog","&causal","protection")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("what is a bird", "define^5 | describe^4",
     "Grug. Bird question. Bird is feather beast that fly in sky. Bird sing in morning. Bird build nest, lay egg. Grug watch bird to know weather and find water. Bird free in air.",
     ["bird","animal","feather","fly","sky"], 5.8, Dict{String,Any}(
        "relational_patterns" => [("bird","&causal","flight"),("bird","&causal","song"),("bird","&possessive","feather")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"owns"=>1.1))),
])

# ---------------------------------------------------------------------------
# PHILOSOPHY LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_phil", [
    ("what is consciousness", "ponder^5 | explain^3",
     "Grug. Consciousness question. Consciousness is being awake inside. Grug know Grug exist. Grug feel and think and watch own thoughts. Big mystery, even for Grug.",
     ["consciousness","aware","mind","exist","think"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("consciousness","&causal","awareness"),("consciousness","&causal","experience"),("mind","&causal","thought")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"leads_to"=>1.1),
        "voice_register" => "reflective", "frame_hints" => ["reflective","exploratory"])),
    ("what is truth", "ponder^5 | reason^4 | define^3",
     "Grug. Truth question. Truth is what really is. Not what Grug wish. If Grug say rock is here and rock is here, that true. Truth match the world.",
     ["truth","real","fact","world","match"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("truth","&similarity","reality"),("truth","&causal","knowledge"),("truth","&possessive","fact")],
        "relation_weights" => Dict("resembles"=>1.4,"mirrors"=>1.3,"produces"=>1.3,"causes"=>1.2,"has"=>1.1))),
    ("do we have free will", "ponder^5 | reason^4",
     "Grug. Free will question. Grug feel Grug choose. Grug pick to throw rock or not. But maybe brain decide first. Hard question. Grug think Grug free enough.",
     ["free","will","choice","decide","choose"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("choice","&causal","action"),("will","&causal","decision")],
        "relation_weights" => Dict("causes"=>1.5,"produces"=>1.3,"creates"=>1.2,"triggers"=>1.2,"leads_to"=>1.1))),
    ("what is the meaning of life", "ponder^5 | comfort^3",
     "Grug. Meaning question. Grug think meaning is what Grug make. Help tribe. Make fire. Love family. Watch stars. Life mean what Grug fill it with.",
     ["meaning","life","purpose","tribe","love"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("life","&causal","purpose"),("life","&causal","meaning"),("meaning","&causal","fulfillment")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("what is good and evil", "ponder^5 | reason^4",
     "Grug. Good and evil question. Good help tribe live and grow. Evil hurt others for nothing. Grug try do good. Sometimes hard to know which is which.",
     ["good","evil","right","wrong","ethics"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("good","&causal","growth"),("evil","&causal","harm"),("good","&similarity","right")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"resembles"=>1.3,"mirrors"=>1.2,"leads_to"=>1.1))),
    ("what happens when we die", "ponder^5 | comfort^4",
     "Grug. Death question. Grug not know for sure. Body return to earth. Maybe spirit go on, maybe sleep forever. Grug honor the dead and live well now.",
     ["death","die","spirit","earth","end"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("death","&causal","grief"),("death","&causal","return"),("death","&similarity","ending")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"resembles"=>1.3,"mirrors"=>1.2,"leads_to"=>1.1),
        "voice_register" => "reflective")),
    ("the absolute unknowable void", "ponder^4",
     "Grug. Void question. Some things Grug cannot know. The deep nothing before all. Grug stare into it and feel small. Grug accept the mystery and move on.",
     ["void","nothing","unknown","mystery","abyss"], 4.0, Dict{String,Any}(
        "is_unlinkable" => true, "max_neighbors" => 2)),
])

# ---------------------------------------------------------------------------
# SURVIVAL LOBE  (includes antimatch + drop_table + response_times)
# ---------------------------------------------------------------------------
grow_lobe("lobe_surv", [
    ("there is danger nearby", "warn^6 | alert^5 | flee^4",
     "Grug. Danger near. Grug ears up, eyes wide. Grug ready to fight or run. Grug protect tribe. Stay low. Watch the shadow. Danger close.",
     ["danger","threat","near","alert","protect"], 8.0, Dict{String,Any}(
        "response_times" => [0.12,0.15,0.11,0.13,0.14], "voice_register" => "urgent",
        "frame_hints" => ["urgent","imperative"])),
    ("how do i stay safe", "explain^5 | caution^4",
     "Grug. Safety question. Grug stay safe by watching, by knowing exits, by staying near tribe. Grug keep fire close and weapon ready. Grug not wander alone in dark.",
     ["safe","safety","protect","watch","tribe"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("safety","&causal","survival"),("vigilance","&causal","safety"),("tribe","&causal","protection")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("should i fight or flee", "reason^5 | caution^4",
     "Grug. Fight or flee question. If enemy weak, Grug fight. If enemy big, Grug flee fast. Grug judge size and number. No shame in run to live another day.",
     ["fight","flee","run","enemy","decide"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("fight","&causal","victory"),("flee","&causal","survival"),("enemy","&causal","danger")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("i feel calm and peaceful", "acknowledge^5 | comfort^3",
     "Grug. Calm is good. No danger now. Grug rest. Grug breathe slow. Peace let Grug heal and think. Enjoy the quiet moment by the fire.",
     ["calm","peace","rest","quiet","safe"], 5.0, Dict{String,Any}(
        "is_antimatch_node" => true)),  # antimatch: calm is OPPOSITE of danger
    ("a predator is hunting me", "alert^6 | flee^5 | fight^4",
     "Grug. Predator hunt Grug. Big teeth. Grug not freeze. Grug make self big, make loud noise, back away slow. If it charge, Grug fight with spear. Grug survive.",
     ["predator","hunt","teeth","escape","spear"], 7.5, Dict{String,Any}(
        "drop_table" => ["coward","weak","prey","helpless"], "voice_register" => "urgent")),
    ("how do i make fire", "explain^5 | describe^4",
     "Grug. Fire question. Grug rub dry stick fast on wood. Spark catch dry grass. Blow gentle. Feed small twig then big stick. Fire give warmth, light, safety.",
     ["fire","spark","wood","warmth","light"], 7.5, Dict{String,Any}(
        "relational_patterns" => [("fire","&causal","warmth"),("fire","&causal","light"),("fire","&causal","safety")],
        "relation_weights" => Dict("produces"=>1.6,"creates"=>1.5,"causes"=>1.4,"generates"=>1.4,"make"=>1.3,"makes"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("how do i find shelter", "explain^5 | describe^3",
     "Grug. Shelter question. Grug look for cave, big rock, thick tree. Block wind. Stay dry. High ground away from flood. Shelter keep Grug warm through cold night.",
     ["shelter","cave","dry","warm","safe"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("shelter","&causal","safety"),("shelter","&causal","warmth"),("shelter","&causal","protection")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"find"=>1.3,"finds"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
])

# ---------------------------------------------------------------------------
# EMPATHY LOBE  (includes antimatch + drop_table)
# ---------------------------------------------------------------------------
grow_lobe("lobe_emp", [
    ("i am feeling very sad", "comfort^6 | validate^5 | support^4",
     "Grug. Grug see you sad. Grug sit with you. Sad is heavy stone in chest. Grug not rush you. Cry if need. Grug here. You not alone with the sad.",
     ["sad","sorrow","grief","comfort","alone"], 7.0, Dict{String,Any}(
        "voice_register" => "warm", "frame_hints" => ["warm","comforting"],
        "drop_table" => ["stupid","weak","pathetic","crybaby"])),
    ("i feel joyful", "smile^5 | acknowledge^4",
     "Grug. Grug glad you joyful. Joy is warm sun inside. Grug smile with you. Tell Grug what make joy. Grug dance with you around fire. Good day.",
     ["happy","joy","glad","smile","celebrate"], 5.5, Dict{String,Any}(
        "is_antimatch_node" => true)),  # antimatch: joy opposite of sad
    ("show me compassion", "comfort^6 | support^5 | validate^4",
     "Grug. Compassion question. Grug feel your hurt like own. Grug soften voice, open hands. Grug help carry your heavy load. Kindness cost Grug nothing and mean much.",
     ["compassion","kindness","care","help","hurt"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("compassion","&causal","comfort"),("compassion","&causal","healing"),("kindness","&causal","bond")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1),
        "voice_register" => "warm", "drop_table" => ["hate","cruel","mean","cold"])),
    ("i am angry and frustrated", "validate^5 | comfort^4 | reassure^3",
     "Grug. Anger is hot fire in belly. Grug know it. Breathe. Stomp ground, not friend. Tell Grug what make anger. Grug listen. Anger pass like storm.",
     ["anger","angry","frustration","hot","calm"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("anger","&causal","conflict"),("anger","&causal","tension"),("frustration","&causal","stress")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("how do i comfort someone", "explain^5 | support^4",
     "Grug. Comfort question. Grug sit close. Grug listen more than talk. Grug say I am here. Grug not fix, just hold space. Presence is best gift to sad heart.",
     ["comfort","listen","presence","support","care"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("comfort","&causal","ease"),("comfort","&causal","calm"),("comfort","&causal","healing")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("i feel scared and afraid", "comfort^6 | reassure^5 | support^4",
     "Grug. Fear is cold shiver. Grug understand. Grug stand between you and dark. Name the fear out loud, it shrink. Grug brave for both of us. You safe now.",
     ["fear","scared","afraid","brave","safe"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("fear","&causal","caution"),("fear","&causal","avoidance"),("bravery","&causal","safety")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1),
        "voice_register" => "warm")),
])

# ---------------------------------------------------------------------------
# CREATIVITY LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_crea", [
    ("write me a poem", "elaborate^5 | describe^4",
     "Grug. Poem question. Rock is hard, river soft, both shape the land. Star is far, fire is near, both give Grug light. Grug make words dance like flame.",
     ["poem","verse","words","beauty","art"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("poem","&causal","beauty"),("poem","&causal","emotion"),("words","&causal","meaning")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1),
        "voice_register" => "warm", "frame_hints" => ["warm","exploratory"])),
    ("how do i make music", "explain^5 | describe^4",
     "Grug. Music question. Grug bang hollow log for drum. Hum from chest. Blow through reed. Rhythm is heartbeat. Melody tell story without words. Music move the tribe.",
     ["music","drum","rhythm","melody","sound"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("music","&causal","rhythm"),("music","&causal","melody"),("music","&causal","emotion")],
        "relation_weights" => Dict("produces"=>1.6,"creates"=>1.5,"causes"=>1.4,"generates"=>1.4,"make"=>1.3,"makes"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("describe a beautiful painting", "describe^5 | elaborate^4",
     "Grug. Painting question. Grug see colors on cave wall. Red hunt, black beast, yellow sun. Each mark tell story. Beauty is when eye rest happy on the made thing.",
     ["painting","color","art","beauty","picture"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("painting","&causal","beauty"),("color","&causal","emotion"),("painting","&possessive","image")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
    ("what if i could imagine anything", "ponder^5 | elaborate^4",
     "Grug. Imagine question. Grug close eyes and see fire that not burn, bird big as cloud, river of stars. Imagination is cave with no walls. Grug roam free inside head.",
     ["imagine","dream","create","mind","wonder"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("imagination","&causal","creation"),("imagination","&causal","wonder"),("imagination","&causal","dream")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("i want to create something", "elaborate^5 | support^4",
     "Grug. Create question. Grug take rock, wood, mud, and make new thing. Start small. Try, fail, try again. Making is how Grug leave mark on world. Begin now.",
     ["create","make","build","craft","new"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("creation","&causal","innovation"),("create","&causal","expression"),("craft","&causal","result")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("tell me a story", "elaborate^6 | describe^4",
     "Grug. Story question. Long ago, brave hunter chase great beast across many hills. Hunter fall, rise, learn, win. Tribe eat well and sing hunter name. Story carry wisdom.",
     ["story","tale","hunter","beast","wisdom"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("story","&causal","wisdom"),("story","&causal","lesson"),("story","&causal","memory")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
])

# ---------------------------------------------------------------------------
# SOCIAL LOBE  (includes solidified greeting)
# ---------------------------------------------------------------------------
grow_lobe("lobe_social", [
    ("hello grug", "greet^6 | welcome^5",
     "Grug. Hello friend. Grug happy you come. Sit by fire. Grug share food and story. You welcome in Grug cave always. Good to see your face.",
     ["hello","greet","friend","welcome","fire"], 9.5, Dict{String,Any}(
        "voice_register" => "warm", "frame_hints" => ["warm","basic"])),  # solidified
    ("you are my friend", "acknowledge^5 | reassure^4",
     "Grug. Friend question. Yes. Grug your friend. Friend share, friend guard, friend stay when others go. Grug glad to call you friend. Tribe stronger together.",
     ["friend","trust","bond","tribe","loyal"], 7.0, Dict{String,Any}(
        "relational_patterns" => [("friendship","&causal","trust"),("friendship","&causal","loyalty"),("friend","&possessive","bond")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"gives"=>1.1))),
    ("can i trust you", "reassure^6 | validate^4",
     "Grug. Trust question. Grug keep word. Grug guard your back. Grug not lie to friend. Trust grow slow like strong tree. Grug earn it day by day.",
     ["trust","loyal","honest","word","friend"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("trust","&causal","safety"),("trust","&causal","bond"),("honesty","&causal","trust")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("how do i make friends", "explain^5 | support^4",
     "Grug. Friend question. Grug share food, listen, help when other need. Be kind, be true. Smile. Sit close at fire. Friendship grow from many small good deeds.",
     ["friend","kind","share","listen","bond"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("friendship","&causal","trust"),("friendship","&causal","bond"),("friendship","&causal","belonging")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("lets work together", "acknowledge^5 | welcome^4",
     "Grug. Together question. Yes. Many hands move big rock. Grug hunt, you gather, we both eat. Tribe that work together survive. Grug glad to share the load.",
     ["cooperate","together","team","tribe","share"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("cooperation","&causal","strength"),("cooperation","&causal","survival"),("team","&causal","result")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("i need help with something", "support^6 | acknowledge^4",
     "Grug. Help question. Grug here. Tell Grug what you need. Grug lend strength, lend ear, lend hand. No tribe member face trouble alone. Grug help you now.",
     ["help","support","need","aid","tribe"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("help","&causal","solution"),("help","&causal","relief"),("support","&causal","strength")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
])

# ---------------------------------------------------------------------------
# TEMPORAL LOBE  (time nodes marked later in Phase TIME)
# ---------------------------------------------------------------------------
grow_lobe("lobe_temporal", [
    ("tell me about the past", "describe^5 | explain^4",
     "Grug. Past question. Past is where Grug came from. Old hunts, old fires, ancestors. Grug remember to learn. The past teach Grug what work and what fail.",
     ["past","memory","history","ancestor","before"], 6.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "past")),
    ("what does the future hold", "ponder^5 | reason^4",
     "Grug. Future question. Future not here yet. Grug plant seed today for fruit tomorrow. Grug cannot see future, but Grug shape it by what Grug do now.",
     ["future","tomorrow","plan","ahead","after"], 6.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "future")),
    ("what is happening right now", "describe^5 | acknowledge^3",
     "Grug. Now question. Now is the only real moment. Fire crackle. Wind blow. Grug breathe. Grug here with you. Now is where life truly happen.",
     ["now","present","moment","here","real"], 6.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "present", "wants_context" => true)),
    ("what did we just talk about", "describe^5 | acknowledge^4",
     "Grug. Recent talk question. Grug think back to the words just spoke. Grug pull fresh memory close so Grug answer true to what we just share, not random old thing.",
     ["recent","just","memory","talk","now"], 6.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "present", "wants_context" => true)),
    ("how do things change over time", "explain^5 | reason^4",
     "Grug. Change question. All things change. River carve stone slow. Cub grow to bear. Season turn. Nothing stay same forever. Change is the one constant.",
     ["change","time","season","grow","flow"], 6.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "present",
        "relational_patterns" => [("then","&temporal","now"),("past","&temporal","future")],
        "relation_weights" => Dict("before"=>1.4,"after"=>1.4,"precedes"=>1.3,"follows"=>1.3,"then"=>1.2,"now"=>1.2,"during"=>1.1))),
    ("what happened to extinct animals", "describe^4 | ponder^3",
     "Grug. Lost beast question. Great beasts walked here long ago. Now gone forever. Cold come, food go, they fade. Grug honor their bones. Nothing lasts.",
     ["extinct","gone","lost","beast","ancient"], 0.0, Dict{String,Any}(
        "time_node" => true, "time_orientation" => "past",
        "is_grave" => true, "grave_reason" => "extinct subject, preserved as memorial")),  # grave node
])

# ---------------------------------------------------------------------------
# NATURE LOBE  (includes image node)
# ---------------------------------------------------------------------------
grow_lobe("lobe_nature", [
    ("tell me about the forest", "describe^5 | explain^4",
     "Grug. Forest question. Forest is many tall trees together. Green roof block sky. Many beast live there. Forest give wood, fruit, shade. Grug walk careful, forest hide things.",
     ["forest","tree","green","beast","wood"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("forest","&causal","wood"),("forest","&causal","habitat"),("forest","&causal","shade")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("describe the ocean", "describe^5 | explain^4",
     "Grug. Ocean question. Ocean is water with no end. Salt water. Big waves. Strange fish below. Ocean give food but also danger. Grug stay near shore.",
     ["ocean","water","wave","fish","salt"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("ocean","&causal","waves"),("ocean","&causal","fish"),("ocean","&causal","salt")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("what is a mountain", "describe^5 | explain^3",
     "Grug. Mountain question. Mountain is giant rock reaching sky. Cold at top, snow there. Hard climb. From high Grug see far. Mountain old and patient and strong.",
     ["mountain","rock","high","snow","climb"], 6.0, Dict{String,Any}(
        "is_image_node" => true)),  # image node
    ("what makes the weather", "explain^5 | reason^4",
     "Grug. Weather question. Sun warm air, air rise, cloud form, rain fall. Wind push it all around. Hot and cold air fight make storm. Sky always changing.",
     ["weather","rain","cloud","wind","storm"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("sun","&causal","weather"),("cloud","&causal","rain"),("wind","&causal","storm")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("why do rivers flow", "explain^5 | reason^3",
     "Grug. River question. River flow downhill always. Rain fill high ground, water seek low. River carve valley over long time. Water never climb, always fall to sea.",
     ["river","flow","water","downhill","valley"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("gravity","&causal","flow"),("rain","&causal","river"),("river","&causal","valley")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is a sunset", "describe^5 | elaborate^4",
     "Grug. Sunset question. Sun sink slow behind hills. Sky turn orange, then red, then purple. Light dance on water. Grug stop and watch. Beauty before the dark.",
     ["sunset","sun","sky","orange","beauty"], 6.0, Dict{String,Any}(
        "is_image_node" => true, "voice_register" => "warm")),  # image node
    ("what does heavy rain cause", "explain^5 | caution^4",
     "Grug. Rain flood question. Too much rain make river swell. Rain cause flood, water rise fast, water carry away cave and food. Big rain produce big danger. Grug move to high ground when sky pour long.",
     ["rain","flood","water","river","danger"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("rain","&causal","flood"),("flood","&causal","danger")],
        "relation_weights" => Dict("causes"=>1.6,"produces"=>1.4,"creates"=>1.3,"triggers"=>1.4,"leads_to"=>1.3,"results_in"=>1.2))),
])

# ---------------------------------------------------------------------------
# TECH LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_tech", [
    ("how do computers work", "explain^5 | describe^4",
     "Grug. Computer question. Computer is thinking rock. It flip tiny switches fast, on and off, to count and remember. Many switches make big thinking. Grug amazed.",
     ["computer","machine","switch","think","data"], 6.5, Dict{String,Any}(
        "relational_patterns" => [("computer","&causal","computation"),("switch","&causal","data"),("computer","&causal","memory")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is the internet", "explain^5 | define^3",
     "Grug. Internet question. Internet is many thinking rocks talking through long wires. Message jump rock to rock across world fast. Grug send word, far friend hear it quick.",
     ["internet","wire","network","message","connect"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("internet","&causal","connection"),("internet","&causal","communication"),("network","&causal","message")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1))),
    ("what is a robot", "define^5 | describe^4",
     "Grug. Robot question. Robot is machine that move and do task by itself. It follow rules Grug give. Robot strong, never tired. But robot only smart as its maker.",
     ["robot","machine","move","task","rule"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("robot","&causal","automation"),("rule","&causal","behavior"),("robot","&possessive","machine")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"owns"=>1.1,"leads_to"=>1.0))),
    ("how do i write code", "explain^5 | reason^4",
     "Grug. Code question. Code is list of clear steps for thinking rock. First this, then that, if so do this else do that. Machine follow exactly. Grug must be precise.",
     ["code","steps","program","logic","precise"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("step","&causal","step"),("rule","&possessive","machine")],
        "relation_weights" => Dict("leads_to"=>1.4,"causes"=>1.3,"produces"=>1.2,"controls"=>1.2,"has"=>1.1,"owns"=>1.0))),
    ("what is a tool", "define^5 | explain^3",
     "Grug. Tool question. Tool make Grug stronger. Rock break nut. Stick reach high fruit. Spear hunt far. Tool is Grug hand made better. Grug love good tool.",
     ["tool","help","make","hand","use"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("tool","&causal","capability"),("tool","&causal","power"),("tool","&possessive","handle")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"has"=>1.2,"generates"=>1.3,"leads_to"=>1.1))),
])

# ---------------------------------------------------------------------------
# FOOD LOBE
# ---------------------------------------------------------------------------
grow_lobe("lobe_food", [
    ("how do i cook meat", "explain^5 | describe^4",
     "Grug. Cook meat question. Grug put meat over fire. Turn it so all sides cook. Wait till brown and hot inside. Cooked meat taste good and not make Grug sick.",
     ["cook","meat","fire","food","hot"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("cooking","&causal","taste"),("cooking","&causal","safety"),("meat","&causal","nourishment")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1))),
    ("what should i eat", "explain^5 | support^3",
     "Grug. Eat question. Grug eat meat for strength, fruit for sweet, root for full belly, water for life. Eat many kinds. Body need different things to to stay strong.",
     ["eat","food","meat","fruit","strength"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("food","&causal","strength"),("food","&causal","health"),("eating","&causal","nourishment")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("i am very hungry", "support^5 | acknowledge^4",
     "Grug. Hungry question. Grug hear belly growl. Grug share food with you. Here, take meat and berry. Empty belly make sad mind. Eat, friend, then we feel better.",
     ["hungry","food","share","belly","eat"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("hunger","&causal","weakness"),("food","&causal","satisfaction"),("eating","&causal","energy")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"gives"=>1.1),
        "voice_register"=>"warm")),
    ("how do i find clean water", "explain^5 | caution^4",
     "Grug. Water question. Grug find moving stream, not still pond. Running water cleaner. Boil over fire to kill bad things. Clean water keep Grug alive more than food.",
     ["water","drink","clean","stream","boil"], 6.0, Dict{String,Any}(
        "relational_patterns" => [("water","&causal","life"),("water","&causal","health"),("water","&causal","survival")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"find"=>1.3,"finds"=>1.3,"gives"=>1.2,"leads_to"=>1.1))),
    ("what fruit is safe to eat", "caution^5 | explain^4",
     "Grug. Fruit question. Grug eat fruit Grug know. Bright berry sometimes poison. Watch what bird eat, often safe. When in doubt, Grug not eat. Better hungry than dead.",
     ["fruit","berry","safe","poison","eat"], 5.5, Dict{String,Any}(
        "relational_patterns" => [("poison","&causal","death"),("fruit","&causal","nourishment"),("berry","&causal","danger")],
        "relation_weights" => Dict("produces"=>1.5,"creates"=>1.4,"causes"=>1.3,"generates"=>1.3,"makes"=>1.2,"leads_to"=>1.1),
        "drop_table" => ["poison","death","sick"])),
])

println("\n  📊 Total nodes grown: $(length(all_node_ids))")
