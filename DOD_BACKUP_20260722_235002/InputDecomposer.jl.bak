# ==============================================================================
# InputDecomposer.jl — v7.28 Compound-Query Decomposition
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
# GRUG say: detection is CONJUNCTION + MULTI-CLAUSE + SIGIL BOUNDARY.
#           "also", "and", "but" when they join two INDEPENDENT clauses.
#           Multiple "?" markers. Multiple sigil expansions. Not every
#           "and" trigger split — "bread and butter" is ONE subject.
#           "what is bread AND what is butter" is TWO subject. Context
#           matter. Heuristic is: conjunction + question marker on both
#           side = split. Conjunction + no question = same subject.
#
# v7.27: GRUG say SPECIMEN OWNS THE CONJUNCTIONS. Not source code. The
#           specimen has decomposer_config with split_conjunctions, compound_pairs,
#           question_markers, command_markers, conjugation_rules. The decomposer
#           reads them at runtime. If specimen doesn't have them, built-in defaults
#           (the old constants) are used. SPECIMEN-OVERRIDES-DEFAULTS.
#
# v7.27: CONJUGATION RULES. "calculates", "calculated", "calculating" all
#           match the "calculate" command marker. The specimen's
#           conjugation_rules maps verb stems to inflected forms. The
#           decomposer expands command_markers to include all inflected forms.
#           Now "describe what fire is and then calculate the total" splits
#           correctly even when the user writes "describes" or "calculated".
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

using Base.Threads: ReentrantLock

export DecomposedSubSubject, decompose_input, is_compound
export InputChunk, chunk_boundaries
export DecomposerConfig, build_config, DEFAULT_CONFIG
export set_config!, get_config
# v7.28: Config mutation exports (for /decomposer CLI)
export add_split_conjunction!, remove_split_conjunction!
export add_compound_pair!, remove_compound_pair!
export add_question_marker!, remove_question_marker!
export add_command_marker!, remove_command_marker!
export add_conjugation_rule!, remove_conjugation_rule!
export set_context_conjunction!, reset_config!
export config_status_string
# GRUG v10: MLP-assisted decomposition exports
export decompose_input_mlp
export MLP_COMPOUND_THRESHOLD, MLP_NOVELTY_COMPOUND_THRESHOLD, MLP_COMPOUND_MAX_PARTS

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
# INPUT CHUNK — token-range scope for pattern bind phase
# ==============================================================================

#=
    InputChunk — a contiguous token range in the input.

    When the decomposer splits a compound input, each sub-subject covers a
    span of the original tokenized input. InputChunk captures that span as
    (first_token, last_token) indices into the whitespace-split token array,
    plus a chunk_index for fast comparison.

    The scanner already returns best_idx (1-based token position) from
    cheap_scan / medium_scan / high_res_scan. By cross-referencing best_idx
    against InputChunk boundaries, the scan phase can determine which chunk(s)
    a match covers and stamp the resulting vote with input_chunks.

    Bio-coherence: place cells fire for a specific location, not "the
    environment." Object cells fire for a specific object, not "the scene."
    A vote that knows which chunk it resolved is a place-cell vote — it
    carries its own scope instead of relying on an external tag.
=#
struct InputChunk
    first_token::Int    # 1-based index of first token in this chunk
    last_token::Int     # 1-based index of last token in this chunk
    chunk_index::Int    # which chunk this is (1, 2, 3...)
    text::String        # the sub-string this chunk covers (for diagnostics)
end

# ==============================================================================
# DECOMPOSER CONFIG — user-definable via specimen
# ==============================================================================

#=
    DecomposerConfig — all the lists that were previously hardcoded constants.

    The specimen's decomposer_config dict is read at runtime via build_config().
    If the specimen doesn't have a decomposer_config, or a key is missing,
    built-in defaults are used (the old constants). This is
    SPECIMEN-OVERRIDES-DEFAULTS, not specimen-replaces-defaults.

    conjugation_rules: maps verb stem (String) to Vector of inflected forms.
    When checking command_markers, the decomposer also checks all inflected
    forms. So "calculates" matches the "calculate" command marker.

    expanded_command_markers: the FULL set — command_markers + all their
    inflected forms. Built by build_config() from command_markers and
    conjugation_rules. This is what _has_clause_structure actually checks.
=#
struct DecomposerConfig
    split_conjunctions::Set{String}
    compound_pairs::Dict{String,Set{String}}   # "and" → Set(["then","also",...])
    context_conjunction::String
    question_markers::Set{String}
    command_markers::Set{String}               # stems only (for display/diagnostics)
    expanded_command_markers::Set{String}       # stems + all inflected forms
    conjugation_rules::Dict{String,Vector{String}}
end

# ==============================================================================
# BUILT-IN DEFAULTS (the old constants, used when specimen has no config)
# ==============================================================================

const _DEFAULT_SPLIT_CONJUNCTIONS = Set([
    "also", "additionally", "furthermore", "moreover",
    "besides", "likewise", "similarly",
    "but", "however", "yet", "nevertheless", "nonetheless",
    "alternatively", "instead",
    "or",   # "what is X or what is Y" — split
    "then", # "calculate X and then describe Y" — split at "then"
    # ── GRUG v10: expanded conjunctions ──
    "while", "whilst",     # "what is X while what is Y"
    "since",               # "describe X since Y is also relevant"
    "unless",              # "explain X unless you prefer Y"
    "except",              # "calculate X except compute Y instead"
    "plus",                # "what is X plus what is Y"
    "independently",       # "analyze X independently evaluate Y"
    "separately",          # "describe X separately summarize Y"
])

const _DEFAULT_COMPOUND_PAIRS = Dict{String,Set{String}}(
    "and" => Set(["then", "also", "additionally", "furthermore", "moreover"]),
    # ── GRUG v10: expanded compound pairs ──
    "or"  => Set(["else"]),              # "or else" is compound
    "but" => Set(["rather", "instead"]), # "but rather", "but instead"
    "then"=> Set(["additionally"]),      # "then additionally"
)

const _DEFAULT_CONTEXT_CONJUNCTION = "and"

const _DEFAULT_QUESTION_MARKERS = Set([
    "what", "who", "where", "when", "why", "how",
    "which", "whose", "whom",
    # ── GRUG v10: expanded question markers (auxiliary verbs) ──
    "can", "could", "would", "shall", "will",
    "do", "does", "did",
    "is", "are", "was", "were", "am"
])

const _DEFAULT_COMMAND_MARKERS = Set([
    "tell", "show", "give", "explain", "describe",
    "calculate", "compute", "solve", "define",
    "list", "name", "find", "count",
    # ── GRUG v10: expanded command markers ──
    "compare", "contrast", "analyze", "evaluate",
    "summarize", "determine", "identify",
    "convert", "translate", "search", "lookup"
])

const _DEFAULT_CONJUGATION_RULES = Dict{String,Vector{String}}(
    "tell"      => ["tells", "told", "telling"],
    "show"      => ["shows", "showed", "showing"],
    "give"      => ["gives", "gave", "giving"],
    "explain"   => ["explains", "explained", "explaining"],
    "describe"  => ["describes", "described", "describing"],
    "calculate" => ["calculates", "calculated", "calculating"],
    "compute"   => ["computes", "computed", "computing"],
    "solve"     => ["solves", "solved", "solving"],
    "define"    => ["defines", "defined", "defining"],
    "list"      => ["lists", "listed", "listing"],
    "name"      => ["names", "named", "naming"],
    "find"      => ["finds", "found", "finding"],
    "count"     => ["counts", "counted", "counting"],
    # ── GRUG v10: conjugation rules for new command markers ──
    "compare"   => ["compares", "compared", "comparing"],
    "contrast"  => ["contrasts", "contrasted", "contrasting"],
    "analyze"   => ["analyzes", "analyzed", "analyzing"],
    "evaluate"  => ["evaluates", "evaluated", "evaluating"],
    "summarize" => ["summarizes", "summarized", "summarizing"],
    "determine" => ["determines", "determined", "determining"],
    "identify"  => ["identifies", "identified", "identifying"],
    "convert"   => ["converts", "converted", "converting"],
    "translate" => ["translates", "translated", "translating"],
    "search"    => ["searches", "searched", "searching"],
    "lookup"    => ["lookups", "lookedup"],     # irregular but common
)

"""
    DEFAULT_CONFIG — the built-in config used when no specimen config is provided.
    Built once at module load time from the default constants above.
"""
const DEFAULT_CONFIG = let
    _expanded = copy(_DEFAULT_COMMAND_MARKERS)
    for (stem, forms) in _DEFAULT_CONJUGATION_RULES
        push!(_expanded, stem)
        for f in forms
            push!(_expanded, f)
        end
    end
    DecomposerConfig(
        _DEFAULT_SPLIT_CONJUNCTIONS,
        _DEFAULT_COMPOUND_PAIRS,
        _DEFAULT_CONTEXT_CONJUNCTION,
        _DEFAULT_QUESTION_MARKERS,
        _DEFAULT_COMMAND_MARKERS,
        _expanded,
        _DEFAULT_CONJUGATION_RULES
    )
end

# ==============================================================================
# RUNTIME CONFIG — set by Main.jl when a specimen is loaded
# ==============================================================================

# GRUG: This Ref holds the decomposer config that was loaded from the specimen.
# When Main.jl loads a specimen, it calls set_config!(specimen_dict) which
# builds a DecomposerConfig from the specimen's decomposer_config section
# and stores it here. The single-arg decompose_input(input_text) uses this.
# If no specimen has been loaded, it falls back to DEFAULT_CONFIG.

const _RUNTIME_CONFIG = Ref{DecomposerConfig}(DEFAULT_CONFIG)
const _CONFIG_LOCK = ReentrantLock()

"""
    set_config!(specimen_dict) -> DecomposerConfig

Build a DecomposerConfig from the specimen's decomposer_config and store it
as the runtime config. Called by Main.jl after loading a specimen. Returns
the new config for inspection/logging.
"""
function set_config!(specimen_dict)::DecomposerConfig
    cfg = build_config(specimen_dict)
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return cfg
end

"""
    get_config() -> DecomposerConfig

Get the current runtime decomposer config. Useful for diagnostics.
"""
function get_config()::DecomposerConfig
    return lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
end

# ==============================================================================
# BUILD CONFIG FROM SPECIMEN DICT
# ==============================================================================

"""
    build_config(specimen_dict) -> DecomposerConfig

Build a DecomposerConfig from the specimen's decomposer_config dict.
If the specimen doesn't have a decomposer_config, returns DEFAULT_CONFIG.
If a key is missing, uses the built-in default for that key.

The specimen dict should have a "decomposer_config" key with:
  - "split_conjunctions": Array of strings
  - "compound_pairs": Dict of string → Array of strings
  - "context_conjunction": String
  - "question_markers": Array of strings
  - "command_markers": Array of strings
  - "conjugation_rules": Dict of string → Array of strings

GRUG say: SPECIMEN OWNS THE CONJUNCTIONS. You want "hence" to be a split
conjunction? Put it in decomposer_config.split_conjunctions. You want
"investigate" to be a command marker with conjugation "investigates",
"investigated", "investigating"? Put it in decomposer_config. No source
code edit needed. The specimen is the brain, not the compiler.
"""
function build_config(specimen_dict)::DecomposerConfig
    dc = get(specimen_dict, "decomposer_config", nothing)
    if dc === nothing
        return DEFAULT_CONFIG
    end

    # Split conjunctions
    split_conjs = if haskey(dc, "split_conjunctions")
        Set{String}(String(x) for x in dc["split_conjunctions"])
    else
        _DEFAULT_SPLIT_CONJUNCTIONS
    end

    # Compound pairs
    # GRUG v8.4: Compound pair values in the specimen can be either:
    #   - a String like "or" (legacy/compact format)
    #   - an Array of strings like ["or", "else"]
    # If it's a String, iterating it would yield Chars ('o', 'r'), and
    # String('o') throws MethodError. Fix: normalize to array first.
    compound_pairs = if haskey(dc, "compound_pairs")
        Dict{String,Set{String}}(
            String(k) => begin
                _vals = isa(vs, AbstractString) ? [vs] : vs
                Set{String}(String(v) for v in _vals)
            end
            for (k, vs) in dc["compound_pairs"]
        )
    else
        _DEFAULT_COMPOUND_PAIRS
    end

    # Context conjunction
    context_conj = if haskey(dc, "context_conjunction")
        String(dc["context_conjunction"])
    else
        _DEFAULT_CONTEXT_CONJUNCTION
    end

    # Question markers
    question_markers = if haskey(dc, "question_markers")
        Set{String}(String(x) for x in dc["question_markers"])
    else
        _DEFAULT_QUESTION_MARKERS
    end

    # Command markers (stems)
    command_markers = if haskey(dc, "command_markers")
        Set{String}(String(x) for x in dc["command_markers"])
    else
        _DEFAULT_COMMAND_MARKERS
    end

    # Conjugation rules
    conj_rules = if haskey(dc, "conjugation_rules")
        Dict{String,Vector{String}}(
            String(k) => [String(v) for v in vs]
            for (k, vs) in dc["conjugation_rules"]
        )
    else
        _DEFAULT_CONJUGATION_RULES
    end

    # Expanded command markers: stems + all inflected forms
    expanded = copy(command_markers)
    for (stem, forms) in conj_rules
        push!(expanded, stem)
        for f in forms
            push!(expanded, f)
        end
    end

    return DecomposerConfig(
        split_conjs,
        compound_pairs,
        context_conj,
        question_markers,
        command_markers,
        expanded,
        conj_rules
    )
end

# ==============================================================================
# CHUNK BOUNDARIES — compute InputChunks from decomposed sub-subjects
# ==============================================================================

# GRUG: Characters to strip when matching sub-subject tokens against
# full-input tokens. Decomposition may remove trailing punctuation.
const punctuation_chars = [',', '.', ';', ':', '!', '?', '-', '—']

#=
    chunk_boundaries(input_text) -> Vector{InputChunk}

    Decompose the input, then compute token ranges for each sub-subject.
    Returns a vector of InputChunk, one per sub-subject. For singleton
    inputs, returns one chunk spanning the entire input.

    Uses DEFAULT_CONFIG (no specimen config). For specimen-driven config,
    use chunk_boundaries(input_text, config).
=#
function chunk_boundaries(input_text::String)::Vector{InputChunk}
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    return chunk_boundaries(input_text, cfg)
end

function chunk_boundaries(input_text::String, config::DecomposerConfig)::Vector{InputChunk}
    if isempty(strip(input_text))
        # Empty input — one chunk spanning nothing
        return [InputChunk(1, 0, 1, "")]
    end

    # Decompose the input first
    subs = decompose_input(input_text, config)

    # Singleton — one chunk spanning everything
    if length(subs) == 1
        n_tokens = length(split(input_text))
        return [InputChunk(1, n_tokens, 1, input_text)]
    end

    # Compound — compute token ranges for each sub-subject.
    # Tokenize the full input once, then find each sub-subject's tokens.
    full_tokens = split(input_text)
    n_full = length(full_tokens)

    # GRUG: Build a mapping from (lowercased token, position) for the full
    # input so we can find where each sub-subject starts.
    # Strategy: walk the full token stream left-to-right. For each
    # sub-subject, find its first token in the remaining full stream,
    # then track how many tokens it covers.
    chunks = InputChunk[]
    full_idx = 1  # current position in full token stream

    for (i, sub) in enumerate(subs)
        sub_tokens = split(sub.text)
        isempty(sub_tokens) && continue

        # GRUG: Find where this sub-subject starts in the full token stream.
        # The sub-subject's tokens are a contiguous subsequence of the full
        # token stream (because decomposition splits at boundaries, it doesn't
        # reorder). We search from full_idx forward.
        first_tok = lowercase(strip(sub_tokens[1], punctuation_chars))
        start_idx = full_idx

        # Scan forward to find the start of this sub-subject
        found = false
        for fi in full_idx:n_full
            ft = lowercase(strip(full_tokens[fi], punctuation_chars))
            if ft == first_tok
                start_idx = fi
                found = true
                break
            end
        end

        if !found
            # Fallback: can't find sub-subject start. Use current position.
            start_idx = full_idx
        end

        # GRUG: The sub-subject covers len(sub_tokens) tokens starting
        # from start_idx. But we need to handle the case where the
        # conjunction that was split on appears in the full stream but
        # not in the sub-subject's text.
        end_idx = min(start_idx + length(sub_tokens) - 1, n_full)

        push!(chunks, InputChunk(start_idx, end_idx, i, sub.text))
        full_idx = end_idx + 1
    end

    # GRUG: If we failed to produce any chunks, fall back to singleton.
    if isempty(chunks)
        return [InputChunk(1, n_full, 1, input_text)]
    end

    return chunks
end

# ==============================================================================
# CORE DECOMPOSITION
# ==============================================================================

"""
    decompose_input(input_text) -> Vector{DecomposedSubSubject}

Analyze the input for compound structure using the runtime config
(set by set_config! from the specimen). If no specimen has been loaded,
uses DEFAULT_CONFIG. For explicit config, use decompose_input(input_text, config).
"""
function decompose_input(input_text::String)::Vector{DecomposedSubSubject}
# REMINDER: ANTIMATCH REMOVED. SIGILS IN TRIPLES. HOPFIELD REMOVED.
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    return decompose_input(input_text, cfg)
end

"""
    decompose_input(input_text, config) -> Vector{DecomposedSubSubject}

Analyze the input for compound structure using the provided DecomposerConfig.
Returns a vector of sub-subjects. If the input is simple (no compound
structure), returns a single sub-subject with multipart_group = "" and
role = :singleton (matching historical behavior).

If compound, each sub-subject gets a unique multipart_group ("mp_1", "mp_2", ...)
and the first sub-subject is :primary while subsequent ones are :support.
NOTE: The .role field controls OUTPUT ORDERING only — it tells the orchestrator
which part to render first. It does NOT set the vote's multipart_role. In
MultipartOrchestrator, every group's winning vote is :primary within its own
group, regardless of this field. The caller (process_mission) stamps :primary
as the vote role for every sub-subject's winning vote.
"""
function decompose_input(input_text::String, config::DecomposerConfig)::Vector{DecomposedSubSubject}
# REMINDER: ANTIMATCH REMOVED. SIGILS IN TRIPLES. HOPFIELD REMOVED.
    if isempty(strip(input_text))
        return [DecomposedSubSubject(input_text, "", :singleton, 1)]
    end

    # GRUG: Step 1 — try conjunction-based splitting.
    clauses = _split_on_conjunctions(input_text, config)

    # GRUG: Step 2 — if conjunction splitting found nothing, try
    # question-marker splitting (multiple "?" in the input).
    if length(clauses) <= 1
        clauses = _split_on_question_markers(input_text)
    end

    # GRUG: Step 2b — if still just one clause, try comma-based splitting.
    # "what is X, what is Y, what is Z" — commas between independent questions.
    if length(clauses) <= 1
        clauses = _split_on_comma_clauses(input_text, config)
    end

    # GRUG: Step 2c — sigil-boundary splitting. When the input contains
    # arithmetic expressions (2+3), special sigils (|pipe|), or other
    # sigil-class boundaries, split there. "what is 2+3 and what is fire"
    # already splits at "and", but "describe gravity 2+3 what is fire"
    # needs the arithmetic boundary to split. The arithmetic expression
    # and the natural-language question are fundamentally different subjects.
    if length(clauses) <= 1
        clauses = _split_on_sigil_boundaries(input_text, config)
    end

    # GRUG: Step 3 — still just one clause? Singleton. Old path.
    if length(clauses) <= 1
        # v7.25: HARD WARNING when input LOOKS compound but wasn't decomposed.
        # Heuristic: multiple imperative/question verbs in the input suggest
        # compound structure that the decomposer missed.
        _lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in split(input_text)]
        _cmd_count = count(t -> t in config.expanded_command_markers || t in config.question_markers, _lower_tokens)
        # GRUG v8.4: Reduce false positives by counting adjacent markers as ONE.
        # "what is fire" has 2 markers ("what", "is") but they're part of the same
        # question structure — not separate clauses. Adjacent markers in the token
        # stream should be grouped together.
        _marker_positions = findall(t -> t in config.expanded_command_markers || t in config.question_markers, _lower_tokens)
        _marker_groups = 0
        _last_pos = -10  # sentinel
        for pos in _marker_positions
            if pos > _last_pos + 1
                _marker_groups += 1
            end
            _last_pos = pos
        end
        if _marker_groups >= 2
            @warn """⚠️  COHERENCE WARNING: Input looks compound but was NOT decomposed!
               Input: \"$input_text\"
               Found $_marker_groups marker groups (from $_cmd_count individual markers) but no split was made.
               The system will pick ONE action and ignore the rest — that's a coherence failure.
               FIX: Add the missing conjunction to decomposer_config.split_conjunctions, or restructure the input.
               YOU NEED DECOMPOSITION FOR COMPOUND INPUT, OR NO CAN DO."""
        end
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
    _split_on_conjunctions(input_text, config) -> Vector{String}

Split the input at conjunction boundaries where both sides look like
independent clauses (question or command structure). Returns Vector of
clause strings. If no splits found, returns [input_text].
"""
function _split_on_conjunctions(input_text::String, config::DecomposerConfig)::Vector{String}
    tokens = split(input_text)
    isempty(tokens) && return [input_text]

    # GRUG: Walk the token stream. When we find a split-conjunction,
    # check if both the left and right contexts look independent.
    # "what is time also what is dinosaur" — "also" splits because
    # left has "what" and right has "what".
    # "time also runs fast" — "also" does NOT split because neither
    # side has question/command structure.

    splits = Tuple{Int,Int}[]  # (left_end, right_start) — conjunction tokens to discard
    lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in tokens]

    # v7.26-COMPOUND-CONJ: Track which token indices were consumed as part
    # of a compound conjunction pair (e.g., "and" + "then"). These indices
    # should be skipped in the main loop to prevent double-splitting.
    _consumed = Set{Int}()

    # v7.26-COMPOUND-CONJ: Pre-pass — find compound conjunction pairs
    # ("and then", "and also", etc.) and record them.
    # Uses config.compound_pairs instead of hardcoded COMPOUND_LEADERS.
    for i in 2:(length(tokens) - 1)
        tok = lower_tokens[i]
        if haskey(config.compound_pairs, tok)
            # This token is a compound leader. Check if the next token
            # is one of its compound followers.
            if i + 1 <= length(lower_tokens) && lower_tokens[i + 1] in config.compound_pairs[tok]
                left_has_structure = _has_clause_structure(lower_tokens, 1, i - 1, config)
                right_has_structure = _has_clause_structure(lower_tokens, i + 2, length(tokens), config)
                if left_has_structure && right_has_structure
                    # "and then" — compound conjunction. Left clause ends at i-1,
                    # right clause starts at i+2 (skip both "and" and "then").
                    push!(splits, (i - 1, i + 2))
                    push!(_consumed, i)
                    push!(_consumed, i + 1)
                end
            end
        end
    end

    # Main pass — handle remaining conjunctions (not consumed by compound pass)
    for i in 2:(length(tokens) - 1)
        i in _consumed && continue  # already handled as part of compound pair

        tok = lower_tokens[i]

        # GRUG: Hard split conjunctions — split if right side has
        # question or command structure.
        if tok in config.split_conjunctions
            # GRUG v8.2-coherence-fix: ARITHMETIC CONTEXT GUARD.
            # If the conjunction word is also an arithmetic operator
            # (e.g., "plus" in "3 plus 4") and appears between two
            # number-like tokens, it's arithmetic — NOT a clause
            # conjunction. Suppress the split to preserve math bindings.
            if _is_arithmetic_context(lower_tokens, i)
                continue
            end
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens), config)
            if right_has_structure
                # Left clause ends at i-1, right clause starts at i+1
                # (skip just the conjunction token itself).
                push!(splits, (i - 1, i + 1))
            end
            continue
        end

        # GRUG: "and" — special case. Only split if BOTH sides have
        # independent clause structure (question/command markers).
        # NOTE: "and then" is already handled above (compound conjunction).
        # This branch handles standalone "and" like "what is X and what is Y".
        if tok == config.context_conjunction
            left_has_structure = _has_clause_structure(lower_tokens, 1, i - 1, config)
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens), config)
            if left_has_structure && right_has_structure
                push!(splits, (i - 1, i + 1))
            end
            continue
        end
    end

    isempty(splits) && return [input_text]

    # GRUG: Build clause strings from split boundaries.
    # Each split is (left_end, right_start) — tokens[left_end+1..right_start-1]
    # are the conjunction(s) to discard.
    # Sort by left_end to process left-to-right.
    unique_sorted = sort(unique(splits), by = s -> s[1])
    clauses = String[]
    prev = 1
    for (left_end, right_start) in unique_sorted
        # Left clause: tokens[prev:left_end]
        if left_end >= prev
            clause = join(tokens[prev:left_end], " ")
            clause = strip(clause)
            !isempty(clause) && push!(clauses, clause)
        end
        prev = right_start
    end
    # GRUG: Don't forget the last clause!
    if prev <= length(tokens)
        clause = join(tokens[prev:end], " ")
        clause = strip(clause)
        !isempty(clause) && push!(clauses, clause)
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
    _has_clause_structure(lower_tokens, start_idx, end_idx, config) -> Bool

Check if the token range [start_idx, end_idx] contains question or command
markers that indicate independent clause structure. Used to decide whether
a conjunction should trigger a split.

Uses config.expanded_command_markers (which includes inflected forms)
instead of just the stem forms. So "calculates" matches "calculate".
"""
function _has_clause_structure(lower_tokens::Vector{String},
                                start_idx::Int,
                                end_idx::Int,
                                config::DecomposerConfig)::Bool
    for i in start_idx:end_idx
        if i < 1 || i > length(lower_tokens)
            continue
        end
        tok = lower_tokens[i]
        if tok in config.question_markers || tok in config.expanded_command_markers
            return true
        end
    end
    return false
end

# ==============================================================================
# INTERNAL: COMMA-BASED CLAUSE SPLITTING
# ==============================================================================

"""
    _split_on_comma_clauses(input_text, config) -> Vector{String}

Split the input at comma boundaries where both sides look like independent
questions or commands. This catches: "what is X, what is Y, what is Z" —
a common compound pattern that lacks explicit conjunctions.

Comma splitting is tried LAST (after conjunctions and question markers)
because commas are ambiguous: "bread, butter, and cheese" is ONE subject,
but "what is X, what is Y" is TWO. We only split when both sides have
clause structure (question/command markers).
"""
function _split_on_comma_clauses(input_text::String, config::DecomposerConfig)::Vector{String}
    # GRUG: Only try if there are at least 1 comma.
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
                # GRUG v10: Use enhanced lookahead that checks past conjunction
                # connectors like "and", "or", "but" after the comma.
                # "what is X, and what is Y" now correctly splits.
                if _comma_lookahead_clause_check(lower_tokens, tok_idx + 1, config)
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
# INTERNAL: SIGIL-BOUNDARY SPLITTING (Strategy 4)
# ==============================================================================

#=
    _split_on_sigil_boundaries(input_text, config) -> Vector{String}

    GRUG: When input mixes arithmetic expressions with natural-language
    questions, the two are fundamentally different subjects. The arithmetic
    expression belongs to the ArithmeticEngine, the question belongs to
    the general scan. They should be split.

    Detection heuristic:
      - Find spans of the input that contain arithmetic operators (+, -, *, /, =)
        between digits. These are arithmetic zones.
      - Find spans that contain sigil markers (|, @, #, $, %) followed by
        alphanumeric tokens. These are sigil zones.
      - If both an arithmetic/sigil zone AND a natural-language zone exist,
        split between them.

    Example splits:
      "describe gravity 2+3 what is fire" → ["describe gravity", "2+3", "what is fire"]
      "what is 5*7 and also explain black holes" → ["5*7", "what is and also explain black holes"]
      Actually: conjunctions should catch the "and also" above. The sigil
      split is for cases where there's NO conjunction — the arithmetic just
      sits next to a question with no explicit boundary word.
      "compute 3*4+1 explain photosynthesis" → ["3*4+1", "explain photosynthesis"]

    We also split at "explain", "describe" etc. if they follow an arithmetic
    zone — the command marker starts a new clause.
=#

# GRUG: Regex pattern for detecting arithmetic expressions.
# Matches sequences like: 2+3, 5*7, 12/4, 3-1, 2+3*4, x=5
const _ARITH_PATTERN = r"\d+[+\-*/]\d+([+\-*/]\d+)*"

# GRUG v8.2-coherence-fix: Arithmetic conjunction words — split conjunction
# words that also serve as arithmetic operators. When one of these words
# appears BETWEEN two number-like tokens, it's arithmetic (not a clause
# conjunction) and must NOT be split. Without this guard, "what is 3 plus 4"
# decomposes into ["what is 3", "4"], destroying the math binding chain.
const _ARITH_CONJUNCTION_WORDS = Set([
    "plus",     # "3 plus 4" = arithmetic, "cats plus dogs" = conjunction
    "minus",    # "5 minus 2" = arithmetic
    "times",    # "3 times 7" = arithmetic
    "divided",  # "10 divided by 2" = arithmetic
    "multiplied", # "4 multiplied by 3" = arithmetic
    "added",    # "2 added to 5" = arithmetic
    "subtracted", # "8 subtracted from 10" = arithmetic
])

# GRUG v8.2-coherence-fix: Check if a token looks like a number.
# Covers: "3", "42", "3.14", "-5", number-words ("three", "seven").
const _NUMBER_WORD_SET = Set([
    "zero", "one", "two", "three", "four", "five",
    "six", "seven", "eight", "nine", "ten",
    "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen", "twenty",
    "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety",
    "hundred", "thousand", "million", "billion"
])

function _looks_like_number(tok::AbstractString)::Bool
    isempty(tok) && return false
    # Pure numeric (possibly with sign or decimal point)
    if occursin(r"^[+-]?\d+(\.\d+)?$", tok)
        return true
    end
    # Number word
    if lowercase(tok) in _NUMBER_WORD_SET
        return true
    end
    return false
end

# GRUG v8.2-coherence-fix: Check if a conjunction at position i is acting
# as an arithmetic operator between numbers. Returns true when the split
# should be SUPPRESSED (i.e., the word is arithmetic, not a conjunction).
function _is_arithmetic_context(lower_tokens::Vector{String}, i::Int)::Bool
    tok = lower_tokens[i]
    # Only check words that are both conjunctions AND arithmetic operators
    if !(tok in _ARITH_CONJUNCTION_WORDS)
        return false
    end
    # Check left neighbor: is it a number?
    left_is_num = (i > 1) && _looks_like_number(lower_tokens[i - 1])
    # Check right neighbor: is it a number? (skip "by", "to", "from" after "divided"/"added"/"subtracted")
    right_idx = i + 1
    # Skip prepositions: "divided by 4", "added to 5", "subtracted from 10"
    if right_idx <= length(lower_tokens) && lowercase(lower_tokens[right_idx]) in ("by", "to", "from")
        right_idx += 1
    end
    right_is_num = (right_idx <= length(lower_tokens)) && _looks_like_number(lower_tokens[right_idx])
    return left_is_num && right_is_num
end

# GRUG: Regex pattern for sigil-class tokens.
# Matches: |word|, @word, #word, $word, %word%
const _SIGIL_PATTERN = r"[|@#$%][\w]+[|%]?|\|[\w]+\|"

"""
    _split_on_sigil_boundaries(input_text, config) -> Vector{String}

Split at boundaries between arithmetic/sigil zones and natural-language zones.
Only splits when BOTH zones are present. If the input is purely arithmetic
or purely natural-language, returns [input_text].
"""
function _split_on_sigil_boundaries(input_text::String, config::DecomposerConfig)::Vector{String}
    tokens = split(input_text)
    length(tokens) < 3 && return [input_text]  # GRUG: need at least 3 tokens to have 2 zones

    lower_tokens = [lowercase(replace(t, r"[,;.!?:]"=> "")) for t in tokens]

    # GRUG: Classify each token as arithmetic, sigil, or natural-language.
    # A token is arithmetic if it matches the arithmetic pattern.
    # A token is sigil if it matches the sigil pattern.
    # Everything else is natural-language.
    token_zones = Symbol[]  # :arith, :sigil, :lang for each token
    for tok in tokens
        if occursin(_ARITH_PATTERN, tok)
            push!(token_zones, :arith)
        elseif occursin(_SIGIL_PATTERN, tok)
            push!(token_zones, :sigil)
        else
            push!(token_zones, :lang)
        end
    end

    # GRUG: Find contiguous zones. A zone is a maximal run of same-type tokens.
    # We treat :arith and :sigil as the same type (:special) for splitting.
    # Build a list of (zone_type, start_idx, end_idx).
    zones = Tuple{Symbol, Int, Int}[]
    if isempty(token_zones)
        return [input_text]
    end

    current_type = token_zones[1] in (:arith, :sigil) ? :special : :lang
    zone_start = 1
    for i in 2:length(token_zones)
        tok_type = token_zones[i] in (:arith, :sigil) ? :special : :lang
        if tok_type != current_type
            push!(zones, (current_type, zone_start, i - 1))
            current_type = tok_type
            zone_start = i
        end
    end
    push!(zones, (current_type, zone_start, length(token_zones)))  # last zone

    # GRUG: We need at least one :special zone and one :lang zone to split.
    has_special = any(z -> z[1] == :special, zones)
    has_lang = any(z -> z[1] == :lang, zones)
    if !has_special || !has_lang
        return [input_text]  # all one type, no sigil boundary
    end

    # GRUG v8.1-coherence-fix: MERGE lang+arith zones when the arithmetic
    # is the OBJECT of a question, not a separate subject.
    # "what is 2+2" should NOT be split into "what is" + "2+2" — the
    # arithmetic IS the question's answer target, not an independent subject.
    # Heuristic: if a :lang zone immediately precedes an :arith zone, and
    # the lang zone CONTAINS a question marker (what/who/how/is/etc.)
    # or a command marker (calculate/compute/etc.), the arith zone is
    # likely the object of that question/command — merge them.
    # After merging, mark the merged zone as :question_arith so the
    # multiple-marker splitter knows NOT to break it apart.
    merged_zones = Tuple{Symbol, Int, Int}[]
    i = 1
    while i <= length(zones)
        zt_curr, s_curr, e_curr = zones[i]
        if zt_curr == :lang && i < length(zones)
            zt_next, s_next, e_next = zones[i+1]
            if zt_next == :special
                # Check if the lang zone contains any question/command marker
                has_marker = any(ti -> lower_tokens[ti] in config.question_markers ||
                                       lower_tokens[ti] in config.expanded_command_markers,
                                s_curr:e_curr)
                if has_marker
                    # Merge: lang zone absorbs the following arith zone.
                    # Mark as :question_arith so the multiple-marker splitter
                    # knows to keep this zone intact — "what is 2+2" is ONE
                    # subject, not two.
                    push!(merged_zones, (:question_arith, s_curr, e_next))
                    i += 2  # skip both zones
                    continue
                end
            end
        end
        push!(merged_zones, zones[i])
        i += 1
    end
    zones = merged_zones

    # GRUG: We also check that the :lang zone has clause structure.
    # "compute 2+3 compute 4*5" should split at the second "compute".
    # But "2+3 and 4*5" might be all arithmetic (no lang clause structure).
    # We split at zone boundaries AND at command/question markers within lang zones.
    clauses = String[]
    for (zone_type, start_idx, end_idx) in zones
        zone_text = strip(join(tokens[start_idx:end_idx], " "))
        if isempty(zone_text)
            continue
        end

        # GRUG: For lang zones, check if they contain multiple command/question
        # markers that should be split further. Example:
        # "explain X describe Y" → split at "describe" because it's a command marker.
        # GRUG v8.1-coherence-fix: :question_arith zones (e.g. "what is 2+2")
        # are NEVER split by markers — the arithmetic is the object of the
        # question, and splitting "what is" from "2+2" breaks arithmetic binding.
        if zone_type == :question_arith
            push!(clauses, zone_text)
            continue
        end
        if zone_type == :lang && end_idx - start_idx >= 2
            # Check for multiple command/question markers in this lang zone
            marker_positions = Int[]
            for ti in start_idx:end_idx
                if lower_tokens[ti] in config.expanded_command_markers || lower_tokens[ti] in config.question_markers
                    push!(marker_positions, ti)
                end
            end
            if length(marker_positions) >= 2
                # Multiple markers in the lang zone — split at each marker.
                prev = start_idx
                for mp in marker_positions
                    if mp > prev
                        sub_clause = strip(join(tokens[prev:mp-1], " "))
                        !isempty(sub_clause) && push!(clauses, sub_clause)
                    end
                    prev = mp
                end
                # Last part
                if prev <= end_idx
                    sub_clause = strip(join(tokens[prev:end_idx], " "))
                    !isempty(sub_clause) && push!(clauses, sub_clause)
                end
                continue
            end
        end

        push!(clauses, zone_text)
    end

    return isempty(clauses) ? [input_text] : clauses
end


# ==============================================================================
# MLP-ASSISTED DECOMPOSITION (Strategy 5 — optional, called from Main.jl)
# ==============================================================================

#=
    decompose_input_mlp(input_text, config; mlp_directive_quality, mlp_novelty) -> Vector{DecomposedSubSubject}

    GRUG: The EphemeralMLP knows things. Its directive_quality head tells us
    how confident the MLP is that the input has a single clear directive. When
    directive_quality is LOW, the MLP is confused — the input probably has
    multiple directives that should be split. When novelty is HIGH, the input
    contains unfamiliar patterns that might mask compound structure.

    This function is called by Main.jl AFTER the standard decompose_input()
    returns a singleton. If the MLP signals suggest compound structure that
    the heuristics missed, we do a more aggressive re-decomposition.

    MLP signals used:
      - directive_quality: 0-1 score. Below MLP_COMPOUND_THRESHOLD → try harder.
      - novelty: 0-1 score. Above MLP_NOVELTY_COMPOUND_THRESHOLD → novelty
        may be hiding compound structure.

    When MLP suggests compound but heuristics found nothing, we use a
    fallback strategy: split at EVERY conjunction-like word (broader than
    split_conjunctions) and at every punctuation boundary. This is aggressive
    and may over-split, but over-splitting is better than under-splitting
    when the MLP is confident the input is compound.

    CANCER PREVENTION:
      - MLP_COMPOUND_THRESHOLD is high (0.35) — only triggers when MLP is
        genuinely unsure about the directive.
      - MLP_NOVELTY_COMPOUND_THRESHOLD is high (0.70) — only triggers when
        novelty is very high.
      - Both thresholds must be met (AND, not OR) for the aggressive split.
      - The aggressive split still requires clause structure on both sides.
      - Max 4 sub-subjects from MLP-assisted decomposition.
=#

const MLP_COMPOUND_THRESHOLD = 0.35
const MLP_NOVELTY_COMPOUND_THRESHOLD = 0.70
const MLP_COMPOUND_MAX_PARTS = 4

# GRUG: Broader set of conjunction-like words for aggressive MLP-assisted splitting.
# Includes all split_conjunctions plus softer connectors.
const _MLP_AGGRESSIVE_CONJUNCTIONS = Set([
    "and", "or", "but", "also", "then", "plus", "while", "whilst",
    "additionally", "furthermore", "moreover", "besides", "likewise",
    "however", "yet", "nevertheless", "nonetheless", "alternatively",
    "instead", "since", "unless", "except", "independently", "separately",
    # Softer connectors not in split_conjunctions:
    "with", "without", "along", "including", "aside", "besides"
])

"""
    decompose_input_mlp(input_text; kwargs...) -> Vector{DecomposedSubSubject}

MLP-assisted decomposition. Called by Main.jl when the standard decompose_input()
returns a singleton but the MLP signals suggest the input is compound.

Kwargs:
  - mlp_directive_quality: Float64 — EphemeralMLP head 1 score (0-1)
  - mlp_novelty: Float64 — EphemeralMLP novelty score (0-1)
  - config: DecomposerConfig — decomposer config (defaults to runtime config)

Returns decomposed sub-subjects. If MLP signals don't suggest compound,
returns the standard singleton result.
"""
function decompose_input_mlp(input_text::String;
# REMINDER: ANTIMATCH REMOVED. SIGILS IN TRIPLES. HOPFIELD REMOVED.
                             mlp_directive_quality::Float64 = 1.0,
                             mlp_novelty::Float64 = 0.0,
                             config::DecomposerConfig = get_config())::Vector{DecomposedSubSubject}
    # GRUG: First check — do MLP signals even suggest compound?
    if mlp_directive_quality >= MLP_COMPOUND_THRESHOLD
        # MLP is confident about the directive. Not compound. Trust it.
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end
    if mlp_novelty < MLP_NOVELTY_COMPOUND_THRESHOLD
        # Novelty is not high enough to warrant aggressive splitting.
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # GRUG: MLP says "I'm confused AND this is novel." That's a strong signal
    # that the input is compound. Try aggressive decomposition.

    # Strategy: split at EVERY conjunction-like word in the broader set,
    # requiring only that the right side has clause structure (not both sides).
    tokens = split(input_text)
    length(tokens) < 4 && return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]

    lower_tokens = [lowercase(replace(t, r"[,;.!?:]"=> "")) for t in tokens]

    splits = Tuple{Int,Int}[]  # (left_end, right_start)
    for i in 2:(length(tokens) - 1)
        tok = lower_tokens[i]
        if tok in _MLP_AGGRESSIVE_CONJUNCTIONS
            # Aggressive: only check right side for clause structure
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens), config)
            if right_has_structure
                push!(splits, (i - 1, i + 1))
            end
        end
    end

    # Also try splitting at comma boundaries with clause structure on right
    comma_positions = findall(c -> c == ',', input_text)
    if !isempty(comma_positions)
        for (tok_idx, tok) in enumerate(tokens)
            if endswith(tok, ",") && tok_idx < length(tokens)
                next_tok = lower_tokens[tok_idx + 1]
                if next_tok in config.question_markers || next_tok in config.expanded_command_markers
                    push!(splits, (tok_idx, tok_idx + 1))
                end
            end
        end
    end

    isempty(splits) && return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]

    # Build clauses from splits
    unique_sorted = sort(unique(splits), by = s -> s[1])
    clauses = String[]
    prev = 1
    for (left_end, right_start) in unique_sorted
        if left_end >= prev
            clause = strip(join(tokens[prev:left_end], " "))
            !isempty(clause) && push!(clauses, clause)
        end
        prev = right_start
    end
    if prev <= length(tokens)
        clause = strip(join(tokens[prev:end], " "))
        !isempty(clause) && push!(clauses, clause)
    end

    # GRUG: Cap at MLP_COMPOUND_MAX_PARTS to prevent over-splitting.
    if length(clauses) > MLP_COMPOUND_MAX_PARTS
        # Merge the last few clauses
        merged_ending = join(clauses[MLP_COMPOUND_MAX_PARTS:end], " ")
        clauses = vcat(clauses[1:MLP_COMPOUND_MAX_PARTS-1], [strip(merged_ending)])
    end

    # If only one non-empty clause, it's still a singleton
    non_empty = filter(c -> !isempty(strip(c)), clauses)
    if length(non_empty) <= 1
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # Build DecomposedSubSubject array
    result = DecomposedSubSubject[]
    for (i, clause) in enumerate(non_empty)
        clause_text = strip(clause)
        isempty(clause_text) && continue
        group_id = "mp_$i"
        role = i == 1 ? :primary : :support
        push!(result, DecomposedSubSubject(clause_text, group_id, role, i))
    end

    return isempty(result) ? [DecomposedSubSubject(strip(input_text), "", :singleton, 1)] : result
end


# ==============================================================================
# ENHANCED COMMA-CLAUSE SPLITTING (v10 improvement)
# ==============================================================================

# GRUG: The existing _split_on_comma_clauses only checks the token IMMEDIATELY
# after the comma. But "what is X, and also what is Y" has "and" after the comma,
# not a question marker. The enhanced version looks ahead past "and"/"or"/"but"
# after the comma to find the actual clause-starting marker.

# This is a helper that _split_on_comma_clauses now uses.
# We patch the existing function rather than rewriting it.

"""
    _comma_lookahead_clause_check(lower_tokens, after_comma_idx, config) -> Bool

Check if the token after a comma starts a new independent clause,
with lookahead past conjunction connectors. "what is X, and what is Y"
→ the comma's next token is "and", but the token AFTER "and" is "what"
(question marker). This should split.

Looks ahead up to 2 tokens past a conjunction connector.
"""
function _comma_lookahead_clause_check(lower_tokens::Vector{String},
                                       after_comma_idx::Int,
                                       config::DecomposerConfig)::Bool
    n = length(lower_tokens)
    if after_comma_idx > n
        return false
    end

    first_tok = lower_tokens[after_comma_idx]

    # Direct check: the token right after the comma is a marker
    if first_tok in config.question_markers || first_tok in config.expanded_command_markers
        return true
    end

    # Lookahead: the token after comma is a conjunction, check the next token
    conjunction_connectors = ["and", "or", "but", "also", "then", "plus"]
    if first_tok in conjunction_connectors && after_comma_idx + 1 <= n
        next_tok = lower_tokens[after_comma_idx + 1]
        if next_tok in config.question_markers || next_tok in config.expanded_command_markers
            return true
        end
    end

    # Lookahead 2: "and also what" — conjunction + conjunction + marker
    if first_tok in conjunction_connectors && after_comma_idx + 2 <= n
        second_tok = lower_tokens[after_comma_idx + 1]
        third_tok = lower_tokens[after_comma_idx + 2]
        if second_tok in conjunction_connectors &&
           (third_tok in config.question_markers || third_tok in config.expanded_command_markers)
            return true
        end
    end

    return false
end

# ==============================================================================
# CONFIG MUTATION — runtime editing via /decomposer CLI
# ==============================================================================
#
# GRUG say: SPECIMEN OWNS THE CONJUNCTIONS, but OPERATOR OWNS THE RUNTIME.
# These functions mutate _RUNTIME_CONFIG in place. They are called by the
# /decomposer CLI command in Main.jl. Every mutation:
#   1. Validates input (no empty strings, no duplicates where forbidden)
#   2. Mutates the _RUNTIME_CONFIG Ref
#   3. Returns a human-readable success string
#   4. Throws ArgumentError on invalid input (caller catches and hard-warns)
#
# NO SILENT FAILURES. If something goes wrong, the operator MUST see it.
# If a word is already in the set, that's not an error — it's a no-op with
# a visible "already present" message. The operator needs to KNOW.

"""
    add_split_conjunction!(word) -> String

Add a word to the runtime split_conjunctions set. These are words that
trigger a hard split when the right side has clause structure.
Returns a status message. Throws ArgumentError on empty input.
"""
function add_split_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot add empty string as split conjunction"))
    lock(_CONFIG_LOCK) do
        cfg = _RUNTIME_CONFIG[]
        if word in cfg.split_conjunctions
            return "⚠  '$word' already in split_conjunctions (no change)"
        end
        push!(cfg.split_conjunctions, word)
        _RUNTIME_CONFIG[] = cfg  # re-store (Set mutation may not trigger Ref update)
        return "✅ Added '$word' to split_conjunctions (now $(length(cfg.split_conjunctions)) total)"
    end
end

"""
    remove_split_conjunction!(word) -> String

Remove a word from the runtime split_conjunctions set.
Returns a status message. Throws ArgumentError if word not present.
"""
function remove_split_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot remove empty string from split conjunctions"))
    lock(_CONFIG_LOCK) do
        cfg = _RUNTIME_CONFIG[]
        if !(word in cfg.split_conjunctions)
            throw(ArgumentError("'$word' not in split_conjunctions — cannot remove what isn't there"))
        end
        delete!(cfg.split_conjunctions, word)
        _RUNTIME_CONFIG[] = cfg
        return "✅ Removed '$word' from split_conjunctions (now $(length(cfg.split_conjunctions)) total)"
    end
end

"""
    add_compound_pair!(leader, follower) -> String

Add a follower to a compound pair. If the leader doesn't exist yet,
creates the entry. Compound pairs are conjunction pairs like
"and then", "and also" that are treated as a single split point.
Returns a status message. Throws ArgumentError on empty input.
"""
function add_compound_pair!(leader::String, follower::String)::String
    leader = strip(lowercase(leader))
    follower = strip(lowercase(follower))
    isempty(leader) && throw(ArgumentError("Compound pair leader cannot be empty"))
    isempty(follower) && throw(ArgumentError("Compound pair follower cannot be empty"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !haskey(cfg.compound_pairs, leader)
        cfg.compound_pairs[leader] = Set{String}([follower])
        lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
        return "✅ Created compound pair '$leader' → {'$follower'} (new leader)"
    end
    if follower in cfg.compound_pairs[leader]
        return "⚠  '$leader' → '$follower' already in compound_pairs (no change)"
    end
    push!(cfg.compound_pairs[leader], follower)
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Added '$follower' to compound pair '$leader' (now $(length(cfg.compound_pairs[leader])) followers)"
end

"""
    remove_compound_pair!(leader, follower) -> String

Remove a follower from a compound pair. If the leader has no followers
left after removal, the leader entry is deleted entirely.
Throws ArgumentError if the pair doesn't exist.
"""
function remove_compound_pair!(leader::String, follower::String)::String
    leader = strip(lowercase(leader))
    follower = strip(lowercase(follower))
    isempty(leader) && throw(ArgumentError("Compound pair leader cannot be empty"))
    isempty(follower) && throw(ArgumentError("Compound pair follower cannot be empty"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !haskey(cfg.compound_pairs, leader)
        throw(ArgumentError("'$leader' not in compound_pairs — no such leader"))
    end
    if !(follower in cfg.compound_pairs[leader])
        throw(ArgumentError("'$follower' not in compound_pairs['$leader'] — cannot remove what isn't there"))
    end
    delete!(cfg.compound_pairs[leader], follower)
    if isempty(cfg.compound_pairs[leader])
        delete!(cfg.compound_pairs, leader)
        lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
        return "✅ Removed '$follower' from '$leader'; leader had no followers left, removed '$leader' entry entirely"
    end
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Removed '$follower' from compound pair '$leader' (now $(length(cfg.compound_pairs[leader])) followers)"
end

"""
    add_question_marker!(word) -> String

Add a word to the runtime question_markers set (what, who, where, etc.).
Returns a status message. Throws ArgumentError on empty input.
"""
function add_question_marker!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot add empty string as question marker"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if word in cfg.question_markers
        return "⚠  '$word' already in question_markers (no change)"
    end
    push!(cfg.question_markers, word)
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Added '$word' to question_markers (now $(length(cfg.question_markers)) total)"
end

"""
    remove_question_marker!(word) -> String

Remove a word from the runtime question_markers set.
Throws ArgumentError if word not present.
"""
function remove_question_marker!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot remove empty string from question markers"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !(word in cfg.question_markers)
        throw(ArgumentError("'$word' not in question_markers — cannot remove what isn't there"))
    end
    delete!(cfg.question_markers, word)
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Removed '$word' from question_markers (now $(length(cfg.question_markers)) total)"
end

"""
    add_command_marker!(stem, conjugated_forms) -> String

Add a verb stem to command_markers AND all its conjugated forms to
expanded_command_markers. Also records the conjugation rule.
If conjugated_forms is empty, only the stem is added (no conjugation).
Returns a status message. Throws ArgumentError on empty stem.
"""
function add_command_marker!(stem::String, conjugated_forms::Vector{String}=String[])::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Cannot add empty string as command marker"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    was_new = !(stem in cfg.command_markers)
    push!(cfg.command_markers, stem)
    push!(cfg.expanded_command_markers, stem)  # stem itself is always in expanded
    if !isempty(conjugated_forms)
        # GRUG: Store the conjugation rule AND expand all forms
        clean_forms = [strip(lowercase(f)) for f in conjugated_forms if !isempty(strip(f))]
        cfg.conjugation_rules[stem] = clean_forms
        for f in clean_forms
            push!(cfg.expanded_command_markers, f)
        end
    end
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    n_expanded = length(cfg.expanded_command_markers)
    if was_new
        if isempty(conjugated_forms)
            return "✅ Added command marker '$stem' (no conjugation; now $n_expanded expanded markers)"
        else
            return "✅ Added command marker '$stem' with conjugation $(conjugated_forms) (now $n_expanded expanded markers)"
        end
    else
        # Already existed — but may have added new conjugation
        if isempty(conjugated_forms)
            return "⚠  '$stem' already in command_markers (no change)"
        else
            return "✅ Updated conjugation for '$stem' → $(conjugated_forms) (now $n_expanded expanded markers)"
        end
    end
end

"""
    remove_command_marker!(stem) -> String

Remove a verb stem from command_markers AND all its conjugated forms
from expanded_command_markers. Also removes the conjugation rule.
Throws ArgumentError if stem not present.
"""
function remove_command_marker!(stem::String)::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Cannot remove empty string from command markers"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !(stem in cfg.command_markers)
        throw(ArgumentError("'$stem' not in command_markers — cannot remove what isn't there"))
    end
    delete!(cfg.command_markers, stem)
    delete!(cfg.expanded_command_markers, stem)
    # GRUG: Also remove all conjugated forms for this stem
    if haskey(cfg.conjugation_rules, stem)
        for f in cfg.conjugation_rules[stem]
            delete!(cfg.expanded_command_markers, f)
        end
        delete!(cfg.conjugation_rules, stem)
    end
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Removed command marker '$stem' and its conjugated forms (now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    add_conjugation_rule!(stem, forms) -> String

Add or replace a conjugation rule for a verb stem. Also updates
expanded_command_markers with the new forms. The stem MUST already
be in command_markers — you can't conjugate what you don't mark.
Throws ArgumentError if stem not in command_markers or forms empty.
"""
function add_conjugation_rule!(stem::String, forms::Vector{String})::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Conjugation rule stem cannot be empty"))
    isempty(forms) && throw(ArgumentError("Conjugation rule must have at least one form"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !(stem in cfg.command_markers)
        throw(ArgumentError("'$stem' not in command_markers — add it with /decomposer addCommand first"))
    end
    # GRUG: Remove old forms from expanded if they existed
    if haskey(cfg.conjugation_rules, stem)
        for old_f in cfg.conjugation_rules[stem]
            delete!(cfg.expanded_command_markers, old_f)
        end
    end
    # Add new forms
    clean_forms = [strip(lowercase(f)) for f in forms if !isempty(strip(f))]
    isempty(clean_forms) && throw(ArgumentError("All conjugation forms were empty after trimming"))
    cfg.conjugation_rules[stem] = clean_forms
    for f in clean_forms
        push!(cfg.expanded_command_markers, f)
    end
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Set conjugation rule '$stem' → $clean_forms (now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    remove_conjugation_rule!(stem) -> String

Remove a conjugation rule for a verb stem. Also removes the inflected
forms from expanded_command_markers. The stem itself stays in
command_markers and expanded_command_markers.
Throws ArgumentError if no rule exists for this stem.
"""
function remove_conjugation_rule!(stem::String)::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Conjugation rule stem cannot be empty"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    if !haskey(cfg.conjugation_rules, stem)
        throw(ArgumentError("No conjugation rule for '$stem' — cannot remove what isn't there"))
    end
    for f in cfg.conjugation_rules[stem]
        delete!(cfg.expanded_command_markers, f)
    end
    delete!(cfg.conjugation_rules, stem)
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Removed conjugation rule for '$stem' (stem still in command_markers; now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    set_context_conjunction!(word) -> String

Set the context conjunction (default: "and"). This is the conjunction
that only triggers a split when BOTH sides have clause structure.
Throws ArgumentError on empty input.
"""
function set_context_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Context conjunction cannot be empty"))
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    old = cfg.context_conjunction
    cfg = DecomposerConfig(  # Reconstruct — context_conjunction is immutable in struct
        cfg.split_conjunctions,
        cfg.compound_pairs,
        word,  # new context conjunction
        cfg.question_markers,
        cfg.command_markers,
        cfg.expanded_command_markers,
        cfg.conjugation_rules
    )
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = cfg end
    return "✅ Context conjunction changed: '$old' → '$word'"
end

"""
    reset_config!() -> String

Reset the runtime config to built-in defaults. NO SILENT SURPRISE:
this is a hard reset, and the operator is told exactly what they lost.
"""
function reset_config!()::String
    old_n = lock(_CONFIG_LOCK) do; length(_RUNTIME_CONFIG[].split_conjunctions) end
    lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] = DEFAULT_CONFIG end
    new_n = length(DEFAULT_CONFIG.split_conjunctions)
    return "✅ Decomposer config reset to built-in defaults (was $old_n split_conjunctions, now $new_n)"
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

"""
    config_status_string() -> String

Multi-line formatted string showing the full runtime decomposer config.
Used by /decomposer status command. NO SILENT ANYTHING — every field
is shown, even if empty.
"""
function config_status_string()::String
    cfg = lock(_CONFIG_LOCK) do; _RUNTIME_CONFIG[] end
    lines = String[]

    push!(lines, "╔══════════════════════════════════════════════════════════╗")
    push!(lines, "║            ✂️  DECOMPOSER CONFIG STATUS                  ║")
    push!(lines, "╠══════════════════════════════════════════════════════════╣")

    # Split conjunctions
    push!(lines, "  SPLIT CONJUNCTIONS ($(length(cfg.split_conjunctions))):")
    push!(lines, "    $(join(sort(collect(cfg.split_conjunctions)), ", "))")

    # Compound pairs
    push!(lines, "  COMPOUND PAIRS ($(length(cfg.compound_pairs)) leaders):")
    for (leader, followers) in sort(collect(cfg.compound_pairs), by=x->x[1])
        push!(lines, "    '$leader' → $(join(sort(collect(followers)), ", "))")
    end

    # Context conjunction
    push!(lines, "  CONTEXT CONJUNCTION: '$(cfg.context_conjunction)'")

    # Question markers
    push!(lines, "  QUESTION MARKERS ($(length(cfg.question_markers))):")
    push!(lines, "    $(join(sort(collect(cfg.question_markers)), ", "))")

    # Command markers (stems)
    push!(lines, "  COMMAND MARKERS (stems: $(length(cfg.command_markers)), expanded: $(length(cfg.expanded_command_markers))):")
    push!(lines, "    Stems: $(join(sort(collect(cfg.command_markers)), ", "))")

    # Conjugation rules
    push!(lines, "  CONJUGATION RULES ($(length(cfg.conjugation_rules))):")
    for (stem, forms) in sort(collect(cfg.conjugation_rules), by=x->x[1])
        push!(lines, "    '$stem' → $(join(forms, ", "))")
    end

    push!(lines, "╚══════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end

end # module
