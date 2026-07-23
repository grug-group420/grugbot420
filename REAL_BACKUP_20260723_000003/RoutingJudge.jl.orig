# ==============================================================================
# RoutingJudge.jl — Lazy conservative intent resolver with entropy jitter
# ==============================================================================
# GRUG v8.28e: Architecture
#
# The prescan (_conversation_prescan) is currently a greedy waterfall — first
# regex match wins, no backtracking, no conflict detection. Every false-winner
# bug (v8.28d: "what time means it", penicillin→tides crosstalk, "no fire
# means...", stalactite correction) was a case where a lower-priority pattern
# won because the correct pattern failed to match or was checked too late.
#
# RoutingJudge fixes this by:
#   1. Collecting ALL candidate intents from the prescan (not just first match)
#   2. Scoring each intent using: regex match quality + graph backing + conservative bias
#   3. Computing Shannon entropy across the score distribution
#   4. If entropy < LAZY_THRESHOLD → lazy mode, pass through the top intent
#   5. If entropy ≥ LAZY_THRESHOLD → apply jitter snap-back toward conservative intent
#
# GRAPH BACKING (pseudo-nonlinear):
#   The routing judge consults the knowledge graph (NODE_MAP, sigil nodes,
#   relational triples, dictionary) to score intents. If the graph already
#   contains knowledge relevant to the query, :question gets a boost (the bot
#   can actually answer). If not, the conservative bias still favors :question,
#   but with higher entropy (less certain), so the jitter is weaker.
#
#   This creates a self-reinforcing loop: correct routing → knowledge creation
#   → graph backing → lower entropy → easier routing → more correct routing.
#   The old bugs were in the opposite spiral: wrong routing → garbage knowledge
#   → higher entropy → harder routing → more wrong routing.
#
# CONSERVATIVE HIERARCHY (safest → riskiest):
#   :nothing > :calculate > :question > :correct > :define > :teach
#
#   Do nothing is safest. Arithmetic calculation is nearly as safe (deterministic
#   results, no knowledge modification). Asking is safer than correcting.
#   Correcting is safer than defining. Teaching is riskiest (it creates
#   persistent knowledge from user input, so it should only fire when
#   clearly intended).
#
# JITTER SNAP-BACK:
#   When entropy is high (close call between intents), a small random
#   perturbation is applied that snaps toward the safer intent. The snap
#   strength is proportional to entropy — low entropy = no jitter, high
#   entropy = stronger snap. This prevents edge cases where a slightly
#   higher-scoring risky intent beats a slightly lower-scoring safe intent.
#
# AUTOMATA MODEL:
#   The prescan is modeled as a finite-state machine. Intents are states,
#   regex patterns are transitions, and the routing judge resolves when
#   multiple transitions are simultaneously live (ambiguous input).
# ==============================================================================

module RoutingJudge

# NOTE: RoutingJudge is included BEFORE engine.jl and Main.jl in GrugBot420,
# so we CANNOT `using ..GrugBot420: NODE_MAP, ...` at module load time —
# those bindings don't exist yet. Instead, we use lazy runtime access via
# `getfield(parentmodule, ...)` which resolves at call time, after all
# includes have completed.

"""Get a binding from the parent GrugBot420 module at runtime."""
function _parent_binding(name::Symbol)
    pm = parentmodule(RoutingJudge)
    # Walk up if nested inside a deeper eval context
    while pm !== Main && !isdefined(pm, name)
        pm = parentmodule(pm)
    end
    getfield(pm, name)
end

# Lazy accessors — resolve at call time, not at include time
_get_NODE_MAP()   = _parent_binding(:NODE_MAP)
_get_NODE_LOCK()  = _parent_binding(:NODE_LOCK)
_get_dict_lookup() = _parent_binding(:_dict_lookup_word)
_get_pending_teach() = _parent_binding(:_conv_get_pending_teach)
_get_pending_teach_turn() = _parent_binding(:_conv_pending_teach_turn)

# ── Knobs ────────────────────────────────────────────────────────────────────

# Entropy threshold for lazy activation. Below this, the judge stays dormant.
const LAZY_ENTROPY_THRESHOLD = 0.15  # bits — roughly 85%+ confidence on one intent

# Conservative bias per intent kind. Higher = more conservative (safer).
# This is the "snap-back target" — when jitter fires, it pushes toward higher bias.
const CONSERVATIVE_BIAS = Dict{Symbol, Float64}(
    :nothing       => 1.00,   # Do nothing is always safest
    :calculate     => 0.95,   # Arithmetic is deterministic — very safe, nearly as safe as :nothing
    :question      => 0.80,   # Asking is safe — bot just queries its own knowledge
    :correct       => 0.50,   # Correcting modifies existing knowledge — moderate risk
    :define        => 0.25,   # Defining creates new knowledge — risky
    :teach         => 0.10,   # Teaching creates persistent sigil nodes — riskiest
    :teach_synonym => 0.15,   # Conversational synonym registration — narrow, low-risk
    :teach_verb    => 0.15,   # Conversational verb/class registration — narrow, low-risk
)

# ==============================================================================
# GRUG v9.3: ROUTING SELF-IMPROVEMENT — adaptive bias adjustment
# ==============================================================================
# The CONSERVATIVE_BIAS dict above is a fixed PRIOR — grug's starting opinion
# about how safe each intent kind is. But grug should get BETTER at routing
# over time, not stay frozen forever. BIAS_ADJUSTMENT is a small persistent
# delta layered on top of CONSERVATIVE_BIAS, nudged by real /right and /wrong
# feedback from the user. If :teach routing keeps producing /right outcomes,
# its effective bias creeps up (grug trusts that path a little more next
# time there's a close call). If :question routing keeps producing /wrong,
# its effective bias creeps down.
#
# This is intentionally SLOW and BOUNDED (small learn rate, clamped range) —
# routing bias adaptation should never override the conservative hierarchy
# wholesale, only nudge close calls over time. It persists across specimen
# save/load (see Main.jl save_specimen_to_file!/load_specimen_from_file!).
# ==============================================================================

const _BIAS_ADJUSTMENT_LOCK = ReentrantLock()

# Per-kind persistent delta, added to CONSERVATIVE_BIAS at resolve time.
const BIAS_ADJUSTMENT = Dict{Symbol, Float64}(k => 0.0 for k in keys(CONSERVATIVE_BIAS))

# How much a single /right or /wrong nudges the bias for that intent kind.
const BIAS_LEARN_RATE = 0.02

# Adjustment is clamped to +/- this value — routing bias can drift, but
# never enough to invert the conservative hierarchy by itself.
const BIAS_ADJUSTMENT_CLAMP = 0.30

"""
    effective_bias(kind::Symbol)::Float64

Return the CURRENT effective conservative bias for an intent kind — the
static prior (CONSERVATIVE_BIAS) plus whatever has been learned so far
(BIAS_ADJUSTMENT), clamped to a sane range. This is what `resolve` actually
uses for scoring, instead of the raw static dict.
"""
function effective_bias(kind::Symbol)::Float64
    base = get(CONSERVATIVE_BIAS, kind, 0.0)
    adj = lock(_BIAS_ADJUSTMENT_LOCK) do
        get(BIAS_ADJUSTMENT, kind, 0.0)
    end
    return clamp(base + adj, 0.0, 1.5)
end

"""
    record_routing_outcome!(kind::Symbol, success::Bool)

GRUG v9.3: The self-improvement hook. Call this when the user gives explicit
feedback (/right or /wrong) about the last response, passing the intent kind
that `_conversation_prescan` routed to for that turn. On success, the kind's
bias nudges UP by BIAS_LEARN_RATE (grug trusts this routing path a little
more). On failure, it nudges DOWN. Adjustment is clamped so routing can drift
but never invert the conservative hierarchy on its own.

Non-fatal by design — an unknown kind just gets a fresh 0.0 entry instead of
erroring, since new intent kinds may be added over time.
"""
function record_routing_outcome!(kind::Symbol, success::Bool)
    lock(_BIAS_ADJUSTMENT_LOCK) do
        current = get(BIAS_ADJUSTMENT, kind, 0.0)
        delta = success ? BIAS_LEARN_RATE : -BIAS_LEARN_RATE
        updated = clamp(current + delta, -BIAS_ADJUSTMENT_CLAMP, BIAS_ADJUSTMENT_CLAMP)
        BIAS_ADJUSTMENT[kind] = updated
    end
    return nothing
end

"""
    get_bias_adjustments()::Dict{Symbol, Float64}

Snapshot of all learned bias adjustments, for specimen serialization.
"""
function get_bias_adjustments()::Dict{Symbol, Float64}
    lock(_BIAS_ADJUSTMENT_LOCK) do
        return copy(BIAS_ADJUSTMENT)
    end
end

"""
    set_bias_adjustments!(d::AbstractDict)

Bulk-restore learned bias adjustments (e.g. from a loaded specimen). Values
are clamped defensively in case of hand-edited/corrupted specimen data.
Keys not present in `d` keep their current value (usually 0.0 on fresh boot).
"""
function set_bias_adjustments!(d::AbstractDict)
    lock(_BIAS_ADJUSTMENT_LOCK) do
        for (k, v) in d
            kk = k isa Symbol ? k : Symbol(String(k))
            BIAS_ADJUSTMENT[kk] = clamp(Float64(v), -BIAS_ADJUSTMENT_CLAMP, BIAS_ADJUSTMENT_CLAMP)
        end
    end
    return nothing
end

"""
    reset_bias_adjustments!()

Zero out all learned routing bias adjustments. Used on full cave wipe
(specimen reload) so stale learning from a previous specimen doesn't bleed
into a freshly loaded one.
"""
function reset_bias_adjustments!()
    lock(_BIAS_ADJUSTMENT_LOCK) do
        for k in keys(BIAS_ADJUSTMENT)
            BIAS_ADJUSTMENT[k] = 0.0
        end
    end
    return nothing
end

# Graph backing weight — how much existing knowledge boosts :question score.
const GRAPH_BACKING_WEIGHT = 0.30

# Jitter snap-back strength — proportional to entropy. This is the maximum
# bias applied at maximum entropy (1.0 bits for 2-way tie). Scales linearly.
const JITTER_SNAP_STRENGTH = 0.15

# Regex match quality weights. Exact match > partial match > no match.
const MATCH_QUALITY = Dict{Symbol, Float64}(
    :exact   => 1.0,   # Full pattern match (entire input captured cleanly)
    :partial => 0.6,   # Pattern matched but with loose captures
    :none    => 0.0,   # Pattern did not match
)

# ── Intent candidate ─────────────────────────────────────────────────────────

struct IntentCandidate
    kind::Symbol           # :question, :define, :correct, :teach, :calculate, :nothing
    topic::String          # The extracted topic/word (for :calculate, the arithmetic expression)
    definition::String     # The extracted definition (empty for :question, :calculate)
    hint::String           # Lobe hint or subject
    match_quality::Float64 # How well the regex matched (1.0 = exact, 0.6 = partial)
    source::String         # Which pattern produced this (for debug logging)
end

# ── Scored intent ────────────────────────────────────────────────────────────

struct ScoredIntent
    candidate::IntentCandidate
    base_score::Float64     # Raw score from match quality + graph backing
    bias::Float64           # Conservative bias for this intent kind
    final_score::Float64    # After jitter snap-back (if applied)
end

# ── Entropy computation ──────────────────────────────────────────────────────

"""
    shannon_entropy(scores::Vector{Float64})::Float64

Compute Shannon entropy of a score distribution. Normalizes scores to
probabilities first. Returns 0.0 for a single candidate (no uncertainty).
Maximum for N candidates is log2(N).
"""
function shannon_entropy(scores::Vector{Float64})::Float64
    n = length(scores)
    n <= 1 && return 0.0

    total = sum(scores)
    total <= 0.0 && return log2(n)  # Uniform if all zero

    probs = [s / total for s in scores]
    H = 0.0
    for p in probs
        if p > 0.0
            H -= p * log2(p)
        end
    end
    return H
end

# ── Graph backing computation ────────────────────────────────────────────────

"""
    compute_graph_backing(topic::String, kind::Symbol)::Float64

Check if the knowledge graph has backing for a given topic and intent kind.
Returns a score in [0.0, GRAPH_BACKING_WEIGHT].

For :question — if the graph has nodes or dictionary entries about this topic,
  the bot can actually answer, so :question gets a boost.
For :define — if the word is ALREADY defined, defining it again is redundant,
  so :define gets a slight penalty (negative backing).
For :correct — if the word IS defined, correction makes sense, so :correct
  gets a boost.
For :teach — always gets 0 (no graph backing — teaching is user-driven).
For :nothing — always gets 0 (no graph interaction).
"""
function compute_graph_backing(topic::String, kind::Symbol)::Float64
    kind === :nothing && return 0.0
    kind === :teach && return 0.0
    kind === :calculate && return 0.0  # Arithmetic needs no graph backing — it's self-contained

    _topic = String(strip(lowercase(String(topic))))
    isempty(_topic) && return 0.0

    if kind === :question
        # Check if knowledge graph has something about this topic
        _lookup_result = _get_dict_lookup()(String(_topic))
        has_dict = _lookup_result !== nothing && !isempty(_lookup_result)
        has_node = _has_node_with_topic(_topic)

        if has_dict && has_node
            return GRAPH_BACKING_WEIGHT  # Full backing — bot can definitely answer
        elseif has_dict || has_node
            return GRAPH_BACKING_WEIGHT * 0.6  # Partial backing
        else
            return 0.0  # No backing — bot would have to ask clarification
        end
    elseif kind === :define
        # If already defined, re-defining is redundant — slight penalty
        _lookup_result = _get_dict_lookup()(String(_topic))
        has_dict = _lookup_result !== nothing && !isempty(_lookup_result)
        return has_dict ? -GRAPH_BACKING_WEIGHT * 0.3 : 0.0
    elseif kind === :correct
        # If defined, correction makes sense — boost
        _lookup_result = _get_dict_lookup()(String(_topic))
        has_dict = _lookup_result !== nothing && !isempty(_lookup_result)
        return has_dict ? GRAPH_BACKING_WEIGHT * 0.5 : 0.0
    end

    return 0.0
end

"""
    _has_node_with_topic(topic::String)::Bool

Check if any node in NODE_MAP has triples or content related to the topic.
Uses a simple substring check on node text fields.
"""
function _has_node_with_topic(topic::AbstractString)::Bool
    _topic_lower = lowercase(String(topic))
    found = false
    _map = _get_NODE_MAP()
    _lock = _get_NODE_LOCK()
    lock(_lock) do
        for (id, node) in _map
            # Check node's pattern (text content)
            node_pattern = node.pattern
            if occursin(_topic_lower, lowercase(node_pattern))
                found = true
                break
            end
            # Check node's action_packet
            node_action = node.action_packet
            if occursin(_topic_lower, lowercase(node_action))
                found = true
                break
            end
            # Check node's relational triples
            triples = node.relational_patterns
            if !isempty(triples)
                for tr in triples
                    tr_str = lowercase(string(tr))
                    if occursin(_topic_lower, tr_str)
                        found = true
                        break
                    end
                end
                found && break
            end
        end
    end
    return found
end

# ── Pending teach state check ────────────────────────────────────────────────

"""
    compute_pending_teach_backing(kind::Symbol)::Float64

If there's pending teach state, :teach gets a boost (the user is likely
responding to our clarification). But this is tempered by the conservative
hierarchy — :teach is still riskiest, so the boost is small.
"""
function compute_pending_teach_backing(kind::Symbol)::Float64
    _pending = _get_pending_teach()()
    if isempty(_pending)
        return 0.0
    end

    # There IS pending state. :teach gets a moderate boost.
    # But :question also gets a small boost (topic shift detection —
    # the user might be asking a new question instead of teaching).
    if kind === :teach
        return 0.20  # Pending state makes teach plausible
    elseif kind === :question
        return 0.10  # But topic shift is also plausible
    end

    return 0.0
end

# ── Token-level arithmetic detection ─────────────────────────────────────────

"""
    _has_arithmetic_tokens(text::String)::Bool

Check whether the given text fragment contains arithmetic token patterns.
This uses sigil-aware token analysis — not just regex on raw strings, but
actual canonicalization through SigilPromoter's number/op maps.

Detects:
  - "5+5", "3 - 2", "12/4", "7*8" (digit-operator-digit)
  - "five plus three", "two minus one" (word-operator-word)
  - "5 + five", "3 times 7" (mixed digit/word with operator)

The key insight: "5+5" as a topic is NOT a knowledge query about the literal
string "5+5" — it's an arithmetic expression. The routing judge must detect
this at the TOKEN level, not just the regex pattern level.
"""
function _has_arithmetic_tokens(text::AbstractString)::Bool
    # ── Fast path: direct regex for digit-operator-digit patterns ──
    # "5+5", "3 - 2", "12/4", "7*8", "2^3" — these are the most common forms
    if occursin(r"\d\s*[+\-*/^]\s*\d", text)
        return true
    end

    # ── Word-based arithmetic: number-word + operator-word + number-word ──
    # "five plus three", "two minus one", "3 times 7", "ten divided by 2"
    # First check if any operator word appears
    _op_words = ["plus", "minus", "times", "divided", "over",
                 "multiplied", "added", "subtracted", "add",
                 "multiply", "divide", "subtract"]
    _has_op_word = any(w -> occursin(Regex("\\b$(w)\\b"), text), _op_words)
    if !_has_op_word
        return false  # No operator word AND no digit-operator-digit → not arithmetic
    end

    # Check for number-word or digit near the operator word
    _num_words = Set(["zero","one","two","three","four","five","six","seven",
                      "eight","nine","ten","eleven","twelve","thirteen","fourteen",
                      "fifteen","sixteen","seventeen","eighteen","nineteen","twenty",
                      "thirty","forty","fifty","sixty","seventy","eighty","ninety",
                      "hundred","thousand","million"])
    _tokens = split(lowercase(text))
    _has_digit = any(t -> occursin(r"^\d", String(t)), _tokens)
    _has_num_word = any(t -> String(t) in _num_words, _tokens)
    if (_has_digit || _has_num_word) && _has_op_word
        return true
    end

    return false
end

"""
    _has_math_bindings_in_topic(topic::String)::Bool

Check whether the promoted form of a topic contains math sigil bindings (&n, &op).
This is the most rigorous check — it runs the full SigilPromoter pipeline and
checks for arithmetic sigil bindings. Uses ArithmeticEngine.has_math_bindings internally.
"""
function _has_math_bindings_in_topic(topic::AbstractString)::Bool
    try
        _table = _parent_binding(:_ENGINE_SIGIL_TABLE)
        _, bindings = _parent_binding(:promote_input)(_table, topic)  # SigilPromoter.promote_input via lazy lookup
        return _parent_binding(:has_math_bindings)(bindings)  # ArithmeticEngine.has_math_bindings via lazy lookup
    catch
        # Fallback to token-level check if sigil promotion fails
        return _has_arithmetic_tokens(topic)
    end
end

# ── Relational triple analysis for intent classification ──────────────────────

"""
    _extract_arithmetic_triples(text::String)::Bool

Extract relational triples from the text and check if any triple contains
arithmetic sigils (&n, &op). This catches patterns like:
  - (&n, plus, &n) — arithmetic triple after promotion
  - (5, added_to, 3) — natural language that promotes to sigils
  - (result, equals, &n) — result-oriented arithmetic

Relational triples with sigils are DYNAMIC — they evaluate at match time.
The judge should use them to detect when a topic isn't a literal string
but a computation to be performed.
"""
function _extract_arithmetic_triples(text::AbstractString)::Bool
    try
        _extract_fn = _parent_binding(:extract_relational_triples)
        triples = _extract_fn(text)
        for tr in triples
            tr_str = lowercase(string(tr.subject, " ", tr.relation, " ", tr.object))
            # Check if the triple contains sigil tokens or arithmetic operators
            if occursin(r"&n|&op", tr_str) || _has_arithmetic_tokens(tr_str)
                return true
            end
        end
    catch
        # extract_relational_triples may fail on short/malformed input — that's fine
    end
    return false
end

# ── Functorial compound question splitting ────────────────────────────────────

"""
    SubIntent — a sub-intent produced by functorial composition of a compound question.

When "what is 5+5 and what is love" is split at "and", each part becomes a
SubIntent that can be independently classified. The functorial approach
means: split → classify each part → compose the results.

This is fundamentally different from the InputDecomposer's conjunction split,
which operates at the token/sentence level. SubIntent splitting operates at
the INTENT level — it's the routing judge's job to decide how each part
should be handled, not just where to split.
"""
struct SubIntent
    text::String           # The sub-question text (e.g., "what is 5+5")
    kind::Symbol           # The classified intent (e.g., :calculate)
    topic::String          # The extracted topic (e.g., "5+5")
    definition::String     # Definition if any (usually empty for sub-intents)
    hint::String           # Lobe hint if any
    source::String         # Which splitter produced this
end

"""
    _split_compound_question(text::String)::Vector{SubIntent}

Split a compound question on conjunction boundaries ("and", "also", "or")
and classify each sub-question independently. This is the FUNCTORIAL
approach: the compound question is a composition of simpler questions,
and each is classified using token-level analysis.

Returns a vector of SubIntent structs. If the input is not compound,
returns a single SubIntent wrapping the full text with :nothing kind
(caller should classify it normally).

Splitting rules:
  - "what is X and what is Y" → ["what is X", "what is Y"]
  - "what is X and Y" → ["what is X", "what is Y"] (propagate the question word)
  - "X is Y and Z" → ["X is Y", "X is Z"] (propagate the subject)
  - Do NOT split arithmetic expressions: "5+5" stays together, "5 plus 5" stays together
"""
function _split_compound_question(text::AbstractString)::Vector{SubIntent}
    t = String(strip(text))
    isempty(t) && return [SubIntent(t, :nothing, "", "", "", "empty")]

    # ── Step 1: Find split points ──────────────────────────────────────
    # We split on "and" when it connects two independent question/define
    # structures. We do NOT split arithmetic "and" (e.g., "5 and 3" inside
    # an expression like "add 5 and 3").

    tokens = split(t)
    length(tokens) < 4 && return [SubIntent(t, :nothing, "", "", "", "too-short")]

    lower_tokens = [lowercase(String(tok)) for tok in tokens]

    # Find "and" tokens that are NOT arithmetic context
    split_points = Int[]  # indices of "and" tokens to split on
    for i in 2:(length(tokens) - 1)
        tok = lower_tokens[i]
        if tok == "and"
            # GRUG: Arithmetic context guard — "add 5 and 3" must NOT split here.
            # The "and" is connecting arithmetic operands, not joining clauses.
            if _is_arithmetic_and(lower_tokens, i)
                continue
            end
            # Check if right side has clause structure (question word, copula, etc.)
            if _right_has_independent_structure(lower_tokens, i)
                push!(split_points, i)
            end
        end
    end

    isempty(split_points) && return [SubIntent(t, :nothing, "", "", "", "no-split")]

    # ── Step 2: Split and classify each sub-question ───────────────────
    sub_intents = SubIntent[]
    prev = 1
    for sp in split_points
        # Left clause: tokens[prev:sp-1]
        left_text = strip(join(tokens[prev:sp-1], " "))
        if !isempty(left_text)
            push!(sub_intents, SubIntent(left_text, :nothing, "", "", "", "compound-split-left"))
        end
        prev = sp + 1
    end
    # Last clause
    last_text = strip(join(tokens[prev:end], " "))
    if !isempty(last_text)
        push!(sub_intents, SubIntent(last_text, :nothing, "", "", "", "compound-split-right"))
    end

    # ── Step 3: Classify each sub-intent ───────────────────────────────
    # Run token-level analysis on each sub-intent's text to determine its kind.
    classified = SubIntent[]
    for si in sub_intents
        _kind, _topic, _def, _hint = _classify_sub_text(si.text)
        push!(classified, SubIntent(si.text, _kind, _topic, _def, _hint, si.source))
    end

    return classified
end

"""
    _is_arithmetic_and(lower_tokens, i)::Bool

Check if "and" at position i is connecting arithmetic operands, not clauses.
"add 5 and 3" → arithmetic (don't split)
"what is 5+5 and what is love" → NOT arithmetic (split)
"5 and 3 equals 8" → arithmetic (don't split — left is number, right is number)
"""
function _is_arithmetic_and(lower_tokens::Vector{String}, i::Int)::Bool
    # If left neighbor looks like a number and right neighbor looks like a number,
    # this is arithmetic "and" (connecting operands)
    left_is_num = i > 1 && _looks_like_arith_token(lower_tokens[i-1])
    right_is_num = i < length(lower_tokens) && _looks_like_arith_token(lower_tokens[i+1])
    if left_is_num && right_is_num
        return true
    end
    # "add/subtract/multiply/divide N and M" — the "and" connects operands
    if i > 2 && lower_tokens[i-1] in ["add", "subtract", "multiply", "divide", "plus", "minus", "times"]
        return true
    end
    return false
end

"""
    _looks_like_arith_token(tok)::Bool

Check if a lowercase token looks like it could be an arithmetic operand.
"""
function _looks_like_arith_token(tok::AbstractString)::Bool
    # Pure number
    occursin(r"^[+-]?\d+(\.\d+)?$", tok) && return true
    # Number word
    tok in Set(["zero","one","two","three","four","five","six","seven","eight","nine","ten",
                "eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen",
                "eighteen","nineteen","twenty","thirty","forty","fifty","sixty","seventy",
                "eighty","ninety","hundred"]) && return true
    # Operator
    tok in Set(["plus","minus","times","divided","over","multiplied","added","subtracted",
                "add","subtract","multiply","divide"]) && return true
    return false
end

"""
    _right_has_independent_structure(lower_tokens, and_pos)::Bool

Check if the tokens to the RIGHT of "and" at position and_pos have
independent clause structure — question words, copulas, etc.
"""
function _right_has_independent_structure(lower_tokens::Vector{String}, and_pos::Int)::Bool
    right_start = and_pos + 1
    right_start > length(lower_tokens) && return false

    # Question markers that indicate independent clause structure
    _question_starters = Set(["what", "who", "where", "when", "why", "how", "which",
                              "tell", "show", "explain", "describe", "define",
                              "calculate", "compute", "solve"])

    # Check first few tokens of right side
    for i in right_start:min(right_start + 2, length(lower_tokens))
        if lower_tokens[i] in _question_starters
            return true
        end
        # Copula after initial word: "grass is green"
        if lower_tokens[i] in ["is", "are", "was", "were"] && i > right_start
            return true
        end
    end

    return false
end

"""
    _classify_sub_text(text::String)::Tuple{Symbol, String, String, String}

Classify a sub-question text fragment. Returns (kind, topic, definition, hint).
Uses the same pattern matching as collect_intents but on a smaller fragment,
plus token-level arithmetic detection.
"""
function _classify_sub_text(text::AbstractString)::Tuple{Symbol, String, String, String}
    t = String(strip(text))
    isempty(t) && return (:nothing, "", "", "")

    # ── Check for arithmetic first (highest priority for token-level detection) ───
    # If the text or any captured topic contains arithmetic tokens, it's :calculate
    # This catches "what is 5+5", "5+5", "what is 5 plus 5", etc.
    _topic = ""

    # "what is X" pattern on sub-text
    _whatis = match(r"^what\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _whatis !== nothing
        _topic = String(strip(_whatis.captures[1]))
        # Token-level check: is the topic arithmetic?
        if _has_arithmetic_tokens(_topic) || _has_math_bindings_in_topic(_topic)
            return (:calculate, _topic, "", "")
        end
        # Relational triple check: does the topic contain sigil-bearing triples?
        if _extract_arithmetic_triples(_topic)
            return (:calculate, _topic, "", "")
        end
        return (:question, _topic, "", "")
    end

    # "who is X" / "tell me about X" / etc — always :question
    _whois = match(r"^who\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _whois !== nothing
        return (:question, String(strip(_whois.captures[1])), "", "")
    end

    _tellme = match(r"^tell\s+me\s+about\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _tellme !== nothing
        return (:question, String(strip(_tellme.captures[1])), "", "")
    end

    _explain = match(r"^explain\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _explain !== nothing
        return (:question, String(strip(_explain.captures[1])), "", "")
    end

    # "why is X" / "why are X" / "why does X" — question pattern on sub-text
    _whyis = match(r"^why\s+(?:is|are|was|were|does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _whyis !== nothing
        return (:question, String(strip(_whyis.captures[1])), "", "")
    end

    # "where is X" / "when is X" — question pattern on sub-text
    _whereis = match(r"^(?:where|when)\s+(?:is|are|was|were|does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _whereis !== nothing
        return (:question, String(strip(_whereis.captures[1])), "", "")
    end

    # "how is X" / "how are X" — question pattern on sub-text
    _howis = match(r"^how\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _howis !== nothing
        return (:question, String(strip(_howis.captures[1])), "", "")
    end

    # "how does X work" / "how do X work" — question pattern on sub-text
    _howdoes = match(r"^how\s+(?:does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,2})(?:\s+work)?\s*\??\s*$"i, t)
    if _howdoes !== nothing
        return (:question, String(strip(_howdoes.captures[1])), "", "")
    end

    # Bare arithmetic expression: "5+5", "3 plus 4", "12 - 7"
    if _has_arithmetic_tokens(t) || _has_math_bindings_in_topic(t)
        return (:calculate, t, "", "")
    end

    # "X is Y" — define pattern on sub-text
    _xisy = match(r"^(\S+(?:\s+\S+){0,2})\s+(?:is|are)\s+(.+)$"i, t)
    if _xisy !== nothing
        _word = String(strip(_xisy.captures[1]))
        _def = String(strip(_xisy.captures[2]))
        _skip = Set(["what", "who", "where", "when", "why", "how", "which",
                     "it", "this", "that", "there"])
        if !(lowercase(_word) in _skip) && !isempty(_word) && !isempty(_def)
            # Check if the definition side is arithmetic
            if _has_arithmetic_tokens(_def) || _has_math_bindings_in_topic(_def)
                return (:calculate, _def, "", "")
            end
            return (:define, _word, _def, "")
        end
    end

    return (:nothing, "", "", "")
end

# ── Main routing judge ───────────────────────────────────────────────────────

"""
    resolve(candidates::Vector{IntentCandidate};
            verbose::Bool=false)::Union{Nothing, Tuple{Symbol, String, String, String}}

The main routing judge. Takes all candidate intents from the prescan,
scores them, computes entropy, and either passes through (lazy) or applies
jitter snap-back (high entropy).

Returns the winning intent tuple (kind, topic, def, hint), or nothing
if no candidates were viable.
"""
function resolve(candidates::Vector{IntentCandidate};
                 verbose::Bool=false)::Union{Nothing, Tuple{Symbol, String, String, String}}
    n = length(candidates)
    n == 0 && return nothing
    n == 1 && return _emit(candidates[1])  # No ambiguity — lazy pass-through

    # ── Score each candidate ──────────────────────────────────────────────
    scored = ScoredIntent[]
    for c in candidates
        # Base score = match quality + graph backing
        base = c.match_quality
        base += compute_graph_backing(c.topic, c.kind)

        # Conservative bias — GRUG v9.3: use the LEARNED effective bias
        # (static prior + accumulated /right//wrong adjustment), not the
        # raw static dict. This is the routing self-improvement hook.
        bias = effective_bias(c.kind)

        # Pre-jitter final score = base * bias + pending_teach_backing
        # NOTE: pending_teach_backing is applied ADDITIVELY after bias multiplication.
        # This prevents the low :teach bias (0.1) from crushing the pending-teach
        # boost. When there IS pending state, :teach should be competitive even
        # though it is normally the riskiest intent. The additive term is
        # conditional - it is zero when there is no pending state.
        pre_jitter = base * bias
        pre_jitter += compute_pending_teach_backing(c.kind)

        push!(scored, ScoredIntent(c, base, bias, pre_jitter))
    end

    # ── Compute entropy ───────────────────────────────────────────────────
    pre_jitter_scores = [s.final_score for s in scored]
    H = shannon_entropy(pre_jitter_scores)

    if verbose
        println("[ROUTING-JUDGE] Candidates: $n, Entropy: $(round(H, digits=3)) bits")
        for s in scored
            println("  $(s.candidate.kind): base=$(round(s.base_score, digits=3)) bias=$(round(s.bias, digits=3)) pre_jitter=$(round(s.final_score, digits=3)) [$(s.candidate.source)]")
        end
    end

    # ── Lazy threshold check ──────────────────────────────────────────────
    if H < LAZY_ENTROPY_THRESHOLD
        # Clear winner — lazy mode, no jitter needed
        if verbose
            println("[ROUTING-JUDGE] LAZY — entropy below threshold, no jitter")
        end
        best = argmax([s.final_score for s in scored])
        return _emit(scored[best].candidate)
    end

    # ── Jitter snap-back ──────────────────────────────────────────────────
    # Entropy is high — close call between intents. Apply jitter that snaps
    # toward the conservative (safer) intent.
    #
    # The snap is: for each candidate, add (bias * JITTER_SNAP_STRENGTH * H)
    # Higher bias = more snap toward it. H scales the snap — more entropy
    # means more uncertainty, so we lean harder on the conservative prior.
    #
    # This is "pseudo-nonlinear" because the snap interacts with graph backing:
    # if the graph has no backing for :question, the base score is lower,
    # but the conservative bias still snaps toward it. The snap can override
    # a slightly-higher-scoring risky intent when entropy is high.
    for i in 1:length(scored)
        s = scored[i]
        snap = s.bias * JITTER_SNAP_STRENGTH * H
        s_final = s.final_score + snap
        # Update the final score in-place (ScoredIntent is immutable, rebuild)
        scored[i] = ScoredIntent(s.candidate, s.base_score, s.bias, s_final)
    end

    if verbose
        println("[ROUTING-JUDGE] JITTER — entropy=$(round(H, digits=3)) bits, snap applied")
        for s in scored
            println("  $(s.candidate.kind): final=$(round(s.final_score, digits=3)) snap=$(round(s.bias * JITTER_SNAP_STRENGTH * H, digits=3)) [$(s.candidate.source)]")
        end
    end

    best = argmax([s.final_score for s in scored])
    return _emit(scored[best].candidate)
end

"""
    _emit(c::IntentCandidate)::Union{Nothing, Tuple{Symbol, String, String, String}}

Convert an IntentCandidate to the prescan return format.
"""
function _emit(c::IntentCandidate)
    if c.kind === :nothing
        return nothing
    else
        return (c.kind, c.topic, c.definition, c.hint)
    end
end

# ── Intent collector (replaces greedy waterfall) ────────────────────────────

"""
    collect_intents(text::String)::Vector{IntentCandidate}

Run ALL prescan patterns against the input text and collect ALL matches.
This replaces the greedy waterfall (first match wins) with a collector
that gathers every viable intent for the routing judge to resolve.

Patterns are checked in the same order as the original prescan, but
instead of returning on the first match, we continue checking all patterns.
Each match creates an IntentCandidate with match quality and source label.
"""
function collect_intents(text::String)::Vector{IntentCandidate}
    t = strip(text)
    candidates = IntentCandidate[]

    if isempty(t) || startswith(t, "/")
        push!(candidates, IntentCandidate(:nothing, "", "", "", 1.0, "empty-or-slash"))
        return candidates
    end

    # ── Pending teach ──────────────────────────────────────────────────
    # GRUG v9.3: Delegate to the SAME shared classifier the greedy-waterfall
    # fallback uses (`_conv_pending_teach_turn`, in Main.jl) via the lazy
    # `_parent_binding` pattern, instead of maintaining an independent
    # reimplementation here. The two copies had drifted apart (missing
    # ack-words like "idk"/"dunno", no bare-subject-word follow-up, no
    # carried-forward subject) — a single source of truth eliminates that
    # class of bug permanently, and any future improvement to the
    # teach-response heuristics automatically benefits both paths.
    _pending = _get_pending_teach()()
    if !isempty(_pending)
        _status, _payload = _get_pending_teach_turn()(t)
        if _status === :teach
            # `_payload` is (:teach, topic, def, subj). This is a VERY
            # OBVIOUS teach-response case — we explicitly asked a
            # clarification question last turn and this input clearly
            # answers it. Being "lazy conservative" here means NOT
            # second-guessing that with generic single-utterance patterns
            # further down (e.g. the answer text happening to look
            # arithmetic-shaped, like "multiply n by 3 and subtract 2",
            # would otherwise spawn a competing :calculate candidate whose
            # bias, 0.95, is high enough to crush :teach's deliberately-low
            # 0.1 bias even with the pending-teach backing bonus — silently
            # hijacking the answer as an immediate calculation instead of
            # teaching the procedure). Return immediately with just the
            # :teach candidate.
            _tk, _ttopic, _tdef, _tsubj = _payload
            push!(candidates, IntentCandidate(:teach, _ttopic, _tdef, _tsubj, 0.8, "pending-teach-active"))
            return candidates
        elseif _status === :declined
            # Acknowledgment/decline already fully handled (side effects
            # applied inside _conv_pending_teach_turn). Not a teach, not a
            # question — let it fall to :nothing so the caller doesn't
            # double-process this turn.
            push!(candidates, IntentCandidate(:nothing, "", "", "", 1.0, "pending-teach-declined"))
            return candidates
        end
        # :fall_through / :unparsed / :no_pending → fall through to the
        # ordinary pattern candidates below (topic shift, mismatch, or an
        # unparseable reply that should be treated as a fresh utterance).
    end
    # ── Question patterns ─────────────────────────────────────────────────
    _question_topic = ""

    # "what does X mean"
    _whatdoes_match = match(r"^(?:what\s+does|what\s+do)\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s+mean\s*\??\s*$"i, t)
    if _whatdoes_match !== nothing
        _qt = String(strip(_whatdoes_match.captures[1]))
        push!(candidates, IntentCandidate(:question, _qt, "", "", 1.0, "what-does-X-mean"))
    end

    # "what is X" / "what are X" / "what was X"
    _whatis_match = match(r"^what\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _whatis_match !== nothing
        _w = String(strip(_whatis_match.captures[1]))
        _q_skip = Set(["it", "this", "that", "there", "he", "she", "they", "we", "you", "i",
                        "up", "wrong", "happening", "going", "that"])
        if !(lowercase(_w) in _q_skip)
            # GRUG v9: TOKEN-LEVEL ARITHMETIC DETECTION — if the captured topic
            # contains arithmetic sigils (&n, &op) or arithmetic tokens (5+5, 3 plus 4),
            # this is a :calculate intent, NOT a :question about a literal string.
            if _has_arithmetic_tokens(_w) || _has_math_bindings_in_topic(_w)
                push!(candidates, IntentCandidate(:calculate, _w, "", "", 1.0, "what-is-X-arithmetic"))
            elseif _extract_arithmetic_triples(_w)
                push!(candidates, IntentCandidate(:calculate, _w, "", "", 0.9, "what-is-X-triple-arithmetic"))
            else
                push!(candidates, IntentCandidate(:question, _w, "", "", 1.0, "what-is-X"))
            end
        else
            # Pronoun after "what is" — conversational, not knowledge query
            push!(candidates, IntentCandidate(:nothing, "", "", "", 0.6, "what-is-pronoun"))
        end
    end

    # "what X is Y" / "what X are Y" — intervening word pattern (v8.28d)
    _whatwordis_match = match(r"^what\s+([^\s?]+)\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _whatwordis_match !== nothing
        _w2 = String(strip(_whatwordis_match.captures[2]))
        _q_skip2 = Set(["it", "this", "that", "there", "he", "she", "they", "we", "you", "i",
                        "up", "wrong", "happening", "going"])
        if lowercase(_w2) in _q_skip2
            # Conversational — "what time is it"
            push!(candidates, IntentCandidate(:question, String(strip(_whatwordis_match.captures[1])), "", "", 0.9, "what-X-is-pronoun"))
        else
            # "what color is the sky" — knowledge query about full phrase
            _full_topic = String(strip(_whatwordis_match.captures[1])) * " " * _w2
            # GRUG v9: Check if the Y part (or full topic) contains arithmetic tokens.
            # "what is 5+5" won't reach here (it's caught by what-is-X), but
            # "what sum is 3+4" would — Y = "3+4" is arithmetic, not a knowledge topic.
            if _has_arithmetic_tokens(_w2) || _has_math_bindings_in_topic(_w2)
                push!(candidates, IntentCandidate(:calculate, _w2, "", "", 1.0, "what-X-is-Y-arithmetic"))
            elseif _extract_arithmetic_triples(_w2)
                push!(candidates, IntentCandidate(:calculate, _w2, "", "", 0.9, "what-X-is-Y-triple-arithmetic"))
            else
                push!(candidates, IntentCandidate(:question, _full_topic, "", "", 0.9, "what-X-is-Y"))
            end
        end
    end

    # "who is X" / "who are X"
    _whois_match = match(r"^who\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _whois_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_whois_match.captures[1])), "", "", 1.0, "who-is-X"))
    end

    # "tell me about X"
    _tellme_match = match(r"^tell\s+me\s+about\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _tellme_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_tellme_match.captures[1])), "", "", 0.9, "tell-me-about-X"))
    end

    # "explain X"
    _explain_match = match(r"^explain\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _explain_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_explain_match.captures[1])), "", "", 0.9, "explain-X"))
    end

    # "how does X work" / "how do X work"
    _howdoes_match = match(r"^how\s+(?:does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,2})(?:\s+work)?\s*\??\s*$"i, t)
    if _howdoes_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_howdoes_match.captures[1])), "", "", 0.9, "how-does-X"))
    end

    # "how is X" / "how are X"
    _howis_match = match(r"^how\s+(?:is|are|was|were)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _howis_match !== nothing
        _w = String(strip(_howis_match.captures[1]))
        _how_skip = Set(["you", "things", "it", "that", "this", "we", "they"])
        if !(lowercase(_w) in _how_skip)
            push!(candidates, IntentCandidate(:question, _w, "", "", 0.8, "how-is-X"))
        else
            push!(candidates, IntentCandidate(:nothing, "", "", "", 0.5, "how-is-pronoun"))
        end
    end

    # "why is X" / "why does X"
    _why_match = match(r"^why\s+(?:is|are|was|were|does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _why_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_why_match.captures[1])), "", "", 0.9, "why-is-X"))
    end

    # "where is X" / "where does X"
    _where_match = match(r"^where\s+(?:is|are|was|were|does|do|did)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _where_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_where_match.captures[1])), "", "", 0.9, "where-is-X"))
    end

    # "who did X" / "who discovered X"
    _whodid_match = match(r"^who\s+(?:did|discovered|invented|made|created|found|built)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _whodid_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_whodid_match.captures[1])), "", "", 0.9, "who-did-X"))
    end

    # "define X" (standalone)
    _define_q_match = match(r"^define\s+([^\s?]+(?:\s+[^\s?]+){0,2})\s*\??\s*$"i, t)
    if _define_q_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_define_q_match.captures[1])), "", "", 0.9, "define-X"))
    end

    # "what causes/makes/creates/produces/drives X" — question without copula
    _whatverb_match = match(r"^what\s+(?:causes|makes|creates|produces|drives|leads\s+to|contributes\s+to)\s+([^\s?]+(?:\s+[^\s?]+){0,3})\s*\??\s*$"i, t)
    if _whatverb_match !== nothing
        push!(candidates, IntentCandidate(:question, String(strip(_whatverb_match.captures[1])), "", "", 1.0, "what-causes-X"))
    end

    # "where do/does X come from" / "where do/does X"
    # Already covered by the where pattern above

    # ── Correction patterns ───────────────────────────────────────────────
    # "no, X is Y" / "actually, X is Y" / etc (with comma or space)
    _correct_match = match(r"^(?:no[, ]\s*|actually[, ]\s*|wrong[, ]\s*|incorrect[, ]\s*)(.+?)\s+(?:is|are|means)\s+(.+)$"i, t)
    if _correct_match !== nothing
        _word = String(strip(_correct_match.captures[1]))
        _def  = String(strip(_correct_match.captures[2]))
        if !isempty(_word) && !isempty(_def)
            push!(candidates, IntentCandidate(:correct, _word, _def, "", 1.0, "no-X-is-Y"))
        end
    end

    # Broader correction: "no, X verbs Y" (v8.28d)
    _correct_verb_match = match(r"^(?:no[, ]\s*|actually[, ]\s*|wrong[, ]\s*|incorrect[, ]\s*)(\S+(?:\s+\S+){0,2})\s+(?:hangs?|grows?|forms?|appears?|comes?|goes?|lies?|sits?|stands?|falls?|rises?|moves?|flows?|runs?|exists?|lives?|happens?|occurs?|starts?|begins?|ends?|stops?|means?|is|are|was|were|has|have|had|does|do|did|will|would|should|can|could|must|might|shall)\s+(.+)$"i, t)
    if _correct_verb_match !== nothing
        _word = String(strip(_correct_verb_match.captures[1]))
        _def  = String(strip(_correct_verb_match.captures[2]))
        if !isempty(_word) && !isempty(_def)
            _full_def = _word * " " * _def
            push!(candidates, IntentCandidate(:correct, _word, _full_def, "", 0.8, "no-X-verbs-Y"))
        end
    end

    # Standalone correction: "wrong" / "incorrect" / "no"
    _standalone_correct = match(r"^(?:wrong|incorrect|no|bad|nope|nah)\s*$"i, t)
    if _standalone_correct !== nothing
        push!(candidates, IntentCandidate(:correct, "", "", "", 0.7, "standalone-correction"))
    end

    # ── Define patterns ───────────────────────────────────────────────────
    # "define X as Y"
    _define_as_match = match(r"^define\s+(\S+(?:\s+\S+){0,2})\s+as\s+(.+)$"i, t)
    if _define_as_match !== nothing
        _word = String(strip(_define_as_match.captures[1]))
        _def  = String(strip(_define_as_match.captures[2]))
        if !isempty(_word) && !isempty(_def)
            push!(candidates, IntentCandidate(:define, _word, _def, "", 1.0, "define-X-as-Y"))
        end
    end

    # "X means Y"
    _means_match = match(r"^(\S+(?:\s+\S+){0,2})\s+means\s+(.+)$"i, t)
    if _means_match !== nothing
        _word = String(strip(_means_match.captures[1]))
        _def  = String(strip(_means_match.captures[2]))
        _w_lower = lowercase(_word)
        _interrogative_skip = Set(["what", "who", "where", "when", "why", "how", "which"])
        if !(_w_lower in _interrogative_skip) && !isempty(_word) && !isempty(_def)
            push!(candidates, IntentCandidate(:define, _word, _def, "", 0.9, "X-means-Y"))
        end
    end

    # "X is Y" / "X are Y" — the catch-all define pattern
    _xisy_match = match(r"^(\S+(?:\s+\S+){0,2})\s+(?:is|are)\s+(.+)$"i, t)
    if _xisy_match !== nothing
        _word = String(strip(_xisy_match.captures[1]))
        _def  = String(strip(_xisy_match.captures[2]))
        _w_lower = lowercase(_word)
        # Skip interrogatives and pronouns — "what is X" is a question, not a definition
        _skip_words = Set(["what", "who", "where", "when", "why", "how", "which",
                           "it", "this", "that", "there", "he", "she", "they", "we", "you", "i"])
        if !(_w_lower in _skip_words) && !isempty(_word) && !isempty(_def)
            # GRUG v9: If the definition side contains arithmetic tokens, this is
            # actually a :calculate intent disguised as a definition. E.g., "sum is 5+5"
            # means the user wants to compute, not store "5+5" as a definition.
            if _has_arithmetic_tokens(_def) || _has_math_bindings_in_topic(_def)
                push!(candidates, IntentCandidate(:calculate, _def, "", "", 0.9, "X-is-Y-arithmetic"))
            else
                push!(candidates, IntentCandidate(:define, _word, _def, "", 0.5, "X-is-Y"))
            end
        end
    end

    # ── Compound question splitting ──────────────────────────────────────
    # GRUG v9: If no single pattern matched the full input well, try splitting on
    # conjunction boundaries. Compound questions like "what is 5+5 and what is love"
    # don't match any single pattern (the what-is-X regex expects end-of-string),
    # but the compound splitter can break them into independent sub-intents.
    #
    # This is the FUNCTORIAL approach: split → classify each part → compose.
    # Each sub-intent is independently classified and added as a candidate.
    # The routing judge will see multiple candidates and resolve them.
    #
    # We only try this when:
    #   1. The input contains "and" (necessary condition for compound)
    #   2. No candidate has match_quality >= 0.9 (strong match already found)
    #
    # Condition 2 prevents splitting when a pattern already matched well.
    # E.g., "what is love and happiness" matching what-is-X with topic
    # "love and happiness" is fine — it's one question about a compound topic.
    _best_mq = isempty(candidates) ? 0.0 : maximum(c.match_quality for c in candidates)
    if occursin(r"\band\b", lowercase(t)) && _best_mq < 0.9
        _sub_intents = _split_compound_question(String(t))
        for si in _sub_intents
            if si.kind !== :nothing
                # Convert SubIntent to IntentCandidate
                push!(candidates, IntentCandidate(si.kind, si.topic, si.definition,
                                                  si.hint, 0.85, "compound-$(si.source)"))
            end
        end
    end
    # ── Bare arithmetic fallback ────────────────────────────────────────────
    # GRUG v9: If nothing matched but the input IS arithmetic, it's :calculate.
    # E.g., "5+5", "3 plus 4", "12 - 7" — no "what is" prefix, just the expression.
    # This must come BEFORE the "no candidates" fallback.
    if isempty(candidates) && (_has_arithmetic_tokens(String(t)) || _has_math_bindings_in_topic(String(t)))
        push!(candidates, IntentCandidate(:calculate, String(t), "", "", 0.95, "bare-arithmetic"))
    end

    # ── No candidates matched — default to :nothing ───────────────────────
    if isempty(candidates)
        push!(candidates, IntentCandidate(:nothing, "", "", "", 0.3, "default-no-match"))
    end

    return candidates
end

# ── Export ────────────────────────────────────────────────────────────────────

export RoutingJudge, IntentCandidate, ScoredIntent, SubIntent,
       collect_intents, resolve,
       shannon_entropy, compute_graph_backing,
       _split_compound_question, _classify_sub_text,
       _has_arithmetic_tokens, _has_math_bindings_in_topic,
       CONSERVATIVE_BIAS, LAZY_ENTROPY_THRESHOLD, JITTER_SNAP_STRENGTH,
       BIAS_ADJUSTMENT, BIAS_LEARN_RATE, BIAS_ADJUSTMENT_CLAMP,
       effective_bias, record_routing_outcome!,
       get_bias_adjustments, set_bias_adjustments!, reset_bias_adjustments!

end # module RoutingJudge
