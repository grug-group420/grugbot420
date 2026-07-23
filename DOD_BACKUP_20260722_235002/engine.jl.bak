# Engine.jl
# ==============================================================================
# !!! GRUG REMINDER — RELATIONAL TRIPLES CAN USE SIGILS !!!
# ------------------------------------------------------------------------------
# A RelationalTriple's subject / relation / object fields may contain sigil
# tokens (e.g. "&n", "&word", "&noun", or specimen-defined macros). Relational
# patterns are NOT plain literal text only — they can carry typed sigil holes
# just like patterns do. Anything that builds, matches, mutates, inhibits, or
# serializes RelationalTriples MUST account for sigils (resolve via
# SigilRegistry where appropriate). Do not assume triple fields are always
# literal words. See SigilRegistry.jl / SigilPromoter.jl.
# ==============================================================================
using Base.Threads: Atomic, atomic_add!, ReentrantLock
using JSON
using Random # GRUG: Need random to roll active node limits and scan modes!

# GRUG: Bring the Pattern Scanner into the cave!
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

# GRUG: AIMLNodeSystem removed in v8.12 — scaffold tracking layer had no
# output actuator. The stochastic rule board (ORCHESTRATION_RULES, formerly
# AIML_DROP_TABLE) remains in this file.

# GRUG: Bring the Action+Tone Predictor (pre-vote arousal tuning and confidence weighting)!
# GRUG: Guard against double-include if ActionTonePredictor already loaded by caller.
if !isdefined(@__MODULE__, :ActionTonePredictor)
    include("ActionTonePredictor.jl")
    using .ActionTonePredictor
end

# GRUG v7.21b-2: TonalJudge — token bag + common-sense judge that picks
# scaffold frame hints. Sits between predictor and scaffold. b-2 is
# plumbing-only (judge runs and surfaces [FRAME=...] but does not yet
# alter synthesize_voice_reply — that's b-3).
if !isdefined(@__MODULE__, :TonalJudge)
    include("TonalJudge.jl")
    using .TonalJudge
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

# GRUG: SigilRegistry — Stage 1 sigil kernel. Same defensive include pattern
# as siblings above so engine.jl runs standalone (test_comprehensive etc.)
# AND inside GrugBot420.jl (where it's already loaded by the package init).
if !isdefined(@__MODULE__, :SigilRegistry)
    include("SigilRegistry.jl")
    using .SigilRegistry
end

# GRUG: SigilPromoter — Stage 1.5a front-door input promoter. Two-layer:
# Layer 1 thesaurus canonicalization ("two plus two" -> "2 + 2"), Layer 2
# registry shape promotion ("2 + 2" -> "&n &op &n"). MUST come after
# SigilRegistry because it does `using ..SigilRegistry`.
if !isdefined(@__MODULE__, :SigilPromoter)
    include("SigilPromoter.jl")
    using .SigilPromoter
end

# GRUG: ArithmeticEngine — Stage 2 arithmetic evaluator. Reads the bindings
# that SigilPromoter stashed in task-local storage and actually COMPUTES the
# result (2+2=4, not "Execute the calculation"). MUST come after SigilPromoter
# because it does `using ..SigilPromoter`.
if !isdefined(@__MODULE__, :ArithmeticEngine)
    include("ArithmeticEngine.jl")
    using .ArithmeticEngine
end

# GRUG: ActionEngine — Stage 2b dynamic sigil action evaluator. Reads
# the node's action_callback from json_data, fetches the registered
# compute function, and computes the result from sigil bindings. This
# is the DYNAMIC answer: one sigil node computes infinite instances.
# Factorial, square root, fibonacci — anything that takes &n and produces
# an answer. MUST come after SigilPromoter because it does `using ..SigilPromoter`.
if !isdefined(@__MODULE__, :ActionEngine)
    include("ActionEngine.jl")
    using .ActionEngine
end

# GRUG: InputDecomposer — v7.23 compound-query decomposition. Engine.jl
# references InputDecomposer.InputChunk in _match_to_chunks signatures, so it
# MUST be loaded before those function definitions are compiled. Same defensive
# include pattern as siblings above.
if !isdefined(@__MODULE__, :InputDecomposer)
    include("InputDecomposer.jl")
    using .InputDecomposer
end

# ==============================================================================
# FRONT-DOOR SIGIL TABLE (Stage 1.5a)
# ==============================================================================
# GRUG: One stable engine-default SigilTable shared by every scan_and_expand
# call. Built once at module init and held const so per-call promotion never
# re-allocates the table. Specimens that want to extend the registry merge
# their entries in via merge_registry! at specimen-load time; the front-door
# promoter still consults THIS table for shape predicates because it is the
# union of engine defaults plus any specimen extensions registered later.
#
# IMPORTANT: this is a SigilTable, which is mutable internally (its dicts
# grow when register_sigil! / merge_registry! is called). We treat the
# binding as const because we never reassign the variable; we only mutate
# the table in place. That matches how the matcher already treats other
# global lobe registries.
const _ENGINE_SIGIL_TABLE::SigilRegistry.SigilTable = SigilRegistry.default_registry()

# GRUG: Promotion bindings handoff. Originally task-local storage, but
# scan_and_expand runs inside a @spawn'd Task (VoteOrchestrator) while
# synthesize_voice_reply runs in a DIFFERENT @spawn'd Task. Julia task-local
# storage does NOT propagate across Task boundaries, so the arithmetic
# engine could never see the bindings — it always got an empty vector.
#
# FIX: Store bindings in a module-level Ref (locked) IN ADDITION to
# task-local storage. The module-level Ref survives task boundaries.
# Task-local storage is still written for backward compat with any code
# that runs in the same task as scan_and_expand.
#
# Stage 1.5a-fix-1 adds _PROMOTION_RAW_KEY: the ORIGINAL user input string,
# preserved verbatim. ATP needs it for tone signals (caps, written-out vs
# symbolic). AIML render needs it to echo back in the user's register.
const _PROMOTION_BINDINGS_KEY::Symbol  = :grugbot420_sigil_promotion_bindings
const _PROMOTION_REWRITTEN_KEY::Symbol = :grugbot420_sigil_promotion_rewritten
const _PROMOTION_RAW_KEY::Symbol       = :grugbot420_sigil_promotion_raw

# GRUG v7.24-BUG5: Module-level promotion bindings that survive Task boundaries.
# scan_and_expand writes these; synthesize_voice_reply reads them. The
# task-local path is a dead end because the orchestrator runs in a
# different @spawn'd Task than the scanner.
const _GLOBAL_PROMOTION_BINDINGS::Base.RefValue{Vector{SigilPromoter.SigilBinding}} = Ref(SigilPromoter.SigilBinding[])
const _GLOBAL_PROMOTION_REWRITTEN::Base.RefValue{String} = Ref("")
const _GLOBAL_PROMOTION_RAW::Base.RefValue{String} = Ref("")
# GRUG v8.14: Pre-expansion raw text — the original user input BEFORE thesaurus
# gate expansion. The expansion appends synonyms which dilute lexical overlap
# (input_coverage denominator grows but overlap doesn't). By storing the
# pre-expansion text, _scan_confidence_for_node can compute overlap against
# BOTH the expanded input AND the original input, taking the max. This mirrors
# the existing dual-input pattern for sigil promotion (v7.55).
const _GLOBAL_RAW_PRE_EXPANSION::Base.RefValue{String} = Ref("")
const _GLOBAL_PROMOTION_LOCK::ReentrantLock = ReentrantLock()

# GRUG v8.1-coherence-fix: PER-GROUP BINDING STASH for multipart sub-scans.
# When a compound input ("what is 2+2 also what is a cat") is decomposed,
# each sub-subject calls scan_and_expand independently. Each call OVERWRITES
# _GLOBAL_PROMOTION_BINDINGS, so by the time synthesize_voice_reply runs for
# the math sub-objective, the bindings are from the LAST sub-scan (cat),
# not the math scan. Result: "Arithmetic: no math bindings this cycle."
#
# Fix: stash bindings per multipart_group in this dict. After each sub-scan,
# the caller stores the bindings under the sub-subject's group_id. Then
# synthesize_voice_reply looks up bindings by the primary_vote's group_id
# BEFORE falling back to the global Ref. This way each sub-objective gets
# its own correct bindings.
const _MULTIPART_GROUP_BINDINGS::Dict{String, Vector{SigilPromoter.SigilBinding}} = Dict{String, Vector{SigilPromoter.SigilBinding}}()
const _MULTIPART_GROUP_REWRITTEN::Dict{String, String} = Dict{String, String}()
const _MULTIPART_GROUP_RAW::Dict{String, String} = Dict{String, String}()
const _MULTIPART_GROUP_LOCK::ReentrantLock = ReentrantLock()

"""
    stash_multipart_bindings!(group_id, bindings, rewritten, raw)

GRUG v8.1-coherence-fix: Store promotion bindings for a specific multipart
group. Called after each sub-scan in the multipart pipeline so the bindings
survive even when subsequent sub-scans overwrite the global Refs.
"""
function stash_multipart_bindings!(group_id::String,
                                    bindings::Vector{SigilPromoter.SigilBinding},
                                    rewritten::String,
                                    raw::String)
    isempty(group_id) && return nothing  # no group, don't stash
    lock(_MULTIPART_GROUP_LOCK) do
        _MULTIPART_GROUP_BINDINGS[group_id] = bindings
        _MULTIPART_GROUP_REWRITTEN[group_id] = rewritten
        _MULTIPART_GROUP_RAW[group_id] = raw
    end
    return nothing
end

"""
    clear_multipart_bindings!()

GRUG v8.1-coherence-fix: Clear the per-group binding stash. Called at the
start of each mission cycle so stale bindings from previous cycles don't
leak into the current one.
"""
function clear_multipart_bindings!()
    lock(_MULTIPART_GROUP_LOCK) do
        empty!(_MULTIPART_GROUP_BINDINGS)
        empty!(_MULTIPART_GROUP_REWRITTEN)
        empty!(_MULTIPART_GROUP_RAW)
    end
    return nothing
end

"""
    get_multipart_bindings(group_id) -> Vector{SigilPromoter.SigilBinding}

GRUG v8.1-coherence-fix: Look up promotion bindings for a specific multipart
group. Returns empty vector if group has no stashed bindings.
"""
function get_multipart_bindings(group_id::String)::Vector{SigilPromoter.SigilBinding}
    isempty(group_id) && return SigilPromoter.SigilBinding[]
    lock(_MULTIPART_GROUP_LOCK) do
        get(_MULTIPART_GROUP_BINDINGS, group_id, SigilPromoter.SigilBinding[])
    end
end

"""
    get_multipart_rewritten(group_id) -> Union{String,Nothing}
"""
function get_multipart_rewritten(group_id::String)::Union{String,Nothing}
    isempty(group_id) && return nothing
    lock(_MULTIPART_GROUP_LOCK) do
        get(_MULTIPART_GROUP_REWRITTEN, group_id, nothing)
    end
end

"""
    get_multipart_raw(group_id) -> Union{String,Nothing}
"""
function get_multipart_raw(group_id::String)::Union{String,Nothing}
    isempty(group_id) && return nothing
    lock(_MULTIPART_GROUP_LOCK) do
        get(_MULTIPART_GROUP_RAW, group_id, nothing)
    end
end

# GRUG v8.1-coherence-fix: PER-GROUP LOBE STATE STASH for multipart sub-scans.
# score_lobes() determines the winner lobe and passthrough lobes, which
# ephemeral_voice_orchestrator reads to compute lobe_alignment per vote.
# For multipart inputs, each sub-subject may belong to a different lobe
# (math sub-subject → MathLobe, emotional sub-subject → SocialLobe).
# A single global score_lobes call picks ONE winner for all votes, which
# means math-lobe votes get lobe_alignment=0.0 if the emotional lobe won
# globally. This stash lets us compute and store per-group lobe results,
# so each sub-subject's votes get the correct lobe_alignment from their
# own group's scoring.
const _MULTIPART_GROUP_LOBE_STATE::Dict{String, Tuple{Vector, String, Vector{String}}} = Dict{String, Tuple{Vector, String, Vector{String}}}()
# Already under _MULTIPART_GROUP_LOCK (same critical section).

"""
    stash_multipart_lobe_state!(group_id, scores, winner, passthrough)

GRUG v8.1-coherence-fix: Store per-group lobe orchestrator state for
multipart sub-scans. Called by process_mission after score_lobes runs
per multipart group. Takes separate arguments to avoid tuple-nesting
ambiguity that caused BoundsError with the old single-Tuple signature.
"""
function stash_multipart_lobe_state!(group_id::String, scores, winner::String, passthrough::Vector{String})
    isempty(group_id) && return nothing
    lock(_MULTIPART_GROUP_LOCK) do
        _MULTIPART_GROUP_LOBE_STATE[group_id] = (scores, winner, passthrough)
    end
    return nothing
end

"""
    clear_multipart_lobe_states!()

Clear all per-group lobe state stashes. Called at the start of process_mission.
"""
function clear_multipart_lobe_states!()
    lock(_MULTIPART_GROUP_LOCK) do
        empty!(_MULTIPART_GROUP_LOBE_STATE)
    end
    return nothing
end

"""
    get_multipart_lobe_state(group_id) -> (scores, winner, passthrough) or nothing

GRUG v8.1-coherence-fix: Look up lobe orchestrator state for a specific
multipart group. Returns nothing if group has no stashed state.
"""
function get_multipart_lobe_state(group_id::String)::Union{Nothing, Tuple{Vector, String, Vector{String}}}
    isempty(group_id) && return nothing
    lock(_MULTIPART_GROUP_LOCK) do
        get(_MULTIPART_GROUP_LOBE_STATE, group_id, nothing)
    end
end

# GRUG v8.2: PER-GROUP SCOPED MISSION TEXT STASH for multipart sub-objectives.
# When a compound input ("what is 2+2 also what is a cat") is decomposed,
# each sub-subject has its own text that should be used as the mission for
# that sub-objective's AIML payload. Without this, every COMMANDS handler
# receives the FULL compound input as `mission`, so synthesize_voice_reply
# generates a response about the whole input, not just the sub-subject.
# This is the root cause of "Grug only answers one part" — each entry's
# AIML call sees the full question and naturally gravitates toward the
# highest-confidence sub-subject, ignoring the others.
#
# Fix: stash each sub-subject's text under its group_id. The ActionLog
# picks it up and stores it as scoped_mission on each ActionEntry.
# The COMMANDS dispatch loop then passes scoped_mission instead of mission.
const _MULTIPART_GROUP_SCOPED_TEXT::Dict{String, String} = Dict{String, String}()

"""
    stash_multipart_scoped_text!(group_id, scoped_text)

GRUG v8.2: Store the sub-subject text for a specific multipart group.
Called during process_mission decomposition so each sub-objective knows
what part of the input it's actually answering.
"""
function stash_multipart_scoped_text!(group_id::String, scoped_text::String)
    isempty(group_id) && return nothing
    lock(_MULTIPART_GROUP_LOCK) do
        _MULTIPART_GROUP_SCOPED_TEXT[group_id] = scoped_text
    end
    return nothing
end

"""
    get_multipart_scoped_text(group_id) -> String or ""

GRUG v8.2: Look up the sub-subject text for a specific multipart group.
Returns empty string if group has no stashed text (singleton/fallback).

For compound chunk groups like "chk_1_2" (votes from chunks 1 AND 2),
joins the text from each constituent chunk with " and ".
"""
function get_multipart_scoped_text(group_id::String)::String
    isempty(group_id) && return ""
    lock(_MULTIPART_GROUP_LOCK) do
        # Direct lookup first
        text = get(_MULTIPART_GROUP_SCOPED_TEXT, group_id, "")
        if !isempty(text)
            return text
        end
        # GRUG v8.2: Handle compound chunk groups like "chk_1_2" or "chk_1_2_3".
        # These are created by group_votes_by_chunks when votes from multiple
        # chunks overlap. We look up each constituent chunk's text and join them.
        if startswith(group_id, "chk_")
            parts = split(group_id[5:end], "_")
            chunk_texts = String[]
            for p in parts
                idx = tryparse(Int, p)
                isnothing(idx) && continue
                # Try both "chk_X" and "mp_X" naming schemes
                ct = get(_MULTIPART_GROUP_SCOPED_TEXT, "chk_$(idx)", "")
                if isempty(ct)
                    ct = get(_MULTIPART_GROUP_SCOPED_TEXT, "mp_$(idx)", "")
                end
                if !isempty(ct)
                    push!(chunk_texts, ct)
                end
            end
            if !isempty(chunk_texts)
                return join(chunk_texts, " and ")
            end
        end
        # GRUG v8.4: Handle composite multipart+chunk groups like "mp_1_chk_1".
        # These are created by group_votes_by_chunks when it partitions by
        # multipart_group first. The format is "{mp_group}_chk_{chunk_indices}".
        # Look up the multipart group's stashed text (e.g., "mp_1") which was
        # stashed at decompose time by stash_multipart_scoped_text!.
        if occursin("_chk_", group_id)
            # Extract the mp prefix: "mp_1_chk_1" -> "mp_1"
            mp_prefix = group_id[1:findfirst("_chk_", group_id).start - 1]
            ct = get(_MULTIPART_GROUP_SCOPED_TEXT, mp_prefix, "")
            if !isempty(ct)
                return ct
            end
        end
        return ""
    end
end

"""
    clear_multipart_scoped_text!()

GRUG v8.2: Clear all per-group scoped text. Called at the start of
process_mission so stale text from previous cycles doesn't leak.
"""
function clear_multipart_scoped_text!()
    lock(_MULTIPART_GROUP_LOCK) do
        empty!(_MULTIPART_GROUP_SCOPED_TEXT)
    end
    return nothing
end

# GRUG v8.1: Time orientation — same pattern as promotion bindings.
# scan_and_expand writes; synthesize_voice_reply reads across Task boundaries.
const _TIME_ORIENTATION_KEY::Symbol = :grugbot420_time_orientation
const _GLOBAL_TIME_ORIENTATION::Base.RefValue{Tuple{String,Dict{String,Any}}} = Ref(("none", Dict{String,Any}()))

"""
    current_promotion_bindings() -> Vector{SigilPromoter.SigilBinding}

Return the bindings produced by the most recent `scan_and_expand` call.
Reads from the module-level Ref first (survives Task boundaries), then
falls back to task-local storage for backward compat.
"""
function current_promotion_bindings()::Vector{SigilPromoter.SigilBinding}
    # GRUG v7.24-BUG5: Prefer module-level Ref — it survives @spawn.
    global_bindings = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_BINDINGS[]
    end
    if !isempty(global_bindings)
        return global_bindings
    end
    # Fallback: task-local (for code running in same task as scan_and_expand)
    val = get(task_local_storage(), _PROMOTION_BINDINGS_KEY, nothing)
    isnothing(val) && return SigilPromoter.SigilBinding[]
    if !(val isa Vector{SigilPromoter.SigilBinding})
        error("FATAL: task-local promotion bindings have wrong type: $(typeof(val))")
    end
    return val
end

"""
    current_promotion_rewritten() -> Union{String,Nothing}

Return the rewritten input string from the most recent `scan_and_expand`
call. Reads from the module-level Ref first, then falls back to task-local.
"""
function current_promotion_rewritten()::Union{String,Nothing}
    global_rewritten = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_REWRITTEN[]
    end
    if !isempty(global_rewritten)
        return global_rewritten
    end
    return get(task_local_storage(), _PROMOTION_REWRITTEN_KEY, nothing)
end

"""
    current_promotion_raw() -> Union{String,Nothing}

Return the ORIGINAL user input string from the most recent
`scan_and_expand` call on the current task, or `nothing` if no promotion
has run on this task. This is the verbatim input — caps, whitespace,
word-vs-digit, all preserved.

Stage 1.5a-fix-1 added this so:
  - ATP can read user tone signals that promotion strips ("WHAT IS 2+2"
    is angrier than "what is two plus two").
  - AIML render can echo back in the user's register ("two plus two" vs
    "2 + 2"), making replies feel coherent rather than alien.
  - Telemetry can show before/after for diff'ing promotion behaviour.

Pair with `current_promotion_bindings()`: each binding's `.surface` field
gives you the user's raw token for that capture, and `.raw_position`
indexes into the raw token stream.
"""
function current_promotion_raw()::Union{String,Nothing}
    # GRUG: Prefer module-level Ref — it survives @spawn, just like bindings.
    global_raw = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_RAW[]
    end
    if !isempty(global_raw)
        return global_raw
    end
    return get(task_local_storage(), _PROMOTION_RAW_KEY, nothing)
end

"""
    current_time_orientation() -> Tuple{String,Dict{String,Any}}

Return the time orientation extracted from the most recent `scan_and_expand`
call. Returns (orientation_string, metadata_dict). Orientation is one of
"past", "present", "future", or "none" when no time sigil was detected.

Reads from module-level Ref first (survives Task boundaries), then falls
back to task-local storage.
"""
function current_time_orientation()::Tuple{String,Dict{String,Any}}
    global_orient = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_TIME_ORIENTATION[]
    end
    if global_orient[1] != "none"
        return global_orient
    end
    return get(task_local_storage(), _TIME_ORIENTATION_KEY, ("none", Dict{String,Any}()))
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
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
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
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
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

    # GRUG v7.21c-5: noun-question surface forms.
    # `what is fire` already works because `is` is a relational verb. But
    # `tell me about fire` previously produced User Triples: None: `tell` is a
    # query/tone marker, not a semantic relation, and `about` is a preposition.
    # That let the built-in generic `tell me` node beat noun-specific aliases.
    # Preserve the simple adjacency extractor, but first add explicit query
    # relations for common noun-question surfaces so noun-description nodes get
    # the same lock-in as `what is <noun>`.
    for i in 1:length(tokens)
        tok = String(tokens[i])
        if tok == "tell"
            # tell me about fire / tell about fire
            if i + 3 <= length(tokens) && String(tokens[i+1]) == "me" && String(tokens[i+2]) == "about"
                obj = String(tokens[i+3])
                # GRUG v8.17: Stem the object so "atoms" → "atom" in triples
                obj_stemmed = Thesaurus.stem_token(obj)
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj_stemmed != obj ? obj_stemmed : obj))
            elseif i + 2 <= length(tokens) && String(tokens[i+1]) == "about"
                obj = String(tokens[i+2])
                obj_stemmed = Thesaurus.stem_token(obj)
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj_stemmed != obj ? obj_stemmed : obj))
            end
        elseif tok == "describe" && i + 1 <= length(tokens)
            obj = String(tokens[i+1])
            obj_stemmed = Thesaurus.stem_token(obj)
            !isempty(obj) && push!(triples, RelationalTriple("describe", "targets", obj_stemmed != obj ? obj_stemmed : obj))
        elseif tok == "about" && i > 1 && i < length(tokens) && String(tokens[i-1]) == "what"
            obj = String(tokens[i+1])
            obj_stemmed = Thesaurus.stem_token(obj)
            !isempty(obj) && push!(triples, RelationalTriple("what", "about", obj_stemmed != obj ? obj_stemmed : obj))
        end
    end

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
                        # GRUG v8.17: Stem subjects and objects for relational matching.
                        # "you are atoms" → (you, be, atom) instead of (you, be, atoms)
                        # This ensures triples match node patterns and required_relations.
                        subj_stemmed = Thesaurus.stem_token(subj)
                        obj_stemmed  = Thesaurus.stem_token(obj)
                        push!(triples, RelationalTriple(subj_stemmed != subj ? subj_stemmed : subj, tok, obj_stemmed != obj ? obj_stemmed : obj))
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

"""
    screen_input_complexity(signal::Vector{Float64}, triples::Vector{RelationalTriple})::Int
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.

Compute the base selective-scan tier for an input screen from signal length and
relational structure. This is the input-side tier only; `_effective_scan_mode`
may still downgrade it per node pattern length.
"""
function screen_input_complexity(signal::Vector{Float64}, triples::Vector{RelationalTriple})::Int
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    len = length(signal)
    len == 0 && error("!!! FATAL: screen_input_complexity got empty signal! Cannot scan empty input! !!!")

    triple_count = length(triples)

    # Cheap: tiny signal with little/no relational structure.
    if len <= 3 && triple_count == 0
        return 1
    end

    # High-res: long signal or dense relation basket.
    if len > 20 || triple_count >= 4
        return 3
    end

    # Medium: everything between cheap and high-res.
    return 2
end

"""
    _bidirectional_cheap_scan(target::Vector{Float64}, pattern::Vector{Float64}; threshold=0.6, nonjitter=false, jitter_floor=JITTER_CONFIDENCE_FLOOR)

Tier-1 scan wrapper for short node patterns. Runs cheap_scan forward and with
the pattern reversed, fuses the two directional confidences with
big_number_small_number_coherence, and optionally applies post-fusion jitter.
If one direction misses, it contributes `threshold - 0.01`; if both miss, the
forward PatternNotFoundError is rethrown. Empty inputs fail loudly.
"""
function _bidirectional_cheap_scan(target::Vector{Float64}, pattern::Vector{Float64};
                                   threshold::Real=0.6,
                                   nonjitter::Bool=false,
                                   jitter_floor::Real=JITTER_CONFIDENCE_FLOOR)::Tuple{Int, Float64}
    isempty(target) && error("!!! FATAL: _bidirectional_cheap_scan got empty target! !!!")
    isempty(pattern) && error("!!! FATAL: _bidirectional_cheap_scan got empty pattern! !!!")

    miss_contribution = max(0.0, Float64(threshold) - 0.01)

    fwd_idx = 0
    fwd_conf = miss_contribution
    fwd_err = nothing
    fwd_hit = false
    try
        fwd_idx, fwd_conf = cheap_scan(target, pattern; threshold=threshold)
        fwd_hit = true
    catch e
        if e isa PatternNotFoundError
            fwd_err = e
        else
            rethrow(e)
        end
    end

    rev_idx = 0
    rev_conf = miss_contribution
    rev_err = nothing
    rev_hit = false
    try
        rev_idx, rev_conf = cheap_scan(target, reverse(pattern); threshold=threshold)
        rev_hit = true
    catch e
        if e isa PatternNotFoundError
            rev_err = e
        else
            rethrow(e)
        end
    end

    if !fwd_hit && !rev_hit
        throw(fwd_err === nothing ? rev_err : fwd_err)
    end

    fused = big_number_small_number_coherence(Float64(fwd_conf), Float64(rev_conf))
    should_jitter = !nonjitter || fused < Float64(jitter_floor)
    final_conf = should_jitter ? slight_jitter(fused) : fused
    best_idx = fwd_hit ? fwd_idx : rev_idx
    return (best_idx, final_conf)
end

"""
    _effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int

Apply per-node pattern-complexity downgrade to a requested scan tier. Empty
signals keep the requested tier and let the scanner/error path handle them;
short patterns do not pay for expensive scans.
"""
function _effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int
    if base_mode < 1 || base_mode > 3
        error("!!! FATAL: _effective_scan_mode got invalid base_mode=$base_mode; expected 1..3 !!!")
    end
    len = length(node_signal)
    len == 0 && return base_mode
    len <= 3 && return min(base_mode, 1)
    len <= 8 && return min(base_mode, 2)
    return base_mode
end

"""
extract_dynamic_relational_triples(input::String, scan_mode::Int)::Vector{RelationalTriple}
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.

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
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
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
                
                # GRUG v8.17: Stem subjects and objects for relational matching.
                # "you are atoms" → (you, be, atom) instead of (you, be, atoms).
                # Compound subjects/objects: stem each part individually then rejoin.
                # e.g. "large atoms" → "large atom"
                subj_stemmed = join([Thesaurus.stem_token(String(p)) for p in subj_parts], " ")
                obj_stemmed_parts = [Thesaurus.stem_token(String(p)) for p in obj_parts]
                obj_stemmed = join(obj_stemmed_parts, " ")
                
                # GRUG: Add triple if valid
                if !isempty(subj_stemmed) && !isempty(obj_stemmed)
                    push!(triples, RelationalTriple(subj_stemmed, tok, obj_stemmed))
                    
                    # GRUG: High-res feature - detect nested relations via "which" clause
                    # e.g., "A causes B which causes C" -> extract (A causes B) and (B causes C)
                    if "which" in obj_parts || "that" in obj_parts
                        which_idx = findfirst(x -> x in ["which", "that"], obj_parts)
                        if !isnothing(which_idx) && which_idx < length(obj_parts)
                            # Look for verb after "which/that"
                            for k in (which_idx + 1):length(obj_parts)
                                if obj_parts[k] in all_verbs && k < length(obj_parts)
                                    nested_obj_parts = obj_parts[(k+1):end]
                                    nested_obj = join([Thesaurus.stem_token(String(p)) for p in nested_obj_parts], " ")
                                    if !isempty(nested_obj)
                                        # Create nested relation: subject of clause verb -> object
                                        # The clause subject is the compound object minus the which/that part
                                        clause_subj_parts = obj_parts[1:(which_idx-1)]
                                        clause_subj = join([Thesaurus.stem_token(String(p)) for p in clause_subj_parts], " ")
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
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    node_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    required_relations::Vector{String},
# REMINDER: required_relations may use sigils (&n is_greater_than &n) — not fixed string comparisons.
    relation_weights::Dict{String, Float64}
)::Tuple{Float64, Bool}

    if isempty(node_triples)
        return (0.0, false)
    end

    is_antimatch = false
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

    # GRUG v7.55: Expand any relation sigils in required_relations before
    # checking. If a required relation is "&causes" and the sigil expands to
    # ["causes","produces","creates"], then the user supplying ANY of those
    # satisfies the requirement.
    if !isempty(required_relations)
        user_rels = Set([t.relation for t in user_triples])
        for req in required_relations
            req == NONJITTER_TAG && continue
            # GRUG v7.55: Expand relation sigil if present.
            req_alternatives = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, req)
            satisfied = any(alt -> alt in user_rels, req_alternatives)
            if !satisfied
                return (-9999.0, false)
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
            # GRUG v7.55: Expand node triple's relation if it's a sigil reference.
            # Dynamic relational: (subj, &causes, obj) matches (subj, causes, obj)
            # OR (subj, produces, obj) OR any alternative in the sigil's expansion.
            nt_rel_alternatives = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, nt.relation)
            relation_match = any(alt -> ut.relation == alt, nt_rel_alternatives)

            # GRUG: Weight itself gets the first nudge — same bullseye every
            # activation otherwise. jitter_weight is the sign-preserving wrapper.
            # For dynamic relationals, look up weight by:
            #   1. User's actual relation verb (always concrete)
            #   2. The sigil reference name (e.g. "&causes")
            #   3. Any expansion alternative that has a weight
            #   4. Default 1.0
            weight = if !isempty(nt_rel_alternatives) && nt_rel_alternatives[1] != nt.relation
                # Dynamic relational — nt.relation is "&name" form
                w = get(relation_weights, ut.relation, nothing)
                if !isnothing(w)
                    jitter_w(w)
                else
                    # Try the sigil name itself as a weight key (e.g. "&causes")
                    w2 = get(relation_weights, nt.relation, nothing)
                    if !isnothing(w2)
                        jitter_w(w2)
                    else
                        # Try each alternative until one has a weight
                        found = nothing
                        for alt in nt_rel_alternatives
                            w3 = get(relation_weights, alt, nothing)
                            if !isnothing(w3)
                                found = w3
                                break
                            end
                        end
                        jitter_w(something(found, 1.0))
                    end
                end
            else
                jitter_w(get(relation_weights, ut.relation, 1.0))
            end

            if relation_match
                if ut.subject == nt.object && ut.object == nt.subject
                    match_score -= jitter_s(2.0 * weight)
                    is_antimatch = true
                elseif ut.subject == nt.subject && ut.object == nt.object
                    match_score += jitter_s(2.0 * weight)
                elseif ut.subject == nt.subject || ut.object == nt.object
                    match_score += jitter_s(1.0 * weight)
                elseif ut.object == nt.subject || ut.subject == nt.object
                    # GRUG v7.57: Cross-field partial match. When the user says
                    # "i make fire" and the node triple is (fire, &causal, warmth),
                    # the user's object "fire" matches the node's subject "fire".
                    # This is a meaningful semantic overlap — the user's query is
                    # ABOUT the same concept the node relates from. Use a lower
                    # weight (0.7) than same-field partial (1.0) to differentiate
                    # direct ownership from associative overlap, but high enough
                    # to disambiguate cross-lobe confusion (e.g. fire vs music).
                    match_score += jitter_s(0.7 * weight)
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

    return (final_score, is_antimatch)
end

# ==============================================================================
# STRENGTH CAP & APOPTOSIS CONSTANTS
# ==============================================================================

# GRUG: Strength lives in [0.0, STRENGTH_CAP]. At 0.0, node is marked grave.
# At STRENGTH_CAP, node cannot grow stronger (apoptosis ceiling / stratification).
const STRENGTH_CAP   = 10.0
const STRENGTH_FLOOR = 0.0

"""
    strength_biased_scan_coinflip(node::Node)::Bool

GRUG v8.26e: STRENGTH REMOVED from scan coinflip. Per user directive:
"strength should not bias confidence at all. strength only affects
chatter really and when things get graved." The old formula gave
strong nodes up to 90% scan chance vs 20% for weak ones — this meant
high-strength low-relevance nodes (like thermodynamics) always got
scanned while weaker but more relevant nodes (like fire) often got
skipped entirely. Now ALL non-grave nodes get a flat 50/50 coinflip.
Grave nodes are already excluded before this gate.
BUG-011: this is not reinforcement and never changes node strength.
"""
function strength_biased_scan_coinflip(node)::Bool
    return rand() < 0.50
end

# GRUG: Slow-response telemetry threshold. v7.21c-5 side-process isolation:
# exceeding this threshold logs diagnostics only; it does not grave voters.
# 24-hour ledger clears daily. Time in seconds.
const SLOW_NODE_THRESHOLD_SECONDS = 5.0
const LEDGER_CLEAR_INTERVAL       = 86400.0  # GRUG: 24 hours in seconds

# GRUG: Max neighbors before node is UNLINKABLE (apoptosis of link capacity).
# DEPRECATED as a hard cap — kept as a fallback default. The real cap is rolled
# per-node at construction time in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]
# and stored on Node.max_neighbors. This randomized cap stops every node from
# saturating at the same uniform link count and lets dense hubs / sparse satellites
# emerge organically.
const MAX_NEIGHBORS = 4
const LATCH_PARTNER_CAP_MIN = 8
const LATCH_PARTNER_CAP_MAX = 16

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
# REMINDER: hopfield_key is DEAD FIELD (specimen compat only). ANTIMATCH REMOVED. SIGILS IN TRIPLES.
    id::String
    pattern::String
    signal::Vector{Float64}          # GRUG: Number rocks for Pattern Scanner!
    action_packet::String
    json_data::Dict{String, Any}
    drop_table::Vector{String}
    throttle::Float64
    relational_patterns::Vector{RelationalTriple}
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    required_relations::Vector{String}
# REMINDER: required_relations may use sigils (&n is_greater_than &n) — not fixed string comparisons.
    relation_weights::Dict{String, Float64}

    # GRUG NEW: Strength system (apoptosis + stratification)
    strength::Float64                # GRUG: Node power [0.0, STRENGTH_CAP]

    # GRUG NEW: Is this node an image node? (pattern is SDF binary, not text)
    is_image_node::Bool

    # GRUG v8.26h: is_antimatch_node field is DEAD/LEGACY. Antimatch nodes were removed.
    # /addAntiMatch and /antiAnswer commands deleted. This field remains for specimen compat.
    is_antimatch_node::Bool

    # GRUG NEW: Neighbor linking (max neighbors rolled per-node 8-16 before UNLINKABLE)
    neighbor_ids::Vector{String}
    is_unlinkable::Bool              # GRUG: True when neighbor_ids reaches max_neighbors
    max_neighbors::Int               # GRUG: Per-node cap, rolled in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]

    # GRUG NEW: Grave tracking (strength hits 0 OR slow response average)
    is_grave::Bool
# REMINDER: Grave nodes exist but antimatch does NOT — antimatch was removed.
    grave_reason::String             # GRUG: "STRENGTH_ZERO", "GRAVED-SLOW", or ""

    # GRUG NEW: Big-O response time ledger (clears every 24 hours)
    response_times::Vector{Float64}  # GRUG: Rolling list of response times (seconds)
    ledger_last_cleared::Float64     # GRUG: Unix timestamp of last 24hr clear

    # GRUG NEW: Hopfield cache key (hash of pattern, used for familiar input lookup)
    hopfield_key::UInt64
# ⚠️ REMINDER: HOPFIELD CACHING WAS REMOVED. This field is dead — specimen round-trip only.

    # GRUG NEW: Contributed to output this cycle (for /right and /wrong feedback)
    fired_this_cycle::Bool           # GRUG: True if node's vote was used by AIML orchestrator
    voted_this_cycle::Bool           # GRUG: True if node voted (may or may not have contributed)
    gained_this_cycle::Bool          # GRUG: True if node gained strength this cycle
    strength_delta_this_cycle::Float64  # GRUG: Strength change this cycle (feedback diagnostics)

    # GRUG BUG-010b: Pre-chatter originals for inhibition rules.
    # When chatter swaps a node's pattern + action_packet (Markov remix),
    # the remixed content is borrowed/stolen — it's NOT the node's organic
    # identity. Inhibition rules (the "don't do" list) must use the
    # ORIGINAL content, not the post-swap remixed stuff. Originals are
    # frozen at node creation and never updated by chatter.
    original_pattern::String             # GRUG: Pattern at birth. Chatter never touches this.
    original_action_packet::String       # GRUG: Action packet at birth. Chatter never touches this.

    # GRUG v7.59: Node type discriminator. :voter = regular voter node (grows in groups,
    # eligible for idle chatter, votes remixed by ChatterVoteSwap). :sigil = procedural/
    # sigil-using node (NOCHAT — ineligible for idle chatter, always singleton, never
    # placed in growth groups). Sigil nodes carry syntactic grammars (e.g. "&n &op &n")
    # whose patterns are NOT semantic — they are deterministic execution chains. Chatter
    # must not remix procedural votes any more than dreams remix motor procedures.
    # Biology: basal ganglia/cerebellum (procedural) do not participate in hippocampal
    # replay (declarative/episodic). People don't dream in procedures.
    #
    # IMPORTANT: Relational triples can optionally USE sigils, making them dynamic rather
    # than static. A required_relations entry like "&n is_greater_than &n" means the
    # relation is evaluated at match time with the sigil-bound values — not a fixed string
    # comparison. This is easy to forget when authoring specimens. Comments about this
    # appear throughout the codebase as reminders.
    node_type::Symbol                 # GRUG: :voter (default) or :sigil (NOCHAT, singleton)
end

struct Vote
    node_id::String
    action::String
    confidence::Float64
    negatives::Vector{String}
    user_triples::Vector{RelationalTriple}
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    node_triples::Vector{RelationalTriple}
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    antimatch::Bool  # GRUG v8.26h: LEGACY — antimatch nodes removed. Field kept for compat.
    # ---- v7.23 multipart fields (additive, default-safe) ------------------
    # GRUG: empty group_id means "this vote is on its own". Same node may emit
    # several votes that all carry the SAME non-empty group_id; AIML treats
    # them as one objective. Role distinguishes the locked-in claim
    # (:primary) from the supports (:support). :singleton is the default
    # marker for the historical case (no multipart).
    multipart_group::String
    multipart_role::Symbol
    # ---- v7.23 chunked affinity field -------------------------------------
    # GRUG: which input chunks this vote resolved. Empty = old behavior
    # (unchunked input, or vote was created before chunk-aware pipeline).
    # When chunked affinities are active, each vote knows which part(s)
    # of the input it matched — like a place cell that fires for a specific
    # location, not "the environment." MultipartOrchestrator uses this for
    # grouping instead of the multipart_group tag when available.
    input_chunks::Vector{Int}
end

# GRUG: 7-arg outer constructor preserves every existing call site.
# Supplies "" / :singleton / empty Int[] for the new fields. Old code is bit-exact.
function Vote(node_id::String,
              action::String,
              confidence::Float64,
              negatives::Vector{String},
              user_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
              node_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
              antimatch::Bool)
    return Vote(node_id, action, confidence, negatives,
                user_triples, node_triples, antimatch,
                "", :singleton, Int[])
end

# GRUG: 9-arg constructor for multipart_group + multipart_role (pre-chunked-affinity).
# Supplies empty Int[] for input_chunks. Preserves existing cast_vote_with_group sites.
function Vote(node_id::String,
              action::String,
              confidence::Float64,
              negatives::Vector{String},
              user_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
              node_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
              antimatch::Bool,
              multipart_group::String,
              multipart_role::Symbol)
    return Vote(node_id, action, confidence, negatives,
                user_triples, node_triples, antimatch,
                multipart_group, multipart_role, Int[])
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

# GRUG v7.60-confidence-lock: Raw confidence floor for firing a node in
# scan_specimens. Only nodes whose pattern-match confidence meets this lock
# enter the voter pool. This prevents low-confidence noise from inflating
# past the vote threshold via composite scoring bonuses. The lock is applied
# at scan time, before any bonuses are computed, so it gates on genuine
# pattern relevance, not post-hoc score engineering.
# GRUG v7.61: Raised from 0.15 to 0.30. At 0.15, nodes matching only ONE
# content word (like "shelter work" for "how does fire work") could enter
# the voter pool with confidence ~0.3 and sometimes win the vote. A 0.30
# lock requires at least moderate lexical overlap (harmonic mean of both
# input-coverage and node-coverage ≥ 0.30), which means matching at least
# half the content words in both directions — sufficient semantic relevance.
const SCAN_CONFIDENCE_LOCK       = 0.35
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
    is_time_node(node::Node)::Bool

GRUG v7.56a: Returns true if this node is a time node. Time nodes are regular
nodes that carry `time_node=true` in their json_data. They cluster into
time-node-only groups. No special code path — pure label gate.
"""
function is_time_node(node::Node)::Bool
    return get(node.json_data, "time_node", false) === true
end

# ── GRUG v8.1: TIME COHERENCE SIGNALING ──────────────────────────────
# Time sigils (&now, &before, &next) are :macro/:tone entries in the
# sigil registry. When the promoter rewrites a temporal word (e.g. "now"
# → "&now"), the resulting SigilBinding carries the sigil entry's params
# dict, which includes :orientation and :vote_flags. These functions
# extract that orientation from the current promotion bindings and make
# it available to the AIML payload generator and hippocampal lever.
#
# The three orientations and their vote flags:
#   past    → reflect=true,  assess=false, project=false
#   present → reflect=false, assess=true,  project=false
#   future  → reflect=false, assess=false, project=true
#
# Time nodes that fire during a cascade read these flags to determine
# which AIML reasoning mode to activate. The hippocampal lever uses
# orientation to decide whether to pull past context (reflect), assess
# current state (assess), or project forward (project).

const TIME_SIGIL_NAMES = Set{String}(["now", "before", "next"])

"""
    extract_time_orientation(bindings) -> (orientation::String, vote_flags::Dict)

GRUG v8.1: Scan promotion bindings for time sigil entries. Returns the
orientation and vote_flags from the FIRST time sigil binding found. If no
time sigil binding is present, returns ("none", empty Dict). Multiple time
sigils in one input are possible but the first one wins (the system orients
toward the first temporal signal the user sends).
"""
function extract_time_orientation(bindings::Vector{SigilPromoter.SigilBinding})::Tuple{String,Dict{String,Any}}
    for b in bindings
        if b.name in TIME_SIGIL_NAMES
            # Look up the sigil entry to read params
            entry = SigilRegistry.lookup_sigil(_ENGINE_SIGIL_TABLE, b.name)
            if entry.params !== nothing
                orientation = get(entry.params, "orientation", "none")
                vote_flags  = get(entry.params, "vote_flags", Dict{String,Any}())
                signal_list = get(entry.params, "signal", String[])
                return (orientation, Dict{String,Any}(
                    "orientation" => orientation,
                    "vote_flags"  => vote_flags,
                    "signal"      => signal_list,
                    "sigil_name"  => b.name,
                    "surface"     => b.surface
                ))
            end
        end
    end
    return ("none", Dict{String,Any}())
end

"""
    has_time_orientation(bindings) -> Bool

GRUG v8.1: Returns true if any binding in the list is a time sigil.
"""
function has_time_orientation(bindings::Vector{SigilPromoter.SigilBinding})::Bool
    return any(b -> b.name in TIME_SIGIL_NAMES, bindings)
end

"""
    time_vote_flags(orientation_data) -> Dict

GRUG v8.1: Extract just the vote_flags from time orientation data.
Returns empty Dict if no time orientation is present.
"""
function time_vote_flags(orientation_data::Dict{String,Any})::Dict{String,Any}
    return get(orientation_data, "vote_flags", Dict{String,Any}())
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
# v7.20 — VOTE-LEVEL NONJITTER OVERRIDE
# ==============================================================================
# GRUG: Old NONJITTER was an absolute lifetime tag — once a node solidified,
# every vote it cast was bit-stable forever. New rule: the tag is a
# *baseline*, not an absolute. A solidified node's high-confidence votes stay
# bit-stable (still a "crystallized rock"), but a *low-confidence* firing
# from the same node still jitters. Why? "The solid rock is guessing" —
# you don't want to ossify a guess just because the rock is usually right.
#
# Plumbing:
#   - JITTER_CONFIDENCE_FLOOR : confidence below this forces jitter through.
#   - jitter_allowed_for(node, conf) : single point of truth; both the node
#     tag and the per-firing confidence are consulted.
#
# Callsite contract:
#   * Node-only check (no confidence available yet, e.g. relational weight
#     jitter at growth time): keep using is_nonjitter(node).
#   * Confidence-bearing check (scan output, vote relay): use
#     jitter_allowed_for(node, conf).
#
# Why a constant, not a config? The floor lives at the "this is a guess"
# threshold — same conceptual line that CONTEXT_TRUST_FLOOR draws for memory
# pulls. Both should move together if at all. A constant in the engine is
# the right home; if it ever needs runtime tuning we expose a setter.
# ==============================================================================

# GRUG: A vote firing below this confidence is treated as a guess. Even on a
# solidified (NONJITTER) node, jitter still runs to avoid ossifying the
# guess. 0.50 is "I'm 50/50 on this" — anything below that is honestly
# uncertain and deserves substrate noise.
const JITTER_CONFIDENCE_FLOOR = 0.50

"""
    jitter_allowed_for(node::Node, confidence::Float64)::Bool

GRUG v7.20: Single point of truth for "should jitter run for this firing?"
Combines the node-level NONJITTER baseline with a per-firing confidence
override.

RETURNS:
  - `true`  → jitter SHOULD run (default for unsolid nodes; also for solid
              nodes when the current vote is low-confidence)
  - `false` → jitter is suppressed (solid node firing a high-confidence vote)

LOGIC:
  - Unsolid node (no NONJITTER tag): jitter always runs → return true
  - Solid node + confidence ≥ JITTER_CONFIDENCE_FLOOR: bit-stable → return false
  - Solid node + confidence < JITTER_CONFIDENCE_FLOOR: low-conf override fires
    → return true (rock is guessing, don't ossify the guess)

CONTRACT: this function is pure (no mutation, no allocation, no I/O). Safe
to call from hot paths.
"""
function jitter_allowed_for(node::Node, confidence::Float64)::Bool
    # GRUG: Fast path — unsolid nodes always jitter.
    if !is_nonjitter(node)
        return true
    end
    # GRUG: Solid node — honor the per-firing confidence override.
    return confidence < JITTER_CONFIDENCE_FLOOR
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

GRUG BUG-011: Coinflip-gated strength gain primitive. Capped at STRENGTH_CAP.
Callers must only invoke this from approved reinforcement paths, e.g. locked
/right feedback. General use/vote paths must not call it for passive reward.
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
        lock(NODE_LOCK) do
            node.strength = max(node.strength - 1.0, STRENGTH_FLOOR)
            if node.strength <= STRENGTH_FLOOR && !node.is_grave
                node.is_grave    = true
                node.grave_reason = "STRENGTH_ZERO"
                println("[ENGINE] ⚰  Node $(node.id) marked GRAVE (strength -> 0).")
                # GRUG (v7.19): tell the group bookkeeper a slot opened up.
                try mark_group_grave_slot!(node.id) catch e; @warn "group slot update failed for $(node.id): $e"; end
            end
        end
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
    # GRUG (v7.19): tell the group bookkeeper a slot opened up.
    try mark_group_grave_slot!(node.id) catch e; @warn "group slot update failed for $(node.id): $e"; end
    println("[ENGINE] ⚰  Node $(node.id) marked GRAVE: [$reason].")
end

# ==============================================================================
# BIG-O RESPONSE TIME LEDGER
# ==============================================================================

"""
record_response_time!(node::Node, elapsed_seconds::Float64)

GRUG: Record a response time for this node in its big-O ledger.
Side-process isolation rule: timing telemetry must not change vote confidence
or future vote eligibility. Slow averages are logged, not auto-graved.
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
        error("!!! FATAL: record_response_time! got negative elapsed time: $elapsed_seconds! !!!")
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

        # GRUG: Check average response time for telemetry only.
        # v7.21c-5 side-process isolation: response-time side effects must not
        # grave nodes or alter future vote eligibility. Keep the ledger useful
        # for diagnostics, but never convert slowness into GRAVED-SLOW here.
        if !isempty(node.response_times)
            avg_time = sum(node.response_times) / length(node.response_times)
            if avg_time > SLOW_NODE_THRESHOLD_SECONDS
                println("[ENGINE] 🐢  Node $(node.id) slow telemetry only (avg: $(round(avg_time, digits=2))s > $(SLOW_NODE_THRESHOLD_SECONDS)s); not graving.")
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
Fails (returns false) if either node already has its per-node max_neighbors cap
(is UNLINKABLE). Each node rolls its own cap in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]
at construction so connectivity is heterogeneous (hub vs. satellite emergence).
On success, both nodes gain each other as neighbors.
"""
function try_link_nodes!(node_a::Node, node_b::Node)::Bool
    if node_a.id == node_b.id
        # GRUG: Node cannot be its own neighbor. That's just a mirror, not a friend!
        return false
    end

    lock(NODE_LOCK) do
        # GRUG: Check both nodes can accept new neighbors
        # GRUG (v7.19): UNLINKABLE override for grave-slot replacement.
        # If a node is UNLINKABLE but its group has has_grave_slot=true (a
        # member was just graved), allow ONE extra link to fill the empty
        # slot. The slot flag is cleared by add_to_group! when the new
        # member joins downstream of try_link_nodes! \u2014 here we only honor
        # the override at the link layer.
        a_locked = node_a.is_unlinkable
        b_locked = node_b.is_unlinkable
        if a_locked
            ga = group_for(node_a.id)
            if !isnothing(ga) && ga.has_grave_slot
                a_locked = false
            end
        end
        if b_locked
            gb = group_for(node_b.id)
            if !isnothing(gb) && gb.has_grave_slot
                b_locked = false
            end
        end
        if a_locked || b_locked
            return false
        end
        if node_a.id in node_b.neighbor_ids || node_b.id in node_a.neighbor_ids
            # GRUG: Already linked! Don't double-link.
            return false
        end

        push!(node_a.neighbor_ids, node_b.id)
        push!(node_b.neighbor_ids, node_a.id)

        # GRUG: Check if either node just hit its per-node UNLINKABLE threshold
        if length(node_a.neighbor_ids) >= node_a.max_neighbors
            node_a.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_a.id) is now UNLINKABLE ($(node_a.max_neighbors) neighbors reached).")
        end
        if length(node_b.neighbor_ids) >= node_b.max_neighbors
            node_b.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_b.id) is now UNLINKABLE ($(node_b.max_neighbors) neighbors reached).")
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
# GRUG v8.0: CASCADE BRIDGE — Match-Cascade Handoff System
# OLD: nodeattach was ASYMMETRIC one-way (target fires → attached MAY fire).
#      Dumb middle-man connector pattern that didn't use the scanner's natural
#      match boundary. Cross-lobe suppression was a hack. AttachedNode was
#      direction-locked — B→A never knew A→B existed.
# NEW: CascadeBridge is BIDIRECTIONAL. When a node fires, the scanner's
#      unmatched tail (the match boundary cutoff) IS the handoff payload to
#      the bridged node. The receiving lobe's scanner processes that fragment
#      directly — no middle-man connector pattern needed. Two-way because
#      the bridge entry exists under BOTH node IDs in BRIDGE_MAP.
#      Cross-lobe works NATURALLY: the unmatched tail carries provenance
#      (which lobe matched last, which node, seam verb) so the receiving
#      lobe knows exactly where the handoff came from.
# Crystallize preserved: crystalized bridges skip the handoff coinflip
#      and always fire. Same :user/:auto/:none origin system.

mutable struct CascadeBridge
    partner_id::String       # GRUG: ID of the bridged partner node (must exist in NODE_MAP)
    seam_tokens::Vector{String}  # GRUG: Tokens at the match boundary — the seam where one lobe's
                              #       scanner cut off and the handoff begins. These are the ACTUAL
                              #       unmatched tokens from the source lobe's scan, not a fabricated
                              #       connector pattern. Replaced the dumb middle-man.
    base_confidence::Float64 # GRUG: JIT-baked confidence computed at bridge time.
                             #       Formula: token_overlap_similarity(node_A.pattern, node_B.pattern)
                             #                 + (partner.strength / STRENGTH_CAP) * 0.5
                             #       At fire time, only jitter is applied: max(0.1, base_confidence + jitter)
    source_lobe::String      # GRUG: Lobe ID of the node that created this bridge entry.
                             #       For bidirectional entries, each side records the OTHER node's lobe.
                             #       This is the provenance — the receiving lobe knows who sent the handoff.
    is_crystalized::Bool     # GRUG (CRYSTALIZE spec): if true, skip the handoff coinflip —
                             #       this bridge ALWAYS fires when its partner fires. Set by user
                             #       via /crystalize, or auto-set when the partner node has high
                             #       strength AND high semantic-truth on its relational triples.
                             #       Auto-revoked if strength drops below the crystalization floor.
    crystal_origin::Symbol   # GRUG: :user (manual /crystalize), :auto (semantic-truth triggered),
                             #       or :none (not crystalized). Lets the auto-revoker only touch
                             #       nodes it crystalized itself — manual marks stay sticky.
end

# Backwards-compat constructor: old 4-arg attach sites still work (seam_tokens
# defaults to empty, source_lobe defaults to ""). Full bridge creation uses 6-arg form.
CascadeBridge(partner_id::String, seam_tokens::Vector{String}, base_confidence::Float64) =
    CascadeBridge(partner_id, seam_tokens, base_confidence, "", false, :none)

# GRUG v8.0: BRIDGE_MAP is BIDIRECTIONAL. When A↔B is bridged, BOTH
# BRIDGE_MAP[A] and BRIDGE_MAP[B] get an entry. Each side's entry points
# to the other. This makes handoff two-way: when A fires, it checks
# BRIDGE_MAP[A] and hands off unmatched tail to B. When B fires, it
# checks BRIDGE_MAP[B] and hands off to A. No more one-way derp.
const BRIDGE_MAP   = Dict{String, Vector{CascadeBridge}}()
const BRIDGE_LOCK  = ReentrantLock()

# GRUG: Backward compat aliases so existing code doesn't break during migration
const ATTACHMENT_MAP  = BRIDGE_MAP
const ATTACHMENT_LOCK = BRIDGE_LOCK

# ==============================================================================
# CHATTER GROUPS (v7.19)
# ==============================================================================
#
# GRUG: A NodeGroup is a named bundle of similar-pattern nodes that chatter
# together. When a new node grows and finds a strength-biased latch target,
# the new node JOINS the latch target's group (or creates a fresh group if
# the target has none). Each group has a stable id ("group_<n>") so chatter
# can address whole bundles without recomputing similarity every cycle.
#
# Membership rules:
#   - A node belongs to exactly one group at a time (its primary group_id).
#   - A node CAN appear in multiple groups via its neighbor_ids \u2014 those are
#     symmetric latches \u2014 but for chatter purposes we use the primary group.
#   - When a member is graved, we strip UNLINKABLE from the group so a
#     replacement can come in (per spec: "if a node within a group gets
#     graved the unlinkable tag is removed for that group until another
#     node replaces it").
#   - Phagy idle role organizes/cleans groups: drops graves, prunes empty
#     groups, merges duplicates if any drift in.
#
# Persistence:
#   GROUP_MAP serializes into the specimen JSON so groups survive save/load.
#   See save_specimen / load_specimen in Main.jl.

const GROUP_MAX_OCCUPANCY = 32  # GRUG: Max members per group. New nodes can't join full groups.
const NOCHAT_GRADUATE_MIN_NEIGHBORS = 4  # GRUG v7.39: Min connected members for NOCHAT graduation. Groups with <4 connected members are invisible to ChatterMode to prevent whacky remixes on under-populated groups.

mutable struct NodeGroup
# REMINDER: hopfield_key is DEAD FIELD (specimen compat only). ANTIMATCH REMOVED. SIGILS IN TRIPLES.
    id::String                       # GRUG: Stable group id ("group_0", "group_1", ...)
    members::Vector{String}          # GRUG: Node ids \u2014 ORDER PRESERVED for cursor walks
    centroid_pattern::String         # GRUG: Pattern of the founding/seed node (similarity anchor)
    created_at::Float64              # GRUG: Unix timestamp at creation
    last_chatter_at::Float64         # GRUG: 0.0 = never chattered. Updated when group participates.
    chatter_count::Int               # GRUG: How many times this group has chattered (lifetime)
    has_grave_slot::Bool             # GRUG: True after a member is graved \u2014 grants UNLINKABLE override
                                     #       so a fresh node can fill the empty slot. Cleared when
                                     #       the slot is filled.
    grave_count::Int                 # GRUG BUG-010: Number of currently-vacant grave slots in this
                                     #       group. Incremented when a member is graved, decremented
                                     #       when a replacement fills the slot. Used by grave_shadow
                                     #       to compute local inhibition from dead knowledge.
    max_occupancy::Int               # GRUG: Cap on members. Graved nodes create vacancies below this.
                                     #       New nodes can join if length(members) < max_occupancy.
    is_time_node_group::Bool         # GRUG v7.56a: True when seed node is a time node. Time nodes
                                     #       can ONLY pair into groups with other time nodes. Non-time
                                     #       nodes can only join non-time-node groups. Pure label gate.
    is_chatter_eligible::Bool        # GRUG v7.39: False = NOCHAT — group is invisible to ChatterMode.
                                     #       Singleton groups with <4 connected members start as NOCHAT
                                     #       to prevent whacky remixes on under-populated groups.
                                     #       Automatically graduates to true when group reaches 4+
                                     #       connected members (checked in add_to_group!). Replaces
                                     #       the old chatter_count=-1 sentinel hack which was fragile
                                     #       and never enforced.
    inhibition_tokens::Set{String}   # GRUG BUG-010b: Semantic "don't do" set — tokens from alive
                                     #       members' ORIGINAL pattern + action_packet (pre-chatter),
                                     #       expanded by thesaurus. Post-swap remixed content does NOT
                                     #       contribute. Graved nodes excluded. Used by growth/latch
                                     #       to avoid spawning what's already semantically covered.
    inhibition_dirty::Bool           # GRUG BUG-010b: True when inhibition_tokens is stale and needs
                                     #       refresh before use. Set on: member add, grave, chatter swap.
                                     #       Cleared by refresh_inhibition_tokens!().
end

# GRUG: Backwards-friendly constructor. Most callers only know id+seed.
# Calls the default inner constructor (13 positional fields) provided by Julia.
NodeGroup(id::String, seed_node_id::String, centroid_pattern::String; is_time_node_group::Bool=false, is_chatter_eligible::Bool=true) =
    NodeGroup(id, [seed_node_id], centroid_pattern, time(), 0.0, 0, false, 0, GROUP_MAX_OCCUPANCY, is_time_node_group, is_chatter_eligible, Set{String}(), true)

# NOTE: No explicit 14-arg outer constructor needed — Julia's default inner
# constructor already provides NodeGroup(id, members, centroid_pattern,
# created_at, last_chatter_at, chatter_count, has_grave_slot, grave_count, max_occupancy,
# is_time_node_group, is_chatter_eligible, inhibition_tokens, inhibition_dirty).
# Defining an outer constructor with the same signature as the inner one
# replaces it and causes infinite recursion (StackOverflowError).

# GRUG: All groups, by stable id. Phagy organizes this map at idle.
const GROUP_MAP    = Dict{String, NodeGroup}()
const GROUP_LOCK   = ReentrantLock()
const GROUP_COUNTER = Atomic{Int}(0)

# GRUG: Reverse index node_id -> group_id (primary group only). Built lazily;
# always check GROUP_MAP for ground truth. Speeds up "what group is this node
# in?" lookups during chatter without a full scan.
const NODE_TO_GROUP = Dict{String, String}()

# GRUG: Per-node 1-hour chatter cooldown. Distinct from MORPH_COOLDOWN_MAP
# in ChatterMode.jl (which gated the old pattern-morph path). The vote-swap
# chatter has its own short cooldown because swaps are reversible noise,
# not the irreversible identity drift of pattern morphing.
# Map: node_id -> last chatter epoch seconds.
const CHATTER_NODE_COOLDOWN      = Dict{String, Float64}()
const CHATTER_NODE_COOLDOWN_LOCK = ReentrantLock()
const CHATTER_NODE_COOLDOWN_SECONDS = 3600.0   # GRUG: 1 hour, per spec

# BUG-011: Permanent mutation registry. Once a node has been chatter-mutated
# (pattern swapped or vote remixed), it can NEVER be mutated again. This is
# stronger than the 1-hour cooldown — it's a lifetime ban. The set persists
# across sessions and survives reload. Cleared only by full engine reset.
const CHATTER_MUTATED_SET      = Set{String}()
const CHATTER_MUTATED_SET_LOCK = ReentrantLock()

"""
    is_chatter_mutated(node_id) -> Bool

Returns true if this node has ever been chatter-mutated (pattern swap or vote
remix applied). Mutated nodes are permanently excluded from future chatter.
"""
function is_chatter_mutated(node_id::String)::Bool
    return lock(CHATTER_MUTATED_SET_LOCK) do
        node_id in CHATTER_MUTATED_SET
    end
end

"""
    mark_chatter_mutated!(node_id)

Record that this node has been chatter-mutated. Permanent — only cleared by
full engine reset. Checked before staging any swap and enforced at apply time.
"""
function mark_chatter_mutated!(node_id::String)
    lock(CHATTER_MUTATED_SET_LOCK) do
        push!(CHATTER_MUTATED_SET, node_id)
    end
end

"""
    next_group_id() -> String

GRUG: Atomic group id minter. Always returns a unique "group_<n>" string.
Underlying counter is reset only by full engine reset (reset_engine!).
"""
function next_group_id()::String
    n = atomic_add!(GROUP_COUNTER, 1)
    return "group_$n"
end

# ── GRUG v7.59: Sigil node helper functions ──────────────────────────────────────
# These predicates identify sigil nodes by their node_type field. Sigil nodes
# carry syntactic grammars (e.g. "&n &op &n") whose patterns are NOT semantic
# content — they are deterministic execution chains. Chatter must not remix
# procedural votes. Biology: people don't dream in procedures.
#
# Relational triples can optionally USE sigils, making them dynamic rather than
# static. A required_relations entry like "&n is_greater_than &n" means the
# relation evaluates at match time with sigil-bound values — not a fixed string
# comparison. Easy to forget when authoring specimens.

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
    is_nochat(node) -> Bool

GRUG v7.59: Returns true when the node is ineligible for idle chatter.
Sigil nodes (node_type == :sigil) are always NOCHAT because their patterns
are syntactic grammars (e.g. "&n &op &n"), not semantic content. ChatterVoteSwap
must not remix their deterministic execution chains. Biology: people don't dream
in procedures — the basal ganglia/cerebellum (procedural) do not participate in
hippocampal replay (declarative/episodic).

Relational triples can optionally USE sigils, making them dynamic rather than static.
A required_relations entry like "&n is_greater_than &n" means the relation evaluates
at match time with sigil-bound values — not a fixed string comparison. This is easy
to forget when authoring specimens.
"""
is_nochat(node::Node)::Bool = node.node_type === :sigil

"""
    is_singleton(node) -> Bool

GRUG v7.59: Returns true when the node must never be placed in growth groups.
Sigil nodes are always singleton — they carry procedural execution chains that
must not be contaminated by group dynamics (partner cap, unlinkable mechanics,
chatter windows). GroupRegistry.register_node_in_group! rejects singleton nodes.

Relational triples can optionally USE sigils, making them dynamic rather than static.
A required_relations entry using sigils evaluates at match time with the sigil-bound
values, not as a fixed string. Easy to forget when authoring specimens.
"""
is_singleton(node::Node)::Bool = node.node_type === :sigil

# ── End v7.59 helpers ────────────────────────────────────────────────────────────

"""
    register_group!(seed_node::Node) -> NodeGroup

GRUG: Create a fresh group seeded by a single node. The node becomes the
group's centroid — future joiners are evaluated against this pattern. Idempotent
when the seed already belongs to a group: returns the existing group.
NO SILENT FAILURES: errors if seed_node has empty pattern.

GRUG v7.59: Singleton (sigil) nodes are REJECTED — they must never be placed
in growth groups. Their patterns are syntactic grammars, not semantic content.
People don't dream in procedures.
"""
function register_group!(seed_node::Node)::NodeGroup
    # GRUG v7.59: SINGLETON REJECTION — sigil nodes NEVER join groups.
    # They are NOCHAT (ineligible for idle chatter) and singleton (no group
    # partners). Their patterns are syntactic grammars, not semantic content.
    # Group dynamics (partner caps, unlinkable mechanics, chatter windows)
    # must not contaminate procedural execution. People don't dream in procedures.
    if is_singleton(seed_node)
        error("!!! FATAL: register_group! rejected singleton node $(seed_node.id) " *
              "(sigil node, node_type==:sigil); singleton nodes are never placed " *
              "in groups — they are NOCHAT and ineligible for idle chatter. " *
              "People don't dream in procedures. !!!")
    end
    if strip(seed_node.pattern) == ""
        error("!!! FATAL: register_group! seed node $(seed_node.id) has empty pattern! !!!")
    end
    return lock(GROUP_LOCK) do
        # GRUG: If seed already in a group, just return that one. No duplicate seeding.
        existing = get(NODE_TO_GROUP, seed_node.id, nothing)
        if !isnothing(existing) && haskey(GROUP_MAP, existing)
            return GROUP_MAP[existing]
        end

        gid = next_group_id()
        # GRUG v7.56a: If seed is a time node, this group is a time-node group.
        # Time nodes can ONLY pair into groups with other time nodes.
        is_tng = is_time_node(seed_node)
        grp = NodeGroup(gid, seed_node.id, seed_node.pattern; is_time_node_group=is_tng)
        GROUP_MAP[gid] = grp
        NODE_TO_GROUP[seed_node.id] = gid
        return grp
    end
end

"""
    add_to_group!(group::NodeGroup, node_id::String)::Bool

GRUG: Append `node_id` to the group's member list. Returns true on success,
false if already a member. Updates the NODE_TO_GROUP reverse index. Clears
`has_grave_slot` if the join fills a graved slot (count back to known size).
v7.39: Also graduates NOCHAT groups to chatter-eligible when enough connected
members are present (NOCHAT_GRADUATE_MIN_NEIGHBORS = 4).
"""
function add_to_group!(group::NodeGroup, node_id::String)::Bool
    if isempty(strip(node_id))
        error("!!! FATAL: add_to_group! got empty node_id! !!!")
    end
    # GRUG v7.59: Singleton (sigil) nodes are REJECTED from group membership.
    # They are NOCHAT (ineligible for idle chatter) and singleton (no group
    # partners). Their patterns are syntactic grammars, not semantic content.
    # People don't dream in procedures.
    _joining = get(NODE_MAP, node_id, nothing)
    if !isnothing(_joining) && is_singleton(_joining)
        return false  # silent reject — sigil nodes never join groups
    end
    return lock(GROUP_LOCK) do
        if node_id in group.members
            return false
        end
        # GRUG: Enforce max_occupancy cap. Full group = no join.
        # Exception: has_grave_slot means a vacancy exists, so one extra can fill it.
        if length(group.members) >= group.max_occupancy && !group.has_grave_slot
            return false
        end
        # GRUG v7.56a: Time-node group isolation. Time nodes can ONLY pair
        # into groups with other time nodes. Non-time nodes can only join
        # non-time-node groups. Cross-type join = silent reject (returns false).
        # This is the core grouping constraint for time nodes — they cluster
        # together and never mix with regular nodes in groups.
        joining_node = get(NODE_MAP, node_id, nothing)
        if !isnothing(joining_node)
            node_is_time = is_time_node(joining_node)
            grp_is_time = group.is_time_node_group
            if node_is_time != grp_is_time
                return false
            end
        end
        push!(group.members, node_id)
        NODE_TO_GROUP[node_id] = group.id
        # GRUG: Filling a graved slot clears the override and decrements grave_count.
        if group.has_grave_slot
            group.has_grave_slot = false
            group.grave_count = max(0, group.grave_count - 1)
            # GRUG: If grave_count dropped to zero, no more vacant slots.
            # If still > 0, there are more graves to fill — re-enable slot flag
            # so the next join also gets the override.
            if group.grave_count > 0
                group.has_grave_slot = true
            end
        end

        # GRUG v7.39: NOCHAT graduation. When a NOCHAT group (is_chatter_eligible=false)
        # grows to have enough connected members, it automatically graduates to
        # chatter-eligible. The threshold is NOCHAT_GRADUATE_MIN_NEIGHBORS (4).
        # This replaces the old chatter_count=-1 sentinel which had no graduation path.
        if !group.is_chatter_eligible
            _connected = 0
            for mid in group.members
                mn = get(NODE_MAP, mid, nothing)
                if mn !== nothing && !mn.is_grave && length(mn.neighbor_ids) > 0
                    _connected += 1
                end
            end
            if _connected >= NOCHAT_GRADUATE_MIN_NEIGHBORS
                group.is_chatter_eligible = true
            end
        end

        # GRUG BUG-010b: Inhibition tokens are now stale (new member added).
        group.inhibition_dirty = true

        return true
    end
end

"""
    mark_group_grave_slot!(node_id::String)

GRUG: When a node is graved, find its primary group and flip has_grave_slot
to true. This grants temporary UNLINKABLE override on members of the group
so a fresh node can replace the graved one. No-op if node was not in any group.
"""
function mark_group_grave_slot!(node_id::String)
    if isempty(strip(node_id))
        error("!!! FATAL: mark_group_grave_slot! got empty node_id! !!!")
    end
    lock(GROUP_LOCK) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) && return
        if !haskey(GROUP_MAP, gid)
            # GRUG: Reverse index pointed nowhere \u2014 self-heal.
            delete!(NODE_TO_GROUP, node_id)
            return
        end
        grp = GROUP_MAP[gid]
        # GRUG: Drop the dead member from the visible list but remember the slot is open.
        filter!(m -> m != node_id, grp.members)
        delete!(NODE_TO_GROUP, node_id)
        grp.has_grave_slot = true
        # GRUG BUG-010: Track how many grave vacancies this group has.
        # Each grave increments the count; add_to_group! decrements when
        # a replacement fills the slot. Used by grave_shadow_multiplier.
        grp.grave_count += 1
        # GRUG BUG-010b: Inhibition tokens are stale (member graved).
        grp.inhibition_dirty = true
    end
end

"""
    group_for(node_id::String)::Union{NodeGroup, Nothing}

GRUG: Cheap lookup. Returns the NodeGroup whose primary membership contains
`node_id`, or nothing.
"""
function group_for(node_id::String)::Union{NodeGroup, Nothing}
    return lock(GROUP_LOCK) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) && return nothing
        return get(GROUP_MAP, gid, nothing)
    end
end

"""
    group_avg_strength(group::NodeGroup; node_map, node_lock)::Float64

GRUG: Compute the average strength of alive (non-grave, non-unlinkable) members
in a group. Used by mitosis coinflip to bias group latching probability.
Returns 0.0 if the group has no alive members (empty or all graved).
"""
function group_avg_strength(group::NodeGroup; node_map, node_lock)::Float64
    total = 0.0
    count = 0
    lock(node_lock) do
        for mid in group.members
            member = get(node_map, mid, nothing)
            isnothing(member) && continue
            member.is_grave && continue
            total += member.strength
            count += 1
        end
    end
    return count > 0 ? total / Float64(count) : 0.0
end

"""
    compute_grave_shadow(node_id::String; node_map=NODE_MAP, node_lock=NODE_LOCK,
                         group_map=GROUP_MAP, group_lock=GROUP_LOCK,
                         aiml_tribe=nothing)::Float64

GRUG BUG-010: Compute the grave shadow multiplier for a voting node.
Dead knowledge casts shadows on surviving neighbors — the more graves in
a node's scope, the deeper the shadow. This is a multiplicative penalty
applied in composite_vote_score() after frame_match_multiplier.

Scoping rules:
  - Antimatch nodes → 1.0 (suppressors don't die, don't cast shadows)
  - AIML nodes → GLOBAL: grave ratio across the entire AIML tribe
  - Regular nodes → LOCAL GROUP: grave ratio within the node's NodeGroup

Formula: shadow = 1.0 - (grave_ratio * (1.0 - GRAVE_SHADOW_FLOOR))
  where grave_ratio = grave_count / max(grave_count + alive_count, 1)
  - 0 graves → shadow = 1.0 (no penalty)
  - some graves → shadow < 1.0 (inhibited)
  - all graves → shadow = GRAVE_SHADOW_FLOOR (maximum inhibition)

If the node has no group (orphan), grave_shadow = 1.0 (no local shadow).
"""
function compute_grave_shadow(node_id::String;
                              node_map = NODE_MAP,
                              node_lock = NODE_LOCK,
                              group_map = GROUP_MAP,
                              group_lock = GROUP_LOCK,
                              aiml_tribe = nothing)::Float64
    # GRUG v7.60: Antimatch removed. All nodes can cast shadows.
    node = lock(node_lock) do
        get(node_map, node_id, nothing)
    end
    if isnothing(node)
        return 1.0  # vanished node — no opinion
    end
    # GRUG v7.60: Antimatch removed. Former antimatch nodes now follow normal shadow rules.
    if node.is_grave
        return 1.0  # already dead — no self-shadow (grave nodes don't vote anyway)
    end

    # GRUG: AIML nodes are globally active — use tribe-level grave ratio.
    if !isnothing(aiml_tribe)
        # aiml_tribe is the Dict{String, AIMLNode} for this lobe
        grave_count = 0
        alive_count = 0
        for (nid, an) in aiml_tribe
            if an.is_grave
                grave_count += 1
            else
                alive_count += 1
            end
        end
        if grave_count < VoteOrchestrator.GRAVE_SHADOW_MIN_GRAVES
            return 1.0  # not enough graves to cast a shadow
        end
        total = grave_count + alive_count
        if total <= 0
            return 1.0  # empty tribe — no opinion
        end
        grave_ratio = Float64(grave_count) / Float64(total)
        floor = VoteOrchestrator.GRAVE_SHADOW_FLOOR
        shadow = 1.0 - (grave_ratio * (1.0 - floor))
        return clamp(shadow, floor, 1.0)
    end

    # GRUG: Regular nodes are sparse — use group-scoped grave ratio.
    grp = lock(group_lock) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) ? nothing : get(group_map, gid, nothing)
    end

    if isnothing(grp)
        return 1.0  # orphan node — no local shadow
    end

    grave_cnt = grp.grave_count
    alive_cnt = length(grp.members)  # graved members already removed from members list

    if grave_cnt < VoteOrchestrator.GRAVE_SHADOW_MIN_GRAVES
        return 1.0  # not enough graves to cast a shadow
    end
    if alive_cnt <= 0 && grave_cnt <= 0
        return 1.0  # empty group — no opinion
    end

    total = Float64(grave_cnt + alive_cnt)
    grave_ratio = Float64(grave_cnt) / total
    floor = VoteOrchestrator.GRAVE_SHADOW_FLOOR
    shadow = 1.0 - (grave_ratio * (1.0 - floor))
    return clamp(shadow, floor, 1.0)
end

# ==============================================================================
# BUG-010b: INHIBITION TOKENS — "don't do" list from alive members' originals
# ==============================================================================
# GRUG: When chatter swaps a node's pattern + action_packet (Markov remix),
# the remixed content is borrowed/stolen — it's NOT the node's organic identity.
# Inhibition rules (the "don't do" list) must use the ORIGINAL content
# (pre-chatter), not the post-swap remixed stuff.
#
# GRUG BUG-011: Inhibition is AUTO-GROWTH ONLY, not latch selection.
# Latch may still attach to coherent existing groups; inhibition suppresses only
# automatic spawning/linking of redundant new coverage.
#
# Active inhibition tokens are stored per node type in GROUP_INHIBITION_BY_TYPE:
#   :voter => regular voter nodes
#   :time  => time nodes (same behavior as voter nodes, separate bucket)
# Antimatch nodes don't contribute (they're stiff suppressors, not knowledge).
# Graved nodes don't contribute (dead knowledge doesn't inhibit).
# Post-swap remixed content doesn't contribute (chatter overwrites don't inhibit).
# group.inhibition_tokens remains a legacy union/debug view for old specimens.


# GRUG BUG-011: Per-node-type inhibition buckets. Kept out of NodeGroup's
# positional constructor to avoid breaking old specimen load paths. Keyed by
# group id, then by node type (:voter or :time). (AIML nodes were tracked in
# AIMLNodeSystem, removed v8.12 — they are not NodeGroup members.)
const GROUP_INHIBITION_BY_TYPE = Dict{String, Dict{Symbol, Set{String}}}()

function _node_inhibition_type(node)::Symbol
    return is_time_node(node) ? :time : :voter
end

function _group_inhibition_tokens(group::NodeGroup, node_type::Symbol)::Set{String}
    typed = get(GROUP_INHIBITION_BY_TYPE, group.id, nothing)
    if typed === nothing
        return Set{String}()
    end
    return get(typed, node_type, Set{String}())
end

"""
    refresh_inhibition_tokens!(group::NodeGroup; node_map, node_lock, thesaurus_fn=nothing)

GRUG BUG-010b: Rebuild the group's inhibition_tokens set from alive members'
ORIGINAL pattern + action_packet content (pre-chatter), expanded by thesaurus.
Call this after: group membership changes, chatter swaps, or graving events.

Only alive (non-grave), non-antimatch members contribute. Post-swap remixed
content is ignored — only originals count.
"""
function refresh_inhibition_tokens!(
    group::NodeGroup;
    node_map = NODE_MAP,
    node_lock = NODE_LOCK,
    thesaurus_fn::Union{Function, Nothing} = nothing,
)::Nothing
    typed_tokens = Dict{Symbol, Set{String}}(:voter => Set{String}(), :time => Set{String}())

    function add_token!(bucket::Set{String}, tok)
        t = lowercase(strip(string(tok)))
        isempty(t) && return
        push!(bucket, t)
        if thesaurus_fn !== nothing
            try
                syns = thesaurus_fn(t)  # expects Vector{String} or Set{String}
                for s in syns
                    s_str = lowercase(strip(string(s)))
                    isempty(s_str) || push!(bucket, s_str)
                end
            catch
                # thesaurus lookup failure = skip expansion, token already added
            end
        end
    end

    lock(node_lock) do
        for mid in group.members
            node = get(node_map, mid, nothing)
            isnothing(node) && continue
            node.is_grave && continue
            # GRUG v7.60: antimatch removed, no skip needed

            bucket = typed_tokens[_node_inhibition_type(node)]

            # GRUG: Original pattern tokens (pre-chatter, frozen at birth)
            if !isempty(node.original_pattern)
                for tok in split(lowercase(strip(node.original_pattern)), r"\s+")
                    add_token!(bucket, tok)
                end
            end

            # GRUG: Original action_packet action names (pre-chatter)
            if !isempty(node.original_action_packet)
                action_names = _action_names_from_packet(node.original_action_packet)
                for aname in action_names
                    add_token!(bucket, aname)
                end
            end
        end
    end

    GROUP_INHIBITION_BY_TYPE[group.id] = typed_tokens
    group.inhibition_tokens = union(values(typed_tokens)...)
    group.inhibition_dirty = false
    return nothing
end

"""
    is_inhibited(pattern::String, group::NodeGroup; threshold::Float64=0.5, node_type::Symbol=:voter)::Bool

GRUG BUG-011: Check if a candidate pattern's tokens overlap too much with
the group's same-node-type inhibition bucket. If overlap >= threshold, the
pattern is "already covered" — auto-growth should not spawn/link it here.
Latch selection does not call this anymore.

threshold=0.5 means: if ≥50% of the candidate's tokens are already in the
inhibition set, it's inhibited (don't duplicate coverage).
"""
function is_inhibited(
    pattern::String,
    group::NodeGroup;
    threshold::Float64 = 0.5,
    node_type::Symbol = :voter,
    node_map = NODE_MAP,
    node_lock = NODE_LOCK,
    thesaurus_fn::Union{Function, Nothing} = nothing,
)::Bool
    # GRUG BUG-010b: Lazy refresh — if dirty, rebuild before checking.
    if group.inhibition_dirty
        try
            refresh_inhibition_tokens!(group; node_map=node_map, node_lock=node_lock, thesaurus_fn=thesaurus_fn)
        catch e
            @warn "[INHIBIT] refresh_inhibition_tokens! failed for group $(group.id): $e"
        end
    end
    active_tokens = _group_inhibition_tokens(group, node_type)
    if isempty(active_tokens) || isempty(pattern)
        return false
    end

    candidate_tokens = Set(lowercase(strip(t)) for t in split(pattern, r"\s+") if !isempty(strip(t)))
    if isempty(candidate_tokens)
        return false
    end

    overlap = length(intersect(candidate_tokens, active_tokens))
    ratio = Float64(overlap) / Float64(length(candidate_tokens))

    return ratio >= threshold
end

"""
    GroupLatchCandidate

GRUG: A candidate group for mitosis latching. Carries the group,
its pattern-similarity score (with grave-slot boost), and its pre-computed
average alive-member strength. The caller (MitosisMode) filters by strength
floor then picks one at random from the list. Analog coherence as digital
selection — the list IS the distribution, random pick IS the event.
"""
struct GroupLatchCandidate
    group::NodeGroup
    similarity_score::Float64   # GRUG: centroid pattern similarity + grave boost
    avg_strength::Float64       # GRUG: average alive-member strength
end

"""
    find_group_latch_candidates(pattern::String; node_map, node_lock, requesting_node_is_time::Bool=false)::Vector{GroupLatchCandidate}

GRUG: For mitosis autogrowth: find ALL related groups for a new node to join.
Each candidate carries pre-computed avg_strength. The caller picks one at
RANDOM from the filtered list — no ranking, no "pick best", no coinflip.
The list IS the probability distribution. Analog coherence as digital
selection. Events go where they are best used.

Criteria:
  - Group must NOT be at max_occupancy (length(members) < max_occupancy)
  - has_grave_slot groups get a +0.5 similarity boost (vacancy to fill)
  - Group centroid must have some token overlap with the new node's pattern
  - avg_strength is pre-computed for the caller's strength floor filter
  - v7.56a: time-node isolation — time nodes only see time-node groups,
    non-time nodes only see non-time-node groups (requesting_node_is_time gate)
  - Empty vector = no related group found
"""
function find_group_latch_candidates(pattern::String; node_map, node_lock, requesting_node_is_time::Bool=false, thesaurus_fn::Union{Function, Nothing}=nothing)::Vector{GroupLatchCandidate}
    candidates = GroupLatchCandidate[]

    lock(GROUP_LOCK) do
        for (gid, grp) in GROUP_MAP
            # GRUG: Full group = no room. Skip.
            if length(grp.members) >= grp.max_occupancy
                continue
            end

            # GRUG v7.56a: Time-node group isolation. Time nodes only see
            # time-node groups, non-time nodes only see non-time-node groups.
            if grp.is_time_node_group != requesting_node_is_time
                continue
            end

            # GRUG: Compute similarity between new node pattern and group centroid
            sim = _token_overlap_similarity(pattern, grp.centroid_pattern)

            # GRUG: Grave-slot groups get a big boost — they have a vacancy
            # that a new node should fill (replacing the lost member).
            if grp.has_grave_slot
                sim += 0.5
            end

            # GRUG: Don't include totally unrelated groups (sim must be > 0)
            if sim <= 0.0
                continue
            end

            # GRUG BUG-011: Inhibition is auto-growth-only. Do NOT suppress
            # latch candidates here; latch attaches to existing structure.

            # GRUG: Pre-compute average alive-member strength.
            # Caller filters by floor then picks at random.
            avg_s = group_avg_strength(grp; node_map=node_map, node_lock=node_lock)

            push!(candidates, GroupLatchCandidate(grp, sim, avg_s))
        end
    end

    return candidates
end


"""
    link_to_group_member(new_node::Node, group::NodeGroup)::Union{String, Nothing}

GRUG: For mitosis autogrowth: within a group, find the best member to link
the new node to. The member must pass BOTH similarity thresholds:
  1. Pattern similarity: Jaccard token overlap > MITOSIS_PATTERN_SIM_FLOOR (0.15)
  2. Vote (action_packet) similarity: shared action names > MITOSIS_VOTE_SIM_FLOOR (0.25)

Among members passing both thresholds, pick the strongest non-grave,
non-unlinkable one. Returns the linked member's id, or nothing.

This ensures mitosis nodes attach to genuinely related neighbors — not just
any node in the group, but one that shares both what it knows (pattern)
and how it acts (vote).
"""
const MITOSIS_PATTERN_SIM_FLOOR = 0.15   # GRUG: Min pattern Jaccard for group member link
const MITOSIS_VOTE_SIM_FLOOR   = 0.25   # GRUG: Min vote overlap for group member link

# GRUG (v9.2): Relational+thesaurus-guided latching — pattern-bind minus votes.
# Used by _scan_latch_candidates() for the autonomous growth path.
const LATCH_SCAN_CONFIDENCE_FLOOR = 0.60  # GRUG: Min high_res_scan confidence for latch candidate
const THES_LATCH_WEIGHT           = 0.30  # GRUG: Thesaurus proximity bonus weight in candidate score
const LATCH_CANDIDATE_TOP_N       = 5     # GRUG: How many top candidates to consider


# GRUG BUG-011: Action packets are still pipe-delimited strings. If an action
# name itself needs a literal pipe, encode it as {PIPE} or {{PIPE}} inside the
# action name. Decode only AFTER splitting packet slots so delimiters stay sane.
const ACTION_PIPE_MACROS = ("{{PIPE}}", "{PIPE}")

function expand_action_macro_string(s::AbstractString)::String
    out = String(s)
    for macro_token in ACTION_PIPE_MACROS
        out = replace(out, macro_token => "|")
    end
    return out
end

function _action_names_from_packet(packet::String)::Set{String}
    _, _, action_items = parse_action_packet(packet)
    return Set(String(item[1]) for item in action_items if !isempty(strip(String(item[1]))))
end


function link_to_group_member(new_node::Node, group::NodeGroup)::Union{String, Nothing}
    new_pattern = lowercase(strip(new_node.pattern))
    new_actions = _action_names_from_packet(new_node.action_packet)

    best_id    = nothing
    best_score = -1.0

    lock(NODE_LOCK) do
        for mid in group.members
            member = get(NODE_MAP, mid, nothing)
            isnothing(member) && continue
            member.is_grave && continue
            member.is_unlinkable && continue
            mid == new_node.id && continue

            # GRUG: Threshold 1 — Pattern similarity (Jaccard token overlap)
            pat_sim = _token_overlap_similarity(new_node.pattern, member.pattern)
            if pat_sim < MITOSIS_PATTERN_SIM_FLOOR
                continue
            end

            # GRUG: Threshold 2 — Vote similarity (shared action names)
            member_actions = _action_names_from_packet(member.action_packet)
            if !isempty(new_actions) && !isempty(member_actions)
                shared = length(intersect(new_actions, member_actions))
                total = length(union(new_actions, member_actions))
                vote_sim = total > 0 ? Float64(shared) / Float64(total) : 0.0
            else
                # GRUG: No actions to compare = assume unrelated
                vote_sim = 0.0
            end
            if vote_sim < MITOSIS_VOTE_SIM_FLOOR
                continue
            end

            # GRUG: Score = strength * pattern_sim * (1 + vote_sim)
            # Stronger, more similar members rank higher.
            score = member.strength * pat_sim * (1.0 + vote_sim)
            if score > best_score
                best_score = score
                best_id = mid
            end
        end
    end

    # GRUG: Link the nodes if we found a match
    if best_id !== nothing
        member = lock(NODE_LOCK) do
            get(NODE_MAP, best_id, nothing)
        end
        if member !== nothing
            linked = try_link_nodes!(new_node, member)
            if linked
                return best_id
            end
        end
    end

    return nothing
end

# ==============================================================================
# RELATIONAL+THESAURUS-GUIDED LATCH SCAN (v9.2 — pattern-bind minus votes)
# ==============================================================================
# GRUG: This replaces find_group_latch_candidates() in the autonomous growth
# path. Instead of Jaccard token overlap on group centroids, it uses the full
# pattern-bind pipeline: SigilPromoter canonicalization → relational triple
# extraction → high_res_scan confidence → evaluate_relational_dialectics →
# thesaurus proximity bonus → action_packet vote overlap gate.
#
# Three gates must ALL pass for a candidate node:
#   1. scan_conf > LATCH_SCAN_CONFIDENCE_FLOOR   (float-hash pattern match)
#   2. rel_score >= 0                             (relational overlap, -9999.0 = hard reject)
#   3. vote_overlap > MITOSIS_VOTE_SIM_FLOOR      (action_packet name overlap)
#
# Candidate score = scan_conf + rel_score + thes_bonus
# NO VOTE ACTIVATION — candidates are never fired, never enter VoteOrchestrator.
#
# Only non-grave, non-UNLINKABLE, non-image nodes in groups qualify.
# qualify. Time nodes and match nodes participate. Batch size limited to 1000
# (same as ACTIVE_FIRE_CAP) to keep scan bounded on large specimens.

# GRUG: Latch candidate struct for the relational+thesaurus pipeline.
# Carries more signal than the old GroupLatchCandidate (which only had
# similarity_score + avg_strength). This one carries the composite score
# and all three gate results for debug visibility.
struct LatchCandidate
    node_id::String                     # GRUG: The candidate node's ID
    group::NodeGroup                    # GRUG: The group this node belongs to
    scan_conf::Float64                  # GRUG: high_res_scan confidence (gate 1)
    rel_score::Float64                  # GRUG: evaluate_relational_dialectics score (gate 2)
    vote_overlap::Float64               # GRUG: action_packet name overlap (gate 3)
    thes_bonus::Float64                 # GRUG: thesaurus proximity bonus
    composite_score::Float64            # GRUG: scan_conf + rel_score + thes_bonus
    avg_strength::Float64               # GRUG: pre-computed group avg strength
end

"""
    _scan_latch_candidates(pattern, action_packet; kwargs...) -> Vector{LatchCandidate}

GRUG: Find candidate nodes for group latching using the relational+thesaurus
pipeline. This is the pattern-bind phase minus vote activation. Returns scored
candidates sorted by composite_score (descending). Caller picks from top-N.

When pipeline functions (sigil_promote_fn, extract_triples_fn, etc.) are not
provided, falls back to simpler checks — still better than Jaccard-only.
"""
function _scan_latch_candidates(
    pattern::String,
    action_packet::String;
    node_map,
    node_lock,
    lobe_id::String = "",
    thesaurus_fn::Union{Function, Nothing} = nothing,
    sigil_promote_fn::Union{Function, Nothing} = nothing,
    extract_triples_fn::Union{Function, Nothing} = nothing,
    evaluate_dialectics_fn::Union{Function, Nothing} = nothing,
    words_to_signal_fn::Union{Function, Nothing} = nothing,
    batch_size::Int = 1000,
)::Vector{LatchCandidate}
    candidates = LatchCandidate[]

    # GRUG: Step 1 — Canonicalize the pattern via SigilPromoter if available.
    # Thesaurus canonicalization rewrites surface variants ("two plus two" → "2 + 2")
    # so a new node with pattern "calculate sum" can match "compute addition".
    canonical_pattern = pattern
    if sigil_promote_fn !== nothing
        try
            promoted = sigil_promote_fn(pattern)
            # GRUG: promote_input returns (rewritten, bindings). We just need the text.
            if isa(promoted, Tuple) && length(promoted) >= 1 && !isempty(promoted[1])
                canonical_pattern = String(promoted[1])
            elseif isa(promoted, AbstractString) && !isempty(promoted)
                canonical_pattern = String(promoted)
            end
        catch
            # GRUG: SigilPromoter failure = use raw pattern. Not fatal.
        end
    end

    # GRUG: Step 2 — Extract relational triples from the canonical pattern.
    # These (subject, relation, object) triples are compared against each
    # candidate node's relational_patterns via evaluate_relational_dialectics.
    new_triples = if extract_triples_fn !== nothing
        try
            extract_triples_fn(canonical_pattern)
        catch
            # GRUG: Triple extraction failure = empty triples. Pipeline continues
            # without relational gating — relies on scan_conf + vote_overlap only.
            []
        end
    else
        []
    end

    # GRUG: Step 3 — Build the new node's float-hash signal for pattern scanning.
    # high_res_scan needs a Vector{Float64} target signal.
    new_signal = if words_to_signal_fn !== nothing
        try
            words_to_signal_fn(canonical_pattern)
        catch
            Float64[]
        end
    else
        Float64[]
    end

    # GRUG: Extract action names from the new node's action_packet for vote overlap.
    new_action_names = _action_names_from_packet(action_packet)

    # GRUG: Step 4 — Scan candidate nodes. Batch-limited.
    # Collect nodes that are: not grave, not UNLINKABLE, not image,
    # in a group, and (optionally) in the same lobe or connected lobes.
    # GRUG: Three-phase lock strategy to avoid deadlock AND avoid reading
    # NODE_TO_GROUP under the wrong lock. NODE_TO_GROUP is written under
    # GROUP_LOCK, so we must read it under GROUP_LOCK too.
    #
    # Phase 1 (node_lock): Collect candidate node IDs and hard-filter flags.
    #   No NODE_TO_GROUP access here — just node_map reads.
    # Phase 2 (GROUP_LOCK): Look up NODE_TO_GROUP + GROUP_MAP, filter to
    #   groups with room. Returns (node_id, group) pairs.
    # Phase 3 (node_lock): Fetch actual node objects for scoring.
    _candidate_nids = lock(node_lock) do
        nids = String[]
        for node in values(node_map)
            # GRUG: Hard filters — these never participate in latching
            node.is_grave && continue
            node.is_unlinkable && continue
            node.is_image_node && continue
            # GRUG v7.60: antimatch removed, no skip needed
            push!(nids, node.id)
            length(nids) >= batch_size && break
        end
        return nids
    end

    # GRUG: Phase 2 — under GROUP_LOCK, look up group membership + room.
    _eligible_pairs = lock(GROUP_LOCK) do
        eligible = Tuple{String, NodeGroup}[]  # (node_id, group)
        for nid in _candidate_nids
            gid = get(NODE_TO_GROUP, nid, nothing)
            isnothing(gid) && continue
            grp = get(GROUP_MAP, gid, nothing)
            isnothing(grp) && continue
            if length(grp.members) >= grp.max_occupancy && !grp.has_grave_slot
                continue
            end
            push!(eligible, (nid, grp))
        end
        return eligible
    end

    # GRUG: Phase 3 — back under node_lock, fetch the actual node objects.
    candidate_nodes = lock(node_lock) do
        result = Tuple{Any, Any}[]  # (node, group)
        for (nid, grp) in _eligible_pairs
            node = get(node_map, nid, nothing)
            isnothing(node) && continue
            push!(result, (node, grp))
        end
        return result
    end

    if isempty(candidate_nodes)
        return candidates
    end

    # GRUG: Step 5 — Score each candidate through the three-gate pipeline.
    for (node, grp) in candidate_nodes
        try
            # GRUG BUG-010b: If this group's inhibition tokens already cover the
            # candidate pattern, skip — semantic territory already occupied by
            # alive members' ORIGINAL content (pre-chatter).
            inhibit_type = grp.is_time_node_group ? :time : :voter
            if is_inhibited(pattern, grp; node_type=inhibit_type, node_map=node_map, node_lock=node_lock, thesaurus_fn=thesaurus_fn)
                continue
            end
            # ── GATE 1: Pattern scan confidence ────────────────────────────
            scan_conf = 0.0
            if !isempty(new_signal) && words_to_signal_fn !== nothing
                try
                    node_signal = words_to_signal_fn(node.pattern)
                    if !isempty(node_signal) && !isempty(new_signal)
                        # GRUG: high_res_scan needs target >= pattern length.
                        # The longer signal is the target; the shorter is the pattern.
                        if length(node_signal) >= length(new_signal) && length(new_signal) >= 2
                            try
                                # GRUG: high_res_scan throws PatternNotFoundError when no match.
                                # We catch that and treat it as scan_conf = 0 (below threshold).
                                (_, conf) = PatternScanner.high_res_scan(
                                    node_signal, new_signal;
                                    tolerance=0.05, threshold=LATCH_SCAN_CONFIDENCE_FLOOR
                                )
                                scan_conf = conf
                            catch
                                # GRUG: PatternNotFoundError or other scan error = no match.
                                # Fall back to token overlap as a cheaper check.
                                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                            end
                        elseif length(new_signal) >= length(node_signal) && length(node_signal) >= 2
                            try
                                # GRUG: Reversed — new node signal is longer, it's the target.
                                (_, conf) = PatternScanner.high_res_scan(
                                    new_signal, node_signal;
                                    tolerance=0.05, threshold=LATCH_SCAN_CONFIDENCE_FLOOR
                                )
                                scan_conf = conf
                            catch
                                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                            end
                        else
                            # GRUG: Signal too short for high_res_scan. Use token overlap.
                            scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                        end
                    else
                        scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                    end
                catch
                    # GRUG: Signal computation failed. Use token overlap fallback.
                    scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                end
            else
                # GRUG: No signal function available. Use token overlap.
                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
            end

            # GRUG: Gate 1 check — scan confidence must exceed floor.
            if scan_conf < LATCH_SCAN_CONFIDENCE_FLOOR
                continue
            end

            # ── GATE 2: Relational dialectics ──────────────────────────────
            rel_score = 0.0
            if evaluate_dialectics_fn !== nothing && !isempty(new_triples)
                try
                    (score, is_anti) = evaluate_dialectics_fn(
                        new_triples,
                        node.relational_patterns,
                        node.required_relations,
                        node.relation_weights
                    )
                    # GRUG: -9999.0 sentinel = hard reject (missing required relation).
                    # is_anti = true = antimatch detected (inverse subject/object).
                    if score == -9999.0 || is_anti
                        continue  # GRUG: Hard reject — skip this candidate entirely.
                    end
                    rel_score = score
                catch
                    # GRUG: Dialectics evaluation failed. Neutral score (0.0).
                    # Pipeline continues with scan_conf + vote_overlap only.
                    rel_score = 0.0
                end
            end

            # GRUG: Gate 2 check — rel_score must be >= 0 (not hard-rejected).
            # (Already handled by the continue above for -9999.0 and antimatch.)
            if rel_score < 0.0
                continue
            end

            # ── GATE 3: Vote (action_packet) overlap ───────────────────────
            vote_overlap = 0.0
            if !isempty(new_action_names)
                member_actions = _action_names_from_packet(node.action_packet)
                if !isempty(member_actions)
                    shared = length(intersect(new_action_names, member_actions))
                    total = length(union(new_action_names, member_actions))
                    vote_overlap = total > 0 ? Float64(shared) / Float64(total) : 0.0
                end
            end

            # GRUG: Gate 3 check — vote overlap must exceed floor.
            if vote_overlap < MITOSIS_VOTE_SIM_FLOOR
                continue
            end

            # ── THESAURUS PROXIMITY BONUS ──────────────────────────────────
            # GRUG: Near-synonyms expand reach beyond exact token match.
            # "calculate" is close to "compute" in thesaurus space.
            thes_bonus = 0.0
            if thesaurus_fn !== nothing
                try
                    pat_tokens = split(lowercase(strip(canonical_pattern)))
                    node_tokens = split(lowercase(strip(node.pattern)))
                    best_thes = 0.0
                    for pt in pat_tokens
                        for nt in node_tokens
                            try
                                sim = thesaurus_fn(String(pt), String(nt))
                                if sim > best_thes
                                    best_thes = sim
                                end
                            catch; end
                            # GRUG: Early exit if we already have a strong match
                            best_thes >= 0.8 && break
                        end
                        best_thes >= 0.8 && break
                    end
                    thes_bonus = best_thes * THES_LATCH_WEIGHT
                catch
                    # GRUG: Thesaurus failure = no bonus. Not fatal.
                end
            end

            # ── COMPOSITE SCORE ─────────────────────────────────────────────
            composite = scan_conf + rel_score + thes_bonus

            # GRUG: Grave-slot boost — group with a vacancy gets a bonus
            # because a new node fills a meaningful gap.
            if grp.has_grave_slot
                composite += 0.5
            end

            # GRUG: Pre-compute avg_strength for the caller's coinflip.
            avg_str = group_avg_strength(grp; node_map=node_map, node_lock=node_lock)

            push!(candidates, LatchCandidate(
                node.id, grp, scan_conf, rel_score, vote_overlap,
                thes_bonus, composite, avg_str
            ))
        catch
            # GRUG: Per-candidate failure doesn't kill the whole scan.
            # Skip this node and continue with the rest.
            continue
        end
    end

    # GRUG: Sort by composite score descending. Caller picks from top-N.
    sort!(candidates, by = c -> -c.composite_score)

    return candidates
end

"""
    chatter_cooldown_remaining(node_id::String)::Float64

GRUG: Seconds until the node may chatter again. 0.0 means "go ahead".
Negative-safe: clamps at 0.0.
"""
function chatter_cooldown_remaining(node_id::String)::Float64
    return lock(CHATTER_NODE_COOLDOWN_LOCK) do
        last = get(CHATTER_NODE_COOLDOWN, node_id, 0.0)
        last == 0.0 && return 0.0
        elapsed = time() - last
        return max(0.0, CHATTER_NODE_COOLDOWN_SECONDS - elapsed)
    end
end

"""
    stamp_chatter!(node_id::String)

GRUG: Record that this node just participated in chatter. Resets its
1-hour cooldown clock.
"""
function stamp_chatter!(node_id::String)
    lock(CHATTER_NODE_COOLDOWN_LOCK) do
        CHATTER_NODE_COOLDOWN[node_id] = time()
    end
end

# GRUG: Handoff slot so scan_and_expand relay pass can reuse the FireCounter
# built by scan_specimens for this cycle. All fire paths share one counter so
# the 1000 cap is enforced GLOBALLY — attachments, drop-table, and cascade all
# count toward the same limit. Protected by NODE_LOCK implicitly (only written
# by scan_specimens under its own flow).
const _LAST_FIRE_COUNTER = Ref{Union{Nothing, VoteOrchestrator.FireCounter}}(nothing)
const _FIRE_COUNTER_LOCK = ReentrantLock()

"""
    get_fire_counter() -> Union{Nothing, VoteOrchestrator.FireCounter}

Thread-safe read of _LAST_FIRE_COUNTER. Used by Main.jl scan telemetry.
"""
get_fire_counter() = lock(_FIRE_COUNTER_LOCK) do; _LAST_FIRE_COUNTER[] end

# GRUG: Hard cap on how many bridges a node can have. User said 4.
# Each bridge is bidirectional, so MAX_BRIDGES=4 means 4 partners per node.
const MAX_BRIDGES = 4
# GRUG: Backward compat alias
const MAX_ATTACHMENTS = MAX_BRIDGES

# GRUG: Small stochastic jitter applied to co-fired node confidence.
# Biologically motivated — synaptic relay is noisy. Same neuron doesn't fire
# with identical strength every time it gets woken by a relay. Keeps the vote
# pool from collapsing to the same winner every cycle when attachments fire.
# Magnitude is small (sigma=0.05) so it nudges but never dominates.
const RELAY_CONF_JITTER_SIGMA = 0.05

# v10-coherence-fix: CASCADE-RELAY CONFIDENCE DISCOUNT.
# Applied to bridge-handoff (cascade) node confidence at injection time, BEFORE
# score_lobes runs. Bridges are context co-activations, not direct answers — a
# bridged partner must never out-rank the genuine primary content match. At 0.35
# a bridge node carrying base_confidence 0.4 enters the pool at ~0.14, well below
# any real primary content match (which scores 0.6+ on exact-pattern overlap),
# so it can co-activate for generative context without stealing the winner crown.
const CASCADE_RELAY_CONF_DISCOUNT = 0.35


# SMELL-004: Pattern-scan acceptance thresholds. These were inline magic
# numbers at the cheap/medium/high scan dispatch site. Promoted to named
# constants so tuning is centralized and meaning is documented.
#
#   CHEAP_SCAN_THRESHOLD  — bidirectional scan for short signals (≤3 tokens).
#                            High because short patterns have LOW discrimination
#                            on overlap math — a 0.3 floor lets a single fuzzy
#                            character span trigger a "match," which causes
#                            unrelated lobes to all fire on short inputs and
#                            produces routing-by-coinflip on the resulting
#                            0.55-0.57 plateau. 0.6 means the cheap scan only
#                            says "yes" when most of the short pattern is
#                            actually present in the input. Cheap stays cheap;
#                            it just stops rubber-stamping non-matches.
#   MEDIUM_SCAN_THRESHOLD — standard medium-resolution scan.
#   HIGH_SCAN_THRESHOLD   — full high-resolution scan; strict acceptance.
const CHEAP_SCAN_THRESHOLD  = 0.6
const MEDIUM_SCAN_THRESHOLD = 0.4
const HIGH_SCAN_THRESHOLD   = 0.5

# BUG-004 PENALTY: When pattern tokens > input tokens, the cheap bidirectional
# scan with swapped arguments is inherently less reliable. This penalty fraction
# is subtracted from token_conf to downrank these matches vs properly-sized ones.
const BUG_004_PENALTY = 0.25

# GRUG v7.49: Anti-match drain constants.
# ANTIMATCH_DRAIN_FIXED: fixed confidence drain per activation for NONJITTER anti-match nodes.
# ANTIMATCH_DRAIN_MAX_JITTER: upper bound for random (jittered) confidence drain per activation.
# Actual jitter drain = rand() * ANTIMATCH_DRAIN_MAX_JITTER.
const ANTIMATCH_DRAIN_FIXED      = 0.03   # GRUG: fixed tick for NONJITTER anti-match
const ANTIMATCH_DRAIN_MAX_JITTER = 0.05   # GRUG: max random tick drain per activation

# GRUG: STOPWORDS — closed-class function words that overlap nearly everything.
# Used by the literal-token pre-gate in fire_one() to distinguish "shared
# content word" (real lexical hit) from "shared stop-word" (noise). A pattern
# that overlaps the input only on tokens like `the`, `for`, `a` is not a real
# lexical hit and should not bypass the coinflip — those overlaps are statistical
# noise, not semantic signal. Compact list focused on grug-tier prose; keep
# function-only (no nouns or verbs).
const STOPWORDS = Set([
    "a", "an", "the",
    "i", "you", "we", "he", "she", "it", "they", "me", "us", "him", "her", "them",
    "my", "your", "our", "his", "their", "its",
    "is", "am", "are", "was", "were", "be", "been", "being",
    "do", "does", "did", "have", "has", "had",
    "to", "of", "in", "on", "at", "for", "with", "by", "from", "as",
    "and", "or", "but", "if", "so", "than", "then",
    "this", "that", "these", "those",
    "not", "no",
    "up", "down",
    # GRUG: Question words — "what", "who", "how" etc. are closed-class
    # function words that match nearly everything. Without them in STOPWORDS,
    # "what" counts as a content token in the literal pre-gate, giving
    # conversation nodes a literal_hit on "What is the quadratic formula"
    # even though "what" carries zero domain signal.
    "what", "who", "how", "why", "when", "where", "which",
])


"""
    bridge_nodes!(node_a::String, node_b::String; seam_tokens::Vector{String}=String[])::String

GRUG v8.0: MATCH-CASCADE BRIDGE! Replace the dumb one-way middle-man nodeattach
with a two-way bridge. When node A fires, the scanner's unmatched tail (the
match boundary cutoff) is handed off to node B's lobe. Vice versa from B→A.
No more fabricated connector pattern — the ACTUAL unmatched tokens at the seam
become the bridge payload. Both sides know about each other (bidirectional).

JIT CONFIDENCE BAKING: Same as old attach_node! but now symmetric:
  base_confidence_AB = token_overlap(node_A.pattern, node_B.pattern)
  base_confidence_BA = token_overlap(node_A.pattern, node_B.pattern)
v8.26e: STRENGTH BONUS REMOVED. Old formula included (partner.strength/CAP)*0.5
which let high-strength nodes like thermodynamics (8.0) get +0.40 bonus on
bridges, passing SCAN_CONFIDENCE_LOCK even with zero overlap. Now confidence
is purely pattern overlap — no strength bias.

SEAM TOKENS: The tokens at the match boundary where the source lobe's scanner
cut off. These become the handoff payload — the receiving lobe's scanner
processes these tokens directly. If empty at bridge time, they'll be populated
at fire time from the actual scanner match boundary. For manual /nodeBridge
commands, seam_tokens come from the user's pattern argument (backward compat).

Validation (error-first, NO silent failures):
  - Both nodes must exist in NODE_MAP and not be grave
  - node_a ≠ node_b (no self-bridging, that's a loop not a bridge)
  - Neither node can already have MAX_BRIDGES (4) bridges
  - node_a and node_b cannot already be bridged (no duplicate bridges)

Returns confirmation string on success.
"""

# GRUG: Safe Lobe access — Lobe module may not be loaded when engine runs standalone
_safe_find_lobe(node_id::String) = isdefined(@__MODULE__, :Lobe) ? something(Lobe.find_lobe_for_node(node_id), "") : ""
_safe_lobe_registry_has(lobe_id::String) = isdefined(@__MODULE__, :Lobe) && haskey(Lobe.LOBE_REGISTRY, lobe_id)

function bridge_nodes!(node_a::String, node_b::String;
                       seam_tokens::Vector{String}=String[])::String
    if strip(node_a) == ""
        error("!!! FATAL: bridge_nodes! got empty node_a! Grug needs a real node! !!!")
    end
    if strip(node_b) == ""
        error("!!! FATAL: bridge_nodes! got empty node_b! Grug needs a real partner! !!!")
    end
    if node_a == node_b
        error("!!! FATAL: bridge_nodes! '$node_a' cannot bridge to itself! That's a loop, not a bridge! !!!")
    end

    # GRUG: Validate both nodes exist and are alive
    lobe_a = ""
    lobe_b = ""
    lock(NODE_LOCK) do
        if !haskey(NODE_MAP, node_a)
            error("!!! FATAL: bridge_nodes! node '$node_a' does not exist on the map! !!!")
        end
        if !haskey(NODE_MAP, node_b)
            error("!!! FATAL: bridge_nodes! node '$node_b' does not exist on the map! !!!")
        end
        na = NODE_MAP[node_a]
        nb = NODE_MAP[node_b]
        if na.is_grave
            error("!!! FATAL: bridge_nodes! node '$node_a' is GRAVE [$(na.grave_reason)]! Cannot bridge dead nodes! !!!")
        end
        if nb.is_grave
            error("!!! FATAL: bridge_nodes! node '$node_b' is GRAVE [$(nb.grave_reason)]! Cannot bridge dead nodes! !!!")
        end
    end

    # GRUG: Resolve lobe provenance for both sides of the bridge
    lobe_a = _safe_find_lobe(node_a)
    lobe_b = _safe_find_lobe(node_b)

    # GRUG v8.26e: JIT CONFIDENCE BAKING — symmetric, no strength bonus.
    # Bridge confidence is purely based on token pattern overlap between
    # the two nodes. No strength bias per user directive.
    overlap = lock(NODE_LOCK) do
        na = NODE_MAP[node_a]
        nb = NODE_MAP[node_b]
        return _token_overlap_similarity(na.pattern, nb.pattern)
    end
    # GRUG v8.26e: STRENGTH REMOVED from JIT confidence baking. Per user
    # directive: "strength should not bias confidence at all." The old formula
    # was `overlap + (partner.strength / CAP) * 0.5`, which gave strong nodes
    # like thermodynamics (str=8.0) an extra 0.40 confidence on bridges —
    # enough to pass SCAN_CONFIDENCE_LOCK (0.35) even with zero overlap.
    # This caused fire→thermo cascade to fire and dominate the answer.
    # Now bridge confidence is purely based on token pattern overlap.
    jit_conf_a_to_b = overlap
    jit_conf_b_to_a = overlap

    lock(BRIDGE_LOCK) do
        # GRUG: Check bridge caps on BOTH sides (bidirectional = both must have room)
        existing_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        if length(existing_a) >= MAX_BRIDGES
            error("!!! FATAL: bridge_nodes! node '$node_a' already has $(length(existing_a)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end
        existing_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        if length(existing_b) >= MAX_BRIDGES
            error("!!! FATAL: bridge_nodes! node '$node_b' already has $(length(existing_b)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end

        # GRUG: Check for duplicate bridge (either direction)
        for br in existing_a
            if br.partner_id == node_b
                error("!!! FATAL: bridge_nodes! '$node_a' is already bridged to '$node_b'! No duplicate bridges! !!!")
            end
        end
        for br in existing_b
            if br.partner_id == node_a
                error("!!! FATAL: bridge_nodes! '$node_b' is already bridged to '$node_a'! Bidirectional bridge already exists! !!!")
            end
        end

        # GRUG: All checks passed. Create bidirectional bridge entries!
        # A→B entry: partner is B, source_lobe is B's lobe (provenance = "came from B's lobe")
        # B→A entry: partner is A, source_lobe is A's lobe (provenance = "came from A's lobe")
        bridge_a_to_b = CascadeBridge(node_b, seam_tokens, jit_conf_a_to_b, lobe_b, false, :none)
        bridge_b_to_a = CascadeBridge(node_a, seam_tokens, jit_conf_b_to_a, lobe_a, false, :none)

        push!(existing_a, bridge_a_to_b)
        BRIDGE_MAP[node_a] = existing_a
        push!(existing_b, bridge_b_to_a)
        BRIDGE_MAP[node_b] = existing_b
    end

    n_bridged_a = lock(() -> length(get(BRIDGE_MAP, node_a, CascadeBridge[])), BRIDGE_LOCK)
    n_bridged_b = lock(() -> length(get(BRIDGE_MAP, node_b, CascadeBridge[])), BRIDGE_LOCK)
    cross_lobe_tag = lobe_a != lobe_b ? " [CROSS-LOBE: $lobe_a ↔ $lobe_b]" : ""
    seam_preview = isempty(seam_tokens) ? "(seam tokens populated at fire time)" : "\"$(join(seam_tokens, " "))\""
    println("[ENGINE] 🌉  Bridge: '$node_a' ↔ '$node_b'$cross_lobe_tag | seam=$seam_preview | conf_A→B=$(round(jit_conf_a_to_b, digits=3)), conf_B→A=$(round(jit_conf_b_to_a, digits=3)) | A: $n_bridged_a/$MAX_BRIDGES, B: $n_bridged_b/$MAX_BRIDGES")
    return "Bridged '$node_a' ↔ '$node_b'$cross_lobe_tag | seam=$seam_preview | conf_A→B=$(round(jit_conf_a_to_b, digits=3)), B→A=$(round(jit_conf_b_to_a, digits=3)) | A: $n_bridged_a/$MAX_BRIDGES, B: $n_bridged_b/$MAX_BRIDGES"
end

# GRUG: Backward-compat wrapper — old /nodeAttach calls still work.
# Converts the old (target_id, attach_id, pattern) signature into the new
# bidirectional bridge. The pattern becomes seam_tokens (split on whitespace).
function attach_node!(target_id::String, attach_id::String, pattern::String)::String
    if isempty(strip(pattern))
        error("!!! FATAL: attach_node! got empty pattern! Grug needs a real relay pattern! !!!")
    end
    seam = String.(split(strip(pattern)))
    return bridge_nodes!(target_id, attach_id; seam_tokens=seam)
end

"""
    unbridge_nodes!(node_a::String, node_b::String)::String

GRUG v8.0: Remove a bidirectional bridge between two nodes. Both sides of
the bridge entry are removed — BRIDGE_MAP[node_a] loses the B entry AND
BRIDGE_MAP[node_b] loses the A entry. No half-bridges allowed.

Returns confirmation string. Errors if bridge doesn't exist.
"""
function unbridge_nodes!(node_a::String, node_b::String)::String
    if strip(node_a) == ""
        error("!!! FATAL: unbridge_nodes! got empty node_a! !!!")
    end
    if strip(node_b) == ""
        error("!!! FATAL: unbridge_nodes! got empty node_b! !!!")
    end

    lock(BRIDGE_LOCK) do
        # GRUG: Remove node_b from node_a's bridge list
        found_a = false
        if haskey(BRIDGE_MAP, node_a)
            existing_a = BRIDGE_MAP[node_a]
            idx_a = findfirst(br -> br.partner_id == node_b, existing_a)
            if !isnothing(idx_a)
                deleteat!(existing_a, idx_a)
                found_a = true
                if isempty(existing_a)
                    delete!(BRIDGE_MAP, node_a)
                end
            end
        end

        # GRUG: Remove node_a from node_b's bridge list (bidirectional!)
        found_b = false
        if haskey(BRIDGE_MAP, node_b)
            existing_b = BRIDGE_MAP[node_b]
            idx_b = findfirst(br -> br.partner_id == node_a, existing_b)
            if !isnothing(idx_b)
                deleteat!(existing_b, idx_b)
                found_b = true
                if isempty(existing_b)
                    delete!(BRIDGE_MAP, node_b)
                end
            end
        end

        if !found_a && !found_b
            error("!!! FATAL: unbridge_nodes! no bridge exists between '$node_a' and '$node_b'! !!!")
        end
    end

    println("[ENGINE] 🌉💨  Bridge removed: '$node_a' ↔ '$node_b'.")
    return "Unbridged '$node_a' ↔ '$node_b'"
end

# GRUG: Backward-compat wrapper — old /nodeDetach still works
function detach_node!(target_id::String, attach_id::String)::String
    return unbridge_nodes!(target_id, attach_id)
end

"""
    confidence_biased_bridge_coinflip(node::Node, bridge_confidence::Float64)::Bool

GRUG v8.26e: STRENGTH REMOVED from bridge coinflip. Per user directive:
"strength should not bias confidence at all. strength only affects chatter
really and when things get graved." Bridge relays now use ONLY the bridge's
baked semantic confidence, not the partner's strength. This prevents
high-strength nodes from dominating cascade relays.
"""
function confidence_biased_bridge_coinflip(node::Node, bridge_confidence::Float64)::Bool
    if !isfinite(bridge_confidence)
        error("!!! FATAL: bridge_confidence must be finite, got $bridge_confidence !!!")
    end
    # GRUG v8.26e: Only confidence-based probability. No strength bias.
    confidence_bias = clamp(bridge_confidence / VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD, 0.0, 1.0)
    # Scale to [0.10, 0.90] range so very low confidence bridges still have
    # a tiny chance and very high ones aren't guaranteed.
    probability = clamp(0.10 + 0.80 * confidence_bias, 0.0, 1.0)
    return rand() < probability
end

"""
    fire_cascades!(source_id::String, active_count::Int, active_cap::Int;
                  unmatched_tail::Vector{String}=String[])::Vector{Tuple{String, Float64, String}}

GRUG v8.0: MATCH-CASCADE HANDOFF! Replaces the old dumb fire_attachments!.
When a node fires, its bridge partners get the unmatched tail of the input —
the tokens the scanner DIDN'T match. This is the match-boundary cutoff, and
it IS the natural cross-lobe bridge. No more fabricated connector pattern
middle-man. The receiving lobe's scanner processes these tokens directly.

Bidirectional: When A fires and checks BRIDGE_MAP[A], it finds B. When B fires
and checks BRIDGE_MAP[B], it finds A. Both directions work. No more one-way derp.

CRYSTALIZE: Crystalized bridges skip the coinflip and always fire. Same
:user/:auto/:none system as before. The auto-crystallizer still works.

JIT CONFIDENCE: base_confidence was baked at bridge time using symmetric
pattern overlap + partner strength bonus. At fire time, only stochastic
jitter is applied: max(0.1, base_confidence + randn() * RELAY_CONF_JITTER_SIGMA)
Same as before but without the dumb connector pattern.

MATCH-BOUNDARY HANDOFF: The unmatched_tail parameter carries the tokens that
the source lobe's scanner couldn't match. These are the seam tokens — the
bridge payload. When the partner node is in a different lobe, this tail gets
handed to that lobe's scanner for processing. Same-lobe bridges also benefit
because the tail carries context the primary scan missed.

active_count = how many nodes have already fired this scan cycle
active_cap   = the biological attention bottleneck limit for this cycle

Returns: Vector of (partner_id, confidence, seam_text) triples.
         seam_text is the join of seam_tokens for generative context.
"""
function fire_cascades!(source_id::String, active_count::Int, active_cap::Int;
                        unmatched_tail::Vector{String}=String[])::Vector{Tuple{String, Float64, String}}
    fired = Tuple{String, Float64, String}[]

    # GRUG v8.0 FIX: Copy the bridge vector under BRIDGE_LOCK so we have an
    # immutable snapshot. Without copy, we hold a reference to the live vector
    # inside BRIDGE_MAP — another task could push!/filter! it after we release
    # BRIDGE_LOCK, causing a concurrent modification race during NODE_LOCK iteration.
    bridges = lock(() -> copy(get(BRIDGE_MAP, source_id, CascadeBridge[])), BRIDGE_LOCK)
    if isempty(bridges)
        return fired
    end

    lock(NODE_LOCK) do
        # GRUG: Verify source still exists. Non-fatal if gone.
        source_node = get(NODE_MAP, source_id, nothing)
        if isnothing(source_node)
            @warn "[ENGINE] ⚠ fire_cascades!: source '$source_id' vanished from NODE_MAP."
            return
        end

        source_lobe = _safe_find_lobe(source_id)
        current_active = active_count

        for br in bridges
            # GRUG: ACTIVE CAP GATE! Biological attention limit.
            if current_active >= active_cap
                println("[ENGINE] 🧠  Cascade handoff halted for '$source_id' — active cap ($active_cap) reached.")
                break
            end

            # GRUG: Check partner node still exists and is alive
            partner_ref = get(NODE_MAP, br.partner_id, nothing)
            if isnothing(partner_ref)
                # Partner was deleted/graved. Stale bridge. Skip.
                continue
            end
            if partner_ref.is_grave
                # Dead nodes don't fire. Skip.
                continue
            end

            # GRUG v8.0: NO MORE CROSS-LOBE SUPPRESSION! The old system had a
            # hack that suppressed cross-lobe attachments and redirected to cascade
            # PASS 2. That's gone now. The match-cascade handoff IS the cross-lobe
            # bridge. When source is in lobe A and partner is in lobe B, the
            # unmatched tail carries provenance (which lobe, which node, seam tokens)
            # so lobe B's scanner knows exactly where the handoff came from.
            # This is the whole point of the rework — cross-lobe works NATURALLY.
            partner_lobe = _safe_find_lobe(br.partner_id)
            is_cross_lobe = source_lobe != "" && partner_lobe != "" && source_lobe != partner_lobe

            # GRUG v8.0: CONFIDENCE-BIASED BRIDGE COINFLIP! Not the same as scan
            # coinflip anymore. Bridge relays now bias by BOTH partner strength AND
            # the bridge's base_confidence relative to AIML_CONFIDENCE_THRESHOLD.
            # High-confidence bridges fire more reliably. Weak ones still get a chance.
            # CRYSTALIZE: crystalized bridges with high-confidence votes SKIP the
            # coinflip entirely (deterministic pass-through). Crystalized bridges with
            # LOW-confidence votes still flip — confidence must be earned.
            # NON-CRYSTALIZE: always flip, biased by strength + confidence.
            if br.is_crystalized
                # Crystalized bridge: skip coinflip ONLY for high-confidence votes.
                # Low-confidence crystalized votes still flip (must earn certainty).
                if br.base_confidence < VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD &&
                   !confidence_biased_bridge_coinflip(partner_ref, br.base_confidence)
                    continue
                end
            else
                # Non-crystalized bridge: always flip, biased by strength + confidence.
                if !confidence_biased_bridge_coinflip(partner_ref, br.base_confidence)
                    continue
                end
            end

            # GRUG: JIT CONFIDENCE — pre-baked at bridge time, just apply jitter now!
            # Same as old fire_attachments! but using CascadeBridge.base_confidence.
            # Floor of 0.1 so bridged nodes always have SOME voice.
            # NONJITTER honor and VOTE-LEVEL OVERRIDE still apply — same single-source-of-truth.
            jitter = jitter_allowed_for(partner_ref, br.base_confidence) ?
                     randn() * RELAY_CONF_JITTER_SIGMA :
                     0.0
            # GRUG v7.60-confidence-lock: Cascade confidence must also respect
            # the scan confidence lock. If the jittered confidence falls below
            # SCAN_CONFIDENCE_LOCK, the cascade node doesn't fire — it has no
            # genuine pattern relevance to the current input.
            confidence = br.base_confidence + jitter
            confidence < SCAN_CONFIDENCE_LOCK && continue

            # GRUG: MATCH-BOUNDARY HANDOFF! The seam tokens are the bridge payload.
            # At fire time, if we have an unmatched_tail from the scanner, those
            # tokens are the seam. If the bridge already has seam_tokens from
            # bridge creation time, those are used instead (backward compat).
            # For generative context, we return the seam as a text string.
            actual_seam = isempty(unmatched_tail) ? br.seam_tokens : unmatched_tail
            seam_text = join(actual_seam, " ")

            # GRUG: For cross-lobe bridges, log the handoff with provenance.
            # This is the key diagnostic — you can see exactly which lobe sent
            # what to which lobe through which seam.
            if is_cross_lobe
                println("[ENGINE] 🌉  Cross-lobe cascade: '$source_id' ($source_lobe) → '$(br.partner_id)' ($partner_lobe) | seam=\"$seam_text\" | conf=$(round(confidence, digits=3))")
            end

            push!(fired, (br.partner_id, confidence, seam_text))
            current_active += 1

            # GRUG BUG-011: Cascade/use no longer changes strength. Only lock-in feedback can.

            println("[ENGINE] ⚡  Cascade handoff: '$(br.partner_id)' fired via bridge from '$source_id' (conf=$(round(confidence, digits=3)), seam=\"$(first(seam_text, 40))\")")
        end
    end

    return fired
end

# GRUG: Backward-compat wrapper — old fire_attachments! calls still work.
# Without unmatched_tail, uses the bridge's stored seam_tokens.
function fire_attachments!(target_id::String, active_count::Int, active_cap::Int)::Vector{Tuple{String, Float64, String}}
    return fire_cascades!(target_id, active_count, active_cap)
end

"""
    get_bridge_summary()::String

GRUG v8.0: Return human-readable summary of all node bridges for /nodes or /status.
Shows bidirectional bridges with provenance, seam tokens, and crystalize status.
"""
function get_bridge_summary()::String
    lines = String[]
    # GRUG v8.0 FIX: Acquire locks in consistent order (BRIDGE_LOCK → NODE_LOCK is wrong,
    # can deadlock against bridge_nodes! which does NODE_LOCK → BRIDGE_LOCK).
    # Fix: snapshot bridge data under BRIDGE_LOCK, then read nodes under NODE_LOCK separately.
    bridge_data = lock(BRIDGE_LOCK) do
        if isempty(BRIDGE_MAP)
            return Tuple{String, Vector{CascadeBridge}}[]
        end
        collect(BRIDGE_MAP)
    end
    if isempty(bridge_data)
        return "[BRIDGE MAP EMPTY]"
    end
    push!(lines, "=== BRIDGE MAP ($(length(bridge_data)) nodes with bridges) ===")
    # GRUG: Read partner status under NODE_LOCK only
    partner_status_map = Dict{String, String}()
    lock(NODE_LOCK) do
        for (node_id, bridges) in bridge_data
            for br in bridges
                if !haskey(partner_status_map, br.partner_id)
                    n = get(NODE_MAP, br.partner_id, nothing)
                    partner_status_map[br.partner_id] = isnothing(n) ? "[MISSING]" : (n.is_grave ? "[GRAVE]" : "[ALIVE str=$(round(n.strength, digits=1))]")
                end
            end
        end
    end
    # GRUG: Now format output without holding any lock (using snapshots)
    shown_pairs = Set{Tuple{String,String}}()
    for (node_id, bridges) in sort(bridge_data, by=x->x[1])
        push!(lines, "  🌉 $node_id ($(length(bridges))/$MAX_BRIDGES bridges):")
        for br in bridges
            partner_status = get(partner_status_map, br.partner_id, "[UNKNOWN]")
            crystal_tag = br.is_crystalized ? " 💎[CRYSTAL:$(br.crystal_origin)]" : ""
            cross_tag = br.source_lobe != "" ? " [from_lobe=$(br.source_lobe)]" : ""
            seam_preview = isempty(br.seam_tokens) ? "(dynamic)" : "\"$(join(br.seam_tokens[1:min(5, length(br.seam_tokens))], " "))$(length(br.seam_tokens) > 5 ? "..." : "")\""
            push!(lines, "      ↔ $(br.partner_id) $partner_status$crystal_tag$cross_tag | base_conf=$(round(br.base_confidence, digits=3)) | seam=$seam_preview")
        end
    end
    return join(lines, "\n")
end

# GRUG: Backward compat alias
get_attachment_summary() = get_bridge_summary()

"""
    get_bridges_for_node(node_id::String)::Vector{CascadeBridge}

GRUG v8.0: Get the list of bridges for a specific node.
Returns empty vector if no bridges exist.
"""
function get_bridges_for_node(node_id::String)::Vector{CascadeBridge}
    return lock(() -> get(BRIDGE_MAP, node_id, CascadeBridge[]), BRIDGE_LOCK)
end

# GRUG: Backward compat alias
get_attachments_for_target(target_id::String) = get_bridges_for_node(target_id)

# ==============================================================================
# CRYSTALIZE — manual + auto crystalization of attached nodes
# ==============================================================================
# GRUG: A crystalized attached node SKIPS the strength-biased coinflip in
# fire_attachments! and ALWAYS fires when its target fires. Two ways to
# crystalize:
#   1. Manual:  user calls /crystalize <target_id> <attach_id>     (origin=:user)
#   2. Auto:    background sweep marks high-strength + high-semantic-truth
#               attachments as crystalized. Auto-marks are revoked when the
#               attached node's strength drops below CRYSTAL_AUTO_STRENGTH_FLOOR.
# Manual marks are sticky — only /decrystalize removes them.

# GRUG: Tunables for auto-crystalization. Tuned conservative so only nodes
# that have proven themselves get the always-fire privilege.
const CRYSTAL_AUTO_STRENGTH_FLOOR  = 5.0   # node.strength >= this to auto-crystallize
const CRYSTAL_AUTO_SEMANTIC_FLOOR  = 0.7   # mean relational-truth score >= this
const CRYSTAL_AUTO_REVOKE_FLOOR    = 3.0   # auto-crystal revoked if strength drops below this

"""
    crystalize_bridge!(node_a::String, node_b::String; origin::Symbol=:user)::String

GRUG v8.0: Mark the bridge between node_a and node_b as crystalized so it
fires unconditionally on partner activation. Crystallizes BOTH sides of the
bidirectional bridge (both A→B and B→A entries). Returns a status string.
Errors if no such bridge exists.

`origin` should be `:user` for manual marks (sticky) or `:auto` for
auto-crystallizer marks (revocable when strength drops).
"""
function crystalize_bridge!(node_a::String, node_b::String;
                            origin::Symbol = :user)::String
    if origin ∉ (:user, :auto)
        error("!!! FATAL: crystalize_bridge! origin must be :user or :auto, got :$origin !!!")
    end
    found_a = false
    found_b = false
    msg = ""
    lock(BRIDGE_LOCK) do
        # GRUG: Crystalize A→B entry
        bridges_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges_a
            if br.partner_id == node_b
                if br.is_crystalized && br.crystal_origin == origin
                    msg = "Bridge $node_a→$node_b already crystalized (origin=:$(origin))."
                else
                    br.is_crystalized = true
                    br.crystal_origin = origin
                    msg = "💎 Bridge $node_a↔$node_b CRYSTALIZED (origin=:$(origin)). Always fires."
                end
                found_a = true
                break
            end
        end

        # GRUG: Crystalize B→A entry (bidirectional!)
        bridges_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        for br in bridges_b
            if br.partner_id == node_a
                if br.is_crystalized && br.crystal_origin != origin
                    # Already crystalized from different origin — upgrade if :user overrides :auto
                    if origin == :user
                        br.is_crystalized = true
                        br.crystal_origin = origin
                    end
                else
                    br.is_crystalized = true
                    br.crystal_origin = origin
                end
                found_b = true
                break
            end
        end
    end
    if !found_a && !found_b
        error("!!! FATAL: crystalize_bridge! found no bridge between '$node_a' and '$node_b' !!!")
    end
    return msg
end

# GRUG: Backward compat wrapper — old crystalize_attachment! calls still work
function crystalize_attachment!(target_id::String, attach_id::String;
                                origin::Symbol = :user)::String
    return crystalize_bridge!(target_id, attach_id; origin=origin)
end

"""
    decrystalize_bridge!(node_a::String, node_b::String; force::Bool=false)::String

GRUG v8.0: Clear the crystalize tag on both sides of a bidirectional bridge.
By default this only clears `:auto` marks (so the auto-revoker can't
accidentally remove a manual mark). Pass `force=true` to also clear `:user`
marks (used by /decrystalize). Both sides are decrystalized.
"""
function decrystalize_bridge!(node_a::String, node_b::String;
                              force::Bool = false)::String
    found = false
    msg = ""
    lock(BRIDGE_LOCK) do
        # GRUG: Decrystalize A->B entry
        bridges_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges_a
            if br.partner_id == node_b
                if !br.is_crystalized
                    msg = "Bridge $node_a<->$node_b was not crystalized."
                elseif br.crystal_origin == :user && !force
                    msg = "Bridge $node_a<->$node_b is :user-crystalized -- pass force=true (or use /decrystalize)."
                else
                    prev = br.crystal_origin
                    br.is_crystalized = false
                    br.crystal_origin = :none
                    msg = "Bridge $node_a<->$node_b de-crystalized (was :$prev)."
                end
                found = true
                break
            end
        end

        # GRUG: Decrystalize B->A entry (bidirectional!)
        bridges_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        for br in bridges_b
            if br.partner_id == node_a
                if br.is_crystalized
                    if br.crystal_origin == :user && !force
                        # Don't clear :user marks without force
                    else
                        br.is_crystalized = false
                        br.crystal_origin = :none
                    end
                end
                found = true
                break
            end
        end
    end
    if !found
        error("!!! FATAL: decrystalize_bridge! found no bridge between '$node_a' and '$node_b' !!!")
    end
    return msg
end

# GRUG: Backward compat wrapper
function decrystalize_attachment!(target_id::String, attach_id::String;
                                  force::Bool = false)::String
    return decrystalize_bridge!(target_id, attach_id; force=force)
end


"""
    _semantic_truth_score(node) -> Float64

GRUG: Cheap semantic-truth proxy used by the auto-crystallizer. Returns a
score in [0,1] based on how well a node's relational triples are anchored:
  - fraction of triples whose verb is a registered relation class verb
  - bonus for required_relations (declared semantic anchors)
  - bonus for non-empty relation_weights map (intentional weighting)
"""
function _semantic_truth_score(node)::Float64
    triples = node.relational_patterns
    n_triples = length(triples)
    if n_triples == 0 && isempty(node.required_relations)
        return 0.0
    end

    known_verbs = try
        Set(lowercase.(SemanticVerbs.get_all_verbs()))
    catch
        Set{String}()
    end

    matched = 0
    for t in triples
        v = lowercase(strip(t.relation))
        if v in known_verbs
            matched += 1
        end
    end
    triple_score = n_triples == 0 ? 0.0 : matched / n_triples

    req_bonus  = isempty(node.required_relations) ? 0.0 : 0.20
    wts_bonus  = isempty(node.relation_weights)   ? 0.0 : 0.10

    return clamp(triple_score + req_bonus + wts_bonus, 0.0, 1.0)
end

"""
    auto_crystalize_sweep!() -> Tuple{Int, Int}

GRUG v8.0: Walk every bridge in BRIDGE_MAP. Auto-crystallize bridges
whose partner node has BOTH:
  - strength >= CRYSTAL_AUTO_STRENGTH_FLOOR, AND
  - semantic_truth_score >= CRYSTAL_AUTO_SEMANTIC_FLOOR
Auto-revoke bridges previously auto-crystalized whose partner strength has
dropped below CRYSTAL_AUTO_REVOKE_FLOOR. Manual (`:user`) marks are never
touched. Bidirectional: crystallizing one side also crystallizes the partner side.

Called from the idle / phagy sweep loop. Cheap to run — O(bridges).
"""
function auto_crystalize_sweep!()::Tuple{Int, Int}
    crystallized = 0
    revoked = 0
    # GRUG v8.0 FIX: Lock ordering must be NODE_LOCK → BRIDGE_LOCK (same as bridge_nodes!).
    # Previously this held BRIDGE_LOCK while acquiring NODE_LOCK (line 2532), which
    # could deadlock against bridge_nodes! holding NODE_LOCK and waiting for BRIDGE_LOCK.
    # Fix: snapshot all bridge data under BRIDGE_LOCK first, then read nodes under NODE_LOCK,
    # then apply mutations under BRIDGE_LOCK. No nested locks.
    
    # Step 1: Snapshot bridge entries under BRIDGE_LOCK
    bridge_snapshots = lock(BRIDGE_LOCK) do
        snapshots = Tuple{String, CascadeBridge, String}[]  # (node_id, bridge, partner_id)
        for (node_id, bridges) in BRIDGE_MAP
            for br in bridges
                push!(snapshots, (node_id, br, br.partner_id))
            end
        end
        snapshots
    end
    
    # Step 2: Read source AND partner node data under NODE_LOCK (no BRIDGE_LOCK held)
    # GRUG v8.0: Both sides must be strong for auto-crystallization. Previously
    # only the partner was checked — now source node must also exceed the floor.
    node_data = Dict{String, Tuple{Bool, Float64, Float64}}()  # node_id => (is_grave, strength, semantic_truth)
    lock(NODE_LOCK) do
        for (node_id, _br, partner_id) in bridge_snapshots
            for nid in (node_id, partner_id)
                if !haskey(node_data, nid)
                    n = get(NODE_MAP, nid, nothing)
                    if isnothing(n)
                        node_data[nid] = (true, 0.0, 0.0)  # treat missing as grave
                    else
                        node_data[nid] = (n.is_grave, n.strength, _semantic_truth_score(n))
                    end
                end
            end
        end
    end
    
    # Step 3: Apply mutations under BRIDGE_LOCK only (no NODE_LOCK held)
    lock(BRIDGE_LOCK) do
        for (node_id, br, partner_id) in bridge_snapshots
            # Re-verify the bridge still exists (could have been unbridged between steps)
            current_bridges = get(BRIDGE_MAP, node_id, CascadeBridge[])
            if !(br in current_bridges)
                continue
            end

            sd = get(node_data, node_id, (true, 0.0, 0.0))
            source_is_grave, source_strength, source_semantic = sd
            source_is_grave && continue

            pd = get(node_data, partner_id, (true, 0.0, 0.0))
            partner_is_grave, partner_strength, partner_semantic = pd
            partner_is_grave && continue

            if br.is_crystalized && br.crystal_origin == :auto
                # GRUG v8.0: Revoke if EITHER side drops below revoke floor.
                # Crystallization is a mutual commitment — both sides must maintain strength.
                if source_strength < CRYSTAL_AUTO_REVOKE_FLOOR ||
                   partner_strength < CRYSTAL_AUTO_REVOKE_FLOOR
                    br.is_crystalized = false
                    br.crystal_origin = :none
                    # GRUG: Also decrystalize the partner side (bidirectional)
                    partner_bridges = get(BRIDGE_MAP, partner_id, CascadeBridge[])
                    for pbr in partner_bridges
                        if pbr.partner_id == node_id && pbr.crystal_origin == :auto
                            pbr.is_crystalized = false
                            pbr.crystal_origin = :none
                        end
                    end
                    revoked += 1
                end
            elseif !br.is_crystalized
                # GRUG v8.0: BOTH source AND partner must exceed thresholds.
                # It takes two strong nodes to form a crystal bond — one strong
                # side isn't enough. This prevents weak nodes from free-riding
                # on a strong partner's crystal status.
                if source_strength >= CRYSTAL_AUTO_STRENGTH_FLOOR &&
                   source_semantic >= CRYSTAL_AUTO_SEMANTIC_FLOOR &&
                   partner_strength >= CRYSTAL_AUTO_STRENGTH_FLOOR &&
                   partner_semantic >= CRYSTAL_AUTO_SEMANTIC_FLOOR
                    br.is_crystalized = true
                    br.crystal_origin = :auto
                    # GRUG: Also crystalize the partner side (bidirectional)
                    partner_bridges = get(BRIDGE_MAP, partner_id, CascadeBridge[])
                    for pbr in partner_bridges
                        if pbr.partner_id == node_id && !pbr.is_crystalized
                            pbr.is_crystalized = true
                            pbr.crystal_origin = :auto
                        end
                    end
                    crystallized += 1
                end
            end
            # :user marks are sticky — never auto-touched.
        end
    end
    return (crystallized, revoked)
end

"""
    is_bridge_crystalized(node_a::String, node_b::String) -> Bool

GRUG v8.0: Convenience query. Returns false if bridge doesn't exist.
"""
function is_bridge_crystalized(node_a::String, node_b::String)::Bool
    return lock(() -> begin
        bridges = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges
            br.partner_id == node_b && return br.is_crystalized
        end
        return false
    end, BRIDGE_LOCK)
end

# GRUG: Backward compat alias
is_crystalized(target_id::String, attach_id::String) = is_bridge_crystalized(target_id, attach_id)

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
            error("!!! FATAL: attach_image_node! node '$attach_id' is NOT an image node! Use /nodeBridge for text nodes! !!!")
        end
    end

    # GRUG: JIT GPU ACCEL — Convert image binary to nonlinear SDF at attach time!
    # JITGPU() dispatches real KernelAbstractions kernels: CUDABackend() on NVIDIA,
    # ROCBackend() on AMD, MetalBackend() on Apple Silicon, CPU() on CI/no-GPU.
    # This is the expensive computation that happens ONCE, not every fire cycle.
    connector_sdf = ImageSDF.JITGPU(image_data; width=width, height=height)
    connector_signal = ImageSDF.sdf_to_signal(connector_sdf)

    # GRUG v8.0: JIT CONFIDENCE BAKING — SDF cosine similarity + strength bonus.
    # Now bidirectional: compute confidence for both directions.
    # A→B uses B's strength, B→A uses A's strength. Same SDF similarity.
    jit_conf_target_to_attach = lock(NODE_LOCK) do
        attach_node_ref = NODE_MAP[attach_id]
        if isempty(attach_node_ref.signal)
            return 0.3
        end
        sdf_sim = _sdf_signal_similarity(connector_signal, attach_node_ref.signal)
        strength_bonus = attach_node_ref.strength / STRENGTH_CAP
        return sdf_sim + (strength_bonus * 0.5)
    end

    jit_conf_attach_to_target = lock(NODE_LOCK) do
        target_node = NODE_MAP[target_id]
        if isempty(target_node.signal)
            # GRUG: Text node with no signal — use flat baseline
            return 0.3
        end
        sdf_sim = _sdf_signal_similarity(connector_signal, target_node.signal)
        strength_bonus = target_node.strength / STRENGTH_CAP
        return sdf_sim + (strength_bonus * 0.5)
    end

    # GRUG: Seam tokens for image bridges use SDF metadata as the seam marker
    sdf_seam = ["SDF:image:$(width)x$(height)"]

    # GRUG: Resolve lobe provenance
    lobe_target = _safe_find_lobe(target_id)
    lobe_attach = _safe_find_lobe(attach_id)

    lock(BRIDGE_LOCK) do
        # GRUG: Check bridge caps on BOTH sides (bidirectional!)
        existing_target = get(BRIDGE_MAP, target_id, CascadeBridge[])
        if length(existing_target) >= MAX_BRIDGES
            error("!!! FATAL: attach_image_node! target '$target_id' already has $(length(existing_target)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end
        existing_attach = get(BRIDGE_MAP, attach_id, CascadeBridge[])
        if length(existing_attach) >= MAX_BRIDGES
            error("!!! FATAL: attach_image_node! image node '$attach_id' already has $(length(existing_attach)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end

        # GRUG: Check for duplicate bridge (either direction)
        for br in existing_target
            if br.partner_id == attach_id
                error("!!! FATAL: attach_image_node! '$attach_id' is already bridged to '$target_id'! No duplicate bridges! !!!")
            end
        end
        for br in existing_attach
            if br.partner_id == target_id
                error("!!! FATAL: attach_image_node! '$target_id' is already bridged to '$attach_id'! No duplicate bridges! !!!")
            end
        end

        # GRUG: Create bidirectional bridge entries!
        bridge_target_to_attach = CascadeBridge(attach_id, sdf_seam, jit_conf_target_to_attach, lobe_attach, false, :none)
        bridge_attach_to_target = CascadeBridge(target_id, sdf_seam, jit_conf_attach_to_target, lobe_target, false, :none)

        push!(existing_target, bridge_target_to_attach)
        BRIDGE_MAP[target_id] = existing_target
        push!(existing_attach, bridge_attach_to_target)
        BRIDGE_MAP[attach_id] = existing_attach
    end

    n_bridged_target = lock(() -> length(get(BRIDGE_MAP, target_id, CascadeBridge[])), BRIDGE_LOCK)
    n_bridged_attach = lock(() -> length(get(BRIDGE_MAP, attach_id, CascadeBridge[])), BRIDGE_LOCK)
    println("[ENGINE] 🖼️🌉  Image bridge: '$target_id' ↔ '$attach_id' via SDF ($(width)x$(height), conf_T→A=$(round(jit_conf_target_to_attach, digits=3)), conf_A→T=$(round(jit_conf_attach_to_target, digits=3)), T: $n_bridged_target/$MAX_BRIDGES, A: $n_bridged_attach/$MAX_BRIDGES)")
    return "Bridged image '$attach_id' ↔ '$target_id' via SDF ($(width)x$(height), conf_T→A=$(round(jit_conf_target_to_attach, digits=3)), A→T=$(round(jit_conf_attach_to_target, digits=3)))"
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
create_node(pattern, action_packet, data, drop_table; is_image_node=false, is_antimatch_node=false, initial_strength=1.0)::String
# ⚠️ REMINDER: ANTIMATCH NODES WERE REMOVED. This field is dead/legacy only.

GRUG: Grow a new node in the cave. Returns the new node's ID.
If is_image_node=true, pattern is treated as SDF binary data (not text).
If is_antimatch_node=true, node is an anti-match: pattern-activated but vote-silent,
drains confidence from regular votes in the same lobe. No strength dynamics.
New nodes automatically try to latch onto the strongest similar existing node.
"""
function create_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    is_image_node::Bool  = false,
    is_antimatch_node::Bool = false,
# ⚠️ REMINDER: ANTIMATCH NODES WERE REMOVED. This field is dead/legacy only.
    initial_strength::Float64 = 1.0,
    node_type::Symbol = :voter  # GRUG v7.59: :voter (default) or :sigil (NOCHAT, singleton)
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

    # GRUG v7.21c-1: Allow nodes to declare auxiliary triples that aren't
    # extractable from the pattern itself. Use case: a node like `"i feel"`
    # has only 2 tokens (no verb-flanked triple available from the pattern),
    # but the seed author knows the conceptual triples are
    # ("feeling", "felt_by", "person"). data["aux_triples"] is a vector of
    # 3-element [subject, relation, object] entries that get merged in here.
    if haskey(data, "aux_triples") && isa(data["aux_triples"], AbstractVector)
        for t in data["aux_triples"]
            if isa(t, AbstractVector) && length(t) >= 3
                push!(rels, RelationalTriple(
                    String(t[1]),
                    String(t[2]),
                    String(t[3]),
                ))
            elseif isa(t, AbstractDict)
                push!(rels, RelationalTriple(
                    String(get(t, "subject", "")),
                    String(get(t, "relation", "")),
                    String(get(t, "object",  "")),
                ))
            end
        end
    end

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
        is_antimatch_node,  # is_antimatch_node
        String[],           # neighbor_ids
        false,              # is_unlinkable
        rand(LATCH_PARTNER_CAP_MIN:LATCH_PARTNER_CAP_MAX),  # max_neighbors (per-node 8-16 roll)
        false,              # is_grave
        "",                 # grave_reason
        Float64[],          # response_times (big-O ledger)
        time(),             # ledger_last_cleared
        hopfield_key,       # hopfield_key
        false,              # fired_this_cycle
        false,              # voted_this_cycle
        false,              # gained_this_cycle
        0.0,                # strength_delta_this_cycle
        pattern,             # original_pattern (BUG-010b: frozen at birth, chatter never touches)
        action_packet,       # original_action_packet (BUG-010b: frozen at birth, chatter never touches)
        node_type,           # GRUG v7.59: :voter or :sigil (NOCHAT, singleton)
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
    latched_to_id = nothing
    # GRUG v7.49: Anti-match nodes skip latching — they don't compete,
    # don't need neighbors, and don't participate in chatter groups.
    if !is_image_node && !is_antimatch_node && map_size >= NODE_LATCH_THRESHOLD
        latch_target_id = find_best_latch_target(new_node)
        if !isnothing(latch_target_id)
            target_node = lock(() -> get(NODE_MAP, latch_target_id, nothing), NODE_LOCK)
            if !isnothing(target_node)
                linked = try_link_nodes!(new_node, target_node)
                if linked
                    latched_to_id = latch_target_id
                    println("[ENGINE] 🌱  Node $id latched onto neighbor $latch_target_id.")
                end
            end
        end
    elseif !is_image_node && !is_antimatch_node && map_size < NODE_LATCH_THRESHOLD
        # GRUG: Map too small for meaningful latching. Node plants clean with no forced links.
        # User is responsible for explicit drop_table wiring at this scale.
        # Latch will engage automatically once map reaches NODE_LATCH_THRESHOLD nodes.
        @debug "[ENGINE] Latch suppressed for $id (map_size=$map_size < NODE_LATCH_THRESHOLD=$NODE_LATCH_THRESHOLD). Plant clean."
    end

    # GRUG (v7.19): GROUP MEMBERSHIP.
    # Every text node belongs to exactly one chatter group. Groups are how
    # the chatter ritual addresses bundles of similar-pattern nodes without
    # recomputing similarity each cycle.
    #   - If we latched onto an existing partner: join that partner group.
    #     If the partner has no group (predates v7.19), seed a fresh group on
    #     the partner first, then join.
    #   - v7.56a: Time-node isolation — if add_to_group! rejects the join
    #     (time node trying to join non-time group or vice versa), the node
    #     seeds its own group instead.
    #   - If we did not latch (small map, no candidates, or partner full):
    #     seed a new group with this node as the founder.
    # Image nodes and anti-match nodes do not chatter — skip groups.
    # GRUG v7.59: Sigil nodes are also excluded — they are singleton (never
    # in groups) and NOCHAT (ineligible for idle chatter). Their patterns
    # are syntactic grammars, not semantic content. People don't dream in
    # procedures.
    if !is_image_node && !is_antimatch_node && node_type !== :sigil
        try
            if !isnothing(latched_to_id)
                partner_grp = group_for(latched_to_id)
                if isnothing(partner_grp)
                    partner_node = lock(() -> get(NODE_MAP, latched_to_id, nothing), NODE_LOCK)
                    if !isnothing(partner_node)
                        partner_grp = register_group!(partner_node)
                    end
                end
                if !isnothing(partner_grp)
                    joined = add_to_group!(partner_grp, id)
                    # GRUG v7.56a: If join was rejected (time-node isolation gate),
                    # seed a new group for this node instead of leaving it groupless.
                    if !joined
                        register_group!(new_node)
                    end
                else
                    register_group!(new_node)
                end
            else
                register_group!(new_node)
            end
        catch e
            @warn "[ENGINE] Group registration failed for $id: $e"
        end
    end

    return id
end

# ==============================================================================
# GRUG v7.59: SIGIL NODE CREATION HELPERS
# ==============================================================================

"""
    create_sigil_node(pattern, action_packet, data, drop_table; kind, ...) -> String

GRUG v7.59: Convenience wrapper around `create_node` that creates a sigil node
with the appropriate @sigil:kind tag in the drop_table and node_type=:sigil.
Sigil nodes are NOCHAT (ineligible for idle chatter) and singleton (never placed
in growth groups). Their patterns are syntactic grammars (e.g. "&n &op &n"),
not semantic content. People don't dream in procedures.

Relational triples can optionally USE sigils, making them dynamic rather than
static. A required_relations entry like "&n is_greater_than &n" means the
relation evaluates at match time with sigil-bound values — not a fixed string
comparison. Easy to forget when authoring specimens.
"""
function create_sigil_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    kind::Symbol = :none,
    initial_strength::Float64 = 1.0,
)::String
    # GRUG: Inject @sigil:kind tag into drop_table
    tag = "$(SIGIL_TAG_PREFIX)$(kind)"
    dt_with_tag = vcat(drop_table, [tag])
    # GRUG: Also set is_unlinkable — sigil nodes never get neighbors
    data_with_sigil = copy(data)
    data_with_sigil["is_unlinkable"] = true
    data_with_sigil["is_nochat"] = true
    data_with_sigil["is_singleton"] = true
    data_with_sigil["neighbor_ids"] = String[]
    return create_node(
        pattern, action_packet, data_with_sigil, dt_with_tag;
        initial_strength = initial_strength,
        node_type = :sigil,
    )
end

"""
    list_sigil_node_ids(kind=:any) -> Vector{String}

GRUG v7.59: Return IDs of all non-grave nodes that carry the specified sigil
tag kind. Pass kind=:any to list all sigil nodes regardless of kind.
"""
function list_sigil_node_ids(kind::Symbol = :any)::Vector{String}
    result = String[]
    for (id, node) in NODE_MAP
        node.is_grave && continue
        nk = node_sigil_kind(node)
        nk === :none && continue
        if kind === :any || nk === kind
            push!(result, id)
        end
    end
    return result
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

            push!(action_items, (expand_action_macro_string(action_name), weight, action_negatives))

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

            push!(action_items, (expand_action_macro_string(action_name), weight, String[]))
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
    _, _, action_items = parse_action_packet(packet)
    isempty(action_items) && error("!!! FATAL: select_action got empty action packet! !!!")

    total_weight = sum(Float64(item[2]) for item in action_items)
    total_weight <= 0.0 && error("!!! FATAL: select_action got non-positive total action weight! !!!")

    pairs_for_coin = Pair[]
    for item in action_items
        name = String(item[1])
        weight = Float64(item[2])
        prob = (weight / total_weight) * 100.0
        push!(pairs_for_coin, bias(Symbol(name), prob) => () -> nothing)
    end

    winning_sym = @coinflip pairs_for_coin
    negatives = String[]
    for item in action_items
        append!(negatives, String.(item[3]))
    end
    return String(winning_sym), unique(negatives)
end


"""
cast_vote(id, conf, antimatch, u_trips, n_trips)

GRUG: Cast a vote for a matched node. Selects a stochastic action from the
node's action packet, bumps node strength on coinflip, and returns a Vote.
Throws if node ID is empty or node vanished from NODE_MAP — NO SILENT FAILURES.
"""
function cast_vote(id, conf, antimatch, u_trips, n_trips)
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end
    
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.60: Anti-match nodes are deprecated. If one somehow reaches this
    # function, silently return an empty vote instead of crashing. Antimatch
    # concept has been removed — all nodes vote normally based on confidence.
    if node.is_antimatch_node
        @warn "[ENGINE] Antimatch node $id reached cast_vote — deprecated, returning empty vote."
        return Vote(id, "ponder^1", 0.0, String[], RelationalTriple[], RelationalTriple[], false)
    end

    winning_action, negatives = select_action(node.action_packet)
    
    # GRUG FIX 2.8: Include bad action name in error!
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG BUG-011: Voting/use no longer changes strength. Only lock-in feedback can.

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch)
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
    return Vote(id, cmd_name, 9999.0, negatives, RelationalTriple[], node.relational_patterns, false)
end

"""
cast_vote_with_group(id, conf, antimatch, u_trips, n_trips, multipart_group, multipart_role)

GRUG v7.23: Same as cast_vote but stamps the vote with multipart_group and
multipart_role. Used when input decomposer splits a compound query into
sub-subjects — each sub-subject's votes carry the group ID assigned by
the decomposer, and the role (:primary for first sub-subject, :support
for subsequent ones) so MultipartOrchestrator can coalesce them into
one cohesive objective.
"""
function cast_vote_with_group(id, conf, antimatch, u_trips, n_trips,
                               multipart_group::String, multipart_role::Symbol)
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end
    
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.60: Anti-match nodes are deprecated. Silently return empty vote.
    if node.is_antimatch_node
        @warn "[ENGINE] Antimatch node $id reached cast_vote_with_group — deprecated, returning empty vote."
        return Vote(id, "ponder^1", 0.0, String[], RelationalTriple[], RelationalTriple[], false, multipart_group, multipart_role, Int[])
    end

    winning_action, negatives = select_action(node.action_packet)
    
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG BUG-011: Voting/use no longer changes strength. Only lock-in feedback can.

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch,
                multipart_group, multipart_role)
end

#=
    cast_vote_chunked(id, conf, antimatch, u_trips, n_trips, input_chunks)

GRUG v7.23: Cast a vote that knows which input chunk(s) it resolved.
This is the chunked-affinity path — the vote carries its own scope
instead of relying on a multipart_group tag. Used when the pattern
bind phase has chunk boundaries and can determine which part of the
input the node matched.

The vote's multipart_group is derived from input_chunks: if there's
exactly one chunk, group_id = "mp_{chunk_index}". If multiple chunks,
group_id = "mp_{first_chunk}" (primary chunk). If no chunks, group_id
= "" (singleton). multipart_role is always :primary for the winning
vote within its chunk group — same as the InputDecomposer path.
=#
function cast_vote_chunked(id, conf, antimatch, u_trips, n_trips,
                           input_chunks::Vector{Int};
                           multipart_group::String = "")
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end

    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.60: Anti-match nodes are deprecated. Silently return empty vote.
    if node.is_antimatch_node
        @warn "[ENGINE] Antimatch node $id reached cast_vote_chunked — deprecated, returning empty vote."
        return Vote(id, "ponder^1", 0.0, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton, input_chunks)
    end

    winning_action, negatives = select_action(node.action_packet)

    if !haskey(COMMANDS, winning_action)
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG BUG-011: Voting/use no longer changes strength. Only lock-in feedback can.

    # GRUG v8.4: multipart_group is now passed explicitly from the caller
    # (process_mission). The old code derived group_id from input_chunks[1],
    # which was WRONG for compound input: both sub-subjects have chunk 1
    # within their own chunk resolution, so both got "mp_1" and merged.
    # Now: if multipart_group is provided, use it. Otherwise, fall back to
    # the old chunk-derived derivation for backward compat (singleton path).
    if !isempty(multipart_group)
        group_id = multipart_group
    else
        group_id = isempty(input_chunks) ? "" : "mp_$(input_chunks[1])"
    end

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch,
                group_id, :primary, input_chunks)
end

# ==============================================================================
# /RIGHT AND /WRONG FEEDBACK: LOCK-IN-ONLY STRENGTH CHANGES
# ==============================================================================

#=
    apply_right_feedback!(contributor_votes, locked_node_ids) -> Dict

BUG-011: Apply /right reinforcement only to contributor votes whose node_id is
present in locked_node_ids. Non-lock / unsure contributors never change strength.
Eligible locked nodes still gain only through bump_strength!'s stochastic coinflip.
Grave nodes are skipped. Compatibility fields for the old tiered/double-reward
result shape remain, but unsure_rewarded and skipped_double_reward are empty.
=#
function apply_right_feedback!(contributor_votes::Vector{Vote},
                               locked_node_ids::Set{String} = Set{String}())::Dict{String, Any}
    if isempty(contributor_votes)
        error("!!! FATAL: apply_right_feedback! got empty contributor_votes list! !!!")
    end

    rewarded = String[]
    locked_rewarded = String[]
    unsure_rewarded = String[]  # BUG-011: kept for result compatibility; always empty.
    skipped_double_reward = String[]
    coinflip_missed = String[]
    grave_skipped = String[]
    nonlocked_skipped = String[]

    seen_nodes = Set{String}()

    lock(NODE_LOCK) do
        for vote in contributor_votes
            id = vote.node_id
            id in seen_nodes && continue
            push!(seen_nodes, id)

            if !(id in locked_node_ids)
                push!(nonlocked_skipped, id)
                continue
            end

            node = get(NODE_MAP, id, nothing)
            if isnothing(node)
                println("[ENGINE] ⚠  /right: Node [$id] not found, skipping.")
                continue
            end

            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end

            if node.gained_this_cycle
                push!(skipped_double_reward, node.id)
                continue
            end

            # GRUG BUG-011: Only lock-in votes can change strength, and even
            # lock-ins remain stochastic through bump_strength!'s jittered coinflip.
            before = node.strength
            bump_strength!(node)
            if node.strength > before
                push!(rewarded, node.id)
                push!(locked_rewarded, node.id)
            else
                push!(coinflip_missed, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors"    => length(contributor_votes),
        "locked_considered"     => length(intersect(Set(v.node_id for v in contributor_votes), locked_node_ids)),
        "rewarded"              => rewarded,
        "locked_rewarded"       => locked_rewarded,
        "unsure_rewarded"       => unsure_rewarded,
        "nonlocked_skipped"     => nonlocked_skipped,
        "skipped_double_reward" => skipped_double_reward,
        "coinflip_missed"       => coinflip_missed,
        "grave_skipped"         => grave_skipped,
    )
    println("[ENGINE] ✅ /right lock-in-only: total=$(length(contributor_votes)) locked=$(result["locked_considered"]) rewarded=$(length(rewarded)) nonlocked_skip=$(length(nonlocked_skipped)) coinflip_miss=$(length(coinflip_missed)) grave_skip=$(length(grave_skipped))")
    return result
end

# GRUG: Backward-compatible signature. Under BUG-011 there is no implicit
# lock-in evidence here, so this path performs NO strength changes. Callers
# that want reinforcement must pass locked_node_ids to the Vote-based method.
function apply_right_feedback!(contributor_ids::Vector{String})::Dict{String, Any}
    stub_votes = [Vote(id, "", 0.5, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton)
                  for id in contributor_ids]
    return apply_right_feedback!(stub_votes, Set{String}())
end

function apply_wrong_feedback!(contributor_ids::Vector{String},
                               locked_node_ids::Set{String}=Set(contributor_ids))::Dict{String, Any}
    if isempty(contributor_ids)
        error("!!! FATAL: apply_wrong_feedback! got empty contributor_ids list! !!!")
    end

    penalized = String[]
    coinflip_missed = String[]
    nonlocked_skipped = String[]
    grave_skipped = String[]
    missing_skipped = String[]
    graved_count = 0
    seen_nodes = Set{String}()

    lock(NODE_LOCK) do
        for id in contributor_ids
            id in seen_nodes && continue
            push!(seen_nodes, id)

            if !(id in locked_node_ids)
                push!(nonlocked_skipped, id)
                continue
            end

            node = get(NODE_MAP, id, nothing)
            if isnothing(node)
                println("[ENGINE] ⚠  /wrong: Node [$id] not found, skipping.")
                push!(missing_skipped, id)
                continue
            end

            if node.is_grave
                push!(grave_skipped, id)
                continue
            end

            was_grave_before = node.is_grave
            before = node.strength
            # GRUG BUG-011: Only lock-in votes can change strength, and penalty
            # remains stochastic through penalize_strength!'s jittered coinflip.
            penalize_strength!(node)
            if node.strength < before || (node.is_grave && !was_grave_before)
                push!(penalized, id)
                if node.is_grave && !was_grave_before
                    graved_count += 1
                end
            else
                push!(coinflip_missed, id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors" => length(contributor_ids),
        "locked_considered" => length(intersect(Set(contributor_ids), locked_node_ids)),
        "penalized" => penalized,
        "coinflip_missed" => coinflip_missed,
        "nonlocked_skipped" => nonlocked_skipped,
        "grave_skipped" => grave_skipped,
        "missing_skipped" => missing_skipped,
        "newly_graved" => graved_count,
    )
    println("[ENGINE] ❌ /wrong lock-in-only: total=$(length(contributor_ids)) locked=$(result["locked_considered"]) penalized=$(length(penalized)) nonlocked_skip=$(length(nonlocked_skipped)) coinflip_miss=$(length(coinflip_missed)) newly_graved=$graved_count")
    return result
end


# ==============================================================================
# JSON NODE GROWER (MAP EXPANSION)
# ==============================================================================

"""
    ensure_action_packet_registered!(action_packet::AbstractString)

GRUG v7.21c-2: PROSE-SLOT REGISTRY HELPER.

Walks every slot in an action_packet. For each slot's action_name, if it
is not already in COMMANDS:
  - If it looks like prose (>=2 words AND >=8 chars), auto-register a
    passthrough handler that funnels through `synthesize_voice_reply`.
  - Otherwise (single short word, looks like a typo): raise a FATAL error
    with the list of valid actions, preserving QoL-2025 BUG-007 behavior.

Called from grow_nodes_from_packet (seed-time) and from load_specimen
(restore-time), so prose-slot nodes survive a save/load round-trip.

Idempotent: registering the same prose action twice is a no-op.
"""
function ensure_action_packet_registered!(action_packet::AbstractString)
    _, _, action_items = parse_action_packet(String(action_packet))
    for item in action_items
        action_name = String(item[1])
        isempty(action_name) && continue
        haskey(COMMANDS, action_name) && continue

        is_prose_slot = (length(split(action_name)) >= 2) && (length(action_name) >= 8)
        if is_prose_slot
            COMMANDS[action_name] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
                return Base.invokelatest(synthesize_voice_reply, mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
            end
        else
            valid_actions = sort(collect(keys(COMMANDS)))
            valid_list = join(valid_actions, ", ")
            error("!!! FATAL: action_packet contains unknown action '$action_name'. " *
                  "Valid actions: $valid_list. " *
                  "Use {PIPE} or {{PIPE}} inside action names when you need a literal '|'. " *
                  "(see plans/semantic_plugins/QOL_SWEEP_2025.md BUG-007) !!!")
        end
    end
    return nothing
end

"""
grow_nodes_from_packet(json_str::String; target_lobe::Union{String,Nothing}=nothing,
                                          default_system_prompt::String="Grug speaks plainly.")::Vector{String}

GRUG: Parse a JSON packet and grow new nodes from it.

Supports BOTH packet shapes (QoL-2025 unification):
  - Multi-node:  `{"nodes":[{...}, {...}]}`
  - Single-node: `{"pattern":"...", "action_packet":"...", "data":{...}}`

Per-node fields accepted:
  - `pattern`         (required) — text or image binary descriptor
  - `action_packet`   (required) — pipe-separated `name^weight` entries
  - `data` OR `json_data` — node-internal metadata Dict
                            (BOTH keys accepted; `data` is the new canonical
                            spelling; `json_data` kept for back-compat)
  - `drop_table`      (optional) — co-activation neighbor ID list
  - `is_image_node`   (optional) — flag for image-binary nodes

If `target_lobe` is provided and exists, every grown node is added to that
lobe (Lobe.add_node_to_lobe! + LobeTable.json_to_table_chunk!) so the
topicality gate sees them. If `target_lobe` is `nothing`, nodes go to the
unassigned pool (legacy behavior).

If `data` does not include a `system_prompt` field, `default_system_prompt`
is injected. AIML synthesis requires it; missing it crashes voting with
`FATAL: Node dictionary missing 'system_prompt'!` (see QOL_SWEEP_2025 BUG-010).

Supports `is_image_node` flag in the JSON for image node creation.
If `is_image_node` is true, `pattern` field is treated as image binary descriptor.

Supports `is_antimatch_node` flag (v7.49) for anti-match node creation.
Anti-match nodes are pattern-activated but vote-silent — they drain confidence
from regular votes in the same lobe instead of casting their own vote.
NONJITTER tag makes drain a fixed constant instead of a random tick.
"""
function grow_nodes_from_packet(json_str::String;
                                target_lobe::Union{String,Nothing}=nothing,
                                default_system_prompt::String="Grug speaks plainly.")::Vector{String}
    if strip(json_str) == "" error("!!! FATAL: Cannot grow from empty JSON string !!!") end
    packet = try JSON.parse(json_str) catch e error("!!! FATAL: JSON parser dead: $e !!!") end

    # GRUG QoL-2025: Accept either {"nodes":[...]} or a single node dict.
    nodes_arr = if haskey(packet, "nodes")
        packet["nodes"]
    elseif haskey(packet, "pattern") && haskey(packet, "action_packet")
        [packet]  # treat the packet itself as a single-node entry
    else
        error("!!! FATAL: /grow JSON packet must have either 'nodes' array or top-level 'pattern' + 'action_packet'. !!!")
    end

    validated = Vector{Tuple{String,String,Dict{String,Any},Vector{String},Bool,Bool}}()
    for n in nodes_arr
        pattern      = String(n["pattern"])
        action_packet = String(n["action_packet"])

        # GRUG QoL-2025: Accept both `data` and `json_data` keys for the
        # node-metadata field. They are the same thing under different
        # historic names — `/grow` originally used `json_data`,
        # `/lobeGrow` used `data`. Now: `data` preferred, `json_data` accepted.
        # If both present, prefer `data` and warn.
        raw_data = if haskey(n, "data") && haskey(n, "json_data")
            @warn "[ENGINE] grow_nodes_from_packet: node has BOTH 'data' and 'json_data'; using 'data' and ignoring 'json_data'."
            n["data"]
        elseif haskey(n, "data")
            n["data"]
        elseif haskey(n, "json_data")
            n["json_data"]
        else
            Dict()
        end
        json_data = Dict{String, Any}(string(k) => v for (k, v) in raw_data)

        # GRUG QoL-2025 BUG-010: Inject default system_prompt if missing.
        # AIML synthesis hard-fails without it; quietly defaulting is
        # friendlier than letting the user discover the requirement at
        # vote time.
        if !haskey(json_data, "system_prompt") || isempty(strip(string(get(json_data, "system_prompt", ""))))
            json_data["system_prompt"] = default_system_prompt
        end

        # v7.25: HARD CONFIG WARNING — if the node is missing voice config,
        # it WILL produce incoherent responses. The operator needs to know NOW,
        # not at vote time. These are NOT optional for coherent speech.
        _sp_body = let sp = string(get(json_data, "system_prompt", ""))
            parts = split(sp, "."); isempty(parts) ? "" : strip(join([strip(String(p)) for p in parts[2:end] if !isempty(strip(String(p)))], ". "))
        end
        if isempty(_sp_body) && !haskey(json_data, "noun_anchors")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has single-sentence system_prompt and NO noun_anchors!
               The claim will fall back to the raw pattern — this produces pattern-echo garbage.
               FIX: Make system_prompt multi-sentence (sentence 1 = persona, rest = grug voice)
               OR add \"noun_anchors\" to json_data. YOU NEED THIS OR NO CAN DO."""
        end
        if !haskey(json_data, "voice_register")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has NO voice_register!
               Frame skeleton will be chosen by TonalJudge alone — may not match the node's intent.
               FIX: Add \"voice_register\" to json_data (e.g. \"warm\", \"terse\", \"explanatory\").
               YOU NEED THIS OR NO CAN DO."""
        end
        if !haskey(json_data, "frame_hints")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has NO frame_hints!
               TonalJudge cannot compute frame_match_multiplier for this node.
               FIX: Add \"frame_hints\" to json_data (e.g. [\"warm\", \"plain\"]).
               Valid: warm, exploratory, imperative, contemplative, de-escalating, terse, plain.
               YOU NEED THIS OR NO CAN DO."""
        end

        drop_table   = haskey(n, "drop_table") && (n["drop_table"] isa AbstractVector) ?
                       String[string(x) for x in n["drop_table"]] : String[]
        # GRUG NEW: Check for is_image_node flag in JSON packet
        is_img_node  = haskey(n, "is_image_node") && n["is_image_node"] === true

        # GRUG v7.49: Check for is_antimatch_node flag in JSON packet.
        # Anti-match nodes are pattern-activated confidence drainers — they
        # never vote, never gain/lose strength, and never enter the averages curve.
        is_am_node   = haskey(n, "is_antimatch_node") && n["is_antimatch_node"] === true

        # GRUG QoL-2025 BUG-007 + v7.21c-2 PROSE-SLOT EXTENSION:
        # Validate every action name against COMMANDS at grow time, but
        # auto-register prose answer-slots (multi-word, 8+ chars). Single-word
        # unknown actions are still treated as typos.
        ensure_action_packet_registered!(action_packet)

        push!(validated, (pattern, action_packet, json_data, drop_table, is_img_node, is_am_node))
    end

    new_ids = String[]
    for (p, a, j, d, is_img, is_am) in validated
        # GRUG: Optional initial_strength from json_data. Lets seed packets
        # anchor "obvious-winner" nodes (e.g. greeting's "good morning" node
        # for a greeting-domain query) at high strength so the strength-biased
        # coinflip and downstream confidence ranking favor them. Honest fallback
        # to 1.0 default if missing or malformed. Clamped to [FLOOR, CAP] inside
        # create_node, so a packet asking for strength=999 lands at STRENGTH_CAP
        # rather than crashing.
        init_str = 1.0
        if haskey(j, "initial_strength")
            try
                init_str = Float64(j["initial_strength"])
            catch e
                @warn "[ENGINE] grow_nodes_from_packet: bad initial_strength on a node ($(j["initial_strength"])), falling back to 1.0: $e"
            end
        end
        nid = create_node(p, a, j, d; is_image_node=is_img, is_antimatch_node=is_am, initial_strength=init_str)
        push!(new_ids, nid)

        # GRUG QoL-2025 BUG-008: If a target lobe was specified, route the
        # node into it AND register its json_data in the lobe table so the
        # topicality gate can reason about it.
        if !isnothing(target_lobe) && isdefined(@__MODULE__, :Lobe)
            try
                if haskey(Lobe.LOBE_REGISTRY, target_lobe)
                    alive = count_alive_nodes_in_lobe(target_lobe)
                    Lobe.add_node_to_lobe!(target_lobe, nid; alive_count=alive)
                    LobeTable.json_to_table_chunk!(target_lobe, nid, j)
                    LobeTable.drop_table_to_chunk!(target_lobe, nid, d)

                    # GRUG: STOCHASTIC AIML GROWTH — when a main node lands in a
                    # lobe, coinflip ~1/3 to auto-grow an AIML executive node.
                    # GRUG v8.12: AIMLNodeSystem removed — stochastic AIML growth
                    # callback is now no-op. The node still gets attached to the
                    # lobe below; the AIML-specific sub-population tracking is gone.
                else
                    @warn "[ENGINE] grow_nodes_from_packet: target_lobe '$target_lobe' does not exist; node '$nid' grown into unassigned pool."
                end
            catch e
                @warn "[ENGINE] grow_nodes_from_packet: failed to attach node '$nid' to lobe '$target_lobe': $e"
            end
        end
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
            am_tag     = node.is_antimatch_node ? "[ANTIMATCH]"      : ""
            avg_rt     = isempty(node.response_times) ? "N/A" :
                         "$(round(sum(node.response_times)/length(node.response_times), digits=3))s"
            nj_tag     = is_nonjitter(node) ? "[NONJITTER]" : ""
            push!(lines, "  $id | str=$(round(node.strength, digits=2)) | neighbors=$(length(node.neighbor_ids)) | $grave_tag $link_tag $img_tag $am_tag $nj_tag | avg_rt=$avg_rt | pattern=\"$(first(node.pattern, 40))\"")
        end
    end
    return join(lines, "\n")
end

# ==============================================================================
# AIML RULE TABLE (STOCHASTIC ORCHESTRATION RULES) -- REMOVED
# ==============================================================================
# GRUG v9-removal: The /addRule stochastic rule board (StochasticRule,
# ORCHESTRATION_RULES, ALLOWED_RULE_TAGS, add_orchestration_rule!) was DELETED.
# Investigation confirmed this board's evaluated output (rules_str) was ONLY
# ever printed into the DEBUG TELEMETRY section of the reply payload -- it was
# NEVER concatenated into conversational_reply (the actual user-visible
# output). It added tag-templated debug text and nothing else; it never
# shaped the structure of what Grug says. The real orchestration/sequencing
# is HippocampalModulator's ActionLog (reserved_step, confidence-ordered
# dispatch), and staleness-prevention is handled by the thesaurus/synonym
# swap pipeline in Main.jl (_vote_word_swap, _pick_synonym,
# _hippocampal_rephrase). Neither of those depended on this rule board.
# /addRule, /loadSpecimen "rules" restore, and specimen "rules" save were
# removed alongside it (see Main.jl). Old specimens with a "rules" key still
# load fine -- the key is recognized and silently skipped, same backward-compat
# pattern used for the removed AIMLNodeSystem's "aiml_system" key.

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
# v7.21c-5 side-process isolation makes this telemetry-only: slow averages
# are logged but do not change vote confidence or active voting eligibility.
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
# SCAN + EXPAND COMPATIBILITY API
# ==============================================================================

# GRUG v8.23: WORD COEFFICIENT STRUCTURE — flow instead of force.
# Old approach: binary stopword filter (word is either 0 or 1) + binary generic
# penalty (0.5 if ALL overlap is generic, else 1.0). Three hard tiers = force.
# New approach: every word gets a coefficient reflecting its semantic
# discriminative power. "the" still contributes, but at 0.05 — it's not
# deleted, it flows. "work" contributes 0.15 — weak but present. "fire"
# contributes 1.0 — strong discriminative signal. The overlap sum, coverage
# denominators, and harmonic mean all use weighted sums instead of counts.
# No more tiers, no more cutoffs, no more _all_generic penalty flag.
# Words NOT in this dict default to 1.0 (assumed highly discriminative).
# Sigil tokens (&n, &op, etc.) are not in the dict → default 1.0.
const WORD_COEFFICIENT = Dict{String, Float64}(
    # --- Tier 0.05: Pure function words (determiners, articles, copula) ---
    # These appear in virtually every sentence. They're not zero because
    # they DO participate in overlap, but their contribution is negligible.
    "a" => 0.05, "an" => 0.05, "the" => 0.05,
    "is" => 0.05, "am" => 0.05, "are" => 0.05, "was" => 0.05, "were" => 0.05,
    "be" => 0.05, "been" => 0.05, "being" => 0.05,
    "it" => 0.05, "its" => 0.05, "me" => 0.05,
    # --- Tier 0.08: Pronouns and light function words ---
    # GRUG v8.26e: "you" raised to 0.30 — "you" in "who are you" IS the
    # discriminative content, not filler. The identity node (pattern="you")
    # must beat the copula node (pattern="are") for self-reference queries.
    # At 0.08 both get near-identical tiny overlap and signal similarity
    # becomes the tiebreaker, which is unreliable for single-word patterns.
    "i" => 0.08, "you" => 0.30, "we" => 0.08, "he" => 0.08, "she" => 0.08,
    "they" => 0.08, "him" => 0.08, "her" => 0.08, "them" => 0.08, "us" => 0.08,
    "my" => 0.08, "your" => 0.20, "our" => 0.08, "his" => 0.08, "their" => 0.08,
    "this" => 0.08, "that" => 0.08, "these" => 0.08, "those" => 0.08,
    # GRUG v8.26e: "who" raised to 0.25 — "who" is a question word with
    # discriminative power (like "how"/"why"/"when" at tier 0.25).
    "what" => 0.08, "who" => 0.25, "whom" => 0.25, "which" => 0.08,
    # --- Tier 0.10: Conjunctions and basic operators ---
    "and" => 0.10, "or" => 0.10, "but" => 0.10, "nor" => 0.10,
    "not" => 0.10, "no" => 0.10, "so" => 0.10, "yet" => 0.10,
    "if" => 0.10, "than" => 0.10, "then" => 0.10, "because" => 0.10,
    # --- Tier 0.10: Modal/auxiliary verbs ---
    "do" => 0.10, "does" => 0.10, "did" => 0.10,
    "have" => 0.10, "has" => 0.10, "had" => 0.10,
    "will" => 0.10, "would" => 0.10, "could" => 0.10, "should" => 0.10,
    "may" => 0.10, "might" => 0.10, "shall" => 0.10, "can" => 0.10,
    # --- Tier 0.12: Prepositions (light spatial/temporal) ---
    "to" => 0.12, "of" => 0.12, "in" => 0.12, "for" => 0.12, "on" => 0.12,
    "with" => 0.12, "at" => 0.12, "by" => 0.12, "from" => 0.12, "as" => 0.12,
    "into" => 0.12, "about" => 0.12,
    # --- Tier 0.18: Prepositions with more semantic content ---
    "through" => 0.18, "during" => 0.18, "before" => 0.18, "after" => 0.18,
    "above" => 0.18, "below" => 0.18, "between" => 0.18,
    "out" => 0.18, "off" => 0.18, "over" => 0.18, "under" => 0.18,
    "up" => 0.18, "down" => 0.18,
    # --- Tier 0.20: Quantifiers/determiners with selection meaning ---
    "both" => 0.20, "either" => 0.20, "neither" => 0.20,
    "each" => 0.20, "every" => 0.20, "all" => 0.20, "any" => 0.20,
    "few" => 0.20, "more" => 0.20, "most" => 0.20, "other" => 0.20,
    "some" => 0.20, "such" => 0.20, "only" => 0.20, "own" => 0.20,
    "same" => 0.20, "too" => 0.20, "very" => 0.20, "just" => 0.20,
    "again" => 0.20, "further" => 0.20, "once" => 0.20,
    # --- Tier 0.25: Question words (some discriminative power) ---
    "how" => 0.25, "why" => 0.25, "when" => 0.25, "where" => 0.25,
    "tell" => 0.25,
    # --- Tier 0.15: Generic content words (was _generic_content_words) ---
    # These pass the old stopword filter but appear across many topics.
    # They contribute, but weakly — "work" in "how does fire work" is
    # structural, not topical. The coefficient handles this naturally:
    # overlap on "work" alone → small weighted overlap → low harmonic mean.
    # No need for a separate _all_generic penalty flag anymore.
    "work" => 0.15, "make" => 0.15, "go" => 0.15, "get" => 0.15,
    "use" => 0.15, "find" => 0.15, "give" => 0.15, "ask" => 0.15,
    "try" => 0.15, "leave" => 0.15, "call" => 0.15, "keep" => 0.15,
    "let" => 0.15, "begin" => 0.15, "seem" => 0.15, "help" => 0.15,
    "show" => 0.15, "hear" => 0.15, "play" => 0.15, "run" => 0.15,
    "move" => 0.15, "live" => 0.15, "believe" => 0.15, "bring" => 0.15,
    "happen" => 0.15, "write" => 0.15, "provide" => 0.15, "sit" => 0.15,
    "stand" => 0.15, "lose" => 0.15, "pay" => 0.15, "meet" => 0.15,
    "include" => 0.15, "continue" => 0.15, "set" => 0.15, "learn" => 0.15,
    "change" => 0.15, "lead" => 0.15, "watch" => 0.15, "follow" => 0.15,
    "stop" => 0.15, "create" => 0.15, "speak" => 0.15, "read" => 0.15,
    "allow" => 0.15, "add" => 0.15, "spend" => 0.15, "grow" => 0.15,
    "open" => 0.15, "walk" => 0.15, "win" => 0.15, "offer" => 0.15,
    "remember" => 0.15, "consider" => 0.15, "appear" => 0.15, "buy" => 0.15,
    "wait" => 0.15, "serve" => 0.15, "die" => 0.15, "send" => 0.15,
    "expect" => 0.15, "build" => 0.15, "stay" => 0.15, "fall" => 0.15,
    "cut" => 0.15, "reach" => 0.15, "kill" => 0.15, "remain" => 0.15,
    "suggest" => 0.15, "raise" => 0.15, "pass" => 0.15, "sell" => 0.15,
    "require" => 0.15, "report" => 0.15, "decide" => 0.15, "pull" => 0.15,
    "develop" => 0.15,
    # --- Special: grug (self-reference, matches too many nodes) ---
    "grug" => 0.10,
)

# Helper: get word coefficient with default 1.0 for unknown words
_word_coeff(w::String) = get(WORD_COEFFICIENT, w, 1.0)

function _lexical_overlap_confidence(input_text::String, node::Node)::Float64
# GRUG v8.23: COEFFICIENT-WEIGHTED LEXICAL OVERLAP — flow, not force.
# Replaces the old binary stopword filter + generic penalty with a smooth
# coefficient spectrum. Every word flows with its natural semantic weight:
# "the" contributes 0.05, "work" contributes 0.15, "fire" contributes 1.0.
# Overlap is the sum of coefficients for shared tokens, not the count.
# Coverage denominators use coefficient-weighted sums, not raw counts.
# No more hard tiers, no more _all_generic penalty flag, no more binary
# filter. The harmonic mean naturally handles everything — if overlap is
# only on "work" (coeff 0.15), the weighted overlap is tiny → low harmonic.
# If overlap includes "fire" (coeff 1.0), the weighted overlap is strong.
#
# GRUG v8.17: STEMMED OVERLAP. Before computing overlap, expand both
# input and pattern tokens with their stemmed forms via Thesaurus.stem_token.
# This way "atoms" in input produces {"atoms", "atom"} and "atom" in
# pattern produces {"atom"} — overlap found! Same for verb forms:
# "running" produces {"running", "run"}, matching "run" in pattern.
# Both original AND stemmed forms are kept so exact matches still work.
#
# IMPORTANT: Stemmed forms inherit the coefficient of their ORIGINAL token.
# "atoms" (coeff 1.0, not in dict) → stem "atom" (also 1.0, not in dict).
# "running" (coeff 0.15, generic) → stem "run" (also 0.15, in dict).
# This prevents stemmed expansions from gaming the coefficient system.
    # GRUG v8.23: Tokenize ALL tokens (no stopword filtering), then expand
    # with stemmed forms. Each token gets BOTH its original form and its stem.
    # Coefficients handle what stopwords used to — no need to delete tokens.
    input_tokens_raw = split(lowercase(strip(input_text)))
    input_tokens = Thesaurus.normalize_tokens(input_tokens_raw)

    node_tokens_raw = split(lowercase(strip(node.pattern)))
    node_tokens = Thesaurus.normalize_tokens(node_tokens_raw)

    if isempty(input_tokens) || isempty(node_tokens)
        return 0.0
    end
    # GRUG v8.23: Build coefficient maps for expanded token sets.
    # Each expanded token inherits the coefficient of its original form.
    # input_tokens = ["the", "fire", "fire"] (from "the fire" → stem "fire" added)
    # input_coeff = Dict("the" => 0.05, "fire" => 1.0)
    # For coverage, we sum coefficients of ALL expanded tokens, but each
    # unique token's coefficient is counted only once per side.
    function _build_coeff_map(tokens_raw, tokens_expanded)
        coeff_map = Dict{String, Float64}()
        # Pre-build stem→coeff map from raw tokens (avoids repeated stem_token calls)
        stem_coeff = Dict{String, Float64}()
        for raw in tokens_raw
            stem = Thesaurus.stem_token(String(raw))
            c = _word_coeff(String(raw))
            # If multiple raw tokens stem to same form, take max coefficient
            if !haskey(stem_coeff, stem) || c > stem_coeff[stem]
                stem_coeff[stem] = c
            end
        end
        for t in tokens_expanded
            if !haskey(coeff_map, t)
                if haskey(stem_coeff, t)
                    coeff_map[t] = stem_coeff[t]
                else
                    coeff_map[t] = _word_coeff(t)
                end
            end
        end
        return coeff_map
    end
    input_coeff = _build_coeff_map(input_tokens_raw, input_tokens)
    node_coeff = _build_coeff_map(node_tokens_raw, node_tokens)
    # GRUG v8.23: Weighted overlap = sum of coefficients of shared tokens.
    # If "fire" (1.0) and "the" (0.05) are both shared, overlap = 1.05.
    # This naturally replaces the old binary filter + generic penalty.
    overlap_set = intersect(input_tokens, node_tokens)
    isempty(overlap_set) && return 0.0
    weighted_overlap = sum(get(input_coeff, w, 1.0) for w in overlap_set)
    # GRUG v8.23: Weighted coverage denominators.
    # OLD: input_content_count = length(input_content) — just a count.
    # NEW: input_weight = sum of coefficients for all unique tokens on this side.
    # "the fire is hot" → tokens {the, fire, is, hot} → weights 0.05+1.0+0.05+1.0 = 2.10
    # "fire burn" → tokens {fire, burn} → weights 1.0+1.0 = 2.0
    input_weight = sum(values(input_coeff))
    node_weight = sum(values(node_coeff))
    # GRUG v8.23: BIDIRECTIONAL WEIGHTED OVERLAP. Harmonic mean of weighted
    # input_coverage and node_coverage. Same principle as v7.60 but with
    # coefficient-weighted numerators and denominators instead of raw counts.
    #   - input_coverage = weighted_overlap / input_weight
    #     How much of the input's semantic weight is captured by overlap.
    #   - node_coverage = weighted_overlap / node_weight
    #     How much of the node's semantic weight is captured by overlap.
    #   - harmonic mean balances both directions.
    # Example: "the fire is hot" ↔ "fire burn wood"
    #   input_weight = 0.05+1.0+0.05+1.0 = 2.10, node_weight = 1.0+1.0+1.0 = 3.0
    #   overlap_set = {"fire"}, weighted_overlap = 1.0
    #   input_coverage = 1.0/2.10 = 0.476, node_coverage = 1.0/3.0 = 0.333
    #   harmonic = 2*0.476*0.333/(0.476+0.333) = 0.393
    # OLD binary approach would give: overlap=1, input_content=2, node_content=3
    #   input_coverage = 0.5, node_coverage = 0.333, harmonic = 0.40
    # The coefficient approach penalizes "the"/"is" in denominators automatically.
    input_coverage = weighted_overlap / max(0.01, input_weight)
    node_coverage = weighted_overlap / max(0.01, node_weight)
    harmonic = (input_coverage + node_coverage) > 0 ?
               2.0 * (input_coverage * node_coverage) / (input_coverage + node_coverage) : 0.0
    return clamp(harmonic, 0.0, 1.0)
end

function _scan_confidence_for_node(input_signal::Vector{Float64}, input_text::String, node::Node, base_mode::Int)::Float64
# REMINDER: ANTIMATCH NODES REMOVED. Do not add antimatch confidence drain.
# GRUG v7.60-coherence: LEXICAL GATING. The signal scanner (float-hash)
# produces near-1.0 confidence for almost every node regardless of semantic
# relevance, because the signal vectors are poorly differentiated. This
# caused wrong nodes to win votes: "greece" beat "fire hearth" for "what
# is fire". The fix: lexical overlap is the PRIMARY confidence source.
# Signal similarity can BOOST a lexically-matched node but CANNOT create
# confidence from zero. A node with zero lexical overlap with the input
# gets zero confidence regardless of signal similarity.
#
# GRUG v7.55: DUAL-INPUT LEXICAL OVERLAP. Sigil promotion rewrites "6"
# to "&n" in the input before scanning, so answer nodes with literal
# numbers in their pattern ("factorial of 6") lose lexical overlap.
# Fix: compute overlap against BOTH the promoted input AND the raw
# (un-promoted) input, and take the max. This way:
#   - Sigil nodes match the promoted input ("&n &op &n" ↔ "&n &op &n")
#   - Answer nodes match the raw input ("factorial of 6" ↔ "factorial of 6")
    node.is_image_node && return 0.0

    # GRUG v7.55: DUAL-INPUT — compute overlap against BOTH promoted and raw input.
    raw_input = lock(_GLOBAL_PROMOTION_LOCK) do; _GLOBAL_PROMOTION_RAW[]; end
    use_raw = !isempty(raw_input) && raw_input != input_text

    # GRUG v8.14: TRIPLE-INPUT — also compute overlap against the pre-expansion
    # raw text (original user input BEFORE thesaurus gate expansion). The
    # expansion appends synonyms that dilute input_coverage. For example,
    # "what is fire" → "what is fire constitutes equals blaze flame conflagration
    # amounts-to" drops input_coverage from 1.0 to 0.143 because the expansion
    # adds words not in the node's pattern. Taking the max across all three
    # versions ensures expansion tokens never HURT a match that would succeed
    # without them. The expansion's purpose is to HELP synonym-matched nodes
    # (where the node's pattern contains a synonym of the user's word), and
    # that still works because the expanded text provides higher node_coverage
    # for those nodes.
    pre_expansion_input = lock(_GLOBAL_PROMOTION_LOCK) do; _GLOBAL_RAW_PRE_EXPANSION[]; end
    use_pre_expansion = !isempty(pre_expansion_input) && pre_expansion_input != input_text

    isempty(node.signal) && return max(_lexical_overlap_confidence(input_text, node),
                                        use_raw ? _lexical_overlap_confidence(raw_input, node) : 0.0,
                                        use_pre_expansion ? _lexical_overlap_confidence(pre_expansion_input, node) : 0.0)

    lex_conf = _lexical_overlap_confidence(input_text, node)

    # GRUG v7.55: Also compute overlap against the raw (un-promoted) input.
    # If the raw input has better overlap with this node's pattern, use that.
    # This is critical for answer nodes that contain literal numbers — the
    # promoted input replaces numbers with sigil tokens, breaking the match.
    if use_raw
        raw_lex_conf = _lexical_overlap_confidence(raw_input, node)
        lex_conf = max(lex_conf, raw_lex_conf)
    end

    # GRUG v8.14: Also compute overlap against the pre-expansion input.
    # If the original (un-expanded) input has better overlap, use that.
    # This prevents thesaurus expansion from HURTING matches that would
    # succeed without the expansion.
    if use_pre_expansion
        pre_exp_lex_conf = _lexical_overlap_confidence(pre_expansion_input, node)
        lex_conf = max(lex_conf, pre_exp_lex_conf)
    end

    # GRUG v7.60-coherence: LEXICAL GATE — if the node shares ZERO words
    # with the input, it has no business firing. Signal similarity alone
    # is not sufficient because the float-hash vectors are too coarse.
    lex_conf <= 0.0 && return 0.0

    mode = _effective_scan_mode(base_mode, node.signal)
    sig_conf = 0.0
    try
        if mode == 1
            _, sig_conf = _bidirectional_cheap_scan(input_signal, node.signal; threshold=0.1, nonjitter=is_nonjitter(node))
        elseif mode == 2
            _, sig_conf = medium_scan(input_signal, node.signal; threshold=0.1)
        else
            _, sig_conf = high_res_scan(input_signal, node.signal; threshold=0.1)
        end
    catch e
        if e isa PatternNotFoundError || e isa PatternScanError
            sig_conf = 0.0
        else
            rethrow(e)
        end
    end

    # GRUG v7.60-coherence: COMBINED CONFIDENCE. Signal similarity BOOSTS
    # lexical confidence but cannot override it. The formula:
    #   combined = lex_conf * (1.0 + 0.3 * sig_conf)
    # This means:
    #   - lex_conf=0.5, sig_conf=1.0 → 0.5 * 1.3 = 0.65  (good match, boosted)
    #   - lex_conf=0.5, sig_conf=0.0 → 0.5 * 1.0 = 0.5  (good match, no boost)
    #   - lex_conf=0.333, sig_conf=1.0 → 0.333 * 1.3 = 0.433  (partial match)
    #   - lex_conf=0.0, sig_conf=1.0 → 0.0  (no lexical overlap = no fire)
    # The signal scanner can add at most 30% bonus on top of lexical overlap,
    # which preserves lexical relevance as the dominant signal.
    combined = lex_conf * (1.0 + 0.3 * clamp(sig_conf, 0.0, 1.0))
    return clamp(combined, 0.0, 1.0)
end

function _specimen_tuple(id::String, conf::Float64, antimatch::Bool,
                         user_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
                         node_triples::Vector{RelationalTriple},
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
                         input_chunks::Vector{Int}=Int[])
    return (id, conf, antimatch, user_triples, node_triples, input_chunks)
end

"""
    scan_specimens(input::String; chunks=[])

Compatibility scanner used by scan_and_expand. Returns six-tuples:
`(node_id, confidence, antimatch, user_triples, node_triples, input_chunks)`.
BUG-011: scanning/firing is marker-only and never mutates strength.
"""
function scan_specimens(input::String; chunks=[])::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}}
# REMINDER: ANTIMATCH NODES REMOVED. No antimatch drain in scan loop. HOPFIELD REMOVED.
# REMINDER: Relational triples CAN contain sigils like &n, &op — they are dynamic, not just literal strings.
    strip(input) == "" && error("!!! FATAL: scan_specimens got empty input! !!!")

    input_signal = words_to_signal(input)
    # GRUG v8.16: Extract triples from RAW pre-expansion text, not from thesaurus-expanded text.
    # The `input` parameter is the promoted (possibly thesaurus-expanded) text. If we extract
    # triples from "what is love constitutes equals blaze", we get garbage triples like
    # (is, care, constitutes). The raw user input "what is love" produces clean triples
    # like (what, is, love). Pattern matching still uses the expanded text (via input_signal),
    # but relational matching should use the user's actual words.
    pre_expansion_input = lock(_GLOBAL_PROMOTION_LOCK) do; _GLOBAL_RAW_PRE_EXPANSION[]; end
    triple_source = (!isempty(pre_expansion_input) && pre_expansion_input != input) ? pre_expansion_input : input
    user_triples = extract_dynamic_relational_triples(triple_source, screen_input_complexity(input_signal, RelationalTriple[]))
    base_mode = screen_input_complexity(input_signal, user_triples)
    input_chunk_ids = isempty(chunks) ? Int[] : collect(1:length(chunks))
    active_cap = rand(600:1800)

    matched = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
    seen = Set{String}()
    high_conf_ids = String[]

    nodes = lock(() -> collect(values(NODE_MAP)), NODE_LOCK)
    for node in nodes
        length(matched) >= active_cap && break
        node.is_grave && continue

        conf = _scan_confidence_for_node(input_signal, input, node, base_mode)
        conf <= 0.0 && continue

        # GRUG v7.60-confidence-lock: Only nodes with genuine high confidence
        # should fire and vote. Low-confidence noise must be excluded at the
        # source — the scan stage — not just filtered downstream. This is the
        # "lock in confidence" gate: a node must have raw pattern-match
        # confidence >= SCAN_CONFIDENCE_LOCK to even enter the voter pool.
        # Without this, every node with any activation fires, and composite
        # scoring can inflate weak matches past the vote threshold.
        # GRUG v8.26e: A SECOND gate (VOTE_CONFIDENCE_FLOOR = 0.55) exists in
        # Main.jl's ephemeral_voice_orchestrator. Nodes that pass this SCAN lock
        # but fall below VOTE_CONFIDENCE_FLOOR still fire for cascade/drop-table
        # purposes but do NOT get to vote. This double-gate prevents high-strength
        # low-relevance nodes from dominating the answer.
        conf < SCAN_CONFIDENCE_LOCK && continue

        # GRUG v8.16: SIGIL NODE CONFIDENCE GATE. Sigil pattern nodes
        # (patterns containing &n, &op, &conj etc.) fire as low-confidence
        # side-features on non-math questions because the signal scanner
        # gives them non-zero similarity even with zero lexical overlap.
        # This is false activation: "what is AI" should NOT produce a
        # math side-feature. Fix: sigil-pattern nodes need conf >=
        # SCAN_CONFIDENCE_LOCK + 0.15 (i.e. 0.50) to enter the voter pool.
        # A genuine math input like "what is 5 plus 3" produces high
        # lexical overlap with the promoted pattern "&n &op &n" and
        # easily clears 0.50. A false positive like "what is AI" typically
        # gets 0.35-0.45 and is now excluded.
        _is_sigil_pattern = occursin(r"&[a-z]", node.pattern)
        if _is_sigil_pattern && conf < SCAN_CONFIDENCE_LOCK + 0.15
            continue
        end

        # GRUG v8.21: SIGIL PATTERN SPECIFICITY BONUS. When multiple sigil
        # patterns match an input (e.g., "square of &n" AND "square root of &n"
        # both match "square root of 49"), the longer pattern is more specific
        # and should win. Without this bonus, the shorter pattern can have
        # higher signal similarity and win incorrectly (e.g., "square of &n"
        # winning over "square root of &n" for "square root of 49" → wrong answer).
        # Fix: count non-sigil content tokens in the pattern and add a small
        # bonus per extra content token. This naturally favors longer, more
        # specific patterns without penalizing short patterns on non-ambiguous inputs.
        if _is_sigil_pattern
            _pat_toks = split(lowercase(strip(node.pattern)), r"\s+")
            _content_toks = [t for t in _pat_toks if !occursin(r"^&[a-z]$", t) && length(t) > 2]
            _specificity_bonus = length(_content_toks) * 0.04   # 4% per content token
            conf = min(1.0, conf + _specificity_bonus)
        end

        # GRUG v8.26e: TEMPORAL RELATION BONUS. Nodes with required_relations
        # containing &temporal are TIME nodes. When the input contains temporal
        # keywords (before, after, during, since, until, when, while, precedes,
        # follows, then, now), these nodes get a confidence bonus because the
        # user is asking a temporal question. Without this, a simple node like
        # "renaissance" (pattern="renaissance") beats the time node
        # "the dark ages the renaissance" because the longer pattern dilutes
        # node_coverage. The temporal bonus compensates for this dilution.
        _has_temporal_req = any(r -> occursin("temporal", lowercase(r)), node.required_relations)
        if _has_temporal_req
            _input_lower = lowercase(pre_expansion_input)
            _temporal_keywords = ["before", "after", "during", "since", "until", "when", "while", "precedes", "follows", "then", "now", "came before", "came after", "next", "previous", "past", "future", "present"]
            _temporal_hits = count(kw -> occursin(kw, _input_lower), _temporal_keywords)
            if _temporal_hits > 0
                _temporal_bonus = min(0.25, _temporal_hits * 0.12)  # 12% per keyword hit, cap 25%
                conf = min(1.0, conf + _temporal_bonus)
            end
        end

        # GRUG v7.60-confidence-lock: ANTIMATCH REMOVED. No antimatch bypass.
        # All non-grave, non-image nodes with conf >= SCAN_CONFIDENCE_LOCK enter voter pool directly.

        push!(matched, _specimen_tuple(node.id, Float64(conf), false, user_triples, node.relational_patterns, input_chunk_ids))
        push!(seen, node.id)
        node.fired_this_cycle = true
        node.voted_this_cycle = true
        conf >= HOPFIELD_STORE_THRESHOLD && push!(high_conf_ids, node.id)

        # Drop-table co-activation: associative memory, no strength mutation.
        for drop_id in node.drop_table
            length(matched) >= active_cap && break
            drop_id in seen && continue
            drop_node = get(NODE_MAP, drop_id, nothing)
            isnothing(drop_node) && continue
            drop_node.is_grave && continue
            # GRUG v7.60-confidence-lock: Drop-table co-activation must also
            # respect the confidence lock. If the parent's conf * 0.8 is below
            # SCAN_CONFIDENCE_LOCK, the co-activated node doesn't fire — it
            # has no genuine pattern relevance to the current input.
            drop_conf = Float64(conf) * 0.8
            drop_conf < SCAN_CONFIDENCE_LOCK && continue
            push!(matched, _specimen_tuple(drop_id, drop_conf, false, user_triples, drop_node.relational_patterns, input_chunk_ids))
            push!(seen, drop_id)
            drop_node.fired_this_cycle = true
            drop_node.voted_this_cycle = true
        end
    end

    # Bridge/cascade pass over a stable snapshot of current matches.
    # GRUG v8.26e: CASCADE RELEVANCE GATE. Cascade-fired nodes get their
    # bridge confidence as their "scan confidence", but this doesn't reflect
    # actual lexical relevance to the input. A high-strength node bridged
    # from a relevant node can have bridge_conf > SCAN_CONFIDENCE_LOCK
    # even with zero lexical overlap with the input. This is how thermodynamics
    # wins over fire/water: fire fires, bridge cascades to thermo with conf=0.35,
    # thermo votes with that inflated confidence, and wins because it's stronger.
    # Fix: CASCADE NODES MUST ALSO PASS LEXICAL OVERLAP CHECK against the input.
    # Their bridge confidence is used for scoring/ranking, but they need at
    # least MINIMAL lexical relevance (overlap >= SCAN_CONFIDENCE_LOCK) to enter
    # the voter pool. Without this, cascaded nodes are phantom voters.
    for source_id in copy(collect(seen))
        length(matched) >= active_cap && break
        for (bridge_id, bridge_conf, seam_text) in fire_cascades!(source_id, length(matched), active_cap)
            bridge_id in seen && continue
            bridge_node = get(NODE_MAP, bridge_id, nothing)
            isnothing(bridge_node) && continue
            bridge_node.is_grave && continue
            # GRUG v8.26e: LEXICAL RELEVANCE GATE for cascade nodes.
            # Bridge confidence alone is not sufficient — the cascaded node
            # must have SOME lexical overlap with the input to vote.
            # This prevents the thermodynamics-domination bug where a
            # high-strength but irrelevant node cascades in and wins.
            # GRUG v8.26e: Use PRE-EXPANSION input for cascade lexical check.
            # The `input` parameter is thesaurus-expanded (e.g., "what is fire blaze combustion heat ..."),
            # which gives thermodynamics nodes spurious lexical overlap via thesaurus-added tokens
            # like "heat" and "combustion". The raw pre-expansion input ("what is fire") correctly
            # shows zero overlap with thermodynamics anchors, blocking the cascade.
            _cascade_lex_conf = _lexical_overlap_confidence(pre_expansion_input, bridge_node)
            if _cascade_lex_conf < SCAN_CONFIDENCE_LOCK
                continue   # skip — no genuine relevance to the input
            end
            # Use the BETTER of bridge confidence and lexical confidence
            # as the node's effective scan confidence. Bridge conf captures
            # the relational chain strength; lexical conf captures direct
            # relevance. Taking the max respects both signals.
            effective_conf = max(Float64(bridge_conf), _cascade_lex_conf)
            seam_triples = isempty(strip(seam_text)) ? RelationalTriple[] : extract_relational_triples(seam_text)
            node_triples = vcat(bridge_node.relational_patterns, seam_triples)
            push!(matched, _specimen_tuple(bridge_id, effective_conf, false, user_triples, node_triples, input_chunk_ids))
            push!(seen, bridge_id)
            bridge_node.fired_this_cycle = true
            bridge_node.voted_this_cycle = true
        end
    end

    input_hash = hopfield_input_hash(input)
    hopfield_record!(input_hash, high_conf_ids)

    sort!(matched, by=x -> x[2], rev=true)
    return matched
end

"""
    scan_and_expand(input::String; chunks=[])

Public compatibility wrapper for the historical three-pass scan API.

STAGE 1.5a — FRONT-DOOR SIGIL PROMOTION:
Before scanning, run the input through SigilPromoter.promote_input().
Two layers:
  Layer 1 — thesaurus canonicalization ("two plus two" -> "2 + 2")
  Layer 2 — registry shape promotion   ("2 + 2"        -> "&n &op &n")
Bindings are stashed in both task-local storage and module-level Refs so
downstream code (ArithmeticEngine, ATP, synthesize_voice_reply) can read them
across Task boundaries. The PROMOTED text is passed to scan_specimens so that
nodes with &n/&op patterns can match the promoted form.
"""
function scan_and_expand(input::String; chunks=[], multipart_group::String="")
    # ── STAGE 1.5a — FRONT-DOOR SIGIL PROMOTION ──────────────────────────
    # GRUG v8.19: PROMOTE THE PRE-EXPANSION TEXT, NOT THE EXPANDED TEXT.
    # The thesaurus gate appends synonyms to the input before it reaches
    # scan_and_expand. Promoting the expanded text produces diluted sigil
    # patterns: "what is 20 divided by 5 constitutes equals blaze" promotes
    # to "&query &definition &n &op by &n &definition &definition ..." which
    # has terrible lexical overlap with "&n &op &n". The fix: promote the
    # ORIGINAL user input (stashed in _GLOBAL_RAW_PRE_EXPANSION) to get
    # clean sigil bindings, then append expansion tokens as raw literals
    # for signal matching (not sigil-promoted).
    pre_exp = lock(_GLOBAL_PROMOTION_LOCK) do; _GLOBAL_RAW_PRE_EXPANSION[]; end
    promotion_source = (!isempty(pre_exp) && pre_exp != input) ? pre_exp : input
    # GRUG v8.19 DEBUG: Log promotion source selection
    @info "[ENGINE v8.19] scan_and_expand: input='$(input[1:min(80,length(input))])' pre_exp='$(pre_exp[1:min(80,length(pre_exp))])' using_promotion_source='$(promotion_source[1:min(80,length(promotion_source))])'"
    promoted_text, promotion_bindings = SigilPromoter.promote_input(
        _ENGINE_SIGIL_TABLE, promotion_source)

    # GRUG v8.19: DO NOT append thesaurus expansion tokens to the promoted
    # text. Expansion tokens inflate input_content_count in lexical overlap,
    # which drops the harmonic mean below the 0.50 sigil gate. For example,
    # "what is 20 divided by 5 constitutes equals blaze" promotes to
    # "&query &definition &n &op by &n constitutes equals blaze" — the extra
    # tokens make input_content = {&query, &definition, &n, &op, constitutes,
    # equals, blaze} = 7 tokens. Overlap with "&n &op &n" = {&n, &op} = 2.
    # input_coverage = 2/7 = 0.286, harmonic = 2*(0.286*1.0)/(0.286+1.0) =
    # 0.446, below the 0.50 gate. The expansion tokens are already in the
    # signal vector (words_to_signal runs on the full input), so they still
    # contribute to signal similarity for synonym-matched nodes. The promoted
    # text must stay CLEAN (only sigil-promoted tokens) for lexical overlap
    # to work correctly with sigil pattern nodes.

    # GRUG: Stash promotion results. Each scan_and_expand call OVERWRITES
    # any prior binding so stale state from a previous input never leaks.
    # Write to BOTH task-local storage AND module-level Refs:
    #   - Task-local: backward compat for code in the same task
    #   - Module-level Refs: survive @spawn Task boundaries (BUG-5 fix).
    # GRUG v8.19: _GLOBAL_PROMOTION_RAW should be the ORIGINAL user input
    # (pre-expansion), not the expanded text, so lexical overlap against
    # raw input works correctly for sigil nodes.
    task_local_storage(_PROMOTION_RAW_KEY,       promotion_source)
    task_local_storage(_PROMOTION_REWRITTEN_KEY, promoted_text)
    task_local_storage(_PROMOTION_BINDINGS_KEY,  promotion_bindings)
    lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_RAW[]        = promotion_source
        _GLOBAL_PROMOTION_REWRITTEN[]  = promoted_text
        _GLOBAL_PROMOTION_BINDINGS[]   = promotion_bindings
    end

    # GRUG v8.1-coherence-fix: ALSO stash per multipart_group if provided.
    # This is the key fix for multipart decoherence: each sub-scan's
    # bindings are stored under their group_id so synthesize_voice_reply
    # can look up the correct bindings for each sub-objective.
    stash_multipart_bindings!(multipart_group, promotion_bindings,
                              promoted_text, input)

    # GRUG v8.1: TIME ORIENTATION — extract temporal orientation from promotion
    # bindings and stash it the same way (task-local + global Ref).
    time_orient, time_meta = extract_time_orientation(promotion_bindings)
    task_local_storage(_TIME_ORIENTATION_KEY, (time_orient, time_meta))
    lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_TIME_ORIENTATION[] = (time_orient, time_meta)
    end
    if time_orient != "none"
        @info "[ENGINE v8.1] Time orientation detected: $(time_orient) (sigil=$(get(time_meta, "sigil_name", "?")), surface='$(get(time_meta, "surface", ""))')"
    end

    # GRUG: From here on, scan_specimens sees the PROMOTED text, not the raw
    # text. That is the whole point — one shape, one node.
    return scan_specimens(promoted_text; chunks=chunks)
end

"""
    bind_sigils(input_text::String, sigil_table) -> Dict{String,Vector{Any}}

GRUG: Convenience function that runs sigil promotion on an input string and
returns bindings grouped by name (via SigilPromoter.bindings_by_name).
Used by PettyLearner to get arithmetic bindings without having to know
about the promotion internals. Returns empty Dict on error.
"""
function bind_sigils(input_text::String, sigil_table)::Dict{String,Vector{Any}}
    if isempty(strip(input_text))
        return Dict{String,Vector{Any}}()
    end
    try
        _, bindings = SigilPromoter.promote_input(sigil_table, input_text)
        return SigilPromoter.bindings_by_name(bindings)
    catch e
        @warn "[ENGINE] bind_sigils failed: $e"
        return Dict{String,Vector{Any}}()
    end
end

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