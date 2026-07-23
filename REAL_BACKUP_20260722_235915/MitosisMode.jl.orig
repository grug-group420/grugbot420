# MitosisMode.jl
# ==============================================================================
# MITOSIS MODE — IDLE-TIME LAZY FUZZY CONSERVATIVE AUTOCATALYTIC NODE GROWTH
# ==============================================================================
# GRUG: When cave is idle long enough, Grug *maybe* grow new node. Not fast.
# Not eager. Lazy. Fuzzy. Conservative. Like moss on rock — slow, only where
# moisture collects enough to warrant it.
#
# PHILOSOPHY:
#   Mitosis is a STOCHASTIC LEVER in the idle maintenance loop, same as
#   chatter/phagy. It does NOT fire every idle cycle. It rolls a coinflip
#   first. Most idle cycles, nothing grows. That's by design.
#
#   When it DOES roll heads, it checks WARRANT — is there enough DATA and
#   ENERGY to justify growth? Warrant thresholds are HIGH. Growth must be
#   earned, not assumed. Better to miss a growth opportunity than to grow
#   junk nodes that pollute the topology.
#
#   When a node IS grown, it MUST find a related non-UNLINKABLE neighbor
#   to latch onto. No floaters. Every new node connects to the existing
#   web or it doesn't get planted. This keeps topology coherent.
#
# WARRANT SYSTEM (five sources, all conservative):
#   1. SILENCE MAP      — High-intensity user inputs with no node match.
#                          The cave was silent when it shouldn't have been.
#                          Needs VERY high intensity AND repeated mentions.
#   2. MEMORY FREQUENCY — Words that appear MANY times across messages
#                          with no existing coverage. High bar (>= 5 occurrences).
#   3. THESAURUS GAPS   — Synonyms of existing patterns not yet covered.
#                          Only if similarity is VERY high (>= 0.8).
#   4. LOBE COVERAGE    — Lobes with severe under-population relative to
#                          their subject words. Very conservative ratio gate.
#   5. ATTACHMENT IMPLICATIONS — Crystalized attachments whose connector
#                          concept has no node. Only crystalized, not tentative.
#
# ARCHITECTURE:
#   Follows ChatterMode/PhagyMode pattern: NO `using ..GrugBot420`.
#   All state is passed as parameters. This module is self-contained.
#
# STOCHASTIC LEVER (DATA-DRIVEN):
#   MITOSIS_PROBABILITY is the CEILING, not a flat rate. 0.15 = 15% max.
#   Actual probability = data_energy * MITOSIS_PROBABILITY.
#   data_energy comes from recent user messages (count + intensity).
#   No recent user data → data_energy = 0 → zero mitosis chance.
#   With data_energy = 1.0, it's 15% per eligible idle cycle (same as before).
#   Combined with the 120s ±30s idle timer and warrant checks, growth is
#   always earned from interaction — never blind.
#
# AUTO-LATCH:
#   Every new mitosis node must find a related non-UNLINKABLE neighbor.
#   Uses the same find_best_latch_target / try_link_nodes! path as /grow.
#   If no latch target exists (all related nodes UNLINKABLE or no similarity),
#   the node is still planted but a warning is logged. It's better to have
#   an isolated node covering a gap than no node at all — but we always
#   prefer connection.
#
# SAFETY:
#   - One bud per cycle max
#   - MIN_POPULATION_GATE = 10 (tiny specimens can grow)
#   - MAX_POPULATION_CAP = 10000
#   - Cooldown 5 idle cycles between successful mitosis (lazy, not fast)
#   - Stochastic gate: data_energy * 15% ceiling (no data = no growth)
#   - High warrant thresholds: growth must be EARNED
#   - No silent failures — every mitosis event is logged
#   - Auto-latch to non-UNLINKABLE neighbors (skip locked nodes)
#
# ==============================================================================

module MitosisMode

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

using Random
using Base.Threads: ReentrantLock

export run_mitosis!, MitosisStats, get_mitosis_log, MitosisError, get_mitosis_status_summary
export MITOSIS_PROBABILITY, DATA_ENERGY_MSG_SCALE, DATA_ENERGY_INTENSITY_SCALE
export MITOSIS_GROUP_STRENGTH_FLOOR, MITOSIS_NOVELTY_COVERAGE_FLOOR
export STRAIN_WARRANT_WEIGHT, STRAIN_WARRANT_ACTIVE_THRESHOLD  # GRUG v7.50: hippocampal strain warrant
export LATCH_SCAN_CONFIDENCE_FLOOR, THES_LATCH_WEIGHT, LATCH_CANDIDATE_TOP_N  # GRUG v9.2: relational+thesaurus latching

# ==============================================================================
# ERROR TYPE
# ==============================================================================

struct MitosisError <: Exception
    msg::String
end

Base.showerror(io::IO, e::MitosisError) =
    print(io, "MitosisError: ", e.msg)

# ==============================================================================
# MITOSIS STATS
# ==============================================================================

struct MitosisStats
    source::String          # Which warrant source triggered this mitosis
    new_node_id::String     # ID of the newly grown node ("" if no growth)
    new_pattern::String     # Pattern of the new node
    target_lobe::String     # Lobe the node was planted into
    warrant_score::Float64  # How strong the warrant was (0.0-1.0)
    cycle_time_ms::Float64  # Wall time for this cycle
    notes::String           # Human-readable summary
    latched_to::String      # ID of neighbor node latched to ("" if none)
end

# ==============================================================================
# MITOSIS LOG (bounded ring — last 50 cycles)
# ==============================================================================

const MITOSIS_LOG      = MitosisStats[]
const MITOSIS_LOG_LOCK = ReentrantLock()
const MAX_MITOSIS_LOG  = 50

function push_mitosis_log!(stats::MitosisStats)
    lock(MITOSIS_LOG_LOCK) do
        push!(MITOSIS_LOG, stats)
        while length(MITOSIS_LOG) > MAX_MITOSIS_LOG
            deleteat!(MITOSIS_LOG, 1)
        end
    end
end

function get_mitosis_log()::Vector{MitosisStats}
    lock(MITOSIS_LOG_LOCK) do
        collect(MITOSIS_LOG)
    end
end

# ==============================================================================
# CONFIGURATION — LAZY FUZZY CONSERVATIVE
# ==============================================================================

# GRUG: Stochastic lever CEILING. Only 15% of eligible idle cycles even ATTEMPT
# mitosis AT MOST. Combined with 120s ±30s idle timer = ~1 attempt per 13 min
# of idle at peak data. But if there's no new data, this goes to ZERO.
# Growth must be EARNED from data, not from blind coinflips.
const MITOSIS_PROBABILITY       = 0.15

# GRUG: Data-driven gate parameters. The stochastic gate probability is:
#   min(MITOSIS_PROBABILITY, data_energy * MITOSIS_PROBABILITY)
# where data_energy = min(recent_user_msgs / DATA_ENERGY_MSG_SCALE, 1.0)
# If the user hasn't said anything recently, data_energy = 0 and mitosis
# doesn't even TRY. Quiet cave = no growth. Loud cave = growth earns its keep.
const DATA_ENERGY_MSG_SCALE     = 10      # 10 recent user messages = full energy
const DATA_ENERGY_INTENSITY_SCALE = 15.0  # Or 15 accumulated intensity = full energy

const MAX_MITOSIS_PER_CYCLE     = 1       # One bud per cycle, never more
const MIN_POPULATION_GATE       = 10      # Need at least 10 nodes to start
const MAX_POPULATION_CAP        = 10000   # Hard cap — no growth beyond this

# GRUG: Cooldown is LONG. 5 idle cycles between successful mitosis events.
# This is supposed to be slow, like moss. Not fast, like bacteria.
const MITOSIS_COOLDOWN_CYCLES   = 5

# GRUG: Warrant thresholds are HIGH. Growth must be EARNED.
# If in doubt, DON'T grow. Junk nodes are worse than missing nodes.
const SILENCE_WARRANT_THRESHOLD = 2.0     # Intensity must be VERY high (baseline is 1.0)
const SILENCE_WARRANT_MIN_ACCUM = 5.0     # Accumulated intensity across messages must be substantial
const FREQUENCY_WARRANT_MIN     = 5       # A word must appear 5+ times to warrant growth
const THESAURUS_WARRANT_THRESHOLD = 0.8   # Only very similar synonyms count
const LOBE_COVERAGE_RATIO_MIN   = 0.25    # Only severely under-populated lobes trigger
const MIN_WARRANT_THRESHOLD     = 0.5     # Overall warrant must be at least 0.5 (was 0.3)

const MITOSIS_STRENGTH_DEFAULT  = 1.0     # Same as baseline — don't inflate mitosis nodes

# GRUG (v9.1): Group strength threshold — the average strength of the target
# group's alive members must pass this floor for mitosis to latch there.
# Weak groups don't earn new branches. Dead groups are dead for a reason.
const MITOSIS_GROUP_STRENGTH_FLOOR = 0.5  # avg strength must be >= 0.5 (STRENGTH_FLOOR is 0.0, STRENGTH_CAP is 10.0)

# GRUG (v9.2): Relational+thesaurus-guided latching — replaces Jaccard-only
# find_group_latch_candidates with the pattern-bind pipeline (minus votes).
# Three gates must ALL pass for a candidate: scan confidence, relational score,
# and vote overlap. The hard strength floor is replaced with a strength-biased
# coinflip (p_join = avg_strength / STRENGTH_CAP).
const LATCH_SCAN_CONFIDENCE_FLOOR = 0.60  # GRUG: Min high_res_scan confidence for latch candidate
const THES_LATCH_WEIGHT           = 0.30  # GRUG: Thesaurus proximity bonus weight in candidate score
const LATCH_CANDIDATE_TOP_N       = 5     # GRUG: How many top candidates to consider for random pick

# GRUG (v9.1): Novelty gate — how well-covered must the input be for us to
# consider it STALE? If the pattern overlap between the input and existing
# node patterns exceeds this threshold, the input is NOT novel → no mitosis.
# Below this = novel (gap exists, worth branching).
const MITOSIS_NOVELTY_COVERAGE_FLOOR = 0.6  # 60%+ token overlap with existing = stale

# GRUG v7.50: Hippocampal strain warrant — the 6th warrant source.
# When the self-observer feels strain (high novelty + low directive_quality from
# EphemeralMLP), that's an INTERNAL growth signal. Not driven by external data
# patterns, but by the system's felt inability to handle what it's seeing.
# The strain must be confirmed by SelfObserver (hippocampal_warrant_active = true)
# to prevent noise from triggering growth. Cancer prevention: grow for reason, not just because.
# Warrant weight is proportional to strain_energy — higher strain = stronger warrant.
const STRAIN_WARRANT_WEIGHT = 0.7   # base warrant score when strain is at threshold
const STRAIN_WARRANT_ACTIVE_THRESHOLD = 0.55  # strain must be at least this high (matches EphemeralMLP.STRAIN_THRESHOLD)

# ==============================================================================
# COOLDOWN TRACKING
# ==============================================================================

const _mitosis_cooldown = Ref(0)

function _check_cooldown()::Bool
    if _mitosis_cooldown[] > 0
        _mitosis_cooldown[] -= 1
        return false
    end
    return true
end

function _set_cooldown()
    _mitosis_cooldown[] = MITOSIS_COOLDOWN_CYCLES
end

# ==============================================================================\
# STOCHASTIC GATE — data-driven coinflip to even attempt mitosis
# ==============================================================================
# GRUG: The stochastic gate is NOT a blind coinflip anymore. It's modulated
# by how much new data the cave has received since the last idle cycle.
# More user interaction → higher probability of attempting mitosis.
# Silence → zero probability. Growth must be EARNED from data.
#
# data_energy is computed from recent message_history:
#   msg_energy  = min(recent_user_msg_count / DATA_ENERGY_MSG_SCALE, 1.0)
#   int_energy  = min(recent_user_intensity / DATA_ENERGY_INTENSITY_SCALE, 1.0)
#   data_energy = max(msg_energy, int_energy)   — either signal suffices
#
# Effective probability = data_energy * MITOSIS_PROBABILITY
# So: 10 recent user msgs → full 15% attempt rate
#     0 recent user msgs → 0% attempt rate (no data, no growth)
#     5 recent user msgs → 7.5% attempt rate (modest data, modest chance)

function _compute_data_energy(message_snapshots::Vector{Tuple{String, String, Float64}})::Float64
    # GRUG: Count recent user messages and accumulate their intensity.
    # "Recent" = last 50 messages in the snapshot. Not all of history.
    recent = message_snapshots[max(1, length(message_snapshots) - 49):end]
    user_msgs = filter(m -> m[1] == "user", recent)

    msg_count = length(user_msgs)
    total_intensity = sum(m[3] for m in user_msgs; init=0.0)

    msg_energy = min(Float64(msg_count) / Float64(DATA_ENERGY_MSG_SCALE), 1.0)
    int_energy = min(total_intensity / DATA_ENERGY_INTENSITY_SCALE, 1.0)

    # GRUG: Either signal suffices. A few HIGH-intensity messages count
    # just as much as many low-intensity ones. The cave is hungry for data,
    # and it doesn't care whether the data came in big chunks or small.
    return max(msg_energy, int_energy)
end

function _stochastic_gate(message_snapshots::Vector{Tuple{String, String, Float64}};
                           strain_energy::Float64 = 0.0)::Tuple{Bool, Float64}
    data_energy = _compute_data_energy(message_snapshots)
    # GRUG v7.50: Strain energy from EphemeralMLP flows into the stochastic gate.
    # The system doesn't just grow from external data — it grows from internal
    # felt deficit. When strain is high, the gate probability increases even
    # if data_energy is modest. Both signals contribute: external data + internal hurt.
    # Combined energy is max(data_energy, strain_energy) — either signal suffices,
    # same principle as msg_energy vs int_energy within data_energy itself.
    combined_energy = max(data_energy, strain_energy)
    effective_prob = min(combined_energy * MITOSIS_PROBABILITY, MITOSIS_PROBABILITY)
    return (rand() < effective_prob, effective_prob)
end

# ==============================================================================
# HELPER: Extract tokens from a string (lowercase, stripped, no stopwords)
# ==============================================================================

# ==============================================================================
# STRENGTH-BIASED JOIN COINFLIP (v9.2)
# ==============================================================================
# GRUG: Replaces hard MITOSIS_GROUP_STRENGTH_FLOOR threshold with a smooth
# probability curve. A group with avg_strength 0.5 used to be rejected outright
# (below 0.5 floor). Now it has a 5% chance of accepting a new member.
# A group with avg_strength 5.0 has a 50% chance. A group with avg_strength
# 9.0 has a 90% chance. Bio-coherent: weak groups RARELY get new blood,
# but sometimes they do. Strong groups almost always do. No hard wall.
#
# The old hard floor is still exported for /grow backward compat, but the
# autonomous growth path (MitosisMode, TemporalGrowth) uses this coinflip.

function _strength_biased_join_coinflip(avg_strength::Float64;
                                         strength_cap::Float64 = 10.0)::Bool
    # GRUG: Linear bias. p in [0, 1]. clamp for safety.
    p = clamp(avg_strength / strength_cap, 0.0, 1.0)
    # GRUG: Edge case — zero-strength group should never accept (p=0).
    # But a group with even 0.1 strength gets a 1% chance. Bio-coherent:
    # a nearly-dead tissue rarely attracts cells, but it's not impossible.
    p <= 0.0 && return false
    return rand() < p
end

# ==============================================================================
# HELPER: Extract action names from an action_packet string
# ==============================================================================
# GRUG: Same logic as engine.jl _action_names_from_packet but MitosisMode
# is self-contained (no `using ..GrugBot420`). Duplicated here for autonomy.
# Literal pipes in action names use {PIPE}/{{PIPE}} macro decoded after splitting.
_mitosis_expand_action_macro_string(s::AbstractString)::String = replace(replace(String(s), "{{PIPE}}" => "|"), "{PIPE}" => "|")

function _mitosis_action_names_from_packet(packet::String)::Set{String}
    names = Set{String}()
    for part in split(packet, '|')
        p = strip(part)
        isempty(p) && continue
        # Strip inline negatives and weight: action_name[negs]^weight -> action_name
        m = match(r"^(.+?)\[[^\]]*\]", p)
        if !isnothing(m)
            name = strip(m.captures[1])
            !isempty(name) && push!(names, _mitosis_expand_action_macro_string(name))
        else
            # Strip weight suffix: action_name^weight -> action_name
            m2 = match(r"^(.+?)\^", p)
            if !isnothing(m2)
                name = strip(m2.captures[1])
                !isempty(name) && push!(names, _mitosis_expand_action_macro_string(name))
            else
                !isempty(p) && push!(names, _mitosis_expand_action_macro_string(p))
            end
        end
    end
    return names
end

# ==============================================================================
# HELPER: Check if action family is AIML (always singleton)
# ==============================================================================
# GRUG: AIMLNodeSystem removed in v8.12. AIML nodes were executive/template
# nodes that were always singletons. Kept for specimen backward-compat:
# old specimens may still have ACTION_AIML or is_aiml entries. We still
# recognize them as singletons so they don't crash during load.

function _is_singleton_action_family(action_family_name::String, json_data::Dict{String,Any})::Bool
    # GRUG: AIML action family = always singleton (backward-compat)
    action_family_name == "ACTION_AIML" && return true
    # GRUG: Explicit AIML flag in json_data (backward-compat)
    get(json_data, "is_aiml", false) === true && return true
    return false
end

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
    "above", "below", "between", "under", "again", "also", "now"
])

function _tokenize(text::String)::Vector{String}
    tokens = split(lowercase(strip(text)))
    return filter(t -> length(t) > 2 && !(t in STOPWORDS), String.(tokens))
end

# ==============================================================================
# PATTERN BIND: ACTIVATORS + VERBS (v9.1)
# ==============================================================================
# GRUG: Pattern is not just stripped question content. Pattern = ACTIVATORS
# (question markers, command markers) BIND to their content targets. The
# activator gives the node its semantic ROLE (query, command, etc.), and the
# bound content gives it its semantic TOPIC. Together they form the full pattern.
#
# "Why is the sky blue?" → activator="why" binds "sky blue" → pattern="why sky blue"
# "Calculate the total" → activator="calculate" binds "total" → pattern="calculate total"
# "Maybe consciousness exists" → no activator, verb="exists" binds "consciousness" → pattern="consciousness exists"
#
# The activator-verb bind means the pattern carries its OWN activation key —
# a node with pattern "why sky blue" will match "why" questions about the sky,
# not just any mention of sky/blue. The activator IS the question expectation.
# The verb carries the action semantic. Both must be present for proper binding.
#
# For ACTION_QUERY (1): activator = question marker, pattern = activator + content
# For ACTION_COMMAND (2): activator = command marker, pattern = activator + content
# For others: activator = leading verb (if any), pattern = verb + content

const _ACTIVATOR_MARKERS = Set([
    # Question markers (from InputDecomposer)
    "what", "who", "where", "when", "why", "how", "which", "whose", "whom",
    # Command markers (from InputDecomposer)
    "tell", "show", "give", "explain", "describe", "calculate", "compute",
    "solve", "define", "list", "name", "find", "count",
])

function _extract_activator_verb_pattern(input_text::String, action_family_int::Union{Int, Nothing})::String
    tokens_raw = split(lowercase(strip(input_text)))
    isempty(tokens_raw) && return strip(input_text)

    # GRUG: Find the first activator marker in the input (question or command word)
    activator = nothing
    content_start = 1
    for (i, t) in enumerate(tokens_raw)
        if t in _ACTIVATOR_MARKERS
            activator = t
            content_start = i + 1
            break
        end
    end

    # GRUG: Extract content tokens after the activator, filtering stopwords and short tokens
    content_tokens = filter(t -> length(t) > 2 && !(t in STOPWORDS) && !(t in _ACTIVATOR_MARKERS),
                            String.(tokens_raw[content_start:end]))

    # GRUG: If no activator found, look for the leading VERB instead.
    # Verbs carry action semantics — they're the "what's being done" key.
    if activator === nothing
        # GRUG: Find the first non-stopword token that looks like a verb.
        # Simple heuristic: tokens that aren't common nouns (determiners, pronouns).
        # We just take the first content token as the "verb anchor".
        if !isempty(content_tokens)
            activator = content_tokens[1]
            content_tokens = length(content_tokens) > 1 ? content_tokens[2:end] : String[]
        end
    end

    # GRUG: Assemble pattern: activator + up to 3 content tokens
    if activator !== nothing
        max_content = min(length(content_tokens), 3)
        if max_content > 0
            return strip(join(vcat([activator], content_tokens[1:max_content]), " "))
        else
            return strip(activator)
        end
    end

    # GRUG: No activator, no verb — fall back to top content tokens (max 4)
    if !isempty(content_tokens)
        max_tokens = min(length(content_tokens), 4)
        return strip(join(content_tokens[1:max_tokens], " "))
    end

    # GRUG: Total fallback — return stripped original
    return strip(input_text)
end

# ==============================================================================
# NOVELTY GATE — is the user input novel or stale? (v9.1)
# ==============================================================================
# GRUG: Mitosis only triggers on NOVEL user input. "Novel" means the input's
# content tokens are NOT already well-covered by existing node patterns.
# The last 10,000 user inputs (MESSAGE_HISTORY, MAX_HISTORY=10000) plus
# constant pins form the input pool. We check the MOST RECENT user input
# against existing coverage. Pinned messages are "constant" — they always
# contribute to data_energy even if old (they're explicitly marked as important).
#
# Coverage check: tokenize the input, check each token against existing patterns.
# If coverage_ratio >= MITOSIS_NOVELTY_COVERAGE_FLOOR, the input is STALE.
# Below that = novel (gaps exist, worth branching a new node).

function _check_input_novelty(
    input_text::String,
    node_snapshots::Vector{Tuple{String, Bool}}
)::Tuple{Bool, Float64}
    # GRUG: Returns (is_novel, coverage_ratio)
    # is_novel = true means the input has uncovered content → mitosis may proceed
    # coverage_ratio = fraction of input tokens already covered by existing patterns

    isempty(strip(input_text)) && return (false, 1.0)

    tokens = _tokenize(input_text)
    isempty(tokens) && return (false, 1.0)

    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    covered_count = 0
    for tok in tokens
        if _is_covered(tok, existing_patterns)
            covered_count += 1
        end
    end

    coverage_ratio = Float64(covered_count) / Float64(length(tokens))

    # GRUG: Novel if coverage is BELOW the floor. Gaps = novel.
    is_novel = coverage_ratio < MITOSIS_NOVELTY_COVERAGE_FLOOR

    return (is_novel, coverage_ratio)
end
# GRUG: Instead of exact substring match, use fuzzy coverage. A token is
# "covered" if it appears as a whole word in an existing pattern, OR if
# an existing pattern is a very close match (Jaccard > 0.5). This prevents
# growing "scared" when "sacred" exists — they're not actually similar
# enough. Conservative fuzzy matching, not greedy.

function _is_covered(token::String, existing_patterns::Set{String})::Bool
    tok_lower = lowercase(strip(token))
    tok_words = Set(split(tok_lower))

    for pat in existing_patterns
        pat_words = Set(split(pat))

        # GRUG: Token is a whole word in this pattern → covered
        if tok_lower in pat_words
            return true
        end

        # GRUG: Single-word token: check if it's a substring of a single-word pattern
        # But ONLY if the pattern is also single-word (no false "sacred"/"scared" matches)
        if length(tok_words) == 1 && length(pat_words) == 1
            # Only count as covered if one is a prefix of the other AND
            # the length difference is small (max 2 chars — "run"/"running" ok,
            # "run"/"runt" barely ok, "scare"/"sacred" no)
            if startswith(tok_lower, pat) || startswith(pat, tok_lower)
                len_diff = abs(length(tok_lower) - length(pat))
                if len_diff <= 2
                    return true
                end
            end
        end

        # GRUG: Jaccard similarity for multi-word patterns
        if length(tok_words) > 1 || length(pat_words) > 1
            intersection = length(intersect(tok_words, pat_words))
            union_size = length(union(tok_words, pat_words))
            if union_size > 0 && Float64(intersection) / Float64(union_size) > 0.5
                return true
            end
        end
    end

    return false
end

# ==============================================================================
# SOURCE 1: SILENCE MAP WARRANT (CONSERVATIVE)
# ==============================================================================
# GRUG: Only fires for VERY high-intensity user messages with NO node match.
# The bar is high: intensity >= 2.0 AND accumulated intensity >= 5.0.
# One message at intensity 2.5 isn't enough. The cave needs to hear the
# same gap repeatedly before it grows to fill it.

function _silence_warrant(;
    node_snapshots::Vector{Tuple{String, Bool}},
    message_snapshots::Vector{Tuple{String, String, Float64}},
)::Union{Tuple{String, String, Float64}, Nothing}
    # GRUG: Filter to VERY high-intensity user messages
    recent_user_msgs = filter(m -> m[1] == "user" && m[3] >= SILENCE_WARRANT_THRESHOLD,
                              message_snapshots)

    isempty(recent_user_msgs) && return nothing

    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    # GRUG: Accumulate intensity per uncovered token
    token_intensity = Dict{String, Float64}()
    for (_, text, intensity) in recent_user_msgs
        tokens = _tokenize(text)
        for tok in tokens
            _is_covered(tok, existing_patterns) && continue
            token_intensity[tok] = get(token_intensity, tok, 0.0) + intensity
        end
    end

    isempty(token_intensity) && return nothing

    best_tok = argmax(token_intensity)
    best_accum = token_intensity[best_tok]

    # GRUG: Must have SUBSTANTIAL accumulated intensity
    best_accum < SILENCE_WARRANT_MIN_ACCUM && return nothing

    warrant = min(best_accum / 10.0, 1.0)
    return (best_tok, "silence_map", warrant)
end

# ==============================================================================
# SOURCE 2: MEMORY FREQUENCY WARRANT (CONSERVATIVE)
# ==============================================================================
# GRUG: A word must appear 5+ times across user messages with no existing
# coverage. That's a LOT of repetition. Growth is earned.

function _frequency_warrant(;
    node_snapshots::Vector{Tuple{String, Bool}},
    message_snapshots::Vector{Tuple{String, String, Float64}},
)::Union{Tuple{String, String, Float64}, Nothing}
    all_user_msgs = filter(m -> m[1] == "user", message_snapshots)
    length(all_user_msgs) < 5 && return nothing

    token_counts = Dict{String, Int}()
    for (_, text, _) in all_user_msgs
        for tok in _tokenize(text)
            token_counts[tok] = get(token_counts, tok, 0) + 1
        end
    end

    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    candidates = Dict{String, Int}()
    for (tok, count) in token_counts
        count >= FREQUENCY_WARRANT_MIN || continue
        _is_covered(tok, existing_patterns) && continue
        candidates[tok] = count
    end

    isempty(candidates) && return nothing

    best_tok = argmax(candidates)
    best_count = candidates[best_tok]
    warrant = min(best_count / 20.0, 1.0)  # GRUG: Need 20+ mentions for warrant=1.0

    return (best_tok, "memory_frequency", warrant)
end

# ==============================================================================
# SOURCE 3: THESAURUS GAP WARRANT (CONSERVATIVE)
# ==============================================================================
# GRUG: Only VERY similar synonyms (>= 0.8) count. If the thesaurus says
# "scared" is similar to "afraid" at 0.85, that's warrant. But "scared"
# similar to "concerned" at 0.4 is NOT warrant. Conservative.

function _thesaurus_warrant(;
    node_snapshots::Vector{Tuple{String, Bool, String}},
    all_patterns::Set{String},
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
)::Union{Tuple{String, String, Float64}, Nothing}
    single_word = filter(n -> !n[2] && length(split(n[1])) == 1, node_snapshots)

    isempty(single_word) && return nothing

    best_gap = nothing
    best_score = 0.0

    for (pat, _, node_id) in single_word
        word = lowercase(strip(pat))
        try
            expanded = thesaurus_gate_filter(word)
            for synonym in expanded
                syn_lower = lowercase(strip(synonym))
                _is_covered(syn_lower, all_patterns) && continue

                sim = thesaurus_word_similarity(word, synonym)
                if sim >= THESAURUS_WARRANT_THRESHOLD && sim > best_score
                    best_gap = (synonym, node_id)
                    best_score = sim
                end
            end
        catch
            continue
        end
    end

    best_gap === nothing && return nothing

    (synonym, parent_id) = best_gap
    return (synonym, "thesaurus_gap", best_score)
end

# ==============================================================================
# SOURCE 4: LOBE COVERAGE WARRANT (CONSERVATIVE)
# ==============================================================================
# GRUG: Only SEVERELY under-populated lobes trigger. A lobe needs
# < 0.25 nodes/subject_word ratio. And the uncovered word must not be
# trivially short. Growth here is very lazy.

function _lobe_coverage_warrant(;
    node_snapshots::Vector{Tuple{String, Bool}},
    lobe_snapshots::Vector{Tuple{String, String, Set{String}}},
)::Union{Tuple{String, String, Float64}, Nothing}
    isempty(lobe_snapshots) && return nothing

    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    best_gap = nothing
    best_score = 0.0

    for (lobe_id, subject, node_ids) in lobe_snapshots
        subject_words = split(lowercase(subject))
        subject_words = filter(w -> length(w) > 3 && !(w in STOPWORDS), String.(subject_words))

        node_count = length(node_ids)

        uncovered = filter(w -> !_is_covered(w, existing_patterns), subject_words)

        coverage_ratio = isempty(subject_words) ? 1.0 : node_count / length(subject_words)

        # GRUG: Only severely under-populated lobes
        if coverage_ratio < LOBE_COVERAGE_RATIO_MIN && !isempty(uncovered)
            word = rand(uncovered)
            score = 1.0 - coverage_ratio
            if score > best_score
                best_gap = (word, lobe_id)
                best_score = score
            end
        end
    end

    best_gap === nothing && return nothing

    (word, lobe_id) = best_gap
    return (word, "lobe_coverage", best_score)
end

# ==============================================================================
# SOURCE 5: ATTACHMENT IMPLICATION WARRANT (CONSERVATIVE)
# ==============================================================================
# GRUG: Only CRYSTALIZED attachments whose connector concept has no node.
# Tentative attachments are NOT warrant — they might be transient.

function _attachment_warrant(;
    node_snapshots::Vector{Tuple{String, Bool}},
    attachment_snapshots::Vector{Tuple{String, String, Bool}},
)::Union{Tuple{String, String, Float64}, Nothing}
    isempty(attachment_snapshots) && return nothing

    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    for (target_id, connector, is_crystalized) in attachment_snapshots
        if is_crystalized && length(connector) > 3  # GRUG: Min 4 chars, not trivial
            conn_lower = lowercase(strip(connector))
            _is_covered(conn_lower, existing_patterns) && continue
            # GRUG: Only the first uncovered crystalized attachment wins
            # (one bud per cycle, conservative)
            return (connector, "attachment_implication", 0.75)
        end
    end

    return nothing
end


# ==============================================================================
# SOURCE 6: Hippocampal strain warrant (GRUG v7.50)
# ==============================================================================
# GRUG: The system HURTS — it sees novel input it can't handle well.
# SelfObserver confirms the hurt is real (hippocampal_warrant_active).
# This warrant says: "Grow something to handle what you can't."
# The strain_energy scalar (0.0-1.0) determines warrant strength.
# Higher strain = stronger warrant = more likely to beat other candidates.
#
# This is the endocrine bridge: EphemeralMLP strain signal → MitosisMode growth.
# The organism doesn't just grow from external data. It grows from internal deficit.
# Without this, growth is purely reactive. With it, growth is also driven by
# the system's own assessment of its structural insufficiency.

function _hippocampal_strain_warrant(;
    strain_energy::Float64,
    hippocampal_warrant_active::Bool,
    node_snapshots::Vector{Tuple{String, Bool}},
    message_snapshots::Vector{Tuple{String, String, Float64}},
)::Union{Tuple{String, String, Float64}, Nothing}
    # GRUG: No warrant if SelfObserver hasn't confirmed the strain.
    # This is the cancer-prevention gate: strain alone isn't enough.
    # The system must also have its own internal confirmation that
    # the strain reflects a real structural deficit, not just noise.
    !hippocampal_warrant_active && return nothing

    # GRUG: Strain below the active threshold means the hurt isn't
    # strong enough to warrant growth. Mild discomfort ≠ growth signal.
    strain_energy < STRAIN_WARRANT_ACTIVE_THRESHOLD && return nothing

    # GRUG: What should we grow? The pattern comes from the MOST RECENT
    # user message — that's the stimulus causing the strain. The system
    # hurts because of what it just saw and couldn't handle.
    # Extract the most intense recent user message as the growth target.
    user_msgs = [(text, intensity) for (role, text, intensity) in message_snapshots
                 if role == "user" && !isempty(strip(text))]
    isempty(user_msgs) && return nothing

    # GRUG: Pick the most intense user message — the one that hurts most.
    _, max_idx = findmax(m -> m[2], user_msgs)
    target_text = strip(user_msgs[max_idx][1])

    # GRUG: Jitter the text to get a pattern (same as other warrant sources).
    # If the exact text already exists as a node, it's covered — no warrant.
    existing_patterns = Set(lowercase(strip(pat)) for (pat, grave) in node_snapshots
                           if !grave)

    # GRUG: Try the full text first, then progressively shorter substrings.
    # This mirrors how _silence_warrant works — find an UNCOVERED pattern.
    pattern = lowercase(strip(target_text))
    if _is_covered(pattern, existing_patterns)
        # Try first sentence / phrase
        pattern = lowercase(strip(split(target_text, r"[.!?]")[1]))
        if _is_covered(pattern, existing_patterns)
            # Try first few words
            words = split(target_text)
            if length(words) >= 2
                pattern = lowercase(strip(join(words[1:min(3, length(words))], " ")))
                if _is_covered(pattern, existing_patterns)
                    return nothing  # Already covered at every granularity
                end
            else
                return nothing
            end
        end
    end

    # GRUG: Warrant score is proportional to strain_energy, scaled by weight.
    # At STRAIN_WARRANT_ACTIVE_THRESHOLD, score ≈ 0.39. At 1.0, score ≈ 0.7.
    # This competes with other sources — silence_map typically scores 0.85+,
    # so hippocampal strain wins when other sources are quiet but strain is high.
    warrant_score = strain_energy * STRAIN_WARRANT_WEIGHT

    return (pattern, "hippocampal_strain", warrant_score)
end

# ==============================================================================
# BUD SELECTION — Pick the best warrant source
# ==============================================================================

function _select_bud(;
    node_snapshots::Vector{Tuple{String, Bool}},
    node_with_ids::Vector{Tuple{String, Bool, String}},
    all_patterns::Set{String},
    message_snapshots::Vector{Tuple{String, String, Float64}},
    lobe_snapshots::Vector{Tuple{String, String, Set{String}}},
    attachment_snapshots::Vector{Tuple{String, String, Bool}},
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    strain_energy::Float64 = 0.0,                           # GRUG v7.50: hippocampal strain
    hippocampal_warrant_active::Bool = false,               # GRUG v7.50: SelfObserver confirmation
)::Union{Tuple{String, String, Float64}, Nothing}
    candidates = Tuple{String, String, Float64}[]

    # Source 1: Silence map (highest priority — unmet needs)
    result = _silence_warrant(node_snapshots=node_snapshots,
                              message_snapshots=message_snapshots)
    result !== nothing && push!(candidates, result)

    # Source 2: Memory frequency
    result = _frequency_warrant(node_snapshots=node_snapshots,
                                message_snapshots=message_snapshots)
    result !== nothing && push!(candidates, result)

    # Source 3: Thesaurus gaps
    result = _thesaurus_warrant(node_snapshots=node_with_ids,
                                all_patterns=all_patterns,
                                thesaurus_gate_filter=thesaurus_gate_filter,
                                thesaurus_word_similarity=thesaurus_word_similarity)
    result !== nothing && push!(candidates, result)

    # Source 4: Lobe coverage
    result = _lobe_coverage_warrant(node_snapshots=node_snapshots,
                                    lobe_snapshots=lobe_snapshots)
    result !== nothing && push!(candidates, result)

    # Source 5: Attachment implications
    result = _attachment_warrant(node_snapshots=node_snapshots,
                                 attachment_snapshots=attachment_snapshots)
    result !== nothing && push!(candidates, result)

    # Source 6: Hippocampal strain (GRUG v7.50)
    # GRUG: The system hurts from novel input it can't handle. SelfObserver
    # confirms the hurt is real. This warrant grows structure to fill the gap.
    result = _hippocampal_strain_warrant(strain_energy=strain_energy,
                                         hippocampal_warrant_active=hippocampal_warrant_active,
                                         node_snapshots=node_snapshots,
                                         message_snapshots=message_snapshots)
    result !== nothing && push!(candidates, result)

    isempty(candidates) && return nothing

    best = argmax(c -> c[3], candidates)
    best[3] < MIN_WARRANT_THRESHOLD && return nothing

    return best
end

# ==============================================================================
# NODE GENERATION — Actually grow the node + auto-latch
# ==============================================================================

function _infer_lobe(pattern::String, source::String;
                     node_lobe_hints::Vector{Tuple{String, String}},
                     thesaurus_word_similarity::Function = (a,b) -> 0.0
)::String
    pattern_lower = lowercase(pattern)

    # Strategy 1: Substring match to existing node's lobe_hint
    for (pat, hint) in node_lobe_hints
        if occursin(pattern_lower, lowercase(pat)) || occursin(lowercase(pat), pattern_lower)
            return hint
        end
    end

    # Strategy 2: Thesaurus similarity to find a lobe-neighbor
    best_hint = nothing
    best_sim = 0.5
    for (pat, hint) in node_lobe_hints
        if length(split(pat)) == 1
            try
                sim = thesaurus_word_similarity(pattern, pat)
                if sim > best_sim
                    best_hint = hint
                    best_sim = sim
                end
            catch
                continue
            end
        end
    end
    best_hint !== nothing && return best_hint

    # Strategy 3: Default assignment by keyword heuristics
    emotion_words = ["sad", "happy", "angry", "afraid", "scared", "fear",
                     "worry", "love", "hate", "grief", "mourn", "joy",
                     "lonely", "hurt", "pain", "comfort", "cry", "laugh",
                     "anxious", "anxiety"]
    survival_words = ["danger", "run", "predator", "storm", "flood",
                      "fire", "alert", "warn", "hide", "safe", "emergency",
                      "threat", "escape", "shelter"]
    philosophy_words = ["meaning", "truth", "exist", "consciousness",
                       "reality", "why", "purpose", "wonder", "think",
                       "know", "believe", "understand", "question"]
    science_words = ["observe", "describe", "explain", "measure",
                    "experiment", "calculate", "analyze", "discover",
                    "evidence", "proof", "theory"]
    social_words = ["hello", "friend", "tribe", "belong", "greet",
                   "welcome", "goodbye", "trust", "share", "together"]
    math_words = ["number", "count", "add", "plus", "minus", "multiply",
                  "divide", "equal", "sum", "calculate"]
    reason_words = ["reason", "logic", "infer", "deduce", "conclude",
                   "because", "therefore", "premise", "argument"]

    if any(w -> occursin(w, pattern_lower), emotion_words)
        return "EmotionLobe"
    elseif any(w -> occursin(w, pattern_lower), survival_words)
        return "SurvivalLobe"
    elseif any(w -> occursin(w, pattern_lower), philosophy_words)
        return "PhilosophyLobe"
    elseif any(w -> occursin(w, pattern_lower), science_words)
        return "ScienceLobe"
    elseif any(w -> occursin(w, pattern_lower), social_words)
        return "SocialLobe"
    elseif any(w -> occursin(w, pattern_lower), math_words)
        return "MathLobe"
    elseif any(w -> occursin(w, pattern_lower), reason_words)
        return "ReasoningLobe"
    end

    return "default"
end

# ==============================================================================
# ACTION PACKET FROM SEMANTIC ACTION SUBSYSTEM
# ==============================================================================
# GRUG: The action_packet tells a new node HOW to vote. Old way was hardcoded
# per lobe name — dumb. New way: derive from the ACTION semantic subsystem.
# What the user is DOING determines how the new node should act.
#
# ACTION_ASSERT   → node should assert/declare (the user stated something)
# ACTION_QUERY    → node should question/explore (the user asked something)
# ACTION_COMMAND  → node should command/direct (the user told us to do something)
# ACTION_NEGATE   → node should reject/refute (the user contradicted something)
# ACTION_SPECULATE → node should speculate/hedge (the user was uncertain)
# ACTION_ESCALATE → node should escalate/urgently act (the user was alarmed)
#
# When no semantic prediction is available (old behavior), falls back to
# lobe-name-based defaults. But semantic ALWAYS takes priority.

const _ACTION_FAMILY_PACKETS = Dict{Int, String}(
    # ACTION_ASSERT (0) — declarative claim, stating a fact
    0 => "declare[certainly]^3 | assert[firmly]^2 | state[clearly]^1",
    # ACTION_QUERY (1) — requesting information, asking
    1 => "question[curiously]^4 | explore[carefully]^3 | inquire[gently]^1",
    # ACTION_COMMAND (2) — directive, imperative structure
    2 => "command[directly]^3 | direct[immediately]^2 | execute[swiftly]^1",
    # ACTION_NEGATE (3) — contradiction or rejection
    3 => "reject[firmly]^3 | refute[clearly]^2 | deny[categorically]^1",
    # ACTION_SPECULATE (4) — epistemic hedge, incomplete chain
    4 => "speculate[thoughtfully]^3 | hypothesize[carefully]^2 | wonder[openly]^1",
    # ACTION_ESCALATE (5) — emotional spike, urgency burst
    5 => "escalate[urgently]^4 | alert[immediate]^3 | insist[strongly]^2",
)

# GRUG: Map ActionFamily integer values to human-readable names for json_data
const _ACTION_FAMILY_NAMES = Dict{Int, String}(
    0 => "ACTION_ASSERT",
    1 => "ACTION_QUERY",
    2 => "ACTION_COMMAND",
    3 => "ACTION_NEGATE",
    4 => "ACTION_SPECULATE",
    5 => "ACTION_ESCALATE",
)

# ==============================================================================
# QUESTION PATTERN EXTRACTION - derive pattern from question semantic subsystem
# ==============================================================================
# GRUG: When the user's input is classified as ACTION_QUERY (they're asking
# something), the new node's pattern should reflect WHAT is being asked.
# We extract the question topic by stripping question markers and keeping
# the content words. "Why is the sky blue?" -> pattern = "sky blue".
# "What is consciousness?" -> pattern = "consciousness".
#
# This is the question semantic subsystem: pattern = what's being ASKED.
# The action subsystem (above) handles: vote = what's being DONE.

const _QUESTION_MARKERS = Set([
    "what", "who", "where", "when", "why", "how",
    "which", "whose", "whom"
])

function _extract_question_pattern(input_text::String)::String
    tokens = split(lowercase(strip(input_text)))
    # GRUG: Drop question markers, stopwords, and short tokens
    content_tokens = filter(t -> length(t) > 2 &&
                                 !(t in _QUESTION_MARKERS) &&
                                 !(t in STOPWORDS),
                            String.(tokens))
    if isempty(content_tokens)
        # GRUG: No content after stripping markers? Return the best token we have.
        all_tokens = filter(t -> length(t) > 1, String.(tokens))
        isempty(all_tokens) && return strip(input_text)
        return all_tokens[1]
    end
    # GRUG: Join top content tokens as pattern (max 4 to keep patterns tight)
    max_tokens = min(length(content_tokens), 4)
    return strip(join(content_tokens[1:max_tokens], " "))
end

function _infer_action_packet(pattern::String, lobe_hint::String;
                              lobe_action_packets::Vector{Tuple{String, String}},
                              action_family_int::Union{Int, Nothing} = nothing
)::String
    # GRUG: SEMANTIC PRIORITY — if we have an ActionFamily from the user's
    # input classification, use it. The action subsystem tells us what the
    # user is DOING, and the new node's vote should match that action type.
    # Pattern is about what's being ASKED. Vote is about what's being DONE.
    if action_family_int !== nothing && haskey(_ACTION_FAMILY_PACKETS, action_family_int)
        return _ACTION_FAMILY_PACKETS[action_family_int]
    end

    # GRUG: FALLBACK — same-lobe nodes or hardcoded defaults (old behavior)
    same_lobe = filter(t -> t[1] == lobe_hint, lobe_action_packets)
    if !isempty(same_lobe)
        return rand(same_lobe)[2]
    end

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

    return get(default_packets, lobe_hint, default_packets["default"])
end

function _infer_system_prompt(pattern::String, lobe_hint::String)::String
    prompts = Dict(
        "EmotionLobe"     => "Grug feel things deeply. Grug understand $pattern because Grug has felt it too.",
        "SurvivalLobe"    => "Grug know about $pattern. Grug protect tribe from what can hurt us.",
        "PhilosophyLobe"  => "Grug wonder about $pattern. Big thoughts live in small caves sometimes.",
        "ScienceLobe"     => "Grug observe $pattern carefully. Truth shows up when Grug look close.",
        "SocialLobe"      => "Grug welcome tribe. $pattern is part of what makes us together.",
        "MathLobe"        => "Grug count rocks careful. $pattern is another kind of counting.",
        "ReasoningLobe"   => "Grug think step by step. $pattern requires careful thought.",
        "default"         => "Grug think about $pattern. One more rock for Grug's wall of knowing.",
    )

    template = get(prompts, lobe_hint, prompts["default"])
    return replace(template, "\$pattern" => pattern)
end

# ==============================================================================
# MAIN MITOSIS FUNCTION — lazy fuzzy conservative stochastic lever
# ==============================================================================

"""
    run_mitosis!(; kwargs...)

GRUG: Run one mitosis cycle — MAYBE. It's a data-driven stochastic lever.
First, snapshot recent messages and compute data_energy. If there's no
new user data, the stochastic gate probability is ZERO — no growth without
data, period. With data, probability scales up to MITOSIS_PROBABILITY (15%).
If the gate doesn't roll, return immediately with "skipped_stochastic_gate".
If it does roll, check cooldown, then population, then warrant.
One bud per cycle max. No silent failures. Big-O safe.

Required kwargs:
  - node_map, node_lock: the live NODE_MAP and its lock
  - message_history, history_lock: MESSAGE_HISTORY and its lock
  - thesaurus_gate_filter: function word -> Vector{String}
  - thesaurus_word_similarity: function (word1, word2) -> Float64
  - create_node_fn: function (pattern, action_packet, data, drop_table; initial_strength) -> String
  - lobe_registry: the LOBE_REGISTRY dict (or empty dict)
  - attachment_map: the ATTACHMENT_MAP dict (or empty dict)
  - immune_gate_fn: function (pattern, data) -> Bool (or nothing)
  - stochastic_aiml_growth_fn: NO-OP since v8.12 (AIMLNodeSystem removed). Kept as kwarg for backward-compat.

Semantic subsystem kwargs (mitosis v9 — pattern from questions, vote from actions):
  - prediction_fn: function () -> Union{Nothing, PredictionResult} (or nothing)
      Returns the last ActionTonePredictor result. Used to derive action_family
      for the action packet (vote = what's being DONE) and to detect ACTION_QUERY
      for question-pattern extraction (pattern = what's being ASKED).
  - last_user_text_fn: function () -> Union{Nothing, String} (or nothing)
      Returns the last user message text. Used for question-pattern extraction
      when input is classified as ACTION_QUERY.

Group latch kwargs (mitosis v9 — new nodes latch to groups, not individual nodes):
  - group_latch_fn: function (pattern; node_map, node_lock) -> Vector{GroupLatchCandidate}
      Returns all related candidate groups with pre-computed averages.
      Caller filters by strength floor then picks one at random.
      Analog coherence as digital selection. Empty vector = no eligible group.
  - add_to_group_fn: function (group, node_id) -> Bool
      Adds the new node to its target group after creation.
  - link_to_group_member_fn: function (new_node, group) -> Union{String, Nothing}
      Links the new node to the strongest non-grave, non-unlinkable member
      of the group. Returns the linked member's id, or nothing.
"""
function run_mitosis!(;
    node_map,
    node_lock,
    message_history,
    history_lock,
    thesaurus_gate_filter::Function,
    thesaurus_word_similarity::Function,
    create_node_fn::Function,
    lobe_registry = Dict{String, Any}(),
    attachment_map = Dict{String, Vector}(),
    immune_gate_fn = nothing,
    stochastic_aiml_growth_fn = nothing,  # GRUG v8.12: no-op (AIMLNodeSystem removed)
    # GRUG (v9): Semantic subsystem — pattern from questions, vote from actions
    prediction_fn = nothing,           # () -> Union{Nothing, PredictionResult}
    last_user_text_fn = nothing,       # () -> Union{Nothing, String}
    # GRUG (v9): Group-based latching — new nodes join groups, not individual nodes
    # NOTE: group_latch_fn is kept for /grow backward compat but NOT used in
    # the autonomous growth path anymore (v9.2 replaces it with the
    # relational+thesaurus pipeline via the new kwargs below).
    group_latch_fn = nothing,          # (pattern; node_map, node_lock) -> Vector{GroupLatchCandidate}
    add_to_group_fn = nothing,         # (group, node_id) -> Bool
    link_to_group_member_fn = nothing, # (new_node, group) -> Union{String, Nothing}
    # GRUG v7.50: Hippocampal strain — endocrine bridge from EphemeralMLP
    strain_energy_fn::Union{Function, Nothing} = nothing,            # () -> Float64
    hippocampal_warrant_fn::Union{Function, Nothing} = nothing,     # () -> Bool
    # GRUG (v9.2): Relational+thesaurus-guided latching pipeline — pattern-bind minus votes.
    # These replace the old group_latch_fn call in the autonomous growth path.
    # When all four are provided, the new pipeline is used; when absent,
    # the old group_latch_fn path is preserved for backward compat.
    scan_latch_candidates_fn = nothing,    # (pattern, action_packet; node_map, node_lock, lobe_id, thesaurus_fn) -> Vector{LatchCandidate}
    register_group_fn = nothing,           # (node) -> NodeGroup — creates singleton group
    group_avg_strength_fn = nothing,       # (group; node_map, node_lock) -> Float64
    group_for_fn = nothing,                # (node_id) -> Union{NodeGroup, Nothing} — lookup group by member
    sigil_promote_fn = nothing,            # (text) -> String — SigilPromoter canonicalization
    extract_triples_fn = nothing,           # (text) -> Vector{RelationalTriple} — relational extraction
    evaluate_dialectics_fn = nothing,       # (user_triples, node_triples, req_rels, rel_weights) -> (Float64, Bool)
    words_to_signal_fn = nothing,           # (text) -> Vector{Float64} — float-hash signal for scanner
)::MitosisStats
    t0 = time()

    # GRUG: Snapshot message history FIRST — need it for the data-driven
    # stochastic gate. No point snapshotting anything else if there's no data.
    message_snapshots = lock(history_lock) do
        [(lowercase(m.role), m.text, m.intensity) for m in message_history]
    end

    # GRUG: DATA-DRIVEN STOCHASTIC GATE — probability is modulated by how
    # much new data the cave has. No data = no growth, period. More user
    # interaction → higher probability of attempting mitosis.
    # GRUG v7.50: Strain energy from EphemeralMLP also feeds the gate.
    # Internal deficit can boost gate probability even without fresh data.
    _strain_e = strain_energy_fn !== nothing ? strain_energy_fn() : 0.0
    (gate_passed, effective_prob) = _stochastic_gate(message_snapshots;
                                                      strain_energy=_strain_e)
    if !gate_passed
        return MitosisStats("stochastic_gate", "", "", "", 0.0,
                           (time() - t0) * 1000,
                           "Stochastic gate: mitosis didn't roll this cycle (p=$(round(effective_prob, digits=3)), data_energy=$(round(effective_prob / MITOSIS_PROBABILITY, digits=2)))", "")
    end

    # GRUG: Check cooldown
    if !_check_cooldown()
        return MitosisStats("cooldown", "", "", "", 0.0,
                           (time() - t0) * 1000, "Mitosis on cooldown", "")
    end

    # GRUG: Population gate
    alive_count = lock(node_lock) do
        count(n -> !n.is_grave, values(node_map))
    end

    if alive_count < MIN_POPULATION_GATE
        return MitosisStats("population_gate", "", "", "", 0.0,
                           (time() - t0) * 1000,
                           "Too few nodes ($alive_count < $MIN_POPULATION_GATE)", "")
    end

    if alive_count >= MAX_POPULATION_CAP
        return MitosisStats("population_cap", "", "", "", 0.0,
                           (time() - t0) * 1000,
                           "Population at cap ($alive_count >= $MAX_POPULATION_CAP)", "")
    end

    # GRUG: Snapshot all data for warrant analysis
    node_snapshots = lock(node_lock) do
        [(lowercase(strip(n.pattern)), n.is_grave) for n in values(node_map)]
    end

    node_with_ids = lock(node_lock) do
        [(lowercase(strip(n.pattern)), n.is_grave, n.id) for n in values(node_map)]
    end

    all_patterns = Set(p[1] for p in node_snapshots if !p[2])

    # GRUG: message_snapshots already taken above (needed for stochastic gate).
    # No need to re-snapshot here.

    lobe_snapshots = isempty(lobe_registry) ? Tuple{String, String, Set{String}}[] :
        [(lid, lobe.subject, lobe.node_ids) for (lid, lobe) in lobe_registry]

    attachment_snapshots = isempty(attachment_map) ? Tuple{String, String, Bool}[] :
        begin
            result = Tuple{String, String, Bool}[]
            for (target_id, attachments) in attachment_map
                for att in attachments
                    connector = ""
                    is_crystal = false
                    # GRUG: Handle both struct and dict access patterns
                    # GRUG v8.0: Also handle CascadeBridge (seam_tokens + partner_id)
                    try
                        if hasproperty(att, :seam_tokens)     # GRUG v8.0: CascadeBridge
                            connector = join(att.seam_tokens, " ")
                        elseif hasproperty(att, :pattern)
                            connector = att.pattern
                        elseif hasproperty(att, :connector)
                            connector = att.connector
                        elseif isa(att, Dict)
                            connector = get(att, "connector", get(att, "pattern", ""))
                        end
                        if hasproperty(att, :is_crystalized)
                            is_crystal = att.is_crystalized
                        elseif isa(att, Dict)
                            is_crystal = get(att, "is_crystalized", false)
                        end
                    catch
                        continue
                    end
                    push!(result, (target_id, connector, is_crystal))
                end
            end
            result
        end

    # GRUG: Get lobe hints and action packets from existing nodes
    node_lobe_hints = lock(node_lock) do
        [(lowercase(strip(n.pattern)),
          get(n.json_data, "lobe_hint", "default"))
         for n in values(node_map) if !n.is_grave]
    end

    lobe_action_packets = lock(node_lock) do
        [(get(n.json_data, "lobe_hint", "default"), n.action_packet)
         for n in values(node_map) if !n.is_grave]
    end

    # GRUG: Select the best bud
    # GRUG v7.50: Resolve hippocampal warrant from SelfObserver confirmation.
    _hippo_warrant = hippocampal_warrant_fn !== nothing ? hippocampal_warrant_fn() : false

    bud = _select_bud(
        node_snapshots=node_snapshots,
        node_with_ids=node_with_ids,
        all_patterns=all_patterns,
        message_snapshots=message_snapshots,
        lobe_snapshots=lobe_snapshots,
        attachment_snapshots=attachment_snapshots,
        thesaurus_gate_filter=thesaurus_gate_filter,
        thesaurus_word_similarity=thesaurus_word_similarity,
        strain_energy=_strain_e,                    # GRUG v7.50
        hippocampal_warrant_active=_hippo_warrant,  # GRUG v7.50
    )

    if bud === nothing
        return MitosisStats("no_warrant", "", "", "", 0.0,
                           (time() - t0) * 1000,
                           "No sufficient warrant for mitosis this cycle", "")
    end

    (pattern, source, warrant) = bud

    # ── SEMANTIC SUBSYSTEM INTEGRATION (v9.1) ───────────────────────────────────
    # GRUG: Pattern from ACTIVATORS+VERBS, vote from ACTIONS. Growth driven by
    # nothing but NOVEL user input. The semantic subsystems tell us:
    #   - What is being ASKED/DONE → pattern (activator-verb bind)
    #   - What action TYPE → action_packet (action subsystem)
    #   - Is the input NOVEL? → novelty gate (coverage check)
    #   - Is the target group strong enough? → group strength floor
    # Mitosis = auto-branch new config based on novel input.

    action_family_int = nothing
    action_family_name = "none"
    last_user_text = ""
    novelty_info = "no_input"

    # GRUG: Get semantic prediction from the action-tone predictor.
    # prediction_fn returns the last PredictionResult (or nothing).
    # We use action_family for vote construction and to detect
    # ACTION_QUERY/ACTION_COMMAND for activator-verb pattern extraction.
    if prediction_fn !== nothing
        try
            pred = prediction_fn()
            if pred !== nothing
                action_family_int = Int(pred.action_family)
                action_family_name = get(_ACTION_FAMILY_NAMES, action_family_int, "unknown")
            end
        catch
            # GRUG: Prediction failure = fallback to old behavior. Not fatal.
        end
    end

    # ── NOVELTY GATE (v9.1) ─────────────────────────────────────────
    # GRUG: Mitosis ONLY triggers on novel user input. The last 10,000 user
    # inputs plus constant pins form the input pool. If the most recent user
    # input is already well-covered by existing node patterns, it's STALE
    # → no mitosis. Growth must come from novelty — gaps in coverage.
    # Pinned messages are "constant" — they always contribute to data_energy
    # even if old (they're explicitly marked as important by the operator).
    if last_user_text_fn !== nothing
        try
            user_text = last_user_text_fn()
            if user_text !== nothing && !isempty(strip(user_text))
                last_user_text = user_text
                (is_novel, coverage) = _check_input_novelty(user_text, node_snapshots)
                if !is_novel
                    return MitosisStats("novelty_gate", "", "", "", 0.0,
                                       (time() - t0) * 1000,
                                       "Novelty gate: input stale (coverage=$(round(coverage, digits=2)) >= $(MITOSIS_NOVELTY_COVERAGE_FLOOR)). No novel gaps.", "")
                end
                novelty_info = "novel(coverage=$(round(coverage, digits=2)))"
            end
        catch
            # GRUG: Novelty check failure = proceed cautiously (don't block mitosis on error)
            novelty_info = "novelty_check_error"
        end
    end

    # ── ACTIVATOR-VERB PATTERN BIND (v9.1) ────────────────────────────
    # GRUG: Pattern = activator BIND content. The activator (question marker,
    # command marker, or leading verb) gives the node its activation key.
    # "Why is the sky blue?" → activator="why" binds "sky blue" → "why sky blue"
    # "Calculate the total" → activator="calculate" binds "total" → "calculate total"
    # The activator IS the question expectation. The verb IS the action semantic.
    # Pattern carries its own activation trigger — not just content tokens.
    if action_family_int !== nothing && last_user_text_fn !== nothing
        try
            user_text = last_user_text_fn()
            if user_text !== nothing && !isempty(strip(user_text))
                bound_pattern = _extract_activator_verb_pattern(user_text, action_family_int)
                if !isempty(strip(bound_pattern)) && length(bound_pattern) > 2
                    pattern = bound_pattern
                end
            end
        catch
            # GRUG: Activator-verb bind failure = fallback to warrant token. Not fatal.
        end
    elseif action_family_int === 1 && last_user_text_fn !== nothing
        # GRUG: Legacy path — ACTION_QUERY without full prediction, use question pattern
        try
            user_text = last_user_text_fn()
            if user_text !== nothing && !isempty(strip(user_text))
                question_pat = _extract_question_pattern(user_text)
                if !isempty(strip(question_pat)) && length(question_pat) > 2
                    pattern = question_pat
                end
            end
        catch
            # GRUG: Fallback to warrant token pattern. Not fatal.
        end
    end

    # GRUG: Infer lobe and system prompt from the (possibly rewritten) pattern
    lobe_hint = _infer_lobe(pattern, source;
                            node_lobe_hints=node_lobe_hints,
                            thesaurus_word_similarity=thesaurus_word_similarity)

    # GRUG: ACTION PACKET from the action semantic subsystem.
    # vote = what's being DONE. action_family_int drives the packet style.
    action_packet = _infer_action_packet(pattern, lobe_hint;
                                         lobe_action_packets=lobe_action_packets,
                                         action_family_int=action_family_int)

    system_prompt = _infer_system_prompt(pattern, lobe_hint)

    # GRUG: Build the node data — now includes semantic classification
    json_data = Dict{String, Any}(
        "system_prompt"     => system_prompt,
        "lobe_hint"         => lobe_hint,
        "voice_register"    => "plain",
        "frame_hints"       => ["basic"],
        "noun_anchors"      => [pattern],
        "mitosis_source"    => source,
        "mitosis_warrant"   => warrant,
        "mitosis_born"      => string(round(time(), digits=3)),
        "action_family"     => action_family_name,
        "mitosis_branch"    => true,  # GRUG: This is an auto-branch from novel input
        "novelty_info"      => novelty_info,  # GRUG: Novelty gate result for this mitosis
    )

    # GRUG: Immune gate check (same as /grow)
    if immune_gate_fn !== nothing
        try
            passed = immune_gate_fn(pattern, json_data)
            if !passed
                return MitosisStats("immune_blocked", "", pattern, lobe_hint, warrant,
                                   (time() - t0) * 1000,
                                   "Immune gate blocked mitosis for '$pattern'", "")
            end
        catch e
            return MitosisStats("immune_error", "", pattern, lobe_hint, warrant,
                               (time() - t0) * 1000,
                               "Immune gate error for '$pattern': $e", "")
        end
    end

    # GRUG: CREATE THE NODE! This is an auto-branch — new config from novel input.
    latched_to_id = ""
    latched_group_id = ""
    try
        new_id = create_node_fn(
            pattern,
            action_packet,
            json_data,
            String[];  # no drop_table — group latching handles neighbors
            initial_strength = MITOSIS_STRENGTH_DEFAULT
        )

        # GRUG: Register node into its lobe
        if !isempty(lobe_registry) && haskey(lobe_registry, lobe_hint)
            lobe = lobe_registry[lobe_hint]
            if hasproperty(lobe, :node_ids) && !(new_id in lobe.node_ids)
                push!(lobe.node_ids, new_id)
            end

            # GRUG: STOCHASTIC AIML GROWTH — removed v8.12 (AIMLNodeSystem removed).
            # The :aiml growth_type branch in AutoGrowth is now a no-op.
        end

        # ── GROUP-BASED LATCHING (v9.2 — RELATIONAL+THESAURUS COHERENCE) ────
        # GRUG: New mitosis node finds a group using the relational+thesaurus
        # pipeline (pattern-bind minus votes). Three gates must ALL pass:
        #   1. scan_conf > LATCH_SCAN_CONFIDENCE_FLOOR  (float-hash pattern match)
        #   2. rel_score >= 0                            (relational triple overlap, -9999.0 = hard reject)
        #   3. vote_overlap > MITOSIS_VOTE_SIM_FLOOR     (action_packet name overlap)
        # Hard strength floor is REPLACED by strength-biased coinflip:
        #   p_join = avg_strength / STRENGTH_CAP
        # AIML nodes (backward-compat) and antimatch nodes (REMOVED v8.26h) are ALWAYS singletons — no latching.
        # Match nodes and time nodes participate in the full pipeline.
        # Singletons with <4 connected nodes get NOCHAT label (ChatterMode-ineligible).
        # NO AUTO GROWTH — stochastic gate remains disabled.

        # GRUG: First — node type branch. AIML (backward-compat) and antimatch (REMOVED v8.26h) = always singleton.
        _is_antimatch = false
        _is_singleton_type = false
        try
            new_node_obj = lock(node_lock) do
                get(node_map, new_id, nothing)
            end
            if new_node_obj !== nothing
                _is_antimatch = new_node_obj.is_antimatch_node
                _is_singleton_type = _is_singleton_action_family(action_family_name, json_data)
            end
        catch
            # GRUG: Can't read node? Assume non-singleton, try latching.
            # A read failure shouldn't prevent group assignment.
        end

        if _is_antimatch || _is_singleton_type
            # ── ANTIMATCH/AIML: ALWAYS SINGLETON ──────────────────────────
            # GRUG: Antimatch nodes drain confidence, they don't join groups.
            # AIML nodes were executive templates (AIMLNodeSystem removed v8.12).
            # Both go straight to singleton group. No chatter. No latching.
            try
                if register_group_fn !== nothing
                    new_node_obj = lock(node_lock) do
                        get(node_map, new_id, nothing)
                    end
                    if new_node_obj !== nothing
                        grp = register_group_fn(new_node_obj)
                        if grp !== nothing
                            latched_group_id = grp.id
                        end
                    end
                end
            catch e
                # GRUG: Singleton registration failure is not fatal — node still exists.
                # It just won't have a group yet. Phagy may assign one later.
                latched_group_id = ""
            end

        elseif scan_latch_candidates_fn !== nothing && add_to_group_fn !== nothing
            # ── MATCH/TIME: RELATIONAL+THESAURUS PIPELINE (v9.2) ───────────
            # GRUG: The new pipeline. Canonicalize pattern → extract relational
            # triples → scan candidate nodes with high_res_scan → evaluate
            # relational dialectics → thesaurus bonus → three-gate filter →
            # rank by composite score → random from top-N → strength-biased
            # coinflip → join or singleton+NOCHAT. NO VOTE ACTIVATION.
            try
                candidates = scan_latch_candidates_fn(
                    pattern, action_packet;
                    node_map=node_map,
                    node_lock=node_lock,
                    lobe_id=lobe_hint,
                    thesaurus_fn=thesaurus_word_similarity,
                    # GRUG: Pass the engine functions for the pipeline.
                    # When these are nothing, the scan function falls back
                    # to simpler checks (still better than Jaccard-only).
                    sigil_promote_fn=sigil_promote_fn,
                    extract_triples_fn=extract_triples_fn,
                    evaluate_dialectics_fn=evaluate_dialectics_fn,
                    words_to_signal_fn=words_to_signal_fn,
                )

                if !isempty(candidates)
                    # GRUG: Pick from top-N candidates by score.
                    # Random within top-N = analog coherence, not deterministic best.
                    n_pick = min(LATCH_CANDIDATE_TOP_N, length(candidates))
                    chosen = candidates[rand(1:n_pick)]
                    target_group = chosen.group

                    # GRUG: Strength-biased coinflip replaces hard floor.
                    avg_str = if group_avg_strength_fn !== nothing
                        group_avg_strength_fn(target_group; node_map=node_map, node_lock=node_lock)
                    else
                        # GRUG: Fallback — use pre-computed avg_strength from candidate.
                        try
                            chosen.avg_strength
                        catch
                            0.0
                        end
                    end

                    if _strength_biased_join_coinflip(avg_str)
                        # ── JOIN GROUP ──────────────────────────────────────
                        joined = add_to_group_fn(target_group, new_id)
                        if joined
                            latched_group_id = target_group.id

                            # GRUG: Link to a related member within the group.
                            # Uses existing link_to_group_member which checks
                            # pattern Jaccard + vote overlap thresholds.
                            if link_to_group_member_fn !== nothing
                                try
                                    new_node_obj = lock(node_lock) do
                                        get(node_map, new_id, nothing)
                                    end
                                    if new_node_obj !== nothing
                                        linked_id = link_to_group_member_fn(new_node_obj, target_group)
                                        if linked_id !== nothing
                                            latched_to_id = linked_id
                                        end
                                    end
                                catch e
                                    # GRUG: Link failure is not fatal — node is in the group.
                                    # Missing a neighbor link just means it's not directly
                                    # connected to a member yet. Phagy can fix this later.
                                end
                            end
                        end
                    else
                        # ── COINFLIP LOST: SINGLETON + NOCHAT ───────────────
                        # GRUG: The group wasn't strong enough to earn this node.
                        # Found a new singleton group instead. NOCHAT if <4 neighbors.
                        try
                            if register_group_fn !== nothing
                                new_node_obj = lock(node_lock) do
                                    get(node_map, new_id, nothing)
                                end
                                if new_node_obj !== nothing
                                    grp = register_group_fn(new_node_obj)
                                    if grp !== nothing
                                        latched_group_id = grp.id
                                        # GRUG: NOCHAT rule — singleton groups with <4 connected
                                        # nodes are invisible to ChatterMode. Prevents whacky remixes
                                        # from under-populated groups. Graduate out at 4+ nodes.
                                        if length(new_node_obj.neighbor_ids) < 4
                                            try
                                                # GRUG v7.39: NOCHAT — mark group invisible to ChatterMode.
                                                # Use is_chatter_eligible field on NodeGroup (added v7.39).
                                                # For now: mark via is_chatter_eligible=false on NodeGroup.
                                                # ChatterMode enforces: skips groups with is_chatter_eligible=false.
                                                # Graduates to true automatically in add_to_group! when group reaches 4+ connected members.
                                                grp.is_chatter_eligible = false
                                            catch
                                                # GRUG: Can't mark NOCHAT? Not fatal. The group
                                                # just might get chattered too early. Not ideal
                                                # but not catastrophic.
                                            end
                                        end
                                    end
                                end
                            end
                        catch e
                            # GRUG: Singleton registration failure — node is free agent.
                            latched_group_id = ""
                        end
                    end
                else
                    # ── NO CANDIDATES: SINGLETON + NOCHAT ────────────────────
                    # GRUG: No group passed the three-gate filter. That's fine —
                    # the node founds a new singleton group. If it grows later,
                    # great. If not, Phagy may merge it.
                    try
                        if register_group_fn !== nothing
                            new_node_obj = lock(node_lock) do
                                get(node_map, new_id, nothing)
                            end
                            if new_node_obj !== nothing
                                grp = register_group_fn(new_node_obj)
                                if grp !== nothing
                                    latched_group_id = grp.id
                                    # GRUG: NOCHAT — same rule as coinflip-lost path.
                                    if length(new_node_obj.neighbor_ids) < 4
                                        try
                                            grp.is_chatter_eligible = false
                                        catch; end
                                    end
                                end
                            end
                        end
                    catch e
                        latched_group_id = ""
                    end
                end
            catch e
                # GRUG: Pipeline failure is not fatal — node is still planted.
                # Every step has its own try/catch; this catches unexpected
                # errors in the pipeline dispatch itself.
                latched_to_id = ""
                latched_group_id = ""
            end

        elseif group_latch_fn !== nothing && add_to_group_fn !== nothing
            # ── FALLBACK: OLD JACCARD-ONLY PATH (backward compat) ───────────
            # GRUG: When scan_latch_candidates_fn is not provided (e.g. /grow
            # command or old caller), use the original Jaccard-based group
            # latching with the hard strength floor. No changes to this path.
            try
                candidates = group_latch_fn(pattern; node_map=node_map, node_lock=node_lock)

                if !isempty(candidates)
                    eligible = filter(c -> c.avg_strength >= MITOSIS_GROUP_STRENGTH_FLOOR, candidates)

                    if !isempty(eligible)
                        chosen = eligible[rand(1:length(eligible))]
                        target_group = chosen.group

                        joined = add_to_group_fn(target_group, new_id)
                        if joined
                            latched_group_id = target_group.id

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
            catch e
                latched_to_id = ""
                latched_group_id = ""
            end
        end

        # GRUG: Set cooldown AFTER successful growth
        _set_cooldown()

        # GRUG (v9.2): Build notes with node type and NOCHAT info.
        _type_tag = if _is_antimatch
            "antimatch:singleton"
        elseif _is_singleton_type
            "aiml:singleton"  # backward-compat label (AIMLNodeSystem removed v8.12)
        else
            "match"
        end
        _nochatter_tag = ""
        if !isempty(latched_group_id) && isempty(latched_to_id)
            # GRUG: In a group but not linked — check NOCHAT (is_chatter_eligible)
            try
                if group_for_fn !== nothing
                    grp = group_for_fn(new_id)
                    if grp !== nothing && hasproperty(grp, :is_chatter_eligible) && !grp.is_chatter_eligible
                        _nochatter_tag = " [NOCHAT]"
                    end
                end
            catch; end
        end

        notes = if !isempty(latched_to_id)
            "Mitosis: branched '$pattern' -> $new_id in $lobe_hint [$(action_family_name):$(_type_tag)], group->$latched_group_id, linked->$latched_to_id (warrant=$warrant from $source)"
        elseif !isempty(latched_group_id)
            "Mitosis: branched '$pattern' -> $new_id in $lobe_hint [$(action_family_name):$(_type_tag)], group->$latched_group_id$(_nochatter_tag), no link target (warrant=$warrant from $source)"
        else
            "Mitosis: branched '$pattern' -> $new_id in $lobe_hint [$(action_family_name):$(_type_tag)], free agent (warrant=$warrant from $source)"
        end

        stats = MitosisStats(source, new_id, pattern, lobe_hint, warrant,
                            (time() - t0) * 1000, notes, latched_to_id)
        push_mitosis_log!(stats)

        return stats
    catch e
        notes = "Mitosis FAILED for '$pattern': $e"
        stats = MitosisStats(source, "", pattern, lobe_hint, warrant,
                            (time() - t0) * 1000, notes, "")
        push_mitosis_log!(stats)
        return stats
    end
end

# ==============================================================================
# CLI COMMAND: /mitosisStatus
# ==============================================================================

function get_mitosis_status_summary()::String
    log = get_mitosis_log()

    if isempty(log)
        return "Mitosis: no events yet. Cave has not grown on its own."
    end

    lines = String[]
    push!(lines, "=== MITOSIS STATUS ===")
    push!(lines, "Total events: $(length(log))")
    push!(lines, "Stochastic probability: $(MITOSIS_PROBABILITY) ceiling (data-driven: 0% when quiet, up to $(MITOSIS_PROBABILITY) when active)")
    push!(lines, "Cooldown: $(MITOSIS_COOLDOWN_CYCLES) idle cycles between successful growth")

    # Count by source
    source_counts = Dict{String, Int}()
    growth_count = 0
    latched_count = 0
    for entry in log
        source_counts[entry.source] = get(source_counts, entry.source, 0) + 1
        if !isempty(entry.new_node_id)
            growth_count += 1
        end
        if !isempty(entry.latched_to)
            latched_count += 1
        end
    end

    push!(lines, "Nodes grown: $growth_count")
    push!(lines, "Nodes latched: $latched_count")
    push!(lines, "Warrant sources:")
    for (src, cnt) in sort(collect(source_counts), by=x->x[2], rev=true)
        push!(lines, "  $src: $cnt")
    end

    # Show last 5 events
    push!(lines, "\nRecent events (last 5):")
    recent = log[max(1, length(log)-4):end]
    for entry in reverse(recent)
        if isempty(entry.new_node_id)
            push!(lines, "  [$(entry.source)] $(entry.notes)")
        else
            latch_info = isempty(entry.latched_to) ? ", no latch" : ", latched→$(entry.latched_to)"
            push!(lines, "  [$(entry.source)] BUD: '$(entry.new_pattern)' → $(entry.new_node_id) in $(entry.target_lobe) (warrant=$(round(entry.warrant_score, digits=2))$(latch_info))")
        end
    end

    return join(lines, "\n")
end

end # module MitosisMode
