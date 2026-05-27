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

# GRUG v7.21b-2: TonalJudge — token bag + common-sense judge that picks
# scaffold frame hints. Sits between predictor and scaffold. b-2 is
# plumbing-only (judge runs and surfaces [FRAME=...] but does not yet
# alter generate_aiml_payload — that's b-3).
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

# GRUG: Task-local handoff for the bindings produced by promote_input.
# scan_and_expand stashes these here so downstream phases (vote, ATP) can
# read them without changing return-tuple shapes. Stage 1.5a writes; Stage
# 1.5b reads (ATP arithmetic dispatch). Default empty so non-promoted text
# paths see a defined-but-empty side-channel.
#
# Stage 1.5a-fix-1 adds _PROMOTION_RAW_KEY: the ORIGINAL user input string,
# preserved verbatim. ATP needs it for tone signals (caps, written-out vs
# symbolic). AIML render needs it to echo back in the user's register.
# Without this, "what is 2+2" and "what is two plus two" look identical to
# every downstream phase, which is wrong.
const _PROMOTION_BINDINGS_KEY::Symbol  = :grugbot420_sigil_promotion_bindings
const _PROMOTION_REWRITTEN_KEY::Symbol = :grugbot420_sigil_promotion_rewritten
const _PROMOTION_RAW_KEY::Symbol       = :grugbot420_sigil_promotion_raw

"""
    current_promotion_bindings() -> Vector{SigilPromoter.SigilBinding}

Return the bindings produced by the most recent `scan_and_expand` call on
the current task, or an empty vector if none. Read-only accessor for
downstream phases (vote / ATP) to consume the side-channel.
"""
function current_promotion_bindings()::Vector{SigilPromoter.SigilBinding}
    val = get(task_local_storage(), _PROMOTION_BINDINGS_KEY, nothing)
    isnothing(val) && return SigilPromoter.SigilBinding[]
    # GRUG: defensive type assertion — if some other code clobbered the key
    # with the wrong type we want to know loudly rather than crash deeper in.
    if !(val isa Vector{SigilPromoter.SigilBinding})
        error("FATAL: task-local promotion bindings have wrong type: $(typeof(val))")
    end
    return val
end

"""
    current_promotion_rewritten() -> Union{String,Nothing}

Return the rewritten input string from the most recent `scan_and_expand`
call on the current task (the string that was actually fed to the matcher),
or `nothing` if no promotion has run on this task. Useful for telemetry
and round-trip assertions.
"""
function current_promotion_rewritten()::Union{String,Nothing}
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
    return get(task_local_storage(), _PROMOTION_RAW_KEY, nothing)
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
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj))
            elseif i + 2 <= length(tokens) && String(tokens[i+1]) == "about"
                obj = String(tokens[i+2])
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj))
            end
        elseif tok == "describe" && i + 1 <= length(tokens)
            obj = String(tokens[i+1])
            !isempty(obj) && push!(triples, RelationalTriple("describe", "targets", obj))
        elseif tok == "about" && i > 1 && i < length(tokens) && String(tokens[i-1]) == "what"
            obj = String(tokens[i+1])
            !isempty(obj) && push!(triples, RelationalTriple("what", "about", obj))
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

    if !isempty(required_relations)
        user_rels = Set([t.relation for t in user_triples])
        for req in required_relations
            # GRUG v7.21: NONJITTER is a behavioral tag, not a semantic relation.
            # Do not treat it as a missing requirement if the user didn't supply it.
            req == NONJITTER_TAG && continue
            if !(req in user_rels)
                # GRUG FIX 2.7: Sentinel Value for hard requirement miss!
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
            # GRUG: Weight itself gets the first nudge — same bullseye every
            # activation otherwise. jitter_weight is the sign-preserving wrapper.
            weight = jitter_w(get(relation_weights, ut.relation, 1.0))
            if ut.relation == nt.relation
                if ut.subject == nt.object && ut.object == nt.subject
                    match_score -= jitter_s(2.0 * weight)
                    is_antimatch = true
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

    return (final_score, is_antimatch)
end

# ==============================================================================
# STRENGTH CAP & APOPTOSIS CONSTANTS
# ==============================================================================

# GRUG: Strength lives in [0.0, STRENGTH_CAP]. At 0.0, node is marked grave.
# At STRENGTH_CAP, node cannot grow stronger (apoptosis ceiling / stratification).
const STRENGTH_CAP   = 10.0
const STRENGTH_FLOOR = 0.0

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

    # GRUG NEW: Neighbor linking (max neighbors rolled per-node 8-16 before UNLINKABLE)
    neighbor_ids::Vector{String}
    is_unlinkable::Bool              # GRUG: True when neighbor_ids reaches max_neighbors
    max_neighbors::Int               # GRUG: Per-node cap, rolled in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]

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
    antimatch::Bool
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
# GRUG: Attachment ≠ Neighbor linking. Neighbors are symmetric co-activation
# via drop tables. Attachments are ASYMMETRIC: target fires → attached MAY fire.
# Attached nodes don't cause the target to fire. One-way dependency chain.

mutable struct AttachedNode
    node_id::String          # GRUG: ID of the node being attached (must exist in NODE_MAP)
    pattern::String          # GRUG: Connector pattern — middleman reason WHY these nodes are related
    signal::Vector{Float64}  # GRUG: Pre-baked signal from connector pattern (for PatternScanner compat)
    base_confidence::Float64 # GRUG: JIT-baked confidence computed at attach time, NOT at fire time!
                             #       Formula: token_overlap(connector, attached_node.pattern) + (strength/CAP)*0.5
                             #       At fire time, only jitter is applied: max(0.1, base_confidence + jitter)
    is_crystalized::Bool     # GRUG (CRYSTALIZE spec): if true, skip the strength-biased coinflip —
                             #       this attachment ALWAYS fires when the target fires. Set by user
                             #       via /crystalize, or auto-set when the attached node has high
                             #       strength AND high semantic-truth on its relational triples.
                             #       Auto-revoked if strength drops below the crystalization floor.
    crystal_origin::Symbol   # GRUG: :user (manual /crystalize), :auto (semantic-truth triggered),
                             #       or :none (not crystalized). Lets the auto-revoker only touch
                             #       nodes it crystalized itself — manual marks stay sticky.
end

# Backwards-compat 4-arg constructor: old attach sites get a non-crystalized
# attachment by default. CRYSTALIZE-aware sites use the 6-arg form.
AttachedNode(node_id::String, pattern::String, signal::Vector{Float64}, base_confidence::Float64) =
    AttachedNode(node_id, pattern, signal, base_confidence, false, :none)

# GRUG: Map from target_node_id -> Vector of AttachedNode (max MAX_ATTACHMENTS each)
const ATTACHMENT_MAP  = Dict{String, Vector{AttachedNode}}()
const ATTACHMENT_LOCK = ReentrantLock()

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

mutable struct NodeGroup
    id::String                       # GRUG: Stable group id ("group_0", "group_1", ...)
    members::Vector{String}          # GRUG: Node ids \u2014 ORDER PRESERVED for cursor walks
    centroid_pattern::String         # GRUG: Pattern of the founding/seed node (similarity anchor)
    created_at::Float64              # GRUG: Unix timestamp at creation
    last_chatter_at::Float64         # GRUG: 0.0 = never chattered. Updated when group participates.
    chatter_count::Int               # GRUG: How many times this group has chattered (lifetime)
    has_grave_slot::Bool             # GRUG: True after a member is graved \u2014 grants UNLINKABLE override
                                     #       so a fresh node can fill the empty slot. Cleared when
                                     #       the slot is filled.
end

# GRUG: Backwards-friendly constructor. Most callers only know id+seed.
NodeGroup(id::String, seed_node_id::String, centroid_pattern::String) =
    NodeGroup(id, [seed_node_id], centroid_pattern, time(), 0.0, 0, false)

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

"""
    next_group_id() -> String

GRUG: Atomic group id minter. Always returns a unique "group_<n>" string.
Underlying counter is reset only by full engine reset (reset_engine!).
"""
function next_group_id()::String
    n = atomic_add!(GROUP_COUNTER, 1)
    return "group_$n"
end

"""
    register_group!(seed_node::Node) -> NodeGroup

GRUG: Create a fresh group seeded by a single node. The node becomes the
group's centroid \u2014 future joiners are evaluated against this pattern. Idempotent
when the seed already belongs to a group: returns the existing group.
NO SILENT FAILURES: errors if seed_node has empty pattern.
"""
function register_group!(seed_node::Node)::NodeGroup
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
        grp = NodeGroup(gid, seed_node.id, seed_node.pattern)
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
"""
function add_to_group!(group::NodeGroup, node_id::String)::Bool
    if isempty(strip(node_id))
        error("!!! FATAL: add_to_group! got empty node_id! !!!")
    end
    return lock(GROUP_LOCK) do
        if node_id in group.members
            return false
        end
        push!(group.members, node_id)
        NODE_TO_GROUP[node_id] = group.id
        # GRUG: Filling a graved slot clears the override.
        group.has_grave_slot = false
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

# GRUG: Hard cap on how many nodes can be bolted onto one target. User said 4.
const MAX_ATTACHMENTS = 4

# GRUG: Small stochastic jitter applied to co-fired node confidence.
# Biologically motivated — synaptic relay is noisy. Same neuron doesn't fire
# with identical strength every time it gets woken by a relay. Keeps the vote
# pool from collapsing to the same winner every cycle when attachments fire.
# Magnitude is small (sigma=0.05) so it nudges but never dominates.
const RELAY_CONF_JITTER_SIGMA = 0.05


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
])


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
            # CRYSTALIZE: crystalized attachments SKIP the coinflip — they always
            # fire when the target fires. This is the user-spec'd hard-fire path.
            if !att.is_crystalized && !strength_biased_scan_coinflip(attach_node_ref)
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
            #
            # GRUG v7.20 VOTE-LEVEL OVERRIDE: even on a NONJITTER node, if the
            # base confidence carried by the attachment is below
            # JITTER_CONFIDENCE_FLOOR, the relay still jitters. "Solid rock,
            # weak signal → still nudge it; we don't ossify guesses." This
            # uses the same single-source-of-truth helper jitter_allowed_for
            # used by the scan-side override.
            jitter = jitter_allowed_for(attach_node_ref, att.base_confidence) ?
                     randn() * RELAY_CONF_JITTER_SIGMA :
                     0.0
            confidence = max(0.1, att.base_confidence + jitter)

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
                crystal_tag = att.is_crystalized ? " 💎[CRYSTAL:$(att.crystal_origin)]" : ""
                push!(lines, "      🔗 $(att.node_id) $node_status$crystal_tag | base_conf=$(round(att.base_confidence, digits=3)) | connector=\"$(first(att.pattern, 35))\"")
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
    crystalize_attachment!(target_id, attach_id; origin=:user) -> String

GRUG: Mark the attachment from `target_id`→`attach_id` as crystalized so it
fires unconditionally on target activation. Returns a status string. Errors
if no such attachment exists.

`origin` should be `:user` for manual marks (sticky) or `:auto` for
auto-crystallizer marks (revocable when strength drops).
"""
function crystalize_attachment!(target_id::String, attach_id::String;
                                origin::Symbol = :user)::String
    if origin ∉ (:user, :auto)
        error("!!! FATAL: crystalize_attachment! origin must be :user or :auto, got :$origin !!!")
    end
    found = false
    msg = ""
    lock(ATTACHMENT_LOCK) do
        atts = get(ATTACHMENT_MAP, target_id, AttachedNode[])
        for (i, att) in enumerate(atts)
            if att.node_id == attach_id
                if att.is_crystalized && att.crystal_origin == origin
                    msg = "Attachment $target_id→$attach_id already crystalized (origin=:$(origin))."
                else
                    # Replace in-place via reassignment (mutable struct so
                    # we can also just mutate fields, but reassignment keeps
                    # the API symmetric with non-mutable-friendly callers).
                    att.is_crystalized = true
                    att.crystal_origin = origin
                    msg = "💎 Attachment $target_id→$attach_id CRYSTALIZED (origin=:$(origin)). Always fires."
                end
                found = true
                break
            end
        end
    end
    if !found
        error("!!! FATAL: crystalize_attachment! found no attachment from '$target_id' to '$attach_id' !!!")
    end
    return msg
end

"""
    decrystalize_attachment!(target_id, attach_id; force=false) -> String

GRUG: Clear the crystalize tag. By default this only clears `:auto` marks
(so the auto-revoker can't accidentally remove a manual mark). Pass
`force=true` to also clear `:user` marks (used by /decrystalize).
"""
function decrystalize_attachment!(target_id::String, attach_id::String;
                                  force::Bool = false)::String
    found = false
    msg = ""
    lock(ATTACHMENT_LOCK) do
        atts = get(ATTACHMENT_MAP, target_id, AttachedNode[])
        for att in atts
            if att.node_id == attach_id
                if !att.is_crystalized
                    msg = "Attachment $target_id→$attach_id was not crystalized."
                elseif att.crystal_origin == :user && !force
                    msg = "Attachment $target_id→$attach_id is :user-crystalized — pass force=true (or use /decrystalize)."
                else
                    prev = att.crystal_origin
                    att.is_crystalized = false
                    att.crystal_origin = :none
                    msg = "🪨 Attachment $target_id→$attach_id de-crystalized (was :$prev)."
                end
                found = true
                break
            end
        end
    end
    if !found
        error("!!! FATAL: decrystalize_attachment! found no attachment from '$target_id' to '$attach_id' !!!")
    end
    return msg
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

GRUG: Walk every attachment in ATTACHMENT_MAP. Auto-crystallize attachments
whose attached node has BOTH:
  - strength >= CRYSTAL_AUTO_STRENGTH_FLOOR, AND
  - semantic_truth_score >= CRYSTAL_AUTO_SEMANTIC_FLOOR
Auto-revoke attachments previously auto-crystalized whose strength has
dropped below CRYSTAL_AUTO_REVOKE_FLOOR. Manual (`:user`) marks are never
touched. Returns (crystallized_count, revoked_count).

Called from the idle / phagy sweep loop. Cheap to run — O(attachments).
"""
function auto_crystalize_sweep!()::Tuple{Int, Int}
    crystallized = 0
    revoked = 0
    lock(ATTACHMENT_LOCK) do
        for (target_id, atts) in ATTACHMENT_MAP
            for att in atts
                node = lock(() -> get(NODE_MAP, att.node_id, nothing), NODE_LOCK)
                isnothing(node) && continue
                node.is_grave && continue

                if att.is_crystalized && att.crystal_origin == :auto
                    if node.strength < CRYSTAL_AUTO_REVOKE_FLOOR
                        att.is_crystalized = false
                        att.crystal_origin = :none
                        revoked += 1
                    end
                elseif !att.is_crystalized
                    if node.strength >= CRYSTAL_AUTO_STRENGTH_FLOOR &&
                       _semantic_truth_score(node) >= CRYSTAL_AUTO_SEMANTIC_FLOOR
                        att.is_crystalized = true
                        att.crystal_origin = :auto
                        crystallized += 1
                    end
                end
                # :user marks are sticky — never auto-touched.
            end
        end
    end
    return (crystallized, revoked)
end

"""
    is_crystalized(target_id, attach_id) -> Bool

GRUG: Convenience query. Returns false if attachment doesn't exist.
"""
function is_crystalized(target_id::String, attach_id::String)::Bool
    return lock(ATTACHMENT_LOCK) do
        atts = get(ATTACHMENT_MAP, target_id, AttachedNode[])
        for att in atts
            att.node_id == attach_id && return att.is_crystalized
        end
        return false
    end
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
    latched_to_id = nothing
    if !is_image_node && map_size >= NODE_LATCH_THRESHOLD
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
    elseif !is_image_node && map_size < NODE_LATCH_THRESHOLD
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
    #   - If we did not latch (small map, no candidates, or partner full):
    #     seed a new group with this node as the founder.
    # Image nodes do not chatter — SDF semantics differ — so they skip groups.
    if !is_image_node
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
                    add_to_group!(partner_grp, id)
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

v7.20 VOTE-LEVEL OVERRIDE (`jitter_floor`):
  The NONJITTER tag is a *baseline*, not an absolute. If `nonjitter=true` BUT
  the fused coherence comes in below `jitter_floor`, jitter still runs on the
  output. This stops a solidified node from ossifying a low-confidence guess.
  Default `jitter_floor=0.0` preserves the old behavior (no override). The
  scan_and_expand caller passes `jitter_floor=JITTER_CONFIDENCE_FLOOR` to
  activate the override system-wide.
"""
function _bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3,
    nonjitter::Bool = false,
    jitter_floor::Float64 = 0.0
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
    #
    # v7.20 VOTE-LEVEL OVERRIDE: NONJITTER is a *baseline*, not an absolute.
    # When jitter_floor > 0 and the fused coherence falls below it, jitter
    # runs even on a NONJITTER node. The semantics: a solidified rock that's
    # only 30% sure of itself on this firing is *guessing*, and we don't want
    # to ossify the guess. High-confidence firings (≥ floor) on solidified
    # rocks remain bit-stable. Default jitter_floor=0.0 disables the override
    # (old behavior).
    suppress_jitter = nonjitter && smoothed_conf >= jitter_floor
    final_conf = suppress_jitter ? smoothed_conf : slight_jitter(smoothed_conf)

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

GRUG: Before scanning a node, flip a biased coin.
Strong nodes are more likely to be scanned and activated.
Weak nodes can still get scanned, but less often (keeps competition alive).

Probability formula: base_prob + (strength / STRENGTH_CAP) * bonus_prob
  - Weakest node (strength=0.0): 20% chance of scan
  - Average node (strength=5.0): 60% chance
  - Strongest node (strength=10.0): 90% chance
"""
function strength_biased_scan_coinflip(node::Node)::Bool
    base_prob  = 0.20
    bonus_prob = 0.70
    scan_prob  = base_prob + (node.strength / STRENGTH_CAP) * bonus_prob
    return rand() < clamp(scan_prob, 0.0, 1.0)
end

# ==============================================================================
# MAIN SCAN FUNCTION
# ==============================================================================

"""
scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}}

GRUG: Main scan entry point. Converts input text to signal, extracts relational
triples, runs ActionTonePredictor, checks Hopfield fast-path, then scans all
nodes for matches. Returns vector of (id, confidence, antimatch, user_triples,
node_triples) tuples. Throws on empty input — NO SILENT FAILURES.
"""
function scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}}
    if strip(input_text) == ""
        error("!!! FATAL: Grug cannot scan empty air! Input text is blank! !!!")
    end

    all_valid_specimens = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]
    
    # GRUG: Convert input to number rocks!
    target_signal = words_to_signal(input_text)

    # GRUG: LITERAL TOKEN PRE-GATE — input side.
    # Compute the lowercased, whitespace-split token set of the input ONCE here
    # so every fire_one call can do a cheap set lookup. The gate exists because
    # words_to_signal hashes tokens to uniformly-distributed Float64 values in
    # [0, 1], and the matcher then accepts |a - b| <= 0.1 as a "match." That
    # gives unrelated word pairs a ~20% false-match rate per token comparison,
    # which is why nodes from semantically unrelated lobes kept firing on
    # short inputs. The fix: require at least one literal token of the node's
    # pattern to appear in the input (or vice-versa for short inputs) BEFORE
    # the float scanner gets to vote. Float math still runs on the survivors —
    # it's the fuzzy-refinement step on top of a real lexical hit.
    #
    # Thesaurus expansion is intentionally NOT applied here. The thesaurus is
    # an orchestration / synthesis-time concern, not a matching one — the
    # scanner's job is to find what literally hit, the synthesizer's job is
    # to remix the result with synonyms. See Main.jl:1339 for that path.
    input_token_set = Set(split(lowercase(strip(input_text))))
    
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

    # GRUG: ACTION+TONE PRE-PREDICTION (DIAGNOSTIC ONLY)
    # Side processes must NEVER affect vote confidence. ActionTonePredictor may
    # observe, log, and populate LAST_PREDICTION for UI/telemetry, but the scan
    # score below remains pure core matching: token_conf + rel_conf.
    # If prediction fails for any reason, Grug logs warning and continues.
    prediction = try
        ActionTonePredictor.predict_action_tone(input_text, SemanticVerbs.get_all_verbs())
    catch e
        @warn "[ENGINE] ActionTonePredictor failed (non-fatal): $e"
        nothing
    end

    if !isnothing(prediction)
        # GRUG v7.21b-3a: Run the TonalJudge against the prediction so its
        # frame_hint verdict lands in LAST_JUDGEMENT. b-3a is OBSERVATION-ONLY
        # at the orchestrator level — the judge runs and surfaces a [FRAME=...]
        # diagnostic, but no scoring dimension reads it yet (that's b-3b). If
        # judging fails for any reason, log and continue — the existing log
        # line keeps working without the frame tag.
        frame_str = try
            judgement = TonalJudge.judge_from_prediction(prediction)
            mode_label = judgement.mode === TonalJudge.RELATIONAL ? "rel" : "basic"
            " [FRAME=$(TonalJudge.frame_hint_label(judgement.frame_hint))/$(mode_label)]"
        catch e
            @warn "[ENGINE] TonalJudge.judge_from_prediction failed (non-fatal): $e"
            ""
        end

        @info "[ENGINE] 🔮 $(ActionTonePredictor.format_prediction_summary(prediction))$(frame_str)"
        # GRUG: If predictor found a dangling verb (incomplete causal chain), warn user.
        # Informational only -- scan still proceeds, but output may be less coherent.
        if prediction.incomplete_chain
            @warn "[ENGINE] Incomplete causal chain detected (dangling verb: '$(prediction.dangling_verb)'). Input may be truncated."
        end
    end

    # GRUG: HOPFIELD FAST-PATH — REMOVED (SMELL-003 cleanup)
    # ============================================================================
    # The Hopfield cache fast-path was disabled and left as a 30-line comment
    # block. Removed during the QoL sweep — git history preserves the original.
    # If you need to re-enable familiar-input caching for very large lobes
    # (50k+ nodes per lobe), reintroduce a minimal lookup here. Current 1000-
    # node-per-cycle cap makes this unnecessary.
    # ============================================================================

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
    # Returns shape: (id, confidence, is_antimatch, user_triples, node_triples)
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

        # GRUG: LITERAL TOKEN PRE-GATE — pattern side.
        # Hard correctness gate AND coinflip-bypass for text nodes.
        #
        # Order is intentional: this runs BEFORE strength_biased_scan_coinflip.
        # Why? Because the coinflip is a "should we burn cycles on fuzzy work?"
        # gate. If the input literally contains one of the node's pattern
        # tokens, the work is already justified — there's no reason to skip
        # a sure thing 70% of the time just because the node is freshly
        # created with strength=1.0. That was causing weak-but-relevant nodes
        # (e.g. greeting's "good morning" node firing on input "good morning")
        # to go silent half the time.
        #
        # Behavior matrix:
        #   text node + literal-token hit  → BYPASS coinflip, fall through to scanner.
        #   text node + no literal hit     → reject outright (no fuzzy noise vote).
        #   text node + empty pattern      → coinflip as before.
        #   image node                     → coinflip as before (uses SDF signal,
        #                                    different match path entirely).
        # GRUG: STOPWORDS — closed-class words that match almost anything.
        # The float-hash scanner cannot distinguish "shared stop-word" from
        # "shared content-word", so a node that only collides with the input
        # on `the` or `for` will get the same hash-window similarity boost
        # as a node that genuinely shares `cliff`. We exclude stop-words from
        # the literal-hit decision: if the ONLY shared tokens are stop-words,
        # the node falls back to coinflip-gated scanning like an OOV node.
        # Content overlap still grants literal_hit and bypasses the coinflip.
        literal_hit = false
        literal_jaccard = 0.0
        if !node.is_image_node && !isempty(node.pattern)
            pattern_token_set = Set(split(lowercase(strip(node.pattern))))
            if !isempty(pattern_token_set) && !isempty(input_token_set)
                shared = intersect(pattern_token_set, input_token_set)
                # GRUG: Strip stop-words from the shared set for the gate decision.
                # Pattern AND input both lose stop-words from the union for Jaccard
                # so a single content-word match scores reasonably (e.g. "cliff"
                # in "watch out for the cliff" vs "beware the cliff edge" gives
                # content-Jaccard = 1/4 = 0.25 instead of full-Jaccard = 1/8).
                shared_content = Set(t for t in shared if !(t in STOPWORDS))
                if isempty(shared_content)
                    # No CONTENT token in common → not a real lexical hit. Don't
                    # grant the literal bypass; let coinflip decide. Still allow
                    # the scan to run if coinflip passes (image-node behavior).
                    literal_hit = false
                    # We still know there's *some* overlap (stop-word). Reject
                    # outright like the original gate did when shared was empty:
                    # patterns sharing only stop-words with the input are noise.
                    return nothing
                else
                    literal_hit = true
                    pat_content = Set(t for t in pattern_token_set if !(t in STOPWORDS))
                    inp_content = Set(t for t in input_token_set if !(t in STOPWORDS))
                    union_content = union(pat_content, inp_content)
                    union_size = isempty(union_content) ?
                        length(union(pattern_token_set, input_token_set)) :
                        length(union_content)
                    literal_jaccard = length(shared_content) / max(1, union_size)
                end
            end
        end

        # GRUG: STRENGTH-BIASED COINFLIP — only runs when no literal hit decided
        # the question. A literal-token match is a sure thing; don't roll dice
        # on it. Image nodes and empty-pattern nodes still go through coinflip
        # because their match path can't be cheaply pre-gated by tokens.
        if !literal_hit
            if !strength_biased_scan_coinflip(node)
                return nothing
            end
        end

        # GRUG: Image nodes use SDF signal, not text signal. Skip size check for them.
        # BUG-004: When pattern is longer than user input, the original code
        # SILENTLY skipped the node. Now we downgrade to cheap bidirectional
        # scan instead — the bidirectional scan handles short-input-vs-long-pattern
        # by matching on the shorter side. We also tag this so we log it once
        # per node lifetime (not on every fire — that would spam).
        long_pattern_short_input = false
        if !node.is_image_node
            if length(target_signal) < length(node.signal)
                long_pattern_short_input = true
                # One-shot warning per node: only the first time this fires.
                if !get(node.json_data, "_long_pattern_warn_emitted", false)
                    @warn "[ENGINE] BUG-004: pattern longer than input — using cheap bidirectional scan." node_id=node.id pattern_len=length(node.signal) input_len=length(target_signal)
                    try
                        node.json_data["_long_pattern_warn_emitted"] = true
                    catch
                        # data might be read-only in some paths — silent ok
                    end
                end
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

            # BUG-004: If pattern is longer than input, FORCE cheap bidirectional
            # scan regardless of complexity tier. Higher tiers assume input ≥ pattern.
            if long_pattern_short_input
                effective_mode = 1
            end

            if effective_mode == 1
                # GRUG: BIDIRECTIONAL CHEAP SCAN — simple patterns (≤3 signal elements)
                # v7.20: pass per-node NONJITTER opt-out so anchor / calibration /
                # canonical-form nodes return bit-stable confidence. Tag lives in
                # node.required_relations (see is_nonjitter / set_nonjitter! above).
                #
                # v7.20 VOTE-LEVEL OVERRIDE: also pass JITTER_CONFIDENCE_FLOOR so a
                # solidified rock firing low-confidence still gets jittered. The
                # combined behavior is "high-conf solid: silent; low-conf solid:
                # still jitters; unsolid: always jitters." See jitter_allowed_for.
                #
                # BUG-004: When pattern is longer than input, swap arg roles so
                # the (smaller) input acts as the pattern and the (larger) node
                # signal acts as the target. The cheap scan loops `(length(target)
                # - pat_len + 1)` and would otherwise have an empty range.
                if long_pattern_short_input
                    _, token_conf = _bidirectional_cheap_scan(
                        node.signal, target_signal;
                        threshold=CHEAP_SCAN_THRESHOLD,
                        nonjitter=is_nonjitter(node),
                        jitter_floor=JITTER_CONFIDENCE_FLOOR
                    )
                else
                    _, token_conf = _bidirectional_cheap_scan(
                        target_signal, node.signal;
                        threshold=CHEAP_SCAN_THRESHOLD,
                        nonjitter=is_nonjitter(node),
                        jitter_floor=JITTER_CONFIDENCE_FLOOR
                    )
                end
            elseif effective_mode == 2
                _, token_conf = medium_scan(target_signal, node.signal; threshold=MEDIUM_SCAN_THRESHOLD)
            else
                _, token_conf = high_res_scan(target_signal, node.signal; threshold=HIGH_SCAN_THRESHOLD)
            end
        catch e
            if e isa PatternNotFoundError
                # Normal logic: Scanner says no match in any direction.
                #
                # BUT: if the literal-token gate confirmed a real lexical hit
                # earlier, we don't want to silently drop this node just
                # because the float scanner couldn't find a clean window. A
                # short pattern (e.g. "hello hi") embedded in a longer input
                # (e.g. "hello again old friend") will fail cheap_scan's
                # window threshold even though "hello" is literally present —
                # the noise tokens around it drag the per-window similarity
                # below CHEAP_SCAN_THRESHOLD.
                #
                # Resolution: when literal_hit=true, fall back to the Jaccard
                # of pattern_tokens ∩ input_tokens / pattern_tokens ∪ input_tokens
                # as a literal-hit floor. This is honest about partial overlap:
                # full overlap → ~1.0, single-word-of-many → low. Still gives
                # the node a fair shot at the vote pool instead of dropping it.
                if literal_hit
                    token_conf = literal_jaccard
                else
                    return nothing
                end
            elseif e isa PatternScanError
                # FATAL LOGIC ERROR. NO SILENT FAILURE! Scream loud!
                rethrow(e)
            else
                error("!!! FATAL: Unknown error during complexity-based pattern scan: $e !!!")
            end
        end

        # GRUG: LITERAL-JACCARD BLEND.
        # The float-hash scanner produces unreliable inflation when only stop
        # words or hash collisions happen to align — it can score 0.5 for a
        # pattern that genuinely shares only one content token. Now that the
        # literal-token pre-gate guarantees real content overlap, we blend the
        # scanner's output with the content-Jaccard so the final score reflects
        # actual lexical overlap rather than hash noise.
        #
        # final = JACCARD_BLEND_W * jaccard + (1 - JACCARD_BLEND_W) * cheap_scan
        # The blend is only applied when literal_hit fired AND we got a real
        # cheap_scan number (not the Jaccard fallback path above). Jaccard is
        # already honest by construction; the scanner is the noisy one.
        if literal_hit && token_conf > 0.0
            JACCARD_BLEND_W = 0.6
            blended = JACCARD_BLEND_W * literal_jaccard + (1.0 - JACCARD_BLEND_W) * token_conf
            token_conf = blended
        end

        # 2. Relational Matcher (Dialectical)
        rel_conf, is_antimatch = evaluate_relational_dialectics(
            user_triples, node.relational_patterns, node.required_relations, node.relation_weights
        )

        # 3. Hard Anti-Match / Missing Requirement Penalty
        # GRUG: -9999.0 means node demanded a gear user did not have!
        if is_antimatch || rel_conf == -9999.0
            return nothing
        end

        confidence = token_conf + rel_conf

        # GRUG v7.21c-5: Side-process isolation.
        # Do NOT multiply confidence by ActionTonePredictor, TonalJudge, memory,
        # lobe routing, timing ledgers, or any other auxiliary process. Vote
        # confidence is the raw result of core node matching only.

        if token_conf > 0 || rel_conf > 0
            # GRUG: Node wants to fire. Claim a slot from the shared FireCounter.
            # If cap reached, skip — hard cap applies to ALL fire paths.
            if !VoteOrchestrator.try_claim_fire_slot!(fc)
                return nothing
            end
            # GRUG DEBUG: gated diagnostic for fire trace.
            if get(ENV, "GRUG_DEBUG_FIRE", "") != ""
                try
                    @info "[FIRE] $(node.id) pat='$(node.pattern)' act='$(node.action_packet)' tok=$(round(token_conf,digits=3)) rel=$(round(rel_conf,digits=3)) conf=$(round(confidence,digits=3)) lit=$(literal_hit) jac=$(round(literal_jaccard,digits=3))"
                catch
                end
            end
            return (id, confidence, is_antimatch, user_triples, node.relational_patterns)
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
  When a primary node lives in a lobe, cascade into other lobes —
  but ONLY inject a non-primary lobe's node if its own pattern signal
  shares at least one token with the input (within scan tolerance).
  This is the "share at least one node pattern token with the input"
  rule the original cascade design promised but never enforced.
  Without this gate, every lobe got its full node set injected at the
  cascade discount whenever ANY primary fired loudly — flooding the
  vote pool with semantically unrelated nodes from every domain and
  collapsing routing to coinflip-on-a-flat-plateau. The gate keeps
  cross-lobe talk alive (genuinely overlapping queries still cascade)
  while killing the indiscriminate flood.
  Cascade threshold: 0.15 (soft gate on cascade_conf).
  Cascade confidence: 60% of the highest primary confidence (cross-lobe discount).
"""
function scan_and_expand(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}}
    # ──────────────────────────────────────────────────────────────────────
    # STAGE 1.5a — FRONT-DOOR SIGIL PROMOTION
    # ──────────────────────────────────────────────────────────────────────
    # GRUG: Before anything else, run the input through the SigilPromoter.
    # Two layers:
    #   Layer 1 — thesaurus canonicalization ("two plus two" -> "2 + 2")
    #   Layer 2 — registry shape promotion   ("2 + 2"        -> "&n &op &n")
    # The matcher downstream just compares strings; pre-rewriting collapses
    # many surface variants of the same shape onto ONE pattern bucket. For
    # pure-text inputs (no digits, no math words) the rewrite is a no-op
    # confidence-equivalence guarantee; existing tests are unaffected.
    #
    # The bindings (position-keyed Vector{SigilBinding}) get stashed into
    # task-local storage so downstream phases (vote, ATP) can read them
    # without changing the scan_and_expand return-tuple shape. ATP arithmetic
    # dispatch (Stage 1.5b) reads from current_promotion_bindings().
    #
    # No silent failures: if the promoter raises, we let it propagate. The
    # alternative (catch + fall back to raw input) would mask configuration
    # bugs in specimen-level registries, exactly the kind of thing we need
    # to surface loudly.
    promoted_text, promotion_bindings = SigilPromoter.promote_input(
        _ENGINE_SIGIL_TABLE, input_text)

    # GRUG: Stash on the current task. Each scan_and_expand call OVERWRITES
    # any prior binding so stale state from a previous input never leaks.
    # Three keys:
    #   _PROMOTION_RAW_KEY        — the user's verbatim input (Stage 1.5a-fix-1)
    #   _PROMOTION_REWRITTEN_KEY  — the matcher-ready promoted string
    #   _PROMOTION_BINDINGS_KEY   — Vector{SigilBinding} side-channel
    task_local_storage(_PROMOTION_RAW_KEY,       input_text)
    task_local_storage(_PROMOTION_REWRITTEN_KEY, promoted_text)
    task_local_storage(_PROMOTION_BINDINGS_KEY,  promotion_bindings)

    # GRUG: From here on, scan_specimens and the cascade gates see the
    # PROMOTED text, not the raw text. That is the whole point — one shape,
    # one node.
    primary_results = scan_specimens(promoted_text)

    if isempty(primary_results)
        return primary_results
    end

    # GRUG: Pre-compute input CONTENT TOKEN SET once for cascade overlap gate.
    # We compare cascade-candidate nodes' pattern-token sets against this set
    # (CONTENT tokens only, stop-words stripped) to decide whether a cross-lobe
    # node's pattern is genuinely related to the input. The original gate used
    # signal-hash bands, which suffer the same hash-collision noise as the
    # primary scanner — every "the/for/a" overlap let cross-lobe garbage in.
    # Switching to content tokens makes the gate semantically honest.
    #
    # NOTE: we use the PROMOTED text here for the same reason the primary
    # scanner does — cascade gates need to see the same token universe the
    # matcher does, otherwise sigil tokens (&n, &op) wouldn't gate properly.
    cascade_input_tokens = try
        Set(t for t in split(lowercase(strip(promoted_text))) if !(t in STOPWORDS))
    catch
        Set{SubString{String}}()
    end

    # GRUG: Track which IDs are already in the result set to avoid duplicates
    already_included = Set(r[1] for r in primary_results)
    expanded = copy(primary_results)

    user_triples = extract_relational_triples(input_text)
    max_primary_conf = maximum(r[2] for r in primary_results)

    # ── PASS 1: Drop-table expansion (same lobe, 80% confidence discount) ──────
    for (id, conf, antimatch, u_trips, n_trips) in primary_results
        activating_node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        isnothing(activating_node) && continue

        drop_neighbors = collect_drop_table_neighbors(activating_node)
        for drop_id in drop_neighbors
            if !(drop_id in already_included)
                drop_node = lock(() -> get(NODE_MAP, drop_id, nothing), NODE_LOCK)
                isnothing(drop_node) && continue

                # GRUG: Drop-table neighbor gets discounted confidence (80% of activator)
                drop_conf = conf * 0.8
                push!(expanded, (drop_id, drop_conf, false, user_triples, drop_node.relational_patterns))
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
            for (id, conf, _, _, _) in primary_results
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

                        # GRUG: CONTENT-TOKEN OVERLAP GATE — only cascade if this
                        # node's pattern shares at least one CONTENT token (non
                        # stop-word) with the input. The original gate compared
                        # signal-hash bands and leaked through every "the/for/a"
                        # collision, flooding routing with cross-lobe noise.
                        # Switching to content tokens makes the gate honest.
                        if cascade_node.is_image_node
                            continue
                        end
                        if isempty(cascade_input_tokens) || isempty(cascade_node.pattern)
                            continue
                        end
                        cand_tokens = Set(t for t in split(lowercase(strip(cascade_node.pattern)))
                                          if !(t in STOPWORDS))
                        if isempty(cand_tokens)
                            continue
                        end
                        if isempty(intersect(cand_tokens, cascade_input_tokens))
                            continue  # GRUG: No shared content token → skip.
                        end

                        push!(expanded, (node_id, cascade_conf, false, user_triples, cascade_node.relational_patterns))
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
    relay_additions = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    for (id, conf, antimatch, u_trips, n_trips) in expanded
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
                push!(relay_additions, (fired_id, fired_conf, false, user_triples, relay_triples))
                push!(already_included, fired_id)
            end
        end
    end

    if !isempty(relay_additions)
        append!(expanded, relay_additions)
        println("[ENGINE] 🔗  Attachment relay pass added $(length(relay_additions)) node(s) to expanded set.")
    end

    # ── LOBE CURVE — averages-based selection (replaces the v7.18 hard mute) ──
    # GRUG: After all expansion passes, group entries by lobe and compute the
    # base_avg × top_avg curve. Winner lobe goes first; runners-up that pass
    # the multi-lobe threshold (score >= MIN_PASS_THROUGH_SCORE AND >=
    # MIN_WINNING_VOTES_PER_LOBE hard-selected votes) fire after. Lobes that
    # don't clear are dropped from the firing list. Cross-domain leakage is
    # naturally prevented because off-topic lobes will have low confidence
    # averages even if they lexically match a few tokens. No hard subject-
    # token muting needed. See plans/semantic_plugins/QOL_SWEEP_2025.md
    # "BUG-011 rewrite" for the architectural reasoning.
    expanded = try
        if isempty(expanded)
            expanded
        else
            orders = LobeOrchestrator.score_lobes(expanded, Lobe.find_lobe_for_node)
            if isempty(orders)
                # No lobe cleared (would only happen with totally empty pool).
                # Return empty — downstream prints "Cave is silent" cleanly.
                eltype(expanded)[]
            else
                # Loud trace so operators see the curve at work.
                println("[ORCHESTRATOR] 🎯 ", LobeOrchestrator.last_summary())
                LobeOrchestrator.flatten_in_fire_order(orders)
            end
        end
    catch e
        @warn "[ORCHESTRATOR] lobe curve FAILED (continuing with unfiltered pool): $e"
        expanded
    end

    return expanded
end

# ==============================================================================
# VOTE CASTING  
# ==============================================================================

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

    winning_action, negatives = select_action(node.action_packet)
    
    # GRUG FIX 2.8: Include bad action name in error!
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG NEW: Bump strength on a coinflip when a node votes (used = maybe stronger)
    bump_strength!(node)

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
    ensure_action_packet_registered!(action_packet::AbstractString)

GRUG v7.21c-2: PROSE-SLOT REGISTRY HELPER.

Walks every slot in an action_packet. For each slot's action_name, if it
is not already in COMMANDS:
  - If it looks like prose (>=2 words AND >=8 chars), auto-register a
    passthrough handler that funnels through `generate_aiml_payload`.
  - Otherwise (single short word, looks like a typo): raise a FATAL error
    with the list of valid actions, preserving QoL-2025 BUG-007 behavior.

Called from grow_nodes_from_packet (seed-time) and from load_specimen
(restore-time), so prose-slot nodes survive a save/load round-trip.

Idempotent: registering the same prose action twice is a no-op.
"""
function ensure_action_packet_registered!(action_packet::AbstractString)
    for entry in split(action_packet, '|')
        cleaned = strip(entry)
        isempty(cleaned) && continue
        no_brackets = replace(cleaned, r"\[[^\]]*\]" => "")
        action_name = String(strip(split(no_brackets, '^')[1]))
        isempty(action_name) && continue
        haskey(COMMANDS, action_name) && continue

        is_prose_slot = (length(split(action_name)) >= 2) && (length(action_name) >= 8)
        if is_prose_slot
            COMMANDS[action_name] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
                return Base.invokelatest(generate_aiml_payload, mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
            end
        else
            valid_actions = sort(collect(keys(COMMANDS)))
            valid_list = join(valid_actions, ", ")
            error("!!! FATAL: action_packet contains unknown action '$action_name'. " *
                  "Valid actions: $valid_list. " *
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

    validated = Vector{Tuple{String,String,Dict{String,Any},Vector{String},Bool}}()
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

        drop_table   = haskey(n, "drop_table") && (n["drop_table"] isa AbstractVector) ?
                       String[string(x) for x in n["drop_table"]] : String[]
        # GRUG NEW: Check for is_image_node flag in JSON packet
        is_img_node  = haskey(n, "is_image_node") && n["is_image_node"] === true

        # GRUG QoL-2025 BUG-007 + v7.21c-2 PROSE-SLOT EXTENSION:
        # Validate every action name against COMMANDS at grow time, but
        # auto-register prose answer-slots (multi-word, 8+ chars). Single-word
        # unknown actions are still treated as typos.
        ensure_action_packet_registered!(action_packet)

        push!(validated, (pattern, action_packet, json_data, drop_table, is_img_node))
    end

    new_ids = String[]
    for (p, a, j, d, is_img) in validated
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
        nid = create_node(p, a, j, d; is_image_node=is_img, initial_strength=init_str)
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