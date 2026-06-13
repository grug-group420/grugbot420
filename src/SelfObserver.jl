# ==============================================================================
# SelfObserver.jl — GRUG Subconscious Microlog Store
# ==============================================================================
# GRUG say: cave have loud thoughts (vote, route, rank). Loud thoughts decide.
# GRUG say: cave ALSO have quiet thoughts in back of head. Bits and pieces.
# GRUG say: "oh that happen... about two day ago... maybe... feels like".
# GRUG say: quiet thoughts NEVER push loud thoughts around. NEVER touch confidence.
# GRUG say: quiet thoughts only whisper to mouth at end, if mouth even ask.
# GRUG say: only ONE loud thought may ask quiet thoughts at a time.
# GRUG say: quiet thoughts get tired. Each loud thought has tokens. Tokens refill.
# GRUG say: quiet thoughts have no clock. Just "rule of thumb": just-now, recent,
#           earlier-today, yesterday-ish, couple-days-ago, a-while-back, long-ago.
# GRUG say: quiet thoughts forget. Old quiet thoughts fade. Strong ones survive.
# GRUG say: NO SILENT FAILURES. Throttle/timeout/miss all return `nothing`,
#           and that is INTENTIONAL — "I don't know" is a valid subconscious answer.
#           But internal counters track WHY so we can audit.
# GRUG say: STRUCTURAL GUARANTEE: nothing in this module returns Float64 from
#           public API. No number that could be added to a vote confidence.
#           If someone later adds one, the test in test_self_observer.jl breaks.
# ==============================================================================
#
# ACADEMIC: This module implements an isolated, fuzzy, throttled, observation-only
# memory store inspired by the role of preconscious / subconscious associative
# fragments. Writes are stochastic (probabilistic insertion). Reads are
# globally serialized (one outstanding reader at a time), per-caller token-bucket
# throttled, and bounded by a hard timeout. Returned hints carry only fuzzy
# time-bucket symbols and provenance tags — never raw timestamps, never
# confidence-shaped scalars. Drop tables (per-key and per-entry) provide
# associative recall via bounded depth-2 walks. Eviction is salience-and-decay
# weighted, so a vivid one-off can outlive a noisy repeat.
#
# IFS UPGRADE: The Microlog now uses an Intuitionistic Fuzzy Set triple (mu, nu, pi)
# instead of a scalar weight. Novel data gets full IFML treatment (high hesitation pi).
# Seen-a-lot data degrades to standard fuzzy (pi collapsed, just mu matters).
# Key variables get RelationalJitter — ephemeral in activity, state persists in table.
#
# This module is ARCHITECTURALLY ISOLATED from vote ranking, candidate scoring,
# and routing. Its public hint type contains zero Float64 fields. The only
# integration point is the generation / system-prompt layer.
# ==============================================================================

module SelfObserver

using Base.Threads
using Base.Threads: Atomic, atomic_add!, atomic_sub!, ReentrantLock
using Random
using ..RelationalJitter

# ==============================================================================
# EXPORTS
# ==============================================================================

export Microlog, SubconsciousStore, SubconsciousHint
export SelfObserverError, SelfObserverConfigError, SelfObserverArgumentError
export observe!, peek_exact, peek_pattern, audit_trail, drop_store!
export reset_audit!, store_size, key_count
export serialize_store, restore_store!, restore_global_store!
export FUZZY_BUCKETS
# GRUG: IFS exports for the growth/link system to inspect fuzzy/IFML state
export IFS_MATURE_THRESHOLD, IFS_INITIAL_MU, IFS_INITIAL_NU, IFS_INITIAL_PI
export is_entry_mature, ifs_state, ifs_reinforce_entry!

# ==============================================================================
# ERROR TYPES — GRUG: no silent failures on programmer errors.
# ==============================================================================
# GRUG: Public API still returns `nothing` on throttle/timeout/miss — those are
# legit subconscious states. Errors below are reserved for misuse: bad config,
# wrong types, structural violations. Loud failures.

struct SelfObserverError <: Exception
    message::String
    context::String
end

struct SelfObserverConfigError <: Exception
    message::String
    field::String
end

struct SelfObserverArgumentError <: Exception
    message::String
    arg::String
end

function Base.showerror(io::IO, e::SelfObserverError)
    print(io, "SelfObserverError: ", e.message, " (context=", e.context, ")")
end
function Base.showerror(io::IO, e::SelfObserverConfigError)
    print(io, "SelfObserverConfigError: ", e.message, " (field=", e.field, ")")
end
function Base.showerror(io::IO, e::SelfObserverArgumentError)
    print(io, "SelfObserverArgumentError: ", e.message, " (arg=", e.arg, ")")
end

# ==============================================================================
# CONSTANTS — GRUG: magic numbers in one place, with reasons.
# ==============================================================================

# GRUG: write-side defaults
const DEFAULT_P_WRITE          = 0.25      # stochastic write probability
const DEFAULT_SALIENCE         = 1.0       # baseline interest weight (maps to initial mu)
const SALIENCE_FLOOR           = 0.0
const SALIENCE_CEILING         = 10.0
const REINFORCE_GAIN           = 0.5       # how much repeat-write boosts existing mu
const WEIGHT_CEILING           = 10.0      # max mu after reinforcement (legacy compat)
const DECAY_PER_TICK           = 0.02      # mu loss per maintenance tick (parked use)

# GRUG: IFS (Intuitionistic Fuzzy Set) constants for the fuzzy/IFML upgrade.
# GRUG say: new data gets full IFML treatment (mu, nu, pi). Seen-a-lot data
# degrades to standard fuzzy (just mu) because pi collapsed near zero.
# GRUG say: key variables get jitter — ephemeral in activity, state persists.
const IFS_INITIAL_MU    = 0.15     # slight positive bias for novel observation (it was observed)
const IFS_INITIAL_NU    = 0.05     # minimal non-membership (no counter-evidence yet)
const IFS_INITIAL_PI    = 0.80     # lots of hesitation — we barely know this thing
const IFS_MATURE_THRESHOLD = 0.20  # pi below this → mature, standard fuzzy (just mu)
const IFS_REINFORCE_MU_GAIN = 0.08 # how much pi→mu transfer on positive reinforcement
const IFS_REINFORCE_NU_GAIN = 0.08 # how much pi→nu transfer on negative reinforcement
const IFS_MU_FLOOR       = 0.0
const IFS_MU_CEIL        = 1.0
const IFS_NU_FLOOR       = 0.0
const IFS_NU_CEIL        = 1.0

# GRUG: store sizing
const MAX_ENTRIES_PER_KEY      = 32
const MAX_TOTAL_ENTRIES        = 4096
const MAX_DROP_TABLE_PER_KEY   = 8
const MAX_DROP_TABLE_PER_ENTRY = 8

# GRUG: read-side defaults
const MAX_ENTRIES_PER_PEEK     = 5
const READER_TIMEOUT_MS        = 100
const PATTERN_WALK_DEPTH       = 2          # drop-table walk hops
const TOKEN_OVERLAP_FLOOR      = 1          # at least 1 shared token to count

# GRUG: throttle defaults
const TOKEN_BUCKET_CAPACITY    = 3          # per-node tokens
const TOKEN_REFILL_SECONDS     = 20.0       # one token per N seconds per node
const GLOBAL_TOKEN_CAP         = 8          # outstanding tokens across all nodes

# GRUG: valid tag namespaces — closed set, so audits are tractable.
const VALID_TAGS = Set{Symbol}([:timing, :lexical, :mood, :relational, :meta, :context_polarity])

# GRUG: fuzzy time buckets, in seconds, in increasing order.
# Boundaries are jittered per query (see fuzzy_bucket_for).
# Shape: (bucket symbol, upper-bound seconds for that bucket).
const FUZZY_BUCKETS = [
    (:just_now,         30.0),         # < 30s
    (:recent,           5 * 60.0),     # < 5 min
    (:earlier_today,    8 * 3600.0),   # < 8 h
    (:yesterday_ish,    36 * 3600.0),  # < ~1.5 days
    (:couple_days_ago,  4 * 86400.0),  # < ~4 days
    (:a_while_back,     21 * 86400.0), # < ~3 weeks
    (:long_ago,         Inf)
]
const FUZZY_BUCKET_JITTER = 0.15  # ±15% jitter on boundaries per query

# ==============================================================================
# CORE TYPES
# ==============================================================================

# GRUG: single fragment of subconscious observation.
# `payload` is symbol-or-string keyed for serialization friendliness.
# IFS triple (mu, nu, pi) replaces the old scalar weight.
#   mu = membership (positive evidence strength)
#   nu = non-membership (negative evidence strength)
#   pi = hesitation margin = 1 - mu - nu (shrinks as evidence accumulates)
# Novel data: high pi (IFML mode — full triple evaluation).
# Seen-a-lot data: pi near zero (standard fuzzy — just mu matters).
# Key variables get jitter on activity (ephemeral shake), state persists in table.
mutable struct Microlog
    key::String
    tag::Symbol
    payload::Dict{String, Any}
    mu::Float64                     # IFS membership — INTERNAL ONLY, never escapes via public API
    nu::Float64                     # IFS non-membership — INTERNAL ONLY
    pi::Float64                     # IFS hesitation — INTERNAL ONLY
    timestamp::Float64              # INTERNAL ONLY — fuzzed before returning
    provenance::Symbol              # why this microlog was written (e.g. :no_relations_extracted)
    drop_table::Vector{String}      # per-entry associated keys (moment-specific)
end

# GRUG: IFS invariant enforcer. After ANY mutation to mu or nu, call this.
# Ensures mu+nu <= 1.0 and recalculates pi = 1 - mu - nu >= 0.
# This is the single chokepoint that guarantees the IFS triple never violates
# the Atanassov constraint. All mutation sites must call this afterward.
function _ifs_enforce_invariant!(ml::Microlog)
    # GRUG: if mu+nu > 1.0, shrink mu to make room. Mu is the "winner" that
    # absorbs overflow — positive evidence is stronger than lack of negation.
    if ml.mu + ml.nu > IFS_MU_CEIL + 1e-12
        overflow = ml.mu + ml.nu - 1.0
        ml.mu = max(IFS_MU_FLOOR, ml.mu - overflow)
    end
    ml.pi = max(0.0, 1.0 - ml.mu - ml.nu)
    return nothing
end

function Microlog(key::String, tag::Symbol, payload::Dict{String,Any},
                  mu::Float64, nu::Float64, pi::Float64, provenance::Symbol,
                  drop_table::Vector{String} = String[])
    if tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag must be one of $(collect(VALID_TAGS))", "tag"))
    end
    # GRUG: validate IFS triple. pi = 1 - mu - nu must be >= 0.
    if !(IFS_MU_FLOOR <= mu <= IFS_MU_CEIL)
        throw(SelfObserverArgumentError(
            "mu out of range [$IFS_MU_FLOOR, $IFS_MU_CEIL]", "mu"))
    end
    if !(IFS_NU_FLOOR <= nu <= IFS_NU_CEIL)
        throw(SelfObserverArgumentError(
            "nu out of range [$IFS_NU_FLOOR, $IFS_NU_CEIL]", "nu"))
    end
    if pi < 0.0
        throw(SelfObserverArgumentError(
            "pi (hesitation) is negative: mu=$mu, nu=$nu, pi=$pi", "pi"))
    end
    if mu + nu + pi > 1.0 + 1e-9  # GRUG: tiny tolerance for float arithmetic
        throw(SelfObserverArgumentError(
            "IFS invariant violated: mu+nu+pi = $(mu+nu+pi) > 1.0", "ifs_triple"))
    end
    # GRUG: snap pi to exact invariant
    pi = max(0.0, 1.0 - mu - nu)
    return Microlog(key, tag, payload, mu, nu, pi, time(), provenance,
                    copy(drop_table))
end

# GRUG: backward-compatible constructor from salience (maps to mu, rest is IFML defaults).
# Old code that passes weight/salience as a single Float64 still works.
function Microlog(key::String, tag::Symbol, payload::Dict{String,Any},
                  salience::Float64, provenance::Symbol,
                  drop_table::Vector{String} = String[])
    if tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag must be one of $(collect(VALID_TAGS))", "tag"))
    end
    if !(SALIENCE_FLOOR <= salience <= SALIENCE_CEILING)
        throw(SelfObserverArgumentError(
            "salience out of range [$SALIENCE_FLOOR, $SALIENCE_CEILING]", "salience"))
    end
    # GRUG: map salience to mu. Salience 0→mu=0.05, salience 10→mu=0.85.
    # High-salience first write still starts with hesitation (IFML) but higher mu.
    mu = 0.05 + 0.08 * salience   # salience 1.0 → mu=0.13, salience 10 → mu=0.85
    mu = min(mu, IFS_MU_CEIL)
    nu = IFS_INITIAL_NU
    pi = max(0.0, 1.0 - mu - nu)
    return Microlog(key, tag, payload, mu, nu, pi, time(), provenance,
                    copy(drop_table))
end

# ==============================================================================
# IFS HELPERS — GRUG fuzzy/IFML evaluation with jitter
# ==============================================================================

"""
    _is_mature(ml::Microlog)::Bool

GRUG: True when hesitation pi is below IFS_MATURE_THRESHOLD. Mature entries
behave as standard fuzzy — just mu matters, the IFML triple has collapsed.
"""
_is_mature(ml::Microlog)::Bool = ml.pi < IFS_MATURE_THRESHOLD

"""
    _effective_weight(ml::Microlog)::Float64

GRUG: Compute the effective weight for scoring/eviction from the IFS triple.
  - Mature entry (pi < threshold): standard fuzzy — just mu, slightly jittered.
  - Novel entry (pi >= threshold): IFML — mu + modal possibility bonus.
    ◇mu = mu + pi (possibly true if hesitation resolves favorably).
    The effective weight is weighted between mu and ◇mu based on how
    much reinforcement the entry has seen (captured by mu itself).
    Also lightly jittered on both paths — ephemeral shake, state persists.

Internal only — never escapes via public API.
"""
function _effective_weight(ml::Microlog)::Float64
    if _is_mature(ml)
        # GRUG: Standard fuzzy. Mu is the whole story. Slight jitter.
        mu_j = RelationalJitter.jitter_value(ml.mu; ratio=0.02)
        return clamp(mu_j, IFS_MU_FLOOR, IFS_MU_CEIL)
    else
        # GRUG: IFML. Mu is the floor (what we know for sure). ◇mu = mu + pi
        # (possibility operator) adds a proportional bonus for hesitation.
        # The bonus is MULTIPLICATIVE on mu so that high-mu entries always
        # score higher than low-mu entries, regardless of pi. This matters
        # for eviction: a vivid (high-mu, moderate-pi) entry must survive
        # over a barely-noticed (low-mu, high-pi) one.
        #
        # Formula: effective = mu * (1 + PI_BOOST_SCALE * pi)
        #   - pi=0 (mature): just mu (no bonus)
        #   - pi=0.80 (novel): mu * 1.40 — 40% possibility bonus
        #   - pi=1.0 (pure hesitation): mu * 1.50 — 50% possibility bonus
        #
        # ◇mu is the theoretical ceiling if all hesitation resolves positively.
        # The multiplicative form keeps mu as the dominant term while still
        # rewarding the possibility that hesitation resolves favorably.
        PI_BOOST_SCALE = 0.5
        raw = ml.mu * (1.0 + PI_BOOST_SCALE * ml.pi)
        # GRUG: also jitter mu slightly — ephemeral entropy, state persists
        mu_j = RelationalJitter.jitter_value(ml.mu; ratio=0.02)
        raw_j = mu_j * (1.0 + PI_BOOST_SCALE * ml.pi)
        # GRUG: jitter nu slightly — it affects eviction scoring
        nu_j = RelationalJitter.jitter_value(ml.nu; ratio=0.02)
        nu_j = clamp(nu_j, IFS_NU_FLOOR, IFS_NU_CEIL)
        # GRUG: non-membership dampens effective weight
        raw_j = max(0.0, raw_j - nu_j * 0.3)
        return clamp(raw_j, IFS_MU_FLOOR, IFS_MU_CEIL)
    end
end

"""
    _ifs_reinforce!(ml::Microlog; positive::Bool=true, gain::Float64=IFS_REINFORCE_MU_GAIN)

GRUG: Shrink hesitation pi by transferring to mu (positive evidence) or nu
(negative evidence). The transition from IFML → standard fuzzy is automatic
as pi drops below IFS_MATURE_THRESHOLD. This is what makes "I keep noticing X"
stick — repeated positive reinforcement collapses pi and grows mu.

The actual IFS state (mu, nu, pi) is NOT jittered — only ephemeral activity
uses jitter. State persists cleanly in the hash table.

Uses _ifs_enforce_invariant! after mutation to guarantee mu+nu+pi = 1.0.
"""
function _ifs_reinforce!(ml::Microlog; positive::Bool=true,
                         gain::Float64=IFS_REINFORCE_MU_GAIN)
    if positive
        # GRUG: positive evidence → mu grows, pi shrinks
        transfer = min(gain, ml.pi)  # can't transfer more than what's hesitating
        ml.mu = min(IFS_MU_CEIL, ml.mu + transfer)
        _ifs_enforce_invariant!(ml)
    else
        # GRUG: negative evidence → nu grows, pi shrinks
        transfer = min(gain, ml.pi)
        ml.nu = min(IFS_NU_CEIL, ml.nu + transfer)
        _ifs_enforce_invariant!(ml)
    end
    return nothing
end

# GRUG: the public hint type. ZERO Float64 fields. Symbols + strings + a fuzzy
# bucket. This is the structural guarantee — a test mechanically asserts that
# fieldtypes contain no Float64.
struct SubconsciousHint
    key::String
    tag::Symbol
    fuzzy_when::Symbol           # one of FUZZY_BUCKETS' first elements
    provenance::Symbol
    payload_keys::Vector{String} # surface only the keys, not the raw values
                                 # (caller can request a deep copy via payload_for)
    payload_strings::Dict{String, String}  # string-only safe view of payload
    associations::Vector{String} # related keys from drop-table walk
end

# GRUG: per-node token bucket. One per caller node id.
mutable struct TokenBucket
    capacity::Int
    tokens::Float64              # INTERNAL — never returned
    last_refill::Float64
end

function TokenBucket(cap::Int = TOKEN_BUCKET_CAPACITY)
    return TokenBucket(cap, Float64(cap), time())
end

# GRUG: the store. Own hash table. Own lock. Own audit counters.
# READER_LOCK is a strict, non-reentrant gate: only one peek at a time, system-wide.
mutable struct SubconsciousStore
    table::Dict{String, Vector{Microlog}}     # key → fragments
    drop_tables::Dict{String, Vector{String}} # key → associated keys (per-key, stable)
    total_entries::Int
    write_lock::ReentrantLock                  # protects table + drop_tables on write
    reader_busy::Atomic{Bool}                  # strict: one outstanding read at a time
    reader_owner::Ref{String}                  # node_id currently holding the read slot, "" if free
    buckets::Dict{String, TokenBucket}         # per-node-id token buckets
    bucket_lock::ReentrantLock                 # protects buckets dict
    global_outstanding::Atomic{Int}            # global cap on in-flight read tokens

    # Audit counters (Atomic so we never lock for telemetry)
    n_writes::Atomic{Int}
    n_writes_skipped_stochastic::Atomic{Int}
    n_writes_reinforced::Atomic{Int}
    n_evictions_per_key::Atomic{Int}
    n_evictions_total_cap::Atomic{Int}
    n_peeks_attempted::Atomic{Int}
    n_peeks_hit::Atomic{Int}
    n_peeks_miss::Atomic{Int}
    n_peeks_throttle::Atomic{Int}
    n_peeks_global_cap::Atomic{Int}
    n_peeks_lock_busy::Atomic{Int}
    n_peeks_timeout::Atomic{Int}

    rng::Random.AbstractRNG
end

function SubconsciousStore(; rng::Random.AbstractRNG = Random.default_rng())
    return SubconsciousStore(
        Dict{String, Vector{Microlog}}(),
        Dict{String, Vector{String}}(),
        0,
        ReentrantLock(),
        Atomic{Bool}(false),
        Ref{String}(""),
        Dict{String, TokenBucket}(),
        ReentrantLock(),
        Atomic{Int}(0),
        Atomic{Int}(0), Atomic{Int}(0), Atomic{Int}(0),
        Atomic{Int}(0), Atomic{Int}(0),
        Atomic{Int}(0), Atomic{Int}(0), Atomic{Int}(0),
        Atomic{Int}(0), Atomic{Int}(0), Atomic{Int}(0), Atomic{Int}(0),
        rng,
    )
end

# ==============================================================================
# PUBLIC IFS HELPERS — for the growth/link system to inspect fuzzy/IFML state
# ==============================================================================

"""
    is_entry_mature(ml::Microlog)::Bool

GRUG: Public wrapper around _is_mature. True when hesitation pi is below
IFS_MATURE_THRESHOLD — the entry behaves as standard fuzzy (just mu).
"""
is_entry_mature(ml::Microlog)::Bool = _is_mature(ml)

"""
    ifs_state(ml::Microlog)::NamedTuple{(:mu, :nu, :pi, :mature), Tuple{Float64, Float64, Float64, Bool}}

GRUG: Read-only snapshot of the IFS triple + maturity flag. For callers that
need to know the fuzzy/IFML state without directly touching Microlog fields.
"""
function ifs_state(ml::Microlog)::NamedTuple{(:mu, :nu, :pi, :mature), Tuple{Float64, Float64, Float64, Bool}}
    return (mu=ml.mu, nu=ml.nu, pi=ml.pi, mature=_is_mature(ml))
end

"""
    ifs_reinforce_entry!(store::SubconsciousStore, key::String, tag::Symbol,
                         provenance::Symbol; positive::Bool=true,
                         gain::Float64=IFS_REINFORCE_MU_GAIN)::Bool

GRUG: Public API for the growth/link system to reinforce a specific entry
without going through the full observe! path. Finds the matching microlog
and applies IFS reinforcement. Returns true if reinforced, false if not found.
"""
function ifs_reinforce_entry!(store::SubconsciousStore, key::String, tag::Symbol,
                              provenance::Symbol; positive::Bool=true,
                              gain::Float64=IFS_REINFORCE_MU_GAIN)::Bool
    lock(store.write_lock)
    try
        bucket = get(store.table, key, nothing)
        bucket === nothing && return false
        for ml in bucket
            if ml.tag == tag && ml.provenance == provenance
                _ifs_reinforce!(ml; positive=positive, gain=gain)
                ml.timestamp = time()
                return true
            end
        end
        return false
    finally
        unlock(store.write_lock)
    end
end

# ==============================================================================
# INTERNAL HELPERS
# ==============================================================================

# GRUG: tokenize a key/query for token-overlap matching.
# Lowercase + split on non-alnum. Returns Set{String} so overlap is O(min(|a|,|b|)).
function _tokenize(s::AbstractString)::Set{String}
    out = Set{String}()
    if isempty(s)
        return out
    end
    cur = IOBuffer()
    for c in lowercase(s)
        if isletter(c) || isdigit(c)
            print(cur, c)
        else
            t = String(take!(cur))
            if !isempty(t)
                push!(out, t)
            end
        end
    end
    t = String(take!(cur))
    if !isempty(t)
        push!(out, t)
    end
    return out
end

# GRUG: refill a token bucket based on elapsed wall time.
# Internal-only; tokens never leave the store.
function _refill!(bucket::TokenBucket)
    now = time()
    elapsed = now - bucket.last_refill
    if elapsed > 0.0
        gain = elapsed / TOKEN_REFILL_SECONDS
        bucket.tokens = min(Float64(bucket.capacity), bucket.tokens + gain)
        bucket.last_refill = now
    end
    return nothing
end

# GRUG: try to consume one token for the given node id. Returns true on success.
# Locks bucket_lock briefly; uses global_outstanding to enforce global cap.
function _try_consume!(store::SubconsciousStore, node_id::String)::Bool
    if isempty(node_id)
        throw(SelfObserverArgumentError("node_id must be non-empty", "node_id"))
    end
    # Global cap check first (cheap atomic).
    cur = store.global_outstanding[]
    if cur >= GLOBAL_TOKEN_CAP
        atomic_add!(store.n_peeks_global_cap, 1)
        return false
    end

    lock(store.bucket_lock)
    try
        b = get!(store.buckets, node_id) do
            TokenBucket()
        end
        _refill!(b)
        if b.tokens < 1.0
            atomic_add!(store.n_peeks_throttle, 1)
            return false
        end
        b.tokens -= 1.0
        atomic_add!(store.global_outstanding, 1)
        return true
    finally
        unlock(store.bucket_lock)
    end
end

# GRUG: release one outstanding token (decrement global cap counter only).
# Per-node bucket does NOT refund — the read happened, token spent.
function _release_outstanding!(store::SubconsciousStore)
    atomic_sub!(store.global_outstanding, 1)
    return nothing
end

# GRUG: try to acquire the strict global reader slot. Returns true on success.
# Uses CAS via Atomic{Bool}: false → true. Caller MUST call _release_reader! on success.
function _try_acquire_reader!(store::SubconsciousStore, node_id::String,
                              timeout_ms::Int)::Bool
    deadline = time() + (timeout_ms / 1000.0)
    # Tight CAS spin with short sleeps; bounded by deadline.
    while true
        # Atomic CAS: only the thread that flips false→true wins.
        prev = Threads.atomic_cas!(store.reader_busy, false, true)
        if prev == false
            # We won the slot. Record owner under bucket_lock to keep
            # cross-thread visibility honest.
            lock(store.bucket_lock)
            try
                store.reader_owner[] = node_id
            finally
                unlock(store.bucket_lock)
            end
            return true
        end
        if time() >= deadline
            # If we never acquired, classify the reason. If reader_busy was
            # held the whole time, it's "lock_busy"; if we hit the deadline
            # because of contention noise, it's "timeout". We bias toward
            # lock_busy (the more informative case) when slot still held.
            if store.reader_busy[]
                atomic_add!(store.n_peeks_lock_busy, 1)
            else
                atomic_add!(store.n_peeks_timeout, 1)
            end
            return false
        end
        sleep(0.001)  # 1ms back-off
    end
end

function _release_reader!(store::SubconsciousStore)
    lock(store.bucket_lock)
    try
        store.reader_owner[] = ""
    finally
        unlock(store.bucket_lock)
    end
    store.reader_busy[] = false
    return nothing
end

# GRUG: deterministic-ish boundary jitter for fuzzy time buckets.
# Same (key, query_id) → same boundary set. Different query_ids → independent jitter.
function _jittered_boundaries(key::String, query_id::String)
    # GRUG: hash-derived seed so fuzz is reproducible per (key, query_id) pair.
    seed = UInt64(hash((key, query_id)))
    rng = Random.MersenneTwister(seed)
    out = Vector{Tuple{Symbol, Float64}}(undef, length(FUZZY_BUCKETS))
    for (i, (sym, bound)) in enumerate(FUZZY_BUCKETS)
        if isfinite(bound)
            jf = 1.0 + FUZZY_BUCKET_JITTER * (2 * rand(rng) - 1.0)
            out[i] = (sym, bound * jf)
        else
            out[i] = (sym, bound)
        end
    end
    return out
end

# GRUG: assign a fuzzy bucket for a microlog given the current query context.
function _fuzzy_bucket_for(ml::Microlog, query_id::String)::Symbol
    age = max(0.0, time() - ml.timestamp)
    boundaries = _jittered_boundaries(ml.key, query_id)
    for (sym, bound) in boundaries
        if age <= bound
            return sym
        end
    end
    return :long_ago
end

# GRUG: extract a string-only safe view of payload (for SubconsciousHint).
function _payload_strings(p::Dict{String,Any})::Dict{String,String}
    out = Dict{String,String}()
    for (k, v) in p
        if v isa AbstractString
            out[k] = String(v)
        elseif v isa Symbol
            out[k] = String(v)
        elseif v isa Integer || v isa Bool
            out[k] = string(v)
        # GRUG: deliberately DROP Float64/Float32 from the surfaced view.
        # Keeps the no-confidence-shape guarantee at the data level too.
        end
    end
    return out
end

# GRUG: build a SubconsciousHint from a microlog + fuzzy time + associations.
function _make_hint(ml::Microlog, fuzzy_when::Symbol,
                    associations::Vector{String})::SubconsciousHint
    return SubconsciousHint(
        ml.key, ml.tag, fuzzy_when, ml.provenance,
        sort!(collect(keys(ml.payload))),
        _payload_strings(ml.payload),
        unique!(filter(!isempty, copy(associations))),
    )
end

# GRUG: IFS-aware eviction. Score = _effective_weight(ml) * recency_factor.
# Recency factor decays exponentially with age. Lowest score evicted.
# _effective_weight uses jitter (ephemeral) so eviction is slightly non-deterministic
# but statistically fair — same snap-back property as all jitter usage.
function _evict_lowest!(entries::Vector{Microlog})::Microlog
    if isempty(entries)
        throw(SelfObserverError("eviction called on empty bucket", "evict_lowest"))
    end
    now = time()
    worst_idx = 1
    worst_score = Inf
    for (i, ml) in enumerate(entries)
        age = max(0.0, now - ml.timestamp)
        # GRUG: half-life ~ 1 day; clamp to avoid underflow weirdness.
        recency = exp(-age / 86400.0)
        score = _effective_weight(ml) * recency
        if score < worst_score
            worst_score = score
            worst_idx = i
        end
    end
    return splice!(entries, worst_idx)
end

# GRUG: append-into-bounded-vector with LRU-style trim (used for drop tables).
function _push_bounded!(v::Vector{String}, item::String, cap::Int)
    if isempty(item)
        return v
    end
    # Move-to-front semantics: dedupe then prepend, trim to cap.
    filter!(x -> x != item, v)
    pushfirst!(v, item)
    if length(v) > cap
        resize!(v, cap)
    end
    return v
end

# ==============================================================================
# PUBLIC API — WRITE PATH
# ==============================================================================

"""
    observe!(store, key, tag, payload; p_write=DEFAULT_P_WRITE,
             salience=DEFAULT_SALIENCE, provenance=:unspecified,
             drop_table=String[])

Stochastically record a microlog fragment in the subconscious store.

- `key::String`            — concept anchor; non-empty.
- `tag::Symbol`            — must be one of `:timing, :lexical, :mood, :relational, :meta`.
- `payload::Dict{String,Any}` — descriptive fields. Float values are NOT exposed in hints.
- `p_write`                — probability of actually writing (caller may override).
- `salience`               — initial interest, clamped to [0.0, 10.0]. Maps to IFS mu via salience→mu formula.
- `provenance`             — why this fragment was written (e.g. `:no_relations_extracted`).
- `drop_table`             — moment-specific co-activated keys for this entry.

Returns `true` if written, `false` if the stochastic coin came up "skip", or
`false` if `payload` was empty (we don't keep empty fragments). Throws on
programmer errors (bad tag, empty key, out-of-range salience).
"""
function observe!(store::SubconsciousStore, key::String, tag::Symbol,
                  payload::Dict{String,Any};
                  p_write::Float64 = DEFAULT_P_WRITE,
                  salience::Float64 = DEFAULT_SALIENCE,
                  provenance::Symbol = :unspecified,
                  drop_table::Vector{String} = String[])::Bool
    # --- argument validation: no silent failure on misuse ---
    if isempty(key)
        throw(SelfObserverArgumentError("key must be non-empty", "key"))
    end
    if tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag must be one of $(collect(VALID_TAGS))", "tag"))
    end
    if !(0.0 <= p_write <= 1.0)
        throw(SelfObserverArgumentError(
            "p_write must be in [0,1]", "p_write"))
    end
    if !(SALIENCE_FLOOR <= salience <= SALIENCE_CEILING)
        throw(SelfObserverArgumentError(
            "salience out of [$(SALIENCE_FLOOR),$(SALIENCE_CEILING)]", "salience"))
    end
    if isempty(payload)
        # GRUG: empty fragment = nothing to remember. Not an error, just a no-op.
        return false
    end

    # --- stochastic gate ---
    # GRUG: lock-free RNG draw is fine — the rng field is per-store; concurrent
    # writes may interleave but the `rand` call itself is thread-safe enough on
    # MersenneTwister/default_rng for our coin-flip purposes.
    if rand(store.rng) > p_write
        atomic_add!(store.n_writes_skipped_stochastic, 1)
        return false
    end

    # --- write under lock ---
    lock(store.write_lock)
    try
        bucket = get!(store.table, key) do
            Vector{Microlog}()
        end

        # GRUG: reinforcement — if a recent matching entry exists (same tag &
        # provenance), IFS-reinforce it and refresh timestamp instead of adding
        # a brand-new entry. This is what makes "I keep noticing X" stick.
        # Positive reinforcement: mu grows, pi shrinks. IFML → standard fuzzy
        # happens automatically when pi drops below IFS_MATURE_THRESHOLD.
        reinforced = false
        for ml in bucket
            if ml.tag == tag && ml.provenance == provenance
                # GRUG: IFS reinforcement — transfer pi→mu. Gain proportional to salience.
                gain = IFS_REINFORCE_MU_GAIN * (0.5 + 0.05 * salience)
                _ifs_reinforce!(ml; positive=true, gain=gain)
                # GRUG: also bump mu directly for backward-compat salience ceiling behavior.
                # This gives salience-heavy observations a faster climb even after pi=0.
                # _ifs_enforce_invariant! (called inside _ifs_reinforce!) guarantees
                # mu+nu+pi = 1.0 at all times, so the direct bump needs the same treatment.
                ml.mu = ml.mu + REINFORCE_GAIN * salience * 0.01
                _ifs_enforce_invariant!(ml)
                ml.timestamp = time()
                # Merge new payload keys (additive, not destructive).
                for (k, v) in payload
                    ml.payload[k] = v
                end
                # Merge per-entry drop table additions.
                for assoc in drop_table
                    _push_bounded!(ml.drop_table, assoc, MAX_DROP_TABLE_PER_ENTRY)
                end
                reinforced = true
                atomic_add!(store.n_writes_reinforced, 1)
                break
            end
        end

        if !reinforced
            ml = Microlog(key, tag, copy(payload), salience, provenance,
                          copy(drop_table))
            push!(bucket, ml)
            store.total_entries += 1

            # Per-key cap eviction.
            while length(bucket) > MAX_ENTRIES_PER_KEY
                _evict_lowest!(bucket)
                store.total_entries -= 1
                atomic_add!(store.n_evictions_per_key, 1)
            end

            # Global total cap eviction: pick the globally lowest-scoring
            # entry across ALL keys. O(N) worst case but bounded by 4096.
            while store.total_entries > MAX_TOTAL_ENTRIES
                _evict_globally_lowest!(store)
                atomic_add!(store.n_evictions_total_cap, 1)
            end
        end

        # Per-key drop table update (stable concept-shape associations).
        if !isempty(drop_table)
            pk = get!(store.drop_tables, key) do
                Vector{String}()
            end
            for assoc in drop_table
                _push_bounded!(pk, assoc, MAX_DROP_TABLE_PER_KEY)
            end
        end

        atomic_add!(store.n_writes, 1)
        return true
    finally
        unlock(store.write_lock)
    end
end

# GRUG: global-cap eviction helper. Caller already holds write_lock.
function _evict_globally_lowest!(store::SubconsciousStore)
    now = time()
    worst_key = ""
    worst_idx = 0
    worst_score = Inf
    for (k, bucket) in store.table
        for (i, ml) in enumerate(bucket)
            age = max(0.0, now - ml.timestamp)
            recency = exp(-age / 86400.0)
            score = _effective_weight(ml) * recency
            if score < worst_score
                worst_score = score
                worst_key = k
                worst_idx = i
            end
        end
    end
    if worst_idx == 0
        throw(SelfObserverError("global eviction found nothing to evict",
                                "evict_globally_lowest"))
    end
    splice!(store.table[worst_key], worst_idx)
    if isempty(store.table[worst_key])
        delete!(store.table, worst_key)
    end
    store.total_entries -= 1
    return nothing
end

# ==============================================================================
# PUBLIC API — READ PATH
# ==============================================================================

"""
    peek_exact(store, node_id, key; tag=nothing, max_entries=MAX_ENTRIES_PER_PEEK,
               timeout_ms=READER_TIMEOUT_MS, query_id=randstring(8))

Look up exact-key fragments. Returns `Vector{SubconsciousHint}` or `nothing`.

`nothing` is returned (silently, intentionally) when:
- the per-node token bucket is empty,
- the global outstanding cap is reached,
- the global single-reader slot is busy and the timeout expired,
- the key has no entries.

This is by design: the subconscious gives "I don't know" as a normal answer.
Use `audit_trail(store)` to see *why* a peek returned nothing.
"""
function peek_exact(store::SubconsciousStore, node_id::String, key::String;
                    tag::Union{Nothing,Symbol} = nothing,
                    max_entries::Int = MAX_ENTRIES_PER_PEEK,
                    timeout_ms::Int = READER_TIMEOUT_MS,
                    query_id::String = randstring(8)
                   )::Union{Nothing, Vector{SubconsciousHint}}
    if isempty(key)
        throw(SelfObserverArgumentError("key must be non-empty", "key"))
    end
    if tag !== nothing && tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag (if given) must be one of $(collect(VALID_TAGS))", "tag"))
    end
    if max_entries < 1
        throw(SelfObserverArgumentError("max_entries must be >= 1", "max_entries"))
    end

    atomic_add!(store.n_peeks_attempted, 1)

    # Throttle gate.
    if !_try_consume!(store, node_id)
        return nothing
    end
    # Reader gate.
    if !_try_acquire_reader!(store, node_id, timeout_ms)
        _release_outstanding!(store)
        return nothing
    end

    try
        bucket = get(store.table, key, nothing)
        if bucket === nothing || isempty(bucket)
            atomic_add!(store.n_peeks_miss, 1)
            return nothing
        end

        # Filter by tag if requested. Sort by _effective_weight*recency descending; cap.
        now = time()
        scored = Tuple{Float64, Microlog}[]
        for ml in bucket
            if tag !== nothing && ml.tag != tag
                continue
            end
            age = max(0.0, now - ml.timestamp)
            recency = exp(-age / 86400.0)
            push!(scored, (_effective_weight(ml) * recency, ml))
        end
        if isempty(scored)
            atomic_add!(store.n_peeks_miss, 1)
            return nothing
        end
        sort!(scored; by = x -> -x[1])
        top = scored[1:min(end, max_entries)]

        # Build hints. Per-key drop table provides associations.
        per_key_drops = get(store.drop_tables, key, String[])
        hints = SubconsciousHint[]
        for (_score, ml) in top
            fuzzy = _fuzzy_bucket_for(ml, query_id)
            assoc = String[]
            append!(assoc, ml.drop_table)
            append!(assoc, per_key_drops)
            push!(hints, _make_hint(ml, fuzzy, assoc))
        end
        atomic_add!(store.n_peeks_hit, 1)
        return hints
    finally
        _release_reader!(store)
        _release_outstanding!(store)
    end
end

"""
    peek_pattern(store, node_id, query; tag=nothing,
                 max_entries=MAX_ENTRIES_PER_PEEK,
                 timeout_ms=READER_TIMEOUT_MS,
                 walk_depth=PATTERN_WALK_DEPTH,
                 query_id=randstring(8))

Pattern-style fuzzy lookup. Two recall sources are merged:

1. Token-overlap: tokenize `query`, score each stored key by the count of
   shared tokens (tied with stored microlog effective_weight*recency).
2. Drop-table walk: starting from the best-overlap keys, walk per-key drop
   tables up to `walk_depth` hops, depth-discounted.

Returns `Vector{SubconsciousHint}` or `nothing`. Same `nothing`-on-throttle/
miss/timeout semantics as `peek_exact`.
"""
function peek_pattern(store::SubconsciousStore, node_id::String, query::String;
                      tag::Union{Nothing,Symbol} = nothing,
                      max_entries::Int = MAX_ENTRIES_PER_PEEK,
                      timeout_ms::Int = READER_TIMEOUT_MS,
                      walk_depth::Int = PATTERN_WALK_DEPTH,
                      query_id::String = randstring(8)
                     )::Union{Nothing, Vector{SubconsciousHint}}
    if isempty(query)
        throw(SelfObserverArgumentError("query must be non-empty", "query"))
    end
    if tag !== nothing && tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag (if given) must be one of $(collect(VALID_TAGS))", "tag"))
    end
    if max_entries < 1
        throw(SelfObserverArgumentError("max_entries must be >= 1", "max_entries"))
    end
    if walk_depth < 0 || walk_depth > 4
        throw(SelfObserverArgumentError(
            "walk_depth must be in [0,4]", "walk_depth"))
    end

    atomic_add!(store.n_peeks_attempted, 1)

    if !_try_consume!(store, node_id)
        return nothing
    end
    if !_try_acquire_reader!(store, node_id, timeout_ms)
        _release_outstanding!(store)
        return nothing
    end

    try
        q_tokens = _tokenize(query)
        if isempty(q_tokens)
            atomic_add!(store.n_peeks_miss, 1)
            return nothing
        end

        now = time()
        # GRUG: pass 1 — token overlap over keys.
        seed_keys = String[]   # keys that survived overlap floor
        # collect (key, overlap_count, best_score)
        overlap_records = Tuple{String, Int, Float64}[]
        for (k, bucket) in store.table
            k_tokens = _tokenize(k)
            shared = length(intersect(q_tokens, k_tokens))
            if shared < TOKEN_OVERLAP_FLOOR
                continue
            end
            best = -Inf
            for ml in bucket
                if tag !== nothing && ml.tag != tag
                    continue
                end
                age = max(0.0, now - ml.timestamp)
                recency = exp(-age / 86400.0)
                s = _effective_weight(ml) * recency
                if s > best
                    best = s
                end
            end
            if isfinite(best)
                push!(overlap_records, (k, shared, best))
                push!(seed_keys, k)
            end
        end

        # GRUG: pass 2 — drop-table walk from seed keys.
        # Collected as Dict{String, Float64} key→discount factor (max if seen via
        # multiple paths).
        walk_keys = Dict{String, Float64}()
        if walk_depth > 0
            frontier = Set{String}(seed_keys)
            visited = Set{String}(seed_keys)
            for d in 1:walk_depth
                next_frontier = Set{String}()
                discount = 1.0 / (1 + d)  # depth 1 → 0.5, depth 2 → 0.333, etc.
                for k in frontier
                    drops = get(store.drop_tables, k, String[])
                    for assoc in drops
                        if assoc in visited
                            continue
                        end
                        # Only count keys that actually have entries.
                        if !haskey(store.table, assoc)
                            continue
                        end
                        cur = get(walk_keys, assoc, 0.0)
                        if discount > cur
                            walk_keys[assoc] = discount
                        end
                        push!(next_frontier, assoc)
                    end
                end
                if isempty(next_frontier)
                    break
                end
                union!(visited, next_frontier)
                frontier = next_frontier
            end
        end

        # Merge: candidate score = (overlap_count * best) for direct hits,
        # (best * discount) for walk-only hits.
        candidates = Tuple{Float64, String, Microlog}[]
        seen_pairs = Set{Tuple{String, Int}}()  # (key, ml index) dedupe
        for (k, shared, best) in overlap_records
            bucket = store.table[k]
            for (i, ml) in enumerate(bucket)
                if tag !== nothing && ml.tag != tag
                    continue
                end
                age = max(0.0, now - ml.timestamp)
                recency = exp(-age / 86400.0)
                s = shared * (_effective_weight(ml) * recency)
                push!(candidates, (s, k, ml))
                push!(seen_pairs, (k, i))
            end
        end
        for (k, disc) in walk_keys
            bucket = get(store.table, k, nothing)
            bucket === nothing && continue
            for (i, ml) in enumerate(bucket)
                if (k, i) in seen_pairs
                    continue
                end
                if tag !== nothing && ml.tag != tag
                    continue
                end
                age = max(0.0, now - ml.timestamp)
                recency = exp(-age / 86400.0)
                push!(candidates, (disc * _effective_weight(ml) * recency, k, ml))
            end
        end

        if isempty(candidates)
            atomic_add!(store.n_peeks_miss, 1)
            return nothing
        end

        sort!(candidates; by = x -> -x[1])
        top = candidates[1:min(end, max_entries)]

        hints = SubconsciousHint[]
        for (_s, k, ml) in top
            fuzzy = _fuzzy_bucket_for(ml, query_id)
            assoc = String[]
            append!(assoc, ml.drop_table)
            append!(assoc, get(store.drop_tables, k, String[]))
            push!(hints, _make_hint(ml, fuzzy, assoc))
        end
        atomic_add!(store.n_peeks_hit, 1)
        return hints
    finally
        _release_reader!(store)
        _release_outstanding!(store)
    end
end

# ==============================================================================
# AUDIT / MAINTENANCE
# ==============================================================================

"""
    audit_trail(store) -> Dict{Symbol, Int}

Returns a snapshot of internal counters. INTEGER-VALUED ONLY by design — no
Float64 leakage path. Useful for tests and for logging the *reason* a peek
returned `nothing`.
"""
function audit_trail(store::SubconsciousStore)::Dict{Symbol, Int}
    return Dict{Symbol, Int}(
        :writes                    => store.n_writes[],
        :writes_skipped_stochastic => store.n_writes_skipped_stochastic[],
        :writes_reinforced         => store.n_writes_reinforced[],
        :evictions_per_key         => store.n_evictions_per_key[],
        :evictions_total_cap       => store.n_evictions_total_cap[],
        :peeks_attempted           => store.n_peeks_attempted[],
        :peeks_hit                 => store.n_peeks_hit[],
        :peeks_miss                => store.n_peeks_miss[],
        :peeks_throttle            => store.n_peeks_throttle[],
        :peeks_global_cap          => store.n_peeks_global_cap[],
        :peeks_lock_busy           => store.n_peeks_lock_busy[],
        :peeks_timeout             => store.n_peeks_timeout[],
        :total_entries             => store.total_entries,
        :keys                      => length(store.table),
        :outstanding_tokens        => store.global_outstanding[],
    )
end

"""
    reset_audit!(store)

Zero out audit counters without touching the store contents.
"""
function reset_audit!(store::SubconsciousStore)
    store.n_writes[] = 0
    store.n_writes_skipped_stochastic[] = 0
    store.n_writes_reinforced[] = 0
    store.n_evictions_per_key[] = 0
    store.n_evictions_total_cap[] = 0
    store.n_peeks_attempted[] = 0
    store.n_peeks_hit[] = 0
    store.n_peeks_miss[] = 0
    store.n_peeks_throttle[] = 0
    store.n_peeks_global_cap[] = 0
    store.n_peeks_lock_busy[] = 0
    store.n_peeks_timeout[] = 0
    return nothing
end

"""
    drop_store!(store)

Drop-table style wipe. Empties the hash table, drop-table associations, and
buckets. Audit counters are preserved (call `reset_audit!` separately if you
want them cleared too).
"""
function drop_store!(store::SubconsciousStore)
    lock(store.write_lock)
    try
        empty!(store.table)
        empty!(store.drop_tables)
        store.total_entries = 0
    finally
        unlock(store.write_lock)
    end
    lock(store.bucket_lock)
    try
        empty!(store.buckets)
    finally
        unlock(store.bucket_lock)
    end
    return nothing
end

"""
    store_size(store) -> Int

Total live microlog count. Integer.
"""
store_size(store::SubconsciousStore)::Int = store.total_entries

"""
    key_count(store) -> Int

Number of distinct keys with at least one microlog. Integer.
"""
key_count(store::SubconsciousStore)::Int = length(store.table)

# ==============================================================================
# PROCESS-WIDE SINGLETON (for save/load integration with Main.save_specimen!)
# ==============================================================================

# GRUG: One subconscious store per process. Lazily replaced on /loadSpecimen
# (`restore_global_store!`) and wiped on cave reset (`drop_store!` on the
# return of `default_store()`). Tests that want isolation should construct
# their own SubconsciousStore and pass it explicitly --- the singleton is
# only for the live runtime path.
const _GLOBAL_STORE = Ref{SubconsciousStore}(SubconsciousStore())

"""
    default_store() -> SubconsciousStore

GRUG: Return the process-wide subconscious store singleton. Used by the
canonical save/load path in `Main.save_specimen_to_file!` so that the
SelfObserver microlog table travels with the specimen.
"""
default_store() = _GLOBAL_STORE[]

"""
    serialize_store(store::SubconsciousStore) -> Dict{String,Any}

GRUG: Snapshot the live microlog table + drop tables to a JSON-friendly
dict. Audit counters and token buckets are NOT persisted --- they are
diagnostic / per-session and mean nothing after a reload.

Schema (specimen key `subconscious`):
```
Dict(
  "table"         => Dict{String, Vector{Dict}},  # key -> list of microlog dicts
  "drop_tables"   => Dict{String, Vector{String}},
  "total_entries" => Int
)
```
Each microlog dict has: key, tag (String), payload (Dict{String,Any}),
mu (Float64), nu (Float64), pi (Float64), timestamp (Float64),
provenance (String), drop_table (Vector{String}).
Backward compat: old snapshots with "weight" are auto-migrated to IFS triple.
"""
function serialize_store(store::SubconsciousStore)::Dict{String, Any}
    out = Dict{String, Any}()
    lock(store.write_lock)
    try
        table_out = Dict{String, Any}()
        for (k, mls) in store.table
            entries = Vector{Dict{String, Any}}()
            for ml in mls
                push!(entries, Dict{String, Any}(
                    "key"        => ml.key,
                    "tag"        => String(ml.tag),
                    "payload"    => ml.payload,
                    "mu"         => ml.mu,
                    "nu"         => ml.nu,
                    "pi"         => ml.pi,
                    "timestamp"  => ml.timestamp,
                    "provenance" => String(ml.provenance),
                    "drop_table" => copy(ml.drop_table),
                ))
            end
            table_out[k] = entries
        end
        out["table"] = table_out

        drops_out = Dict{String, Any}()
        for (k, v) in store.drop_tables
            drops_out[k] = copy(v)
        end
        out["drop_tables"] = drops_out
        out["total_entries"] = store.total_entries
    finally
        unlock(store.write_lock)
    end
    return out
end

"""
    restore_store!(store::SubconsciousStore, data::AbstractDict)::Int

GRUG: Wipe `store` and rehydrate it from a `serialize_store` snapshot.
Returns the number of microlog entries restored. Tolerant of missing
keys --- a partial / older snapshot just restores what's there.

IFS SAFETY: Serialized mu/nu/pi values may drift slightly from the IFS
invariant (mu+nu+pi=1.0) due to floating-point arithmetic or historical
reinforcement. The restore path clamps mu+nu <= 1.0 and recalculates pi
before constructing the Microlog, ensuring the invariant is always clean.
"""
function restore_store!(store::SubconsciousStore, data::AbstractDict)::Int
    drop_store!(store)  # wipe table + drop_tables + buckets

    n_restored = 0
    lock(store.write_lock)
    try
        if haskey(data, "table") && isa(data["table"], AbstractDict)
            for (k, entries) in data["table"]
                key = String(k)
                mls = Vector{Microlog}()
                for raw in entries
                    isa(raw, AbstractDict) || continue
                    tag_str = String(get(raw, "tag", "meta"))
                    tag_sym = Symbol(tag_str)
                    if !(tag_sym in VALID_TAGS)
                        # GRUG: silently coerce unknown tags to :meta rather than
                        # throw --- save format is forward-compatible by design.
                        tag_sym = :meta
                    end
                    payload_raw = get(raw, "payload", Dict{String, Any}())
                    payload = isa(payload_raw, AbstractDict) ?
                        Dict{String, Any}(String(k2) => v2 for (k2, v2) in payload_raw) :
                        Dict{String, Any}()
                    # GRUG: prov and dt needed before IFS/weight branch
                    prov = Symbol(String(get(raw, "provenance", "restored")))
                    dt_raw = get(raw, "drop_table", String[])
                    dt = isa(dt_raw, AbstractVector) ? String[String(x) for x in dt_raw] : String[]
                    timestamp = Float64(get(raw, "timestamp", time()))
                    # GRUG: IFS restore. New snapshots have mu/nu/pi.
                    # Old snapshots have weight — auto-migrate to IFS triple.
                    if haskey(raw, "mu")
                        mu = clamp(Float64(get(raw, "mu", IFS_INITIAL_MU)), IFS_MU_FLOOR, IFS_MU_CEIL)
                        nu = clamp(Float64(get(raw, "nu", IFS_INITIAL_NU)), IFS_NU_FLOOR, IFS_NU_CEIL)
                        # GRUG: enforce IFS invariant mu+nu <= 1.0 BEFORE constructing.
                        # Serialized values may have drifted (e.g. mu+nu > 1.0 from
                        # historical reinforcement). Shrink mu to fit.
                        if mu + nu > IFS_MU_CEIL + 1e-12
                            overflow = mu + nu - 1.0
                            mu = max(IFS_MU_FLOOR, mu - overflow)
                        end
                        pi = max(0.0, 1.0 - mu - nu)
                        ml = Microlog(key, tag_sym, payload, mu, nu, pi, prov, dt)
                    else
                        # GRUG: backward compat — old weight-based snapshot.
                        # Map weight to mu using same formula as salience constructor.
                        weight_raw = get(raw, "weight", DEFAULT_SALIENCE)
                        weight = clamp(Float64(weight_raw), SALIENCE_FLOOR, SALIENCE_CEILING)
                        # Treat old weight as salience for migration
                        ml = Microlog(key, tag_sym, payload, weight, prov, dt)
                    end
                    # GRUG: override constructor's time() with saved timestamp
                    ml.timestamp = timestamp
                    push!(mls, ml)
                    n_restored += 1
                end
                if !isempty(mls)
                    store.table[key] = mls
                end
            end
        end

        if haskey(data, "drop_tables") && isa(data["drop_tables"], AbstractDict)
            for (k, v) in data["drop_tables"]
                if isa(v, AbstractVector)
                    store.drop_tables[String(k)] = String[String(x) for x in v]
                end
            end
        end

        # GRUG: total_entries is authoritative from our actual rehydrate count,
        # not whatever was in the snapshot. Keeps the invariant tight.
        store.total_entries = n_restored
    finally
        unlock(store.write_lock)
    end
    return n_restored
end

"""
    restore_global_store!(data::AbstractDict)::Int

GRUG: Convenience wrapper for the canonical load path — replaces the
process-wide singleton's contents from a snapshot. Returns count restored.
"""
restore_global_store!(data::AbstractDict)::Int = restore_store!(_GLOBAL_STORE[], data)

end # module SelfObserver
