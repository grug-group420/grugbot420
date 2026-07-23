# AutoGrowth.jl
# ==============================================================================
# LIVE CONVERSATION AUTO-LEARNING — Evidence Accumulation + Lazy Coinflip Growth
# ==============================================================================
# GRUG: The cave grows while you TALK to it, not just when you're quiet.
# Every user message carries evidence. The system ACCUMULATES that evidence
# lazily — one datum at a time, biased by intensity. When enough evidence
# piles up for a gap, a coinflip decides whether to grow NOW. The coinflip
# is BIASED by evidence intensity: more evidence = higher probability.
# Low evidence = almost never grows. High evidence = grows for sure.
#
# PRINCIPLE: LAZY CONSERVATIVE. Accumulate first, grow later. Never grow
# on the first mention. Grow when the cave has HEARD something enough
# times to be sure it's a real gap, not noise.
#
# ARCHITECTURE:
#   1. EVIDENCE ACCUMULATOR — Dict{String, EvidenceRecord}
#      - Key: candidate pattern/token that might need a node
#      - Value: cumulative intensity, frequency count, source tags, last_seen
#      - Updated on EVERY user message (process_mission path, not idle)
#   2. COINFLIP GATE — evidence-biased stochastic lever
#      - p_grow = min(evidence_intensity / GROWTH_EVIDENCE_SCALE, GROWTH_COINFLIP_CAP)
#      - Only coinflip when evidence passes GROWTH_EVIDENCE_FLOOR threshold
#      - Max one growth per conversation turn (no flooding)
#   3. GROWTH TYPES — all node types and side systems:
#      a. MATCH nodes — pattern-activated voting nodes (standard)
#      b. TIME nodes — temporal orientation nodes (time_node=true)
#      c. AIML nodes — stochastic executive templates
#      d. ANTIMATCH nodes — confidence drains (rare, only for recurring negation patterns)
#      e. SIGIL entries — new &noun lexicon entries or relation sigils
#      f. THESAURUS pairs — synonym seed pairs discovered from co-occurrence
#      g. LOBE subject whitelist entries — domain tokens for under-populated lobes
#   4. INTEGRATION — wired into process_mission (active conversation)
#      and maybe_run_idle (supplement TemporalGrowth)
#
# EVIDENCE SOURCES (same warrants as MitosisMode but ACCUMULATED, not immediate):
#   - SILENCE: high-intensity user messages with no node match
#   - FREQUENCY: words that appear 5+ times but have no coverage
#   - THESAURUS: synonyms close to existing nodes but uncovered
#   - LOBE_COVERAGE: under-populated lobes missing domain tokens
#   - ATTACHMENT: crystalized attachment connectors with no node
#   - STRAIN: EphemeralMLP hippocampal strain (internal hurt)
#   - SIGIL_GAP: patterns that reference sigils but sigil has no expansion
#   - CO_OCCURRENCE: words that co-occur with existing node patterns frequently
#
# CANCER PREVENTION:
#   - Evidence DECAYS over time (half-life = EVIDENCE_DECAY_HALFLIFE_SECONDS)
#   - Max evidence entries = EVIDENCE_CAP (bounded)
#   - Growth coinflip cap = GROWTH_COINFLIP_CAP (0.25 = max 25% chance per turn)
#   - Only one growth per conversation turn
#   - Immune gate checks every growth (same as /grow and mitosis)
#   - Population cap still applies (MAX_POPULATION_CAP)
#   - NOCHAT for new singleton groups (same as MitosisMode)
# ==============================================================================

module AutoGrowth

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

# GRUG: Bring in sibling module SigilRegistry for verb→sigil reverse lookup.
# AutoGrowth is a submodule of Main and cannot see sibling modules without this.
using ..SigilRegistry

# GRUG v7.58: Bring in RelationalTriple from engine.jl so _grow_node! can
# construct relational_patterns. Without this, UndefVarError(:RelationalTriple)
# silently kills the relational pattern assignment block.
import ..RelationalTriple

# GRUG v8.2: Bring in InverseSigil for growth magnet (SOURCE 19).
# Shape-cluster density is a genuinely new signal that the 18 existing sources
# don't produce. The magnet clusters uncovered tokens by sigil shape, producing
# stronger growth signals than treating each token as an unrelated atom.
using ..InverseSigil

# GRUG: Bring in sibling modules for node creation, sigil registration, etc.
# These are injected as function kwargs — no `using` needed for the core module.
# The module is self-contained; callers inject the needed functions.

# ==============================================================================
# EVIDENCE RECORD — one candidate gap the cave has noticed
# ==============================================================================

mutable struct EvidenceRecord
    pattern::String              # The candidate pattern/token
    accumulated_intensity::Float64  # Cumulative intensity from all observations
    frequency::Int               # How many times this gap was observed
    sources::Set{String}         # Which warrant sources noticed this gap
    last_seen::Float64           # Unix timestamp of most recent observation
    first_seen::Float64          # Unix timestamp of first observation
    growth_type::Symbol          # :match, :time, :aiml, :antimatch(DEAD), :sigil, :thesaurus, :lobe_whitelist, :flashcard
    lobe_hint::String            # Inferred lobe for this candidate
    user_triples::Vector{Tuple{String,String,String}}  # GRUG v7.58: Relational triples from user input that triggered this evidence. Promoted to sigil refs at growth time.
    # GRUG: Evidence-biased coinflip needs these to be mutable.
    # Decay happens every cycle — accumulated_intensity shrinks over time.
end

function EvidenceRecord(pattern::String, growth_type::Symbol;
                        lobe_hint::String = "default",
                        user_triples::Vector{Tuple{String,String,String}} = Tuple{String,String,String}[])
    t = time()
    EvidenceRecord(pattern, 0.0, 0, Set{String}(), t, t, growth_type, lobe_hint, user_triples)
end

# ==============================================================================
# AUTO GROWTH STATS — one growth event record
# ==============================================================================

struct AutoGrowthStats
    pattern::String
    growth_type::String         # "match", "time", "aiml", "antimatch"(DEAD), "sigil", "thesaurus", "lobe_whitelist", "flashcard"
    evidence_intensity::Float64
    evidence_frequency::Int
    coinflip_prob::Float64
    won_coinflip::Bool
    new_id::String              # Node ID or sigil name (empty if coinflip lost or immune blocked)
    lobe_hint::String
    source::String              # Which evidence source triggered this
    notes::String
    cycle_time_ms::Float64
end

# ==============================================================================
# CONSTANTS — LAZY CONSERVATIVE TUNING
# ==============================================================================

# GRUG: Evidence floor. Below this accumulated intensity, NO growth attempt.
# A candidate needs at least this much evidence before the system even
# considers growing for it. 2.0 = roughly 2 high-intensity observations
# or 5+ low-intensity ones. Lazy.
const EVIDENCE_FLOOR = 2.0

# GRUG: Frequency floor. A candidate must be observed at least this many
# times before growth is considered. 3 = you need to hear it thrice.
# Not once (noise), not twice (coincidence), thrice (pattern).
const EVIDENCE_FREQUENCY_FLOOR = 3

# GRUG: Evidence decay half-life. Observations older than this decay by half.
# 3600 seconds = 1 hour. If you mentioned something an hour ago and never
# again, its evidence is halved. Mentioned 2 hours ago? Quartered.
# This prevents stale evidence from triggering growth on topics the user
# moved on from. The cave forgets what it doesn't keep hearing about.
const EVIDENCE_DECAY_HALFLIFE = 3600.0  # seconds

# GRUG: Evidence decay interval. How often to run decay. Every 60 seconds
# = once per minute. Not every cycle (too expensive), not every hour
# (stale evidence lingers too long).
const EVIDENCE_DECAY_INTERVAL = 60.0

# GRUG: Evidence scale for coinflip bias.
# p_grow = min(accumulated_intensity / EVIDENCE_SCALE, GROWTH_COINFLIP_CAP)
# At EVIDENCE_SCALE = 8.0, you need 8.0 accumulated intensity for a 25%
# growth chance (at cap). Higher scale = more evidence needed = more lazy.
const EVIDENCE_SCALE = 8.0

# GRUG: Growth coinflip cap. The maximum probability of growing per turn.
# 0.25 = at MOST 25% chance of growing, even with enormous evidence.
# Combined with one-growth-per-turn, that's at most 1 node per 4 turns
# at peak evidence. Slow. Like moss.
const GROWTH_COINFLIP_CAP = 0.25

# GRUG: Maximum evidence entries. Bounded so the accumulator doesn't grow
# without limit. Oldest entries are evicted when cap is hit.
const EVIDENCE_CAP = 500

# GRUG: Max autogrowth events per conversation turn. Always 1.
# The cave grows at most one thing per user message. Never flood.
const MAX_GROWTH_PER_TURN = 1

# GRUG: Population cap — same as MitosisMode. No growth beyond this.
const POPULATION_CAP = 10000

# GRUG: Evidence intensity increment per observation. Default is the
# user message intensity (from MESSAGE_HISTORY). For sigil/thesaurus
# sources that don't have intensity, use this default.
const DEFAULT_INTENSITY_INCREMENT = 1.0

# GRUG: Co-occurrence threshold for thesaurus pair discovery.
# Two words must co-occur in user messages this many times before
# we consider them synonym candidates. High bar = conservative.
const THESAURUS_CO_OCCUR_MIN = 5

# GRUG: Thesaurus similarity floor for auto-discovered pairs.
# Only pairs with trigram similarity >= this get registered.
# Prevents garbage pairs like "the"/"then" (high co-occurrence, no meaning).
const THESAURUS_AUTO_SIM_FLOOR = 0.3

# GRUG: Sigil gap evidence floor. A pattern that references a sigil
# but the sigil has no expansion needs EVIDENCE_FLOOR observations
# before we consider growing an expansion entry. Same floor as match nodes.
const SIGIL_EVIDENCE_FLOOR = EVIDENCE_FLOOR

# GRUG: AIML growth probability when evidence supports it.
# AIML nodes are heavier (template+executive), so grow them at 1/3 the
# rate of match nodes. Same stochastic ratio as MitosisMode.
const AIML_GROWTH_RATE = 0.33

# GRUG: Antimatch growth — VERY rare. Only for recurring negation patterns.
# Antimatch nodes drain confidence; too many = cave becomes depressive.
const ANTIMATCH_GROWTH_RATE = 0.1

# GRUG: Time node growth — when user mentions temporal orientations
# (before, after, during, while, when) frequently with no time node coverage.
const TIME_NODE_KEYWORDS = Set([
    "before", "after", "during", "while", "when", "since", "until",
    "previously", "afterwards", "meanwhile", "simultaneously", "eventually",
    "soon", "later", "earlier", "already", "yet", "still", "now",
])

# GRUG: Lobe whitelist growth rate. When a lobe is under-populated and
# the user mentions domain tokens not in its whitelist, we add them.
# 0.5 = 50% chance per qualifying evidence (whitelist growth is cheap).
const LOBE_WHITELIST_GROWTH_RATE = 0.5

# GRUG v10: Flashcard growth rate. When arithmetic facts accumulate evidence,
# write to flashcard instead of growing a node. Flashcard growth is CHEAP.
const FLASHCARD_GROWTH_RATE = 0.8

# GRUG v8.2: Sigil voter node growth rate. These are NOCHAT, singleton, never
# in growth groups. They're lighter than AIML but more specialized than match.
# 0.5 = half the rate of regular match growth. Still cautious.
const SIGIL_VOTER_GROWTH_RATE = 0.5

# GRUG v8.2: Inverse voter node growth rate. Regular :voter nodes grown via
# the inverse sigil magnet. These ARE chat-eligible and join groups, but
# they're grown from shape-cluster evidence (stronger warrant than raw gap).
# Same rate as regular match — the evidence bonus from the magnet already
# makes them grow faster; no need to further adjust the coinflip.
const INVERSE_VOTER_GROWTH_RATE = 1.0

# GRUG v8.2: Concept dedup similarity floor. Before growing ANY node,
# check if an existing node already covers the same concept. Uses thesaurus
# synonym_lookup + word_similarity. If any existing pattern scores above
# this floor, the growth is blocked as a duplicate. 0.7 = if "big" exists,
# "large" (synonym=0.95) is blocked, but "huge" (sim~0.4) is allowed.
const CONCEPT_DEDUP_FLOOR = 0.7

# GRUG v10: Curiosity growth rate. When curiosity accumulator overflows,
# it's very likely a real question should be asked. High rate.

# ── GRUG v10: MLP HEAD EVIDENCE THRESHOLDS ─────────────────────────────
# GRUG: The 3 unused EphemeralMLP output heads now feed evidence.
# These thresholds control when each head value becomes a signal.

# When semantic_score < this, the brain can't find semantically coherent matches.
const SEMANTIC_GAP_THRESHOLD        = 0.35

# When relevance_score < this, the brain's responses aren't relevant.
const RELEVANCE_DROPOUT_THRESHOLD   = 0.30

# When disambiguation > this, the brain sees ambiguity it can't resolve.
const DISAMBIGUATION_PRESSURE_THRESHOLD = 0.65

# When |ΔΦ| > this and negative, coherence is dropping.
const COHERENCE_DROP_THRESHOLD      = -0.15

# ── GRUG v10: CURIOSITY ACCUMULATOR ────────────────────────────────────
# GRUG: Curiosity is passive — it accumulates from the same signals that
# feed evidence. When it overflows, the system asks a question autonomously.
const CURIOSITY_OVERFLOW_THRESHOLD  = 0.85
const CURIOSITY_COOLDOWN            = 300.0   # seconds after quench before next overflow
const CURIOSITY_PER_TOKEN           = 0.05    # intensity per uncovered token
const CURIOSITY_NOVELTY_WEIGHT      = 0.10    # novelty contribution to curiosity
const CURIOSITY_SEMANTIC_WEIGHT     = 0.08    # low-semantic contribution to curiosity

# ── GRUG v10: Deep MLP integration constants ──────────────────────────
const NOVELTY_SURGE_THRESHOLD    = 0.65   # novelty above this = surge (boost evidence)
const NOVELTY_SURGE_BOOST        = 0.35   # how much to boost evidence during novelty surge
const ACTIVATION_RELU_GROWTH_MULT = 1.25  # ReLU path (novel) multiplies growth evidence
const ACTIVATION_SIGMOID_GROWTH_MULT = 0.8  # sigmoid path (familiar) dampens growth evidence
const HASH_RARITY_FLOOR         = 3      # patterns seen fewer times than this = rare
const HASH_RARITY_BOOST         = 0.25   # boost for evidence when pattern is rare
const CORRELATION_QUALITY_BOOST = 0.20   # boost when input correlations are well-established

# GRUG: Stopwords for token extraction (same set as MitosisMode)
const STOPWORDS = Set([
    "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would", "could",
    "should", "may", "might", "must", "shall", "can", "need", "dare",
    "it", "its", "i", "me", "my", "we", "us", "our", "you", "your",
    "he", "him", "his", "she", "her", "they", "them", "their",
    "this", "that", "these", "those", "what", "which", "who", "whom",
    "when", "where", "why", "how", "all", "each", "every", "both",
    "few", "more", "most", "other", "some", "such", "no", "not",
    "only", "own", "same", "so", "than", "too", "very", "just",
    "because", "but", "and", "or", "if", "then", "else", "when",
    "up", "out", "in", "on", "at", "to", "for", "with", "from",
    "by", "about", "into", "through", "during", "before", "after",
    "above", "below", "between", "under", "again", "also", "now",
])

# ==============================================================================
# STATE — evidence accumulator + log + locks
# ==============================================================================

const _EVIDENCE = Dict{String, EvidenceRecord}()  # pattern -> record
const _EVIDENCE_LOCK = ReentrantLock()
const _LAST_DECAY = Ref{Float64}(time())
const _GROWTH_LOG = AutoGrowthStats[]
const _GROWTH_LOG_LOCK = ReentrantLock()
const _GROWTH_LOG_MAX = 100
const _CO_OCCUR_MAP = Dict{Tuple{String,String}, Int}()  # (word_a, word_b) -> count
const _CO_OCCUR_LOCK = ReentrantLock()

# GRUG v10: Curiosity accumulator state — stored in memory, not in evidence Dict.
# Curiosity is a separate channel that overflows into autonomous questions.
const _CURIOSITY_BUFFER    = Ref{Vector{String}}(String[])     # queued unknown patterns
const _CURIOSITY_INTENSITY = Ref{Float64}(0.0)                 # accumulated curiosity (0.0-1.0)
const _CURIOSITY_QUENCHED  = Ref{Float64}(0.0)                 # timestamp of last quench
const _CURIOSITY_OVERFLOW_COUNT = Ref{Int}(0)                  # total overflow events
const _CURIOSITY_LOCK      = ReentrantLock()

# ==============================================================================
# EVIDENCE ACCUMULATION — called every user message
# ==============================================================================

"""
    accumulate_evidence!(; kwargs...)

GRUG: Scan a user message for evidence of gaps in the cave's knowledge.
Every uncovered token, uncovered synonym, under-populated lobe, missing
sigil expansion — all of it feeds into the evidence accumulator. The
accumulator is a Dict keyed by candidate pattern, with mutable records
that track cumulative intensity and frequency.

This function is called from process_mission (active conversation path).
It does NOT grow anything. It just accumulates evidence. Growth happens
in maybe_grow_from_evidence! which is called separately.

Required kwargs:
  - user_text::String — the user's message text
  - intensity::Float64 — message intensity (from MESSAGE_HISTORY)
  - node_patterns::Set{String} — set of existing node patterns (lowercase, stripped)
  - node_ids_patterns::Vector{Tuple{String,String}} — (node_id, pattern) pairs
  - thesaurus_gate_filter::Function — word -> Vector{String}
  - thesaurus_word_similarity::Function — (word1, word2) -> Float64

Optional kwargs:
  - lobe_snapshots::Vector{Tuple{String,String,Set{String}}} — (lobe_id, subject, node_ids)
  - attachment_snapshots::Vector{Tuple{String,String,Bool}} — (target_id, connector, is_crystalized)
  - sigil_table_entries::Dict{String,Any} — sigil name -> entry dict (for gap detection)
  - strain_energy::Float64 — EphemeralMLP strain energy
  - hippocampal_warrant_active::Bool — SelfObserver confirmation
"""
function accumulate_evidence!(;
    user_text::String,
    intensity::Float64,
    node_patterns::Set{String},
    node_ids_patterns::Vector{Tuple{String,String}},
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    lobe_snapshots::Vector{Tuple{String,String,Set{String}}} = Tuple{String,String,Set{String}}[],
    attachment_snapshots::Vector{Tuple{String,String,Bool}} = Tuple{String,String,Bool}[],
    sigil_table_entries::Dict = Dict{String,Any}(),
    strain_energy::Float64 = 0.0,
    hippocampal_warrant_active::Bool = false,
    # ── GRUG v10: NEW EphemeralMLP head evidence sources ──
    mlp_semantic_score::Float64 = 0.5,
    mlp_relevance_score::Float64 = 0.5,
    mlp_disambiguation::Float64 = 0.5,
    coherence_delta_phi::Float64 = 0.0,
    observer_recurring_gap::Bool = false,
    observer_gap_pattern::String = "",
    # GRUG v10: Deep MLP integration kwargs
    mlp_novelty_score::Float64 = 0.5,
    mlp_activation_mode::Symbol = :sigmoid,
    mlp_hash_rarity::Float64 = 0.0,
    mlp_correlation_quality::Float64 = 0.5,
    # GRUG v7.58: Relational triple extraction for SOURCE 18
    extract_triples_fn::Union{Function,Nothing} = nothing,
    evaluate_dialectics_fn::Union{Function,Nothing} = nothing,
    node_map = nothing,
    node_lock = nothing,
    # GRUG v8.2: Lobe-qualified answer hint from "science: answer" prefix
    lobe_hint::String = "",
)
    isempty(strip(user_text)) && return nothing

    tokens = _tokenize(user_text)
    isempty(tokens) && return nothing

    t_now = time()

    # ── SOURCE 1: SILENCE MAP — uncovered tokens ──────────────────────
    # GRUG: Tokens in the user message that have NO coverage in existing
    # node patterns. Each uncovered token gets an evidence increment.
    for tok in tokens
        if !_is_covered(tok, node_patterns)
            _add_evidence!(tok, intensity, "silence_map", :match;
                          lobe_hint = _infer_lobe_from_token(tok))
        end
    end

    # ── SOURCE 2: THESAURUS GAP — uncovered synonyms ──────────────────
    # GRUG: For each covered token, check if its thesaurus synonyms are
    # also covered. Uncovered synonyms = gap evidence.
    for tok in tokens
        if _is_covered(tok, node_patterns)
            try
                expanded = thesaurus_gate_filter(tok)
                for syn in expanded
                    syn_lower = lowercase(strip(syn))
                    if !_is_covered(syn_lower, node_patterns) && length(syn_lower) > 2
                        _add_evidence!(syn_lower, intensity * 0.5, "thesaurus_gap", :match;
                                      lobe_hint = _infer_lobe_from_token(syn_lower))
                    end
                end
            catch
                # GRUG: Thesaurus errors non-fatal. Skip.
            end
        end
    end

    # ── SOURCE 3: LOBE COVERAGE — under-populated lobe domain tokens ──
    # GRUG: If the user mentions tokens that belong to an under-populated
    # lobe's subject but aren't in its whitelist, that's evidence.
    for (lobe_id, subject, node_ids) in lobe_snapshots
        subject_tokens = _tokenize(subject)
        overlap = intersect(Set(tokens), Set(subject_tokens))
        if !isempty(overlap) && length(node_ids) < 5
            # GRUG: Under-populated lobe with subject overlap.
            for tok in overlap
                if !_is_covered(tok, node_patterns)
                    _add_evidence!(tok, intensity * 0.3, "lobe_coverage", :match;
                                  lobe_hint = lobe_id)
                end
            end
            # GRUG: Also consider adding to whitelist
            for tok in tokens
                if length(tok) > 3 && !in(tok, STOPWORDS)
                    _add_evidence!("wl:$lobe_id:$tok", intensity * 0.2, "lobe_whitelist", :lobe_whitelist;
                                  lobe_hint = lobe_id)
                end
            end
        end
    end

    # ── SOURCE 4: ATTACHMENT IMPLICATION — crystalized connectors ──────
    for (_, connector, is_crystalized) in attachment_snapshots
        if is_crystalized && length(connector) > 3
            conn_lower = lowercase(strip(connector))
            if !_is_covered(conn_lower, node_patterns)
                _add_evidence!(conn_lower, DEFAULT_INTENSITY_INCREMENT, "attachment", :match;
                              lobe_hint = _infer_lobe_from_token(conn_lower))
            end
        end
    end

    # ── SOURCE 5: STRAIN — internal hurt ───────────────────────────────
    # GRUG: When the system hurts from novel input, the ENTIRE input
    # pattern gets evidence. Not individual tokens — the full pattern.
    # This is because strain means the system can't handle WHAT IT SAW,
    # not just individual words.
    if hippocampal_warrant_active && strain_energy > 0.55
        full_pattern = _extract_activator_verb_pattern(user_text)
        if !isempty(strip(full_pattern)) && length(full_pattern) > 2
            if !_is_covered(lowercase(full_pattern), node_patterns)
                _add_evidence!(lowercase(full_pattern), strain_energy * 0.7, "strain", :match;
                              lobe_hint = _infer_lobe_from_token(full_pattern))
            end
        end
    end

    # ── SOURCE 6: TIME NODE GAP — temporal orientation keywords ────────
    # GRUG: When the user uses temporal keywords frequently and there's
    # no time node covering them, that's evidence for a time node.
    time_toks = filter(t -> in(t, TIME_NODE_KEYWORDS), tokens)
    if !isempty(time_toks)
        has_time_coverage = any(occursin("time_node", pat) for pat in node_patterns)
        if !has_time_coverage
            for tt in time_toks
                _add_evidence!("time:$tt", intensity * 0.4, "time_gap", :time;
                              lobe_hint = "default")
            end
        end
    end

    # ── SOURCE 7: SIGIL GAP — patterns referencing sigils with no expansion ──
    # GRUG: If the user's text contains words that match sigil names but
    # the sigil has no expansion (empty lexicon), that's evidence for
    # growing a sigil expansion entry. The &noun sigils especially.
    for (sig_name, sig_entry) in sigil_table_entries
        if occursin(sig_name, lowercase(user_text))
            # GRUG: Check if sigil has expansion/lexicon
            has_expansion = false
            try
                if haskey(sig_entry, :lexicon) && !isnothing(sig_entry[:lexicon]) && !isempty(sig_entry[:lexicon])
                    has_expansion = true
                end
                if haskey(sig_entry, :expansion) && !isnothing(sig_entry[:expansion]) && !isempty(sig_entry[:expansion])
                    has_expansion = true
                end
                if isa(sig_entry, AbstractDict)
                    if haskey(sig_entry, "lexicon") && !isnothing(sig_entry["lexicon"]) && !isempty(sig_entry["lexicon"])
                        has_expansion = true
                    end
                    if haskey(sig_entry, "expansion") && !isnothing(sig_entry["expansion"]) && !isempty(sig_entry["expansion"])
                        has_expansion = true
                    end
                end
            catch; end
            if !has_expansion
                _add_evidence!("sigil:$sig_name", intensity * 0.3, "sigil_gap", :sigil;
                              lobe_hint = "default")
            end
        end
    end

    # ── SOURCE 8: CO-OCCURRENCE — for thesaurus pair discovery ─────────
    # GRUG: Track which non-stopword tokens co-occur in the same user message.
    # Pairs that co-occur frequently and have some trigram similarity are
    # candidates for auto-thesaurus registration. This feeds the thesaurus
    # gap evidence source in future cycles.
    content_tokens = filter(t -> length(t) > 3 && !in(t, STOPWORDS), tokens)
    if length(content_tokens) >= 2
        lock(_CO_OCCUR_LOCK) do
            for i in 1:length(content_tokens)-1
                for j in i+1:length(content_tokens)
                    a, b = content_tokens[i], content_tokens[j]
                    if a != b
                        key = a < b ? (a, b) : (b, a)
                        _CO_OCCUR_MAP[key] = get(_CO_OCCUR_MAP, key, 0) + 1
                    end
                end
            end
        end
    end


    # ── SOURCE 9: SEMANTIC COHERENCE GAP ──────────────────────────────────
    # GRUG v10: When EphemeralMLP reports low semantic_score, the brain
    # can't find semantically coherent matches. Stronger than mere silence.
    if mlp_semantic_score < SEMANTIC_GAP_THRESHOLD && intensity > 0.5
        semantic_deficit = 1.0 - mlp_semantic_score
        for tok in tokens
            if !_is_covered(tok, node_patterns) && length(tok) > 2 && !in(tok, STOPWORDS)
                _add_evidence!(tok, intensity * semantic_deficit * 0.4, "semantic_gap", :match;
                              lobe_hint = _infer_lobe_from_token(tok))
            end
        end
    end

    # ── SOURCE 10: RELEVANCE DROPOUT ──────────────────────────────────────
    # GRUG v10: Low relevance_score means responses aren't relevant.
    # Often means thesaurus is incomplete - missing synonym connections.
    if mlp_relevance_score < RELEVANCE_DROPOUT_THRESHOLD
        relevance_deficit = 1.0 - mlp_relevance_score
        for tok in tokens
            if _is_covered(tok, node_patterns)
                try
                    expanded = thesaurus_gate_filter(tok)
                    for syn in expanded
                        syn_lower = lowercase(strip(syn))
                        if !_is_covered(syn_lower, node_patterns) && length(syn_lower) > 2
                            _add_evidence!(syn_lower, intensity * relevance_deficit * 0.3,
                                          "relevance_dropout", :thesaurus;
                                          lobe_hint = _infer_lobe_from_token(syn_lower))
                        end
                    end
                catch; end
            end
        end
    end

    # ── SOURCE 11: DISAMBIGUATION PRESSURE ─────────────────────────────────
    # GRUG v10: High disambiguation means the brain sees ambiguity it
    # can't resolve. New sigil entries and patterns provide resolution.
    if mlp_disambiguation > DISAMBIGUATION_PRESSURE_THRESHOLD
        for (sig_name, _) in sigil_table_entries
            if occursin(sig_name, lowercase(user_text))
                _add_evidence!("sigil:$sig_name", intensity * mlp_disambiguation * 0.3,
                              "disambiguation_pressure", :sigil;
                              lobe_hint = "default")
            end
        end
        full_pattern = _extract_activator_verb_pattern(user_text)
        if !isempty(strip(full_pattern)) && length(full_pattern) > 2
            if !_is_covered(lowercase(full_pattern), node_patterns)
                _add_evidence!(lowercase(full_pattern), mlp_disambiguation * 0.25,
                              "disambiguation_pressure", :match;
                              lobe_hint = _infer_lobe_from_token(full_pattern))
            end
        end
    end

    # ── SOURCE 12: COHERENCE FIELD DELTA ──────────────────────────────────
    # GRUG v10: Large negative dPhi means coherence dropping. Growth fills gaps.
    if coherence_delta_phi < COHERENCE_DROP_THRESHOLD
        coherence_magnitude = abs(coherence_delta_phi)
        for tok in tokens
            if !_is_covered(tok, node_patterns) && length(tok) > 2 && !in(tok, STOPWORDS)
                _add_evidence!(tok, coherence_magnitude * 0.5 * intensity,
                              "coherence_drop", :match;
                              lobe_hint = _infer_lobe_from_token(tok))
            end
        end
    end

    # ── SOURCE 13: SELF-OBSERVER PATTERN ───────────────────────────────────
    # GRUG v10: SelfObserver recurring gap = independent validation signal.
    if observer_recurring_gap && !isempty(observer_gap_pattern)
        _add_evidence!(lowercase(strip(observer_gap_pattern)), intensity * 0.5,
                      "observer_pattern", :match;
                      lobe_hint = _infer_lobe_from_token(observer_gap_pattern))
    end

    # ── SOURCE 14: NOVELTY SURGE ── high novelty boosts ALL evidence ──────
    # GRUG v10: When EphemeralMLP novelty_score is high, the brain is seeing
    # unfamiliar territory. This doesn't add NEW evidence entries - it MODULATES
    # the intensity of evidence that was just added. High novelty = "I don't know
    # what I'm looking at" = more aggressive growth. The intensity boost is
    # proportional to how novel the input is above the threshold.
    if mlp_novelty_score > NOVELTY_SURGE_THRESHOLD
        surge_boost = NOVELTY_SURGE_BOOST * (mlp_novelty_score - NOVELTY_SURGE_THRESHOLD) / (1.0 - NOVELTY_SURGE_THRESHOLD)
        # GRUG: Apply boost to ALL evidence entries from THIS cycle.
        # We do this by bumping the intensity of recent evidence entries.
        lock(_EVIDENCE_LOCK) do
            for (key, entry) in _EVIDENCE
                if t_now - entry.last_seen < 2.0  # GRUG: Only entries from this cycle
                    _EVIDENCE[key] = EvidenceRecord(
                        entry.pattern,
                        entry.accumulated_intensity + surge_boost * entry.accumulated_intensity,
                        entry.frequency,
                        entry.sources,
                        t_now,  # refresh last_seen
                        entry.first_seen,
                        entry.growth_type,
                        entry.lobe_hint,
                        entry.user_triples  # GRUG v7.58: preserve relational triples
                    )
                end
            end
        end
    end

    # ── SOURCE 15: ACTIVATION MODE BIAS ── ReLU vs sigmoid modulates growth urgency ──
    # GRUG v10: The MLP's activation mode tells us HOW it processed this input.
    # ReLU path = novel/exploratory = brain is in learning mode = growth is more
    # urgent. Sigmoid path = familiar/refinement = brain is in consolidation mode
    # = growth is less urgent. This modifies the intensity of evidence entries
    # from THIS cycle, similar to SOURCE 14 but based on activation mode.
    activation_mult = if mlp_activation_mode == :relu
        ACTIVATION_RELU_GROWTH_MULT
    else
        ACTIVATION_SIGMOID_GROWTH_MULT
    end
    if activation_mult != 1.0
        lock(_EVIDENCE_LOCK) do
            for (key, entry) in _EVIDENCE
                if t_now - entry.last_seen < 2.0  # GRUG: Only entries from this cycle
                    delta = (activation_mult - 1.0) * entry.accumulated_intensity
                    _EVIDENCE[key] = EvidenceRecord(
                        entry.pattern,
                        max(0.0, entry.accumulated_intensity + delta),
                        entry.frequency,
                        entry.sources,
                        entry.last_seen,
                        entry.first_seen,
                        entry.growth_type,
                        entry.lobe_hint,
                        entry.user_triples  # GRUG v7.58: preserve relational triples
                    )
                end
            end
        end
    end

    # ── SOURCE 16: PATTERN FREQUENCY (NOVELTY TRACKER HASH RARITY) ──────
    # GRUG v10: The novelty_tracker's hash_counts tell us how many times each
    # input pattern hash has been seen. The mlp_hash_rarity stat (computed in
    # Main.jl from get_novelty_tracker_stats) represents what fraction of known
    # hashes are rare (seen fewer than HASH_RARITY_FLOOR times). When many
    # patterns are rare, the brain is in exploration mode and evidence for
    # uncovered tokens should be boosted. Rare patterns = more growth.
    if mlp_hash_rarity > 0.3
        rarity_boost = HASH_RARITY_BOOST * mlp_hash_rarity
        for tok in tokens
            if !_is_covered(tok, node_patterns) && length(tok) > 2 && !in(tok, STOPWORDS)
                _add_evidence!(tok, rarity_boost * intensity, "hash_rarity", :match;
                              lobe_hint = _infer_lobe_from_token(tok))
            end
        end
    end

    # ── SOURCE 17: INPUT CORRELATION QUALITY BOOST ──────────────────────
    # GRUG v10: When the MLP has well-established input-quality correlations
    # (high mean_quality_ema), the brain knows its existing knowledge well.
    # Gaps in well-established knowledge are MORE significant than gaps in
    # uncharted territory. If correlation quality is high AND there are still
    # uncovered tokens, those gaps are REAL unknowns, not just noise.
    # This boosts evidence for thesaurus gap discovery when the brain has
    # enough correlation data to trust its own gap detection.
    if mlp_correlation_quality > 0.6
        quality_boost = CORRELATION_QUALITY_BOOST * (mlp_correlation_quality - 0.5) / 0.5
        for tok in tokens
            if _is_covered(tok, node_patterns)
                try
                    expanded = thesaurus_gate_filter(tok)
                    for syn in expanded
                        syn_lower = lowercase(strip(syn))
                        if !_is_covered(syn_lower, node_patterns) && length(syn_lower) > 2
                            _add_evidence!(syn_lower, intensity * quality_boost * 0.3,
                                          "correlation_quality_boost", :thesaurus;
                                          lobe_hint = _infer_lobe_from_token(syn_lower))
                        end
                    end
                catch; end
            end
        end
    end


    # ── SOURCE 18: RELATIONAL TRIPLE GAP ────────────────────────────────
    # GRUG v7.58: Dynamic sigil relationals for AutoGrowth. When the user's
    # input produces relational triples that don't match ANY existing node's
    # relational_patterns, that's strong evidence for a new node that WOULD
    # match those triples. This is the "obvious" thing — the user is telling
    # us about a RELATION (fire makes warmth, water gives life), and if no
    # node captures that relation, we need one.
    #
    # How it works:
    #   1. Extract triples from user input via extract_triples_fn
    #   2. For each triple, scan ALL existing nodes for a relational match
    #   3. If NO node matches a triple → that triple's subject/object are gaps
    #   4. Accumulate evidence for those gap tokens WITH the user triple attached
    #   5. At growth time, the stored triple becomes the new node's relational_patterns
    #
    # This works for ALL growth types:
    #   - :match nodes get relational_patterns for disambiguation
    #   - :time nodes get &temporal relational anchoring
    #   - :aiml nodes get relational context for template selection
    #   - :antimatch nodes — REMOVED v8.26h. Antimatch nodes no longer exist.
    #   - :sigil growth uses relational context for expansion discovery
    #   - :thesaurus pairs are discovered from co-occurrence IN relational context
    #   - :lobe_whitelist entries gain relational fingerprints
    #   - :flashcard entries anchor to arithmetic relations
    if extract_triples_fn !== nothing && node_map !== nothing && node_lock !== nothing
        try
            user_triples = extract_triples_fn(user_text)
            if !isempty(user_triples)
                for ut in user_triples
                    ut_subj = lowercase(strip(ut.relation === nothing ? string(ut[1]) : ut.subject))
                    ut_rel  = lowercase(strip(ut.relation === nothing ? string(ut[2]) : ut.relation))
                    ut_obj  = lowercase(strip(ut.relation === nothing ? string(ut[3]) : ut.object))

                    # GRUG: Skip triples with stopword components
                    (ut_subj in STOPWORDS || ut_rel in STOPWORDS || ut_obj in STOPWORDS) && continue
                    (length(ut_subj) < 2 || length(ut_obj) < 2) && continue

                    # GRUG: Check if ANY existing node matches this triple
                    matched_any = false
                    if evaluate_dialectics_fn !== nothing
                        lock(node_lock) do
                            for (_, node) in node_map
                                node.is_grave && continue
                                if !isempty(node.relational_patterns)
                                    try
                                        (score, is_anti) = evaluate_dialectics_fn(
                                            [ut],  # user triple as single-element vector
                                            node.relational_patterns,
                                            node.required_relations,
                                            node.relation_weights
                                        )
                                        # GRUG: Positive score = some node already captures this relation
                                        # -9999.0 sentinel = hard miss, is_anti = antimatch
                                        if score > RELATIONAL_GAP_SCORE_FLOOR && !is_anti
                                            matched_any = true
                                            break
                                        end
                                    catch
                                        # GRUG: evaluation error = can't confirm match, keep checking
                                        continue
                                    end
                                end
                            end
                        end
                    end

                    if !matched_any
                        # GRUG: This triple is UNMATCHED — evidence for both subject and object
                        triple_tuple = (ut_subj, ut_rel, ut_obj)

                        # GRUG: Subject token as gap evidence
                        if !_is_covered(ut_subj, node_patterns) && length(ut_subj) > 2
                            _add_evidence!(ut_subj, intensity * 0.6, "relational_gap", :match;
                                          lobe_hint = _infer_lobe_from_token(ut_subj),
                                          user_triples = [triple_tuple])
                        end

                        # GRUG: Object token as gap evidence
                        if !_is_covered(ut_obj, node_patterns) && length(ut_obj) > 2
                            _add_evidence!(ut_obj, intensity * 0.6, "relational_gap", :match;
                                          lobe_hint = _infer_lobe_from_token(ut_obj),
                                          user_triples = [triple_tuple])
                        end

                        # GRUG: Full "subj rel obj" pattern as higher-order gap
                        full_pat = "$(ut_subj) $(ut_rel) $(ut_obj)"
                        if !_is_covered(lowercase(full_pat), node_patterns) && length(full_pat) > 5
                            _add_evidence!(lowercase(full_pat), intensity * 0.4, "relational_gap", :match;
                                          lobe_hint = _infer_lobe_from_token(ut_subj),
                                          user_triples = [triple_tuple])
                        end
                    end
                end
            end
        catch
            # GRUG: SOURCE 18 is non-fatal. If triple extraction or evaluation
            # fails, the other 17 sources still work fine.
        end
    end



    # ── SOURCE 19: INVERSE SIGIL MAGNET — shape-cluster density ──────────────
    # GRUG v8.2: The inverse sigil list clusters uncovered tokens by sigil shape.
    # Instead of treating each uncovered token as an unrelated atom (SOURCE 1),
    # this groups them: "cat" and "dog" are both concretes under &noun, so they
    # produce a COMBINED signal stronger than two unrelated atoms would.
    #
    # How it works:
    #   1. Call InverseSigil.feed_evidence!() which scans user text for tokens
    #      that match sigil shapes and clusters uncovered tokens by shape.
    #   2. feed_evidence!() returns a list of (pattern, intensity_bonus, source,
    #      growth_type, route) tuples.
    #   3. For each tuple, add evidence to the accumulator with the magnet's bonus.
    #   4. The magnet bonus is STRONGER than plain SOURCE 1 because it reflects
    #      shape-cluster density — related observations are grouped, not scattered.
    #   5. Petty growth routes (sigil lexicon entries, verb registrations) are
    #      dispatched at growth time, not accumulation time.
    #
    # This is the KEY insight: the inverse sigil list acts as a GROWTH MAGNET.
    # More concretes under a sigil shape = stronger pull toward growth.
    try
        inv_results = InverseSigil.feed_evidence!(;
            sigil_table_entries = sigil_table_entries,
            user_text = user_text,
            node_patterns = node_patterns,
            intensity = intensity,
            lobe_hint = lobe_hint,
        )
        if !isempty(inv_results)
            for result in inv_results
                # GRUG v8.2: Prefer explicit lobe prefix ("science: answer") over inference
                _lobe = isempty(result.lobe_hint) ? _infer_lobe_from_token(result.pattern) : result.lobe_hint
                _add_evidence!(result.pattern, result.intensity_bonus,
                              result.source, result.growth_type;
                              lobe_hint = _lobe)
            end
        end
    catch
        # GRUG: SOURCE 19 is non-fatal. If the inverse sigil magnet fails,
        # the other 18 sources still work fine.
    end


    # ── CURIOSITY ACCUMULATION ─────────────────────────────────────────────
    # GRUG v10: Feed curiosity accumulator. Separate channel that overflows
    # into autonomous questions. Doesn't grow nodes - asks the USER.
    lock(_CURIOSITY_LOCK) do
        n_uncovered = count(t -> !_is_covered(t, node_patterns) && length(t) > 2 && !in(t, STOPWORDS), tokens)
        _CURIOSITY_INTENSITY[] = clamp(
            _CURIOSITY_INTENSITY[] + n_uncovered * CURIOSITY_PER_TOKEN,
            0.0, 1.0
        )
        if strain_energy > 0.55
            _CURIOSITY_INTENSITY[] = clamp(
                _CURIOSITY_INTENSITY[] + strain_energy * CURIOSITY_NOVELTY_WEIGHT,
                0.0, 1.0
            )
        end
        if mlp_semantic_score < SEMANTIC_GAP_THRESHOLD
            _CURIOSITY_INTENSITY[] = clamp(
                _CURIOSITY_INTENSITY[] + (1.0 - mlp_semantic_score) * CURIOSITY_SEMANTIC_WEIGHT,
                0.0, 1.0
            )
        end
        # GRUG v10: Deep MLP — novelty also feeds curiosity. Novel input = curious.
        if mlp_novelty_score > NOVELTY_SURGE_THRESHOLD
            _CURIOSITY_INTENSITY[] = clamp(
                _CURIOSITY_INTENSITY[] + mlp_novelty_score * 0.06,
                0.0, 1.0
            )
        end
        for tok in tokens
            if !_is_covered(tok, node_patterns) && length(tok) > 2 && !in(tok, STOPWORDS)
                tok_lower = lowercase(strip(tok))
                if !(tok_lower in _CURIOSITY_BUFFER[])
                    push!(_CURIOSITY_BUFFER[], tok_lower)
                end
            end
        end
    end

    # ── DECAY — expire stale evidence ──────────────────────────────────
    # GRUG: Decay evidence periodically, not every call (too expensive).
    # Every EVIDENCE_DECAY_INTERVAL seconds, halve all accumulated intensities.
    lock(_EVIDENCE_LOCK) do
        if t_now - _LAST_DECAY[] > EVIDENCE_DECAY_INTERVAL
            _decay_evidence!(t_now)
            _LAST_DECAY[] = t_now
        end
    end

    # ── CAP — evict oldest entries if over cap ─────────────────────────
    lock(_EVIDENCE_LOCK) do
        while length(_EVIDENCE) > EVIDENCE_CAP
            # GRUG: Evict the entry with the OLDEST last_seen time.
            # Stale evidence goes first. Fresh evidence stays.
            oldest_key = ""
            oldest_time = Inf
            for (k, v) in _EVIDENCE
                if v.last_seen < oldest_time
                    oldest_time = v.last_seen
                    oldest_key = k
                end
            end
            !isempty(oldest_key) && delete!(_EVIDENCE, oldest_key)
        end
    end

    return nothing
end

# ==============================================================================
# EVIDENCE GROWTH — coinflip biased by accumulated evidence
# ==============================================================================

"""
    maybe_grow_from_evidence!(; kwargs...) -> Union{AutoGrowthStats, Nothing}

GRUG: Check accumulated evidence and maybe grow something. The coinflip
is biased by evidence intensity: more evidence = higher probability.
Only ONE growth per call (one per conversation turn). If the coinflip
doesn't land, nothing happens. If it does, the system grows whatever
has the strongest evidence.

This is called from process_mission AFTER the scan/response is done,
so it doesn't slow down the response pipeline. Growth is background work.

Required kwargs:
  - node_map, node_lock: the live NODE_MAP and its lock
  - create_node_fn: (pattern, action_packet, data, drop_table; initial_strength, is_image_node, is_antimatch_node) -> String
  - add_to_group_fn: (group, node_id) -> Bool
  - register_group_fn: (node) -> NodeGroup
  - group_map, group_lock: GROUP_MAP and lock
  - lobe_registry: LOBE_REGISTRY dict
  - immune_gate_fn: (pattern, data) -> Bool
  - thesaurus_gate_filter::Function
  - thesaurus_word_similarity::Function

Optional kwargs:
  - add_lobe_whitelist_fn: (lobe_id, token) -> Int — add to lobe whitelist
  - register_sigil_fn: (sigil_name, expansion_entries) -> Bool — register sigil expansion
  - register_thesaurus_pair_fn: (word_a, word_b) -> Bool — register synonym pair
  - stochastic_aiml_growth_fn: (lobe_id, hint_pattern; data_warrant) -> Union{AIMLNode, Nothing}
  - group_latch_fn: (pattern; node_map, node_lock, requesting_node_is_time) -> Vector{GroupLatchCandidate}
  - link_to_group_member_fn: (new_node, group) -> Union{String, Nothing}
  - group_avg_strength_fn: (group; node_map, node_lock) -> Float64
  - group_for_fn: (node_id) -> Union{NodeGroup, Nothing}
  - sigil_promote_fn: (text) -> String
  - extract_triples_fn: (text) -> Vector{RelationalTriple}
  - evaluate_dialectics_fn: (user_triples, node_triples, req_rels, rel_weights) -> (Float64, Bool)
  - words_to_signal_fn: (text) -> Vector{Float64}
  - scan_latch_candidates_fn: (pattern, action_packet; node_map, node_lock, lobe_id, thesaurus_fn, ...) -> Vector{LatchCandidate}
"""
function maybe_grow_from_evidence!(;
    node_map,
    node_lock,
    create_node_fn::Function,
    add_to_group_fn,
    register_group_fn,
    group_map,
    group_lock,
    lobe_registry = Dict{String,Any}(),
    immune_gate_fn = nothing,
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    thesaurus_synonym_lookup::Union{Function,Nothing} = nothing,  # GRUG v8.2: seed-aware synonym check for concept dedup
    add_lobe_whitelist_fn = nothing,
    register_sigil_fn = nothing,
    register_thesaurus_pair_fn = nothing,
    stochastic_aiml_growth_fn = nothing,
    group_latch_fn = nothing,
    link_to_group_member_fn = nothing,
    group_avg_strength_fn = nothing,
    group_for_fn = nothing,
    sigil_promote_fn = nothing,
    extract_triples_fn = nothing,
    evaluate_dialectics_fn = nothing,
    words_to_signal_fn = nothing,
    scan_latch_candidates_fn = nothing,
    # GRUG v7.58: Relational sigil integration — verb→sigil reverse mapping + user text
    verb_class_of_fn::Union{Function,Nothing} = nothing,
    user_text::String = "",
    sigil_table::Union{Any,Nothing} = nothing,
    # GRUG v10: Deep MLP integration — rule hints for growth type suggestion
    mlp_rule_hints::Vector{Dict{String, Any}} = Dict{String, Any}[],
)::Union{AutoGrowthStats, Nothing}
    t0 = time()

    # ── POPULATION CAP ─────────────────────────────────────────────────
    alive_count = lock(node_lock) do
        count(n -> !n.is_grave, values(node_map))
    end
    if alive_count >= POPULATION_CAP
        return nothing
    end

    # ── FIND STRONGEST EVIDENCE ────────────────────────────────────────
    # GRUG: Pick the candidate with the highest accumulated intensity
    # that also passes the evidence floor and frequency floor.
    # Only ONE candidate per turn. The strongest wins.
    best_key = ""
    best_record = nothing
    best_score = 0.0

    lock(_EVIDENCE_LOCK) do
        for (key, rec) in _EVIDENCE
            # GRUG: Evidence must pass BOTH floor checks.
            if rec.accumulated_intensity < EVIDENCE_FLOOR
                continue
            end
            if rec.frequency < EVIDENCE_FREQUENCY_FLOOR
                continue
            end
            # GRUG: Score = accumulated_intensity (simple, effective).
            # Could also factor in source diversity or recency, but
            # intensity already captures the essential signal.
            score = rec.accumulated_intensity
            if score > best_score
                best_score = score
                best_key = key
                best_record = rec
            end
        end
    end

    if best_record === nothing
        return nothing  # No evidence above floor
    end

    # ── COINFLIP — biased by evidence intensity ────────────────────────
    # GRUG: p_grow = min(intensity / EVIDENCE_SCALE, GROWTH_COINFLIP_CAP)
    # At EVIDENCE_SCALE=8 and GROWTH_COINFLIP_CAP=0.25:
    #   intensity=2.0 → p=0.0625 (6.25% — just above floor, unlikely)
    #   intensity=4.0 → p=0.125  (12.5% — moderate evidence)
    #   intensity=8.0 → p=0.25   (25% — strong evidence, cap hit)
    #   intensity=12+ → p=0.25   (25% — capped, no higher)
    p_grow = min(best_record.accumulated_intensity / EVIDENCE_SCALE, GROWTH_COINFLIP_CAP)

    # GRUG: Adjust rate by growth type. AIML nodes now no-op (v8.12).
    # Antimatch nodes at 1/10 rate. These are heavier/riskier.
    # Sigil voter nodes at 1/2 rate (NOCHAT singleton, specialized).
    # Inverse voter nodes at full rate (magnet evidence already gives bonus).
    if best_record.growth_type == :aiml
        # GRUG v8.12: AIMLNodeSystem removed — :aiml growth is no-op now.
        # Still consume the growth_type so it doesn't fall through.
    elseif best_record.growth_type == :antimatch
        p_grow *= ANTIMATCH_GROWTH_RATE
    elseif best_record.growth_type == :lobe_whitelist
        p_grow = min(p_grow * LOBE_WHITELIST_GROWTH_RATE, GROWTH_COINFLIP_CAP)
    elseif best_record.growth_type == :flashcard
        p_grow = min(p_grow * FLASHCARD_GROWTH_RATE, GROWTH_COINFLIP_CAP)
    elseif best_record.growth_type == :sigil_voter_node
        p_grow *= SIGIL_VOTER_GROWTH_RATE
    elseif best_record.growth_type == :inverse_voter_node
        p_grow *= INVERSE_VOTER_GROWTH_RATE
    end

    won_coinflip = rand() < p_grow

    if !won_coinflip
        # GRUG: Coinflip lost. Record the near-miss for diagnostics.
        stats = AutoGrowthStats(
            best_record.pattern,
            string(best_record.growth_type),
            best_record.accumulated_intensity,
            best_record.frequency,
            p_grow,
            false,  # didn't win
            "",
            best_record.lobe_hint,
            join(best_record.sources, ","),
            "Coinflip lost (p=$(round(p_grow, digits=3)))",
            (time() - t0) * 1000,
        )
        _log_growth!(stats)
        return stats
    end

    # ── GROW! ──────────────────────────────────────────────────────────
    # GRUG: The coinflip landed. Time to grow something.
    # Branch by growth_type — each type has its own growth logic.

    pattern = best_record.pattern
    growth_type = best_record.growth_type
    lobe_hint = best_record.lobe_hint
    new_id = ""
    notes = ""

    # ── GRUG v8.2: CONCEPT DEDUP GUARD ──────────────────────────────────────
    # Before growing ANY node, check if an existing node already covers the
    # same concept. The thesaurus knows that "big" and "large" are synonyms,
    # so if a node for "big" exists, growing another for "large" is a waste.
    # This guard uses both synonym_lookup (seed-aware, exact synonym matches)
    # and word_similarity (trigram Jaccard for fuzzy matches).
    # ─────────────────────────────────────────────────────────────────────────
    if growth_type in (:match, :time, :antimatch, :sigil_voter_node, :inverse_voter_node)
        # GRUG v8.2: Use synonym_lookup (seed-aware) for dedup when available.
        # synonym_lookup catches "big"/"large" (0.95) where word_similarity misses (0.0).
        # Falls back to word_similarity (trigram Jaccard) when no synonym_lookup provided.
        _dedup_sim_fn = thesaurus_synonym_lookup !== nothing ? thesaurus_synonym_lookup : thesaurus_word_similarity
        _dedup_blocked = _is_concept_duplicate(pattern, node_map, node_lock;
                                                thesaurus_word_similarity = _dedup_sim_fn)
        if _dedup_blocked
            stats = AutoGrowthStats(
                pattern,
                string(growth_type),
                best_record.accumulated_intensity,
                best_record.frequency,
                p_grow,
                false,
                "",
                lobe_hint,
                join(best_record.sources, ","),
                "Concept dedup: '$pattern' already covered by existing node",
                (time() - t0) * 1000,
            )
            _log_growth!(stats)
            # GRUG: Remove the evidence — it's not a real gap, just a synonym.
            lock(_EVIDENCE_LOCK) do
                delete!(_EVIDENCE, best_key)
            end
            return stats
        end
    end

    # ── GRUG v10: MLP RULE HINT INFLUENCE ──────────────────────────
    # When the best evidence has generic growth_type=:match, MLP rules
    # can suggest a more specific type. Rules that fire with :solid
    # transform_type mean the pattern is well-established but incomplete
    # → upgrade to :thesaurus. Rules with :fuzzy mean uncertain → keep
    # :match. Rules with payload["suggest_growth_type"] override directly.
    if growth_type == :match && !isempty(mlp_rule_hints)
        for hint in mlp_rule_hints
            tt = get(hint, "transform_type", "")
            payload = get(hint, "payload", Dict{String,Any}())
            # GRUG: Direct hint from rule payload takes priority
            if haskey(payload, "suggest_growth_type")
                suggested = Symbol(payload["suggest_growth_type"])
                if suggested in (:thesaurus, :sigil, :lobe_whitelist, :flashcard, :time)
                    growth_type = suggested
                    notes = "MLP rule hint: $(get(hint, "rule_id", "?")) suggested :$(suggested)"
                    break
                end
            end
            # GRUG: Solid rules = well-established pattern, upgrade to thesaurus
            if tt == "solid" && get(hint, "fire_count", 0) >= 3
                growth_type = :thesaurus
                notes = "MLP rule hint: solid rule $(get(hint, "rule_id", "?")) (fired $(get(hint, "fire_count", 0))x) suggests thesaurus"
                break
            end
        end
    end

    if growth_type == :match || growth_type == :time || growth_type == :antimatch
        # ── MATCH / TIME / ANTIMATCH NODE GROWTH ───────────────────────
        new_id, notes = _grow_node!(
            pattern, growth_type, lobe_hint;
            node_map=node_map,
            node_lock=node_lock,
            create_node_fn=create_node_fn,
            add_to_group_fn=add_to_group_fn,
            register_group_fn=register_group_fn,
            group_map=group_map,
            group_lock=group_lock,
            lobe_registry=lobe_registry,
            immune_gate_fn=immune_gate_fn,
            thesaurus_word_similarity=thesaurus_word_similarity,
            group_latch_fn=group_latch_fn,
            link_to_group_member_fn=link_to_group_member_fn,
            group_avg_strength_fn=group_avg_strength_fn,
            group_for_fn=group_for_fn,
            sigil_promote_fn=sigil_promote_fn,
            extract_triples_fn=extract_triples_fn,
            evaluate_dialectics_fn=evaluate_dialectics_fn,
            words_to_signal_fn=words_to_signal_fn,
            scan_latch_candidates_fn=scan_latch_candidates_fn,
            # GRUG v7.58: Pass relational sigil integration through to _grow_node!
            user_text=user_text,
            user_triples_from_evidence=best_record.user_triples,
            verb_class_of_fn=verb_class_of_fn,
            sigil_table=sigil_table,
        )

    elseif growth_type == :aiml
        # ── AIML NODE GROWTH — NO-OP since v8.12 ──────────────────────────
        # GRUG: AIMLNodeSystem removed in v8.12. The :aiml growth_type is kept
        # in the enum for specimen backward-compat but does nothing at runtime.
        notes = "AIML growth: no-op (AIMLNodeSystem removed v8.12)"

    elseif growth_type == :sigil
        # ── SIGIL EXPANSION GROWTH ──────────────────────────────────────
        # GRUG: Pattern is "sigil:sigil_name". Register expansion entries.
        sig_name = replace(pattern, r"^sigil:" => "")
        if register_sigil_fn !== nothing
            try
                # GRUG: Auto-discover expansion from co-occurrence data.
                # Words that co-occur frequently with this sigil's domain
                # become expansion candidates. Minimal but functional.
                expansion_entries = _discover_sigil_expansion(sig_name, thesaurus_gate_filter)
                if !isempty(expansion_entries)
                    success = register_sigil_fn(sig_name, expansion_entries)
                    new_id = success ? "sigil:$sig_name" : ""
                    notes = "Sigil expansion for '&$sig_name': $(join(expansion_entries, ","))"
                else
                    notes = "No expansion candidates found for sigil '&$sig_name'"
                end
            catch e
                notes = "Sigil growth failed: $e"
            end
        else
            notes = "Sigil growth: no register_sigil_fn provided"
        end

    elseif growth_type == :thesaurus
        # ── THESAURUS PAIR GROWTH ───────────────────────────────────────
        # GRUG: Pattern is "thes:word_a:word_b". Register synonym pair.
        parts = split(pattern, ":")
        if length(parts) >= 3
            word_a, word_b = parts[2], parts[3]
            if register_thesaurus_pair_fn !== nothing
                try
                    success = register_thesaurus_pair_fn(word_a, word_b)
                    new_id = success ? "thes:$word_a:$word_b" : ""
                    notes = "Thesaurus pair: $word_a ↔ $word_b"
                catch e
                    notes = "Thesaurus pair failed: $e"
                end
            else
                notes = "Thesaurus pair: no register_thesaurus_pair_fn provided"
            end
        end

    elseif growth_type == :lobe_whitelist
        # ── LOBE WHITELIST GROWTH ────────────────────────────────────────
        # GRUG: Pattern is "wl:lobe_id:token". Add token to lobe's whitelist.
        parts = split(pattern, ":")
        if length(parts) >= 3
            wl_lobe_id, wl_token = parts[2], parts[3]
            if add_lobe_whitelist_fn !== nothing
                try
                    count = add_lobe_whitelist_fn(wl_lobe_id, wl_token)
                    new_id = "wl:$wl_lobe_id:$wl_token"
                    notes = "Whitelist: $wl_token → $wl_lobe_id (now $count entries)"
                catch e
                    notes = "Whitelist growth failed: $e"
                end
            else
                notes = "Whitelist growth: no add_lobe_whitelist_fn provided"
            end
        end
    elseif growth_type == :flashcard
        # ── FLASHCARD GROWTH ───────────────────────────────────────────────
        # GRUG v10: Pattern is "fc:<expression>". Compute arithmetic and write
        # to flashcard. No node needed - just a lookup table entry.
        if startswith(pattern, "fc:")
            expr = pattern[4:end]  # strip "fc:" prefix
            if !isempty(expr)
                new_id = "fc:$expr"
                notes = "Flashcard candidate: $expr (needs computation)"
            end
        else
            notes = "Flashcard growth: invalid pattern format '$pattern'"
        end

    elseif growth_type == :sigil_voter_node
        # ── SIGIL VOTER NODE GROWTH ──────────────────────────────────────
        # GRUG v8.2: Grow a :sigil node_type node. NOCHAT, singleton, never
        # in growth groups. Pattern is the sigil shape identifier.
        # These nodes represent sigil SHAPES as first-class voting entities.
        # e.g. &causal → a node whose pattern is "sigil:causal" that votes
        # whenever causal language is detected, routing to the right response.
        sig_pattern = startswith(pattern, "sigil:") ? pattern : "sigil:$pattern"
        sig_action = _infer_action_packet_from_lobe(lobe_hint, lobe_registry;
                                                      node_map=node_map, node_lock=node_lock)
        sig_json = Dict{String, Any}(
            "system_prompt"      => "Sigil anchor for &$pattern. Shape-cluster magnet grew this node.",
            "lobe_hint"          => lobe_hint,
            "voice_register"     => "plain",
            "frame_hints"        => ["basic"],
            "noun_anchors"       => [pattern],
            "autogrowth_source"  => "inverse_sigil_magnet",
            "autogrowth_born"    => string(round(time(), digits=3)),
            "autogrowth_type"    => "sigil_voter_node",
            "sigil_anchor"       => pattern,  # which sigil this node represents
        )
        try
            new_id = create_node_fn(
                sig_pattern,
                sig_action,
                sig_json,
                String[];
                initial_strength = 1.0,
                node_type = :sigil,  # GRUG: :sigil = NOCHAT, singleton
            )
            if !isempty(new_id)
                # GRUG: Register into lobe
                if !isempty(lobe_registry) && haskey(lobe_registry, lobe_hint)
                    rec = lobe_registry[lobe_hint]
                    if hasproperty(rec, :node_ids) && !(new_id in rec.node_ids)
                        push!(rec.node_ids, new_id)
                    end
                end
                notes = "Sigil voter node grown: &$pattern (NOCHAT, singleton) in $lobe_hint"
            end
        catch e
            notes = "Sigil voter node growth failed: $e"
        end

    elseif growth_type == :inverse_voter_node
        # ── INVERSE VOTER NODE GROWTH ────────────────────────────────
        # GRUG v8.2: Grow a regular :voter node from inverse sigil evidence.
        # These ARE chat-eligible and join groups, unlike sigil voter nodes.
        # The pattern comes from the magnet's concrete cluster — e.g. if
        # &noun has concretes ["cat","dog","bird"], the pattern might be
        # the strongest concrete token or a combined pattern.
        # Falls through to _grow_node!() with the same logic as :match but
        # with autogrowth_type tagged as "inverse_voter_node".
        inv_json_extras = Dict{String, Any}(
            "autogrowth_source"  => "inverse_sigil_magnet",
            "autogrowth_type"    => "inverse_voter_node",
        )
        new_id, notes = _grow_node!(
            pattern, :match, lobe_hint;  # use :match for _grow_node! dispatch
            node_map=node_map, node_lock=node_lock,
            create_node_fn=create_node_fn,
            add_to_group_fn=add_to_group_fn,
            register_group_fn=register_group_fn,
            group_map=group_map, group_lock=group_lock,
            lobe_registry=lobe_registry,
            immune_gate_fn=immune_gate_fn,
            thesaurus_word_similarity=thesaurus_word_similarity,
            group_latch_fn=group_latch_fn,
            link_to_group_member_fn=link_to_group_member_fn,
            group_avg_strength_fn=group_avg_strength_fn,
            group_for_fn=group_for_fn,
            sigil_promote_fn=sigil_promote_fn,
            extract_triples_fn=extract_triples_fn,
            evaluate_dialectics_fn=evaluate_dialectics_fn,
            words_to_signal_fn=words_to_signal_fn,
            scan_latch_candidates_fn=scan_latch_candidates_fn,
            user_text=user_text,
            user_triples_from_evidence=best_record.user_triples,
            verb_class_of_fn=verb_class_of_fn,
            sigil_table=sigil_table,
            extra_json_data=inv_json_extras,  # tag the node with inverse provenance
        )
        if !isempty(new_id)
            notes = "Inverse voter node grown: '$pattern' in $lobe_hint (from sigil magnet)"
        end

    else
        notes = "Unknown growth type: $growth_type"
    end

    # ── REMOVE EVIDENCE IF GROWTH HAPPENED ─────────────────────────────
    # GRUG: If we successfully grew something, remove its evidence record.
    # The gap is (hopefully) filled. If the growth failed or was blocked,
    # keep the evidence so it can try again later.
    if !isempty(new_id)
        lock(_EVIDENCE_LOCK) do
            delete!(_EVIDENCE, best_key)
        end
    end

    stats = AutoGrowthStats(
        pattern,
        string(growth_type),
        best_record.accumulated_intensity,
        best_record.frequency,
        p_grow,
        won_coinflip,
        new_id,
        lobe_hint,
        join(best_record.sources, ","),
        notes,
        (time() - t0) * 1000,
    )
    _log_growth!(stats)
    return stats
end

# ==============================================================================
# CONCEPT DEDUP — prevent growing nodes for concepts already covered
# ==============================================================================
# GRUG v8.2: Before growing ANY node, check if an existing alive node already
# covers the same concept. "big" and "large" are the same idea — the thesaurus
# knows this via word_similarity (trigram Jaccard) and synonym_lookup (seed-aware).
# If any existing node's pattern scores above CONCEPT_DEDUP_FLOOR (0.7), the
# candidate is a duplicate and growth is blocked.
#
# This only checks ALIVE nodes (is_grave == false). Dead nodes don't count —
# they were killed for a reason (poor performance, low strength).
# ==============================================================================

"""
    _is_concept_duplicate(pattern, node_map, node_lock; thesaurus_word_similarity) -> Bool

Return `true` if any alive (non-grave) node in `node_map` has a pattern
similar enough to `pattern` to be considered the same concept.

Similarity is computed via the provided `thesaurus_word_similarity` function.
When `synonym_lookup` is passed (the preferred option), it catches semantic
synonyms like "big"/"large" (0.95 seed match) that plain `word_similarity`
misses (0.0 trigram overlap). Falls back to `word_similarity` (trigram Jaccard)
when no synonym_lookup is available.

The floor is `CONCEPT_DEDUP_FLOOR` (0.7 by default). Patterns are compared
word-by-word: if ANY word in the candidate pattern matches any word in an
existing pattern above the floor, the whole pattern is considered covered.

For single-word patterns (the common case for autogrowth), this is a direct
similarity check. For multi-word patterns, we check word pairs and take
the maximum similarity across all pairs.
"""
function _is_concept_duplicate(pattern::String, node_map, node_lock;
                                thesaurus_word_similarity::Function)
    candidate_words = split(lowercase(strip(pattern)), r"[\s_]+")
    # GRUG: Filter out empty tokens from split
    filter!(!isempty, candidate_words)

    # GRUG: Empty pattern = can't be a duplicate of anything
    if isempty(candidate_words)
        return false
    end

    best_score = 0.0
    best_match = ""

    # GRUG: Thread-safe read of node_map. We only need to read, so a quick
    # lock lets us snapshot the values without holding the lock too long.
    all_nodes = lock(node_lock) do
        collect(values(node_map))
    end

    for node in all_nodes
        # GRUG: Skip grave nodes — they're dead and don't represent active concepts
        if node.is_grave
            continue
        end

        existing_words = split(lowercase(strip(node.pattern)), r"[\s_]+")
        filter!(!isempty, existing_words)
        if isempty(existing_words)
            continue
        end

        # GRUG: Compare every candidate word against every existing word.
        # Take the MAX similarity across all pairs. If any pair scores above
        # CONCEPT_DEDUP_FLOOR, the concepts overlap enough to block growth.
        for cw in candidate_words
            for ew in existing_words
                try
                    sim = thesaurus_word_similarity(cw, ew)
                    if sim > best_score
                        best_score = sim
                        best_match = node.pattern
                    end
                    if sim >= CONCEPT_DEDUP_FLOOR
                        @debug "[AutoGrowth] Concept dedup: '$pattern' blocked by existing '$(node.pattern)' (sim=$(round(sim, digits=3)))"
                        return true
                    end
                catch
                    # GRUG: word_similarity can throw on empty/weird input — skip it
                    continue
                end
            end
        end
    end

    # GRUG: No existing node covers this concept. Safe to grow.
    return false
end

# ==============================================================================
# GRUG new: EXACT NODE COPY GUARD (Cycle Solver Ledger companion check)
# ==============================================================================
# GRUG: This is DELIBERATELY separate from _is_concept_duplicate above.
# _is_concept_duplicate blocks growth on SEMANTIC/FUZZY similarity (synonyms,
# trigram overlap) — "big" blocks "large". That's desired and stays as-is.
#
# THIS guard blocks growth ONLY on BYTE-IDENTICAL full-node copies: same
# pattern AND same action_packet AND same drop_table (structure), all
# identical to an existing alive node. Two nodes with the SAME pattern/bind
# sites but DIFFERENT structure/wording elsewhere are explicitly ALLOWED —
# multiple nodes solving the same concept with different structure is the
# desired anti-staleness mechanism the thesaurus alone can't provide. Only a
# truly exact clone (pattern + action_packet + drop_table all identical) is
# redundant enough to block outright.
# ==============================================================================

"""
    _is_exact_node_duplicate(pattern, action_packet, drop_table, node_map, node_lock) -> Bool

Return `true` if any alive (non-grave) node in `node_map` is a BYTE-IDENTICAL
copy of the candidate: same `pattern`, same `action_packet`, AND same
`drop_table` contents (order-insensitive — same set of drop entries).

This is a much stricter/lighter check than `_is_concept_duplicate`. It does
NOT consider semantic similarity, and it does NOT block nodes that merely
share a pattern/bind site with different action_packet or drop_table — those
are explicitly welcome (anti-staleness via structural diversity).
"""
function _is_exact_node_duplicate(pattern::String, action_packet::String,
                                   drop_table::Vector{String}, node_map, node_lock)::Bool
    candidate_pattern = lowercase(strip(pattern))
    candidate_action  = strip(action_packet)
    candidate_drops   = Set(strip.(drop_table))

    all_nodes = lock(node_lock) do
        collect(values(node_map))
    end

    for node in all_nodes
        node.is_grave && continue
        if lowercase(strip(node.pattern)) == candidate_pattern &&
           strip(node.action_packet) == candidate_action &&
           Set(strip.(node.drop_table)) == candidate_drops
            @debug "[AutoGrowth] Exact node duplicate blocked: '$pattern' is a byte-identical copy of existing node $(node.id)"
            return true
        end
    end

    return false
end

# ==============================================================================
# NODE GROWTH — internal helper for match/time/antimatch node creation
# ==============================================================================

function _grow_node!(pattern::String, growth_type::Symbol, lobe_hint::String;
                     node_map, node_lock, create_node_fn, add_to_group_fn,
                     register_group_fn, group_map, group_lock, lobe_registry,
                     immune_gate_fn, thesaurus_word_similarity,
                     group_latch_fn=nothing, link_to_group_member_fn=nothing,
                     group_avg_strength_fn=nothing, group_for_fn=nothing,
                     sigil_promote_fn=nothing, extract_triples_fn=nothing,
                     evaluate_dialectics_fn=nothing, words_to_signal_fn=nothing,
                     scan_latch_candidates_fn=nothing,
                     user_text::String="",
                     user_triples_from_evidence::Vector{Tuple{String,String,String}}=Tuple{String,String,String}[],
                     verb_class_of_fn::Union{Function,Nothing}=nothing,
                     sigil_table::Union{Any,Nothing}=nothing,
                     extra_json_data::Union{Dict{String,Any},Nothing}=nothing)
    new_id = ""
    notes = ""

    # GRUG: Infer action packet from lobe's own nodes (same as TemporalGrowth).
    action_packet = _infer_action_packet_from_lobe(lobe_hint, lobe_registry;
                                                     node_map=node_map, node_lock=node_lock)

    # GRUG: Build json_data with autogrowth provenance
    json_data = Dict{String, Any}(
        "system_prompt"     => "Grug think about $pattern. One more rock for Grug's wall of knowing.",
        "lobe_hint"         => lobe_hint,
        "voice_register"    => "plain",
        "frame_hints"       => ["basic"],
        "noun_anchors"      => [pattern],
        "autogrowth_source" => "live_conversation",
        "autogrowth_born"   => string(round(time(), digits=3)),
        "autogrowth_type"   => string(growth_type),
    )

    # GRUG v8.2: Merge extra_json_data if provided (e.g. inverse voter node provenance).
    # Caller-supplied keys override defaults — the caller knows best what this node is.
    if extra_json_data !== nothing
        for (k, v) in extra_json_data
            json_data[k] = v
        end
    end

    # GRUG: Time nodes get extra json_data
    if growth_type == :time
        json_data["time_node"] = true
        json_data["time_orientation"] = "neutral"
    end

    # GRUG: Antimatch nodes get is_antimatch_node=true
    is_antimatch = growth_type == :antimatch

    # GRUG: Immune gate check
    if immune_gate_fn !== nothing
        try
            passed = immune_gate_fn(pattern, json_data)
            if !passed
                return ("", "Immune gate blocked autogrowth for '$pattern'")
            end
        catch e
            return ("", "Immune gate error for '$pattern': $e")
        end
    end

    # GRUG new: EXACT NODE COPY GUARD. Byte-identical clones (same pattern
    # AND same action_packet AND same drop_table) are blocked outright — a
    # perfect duplicate contributes nothing a sibling doesn't already provide.
    # This is SEPARATE from the semantic CONCEPT DEDUP GUARD above: nodes
    # sharing a pattern/bind site with DIFFERENT action_packet or drop_table
    # sail through untouched (desired — structural diversity fights
    # orchestration staleness).
    if _is_exact_node_duplicate(pattern, action_packet, String[], node_map, node_lock)
        stats = AutoGrowthStats(
            pattern,
            string(growth_type),
            best_record.accumulated_intensity,
            best_record.frequency,
            p_grow,
            false,
            "",
            lobe_hint,
            join(best_record.sources, ","),
            "Exact node duplicate: '$pattern' is a byte-identical copy of an existing node",
            (time() - t0) * 1000,
        )
        _log_growth!(stats)
        lock(_EVIDENCE_LOCK) do
            delete!(_EVIDENCE, best_key)
        end
        return stats
    end

    # GRUG: CREATE THE NODE!
    try
        new_id = create_node_fn(
            pattern,
            action_packet,
            json_data,
            String[];
            initial_strength = 1.0,
            is_antimatch_node = is_antimatch,
        )

        # GRUG: Register into lobe
        if !isempty(lobe_registry) && haskey(lobe_registry, lobe_hint)
            rec = lobe_registry[lobe_hint]
            if hasproperty(rec, :node_ids) && !(new_id in rec.node_ids)
                push!(rec.node_ids, new_id)
            end
        end

        # ── GRUG v7.58: ASSIGN RELATIONAL PATTERNS FROM USER TRIPLES ──────────
        # When AutoGrowth grows a node from relational gap evidence, the user's
        # triples (stored in the EvidenceRecord) get promoted to sigil refs and
        # assigned to the new node's relational_patterns + relation_weights.
        # This gives autogrown nodes the SAME disambiguation power as hand-crafted
        # specimen nodes — a node with (fire, &causal, warmth) matches ANY verb
        # in &causal's expansion, not just the one verb the user happened to type.
        #
        # Works for ALL growth types: :match, :time, :aiml, :antimatch, :sigil,
        # :thesaurus, :lobe_whitelist, :flashcard. Every node type benefits from
        # relational anchoring — it's how the node gets FOUND by the scan pipeline.
        if !isempty(new_id) && (extract_triples_fn !== nothing || !isempty(user_triples_from_evidence))
            try
                # GRUG: Get triples — prefer evidence-stored triples (already extracted,
                # already filtered for relevance), fall back to extracting from user_text.
                raw_triples = if !isempty(user_triples_from_evidence)
                    user_triples_from_evidence
                elseif !isempty(user_text) && extract_triples_fn !== nothing
                    ut = extract_triples_fn(user_text)
                    # GRUG: Convert RelationalTriple structs to plain tuples if needed
                    [(lowercase(strip(t.relation === nothing ? string(t[1]) : t.subject)),
                      lowercase(strip(t.relation === nothing ? string(t[2]) : t.relation)),
                      lowercase(strip(t.relation === nothing ? string(t[3]) : t.object)))
                     for t in ut]
                else
                    Tuple{String,String,String}[]
                end

                if !isempty(raw_triples)
                    (promoted, weights) = _compute_relational_patterns_from_triples(
                        raw_triples, pattern; verb_class_of_fn=verb_class_of_fn,
                        sigil_table=sigil_table)

                    if !isempty(promoted)
                        # GRUG: Mutate the newly created node directly.
                        # Node is mutable struct, so we can modify its fields.
                        new_node_obj = lock(node_lock) do
                            get(node_map, new_id, nothing)
                        end
                        if new_node_obj !== nothing
                            for (subj, rel, obj) in promoted
                                push!(new_node_obj.relational_patterns,
                                      RelationalTriple(subj, rel, obj))
                            end
                            for (k, v) in weights
                                new_node_obj.relation_weights[k] = v
                            end
                            # GRUG: Also store in json_data for specimen persistence
                            json_data["relational_patterns"] = [
                                Dict("subject" => s, "relation" => r, "object" => o)
                                for (s, r, o) in promoted
                            ]
                            json_data["relation_weights"] = weights
                            # GRUG: Update node's json_data with relational info
                            try
                                if hasproperty(new_node_obj, :json_data)
                                    merge!(new_node_obj.json_data, json_data)
                                end
                            catch; end
                        end
                    end
                end
            catch e_relational
                # GRUG: Relational pattern assignment is non-fatal.
                # The node was still created — it just won't have relational patterns.
                # Group latching will still work via thesaurus/Jaccard fallback.
                @warn "[AutoGrowth] Relational pattern assignment failed for '$pattern': $e_relational"
            end
        end

        # GRUG: Group latching — same logic as MitosisMode
        _latched_group_id = ""
        _latched_to_id = ""

        # GRUG: Antimatch and AIML = always singleton
        # GRUG v7.59: Sigil nodes are also singleton (node_type==:sigil).
        # They are NOCHAT (ineligible for idle chatter) and never placed in
        # growth groups. register_group! rejects them; the catch below handles it.
        _is_singleton = is_antimatch
        # GRUG v7.59: Also check if the new node is a sigil node.
        if !_is_singleton
            _new_node_obj = lock(node_lock) do
                get(node_map, new_id, nothing)
            end
            if _new_node_obj !== nothing && isdefined(_new_node_obj, :node_type) && _new_node_obj.node_type === :sigil
                _is_singleton = true
            end
        end

        if _is_singleton
            try
                if register_group_fn !== nothing
                    new_node_obj = lock(node_lock) do
                        get(node_map, new_id, nothing)
                    end
                    if new_node_obj !== nothing
                        grp = register_group_fn(new_node_obj)
                        if grp !== nothing
                            _latched_group_id = grp.id
                        end
                    end
                end
            catch
                _latched_group_id = ""
            end
        else
            # GRUG: Try relational+thesaurus pipeline or fallback group latch
            _try_group_latch!(new_id, pattern, action_packet, lobe_hint;
                             node_map=node_map, node_lock=node_lock,
                             add_to_group_fn=add_to_group_fn,
                             register_group_fn=register_group_fn,
                             group_latch_fn=group_latch_fn,
                             link_to_group_member_fn=link_to_group_member_fn,
                             group_avg_strength_fn=group_avg_strength_fn,
                             group_for_fn=group_for_fn,
                             scan_latch_candidates_fn=scan_latch_candidates_fn,
                             # GRUG v7.58: Pass relational sigil kwargs for full 3-gate pipeline
                             sigil_promote_fn=sigil_promote_fn,
                             extract_triples_fn=extract_triples_fn,
                             evaluate_dialectics_fn=evaluate_dialectics_fn,
                             words_to_signal_fn=words_to_signal_fn,
                             growth_type=growth_type,
                             _latched_group_id_ref = Ref(_latched_group_id),
                             _latched_to_id_ref = Ref(_latched_to_id),
            )
            _latched_group_id = _latched_group_id_ref[] === nothing ? "" : _latched_group_id_ref[]
            _latched_to_id = _latched_to_id_ref[] === nothing ? "" : _latched_to_id_ref[]
        end

        latch_info = isempty(_latched_to_id) ?
                     (isempty(_latched_group_id) ? "free_agent" : "group=$(_latched_group_id)") :
                     "group=$(_latched_group_id),link=$(_latched_to_id)"
        notes = "AutoGrew [$growth_type] '$pattern' → $new_id in $lobe_hint [$latch_info]"

    catch e
        notes = "AutoGrowth node creation failed for '$pattern': $e"
    end

    return (new_id, notes)
end

# ==============================================================================
# GROUP LATCHING — same pattern as MitosisMode
# ==============================================================================

# GRUG: Helper to attempt group latching for a newly grown node.
# Tries relational+thesaurus pipeline if available, falls back to
# Jaccard-only group_latch_fn. Singleton+NOCHAT if no group passes.

function _try_group_latch!(new_id, pattern, action_packet, lobe_hint;
                           node_map, node_lock, add_to_group_fn,
                           register_group_fn, group_latch_fn=nothing,
                           link_to_group_member_fn=nothing,
                           group_avg_strength_fn=nothing,
                           group_for_fn=nothing,
                           scan_latch_candidates_fn=nothing,
                           # GRUG v7.58: Relational sigil kwargs for _scan_latch_candidates
                           sigil_promote_fn=nothing,
                           extract_triples_fn=nothing,
                           evaluate_dialectics_fn=nothing,
                           words_to_signal_fn=nothing,
                           growth_type=:match,
                           _latched_group_id_ref=Ref(""),
                           _latched_to_id_ref=Ref(""))
    # GRUG: Check if this is a time node — must latch to time-only groups
    grown_is_time = growth_type == :time

    if scan_latch_candidates_fn !== nothing
        # ── RELATIONAL+THESAURUS PIPELINE ───────────────────────────
        try
            candidates = scan_latch_candidates_fn(
                pattern, action_packet;
                node_map=node_map, node_lock=node_lock,
                lobe_id=lobe_hint,
                thesaurus_fn=thesaurus_word_similarity,
                # GRUG v7.58: Pass relational sigil kwargs for full 3-gate pipeline
                sigil_promote_fn=sigil_promote_fn,
                extract_triples_fn=extract_triples_fn,
                evaluate_dialectics_fn=evaluate_dialectics_fn,
                words_to_signal_fn=words_to_signal_fn,
            )
            if !isempty(candidates)
                # GRUG: Filter by time-node isolation if needed
                if grown_is_time
                    candidates = filter(c -> try c.group.is_time_node_group catch; false end, candidates)
                else
                    candidates = filter(c -> try !c.group.is_time_node_group catch; true end, candidates)
                end

                if !isempty(candidates)
                    n_pick = min(5, length(candidates))
                    chosen = candidates[rand(1:n_pick)]
                    target_group = chosen.group

                    avg_str = if group_avg_strength_fn !== nothing
                        group_avg_strength_fn(target_group; node_map=node_map, node_lock=node_lock)
                    else
                        try chosen.avg_strength catch; 0.0 end
                    end

                    # GRUG: Strength-biased coinflip
                    if _strength_biased_join_coinflip(avg_str)
                        joined = add_to_group_fn(target_group, new_id)
                        if joined
                            _latched_group_id_ref[] = target_group.id
                            if link_to_group_member_fn !== nothing
                                try
                                    new_node_obj = lock(node_lock) do
                                        get(node_map, new_id, nothing)
                                    end
                                    if new_node_obj !== nothing
                                        linked_id = link_to_group_member_fn(new_node_obj, target_group)
                                        if linked_id !== nothing
                                            _latched_to_id_ref[] = linked_id
                                        end
                                    end
                                catch; end
                            end
                            return
                        end
                    end
                end
            end
        catch; end
    end

    # ── FALLBACK: JACCARD-ONLY GROUP LATCH ─────────────────────────
    if group_latch_fn !== nothing && add_to_group_fn !== nothing
        try
            candidates = group_latch_fn(pattern; node_map=node_map, node_lock=node_lock,
                                        requesting_node_is_time=grown_is_time)
            if !isempty(candidates)
                eligible = filter(c -> c.avg_strength >= 0.5, candidates)
                if !isempty(eligible)
                    chosen = eligible[rand(1:length(eligible))]
                    target_group = chosen.group
                    joined = add_to_group_fn(target_group, new_id)
                    if joined
                        _latched_group_id_ref[] = target_group.id
                        if link_to_group_member_fn !== nothing
                            new_node_obj = lock(node_lock) do
                                get(node_map, new_id, nothing)
                            end
                            if new_node_obj !== nothing
                                linked_id = link_to_group_member_fn(new_node_obj, target_group)
                                if linked_id !== nothing
                                    _latched_to_id_ref[] = linked_id
                                end
                            end
                        end
                        return
                    end
                end
            end
        catch; end
    end

    # ── SINGLETON + NOCHAT ────────────────────────────────────────
    # GRUG: No group passed. Found a new singleton group. NOCHAT if <4 neighbors.
    try
        if register_group_fn !== nothing
            new_node_obj = lock(node_lock) do
                get(node_map, new_id, nothing)
            end
            if new_node_obj !== nothing
                grp = register_group_fn(new_node_obj)
                if grp !== nothing
                    _latched_group_id_ref[] = grp.id
                    if length(new_node_obj.neighbor_ids) < 4
                        try
                            grp.is_chatter_eligible = false
                        catch; end
                    end
                end
            end
        end
    catch; end
end

# ==============================================================================
# THESAURUS AUTO-DISCOVERY — check co-occurrence for synonym pairs
# ==============================================================================

"""
    discover_thesaurus_pairs!(; register_thesaurus_pair_fn, thesaurus_word_similarity)

GRUG: Called from idle cycle. Scans the co-occurrence map for pairs that
meet the threshold (co-occur THESAURUS_CO_OCCUR_MIN times, trigram sim
>= THESAURUS_AUTO_SIM_FLOOR). Registers them as synonym seed pairs.
This makes the thesaurus grow itself from conversation data.
"""
function discover_thesaurus_pairs!(;
    register_thesaurus_pair_fn::Union{Function,Nothing} = nothing,
    thesaurus_word_similarity::Function = (a,b) -> 0.0,
)
    if register_thesaurus_pair_fn === nothing
        return String[]
    end

    discovered = String[]

    lock(_CO_OCCUR_LOCK) do
        for ((a, b), count) in _CO_OCCUR_MAP
            if count < THESAURUS_CO_OCCUR_MIN
                continue
            end
            # GRUG: Check trigram similarity to filter garbage pairs
            try
                sim = _trigram_similarity(a, b)
                if sim >= THESAURUS_AUTO_SIM_FLOOR
                    # GRUG: Also check thesaurus — don't register if already known
                    existing_sim = thesaurus_word_similarity(a, b)
                    if existing_sim < 0.7  # Not already a known synonym pair
                        key = "thes:$a:$b"
                        _add_evidence!(key, Float64(count) * 0.5, "co_occurrence", :thesaurus;
                                      lobe_hint = "default")
                        push!(discovered, "$a↔$b(count=$count,sim=$(round(sim,digits=2)))")
                    end
                end
            catch; end
        end
    end

    return discovered
end

# ==============================================================================
# EVIDENCE HELPERS
# ==============================================================================

# ==============================================================================
# GRUG v7.58: DYNAMIC SIGIL RELATIONAL HELPERS
# When AutoGrowth grows a node, it needs to assign relational_patterns that use
# sigil references (&causal, &temporal, etc.) instead of concrete verbs ("make",
# "before"). This gives autogrown nodes the SAME disambiguation power as hand-
# crafted specimen nodes — a node with (fire, &causal, warmth) matches ANY verb
# in &causal's expansion, not just the one verb the user happened to type.
#
# The reverse mapping: verb → verb_class_of(verb) → "&$(class_name)".
# Example: "make" → "causal" → "&causal".
# ==============================================================================

"""
    _verb_to_sigil_ref(verb::String; verb_class_of_fn=nothing, sigil_table=nothing) -> String

Map a concrete verb to its sigil reference if possible.
E.g. "make" → "&causal", "before" → "&temporal", "has" → "&possessive".
Strategy:
  1. Try SemanticVerbs verb_class_of reverse map (fast, O(1))
  2. Fall back to SigilRegistry verb_to_relation_sigil (searches expansion lists)
If no sigil matches, return the verb as-is (concrete triple, no expansion).
"""
function _verb_to_sigil_ref(verb::String;
                            verb_class_of_fn::Union{Function,Nothing}=nothing,
                            sigil_table::Union{Any,Nothing}=nothing)::String
    v = lowercase(strip(verb))
    isempty(v) && return verb

    # GRUG: Try the verb→class reverse map from SemanticVerbs (fast O(1))
    if verb_class_of_fn !== nothing
        try
            cls = verb_class_of_fn(v)
            if cls !== nothing && cls != ""
                return "&$cls"
            end
        catch
            # GRUG: verb_class_of failed — try sigil table fallback
        end
    end

    # GRUG v7.58: Fallback — search SigilRegistry relation sigil expansion lists.
    # This catches verbs like "before", "has", "after" that are in sigil expansions
    # but not in the SemanticVerbs _VERB_REGISTRY.
    if sigil_table !== nothing
        try
            sigil_name = SigilRegistry.verb_to_relation_sigil(sigil_table, v)
            if sigil_name !== nothing && sigil_name != ""
                return "&$sigil_name"
            end
        catch
            # GRUG: sigil table lookup failed — return verb as-is
        end
    end

    return verb
end

"""
    _promote_triple_to_sigil(triple; verb_class_of_fn) -> Tuple{String,String,String}

Promote a concrete (subject, verb, object) triple to sigil form.
The verb gets mapped to a sigil reference if possible.
Subject and object stay concrete — they're the nouns that anchor the node.
Returns (subject, sigil_ref_or_verb, object).
"""
function _promote_triple_to_sigil(triple::Tuple{String,String,String};
                                  verb_class_of_fn::Union{Function,Nothing}=nothing,
                                  sigil_table::Union{Any,Nothing}=nothing)::Tuple{String,String,String}
    (subj, rel, obj) = triple
    sigil_ref = _verb_to_sigil_ref(rel; verb_class_of_fn=verb_class_of_fn, sigil_table=sigil_table)
    return (subj, sigil_ref, obj)
end

"""
    _compute_relational_patterns_from_triples(user_triples, pattern; verb_class_of_fn)
    -> (Vector{Tuple{String,String,String}}, Dict{String,Float64})

Given the user's relational triples and the growth pattern, compute the
relational_patterns and relation_weights for a newly autogrown node.

Strategy:
  - Each user triple is promoted to sigil form: (subj, &sigil, obj)
  - The pattern's tokens become the node's subject/object anchors
  - relation_weights get a default boost for each sigil reference used
  - This makes autogrown nodes relational-aware from birth
"""
function _compute_relational_patterns_from_triples(
# REMINDER: relational_patterns may contain sigil tokens (&n, &op etc) — dynamic evaluation at match time.
    user_triples::Vector{Tuple{String,String,String}},
    pattern::String;
    verb_class_of_fn::Union{Function,Nothing}=nothing,
    sigil_table::Union{Any,Nothing}=nothing
)::Tuple{Vector{Tuple{String,String,String}}, Dict{String,Float64}}
    promoted = Tuple{String,String,String}[]
    weights = Dict{String,Float64}()

    pat_lower = lowercase(strip(pattern))

    for ut in user_triples
        (subj, sigil_ref, obj) = _promote_triple_to_sigil(ut;
            verb_class_of_fn=verb_class_of_fn, sigil_table=sigil_table)

        # GRUG: Only keep triples where the pattern overlaps with subject or object.
        # A triple like ("weather", &causal, "mood") doesn't belong on a "fire" node.
        # But ("fire", &causal, "warmth") absolutely belongs on a "fire" node.
        pat_tokens = Set(split(pat_lower))
        subj_lower = lowercase(strip(subj))
        obj_lower  = lowercase(strip(obj))
        relevant = subj_lower in pat_tokens || obj_lower in pat_tokens ||
                   occursin(subj_lower, pat_lower) || occursin(obj_lower, pat_lower) ||
                   occursin(pat_lower, subj_lower) || occursin(pat_lower, obj_lower)

        if relevant
            push!(promoted, (subj, sigil_ref, obj))
            # GRUG: Sigil reference weights — higher for sigil refs (they expand to many verbs)
            # Concrete verb weights stay at 1.0 (they only match themselves)
            if startswith(sigil_ref, "&")
                weights[sigil_ref] = get(weights, sigil_ref, 0.0) + 1.3
            else
                weights[sigil_ref] = get(weights, sigil_ref, 0.0) + 1.0
            end
        end
    end

    # GRUG: Deduplicate promoted triples
    unique_promoted = collect(Set(promoted))

    return (unique_promoted, weights)
end

# GRUG v7.58: Threshold for SOURCE 18 — how much relational mismatch
# counts as a "gap" worth accumulating evidence for.
const RELATIONAL_GAP_SCORE_FLOOR = 0.5

function _add_evidence!(pattern::String, intensity::Float64, source::String,
                        growth_type::Symbol; lobe_hint::String = "default",
                        user_triples::Vector{Tuple{String,String,String}} = Tuple{String,String,String}[])
    lock(_EVIDENCE_LOCK) do
        if haskey(_EVIDENCE, pattern)
            rec = _EVIDENCE[pattern]
            rec.accumulated_intensity += intensity
            rec.frequency += 1
            push!(rec.sources, source)
            rec.last_seen = time()
            # GRUG: Upgrade growth type if evidence suggests a more specific type
            # (e.g., a pattern first seen via silence_map might later show time keywords)
            if growth_type != :match && rec.growth_type == :match
                rec.growth_type = growth_type
            end
            # GRUG v7.58: Merge in user triples — keep the richest set.
            # If new triples are non-empty and existing are empty, replace.
            # If both non-empty, merge unique triples.
            if !isempty(user_triples)
                existing_set = Set(rec.user_triples)
                for ut in user_triples
                    if !(ut in existing_set)
                        push!(rec.user_triples, ut)
                        push!(existing_set, ut)
                    end
                end
            end
        else
            rec = EvidenceRecord(pattern, growth_type; lobe_hint=lobe_hint, user_triples=user_triples)
            rec.accumulated_intensity = intensity
            rec.frequency = 1
            push!(rec.sources, source)
            _EVIDENCE[pattern] = rec
        end
    end
end

function _decay_evidence!(t_now::Float64)
    # GRUG: Halve all accumulated intensities. This is exponential decay
    # with half-life = EVIDENCE_DECAY_HALFLIFE. Simple and effective.
    # Patterns that keep getting observed maintain their intensity.
    # Patterns the user stopped mentioning fade to zero and get evicted.
    lock(_EVIDENCE_LOCK) do
        to_delete = String[]
        for (key, rec) in _EVIDENCE
            rec.accumulated_intensity *= 0.5
            if rec.accumulated_intensity < 0.1  # Below noise floor — delete
                push!(to_delete, key)
            end
        end
        for key in to_delete
            delete!(_EVIDENCE, key)
        end
    end
end

function _is_covered(token::String, existing_patterns::Set{String})::Bool
    tok_lower = lowercase(strip(token))
    tok_words = Set(split(tok_lower))
    for pat in existing_patterns
        pat_words = Set(split(pat))
        if tok_lower in pat_words
            return true
        end
        if length(tok_words) == 1 && length(pat_words) == 1
            if startswith(tok_lower, pat) || startswith(pat, tok_lower)
                abs(length(tok_lower) - length(pat)) <= 2 && return true
            end
        end
        if length(tok_words) > 1 || length(pat_words) > 1
            intersection = length(intersect(tok_words, pat_words))
            union_size = length(union(tok_words, pat_words))
            union_size > 0 && Float64(intersection) / Float64(union_size) > 0.5 && return true
        end
    end
    return false
end

function _tokenize(text::String)::Vector{String}
    tokens = split(lowercase(strip(text)))
    return filter(t -> length(t) > 2 && !(t in STOPWORDS), String.(tokens))
end

# GRUG: Lobe inference from token content. Same keyword heuristics as MitosisMode.
function _infer_lobe_from_token(token::String)::String
    t = lowercase(strip(token))
    emotion_words = ["sad", "happy", "angry", "afraid", "scared", "fear",
                     "worry", "love", "hate", "grief", "mourn", "joy",
                     "lonely", "hurt", "pain", "comfort", "anxious", "anxiety"]
    survival_words = ["danger", "run", "predator", "storm", "flood",
                      "fire", "alert", "warn", "hide", "safe", "emergency",
                      "threat", "escape", "shelter"]
    philosophy_words = ["meaning", "truth", "exist", "consciousness",
                       "reality", "why", "purpose", "wonder", "think",
                       "know", "believe", "understand"]
    science_words = ["observe", "describe", "explain", "measure",
                    "experiment", "calculate", "analyze", "discover",
                    "evidence", "proof", "theory"]
    social_words = ["hello", "friend", "tribe", "belong", "greet",
                   "welcome", "goodbye", "trust", "share", "together"]
    math_words = ["number", "count", "add", "plus", "minus", "multiply",
                  "divide", "equal", "sum", "calculate"]
    reason_words = ["reason", "logic", "infer", "deduce", "conclude",
                   "because", "therefore", "premise", "argument"]

    if any(w -> occursin(w, t), emotion_words); return "EmotionLobe" end
    if any(w -> occursin(w, t), survival_words); return "SurvivalLobe" end
    if any(w -> occursin(w, t), philosophy_words); return "PhilosophyLobe" end
    if any(w -> occursin(w, t), science_words); return "ScienceLobe" end
    if any(w -> occursin(w, t), social_words); return "SocialLobe" end
    if any(w -> occursin(w, t), math_words); return "MathLobe" end
    if any(w -> occursin(w, t), reason_words); return "ReasoningLobe" end
    return "default"
end

# GRUG: Activator-verb pattern extraction. Same as MitosisMode.
const _ACTIVATOR_MARKERS = Set([
    "what", "who", "where", "when", "why", "how", "which", "whose", "whom",
    "tell", "show", "give", "explain", "describe", "calculate", "compute",
    "solve", "define", "list", "name", "find", "count",
])

function _extract_activator_verb_pattern(input_text::String)::String
    tokens = split(lowercase(strip(input_text)))
    isempty(tokens) && return strip(input_text)

    activator = nothing
    content_start = 1
    for (i, t) in enumerate(tokens)
        if t in _ACTIVATOR_MARKERS
            activator = t
            content_start = i + 1
            break
        end
    end

    content_tokens = filter(t -> length(t) > 2 && !(t in STOPWORDS) && !(t in _ACTIVATOR_MARKERS),
                            String.(tokens[content_start:end]))

    if activator === nothing
        if !isempty(content_tokens)
            activator = content_tokens[1]
            content_tokens = length(content_tokens) > 1 ? content_tokens[2:end] : String[]
        end
    end

    if activator !== nothing
        max_content = min(length(content_tokens), 3)
        if max_content > 0
            return strip(join(vcat([activator], content_tokens[1:max_content]), " "))
        else
            return strip(activator)
        end
    end

    if !isempty(content_tokens)
        return strip(join(content_tokens[1:min(4, length(content_tokens))], " "))
    end

    return strip(input_text)
end

# GRUG: Action packet inference from lobe's own nodes.
function _infer_action_packet_from_lobe(lobe_hint::String, lobe_registry;
                                         node_map, node_lock)::String
    default_packets = Dict(
        "EmotionLobe"     => "comfort[gentle]^3 | support[steady]^2 | acknowledge^1",
        "SurvivalLobe"    => "alert[urgent]^4 | warn[immediate]^3 | hide^2",
        "PhilosophyLobe"  => "ponder[deeply]^4 | reason[carefully]^3 | elaborate^1",
        "ScienceLobe"     => "describe[clearly]^3 | explain[step by step]^2 | analyze^1",
        "SocialLobe"      => "welcome[warm]^3 | greet[familiar]^2 | acknowledge^1",
        "MathLobe"        => "calculate[precise]^4 | verify[careful]^3 | explain^1",
        "ReasoningLobe"   => "reason[carefully]^3 | analyze[systematic]^2 | explain^1",
        "default"         => "ponder[carefully]^2 | describe[simply]^2 | acknowledge^1",
    )

    # GRUG: Try to read the lobe's own action_packets if available
    if !isempty(lobe_registry) && haskey(lobe_registry, lobe_hint)
        rec = lobe_registry[lobe_hint]
        if hasproperty(rec, :node_ids) && !isempty(rec.node_ids)
            # GRUG: Sample up to 8 strongest nodes
            scored = Tuple{Float64, String}[]
            lock(node_lock) do
                for nid in rec.node_ids
                    node = get(node_map, nid, nothing)
                    isnothing(node) && continue
                    node.is_grave && continue
                    push!(scored, (node.strength, nid))
                end
            end
            if !isempty(scored)
                sort!(scored, by=x -> x[1], rev=true)
                sample = scored[1:min(8, length(scored))]
                action_counts = Dict{String, Float64}()
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
                            action_counts[name] = get(action_counts, name, 0.0) + weight
                        end
                    end
                end
                if !isempty(action_counts)
                    ranked = sort(collect(action_counts), by=x -> x[2], rev=true)
                    top = ranked[1:min(3, length(ranked))]
                    parts = String[]
                    weights = [4, 3, 2]
                    for (i, (name, _)) in enumerate(top)
                        w = i <= length(weights) ? weights[i] : 1
                        push!(parts, "$name^$w")
                    end
                    return join(parts, " | ")
                end
            end
        end
    end

    return get(default_packets, lobe_hint, default_packets["default"])
end

_expand_action_macro_string(s::AbstractString)::String = replace(replace(String(s), "{{PIPE}}" => "|"), "{PIPE}" => "|")

function _parse_action_name(part::AbstractString)::String
    m = match(r"^(.+?)\[", part)
    m !== nothing && return _expand_action_macro_string(strip(m.captures[1]))
    m2 = match(r"^(.+?)\^", part)
    m2 !== nothing && return _expand_action_macro_string(strip(m2.captures[1]))
    return _expand_action_macro_string(strip(part))
end

function _parse_action_weight(part::AbstractString)::Float64
    m = match(r"\^(\d+)", part)
    m !== nothing && return parse(Float64, m.captures[1])
    return 1.0
end

# GRUG: Strength-biased join coinflip — same as MitosisMode.
function _strength_biased_join_coinflip(avg_strength::Float64;
                                         strength_cap::Float64 = 10.0)::Bool
    p = clamp(avg_strength / strength_cap, 0.0, 1.0)
    p <= 0.0 && return false
    return rand() < p
end

# GRUG: Trigram similarity for thesaurus auto-discovery
function _trigram_similarity(a::String, b::String)::Float64
    if length(a) < 3 || length(b) < 3
        return lowercase(a) == lowercase(b) ? 1.0 : 0.0
    end
    a_tris = Set(a[i:i+2] for i in 1:length(a)-2)
    b_tris = Set(b[i:i+2] for i in 1:length(b)-2)
    intersection = length(intersect(a_tris, b_tris))
    union_size = length(union(a_tris, b_tris))
    return union_size > 0 ? Float64(intersection) / Float64(union_size) : 0.0
end

# GRUG: Discover sigil expansion candidates from co-occurrence data
function _discover_sigil_expansion(sig_name::String,
                                    thesaurus_gate_filter::Function)::Vector{String}
    # GRUG: Find words that co-occur frequently with the sigil's domain.
    # The sigil name itself (minus & prefix) is the seed.
    candidates = String[]
    lock(_CO_OCCUR_LOCK) do
        for ((a, b), count) in _CO_OCCUR_MAP
            if count < 3
                continue
            end
            # GRUG: If one of the pair matches the sigil name, the other is a candidate
            if a == sig_name || b == sig_name
                partner = a == sig_name ? b : a
                length(partner) > 2 && push!(candidates, partner)
            end
        end
    end

    # GRUG: Also try thesaurus expansion — synonyms of the sigil name
    try
        expanded = thesaurus_gate_filter(sig_name)
        for syn in expanded
            s = lowercase(strip(syn))
            length(s) > 2 && push!(candidates, s)
        end
    catch; end

    # GRUG: Deduplicate and limit
    return unique(candidates)[1:min(10, length(unique(candidates)))]
end

# ==============================================================================
# LOGGING
# ==============================================================================

function _log_growth!(stats::AutoGrowthStats)
    lock(_GROWTH_LOG_LOCK) do
        push!(_GROWTH_LOG, stats)
        while length(_GROWTH_LOG) > _GROWTH_LOG_MAX
            deleteat!(_GROWTH_LOG, 1)
        end
    end
end

function get_growth_log()::Vector{AutoGrowthStats}
    lock(_GROWTH_LOG_LOCK) do
        collect(_GROWTH_LOG)
    end
end

# ==============================================================================
# STATUS + DIAGNOSTICS
# ==============================================================================

function get_autogrowth_status_summary()::String
    lines = String[
        "=== AUTOGROWTH STATUS ===",
        "  evidence_floor=$EVIDENCE_FLOOR, frequency_floor=$EVIDENCE_FREQUENCY_FLOOR",
        "  evidence_scale=$EVIDENCE_SCALE, coinflip_cap=$GROWTH_COINFLIP_CAP",
        "  decay_halflife=$(EVIDENCE_DECAY_HALFLIFE)s, decay_interval=$(EVIDENCE_DECAY_INTERVAL)s",
        "  evidence_cap=$EVIDENCE_CAP, population_cap=$POPULATION_CAP",
        "  ── v10 MLP head thresholds ──",
        "  semantic_gap<$(SEMANTIC_GAP_THRESHOLD), relevance_dropout<$(RELEVANCE_DROPOUT_THRESHOLD)",
        "  disambiguation_pressure>$(DISAMBIGUATION_PRESSURE_THRESHOLD), coherence_drop<$(COHERENCE_DROP_THRESHOLD)",
        "  ── v10 Curiosity accumulator ──",
        "  overflow_threshold=$(CURIOSITY_OVERFLOW_THRESHOLD), cooldown=$(CURIOSITY_COOLDOWN)s",
    ]

    lock(_EVIDENCE_LOCK) do
        push!(lines, "  pending_evidence=$(length(_EVIDENCE)) entries")
        # GRUG: Show top 5 by accumulated intensity
        sorted = sort(collect(_EVIDENCE), by=x -> x[2].accumulated_intensity, rev=true)
        top5 = sorted[1:min(5, length(sorted))]
        if !isempty(top5)
            push!(lines, "  top candidates:")
            for (key, rec) in top5
                push!(lines, "    '$key' type=$(rec.growth_type) intensity=$(round(rec.accumulated_intensity, digits=2)) freq=$(rec.frequency) lobe=$(rec.lobe_hint) sources=[$(join(rec.sources, ","))]")
            end
        end
    end

    lock(_CO_OCCUR_LOCK) do
        push!(lines, "  co_occurrence_pairs=$(length(_CO_OCCUR_MAP))")
    end

    # GRUG v10: Curiosity accumulator status
    curiosity = get_curiosity_status()
    push!(lines, "  curiosity: intensity=$(curiosity["intensity"]) buffer=$(curiosity["buffer_size"]) overflows=$(curiosity["overflow_count"])")
    if curiosity["is_overflowing"]
        push!(lines, "  *** CURIOSITY OVERFLOW PENDING ***")
    end

    log = get_growth_log()
    if !isempty(log)
        # GRUG: Count by growth type
        type_counts = Dict{String, Int}()
        grew_count = 0
        for entry in log
            type_counts[entry.growth_type] = get(type_counts, entry.growth_type, 0) + 1
            entry.won_coinflip && !isempty(entry.new_id) && (grew_count += 1)
        end
        push!(lines, "  growth_log=$(length(log)) events, grew=$grew_count nodes")
        push!(lines, "  by type:")
        for (gtype, cnt) in sort(collect(type_counts), by=x -> x[2], rev=true)
            push!(lines, "    $gtype: $cnt")
        end

        # Recent events
        recent = log[max(1, length(log)-4):end]
        push!(lines, "  recent:")
        for entry in reverse(recent)
            status = entry.won_coinflip ? (isempty(entry.new_id) ? "BLOCKED" : "GREW") : "SKIP"
            push!(lines, "    [$status] '$(entry.pattern)' type=$(entry.growth_type) p=$(round(entry.coinflip_prob, digits=3)) → $(entry.new_id) ($(round(entry.cycle_time_ms, digits=1))ms)")
        end
    else
        push!(lines, "  (no autogrowth events yet)")
    end

    return join(lines, "\n")
end

# ==============================================================================
# RESET — for testing / specimen reload
# ==============================================================================

function reset_evidence!()
    lock(_EVIDENCE_LOCK) do
        empty!(_EVIDENCE)
    end
    lock(_CO_OCCUR_LOCK) do
        empty!(_CO_OCCUR_MAP)
    end
    lock(_GROWTH_LOG_LOCK) do
        empty!(_GROWTH_LOG)
    end
    lock(_EVIDENCE_LOCK) do
        _LAST_DECAY[] = time()
    end
    return nothing
end

# ==============================================================================
# EVIDENCE SNAPSHOT — for save/load
# ==============================================================================

function get_evidence_snapshot()::Vector{Dict{String,Any}}
    lock(_EVIDENCE_LOCK) do
        [Dict{String,Any}(
            "pattern" => rec.pattern,
            "accumulated_intensity" => rec.accumulated_intensity,
            "frequency" => rec.frequency,
            "sources" => collect(rec.sources),
            "last_seen" => rec.last_seen,
            "first_seen" => rec.first_seen,
            "growth_type" => string(rec.growth_type),
            "lobe_hint" => rec.lobe_hint,
            # GRUG v7.58: Serialize user_triples for specimen persistence
            "user_triples" => [[s, r, o] for (s, r, o) in rec.user_triples],
        ) for rec in values(_EVIDENCE)]
    end
end

function load_evidence_snapshot!(snapshots::Vector)
    lock(_EVIDENCE_LOCK) do
        empty!(_EVIDENCE)
        for entry in snapshots
            pattern = get(entry, "pattern", "")
            isempty(pattern) && continue
            growth_type_sym = Symbol(get(entry, "growth_type", "match"))
            # GRUG v7.58: Deserialize user_triples from specimen
            raw_triples = get(entry, "user_triples", [])
            user_triples = Tuple{String,String,String}[]
            for t in raw_triples
                if isa(t, AbstractVector) && length(t) >= 3
                    push!(user_triples, (string(t[1]), string(t[2]), string(t[3])))
                elseif isa(t, AbstractDict)
                    s = get(t, "1", get(t, "subject", ""))
                    r = get(t, "2", get(t, "relation", ""))
                    o = get(t, "3", get(t, "object", ""))
                    if !isempty(s) && !isempty(r) && !isempty(o)
                        push!(user_triples, (s, r, o))
                    end
                end
            end
            rec = EvidenceRecord(pattern, growth_type_sym;
                                 lobe_hint=get(entry, "lobe_hint", "default"),
                                 user_triples=user_triples)
            rec.accumulated_intensity = get(entry, "accumulated_intensity", 0.0)
            rec.frequency = get(entry, "frequency", 0)
            rec.last_seen = get(entry, "last_seen", time())
            rec.first_seen = get(entry, "first_seen", time())
            sources = get(entry, "sources", String[])
            for s in sources
                push!(rec.sources, string(s))
            end
            _EVIDENCE[pattern] = rec
        end
    end
end

function get_co_occur_snapshot()::Vector{Dict{String,Any}}
    lock(_CO_OCCUR_LOCK) do
        [Dict{String,Any}("a" => k[1], "b" => k[2], "count" => v)
         for (k, v) in _CO_OCCUR_MAP if v >= 2]
    end
end

function load_co_occur_snapshot!(snapshots::Vector)
    lock(_CO_OCCUR_LOCK) do
        empty!(_CO_OCCUR_MAP)
        for entry in snapshots
            a = get(entry, "a", "")
            b = get(entry, "b", "")
            count = get(entry, "count", 0)
            if !isempty(a) && !isempty(b) && count > 0
                key = a < b ? (a, b) : (b, a)
                _CO_OCCUR_MAP[key] = count
            end
        end
    end
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export accumulate_evidence!, maybe_grow_from_evidence!, discover_thesaurus_pairs!
export get_autogrowth_status_summary, reset_evidence!
export get_growth_log, AutoGrowthStats
export get_evidence_snapshot, load_evidence_snapshot!
export get_co_occur_snapshot, load_co_occur_snapshot!
export EVIDENCE_FLOOR, EVIDENCE_SCALE, GROWTH_COINFLIP_CAP, EVIDENCE_CAP
export EVIDENCE_FREQUENCY_FLOOR, EVIDENCE_DECAY_HALFLIFE
# GRUG v10: Curiosity accumulator exports
export check_curiosity_overflow, get_curiosity_status, quench_curiosity!
export serialize_curiosity, deserialize_curiosity!
# GRUG v10: New evidence source thresholds
export SEMANTIC_GAP_THRESHOLD, RELEVANCE_DROPOUT_THRESHOLD
export DISAMBIGUATION_PRESSURE_THRESHOLD, COHERENCE_DROP_THRESHOLD
export CURIOSITY_OVERFLOW_THRESHOLD, CURIOSITY_COOLDOWN
# GRUG v10: New growth type rates
export FLASHCARD_GROWTH_RATE

# ==============================================================================
# CURIOSITY ACCUMULATOR API — GRUG v10
# ==============================================================================

"""
    check_curiosity_overflow() -> Union{String, Nothing}

Check if the curiosity accumulator has overflowed. If so, return the
highest-frequency pattern from the buffer as a question target.
Returns nothing if not overflowing or in cooldown.
"""
function check_curiosity_overflow()::Union{String, Nothing}
    lock(_CURIOSITY_LOCK) do
        # GRUG: Check cooldown
        if time() - _CURIOSITY_QUENCHED[] < CURIOSITY_COOLDOWN
            return nothing
        end
        # GRUG: Check overflow threshold
        if _CURIOSITY_INTENSITY[] < CURIOSITY_OVERFLOW_THRESHOLD
            return nothing
        end
        if isempty(_CURIOSITY_BUFFER[])
            return nothing
        end
        # GRUG: Find the highest-frequency pattern in the buffer
        # Cross-reference with evidence records to find the most-observed one
        best_pattern = _CURIOSITY_BUFFER[][1]
        best_freq = 0
        for pat in _CURIOSITY_BUFFER[]
            lock(_EVIDENCE_LOCK) do
                if haskey(_EVIDENCE, pat)
                    freq = _EVIDENCE[pat].frequency
                    if freq > best_freq
                        best_freq = freq
                        best_pattern = pat
                    end
                end
            end
        end
        return best_pattern
    end
end

"""
    quench_curiosity!()

Reset the curiosity accumulator after an overflow. Empties buffer,
zeros intensity, records quench time.
"""
function quench_curiosity!()
    lock(_CURIOSITY_LOCK) do
        _CURIOSITY_BUFFER[] = String[]
        _CURIOSITY_INTENSITY[] = 0.0
        _CURIOSITY_QUENCHED[] = time()
        _CURIOSITY_OVERFLOW_COUNT[] += 1
    end
end

"""
    get_curiosity_status() -> Dict{String, Any}

Return curiosity accumulator state for diagnostics.
"""
function get_curiosity_status()::Dict{String, Any}
    lock(_CURIOSITY_LOCK) do
        Dict{String, Any}(
            "intensity"      => round(_CURIOSITY_INTENSITY[]; digits=3),
            "buffer_size"    => length(_CURIOSITY_BUFFER[]),
            "buffer_top5"    => _CURIOSITY_BUFFER[][1:min(5, length(_CURIOSITY_BUFFER[]))],
            "quenched_at"    => _CURIOSITY_QUENCHED[],
            "overflow_count" => _CURIOSITY_OVERFLOW_COUNT[],
            "is_overflowing" => _CURIOSITY_INTENSITY[] >= CURIOSITY_OVERFLOW_THRESHOLD,
            "cooldown_remaining" => max(0.0, CURIOSITY_COOLDOWN - (time() - _CURIOSITY_QUENCHED[])),
        )
    end
end

"""
    serialize_curiosity() -> Dict{String, Any}

Serialize curiosity accumulator state for specimen save.
"""
function serialize_curiosity()::Dict{String, Any}
    lock(_CURIOSITY_LOCK) do
        Dict{String, Any}(
            "buffer"          => String[_CURIOSITY_BUFFER[]...],
            "intensity"       => _CURIOSITY_INTENSITY[],
            "quenched_at"     => _CURIOSITY_QUENCHED[],
            "overflow_count"  => _CURIOSITY_OVERFLOW_COUNT[],
        )
    end
end

"""
    deserialize_curiosity!(data::Any)

Restore curiosity accumulator state from specimen load.
"""
function deserialize_curiosity!(data::Any)
    if data === nothing || !isa(data, AbstractDict)
        return
    end
    lock(_CURIOSITY_LOCK) do
        buf = get(data, "buffer", [])
        if isa(buf, AbstractVector)
            _CURIOSITY_BUFFER[] = String[string(b) for b in buf]
        end
        _CURIOSITY_INTENSITY[] = clamp(Float64(get(data, "intensity", 0.0)), 0.0, 1.0)
        _CURIOSITY_QUENCHED[] = Float64(get(data, "quenched_at", 0.0))
        _CURIOSITY_OVERFLOW_COUNT[] = Int(get(data, "overflow_count", 0))
    end
end

end # module AutoGrowth
