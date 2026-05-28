# Thesaurus.jl - GRUG Dimensional thesaurus for words, concepts, and contexts
# GRUG say: words is words, but concepts is bigger ideas. This module compare them all.
# GRUG say: similarity not just one number, but many dimensions. Like looking at thing from different angles.
# GRUG say: NEW - seed synonym dictionary! happy/joyful, fast/quick. Structural gap bridged!
# GRUG say: NEW - gate filter! Give Grug input tokens, get back expanded set for better scan matching.

module Thesaurus

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
    ("afraid",      ["scared", "fearful", "terrified", "anxious", "nervous", "worried"]),
    ("tired",       ["weary", "fatigued", "exhausted", "sleepy", "drained"]),
    ("surprised",   ["shocked", "astonished", "amazed", "stunned", "startled"]),
    ("confused",    ["puzzled", "baffled", "perplexed", "bewildered", "lost"]),
    ("excited",     ["thrilled", "eager", "enthusiastic", "keen", "animated"]),
    ("calm",        ["peaceful", "serene", "tranquil", "relaxed", "composed"]),
    ("brave",       ["courageous", "bold", "fearless", "daring", "heroic"]),

    # Speed / size / degree
    ("fast",        ["quick", "rapid", "swift", "speedy", "hasty", "brisk"]),
    ("slow",        ["sluggish", "gradual", "leisurely", "unhurried", "plodding"]),
    ("big",         ["large", "huge", "enormous", "vast", "massive", "gigantic"]),
    ("small",       ["tiny", "little", "miniature", "minute", "compact", "petite"]),
    ("strong",      ["powerful", "mighty", "robust", "sturdy", "tough", "solid"]),
    ("weak",        ["feeble", "frail", "fragile", "delicate", "powerless"]),
    ("hard",        ["difficult", "tough", "challenging", "arduous", "strenuous"]),
    ("easy",        ["simple", "effortless", "straightforward", "trivial", "basic"]),
    ("hot",         ["warm", "scorching", "burning", "fiery", "boiling"]),
    ("cold",        ["cool", "freezing", "icy", "chilly", "frigid"]),

    # Actions / verbs
    ("run",         ["sprint", "dash", "jog", "race", "rush"]),
    ("walk",        ["stroll", "march", "stride", "wander", "trek"]),
    ("look",        ["see", "observe", "watch", "view", "examine", "inspect"]),
    ("talk",        ["speak", "say", "tell", "chat", "converse", "discuss"]),
    ("think",       ["consider", "ponder", "reflect", "contemplate", "reason"]),
    ("make",        ["create", "build", "construct", "produce", "form", "craft"]),
    ("get",         ["obtain", "acquire", "receive", "gain", "fetch", "retrieve"]),
    ("give",        ["provide", "supply", "offer", "grant", "deliver", "hand"]),
    ("find",        ["discover", "locate", "detect", "uncover", "identify"]),
    ("use",         ["employ", "apply", "utilize", "operate", "leverage"]),
    ("fix",         ["repair", "mend", "correct", "patch", "restore", "resolve"]),
    ("break",       ["shatter", "crack", "destroy", "damage", "ruin", "fracture"]),
    ("start",       ["begin", "initiate", "launch", "commence", "trigger"]),
    ("stop",        ["end", "halt", "cease", "terminate", "finish", "quit"]),
    ("help",        ["assist", "support", "aid", "serve", "facilitate"]),
    ("need",        ["require", "want", "demand", "lack", "desire"]),
    ("show",        ["display", "present", "reveal", "demonstrate", "exhibit"]),
    ("know",        ["understand", "grasp", "comprehend", "recognize", "realize"]),
    ("try",         ["attempt", "endeavor", "strive", "test", "experiment"]),
    ("move",        ["shift", "transfer", "transport", "relocate", "migrate"]),

    # Common nouns
    ("house",       ["home", "dwelling", "residence", "building", "place"]),
    ("car",         ["vehicle", "auto", "automobile", "ride", "truck"]),
    ("food",        ["meal", "dish", "cuisine", "nourishment", "sustenance"]),
    ("water",       ["liquid", "fluid", "drink", "beverage"]),
    ("money",       ["cash", "currency", "funds", "finance", "capital"]),
    ("job",         ["work", "career", "occupation", "profession", "employment"]),
    ("problem",     ["issue", "challenge", "difficulty", "obstacle", "trouble"]),
    ("answer",      ["response", "reply", "solution", "result", "outcome"]),
    ("idea",        ["concept", "notion", "thought", "proposal", "plan"]),
    ("plan",        ["strategy", "scheme", "approach", "method", "design"]),
    ("error",       ["mistake", "fault", "bug", "flaw", "defect", "failure"]),
    ("data",        ["information", "info", "facts", "records", "stats"]),
    ("test",        ["check", "verify", "validate", "examine", "assess"]),
    ("system",      ["framework", "structure", "platform", "architecture"]),
    ("input",       ["query", "request", "prompt", "signal", "message"]),
    ("output",      ["result", "response", "reply", "answer", "product"]),

    # Tech / AI adjacent
    ("learn",       ["train", "study", "adapt", "improve", "evolve"]),
    ("predict",     ["forecast", "estimate", "infer", "anticipate", "project"]),
    ("match",       ["fit", "align", "correspond", "map", "pair", "link"]),
    ("search",      ["find", "scan", "query", "look", "seek", "explore"]),
    ("connect",     ["link", "join", "wire", "attach", "bind", "associate"]),
    ("store",       ["save", "persist", "cache", "record", "keep", "archive"]),
    ("load",        ["read", "fetch", "retrieve", "import", "open"]),
    ("send",        ["transmit", "dispatch", "route", "forward", "push"]),
    ("receive",     ["get", "accept", "collect", "obtain", "pull"]),
    ("delete",      ["remove", "erase", "purge", "drop", "clear", "wipe"]),

    # Science domain — bridging lab/research vocabulary
    ("hypothesis",  ["theory", "conjecture", "assumption", "postulate", "supposition"]),
    ("experiment",  ["test", "trial", "study", "investigation", "procedure"]),
    ("observe",     ["measure", "detect", "monitor", "record", "track"]),
    ("analyze",     ["examine", "study", "evaluate", "assess", "investigate"]),
    ("energy",      ["power", "force", "charge", "capacity", "potential"]),
    ("matter",      ["substance", "material", "mass", "stuff", "element"]),
    ("evolve",      ["develop", "adapt", "change", "mutate", "transform", "progress"]),
    ("cause",       ["trigger", "produce", "generate", "induce", "create", "lead"]),
    ("effect",      ["result", "outcome", "consequence", "impact", "product"]),
    ("measure",     ["quantify", "gauge", "assess", "calculate", "evaluate"]),

    # Philosophy domain — bridging abstract reasoning vocabulary
    ("truth",       ["fact", "reality", "validity", "actuality", "verity"]),
    ("knowledge",   ["understanding", "insight", "wisdom", "awareness", "cognition"]),
    ("belief",      ["conviction", "opinion", "view", "stance", "position", "faith"]),
    ("logic",       ["reasoning", "rationale", "deduction", "inference", "argument"]),
    ("exist",       ["be", "live", "occur", "subsist", "persist", "remain"]),
    ("consciousness", ["awareness", "perception", "sentience", "mindfulness", "cognition"]),
    ("ethical",     ["moral", "principled", "righteous", "virtuous", "just"]),
    ("abstract",    ["theoretical", "conceptual", "intangible", "hypothetical", "notional"]),
    ("argue",       ["debate", "reason", "contend", "assert", "claim", "posit"]),
    ("question",    ["query", "inquiry", "challenge", "doubt", "interrogate", "probe"]),
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
thesaurus_gate_filter(input_text) -> Set{String}

GRUG: Pre-scan gate expansion. Turns input tokens into a rich synonym cloud.
Used by process_mission gate before scan_and_expand runs.
Each token expands to at most GATE_MAX_EXPANSIONS_PER_TOKEN synonyms (sorted by seed priority).
Returns combined set of original tokens + expansions (all lowercase).
"""
function thesaurus_gate_filter(input_text::AbstractString)::Set{String}
    if isempty(strip(input_text))
        throw_thesaurus_error("Cannot filter empty input", "thesaurus_gate_filter")
    end

    tokens = filter(!isempty, map(t -> lowercase(strip(t)), split(input_text)))
    expanded = Set{String}(tokens)  # GRUG: Start with originals, add synonyms on top

    for tok in tokens
        syns = get_seed_synonyms(tok)
        # GRUG: Take up to GATE_MAX_EXPANSIONS_PER_TOKEN synonyms.
        # Seed synonyms are already sorted alphabetically - that's fine,
        # all seed entries are high quality. Take first N.
        count = 0
        for syn in syns
            count >= GATE_MAX_EXPANSIONS_PER_TOKEN && break
            push!(expanded, syn)
            count += 1
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

# GRUG say: module done! Seed synonyms bridge structural gap. Gate filter ready for scan.
# GRUG say: Runtime seeds via add_seed_synonym!() keep cave growing without restart.

# ============================================================================
# CONCEPT CLASSES (v7.16.0)
# GRUG: Synonyms are word-to-word with intensity scores ("happy ~ joyful at 0.8").
# Concept classes are different: a NAMED EQUIVALENCE GROUP where every member
# stands in for the concept equally. No intensity ranking -- you are in the
# class or you are not.
#
# Example:
#   CONCEPT_CLASS["inquiry"] = {question, ask, query, probe, wonder,
#                                investigate, interrogate}
# Any of those words, when seen, signals "inquiry". During synthesis, the
# orchestrator can widen its vocabulary by pulling ALL members of the class
# containing the seed word.
#
# Structural difference from synonyms:
#   - Synonyms: pairwise bidirectional, intensity-weighted (0.0-1.0)
#   - Concepts: named-group, flat equivalence (in or out), no intensity
#
# Both coexist. _pick_synonym in Main.jl consults BOTH:
#   1. Thesaurus.SYNONYM_SEED_MAP (pairwise)
#   2. Thesaurus.CONCEPT_CLASS_MEMBERS (concept-group)
#   3. SemanticVerbs._SYNONYM_MAP (runtime alias->canonical)
# ============================================================================

# GRUG: Main registry. concept_name -> Set{String} of equivalent members.
const CONCEPT_CLASS_MEMBERS = Dict{String, Set{String}}()

# GRUG: Reverse index. word -> Set{String} of concept names it belongs to.
# A word can belong to MULTIPLE concepts (e.g. "probe" is both :inquiry
# and :tool). Rebuilt on every mutation -- readers pay zero cost.
const CONCEPT_CLASS_REVERSE = Dict{String, Set{String}}()

# GRUG: Lock guards BOTH dicts. One lock, consistent writes.
const CONCEPT_CLASS_LOCK = ReentrantLock()

# GRUG: Seeded concept classes. These cover common orchestration needs where
# the synonym seed map misses because the words aren't pairwise-similar but
# ARE semantically interchangeable in AIML context.
const _SEED_CONCEPT_CLASSES_RAW = [
    # INQUIRY: verbs of asking, probing, seeking
    ("inquiry",       ["question", "ask", "query", "probe", "wonder",
                       "investigate", "interrogate", "inquire", "seek"]),

    # ASSISTANCE: verbs of helping / supporting action
    ("assistance",    ["help", "assist", "aid", "support", "guide",
                       "facilitate", "back", "bolster"]),

    # DANGER: nouns/adjectives of threat
    ("danger",        ["danger", "threat", "risk", "hazard", "peril",
                       "menace", "jeopardy"]),

    # AGREEMENT: verbs of assent / validation
    ("agreement",     ["agree", "accept", "endorse", "affirm", "confirm",
                       "consent", "concur", "validate"]),

    # REFUSAL: verbs of denial / rejection
    ("refusal",       ["refuse", "reject", "deny", "decline", "dismiss",
                       "repudiate", "veto"]),

    # INVESTIGATION: methodical inquiry (meatier than bare "inquiry")
    ("investigation", ["investigate", "examine", "analyze", "study",
                       "research", "inspect", "scrutinize", "explore"]),

    # CHANGE: verbs of transformation
    ("change",        ["change", "alter", "modify", "transform", "shift",
                       "convert", "adjust", "adapt"]),

    # CREATION: verbs of making / producing
    ("creation",      ["create", "make", "build", "produce", "generate",
                       "construct", "forge", "craft"]),

    # DESTRUCTION: verbs of ending / dismantling
    ("destruction",   ["destroy", "ruin", "demolish", "dismantle", "break",
                       "shatter", "wreck", "obliterate"]),

    # UNDERSTANDING: verbs of cognition / comprehension
    ("understanding", ["understand", "comprehend", "grasp", "know",
                       "realize", "recognize", "apprehend", "perceive"]),

    # COMMUNICATION: verbs of speech / signaling
    ("communication", ["say", "tell", "speak", "communicate", "convey",
                       "express", "articulate", "state", "declare"]),

    # EMOTION_POSITIVE: broad "good feeling" concept
    ("emotion_positive", ["happy", "joy", "glad", "content", "pleased",
                          "delighted", "satisfied", "cheerful"]),

    # EMOTION_NEGATIVE: broad "bad feeling" concept
    ("emotion_negative", ["sad", "angry", "afraid", "distressed", "upset",
                          "troubled", "anguished"]),
]

# GRUG: Build seed concept classes at module load time.
function _build_concept_class_seed!()
    for (concept_name, members) in _SEED_CONCEPT_CLASSES_RAW
        clean_name = lowercase(strip(concept_name))
        clean_members = Set{String}()
        for m in members
            cm = lowercase(strip(m))
            isempty(cm) || push!(clean_members, cm)
        end
        CONCEPT_CLASS_MEMBERS[clean_name] = clean_members
        # GRUG: reverse index
        for m in clean_members
            if !haskey(CONCEPT_CLASS_REVERSE, m)
                CONCEPT_CLASS_REVERSE[m] = Set{String}()
            end
            push!(CONCEPT_CLASS_REVERSE[m], clean_name)
        end
    end
end

_build_concept_class_seed!()

"""
    add_concept_class!(concept_name::AbstractString, members::Vector{<:AbstractString})

GRUG v7.16.0: Register or extend a named concept class. concept_name is the
group label (e.g. "inquiry"). members is the list of interchangeable words.
If the class exists, new members are MERGED in (additive, idempotent).
Thread-safe via CONCEPT_CLASS_LOCK. NO SILENT FAILURES -- empty name or
empty members list throws. Returns (concept_name, new_member_count) so the
caller can report how many members are now in the class.
"""
function add_concept_class!(concept_name::AbstractString,
                             members::Vector{<:AbstractString})
    name = lowercase(strip(String(concept_name)))
    if isempty(name)
        throw_thesaurus_error("Concept class name cannot be empty", "add_concept_class!")
    end
    if isempty(members)
        throw_thesaurus_error("Concept class '$name' needs at least one member",
                              "add_concept_class!")
    end

    cleaned = Set{String}()
    for m in members
        cm = lowercase(strip(String(m)))
        if isempty(cm)
            throw_thesaurus_error("Empty member string for concept class '$name'",
                                  "add_concept_class!")
        end
        push!(cleaned, cm)
    end

    lock(CONCEPT_CLASS_LOCK) do
        if !haskey(CONCEPT_CLASS_MEMBERS, name)
            CONCEPT_CLASS_MEMBERS[name] = Set{String}()
        end
        union!(CONCEPT_CLASS_MEMBERS[name], cleaned)
        # GRUG: refresh reverse index for new members
        for m in cleaned
            if !haskey(CONCEPT_CLASS_REVERSE, m)
                CONCEPT_CLASS_REVERSE[m] = Set{String}()
            end
            push!(CONCEPT_CLASS_REVERSE[m], name)
        end
        return (name, length(CONCEPT_CLASS_MEMBERS[name]))
    end
end

"""
    remove_concept_class!(concept_name::AbstractString)::Bool

GRUG v7.16.0: Remove an entire concept class and its members' reverse-index
entries. Returns true if the class existed, false if it didn't. Thread-safe.
"""
function remove_concept_class!(concept_name::AbstractString)::Bool
    name = lowercase(strip(String(concept_name)))
    isempty(name) && return false
    lock(CONCEPT_CLASS_LOCK) do
        haskey(CONCEPT_CLASS_MEMBERS, name) || return false
        members = CONCEPT_CLASS_MEMBERS[name]
        for m in members
            if haskey(CONCEPT_CLASS_REVERSE, m)
                delete!(CONCEPT_CLASS_REVERSE[m], name)
                isempty(CONCEPT_CLASS_REVERSE[m]) && delete!(CONCEPT_CLASS_REVERSE, m)
            end
        end
        delete!(CONCEPT_CLASS_MEMBERS, name)
        return true
    end
end

"""
    serialize_concept_classes() -> Dict{String, Vector{String}}

GRUG: Snapshot the concept-class membership map for persistence.
Sorted output for stable diffs. The reverse map is rebuilt on load
via `restore_concept_classes!` and need not be persisted separately.
"""
function serialize_concept_classes()::Dict{String, Vector{String}}
    out = Dict{String, Vector{String}}()
    lock(CONCEPT_CLASS_LOCK) do
        for (name, members) in CONCEPT_CLASS_MEMBERS
            out[name] = sort(collect(members))
        end
    end
    return out
end

"""
    restore_concept_classes!(data::AbstractDict) -> Int

GRUG: Wipe the concept-class registry and rehydrate from a snapshot.
Returns the number of classes restored. The reverse map is rebuilt
in-place. Tolerant of malformed entries (skipped, not fatal).
"""
function restore_concept_classes!(data::AbstractDict)::Int
    n = 0
    lock(CONCEPT_CLASS_LOCK) do
        empty!(CONCEPT_CLASS_MEMBERS)
        empty!(CONCEPT_CLASS_REVERSE)
        for (raw_name, raw_members) in data
            name = lowercase(strip(String(raw_name)))
            isempty(name) && continue
            isa(raw_members, AbstractVector) || continue
            members = Set{String}()
            for m in raw_members
                clean = lowercase(strip(String(m)))
                isempty(clean) || push!(members, clean)
            end
            isempty(members) && continue
            CONCEPT_CLASS_MEMBERS[name] = members
            for m in members
                if !haskey(CONCEPT_CLASS_REVERSE, m)
                    CONCEPT_CLASS_REVERSE[m] = Set{String}()
                end
                push!(CONCEPT_CLASS_REVERSE[m], name)
            end
            n += 1
        end
    end
    return n
end

"""
    get_concept_equivalents(word::AbstractString)::Set{String}

GRUG v7.16.0: Given a word, return the union of all its concept-class
siblings (members of any class this word belongs to, EXCLUDING the word
itself). Used by Main.jl's _pick_synonym to widen the synonym pool.
Empty set for unknown words. Thread-safe.
"""
function get_concept_equivalents(word::AbstractString)::Set{String}
    clean = lowercase(strip(String(word)))
    isempty(clean) && return Set{String}()
    lock(CONCEPT_CLASS_LOCK) do
        haskey(CONCEPT_CLASS_REVERSE, clean) || return Set{String}()
        out = Set{String}()
        for concept in CONCEPT_CLASS_REVERSE[clean]
            for sibling in CONCEPT_CLASS_MEMBERS[concept]
                sibling == clean || push!(out, sibling)
            end
        end
        return out
    end
end

"""
    concept_classes_of(word::AbstractString)::Set{String}

GRUG v7.16.0: Return the set of concept class names a word belongs to.
For diagnostics and /conceptClass list --word <w>.
"""
function concept_classes_of(word::AbstractString)::Set{String}
    clean = lowercase(strip(String(word)))
    isempty(clean) && return Set{String}()
    lock(CONCEPT_CLASS_LOCK) do
        haskey(CONCEPT_CLASS_REVERSE, clean) || return Set{String}()
        return copy(CONCEPT_CLASS_REVERSE[clean])
    end
end

"""
    list_concept_classes()::Vector{Tuple{String, Vector{String}}}

GRUG v7.16.0: Return all concept classes as (name, sorted members) pairs.
For /conceptClass list CLI and /saveSpecimen serialization.
"""
function list_concept_classes()::Vector{Tuple{String, Vector{String}}}
    lock(CONCEPT_CLASS_LOCK) do
        return [(k, sort!(collect(v))) for (k, v) in CONCEPT_CLASS_MEMBERS]
    end
end

"""
    concept_class_count()::Int

GRUG v7.16.0: How many concept classes exist? For diagnostics.
"""
function concept_class_count()::Int
    lock(CONCEPT_CLASS_LOCK) do
        return length(CONCEPT_CLASS_MEMBERS)
    end
end

end # module Thesaurus