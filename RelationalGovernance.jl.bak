# RelationalGovernance.jl
# ==============================================================================
# !!! GRUG REMINDER — RELATIONAL TRIPLES CAN USE SIGILS !!!
# A RelationalTriple's subject / relation / object may contain sigil tokens
# (&n, &word, &noun, specimen macros). Co-firing / auto-attach logic that reads
# or compares triples must NOT assume the fields are always literal words —
# sigil holes are valid. Resolve via SigilRegistry where appropriate.
# ==============================================================================
# RELATIONAL GOVERNANCE — AUTO-ATTACH FROM ACCUMULATED CO-ACTIVATION INTENSITY
# ==============================================================================
# GRUG say: nodes that fire together should wire together. But SLOW. LAZY.
# CONSERVATIVE. Like moss on rock — only grows where moisture collects enough
# over a LONG time. Not eager. Not fast. Patient.
#
# PHILOSOPHY:
#   Hebbian learning at the topology level: "neurons that fire together wire
#   together." But biology doesn't rush this. Synaptic strengthening happens
#   over REPEATED co-activation, not single coincidences. One co-firing is
#   noise. Ten co-firings is a signal. A hundred is a bond worth making
#   permanent. That's the spectrum.
#
#   The existing /nodeAttach command lets users MANUALLY bolt nodes together.
#   This module does it AUTOMATICALLY when the data (repeated co-activation)
#   justifies it. Same attachment mechanism (AttachedNode, ATTACHMENT_MAP),
#   same connector pattern logic — just earned organically instead of
#   commanded.
#
# MECHANISM:
#   1. OBSERVE: After each scan cycle, record which nodes fired together.
#      Increment pair-wise intensity in the co-activation accumulator.
#   2. DECAY: Intensity decays over time. Co-firing that stops happening
#      gradually loses its accumulated signal. Bonds that aren't reinforced
#      fade. This prevents stale pairs from triggering attachments.
#   3. THRESHOLD: When a pair's intensity crosses the auto-attach threshold,
#      the system attaches them — using their shared token overlap as the
#      connector pattern (same as /nodeAttach but computed automatically).
#   4. LAZY GATE: This whole process runs ONLY during idle cycles, gated by
#      a stochastic lever (low probability per cycle). Most idle cycles,
#      nothing happens. That's by design.
#
# DATA-DRIVEN:
#   Same philosophy as mitosis and AIML growth. No co-firing data = no
#   attachment. Period. The intensity must be EARNED from actual repeated
#   co-activation, not from assumptions. The threshold is HIGH on purpose —
#   better to miss a bond than to create a junk attachment that pollutes
#   the topology.
#
# BOUNDS:
#   - CO_ACC_MAX_PAIRS: Maximum pairs tracked in the accumulator. Bounded
#     so memory doesn't grow unbounded. When full, weakest pairs are evicted.
#   - CO_ACC_DECAY_RATE: Fraction of intensity lost per decay cycle.
#     Pairs that stop co-firing fade to zero and get evicted.
#   - AUTO_ATTACH_THRESHOLD: Intensity a pair must accumulate before
#     auto-attach triggers. Conservative. High. Earned.
#   - AUTO_ATTACH_PROB: Stochastic lever per idle cycle. Most cycles, no
#     auto-attach happens even if some pairs are above threshold. Lazy.
#
# ARCHITECTURE:
#   Follows ChatterMode/PhagyMode/MitosisMode pattern: NO `using ..GrugBot420`.
#   All state is passed as parameters. This module is self-contained.
#   Dependencies are injected as function callbacks.
#
# CONNECTOR PATTERN:
#   When auto-attaching, the connector pattern is the SHARED TOKEN OVERLAP
#   between the two nodes' patterns — the words they have in common. This
#   is the same kind of connector that /nodeAttach uses, just computed
#   automatically instead of user-specified. If two nodes share no tokens,
#   the connector is the concatenation of their first tokens with "≈" as
#   a relational bridge marker. The system always has SOMETHING to say
#   about why these nodes are related, because the co-activation data
#   already proved it.
#
# SAFETY:
#   - No silent failures. Every auto-attach is logged.
#   - Respects MAX_ATTACHMENTS cap (4 per target, same as manual).
#   - Respects UNLINKABLE / GRAVE state on both nodes.
#   - Will not create duplicate attachments.
#   - One auto-attach per idle cycle max (lazy, not fast).
#   - Co-activation accumulator is bounded (no unbounded memory).
#   - Decay prevents stale pairs from triggering attachments.
# ==============================================================================

module RelationalGovernance

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

export observe_co_firing!, run_relational_governance!, RelationalGovStats
export get_relational_gov_status_summary, RelationalGovError
export CO_ACC_MAX_PAIRS, CO_ACC_DECAY_RATE, AUTO_ATTACH_THRESHOLD, AUTO_ATTACH_PROB

# ==============================================================================
# ERROR TYPE — GRUG: NO SILENT FAILURES
# ==============================================================================

struct RelationalGovError <: Exception
    msg::String
end

Base.showerror(io::IO, e::RelationalGovError) =
    print(io, "RelationalGovError: ", e.msg)

# ==============================================================================
# CONSTANTS — CONSERVATIVE BY DEFAULT
# ==============================================================================

# GRUG: Maximum number of pairs tracked in the co-activation accumulator.
# Bounded so memory doesn't grow without limit. When full, weakest pairs
# are evicted to make room for new ones. 5000 is generous — most specimens
# won't have this many active co-firing pairs.
const CO_ACC_MAX_PAIRS = 5000

# GRUG: Fraction of intensity lost per decay cycle. Pairs that stop
# co-firing gradually lose their accumulated signal. At 0.05 per decay,
# a pair that stops co-firing will be at ~60% intensity after 10 decay
# cycles, ~35% after 20, and effectively zero after ~60. Slow fade,
# not sudden death. Gives pairs a chance to recover if co-firing resumes.
const CO_ACC_DECAY_RATE = 0.05

# GRUG: Intensity threshold a pair must accumulate before auto-attach
# triggers. Conservative. At 10.0, that's roughly 10 co-firing events
# (if each adds ~1.0) AFTER decay. Actual accumulation depends on
# frequency and recency. High threshold = fewer junk attachments.
# Better to miss a bond than make a bad one.
const AUTO_ATTACH_THRESHOLD = 10.0

# GRUG: Stochastic lever — probability that relational governance even
# TRIES during an eligible idle cycle. 0.10 = 10% chance. Most idle
# cycles, nothing happens. Combined with the 120s ±30s idle timer and
# the high threshold, auto-attachments are RARE and EARNED.
const AUTO_ATTACH_PROB = 0.10

# GRUG: Intensity increment per co-firing event. Each time two nodes
# fire in the same cycle, their pair intensity increases by this amount.
# Combined with decay, this creates a running average that reflects
# RECENT co-firing frequency, not lifetime total.
const CO_FIRE_INCREMENT = 1.0

# GRUG: Minimum token overlap required between two nodes before we even
# track their co-activation. If they share NO tokens, they're probably
# not meaningfully related — the co-firing was coincidental (same input
# matched many unrelated lobes). This filter prevents the accumulator
# from filling up with junk pairs.
const MIN_OVERLAP_FOR_TRACKING = 0.05

# ==============================================================================
# CO-ACTIVATION ACCUMULATOR
# ==============================================================================
# GRUG: The accumulator tracks pair-wise intensity. Key is a sorted pair
# of node IDs (always smaller ID first) so (A,B) and (B,A) map to the
# same entry. No duplicates. Bounded by CO_ACC_MAX_PAIRS.

const CO_ACC = Dict{Tuple{String, String}, Float64}()
const CO_ACC_LOCK = ReentrantLock()

# ==============================================================================
# GOVERNANCE LOG (bounded ring — last 50 events)
# ==============================================================================

struct GovEvent
    event_type::String     # "auto_attach" or "decay" or "observe"
    node_a::String         # GRUG: First node ID (sorted)
    node_b::String         # GRUG: Second node ID (sorted)
    intensity::Float64     # GRUG: Pair intensity at time of event
    connector::String      # GRUG: Connector pattern (for auto_attach events)
    timestamp::Float64     # GRUG: Unix timestamp
    notes::String          # GRUG: Human-readable summary
end

const GOV_LOG      = GovEvent[]
const GOV_LOG_LOCK = ReentrantLock()
const MAX_GOV_LOG  = 50

# ==============================================================================
# STATS (returned per cycle for diagnostics)
# ==============================================================================

struct RelationalGovStats
    event::String           # GRUG: "auto_attach", "decay", "skipped_stochastic", "no_pairs_above_threshold", etc.
    pairs_tracked::Int      # GRUG: How many pairs in the accumulator
    pairs_above_threshold::Int  # GRUG: How many pairs have crossed the threshold
    attachments_made::Int   # GRUG: How many auto-attachments were made this cycle
    cycle_time_ms::Float64  # GRUG: Wall time for this cycle in milliseconds
    notes::String           # GRUG: Human-readable summary
end

# ==============================================================================
# OBSERVE — Record co-firing from a scan cycle
# ==============================================================================

"""
    observe_co_firing!(fired_node_ids::Vector{String};
                       token_overlap_fn = (a,b) -> 0.0)

GRUG: After each scan cycle, call this with the list of node IDs that fired.
For every pair of fired nodes, increment their co-activation intensity
IF they have enough token overlap to be meaningfully related.

`token_overlap_fn` should return a float [0.0, 1.0] similarity between
two node patterns. Pairs below MIN_OVERLAP_FOR_TRACKING are ignored —
co-firing without similarity is probably coincidental.

Thread-safe: takes CO_ACC_LOCK for all mutations.
"""
function observe_co_firing!(fired_node_ids::Vector{String};
                            token_overlap_fn::Function = (a, b) -> 0.0)::Int
    if length(fired_node_ids) < 2
        return 0  # GRUG: Need at least 2 nodes to have a pair
    end

    new_pairs = 0

    # GRUG: Generate all unique pairs from the fired set.
    # Sort IDs so (A,B) and (B,A) map to the same key.
    sorted_ids = sort(fired_node_ids)
    n = length(sorted_ids)

    # GRUG v8.0 FIX: Compute token overlaps OUTSIDE CO_ACC_LOCK!
    # Old code called token_overlap_fn inside lock(CO_ACC_LOCK), but
    # token_overlap_fn acquires NODE_LOCK. That creates CO_ACC_LOCK → NODE_LOCK
    # nesting. While no current code path does NODE_LOCK → CO_ACC_LOCK, the
    # nested pattern is a deadlock risk if any future code adds that ordering.
    # Fix: pre-compute all overlaps (read-only under NODE_LOCK), then do
    # the CO_ACC mutation in a separate lock block with no nesting.
    eligible_pairs = Tuple{String, String, Float64}[]  # (id_a, id_b, overlap)
    for i in 1:(n-1)
        for j in (i+1):n
            id_a = sorted_ids[i]
            id_b = sorted_ids[j]
            overlap = token_overlap_fn(id_a, id_b)
            if overlap >= MIN_OVERLAP_FOR_TRACKING
                push!(eligible_pairs, (id_a, id_b, overlap))
            end
        end
    end

    # GRUG v8.0: Now mutate CO_ACC under CO_ACC_LOCK only — no NODE_LOCK nesting.
    lock(CO_ACC_LOCK) do
        for (id_a, id_b, _overlap) in eligible_pairs
            key = (id_a, id_b)
            if haskey(CO_ACC, key)
                CO_ACC[key] += CO_FIRE_INCREMENT
            else
                # GRUG: New pair. Check if accumulator is full.
                if length(CO_ACC) >= CO_ACC_MAX_PAIRS
                    # GRUG: Evict the weakest pair to make room.
                    # Find the pair with the lowest intensity.
                    min_key = nothing
                    min_val = Inf
                    for (k, v) in CO_ACC
                        if v < min_val
                            min_val = v
                            min_key = k
                        end
                    end
                    if !isnothing(min_key)
                        delete!(CO_ACC, min_key)
                    end
                end
                CO_ACC[key] = CO_FIRE_INCREMENT
                new_pairs += 1
            end
        end
    end

    return new_pairs
end

# ==============================================================================
# DECAY — Fade intensity for pairs that stopped co-firing
# ==============================================================================

"""
    _decay_accumulator!()

GRUG: Apply exponential decay to all pairs in the accumulator.
Intensity drops by CO_ACC_DECAY_RATE fraction per call. Pairs that
drop below a tiny floor (0.01) are evicted entirely — they're effectively
zero and just taking space.

Returns (pairs_decayed, pairs_evicted) counts.
"""
function _decay_accumulator!()::Tuple{Int, Int}
    pairs_decayed = 0
    pairs_evicted = 0
    evict_keys = Tuple{String, String}[]

    lock(CO_ACC_LOCK) do
        for (key, val) in CO_ACC
            new_val = val * (1.0 - CO_ACC_DECAY_RATE)
            pairs_decayed += 1
            if new_val < 0.01
                # GRUG: Effectively zero. Evict.
                push!(evict_keys, key)
                pairs_evicted += 1
            else
                CO_ACC[key] = new_val
            end
        end
        for key in evict_keys
            delete!(CO_ACC, key)
        end
    end

    return (pairs_decayed, pairs_evicted)
end

# ==============================================================================
# AUTO-ATTACH — When intensity crosses threshold, bolt the nodes together
# ==============================================================================

"""
    _auto_attach_best_candidate!(;
        attach_fn::Function,
        token_overlap_fn::Function,
        node_map_ref,
        node_lock_ref)

GRUG: Find the pair with the highest intensity that's above the auto-attach
threshold and attach them. Only ONE attachment per call (lazy, not fast).

The connector pattern is computed from the shared token overlap between
the two nodes' patterns. Same mechanism as /nodeAttach, just automatic.

Returns (attached::Bool, node_a, node_b, connector, intensity) or
( false, "", "", "", 0.0) if no suitable pair found.
"""
function _auto_attach_best_candidate!(;
    attach_fn::Function,
    token_overlap_fn::Function,
    node_map_ref,
    node_lock_ref)::Tuple{Bool, String, String, String, Float64}

    # GRUG: Find the best candidate pair above threshold
    best_key = nothing
    best_intensity = -1.0

    lock(CO_ACC_LOCK) do
        for (key, val) in CO_ACC
            if val >= AUTO_ATTACH_THRESHOLD && val > best_intensity
                best_key = key
                best_intensity = val
            end
        end
    end

    if isnothing(best_key)
        return (false, "", "", "", 0.0)
    end

    id_a, id_b = best_key

    # GRUG: Compute the connector pattern from shared token overlap.
    # This is the same kind of connector /nodeAttach uses, just automatic.
    # We look at both nodes' patterns and find the words they share.
    pattern_a = ""
    pattern_b = ""
    lock(node_lock_ref) do
        na = get(node_map_ref, id_a, nothing)
        nb = get(node_map_ref, id_b, nothing)
        if !isnothing(na)
            pattern_a = na.pattern
        end
        if !isnothing(nb)
            pattern_b = nb.pattern
        end
    end

    if isempty(pattern_a) || isempty(pattern_b)
        # GRUG: One or both nodes vanished. Remove the pair and skip.
        lock(CO_ACC_LOCK) do
            delete!(CO_ACC, best_key)
        end
        return (false, "", "", "", 0.0)
    end

    # GRUG: Compute shared tokens for the connector pattern.
    tokens_a = Set(split(pattern_a))
    tokens_b = Set(split(pattern_b))
    shared = intersect(tokens_a, tokens_b)

    connector = if !isempty(shared)
        # GRUG: Shared words exist — use them as the connector.
        # Sort for determinism, join with spaces.
        join(sort(collect(shared)), " ")
    else
        # GRUG: No shared words but they co-fired enough to exceed threshold.
        # This can happen with sigil-promoted patterns or short patterns.
        # Bridge them with a relational marker: "first_a ≈ first_b"
        first_a = split(pattern_a)[1]
        first_b = split(pattern_b)[1]
        "$(first_a) ≈ $(first_b)"
    end

    # GRUG: Try to attach! Use the same attach_node! that /nodeAttach uses.
    # It handles all the validation: grave check, UNLINKABLE check, cap check,
    # duplicate check. If it fails, we respect that — no forcing.
    try
        result = attach_fn(id_a, id_b, connector)
        # GRUG: Attachment succeeded! Remove the pair from the accumulator
        # so we don't try to re-attach them. The bond is made.
        lock(CO_ACC_LOCK) do
            delete!(CO_ACC, best_key)
        end
        return (true, id_a, id_b, connector, best_intensity)
    catch e
        # GRUG: Attachment failed. This is NOT a silent failure — we log it.
        # Common reasons: target already has MAX_ATTACHMENTS, one node is
        # now UNLINKABLE or GRAVE, or they're already attached. All valid
        # reasons to skip. Remove the pair so we don't keep retrying.
        lock(CO_ACC_LOCK) do
            delete!(CO_ACC, best_key)
        end
        return (false, id_a, id_b, connector, best_intensity)
    end
end

# ==============================================================================
# MAIN ENTRY POINT — Run during idle cycle
# ==============================================================================

"""
    run_relational_governance!(;
        attach_fn::Function,
        token_overlap_fn::Function,
        node_map_ref,
        node_lock_ref,
        immune_gate_fn::Function = (pattern, data) -> true)

GRUG: Run one cycle of relational governance during idle time.

1. STOCHASTIC GATE: Only AUTO_ATTACH_PROB (10%) of eligible idle cycles
   even attempt auto-attach. Most cycles, nothing happens.
2. DECAY: Apply exponential decay to all accumulated pair intensities.
   Pairs that stopped co-firing gradually fade. Stale pairs get evicted.
3. AUTO-ATTACH: If any pair is above threshold, attach the best candidate.
   ONE attachment per cycle max. Lazy, not fast.

Returns RelationalGovStats for diagnostics.

Data-driven: if no pairs have accumulated enough intensity, nothing happens.
No intensity = no attachment. The data must EARN the bond.
"""
function run_relational_governance!(;
    attach_fn::Function,
    token_overlap_fn::Function,
    node_map_ref,
    node_lock_ref,
    immune_gate_fn::Function = (pattern, data) -> true)::RelationalGovStats

    t_start = time_ns()

    # GRUG: STOCHASTIC GATE — only 10% of idle cycles even try.
    if rand() >= AUTO_ATTACH_PROB
        # GRUG: Still decay even when we don't attempt attach.
        # Accumulator shouldn't grow stale just because the stochastic
        # gate didn't roll this cycle.
        (pairs_decayed, pairs_evicted) = _decay_accumulator!()

        pairs_tracked = lock(() -> length(CO_ACC), CO_ACC_LOCK)
        t_elapsed = (time_ns() - t_start) / 1.0e6

        return RelationalGovStats(
            "skipped_stochastic_gate",
            pairs_tracked,
            0,  # pairs above threshold (not checked this cycle)
            0,  # no attachments made
            t_elapsed,
            "Stochastic gate didn't roll. Decayed $(pairs_decayed) pairs, evicted $(pairs_evicted) stale pairs."
        )
    end

    # GRUG: STEP 1 — Decay existing intensities.
    (pairs_decayed, pairs_evicted) = _decay_accumulator!()

    # GRUG: STEP 2 — Count pairs above threshold.
    pairs_above = lock(CO_ACC_LOCK) do
        count(v -> v >= AUTO_ATTACH_THRESHOLD, values(CO_ACC))
    end

    pairs_tracked = lock(() -> length(CO_ACC), CO_ACC_LOCK)

    if pairs_above == 0
        t_elapsed = (time_ns() - t_start) / 1.0e6
        return RelationalGovStats(
            "no_pairs_above_threshold",
            pairs_tracked,
            0,
            0,
            t_elapsed,
            "No pairs above threshold ($(AUTO_ATTACH_THRESHOLD)). Decayed $(pairs_decayed), evicted $(pairs_evicted). Accumulator has $(pairs_tracked) pairs."
        )
    end

    # GRUG v8.0: STEP 3 — AUTO-ATTACH DISABLED.
    # The auto-attach strategy needs rethinking. The current approach of
    # blindly attaching the highest-intensity co-firing pair is too aggressive.
    # A better strategy is needed — the user will work this out in due time.
    # Accumulator still accumulates and decays normally. The data is preserved.
    # When a better strategy is ready, uncomment the block below.
    #
    # (attached, id_a, id_b, connector, intensity) = _auto_attach_best_candidate!(;
    #     attach_fn = attach_fn,
    #     token_overlap_fn = token_overlap_fn,
    #     node_map_ref = node_map_ref,
    #     node_lock_ref = node_lock_ref,
    # )
    #
    # # GRUG: Immune gate check on the connector pattern.
    # if attached
    #     json_text = JSON.json(Dict("pattern" => connector, "nodes" => [id_a, id_b]))
    #     if !immune_gate_fn(connector, json_text)
    #         # GRUG: Immune system rejected this attachment. Detach it.
    #         # This is rare but the immune system has final say.
    #         try
    #             # GRUG: We can't easily detach here since we don't have
    #             # detach_fn. Instead, log it as a rejection and mark the
    #             # pair so it won't be retried (already removed from acc).
    #             attached = false
    #         catch
    #             # GRUG: Best effort. The attachment might stick but it'll
    #             # be logged as immune-rejected for human review.
    #         end
    #     end
    # end
    attached = false
    id_a = ""; id_b = ""; connector = ""; intensity = 0.0

    t_elapsed = (time_ns() - t_start) / 1.0e6

    # GRUG v8.0: Auto-attach disabled — return diagnostic info without attempting attachment.
    # Accumulator still accumulates and decays. Pairs above threshold are tracked.
    # When auto-attach is re-enabled, restore the STEP 3 block above and remove this return.
    return RelationalGovStats(
        "auto_attach_disabled",
        pairs_tracked,
        pairs_above,
        0,
        t_elapsed,
        "Auto-attach DISABLED (v8.0). Accumulator has $(pairs_above) pairs above threshold ($(AUTO_ATTACH_THRESHOLD)). Decayed $(pairs_decayed), evicted $(pairs_evicted). Strategy pending rework."
    )

    # GRUG v8.0: DEAD CODE below — kept for when auto-attach is re-enabled.
    # Restore: uncomment STEP 3 block above, remove the early return above,
    # and uncomment this if/else block.
    #= 
    if attached
        # GRUG: Log the event
        lock(GOV_LOG_LOCK) do
            push!(GOV_LOG, GovEvent(
                "auto_attach", id_a, id_b, intensity, connector, time(),
                "Auto-attached '$id_a' ↔ '$id_b' (intensity=$(round(intensity, digits=2)), connector=\"$(first(connector, 40))\")"
            ))
            if length(GOV_LOG) > MAX_GOV_LOG
                deleteat!(GOV_LOG, 1)
            end
        end

        return RelationalGovStats(
            "auto_attach",
            pairs_tracked,
            pairs_above - 1,  # GRUG: One less above threshold now
            1,
            t_elapsed,
            "Auto-attached '$id_a' ↔ '$id_b' (intensity=$(round(intensity, digits=2)), connector=\"$(first(connector, 40))\"). Decayed $(pairs_decayed), evicted $(pairs_evicted)."
        )
    else
        notes = if !isempty(id_a) && !isempty(id_b)
            "Best candidate '$id_a' ↔ '$id_b' failed to attach (intensity=$(round(intensity, digits=2))). Likely at cap, grave, or already attached."
        else
            "No suitable candidate found despite $(pairs_above) pairs above threshold."
        end

        return RelationalGovStats(
            "attach_failed",
            pairs_tracked,
            pairs_above,
            0,
            t_elapsed,
            notes * " Decayed $(pairs_decayed), evicted $(pairs_evicted)."
        )
    end
    =#
end

# ==============================================================================
# STATUS SUMMARY — For /status CLI and diagnostics
# ==============================================================================

"""
    get_relational_gov_status_summary()::String

GRUG: Return a human-readable status summary of the relational governance
system. Shows accumulator size, top pairs, recent events.
"""
function get_relational_gov_status_summary()::String
    lines = String[]
    push!(lines, "═══ RELATIONAL GOVERNANCE ═══")

    pairs_tracked = lock(() -> length(CO_ACC), CO_ACC_LOCK)
    push!(lines, "  Accumulator: $(pairs_tracked)/$(CO_ACC_MAX_PAIRS) pairs tracked")

    pairs_above = lock(CO_ACC_LOCK) do
        count(v -> v >= AUTO_ATTACH_THRESHOLD, values(CO_ACC))
    end
    push!(lines, "  Above threshold ($(AUTO_ATTACH_THRESHOLD)): $(pairs_above) pairs")
    push!(lines, "  Auto-attach probability: $(AUTO_ATTACH_PROB) ($(round(AUTO_ATTACH_PROB * 100, digits=1))% per idle cycle)")
    push!(lines, "  Decay rate: $(CO_ACC_DECAY_RATE) ($(round(CO_ACC_DECAY_RATE * 100, digits=1))% per decay cycle)")

    # GRUG: Show top 5 pairs by intensity
    top_pairs = lock(CO_ACC_LOCK) do
        sorted = sort(collect(CO_ACC), by = x -> x[2], rev = true)
        sorted[1:min(5, length(sorted))]
    end

    if !isempty(top_pairs)
        push!(lines, "  Top pairs:")
        for ((id_a, id_b), intensity) in top_pairs
            marker = intensity >= AUTO_ATTACH_THRESHOLD ? "★" : " "
            push!(lines, "  $(marker) $(id_a) ↔ $(id_b): intensity=$(round(intensity, digits=2))")
        end
    end

    # GRUG: Show recent governance events
    recent_events = lock(GOV_LOG_LOCK) do
        GOV_LOG[max(1, length(GOV_LOG)-4):end]
    end
    if !isempty(recent_events)
        push!(lines, "  Recent events:")
        for evt in recent_events
            push!(lines, "    [$(evt.event_type)] $(evt.notes)")
        end
    end

    return join(lines, "\n")
end

# ==============================================================================
# SERIALIZATION — For specimen save/load
# ==============================================================================

"""
    serialize_co_activation()::Dict{String, Any}

GRUG: Serialize the co-activation accumulator for specimen save.
Only the top pairs are saved (bounded) to keep specimens compact.
"""
function serialize_co_activation()::Dict{String, Any}
    pairs_data = lock(CO_ACC_LOCK) do
        # GRUG: Save all pairs with intensity > 0.5 (skip near-zero noise)
        [(String(pair[1]) * "|" * String(pair[2]) => round(intensity, digits=4))
         for (pair, intensity) in CO_ACC if intensity > 0.5]
    end

    return Dict{String, Any}(
        "co_activation_pairs" => Dict(pairs_data),
        "max_pairs"           => CO_ACC_MAX_PAIRS,
        "decay_rate"          => CO_ACC_DECAY_RATE,
        "auto_attach_threshold" => AUTO_ATTACH_THRESHOLD,
        "auto_attach_prob"    => AUTO_ATTACH_PROB,
    )
end

"""
    deserialize_co_activation!(data)

GRUG: Restore the co-activation accumulator from specimen data.
Merges with existing accumulator (doesn't clear it first).
"""
function deserialize_co_activation!(data)
    pairs_raw = get(data, "co_activation_pairs", Dict{String, Any}())

    lock(CO_ACC_LOCK) do
        for (key_str, intensity) in pairs_raw
            parts = split(String(key_str), "|")
            if length(parts) == 2
                id_a = String(parts[1])
                id_b = String(parts[2])
                key = (min(id_a, id_b), max(id_a, id_b))
                val = Float64(intensity)
                # GRUG: Merge — keep the higher intensity if pair already exists
                if haskey(CO_ACC, key)
                    CO_ACC[key] = max(CO_ACC[key], val)
                else
                    CO_ACC[key] = val
                end
            end
        end
        # GRUG: Enforce max pairs after deserialization
        while length(CO_ACC) > CO_ACC_MAX_PAIRS
            min_key = nothing
            min_val = Inf
            for (k, v) in CO_ACC
                if v < min_val
                    min_val = v
                    min_key = k
                end
            end
            if !isnothing(min_key)
                delete!(CO_ACC, min_key)
            else
                break
            end
        end
    end

    return nothing
end

# ==============================================================================
# RESET — For testing
# ==============================================================================

"""
    reset_co_activation!()

GRUG: Clear the entire co-activation accumulator. For testing only.
"""
function reset_co_activation!()
    lock(CO_ACC_LOCK) do
        empty!(CO_ACC)
    end
    lock(GOV_LOG_LOCK) do
        empty!(GOV_LOG)
    end
end

# ==============================================================================
# DIRECT CO-OCCURRENCE — entry point for InputLedger (user input mining)
# ==============================================================================

"""
    observe_direct_co_occurrence!(id_a::String, id_b::String, increment::Float64)

GRUG: Record a direct co-occurrence observation between two nodes.
This is the entry point for the InputLedger background thread — when
it finds that two nodes were co-expressed in the same user input,
it calls this to bump their pair intensity.

Unlike observe_co_firing! (which takes a list of fired nodes and
generates all pairs), this takes a SINGLE pair with a caller-specified
increment. The InputLedger uses 2.0 (stronger than scan co-firing's 1.0)
because user-typed co-occurrence is an INTENTIONAL signal.

No token-overlap filter here — the caller already filtered.
Thread-safe: takes CO_ACC_LOCK for all mutations.
"""
function observe_direct_co_occurrence!(id_a::String, id_b::String, increment::Float64)
    # GRUG: Sort the pair so (A,B) and (B,A) map to the same key.
    key = (min(id_a, id_b), max(id_a, id_b))

    lock(CO_ACC_LOCK) do
        if haskey(CO_ACC, key)
            CO_ACC[key] += increment
        else
            # GRUG: New pair. Check if accumulator is full.
            if length(CO_ACC) >= CO_ACC_MAX_PAIRS
                # GRUG: Evict the weakest pair.
                min_key = nothing
                min_val = Inf
                for (k, v) in CO_ACC
                    if v < min_val
                        min_val = v
                        min_key = k
                    end
                end
                if !isnothing(min_key)
                    delete!(CO_ACC, min_key)
                end
            end
            CO_ACC[key] = increment
        end
    end
end

end # module RelationalGovernance
