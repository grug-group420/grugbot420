# InputQueue.jl — GRUG Input Queue and NegativeThesaurus inhibition system
# GRUG say: queue is like waiting line at cave. Inputs wait their turn, processed in order.
# GRUG say: NegativeThesaurus is cave wall of bad words. Words listed here get penalized before scan.

module InputQueue
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


# ============================================================================
# CONSTANTS — GRUG like numbers in one place
# ============================================================================

const QUEUE_MAX_SIZE  = 512    # GRUG: Cave queue has a size limit. Overflow is fatal!
const NEG_THESAURUS_MAX = 256  # GRUG: Max inhibition entries. Prevents memory bloat.

# ============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ============================================================================

struct InputQueueError <: Exception
    message::String
    context::String
end

function throw_queue_error(msg::String, ctx::String = "unknown")
    throw(InputQueueError(msg, ctx))
end

# ============================================================================
# INPUT QUEUE — FIFO buffer for batched input processing
# ============================================================================

"""
InputEntry

GRUG: One item waiting in the queue.
  - text:       raw input string
  - priority:   higher number = higher priority (default 0 = normal)
  - enqueued_at: unix timestamp for age tracking
"""
struct InputEntry
    text::String
    priority::Int
    enqueued_at::Float64
end

# GRUG: The queue. Mutable so Grug can push and pop.
const _QUEUE = InputEntry[]
const _QUEUE_LOCK = ReentrantLock()

"""
enqueue!(text::String; priority::Int=0)

GRUG: Push a new input into the queue. Error if queue is full.
Priority 0 = normal. Higher = processes first (queue sorts by priority desc, then FIFO).
"""
function enqueue!(text::String; priority::Int = 0)
    if strip(text) == ""
        throw_queue_error("Cannot enqueue empty text!", "enqueue!")
    end
    lock(_QUEUE_LOCK) do
        if length(_QUEUE) >= QUEUE_MAX_SIZE
            throw_queue_error(
                "Input queue is full! Max size: $QUEUE_MAX_SIZE. Drain queue before enqueuing more.",
                "enqueue!"
            )
        end
        push!(_QUEUE, InputEntry(text, priority, time()))
        # GRUG: Sort by priority descending, preserving insertion order for equal priority (stable sort)
        sort!(_QUEUE; by = e -> e.priority, rev = true, alg = Base.Sort.MergeSort)
    end
    return nothing
end

"""
dequeue!()::Union{InputEntry, Nothing}

GRUG: Pop the next input from queue. Returns nothing if empty.
"""
function dequeue!()::Union{InputEntry, Nothing}
    lock(_QUEUE_LOCK) do
        isempty(_QUEUE) ? nothing : popfirst!(_QUEUE)
    end
end

"""
peek_queue()::Vector{InputEntry}

GRUG: Read all current queue entries without removing them. Returns snapshot copy.
"""
function peek_queue()::Vector{InputEntry}
    lock(_QUEUE_LOCK) do
        copy(_QUEUE)
    end
end

"""
queue_size()::Int

GRUG: How many items waiting in queue?
"""
function queue_size()::Int
    lock(_QUEUE_LOCK) do
        length(_QUEUE)
    end
end

"""
flush_queue!()::Int

GRUG: Wipe entire queue. Returns how many items were dropped.
"""
function flush_queue!()::Int
    lock(_QUEUE_LOCK) do
        n = length(_QUEUE)
        empty!(_QUEUE)
        n
    end
end

# ============================================================================
# NEGATIVE THESAURUS — Inhibition word registry
# ============================================================================

"""
NegEntry

GRUG: One inhibition entry.
  - word:    the inhibited word/phrase (lowercased, stripped)
  - reason:  why it is inhibited (for audit logging)
  - added_at: timestamp
"""
struct NegEntry
    word::String
    reason::String
    added_at::Float64
end

# GRUG: The inhibition registry. Dict for O(1) lookup.
const _NEG_THESAURUS = Dict{String, NegEntry}()
const _NEG_LOCK = ReentrantLock()

"""
add_inhibition!(word::String; reason::String="")

GRUG: Register a word/phrase as inhibited. Lowercases and strips before storing.
Error if already registered (Grug no like duplicate rules).
Error if limit reached.
"""
function add_inhibition!(word::String; reason::String = "")
    clean = strip(lowercase(word))
    if isempty(clean)
        throw_queue_error("Cannot inhibit empty word!", "add_inhibition!")
    end
    lock(_NEG_LOCK) do
        if haskey(_NEG_THESAURUS, clean)
            throw_queue_error(
                "Word '$clean' already in NegativeThesaurus! Use remove_inhibition! first to update.",
                "add_inhibition!"
            )
        end
        if length(_NEG_THESAURUS) >= NEG_THESAURUS_MAX
            throw_queue_error(
                "NegativeThesaurus is full! Max entries: $NEG_THESAURUS_MAX",
                "add_inhibition!"
            )
        end
        _NEG_THESAURUS[clean] = NegEntry(clean, reason, time())
    end
    return nothing
end

"""
remove_inhibition!(word::String)::Bool

GRUG: Remove a word from the inhibition list. Returns true if found and removed, false if not present.
"""
function remove_inhibition!(word::String)::Bool
    clean = strip(lowercase(word))
    lock(_NEG_LOCK) do
        haskey(_NEG_THESAURUS, clean) ? (delete!(_NEG_THESAURUS, clean); true) : false
    end
end

"""
is_inhibited(word::String)::Bool

GRUG: Check if a word is in the NegativeThesaurus. O(1) lookup.
"""
function is_inhibited(word::String)::Bool
    clean = strip(lowercase(word))
    lock(_NEG_LOCK) do
        haskey(_NEG_THESAURUS, clean)
    end
end

"""
list_inhibitions()::Vector{NegEntry}

GRUG: Get all current inhibition entries sorted alphabetically.
"""
function list_inhibitions()::Vector{NegEntry}
    lock(_NEG_LOCK) do
        sort(collect(values(_NEG_THESAURUS)); by = e -> e.word)
    end
end

"""
inhibition_count()::Int

GRUG: How many words currently inhibited?
"""
function inhibition_count()::Int
    lock(_NEG_LOCK) do
        length(_NEG_THESAURUS)
    end
end

"""
apply_inhibition_filter(tokens::Vector{String})::Vector{String}

GRUG: Given a list of input tokens, remove any that appear in NegativeThesaurus.
Returns filtered list. Non-mutating (returns new vector).
"""
function apply_inhibition_filter(tokens::Vector{String})::Vector{String}
    if isempty(tokens)
        throw_queue_error("Cannot filter empty token list!", "apply_inhibition_filter")
    end
    lock(_NEG_LOCK) do
        filter(t -> !haskey(_NEG_THESAURUS, strip(lowercase(t))), tokens)
    end
end

"""
apply_inhibition_to_text(text::String)::Tuple{String, Vector{String}}

GRUG: Split text into tokens, filter inhibited tokens, rejoin.
Returns (filtered_text, removed_tokens).
Throws if result is empty string (all tokens were inhibited — suspicious!).
"""
function apply_inhibition_to_text(text::String)::Tuple{String, Vector{String}}
    if strip(text) == ""
        throw_queue_error("Cannot apply inhibition filter to empty text!", "apply_inhibition_to_text")
    end
    tokens = split(text)
    token_strs = String[string(t) for t in tokens]
    filtered = apply_inhibition_filter(token_strs)
    removed  = setdiff(token_strs, filtered)
    if isempty(filtered)
        throw_queue_error(
            "NegativeThesaurus filtered ALL tokens from input! Input was: '$text'. " *
            "This is suspicious — check inhibition list for over-blocking.",
            "apply_inhibition_to_text"
        )
    end
    return join(filtered, " "), removed
end

# ============================================================================
# GRUG v9.4: NEGATIVE THESAURUS — CONTEXT LEDGER (synonym-pair edge cases)
# ============================================================================
# GRUG say: a word is not always one meaning! "Race" the contest and "race"
# the human race are same spelling, different sense. Thesaurus does not know
# the difference — it just sees "race" has synonyms in both senses mixed
# together. Same trouble other way: "deep" the adjective ("deep water") gets
# swapped for "abyss" the noun, "keep" the behavior-verb ("keep a promise")
# gets swapped for "store" the inventory-verb, "time" gets swapped for
# "epoch" in a proper-noun-like context ("Time node" -> "Epoch node"),
# "effect" gets swapped for "result" inside the fixed idiom "cause and
# effect". None of these words are BAD — only ONE DIRECTION of ONE
# SUBSTITUTION is bad, in a specific context. Blocking the whole word (old
# is_inhibited single-word blacklist above) is too blunt: it would ban
# "abyss" from ever being used for ANY word, everywhere, forever.
#
# The fix: NegativeThesaurus is not (only) a word blacklist. It is a LEDGER
# OF EDGE CASES — specific (word, synonym) PAIRS that are known-bad
# substitutions. Either side of a pair MAY be more than one word ("you're"
# <-> "you are" is a perfectly normal single-token <-> two-token synonym
# pair, and the ledger must be able to record an edge case against either
# side of that just as easily as against single words).
#
# This pair ledger is checked in BOTH directions GrugBot touches synonyms:
#   (a) PATTERN FAN-OUT / ACTIVATION — Thesaurus.thesaurus_gate_filter
#       expands input tokens into a synonym cloud so nodes can match via
#       synonymy. A blocked pair must not be injected into that cloud (so
#       "deep water" does not spuriously activate an "abyss"-tagged node).
#   (b) ORCHESTRATION / ANTI-STALE OUTPUT SWAP — _pick_synonym,
#       _light_thesaurus_touch, _hippocampal_touch, _vote_word_swap in
#       Main.jl pick random eligible words from the locked-in answer and
#       swap in a thesaurus alternative to keep responses fresh. A blocked
#       pair must not be chosen there either — staleness prevention should
#       never produce a nonsensical substitution.
#
# Word-level is_inhibited (above) still exists unchanged for the different,
# coarser use case of stripping a word out of the input stream entirely
# (e.g. operator has decided "incorrect"/"fake"/"nonsense" should never be
# treated as content at all). The pair ledger is additive, not a
# replacement — most of the time whole-word inhibition is NOT what you
# want (that's the "not how it is currently being done" gap): you want to
# forbid ONE substitution direction while leaving the word free everywhere
# else.
# ============================================================================

"""
NegPairEntry

GRUG: One synonym-pair edge case. `word` and `synonym` are each stored
lowercased+stripped, and may contain internal spaces (multi-word phrases
like "you are" are valid on either side). `bidirectional` — if true (the
default), the exception blocks the substitution in BOTH directions
(word->synonym AND synonym->word). Most register/context mistakes are
symmetric ("deep"->"abyss" is exactly as wrong as "abyss"->"deep" in
general prose), so bidirectional=true is the sane default; set it false
only when you are sure just one direction is bad.
"""
struct NegPairEntry
    word::String
    synonym::String
    reason::String
    added_at::Float64
    bidirectional::Bool
end

# GRUG: canonical key for a (word,synonym) pair — lowercase+strip both sides.
_pair_key(w::AbstractString, s::AbstractString) = (strip(lowercase(String(w))), strip(lowercase(String(s))))

# GRUG: the ledger. Keyed on the FIRST word of the pair (as originally
# registered) -> Dict of synonym -> entry. Bidirectional entries are
# mirrored into the reverse word's bucket too at insert time, so lookup
# from EITHER side is a plain O(1) dict hit — no need to scan both
# directions at query time.
const _NEG_PAIRS = Dict{String, Dict{String, NegPairEntry}}()
const _NEG_PAIRS_LOCK = ReentrantLock()

"""
add_synonym_exception!(word::String, synonym::String; reason::String="", bidirectional::Bool=true)

GRUG: Register a (word, synonym) pair as a known-bad substitution — a
context edge case, NOT a full word ban. Either side may be a multi-word
phrase ("you're" / "you are"). Errors if the exact pair is already
registered (use remove_synonym_exception! first to update) or the ledger
is full.
"""
function add_synonym_exception!(word::String, synonym::String; reason::String = "", bidirectional::Bool = true)
    w, s = _pair_key(word, synonym)
    if isempty(w) || isempty(s)
        throw_queue_error("Cannot register empty word/synonym exception!", "add_synonym_exception!")
    end
    if w == s
        throw_queue_error("Word and synonym cannot be identical: '$w'", "add_synonym_exception!")
    end
    lock(_NEG_PAIRS_LOCK) do
        if haskey(_NEG_PAIRS, w) && haskey(_NEG_PAIRS[w], s)
            throw_queue_error(
                "Pair '$w' <-> '$s' already in NegativeThesaurus context ledger! Use remove_synonym_exception! first to update.",
                "add_synonym_exception!"
            )
        end
        n_total = sum(length(v) for v in values(_NEG_PAIRS); init = 0)
        if n_total >= NEG_THESAURUS_MAX
            throw_queue_error(
                "NegativeThesaurus context ledger is full! Max entries: $NEG_THESAURUS_MAX",
                "add_synonym_exception!"
            )
        end
        entry = NegPairEntry(w, s, reason, time(), bidirectional)
        get!(_NEG_PAIRS, w, Dict{String, NegPairEntry}())[s] = entry
        if bidirectional
            get!(_NEG_PAIRS, s, Dict{String, NegPairEntry}())[w] = entry
        end
    end
    return nothing
end

"""
remove_synonym_exception!(word::String, synonym::String)::Bool

GRUG: Remove a (word, synonym) edge case (both directions, if it was
bidirectional). Returns true if found and removed, false if not present.
"""
function remove_synonym_exception!(word::String, synonym::String)::Bool
    w, s = _pair_key(word, synonym)
    lock(_NEG_PAIRS_LOCK) do
        found = false
        if haskey(_NEG_PAIRS, w) && haskey(_NEG_PAIRS[w], s)
            was_bidi = _NEG_PAIRS[w][s].bidirectional
            delete!(_NEG_PAIRS[w], s)
            isempty(_NEG_PAIRS[w]) && delete!(_NEG_PAIRS, w)
            found = true
            if was_bidi && haskey(_NEG_PAIRS, s) && haskey(_NEG_PAIRS[s], w)
                delete!(_NEG_PAIRS[s], w)
                isempty(_NEG_PAIRS[s]) && delete!(_NEG_PAIRS, s)
            end
        end
        return found
    end
end

"""
is_synonym_blocked(word::String, synonym::String)::Bool

GRUG: Check whether substituting `synonym` for `word` (in either literal
direction of lookup — caller may pass either order) is a registered edge
case. O(1) lookup. This is the check that ORCHESTRATION synonym-swap code
and ACTIVATION gate-expansion code both call before actually using a
candidate synonym.
"""
function is_synonym_blocked(word::String, synonym::String)::Bool
    w, s = _pair_key(word, synonym)
    lock(_NEG_PAIRS_LOCK) do
        haskey(_NEG_PAIRS, w) && haskey(_NEG_PAIRS[w], s)
    end
end

"""
list_synonym_exceptions()::Vector{NegPairEntry}

GRUG: All registered edge-case pairs, deduplicated (bidirectional pairs
are stored twice internally — once per direction — but listed once here),
sorted by word then synonym.
"""
function list_synonym_exceptions()::Vector{NegPairEntry}
    lock(_NEG_PAIRS_LOCK) do
        seen = Set{Tuple{String,String}}()
        out = NegPairEntry[]
        for (w, inner) in _NEG_PAIRS
            for (s, entry) in inner
                key = w <= s ? (w, s) : (s, w)
                if !(key in seen)
                    push!(seen, key)
                    push!(out, entry)
                end
            end
        end
        sort(out; by = e -> (e.word, e.synonym))
    end
end

"""
synonym_exception_count()::Int

GRUG: How many UNIQUE edge-case pairs currently registered (bidirectional
pairs counted once).
"""
function synonym_exception_count()::Int
    length(list_synonym_exceptions())
end

"""
flush_synonym_exceptions!()

GRUG: Remove ALL synonym-pair edge cases. Destructive. Does not touch the
separate whole-word inhibition list (_NEG_THESAURUS) — flush that
independently via /negativeThesaurus flush if needed.
"""
function flush_synonym_exceptions!()
    lock(_NEG_PAIRS_LOCK) do
        empty!(_NEG_PAIRS)
    end
    return nothing
end

# GRUG v9.4: Default-seeded edge cases — the exact register-swap mistakes
# already caught and documented (Coherence Fix Notes on threadC test log):
#   "deep" (adjective, "deep water") mistakenly swapped for "abyss" (noun)
#   "keep" (behavioral verb, "keep a promise") mistakenly swapped for
#       "store" (inventory/save verb)
#   "time" mistakenly swapped for "epoch" in proper-noun-like usage
#       ("Time node" -> "Epoch node" — wrong register, reads like a
#       geological era label instead of the lobe name)
#   "effect" mistakenly swapped for "result" inside the fixed idiom
#       "cause and effect" ("cause and result" is not an idiom in English)
# These are seeded once at module load so the exact reported bugs are
# fixed out of the box; operators can add more via /negativeThesaurus
# addPair as new edge cases are discovered — this is a growing ledger,
# not a fixed list.
function _seed_default_synonym_exceptions!()
    _defaults = [
        ("deep",   "abyss",  "deep is commonly the adjective in \"deep water\"; abyss is a noun for extreme depth — register-swap artifact"),
        ("keep",   "store",  "keep in behavioral/promise sense (\"keep a promise\", \"keep calm\") vs store's inventory/save sense — context mismatch"),
        ("time",   "epoch",  "epoch reads as a specific geological/historical era, not a substitute for general \"time\" (e.g. \"Time node\" -> \"Epoch node\" is wrong register)"),
        ("effect", "result", "\"cause and effect\" is a fixed idiom; \"cause and result\" is not natural English"),
    ]
    for (w, s, r) in _defaults
        try
            add_synonym_exception!(w, s; reason = r, bidirectional = true)
        catch e
            # GRUG: already present (e.g. re-included module) — non-fatal.
            e isa InputQueueError || rethrow()
        end
    end
end
_seed_default_synonym_exceptions!()

end # module InputQueue