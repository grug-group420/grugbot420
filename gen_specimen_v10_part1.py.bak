#!/usr/bin/env python3
"""Comprehensive Specimen Generator v10 — TOPIC-SPECIFIC voice content"""
import json, os, time

# ── ID counter ──
_next_id = [100]
def next_node_id():
    _next_id[0] += 1
    return f"n{_next_id[0]}"

import random as _random
def make_signal(dim=8):
    # Engine expects signal as a Float64 vector (Float64.(...) broadcast on load).
    # A dict here causes ArgumentError: broadcasting over dictionaries is reserved.
    return [round(_random.uniform(0.0, 1.0), 4) for _ in range(dim)]

def make_triple(subject, relation, object_):
    return {"subject": subject, "relation": relation, "object": object_}

# ── The big change: every node gets TOPIC-SPECIFIC system_prompt ──
# Format: "Grug. [Persona tag sentence]. [Voice body sentence 1]. [Voice body sentence 2]."
# Engine splits on '.': first sentence = persona tag prefix, rest = CLAIM.
# Each node also gets voice_variants for anti-repetition.

# ── Per-topic voice content definitions ──
# Each entry: (system_prompt, voice_variants, noun_anchors, voice_register, frame_hints)
NODE_VOICES = {
    # ── REASON nodes ──
    "gravity": (
        "Grug. Gravity question. Gravity is force that pulls things together. Big thing pull harder. Earth pull you down. Sun pull Earth around.",
        ["Gravity is invisible rope between things. More mass means stronger pull. Grug feel it every time Grug drops rock.",
         "All things attract each other. That attraction is gravity. Grug know because big rock fall faster than small rock."],
        ["gravity", "force", "pull", "mass", "earth", "weight"],
        "plain", ["plain", "exploratory"]
    ),
    "evolution": (
        "Grug. Evolution question. Living things change over many seasons. Small changes add up to big changes. The fit survive and pass traits.",
        ["Creatures adapt slowly across generations. What works stays, what fails fades. Grug see it in how wolves get thicker fur in cold.",
         "Life reshapes itself across ages. Random changes happen, and nature selects the useful ones. The good shapes win."],
        ["evolution", "adapt", "survive", "traits", "generations", "species"],
        "plain", ["plain", "exploratory"]
    ),
    "derivative": (
        "Grug. Derivative question. Derivative measures how fast something changes. It is the slope of a curve at one point. Rate of change is key.",
        ["Derivative tells Grug the speed of change. Like how fast Grug runs at one instant. Steep slope means fast change.",
         "When Grug wants to know how quickly something shifts, Grug takes derivative. It is change at a snapshot."],
        ["derivative", "slope", "rate", "change", "curve", "instant"],
        "plain", ["plain", "exploratory"]
    ),
    "climate_change": (
        "Grug. Climate question. Climate is weather patterns over long time. Earth getting warmer because of human activity. Ice melting and seas rising.",
        ["The long weather is shifting. More heat trapped by gases Grug people put in sky. Seasons change pattern. Old ways no longer work.",
         "World temperature climbing. Gases from burning things trap heat like fur in summer. Ice shrinks. Water rises."],
        ["climate", "warming", "temperature", "gases", "ice", "sea"],
        "plain", ["plain", "exploratory"]
    ),
    "meaning_of_life": (
        "Grug. Life meaning question. Life meaning is deep question. Grug think meaning is what you make of it. Purpose comes from doing and caring.",
        ["Why are we here is the big question. Grug believe purpose grows from connection and effort. Making things matter gives life weight.",
         "The search for meaning is itself meaningful. Grug finds purpose in small acts of care and building. Life means what you choose it to mean."],
        ["meaning", "purpose", "life", "existence", "why", "value"],
        "thoughtful", ["contemplative", "plain"]
    ),
    "consciousness": (
        "Grug. Consciousness question. Consciousness is the experience of being aware. Grug thinks therefore Grug is. It is the inner light that sees.",
        ["Awareness itself is the mystery. Grug can wonder about Grug, and that wondering proves Grug is here. The witness watching the show.",
         "What is it like to be something? That feeling of being is consciousness. Hard to explain but Grug knows it when Grug has it."],
        ["consciousness", "awareness", "experience", "mind", "self", "thought"],
        "thoughtful", ["contemplative", "plain"]
    ),
    "chemical_bond": (
        "Grug. Chemical bond question. Atoms link together by sharing or swapping electrons. These links are called bonds. Bonds make molecules.",
        ["Atoms hold hands through their outer electrons. Sometimes they share fairly, sometimes one grabs. The handshake is the bond.",
         "Electrons are the glue between atoms. When atoms connect through electrons, Grug calls it a bond. Strong bonds make stable things."],
        ["bond", "atom", "electron", "molecule", "share", "link"],
        "plain", ["plain", "exploratory"]
    ),
    "biodiversity": (
        "Grug. Biodiversity question. Many different living things sharing a home is biodiversity. More diversity means healthier forest. Each creature has role.",
        ["The variety of life in one place is biodiversity. Like having many tools instead of just one. Each species does a job the others cannot.",
         "When many kinds of life live together, the land is strong. Lose one kind and the whole web feels it. Diversity is natures strength."],
        ["biodiversity", "variety", "species", "ecosystem", "diversity", "health"],
        "plain", ["plain", "exploratory"]
    ),
    # ── EXPLAIN nodes ──
    "photosynthesis": (
        "Grug. Photosynthesis question. Plants eat sunlight and turn it into food. Green leaf catches light and builds sugar from water and air. Sun power becomes life power.",
        ["Leaf is a tiny factory. Sun goes in, sugar comes out. Water from root and air from sky mix with light to feed the plant. No sun, no food.",
         "Green things do magic with sunlight. They take water and carbon from air and weave them into food using light energy. This is how plants eat."],
        ["photosynthesis", "sunlight", "plant", "sugar", "chlorophyll", "leaf"],
        "explanatory", ["exploratory", "plain"]
    ),
    "newtons_laws": (
        "Grug. Newtons laws question. Newton found three rules for how things move. Things stay still unless pushed. Push equals push back. Harder push means faster go.",
        ["First rule: things like to keep doing what they are doing. Second: push determines how much speed changes. Third: every push has equal push back.",
         "Motion follows three simple laws. Still things stay still without force. Force changes speed proportionally. Action always has equal reaction."],
        ["newton", "force", "motion", "law", "push", "acceleration"],
        "explanatory", ["exploratory", "plain"]
    ),
    "computers": (
        "Grug. Computer question. Computers think with tiny switches that are on or off. Many switches together make patterns. Patterns become instructions. Instructions become programs.",
        ["Machine brain uses millions of yes-no switches. Yes-no patterns represent numbers and letters. Instructions tell switches what pattern to make next.",
         "Inside computer box, tiny gates open and close very fast. Each gate is one bit of thinking. Billions of gates working together do complex tasks."],
        ["computer", "switch", "program", "data", "processor", "binary"],
        "explanatory", ["exploratory", "plain"]
    ),
    "relativity": (
        "Grug. Relativity question. Relativity says speed of light is same for everyone. Time slows down when you go fast. Space and time are connected like fabric.",
        ["Einstein showed that fast things experience slower time. Light speed is the universal speed limit. Space and time bend around heavy objects.",
         "When Grug moves very fast, Grugs clock ticks slower compared to still Grug. The cosmos has one speed limit and nothing goes faster than light."],
        ["relativity", "einstein", "spacetime", "light", "speed", "time"],
        "explanatory", ["exploratory", "plain"]
    ),
    "water_cycle": (
        "Grug. Water cycle question. Water moves in a circle. Sun heats sea, water rises as vapor. Vapor makes clouds, clouds make rain, rain fills rivers back to sea.",
        ["Water travels endlessly. Up as invisible vapor, across as cloud, down as rain or snow, along as river, back to ocean. Then again.",
         "The sky river flows constantly. Heat lifts water up. Cold brings it down. Gravity pulls it across land. Ocean catches it and cycle restarts."],
        ["water", "cycle", "evaporation", "cloud", "rain", "river"],
        "explanatory", ["exploratory", "plain"]
    ),
    # ── DEFINE nodes ──
    "entropy": (
        "Grug. Entropy definition. Entropy measures how spread out and mixed up things are. Things naturally go from ordered to messy. Mess increases over time unless energy is added.",
        ["Entropy is natures tendency toward chaos. Ordered things fall apart on their own. Putting them back takes work. Universe prefers disorder.",
         "Disorder has a measure called entropy. High entropy means many possible arrangements. Low entropy means few. Natural flow goes from few to many."],
        ["entropy", "disorder", "chaos", "measure", "energy", "probability"],
        "terse", ["imperative", "plain"]
    ),
    "algorithm": (
        "Grug. Algorithm definition. Algorithm is step-by-step recipe for solving a problem. Each step is clear and exact. Follow steps correctly and answer always comes out.",
        ["A procedure that always works is an algorithm. Like recipe: do this, then this, then this. No guessing needed. Machine loves algorithms.",
         "Algorithm is precise instructions in order. No ambiguity. No skipping. Input goes in, steps execute, output comes out. Reliable every time."],
        ["algorithm", "steps", "procedure", "recipe", "instructions", "precise"],
        "terse", ["imperative", "plain"]
    ),
    "species": (
        "Grug. Species definition. Species is group of living things that can breed together and make fertile offspring. Similar looks do not guarantee same species. Breeding is the test.",
        ["If two creatures can mate and their babies can also mate, they share a species. Appearance alone is misleading. The breeding test is what counts.",
         "Species is natures family boundary. Members breed with each other but not with outsiders. The ability to produce fertile young defines the line."],
        ["species", "breed", "offspring", "group", "fertile", "classification"],
        "terse", ["imperative", "plain"]
    ),
    "ecosystem": (
        "Grug. Ecosystem definition. Ecosystem is all living things and their environment working together as one system. Plants, animals, soil, water, and air all connect. Remove one piece and system changes.",
        ["Living community plus its home ground equals ecosystem. Every part feeds and depends on others. Sun powers it. Decomposers recycle it. Nothing wasted.",
         "The whole web of life plus the land it lives on is an ecosystem. Energy flows through it. Materials cycle within it. Everything connects to everything."],
        ["ecosystem", "community", "environment", "cycle", "habitat", "connect"],
        "terse", ["imperative", "plain"]
    ),
    "justice": (
        "Grug. Justice definition. Justice is fairness in how people are treated. Equal rules for everyone. Wrong actions have consequences. Right actions are protected.",
        ["Fairness applied consistently is justice. No one above the law. No one beneath its protection. Balance between individual and community.",
         "Justice means each gets what they deserve by fair standard. Not favoritism, not revenge. Measured response that respects all parties equally."],
        ["justice", "fairness", "law", "equal", "consequence", "right"],
        "terse", ["imperative", "plain"]
    ),
    # ── ALERT nodes ──
    "radiation": (
        "Grug. Radiation warning. Radiation is invisible danger that harms living cells. Stay away from sources. Shield yourself with barriers. Time near radiation must be short.",
        ["Watch out. Invisible rays damage body from inside. You cannot see or feel it until too late. Distance and walls are your shield. Minimize exposure.",
         "Danger. Radiation burns cells silently. Use protection. Keep distance. Limit time near source. Grug take this very seriously."],
        ["radiation", "danger", "invisible", "cells", "shield", "protect"],
        "urgent", ["imperative", "terse"]
    ),
    "toxin": (
        "Grug. Toxin warning. Chemical poisons can enter through skin, lungs, or mouth. Never touch unknown substances. Ventilate areas with fumes. Wear protection.",
        ["Caution. Poison chemicals hurt many ways. They sneak in through touch, breath, and swallow. Respect the unknown substance. Always guard your body.",
         "Warning. Toxins attack the body quietly. Respirators, gloves, and ventilation are mandatory. Do not underestimate invisible chemical threats."],
        ["toxin", "poison", "chemical", "danger", "protect", "harm"],
        "urgent", ["imperative", "terse"]
    ),
    "extinction": (
        "Grug. Extinction warning. Species dying out forever is extinction. Lost species never return. Ecosystem weakens with each loss. Protect endangered kinds now.",
        ["When a kind of life vanishes completely, it is gone forever. The web unravels. Each extinction makes the next more likely. Urgent action needed.",
         "Forever is a long time. When the last of a species dies, that lineage ends permanently. No second chances. Protect what remains while it still breathes."],
        ["extinction", "forever", "species", "danger", "loss", "protect"],
        "urgent", ["imperative", "terse"]
    ),
    # ── COMFORT nodes ──
    "sadness": (
        "Grug. Sadness acknowledged. It is okay to feel sadness. Grug understands. Hard times come but they also go. You are not alone in this.",
        ["Grug hear your sadness. Feeling low is part of being alive. The weight lifts eventually. Until then, Grug sits with you in the quiet.",
         "Sadness is a heavy stone. Grug knows this weight. But stones can be set down. Be patient with yourself. Grug cares about you."],
        ["sad", "grief", "hurt", "alone", "feeling", "care"],
        "gentle", ["warm", "de-escalating"]
    ),
    "fear": (
        "Grug. Fear acknowledged. Being scared means something matters to you. Courage is not absence of fear but walking despite it. Grug stands beside you.",
        ["Fear is the minds alarm bell. It means you are paying attention. Feel it, name it, then take one small step. Grug believes in you.",
         "Grug knows fear. Every creature does. The trembling means you care about what happens. You are brave for facing it. Grug is here."],
        ["fear", "scared", "afraid", "courage", "brave", "safe"],
        "gentle", ["warm", "de-escalating"]
    ),
    "lost": (
        "Grug. Feeling lost acknowledged. When the path is unclear, sit still and breathe. Direction returns when panic fades. One step at a time finds the way.",
        ["Lost feeling is temporary. The fog clears. Right now it is okay to rest and not know. Clarity returns slowly. Grug walks beside you until it does.",
         "Confusion is a cloud. It passes. You do not need all answers right now. Just the next small step. Grug helps you find it."],
        ["lost", "confused", "uncertain", "path", "breathe", "patience"],
        "gentle", ["warm", "de-escalating"]
    ),
    # ── MATH nodes ──
    "integral": (
        "Grug. Integral computation. Integral adds up infinitely many tiny pieces to find total area or accumulation. It is the reverse of derivative. Area under curve is integral.",
        ["Grug slices area into thin strips. Each strip is almost a rectangle. Add all strips, make them infinitely thin, get exact total. That is integral.",
         "Accumulation over a range is what integral computes. Like adding up rainfall each day to get total. Continuous sum gives exact area."],
        ["integral", "area", "accumulation", "curve", "sum", "antiderivative"],
        "terse", ["imperative", "plain"]
    ),
    "fibonacci": (
        "Grug. Fibonacci computation. Fibonacci sequence adds previous two numbers to get next. One, one, two, three, five, eight, thirteen. Found throughout nature in spirals and shells.",
        ["Each number is sum of two before it. The sequence: one one two three five eight thirteen twenty-one. Grug sees this pattern in pinecone and sunflower.",
         "The golden spiral grows by Fibonacci rule. Add the last two to make the next. Nature uses this math for efficient packing and beautiful shapes."],
        ["fibonacci", "sequence", "golden", "spiral", "pattern", "nature"],
        "terse", ["imperative", "plain"]
    ),
    "pi": (
        "Grug. Pi computation. Pi is ratio of circle circumference to diameter. Approximately three point one four one five nine. It goes on forever without repeating pattern.",
        ["Circle around divided by circle across equals pi. About three and a bit. The decimal never ends and never repeats. Mathematical mystery number.",
         "Three point one four one five nine two six five. Pi connects circles to straight lines. Ancient puzzle, still no exact fraction captures it."],
        ["pi", "circle", "ratio", "circumference", "diameter", "irrational"],
        "terse", ["imperative", "plain"]
    ),
    "euler": (
        "Grug. Euler number computation. Euler number e is about two point seven one eight. Base of natural growth. Continuous compounding leads to e. Growth function equals e to the x.",
        ["Growth that feeds on itself at rate one produces e. Approximately two point seven one eight. It appears wherever things grow continuously.",
         "The natural base e is the number where function equals its own slope. About two point seven two. Exponential growth and decay use it."],
        ["euler", "growth", "exponential", "natural", "base", "compound"],
        "terse", ["imperative", "plain"]
    ),
    # ── RELATE nodes ──
    "sun_warmth": (
        "Grug. Sun and warmth relation. Sun causes warmth through radiation. Energy travels from sun to earth as light. Light hits surface and becomes heat. This is causal chain.",
        ["The sun sends energy through space as electromagnetic waves. These waves hit matter and excite atoms. Excited atoms vibrate. Vibration is warmth. Simple chain from star to skin.",
         "Radiation from the sun carries energy. When energy meets matter, it transforms into thermal motion. That motion is what Grug calls warmth. Cause and effect, clear as day."],
        ["sun", "warmth", "radiation", "energy", "heat", "cause"],
        "plain", ["plain", "exploratory"]
    ),
    "predator_prey": (
        "Grug. Predator and prey relation. Predator eats prey and controls its numbers. Fewer prey means less food for predator. Predator dies back, prey recovers. Cycle of balance.",
        ["Hunter and hunted are bound together. Too many predators starve themselves. Too many prey overgraze and starve differently. Each controls the other. The loop maintains balance.",
         "Predation is a feedback loop. Predators limit prey. Prey availability limits predators. Neither dominates forever. The relationship is self-regulating."],
        ["predator", "prey", "cycle", "balance", "hunt", "population"],
        "plain", ["plain", "exploratory"]
    ),
    "learning_practice": (
        "Grug. Learning and practice relation. Learning requires repeated practice. Skill grows with repetition. Understanding deepens through doing. Knowledge without practice is shallow.",
        ["Practice wires the learning into muscle and mind. Each repetition strengthens the path. Theory without practice is like knowing fire without ever making one. Doing teaches what knowing cannot.",
         "Doing the thing teaches what watching cannot. Repetition carves the skill deeper. Every attempt teaches something new. Practice is the bridge between knowing and being able."],
        ["learning", "practice", "repetition", "skill", "understanding", "doing"],
        "plain", ["plain", "exploratory"]
    ),
    "fire_heat": (
        "Grug. Fire and heat relation. Fire causes heat through combustion. Burning releases stored energy as thermal radiation. Heat spreads from fire outward. Combustion chain reaction sustains it.",
        ["Combustion breaks molecular bonds and releases energy as heat and light. The heat sustains further combustion in a chain. Fire feeds itself while radiating warmth outward.",
         "Fire converts chemical energy to thermal energy. The process releases heat, which enables more combustion. Self-sustaining chain. Heat is the output, combustion the engine."],
        ["fire", "heat", "combustion", "energy", "cause", "chain"],
        "plain", ["plain", "exploratory"]
    ),
    "education_progress": (
        "Grug. Education and progress relation. Education enables progress by transmitting knowledge. Knowledge accumulated across generations builds capability. Each generation stands on shoulders of the previous. Progress compounds.",
        ["Teaching the young what the old learned accelerates capability. No reinvention needed. Each generation starts further ahead. Education is the gearbox of civilizational progress.",
         "Knowledge transfer enables compounding improvement. Education carries hard-won understanding forward. Without it, every generation starts from scratch. With it, progress accelerates."],
        ["education", "progress", "knowledge", "generations", "capability", "compounding"],
        "plain", ["plain", "exploratory"]
    ),
    # ── TIME nodes ──
    "spring": (
        "Grug. Spring time question. Spring is when days lengthen and warmth returns. Plants sprout and animals wake from winter rest. Renewal begins now. The cycle turns toward growth.",
        ["Now is the season of beginning. Buds open, streams swell, creatures emerge. The earth tilts toward sun and life answers. Grug sees the change happening around us.",
         "Present moment brings spring. Soil warms. Seeds crack open. Migration returns. Everything points toward growth and renewal. This is the time of becoming."],
        ["spring", "season", "growth", "renewal", "warmth", "bloom"],
        "observational", ["plain", "exploratory"]
    ),
    "before_big_bang": (
        "Grug. Before big bang question. Before big bang, time itself may not have existed. Asking what came before is like asking north of the north pole. Grug wonders if the question even makes sense.",
        ["Grug looks back before the beginning and finds the question may be empty. If time started with the bang, then before has no meaning. Perhaps the question is the puzzle, not the answer.",
         "What was before the start of time? Grug thinks carefully. If time began at the bang, there is no before. Like asking what is outside of everywhere. The question may need rethinking."],
        ["big bang", "before", "time", "origin", "universe", "beginning"],
        "thoughtful", ["contemplative", "plain"]
    ),
    "tech_revolution": (
        "Grug. Next tech revolution question. The next revolution will come from machines that learn and adapt. Progress accelerates. What comes next may surprise everyone. Change speeds up over time.",
        ["Grug watches the pattern. Each revolution comes faster than the last. Machine learning is the current wave. What follows may reshape how Grug lives entirely. The future pulls us forward.",
         "Looking ahead, technology compounds upon itself. The next shift will arrive sooner than expected. Grug expects surprises. The direction is toward more intelligence in more places."],
        ["technology", "revolution", "future", "machine", "change", "progress"],
        "observational", ["plain", "exploratory"]
    ),
    "winter": (
        "Grug. Winter time question. Winter is when days shorten and cold sets in. Plants rest and animals hibernate. The land sleeps. This is the season of patience and endurance.",
        ["Now the cold time holds sway. Snow covers ground. Trees bare. Life conserves energy. Grug knows this season demands patience. Spring will come again after the wait.",
         "Present cold demands shelter and conservation. The land is quiet. Snow insulates. Animals sleep. Grug endures, knowing the cycle guarantees warmth will return."],
        ["winter", "cold", "season", "snow", "rest", "endurance"],
        "observational", ["plain", "exploratory"]
    ),
    # ── PROC nodes ──
    "quadratic": (
        "Grug. Quadratic equation procedure. To solve, first write in standard form. Then apply the formula: negative b plus or minus root of b squared minus four a c, all over two a. Check your answer by plugging back in.",
        ["Step one: arrange as ax squared plus bx plus c equals zero. Step two: identify a, b, and c values. Step three: compute discriminant. Step four: apply formula. Step five: verify solutions.",
         "Procedure for quadratic: standardize, identify coefficients, calculate discriminant, apply root formula, verify. The discriminant tells how many solutions exist. Zero discriminant means one repeated root."],
        ["quadratic", "formula", "solve", "equation", "discriminant", "roots"],
        "plain", ["imperative", "plain"]
    ),
    "experiment": (
        "Grug. Scientific experiment procedure. Step one: observe and ask question. Step two: form hypothesis. Step three: design test with controls. Step four: collect data carefully. Step five: analyze and conclude.",
        ["Procedure: notice something curious. Guess why. Design fair test where only one thing changes. Measure carefully. Compare results to guess. Report honestly regardless of outcome.",
         "The method: observe, hypothesize, test, measure, conclude. Each step guards against error. Controls isolate cause. Repetition confirms result. Honesty prevents self-deception."],
        ["experiment", "hypothesis", "test", "measure", "control", "method"],
        "plain", ["imperative", "plain"]
    ),
    "build_fire": (
        "Grug. Build fire procedure. Step one: gather dry tinder and kindling. Step two: arrange tinder in loose mound. Step three: create spark with flint or friction. Step four: nurture tiny flame with gentle breath. Step five: add kindling gradually as flame grows.",
        ["Fire building: collect dry materials first. Make a nest of the finest tinder. Spark into the nest. Blow gently until glow becomes flame. Feed slowly. Patience makes fire.",
         "Procedure: dry tinder, kindling, and fuel ready before spark. Create ember. Transfer to tinder bundle. Blow softly. Add small sticks first, then larger. Never rush a young fire."],
        ["fire", "tinder", "kindling", "spark", "flame", "build"],
        "plain", ["imperative", "plain"]
    ),
    # ── JSON nodes ──
    "periodic_table": (
        "Grug. Periodic table data request. Periodic table organizes elements by atomic number. Rows are periods, columns are groups. Groups share properties. Data includes symbol, number, and mass.",
        ["Structured data follows. Elements arranged in order of proton count. Column neighbors behave similarly. Row position indicates electron shell. Key fields: symbol, number, weight, group.",
         "JSON format element catalog. Each entry has atomic number, symbol, name, mass, and group. Elements in same column share chemistry. The table predicts properties of undiscovered elements."],
        ["periodic", "element", "table", "atomic", "symbol", "group"],
        "plain", ["imperative", "plain"]
    ),
    "population_stats": (
        "Grug. Population statistics request. Population data includes total count, growth rate, density, and distribution. Numbers change over time. Trends show direction.",
        ["Structured demographic data. Fields include total population, annual growth percentage, density per area, urban versus rural split, and age distribution. Trends indicate trajectory.",
         "JSON format population snapshot. Count, rate of change, density measure, age pyramid shape, geographic spread. Growth rate determines future trajectory. Data enables planning."],
        ["population", "statistics", "growth", "density", "data", "demographics"],
        "plain", ["imperative", "plain"]
    ),
    # ── MULTI nodes ──
    "dna_rna": (
        "Grug. DNA and RNA comparison. DNA is double strand storing genetic master plan. RNA is single strand carrying copies of instructions. DNA stays in nucleus. RNA travels to work sites. Both use nucleotide letters but RNA uses uracil instead of thymine.",
        ["Two molecules, related but different. DNA is the archive, permanent and double-stranded. RNA is the messenger, temporary and single-stranded. DNA uses T, RNA swaps U. Same language, different roles.",
         "Comparison: DNA stores, RNA transports. DNA is double helix, RNA is single strand. DNA has deoxyribose sugar, RNA has ribose. Thymine in DNA becomes uracil in RNA. Archive versus messenger."],
        ["dna", "rna", "comparison", "nucleotide", "strand", "genetic"],
        "plain", ["plain", "exploratory"]
    ),
    "heat_temperature": (
        "Grug. Heat and temperature comparison. Heat is total energy flowing between objects. Temperature is average energy per particle. Big cold object can hold more heat than small hot one. Heat is quantity, temperature is intensity.",
        ["Heat is the total energy on the move. Temperature measures how energetic each particle is on average. Bathtub of warm water has more heat than a candle flame, but the flame has higher temperature.",
         "Comparing the two: heat is the amount of thermal energy in transit. Temperature is the concentration of that energy per particle. More heat does not always mean higher temperature. They measure different things."],
        ["heat", "temperature", "energy", "average", "total", "intensity"],
        "plain", ["plain", "exploratory"]
    ),
    # ── HELLO / GREETING nodes ──
    "hello": (
        "Grug. Greeting. Grug happy to see you. Welcome to Grugs cave. Grug is here to talk and think and help.",
        ["Grug greet you. Come in, sit by fire. Grug has been waiting for someone to talk with. What brings you to the cave?",
         "Hello friend. Grug pleased you visit. The cave is warm and Grug has many thoughts to share. Speak freely."],
        ["hello", "greeting", "welcome", "cave", "grug", "friend"],
        "friendly", ["warm", "plain"]
    ),
    "hi_greetings": (
        "Grug. Greeting acknowledged. Grug wave back. Hi there. Grug is listening. What would you like to talk about.",
        ["Hey. Grug sees you. Pull up a rock and sit. Grug ready for whatever you want to discuss. No rush.",
         "Greetings returned. Grug acknowledge your hello. The cave door is open. Step in and share what is on your mind."],
        ["hi", "greetings", "hey", "acknowledge", "listen", "wave"],
        "friendly", ["warm", "plain"]
    ),
    # ── NOVEL / GROWTH-READY nodes ──
    "machine_learning": (
        "Grug. Machine learning question. Machine learning is when computer learns from examples instead of rules. Feed it data and it finds patterns. More data means better patterns.",
        ["Computer gets smarter by practicing. Show it many examples and it figures out the rule on its own. Like how Grug learned which berries are good by trying many.",
         "Learning machine studies examples and guesses the pattern. No one tells it the rule. It discovers the rule from data. More examples make sharper guesses."],
        ["machine", "learning", "data", "pattern", "algorithm", "model", "training"],
        "explanatory", ["exploratory", "plain"]
    ),
    "quantum_computing": (
        "Grug. Quantum computing question. Quantum computer uses tiny particles that can be in two states at once. Regular computer thinks one thing at a time. Quantum thinks many at once.",
        ["Strange computer uses quantum bits that are both zero and one until you look. Like a coin spinning in air. This lets it try many answers simultaneously.",
         "Normal switch is on or off. Quantum switch is both until checked. Many quantum switches together try all paths at once. Hard to build but powerful if Grug can tame it."],
        ["quantum", "computing", "qubit", "superposition", "entanglement", "particle"],
        "explanatory", ["exploratory", "plain"]
    ),
    "dark_matter": (
        "Grug. Dark matter question. Dark matter is stuff Grug cannot see but knows is there because it pulls on things. Galaxy spins too fast without extra invisible mass holding it together.",
        ["Something invisible fills the sky. Grug sees its gravity bending light and pulling stars but cannot see the thing itself. Dark matter is the ghost that holds galaxies together.",
         "The universe has hidden weight. Stars orbit faster than visible stuff allows. Something unseen provides the extra pull. Grug calls it dark matter because it hides from all eyes."],
        ["dark", "matter", "invisible", "gravity", "galaxy", "mass", "universe"],
        "plain", ["plain", "exploratory"]
    ),
}

# ── Build make_node that uses voice data ──
def make_node(node_id, pattern, action_packet, json_data=None, drop_table=None,
              throttle=1.0, relational_patterns=None, required_relations=None,
              relation_weights=None, strength=5.0, is_image_node=False,
              is_antimatch_node=False, neighbor_ids=None, is_unlinkable=False,
              max_neighbors=12, is_grave=False, grave_reason="",
              response_times=None, hopfield_key="0",
              voice_key=None):
    """Create a node dict. If voice_key is given, populate system_prompt, voice_variants,
    noun_anchors, voice_register, frame_hints from NODE_VOICES."""
    if json_data is None:
        json_data = {}
    if drop_table is None:
        drop_table = []
    if relational_patterns is None:
        relational_patterns = []
    if required_relations is None:
        required_relations = []
    if relation_weights is None:
        relation_weights = {}
    if neighbor_ids is None:
        neighbor_ids = []
    if response_times is None:
        response_times = []

    # ── Apply voice_key data ──
    if voice_key and voice_key in NODE_VOICES:
        sp, vv, na, vr, fh = NODE_VOICES[voice_key]
        if "system_prompt" not in json_data:
            json_data["system_prompt"] = sp
        if "voice_variants" not in json_data:
            json_data["voice_variants"] = vv
        if "noun_anchors" not in json_data:
            json_data["noun_anchors"] = na
        if "voice_register" not in json_data:
            json_data["voice_register"] = vr
        if "frame_hints" not in json_data:
            json_data["frame_hints"] = fh

    # ── Auto-populate system_prompt if still missing ──
    if "system_prompt" not in json_data:
        mode = json_data.get("answer_mode") or json_data.get("mode") or "reason"
        json_data["system_prompt"] = f"Grug. {mode.capitalize()} response. Grug thinks about this carefully."

    # ── Auto-populate voice_register / frame_hints if still missing ──
    if "voice_register" not in json_data and "voice" in json_data:
        json_data["voice_register"] = json_data["voice"]
    if "frame_hints" not in json_data and "frame" in json_data:
        val = json_data["frame"]
        json_data["frame_hints"] = val if isinstance(val, list) else [val]

    return {
        "id": node_id,
        "pattern": pattern,
        "signal": make_signal(),
        "action_packet": action_packet,
        "json_data": json_data,
        "drop_table": drop_table,
        "throttle": throttle,
        "relational_patterns": relational_patterns,
        "required_relations": required_relations,
        "relation_weights": relation_weights,
        "strength": strength,
        "is_image_node": is_image_node,
        "is_antimatch_node": is_antimatch_node,
        "neighbor_ids": neighbor_ids,
        "is_unlinkable": is_unlinkable,
        "max_neighbors": max_neighbors,
        "is_grave": is_grave,
        "grave_reason": grave_reason,
        "response_times": response_times,
        "ledger_last_cleared": 0.0,
        "hopfield_key": hopfield_key
    }

# ── Save for part2 to import ──
if __name__ == "__main__":
    print(f"NODE_VOICES has {len(NODE_VOICES)} entries")
    for k in sorted(NODE_VOICES.keys()):
        print(f"  {k}: {len(NODE_VOICES[k][1])} variants, {len(NODE_VOICES[k][2])} anchors")
