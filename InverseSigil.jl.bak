# ==============================================================================
# InverseSigil.jl — Growth Magnet: Reverse Sigil Index + Shape-Cluster Density
# ==============================================================================
# GRUG say: sigils are shapes. Shapes have CONCRETES under them. &n → [2, 7, 42].
# &noun → ["cat", "dog"]. The INVERSE SIGIL LIST is the reverse index from shape
# to concretes. It acts as a MAGNET: more concretes under a sigil shape = stronger
# pull toward growth. Shape-cluster density is a genuinely new signal that the
# existing 18 evidence sources don't produce.
#
# WHY THIS MATTERS:
#   The silence_map (SOURCE 1 in AutoGrowth) sees uncovered tokens as UNRELATED
#   atoms. "cat" is a gap. "dog" is a gap. But if BOTH are concretes under &noun,
#   they're not unrelated — they're the SAME gap with TWO observations. The magnet
#   clusters them by shape, so two observations of &noun concretes produce a
#   stronger growth signal than two unrelated atoms.
#
# TWO MAGNET MODES:
#   1. LINEAR (token inverse) — for :macro sigils like &noun where every concrete
#      matters equally. 5 concretes under &noun = 5x signal. Simple.
#
#   2. PSEUDONONLINEAR (functorial inverse) — for :lambda sigils like &n where
#      raw concretes are noisy (any digit is a concrete for &n). Uses a curve:
#      dead zone (ignore noise below floor) → linear ramp (genuine growth) → cap
#      (bounded at top, no runaway). User-added concretes BYPASS the dead zone.
#
# GROWTH ROUTING:
#   The magnet doesn't just produce a signal — it routes the growth to the right
#   target. Three node types and petty growth:
#
#   NODE TARGETS:
#     - AIML nodes: executive templates, per-lobe tribes, 1/3 population cap.
#       Grown when shape-cluster density is HIGH and the sigil class is :relation
#       or the pattern suggests executive/reasoning behavior.
#     - Sigil voter nodes: node_type=:sigil, NOCHAT, singleton, never in growth
#       groups. Grown when the shape itself needs a dedicated voter (e.g. a new
#       &relation sigil that needs a procedural node to represent it).
#     - Regular voter nodes: node_type=:voter, grows in groups, eligible for
#       idle chatter. Default growth target.
#
#   PETTY TARGETS (no node grown):
#     - Thesaurus pair: synonym discovered via shape clustering
#     - Sigil lexicon entry: new concrete added to &noun or other :macro lexicon
#     - Verb registration: new verb mapped to a :relation sigil expansion
#     - Governance data: side data like lobe whitelist entries
#
# USER-ADDABLE CONCRETES:
#   If the user explicitly says "quantum is a &noun", that's a DIRECTIVE, not
#   noise. It counts immediately, no dead zone. User_directives bypass damping.
#
# ARCHITECTURE:
#   InverseEntry — per sigil, holds concrete list, magnet mode, density, directives
#   InverseSigilTable — Dict{String, InverseEntry}, thread-safe via ReentrantLock
#   magnet_strength(sigil_name) — compute pull strength for growth signal
#   route_growth(sigil_name, density) — decide growth target (node vs petty)
#   add_concrete!(sigil_name, token; user_directive) — add a concrete to the index
#   feed_evidence!(...) — SOURCE 19 integration with AutoGrowth accumulator
#
# ==============================================================================

module InverseSigil

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.         ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.     ║
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

# GRUG: Bring in sibling module SigilRegistry for sigil class lookups.
# InverseSigil is a submodule of Main and cannot see sibling modules without this.
using ..SigilRegistry

# ==============================================================================
# CONSTANTS — Magnet Tuning
# ==============================================================================

# ── LINEAR MODE (token inverse: &noun, :macro class) ──────────────────────────
# Every concrete under a :macro sigil counts equally. No damping.
# 5 concretes under &noun = 5 * LINEAR_WEIGHT signal. Simple.
const LINEAR_WEIGHT = 1.0        # per-concrete contribution to magnet strength
const LINEAR_FLOOR  = 1          # minimum concretes to produce ANY signal
                             # (0 concretes = no magnet, 1+ = linear scaling)

# ── PSEUDONONLINEAR MODE (functorial inverse: &n, :lambda class) ─────────────
# Dead zone below floor (noise), linear ramp in growth zone, hard cap at top.
# User-added concretes bypass the dead zone entirely.
const PSEUDO_DEAD_ZONE_FLOOR = 3.0    # concretes below this = noise, no signal
const PSEUDO_RAMP_SLOPE      = 0.25   # signal per concrete above floor
const PSEUDO_SIGNAL_CAP      = 5.0    # maximum magnet strength (bounded)
const PSEUDO_USER_DIRECTIVE_BONUS = 1.0  # each user-directive concrete adds this
                                          # on top of normal contribution, bypassing dead zone

# ── GROWTH ROUTING THRESHOLDS ────────────────────────────────────────────────
# When magnet strength exceeds these thresholds, different growth targets activate.
# Lower threshold = petty growth (cheap, no node). Higher = node growth (expensive).
const ROUTE_PETTY_THRESHOLD   = 2.0   # magnet strength >= this → petty growth eligible
const ROUTE_NODE_THRESHOLD    = 4.0   # magnet strength >= this → node growth eligible
const ROUTE_AIML_THRESHOLD    = 6.0   # magnet strength >= this → AIML node eligible

# ── PETTY GROWTH TYPE ROUTING ────────────────────────────────────────────────
# Within petty growth, which kind of petty? Based on sigil class.
# :macro → sigil lexicon entry (add concrete to &noun lexicon)
# :relation → verb registration (add verb to &causal expansion)
# :lambda with similar tokens → thesaurus pair
# default → governance data (lobe whitelist entry, etc.)
const PETTY_SIGIL_LEXICON_SIMILARITY_FLOOR = 0.3  # for thesaurus petty from shape cluster

# ── EVIDENCE INTEGRATION ──────────────────────────────────────────────────────
# How much magnet strength boosts evidence intensity in AutoGrowth SOURCE 19.
const MAGNET_EVIDENCE_MULTIPLIER = 0.4  # magnet_strength * this = evidence intensity bonus
const MAGNET_EVIDENCE_SOURCE_TAG = "inverse_sigil_magnet"  # source tag for _add_evidence!

# ── DECAY ─────────────────────────────────────────────────────────────────────
# Concretes decay if not re-observed. Same philosophy as AutoGrowth evidence decay.
# A concrete seen once and never again should eventually stop pulling.
const CONCRETE_DECAY_HALFLIFE = 7200.0   # seconds (2 hours — slower than evidence decay)
const CONCRETE_DECAY_INTERVAL = 120.0     # seconds between decay sweeps
const CONCRETE_NOISE_FLOOR    = 0.1       # concretes below this weight are evicted

# ── CAPS ──────────────────────────────────────────────────────────────────────
const MAX_CONCRETES_PER_SIGIL = 200  # bounded — no runaway growth
const MAX_INVERSE_ENTRIES     = 100  # bounded — no unbounded sigil tracking

# ==============================================================================
# DATA STRUCTURES
# ==============================================================================

"""
    ConcreteEntry

A single concrete token observed under a sigil shape. Tracks how many times
it was observed and whether it was a user directive (bypasses damping).

Fields:
  - token::String — the concrete token (e.g. "cat" under &noun, "7" under &n)
  - observation_count::Int — how many times this concrete was observed
  - accumulated_weight::Float64 — decaying weight (like evidence intensity)
  - is_user_directive::Bool — user explicitly added this; bypasses dead zone
  - first_seen::Float64 — unix timestamp
  - last_seen::Float64 — unix timestamp
"""
mutable struct ConcreteEntry
    token::String
    observation_count::Int
    accumulated_weight::Float64
    is_user_directive::Bool
    first_seen::Float64
    last_seen::Float64
end

function ConcreteEntry(token::String; is_user_directive::Bool = false)
    t = time()
    ConcreteEntry(token, 1, 1.0, is_user_directive, t, t)
end

"""
    MagnetMode

Determines how magnet strength is calculated for a sigil's inverse entry.

  - :linear — every concrete counts equally. Used for :macro sigils (&noun)
    where each concrete is a meaningful token.
  - :pseudononlinear — dead zone + ramp + cap. Used for :lambda sigils (&n)
    where raw concretes are noisy (any digit qualifies).
"""
@enum MagnetMode begin
    LINEAR
    PSEUDONONLINEAR
end

"""
    PettyGrowthType

The kind of petty growth to dispatch when magnet strength is in the petty zone.
Determined by sigil class and concrete characteristics.

  - :sigil_lexicon — add concrete to :macro sigil lexicon (e.g. "cat" → &noun)
  - :verb_registration — add verb to :relation sigil expansion (e.g. "produces" → &causal)
  - :thesaurus_pair — register synonym pair from shape-cluster similarity
  - :governance_data — side data: lobe whitelist, sigil params, etc.
"""
@enum PettyGrowthType begin
    SIGIL_LEXICON
    VERB_REGISTRATION
    THESAURUS_PAIR
    GOVERNANCE_DATA
end

"""
    InverseEntry

One sigil's reverse index entry. Holds all concretes observed under this shape,
their cumulative weights, magnet mode, and routing decisions.

Fields:
  - sigil_name::String — the sigil name (no & prefix), e.g. "noun", "n"
  - magnet_mode::MagnetMode — :linear or :pseudononlinear
  - concretes::Dict{String, ConcreteEntry} — token → entry
  - cluster_density::Float64 — cached magnet strength (updated on each add)
  - last_routed_growth_type::Symbol — what growth type was last routed
  - total_observations::Int — sum of all concrete observation_counts
  - user_directive_count::Int — how many concretes are user directives
"""
mutable struct InverseEntry
    sigil_name::String
    magnet_mode::MagnetMode
    concretes::Dict{String, ConcreteEntry}
    cluster_density::Float64
    last_routed_growth_type::Symbol
    total_observations::Int
    user_directive_count::Int
    lobe_hint::String                 # GRUG v8.2: lobe to grow in — from "science: answer" prefix
end

function InverseEntry(sigil_name::String, magnet_mode::MagnetMode;
                      lobe_hint::String = "")
    InverseEntry(sigil_name, magnet_mode, Dict{String, ConcreteEntry}(),
                 0.0, :none, 0, 0, lobe_hint)
end

"""
    GrowthRoute

The result of routing a magnet signal to a growth target. Carries all the
information needed by AutoGrowth or PettyLearner to dispatch the growth.

Fields:
  - target::Symbol — :aiml_node, :sigil_voter_node, :voter_node, or :petty
  - petty_type::PettyGrowthType — only when target == :petty
  - sigil_name::String — which sigil triggered this route
  - magnet_strength::Float64 — the computed magnet strength
  - concretes::Vector{String} — the concrete tokens under this sigil
  - user_directives::Vector{String} — concretes added by user directive
  - evidence_bonus::Float64 — how much to boost AutoGrowth evidence intensity
  - notes::String — human-readable description of the routing decision
"""
struct GrowthRoute
    target::Symbol                   # :aiml_node, :sigil_voter_node, :voter_node, :petty
    petty_type::PettyGrowthType      # only meaningful when target == :petty
    sigil_name::String
    magnet_strength::Float64
    concretes::Vector{String}
    user_directives::Vector{String}
    evidence_bonus::Float64
    lobe_hint::String                # GRUG v8.2: lobe to grow in — from "science: answer" prefix or inference
    notes::String
end

# ==============================================================================
# TABLE — reverse index + lock
# ==============================================================================

const _INVERSE_TABLE = Dict{String, InverseEntry}()  # sigil_name → InverseEntry
const _INVERSE_LOCK = ReentrantLock()
const _LAST_DECAY = Ref{Float64}(time())

# ==============================================================================
# MAGNET STRENGTH CALCULATION
# ==============================================================================

"""
    magnet_strength(entry::InverseEntry) -> Float64

Compute the magnet strength for an inverse entry. This is the core signal
that drives growth routing. The calculation depends on magnet_mode:

  LINEAR: every concrete counts equally.
    strength = count(concretes with weight > 0) * LINEAR_WEIGHT
    Below LINEAR_FLOOR concretes = 0 (no signal from noise).

  PSEUDONONLINEAR: dead zone + ramp + cap.
    - Observed concretes contribute based on accumulated_weight.
    - User directives bypass the dead zone and add PSEUDO_USER_DIRECTIVE_BONUS.
    - Dead zone: concretes with weight > 0 but total < PSEUDO_DEAD_ZONE_FLOOR = 0 signal.
    - Ramp: (total_observed_weight - PSEUDO_DEAD_ZONE_FLOOR) * PSEUDO_RAMP_SLOPE.
    - Cap: min(ramp_result + user_bonus, PSEUDO_SIGNAL_CAP).

Returns a Float64 >= 0.0 representing the magnet pull strength.
"""
function magnet_strength(entry::InverseEntry)::Float64
    if isempty(entry.concretes)
        return 0.0
    end

    if entry.magnet_mode == LINEAR
        # ── LINEAR MODE: every concrete counts equally ────────────────────────
        # Count concretes with non-trivial weight (above noise floor).
        active_count = count(e -> e.accumulated_weight > CONCRETE_NOISE_FLOOR,
                             values(entry.concretes))
        if active_count < LINEAR_FLOOR
            return 0.0  # Not enough concretes for a signal
        end
        return Float64(active_count) * LINEAR_WEIGHT

    else
        # ── PSEUDONONLINEAR MODE: dead zone + ramp + cap ─────────────────────
        # Separate user directives (bypass dead zone) from observed concretes.
        # GRUG: values() returns ValueIterator — not filterable directly.
        # Collect to Vector first, then filter.
        _all_concretes = collect(values(entry.concretes))
        user_concretes = filter(e -> e.is_user_directive, _all_concretes)
        auto_concretes = filter(e -> !e.is_user_directive, _all_concretes)

        # Auto-observed concretes: sum weights, apply dead zone.
        auto_weight = sum(e -> e.accumulated_weight, auto_concretes; init=0.0)
        if auto_weight < PSEUDO_DEAD_ZONE_FLOOR
            auto_signal = 0.0  # Dead zone: not enough observed concretes
        else
            # Linear ramp above floor
            auto_signal = (auto_weight - PSEUDO_DEAD_ZONE_FLOOR) * PSEUDO_RAMP_SLOPE
        end

        # User directives: each adds bonus, bypassing dead zone.
        user_bonus = length(user_concretes) * PSEUDO_USER_DIRECTIVE_BONUS

        # Total = auto signal + user bonus, capped.
        return min(auto_signal + user_bonus, PSEUDO_SIGNAL_CAP)
    end
end

# ==============================================================================
# GROWTH ROUTING
# ==============================================================================

"""
    route_growth(entry::InverseEntry; sigil_class::Symbol) -> GrowthRoute

Decide where to route growth based on magnet strength and sigil class.
Three tiers:

  1. PETTY (magnet < ROUTE_NODE_THRESHOLD): no node grown, trivial gap filled.
     - :macro sigil → SIGIL_LEXICON (add concrete to lexicon)
     - :relation sigil → VERB_REGISTRATION (add verb to expansion)
     - :lambda sigil with similar tokens → THESAURUS_PAIR
     - default → GOVERNANCE_DATA

  2. NODE (magnet >= ROUTE_NODE_THRESHOLD): grow a voter node.
     - Default for most sigil shapes.
     - node_type = :voter (grows in groups, eligible for idle chatter).

  3. AIML (magnet >= ROUTE_AIML_THRESHOLD): grow an AIML executive node.
     - Only for :relation sigils or patterns suggesting executive behavior.
     - Per-lobe tribes, 1/3 population cap.

  4. SIGIL VOTER NODE: node_type = :sigil (NOCHAT, singleton).
     - When the shape itself needs a dedicated voter node.
     - Triggered when a NEW sigil shape has high magnet strength but
       no existing node represents it.

NOTE: Antimatch nodes are DEPRECATED and will NEVER be routed.
"""
function route_growth(entry::InverseEntry; sigil_class::Symbol = :macro,
                             lobe_hint::String = "")::GrowthRoute
    strength = magnet_strength(entry)
    concrete_tokens = collect(keys(entry.concretes))
    user_directives = filter(k -> entry.concretes[k].is_user_directive,
                             keys(entry.concretes)) |> collect
    _lobe = isempty(lobe_hint) ? entry.lobe_hint : lobe_hint

    # ── BELOW PETTY THRESHOLD: no growth at all ──────────────────────────────
    if strength < ROUTE_PETTY_THRESHOLD
        return GrowthRoute(:none, GOVERNANCE_DATA, entry.sigil_name,
                          strength, concrete_tokens, user_directives,
                          strength * MAGNET_EVIDENCE_MULTIPLIER,
                          _lobe,
                          "Magnet strength $(round(strength, digits=2)) below petty threshold $(ROUTE_PETTY_THRESHOLD)")
    end

    # ── PETTY ZONE: trivial growth, no node ───────────────────────────────────
    if strength < ROUTE_NODE_THRESHOLD
        petty_type = _classify_petty(entry, sigil_class)
        evidence_bonus = strength * MAGNET_EVIDENCE_MULTIPLIER
        return GrowthRoute(:petty, petty_type, entry.sigil_name,
                          strength, concrete_tokens, user_directives,
                          evidence_bonus,
                          _lobe,
                          "Petty growth: $(petty_type) for &$(entry.sigil_name) (strength=$(round(strength, digits=2)))")
    end

    # ── AIML ZONE: executive template node ───────────────────────────────────
    # GRUG: Only :relation sigils or high-density shapes with executive character
    # get AIML nodes. They're expensive — per-lobe tribes, 1/3 cap.
    if strength >= ROUTE_AIML_THRESHOLD && sigil_class in (:relation, :lambda)
        evidence_bonus = strength * MAGNET_EVIDENCE_MULTIPLIER
        return GrowthRoute(:aiml_node, GOVERNANCE_DATA, entry.sigil_name,
                          strength, concrete_tokens, user_directives,
                          evidence_bonus,
                          _lobe,
                          "AIML growth for &$(entry.sigil_name) (strength=$(round(strength, digits=2)), class=:$sigil_class)")
    end

    # ── SIGIL VOTER NODE ─────────────────────────────────────────────────────
    # GRUG: When a NEW sigil shape has high magnet but no node yet represents it,
    # grow a :sigil node_type. These are NOCHAT, singleton, never in growth groups.
    # Trigger: sigil class is :tag or :relation AND magnet is strong.
    if sigil_class in (:tag, :relation) && strength >= ROUTE_NODE_THRESHOLD
        evidence_bonus = strength * MAGNET_EVIDENCE_MULTIPLIER
        return GrowthRoute(:sigil_voter_node, GOVERNANCE_DATA, entry.sigil_name,
                          strength, concrete_tokens, user_directives,
                          evidence_bonus,
                          _lobe,
                          "Sigil voter node for &$(entry.sigil_name) (strength=$(round(strength, digits=2)), NOCHAT singleton)")
    end

    # ── REGULAR VOTER NODE (default) ──────────────────────────────────────────
    # GRUG: The most common growth target. node_type=:voter, grows in groups,
    # eligible for idle chatter. Standard pattern-activated voting node.
    evidence_bonus = strength * MAGNET_EVIDENCE_MULTIPLIER
    return GrowthRoute(:voter_node, GOVERNANCE_DATA, entry.sigil_name,
                      strength, concrete_tokens, user_directives,
                      evidence_bonus,
                      _lobe,
                      "Voter node for &$(entry.sigil_name) (strength=$(round(strength, digits=2)))")
end

"""
    _classify_petty(entry, sigil_class) -> PettyGrowthType

Decide which kind of petty growth to dispatch based on sigil class and
concrete characteristics.
"""
function _classify_petty(entry::InverseEntry, sigil_class::Symbol)::PettyGrowthType
    if sigil_class == :macro
        # :macro sigils (&noun) → add concrete to lexicon
        return SIGIL_LEXICON
    elseif sigil_class == :relation
        # :relation sigils (&causal) → add verb to expansion
        return VERB_REGISTRATION
    elseif sigil_class == :lambda
        # :lambda sigils (&n, &word) → check for thesaurus pairs among concretes
        # If concretes are string tokens (not just digits), thesaurus pair possible.
        non_numeric_concretes = filter(c -> !all(isdigit, c), keys(entry.concretes))
        if length(non_numeric_concretes) >= 2
            return THESAURUS_PAIR
        end
        return GOVERNANCE_DATA
    else
        # :tag, :glue, :functor, :procedure → governance data
        return GOVERNANCE_DATA
    end
end

# ==============================================================================
# CONCRETE MANAGEMENT — add, observe, decay
# ==============================================================================

"""
    add_concrete!(sigil_name, token; user_directive=false, sigil_class=nothing)

Add a concrete token to the inverse index under a sigil shape. If the sigil
doesn't have an inverse entry yet, one is created.

If `user_directive=true`, the concrete bypasses the pseudononlinear dead zone.
This is for when the user EXPLICITLY says something like "quantum is a &noun".

If `sigil_class` is provided, it's used to set the magnet mode for new entries.
If not provided, the class is looked up from the SigilRegistry (if available).

Thread-safe via ReentrantLock.
"""
function add_concrete!(sigil_name::String, token::String;
                       user_directive::Bool = false,
                       sigil_class::Union{Symbol, Nothing} = nothing,
                       lobe_hint::String = "")
    token_lower = lowercase(strip(token))
    isempty(token_lower) && return nothing

    lock(_INVERSE_LOCK) do
        # GRUG: Create inverse entry if it doesn't exist
        if !haskey(_INVERSE_TABLE, sigil_name)
            # Determine magnet mode from sigil class
            mode = _magnet_mode_for_class(sigil_class)
            entry = InverseEntry(sigil_name, mode)
            _INVERSE_TABLE[sigil_name] = entry
        end

        entry = _INVERSE_TABLE[sigil_name]

        # GRUG v8.2: Store lobe hint if provided — "science: answer" prefix
        if !isempty(lobe_hint) && isempty(entry.lobe_hint)
            entry.lobe_hint = lobe_hint
        end

        # GRUG: Cap check — bounded growth
        if length(entry.concretes) >= MAX_CONCRETES_PER_SIGIL
            # Evict lowest-weight non-user-directive concrete
            evict_candidates = filter(e -> !e.is_user_directive, values(entry.concretes))
            if !isempty(evict_candidates)
                lowest = argmin(e -> e.accumulated_weight, evict_candidates)
                delete!(entry.concretes, lowest.token)
            else
                return nothing  # All user directives, can't evict
            end
        end

        # GRUG: Add or update the concrete
        if haskey(entry.concretes, token_lower)
            ce = entry.concretes[token_lower]
            ce.observation_count += 1
            ce.accumulated_weight += 1.0  # Each observation adds weight
            ce.last_seen = time()
            # GRUG: Upgrade to user directive if this observation is one
            if user_directive && !ce.is_user_directive
                ce.is_user_directive = true
                entry.user_directive_count += 1
            end
        else
            ce = ConcreteEntry(token_lower; is_user_directive=user_directive)
            entry.concretes[token_lower] = ce
            if user_directive
                entry.user_directive_count += 1
            end
        end

        entry.total_observations += 1

        # GRUG: Update cached cluster density
        entry.cluster_density = magnet_strength(entry)
    end

    return nothing
end

"""
    add_concretes_from_bindings!(bindings)

Process SigilPromoter bindings to extract concretes and add them to the
inverse index. Each binding tells us what token was erased during promotion
and which sigil it was promoted to — that's EXACTLY the concrete→shape
mapping we need.

This is the AUTOMATIC path: every time SigilPromoter promotes a token,
we learn that the token is a concrete of that sigil shape.

bindings can be a Vector of SigilBinding structs or any iterable where
each element has .name and .value fields.
"""
function add_concretes_from_bindings!(bindings)
    for b in bindings
        try
            sig_name = string(getproperty(b, :name))
            token = string(getproperty(b, :value))
            if !isempty(sig_name) && !isempty(token)
                add_concrete!(sig_name, token;
                             user_directive=false,
                             sigil_class=nothing)
            end
        catch
            # GRUG: Binding without .name or .value — skip silently.
            # Not all iterables have these fields. Duck-typing is fine here.
        end
    end
end

"""
    observe_concretes!(sigil_name, tokens; sigil_class=nothing)

Observe multiple concrete tokens under a sigil shape. Called from
AutoGrowth SOURCE 19 when uncovered tokens cluster under a sigil.

This is the EVIDENCE-BASED path: not every observation triggers growth,
but every observation builds magnet strength.
"""
function observe_concretes!(sigil_name::String, tokens::Vector{String};
                            sigil_class::Union{Symbol, Nothing} = nothing,
                            lobe_hint::String = "")
    for tok in tokens
        add_concrete!(sigil_name, tok; user_directive=false, sigil_class=sigil_class,
                      lobe_hint=lobe_hint)
    end
end

"""
    user_add_concrete!(sigil_name, token; sigil_class=nothing)

User explicitly adds a concrete to a sigil shape. Bypasses dead zone.
This is for when the user says "quantum is a &noun" — a DIRECTIVE.
"""
function user_add_concrete!(sigil_name::String, token::String;
                            sigil_class::Union{Symbol, Nothing} = nothing,
                            lobe_hint::String = "")
    add_concrete!(sigil_name, token; user_directive=true, sigil_class=sigil_class,
                  lobe_hint=lobe_hint)
end

# ==============================================================================
# DECAY — concretes fade if not re-observed
# ==============================================================================

"""
    decay_concretes!()

Halve accumulated weight of all concretes, evict those below noise floor.
Same philosophy as AutoGrowth evidence decay. Called periodically.
"""
function decay_concretes!()
    t_now = time()
    lock(_INVERSE_LOCK) do
        if t_now - _LAST_DECAY[] < CONCRETE_DECAY_INTERVAL
            return nothing
        end
        _LAST_DECAY[] = t_now

        for (sig_name, entry) in _INVERSE_TABLE
            to_evict = String[]
            for (token, ce) in entry.concretes
                # GRUG: User directives decay slower — they're directives, not noise
                decay_factor = ce.is_user_directive ? 0.75 : 0.5
                ce.accumulated_weight *= decay_factor
                if ce.accumulated_weight < CONCRETE_NOISE_FLOOR
                    push!(to_evict, token)
                end
            end
            for token in to_evict
                if entry.concretes[token].is_user_directive
                    entry.user_directive_count -= 1
                end
                delete!(entry.concretes, token)
            end

            # GRUG: Update cached density after decay
            entry.cluster_density = magnet_strength(entry)
        end

        # GRUG: Evict empty inverse entries (sigils with no concretes left)
        empty_sigs = filter(k -> isempty(_INVERSE_TABLE[k].concretes), keys(_INVERSE_TABLE))
        for k in empty_sigs
            delete!(_INVERSE_TABLE, k)
        end

        # GRUG: Cap check for total entries
        while length(_INVERSE_TABLE) > MAX_INVERSE_ENTRIES
            # Evict entry with lowest total density
            lowest_sig = argmin(k -> _INVERSE_TABLE[k].cluster_density, keys(_INVERSE_TABLE))
            delete!(_INVERSE_TABLE, lowest_sig)
        end
    end
    return nothing
end

# ==============================================================================
# EVIDENCE INTEGRATION — SOURCE 19 for AutoGrowth
# ==============================================================================

"""
    feed_evidence!(; sigil_table_entries, user_text, node_patterns, intensity)

GRUG: This is SOURCE 19 for AutoGrowth. It scans user text for tokens that
match sigil shapes, clusters uncovered tokens by shape, and returns a list
of (pattern, evidence_bonus, source_tag, growth_type, route) tuples that
AutoGrowth can feed into its _add_evidence! accumulator.

The key insight: instead of treating each uncovered token as an unrelated
atom (like SOURCE 1 does), this clusters them by sigil shape. Two uncovered
tokens that are both concretes of &noun produce a STRONGER combined signal
than two unrelated atoms would.

Returns Vector{NamedTuple} with:
  - pattern::String — the candidate pattern for evidence
  - intensity_bonus::Float64 — how much to add to evidence intensity
  - source::String — "inverse_sigil_magnet"
  - growth_type::Symbol — routed growth type (:match, :sigil, :aiml, etc.)
  - route::GrowthRoute — the full routing decision
"""
function feed_evidence!(;
    sigil_table_entries::Dict = Dict{String,Any}(),
    user_text::String = "",
    node_patterns::Set{String} = Set{String}(),
    intensity::Float64 = 1.0,
    lobe_hint::String = "",
)::Vector{NamedTuple}
    results = NamedTuple[]

    isempty(strip(user_text)) && return results

    # GRUG: Decay concretes periodically
    decay_concretes!()

    # GRUG: For each sigil in the registry, check if user text contains
    # tokens that could be concretes under that sigil shape.
    tokens = _tokenize(user_text)
    isempty(tokens) && return results

    uncovered = filter(t -> !_is_covered(t, node_patterns), tokens)

    for (sig_name, sig_entry) in sigil_table_entries
        # GRUG: Determine sigil class
        sig_class = _extract_sigil_class(sig_entry)

        # GRUG: Find uncovered tokens that could be concretes of this sigil
        matching_concretes = _find_concretes_for_sigil(
            sig_name, sig_class, sig_entry, uncovered, user_text
        )

        if isempty(matching_concretes)
            continue
        end

        # GRUG: Observe these concretes — they build magnet strength
        observe_concretes!(sig_name, matching_concretes; sigil_class=sig_class,
                           lobe_hint=lobe_hint)

        # GRUG: Get the inverse entry and compute routing
        entry = lock(_INVERSE_LOCK) do
            get(_INVERSE_TABLE, sig_name, nothing)
        end

        if entry === nothing
            continue
        end

        route = route_growth(entry; sigil_class=sig_class, lobe_hint=lobe_hint)

        # GRUG: Only produce evidence if the route is not :none
        if route.target == :none
            continue
        end

        # GRUG: Map route.target to AutoGrowth growth_type symbol
        ag_growth_type = _route_to_growth_type(route)

        # GRUG: For each uncovered token under this sigil, add evidence
        # with the magnet's bonus. The bonus is STRONGER than plain SOURCE 1
        # because the magnet clusters related observations together.
        for tok in matching_concretes
            push!(results, (
                pattern = tok,
                intensity_bonus = route.evidence_bonus * intensity,
                source = MAGNET_EVIDENCE_SOURCE_TAG,
                growth_type = ag_growth_type,
                route = route,
                lobe_hint = route.lobe_hint,
            ))
        end

        # GRUG: Also add a sigil-level evidence entry if routing to sigil/aiml
        if route.target in (:sigil_voter_node, :aiml_node)
            push!(results, (
                pattern = "sigil:$(sig_name)",
                intensity_bonus = route.evidence_bonus * intensity * 0.5,
                source = MAGNET_EVIDENCE_SOURCE_TAG,
                growth_type = :sigil,
                route = route,
                lobe_hint = route.lobe_hint,
            ))
        end
    end

    return results
end

# ==============================================================================
# PETTY DISPATCH — route petty growth to PettyLearner or direct sigil ops
# ==============================================================================

"""
    dispatch_petty!(route::GrowthRoute; kwargs...) -> String

Dispatch a petty growth route to the appropriate fast-path handler.
Returns a human-readable description of what happened.

This is SEPARATE from PettyLearner.classify_petty — this handles
petty growth identified by the INVERSE SIGIL magnet, not by PettyLearner's
token-level classifier. The two systems cooperate:
  - PettyLearner handles ONE uncovered token with high similarity to a known token
  - InverseSigil handles clusters of concretes under a sigil shape that don't
    warrant a full node

Kwargs:
  - register_sigil_fn — (sigil_name, expansion_entries) -> Bool
  - register_thesaurus_pair_fn — (word_a, word_b) -> Bool
  - add_lobe_whitelist_fn — (lobe_id, token) -> Int
  - sigil_table — the SigilTable for class lookups
"""
function dispatch_petty!(route::GrowthRoute;
    register_sigil_fn = nothing,
    register_thesaurus_pair_fn = nothing,
    add_lobe_whitelist_fn = nothing,
    sigil_table = nothing,
)::String
    if route.target != :petty
        return "Not a petty route (target=$(route.target))"
    end

    if route.petty_type == SIGIL_LEXICON
        # ── Add concrete to :macro sigil lexicon ──────────────────────────────
        # GRUG: The concretes under this sigil should be added to its lexicon.
        # This makes the sigil's expansion richer — more words match &noun.
        if register_sigil_fn !== nothing && !isempty(route.concretes)
            try
                success = register_sigil_fn(route.sigil_name, route.concretes)
                return success ?
                    "Added $(length(route.concretes)) concretes to &$(route.sigil_name) lexicon" :
                    "Sigil lexicon update for &$(route.sigil_name) failed"
            catch e
                return "Sigil lexicon dispatch failed: $e"
            end
        else
            return "Sigil lexicon: no register_sigil_fn or no concretes"
        end

    elseif route.petty_type == VERB_REGISTRATION
        # ── Add verb to :relation sigil expansion ─────────────────────────────
        # GRUG: Concrete tokens under a :relation sigil are verbs that should
        # be added to the sigil's expansion list. E.g. "produces" → &causal.
        if register_sigil_fn !== nothing && !isempty(route.concretes)
            try
                # GRUG: Filter to plausible verbs (not digits, not too short)
                verb_candidates = filter(c -> length(c) > 3 && !all(isdigit, c),
                                        route.concretes)
                if !isempty(verb_candidates)
                    success = register_sigil_fn(route.sigil_name, verb_candidates)
                    return success ?
                        "Added $(length(verb_candidates)) verbs to &$(route.sigil_name) expansion" :
                        "Verb registration for &$(route.sigil_name) failed"
                else
                    return "No valid verb candidates under &$(route.sigil_name)"
                end
            catch e
                return "Verb registration dispatch failed: $e"
            end
        else
            return "Verb registration: no register_sigil_fn or no concretes"
        end

    elseif route.petty_type == THESAURUS_PAIR
        # ── Register thesaurus pair from shape-cluster similarity ──────────────
        # GRUG: Non-numeric concretes under a :lambda sigil might be synonyms.
        # Register the most similar pair.
        if register_thesaurus_pair_fn !== nothing && length(route.concretes) >= 2
            try
                # GRUG: Take the two most-observed concretes as the pair.
                # A proper thesaurus similarity check would be better, but
                # we don't have that function here — we rely on shape clustering
                # as the similarity signal.
                sorted = sort(route.concretes, by=c -> _observation_count(c), rev=true)
                word_a, word_b = sorted[1], sorted[2]
                success = register_thesaurus_pair_fn(word_a, word_b)
                return success ?
                    "Thesaurus pair: $word_a ↔ $word_b (shape-clustered under &$(route.sigil_name))" :
                    "Thesaurus pair registration failed"
            catch e
                return "Thesaurus pair dispatch failed: $e"
            end
        else
            return "Thesaurus pair: no register_fn or fewer than 2 concretes"
        end

    elseif route.petty_type == GOVERNANCE_DATA
        # ── Side governance data (lobe whitelist, sigil params, etc.) ──────────
        # GRUG: These concretes don't fit any other petty category.
        # Add to lobe whitelist if we can determine a lobe.
        if add_lobe_whitelist_fn !== nothing && !isempty(route.concretes)
            try
                total_added = 0
                for tok in route.concretes
                    # GRUG: Try to infer lobe from the sigil name
                    lobe = _infer_lobe_from_sigil(route.sigil_name)
                    count = add_lobe_whitelist_fn(lobe, tok)
                    total_added += count
                end
                return "Governance: added $total_added whitelist entries from &$(route.sigil_name)"
            catch e
                return "Governance data dispatch failed: $e"
            end
        else
            return "Governance data: no add_lobe_whitelist_fn or no concretes"
        end
    end

    return "Unknown petty type: $(route.petty_type)"
end

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

"""
    _magnet_mode_for_class(sigil_class) -> MagnetMode

Determine magnet mode from sigil class. :macro → LINEAR, :lambda → PSEUDONONLINEAR.
Unknown → PSEUDONONLINEAR (conservative default).
"""
function _magnet_mode_for_class(sigil_class::Union{Symbol, Nothing})::MagnetMode
    if sigil_class === nothing
        return PSEUDONONLINEAR  # Conservative default
    end
    if sigil_class == :macro
        return LINEAR  # Token sigils — every concrete matters
    elseif sigil_class == :lambda
        return PSEUDONONLINEAR  # Functorial sigils — noisy, need damping
    elseif sigil_class == :relation
        return LINEAR  # Relation sigils — each verb expansion is meaningful
    elseif sigil_class == :tag
        return LINEAR  # Tag sigils — rare, each concrete is significant
    else
        return PSEUDONONLINEAR  # Reserved classes — conservative
    end
end

"""
    _route_to_growth_type(route) -> Symbol

Map a GrowthRoute target to an AutoGrowth growth_type symbol.
"""
function _route_to_growth_type(route::GrowthRoute)::Symbol
    if route.target == :voter_node
        return :inverse_voter_node  # GRUG v8.2: Was :match — now distinct growth type
    elseif route.target == :sigil_voter_node
        return :sigil_voter_node  # GRUG v8.2: Was :sigil — now distinct growth type
    elseif route.target == :aiml_node
        return :aiml  # AIML executive template
    elseif route.target == :petty
        # GRUG: Map petty types to AutoGrowth growth types
        if route.petty_type == SIGIL_LEXICON
            return :sigil  # Adding to sigil lexicon = sigil growth
        elseif route.petty_type == VERB_REGISTRATION
            return :sigil  # Adding verb to expansion = sigil growth
        elseif route.petty_type == THESAURUS_PAIR
            return :thesaurus  # Synonym pair = thesaurus growth
        elseif route.petty_type == GOVERNANCE_DATA
            return :lobe_whitelist  # Side data = lobe whitelist growth
        end
    end
    return :match  # Default fallback
end

"""
    _extract_sigil_class(sig_entry) -> Symbol

Extract the sigil class from a sigil entry dict. Handles both
SigilEntry structs and Dict representations.
"""
function _extract_sigil_class(sig_entry)::Symbol
    try
        if isa(sig_entry, SigilEntry)
            return sig_entry.class
        end
        if isa(sig_entry, AbstractDict)
            if haskey(sig_entry, :class)
                return sig_entry[:class]
            end
            if haskey(sig_entry, "class")
                return Symbol(sig_entry["class"])
            end
        end
        # GRUG: Try to access .class field on any struct
        if hasproperty(sig_entry, :class)
            return getfield(sig_entry, :class)
        end
    catch; end
    return :macro  # Default to :macro (most common, linear mode)
end

"""
    _find_concretes_for_sigil(sig_name, sig_class, sig_entry, uncovered_tokens, user_text)

Determine which uncovered tokens could be concretes of this sigil shape.
Uses the sigil's promote_predicate (if available) or heuristic matching.
"""
function _find_concretes_for_sigil(sig_name::String, sig_class::Symbol,
                                    sig_entry, uncovered_tokens::Vector{String},
                                    user_text::String)::Vector{String}
    concretes = String[]

    # GRUG: For :macro sigils with a lexicon, tokens that match the lexicon
    # are concretes. BUT we want UNCOVERED tokens, so we also consider tokens
    # that the promoter WOULD promote to this sigil.
    if sig_class == :macro
        # Check if the sigil has a lexicon — tokens in it are known concretes
        lexicon = nothing
        try
            if isa(sig_entry, SigilEntry) && sig_entry.lexicon !== nothing
                lexicon = sig_entry.lexicon
            elseif isa(sig_entry, AbstractDict)
                lexicon = get(sig_entry, :lexicon, get(sig_entry, "lexicon", nothing))
            end
        catch; end

        # GRUG: For &noun-like sigils, ALL uncovered non-stopword tokens are
        # potential concretes. The sigil shape is "any noun", so any noun-like
        # token that isn't covered could be a concrete of &noun.
        # We can't determine definitively if a word is a noun, but we CAN
        # use heuristics: length > 3, not a stopword, not all digits.
        if sig_name == "noun"
            for tok in uncovered_tokens
                if length(tok) > 3 && !all(isdigit, tok)
                    push!(concretes, tok)
                end
            end
        elseif lexicon !== nothing
            # GRUG: For other :macro sigils, check lexicon membership.
            # If a token is already in the lexicon, it's a known concrete.
            # We want NEW concretes — uncovered tokens that COULD belong.
            # Heuristic: if the user text mentions the sigil name, nearby
            # uncovered tokens are candidate concretes.
            if occursin(sig_name, lowercase(user_text)) ||
               occursin("&$sig_name", lowercase(user_text))
                for tok in uncovered_tokens
                    if length(tok) > 3 && !all(isdigit, tok)
                        push!(concretes, tok)
                    end
                end
            end
        end

    elseif sig_class == :lambda
        # GRUG: For :lambda sigils, use promote_predicate if available.
        # &n: digits are concretes. &op: arithmetic operators are concretes.
        # &word: any non-stopword token is a concrete.
        predicate = nothing
        try
            if isa(sig_entry, SigilEntry) && sig_entry.promote_predicate !== nothing
                predicate = sig_entry.promote_predicate
            elseif isa(sig_entry, AbstractDict)
                predicate = get(sig_entry, :promote_predicate,
                               get(sig_entry, "promote_predicate", nothing))
            end
        catch; end

        if predicate !== nothing
            for tok in uncovered_tokens
                try
                    if predicate(tok)
                        push!(concretes, tok)
                    end
                catch; end
            end
        else
            # GRUG: Heuristic matching by sigil name
            if sig_name == "n"
                # &n: digits are concretes
                for tok in uncovered_tokens
                    if all(isdigit, tok) || tryparse(Float64, tok) !== nothing
                        push!(concretes, tok)
                    end
                end
            elseif sig_name == "op"
                # &op: arithmetic operators — not typically uncovered tokens
                # but check for operator-like tokens
                for tok in uncovered_tokens
                    if tok in ["+", "-", "*", "/", "=", "^", "%"]
                        push!(concretes, tok)
                    end
                end
            elseif sig_name == "word"
                # &word: any non-stopword token
                for tok in uncovered_tokens
                    if length(tok) > 3 && !all(isdigit, tok)
                        push!(concretes, tok)
                    end
                end
            end
        end

    elseif sig_class == :relation
        # GRUG: For :relation sigils, verbs that match the expansion are concretes.
        # Uncovered tokens that appear in the expansion list are candidate concretes.
        expansion = nothing
        try
            if isa(sig_entry, SigilEntry) && sig_entry.expansion !== nothing
                expansion = sig_entry.expansion
            elseif isa(sig_entry, AbstractDict)
                expansion = get(sig_entry, :expansion,
                               get(sig_entry, "expansion", nothing))
            end
        catch; end

        if expansion !== nothing
            expansion_lower = Set(lowercase(strip(string(e))) for e in expansion)
            for tok in uncovered_tokens
                if tok in expansion_lower
                    push!(concretes, tok)
                end
            end
        end

        # GRUG: Also check if uncovered tokens are verbs that could be ADDED
        # to the expansion. If the user text contains the sigil name and
        # nearby uncovered verbs, they're candidates.
        if occursin(sig_name, lowercase(user_text)) ||
           occursin("&$sig_name", lowercase(user_text))
            # GRUG: Simple verb heuristic — tokens that end in "s", "ed", "ing"
            for tok in uncovered_tokens
                if length(tok) > 3 && (endswith(tok, "s") || endswith(tok, "ed") || endswith(tok, "ing"))
                    if !(tok in concretes)  # Don't double-add
                        push!(concretes, tok)
                    end
                end
            end
        end
    end

    return concretes
end

# ── Token/pattern helpers (same logic as AutoGrowth, duplicated for module independence) ──

const _INV_STOPWORDS = Set([
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

function _tokenize(text::String)::Vector{String}
    tokens = split(lowercase(strip(text)))
    return filter(t -> length(t) > 2 && !(t in _INV_STOPWORDS), String.(tokens))
end

function _is_covered(token::String, existing_patterns::Set{String})::Bool
    tok_lower = lowercase(strip(token))
    for pat in existing_patterns
        if occursin(tok_lower, lowercase(pat))
            return true
        end
    end
    return false
end

function _observation_count(token::String)::Int
    # GRUG: Get observation count from ALL inverse entries that contain this token.
    # Used for sorting concretes by frequency in thesaurus pair selection.
    total = 0
    lock(_INVERSE_LOCK) do
        for (_, entry) in _INVERSE_TABLE
            if haskey(entry.concretes, token)
                total += entry.concretes[token].observation_count
            end
        end
    end
    return total
end

function _infer_lobe_from_sigil(sigil_name::String)::String
    # GRUG: Simple heuristic — map sigil names to likely lobes.
    # More specific than token-level inference because sigils carry semantic weight.
    if sigil_name in ["n", "op"]
        return "MathLobe"
    elseif sigil_name in ["noun", "word"]
        return "default"  # nouns are universal, no specific lobe
    elseif sigil_name in ["temporal", "now", "before", "next"]
        return "default"  # temporal is cross-cutting
    elseif sigil_name in ["causal"]
        return "ReasoningLobe"
    elseif sigil_name in ["spatial"]
        return "ScienceLobe"
    elseif sigil_name in ["possessive", "similarity"]
        return "default"
    else
        return "default"
    end
end

# ==============================================================================
# STATUS + DIAGNOSTICS
# ==============================================================================

"""
    get_inverse_sigil_status() -> String

Human-readable status of the inverse sigil table, including all entries
and their magnet strengths.
"""
function get_inverse_sigil_status()::String
    lines = String[
        "=== INVERSE SIGIL (GROWTH MAGNET) STATUS ===",
        "  max_concretes_per_sigil=$MAX_CONCRETES_PER_SIGIL",
        "  max_inverse_entries=$MAX_INVERSE_ENTRIES",
        "  route_petty_threshold=$ROUTE_PETTY_THRESHOLD",
        "  route_node_threshold=$ROUTE_NODE_THRESHOLD",
        "  route_aiml_threshold=$ROUTE_AIML_THRESHOLD",
        "  magnet_evidence_multiplier=$MAGNET_EVIDENCE_MULTIPLIER",
        "  ── Magnet Modes ──",
        "  LINEAR: weight=$(LINEAR_WEIGHT), floor=$(LINEAR_FLOOR)",
        "  PSEUDONONLINEAR: dead_zone=$(PSEUDO_DEAD_ZONE_FLOOR), slope=$(PSEUDO_RAMP_SLOPE), cap=$(PSEUDO_SIGNAL_CAP), user_bonus=$(PSEUDO_USER_DIRECTIVE_BONUS)",
    ]

    lock(_INVERSE_LOCK) do
        push!(lines, "  ── Entries ($(length(_INVERSE_TABLE))) ──")
        # Sort by cluster density (highest first)
        sorted = sort(collect(_INVERSE_TABLE), by=x -> x[2].cluster_density, rev=true)
        for (sig_name, entry) in sorted[1:min(20, length(sorted))]
            mode_str = entry.magnet_mode == LINEAR ? "LIN" : "PSNL"
            push!(lines, "    &$(sig_name): density=$(round(entry.cluster_density, digits=2)) " *
                         "concretes=$(length(entry.concretes)) " *
                         "user_directives=$(entry.user_directive_count) " *
                         "mode=$(mode_str) " *
                         "total_obs=$(entry.total_observations)")
        end
        if length(sorted) > 20
            push!(lines, "    ... and $(length(sorted) - 20) more")
        end
    end

    return join(lines, "\n")
end

"""
    get_all_routes(; sigil_table_entries) -> Vector{GrowthRoute}

Compute current growth routes for ALL inverse entries. Useful for
diagnostics and for feeding into AutoGrowth's evidence pipeline.
"""
function get_all_routes(; sigil_table_entries::Dict = Dict{String,Any}())::Vector{GrowthRoute}
    routes = GrowthRoute[]
    lock(_INVERSE_LOCK) do
        for (sig_name, entry) in _INVERSE_TABLE
            # GRUG: Look up sigil class from the registry if available
            sig_class = :macro  # default
            if haskey(sigil_table_entries, sig_name)
                sig_class = _extract_sigil_class(sigil_table_entries[sig_name])
            end
            push!(routes, route_growth(entry; sigil_class=sig_class))
        end
    end
    return routes
end

# ==============================================================================
# RESET — for testing / specimen reload
# ==============================================================================

"""
    reset_inverse_table!()

Clear all inverse entries. Called on specimen reload to prevent stale data.
"""
function reset_inverse_table!()
    lock(_INVERSE_LOCK) do
        empty!(_INVERSE_TABLE)
        _LAST_DECAY[] = time()
    end
end

"""
    set_lobe_hints_for_tokens!(tokens::Vector{String}, lobe_name::String)

GRUG v8.2: Set lobe_hint on any inverse entries whose concretes include
one of the given tokens. This is TARGETED — only affects entries that
already know about these tokens, not a broadcast to all sigils.

Called from process_mission when a lobe-qualified answer like
"science: gravity is an attractive force" is detected. The content tokens
("gravity", "attractive", "force") are checked against existing inverse
entries, and matching entries get the lobe hint set.
"""
function set_lobe_hints_for_tokens!(tokens::Vector{String}, lobe_name::String)
    if isempty(lobe_name); return nothing; end
    lock(_INVERSE_LOCK) do
        for (sig_name, entry) in _INVERSE_TABLE
            for tok in tokens
                if haskey(entry.concretes, lowercase(strip(tok)))
                    if isempty(entry.lobe_hint)
                        entry.lobe_hint = lobe_name
                    end
                    break   # one match is enough per entry
                end
            end
        end
    end
    return nothing
end

"""
    get_table_snapshot() -> Dict{String, Any}

GRUG v8.2: Serialize the entire inverse table for specimen save.
Returns a dict that can be JSON-serialized and restored with load_table_snapshot!().
"""
function get_table_snapshot()::Dict{String, Any}
    lock(_INVERSE_LOCK) do
        entries = Dict{String, Any}()
        for (sig_name, entry) in _INVERSE_TABLE
            concretes_data = Dict{String, Any}()
            for (tok, ce) in entry.concretes
                concretes_data[tok] = Dict{String, Any}(
                    "token"             => ce.token,
                    "observation_count"  => ce.observation_count,
                    "accumulated_weight" => ce.accumulated_weight,
                    "is_user_directive"  => ce.is_user_directive,
                    "first_seen"         => ce.first_seen,
                    "last_seen"          => ce.last_seen,
                )
            end
            entries[sig_name] = Dict{String, Any}(
                "sigil_name"              => entry.sigil_name,
                "magnet_mode"             => entry.magnet_mode === PSEUDONONLINEAR ? "pseudononlinear" : "linear",
                "concretes"               => concretes_data,
                "cluster_density"         => entry.cluster_density,
                "last_routed_growth_type" => String(entry.last_routed_growth_type),
                "total_observations"      => entry.total_observations,
                "user_directive_count"    => entry.user_directive_count,
                "lobe_hint"               => entry.lobe_hint,
            )
        end
        return Dict{String, Any}(
            "entries"    => entries,
            "last_decay" => _LAST_DECAY[],
        )
    end
end

"""
    load_table_snapshot!(data::Dict{String, Any})

GRUG v8.2: Restore the inverse table from a specimen snapshot.
Overwrites any existing data. Called during /loadSpecimen.
"""
function load_table_snapshot!(data)
    lock(_INVERSE_LOCK) do
        empty!(_INVERSE_TABLE)
        entries_data = get(data, "entries", Dict{String, Any}())
        for (sig_name, edata) in entries_data
            concretes = Dict{String, ConcreteEntry}()
            concretes_raw = get(edata, "concretes", Dict{String, Any}())
            for (tok, cdata) in concretes_raw
                concretes[tok] = ConcreteEntry(
                    String(get(cdata, "token", tok)),
                    Int(get(cdata, "observation_count", 1)),
                    Float64(get(cdata, "accumulated_weight", 1.0)),
                    Bool(get(cdata, "is_user_directive", false)),
                    Float64(get(cdata, "first_seen", time())),
                    Float64(get(cdata, "last_seen", time())),
                )
            end
            mode_str = String(get(edata, "magnet_mode", "linear"))
            mode = mode_str == "pseudononlinear" ? PSEUDONONLINEAR : LINEAR
            entry = InverseEntry(
                String(get(edata, "sigil_name", sig_name)),
                mode,
            )
            # Overwrite fields that aren't set by constructor
            entry.concretes            = concretes
            entry.cluster_density      = Float64(get(edata, "cluster_density", 0.0))
            growth_type_str            = String(get(edata, "last_routed_growth_type", "none"))
            entry.last_routed_growth_type = Symbol(growth_type_str)
            entry.total_observations   = Int(get(edata, "total_observations", 0))
            entry.user_directive_count = Int(get(edata, "user_directive_count", 0))
            entry.lobe_hint            = String(get(edata, "lobe_hint", ""))
            _INVERSE_TABLE[sig_name]   = entry
        end
        _LAST_DECAY[] = Float64(get(data, "last_decay", time()))
    end
    return nothing
end

"""
    set_lobe_hint!(sigil_name::String, lobe_name::String)

GRUG v8.2: Manually set lobe_hint on an inverse entry.
Called by /setLobeHint command.
"""
function set_lobe_hint!(sigil_name::String, lobe_name::String)
    lock(_INVERSE_LOCK) do
        if haskey(_INVERSE_TABLE, sigil_name)
            _INVERSE_TABLE[sigil_name].lobe_hint = lobe_name
            return true
        end
    end
    return false
end

"""
    clear_lobe_hint!(sigil_name::String)

GRUG v8.2: Clear lobe_hint on an inverse entry.
Called by /clearLobeHint command.
"""
function clear_lobe_hint!(sigil_name::String)
    lock(_INVERSE_LOCK) do
        if haskey(_INVERSE_TABLE, sigil_name)
            _INVERSE_TABLE[sigil_name].lobe_hint = ""
            return true
        end
    end
    return false
end

"""
    get_table_status() -> String

GRUG v8.2: Return a human-readable summary of the inverse table.
Called by /inverseStatus command.
"""
function get_table_status()::String
    lines = String[]
    lock(_INVERSE_LOCK) do
        n_entries = length(_INVERSE_TABLE)
        if n_entries == 0
            push!(lines, "Inverse table is empty. No sigil concretes observed yet.")
            return lines
        end
        push!(lines, "Inverse table: $n_entries sigil(s)")
        push!(lines, repeat("-", 60))
        for (sig_name, entry) in sort(collect(_INVERSE_TABLE); by=x->x[1])
            n_conc = length(entry.concretes)
            n_user = count(ce -> ce.is_user_directive, values(entry.concretes))
            strength = magnet_strength(entry)
            route = route_growth(entry; sigil_class=:macro)
            lobe_str = isempty(entry.lobe_hint) ? "-" : entry.lobe_hint
            push!(lines, "  &$(sig_name): mode=$(entry.magnet_mode), concretes=$n_conc ($(n_user) user), magnet=$(round(strength, digits=2)), route=$(route.target), lobe=$lobe_str")
        end
    end
    return join(lines, "\n")
end

"""
    get_entry_detail(sigil_name::String) -> String

GRUG v8.2: Return a detailed view of one inverse entry.
Called by /inverseDetail command.
"""
function get_entry_detail(sigil_name::String)::String
    lines = String[]
    lock(_INVERSE_LOCK) do
        entry = get(_INVERSE_TABLE, sigil_name, nothing)
        if entry === nothing
            push!(lines, "No inverse entry for sigil '&$(sigil_name)'.")
            return lines
        end
        push!(lines, "Inverse entry: &$(entry.sigil_name)")
        push!(lines, repeat("-", 40))
        push!(lines, "  magnet_mode:       $(entry.magnet_mode)")
        push!(lines, "  cluster_density:    $(round(entry.cluster_density, digits=3))")
        push!(lines, "  total_observations: $(entry.total_observations)")
        push!(lines, "  user_directives:    $(entry.user_directive_count)")
        push!(lines, "  last_route:         $(entry.last_routed_growth_type)")
        push!(lines, "  lobe_hint:          $(isempty(entry.lobe_hint) ? "(none)" : entry.lobe_hint)")
        strength = magnet_strength(entry)
        push!(lines, "  magnet_strength:    $(round(strength, digits=3))")
        # Show concrete tokens sorted by weight
        sorted_conc = sort(collect(entry.concretes); by=x->x[2].accumulated_weight, rev=true)
        push!(lines, "  concretes ($(length(sorted_conc))):")
        for (tok, ce) in sorted_conc
            directive_flag = ce.is_user_directive ? " [USER]" : ""
            push!(lines, "    '$tok': weight=$(round(ce.accumulated_weight, digits=2)), obs=$(ce.observation_count)$(directive_flag)")
        end
    end
    return join(lines, "\n")
end

end # module InverseSigil
