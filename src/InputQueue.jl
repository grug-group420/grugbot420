# InputQueue.jl — GRUG Input Queue and NegativeThesaurus inhibition system
# GRUG say: queue is like waiting line at cave. Inputs wait their turn, processed in order.
# GRUG say: NegativeThesaurus is cave wall of bad words. Words listed here get penalized before scan.

module InputQueue

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

# ============================================================================
# CONCEPT-CLASS INHIBITION (v7.16.0)
# GRUG: Normal inhibition is word-at-a-time. Concept-class inhibition bans
# an ENTIRE concept -- e.g. inhibit "inquiry" and now every word in the
# Thesaurus.CONCEPT_CLASS_MEMBERS["inquiry"] set is considered inhibited.
# Stored separately so the two systems stay clean:
#   _NEG_THESAURUS     -> word-level bans (existing)
#   _NEG_CONCEPT_BANS  -> concept-name-level bans (new)
# is_inhibited(word) consults BOTH -- word-ban OR any-concept-ban containing word.
# ============================================================================
const _NEG_CONCEPT_BANS      = Dict{String, NegEntry}()
const _NEG_CONCEPT_BANS_LOCK = ReentrantLock()

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
v7.16.0: also returns true if the word belongs to any concept class that is
currently concept-banned. This lets operators ban a whole concept in one shot.
Word-ban + concept-ban are OR'd -- either blocks the word.
"""
function is_inhibited(word::String)::Bool
    clean = strip(lowercase(word))
    # GRUG: word-level check (existing semantic)
    word_banned = lock(_NEG_LOCK) do
        haskey(_NEG_THESAURUS, clean)
    end
    word_banned && return true
    # GRUG v7.16.0: concept-level check. Ask Thesaurus which classes contain
    # this word, then see if any of those classes is banned. Done under the
    # concept-ban lock so a ban in flight cannot tear.
    return is_concept_inhibited(String(clean))
end

"""
is_concept_inhibited(word::String)::Bool

GRUG v7.16.0: Return true if any concept class containing `word` is banned.
Cheaper than is_inhibited when the caller only wants concept-level semantics.
Never throws -- unknown words return false (not in any class -> not banned).
"""
function is_concept_inhibited(word::String)::Bool
    clean = strip(lowercase(word))
    isempty(clean) && return false
    # GRUG: Thesaurus module may not be loaded in every context (e.g. isolated
    # unit tests of InputQueue alone). Guard the lookup so we never crash the
    # inhibition check. NO SILENT FAIL -- @warn if the module is missing when
    # concept bans exist (that would be a real architectural bug).
    parent = parentmodule(@__MODULE__)
    thesaurus_mod = nothing
    if isdefined(parent, :Thesaurus)
        thesaurus_mod = getfield(parent, :Thesaurus)
    elseif isdefined(@__MODULE__, :Thesaurus)
        thesaurus_mod = getfield(@__MODULE__, :Thesaurus)
    end

    if thesaurus_mod === nothing
        # GRUG: No Thesaurus available. If there are concept bans registered,
        # something is wrong -- scream. If not, silently fine.
        has_bans = lock(_NEG_CONCEPT_BANS_LOCK) do
            !isempty(_NEG_CONCEPT_BANS)
        end
        if has_bans
            @warn "[NegativeThesaurus v7.16.0] Concept bans exist but Thesaurus module not reachable. Concept-level inhibition BYPASSED for '$clean'."
        end
        return false
    end

    local classes::Set{String}
    try
        classes = thesaurus_mod.concept_classes_of(clean)
    catch e
        @warn "[NegativeThesaurus v7.16.0] Thesaurus.concept_classes_of('$clean') threw $e; treating as no classes."
        return false
    end
    isempty(classes) && return false
    return lock(_NEG_CONCEPT_BANS_LOCK) do
        for c in classes
            haskey(_NEG_CONCEPT_BANS, c) && return true
        end
        return false
    end
end

"""
add_concept_inhibition!(concept_name::String; reason::String = "")

GRUG v7.16.0: Ban an entire concept class by name. Every word in
Thesaurus.CONCEPT_CLASS_MEMBERS[concept_name] becomes inhibited in one shot.
Throws if the concept class doesn't exist (can't ban what isn't defined)
or if it's already banned. NO SILENT FAILURES.
"""
function add_concept_inhibition!(concept_name::String; reason::String = "")
    clean = strip(lowercase(concept_name))
    if isempty(clean)
        throw_queue_error("Cannot concept-inhibit empty name!", "add_concept_inhibition!")
    end
    # GRUG: Reach Thesaurus. Same lookup pattern as is_concept_inhibited.
    parent = parentmodule(@__MODULE__)
    thesaurus_mod = nothing
    if isdefined(parent, :Thesaurus)
        thesaurus_mod = getfield(parent, :Thesaurus)
    elseif isdefined(@__MODULE__, :Thesaurus)
        thesaurus_mod = getfield(@__MODULE__, :Thesaurus)
    end
    if thesaurus_mod === nothing
        throw_queue_error("Thesaurus module not loaded. Cannot verify concept '$clean' exists.",
                          "add_concept_inhibition!")
    end
    # GRUG: Check class is real.
    class_names = Set(k for (k, _) in thesaurus_mod.list_concept_classes())
    if !(clean in class_names)
        throw_queue_error(
            "Concept class '$clean' does not exist. Use /conceptClass list to see defined classes.",
            "add_concept_inhibition!"
        )
    end
    lock(_NEG_CONCEPT_BANS_LOCK) do
        if haskey(_NEG_CONCEPT_BANS, clean)
            throw_queue_error(
                "Concept class '$clean' already inhibited. Use remove_concept_inhibition! first.",
                "add_concept_inhibition!"
            )
        end
        _NEG_CONCEPT_BANS[clean] = NegEntry(clean, reason, time())
    end
    return nothing
end

"""
remove_concept_inhibition!(concept_name::String)::Bool

GRUG v7.16.0: Lift a concept-class ban. Returns true if the ban existed,
false if nothing to remove.
"""
function remove_concept_inhibition!(concept_name::String)::Bool
    clean = strip(lowercase(concept_name))
    lock(_NEG_CONCEPT_BANS_LOCK) do
        haskey(_NEG_CONCEPT_BANS, clean) ? (delete!(_NEG_CONCEPT_BANS, clean); true) : false
    end
end

"""
list_concept_inhibitions()::Vector{NegEntry}

GRUG v7.16.0: Return all active concept-class bans, sorted by name.
"""
function list_concept_inhibitions()::Vector{NegEntry}
    lock(_NEG_CONCEPT_BANS_LOCK) do
        sort(collect(values(_NEG_CONCEPT_BANS)); by = e -> e.word)
    end
end

"""
concept_inhibition_count()::Int

GRUG v7.16.0: How many concept classes currently banned?
"""
function concept_inhibition_count()::Int
    lock(_NEG_CONCEPT_BANS_LOCK) do
        length(_NEG_CONCEPT_BANS)
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

end # module InputQueue