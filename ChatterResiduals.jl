# ==============================================================================
# ChatterResiduals.jl — Background Thread Mining Chatter Swaps into Relational Data
# ==============================================================================
# GRUG: When chatter swaps votes into weak nodes, those nodes become "multi-
# activator randomized types" — their action packets now contain actions from
# multiple donor families, their patterns fragment under accumulated swap
# pressure, and they lose solid group identity. They become globally
# UNLINKABLE: too many neighbors, or pattern too scattered to latch to
# anything coherently.
#
# These are CHATTER RESIDUALS. The residual IS the pattern drift — the
# fact that a weak node accepted a vote swap from a strong donor means
# those two nodes are now relationally entangled, even though the weak
# node's identity is fragmenting. That entanglement is DATA. This module
# mines it.
#
# Architecture (mirrors InputLedger):
#   - Hash ledger: UInt64 hash(session_id | node_id | donor_id) → consumed
#   - Fresh scanner: walks CHATTER_LOG, skips consumed swaps, returns batch
#   - Batch processor: for each accepted swap, record co-occurrence between
#     receiver and donor with CHATTER_CO_OCCUR_INCREMENT (1.5)
#   - Background thread: @async loop, crash-restart, never dies
#   - Bounded: ledger capped at 2 * MAX_CHATTER_LOG (400 entries)
#   - Serialize/deserialize for specimen save/load
#   - Status diagnostics for /status
#
# PHILOSOPHY: InputLedger mines USER INPUT — the primary channel (2.0
# increment). ChatterResiduals mines CHATTER SWAPS — the secondary channel
# (1.5 increment). Chatter learns what to chatter about while active.
# The residual is the afterimage: which nodes gossiped with which, and
# what fragmentary identity traces they left behind.
#
# "moss on rock, but the moss remembers who brushed against it"
# ==============================================================================

module ChatterResiduals

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
using Base.Threads: ReentrantLock, @spawn
using Random

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

struct ChatterResidualError <: Exception
    msg::String
end

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Maximum ledger entries. 2x ChatterMode MAX_CHATTER_LOG (200) because
# each session can produce up to ~200 accepted swaps (in practice far fewer).
# Bounded so the ledger can't grow without limit.
const RESIDUAL_LEDGER_CAP = 400

# GRUG: How many fresh swaps to collect per batch before processing.
# Chatter is less frequent than user input, so smaller batches.
const RESIDUAL_BATCH_SIZE = 200

# GRUG: How long the background thread sleeps when no fresh data is found.
# 10 seconds — chatter runs every ~2 minutes, so this is responsive enough.
const RESIDUAL_POLL_INTERVAL_EMPTY = 10.0

# GRUG: How long the background thread sleeps after processing a batch.
# Shorter than empty poll — there might be more fresh swaps right behind.
const RESIDUAL_POLL_INTERVAL_AFTER_BATCH = 2.0

# GRUG: Minimum number of fresh swaps needed to even bother processing.
# Chatter sessions typically produce 5-50 accepted swaps. Less than 3
# = not enough signal. Wait for more.
const RESIDUAL_MIN_BATCH_THRESHOLD = 3

# GRUG: Intensity increment per co-occurrence observation from chatter swaps.
# This is a SECONDARY CHANNEL — weaker than user input (2.0) but stronger
# than scan co-firing (1.0). Chatter residuals are organic, emergent
# entanglement. They didn't come from the user directly, but they came
# from the system's own gossip — that's worth more than random co-firing.
const CHATTER_CO_OCCUR_INCREMENT = 1.5

# GRUG: Confidence-similarity gate for secondary chatter type. A residual
# swap only feeds into RelationalGovernance if the weak node's pattern
# has approximately CONFIDENCE_SIMILARITY_FLOOR (0.50) Jaccard overlap
# with the donor's pattern. This is NOT the 0.05 minimum-overlap junk
# filter from InputLedger/RelGov — it's a CONFIDENCE threshold. The weak
# node must actually RECOGNIZE the donor's pattern as similar to its own
# identity. ~50% means "about half my tokens appear in the donor's pattern"
# — a genuine resonance, not just noise.
#
# The jitter (CONFIDENCE_SIMILARITY_JITTER_SIGMA) makes the threshold
# stochastic. Sometimes a 45% overlap sneaks through, sometimes a 55%
# overlap gets blocked. This prevents a hard wall and lets borderline
# residuals occasionally propagate — organic, not mechanical.
const CONFIDENCE_SIMILARITY_FLOOR = 0.50
const CONFIDENCE_SIMILARITY_JITTER_SIGMA = 0.08

# GRUG: Markov remix constants for vote stealing. When a residual passes
# the confidence gate, we steal the donor's vote but remix it via a Markov
# chain so it's not a stale copy. The remix draws from BOTH the receiver's
# and donor's action packets, producing a new action that belongs to the
# receiver's identity while carrying the donor's trace.
#
# MARKOV_BLEND_BIAS: Probability of drawing the next token from the donor's
# vocabulary vs the receiver's. 0.35 means ~35% donor influence — the
# receiver's own identity dominates but the donor leaves a trace. Not 50/50
# because the whole point is the WEAK node steals FROM the strong — it's
# assimilation, not a merger.
const MARKOV_BLEND_BIAS = 0.35

# GRUG: Maximum attempts to generate a unique remixed action name before
# falling back to a simple prefix splice. Prevents infinite loops when
# both packets have very short token vocabularies.
const MARKOV_MAX_ATTEMPTS = 12

# GRUG: Weight blend for the remixed action's vote weight. The new weight
# is a weighted average of the donor's and receiver's items. 0.60 means
# the receiver's weight counts 60% — the node keeps most of its own vote
# intensity, but the donor's strength bleeds in.
const WEIGHT_BLEND_RECEIVER_SHARE = 0.60

# ==============================================================================
# HASH LEDGER — tracks which chatter swaps have been consumed
# ==============================================================================
# GRUG: Key is hash(session_id * "|" * node_id * "|" * donor_id). This is
# stable — the same swap always maps to the same hash. Value is always true
# (consumed). If a hash is NOT in the ledger, the swap is fresh.

const _RESIDUAL_LEDGER = Dict{UInt64, Bool}()
const _RESIDUAL_LEDGER_LOCK = ReentrantLock()

# GRUG: Counters for diagnostics
const _RESIDUAL_STATS = Atomic{Int}(0)       # total swaps consumed ever
const _RESIDUAL_BATCHES = Atomic{Int}(0)     # total batches processed ever
const _RESIDUAL_LAST_BATCH_TIME = Atomic{Float64}(0.0)  # timestamp of last batch
const _RESIDUAL_CO_OCCUR_OBS = Atomic{Int}(0)  # total co-occurrence observations fed
const _RESIDUAL_VOTES_STOLEN = Atomic{Int}(0)   # total vote-steals with Markov remix applied
const _RESIDUAL_VOTES_FAILED = Atomic{Int}(0)   # vote-steals that failed validation (parse/refused)

# ==============================================================================
# BACKGROUND THREAD STATE
# ==============================================================================

const _RESIDUAL_THREAD_RUNNING = Atomic{Bool}(false)  # is the thread alive?
const _RESIDUAL_THREAD_REF = Ref{Task}(Task(() -> nothing))  # reference to async task

# ==============================================================================
# LEDGER OPERATIONS
# ==============================================================================

"""
    _swap_hash(session_id::String, node_id::String, donor_id::String)::UInt64

GRUG: Compute a stable hash for a chatter swap. Same swap = same hash.
Uses session_id + "|" + node_id + "|" + donor_id so each unique swap
gets a unique hash. Different sessions with same nodes are different swaps.
"""
function _swap_hash(session_id::String, node_id::String, donor_id::String)::UInt64
    return hash(session_id * "|" * node_id * "|" * donor_id)
end

"""
    is_consumed(h::UInt64)::Bool

GRUG: Check if a hash has already been consumed. Thread-safe.
"""
function is_consumed(h::UInt64)::Bool
    return lock(() -> haskey(_RESIDUAL_LEDGER, h), _RESIDUAL_LEDGER_LOCK)
end

"""
    mark_consumed!(h::UInt64)

GRUG: Mark a hash as consumed. Thread-safe. Evicts random entry if
ledger is at cap. Same strategy as InputLedger — old consumed entries
don't need to be tracked forever.
"""
function mark_consumed!(h::UInt64)
    lock(_RESIDUAL_LEDGER_LOCK) do
        if !haskey(_RESIDUAL_LEDGER, h)
            if length(_RESIDUAL_LEDGER) >= RESIDUAL_LEDGER_CAP
                keys_vec = collect(keys(_RESIDUAL_LEDGER))
                delete!(_RESIDUAL_LEDGER, keys_vec[rand(1:length(keys_vec))])
            end
            _RESIDUAL_LEDGER[h] = true
        end
    end
end

"""
    residual_ledger_size()::Int

GRUG: How many entries in the ledger. For diagnostics.
"""
function residual_ledger_size()::Int
    return lock(() -> length(_RESIDUAL_LEDGER), _RESIDUAL_LEDGER_LOCK)
end

# ==============================================================================
# FRESH SWAP SCANNER — finds unconsumed swaps in CHATTER_LOG
# ==============================================================================

"""
    scan_fresh_swaps(;
        chatter_log_ref,
        chatter_log_lock_ref,
        batch_size::Int = RESIDUAL_BATCH_SIZE,
        min_threshold::Int = RESIDUAL_MIN_BATCH_THRESHOLD
    )::Vector{Tuple{String, String, String, String, UInt64}}

GRUG: Walk CHATTER_LOG and collect fresh (unconsumed) accepted swaps.
Returns a vector of (session_id, node_id, donor_id, donor_action_name, hash)
tuples. Only swaps whose hash is NOT in the ledger are returned — these
are the fresh ones.

Stops at batch_size swaps OR end of log, whichever comes first.
If fewer than min_threshold fresh swaps are found, returns empty
(the thread will sleep and try again later).

Thread-safe: takes the log lock for the walk, ledger lock for
consumption checks.
"""
function scan_fresh_swaps(;
    chatter_log_ref,
    chatter_log_lock_ref,
    batch_size::Int = RESIDUAL_BATCH_SIZE,
    min_threshold::Int = RESIDUAL_MIN_BATCH_THRESHOLD
)::Vector{Tuple{String, String, String, String, UInt64}}

    fresh = Tuple{String, String, String, String, UInt64}[]

    lock(chatter_log_lock_ref) do
        for session in chatter_log_ref
            for clone in session.clones
                clone.accepted_swap || continue
                # GRUG: Only mine swaps where the clone actually accepted.
                # Empty donor_id means the swap was blocked before staging.
                isempty(clone.donor_id) && continue

                h = _swap_hash(session.session_id, clone.source_id, clone.donor_id)
                if !is_consumed(h)
                    push!(fresh, (session.session_id, clone.source_id,
                                  clone.donor_id, clone.donor_action_name, h))
                end
                length(fresh) >= batch_size && break
            end
            length(fresh) >= batch_size && break
        end
    end

    # GRUG: Not enough fresh data? Return empty — thread should sleep.
    if length(fresh) < min_threshold
        return Tuple{String, String, String, String, UInt64}[]
    end

    return fresh
end

# ==============================================================================
# ACTION ITEM PARSER — lightweight mirror of ChatterMode._parse_action_items
# ==============================================================================
# GRUG: We can't import ChatterMode (module load order coupling), so we mirror
# the parser here. Same format: pipe-delimited entries like
#   action_name[neg1, neg2]^weight  |  action2^weight  |  action3
# We only need the structured result, not the full ChatterMode cargo.

struct _ResidualActionItem
    action::String
    negatives::Vector{String}
    weight::Float64
    has_weight::Bool
end

# GRUG BUG-011: Keep pipe-delimited packets, but allow literal pipes in
# action names via {PIPE}/{{PIPE}} macro decoded after slot splitting.
_residual_expand_action_macro_string(s::AbstractString)::String = replace(replace(String(s), "{{PIPE}}" => "|"), "{PIPE}" => "|")

function _residual_parse_items(packet::String)::Vector{_ResidualActionItem}
    strip(packet) == "" && return _ResidualActionItem[]
    items = _ResidualActionItem[]
    for raw in split(packet, '|')
        p = strip(raw)
        isempty(p) && continue
        negs = String[]
        weight = 1.0
        has_weight = false
        m = match(r"^(.+?)\[([^\]]*)\](?:\^([\d.]+))?$", p)
        if !isnothing(m)
            action_name = strip(m.captures[1])
            for n in split(m.captures[2], ',')
                ns = strip(n)
                !isempty(ns) && push!(negs, String(ns))
            end
            wstr = m.captures[3]
            if !isnothing(wstr)
                w = tryparse(Float64, strip(wstr))
                !isnothing(w) && (weight = w; has_weight = true)
            end
            push!(items, _ResidualActionItem(_residual_expand_action_macro_string(action_name), negs, weight, has_weight))
        elseif contains(p, '^')
            parts = split(p, '^'; limit=2)
            action_name = strip(parts[1])
            w = tryparse(Float64, strip(parts[2]))
            !isnothing(w) && push!(items, _ResidualActionItem(_residual_expand_action_macro_string(action_name), String[], w, true))
        else
            push!(items, _ResidualActionItem(_residual_expand_action_macro_string(p), String[], 1.0, false))
        end
    end
    return items
end

function _residual_serialize_items(items::Vector{_ResidualActionItem})::String
    parts = String[]
    for it in items
        body = isempty(it.negatives) ? it.action : "$(it.action)[" * join(it.negatives, ", ") * "]"
        push!(parts, it.has_weight ? "$(body)^$(round(it.weight, digits=3))" : body)
    end
    return join(parts, " | ")
end

# ==============================================================================
# MARKOV REMIX ENGINE — vote stealing with automata remix
# ==============================================================================
# GRUG: When a residual passes the confidence-similarity gate, we don't just
# record co-occurrence — we STEAL THE VOTE. But the stolen vote can't be a
# stale copy of the donor's action. That would be plagiarism, not learning.
# Instead, we remix it via a Markov-like transition that draws from BOTH the
# receiver's and donor's action vocabularies. The result is a new action that
# belongs to the receiver's identity while carrying the donor's trace.
#
# Algorithm:
#   1. Tokenize both action names (split by underscores/spaces/hyphens)
#   2. Build a bigram transition table from BOTH token sequences
#   3. Walk the chain: start from the donor's first token (the seed), then
#      at each step, draw the next token from the combined transition table
#      with MARKOV_BLEND_BIAS weighting toward the donor's transitions
#   4. The resulting token sequence becomes the remixed action name
#   5. If the chain produces an action already in the receiver's packet,
#      retry with a different walk (up to MARKOV_MAX_ATTEMPTS)
#   6. Fall back to a prefix-splice if all walks collide
#
# "the vote needs an automata remix slightly to not be stale. base it on
#  both nodes votes. like a markov is fine for this" — user spec

"""
    _tokenize_action(action_name::String)::Vector{String}

GRUG: Split an action name into tokens by underscores, spaces, and hyphens.
"ponder_deeply" → ["ponder", "deeply"]. "query-respond" → ["query", "respond"].
"""
function _tokenize_action(action_name::String)::Vector{String}
    tokens = String[]
    for raw in split(replace(lowercase(strip(action_name)), "-" => "_"), '_')
        t = strip(raw)
        !isempty(t) && push!(tokens, t)
    end
    return tokens
end

"""
    _build_bigram_table(token_sequences::Vector{Vector{String}})::Dict{String, Vector{String}}

GRUG: Build a bigram transition table from multiple token sequences.
For each sequence [a, b, c, d], we add transitions a→b, b→c, c→d.
Multiple sequences merge into the same table. The table maps each token
to the list of tokens that followed it (with duplicates = frequency).
"""
function _build_bigram_table(token_sequences::Vector{Vector{String}})::Dict{String, Vector{String}}
    table = Dict{String, Vector{String}}()
    for seq in token_sequences
        for i in 1:(length(seq) - 1)
            src = seq[i]
            dst = seq[i + 1]
            if !haskey(table, src)
                table[src] = String[]
            end
            push!(table[src], dst)
        end
    end
    return table
end

"""
    _walk_markov(bigram_table, start_tokens, max_len)::Vector{String}

GRUG: Walk a Markov chain starting from a random start token. At each step,
look up the current token in the bigram table. If found, pick a random
successor. If not found (dead end), stop. Cap at max_len tokens.
Legacy single-strand walk — kept for fallback.
"""
function _walk_markov(bigram_table::Dict{String, Vector{String}},
                      start_tokens::Vector{String},
                      max_len::Int)::Vector{String}
    isempty(start_tokens) && return String[]
    # GRUG: Start from a random seed token from the donor's first tokens
    seed = rand(start_tokens)
    chain = [seed]
    for _ in 1:max_len
        current = chain[end]
        if !haskey(bigram_table, current) || isempty(bigram_table[current])
            break  # dead end
        end
        push!(chain, rand(bigram_table[current]))
    end
    return chain
end

# ==============================================================================
# GRUG (v8.1): STRUCTURAL CROSSOVER MARKOV — two-strand blend
# ==============================================================================
# The old Markov dumped both vocabularies into one bigram table and walked
# blindly. The remix was accidental. The new approach builds TWO separate
# bigram tables (strand A = donor, strand B = receiver) and walks with
# deliberate crossover between them. Like genetic crossover: at each step,
# there's a chance to jump to the other strand and continue from there.
# The result is a chain that STRUCTURALLY blends the two inputs, not one
# that wanders through a merged soup.
#
# "the markov mutator for vote swaps should work by converting the original
#  node vote + the node vote you are stealing then markov remix both inputs
#  in a way where markov knows these are two structures to blend together"
# ==============================================================================

# GRUG: Crossover rate — probability of jumping to the other strand at each step.
const MARKOV_CROSSOVER_RATE = 0.35

"""
    _walk_crossover_markov(strand_a, strand_b, bigram_a, bigram_b;
                            start_in_a::Bool = true,
                            crossover_rate::Float64 = MARKOV_CROSSOVER_RATE,
                            max_len::Int = 4)::Vector{String}

GRUG: Walk a two-strand Markov chain with deliberate crossover. strand_a is
the donor (stolen vote), strand_b is the receiver (original vote). We start
in strand A (the donor — the stolen vote is the seed identity). At each step:
  1. Try to continue in the current strand (bigram transition)
  2. If crossover roll succeeds, jump to the other strand:
     - If the other strand has a token at this position, use it
     - If not (strand is shorter), try the other strand's bigram table instead
  3. If both strands are dead ends at this token, stop

The walk produces a chain that traces through BOTH structures deliberately.
Like genetic crossover — the child inherits from both parents at marked points.
"""
function _walk_crossover_markov(strand_a::Vector{String},
                                 strand_b::Vector{String},
                                 bigram_a::Dict{String, Vector{String}},
                                 bigram_b::Dict{String, Vector{String}};
                                 start_in_a::Bool = true,
                                 crossover_rate::Float64 = MARKOV_CROSSOVER_RATE,
                                 max_len::Int = 4)::Vector{String}
    isempty(strand_a) && isempty(strand_b) && return String[]

    # GRUG: Start from the first token of the starting strand.
    # Default: start in strand A (donor) — the stolen vote is the seed.
    in_a = start_in_a
    current_strand = in_a ? strand_a : strand_b
    if isempty(current_strand)
        # GRUG: Starting strand is empty, flip to the other.
        in_a = !in_a
        current_strand = in_a ? strand_a : strand_b
        isempty(current_strand) && return String[]
    end

    chain = [current_strand[1]]
    step = 1  # position index in the current strand

    for _ in 1:max_len
        current_token = chain[end]
        current_bigram = in_a ? bigram_a : bigram_b
        other_bigram = in_a ? bigram_b : bigram_a
        other_strand = in_a ? strand_b : strand_a

        # GRUG: Crossover roll — should we jump to the other strand?
        if rand() < crossover_rate && !isempty(other_strand)
            # GRUG: Cross over! Try to continue from the other strand.
            # If the other strand has a token at our current position + 1,
            # use it (positional crossover — like genetic recombination).
            next_pos = step + 1
            if next_pos <= length(other_strand)
                # GRUG: Positional crossover — take the token at this position
                # from the other strand. This is the structural blend.
                cross_token = other_strand[next_pos]
                push!(chain, cross_token)
                in_a = !in_a
                step = next_pos
                continue
            elseif haskey(other_bigram, current_token) && !isempty(other_bigram[current_token])
                # GRUG: No positional token, but the other strand's bigram
                # knows this token. Transition into the other strand.
                push!(chain, rand(other_bigram[current_token]))
                in_a = !in_a
                step += 1
                continue
            end
            # GRUG: Crossover failed — other strand has nothing at this point.
            # Fall through to same-strand continuation.
        end

        # GRUG: Continue in the current strand (no crossover, or crossover failed).
        if haskey(current_bigram, current_token) && !isempty(current_bigram[current_token])
            push!(chain, rand(current_bigram[current_token]))
            step += 1
        else
            # GRUG: Dead end in current strand. Try the other strand as rescue.
            if haskey(other_bigram, current_token) && !isempty(other_bigram[current_token])
                push!(chain, rand(other_bigram[current_token]))
                in_a = !in_a
                step += 1
            else
                break  # Both strands dead. Walk ends here.
            end
        end
    end

    return chain
end

"""
    _markov_remix_action_name(donor_action::String, receiver_actions::Vector{String};
                               max_len::Int = 4)::String

GRUG: Produce a Markov-remixed action name from the donor's action and the
receiver's existing action vocabulary. Uses structural crossover Markov: builds
TWO separate bigram tables (one per strand) and walks with deliberate crossover
between them. The donor strand is the stolen vote identity; the receiver strand
is the node's own voice. Crossover blends them structurally, not by accident.
"""
function _markov_remix_action_name(donor_action::String,
                                    receiver_actions::Vector{String};
                                    max_len::Int = 4)::String
    donor_tokens = _tokenize_action(donor_action)
    isempty(donor_tokens) && return donor_action  # can't tokenize, use as-is

    # GRUG: Tokenize ALL of the receiver's actions. The receiver's full
    # action vocabulary forms strand B (the node's own voice).
    recv_token_seqs = Vector{Vector{String}}()
    for a in receiver_actions
        t = _tokenize_action(a)
        !isempty(t) && push!(recv_token_seqs, t)
    end

    # GRUG: Build TWO separate bigram tables — strand A (donor) and
    # strand B (receiver). The crossover walk knows these are two
    # distinct structures to blend, not one merged soup.
    donor_bigram = _build_bigram_table([donor_tokens])
    recv_bigram = _build_bigram_table(recv_token_seqs)

    # GRUG: The receiver's primary action (strongest) forms strand B's
    # main sequence for positional crossover. The donor is strand A.
    recv_primary = isempty(recv_token_seqs) ? String[] : recv_token_seqs[1]

    # GRUG: Walk the two-strand crossover chain.
    chain = _walk_crossover_markov(donor_tokens, recv_primary,
                                    donor_bigram, recv_bigram;
                                    start_in_a = true,
                                    max_len = max_len)

    # GRUG: If the crossover walk produced only 1 token (just the seed),
    # try starting from the receiver's strand instead. The donor strand
    # might have no transitions (single-token action name).
    if length(chain) <= 1 && !isempty(recv_primary)
        chain = _walk_crossover_markov(donor_tokens, recv_primary,
                                        donor_bigram, recv_bigram;
                                        start_in_a = false,
                                        max_len = max_len)
    end

    # GRUG: Last resort — if crossover still can't produce a multi-token
    # chain, fall back to the old single-strand walk on a combined table.
    if length(chain) <= 1
        all_seqs = vcat([donor_tokens], recv_token_seqs)
        combined_bigram = _build_bigram_table(all_seqs)
        all_starts = vcat(donor_tokens, reduce(vcat, recv_token_seqs; init=String[]))
        chain = _walk_markov(combined_bigram, all_starts, max_len)
    end

    # Rejoin tokens with underscore to form an action name
    remixed = join(chain, "_")
    isempty(remixed) && return donor_action  # absolute fallback
    return remixed
end

"""
    _prefix_splice_fallback(donor_action::String, receiver_actions::Vector{String})::String

GRUG: If all Markov walks produce collisions (action already exists in the
receiver's packet), fall back to a simple prefix-splice: take the first
token from the donor and the last token from a random receiver action,
join them. This guarantees novelty while keeping both identities visible.
"""
function _prefix_splice_fallback(donor_action::String,
                                  receiver_actions::Vector{String})::String
    d_tokens = _tokenize_action(donor_action)
    r_tokens = isempty(receiver_actions) ? String[] :
               _tokenize_action(rand(receiver_actions))

    prefix = isempty(d_tokens) ? "remix" : d_tokens[1]
    suffix = isempty(r_tokens) ? "drift" : r_tokens[end]

    return "$(prefix)_$(suffix)"
end

"""
    _remix_vote(donor_action_name::String, receiver_packet::String, donor_packet::String;
                 overlap::Float64 = 0.5)::String

GRUG: The main vote-remix entry point. Takes the donor's action name (the
stolen vote), the receiver's full action packet, and the donor's full action
packet. Produces a new action_packet string for the receiver with the
remixed vote injected in place of the weakest action.

Steps:
  1. Parse both packets into _ResidualActionItem vectors
  2. Build the receiver's action name list for Markov vocabulary
  3. Run Markov remix on the donor's action name using both vocabularies
  4. If the remixed name collides with an existing receiver action, retry
     (up to MARKOV_MAX_ATTEMPTS), then fall back to prefix-splice
  5. Merge negatives: receiver's item negatives stay, add donor's negatives
     that aren't already present (union, not overwrite)
  6. Blend weight: weighted average of donor and receiver weakest-item
     weights, biased toward receiver (WEIGHT_BLEND_RECEIVER_SHARE = 0.60)
  7. Replace receiver's lowest-weight item with the remixed item
  8. Serialize and return the new packet string
"""
function _remix_vote(donor_action_name::String,
                     receiver_packet::String,
                     donor_packet::String;
                     overlap::Float64 = 0.5)::String
    recv_items = _residual_parse_items(receiver_packet)
    donor_items = _residual_parse_items(donor_packet)

    # GRUG: If either packet is unparseable, return the receiver's packet
    # unchanged. Vote stealing is best-effort — a bad packet should not
    # corrupt a live node.
    if isempty(recv_items)
        return receiver_packet
    end

    # GRUG: Find the donor item matching the donor_action_name.
    # This carries the donor's negatives and weight — the vote identity.
    donor_item = nothing
    for it in donor_items
        if it.action == donor_action_name
            donor_item = it
            break
        end
    end
    # GRUG: If we can't find the donor's exact action, use the first item.
    # The swap happened, so the donor's packet must contain this action,
    # but defensive coding says: don't crash on data inconsistency.
    if isnothing(donor_item) && !isempty(donor_items)
        donor_item = donor_items[1]
    end
    if isnothing(donor_item)
        return receiver_packet  # no donor data, can't remix
    end

    # GRUG: Build the receiver's action name list for Markov vocabulary.
    recv_action_names = [it.action for it in recv_items]

    # GRUG: Run Markov remix. Try up to MARKOV_MAX_ATTEMPTS walks.
    # If a walk produces an action name already in the receiver's packet,
    # it's a collision — retry. This prevents self-swap duplication.
    remixed_name = donor_action_name  # start with donor as fallback
    for attempt in 1:MARKOV_MAX_ATTEMPTS
        candidate = _markov_remix_action_name(donor_item.action, recv_action_names)
        if !(candidate in recv_action_names)
            remixed_name = candidate
            break
        end
        # GRUG: Collision. On last attempt, use prefix-splice fallback.
        if attempt == MARKOV_MAX_ATTEMPTS
            remixed_name = _prefix_splice_fallback(donor_item.action, recv_action_names)
            # GRUG: If even the splice collides, suffix with a nonce.
            if remixed_name in recv_action_names
                remixed_name = "$(remixed_name)_$(rand(100:999))"
            end
        end
    end

    # GRUG: Merge negatives. Receiver's item negatives stay. Donor's
    # negatives are unioned in — they're part of the stolen vote's
    # identity. "I stole your vote, and your vendettas come with it."
    # But: don't add the remixed action name as a negative anywhere
    # (that would be self-contradictory).
    merged_negs = String[]
    for it in recv_items
        for n in it.negatives
            (!(n in merged_negs) && n != remixed_name) && push!(merged_negs, n)
        end
    end
    for n in donor_item.negatives
        (!(n in merged_negs) && n != remixed_name) && push!(merged_negs, n)
    end

    # GRUG: Replace the receiver's lowest-weight item. Same strategy as
    # ChatterMode._apply_swap: weak votes get overwritten, strong votes
    # keep their slots. Additive at the personality layer.
    swap_idx = argmin([it.weight for it in recv_items])
    weakest_weight = recv_items[swap_idx].weight

    # GRUG: Blend weight. The remixed vote's weight is a weighted average
    # of the donor's item weight and the receiver's weakest item weight.
    # WEIGHT_BLEND_RECEIVER_SHARE (0.60) means the receiver's identity
    # dominates — it's assimilation, not replacement.
    donor_w = donor_item.has_weight ? donor_item.weight : 1.0
    blended_weight = (WEIGHT_BLEND_RECEIVER_SHARE * weakest_weight +
                      (1.0 - WEIGHT_BLEND_RECEIVER_SHARE) * donor_w)
    # GRUG: Jitter the blend slightly — organic, not mechanical.
    blended_weight += (rand() * 2.0 - 1.0) * 0.05
    blended_weight = max(0.05, blended_weight)  # floor from engine.jl

    # GRUG: Build the remixed action item. Negatives from the merged set
    # go on the NEW item only (the stolen vote), not on existing items.
    # This is the donor's trace living inside the receiver's packet.
    remixed_negs = String[]
    for n in donor_item.negatives
        (!(n in remixed_negs) && n != remixed_name) && push!(remixed_negs, n)
    end

    remixed_item = _ResidualActionItem(remixed_name, remixed_negs,
                                        round(blended_weight, digits=3), true)

    # GRUG: Replace the weakest item with the remixed item.
    new_items = copy(recv_items)
    new_items[swap_idx] = remixed_item

    return _residual_serialize_items(new_items)
end

# ==============================================================================
# BATCH PROCESSOR — digest fresh swaps into co-occurrence data + vote stealing
# ==============================================================================

"""
    process_residual_batch!(fresh_swaps::Vector{Tuple{String, String, String, String, UInt64}};
                            co_occur_fn::Function = (id_a, id_b, increment) -> nothing,
                            token_overlap_fn::Function = (id_a, id_b) -> 0.0,
                            node_map_ref,
                            node_lock_ref)::Int

GRUG: Process a batch of fresh chatter swaps into co-occurrence data AND
vote stealing with Markov remix.

For each accepted swap (receiver ← donor):
  1. Both nodes exist and are alive (not grave)
  2. Compute Jaccard token overlap between receiver and donor patterns
  3. Confidence-similarity gate: overlap must be ≥ ~50% (with jitter)
     — the weak node must actually RECOGNIZE the donor's pattern as
     similar to its own identity. This is NOT a 0.05 junk filter.
     50% means "about half my tokens appear in yours" — genuine resonance.
     Jitter (~±8%) makes the threshold stochastic, not a hard wall.
  4. If the gate passes:
     a. Record co-occurrence with CHATTER_CO_OCCUR_INCREMENT (1.5) — secondary channel
     b. STEAL THE VOTE: remix the donor's action into the receiver's packet
        via Markov automata. The stolen vote is NOT a stale copy — it's
        remixed from both nodes' action vocabularies so it belongs to the
        receiver while carrying the donor's trace.

The residual IS the co-occurrence between a weak node and its strong donor,
but ONLY when the weak node's own pattern has confidence similarity to the
donor. Random swaps between unrelated nodes are noise — they don't feed in.
Earned. Organic. Moss that only grows on rock it can grip.

"should also steal the votes for those patterns. thats more coherent."
"the vote needs an automata remix slightly to not be stale. base it on both
 nodes votes. like a markov is fine for this"

Then marks all swaps in the batch as consumed in the ledger.

Returns the number of swaps processed.
"""
function process_residual_batch!(fresh_swaps::Vector{Tuple{String, String, String, String, UInt64}};
                                 co_occur_fn::Function = (id_a, id_b, increment) -> nothing,
                                 token_overlap_fn::Function = (id_a, id_b) -> 0.0,
                                 node_map_ref,
                                 node_lock_ref)::Int

    if isempty(fresh_swaps)
        return 0
    end

    swaps_processed = 0
    co_occur_observations = 0
    votes_stolen = 0
    votes_failed = 0

    for (session_id, node_id, donor_id, donor_action_name, h) in fresh_swaps
        # GRUG: Verify both nodes still exist and are alive.
        # Chatter swaps are applied lazily — a node might have been graved
        # between the swap and now. Skip dead pairs.
        local node_alive, donor_alive
        lock(node_lock_ref) do
            node_alive = haskey(node_map_ref, node_id) && !node_map_ref[node_id].is_grave
            donor_alive = haskey(node_map_ref, donor_id) && !node_map_ref[donor_id].is_grave
        end

        if !node_alive || !donor_alive
            mark_consumed!(h)
            swaps_processed += 1
            continue
        end

        # GRUG: Confidence-similarity gate. The secondary chatter type only
        # uses input that has a CONFIDENCE similarity relationship to the
        # weak node's own pattern. ~50% Jaccard overlap with jitter means the
        # weak node actually recognizes the donor — it's not just noise.
        # A 0.05 minimum would let junk through. 50% means "about half my
        # tokens appear in yours" — genuine resonance, earned, organic.
        overlap = token_overlap_fn(node_id, donor_id)

        # GRUG: Jittered threshold. Stochastic so borderline pairs sometimes
        # pass, sometimes don't. Not a hard wall.
        jittered_floor = CONFIDENCE_SIMILARITY_FLOOR +
                         (rand() * 2.0 - 1.0) * CONFIDENCE_SIMILARITY_JITTER_SIGMA
        jittered_floor = clamp(jittered_floor, 0.20, 0.80)  # GRUG: sane bounds

        if overlap >= jittered_floor
            # ── CO-OCCURRENCE ──
            # GRUG: Record relational entanglement. Secondary channel (1.5).
            co_occur_fn(node_id, donor_id, CHATTER_CO_OCCUR_INCREMENT)
            co_occur_observations += 1

            # ── VOTE STEALING WITH MARKOV REMIX ──
            # GRUG: The residual didn't just entangle these nodes — the weak
            # node STOLE the donor's vote. But a stolen vote can't be a stale
            # copy. We remix it via Markov automata using both nodes' action
            # packets, so the result is the receiver's voice carrying the
            # donor's trace. Not plagiarism — assimilation.
            local recv_packet::String, donor_packet::String
            lock(node_lock_ref) do
                recv_packet = node_map_ref[node_id].action_packet
                donor_packet = node_map_ref[donor_id].action_packet
            end

            # GRUG: Run the Markov remix. This produces a new action_packet
            # for the receiver with the stolen vote remixed in.
            local new_packet::String
            try
                new_packet = _remix_vote(donor_action_name, recv_packet,
                                          donor_packet; overlap = overlap)
            catch e
                # GRUG: Remix failed. Log it but don't corrupt the node.
                # Vote stealing is best-effort — a failed remix should not
                # be fatal. The co-occurrence data was already recorded.
                println("[CHATTER_RESIDUALS] ⚠️  Markov remix failed for " *
                        "$(node_id) ← $(donor_id): $e")
                new_packet = ""
                votes_failed += 1
            end

            # GRUG: Validate the remixed packet before writing back.
            # Same guard as ChatterMode.apply_chatter_diffs! — if it
            # doesn't parse, REFUSE the swap. No silent failures.
            if !isempty(new_packet) && new_packet != recv_packet
                local parse_ok::Bool
                try
                    _residual_parse_items(new_packet)
                    parse_ok = true
                catch
                    parse_ok = false
                end

                if parse_ok
                    # GRUG: Write back under lock. Same pattern as
                    # apply_chatter_diffs! — only touch the action_packet.
                    lock(node_lock_ref) do
                        n = get(node_map_ref, node_id, nothing)
                        if !isnothing(n) && !n.is_grave
                            n.action_packet = new_packet
                        end
                    end
                    votes_stolen += 1
                else
                    # GRUG: Remixed packet failed validation. Refused.
                    println("[CHATTER_RESIDUALS] ⛔  Refused remixed vote for " *
                            "$(node_id): packet failed parse validation")
                    votes_failed += 1
                end
            end
        end

        # GRUG: Mark this swap consumed regardless of whether it produced
        # co-occurrence data or a stolen vote. Even a swap between nodes
        # with no pattern overlap has been "seen" — don't re-process it.
        mark_consumed!(h)
        swaps_processed += 1
    end

    # GRUG: Update stats
    atomic_add!(_RESIDUAL_STATS, swaps_processed)
    atomic_add!(_RESIDUAL_BATCHES, 1)
    atomic_add!(_RESIDUAL_LAST_BATCH_TIME, time())
    atomic_add!(_RESIDUAL_CO_OCCUR_OBS, co_occur_observations)
    atomic_add!(_RESIDUAL_VOTES_STOLEN, votes_stolen)
    atomic_add!(_RESIDUAL_VOTES_FAILED, votes_failed)

    return swaps_processed
end

# ==============================================================================
# BACKGROUND THREAD — the afterimage miner
# ==============================================================================

"""
    start_chatter_residuals_thread!(;
        chatter_log_ref,
        chatter_log_lock_ref,
        node_map_ref,
        node_lock_ref,
        co_occur_fn::Function,
        token_overlap_fn::Function)

GRUG: Start the background chatter residuals thread. It runs forever in a
loop: scan for fresh swaps → process batch → sleep → repeat.

If the thread crashes, it auto-restarts after a delay. The thread
should NEVER die — it's the afterimage miner. Afterimages don't stop.

Thread-safe: all shared state access goes through locks.
"""
function start_chatter_residuals_thread!(;
    chatter_log_ref,
    chatter_log_lock_ref,
    node_map_ref,
    node_lock_ref,
    co_occur_fn::Function,
    token_overlap_fn::Function)

    if _RESIDUAL_THREAD_RUNNING[]
        @warn "[CHATTER_RESIDUALS] Thread already running. Not starting another."
        return
    end

    _RESIDUAL_THREAD_RUNNING[] = true

    _RESIDUAL_THREAD_REF[] = @async begin
        # GRUG: Outer crash-recovery loop. If the inner loop throws,
        # we log it, wait, and restart. The thread NEVER dies.
        while _RESIDUAL_THREAD_RUNNING[]
            try
                _residual_inner_loop(;
                    chatter_log_ref = chatter_log_ref,
                    chatter_log_lock_ref = chatter_log_lock_ref,
                    node_map_ref = node_map_ref,
                    node_lock_ref = node_lock_ref,
                    co_occur_fn = co_occur_fn,
                    token_overlap_fn = token_overlap_fn,
                )
            catch e
                # GRUG: Thread crashed! Log it but DON'T die.
                # Auto-restart after a delay. The afterimage miner keeps going.
                println("[CHATTER_RESIDUALS] !!! Thread crashed: $e. Auto-restarting in 30s...")
                sleep(30.0)
            end
        end
        println("[CHATTER_RESIDUALS] 🛑 Thread stopped.")
    end

    println("[CHATTER_RESIDUALS] 🔮  Background thread started. Mining chatter afterimages...")
end

"""
    _residual_inner_loop(; kwargs...)

GRUG: The inner loop of the background thread. Scans for fresh swaps,
processes batches, sleeps when empty. Runs until _RESIDUAL_THREAD_RUNNING
is false.
"""
function _residual_inner_loop(;
    chatter_log_ref,
    chatter_log_lock_ref,
    node_map_ref,
    node_lock_ref,
    co_occur_fn::Function,
    token_overlap_fn::Function)

    while _RESIDUAL_THREAD_RUNNING[]
        # GRUG: Scan for fresh swaps.
        fresh = scan_fresh_swaps(;
            chatter_log_ref = chatter_log_ref,
            chatter_log_lock_ref = chatter_log_lock_ref,
        )

        if isempty(fresh)
            # GRUG: Nothing fresh. Sleep and try again.
            sleep(RESIDUAL_POLL_INTERVAL_EMPTY)
            continue
        end

        # GRUG: Process the batch. This is where chatter afterimages become
        # relational data.
        processed = process_residual_batch!(fresh;
            co_occur_fn = co_occur_fn,
            token_overlap_fn = token_overlap_fn,
            node_map_ref = node_map_ref,
            node_lock_ref = node_lock_ref,
        )

        if processed > 0
            # GRUG: Report what we mined.
            println("[CHATTER_RESIDUALS] 🔮  Mined $(processed) chatter residual(s) into relational data")
        end

        # GRUG: Brief sleep after processing — there might be more fresh swaps.
        sleep(RESIDUAL_POLL_INTERVAL_AFTER_BATCH)
    end
end

"""
    stop_chatter_residuals_thread!()

GRUG: Signal the background thread to stop. It will finish its current
batch and then exit. Does NOT wait for it — just sets the flag.
"""
function stop_chatter_residuals_thread!()
    _RESIDUAL_THREAD_RUNNING[] = false
    println("[CHATTER_RESIDUALS] 🛑 Stop signal sent to background thread.")
end

# ==============================================================================
# STATUS & DIAGNOSTICS
# ==============================================================================

"""
    get_chatter_residuals_status()::String

GRUG: Human-readable status of the chatter residuals thread.
"""
function get_chatter_residuals_status()::String
    lines = String[]
    push!(lines, "═══ CHATTER RESIDUALS ═══")
    push!(lines, "  Thread running      : $(_RESIDUAL_THREAD_RUNNING[])")
    push!(lines, "  Ledger entries      : $(residual_ledger_size()) / $(RESIDUAL_LEDGER_CAP)")
    push!(lines, "  Total swaps consumed: $(_RESIDUAL_STATS[])")
    push!(lines, "  Co-occur observations: $(_RESIDUAL_CO_OCCUR_OBS[])")
    push!(lines, "  Votes stolen (remix): $(_RESIDUAL_VOTES_STOLEN[])")
    push!(lines, "  Votes refused       : $(_RESIDUAL_VOTES_FAILED[])")
    push!(lines, "  Batches processed   : $(_RESIDUAL_BATCHES[])")
    if _RESIDUAL_LAST_BATCH_TIME[] > 0
        ago = round(time() - _RESIDUAL_LAST_BATCH_TIME[], digits=1)
        push!(lines, "  Last batch          : $(ago)s ago")
    else
        push!(lines, "  Last batch          : never")
    end
    push!(lines, "  Batch size          : $(RESIDUAL_BATCH_SIZE)")
    push!(lines, "  Min threshold       : $(RESIDUAL_MIN_BATCH_THRESHOLD)")
    push!(lines, "  Co-occur increment  : $(CHATTER_CO_OCCUR_INCREMENT)")
    push!(lines, "  Confidence floor    : $(CONFIDENCE_SIMILARITY_FLOOR) ± $(CONFIDENCE_SIMILARITY_JITTER_SIGMA)")
    push!(lines, "  Markov blend bias   : $(MARKOV_BLEND_BIAS)")
    push!(lines, "  Weight blend (recv) : $(WEIGHT_BLEND_RECEIVER_SHARE)")
    push!(lines, "  Poll (empty)        : $(RESIDUAL_POLL_INTERVAL_EMPTY)s")
    push!(lines, "  Poll (after)        : $(RESIDUAL_POLL_INTERVAL_AFTER_BATCH)s")
    return join(lines, "\n")
end

# ==============================================================================
# SERIALIZATION — for specimen save/load
# ==============================================================================

"""
    serialize_chatter_residuals()::Dict{String, Any}

GRUG: Serialize the ledger for specimen save. Only the hash keys are
saved (values are always true). Keeps specimens compact.
"""
function serialize_chatter_residuals()::Dict{String, Any}
    hash_list = lock(_RESIDUAL_LEDGER_LOCK) do
        [string(h) for h in keys(_RESIDUAL_LEDGER)]
    end

    return Dict{String, Any}(
        "ledger_hashes"       => hash_list,
        "total_consumed"      => _RESIDUAL_STATS[],
        "co_occur_observations" => _RESIDUAL_CO_OCCUR_OBS[],
        "votes_stolen"        => _RESIDUAL_VOTES_STOLEN[],
        "votes_failed"        => _RESIDUAL_VOTES_FAILED[],
        "batches_processed"   => _RESIDUAL_BATCHES[],
        "ledger_cap"          => RESIDUAL_LEDGER_CAP,
    )
end

"""
    deserialize_chatter_residuals!(data)

GRUG: Restore the ledger from specimen data. Merges with existing ledger.
"""
function deserialize_chatter_residuals!(data)
    hash_list = get(data, "ledger_hashes", [])

    lock(_RESIDUAL_LEDGER_LOCK) do
        for h_str in hash_list
            h = parse(UInt64, String(h_str))
            if !haskey(_RESIDUAL_LEDGER, h)
                _RESIDUAL_LEDGER[h] = true
            end
        end
        # GRUG: Enforce cap after deserialization
        while length(_RESIDUAL_LEDGER) > RESIDUAL_LEDGER_CAP
            keys_vec = collect(keys(_RESIDUAL_LEDGER))
            delete!(_RESIDUAL_LEDGER, keys_vec[rand(1:length(keys_vec))])
        end
    end

    # GRUG: Restore counters (take max — they only grow)
    _RESIDUAL_STATS[] = max(_RESIDUAL_STATS[], get(data, "total_consumed", 0))
    _RESIDUAL_CO_OCCUR_OBS[] = max(_RESIDUAL_CO_OCCUR_OBS[], get(data, "co_occur_observations", 0))
    _RESIDUAL_BATCHES[] = max(_RESIDUAL_BATCHES[], get(data, "batches_processed", 0))
    _RESIDUAL_VOTES_STOLEN[] = max(_RESIDUAL_VOTES_STOLEN[], get(data, "votes_stolen", 0))
    _RESIDUAL_VOTES_FAILED[] = max(_RESIDUAL_VOTES_FAILED[], get(data, "votes_failed", 0))
end

"""
    reset_chatter_residuals!()

GRUG: Clear the entire ledger and reset counters. For testing.
"""
function reset_chatter_residuals!()
    lock(_RESIDUAL_LEDGER_LOCK) do
        empty!(_RESIDUAL_LEDGER)
    end
    _RESIDUAL_STATS[] = 0
    _RESIDUAL_BATCHES[] = 0
    _RESIDUAL_LAST_BATCH_TIME[] = 0.0
    _RESIDUAL_CO_OCCUR_OBS[] = 0
    _RESIDUAL_VOTES_STOLEN[] = 0
    _RESIDUAL_VOTES_FAILED[] = 0
end

end # module ChatterResiduals
