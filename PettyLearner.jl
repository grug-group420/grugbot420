# ==============================================================================
# PettyLearner.jl — v10 Instant Fast-Path Learning
# ==============================================================================
# GRUG say: not every gap need new node. Some gap so SMALL, Grug just WRITE
# the answer down. New word that's synonym of old word? Just add synonym pair.
# Simple math like "3+5"? Just write answer on flashcard. Domain token for
# empty lobe? Just add to whitelist. NO COINFLIP. NO EVIDENCE. INSTANT.
#
# The classifier looks at the input and decides if it's a "petty" case —
# something so simple that growing a node would be wasteful. Three categories:
#
#   1. NEW WORD → THESAURUS: One uncovered token, high similarity to a
#      covered token. Add synonym pair instantly.
#
#   2. SIMPLE MATH → FLASHCARD: Arithmetic expression with bindings.
#      Compute result, write to flashcard. No node needed.
#
#   3. DOMAIN TOKEN → LOBE WHITELIST: One uncovered token that overlaps
#      with an under-populated lobe's subject. Add to whitelist instantly.
#
# If none of these apply, the input goes through normal AutoGrowth evidence
# accumulation + coinflip. Petty learning is a FAST-PATH that SKIPS the
# evidence pipeline entirely. It's for trivial gaps that don't need the
# full machinery.
#
# IMPORTANT: Petty learning is CONSERVATIVE. Only ONE uncovered token.
# If there are 2+ uncovered tokens, it's not petty — it's a real gap.
# Multiple gaps need evidence accumulation to decide WHICH one to grow.
# ==============================================================================

module PettyLearner

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

export PettyResult, classify_petty, dispatch_petty!

# ==============================================================================
# RESULT STRUCT
# ==============================================================================

struct PettyResult
    dispatched::Bool          # Was a petty fast-path taken?
    path::Symbol              # :thesaurus, :flashcard, :lobe_whitelist, :none
    detail::String            # Human-readable description of what happened
    candidate_token::String   # The token that triggered the fast-path
    target_lobe::String       # Lobe hint for the candidate (empty if none)
    similarity::Float64       # Thesaurus similarity score (0.0 if N/A)
    arithmetic_expr::String   # Arithmetic expression (empty if N/A)
    arithmetic_result::String # Arithmetic result (empty if N/A)
end

# ==============================================================================
# STOPWORDS — same set as AutoGrowth (duplicated for module independence)
# ==============================================================================

const _PETTY_STOPWORDS = Set([
    "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would", "could",
    "should", "may", "might", "must", "shall", "can", "need", "dare",
    "to", "of", "in", "for", "on", "with", "at", "by", "from", "as",
    "into", "through", "during", "before", "after", "above", "below",
    "between", "out", "off", "over", "under", "again", "further", "then",
    "once", "here", "there", "when", "where", "why", "how", "all", "each",
    "every", "both", "few", "more", "most", "other", "some", "such", "no",
    "not", "only", "own", "same", "so", "than", "too", "very", "just",
    "because", "but", "and", "or", "if", "while", "about", "up", "it",
    "its", "that", "this", "these", "those", "i", "me", "my", "we", "you",
    "your", "he", "she", "him", "her", "they", "them", "what", "which",
    "who", "whom", "whose", "also", "too", "either", "neither",
])

# ==============================================================================
# THRESHOLD
# ==============================================================================

const PETTY_MAX_UNCOVERED_TOKENS = 1   # Only 1 uncovered → petty candidate
const PETTY_SIMILARITY_FLOOR     = 0.70  # synonym_seed_threshold
const PETTY_MIN_TOKEN_LENGTH     = 3     # ignore 1-2 char tokens
const PETTY_MAX_ARITH_OPS        = 2     # at most 2 operators for "simple" math

# ==============================================================================
# CLASSIFY — determine if input is a petty learning case
# ==============================================================================

"""
    classify_petty(user_text, tokens, node_patterns, thesaurus_fn,
                   word_sim_fn, lobe_snapshots, sigil_entries,
                   arithmetic_bindings) -> PettyResult

Determine if the input represents a petty learning opportunity.
Returns PettyResult with path=:none if no fast-path applies.
"""
function classify_petty(
    user_text::String,
    tokens::Vector{String},
    node_patterns::Set{String},
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    lobe_snapshots::Vector{Tuple{String,String,Set{String}}},
    sigil_entries::Dict,
    arithmetic_bindings::Dict,
)::PettyResult
    # GRUG: Find uncovered non-stopword tokens.
    uncovered = String[]
    for tok in tokens
        t = lowercase(strip(tok))
        if length(t) >= PETTY_MIN_TOKEN_LENGTH && !in(t, _PETTY_STOPWORDS)
            if !_is_covered(t, node_patterns)
                push!(uncovered, t)
            end
        end
    end

    # ── PATH 1: NEW WORD → THESAURUS ──────────────────────────────────────
    # GRUG: If exactly ONE uncovered token and it's similar to a covered token,
    # it's probably a synonym we just haven't registered yet.
    if length(uncovered) == 1
        candidate = uncovered[1]
        best_sim = 0.0
        best_match = ""
        # GRUG: Check similarity against all covered tokens in the input
        for tok in tokens
            t = lowercase(strip(tok))
            if t == candidate
                continue
            end
            if _is_covered(t, node_patterns) && length(t) >= PETTY_MIN_TOKEN_LENGTH
                try
                    sim = thesaurus_word_similarity(candidate, t)
                    if sim > best_sim
                        best_sim = sim
                        best_match = t
                    end
                catch
                    # GRUG: similarity errors non-fatal
                end
            end
        end
        if best_sim >= PETTY_SIMILARITY_FLOOR && !isempty(best_match)
            lobe_hint = _infer_lobe_from_token(candidate, lobe_snapshots)
            return PettyResult(
                true, :thesaurus,
                "\"$candidate\" ≈ \"$best_match\" (sim=$(round(best_sim, digits=2))) → synonym pair",
                candidate, lobe_hint, best_sim, "", ""
            )
        end

        # ── PATH 3: DOMAIN TOKEN → LOBE WHITELIST ────────────────────────
        # GRUG: If that one uncovered token belongs to an under-populated
        # lobe's subject area, add it to that lobe's whitelist.
        for (lobe_id, subject, node_ids) in lobe_snapshots
            subject_tokens = [lowercase(strip(t)) for t in split(subject)]
            if candidate in subject_tokens && length(node_ids) < 5
                # GRUG: Check the token doesn't already belong to multiple lobes
                matching_lobe_count = count(
                    ((lid, sub, _),) -> in(candidate, [lowercase(strip(t)) for t in split(sub)]),
                    lobe_snapshots
                )
                if matching_lobe_count == 1
                    return PettyResult(
                        true, :lobe_whitelist,
                        "\"$candidate\" → lobe whitelist for $lobe_id ($(length(node_ids)) nodes)",
                        candidate, lobe_id, 0.0, "", ""
                    )
                end
            end
        end
    end

    # ── PATH 2: SIMPLE MATH → FLASHCARD ──────────────────────────────────
    # GRUG: If the input has arithmetic bindings and the expression is
    # computable, write the result to flashcard instead of growing a node.
    if !isempty(arithmetic_bindings)
        has_n = count(k -> startswith(string(k), "&n"), keys(arithmetic_bindings)) >= 2
        has_op = count(k -> startswith(string(k), "&op"), keys(arithmetic_bindings)) >= 1
        n_ops = count(k -> startswith(string(k), "&op"), keys(arithmetic_bindings))
        if has_n && has_op && n_ops <= PETTY_MAX_ARITH_OPS
            # GRUG: This is simple math. Build the expression string.
            expr = _build_arithmetic_expr(arithmetic_bindings)
            if !isempty(expr)
                lobe_hint = _infer_lobe_from_token("math", lobe_snapshots)
                return PettyResult(
                    true, :flashcard,
                    "\"$expr\" → flashcard (simple math, no node needed)",
                    "math", lobe_hint, 0.0, expr, ""
                )
            end
        end
    end

    # ── NO PETTY PATH ────────────────────────────────────────────────────
    return PettyResult(false, :none, "", "", "", 0.0, "", "")
end

# ==============================================================================
# DISPATCH — execute the fast-path action
# ==============================================================================

"""
    dispatch_petty!(result::PettyResult; kwargs...) -> PettyResult

Execute the fast-path action. Returns updated PettyResult with detail
field updated to reflect what actually happened.
"""
function dispatch_petty!(result::PettyResult;
    thesaurus_register_fn::Function = (a, b) -> false,
    flashcard_put_fn::Function = (lobe, expr, res; kwargs...) -> nothing,
    lobe_whitelist_fn::Function = (lobe_id, token) -> 0,
    arithmetic_compute_fn::Function = (bindings) -> nothing,
    arithmetic_bindings::Dict = Dict(),
)::PettyResult
    if !result.dispatched
        return result
    end

    detail = result.detail

    if result.path == :thesaurus
        # GRUG: Register the synonym pair. Bidirectional via add_seed_synonym!
        try
            success = thesaurus_register_fn(result.candidate_token, result.similarity > 0 ? result.candidate_token : "")
            detail = "$(result.detail) [registered=$(success)]"
        catch e
            detail = "$(result.detail) [FAILED: $e]"
        end
    elseif result.path == :flashcard
        # GRUG: Compute arithmetic and write to flashcard.
        try
            arith_result = arithmetic_compute_fn(arithmetic_bindings)
            if arith_result !== nothing
                result_str = string(get(arith_result, :formatted, ""))
                result_num = Float64(get(arith_result, :value, NaN))
                expr = result.arithmetic_expr
                lobe = isempty(result.target_lobe) ? "math" : result.target_lobe
                flashcard_put_fn(lobe, expr, result_str; result_num=result_num, card_type=:arithmetic)
                detail = "flashcard: $expr = $result_str [written to $lobe]"
            else
                detail = "flashcard: computation returned nothing [SKIPPED]"
            end
        catch e
            detail = "flashcard: FAILED: $e"
        end
    elseif result.path == :lobe_whitelist
        # GRUG: Add the token to the lobe's whitelist.
        try
            count_added = lobe_whitelist_fn(result.target_lobe, result.candidate_token)
            detail = "whitelist: \"$(result.candidate_token)\" → $(result.target_lobe) [added=$count_added]"
        catch e
            detail = "whitelist: FAILED: $e"
        end
    end

    return PettyResult(
        result.dispatched, result.path, detail,
        result.candidate_token, result.target_lobe, result.similarity,
        result.arithmetic_expr, result.arithmetic_result
    )
end

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

function _is_covered(token::String, node_patterns::Set{String})::Bool
    tok_lower = lowercase(strip(token))
    for pat in node_patterns
        if occursin(tok_lower, lowercase(pat))
            return true
        end
    end
    return false
end

function _infer_lobe_from_token(token::String, lobe_snapshots::Vector{Tuple{String,String,Set{String}}})::String
    tok_lower = lowercase(strip(token))
    best_lobe = "default"
    best_overlap = 0
    for (lobe_id, subject, _) in lobe_snapshots
        subject_tokens = [lowercase(strip(t)) for t in split(subject)]
        overlap = count(t -> t == tok_lower, subject_tokens)
        if overlap > best_overlap
            best_overlap = overlap
            best_lobe = lobe_id
        end
    end
    return best_lobe
end

function _build_arithmetic_expr(bindings::Dict)::String
    # GRUG: Build a human-readable arithmetic expression from sigil bindings.
    # E.g., &n1=3, &op1=+, &n2=5 → "3+5"
    nums = String[]
    ops = String[]
    for (key, val) in bindings
        k = string(key)
        v = string(val)
        if startswith(k, "&n")
            push!(nums, v)
        elseif startswith(k, "&op")
            push!(ops, v)
        end
    end
    sort!(nums; by=n -> tryparse(Int, string(n)) !== nothing ? tryparse(Int, string(n)) : 0)
    sort!(ops)
    if length(nums) < 2 || isempty(ops)
        return ""
    end
    # GRUG: Interleave nums and ops: num1 op1 num2
    parts = String[]
    push!(parts, nums[1])
    for i in 1:length(ops)
        push!(parts, ops[min(i, length(ops))])
        if i + 1 <= length(nums)
            push!(parts, nums[i + 1])
        end
    end
    return join(parts, "")
end

# ==============================================================================
# STATUS
# ==============================================================================

function petty_status()::String
    return """
    === PETTY LEARNER STATUS ===
      max_uncovered_tokens: $PETTY_MAX_UNCOVERED_TOKENS
      similarity_floor:     $PETTY_SIMILARITY_FLOOR
      min_token_length:     $PETTY_MIN_TOKEN_LENGTH
      max_arith_ops:        $PETTY_MAX_ARITH_OPS
      paths: :thesaurus, :flashcard, :lobe_whitelist
    """
end

end # module PettyLearner
