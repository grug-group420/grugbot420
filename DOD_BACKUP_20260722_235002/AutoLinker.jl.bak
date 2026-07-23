# AutoLinker.jl
# ==============================================================================
# EVIDENCE-BASED AUTO LINKING — Cross-Lobe Bridge Growth via Lazy Coinflip
# ==============================================================================
# GRUG: Nodes that SHOULD be linked but aren't. The cave knows when two
# nodes keep showing up together — same scan cycle, same user input, same
# thesaurus neighborhood. But they live in DIFFERENT lobes and have NO
# bridge between them. That's a GAP in the cave's connectivity.
#
# The AutoLinker watches for evidence that two existing nodes should be
# bridged. It accumulates that evidence lazily — one observation at a time.
# When enough evidence piles up, a coinflip decides whether to bridge NOW.
# The coinflip is BIASED by evidence intensity: more evidence = higher prob.
#
# CRITICAL INSIGHT (from the human): The most important links are CROSS-LOBE.
# Same-lobe nodes already share scan context — they can find each other.
# Cross-lobe nodes CAN'T find each other without a bridge. The bridge IS
# the only path. So cross-lobe evidence gets a BONUS multiplier and a
# LOWER floor. The cave WANTS to connect its isolated chambers.
#
# PRINCIPLE: LAZY CONSERVATIVE. Same as AutoGrowth. Accumulate first,
# link later. Never link on the first co-firing. Link when the cave has
# SEEN the pair enough times to be sure it's a real relationship, not noise.
#
# ARCHITECTURE:
#   1. LINK EVIDENCE ACCUMULATOR — Dict{String, LinkEvidenceRecord}
#      - Key: "nodeA_id::nodeB_id" (sorted pair, canonical form)
#      - Value: cumulative intensity, frequency, source tags, cross_lobe flag,
#        lobe_a, lobe_b, last_seen
#   2. COINFLIP GATE — evidence-biased stochastic lever
#      - p_link = min(intensity / LINK_EVIDENCE_SCALE, LINK_COINFLIP_CAP)
#      - Cross-lobe pairs: p_link gets CROSS_LOBE_BONUS multiplier (1.5x)
#      - Same-lobe pairs: p_link gets SAME_LOBE_PENALTY (0.5x)
#      - Only coinflip when evidence passes floor + frequency floor
#   3. EVIDENCE SOURCES:
#      a. CO-FIRING — nodes that fire in the same scan cycle
#      b. INPUT CO-OCCURRENCE — nodes touched by the same user input
#      c. SYNONYM BRIDGE — nodes whose patterns are thesaurus synonyms
#      d. OPPOSING-LOBE CO-ACTIVATION — cross-lobe nodes co-activated
#      e. STRAIN PAIR — two nodes both registering strain from novel input
#      f. ATTACHMENT NEIGHBOR — indirect: A→B→C suggests A↔C
#      g. CO-OCCURRENCE MAP — word-level co-occurrence implies node-level link
#
# CANCER PREVENTION:
#   - Max 1 link per conversation turn (MAX_LINK_PER_TURN = 1)
#   - Evidence floor (LINK_EVIDENCE_FLOOR = 3.0)
#   - Frequency floor (LINK_FREQUENCY_FLOOR = 4 observations)
#   - Coinflip cap (LINK_COINFLIP_CAP = 0.20 — max 20% chance even at high evidence)
#   - Bridge cap check — never try if either node has MAX_BRIDGES already
#   - Already-bridged check — don't re-bridge existing pairs
#   - Immune gate on every new bridge
#   - NOCHAT groups — singleton groups don't get auto-linked (same as AutoGrowth)
#   - Same-lobe evidence floor is HIGHER (SAME_LOBE_EVIDENCE_FLOOR = 5.0)
#   - Population cap on link evidence accumulator (LINK_EVIDENCE_CAP = 5000)
#   - Evidence decay (half-life 7200s — slower than node growth, links are more stable)
# ==============================================================================

module AutoLinker

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

# ==============================================================================
# CONSTANTS — CONSERVATIVE BY DEFAULT
# ==============================================================================

# GRUG: How much evidence intensity before we even CONSIDER linking?
# Cross-lobe pairs use LINK_EVIDENCE_FLOOR. Same-lobe pairs use
# SAME_LOBE_EVIDENCE_FLOOR (higher — same-lobe links are less urgent).
const LINK_EVIDENCE_FLOOR       = 3.0
const SAME_LOBE_EVIDENCE_FLOOR  = 5.0

# GRUG: Evidence scale divisor for coinflip probability.
# p_link = min(intensity / LINK_EVIDENCE_SCALE, LINK_COINFLIP_CAP)
# Higher scale = need more evidence for the same probability.
const LINK_EVIDENCE_SCALE       = 30.0

# GRUG: Maximum coinflip probability. Even with infinite evidence,
# the chance of linking never exceeds this cap. 20% = very conservative.
const LINK_COINFLIP_CAP         = 0.20

# GRUG: Cross-lobe pairs get this multiplier on their coinflip p.
# Cross-lobe bridges are the MOST valuable — they create cascade paths
# between isolated chambers. The cave WANTS to connect its lobes.
const CROSS_LOBE_BONUS          = 1.5

# GRUG: Same-lobe pairs get this penalty on their coinflip p.
# Same-lobe nodes already share scan context. Linking them is nice
# but not critical. Lower priority.
const SAME_LOBE_PENALTY         = 0.5

# GRUG: How many times must we see a pair before we'll even coinflip?
# 4 observations minimum. A pair seen once or twice is noise.
# A pair seen 4+ times is a pattern.
const LINK_FREQUENCY_FLOOR      = 4

# GRUG: Maximum one link per conversation turn. No flooding.
const MAX_LINK_PER_TURN         = 1

# GRUG: Maximum number of link evidence records. Bounded.
const LINK_EVIDENCE_CAP         = 5000

# GRUG: Evidence decay half-life in seconds. Links are more stable
# than node growth — a pair that co-fired a lot but stopped still
# has residual evidence. 7200s = 2 hours half-life.
const LINK_DECAY_HALFLIFE       = 7200.0

# GRUG: Interval between decay sweeps. Don't decay every call —
# too expensive. Every 300s = 5 minutes.
const LINK_DECAY_INTERVAL       = 300.0

# GRUG: Maximum number of link events in the log. Bounded ring.
const LINK_LOG_MAX              = 100

# GRUG: Intensity increment per co-firing observation. Base unit.
const CO_FIRE_INCREMENT         = 1.0

# GRUG: Intensity increment per input co-occurrence observation.
# User-typed co-occurrence is STRONGER than scan co-firing —
# it's intentional. 2.0 = double weight.
const INPUT_CO_OCCUR_INCREMENT  = 2.0

# GRUG: Intensity increment for synonym bridge evidence.
# If two nodes' patterns are thesaurus synonyms, that's a strong
# relational signal. 1.5 weight.
const SYNONYM_BRIDGE_INCREMENT  = 1.5

# GRUG: Intensity increment for opposing-lobe co-activation.
# The user's key insight: cross-lobe connections are the most important.
# 3.0 weight — the highest increment. The cave REALLY wants these.
const CROSS_LOBE_CO_ACT_INCREMENT = 3.0

# GRUG: Intensity increment for strain pair evidence.
# Two nodes both "hurting" from novel input = they're related by stress.
# 0.8 weight — moderate. Stress is a signal but not as direct as co-fire.
const STRAIN_PAIR_INCREMENT     = 0.8

# GRUG: Intensity increment for attachment neighbor evidence.
# If A→B and B→C, A↔C gets indirect evidence. 0.5 weight — weak.
# Indirect evidence is suggestive, not definitive.
const ATTACH_NEIGHBOR_INCREMENT = 0.5

# GRUG: Intensity increment for word co-occurrence map evidence.
# If words in two node patterns co-occur frequently in user messages,
# the nodes should probably be linked. 0.7 weight.
const WORD_CO_OCCUR_INCREMENT   = 0.7

# GRUG: Bridge cap from engine.jl. We check this before attempting link.
# Must match engine.jl MAX_BRIDGES = 4.
const ENGINE_MAX_BRIDGES        = 4

# ── GRUG v10: NEW MLP-signal evidence thresholds ──
# GRUG: When mlp_disambiguation exceeds this, cross-lobe pairs get bonus evidence.
# High disambiguation = the MLP thinks there are multiple possible interpretations
# = nodes that disambiguate each other should be linked.
const DISAMBIGUATION_BRIDGE_THRESHOLD = 0.60

# GRUG: When mlp_relevance_score is BELOW this, the MLP thinks the current
# relevance mapping is weak = cross-lobe pairs that might restore relevance
# get bonus evidence. Low relevance = gap = link opportunity.
const RELEVANCE_CROSS_LOBE_THRESHOLD = 0.45

# GRUG: Intensity increment for disambiguation-bridge evidence.
# When MLP disambiguation is high, pairs of co-fired nodes get this per pair.
const DISAMBIGUATION_BRIDGE_INCREMENT = 0.4

# GRUG: Intensity increment for relevance-cross-lobe evidence.
# When MLP relevance is low, cross-lobe co-fired pairs get this bonus.
const RELEVANCE_CROSS_LOBE_INCREMENT = 0.5

# GRUG: Intensity increment for chatter residual co-occurrence evidence.
# ChatterResiduals detects word pairs that co-occur in vote-stealing context.
# Each pair gets its intensity * this increment as link evidence.
const NOVELTY_CO_FIRE_BOOST = 0.4   # GRUG v10: boost co-fire evidence during high novelty
const CHATTER_RESIDUAL_INCREMENT = 0.6

# ==============================================================================
# DATA STRUCTURES
# ==============================================================================

"""
    LinkEvidenceRecord

GRUG: One record per candidate node pair. Tracks accumulated evidence
that these two nodes SHOULD be bridged. The pair key is the canonical
sorted form "idA::idB" (always smaller ID first).
"""
mutable struct LinkEvidenceRecord
    node_a::String              # GRUG: First node ID (sorted, smaller)
    node_b::String              # GRUG: Second node ID (sorted, larger)
    accumulated_intensity::Float64  # GRUG: Cumulative evidence intensity
    frequency::Int             # GRUG: How many times we've seen this pair
    sources::Vector{String}    # GRUG: Which evidence sources contributed
    is_cross_lobe::Bool        # GRUG: True if nodes are in different lobes
    lobe_a::String             # GRUG: Lobe of node_a
    lobe_b::String             # GRUG: Lobe of node_b
    last_seen::Float64         # GRUG: Unix timestamp of last observation
end

function LinkEvidenceRecord(node_a::String, node_b::String;
                            is_cross_lobe::Bool = false,
                            lobe_a::String = "",
                            lobe_b::String = "")
    LinkEvidenceRecord(node_a, node_b, 0.0, 0, String[],
                       is_cross_lobe, lobe_a, lobe_b, time())
end

"""
    AutoLinkStats

GRUG: Returned from maybe_auto_link! for diagnostics and logging.
"""
struct AutoLinkStats
    won_coinflip::Bool         # GRUG: Did the coinflip land?
    node_a::String             # GRUG: First node ID
    node_b::String             # GRUG: Second node ID
    is_cross_lobe::Bool        # GRUG: Was this a cross-lobe link?
    evidence_intensity::Float64  # GRUG: Accumulated evidence at time of coinflip
    coinflip_p::Float64        # GRUG: The probability that was rolled
    source::String             # GRUG: Primary evidence source that won
    lobe_a::String             # GRUG: Lobe of node_a
    lobe_b::String             # GRUG: Lobe of node_b
    reason::String             # GRUG: Human-readable summary
end

# ==============================================================================
# STATE — link evidence accumulator + log + locks
# ==============================================================================

const _LINK_EVIDENCE = Dict{String, LinkEvidenceRecord}()  # "idA::idB" -> record
const _LINK_EVIDENCE_LOCK = ReentrantLock()
const _LAST_LINK_DECAY = Ref{Float64}(time())
const _LINK_LOG = AutoLinkStats[]
const _LINK_LOG_LOCK = ReentrantLock()

# GRUG: Total auto-links made since startup. For diagnostics.
const _TOTAL_AUTO_LINKS = Ref{Int}(0)

# ==============================================================================
# HELPER — canonical pair key
# ==============================================================================

"""
    _pair_key(id_a, id_b) -> String

GRUG: Canonical sorted pair key. Always "smaller::larger".
Same pair regardless of argument order.
"""
function _pair_key(id_a::String, id_b::String)::String
    a, b = id_a < id_b ? (id_a, id_b) : (id_b, id_a)
    return "$(a)::$(b)"
end

# ==============================================================================
# EVIDENCE ACCUMULATION — add observations for candidate pairs
# ==============================================================================

"""
    accumulate_link_evidence!(; kwargs...)

GRUG: Called from process_mission and idle cycle. Scans for evidence
that pairs of existing nodes should be bridged. Does NOT link anything.
Just accumulates evidence. Linking happens in maybe_auto_link!.

Evidence sources (each is a kwarg):
  - co_fired_ids: Vector{String} — node IDs that fired in the same scan
  - input_touched_ids: Vector{String} — node IDs touched by user input
  - node_ids_patterns: Vector{Tuple{String,String}} — (id, pattern) pairs
  - bridge_map_snapshot: Dict{String, Vector{Tuple{String,String}}} — node_id -> [(partner_id, connector)]
  - thesaurus_gate_filter: Function — word -> Vector{String}
  - thesaurus_word_similarity: Function — (word1, word2) -> Float64
  - lobe_of_fn: Function — node_id -> Union{String, Nothing}
  - strain_nodes: Vector{String} — node IDs currently under strain
  - co_occur_map: Dict{Tuple{String,String}, Int} — word co-occurrence from AutoGrowth
  - co_activation_pairs: Vector{Tuple{String,String,Float64}} — explicit (id_a, id_b, intensity) pairs from CO_ACC
  - mlp_disambiguation: Float64 — EphemeralMLP head 4 disambiguation score (0-1)
  - mlp_relevance_score: Float64 — EphemeralMLP head 3 relevance score (0-1)
  - chatter_co_occur_pairs: Vector{Tuple{String,String,Float64}} — ChatterResiduals co-occurrence (word_a, word_b, intensity)

EVIDENCE SOURCES (full list):
  a. CO-FIRING — nodes that fire in the same scan cycle
  b. INPUT CO-OCCURRENCE — nodes touched by the same user input
  c. SYNONYM BRIDGE — nodes whose patterns are thesaurus synonyms
  d. OPPOSING-LOBE CO-ACTIVATION — cross-lobe nodes co-activated
  e. STRAIN PAIR — two nodes both registering strain from novel input
  f. ATTACHMENT NEIGHBOR — indirect: A→B→C suggests A↔C
  g. CO-OCCURRENCE MAP — word-level co-occurrence implies node-level link
  h. EXPLICIT CO-ACTIVATION PAIRS — direct pair evidence from RelationalGovernance
  i. DISAMBIGUATION BRIDGE — MLP head 4: high disambiguation → co-fired pairs are disambiguators
  j. RELEVANCE CROSS-LOBE — MLP head 3: low relevance → cross-lobe pairs fill the gap
  k. CHATTER RESIDUAL CO-OCCURRENCE — ChatterResiduals underground word pairs
"""
function accumulate_link_evidence!(;
    co_fired_ids::Vector{String} = String[],
    input_touched_ids::Vector{String} = String[],
    node_ids_patterns::Vector{Tuple{String,String}} = Tuple{String,String}[],
    bridge_map_snapshot::Dict = Dict{String,Vector{Tuple{String,String}}}(),
    thesaurus_gate_filter::Function = (w) -> String[],
    thesaurus_word_similarity::Function = (a, b) -> 0.0,
    lobe_of_fn::Function = (id) -> nothing,
    strain_nodes::Vector{String} = String[],
    co_occur_map::Dict{Tuple{String,String}, Int} = Dict{Tuple{String,String}, Int}(),
    co_activation_pairs::Vector{Tuple{String,String,Float64}} = Tuple{String,String,Float64}[],
    # ── GRUG v10: NEW EphemeralMLP signal evidence sources ──
    mlp_disambiguation::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    chatter_co_occur_pairs::Vector{Tuple{String,String,Float64}} = Tuple{String,String,Float64}[],
    # GRUG v10: Deep MLP integration kwarg
    mlp_novelty_score::Float64 = 0.5,
)
    t_now = time()

    # ── SOURCE 1: CO-FIRING ──────────────────────────────────────────
    # GRUG: Nodes that fire in the same scan cycle are related.
    # Every co-firing pair gets an evidence increment.
    if length(co_fired_ids) >= 2
        sorted = sort(co_fired_ids)
        n = length(sorted)
        for i in 1:(n-1)
            for j in (i+1):n
                id_a, id_b = sorted[i], sorted[j]
                _add_link_evidence!(id_a, id_b, CO_FIRE_INCREMENT,
                                    "co_firing", lobe_of_fn)
            end
        end
    end

    # ── SOURCE 2: INPUT CO-OCCURRENCE ────────────────────────────────
    # GRUG: Nodes touched by the same user input are STRONGLY related.
    # The user expressed these concepts together — that's intentional.
    if length(input_touched_ids) >= 2
        sorted = sort(input_touched_ids)
        n = length(sorted)
        for i in 1:(n-1)
            for j in (i+1):n
                id_a, id_b = sorted[i], sorted[j]
                _add_link_evidence!(id_a, id_b, INPUT_CO_OCCUR_INCREMENT,
                                    "input_co_occurrence", lobe_of_fn)
            end
        end
    end

    # ── SOURCE 3: SYNONYM BRIDGE ─────────────────────────────────────
    # GRUG: If two nodes' patterns are thesaurus synonyms, they should
    # be linked — especially if they're in different lobes. The synonym
    # relationship is a SEMANTIC bridge that crosses lobe boundaries.
    if !isempty(node_ids_patterns)
        # GRUG: Build a pattern -> node_id index for fast lookup
        pattern_to_id = Dict{String, Vector{String}}()
        for (nid, pat) in node_ids_patterns
            pat_lower = lowercase(strip(pat))
            if !haskey(pattern_to_id, pat_lower)
                pattern_to_id[pat_lower] = String[]
            end
            push!(pattern_to_id[pat_lower], nid)
        end

        # GRUG: For each unique pattern, check if thesaurus knows synonyms
        # that map to OTHER nodes (different pattern, possibly different lobe)
        checked_pairs = Set{String}()
        for (nid, pat) in node_ids_patterns
            pat_lower = lowercase(strip(pat))
            try
                synonyms = thesaurus_gate_filter(pat)
                for syn in synonyms
                    syn_lower = lowercase(strip(syn))
                    if haskey(pattern_to_id, syn_lower)
                        for other_id in pattern_to_id[syn_lower]
                            if other_id != nid
                                pk = _pair_key(nid, other_id)
                                if !in(pk, checked_pairs)
                                    push!(checked_pairs, pk)
                                    _add_link_evidence!(nid, other_id,
                                                        SYNONYM_BRIDGE_INCREMENT,
                                                        "synonym_bridge", lobe_of_fn)
                                end
                            end
                        end
                    end
                end
            catch
                # GRUG: Thesaurus errors non-fatal. Skip.
            end
        end
    end

    # ── SOURCE 4: OPPOSING-LOBE CO-ACTIVATION ────────────────────────
    # GRUG: This is the KEY insight from the human. Cross-lobe nodes
    # that co-fire are the most important link candidates. They create
    # cascade paths between isolated chambers. Extra high increment.
    if !isempty(co_fired_ids) && length(co_fired_ids) >= 2
        for i in 1:length(co_fired_ids)
            for j in (i+1):length(co_fired_ids)
                id_a = co_fired_ids[i]
                id_b = co_fired_ids[j]
                la = lobe_of_fn(id_a)
                lb = lobe_of_fn(id_b)
                if !isnothing(la) && !isnothing(lb) && la != lb
                    # GRUG: Cross-lobe co-fire! This is the gold.
                    _add_link_evidence!(id_a, id_b, CROSS_LOBE_CO_ACT_INCREMENT,
                                        "opposing_lobe_co_act", lobe_of_fn;
                                        force_cross_lobe = true,
                                        explicit_lobe_a = la,
                                        explicit_lobe_b = lb)
                end
            end
        end
    end

    # ── SOURCE 5: STRAIN PAIR ────────────────────────────────────────
    # GRUG: Two nodes both under strain from novel input = they're
    # related by stress. The novel input touched both of them and
    # neither could handle it well. They should support each other.
    if length(strain_nodes) >= 2
        sorted = sort(strain_nodes)
        n = length(sorted)
        for i in 1:(n-1)
            for j in (i+1):n
                _add_link_evidence!(sorted[i], sorted[j], STRAIN_PAIR_INCREMENT,
                                    "strain_pair", lobe_of_fn)
            end
        end
    end

    # ── SOURCE 6: ATTACHMENT NEIGHBOR (indirect) ────────────────────
    # GRUG: If A is bridged to B and B is bridged to C, then A and C
    # have indirect evidence — they're one hop apart. The bridge path
    # A→B→C suggests A↔C could be valuable. Weak evidence.
    if !isempty(bridge_map_snapshot)
        checked_indirect = Set{String}()
        for (node_id, partners) in bridge_map_snapshot
            if length(partners) >= 2
                # GRUG: This node has 2+ partners. Each pair of partners
                # is one hop apart through this node.
                partner_ids = [pid for (pid, _) in partners]
                for i in 1:length(partner_ids)
                    for j in (i+1):length(partner_ids)
                        pk = _pair_key(partner_ids[i], partner_ids[j])
                        if !in(pk, checked_indirect)
                            push!(checked_indirect, pk)
                            _add_link_evidence!(partner_ids[i], partner_ids[j],
                                                ATTACH_NEIGHBOR_INCREMENT,
                                                "attach_neighbor", lobe_of_fn)
                        end
                    end
                end
            end
        end
    end

    # ── SOURCE 7: WORD CO-OCCURRENCE MAP ─────────────────────────────
    # GRUG: If words in two node patterns co-occur frequently in user
    # messages (tracked by AutoGrowth._CO_OCCUR_MAP), the nodes should
    # probably be linked. This catches semantic relationships that
    # aren't obvious from pattern overlap or thesaurus.
    if !isempty(co_occur_map) && !isempty(node_ids_patterns)
        # GRUG: Build word -> node_id index
        word_to_nodes = Dict{String, Vector{String}}()
        for (nid, pat) in node_ids_patterns
            for w in split(lowercase(strip(pat)))
                if length(w) > 3
                    if !haskey(word_to_nodes, w)
                        word_to_nodes[w] = String[]
                    end
                    push!(word_to_nodes[w], nid)
                    # GRUG: Deduplicate within same node
                    word_to_nodes[w] = unique(word_to_nodes[w])
                end
            end
        end

        checked_word_pairs = Set{String}()
        for ((word_a, word_b), count) in co_occur_map
            if count < 3
                continue  # GRUG: Need at least 3 co-occurrences
            end
            # GRUG: Get nodes containing each word
            nodes_a = get(word_to_nodes, word_a, String[])
            nodes_b = get(word_to_nodes, word_b, String[])
            for na in nodes_a
                for nb in nodes_b
                    if na != nb
                        pk = _pair_key(na, nb)
                        if !in(pk, checked_word_pairs)
                            push!(checked_word_pairs, pk)
                            _add_link_evidence!(na, nb,
                                                WORD_CO_OCCUR_INCREMENT * min(count, 10) / 5.0,
                                                "word_co_occur", lobe_of_fn)
                        end
                    end
                end
            end
        end
    end

    # ── SOURCE 8: EXPLICIT CO-ACTIVATION PAIRS ───────────────────────
    # GRUG: Direct pair evidence from RelationalGovernance CO_ACC.
    # Unlike co_fired_ids (which generates ALL pairs from a set), this
    # takes EXPLICIT (id_a, id_b, intensity) triples. Only the specified
    # pairs get evidence — no accidental cross-pair contamination.
    # This is the correct way to feed idle-time co-activation data.
    if !isempty(co_activation_pairs)
        for (id_a, id_b, pair_intensity) in co_activation_pairs
            if id_a != id_b
                _add_link_evidence!(id_a, id_b,
                                    min(pair_intensity, 20.0) * 0.3,  # GRUG: Scale down — CO_ACC intensity is already accumulated
                                    "co_activation_pair", lobe_of_fn)
            end
        end
    end

    # ── SOURCE 9: DISAMBIGUATION BRIDGE (MLP head 4) ──────────────────────────
    # GRUG: When MLP disambiguation is HIGH, the input has multiple possible
    # interpretations. Nodes that co-fired during ambiguous input should be linked
    # because they disambiguate each other — together they resolve the ambiguity.
    # This is the MLP telling us: "these nodes carry complementary signals."
    if mlp_disambiguation > DISAMBIGUATION_BRIDGE_THRESHOLD && length(co_fired_ids) >= 2
        # GRUG: Only add evidence for co-fired pairs during high disambiguation.
        # The MLP detected ambiguity — the co-fired nodes are the disambiguators.
        for i in 1:length(co_fired_ids)
            for j in (i+1):length(co_fired_ids)
                id_a = co_fired_ids[i]
                id_b = co_fired_ids[j]
                la = lobe_of_fn(id_a)
                lb = lobe_of_fn(id_b)
                # GRUG: Cross-lobe disambiguation pairs are especially valuable —
                # they provide ALTERNATIVE perspectives on the same ambiguous input.
                cross_bonus = (!isnothing(la) && !isnothing(lb) && la != lb) ? 1.5 : 1.0
                _add_link_evidence!(id_a, id_b,
                                    DISAMBIGUATION_BRIDGE_INCREMENT * mlp_disambiguation * cross_bonus,
                                    "disambiguation_bridge", lobe_of_fn;
                                    force_cross_lobe = cross_bonus > 1.0,
                                    explicit_lobe_a = something(la, ""),
                                    explicit_lobe_b = something(lb, ""))
            end
        end
    end

    # ── SOURCE 10: RELEVANCE CROSS-LOBE (MLP head 3) ──────────────────────────
    # GRUG: When MLP relevance_score is LOW, the current node coverage is weak —
    # the input doesn't match well to existing knowledge. Cross-lobe pairs that
    # co-fired during low-relevance input should be linked because they represent
    # ALTERNATIVE paths that might restore relevance. Low relevance = gap in the
    # cave's connectivity. Linking the cross-lobe survivors fills that gap.
    if mlp_relevance_score < RELEVANCE_CROSS_LOBE_THRESHOLD && length(co_fired_ids) >= 2
        for i in 1:length(co_fired_ids)
            for j in (i+1):length(co_fired_ids)
                id_a = co_fired_ids[i]
                id_b = co_fired_ids[j]
                la = lobe_of_fn(id_a)
                lb = lobe_of_fn(id_b)
                # GRUG: ONLY cross-lobe pairs get this bonus. Same-lobe pairs
                # already share context — they don't fill the relevance gap.
                if !isnothing(la) && !isnothing(lb) && la != lb
                    gap_magnitude = 1.0 - mlp_relevance_score  # GRUG: bigger gap = more evidence
                    _add_link_evidence!(id_a, id_b,
                                        RELEVANCE_CROSS_LOBE_INCREMENT * gap_magnitude,
                                        "relevance_cross_lobe", lobe_of_fn;
                                        force_cross_lobe = true,
                                        explicit_lobe_a = la,
                                        explicit_lobe_b = lb)
                end
            end
        end
    end

    # ── SOURCE 11: CHATTER RESIDUAL CO-OCCURRENCE ──────────────────────────────
    # GRUG: ChatterResiduals detects word pairs that co-occur during vote-stealing
    # and Markov crossover — residual patterns that the normal scan cycle misses.
    # These are "underground" co-occurrence signals. If two words keep showing up
    # together in chatter residuals, their nodes should be linked.
    # Each chatter_co_occur pair is (word_a, word_b, pair_intensity).
    # We look up which nodes contain each word and add evidence between them.
    if !isempty(chatter_co_occur_pairs) && !isempty(node_ids_patterns)
        # GRUG: Build word -> node_id index (same as SOURCE 7)
        word_to_nodes = Dict{String, Vector{String}}()
        for (nid, pat) in node_ids_patterns
            for w in split(lowercase(strip(pat)))
                if length(w) > 3
                    if !haskey(word_to_nodes, w)
                        word_to_nodes[w] = String[]
                    end
                    push!(word_to_nodes[w], nid)
                    word_to_nodes[w] = unique(word_to_nodes[w])
                end
            end
        end

        checked_chatter = Set{String}()
        for (word_a, word_b, pair_intensity) in chatter_co_occur_pairs
            if pair_intensity < 0.1
                continue  # GRUG: Skip negligible chatter
            end
            nodes_a = get(word_to_nodes, word_a, String[])
            nodes_b = get(word_to_nodes, word_b, String[])
            for na in nodes_a
                for nb in nodes_b
                    if na != nb
                        pk = _pair_key(na, nb)
                        if !in(pk, checked_chatter)
                            push!(checked_chatter, pk)
                            _add_link_evidence!(na, nb,
                                                CHATTER_RESIDUAL_INCREMENT * pair_intensity * 0.5,
                                                "chatter_residual", lobe_of_fn)
                        end
                    end
                end
            end
        end
    end


    # ── SOURCE 12: NOVELTY-AMPLIFIED CO-FIRING (MLP novelty_score) ──────
    # GRUG v10: When EphemeralMLP novelty_score is high, the brain is seeing
    # novel input. Co-firing during novel input is MORE significant than
    # co-firing during familiar input, because novel co-firing represents
    # new associations forming. We boost co-fire pairs that fired during
    # high novelty. This is separate from SOURCE 1 (base co-fire) because
    # it applies a novelty-dependent multiplier.
    if mlp_novelty_score > 0.6 && length(co_fired_ids) >= 2
        novelty_mult = 1.0 + NOVELTY_CO_FIRE_BOOST * (mlp_novelty_score - 0.6) / 0.4
        for i in 1:length(co_fired_ids)
            for j in (i+1):length(co_fired_ids)
                id_a = co_fired_ids[i]
                id_b = co_fired_ids[j]
                la = lobe_of_fn(id_a)
                lb = lobe_of_fn(id_b)
                # GRUG: Cross-lobe novel co-firing = gold + platinum
                cross_bonus = (!isnothing(la) && !isnothing(lb) && la != lb) ? 1.5 : 1.0
                _add_link_evidence!(id_a, id_b,
                                    CO_FIRE_INCREMENT * (novelty_mult - 1.0) * cross_bonus,
                                    "novelty_co_fire", lobe_of_fn;
                                    force_cross_lobe = cross_bonus > 1.0,
                                    explicit_lobe_a = something(la, ""),
                                    explicit_lobe_b = something(lb, ""))
            end
        end
    end


    # ── DECAY ───────────────────────────────────────────────────────
    lock(_LINK_EVIDENCE_LOCK) do
        if t_now - _LAST_LINK_DECAY[] > LINK_DECAY_INTERVAL
            _decay_link_evidence!(t_now)
            _LAST_LINK_DECAY[] = t_now
        end
    end

    # ── CAP ──────────────────────────────────────────────────────────
    lock(_LINK_EVIDENCE_LOCK) do
        while length(_LINK_EVIDENCE) > LINK_EVIDENCE_CAP
            oldest_key = ""
            oldest_time = Inf
            for (k, v) in _LINK_EVIDENCE
                if v.last_seen < oldest_time
                    oldest_time = v.last_seen
                    oldest_key = k
                end
            end
            !isempty(oldest_key) && delete!(_LINK_EVIDENCE, oldest_key)
        end
    end

    return nothing
end


"""
    _add_link_evidence!(id_a, id_b, intensity, source, lobe_of_fn;
                        force_cross_lobe=false, explicit_lobe_a="", explicit_lobe_b="")

GRUG: Add evidence that id_a and id_b should be bridged.
Resolves lobes, determines cross-lobe status, and accumulates.
"""
function _add_link_evidence!(id_a::String, id_b::String,
                             intensity::Float64, source::String,
                             lobe_of_fn::Function;
                             force_cross_lobe::Bool = false,
                             explicit_lobe_a::String = "",
                             explicit_lobe_b::String = "")
    id_a == id_b && return nothing  # GRUG: No self-links

    key = _pair_key(id_a, id_b)

    # GRUG: Resolve lobes
    la = isempty(explicit_lobe_a) ? lobe_of_fn(id_a) : explicit_lobe_a
    lb = isempty(explicit_lobe_b) ? lobe_of_fn(id_b) : explicit_lobe_b
    cross = force_cross_lobe || (!isnothing(la) && !isnothing(lb) && la != lb)
    la_str = something(la, "")
    lb_str = something(lb, "")

    lock(_LINK_EVIDENCE_LOCK) do
        if haskey(_LINK_EVIDENCE, key)
            rec = _LINK_EVIDENCE[key]
            rec.accumulated_intensity += intensity
            rec.frequency += 1
            push!(rec.sources, source)
            rec.last_seen = time()
            # GRUG: Upgrade cross-lobe status if new evidence says so
            if cross && !rec.is_cross_lobe
                rec.is_cross_lobe = true
            end
        else
            rec = LinkEvidenceRecord(id_a < id_b ? id_a : id_b,
                                     id_a < id_b ? id_b : id_a;
                                     is_cross_lobe = cross,
                                     lobe_a = la_str,
                                     lobe_b = lb_str)
            rec.accumulated_intensity = intensity
            rec.frequency = 1
            push!(rec.sources, source)
            _LINK_EVIDENCE[key] = rec
        end
    end
end


"""
    _decay_link_evidence!(t_now)

GRUG: Halve all accumulated intensities. Evidence that stops being
observed fades to zero and gets evicted. Same as AutoGrowth decay.
"""
function _decay_link_evidence!(t_now::Float64)
    lock(_LINK_EVIDENCE_LOCK) do
        to_delete = String[]
        for (key, rec) in _LINK_EVIDENCE
            rec.accumulated_intensity *= 0.5
            if rec.accumulated_intensity < 0.1
                push!(to_delete, key)
            end
        end
        for key in to_delete
            delete!(_LINK_EVIDENCE, key)
        end
    end
end

# ==============================================================================
# COINFLIP LINK DECISION — maybe bridge a pair
# ==============================================================================

"""
    maybe_auto_link!(; kwargs...) -> Union{AutoLinkStats, Nothing}

GRUG: Check accumulated link evidence and maybe bridge a pair of nodes.
The coinflip is biased by evidence intensity. Cross-lobe pairs get a
bonus multiplier. Same-lobe pairs get a penalty.

Only ONE link per call (one per conversation turn). If the coinflip
doesn't land, nothing happens. If it does, the system bridges whatever
pair has the strongest evidence AND passes all gate checks.

Required kwargs:
  - node_map, node_lock: the live NODE_MAP and its lock
  - bridge_fn: (node_a, node_b; seam_tokens) -> String — bridge_nodes! wrapper
  - bridge_map_ref: BRIDGE_MAP dict (for cap checking)
  - bridge_lock_ref: BRIDGE_LOCK (for cap checking)
  - lobe_of_fn: (node_id) -> Union{String, Nothing} — resolve lobe
  - immune_gate_fn: (pattern, data) -> Bool — immune system check
  - is_already_bridged_fn: (node_a, node_b) -> Bool — duplicate check

Optional kwargs:
  - node_alive_fn: (node_id) -> Bool — check if node is alive (not grave)
  - thesaurus_gate_filter: Function — for seam token computation
  - max_bridges: Int — bridge cap (default ENGINE_MAX_BRIDGES = 4)
"""
function maybe_auto_link!(;
    node_map,
    node_lock,
    bridge_fn::Function,
    bridge_map_ref,
    bridge_lock_ref,
    lobe_of_fn::Function,
    immune_gate_fn::Function,
    is_already_bridged_fn::Function,
    node_alive_fn::Function = (id) -> true,
    thesaurus_gate_filter::Function = (w) -> String[],
    max_bridges::Int = ENGINE_MAX_BRIDGES,
)
    # GRUG: Find the best candidate pair with enough evidence.
    # Pick the one with highest accumulated intensity that passes floors.
    best_key = nothing
    best_intensity = -1.0
    best_is_cross = false
    best_lobe_a = ""
    best_lobe_b = ""
    best_source = ""

    lock(_LINK_EVIDENCE_LOCK) do
        for (key, rec) in _LINK_EVIDENCE
            # GRUG: Check evidence floor — cross-lobe uses lower floor
            floor = rec.is_cross_lobe ? LINK_EVIDENCE_FLOOR : SAME_LOBE_EVIDENCE_FLOOR
            if rec.accumulated_intensity < floor
                continue
            end
            # GRUG: Check frequency floor
            if rec.frequency < LINK_FREQUENCY_FLOOR
                continue
            end
            # GRUG: Pick highest intensity
            if rec.accumulated_intensity > best_intensity
                best_key = key
                best_intensity = rec.accumulated_intensity
                best_is_cross = rec.is_cross_lobe
                best_lobe_a = rec.lobe_a
                best_lobe_b = rec.lobe_b
                best_source = isempty(rec.sources) ? "unknown" : rec.sources[end]
            end
        end
    end

    if isnothing(best_key)
        return nothing  # GRUG: No pair with enough evidence
    end

    # GRUG: Parse the pair key back to node IDs
    parts = split(best_key, "::")
    if length(parts) != 2
        return nothing
    end
    id_a = String(parts[1])
    id_b = String(parts[2])

    # GRUG: PRE-FLIGHT CHECKS — verify both nodes are alive, not at cap,
    # not already bridged, and pass immune gate.

    # Check: both nodes still alive?
    if !node_alive_fn(id_a) || !node_alive_fn(id_b)
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end
        return nothing
    end

    # Check: already bridged?
    if is_already_bridged_fn(id_a, id_b)
        # GRUG: Already bridged! Remove evidence — the link exists.
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end
        return nothing
    end

    # Check: bridge cap on both sides?
    bridges_a = lock(() -> length(get(bridge_map_ref, id_a, [])), bridge_lock_ref)
    bridges_b = lock(() -> length(get(bridge_map_ref, id_b, [])), bridge_lock_ref)
    if bridges_a >= max_bridges || bridges_b >= max_bridges
        # GRUG: One or both nodes at bridge cap. Remove evidence — can't link.
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end
        return nothing
    end

    # ── COINFLIP ─────────────────────────────────────────────────────
    # GRUG: Compute the coinflip probability. Biased by evidence intensity.
    # Cross-lobe gets bonus. Same-lobe gets penalty.
    p_base = min(best_intensity / LINK_EVIDENCE_SCALE, LINK_COINFLIP_CAP)
    if best_is_cross
        p_link = min(p_base * CROSS_LOBE_BONUS, LINK_COINFLIP_CAP)
    else
        p_link = p_base * SAME_LOBE_PENALTY
    end

    coinflip = rand()
    won = coinflip < p_link

    if !won
        return nothing  # GRUG: Coinflip didn't land. Try again next turn.
    end

    # ── IMMUNE GATE ──────────────────────────────────────────────────
    # GRUG: The immune system gets final say. If it rejects this link,
    # we respect that. Remove evidence so we don't keep retrying.
    link_pattern = "autolink:$id_a:$id_b"
    json_data = Dict{String,Any}(
        "node_a" => id_a,
        "node_b" => id_b,
        "evidence_intensity" => best_intensity,
        "is_cross_lobe" => best_is_cross,
        "lobe_a" => best_lobe_a,
        "lobe_b" => best_lobe_b,
        "source" => best_source,
    )
    if !immune_gate_fn(link_pattern, json_data)
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end
        return AutoLinkStats(false, id_a, id_b, best_is_cross,
                             best_intensity, p_link, best_source,
                             best_lobe_a, best_lobe_b,
                             "Immune gate rejected link $id_a ↔ $id_b")
    end

    # ── COMPUTE SEAM TOKENS ──────────────────────────────────────────
    # GRUG: The bridge needs seam tokens. Compute shared words from
    # both node patterns. If no shared words, use a relational marker.
    pattern_a = ""
    pattern_b = ""
    lock(node_lock) do
        na = get(node_map, id_a, nothing)
        nb = get(node_map, id_b, nothing)
        if !isnothing(na); pattern_a = na.pattern; end
        if !isnothing(nb); pattern_b = nb.pattern; end
    end

    tokens_a = Set(split(lowercase(strip(pattern_a))))
    tokens_b = Set(split(lowercase(strip(pattern_b))))
    shared = intersect(tokens_a, tokens_b)

    seam_tokens = if !isempty(shared)
        # GRUG: Shared words exist — use them as seam.
        sort(collect(shared))
    else
        # GRUG: No shared words but they're related by evidence.
        # Use first token from each + relational marker.
        fa = isempty(tokens_a) ? "X" : first(sort(collect(tokens_a)))
        fb = isempty(tokens_b) ? "Y" : first(sort(collect(tokens_b)))
        ["$(fa)≈$(fb)"]
    end

    # ── BRIDGE! ──────────────────────────────────────────────────────
    try
        result = bridge_fn(id_a, id_b; seam_tokens = seam_tokens)

        # GRUG: Bridge succeeded! Remove evidence + log it.
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end

        lock(_LINK_EVIDENCE_LOCK) do
            _TOTAL_AUTO_LINKS[] += 1
        end

        stats = AutoLinkStats(true, id_a, id_b, best_is_cross,
                              best_intensity, p_link, best_source,
                              best_lobe_a, best_lobe_b,
                              "Auto-linked $id_a ↔ $id_b (cross=$(best_is_cross), intensity=$(round(best_intensity, digits=2)), p=$(round(p_link, digits=3)), source=$best_source)")

        lock(_LINK_LOG_LOCK) do
            push!(_LINK_LOG, stats)
            if length(_LINK_LOG) > LINK_LOG_MAX
                deleteat!(_LINK_LOG, 1)
            end
        end

        return stats

    catch e
        # GRUG: Bridge failed (cap check, grave, etc). Remove evidence.
        lock(_LINK_EVIDENCE_LOCK) do
            delete!(_LINK_EVIDENCE, best_key)
        end

        return AutoLinkStats(false, id_a, id_b, best_is_cross,
                             best_intensity, p_link, best_source,
                             best_lobe_a, best_lobe_b,
                             "Bridge FAILED for $id_a ↔ $id_b: $e")
    end
end

# ==============================================================================
# STATUS + DIAGNOSTICS
# ==============================================================================

"""
    get_autolink_status_summary() -> String

GRUG: Human-readable status of the auto-linker. Shows evidence count,
cross-lobe count, top candidates, and recent link history.
"""
function get_autolink_status_summary()::String
    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════╗")
    push!(lines, "║          AUTOLINKER — Evidence Status            ║")
    push!(lines, "╠══════════════════════════════════════════════════╣")

    total_evidence = 0
    cross_lobe_count = 0
    above_floor = 0
    top_candidates = Tuple{Float64, String, Bool, Int}[]  # (intensity, key, cross, freq)

    lock(_LINK_EVIDENCE_LOCK) do
        total_evidence = length(_LINK_EVIDENCE)
        for (key, rec) in _LINK_EVIDENCE
            if rec.is_cross_lobe
                cross_lobe_count += 1
            end
            floor = rec.is_cross_lobe ? LINK_EVIDENCE_FLOOR : SAME_LOBE_EVIDENCE_FLOOR
            if rec.accumulated_intensity >= floor && rec.frequency >= LINK_FREQUENCY_FLOOR
                above_floor += 1
            end
            push!(top_candidates, (rec.accumulated_intensity, key, rec.is_cross_lobe, rec.frequency))
        end
    end

    sort!(top_candidates, by = x -> -x[1])
    top5 = top_candidates[1:min(5, length(top_candidates))]

    push!(lines, "║  evidence_records=$total_evidence")
    push!(lines, "║  cross_lobe_pairs=$cross_lobe_count")
    push!(lines, "║  above_floor=$above_floor (eligible for coinflip)")
    push!(lines, "║  total_auto_links=$(lock(_LINK_EVIDENCE_LOCK) do; _TOTAL_AUTO_LINKS[] end)")
    push!(lines, "║")
    push!(lines, "║  CONSTANTS:")
    push!(lines, "║    evidence_floor=$LINK_EVIDENCE_FLOOR (cross-lobe)")
    push!(lines, "║    same_lobe_floor=$SAME_LOBE_EVIDENCE_FLOOR")
    push!(lines, "║    frequency_floor=$LINK_FREQUENCY_FLOOR")
    push!(lines, "║    coinflip_cap=$(LINK_COINFLIP_CAP * 100)%")
    push!(lines, "║    cross_lobe_bonus=$(CROSS_LOBE_BONUS)x")
    push!(lines, "║    same_lobe_penalty=$(SAME_LOBE_PENALTY)x")
    push!(lines, "║    decay_half_life=$(LINK_DECAY_HALFLIFE)s")
    push!(lines, "║    disambiguation_bridge_thresh=$(DISAMBIGUATION_BRIDGE_THRESHOLD)")
    push!(lines, "║    relevance_cross_lobe_thresh=$(RELEVANCE_CROSS_LOBE_THRESHOLD)")
    push!(lines, "║    chatter_residual_increment=$(CHATTER_RESIDUAL_INCREMENT)")
    push!(lines, "║    disambiguation_bridge_increment=$(DISAMBIGUATION_BRIDGE_INCREMENT)")
    push!(lines, "║    relevance_cross_lobe_increment=$(RELEVANCE_CROSS_LOBE_INCREMENT)")
    push!(lines, "║")

    if !isempty(top5)
        push!(lines, "║  TOP CANDIDATES:")
        for (intensity, key, cross, freq) in top5
            parts = split(key, "::")
            tag = cross ? "XLOBE" : "SAME "
            push!(lines, "║    [$tag] $(parts[1]) ↔ $(parts[2]) | intensity=$(round(intensity, digits=2)) freq=$freq")
        end
    end

    # GRUG: Recent link log
    recent = lock(() -> length(_LINK_LOG) > 5 ? _LINK_LOG[(end-4):end] : copy(_LINK_LOG), _LINK_LOG_LOCK)
    if !isempty(recent)
        push!(lines, "║")
        push!(lines, "║  RECENT LINKS:")
        for r in recent
            tag = r.is_cross_lobe ? "XLOBE" : "SAME "
            status = r.won_coinflip ? "✓" : "✗"
            push!(lines, "║    [$tag$status] $(r.node_a) ↔ $(r.node_b) | p=$(round(r.coinflip_p, digits=3)) source=$(r.source)")
        end
    end

    push!(lines, "╚══════════════════════════════════════════════════╝")
    return join(lines, "\n")
end

"""
    reset_link_evidence!()

GRUG: Clear all link evidence. For debugging/testing.
"""
function reset_link_evidence!()
    lock(_LINK_EVIDENCE_LOCK) do
        empty!(_LINK_EVIDENCE)
    end
    lock(_LINK_LOG_LOCK) do
        empty!(_LINK_LOG)
    end
    lock(_LINK_EVIDENCE_LOCK) do
        _TOTAL_AUTO_LINKS[] = 0
        _LAST_LINK_DECAY[] = time()
    end
end

"""
    get_link_log() -> Vector{AutoLinkStats}

GRUG: Get the link event log. For diagnostics.
"""
function get_link_log()::Vector{AutoLinkStats}
    lock(_LINK_LOG_LOCK) do
        return copy(_LINK_LOG)
    end
end

# ==============================================================================
# SPECIMEN SAVE/LOAD — snapshots of link evidence for persistence
# ==============================================================================

"""
    get_link_evidence_snapshot() -> Dict

GRUG: Serialize link evidence for specimen save.
Returns a dict of key -> (intensity, frequency, sources, is_cross_lobe, lobe_a, lobe_b)
"""
function get_link_evidence_snapshot()::Dict{String, Any}
    snap = Dict{String, Any}()
    lock(_LINK_EVIDENCE_LOCK) do
        for (key, rec) in _LINK_EVIDENCE
            snap[key] = Dict{String, Any}(
                "node_a"              => rec.node_a,
                "node_b"              => rec.node_b,
                "accumulated_intensity" => rec.accumulated_intensity,
                "frequency"           => rec.frequency,
                "sources"             => copy(rec.sources),
                "is_cross_lobe"       => rec.is_cross_lobe,
                "lobe_a"              => rec.lobe_a,
                "lobe_b"              => rec.lobe_b,
                "last_seen"           => rec.last_seen,
            )
        end
    end
    return snap
end

"""
    load_link_evidence_snapshot!(snap::Dict)

GRUG: Restore link evidence from specimen load.
"""
function load_link_evidence_snapshot!(snap)
    lock(_LINK_EVIDENCE_LOCK) do
        empty!(_LINK_EVIDENCE)
        for (key, data) in snap
            if isa(data, AbstractDict)
                rec = LinkEvidenceRecord(
                    get(data, "node_a", ""),
                    get(data, "node_b", "");
                    is_cross_lobe = get(data, "is_cross_lobe", false),
                    lobe_a = get(data, "lobe_a", ""),
                    lobe_b = get(data, "lobe_b", ""),
                )
                rec.accumulated_intensity = get(data, "accumulated_intensity", 0.0)
                rec.frequency = get(data, "frequency", 0)
                rec.sources = get(data, "sources", String[])
                rec.last_seen = get(data, "last_seen", time())
                _LINK_EVIDENCE[key] = rec
            end
        end
    end
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export accumulate_link_evidence!, maybe_auto_link!
export get_autolink_status_summary, reset_link_evidence!
export get_link_log, AutoLinkStats
export get_link_evidence_snapshot, load_link_evidence_snapshot!
export LINK_EVIDENCE_FLOOR, SAME_LOBE_EVIDENCE_FLOOR, LINK_EVIDENCE_SCALE
export LINK_COINFLIP_CAP, CROSS_LOBE_BONUS, SAME_LOBE_PENALTY
export LINK_FREQUENCY_FLOOR, MAX_LINK_PER_TURN, LINK_EVIDENCE_CAP
export LINK_DECAY_HALFLIFE
export DISAMBIGUATION_BRIDGE_THRESHOLD, RELEVANCE_CROSS_LOBE_THRESHOLD
export DISAMBIGUATION_BRIDGE_INCREMENT, RELEVANCE_CROSS_LOBE_INCREMENT
export CHATTER_RESIDUAL_INCREMENT

end # module AutoLinker
