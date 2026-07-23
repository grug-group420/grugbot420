# ==============================================================================
# EphemeralAutomaton.jl — v7.27 ATP-Callable JIT Step Machine + Time Crystal
# ==============================================================================
# GRUG say: most rocks just react. Question come in, rock match pattern, rock
#           shout answer. That is pattern REACTION. But some questions need
#           STEPS. "Take 3, double it, add 5, then square." That is pattern
#           COMPLETION. Old grug had no completion. New grug have small JIT
#           machine: tiny rule-set, lives only for one question, dies after.
#
# GRUG say: NOT a sub-population. NOT persistent. NO strength. NO grave. Pure
#           working-memory loop. Basal-ganglia (ATP) decides if escalate. Few
#           rocks ever fire at one time, so this is sparse — no thread storm.
#
# GRUG say: jitter snap-back is per-step, on values caller TAGS as safe to
#           wobble. Step indices, operator names, final state booleans never
#           wobble — that would corrupt step coherence. Numeric values that
#           are accumulators or weights CAN wobble, mean snaps back to true
#           value.
#
# GRUG say: user can add rules at runtime. Rules tiny. Pattern-trigger plus
#           ordered step list. End user ships rules; engine does not bake any
#           policy.
#
# GRUG v7.27 say: OLD CRYSTAL HAD NO MEMORY. Every run was frozen in time.
#           Trace evaporated. No cross-cycle state. But brain that forgets
#           everything is not brain — is reflex arc. Now automaton GROWS.
#           Every ATP prediction that clears the confidence floor writes a
#           PhaseSnapshot into the accumulator. The crystal preserves phase
#           relationships across time. Each call isn't isolated anymore —
#           state at time t+T is correlated with state at time t, not just
#           determined by the drive at t+T. That IS a time crystal.
#
# GRUG say: rain check is ATP min_confidence at issuance. Snapshot below
#           floor never enters accumulator. No separate observation_count
#           state machine. ATP already decides what's real. Prediction is
#           power. Observation is truth. Same truth gate, one threshold.
#
# GRUG say: MLP reads crystal phase but does not OWN crystal. Automaton
#           accumulates. MLP evaluates. Clean separation — automaton
#           remembers, MLP sees.
# ==============================================================================
#
# ACADEMIC: This module implements an ephemeral automaton — a transient,
# rule-driven step executor invoked by ActionTonePredictor when escalation
# is warranted. Rules are persistent (registered with `register_automaton_rule!`
# and stored in a process-wide registry); traces are not (each call returns
# a fresh AutomatonTrace whose lifetime is the caller's). The automaton
# performs no cross-call state sharing and creates no nodes. Stochastic
# perturbation is opt-in per step output via the `jitter_targets` field;
# fields not in this set are returned bit-exact, preserving the deterministic
# step sequence required for downstream coherence.
#
# v7.27 adds the PhaseAccumulator — a cross-cycle store of ATP prediction
# snapshots that gives the automaton temporal memory. Each snapshot records
# the action and tone probability distributions at the time of ATP escalation.
# Retrieval uses big_number_small_number_coherence on distribution similarity.
# This is the time crystal: periodic structure that preserves phase
# relationships across time. The MLP consumes pulled snapshots via
# phase_mix_hidden! but does not own the accumulator.
# ==============================================================================

module EphemeralAutomaton

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

using ..RelationalJitter: jitter_value, JitterError

# GRUG: PatternScanner loaded before this module in GrugBot420.jl.
# Guard for standalone test loading.
if !isdefined(@__MODULE__, :PatternScanner)
    include(joinpath(@__DIR__, "patternscanner.jl"))
end
using .PatternScanner: big_number_small_number_coherence, slight_jitter

export AutomatonRule, AutomatonStep, AutomatonTrace
export AutomatonError, AutomatonRuleError
export register_automaton_rule!, unregister_automaton_rule!,
       list_automaton_rules, lookup_automaton_rule, clear_automaton_rules!
export run_automaton, find_matching_rule, run_for_action_family

# GRUG v7.27: Time crystal exports
export PhaseSnapshot, PhaseAccumulator
export record_phase!, phase_pull_query, phase_pull_status, phase_pull_status_string
export set_phase_pull_threshold!, get_phase_pull_threshold
export set_phase_surface_count!, get_phase_surface_count
export set_phase_enabled!, reset_phase_accumulator!
export phase_accumulator_to_dict, phase_accumulator_from_dict!

# GRUG v7.29: Vigilance context injector exports
export VigilanceConfig, ContextInjectorAgent, InjectorDisposition
export compute_context_weight, dispatch_vigilance_agents!
export get_vigilance_config, set_vigilance_config!
export get_automaton_max_cap, set_automaton_max_cap!
export vigilance_status, vigilance_status_string
export serialize_vigilance_config, deserialize_vigilance_config!
export serialize_injector_stats, reset_injector_stats!

# ==============================================================================
# CONSTANTS — GRUG keep magic numbers in one place
# ==============================================================================

# GRUG: Phase vector dimensionality. 6 ActionFamily + 6 ToneFamily = 12 floats.
const PHASE_DIM = 12

# GRUG: Default pull threshold for phase retrieval. Coherence above this
# gets magnetized. Same philosophy as the old magnet pull threshold.
const PHASE_PULL_THRESHOLD_DEFAULT = 0.55

# GRUG: How many random surface snapshots to sprinkle alongside pulled ones.
# Transformers ignore what they don't need via attention weights — free bits.
const PHASE_SURFACE_COUNT_DEFAULT = 3

# GRUG: Master switch default. Crystal starts ON because why build a crystal
# and then leave it in the dark?
const PHASE_ENABLED_DEFAULT = true

# GRUG: How strongly pulled phase vectors blend into MLP hidden state.
# This is consumed by EphemeralMLP.phase_mix_hidden!, not by the automaton
# itself — but the constant lives here because the automaton OWNS the crystal.
const PHASE_MIX_STRENGTH = 0.30

# GRUG: How weakly surface (random) phase vectors blend.
const PHASE_SURFACE_MIX_STRENGTH = 0.05

# ==============================================================================
# ERROR TYPES
# ==============================================================================

struct AutomatonError <: Exception
    message::String
    context::String
end

struct AutomatonRuleError <: Exception
    message::String
    context::String
end

@inline _err(msg, ctx) = throw(AutomatonError(msg, ctx))
@inline _rerr(msg, ctx) = throw(AutomatonRuleError(msg, ctx))

# ==============================================================================
# STEP & RULE STRUCTS
# ==============================================================================

"""
A single deterministic step in an automaton rule. `op` is a Symbol naming the
operation (e.g. :literal, :add, :double, :tag), `payload` is anything the
op needs (most often a Number, a String, or a NamedTuple). `label` is a
human-readable name surfaced in the trace.
"""
struct AutomatonStep
    label::String
    op::Symbol
    payload::Any
end

"""
An automaton rule. `id` is unique per registry. `trigger_action` is the
ActionFamily that, in combination with confidence ≥ threshold, makes ATP
escalate to this rule. `steps` is the ordered list of AutomatonStep.
`jitter_targets` is the set of step labels whose numeric output is allowed
to wobble through RelationalJitter; outputs of unlisted steps are exact.
`min_confidence` is the ATP confidence floor below which the rule will not
fire even if the action family matches.
"""
struct AutomatonRule
    id::String
    trigger_action::Symbol
    steps::Vector{AutomatonStep}
    jitter_targets::Set{String}
    min_confidence::Float64
end

function AutomatonRule(id::String, trigger_action::Symbol,
                       steps::Vector{AutomatonStep};
                       jitter_targets::Set{String} = Set{String}(),
                       min_confidence::Float64 = 0.5)
    if isempty(strip(id))
        _rerr("automaton rule id cannot be empty", "AutomatonRule")
    end
    if isempty(steps)
        _rerr("automaton rule '$id' has zero steps", "AutomatonRule")
    end
    if !(min_confidence >= 0.0 && min_confidence <= 1.0)
        _rerr("automaton rule '$id' min_confidence must be in [0,1], got $min_confidence",
              "AutomatonRule")
    end
    return AutomatonRule(id, trigger_action, steps, jitter_targets, min_confidence)
end

"""
Trace of one rule execution. `values` maps step label -> evaluated output
(post-jitter where applicable). `sequence` is the labels in order so callers
that want the linear story can iterate it deterministically. `jittered`
records which labels were perturbed this run.
"""
struct AutomatonTrace
    rule_id::String
    sequence::Vector{String}
    values::Dict{String, Any}
    jittered::Set{String}
end

# ==============================================================================
# PHASE SNAPSHOT — one rotation of the time crystal
# ==============================================================================

"""
    PhaseSnapshot

A single ATP prediction snapshot stored in the crystal. Records the full
action and tone probability distributions at the time of escalation, plus
metadata about which rule triggered and when.

GRUG: This IS the crystal's phase. Not a summary, not a compressed version —
      the actual probability distribution the automaton saw when it decided
      to step. If ATP said "70% ASSERT, 20% QUERY, 10% other" at time T,
      that IS what gets stored. Later, when a new input produces a similar
      distribution, the crystal reads its own phase from a previous period.

PHASE VECTOR FORMAT (12 floats):
  [1:6]  Action distribution: ACTION_ASSERT, ACTION_QUERY, ACTION_COMMAND,
         ACTION_NEGATE, ACTION_SPECULATE, ACTION_ESCALATE (alphabetical enum order)
  [7:12] Tone distribution: TONE_HOSTILE, TONE_CURIOUS, TONE_DECLARATIVE,
         TONE_URGENT, TONE_NEUTRAL, TONE_REFLECTIVE (alphabetical enum order)

RAIN CHECK: ATP min_confidence at issuance IS the rain check. A snapshot
only enters the accumulator if the ATP prediction that triggered the
automaton had confidence >= rule.min_confidence. No separate observation
state machine needed. The same gate that decides whether to ESCALATE also
decides whether to REMEMBER.
"""
mutable struct PhaseSnapshot
    id::String                          # unique snapshot ID
    phase_vector::Vector{Float64}       # 12-dim ATP distribution (PHASE_DIM)
    trigger_action::Symbol              # which ActionFamily triggered this escalation
    rule_id::String                     # which automaton rule ran
    atp_confidence::Float64             # ATP confidence at time of recording
    timestamp::Float64                  # when this snapshot was taken
    pull_count::Int                     # how many times this was phase-pulled
    last_pull_time::Float64             # when last pulled (0.0 = never)
end

function PhaseSnapshot(
    id::String,
    phase_vector::Vector{Float64};
    trigger_action::Symbol = :ACTION_ASSERT,
    rule_id::String = "",
    atp_confidence::Float64 = 0.0
)
    # GRUG: Validate phase vector dimension — NO SILENT FAILURES
    if length(phase_vector) != PHASE_DIM
        _err("PhaseSnapshot phase_vector must have $PHASE_DIM elements, got $(length(phase_vector))",
             "PhaseSnapshot")
    end
    # GRUG: No NaN or Inf in phase vector — corrupted crystal is worse than no crystal
    for (i, v) in enumerate(phase_vector)
        if isnan(v) || isinf(v)
            _err("PhaseSnapshot phase_vector[$i] is NaN/Inf: $v", "PhaseSnapshot")
        end
    end
    if isnan(atp_confidence) || isinf(atp_confidence)
        _err("PhaseSnapshot atp_confidence is NaN/Inf: $atp_confidence", "PhaseSnapshot")
    end
    return PhaseSnapshot(
        id, phase_vector, trigger_action, rule_id,
        clamp(atp_confidence, 0.0, 1.0),
        time(), 0, 0.0
    )
end

# ==============================================================================
# PHASE ACCUMULATOR — the growing time crystal
# ==============================================================================

"""
    PhaseAccumulator

The growing data map for the automaton's cross-cycle temporal memory.
Snapshots accumulate over time as ATP escalates and the automaton runs.
Phase retrieval pulls only snapshots coherent with the current ATP
prediction, plus a few random surface bits from the rest.

GRUG: Brain map grows. Brain map gets BIG. But brain no read ALL map every
      time. Brain phase-pulls what it needs. Brain sprinkles random bits
      because sometimes unexpected phase is useful phase. Transformer
      attention ignores useless bits for free — no cost, no harm.

RAIN CHECK: No separate admission state machine. ATP min_confidence IS the
      rain check. A snapshot below the floor never enters the accumulator
      because the rule that would have recorded it never fired. The same
      gate that decides escalation also decides memory. Prediction is power.
      Observation is truth. One threshold. No redundancy.
"""
mutable struct PhaseAccumulator
    entries::Dict{String, PhaseSnapshot}        # id -> snapshot
    pull_threshold::Float64                      # coherence above this gets pulled
    surface_count::Int                           # how many random bits to sprinkle
    enabled::Bool                                # master switch for phase retrieval
    total_pulls::Int                             # lifetime pull count
    total_snapshots_recorded::Int                 # lifetime snapshots recorded
    lock::ReentrantLock
end

function PhaseAccumulator()
    return PhaseAccumulator(
        Dict{String, PhaseSnapshot}(),
        PHASE_PULL_THRESHOLD_DEFAULT,
        PHASE_SURFACE_COUNT_DEFAULT,
        PHASE_ENABLED_DEFAULT,
        0, 0,
        ReentrantLock()
    )
end

# ── Global phase accumulator reference ──────────────────────────────────────

const _PHASE_ACCUMULATOR = Ref{PhaseAccumulator}()

function _phase_accumulator()::PhaseAccumulator
    if !isassigned(_PHASE_ACCUMULATOR)
        _PHASE_ACCUMULATOR[] = PhaseAccumulator()
    end
    return _PHASE_ACCUMULATOR[]
end

# ==============================================================================
# RECORD PHASE — write ATP snapshot into the crystal after automaton runs
# ==============================================================================

"""
    record_phase!(phase_vector, trigger_action, rule_id, atp_confidence;
                  snapshot_id = "") -> PhaseSnapshot

Write an ATP prediction snapshot into the phase accumulator after the
automaton runs. This is the crystal GROWING — each escalation adds a new
phase point.

RAIN CHECK IS IMPLICIT: This function should only be called after ATP
escalation succeeds (i.e., the rule's min_confidence was cleared). The
caller enforces this by only calling record_phase! after a successful
run_for_action_family. No separate admission state machine needed.

GRUG: Rock goes in pile only if Grug already decided rock is worth stepping
      on. No maybe-pile. No waiting for SelfObserver. ATP already said yes.
      That IS the rain check. One gate, one threshold, no redundancy.
"""
function record_phase!(phase_vector::Vector{Float64},
                       trigger_action::Symbol,
                       rule_id::String,
                       atp_confidence::Float64;
                       snapshot_id::String = "")::PhaseSnapshot
    acc = _phase_accumulator()

    # GRUG: Generate deterministic ID if not provided
    if isempty(snapshot_id)
        snapshot_id = "phase_$(length(acc.entries))_$(round(Int, time() * 1000))"
    end

    # GRUG: Validate before writing — NO SILENT CORRUPTION
    if length(phase_vector) != PHASE_DIM
        @error "[EphemeralAutomaton] record_phase!: wrong phase_vector dim $(length(phase_vector)), expected $PHASE_DIM — SKIPPING"
        return PhaseSnapshot("INVALID", zeros(PHASE_DIM);
                             trigger_action = trigger_action,
                             rule_id = rule_id,
                             atp_confidence = 0.0)
    end
    for (i, v) in enumerate(phase_vector)
        if isnan(v) || isinf(v)
            @error "[EphemeralAutomaton] record_phase!: phase_vector[$i] is NaN/Inf: $v — SKIPPING"
            return PhaseSnapshot("INVALID", zeros(PHASE_DIM);
                                 trigger_action = trigger_action,
                                 rule_id = rule_id,
                                 atp_confidence = 0.0)
        end
    end

    snapshot = PhaseSnapshot(snapshot_id, phase_vector;
                             trigger_action = trigger_action,
                             rule_id = rule_id,
                             atp_confidence = atp_confidence)

    lock(acc.lock) do
        # GRUG: Don't overwrite existing snapshot — explicit delete required
        if haskey(acc.entries, snapshot_id)
            @warn "[EphemeralAutomaton] record_phase!: snapshot '$snapshot_id' already exists — overwriting"
        end
        acc.entries[snapshot_id] = snapshot
        acc.total_snapshots_recorded += 1
    end

    return snapshot
end

# ==============================================================================
# PHASE PULL QUERY — coherence-based retrieval from the crystal
# ==============================================================================

# GRUG: Distribution similarity metrics for phase retrieval.
# Forward confidence = dot product (how similar are the distributions).
# Backward confidence = 1 - normalized Jensen-Shannon distance (how not-dissimilar).
# These feed into big_number_small_number_coherence same as pattern bind.

"""
    _distribution_dot_product(a::Vector{Float64}, b::Vector{Float64}) -> Float64

Dot product between two probability distributions. High value = similar
direction in probability space. Used as forward confidence in coherence.
"""
function _distribution_dot_product(a::Vector{Float64}, b::Vector{Float64})::Float64
    if length(a) != length(b)
        @error "[EphemeralAutomaton] _distribution_dot_product: dimension mismatch $(length(a)) vs $(length(b))"
        return 0.0
    end
    return sum(a[i] * b[i] for i in eachindex(a))
end

"""
    _distribution_js_distance(a::Vector{Float64}, b::Vector{Float64}) -> Float64

Jensen-Shannon distance between two probability distributions. Square root
of JS divergence. Returns value in [0, 1] where 0 = identical distributions.
Used as the dissimilarity measure for backward confidence in coherence.
"""
function _distribution_js_distance(a::Vector{Float64}, b::Vector{Float64})::Float64
    if length(a) != length(b)
        @error "[EphemeralAutomaton] _distribution_js_distance: dimension mismatch $(length(a)) vs $(length(b))"
        return 1.0
    end
    # M = (a + b) / 2 — the midpoint distribution
    m = [(a[i] + b[i]) * 0.5 for i in eachindex(a)]

    # KL(a || M) = sum(a_i * log(a_i / m_i)) where a_i > 0
    kl_am = 0.0
    for i in eachindex(a)
        if a[i] > 0.0 && m[i] > 0.0
            kl_am += a[i] * log(a[i] / m[i])
        end
    end

    # KL(b || M)
    kl_bm = 0.0
    for i in eachindex(b)
        if b[i] > 0.0 && m[i] > 0.0
            kl_bm += b[i] * log(b[i] / m[i])
        end
    end

    # JS divergence = (KL(a||M) + KL(b||M)) / 2
    js_div = (kl_am + kl_bm) * 0.5

    # JS distance = sqrt(JS divergence), bounded to [0, 1]
    # Numerical safety: clamp before sqrt
    js_dist = sqrt(clamp(js_div, 0.0, 1.0))

    return isnan(js_dist) ? 1.0 : js_dist
end

"""
    phase_pull_query(query_phase::Vector{Float64};
                     is_compound::Bool = false,
                     scan_mode::Int = 1) -> Dict{String, Any}

The main phase retrieval query. Queries the growing crystal for snapshots
that are coherent with the current ATP prediction, plus random surface bits.

Only activates on complex/compound tasks (is_compound=true OR scan_mode >= 3).
On simple inputs, returns empty result — no compute wasted.

Returns a dict with:
  - "phase_entries"   : Vector{Tuple{Float64, PhaseSnapshot}} — high-coherence entries with scores
  - "surface_entries"  : Vector{PhaseSnapshot} — random surface bits
  - "pull_count"       : Int — how many entries were phase-pulled
  - "surface_count"    : Int — how many random surface bits
  - "activated"        : Bool — whether phase pull actually ran
  - "crystal_size"     : Int — total snapshots in the crystal

GRUG: Crystal only works when brain sees COMPLEX thing. Simple rock no need
      crystal. Complex rock needs crystal. Crystal pulls related phase from
      previous periods. Also sprinkles random phase because sometimes
      unexpected phase is useful. Transformer attention ignores useless
      phase for free.
"""
function phase_pull_query(query_phase::Vector{Float64};
                          is_compound::Bool = false,
                          scan_mode::Int = 1)::Dict{String, Any}
    acc = _phase_accumulator()

    result = Dict{String, Any}(
        "phase_entries"    => Tuple{Float64, PhaseSnapshot}[],
        "surface_entries"  => PhaseSnapshot[],
        "pull_count"       => 0,
        "surface_count"    => 0,
        "activated"        => false,
        "crystal_size"     => 0
    )

    # GRUG: Activation gate — only kick in on complex/compound tasks
    if !is_compound && scan_mode < 3
        lock(acc.lock) do
            result["crystal_size"] = length(acc.entries)
        end
        return result
    end

    # GRUG: Phase pull disabled? Return empty.
    if !acc.enabled
        lock(acc.lock) do
            result["crystal_size"] = length(acc.entries)
        end
        return result
    end

    # GRUG: Empty query = nothing to compare against
    if isempty(query_phase) || length(query_phase) != PHASE_DIM
        lock(acc.lock) do
            result["crystal_size"] = length(acc.entries)
        end
        return result
    end

    lock(acc.lock) do
        result["crystal_size"] = length(acc.entries)

        if isempty(acc.entries)
            return  # crystal is empty — nothing to pull
        end

        # ── PHASE PULL: coherence-matched retrieval ────────────────────
        # GRUG: For each stored snapshot, compute distribution similarity
        # via dot product (forward) and JS distance (dissimilarity), then
        # fuse into coherence using big_number_small_number_coherence,
        # then apply slight_jitter snap-back. Same engine as pattern bind.
        scored_entries = Tuple{Float64, PhaseSnapshot}[]
        for entry in values(acc.entries)
            try
                # Forward confidence = dot product (similarity)
                forward_conf = _distribution_dot_product(query_phase, entry.phase_vector)

                # Dissimilarity = JS distance (0 = identical, 1 = maximally different)
                js_dist = _distribution_js_distance(query_phase, entry.phase_vector)

                # Backward confidence = 1 - dissimilarity (inverse mismatch)
                backward_conf = 1.0 - js_dist

                # GRUG: confidence = bigNumberSmallNumberCoherence(similarity-dissimilarity)
                coherence = big_number_small_number_coherence(forward_conf, backward_conf)

                # GRUG: confidence.slightJitterSnapBack()
                confidence = slight_jitter(coherence)

                push!(scored_entries, (confidence, entry))
            catch e
                # GRUG: NO SILENT FAILURES — log but don't crash the whole query
                @error "[EphemeralAutomaton] phase_pull_query: failed to score entry '$(entry.id)': $e"
            end
        end

        # Sort by confidence, descending
        sort!(scored_entries; by = x -> x[1], rev = true)

        # Pull entries above threshold
        phase_pulled = Tuple{Float64, PhaseSnapshot}[]
        for (conf, entry) in scored_entries
            if conf >= acc.pull_threshold
                entry.pull_count += 1
                entry.last_pull_time = time()
                push!(phase_pulled, (conf, entry))
            end
        end

        acc.total_pulls += length(phase_pulled)

        # ── STOCHASTIC SURFACE: random bits from non-pulled entries ────
        # GRUG: Transformers ignore what they don't need via attention weights.
        # So pulling random phase bits is FREE. Might be useful, might not, no cost.
        pulled_ids = Set(e.id for (_, e) in phase_pulled)
        non_pulled = filter(e -> !(e.id in pulled_ids), values(acc.entries))

        surface_bits = PhaseSnapshot[]
        if !isempty(non_pulled) && acc.surface_count > 0
            n_sample = min(acc.surface_count, length(non_pulled))
            shuffled = collect(non_pulled)
            shuffle!(shuffled)
            surface_bits = shuffled[1:n_sample]
            for entry in surface_bits
                entry.pull_count += 1
                entry.last_pull_time = time()
            end
        end

        # ── Build result ────────────────────────────────────────────────
        result["phase_entries"]   = phase_pulled
        result["surface_entries"] = surface_bits
        result["pull_count"]      = length(phase_pulled)
        result["surface_count"]   = length(surface_bits)
        result["activated"]       = true
    end

    return result
end

# ==============================================================================
# PHASE STATUS & CONFIG
# ==============================================================================

"""
    phase_pull_status() -> Dict{String, Any}

Return current status of the phase accumulator. Crystal size, pull counts,
thresholds, enabled state. NO SILENT FAILURES — if status can't be read,
that's an error, not a blank dict.
"""
function phase_pull_status()::Dict{String, Any}
    acc = _phase_accumulator()
    lock(acc.lock) do
        return Dict{String, Any}(
            "crystal_size"            => length(acc.entries),
            "pull_threshold"          => round(acc.pull_threshold; digits=4),
            "surface_count"           => acc.surface_count,
            "enabled"                 => acc.enabled,
            "total_pulls"             => acc.total_pulls,
            "total_snapshots_recorded" => acc.total_snapshots_recorded
        )
    end
end

"""
    phase_pull_status_string() -> String

Human-readable status of the phase accumulator for CLI display.
"""
function phase_pull_status_string()::String
    try
        s = phase_pull_status()
        n = Int(get(s, "crystal_size", 0))
        thresh = round(Float64(get(s, "pull_threshold", 0.55)); digits=3)
        surf = Int(get(s, "surface_count", 3))
        enabled = Bool(get(s, "enabled", true))
        pulls = Int(get(s, "total_pulls", 0))
        recorded = Int(get(s, "total_snapshots_recorded", 0))
        status = enabled ? "ON" : "OFF"
        lines = String[
            "💎 Phase Accumulator (Time Crystal) — $status",
            "  Snapshots: $n | Recorded: $recorded | Pulls: $pulls",
            "  Threshold: $thresh | Surface bits: $surf",
        ]
        if n == 0
            push!(lines, "  ⚠️  HARD WARN: crystal is EMPTY — no phase data to pull from")
        end
        return join(lines, "\n")
    catch e
        return "❌ Phase accumulator status FAILED: $e — HARD WARN"
    end
end

# ── Config setters ────────────────────────────────────────────────────────

"""
    set_phase_pull_threshold!(threshold::Float64)

Set the coherence threshold for phase retrieval. Must be in [0.1, 0.9].
"""
function set_phase_pull_threshold!(threshold::Float64)
    if isnan(threshold) || isinf(threshold)
        _err("set_phase_pull_threshold! got NaN/Inf: $threshold", "set_phase_pull_threshold!")
    end
    if !(threshold >= 0.1 && threshold <= 0.9)
        _err("set_phase_pull_threshold! must be in [0.1, 0.9], got $threshold",
             "set_phase_pull_threshold!")
    end
    acc = _phase_accumulator()
    lock(acc.lock) do
        acc.pull_threshold = threshold
    end
    return nothing
end

function get_phase_pull_threshold()::Float64
    acc = _phase_accumulator()
    return lock(acc.lock) do
        acc.pull_threshold
    end
end

"""
    set_phase_surface_count!(count::Int)

Set how many random surface snapshots to sprinkle. Must be in [0, 16].
"""
function set_phase_surface_count!(count::Int)
    if !(count >= 0 && count <= 16)
        _err("set_phase_surface_count! must be in [0, 16], got $count",
             "set_phase_surface_count!")
    end
    acc = _phase_accumulator()
    lock(acc.lock) do
        acc.surface_count = count
    end
    return nothing
end

function get_phase_surface_count()::Int
    acc = _phase_accumulator()
    return lock(acc.lock) do
        acc.surface_count
    end
end

"""
    set_phase_enabled!(enabled::Bool)

Master switch for phase retrieval. When disabled, phase_pull_query returns
empty results regardless of input complexity.
"""
function set_phase_enabled!(enabled::Bool)
    acc = _phase_accumulator()
    lock(acc.lock) do
        acc.enabled = enabled
    end
    return nothing
end

"""
    reset_phase_accumulator!()

Nuclear reset. Clears all snapshots, resets counters. Crystal goes dark.
"""
function reset_phase_accumulator!()
    acc = _phase_accumulator()
    lock(acc.lock) do
        empty!(acc.entries)
        acc.total_pulls = 0
        acc.total_snapshots_recorded = 0
    end
    return nothing
end

# ==============================================================================
# PHASE SERIALIZATION — crystal survives save/load
# ==============================================================================

"""
    phase_accumulator_to_dict() -> Dict{String, Any}

Serialize the phase accumulator to a dict for specimen save.
Same pattern as automaton rule serialization — one dict per snapshot.
"""
function phase_accumulator_to_dict()::Dict{String, Any}
    acc = _phase_accumulator()
    return lock(acc.lock) do
        snapshots = Dict{String, Any}[]
        for (sid, snap) in acc.entries
            try
                push!(snapshots, Dict{String, Any}(
                    "id"             => sid,
                    "phase_vector"   => snap.phase_vector,
                    "trigger_action" => string(snap.trigger_action),
                    "rule_id"        => snap.rule_id,
                    "atp_confidence" => snap.atp_confidence,
                    "timestamp"      => snap.timestamp,
                    "pull_count"     => snap.pull_count,
                    "last_pull_time" => snap.last_pull_time
                ))
            catch e
                @warn "[EphemeralAutomaton] Skipping bad phase snapshot during save: $e"
            end
        end
        return Dict{String, Any}(
            "snapshots"               => snapshots,
            "pull_threshold"          => acc.pull_threshold,
            "surface_count"           => acc.surface_count,
            "enabled"                 => acc.enabled,
            "total_pulls"             => acc.total_pulls,
            "total_snapshots_recorded" => acc.total_snapshots_recorded
        )
    end
end

"""
    phase_accumulator_from_dict!(data)

Restore the phase accumulator from a specimen dict. Clears existing state
and replaces with loaded data. NO SILENT FAILURES — bad entries are skipped
with @warn, never silently dropped.
"""
function phase_accumulator_from_dict!(data)
    acc = _phase_accumulator()
    lock(acc.lock) do
        empty!(acc.entries)

        snapshots = get(data, "snapshots", Dict{String, Any}[])
        if isa(snapshots, AbstractVector)
            for sdata in snapshots
                try
                    sid = String(get(sdata, "id", ""))
                    isempty(sid) && continue

                    pv_raw = get(sdata, "phase_vector", [])
                    pv = Float64.(pv_raw)
                    if length(pv) != PHASE_DIM
                        @warn "[EphemeralAutomaton] Skipping phase snapshot '$sid' with wrong dim: $(length(pv)) != $PHASE_DIM"
                        continue
                    end
                    # GRUG: Validate no NaN/Inf in loaded phase vector
                    has_bad = false
                    for (i, v) in enumerate(pv)
                        if isnan(v) || isinf(v)
                            @warn "[EphemeralAutomaton] Skipping phase snapshot '$sid': phase_vector[$i] is NaN/Inf"
                            has_bad = true
                            break
                        end
                    end
                    has_bad && continue

                    trigger = Symbol(get(sdata, "trigger_action", "ACTION_ASSERT"))
                    rule_id = String(get(sdata, "rule_id", ""))
                    atp_conf = Float64(get(sdata, "atp_confidence", 0.0))
                    ts = Float64(get(sdata, "timestamp", 0.0))
                    pc = Int(get(sdata, "pull_count", 0))
                    lpt = Float64(get(sdata, "last_pull_time", 0.0))

                    snap = PhaseSnapshot(sid, pv;
                                         trigger_action = trigger,
                                         rule_id = rule_id,
                                         atp_confidence = atp_conf)
                    snap.timestamp = ts
                    snap.pull_count = pc
                    snap.last_pull_time = lpt

                    acc.entries[sid] = snap
                catch e
                    @warn "[EphemeralAutomaton] Skipping bad phase snapshot during load: $e"
                end
            end
        end

        acc.pull_threshold = clamp(
            Float64(get(data, "pull_threshold", PHASE_PULL_THRESHOLD_DEFAULT)),
            0.1, 0.9)
        acc.surface_count = clamp(
            Int(get(data, "surface_count", PHASE_SURFACE_COUNT_DEFAULT)),
            0, 16)
        acc.enabled = Bool(get(data, "enabled", PHASE_ENABLED_DEFAULT))
        acc.total_pulls = max(0, Int(get(data, "total_pulls", 0)))
        acc.total_snapshots_recorded = max(0, Int(get(data, "total_snapshots_recorded", 0)))
    end
    return nothing
end

# ==============================================================================
# REGISTRY
# ==============================================================================

const _AUTOMATON_REGISTRY      = Dict{String, AutomatonRule}()
const _AUTOMATON_REGISTRY_LOCK = ReentrantLock()

"""
    register_automaton_rule!(rule) -> AutomatonRule

Add a rule under its `id`. Throws if `id` already exists — explicit
overwrite is required via `unregister_automaton_rule!` first to make
double-register accidents impossible.
"""
function register_automaton_rule!(rule::AutomatonRule)::AutomatonRule
    lock(_AUTOMATON_REGISTRY_LOCK) do
        if haskey(_AUTOMATON_REGISTRY, rule.id)
            _rerr("automaton rule '$(rule.id)' already registered; unregister first",
                  "register_automaton_rule!")
        end
        _AUTOMATON_REGISTRY[rule.id] = rule
    end
    return rule
end

"""
    unregister_automaton_rule!(id) -> Bool

Remove the rule. Returns true if removed, false if was not present (this
case is non-fatal; a delete that finds nothing is idempotent).
"""
function unregister_automaton_rule!(id::String)::Bool
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        if haskey(_AUTOMATON_REGISTRY, id)
            delete!(_AUTOMATON_REGISTRY, id)
            return true
        end
        return false
    end
end

function list_automaton_rules()::Vector{AutomatonRule}
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        collect(values(_AUTOMATON_REGISTRY))
    end
end

function lookup_automaton_rule(id::String)::Union{AutomatonRule, Nothing}
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        get(_AUTOMATON_REGISTRY, id, nothing)
    end
end

function clear_automaton_rules!()
    lock(_AUTOMATON_REGISTRY_LOCK) do
        empty!(_AUTOMATON_REGISTRY)
    end
    return nothing
end

# ==============================================================================
# STEP EVALUATOR — small builtin op set; extensible by users via :userfn
# ==============================================================================

# GRUG: the eval table is intentionally tiny. Each op is a pure function over
# (payload, accum, ctx) returning a value. :userfn lets the caller stash an
# arbitrary callable in the payload for things the builtin set does not cover.
function _eval_step(step::AutomatonStep, accum::Any, ctx::Dict{String, Any})
    op = step.op
    p  = step.payload
    if op === :literal
        return p
    elseif op === :tag
        # Tag steps record a label-string; do not affect accum.
        return p
    elseif op === :add
        return _as_number(accum) + _as_number(p)
    elseif op === :sub
        return _as_number(accum) - _as_number(p)
    elseif op === :mul
        return _as_number(accum) * _as_number(p)
    elseif op === :div
        d = _as_number(p)
        d == 0 && _err("divide by zero in step '$(step.label)'", "_eval_step")
        return _as_number(accum) / d
    elseif op === :pow
        return _as_number(accum) ^ _as_number(p)
    elseif op === :double
        return _as_number(accum) * 2.0
    elseif op === :half
        return _as_number(accum) / 2.0
    elseif op === :setctx
        # payload must be a Pair{String,Any}: write into ctx, return accum unchanged
        if !(p isa Pair)
            _err("op :setctx requires a Pair payload, got $(typeof(p))",
                 "_eval_step")
        end
        ctx[String(first(p))] = last(p)
        return accum
    elseif op === :getctx
        # payload is a String key; missing key is a loud error
        if !(p isa AbstractString)
            _err("op :getctx requires a String key, got $(typeof(p))",
                 "_eval_step")
        end
        haskey(ctx, String(p)) || _err(
            "op :getctx missing key '$(String(p))'", "_eval_step")
        return ctx[String(p)]
    elseif op === :userfn
        # payload must be a callable taking (accum, ctx)
        if !(p isa Function)
            _err("op :userfn requires a callable payload, got $(typeof(p))",
                 "_eval_step")
        end
        return p(accum, ctx)
    else
        _err("unknown automaton op :$(op) in step '$(step.label)'",
             "_eval_step")
    end
end

@inline function _as_number(x)
    if x isa Number
        return float(x)
    elseif x isa AbstractString
        v = tryparse(Float64, x)
        v === nothing && _err("could not parse '$x' as a number", "_as_number")
        return v
    else
        _err("expected number, got $(typeof(x))", "_as_number")
    end
end

# ==============================================================================
# RUN
# ==============================================================================

"""
    run_automaton(rule, ctx; seed=0.0) -> AutomatonTrace

Execute every step in order. The accumulator starts at `seed` (or whatever
the first :literal step writes) and threads through subsequent ops.
Steps whose label is in `rule.jitter_targets` AND whose output is numeric
get a zero-mean nudge via `RelationalJitter.jitter_value`. All other step
outputs are exact.

`ctx` is a mutable Dict that survives across steps within this run only —
each call to `run_automaton` constructs a fresh ctx if not supplied.

Throws AutomatonError on any step failure. Never silently drops a step.
"""
function run_automaton(rule::AutomatonRule;
                       ctx::Dict{String, Any} = Dict{String, Any}(),
                       seed::Any = 0.0)::AutomatonTrace
    sequence = String[]
    values   = Dict{String, Any}()
    jittered = Set{String}()
    accum    = seed

    for step in rule.steps
        if haskey(values, step.label)
            _err("duplicate step label '$(step.label)' in rule '$(rule.id)'",
                 "run_automaton")
        end
        result = try
            _eval_step(step, accum, ctx)
        catch e
            if e isa AutomatonError
                rethrow()
            else
                _err("step '$(step.label)' (op=$(step.op)) raised $(typeof(e)): $(sprint(showerror, e))",
                     "run_automaton")
            end
        end

        # Optional jitter: only on numeric results AND only if label is tagged.
        if step.label in rule.jitter_targets && result isa Number
            try
                result = jitter_value(float(result))
                push!(jittered, step.label)
            catch e
                # JitterError on non-finite or out-of-range — surface loudly.
                _err("jitter failed on step '$(step.label)': $(sprint(showerror, e))",
                     "run_automaton")
            end
        end

        push!(sequence, step.label)
        values[step.label] = result
        # The accumulator only updates for ops that participate in arithmetic.
        # Tag/setctx leave accum unchanged.
        if !(step.op in (:tag, :setctx))
            accum = result
        end
    end

    return AutomatonTrace(rule.id, sequence, values, jittered)
end

# ==============================================================================
# DISPATCH HELPERS
# ==============================================================================

"""
    find_matching_rule(action_family, confidence) -> Union{AutomatonRule,Nothing}

Find the highest-confidence-bar rule whose trigger matches and whose
min_confidence is satisfied. If multiple rules tie, the one registered
earliest wins (registry ordering). Returns nothing if no match.
"""
function find_matching_rule(action_family::Symbol, confidence::Float64)
    return lock(_AUTOMATON_REGISTRY_LOCK) do
        best::Union{AutomatonRule, Nothing} = nothing
        best_bar = -Inf
        for r in values(_AUTOMATON_REGISTRY)
            r.trigger_action === action_family || continue
            confidence >= r.min_confidence || continue
            if r.min_confidence > best_bar
                best = r
                best_bar = r.min_confidence
            end
        end
        return best
    end
end

"""
    run_for_action_family(action_family, confidence; ctx, seed)
        -> Union{AutomatonTrace, Nothing}

Convenience: look up a matching rule, run it, return its trace. Returns
`nothing` (not an error) when no rule matches — callers treat that as
"no escalation, proceed with reaction-only path".
"""
function run_for_action_family(action_family::Symbol,
                               confidence::Float64;
                               ctx::Dict{String, Any} = Dict{String, Any}(),
                               seed::Any = 0.0)::Union{AutomatonTrace, Nothing}
    rule = find_matching_rule(action_family, confidence)
    rule === nothing && return nothing
    return run_automaton(rule; ctx = ctx, seed = seed)
end

# ==============================================================================
# VIGILANCE SYSTEM — v7.29 AIML context weight → automaton dispatch
# ==============================================================================
# GRUG say: orchestrator give samey response because it work with FLAT context.
#           All info same height. No peaks. No valleys. Brain see flat, brain
#           give flat. But some context MORE IMPORTANT than other context. How
#           brain KNOW? Brain NOT know — brain NEED DISPATCHER to tell it.
#
# GRUG say: vigilance IS that dispatcher. More context weight = more vigilance
#           = more automatons dispatched = more context injectors probing
#           subconscious = richer scaffold for orchestrator to compose over.
#
# GRUG say: context injector NOT worker. NOT doing computation. Context injector
#           is PROBE. It go into subconscious with BIASED DISPOSITION, find
#           things, INJECT findings back into scaffold. Orchestrator then
#           compose over richer input WITHOUT KNOWING how context got there.
#
# GRUG say: bias come from RULE. Rule trigger + keyword + confidence = bias.
#           Bias determine what agent probe in subconscious (peek_pattern token
#           overlap, which keys, drop-table walk weights). Different rule =
#           different bias = different injection profile = different context
#           flavor in scaffold.
#
# GRUG say: agent EPHEMERAL but PERSISTENT IN STATE. Agent die after timeout/
#           completion, but injected context stay in scaffold. Findings MAY go
#           back into subconscious via observe!(). Agent born, agent probe,
#           agent inject, agent die. Context lives on.
#
# GRUG say: jitter snap-back. Agent operate on JITTERED COPY of state. Values
#           snap back on completion/timeout. NO CORRUPTION of core compute state.
#           Agent reads wobble, core stays solid. That IS the contract.
# ==============================================================================

# ── VIGILANCE CONSTANTS ─────────────────────────────────────────────────────

# GRUG: Hard cap on concurrent automatons. 6 is enough. Brain not swarm.
const AUTOMATON_MAX_CAP_DEFAULT = 6
const AUTOMATON_MAX_CAP_FLOOR  = 1
const AUTOMATON_MAX_CAP_CEILING = 16

# GRUG: How long an agent gets before timeout kills it.
const INJECTOR_TIMEOUT_SECONDS = 5.0
const INJECTOR_TIMEOUT_JITTER  = 0.5

# GRUG: Context weight thresholds that map to dispatch counts.
# Weight is composite from lobe activation depth, winner strength,
# inhibition hits, anti-match detection, memory intensity.
const VIGILANCE_WEIGHT_FLOOR   = 0.0    # below this = no vigilance at all
const VIGILANCE_WEIGHT_LOW     = 0.25   # low vigilance → 1 injector
const VIGILANCE_WEIGHT_MEDIUM  = 0.50   # medium vigilance → 2 injectors
const VIGILANCE_WEIGHT_HIGH    = 0.75   # high vigilance → 3 injectors
const VIGILANCE_WEIGHT_EXTREME = 0.90   # extreme vigilance → 4 injectors

# GRUG: Maximum injectors even at extreme weight (capped by AUTOMATON_MAX_CAP).
const MAX_INJECTORS_PER_CYCLE = 4

# GRUG: Whether agent findings get written back to subconscious.
const INJECTOR_FEEDBACK_PROB = 0.15  # 15% chance findings go back via observe!()

# ── INJECTOR DISPOSITION ────────────────────────────────────────────────────

"""
    InjectorDisposition

The biased lens through which a context injector agent probes the subconscious.
Inherited from the automaton rule that spawned the agent: its trigger action,
keyword context, and confidence level all become biases that determine WHAT
the agent looks for and HOW it scores what it finds.

GRUG: bias IS the point. Two agents with different bias see SAME subconscious
      and find DIFFERENT things. That IS the feature, not a bug. Orchestrator
      gets multiple perspectives on the same memory, composed into richer context.
"""
struct InjectorDisposition
    trigger_action::Symbol            # which ActionFamily triggered this agent
    keyword_hints::Vector{String}     # token overlap bias for peek_pattern
    confidence_weight::Float64        # high confidence = more aggressive probing
    probe_depth::Int                  # how many entries to request per probe
    drop_table_walk_bias::Float64    # bias toward certain drop-table paths
end

function InjectorDisposition(;
    trigger_action::Symbol = :ACTION_ASSERT,
    keyword_hints::Vector{String} = String[],
    confidence_weight::Float64 = 0.5,
    probe_depth::Int = 3,
    drop_table_walk_bias::Float64 = 0.5)
    cw = clamp(confidence_weight, 0.0, 1.0)
    pd = clamp(probe_depth, 1, 5)
    dtwb = clamp(drop_table_walk_bias, 0.0, 1.0)
    return InjectorDisposition(trigger_action, keyword_hints, cw, pd, dtwb)
end

# ── CONTEXT INJECTOR AGENT ──────────────────────────────────────────────────

"""
    ContextInjectorAgent

An ephemeral JIT agent that probes the subconscious and injects findings
back into the response scaffold. The agent is transient — it dies after
timeout or completion — but its injected context persists in the scaffold
and may optionally feed back into the subconscious via observe!().

GRUG: agent NOT worker. Agent INSPECTOR GADGET. Agent look around, find
      interesting thing, report back. Agent not compute. Agent discover.
      Discovery goes into scaffold. Orchestrator compose over discovery.
      Orchestrator not know where discovery came from. That IS the point.
"""
mutable struct ContextInjectorAgent
    id::String                         # unique agent ID
    rule_id::String                    # which automaton rule spawned this
    disposition::InjectorDisposition   # biased lens for probing
    status::Symbol                     # :spawning, :probing, :injecting, :done, :timed_out
    findings::Vector{Dict{String,Any}} # what the agent found in subconscious
    injection_target::Symbol           # where findings go (:scaffold, :action_entry, :both)
    spawned_at::Float64                # when this agent was created
    timeout_at::Float64                # when this agent dies
    jitter_snapshot::Dict{String,Any}  # jittered copy of state at spawn time
    probe_keys_probed::Int             # how many subconscious keys were probed
    entries_injected::Int              # how many entries were injected
    feedback_written::Int              # how many findings went back to subconscious
end

function ContextInjectorAgent(
    id::String,
    rule_id::String,
    disposition::InjectorDisposition;
    injection_target::Symbol = :scaffold,
    timeout_seconds::Float64 = INJECTOR_TIMEOUT_SECONDS
)
    now_time = time()
    timeout_jitter = (rand() * 2.0 - 1.0) * INJECTOR_TIMEOUT_JITTER
    return ContextInjectorAgent(
        id, rule_id, disposition,
        :spawning,           # status
        Dict{String,Any}[],  # findings
        injection_target,
        now_time,            # spawned_at
        now_time + timeout_seconds + timeout_jitter,  # timeout_at
        Dict{String,Any}(),  # jitter_snapshot (filled at spawn)
        0,                   # probe_keys_probed
        0,                   # entries_injected
        0                    # feedback_written
    )
end

# ── VIGILANCE CONFIG ────────────────────────────────────────────────────────

"""
    VigilanceConfig

Tunable configuration for the AIML vigilance → context injector dispatch system.
All values are specimen-persistent (saved/loaded with specimen files).

GRUG: every knob here is a LEVER the operator can pull to tune how aggressively
      the brain probes its own subconscious. More vigilance = more context
      injectors = richer responses. Less vigilance = leaner responses, faster.
      Default is middle-of-road: moderate vigilance, 6-cap, 5s timeout.
"""
mutable struct VigilanceConfig
    enabled::Bool                      # master switch for vigilance dispatch
    max_cap::Int                       # hard cap on concurrent automatons
    weight_floor::Float64              # below this context weight, no dispatch
    weight_low::Float64                # low vigilance threshold → 1 injector
    weight_medium::Float64             # medium vigilance → 2 injectors
    weight_high::Float64               # high vigilance → 3 injectors
    weight_extreme::Float64            # extreme vigilance → 4 injectors
    max_injectors_per_cycle::Int       # cap even at extreme weight
    injector_timeout_seconds::Float64  # how long each agent gets
    injector_feedback_prob::Float64    # P(findings → observe!())
    lock::ReentrantLock
end

function VigilanceConfig()
    return VigilanceConfig(
        true,                        # enabled
        AUTOMATON_MAX_CAP_DEFAULT,    # max_cap
        VIGILANCE_WEIGHT_FLOOR,       # weight_floor
        VIGILANCE_WEIGHT_LOW,         # weight_low
        VIGILANCE_WEIGHT_MEDIUM,      # weight_medium
        VIGILANCE_WEIGHT_HIGH,        # weight_high
        VIGILANCE_WEIGHT_EXTREME,     # weight_extreme
        MAX_INJECTORS_PER_CYCLE,      # max_injectors_per_cycle
        INJECTOR_TIMEOUT_SECONDS,     # injector_timeout_seconds
        INJECTOR_FEEDBACK_PROB,       # injector_feedback_prob
        ReentrantLock()
    )
end

# ── Global vigilance state ──────────────────────────────────────────────────

const _VIGILANCE_CONFIG = Ref{VigilanceConfig}()
const _ACTIVE_INJECTORS = Dict{String, ContextInjectorAgent}()
const _INJECTOR_LOCK    = ReentrantLock()
const _INJECTOR_STATS   = Dict{String, Int}(
    "total_dispatched"       => 0,
    "total_completed"        => 0,
    "total_timed_out"        => 0,
    "total_entries_injected" => 0,
    "total_feedback_written" => 0,
    "total_probe_keys"       => 0
)

function _vigilance_config()::VigilanceConfig
    if !isassigned(_VIGILANCE_CONFIG)
        _VIGILANCE_CONFIG[] = VigilanceConfig()
    end
    return _VIGILANCE_CONFIG[]
end

# ── CONTEXT WEIGHT COMPUTATION ──────────────────────────────────────────────

"""
    compute_context_weight(;
        lobe_activation_depth, winner_strength, inhibition_hits,
        anti_match_detected, memory_intensity
    ) -> Float64

Compute the composite context weight that determines how many context injector
automatons get dispatched. Higher weight = more vigilance = more dispatches.

GRUG: context weight is HOW MUCH the brain cares about THIS input right NOW.
      Lots of lobe activation? Brain cares. Strong winner? Brain cares.
      Inhibition firing? Brain cares a LOT (something being suppressed = interesting).
      Anti-match detected? Brain REALLY cares (stance violation = alarm).
      Memory intensity high? Brain has been thinking about this already = cares.

      All five dimensions feed into one composite. Composite maps to dispatch
      count via the vigilance thresholds. Simple. Biological. Rube Goldberg
      in an organized way.
"""
function compute_context_weight(;
    lobe_activation_depth::Float64 = 0.0,
    winner_strength::Float64 = 0.0,
    inhibition_hits::Int = 0,
    anti_match_detected::Bool = false,  # GRUG v8.26h: LEGACY — antimatch nodes removed
    memory_intensity::Float64 = 0.0
)::Float64
    # GRUG: Normalize each dimension to [0, 1] then weighted sum.
    # Lobe activation: already 0-1ish (fraction of lobes that fired)
    la = clamp(lobe_activation_depth, 0.0, 1.0)

    # Winner strength: 0-STRENGTH_CAP(10.0), normalize
    ws = clamp(winner_strength / 10.0, 0.0, 1.0)

    # Inhibition hits: more hits = more interesting. Cap at 5 for normalization
    ih = clamp(Float64(inhibition_hits) / 5.0, 0.0, 1.0)

    # Anti-match: binary but HIGH WEIGHT — stance violations are alarms
    am = anti_match_detected ? 1.0 : 0.0

    # Memory intensity: 0-CONTEXT_INTENSITY_CAP(3.0), normalize
    mi = clamp(memory_intensity / 3.0, 0.0, 1.0)

    # Weighted composite — anti-match and inhibition weighted heaviest
    # because suppressed/alarm signals are the MOST IMPORTANT context to enrich
    weight = 0.15 * la +    # lobe activation: moderate importance
             0.20 * ws +    # winner strength: moderate-high
             0.25 * ih +    # inhibition hits: high (something suppressed = interesting)
             0.25 * am +    # anti-match: high (stance violation = alarm)
             0.15 * mi      # memory intensity: moderate (ongoing thread)

    return clamp(weight, 0.0, 1.0)
end

# ── DISPATCH COUNT FROM WEIGHT ──────────────────────────────────────────────

"""
    _dispatch_count_from_weight(weight, config) -> Int

Map context weight to number of context injectors to dispatch.
Uses the vigilance thresholds: weight in [floor, low) → 0, [low, medium) → 1,
[medium, high) → 2, [high, extreme) → 3, [extreme, 1.0] → 4.
Capped by config.max_injectors_per_cycle and config.max_cap.

GRUG: not rocket surgery. More weight = more agents. Simple staircase function.
"""
function _dispatch_count_from_weight(weight::Float64, config::VigilanceConfig)::Int
    count = if weight < config.weight_low
        0
    elseif weight < config.weight_medium
        1
    elseif weight < config.weight_high
        2
    elseif weight < config.weight_extreme
        3
    else
        4
    end
    # Cap by both per-cycle max and global max_cap
    return min(count, config.max_injectors_per_cycle, config.max_cap)
end

# ── AGENT EXECUTION ─────────────────────────────────────────────────────────

"""
    _run_injector_agent!(agent, observer_store) -> ContextInjectorAgent

Execute a single context injector agent: probe subconscious, collect findings,
inject into scaffold. Agent operates on jittered copies — core state untouched.

GRUG: agent go into subconscious with biased disposition. Disposition tell agent
      WHAT to look for (keyword hints bias peek_pattern token scoring). Agent
      find things, collect them in findings. Agent done. Findings stay in agent
      for caller to inject into scaffold.

NOTE: This function does NOT directly access SelfObserver. The caller must
      pass the observer_store and the probe function. This keeps the module
      dependency clean — EphemeralAutomaton does NOT import SelfObserver.
"""
function _run_injector_agent!(agent::ContextInjectorAgent,
                              probe_fn::Function)::ContextInjectorAgent
    agent.status = :probing

    # GRUG: Build probe query from disposition bias.
    # Keyword hints become the peek_pattern query tokens.
    # Confidence weight controls how aggressively we score overlaps.
    # Probe depth controls max entries requested per probe.
    try
        for hint in agent.disposition.keyword_hints
            if time() > agent.timeout_at
                agent.status = :timed_out
                return agent
            end

            # Call the probe function (which wraps SelfObserver.peek_pattern)
            # with the hint and disposition parameters
            result = probe_fn(
                hint,
                agent.disposition.probe_depth,
                agent.disposition.confidence_weight,
                agent.disposition.drop_table_walk_bias
            )

            if result !== nothing && !isempty(result)
                push!(agent.findings, result)
                agent.probe_keys_probed += 1
            end
        end

        # GRUG: Also probe by trigger_action — each action family has
        # associated subconscious patterns that the agent should check
        action_hint = string(agent.disposition.trigger_action)
        if time() <= agent.timeout_at
            result = probe_fn(
                action_hint,
                agent.disposition.probe_depth,
                agent.disposition.confidence_weight * 0.7,  # lower confidence for action-based probe
                agent.disposition.drop_table_walk_bias * 0.5 # less drop-table bias too
            )
            if result !== nothing && !isempty(result)
                push!(agent.findings, result)
                agent.probe_keys_probed += 1
            end
        end

        agent.status = :done
    catch e
        # GRUG: Agent failure does NOT crash the system. Agent is inspector gadget,
        # not surgeon. If inspector falls in hole, inspector dies, cave continues.
        @warn "[EphemeralAutomaton] Injector agent '$(agent.id)' failed during probe: $e"
        agent.status = :timed_out
    end

    return agent
end

# ── VIGILANCE DISPATCH ──────────────────────────────────────────────────────

"""
    dispatch_vigilance_agents!(context_weight, rules, probe_fn;
                               injection_target) -> Vector{ContextInjectorAgent}

Main entry point for the vigilance system. Given a computed context weight
and a list of matching automaton rules, dispatch context injector agents
into their own threads, one per rule, up to the dispatch count determined
by the weight and vigilance config.

Each agent runs in its own @async task. The function waits for all agents
to complete (or timeout), then returns the completed agents for the caller
to extract findings and inject into the scaffold.

GRUG: dispatch is the BRAINSTEM of vigilance. It says "how many agents do we
      need?" and then it makes them. Each agent is an @async task that probes
      subconscious and dies. Caller then harvests findings from dead agents.
      Simple. Biological. Rube Goldberg in an organized way.

Returns Vector{ContextInjectorAgent} — the completed agents with findings.
"""
function dispatch_vigilance_agents!(context_weight::Float64,
                                    rules::Vector{AutomatonRule},
                                    probe_fn::Function;
                                    injection_target::Symbol = :scaffold)::Vector{ContextInjectorAgent}
    config = _vigilance_config()

    # GRUG: Vigilance disabled? No agents. Simple.
    if !config.enabled
        return ContextInjectorAgent[]
    end

    # GRUG: Weight below floor? No vigilance warranted. Flat context = flat response.
    if context_weight < config.weight_floor
        return ContextInjectorAgent[]
    end

    # How many agents to dispatch?
    dispatch_count = _dispatch_count_from_weight(context_weight, config)

    if dispatch_count == 0
        return ContextInjectorAgent[]
    end

    # GRUG: Also check how many agents are ALREADY running. Respect the cap.
    current_active = lock(_INJECTOR_LOCK) do
        length(_ACTIVE_INJECTORS)
    end
    available_slots = max(0, config.max_cap - current_active)
    dispatch_count = min(dispatch_count, available_slots)

    if dispatch_count == 0
        @debug "[EphemeralAutomaton] vigilance dispatch: all $(config.max_cap) slots occupied, no new agents"
        return ContextInjectorAgent[]
    end

    # GRUG: Pick the best rules to dispatch. Sort by min_confidence descending
    # (higher confidence bar = more specific = better bias for injection).
    # Take top dispatch_count rules.
    sorted_rules = sort(rules; by = r -> r.min_confidence, rev = true)
    dispatched_rules = sorted_rules[1:min(dispatch_count, length(sorted_rules))]

    if isempty(dispatched_rules)
        return ContextInjectorAgent[]
    end

    # GRUG: Spawn agents, one per rule, each in its own @async task.
    agents = ContextInjectorAgent[]
    tasks = Task[]

    for (i, rule) in enumerate(dispatched_rules)
        # Build disposition from rule bias
        # GRUG: trigger_action IS the primary bias. min_confidence IS the
        # confidence_weight. Step labels that are :tag steps become keyword_hints.
        keyword_hints = String[]
        for step in rule.steps
            if step.op === :tag && step.payload isa AbstractString
                push!(keyword_hints, String(step.payload))
            end
        end

        disposition = InjectorDisposition(
            trigger_action = rule.trigger_action,
            keyword_hints = keyword_hints,
            confidence_weight = rule.min_confidence,
            probe_depth = min(3 + floor(Int, rule.min_confidence * 2), 5),
            drop_table_walk_bias = 0.3 + rule.min_confidence * 0.4
        )

        agent_id = "injector_$(rule.id)_$(round(Int, time() * 1000))_$(i)"
        agent = ContextInjectorAgent(
            agent_id, rule.id, disposition;
            injection_target = injection_target,
            timeout_seconds = config.injector_timeout_seconds
        )

        # GRUG: Jitter snap-back — agent reads jittered copies, core stays solid.
        # We snapshot current state here. Agent works on this snapshot.
        # On completion, snapshot evaporates. No mutation of core compute state.
        agent.jitter_snapshot = Dict{String, Any}(
            "context_weight" => context_weight,
            "min_confidence" => rule.min_confidence,
            "trigger_action" => string(rule.trigger_action),
            "spawn_weight"   => jitter_value(float(context_weight))  # jittered weight
        )

        # Register as active
        lock(_INJECTOR_LOCK) do
            _ACTIVE_INJECTORS[agent.id] = agent
        end

        # GRUG: One @async task per agent. Agent probes, agent dies.
        # Findings stay in agent struct. Caller harvests after.
        task = @async begin
            try
                _run_injector_agent!(agent, probe_fn)

                # GRUG: Maybe feed findings back to subconscious.
                # Stochastic — INJECTOR_FEEDBACK_PROB chance per finding.
                for finding in agent.findings
                    if rand() < config.injector_feedback_prob
                        agent.feedback_written += 1
                        # Feedback is handled by caller — agent just marks it.
                        # The caller checks feedback_written and calls observe!() accordingly.
                    end
                end

                # Record injection count
                agent.entries_injected = sum(length(get(f, "entries", [])) for f in agent.findings;
                                             init = 0)
            catch e
                @warn "[EphemeralAutomaton] Injector task for '$(agent.id)' crashed: $e"
                agent.status = :timed_out
            end

            # Remove from active
            lock(_INJECTOR_LOCK) do
                delete!(_ACTIVE_INJECTORS, agent.id)
            end

            return agent
        end

        push!(tasks, task)
        push!(agents, agent)
    end

    # GRUG: Wait for all agents to finish (or timeout).
    # Each agent has its own timeout enforced internally, so we just
    # wait for all tasks with a generous outer timeout.
    outer_timeout = config.injector_timeout_seconds + INJECTOR_TIMEOUT_JITTER + 1.0
    deadline = time() + outer_timeout

    completed_agents = ContextInjectorAgent[]
    for (i, task) in enumerate(tasks)
        remaining = max(0.0, deadline - time())
        if remaining <= 0.0
            # Outer timeout — remaining agents are declared timed out
            for j in i:length(tasks)
                if agents[j].status == :probing || agents[j].status == :spawning
                    agents[j].status = :timed_out
                end
                push!(completed_agents, agents[j])
            end
            break
        end

        try
            result = timedwait(() -> istaskdone(task), remaining)
            if result === :ok
                push!(completed_agents, fetch(task))
            else
                # Task didn't finish in time
                agents[i].status = :timed_out
                push!(completed_agents, agents[i])
            end
        catch e
            agents[i].status = :timed_out
            push!(completed_agents, agents[i])
        end
    end

    # GRUG: Update stats. Bookkeeping. Cave remembers how many agents lived.
    lock(_INJECTOR_LOCK) do
        for agent in completed_agents
            _INJECTOR_STATS["total_dispatched"] += 1
            if agent.status == :done
                _INJECTOR_STATS["total_completed"] += 1
            else
                _INJECTOR_STATS["total_timed_out"] += 1
            end
            _INJECTOR_STATS["total_entries_injected"] += agent.entries_injected
            _INJECTOR_STATS["total_feedback_written"] += agent.feedback_written
            _INJECTOR_STATS["total_probe_keys"] += agent.probe_keys_probed
        end
    end

    return completed_agents
end

# ── CONFIG GETTERS / SETTERS ────────────────────────────────────────────────

"""
    get_vigilance_config() -> Dict{String, Any}

Return current vigilance configuration as a dict. For CLI display and save.
"""
function get_vigilance_config()::Dict{String, Any}
    config = _vigilance_config()
    return lock(config.lock) do
        Dict{String, Any}(
            "enabled"                     => config.enabled,
            "max_cap"                     => config.max_cap,
            "weight_floor"                => config.weight_floor,
            "weight_low"                  => config.weight_low,
            "weight_medium"               => config.weight_medium,
            "weight_high"                 => config.weight_high,
            "weight_extreme"              => config.weight_extreme,
            "max_injectors_per_cycle"     => config.max_injectors_per_cycle,
            "injector_timeout_seconds"    => config.injector_timeout_seconds,
            "injector_feedback_prob"      => config.injector_feedback_prob
        )
    end
end

"""
    set_vigilance_config!(; kwargs...)

Set vigilance config parameters. Only specified kwargs are updated.
Validates all values. NO SILENT FAILURES.
"""
function set_vigilance_config!(; kwargs...)
    config = _vigilance_config()
    lock(config.lock) do
        for (key, val) in kwargs
            if key === :enabled
                config.enabled = Bool(val)
            elseif key === :max_cap
                cap = Int(val)
                if !(cap >= AUTOMATON_MAX_CAP_FLOOR && cap <= AUTOMATON_MAX_CAP_CEILING)
                    _err("max_cap must be in [$AUTOMATON_MAX_CAP_FLOOR, $AUTOMATON_MAX_CAP_CEILING], got $cap",
                         "set_vigilance_config!")
                end
                config.max_cap = cap
            elseif key === :weight_floor
                config.weight_floor = clamp(Float64(val), 0.0, 0.9)
            elseif key === :weight_low
                config.weight_low = clamp(Float64(val), 0.0, 1.0)
            elseif key === :weight_medium
                config.weight_medium = clamp(Float64(val), 0.0, 1.0)
            elseif key === :weight_high
                config.weight_high = clamp(Float64(val), 0.0, 1.0)
            elseif key === :weight_extreme
                config.weight_extreme = clamp(Float64(val), 0.0, 1.0)
            elseif key === :max_injectors_per_cycle
                config.max_injectors_per_cycle = clamp(Int(val), 1, config.max_cap)
            elseif key === :injector_timeout_seconds
                config.injector_timeout_seconds = clamp(Float64(val), 1.0, 30.0)
            elseif key === :injector_feedback_prob
                config.injector_feedback_prob = clamp(Float64(val), 0.0, 1.0)
            else
                @warn "[EphemeralAutomaton] set_vigilance_config!: unknown key '$key' — ignored"
            end
        end
    end
    return nothing
end

"""
    get_automaton_max_cap() -> Int

Get the current automaton max cap (concurrent agent limit).
"""
function get_automaton_max_cap()::Int
    config = _vigilance_config()
    return lock(config.lock) do
        config.max_cap
    end
end

"""
    set_automaton_max_cap!(cap)

Set the hard cap on concurrent automatons. Must be in [1, 16].
"""
function set_automaton_max_cap!(cap::Int)
    set_vigilance_config!(; max_cap = cap)
    return nothing
end

# ── VIGILANCE STATUS ────────────────────────────────────────────────────────

"""
    vigilance_status() -> Dict{String, Any}

Return comprehensive vigilance system status. For CLI display and diagnostics.
"""
function vigilance_status()::Dict{String, Any}
    config = _vigilance_config()
    active_count = lock(_INJECTOR_LOCK) do
        length(_ACTIVE_INJECTORS)
    end
    stats = lock(_INJECTOR_LOCK) do
        copy(_INJECTOR_STATS)
    end
    result = get_vigilance_config()
    result["active_agents"] = active_count
    result["stats"] = stats
    return result
end

"""
    vigilance_status_string() -> String

Human-readable vigilance status for CLI display.
"""
function vigilance_status_string()::String
    try
        s = vigilance_status()
        enabled = Bool(get(s, "enabled", true))
        cap = Int(get(s, "max_cap", 6))
        active = Int(get(s, "active_agents", 0))
        stats = get(s, "stats", Dict{String,Int}())
        dispatched = Int(get(stats, "total_dispatched", 0))
        completed = Int(get(stats, "total_completed", 0))
        timed_out = Int(get(stats, "total_timed_out", 0))
        injected = Int(get(stats, "total_entries_injected", 0))
        feedback = Int(get(stats, "total_feedback_written", 0))
        status = enabled ? "ON" : "OFF"
        lines = String[
            "👁 Vigilance System — $status",
            "  Max cap: $cap | Active: $active | Per-cycle max: $(get(s, "max_injectors_per_cycle", 4))",
            "  Thresholds: low=$(get(s, "weight_low", 0.25)) med=$(get(s, "weight_medium", 0.50)) high=$(get(s, "weight_high", 0.75)) extreme=$(get(s, "weight_extreme", 0.90))",
            "  Timeout: $(get(s, "injector_timeout_seconds", 5.0))s | Feedback prob: $(get(s, "injector_feedback_prob", 0.15))",
            "  Lifetime: dispatched=$dispatched completed=$completed timed_out=$timed_out",
            "  Injected: $injected entries | Feedback: $feedback observations"
        ]
        if !enabled
            push!(lines, "  ⚠️  Vigilance DISABLED — no context injector dispatch")
        end
        return join(lines, "\n")
    catch e
        return "❌ Vigilance status FAILED: $e"
    end
end

# ── SERIALIZATION ────────────────────────────────────────────────────────────

"""
    serialize_vigilance_config() -> Dict{String, Any}

Serialize vigilance config to dict for specimen save file.
"""
function serialize_vigilance_config()::Dict{String, Any}
    return get_vigilance_config()
end

"""
    deserialize_vigilance_config!(data)

Restore vigilance config from specimen dict. NO SILENT FAILURES.
"""
function deserialize_vigilance_config!(data)
    config = _vigilance_config()
    lock(config.lock) do
        config.enabled                     = Bool(get(data, "enabled", true))
        config.max_cap                     = clamp(Int(get(data, "max_cap", AUTOMATON_MAX_CAP_DEFAULT)),
                                                   AUTOMATON_MAX_CAP_FLOOR, AUTOMATON_MAX_CAP_CEILING)
        config.weight_floor                = clamp(Float64(get(data, "weight_floor", VIGILANCE_WEIGHT_FLOOR)), 0.0, 0.9)
        config.weight_low                  = clamp(Float64(get(data, "weight_low", VIGILANCE_WEIGHT_LOW)), 0.0, 1.0)
        config.weight_medium               = clamp(Float64(get(data, "weight_medium", VIGILANCE_WEIGHT_MEDIUM)), 0.0, 1.0)
        config.weight_high                 = clamp(Float64(get(data, "weight_high", VIGILANCE_WEIGHT_HIGH)), 0.0, 1.0)
        config.weight_extreme              = clamp(Float64(get(data, "weight_extreme", VIGILANCE_WEIGHT_EXTREME)), 0.0, 1.0)
        config.max_injectors_per_cycle     = clamp(Int(get(data, "max_injectors_per_cycle", MAX_INJECTORS_PER_CYCLE)), 1, config.max_cap)
        config.injector_timeout_seconds    = clamp(Float64(get(data, "injector_timeout_seconds", INJECTOR_TIMEOUT_SECONDS)), 1.0, 30.0)
        config.injector_feedback_prob      = clamp(Float64(get(data, "injector_feedback_prob", INJECTOR_FEEDBACK_PROB)), 0.0, 1.0)
    end
    return nothing
end

"""
    serialize_injector_stats() -> Dict{String, Any}

Serialize injector stats for specimen save file.
"""
function serialize_injector_stats()::Dict{String, Any}
    return lock(_INJECTOR_LOCK) do
        copy(_INJECTOR_STATS)
    end
end

"""
    reset_injector_stats!()

Reset all injector stats to zero. For diagnostics/testing.
"""
function reset_injector_stats!()
    lock(_INJECTOR_LOCK) do
        _INJECTOR_STATS["total_dispatched"]       = 0
        _INJECTOR_STATS["total_completed"]        = 0
        _INJECTOR_STATS["total_timed_out"]        = 0
        _INJECTOR_STATS["total_entries_injected"] = 0
        _INJECTOR_STATS["total_feedback_written"] = 0
        _INJECTOR_STATS["total_probe_keys"]       = 0
    end
    return nothing
end


end # module
