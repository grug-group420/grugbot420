# ==============================================================================
# EphemeralMLP.jl — v7.27 Sigmoid/ReLU Activated Ephemeral MLP with Transformer + PhaseMix
# ==============================================================================
# GRUG say: vote list is like river. Rocks fall in river, river carries rocks
#           to big mouth (AIML). Sometimes river carry rocks well. Sometimes
#           river carry rocks in clumps, or drops good rocks, or carries
#           noise rocks that should sink. Grug watch river. Grug learn.
#
# GRUG say: when Grug see SAME river many times, river is FAMILIAR. Grug use
#           SIGMOID brain — smooth, refined, "yes I have seen this before,
#           I know which rocks to keep." When Grug see NEW river, river is
#           UNFAMILIAR. Grug use RELU brain — sharp, exploring, "I have NOT
#           seen this before, let me try something different."
#
# GRUG say: SIGMOID path uses SOLID transformers — crystalized, precise,
#           rule-following. Like a master sculptor who has carved this shape
#           a thousand times. RELU path uses FUZZY transformers — exploratory,
#           soft-edged, associative. Like an artist trying a new medium for
#           the first time, reaching for connections that might not exist yet.
#
# GRUG say: this brain is EPHEMERAL in presence — it wakes up, thinks about
#           the vote list, writes its adjustments, then goes back to sleep.
#           It does NOT stay awake between cycles. It does NOT hold locks.
#           But its STATE is persistent — weights it learned, rules the user
#           gave it, patterns it noticed. These survive. The brain remembers
#           even though the thinking is momentary.
#
# GRUG say: key weights in this brain get JITTER SNAP-BACK. They wobble a
#           little each time the brain wakes up (exploration!), but on average
#           they snap back to their true value (no drift!). Step indices,
#           rule IDs, activation mode — these NEVER wobble. Only numeric
#           values that are accumulators or weights CAN wobble. Grug learned
#           this from RelationalJitter — same rock, different cave.
#
# GRUG say: user can add RULES to this brain. Rules live in a hash table
#           keyed by pattern. When a vote matches the pattern, the rule fires.
#           Rules can also be activated by KEY — like a named switch. Drop
#           tables link related rules together so firing one can cascade to
#           neighbors. This is the same drop-table trick SelfObserver uses.
#
# GRUG say: NO SILENT FAILURES. Every error path throws or logs loudly.
#           If the brain can't think, it says so. If a rule is bad, it says
#           why. If serialization breaks, it breaks loud. Grug hate quiet bugs.
#
# GRUG say: this module saves its state as a STANDALONE JSON structure under
#           the "ephemeral_mlp" key in the specimen file. It does NOT
#           interleave with other specimen sections. Load restores only this
#           module's state. Save writes only this module's state. Clean hands.
# ==============================================================================
#
# ACADEMIC: This module implements a Sigmoid/ReLU-activated MLP with transformer
# backing that processes the vote list (LAST_CONTRIBUTOR_VOTES) before it reaches
# AIML orchestration. The activation function serves double duty as a novelty
# detector: familiar inputs (Hopfield cache hit) route through sigmoid/solid
# transformers for refinement; novel inputs (no cache hit) route through
# ReLU/fuzzy transformers for exploration.
#
# The system is ephemeral in presence (processes and dies each cycle) but
# persistent in state (learned weights, user rules, and statistics survive
# across cycles and specimen save/load). Key weight values receive zero-mean
# jitter perturbation with statistical snap-back (identical mechanism to
# RelationalJitter), preserving exploration without corrupting deterministic
# computation.
#
# User-extensible rules are stored in a pattern/key-activated hash table with
# drop-table features (borrowed from SelfObserver's associative recall design).
# Rules may be activated by vote pattern match OR by explicit key lookup. Drop
# tables link related rules for cascading activation.
# ==============================================================================

module EphemeralMLP

using Random
using Base.Threads: ReentrantLock
using JSON

# ==============================================================================
# EXPORTS
# ==============================================================================

export EphemeralMLPState, MLPWeight, MLPTransformerRule, RuleHashTable
export EphemeralMLPError, EphemeralMLPConfigError, EphemeralMLPRuleError
export EphemeralMLPActivation
export ACTIVATION_SIGMOID, ACTIVATION_RELU
export init_ephemeral_mlp!, reset_ephemeral_mlp!
export transform_vote_list, get_mlp_status
export add_mlp_rule!, drop_mlp_rule!, list_mlp_rules, lookup_mlp_rule
export activate_rule_by_key!, activate_rules_by_pattern!
export to_specimen_dict, from_specimen_dict!
export register_right_feedback!, register_wrong_feedback!
export get_activation_mode, get_novelty_score
export set_observation_threshold!, get_observation_threshold
export get_strain_energy, is_hippocampal_warrant_active, dampen_strain!
export STRAIN_NOVELTY_WEIGHT, STRAIN_QUALITY_WEIGHT, STRAIN_THRESHOLD, STRAIN_FLOOR, STRAIN_CEILING
export MLP_TRANSFORM_FUZZY, MLP_TRANSFORM_SOLID
export phase_mix_hidden!

# ==============================================================================
# ERROR TYPES — GRUG: no silent failures
# ==============================================================================

struct EphemeralMLPError <: Exception
    message::String
    context::String
end

struct EphemeralMLPConfigError <: Exception
    message::String
    field::String
end

struct EphemeralMLPRuleError <: Exception
    message::String
    rule_id::String
end

function Base.showerror(io::IO, e::EphemeralMLPError)
    print(io, "EphemeralMLPError: ", e.message, " (context=", e.context, ")")
end
function Base.showerror(io::IO, e::EphemeralMLPConfigError)
    print(io, "EphemeralMLPConfigError: ", e.message, " (field=", e.field, ")")
end
function Base.showerror(io::IO, e::EphemeralMLPRuleError)
    print(io, "EphemeralMLPRuleError: ", e.message, " (rule_id=", e.rule_id, ")")
end

@inline _err(msg, ctx) = throw(EphemeralMLPError(msg, ctx))
@inline _cerr(msg, fld) = throw(EphemeralMLPConfigError(msg, fld))
@inline _rerr(msg, rid) = throw(EphemeralMLPRuleError(msg, rid))

# ==============================================================================
# CONSTANTS — GRUG: magic numbers live here, with reasons
# ==============================================================================

# GRUG: Activation mode symbols
const ACTIVATION_SIGMOID = :sigmoid   # familiar path — solid transformers
const ACTIVATION_RELU    = :relu      # novel path — fuzzy transformers

# GRUG: Transformer type symbols
const MLP_TRANSFORM_FUZZY = :fuzzy    # soft membership, exploratory (ReLU path)
const MLP_TRANSFORM_SOLID = :solid    # crisp, refining (Sigmoid path)

# GRUG: Novelty thresholds
const NOVELTY_THRESHOLD  = 0.5       # >= 0.5 = novel (ReLU), < 0.5 = familiar (Sigmoid)
const NOVELTY_FLOOR      = 0.0
const NOVELTY_CEILING    = 1.0

# GRUG v7.50: Hippocampal strain — the self-observer's felt deficit signal.
# When the MLP encounters novel input it can't handle well (high novelty +
# low directive_quality), that's STRAIN. The system hurt because it doesn't
# have enough structure. This strain flows to MitosisMode as a growth signal.
# Homeostatic loop: strain → mitosis → growth → strain decreases → calm.
const STRAIN_NOVELTY_WEIGHT     = 0.6   # how much novelty contributes to strain
const STRAIN_QUALITY_WEIGHT     = 0.4   # how much low quality contributes to strain
const STRAIN_THRESHOLD          = 0.55  # strain >= this = hippocampal warrant fires
const STRAIN_FLOOR              = 0.0
const STRAIN_CEILING            = 1.0

# GRUG: Weight bounds
const WEIGHT_FLOOR       = -2.0
const WEIGHT_CEILING     = 2.0
const WEIGHT_DEFAULT     = 0.0

# GRUG: Jitter snap-back — same principle as RelationalJitter
# Zero-mean perturbation: δ ~ U(-ε·|w|, +ε·|w|), E[w+δ] = w
const JITTER_RATIO       = 0.03      # 3% wobble on jitter-eligible weights
const JITTER_ENABLED_REF = Ref(true) # global toggle for deterministic tests

# GRUG: Learning rate for /right /wrong feedback
const LEARNING_RATE_POSITIVE = 0.05  # how much /right nudges weights up
const LEARNING_RATE_NEGATIVE = 0.08  # how much /wrong nudges weights down (stronger signal)

# GRUG: SelfObserver gate — CONSERVATIVE THRESHOLD
# The MLP's adjustments to the vote list are ZERO until SelfObserver has
# accumulated at least this many observations for the relevant topic.
# Prediction is power. Observation is truth. A prediction only becomes
# real when it happens at observation time. Until then, the MLP predicts
# but does NOT modify. This prevents hallucinated directives from
# corrupting actual vote confidence.
# OBSERVATION_THRESHOLD is now a mutable field in EphemeralMLPState (default 5).
# Use set_observation_threshold!(n) / get_observation_threshold() to change it.

# GRUG: Rule table bounds
const MAX_RULES             = 128
const MAX_DROP_TABLE_ENTRIES = 16    # per-rule drop table links
const MAX_PATTERN_LENGTH    = 256
const MAX_RULE_ID_LENGTH    = 64

# GRUG: Transformer dimensionality (small — this is a sparse system)
# VOTE_FEATURE_DIM = 8 (vote features) + 4 (input correlation features) = 12
const VOTE_FEATURE_DIM     = 12      # features extracted per vote (8 vote + 4 input correlation)
const HIDDEN_DIM           = 16      # hidden layer width
const ATTENTION_HEADS      = 2       # sparse attention heads

# GRUG: History for novelty estimation
const NOVELTY_HISTORY_SIZE = 64      # rolling window of hash-based novelty scores

# GRUG: Input correlation tracking — the MLP learns input→directive correlations
# by storing lightweight hashes of user inputs alongside the vote list hashes
const INPUT_CORRELATION_HISTORY_SIZE = 128  # how many input→vote correlations to track


# GRUG: Phase mix selective attention — the automaton accumulates ATP phase snapshots
# across cycles (time crystal). When a complex input arrives, phase_pull_query retrieves
# the most coherent snapshots from the accumulator. Their 12-dim ATP distribution vectors
# blend into the hidden state via phase_mix_hidden! — hippocampal retrieval that speaks
# the automaton's native language. Rain check = ATP min_confidence gate at issuance.
# Surface bits: random snapshots sprinkled in for exploratory diversity (transformers
# ignore what they don't need). Only kicks in on complex/compound tasks.
# you don't need all of it every time. Only pull high-confidence related data.
# Random bits sprinkled in are free (transformers ignore what they don't need).
# New data enters slowly via rain check gate (SelfObserver must approve).
#
        # Uses the same confidence system with jitter snap-back as pattern bind phase.

# Uses the same confidence system with jitter snap-back as pattern bind phase.
# Only kicks in on complex/compound tasks (needs high_res scan or compound input).


# Phase mix: constants for ATP phase vector blending from automaton's time crystal
const PHASE_DIM                  = 12    # 6 ActionFamily + 6 ToneFamily ATP distribution dims
const PHASE_MIX_STRENGTH         = 0.30  # how strongly phase-pulled vectors blend into hidden state
const PHASE_SURFACE_MIX_STRENGTH = 0.05  # how weakly random surface snapshots blend into hidden

# ==============================================================================
# WEIGHT WITH JITTER SNAP-BACK
# ==============================================================================

"""
    MLPWeight

A single weight in the MLP. Stores the deterministic value and whether
this weight is eligible for jitter snap-back. Jitter-eligible weights
wobble on each forward pass (exploration) but their mean snaps back to
the true value (no drift). Non-jitter weights are always bit-exact.
"""
mutable struct MLPWeight
    value::Float64
    jitter_eligible::Bool
    # GRUG: Internal — the wobbled value from last forward pass.
    # This is what the transformer used, but the TRUE value is `value`.
    # On next forward pass, a NEW wobble is drawn from zero-mean distribution.
    last_wobble::Float64

    function MLPWeight(value::Float64 = WEIGHT_DEFAULT; jitter_eligible::Bool = false)
        if !(WEIGHT_FLOOR <= value <= WEIGHT_CEILING)
            _cerr("Weight value $value outside [$WEIGHT_FLOOR, $WEIGHT_CEILING]", "value")
        end
        return new(value, jitter_eligible, 0.0)
    end
end

"""
    jitter_weight(w::MLPWeight)::Float64

Apply zero-mean jitter to a weight if jitter is enabled and the weight is
jitter-eligible. Returns the (possibly wobbled) value. The true value in
`w.value` is NEVER modified — only `w.last_wobble` records the displacement.

Statistical snap-back: E[w.value + δ] = w.value because δ ~ U(-ε·|w|, +ε·|w|).
Over many forward passes, the mean converges to the true value by LLN.
"""
function jitter_weight(w::MLPWeight)::Float64
    # GRUG: NO NaN. NO Inf. NO sign flip. NO silent failure.
    if !JITTER_ENABLED_REF[]
        w.last_wobble = 0.0
        return w.value
    end
    if !w.jitter_eligible
        w.last_wobble = 0.0
        return w.value
    end
    if w.value == 0.0
        # GRUG: Zero stays zero. No wobble on nothing.
        w.last_wobble = 0.0
        return 0.0
    end
    abs_val = abs(w.value)
    delta = (rand() * 2.0 - 1.0) * JITTER_RATIO * abs_val
    # GRUG: Clamp so we can't cross zero (no sign flip)
    if w.value > 0.0
        delta = min(delta, w.value - WEIGHT_FLOOR)   # can't go below floor
        delta = max(delta, -(w.value))               # can't cross zero
    else
        delta = max(delta, w.value - WEIGHT_CEILING)  # can't go above ceiling
        delta = min(delta, -(w.value))                # can't cross zero
    end
    w.last_wobble = delta
    result = w.value + delta
    # GRUG: Paranoid clamp — never let result escape bounds
    result = clamp(result, WEIGHT_FLOOR, WEIGHT_CEILING)
    if isnan(result) || isinf(result)
        _err("jitter_weight produced NaN/Inf! value=$(w.value) delta=$delta", "jitter_weight")
    end
    return result
end

# ==============================================================================
# RULE HASH TABLE — pattern/key activated with drop tables
# ==============================================================================

"""
    MLPTransformerRule

A user-extensible rule for the MLP transformer. Rules are activated either
by pattern match on vote content OR by explicit key activation. Each rule
carries a weight (how strongly it influences the transformer output), a
transformer type preference (:fuzzy or :solid), and a drop table of related
rule IDs for cascading activation.

GRUG: Rules are PERSISTENT — they survive across cycles. Rules are EPHEMERAL
      in activation — they fire during transform_vote_list and then go dormant.
"""
mutable struct MLPTransformerRule
    id::String                          # unique rule identifier
    pattern::String                     # regex pattern for vote matching
    key::String                         # explicit activation key
    weight::MLPWeight                   # how strongly this rule influences output
    transform_type::Symbol              # :fuzzy or :solid
    payload::Dict{String, Any}          # arbitrary data the rule carries
    drop_table::Vector{String}          # linked rule IDs for cascading activation
    fire_count::Int                     # how many times this rule has fired
    last_fire_time::Float64             # when this rule last fired (0.0 = never)
    enabled::Bool                       # user can disable without removing
end

function MLPTransformerRule(
    id::String,
    pattern::String;
    key::String = "",
    weight_value::Float64 = 1.0,
    weight_jitter::Bool = true,
    transform_type::Symbol = MLP_TRANSFORM_FUZZY,
    payload::Dict{String, Any} = Dict{String, Any}(),
    drop_table::Vector{String} = String[]
)
    # GRUG: Validate inputs — NO silent failures
    if strip(id) == ""
        _rerr("Rule ID cannot be empty", "")
    end
    if length(id) > MAX_RULE_ID_LENGTH
        _rerr("Rule ID too long (max $MAX_RULE_ID_LENGTH): '$id'", id)
    end
    if length(pattern) > MAX_PATTERN_LENGTH
        _rerr("Pattern too long (max $MAX_PATTERN_LENGTH)", id)
    end
    if transform_type ∉ (MLP_TRANSFORM_FUZZY, MLP_TRANSFORM_SOLID)
        _rerr("transform_type must be :fuzzy or :solid, got :$transform_type", id)
    end
    # GRUG: Validate regex compiles
    try
        Regex(pattern)
    catch e
        _rerr("Pattern does not compile: $e", id)
    end
    if length(drop_table) > MAX_DROP_TABLE_ENTRIES
        _rerr("Drop table too long (max $MAX_DROP_TABLE_ENTRIES): $(length(drop_table)) entries", id)
    end
    w = MLPWeight(weight_value; jitter_eligible = weight_jitter)
    return MLPTransformerRule(
        id, pattern, key, w, transform_type,
        payload, copy(drop_table), 0, 0.0, true
    )
end

"""
    RuleHashTable

The rule storage for the EphemeralMLP. Rules are stored in a dict keyed by
rule ID. A secondary index maps activation keys to rule IDs for O(1) key
lookup. Pattern matching scans all rules (acceptable for MAX_RULES = 128).
Drop tables are stored per-rule and used for cascading activation.
"""
mutable struct RuleHashTable
    rules::Dict{String, MLPTransformerRule}     # id -> rule
    key_index::Dict{String, Vector{String}}     # activation key -> [rule_ids]
    lock::ReentrantLock
end

function RuleHashTable()
    return RuleHashTable(
        Dict{String, MLPTransformerRule}(),
        Dict{String, Vector{String}}(),
        ReentrantLock()
    )
end

# ==============================================================================
# NOVELTY TRACKER — rolling window of input familiarity scores
# ==============================================================================

"""
    NoveltyTracker

Tracks a rolling window of novelty scores (0.0 = most familiar, 1.0 = most
novel) to estimate whether the current input is familiar or novel. The score
is based on how often we've seen similar vote-list hashes recently.
"""
mutable struct NoveltyTracker
    history::Vector{Float64}           # rolling window of novelty scores
    hash_counts::Dict{UInt64, Int}     # how many times each hash appeared
    total_observations::Int
end

function NoveltyTracker()
    return NoveltyTracker(
        Float64[],
        Dict{UInt64, Int}(),
        0
    )
end

# ==============================================================================
# INPUT CORRELATION TRACKER — learns input→directive correlations
# ==============================================================================

"""
    InputCorrelationEntry

A single recorded correlation between a user input hash and the resulting
vote-list hash + directive quality. The MLP uses these to learn which
inputs produce which directive patterns. Over time, familiar inputs should
produce better (higher quality) directives because the MLP has learned
the correlation.
"""
struct InputCorrelationEntry
    input_hash::UInt64                 # hash of the original user input
    vote_hash::UInt64                  # hash of the resulting vote list
    directive_quality::Float64         # MLP quality score for this pair
    timestamp::Float64                 # when this correlation was recorded
end

"""
    InputCorrelationTracker

Tracks correlations between user inputs and the resulting vote-list
directives. The MLP uses this to learn which input patterns tend to
produce good or bad directive quality, so it can route familiar inputs
through the solid/sigmoid path with confidence and novel inputs through
the fuzzy/ReLU path for exploration.

GRUG: Brain need to know what question was ASKED, not just what rocks
      answered. Different questions → different rocks → different quality.
      Without the question, brain is blind.
"""
mutable struct InputCorrelationTracker
    entries::Vector{InputCorrelationEntry}
    input_quality_ema::Dict{UInt64, Float64}  # EMA of quality per input hash
    total_correlations::Int
end

function InputCorrelationTracker()
    return InputCorrelationTracker(
        InputCorrelationEntry[],
        Dict{UInt64, Float64}(),
        0
    )
end

# ==============================================================================
# MLP WEIGHT MATRICES — the actual neural weights (small, sparse)
# ==============================================================================

"""
    MLPWeights

The weight matrices for the MLP. Small by design — this is a sparse system
that processes one feature (the vote list), not a general-purpose neural net.
Weights are stored as flat vectors with jitter eligibility flags.

Architecture:
  input (VOTE_FEATURE_DIM) → hidden (HIDDEN_DIM) → output (1)

The output is a single scalar: the directive quality score. This score
modulates how the vote list is re-weighted before being passed to AIML.
"""
mutable struct MLPWeights
    # GRUG: Input → hidden weights (VOTE_FEATURE_DIM × HIDDEN_DIM)
    w_input_hidden::Vector{MLPWeight}   # length = VOTE_FEATURE_DIM * HIDDEN_DIM
    b_hidden::Vector{MLPWeight}         # length = HIDDEN_DIM

    # GRUG: Hidden → output weights (HIDDEN_DIM × 1)
    w_hidden_output::Vector{MLPWeight}  # length = HIDDEN_DIM
    b_output::MLPWeight                 # single output bias

    # GRUG: Attention weights for sparse transformer (HIDDEN_DIM × ATTENTION_HEADS)
    w_attention::Vector{MLPWeight}      # length = HIDDEN_DIM * ATTENTION_HEADS
end

function MLPWeights()
    total_ih = VOTE_FEATURE_DIM * HIDDEN_DIM
    # GRUG: Initialize with small random weights, hidden/output bias jitter-eligible
    w_ih = [MLPWeight((rand() - 0.5) * 0.1; jitter_eligible = true) for _ in 1:total_ih]
    b_h  = [MLPWeight(0.0; jitter_eligible = true) for _ in 1:HIDDEN_DIM]
    w_ho = [MLPWeight((rand() - 0.5) * 0.1; jitter_eligible = true) for _ in 1:HIDDEN_DIM]
    b_o  = MLPWeight(0.0; jitter_eligible = true)
    w_at = [MLPWeight((rand() - 0.5) * 0.1; jitter_eligible = true) for _ in 1:(HIDDEN_DIM * ATTENTION_HEADS)]
    return MLPWeights(w_ih, b_h, w_ho, b_o, w_at)
end

# ==============================================================================
# EPHEMERAL MLP STATE — the top-level state container
# ==============================================================================

"""
    EphemeralMLPState

The complete state of the EphemeralMLP module. This is what gets serialized
to the specimen file under the "ephemeral_mlp" key. The state is persistent
(learned weights, rules, statistics survive across cycles and save/load) but
the processing is ephemeral (the MLP wakes up, transforms the vote list,
then goes dormant — it does not hold any resources between cycles).

GRUG: Ephemeral in presence. Persistent in state. Like a dream you remember
      after waking up.
"""
mutable struct EphemeralMLPState
    weights::MLPWeights                    # the neural weights
    rules::RuleHashTable                   # user-extensible rules
    novelty_tracker::NoveltyTracker        # familiarity detection
    input_correlations::InputCorrelationTracker  # input→directive correlations
    last_activation::Symbol                # :sigmoid or :relu
    last_novelty_score::Float64            # 0.0-1.0
    last_transform_time::Float64           # when transform_vote_list last ran
    last_user_input::String                # the original user input from last cycle
    total_transforms::Int                  # lifetime transform count
    total_sigmoid_activations::Int         # how many times sigmoid path fired
    total_relu_activations::Int            # how many times relu path fired
    right_feedback_count::Int              # /right feedback received
    wrong_feedback_count::Int              # /wrong feedback received
    last_directive_quality::Float64        # output of last MLP forward pass
    selfobserver_observations::Int         # how many SelfObserver confirmations we've received
    observation_threshold::Int             # minimum SelfObserver entries before MLP adjustments are non-zero (user-editable)
    adjustments_enabled::Bool              # gate: true only after observation_threshold met
    strain_energy::Float64                 # GRUG v7.50: hippocampal strain signal (0.0-1.0). High = "I can't handle this"
    hippocampal_warrant_active::Bool       # GRUG v7.50: true when strain high + selfobserver confirmed = warrant for growth
    lock::ReentrantLock                    # protects all mutable state
end

function EphemeralMLPState()
    return EphemeralMLPState(
        MLPWeights(),
        RuleHashTable(),
        NoveltyTracker(),
        InputCorrelationTracker(),
        ACTIVATION_SIGMOID,     # default: assume familiar until proven novel
        0.5,                    # neutral novelty
        0.0,
        "",                     # no user input yet
        0, 0, 0, 0, 0,
        0.0,
        0,                      # no SelfObserver observations yet
        5,                      # observation_threshold default (was const OBSERVATION_THRESHOLD)
        false,                  # adjustments disabled until threshold met
        0.0,                    # no strain yet
        false,                  # no hippocampal warrant yet
        ReentrantLock()
    )
end

# ==============================================================================
# GLOBAL STATE — single module-level instance
# ==============================================================================

const _GLOBAL_STATE = Ref{EphemeralMLPState}()

"""
    _state()::EphemeralMLPState

Get the global EphemeralMLP state. Initializes on first call. NO silent
failure — if initialization fails, this throws.
"""
function _state()::EphemeralMLPState
    if !isassigned(_GLOBAL_STATE)
        _GLOBAL_STATE[] = EphemeralMLPState()
    end
    return _GLOBAL_STATE[]
end

# ==============================================================================
# INITIALIZATION
# ==============================================================================

"""
    init_ephemeral_mlp!()

Initialize or re-initialize the EphemeralMLP module. Creates fresh weights,
empty rule table, zero novelty history. NO silent failure — if weights can't
be allocated, this throws.
"""
function init_ephemeral_mlp!()
    try
        _GLOBAL_STATE[] = EphemeralMLPState()
    catch e
        _err("Failed to initialize EphemeralMLP: $e", "init_ephemeral_mlp!")
    end
    return "🧠 EphemeralMLP initialized — fresh weights, empty rules, ready to learn"
end

"""
    reset_ephemeral_mlp!()

Reset the EphemeralMLP to factory state but KEEP user rules. Weights are
re-initialized, statistics are zeroed, but rules the user added persist.
GRUG: User rules are sacred. Don't throw away what the user built.
"""
function reset_ephemeral_mlp!()
    st = _state()
    lock(st.lock) do
        saved_rules = st.rules  # keep user rules
        _GLOBAL_STATE[] = EphemeralMLPState()
        _GLOBAL_STATE[].rules = saved_rules
    end
    return "🧠 EphemeralMLP reset — fresh weights, rules preserved"
end

# ==============================================================================
# NOVELTY DETECTION
# ==============================================================================

"""
    compute_vote_list_hash(vote_data::Vector{Dict{String, Any}})::UInt64

Compute a stable hash from the vote list data for novelty tracking.
Only uses node_id and confidence — these capture the essential structure
of which nodes voted and how strongly.
"""
function compute_vote_list_hash(vote_data::Vector{Dict{String, Any}})::UInt64
    if isempty(vote_data)
        return UInt64(0)
    end
    # GRUG: Sort by node_id for stable hashing regardless of vote order
    sorted = sort(vote_data; by = v -> get(v, "node_id", ""))
    hash_parts = String[]
    for v in sorted
        push!(hash_parts, "$(get(v, "node_id", "")):$(round(Float64(get(v, "confidence", 0.0)); digits=2))")
    end
    return hash(join(hash_parts, "|"))
end

"""
    estimate_novelty(vote_data::Vector{Dict{String, Any}})::Float64

Estimate how novel this vote list is compared to recent history.
Returns 0.0 (completely familiar) to 1.0 (completely novel).

The novelty score drives the activation function:
  - score < NOVELTY_THRESHOLD (0.5) → SIGMOID → solid transformers (familiar)
  - score >= NOVELTY_THRESHOLD (0.5) → RELU → fuzzy transformers (novel)
"""
function estimate_novelty(vote_data::Vector{Dict{String, Any}})::Float64
    st = _state()
    h = compute_vote_list_hash(vote_data)

    lock(st.lock) do
        tracker = st.novelty_tracker
        tracker.total_observations += 1

        # GRUG: Count how many times we've seen this exact hash
        count = get(tracker.hash_counts, h, 0)
        tracker.hash_counts[h] = count + 1

        # GRUG: Novelty = inverse of how often we've seen this pattern
        # First time = 1.0 (maximally novel), seen N times = 1/N (capped)
        if count == 0
            novelty = 1.0
        else
            novelty = 1.0 / (1.0 + Float64(count))
        end

        # GRUG: Also factor in recent history diversity
        # If recent scores have been all similar (low variance), nudge novelty up
        if length(tracker.history) >= 3
            recent = tracker.history[max(1, end-2):end]
            variance = sum((x - mean_val(recent))^2 for x in recent) / length(recent)
            # GRUG: Low variance = stuck in a rut, nudge novelty up
            if variance < 0.01
                novelty = min(NOVELTY_CEILING, novelty + 0.1)
            end
        end

        # GRUG: Push to history (bounded)
        push!(tracker.history, novelty)
        if length(tracker.history) > NOVELTY_HISTORY_SIZE
            popfirst!(tracker.history)
        end

        return clamp(novelty, NOVELTY_FLOOR, NOVELTY_CEILING)
    end
end

# GRUG: Simple mean helper — avoid pulling in StatsAPI for one function
function mean_val(v::AbstractVector{<:Real})
    isempty(v) && return 0.0
    return sum(v) / length(v)
end

# ==============================================================================
# ACTIVATION FUNCTIONS
# ==============================================================================

"""
    sigmoid(x::Float64)::Float64

Numerically stable sigmoid: 1/(1+exp(-x)). Clamped to avoid overflow.
"""
function sigmoid(x::Float64)::Float64
    if x >= 20.0  return 1.0 end
    if x <= -20.0 return 0.0 end
    return 1.0 / (1.0 + exp(-x))
end

"""
    relu(x::Float64)::Float64

ReLU: max(0, x). Simple, effective, no overflow possible.
"""
function relu(x::Float64)::Float64
    return max(0.0, x)
end

# ==============================================================================
# FEATURE EXTRACTION FROM VOTES
# ==============================================================================

"""
    extract_vote_features(vote_data::Vector{Dict{String, Any}}, user_input::String = "")::Vector{Float64}

Extract a fixed-size feature vector from the vote list AND the original user
input. The MLP needs both to learn input→directive correlations — you can't
learn which questions produce good answers if you don't know what was asked.

Features (VOTE_FEATURE_DIM = 12):
  1. Number of votes (normalized)
  2. Mean confidence
  3. Confidence variance
  4. Max confidence
  5. Min confidence
  6. Fraction of votes with antimatch=true
  7. Number of unique node IDs (normalized)
  8. Confidence range (max - min)
  ── Input correlation features (4) ──
  9. Input length (normalized) — short questions vs long explanations
  10. Input word count (normalized) — complexity proxy
  11. Input question score — does the input contain question words?
  12. Input→vote correlation strength — how many times this input hash
      has been seen with similar vote patterns (EMA quality)
"""
function extract_vote_features(vote_data::Vector{Dict{String, Any}},
                               user_input::String = "")::Vector{Float64}
    if isempty(vote_data)
        return zeros(VOTE_FEATURE_DIM)
    end

    n = length(vote_data)
    confidences = Float64[Float64(get(v, "confidence", 0.0)) for v in vote_data]
    antimatches = count(v -> get(v, "antimatch", false) == true, vote_data)
    unique_nodes = length(unique([get(v, "node_id", "") for v in vote_data]))

    mean_conf = mean_val(confidences)
    var_conf = isempty(confidences) ? 0.0 :
        sum((c - mean_conf)^2 for c in confidences) / length(confidences)
    max_conf = isempty(confidences) ? 0.0 : maximum(confidences)
    min_conf = isempty(confidences) ? 0.0 : minimum(confidences)

    # ── Input correlation features ──────────────────────────────────────
    # GRUG: Brain needs to know what QUESTION was asked, not just what
    # rocks answered. Different questions → different quality.
    input_len = min(length(user_input) / 200.0, 1.0)   # normalized char count
    input_words = min(length(split(user_input)) / 50.0, 1.0)  # normalized word count

    # GRUG: Question score — does the input contain question indicators?
    question_words = ["what", "why", "how", "when", "where", "who", "which", "?"]
    input_lower = lowercase(user_input)
    question_score = 0.0
    for qw in question_words
        if occursin(qw, input_lower)
            question_score += 1.0 / length(question_words)
        end
    end
    question_score = min(question_score, 1.0)

    # GRUG: Input→vote correlation — has the MLP seen this input before?
    # If so, what's the EMA quality? High EMA = this input tends to produce
    # good directives. Low EMA = this input tends to produce bad ones.
    input_hash = isempty(user_input) ? UInt64(0) : hash(lowercase(strip(user_input)))
    st = _state()
    correlation_strength = 0.0
    if input_hash != UInt64(0)
        ema = get(st.input_correlations.input_quality_ema, input_hash, nothing)
        if !isnothing(ema)
            correlation_strength = clamp(ema, 0.0, 1.0)
        end
    end

    features = Float64[
        min(n / 10.0, 1.0),               # 1: normalized vote count
        mean_conf,                          # 2: mean confidence
        min(var_conf, 1.0),                 # 3: capped variance
        max_conf,                           # 4: max confidence
        min_conf,                           # 5: min confidence
        n > 0 ? Float64(antimatches) / n : 0.0,  # 6: antimatch fraction
        min(unique_nodes / 10.0, 1.0),     # 7: normalized unique nodes
        max_conf - min_conf,                # 8: confidence range
        input_len,                          # 9: input length (normalized)
        input_words,                        # 10: input word count (normalized)
        question_score,                     # 11: question indicator score
        correlation_strength                # 12: input→vote EMA quality
    ]

    # GRUG: Paranoid check — must be exactly VOTE_FEATURE_DIM
    if length(features) != VOTE_FEATURE_DIM
        _err("extract_vote_features produced $(length(features)) features, expected $VOTE_FEATURE_DIM",
             "extract_vote_features")
    end

    # GRUG: No NaN or Inf allowed in features
    for (i, f) in enumerate(features)
        if isnan(f) || isinf(f)
            _err("Feature $i is NaN/Inf: $f", "extract_vote_features")
        end
    end

    return features
end

# ==============================================================================
# FUZZY TRANSFORMER (ReLU / novel path)
# ==============================================================================

"""
    fuzzy_transform(hidden::Vector{Float64}, weights::MLPWeights, rules::Vector{MLPTransformerRule})::Vector{Float64}

Fuzzy transformer for the ReLU/novel path. Uses soft membership — attention
weights are NOT forced to sum to 1.0 (they're fuzzy). Explores connections
that might not exist yet. Rules with :fuzzy transform_type contribute extra
exploration bias.

GRUG: When brain sees NEW thing, brain reaches out in all directions.
      Fingers are soft. Some paths lead nowhere. That's OK — brain is LEARNING.
"""
function fuzzy_transform(hidden::Vector{Float64}, weights::MLPWeights,
                         rules::Vector{MLPTransformerRule})::Vector{Float64}
    if isempty(hidden)
        return Float64[]
    end

    # GRUG: Sparse attention over hidden states
    # Each head attends to a subset of hidden dimensions
    attention_output = zeros(HIDDEN_DIM)

    for head in 1:ATTENTION_HEADS
        head_offset = (head - 1) * HIDDEN_DIM
        head_weights = weights.w_attention[head_offset .+ (1:min(HIDDEN_DIM, length(weights.w_attention) - head_offset))]

        # GRUG: Fuzzy attention — soft membership, NOT normalized
        attended = Float64[]
        for (i, h_val) in enumerate(hidden)
            if i <= length(head_weights)
                w_val = jitter_weight(head_weights[i])
                # GRUG: Fuzzy = sigmoid-weighted contribution (soft, not crisp)
                contribution = sigmoid(w_val) * h_val
                push!(attended, contribution)
            else
                push!(attended, h_val * 0.5)  # default soft weight
            end
        end

        # GRUG: Accumulate into output (fuzzy = additive, not normalized)
        for i in 1:min(length(attended), HIDDEN_DIM)
            attention_output[i] += attended[i]
        end
    end

    # GRUG: Apply fuzzy rules as exploration bias
    rule_bias = zeros(HIDDEN_DIM)
    for rule in rules
        if !rule.enabled
            continue
        end
        w = jitter_weight(rule.weight)
        # GRUG: Fuzzy rules spread their influence across all dimensions
        # (exploratory — no hard targeting)
        for i in 1:HIDDEN_DIM
            # GRUG: Deterministic hash of rule ID to dimension index
            # ensures same rule always biases same dimensions
            dim_idx = (mod(hash(rule.id), HIDDEN_DIM) + 1)
            if dim_idx == i
                rule_bias[i] += w * 0.1  # soft influence
            end
        end
    end

    # GRUG: Combine attention + rule bias
    result = attention_output .+ rule_bias

    # GRUG: No NaN/Inf allowed
    for (i, r) in enumerate(result)
        if isnan(r) || isinf(r)
            _err("fuzzy_transform produced NaN/Inf at dim $i: $r", "fuzzy_transform")
        end
    end

    return result
end

# ==============================================================================
# SOLID TRANSFORMER (Sigmoid / familiar path)
# ==============================================================================

"""
    solid_transform(hidden::Vector{Float64}, weights::MLPWeights, rules::Vector{MLPTransformerRule})::Vector{Float64}

Solid/crystalized transformer for the Sigmoid/familiar path. Uses crisp
attention — weights are softmax-normalized so they sum to 1.0. Refines
known patterns with precision. Rules with :solid transform_type contribute
targeted adjustments.

GRUG: When brain sees SAME thing again, brain knows what to do. Fingers are
      precise. Every movement has purpose. Brain is REFINING, not exploring.
"""
function solid_transform(hidden::Vector{Float64}, weights::MLPWeights,
                         rules::Vector{MLPTransformerRule})::Vector{Float64}
    if isempty(hidden)
        return Float64[]
    end

    # GRUG: Crisp attention over hidden states
    # Each head produces a proper probability distribution
    attention_output = zeros(HIDDEN_DIM)

    for head in 1:ATTENTION_HEADS
        head_offset = (head - 1) * HIDDEN_DIM
        head_weights = weights.w_attention[head_offset .+ (1:min(HIDDEN_DIM, length(weights.w_attention) - head_offset))]

        # GRUG: Compute attention scores (raw, before softmax)
        scores = Float64[]
        for (i, h_val) in enumerate(hidden)
            if i <= length(head_weights)
                w_val = jitter_weight(head_weights[i])
                push!(scores, w_val * h_val)
            else
                push!(scores, h_val * 0.1)  # default low attention
            end
        end

        # GRUG: Softmax normalization — crisp attention, sums to 1.0
        max_score = isempty(scores) ? 0.0 : maximum(scores)
        exp_scores = [exp(s - max_score) for s in scores]  # numerical stability
        sum_exp = sum(exp_scores)
        if sum_exp <= 0.0
            # GRUG: Uniform attention if all scores are terrible
            attention_probs = fill(1.0 / length(scores), length(scores))
        else
            attention_probs = exp_scores ./ sum_exp
        end

        # GRUG: Weighted sum of hidden states
        for i in 1:min(length(attention_probs), length(hidden), HIDDEN_DIM)
            attention_output[i] += attention_probs[i] * hidden[i]
        end
    end

    # GRUG: Apply solid rules as targeted adjustments
    rule_adjustments = zeros(HIDDEN_DIM)
    for rule in rules
        if !rule.enabled
            continue
        end
        w = jitter_weight(rule.weight)
        # GRUG: Solid rules target SPECIFIC dimensions (deterministic)
        # based on rule ID hash — precise, not spread
        dim_idx = mod(hash(rule.id), HIDDEN_DIM) + 1
        rule_adjustments[dim_idx] += w * 0.2  # stronger, targeted influence
    end

    # GRUG: Combine attention + rule adjustments
    result = attention_output .+ rule_adjustments

    # GRUG: No NaN/Inf allowed
    for (i, r) in enumerate(result)
        if isnan(r) || isinf(r)
            _err("solid_transform produced NaN/Inf at dim $i: $r", "solid_transform")
        end
    end

    return result
end

# PHASE MIX - hippocampal retrieval blended into hidden state
# ==============================================================================
# GRUG: Phase vectors from the automaton's time crystal blend into the hidden
# state. Each 12-dim ATP distribution vector is projected to 16-dim hidden space
# via tile+scale, weighted by coherence * PHASE_MIX_STRENGTH. Surface snapshots
# at PHASE_SURFACE_MIX_STRENGTH. This is the automaton's voice in the MLP's brain.

"""
    phase_mix_hidden!(hidden::Vector{Float64},
                      phase_entries::Vector{Tuple{Float64, Vector{Float64}}},
                      surface_entries::Vector{Vector{Float64}})::Nothing

Blend retrieved ATP phase vectors directly into the hidden state.

Phase entries: (coherence, 12-dim_phase_vector) tuples from automaton's phase_pull_query.
Surface entries: random 12-dim phase vectors sprinkled in for diversity.

Projection: 12-dim phase vector tiled+scaled to 16-dim hidden space.
  hidden[j] += coherence * PHASE_MIX_STRENGTH * (scale * phase[((j-1) % PHASE_DIM)+1] + offset)

GRUG: Old way was MagnetPullEntry with 8-dim synthetic features. New way: 12-dim ATP
      distributions from the automaton's phase accumulator. The automaton IS the
      hippocampus now. The MLP just blends what the hippocampus retrieves.
"""
function phase_mix_hidden!(hidden::Vector{Float64},
                            phase_entries::Vector{Tuple{Float64, Vector{Float64}}},
                            surface_entries::Vector{Vector{Float64}})::Nothing
    # -- Phase entries: confidence-matched, strong blend --------------------
    for (coherence, phase_vector) in phase_entries
        try
            if length(phase_vector) != PHASE_DIM
                @error "[EphemeralMLP] phase_mix_hidden!: phase vector has wrong dim $(length(phase_vector)), expected $PHASE_DIM - skipping"
                continue
            end
            # Validate no NaN/Inf
            has_bad = false
            for (fi, pv) in enumerate(phase_vector)
                if isnan(pv) || isinf(pv)
                    @error "[EphemeralMLP] phase_mix_hidden!: phase_vector[$fi] is NaN/Inf: $pv - skipping entry"
                    has_bad = true
                    break
                end
            end
            if has_bad
                continue
            end

            # GRUG: Project 12-dim phase vector to 16-dim hidden space via tile+scale.
            # This gives every phase snapshot a UNIQUE hidden-space fingerprint.
            mix_strength = coherence * PHASE_MIX_STRENGTH
            for j in 1:length(hidden)
                src_idx = ((j - 1) % PHASE_DIM) + 1
                # Scale each phase dim to spread across hidden space range
                scale = 0.5 + 0.1 * (j / length(hidden))  # slight position-dependent scale
                offset = 0.01 * (j - 1) / length(hidden)   # slight position-dependent offset
                hidden[j] += mix_strength * (scale * phase_vector[src_idx] + offset)
            end
        catch e
            @error "[EphemeralMLP] phase_mix_hidden!: FAILED to mix phase entry: $e"
        end
    end

    # -- Surface entries: random phase bits, weak blend ---------------------
    for phase_vector in surface_entries
        try
            if length(phase_vector) != PHASE_DIM
                @error "[EphemeralMLP] phase_mix_hidden!: surface vector has wrong dim $(length(phase_vector)), expected $PHASE_DIM - skipping"
                continue
            end
            has_bad = false
            for (fi, pv) in enumerate(phase_vector)
                if isnan(pv) || isinf(pv)
                    @error "[EphemeralMLP] phase_mix_hidden!: surface vector[$fi] is NaN/Inf: $pv - skipping entry"
                    has_bad = true
                    break
                end
            end
            if has_bad
                continue
            end

            for j in 1:length(hidden)
                src_idx = ((j - 1) % PHASE_DIM) + 1
                scale = 0.5 + 0.1 * (j / length(hidden))
                offset = 0.01 * (j - 1) / length(hidden)
                hidden[j] += PHASE_SURFACE_MIX_STRENGTH * (scale * phase_vector[src_idx] + offset)
            end
        catch e
            @error "[EphemeralMLP] phase_mix_hidden!: FAILED to mix surface entry: $e"
        end
    end

    # -- Post-mix NaN/Inf guard --------------------------------------------
    for j in 1:length(hidden)
        if isnan(hidden[j]) || isinf(hidden[j])
            @error "[EphemeralMLP] phase_mix_hidden!: hidden[$j] is NaN/Inf after mixing: $(hidden[j]) - resetting to 0.0"
            hidden[j] = 0.0
        end
    end

    return
end


# MLP FORWARD PASS
# ==============================================================================

"""
    mlp_forward(features::Vector{Float64}, weights::MLPWeights, activation::Symbol, rules::Vector{MLPTransformerRule}; phase_entries, surface_entries)::Float64

Run the MLP forward pass: input → hidden → activation → transformer → output.
Returns the directive quality score (a scalar in [0, 1]).

The activation function determines the transformer path:
  - :sigmoid → solid_transform (familiar, refining)
  - :relu    → fuzzy_transform (novel, exploratory)
"""
function mlp_forward(features::Vector{Float64}, weights::MLPWeights,
                     activation::Symbol, rules::Vector{MLPTransformerRule};
                     phase_entries::Vector{Tuple{Float64, Vector{Float64}}} = Vector{Tuple{Float64, Vector{Float64}}}(),
                     surface_entries::Vector{Vector{Float64}} = Vector{Vector{Float64}}())::Float64
    if length(features) != VOTE_FEATURE_DIM
        _err("mlp_forward: expected $VOTE_FEATURE_DIM features, got $(length(features))",
             "mlp_forward")
    end

    # ── Input → Hidden ──────────────────────────────────────────────────
    hidden = zeros(HIDDEN_DIM)
    for j in 1:HIDDEN_DIM
        sum_val = jitter_weight(weights.b_hidden[j])
        for i in 1:VOTE_FEATURE_DIM
            idx = (i - 1) * HIDDEN_DIM + j
            if idx <= length(weights.w_input_hidden)
                sum_val += features[i] * jitter_weight(weights.w_input_hidden[idx])
            end
        end
        # GRUG: Apply activation function to get hidden state
        if activation == ACTIVATION_RELU
            hidden[j] = relu(sum_val)
        else
            hidden[j] = sigmoid(sum_val)
        end
    end

    # ── Transformer ─────────────────────────────────────────────────────
    # -- Phase mix: hippocampal retrieval into hidden state ----------------
    # GRUG: Retrieved phase snapshots from the automaton's time crystal BLEND into
    # what the brain sees. 12-dim ATP distributions projected to 16-dim hidden space.
    # That's real hippocampal retrieval - the automaton's voice in the MLP's brain.
    if !isempty(phase_entries) || !isempty(surface_entries)
        phase_mix_hidden!(hidden, phase_entries, surface_entries)
    end

    # GRUG: Route to fuzzy or solid transformer based on activation mode
    transformed = if activation == ACTIVATION_RELU
        fuzzy_transform(hidden, weights, rules)
    else
        solid_transform(hidden, weights, rules)
    end

    # ── Transformed → Output ────────────────────────────────────────────
    if isempty(transformed)
        return 0.5  # neutral quality when no transformation happened
    end

    output_sum = jitter_weight(weights.b_output)
    for i in 1:min(length(transformed), length(weights.w_hidden_output))
        output_sum += transformed[i] * jitter_weight(weights.w_hidden_output[i])
    end

    # GRUG: Final sigmoid to squash output to [0, 1]
    quality = sigmoid(output_sum)

    if isnan(quality) || isinf(quality)
        _err("mlp_forward produced NaN/Inf quality: $quality (output_sum=$output_sum)",
             "mlp_forward")
    end

    return clamp(quality, 0.0, 1.0)
end

# ==============================================================================
# RULE MANAGEMENT
# ==============================================================================

"""
    add_mlp_rule!(rule::MLPTransformerRule)

Register a new user rule. Throws on duplicate ID, full table, or bad input.
NO silent failure — if the rule can't be added, you'll know why.
"""
function add_mlp_rule!(rule::MLPTransformerRule)
    st = _state()
    lock(st.rules.lock) do
        if haskey(st.rules.rules, rule.id)
            _rerr("Rule ID '$(rule.id)' already exists — use drop_mlp_rule! first", rule.id)
        end
        if length(st.rules.rules) >= MAX_RULES
            _rerr("Rule table full (max $MAX_RULES) — drop some rules first", rule.id)
        end

        st.rules.rules[rule.id] = rule

        # GRUG: Update key index if rule has an activation key
        if !isempty(rule.key)
            if !haskey(st.rules.key_index, rule.key)
                st.rules.key_index[rule.key] = String[]
            end
            push!(st.rules.key_index[rule.key], rule.id)
        end
    end
    return "📋 MLP rule '$(rule.id)' registered (pattern='$(rule.pattern)', type=$(rule.transform_type), key='$(rule.key)')"
end

"""
    drop_mlp_rule!(rule_id::String)::Bool

Remove a user rule by ID. Returns true if removed, false if not found.
Also removes the rule from key indices and other rules' drop tables.
"""
function drop_mlp_rule!(rule_id::String)::Bool
    st = _state()
    removed = false
    lock(st.rules.lock) do
        if !haskey(st.rules.rules, rule_id)
            return  # will return from the lock block, not the function
        end

        rule = st.rules.rules[rule_id]

        # GRUG: Remove from key index
        if !isempty(rule.key) && haskey(st.rules.key_index, rule.key)
            filter!(id -> id != rule_id, st.rules.key_index[rule.key])
            if isempty(st.rules.key_index[rule.key])
                delete!(st.rules.key_index, rule.key)
            end
        end

        # GRUG: Remove from other rules' drop tables
        for (other_id, other_rule) in st.rules.rules
            filter!(id -> id != rule_id, other_rule.drop_table)
        end

        delete!(st.rules.rules, rule_id)
        removed = true
    end
    return removed
end

"""
    list_mlp_rules()::Vector{MLPTransformerRule}

Return a copy of all registered rules. Safe to iterate — the internal
table is not exposed.
"""
function list_mlp_rules()::Vector{MLPTransformerRule}
    st = _state()
    lock(st.rules.lock) do
        return collect(values(st.rules.rules))
    end
end

"""
    lookup_mlp_rule(rule_id::String)::Union{MLPTransformerRule, Nothing}

Look up a rule by ID. Returns nothing if not found (not an error — lookup
is a query, not a contract).
"""
function lookup_mlp_rule(rule_id::String)::Union{MLPTransformerRule, Nothing}
    st = _state()
    lock(st.rules.lock) do
        return get(st.rules.rules, rule_id, nothing)
    end
end

"""
    activate_rule_by_key!(key::String)::Vector{String}

Activate all rules matching the given activation key. Returns the IDs of
activated rules. Activated rules have their fire_count incremented and
last_fire_time set. Their drop-table neighbors are also activated.
"""
function activate_rule_by_key!(key::String)::Vector{String}
    st = _state()
    activated = String[]
    lock(st.rules.lock) do
        rule_ids = get(st.rules.key_index, key, String[])
        for rid in rule_ids
            rule = get(st.rules.rules, rid, nothing)
            if isnothing(rule) || !rule.enabled
                continue
            end
            rule.fire_count += 1
            rule.last_fire_time = time()
            push!(activated, rid)

            # GRUG: Cascade through drop table
            for drop_id in rule.drop_table
                drop_rule = get(st.rules.rules, drop_id, nothing)
                if !isnothing(drop_rule) && drop_rule.enabled
                    drop_rule.fire_count += 1
                    drop_rule.last_fire_time = time()
                    push!(activated, drop_id)
                end
            end
        end
    end
    return activated
end

"""
    activate_rules_by_pattern!(vote_text::String)::Vector{String}

Activate all rules whose pattern matches the given vote text. Returns the
IDs of activated rules (including drop-table cascades).
"""
function activate_rules_by_pattern!(vote_text::String)::Vector{String}
    st = _state()
    activated = String[]
    lock(st.rules.lock) do
        for (rid, rule) in st.rules.rules
            if !rule.enabled
                continue
            end
            try
                if occursin(Regex(rule.pattern), vote_text)
                    rule.fire_count += 1
                    rule.last_fire_time = time()
                    push!(activated, rid)

                    # GRUG: Cascade through drop table
                    for drop_id in rule.drop_table
                        drop_rule = get(st.rules.rules, drop_id, nothing)
                        if !isnothing(drop_rule) && drop_rule.enabled
                            drop_rule.fire_count += 1
                            drop_rule.last_fire_time = time()
                            push!(activated, drop_id)
                        end
                    end
                end
            catch e
                # GRUG: Bad regex in rule — LOG IT, don't silently skip
                @error "[EphemeralMLP] Rule '$rid' pattern match FAILED: $e"
            end
        end
    end
    return activated
end

# ==============================================================================
# FEEDBACK (/right /wrong integration)
# ==============================================================================

"""
    register_right_feedback!(directive_quality::Float64)

Apply positive feedback from /right. Nudges the weights that contributed
to the last directive quality score upward. Learning rate is conservative
(LEARNING_RATE_POSITIVE = 0.05) — the MLP learns slowly from positive
signals to avoid overfitting to any single good outcome.
"""
function register_right_feedback!(directive_quality::Float64)
    st = _state()
    lock(st.lock) do
        st.right_feedback_count += 1

        # GRUG: Nudge ALL jitter-eligible weights slightly upward
        # The closer the quality was to 1.0, the smaller the nudge
        # (already good → less to learn). The further from 1.0, the
        # bigger the nudge (surprising good outcome → more to learn).
        surprise = 1.0 - directive_quality  # 0.0 = expected, 1.0 = very surprising
        nudge = LEARNING_RATE_POSITIVE * surprise

        _nudge_weights!(st.weights, nudge)
    end
end

"""
    register_wrong_feedback!(directive_quality::Float64)

Apply negative feedback from /wrong. Nudges the weights that contributed
to the last directive quality score downward. Learning rate is stronger
(LEARNING_RATE_NEGATIVE = 0.08) — bad outcomes deserve more correction
than good outcomes deserve reinforcement.
"""
function register_wrong_feedback!(directive_quality::Float64)
    st = _state()
    lock(st.lock) do
        st.wrong_feedback_count += 1

        # GRUG: Nudge jitter-eligible weights downward
        # The higher the quality was (confident but wrong), the bigger
        # the correction needed.
        overconfidence = directive_quality  # 1.0 = very confident but wrong
        nudge = -LEARNING_RATE_NEGATIVE * overconfidence

        _nudge_weights!(st.weights, nudge)
    end
end

# ── No-arg convenience methods for CLI hooks ──────────────────────────────
# GRUG: /right and /wrong CLI commands don't have a quality value handy.
# The MLP stores last_directive_quality from the most recent transform.
# These convenience methods use that stored value so the CLI can just
# call register_right_feedback!() / register_wrong_feedback!() with no args.

"""
    register_right_feedback!()

No-arg convenience: uses the stored `last_directive_quality` from the most
recent transform. If no transform has run yet, uses a moderate positive
default (0.7) since the user explicitly said "right".
"""
function register_right_feedback!()
    st = _state()
    q = lock(st.lock) do
        st.last_directive_quality > 0.0 ? st.last_directive_quality : 0.7
    end
    register_right_feedback!(q)
end

"""
    register_wrong_feedback!()

No-arg convenience: uses the stored `last_directive_quality` from the most
recent transform. If no transform has run yet, uses a moderate confidence
default (0.5) — we don't know how confident the MLP was, so assume middle.
"""
function register_wrong_feedback!()
    st = _state()
    q = lock(st.lock) do
        st.last_directive_quality > 0.0 ? st.last_directive_quality : 0.5
    end
    register_wrong_feedback!(q)
end

"""
    _nudge_weights!(weights::MLPWeights, delta::Float64)

Internal helper: nudge all jitter-eligible weights by delta, clamped to
[WEIGHT_FLOOR, WEIGHT_CEILING]. NO NaN/Inf allowed.
"""
function _nudge_weights!(weights::MLPWeights, delta::Float64)
    if isnan(delta) || isinf(delta)
        _err("_nudge_weights! got NaN/Inf delta: $delta", "_nudge_weights!")
    end
    if delta == 0.0
        return  # nothing to nudge
    end

    for w in weights.w_input_hidden
        if w.jitter_eligible
            w.value = clamp(w.value + delta, WEIGHT_FLOOR, WEIGHT_CEILING)
        end
    end
    for w in weights.b_hidden
        if w.jitter_eligible
            w.value = clamp(w.value + delta, WEIGHT_FLOOR, WEIGHT_CEILING)
        end
    end
    for w in weights.w_hidden_output
        if w.jitter_eligible
            w.value = clamp(w.value + delta, WEIGHT_FLOOR, WEIGHT_CEILING)
        end
    end
    if weights.b_output.jitter_eligible
        weights.b_output.value = clamp(weights.b_output.value + delta, WEIGHT_FLOOR, WEIGHT_CEILING)
    end
    for w in weights.w_attention
        if w.jitter_eligible
            w.value = clamp(w.value + delta, WEIGHT_FLOOR, WEIGHT_CEILING)
        end
    end
end

# ==============================================================================
# MAIN ENTRY POINT — transform_vote_list
# ==============================================================================

"""
    transform_vote_list(vote_data::Vector{Dict{String, Any}}; hopfield_hit::Bool = false, user_input::String = "", selfobserver_count::Int = 0)::Dict{String, Any}

The primary entry point. Called after LAST_CONTRIBUTOR_VOTES is populated
but BEFORE the AIML scaffold is built. Processes the vote list through the
MLP and returns a dict with:
  - "directive_quality" : Float64  — how good the MLP thinks this vote list is
  - "activation"        : Symbol   — :sigmoid or :relu
  - "novelty_score"     : Float64  — 0.0-1.0
  - "active_rules"      : Vector{String} — IDs of rules that fired
  - "adjustments"       : Dict{String, Float64} — per-node confidence adjustments
  - "adjustments_enabled" : Bool   — whether adjustments are non-zero (SelfObserver gate)

GRUG: Prediction is power. Observation is truth. The MLP's directive quality
      is a PREDICTION. SelfObserver records what ACTUALLY happened. The MLP
      should NOT modify the vote list until SelfObserver has enough observations
      to confirm the prediction was right. This is the "rain check" — conservative
      until evidence accumulates. observation_threshold (default 5) observations
      must be recorded before adjustments become non-zero.

      The MLP also needs the ORIGINAL USER INPUT to learn input→directive
      correlations. You can't learn which questions produce good answers if
      you don't know what was asked. Different questions → different rocks →
      different quality.
"""
function transform_vote_list(vote_data::Vector{Dict{String, Any}};
                             hopfield_hit::Bool = false,
                             user_input::String = "",
                             selfobserver_count::Int = 0,
                             is_compound::Bool = false,
                             scan_mode::Int = 1,
                             phase_entries::Vector{Tuple{Float64, Vector{Float64}}} = Vector{Tuple{Float64, Vector{Float64}}}(),
                             surface_entries::Vector{Vector{Float64}} = Vector{Vector{Float64}}())::Dict{String, Any}
    st = _state()
    t_start = time()

    result = Dict{String, Any}(
        "directive_quality"  => 0.5,
        "activation"         => ACTIVATION_SIGMOID,
        "novelty_score"      => 0.5,
        "active_rules"       => String[],
        "adjustments"        => Dict{String, Float64}(),
        "adjustments_enabled"=> false,
        "phase_entries"      => Tuple{Float64, Vector{Float64}}[],
        "phase_activated"   => false,
        "phase_pull_count"  => 0,
        "phase_surface_count"=> 0
    )

    # GRUG: Empty vote list = nothing to transform. Return neutral.
    if isempty(vote_data)
        result["directive_quality"] = 0.5
        result["novelty_score"] = 0.0
        return result
    end

    lock(st.lock) do
        try
            # ── Step 0: Update SelfObserver gate ─────────────────────────
            # GRUG: Prediction is power. Observation is truth. The MLP's
            # adjustments are ZERO until SelfObserver has seen enough to
            # confirm predictions are accurate. This prevents the MLP from
            # hallucinating directives that corrupt actual vote confidence.
            st.selfobserver_observations = selfobserver_count
            if selfobserver_count >= st.observation_threshold
                st.adjustments_enabled = true
            end

            # ── Step 1: Estimate novelty ────────────────────────────────
            novelty = estimate_novelty(vote_data)

            # GRUG: Hopfield cache hit is a STRONG familiarity signal
            if hopfield_hit
                novelty = novelty * 0.3
            end

            # GRUG: If we've seen this exact user input before with good
            # EMA quality, that's ALSO a strong familiarity signal
            if !isempty(user_input)
                input_hash = hash(lowercase(strip(user_input)))
                ema = get(st.input_correlations.input_quality_ema, input_hash, nothing)
                if !isnothing(ema) && ema > 0.6
                    # GRUG: This input historically produces good directives
                    novelty = novelty * 0.5
                end
            end

            novelty = clamp(novelty, NOVELTY_FLOOR, NOVELTY_CEILING)

            # ── Step 2: Select activation ────────────────────────────────
            activation = if novelty >= NOVELTY_THRESHOLD
                ACTIVATION_RELU     # novel → explore
            else
                ACTIVATION_SIGMOID  # familiar → refine
            end

            # ── Step 3: Activate matching rules ─────────────────────────
            vote_text = String(strip(join([get(v, "action", "") for v in vote_data], " ") * " " * user_input))
            activated = activate_rules_by_pattern!(vote_text)

            # ── Step 4: Get active rules for transformer ────────────────
            active_rules = MLPTransformerRule[]
            for rid in activated
                rule = lookup_mlp_rule(rid)
                if !isnothing(rule) && rule.enabled
                    push!(active_rules, rule)
                end
            end
            # GRUG: Also include rules whose transform_type matches activation
            all_rules = list_mlp_rules()
            for rule in all_rules
                if rule.enabled && rule.transform_type == (activation == ACTIVATION_RELU ? MLP_TRANSFORM_FUZZY : MLP_TRANSFORM_SOLID)
                    if !(rule.id in activated)
                        push!(active_rules, rule)
                    end
                end
            end

            # -- Step 4.5: Phase mix selective attention -----------------------------------------
            # GRUG: Phase pull ONLY on COMPLEX inputs. Simple inputs skip.
            # The automaton's time crystal accumulates ATP phase snapshots across cycles.
            # phase_pull_query retrieves coherent snapshots from the accumulator.
            # Their 12-dim ATP distribution vectors blend into the hidden state
            # via phase_mix_hidden!, NOT through the rule pathway.
            # Phase entries are received from outside (caller passes them in kwargs).
            phase_pulled_entries = phase_entries

            phase_surface_entries = surface_entries

            phase_activated = !isempty(phase_pulled_entries) || !isempty(phase_surface_entries)
            # ── Step 5: Extract features (with user input!) ──────────────
            features = extract_vote_features(vote_data, user_input)

            # ── Step 6: MLP forward pass ─────────────────────────────────
            quality = mlp_forward(features, st.weights, activation, active_rules;
                phase_entries = phase_pulled_entries,
                surface_entries = phase_activated ? phase_surface_entries : Vector{Vector{Float64}}())

            # ── Step 7: Record input→vote correlation ───────────────────
            # GRUG: Brain needs to remember which questions produced which
            # directive quality, so it can learn the correlation over time.
            if !isempty(user_input)
                input_hash = hash(lowercase(strip(user_input)))
                vote_hash = compute_vote_list_hash(vote_data)
                entry = InputCorrelationEntry(input_hash, vote_hash, quality, time())
                push!(st.input_correlations.entries, entry)
                st.input_correlations.total_correlations += 1

                # GRUG: Update EMA quality for this input hash
                # EMA α = 0.2 — slow-moving average, conservative
                α = 0.2
                old_ema = get(st.input_correlations.input_quality_ema, input_hash, quality)
                st.input_correlations.input_quality_ema[input_hash] = old_ema * (1.0 - α) + quality * α

                # GRUG: Trim entries to bounded size
                if length(st.input_correlations.entries) > INPUT_CORRELATION_HISTORY_SIZE
                    st.input_correlations.entries = st.input_correlations.entries[end-INPUT_CORRELATION_HISTORY_SIZE+1:end]
                end
            end

            # ── Step 8: Compute per-node adjustments (SelfObserver-gated) ─
            # GRUG: Adjustments are ZERO until SelfObserver has enough
            # observations to confirm predictions. This is the "rain check."
            # Prediction tries to be right, but it's only ACTUALLY right
            # once it happens at observation time. Otherwise things hallucinate.
            adjustments = Dict{String, Float64}()
            if st.adjustments_enabled
                for v in vote_data
                    node_id = get(v, "node_id", "")
                    if isempty(node_id)
                        continue
                    end
                    base_conf = Float64(get(v, "confidence", 0.0))
                    adjustment = (quality - 0.5) * 0.02 * base_conf  # TINY: max ±0.01
                    adjustments[node_id] = adjustment
                end
            end

            # ── Step 9: Update state ─────────────────────────────────────
            st.last_activation = activation
            st.last_novelty_score = novelty
            st.last_transform_time = time()
            st.last_user_input = user_input
            st.total_transforms += 1
            if activation == ACTIVATION_SIGMOID
                st.total_sigmoid_activations += 1
            else
                st.total_relu_activations += 1
            end
            st.last_directive_quality = quality

            # GRUG v7.50: Compute hippocampal strain — the self-observer's felt deficit.
            # High novelty + low directive_quality = the system can't handle what it's seeing.
            # That's STRAIN. It flows to MitosisMode as a growth signal.
            # Homeostatic loop: strain → mitosis → growth → structure improves → strain decreases.
            quality_deficit = 1.0 - quality   # low quality = high deficit
            strain = clamp(
                STRAIN_NOVELTY_WEIGHT * novelty + STRAIN_QUALITY_WEIGHT * quality_deficit,
                STRAIN_FLOOR, STRAIN_CEILING
            )
            st.strain_energy = strain
            # Hippocampal warrant fires when strain is high AND SelfObserver has
            # confirmed enough observations to trust the signal. Without confirmation,
            # strain might just be noise. The warrant is the bridge: "I hurt AND I'm
            # confident the hurt is real" → warrant for growth.
            st.hippocampal_warrant_active = strain >= STRAIN_THRESHOLD && st.adjustments_enabled

            # ── Step 10: Build result ────────────────────────────────────
            result["directive_quality"]   = quality
            result["activation"]          = activation
            result["novelty_score"]       = novelty
            result["active_rules"]        = activated
            result["adjustments"]         = adjustments
            result["adjustments_enabled"] = st.adjustments_enabled
            result["phase_entries"]      = phase_pulled_entries
            result["phase_activated"]    = phase_activated
            result["phase_pull_count"]   = length(phase_pulled_entries)
            result["phase_surface_count"] = length(phase_surface_entries)
            result["strain_energy"]            = strain
            result["hippocampal_warrant_active"] = st.hippocampal_warrant_active

        catch e
            # GRUG: NO SILENT FAILURE — log the error and return neutral result
            @error "[EphemeralMLP] transform_vote_list FAILED: $e"
            result["directive_quality"] = 0.5
            result["error"] = string(e)
        end
    end

    return result
end

# ==============================================================================
# STATUS & QUERIES
# ==============================================================================

"""
    get_mlp_status()::Dict{String, Any}

Return a comprehensive status snapshot of the EphemeralMLP module.
Safe to call at any time — acquires lock, copies values, releases lock.
"""
function get_mlp_status()::Dict{String, Any}
    st = _state()
    lock(st.lock) do
        n_rules = length(st.rules.rules)
        n_enabled = count(r -> r.enabled, values(st.rules.rules))
        n_jitter = count(w -> w.jitter_eligible, st.weights.w_input_hidden) +
                   count(w -> w.jitter_eligible, st.weights.b_hidden) +
                   count(w -> w.jitter_eligible, st.weights.w_hidden_output) +
                   (st.weights.b_output.jitter_eligible ? 1 : 0) +
                   count(w -> w.jitter_eligible, st.weights.w_attention)

        return Dict{String, Any}(
            "total_transforms"       => st.total_transforms,
            "sigmoid_activations"    => st.total_sigmoid_activations,
            "relu_activations"       => st.total_relu_activations,
            "last_activation"        => String(st.last_activation),
            "last_novelty_score"     => round(st.last_novelty_score; digits=4),
            "last_directive_quality" => round(st.last_directive_quality; digits=4),
            "right_feedback_count"   => st.right_feedback_count,
            "wrong_feedback_count"   => st.wrong_feedback_count,
            "rules_total"            => n_rules,
            "rules_enabled"          => n_enabled,
            "jitter_eligible_weights"=> n_jitter,
            "jitter_enabled"         => JITTER_ENABLED_REF[],
            "novelty_observations"   => st.novelty_tracker.total_observations,
            "novelty_hashes_tracked" => length(st.novelty_tracker.hash_counts),
            "novelty_history_len"    => length(st.novelty_tracker.history),
            "selfobserver_observations" => st.selfobserver_observations,
            "observation_threshold"  => st.observation_threshold,
            "adjustments_enabled"   => st.adjustments_enabled,
            "input_correlations"    => st.input_correlations.total_correlations,
            "last_user_input"       => st.last_user_input,
            "strain_energy"         => round(st.strain_energy; digits=4),
            "hippocampal_warrant"   => st.hippocampal_warrant_active
        )
    end
end

"""
    get_activation_mode()::Symbol

Return the last activation mode used (:sigmoid or :relu).
"""
function get_activation_mode()::Symbol
    st = _state()
    lock(st.lock) do
        return st.last_activation
    end
end

"""
    get_novelty_score()::Float64

Return the last novelty score (0.0-1.0).
"""
function get_novelty_score()::Float64
    st = _state()
    lock(st.lock) do
        return st.last_novelty_score
    end
end

# ==============================================================================
# HIPPOCAMPAL STRAIN QUERIES — GRUG v7.50
# ==============================================================================

"""
    get_strain_energy()::Float64

Return the last hippocampal strain energy (0.0-1.0). High strain means
the system encountered novel input it couldn't handle well. This signal
flows to MitosisMode as an internal growth driver — not just external
data_energy, but felt internal deficit.

GRUG: The self-observer's hurt. When this is high, the system needs to grow.
"""
function get_strain_energy()::Float64
    st = _state()
    lock(st.lock) do
        return st.strain_energy
    end
end

"""
    is_hippocampal_warrant_active()::Bool

Return whether the hippocampal warrant is active. True when strain_energy
is above STRAIN_THRESHOLD AND SelfObserver has confirmed enough observations
to trust the signal. This is the 6th warrant source for MitosisMode.

GRUG: "I hurt AND I'm confident the hurt is real" → warrant for growth.
"""
function is_hippocampal_warrant_active()::Bool
    st = _state()
    lock(st.lock) do
        return st.hippocampal_warrant_active
    end
end

"""
    dampen_strain!(factor::Float64=0.5)

GRUG v7.51: Reduce strain energy by a dampening factor. Called when the user
provides an /answer or /antiAnswer — resolving the structural deficit that
caused the strain. The factor multiplies the current strain (0.5 = halve it).
Also re-evaluates hippocampal_warrant_active since strain may now be below threshold.

This is the "resolve" step in the hippocampal cycle:
  strain → ask question → user answers → dampen strain → strain resolved
"""
function dampen_strain!(factor::Float64=0.5)
    if factor < 0.0 || factor > 1.0
        error("!!! FATAL: dampen_strain! factor must be in [0.0, 1.0], got $factor !!!")
    end
    st = _state()
    lock(st.lock) do
        old_strain = st.strain_energy
        st.strain_energy = clamp(old_strain * (1.0 - factor), STRAIN_FLOOR, STRAIN_CEILING)
        # Re-evaluate warrant: if strain dropped below threshold, warrant deactivates.
        st.hippocampal_warrant_active = st.strain_energy >= STRAIN_THRESHOLD && st.adjustments_enabled
        return (old=old_strain, new=st.strain_energy)
    end
end

# ==============================================================================
# OBSERVATION THRESHOLD — user-editable gate for MLP adjustments
# ==============================================================================

"""
    set_observation_threshold!(n::Int)

Set the minimum number of SelfObserver entries required before MLP adjustments
become non-zero. Default is 5. Setting to 0 means adjustments are always enabled.

GRUG: The brain doesn't guess until it has seen enough. But sometimes Grug
      wants the brain to start guessing sooner, or later. This is that knob.
"""
function set_observation_threshold!(n::Int)
    if n < 0
        _err("set_observation_threshold! requires n >= 0, got $n", "set_observation_threshold!")
    end
    st = _state()
    lock(st.lock) do
        old = st.observation_threshold
        st.observation_threshold = n
        # GRUG: If threshold just dropped below current observations, enable adjustments immediately
        if st.selfobserver_observations >= n && n > 0
            st.adjustments_enabled = true
        elseif n == 0
            st.adjustments_enabled = true
        end
        @info "[EphemeralMLP] observation_threshold changed: $old → $n (adjustments_enabled=$(st.adjustments_enabled))"
    end
    return n
end

"""
    get_observation_threshold()::Int

Return the current observation threshold. MLP adjustments are zero until
SelfObserver has at least this many entries.
"""
function get_observation_threshold()::Int
    st = _state()
    lock(st.lock) do
        return st.observation_threshold
    end
end

# ==============================================================================
# SERIALIZATION — standalone JSON for specimen file
# ==============================================================================

"""
    to_specimen_dict()::Dict{String, Any}

Serialize the EphemeralMLP state to a standalone JSON-compatible dict.
This goes under the "ephemeral_mlp" key in the specimen file. Every field
is explicitly typed — no ambiguous values. Version stamped for forward compat.

GRUG: Save everything. The brain remembers. When Grug wakes up in a new cave,
      Grug should recognize the old dream.
"""
function to_specimen_dict()::Dict{String, Any}
    st = _state()
    lock(st.lock) do
        # ── Weights ─────────────────────────────────────────────────────
        serialize_weights(ws::Vector{MLPWeight}) = Dict{String, Any}[
            Dict{String, Any}(
                "value"           => round(w.value; digits=6),
                "jitter_eligible" => w.jitter_eligible,
                "last_wobble"     => round(w.last_wobble; digits=6)
            ) for w in ws
        ]

        weights_dict = Dict{String, Any}(
            "w_input_hidden"  => serialize_weights(st.weights.w_input_hidden),
            "b_hidden"        => serialize_weights(st.weights.b_hidden),
            "w_hidden_output" => serialize_weights(st.weights.w_hidden_output),
            "b_output"        => Dict{String, Any}(
                "value"           => round(st.weights.b_output.value; digits=6),
                "jitter_eligible" => st.weights.b_output.jitter_eligible,
                "last_wobble"     => round(st.weights.b_output.last_wobble; digits=6)
            ),
            "w_attention"     => serialize_weights(st.weights.w_attention)
        )

        # ── Rules ───────────────────────────────────────────────────────
        rules_list = Dict{String, Any}[]
        for (rid, rule) in st.rules.rules
            push!(rules_list, Dict{String, Any}(
                "id"            => rule.id,
                "pattern"       => rule.pattern,
                "key"           => rule.key,
                "weight"        => Dict{String, Any}(
                    "value"           => round(rule.weight.value; digits=6),
                    "jitter_eligible" => rule.weight.jitter_eligible
                ),
                "transform_type"=> String(rule.transform_type),
                "payload"       => rule.payload,
                "drop_table"    => rule.drop_table,
                "fire_count"    => rule.fire_count,
                "last_fire_time"=> round(rule.last_fire_time; digits=3),
                "enabled"       => rule.enabled
            ))
        end

        # ── Novelty tracker ─────────────────────────────────────────────
        hash_counts_list = Dict{String, Any}[]
        for (h, c) in st.novelty_tracker.hash_counts
            push!(hash_counts_list, Dict{String, Any}(
                "hash"  => string(h),
                "count" => c
            ))
        end

        novelty_dict = Dict{String, Any}(
            "history"           => [round(v; digits=4) for v in st.novelty_tracker.history],
            "hash_counts"       => hash_counts_list,
            "total_observations"=> st.novelty_tracker.total_observations
        )

        # ── Input correlation tracker ────────────────────────────────────────
        # GRUG: Brain remembers which questions led to which answers. On reload,
        # it should know the same correlations it learned before.
        ic_entries_list = Dict{String, Any}[]
        for entry in st.input_correlations.entries
            push!(ic_entries_list, Dict{String, Any}(
                "input_hash"        => string(entry.input_hash),
                "vote_hash"         => string(entry.vote_hash),
                "directive_quality" => round(entry.directive_quality; digits=4),
                "timestamp"         => round(entry.timestamp; digits=3)
            ))
        end

        ic_ema_list = Dict{String, Any}[]
        for (h, q) in st.input_correlations.input_quality_ema
            push!(ic_ema_list, Dict{String, Any}(
                "hash"       => string(h),
                "ema_quality" => round(q; digits=6)
            ))
        end

        input_corr_dict = Dict{String, Any}(
            "entries"            => ic_entries_list,
            "input_quality_ema"  => ic_ema_list,
            "total_correlations" => st.input_correlations.total_correlations
        )
        # -- Top-level state ---------------------------------------------------
        return Dict{String, Any}(
            "_meta" => Dict{String, Any}(
                "version"   => "1.5",
                "format"    => "ephemeral-mlp-v1.5",
                "saved_at"  => time()
            ),
            "weights"                   => weights_dict,
            "rules"                     => rules_list,
            "novelty_tracker"           => novelty_dict,
            "input_correlations"        => input_corr_dict,
            "last_activation"           => String(st.last_activation),
            "last_novelty_score"        => round(st.last_novelty_score; digits=4),
            "last_directive_quality"    => round(st.last_directive_quality; digits=4),
            "last_user_input"           => st.last_user_input,
            "total_transforms"          => st.total_transforms,
            "total_sigmoid_activations" => st.total_sigmoid_activations,
            "total_relu_activations"    => st.total_relu_activations,
            "right_feedback_count"      => st.right_feedback_count,
            "wrong_feedback_count"      => st.wrong_feedback_count,
            "selfobserver_observations" => st.selfobserver_observations,
            "observation_threshold"      => st.observation_threshold,
            "adjustments_enabled"       => st.adjustments_enabled,
            "strain_energy"             => round(st.strain_energy; digits=4),
            "hippocampal_warrant_active" => st.hippocampal_warrant_active,
            # GRUG v7.50: Strain constants for drift detection on reload.
            # These are compile-time constants but they govern specimen personality
            # (how readily the hippocampal warrant fires). If code defaults change
            # between sessions, the operator should know.
            "strain_novelty_weight"     => STRAIN_NOVELTY_WEIGHT,
            "strain_quality_weight"     => STRAIN_QUALITY_WEIGHT,
            "strain_threshold"          => STRAIN_THRESHOLD
        )
    end
end

"""
    from_specimen_dict!(data::Dict{String, Any})

Restore the EphemeralMLP state from a specimen dict. This is a DESTRUCTIVE
operation — current state is replaced. Validates all inputs before modifying
any state. NO silent failures — if anything is wrong, this throws and NO
CHANGES ARE MADE.
"""
function from_specimen_dict!(data::Dict{String, Any})
    if isempty(data)
        _err("from_specimen_dict! got empty dict", "from_specimen_dict!")
    end

    # GRUG: Validate structure before touching anything
    if !haskey(data, "weights")
        _err("from_specimen_dict! missing 'weights' key", "from_specimen_dict!")
    end

    # ── Parse weights ───────────────────────────────────────────────────
    function parse_weights(ws_list::AbstractVector)::Vector{MLPWeight}
        weights = MLPWeight[]
        for w_data in ws_list
            if !isa(w_data, Dict)
                _err("from_specimen_dict! weight entry is not a dict", "parse_weights")
            end
            val = Float64(get(w_data, "value", 0.0))
            jitter = Bool(get(w_data, "jitter_eligible", false))
            push!(weights, MLPWeight(clamp(val, WEIGHT_FLOOR, WEIGHT_CEILING); jitter_eligible = jitter))
        end
        return weights
    end

    wd = data["weights"]
    new_weights = MLPWeights()
    try
        if haskey(wd, "w_input_hidden") && isa(wd["w_input_hidden"], AbstractVector)
            new_weights.w_input_hidden = parse_weights(wd["w_input_hidden"])
        end
        if haskey(wd, "b_hidden") && isa(wd["b_hidden"], AbstractVector)
            new_weights.b_hidden = parse_weights(wd["b_hidden"])
        end
        if haskey(wd, "w_hidden_output") && isa(wd["w_hidden_output"], AbstractVector)
            new_weights.w_hidden_output = parse_weights(wd["w_hidden_output"])
        end
        if haskey(wd, "b_output") && isa(wd["b_output"], Dict)
            b_out = wd["b_output"]
            val = Float64(get(b_out, "value", 0.0))
            jitter = Bool(get(b_out, "jitter_eligible", false))
            new_weights.b_output = MLPWeight(clamp(val, WEIGHT_FLOOR, WEIGHT_CEILING); jitter_eligible = jitter)
        end
        if haskey(wd, "w_attention") && isa(wd["w_attention"], AbstractVector)
            new_weights.w_attention = parse_weights(wd["w_attention"])
        end
    catch e
        _err("from_specimen_dict! failed to parse weights: $e", "from_specimen_dict!")
    end

    # ── Parse rules ─────────────────────────────────────────────────────
    new_rules = RuleHashTable()
    if haskey(data, "rules") && isa(data["rules"], AbstractVector)
        for r_data in data["rules"]
            try
                if !isa(r_data, Dict)
                    @warn "[EphemeralMLP] Skipping non-dict rule entry"
                    continue
                end
                rule_id = String(get(r_data, "id", ""))
                pattern = String(get(r_data, "pattern", ""))
                key = String(get(r_data, "key", ""))
                transform_type = Symbol(String(get(r_data, "transform_type", "fuzzy")))

                # GRUG: Validate rule — throw on bad data
                if isempty(rule_id)
                    @warn "[EphemeralMLP] Skipping rule with empty ID"
                    continue
                end

                weight_data = get(r_data, "weight", Dict{String, Any}("value" => 1.0, "jitter_eligible" => true))
                weight_val = Float64(get(weight_data, "value", 1.0))
                weight_jitter = Bool(get(weight_data, "jitter_eligible", true))

                payload = Dict{String, Any}(get(r_data, "payload", Dict{String, Any}()))
                drop_tbl = String[String(x) for x in get(r_data, "drop_table", String[])]
                fire_count = Int(get(r_data, "fire_count", 0))
                last_fire = Float64(get(r_data, "last_fire_time", 0.0))
                enabled = Bool(get(r_data, "enabled", true))

                # GRUG: Validate pattern compiles
                try
                    Regex(pattern)
                catch e
                    @warn "[EphemeralMLP] Skipping rule '$rule_id' with bad pattern: $e"
                    continue
                end

                rule = MLPTransformerRule(
                    rule_id, pattern;
                    key = key,
                    weight_value = clamp(weight_val, WEIGHT_FLOOR, WEIGHT_CEILING),
                    weight_jitter = weight_jitter,
                    transform_type = transform_type ∈ (MLP_TRANSFORM_FUZZY, MLP_TRANSFORM_SOLID) ? transform_type : MLP_TRANSFORM_FUZZY,
                    payload = payload,
                    drop_table = drop_tbl
                )
                rule.fire_count = fire_count
                rule.last_fire_time = last_fire
                rule.enabled = enabled

                new_rules.rules[rule_id] = rule
                if !isempty(key)
                    if !haskey(new_rules.key_index, key)
                        new_rules.key_index[key] = String[]
                    end
                    push!(new_rules.key_index[key], rule_id)
                end
            catch e
                @warn "[EphemeralMLP] Skipping bad rule entry: $e"
            end
        end
    end

    # ── Parse novelty tracker ───────────────────────────────────────────
    new_novelty = NoveltyTracker()
    if haskey(data, "novelty_tracker") && isa(data["novelty_tracker"], Dict)
        nt = data["novelty_tracker"]
        if haskey(nt, "history") && isa(nt["history"], AbstractVector)
            new_novelty.history = Float64[clamp(Float64(v), NOVELTY_FLOOR, NOVELTY_CEILING)
                                          for v in nt["history"]]
            # GRUG: Trim to bounded size
            if length(new_novelty.history) > NOVELTY_HISTORY_SIZE
                new_novelty.history = new_novelty.history[end-NOVELTY_HISTORY_SIZE+1:end]
            end
        end
        if haskey(nt, "hash_counts") && isa(nt["hash_counts"], AbstractVector)
            for hc in nt["hash_counts"]
                try
                    h = parse(UInt64, String(get(hc, "hash", "0")))
                    c = Int(get(hc, "count", 0))
                    new_novelty.hash_counts[h] = c
                catch e
                    @warn "[EphemeralMLP] Skipping bad hash_count entry: $e"
                end
            end
        end
        new_novelty.total_observations = Int(get(nt, "total_observations", 0))
    end

    # ── Parse input correlation tracker ──────────────────────────────────
    # GRUG: Reload the brain's memory of which questions led to which answers.
    # If the key is missing (old specimen), start with a blank tracker.
    new_input_corr = InputCorrelationTracker()
    if haskey(data, "input_correlations") && isa(data["input_correlations"], Dict)
        ic = data["input_correlations"]
        if haskey(ic, "entries") && isa(ic["entries"], AbstractVector)
            for entry_data in ic["entries"]
                try
                    if !isa(entry_data, Dict)
                        continue
                    end
                    ih = parse(UInt64, String(get(entry_data, "input_hash", "0")))
                    vh = parse(UInt64, String(get(entry_data, "vote_hash", "0")))
                    dq = clamp(Float64(get(entry_data, "directive_quality", 0.5)), 0.0, 1.0)
                    ts = Float64(get(entry_data, "timestamp", 0.0))
                    push!(new_input_corr.entries, InputCorrelationEntry(ih, vh, dq, ts))
                catch e
                    @warn "[EphemeralMLP] Skipping bad input_correlation entry: $e"
                end
            end
            # GRUG: Trim to bounded size
            if length(new_input_corr.entries) > INPUT_CORRELATION_HISTORY_SIZE
                new_input_corr.entries = new_input_corr.entries[end-INPUT_CORRELATION_HISTORY_SIZE+1:end]
            end
        end
        if haskey(ic, "input_quality_ema") && isa(ic["input_quality_ema"], AbstractVector)
            for ema_data in ic["input_quality_ema"]
                try
                    if !isa(ema_data, Dict)
                        continue
                    end
                    h = parse(UInt64, String(get(ema_data, "hash", "0")))
                    q = clamp(Float64(get(ema_data, "ema_quality", 0.5)), 0.0, 1.0)
                    new_input_corr.input_quality_ema[h] = q
                catch e
                    @warn "[EphemeralMLP] Skipping bad input_quality_ema entry: $e"
                end
            end
        end
        new_input_corr.total_correlations = Int(get(ic, "total_correlations", 0))
    end


    # ── Apply all parsed state ──────────────────────────────────────────
    st = _state()
    lock(st.lock) do
        st.weights = new_weights
        st.rules = new_rules
        st.novelty_tracker = new_novelty
        st.input_correlations = new_input_corr
        st.last_activation = Symbol(String(get(data, "last_activation", "sigmoid")))
        st.last_novelty_score = clamp(Float64(get(data, "last_novelty_score", 0.5)), NOVELTY_FLOOR, NOVELTY_CEILING)
        st.last_directive_quality = clamp(Float64(get(data, "last_directive_quality", 0.5)), 0.0, 1.0)
        st.last_user_input = String(get(data, "last_user_input", ""))
        st.total_transforms = Int(get(data, "total_transforms", 0))
        st.total_sigmoid_activations = Int(get(data, "total_sigmoid_activations", 0))
        st.total_relu_activations = Int(get(data, "total_relu_activations", 0))
        st.right_feedback_count = Int(get(data, "right_feedback_count", 0))
        st.wrong_feedback_count = Int(get(data, "wrong_feedback_count", 0))
        st.selfobserver_observations = Int(get(data, "selfobserver_observations", 0))
        st.observation_threshold = max(0, Int(get(data, "observation_threshold", 5)))
        st.adjustments_enabled = Bool(get(data, "adjustments_enabled", false))
        st.strain_energy = clamp(Float64(get(data, "strain_energy", 0.0)), STRAIN_FLOOR, STRAIN_CEILING)
        st.hippocampal_warrant_active = Bool(get(data, "hippocampal_warrant_active", false))

        # GRUG v7.50: Drift-check strain constants so reload personality
        # doesn't silently shift if code defaults changed.
        _strain_drift = 0
        if Float64(get(data, "strain_novelty_weight", STRAIN_NOVELTY_WEIGHT)) != STRAIN_NOVELTY_WEIGHT; _strain_drift += 1; end
        if Float64(get(data, "strain_quality_weight", STRAIN_QUALITY_WEIGHT)) != STRAIN_QUALITY_WEIGHT; _strain_drift += 1; end
        if Float64(get(data, "strain_threshold", STRAIN_THRESHOLD)) != STRAIN_THRESHOLD; _strain_drift += 1; end
        if _strain_drift > 0
            println("  🧠 EphemeralMLP: $_strain_drift strain-constant drift(s) from code defaults")
        end

    end
end


end # module EphemeralMLP