# Thesaurus.jl - GRUG Dimensional thesaurus for words, concepts, and contexts
# GRUG say: words is words, but concepts is bigger ideas. This module compare them all.
# GRUG say: similarity not just one number, but many dimensions. Like looking at thing from different angles.
# GRUG say: NEW - seed synonym dictionary! happy/joyful, fast/quick. Structural gap bridged!
# GRUG say: NEW - gate filter! Give Grug input tokens, get back expanded set for better scan matching.

module Thesaurus
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
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


# ============================================================================
# CONSTANTS - GRUG like numbers in one place, easy to change later
# ============================================================================

const DEFAULT_SEMANTIC_WEIGHT    = 0.5
const DEFAULT_CONTEXTUAL_WEIGHT  = 0.3
const DEFAULT_ASSOCIATIVE_WEIGHT = 0.2
const DEFAULT_NGRAM_SIZE         = 3

# GRUG: Minimum similarity score for synonym lookup to count as a match.
# Below this threshold, structural similarity is too weak to assert synonymy.
const SYNONYM_SEED_THRESHOLD     = 0.70

# GRUG: Gate expansion max results per input token.
# Each input token can expand to at most this many synonyms.
# Prevents gate from exploding into huge token set for long inputs.
const GATE_MAX_EXPANSIONS_PER_TOKEN = 3

# ============================================================================
# ERROR TYPES - GRUG hate silent failures! Must know what went wrong
# ============================================================================

struct ThesaurusError <: Exception
    message::String
    context::String
end

function throw_thesaurus_error(msg::String, ctx::String = "unknown")
    throw(ThesaurusError(msg, ctx))
end

# ============================================================================
# RESULT STRUCTURE - GRUG want rich results, not just one number
# ============================================================================

struct ThesaurusResult
    overall::Float64
    semantic::Float64
    contextual::Float64
    associative::Float64
    match_type::String
    confidence::Float64
    details::Dict{String, Any}
end

# ============================================================================
# SEED SYNONYM DICTIONARY
# GRUG: ~200 common pairs where structure diverges but meaning matches.
# Covers the "happy vs joyful = 0.0" problem that pure trigrams cannot solve.
# Bidirectional: both directions stored at build time.
# Format: canonical -> Set of synonyms (all lowercase, stripped)
# ============================================================================

const _SEED_SYNONYMS_RAW = [
    # Emotions / mental states
    ("happy",       ["joyful", "glad", "pleased", "content", "cheerful", "delighted", "elated"]),
    ("sad",         ["unhappy", "sorrowful", "melancholy", "gloomy", "dejected", "downcast"]),
    ("angry",       ["mad", "furious", "irate", "enraged", "livid", "wrathful"]),
    # v8.26: "afraid" → "fearful"/"terrified"/"anxious"/"nervous"/"worried" are clinical.
    # Only "scared" is caveman-safe.
    ("afraid",      ["scared"]),
    ("tired",       ["weary", "fatigued", "exhausted", "sleepy", "drained"]),
    ("surprised",   ["shocked", "astonished", "amazed", "stunned", "startled"]),
    ("confused",    ["puzzled", "baffled", "perplexed", "bewildered", "lost"]),
    ("excited",     ["thrilled", "eager", "enthusiastic", "keen", "animated"]),
    ("calm",        ["peaceful", "serene", "tranquil", "relaxed", "composed"]),
    # v8.26: "brave" → "courageous"/"fearless"/"daring"/"heroic" are formal/literary.
    # Only "bold" is safe.
    ("brave",       ["bold"]),

    # Speed / size / degree
    ("fast",        ["quick", "rapid", "swift", "speedy", "hasty", "brisk"]),
    ("slow",        ["sluggish", "gradual", "leisurely", "unhurried", "plodding"]),
    ("big",         ["large", "huge", "enormous", "vast", "massive", "gigantic"]),
    ("small",       ["tiny", "little", "miniature", "minute", "compact", "petite"]),
    ("strong",      ["powerful", "mighty", "robust", "sturdy", "tough", "solid"]),
    ("weak",        ["feeble", "frail", "fragile", "delicate", "powerless"]),
    ("hard",        ["difficult", "tough", "challenging", "rough", "demanding"]),
    ("easy",        ["simple", "effortless", "straightforward", "trivial", "basic"]),
    ("hot",         ["warm", "scorching", "burning", "fiery", "boiling"]),
    ("cold",        ["cool", "freezing", "icy", "chilly", "frigid"]),

    # Actions / verbs
    # run removed — "Grug run it" → "Grug dash/sprint it" is wrong-domain for action voice
    ("run",         ["sprint", "dash", "jog", "race", "rush"]),
    ("walk",        ["stroll", "march", "stride", "wander", "trek"]),
    # v7.40: removed "see", "observe", "watch" (cross-links with see/watch entries cause
    # bidirectional explosion — "look" in voice_body swaps to entire see+watch cluster)
    # Also removed "inspect", "examine" (analytical, not perceptual)
    ("look",        ["view", "examine", "inspect"]),
    # talk/say/etc removed — "say" is core grug voice; swapping "say"→"converse"/"chat"
    # produces decoherent academic tone. Synonyms too formal for voice_body.
    ("talk",        ["speak", "say", "tell", "chat", "converse", "discuss"]),
    # think removed — "think" is core grug voice; "Grug sit and reason/contemplate" 
    # is academic decoherence. The voice should stay simple.
    ("think",       ["consider", "ponder", "reflect", "contemplate", "reason"]),
    # make removed — "make space" → "fashion space" is wrong-domain decoherence
    ("make",        ["create", "build", "craft", "fashion", "shape", "forge"]),
    # v7.40: removed "retrieve" (cross-link with load), "fetch" (cross-link with load)
    ("get",         ["obtain", "acquire", "gain"]),
    # v7.40: removed "bestow" (archaic — "Grug give" → "Grug bestow" is decoherent)
    # v8.26b: "grant" is wrong register ("Art is the grant" → should be "gift").
    # "provide"/"deliver" are formal. Trim to just "offer" and "hand".
    ("give",        ["offer", "hand"]),
    # v7.40: removed "detect" (techy), "identify" (formal), "uncover" (archaic in voice context)
    ("find",        ["discover", "locate"]),
    # v7.40: removed "utilize" (corporate jargon), "leverage" (business jargon),
    # "employ" (formal for grug voice)
    ("use",         ["apply", "operate"]),
    ("fix",         ["repair", "mend", "correct", "patch", "restore", "resolve"]),
    ("break",       ["shatter", "crack", "destroy", "damage", "ruin", "fracture"]),
    # v7.40: removed "commence" (overly formal), "embark" (nautical metaphor)
    ("start",       ["begin", "initiate", "launch"]),
    ("stop",        ["end", "halt", "cease", "finish", "quit"]),
    # v7.40: removed "facilitate" (corporate jargon)
    # v8.26: "help" → "assist" is formal, "support" OK, "aid" is formal, "serve" wrong meaning.
    ("help",        ["support"]),
    ("need",        ["require", "want", "demand", "lack", "desire"]),
    # v7.40: removed "demonstrate", "illustrate" (academic — "Grug show" → "Grug demonstrate" is formal)
    # v8.26: "show" → "display" wrong in "The display is all Grug has" (should be "present").
    # "reveal" is slightly elevated. Keep "present" only.
    ("show",            ["present"]),
    # know removed — "What Grug knows" → "What Grug comprehends" is academic decoherence
    ("know",        ["understand", "grasp", "comprehend", "recognize", "realize"]),
    # v7.40: removed "endeavor" (archaic/formal), "strive" (overly earnest for grug)
    ("try",         ["attempt", "test", "experiment"]),
    # v7.40: removed "relocate" (corporate), "migrate" (technical), "transport" (logistics)
    ("move",        ["shift", "transfer"]),

    # Common nouns
    # v7.40: removed "residence" (too formal), "building" (wrong-domain —
    # "shelter" in voice_body is survival concept, not real estate)
    ("house",       ["home", "dwelling", "shelter"]),
    ("car",         ["vehicle", "auto", "automobile", "ride", "truck"]),
    ("food",        ["meal", "dish", "cuisine", "nourishment", "sustenance"]),
    # water removed — "water" → "beverage"/"fluid" in voice_body is contextually wrong
    ("water",       ["liquid", "fluid", "drink", "beverage"]),
    ("money",       ["cash", "currency", "funds", "finance", "capital"]),
    # v8.26: "job" as VERB ("Grug brain job hard") swaps wrong. "career"/"occupation"/"profession"
    # are formal register. "employment" is bureaucratic. Only "work" is safe.
    ("job",             ["work"]),
    ("problem",     ["issue", "challenge", "difficulty", "obstacle", "trouble"]),
    # v7.40: removed "outcome", "output", "product" (wrong-domain — "answer" → "output/product"
    # is tech jargon decoherence in voice_body)
    ("answer",      ["response", "reply", "solution", "result"]),
    # v7.40: removed "thought" (bidirectional link: "idea"↔"thought" causes "Grug thought"
    # → "Grug concept/notion" and back-swaps "thought"→"proposal/plan" — wrong-domain for inner monologue)
    ("idea",        ["concept", "notion", "proposal", "plan"]),
    ("plan",        ["strategy", "scheme", "approach", "method", "design"]),
    ("error",       ["mistake", "fault", "bug", "flaw", "defect", "failure"]),
    ("data",        ["information", "info", "facts", "records", "stats"]),
    ("test",        ["check", "verify", "validate", "examine", "assess"]),
    ("system",      ["framework", "structure", "platform", "architecture"]),
    ("input",       ["query", "request", "prompt", "signal", "message"]),
    # v7.40: removed "answer" (cross-link with answer entry), "product" (wrong-domain —
    # "output" → "product" is manufacturing jargon), "reply" (cross-link with answer/reply)
    ("output",      ["result", "response"]),

    # Tech / AI adjacent
    ("learn",       ["train", "study", "adapt", "improve", "evolve"]),
    ("predict",     ["forecast", "estimate", "infer", "anticipate", "project"]),
    ("match",       ["fit", "align", "correspond", "map", "pair", "link"]),
    ("search",      ["scan", "query", "seek", "explore", "hunt", "probe"]),
    # v7.40: removed "couple" (wrong-domain romantic connotation), "associate" (academic)
    ("connect",     ["link", "join", "bind", "unite"]),
    ("store",       ["save", "cache", "record", "keep", "archive", "stash"]),
    # v7.40: removed "import" (ambiguous — "import" in programming ≠ "import" as significance),
    # "retrieve" (cross-link with receive entry)
    ("load",        ["read", "fetch", "open"]),
    # v7.40+8.26: removed "dispatch", "transmit", "route" (wrong-domain — "forward" in
    # voice_body is usually preposition "move forward", not verb "forward a message").
    # "push" also removed (wrong register — "send"→"push" in "push energy" is incoherent).
    # v8.26b: "forward"→"send" bidirectional produces "moving send" / "time flows send".
    # COMMENTED OUT — "send" should not swap at all.
    # ("send",        ["forward"]),
    # v7.40: removed "get" (cross-link with get entry — bidirectional explosion),
    # "collect" (cross-link with accumulate), "obtain" (cross-link with get),
    # "pull" (wrong-domain for "receive")
    ("receive",     ["accept"]),
    ("delete",      ["remove", "erase", "purge", "drop", "wipe"]),

    # Science domain — bridging lab/research vocabulary
    # v7.40: removed "conjecture", "postulate", "supposition" (academic science terms
    # that would decohere voice_body — "hypothesis" → "postulate" is wrong register)
    ("hypothesis",  ["theory", "assumption"]),
    # v7.41: removed "investigation", "procedure" (bureaucratic — "Grug experiment" →
    # "Grug investigation/procedure" is wrong register)
    ("experiment",  ["test", "trial", "study"]),
    ("observe",     ["measure", "detect", "monitor", "record", "track"]),
    ("analyze",     ["examine", "study", "evaluate", "assess", "investigate"]),
    ("energy",      ["power", "force", "vigor", "vitality", "stamina"]),
    ("matter",      ["substance", "material", "mass", "stuff", "element"]),
    ("evolve",      ["develop", "adapt", "change", "mutate", "transform", "progress"]),
    ("cause",       ["trigger", "produce", "generate", "induce"]),
    # v7.40: removed "outcome" (cross-link with answer), "product" (cross-link with output),
    # "consequence" (formal/negative connotation)
    ("effect",      ["result", "impact"]),
    ("measure",     ["quantify", "gauge", "assess", "calculate", "evaluate"]),

    # Philosophy domain — bridging abstract reasoning vocabulary
    # v7.40: removed "verity" (archaic/academic — "Grug truth" → "Grug verity" is decoherent)
    ("truth",       ["certainty", "reality"]),
    # v7.40: removed "data", "information", "intelligence", "signal" (wrong-domain —
    # "knowledge" → "data/signal" is tech jargon; "intelligence" is military jargon)
    ("knowledge",   ["insight", "wisdom", "awareness"]),
    # v7.41: removed "conviction" (legal/formal), "stance" (debate jargon),
    # "position" (bureaucratic) — "Grug belief" → "Grug conviction/stance" is wrong register
    ("belief",      ["opinion", "view", "faith"]),
    # v7.41: removed "rationale" (academic/corporate), "deduction" (academic logic),
    # "inference" (academic logic) — "Cold rationale" / "Grug inference" decoheres voice
    ("logic",       ["reasoning", "argument"]),
    # v7.40: removed "subsist" (archaic — "Grug exist" → "Grug subsist" is decoherent)
    ("exist",       ["live", "occur", "remain", "survive"]),
    # v7.40: removed "cognition" (academic), "sentience" (philosophical jargon),
    # "mindfulness" (buzzword). "consciousness" → "sentience" in voice_body is wrong register.
    ("consciousness", ["awareness", "perception"]),
    # v7.41: removed "principled", "virtuous", "honorable", "upright" (moralistic/elevated —
    # "Grug ethical" → "Grug virtuous/upright" is sermon register, not grug voice)
    ("ethical",     ["moral"]),
    # v7.41: removed "conceptual", "hypothetical" (both academic — no safe synonyms remain)
    # ("abstract",    ["conceptual", "hypothetical"]),
    # v7.40: removed "contend", "assert" (formal/legal — "Grug argue" → "Grug contend/assert"
    # is wrong register for grug voice)
    ("argue",       ["debate", "claim"]),
    # v7.40: removed "interrogate" (too formal — "Grug question" → "Grug interrogate" is decoherent)
    # v7.41: removed "inquiry" (formal/bureaucratic — "Grug question" → "Grug inquiry" is wrong register)
    ("question",    ["query", "challenge", "doubt", "probe"]),

    # ========================================================================
    # GRUG v7.38: DOMAIN EXPANSION — math, survival, emotion, creativity,
    # philosophy, cognition. These are the words that appear in specimen
    # system_prompts but had NO thesaurus entries, making every run produce
    # identical output. Each entry gives the swap engine rich alternatives.
    # ========================================================================

    # Math / calculus / science domain
    # v7.40: removed "derive" (academic math term), "reckon" (archaic/dialect)
    ("compute",         ["calculate", "determine", "figure", "tally"]),
    # v7.40: removed multi-word synonyms that garble voice_body
    # v7.41: removed "differential", "marginal" (academic math — wrong register for grug voice)
    ("derivative",      ["gradient", "slope"]),
    # v7.40: removed "antiderivative" (cross-domain math contamination — "total" in
    # voice_body → "antiderivative" is catastrophic decoherence)
    # v7.41: removed "accumulation", "summation", "aggregate" (academic math —
    # "Grug integral" → "Grug accumulation/summation" is wrong register)
    ("integral",        ["total"]),
    # v7.41: removed "proposition", "corollary" (academic math — "Grug theorem" →
    # "Grug proposition/corollary" is wrong register)
    ("theorem",         ["formula", "principle", "law", "result"]),
    # v7.40: removed multi-word synonyms that garble voice_body
    ("calculus",        ["analysis"]),
    # v7.41: removed "mapping", "transformation" (academic math — "Grug function" →
    # "Grug mapping/transformation" is wrong register)
    ("function",        ["relation", "curve", "formula"]),
    ("slope",           ["gradient", "incline", "steepness", "pitch", "tilt"]),
    ("area",            ["region", "zone", "expanse", "surface", "territory"]),
    # v7.41: removed "expression", "equality", "identity" (academic math — "Grug equation"
    # → "Grug identity" or "Grug equality" is wrong-domain for grug voice)
    ("equation",        ["formula", "relation"]),
    # v7.40: removed multi-word synonyms ("work out", "figure out") that garble voice_body
    ("solve",           ["resolve", "crack", "untangle"]),
    # v8.26: "number" → "quantity" wrong in "arranges words into quantity" (should be "sentences").
    # "digit" is different meaning. "figure" is ambiguous. "amount" is different meaning.
    # Remove — "number" should not swap in voice output.
    # ("number",          ["figure", "digit", "value", "quantity", "amount"]),
    # v7.40: removed multi-word synonyms that garble voice_body
    ("triangle",        ["trigon", "three-angle"]),
    # v7.40: removed multi-word synonyms that garble voice_body
    # v7.41: removed "topology" (wrong-domain — topology ≠ geometry, and academic math term)
    # No safe single-word synonyms for geometry that fit grug voice. Commenting out.
    # ("geometry",        ["topology"]),
    # v7.40: removed "quantitative reasoning" (multi-word swap garbles voice_body)
    ("mathematics",     ["math", "calc", "numbers"]),

    # Survival / danger / combat domain
    ("survive",         ["endure", "outlast", "weather", "withstand", "prevail"]),
    ("survival",        ["endurance", "persistence", "preservation"]),
    # v7.41: removed "jeopardy", "menace" (legal/elevated — "Grug danger" → "Grug jeopardy/menace"
    # is wrong register). "peril" is borderline but acceptable in survival context.
    ("danger",          ["peril", "hazard", "threat", "risk"]),
    # v7.40: removed "abscond" (archaic/legal — "Grug flee" → "Grug abscond" is wrong register)
    ("flee",            ["escape", "retreat", "withdraw", "bolt", "scram"]),
    # v7.40: removed "secrete" (biological/archaic — "Grug hide" → "Grug secrete" is wrong register)
    ("hide",            ["conceal", "camouflage", "cover", "shroud", "vanish"]),
    # v7.40: removed "disguise" (cross-domain), "secrecy" (cross-link with stealth)
    ("concealment",     ["hiding", "stealth", "cover", "camouflage"]),
    # v7.40: removed "secrecy" (cross-link), "cunning" (wrong connotation — stealth≠cunning)
    ("stealth",         ["quietness", "cover", "concealment"]),
    ("fight",           ["combat", "battle", "struggle", "clash", "confront", "resist"]),
    # v7.41: removed "valor", "gallantry" (military/aristocratic — "Grug courage" → "Grug gallantry" is wrong register)
    # v8.26: "courage" → "nerve"/"fortitude"/"daring" are formal/literary.
    # "bravery" is OK.
    ("courage",         ["bravery"]),
    ("defend",          ["protect", "guard", "shield", "safeguard", "secure"]),
    ("alert",           ["warn", "caution", "flag", "notify", "signal"]),
    ("warning",         ["caution", "alert", "advisory", "notice", "heads-up"]),
    # v7.40: removed "prudence" (archaic/formal), "vigilance" (military tone)
    ("caution",         ["care", "wariness", "heed"]),
    # v7.40: removed "keep eyes on" (multi-word garble), "observe" (in look cluster already),
    # and "see"/"look" (cross-link with look entry causes bidirectional explosion)
    ("watch",           ["monitor", "guard", "track"]),

    # Emotion / empathy / mental state domain
    # v7.41: removed "melancholy", "anguish", "despair", "heartbreak" (elevated/literary —
    # "Grug sad" → "Grug melancholy/anguish" is wrong register for simple voice)
    ("sadness",         ["sorrow", "grief"]),
    ("anxiety",         ["worry", "unease", "apprehension", "nervousness", "dread", "tension"]),
    # v7.40: removed "bereavement" (clinical/formal — "Grug grief" → "Grug bereavement" is wrong register)
    ("grief",           ["sorrow", "mourning", "anguish", "heartache"]),
    # v7.41: removed "solace", "consolation" (archaic/elevated — "Grug comfort" → "Grug solace" is wrong register)
    # v8.26: "comfort" → "reassurance"/"relief" are formal. "support" is OK.
    ("comfort",         ["support"]),
    # v7.40: removed "endorse" (corporate/political), "acknowledge" (cross-link)
    ("validate",        ["affirm", "confirm"]),
    # v8.26: "feelings" → clinical terms removed. Should stay "feelings".
    ("feelings",        ["emotions", "sentiments", "reactions", "sensations"]),
    ("pain",            ["suffering", "hurt", "agony", "distress", "ache", "torment"]),
    ("worry",           ["anxiety", "concern", "unease", "apprehension", "fret"]),
    # v8.26d: removed "pause" (opposite of breathe — "pause out oxygen" is incoherent)
    # v8.26d: removed "settle" ("settle out oxygen" doesn't work in breathing context)
    ("breathe",         ["inhale", "exhale", "respire"]),
    # v7.40: removed "out of danger" (multi-word garble)
    ("safe",            ["secure", "protected", "sheltered", "unharmed"]),
    # v7.40: removed "by oneself" (multi-word garble), "unaccompanied" (too formal)
    ("alone",           ["isolated", "lonely", "solo"]),

    # Creativity / imagination / expression domain
    # v7.41: removed "envision", "conceive" (elevated/academic — "Grug imagine" →
    # "Grug envision/conceive" is wrong register for caveman voice)
    ("imagine",         ["fantasize", "dream", "picture", "visualize"]),
    # v7.41: removed "inventiveness", "fancy", "originality" (elevated/literary —
    # "Grug imagination" → "Grug inventiveness/fancy" is wrong register)
    ("imagination",     ["creativity", "vision"]),
    # v7.40: removed "spawn", "birth", "conjure" (weird for voice_body — "create" → "spawn"
    # is gamer-speak; "birth" is biological; "conjure" is magical). Also removed "compose"
    # (cross-link with write/weave entries). Keep "craft" and "forge" (grug-appropriate).
    ("create",          ["craft", "forge"]),
    # v7.41: removed "verse", "lyricism", "poetics", "meter" (academic literary terms —
    # "Grug poetry" → "Grug lyricism/meter" is wrong register). Keep "rhyme" (grug-appropriate).
    ("poetry",          ["rhyme"]),
    # v7.41: removed "chronicle" (literary/archaic — "Grug story" → "Grug chronicle" is wrong register)
    ("story",           ["tale", "narrative", "account", "yarn"]),
    # v7.40: removed "fabricate" (has deceptive connotation), "compose" (cross-link with write)
    ("weave",           ["intertwine", "braid", "spin", "thread"]),
    # v7.41: removed "splendor", "magnificence" (overly elevated for grug voice)
    ("beauty",          ["elegance", "grace", "wonder"]),
    # v7.41: removed "exquisite" (overly elevated for grug voice)
    ("beautiful",       ["lovely", "gorgeous", "stunning", "radiant"]),
    ("explore",         ["investigate", "probe", "discover", "delve", "chart"]),
    ("wonder",          ["marvel", "awe", "curiosity", "amazement", "fascination"]),
    # v7.40: removed "inscribe" (archaic), "scribe" (archaic), "author" (modern jargon),
    # "compose" (cross-link with create/weave)
    ("write",           ["pen", "draft"]),

    # Philosophy / cognition / abstract domain
    # v7.41: removed "deliberate" (formal/legal register), "meditate" (spiritual register),
    # "muse" (archaic poetic). Keep ponder/reflect/consider (grug-appropriate).
    ("contemplate",     ["ponder", "reflect", "consider"]),
    # v7.40: DUPLICATE of line 216 — same entry in philosophy domain. Removed
    # "sentience", "mindfulness", "cognition" for same reasons. Keep minimal.
    ("consciousness",   ["awareness", "sentience", "perception", "mindfulness", "cognition"]),
    # v7.40: removed "import" (wrong-domain — "meaning" → "import" is ambiguous),
    # "essence" (cross-link with soul/heart), "significance" (academic)
    ("meaning",         ["purpose", "value"]),
    # v7.40: removed "being" (philosophical jargon), "subsistence" (archaic),
    # "presence" (wrong-domain — "existence" → "presence" is not the same concept)
    ("existence",       ["life", "reality"]),
    # v7.40: removed "hallowed", "sanctified", "inviolable" (archaic/religious —
    # "Grug sacred" → "Grug hallowed/sanctified" is wrong register)
    # v7.41: removed "revered", "divine", "blessed" (religious/elevated —
    # "Grug sacred" → "Grug revered/divine" is still wrong register). No safe synonyms remain.
    # ("sacred",          ["revered", "divine", "blessed"]),
    # v7.41: removed "everlasting", "eternal", "perpetual", "immutable" (religious/elevated —
    # "Grug permanent" → "Grug eternal/immutable" is wrong register)
    ("permanent",       ["enduring", "lasting"]),
    # v7.40: removed "verity" and "axiom" (archaic/academic decoherence in voice_body)
    ("truth",           ["certainty", "reality"]),
    # v7.40: removed "volition" (academic — "Grug will" → "Grug volition" is decoherent)
    # v7.40: removed "resolve" (cross-link with fix/solve entries — bidirectional explosion),
    # "agency" (cross-link with agency entry), "determination" (cross-link creates loop)
    ("will",            ["choice"]),
    # v7.41: removed — all synonyms are philosophical jargon (fatalism, predestination,
    # inevitability, necessity) that decohere grug voice when swapped in
    # ("determinism",     ["fatalism", "predestination", "inevitability", "necessity"]),
    ("choose",          ["select", "decide", "opt", "pick", "determine"]),
    ("choice",          ["decision", "option", "selection", "alternative", "preference"]),
    # v7.40: removed "volition" (archaic), "sovereignty" (political), "self-determination"
    # (multi-word). "autonomy" is acceptable as single-word synonym for agency.
    ("agency",          ["autonomy"]),
    ("aware",           ["conscious", "mindful", "alert", "perceptive", "attentive"]),
    # v7.40: removed "cognition" (academic), "realization" (cross-domain with realize↔know),
    # "mindfulness" (buzzword). Also removed "consciousness" cross-link (bidirectional
    # explosion with consciousness entry)
    ("awareness",       ["perception"]),
    ("feel",            ["experience", "sense", "undergo", "intuit", "notice"]),
    ("real",            ["genuine", "actual", "authentic", "true", "concrete"]),
    ("valid",           ["legitimate", "sound", "justified", "warranted", "reasonable"]),

    # Time / memory domain
    ("time",            ["moment", "instant", "era", "epoch", "interval"]),
    ("past",            ["history", "yesterday", "bygone"]),
    ("memory",          ["recollection", "remembrance", "retention", "recall"]),
    ("now",             ["presently", "currently"]),
    ("recall",          ["remember", "recollect", "retrieve", "summon"]),

    # Perception / description domain
    # v7.40: removed "behold" (archaic), "discern" (academic), "examine", "inspect"
    # (these are analytical verbs, not perceptual — "Grug see" → "Grug inspect" is
    # wrong-domain; also removed "watch" to prevent cross-link with watch entry)
    ("see",             ["observe", "notice", "view"]),
    # v7.40: removed multi-word synonyms ("day's end", "evening glow") that garble voice_body
    ("sunset",          ["dusk", "twilight", "sundown"]),
    ("horizon",         ["skyline", "vista", "distance"]),
    ("orange",          ["amber", "tangerine", "copper", "flame-colored"]),
    ("purple",          ["violet", "indigo", "lavender", "plum"]),
    ("stretch",         ["extend", "span", "reach", "spread", "span"]),
    # v7.41: duplicate of line 324 — removed. Both had "splendor"/"magnificence" (elevated)
    ("beauty",          ["elegance", "splendor", "magnificence", "wonder", "grace"]),
    ("describe",        ["depict", "portray", "characterize", "outline", "render"]),
    # v7.40: removed "encapsulate", "immortalize" (academic/tech — "capture" → "encapsulate"
    # is programmer-speak; "immortalize" is purple prose)
    ("capture",         ["seize", "trap"]),

    # Misc common specimen vocabulary
    # v7.40: removed "concede" (legal/formal), "validate" (cross-link with validate entry)
    ("acknowledge",     ["affirm", "admit"]),
    ("preserve",        ["conserve", "protect", "maintain", "safeguard", "keep"]),
    ("engage",          ["involve", "commit", "confront", "tackle", "enter"]),
    # v7.40: removed "conceivably" (formal), "potentially" (corporate)
    ("perhaps",         ["maybe", "possibly"]),
    # v7.41: removed "shall" (archaic/formal — "Each step shall hold" is wrong register
    # for grug voice). No safe single-word synonyms remain; commenting out entirely.
    ("must",            ["shall"]),
    # v7.40: removed "sagacity" (archaic), "prudence" (formal), "discernment" (academic)
    ("wisdom",          ["insight", "judgment"]),
    ("chaos",           ["disorder", "turmoil", "confusion", "entropy", "muddle"]),
    # v7.40: removed "tongue" (archaic — "Grug language" → "Grug tongue" is decoherent),
    # "communication" (too academic for grug voice)
    # v7.41: removed "expression" (academic — "Grug language" → "Grug expression" is wrong-domain)
    ("language",        ["speech", "voice"]),
    # v7.40: removed "core", "essence" (academic — "Grug heart" → "Grug core/essence"
    # is wrong-domain decoherence; "heart" as emotion ≠ "core" as center)
    ("soul",            ["spirit", "heart"]),
    ("capacity",        ["ability", "capability", "faculty", "competence", "skill"]),
    ("absence",         ["lack", "void", "dearth", "omission", "missing"]),
    # v7.40: removed "notwithstanding" (archaic/legal — "despite" → "notwithstanding" is wrong register)
    # Single-entry: "despite" is a preposition with very few safe single-word synonyms
    # ("notwithstanding" is the only one and it's archaic). Commenting out entirely.
    # ("despite",         ["notwithstanding"]),
    ("quality",         ["property", "attribute", "characteristic", "trait", "nature"]),
    # v7.40: removed "contrary", "reciprocal", "antithesis" (academic/math —
    # "inverse" → "antithesis" is philosophical, "reciprocal" is math jargon)
    ("inverse",         ["reverse", "opposite"]),
    ("accumulate",      ["gather", "collect", "amass", "compile"]),
    ("rate",            ["pace", "speed", "frequency", "velocity", "tempo"]),
    # v7.41: removed "transformation" (academic — "Grug change" → "Grug transformation" is elevated)
    ("change",          ["shift", "alteration", "transition", "mutation"]),
    ("measure",         ["gauge", "quantify", "assess", "evaluate", "benchmark"]),
    # v7.40: removed "verity" (archaic/academic — "fact" → "verity" is decoherent)
    ("fact",            ["certainty", "datum", "finding"]),
    ("careful",         ["cautious", "wary", "attentive", "prudent", "mindful"]),
    ("justified",       ["warranted", "validated", "excused", "defensible", "reasonable"]),
    ("weakness",        ["frailty", "vulnerability", "deficiency", "flaw", "shortcoming"]),
    # v7.40: removed "knowledge" (cross-link with knowledge entry — bidirectional explosion
    # re-introduces "data"/"signal"/"intelligence" to knowledge cluster), "intelligence"
    # (military jargon), "signal" (cross-link with input/alert entries)
    ("information",     ["data", "insight", "facts"]),

    # ========================================================================
    # GRUG v8.3: HIPPOCAMPAL ANSWER COVERAGE — synonyms for common words
    # that appear in /answer-taught content. Without these, _hippocampal_touch
    # has nothing to swap and the answer is parroted verbatim. These are
    # general-purpose words that survive domain shift — they work in science,
    # emotion, language, math, and nature answers alike.
    # ========================================================================
    # --- Science / Nature answer words ---
    ("rock",            ["stone", "boulder", "mineral"]),
    ("shallow",         ["shallow-water", "coastal", "nearshore"]),
    ("formed",          ["created", "built", "shaped", "produced", "constructed"]),
    ("structures",      ["formations", "builds", "arrangements", "frameworks"]),
    ("layered",         ["stratified", "banded", "laminated", "stacked"]),
    ("luminous",        ["bright", "radiant", "brilliant", "glowing"]),
    ("galactic",        ["galaxy-scale", "cosmic", "astronomical"]),
    ("nuclei",          ["cores", "centers", "hearts"]),
    ("powered",         ["driven", "fueled", "energized", "propelled"]),
    ("supermassive",    ["gigantic", "immense", "colossal", "enormous"]),
    ("converts",        ["transforms", "changes", "turns", "transmutes"]),
    ("sugar",           ["glucose", "sweetener", "carbohydrate"]),
    ("alcohol",         ["ethanol", "spirits", "liquor"]),
    ("carbon",          ["element-six", "c-atom", "soot"]),
    ("dioxide",         ["co2", "dioxide-gas"]),
    ("yeast",           ["fungus", "leaven", "microbe"]),
    ("bacteria",        ["microorganism", "germ", "microbe"]),
    # v8.26: "oxygen" → "o2" is informal abbreviation that sounds weird in voice.
    # "element-eight"/"breath-gas" are hyphenated (already filtered).
    # Remove — "oxygen" should stay "oxygen" in caveman voice.
    # ("oxygen",          ["element-eight", "o2", "breath-gas"]),
    ("hydrogen",        ["element-one", "h2", "light-gas"]),
    ("atom",            ["particle", "molecule", "bit-of-matter"]),
    ("molecule",        ["particle", "compound", "unit"]),
    ("cell",            ["unit", "compartment", "organism-tiny"]),
    ("energy",          ["power", "force", "vigor", "vitality"]),
    # v8.26: "heat" → "thermal"/"fire-emanation" are formal/hyphenated.
    # Only "warmth" is safe.
    ("heat",            ["warmth"]),
    # v8.26: "light" → "radiance"/"illumination"/"glow" are poetic/formal.
    # "glow" already in excluded set. Remove — "light" is core word.
    ("light",           ["radiance", "illumination", "glow"]),
    ("combines",        ["joins", "merges", "blends", "unites"]),
    ("releases",        ["emits", "gives-off", "discharges", "expels"]),
    # --- Emotion / Psychology answer words ---
    ("understanding",   ["comprehension", "grasp", "awareness", "insight"]),
    # v8.26: "sharing" → "experiencing"/"feeling-with"/"communing" are formal/multi-word.
    # Remove — "sharing" should not swap.
    # ("sharing",         ["experiencing", "feeling-with", "communing"]),
    # v8.26: duplicate removed (see line ~335)
    ("feelings",        ["emotions", "sentiments", "reactions", "sensations"]),
    # v8.26: "emotional" → "affective" is clinical, "feeling-based"/"heart-level" are hyphenated.
    # Remove — "emotional" should not swap.
    # ("emotional",       ["affective", "feeling-based", "heart-level"]),
    # v8.26: "connection" → "attachment" is clinical, "bond"/"link"/"tie" are OK.
    ("connection",      ["bond", "link", "tie"]),
    ("person",          ["individual", "being", "soul", "human"]),
    # v8.26b: "another" → "fellow" is wrong context. "divisors fellow than 1" is incoherent.
    # "fellow" is a noun, not a preposition. COMMENTED OUT.
    # ("another",         ["fellow"]),
    ("empathy",         ["compassion", "sympathy", "caring", "fellow-feeling"]),
    ("approximately",   ["roughly", "about", "around", "nearly"]),
    ("appears",         ["seems", "looks", "shows-up", "manifests"]),
    # --- Language / Poetry answer words ---
    ("poem",            ["verse", "composition", "lyric", "work"]),
    ("line",            ["verse-line", "row", "stanza-row"]),
    ("rhyme",           ["sound-match", "echo-end", "poetry"]),
    ("meter",           ["rhythm", "beat", "measure", "cadence"]),
    ("scheme",          ["pattern", "plan", "arrangement", "design"]),
    ("specific",        ["particular", "exact", "precise", "defined"]),
    # --- Math answer words ---
    ("ratio",           ["proportion", "fraction", "relationship"]),
    # v8.26: "golden" → "ideal"/"perfect"/"sublime" — "sublime" is literary.
    # "ideal" and "perfect" are OK.
    ("golden",          ["ideal", "perfect"]),
    # v8.26: "value" → "figure"/"amount"/"number"/"meaning"/"purpose"/"digit"/"quantity"
    # most are wrong meaning or formal. Remove — "value" should not swap.
    # ("value",           ["figure", "amount", "number", "meaning", "purpose", "digit", "quantity"]),
    # --- General answer-function words ---
    # v8.26b: "are" → "form" is wrong. "Atoms form made of" is incoherent.
    # "are" is a core verb and should never be swapped. COMMENTED OUT.
    # ("are",             ["form"]),
    # v8.26: "is" → "equals"/"represents"/"constitutes"/"amounts-to" are formal/math.
    # Remove — "is" is the most fundamental verb, should never swap.
    # ("is",              ["equals", "represents", "constitutes", "amounts-to"]),
    # v8.26: "using" → "via"/"by-means-of"/"through" are formal. "with" bidirectional
    # means "with" → "using" which breaks "Grug sit with love" → "Grug sit using love".
    # Remove — "using" should not appear in voice output.
    ("using",           ["via", "through", "by-means-of", "with"]),
    # v8.26c: "through" → "via"/"by-way-of"/"by-means-of" are hyphenated/multi-word.
    # Blocked by hyphen filter anyway. Keep commented for cleanliness.
    # ("through",         ["via", "by-way-of", "by-means-of"]),
    # v8.26: "into" → "becoming"/"transforming-into"/"yielding" are formal/multi-word.
    # Remove — "into" should not swap.
    # ("into",            ["becoming", "transforming-into", "yielding"]),
    ("organism",        ["creature", "being", "lifeform"]),
    ("survival",        ["endurance", "preservation", "persistence"]),
    ("prey",            ["quarry", "target", "game"]),
    ("pursuit",         ["hunt", "chase", "quest"]),
    ("capture",         ["catch", "seizure", "taking"]),
    ("digest",          ["absorb", "process", "break-down"]),
    ("applies",         ["uses", "employs", "utilizes"]),
    ("organized",       ["structured", "arranged", "ordered"]),
    ("expresses",       ["conveys", "communicates", "shows", "reveals"]),
    ("scatters",        ["disperses", "spreads", "diffuses"]),
    ("blue",            ["azure", "cerulean", "sky-colored"]),
    ("short",           ["brief", "small", "compact"]),
    ("fast",            ["quick", "rapid", "swift"]),

    # ── v8.13 expansion: high-frequency answer words ──────────────────────
    # These are the words Grug actually uses in answers. Without them the
    # thesaurus can only swap ~15% of tokens. With these, we hit ~40-50%.

    # ── Connectors / conjunctions / discourse markers ──
    # v8.26b: "and" is the MOST fundamental connector. Swapping "and"→"also" produces
    # "also" everywhere: "Two hydrogen also one oxygen", "helping also hurting",
    # "art also science", "fellow than 1 also themselves". COMMENTED OUT.
    ("and",             ["also"]),
    # v8.26: "but" → "however"/"nevertheless" are formal (already in excluded set).
    # "yet" and "still" are safe.
    ("but",             ["yet", "still", "though"]),
    # v8.26: "or" → "alternatively"/"otherwise" are formal. "else" is OK.
    ("or",              ["else"]),
    # v8.26: "not" → "no" breaks grammar ("does no mean"), "neither" is formal.
    # Only "never" is safe and only in some contexts, but it's still risky.
    # Removing entirely — "not" should never be swapped in voice output.
    # ("not",             ["never", "no", "neither"]),
    # v8.26: "because" → "owing to" is multi-word formal, "for" is archaic conjunction.
    # "since" and "as" are safe.
    ("because",         ["since", "as"]),
    ("therefore",       ["thus", "hence", "consequently", "so", "accordingly"]),
    ("however",         ["but", "yet", "nevertheless", "though", "still"]),
    # "moreover"/"furthermore" create bidirectional links to "also" and "and".
    # These connectors are grammatically fine — variety is good.
    ("moreover",        ["also", "and"]),
    ("furthermore",     ["also", "and"]),
    # v8.26c: "also"↔"and" bidirectional is fine — grammatically correct.
    # Variety is good; "also" for "and" is not incoherent.
    ("also",            ["and"]),
    ("thus",            ["therefore", "hence", "consequently", "so"]),
    ("yet",             ["but", "however", "nevertheless", "still"]),
    ("indeed",          ["truly", "certainly", "surely", "actually"]),
    ("actually",        ["in fact", "really", "truly", "indeed"]),
    ("really",          ["truly", "actually", "indeed", "genuinely"]),
    ("certainly",       ["surely", "indeed", "definitely", "undoubtedly"]),
    # v8.26b: "just" is wrong register. "merely"/"barely" are formal. Only "only" is OK.
    ("simply",          ["only"]),
    ("basically",       ["essentially", "fundamentally", "in short", "in essence"]),
    ("quite",           ["fairly", "rather", "somewhat", "pretty"]),
    ("rather",          ["quite", "fairly", "somewhat", "instead"]),
    ("often",           ["frequently", "commonly", "regularly", "many times"]),
    ("sometimes",       ["occasionally", "at times", "now and then", "periodically"]),
    ("usually",         ["typically", "normally", "generally", "ordinarily"]),
    ("perhaps",         ["maybe", "possibly", "potentially", "perchance"]),
    ("maybe",           ["perhaps", "possibly", "potentially"]),

    # ── Common verbs ──
    # v8.26: "make" → "produce" is formal, "craft" is slightly elevated.
    ("make",            ["create", "build", "form"]),
    ("made",            ["created", "built", "formed", "produced", "crafted"]),
    ("go",              ["move", "proceed", "travel", "advance"]),
    ("goes",            ["moves", "proceeds", "travels", "advances"]),
    ("went",            ["moved", "proceeded", "traveled", "advanced"]),
    ("come",            ["arrive", "approach", "emerge"]),
    ("came",            ["arrived", "approached", "emerged"]),
    ("take",            ["grab", "seize", "claim", "accept"]),
    ("took",            ["grabbed", "seized", "claimed", "accepted"]),
    # v8.26: "know" → "understand" (excluded), "comprehend"/"recognize"/"grasp" are formal.
    # Remove — "know" is core caveman word.
    ("know",            ["understand", "comprehend", "recognize", "grasp"]),
    # v8.26: "knew" → formal past tenses removed.
    ("knew",            ["understood", "comprehended", "recognized"]),
    # v8.26: "think" → "consider"/"reckon"/"suppose" are formal/dialect.
    # "believe" is OK but slightly elevated. Remove — "think" is core caveman word.
    ("think",           ["believe", "consider", "reckon", "suppose"]),
    # v8.26: "thought" (verb past) → "believed"/"considered"/"reckoned"/"supposed" are formal.
    # Remove — "thought" should stay "thought".
    ("thought",         ["believed", "considered", "reckoned", "supposed"]),
    # v8.26: "say" → "state"/"declare"/"express"/"mention" are formal.
    # Remove — "say" is core caveman word.
    ("say",             ["state", "declare", "express", "mention"]),
    # v8.26: "said" → same cleanup
    ("said",            ["stated", "declared", "expressed", "mentioned"]),
    # v8.26: "tell" → "inform"/"reveal"/"convey"/"narrate" are formal.
    # Remove — "tell" is core caveman word.
    ("tell",            ["inform", "reveal", "convey", "narrate"]),
    # v8.26: "told" → same cleanup
    ("told",            ["informed", "revealed", "conveyed", "narrated"]),
    # v8.26: "grow" → "develop"/"expand"/"increase" are formal. "thrive" is OK.
    ("grow",            ["thrive"]),
    # v8.26: "hold" → "grasp"/"grip" wrong in "one's hold mind" context.
    # "carry" and "support" are different meanings. Remove — "hold" should stay.
    ("hold",            ["grasp", "grip", "carry", "support"]),
    # v8.26: "bring" → "deliver"/"convey" are formal. "carry"/"fetch" are OK.
    ("bring",           ["carry", "fetch"]),
    # v8.26: "become"/"becomes" → all multi-word. Remove.
    # ("become",          ["turn into", "transform into", "evolve into"]),
    # ("becomes",         ["turns into", "transforms into", "evolves into"]),
    # v8.26: "run" → "sprint"/"race"/"dash" are too specific. "hurry" is OK.
    ("run",             ["hurry"]),
    ("play",            ["frolic", "amuse", "entertain"]),
    ("hear",            ["listen", "detect", "perceive"]),
    ("heard",           ["listened", "detected", "perceived"]),
    ("let",             ["allow", "permit", "enable", "leave"]),
    ("must",            ["have to", "need to", "ought to", "shall"]),
    ("can",             ["able to", "could", "may", "know how to"]),
    ("will",            ["shall", "going to", "intend to"]),
    ("would",           ["could", "might", "may"]),
    ("should",          ["ought to", "must", "need to"]),
    ("could",           ["might", "would", "may", "can"]),
    ("might",           ["could", "may", "would"]),
    ("may",             ["might", "could", "can"]),

    # ── Auxiliaries / common function words ──
    ("was",             ["had been", "existed as"]),
    ("were",            ["had been", "existed as"]),
    # v8.26: "has" → "possesses"/"owns"/"contains" are formal register.
    # "owns" OK in some contexts. "holds" already excluded from "hold" entry removal.
    ("has",             ["owns"]),
    # v8.26: "have" → same cleanup
    ("have",            ["own"]),
    # v8.26: "had" → "possessed"/"owned"/"contained" are formal
    ("had",             ["held"]),
    # v8.26: "does"/"did"/"do" → "performs"/"executes"/"accomplishes" are formal register.
    # These auxiliaries should rarely swap. Remove entirely.
    ("does",            ["performs", "executes", "accomplishes"]),
    ("did",             ["performed", "executed", "accomplished"]),
    ("do",              ["perform", "execute", "accomplish", "act"]),
    ("get",             ["obtain", "acquire", "gain", "receive"]),
    ("got",             ["obtained", "acquired", "gained", "received"]),

    # ── Adjectives / quantifiers ──
    # v8.26: "good" → "worthy"/"excellent" are formal. "great"/"fine"/"solid" OK.
    ("good",            ["great", "fine", "solid"]),
    # v8.26: "bad" → "poor"/"dreadful"/"lousy" are formal/weird. "terrible"/"awful" OK.
    ("bad",             ["terrible", "awful"]),
    # v8.26: "great" → "grand"/"immense" are formal. "mighty"/"vast"/"huge" OK.
    ("great",           ["mighty", "huge"]),
    ("new",             ["fresh", "novel", "recent", "modern"]),
    ("old",             ["ancient", "aged", "venerable", "vintage"]),
    ("long",            ["extended", "lengthy", "prolonged", "vast"]),
    # v8.26: "important" → "significant"/"crucial"/"essential" are formal.
    # "vital" and "key" are OK.
    ("important",       ["vital", "key"]),
    ("different",       ["distinct", "diverse", "various", "unlike"]),
    ("same",            ["identical", "equal", "equivalent", "alike"]),
    ("possible",        ["feasible", "achievable", "attainable", "potential"]),
    ("every",           ["each", "all", "any", "every single"]),
    ("all",             ["every", "each", "the entire", "the whole"]),
    # v8.26: "some" → "several" garbles "some to occur" → "several to occur".
    # "certain" and "particular" are formal/wrong register. "a few" is multi-word.
    # Only safe synonym removed entirely — "some" should stay "some".
    # ("some",            ["certain", "a few", "several", "particular"]),
    # v8.26: "many" → "several" wrong (several ≠ many, different quantity).
    # "numerous" is formal. "various" is different meaning. Only "multiple" OK but formal.
    ("many",            ["countless"]),
    ("much",            ["a lot", "plenty", "abundantly", "considerably"]),
    # v8.26: "very" → "extremely"/"highly"/"deeply"/"terribly"/"remarkably" are formal.
    # Remove — "very" is core caveman word.
    ("very",            ["extremely", "highly", "deeply", "terribly", "remarkably"]),
    # v8.26: "still" → "nevertheless"/"even so"/"nonetheless" are formal.
    # "yet" is OK.
    ("still",           ["yet"]),
    # v8.26: "never" → "not ever"/"at no time"/"never once" are multi-word/formal.
    # Remove — "never" should stay "never".
    # ("never",           ["not ever", "at no time", "never once"]),
    # v8.26: "always" → "forever"/"constantly"/"perpetually"/"invariably" are formal.
    # "ever" is OK.
    ("always",          ["ever"]),
    # v8.26: "already" → "previously"/"by now"/"before now" are formal/multi-word.
    # Remove — "already" should stay.
    ("already",         ["previously", "by now", "before now"]),

    # ── Prepositions / spatial words ──
    ("from",            ["out of", "originating from", "derived from"]),
    # v8.26: "between" → "amid" wrong preposition ("bridge amid sun and life").
    # "betwixt" is archaic. Only "among" is sometimes OK.
    ("between",         ["among"]),
    ("before",          ["prior to", "ahead of", "preceding"]),
    ("after",           ["following", "subsequent to", "behind"]),
    # v8.26: "during" → "amid" wrong preposition, "in the course of" is multi-word formal.
    # "throughout" is formal. Only "while" is safe.
    ("during",          ["while"]),
    # v8.26: "while" → "whilst" is archaic, "even as" is multi-word.
    # "during" and "as" are OK.
    ("while",           ["during", "as"]),
    # v8.26: "since" → "ever since"/"from the time" are multi-word.
    # "because" and "as" are OK.
    ("since",           ["because", "as"]),
    ("until",           ["till", "up to", "as far as"]),
    ("above",           ["over", "on top of", "higher than"]),
    ("below",           ["under", "beneath", "lower than"]),
    ("under",           ["beneath", "below", "underneath"]),
    ("over",            ["above", "on top of", "beyond"]),
    # v8.26: "among" → "amid"/"amidst" wrong register. Only "between" OK.
    ("among",           ["between"]),
    ("across",          ["spanning", "traversing", "crossing"]),
    # v8.26: "along" → "beside"/"by"/"following" — "along" in "sits along you"
    # is already wrong (should be "with"), swapping makes it worse. Remove.
    ("along",           ["beside", "by", "following"]),
    ("against",         ["opposing", "versus", "counter to"]),
    ("within",          ["inside", "in", "contained in"]),
    ("without",         ["lacking", "absent", "devoid of", "minus"]),
    ("behind",          ["after", "back from", "trailing"]),
    ("beyond",          ["past", "farther than", "exceeding"]),
    ("toward",          ["towards", "approaching", "heading for"]),
    ("towards",         ["toward", "approaching", "heading for"]),
    ("upon",            ["on", "atop", "on top of"]),

    # ── Common nouns that appear in answers ──
    ("thing",           ["matter", "object", "item", "entity"]),
    ("things",          ["matters", "objects", "items", "entities"]),
    ("way",             ["path", "route", "method", "manner"]),
    ("hand",            ["paw", "grip", "clasp"]),
    ("hands",           ["paws", "grips", "clasps"]),
    # v8.26: "world" → "realm"/"domain" are formal. "globe" is slightly formal.
    ("world",           ["earth", "globe"]),
    # v8.26: "earth" → "ground"/"soil"/"land" change meaning (planet → dirt).
    # Only "world" is safe bidirectional swap.
    ("earth",           ["world"]),
    # v8.26: "fire" → "blaze"/"inferno"/"conflagration" are literary/wrong register.
    # Only "flame" is sometimes OK but it's already in excluded set.
    # Remove — "fire" is core caveman word, should not swap.
    ("fire",            ["flame", "blaze", "inferno", "conflagration"]),
    # v8.26: "water" → "rain" wrong in "water is split" context. "moisture" is different.
    # "liquid" OK in scientific contexts, "flow" is poetic. Keep only "liquid".
    ("water",           ["liquid"]),
    ("light",           ["glow", "radiance", "illumination", "brightness"]),
    # v8.26: "heat" → "fire" creates circular confusion (fire↔heat↔fire).
    # "temperature" is clinical, "glow" is poetic. Only "warmth" is safe.
    ("heat",            ["warmth"]),
    # v8.26: "energy" → "vigor"/"vitality"/"stamina" are clinical/formal.
    # "force" and "power" create circular swaps. Keep simple.
    ("energy",          ["power", "might"]),
    # v8.26: "power" → "might" is caveman-safe. "energy"/"force"/"strength" are circular.
    ("power",           ["might", "strength"]),
    # v8.26: "force" → circular with power/energy. "might" is OK.
    ("force",           ["might", "strength"]),
    ("life",            ["living", "existence", "being", "survival"]),
    ("living",          ["life", "existence", "being", "survival"]),
    ("cave",            ["den", "lair", "shelter", "dwelling"]),
    # v8.26: "people" → "mortals" is literary, "beings" is philosophical.
    # "folk" and "humans" are OK.
    ("people",          ["folk", "humans"]),
    ("creature",        ["being", "organism", "beast", "lifeform"]),
    ("creatures",       ["beings", "organisms", "beasts", "lifeforms"]),
    ("body",            ["form", "frame", "physique", "organism"]),
    # v8.26: "mind" → "intellect" is formal, "consciousness" is philosophical/wrong register.
    # "brain" and "thought" are OK.
    ("mind",            ["brain", "thought"]),
    ("heart",           ["chest", "core", "center", "soul"]),
    ("time",            ["moment", "era", "period", "age"]),
    ("moment",          ["time", "instant", "second", "breath"]),
    ("question",        ["query", "inquiry", "ask"]),
    ("answer",          ["reply", "response", "rejoinder"]),
    # v8.26: "truth" → "certainty" is philosophical (already in excluded set).
    # "reality" is philosophical. "fact" is OK.
    ("truth",           ["fact"]),
    # v8.26: "fact" → "certainty"/"datum" are formal/scientific. "truth"/"reality" OK.
    ("fact",            ["truth", "reality"]),
    ("rule",            ["govern", "command", "control", "principle", "decree", "edict"]),
    ("law",             ["statute", "ordinance", "principle", "decree", "edict"]),
    ("path",            ["way", "route", "track", "course"]),
    # v8.26: "step" → "stride" is literary. "pace"/"stage"/"phase" are OK.
    ("step",            ["pace", "stage", "phase"]),
    ("thread",          ["strand", "line", "fiber", "connection"]),
    ("risk",            ["danger", "hazard", "peril", "threat"]),
    ("danger",          ["risk", "hazard", "peril", "threat"]),
    ("strength",        ["power", "force", "might", "vigor"]),
    # v8.26: "fear" → "dread"/"terror"/"anxiety"/"fright" are literary/clinical.
    # Remove — "fear" is core caveman word.
    ("fear",            ["dread", "terror", "anxiety", "fright"]),
    ("hope",            ["wish", "desire", "aspiration", "longing"]),
    ("trust",           ["faith", "belief", "confidence", "reliance"]),
    ("care",            ["concern", "attention", "regard", "solicitude"]),
    ("warmth",          ["heat", "affection", "cordiality", "glow"]),
    ("pain",            ["hurt", "agony", "suffering", "ache"]),
    ("joy",             ["delight", "bliss", "gladness", "elation"]),
    ("sorrow",          ["grief", "sadness", "mourning", "woe"]),
    ("rage",            ["fury", "wrath", "anger", "ire"]),
    ("calm",            ["peace", "tranquility", "stillness", "serenity"]),
    ("peace",           ["calm", "tranquility", "stillness", "serenity"]),
    ("form",            ["shape", "structure", "pattern", "arrangement"]),
    ("shape",           ["form", "figure", "structure", "outline"]),
    ("structure",       ["form", "framework", "arrangement", "architecture"]),
    ("color",           ["hue", "shade", "tint", "tone"]),
    ("sound",           ["noise", "tone", "echo", "vibration"]),
    ("voice",           ["speech", "utterance", "expression", "tone"]),
    ("word",            ["term", "expression", "name", "utterance"]),
    ("words",           ["terms", "expressions", "names", "utterances"]),
    ("name",            ["call", "title", "designation", "label"]),
    ("story",           ["tale", "narrative", "account", "chronicle"]),
    ("reason",          ["logic", "rationale", "thinking", "motive"]),
    # v8.26: "idea" → "concept"/"notion"/"insight" are formal. "thought" is OK.
    ("idea",            ["thought"]),
    # v8.26: "thought" (noun) → "concept"/"notion"/"reflection" are formal.
    # "idea" is OK.
    ("thought",         ["idea"]),
    # v8.26: "knowledge" → "wisdom" cascades to "sagacity". "insight" is formal.
    # "learning" is different meaning. "understanding" is OK.
    ("knowledge",       ["understanding"]),
    # v8.26: "wisdom" → "sagacity" is archaic (comment said removed but wasn't).
    # "judgment" is formal. "insight" already excluded. Keep only "knowledge".
    ("wisdom",          ["knowledge"]),
    # v8.26: "science" → "discipline"/"research"/"investigation" are formal.
    # Only "study" is caveman-safe.
    ("science",         ["study"]),
    # v8.26: "nature" → "wilderness"/"environment"/"ecosystem" are formal/wrong register.
    # "the wild" is multi-word. Remove — "nature" should not swap.
    ("nature",          ["wilderness", "environment", "ecosystem", "the wild"]),
    ("forest",          ["woods", "woodland", "grove", "thicket"]),
    ("river",           ["stream", "waterway", "current", "flow"]),
    ("sky",             ["heavens", "firmament", "atmosphere", "above"]),
    # v8.26: "ground" → "terrain" is formal. Keep "earth", "soil", "land".
    ("ground",          ["earth", "soil", "land"]),
    # v8.26: "soil" → "dirt" is colloquial but OK. "terrain" is formal.
    ("soil",            ["earth", "dirt", "ground", "land"]),
    ("rock",            ["stone", "boulder", "mineral"]),
    ("stone",           ["rock", "boulder", "mineral"]),
    # v8.26: "sun" → "star" wrong in "sunlight"/"sun energy" context.
    # "daystar" is archaic. "light source" is multi-word. Remove entirely.
    # ("sun",             ["star", "daystar", "light source"]),
    ("moon",            ["luna", "satellite", "night light"]),
    ("star",            ["sun", "celestial body", "light"]),
    ("air",             ["atmosphere", "breath", "wind", "breeze"]),
    ("wind",            ["breeze", "gust", "air", "draft"]),
    # v8.26: "rain" → "drizzle" wrong register, "downpour" is different scale.
    # "shower" is ambiguous. Only "precipitation" is OK for science context.
    ("rain",            ["precipitation"]),
    ("tree",            ["timber", "sapling", "oak", "trunk"]),
    ("ocean",           ["sea", "deep", "abyss", "waters"]),
    ("sea",             ["ocean", "deep", "waters", "marine"]),
    ("mountain",        ["peak", "summit", "ridge", "highland"]),
    ("valley",         ["hollow", "gorge", "dale", "basin"]),

    # ── v8.13 hotfix: cross-pos problematic entries ───────────────────────
    # "like" as preposition (shaped like...) → "such as" / "akin to"
    # NOT "enjoy" (that's the verb sense, breaks in prepositional context)
    ("like",            ["akin to", "similar to", "such as", "resembling"]),
    # v8.26b: "just" is wrong — "fits so just" is incoherent. "correct"/"proper"/"fitting" are formal.
    # Only "true" is OK for caveman voice.
    ("right",           ["true"]),
    ("future",          ["ahead", "what comes", "what lies ahead", "time to come"]),
    ("gentle",          ["tender", "mild", "soft", "kind", "delicate"]),
]

# GRUG: Build bidirectional flat lookup at module load time.
# synonym_word -> Set of all words it is synonymous with (one hop, bidirectional).
const SYNONYM_SEED_MAP = Dict{String, Set{String}}()

function _build_seed_map!()
    for (canonical, synonyms) in _SEED_SYNONYMS_RAW
        can = lowercase(strip(canonical))
        syns = Set{String}(map(s -> lowercase(strip(s)), synonyms))

        # GRUG: canonical -> all its synonyms
        if !haskey(SYNONYM_SEED_MAP, can)
            SYNONYM_SEED_MAP[can] = Set{String}()
        end
        union!(SYNONYM_SEED_MAP[can], syns)

        # GRUG: each synonym -> canonical AND all other synonyms (full bidirectional)
        for syn in syns
            if !haskey(SYNONYM_SEED_MAP, syn)
                SYNONYM_SEED_MAP[syn] = Set{String}()
            end
            push!(SYNONYM_SEED_MAP[syn], can)
            # GRUG: Also add all other synonyms of the same canonical
            others = filter(s -> s != syn, syns)
            union!(SYNONYM_SEED_MAP[syn], others)
        end
    end
end

# GRUG: Build the map immediately at module load time. Not lazy - must be ready!
_build_seed_map!()

# ============================================================================
# SYNONYM LOOKUP - Check seed dictionary first, fall back to structural
# ============================================================================

"""
synonym_lookup(word1, word2) -> Float64

GRUG: Check if two words are synonyms.
Priority chain:
  1. Exact seed match (bidirectional) -> 0.95
  2. Structural similarity (trigram Jaccard) -> whatever it scores
Returns score in [0.0, 1.0].
"""
function synonym_lookup(word1::AbstractString, word2::AbstractString)::Float64
    if isempty(strip(word1)) || isempty(strip(word2))
        throw_thesaurus_error("Cannot lookup empty words", "synonym_lookup")
    end
    w1 = lowercase(strip(word1))
    w2 = lowercase(strip(word2))

    # GRUG: Exact same word is always 1.0
    if w1 == w2
        return 1.0
    end

    # GRUG: Check 1 - seed dictionary (O(1) lookup, covers structural gaps)
    if haskey(SYNONYM_SEED_MAP, w1) && w2 in SYNONYM_SEED_MAP[w1]
        return 0.95  # GRUG: Seed match = very high confidence synonym
    end
    if haskey(SYNONYM_SEED_MAP, w2) && w1 in SYNONYM_SEED_MAP[w2]
        return 0.95  # GRUG: Bidirectional - also check reverse
    end

    # GRUG: Check 2 - structural similarity (trigram Jaccard)
    return word_similarity(word1, word2)
end

"""
get_seed_synonyms(word) -> Vector{String}

GRUG: Return all known seed synonyms for a word. Empty if none known.
"""
function get_seed_synonyms(word::AbstractString)::Vector{String}
    w = lowercase(strip(word))
    if isempty(w)
        throw_thesaurus_error("Cannot get synonyms for empty word", "get_seed_synonyms")
    end
    if haskey(SYNONYM_SEED_MAP, w)
        return sort(collect(SYNONYM_SEED_MAP[w]))
    end
    return String[]
end

# ============================================================================
# GATE FILTER - Expand input tokens with synonyms for pre-scan enrichment
# GRUG: This is the gate integration point!
# Takes a raw input string, tokenizes it, expands each token with synonyms.
# Returns an expanded set of tokens that the scan gate can use for richer matching.
# Example: "fix the error" -> {"fix","repair","mend","patch","error","mistake","bug","the"}
# ============================================================================

"""
thesaurus_gate_filter(input_text; is_blocked=nothing) -> Set{String}

GRUG: Pre-scan gate expansion. Turns input tokens into a rich synonym cloud.
Used by process_mission gate before scan_and_expand runs.
Each token expands to at most GATE_MAX_EXPANSIONS_PER_TOKEN synonyms (sorted by seed priority).
Returns combined set of original tokens + expansions (all lowercase).

GRUG v9.4: `is_blocked` is an optional `(word, synonym) -> Bool` callback.
Thesaurus.jl itself has no knowledge of InputQueue's context ledger (that
would be a circular module dependency — InputQueue is included AFTER
Thesaurus), so the caller (Main.jl) injects `InputQueue.is_synonym_blocked`
here. When provided, any (tok, syn) pair the callback flags as a known-bad
register/context edge case ("deep"->"abyss" activating an ocean-flavoured
node from an unrelated "deep water is dangerous" input, etc.) is skipped
during expansion — the edge case is honoured at ACTIVATION time, not just
at output time.
"""
function thesaurus_gate_filter(input_text::AbstractString;
                                is_blocked::Union{Function, Nothing} = nothing)::Set{String}
    if isempty(strip(input_text))
        throw_thesaurus_error("Cannot filter empty input", "thesaurus_gate_filter")
    end

    tokens = filter(!isempty, map(t -> lowercase(strip(t)), split(input_text)))
    # GRUG v8.17: Start with both original AND stemmed forms of all tokens.
    # "atoms" produces {"atoms", "atom"}, "running" produces {"running", "run"}.
    # This ensures gate expansion matches work even before synonym lookup.
    expanded = normalize_tokens(tokens)

    _blocked(w, s) = is_blocked !== nothing && is_blocked(w, s)

    for tok in tokens
        syns = get_seed_synonyms(tok)
        # GRUG: Take up to GATE_MAX_EXPANSIONS_PER_TOKEN synonyms.
        # Seed synonyms are already sorted alphabetically - that's fine,
        # all seed entries are high quality. Take first N.
        count = 0
        for syn in syns
            count >= GATE_MAX_EXPANSIONS_PER_TOKEN && break
            _blocked(tok, syn) && continue  # GRUG v9.4: context-ledger edge case — skip
            push!(expanded, syn)
            # GRUG v8.17: Also add the stemmed form of each synonym.
            stemmed = stem_token(syn)
            stemmed != syn && push!(expanded, stemmed)
            count += 1
        end
        # GRUG v8.17: Also expand the stemmed form's synonyms.
        # If "atoms" stems to "atom", and "atom" has synonyms ["particle", ...],
        # we should include those too.
        stemmed_tok = stem_token(tok)
        if stemmed_tok != tok
            stemmed_syns = get_seed_synonyms(stemmed_tok)
            count2 = 0
            for syn in stemmed_syns
                count2 >= GATE_MAX_EXPANSIONS_PER_TOKEN && break
                _blocked(stemmed_tok, syn) && continue  # GRUG v9.4
                push!(expanded, syn)
                count2 += 1
            end
        end
    end

    return expanded
end

"""
thesaurus_gate_score(input_text, candidate_text) -> Float64

GRUG: Score how well candidate matches input after gate expansion.
Uses synonym-aware token overlap (Jaccard over expanded sets).
Returns [0.0, 1.0]. Higher = better match through synonymy.
"""
function thesaurus_gate_score(input_text::AbstractString, candidate_text::AbstractString)::Float64
    if isempty(strip(input_text)) || isempty(strip(candidate_text))
        throw_thesaurus_error("Cannot score empty input or candidate", "thesaurus_gate_score")
    end

    expanded_input     = thesaurus_gate_filter(input_text)
    expanded_candidate = thesaurus_gate_filter(candidate_text)

    union_sz = length(union(expanded_input, expanded_candidate))
    return union_sz > 0 ? Float64(length(intersect(expanded_input, expanded_candidate))) / Float64(union_sz) : 0.0
end

# ============================================================================
# NGRAM HELPER - GRUG break words into chunks to compare them
# ============================================================================

function generate_ngrams(text::AbstractString, n::Int = DEFAULT_NGRAM_SIZE)::Set{String}
    if isempty(text) || n <= 0
        return Set{String}()
    end
    normalized = lowercase(replace(strip(text), r"\s+" => ""))
    if length(normalized) < n
        return Set{String}([String(normalized)])
    end
    ngrams = Set{String}()
    for i in 1:(length(normalized) - n + 1)
        push!(ngrams, String(SubString(normalized, i, i + n - 1)))
    end
    return ngrams
end

# ============================================================================
# JACCARD SIMILARITY - GRUG favorite way to compare sets
# ============================================================================

function jaccard_similarity(set1::Set, set2::Set)::Float64
    if isempty(set1) && isempty(set2)
        return 1.0
    end
    if isempty(set1) || isempty(set2)
        return 0.0
    end
    intersection_size = length(intersect(set1, set2))
    union_size        = length(union(set1, set2))
    if union_size == 0
        return 0.0
    end
    return intersection_size / union_size
end

# ============================================================================
# WORD SIMILARITY - Compare two words character by character chunks
# ============================================================================

function word_similarity(word1::AbstractString, word2::AbstractString; ngram_size::Int = DEFAULT_NGRAM_SIZE)::Float64
    if isempty(strip(word1)) || isempty(strip(word2))
        throw_thesaurus_error("Cannot compare empty words", "word_similarity")
    end
    if lowercase(strip(word1)) == lowercase(strip(word2))
        return 1.0
    end
    ngrams1 = generate_ngrams(word1, ngram_size)
    ngrams2 = generate_ngrams(word2, ngram_size)
    # GRUG handle short words: if both generate single ngrams, compare them directly
    if length(ngrams1) == 1 && length(ngrams2) == 1
        w1 = first(ngrams1)
        w2 = first(ngrams2)
        if w1 == w2
            return 1.0
        end
        # GRUG check partial match in short words
        if occursin(w1, w2) || occursin(w2, w1)
            return 0.5
        end
    end
    return jaccard_similarity(ngrams1, ngrams2)
end

# ============================================================================
# CONCEPT SIMILARITY - Compare bigger ideas, not just words
# ============================================================================

function concept_similarity(concept1::AbstractString, concept2::AbstractString)::Float64
    if isempty(strip(concept1)) || isempty(strip(concept2))
        throw_thesaurus_error("Cannot compare empty concepts", "concept_similarity")
    end
    if lowercase(strip(concept1)) == lowercase(strip(concept2))
        return 1.0
    end
    tokens1   = Set{String}(filter(!isempty, map(t -> lowercase(strip(t)), split(concept1))))
    tokens2   = Set{String}(filter(!isempty, map(t -> lowercase(strip(t)), split(concept2))))
    token_sim = jaccard_similarity(tokens1, tokens2)
    substr_sim = 0.0
    for t1 in tokens1
        for t2 in tokens2
            if occursin(t1, t2) || occursin(t2, t1)
                substr_sim = max(substr_sim, 0.5)
                break
            end
        end
    end
    final_sim = 0.7 * token_sim + 0.3 * substr_sim
    return min(1.0, final_sim)
end

# ============================================================================
# CONTEXT SIMILARITY - Compare where things belong
# ============================================================================

function context_similarity(ctx1::Vector{String}, ctx2::Vector{String})::Float64
    if isempty(ctx1) && isempty(ctx2)
        return 0.5
    end
    if isempty(ctx1) || isempty(ctx2)
        return 0.0
    end
    norm_ctx1 = Set{String}(map(c -> lowercase(strip(c)), ctx1))
    norm_ctx2 = Set{String}(map(c -> lowercase(strip(c)), ctx2))
    return jaccard_similarity(norm_ctx1, norm_ctx2)
end

# ============================================================================
# CROSS-TYPE SIMILARITY - Compare word to concept or vice versa
# ============================================================================

function cross_type_similarity(word::AbstractString, concept::AbstractString)::Float64
    if isempty(strip(word)) || isempty(strip(concept))
        throw_thesaurus_error("Cannot compare empty word/concept", "cross_type_similarity")
    end
    word_lower    = lowercase(strip(word))
    concept_lower = lowercase(strip(concept))
    concept_tokens = split(concept_lower)

    # GRUG check 0: seed synonym check for word against each concept token
    for tok in concept_tokens
        score = synonym_lookup(word_lower, String(tok))
        if score >= SYNONYM_SEED_THRESHOLD
            return min(1.0, score * 0.9)  # GRUG: Slight discount - it's still cross-type
        end
    end

    # GRUG check 1: word is exact token in concept (check BEFORE substring)
    if word_lower in concept_tokens
        return 0.85
    end

    # GRUG check 2: is word substring of concept?
    if occursin(word_lower, concept_lower)
        return 0.9
    end

    # GRUG check 3: is concept substring of word?
    if occursin(concept_lower, word_lower)
        return 0.7
    end

    # GRUG check 4: acronym detection!
    # "AI" -> "artificial intelligence" matches first letters of each token
    word_letters  = collect(word_lower)
    acronym_match = true
    if length(word_letters) >= 2 && length(word_letters) == length(concept_tokens)
        for (i, token) in enumerate(concept_tokens)
            if length(token) > 0 && word_letters[i] != token[1]
                acronym_match = false
                break
            end
        end
        if acronym_match
            return 0.95  # GRUG high confidence: full acronym match
        end
    end

    # GRUG check 5: partial acronym (word shorter than tokens)
    # "AI" matches first 2 tokens of a 3-token concept
    if length(word_letters) >= 2 && length(word_letters) <= length(concept_tokens)
        partial_match = true
        for (i, letter) in enumerate(word_letters)
            if i > length(concept_tokens)
                partial_match = false
                break
            end
            token = concept_tokens[i]
            if length(token) == 0 || letter != token[1]
                partial_match = false
                break
            end
        end
        if partial_match
            # GRUG scale by coverage ratio plus base confidence
            return 0.85 * (length(word_letters) / length(concept_tokens)) + 0.1
        end
    end

    # GRUG fallback: compare word to each token individually
    best_sim = 0.0
    for token in concept_tokens
        sim = word_similarity(word, String(token))
        best_sim = max(best_sim, sim)
    end

    # GRUG also try bigram similarity with full concept
    ngram_sim = word_similarity(word, concept; ngram_size=2)

    return max(best_sim, ngram_sim * 0.8)
end

# ============================================================================
# MAIN THESAURUS COMPARE - The big function that does it all
# ============================================================================

function thesaurus_compare(input1::AbstractString, input2::AbstractString;
                           context1::Vector{String}   = String[],
                           context2::Vector{String}   = String[],
                           semantic_weight::Float64   = DEFAULT_SEMANTIC_WEIGHT,
                           contextual_weight::Float64 = DEFAULT_CONTEXTUAL_WEIGHT,
                           associative_weight::Float64 = DEFAULT_ASSOCIATIVE_WEIGHT)::ThesaurusResult
    weight_sum = semantic_weight + contextual_weight + associative_weight
    if abs(weight_sum - 1.0) > 0.001
        throw_thesaurus_error("Weights must sum to 1.0, got $weight_sum", "thesaurus_compare")
    end
    if isempty(strip(input1)) || isempty(strip(input2))
        throw_thesaurus_error("Cannot compare empty inputs", "thesaurus_compare")
    end

    is_word1 = !occursin(" ", strip(input1))
    is_word2 = !occursin(" ", strip(input2))

    if is_word1 && is_word2
        match_type  = "word-word"
        # GRUG: Use synonym_lookup (seed-aware) instead of raw word_similarity
        semantic    = synonym_lookup(input1, input2)
        associative = 0.0
    elseif !is_word1 && !is_word2
        match_type  = "concept-concept"
        semantic    = concept_similarity(input1, input2)
        associative = 0.0
    else
        match_type = "cross-type"
        if is_word1
            semantic = cross_type_similarity(input1, input2)
        else
            semantic = cross_type_similarity(input2, input1)
        end
        associative = semantic
    end

    contextual = context_similarity(context1, context2)

    # GRUG compute overall - contextual only matters if provided
    if match_type == "cross-type"
        overall = semantic_weight * semantic + contextual_weight * contextual + associative_weight * associative
    else
        if isempty(context1) && isempty(context2)
            overall = semantic
        else
            adjusted_semantic = semantic_weight + associative_weight
            overall = adjusted_semantic * semantic + contextual_weight * contextual
        end
    end

    # GRUG confidence: short inputs or missing context reduce confidence
    confidence = 1.0
    if length(strip(input1)) < 3 || length(strip(input2)) < 3
        confidence *= 0.8
    end
    if isempty(context1) || isempty(context2)
        confidence *= 0.9
    end

    details = Dict{String, Any}(
        "input1"            => String(input1),
        "input2"            => String(input2),
        "is_word1"          => is_word1,
        "is_word2"          => is_word2,
        "context1_provided" => !isempty(context1),
        "context2_provided" => !isempty(context2),
        "weights_used"      => Dict(
            "semantic"    => semantic_weight,
            "contextual"  => contextual_weight,
            "associative" => associative_weight
        )
    )

    return ThesaurusResult(overall, semantic, contextual, associative, match_type, confidence, details)
end

# ============================================================================
# FORMAT INTENSITY - Turn number into human words
# ============================================================================

function format_thesaurus_intensity(score::Float64)::String
    if score < 0.0 || score > 1.0
        throw_thesaurus_error("Score must be between 0.0 and 1.0, got $score", "format_thesaurus_intensity")
    end
    if score >= 0.95
        return "IDENTICAL"
    elseif score >= 0.85
        return "VERY HIGH"
    elseif score >= 0.70
        return "HIGH"
    elseif score >= 0.50
        return "MEDIUM"
    elseif score >= 0.30
        return "LOW"
    elseif score >= 0.15
        return "VERY LOW"
    else
        return "NEGLIGIBLE"
    end
end

# ============================================================================
# BATCH COMPARE - Compare one thing to many things at once
# ============================================================================

function thesaurus_batch_compare(target::AbstractString, candidates::Vector{<:AbstractString};
                                  target_context::Vector{String}              = String[],
                                  candidate_contexts::Vector{Vector{String}} = Vector{Vector{String}}())::Vector{Tuple{String, ThesaurusResult}}
    if isempty(strip(target))
        throw_thesaurus_error("Target cannot be empty", "thesaurus_batch_compare")
    end
    if isempty(candidates)
        throw_thesaurus_error("Candidates list cannot be empty", "thesaurus_batch_compare")
    end
    results = Vector{Tuple{String, ThesaurusResult}}()
    for (i, candidate) in enumerate(candidates)
        ctx    = isempty(candidate_contexts) ? String[] : (i <= length(candidate_contexts) ? candidate_contexts[i] : String[])
        result = thesaurus_compare(target, candidate; context1 = target_context, context2 = ctx)
        push!(results, (String(candidate), result))
    end
    sort!(results, by = x -> x[2].overall, rev = true)
    return results
end

# ============================================================================
# RUNTIME SEED SYNONYM REGISTRATION
# GRUG: _SEED_SYNONYMS_RAW is hardcoded at load time. But /loadSpecimen and
# future CLI commands need to add seed synonyms at runtime without restarting.
# add_seed_synonym!() patches SYNONYM_SEED_MAP live — same bidirectional
# insertion logic as _build_seed_map!(), just for one entry at a time.
# ============================================================================

const SEED_MAP_LOCK = ReentrantLock()

"""
add_seed_synonym!(canonical::AbstractString, synonyms::Vector{<:AbstractString})

GRUG: Register a new seed synonym group at runtime.
canonical is the root word. synonyms is the list of words that mean the same thing.
Bidirectional: canonical→synonyms AND each synonym→canonical AND each synonym→other synonyms.
Thread-safe via SEED_MAP_LOCK. No silent failures.
"""
function add_seed_synonym!(canonical::AbstractString, synonyms::Vector{<:AbstractString})
    can = lowercase(strip(String(canonical)))
    if isempty(can)
        throw_thesaurus_error("Cannot add seed synonym with empty canonical word", "add_seed_synonym!")
    end
    if isempty(synonyms)
        throw_thesaurus_error("Cannot add seed synonym with empty synonyms list for '$can'", "add_seed_synonym!")
    end

    syns = Set{String}()
    for s in synonyms
        cleaned = lowercase(strip(String(s)))
        if isempty(cleaned)
            throw_thesaurus_error("Cannot add empty synonym string for canonical '$can'", "add_seed_synonym!")
        end
        push!(syns, cleaned)
    end

    lock(SEED_MAP_LOCK) do
        # GRUG: canonical -> all its synonyms
        if !haskey(SYNONYM_SEED_MAP, can)
            SYNONYM_SEED_MAP[can] = Set{String}()
        end
        union!(SYNONYM_SEED_MAP[can], syns)

        # GRUG: each synonym -> canonical AND all other synonyms (full bidirectional)
        for syn in syns
            if !haskey(SYNONYM_SEED_MAP, syn)
                SYNONYM_SEED_MAP[syn] = Set{String}()
            end
            push!(SYNONYM_SEED_MAP[syn], can)
            # GRUG: Also add all other synonyms of the same canonical
            others = filter(s -> s != syn, syns)
            union!(SYNONYM_SEED_MAP[syn], others)
        end
    end

    return length(syns)
end

"""
seed_synonym_count()::Int

GRUG: How many unique words are in the seed synonym map? For diagnostics.
"""
function seed_synonym_count()::Int
    return length(SYNONYM_SEED_MAP)
end

# ============================================================================
# GRUG v8.17: SYSTEM-WIDE STEMMING / NORMALIZATION
# GRUG say: words come in many shapes — "atoms" ≠ "atom" in old code.
#           That bad. Plurals, verb conjugations, gerunds — all should
#           fold to base form so "explain atoms" matches node "atom",
#           "rivers" matches "river", "running" matches "run", etc.
# GRUG say: NOT a real Porter stemmer — too aggressive, turns "atom"
#           into "atom" but also "universal" into "univers". Bad for
#           semantic matching. Instead: rule-based inflection stripper
#           that only strips COMMON, SAFE English suffixes. If unsure,
#           return the word unchanged. False negatives (missed stems)
#           are cheap; false positives (wrong stems) are expensive.
# ============================================================================

# GRUG: Irregular plurals that rule-based stripping gets wrong.
# "men" → "man", "feet" → "foot", etc. Must come before suffix rules.
const _IRREGULAR_PLURALS = Dict{String, String}(
    "men"      => "man",
    "women"    => "woman",
    "children" => "child",
    "feet"     => "foot",
    "teeth"    => "tooth",
    "geese"    => "goose",
    "mice"     => "mouse",
    "lice"     => "louse",
    "oxen"     => "ox",
    "people"   => "person",
    "criteria" => "criterion",
    "phenomena"=> "phenomenon",
    "data"     => "datum",
    "dice"     => "die",
    "indices"  => "index",
    "vertices" => "vertex",
    "matrices" => "matrix",
)

# GRUG: Irregular verb forms — past tense / gerund / participle → base.
# Only the most common ones. Regular forms handled by suffix rules.
const _IRREGULAR_VERBS = Dict{String, String}(
    "was"      => "be",
    "were"     => "be",
    "been"     => "be",
    "am"       => "be",
    "is"       => "be",
    "are"      => "be",
    "had"      => "have",
    "has"      => "have",
    "did"      => "do",
    "does"     => "do",
    "went"     => "go",
    "gone"     => "go",
    "goes"     => "go",
    "came"     => "come",
    "took"     => "take",
    "taken"    => "take",
    "takes"    => "take",
    "gave"     => "give",
    "given"    => "give",
    "gives"    => "give",
    "made"     => "make",
    "makes"    => "make",
    "knew"     => "know",
    "known"    => "know",
    "knows"    => "know",
    "thought"  => "think",
    "thinks"   => "think",
    "saw"      => "see",
    "seen"     => "see",
    "sees"     => "see",
    "said"     => "say",
    "says"     => "say",
    "told"     => "tell",
    "tells"    => "tell",
    "found"    => "find",
    "finds"    => "find",
    "got"      => "get",
    "gets"     => "get",
    "felt"     => "feel",
    "feels"    => "feel",
    "ran"      => "run",
    "runs"     => "run",
    "spoke"    => "speak",
    "spoken"   => "speak",
    "wrote"    => "write",
    "written"  => "write",
    "writes"   => "write",
    "ate"      => "eat",
    "eaten"    => "eat",
    "drank"    => "drink",
    "drunk"    => "drink",
    "slept"    => "sleep",
    "swept"    => "sweep",
    "kept"     => "keep",
    "left"     => "leave",
    "brought"  => "bring",
    "bought"   => "buy",
    "caught"   => "catch",
    "taught"   => "teach",
    "fought"   => "fight",
    "sought"   => "seek",
    "stood"    => "stand",
    "understood" => "understand",
    "meant"    => "mean",
    "met"      => "meet",
    "led"      => "lead",
    "fed"      => "feed",
    "bred"     => "breed",
    "fled"     => "flee",
    "sped"     => "speed",
    "shed"     => "shed",
    "lit"      => "light",
    "sat"      => "sit",
    "won"      => "win",
    "lost"     => "lose",
    "hung"     => "hang",
    "shrank"   => "shrink",
    "shrunk"   => "shrink",
    "sang"     => "sing",
    "sung"     => "sing",
    "rang"     => "ring",
    "rung"     => "ring",
    "swam"     => "swim",
    "swum"     => "swim",
    "began"    => "begin",
    "begun"    => "begin",
    "showed"   => "show",
    "shown"    => "show",
    "grew"     => "grow",
    "grown"    => "grow",
    "drew"     => "draw",
    "drawn"    => "draw",
    "threw"    => "throw",
    "thrown"   => "throw",
    "blew"     => "blow",
    "blown"    => "blow",
    "flew"     => "fly",
    "flown"    => "fly",
    "knew"     => "know",
    "arose"    => "arise",
    "arisen"   => "arise",
    "chose"    => "choose",
    "chosen"   => "choose",
    "bore"     => "bear",
    "born"     => "bear",
    "wore"     => "wear",
    "worn"     => "wear",
    "tore"     => "tear",
    "torn"     => "tear",
    "drove"    => "drive",
    "driven"   => "drive",
    "rose"     => "rise",
    "risen"    => "rise",
    "broke"    => "break",
    "broken"   => "break",
    "spoke"    => "speak",
    "froze"    => "freeze",
    "frozen"   => "freeze",
    "woke"     => "wake",
    "woken"    => "wake",
    "shook"    => "shake",
    "took"     => "take",
    "stole"    => "steal",
    "stolen"   => "steal",
    "swore"    => "swear",
    "sworn"    => "swear",
    "strove"   => "strive",
    "striven"  => "strive",
    "wove"     => "weave",
    "woven"    => "weave",
    "hid"      => "hide",
    "hidden"   => "hide",
    "bit"      => "bite",
    "bitten"   => "bite",
    "fell"     => "fall",
    "fallen"   => "fall",
    "held"     => "hold",
    "told"     => "tell",
    "sent"     => "send",
    "spent"    => "spend",
    "built"    => "build",
    "dealt"    => "deal",
    "meant"    => "mean",
    "heard"    => "hear",
    "learned"  => "learn",
    "learnt"   => "learn",
)

# GRUG: Words that should NOT be stripped by suffix rules because the
# result would be a different valid word or a non-word.
# "atoms" → "atom" is good, but "universe" → "univers" is bad,
# "being" → "be" changes meaning, "doing" → "do" loses gerund sense.
# This is a blacklist — if the stem would produce one of these,
# skip the suffix stripping.
const _STEM_BLACKLIST = Set([
    "being", "doing", "having", "going", "coming", "seeing",
    "knowing", "feeling", "thinking", "getting", "making",
    "finding", "telling", "saying", "keeping", "leaving",
    "meaning", "meeting", "dealing", "reading", "leading",
    "universe", "universal", "diverse", "diversity", "inverse",
    "converse", "reverse", "perverse", "adverse", "averse",
    "promise", "compromise", "enterprise", "surprise", "arise",
    "arouse", "cause", "because", "clause", "pause", "applause",
    "house", "mouse", "douse", "rouse", "course", "resource",
    "force", "source", "substance", "distance", "instance",
])

"""
    stem_token(word::AbstractString) -> String

GRUG: Normalize a single token to its base form. Applies:
  1. Irregular plural lookup (men → man, children → child)
  2. Irregular verb lookup (was → be, went → go, knew → know)
  3. Regular plural stripping (atoms → atom, rivers → river)
  4. Regular verb suffix stripping (running → run, explained → explain)
  5. Blacklist check — if the word is in _STEM_BLACKLIST, return unchanged

Rules are deliberately conservative. False negatives (missed stem) are
cheap — the thesaurus gate expansion and seed synonyms still provide
alternate paths. False positives (wrong stem) are expensive — they
cause semantic conflation. When in doubt, return the word unchanged.

Special: sigil tokens (&n, &op, etc.) are returned unchanged — they
are not natural language words and must not be mangled.
"""
function stem_token(word::AbstractString)::String
    w = lowercase(strip(word))
    isempty(w) && return w

    # GRUG: Sigil tokens pass through unchanged — &n, &op, &being etc.
    # These are pattern holes, not natural language.
    length(w) >= 2 && w[1] == '&' && return word

    # GRUG: Very short words — no safe suffix to strip.
    length(w) <= 2 && return w

    # GRUG: Check blacklist FIRST — these words must not be mangled.
    w in _STEM_BLACKLIST && return w

    # GRUG: Irregular plurals — check before suffix rules.
    if haskey(_IRREGULAR_PLURALS, w)
        return _IRREGULAR_PLURALS[w]
    end

    # GRUG: Irregular verbs — past/gerund/participle → base.
    if haskey(_IRREGULAR_VERBS, w)
        return _IRREGULAR_VERBS[w]
    end

    # GRUG: Regular plural stripping — only safe, common patterns.
    # "atoms" → "atom" (drop -s)
    # "rivers" → "river" (drop -s)
    # "boxes" → "box" (drop -es after x/s/z)
    # "wishes" → "wish" (drop -es after sh/ch)
    # "countries" → "country" (-ies → -y)
    # "leaves" → "leaf" (-ves → -f) — irregular, but common enough
    # DO NOT strip -s if the result would be a different common word
    # (e.g., "us" ≠ "u", "yes" ≠ "ye", "bus" ≠ "bu")

    if length(w) >= 4 && endswith(w, "ies")
        # "countries" → "country", "stories" → "story"
        candidate = w[1:end-3] * "y"
        # GRUG: Sanity — candidate must be shorter and sensible
        length(candidate) >= 3 && return candidate
    end

    if length(w) >= 4 && endswith(w, "ves")
        # "leaves" → "leaf", "wolves" → "wolf", "lives" → "life"
        # But NOT "gives" → "gif" or "drives" → "drif"
        # Only for common f→ves pattern words
        _fves_candidates = Dict(
            "leaves" => "leaf", "wolves" => "wolf", "calves" => "calf",
            "halves" => "half", "knives" => "knife", "lives" => "life",
            "wives" => "wife", "shelves" => "shelf", "selves" => "self",
            "thieves" => "thief", "loaves" => "loaf",
        )
        if haskey(_fves_candidates, w)
            return _fves_candidates[w]
        end
    end

    if length(w) >= 4 && endswith(w, "es")
        # "boxes" → "box", "wishes" → "wish", "passes" → "pass"
        # "watches" → "watch", "judges" → "judge"
        # But NOT "bees" → "be", "sees" → "se", "yes" → "ye"
        candidate = w[1:end-2]
        # GRUG: Only accept if candidate is at least 3 chars and
        # the -es follows s/x/z/sh/ch pattern
        pre = w[end-2:end-2]  # char before "es"
        if length(candidate) >= 3 && (pre in ['s','x','z'] || endswith(w[1:end-2], "sh") || endswith(w[1:end-2], "ch"))
            return candidate
        end
    end

    if length(w) >= 3 && endswith(w, "s") && !endswith(w, "ss") && !endswith(w, "us")
        # "atoms" → "atom", "rivers" → "river", "feelings" → "feeling"
        # But NOT "bus" → "bu", "yes" → "ye", "us" → "u", "gas" → "ga"
        # Also NOT "loss" → "los", "class" → "clas" (ss words)
        candidate = w[1:end-1]
        length(candidate) >= 2 && return candidate
    end

    # GRUG: Regular verb suffix stripping — conservative rules only.
    # "running" → "run" (drop -ning → double-consonant check)
    # "explaining" → "explain" (drop -ing)
    # "explained" → "explain" (drop -ed)
    # "computes" → "compute" (drop -s — already handled above by plural rule)
    # DO NOT strip if it would produce a different common word.

    if length(w) >= 5 && endswith(w, "ing")
        candidate = w[1:end-3]
        if length(candidate) >= 3
            # GRUG: Doubled consonant — "running" → "runn" → "run"
            # If candidate ends with doubled consonant, try stripping one
            if length(candidate) >= 2 && candidate[end] == candidate[end-1] &&
               candidate[end] in 'b':'z'
                return candidate[1:end-1]
            end
            return candidate
        end
    end

    if length(w) >= 4 && endswith(w, "ed")
        candidate = w[1:end-2]
        if length(candidate) >= 3
            # GRUG: Doubled consonant — "planned" → "plann" → "plan"
            if length(candidate) >= 2 && candidate[end] == candidate[end-1] &&
               candidate[end] in 'b':'z'
                return candidate[1:end-1]
            end
            return candidate
        end
    end

    # GRUG: No safe stripping found — return word unchanged.
    return w
end

"""
    normalize_tokens(tokens) -> Set{String}

GRUG: Apply stemming to a collection of tokens, returning a set that
includes BOTH the original tokens AND their stemmed forms. This way,
"atoms" produces {"atoms", "atom"} — the original is preserved for
exact matching while the stem enables cross-form matching.
"""
function normalize_tokens(tokens)::Set{String}
    result = Set{String}()
    for tok in tokens
        s = String(tok)  # GRUG: SubString{String} → String for Set{String}
        push!(result, s)
        stemmed = stem_token(s)
        if stemmed != s
            push!(result, stemmed)
        end
    end
    return result
end

"""
    stem_expand_text(text::String) -> Set{String}

GRUG: Tokenize text, apply stemming, and return expanded set with
both original and stemmed tokens. Used by _lexical_overlap_confidence
to normalize both input and pattern tokens before comparison.
"""
function stem_expand_text(text::String)::Set{String}
    isempty(strip(text)) && return Set{String}()
    tokens = filter(!isempty, map(t -> lowercase(strip(t)), split(text)))
    return normalize_tokens(tokens)
end

# GRUG say: module done! Seed synonyms bridge structural gap. Gate filter ready for scan.
# GRUG say: Runtime seeds via add_seed_synonym!() keep cave growing without restart.
# GRUG say: v8.17 stemming — "atoms" matches "atom" now. System-wide. Happy Grug.

end # module Thesaurus