# Engine.jl
using Base.Threads: Atomic, atomic_add!
using JSON
using Random # GRUG: Need random to roll active node limits and scan modes!

# GRUG: Bring the Pattern Scanner into the cave!
# GRUG: Guard against double-include if PatternScanner already loaded by caller (e.g. test runner).
if !isdefined(@__MODULE__, :PatternScanner)
    include("patternscanner.jl")
    using .PatternScanner
end

# GRUG: Bring the Image SDF converter (JIT GPU-style image processing)!
# GRUG: Guard against double-include if ImageSDF already loaded by caller.
if !isdefined(@__MODULE__, :ImageSDF)
    include("ImageSDF.jl")
    using .ImageSDF
end

# GRUG: Bring the Eye System (edge blur, attention modulation, arousal)!
# GRUG: Guard against double-include if EyeSystem already loaded by caller.
if !isdefined(@__MODULE__, :EyeSystem)
    include("EyeSystem.jl")
    using .EyeSystem
end

# GRUG: Bring the live mutable Verb Registry (user can add verbs + synonyms at runtime)!
# GRUG: Guard against double-include if SemanticVerbs already loaded by caller.
if !isdefined(@__MODULE__, :SemanticVerbs)
    include("SemanticVerbs.jl")
    using .SemanticVerbs
end

# GRUG: Bring the AIML Node System for pattern-based responses.
# GRUG: Guard against double-include if AIMLNodeSystem already loaded by caller.
if !isdefined(@__MODULE__, :AIMLNodeSystem)
    include("AIMLNodeSystem.jl")
    using .AIMLNodeSystem
end

# GRUG: Bring the Action+Tone Predictor (pre-vote arousal tuning and confidence weighting)!
# GRUG: Guard against double-include if ActionTonePredictor already loaded by caller.
if !isdefined(@__MODULE__, :ActionTonePredictor)
    include("ActionTonePredictor.jl")
    using .ActionTonePredictor
end

# GRUG: Bring the Vote Orchestrator (parallel 1000-cap fire + unique Task dispatch + threshold vote picker).
# GRUG: Guard against double-include if VoteOrchestrator already loaded by caller.
if !isdefined(@__MODULE__, :VoteOrchestrator)
    include("VoteOrchestrator.jl")
    using .VoteOrchestrator
end

# GRUG: RelationalJitter — per-activation zero-mean nudge on match score
# components. Loaded at package level by GrugBot420.jl; this guard lets
# engine.jl also run standalone in tests (same pattern as VoteOrchestrator).
if !isdefined(@__MODULE__, :RelationalJitter)
    include("RelationalJitter.jl")
    using .RelationalJitter
end

# ==============================================================================
# SENSORY CONVERSION (TEXT TO SIGNAL)
# ==============================================================================

"""
Converts text into a bounded vector of floats for pattern matching.
"""
function words_to_signal(text::String)::Vector{Float64}
    tokens = split(lowercase(strip(text)))
    if isempty(tokens)
        error("!!! FATAL: Grug cannot turn empty wind into number rocks! !!!")
    end
    
    signal = Float64[]
    for tok in tokens
        # GRUG FIX 2.1: Hash Normalization!
        # hash() returns UInt64. If Grug divide by Int max, Grug lose half the numbers!
        # Grug divide by UInt64 max to get full [0.0 to 1.0] range. 
        # No abs() needed, UInt64 rock is always positive!
        val = Float64(hash(tok)) / Float64(typemax(UInt64))
        push!(signal, val)
    end
    
    return signal
end

# ==============================================================================
# RELATIONAL CHUNKER & DIALECTICAL MATCHER
# ==============================================================================

struct RelationalTriple
    subject::String
    relation::String
    object::String
end

# GRUG: Verb sets are now LIVE and mutable! They live in SemanticVerbs module.
# Old static const rocks are gone. Grug call get_all_verbs() on every extraction loop.
# User can /addVerb, /addRelationClass, /addSynonym at runtime — takes effect immediately.
#
# GRUG: LOAD-TIME SNAPSHOTS — These three const sets capture the DEFAULT verbs at startup.
# They are NOT live. External code (tests, diagnostics) may read them for the initial defaults.
# For live verb matching inside extract_relational_triples(), always call get_all_verbs()!
# These exist only so downstream code that imported them before the live registry existed
# does not break. Do NOT use them for new matching logic.
const CAUSAL_VERBS   = SemanticVerbs.get_verbs_in_class("causal")    # snapshot at load time
const SPATIAL_VERBS  = SemanticVerbs.get_verbs_in_class("spatial")   # snapshot at load time
const TEMPORAL_VERBS = SemanticVerbs.get_verbs_in_class("temporal")  # snapshot at load time

"""
rewrite_passive_mission(input::String)::String

GRUG: Rewrite passive voice constructs to active voice.
"X was Y by Z" → "Z Y X". Used to normalize mission text before scanning.
Throws on empty input — NO SILENT FAILURES.
"""
function rewrite_passive_mission(input::String)::String
    if strip(input) == ""
        error("!!! FATAL: rewrite_passive_mission got empty input! Cannot rewrite empty air! !!!")
    end
    return replace(input, r"\b(\w+)\s+was\s+(\w+)\s+by\s+(\w+)\b"i => s"\3 \2 \1")
end

"""
# GRUG DOC 2.2: Adjacency Assumption Limitation!
# Grug look only at rocks right next to the verb (tokens[i-1], tokens[i+1]).
# This breaks if user uses big compound nouns or punctuation! 
# Future Grug need better chunker, but for now, we just skip bad boundary rocks safely.
"""
function extract_relational_triples(input::String)::Vector{RelationalTriple}
    # GRUG: Step 1 - Normalize synonyms BEFORE any other processing.
    # "triggers" -> "causes", "precede" -> "precedes", etc. User-defined at runtime.
    # This runs on token boundaries so partial words are never corrupted.
    synonym_normalized = SemanticVerbs.normalize_synonyms(input)

    clean_input = rewrite_passive_mission(synonym_normalized)
    tokens = split(lowercase(clean_input))
    
    if isempty(tokens)
        error("!!! FATAL: Grug found no tokens after split. Something wrong with input! !!!")
    end

    triples = RelationalTriple[]

    # GRUG QoL FIX: Need at least 3 rocks to make a (Subject, Verb, Object) gear!
    if length(tokens) < 3
        return triples
    end

    try
        for (i, tok) in enumerate(tokens)
            if tok in SemanticVerbs.get_all_verbs()
                # GRUG: Boundary check so Grug does not reach out of cave and crash.
                if i > 1 && i < length(tokens)
                    subj = String(tokens[i-1])
                    obj  = String(tokens[i+1])
                    
                    # GRUG FIX 2.2: Make sure subject and object are real rocks, not empty wind!
                    if !isempty(subj) && !isempty(obj)
                        push!(triples, RelationalTriple(subj, tok, obj))
                    end
                end
            end
        end
    catch e
        rethrow(e)
    end

    if isempty(triples)
        # GRUG QoL FIX: User speaking without relational verbs is not a machine failure!
        # It just means no dialectical gears to align. Return empty basket safely!
        return triples
    end

    return triples
end

# ==============================================================================
# SEMANTIC CHUNK ROUTER — v7.20
# ==============================================================================
# GRUG: The decoherence problem is that wrong-lobe content (food, survival,
# temporal) bleeds into math/knowledge responses. The lobe topicality gate
# filters the vote pool, but once votes exist, AIML rendering pulls ANY node's
# content for SUPPORT. The fix: chunk the input at the ROUTING level so each
# chunk's semantic span (including build-up like "what is" before "2+2") gets
# its own scoped_mission, and only topical lobes vote on each chunk.
#
# SigilBinding.raw_position tells us where math expressions live in the token
# stream. We expand backward to capture semantic build-up tokens. Relational
# triples from the input provide the semantic structure (subject-verb-object)
# that identifies what the user is actually asking about.
# ==============================================================================

"""
    SemanticChunk

GRUG v7.20: One semantic chunk of the input. A chunk is a contiguous token span
that forms a coherent semantic unit. Math chunks include their build-up (the
"what is" before "2+2"). Non-math chunks are the remaining topical content.
"""
struct SemanticChunk
    text::String              # The chunk text (e.g. "what is 2 plus 2")
    kind::Symbol              # :math_semantic, :knowledge, :emotive, :procedural
    token_start::Int          # 0-based start index in raw token stream
    token_end::Int            # 0-based end index in raw token stream (inclusive)
    is_primary::Bool          # true if this chunk contains sigil bindings (math)
end

# GRUG v7.20: Semantic build-up markers — tokens that commonly precede a math
# expression and are part of the question, not separate content. These are
# the "semantic build-up" the user specifically asked to include with the math.
# E.g. "what is 2+2" → the "what is" is build-up, not a separate knowledge query.
const MATH_BUILDUP_MARKERS = Set([
    "what", "is", "are", "was", "were",        # question openers
    "answer", "calculate", "compute", "solve",  # intent verbs
    "tell", "me", "about",                       # request framing
    "the", "result", "of",                       # noun phrases
    "find", "determine", "evaluate",             # procedural verbs
    "how", "much", "many",                       # quantity questions
    "does", "do", "would", "will",               # auxiliary verbs
    "give", "show", "get",                       # request verbs
    "please", "can", "could",                    # politeness markers
])

# GRUG v7.20: Maximum build-up lookback. We look backward from the first math
# binding at most this many tokens to find semantic build-up. Prevents
# over-eating into prior unrelated content.
const MAX_BUILDUP_LOOKBACK = 6

"""
    _extract_math_buildup_span(tokens, first_binding_raw_pos) -> (start, end)

GRUG v7.20: Given the raw token list and the raw_position of the first math
binding (&n), look backward to find where the semantic build-up begins. The
build-up is the contiguous run of MATH_BUILDUP_MARKERS tokens leading up to
the first math token. If the first non-marker token is found, the build-up
starts just after it. If no build-up is found, the span starts at the first
binding position.

Returns (start_idx, end_idx) as 0-based inclusive indices into the raw token
stream. end_idx is the raw_position of the LAST math binding (the last &n).
"""
function _extract_math_buildup_span(tokens::Vector{String},
                                     first_binding_pos::Int,
                                     last_binding_pos::Int)::Tuple{Int, Int}
    # GRUG: Start looking backward from just before the first math token.
    # Build the longest contiguous run of build-up markers going backward.
    buildup_start = first_binding_pos

    lookback_start = max(1, first_binding_pos - MAX_BUILDUP_LOOKBACK)
    for i in (first_binding_pos - 1):-1:lookback_start
        if i < 1
            break
        end
        tok_lower = lowercase(strip(tokens[i]))
        if tok_lower in MATH_BUILDUP_MARKERS
            buildup_start = i
        else
            # GRUG: Hit a non-marker token — stop. Build-up must be contiguous.
            break
        end
    end

    return (buildup_start, last_binding_pos)
end

"""
    decompose_semantic_chunks(input_text, mediation) -> Vector{SemanticChunk}

GRUG v7.20: Split the input into semantic chunks using SigilMediator binding
positions. For math inputs, the math expression AND its semantic build-up
("what is 2 plus 2", not just "2 plus 2") form one chunk. The remaining
tokens (if any) form separate chunks.

For non-math inputs, the entire input is one chunk of kind :knowledge.

For multipart inputs (InputDecomposer already split on conjunctions), this
function operates WITHIN each clause — it further refines the clause into
math-semantic vs. non-math chunks if the clause contains math bindings.

Returns a Vector{SemanticChunk} in left-to-right order. At least one chunk
is always returned (the full input if no math is detected).
"""
function decompose_semantic_chunks(input_text::String,
                                    mediation)::Vector{SemanticChunk}
    if strip(input_text) == ""
        error("!!! FATAL: decompose_semantic_chunks got empty input! !!!")
    end

    tokens = split(input_text)
    n_tokens = length(tokens)

    # GRUG: No mediation or no bindings → single knowledge chunk.
    if isnothing(mediation) || isempty(getfield(mediation, :bindings))
        return SemanticChunk[
            SemanticChunk(input_text, :knowledge, 0, max(0, n_tokens - 1), true)
        ]
    end

    bindings = getfield(mediation, :bindings)
    kinds = getfield(mediation, :kinds)

    # GRUG: No math kind → single knowledge chunk.
    if !(:math in kinds)
        return SemanticChunk[
            SemanticChunk(input_text, :knowledge, 0, max(0, n_tokens - 1), true)
        ]
    end

    # GRUG: Math detected! Find the math binding span using raw_position.
    # SigilBinding.raw_position is 0-based index into the raw token stream.
    math_bindings = [b for b in bindings if b.name in ("n", "op")]

    if isempty(math_bindings)
        # GRUG: No &n or &op bindings despite :math kind — shouldn't happen,
        # but handle gracefully.
        return SemanticChunk[
            SemanticChunk(input_text, :knowledge, 0, max(0, n_tokens - 1), true)
        ]
    end

    # GRUG: raw_position is 0-based. Julia is 1-based. Convert carefully.
    # The binding's raw_position points to the word in the ORIGINAL input
    # (before canonicalization). We need to map these to 1-based token indices.
    first_math_1based = minimum(b.raw_position for b in math_bindings) + 1
    last_math_1based  = maximum(b.raw_position for b in math_bindings) + 1

    # GRUG: Expand the span backward to capture semantic build-up.
    # "what is 2 plus 2" → math bindings at positions 2,3,4 (1-based),
    # build-up "what is" at positions 1,2 → full span = [1..4]
    buildup_start_1based, math_end_1based = _extract_math_buildup_span(
        String.(tokens), first_math_1based, last_math_1based
    )

    # GRUG: Build the math-semantic chunk text.
    math_start_clamped = clamp(buildup_start_1based, 1, n_tokens)
    math_end_clamped   = clamp(math_end_1based, 1, n_tokens)

    math_chunk_text = strip(join(tokens[math_start_clamped:math_end_clamped], " "))

    chunks = SemanticChunk[]

    # GRUG: If there's content BEFORE the math build-up, it's a separate chunk.
    if math_start_clamped > 1
        pre_text = strip(join(tokens[1:math_start_clamped - 1], " "))
        if !isempty(pre_text)
            # GRUG: Infer the kind of the pre-math chunk from content.
            pre_kind = _infer_chunk_kind(pre_text)
            push!(chunks, SemanticChunk(
                pre_text, pre_kind,
                0,                          # token_start (0-based)
                math_start_clamped - 2,     # token_end (0-based, inclusive)
                false                       # not primary
            ))
        end
    end

    # GRUG: The math-semantic chunk — the core of the user's directive.
    push!(chunks, SemanticChunk(
        String(math_chunk_text), :math_semantic,
        math_start_clamped - 1,     # token_start (0-based)
        math_end_clamped - 1,       # token_end (0-based, inclusive)
        true                        # IS primary
    ))

    # GRUG: If there's content AFTER the math expression, it's a separate chunk.
    if math_end_clamped < n_tokens
        post_text = strip(join(tokens[math_end_clamped + 1:n_tokens], " "))
        if !isempty(post_text)
            post_kind = _infer_chunk_kind(post_text)
            push!(chunks, SemanticChunk(
                post_text, post_kind,
                math_end_clamped,          # token_start (0-based)
                n_tokens - 1,              # token_end (0-based, inclusive)
                false                      # not primary
            ))
        end
    end

    # GRUG: If somehow no chunks were built (edge case), return full input.
    if isempty(chunks)
        return SemanticChunk[
            SemanticChunk(input_text, :knowledge, 0, max(0, n_tokens - 1), true)
        ]
    end

    return chunks
end

"""
    _infer_chunk_kind(text) -> Symbol

GRUG v7.20: Heuristic kind assignment for non-math chunks. Uses keyword
matching to classify the chunk. Falls back to :knowledge for unrecognized text.
"""
function _infer_chunk_kind(text::String)::Symbol
    lower = lowercase(strip(text))
    # GRUG: emotive markers — feelings, emotions, self-references
    emotive_markers = ["feel", "feeling", "angry", "sad", "happy", "scared",
                       "afraid", "worried", "anxious", "love", "hate",
                       "frustrated", "upset", "comfort", "mood"]
    for m in emotive_markers
        if occursin(m, lower)
            return :emotive
        end
    end

    # GRUG: procedural markers — instructions, requests
    procedural_markers = ["how", "do", "make", "build", "create", "tell",
                          "show", "give", "explain", "teach", "help",
                          "can you", "could you"]
    for m in procedural_markers
        if occursin(m, lower)
            return :procedural
        end
    end

    # GRUG: default — knowledge query or statement
    return :knowledge
end

"""
    _lobe_topicality_for_vote(vote, mission_text) -> Float64

GRUG v7.20: Compute lobe topicality for an individual vote. Finds which lobe
the vote's node belongs to, then computes the thesaurus-expanded token overlap
between that lobe's subject and the mission text. Returns 0.0 for unassigned
nodes or on error.

This extends the lobe topicality gate from the scan level (where it filters
the vote pool) into the AIML rendering level (where it gates support content).
"""
function _lobe_topicality_for_vote(vote, mission_text::String)::Float64
    try
        lobe_id = Lobe.find_lobe_for_node(vote.node_id)
        if isnothing(lobe_id)
            return 0.0
        end
        rec = Lobe.get_lobe(lobe_id)
        mission_expanded = try
            Thesaurus.thesaurus_gate_filter(mission_text)
        catch
            Set(lowercase.(filter(!isempty, map(strip, split(mission_text)))))
        end
        return _compute_lobe_topicality(rec.subject, mission_expanded)
    catch
        return 0.0
    end
end

"""
    _triple_is_topical(triple, mission_text) -> Bool

GRUG v7.20: Check if a relational triple is topically relevant to the mission
text. A triple is topical if any of its components (subject, relation, object)
shares at least one non-stopword token with the mission text. Triples like
(dish, &causal, strength) for a math mission have zero overlap and get filtered.

Stopwords (the, a, an, is, are, was, were, what, how, why, when, it, that,
this, of, for, in, on, at, to, with, and, or, but) are excluded from the
overlap check so that generic tokens don't create false topicality.
"""
function _triple_is_topical(triple, mission_text::String)::Bool
    STOPWORDS = Set(["the", "a", "an", "is", "are", "was", "were", "what",
                     "how", "why", "when", "it", "that", "this", "of", "for",
                     "in", "on", "at", "to", "with", "and", "or", "but",
                     "do", "does", "did", "has", "have", "had", "be", "been",
                     "am", "not", "no", "nor", "so", "if", "then", "than",
                     "too", "very", "just", "about", "up", "out", "can",
                     "will", "would", "could", "should", "may", "might"])

    # GRUG: tokenize the triple components
    triple_tokens = Set{String}()
    for component in [triple.subject, triple.relation, triple.object]
        for tok in split(lowercase(strip(String(component))))
            tok_clean = lowercase(strip(tok))
            if length(tok_clean) >= 3 && !(tok_clean in STOPWORDS)
                push!(triple_tokens, tok_clean)
            end
        end
    end

    # GRUG: Skip sigil tokens (&causal, &spatial etc.) — they're not topical
    triple_tokens = filter(t -> !startswith(t, "&"), triple_tokens)

    if isempty(triple_tokens)
        return false  # triple has no content tokens to match
    end

    # GRUG: tokenize the mission text (same method as relevance scoring)
    mission_tokens = Set{String}()
    for tok in split(lowercase(strip(mission_text)))
        tok_clean = lowercase(strip(tok))
        if length(tok_clean) >= 3 && !(tok_clean in STOPWORDS)
            push!(mission_tokens, tok_clean)
        end
    end

    # GRUG: Any overlap = topical
    return !isempty(intersect(triple_tokens, mission_tokens))
end

"""
extract_dynamic_relational_triples(input::String, scan_mode::Int)::Vector{RelationalTriple}

GRUG: Dynamic relational extraction for complex inputs (high-res scan mode).
When scan_mode >= 3 (high-res), this performs more sophisticated extraction:
  - Captures compound subjects/objects across multiple tokens
  - Handles nested relations (e.g., "A causes B which causes C")
  - Detects implicit relations through conjunctions and prepositions
  - Extracts causal chains and temporal sequences
  - Handles multiple clauses with proper scope

This follows the "wave" of complexity - if pattern scan goes high-res,
relational extraction should too. For simple inputs (scan_mode < 3),
falls back to basic extract_relational_triples() for efficiency.

Throws on empty input - NO SILENT FAILURES.
"""
function extract_dynamic_relational_triples(input::String, scan_mode::Int)::Vector{RelationalTriple}
    if strip(input) == ""
        error("!!! FATAL: extract_dynamic_relational_triples got empty input! Cannot extract relations from empty air! !!!")
    end
    
    # GRUG: For simple inputs, use basic extraction (efficiency)
    if scan_mode < 3
        return extract_relational_triples(input)
    end
    
    # GRUG: High-res mode - perform sophisticated extraction
    triples = RelationalTriple[]
    
    # Step 1: Normalize synonyms first
    synonym_normalized = SemanticVerbs.normalize_synonyms(input)
    clean_input = rewrite_passive_mission(synonym_normalized)
    tokens = split(lowercase(clean_input))
    
    if isempty(tokens)
        error("!!! FATAL: Grug found no tokens after split. Something wrong with input! !!!")
    end
    
    if length(tokens) < 3
        return triples
    end
    
    try
        # GRUG: Get all live verbs for matching
        all_verbs = SemanticVerbs.get_all_verbs()
        
        # GRUG: Track for compound subject/object construction
        i = 1
        while i <= length(tokens)
            tok = tokens[i]
            
            if tok in all_verbs
                # GRUG: Extract compound subject (look backward)
                subj_parts = String[]
                j = i - 1
                while j >= 1
                    candidate = String(tokens[j])
                    # Stop at verb or conjunction boundary
                    if candidate in all_verbs || candidate in ["and", "or", "but", "which", "that", "who", "whose"]
                        break
                    end
                    pushfirst!(subj_parts, candidate)
                    j -= 1
                end
                subject = join(subj_parts, " ")
                
                # GRUG: Extract compound object (look forward)
                obj_parts = String[]
                j = i + 1
                while j <= length(tokens)
                    candidate = String(tokens[j])
                    # Stop at verb boundary
                    if candidate in all_verbs
                        break
                    end
                    push!(obj_parts, candidate)
                    j += 1
                end
                object = join(obj_parts, " ")
                
                # GRUG: Add triple if valid
                if !isempty(subject) && !isempty(object)
                    push!(triples, RelationalTriple(subject, tok, object))
                    
                    # GRUG: High-res feature - detect nested relations via "which" clause
                    # e.g., "A causes B which causes C" -> extract (A causes B) and (B causes C)
                    if "which" in obj_parts || "that" in obj_parts
                        which_idx = findfirst(x -> x in ["which", "that"], obj_parts)
                        if !isnothing(which_idx) && which_idx < length(obj_parts)
                            # Look for verb after "which/that"
                            for k in (which_idx + 1):length(obj_parts)
                                if obj_parts[k] in all_verbs && k < length(obj_parts)
                                    nested_obj = join(obj_parts[(k+1):end], " ")
                                    if !isempty(nested_obj)
                                        # Create nested relation: subject of clause verb -> object
                                        # The clause subject is the compound object minus the which/that part
                                        clause_subj = join(obj_parts[1:(which_idx-1)], " ")
                                        if !isempty(clause_subj)
                                            push!(triples, RelationalTriple(clause_subj, obj_parts[k], nested_obj))
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                
                # Skip tokens we've already processed
                i += max(1, length(obj_parts))
            else
                i += 1
            end
        end
        
    catch e
        rethrow(e)
    end
    
    if isempty(triples)
        # GRUG QoL FIX: No relations found is not a failure
        return triples
    end
    
    return triples
end

"""
# GRUG DOC 2.3 & 2.7: Match Score expectations!
# If node demands a relation user doesn't have, Grug return Sentinel -9999.0!
# Normal match scores add up! Score can easily exceed 1.0 (sometimes 2.0+). 
# When added to PatternScanner confidence, total confidence can be 3.0+. 
# This is expected! High score means BIG ROCK.
"""
function evaluate_relational_dialectics(
    user_triples::Vector{RelationalTriple}, 
    node_triples::Vector{RelationalTriple},
    required_relations::Vector{String},
    relation_weights::Dict{String, Float64}
)::Float64

    if isempty(node_triples)
        return 0.0
    end

    # GRUG v7.27: is_antimatch removed. Anti-match nodes were driving decoherence —
    # a node with reversed subject/object triples was hard-killed instead of just
    # scoring negatively. This caused legitimate nodes to vanish from the pipeline
    # mid-scan, leaving orphaned votes and incoherent response assembly.
    # Now: reversed triples just contribute negative score (same as before) but
    # the node is NOT excluded from the pipeline. Confidence gating handles the rest.
    match_score = 0.0
    orthogonal_penalty = 0.0

    # GRUG v7.21: Check NONJITTER tag ONCE up front. The tag lives in
    # required_relations (see src/engine.jl §"PER-NODE NONJITTER TAG"), so
    # we already have it in hand — no extra field, no extra lookup, no lock.
    # If set, every RelationalJitter.jitter_* call below collapses into the
    # identity function so the node returns bit-stable relational scores.
    # NOTE: we do NOT check required_relations against user_rels for the
    # NONJITTER tag — it's a behavioral flag, not a required semantic relation,
    # so the user never needs to "supply" it. The hard-requirement loop below
    # already scans required_relations for user-rel membership; we MUST make
    # sure the NONJITTER string is not treated as a missing semantic relation.
    # Implementation: skip the tag inside the membership check.
    nonjitter = NONJITTER_TAG in required_relations

    if !isempty(required_relations)
        user_rels = Set([t.relation for t in user_triples])
        for req in required_relations
            # GRUG v7.21: NONJITTER is a behavioral tag, not a semantic relation.
            # Do not treat it as a missing requirement if the user didn't supply it.
            req == NONJITTER_TAG && continue
            if !(req in user_rels)
                # GRUG FIX 2.7: Sentinel Value for hard requirement miss!
                return -9999.0
            end
        end
    end

    # GRUG: Per-activation jitter — each contribution below gets a tiny
    # zero-mean nudge via RelationalJitter.jitter_score. The jitter is
    # symmetric so repeated activations snap back to the deterministic
    # match score in expectation; any single activation just sees a nudge
    # that can tip exact ties toward weaker neighbors. See RelationalJitter.jl.
    #
    # v7.21 NONJITTER HONOR: if the incoming required_relations carries the
    # NONJITTER tag, every jitter_* call becomes identity. We pre-select the
    # callable once instead of branching inside the hot double-loop so the
    # branch-predictor sees a single stable pattern per activation.
    jitter_w = nonjitter ? identity : RelationalJitter.jitter_weight
    jitter_s = nonjitter ? identity : RelationalJitter.jitter_score

    for ut in user_triples
        for nt in node_triples
            # GRUG: Weight itself gets the first nudge — same bullseye every
            # activation otherwise. jitter_weight is the sign-preserving wrapper.
            weight = jitter_w(get(relation_weights, ut.relation, 1.0))
            if ut.relation == nt.relation
                if ut.subject == nt.object && ut.object == nt.subject
                    # GRUG v7.27: reversed triples subtract score but NO LONGER
                    # hard-kill the node. The old is_antimatch flag caused the
                    # entire node to be dropped from scan_specimens, driving
                    # decoherence. Now it just scores negatively and the node
                    # stays in the pool for confidence gating to handle.
                    match_score -= jitter_s(2.0 * weight)
                elseif ut.subject == nt.subject && ut.object == nt.object
                    match_score += jitter_s(2.0 * weight)
                elseif ut.subject == nt.subject || ut.object == nt.object
                    match_score += jitter_s(1.0 * weight)
                else
                    orthogonal_penalty += jitter_s(0.5 * weight)
                end
            end
        end
    end

    # GRUG COHERENCE FIX: Don't let large user paragraphs nuke perfectly matched triples!
    # GRUG: Final dampener also gets a jitter so the 0.1 floor and the 0.1
    # penalty multiplier aren't deterministic constants. Sentinel (-9999.0)
    # and true zero are handled internally by jitter_value and pass through
    # untouched — the hard-requirement-miss contract is preserved.
    # v7.21: NONJITTER collapses this final jitter to identity as well.
    if match_score > 0
        final_score = max(0.1, match_score - jitter_s(orthogonal_penalty * 0.1))
    else
        final_score = match_score - orthogonal_penalty
    end

    return final_score
end

# ==============================================================================
# STRENGTH CAP & APOPTOSIS CONSTANTS
# ==============================================================================

# GRUG: Strength lives in [0.0, STRENGTH_CAP]. At 0.0, node is marked grave.
# At STRENGTH_CAP, node cannot grow stronger (apoptosis ceiling / stratification).
const STRENGTH_CAP   = 10.0
const STRENGTH_FLOOR = 0.0

# GRUG: Nodes with response time averages above this threshold get GRAVED-SLOW.
# 24-hour ledger clears daily. Time in seconds.
const SLOW_NODE_THRESHOLD_SECONDS = 5.0
const LEDGER_CLEAR_INTERVAL       = 86400.0  # GRUG: 24 hours in seconds

# GRUG: Max neighbors before node is UNLINKABLE (apoptosis of link capacity).
const MAX_NEIGHBORS = 4

# GRUG: Minimum map size before automatic neighbor latching is allowed.
# Below this threshold, the map is too small for token overlap similarity to be
# statistically meaningful. Latching on a tiny map creates junk topology — two
# unrelated nodes link just because they're the only ones available.
# Above NODE_LATCH_THRESHOLD, the specimen has enough diversity that overlap
# similarity actually reflects semantic proximity. THEN latch kicks in.
const NODE_LATCH_THRESHOLD = 1000

# ==============================================================================
# CORE ENGINE STRUCTURES
# ==============================================================================

mutable struct Node
    id::String
    pattern::String
    signal::Vector{Float64}          # GRUG: Number rocks for Pattern Scanner!
    action_packet::String 
    json_data::Dict{String, Any}
    drop_table::Vector{String}
    throttle::Float64
    relational_patterns::Vector{RelationalTriple}
    required_relations::Vector{String}
    relation_weights::Dict{String, Float64}

    # GRUG NEW: Strength system (apoptosis + stratification)
    strength::Float64                # GRUG: Node power [0.0, STRENGTH_CAP]

    # GRUG NEW: Is this node an image node? (pattern is SDF binary, not text)
    is_image_node::Bool

    # GRUG NEW: Neighbor linking (max MAX_NEIGHBORS before UNLINKABLE)
    neighbor_ids::Vector{String}
    is_unlinkable::Bool              # GRUG: True when neighbor_ids reaches MAX_NEIGHBORS

    # GRUG NEW: Grave tracking (strength hits 0 OR slow response average)
    is_grave::Bool
    grave_reason::String             # GRUG: "STRENGTH_ZERO", "GRAVED-SLOW", or ""

    # GRUG NEW: Big-O response time ledger (clears every 24 hours)
    response_times::Vector{Float64}  # GRUG: Rolling list of response times (seconds)
    ledger_last_cleared::Float64     # GRUG: Unix timestamp of last 24hr clear

    # GRUG NEW: Hopfield cache key (hash of pattern, used for familiar input lookup)
    hopfield_key::UInt64

    # GRUG NEW: Contributed to output this cycle (for /right and /wrong feedback)
    fired_this_cycle::Bool           # GRUG: True if node's vote was used by AIML orchestrator
    voted_this_cycle::Bool           # GRUG: True if node voted (may or may not have contributed)
    gained_this_cycle::Bool          # GRUG: True if node gained strength this cycle
    strength_delta_this_cycle::Float64  # GRUG: Strength change this cycle (for over-compensation penalty)
end

struct Vote
    node_id::String
    action::String
    confidence::Float64
    negatives::Vector{String}
    user_triples::Vector{RelationalTriple}
    node_triples::Vector{RelationalTriple}
    # GRUG v7.27: antimatch::Bool field REMOVED. Anti-match nodes were driving
    # decoherence by hard-killing nodes mid-scan. The field is gone entirely.
    # Confidence gating handles low-score nodes now.
    # GRUG v7.16+: optional payload string for sigil-routed multi-vote nodes.
    # When non-empty, command renderers concatenate "<action_output> <payload>"
    # so `action` stays a valid COMMANDS key while structured content (e.g.
    # arithmetic answer "= 4", clause text) rides along.
    # All existing 6-arg call sites (cast_vote, cast_explicit_vote, every
    # test fixture) work unchanged via the inner constructor's default.
    payload::String
    # GRUG v7.17+: multipart vote grouping. objective_id ties votes from
    # the same compound question together so AIML can orchestrate them as a
    # coherent bundle instead of independent singleton votes.
    # bundle_role: :singleton (default), :step_n (math chain intermediate),
    # :final (math chain answer), :companion (multipart clause vote).
    objective_id::UInt64
    bundle_role::Symbol

    Vote(node_id::AbstractString,
         action::AbstractString,
         confidence::Real,
         negatives::Vector{String},
         user_triples::Vector{RelationalTriple},
         node_triples::Vector{RelationalTriple},
         payload::AbstractString = "",
         objective_id::UInt64 = UInt64(0),
         bundle_role::Symbol = :singleton) = new(
            String(node_id), String(action), Float64(confidence),
            negatives, user_triples, node_triples, String(payload),
            objective_id, bundle_role,
         )
end

# GRUG v7.17+: monotonically increasing counter for objective_id.
# Each compound input cycle gets a fresh ID; votes stamped with the same
# objective_id belong to the same logical question.
const _OBJECTIVE_COUNTER = Ref{UInt64}(UInt64(0))

function fresh_objective_id()::UInt64
    _OBJECTIVE_COUNTER[] += UInt64(1)
    return _OBJECTIVE_COUNTER[]
end

const NODE_MAP  = Dict{String, Node}()
const COMMANDS  = Dict{String, Function}()
const NODE_LOCK = ReentrantLock()
const ID_COUNTER = Atomic{Int}(0)

# ==============================================================================
# HOPFIELD FAMILIAR INPUT CACHE
# ==============================================================================

# GRUG: When a highly familiar input comes in, skip the full scan.
# Map: input_hash -> Vector of node_ids that fired at high confidence for this input.
# This is the Hopfield precache: known inputs get precached node IDs fired directly.
const HOPFIELD_CACHE      = Dict{UInt64, Vector{String}}()
const HOPFIELD_CACHE_LOCK = ReentrantLock()

# GRUG: Confidence threshold above which a result gets stored in Hopfield cache.
const HOPFIELD_STORE_THRESHOLD   = 1.5
# GRUG: How many times an input must repeat before it's considered "familiar" enough
# to use the Hopfield cache instead of a full scan.
const HOPFIELD_HIT_COUNT_MIN     = 2
const HOPFIELD_HIT_COUNTS        = Dict{UInt64, Int}()

# ============================================================================
# HOPFIELD CACHE FUNCTIONS - RE-ENABLED for test compatibility
# ============================================================================
"""
hopfield_input_hash(input_text::String)::UInt64

GRUG: Compute a stable hash for a normalized input string.
Used as the key for Hopfield cache lookups.
"""
function hopfield_input_hash(input_text::String)::UInt64
    if strip(input_text) == ""
        error("!!! FATAL: hopfield_input_hash got empty input! !!!")
    end
    # GRUG: Normalize before hashing (lowercase, strip, collapse spaces)
    normalized = join(split(lowercase(strip(input_text))), " ")
    return hash(normalized)
end

"""
hopfield_lookup(input_hash::UInt64)::Union{Vector{String}, Nothing}

GRUG: Check if this input hash is familiar enough for Hopfield fast-path.
Returns cached node_ids if familiar, Nothing if not cached or not yet familiar.
"""
function hopfield_lookup(input_hash::UInt64)::Union{Vector{String}, Nothing}
    return lock(HOPFIELD_CACHE_LOCK) do
        hit_count = get(HOPFIELD_HIT_COUNTS, input_hash, 0)
        if hit_count >= HOPFIELD_HIT_COUNT_MIN && haskey(HOPFIELD_CACHE, input_hash)
            return HOPFIELD_CACHE[input_hash]
        end
        return nothing
    end
end

"""
hopfield_record!(input_hash::UInt64, node_ids::Vector{String})

GRUG: Record that these node_ids fired for this input hash at high confidence.
Increment hit counter. Once hit count reaches HOPFIELD_HIT_COUNT_MIN, future
lookups will use the cache instead of doing a full scan.
"""
function hopfield_record!(input_hash::UInt64, node_ids::Vector{String})
    if isempty(node_ids)
        # GRUG: Nothing to cache. Not a failure, just skip.
        return
    end
    lock(HOPFIELD_CACHE_LOCK) do
        HOPFIELD_CACHE[input_hash] = node_ids
        HOPFIELD_HIT_COUNTS[input_hash] = get(HOPFIELD_HIT_COUNTS, input_hash, 0) + 1
    end
end

# ==============================================================================
# v7.20 — PER-NODE NONJITTER TAG
# ==============================================================================
# GRUG: Some rocks must stay still. Jitter good for most rocks (snap-back breath
# keeps system alive and adaptive), but anchor rocks, calibration rocks, and
# canonical-form rocks get broken if they wiggle. So grug give those rocks a tag.
# If node carries NONJITTER tag in its required_relations, jitter systems skip it.
#
# Storage: tag lives as the string "NONJITTER" inside node.required_relations.
# This means:
#   - No struct change needed.
#   - Tag survives specimen save/restore for free (required_relations already serialized).
#   - Node creation kwarg `required_relations=["NONJITTER"]` just works.
#   - Runtime tag add/remove is a plain Vector{String} push/filter operation.
#
# Honoring: helpers that apply bounded-snap-back jitter check is_nonjitter(node)
# and skip the jitter call when the tag is present. The tag is orthogonal to the
# global _JITTER_ENABLED toggle in RelationalJitter — a NONJITTER node is silent
# even when global jitter is on.
# ==============================================================================

const NONJITTER_TAG = "NONJITTER"

"""
    is_nonjitter(node::Node)::Bool

GRUG: Rock carry NONJITTER tag? If yes, jitter systems must leave rock alone.
Pure check, no mutation, no allocation. Safe to call from hot paths.
"""
function is_nonjitter(node::Node)::Bool
    # GRUG: required_relations is a plain Vector{String}. `in` is O(n) but
    # required_relations is almost always small (≤ 4 entries), so this is
    # effectively constant-time. No lock needed — node.required_relations
    # is a direct field read and this function is nominally called from the
    # same thread that holds a reference to the node.
    return NONJITTER_TAG in node.required_relations
end

"""
    set_nonjitter!(node::Node)

GRUG: Tag rock as NONJITTER. Idempotent — calling twice leaves the vector
with exactly one tag, not two. NO SILENT FAILURE: if node is nothing, caller
gets a MethodError from Julia's dispatch, not a quiet no-op.
"""
function set_nonjitter!(node::Node)
    if !is_nonjitter(node)
        push!(node.required_relations, NONJITTER_TAG)
    end
    return node
end

"""
    clear_nonjitter!(node::Node)

GRUG: Remove NONJITTER tag from rock. If rock did not carry the tag, this is
a no-op — but NOT a silent failure, because the function contract is
"after this call, the tag is absent", which is true either way. Returns the
node for chaining.
"""
function clear_nonjitter!(node::Node)
    if is_nonjitter(node)
        filter!(r -> r != NONJITTER_TAG, node.required_relations)
    end
    return node
end

"""
    collect_nonjitter_ids()::Set{String}

GRUG v7.21: Walk NODE_MAP under lock and return the Set of ids whose node
carries the NONJITTER tag. This is the bridge between the engine-layer tag
store (each Node's required_relations) and subsystems that only speak in
node ids — notably FullLobeScanner, which operates on a
`Dict{String, Vector{Float64}}` of features and has no access to Node
objects.

Typical usage at an orchestrator call site:

    nj_ids = collect_nonjitter_ids()
    gather_candidates!(scanner, features; nonjitter_ids=nj_ids)
    activate_candidates!(scanner, features; nonjitter_ids=nj_ids)

RETURNS: a fresh Set{String} (never nothing). Empty set if no nodes carry
the tag. Always safe to pass directly to FullLobeScanner.

PERFORMANCE: O(N) over NODE_MAP, where N is the total node count. Call
once per mission (not per candidate) and cache the result for the duration
of the scan — the tag set is stable across a single scan because NONJITTER
is not mutated from inside the scan hot path.

NO SILENT FAILURES: a missing NODE_MAP or corrupted required_relations
would surface as a normal Julia error from the iteration, not a quiet empty
set.
"""
function collect_nonjitter_ids()::Set{String}
    ids = Set{String}()
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            # GRUG: is_nonjitter is cheap (≤4-element membership). Whole walk
            # is O(N * avg_rels) ≈ O(N) with tiny constant.
            if is_nonjitter(node)
                push!(ids, id)
            end
        end
    end
    return ids
end

# ==============================================================================
# v7.22 — STRENGTH-DRIVEN SOLIDIFICATION
# ==============================================================================
# GRUG: Nodes that prove themselves stop wiggling. Simple rule:
#
#   strength >= STRENGTH_SOLIDIFY_THRESHOLD   ->  NONJITTER tag ON
#   strength <  STRENGTH_SOLIDIFY_THRESHOLD   ->  NONJITTER tag OFF
#
# The tag is the ONLY effect. All the heavy lifting for "what does NONJITTER
# do" already happened in v7.21 — every node-scoped jitter site honors the
# tag system-wide. v7.22 just automates the tag, system-wide, for all node
# types based on strength.
#
# Lifecycle:
#   - Node earns strength (bump_strength! via /right, fire-success, etc.)
#     Crosses threshold upward -> auto-solidify (NONJITTER on, logged 💎)
#   - Node loses strength (penalize_strength! via /wrong, etc.)
#     Crosses threshold downward -> auto-desolidify (NONJITTER off, logged 💧)
#   - Node climbs back up later -> re-solidifies. No frozen state — confidence
#     is always computed fresh from pattern scan, same as any other node.
#     NONJITTER only silences jitter; it does not freeze computation inputs.
#
# Why no frozen confidence? Confidence is a scan-time output derived from
# the user input against the node's pattern/triples. Freezing it would make
# the node return the same answer for DIFFERENT queries, which is wrong —
# the node should always reflect the current query. NONJITTER gives us
# repeatable, bit-stable answers for the SAME query without breaking
# responsiveness to different queries.
# ==============================================================================

const STRENGTH_SOLIDIFY_THRESHOLD = 9.0       # GRUG: 90% of STRENGTH_CAP

"""
    is_solidified(node::Node)::Bool

GRUG: Is this rock solid? A node is solidified iff it carries the NONJITTER
tag. v7.22 makes that tag a pure function of strength; callers that want
the strength predicate directly should use
`node.strength >= STRENGTH_SOLIDIFY_THRESHOLD`.

Kept separate from is_nonjitter so that future manual tag uses (e.g. a
calibration node that is tagged regardless of strength) still answer TRUE
to is_solidified — solidified just means "locked from jitter", regardless
of how the lock got there.
"""
function is_solidified(node::Node)::Bool
    return is_nonjitter(node)
end

"""
    check_solidify_threshold!(node::Node)

GRUG: Called after any strength change. Keeps the NONJITTER tag in sync
with the strength threshold:

  - strength >= threshold AND not tagged -> apply tag (solidify)
  - strength <  threshold AND tagged     -> remove tag (desolidify)

Both transitions log a line so we can see nodes crystallize and soften in
real time. No-op if already in the correct state.

NOTE: This function does NOT lock NODE_LOCK itself. Callers already hold
the lock (see bump_strength! and penalize_strength!); calling from outside
a lock is also safe because we only touch the node's required_relations
via the set/clear helpers, which are O(1) and don't race on unrelated
fields.
"""
function check_solidify_threshold!(node::Node)
    if node.strength >= STRENGTH_SOLIDIFY_THRESHOLD
        if !is_nonjitter(node)
            set_nonjitter!(node)
            println("[ENGINE] 💎 Node $(node.id) solidified (strength=$(round(node.strength, digits=2)) ≥ $(STRENGTH_SOLIDIFY_THRESHOLD)) — NONJITTER tag applied.")
        end
    else
        if is_nonjitter(node)
            clear_nonjitter!(node)
            println("[ENGINE] 💧 Node $(node.id) softened (strength=$(round(node.strength, digits=2)) < $(STRENGTH_SOLIDIFY_THRESHOLD)) — NONJITTER tag removed, jitter resumed.")
        end
    end
    return node
end

# ==============================================================================
# STRENGTH & GRAVE MANAGEMENT
# ==============================================================================

"""
bump_strength!(node::Node)

GRUG: On a coinflip, node gains strength when used. Capped at STRENGTH_CAP (apoptosis).
Coinflip means NOT every use rewards strength - only lucky ones!
"""
function bump_strength!(node::Node)
    # GRUG: 50/50 coinflip. Only winners get stronger.
    if rand() < 0.5
        lock(NODE_LOCK) do
            node.strength = min(node.strength + 1.0, STRENGTH_CAP)
        end
        # GRUG v7.22: if the bump just pushed strength across the
        # SOLIDIFY threshold, auto-apply the NONJITTER tag. Node starts
        # answering bit-stable for the same query from now on. If the
        # node was already solid, this is a no-op.
        check_solidify_threshold!(node)
    end
end

"""
penalize_strength!(node::Node)

GRUG: On /wrong feedback, node does a coinflip. If it loses, strength drops.
At 0.0, node is marked grave (negative reinforcement during generative phase).
"""
function penalize_strength!(node::Node)
    # GRUG: Coinflip. Losers get penalized. Winners escape unscathed this round.
    if rand() < 0.5
        # GRUG v7.15.2: Capture whether this penalty tipped the node into
        # grave territory so we can sync GroupRegistry OUTSIDE the NODE_LOCK
        # hold. Re-entering the registry lock from inside NODE_LOCK would
        # work (no circular lock order in this call site today) but we
        # prefer to keep lock hold-times minimal.
        became_grave = false
        lock(NODE_LOCK) do
            node.strength = max(node.strength - 1.0, STRENGTH_FLOOR)
            if node.strength <= STRENGTH_FLOOR && !node.is_grave
                node.is_grave    = true
                node.grave_reason = "STRENGTH_ZERO"
                became_grave = true
                println("[ENGINE] ⚰  Node $(node.id) marked GRAVE (strength -> 0).")
            end
        end

        # GRUG v7.15.2: After releasing NODE_LOCK, push the grave event into
        # the GroupRegistry so partner-bookkeeping catches up. Skip entirely
        # if this penalty didn't flip the grave bit --- no double-counting.
        became_grave && _sync_grave_to_group_registry(node.id, "penalize_strength!")

        # GRUG v7.22: if the penalty just dropped strength below the
        # SOLIDIFY threshold, auto-remove the NONJITTER tag. Node resumes
        # jittering. If strength climbs back above the threshold later
        # (via future bump_strength! calls), the tag is automatically
        # re-applied. No frozen state to carry — confidence is always
        # computed fresh from pattern scan.
        check_solidify_threshold!(node)
    end
end

"""
    _sync_grave_to_group_registry(node_id::String, caller::String)

GRUG v7.15.2: Shared helper for grave → GroupRegistry propagation.

engine.jl is `include`d two ways:
  1. Via `GrugBot420.jl` → `using .GroupRegistry` is in scope → sync works.
  2. Directly by a few standalone tests (test_smoke.jl, etc.) → GroupRegistry
     is NOT in scope → we must skip cleanly, not throw.

The `isdefined(@__MODULE__, :GroupRegistry)` check lets us do both:
  - Package-mode callers get the sync.
  - Standalone-mode callers skip the sync silently (those tests don't
    exercise group semantics at all).

NO SILENT FAILURE INSIDE THE CALL: once we know GroupRegistry is reachable,
we catch GroupRegistry.GroupRegistryError and surface it as a @warn (non-
fatal --- the node IS graved, registry drift is a bookkeeping issue, not a
correctness issue for the engine). Any other exception rethrows untouched.
"""
function _sync_grave_to_group_registry(node_id::String, caller::String)
    # GRUG: guard on module visibility. In the standalone-include path this
    # short-circuits before we touch the missing symbol.
    if !isdefined(@__MODULE__, :GroupRegistry)
        @debug "[ENGINE] GroupRegistry not loaded in this module context; grave sync skipped for $node_id ($caller)."
        return nothing
    end
    try
        touched = GroupRegistry.grave_node_everywhere!(node_id)
        if touched > 0
            println("[ENGINE] 🪦  Synced grave to GroupRegistry ($touched group(s)).")
        end
    catch e
        if e isa GroupRegistry.GroupRegistryError
            @warn "[ENGINE] $caller GroupRegistry sync threw (non-fatal, continuing): $(e.msg)"
        else
            rethrow(e)
        end
    end
    return nothing
end

"""
mark_node_grave!(node::Node, reason::String)

GRUG: Explicitly mark a node as grave with a reason string.
Used for GRAVED-SLOW (big-O ledger) and STRENGTH_ZERO cases.
"""
function mark_node_grave!(node::Node, reason::String)
    if strip(reason) == ""
        error("!!! FATAL: mark_node_grave! requires a non-empty reason string! !!!")
    end
    lock(NODE_LOCK) do
        node.is_grave     = true
        node.grave_reason = reason
    end
    println("[ENGINE] ⚰  Node $(node.id) marked GRAVE: [$reason].")

    # GRUG v7.15.2: Keep the GroupRegistry in sync. If the node belongs to any
    # groups, increment their grave_count so chatter-window callers and the
    # PhagyGroupOrganizer automaton can react (e.g. clear is_unlinkable).
    # grave_node_everywhere! is a no-op when the node was never registered.
    #
    # NO CIRCULAR DEP: engine.jl is `include`d both by GrugBot420.jl (where
    # GroupRegistry is in scope) AND by some standalone tests that
    # `include("../src/engine.jl")` directly without the package wrapper. In
    # the standalone case GroupRegistry is simply not defined, so we guard
    # with `isdefined(@__MODULE__, :GroupRegistry)` --- a true skip here is
    # fine (those tests don't exercise group semantics) and keeps the package
    # tests + standalone tests both green.
    #
    # NO SILENT FAILURE: a typed GroupRegistryError means registry state is
    # corrupt, not a benign skip --- we log it loudly as a warning so the
    # operator sees the drift, but we don't crash the grave flow. Other
    # exception types rethrow unchanged.
    _sync_grave_to_group_registry(node.id, "mark_node_grave!")
end

# ==============================================================================
# BIG-O RESPONSE TIME LEDGER
# ==============================================================================

"""
record_response_time!(node::Node, elapsed_seconds::Float64)

GRUG: Record a response time for this node in its big-O ledger.
If average response time exceeds SLOW_NODE_THRESHOLD_SECONDS, mark GRAVED-SLOW.
Ledger clears every 24 hours (LEDGER_CLEAR_INTERVAL).
"""
function mark_node_contributor!(node::Node)
    """
    Mark a node as having contributed to output this cycle.
    This enables the node for reinforcement/penalty via /right and /wrong.
    """
    node.fired_this_cycle = true
    node.voted_this_cycle = true  # Contributors also voted
end

function reset_cycle_flags!(node::Node)
    """
    Reset cycle tracking flags at the start of a new cycle.
    """
    node.fired_this_cycle = false
    node.voted_this_cycle = false
    node.gained_this_cycle = false
    node.strength_delta_this_cycle = 0.0
end

function reset_all_cycle_flags!()
    """
    Reset cycle flags for all nodes at the start of a new mission.
    """
    lock(NODE_LOCK) do
        for node in values(NODE_MAP)
            reset_cycle_flags!(node)
        end
    end
end

function record_response_time!(node::Node, elapsed_seconds::Float64)
    if elapsed_seconds < 0.0
        error("!!! FATAL: record_response_time! got negative elapsed time: $(elapsed_seconds)! !!!")
    end

    lock(NODE_LOCK) do
        # GRUG: Check if 24-hour window has passed. If so, wipe the ledger clean.
        now_t = time()
        if now_t - node.ledger_last_cleared >= LEDGER_CLEAR_INTERVAL
            empty!(node.response_times)
            node.ledger_last_cleared = now_t
            println("[ENGINE] 🕐  Node $(node.id) big-O ledger cleared (24hr reset).")
        end

        push!(node.response_times, elapsed_seconds)

        # GRUG: Check average response time. If too slow, node gets yeeted!
        if !isempty(node.response_times)
            avg_time = sum(node.response_times) / length(node.response_times)
            if avg_time > SLOW_NODE_THRESHOLD_SECONDS && !node.is_grave
                node.is_grave     = true
                node.grave_reason = "GRAVED-SLOW"
                println("[ENGINE] 🐢  Node $(node.id) marked [GRAVED-SLOW] (avg: $(round(avg_time, digits=2))s > $(SLOW_NODE_THRESHOLD_SECONDS)s).")
            end
        end
    end
end

# ==============================================================================
# NEIGHBOR LINKING (MAX 4 NEIGHBORS = UNLINKABLE)
# ==============================================================================

"""
try_link_nodes!(node_a::Node, node_b::Node)::Bool

GRUG: Attempt to link two nodes as neighbors.
Fails (returns false) if either node already has MAX_NEIGHBORS (is UNLINKABLE).
On success, both nodes gain each other as neighbors.
"""
function try_link_nodes!(node_a::Node, node_b::Node)::Bool
    if node_a.id == node_b.id
        # GRUG: Node cannot be its own neighbor. That's just a mirror, not a friend!
        return false
    end

    lock(NODE_LOCK) do
        # GRUG: Check both nodes can accept new neighbors
        if node_a.is_unlinkable || node_b.is_unlinkable
            return false
        end
        if node_a.id in node_b.neighbor_ids || node_b.id in node_a.neighbor_ids
            # GRUG: Already linked! Don't double-link.
            return false
        end

        push!(node_a.neighbor_ids, node_b.id)
        push!(node_b.neighbor_ids, node_a.id)

        # GRUG: Check if either node just hit the UNLINKABLE threshold
        if length(node_a.neighbor_ids) >= MAX_NEIGHBORS
            node_a.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_a.id) is now UNLINKABLE ($(MAX_NEIGHBORS) neighbors reached).")
        end
        if length(node_b.neighbor_ids) >= MAX_NEIGHBORS
            node_b.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_b.id) is now UNLINKABLE ($(MAX_NEIGHBORS) neighbors reached).")
        end

        return true
    end
end

"""
find_best_latch_target(new_node::Node)::Union{String, Nothing}

GRUG: When a new node grows, it wants to latch onto the strongest similar neighbor.
Scan existing nodes for the best candidate:
  - Must NOT be UNLINKABLE (has room for another neighbor)
  - Must NOT be GRAVE
  - Must be pattern-similar (token overlap > 0)
  - Among eligible, pick the strongest one

Returns node_id of best candidate, or Nothing if no eligible nodes found.
"""
function find_best_latch_target(new_node::Node)::Union{String, Nothing}
    best_id       = nothing
    best_score    = -Inf

    lock(NODE_LOCK) do
        for (id, candidate) in NODE_MAP
            id == new_node.id  && continue  # GRUG: Skip self
            candidate.is_grave              && continue  # GRUG: No latching onto graves
            candidate.is_unlinkable         && continue  # GRUG: No room for new neighbor

            # GRUG: Compute rough token similarity between patterns
            sim = _token_overlap_similarity(new_node.pattern, candidate.pattern)
            if sim <= 0.0
                continue  # GRUG: No similarity, not a good latch target
            end

            # GRUG: Score = strength * similarity. Strongly similar nodes rank highest.
            score = candidate.strength * sim
            if score > best_score
                best_score = score
                best_id    = id
            end
        end
    end

    return best_id
end

"""
_token_overlap_similarity(p1::String, p2::String)::Float64

GRUG: Internal Jaccard-like token overlap similarity [0.0, 1.0].
Used for neighbor latching and chatter gossip decisions.
"""
function _token_overlap_similarity(p1::String, p2::String)::Float64
    if strip(p1) == "" || strip(p2) == ""
        return 0.0
    end
    t1 = Set(split(lowercase(strip(p1))))
    t2 = Set(split(lowercase(strip(p2))))
    union_size = length(union(t1, t2))
    return union_size > 0 ? Float64(length(intersect(t1, t2))) / Float64(union_size) : 0.0
end

# ==============================================================================
# RELATIONAL FIRE SYSTEM (NODE ATTACHMENTS)
# ==============================================================================

# GRUG: /nodeAttach lets user bolt up to 4 nodes onto a target node.
# When the target fires (selected for voting), each attached node does a
# strength-biased coinflip. Winners fire too with a pre-baked confidence.
# This is RELATIONAL FIRE: nodes ride on the coattails of a parent node's
# activation, gated by coinflip and the biological attention bottleneck.
#
# JIT CONFIDENCE BAKING: The connector pattern (middleman) is scanned against
# the ATTACHED NODE's own pattern ONCE at attach time (in attach_node!).
# The resulting base_confidence is stored in the AttachedNode struct. At fire
# time, only stochastic jitter is applied — no re-scanning needed. This is
# the JIT optimization: expensive work happens when the user issues the
# /nodeAttach command, not every relay activation cycle.
#
# The connector pattern is still stored for:
#   1. AIML reference: the middleman reason WHY these nodes are related
#   2. Generative context: surfaces as a RelationalTriple downstream so the
#      pipeline knows WHY these nodes were co-activated
#
# /imgnodeAttach does the same for image nodes: SDF conversion happens at
# attach time (JIT GPU accel), base_confidence is baked from SDF similarity.
#
# GRUG: Attachment ≠ Neighbor linking. Neighbors are symmetric co-activation
# via drop tables. Attachments are ASYMMETRIC: target fires → attached MAY fire.
# Attached nodes don't cause the target to fire. One-way dependency chain.

struct AttachedNode
    node_id::String          # GRUG: ID of the node being attached (must exist in NODE_MAP)
    pattern::String          # GRUG: Connector pattern — middleman reason WHY these nodes are related
    signal::Vector{Float64}  # GRUG: Pre-baked signal from connector pattern (for PatternScanner compat)
    base_confidence::Float64 # GRUG: JIT-baked confidence computed at attach time, NOT at fire time!
                             #       Formula: token_overlap(connector, attached_node.pattern) + (strength/CAP)*0.5
                             #       At fire time, only jitter is applied: max(0.1, base_confidence + jitter)
end

# GRUG: Map from target_node_id -> Vector of AttachedNode (max MAX_ATTACHMENTS each)
const ATTACHMENT_MAP  = Dict{String, Vector{AttachedNode}}()
const ATTACHMENT_LOCK = ReentrantLock()

# GRUG: Handoff slot so scan_and_expand relay pass can reuse the FireCounter
# built by scan_specimens for this cycle. All fire paths share one counter so
# the 1000 cap is enforced GLOBALLY — attachments, drop-table, and cascade all
# count toward the same limit. Protected by NODE_LOCK implicitly (only written
# by scan_specimens under its own flow).
const _LAST_FIRE_COUNTER = Ref{Union{Nothing, VoteOrchestrator.FireCounter}}(nothing)

# GRUG: Hard cap on how many nodes can be bolted onto one target. User said 4.
const MAX_ATTACHMENTS = 4

# GRUG: Small stochastic jitter applied to co-fired node confidence.
# Biologically motivated — synaptic relay is noisy. Same neuron doesn't fire
# with identical strength every time it gets woken by a relay. Keeps the vote
# pool from collapsing to the same winner every cycle when attachments fire.
# Magnitude is small (sigma=0.05) so it nudges but never dominates.
const RELAY_CONF_JITTER_SIGMA = 0.05

# ==============================================================================
# v7.18 — LOBE TOPICALITY GATE + SEMANTIC-BRIDGE EXCEPTION
# ==============================================================================
# GRUG: Lobes with data unrelated to the mission should NOT vote. Their nodes
# are muted before vote collection. A muted node may be REINSTATED (at half
# weight) only if a semantic bridge exists. Bridges are NOT raw keyword
# overlap — they are:
#   1. Relational-triple overlap with the mission's DYNAMIC relational triples
#      (extracted live via extract_dynamic_relational_triples).
#   2. A required_relation verb that is also used by a node in an eligible lobe.
#   3. A /nodeAttach attachment pointing to a node in an eligible lobe.
"""
    _scaffold_coherence_pass(scaffold_text, mission_text) -> String

GRUG v7.20: Post-hoc filter on the assembled scaffold. Strips sub-clauses
that contain tokens from off-topic lobe subjects when the mission has no
topical overlap with those domains. This is the safety net — even after
the topicality gate and triple filter, some off-topic content may slip
through via weak support-band votes.

Strategy: tokenize the mission, identify which lobe-subject tokens appear
in the scaffold, and strip sentences containing tokens from lobes whose
topicality score is below LOBE_TOPICALITY_FLOOR.
"""
function _scaffold_coherence_pass(scaffold_text::String, mission_text::String)::String
    # #############################################################################
    # ###  DO NOT ADD LOBE MUTING. THIS IS NOW A NO-OP PASS-THROUGH.        ###
    # ###  LOBE_TOPICALITY_FLOOR IS 0.0. NO LOBES ARE EVER MUTED.           ###
    # ###  THE CORRECT DESIGN IS LobeOrchestrator.jl: SEQUENTIAL FIRING.     ###
    # #############################################################################
    return scaffold_text

    # DEAD CODE BELOW — kept for reference only, never reached.
    try
        # GRUG: Get the set of muted lobe IDs for this mission.
        eligible, muted, _, _ = _compute_muted_lobes(mission_text)

        if isempty(muted)
            return scaffold_text  # no off-topic lobes → nothing to strip
        end

        # GRUG: Collect subject tokens from muted lobes. These are the
        # "off-topic markers" — if a sentence in the scaffold contains
        # these tokens, it's likely from a muted lobe bleeding through.
        off_topic_markers = Set{String}()
        for lobe_id in muted
            try
                rec = Lobe.get_lobe(lobe_id)
                for tok in split(lowercase(strip(rec.subject)))
                    tok_clean = lowercase(strip(tok))
                    if length(tok_clean) >= 3
                        push!(off_topic_markers, tok_clean)
                    end
                end
                # GRUG: Also collect sample patterns from muted lobes.
                # Node patterns like "what should i eat" or "a predator is
                # hunting me" are strong off-topic signals.
                for nid in rec.node_ids[1:min(3, length(rec.node_ids))]
                    node = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                    if !isnothing(node)
                        for tok in split(lowercase(strip(node.pattern)))
                            tok_clean = lowercase(strip(tok))
                            if length(tok_clean) >= 4
                                push!(off_topic_markers, tok_clean)
                            end
                        end
                    end
                end
            catch
                continue
            end
        end

        if isempty(off_topic_markers)
            return scaffold_text
        end

        # GRUG: Split scaffold into sentences on period boundaries.
        # Re-join sentences that DON'T contain off-topic markers.
        # Preserve the original sentence structure as much as possible.
        sentences = split(scaffold_text, r"\.\s*")
        kept = String[]

        for sent in sentences
            sent_strip = strip(sent)
            if isempty(sent_strip)
                continue
            end

            # GRUG: Check if this sentence contains off-topic markers.
            sent_lower = lowercase(sent_strip)
            has_off_topic = false
            for marker in off_topic_markers
                if occursin(marker, sent_lower)
                    has_off_topic = true
                    break
                end
            end

            # GRUG: Always keep the FIRST sentence (it's the CLAIM / math answer).
            # Only filter subsequent sentences (SUPPORT content).
            if isempty(kept) || !has_off_topic
                push!(kept, sent_strip)
            end
        end

        if isempty(kept)
            return scaffold_text  # safety: don't return empty
        end

        return join(kept, ". ") * "."
    catch
        # GRUG: Never crash the output on a coherence pass failure.
        return scaffold_text
    end
end

# Raw pattern-keyword overlap does NOT unmute a lobe or its nodes.

# #############################################################################
# ###  DO NOT ADD LOBE MUTING. DO NOT CHANGE LOBE SELECTION TO A GATE.     ###
# ###  LOBE_TOPICALITY_FLOOR BELOW IS DISABLED (= 0.0). IT MUST STAY 0.0. ###
# ###  THE CORRECT DESIGN IS IN LobeOrchestrator.jl: SEQUENTIAL FIRING.    ###
# ###  THIS WAS THE ORIGINAL DESIGN. IT WAS REMOVED AND REPLACED WITH      ###
# ###  MUTING. DO NOT DO THAT AGAIN.                                       ###
# #############################################################################

# GRUG: Topicality floor — a lobe's (thesaurus-expanded subject) must share at
# least this fraction of tokens with the mission (also thesaurus-expanded) to
# be eligible. Tuned low enough that domain-adjacent lobes still fire, high
# enough to mute cooking when user asks about physics.
# *** DISABLED v7.24: SET TO 0.0 — NO LOBE IS EVER MUTED. ***
# *** THE CORRECT DESIGN IS SEQUENTIAL LOBE FIRING (LobeOrchestrator.jl) ***
const LOBE_TOPICALITY_FLOOR = 0.0

# GRUG: Bridged-node confidence discount. Muted-lobe nodes that prove a
# semantic bridge vote at half strength — their opinion is heard but it does
# not win primary.
const BRIDGED_NODE_CONF_WEIGHT = 0.5

# GRUG v7.20: Support-vote topicality floor. When rendering SUPPORT content
# in generate_aiml_payload, confirmed support votes from lobes whose topicality
# to the mission is below this floor are suppressed. Higher than LOBE_TOPICALITY_FLOOR
# (0.15) because support content is optional scaffolding — the primary CLAIM
# already carries the answer. Only strongly topical support should appear.
const _SUPPORT_TOPICALITY_FLOOR = 0.30

# GRUG v7.21: LOBE FAMILY CLUSTERS — structural grouping of lobes into
# cognitive families. Lobes in the same family share CONTENT DOMAIN, not just
# graph connectivity. A math answer should NOT cite philosophy content even
# though lobe_math and lobe_phil are connected — they're about different things.
# This is the key insight the topicality gate missed: CONNECTION != RELEVANCE.
const _LOBE_FAMILIES = Dict{String, Set{String}}(
    "logic"    => Set(["lobe_math", "lobe_science", "lobe_tech"]),
    "life"     => Set(["lobe_biology", "lobe_nature", "lobe_food", "lobe_surv"]),
    "mind"     => Set(["lobe_emp", "lobe_social", "lobe_phil", "lobe_crea"]),
    "temporal" => Set(["lobe_temporal"]),
    "general"  => Set(["default"]),
)

# GRUG v7.21: _same_lobe_family() — strict structural check.
# Two lobes are in the same family if they appear in the same _LOBE_FAMILIES
# entry. Returns true if they share a family, false otherwise.
# This replaces the fuzzy topicality gate for support vote filtering because
# thesaurus expansion creates false overlaps between unrelated lobes.
function _same_lobe_family(lobe_a::String, lobe_b::String)::Bool
    if lobe_a == lobe_b
        return true
    end
    for (_, members) in _LOBE_FAMILIES
        if lobe_a in members && lobe_b in members
            return true
        end
    end
    return false
end

# GRUG v7.21: Module-level flag set by the orchestrator (Main.jl) when
# deterministic math answers are detected for this mission cycle. Read by
# _mission_has_deterministic_answer() to choose the rendering path.
const _CURRENT_HAS_DETERMINISTIC_ANSWER = Ref{Bool}(false)

# GRUG v7.21: _mission_has_deterministic_answer() — predicate that detects
# whether this mission cycle produced a deterministic (computable) answer.
# When true, the rendering pipeline skips the entire SUPPORT block — the
# answer stands alone. No relational triples, no support-band votes, no hedge
# votes. This is the fundamental rethink: deterministic answers don't NEED
# scaffolding, and scaffolding from off-topic lobes is WORSE than no scaffolding.
function _mission_has_deterministic_answer(primary_vote)::Bool
    # Check 1: The orchestrator detected deterministic math answers for this mission.
    # This is the PRIMARY signal — it's set when SigilMediator finds math bindings
    # and ArithmeticEngine computes a valid result, BEFORE any stochastic voting.
    # The primary_vote may NOT be a math vote (e.g., a survival-lobe "flee" node
    # can win the election even for a math mission), but the deterministic answer
    # still exists and should be rendered without decoherent support.
    if _CURRENT_HAS_DETERMINISTIC_ANSWER[]
        return true
    end
    # Check 2: bundle_role === :final means ArithmeticEngine computed an answer
    if getfield(primary_vote, :bundle_role) === :final
        return true
    end
    # Check 3: primary vote's node is in lobe_math
    node_id = primary_vote.node_id
    lobe_id = try Lobe.find_lobe_for_node(node_id) catch nothing end
    if lobe_id == "lobe_math"
        return true
    end
    return false
end

# #############################################################################
# ###  DO NOT ADD LOBE MUTING. _support_vote_is_coherent IS NOW ALWAYS TRUE.###
# ###  NO LOBE IS EVER MUTED. SUPPORT VOTES FROM ANY LOBE ARE COHERENT.   ###
# ###  THE CORRECT DESIGN IS LobeOrchestrator.jl: SEQUENTIAL FIRING.       ###
# #############################################################################
# GRUG v7.24: _support_vote_is_coherent() now always returns true.
# Lobe muting is wrong. Support votes from any lobe are coherent because
# the lock-in floor already filters weak votes. Sequential lobe firing
# handles ordering. No lobe should ever be blocked from contributing support.
function _support_vote_is_coherent(support_vote, primary_vote, mission_text::String)::Bool
    return true
    # DEAD CODE BELOW — kept for reference only, never reached.
    # Find the lobe of the support vote's node
    sv_lobe = try Lobe.find_lobe_for_node(support_vote.node_id) catch nothing end
    pv_lobe = try Lobe.find_lobe_for_node(primary_vote.node_id) catch nothing end

    # If either lobe is unknown, fall back to topicality-only gate
    if sv_lobe === nothing || pv_lobe === nothing
        return _lobe_topicality_for_vote(support_vote, mission_text) >= _SUPPORT_TOPICALITY_FLOOR
    end

    # Structural check: must be in the same lobe family
    if !_same_lobe_family(sv_lobe, pv_lobe)
        return false
    end

    # Semantic check: must also pass topicality floor
    return _lobe_topicality_for_vote(support_vote, mission_text) >= _SUPPORT_TOPICALITY_FLOOR
end

# GRUG: Telemetry for the scaffold debug block. Populated every scan_and_expand
# call. Read by Main.jl when it builds the AIML payload.
const _LAST_MUTED_LOBES    = Ref{Vector{String}}(String[])
const _LAST_BRIDGED_NODES  = Ref{Vector{Tuple{String, String, String}}}(Tuple{String,String,String}[])
# Tuple format: (node_id, lobe_id, bridge_reason)

"""
    _compute_lobe_topicality(subject, mission_expanded_tokens) -> Float64

GRUG: Fraction of (thesaurus-expanded) lobe subject tokens that appear in the
(thesaurus-expanded) mission token set. Returns 0.0 if subject is empty.
"""
function _compute_lobe_topicality(subject::String, mission_expanded::Set{String})::Float64
    if isempty(strip(subject))
        return 0.0
    end
    # Expand the subject through the same thesaurus gate used for missions.
    subject_expanded = try
        Thesaurus.thesaurus_gate_filter(subject)
    catch
        Set(lowercase.(filter(!isempty, map(strip, split(subject)))))
    end
    if isempty(subject_expanded) || isempty(mission_expanded)
        return 0.0
    end
    hits = length(intersect(subject_expanded, mission_expanded))
    if hits == 0
        return 0.0
    end
    # GRUG: Use the SMALLER side as denominator so a short mission isn't
    # penalised when it only carries one topical token (e.g. "gravity
    # problem" hits "physics gravity motion force" at 1/4 subject = 0.25,
    # 1/2 mission = 0.5 — we take the higher signal). This matches the
    # intuition that one strong keyword is enough to wake a small lobe,
    # even if the lobe has many other tokens.
    denom = min(length(subject_expanded), length(mission_expanded))
    return Float64(hits) / Float64(denom)
end

"""
    _compute_muted_lobes(mission_text) -> (eligible, muted, eligible_node_ids, eligible_verbs)

#############################################################################
###  DO NOT ADD LOBE MUTING. LOBE_TOPICALITY_FLOOR IS 0.0 (DISABLED).    ###
###  ALL LOBES ARE ALWAYS ELIGIBLE. MUTED SET IS ALWAYS EMPTY.          ###
###  THE CORRECT DESIGN IS IN LobeOrchestrator.jl: SEQUENTIAL FIRING.   ###
#############################################################################

GRUG v7.24: With LOBE_TOPICALITY_FLOOR = 0.0, this function always returns
all lobes as eligible and muted set as empty. Kept for backward compatibility
with _scaffold_coherence_pass. DO NOT re-enable muting.
"""
function _compute_muted_lobes(mission_text::String)::Tuple{Set{String}, Set{String}, Set{String}, Set{String}}
    eligible = Set{String}()
    muted    = Set{String}()
    eligible_node_ids = Set{String}()
    eligible_verbs    = Set{String}()

    if !(isdefined(@__MODULE__, :Lobe))
        return (eligible, muted, eligible_node_ids, eligible_verbs)
    end

    # GRUG: Thesaurus-expand the mission once, up-front.
    mission_expanded = try
        Thesaurus.thesaurus_gate_filter(mission_text)
    catch
        Set(lowercase.(filter(!isempty, map(strip, split(mission_text)))))
    end

    all_lobe_ids = try
        Lobe.get_lobe_ids()
    catch
        String[]
    end

    for lobe_id in all_lobe_ids
        topic = try
            rec = Lobe.get_lobe(lobe_id)
            _compute_lobe_topicality(rec.subject, mission_expanded)
        catch
            0.0
        end
        if topic >= LOBE_TOPICALITY_FLOOR
            push!(eligible, lobe_id)
        else
            push!(muted, lobe_id)
        end
    end

    # GRUG: Collect node ids + required_relation verbs from eligible lobes.
    for lobe_id in eligible
        try
            rec = Lobe.get_lobe(lobe_id)
            for nid in rec.node_ids
                push!(eligible_node_ids, nid)
                node = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                isnothing(node) && continue
                for v in node.required_relations
                    push!(eligible_verbs, lowercase(strip(v)))
                end
            end
        catch
            continue
        end
    end

    return (eligible, muted, eligible_node_ids, eligible_verbs)
end

"""
    _node_has_semantic_bridge(node, dyn_verbs, eligible_verbs, eligible_node_ids) -> (ok::Bool, reason::String)

GRUG: A node in a muted lobe is bridged into voting if ANY of:
  1. Its relational_patterns has a verb that also appears in the mission's
     DYNAMIC relational triples (extract_dynamic_relational_triples output).
  2. Its required_relations verb also appears on a node in an eligible lobe.
  3. It is attached (ATTACHMENT_MAP) to a node in an eligible lobe, OR an
     eligible-lobe node is attached to it. Either direction counts as a bridge.

Returns (true, reason) if bridged, (false, "") otherwise.
"""
function _node_has_semantic_bridge(node,
                                   dyn_verbs::Set{String},
                                   eligible_verbs::Set{String},
                                   eligible_node_ids::Set{String})::Tuple{Bool, String}
    # --- Bridge 1: dynamic-triple verb overlap --------------------------------
    for trip in node.relational_patterns
        vlow = lowercase(strip(trip.relation))
        if vlow in dyn_verbs
            return (true, "dyn_triple:$(vlow)")
        end
    end

    # --- Bridge 2: required_relation shared with eligible-lobe node -----------
    for v in node.required_relations
        vlow = lowercase(strip(v))
        if vlow in eligible_verbs
            return (true, "verb_bridge:$(vlow)")
        end
    end

    # --- Bridge 3: attachment to/from eligible-lobe node ----------------------
    # GRUG: Early-return from inside a `lock do ... end` closure only returns
    # from the closure, not from _node_has_semantic_bridge. Collect the result
    # into a local under the lock, then return AFTER the lock releases.
    attach_result = try
        lock(ATTACHMENT_LOCK) do
            # This node attaches TO an eligible node?
            if haskey(ATTACHMENT_MAP, node.id)
                for att in ATTACHMENT_MAP[node.id]
                    if att.node_id in eligible_node_ids
                        return (true, "attach_out:$(att.node_id)")
                    end
                end
            end
            # An eligible node attaches TO this node?
            for (target_id, atts) in ATTACHMENT_MAP
                if target_id in eligible_node_ids
                    for att in atts
                        if att.node_id == node.id
                            return (true, "attach_in:$(target_id)")
                        end
                    end
                end
            end
            return (false, "")
        end
    catch
        (false, "")
    end
    return attach_result
end

"""
    apply_lobe_topicality_gate!(mission_text, expanded) -> Vector

#############################################################################
###  DO NOT ADD LOBE MUTING. THIS FUNCTION IS NOW A PASS-THROUGH.       ###
###  THE CORRECT DESIGN IS IN LobeOrchestrator.jl: SEQUENTIAL FIRING.   ###
###  LOBES ARE NEVER MUTED. THEY FIRE SEQUENTIALLY. THE HIGHEST        ###
###  CURVED_AVG GOES FIRST. TIED LOBES BOTH FIRE, COINFLIP DECIDES     ###
###  ORDER. DO NOT RE-ENABLE THIS GATE. DO NOT ADD LOBE MUTING.         ###
#############################################################################

GRUG v7.24: This function is now a PASS-THROUGH. It returns expanded unchanged.
Lobe muting is the WRONG design. The correct design is sequential lobe firing
via LobeOrchestrator.jl (curved_avg ranking, floor winner goes first, cross-talk
gated at 1000 cap). This function used to drop muted-lobe nodes and discount
bridged nodes to 0.5× confidence. That was wrong — it silenced lobes that
should have had a chance to compete on confidence alone.

The original (correct) design was removed and replaced with muting.
DO NOT DO THAT AGAIN.
"""
function apply_lobe_topicality_gate!(mission_text::String,
                                     expanded::Vector)::Vector
    # GRUG v7.24: PASS-THROUGH. No muting. No gating. No dropping nodes.
    # LobeOrchestrator.jl handles lobe selection via curved_avg ranking.
    # This function used to partition lobes into eligible/muted, drop
    # muted-lobe nodes, and discount bridged nodes to 0.5× confidence.
    # ALL of that was wrong. Lobes fire sequentially based on confidence.
    # The highest curved_avg goes first. No lobe is ever silenced.
    #
    # #############################################################################
    # ###  DO NOT RE-ENABLE THIS GATE. DO NOT ADD LOBE MUTING.               ###
    # #############################################################################
    _LAST_MUTED_LOBES[]   = String[]  # No lobes are ever muted.
    _LAST_BRIDGED_NODES[] = Tuple{String,String,String}[]  # No bridging needed.
    return expanded

end

"""
attach_node!(target_id::String, attach_id::String, pattern::String)::String

GRUG: Bolt a node onto a target node with a connector pattern (middleman).
When target fires, attached node does a coinflip to decide if it fires too.

JIT CONFIDENCE BAKING: The connector pattern is scanned against the ATTACHED
NODE's own pattern ONCE at attach time to compute base_confidence. This is
stored in the AttachedNode struct so fire_attachments! never re-scans — it
only applies stochastic jitter to the pre-baked value. The pattern is still
stored for AIML reference and generative context downstream.

  base_confidence = token_overlap(connector, attached_node.pattern)
                  + (attached_node.strength / STRENGTH_CAP) * 0.5

Validation (error-first, NO silent failures):
  - target_id must exist in NODE_MAP and not be grave
  - attach_id must exist in NODE_MAP and not be grave
  - target_id ≠ attach_id (no self-attachment, that's a mirror not a relay)
  - target cannot already have MAX_ATTACHMENTS (4) attached nodes
  - attach_id cannot already be attached to this target (no duplicate bolts)
  - pattern must not be empty
  
Returns confirmation string on success.
"""
function attach_node!(target_id::String, attach_id::String, pattern::String)::String
    if strip(target_id) == ""
        error("!!! FATAL: attach_node! got empty target_id! Grug needs a real target! !!!")
    end
    if strip(attach_id) == ""
        error("!!! FATAL: attach_node! got empty attach_id! Grug needs a real node to attach! !!!")
    end
    if strip(pattern) == ""
        error("!!! FATAL: attach_node! got empty pattern for node '$attach_id'! Every attachment needs a pattern! !!!")
    end
    if target_id == attach_id
        error("!!! FATAL: attach_node! target '$target_id' cannot attach to itself! That's a mirror, not a relay! !!!")
    end

    # GRUG: Validate both nodes exist and are alive
    lock(NODE_LOCK) do
        if !haskey(NODE_MAP, target_id)
            error("!!! FATAL: attach_node! target node '$target_id' does not exist on the map! !!!")
        end
        if !haskey(NODE_MAP, attach_id)
            error("!!! FATAL: attach_node! attach node '$attach_id' does not exist on the map! !!!")
        end
        target_node = NODE_MAP[target_id]
        attach_node_ref = NODE_MAP[attach_id]
        if target_node.is_grave
            error("!!! FATAL: attach_node! target node '$target_id' is GRAVE [$(target_node.grave_reason)]! Cannot attach to dead nodes! !!!")
        end
        if attach_node_ref.is_grave
            error("!!! FATAL: attach_node! attach node '$attach_id' is GRAVE [$(attach_node_ref.grave_reason)]! Cannot attach dead nodes! !!!")
        end
    end

    # GRUG: Pre-bake the signal from the user-defined pattern
    attach_signal = words_to_signal(pattern)

    # GRUG: JIT CONFIDENCE BAKING! Compute base_confidence NOW at attach time,
    # not every fire cycle. This is the core JIT optimization:
    #   base_confidence = token_overlap(connector_pattern, attached_node.pattern)
    #                   + (attached_node.strength / STRENGTH_CAP) * 0.5
    # At fire time, only jitter is applied: max(0.1, base_confidence + jitter).
    # The connector pattern is still stored for AIML reference — it's just that
    # the expensive scan happens once here instead of every relay activation.
    jit_base_confidence = lock(NODE_LOCK) do
        attach_node_ref = NODE_MAP[attach_id]
        base_conf = _token_overlap_similarity(pattern, attach_node_ref.pattern)
        strength_bonus = attach_node_ref.strength / STRENGTH_CAP
        return base_conf + (strength_bonus * 0.5)
    end

    lock(ATTACHMENT_LOCK) do
        existing = get(ATTACHMENT_MAP, target_id, AttachedNode[])

        # GRUG: Check max attachments cap
        if length(existing) >= MAX_ATTACHMENTS
            error("!!! FATAL: attach_node! target '$target_id' already has $(length(existing)) attachments (max $MAX_ATTACHMENTS)! Detach one first! !!!")
        end

        # GRUG: Check for duplicate attachment (same node already bolted on)
        for att in existing
            if att.node_id == attach_id
                error("!!! FATAL: attach_node! node '$attach_id' is already attached to target '$target_id'! No duplicate bolts! !!!")
            end
        end

        # GRUG: All checks passed. Bolt it on with JIT-baked confidence!
        new_attachment = AttachedNode(attach_id, pattern, attach_signal, jit_base_confidence)
        push!(existing, new_attachment)
        ATTACHMENT_MAP[target_id] = existing
    end

    n_attached = lock(() -> length(get(ATTACHMENT_MAP, target_id, AttachedNode[])), ATTACHMENT_LOCK)
    println("[ENGINE] 🔗  Node '$attach_id' attached to target '$target_id' with pattern \"$(first(pattern, 40))\" (base_conf=$(round(jit_base_confidence, digits=3)), $n_attached/$MAX_ATTACHMENTS slots used).")
    return "Attached '$attach_id' to '$target_id' with pattern \"$(first(pattern, 40))\" (base_conf=$(round(jit_base_confidence, digits=3)), $n_attached/$MAX_ATTACHMENTS)"
end

"""
detach_node!(target_id::String, attach_id::String)::String

GRUG: Remove a specific attached node from a target. Unbolt one relay.
Returns confirmation string. Errors if target or attachment not found.
"""
function detach_node!(target_id::String, attach_id::String)::String
    if strip(target_id) == ""
        error("!!! FATAL: detach_node! got empty target_id! !!!")
    end
    if strip(attach_id) == ""
        error("!!! FATAL: detach_node! got empty attach_id! !!!")
    end

    lock(ATTACHMENT_LOCK) do
        if !haskey(ATTACHMENT_MAP, target_id)
            error("!!! FATAL: detach_node! target '$target_id' has no attachments! Nothing to detach! !!!")
        end
        existing = ATTACHMENT_MAP[target_id]
        idx = findfirst(a -> a.node_id == attach_id, existing)
        if isnothing(idx)
            error("!!! FATAL: detach_node! node '$attach_id' is not attached to target '$target_id'! !!!")
        end
        deleteat!(existing, idx)
        if isempty(existing)
            delete!(ATTACHMENT_MAP, target_id)
        end
    end

    println("[ENGINE] 🔓  Node '$attach_id' detached from target '$target_id'.")
    return "Detached '$attach_id' from '$target_id'"
end

"""
fire_attachments!(target_id::String, active_count::Int, active_cap::Int)::Vector{Tuple{String, Float64, String}}

GRUG: RELATIONAL FIRE! When a target node fires, check its attachments.
Each attached node does a strength-biased coinflip. Winners fire and return
their (node_id, confidence, connector_pattern) for voting. Losers are skipped.

active_count = how many nodes have already fired this scan cycle
active_cap   = the biological attention bottleneck limit for this cycle

JIT CONFIDENCE BAKING: The expensive token_overlap scan between the connector
pattern and the attached node's own pattern happens ONCE at attach time (in
attach_node!), NOT every fire cycle. The pre-baked base_confidence is stored
in the AttachedNode struct. At fire time, only stochastic jitter is applied:
  confidence = max(0.1, att.base_confidence + randn() * RELAY_CONF_JITTER_SIGMA)
  Minimum confidence floor of 0.1 so attached nodes always have SOME voice.
  Jitter is small (sigma=0.05) — nudges but never dominates.

The connector pattern is stored for AIML reference and returned so it can
surface downstream as generative context — it tells the pipeline WHY these
nodes were co-activated.

Returns: Vector of (node_id, confidence, connector_pattern) triples.
"""
function fire_attachments!(target_id::String, active_count::Int, active_cap::Int)::Vector{Tuple{String, Float64, String}}
    fired = Tuple{String, Float64, String}[]

    attachments = lock(() -> get(ATTACHMENT_MAP, target_id, AttachedNode[]), ATTACHMENT_LOCK)
    if isempty(attachments)
        return fired
    end

    lock(NODE_LOCK) do
        # GRUG: Verify target still exists. Non-fatal if gone (vanished between scan and fire).
        target_node = get(NODE_MAP, target_id, nothing)
        if isnothing(target_node)
            @warn "[ENGINE] ⚠ fire_attachments!: target '$target_id' vanished from NODE_MAP."
            return
        end

        current_active = active_count

        for att in attachments
            # GRUG: ACTIVE CAP GATE! If we're at the biological attention limit, stop firing.
            if current_active >= active_cap
                println("[ENGINE] 🧠  Attachment relay halted for '$target_id' — active cap ($active_cap) reached.")
                break
            end

            # GRUG: Check attached node still exists and is alive
            attach_node_ref = get(NODE_MAP, att.node_id, nothing)
            if isnothing(attach_node_ref)
                # GRUG: Attached node was deleted/graved. Stale attachment. Skip.
                continue
            end
            if attach_node_ref.is_grave
                # GRUG: Dead nodes don't fire. Skip.
                continue
            end

            # GRUG: STRENGTH-BIASED COINFLIP! Same formula as scan coinflip.
            # Strong attached nodes fire more often. Weak ones still have a chance.
            if !strength_biased_scan_coinflip(attach_node_ref)
                # GRUG: Lost the coinflip. This attached node stays dormant this round.
                continue
            end

            # GRUG: JIT CONFIDENCE — pre-baked at attach time, just apply jitter now!
            # The expensive token_overlap scan happened once in attach_node! (JIT baking).
            # At fire time we only add stochastic synaptic jitter (sigma=0.05).
            # Floor of 0.1 so attached nodes always have SOME voice.
            if isempty(att.pattern)
                error("!!! FATAL: fire_attachments! found empty connector pattern for '$(att.node_id)' on target '$target_id'! Every attachment MUST have a pattern! !!!")
            end
            # GRUG: Add small stochastic jitter (sigma=RELAY_CONF_JITTER_SIGMA).
            # Synaptic relay is biologically noisy — same node shouldn't fire with
            # identical confidence every cycle. Nudges vote pool diversity.
            #
            # GRUG v7.21 NONJITTER HONOR: if the attached node carries the
            # NONJITTER tag, suppress the synaptic relay jitter so its voted
            # confidence is exactly att.base_confidence (floored at 0.1). This
            # is the system-wide promise of the tag: wherever a node-scoped
            # jitter happens, a NONJITTER-tagged node skips it.
            jitter = is_nonjitter(attach_node_ref) ? 0.0 : randn() * RELAY_CONF_JITTER_SIGMA
            confidence = max(0.1, att.base_confidence + jitter)

            # GRUG v7.23: SPARSE-ACTIVE FIRE GATE on the attachment relay path.
            # SPARSE_ACTIVE_FIRE_FLOOR is now 0.0 (always passes). The relay's
            # own hard floor of 0.1 ("always have SOME voice") still applies
            # above. The real gate is AIML_TOP_LOCKIN_FLOOR (0.50) in the
            # orchestration phase. This check is kept as a structural hook
            # but never culls attachment relay fires.
            if !VoteOrchestrator.should_fire_sparse_active(confidence)
                VoteOrchestrator.tally_sparse_active_skip!()
                continue
            end

            # GRUG: Return the connector pattern so generative knows WHY this relay fired.
            push!(fired, (att.node_id, confidence, att.pattern))
            current_active += 1

            # GRUG: Bump strength on the attached node (it got used!)
            bump_strength!(attach_node_ref)

            println("[ENGINE] ⚡  Attachment relay: '$(att.node_id)' fired via target '$target_id' (conf=$(round(confidence, digits=3)), connector=\"$(first(att.pattern, 30))\")")
        end
    end

    return fired
end

"""
get_attachment_summary()::String

GRUG: Return human-readable summary of all node attachments for /nodes or /status.
"""
function get_attachment_summary()::String
    lines = String[]
    lock(ATTACHMENT_LOCK) do
        if isempty(ATTACHMENT_MAP)
            push!(lines, "[ATTACHMENT MAP EMPTY]")
            return
        end
        push!(lines, "=== ATTACHMENT MAP ($(length(ATTACHMENT_MAP)) targets with attachments) ===")
        for (target_id, attachments) in sort(collect(ATTACHMENT_MAP), by=x->x[1])
            push!(lines, "  🎯 $target_id ($(length(attachments))/$MAX_ATTACHMENTS attached):")
            for att in attachments
                node_status = lock(() -> begin
                    n = get(NODE_MAP, att.node_id, nothing)
                    isnothing(n) ? "[MISSING]" : (n.is_grave ? "[GRAVE]" : "[ALIVE str=$(round(n.strength, digits=1))]")
                end, NODE_LOCK)
                push!(lines, "      🔗 $(att.node_id) $node_status | base_conf=$(round(att.base_confidence, digits=3)) | connector=\"$(first(att.pattern, 35))\"")
            end
        end
    end
    return join(lines, "\n")
end

"""
get_attachments_for_target(target_id::String)::Vector{AttachedNode}

GRUG: Get the list of attachments for a specific target node.
Returns empty vector if no attachments exist.
"""
function get_attachments_for_target(target_id::String)::Vector{AttachedNode}
    return lock(() -> get(ATTACHMENT_MAP, target_id, AttachedNode[]), ATTACHMENT_LOCK)
end

# ==============================================================================
# IMAGE NODE ATTACHMENT (SDF-BASED RELATIONAL FIRE)
# ==============================================================================

# GRUG: /imgnodeAttach does everything /nodeAttach does but for IMAGE NODES.
# Instead of text connector patterns, uses image binary converted to nonlinear
# SDF at attach time (JIT GPU accel). Confidence is baked from SDF signal
# similarity — the cosine similarity between the connector SDF signal and the
# attached image node's own SDF signal. Same error-first philosophy, same
# validation, same AttachedNode struct (pattern stores "SDF:<format>:<w>x<h>"
# metadata, signal stores the SDF-derived signal vector).

"""
_sdf_signal_similarity(sig_a::Vector{Float64}, sig_b::Vector{Float64})::Float64

GRUG: Cosine similarity between two SDF-derived signal vectors.
This is the image-domain equivalent of _token_overlap_similarity for text.
Returns [0.0, 1.0] — 1.0 means identical SDF activations.
Errors on empty signals (NO silent failures).
"""
function _sdf_signal_similarity(sig_a::Vector{Float64}, sig_b::Vector{Float64})::Float64
    if isempty(sig_a)
        error("!!! FATAL: _sdf_signal_similarity got empty sig_a! Image SDF signals must not be empty! !!!")
    end
    if isempty(sig_b)
        error("!!! FATAL: _sdf_signal_similarity got empty sig_b! Image SDF signals must not be empty! !!!")
    end

    # GRUG: Truncate to the shorter signal length for fair comparison.
    # SDF signals may differ in length if images have different resolutions.
    min_len = min(length(sig_a), length(sig_b))
    a = @view sig_a[1:min_len]
    b = @view sig_b[1:min_len]

    # GRUG: Cosine similarity = dot(a,b) / (||a|| * ||b||)
    dot_product = sum(a .* b)
    norm_a = sqrt(sum(a .^ 2))
    norm_b = sqrt(sum(b .^ 2))

    # GRUG: If either norm is zero (black image / null signal), similarity is 0.0.
    if norm_a < 1e-12 || norm_b < 1e-12
        return 0.0
    end

    # GRUG: Clamp to [0.0, 1.0] — negative cosine means anti-correlated SDF,
    # which we treat as zero similarity for confidence purposes.
    return clamp(dot_product / (norm_a * norm_b), 0.0, 1.0)
end

"""
attach_image_node!(target_id::String, attach_id::String, image_data::Vector{UInt8}, width::Int, height::Int)::String

GRUG: Bolt an IMAGE NODE onto a target node with SDF-based relational fire.
Does everything attach_node! does but for image nodes:
  1. Validates both nodes exist, are alive, and attach_id IS an image node
  2. Converts image binary to nonlinear SDF at attach time (JIT GPU accel)
  3. Computes base_confidence from SDF signal similarity (cosine sim)
  4. Stores the SDF signal + base_confidence in the AttachedNode struct
  5. Pattern field stores metadata: "SDF:<format>:<width>x<height>" for AIML ref

JIT GPU ACCEL: JITGPU(binary) dispatches real KernelAbstractions.jl kernels —
CUDABackend() on NVIDIA, ROCBackend() on AMD, MetalBackend() on Apple Silicon,
CPU() (multithreaded) on CI/no-GPU. The expensive image→SDF conversion + similarity
computation happens ONCE here at attach time. At fire time, only jitter is applied
to the pre-baked base_confidence. Same as text JIT baking but with SDF math.

Validation (error-first, NO silent failures):
  - target_id must exist in NODE_MAP and not be grave
  - attach_id must exist in NODE_MAP, not be grave, AND must be an image node
  - target_id ≠ attach_id (no self-attachment)
  - target cannot already have MAX_ATTACHMENTS (4) attached nodes
  - attach_id cannot already be attached to this target (no duplicate bolts)
  - image_data must not be empty
  - width and height must be > 0

Returns confirmation string on success.
"""
function attach_image_node!(target_id::String, attach_id::String, image_data::Vector{UInt8}, width::Int, height::Int)::String
    if strip(target_id) == ""
        error("!!! FATAL: attach_image_node! got empty target_id! Grug needs a real target! !!!")
    end
    if strip(attach_id) == ""
        error("!!! FATAL: attach_image_node! got empty attach_id! Grug needs a real node to attach! !!!")
    end
    if target_id == attach_id
        error("!!! FATAL: attach_image_node! target '$target_id' cannot attach to itself! That's a mirror, not a relay! !!!")
    end
    if isempty(image_data)
        error("!!! FATAL: attach_image_node! got empty image_data! Cannot create SDF from nothing! !!!")
    end
    if width <= 0 || height <= 0
        error("!!! FATAL: attach_image_node! got invalid dimensions: $(width)x$(height)! Both must be > 0! !!!")
    end

    # GRUG: Validate both nodes exist and are alive, and attach_id is an image node
    lock(NODE_LOCK) do
        if !haskey(NODE_MAP, target_id)
            error("!!! FATAL: attach_image_node! target node '$target_id' does not exist on the map! !!!")
        end
        if !haskey(NODE_MAP, attach_id)
            error("!!! FATAL: attach_image_node! attach node '$attach_id' does not exist on the map! !!!")
        end
        target_node = NODE_MAP[target_id]
        attach_node_ref = NODE_MAP[attach_id]
        if target_node.is_grave
            error("!!! FATAL: attach_image_node! target node '$target_id' is GRAVE [$(target_node.grave_reason)]! Cannot attach to dead nodes! !!!")
        end
        if attach_node_ref.is_grave
            error("!!! FATAL: attach_image_node! attach node '$attach_id' is GRAVE [$(attach_node_ref.grave_reason)]! Cannot attach dead nodes! !!!")
        end
        if !attach_node_ref.is_image_node
            error("!!! FATAL: attach_image_node! node '$attach_id' is NOT an image node! Use /nodeAttach for text nodes! !!!")
        end
    end

    # GRUG: JIT GPU ACCEL — Convert image binary to nonlinear SDF at attach time!
    # JITGPU() dispatches real KernelAbstractions kernels: CUDABackend() on NVIDIA,
    # ROCBackend() on AMD, MetalBackend() on Apple Silicon, CPU() on CI/no-GPU.
    # This is the expensive computation that happens ONCE, not every fire cycle.
    connector_sdf = ImageSDF.JITGPU(image_data; width=width, height=height)
    connector_signal = ImageSDF.sdf_to_signal(connector_sdf)

    # GRUG: JIT CONFIDENCE BAKING — SDF cosine similarity + strength bonus
    # Compare connector SDF signal against attached image node's own signal.
    jit_base_confidence = lock(NODE_LOCK) do
        attach_node_ref = NODE_MAP[attach_id]
        # GRUG: Image node signals are already SDF-derived. Compare directly.
        if isempty(attach_node_ref.signal)
            # GRUG: Image node with empty signal — use flat baseline confidence
            return 0.3
        end
        sdf_sim = _sdf_signal_similarity(connector_signal, attach_node_ref.signal)
        strength_bonus = attach_node_ref.strength / STRENGTH_CAP
        return sdf_sim + (strength_bonus * 0.5)
    end

    # GRUG: Pattern stores SDF metadata string for AIML reference.
    # Not a text pattern — this tells downstream "this is an image attachment".
    sdf_meta_pattern = "SDF:image:$(width)x$(height)"

    lock(ATTACHMENT_LOCK) do
        existing = get(ATTACHMENT_MAP, target_id, AttachedNode[])

        # GRUG: Check max attachments cap
        if length(existing) >= MAX_ATTACHMENTS
            error("!!! FATAL: attach_image_node! target '$target_id' already has $(length(existing)) attachments (max $MAX_ATTACHMENTS)! Detach one first! !!!")
        end

        # GRUG: Check for duplicate attachment (same node already bolted on)
        for att in existing
            if att.node_id == attach_id
                error("!!! FATAL: attach_image_node! node '$attach_id' is already attached to target '$target_id'! No duplicate bolts! !!!")
            end
        end

        # GRUG: All checks passed. Bolt it on with JIT-baked SDF confidence!
        new_attachment = AttachedNode(attach_id, sdf_meta_pattern, connector_signal, jit_base_confidence)
        push!(existing, new_attachment)
        ATTACHMENT_MAP[target_id] = existing
    end

    n_attached = lock(() -> length(get(ATTACHMENT_MAP, target_id, AttachedNode[])), ATTACHMENT_LOCK)
    println("[ENGINE] 🖼️🔗  Image node '$attach_id' attached to target '$target_id' via SDF ($(width)x$(height), base_conf=$(round(jit_base_confidence, digits=3)), $n_attached/$MAX_ATTACHMENTS slots used).")
    return "Attached image '$attach_id' to '$target_id' via SDF ($(width)x$(height), base_conf=$(round(jit_base_confidence, digits=3)), $n_attached/$MAX_ATTACHMENTS)"
end

# ==============================================================================
# THROTTLE RESET
# ==============================================================================

"""
reset_throttle!(node::Node, relational_match_strength::Float64)

GRUG: Reset a node's throttle based on relational match strength.
Maps strength to smooth heat between 0.3 (cold) and 1.0 (hot) via
continuous mapping instead of binary hot/cold. Thread-safe via NODE_LOCK.
"""
function reset_throttle!(node::Node, relational_match_strength::Float64)
    # GRUG FIX 2.4: Continuous Throttle Mapping!
    # Instead of binary hot/cold, Grug map relational strength to smooth heat between 0.3 and 1.0.
    lock(NODE_LOCK) do
        node.throttle = clamp(relational_match_strength / 2.0, 0.3, 1.0)
    end
end

# ==============================================================================
# NODE CREATION
# ==============================================================================

"""
create_node(pattern, action_packet, data, drop_table; is_image_node=false, initial_strength=1.0)::String

GRUG: Grow a new node in the cave. Returns the new node's ID.
If is_image_node=true, pattern is treated as SDF binary data (not text).
New nodes automatically try to latch onto the strongest similar existing node.
"""
function create_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    is_image_node::Bool  = false,
    initial_strength::Float64 = 1.0
)::String
    if strip(pattern) == ""
        error("!!! FATAL: Grug cannot grow node with empty pattern! !!!")
    end
    if strip(action_packet) == ""
        error("!!! FATAL: Grug cannot grow node with empty action packet! !!!")
    end

    # GRUG FIX 2.9: Catch bad action packets before planting rotten seed!
    try
        parse_action_packet(action_packet)
    catch e
        error("!!! FATAL: Grug tried to grow node but action packet is rotten: $(e) !!!")
    end

    req_rels = haskey(data, "required_relations") ? convert(Vector{String}, data["required_relations"]) : String[]
    rel_wts  = haskey(data, "relation_weights")   ? convert(Dict{String, Float64}, data["relation_weights"]) : Dict{String, Float64}()

    rels = extract_relational_triples(pattern)

    # GRUG: Bake word rocks into signal immediately!
    # For image nodes, signal will be set after SDF conversion. Use empty placeholder.
    node_signal = is_image_node ? Float64[] : words_to_signal(pattern)

    # GRUG: Compute Hopfield key from pattern for fast familiar-input lookup
    hopfield_key = is_image_node ? UInt64(0) : hash(join(split(lowercase(strip(pattern))), " "))

    # GRUG: Clamp initial strength to valid range
    clamped_strength = clamp(initial_strength, STRENGTH_FLOOR, STRENGTH_CAP)

    id = "node_$(atomic_add!(ID_COUNTER, 1))"
    new_node = Node(
        id, pattern, node_signal, action_packet, data, drop_table,
        0.5,          # throttle
        rels, req_rels, rel_wts,
        clamped_strength,   # strength
        is_image_node,      # is_image_node
        String[],           # neighbor_ids
        false,              # is_unlinkable
        false,              # is_grave
        "",                 # grave_reason
        Float64[],          # response_times (big-O ledger)
        time(),             # ledger_last_cleared
        hopfield_key,       # hopfield_key
        false,              # fired_this_cycle
        false,              # voted_this_cycle
        false,              # gained_this_cycle
        0.0                 # strength_delta_this_cycle
    )

    lock(NODE_LOCK) do
        NODE_MAP[id] = new_node
    end

    # GRUG: NEW NODE LATCH! Find best similar strong neighbor and link up.
    # Only for text nodes (image nodes use SDF similarity, not token overlap).
    # GRUG: LATCH GATE — only activate latching once map is big enough.
    # Below NODE_LATCH_THRESHOLD, token overlap similarity is not statistically
    # meaningful (too few nodes = junk topology from forced links). Above the
    # threshold the map has enough diversity that similarity scores are real.
    map_size = lock(() -> length(NODE_MAP), NODE_LOCK)
    if !is_image_node && map_size >= NODE_LATCH_THRESHOLD
        latch_target_id = find_best_latch_target(new_node)
        if !isnothing(latch_target_id)
            target_node = lock(() -> get(NODE_MAP, latch_target_id, nothing), NODE_LOCK)
            if !isnothing(target_node)
                linked = try_link_nodes!(new_node, target_node)
                if linked
                    println("[ENGINE] 🌱  Node $id latched onto neighbor $latch_target_id.")
                end
            end
        end
    elseif !is_image_node && map_size < NODE_LATCH_THRESHOLD
        # GRUG: Map too small for meaningful latching. Node plants clean with no forced links.
        # User is responsible for explicit drop_table wiring at this scale.
        # Latch will engage automatically once map reaches NODE_LATCH_THRESHOLD nodes.
        @debug "[ENGINE] Latch suppressed for $id (map_size=$map_size < NODE_LATCH_THRESHOLD=$NODE_LATCH_THRESHOLD). Plant clean."
    end

    return id
end

# ==============================================================================
# SIGIL TAG CONVENTION  -  GRUG v7.16+
# ==============================================================================
# GRUG: Sigil-routed nodes carry a tag in their drop_table vector. The tag
# format is "@sigil:<kind>" where <kind> is one of the SigilMediator routing
# kinds (currently :math, :multipart, :instruction-reserved). drop_table is
# overloaded for this on purpose \u2014 it's already a free-form Vector{String}
# attached to every node, persisted by the save system, and editable from
# specimen JSON. No schema change needed.
#
# WHY OVERLOAD drop_table:
#   - Zero schema change to Node, save format, or specimen JSON
#   - drop_table semantics (cross-firing) are orthogonal to tags; tag strings
#     starting with '@' are filtered out of cross-fire neighbor resolution
#     by collect_drop_table_neighbors (NODE_MAP lookup naturally excludes
#     them because no node id starts with '@')
#   - Specimens can author tags by simply listing them in drop_table
#
# READING TAGS: use node_sigil_kind(node) which returns Symbol or :none.
# WRITING TAGS: use create_sigil_node(pattern, packet, kind=:math, ...) which
# wraps create_node and injects the right tag.

const SIGIL_TAG_PREFIX = "@sigil:"

"""
    node_sigil_kind(node) -> Symbol

Inspect `node.drop_table` for a "@sigil:<kind>" tag and return the kind as
a Symbol (e.g. :math, :multipart). Returns :none if no sigil tag is found.
If multiple sigil tags are present (rare; would be a specimen authoring
mistake), returns the first one in drop_table order.
"""
function node_sigil_kind(node::Node)::Symbol
    for entry in node.drop_table
        if startswith(entry, SIGIL_TAG_PREFIX)
            kind_str = entry[length(SIGIL_TAG_PREFIX)+1:end]
            return isempty(kind_str) ? :none : Symbol(kind_str)
        end
    end
    return :none
end

"""
    has_sigil_tag(node) -> Bool

Convenience predicate: true when the node carries any "@sigil:*" tag.
"""
has_sigil_tag(node::Node)::Bool = node_sigil_kind(node) !== :none

"""
    pattern_is_macro_scaffolding(pattern::AbstractString) -> Bool

GRUG: True iff the pattern is *purely* macro scaffolding -- i.e. every
non-empty token starts with `&`. Patterns like `"&n &op &n"`, `"&conj"`,
`"&n &op &n &op &n"` are scaffolding; the macro engine binds them to a
form, computes a value, and the value flows back through `Vote.payload`.

These tokens are NEVER meant to be spoken to the user. Any code that
renders text (CLAIM/SUPPORT in `generate_aiml_payload`) should skip
nodes whose pattern is pure scaffolding -- AIML's job is to wrap the
*computed value* in language, not to echo the binder's ASCII.

A pattern with a mix (e.g. `"compute &n now"`) is NOT pure scaffolding
and remains spoken-friendly.
"""
function pattern_is_macro_scaffolding(pattern::AbstractString)::Bool
    s = strip(pattern)
    isempty(s) && return false
    toks = split(s)
    isempty(toks) && return false
    return all(startswith(t, "&") for t in toks)
end

"""
    create_sigil_node(pattern, action_packet, data, drop_table; kind, ...) -> String

Convenience wrapper around `create_node` that prepends the
"@sigil:<kind>" tag to drop_table. `kind` must be a Symbol; other kwargs
forward to create_node unchanged. Returns the new node id.
"""
function create_sigil_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    kind::Symbol,
    is_image_node::Bool = false,
    initial_strength::Float64 = 1.0,
)::String
    if kind === :none
        error("!!! FATAL: create_sigil_node requires a non-:none kind !!!")
    end
    tag = SIGIL_TAG_PREFIX * String(kind)
    # GRUG: prepend the tag, dedup if specimen already added it.
    new_drop = tag in drop_table ? drop_table : vcat([tag], drop_table)
    return create_node(pattern, action_packet, data, new_drop;
                       is_image_node = is_image_node,
                       initial_strength = initial_strength)
end

"""
    list_sigil_node_ids(kind=:any) -> Vector{String}

Walk NODE_MAP and return ids of all live (non-grave) nodes carrying a
sigil tag. If `kind` is :any, returns all sigil-tagged nodes; otherwise
returns only nodes whose tag matches `kind`. Used by the engine fire
path for direct routing of structured input.
"""
function list_sigil_node_ids(kind::Symbol = :any)::Vector{String}
    out = String[]
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            node.is_grave && continue
            k = node_sigil_kind(node)
            k === :none && continue
            if kind === :any || k === kind
                push!(out, id)
            end
        end
    end
    sort!(out)  # deterministic order
    return out
end

# ==============================================================================
# STOCHASTIC PACKET PARSER
# ==============================================================================

"""
parse_action_packet(packet::String)

GRUG: Parse an action packet string into structured action items.

## Format (pipe-delimited so action names can contain commas):
    "action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight"

## Rules:
  - Actions separated by `|` (pipe), NOT comma.
  - Inline negatives per action: `action[dont do this, dont do that]^weight`
  - Weight optional; defaults to 1.0 if omitted.
  - Negatives optional; action without brackets has no negatives.
  - Weight must be > 0.0.

## Returns:
  - positives: Vector{Tuple{String, Float64}} — (action_name, weight) pairs (for select_action)
  - all_negatives: Vector{String} — deduped union of all action negatives (for Vote compat)
  - action_items: Vector{Tuple{String, Float64, Vector{String}}} — full per-action data
"""
function parse_action_packet(packet::String)
    if strip(packet) == ""
        error("!!! FATAL: Grug cannot parse empty action packet! !!!")
    end

    # GRUG: Actions are pipe-delimited. Pipes let action names contain commas.
    action_items = Vector{Tuple{String, Float64, Vector{String}}}()

    for part in split(packet, '|')
        p = strip(part)
        isempty(p) && continue

        action_negatives = String[]

        # GRUG: Match inline negatives: "action_name[neg1, neg2]^weight"
        # Regex groups: (1) action name, (2) negatives block, (3) optional weight after ]^
        inline_match = match(r"^(.+?)\[([^\]]*)\](?:\^([\d.]+))?$", p)

        if !isnothing(inline_match)
            action_name = strip(inline_match.captures[1])
            if isempty(action_name)
                error("!!! FATAL: Grug found empty action name before inline negatives block! Packet: '$packet' !!!")
            end

            # GRUG: Parse comma-separated negatives inside [ ]
            neg_block = inline_match.captures[2]
            for neg in split(neg_block, ',')
                neg_clean = strip(neg)
                !isempty(neg_clean) && push!(action_negatives, neg_clean)
            end

            # GRUG: Parse optional weight after ]^
            weight_str = inline_match.captures[3]
            weight = if !isnothing(weight_str)
                w = tryparse(Float64, strip(weight_str))
                if isnothing(w) || w <= 0.0
                    error("!!! FATAL: Bad weight '$(weight_str)' in action packet! Weight must be > 0.0 !!!")
                end
                w
            else
                1.0
            end

            push!(action_items, (String(action_name), weight, action_negatives))

        else
            # GRUG: No inline negatives. Check for weight suffix: "action_name^weight"
            action_name, weight = if contains(p, '^')
                parts = split(p, '^'; limit=2)
                name  = strip(parts[1])
                if isempty(name)
                    error("!!! FATAL: Grug found empty action name before '^' weight! Packet: '$packet' !!!")
                end
                w = tryparse(Float64, strip(parts[2]))
                if isnothing(w) || w <= 0.0
                    error("!!! FATAL: Bad weight '$(parts[2])' in action packet! Weight must be > 0.0 !!!")
                end
                name, w
            else
                p_name = strip(p)
                if isempty(p_name)
                    error("!!! FATAL: Grug found empty action name token in packet! Packet: '$packet' !!!")
                end
                p_name, 1.0
            end

            push!(action_items, (String(action_name), weight, String[]))
        end
    end

    if isempty(action_items)
        error("!!! FATAL: Grug found no valid actions in packet! Packet was: '$packet' !!!")
    end

    # GRUG: Build backward-compatible positives list (name, weight) for select_action
    positives = Tuple{String, Float64}[(item[1], item[2]) for item in action_items]

    # GRUG: Collect deduped union of all negatives across all actions (for Vote compat)
    seen_negatives = Set{String}()
    all_negatives  = String[]
    for item in action_items
        for neg in item[3]
            if !(neg in seen_negatives)
                push!(all_negatives, neg)
                push!(seen_negatives, neg)
            end
        end
    end

    return positives, all_negatives, action_items
end

"""
select_action(packet::String)

GRUG: Select a single action from an action packet via weighted coinflip.
Parses the packet into positives (weighted actions), picks one stochastically
using CoinFlipHeader bias. Returns the selected action name.
"""
function select_action(packet::String)
    positives, negatives, _ = parse_action_packet(packet)
    total_weight = sum(p[2] for p in positives)
    
    pairs_for_coin = Pair[]
    for (name, weight) in positives
        prob = (weight / total_weight) * 100.0
        push!(pairs_for_coin, bias(Symbol(name), prob) => () -> nothing)
    end
    
    winning_sym = @coinflip pairs_for_coin
    return String(winning_sym), negatives
end

# ==============================================================================
# GRUG ROUTING MECHANICS (WITH ACTIVE LIMIT & COMPLEXITY BASED SCANS)
# ==============================================================================

# ==============================================================================
# COMPLEXITY PRE-SCREENER
# ==============================================================================

"""
# GRUG DOC 2.5: Magic Numbers Explained!
# Base word token = 0.15 weight. 
# Relational triple = 1.5 weight (1 triple = ~10 words of complexity!).
# Thresholds: 
#   < 1.5  (e.g. less than 10 words, no triples) -> Cheap Eye.
#   < 4.5  (e.g. 10-30 words, or 1-2 triples) -> Medium Eye.
#   >= 4.5 (e.g. big paragraph or many gears) -> High-Res Eye.
"""
function screen_input_complexity(signal::Vector{Float64}, triples::Vector{RelationalTriple})::Int
    if isempty(signal)
        # GRUG: If signal empty, scanner will crash later. Scream now!
        error("!!! FATAL: Complexity screener found empty signal! No silent failure! !!!")
    end

    sig_len   = length(signal)
    rel_count = length(triples)
    
    complexity_score = (sig_len * 0.15) + (rel_count * 1.5)

    if complexity_score < 1.5
        return 1
    elseif complexity_score < 4.5
        return 2
    else
        return 3
    end
end

"""
_effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int

GRUG: SELECTIVE PATTERN SCAN — downgrade the scan tier based on node pattern
complexity. The base_mode comes from screen_input_complexity (which looks at
INPUT complexity). But a simple 2-token node pattern doesn't justify a high-res
two-pass scan — cheap_scan would give the same answer with less work.

This is per-node downgrade logic: the scan tier can only go DOWN, never UP.
If the input demands cheap_scan (mode=1), the node can't push it to high_res.
But if the input demands high_res (mode=3), a tiny node pattern drops it back.

Pattern complexity thresholds:
  - signal length ≤ 3 tokens  → mode capped at 1 (cheap scan only, BIDIRECTIONAL)
  - signal length ≤ 8 tokens  → mode capped at 2 (medium scan max)
  - signal length > 8 tokens  → no cap (full tier from input complexity)

BIDIRECTIONAL AT TIER 1: When effective_mode == 1, scan_and_expand uses
_bidirectional_cheap_scan() instead of plain cheap_scan(). Forward + reverse
passes are both run and fused via big_number_small_number_coherence — NOT
averaged — so that agreement on strong signal is rewarded while agreement
on weak/noise signal is correctly suppressed. This catches order-reversed
matches that forward-only scanning would miss — "man bites dog" aligns
with "dog bites man" when the reverse pass runs.

Why: Short patterns have so few signal values that the sliding window
variance penalty in high_res_scan is numerically meaningless, and the
stride optimization in cheap_scan already covers the full signal. Wasting
O(n²) work on a 2-element pattern is cave fire.
"""
function _effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int
    if isempty(node_signal)
        # GRUG: Empty signal means this node can't be scanned at all.
        # Return base_mode and let the scanner throw PatternNotFoundError.
        return base_mode
    end

    sig_len = length(node_signal)

    # GRUG: Short patterns → force cheap scan. The pattern is too small
    # for medium/high-res to add any discriminative value.
    if sig_len <= 3
        return min(base_mode, 1)
    end

    # GRUG: Medium patterns → cap at medium scan. High-res two-pass
    # variance penalty is meaningless with fewer than 8 signal values.
    if sig_len <= 8
        return min(base_mode, 2)
    end

    # GRUG: Complex patterns → full tier from input complexity. These
    # patterns have enough signal to benefit from high-res scanning.
    return base_mode
end

# ==============================================================================
# BIDIRECTIONAL CHEAP SCAN
# ==============================================================================

"""
_bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3
)::Tuple{Int, Float64}

GRUG: Bidirectional confidence smoothing for tier-1 (cheap scan) patterns.

The signal encoding of words_to_signal is ORDER-SENSITIVE: "dog bites man" and
"man bites dog" produce different signal vectors. A pure forward cheap_scan misses
cases where token overlap is high but word order is reversed — the sliding window
never aligns the reversed pattern against the target.

BIDIRECTIONAL FIX:
  1. Forward scan:  cheap_scan(target, pattern)         — normal left-to-right
  2. Reverse scan:  cheap_scan(target, reverse(pattern)) — reversed pattern signal

COHERENCE FUSION (v7.19 — replaces averaging):
  Both succeed  → coherence = big_number_small_number_coherence(forward_conf, reverse_conf)
                  Two strong confidences that agree -> near 1.0.
                  Two weak confidences that "agree" -> near 0.0 (correctly distrusted).
                  Strong on one side, weak on the other -> penalized by magnitude_mean.
  One succeeds  → coherence = big_number_small_number_coherence(hit_conf, miss_contribution)
                  miss_contribution is just below threshold so a partial reversal gets
                  a moderate coherence, not a spike and not zero.
  Both fail     → rethrow PatternNotFoundError.
                  No match either way. Consistent with single-direction behavior.

WHY COHERENCE BEATS AVERAGING:
  Averaging hides asymmetry: forward=0.9/reverse=0.1 and forward=0.5/reverse=0.5
  both average to 0.5, but one is real disagreement and the other is real agreement.
  Averaging also suffers catastrophic cancellation on close values. Coherence fuses
  |forward - reverse| normalized by max magnitude, then scales by mean magnitude —
  so agreement on strong signal wins, agreement on noise does not.

Called only for effective_mode == 1 (cheap scan tier, simple patterns ≤ 3 signal
elements). Medium and high-res tiers don't need this — they already scan every
index exhaustively, so order sensitivity is minimal at longer pattern lengths.

ERRORS: propagates PatternNotFoundError if both directions miss. NO SILENT FAILURES.

v7.20 NONJITTER KWARG:
  When `nonjitter=true`, the end-confidence snap-back jitter applied to the fused
  coherence output is skipped. This is the per-node opt-out: the caller in
  scan_and_expand passes `nonjitter=is_nonjitter(node)` so that anchor / calibration /
  canonical-form nodes receive bit-stable confidence scores. Per-window jitter
  inside the underlying cheap_scan calls is unaffected — that is a substrate-level
  behavior of the scanner and remains in effect for both forward and reverse passes.
  The NONJITTER tag silences only the post-fusion bounded micro-variance.
"""
function _bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3,
    nonjitter::Bool = false
)::Tuple{Int, Float64}
    if isempty(target)
        # GRUG: Empty target is a scanner crash waiting to happen. Scream now!
        error("!!! FATAL: _bidirectional_cheap_scan got empty target signal! !!!")
    end
    if isempty(pattern)
        # GRUG: Empty pattern means there's nothing to match. No silent failure!
        error("!!! FATAL: _bidirectional_cheap_scan got empty pattern signal! !!!")
    end

    # GRUG: Threshold floor — just below threshold so a miss contributes a near-zero
    # but honest value to the average, rather than harshly dragging it down to 0.
    # This avoids the asymmetry where one direction missing tanks an otherwise good score.
    miss_contribution = max(0.0, Float64(threshold) - 0.01)

    # GRUG: Forward scan — standard left-to-right window alignment.
    forward_idx  = 0
    forward_conf = miss_contribution
    forward_ok   = false
    try
        forward_idx, forward_conf = cheap_scan(target, pattern; threshold=threshold)
        forward_ok = true
    catch e
        if e isa PatternNotFoundError
            # GRUG: Forward direction missed. Not fatal — reverse may still hit.
            forward_conf = miss_contribution
        elseif e isa PatternScanError
            # GRUG: FATAL scanner logic error. Always rethrow. NO SILENT FAILURE!
            rethrow(e)
        else
            error("!!! FATAL: _bidirectional_cheap_scan forward pass got unknown error: $e !!!")
        end
    end

    # GRUG: Reverse scan — reverse the pattern signal so "man bites dog" encoded
    # in reverse becomes equivalent to "dog bites man" forward.
    reverse_conf = miss_contribution
    reverse_ok   = false
    rev_pattern  = reverse(pattern)  # GRUG: New vector, original untouched
    try
        _, reverse_conf = cheap_scan(target, rev_pattern; threshold=threshold)
        reverse_ok = true
    catch e
        if e isa PatternNotFoundError
            # GRUG: Reverse direction also missed. Will check both-fail case below.
            reverse_conf = miss_contribution
        elseif e isa PatternScanError
            rethrow(e)
        else
            error("!!! FATAL: _bidirectional_cheap_scan reverse pass got unknown error: $e !!!")
        end
    end

    # GRUG: Both directions missed — pattern truly not found. Propagate forward error
    # so scan_and_expand gets a PatternNotFoundError and skips this node.
    if !forward_ok && !reverse_ok
        throw(PatternNotFoundError(
            "Bidirectional cheap scan: pattern not found in either direction.",
            miss_contribution
        ))
    end

    # GRUG v7.19: Fuse forward and reverse confidences via big-number/small-number
    # coherence instead of plain averaging. This rewards agreement on strong signal,
    # suppresses agreement on noise, and is immune to catastrophic cancellation
    # between close floats. See PatternScanner.big_number_small_number_coherence
    # for the full formula. If only one direction hit, miss_contribution stands in
    # for the missing side so a partial reversal gets a moderate score instead of
    # a spike (pure average) or a zero (hard drop).
    smoothed_conf = big_number_small_number_coherence(forward_conf, reverse_conf)

    # GRUG v7.20: END-CONFIDENCE SNAP-BACK JITTER.
    # The per-window slight_jitter inside cheap_scan fuzzes each window's score
    # BEFORE fusion. That's substrate-level hardware-variance modelling. Here we
    # add a second, bounded micro-jitter on the fused coherence — the snap-back
    # breath at the decision boundary. This prevents rigid lock-in on identical
    # re-scans and keeps the system biologically plausible.
    #
    # NONJITTER opt-out: if the caller passed nonjitter=true (wired from
    # is_nonjitter(node) at scan_and_expand), we skip this jitter entirely so
    # the output is bit-stable for that node. Global _JITTER_ENABLED in
    # RelationalJitter is not consulted here — that switch governs relational
    # weight jitter, not confidence fusion.
    final_conf = nonjitter ? smoothed_conf : slight_jitter(smoothed_conf)

    # GRUG: Return best alignment index (forward preferred; reverse is orientation-flipped
    # so its index doesn't map back to the original signal cleanly).
    best_idx = forward_ok ? forward_idx : 1
    return (best_idx, final_conf)
end

# ==============================================================================
# DROP TABLE NEIGHBOR ACTIVATION
# ==============================================================================

"""
collect_drop_table_neighbors(node::Node)::Vector{String}

GRUG: When a node is selected for voting, also collect its drop_table neighbors
for co-activation. Drop table entries are node IDs that fire together with this node.
Returns list of valid (non-grave, existing) neighbor node IDs to co-activate.
"""
function collect_drop_table_neighbors(node::Node)::Vector{String}
    result = String[]

    # GRUG: Try lobe hash table first (O(1) prefix lookup) if LobeTable is loaded
    # and this node has been registered in a lobe's drop chunk.
    # Fall back to node.drop_table vector for nodes not yet in lobe storage.
    # This handles both old-style (vector) and new-style (hash table) drop entries.
    lobe_drop_ids = String[]
    if isdefined(@__MODULE__, :LobeTable)
        # GRUG: Ask reverse index which lobe owns this node, then fetch drop chunk.
        if isdefined(@__MODULE__, :Lobe)
            owning_lobe = Lobe.find_lobe_for_node(node.id)
            if !isnothing(owning_lobe) && LobeTable.table_exists(owning_lobe)
                lobe_drop_ids = try
                    LobeTable.get_drop_neighbors(owning_lobe, node.id)
                catch e
                    # GRUG: Non-fatal. Fall back to vector if chunk lookup fails.
                    @warn "[Engine] collect_drop_table_neighbors: lobe table lookup failed for node '$(node.id)': $e"
                    String[]
                end
            end
        end
    end

    # GRUG: Merge lobe table results with node.drop_table vector (dedup via Set).
    # Once all nodes migrate to lobe storage, node.drop_table will be empty and
    # this merge will just use lobe_drop_ids. Both sources are valid during transition.
    all_drop_ids = union(Set(lobe_drop_ids), Set(node.drop_table))

    lock(NODE_LOCK) do
        for drop_id in all_drop_ids
            # GRUG v7.16+: drop_table is overloaded to also carry "@sigil:*"
            # routing tags. Skip those here \u2014 they are NOT node ids and
            # node_sigil_kind() handles the read side. Faster than letting
            # them fall through to the NODE_MAP miss path, and clearer intent.
            startswith(drop_id, "@") && continue
            if haskey(NODE_MAP, drop_id)
                neighbor = NODE_MAP[drop_id]
                # GRUG: Only activate non-grave drop table neighbors
                if !neighbor.is_grave
                    push!(result, drop_id)
                end
            end
            # GRUG: If drop entry doesn't exist in NODE_MAP, skip silently.
            # Nodes can be graved or deleted; drop tables may go stale.
        end
    end
    return result
end

# ==============================================================================
# STRENGTH-BIASED SCAN COINFLIP
# ==============================================================================

"""
strength_biased_scan_coinflip(node::Node)::Bool

GRUG v7.23: REMOVED stochastic coinflip. Every non-grave node gets scanned.
Confidence is the ONLY gate — if a node's pattern matches strongly enough,
it fires. If it doesn't, it doesn't. No lottery. Strength still affects
post-scan weight (bump_strength! on fire) but does NOT gate whether a node
even gets to TRY matching. The lock-in floor (AIML_TOP_LOCKIN_FLOOR) is
the authoritative confidence threshold for orchestration.

Old behavior: 20-90% scan chance based on strength. This caused stochastic
test failures where knowledge nodes sometimes got scanned and sometimes
didn't, even when their pattern was a perfect match for the input.
"""
function strength_biased_scan_coinflip(node::Node)::Bool
    return true  # v7.23: EVERY node scans. Confidence decides.
end

# ==============================================================================
# MAIN SCAN FUNCTION
# ==============================================================================

"""
scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Vector{RelationalTriple}, Vector{RelationalTriple}}}

GRUG: Main scan entry point. Converts input text to signal, extracts relational
triples, runs ActionTonePredictor, checks Hopfield fast-path, then scans all
nodes for matches. Returns vector of (id, confidence, user_triples,
node_triples) tuples. Throws on empty input — NO SILENT FAILURES.
"""
function scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Vector{RelationalTriple}, Vector{RelationalTriple}}}
    if strip(input_text) == ""
        error("!!! FATAL: Grug cannot scan empty air! Input text is blank! !!!")
    end

    all_valid_specimens = Tuple{String, Float64, Vector{RelationalTriple}, Vector{RelationalTriple}}[]
    
    # GRUG: Convert input to number rocks!
    target_signal = words_to_signal(input_text)
    
    # GRUG: DETERMINISTIC SCAN SELECTION
    # Grug look at how complex input is to choose scanner eye.
    scan_mode = screen_input_complexity(target_signal, RelationalTriple[])

    # GRUG: RELATIONAL EXTRACTION COUPLING (per architecture spec)
    # --------------------------------------------------------------------------
    # Rule: "complex pattern scan → dynamic relational extraction, keep basic
    #        relational triples for simple things, dynamic is needed for complex"
    #
    # Therefore:
    #   mode 1 (cheap_scan)   → basic extract_relational_triples
    #   mode 2 (medium_scan)  → basic extract_relational_triples
    #   mode 3 (high_res_scan)→ dynamic extract_dynamic_relational_triples
    #                            NO SILENT FALLBACK. If dynamic fails on a
    #                            complex input, we scream loud. Falling back to
    #                            basic on mode-3 input would defeat the purpose
    #                            of the complexity coupling — the input earned
    #                            high-res scanning, so it earns dynamic triples.
    #
    # Error handling:
    #   - mode 3 dynamic failure → rethrow (fatal for this scan cycle, caller
    #                                       receives real error, NO SILENT FAIL)
    #   - mode 1/2 basic failure → return empty triples + loud @warn
    #     (basic extraction on simple input is less critical; an empty triple
    #      set just means pattern-scan alone drives the decision.)
    # --------------------------------------------------------------------------
    user_triples = if scan_mode >= 3
        # GRUG: High-res mode → DYNAMIC triples REQUIRED. No fallback.
        try
            result = extract_dynamic_relational_triples(input_text, scan_mode)
            println("[ENGINE] 🌊 High-res dynamic relational extraction: $(length(result)) triples from complex input")
            result
        catch e
            # GRUG: Complex input failed dynamic extraction. This is serious.
            # Do NOT quietly degrade to basic — the caller asked for complex
            # analysis and we must either deliver or fail loudly.
            @error "[ENGINE] ⚠ Dynamic relational extraction FAILED on complex input (mode=$scan_mode). NO SILENT FAIL — rethrowing: $e"
            rethrow(e)
        end
    else
        # GRUG: Simple mode (1 or 2) → basic extraction. Non-fatal on failure
        # because basic triples are complementary to pattern scan, not required.
        try
            extract_relational_triples(input_text)
        catch e
            @warn "[ENGINE] Basic relational extraction failed on simple input (mode=$scan_mode), returning empty triples: $e"
            RelationalTriple[]
        end
    end

    # GRUG: ACTION+TONE PRE-PREDICTION
    # Run BEFORE Hopfield check and BEFORE scan so we can pre-weight confidences.
    # This reads causal chain completeness + surface tone markers.
    # Returns a PredictionResult that carries arousal_nudge and action_weight multiplier.
    # If prediction fails for any reason, Grug logs warning and continues without it.
    # Non-fatal: a nil prediction simply means all confidence weights stay at 1.0.
    prediction = try
        ActionTonePredictor.predict_action_tone(input_text, SemanticVerbs.get_all_verbs())
    catch e
        @warn "[ENGINE] ActionTonePredictor failed (non-fatal): $e"
        nothing
    end

    if !isnothing(prediction)
        @info "[ENGINE] 🔮 $(ActionTonePredictor.format_prediction_summary(prediction))"
        # GRUG: If predictor found a dangling verb (incomplete causal chain), warn user.
        # Informational only -- scan still proceeds, but output may be less coherent.
        if prediction.incomplete_chain
            @warn "[ENGINE] Incomplete causal chain detected (dangling verb: '$(prediction.dangling_verb)'). Input may be truncated."
        end
    end

    # GRUG: HOPFIELD FAST-PATH CHECK - DISABLED
    # ==============================================================================
    # The Hopfield cache has been DISABLED. Pattern bind phase is blazing fast even
    # without caching, and the Hopfield system introduces unnecessary complexity.
    # Hopfield caching should only be used for RIDICULOUSLY LARGE lobe sizes
    # (50,000+ nodes per lobe) where memory access becomes a bottleneck.
    # Current lobe architecture with 1000 node cap per cycle makes this obsolete.
    # ============================================================================
    #
    # OLD CODE (DISABLED):
    # input_hash    = hopfield_input_hash(input_text)
    # cached_ids    = hopfield_lookup(input_hash)
    #
    # if !isnothing(cached_ids)
    #     println("[ENGINE] ⚡  Hopfield cache hit for input hash $(input_hash). Firing $(length(cached_ids)) precached nodes.")
    #     lock(NODE_LOCK) do
    #         for id in cached_ids
    #             if haskey(NODE_MAP, id)
    #                 node = NODE_MAP[id]
    #                 # GRUG: Even cached nodes must not be grave!
    #                 if node.is_grave
    #                     continue
    #                 end
    #                 # GRUG: Cached nodes still go through strength biased coinflip
    #                 if !strength_biased_scan_coinflip(node)
    #                     continue
    #                 end
    #                 # GRUG: Use stored confidence from cache (represented as HOPFIELD_STORE_THRESHOLD)
    #                 push!(all_valid_specimens, (id, HOPFIELD_STORE_THRESHOLD, false, user_triples, node.relational_patterns))
    #             end
    #         end
    #     end
    #     return all_valid_specimens
    # end

    # GRUG: SCAN NODES - Already have scan_mode from earlier (deterministic selection)
    # scan_mode was computed before relational extraction to decide extraction strategy

    # GRUG: PARALLEL FIRE PIPELINE (new architecture)
    # --------------------------------------------------------------------------
    # Old code was a serial for-loop. New code:
    #   1. Snapshot node map under NODE_LOCK -> release lock.
    #   2. Build FireCounter (hard cap = 1000, shared across ALL fire types).
    #   3. Dispatch batched fire Tasks via VoteOrchestrator.parallel_fire_batches.
    #      Each Task has a unique non-colliding name so there is NO collision.
    #   4. Results are aggregated flat. Attachment relay later uses SAME counter.
    # --------------------------------------------------------------------------
    # GRUG: Snapshot key list under lock, then release so per-node work can run
    # without blocking other threads. Each node is read-only inside the fire
    # closure (only bump_strength! mutates, and it takes its own sub-lock).
    active_keys = lock(NODE_LOCK) do
        if isempty(NODE_MAP)
            error("!!! FATAL: Grug find cave empty! No specimens to scan! !!!")
        end

        # GRUG DOC 2.6: Biological Attention Bottleneck!
        # Grug cannot look at 1,000,000 rocks at once. Cave will catch fire!
        # active_cap  = 1000  # GRUG: HARD CAP - 1000 nodes max per cycle (now in VoteOrchestrator)
        all_keys    = collect(keys(NODE_MAP))
        shuffle!(all_keys)
        # GRUG: Pre-trim to cap so we don't even build Tasks for over-cap ids.
        all_keys[1:min(length(all_keys), VoteOrchestrator.ACTIVE_FIRE_CAP)]
    end

    # GRUG: Build FireCounter for this cycle. Cap = 1000. All firing shares this.
    # cycle_id carries the input hash for diagnostic traceability.
    cycle_id = "scan#$(hash(input_text))"
    fire_counter = VoteOrchestrator.FireCounter(cycle_id, VoteOrchestrator.ACTIVE_FIRE_CAP)

    # GRUG: The fire_one closure. One node = one fire attempt. Called from
    # many Tasks in parallel. Returns a tuple if node voted, nothing if skipped.
    # Returns shape: (id, confidence, user_triples, node_triples)
    fire_one = function(id::String, fc::VoteOrchestrator.FireCounter)
        # GRUG: Read node under lock, then release for scan work.
        # Scan work (pattern matching, relational eval) is read-only on the node.
        node = lock(NODE_LOCK) do
            get(NODE_MAP, id, nothing)
        end
        if isnothing(node)
            return nothing
        end

        # GRUG: Skip grave nodes. They are negative reinforcement markers, not voters!
        if node.is_grave
            return nothing
        end

        # GRUG NEW: STRENGTH-BIASED COINFLIP before even scanning pattern!
        # Strong nodes are biased to activate. Weak nodes may be skipped.
        if !strength_biased_scan_coinflip(node)
            return nothing
        end

        # GRUG: Image nodes use SDF signal, not text signal. Skip size check for them.
        if !node.is_image_node
            # Grug check: Is user signal too small to hold node pattern? Skip safely.
            if length(target_signal) < length(node.signal)
                return nothing
            end
        end

        token_conf = 0.0
        try
            if node.is_image_node
                # GRUG: Image nodes cannot be scanned with text signals.
                # They only respond to image inputs that have been SDF-converted.
                # Skip image nodes during text scans (they'll fire in image scan path).
                return nothing
            end

            # GRUG: SELECTIVE PATTERN SCAN — downgrade scan tier for simple patterns.
            effective_mode = _effective_scan_mode(scan_mode, node.signal)

            if effective_mode == 1
                # GRUG: BIDIRECTIONAL CHEAP SCAN — simple patterns (≤3 signal elements)
                # v7.20: pass per-node NONJITTER opt-out so anchor / calibration /
                # canonical-form nodes return bit-stable confidence. Tag lives in
                # node.required_relations (see is_nonjitter / set_nonjitter! above).
                _, token_conf = _bidirectional_cheap_scan(
                    target_signal, node.signal;
                    threshold=0.3,
                    nonjitter=is_nonjitter(node)
                )
            elseif effective_mode == 2
                _, token_conf = medium_scan(target_signal, node.signal; threshold=0.4)
            else
                _, token_conf = high_res_scan(target_signal, node.signal; threshold=0.5)
            end
        catch e
            if e isa PatternNotFoundError
                # Normal logic: Scanner says no match in any direction. Skip!
                return nothing
            elseif e isa PatternScanError
                # FATAL LOGIC ERROR. NO SILENT FAILURE! Scream loud!
                rethrow(e)
            else
                error("!!! FATAL: Unknown error during complexity-based pattern scan: $e !!!")
            end
        end

        # 2. Relational Matcher (Dialectical)
        rel_conf = evaluate_relational_dialectics(
            user_triples, node.relational_patterns, node.required_relations, node.relation_weights
        )

        # 3. Missing Requirement Penalty
        # GRUG v7.27: Anti-match flag removed. Reversed triples just subtract
        # from match_score now — they don't hard-kill the node. Only the
        # -9999.0 sentinel (missing hard requirement) still drops the node.
        if rel_conf == -9999.0
            return nothing
        end

        confidence = token_conf + rel_conf

        # GRUG: ACTION+TONE CONFIDENCE PRE-WEIGHTING
        if !isnothing(prediction) && confidence > 0.0
            node_action_peek = try
                positives, _, _ = parse_action_packet(node.action_packet)
                isempty(positives) ? "" : String(positives[1][1])
            catch ex
                @warn "[ENGINE] ⚠ Failed to peek action_packet for node $(node.id): $ex"
                ""
            end
            weight = ActionTonePredictor.get_action_weight_multiplier(prediction, node_action_peek)
            confidence = confidence * weight
        end

        if token_conf > 0 || rel_conf > 0
            # GRUG v7.23: SPARSE-ACTIVE FIRE GATE (post action-tone weighting).
            # Per user directive: "only votes that get locked in should even
            # happen. like anything below lock in confidence just fuck it off
            # dont even fire." Stochastic strength-biased coinflips REMOVED.
            # Confidence is the ONLY gate now. SPARSE_ACTIVE_FIRE_FLOOR is
            # now 0.0 (always passes) because the REAL gate is the lock-in
            # floor (AIML_TOP_LOCKIN_FLOOR = 0.50) in the orchestration
            # phase. This check is kept as a structural hook but never culls.
            if !VoteOrchestrator.should_fire_sparse_active(confidence)
                VoteOrchestrator.tally_sparse_active_skip!()
                return nothing
            end
            # GRUG: Node wants to fire. Claim a slot from the shared FireCounter.
            # If cap reached, skip \u2014 hard cap applies to ALL fire paths.
            if !VoteOrchestrator.try_claim_fire_slot!(fc)
                return nothing
            end
            return (id, confidence, user_triples, node.relational_patterns)
        end
        return nothing
    end

    # GRUG: Launch parallel fire. Each batch is its own Task with unique name.
    # Errors from any Task surface here via fetch_with_timeout inside
    # parallel_fire_batches. TaskTimeoutError distinguishable from other errors
    # so caller can choose retry vs abort. NO SILENT FAILURES.
    fire_results = try
        VoteOrchestrator.parallel_fire_batches(
            active_keys, fire_counter, fire_one;
            batch_size       = VoteOrchestrator.FIRE_BATCH_SIZE,
            task_prefix      = "scan_fire",
            batch_timeout_s  = VoteOrchestrator.FIRE_BATCH_TIMEOUT_S
        )
    catch e
        # GRUG: Parallel fire exploded or timed out. Scream, don't hide.
        if e isa VoteOrchestrator.TaskTimeoutError
            @error "[ENGINE] parallel_fire_batches TIMEOUT during scan_specimens: $e"
        else
            @error "[ENGINE] parallel_fire_batches failed during scan_specimens: $e"
        end
        rethrow(e)
    end

    # GRUG: Re-type the flat Any[] into our specimen tuple vector.
    for r in fire_results
        push!(all_valid_specimens, r)
    end

    # GRUG: Attach FireCounter to a task-local so scan_and_expand relay pass
    # can count attachment fires toward the same 1000 cap. We pass it via a
    # thread-local-ish handoff: store last cycle's counter in a const Ref.
    _LAST_FIRE_COUNTER[] = fire_counter

    if isempty(all_valid_specimens)
        # GRUG QoL FIX: If no valid rocks found, this is not a logic failure!
        # The Antikythera gears simply did not lock for this signal. Return empty basket!
        return all_valid_specimens
    end

    return all_valid_specimens
end

# ==============================================================================
# SCAN SPECIMENS WITH DROP TABLE CO-ACTIVATION
# ==============================================================================

"""
scan_and_expand(input_text)

GRUG: Run scan_specimens then expand results in two passes:

Pass 1 — Drop-table expansion (same lobe co-activation):
  Nodes paired in drop tables activate together.
  Drop-table neighbors inherit 80% of activating node confidence.

Pass 2 — Lobe cascade expansion (cross-lobe bridge activation):
  When a primary node lives in a lobe, cascade into ALL other lobes
  that share at least one node pattern token with the input.
  Cascade threshold: 0.15 (soft gate).
  Cascade confidence: 60% of the highest primary confidence (cross-lobe discount).
  This prevents isolated lobe silos when a query spans multiple domains.
"""
function scan_and_expand(input_text::String)::Vector{Tuple{String, Float64, Vector{RelationalTriple}, Vector{RelationalTriple}}}
    primary_results = scan_specimens(input_text)

    if isempty(primary_results)
        return primary_results
    end

    # GRUG: Track which IDs are already in the result set to avoid duplicates
    already_included = Set(r[1] for r in primary_results)
    expanded = copy(primary_results)

    user_triples = extract_relational_triples(input_text)
    max_primary_conf = maximum(r[2] for r in primary_results)

    # ── PASS 1: Drop-table expansion (same lobe, 80% confidence discount) ──────
    for (id, conf, u_trips, n_trips) in primary_results
        activating_node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        isnothing(activating_node) && continue

        drop_neighbors = collect_drop_table_neighbors(activating_node)
        for drop_id in drop_neighbors
            if !(drop_id in already_included)
                drop_node = lock(() -> get(NODE_MAP, drop_id, nothing), NODE_LOCK)
                isnothing(drop_node) && continue

                # GRUG: Drop-table neighbor gets discounted confidence (80% of activator)
                drop_conf = conf * 0.8
                push!(expanded, (drop_id, drop_conf, user_triples, drop_node.relational_patterns))
                push!(already_included, drop_id)
            end
        end
    end

    # ── PASS 2: Lobe cascade expansion (cross-lobe bridge, 60% of max primary) ─
    # GRUG: Only run cascade if LobeTable and Lobe modules are loaded.
    if isdefined(@__MODULE__, :LobeTable) && isdefined(@__MODULE__, :Lobe)
        cascade_conf = max_primary_conf * 0.6

        # GRUG: Cascade threshold - only cascade if primary conf was meaningful
        if cascade_conf >= 0.15
            # GRUG: Collect lobes that own the primary firing nodes
            primary_lobe_names = Set{String}()
            for (id, conf, _, _) in primary_results
                lobe_name = Lobe.find_lobe_for_node(id)
                !isnothing(lobe_name) && push!(primary_lobe_names, lobe_name)
            end

            # GRUG: For each OTHER lobe not in primary set, cascade into it
            if !isempty(primary_lobe_names)
                all_lobe_names = try
                    Lobe.get_lobe_ids()
                catch ex
                    # GRUG: Lobe registry blew up — log it, don't kill the scan!
                    @warn "[ENGINE] ⚠ Failed to get lobe IDs for cascade: $ex"
                    String[]
                end

                for lobe_name in all_lobe_names
                    lobe_name in primary_lobe_names && continue  # GRUG: Already fired, skip!

                    # GRUG: Get active node IDs from this lobe via LobeTable
                    lobe_node_ids = try
                        LobeTable.table_exists(lobe_name) ?
                            LobeTable.get_active_node_ids(lobe_name) : String[]
                    catch ex
                        # GRUG: One lobe table exploded — warn and skip, don't nuke cascade!
                        @warn "[ENGINE] ⚠ Failed to get node IDs from lobe '$lobe_name': $ex"
                        String[]
                    end

                    for node_id in lobe_node_ids
                        node_id in already_included && continue

                        cascade_node = lock(() -> get(NODE_MAP, node_id, nothing), NODE_LOCK)
                        isnothing(cascade_node) && continue
                        cascade_node.is_grave && continue  # GRUG: Dead nodes don't cascade!

                        push!(expanded, (node_id, cascade_conf, user_triples, cascade_node.relational_patterns))
                        push!(already_included, node_id)
                    end
                end
            end
        end
    end

    # ── PASS 3: Attachment relay (relational fire system, coinflip-gated) ──────
    # GRUG: For every node that made it into the expanded set, check if it has
    # attachments. If so, fire_attachments! runs a strength-biased coinflip on
    # each attached node. Winners get added to the expanded set with their own
    # connector-pattern-derived confidence. The connector pattern (middleman) is
    # scanned against the ATTACHED NODE's own pattern — not the target's — so
    # confidence reflects how relevant the relay reason is to the waking node.
    #
    # The connector pattern also surfaces as a RelationalTriple in the node's
    # context so the generative pipeline knows WHY this node was co-activated.
    # Triple format: (target_id, "relay_attached", connector_pattern)
    # GRUG: Relay pass uses the SAME FireCounter that scan_specimens built for
    # this cycle. That means attachment fires COUNT against the global 1000 cap
    # along with pattern-scan fires, drop-table fires, and cascade fires.
    # If scan already consumed all 1000 slots, attachments simply won't fire.
    # If scan_specimens was never called (edge case, e.g. empty NODE_MAP branch),
    # fall back to a fresh FireCounter so relay still respects the cap.
    shared_fc = _LAST_FIRE_COUNTER[]
    if isnothing(shared_fc)
        shared_fc = VoteOrchestrator.FireCounter("relay_fallback#$(hash(input_text))", VoteOrchestrator.ACTIVE_FIRE_CAP)
    end
    relay_cap   = shared_fc.cap
    relay_additions = Tuple{String, Float64, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    for (id, conf, u_trips, n_trips) in expanded
        # GRUG: Stop firing attachments if global cap is already hit. Hard cap
        # applies across ALL fire paths — no bypass for attachments!
        if VoteOrchestrator.fire_cap_reached(shared_fc)
            println("[ENGINE] 🧠  Attachment relay halted — global fire cap ($relay_cap) reached.")
            break
        end
        # GRUG: Pass current counter value to fire_attachments! so it can
        # honor the cap internally. Tracking is per-call; counter persists.
        fired_pairs = fire_attachments!(id, VoteOrchestrator.current_fire_count(shared_fc), relay_cap)
        for (fired_id, fired_conf, connector_pattern) in fired_pairs
            if !(fired_id in already_included)
                # GRUG: Claim a fire slot for this attachment. If cap is hit, skip.
                # This ensures attached-node firings count toward the 1000 limit.
                if !VoteOrchestrator.try_claim_fire_slot!(shared_fc)
                    break
                end
                fired_node = lock(() -> get(NODE_MAP, fired_id, nothing), NODE_LOCK)
                isnothing(fired_node) && continue
                # GRUG: Inject the connector pattern as a relay triple so generative
                # knows WHY this node was co-fired. The triple reads:
                #   subject=target_id, relation="relay_attached", object=connector_pattern
                relay_triple = RelationalTriple(id, "relay_attached", connector_pattern)
                relay_triples = vcat(fired_node.relational_patterns, [relay_triple])
                push!(relay_additions, (fired_id, fired_conf, user_triples, relay_triples))
                push!(already_included, fired_id)
            end
        end
    end

    if !isempty(relay_additions)
        append!(expanded, relay_additions)
        println("[ENGINE] 🔗  Attachment relay pass added $(length(relay_additions)) node(s) to expanded set.")
    end

    # ── v7.24 FINAL PASS: Lobe Topicality Gate (NOW A PASS-THROUGH) ──
    # #############################################################################
    # ###  DO NOT ADD LOBE MUTING. apply_lobe_topicality_gate! IS A          ###
    # ###  PASS-THROUGH. IT RETURNS expanded UNCHANGED. NO LOBES ARE MUTED. ###
    # ###  THE CORRECT DESIGN IS LobeOrchestrator.jl: SEQUENTIAL FIRING.     ###
    # #############################################################################
    # GRUG v7.24: The gate is now a no-op. All lobes fire. LobeOrchestrator
    # handles sequential ordering based on lock-in vote averages.
    expanded = try
        apply_lobe_topicality_gate!(input_text, expanded)
    catch e
        @warn "[v7.24] lobe topicality gate FAILED (continuing with unfiltered pool): $e"
        expanded
    end

    return expanded
end

# ==============================================================================
# VOTE CASTING  
# ==============================================================================

"""
cast_vote(id, conf, u_trips, n_trips)

GRUG: Cast a vote for a matched node. Selects a stochastic action from the
node's action packet, bumps node strength on coinflip, and returns a Vote.
Throws if node ID is empty or node vanished from NODE_MAP — NO SILENT FAILURES.
v7.27: antimatch param removed — anti-match nodes no longer exist in the pipeline.
"""
function cast_vote(id, conf, u_trips, n_trips)
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end
    
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    winning_action, negatives = select_action(node.action_packet)
    
    # GRUG FIX 2.8: Include bad action name in error!
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG NEW: Bump strength on a coinflip when a node votes (used = maybe stronger)
    bump_strength!(node)

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips)
end

"""
cast_explicit_vote(cmd_name::String, id::String)::Vote

GRUG: Cast an explicit vote bypassing stochastic action selection. Used for
direct command overrides (e.g. /force). Sets confidence to 9999.0 (max priority).
Throws if node not found — NO SILENT FAILURES.
"""
function cast_explicit_vote(cmd_name::String, id::String)::Vote
    # Helper to bypass everything
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Explicit override failed, node [$id] not found !!!")
    
    _, negatives, _ = parse_action_packet(node.action_packet)
    return Vote(id, cmd_name, 9999.0, negatives, RelationalTriple[], node.relational_patterns)
end

# ==============================================================================
# SIGIL-ROUTED MULTI-VOTE FIRE PATH  -  GRUG v7.16+
# ==============================================================================
# GRUG: For nodes carrying a "@sigil:*" tag in drop_table, the fire path emits
# 1+ votes instead of the usual single vote. The opener is selected
# stochastically from the node's static action_packet (same select_action
# machinery as cast_vote) and concatenated with a structured payload derived
# from the sigil bindings.
#
# CONFIDENCE: all emitted votes inherit the SAME conf from pattern-bind, per
# architecture spec ("vote inheritance"). Pattern-bind says "this node is
# relevant"; the multi-vote layer says "and here are the structured pieces
# of the answer". The orchestrator picks among them downstream.
#
# DISPATCH BY KIND:
#   :math      -> compute_arithmetic(bindings) + opener concat;
#                 multi-step results emit one vote per ComputationStep
#   :multipart -> one vote per clause boundary (split on &conj bindings);
#                 each clause gets its own opener+payload
#   :instruction -> reserved; throws NotImplementedError until wired
#   :none / unknown -> falls back to a single regular cast_vote
#
# WHY OPENER+PAYLOAD CONCAT (not pure structured output):
# Per architecture: "vote pools for nodes like this can still contain static
# openers and you could just concatenate the solution to the problem." The
# opener carries the node's voice/personality; the payload carries the
# computed answer. Concatenation preserves both.

"""
    SigilFireError <: Exception

Raised when sigil-routed firing fails in a way that should NOT silently
fall back to single-vote cast_vote. Carries `kind`, `node_id`, `reason`.
"""
struct SigilFireError <: Exception
    kind::Symbol
    node_id::String
    reason::String
end
Base.showerror(io::IO, e::SigilFireError) = print(io,
    "SigilFireError on node '$(e.node_id)' (kind=:$(e.kind)): $(e.reason)")

"""
    _select_opener(packet) -> String

Pick a stochastic opener action name from `packet`. Uses the same
machinery as cast_vote's select_action so opener distributions follow
the same per-node weights specimens already author. Returns the action
name; the caller is responsible for verifying it lives in COMMANDS.
"""
function _select_opener(packet::String)::String
    opener, _ = select_action(packet)
    return opener
end

"""
    cast_sigil_votes(id, conf, bindings, original_text, u_trips, n_trips) -> Vector{Vote}

Dispatch a sigil-tagged node to its kind-specific multi-vote handler.
Returns a Vector{Vote}; for kind=:none or unknown kinds, returns a
1-element vector containing the result of cast_vote (so callers can
treat all paths uniformly).

NO SILENT FAILURES: empty id, missing node, or unknown action throws.
For known kinds, ArithmeticEngine errors propagate as SigilFireError so
the caller can decide whether to retry or skip.
"""
function cast_sigil_votes(
    id::String,
    conf::Float64,
    bindings::Vector,                 # SigilPromoter.SigilBinding, untyped to avoid using-cycle
    original_text::String,
    u_trips::Vector{RelationalTriple},
    n_trips::Vector{RelationalTriple},
)::Vector{Vote}
    if strip(id) == ""
        error("!!! FATAL: cast_sigil_votes got empty node id! !!!")
    end
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before sigil vote! !!!")

    kind = node_sigil_kind(node)

    # GRUG: untagged or unknown kind -> just delegate to cast_vote so the
    # caller can use this function uniformly without branching.
    if kind === :none
        return Vote[cast_vote(id, conf, u_trips, n_trips)]
    end

    # GRUG: per-kind dispatch. Each branch builds a Vector{Vote} sharing the
    # same conf, u_trips, n_trips. bump_strength! is called
    # ONCE per fire (not per emitted vote) to match cast_vote's intent.
    # v7.27: antimatch=false removed from all branches — field no longer exists.
    bump_strength!(node)

    if kind === :math
        return _cast_math_votes(node, conf, bindings, u_trips, n_trips)
    elseif kind === :multipart
        return _cast_multipart_votes(node, conf, bindings, original_text, u_trips, n_trips)
    elseif kind === :instruction
        throw(SigilFireError(kind, id,
            "@sigil:instruction lane is reserved; not yet implemented"))
    else
        # GRUG: unknown sigil kind on a tagged node = specimen authoring error.
        # Loud failure, no silent fallback.
        throw(SigilFireError(kind, id,
            "unknown sigil kind :$(kind); known kinds are :math, :multipart, :instruction"))
    end
end

# -----------------------------------------------------------------------------
# :math handler
# -----------------------------------------------------------------------------
# GRUG: Read bindings, run compute_arithmetic, emit votes:
#   - simple binary op (e.g. 2+2): 1 vote = "<opener> <answer>"
#   - chained op (e.g. 1+2+3):     1 vote per ComputationStep PLUS final vote
#                                   ALL steps share the same conf (inheritance)
# If compute_arithmetic returns an error result, we emit a single fallback
# opener-only vote (no answer) so the node still contributes its voice.
function _cast_math_votes(
    node::Node,
    conf::Float64,
    bindings::Vector,
    u_trips::Vector{RelationalTriple},
    n_trips::Vector{RelationalTriple},
)::Vector{Vote}
    opener = _select_opener(node.action_packet)
    if !haskey(COMMANDS, opener)
        error("!!! FATAL: Sigil opener [$opener] not in COMMANDS dictionary !!!")
    end
    _, negatives = select_action(node.action_packet)

    # GRUG v7.17+: every vote bundle gets a shared objective_id so AIML
    # can group math chain steps with their final answer.
    obj_id = fresh_objective_id()

    # GRUG: filter to math bindings only and pass to ArithmeticEngine.
    if !has_math_bindings(bindings)
        @warn "[ENGINE] _cast_math_votes called with non-math bindings on node $(node.id); emitting opener-only fallback"
        return Vote[Vote(node.id, opener, conf, negatives, u_trips, n_trips, "", obj_id, :singleton)]
    end

    result = compute_arithmetic(bindings)
    if !isnothing(result.error)
        @warn "[ENGINE] _cast_math_votes: compute_arithmetic error on node $(node.id): $(result.error); emitting opener-only fallback"
        return Vote[Vote(node.id, opener, conf, negatives, u_trips, n_trips, "", obj_id, :singleton)]
    end

    out = Vote[]

    # GRUG: per-step votes (only emitted for chained ops where len(steps) > 1).
    # Each step gets bundle_role = :step_n so AIML knows it's intermediate.
    if length(result.steps) > 1
        for step in result.steps
            step_payload = "$(step.lhs) $(step.operator) $(step.rhs) = $(step.result)"
            push!(out, Vote(node.id, opener, conf, negatives, u_trips, n_trips, step_payload, obj_id, :step_n))
        end
    end

    # GRUG: The headline answer vote. bundle_role = :final tells AIML
    # this is the primary output of the math chain.
    # GRUG v7.18+: DECOHERENCE FIX — use format_arithmetic_reply for the
    # final vote payload so the user sees a natural-language answer like
    # "2 plus 2 equals 4" instead of just the bare number "4".
    formatted_reply = format_arithmetic_reply(result)
    push!(out, Vote(node.id, opener, conf, negatives, u_trips, n_trips, formatted_reply, obj_id, :final))

    return out
end

# -----------------------------------------------------------------------------
# :multipart handler
# -----------------------------------------------------------------------------
# GRUG: Split the original text on &conj boundaries; emit one opener+clause
# vote per piece. Bindings give us conj raw_position values which we use to
# slice the original text deterministically. If no &conj is present, falls
# back to a single opener+full-text vote.
#
# DESIGN: we slice ORIGINAL text (not rewritten) so the user sees their own
# words echoed back, which reads more naturally than "&n &op &n".
function _cast_multipart_votes(
    node::Node,
    conf::Float64,
    bindings::Vector,
    original_text::String,
    u_trips::Vector{RelationalTriple},
    n_trips::Vector{RelationalTriple},
)::Vector{Vote}
    opener = _select_opener(node.action_packet)
    if !haskey(COMMANDS, opener)
        error("!!! FATAL: Sigil opener [$opener] not in COMMANDS dictionary !!!")
    end
    _, negatives = select_action(node.action_packet)

    # GRUG v7.17+: every multipart vote bundle shares one objective_id.
    # Each clause gets bundle_role = :companion so AIML can cohere them.
    obj_id = fresh_objective_id()

    # GRUG: SigilBinding.raw_position is 0-based per SigilPromoter contract.
    # Convert to 1-based Julia indices for slicing.
    conj_positions = sort!([Int(b.raw_position) + 1 for b in bindings if b.name == "conj"])

    if isempty(conj_positions)
        # GRUG: no clause boundaries -> single vote with full text echo.
        return Vote[Vote(node.id, opener, conf, negatives, u_trips, n_trips,
                         strip(original_text) |> String, obj_id, :singleton)]
    end

    # GRUG: split original text on word-index boundaries. raw_position is the
    # word index from SigilPromoter._tokenize (1-based). We collect tokens,
    # then slice on conj positions.
    tokens = split(original_text)
    n_toks = length(tokens)
    out = Vote[]
    start_idx = 1
    for cp in conj_positions
        cp_clamped = clamp(cp, 1, n_toks + 1)
        clause_end = cp_clamped - 1
        if clause_end >= start_idx
            clause_text = strip(join(tokens[start_idx:clause_end], " "))
            if !isempty(clause_text)
                push!(out, Vote(node.id, opener, conf, negatives, u_trips, n_trips,
                                String(clause_text), obj_id, :companion))
            end
        end
        start_idx = cp_clamped + 1
    end
    # GRUG: trailing clause after the last conj.
    if start_idx <= n_toks
        tail_text = strip(join(tokens[start_idx:n_toks], " "))
        if !isempty(tail_text)
            push!(out, Vote(node.id, opener, conf, negatives, u_trips, n_trips,
                            String(tail_text), obj_id, :companion))
        end
    end

    # GRUG: edge case -- if all clauses got dropped (e.g. text was just a
    # bare "and"), emit the fallback single-vote so the node still speaks.
    if isempty(out)
        push!(out, Vote(node.id, opener, conf, negatives, u_trips, n_trips,
                        strip(original_text) |> String, obj_id, :singleton))
    end

    return out
end

# ==============================================================================
# /WRONG FEEDBACK: PENALIZE ALL VOTERS
# ==============================================================================

"""
apply_wrong_feedback!(voter_ids::Vector{String})

GRUG: /wrong command! Every node who voted gets a coinflip.
Losers have their strength lowered. Nodes that hit 0 are marked GRAVE.
Grave nodes become negative reinforcement anchors during generative phase.
"""
function apply_right_feedback!(contributor_ids::Vector{String})::Dict{String, Any}
    """
    Apply secondary reinforcement to regular (non-AIML) nodes that contributed to output.
    
    CRITICAL: Only processes nodes that fired_this_cycle == true (contributors).
    - Nodes that already gained strength this cycle are skipped (no double reward)
    - Grave nodes are skipped (dead nodes don't get feedback)
    - Uses 50/50 coinflip for eligible contributors (secondary reinforcement chance)
    
    Returns statistics dictionary with:
    - "total_contributors": Total number of contributing nodes
    - "rewarded": Node IDs that gained strength
    - "skipped_double_reward": Node IDs that already gained (skipped to avoid double reward)
    - "coinflip_missed": Node IDs that lost the coinflip
    - "grave_skipped": Node IDs that are grave and were skipped
    """
    if isempty(contributor_ids)
        error("!!! FATAL: apply_right_feedback! got empty contributor_ids list! !!!")
    end

    rewarded = String[]
    skipped_double_reward = String[]
    coinflip_missed = String[]
    grave_skipped = String[]
    STRENGTH_DELTA = 1.0  # Same as AIML_STRENGTH_DELTA

    lock(NODE_LOCK) do
        for id in contributor_ids
            node = get(NODE_MAP, id, nothing)
            if isnothing(node)
                # GRUG: Node may have already been deleted. Non-fatal, skip.
                println("[ENGINE] ⚠  /right: Node [$id] not found, skipping.")
                continue
            end

            # Skip grave nodes
            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end

            # Skip nodes that already gained strength this cycle (no double reward)
            if node.gained_this_cycle
                push!(skipped_double_reward, node.id)
                continue
            end

            # 50/50 coinflip for secondary reinforcement
            if rand() < 0.5
                bump_strength!(node)
                node.gained_this_cycle = true
                node.strength_delta_this_cycle += STRENGTH_DELTA
                push!(rewarded, node.id)
            else
                push!(coinflip_missed, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors"   => length(contributor_ids),
        "rewarded"             => rewarded,
        "skipped_double_reward" => skipped_double_reward,
        "coinflip_missed"      => coinflip_missed,
        "grave_skipped"        => grave_skipped,
    )
    println("[ENGINE] ✅ /right: contributors=$(length(contributor_ids)) rewarded=$(length(rewarded)) double_skip=$(length(skipped_double_reward)) coinflip_miss=$(length(coinflip_missed)) grave_skip=$(length(grave_skipped))")
    return result
end

function apply_wrong_feedback!(contributor_ids::Vector{String})
    if isempty(contributor_ids)
        error("!!! FATAL: apply_wrong_feedback! got empty contributor_ids list! !!!")
    end

    penalized_count = 0
    graved_count    = 0

    for id in contributor_ids
        node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        if isnothing(node)
            # GRUG: Node may have already been graved. Non-fatal, skip.
            println("[ENGINE] ⚠  /wrong: Node [$id] not found, skipping.")
            continue
        end

        was_grave_before = node.is_grave
        penalize_strength!(node)

        penalized_count += 1
        if node.is_grave && !was_grave_before
            graved_count += 1
        end
    end

    println("[ENGINE] ❌  /wrong applied to $(length(contributor_ids)) contributors. penalized= $penalized_count, newly_graved= $graved_count.")
end

# ==============================================================================
# JSON NODE GROWER (MAP EXPANSION)
# ==============================================================================

"""
grow_nodes_from_packet(json_str::String)::Vector{String}

GRUG: Parse a JSON packet and grow new nodes from it.
Supports `is_image_node` flag in the JSON for image node creation.
If `is_image_node` is true, `pattern` field is treated as image binary descriptor.
"""
function grow_nodes_from_packet(json_str::String)::Vector{String}
    if strip(json_str) == "" error("!!! FATAL: Cannot grow from empty JSON string !!!") end
    packet = try JSON.parse(json_str) catch e error("!!! FATAL: JSON parser dead: $e !!!") end
    
    if !haskey(packet, "nodes")
        error("!!! FATAL: JSON packet missing 'nodes' array! !!!")
    end
    
    nodes_arr = packet["nodes"]
    
    validated = Vector{Tuple{String,String,Dict{String,Any},Vector{String},Bool}}()
    for n in nodes_arr
        pattern      = String(n["pattern"])
        action_packet = String(n["action_packet"])
        json_data    = Dict{String, Any}(string(k) => v for (k, v) in n["json_data"])
        drop_table   = haskey(n, "drop_table") && (n["drop_table"] isa AbstractVector) ? 
                       String[string(x) for x in n["drop_table"]] : String[]
        # GRUG NEW: Check for is_image_node flag in JSON packet
        is_img_node  = haskey(n, "is_image_node") && n["is_image_node"] === true
        push!(validated, (pattern, action_packet, json_data, drop_table, is_img_node))
    end

    new_ids = String[]
    for (p, a, j, d, is_img) in validated
        push!(new_ids, create_node(p, a, j, d; is_image_node=is_img))
    end
    return new_ids
end

# ==============================================================================
# NODE STATUS SUMMARY (FOR /nodes COMMAND)
# ==============================================================================

"""
get_node_status_summary()::String

GRUG: Return a human-readable summary of all nodes: strength, neighbors, grave status.
Used by the /nodes CLI command.
"""
function get_node_status_summary()::String
    lines = String[]
    lock(NODE_LOCK) do
        if isempty(NODE_MAP)
            push!(lines, "[NODE MAP EMPTY]")
            return
        end
        push!(lines, "=== NODE MAP STATUS ($(length(NODE_MAP)) nodes) ===")
        for (id, node) in sort(collect(NODE_MAP), by=x->x[1])
            grave_tag  = node.is_grave     ? "[$(node.grave_reason)]" : "[ALIVE]"
            link_tag   = node.is_unlinkable ? "[UNLINKABLE]"          : "[LINKABLE]"
            img_tag    = node.is_image_node ? "[IMG]"                 : "[TXT]"
            avg_rt     = isempty(node.response_times) ? "N/A" :
                         "$(round(sum(node.response_times)/length(node.response_times), digits=3))s"
            push!(lines, "  $id | str=$(round(node.strength, digits=2)) | neighbors=$(length(node.neighbor_ids)) | $grave_tag $link_tag $img_tag | avg_rt=$avg_rt | pattern=\"$(first(node.pattern, 40))\"")
        end
    end
    return join(lines, "\n")
end

# ==============================================================================
# AIML RULE TABLE (STOCHASTIC ORCHESTRATION RULES)
# ==============================================================================
# GRUG: Rule table lives here so Engine and test runner can both access it.
# Main.jl uses add_orchestration_rule! to populate it at runtime.

# GRUG: AIML rules are STOCHASTIC! Each rule has a fire probability [0.0, 1.0].
# At evaluation time, Grug rolls a coinflip against the probability.
# Rules with prob=1.0 always fire (deterministic). prob=0.5 fires half the time.
struct StochasticRule
    text::String               # GRUG: Rule template text (with magic word placeholders)
    fire_probability::Float64  # GRUG: [0.0, 1.0] - how often this rule fires
end

const AIML_DROP_TABLE = StochasticRule[]

# GRUG: Allowed magic word tags. Fake tags are rejected loudly!
const ALLOWED_RULE_TAGS = Set([
    "{MISSION}",
    "{PRIMARY_ACTION}",
    "{SURE_ACTIONS}",
    "{UNSURE_ACTIONS}",
    "{ALL_ACTIONS}",
    "{CONFIDENCE}",
    "{NODE_ID}",
    "{MEMORY}",
    "{LOBE_CONTEXT}",
    "{VOTE_CERTAINTY}",
    "{TIED_ALTERNATIVES}"
])

"""
add_orchestration_rule!(rule_input::String)::String

GRUG: Add a stochastic rule to the AIML rule board.
Optional [prob=X.XX] suffix sets fire probability (default 1.0).
Validates all magic word tags. Throws loudly on invalid input.
"""
function add_orchestration_rule!(rule_input::String)::String
    if strip(rule_input) == ""
        error("!!! FATAL: Grug cannot add empty air to rule board! !!!")
    end

    # GRUG: Parse optional stochastic probability suffix [prob=X.XX]
    prob_match = match(r"\[prob=([0-9.]+)\]\s*$", rule_input)
    fire_prob  = 1.0
    rule_text  = rule_input

    if !isnothing(prob_match)
        parsed_prob = tryparse(Float64, prob_match.captures[1])
        if isnothing(parsed_prob) || parsed_prob < 0.0 || parsed_prob > 1.0
            error("!!! FATAL: /addRule [prob=X] value is invalid: '$(prob_match.captures[1])'. Must be 0.0-1.0 !!!")
        end
        fire_prob = parsed_prob
        # GRUG: Strip the [prob=...] suffix from the rule text before storing
        rule_text = strip(replace(rule_input, r"\[prob=[0-9.]+\]\s*$" => ""))
    end

    if strip(rule_text) == ""
        error("!!! FATAL: Rule text is empty after stripping probability suffix! !!!")
    end

    # GRUG: Strict Tag Validation. If tag not in allowed list, throw big rock error!
    for m in eachmatch(r"\{[A-Z_]+\}", rule_text)
        tag = m.match
        if !(tag in ALLOWED_RULE_TAGS)
            error("!!! FATAL: Grug see fake magic rock: $tag! Allowed rocks are: $(join(ALLOWED_RULE_TAGS, ", ")) !!!")
        end
    end

    push!(AIML_DROP_TABLE, StochasticRule(rule_text, fire_prob))
    return "Rule tied to tree: [$rule_text] (fire_prob=$(round(fire_prob, digits=2)))"
end

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: KERNEL LAYER (UPDATED)
#
# 1. PERCEPTUAL SIGNAL MAPPING:
# Natural language strings are deterministically hashed into normalized Float64
# vectors upon node creation and user input. This converts NLP string matching 
# into localized sliding-window signal processing via PatternScanner.jl.
#
# 2. DYNAMIC ATTENTION BOTTLENECK (600-1800):
# scan_specimens implements a biological cap. At evaluation time, active_cap 
# is rolled (600:1800). The node registry is shuffled, and only the capped subset 
# is evaluated. This guarantees bounded compute times while simulating shifting 
# heuristic attention patterns.
#
# 3. DETERMINISTIC PERCEPTION MODES:
# Every active node deterministically scales its sensory resolution (cheap, 
# medium, high_res) based on the complexity score of the user's signal density 
# and relational structure, saving CPU cycles on simple inputs.
#
# 4. STRENGTH SYSTEM (APOPTOSIS + STRATIFICATION):
# Nodes accumulate strength on a coinflip when used. Strength is capped at 
# STRENGTH_CAP to prevent runaway dominance (apoptosis ceiling). Nodes penalized 
# via /wrong lose strength on a coinflip; at 0 they become grave markers used as 
# negative reinforcement during the generative phase.
#
# 5. HOPFIELD FAMILIAR INPUT CACHE:
# High-confidence scan results are stored in HOPFIELD_CACHE keyed by input hash.
# Inputs seen multiple times at high confidence bypass the full scan and fire 
# precached node IDs directly, dramatically reducing compute for familiar patterns.
#
# 6. DROP TABLE CO-ACTIVATION:
# scan_and_expand() extends primary scan results with drop-table neighbor nodes.
# Nodes in a primary node's drop_table co-activate with 80% confidence discount.
# This models associative memory: related concepts activate together.
#
# 7. STRENGTH-BIASED SCAN COINFLIP:
# Before pattern scanning, each node undergoes a strength-biased Bernoulli trial.
# Strong nodes (strength near cap) have ~90% scan probability; weak nodes ~20%.
# This creates a soft attention hierarchy without hard winner-takes-all exclusion.
#
# 8. BIG-O RESPONSE TIME LEDGER:
# Each node tracks its own response time history in a 24-hour rolling ledger.
# Nodes whose average response time exceeds SLOW_NODE_THRESHOLD_SECONDS are
# automatically marked [GRAVED-SLOW] and removed from the active voting pool.
#
# 9. NEIGHBOR LINKING (MAX 4 = UNLINKABLE):
# New nodes latch onto the strongest pattern-similar existing node. Nodes are 
# capped at MAX_NEIGHBORS (4) before being flagged UNLINKABLE. Drop tables and 
# neighbor links form the associative graph structure of the specimen.
#
# 10. LIVE SEMANTIC VERB REGISTRY (SEMANRICVERBS.JL):
# Static const verb sets have been replaced by a mutable runtime registry managed
# by SemanticVerbs.jl. extract_relational_triples() calls get_all_verbs() on every
# invocation, so verbs added via /addVerb take effect immediately on the next input.
# Synonym normalization (normalize_synonyms) runs as the first step of triple
# extraction, before passive rewriting, ensuring alias→canonical mapping happens at
# word boundaries without corrupting partial tokens. Load-time snapshot consts
# (CAUSAL_VERBS, SPATIAL_VERBS, TEMPORAL_VERBS) are preserved for backward
# compatibility with external diagnostic code but must not be used in new matching.
#
# 11. ACTION+TONE PRE-VOTE MODULATION (ACTIONTONEPREDICTOR.JL):
# Before the Hopfield cache check and before the scan loop, scan_specimens() invokes
# ActionTonePredictor.predict_action_tone() to classify the input's action family
# (ASSERT/QUERY/COMMAND/NEGATE/SPECULATE/ESCALATE) and tone family
# (HOSTILE/CURIOUS/DECLARATIVE/URGENT/NEUTRAL/REFLECTIVE) from surface lexical
# markers. The resulting PredictionResult carries an action_weight multiplier that
# is applied per-node inside the scan loop: nodes whose declared action aligns with
# the predicted action family receive a confidence boost; misaligned nodes receive
# a mild suppression (0.85 base + 0.15*(1-conf)). Low-confidence predictions apply
# near-unity multipliers, preserving scan integrity when evidence is weak. Dangling
# causal chain detection emits a non-fatal @warn when the input ends on a verb with
# no object, helping surface ambiguous or truncated inputs.
# ==============================================================================

# ==============================================================================
# LOBE POPULATION HELPERS
# ==============================================================================

"""
    count_alive_nodes_in_lobe(lobe_id::String)::Int

GRUG: Count how many ALIVE (non-grave) nodes belong to a lobe.
Graves are memory, not bloat — dead nodes don't eat cap space.
Returns 0 if lobe doesn't exist or Lobe module not loaded.
"""
function count_alive_nodes_in_lobe(lobe_id::String)::Int
    if !isdefined(@__MODULE__, :Lobe)
        return 0
    end
    lobe_rec = Lobe.get_lobe(lobe_id)
    if isnothing(lobe_rec)
        return 0
    end
    alive_count = 0
    lock(NODE_LOCK) do
        for node_id in lobe_rec.node_ids
            node = get(NODE_MAP, node_id, nothing)
            if !isnothing(node) && !node.is_grave
                alive_count += 1
            end
        end
    end
    return alive_count
end