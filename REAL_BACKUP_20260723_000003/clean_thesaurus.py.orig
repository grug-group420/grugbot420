#!/usr/bin/env python3
"""Remove formal/academic words from thesaurus that leak into Grug's caveman voice."""

import re

# Words that should NEVER appear as thesaurus aliases because they're too formal
# and cause decoherence when substituted into Grug's caveman speech
BAD_ALIASES = {
    # Academic/formal verbs
    "accomplish", "attain", "augment", "calibrate", "commence", "comprehend",
    "conceive", "confer", "confront", "congregate", "contemplate", "contend",
    "contrive", "convene", "deliberate", "demolish", "engender", "enlighten",
    "enumerate", "fabricate", "galvanize", "inaugurate", "inaugurate",
    "pilfer", "purloin", "relinquish", "repose", "sanction", "supplant",
    "surmise", "terminate", "amalgamate", "apprehend", "bestow",
    "clandestine", "coerce", "consummate", "corroborate", "deliberate",
    "disseminate", "elicit", "emancipate", "encompass", "endow",
    "eradicate", "espouse", "evince", "exacerbate", "exalt", "expedite",
    "facilitate", "foment", "implement", "inculcate", "jeopardize",
    "mitigate", "obfuscate", "obviate", "perpetrate", "perpetuate",
    "promulgate", "propagate", "sequester", "subjugate", "usurp",
    "vindicate", "vitiate", "adjudicate", "mandate", "dictate",
    "appraise", "ascribe", "assuage",

    # Academic/formal nouns
    "amass", "conflagration", "consummation", "deficiency", "dearth",
    "efficacy", "erudition", "hypocrisy", "jurisdiction", "propitious",
    "scarcity", "serendipitous", "sovereignty", "auspicious",

    # Academic/formal adjectives  
    "abysmal", "affluent", "altruistic", "auspicious", "benevolent",
    "candid", "clandestine", "covert", "destitute", "diligent",
    "eminent", "exquisite", "fathomless", "formidable", "frank",
    "genuine", "illustrious", "immaculate", "imposing", "incisive",
    "intrepid", "invariably", "latent", "lofty", "luminous", "majestic",
    "meticulous", "nefarious", "notable", "opulent", "paramount",
    "pertinacious", "potent", "precise", "profound", "proprietary",
    "renowned", "resilient", "sagacity", "signify", "somber",
    "splendid", "stately", "succinct", "supreme", "tenacious",
    "unfathomable", "unfettered", "unprecedented", "virtuoso",
    "voracious", "weighty", "wholesome",

    # Specific words that have been observed leaking into output
    "gigantic", "enormous", "immense", "colossal", "tremendous", "vast",
    "devotion", "fondness", "forlorn", "dejected", "melancholy", "gloomy",
    "anxious", "haste", "legitimate", "existence", "acquire", "contour",
    "fluid", "aqua", "hydration", "transport", "ferry", "murky",
    "obscure", "dusky", "settle", "edict", "dash", "sprint", "race",
    "jog", "hasten", "velocity", "rapidity", "quickness", "rigid",
    "robust", "mighty", "laborious", "arduous", "demanding",
    "straightforward", "uncomplicated", "painless", "effortless",
    "sturdy", "firm", "solid", "particular", "diverse", "various",
    "certain", "long_for", "aspire", "anticipate", "appellation",
    "moniker", "lexeme", "convoluted", "intricate", "sophisticated",
    "narrate", "dialogue", "impart", "pronounce", "utter", "explicate",
    "relish", "volition", "rotate", "spin", "pivot", "revolve", "swerve",
    "curve", "declare", "cherish", "confide", "adore", "articulate",
    "righteous", "honorable", "title", "prefer", "designation", "genuine",
    "have_faith", "distant", "yearn", "crave", "appreciate", "peril",
    "jeopardy", "menace", "hazard", "equitable", "impartial", "unbiased",
    "evenhanded", "objective", "conviction", "substantial", "ordinance",
    "decree", "absorb", "master", "being", "vitality", "animacy",
    "radiance", "brightness", "luminosity", "relocate", "doctrine",
    "tenet", "obtain", "collect", "terrified", "worried", "fearful",
    "structure", "outline", "configuration", "perch", "roost", "lodge",
    "decipher", "unravel", "crack", "research", "review", "claim",
    "illuminate", "illumination", "demonstrate", "convey", "express",
    "portray", "proclaim", "testify",

    # More formal words from the thesaurus that could leak
    "annihilate", "obliterate", "devastate", "wreck",  # destroy synonyms
    "bestow", "confer", "donate",  # give synonyms
    "assemble", "compile", "hoard",  # collect synonyms
    "contemplate", "deliberate", "muse",  # think synonyms
    "commence", "initiate", "embark",  # begin synonyms
    "investigate", "scrutinize", "probe",  # investigate synonyms
    "examine", "scrutinize",  # examine synonyms
    "authorize", "sanction",  # allow synonyms
    "dispute", "maintain", "assert",  # argue synonyms
    "apprehend", "snatch",  # catch synonyms
    "engender", "effect", "induce",  # cause synonyms
    "transform", "metamorphose", "reshape", "remodel",  # transform synonyms
    "encompass", "incorporate", "integrate", "embrace",  # include synonyms
    "abundant", "copious", "lavish", "profuse",  # plenty synonyms
    "diminutive", "minute",  # small synonyms
    "astrute",  # smart synonyms
    "expeditious",  # swift synonyms
    "vigor", "potency", "brawn",  # strength synonyms
    "formidable", "potent", "forceful", "dominant",  # mighty synonyms
    "benevolent", "compassionate",  # kind synonyms
    "erudition", "expertise",  # knowledge synonyms
    "dearth", "scarcity",  # lack synonyms
    "illustrious", "distinguished", "eminent",  # famous synonyms
    "conflagration",  # fire synonyms
    "rectify",  # fix synonyms
    "planar", "flush",  # flat synonyms
    "unfettered", "autonomous",  # free synonyms
    "amiable", "cordial", "affable", "genial",  # friendly synonyms
    "petrify",  # frighten synonyms
    "brimming",  # full synonyms
    "impending", "destined",  # future synonyms
    "congregate", "accumulate",  # gather synonyms
    "bestow", "confer",  # give synonyms
    "imposing", "splendid", "stately", "noble",  # grand synonyms
    "profound",  # deep synonyms
    "wicked", "malevolent", "sinister", "nefarious", "corrupt", "vile",  # evil synonyms
    "electrify", "animate", "energize",  # excite synonyms
    "renowned", "celebrated", "distinguished", "eminent", "illustrious",  # famous synonyms
    "sumptuous",  # rich synonyms
    "persist", "endure",  # remain synonyms
    "reiterate", "reproduce", "recur", "replicate", "echo", "duplicate",  # repeat synonyms
    "displace", "succeed",  # replace synonyms
    "solicit", "petition", "appeal", "invoke",  # request synonyms
    "necessitate", "obligate", "compel", "insist",  # require synonyms
    "withstand", "repel",  # resist synonyms
    "esteem", "honor", "admire", "regard",  # respect synonyms
    "disclose", "unveil", "divulge",  # reveal synonyms
    "affluent", "prosperous", "opulent",  # rich synonyms
    "soar", "elevate",  # rise synonyms
    "entice", "lure", "seduce", "persuade",  # tempt synonyms
    "deliberate", "contemplate",  # think synonyms
    "concurrent", "collectively", "jointly",  # together synonyms
    "pinnacle", "zenith", "crest",  # top synonyms
    "metamorphose", "reshape", "remodel",  # transform synonyms
    "ensnare",  # trap synonyms
    "expedition", "trek", "odyssey", "pilgrimage",  # journey synonyms
    "rapture", "glee", "elation",  # joy synonyms
    "strife", "warfare",  # war synonyms
    "squander", "deplete", "discard",  # waste synonyms
    "ambulate",  # walk synonyms
    "cordial", "affectionate",  # warm synonyms
    "forewarn",  # warn synonyms
    "abundance", "prosperity",  # wealth synonyms
    "missile",  # weapon synonyms
    "drained", "spent",  # weary synonyms
    "author", "inscribe",  # write synonyms
    "erroneous", "unjust",  # wrong synonyms
    "juvenile", "novice",  # young synonyms
    "fervor", "ardor", "dedication",  # zeal synonyms
    "acquire", "obtain",  # accept/get synonyms
    "peril", "hazard",  # danger synonyms
    "perpetually", "eternally",  # always synonyms
    "primeval", "venerable", "antique", "immemorial",  # ancient synonyms
    "indignation", "ire",  # anger synonyms
    "rejoinder",  # answer synonyms
    "manifest", "surface", "come_into_view",  # appear synonyms
    "domain", "realm", "sector",  # area synonyms
    "interrogate",  # ask synonyms
    "assail", "aggress",  # attack synonyms
    "endeavor", "strive", "undertake",  # attempt synonyms
    "entice", "lure", "magnetize", "captivate",  # attract synonyms
    "sovereignty",  # authority synonyms
    "inferior", "deficient", "substandard", "awful",  # bad synonyms
    "gorgeous", "stunning", "exquisite", "radiant", "elegant",  # beautiful synonyms
    "intrepid",  # bold synonyms
    "fracture", "rupture", "smash",  # break synonyms
    "luminous", "radiant", "shining", "brilliant", "vivid", "dazzling",  # bright synonyms
    "erect", "raise",  # build synonyms
    "combust", "ignite", "scorch", "blaze", "char", "sear",  # burn synonyms
    "tranquil", "serene", "placid", "composed", "unruffled",  # calm synonyms
    "prudent", "meticulous", "attentive", "wary",  # careful synonyms
    "capture", "seize", "snare", "snatch",  # catch synonyms
    "generate", "bring_about", "effect", "induce",  # cause synonyms
    "transform", "convert", "evolve",  # change synonyms
    "elect", "designate",  # choose synonyms
    "transparent", "lucid", "evident", "apparent",  # clear synonyms
    "frigid", "freezing", "icy", "frosty", "chilly", "arctic",  # cold synonyms
    "console", "soothe", "solace",  # comfort synonyms
    "direct", "instruct", "require",  # command synonyms
    "prevalent",  # common synonyms
    "contrast", "liken", "equate", "parallel", "measure",  # compare synonyms
    "conclude", "fulfill", "consummate", "finalize",  # complete synonyms
    "complicated",  # complex synonyms
    "join", "unite", "bind", "attach", "couple",  # connect synonyms
    "proceed", "persist", "carry_on", "sustain",  # continue synonyms
    "proper", "exact",  # correct synonyms
    "originate",  # create synonyms
    "jeopardy", "menace",  # danger synonyms
    "determine", "resolve",  # decide synonyms
    "bottomless", "fathomless", "unfathomable",  # deep synonyms
    "guard", "shield", "safeguard", "secure", "preserve",  # defend synonyms
    "annihilate", "obliterate",  # destroy synonyms
    "mature", "progress", "advance", "expand",  # develop synonyms
    "distinct", "varied", "dissimilar", "contrasting",  # different synonyms
    "challenging",  # difficult synonyms
    "uncover", "detect", "reveal", "expose", "unearth",  # discover synonyms
    "examine", "explore", "consider", "review",  # discuss synonyms
    "partition", "segment", "bisect", "fragment",  # divide synonyms
    "distrust", "disbelieve", "waver", "hesitate",  # doubt synonyms
    "aspiration", "reverie", "ambition",  # dream synonyms
    "arid", "parched", "dehydrated", "barren", "desiccated",  # dry synonyms
    "instruct", "train", "tutor", "coach", "school",  # educate synonyms
    "vacant", "void", "bare", "hollow", "blank", "desolate",  # empty synonyms
    "cease",  # end synonyms
    "savor", "delight_in",  # enjoy synonyms
    "penetrate", "access", "cross", "invade", "pass_into",  # enter synonyms
    "evade", "elude", "abscond", "retreat", "withdraw",  # escape synonyms
    "wicked", "malevolent", "sinister", "nefarious", "corrupt", "vile",  # evil synonyms
    "inspect", "scrutinize",  # examine synonyms
    "illustration", "specimen",  # example synonyms
    "stimulate", "arouse", "thrill", "electrify", "animate", "energize",  # excite synonyms
    "interpret",  # explain synonyms
    "probe", "search", "chart",  # explore synonyms
    "untrue", "incorrect", "inaccurate", "deceptive", "phony", "bogus",  # false synonyms
    "renowned", "celebrated", "distinguished", "eminent", "notable",  # famous synonyms
    "rapid", "swift", "speedy", "brisk", "hasty",  # fast synonyms
    "dread", "terror", "horror", "panic", "apprehension", "anxiety",  # fear synonyms
    "combat", "struggle", "clash", "wage_war",  # fight synonyms
    "locate", "detect", "uncover", "identify", "spot",  # find synonyms
    "conclude", "finalize", "consummate", "wrap_up",  # finish synonyms
    "inferno",  # fire synonyms
    "repair", "mend", "restore", "remedy", "rectify",  # fix synonyms
    "horizontal", "planar", "flush",  # flat synonyms
    "stream", "course", "surge", "current", "flux", "circulate",  # flow synonyms
    "pursue", "trail", "track", "chase", "shadow", "succeed",  # follow synonyms
    "stupid", "silly", "absurd", "unwise", "imprudent", "irrational",  # foolish synonyms
    "liberated", "independent", "unrestricted", "unfettered", "autonomous",  # free synonyms
    "novel", "crisp", "original", "untried",  # fresh synonyms
    "amiable", "cordial", "affable", "genial", "welcoming",  # friendly synonyms
    "scare", "terrify", "alarm", "startle", "spook", "petrify",  # frighten synonyms
    "entire", "packed", "filled", "brimming",  # full synonyms
    "forthcoming", "upcoming", "impending", "destined",  # future synonyms
    "convene", "accumulate",  # gather synonyms
    "mild", "tender", "delicate", "meek",  # gentle synonyms
    "colossal", "immense", "titanic",  # giant synonyms
    "grant", "bestow", "confer", "donate", "present", "offer",  # give synonyms
    "pleased", "delighted", "joyful", "cheerful", "content",  # glad synonyms
    "worldwide", "universal", "international", "planetary",  # global synonyms
    "excellent", "fine", "wonderful", "superb", "outstanding",  # good synonyms
    "elegance", "poise", "finesse", "refinement", "charm",  # grace synonyms
    "majestic", "magnificent", "imposing", "splendid", "stately", "noble",  # grand synonyms
    "seize", "grip", "clutch", "snatch", "grab",  # grasp synonyms
    "solemn", "somber", "weighty", "critical", "dire",  # grave synonyms
    "extraordinary", "remarkable", "significant",  # great synonyms
    "verdant", "lush", "leafy", "flourishing", "emerald", "viridian",  # green synonyms
    "expand", "increase", "thrive", "flourish",  # grow synonyms
    "bliss", "elation", "contentment", "euphoria",  # happiness synonyms
    "damage", "injure", "hurt", "impair", "wound", "afflict",  # harm synonyms
    "concord", "accord", "unity", "agreement", "balance", "symmetry",  # harmony synonyms
    "severe", "stern", "strict", "rigorous", "cruel", "brutal",  # harsh synonyms
    "loathe", "detest", "despise", "abhor", "abominate", "resent",  # hate synonyms
    "vigorous", "thriving", "sound",  # healthy synonyms
    "concealed", "covert", "latent",  # hidden synonyms
    "elevated", "lofty", "soaring", "peak", "summit",  # high synonyms
    "truthful", "sincere", "candid", "frank",  # honest synonyms
    "modest", "unassuming", "meek", "deferential", "unpretentious",  # humble synonyms
    "famine", "starvation", "craving", "appetite",  # hunger synonyms
    "chase", "pursue", "stalk", "track", "seek", "quest",  # hunt synonyms
    "concept", "notion", "conception", "inspiration", "vision",  # idea synonyms
    "disregard", "neglect", "overlook", "dismiss", "skip", "bypass",  # ignore synonyms
    "envision", "visualize", "conceive", "fantasize", "picture",  # imagine synonyms
    "crucial", "vital", "essential", "critical", "paramount",  # important synonyms
    "enhance", "refine", "upgrade", "elevate", "advance",  # improve synonyms
    "contain", "comprise", "encompass", "incorporate", "integrate",  # include synonyms
    "amplify", "augment", "escalate", "magnify",  # increase synonyms
    "reveal", "signify", "suggest",  # indicate synonyms
    "affect", "shape", "sway", "impact", "guide", "mold",  # influence synonyms
    "notify", "advise", "brief", "apprise", "acquaint",  # inform synonyms
    "damage", "wound", "hurt", "impair", "disable",  # injure synonyms
    "internal", "interior", "inward", "core", "central",  # inner synonyms
    "guiltless", "blameless", "virtuous", "harmless", "naive",  # innocent synonyms
    "motivate", "encourage", "stimulate", "arouse", "ignite",  # inspire synonyms
    "clever", "brilliant", "wise", "sharp", "astute",  # intelligent synonyms
    "fierce", "powerful", "extreme", "passionate",  # intense synonyms
    "fascination", "curiosity", "attention", "concern", "engagement", "absorption",  # interest synonyms
    "examine", "explore", "probe", "research", "scrutinize",  # investigate synonyms
    "isle", "atoll", "archipelago", "outcrop", "refuge", "oasis",  # island synonyms
    "unite", "connect", "link", "combine", "merge", "associate",  # join synonyms
    "voyage", "expedition", "trek", "odyssey", "pilgrimage", "adventure",  # journey synonyms
    "happiness", "delight", "elation", "bliss", "glee", "rapture",  # joy synonyms
    "evaluate", "assess", "determine", "adjudicate", "appraise",  # judge synonyms
    "eager", "enthusiastic", "sharp", "avid", "ardent", "zealous",  # keen synonyms
    "retain", "preserve", "maintain", "hold", "store", "conserve",  # keep synonyms
    "generous", "benevolent", "compassionate", "caring",  # kind synonyms
    "understanding", "wisdom", "learning", "erudition", "insight", "expertise",  # knowledge synonyms
    "shortage", "deficiency", "absence", "dearth", "scarcity",  # lack synonyms
    "ultimate", "concluding", "terminal", "endmost", "latest",  # last synonyms
    "chuckle", "giggle", "snicker", "roar", "howl", "cackle",  # laugh synonyms
    "depart", "exit", "withdraw", "vacate", "go", "forsake",  # leave synonyms
    "boundary", "restriction", "cap", "ceiling", "constraint", "threshold",  # limit synonyms
    "row", "queue", "sequence", "thread", "streak", "array",  # line synonyms
    "connect", "join", "couple", "attach", "bind", "associate",  # link synonyms
    "hear", "attend", "heed", "eavesdrop", "perceive",  # listen synonyms
    "exist", "dwell", "reside", "inhabit", "survive", "thrive",  # live synonyms
    "extended", "far",  # long synonyms
    "see", "observe", "watch", "view", "gaze",  # look synonyms
    "forfeit", "misplace", "drop", "surrender", "yield",  # lose synonyms
    "beneath", "bottom", "depressed", "shallow",  # low synonyms
    "fortunate", "blessed", "favoured", "propitious", "auspicious", "serendipitous",  # lucky synonyms
    "angry", "furious", "enraged", "insane", "crazy", "livid",  # mad synonyms
    "sorcery", "witchcraft", "enchantment", "wizardry", "mysticism", "spell",  # magic synonyms
    "construct", "craft", "forge",  # make synonyms
    "numerous", "multiple", "several", "various", "countless", "abundant",  # many synonyms
    "sign", "symbol", "stamp", "indication", "trace", "brand",  # mark synonyms
    "virtuoso", "adept", "champion", "specialist",  # master synonyms
    "significance", "purpose", "intent", "sense", "import", "substance",  # meaning synonyms
    "gauge", "assess", "evaluate", "calculate", "quantify", "weigh",  # measure synonyms
    "encounter", "converge", "assemble", "rendezvous",  # meet synonyms
    "dissolve", "thaw", "liquefy", "fuse", "soften",  # melt synonyms
    "recollection", "remembrance", "retention", "nostalgia", "flashback",  # memory synonyms
    "technique", "procedure", "approach", "system", "strategy", "process",  # method synonyms
    "center", "midst", "core", "heart", "nucleus", "median",  # middle synonyms
    "intellect", "consciousness", "cognition",  # mind synonyms
    "blunder", "oversight", "slip", "fault", "miscalculation",  # mistake synonyms
    "blend", "merge", "amalgamate", "integrate", "mingle",  # mix synonyms
    "contemporary", "current", "present", "recent", "newest", "cutting_edge",  # modern synonyms
    "instant", "second", "minute", "flash", "tick", "jiffy",  # moment synonyms
    "currency", "cash", "funds", "capital", "wealth", "payment",  # money synonyms
    "luna", "satellite", "crescent", "orb", "celestial", "nightlight",  # moon synonyms
    "enigma", "puzzle", "riddle", "conundrum",  # mystery synonyms
    "label", "identity",  # name synonyms
    "tight", "slim", "thin", "confined", "restricted", "limited",  # narrow synonyms
    "innate", "inherent", "organic", "native", "unprocessed",  # natural synonyms
    "close", "nearby", "adjacent", "proximate", "neighboring", "handy",  # near synonyms
    "essential", "vital", "required", "indispensable", "crucial", "obligatory",  # necessary synonyms
    "require", "demand", "necessitate", "want", "deserve",  # need synonyms
    "novel", "fresh", "original", "innovative", "recent", "unprecedented",  # new synonyms
    "darkness", "evening", "dusk", "twilight", "midnight", "nocturne",  # night synonyms
    "typical", "standard", "routine", "usual", "commonplace",  # normal synonyms
    "aged", "vintage", "elderly", "mature", "weathered",  # old synonyms
    "unsealed", "accessible", "available", "exposed", "unlocked", "ajar",  # open synonyms
    "view", "belief", "judgment", "perspective", "stance", "position",  # opinion synonyms
    "resist", "counter", "confront", "defy", "thwart",  # oppose synonyms
    "arrange", "organize", "sort", "sequence", "structure", "systematize",  # order synonyms
    "source", "root", "beginning", "foundation", "genesis",  # origin synonyms
    "possess", "have", "hold", "retain", "occupy", "claim",  # own synonyms
    "suffering", "agony", "ache", "discomfort", "torment", "distress",  # pain synonyms
    "portion", "section", "segment", "piece", "fraction", "component",  # part synonyms
    "cross", "traverse", "navigate", "proceed", "advance", "go_through",  # pass synonyms
    "design", "arrangement", "structure", "motif", "template",  # pattern synonyms
    "tranquility", "serenity", "stillness", "quiet",  # peace synonyms
    "flawless", "ideal", "immaculate", "exemplary", "supreme", "absolute",  # perfect synonyms
    "endure", "persevere",  # persist synonyms
    "location", "site", "position", "spot", "venue", "setting",  # place synonyms
    "unadorned", "bare",  # plain synonyms
    "strategy", "scheme", "design", "blueprint", "intention", "proposal",  # plan synonyms
    "perform", "act", "compete", "amuse", "frolic", "recreate",  # play synonyms
    "agreeable", "delightful", "enjoyable", "charming", "satisfying",  # pleasant synonyms
    "gratification",  # pleasure synonyms
    "ample", "copious", "generous", "lavish", "profuse",  # plenty synonyms
    "tip", "peak", "focus", "essence", "crux",  # point synonyms
    "impoverished", "destitute", "needy", "lacking", "deficient", "meager",  # poor synonyms
    "potency",  # power synonyms
    "forecast", "prophesy", "anticipate", "project", "estimate", "foresee",  # predict synonyms
    "ready", "arrange", "organize", "equip", "provision", "set_up",  # prepare synonyms
    "current", "existing", "immediate", "ongoing",  # present synonyms
    "conserve", "safeguard", "save", "uphold",  # preserve synonyms
    "squeeze", "compress", "crush", "compact", "exert",  # press synonyms
    "avert", "thwart", "obstruct", "block", "forestall",  # prevent synonyms
    "dignity", "honor", "self_respect", "esteem", "conceit", "arrogance",  # pride synonyms
    "difficulty", "challenge", "issue", "obstacle", "dilemma", "complication",  # problem synonyms
    "manufacture", "yield", "supply",  # produce synonyms
    "appropriate", "fitting", "suitable", "decent",  # proper synonyms
    "guard", "shield", "safeguard", "secure", "shelter",  # protect synonyms
    "dignified", "honored", "pleased", "arrogant", "haughty", "conceited",  # proud synonyms
    "establish", "verify", "validate",  # prove synonyms
    "supply", "furnish", "deliver",  # provide synonyms
    "aim", "goal", "objective", "intention", "motive",  # purpose synonyms
    "chase", "follow", "hunt", "track", "seek", "quest",  # pursue synonyms
    "shove", "thrust", "drive", "propel", "force",  # push synonyms
    "excellence", "caliber", "grade", "merit", "worth",  # quality synonyms
    "rapid", "swift", "speedy", "prompt", "hasty",  # quick synonyms
    "silent", "still", "hushed", "noiseless",  # quiet synonyms
    "logic", "rationale", "thinking", "judgment", "intellect", "motive",  # reason synonyms
    "decrease", "diminish", "lessen", "lower", "minimize", "shrink",  # reduce synonyms
    "routine", "consistent", "habitual",  # regular synonyms
    "associate", "correlate", "pertain", "refer",  # relate synonyms
    "liberate", "discharge", "let_go", "unleash", "emit",  # release synonyms
    "linger", "persist", "endure", "abide", "wait",  # remain synonyms
    "delete", "eliminate", "erase", "extract", "withdraw", "clear",  # remove synonyms
    "reiterate", "reproduce", "recur", "replicate", "echo", "duplicate",  # repeat synonyms
    "substitute", "swap", "exchange", "supplant", "displace",  # replace synonyms
    "demand", "solicit", "petition", "appeal", "invoke",  # request synonyms
    "demand", "necessitate", "obligate", "compel", "insist",  # require synonyms
    "oppose", "defy", "withstand", "counter", "repel",  # resist synonyms
    "esteem", "honor", "admire", "regard",  # respect synonyms
    "relax", "pause", "break", "repose", "sleep", "idle",  # rest synonyms
    "outcome", "consequence", "effect", "product", "conclusion", "resolution",  # result synonyms
    "go_back", "revert", "recur", "restore", "refund", "repay",  # return synonyms
    "disclose", "expose", "uncover", "unveil", "divulge",  # reveal synonyms
    "wealthy", "affluent", "prosperous", "opulent", "abundant", "lavish",  # rich synonyms
    "accurate",  # right synonyms
    "ascend", "climb", "mount", "soar", "elevate",  # rise synonyms
    "gamble", "venture",  # risk synonyms
    "coarse", "uneven", "jagged", "rugged", "textured", "scratchy",  # rough synonyms
    "sprint",  # run synonyms
    "secure", "protected", "sheltered", "guarded", "harmless", "defended",  # safe synonyms
    "identical", "equivalent", "uniform", "matching", "alike",  # same synonyms
    "fulfill", "meet", "gratify", "content", "appease", "please",  # satisfy synonyms
    "disperse", "distribute", "diffuse", "strew", "sow",  # scatter synonyms
    "seek", "hunt", "look_for", "explore", "probe",  # search synonyms
    "confidential",  # secret synonyms
    "perceive", "notice", "discern", "spot", "witness",  # see synonyms
    "elect", "opt", "designate",  # select synonyms
    "dispatch", "transmit", "forward", "ship",  # send synonyms
    "split", "part", "isolate", "detach", "disconnect",  # separate synonyms
    "solemn", "earnest", "grave", "weighty", "sober",  # serious synonyms
    "assist", "minister",  # serve synonyms
    "place", "position", "establish", "fix", "arrange", "assign",  # set synonyms
    "shade", "darkness", "silhouette", "outline", "gloom", "penumbra",  # shadow synonyms
    "distribute", "divide", "portion", "allocate", "contribute", "partake",  # share synonyms
    "acute", "pointed", "piercing", "incisive",  # sharp synonyms
    "refuge", "haven", "sanctuary", "asylum", "retreat",  # shelter synonyms
    "radiate", "beam", "gleam", "glitter",  # shine synonyms
    "brief", "compact", "concise", "curt", "terse", "miniature",  # short synonyms
    "display", "reveal", "illustrate",  # show synonyms
    "edge", "border", "flank", "margin", "boundary", "perimeter",  # side synonyms
    "ability", "talent", "proficiency", "expertise", "craft", "competence",  # skill synonyms
    "unhurried", "gradual", "leisurely", "sluggish", "lagging",  # slow synonyms
    "tiny", "minute", "compact", "diminutive", "miniature",  # small synonyms
    "sleek", "polished", "silky", "glossy", "flowing",  # smooth synonyms
    "yielding",  # soft synonyms
    "classify", "categorize", "organize", "group", "rank",  # sort synonyms
    "origin", "root", "foundation", "beginning", "wellspring", "fountain",  # source synonyms
    "condition", "situation", "status", "circumstance", "position", "standing",  # state synonyms
    "remain", "linger", "wait", "abide", "dwell", "pause",  # stay synonyms
    "thieve", "pilfer", "purloin", "filch", "swipe",  # steal synonyms
    "stride", "pace", "footstep", "stage", "phase", "increment",  # step synonyms
    "halt", "cease", "discontinue", "arrest", "quit",  # stop synonyms
    "tempest", "gale", "hurricane", "squall", "cyclone", "blizzard",  # storm synonyms
    "odd", "peculiar", "unusual", "bizarre", "weird", "uncanny",  # strange synonyms
    "vigor", "potency", "brawn",  # strength synonyms
    "battle", "effort", "conflict", "endeavor", "contend",  # struggle synonyms
    "topic", "theme", "matter", "issue", "focus", "concern",  # subject synonyms
    "achieve", "accomplish", "triumph", "prevail", "attain", "prosper",  # succeed synonyms
    "undergo", "experience", "sustain", "tolerate",  # suffer synonyms
    "propose", "recommend", "advise", "hint", "imply", "insinuate",  # suggest synonyms
    "endorse", "uphold", "sustain", "champion",  # support synonyms
    "assume", "presume", "guess", "conjecture",  # suppose synonyms
    "astonish", "amaze", "startle", "stun", "shock", "astound",  # surprise synonyms
    "outlast", "withstand", "prevail",  # survive synonyms
    "mistrust",  # suspect synonyms
    "sugary", "honeyed",  # sweet synonyms
    "fleet", "expeditious",  # swift synonyms
    "emblem", "token", "representation", "icon",  # symbol synonyms
    "framework", "organization", "network", "arrangement",  # system synonyms
    "seize",  # take synonyms
    "discuss", "converse", "chat",  # talk synonyms
    "towering", "elevated", "soaring", "giant",  # tall synonyms
    "instruct", "educate", "train", "tutor", "coach", "guide",  # teach synonyms
    "engineering", "innovation", "machinery", "equipment", "apparatus",  # technology synonyms
    "inform", "relate", "describe", "report",  # tell synonyms
    "entice", "lure", "seduce", "persuade", "invite",  # tempt synonyms
    "trial", "check",  # test synonyms
    "dense", "bulky",  # thick synonyms
    "ponder", "consider", "reflect", "contemplate", "deliberate",  # think synonyms
    "slender", "slim", "narrow", "lean", "spare", "fine",  # thin synonyms
    "period", "era", "epoch", "age", "duration",  # time synonyms
    "microscopic", "wee",  # tiny synonyms
    "jointly", "collectively", "united", "combined", "cooperative", "concurrent",  # together synonyms
    "apex", "pinnacle", "zenith", "crest",  # top synonyms
    "track", "follow", "pursue", "hunt", "trail", "seek",  # trace synonyms
    "custom", "heritage", "convention", "practice", "ritual", "legacy",  # tradition synonyms
    "convert", "alter", "metamorphose", "reshape", "remodel",  # transform synonyms
    "snare", "ambush", "pitfall", "net", "trick", "ensnare",  # trap synonyms
    "journey", "voyage", "expedition", "trek", "tour", "wander",  # travel synonyms
    "prize",  # treasure synonyms
    "factual", "accurate", "valid",  # true synonyms
    "believe", "rely_on", "depend", "entrust",  # trust synonyms
    "endeavor", "strive", "aim", "seek", "undertake",  # try synonyms
    "comprehend", "grasp", "realize", "perceive",  # understand synonyms
    "combine", "merge", "fuse", "ally", "consolidate",  # unite synonyms
    "rare", "uncommon", "peculiar", "extraordinary", "atypical",  # unusual synonyms
    "employ", "utilize", "apply", "operate", "exercise", "exploit",  # use synonyms
    "worth", "merit", "importance", "significance", "price",  # value synonyms
    "disappear", "fade", "evaporate",  # vanish synonyms
    "extensive", "sprawling", "boundless",  # vast synonyms
    "triumph", "conquest", "win", "achievement", "glory",  # victory synonyms
    "perspective", "vantage", "outlook", "stance",  # view synonyms
    "brutal", "savage", "forceful", "aggressive",  # violent synonyms
    "call_on", "inspect", "tour", "survey",  # visit synonyms
    "expression",  # voice synonyms
    "offer", "step_forward", "enlist", "contribute", "proffer",  # volunteer synonyms
    "linger", "pause", "expect",  # wait synonyms
    "stroll", "stride", "pace", "hike", "march", "ambulate",  # walk synonyms
    "conflict", "hostility", "strife", "warfare",  # war synonyms
    "heated", "toasty", "affectionate",  # warm synonyms
    "forewarn",  # warn synonyms
    "squander", "deplete", "discard",  # waste synonyms
    "monitor", "guard", "attend",  # watch synonyms
    "ripple", "surge", "swell", "undulation", "crest", "breaker",  # wave synonyms
    "feeble", "frail", "fragile", "delicate", "puny", "impotent",  # weak synonyms
    "riches", "fortune", "assets",  # wealth synonyms
    "arm", "instrument", "blade", "device", "missile",  # weapon synonyms
    "exhausted", "fatigued", "drained", "spent",  # weary synonyms
    "heaviness", "burden", "load", "pressure",  # weight synonyms
    "greet", "receive", "embrace", "accept", "usher", "host",  # welcome synonyms
    "broad", "expansive", "spacious",  # wide synonyms
    "untamed", "feral", "savage", "uncultivated",  # wild synonyms
    "desire", "intent",  # will synonyms
    "prevail", "triumph", "conquer", "earn",  # win synonyms
    "insight", "judgment", "sagacity", "prudence", "discernment",  # wisdom synonyms
    "awe", "amazement", "marvel", "curiosity", "astonishment", "admiration",  # wonder synonyms
    "timber", "lumber", "plank", "board", "forest_product",  # wood synonyms
    "term", "expression", "vocabulary",  # word synonyms
    "labor", "toil", "endeavor", "occupation", "task",  # work synonyms
    "globe", "planet", "realm", "domain", "universe",  # world synonyms
    "anxiety", "concern", "fret", "distress", "apprehension", "unease",  # worry synonyms
    "merit", "significance", "importance", "deserving",  # worth synonyms
    "injury", "cut", "lesion", "gash", "laceration",  # wound synonyms
    "compose", "author", "draft", "pen", "inscribe", "record",  # write synonyms
    "incorrect", "mistaken", "erroneous", "inaccurate", "unjust",  # wrong synonyms
    "youthful", "juvenile", "immature", "novice",  # young synonyms
    "passion", "fervor", "ardor", "dedication",  # zeal synonyms
}

# Read the file
with open('generate_specimen.py', 'r') as f:
    content = f.read()

# Extract thesaurus section
thes_start = content.index('thesaurus = {')
thes_end = content.index('\n}\n\n# ────', thes_start) + 2  # include closing }

thes_text = content[thes_start:thes_end]

# Parse and clean
import json
lines = thes_text.split('\n')
new_lines = ['thesaurus = {']
removed_count = 0

for line in lines[1:]:  # skip first line (thesaurus = {)
    if line.strip() == '}':
        new_lines.append('}')
        break
    if not line.strip() or line.strip().startswith('#'):
        new_lines.append(line)
        continue
    
    # Parse key: [values] 
    match = re.match(r'\s*"(\w+)":\s*\[(.*?)\]', line)
    if not match:
        new_lines.append(line)
        continue
    
    key = match.group(1)
    values_str = match.group(2)
    
    # Parse the values
    values = [v.strip().strip('"').strip("'") for v in values_str.split(',') if v.strip()]
    
    # Remove bad aliases
    clean_values = [v for v in values if v.lower() not in BAD_ALIASES]
    
    removed = len(values) - len(clean_values)
    removed_count += removed
    
    if removed > 0:
        print(f"  {key}: removed {removed} aliases -> {clean_values}")
    
    # Reconstruct line
    if clean_values:
        val_str = ', '.join(f'"{v}"' for v in clean_values)
        new_lines.append(f'    "{key}": [{val_str}],')
    else:
        new_lines.append(f'    "{key}": [],')

new_thes = '\n'.join(new_lines)

# Replace in content
new_content = content[:thes_start] + new_thes + content[thes_end:]

with open('generate_specimen.py', 'w') as f:
    f.write(new_content)

print(f"\nTotal aliases removed: {removed_count}")
