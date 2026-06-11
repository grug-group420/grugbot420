# =============================================================================
# InputDecomposer.jl — splits compound user input into independent clauses
# =============================================================================
#
# GRUG v7.17+: When the user asks a multipart question like
#   "what is 2+2 and what is a cat"
# the cave needs to decompose this into independent sub-missions so that:
#   1. Each sub-mission can hit the right lobe independently
#   2. Arithmetic doesn't bleed into non-math clauses
#   3. AIML can cohere the responses as a unified answer
#
# This module lives BEFORE SigilMediator in the pipeline:
#   user input → InputDecomposer.decompose() → [clause1, clause2, ...]
#   each clause → SigilMediator.mediate() → vote
#   all votes → MultipartOrchestrator → grouped by objective_id → AIML
#
# Design: thin, declarative, no ML. Uses the decomposer_config from the
# specimen (compound_pairs, question_markers, split_conjunctions) with
# hardcoded English-language defaults for when no config is loaded.

module InputDecomposer

export decompose, set_decomposer_config!, get_decomposer_config, DecomposedClause

# =============================================================================
# DATA STRUCTURES
# =============================================================================

struct DecomposedClause
    text::String           # the sub-mission text
    index::Int             # 1-based clause index in original order
    is_question::Bool      # starts with a question marker
    conjunction::String     # the conjunction that preceded this clause ("" for first)
end

# =============================================================================
# CONFIG
# =============================================================================

# GRUG: hardcoded defaults matching v3 specimen's decomposer_config.
# Can be overridden by set_decomposer_config! when loading a specimen.
const DEFAULT_COMPOUND_PAIRS = Dict{String,Vector{String}}(
    "or"    => ["else"],
    "not"   => ["only"],
    "then"  => ["additionally"],
    "but"   => ["instead", "rather"],
    "and"   => ["additionally", "also", "furthermore", "moreover", "then"],
)

const DEFAULT_QUESTION_MARKERS = [
    "am", "are", "can", "could", "did", "do", "does", "how",
    "is", "shall", "was", "were", "what", "when", "where", "which",
    "who", "whom", "whose", "why", "will", "would",
]

const DEFAULT_SPLIT_CONJUNCTIONS = [
    "additionally", "also", "alternatively", "although", "besides",
    "but", "except", "furthermore", "however", "independently",
    "instead", "likewise", "moreover", "nevertheless", "nonetheless",
    "or", "separately", "similarly", "since", "then",
    "unless", "whereas", "while", "whilst", "yet", "and",
]
# GRUG v7.17.1: "plus" removed from default split_conjunctions.
# "plus" is primarily a math operator. The math-context guard in decompose()
# handles cases where "plus" appears between numbers, but removing it from
# the default list entirely is safer — prevents false splits like
# "what is 2 plus 2" → ["what is 2", "2"]. If a specimen's config
# explicitly includes "plus", the math-context guard will still protect.

# GRUG: mutable config state, override-able from specimen load.
const _CONFIG = Ref{Dict{String,Any}}()

function _ensure_config()::Dict{String,Any}
    if !isassigned(_CONFIG)
        _CONFIG[] = Dict{String,Any}(
            "compound_pairs"     => DEFAULT_COMPOUND_PAIRS,
            "question_markers"   => DEFAULT_QUESTION_MARKERS,
            "split_conjunctions" => DEFAULT_SPLIT_CONJUNCTIONS,
        )
    end
    return _CONFIG[]
end

function set_decomposer_config!(cfg::Dict{String,Any})
    # GRUG v7.17.1: MERGE, don't replace. Specimen configs may be missing
    # core conjunctions like "and" (the v3 specimen omits it). We always
    # ensure the default split_conjunctions are present as a baseline,
    # then add any specimen-specific ones on top.
    merged = Dict{String,Any}()
    # Start with defaults
    merged["compound_pairs"]     = get(cfg, "compound_pairs", DEFAULT_COMPOUND_PAIRS)
    merged["question_markers"]  = get(cfg, "question_markers", DEFAULT_QUESTION_MARKERS)
    # Merge split_conjunctions: defaults + specimen additions
    spec_conjs = get(cfg, "split_conjunctions", String[])
    merged_conjs = sort(unique(vcat(DEFAULT_SPLIT_CONJUNCTIONS, spec_conjs)))
    merged["split_conjunctions"] = merged_conjs
    # Copy any additional keys from specimen config
    for k in keys(cfg)
        if !haskey(merged, k)
            merged[k] = cfg[k]
        end
    end
    _CONFIG[] = merged
end

function get_decomposer_config()::Dict{String,Any}
    return _ensure_config()
end

# =============================================================================
# CORE LOGIC
# =============================================================================

"""
    decompose(input_text::String) → Vector{DecomposedClause}

Split a compound user input into independent clauses. Returns a vector of
DecomposedClause structs in original order.

Single-clause inputs (no conjunctions) return a single-element vector
with conjunction="" and is_question determined from the first word.

The split is conservative: we only split on conjunctions that sit BETWEEN
two clauses (not leading/trailing), and we preserve each clause's full
text including its own question markers.
"""
function decompose(input_text::String)::Vector{DecomposedClause}
    stripped = strip(input_text)
    if isempty(stripped)
        return DecomposedClause[]
    end

    cfg = _ensure_config()
    split_conjs = get(cfg, "split_conjunctions", DEFAULT_SPLIT_CONJUNCTIONS)
    q_markers   = get(cfg, "question_markers", DEFAULT_QUESTION_MARKERS)

    # GRUG: tokenize with position tracking so we can reconstruct.
    tokens = split(stripped)
    n = length(tokens)
    if n == 0
        return DecomposedClause[]
    end

    # GRUG: find split points — indices of tokens that are conjunctions
    # AND are NOT the first token (leading "and" is not a split point)
    # AND are NOT the last token (trailing "and" is part of last clause).
    # A conjunction at position i splits the input into:
    #   clause_left = tokens[1..i-1]
    #   clause_right = tokens[i+1..n]
    # The conjunction itself is NOT included in either clause.
    #
    # GRUG v7.17.1: MATH-CONTEXT GUARD. Tokens like "plus", "minus", "times",
    # "divided" that appear in split_conjunctions are ALSO math operators.
    # If a candidate split token sits between two number tokens (or a number
    # and an operator), it's a math expression — NOT a clause boundary.
    # Failing to guard this causes "what is 2 plus 2" to split into
    # ["what is 2", "2"], which is catastrophic for arithmetic coherence.
    _is_number_like(t::AbstractString) = occursin(r"^[+-]?\d+(\.\d+)?$", t)
    _math_ops = Set(["plus", "minus", "times", "multiplied", "divided", "over", "mod"])

    split_indices = Int[]
    for i in 2:(n-1)
        tok_lower = lowercase(String(tokens[i]))
        # GRUG: strip trailing punctuation from the token before checking
        # (e.g. "and," → "and")
        tok_clean = replace(tok_lower, r"[,;.!?]+$" => "")
        if tok_clean in split_conjs
            # GRUG v7.17.1: math-context guard. If this conjunction is also
            # a math operator AND the tokens immediately left/right are
            # number-like, skip it — it's part of a math expression.
            if tok_clean in _math_ops
                left_tok  = i > 1 ? replace(lowercase(String(tokens[i-1])), r"[,;.!?]+$" => "") : ""
                right_tok = i < n ? replace(lowercase(String(tokens[i+1])), r"[,;.!?]+$" => "") : ""
                if _is_number_like(left_tok) || _is_number_like(right_tok)
                    continue  # math context — don't split
                end
            end
            push!(split_indices, i)
        end
    end

    # GRUG: no split points → single clause.
    if isempty(split_indices)
        first_word = lowercase(String(first(tokens)))
        first_clean = replace(first_word, r"[,;.!?]+$" => "")
        is_q = first_clean in q_markers
        return [DecomposedClause(stripped, 1, is_q, "")]
    end

    # GRUG: build clauses from split points.
    # Clause boundaries: [1, s1-1], [s1+1, s2-1], ..., [sK+1, n]
    clauses = DecomposedClause[]
    boundaries = Vector{Tuple{Int,Int}}()

    prev_end = 0
    for si in split_indices
        clause_start = prev_end + 1
        clause_end = si - 1
        if clause_end >= clause_start
            push!(boundaries, (clause_start, clause_end))
        end
        prev_end = si
    end
    # trailing clause after last conjunction
    trailing_start = prev_end + 1
    if trailing_start <= n
        push!(boundaries, (trailing_start, n))
    end

    # GRUG: also include the leading clause before the first split.
    # Wait — the loop above already handles this because prev_end starts at 0.
    # boundaries[1] = (1, s1-1), which IS the leading clause. Correct.

    for (idx, (cs, ce)) in enumerate(boundaries)
        clause_text = strip(join(tokens[cs:ce], " "))
        if isempty(clause_text)
            continue
        end

        # GRUG: conjunction that preceded this clause.
        # First clause has no preceding conjunction.
        conj = ""
        if idx > 0 && idx <= length(split_indices)
            conj = String(tokens[split_indices[min(idx, length(split_indices))]])
        end

        # GRUG: detect question by checking first word of clause.
        first_tok = lowercase(String(first(split(clause_text))))
        first_clean = replace(first_tok, r"[,;.!?]+$" => "")
        is_q = first_clean in q_markers

        push!(clauses, DecomposedClause(clause_text, idx, is_q, conj))
    end

    # GRUG: edge case — if all clauses were empty, return the full text.
    if isempty(clauses)
        first_word = lowercase(String(first(tokens)))
        first_clean = replace(first_word, r"[,;.!?]+$" => "")
        is_q = first_clean in q_markers
        return [DecomposedClause(stripped, 1, is_q, "")]
    end

    return clauses
end

end # module InputDecomposer
