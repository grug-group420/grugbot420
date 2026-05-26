# Main.jl

# GRUG: When loaded as part of GrugBot420 package, CoinFlipHeader is already
# included and in scope from GrugBot420.jl. Only include/use it standalone.
if !isdefined(@__MODULE__, :CoinFlipHeader)
    include("stochastichelper.jl")
    using .CoinFlipHeader
end

# GRUG: LobeOrchestrator — averages-curve lobe selection (replaces the
# v7.18 hard mute gate). engine.jl references LobeOrchestrator inside
# scan_and_expand, so this must be in scope BEFORE engine.jl is included.
# Guard against double-include for the package-level path.
if !isdefined(@__MODULE__, :LobeOrchestrator)
    include("LobeOrchestrator.jl")
    using .LobeOrchestrator
end

# GRUG: Include engine after macro is alive. Engine need coinflip!
# Engine.jl now includes patternscanner.jl, ImageSDF.jl and EyeSystem.jl internally.
include("engine.jl")

# GRUG: Bring the Chatter Mode gossip system into the cave!
# GRUG: Guard against double-include if ChatterMode already loaded by caller.
if !isdefined(@__MODULE__, :ChatterMode)
    include("ChatterMode.jl")
    using .ChatterMode
end

# GRUG: Bring the Phagy Mode maintenance automata into the cave!
# GRUG: DISABLED - PhagyMode has been commented out throughout the codebase.
# Phagy automata should only be used for long-running systems with large-scale
# memory management needs. For specimen testing and development, the overhead
# is unnecessary. Uncomment when running long-term production instances.
#
# Original functionality:
# # GRUG: Guard against double-include if PhagyMode already loaded by caller.
# if !isdefined(@__MODULE__, :PhagyMode)
#     include("PhagyMode.jl")
#     using .PhagyMode
# end

# GRUG: Bring the Thesaurus dimensional similarity engine into the cave!
# GRUG: Guard against double-include if Thesaurus already loaded by caller.
if !isdefined(@__MODULE__, :Thesaurus)
    include("Thesaurus.jl")
    using .Thesaurus
end

# GRUG: LobeTable MUST be included BEFORE Lobe.jl. Lobe.jl uses LobeTable
# functions (create_lobe_table!, node_ref_put!, etc.) and if Lobe.jl includes
# its own copy of LobeTable.jl into its submodule scope, you end up with TWO
# separate LobeTable instances at runtime — one inside Lobe, one inside Main —
# with separate registries that don't see each other's tables. That was a real
# bug (see plans/semantic_plugins/QOL_SWEEP_2025.md BUG-002). Single source of
# truth: include LobeTable here, then Lobe.jl pulls it from the parent scope.
if !isdefined(@__MODULE__, :LobeTable)
    include("LobeTable.jl")
    using .LobeTable
end

# GRUG: Bring the Lobe partitioning system into the cave!
# GRUG: Guard against double-include if Lobe already loaded by caller.
# Lobe expects LobeTable to already be in the parent module's scope.
if !isdefined(@__MODULE__, :Lobe)
    include("Lobe.jl")
    using .Lobe
end

# GRUG: Bring the BrainStem winner-take-all dispatcher into the cave!
# GRUG: Guard against double-include if BrainStem already loaded by caller.
if !isdefined(@__MODULE__, :BrainStem)
    include("BrainStem.jl")
    using .BrainStem
end

# GRUG: Bring the InputQueue and NegativeThesaurus inhibition system into the cave!
# GRUG: Guard against double-include if InputQueue already loaded by caller.
if !isdefined(@__MODULE__, :InputQueue)
    include("InputQueue.jl")
    using .InputQueue
end

# GRUG: Bring the Immune System into the cave!
# GRUG: Guard against double-include if ImmuneSystem already loaded by caller.
if !isdefined(@__MODULE__, :ImmuneSystem)
    include("ImmuneSystem.jl")
    using .ImmuneSystem
end

using Base64: base64decode
using SHA: sha256
using JSON

# ==============================================================================
# MEMORY CAVE (PIN AWARENESS LAYER)
# ==============================================================================

# GRUG DOC 3.6: These big memory rocks disappear when Grug goes to sleep (CLI closes).
# Future Grug need to learn how to write on permanent cave walls (Persistence feature).
#
# GRUG v7.12: ChatMessage now carries an `intensity` field. Intensity lives in
# [CONTEXT_INTENSITY_FLOOR, CONTEXT_INTENSITY_CAP]. At the pattern-bind /
# relational phase of every /mission (before the AIML orchestrator runs),
# we score each message's relevance to the current user input (lexical token
# overlap + relational triple overlap), pull intensity toward that score
# (snap-back), then add the same zero-mean RelationalJitter nudge the rest
# of the engine uses so /brainstorm's heavy-jump mode automatically
# amplifies context drift. When building the Fresh Memory slice, unpinned
# messages are coinflipped in with `p = intensity / CAP`. Pinned messages
# still always survive. Net effect: irrelevant banners decay and stop
# appearing in future Fresh Memory blocks, which kills the O(N^2) context
# explosion we saw when every /mission re-embedded the last 5 system
# messages verbatim.
# GRUG v7.12: Context-intensity tuning knobs. Must be declared BEFORE the
# ChatMessage back-compat constructor that defaults to BASELINE. Reasonable
# defaults chosen to mirror the AIML strength cap style and the existing
# jitter ratios. All tunable later if needed. NO SILENT FAILURE:
# clamp_intensity below enforces the [FLOOR, CAP] interval.
const CONTEXT_INTENSITY_CAP      = 3.0    # Upper bound on per-message intensity
const CONTEXT_INTENSITY_FLOOR    = 0.0    # Lower bound; irrelevant msgs decay here
const CONTEXT_INTENSITY_BASELINE = 1.0    # New messages start here (neutral)
const CONTEXT_SNAP_ALPHA         = 0.35   # Pull strength toward current relevance
const CONTEXT_RELEVANCE_LEX_W    = 0.6    # Lexical token-overlap weight
const CONTEXT_RELEVANCE_REL_W    = 0.4    # Relational-triple overlap weight
const MAX_FRESH_CONTEXT          = 8      # Hard cap on post-coinflip Fresh Memory
const CONTEXT_COIN_P_FLOOR       = 0.05   # Minimum coinflip p even at intensity=0
const CONTEXT_COIN_P_CEIL        = 0.95   # Maximum coinflip p even at intensity=CAP
const CONTEXT_FEEDBACK_RIGHT_DELTA = 0.5  # /right bonus to last-selected messages
const CONTEXT_FEEDBACK_WRONG_DELTA = -0.5 # /wrong penalty to last-selected messages

# GRUG v7.13: Two-stage Fresh Memory gate — threshold-then-coinflip.
# AIML never sees anything below the threshold, so 10k-message caves do
# not explode the coinflip pool. The threshold auto-tunes each cycle so
# the *eligible* (above-threshold) unpinned set lands inside this band.
# Coinflip still runs within survivors → stochastic exploration preserved,
# O(N²) context bloat stays killed.
const CONTEXT_ELIGIBLE_MIN       = 5      # Prefer ≥5 unpinned messages above threshold
const CONTEXT_ELIGIBLE_MAX       = 10     # Prefer ≤10; tightens threshold otherwise
const CONTEXT_THRESHOLD_STEPS    = 12     # Binary-search budget (log₂ of CAP resolution)

# GRUG v7.17: Chunked Fresh Memory scan. When MESSAGE_HISTORY holds up
# to MAX_HISTORY (10,000) messages we do NOT scan the whole vector in
# one tight loop — we batch the scan into CONTEXT_SCAN_CHUNK-sized
# slices so:
#   * each pass checks an early-exit condition between chunks (e.g. the
#     threshold binary-search aborts a step as soon as the survivor
#     count exceeds CONTEXT_ELIGIBLE_MAX, no need to count the rest).
#   * we never hold a whole-history allocation in one go — the
#     unpinned materialisation appends chunk-by-chunk.
#   * CPU time per cycle is bounded by chunks_actually_scanned *
#     CONTEXT_SCAN_CHUNK rather than total_msgs, which is the
#     difference between "hits the target band in 1 chunk" and
#     "drags 10k messages through every cycle".
# Keeping this tunable lets operators dial scan granularity per deploy;
# 1000 is a solid default (fits in L1/L2 cache, ~8 KB of Float64s).
const CONTEXT_SCAN_CHUNK         = 1000   # Scan MESSAGE_HISTORY in 1k batches

# GRUG v7.17: Per-chunk DONE checkpoint counter. Every chunked scan
# site calls `_chunk_done!(label)` after each CONTEXT_SCAN_CHUNK-sized
# batch finishes — this yields the scheduler (so other Tasks on the
# same thread get a slot), increments a per-label counter (so tests
# and operators can verify "scan emitted N chunks for a 10k cave"),
# and emits a debug log entry gated behind CONTEXT_CHUNK_DEBUG.
#
# Contract: the scan does NOT move to its next 1k batch until
# _chunk_done! has run. That is the "submits DONE for everything to
# continue, then resume" semantics — the batch is published as a
# checkpoint before the next one begins, instead of the whole 10k
# scan running as one uninterruptible CPU burst.
const CONTEXT_CHUNK_DEBUG = Ref(false)           # operator toggle, /status-surfaceable
const CONTEXT_CHUNK_COUNTERS = Dict{String, Int}()  # label → chunks-done-since-start
const CONTEXT_CHUNK_LOCK = ReentrantLock()

function _chunk_done!(label::String)
    # 1) Record that this batch finished so tests and /status can see
    #    how many chunks a given scan site has emitted. Kept under a
    #    lock because MESSAGE_HISTORY scans may run from different
    #    Tasks (CLI + chatter + phagy) and we do not want torn reads.
    lock(CONTEXT_CHUNK_LOCK) do
        CONTEXT_CHUNK_COUNTERS[label] = get(CONTEXT_CHUNK_COUNTERS, label, 0) + 1
    end
    # 2) Optional debug trace.
    if CONTEXT_CHUNK_DEBUG[]
        @debug "[v7.17] chunk DONE" label=label count=CONTEXT_CHUNK_COUNTERS[label]
    end
    # 3) Cooperative yield — this is the "let everything continue"
    #    part of the contract. The scheduler gets a chance to run
    #    any waiting Task (CLI read, phagy pass, etc.) before we
    #    start the next 1k batch. Without this, a 10k scan is one
    #    uninterruptible unit even though we chunked it internally.
    yield()
    return nothing
end

"""
    reset_chunk_counters!()

GRUG v7.17: Zero every chunk-DONE counter. Tests call this before
running a scan so they can count exactly how many chunks fired for
the scan under test.
"""
function reset_chunk_counters!()
    lock(CONTEXT_CHUNK_LOCK) do
        empty!(CONTEXT_CHUNK_COUNTERS)
    end
end

"""
    get_chunk_counter(label)

GRUG v7.17: Read-only access to the per-label chunk-DONE counter.
Returns 0 if no chunk has ever been published for this label.
"""
function get_chunk_counter(label::String)::Int
    lock(CONTEXT_CHUNK_LOCK) do
        return get(CONTEXT_CHUNK_COUNTERS, label, 0)
    end
end

mutable struct ChatMessage
    id::Int
    role::String
    text::String
    pinned::Bool
    intensity::Float64    # GRUG v7.12: relevance-biased, jittered per cycle
end

# GRUG v7.12: Back-compat positional constructor — old call sites that pass
# four args default intensity to the baseline. NO SILENT FAILURE: we still
# go through the struct so Julia type-checks every field.
ChatMessage(id::Int, role::String, text::String, pinned::Bool) =
    ChatMessage(id, role, text, pinned, CONTEXT_INTENSITY_BASELINE)

const MAX_HISTORY   = 10000
const MESSAGE_HISTORY = Vector{ChatMessage}()
const MSG_ID_COUNTER       = Atomic{Int}(0)
const MESSAGE_HISTORY_LOCK = ReentrantLock()  # GRUG: Lock for phagy forensics read-access to MESSAGE_HISTORY

# GRUG v7.12: Track which messages contributed to the LAST /mission's
# Fresh Memory so /right and /wrong can reinforce/punish them. Reset at
# the top of every mission cycle via refresh_message_intensities!.
const LAST_SELECTED_MSG_IDS = Ref(Set{Int}())
const LAST_SELECTED_MSG_LOCK = ReentrantLock()

# GRUG FIX 3.1: Strict Role Validation!
# Grug no let random strangers paint on memory wall.
#
# GRUG 7.12-FIX: The ALLOWED_ROLES set was referenced by add_message_to_history!
# (see ~line 343) but never defined at module scope, causing every command that
# writes to MESSAGE_HISTORY (/mission, /grow, /addRule, /pin, /saveSpecimen,
# immune gates, etc.) to throw UndefVarError(:ALLOWED_ROLES). The outer CLI
# try/catch swallowed it as a SYSTEM ERROR banner so interactive users rarely
# noticed, but scripted pipelines hit it on every command. Role whitelist lives
# right next to MESSAGE_HISTORY so it stays under the same mental model.
# Matches the canonical set in test/test_chat_specimen.jl so both paths agree.
# NO SILENT FAILURE: any unknown role still throws loudly inside
# add_message_to_history!.
const ALLOWED_ROLES = Set{String}(["User", "System", "User_Pinned", "Engine_Voice"])

# ==============================================================================
# ADMIN COMMAND SYSTEM
# ==============================================================================
# GRUG: Some commands too dangerous for regular cave dwellers.
# /writeSave can inject arbitrary JSON into save files - MUST be admin-only.
# /login establishes admin session. Session expires after ADMIN_SESSION_TIMEOUT seconds.
# Password is stored hashed (SHA256) - never store plaintext!
# NO SILENT FAILURES: All admin operations log and validate loudly.

# GRUG: Default admin password. CHANGE THIS BEFORE DEPLOYMENT!
# To set custom password: set ADMIN_PASSWORD_HASH = bytes2hex(sha256("your_password"))
const ADMIN_PASSWORD_DEFAULT = "grug_cave_master_420"

# GRUG: SHA256 hash of default password. Computed at module load.
const ADMIN_PASSWORD_HASH = bytes2hex(sha256(ADMIN_PASSWORD_DEFAULT))

# GRUG: Session timeout in seconds (default: 1 hour)
const ADMIN_SESSION_TIMEOUT = 3600

# GRUG: Admin session state
mutable struct AdminSession
    is_logged_in::Bool
    login_time::Float64
    last_activity::Float64
end

const ADMIN_SESSION = Ref{AdminSession}(AdminSession(false, 0.0, 0.0))
const ADMIN_LOCK = ReentrantLock()

"""
    is_admin_logged_in()::Bool

GRUG: Check if admin session is active and not expired.
Returns true if logged in and within timeout, false otherwise.
Thread-safe: uses ADMIN_LOCK.
"""
function is_admin_logged_in()::Bool
    return lock(ADMIN_LOCK) do
        if !ADMIN_SESSION[].is_logged_in
            return false
        end
        # GRUG: Check session timeout
        elapsed = time() - ADMIN_SESSION[].last_activity
        if elapsed > ADMIN_SESSION_TIMEOUT
            # GRUG: Session expired - reset it
            ADMIN_SESSION[] = AdminSession(false, 0.0, 0.0)
            return false
        end
        # GRUG: Update last activity time
        ADMIN_SESSION[] = AdminSession(true, ADMIN_SESSION[].login_time, time())
        return true
    end
end

"""
    admin_login(password::String)::Tuple{Bool, String}

GRUG: Attempt admin login with provided password.
Returns (success, message) tuple. On success, establishes session.
On failure, returns false with error message. NO SILENT FAILURES.
"""
function admin_login(password::String)::Tuple{Bool, String}
    if strip(password) == ""
        return (false, "⛔ Password cannot be empty!")
    end
    
    # GRUG: Hash the provided password and compare
    provided_hash = bytes2hex(sha256(password))
    
    return lock(ADMIN_LOCK) do
        if provided_hash == ADMIN_PASSWORD_HASH
            now = time()
            ADMIN_SESSION[] = AdminSession(true, now, now)
            return (true, "✅ Admin login successful. Session active for $(ADMIN_SESSION_TIMEOUT) seconds of inactivity.")
        else
            # GRUG: Log failed attempt (but don't expose password hash)
            @warn "[ADMIN] Failed login attempt at $(time())"
            return (false, "⛔ Invalid password. Access denied.")
        end
    end
end

"""
    admin_logout()::String

GRUG: Terminate admin session. Returns confirmation message.
"""
function admin_logout()::String
    return lock(ADMIN_LOCK) do
        if ADMIN_SESSION[].is_logged_in
            ADMIN_SESSION[] = AdminSession(false, 0.0, 0.0)
            return "✅ Admin session terminated."
        else
            return "ℹ️ No active admin session to terminate."
        end
    end
end

"""
    validate_json(json_str::String)::Tuple{Bool, String}

GRUG: Validate that a string is valid JSON.
Returns (is_valid, error_message) tuple.
If valid, error_message is empty string.
"""
function validate_json(json_str::String)::Tuple{Bool, String}
    if strip(json_str) == ""
        return (false, "JSON string is empty!")
    end
    
    try
        # GRUG: Try to parse the JSON
        parsed = JSON.parse(json_str)
        return (true, "")
    catch e
        return (false, "JSON parse error: $(e)")
    end
end

"""
    append_to_save_file(json_str::String, save_filepath::String)::String

GRUG: Append validated JSON to the specimen save file.
Reads existing save file, merges/appends JSON, writes back.
Requires admin login. NO SILENT FAILURES.
Uses system gzip like save_specimen_to_file! - no extra packages needed.

Returns summary string on success, throws on failure.
"""
function append_to_save_file(json_str::String, save_filepath::String)::String
    # GRUG: Pre-flight checks
    if !is_admin_logged_in()
        error("!!! FATAL: /writeSave requires admin login! Use /login first! !!!")
    end
    
    if strip(json_str) == ""
        error("!!! FATAL: /writeSave got empty JSON! Grug cannot write nothing! !!!")
    end
    
    if strip(save_filepath) == ""
        error("!!! FATAL: /writeSave got empty filepath! Grug cannot write to invisible air! !!!")
    end
    
    # GRUG: Validate JSON
    is_valid, json_err = validate_json(json_str)
    if !is_valid
        error("!!! FATAL: /writeSave JSON validation failed: $json_err !!!")
    end
    
    # GRUG: Parse the new JSON
    new_data = JSON.parse(json_str)
    
    # GRUG: Check if save file exists
    if !isfile(save_filepath)
        # GRUG: File doesn't exist - create new file with the JSON
        # Wrap in specimen structure if not already
        specimen = Dict{String, Any}(
            "format_version" => "2.1",
            "created_at" => time(),
            "custom_append" => new_data
        )
        
        json_out = JSON.json(specimen)
        
        # GRUG: Use system gzip like save_specimen_to_file! - no extra packages needed
        try
            open(save_filepath, "w") do io
                proc = open(`gzip -c`, "r+")
                write(proc, json_out)
                close(proc.in)
                compressed = read(proc)
                write(io, compressed)
            end
        catch e
            error("!!! FATAL: /writeSave failed to write compressed file '$save_filepath': $e !!!")
        end
        
        return "✅ Created new save file: $save_filepath with appended JSON."
    end
    
    # GRUG: File exists - read, merge, write back
    try
        # GRUG: Decompress existing file using system gunzip
        json_str_existing = read(`gunzip -c $save_filepath`, String)
        existing = JSON.parse(json_str_existing)
        
        # GRUG: Merge/append the new data
        # If new_data is a dict, merge into existing
        # If new_data is a list, append to appropriate array
        if isa(new_data, Dict)
            for (key, value) in new_data
                if haskey(existing, key)
                    # GRUG: Key exists - merge or replace based on type
                    if isa(existing[key], Dict) && isa(value, Dict)
                        # GRUG: Both dicts - deep merge
                        for (k, v) in value
                            existing[key][k] = v
                        end
                    elseif isa(existing[key], Vector) && isa(value, Vector)
                        # GRUG: Both arrays - concatenate
                        append!(existing[key], value)
                    else
                        # GRUG: Different types - replace
                        existing[key] = value
                    end
                else
                    # GRUG: New key - just add
                    existing[key] = value
                end
            end
        else
            # GRUG: New data is not a dict - put it in a wrapper
            existing["custom_append_$(round(Int, time()))"] = new_data
        end
        
        # GRUG: Write back using system gzip
        json_out = JSON.json(existing)
        open(save_filepath, "w") do io
            proc = open(`gzip -c`, "r+")
            write(proc, json_out)
            close(proc.in)
            compressed = read(proc)
            write(io, compressed)
        end
        
        return "✅ Appended JSON to save file: $save_filepath"
        
    catch e
        error("!!! FATAL: /writeSave failed to process save file '$save_filepath': $e !!!")
    end
end

"""
add_message_to_history!(role::String, text::String, pinned::Bool=false)

GRUG: Write new words on memory cave wall. If wall full, wash away old words.
Pinned messages survive eviction. Throws on empty input — NO SILENT FAILURES.
"""
function add_message_to_history!(role::String, text::String, pinned::Bool=false)
    if strip(text) == "" || strip(role) == ""
        error("!!! FATAL: Grug cannot paint empty air on memory cave wall! !!!")
    end

    if !(role in ALLOWED_ROLES)
        error("!!! FATAL: Grug does not know role '$role'. Allowed roles: $(join(ALLOWED_ROLES, ", ")) !!!")
    end
    
    id  = atomic_add!(MSG_ID_COUNTER, 1)
    msg = ChatMessage(id, role, text, pinned)
    
    if length(MESSAGE_HISTORY) < MAX_HISTORY
        push!(MESSAGE_HISTORY, msg)
    else
        # GRUG: Cave full! Find oldest un-pinned drawing and smash it.
        idx_to_replace = findfirst(m -> !m.pinned, MESSAGE_HISTORY)
        if isnothing(idx_to_replace)
            error("!!! FATAL: All 10,000 slots have pinned rocks! Grug's memory cave is completely full! !!!")
        end
        deleteat!(MESSAGE_HISTORY, idx_to_replace)
        push!(MESSAGE_HISTORY, msg)
    end
end

# ==============================================================================
# DYNAMIC AIML DROP TABLE & MAGIC WORD TEMPLATES
# ==============================================================================
# GRUG: AIML_DROP_TABLE, StochasticRule, ALLOWED_RULE_TAGS, and add_orchestration_rule!
# are defined in Engine.jl so they are available to both Main.jl and the test runner.
# Nothing to re-define here. Grug just uses them directly!

# ==============================================================================
# EPHEMERAL AIML ORCHESTRATOR
# ==============================================================================

"""
extract_lobe_aware_context(votes::Vector{Vote})::String

GRUG: Read the pinned words and the fresh words to give context to the dynamic
generation engine. Extracts lobe knowledge from winning votes for AIML context.
Non-fatal on lobe read errors — warns and returns error placeholder.
"""
function extract_lobe_aware_context(votes::Vector{Vote})::String
    # GRUG: Prefrontal cortex context injector!
    # Show which lobes are active and what knowledge is available from each.
    # This lets AIML rules reason across domain boundaries (science ↔ philosophy ↔ etc.)
    
    try
        if isempty(votes)
            return "Lobe Context: [No active lobes]"
        end
        
        # GRUG: Map each vote to its lobe, collect unique active lobes
        active_lobes = Set{String}()
        for vote in votes
            lobe_name = Lobe.find_lobe_for_node(vote.node_id)
            if !isnothing(lobe_name)
                push!(active_lobes, lobe_name)
            end
        end
        
        if isempty(active_lobes)
            return "Lobe Context: [Unassigned nodes - no lobe context]"
        end
        
        # GRUG: Build context string with active lobes and their node counts
        lobe_parts = String[]
        for lobe_name in sort(collect(active_lobes))
            lobe_node_count = Lobe.get_lobe_node_count(lobe_name)
            active_node_ids = if isdefined(@__MODULE__, :LobeTable) && LobeTable.table_exists(lobe_name)
                LobeTable.get_active_node_ids(lobe_name)
            else
                String[]
            end
            active_count = length(active_node_ids)
            
            # Sample 2-3 node patterns from this lobe to show domain flavor
            sample_patterns = String[]
            for node_id in active_node_ids[1:min(3, length(active_node_ids))]
                node = lock(() -> get(NODE_MAP, node_id, nothing), NODE_LOCK)
                if !isnothing(node)
                    push!(sample_patterns, node.pattern)
                end
            end
            
            pattern_preview = isempty(sample_patterns) ? "" : 
                " ($(join([p[1:min(30, length(p))] for p in sample_patterns], " | ")))"
            
            push!(lobe_parts, "$lobe_name ($active_count/$lobe_node_count active$pattern_preview)")
        end
        
        return "Lobe Context: [" * join(lobe_parts, "] | [") * "]"
        
    catch e
        # GRUG: Don't crash AIML on lobe context error, but WARN
        @warn "[MAIN] ⚠ Failed to extract lobe-aware context (non-fatal): $e"
        return "Lobe Context: [Error retrieving lobe information]"
    end
end

"""
clamp_intensity(x::Float64)::Float64

GRUG v7.12: Clamp an intensity scalar into the configured
[CONTEXT_INTENSITY_FLOOR, CONTEXT_INTENSITY_CAP] interval. No silent
saturation — callers must pass finite floats (NaN/Inf will raise because
we compare with Float64 literals). This is the single gate between
relevance math and the ChatMessage storage.
"""
@inline function clamp_intensity(x::Float64)::Float64
    if !isfinite(x)
        error("!!! FATAL: clamp_intensity got non-finite value $x — relevance math blew up! !!!")
    end
    return clamp(x, CONTEXT_INTENSITY_FLOOR, CONTEXT_INTENSITY_CAP)
end

"""
_tokenize_for_relevance(text::String)::Set{String}

GRUG v7.12: Lowercased whitespace-split token set used for the lexical
half of the message/user relevance score. Short (<3 char) tokens are
dropped to avoid 'the'/'a'/'of' saturating the overlap.
"""
function _tokenize_for_relevance(text::String)::Set{String}
    toks = Set{String}()
    for t in split(lowercase(text))
        s = strip(String(t), [',', '.', ';', ':', '!', '?', '"', '\''])
        if length(s) >= 3
            push!(toks, s)
        end
    end
    return toks
end

"""
_relational_overlap(mission_triples, msg_triples)::Float64

GRUG v7.12: Jaccard-style overlap between the current user input's
RelationalTriples (as surfaced by `extract_dynamic_relational_triples`,
which includes dynamic relations the verb registry did NOT pre-declare
— see engine.jl) and a candidate message's cached triples. Comparison
uses the canonical string form subject|relation|object so synonym
normalization performed upstream still counts.
Returns a value in [0.0, 1.0].
"""
function _relational_overlap(mission_triples::Vector, msg_triples::Vector)::Float64
    if isempty(mission_triples) || isempty(msg_triples)
        return 0.0
    end
    to_key(t) = string(t.subject, "|", t.relation, "|", t.object)
    a = Set(to_key(t) for t in mission_triples)
    b = Set(to_key(t) for t in msg_triples)
    inter = length(intersect(a, b))
    uni = length(union(a, b))
    return uni == 0 ? 0.0 : inter / uni
end

"""
score_message_relevance(msg, user_tokens, user_triples)::Float64

GRUG v7.12: Weighted sum of
  * lexical token overlap (Jaccard of cleaned tokens)
  * relational triple overlap (dynamic triples included)
Weights are CONTEXT_RELEVANCE_LEX_W and CONTEXT_RELEVANCE_REL_W. Result
is mapped into [0, CONTEXT_INTENSITY_CAP] so the snap-back step can pull
intensity directly toward it without an extra scale transform.

The message's own triples are re-extracted on each call. That keeps the
scorer honest against live verb-registry changes (/addVerb,
/addRelationClass); we accept the small CPU cost because MESSAGE_HISTORY
is bounded by MAX_HISTORY and `scan_mode` is clamped inside
extract_dynamic_relational_triples anyway.
"""
function score_message_relevance(msg::ChatMessage,
                                 user_tokens::Set{String},
                                 user_triples::Vector)::Float64
    msg_tokens = _tokenize_for_relevance(msg.text)
    lex = if isempty(msg_tokens) || isempty(user_tokens)
        0.0
    else
        inter = length(intersect(msg_tokens, user_tokens))
        uni = length(union(msg_tokens, user_tokens))
        uni == 0 ? 0.0 : inter / uni
    end

    # GRUG v7.12: Dynamic relational extraction — scan_mode=3 requests the
    # high-res path so complex inputs surface triples the static verb
    # registry never saw. Simple inputs fall back automatically per the
    # engine's own complexity wave.
    msg_triples = try
        extract_dynamic_relational_triples(msg.text, 3)
    catch
        # GRUG: Relation extraction is best-effort for scoring. If a
        # malformed stored message blows it up, treat relational overlap
        # as zero and move on; lexical half still counts. NO SILENT
        # FAILURE in the broader system — the @warn surfaces it.
        @warn "[Main v7.12] relational extraction failed for msg $(msg.id) during relevance scoring"
        RelationalTriple[]
    end
    rel = _relational_overlap(user_triples, msg_triples)

    raw = CONTEXT_RELEVANCE_LEX_W * lex + CONTEXT_RELEVANCE_REL_W * rel
    # Map [0,1] → [0, CAP] so snap-back targets land on the same scale.
    return clamp_intensity(raw * CONTEXT_INTENSITY_CAP)
end

"""
refresh_message_intensities!(user_input::String)

GRUG v7.12: Called at the pattern-bind / relational phase of every
/mission and /brainstorm (AFTER the pattern scanner has surfaced dynamic
relational triples, BEFORE the AIML orchestrator builds its payload).

For every message in MESSAGE_HISTORY:
  1. Compute relevance score against `user_input` (lexical + relational,
     with dynamic triples included).
  2. Snap-back: intensity += CONTEXT_SNAP_ALPHA * (relevance - intensity)
  3. Zero-mean jitter: intensity += RelationalJitter.jitter_value(intensity)
     — /brainstorm scope automatically amplifies via is_brainstorm_active,
     so intensity jitter aligns with the rest of the engine's jitter regime.
  4. Clamp into [FLOOR, CAP].

Pinned messages follow the exact same rules so future features can use
their intensity (e.g. pinned-but-irrelevant vs. pinned-and-hot) without
a second code path.

This is the single hook that lets irrelevant /status banners decay out of
Fresh Memory and stops the O(N^2) context-recursion blow-up we hit at
v7.12 pre-intensity.
"""
function refresh_message_intensities!(user_input::String)
    isempty(MESSAGE_HISTORY) && return

    user_tokens = _tokenize_for_relevance(user_input)
    user_triples = try
        extract_dynamic_relational_triples(user_input, 3)
    catch
        @warn "[Main v7.12] dynamic relational extraction failed for user input; " *
              "falling back to lexical-only relevance"
        RelationalTriple[]
    end

    # GRUG v7.17: Chunked walk through MESSAGE_HISTORY. Holding the
    # lock for one tight 10k-long loop would starve any other writer
    # for the duration — chunking the scan lets us keep the lock held
    # per batch but gives Julia's scheduler explicit yield points
    # between batches (yield() call below). Correctness is identical
    # because every ChatMessage is mutable and referenced by pointer;
    # chunk boundaries don't affect which messages get updated.
    lock(MESSAGE_HISTORY_LOCK) do
        total_n = length(MESSAGE_HISTORY)
        chunk_start = 1
        while chunk_start <= total_n
            chunk_end = min(chunk_start + CONTEXT_SCAN_CHUNK - 1, total_n)
            @inbounds for i in chunk_start:chunk_end
                m = MESSAGE_HISTORY[i]
                relevance = score_message_relevance(m, user_tokens, user_triples)
                # Snap-back toward relevance
                snapped = m.intensity + CONTEXT_SNAP_ALPHA * (relevance - m.intensity)
                # Zero-mean jitter (reuses the engine's RelationalJitter so
                # /brainstorm scope automatically amplifies the nudge)
                nudged = RelationalJitter.jitter_value(snapped)
                m.intensity = clamp_intensity(nudged)
            end
            chunk_start = chunk_end + 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("refresh_intensities")
        end
    end
end

"""
apply_last_selected_feedback!(delta::Float64)

GRUG v7.12: /right and /wrong feedback hook. Walks the set of message
ids that contributed to the last /mission's Fresh Memory and bumps
their intensity by `delta`, clamped into the usual interval. Closes the
learning loop on context selection: a context that led to a good answer
gets reinforced, a bad one gets penalised.

If no prior mission has populated LAST_SELECTED_MSG_IDS (fresh cave,
immediately after /loadSpecimen, or the last mission produced no
scaffold because the scan went silent), this is a no-op — NO SILENT
FAILURE but also no spurious side-effect.
"""
function apply_last_selected_feedback!(delta::Float64)
    selected_ids = lock(LAST_SELECTED_MSG_LOCK) do
        copy(LAST_SELECTED_MSG_IDS[])
    end
    isempty(selected_ids) && return 0

    # GRUG v7.17: Chunked scan with early-exit. selected_ids is a Set
    # so membership is O(1), but we can still finish the pass early:
    # once bumped == length(selected_ids), every id has been found and
    # the rest of MESSAGE_HISTORY is guaranteed to be a miss. On a 10k
    # cave with a typical 3-8 selected ids, this aborts after the
    # first chunk that contains them rather than walking 10k items.
    bumped = 0
    target_hits = length(selected_ids)
    lock(MESSAGE_HISTORY_LOCK) do
        total_n = length(MESSAGE_HISTORY)
        chunk_start = 1
        while chunk_start <= total_n && bumped < target_hits
            chunk_end = min(chunk_start + CONTEXT_SCAN_CHUNK - 1, total_n)
            @inbounds for i in chunk_start:chunk_end
                m = MESSAGE_HISTORY[i]
                if m.id in selected_ids
                    m.intensity = clamp_intensity(m.intensity + delta)
                    bumped += 1
                    bumped >= target_hits && break
                end
            end
            chunk_start = chunk_end + 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("feedback_scan")
        end
    end
    return bumped
end

"""
auto_tune_intensity_threshold(unpinned)::Tuple{Float64, Int}

GRUG v7.13: Binary-search for the intensity threshold that lands the
above-threshold eligible set inside
[CONTEXT_ELIGIBLE_MIN, CONTEXT_ELIGIBLE_MAX] whenever the cave has more
messages than the max band. Returns `(threshold, eligible_count)`.

Search space: [FLOOR, CAP]. We step with binary search for
CONTEXT_THRESHOLD_STEPS iterations (log₂ 3.0/resolution ≈ 12 is plenty
given messages are real Float64s). At each step we count how many
unpinned messages strictly exceed the candidate threshold:
  * count > MAX → raise threshold (narrow more).
  * count < MIN → lower threshold (widen).
  * MIN ≤ count ≤ MAX → stop early, return current.

Edge cases (explicit, NO SILENT FAILURES):
  * Fewer than MIN unpinned messages total → threshold = FLOOR so
    everything passes. We cannot conjure messages out of air.
  * All messages at identical intensity → binary search converges to
    just under that value, all pass. No infinite loop.
  * Jitter has driven every intensity to FLOOR → still returns FLOOR.
"""
function auto_tune_intensity_threshold(unpinned::Vector{ChatMessage})::Tuple{Float64, Int}
    n = length(unpinned)
    if n <= CONTEXT_ELIGIBLE_MAX
        # Cave too small to narrow. Threshold = FLOOR → everything eligible.
        return (CONTEXT_INTENSITY_FLOOR, n)
    end

    lo = CONTEXT_INTENSITY_FLOOR
    hi = CONTEXT_INTENSITY_CAP
    best_threshold = lo
    best_count = n

    # GRUG v7.17: Chunked scan — each binary-search step walks `unpinned`
    # in CONTEXT_SCAN_CHUNK-sized batches and short-circuits as soon as
    # the running survivor count clears CONTEXT_ELIGIBLE_MAX (we only
    # need to know "too many" for the lo-raise branch; we don't need
    # the exact overflow count). The "too few" branch still needs the
    # full count, so those chunks run to completion for that step —
    # but only when the threshold is already high enough that survivors
    # are scarce, which is the cheap case anyway.
    #
    # Net effect: the expensive overshoot cases (threshold too low, most
    # messages survive) abort after ~CONTEXT_ELIGIBLE_MAX+1 hits rather
    # than scanning all 10k. That is the whole point of chunking.
    for _ in 1:CONTEXT_THRESHOLD_STEPS
        mid = (lo + hi) / 2
        count = 0
        overflow = false
        chunk_start = 1
        while chunk_start <= n
            chunk_end = min(chunk_start + CONTEXT_SCAN_CHUNK - 1, n)
            @inbounds for i in chunk_start:chunk_end
                unpinned[i].intensity > mid && (count += 1)
            end
            # Between chunks: if we already know this midpoint produces
            # more survivors than the max, no need to keep counting.
            if count > CONTEXT_ELIGIBLE_MAX
                overflow = true
                # GRUG v7.17: emit DONE even on early-exit so the
                # counter reflects work actually performed.
                _chunk_done!("threshold_scan")
                break
            end
            chunk_start = chunk_end + 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("threshold_scan")
        end
        best_threshold = mid
        best_count = count

        if overflow || count > CONTEXT_ELIGIBLE_MAX
            # Too many survivors → raise threshold.
            lo = mid
        elseif count < CONTEXT_ELIGIBLE_MIN
            # Too few survivors → lower threshold.
            hi = mid
        else
            # Landed in the band. Stop.
            return (mid, count)
        end
    end
    # GRUG: Budget exhausted. Accept the last midpoint; count is whatever
    # it was. Worst case we're a message or two off the band — the
    # downstream coinflip within survivors still narrows the final set.
    return (best_threshold, best_count)
end

"""
extract_aiml_memory_context()::String

GRUG v7.13: Chief Orchestrator reads the memory wall with a two-stage
Fresh Memory gate:

  1. Pinned messages always surface, regardless of intensity.
  2. Unpinned messages are first THRESHOLD-GATED by an auto-tuned
     intensity threshold. The threshold is binary-searched each cycle
     so the eligible set lands in [CONTEXT_ELIGIBLE_MIN,
     CONTEXT_ELIGIBLE_MAX] whenever possible — this is what stops a
     10k-message cave from putting 10k items into the coinflip pool.
  3. Surviving eligibles are still coinflipped (newest-first) with
     p = clamp(intensity/CAP, COIN_P_FLOOR, COIN_P_CEIL) so the
     stochastic exploration character from v7.12 is preserved. The
     final Fresh Memory is capped at MAX_FRESH_CONTEXT entries.
  4. Selected message ids are cached in LAST_SELECTED_MSG_IDS so
     /right and /wrong can reinforce/punish them.

This layer scales: threshold tuning is a single O(N) pass per binary-
search step (≤12 steps), then the coinflip only touches ≤~MAX survivors,
never all N stored messages. NO SILENT FAILURES.
"""
function extract_aiml_memory_context()::String
    total_msgs = length(MESSAGE_HISTORY)
    if total_msgs == 0
        return "Memory Cave: [EMPTY]"
    end

    pinned_msgs = String[]
    recent_msgs = String[]
    selected_ids = Set{Int}()

    try
        # 1. Pinned — always surface, newest-first order preserved.
        # GRUG v7.17: Chunked scan so a 10k cave doesn't tie up one tight
        # loop. Pinned lists are typically tiny (<< total), so this
        # finishes in a handful of chunks in practice.
        total_n = length(MESSAGE_HISTORY)
        chunk_start = 1
        while chunk_start <= total_n
            chunk_end = min(chunk_start + CONTEXT_SCAN_CHUNK - 1, total_n)
            @inbounds for i in chunk_start:chunk_end
                m = MESSAGE_HISTORY[i]
                if m.pinned
                    push!(pinned_msgs, "[$(m.role)]: $(m.text)")
                    push!(selected_ids, m.id)
                end
            end
            chunk_start = chunk_end + 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("pinned_scan")
        end

        # 2. Unpinned — threshold-gate THEN intensity-biased coinflip.
        # The threshold is auto-tuned each cycle so AIML never sees more
        # than ~CONTEXT_ELIGIBLE_MAX candidates even if the cave holds
        # 10k messages. That keeps the coinflip pool tight and the
        # selection work bounded by CONTEXT_ELIGIBLE_MAX, not N.
        #
        # GRUG v7.17: Materialise the unpinned slice in chunks rather
        # than with one giant comprehension. Same final vector, but the
        # allocation grows in 1k bumps instead of one N-sized burst —
        # easier on the GC when MESSAGE_HISTORY is near its 10k cap.
        unpinned = ChatMessage[]
        sizehint!(unpinned, total_n)  # upper bound, shrinks if pinned present
        chunk_start = 1
        while chunk_start <= total_n
            chunk_end = min(chunk_start + CONTEXT_SCAN_CHUNK - 1, total_n)
            @inbounds for i in chunk_start:chunk_end
                m = MESSAGE_HISTORY[i]
                m.pinned || push!(unpinned, m)
            end
            chunk_start = chunk_end + 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("unpinned_materialize")
        end
        threshold, eligible_count = auto_tune_intensity_threshold(unpinned)

        # Eligible survivors — only those strictly above threshold.
        # Walk newest-first so recent messages get first coinflip dibs
        # when the Fresh Memory cap bites. This loop already short-
        # circuits at MAX_FRESH_CONTEXT, so it never touches more than
        # a bounded tail of the unpinned vector in practice — the
        # chunk framing below is just for telemetry and to make the
        # early-exit explicit at chunk boundaries.
        chosen = ChatMessage[]
        unpinned_n = length(unpinned)
        i = unpinned_n
        while i >= 1 && length(chosen) < MAX_FRESH_CONTEXT
            chunk_lo = max(1, i - CONTEXT_SCAN_CHUNK + 1)
            @inbounds for j in i:-1:chunk_lo
                length(chosen) >= MAX_FRESH_CONTEXT && break
                m = unpinned[j]
                m.intensity > threshold || continue   # threshold gate
                p = clamp(m.intensity / CONTEXT_INTENSITY_CAP,
                          CONTEXT_COIN_P_FLOOR, CONTEXT_COIN_P_CEIL)
                if rand() < p
                    push!(chosen, m)
                    push!(selected_ids, m.id)
                end
            end
            i = chunk_lo - 1
            # GRUG v7.17: publish DONE for this batch before advancing.
            _chunk_done!("coinflip_scan")
        end
        # Restore chronological order for human readability.
        reverse!(chosen)
        for m in chosen
            push!(recent_msgs,
                  "[$(m.role)]: $(m.text) (intensity=$(round(m.intensity, digits=2)))")
        end
        # Stash threshold snapshot on the Fresh Memory block header so
        # operators can see what cutoff the cave applied this cycle
        # without digging into the debug log. Bounded length; no PII.
        threshold_note = "threshold=$(round(threshold, digits=2)) eligible=$eligible_count"

        # 3. Cache selected ids for /right and /wrong feedback.
        lock(LAST_SELECTED_MSG_LOCK) do
            LAST_SELECTED_MSG_IDS[] = selected_ids
        end

        pinned_str = isempty(pinned_msgs) ? "No pinned rocks" : join(pinned_msgs, " | ")
        recent_str = isempty(recent_msgs) ? "No recent sounds" : join(recent_msgs, " | ")

        # GRUG v7.13: Fresh Memory header carries the auto-tuned cutoff
        # so downstream log consumers can see the two-stage gate at work.
        return "Deep Memory (Pinned): $pinned_str\nFresh Memory [$threshold_note] (Recent): $recent_str"
    catch e
        error("!!! FATAL: Chief Orchestrator failed to read memory wall: $e !!!")
    end
end

# ==============================================================================
# IMMUNE GATE HELPER — REUSABLE GUARD FOR ALL STRUCTURE-STORING COMMANDS
# ==============================================================================

"""
immune_gate(cmd_name::String, input_text::String; is_critical::Bool=true)::Bool

GRUG: Reusable immune gate. Runs immune_scan! on input_text for any command that
stores structure. Returns true if input passed, false if rejected.
Logs status and records to message history on rejection. NO SILENT FAILURES.
Non-immune errors are warned but do NOT block (immune system crash ≠ command block).
"""
function immune_gate(cmd_name::String, input_text::String; is_critical::Bool=true)::Bool
    node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
    try
        status, sig = ImmuneSystem.immune_scan!(input_text, node_count; is_critical=is_critical)
        if status == :deleted
            println("[IMMUNE] ⛔ $cmd_name REJECTED by immune system (sig=0x$(string(sig, base=16)))")
            add_message_to_history!("System", "⛔ $cmd_name input rejected by immune system: deleted", false)
            return false
        end
        if status != :immature
            println("[IMMUNE] 🛡  $cmd_name scan: $status (sig=0x$(string(sig, base=16)))")
        end
        return true
    catch e
        if e isa ImmuneSystem.ImmuneError
            println("[IMMUNE] ⛔ $cmd_name REJECTED by immune system: $(e.info)")
            add_message_to_history!("System", "⛔ $cmd_name input rejected by immune system: $(e.kind)", false)
            return false
        else
            # GRUG: Immune system itself broke. Log it but don't block the command.
            # Non-fatal: immune failure should not kill the cave.
            @warn "[IMMUNE] Immune scan threw unexpected error for $cmd_name (non-fatal): $e"
            return true
        end
    end
end

# GRUG DOC 3.9: SUPERPOSITION ORCHESTRATOR!
"""
ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})

GRUG: Superposition orchestrator. Finds heaviest rocks (max confidence) for "Sure"
basket, coinflips smaller rocks into "Unsure" basket. Builds AIML payload and
fires the generative engine. Throws on empty votes — NO SILENT FAILURES.
"""
function ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})::Tuple{String, Vector{Vote}, Vector{Vote}}
    if isempty(votes)
        error("!!! FATAL: Orchestrator failed: Cave empty! Received zero votes! Cannot build fire! !!!")
    end
    if strip(mission) == ""
        error("!!! FATAL: Orchestrator failed: Mission text is invisible wind! !!!")
    end

    # GRUG: Sort votes by confidence descending BEFORE bucketing.
    sorted_votes = sort(votes; by = v -> v.confidence, rev = true)

    # GRUG: NEW ARCHITECTURE — threshold-gated vote selection!
    # AIML only considers votes past AIML_CONFIDENCE_THRESHOLD. Top tier (within
    # AIML_TOP_TIER_WINDOW of max) goes straight in, no coinflip. Sub-top tier
    # (below top but above threshold) gets a strength-biased coinflip — strong
    # neurons more likely kept. Below threshold = dropped.
    #
    # This replaces the old "within 0.05 of max = sure, else 50/50 flat coin"
    # logic with a principled two-stage filter that respects node strength.
    # --------------------------------------------------------------------------
    # GRUG: Convert engine votes -> VoteCandidate with node strength pulled
    # from NODE_MAP. Done under one lock pass for efficiency.
    vote_candidates = VoteOrchestrator.VoteCandidate[]
    candidate_to_vote = Dict{String, Vote}()
    lock(NODE_LOCK) do
        for v in sorted_votes
            node = get(NODE_MAP, v.node_id, nothing)
            # GRUG: If a node vanished between scan and orchestrate, skip it
            # loudly (warn, not crash). Another thread may have graved it.
            if isnothing(node)
                @warn "[ORCHESTRATOR] ⚠ Vote for missing node '$(v.node_id)' dropped."
                continue
            end
            push!(vote_candidates, VoteOrchestrator.VoteCandidate(
                v.node_id, v.confidence, node.strength; strength_cap = STRENGTH_CAP
            ))
            candidate_to_vote[v.node_id] = v
        end
    end

    if isempty(vote_candidates)
        error("!!! FATAL: Orchestrator failed: All votes referenced vanished nodes! !!!")
    end

    top_tier, subtop_tier, rejected_tier = VoteOrchestrator.select_aiml_votes(
        vote_candidates;
        threshold  = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
        top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW
    )

    # GRUG: If nothing passed the threshold, fall back to the highest-confidence
    # vote we have. Biology rule: cave should always try to answer, not freeze.
    # This also preserves backwards compatibility with tests that feed low-confidence votes.
    if isempty(top_tier) && isempty(subtop_tier)
        @warn "[ORCHESTRATOR] ⚠ No votes passed AIML_CONFIDENCE_THRESHOLD=$(VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD). Falling back to highest-confidence vote."
        # GRUG: Pick top of the rejected list as emergency fallback.
        fallback = rejected_tier[1]
        push!(top_tier, fallback)
    end

    # GRUG: Translate selected candidates back to Vote objects for downstream use.
    sure_votes   = Vote[candidate_to_vote[vc.node_id] for vc in top_tier]
    unsure_votes = Vote[candidate_to_vote[vc.node_id] for vc in subtop_tier]

    if isempty(sure_votes)
        # GRUG: Should be mathematically impossible after fallback, but NO SILENT FAILURES!
        error("!!! FATAL: Grug math broke! Top tier produced zero sure votes even after fallback! !!!")
    end

    # GRUG: TIE-BREAKING! If multiple rocks sit at the same confidence, pick random winner.
    # Old behavior: always picked sure_votes[1] (first in sort order = arbitrary for ties).
    # New behavior: shuffle the tied group, random winner. Deterministic if only one winner.
    if length(sure_votes) > 1
        # GRUG: Identify the TRUE ties — rocks at exactly the same confidence as the leader.
        # "Within 0.05" already got them into sure_votes. Now find the subset that are
        # dead-equal to the max (within floating-point epsilon). Those are the real tied rocks.
        top_conf = sure_votes[1].confidence
        tied_votes = Vote[v for v in sure_votes if abs(v.confidence - top_conf) < 1e-9]

        if length(tied_votes) > 1
            # GRUG: RANDOM TIE-BREAK! Shuffle the tied rocks and pick one.
            shuffle!(tied_votes)
            primary_vote = tied_votes[1]
            println("[ORCHESTRATOR] 🎲  TIE DETECTED! $(length(tied_votes)) rocks at confidence $(round(top_conf, digits=3)). Random winner: $(primary_vote.node_id)")
        else
            # GRUG: No exact tie. Highest confidence rock wins cleanly.
            primary_vote = sure_votes[1]
        end
    else
        primary_vote = sure_votes[1]
    end

    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    if isnothing(node)
        error("!!! FATAL: Winning node $(primary_vote.node_id) vanished before Grug could grab it! !!!")
    end

    # GRUG: Pass EVERYTHING to the command block so the Generative Engine can see Grug's whole mind!
    output = COMMANDS[primary_vote.action](mission, node, primary_vote, sure_votes, unsure_votes, votes)
    
    # GRUG: Return output along with contributing votes (sure + unsure)
    # These are the votes that actually contributed to generating output
    return output, sure_votes, unsure_votes
end

# ==============================================================================
# COMMAND DEFINITIONS & JIT TEXT GENERATION
# ==============================================================================

"""
generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, context)

GRUG: Build text sandwich for the JIT Generative Builder and synthesize
the dynamic response. Assembles system prompt, mission, vote context, and
memory into a single payload. Throws on missing context keys — NO SILENT FAILURES.
"""
function generate_aiml_payload(mission::String, primary_vote::Vote, sure_votes::Vector{Vote}, unsure_votes::Vector{Vote}, all_votes::Vector{Vote}, context::Dict)
    if !haskey(context, "system_prompt")
        error("!!! FATAL: Node dictionary missing 'system_prompt'! Grug confused! !!!")
    end

    system_prompt = context["system_prompt"]
    neg_str       = isempty(primary_vote.negatives) ? "None" : join(primary_vote.negatives, ", ")
    
    memory_str = extract_aiml_memory_context()
    lobe_str  = extract_lobe_aware_context(all_votes)

    sure_str   = join([v.action for v in sure_votes], ", ")
    unsure_str = isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", ")

    # GRUG: VOTE CERTAINTY — SURE if primary stands alone at top, UNSURE if ties exist.
    # Tied alternatives = other sure_votes that were NOT picked as primary.
    tied_alternatives = Vote[v for v in sure_votes if v.node_id != primary_vote.node_id]
    vote_certainty = isempty(tied_alternatives) ? "SURE" : "UNSURE"
    tied_alt_str = isempty(tied_alternatives) ? "None" :
        join(["$(v.node_id)($(v.action),conf=$(round(v.confidence, digits=2)))" for v in tied_alternatives], ", ")

    # GRUG: Read rule board. Swap shape-shifter words for real context chunks.
    # NOW STOCHASTIC: each rule fires based on its fire_probability.
    # This is where Grug JIT-compiles math into human language with natural variation!
    evaluated_rules = String[]
    try
        for rule in AIML_DROP_TABLE
            # GRUG: Roll a coinflip against the rule's fire probability.
            # prob=1.0 rules always fire. prob=0.5 rules fire ~half the time.
            if rand() > rule.fire_probability
                # GRUG: This rule lost its coinflip this round. Skip it!
                continue
            end

            processed = rule.text
            processed = replace(processed, "{MISSION}"        => mission)
            processed = replace(processed, "{PRIMARY_ACTION}" => primary_vote.action)
            processed = replace(processed, "{SURE_ACTIONS}"   => sure_str)
            processed = replace(processed, "{UNSURE_ACTIONS}" => unsure_str)
            processed = replace(processed, "{ALL_ACTIONS}"    => join([v.action for v in all_votes], ", "))
            processed = replace(processed, "{CONFIDENCE}"     => string(round(primary_vote.confidence, digits=2)))
            processed = replace(processed, "{NODE_ID}"        => primary_vote.node_id)
            processed = replace(processed, "{MEMORY}"         => memory_str)
            # GRUG v7.15: strip the "Lobe Context: " prefix so rules that
            # say "Stay inside the {LOBE_CONTEXT} frame" don't render as
            # "Stay inside the Lobe Context: [cooking...] frame".
            _lobe_display = startswith(lobe_str, "Lobe Context: ") ? lobe_str[length("Lobe Context: ")+1:end] : lobe_str
            processed = replace(processed, "{LOBE_CONTEXT}"   => _lobe_display)
            processed = replace(processed, "{VOTE_CERTAINTY}"     => vote_certainty)
            processed = replace(processed, "{TIED_ALTERNATIVES}"  => tied_alt_str)
            push!(evaluated_rules, processed)
        end
    catch e
        error("!!! FATAL: Grug failed to swap shape-shifter words in dynamic rules: $e !!!")
    end

    rules_str = isempty(evaluated_rules) ? "None" : join(evaluated_rules, " | ")

    # GRUG: Put relation verb-noun sandwiches into the prompt to provide grammar context.
    u_triples = isempty(primary_vote.user_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.user_triples], ", ")
    n_triples = isempty(primary_vote.node_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.node_triples], ", ")

    # =====================================================================
    # GRUG v7.16: AIML SYNTHESIZES VOTES INTO A NATURAL-LANGUAGE REPLY.
    # =====================================================================
    # AIML's job is NOT to emit instructions ("Answer X in one tight
    # paragraph") and it is NOT to emit statistics ("Primary Action:
    # analyze. Sure Actions: [...]"). It is to ORCHESTRATE the votes
    # (which carry the content) into a SPOKEN reply — the node patterns
    # are the claims, the system_prompt is the voice, the relational
    # triples are sub-claims, the primary action is the speech-act,
    # and the thesaurus + inhibitions + rules are the synonymy menu.
    #
    # Pipeline per cycle:
    #   1. Look up winning node → claim (pattern) + voice + drop_table
    #   2. Pick skeleton from primary action family
    #   3. Fill skeleton, routing every word through thesaurus swap →
    #      inhibition check → drop_table check (honour both negative
    #      thesaurus and per-node drop_table)
    #   4. Weave relational triples as sub-clauses
    #   5. Fold in sure companion patterns as supporting claims
    #   6. Add hedge on UNSURE certainty only
    #   7. Cite pinned memory if lexically topical
    #   8. Tag with lobe frame
    #
    # Stats stay behind --- DEBUG TELEMETRY --- (v7.15 separator) so
    # /status, tests, and operators can still see them, but the reply
    # is the first and primary thing a downstream consumer reads.
    # =====================================================================

    # GRUG: Prose-join for action lists that do surface in the reply.
    function _prose_join(items::Vector{String})::String
        if isempty(items);          return "" end
        if length(items) == 1;      return items[1] end
        if length(items) == 2;      return "$(items[1]) and $(items[2])" end
        return join(items[1:end-1], ", ") * ", and " * items[end]
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: _pick_synonym — given a word, return either a random
    # synonym from Thesaurus.SYNONYM_SEED_MAP OR the original word,
    # respecting:
    #   (a) Negative thesaurus (InputQueue.is_inhibited) — NEVER emit
    #   (b) Per-node drop_table — NEVER emit this node's forbidden words
    #   (c) Required relations — if the original word is in the winning
    #       node's required_relations, we MUST keep it (synonyms would
    #       break the required-relation contract)
    #
    # NO SILENT FAILURES: if every candidate is inhibited AND the
    # original word is also inhibited AND is required, we @warn and
    # emit the original anyway (required > inhibited) so the reply
    # still carries the seeded claim. This is the correct choice —
    # silently dropping a required relation breaks the node's contract.
    # -------------------------------------------------------------------
    function _pick_synonym(word::String, drop_table::Vector{String},
                            required_relations::Vector{String})::String
        clean = lowercase(strip(word))
        is_required = clean in required_relations

        # Required-relation short-circuit: never swap, never inhibit.
        if is_required
            return word
        end

        # Candidate pool: original + all synonyms from BOTH registries.
        #   (1) Thesaurus.SYNONYM_SEED_MAP — built-in canonical→synset
        #       map (bidirectional). Rich hardcoded defaults like
        #       "produce" → {trigger, induce, make, construct, ...}.
        #   (2) SemanticVerbs._SYNONYM_MAP — runtime /addSynonym map,
        #       stored alias→canonical. We scan BOTH directions:
        #       if word is a canonical, collect its aliases; if word
        #       is itself an alias, collect its canonical + siblings.
        candidates = String[word]
        if haskey(Thesaurus.SYNONYM_SEED_MAP, clean)
            for syn in Thesaurus.SYNONYM_SEED_MAP[clean]
                push!(candidates, syn)
            end
        end
        # GRUG v7.16-FIX: also pull runtime /addSynonym entries.
        try
            sv_map = SemanticVerbs._SYNONYM_MAP  # alias => canonical
            # Case A: word is a canonical. Collect aliases pointing to it.
            for (alias, canon) in sv_map
                if canon == clean && alias != clean
                    push!(candidates, alias)
                end
            end
            # Case B: word is itself an alias. Add its canonical, and
            # every sibling alias of that canonical.
            if haskey(sv_map, clean)
                my_canon = sv_map[clean]
                if my_canon != clean
                    push!(candidates, my_canon)
                end
                for (alias, canon) in sv_map
                    if canon == my_canon && alias != clean
                        push!(candidates, alias)
                    end
                end
            end
        catch e
            @warn "[MAIN v7.16 synthesis] Runtime synonym lookup failed ($e); continuing with seed-map only."
        end
        unique!(candidates)

        # Filter out inhibited words (both negative-thesaurus and
        # per-node drop_table).
        allowed = filter(candidates) do c
            c_clean = lowercase(strip(c))
            if InputQueue.is_inhibited(String(c_clean))
                return false
            end
            if c_clean in drop_table
                return false
            end
            return true
        end

        if isempty(allowed)
            # Every candidate is inhibited. Warn loudly — this is a
            # seed-configuration smell (user inhibited the word AND
            # all its synonyms). Emit the original so the reply does
            # not lose content; operator can fix the inhibition set.
            @warn "[MAIN v7.16 synthesis] Every synonym of '$word' is inhibited (neg thesaurus or node drop_table). Emitting original to preserve content."
            return word
        end

        # Stochastic pick — this is the natural-variation engine.
        # Two cycles on the same prompt roll different synonyms.
        return rand(allowed)
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: _swap_words_in — route every whitespace-token of a
    # sentence through _pick_synonym and rejoin. Preserves the original
    # token's case via a simple heuristic: if the original starts with
    # uppercase, capitalize the synonym.
    # -------------------------------------------------------------------
    function _swap_words_in(sentence::String, drop_table::Vector{String},
                             required_relations::Vector{String})::String
        # GRUG v7.16-FIX: Julia's `split` with a regex DOES NOT return
        # the separators as tokens (unlike Python's re.split with a
        # capturing group). So we split on whitespace, keep only the
        # word tokens, route each through _pick_synonym, and rejoin
        # with a single space. Multiple-space runs collapse to single
        # spaces — acceptable for seeded patterns (they are already
        # single-space-separated by convention).
        tokens = split(sentence)  # splits on any whitespace, drops empties
        out_tokens = String[]
        for tok in tokens
            # Strip trailing punctuation for the lookup but re-attach
            # after. This lets "causes," still be recognised as "causes".
            m = match(r"^([\w][\w'-]*)(.*)$", String(tok))
            if m === nothing
                push!(out_tokens, String(tok))
                continue
            end
            core = String(m.captures[1])
            tail = m.captures[2] === nothing ? "" : String(m.captures[2])
            picked = _pick_synonym(core, drop_table, required_relations)
            # Case match: if original core was capitalised, capitalise picked.
            if !isempty(core) && isuppercase(first(core)) && !isempty(picked)
                picked = uppercase(first(picked)) *
                         (length(picked) > 1 ? picked[nextind(picked, 1):end] : "")
            end
            push!(out_tokens, picked * tail)
        end
        return join(out_tokens, " ")
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: Look up the winning node so we can pull pattern,
    # drop_table, relational_patterns, and required_relations directly.
    # If the node vanished mid-cycle (shouldn't happen — cast_votes
    # already locked it), we @error and fall back to a minimal reply
    # using only the vote's public surface.
    # -------------------------------------------------------------------
    winning_node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    node_pattern = ""
    node_drop_table = String[]
    node_required = String[]
    node_triples_obj = RelationalTriple[]
    if winning_node !== nothing
        node_pattern     = winning_node.pattern
        node_drop_table  = [lowercase(strip(w)) for w in winning_node.drop_table]
        node_required    = [lowercase(strip(r)) for r in winning_node.required_relations]
        node_triples_obj = winning_node.relational_patterns
    else
        @error "[MAIN v7.16 synthesis] winning node $(primary_vote.node_id) vanished between vote and synthesis — reply will be minimal."
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: Sentence skeletons keyed by primary action family.
    # Each skeleton accepts two slots:
    #   {CLAIM}   — the core claim (the winning node's pattern, with
    #               every word routed through the synonym + inhibition
    #               pipeline).
    #   {SUPPORT} — zero or more supporting sentences (sure companion
    #               patterns, relational triples, or empty).
    # We keep 6 skeletons aligned with the 6 action families in
    # COMMANDS so every vote resolves to a spoken shape.
    # -------------------------------------------------------------------
    skeleton = if primary_vote.action in ["greet", "welcome", "smile", "laugh"]
        "Hello — here is what matters: {CLAIM}.{SUPPORT}"
    elseif primary_vote.action in ["flee", "hide", "fight"]
        "A concern worth raising: {CLAIM}.{SUPPORT}"
    elseif primary_vote.action in ["comfort", "support", "validate", "acknowledge", "reassure"]
        "To acknowledge what matters here: {CLAIM}.{SUPPORT}"
    elseif primary_vote.action in ["alert", "warn", "caution", "notify", "flag"]
        "A caution: {CLAIM}.{SUPPORT}"
    elseif primary_vote.action in ["explain", "clarify", "describe", "define", "elaborate"]
        "Here is the picture: {CLAIM}.{SUPPORT}"
    else  # reason-family: reason, analyze, ponder, calculate
        "Thinking it through: {CLAIM}.{SUPPORT}"
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: Build the CLAIM. If the winning node has a pattern we
    # use it (that IS the seeded answer). If not (shouldn't happen —
    # /lobeGrow enforces pattern), we fall back to a generic frame
    # around the mission so we never emit an empty reply.
    # -------------------------------------------------------------------
    claim_raw = isempty(node_pattern) ? "the mission \"$mission\" touches unseeded territory" : node_pattern
    claim = _swap_words_in(String(claim_raw), node_drop_table, node_required)

    # -------------------------------------------------------------------
    # GRUG v7.16: Build SUPPORT. Up to 2 sentences, drawn from:
    #   (a) Relational triples from the winning node — "X relates to Y"
    #   (b) Sure companion nodes' patterns — supporting claims
    #   (c) On UNSURE certainty, an honest hedge from unsure side-features
    # Each sentence also routes through _swap_words_in so inhibitions
    # and per-node drop_tables apply uniformly.
    # -------------------------------------------------------------------
    support_pieces = String[]

    # (a) Relational triple → sub-clause. Pick up to 1 triple to keep
    # the reply tight. Prefer a triple whose relation is in required_relations.
    if !isempty(node_triples_obj)
        preferred = nothing
        for t in node_triples_obj
            if lowercase(strip(t.relation)) in node_required
                preferred = t
                break
            end
        end
        t = preferred === nothing ? rand(node_triples_obj) : preferred
        rel_swapped  = _pick_synonym(String(t.relation), node_drop_table, node_required)
        subj_swapped = _swap_words_in(String(t.subject),  node_drop_table, node_required)
        obj_swapped  = _swap_words_in(String(t.object),   node_drop_table, node_required)
        push!(support_pieces, " The link is clear: $subj_swapped $rel_swapped $obj_swapped.")
    end

    # (b) Sure companion → supporting claim. Only if we have at least
    # one tied alternative AND it has a pattern different from the
    # primary. This keeps the reply from repeating itself.
    if !isempty(tied_alternatives)
        companion = tied_alternatives[1]
        comp_node = lock(() -> get(NODE_MAP, companion.node_id, nothing), NODE_LOCK)
        if comp_node !== nothing && !isempty(comp_node.pattern) &&
           comp_node.pattern != node_pattern
            comp_claim = _swap_words_in(String(comp_node.pattern),
                                         node_drop_table, node_required)
            push!(support_pieces, " A companion frame: $comp_claim.")
        end
    end

    # (c) UNSURE hedge: honest about alternative frames still on the table.
    if !isempty(unsure_votes) && vote_certainty == "UNSURE"
        # Use a plain action list for the hedge, also routed through
        # synonym-swap so inhibited action words are replaced.
        unsure_actions = [_pick_synonym(String(v.action), node_drop_table, node_required)
                          for v in unsure_votes]
        unique!(unsure_actions)
        hedge_prose = _prose_join(unsure_actions)
        push!(support_pieces, " I am not fully locked in — $hedge_prose is also on the table.")
    end

    support = join(support_pieces, "")

    # -------------------------------------------------------------------
    # GRUG v7.16: Assemble the core sentence from skeleton + claim +
    # support, then wrap with voice (system_prompt) and lobe tag.
    # -------------------------------------------------------------------
    core_reply = replace(skeleton, "{CLAIM}" => claim, "{SUPPORT}" => support)

    # Lobe tag: pull just the first active lobe name from lobe_str.
    lobe_tag = ""
    m_lobe = match(r"\[([a-z_]+) \(\d+/\d+ active\)\]", lobe_str)
    if m_lobe !== nothing
        lobe_tag = " (from the $(m_lobe.captures[1]) cave)"
    end

    # -------------------------------------------------------------------
    # GRUG v7.16: Cite pinned memory only when it is LEXICALLY TOPICAL
    # to the mission. Requires ≥1 shared non-stopword token between
    # pinned text and mission. This prevents unrelated pinned rules
    # from leaking into every reply (that was a v7.15 regression — the
    # old rules dumped ALL pinned memory into every cycle's payload).
    # -------------------------------------------------------------------
    pinned_citation = ""
    try
        mission_tokens = Set(_tokenize_for_relevance(mission))
        if !isempty(mission_tokens)
            # Walk MESSAGE_HISTORY for pinned entries; pick the first
            # topical one (pinned memory is small — linear scan fine).
            lock(MESSAGE_HISTORY_LOCK) do
                for m in MESSAGE_HISTORY
                    if m.pinned
                        pin_tokens = Set(_tokenize_for_relevance(m.text))
                        if !isempty(intersect(mission_tokens, pin_tokens))
                            pinned_citation = " Pinned note: $(m.text)"
                            break
                        end
                    end
                end
            end
        end
    catch e
        @warn "[MAIN v7.16 synthesis] Pinned-memory topicality check failed ($e); skipping citation."
    end

    # Voice prefix: first sentence of the system_prompt is the persona tag.
    voice_first = split(system_prompt, "."; limit=2)[1] |> strip
    voice_prefix = isempty(voice_first) ? "" : "[$voice_first] "

    # Shaping directives — v7.15 kept them as a separate bulleted block
    # because they are tone/voice directives the downstream LLM
    # consumer (if any) should still honour. We keep a COMPACT form
    # (no bullets, inline) so the reply stays a single paragraph.
    # Directives only surface when they add shaping value — empty list
    # means the reply is its own sole authority.
    directive_suffix = ""
    if !isempty(evaluated_rules)
        directive_suffix = " [Directives: " * join(evaluated_rules, "; ") * "]"
    end

    conversational_reply = "$voice_prefix$core_reply$pinned_citation$lobe_tag$directive_suffix"

    # GRUG: Wait little bit so cpu fire not burn down hut.
    sleep(0.3)

    # =====================================================================
    # Assemble the payload: conversational reply first, debug telemetry
    # below a clear separator. extract_aiml_memory_context() now stores
    # a compact digest of this cycle (v7.14), so the stats dump is NOT
    # re-ingested next cycle — it is purely for /status and operators.
    # =====================================================================
    payload_io = IOBuffer()
    print(payload_io, conversational_reply)
    println(payload_io)
    println(payload_io, "--- DEBUG TELEMETRY (orchestration internals, not for speech) ---")
    println(payload_io, "Mission: '$mission'")
    println(payload_io, "Primary Action: $(primary_vote.action)  (conf=$(round(primary_vote.confidence, digits=2)), certainty=$vote_certainty)")
    println(payload_io, "Sure Actions: [$(join([v.action for v in sure_votes], ", "))]")
    println(payload_io, "Unsure Actions (Coinflip Side-Features): [$(isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", "))]")
    println(payload_io, "Constraints: [$neg_str]")
    println(payload_io, "Winning Node: $(primary_vote.node_id)")
    # GRUG v7.15: lobe_str already includes the "Lobe Context: " prefix
    # (from extract_lobe_aware_context), so strip it to avoid doubling.
    _lobe_line = startswith(lobe_str, "Lobe Context: ") ? lobe_str[length("Lobe Context: ")+1:end] : lobe_str
    println(payload_io, "Lobe Context: $_lobe_line")
    println(payload_io, "User Triples: $u_triples")
    println(payload_io, "Node Triples: $n_triples")
    println(payload_io, "Anti-Match Detected: $(primary_vote.antimatch)")
    if !isempty(tied_alternatives)
        println(payload_io, "Tied Alternatives (not selected):")
        for tv in tied_alternatives
            tv_node = lock(() -> get(NODE_MAP, tv.node_id, nothing), NODE_LOCK)
            tv_triples_str = if !isnothing(tv_node) && !isempty(tv_node.relational_patterns)
                join(["($(t.subject), $(t.relation), $(t.object))" for t in tv_node.relational_patterns], ", ")
            else
                "None"
            end
            println(payload_io, "  🪨 $(tv.node_id) | action=$(tv.action) | conf=$(round(tv.confidence, digits=2)) | relations=$tv_triples_str")
        end
    end
    if !isempty(unsure_votes)
        println(payload_io, "Other Possibilities (strong but not winners):")
        for uv in unsure_votes
            uv_node = lock(() -> get(NODE_MAP, uv.node_id, nothing), NODE_LOCK)
            uv_triples_str = if !isnothing(uv_node) && !isempty(uv_node.relational_patterns)
                join(["($(t.subject), $(t.relation), $(t.object))" for t in uv_node.relational_patterns], ", ")
            else
                "None"
            end
            println(payload_io, "  🔸 $(uv.node_id) | action=$(uv.action) | conf=$(round(uv.confidence, digits=2)) | relations=$uv_triples_str")
        end
    end
    println(payload_io, "AIML Memory Bank:")
    println(payload_io, memory_str)
    # GRUG: Lobe Curve telemetry — replaces the old "Muted Lobes / Bridged Nodes"
    # readout. Shows base_avg × top_avg = score per lobe, with 👑 marking the
    # winner and ↗ marking pass-through runners-up. See LobeOrchestrator.jl.
    try
        println(payload_io, LobeOrchestrator.last_summary())
        if !isempty(LobeOrchestrator.LAST_PASSTHROUGH[])
            println(payload_io, "Passthrough Lobes: [$(join(LobeOrchestrator.LAST_PASSTHROUGH[], ", "))]")
        end
    catch e
        println(payload_io, "Lobe Curve: <telemetry error: $e>")
    end
    print(payload_io, "=========================================")
    return String(take!(payload_io))
end

# GRUG: Family of brain actions. Command must take all vote states now!
reason_family = ["reason", "analyze", "ponder", "calculate"]
for act in reason_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        if mission == "boom"
            error("!!! FATAL: Grug triggered intentional crash to test safety nets !!!")
        end
        node.json_data["last_reason"] = mission
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        
        # GRUG: If relations match well, node stay hot. Else, cool down fast.
        rel_strength = length(primary_vote.user_triples) > 0 ? 2.0 : 0.5
        reset_throttle!(node, rel_strength)
        return generated_text
    end
end

# GRUG: Family of happy face actions.
greet_family = ["greet", "welcome", "smile", "laugh"]
for act in greet_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        reset_throttle!(node, 0.5)
        return generated_text
    end
end

# GRUG: Family of survival actions. Grug learn to run away!
survival_family = ["flee", "hide", "fight"]
for act in survival_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        # Give survival actions a unique payload if we want, or use the standard one
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Survival means danger! Keep the node throttle HOT!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# GRUG: Family of explain actions. Grug make things clear like cave painting!
explain_family = ["explain", "clarify", "describe", "define", "elaborate"]
for act in explain_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Explanations are cold logical work. Medium throttle.
        reset_throttle!(node, 0.7)

        return generated_text
    end
end

# GRUG: Family of empathy actions. Grug feel your pain!
empathy_family = ["comfort", "support", "validate", "acknowledge", "reassure"]
for act in empathy_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Emotional support - warm and open throttle.
        reset_throttle!(node, 0.5)

        return generated_text
    end
end

# GRUG: Family of warning actions. Grug shout danger before it arrives!
warning_family = ["alert", "warn", "caution", "notify", "flag"]
for act in warning_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Warnings are urgent! Keep throttle HOT like survival!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# ==============================================================================
# IMAGE BINARY DETECTION HELPER (FOR /mission AND /grow)
# ==============================================================================

"""
maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}

GRUG: Pre-screen input text for image binary using regex from ImageSDF.
If image binary found:
  1. Decode image data from Base64 (or hex)
  2. Run JITGPU — real GPU-accelerated nonlinear SDF conversion via KernelAbstractions.jl
  3. Apply EyeSystem visual processing (edge blur, attention, arousal cutout)
  4. Apply SDF jitter (pineal drip)
  5. Convert to flat Float64 signal
  6. Return (true, signal)
If no image binary: return (false, Float64[])
Throws on empty input or conversion failure — NO SILENT FAILURES.
"""
function maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}
    if strip(input_text) == ""
        error("!!! FATAL: maybe_convert_image_input got empty input! !!!")
    end

    found, fmt, payload = ImageSDF.detect_image_binary(input_text)
    if !found
        return (false, Float64[])
    end

    println("[IMAGE] 🖼  Image binary detected (format: $fmt). Running JIT SDF conversion...")

    try
        # GRUG: Decode raw image bytes based on detected format
        raw_bytes = if fmt == :base64
            base64decode(payload)
        elseif fmt == :hex_png || fmt == :hex_jpeg
            # GRUG: Convert hex string to bytes
            hex_clean = replace(payload, r"[^A-Fa-f0-9]" => "")
            # GRUG: Hex must be even length (2 chars per byte)
            if length(hex_clean) % 2 != 0
                hex_clean = hex_clean[1:end-1]
            end
            UInt8[parse(UInt8, hex_clean[i:i+1], base=16) for i in 1:2:length(hex_clean)]
        else
            # GRUG: Raw binary escape sequences - use payload bytes directly
            Vector{UInt8}(codeunits(payload))
        end

        if isempty(raw_bytes)
            error("!!! FATAL: Image decode produced empty byte array for format $fmt! !!!")
        end

        # GRUG: Estimate dimensions from byte count (assume square grayscale as fallback).
        # Real use case: width/height should come from image metadata.
        # For this JIT path, Grug use sqrt to estimate square-ish dimensions.
        n_bytes     = length(raw_bytes)
        est_side    = max(1, round(Int, sqrt(Float64(n_bytes))))
        est_width   = est_side
        est_height  = max(1, n_bytes ÷ est_side)

        # GRUG: Run JIT GPU-accelerated image -> SDFParams conversion
        # JITGPU dispatches real KernelAbstractions kernels: CUDA/ROC/Metal/CPU.
        # CPU() is genuine multithreaded kernel dispatch, not a fake fallback.
        sdf_params  = ImageSDF.JITGPU(raw_bytes; width=est_width, height=est_height)

        # GRUG: Apply EyeSystem visual processing (blur + attention modulation + arousal cutout)
        mod_brightness, _attn_map = EyeSystem.process_visual_input(
            sdf_params.brightnessArray,
            sdf_params.colorArray,
            sdf_params.xArray,
            sdf_params.yArray,
            sdf_params.width,
            sdf_params.height
        )

        # GRUG: Rebuild SDFParams with eye-processed brightness before jitter
        eye_params = ImageSDF.SDFParams(
            sdf_params.xArray, sdf_params.yArray,
            mod_brightness, sdf_params.colorArray,
            sdf_params.width, sdf_params.height,
            sdf_params.timestamp
        )

        # GRUG: Apply pineal drip jitter (slight deviation from bullseye, snaps back next call)
        jittered_params = ImageSDF.apply_sdf_jitter(eye_params)

        # GRUG: Convert to flat signal vector for PatternScanner compatibility
        signal = ImageSDF.sdf_to_signal(jittered_params; max_samples=256)

        println("[IMAGE] ✅  JIT SDF conversion complete. Signal length: $(length(signal)).")
        return (true, signal)

    catch e
        # GRUG: Image conversion failure is LOUD. No silent swallowing!
        error("!!! FATAL: JIT image->SDF conversion failed for format $fmt: $e !!!")
    end
end

# ==============================================================================
# MISSION PROCESSOR (EXTRACTED FOR QUEUE REUSE)
# ==============================================================================

# ==============================================================================
# GRUG: Consolidated UI string constants for compiler efficiency.
# Single-string print replaces ~100 individual println calls.
# Same output, zero string-table bloat at compile time.
# ==============================================================================

const BOOT_MSG = """
System Online. Grug waiting at cave entrance for instructions.
Primary  : /mission <input>                    (text or image binary)
Feedback : /wrong                              (penalize last response voters)
Explicit : /explicit <cmd> [<node_id>] <input>
Grow     : /grow <lobe_id> <json_packet>      (plant node(s) into a lobe)
         :   • <lobe_id> is required — use `-` for unassigned pool
         :   • Single node: {"pattern":"...","action_packet":"...","data":{...}}
         :   • Multi node:  {"nodes":[{...},{...}]}
         :   • `data.system_prompt` defaults to "Grug speaks plainly." if absent
Rules    : /addRule <rule text> [prob=0.0-1.0]
           Tags: {MISSION}, {PRIMARY_ACTION}, {SURE_ACTIONS}, {UNSURE_ACTIONS},
                 {ALL_ACTIONS}, {CONFIDENCE}, {NODE_ID}, {MEMORY}, {LOBE_CONTEXT}
Memory   : /pin <text>
Nodes    : /nodes                              (show node map status)
Status   : /status                             (show chatter + system status)
Arousal  : /arousal <0.0-1.0>                 (set eye system arousal level)
Verbs    : /addVerb <verb> <class>             (add verb to relation class)
         : /addRelationClass <name>            (create new verb class bucket)
         : /addSynonym <canonical> <alias>     (normalize alias->canonical)
         : /listVerbs                          (show all verb classes + synonyms)
Lobes    : /newLobe <id> <subject>             (create a new subject lobe)
         : /connectLobes <id_a> <id_b>         (connect two lobes)
         : /lobeGrow <lobe_id> <json_packet>   (DEPRECATED — alias for /grow)
         : /lobes                              (list all lobes + node counts)
         : /tableStatus <lobe_id>              (show hash table chunks for a lobe)
         : /tableMatch <lobe_id> <chunk> <pat> (pattern-activate entries in chunk)
Thesaurus: /thesaurus <word1> | <word2>        (compare words/concepts dimensionally)
         : /thesaurus <w1> | <w2> :: <ctx1> :: <ctx2>  (with context lists)
NegThes  : /negativeThesaurus add|remove|list|check|flush
Attach   : /nodeAttach <target> <id> <pat> ...  (attach nodes with relational fire patterns)
         : /nodeDetach <target> <id>            (detach a node from target)
ImgAttach: /imgnodeAttach <tgt> <id> <b64> [w h] (attach image node with SDF-based fire)
         : /imgnodeDetach <target> <id>         (detach image node from target)
         : /attachments                         (show all node attachments)
Specimen : /saveSpecimen <filepath>            (save full cave state to compressed file)
         : /loadSpecimen <filepath>            (restore full cave state from compressed file)
Help     : /help                               (full command reference)

╔══════════════════════════════════════════════════════════════════╗
║  SPECIMEN SEEDING GUIDE (read before /grow)                     ║
╠══════════════════════════════════════════════════════════════════╣
║  Automatic neighbor latching is SUPPRESSED below 1000 nodes.   ║
║  Below that threshold, YOU control topology via drop_table.     ║
║                                                                  ║
║  For a coherent specimen from the start:                        ║
║  1. Seed ORTHOGONAL archetypes first - distinct semantic poles. ║
║     Don't plant 50 near-identical nodes up front.               ║
║  2. Use required_relations as semantic GATES from day one.      ║
║     Nodes that demand specific verbs won't fire on noise.       ║
║  3. Name action_packets deliberately - distinct action families ║
║     give the superposition orchestrator something to work with. ║
║  4. Wire drop_tables manually for known co-activation pairs.    ║
║     Don't rely on the latch system to discover semantics.       ║
║  5. Your first ~100 nodes are the specimen's DNA.               ║
║     The engine enforces structure at scale (1000+ nodes).       ║
║     You enforce MEANING at the start.                           ║
╚══════════════════════════════════════════════════════════════════╝
"""

const HELP_MSG = """
╔══════════════════════════════════════════════════════════════╗
║                  GRUGBOT COMMAND REFERENCE                  ║
╠══════════════════════════════════════════════════════════════╣
║  CORE                                                        ║
║  /mission <text>            Send input to the AI engine      ║
║  /brainstorm <text>         Like /mission but with heavy     ║
║                             scoped jitter (far-jump before   ║
║                             snap back) to escape local       ║
║                             minima for one mission           ║
║  /wrong                     Penalize last contributors    ║
║  /aimlRight                 Reward AIML contributors     ║
 │  /right                     Reward last contributors         │
║  /aimlWrong                 Penalize AIML contributors   ║
║  /explicit <cmd> [<id>] <t> Force a specific command+node    ║
║  /grow <json>               Plant nodes from JSON packet     ║
║  /addRule <rule>            Add stochastic orchestration rule║
║  /pin <text>                Pin text to memory cave wall     ║
║                                                              ║
║  STATUS                                                      ║
║  /nodes                     Show all node map status         ║
║  /status                    Full system health snapshot      ║
║  /arousal <0.0-1.0>         Set eye system arousal level     ║
║                                                              ║
║  SEMANTIC VERBS                                              ║
║  /addVerb <verb> <class>    Add verb to relation class       ║
║  /addRelationClass <name>   Create new verb class bucket     ║
║  /addSynonym <canon> <alias> Register synonym normalization  ║
║  /listVerbs                 Show verb registry               ║
║                                                              ║
║  LOBES & TABLES                                              ║
║  /newLobe <id> <subject>    Create new subject partition     ║
║  /connectLobes <a> <b>      Link two lobes bidirectionally   ║
║  /lobeGrow <id> <json>      Grow node directly into lobe     ║
║  /lobes                     Show lobe status summary         ║
║  /tableStatus <lobe_id>     Show hash table chunk sizes      ║
║  /tableMatch <l> <c> <pat>  Pattern-activate table entries   ║
║                                                              ║
║  AIML NODE SYSTEM                                            ║
║  /aimlStatus                 Show AIML tribe status          ║
║  /aimlList <lobe_id>         List AIML nodes in lobe         ║
║  /aimlAdd <l> <id> <tmpl>    Add AIML node to lobe           ║
║  /aimlRemove <l> <id>        Remove AIML node from lobe      ║
║  /aimlRight                  Reward AIML contributors    ║
║  /aimlWrong                  Penalize AIML contributors  ║
║  /aimlCycle                  Show current cycle info         ║
║  /aimlPhagy                  Run phagy sweep on AIML graves  ║
║                                                              ║
║  THESAURUS                                                   ║
║  /thesaurus <w1> | <w2>     Dimensional similarity compare   ║
║                                                              ║
║  NEGATIVE THESAURUS (INHIBITION FILTER)                     ║
║  /negativeThesaurus add <word> [--reason <text>]             ║
║  /negativeThesaurus remove <word>                           ║
║  /negativeThesaurus list                                    ║
║  /negativeThesaurus check <word>                            ║
║  /negativeThesaurus flush                                   ║
║                                                              ║
║  RELATIONAL FIRE (NODE ATTACHMENTS)                          ║
║  /nodeAttach <tgt> <id> <pat> ...                            ║
║    Attach up to 4 nodes to target with firing patterns       ║
║    Confidence JIT-baked at attach time (not at fire time)    ║
║    Example: /nodeAttach node_0 node_1 "fire pattern"         ║
║  /nodeDetach <target> <id>   Detach node from target         ║
║  /imgnodeAttach <tgt> <id> <b64> [w h]                       ║
║    Attach image node with SDF-based relational fire          ║
║    Image→SDF conversion at attach time (JIT GPU accel)       ║
║    Example: /imgnodeAttach n0 img1 "data:image/png;..." 64 64║
║  /imgnodeDetach <tgt> <id>   Detach image node from target   ║
║  /attachments                Show all attachment map          ║
║                                                              ║
║  SPECIMEN PERSISTENCE                                        ║
║  /saveSpecimen <filepath>    Save full cave to compressed gz ║
║  /loadSpecimen <filepath>    Restore full cave from gz file  ║
║    Saves/restores: nodes, lobes, lobe tables, Hopfield,     ║
║    rules, messages+pins, verbs, thesaurus, inhibitions,     ║
║    arousal, ID counters, brainstem state, attachments        ║
║                                                              ║
║  ADMIN COMMANDS (password protected)                         ║
║  /login <password>           Authenticate as admin           ║
║  /logout                     End admin session               ║
║  /writeSave <filepath> <json> Append JSON to save file       ║
║    Requires admin login. Validates JSON before writing.     ║
║    Use for runtime modifications to saved specimen data.    ║
║                                                              ║
║  /help                      Show this scroll                ║
║  /quit (or /exit)           Close cave and exit CLI loop    ║
╠══════════════════════════════════════════════════════════════╣
║  🛡  IMMUNE SYSTEM (auto-gates all structure-storing cmds)  ║
║  Gated: /grow /lobeGrow /addRule /pin /addVerb              ║
║         /addRelationClass /addSynonym /newLobe              ║
║         /connectLobes /negativeThesaurus-add                ║
║         /loadSpecimen /nodeAttach /imgnodeAttach            ║
║  Exempt: /mission and all read-only commands                ║
║                                                              ║
║  🎲  VOTE CERTAINTY  SURE=clear winner  UNSURE=ties exist   ║
║  AIML tags: {VOTE_CERTAINTY}  {TIED_ALTERNATIVES}           ║
╚══════════════════════════════════════════════════════════════╝
"""

# GRUG: Track last voter IDs so /wrong knows who to punish
const LAST_VOTER_IDS = String[]
const LAST_VOTER_LOCK = ReentrantLock()
const LAST_CONTRIBUTOR_IDS = String[]  # Node IDs that actually contributed to output (fired)

"""
process_mission(mission_text::String)

GRUG: Core mission processing logic, extracted so chatter queue can reuse it.
Handles both text missions and image-binary missions.
Measures response time and records it on the winning nodes for big-O ledger.
"""
function process_mission(mission_text::String)
    if strip(mission_text) == ""
        error("!!! FATAL: process_mission got empty mission text! !!!")
    end

    # GRUG: Start a new AIML cycle. Resets all per-cycle bookkeeping flags on every
    # AIML node so /aimlRight and /aimlWrong know exactly what fired THIS cycle.
    # Must run BEFORE any AIML voting/firing so cycle memory is clean at the start.
    AIMLNodeSystem.begin_cycle!()

    add_message_to_history!("User", mission_text, false)
    
    # GRUG: Pre-screen for image binary BEFORE normal scan
    is_image, img_signal = maybe_convert_image_input(mission_text)

    # GRUG: ACTION+TONE AROUSAL PRE-SET (text inputs only)
    # For text missions, run the predictor here to nudge EyeSystem arousal BEFORE
    # the scan starts. Image inputs skip this — SDF has its own visual arousal path.
    #
    # WHY HERE AND NOT JUST IN scan_specimens?
    # scan_specimens uses the prediction for confidence weighting (its own concern).
    # Arousal is an EyeSystem concern — it belongs in Main where EyeSystem lives.
    # Running it here means the eye is already tuned by the time scan fires.
    # The two calls are intentionally separate: one modulates scan weights,
    # the other modulates the visual attention gate. They are orthogonal.
    #
    # GRUG: Non-fatal on error. Arousal nudge is enhancement, not core pipeline.
    # If prediction throws for any reason, cave still scans normally.
    if !is_image
        try
            prediction = ActionTonePredictor.predict_action_tone(
                mission_text, SemanticVerbs.get_all_verbs()
            )
            ActionTonePredictor.apply_prediction_to_arousal!(
                prediction,
                EyeSystem.get_arousal,
                EyeSystem.set_arousal!
            )
        catch e
            @warn "[MAIN] ActionTonePredictor arousal nudge failed (non-fatal): $e"
        end
    end

    # GRUG: THESAURUS GATE EXPANSION (text inputs only)
    # Before the scan fires, expand the mission tokens with synonym cloud.
    # This bridges the structural gap (happy/joyful = 0.0 without seeds).
    # Expansion is logged so operator can see what the gate added.
    # Non-fatal: if thesaurus throws for any reason, scan proceeds on raw text.
    if !is_image
        try
            gate_tokens = Thesaurus.thesaurus_gate_filter(mission_text)
            original_tokens = Set(split(lowercase(strip(mission_text))))
            new_tokens = setdiff(gate_tokens, original_tokens)
            if !isempty(new_tokens)
                @info "[MAIN] 🔤 Thesaurus gate expanded $(length(original_tokens)) tokens → $(length(gate_tokens)) (+$(length(new_tokens)) synonyms: $(join(sort(collect(new_tokens)), ", ")))"
            end
        catch e
            @warn "[MAIN] Thesaurus gate expansion failed (non-fatal): $e"
        end
    end

    println("--> Scanning specimens & looking for dialectical relations...")
    t_start = time()

    # GRUG: Build the DONE channel for this cycle. One slot per "lobe" unit of
    # fire work. Here we treat the entire scan+expand as one logical lobe
    # (the cave-wide firing pass). If we later split into per-lobe parallel
    # fire, each lobe gets its own slot and its own DoneSignal put.
    # This makes the DONE protocol the official handoff from the fire layer
    # to the orchestrator layer, per architecture spec.
    done_channel = VoteOrchestrator.make_done_channel(8)

    # GRUG: SCAN SUB-PROCESS DISPATCH!
    # The whole scan+expand is its own Task with a unique non-colliding name
    # and a hard timeout. If scan deadlocks (e.g. a wedged batch slipped through
    # the inner batch_timeout), the scan-task timeout catches it at the outer
    # boundary. TaskTimeoutError surfaces loudly — NO SILENT FAILURES.
    # Timeout is derived from FIRE_BATCH_TIMEOUT_S * expected-batch-count margin:
    # 30s is more than enough for any realistic cave, still bounded.
    scan_task_name, scan_task = VoteOrchestrator.dispatch_task_with_timeout(
        () -> begin
            if is_image
                println("[IMAGE] 🔍  Routing to image node scan path...")
                return _scan_image_specimens(img_signal)
            else
                return scan_and_expand(mission_text)
            end
        end,
        "scan_cycle",
        30.0;
        context = "run_mission.scan"
    )

    valid_specimens = try
        VoteOrchestrator.fetch_with_timeout(scan_task_name, scan_task)
    catch e
        # GRUG: Scan exploded or timed out. Scream, then fail loudly —
        # cave cannot respond without scan results. NO SILENT FAILURES.
        if e isa VoteOrchestrator.TaskTimeoutError
            @error "[MAIN] Scan sub-process TIMEOUT: $e"
        else
            @error "[MAIN] Scan sub-process FAILED: $e"
        end
        rethrow(e)
    end

    # GRUG: LOBE FIRING COMPLETE → emit DONE to the orchestrator layer.
    # This is the explicit boundary requested by the architecture spec:
    # "once a lobe is finished firing everything then it sends DONE to the
    # orchestrator layer". The orchestrator (ephemeral_aiml_orchestrator)
    # will only run after DONE is received.
    try
        # GRUG: _LAST_FIRE_COUNTER is declared in engine.jl, which is included
        # into the SAME enclosing module as this file (the GrugBot420 package
        # module when loaded via `using GrugBot420`, or the user's top-level
        # Main when dev-included directly). Either way, the Ref is a sibling
        # binding — reference it bare, never via `Main.` which only resolves
        # in the dev-include case and breaks the packaged path.
        scan_fc = _LAST_FIRE_COUNTER[]
        fires_total = isnothing(scan_fc) ? 0 : VoteOrchestrator.current_fire_count(scan_fc)
        VoteOrchestrator.send_done!(done_channel, VoteOrchestrator.DoneSignal(
            "scan_pass",
            fires_total,
            length(valid_specimens),
            time() - t_start,
            nothing
        ))
    catch e
        # GRUG: Sending DONE should never fail (channel is bounded to 8, we put 1).
        # If it does, log loudly — but don't abort the response pipeline.
        @warn "[MAIN] Failed to send scan DONE signal: $e"
    end

    # GRUG: Orchestrator waits for DONE before picking winners. Timeout 5s —
    # scan should already be done, this is just the formal handoff. If DONE
    # never arrives we still proceed (non-fatal) but log loudly so operator
    # can debug the stuck lobe.
    try
        _signals = VoteOrchestrator.wait_for_done(done_channel, 1; timeout_s = 5.0)
        # GRUG: signals is informational — log if any lobe reported an error.
        for s in _signals
            if !isnothing(s.error)
                @warn "[MAIN] Lobe '$(s.lobe_id)' reported error in DONE: $(s.error)"
            end
        end
    catch e
        @warn "[MAIN] DONE wait failed (non-fatal, orchestrator will still run): $e"
    end

    if isempty(valid_specimens)
        println("--> No valid specimens found for this input. Cave is silent.")
        return
    end

    # GRUG v7.12: CONTEXT INTENSITY REFRESH (pattern-bind / relational phase).
    # Scan just finished - relational triples for the user input are hot.
    # Now (BEFORE vote casting and AIML payload build) we:
    #   1. Re-score every message in MESSAGE_HISTORY for relevance to the
    #      current mission text (lexical + dynamic-relational overlap).
    #   2. Snap each intensity toward its relevance score (SNAP_ALPHA pull).
    #   3. Apply the same zero-mean RelationalJitter used everywhere else so
    #      the stochastic character of the cave stays aligned across layers.
    #   4. Clamp to [FLOOR, CAP].
    # Downstream, extract_aiml_memory_context() coinflips unpinned messages
    # biased by intensity instead of blindly grabbing the last N. Irrelevant
    # chatter decays and drops out; relevant history rises and sticks.
    # Wrapped: the refresh must never abort the mission. If anything inside
    # explodes we scream loudly (no silent failures) and continue with the
    # existing intensities.
    try
        refresh_message_intensities!(mission_text)
    catch e
        @error "[MAIN] Context intensity refresh FAILED (continuing with stale intensities): $e"
    end

    # GRUG: CAST-VOTE SUB-PROCESS DISPATCH!
    # Building Vote objects from specimens is its own bounded sub-process.
    # Each cast_vote touches NODE_MAP, selects a stochastic action, and can
    # bump strength. Dispatched to its own Task with a unique name + timeout.
    # Typical runtime: well under 1s for 1000 specimens. 10s guard is generous.
    cast_votes_task_name, cast_votes_task = VoteOrchestrator.dispatch_task_with_timeout(
        () -> begin
            out = Vote[]
            for (id, conf, is_antimatch, u_trips, n_trips) in valid_specimens
                push!(out, cast_vote(id, conf, is_antimatch, u_trips, n_trips))
            end
            return out
        end,
        "cast_votes",
        10.0;
        context = "run_mission.cast_votes"
    )
    cast_votes = try
        VoteOrchestrator.fetch_with_timeout(cast_votes_task_name, cast_votes_task)
    catch e
        if e isa VoteOrchestrator.TaskTimeoutError
            @error "[MAIN] cast_votes sub-process TIMEOUT: $e"
        else
            @error "[MAIN] cast_votes sub-process FAILED: $e"
        end
        rethrow(e)
    end

    println("--> $(length(cast_votes)) valid votes passed gate... compiling JIT superposition...")

    # GRUG: ORCHESTRATOR SUB-PROCESS DISPATCH!
    # The AIML orchestrator is itself dispatched to a unique Task with a timeout.
    # It reads votes, applies threshold + top-tier + strength-biased coinflip
    # selection, then fires the generative engine. Typical runtime: <2s.
    # 20s guard catches any deadlock in the generative path (JIT layer can
    # occasionally take time on first-hit compilation). NO SILENT FAILURES.
    orch_task_name, orch_task = VoteOrchestrator.dispatch_task_with_timeout(
        () -> ephemeral_aiml_orchestrator(mission_text, cast_votes),
        "aiml_orchestrator",
        20.0;
        context = "run_mission.orchestrator"
    )
    output, sure_votes, unsure_votes = try
        VoteOrchestrator.fetch_with_timeout(orch_task_name, orch_task)
    catch e
        if e isa VoteOrchestrator.TaskTimeoutError
            @error "[MAIN] AIML orchestrator sub-process TIMEOUT: $e"
        else
            @error "[MAIN] AIML orchestrator sub-process FAILED: $e"
        end
        rethrow(e)
    end

    t_elapsed = time() - t_start

    # GRUG: Merge sure and unsure votes - these are the contributors (votes that generated output)
    contributing_votes = vcat(sure_votes, unsure_votes)
    
    # GRUG: Mark contributing nodes and record response time
    for v in cast_votes
        voter_node = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
        if !isnothing(voter_node)
            # Mark all voters as voted_this_cycle
            voter_node.voted_this_cycle = true
            # Record response time on all winning node voters for big-O ledger
            record_response_time!(voter_node, t_elapsed)
        end
    end
    
    # GRUG: Mark contributing nodes as fired_this_cycle
    lock(NODE_LOCK) do
        for v in contributing_votes
            node = get(NODE_MAP, v.node_id, nothing)
            if !isnothing(node)
                node.fired_this_cycle = true
            end
        end
    end

    # GRUG: Store voter IDs so /wrong can punish them if user is unhappy
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
        append!(LAST_VOTER_IDS, [v.node_id for v in cast_votes])
    end
    
    # GRUG: Store contributor IDs for /right and /wrong feedback
    # Only nodes that actually contributed to output should be reinforced/penalized
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_CONTRIBUTOR_IDS)
        append!(LAST_CONTRIBUTOR_IDS, [v.node_id for v in contributing_votes])
    end

    println("\n🤖 AIML Output Scaffold:\n$output")

    # GRUG v7.14: Do NOT store the full scaffold verbatim in MESSAGE_HISTORY.
    # The scaffold embeds the entire Fresh Memory block, so storing it
    # causes each cycle's output to become next cycle's context and
    # recurse forever — that is the O(N²) bloat that v7.12 context
    # intensity fixed for log size but still corrupted output quality
    # because the banner tails kept leaking forward. Instead store a
    # single-line digest that captures the semantic essentials: user
    # asked X → Grug answered with primary=Y on node=Z. That digest is
    # still relevance-scorable against future prompts (lexical+triple
    # overlap picks up the mission text) but carries no recursive
    # scaffold embedding.
    digest = try
        if !isempty(contributing_votes)
            win = contributing_votes[1]
            "Mission \"$(mission_text)\" → primary=$(win.action) conf=$(round(win.confidence, digits=2)) node=$(win.node_id)"
        else
            # GRUG: Should never happen (we guarded on isempty(valid_specimens)
            # well upstream) but be defensive. NO SILENT FAILURES — the
            # string still captures the mission so a future cycle can
            # score it.
            "Mission \"$(mission_text)\" → [no contributing vote — silent cycle]"
        end
    catch e
        @warn "[MAIN v7.14] Failed to build mission digest ($e); storing mission text only"
        "Mission \"$(mission_text)\""
    end
    add_message_to_history!("System", digest, false)
end

# ==============================================================================
# IMAGE NODE SCAN PATH
# ==============================================================================

"""
_scan_image_specimens(img_signal::Vector{Float64})::Vector{Tuple{...}}

GRUG: Scan only image nodes using SDF signal vector.
Text nodes are skipped. Image nodes use their stored SDF signal for comparison.
Returns same tuple format as scan_specimens for uniform downstream processing.
"""
function _scan_image_specimens(img_signal::Vector{Float64})
    if isempty(img_signal)
        error("!!! FATAL: _scan_image_specimens got empty img_signal! !!!")
    end

    results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            # GRUG: Only image nodes respond to image signals
            !node.is_image_node && continue
            node.is_grave       && continue

            # GRUG: Strength-biased coinflip applies to image nodes too
            !strength_biased_scan_coinflip(node) && continue

            # GRUG: Image node needs a non-empty SDF signal to compare against
            if isempty(node.signal)
                # GRUG: Image node has no signal baked in yet. Skip safely.
                continue
            end

            # GRUG: Use cheap_scan for image signals (SDF comparison)
            try
                target = length(img_signal) >= length(node.signal) ? img_signal : continue
                _, conf = cheap_scan(target, node.signal; threshold=0.25)
                push!(results, (id, conf, false, RelationalTriple[], node.relational_patterns))
            catch e
                if e isa PatternNotFoundError
                    continue
                elseif e isa PatternScanError
                    rethrow(e)
                else
                    error("!!! FATAL: Unknown error in _scan_image_specimens for node $id: $e !!!")
                end
            end
        end
    end

    return results
end

# ==============================================================================
# SPECIMEN PERSISTENCE (SAVE / LOAD FULL CAVE STATE FROM COMPRESSED FILE)
# ==============================================================================

# GRUG: /saveSpecimen writes the ENTIRE cave state to a gzip-compressed JSON file.
# /loadSpecimen reads that file back and RESTORES the ENTIRE cave from scratch.
# This is LONG-TERM STORAGE. Not "add a few nodes" — this is "freeze the whole brain,
# put it in a jar, thaw it later with every neuron exactly where Grug left it."
# No silent failures. No half-restores. If the file is bad, NOTHING changes.
# Grug screams loud. Grug validates everything. Grug is paranoid.

"""
save_specimen_to_file!(filepath::String)::String

GRUG: Serialize the ENTIRE cave state to a gzip-compressed JSON file.
Captures ALL mutable state across all modules:
  - nodes       (full Node struct: strengths, patterns, neighbors, graves, etc.)
  - hopfield    (HOPFIELD_CACHE + hit counts)
  - rules       (AIML_DROP_TABLE stochastic rules)
  - messages    (up to 10k message history with pin flags)
  - lobes       (LOBE_REGISTRY: fire/inhibit counts, connections, node assignments)
  - lobe_tables (LOBE_TABLE_REGISTRY: all chunks with NodeRef objects)
  - verbs       (verb classes + verbs + synonyms from SemanticVerbs)
  - thesaurus   (SYNONYM_SEED_MAP runtime additions from Thesaurus)
  - inhibitions (NegativeThesaurus entries from InputQueue)
  - arousal     (EyeSystem arousal state: level, decay, baseline)
  - eye_state   (EyeSystem tracking: attention, centroid, last_arousal)
  - counters    (NODE ID_COUNTER + MSG_ID_COUNTER)
  - last_voters (LAST_VOTER_IDS for /wrong feedback)
  - brainstem   (dispatch count, propagation history)
  - attachments (ATTACHMENT_MAP relational fire system)
  - trajectory  (ActionTonePredictor ring buffer + config)
  - temporal    (ImageSDF TEMPORAL_COHERENCE_LEDGER timing patterns)
  - cooldowns   (ChatterMode MORPH_COOLDOWN_MAP 24h morph timestamps)

Format: v2.4 (backward-compatible with v2.0+ on load).
Returns a formatted summary string.
"""
function save_specimen_to_file!(filepath::String)::String
    if strip(filepath) == ""
        error("!!! FATAL: /saveSpecimen got empty filepath! Grug cannot write to invisible air! !!!")
    end

    # GRUG: Build the specimen dict — one key per state category.
    specimen = Dict{String, Any}()
    t_start = time()

    # ── 1. NODES ──────────────────────────────────────────────────────────
    # GRUG: Serialize every node in NODE_MAP with ALL fields.
    # We bypass create_node() on restore and inject directly, so we need EVERYTHING.
    node_list = Dict{String, Any}[]
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            nd = Dict{String, Any}(
                "id"                  => node.id,
                "pattern"             => node.pattern,
                "signal"              => node.signal,
                "action_packet"       => node.action_packet,
                "json_data"           => node.json_data,
                "drop_table"          => node.drop_table,
                "throttle"            => node.throttle,
                "relational_patterns" => [Dict("subject" => rt.subject, "relation" => rt.relation, "object" => rt.object)
                                          for rt in node.relational_patterns],
                "required_relations"  => node.required_relations,
                "relation_weights"    => node.relation_weights,
                "strength"            => node.strength,
                "is_image_node"       => node.is_image_node,
                "neighbor_ids"        => node.neighbor_ids,
                "is_unlinkable"       => node.is_unlinkable,
                "is_grave"            => node.is_grave,
                "grave_reason"        => node.grave_reason,
                "response_times"      => node.response_times,
                "ledger_last_cleared" => node.ledger_last_cleared,
                "hopfield_key"        => string(node.hopfield_key)  # UInt64 -> String for JSON safety
            )
            push!(node_list, nd)
        end
    end
    specimen["nodes"] = node_list

    # ── 2. HOPFIELD CACHE ─────────────────────────────────────────────────
    # GRUG: Serialize Hopfield fast-path cache keyed by UInt64 hash -> node ID list.
    hopfield_entries = Dict{String, Any}[]
    lock(HOPFIELD_CACHE_LOCK) do
        for (h, ids) in HOPFIELD_CACHE
            push!(hopfield_entries, Dict{String, Any}(
                "hash"      => string(h),
                "node_ids"  => ids,
                "hit_count" => get(HOPFIELD_HIT_COUNTS, h, 0)
            ))
        end
    end
    specimen["hopfield_cache"] = hopfield_entries

    # ── 3. RULES (AIML_DROP_TABLE) ────────────────────────────────────────
    # GRUG: r.text and r.fire_probability are the actual struct field names.
    # Academic: Previously used r.rule_text / r.fire_prob which would cause a
    # Julia field access error at runtime. Fixed in v2.1.
    rule_list = [Dict{String, Any}("text" => r.text, "prob" => r.fire_probability) for r in AIML_DROP_TABLE]
    specimen["rules"] = rule_list

    # ── 4. MESSAGE HISTORY ────────────────────────────────────────────────
    # GRUG: Serialize the full message cave (up to 10k entries). Pins are preserved.
    # GRUG v7.12: intensity also persists so context heat carries across saves.
    # Older specimens without the field load fine — restore path defaults to
    # CONTEXT_INTENSITY_BASELINE when key is missing (see /loadSpecimen below).
    msg_list = [Dict{String, Any}(
        "id"        => m.id,
        "role"      => m.role,
        "text"      => m.text,
        "pinned"    => m.pinned,
        "intensity" => m.intensity
    ) for m in MESSAGE_HISTORY]
    specimen["message_history"] = msg_list

    # ── 5. LOBES ──────────────────────────────────────────────────────────
    lobe_list = Dict{String, Any}[]
    lock(Lobe.LOBE_LOCK) do
        for (id, rec) in Lobe.LOBE_REGISTRY
            push!(lobe_list, Dict{String, Any}(
                "id"                 => rec.id,
                "subject"            => rec.subject,
                "node_ids"           => sort(collect(rec.node_ids)),
                "connected_lobe_ids" => sort(collect(rec.connected_lobe_ids)),
                "node_cap"           => rec.node_cap,
                "fire_count"         => rec.fire_count,
                "inhibit_count"      => rec.inhibit_count,
                "created_at"         => rec.created_at
            ))
        end
    end
    specimen["lobes"] = lobe_list

    # ── 6. NODE_TO_LOBE_IDX ──────────────────────────────────────────────
    node_lobe_idx = Dict{String, String}()
    lock(Lobe.LOBE_LOCK) do
        for (nid, lid) in Lobe.NODE_TO_LOBE_IDX
            node_lobe_idx[nid] = lid
        end
    end
    specimen["node_to_lobe_idx"] = node_lobe_idx

    # ── 7. LOBE TABLES ───────────────────────────────────────────────────
    # GRUG: Serialize all lobe table chunks. NodeRef objects are converted to dicts.
    lobe_table_list = Dict{String, Any}[]
    lock(LobeTable.TABLE_REGISTRY_LOCK) do
        for (lid, rec) in LobeTable.LOBE_TABLE_REGISTRY
            chunks_data = Dict{String, Any}()
            for (cname, chunk) in rec.chunks
                lock(chunk.lock) do
                    entries = Dict{String, Any}()
                    for (k, v) in chunk.store
                        if v isa LobeTable.NodeRef
                            entries[k] = Dict{String, Any}(
                                "_type"       => "NodeRef",
                                "node_id"     => v.node_id,
                                "lobe_id"     => v.lobe_id,
                                "is_active"   => v.is_active,
                                "inserted_at" => v.inserted_at
                            )
                        else
                            # GRUG: Generic value — store as-is (json, drop, hopfield, meta chunks)
                            entries[k] = v
                        end
                    end
                    chunks_data[cname] = entries
                end
            end
            push!(lobe_table_list, Dict{String, Any}(
                "lobe_id"    => rec.lobe_id,
                "chunks"     => chunks_data,
                "created_at" => rec.created_at
            ))
        end
    end
    specimen["lobe_tables"] = lobe_table_list

    # ── 8. VERB REGISTRY ─────────────────────────────────────────────────
    verb_data = Dict{String, Any}()
    lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
        classes = Dict{String, Any}()
        for (cls, verbs) in SemanticVerbs._VERB_REGISTRY
            classes[cls] = sort(collect(verbs))
        end
        verb_data["classes"] = classes
        verb_data["synonyms"] = copy(SemanticVerbs._SYNONYM_MAP)
    end
    specimen["verb_registry"] = verb_data

    # ── 9. THESAURUS SEEDS ────────────────────────────────────────────────
    # GRUG: Serialize the SYNONYM_SEED_MAP (includes hardcoded + runtime additions).
    thesaurus_data = Dict{String, Any}()
    lock(Thesaurus.SEED_MAP_LOCK) do
        for (word, syns) in Thesaurus.SYNONYM_SEED_MAP
            thesaurus_data[word] = sort(collect(syns))
        end
    end
    specimen["thesaurus_seeds"] = thesaurus_data

    # ── 10. INHIBITIONS (NegativeThesaurus) ───────────────────────────────
    inhib_list = Dict{String, Any}[]
    lock(InputQueue._NEG_LOCK) do
        for (word, entry) in InputQueue._NEG_THESAURUS
            push!(inhib_list, Dict{String, Any}(
                "word"     => entry.word,
                "reason"   => entry.reason,
                "added_at" => entry.added_at
            ))
        end
    end
    specimen["inhibitions"] = inhib_list

    # ── 11. AROUSAL STATE ─────────────────────────────────────────────────
    arousal_data = Dict{String, Any}()
    lock(EyeSystem.AROUSAL_LOCK) do
        arousal_data["level"]      = EyeSystem.AROUSAL_STATE.level
        arousal_data["decay_rate"] = EyeSystem.AROUSAL_STATE.decay_rate
        arousal_data["baseline"]   = EyeSystem.AROUSAL_STATE.baseline
    end
    specimen["arousal"] = arousal_data

    # ─── 11.5 EYE STATE ────────────────────────────────────────────────────────
    # GRUG: Save eye tracking state for continuity across reloads.
    # Includes last detected centroid position and arousal at last processing.
    eye_state_data = Dict{String, Any}()
    lock(EyeSystem.EYE_STATE_LOCK) do
        es = EyeSystem.DEFAULT_EYE_STATE
        eye_state_data["attention_enabled"] = es.attention_enabled
        eye_state_data["blur_enabled"] = es.blur_enabled
        eye_state_data["last_centroid_x"] = es.last_centroid_x
        eye_state_data["last_centroid_y"] = es.last_centroid_y
        eye_state_data["last_arousal"] = es.last_arousal
    end
    specimen["eye_state"] = eye_state_data

    # ── 12. ID COUNTERS ──────────────────────────────────────────────────
    specimen["id_counters"] = Dict{String, Any}(
        "node_id_counter" => ID_COUNTER[],
        "msg_id_counter"  => MSG_ID_COUNTER[]
    )
    # ─── 12.5 LAST VOTER IDS ────────────────────────────────────────────────────────
    # GRUG: Save last voter IDs so /wrong works after save/load.
    # Without this, /wrong has no idea who voted after a reload!
    last_voters = lock(LAST_VOTER_LOCK) do
        copy(LAST_VOTER_IDS)
    end
    specimen["last_voters"] = last_voters


    # ── 13. BRAINSTEM STATE ──────────────────────────────────────────────
    brainstem_data = Dict{String, Any}()
    lock(BrainStem.BRAINSTEM_LOCK) do
        bs = BrainStem.BRAINSTEM_STATE
        brainstem_data["dispatch_count"]  = bs.dispatch_count
        brainstem_data["last_winner_id"]  = bs.last_winner_id
        brainstem_data["last_dispatch_t"] = bs.last_dispatch_t
        brainstem_data["propagation_history"] = [
            Dict{String, Any}(
                "source_lobe_id" => pr.source_lobe_id,
                "target_lobe_id" => pr.target_lobe_id,
                "confidence"     => pr.confidence,
                "dispatch_count" => pr.dispatch_count
            ) for pr in bs.propagation_history
        ]
    end
    specimen["brainstem"] = brainstem_data

    # ── 14. ATTACHMENTS (RELATIONAL FIRE SYSTEM) ──────────────────────────────
    # GRUG: Serialize the ATTACHMENT_MAP. Each target_id maps to a list of
    # AttachedNode structs (node_id, pattern, signal, base_confidence).
    # base_confidence is the JIT-baked value computed at attach time.
    attachment_list = Dict{String, Any}[]
    lock(ATTACHMENT_LOCK) do
        for (target_id, attachments) in ATTACHMENT_MAP
            for att in attachments
                push!(attachment_list, Dict{String, Any}(
                    "target_id"       => target_id,
                    "node_id"         => att.node_id,
                    "pattern"         => att.pattern,
                    "signal"          => att.signal,
                    "base_confidence" => att.base_confidence
                ))
            end
        end
    end
    specimen["attachments"] = attachment_list


    # ── 15. TRAJECTORY STATE (ActionTonePredictor) ────────────────
    # GRUG: Save the trajectory ring buffer + config knobs.
    # Academic: The trajectory buffer tracks the system's path through
    # action-tone space. Without persistence, Lorenz attractor damping
    # resets on every load — the specimen forgets its behavioral inertia.
    trajectory_data = Dict{String, Any}()
    lock(ActionTonePredictor._trajectory_lock) do
        config = ActionTonePredictor._trajectory_config[]
        trajectory_data["config"] = Dict{String, Any}(
            "buffer_size"         => config.buffer_size,
            "decay_halflife"      => config.decay_halflife,
            "gini_threshold"      => config.gini_threshold,
            "damping_strength"    => config.damping_strength,
            "softmax_temperature" => config.softmax_temperature
        )
        buf_entries = Dict{String, Any}[]
        for entry in ActionTonePredictor._trajectory_buffer
            push!(buf_entries, Dict{String, Any}(
                "action_dist" => Dict(string(k) => v for (k, v) in entry.action_dist),
                "tone_dist"   => Dict(string(k) => v for (k, v) in entry.tone_dist),
                "timestamp"   => entry.timestamp
            ))
        end
        trajectory_data["buffer"] = buf_entries
    end
    specimen["trajectory"] = trajectory_data

    # ── 16. TEMPORAL COHERENCE LEDGER (ImageSDF) ──────────────────
    # GRUG: Save the SDF timing patterns so temporal coherence survives reload.
    # Academic: Without this, the coherence_score for every SDF resets to zero
    # on load, destroying the temporal stability model for image nodes.
    tcl_list = Dict{String, Any}[]
    lock(ImageSDF.TCL_LOCK) do
        for (sdf_id, rec) in ImageSDF.TEMPORAL_COHERENCE_LEDGER
            push!(tcl_list, Dict{String, Any}(
                "sdf_id"          => rec.sdf_id,
                "last_fired"      => rec.last_fired,
                "fire_count"      => rec.fire_count,
                "avg_interval"    => rec.avg_interval,
                "coherence_score" => rec.coherence_score
            ))
        end
    end
    specimen["temporal_coherence"] = tcl_list

    # ── 17. MORPH COOLDOWN MAP (ChatterMode) ─────────────────────
    # GRUG: Save the 24h morph cooldown timestamps so morphed nodes stay on cooldown after reload.
    # Academic: Without persistence, a save/load cycle would reset all cooldowns,
    # allowing nodes to morph again immediately — violating the 24h invariant.
    cooldown_data = Dict{String, Any}()
    lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
        for (node_id, ts) in ChatterMode.MORPH_COOLDOWN_MAP
            cooldown_data[node_id] = ts
        end
    end
    specimen["morph_cooldowns"] = cooldown_data

    # ── METADATA ──────────────────────────────────────────────────
    # GRUG: Version bumped to 2.1 — added trajectory, temporal_coherence, morph_cooldowns.
    # Academic: v2.1 is backward-compatible with v2.0 on load (new keys are optional).
    # —— 18. IMMUNE SYSTEM STATE ————————————————————————————
    # GRUG: Save immune Hopfield memory + ledger so specimen remembers what was safe/funky.
    # Academic: Without this, the immune system resets on every load —
    # losing all learned safe signatures and audit history.
    specimen["immune_system"] = ImmuneSystem.serialize_immune_state()

    # ─── 19. AIML NODE SYSTEM STATE ─────────────────────────────────────────────────────
    # GRUG: Save AIML registry + population caps + cycle counter.
    # Academic: Without this, all AIML executive nodes are lost on reload —
    # the specimen forgets its learned AIML patterns and tribal structure.
    specimen["aiml_system"] = AIMLNodeSystem.serialize_aiml_state()

    specimen["_meta"] = Dict{String, Any}(
        "version"    => "2.4",
        "saved_at"   => time(),
        "format"     => "grugbot420-specimen-v2.4"
    )

    # ── SERIALIZE + COMPRESS ──────────────────────────────────────────────
    # GRUG: Convert to JSON string, then gzip compress to file.
    # Use system gzip via pipeline — no extra packages needed. Grug like simple.
    json_str = JSON.json(specimen, 2)  # pretty-print with indent=2

    try
        proc = open(`gzip -c`, "r+")
        write(proc, json_str)
        close(proc.in)
        compressed = read(proc)
        open(filepath, "w") do io
            write(io, compressed)
        end
    catch e
        error("!!! FATAL: /saveSpecimen failed to write compressed file '$filepath': $e !!!")
    end

    elapsed = round(time() - t_start, digits=2)
    file_size = filesize(filepath)
    json_size = sizeof(json_str)
    ratio = json_size > 0 ? round(100.0 * (1.0 - file_size / json_size), digits=1) : 0.0

    # GRUG: Build the victory scroll
    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(lines, "║            🧊 SPECIMEN SAVED SUCCESSFULLY                    ║")
    push!(lines, "╠══════════════════════════════════════════════════════════════╣")
    push!(lines, "  📁  File             : $filepath")
    push!(lines, "  📦  JSON size        : $(json_size) bytes")
    push!(lines, "  🗜️   Compressed size  : $(file_size) bytes ($(ratio)% smaller)")
    push!(lines, "  ⏱️   Time             : $(elapsed)s")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🌱  Nodes            : $(length(node_list))")
    push!(lines, "  🧠  Lobes            : $(length(lobe_list))")
    push!(lines, "  📋  Lobe tables      : $(length(lobe_table_list))")
    push!(lines, "  ⚡  Hopfield entries  : $(length(hopfield_entries))")
    push!(lines, "  ⚙️   Rules            : $(length(rule_list))")
    push!(lines, "  💬  Messages         : $(length(msg_list))")
    push!(lines, "  🔧  Verb classes     : $(length(get(verb_data, "classes", Dict())))")
    push!(lines, "  🔤  Thesaurus words  : $(length(thesaurus_data))")
    push!(lines, "  🚫  Inhibitions      : $(length(inhib_list))")
    push!(lines, "  🔗  Attachments      : $(length(attachment_list))")
    _traj_buf = get(trajectory_data, "buffer", [])
    push!(lines, "  🔮  Trajectory entries : $(length(_traj_buf))")
    push!(lines, "  🕐  Temporal coherence : $(length(tcl_list))")
    push!(lines, "  ⏳  Morph cooldowns    : $(length(cooldown_data))")
    # GRUG: Show AIML stats if aiml_system was saved
    # GRUG 7.12-FIX: serialize_aiml_state()["registry"] is a
    # Dict{String, Vector{Dict}} where each value IS the list of node dicts
    # (see AIMLNodeSystem.serialize_aiml_state §registry_data[lobe_id] =
    # nodes_list). The previous version tried get(v, "nodes", []) which
    # threw MethodError(get, (<Vector{Dict}>, "nodes", ...)) because `get`
    # on a Vector expects an Int index, not a String. Count directly.
    # NO SILENT FAILURE: if the schema ever regresses to a nested dict
    # shape, length() on a Dict still returns the node count sensibly.
    _aiml_data = get(specimen, "aiml_system", Dict())
    _aiml_registry = get(_aiml_data, "registry", Dict())
    _aiml_total_nodes = isempty(_aiml_registry) ? 0 : sum(length(v) for v in values(_aiml_registry))
    push!(lines, "  🤖  AIML nodes       : $(_aiml_total_nodes)")
    push!(lines, "  👁   Arousal          : $(arousal_data["level"])")
    push!(lines, "╚══════════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end


"""
load_specimen_from_file!(filepath::String)::String

GRUG: Read a gzip-compressed JSON specimen file and RESTORE the ENTIRE cave state.
This is a DESTRUCTIVE operation — current cave state is WIPED and replaced with
the specimen contents. Think of it as brain transplant, not brain addition.

Phase 1: Read + decompress + parse the file
Phase 2: Validate the entire specimen structure
Phase 3: WIPE all current mutable state
Phase 4: RESTORE all state from specimen
Phase 5: Build summary scroll

Returns a multi-line summary string of everything restored.
"""
function load_specimen_from_file!(filepath::String)::String
    if strip(filepath) == ""
        error("!!! FATAL: /loadSpecimen got empty filepath! Grug needs a file to thaw! !!!")
    end

    if !isfile(filepath)
        error("!!! FATAL: /loadSpecimen file not found: '$filepath'! Check path and try again! !!!")
    end

    t_start = time()
    file_size = filesize(filepath)

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 1: READ + DECOMPRESS + PARSE
    # ══════════════════════════════════════════════════════════════════════

    # GRUG: Read compressed file and decompress via pipeline to gunzip.
    # No extra packages needed — just shell out to gunzip. Grug like simple.
    json_str = try
        compressed_bytes = read(filepath)
        proc = open(`gunzip -c`, "r+")
        write(proc, compressed_bytes)
        close(proc.in)
        String(read(proc))
    catch e
        error("!!! FATAL: /loadSpecimen failed to read/decompress '$filepath': $e !!!")
    end

    if strip(json_str) == ""
        error("!!! FATAL: /loadSpecimen decompressed file is empty! Bad specimen jar! !!!")
    end

    specimen = try
        JSON.parse(json_str)
    catch e
        error("!!! FATAL: /loadSpecimen JSON parse failed after decompression: $e !!!")
    end

    if !isa(specimen, Dict)
        error("!!! FATAL: /loadSpecimen expects a JSON object at top level, got $(typeof(specimen))! !!!")
    end

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 2: VALIDATE STRUCTURE
    # GRUG: Check that all sections exist and have correct types.
    # We don't validate every field here — the restore phase handles
    # individual field errors with try/catch. But we catch structural
    # problems early to avoid partial wipes. Grug is paranoid.
    # ══════════════════════════════════════════════════════════════════════

    validation_errors = String[]

    # GRUG: Allowed top-level keys
    allowed_keys = Set(["nodes", "hopfield_cache", "rules", "message_history",
                        "lobes", "node_to_lobe_idx", "lobe_tables",
                        "verb_registry", "thesaurus_seeds", "inhibitions",
                        "arousal", "eye_state", "id_counters", "last_voters", "brainstem", "attachments",
                        "trajectory", "temporal_coherence", "morph_cooldowns", "immune_system", "aiml_system", "_meta"])
    for key in keys(specimen)
        if !(key in allowed_keys)
            push!(validation_errors, "Unknown top-level key '$key'")
        end
    end

    # GRUG: Type checks for critical array sections
    for k in ["nodes", "hopfield_cache", "rules", "message_history", "lobes", "lobe_tables", "inhibitions", "temporal_coherence"]
        if haskey(specimen, k) && !isa(specimen[k], AbstractVector)
            push!(validation_errors, "'$k' must be an array")
        end
    end

    # GRUG: Type checks for critical dict sections
    for k in ["node_to_lobe_idx", "verb_registry", "thesaurus_seeds", "arousal", "eye_state", "id_counters", "brainstem",
             "trajectory", "morph_cooldowns", "immune_system", "aiml_system", "_meta"]
        if haskey(specimen, k) && !isa(specimen[k], Dict)
            push!(validation_errors, "'$k' must be an object")
        end
    end

    # GRUG: Validate nodes have required fields (spot-check first 5)
    if haskey(specimen, "nodes") && isa(specimen["nodes"], AbstractVector)
        for (i, nd) in enumerate(specimen["nodes"])
            i > 5 && break
            if !isa(nd, Dict)
                push!(validation_errors, "nodes[$i]: not a JSON object")
            elseif !haskey(nd, "id") || !haskey(nd, "pattern") || !haskey(nd, "action_packet")
                push!(validation_errors, "nodes[$i]: missing 'id', 'pattern', or 'action_packet'")
            end
        end
    end

    if !isempty(validation_errors)
        err_list = join(["  - $e" for e in validation_errors], "\n")
        error("!!! FATAL: /loadSpecimen validation failed with $(length(validation_errors)) error(s):\n$err_list\n!!! NO CHANGES MADE. Fix the specimen file and try again. !!!")
    end

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 3: WIPE ALL CURRENT STATE
    # GRUG: Clear EVERYTHING. This is a brain transplant. Old brain goes in the bin.
    # Order doesn't matter for wipe — we lock everything and empty it.
    # ══════════════════════════════════════════════════════════════════════

    println("  🧹 Wiping current cave state...")

    # Wipe nodes
    lock(NODE_LOCK) do
        empty!(NODE_MAP)
    end

    # Wipe Hopfield cache
    lock(HOPFIELD_CACHE_LOCK) do
        empty!(HOPFIELD_CACHE)
        empty!(HOPFIELD_HIT_COUNTS)
    end

    # Wipe AIML rules
    empty!(AIML_DROP_TABLE)

    # GRUG: Wipe AIML node tribes. All lobe registrations, populations, cycle state.
    # A brain transplant must clear executive memory too, not just cave nodes.
    AIMLNodeSystem.reset_all!()

    # Wipe message history
    empty!(MESSAGE_HISTORY)

    # Wipe lobes + index
    lock(Lobe.LOBE_LOCK) do
        empty!(Lobe.LOBE_REGISTRY)
        empty!(Lobe.NODE_TO_LOBE_IDX)
    end

    # Wipe lobe tables
    lock(LobeTable.TABLE_REGISTRY_LOCK) do
        empty!(LobeTable.LOBE_TABLE_REGISTRY)
    end

    # Wipe verb registry
    lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
        empty!(SemanticVerbs._VERB_REGISTRY)
        empty!(SemanticVerbs._VERB_TO_CLASS)
        empty!(SemanticVerbs._SYNONYM_MAP)
    end

    # Wipe thesaurus seeds
    lock(Thesaurus.SEED_MAP_LOCK) do
        empty!(Thesaurus.SYNONYM_SEED_MAP)
    end

    # Wipe inhibitions
    lock(InputQueue._NEG_LOCK) do
        empty!(InputQueue._NEG_THESAURUS)
    end

    # Wipe brainstem state
    lock(BrainStem.BRAINSTEM_LOCK) do
        BrainStem.BRAINSTEM_STATE.dispatch_count = 0
        BrainStem.BRAINSTEM_STATE.last_winner_id = ""
        BrainStem.BRAINSTEM_STATE.last_dispatch_t = 0.0
        BrainStem.BRAINSTEM_STATE.is_dispatching = false
        empty!(BrainStem.BRAINSTEM_STATE.propagation_history)
    end

    # Wipe last voter IDs
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
    end

    # Wipe attachments (relational fire system)
    lock(ATTACHMENT_LOCK) do
        empty!(ATTACHMENT_MAP)
    end


    # Wipe trajectory state (ActionTonePredictor)
    # GRUG: Reset the trajectory ring buffer and config back to defaults.
    lock(ActionTonePredictor._trajectory_lock) do
        empty!(ActionTonePredictor._trajectory_buffer)
        ActionTonePredictor._trajectory_config[] = ActionTonePredictor.DEFAULT_TRAJECTORY_CONFIG
    end

    # Wipe temporal coherence ledger (ImageSDF)
    # GRUG: Clear all SDF timing patterns. Fresh start for image coherence.
    lock(ImageSDF.TCL_LOCK) do
        empty!(ImageSDF.TEMPORAL_COHERENCE_LEDGER)
    end

    # Wipe morph cooldown map (ChatterMode)
    # GRUG: Clear all morph cooldowns. Specimen will bring its own.
    lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
        empty!(ChatterMode.MORPH_COOLDOWN_MAP)
    end

    # Wipe immune system state
    # GRUG: Clear all immune memory. Specimen will bring its own.
    ImmuneSystem.reset_immune_state!()

    println("  ✅ Cave wiped clean. Beginning restore...")

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 4: RESTORE ALL STATE FROM SPECIMEN
    # GRUG: Rebuild the cave brick by brick. Order matters here:
    # ID counters -> verb registry -> thesaurus -> lobes -> lobe tables ->
    # nodes -> node_to_lobe_idx -> hopfield cache -> rules -> inhibitions ->
    # messages -> arousal -> brainstem -> attachments -> trajectory ->
    # temporal_coherence -> morph_cooldowns
    # ══════════════════════════════════════════════════════════════════════

    counts = Dict{String,Int}()

    # ── 4.1 ID COUNTERS ──────────────────────────────────────────────────
    if haskey(specimen, "id_counters")
        idc = specimen["id_counters"]
        if haskey(idc, "node_id_counter")
            ID_COUNTER[] = Int(idc["node_id_counter"])
        end
        if haskey(idc, "msg_id_counter")
            MSG_ID_COUNTER[] = Int(idc["msg_id_counter"])
        end
        println("  🔢 ID counters restored (node=$(ID_COUNTER[]), msg=$(MSG_ID_COUNTER[]))")
    end

    # ─── 4.1.5 LAST VOTER IDS ──────────────────────────────────────────────────
    # GRUG: Restore last voter IDs so /wrong works after reload.
    if haskey(specimen, "last_voters") && isa(specimen["last_voters"], AbstractVector)
        lock(LAST_VOTER_LOCK) do
            empty!(LAST_VOTER_IDS)
            for vid in specimen["last_voters"]
                push!(LAST_VOTER_IDS, String(vid))
            end
        end
        println("  🗳  Last voters restored ($(length(LAST_VOTER_IDS)) IDs)")
    end

    # ─── 4.1.6 EYE STATE ────────────────────────────────────────────────────────
    # GRUG: Restore eye tracking state for continuity.
    if haskey(specimen, "eye_state") && isa(specimen["eye_state"], Dict)
        es = specimen["eye_state"]
        lock(EyeSystem.EYE_STATE_LOCK) do
            if haskey(es, "attention_enabled")
                EyeSystem.DEFAULT_EYE_STATE.attention_enabled = Bool(es["attention_enabled"])
            end
            if haskey(es, "blur_enabled")
                EyeSystem.DEFAULT_EYE_STATE.blur_enabled = Bool(es["blur_enabled"])
            end
            if haskey(es, "last_centroid_x")
                EyeSystem.DEFAULT_EYE_STATE.last_centroid_x = Float64(es["last_centroid_x"])
            end
            if haskey(es, "last_centroid_y")
                EyeSystem.DEFAULT_EYE_STATE.last_centroid_y = Float64(es["last_centroid_y"])
            end
            if haskey(es, "last_arousal")
                EyeSystem.DEFAULT_EYE_STATE.last_arousal = Float64(es["last_arousal"])
            end
        end
        println("  👁  Eye state restored")
    end

    # ── 4.2 VERB REGISTRY ────────────────────────────────────────────────
    n_verb_classes = 0
    n_verbs = 0
    n_verb_synonyms = 0
    if haskey(specimen, "verb_registry")
        vr = specimen["verb_registry"]
        lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
            # Restore classes + verbs
            if haskey(vr, "classes") && isa(vr["classes"], Dict)
                for (cls, verbs) in vr["classes"]
                    SemanticVerbs._VERB_REGISTRY[String(cls)] = Set{String}(String.(verbs))
                    n_verb_classes += 1
                    n_verbs += length(verbs)
                end
            end
            # Restore synonyms
            if haskey(vr, "synonyms") && isa(vr["synonyms"], Dict)
                for (alias, canon) in vr["synonyms"]
                    SemanticVerbs._SYNONYM_MAP[String(alias)] = String(canon)
                    n_verb_synonyms += 1
                end
            end
            # Rebuild reverse map (_VERB_TO_CLASS)
            SemanticVerbs._rebuild_verb_to_class!()
        end
        counts["verb_classes"] = n_verb_classes
        counts["verbs"] = n_verbs
        counts["verb_synonyms"] = n_verb_synonyms
        println("  🔧 Verb registry restored ($n_verb_classes classes, $n_verbs verbs, $n_verb_synonyms synonyms)")
    end

    # ── 4.3 THESAURUS SEEDS ──────────────────────────────────────────────
    n_thesaurus = 0
    if haskey(specimen, "thesaurus_seeds") && isa(specimen["thesaurus_seeds"], Dict)
        lock(Thesaurus.SEED_MAP_LOCK) do
            for (word, syns) in specimen["thesaurus_seeds"]
                Thesaurus.SYNONYM_SEED_MAP[String(word)] = Set{String}(String.(syns))
                n_thesaurus += 1
            end
        end
        counts["thesaurus_words"] = n_thesaurus
        println("  🔤 Thesaurus restored ($n_thesaurus words)")
    end

    # ── 4.4 LOBES ────────────────────────────────────────────────────────
    n_lobes = 0
    if haskey(specimen, "lobes") && isa(specimen["lobes"], AbstractVector)
        lock(Lobe.LOBE_LOCK) do
            for ldata in specimen["lobes"]
                try
                    rec = Lobe.LobeRecord(
                        String(ldata["id"]),
                        String(ldata["subject"]),
                        Set{String}(String.(get(ldata, "node_ids", String[]))),
                        Set{String}(String.(get(ldata, "connected_lobe_ids", String[]))),
                        Int(get(ldata, "node_cap", Lobe.LOBE_NODE_CAP)),
                        Int(get(ldata, "fire_count", 0)),
                        Int(get(ldata, "inhibit_count", 0)),
                        Float64(get(ldata, "created_at", time()))
                    )
                    Lobe.LOBE_REGISTRY[rec.id] = rec
                    n_lobes += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore lobe '$(get(ldata, "id", "?"))': $e !!!")
                end
            end
        end
        counts["lobes"] = n_lobes
        println("  🧠 Lobes restored ($n_lobes)")
    end

    # ── 4.5 LOBE TABLES ──────────────────────────────────────────────────
    n_lobe_tables = 0
    if haskey(specimen, "lobe_tables") && isa(specimen["lobe_tables"], AbstractVector)
        lock(LobeTable.TABLE_REGISTRY_LOCK) do
            for ltdata in specimen["lobe_tables"]
                try
                    lid = String(ltdata["lobe_id"])
                    chunks = Dict{String, LobeTable.LobeTableChunk}()
                    if haskey(ltdata, "chunks") && isa(ltdata["chunks"], Dict)
                        for (cname, entries) in ltdata["chunks"]
                            chunk = LobeTable.LobeTableChunk(
                                String(cname),
                                Dict{String, Any}(),
                                ReentrantLock()
                            )
                            if isa(entries, Dict)
                                for (k, v) in entries
                                    if isa(v, Dict) && get(v, "_type", "") == "NodeRef"
                                        chunk.store[String(k)] = LobeTable.NodeRef(
                                            String(v["node_id"]),
                                            String(v["lobe_id"]),
                                            Bool(v["is_active"]),
                                            Float64(get(v, "inserted_at", time()))
                                        )
                                    else
                                        chunk.store[String(k)] = v
                                    end
                                end
                            end
                            chunks[String(cname)] = chunk
                        end
                    end
                    rec = LobeTable.LobeTableRecord(
                        lid,
                        chunks,
                        Float64(get(ltdata, "created_at", time()))
                    )
                    LobeTable.LOBE_TABLE_REGISTRY[lid] = rec
                    n_lobe_tables += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore lobe table '$(get(ltdata, "lobe_id", "?"))': $e !!!")
                end
            end
        end
        counts["lobe_tables"] = n_lobe_tables
        println("  📋 Lobe tables restored ($n_lobe_tables)")
    end

    # ── 4.6 NODES ─────────────────────────────────────────────────────────
    # GRUG: Direct injection into NODE_MAP — bypasses create_node() to preserve
    # original IDs, strengths, neighbors, graves, everything. This is a RESTORE,
    # not a grow. Every field is exactly what it was when /saveSpecimen froze it.
    n_nodes = 0
    if haskey(specimen, "nodes") && isa(specimen["nodes"], AbstractVector)
        lock(NODE_LOCK) do
            for nd in specimen["nodes"]
                try
                    # Rebuild RelationalTriple vector from serialized dicts
                    rel_patterns = RelationalTriple[]
                    if haskey(nd, "relational_patterns") && isa(nd["relational_patterns"], AbstractVector)
                        for rp in nd["relational_patterns"]
                            push!(rel_patterns, RelationalTriple(
                                String(get(rp, "subject", "")),
                                String(get(rp, "relation", "")),
                                String(get(rp, "object", ""))
                            ))
                        end
                    end

                    node = Node(
                        String(nd["id"]),
                        String(nd["pattern"]),
                        Float64.(get(nd, "signal", Float64[])),
                        String(nd["action_packet"]),
                        Dict{String, Any}(string(k) => v for (k,v) in get(nd, "json_data", Dict())),
                        String.(get(nd, "drop_table", String[])),
                        Float64(get(nd, "throttle", 0.5)),
                        rel_patterns,
                        String.(get(nd, "required_relations", String[])),
                        Dict{String, Float64}(string(k) => Float64(v) for (k,v) in get(nd, "relation_weights", Dict())),
                        Float64(get(nd, "strength", 1.0)),
                        Bool(get(nd, "is_image_node", false)),
                        String.(get(nd, "neighbor_ids", String[])),
                        Bool(get(nd, "is_unlinkable", false)),
                        Bool(get(nd, "is_grave", false)),
                        String(get(nd, "grave_reason", "")),
                        Float64.(get(nd, "response_times", Float64[])),
                        Float64(get(nd, "ledger_last_cleared", time())),
                        parse(UInt64, string(get(nd, "hopfield_key", "0"))),
                        # GRUG: Per-cycle transient flags — always reset to defaults on load.
                        # These are runtime scratch state (who fired this cycle, who gained strength);
                        # they have no meaning across a save/load boundary, so we deliberately drop
                        # any persisted value and start the restored node in a clean pre-cycle state.
                        false,   # fired_this_cycle
                        false,   # voted_this_cycle
                        false,   # gained_this_cycle
                        0.0      # strength_delta_this_cycle
                    )
                    NODE_MAP[node.id] = node
                    n_nodes += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore node '$(get(nd, "id", "?"))': $e !!!")
                end
            end
        end
        counts["nodes"] = n_nodes
        println("  🌱 Nodes restored ($n_nodes)")
    end

    # ── 4.7 NODE_TO_LOBE_IDX ─────────────────────────────────────────────
    if haskey(specimen, "node_to_lobe_idx") && isa(specimen["node_to_lobe_idx"], Dict)
        lock(Lobe.LOBE_LOCK) do
            for (nid, lid) in specimen["node_to_lobe_idx"]
                Lobe.NODE_TO_LOBE_IDX[String(nid)] = String(lid)
            end
        end
    end

    # ── 4.8 HOPFIELD CACHE ────────────────────────────────────────────────
    n_hopfield = 0
    if haskey(specimen, "hopfield_cache") && isa(specimen["hopfield_cache"], AbstractVector)
        lock(HOPFIELD_CACHE_LOCK) do
            for hentry in specimen["hopfield_cache"]
                try
                    h = parse(UInt64, String(hentry["hash"]))
                    ids = String.(hentry["node_ids"])
                    hit = Int(get(hentry, "hit_count", 0))
                    HOPFIELD_CACHE[h] = ids
                    HOPFIELD_HIT_COUNTS[h] = hit
                    n_hopfield += 1
                catch e
                    @warn "loadSpecimen: skipping bad Hopfield entry: $e"
                end
            end
        end
        counts["hopfield_entries"] = n_hopfield
        println("  ⚡ Hopfield cache restored ($n_hopfield entries)")
    end

    # ── 4.9 RULES ─────────────────────────────────────────────────────────
    n_rules = 0
    if haskey(specimen, "rules") && isa(specimen["rules"], AbstractVector)
        for rentry in specimen["rules"]
            try
                rtext = String(rentry["text"])
                rprob = Float64(get(rentry, "prob", 1.0))
                push!(AIML_DROP_TABLE, StochasticRule(rtext, rprob))
                n_rules += 1
            catch e
                error("!!! FATAL: /loadSpecimen failed to restore rule: $e !!!")
            end
        end
        counts["rules"] = n_rules
        println("  ⚙️  Rules restored ($n_rules)")
    end

    # ── 4.10 INHIBITIONS ──────────────────────────────────────────────────
    n_inhibitions = 0
    if haskey(specimen, "inhibitions") && isa(specimen["inhibitions"], AbstractVector)
        lock(InputQueue._NEG_LOCK) do
            for ientry in specimen["inhibitions"]
                try
                    entry = InputQueue.NegEntry(
                        String(ientry["word"]),
                        String(get(ientry, "reason", "")),
                        Float64(get(ientry, "added_at", time()))
                    )
                    InputQueue._NEG_THESAURUS[entry.word] = entry
                    n_inhibitions += 1
                catch e
                    @warn "loadSpecimen: skipping bad inhibition entry: $e"
                end
            end
        end
        counts["inhibitions"] = n_inhibitions
        println("  🚫 Inhibitions restored ($n_inhibitions)")
    end

    # ── 4.11 MESSAGE HISTORY ──────────────────────────────────────────────
    n_messages = 0
    if haskey(specimen, "message_history") && isa(specimen["message_history"], AbstractVector)
        for mentry in specimen["message_history"]
            try
                # GRUG v7.12: intensity is persisted per-message in v7.12+.
                # Older specimens lack the key - default to BASELINE so the
                # first pattern-bind refresh scores them from a neutral start.
                # Clamp on load because a malformed file could hand us NaN/Inf
                # and we do not want that silently corrupting the coinflip.
                raw_intensity = Float64(get(mentry, "intensity", CONTEXT_INTENSITY_BASELINE))
                intensity = if isnan(raw_intensity) || isinf(raw_intensity)
                    @warn "loadSpecimen: non-finite intensity on message; resetting to BASELINE."
                    CONTEXT_INTENSITY_BASELINE
                else
                    clamp_intensity(raw_intensity)
                end
                msg = ChatMessage(
                    Int(mentry["id"]),
                    String(mentry["role"]),
                    String(mentry["text"]),
                    Bool(get(mentry, "pinned", false)),
                    intensity
                )
                push!(MESSAGE_HISTORY, msg)
                n_messages += 1
            catch e
                @warn "loadSpecimen: skipping bad message entry: $e"
            end
        end
        counts["messages"] = n_messages
        n_pinned = count(m -> m.pinned, MESSAGE_HISTORY)
        println("  💬 Messages restored ($n_messages total, $n_pinned pinned)")
    end

    # ── 4.12 AROUSAL ──────────────────────────────────────────────────────
    if haskey(specimen, "arousal") && isa(specimen["arousal"], Dict)
        ar = specimen["arousal"]
        lock(EyeSystem.AROUSAL_LOCK) do
            EyeSystem.AROUSAL_STATE.level      = Float64(get(ar, "level", 0.3))
            EyeSystem.AROUSAL_STATE.decay_rate  = Float64(get(ar, "decay_rate", 0.05))
            EyeSystem.AROUSAL_STATE.baseline    = Float64(get(ar, "baseline", 0.3))
        end
        counts["arousal"] = 1
        println("  👁  Arousal restored (level=$(get(ar, "level", 0.3)))")
    end

    # ── 4.13 BRAINSTEM ────────────────────────────────────────────────────
    if haskey(specimen, "brainstem") && isa(specimen["brainstem"], Dict)
        bs = specimen["brainstem"]
        lock(BrainStem.BRAINSTEM_LOCK) do
            BrainStem.BRAINSTEM_STATE.dispatch_count = Int(get(bs, "dispatch_count", 0))
            BrainStem.BRAINSTEM_STATE.last_winner_id = String(get(bs, "last_winner_id", ""))
            BrainStem.BRAINSTEM_STATE.last_dispatch_t = Float64(get(bs, "last_dispatch_t", 0.0))
            if haskey(bs, "propagation_history") && isa(bs["propagation_history"], AbstractVector)
                for pr in bs["propagation_history"]
                    push!(BrainStem.BRAINSTEM_STATE.propagation_history,
                        BrainStem.PropagationRecord(
                            String(get(pr, "source_lobe_id", "")),
                            String(get(pr, "target_lobe_id", "")),
                            Float64(get(pr, "confidence", 0.0)),
                            Int(get(pr, "dispatch_count", 0))
                        )
                    )
                end
            end
        end
        println("  🧬 BrainStem state restored")
    end


    # ── 4.14 ATTACHMENTS (RELATIONAL FIRE SYSTEM) ────────────────────────────
    n_attachments = 0
    if haskey(specimen, "attachments") && isa(specimen["attachments"], AbstractVector)
        lock(ATTACHMENT_LOCK) do
            for aentry in specimen["attachments"]
                try
                    tid  = String(aentry["target_id"])
                    nid  = String(aentry["node_id"])
                    pat  = String(aentry["pattern"])
                    sig  = Float64.(get(aentry, "signal", Float64[]))
                    # GRUG: Re-bake signal if missing from file (backward compat)
                    if isempty(sig)
                        sig = words_to_signal(pat)
                    end
                    # GRUG: Re-bake base_confidence if missing from old specimen (backward compat).
                    # Old specimens didn't store JIT-baked confidence, so we re-compute it.
                    # If the attached node still exists, use its pattern for similarity.
                    # Otherwise, use a sensible default of 0.3 (some voice, not dominant).
                    base_conf = Float64(get(aentry, "base_confidence", -1.0))
                    if base_conf < 0.0
                        # GRUG: Backward compat re-bake — compute JIT confidence now
                        attach_ref = get(NODE_MAP, nid, nothing)
                        if !isnothing(attach_ref) && !isempty(pat) && !startswith(pat, "SDF:")
                            base_conf = _token_overlap_similarity(pat, attach_ref.pattern) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                        elseif !isnothing(attach_ref) && startswith(pat, "SDF:")
                            # GRUG: Image attachment — use SDF signal similarity if possible
                            if !isempty(sig) && !isempty(attach_ref.signal)
                                base_conf = _sdf_signal_similarity(sig, attach_ref.signal) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                            else
                                base_conf = 0.3
                            end
                        else
                            base_conf = 0.3
                        end
                    end
                    att = AttachedNode(nid, pat, sig, base_conf)
                    existing = get(ATTACHMENT_MAP, tid, AttachedNode[])
                    push!(existing, att)
                    ATTACHMENT_MAP[tid] = existing
                    n_attachments += 1
                catch e
                    @warn "loadSpecimen: skipping bad attachment entry: $e"
                end
            end
        end
        counts["attachments"] = n_attachments
        println("  🔗 Attachments restored ($n_attachments)")
    end


    # ── 4.15 TRAJECTORY STATE (ActionTonePredictor) ───────────────
    # GRUG: Restore the trajectory ring buffer and config from specimen.
    # Academic: Backward-compatible — if key is missing (v2.0 specimen),
    # trajectory stays at defaults. No error, no silent corruption.
    n_trajectory = 0
    if haskey(specimen, "trajectory") && isa(specimen["trajectory"], Dict)
        traj = specimen["trajectory"]
        lock(ActionTonePredictor._trajectory_lock) do
            # Restore config if present
            if haskey(traj, "config") && isa(traj["config"], Dict)
                tc = traj["config"]
                try
                    ActionTonePredictor._trajectory_config[] = ActionTonePredictor.TrajectoryConfig(
                        Int(get(tc, "buffer_size", 16)),
                        Float64(get(tc, "decay_halflife", 120.0)),
                        Float64(get(tc, "gini_threshold", 0.72)),
                        Float64(get(tc, "damping_strength", 0.25)),
                        Float64(get(tc, "softmax_temperature", 1.5))
                    )
                catch e
                    @warn "loadSpecimen: bad trajectory config, using defaults: $e"
                    ActionTonePredictor._trajectory_config[] = ActionTonePredictor.DEFAULT_TRAJECTORY_CONFIG
                end
            end
            # Restore buffer entries
            if haskey(traj, "buffer") && isa(traj["buffer"], AbstractVector)
                for bentry in traj["buffer"]
                    try
                        # GRUG: Enum keys are stored as strings — parse them back.
                        # Academic: ActionFamily/ToneFamily are @enum types. We
                        # build safe lookup tables from instances() — no eval(), no injection risk.
                        action_d = Dict{ActionTonePredictor.ActionFamily, Float64}()
                        action_lookup = Dict(string(f) => f for f in instances(ActionTonePredictor.ActionFamily))
                        for (k, v) in bentry["action_dist"]
                            sk = String(k)
                            if !haskey(action_lookup, sk)
                                error("Unknown ActionFamily value: '$sk'")
                            end
                            action_d[action_lookup[sk]] = Float64(v)
                        end
                        tone_d = Dict{ActionTonePredictor.ToneFamily, Float64}()
                        tone_lookup = Dict(string(f) => f for f in instances(ActionTonePredictor.ToneFamily))
                        for (k, v) in bentry["tone_dist"]
                            sk = String(k)
                            if !haskey(tone_lookup, sk)
                                error("Unknown ToneFamily value: '$sk'")
                            end
                            tone_d[tone_lookup[sk]] = Float64(v)
                        end
                        push!(ActionTonePredictor._trajectory_buffer,
                            ActionTonePredictor.TrajectoryEntry(action_d, tone_d, Float64(bentry["timestamp"]))
                        )
                        n_trajectory += 1
                    catch e
                        @warn "loadSpecimen: skipping bad trajectory entry: $e"
                    end
                end
            end
        end
        counts["trajectory_entries"] = n_trajectory
        println("  🔮 Trajectory restored ($n_trajectory entries)")
    end

    # ── 4.16 TEMPORAL COHERENCE LEDGER (ImageSDF) ─────────────────
    # GRUG: Restore SDF timing patterns from specimen.
    # Academic: Backward-compatible — missing key means no temporal coherence
    # history, which is the same as a fresh specimen. No error.
    n_tcl = 0
    if haskey(specimen, "temporal_coherence") && isa(specimen["temporal_coherence"], AbstractVector)
        lock(ImageSDF.TCL_LOCK) do
            for tentry in specimen["temporal_coherence"]
                try
                    sdf_id = String(tentry["sdf_id"])
                    if strip(sdf_id) == ""
                        error("empty sdf_id in temporal coherence entry")
                    end
                    rec = ImageSDF.TemporalCoherenceRecord(
                        sdf_id,
                        Float64(get(tentry, "last_fired", 0.0)),
                        Int(get(tentry, "fire_count", 0)),
                        Float64(get(tentry, "avg_interval", 0.0)),
                        Float64(get(tentry, "coherence_score", 0.0))
                    )
                    ImageSDF.TEMPORAL_COHERENCE_LEDGER[sdf_id] = rec
                    n_tcl += 1
                catch e
                    @warn "loadSpecimen: skipping bad temporal coherence entry: $e"
                end
            end
        end
        counts["temporal_coherence"] = n_tcl
        println("  🕐 Temporal coherence restored ($n_tcl entries)")
    end

    # ── 4.17 MORPH COOLDOWN MAP (ChatterMode) ────────────────────
    # GRUG: Restore the 24h morph cooldown timestamps from specimen.
    # Academic: Backward-compatible — missing key means no active cooldowns,
    # which is correct for v2.0 specimens that never tracked this.
    n_cooldowns = 0
    if haskey(specimen, "morph_cooldowns") && isa(specimen["morph_cooldowns"], Dict)
        lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
            for (node_id, ts) in specimen["morph_cooldowns"]
                try
                    nid = String(node_id)
                    timestamp = Float64(ts)
                    # GRUG: Only restore cooldowns that are still within the 24h window.
                    # Academic: Stale cooldowns (older than MORPH_COOLDOWN_SECONDS) are
                    # silently discarded — they would expire immediately anyway.
                    if (time() - timestamp) < ChatterMode.MORPH_COOLDOWN_SECONDS
                        ChatterMode.MORPH_COOLDOWN_MAP[nid] = timestamp
                        n_cooldowns += 1
                    end
                catch e
                    @warn "loadSpecimen: skipping bad morph cooldown entry: $e"
                end
            end
        end
        counts["morph_cooldowns"] = n_cooldowns
        println("  ⏳ Morph cooldowns restored ($n_cooldowns active)")
    end

    # —— 4.18 IMMUNE SYSTEM STATE ——————————————————————————————
    if haskey(specimen, "immune_system") && isa(specimen["immune_system"], Dict)
        ImmuneSystem.deserialize_immune_state!(specimen["immune_system"])
        n_immune_sigs = lock(ImmuneSystem.IMMUNE_HOPFIELD_LOCK) do
            length(ImmuneSystem.IMMUNE_HOPFIELD)
        end
        n_immune_log = lock(ImmuneSystem.LEDGER_LOCK) do
            length(ImmuneSystem.IMMUNE_LEDGER)
        end
        counts["immune_signatures"] = n_immune_sigs
        counts["immune_ledger"] = n_immune_log
        println("  🛡 Immune system restored ($n_immune_sigs signatures, $n_immune_log ledger entries)")
    end

    # ─── 4.19 AIML NODE SYSTEM STATE ─────────────────────────────────────────────────
    # GRUG: Restore AIML registry + population caps + cycle counter.
    # Academic: Without this, all AIML executive nodes are lost on reload.
    if haskey(specimen, "aiml_system") && isa(specimen["aiml_system"], Dict)
        AIMLNodeSystem.deserialize_aiml_state!(specimen["aiml_system"])
        n_aiml_lobes = length(AIMLNodeSystem.get_registered_lobes())
        registered_lobes = AIMLNodeSystem.get_registered_lobes()
        n_aiml_nodes = isempty(registered_lobes) ? 0 : sum(AIMLNodeSystem.get_population_size(lid) for lid in registered_lobes)
        counts["aiml_lobes"] = n_aiml_lobes
        counts["aiml_nodes"] = n_aiml_nodes
        println("  🤖 AIML system restored ($n_aiml_nodes nodes across $n_aiml_lobes lobes)")
    end


    # ══════════════════════════════════════════════════════════════════════
    # PHASE 5: BUILD SUMMARY SCROLL
    # ══════════════════════════════════════════════════════════════════════

    elapsed = round(time() - t_start, digits=2)
    json_size = sizeof(json_str)
    n_pinned = count(m -> m.pinned, MESSAGE_HISTORY)

    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(lines, "║            🧬 SPECIMEN LOADED SUCCESSFULLY                   ║")
    push!(lines, "╠══════════════════════════════════════════════════════════════╣")
    push!(lines, "  📁  File             : $filepath")
    push!(lines, "  📦  Compressed size  : $(file_size) bytes")
    push!(lines, "  📄  JSON size        : $(json_size) bytes")
    push!(lines, "  ⏱️   Time             : $(elapsed)s")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🌱  Nodes            : $(get(counts, "nodes", 0))")
    push!(lines, "  🧠  Lobes            : $(get(counts, "lobes", 0))")
    push!(lines, "  📋  Lobe tables      : $(get(counts, "lobe_tables", 0))")
    push!(lines, "  ⚡  Hopfield entries  : $(get(counts, "hopfield_entries", 0))")
    push!(lines, "  ⚙️   Rules            : $(get(counts, "rules", 0))")
    push!(lines, "  💬  Messages         : $(get(counts, "messages", 0)) ($n_pinned pinned)")
    push!(lines, "  🔧  Verb classes     : $(get(counts, "verb_classes", 0)) ($(get(counts, "verbs", 0)) verbs)")
    push!(lines, "  🔤  Thesaurus words  : $(get(counts, "thesaurus_words", 0))")
    push!(lines, "  🚫  Inhibitions      : $(get(counts, "inhibitions", 0))")
    push!(lines, "  🔗  Attachments      : $(get(counts, "attachments", 0))")
    push!(lines, "  🤖  AIML nodes       : $(get(counts, "aiml_nodes", 0)) ($(get(counts, "aiml_lobes", 0)) lobes)")
    push!(lines, "  👁   Arousal          : $(EyeSystem.get_arousal())")
    push!(lines, "  🔢  ID counters      : node=$(ID_COUNTER[]), msg=$(MSG_ID_COUNTER[])")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🧹  Previous state   : WIPED (full brain transplant)")
    push!(lines, "╚══════════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end
# ==============================================================================
# CAVE POPULATION & CLI LOOP
# ==============================================================================

"""
_plant_inline_boot_seeds()

Hardcoded minimal boot seeds. Used as a fallback when no default specimen
file is present. Creates the `default` lobe and three foundational nodes
covering greeting, reasoning, and survival/causal-analysis archetypes.
"""
function _plant_inline_boot_seeds()
    println("Growing initial map seeds with Stochastic Emotion Packets & Relational Gating...")

    # BUG-009: Auto-create the `default` lobe at boot. All boot seeds register
    # into it, so they are no longer floaters in the unassigned pool. The lobe
    # subject is intentionally generic so the topicality gate keeps it eligible
    # for almost any conversation.
    Lobe.create_lobe!("default", "general thinking reasoning conversation greeting")
    println("  + lobe `default` created (subject: general thinking reasoning conversation greeting)")

    greet_ctx    = Dict{String, Any}("system_prompt" => "Highly polite greeting protocols active.")
    reason_ctx   = Dict{String, Any}("system_prompt" => "Cold logical analysis engine active.")

    # GRUG: Relation dictionary to guard the gate!
    relational_ctx = Dict{String, Any}(
        "system_prompt"      => "Causal relational analysis active.",
        "required_relations" => ["hits"], # GRUG: Gate requirement! Must hit!
        "relation_weights"   => Dict("hits" => 2.5) # GRUG: Amplify math if hits match!
    )

    # GRUG: Seed nodes use pipe-delimited action packets with inline negatives per action.
    # Format: "action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight"
    boot_id_1 = create_node("hello hi greeting mornin",
        "greet[dont frown, dont insult]^3 | welcome[dont be rude]^2 | smile^1",
        greet_ctx, String[])

    boot_id_2 = create_node("think ponder reason calculate",
        "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^1",
        reason_ctx, String[])

    # GRUG: Node that demands verb "hits". Will hard-reject "rock hits grug" via anti-match!
    boot_id_3 = create_node("grug hits rock and makes fire",
        "analyze[dont panic]^5 | ponder^2",
        relational_ctx, String[])

    # BUG-009: Register all boot seeds into the `default` lobe so they vote with
    # a real lobe context instead of the legacy "unassigned" special case.
    for nid in (boot_id_1, boot_id_2, boot_id_3)
        Lobe.add_node_to_lobe!("default", nid)
    end
    println("  + 3 boot seeds registered into `default` lobe")
end

try
    # ============================================================
    # DEFAULT SPECIMEN AUTO-LOAD (BUG-009 + ship-with-grug)
    # ============================================================
    # If `grug-binary/default.specimen.gz` (or env-overridden path) exists and
    # auto-load is not disabled by `GRUG_NO_AUTOLOAD=1`, restore from it.
    # Otherwise plant a minimal hardcoded boot-seed set so grug can talk on
    # first run with zero setup. The auto-load gives newcomers a 20-node /
    # 7-lobe brain out of the box; the hardcoded fallback guarantees grug
    # never starts empty.
    default_specimen_path = get(ENV, "GRUG_DEFAULT_SPECIMEN",
                                 joinpath(@__DIR__, "..", "grug-binary", "default.specimen.gz"))
    autoload_disabled = get(ENV, "GRUG_NO_AUTOLOAD", "") == "1"

    if !autoload_disabled && isfile(default_specimen_path)
        println("🧠 Default specimen detected at $(default_specimen_path) — auto-loading...")
        try
            summary = load_specimen_from_file!(default_specimen_path)
            println("  ✅ Default specimen restored.")
            # Show abbreviated summary (first 6 lines)
            for ln in Iterators.take(split(summary, '\n'), 6)
                println("    $ln")
            end
            println("  (Set GRUG_NO_AUTOLOAD=1 to skip this on next boot.)")
        catch e
            println("⚠️  Default specimen failed to load: $e")
            println("   Falling back to inline boot seeds.")
            _plant_inline_boot_seeds()
        end
    else
        if autoload_disabled
            println("ℹ️  GRUG_NO_AUTOLOAD=1 — skipping default specimen auto-load.")
        end
        _plant_inline_boot_seeds()
    end
catch e
    println("!!! FATAL: Grug failed to plant initial seeds in cave !!!")
    Base.show_backtrace(stdout, catch_backtrace())
    exit(1)
end

# ==============================================================================
# IDLE BACKGROUND TRACKER (CHATTER + PHAGY)
# ==============================================================================

# GRUG: Track when last user input arrived so idle detector knows when to act.
const LAST_INPUT_TIME = Ref{Float64}(time())

# GRUG: DISABLED - Phagy rules vector and lock for RULE PRUNER automaton.
# Phagy automata should only be used for long-running systems with large-scale
# memory management needs. For specimen testing and development, the overhead
# is unnecessary. Uncomment when running long-term production instances.
#
# Original functionality:
# Rules vector and lock for RULE PRUNER automaton.
# These are the live orchestration rules registered via /addRule.
# PhagyMode.prune_dormant_rules! expects: rules with fire_count, dormancy_strikes, is_dormant fields.
# const PHAGY_RULES_REF  = Ref{Vector}(Vector())
# const PHAGY_RULES_LOCK = ReentrantLock()

"""
maybe_run_idle()

GRUG: Check if cave is idle enough for an idle action (v7.1 — SLOW TIMER).
Uses ChatterMode.should_trigger_idle() which checks the SHARED 120s ±30s timer.
Both chatter and phagy use this SAME timer. One idle event, one action.

POPULATION GATE: Both chatter AND phagy require >= 1000 alive non-image nodes.
New specimens with < 1000 nodes skip ALL idle actions. They need to grow first.

If yes, do a 50/50 COINFLIP:
  - Heads (CHATTER): snapshot NODE_MAP, run gossip session, apply diffs back.
  - Tails (PHAGY):   run one phagy automaton for map maintenance.
"""
function maybe_run_idle()
    # GRUG: Don't start if chatter is already running (single-threaded loop guard)
    status = ChatterMode.get_chatter_status()
    status.is_running && return

    # GRUG: Check idle threshold (v7.1: 120s ±30s, shared timer for both chatter + phagy)
    !ChatterMode.should_trigger_idle(LAST_INPUT_TIME[]) && return

    # GRUG: Count alive non-image nodes for population gate (v7.1).
    # Both chatter AND phagy require >= 1000 nodes. New specimens skip all idle actions.
    alive_count = lock(NODE_LOCK) do
        count(n -> !n.is_grave && !n.is_image_node, values(NODE_MAP))
    end

    if alive_count < ChatterMode.MIN_POPULATION_FOR_CHATTER
        # GRUG: Population too small. No idle actions for young specimens.
        LAST_INPUT_TIME[] = time()
        return
    end

    # GRUG: THE COINFLIP. 50/50 - Chatter or Phagy. No favorites.
    if rand() < 0.5
        # ── HEADS: CHATTER ────────────────────────────────────────────────────

        # GRUG: Snapshot the NODE_MAP for the chatter clones
        snapshot = Tuple{String, String, String, Float64}[]
        lock(NODE_LOCK) do
            for (id, node) in NODE_MAP
                # GRUG: Only snapshot alive, non-image nodes for chatter
                # (Image nodes don't gossip pattern text - their patterns are SDF data)
                !node.is_grave && !node.is_image_node && push!(snapshot, (id, node.pattern, node.action_packet, node.strength))
            end
        end

        if isempty(snapshot)
            println("[IDLE:CHATTER] ⚠  No eligible nodes for chatter (all grave or image). Skipping.")
            LAST_INPUT_TIME[] = time()
            return
        end

        println("[IDLE] 🪙  Coinflip → CHATTER. Starting gossip round ($(length(snapshot)) eligible nodes)...")

        try
            session = ChatterMode.start_chatter_session!(snapshot)
            ChatterMode.apply_chatter_diffs!(session, NODE_MAP, NODE_LOCK)
        catch e
            if e isa ChatterMode.ChatterError
                # GRUG: ChatterErrors are expected (population gate, etc). Log and continue.
                println("[IDLE:CHATTER] ⛔  $(e.msg)")
            else
                println("[IDLE:CHATTER] !!! ERROR during chatter session: $e !!!")
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end

    else
        # ── TAILS: PHAGY ──────────────────────────────────────────────────────
        # GRUG: Phagy fires for mature specimens (1000+ nodes, gated above).
        println("[IDLE] 🪙  Coinflip → PHAGY. Running maintenance automaton...")

        # GRUG: GRAB THE LIVE RULES VECTOR FOR RULE PRUNER
        # GRUG: DISABLED - Phagy automata system has been commented out throughout the codebase.
        # Phagy automata should only be used for long-running systems with large-scale
        # memory management needs. For specimen testing and development, the overhead
        # is unnecessary. Uncomment when running long-term production instances.
        #
        # Original functionality:
        # Phagy automata handle background memory maintenance including:
        # - ORPHAN_PRUNER: Removes unused nodes
        # - STRENGTH_DECAYER: Weakens inactive connections
        # - GRAVE_RECYCLER: Reuses recycled node IDs
        # - DROP_TABLE_COMPACT: Optimizes drop tables
        # - RULE_PRUNER: Removes low-strength rules
        # - MEMORY_FORENSICS: Validates memory integrity
        #
        # rules_snapshot = lock(PHAGY_RULES_LOCK) do
        #     PHAGY_RULES_REF[]
        # end
        #
        # try
        #     PhagyMode.run_phagy!(
        #         NODE_MAP,
        #         NODE_LOCK,
        #         HOPFIELD_CACHE,
        #         HOPFIELD_CACHE_LOCK,
        #         rules_snapshot,
        #         PHAGY_RULES_LOCK;
        #         message_history = MESSAGE_HISTORY,
        #         history_lock    = MESSAGE_HISTORY_LOCK
        #     )
        # catch e
        #     println("[IDLE:PHAGY] !!! ERROR during phagy cycle: $e !!!")
        #     Base.show_backtrace(stdout, catch_backtrace())
        # end
    end

    # GRUG: Reset idle timer after EITHER action so the next event waits a full interval.
    # Without this reset, chatter or phagy would re-trigger immediately next loop tick.
    LAST_INPUT_TIME[] = time()
end

# ==============================================================================
# MAIN CLI LOOP
# ==============================================================================

"""
run_cli()

GRUG: Main REPL loop. Prints boot message, then loops forever reading input.
Dispatches commands (/ prefix) or runs mission scan. Triggers idle chatter/phagy
between inputs via maybe_run_idle(). This is the top-level entry point.
"""
function run_cli()
    print(BOOT_MSG)
    
    while true
        print("\nBrain > ")

        # GRUG: Quick idle check BEFORE reading input.
        # Non-blocking: if no input ready, maybe trigger chatter OR phagy (50/50 coinflip).
        # In standard Julia CLI, readline() blocks. So idle action runs between prompts.
        maybe_run_idle()

        # GRUG 7.12: Hard EOF gate. When stdin is a closed pipe (scripted input
        # / redirected file), readline() returns "" forever and the loop would
        # spin. Check eof(stdin) up-front and exit cleanly. NO SILENT FAILURE:
        # we print a visible shutdown banner so operators can see the REPL
        # terminated on its own, not via a /quit command.
        if eof(stdin)
            println("\n[GRUG] ☁ stdin closed (EOF). Cave goes quiet. Shutting down CLI loop.")
            break
        end

        line = strip(readline())

        line == "" && continue

        # GRUG 7.12: /quit (and /exit alias) — explicit, loud shutdown. Scripted
        # drivers use this as the last command of a seed/conversation file so
        # Julia exits with code 0 and log capture tools see a clean close.
        # NO SILENT FAILURE: always print a shutdown banner before returning.
        if line == "/quit" || line == "/exit"
            println("[GRUG] 👋 /quit received. Cave closes. Goodbye.")
            break
        end

        # GRUG: Update last input time so idle detector resets
        LAST_INPUT_TIME[] = time()

        # GRUG: If chatter is currently running (async future), queue the input.
        # In this single-threaded implementation, chatter runs synchronously between
        # prompts so this is a safeguard for future async upgrades.
        status = ChatterMode.get_chatter_status()
        if status.is_running
            ChatterMode.enqueue_input!(line)
            println("[MAIN] ⏳  Input queued (chatter active). Will process after chatter ends.")
            continue
        end

        # GRUG: Drain any queued inputs from previous chatter round before processing new one
        ChatterMode.process_chatter_queue!(process_mission)
        
        try
            # GRUG: Parse all known commands via regex
            m_mission     = match(r"^/mission\s+(.+)"s,  line)
            # GRUG: /brainstorm — process mission under heavier scoped jitter.
            # Same capture shape as /mission (one text blob) because the body
            # is fed straight into process_mission; the only difference is the
            # with_brainstorm_jitter scope wrapper around the call.
            m_brainstorm  = match(r"^/brainstorm\s+(.+)"s, line)
            m_wrong       = match(r"^/wrong\s*$",         line)
            # GRUG: AIML node tribe feedback commands
            m_right       = match(r"^/right\s*$",          line)
            m_aimlright   = match(r"^/aimlRight\s*$",     line)
            m_aimlwrong   = match(r"^/aimlWrong\s*$",     line)
            # GRUG: AIML management commands (status, list, add, remove, cycle, phagy)
            m_aimlstatus  = match(r"^/aimlStatus\s*$",    line)
            m_aimllist    = match(r"^/aimlList\s+(\S+)\s*$", line)
            m_aimladd     = match(r"^/aimlAdd\s+(\S+)\s+(\S+)\s+(.+)$", line)
            m_aimlremove  = match(r"^/aimlRemove\s+(\S+)\s+(\S+)\s*$", line)
            m_aimlcycle   = match(r"^/aimlCycle\s*$",     line)
            m_aimlphagy   = match(r"^/aimlPhagy\s*$",     line)
            m_explicit    = match(r"^/explicit\s+([a-zA-Z0-9_]+)\s+\[(.+?)\]\s+(.+)", line)
            m_grow        = match(r"^/grow\s+(\S+)\s+(.+)"s,      line)
            m_rule        = match(r"^/addRule\s+(.+)"s,   line)
            m_pin         = match(r"^/pin\s+(.+)"s,       line)
            m_nodes       = match(r"^/nodes\s*$",          line)
            m_status      = match(r"^/status\s*$",         line)
            m_arousal     = match(r"^/arousal\s+([0-9.]+)\s*$", line)
            # GRUG: Semantic verb/synonym system commands
            m_addverb     = match(r"^/addVerb\s+(\S+)\s+(\S+)\s*$",        line)
            m_addrelclass = match(r"^/addRelationClass\s+(\S+)\s*$",        line)
            m_addsynonym  = match(r"^/addSynonym\s+(\S+)\s+(\S+)\s*$",     line)
            m_listverbs   = match(r"^/listVerbs\s*$",                        line)
            # GRUG: Lobe management commands
            m_newlobe     = match(r"^/newLobe\s+(\S+)\s+(.+)$",               line)
            m_connectlobes= match(r"^/connectLobes\s+(\S+)\s+(\S+)\s*$",    line)
            m_lobegrow    = match(r"^/lobeGrow\s+(\S+)\s+(.+)$"s,             line)
            m_lobes        = match(r"^/lobes\s*$",                                      line)
            m_tablestatus  = match(r"^/tableStatus\s+(\S+)\s*$",                        line)
            m_tablematch   = match(r"^/tableMatch\s+(\S+)\s+(\S+)\s+(.+)$",            line)
            # GRUG: Thesaurus dimensional similarity command
            m_thesaurus    = match(r"^/thesaurus\s+(.+)\|(.+)$",                       line)
            # GRUG: NegativeThesaurus inhibition commands
            m_neginhibit   = match(r"^/negativeThesaurus\s+add\s+(.+?)(?:\s+--reason\s+(.+))?$", line)
            m_negremove    = match(r"^/negativeThesaurus\s+remove\s+(\S+)\s*$",         line)
            m_neglist      = match(r"^/negativeThesaurus\s+list\s*$",                   line)
            m_negcheck     = match(r"^/negativeThesaurus\s+check\s+(.+)$",              line)
            m_negflush     = match(r"^/negativeThesaurus\s+flush\s*$",                  line)
            # GRUG: Help command — show all commands
            m_loadspecimen = match(r"^/loadSpecimen\s+(\S+)\s*$",                          line)
            m_savespecimen = match(r"^/saveSpecimen\s+(\S+)\s*$",                          line)
            # GRUG: Admin commands (password protected)
            m_login        = match(r"^/login\s+(.+)$",                                     line)
            m_logout       = match(r"^/logout\s*$",                                        line)
            m_writesave    = match(r"^/writeSave\s+(\S+)\s+(.+)$"s,                        line)
            # GRUG: Relational fire system commands (node attachment)
            m_nodeattach   = match(r"^/nodeAttach\s+(.+)"s,                              line)
            m_nodedetach   = match(r"^/nodeDetach\s+(\S+)\s+(\S+)\s*$",                  line)
            m_imgnodeattach = match(r"^/imgnodeAttach\s+(.+)"s,                          line)
            m_imgnodedetach = match(r"^/imgnodeDetach\s+(\S+)\s+(\S+)\s*$",              line)
            m_attachments  = match(r"^/attachments\s*$",                                 line)
            m_help         = match(r"^/help\s*$",                                       line)
            
            if !isnothing(m_help)
                # GRUG: /help - show all available CLI commands. Cave painting instruction scroll!
                print(HELP_MSG)

            elseif !isnothing(m_mission)
                # GRUG: /mission - main input command. Handles text AND image binary.
                mission_text = String(m_mission.captures[1])
                process_mission(mission_text)

            elseif !isnothing(m_brainstorm)
                # GRUG: /brainstorm <text> - process one mission under heavy scoped
                # jitter to escape local minima. Temporarily raises the value-jitter
                # ratio (0.03 -> JITTER_BRAINSTORM_RATIO = 0.08) and the
                # coin-threshold ratio (0.01 -> JITTER_BRAINSTORM_COIN_RATIO = 0.05)
                # for the duration of this one call, then snaps back on exit
                # (including exceptional exits). See RelationalJitter.jl §brainstorm.
                mission_text = String(m_brainstorm.captures[1])

                # GRUG: Match /mission's hard empty-input rule. process_mission
                # throws on empty text anyway, but we want the scope wrapper to
                # not enter at all on bad input — keeps the restored state check
                # trivially correct on the error path.
                if isempty(strip(mission_text))
                    println("⚠  /brainstorm: empty prompt; refusing to enter brainstorm scope.")
                else
                    # GRUG: Refuse nested brainstorm at the CLI level too so the
                    # operator sees a friendlier message than the raw JitterScopeError
                    # that would come up from inside the module. We still let the
                    # module throw if a programmatic caller somehow gets past this.
                    if RelationalJitter.is_brainstorm_active()
                        println("⚠  /brainstorm: another brainstorm scope is already active; refusing to nest.")
                    else
                        println("🎲 /brainstorm: entering heavy-jitter scope (ratio=$(RelationalJitter.JITTER_BRAINSTORM_RATIO), coin_ratio=$(RelationalJitter.JITTER_BRAINSTORM_COIN_RATIO)) for one mission.")
                        # GRUG: Scope wrapper restores ratios on every exit path.
                        # Errors inside process_mission propagate out; the try/finally
                        # inside with_brainstorm_jitter guarantees state is restored
                        # before the throw bubbles up to the outer CLI try-block.
                        RelationalJitter.with_brainstorm_jitter() do
                            process_mission(mission_text)
                        end
                        println("🎲 /brainstorm: scope closed; jitter ratios snapped back to defaults.")
                    end
                end

            elseif !isnothing(m_wrong)
                # GRUG: /wrong - user says last response was wrong.
                # CRITICAL: Only nodes that actually contributed (fired) get penalized, not all voters.
                # Nodes that hit 0 become grave (negative reinforcement markers).
                contributor_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_CONTRIBUTOR_IDS)
                end

                if isempty(contributor_ids)
                    println("⚠  /wrong: No previous contributors to penalize. Did you run /mission first?")
                else
                    apply_wrong_feedback!(contributor_ids)
                    println("❌  /wrong applied. $(length(contributor_ids)) contributor(s) penalized via coinflip.")
                end

                # GRUG v7.12: Context-intensity feedback.
                # The message-history entries that were coinflipped INTO the
                # last AIML payload get a negative nudge. They were part of
                # the context that produced the "wrong" answer, so their
                # intensity should sag → lower chance of re-selection next
                # cycle. Wrapped: never let a bad last-selected set break
                # the feedback path.
                try
                    ctx_hit = apply_last_selected_feedback!(CONTEXT_FEEDBACK_WRONG_DELTA)
                    if ctx_hit > 0
                        println("   ↳ context intensity nudged down on $ctx_hit message(s) used last cycle.")
                    end
                catch e
                    @error "[MAIN] /wrong context-intensity feedback FAILED: $e"
                end

elseif !isnothing(m_right)
                # GRUG: /right - user says last response was good.
                # CRITICAL: Only nodes that actually contributed (fired) get secondary reinforcement.
                # Contributors that didn't already gain strength get a 50% coinflip chance.
                contributor_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_CONTRIBUTOR_IDS)
                end

                if isempty(contributor_ids)
                    println("⚠  /right: No previous contributors to reward. Did you run /mission first?")
                else
                    result = apply_right_feedback!(contributor_ids)
                    println("✅ /right applied. $(length(contributor_ids)) contributor(s) processed: $(length(result["rewarded"])) rewarded, $(length(result["skipped_double_reward"])) skipped (already gained), $(length(result["coinflip_missed"])) missed coinflip.")
                end

                # GRUG v7.12: Context-intensity feedback (positive).
                # Messages coinflipped INTO the last AIML payload get a
                # positive intensity bump. They helped produce the "right"
                # answer, so they should be more likely to be reselected
                # next cycle. Wrapped: feedback failure never propagates.
                try
                    ctx_hit = apply_last_selected_feedback!(CONTEXT_FEEDBACK_RIGHT_DELTA)
                    if ctx_hit > 0
                        println("   ↳ context intensity nudged up on $ctx_hit message(s) used last cycle.")
                    end
                catch e
                    @error "[MAIN] /right context-intensity feedback FAILED: $e"
                end

            elseif !isnothing(m_aimlright)
                # GRUG: /aimlRight - user says AIML executive layer did good this cycle.
                # Rewards AIML nodes that contributed (fired), BUT skips any that already gained
                # strength from use in the same cycle (no double snack rule).
                result = AIMLNodeSystem.apply_aiml_right!()
                if result["total_contributors"] == 0
                    println("⚠  /aimlRight: No AIML nodes voted this cycle. Did you run /mission first?")
                else
                    println("✅  /aimlRight applied. $(length(result["rewarded"])) rewarded, $(length(result["skipped_double_reward"])) skipped (already gained this cycle).")
                end

            elseif !isnothing(m_aimlwrong)
                # GRUG: /aimlWrong - user says AIML executive layer did bad this cycle.
                # Penalizes AIML nodes that contributed (fired) via 50/50 coinflip. Nodes that already gained
                # strength this cycle get EXTRA penalty so they end up net-negative — not
                # just back at baseline. Fake punishment is not punishment. Grug rules.
                result = AIMLNodeSystem.apply_aiml_wrong!()
                if result["total_contributors"] == 0
                    println("⚠  /aimlWrong: No AIML nodes voted this cycle. Did you run /mission first?")
                else
                    newly_graved = length(result["newly_graved"])
                    println("❌  /aimlWrong applied. $(length(result["penalized"])) penalized, $(length(result["spared"])) spared by coinflip, $newly_graved newly graved.")
                end

            elseif !isnothing(m_aimlstatus)
                # GRUG: /aimlStatus - show AIML tribe status across all lobes.
                # GRUG: Gives overview of population, caps, and grave count.
                # GRUG 7.12-FIX: get_aiml_status_summary() returns a preformatted
                # String (see AIMLNodeSystem.jl §get_aiml_status_summary). The
                # previous version indexed it as a Dict which threw
                # MethodError(getindex, (<String>, "total_lobes"), ...) for every
                # /aimlStatus call. NO SILENT FAILURE: we now print the string
                # directly inside the status banner.
                summary = AIMLNodeSystem.get_aiml_status_summary()
                println("\n╔════════════════════════════════════════════════════════════╗")
                println("║                    🤖 AIML TRIBE STATUS                      ║")
                println("╠════════════════════════════════════════════════════════════╣")
                println(summary)
                println("╚════════════════════════════════════════════════════════════╝")

            elseif !isnothing(m_aimllist)
                # GRUG: /aimlList <lobe_id> - list all AIML nodes in a specific lobe.
                # GRUG: Shows node IDs, strengths, and grave status.
                lobe_id = m_aimllist.captures[1]
                nodes = AIMLNodeSystem.list_aiml_nodes(String(lobe_id))
                if isempty(nodes)
                    println("⚠  /aimlList: No AIML nodes found in lobe '$lobe_id'. Is it registered?")
                else
                    println("\n╔══════════════════════════════════════════════════════════════╗")
                    println("║           🤖 AIML NODES IN LOBE: $lobe_id")
                    println("╠══════════════════════════════════════════════════════════════╣")
                    for node in nodes
                        grave_marker = node.is_grave ? "💀 GRAVE" : "✅ ALIVE"
                        println("  📍 $(node.id)")
                        println("     Strength: $(round(node.strength, digits=2)) $grave_marker")
                        if node.is_grave
                            println("     Reason: $(node.grave_reason)")
                        end
                        println("     Template: $(node.template[1:min(50, length(node.template))])...")
                    end
                    println("╚══════════════════════════════════════════════════════════════╝")
                end

            elseif !isnothing(m_aimladd)
                # GRUG: /aimlAdd <lobe_id> <node_id> <template> - add new AIML node.
                # GRUG: Creates a new AIML executive node in the specified lobe.
                # GRUG: Will error if lobe not registered or population cap exceeded.
                lobe_id = String(m_aimladd.captures[1])
                node_id = String(m_aimladd.captures[2])
                template = String(m_aimladd.captures[3])
                try
                    node = AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template)
                    println("✅  /aimlAdd: Created AIML node '$node_id' in lobe '$lobe_id' with strength $(node.strength)")
                catch e
                    if e isa AIMLNodeSystem.AIMLNodeError
                        println("❌  /aimlAdd failed: $(e.message) [$(e.context)]")
                    else
                        println("❌  /aimlAdd failed: $e")
                    end
                end

            elseif !isnothing(m_aimlremove)
                # GRUG: /aimlRemove <lobe_id> <node_id> - remove AIML node from lobe.
                # GRUG: Permanently deletes the node. No recovery. Grug not joke.
                lobe_id = String(m_aimlremove.captures[1])
                node_id = String(m_aimlremove.captures[2])
                if AIMLNodeSystem.has_aiml_node(lobe_id, node_id)
                    AIMLNodeSystem.remove_aiml_node!(lobe_id, node_id)
                    println("✅  /aimlRemove: Removed AIML node '$node_id' from lobe '$lobe_id'")
                else
                    println("⚠  /aimlRemove: Node '$node_id' not found in lobe '$lobe_id'")
                end

            elseif !isnothing(m_aimlcycle)
                # GRUG: /aimlCycle - show current cycle info for AIML system.
                # GRUG: Displays cycle counter and explains cycle-based mechanics.
                cycle = AIMLNodeSystem.current_cycle()
                println("\n╔══════════════════════════════════════════════════════════════╗")
                println("║                    🔄 AIML CYCLE INFO                         ║")
                println("╠══════════════════════════════════════════════════════════════╣")
                println("  Current Cycle    : $cycle")
                println("  ─────────────────────────────────────────────────────────────")
                println("  Cycle Mechanics:")
                println("  • /aimlRight rewards nodes that voted this cycle")
                println("  • /aimlWrong penalizes nodes that voted this cycle")
                println("  • Nodes that gained strength are skipped from double reward")
                println("  • Nodes that gained get EXTRA penalty on /aimlWrong")
                println("  • Cycle counter increments with /mission calls")
                println("╚══════════════════════════════════════════════════════════════╝")

            elseif !isnothing(m_aimlphagy)
                # GRUG: /aimlPhagy - run phagy sweep on AIML graves.
                # GRUG: Removes grave nodes from registry (cleanup operation).
                # GRUG: Returns count of removed graves. Grug like clean cave.
                removed_count = AIMLNodeSystem.aiml_phagy_sweep!()
                if removed_count > 0
                    println("🧹  /aimlPhagy: Cleaned up $removed_count grave node(s) from AIML registry")
                else
                    println("✨  /aimlPhagy: No graves to clean. AIML registry already pristine!")
                end

            elseif !isnothing(m_explicit)
                cmd, id, mission_text = m_explicit.captures
                add_message_to_history!("User", mission_text, false)
                
                println("--> Grug forcing command override for [$id]...")
                override_vote = cast_explicit_vote(String(cmd), String(id))
                
                output = ephemeral_aiml_orchestrator(String(mission_text), [override_vote])
                println("\n🤖 AIML [Targeted Override]:\n$output")
                # GRUG v7.14: Same digest policy as run_mission — store a
                # compact one-liner, not the full scaffold, to stop
                # Fresh Memory recursion.
                digest = try
                    "Explicit \"$(mission_text)\" → primary=$(override_vote.action) node=$(override_vote.node_id)"
                catch e
                    @warn "[MAIN v7.14] Failed to build explicit-override digest ($e); storing mission text only"
                    "Explicit \"$(mission_text)\""
                end
                add_message_to_history!("System", digest, false)
                
            elseif !isnothing(m_grow)
                # GRUG QoL-2025 BUG-008: /grow <lobe_id> <json_packet>
                # Unified single-command growth path. Every node has a lobe
                # home — no more "unassigned pool" mystery.
                #
                # Accepts BOTH packet shapes:
                #   /grow lobeid {"pattern":"...", "action_packet":"...", "data":{...}}
                #   /grow lobeid {"nodes":[ {...}, {...} ]}
                #
                # `<lobe_id>` may be the literal `-` (dash) to mean "no lobe,
                # legacy unassigned pool". Useful for boot seeds and tests.
                target_lobe_raw = String(m_grow.captures[1])
                json_text       = String(m_grow.captures[2])
                add_message_to_history!("System", "/grow $target_lobe_raw [JSON MAP PACKET]", false)

                # GRUG: IMMUNE SYSTEM GATE — scan grow input before touching anything!
                # /grow is a CRITICAL command (modifies node population). Full immune scan.
                immune_passed = immune_gate("/grow", json_text; is_critical=true)

                if immune_passed
                    target_lobe = (target_lobe_raw == "-") ? nothing : target_lobe_raw

                    # GRUG: If a real lobe was named, it must exist.
                    if !isnothing(target_lobe) && !haskey(Lobe.LOBE_REGISTRY, target_lobe)
                        println("⚠  /grow: lobe '$target_lobe' does not exist. Use /newLobe first, or pass `-` for the unassigned pool.")
                    elseif !isnothing(target_lobe) && Lobe.lobe_is_full(target_lobe)
                        println("!!! LOBE FULL: Lobe '$target_lobe' has reached its node cap. Cannot grow more nodes! Use /newLobe to add a new lobe. !!!")
                    else
                        println("--> Grug unpacking JSON node seeds for lobe '$(isnothing(target_lobe) ? "-" : target_lobe)'...")

                        # GRUG: Check if the grow packet contains image binary data.
                        # If pattern field has image binary, flag it as image node automatically.
                        is_img, img_sig = maybe_convert_image_input(json_text)
                        if is_img
                            println("[GROW] 🖼  Image binary detected in /grow packet. Image node path active.")
                        end

                        try
                            new_ids = grow_nodes_from_packet(json_text; target_lobe=target_lobe)
                            success_msg = "🌱 Tribe expanded! Grug planted $(length(new_ids)) new nodes into lobe '$(isnothing(target_lobe) ? "-" : target_lobe)': [$(join(new_ids, ", "))]"
                            println(success_msg)
                            add_message_to_history!("System", success_msg, false)
                        catch e
                            println("!!! ERROR in /grow: $e !!!")
                        end
                    end
                end

            elseif !isnothing(m_rule)
                # GRUG: /addRule - add a stochastic orchestration rule.
                # Optional [prob=X.XX] suffix sets fire probability (default 1.0).
                rule_text = String(m_rule.captures[1])
                # GRUG: IMMUNE GATE — rules are stored structure!
                if !immune_gate("/addRule", rule_text; is_critical=false)
                    println("⛔ /addRule blocked by immune system.")
                else
                    println("⚙️ ", add_orchestration_rule!(rule_text))
                end

            elseif !isnothing(m_pin)
                pin_text = String(m_pin.captures[1])
                # GRUG: IMMUNE GATE — pinned memory is stored structure!
                if !immune_gate("/pin", pin_text; is_critical=false)
                    println("⛔ /pin blocked by immune system.")
                else
                    add_message_to_history!("User_Pinned", pin_text, true)
                    println("📌 Grug pinned text to Memory Wall!")
                end

            elseif !isnothing(m_nodes)
                # GRUG: /nodes - show full node map status (strength, neighbors, graves, etc.)
                println(get_node_status_summary())
                # GRUG: Also show attachment map if any attachments exist
                att_summary = get_attachment_summary()
                if !contains(att_summary, "EMPTY")
                    println("\n$att_summary")
                end

            elseif !isnothing(m_status)
                # GRUG: /status - comprehensive system health snapshot.
                # Shows: engine, chatter, lobes, brainstem, thesaurus gate, memory estimate.
                cs  = ChatterMode.get_chatter_status()
                bs  = BrainStem.get_brainstem_status()
                lobe_ids_now = Lobe.get_lobe_ids()
                total_lobe_nodes = sum(Lobe.get_lobe_node_count(lid) for lid in lobe_ids_now; init=0)

                # GRUG: Rough memory estimate. Each node ~= 1KB (pattern + signal + metadata).
                # Hopfield cache ~= 200 bytes per entry. Message history ~= 500 bytes per msg.
                est_node_mem_kb    = length(NODE_MAP) * 1
                est_hopfield_mem_b = length(HOPFIELD_CACHE) * 200
                est_history_mem_b  = length(MESSAGE_HISTORY) * 500
                est_total_kb       = est_node_mem_kb + div(est_hopfield_mem_b + est_history_mem_b, 1024)

                # GRUG: Find top-firing lobe (most wins)
                top_lobe = isempty(lobe_ids_now) ? "none" : begin
                    best_lid = lobe_ids_now[1]
                    best_fc  = 0
                    for lid in lobe_ids_now
                        rec = Lobe.get_lobe(lid)
                        if rec.fire_count > best_fc
                            best_fc  = rec.fire_count
                            best_lid = lid
                        end
                    end
                    "$(best_lid) ($(best_fc) fires)"
                end

                println("╔══════════════════════════════════════════════════╗")
                println("║              GRUGBOT SYSTEM STATUS               ║")
                println("╠══════════════════════════════════════════════════╣")
                println("║  ENGINE                                          ║")
                println("  Nodes in cave   : $(length(NODE_MAP))")
                println("  Hopfield cache  : $(length(HOPFIELD_CACHE)) entries")
                println("  Memory messages : $(length(MESSAGE_HISTORY))")
                println("  Est. memory use : ~$(est_total_kb) KB")
                println("  Trajectory buf  : $(length(ActionTonePredictor._trajectory_buffer)) entries")
                println("  Temporal coher  : $(length(ImageSDF.TEMPORAL_COHERENCE_LEDGER)) entries")
                println("  Morph cooldowns : $(length(ChatterMode.MORPH_COOLDOWN_MAP)) active")
                println("  Current arousal : $(round(EyeSystem.get_arousal(), digits=3))")
                println("  Last input ago  : $(round(time() - LAST_INPUT_TIME[], digits=1))s")
                println("║  LOBES                                           ║")
                println("  Lobes registered: $(length(lobe_ids_now))")
                println("  Nodes in lobes  : $(total_lobe_nodes)")
                println("  Top lobe (fires): $(top_lobe)")
                println("║  BRAINSTEM                                       ║")
                println("  Dispatches run  : $(bs["dispatch_count"])")
                println("  Last winner     : $(isempty(bs["last_winner_id"]) ? "none" : bs["last_winner_id"])")
                println("  Propagations    : $(bs["propagation_events"])")
                println("  Is dispatching  : $(bs["is_dispatching"])")
                println("║  CHATTER                                         ║")
                println("  Chatter running : $(cs.is_running)")
                println("  Input queue     : $(cs.queue_depth) pending")
                println("  Sessions run    : $(cs.sessions_run)")
                println("║  AIML NODE TRIBES                                ║")
                println(AIMLNodeSystem.get_aiml_status_summary())
                println("╚══════════════════════════════════════════════════╝")

            elseif !isnothing(m_arousal)
                # GRUG: /arousal - manually set eye system arousal level [0.0, 1.0]
                arousal_val = tryparse(Float64, m_arousal.captures[1])
                if isnothing(arousal_val)
                    error("!!! FATAL: /arousal value is not a valid float! !!!")
                end
                EyeSystem.set_arousal!(arousal_val)
                println("👁  Arousal set to $(round(arousal_val, digits=3)). Eye system updated.")

            elseif !isnothing(m_addverb)
                # GRUG: /addVerb <verb> <class> - add a new verb to a relation class at runtime.
                # BUG-005: Accept either order (verb first OR class first). The
                # registered class is detectable, the verb is whatever's left.
                # Example: /addVerb triggers causal   AND   /addVerb causal triggers
                arg1 = String(m_addverb.captures[1])
                arg2 = String(m_addverb.captures[2])
                known_classes = SemanticVerbs.get_relation_classes()
                arg1_is_class = arg1 in known_classes
                arg2_is_class = arg2 in known_classes
                if arg1_is_class && !arg2_is_class
                    verb_class, verb_word = arg1, arg2  # class-first order
                elseif arg2_is_class && !arg1_is_class
                    verb_word, verb_class = arg1, arg2  # verb-first (canonical)
                elseif arg1_is_class && arg2_is_class
                    # Both args are registered classes — ambiguous. Default to
                    # canonical order and warn the user.
                    verb_word, verb_class = arg1, arg2
                    println("⚠️  /addVerb: both '$(arg1)' and '$(arg2)' are registered classes. " *
                            "Defaulting to verb='$(verb_word)' class='$(verb_class)'. " *
                            "Reorder explicitly to disambiguate.")
                else
                    # Neither arg is a registered class — use canonical order
                    # and warn that the class is unknown.
                    verb_word, verb_class = arg1, arg2
                    known_list = join(known_classes, ", ")
                    println("⚠️  /addVerb: class '$(verb_class)' is not registered. " *
                            "Run /addRelationClass $(verb_class) first, " *
                            "or check spelling. Known classes: $(known_list)")
                end
                # GRUG: IMMUNE GATE — verb registry is stored structure!
                if !immune_gate("/addVerb", verb_word * " " * verb_class; is_critical=false)
                    println("⛔ /addVerb blocked by immune system.")
                else
                    SemanticVerbs.add_verb!(verb_word, verb_class)
                    println("🔧 Verb '$(verb_word)' added to class '$(verb_class)'. Active immediately.")
                end

            elseif !isnothing(m_addrelclass)
                # GRUG: /addRelationClass <name> - create a new verb class bucket.
                # After this, user can /addVerb <word> <name> to populate it.
                # Example: /addRelationClass epistemic
                class_name = String(m_addrelclass.captures[1])
                # GRUG: IMMUNE GATE — relation class registry is stored structure!
                if !immune_gate("/addRelationClass", class_name; is_critical=false)
                    println("⛔ /addRelationClass blocked by immune system.")
                else
                    SemanticVerbs.add_relation_class!(class_name)
                    println("🗂  Relation class '$(class_name)' created. Use /addVerb to populate.")
                end

            elseif !isnothing(m_addsynonym)
                # GRUG: /addSynonym <canonical> <alias> - register a synonym normalization.
                # From now on, <alias> in user input is treated as <canonical> before triple extraction.
                # Canonical verb must already exist in a relation class!
                # Example: /addSynonym causes triggers
                canonical_verb = String(m_addsynonym.captures[1])
                alias_verb     = String(m_addsynonym.captures[2])
                # GRUG: IMMUNE GATE — synonym map is stored structure!
                if !immune_gate("/addSynonym", canonical_verb * " " * alias_verb; is_critical=false)
                    println("⛔ /addSynonym blocked by immune system.")
                else
                    SemanticVerbs.add_synonym!(canonical_verb, alias_verb)
                    println("📖 Synonym registered: '$(alias_verb)' → '$(canonical_verb)'. Normalization active.")
                end

            elseif !isnothing(m_listverbs)
                # GRUG: /listVerbs - show all registered verb classes and their verbs + synonyms.
                classes   = SemanticVerbs.get_relation_classes()
                synonyms  = SemanticVerbs.get_synonym_map()
                println("=== SEMANTIC VERB REGISTRY ===")
                for cls in classes
                    verbs = SemanticVerbs.get_verbs_in_class(cls)
                    println("  [$(cls)]: $(join(sort(collect(verbs)), ", "))")
                end
                if !isempty(synonyms)
                    println("  --- Synonyms ---")
                    for (alias, canon) in sort(collect(synonyms))
                        println("    $(alias) → $(canon)")
                    end
                else
                    println("  (no synonyms registered)")
                end

            elseif !isnothing(m_newlobe)
                # GRUG: /newLobe <id> <subject> - create a new subject partition.
                # Example: /newLobe language "natural language processing"
                lobe_id_new  = String(m_newlobe.captures[1])
                lobe_subject = String(strip(m_newlobe.captures[2]))
                # GRUG QoL-2025: Warn if subject contains `_` or `-`. The topicality
                # gate normalizes these to spaces (see engine.jl _compute_lobe_topicality)
                # but the user probably MEANT to type spaces. Loud warning beats silent
                # surprise. Don't reject — engine handles it — just inform.
                if occursin('_', lobe_subject) || occursin('-', lobe_subject)
                    println("⚠  /newLobe: subject contains '_' or '-'. These are normalized to spaces during topicality matching, but you probably wanted plain space-separated keywords. Consider: '/newLobe $lobe_id_new $(replace(lobe_subject, '_' => ' ', '-' => ' '))'")
                end
                # GRUG: IMMUNE GATE — lobe creation is stored structure!
                if !immune_gate("/newLobe", lobe_id_new * " " * lobe_subject; is_critical=false)
                    println("⛔ /newLobe blocked by immune system.")
                else
                    Lobe.create_lobe!(lobe_id_new, lobe_subject)
                    # GRUG: Every new lobe automatically gets an AIML tribe registered.
                    # Cap = floor(LOBE_NODE_CAP / 3) — executive layer bounded to 1/3 parent.
                    # This is NOT optional: lobe without AIML registration means /aimlRight
                    # and /aimlWrong will silently skip it. Register now, always, loudly.
                    aiml_cap = AIMLNodeSystem.register_lobe!(lobe_id_new, Lobe.LOBE_NODE_CAP)
                    println("\U0001f9e0 Lobe '$(lobe_id_new)' created for subject: '$(lobe_subject)'. Cap: $(Lobe.LOBE_NODE_CAP) nodes. AIML tribe registered (cap=$aiml_cap).")
                end

            elseif !isnothing(m_connectlobes)
                # GRUG: /connectLobes <id_a> <id_b> - link two lobes bidirectionally.
                # BrainStem uses connections for lateral signal routing.
                # Example: /connectLobes language emotion
                lobe_a = String(m_connectlobes.captures[1])
                lobe_b = String(m_connectlobes.captures[2])
                # GRUG: IMMUNE GATE — lobe connections are stored structure!
                if !immune_gate("/connectLobes", lobe_a * " " * lobe_b; is_critical=false)
                    println("⛔ /connectLobes blocked by immune system.")
                else
                    Lobe.connect_lobes!(lobe_a, lobe_b)
                    println("\U0001f517 Lobes '$(lobe_a)' \u2194 '$(lobe_b)' connected.")
                end

            elseif !isnothing(m_lobegrow)
                # GRUG QoL-2025 BUG-008: /lobeGrow is now a deprecated alias
                # for /grow <lobe_id> <packet>. We route through the unified
                # grow_nodes_from_packet code path so there's only ONE place
                # where node creation + lobe attach happens. The deprecation
                # warning surfaces once per call so users notice and migrate.
                target_lobe_id = String(m_lobegrow.captures[1])
                lobe_json      = String(strip(m_lobegrow.captures[2]))
                println("⚠  /lobeGrow is deprecated. Use: /grow $target_lobe_id <packet>")

                lobegrow_immune_passed = immune_gate("/lobeGrow", lobe_json; is_critical=true)

                if !lobegrow_immune_passed
                    # immune said no
                elseif !haskey(Lobe.LOBE_REGISTRY, target_lobe_id)
                    println("⚠  /lobeGrow: Lobe '$(target_lobe_id)' does not exist. Use /newLobe first.")
                elseif Lobe.lobe_is_full(target_lobe_id)
                    println("!!! LOBE FULL: Lobe '$(target_lobe_id)' has reached its node cap. Cannot grow more nodes! Use /newLobe to add a new lobe. !!!")
                else
                    try
                        new_ids = grow_nodes_from_packet(lobe_json; target_lobe=target_lobe_id)
                        println("🌱 Grew $(length(new_ids)) node(s) into lobe '$(target_lobe_id)': [$(join(new_ids, ", "))]")
                    catch e
                        ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" :
                              e isa Lobe.LobeError ? " [ctx: $(e.context)]" : ""
                        println("!!! ERROR in /lobeGrow: $e$ctx !!!")
                    end
                end

            elseif !isnothing(m_lobes)
                # GRUG: /lobes - uses get_lobe_status_summary() which includes O(1) reverse index count.
                println(Lobe.get_lobe_status_summary())

            elseif !isnothing(m_tablestatus)
                # GRUG: /tableStatus <lobe_id> - show hash table chunk sizes for a lobe.
                # Shows nodes/json/drop/hopfield/meta chunk entry counts.
                ts_lobe_id = String(m_tablestatus.captures[1])
                try
                    if !LobeTable.table_exists(ts_lobe_id)
                        println("\u26a0  /tableStatus: No table found for lobe '$(ts_lobe_id)'. Does the lobe exist?")
                    else
                        println(LobeTable.get_table_summary(ts_lobe_id))
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableStatus: $e$ctx !!!")
                end

            elseif !isnothing(m_tablematch)
                # GRUG: /tableMatch <lobe_id> <chunk> <pattern> - pattern-activate entries.
                # chunk must be one of: nodes, json, drop, hopfield, meta
                # pattern is matched as token mode (any token in pattern activates key)
                # Example: /tableMatch lang json node_0 -> all json fields for node_0
                # Example: /tableMatch lang drop node_0 -> all drop neighbors of node_0
                tm_lobe_id  = String(m_tablematch.captures[1])
                tm_chunk    = String(strip(m_tablematch.captures[2]))
                tm_pattern  = String(strip(m_tablematch.captures[3]))
                try
                    if !LobeTable.table_exists(tm_lobe_id)
                        println("\u26a0  /tableMatch: No table found for lobe '$(tm_lobe_id)'.")
                    else
                        # GRUG: Use prefix mode when pattern looks like a node_id, token otherwise
                        match_mode = startswith(tm_pattern, "node_") ? :prefix : :token
                        hits = LobeTable.table_match(tm_lobe_id, tm_chunk, tm_pattern, mode=match_mode)
                        if isempty(hits)
                            println("[tableMatch] No entries matched '$(tm_pattern)' in chunk '$(tm_chunk)' of lobe '$(tm_lobe_id)'.")
                        else
                            println("[tableMatch] $(length(hits)) hits in lobe='$(tm_lobe_id)' chunk='$(tm_chunk)' pattern='$(tm_pattern)':")
                            for (k, v) in sort(collect(hits), by=x->x[1])
                                println("  $(k) -> $(v)")
                            end
                        end
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableMatch: $e$ctx !!!")
                end

            elseif !isnothing(m_thesaurus)
                # GRUG: /thesaurus <input1> | <input2> - dimensional similarity comparison.
                # Optional context lists after :: separators (comma-separated).
                # Examples:
                #   /thesaurus happy | joyful
                #   /thesaurus machine learning | artificial intelligence
                #   /thesaurus dog | canine :: pet,animal :: domesticated,beast
                raw1 = String(strip(m_thesaurus.captures[1]))
                raw2 = String(strip(m_thesaurus.captures[2]))
                # GRUG: Parse optional context lists after :: separator in raw2
                ctx1 = String[]
                ctx2 = String[]
                if occursin("::", raw2)
                    parts = split(raw2, "::")
                    raw2  = String(strip(parts[1]))
                    if length(parts) >= 2
                        ctx1 = filter(!isempty, map(c -> String(strip(c)), split(parts[2], ",")))
                    end
                    if length(parts) >= 3
                        ctx2 = filter(!isempty, map(c -> String(strip(c)), split(parts[3], ",")))
                    end
                end
                try
                    result = Thesaurus.thesaurus_compare(raw1, raw2; context1=ctx1, context2=ctx2)
                    intensity = Thesaurus.format_thesaurus_intensity(result.overall)
                    # GRUG: Show seed synonyms for single-word inputs so operator sees what gate knows
                    syns1 = !occursin(" ", raw1) ? Thesaurus.get_seed_synonyms(raw1) : String[]
                    syns2 = !occursin(" ", raw2) ? Thesaurus.get_seed_synonyms(raw2) : String[]
                    syn1_str = isempty(syns1) ? "" : "  → seeds: $(join(first(syns1, 4), ", "))"
                    syn2_str = isempty(syns2) ? "" : "  → seeds: $(join(first(syns2, 4), ", "))"
                    println("\n\U0001f50d THESAURUS COMPARISON")
                    println("  Input 1  : \"$(raw1)\"$(syn1_str)")
                    println("  Input 2  : \"$(raw2)\"$(syn2_str)")
                    println("  Type     : $(result.match_type)")
                    println("  \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
                    println("  Overall  : $(round(result.overall * 100, digits=1))%  [$(intensity)]")
                    println("  Semantic : $(round(result.semantic * 100, digits=1))%")
                    println("  Context  : $(round(result.contextual * 100, digits=1))%")
                    println("  Assoc    : $(round(result.associative * 100, digits=1))%")
                    println("  Confid.  : $(round(result.confidence * 100, digits=1))%")
                    if !isempty(ctx1)
                        println("  Ctx1     : $(join(ctx1, ", "))")
                    end
                    if !isempty(ctx2)
                        println("  Ctx2     : $(join(ctx2, ", "))")
                    end
                    println()
                catch e
                    # GRUG: Surface full error context from typed exceptions, not just message!
                    if e isa Thesaurus.ThesaurusError
                        println("!!! THESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! THESAURUS ERROR: $e !!!")
                    end
                end

            elseif !isnothing(m_neginhibit)
                # GRUG: /negativeThesaurus add <word> [--reason <text>]
                # Register a word/phrase as inhibited. Filtered from input before scanning.
                inhibit_word   = String(strip(m_neginhibit.captures[1]))
                inhibit_reason = isnothing(m_neginhibit.captures[2]) ? "" : String(strip(m_neginhibit.captures[2]))
                # GRUG: IMMUNE GATE — inhibition list is stored structure!
                if !immune_gate("/negativeThesaurus add", inhibit_word; is_critical=false)
                    println("⛔ /negativeThesaurus add blocked by immune system.")
                else
                try
                    InputQueue.add_inhibition!(inhibit_word; reason=inhibit_reason)
                    println("🚫 Inhibition registered: '$(inhibit_word)'" * (isempty(inhibit_reason) ? "" : "  reason: $(inhibit_reason)"))
                    println("   NegativeThesaurus size: $(InputQueue.inhibition_count()) / $(InputQueue.NEG_THESAURUS_MAX)")
                catch e
                    if e isa InputQueue.InputQueueError
                        println("!!! NEGATIVETHESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                    end
                end
                end  # GRUG: End immune_gate else block for /negativeThesaurus add

            elseif !isnothing(m_negremove)
                # GRUG: /negativeThesaurus remove <word>
                # Remove a word from the inhibition list.
                remove_word = String(strip(m_negremove.captures[1]))
                try
                    removed = InputQueue.remove_inhibition!(remove_word)
                    if removed
                        println("✅ Inhibition removed: '$(remove_word)'. Word no longer blocked.")
                    else
                        println("⚠️  '$(remove_word)' was not in NegativeThesaurus. Nothing changed.")
                    end
                catch e
                    println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                end

            elseif !isnothing(m_neglist)
                # GRUG: /negativeThesaurus list
                # Show all currently inhibited words with reasons and timestamps.
                entries = InputQueue.list_inhibitions()
                if isempty(entries)
                    println("📋 NegativeThesaurus is empty. No words currently inhibited.")
                else
                    println("📋 NegativeThesaurus — $(length(entries)) inhibited word(s):")
                    for e in entries
                        age_s   = round(time() - e.added_at, digits=0)
                        reason  = isempty(e.reason) ? "(no reason)" : e.reason
                        println("   🚫 '$(e.word)'   reason: $(reason)   added: $(age_s)s ago")
                    end
                end

            elseif !isnothing(m_negcheck)
                # GRUG: /negativeThesaurus check <word>
                # Quick check if a word is inhibited or not.
                check_word = String(strip(m_negcheck.captures[1]))
                if InputQueue.is_inhibited(check_word)
                    println("🚫 '$(check_word)' IS inhibited in NegativeThesaurus.")
                else
                    println("✅ '$(check_word)' is NOT inhibited. Word passes filter freely.")
                end

            elseif !isnothing(m_negflush)
                # GRUG: /negativeThesaurus flush
                # Remove ALL inhibitions at once. Destructive but useful for resets.
                old_count = InputQueue.inhibition_count()
                lock(InputQueue._NEG_LOCK) do
                    empty!(InputQueue._NEG_THESAURUS)
                end
                println("🧹 NegativeThesaurus flushed. Removed $(old_count) inhibition(s). Cave filter is now empty.")

            elseif !isnothing(m_savespecimen)
                # GRUG: /saveSpecimen <filepath> — freeze the entire cave state to a
                # gzip-compressed JSON file. Every node, lobe, rule, message, verb,
                # thesaurus entry, inhibition, arousal level — EVERYTHING.
                spec_path = String(strip(m_savespecimen.captures[1]))
                add_message_to_history!("System", "/saveSpecimen $spec_path", false)

                println("--> Grug freezing entire cave to specimen file...")
                result_summary = save_specimen_to_file!(spec_path)
                println("\n$result_summary")
                # GRUG v7.14: Store a one-line digest instead of the full
                # multi-line banner. The banner was leaking into Fresh Memory
                # and degrading subsequent mission context quality.
                add_message_to_history!("System", "Specimen saved: $spec_path", false)

            elseif !isnothing(m_loadspecimen)
                # GRUG: /loadSpecimen <filepath> — thaw a previously saved specimen file
                # and RESTORE the entire cave state. This is a DESTRUCTIVE operation —
                # current state is WIPED and replaced. Full brain transplant.
                spec_path = String(strip(m_loadspecimen.captures[1]))
                add_message_to_history!("System", "/loadSpecimen $spec_path", false)

                # GRUG: IMMUNE GATE — loadSpecimen replaces ENTIRE brain! CRITICAL!
                if !immune_gate("/loadSpecimen", spec_path; is_critical=true)
                    println("⛔ /loadSpecimen blocked by immune system.")
                else
                    println("--> Grug thawing specimen from file...")
                    result_summary = load_specimen_from_file!(spec_path)
                    println("\n$result_summary")
                    # GRUG v7.14: One-line digest, not the full restore banner.
                    # The banner was leaking into Fresh Memory and degrading
                    # subsequent mission context quality.
                    add_message_to_history!("System", "Specimen loaded: $spec_path", false)
                end

            elseif !isnothing(m_login)
                # GRUG: /login <password> — authenticate as admin
                # Password is hashed and compared. Session established on success.
                password = String(strip(m_login.captures[1]))
                add_message_to_history!("System", "/login [REDACTED]", false)

                success, message = admin_login(password)
                println(message)
                add_message_to_history!("System", message, false)

            elseif !isnothing(m_logout)
                # GRUG: /logout — terminate admin session
                add_message_to_history!("System", "/logout", false)
                message = admin_logout()
                println(message)
                add_message_to_history!("System", message, false)

            elseif !isnothing(m_writesave)
                # GRUG: /writeSave <filepath> <json> — append JSON to save file
                # Requires admin login. Validates JSON before writing.
                # This is DANGEROUS - can inject arbitrary data into save files!
                filepath = String(strip(m_writesave.captures[1]))
                json_str = String(strip(m_writesave.captures[2]))
                add_message_to_history!("System", "/writeSave $filepath [JSON]", false)

                try
                    result = append_to_save_file(json_str, filepath)
                    println(result)
                    add_message_to_history!("System", result, false)
                catch e
                    error_msg = "⛔ /writeSave failed: $e"
                    println(error_msg)
                    add_message_to_history!("System", error_msg, false)
                end

            elseif !isnothing(m_nodeattach)
                # GRUG: /nodeAttach <target_id> <attach_id1> <pattern1> [<attach_id2> <pattern2> ...]
                # Relational fire system: bolt nodes onto a target with user-defined patterns.
                # Parsing: target_id is first token. Remaining tokens alternate between
                # node_id and quoted/unquoted pattern. Each pair is one attachment.
                #
                # Supported formats:
                #   /nodeAttach target_0 node_1 "hello world" node_2 "fire pattern"
                #   /nodeAttach target_0 node_1 hello node_2 fire
                #
                # GRUG: Use a regex to extract pairs of (node_id, pattern) after target_id.
                raw_args = String(strip(m_nodeattach.captures[1]))
                # GRUG: IMMUNE GATE — node attachments are stored structure!
                if !immune_gate("/nodeAttach", raw_args; is_critical=false)
                    println("⛔ /nodeAttach blocked by immune system.")
                else
                
                # GRUG: Tokenize respecting quoted strings
                tokens = String[]
                remaining = raw_args
                while !isempty(remaining)
                    remaining = lstrip(remaining)
                    isempty(remaining) && break
                    if remaining[1] == '"'
                        # GRUG: Quoted token — find closing quote
                        close_idx = findnext('"', remaining, 2)
                        if isnothing(close_idx)
                            error("!!! FATAL: /nodeAttach found opening quote with no closing quote! Check your syntax! !!!")
                        end
                        push!(tokens, remaining[2:close_idx-1])
                        remaining = remaining[close_idx+1:end]
                    else
                        # GRUG: Unquoted token — split on whitespace
                        space_idx = findfirst(isspace, remaining)
                        if isnothing(space_idx)
                            push!(tokens, remaining)
                            remaining = ""
                        else
                            push!(tokens, remaining[1:space_idx-1])
                            remaining = remaining[space_idx+1:end]
                        end
                    end
                end

                if length(tokens) < 3
                    error("!!! FATAL: /nodeAttach needs at least: <target_id> <attach_id> <pattern>. Got $(length(tokens)) token(s)! !!!")
                end

                target_id = tokens[1]
                
                # GRUG: Remaining tokens are pairs: (node_id, pattern)
                pair_tokens = tokens[2:end]
                if length(pair_tokens) % 2 != 0
                    error("!!! FATAL: /nodeAttach attachment args must be pairs of <node_id> <pattern>. Got odd count ($(length(pair_tokens)))! !!!")
                end

                n_pairs = length(pair_tokens) ÷ 2
                if n_pairs > MAX_ATTACHMENTS
                    error("!!! FATAL: /nodeAttach trying to attach $n_pairs nodes at once, but max is $MAX_ATTACHMENTS! !!!")
                end

                results = String[]
                for i in 1:n_pairs
                    aid = pair_tokens[(i-1)*2 + 1]
                    pat = pair_tokens[(i-1)*2 + 2]
                    result = attach_node!(target_id, aid, pat)
                    push!(results, result)
                end

                println("🔗 /nodeAttach complete:")
                for r in results
                    println("   → $r")
                end
                add_message_to_history!("System", "/nodeAttach: $(join(results, " | "))", false)
                end  # GRUG: End immune_gate else block for /nodeAttach

            elseif !isnothing(m_nodedetach)
                # GRUG: /nodeDetach <target_id> <attach_id>
                # Remove a specific attached node from a target.
                target_id = String(strip(m_nodedetach.captures[1]))
                attach_id = String(strip(m_nodedetach.captures[2]))
                result = detach_node!(target_id, attach_id)
                println("🔓 $result")
                add_message_to_history!("System", "/nodeDetach: $result", false)

            elseif !isnothing(m_imgnodeattach)
                # GRUG: /imgnodeAttach <target_id> <attach_id> <image_data_b64> [<width> <height>]
                # Same as /nodeAttach but for image nodes. Image binary is converted to
                # nonlinear SDF at attach time (JIT GPU accel). Confidence is baked from
                # SDF signal similarity. The attach_id MUST be an image node.
                #
                # Supported formats:
                #   /imgnodeAttach target_0 img_node_1 "data:image/png;base64,iVBOR..." 64 64
                #   /imgnodeAttach target_0 img_node_1 "data:image/png;base64,iVBOR..."
                #   (if width/height omitted, defaults to 8x8 — user should specify)
                #
                # GRUG: Tokenize respecting quoted strings (same as /nodeAttach)
                raw_args = String(strip(m_imgnodeattach.captures[1]))
                # GRUG: IMMUNE GATE — image node attachments are stored structure!
                if !immune_gate("/imgnodeAttach", raw_args; is_critical=false)
                    println("⛔ /imgnodeAttach blocked by immune system.")
                else
                tokens = String[]
                remaining = raw_args
                while !isempty(remaining)
                    remaining = lstrip(remaining)
                    isempty(remaining) && break
                    if remaining[1] == '"'
                        close_idx = findnext('"', remaining, 2)
                        if isnothing(close_idx)
                            error("!!! FATAL: /imgnodeAttach found opening quote with no closing quote! Check your syntax! !!!")
                        end
                        push!(tokens, remaining[2:close_idx-1])
                        remaining = remaining[close_idx+1:end]
                    else
                        space_idx = findfirst(isspace, remaining)
                        if isnothing(space_idx)
                            push!(tokens, remaining)
                            remaining = ""
                        else
                            push!(tokens, remaining[1:space_idx-1])
                            remaining = remaining[space_idx+1:end]
                        end
                    end
                end

                if length(tokens) < 3
                    error("!!! FATAL: /imgnodeAttach needs at least: <target_id> <attach_id> <image_data>. Got $(length(tokens)) token(s)! !!!")
                end

                target_id = tokens[1]
                attach_id = tokens[2]
                image_input = tokens[3]

                # GRUG: Parse optional width/height (default 8x8 if not provided)
                img_width = length(tokens) >= 4 ? parse(Int, tokens[4]) : 8
                img_height = length(tokens) >= 5 ? parse(Int, tokens[5]) : 8

                # GRUG: Detect and decode image binary from the input string
                found, fmt, extracted = ImageSDF.detect_image_binary(image_input)
                if !found
                    error("!!! FATAL: /imgnodeAttach could not detect image binary in input! Expected Base64 data URI or hex dump! !!!")
                end

                # GRUG: Convert extracted image data to raw bytes
                image_bytes = if fmt == :base64
                    ImageSDF.base64_to_bytes(extracted)
                else
                    # GRUG: For hex/raw formats, convert hex string to bytes
                    hex_clean = replace(extracted, r"[^A-Fa-f0-9]" => "")
                    [parse(UInt8, hex_clean[i:i+1], base=16) for i in 1:2:length(hex_clean)-1]
                end

                result = attach_image_node!(target_id, attach_id, image_bytes, img_width, img_height)
                println("🖼️🔗 /imgnodeAttach complete:")
                println("   → $result")
                add_message_to_history!("System", "/imgnodeAttach: $result", false)
                end  # GRUG: End immune_gate else block for /imgnodeAttach

            elseif !isnothing(m_imgnodedetach)
                # GRUG: /imgnodeDetach <target_id> <attach_id>
                # Same as /nodeDetach — reuse detach_node! since AttachedNode is universal.
                target_id = String(strip(m_imgnodedetach.captures[1]))
                attach_id = String(strip(m_imgnodedetach.captures[2]))
                result = detach_node!(target_id, attach_id)
                println("🖼️🔓 $result")
                add_message_to_history!("System", "/imgnodeDetach: $result", false)

            elseif !isnothing(m_attachments)
                # GRUG: /attachments — show all current node attachments
                summary = get_attachment_summary()
                println(summary)

            else
                error("!!! FATAL: Grug command bad format. Use /help to see all valid commands. !!!")
            end
            
        catch e
            println("!!! SYSTEM ERROR: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
        end
    end
end

# GRUG: Only run the CLI when executing Main.jl directly as a script,
# not when loaded as part of the GrugBot420 package (e.g., by Documenter or Pkg.test).
if abspath(PROGRAM_FILE) == @__FILE__
    run_cli()
end

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: BEHAVIORAL LAYER (MAIN.JL - UPDATED)
#
# 1. COGNITIVE SUPERPOSITION (MULTI-VOTE ORCHESTRATION):
# The routing engine abandons "winner-takes-all" Softmax weighting in favor of a 
# deterministic/stochastic superposition model. The maximum confidence threshold 
# mathematically bounds the sure_votes array (guaranteed truths), while ALL 
# remaining valid votes are subjected to an iterative 50/50 @coinflip to simulate 
# stochastic side-feature consideration (unsure_votes).
#
# 2. STOCHASTIC AIML RULES:
# Each orchestration rule now carries a fire_probability [0.0, 1.0]. At generation
# time, rules roll against their probability before being injected into the JIT
# payload. This produces natural, non-robotic variation in orchestrator output.
# Rules with no [prob=X] suffix default to 1.0 (always fire, backward compatible).
#
# 3. /WRONG FEEDBACK LOOP:
# /wrong triggers apply_wrong_feedback!() on all node IDs from the last /mission.
# Each voter does a coinflip strength penalty. Nodes reaching strength=0 become
# GRAVE markers used as negative reinforcement anchors during future generative phases.
#
# 4. IMAGE BINARY ROUTING:
# /mission and /grow pre-screen input via ImageSDF.detect_image_binary() regex.
# Detected image binary is decoded, JIT-converted to SDFParams, processed through
# EyeSystem (edge blur + arousal-gated attention cutout), jittered, and converted
# to a flat signal vector for PatternScanner-compatible image node matching.
#
# 5. IDLE MODE: CHATTER + PHAGY COINFLIP (v7.1 — SLOW TIMER):
# Idle detection runs between CLI prompts via maybe_run_idle(). When the cave has
# been quiet for ~120s (±30s jitter), a 50/50 coinflip fires. BOTH chatter and
# phagy share this same slow timer. Both require >= 1000 alive non-image nodes;
# new specimens skip ALL idle actions. HEADS triggers a chatter session: 50-500 node clones gossip
# and exchange patterns. Only WEAK nodes morph — receivers must be weaker than
# senders. Each node can only morph once per 24 hours (MORPH_COOLDOWN_MAP).
# TAILS triggers a phagy cycle: one of six maintenance automata runs
# (ORPHAN_PRUNER, STRENGTH_DECAYER, GRAVE_RECYCLER, CACHE_VALIDATOR,
# DROP_TABLE_COMPACT, RULE_PRUNER). Phagy also requires 1000+ nodes (gated above coinflip).
# Only ONE automaton runs per phagy cycle to preserve Big-O safety. User input
# arriving during chatter is queued and drained after session completion. Phagy is
# synchronous and completes before the next prompt, so no queuing is needed.
#
# 6. DROP TABLE CO-ACTIVATION:
# scan_and_expand() replaces direct scan_specimens() calls for text missions.
# Primary scan results are expanded with drop-table neighbor nodes, modeling
# associative memory co-activation.
#
# 7. BIG-O RESPONSE TIME TRACKING:
# process_mission() measures wall-clock time for each full scan+vote+generate cycle
# and records it on all participating nodes via record_response_time!(). Nodes 
# with slow average times are automatically graved by the Engine ledger system.
#
# 8. SEMANTIC VERB REGISTRY CLI INTEGRATION:
# Four CLI commands expose the SemanticVerbs live registry to the operator at runtime:
#   /addVerb <verb> <class>           — adds a verb to an existing relation class
#   /addRelationClass <name>          — creates a new verb class bucket
#   /addSynonym <canonical> <alias>   — registers alias→canonical normalization
#   /listVerbs                        — dumps all classes, verbs, and synonyms
# All mutations take effect immediately on the next /mission call because
# extract_relational_triples() calls get_all_verbs() and normalize_synonyms()
# on every invocation. Errors from bad class names or duplicate entries are
# surfaced loudly through the standard CLI catch block with a printed backtrace.
#
# 9. ACTION+TONE AROUSAL PRE-SET IN BEHAVIORAL LAYER:
# process_mission() invokes ActionTonePredictor.predict_action_tone() a second
# time (first invocation is inside scan_specimens for confidence weighting) to
# apply an EyeSystem arousal nudge before the scan. The two invocations are
# intentionally orthogonal: the engine-layer call modulates per-node confidence
# multipliers (scan concern); the behavioral-layer call here modulates the global
# arousal level (EyeSystem concern). apply_prediction_to_arousal!() is decoupled
# from EyeSystem via function handle injection, keeping the predictor independently
# testable. Both calls are wrapped in non-fatal try/catch: a prediction failure
# never blocks the mission scan or response generation.
#
# 10. LOBE-AWARE PREFRONTAL CORTEX (AIML CONTEXT):
# extract_lobe_aware_context(votes) maps all votes to their owning lobes,
# building a cross-domain context string injected into the AIML payload via
# the {LOBE_CONTEXT} placeholder. This ensures the prefrontal cortex (AIML)
# has global awareness of which subject domains are active for the current
# query, preventing domain isolation where only one lobe's knowledge would
# be visible. Active lobe names, node counts, and sample patterns are
# included so orchestration rules can reason across science ↔ philosophy ↔
# reasoning boundaries. Errors in lobe context extraction are non-fatal
# (logged via @warn, fallback to empty context string).
#
# 11. NEGATIVE THESAURUS (INHIBITION FILTER):
# Five CLI commands expose the InputQueue.NegativeThesaurus to the operator:
#   /negativeThesaurus add <word> [--reason <text>]  — register inhibition
#   /negativeThesaurus remove <word>                 — deregister
#   /negativeThesaurus list                          — show all entries
#   /negativeThesaurus check <word>                  — test if inhibited
#   /negativeThesaurus flush                         — clear all entries
# Inhibited words are filtered from input tokens before pattern scanning,
# acting as a pre-scan suppression layer. O(1) lookup via Dict{String,NegEntry}.
#
# 12. SPECIMEN PERSISTENCE (FULL CAVE STATE SAVE/RESTORE):
# /saveSpecimen <filepath> serializes the ENTIRE cave state to a gzip-compressed
# JSON file. /loadSpecimen <filepath> reads that file and performs a full brain
# transplant — current state is WIPED and replaced with the specimen contents.
# Together they provide long-term persistence for GrugBot instances.
#
# State categories captured (17 total, v2.1):
#   1. nodes          — full Node structs (id, pattern, signal, action_packet,
#                       strength, neighbors, graves, drop_table, response_times,
#                       hopfield_key, relational_patterns, etc.)
#   2. hopfield_cache — familiar input fast-path cache + hit counts
#   3. rules          — AIML_DROP_TABLE stochastic orchestration rules
#   4. message_history— up to 10k ChatMessage entries with pin flags
#   5. lobes          — LOBE_REGISTRY (subject, node_ids, connections, fire/inhibit)
#   6. node_to_lobe_idx — NODE_TO_LOBE_IDX reverse index
#   7. lobe_tables    — LOBE_TABLE_REGISTRY with all chunks (NodeRef objects)
#   8. verb_registry  — SemanticVerbs classes + verbs + synonyms
#   9. thesaurus_seeds— Thesaurus SYNONYM_SEED_MAP (hardcoded + runtime)
#  10. inhibitions    — InputQueue NegativeThesaurus entries
#  11. arousal        — EyeSystem arousal state (level, decay_rate, baseline)
#  12. id_counters    — NODE ID_COUNTER + MSG_ID_COUNTER atomic values
#  13. brainstem      — dispatch count, propagation history
#  14. attachments    — ATTACHMENT_MAP relational fire system
#  15. trajectory     — ActionTonePredictor ring buffer + config (Lorenz damping)
#  16. temporal_coherence — ImageSDF TEMPORAL_COHERENCE_LEDGER timing patterns
#  17. morph_cooldowns — ChatterMode MORPH_COOLDOWN_MAP 24h timestamps
#
# /loadSpecimen is DESTRUCTIVE: validates the entire file structure BEFORE
# wiping any state. If validation fails, ZERO changes are made. Restore order
# is deliberate: counters → verbs → thesaurus → lobes → lobe_tables → nodes →
# node_to_lobe_idx → hopfield → rules → inhibitions → messages → arousal →
# brainstem → attachments → trajectory → temporal_coherence → morph_cooldowns.
# Each restore step is individually wrapped in try/catch with FATAL error
# reporting. v2.1 keys are optional on load for backward compat with v2.0.
# File format: gzip-compressed JSON (system gzip/gunzip via pipeline,
# no extra Julia packages required).
# ==============================================================================