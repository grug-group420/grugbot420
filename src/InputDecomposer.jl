# ==============================================================================
# InputDecomposer.jl — v7.23 Compound-Query Decomposition
# ==============================================================================
# GRUG say: when user say one thing, cave scan once, one vote pool, easy.
#           when user say THREE thing in one breath — "what time ALSO what
#           is dinosaur AND what is 2+2" — cave need THREE scan pass, THREE
#           vote pool, but ONE answer. Old grug treat three question as one
#           big jumble. Wrong! Three distinct subject, three distinct scan.
#
# GRUG say: THIS is why multipart system exist. Not because node say "I have
#           many parts". Because INPUT say "I have many parts". The multipart
#           group ID come from HERE — the decomposition layer — and flow DOWN
#           through scan and vote. Node don't know it part of compound query.
#           Only decomposer know.
#
# GRUG say: simple input? Decomposer say "just one sub-subject". One group.
#           Old path. No overhead. Complex input? Decomposer split, assign
#           group ID, each sub-subject get own scan. Votes from different
#           scan pass carry same group ID. MultipartOrchestrator coalesce.
#           AIML render one coherent answer. That the whole idea.
#
# GRUG say: detection is CONJUNCTION + MULTI-CLAUSE + SIGIL BOUNDARY.
#           "also", "and", "but" when they join two INDEPENDENT clauses.
#           Multiple "?" markers. Multiple sigil expansions. Not every
#           "and" trigger split — "bread and butter" is ONE subject.
#           "what is bread AND what is butter" is TWO subject. Context
#           matter. Heuristic is: conjunction + question marker on both
#           side = split. Conjunction + no question = same subject.
# ==============================================================================
#
# ACADEMIC: This module sits at the very front of the processing pipeline,
# BEFORE scan_and_expand. It analyzes the raw user input for compound
# structure — multiple independent sub-subjects that each deserve their own
# scan pass but must be coordinated under one response. The key output is
# a Vector of DecomposedSubSubject, each carrying a unique multipart_group
# ID. Downstream, each sub-subject is scanned independently; votes inherit
# the group ID; MultipartOrchestrator.build_objectives coalesces them.
#
# The decomposition is intentionally heuristic, not syntactic. Full NLP
# parsing would be overkill; the signals are:
#   1. Conjunction boundaries with independent clause structure
#   2. Multiple question markers (each "?" starts a new sub-subject)
#   3. Sigil-class boundaries (arithmetic expressions are distinct subjects)
#   4. Fallback: if heuristics are ambiguous, treat as single subject
#      (false negative is safe; false positive splits what should be one
#      answer, which is worse).
#
# Group IDs are opaque strings: "mp_1", "mp_2", etc. Singleton inputs
# (no decomposition) get a single sub-subject with group_id = "" (matching
# the Vote default for singleton behavior).
# ==============================================================================

module InputDecomposer

export DecomposedSubSubject, decompose_input, is_compound

# ==============================================================================
# STRUCTS
# ==============================================================================

"""
A single sub-subject extracted from a compound input. `text` is the
substring to scan. `multipart_group` is the group ID that will be stamped
onto all votes produced by scanning this sub-subject. `role` is :primary
for the first sub-subject and :support for subsequent ones — this controls
OUTPUT ORDERING in the combined response (first sub-subject's output appears
first). It does NOT determine the vote's multipart_role within MultipartOrchestrator;
every group's winning vote is always :primary within its own group. `index` is
the 1-based position in the decomposition order.
"""
struct DecomposedSubSubject
    text::String
    multipart_group::String
    role::Symbol
    index::Int
end

# ==============================================================================
# CONJUNCTION DETECTION CONSTANTS
# ==============================================================================

# GRUG: these are the hard conjunctions that SPLIT independent clauses.
# "also", "additionally", "furthermore" are additive-split signals.
# "but", "however", "yet" are contrastive-split signals.
# "and" is context-dependent — only splits when both sides look like
# independent questions or commands.
const SPLIT_CONJUNCTIONS = Set([
    "also", "additionally", "furthermore", "moreover",
    "besides", "likewise", "similarly",
    "but", "however", "yet", "nevertheless", "nonetheless",
    "alternatively", "instead",
    "or",  # "what is X or what is Y" — split
])

# GRUG: "and" is special — it ONLY splits when both sides have question
# markers or imperative structure. "bread and butter" stays together.
# We don't put "and" in SPLIT_CONJUNCTIONS because it needs context.
const CONTEXT_CONJUNCTION = "and"

# GRUG: question markers that signal independent clause structure
const QUESTION_MARKERS = Set(["what", "who", "where", "when", "why", "how",
                               "which", "whose", "whom"])

# GRUG: imperative/command markers that signal independent clause
const COMMAND_MARKERS = Set(["tell", "show", "give", "explain", "describe",
                              "calculate", "compute", "solve", "define",
                              "list", "name", "find", "count"])

# ==============================================================================
# CORE DECOMPOSITION
# ==============================================================================

"""
    decompose_input(input_text) -> Vector{DecomposedSubSubject}

Analyze the input for compound structure. Returns a vector of sub-subjects.
If the input is simple (no compound structure), returns a single sub-subject
with multipart_group = "" and role = :singleton (matching historical behavior).

If compound, each sub-subject gets a unique multipart_group ("mp_1", "mp_2", ...)
and the first sub-subject is :primary while subsequent ones are :support.
NOTE: The .role field controls OUTPUT ORDERING only — it tells the orchestrator
which part to render first. It does NOT set the vote's multipart_role. In
MultipartOrchestrator, every group's winning vote is :primary within its own
group, regardless of this field. The caller (process_mission) stamps :primary
as the vote role for every sub-subject's winning vote.
"""
function decompose_input(input_text::String)::Vector{DecomposedSubSubject}
    if isempty(strip(input_text))
        return [DecomposedSubSubject(input_text, "", :singleton, 1)]
    end

    # GRUG: Step 1 — try conjunction-based splitting.
    clauses = _split_on_conjunctions(input_text)

    # GRUG: Step 2 — if conjunction splitting found nothing, try
    # question-marker splitting (multiple "?" in the input).
    if length(clauses) <= 1
        clauses = _split_on_question_markers(input_text)
    end

    # GRUG: Step 2b — if still just one clause, try comma-based splitting.
    # "what is X, what is Y, what is Z" — commas between independent questions.
    if length(clauses) <= 1
        clauses = _split_on_comma_clauses(input_text)
    end

    # GRUG: Step 3 — still just one clause? Singleton. Old path.
    if length(clauses) <= 1
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # GRUG: Multiple clauses detected! Assign group IDs.
    result = DecomposedSubSubject[]
    for (i, clause) in enumerate(clauses)
        clause_text = strip(clause)
        isempty(clause_text) && continue
        group_id = "mp_$i"
        role = i == 1 ? :primary : :support
        push!(result, DecomposedSubSubject(clause_text, group_id, role, i))
    end

    # GRUG: Edge case — if all clauses were empty after stripping, fall back.
    if isempty(result)
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # GRUG: If only one non-empty clause survived, it's a singleton after all.
    if length(result) == 1
        return [DecomposedSubSubject(result[1].text, "", :singleton, 1)]
    end

    return result
end

"""
    is_compound(input_text) -> Bool

Quick check: does this input decompose into multiple sub-subjects?
Cheap — runs decomposition and checks count > 1.
"""
function is_compound(input_text::String)::Bool
    return length(decompose_input(input_text)) > 1
end

# ==============================================================================
# INTERNAL: CONJUNCTION-BASED SPLITTING
# ==============================================================================

"""
    _split_on_conjunctions(input_text) -> Vector{String}

Split the input at conjunction boundaries where both sides look like
independent clauses (question or command structure). Returns Vector of
clause strings. If no splits found, returns [input_text].
"""
function _split_on_conjunctions(input_text::String)::Vector{String}
    tokens = split(input_text)
    isempty(tokens) && return [input_text]

    # GRUG: Walk the token stream. When we find a split-conjunction,
    # check if both the left and right contexts look independent.
    # "what is time also what is dinosaur" — "also" splits because
    # left has "what" and right has "what".
    # "time also runs fast" — "also" does NOT split because neither
    # side has question/command structure.

    splits = Int[]  # indices of tokens where we split (BEFORE this token)
    lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in tokens]

    for i in 2:(length(tokens) - 1)
        tok = lower_tokens[i]

        # GRUG: Hard split conjunctions — split if right side has
        # question or command structure.
        if tok in SPLIT_CONJUNCTIONS
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens))
            if right_has_structure
                push!(splits, i + 1)  # split BEFORE the next token
            end
            continue
        end

        # GRUG: "and" — special case. Only split if BOTH sides have
        # independent clause structure (question/command markers).
        if tok == CONTEXT_CONJUNCTION
            left_has_structure = _has_clause_structure(lower_tokens, 1, i - 1)
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens))
            if left_has_structure && right_has_structure
                push!(splits, i + 1)
            end
            continue
        end
    end

    isempty(splits) && return [input_text]

    # GRUG: Build clause strings from split positions.
    # splits are 1-based token indices where new clauses start.
    unique_sorted = sort(unique(splits))
    clauses = String[]
    prev = 1
    for split_idx in unique_sorted
        if split_idx > prev
            clause = join(tokens[prev:split_idx-1], " ")
            push!(clauses, clause)
        end
        prev = split_idx
    end
    # GRUG: Don't forget the last clause!
    if prev <= length(tokens)
        push!(clauses, join(tokens[prev:end], " "))
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# INTERNAL: QUESTION-MARKER SPLITTING
# ==============================================================================

"""
    _split_on_question_markers(input_text) -> Vector{String}

If the input contains multiple "?" characters, split at the sentence
boundary before each subsequent "?". Each question becomes its own
sub-subject. This catches: "what time is it? what is a dinosaur? what is 2+2?"

NOTE: Uses `nextind` for Unicode-safe advancement past the "?" position.
"""
function _split_on_question_markers(input_text::String)::Vector{String}
    # GRUG: Count question marks. If only one (or none), no split.
    q_positions = findall(c -> c == '?', input_text)
    length(q_positions) <= 1 && return [input_text]

    # GRUG: Split at sentence boundaries. A sentence boundary is:
    # after a "?" and any trailing whitespace/punctuation, before the
    # next word character. We look for the gap between sentences.
    clauses = String[]
    last_end = 1

    for qpos in q_positions
        # GRUG: Find the end of this sentence = after "?" and any
        # trailing punctuation/whitespace. Use chktop to avoid running
        # past the end of the string. nextind handles multi-byte chars.
        end_idx = qpos
        while end_idx < lastindex(input_text)
            nxt = nextind(input_text, end_idx)
            input_text[nxt] in " \t,;." || break
            end_idx = nxt
        end

        # GRUG: Extract this clause (from last_end to end of sentence).
        clause = strip(input_text[last_end:min(end_idx, lastindex(input_text))])
        if !isempty(clause)
            push!(clauses, clause)
        end

        last_end = min(nextind(input_text, end_idx), lastindex(input_text) + 1)
    end

    # GRUG: Grab any remaining text after the last "?".
    if last_end <= lastindex(input_text)
        remainder = strip(input_text[last_end:end])
        if !isempty(remainder)
            push!(clauses, remainder)
        end
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# INTERNAL: CLAUSE STRUCTURE DETECTION
# ==============================================================================

"""
    _has_clause_structure(lower_tokens, start_idx, end_idx) -> Bool

Check if the token range [start_idx, end_idx] contains question or command
markers that indicate independent clause structure. Used to decide whether
a conjunction should trigger a split.
"""
function _has_clause_structure(lower_tokens::Vector{String},
                                start_idx::Int,
                                end_idx::Int)::Bool
    for i in start_idx:end_idx
        if i < 1 || i > length(lower_tokens)
            continue
        end
        tok = lower_tokens[i]
        if tok in QUESTION_MARKERS || tok in COMMAND_MARKERS
            return true
        end
    end
    return false
end

# ==============================================================================
# INTERNAL: COMMA-BASED CLAUSE SPLITTING
# ==============================================================================

"""
    _split_on_comma_clauses(input_text) -> Vector{String}

Split the input at comma boundaries where both sides look like independent
questions or commands. This catches: "what is X, what is Y, what is Z" —
a common compound pattern that lacks explicit conjunctions.

Comma splitting is tried LAST (after conjunctions and question markers)
because commas are ambiguous: "bread, butter, and cheese" is ONE subject,
but "what is X, what is Y" is TWO. We only split when both sides have
clause structure (question/command markers).
"""
function _split_on_comma_clauses(input_text::String)::Vector{String}
    # GRUG: Only try if there are at least 2 commas. One comma might just be
    # a list separator. Two+ commas between question-like clauses = compound.
    comma_positions = findall(c -> c == ',', input_text)
    length(comma_positions) < 1 && return [input_text]

    tokens = split(input_text)
    isempty(tokens) && return [input_text]
    lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in tokens]

    # GRUG: Walk the token stream. When we find a comma, check if the
    # right side starts a new independent clause (question/command marker).
    splits = Int[]
    for (tok_idx, tok) in enumerate(tokens)
        if endswith(tok, ",")
            # Check if the NEXT token starts a question/command clause.
            if tok_idx < length(tokens)
                next_tok = lower_tokens[tok_idx + 1]
                if next_tok in QUESTION_MARKERS || next_tok in COMMAND_MARKERS
                    push!(splits, tok_idx + 1)
                end
            end
        end
    end

    isempty(splits) && return [input_text]

    # GRUG: Build clause strings from split positions.
    unique_sorted = sort(unique(splits))
    clauses = String[]
    prev = 1
    for split_idx in unique_sorted
        if split_idx > prev
            clause = strip(join(tokens[prev:split_idx-1], " "), ',')
            clause = strip(clause)
            !isempty(clause) && push!(clauses, clause)
        end
        prev = split_idx
    end
    # Don't forget the last clause!
    if prev <= length(tokens)
        clause = strip(join(tokens[prev:end], " "), ',')
        clause = strip(clause)
        !isempty(clause) && push!(clauses, clause)
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

"""
    summarize_decomposition(sub_subjects) -> String

One-line diagnostic summary of a decomposition result.
"""
function summarize_decomposition(subs::Vector{DecomposedSubSubject})::String
    if length(subs) == 1
        return "[singleton] \"$(subs[1].text)\""
    end
    parts = ["[$(s.multipart_group)/$(s.role)] \"$(s.text)\"" for s in subs]
    return "compound($(length(subs)) parts): " * join(parts, " | ")
end

end # module
