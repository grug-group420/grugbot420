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

# GRUG: Bring the Action+Tone Predictor (pre-vote arousal tuning and confidence weighting)!
# GRUG: Guard against double-include if ActionTonePredictor already loaded by caller.
if !isdefined(@__MODULE__, :ActionTonePredictor)
    include("ActionTonePredictor.jl")
    using .ActionTonePredictor
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

    if !isempty(required_relations)
        user_rels = Set([t.relation for t in user_triples])
        for req in required_relations
            if !(req in user_rels)
                # GRUG FIX 2.7: Sentinel Value for hard requirement miss!
                return (-9999.0, false) 
            end
        end
    end

    for ut in user_triples
        for nt in node_triples
            weight = get(relation_weights, ut.relation, 1.0)
            if ut.relation == nt.relation
                if ut.subject == nt.object && ut.object == nt.subject
                    match_score -= (2.0 * weight)
                    is_antimatch = true
                elseif ut.subject == nt.subject && ut.object == nt.object
                    match_score += (2.0 * weight)
                elseif ut.subject == nt.subject || ut.object == nt.object
                    match_score += (1.0 * weight)
                else
                    orthogonal_penalty += (0.5 * weight)
                end
            end
        end
    end

    # GRUG COHERENCE FIX: Don't let large user paragraphs nuke perfectly matched triples!
    if match_score > 0
        final_score = max(0.1, match_score - (orthogonal_penalty * 0.1))
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
            end
        end
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
    println("[ENGINE] ⚰  Node $(node.id) marked GRAVE: [$reason].")
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

# GRUG: Hard cap on how many nodes can be bolted onto one target. User said 4.
const MAX_ATTACHMENTS = 4

# GRUG: Small stochastic jitter applied to co-fired node confidence.
# Biologically motivated — synaptic relay is noisy. Same neuron doesn't fire
# with identical strength every time it gets woken by a relay. Keeps the vote
# pool from collapsing to the same winner every cycle when attachments fire.
# Magnitude is small (sigma=0.05) so it nudges but never dominates.
const RELAY_CONF_JITTER_SIGMA = 0.05

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
            jitter = randn() * RELAY_CONF_JITTER_SIGMA
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
        hopfield_key        # hopfield_key
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
passes are both run and confidence is smoothed (averaged). This catches
order-reversed matches that forward-only scanning would miss — "man bites dog"
aligns with "dog bites man" when the reverse pass runs.

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

SMOOTHING FORMULA:
  Both succeed  → smoothed = (forward_conf + reverse_conf) / 2
                  Neither direction dominates. True bidirectional match averages out.
  One succeeds  → smoothed = (hit_conf + threshold - ε) / 2
                  One direction found a match; the other didn't meet threshold.
                  We use (threshold - ε) as the miss contribution — not zero
                  (which would harshly punish partial reversal) and not threshold
                  (which would inflate). This gives a moderate signal, not a spike.
  Both fail     → rethrow PatternNotFoundError from forward direction.
                  No match either way. Consistent with single-direction behavior.

WHY AVERAGING WORKS:
  High overlap in both directions → high smooth score (true bidirectional match)
  High in one direction only      → moderate score (partial/lucky alignment)
  Low in both                     → below threshold, PatternNotFoundError propagates

Called only for effective_mode == 1 (cheap scan tier, simple patterns ≤ 3 signal
elements). Medium and high-res tiers don't need this — they already scan every
index exhaustively, so order sensitivity is minimal at longer pattern lengths.

ERRORS: propagates PatternNotFoundError if both directions miss. NO SILENT FAILURES.
"""
function _bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3
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

    # GRUG: Smoothed confidence = average of forward and reverse contributions.
    # If only one succeeded, the miss_contribution softens (not zeroes) the average.
    smoothed_conf = (forward_conf + reverse_conf) / 2.0

    # GRUG: Return best alignment index (forward preferred; reverse is orientation-flipped
    # so its index doesn't map back to the original signal cleanly).
    best_idx = forward_ok ? forward_idx : 1
    return (best_idx, smoothed_conf)
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
            owning_lobe = Main.Lobe.find_lobe_for_node(node.id)
            if !isnothing(owning_lobe) && Main.LobeTable.table_exists(owning_lobe)
                lobe_drop_ids = try
                    Main.LobeTable.get_drop_neighbors(owning_lobe, node.id)
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
    user_triples  = extract_relational_triples(input_text)

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

    # GRUG: HOPFIELD FAST-PATH CHECK!
    # If this input is highly familiar (seen multiple times at high confidence),
    # skip the full scan and use the cached node IDs directly.
    input_hash    = hopfield_input_hash(input_text)
    cached_ids    = hopfield_lookup(input_hash)

    if !isnothing(cached_ids)
        println("[ENGINE] ⚡  Hopfield cache hit for input hash $(input_hash). Firing $(length(cached_ids)) precached nodes.")
        lock(NODE_LOCK) do
            for id in cached_ids
                if haskey(NODE_MAP, id)
                    node = NODE_MAP[id]
                    # GRUG: Even cached nodes must not be grave!
                    if node.is_grave
                        continue
                    end
                    # GRUG: Cached nodes still go through strength biased coinflip
                    if !strength_biased_scan_coinflip(node)
                        continue
                    end
                    # GRUG: Use stored confidence from cache (represented as HOPFIELD_STORE_THRESHOLD)
                    push!(all_valid_specimens, (id, HOPFIELD_STORE_THRESHOLD, false, user_triples, node.relational_patterns))
                end
            end
        end
        return all_valid_specimens
    end

    # GRUG: DETERMINISTIC SCAN SELECTION
    # Grug look at how complex input is to choose scanner eye.
    scan_mode = screen_input_complexity(target_signal, user_triples)

    lock(NODE_LOCK) do
        if isempty(NODE_MAP)
            error("!!! FATAL: Grug find cave empty! No specimens to scan! !!!")
        end

        # GRUG DOC 2.6: Biological Attention Bottleneck!
        # Grug cannot look at 1,000,000 rocks at once. Cave will catch fire!
        # Grug roll rand(600:1800) to limit how many nodes Grug scan. 
        active_cap  = rand(600:1800)
        
        all_keys    = collect(keys(NODE_MAP))
        shuffle!(all_keys) 
        active_keys = all_keys[1:min(length(all_keys), active_cap)]

        hopfield_candidates = String[]  # GRUG: Track high-confidence matches for caching

        for id in active_keys
            node = NODE_MAP[id]

            # GRUG: Skip grave nodes. They are negative reinforcement markers, not voters!
            if node.is_grave
                continue
            end

            # GRUG NEW: STRENGTH-BIASED COINFLIP before even scanning pattern!
            # Strong nodes are biased to activate. Weak nodes may be skipped.
            if !strength_biased_scan_coinflip(node)
                continue
            end

            # GRUG: Image nodes use SDF signal, not text signal. Skip size check for them.
            if !node.is_image_node
                # Grug check: Is user signal too small to hold node pattern? Skip safely.
                if length(target_signal) < length(node.signal)
                    continue
                end
            end
            
            token_conf = 0.0
            try
                if node.is_image_node
                    # GRUG: Image nodes cannot be scanned with text signals.
                    # They only respond to image inputs that have been SDF-converted.
                    # Skip image nodes during text scans (they'll fire in image scan path).
                    continue
                end

                # GRUG: SELECTIVE PATTERN SCAN — downgrade scan tier for simple patterns.
                # The base scan_mode is set by input complexity, but a tiny node pattern
                # doesn't justify high-res. _effective_scan_mode caps the tier based on
                # the node's own signal length. Cheap patterns get cheap scans.
                effective_mode = _effective_scan_mode(scan_mode, node.signal)

                if effective_mode == 1
                    # GRUG: BIDIRECTIONAL CHEAP SCAN — simple patterns (≤3 signal elements)
                    # run forward AND reverse. "dog bites man" vs "man bites dog" both align.
                    # Confidence is smoothed: average of forward and reverse contributions.
                    # If both miss → PatternNotFoundError propagates normally (skip node).
                    _, token_conf = _bidirectional_cheap_scan(target_signal, node.signal; threshold=0.3)
                elseif effective_mode == 2
                    _, token_conf = medium_scan(target_signal, node.signal; threshold=0.4)
                else
                    _, token_conf = high_res_scan(target_signal, node.signal; threshold=0.5)
                end
            catch e
                if e isa PatternNotFoundError
                    # Normal logic: Scanner says no match in any direction. Skip!
                    continue
                elseif e isa PatternScanError
                    # FATAL LOGIC ERROR. NO SILENT FAILURE! Scream loud!
                    rethrow(e)
                else
                    error("!!! FATAL: Unknown error during complexity-based pattern scan: $e !!!")
                end
            end
            
            # 2. Relational Matcher (Dialectical)
            rel_conf, is_antimatch = evaluate_relational_dialectics(
                user_triples, node.relational_patterns, node.required_relations, node.relation_weights
            )
            
            # 3. Hard Anti-Match / Missing Requirement Penalty
            # GRUG: -9999.0 means node demanded a gear user did not have!
            if is_antimatch || rel_conf == -9999.0
                continue 
            end

            confidence = token_conf + rel_conf

            # GRUG: ACTION+TONE CONFIDENCE PRE-WEIGHTING
            # If prediction ran successfully, apply action family weight multiplier.
            # Nodes whose action_packet aligns with predicted action get boosted.
            # Nodes that don't align get mild suppression. Low-confidence predictions
            # apply minimal modulation (multiplier stays near 1.0).
            if !isnothing(prediction) && confidence > 0.0
                # GRUG: Peek at the node's likely action from its action_packet.
                # We use the first positive action name as the node's "declared action".
                node_action_peek = try
                    positives, _, _ = parse_action_packet(node.action_packet)
                    isempty(positives) ? "" : String(positives[1][1])
                catch ex
                    # GRUG: Don't crash scan for one bad action packet, but NEVER hide it!
                    @warn "[ENGINE] ⚠ Failed to peek action_packet for node $(node.id): $ex"
                    ""
                end
                weight = ActionTonePredictor.get_action_weight_multiplier(prediction, node_action_peek)
                confidence = confidence * weight
            end
            
            if token_conf > 0 || rel_conf > 0
                push!(all_valid_specimens, (id, confidence, is_antimatch, user_triples, node.relational_patterns))

                # GRUG: Track high-confidence nodes as Hopfield cache candidates
                if confidence >= HOPFIELD_STORE_THRESHOLD
                    push!(hopfield_candidates, id)
                end
            end
        end

        # GRUG: Store high-confidence results in Hopfield cache for future fast-path use
        if !isempty(hopfield_candidates)
            hopfield_record!(input_hash, hopfield_candidates)
        end
    end

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
function scan_and_expand(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}}
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
                lobe_name = Main.Lobe.find_lobe_for_node(id)
                !isnothing(lobe_name) && push!(primary_lobe_names, lobe_name)
            end

            # GRUG: For each OTHER lobe not in primary set, cascade into it
            if !isempty(primary_lobe_names)
                all_lobe_names = try
                    Main.Lobe.get_lobe_ids()
                catch ex
                    # GRUG: Lobe registry blew up — log it, don't kill the scan!
                    @warn "[ENGINE] ⚠ Failed to get lobe IDs for cascade: $ex"
                    String[]
                end

                for lobe_name in all_lobe_names
                    lobe_name in primary_lobe_names && continue  # GRUG: Already fired, skip!

                    # GRUG: Get active node IDs from this lobe via LobeTable
                    lobe_node_ids = try
                        Main.LobeTable.table_exists(lobe_name) ?
                            Main.LobeTable.get_active_node_ids(lobe_name) : String[]
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
    relay_cap = rand(600:1800)  # GRUG: Independent cap for relay pass
    relay_count = length(expanded)
    relay_additions = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    for (id, conf, antimatch, u_trips, n_trips) in expanded
        fired_pairs = fire_attachments!(id, relay_count, relay_cap)
        for (fired_id, fired_conf, connector_pattern) in fired_pairs
            if !(fired_id in already_included)
                fired_node = lock(() -> get(NODE_MAP, fired_id, nothing), NODE_LOCK)
                isnothing(fired_node) && continue
                # GRUG: Inject the connector pattern as a relay triple so generative
                # knows WHY this node was co-fired. The triple reads:
                #   subject=target_id, relation="relay_attached", object=connector_pattern
                relay_triple = RelationalTriple(id, "relay_attached", connector_pattern)
                relay_triples = vcat(fired_node.relational_patterns, [relay_triple])
                push!(relay_additions, (fired_id, fired_conf, false, user_triples, relay_triples))
                push!(already_included, fired_id)
                relay_count += 1
            end
        end
    end

    if !isempty(relay_additions)
        append!(expanded, relay_additions)
        println("[ENGINE] 🔗  Attachment relay pass added $(length(relay_additions)) node(s) to expanded set.")
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
function apply_wrong_feedback!(voter_ids::Vector{String})
    if isempty(voter_ids)
        error("!!! FATAL: apply_wrong_feedback! got empty voter_ids list! !!!")
    end

    penalized_count = 0
    graved_count    = 0

    for id in voter_ids
        node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        if isnothing(node)
            # GRUG: Node may have already been graved. Non-fatal, skip.
            println("[ENGINE] ⚠  /wrong: Node [$id] not found, skipping penalty.")
            continue
        end

        was_grave_before = node.is_grave
        penalize_strength!(node)

        penalized_count += 1
        if node.is_grave && !was_grave_before
            graved_count += 1
        end
    end

    println("[ENGINE] ❌  /wrong applied to $(length(voter_ids)) voters. Penalized: $penalized_count, Newly graved: $graved_count.")
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