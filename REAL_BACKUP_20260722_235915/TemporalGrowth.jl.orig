# TemporalGrowth.jl
# ==============================================================================
# GROWTH AUTOMATON — Lobe-aware ephemeral jittering node growth
# ==============================================================================
# GRUG: Automaton spawns in ONE named lobe at a time. It reads fresh user
# input, extracts vote + pattern activator data, grows a few new nodes,
# then latches them to related groups. The automaton is ephemeral in
# presence (materializes, runs, evaporates) but its state persists via
# the InputLedger hash. Same pattern as EphemeralAutomaton.
#
# ARCHITECTURE:
#   1. Find named lobes with enough strength (groups pass strength floor)
#   2. Pick ONE lobe to spawn in (strongest groups there)
#   3. Read fresh MESSAGE_HISTORY entries (InputLedger.scan_fresh_entries)
#   4. For each fresh user entry, extract:
#      - Pattern via activator-verb bind (VOTES=ACTIONS, PATTERNS=QUESTIONS)
#      - Relevance filter via many levers (centroids, whitelist, thesaurus)
#      - Action packet from the lobe's own existing nodes (what it DOES)
#      - System prompt from the lobe's group DNA (what it KNOWS)
#   5. Grow a few new nodes (GROWTH_BATCH_SIZE ceiling per spawn)
#   6. Latch new nodes to related groups:
#      - find_group_latch_candidates → filter by MITOSIS_GROUP_STRENGTH_FLOOR
#      - Random pick from eligible (analog coherence as digital selection)
#   7. Evaporate. Ledger remembers what was consumed.
#
# THREE SIGNAL CHANNELS:
#   VOTES   = ACTIONS       — what node does when it fires
#   PATTERNS = QUESTIONS    — what node responds to
#   SIGILS  = INFERENCE     — how node binds at match time
#
# MANY LEVERS FOR RELEVANCE:
#   The automaton has many levers to identify what patterns and actions
#   are relevant to a lobe's topic. It does NOT use hardcoded lookup tables.
#   Instead, it reads the lobe's OWN structures:
#     Lever 1: Group centroids — centroid_pattern = lobe's existing topic DNA
#     Lever 2: Lobe subject whitelist — tokens belonging to the lobe's domain
#     Lever 3: Co-occurrence data — which nodes co-occur (RelationalGovernance)
#     Lever 4: Thesaurus similarity — dimensional proximity between tokens
#     Lever 5: Lobe node patterns/action_packets — what the lobe already does
#
# "Low fidelity without losing result" — minimal machinery, same outcome.
# Structures do the understanding. Automaton just routes.
# ==============================================================================

module TemporalGrowth

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

# GRUG: Bring the hash ledger pattern from InputLedger.
using ..InputLedger: scan_fresh_entries, mark_consumed!, _entry_hash
# GRUG: Bring PatternScanner for jitter (same as EphemeralAutomaton).
using ..PatternScanner: slight_jitter
# GRUG v7.50: Bring EphemeralMLP strain queries for growth status observability.
using ..EphemeralMLP: get_strain_energy, is_hippocampal_warrant_active

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: How many nodes max per automaton spawn. Conservative. A few, not a flood.
const GROWTH_BATCH_SIZE = 3

# GRUG: Stochastic gate ceiling. Automaton doesn't spawn every idle cycle.
# data_energy * GROWTH_PROBABILITY_CEILING = effective probability.
const GROWTH_PROBABILITY_CEILING = 0.15

# GRUG: Group strength floor — same as MitosisMode.MITOSIS_GROUP_STRENGTH_FLOOR.
# Groups with avg_strength below this are too weak to bind to. Free agents instead.
const GROUP_STRENGTH_FLOOR = 0.5

# GRUG: Minimum fresh entries needed before automaton materializes.
# Not enough data = no spawn. Growth must be earned.
const MIN_FRESH_ENTRIES = 5

# GRUG: Data energy scales with recent user message count.
const DATA_ENERGY_MSG_SCALE = 10

# GRUG: Default strength for newly grown nodes. Same as MitosisMode.
const GROWTH_NODE_STRENGTH = 1.0

# GRUG: Relevance thresholds for the many-lever system.
# Minimum thesaurus similarity between an extracted pattern and a lobe's
# centroid/whitelist for the pattern to be considered relevant to the lobe.
const RELEVANCE_THESAURUS_FLOOR = 0.15

# GRUG: How many of a lobe's strongest nodes to sample when inferring
# what actions the lobe performs. Small sample = low fidelity, good enough.
const ACTION_SAMPLE_SIZE = 8

# GRUG: Maximum action names to carry forward into a new node's action_packet.
# Keeps the packet focused, not a copy of everything the lobe does.
const MAX_ACTION_NAMES = 3

# GRUG: Maximum whitelist tokens to check against for relevance scoring.
# Bounds the work so large whitelists don't slow the automaton.
const RELEVANCE_WHITELIST_SAMPLE = 12

# GRUG: Activator markers — question/command words that bind content tokens.
const _ACTIVATOR_MARKERS = Set([
    "what", "why", "how", "when", "where", "who", "which",
    "is", "are", "do", "does", "can", "could", "would", "should",
    "will", "shall", "may", "might", "must",
    "calculate", "compute", "find", "solve", "determine",
    "explain", "describe", "define", "tell", "show",
    "compare", "analyze", "evaluate", "estimate",
    "list", "give", "name", "identify", "provide",
])

# GRUG: Stopwords to strip from content tokens.
const STOPWORDS = Set([
    "the", "a", "an", "is", "are", "was", "were", "be", "been",
    "being", "have", "has", "had", "do", "does", "did", "will",
    "would", "could", "should", "may", "might", "must", "shall",
    "can", "need", "dare", "ought", "used", "to", "of", "in",
    "for", "on", "with", "at", "by", "from", "as", "into",
    "through", "during", "before", "after", "above", "below",
    "between", "out", "off", "over", "under", "again", "further",
    "then", "once", "here", "there", "when", "where", "why",
    "how", "all", "each", "every", "both", "few", "more", "most",
    "other", "some", "such", "no", "nor", "not", "only", "own",
    "same", "so", "than", "too", "very", "just", "because",
    "but", "and", "or", "if", "while", "about", "up", "its",
    "this", "that", "these", "those", "it", "its", "my", "your",
    "his", "her", "our", "their", "i", "me", "we", "you", "he",
    "she", "they", "them", "what", "which", "who", "whom",
])

# ==============================================================================
# STATS — bounded ring of last N spawn results
# ==============================================================================

struct GrowthSpawnStats
    lobe_id::String
    lobe_name::String
    nodes_grown::Int
    nodes_latched::Int
    fresh_entries_consumed::Int
    spawn_ms::Float64
    status::String      # "grew", "no_fresh_data", "no_strong_groups", "stochastic_skip"
    notes::String
end

const GROWTH_LOG_MAX = 50
const GROWTH_LOG = Vector{GrowthSpawnStats}()
const GROWTH_LOG_LOCK = ReentrantLock()

function _log_spawn!(stats::GrowthSpawnStats)
    lock(GROWTH_LOG_LOCK) do
        push!(GROWTH_LOG, stats)
        if length(GROWTH_LOG) > GROWTH_LOG_MAX
            splice!(GROWTH_LOG, 1)
        end
    end
end

function get_growth_log()::Vector{GrowthSpawnStats}
    lock(GROWTH_LOG_LOCK) do
        return copy(GROWTH_LOG)
    end
end

# ==============================================================================
# PATTERN + VOTE EXTRACTION FROM FRESH INPUT
# ==============================================================================

"""
    _tokenize(text::String) -> Vector{String}

GRUG: Simple whitespace tokenizer with lowercasing. Same as MitosisMode.
"""
function _tokenize(text::String)::Vector{String}
    return [lowercase(strip(t)) for t in split(text) if !isempty(strip(t))]
end

"""
    _extract_activator_verb_pattern(input_text::String) -> String

GRUG: Extract a pattern from user input using the activator-verb bind.
Question markers and command verbs bind content tokens into a pattern
that carries its own activation key. Same geometry as MitosisMode.

"why is the sky blue" → activator="why" binds "sky blue" → "why sky blue"
"calculate the total" → activator="calculate" binds "total" → "calculate total"
"maybe consciousness exists" → no activator, verb="exists" binds "consciousness" → "consciousness exists"
"""
function _extract_activator_verb_pattern(input_text::String)::String
    tokens = _tokenize(input_text)
    isempty(tokens) && return ""

    # GRUG: Find the first activator marker in the input.
    activator = nothing
    content_start = 1
    for (i, t) in enumerate(tokens)
        if t in _ACTIVATOR_MARKERS
            activator = t
            content_start = i + 1
            break
        end
    end

    # GRUG: Extract content tokens after the activator, filtering stopwords.
    content_tokens = filter(t -> length(t) > 2 && !(t in STOPWORDS) && !(t in _ACTIVATOR_MARKERS),
                            tokens[content_start:end])

    # GRUG: If no activator found, look for the leading VERB instead.
    if activator === nothing
        if !isempty(content_tokens)
            activator = content_tokens[1]
            content_tokens = length(content_tokens) > 1 ? content_tokens[2:end] : String[]
        end
    end

    # GRUG: Assemble pattern: activator + up to 3 content tokens.
    if activator !== nothing
        max_content = min(length(content_tokens), 3)
        if max_content > 0
            return strip(join(vcat([activator], content_tokens[1:max_content]), " "))
        else
            return strip(activator)
        end
    end

    # GRUG: No activator, no verb — fall back to top content tokens (max 4).
    if !isempty(content_tokens)
        max_tokens = min(length(content_tokens), 4)
        return strip(join(content_tokens[1:max_tokens], " "))
    end

    return strip(input_text)
end

# ==============================================================================
# MANY LEVERS — Relevance filtering and structural inference
# ==============================================================================
#
# GRUG: The automaton does NOT hardcode what patterns or actions are relevant
# to a lobe. It READS the lobe's own structures. Many levers to use:
#
#   Lever 1: Group centroids — centroid_pattern = the lobe's topic DNA
#   Lever 2: Lobe subject whitelist — domain tokens for the lobe
#   Lever 3: Co-occurrence data — which nodes co-occur (CO_ACC)
#   Lever 4: Thesaurus similarity — dimensional proximity between tokens
#   Lever 5: Lobe node patterns + action_packets — what the lobe already does
#
# "Low fidelity without losing result" — we sample a few nodes, check a
# few centroids, and that's enough. The structures already know what they
# care about. The automaton just routes that knowledge into new nodes.
# ==============================================================================

"""
    _score_pattern_relevance(pattern::String, lobe_rec; thesaurus_fn) -> Float64

GRUG: Score how relevant a pattern is to a lobe's topic using many levers.
Returns a float in [0.0, ~2.0] where higher = more relevant.

Levers applied (each contributes additively):
  1. Whitelist match: +1.0 if any pattern token matches the whitelist
  2. Centroid similarity: +thesaurus_fn(pattern, centroid) for each group centroid
  3. Whitelist thesaurus: +max thesaurus_fn(pattern_token, wl_token) for near-matches

A score of 0.0 means the pattern is completely unrelated to the lobe.
Any positive score means some relevance signal was found.
"""
function _score_pattern_relevance(pattern::String, lobe_rec;
                                   thesaurus_fn::Function)::Float64
    isempty(strip(pattern)) && return 0.0

    score = 0.0
    pat_tokens = Set(_tokenize(pattern))

    # ── LEVER 2: Subject whitelist (exact/fuzzy match) ──────────────────
    # GRUG: Whitelist is the hard gate. If input tokens match the whitelist,
    # that's the strongest possible relevance signal.
    wl = lobe_rec.subject_whitelist
    if !isempty(wl)
        wl_sample = length(wl) > RELEVANCE_WHITELIST_SAMPLE ?
                     sort(collect(wl))[1:RELEVANCE_WHITELIST_SAMPLE] : collect(wl)
        for wl_entry in wl_sample
            for pt in pat_tokens
                # GRUG: Substring match (same as lobe_can_accept_subject)
                if occursin(wl_entry, pt) || occursin(pt, wl_entry)
                    score += 1.0
                    break  # One match per whitelist entry is enough
                end
            end
        end
    end

    # ── LEVER 4: Thesaurus proximity to whitelist tokens ────────────────
    # GRUG: Even if no exact match, thesaurus can tell us "calculate" is
    # close to "compute" which might be in the whitelist.
    if !isempty(wl) && score < 1.0  # Only if we didn't already get a hard match
        best_thes = 0.0
        for wl_entry in collect(wl)
            for pt in pat_tokens
                try
                    sim = thesaurus_fn(pt, wl_entry)
                    best_thes = max(best_thes, sim)
                catch
                    # GRUG: Thesaurus errors are non-fatal. Skip and continue.
                end
            end
            if best_thes >= 0.5
                break  # Good enough, stop checking
            end
        end
        if best_thes > RELEVANCE_THESAURUS_FLOOR
            score += best_thes * 0.5  # Discount — thesaurus is soft signal
        end
    end

    return score
end

"""
    _infer_action_packet_from_lobe(lobe_id::String, lobe_rec; node_map, node_lock) -> String

GRUG: Infer a vote (action_packet) for a new node by reading the action_packets
of the lobe's strongest existing nodes. The lobe's own nodes already carry
the actions that are relevant to its domain — we don't need a hardcoded lookup.

Strategy: sample up to ACTION_SAMPLE_SIZE strongest non-grave nodes in the lobe,
collect their action names (from action_packet parse), keep the most common
MAX_ACTION_NAMES names, and build a fresh packet with those.

If the lobe has no nodes yet, return a minimal default packet. This is the
bootstrap case — the first node in a lobe gets a generic action, and future
growth iterates from there.
"""
function _infer_action_packet_from_lobe(lobe_id::String, lobe_rec;
                                         node_map, node_lock)::String
    # GRUG: Collect the strongest nodes in this lobe.
    scored_nodes = Tuple{Float64, String}[]  # (strength, node_id)
    lock(node_lock) do
        for nid in lobe_rec.node_ids
            node = get(node_map, nid, nothing)
            isnothing(node) && continue
            node.is_grave && continue
            push!(scored_nodes, (node.strength, nid))
        end
    end

    # GRUG: No nodes yet — bootstrap with a minimal default.
    if isempty(scored_nodes)
        return "ponder[carefully]^2 | describe[simply]^1 | acknowledge^1"
    end

    # GRUG: Sort by strength descending, take top ACTION_SAMPLE_SIZE.
    sort!(scored_nodes, by = x -> x[1], rev = true)
    sample = scored_nodes[1:min(ACTION_SAMPLE_SIZE, length(scored_nodes))]

    # GRUG: Collect action names from sampled nodes' action_packets.
    action_counts = Dict{String, Float64}()  # action_name → cumulative weight
    lock(node_lock) do
        for (_, nid) in sample
            node = get(node_map, nid, nothing)
            isnothing(node) && continue
            for part in split(node.action_packet, '|')
                p = strip(part)
                isempty(p) && continue
                name = _parse_action_name(p)
                isempty(name) && continue
                weight = _parse_action_weight(p)
                old = get(action_counts, name, 0.0)
                action_counts[name] = old + weight
            end
        end
    end

    # GRUG: No parseable actions found — use the raw packet of the strongest node.
    if isempty(action_counts)
        strongest_id = sample[1][2]
        raw_packet = lock(node_lock) do
            node = get(node_map, strongest_id, nothing)
            isnothing(node) ? "" : node.action_packet
        end
        return isempty(raw_packet) ? "ponder[carefully]^2 | describe[simply]^1 | acknowledge^1" : raw_packet
    end

    # GRUG: Rank actions by cumulative weight, take top MAX_ACTION_NAMES.
    ranked = sort(collect(action_counts), by = x -> x[2], rev = true)
    top_actions = ranked[1:min(MAX_ACTION_NAMES, length(ranked))]

    # GRUG: Build the packet. Preserve the weight notation from the source.
    # Re-weight proportionally: strongest gets ^4, second ^3, third ^2.
    parts = String[]
    weight_scale = [4, 3, 2]
    for (i, (name, _)) in enumerate(top_actions)
        w = i <= length(weight_scale) ? weight_scale[i] : 1
        push!(parts, "$(name)^$(w)")
    end

    return join(parts, " | ")
end

"""
    _infer_system_prompt_from_lobe(lobe_id::String, lobe_rec, pattern::String;
                                    node_map, node_lock, group_map) -> String

GRUG: System prompt for the new node derived from the lobe's group DNA
and subject domain. We don't hardcode prompts per lobe name. Instead we
read what the lobe's groups already know (their centroid patterns) and
what the lobe's subject is about (its subject field + whitelist).

The centroid_pattern of the strongest group IS the topic. The subject
field IS the domain label. Together they tell the new node what it's
about and where it lives.
"""
function _infer_system_prompt_from_lobe(lobe_id::String, lobe_rec, pattern::String;
                                         node_map, node_lock, group_map)::String
    # ── LEVER 1: Find the strongest group centroid in this lobe ────────
    # GRUG: The group centroid IS the lobe's topic DNA. Read it directly.
    best_centroid = ""
    best_strength = 0.0

    for (gid, grp) in group_map
        # GRUG: Only consider groups whose members are in this lobe.
        has_member_in_lobe = false
        for mid in grp.members
            if mid in lobe_rec.node_ids
                has_member_in_lobe = true
                break
            end
        end
        if !has_member_in_lobe
            continue
        end

        # GRUG: Compute avg_strength for this group.
        total_str = 0.0
        count = 0
        lock(node_lock) do
            for mid in grp.members
                member = get(node_map, mid, nothing)
                isnothing(member) && continue
                member.is_grave && continue
                total_str += member.strength
                count += 1
            end
        end
        avg_str = count > 0 ? total_str / count : 0.0

        if avg_str > best_strength
            best_strength = avg_str
            best_centroid = grp.centroid_pattern
        end
    end

    # ── Build prompt from lobe's own structures ─────────────────────────
    # GRUG: The lobe's subject + the group centroid + the new pattern
    # together define what this node knows and where it lives.
    subject = lobe_rec.subject
    lobe_name = lobe_rec.name

    if !isempty(best_centroid)
        # GRUG: The lobe has living groups. The centroid IS the topic.
        # New node inherits the lobe's domain knowledge.
        return "Grug know about $(subject). $(best_centroid) is what this part of the cave knows. $(pattern) belongs here too."
    elseif !isempty(subject)
        # GRUG: No strong groups yet, but the lobe has a subject.
        # Bootstrap: tell the node what domain it lives in.
        return "Grug live in $(lobe_name) cave. Grug study $(subject). $(pattern) is a new rock for this cave."
    else
        # GRUG: No groups, no subject. Absolute bootstrap.
        return "Grug think about $(pattern). One more rock for Grug's wall of knowing."
    end
end

"""
    _parse_action_name(packet_part::String) -> String

GRUG: Parse an action name from a single action_packet part.
"calculate[precise]^4" → "calculate"
"verify^3" → "verify"
"explain" → "explain"
"""
_expand_action_macro_string(s::AbstractString)::String = replace(replace(String(s), "{{PIPE}}" => "|"), "{PIPE}" => "|")

function _parse_action_name(packet_part::String)::String
    p = strip(packet_part)
    isempty(p) && return ""
    # Strip inline negatives: action_name[negs]^weight → action_name
    m = match(r"^(.+?)\[", p)
    if !isnothing(m)
        name = strip(m.captures[1])
        return isempty(name) ? "" : _expand_action_macro_string(name)
    end
    # Strip weight suffix: action_name^weight → action_name
    m2 = match(r"^(.+?)\^", p)
    if !isnothing(m2)
        name = strip(m2.captures[1])
        return isempty(name) ? "" : _expand_action_macro_string(name)
    end
    return _expand_action_macro_string(p)
end

"""
    _parse_action_weight(packet_part::String) -> Float64

GRUG: Parse the weight from a single action_packet part.
"calculate[precise]^4" → 4.0
"verify^3" → 3.0
"explain" → 1.0 (default weight)
"""
function _parse_action_weight(packet_part::String)::Float64
    p = strip(packet_part)
    # Look for ^weight suffix
    m = match(r"\^(\d+(?:\.\d+)?)", p)
    if !isnothing(m)
        try
            return _expand_action_macro_string(p)arse(Float64, m.captures[1])
        catch
            return 1.0
        end
    end
    return 1.0  # GRUG: Default weight when not specified
end

"""
    _find_groups_in_lobe(lobe_rec, group_map; node_map, node_lock) -> Vector{Tuple{NodeGroup, Float64}}

GRUG: Find all groups that have members in this lobe, with their avg_strength.
Returns groups sorted by avg_strength descending. Used by relevance scoring
and system prompt inference.
"""
function _find_groups_in_lobe(lobe_rec, group_map; node_map, node_lock)::Vector{Tuple{Any, Float64}}
    result = Tuple{Any, Float64}[]

    for (gid, grp) in group_map
        # GRUG: Check if any group member lives in this lobe.
        has_member_in_lobe = false
        for mid in grp.members
            if mid in lobe_rec.node_ids
                has_member_in_lobe = true
                break
            end
        end
        if !has_member_in_lobe
            continue
        end

        # GRUG: Compute avg_strength.
        total_str = 0.0
        count = 0
        lock(node_lock) do
            for mid in grp.members
                member = get(node_map, mid, nothing)
                isnothing(member) && continue
                member.is_grave && continue
                total_str += member.strength
                count += 1
            end
        end
        avg_str = count > 0 ? total_str / count : 0.0

        push!(result, (grp, avg_str))
    end

    sort!(result, by = x -> x[2], rev = true)
    return result
end

# ==============================================================================
# DATA ENERGY — same computation as MitosisMode._compute_data_energy
# ==============================================================================

"""
    _compute_data_energy(message_snapshots) -> Float64

GRUG: Compute data_energy from recent messages. Same formula as MitosisMode:
  msg_energy = count_recent / SCALE (capped at 1.0)
  int_energy = mean_intensity_recent (capped at 1.0)
  data_energy = max(msg_energy, int_energy)

No data = no energy = no growth. Growth is earned.
"""
function _compute_data_energy(message_snapshots::Vector{Tuple{String, String, Float64}})::Float64
    isempty(message_snapshots) && return 0.0

    # GRUG: Recent user messages (last 50).
    recent = message_snapshots[max(1, length(message_snapshots) - 49):end]
    user_recent = filter(m -> m[1] == "user", recent)

    msg_energy = min(length(user_recent) / DATA_ENERGY_MSG_SCALE, 1.0)

    int_energy = if !isempty(user_recent)
        mean_intensity = sum(m[3] for m in user_recent) / length(user_recent)
        min(mean_intensity, 1.0)
    else
        0.0
    end

    return max(msg_energy, int_energy)
end

# ==============================================================================
# LOBE SELECTION — find the best named lobe to spawn in
# ==============================================================================

"""
    _select_spawn_lobe(lobe_registry, group_map; node_map, node_lock) -> Union{Tuple{String, String, LobeRecord}, Nothing}

GRUG: Pick ONE named lobe to spawn in. Selection criteria:
  1. Must have a human-readable name (set via /nameLobe)
  2. Must have groups with avg_strength >= GROUP_STRENGTH_FLOOR
  3. Pick the lobe with the strongest eligible group (deterministic best)

Returns (lobe_id, lobe_name, lobe_rec) or nothing if no lobe qualifies.
"""
function _select_spawn_lobe(lobe_registry, group_map; node_map, node_lock)::Union{Tuple{String, String, Any}, Nothing}
    best_lobe_id = nothing
    best_lobe_name = nothing
    best_lobe_rec = nothing
    best_strength = GROUP_STRENGTH_FLOOR  # GRUG: Must clear the floor to qualify

    for (lobe_id, lobe_rec) in lobe_registry
        # GRUG: Only spawn in NAMED lobes. Name = identity for the automaton.
        lobe_name = lobe_rec.name
        if isempty(lobe_name) || lobe_name == lobe_id
            continue
        end

        # GRUG: Find the strongest group in this lobe.
        strongest_in_lobe = 0.0
        for (gid, grp) in group_map
            has_member_in_lobe = false
            for mid in grp.members
                if mid in lobe_rec.node_ids
                    has_member_in_lobe = true
                    break
                end
            end
            if has_member_in_lobe
                total_str = 0.0
                count = 0
                lock(node_lock) do
                    for mid in grp.members
                        member = get(node_map, mid, nothing)
                        isnothing(member) && continue
                        member.is_grave && continue
                        total_str += member.strength
                        count += 1
                    end
                end
                avg_str = count > 0 ? total_str / count : 0.0
                if avg_str > strongest_in_lobe
                    strongest_in_lobe = avg_str
                end
            end
        end

        # GRUG: Lobe qualifies if its strongest group clears the floor.
        if strongest_in_lobe > best_strength
            best_strength = strongest_in_lobe
            best_lobe_id = lobe_id
            best_lobe_name = lobe_name
            best_lobe_rec = lobe_rec
        end
    end

    if best_lobe_id === nothing
        return nothing
    end
    return (best_lobe_id, best_lobe_name, best_lobe_rec)
end

# ==============================================================================
# MAIN GROWTH FUNCTION — the automaton spawn
# ==============================================================================

"""
    run_growth_automaton!(; kwargs...) -> GrowthSpawnStats

GRUG: The growth automaton materializes, runs, and evaporates.
State persists via InputLedger hash (consumed entries).

Flow:
  1. Snapshot MESSAGE_HISTORY, compute data_energy
  2. Stochastic gate: data_energy * GROWTH_PROBABILITY_CEILING
  3. If gate doesn't roll → stochastic_skip. Evaporate.
  4. Select ONE named lobe to spawn in (strongest groups pass floor)
  5. If no lobe qualifies → no_strong_groups. Evaporate.
  6. Scan fresh entries from MESSAGE_HISTORY
  7. If too few fresh entries → no_fresh_data. Evaporate.
  8. For each fresh user entry (up to GROWTH_BATCH_SIZE):
     - Extract pattern via activator-verb bind (QUESTION channel)
     - Score relevance to lobe using many levers (centroids, whitelist, thesaurus)
     - If pattern isn't relevant to lobe → skip (don't grow off-topic nodes)
     - Infer action_packet from lobe's own nodes (ACTION channel)
     - Infer system_prompt from lobe's group DNA + subject
     - Create node + register in lobe
     - Latch to related group (find_group_latch_candidates → strength floor)
  9. Log and evaporate. Ledger remembers.

Required kwargs:
  - node_map, node_lock: live NODE_MAP and lock
  - message_history, history_lock: MESSAGE_HISTORY and lock
  - lobe_registry: LOBE_REGISTRY dict
  - group_map, group_lock: GROUP_MAP and lock
  - node_to_lobe_idx: NODE_TO_LOBE reverse index (or empty dict)
  - create_node_fn: (pattern, action_packet, data, drop_table; initial_strength) -> String
  - add_to_group_fn: (group, node_id) -> Bool
  - group_latch_fn: (pattern; node_map, node_lock) -> Vector{GroupLatchCandidate}
  - link_to_group_member_fn: (new_node, group) -> Union{String, Nothing}
  - immune_gate_fn: (pattern, data) -> Bool (or nothing)

New kwargs (many levers):
  - thesaurus_fn: (word1, word2) -> Float64 similarity. Defaults to a
    cheap Jaccard fallback if not provided. When provided, it should be
    Thesaurus.word_similarity or synonym_lookup for richer signal.
"""
function run_growth_automaton!(;
    node_map,
    node_lock,
    message_history,
    history_lock,
    lobe_registry,
    group_map,
    group_lock,
    node_to_lobe_idx,
    create_node_fn,
    add_to_group_fn,
    group_latch_fn,
    link_to_group_member_fn,
    immune_gate_fn = nothing,
    thesaurus_fn::Function = _cheap_jaccard_fallback,
    # GRUG v7.50: Hippocampal strain — endocrine bridge from EphemeralMLP
    # When the system hurts from novel input it can't handle, strain boosts
    # the growth probability even without fresh data. Same principle as MitosisMode.
    strain_energy_fn::Union{Function, Nothing} = nothing,  # () -> Float64
)::GrowthSpawnStats

    t0 = time()

    # ── 1. SNAPSHOT + DATA ENERGY ──────────────────────────────────────
    message_snapshots = Tuple{String, String, Float64}[]
    lock(history_lock) do
        for msg in message_history
            push!(message_snapshots, (msg.role, msg.text, msg.intensity))
        end
    end
    data_energy = _compute_data_energy(message_snapshots)

    # ── 2. STOCHASTIC GATE ────────────────────────────────────────────
    # GRUG: Jitter on probability, not on decision. Same as v2 design.
    # GRUG v7.50: Strain energy from EphemeralMLP feeds the gate.
    # Internal deficit can boost gate probability even without fresh data.
    _strain_e = strain_energy_fn !== nothing ? strain_energy_fn() : 0.0
    combined_energy = max(data_energy, _strain_e)
    effective_prob = combined_energy * GROWTH_PROBABILITY_CEILING
    jittered_prob = slight_jitter(effective_prob)
    if jittered_prob <= 0.0 || rand() > jittered_prob
        stats = GrowthSpawnStats(
            "", "", 0, 0, 0,
            (time() - t0) * 1000,
            "stochastic_skip",
            "p=$(round(jittered_prob, digits=3)), data_energy=$(round(data_energy, digits=2)), strain=$(round(_strain_e, digits=2))"
        )
        _log_spawn!(stats)
        return stats
    end

    # ── 3. SELECT SPAWN LOBE ──────────────────────────────────────────
    spawn_target = _select_spawn_lobe(lobe_registry, group_map;
                                       node_map=node_map, node_lock=node_lock)
    if spawn_target === nothing
        stats = GrowthSpawnStats(
            "", "", 0, 0, 0,
            (time() - t0) * 1000,
            "no_strong_groups",
            "No named lobe has groups passing strength floor ($GROUP_STRENGTH_FLOOR)"
        )
        _log_spawn!(stats)
        return stats
    end
    (lobe_id, lobe_name, lobe_rec) = spawn_target

    # ── 4. SCAN FRESH ENTRIES ──────────────────────────────────────────
    fresh = scan_fresh_entries(;
        message_history_ref=message_history,
        history_lock_ref=history_lock,
        batch_size=GROWTH_BATCH_SIZE * 3,  # GRUG: Over-scan, some won't be user entries
        min_threshold=MIN_FRESH_ENTRIES
    )
    if isempty(fresh)
        stats = GrowthSpawnStats(
            lobe_id, lobe_name, 0, 0, 0,
            (time() - t0) * 1000,
            "no_fresh_data",
            "Not enough fresh entries ($MIN_FRESH_ENTRIES required)"
        )
        _log_spawn!(stats)
        return stats
    end

    # GRUG: Filter to USER entries only. System/assistant entries aren't growth fuel.
    user_entries = filter(e -> e[1] == "user", fresh)

    # ── 5. GROW NODES ──────────────────────────────────────────────────
    # GRUG: For each fresh user entry, extract pattern (QUESTION channel),
    # score relevance via many levers, infer action (ACTION channel) from
    # the lobe's own nodes, and grow a node if the pattern is relevant.
    nodes_grown = 0
    nodes_latched = 0
    entries_consumed = 0
    growth_notes = String[]

    for (role, text, h) in user_entries
        if nodes_grown >= GROWTH_BATCH_SIZE
            break
        end

        # GRUG: Extract pattern via activator-verb bind (QUESTION channel).
        # PATTERNS = QUESTIONS — what the node responds to.
        pattern = _extract_activator_verb_pattern(text)
        if isempty(strip(pattern)) || length(strip(pattern)) <= 2
            mark_consumed!(h)
            entries_consumed += 1
            continue
        end

        # ── RELEVANCE FILTERING via many levers ────────────────────────
        # GRUG: The pattern must be RELEVANT to this lobe's topic.
        # Fresh user input might contain tokens unrelated to the lobe.
        # The levers filter those out or confirm relevance.
        relevance = _score_pattern_relevance(pattern, lobe_rec;
                                              thesaurus_fn=thesaurus_fn)

        # GRUG: If the lobe has a non-empty whitelist and relevance is 0,
        # the pattern is OFF-TOPIC for this lobe. Skip it.
        # If the whitelist is empty, we accept all patterns (backward compat).
        if !isempty(lobe_rec.subject_whitelist) && relevance <= 0.0
            push!(growth_notes, "off-topic:'$pattern'(rel=$(round(relevance, digits=2)))")
            mark_consumed!(h)
            entries_consumed += 1
            continue
        end

        # ── LEVER 5: Infer action from lobe's own nodes (ACTION channel) ──
        # GRUG: VOTES = ACTIONS — what the node does when it fires.
        # We read the action_packets of the lobe's strongest existing nodes.
        # The lobe's own nodes already know what actions are relevant.
        action_packet = _infer_action_packet_from_lobe(lobe_id, lobe_rec;
                                                        node_map=node_map, node_lock=node_lock)

        # ── LEVER 1+2: Infer system prompt from lobe's group DNA ──────
        # GRUG: The group centroid IS the topic. The subject IS the domain.
        # Together they tell the new node what it's about and where it lives.
        system_prompt = _infer_system_prompt_from_lobe(lobe_id, lobe_rec, pattern;
                                                        node_map=node_map, node_lock=node_lock,
                                                        group_map=group_map)

        json_data = Dict{String, Any}(
            "system_prompt"      => system_prompt,
            "lobe_hint"          => lobe_id,
            "voice_register"     => "plain",
            "frame_hints"        => ["basic"],
            "noun_anchors"       => [pattern],
            "growth_source"      => "automaton",
            "growth_lobe_name"   => lobe_name,
            "growth_born"        => string(round(time(), digits=3)),
            "growth_relevance"   => round(relevance, digits=3),
        )

        # GRUG: Immune gate check — same as /grow and MitosisMode.
        if immune_gate_fn !== nothing
            try
                passed = immune_gate_fn(pattern, json_data)
                if !passed
                    push!(growth_notes, "immune_blocked:'$pattern'")
                    mark_consumed!(h)
                    entries_consumed += 1
                    continue
                end
            catch e
                push!(growth_notes, "immune_error:'$pattern':$e")
                mark_consumed!(h)
                entries_consumed += 1
                continue
            end
        end

        # GRUG: CREATE THE NODE!
        latched_group_id = ""
        latched_to_id = ""
        try
            new_id = create_node_fn(
                pattern,
                action_packet,
                json_data,
                String[];  # no drop_table — group latching handles neighbors
                initial_strength = GROWTH_NODE_STRENGTH
            )

            # GRUG: Register node into its lobe.
            if haskey(lobe_registry, lobe_id)
                rec = lobe_registry[lobe_id]
                if hasproperty(rec, :node_ids) && !(new_id in rec.node_ids)
                    push!(rec.node_ids, new_id)
                end
                # GRUG: Update reverse index too.
                if !isempty(node_to_lobe_idx) && !haskey(node_to_lobe_idx, new_id)
                    node_to_lobe_idx[new_id] = lobe_id
                end
            end

            nodes_grown += 1

            # ── GROUP LATCHING ──────────────────────────────────────────
            # GRUG: Find related groups and latch. Same pattern as MitosisMode:
            # find candidates → filter by strength floor → random pick from eligible.
            if group_latch_fn !== nothing && add_to_group_fn !== nothing
                try
                    # GRUG v7.56a: Check if the newly grown node is a time node.
                    # Time nodes only latch to time-node groups; non-time nodes only
                    # latch to non-time-node groups. Pure label isolation gate.
                    grown_node = get(node_map, new_id, nothing)
                    grown_is_time = !isnothing(grown_node) && get(grown_node.json_data, "time_node", false) === true
                    candidates = group_latch_fn(pattern; node_map=node_map, node_lock=node_lock, requesting_node_is_time=grown_is_time)
                    if !isempty(candidates)
                        # GRUG: Filter by group strength floor.
                        eligible = filter(c -> c.avg_strength >= GROUP_STRENGTH_FLOOR, candidates)
                        if !isempty(eligible)
                            # GRUG: Random pick from eligible list. Analog coherence as digital selection.
                            chosen = eligible[rand(1:length(eligible))]
                            target_group = chosen.group

                            joined = add_to_group_fn(target_group, new_id)
                            if joined
                                latched_group_id = target_group.id
                                nodes_latched += 1

                                # GRUG: Link to a member within the group.
                                if link_to_group_member_fn !== nothing
                                    new_node_obj = lock(node_lock) do
                                        get(node_map, new_id, nothing)
                                    end
                                    if new_node_obj !== nothing
                                        linked_id = link_to_group_member_fn(new_node_obj, target_group)
                                        if linked_id !== nothing
                                            latched_to_id = linked_id
                                        end
                                    end
                                end
                            end
                        end
                    end
                    # GRUG: No eligible group → node remains free agent.
                    # Phagy will organize it in a future idle cycle.
                catch e
                    # GRUG: Group latch failure not fatal — node is still planted.
                    latched_group_id = ""
                    latched_to_id = ""
                end
            end

            latch_info = isempty(latched_to_id) ?
                         (isempty(latched_group_id) ? "no_latch" : "group=$latched_group_id") :
                         "group=$latched_group_id,link=$latched_to_id"
            rel_info = relevance > 0.0 ? " rel=$(round(relevance, digits=2))" : ""
            push!(growth_notes, "'$pattern'→$new_id [$latch_info]$rel_info")

        catch e
            push!(growth_notes, "error:'$pattern':$e")
        end

        # GRUG: Mark entry consumed whether growth succeeded or not.
        mark_consumed!(h)
        entries_consumed += 1
    end

    # GRUG: Mark remaining non-user entries as consumed too.
    for (role, text, h) in fresh
        if role != "user"
            mark_consumed!(h)
            entries_consumed += 1
        end
    end

    stats = GrowthSpawnStats(
        lobe_id,
        lobe_name,
        nodes_grown,
        nodes_latched,
        entries_consumed,
        (time() - t0) * 1000,
        nodes_grown > 0 ? "grew" : "no_valid_patterns",
        join(growth_notes, "; ")
    )
    _log_spawn!(stats)
    return stats
end

# ==============================================================================
# CHEAP JACCARD FALLBACK — used when no thesaurus_fn is provided
# ==============================================================================

"""
    _cheap_jaccard_fallback(word1::AbstractString, word2::AbstractString) -> Float64

GRUG: When no thesaurus function is injected, use cheap character-level
Jaccard similarity. Not as good as the real thesaurus (which knows about
synonyms like "happy"≈"joyful"), but good enough for basic relevance
checking. The automaton works without thesaurus, it just has fewer levers.
"""
function _cheap_jaccard_fallback(word1::AbstractString, word2::AbstractString)::Float64
    isempty(strip(word1)) || isempty(strip(word2)) && return 0.0
    w1 = lowercase(strip(String(word1)))
    w2 = lowercase(strip(String(word2)))
    w1 == w2 && return 1.0
    s1 = Set(collect(w1))
    s2 = Set(collect(w2))
    union_sz = length(union(s1, s2))
    return union_sz > 0 ? Float64(length(intersect(s1, s2))) / Float64(union_sz) : 0.0
end

# ==============================================================================
# STATUS SUMMARY
# ==============================================================================

function get_growth_status_summary()::String
    # GRUG v7.50: Include strain energy in growth status for observability.
    strain_e = try
        round(EphemeralMLP.get_strain_energy(); digits=3)
    catch
        "N/A"
    end
    strain_w = try
        EphemeralMLP.is_hippocampal_warrant_active() ? "ACTIVE" : "inactive"
    catch
        "N/A"
    end
    lines = String[
        "=== GROWTH AUTOMATON ===",
        "  batch_size=$GROWTH_BATCH_SIZE, prob_ceiling=$GROWTH_PROBABILITY_CEILING",
        "  group_strength_floor=$GROUP_STRENGTH_FLOOR, min_fresh=$MIN_FRESH_ENTRIES",
        "  relevance_thesaurus_floor=$RELEVANCE_THESAURUS_FLOOR, action_sample=$ACTION_SAMPLE_SIZE",
        "  strain_energy=$strain_e, hippocampal_warrant=$strain_w",
    ]

    log = get_growth_log()
    if isempty(log)
        push!(lines, "  (no spawns yet)")
    else
        recent = log[max(1, length(log) - 9):end]
        for s in recent
            push!(lines, "  [$(round(s.spawn_ms, digits=1))ms] $(s.lobe_id)($(s.lobe_name)): " *
                         "$(s.status) grew=$(s.nodes_grown) latched=$(s.nodes_latched) " *
                         "consumed=$(s.fresh_entries_consumed)")
        end
    end
    return join(lines, "\n")
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export run_growth_automaton!, GrowthSpawnStats, get_growth_log, get_growth_status_summary
export GROWTH_BATCH_SIZE, GROWTH_PROBABILITY_CEILING, GROUP_STRENGTH_FLOOR
export _extract_activator_verb_pattern, _infer_action_packet_from_lobe
export _score_pattern_relevance, _infer_system_prompt_from_lobe

end # module TemporalGrowth
