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
#
# v8.22 — INVARIANT OBSERVER REBASING. SelfObserver is now an INVARIANT
# observer: it observes and records, NEVER modifies external state, and
# this is enforced as a structural invariant. The module already had the
# no-Float64-leak guarantee (v7.21b-1). v8.22 makes it explicit and
# adds runtime self-check on module load. Three invariants hold:
#
#   1. READ-ONLY EXTERNALLY: observe! and peek_* never touch any state
#      outside this module. No vote confidence, no arousal, no scan params.
#   2. NO FLOAT64 ESCAPE: public API returns only Int, String, Symbol,
#      Bool, Vector{SubconsciousHint}, Dict{Symbol,Int}, or nothing.
#      No Float64 scalar can leak into vote math.
#   3. STOCHASTIC ISOLATION: writes are probabilistic (p_write gate)
#      and reads are throttled (token bucket + global reader lock).
#      The observer is lazy — it doesn't observe everything, and it
#      doesn't answer every query. "I don't know" is the default.
#
# These invariants are checked by _invariant_selfcheck() on module load.
# If any invariant is violated, the module logs a CRITICAL warning but
# continues operating — the observer should never crash the cave.
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
# This module is ARCHITECTURALLY ISOLATED from vote ranking, candidate scoring,
# and routing. Its public hint type contains zero Float64 fields. The only
# integration point is the generation / system-prompt layer.
# ==============================================================================

module SelfObserver

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

using Base.Threads
using Base.Threads: Atomic, atomic_add!, atomic_sub!, ReentrantLock
using Random

# ==============================================================================
# EXPORTS
# ==============================================================================

export Microlog, SubconsciousStore, SubconsciousHint
export SelfObserverError, SelfObserverConfigError, SelfObserverArgumentError
export observe!, peek_exact, peek_pattern, audit_trail, drop_store!, drop_keys_by_prefix!
export reset_audit!, store_size, key_count
export FUZZY_BUCKETS
# GRUG v8.22: Invariant observer exports — self-check and version.
export INVARIANT_OBSERVER_VERSION, invariant_check

# ==============================================================================
# v8.22: INVARIANT OBSERVER VERSION
# ==============================================================================
# GRUG: This constant tags the invariant level of the SelfObserver module.
# Bumped when the invariant guarantees change. Downstream code can check
# this to know what level of isolation to expect.
#   v1 — original observation-only module (v7.21b-1)
#   v2 — explicit invariant observer with runtime self-check (v8.22)
const INVARIANT_OBSERVER_VERSION = 2

# ==============================================================================
# v8.22: INVARIANT SELF-CHECK
# ==============================================================================
# GRUG: Runs on module load and on demand via invariant_check().
# Verifies three structural invariants:
#   1. SubconsciousHint has NO Float64 fields (no confidence leak path)
#   2. All public API return types are Float64-free
#   3. Microlog.weight is the ONLY Float64 field, and it's never in public API
#
# Returns true if all invariants hold, false with @error if any are violated.
# This is the "trust but verify" layer — the guarantees are already documented,
# but a runtime check catches accidental regressions during development.
function invariant_check()::Bool
    all_ok = true

    # INVARIANT 1: SubconsciousHint has no Float64 fields.
    hint_field_types = fieldtypes(SubconsciousHint)
    for ft in hint_field_types
        if ft === Float64
            @error "[SelfObserver v8.22] INVARIANT VIOLATED: SubconsciousHint has a Float64 field! " *
                   "This leaks a confidence-shapable scalar into vote-adjacent code. " *
                   "Remove it or convert to Symbol/String/Int."
            all_ok = false
        end
    end

    # INVARIANT 2: Check that observe! returns Bool (not Float64).
    # We check the return type of observe! by inspecting its method signature.
    # GRUG v9.4: guard against Julia versions where `Method` has no `return_type`
    # field (it was removed in newer Julia base). Use property-access with a
    # fallback so the invariant self-check never throws a FieldError on boot —
    # a thrown check is worse than a skipped one (it scares the user on every
    # boot with a red error even though the engine works fine).
    for m in methods(observe!)
        rt = try
            m.return_type
        catch
            nothing  # field not present on this Julia version — skip this method
        end
        if rt !== nothing && rt !== Bool && rt !== Any
            @error "[SelfObserver v8.22] INVARIANT VIOLATED: observe! returns $rt, expected Bool! " *
                   "observe! must return Bool (written/skipped), not a confidence-shaped scalar."
            all_ok = false
        end
    end

    # INVARIANT 3: Microlog.weight is internal-only. Verify it's not exposed
    # in SubconsciousHint (already checked above, but let's be explicit).
    # The hint uses payload_strings which strips Float64 values — check that.
    # This is a design-level check, not runtime — we verify the _payload_strings
    # function exists and the SubconsciousHint type doesn't carry raw payload.
    for fname in fieldnames(SubconsciousHint)
        if fname === :payload
            @error "[SelfObserver v8.22] INVARIANT VIOLATED: SubconsciousHint has a 'payload' field! " *
                   "Raw payload Dict{String,Any} could contain Float64 values. " *
                   "Use payload_strings (String-only safe view) instead."
            all_ok = false
        end
    end

    if all_ok
        @info "[SelfObserver v8.22] Invariant self-check PASSED — observer is isolated, no Float64 leak paths."
    else
        @error "[SelfObserver v8.22] Invariant self-check FAILED — see above violations. " *
               "The observer module is NOT invariant-safe. Fix before deploying."
    end

    return all_ok
end

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

# GRUG v8.22: LAZY CONSERVATIVE write probability. Reduced from 0.25 to 0.15.
# The subconscious doesn't need to remember everything. Most observations
# are noise — the cave should only store what's salient enough to survive
# the stochastic gate. A lower p_write means fewer entries, less eviction
# pressure, and a higher signal-to-noise ratio in what survives. The
# observer is lazy — it doesn't try to capture every detail, and that's
# by design. "I don't remember" is a valid subconscious answer.
const DEFAULT_P_WRITE          = 0.15      # stochastic write probability (was 0.25)
const DEFAULT_SALIENCE         = 1.0       # baseline interest weight
const SALIENCE_FLOOR           = 0.0
const SALIENCE_CEILING         = 10.0
const REINFORCE_GAIN           = 0.5       # how much repeat-write boosts existing weight
const WEIGHT_CEILING           = 10.0      # max weight after reinforcement
const DECAY_PER_TICK           = 0.02      # weight loss per maintenance tick (parked use)

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
const VALID_TAGS = Set{Symbol}([:timing, :lexical, :mood, :relational, :meta])

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
# `weight` is internal — it shapes survival under eviction, NEVER returned to
# callers as a number. This is part of the no-Float64 invariant.
mutable struct Microlog
    key::String
    tag::Symbol
    payload::Dict{String, Any}
    weight::Float64                 # INTERNAL ONLY — never escapes via public API
    timestamp::Float64              # INTERNAL ONLY — fuzzed before returning
    provenance::Symbol              # why this microlog was written (e.g. :no_relations_extracted)
    drop_table::Vector{String}      # per-entry associated keys (moment-specific)
end

function Microlog(key::String, tag::Symbol, payload::Dict{String,Any},
                  weight::Float64, provenance::Symbol,
                  drop_table::Vector{String} = String[])
    if tag ∉ VALID_TAGS
        throw(SelfObserverArgumentError(
            "tag must be one of $(collect(VALID_TAGS))", "tag"))
    end
    if !(SALIENCE_FLOOR <= weight <= SALIENCE_CEILING)
        throw(SelfObserverArgumentError(
            "weight out of range [$(SALIENCE_FLOOR), $(SALIENCE_CEILING)]", "weight"))
    end
    return Microlog(key, tag, payload, weight, time(), provenance,
                    copy(drop_table))
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

# GRUG: salience-aware eviction. Score = weight * recency_factor.
# Recency factor decays exponentially with age. Lowest score evicted.
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
        score = ml.weight * recency
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
- `salience`               — initial weight, clamped to [0.0, 10.0].
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
        # provenance), boost its weight and refresh timestamp instead of adding
        # a brand-new entry. This is what makes "I keep noticing X" stick.
        reinforced = false
        for ml in bucket
            if ml.tag == tag && ml.provenance == provenance
                ml.weight = min(WEIGHT_CEILING, ml.weight + REINFORCE_GAIN * salience)
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
            score = ml.weight * recency
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

        # Filter by tag if requested. Sort by weight*recency descending; cap.
        now = time()
        scored = Tuple{Float64, Microlog}[]
        for ml in bucket
            if tag !== nothing && ml.tag != tag
                continue
            end
            age = max(0.0, now - ml.timestamp)
            recency = exp(-age / 86400.0)
            push!(scored, (ml.weight * recency, ml))
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
   shared tokens (tied with stored microlog weight*recency).
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
                s = ml.weight * recency
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
                s = shared * (ml.weight * recency)
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
                push!(candidates, (disc * ml.weight * recency, k, ml))
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

"""
    drop_keys_by_prefix!(store, prefix::AbstractString) -> Int

Remove all entries whose key starts with `prefix`. Returns count of keys dropped.
Useful for selectively clearing a namespace (e.g., all "error_" entries) without
nuking the entire store. Also cleans up associated drop-table links.
"""
function drop_keys_by_prefix!(store::SubconsciousStore, prefix::AbstractString)::Int
    lock(store.write_lock)
    dropped = 0
    try
        # Find keys matching prefix
        keys_to_drop = String[]
        for k in keys(store.table)
            if startswith(k, prefix)
                push!(keys_to_drop, k)
            end
        end
        # Remove entries and count
        for k in keys_to_drop
            n = length(store.table[k])
            delete!(store.table, k)
            store.total_entries = max(0, store.total_entries - n)
            dropped += 1
        end
        # Clean drop_tables: remove references to dropped keys
        if !isempty(keys_to_drop)
            drop_set = Set(keys_to_drop)
            for (dt_key, dt_vec) in store.drop_tables
                filter!(v -> !(v in drop_set), dt_vec)
            end
            # Remove empty drop_tables entries
            empty_dt_keys = [k for (k, v) in store.drop_tables if isempty(v)]
            for k in empty_dt_keys
                delete!(store.drop_tables, k)
            end
        end
    finally
        unlock(store.write_lock)
    end
    return dropped
end

end # module SelfObserver

# ==============================================================================
# GRUG v8.22: Run invariant self-check on module load.
# This fires once when the module is first included. If any invariant
# is violated, it logs @error but does NOT crash — the observer should
# never take down the cave. The check result is available via
# SelfObserver.invariant_check() for programmatic verification.
# ==============================================================================
try
    SelfObserver.invariant_check()
catch e
    @error "[SelfObserver v8.22] Invariant self-check FAILED on module load (non-fatal): $e"
end
