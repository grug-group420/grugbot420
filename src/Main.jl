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
# GRUG: Guard against double-include if PhagyMode already loaded by caller.
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️  HOPFIELD_CACHE / HOPFIELD_CACHE_LOCK ARE DEAD AND IRRELEVANT. They remain
#     as vestigial positional args in run_phagy!() because automaton 7
#     (CACHE_VALIDATOR) is permanently disabled. Do NOT waste time on them.
#     They will be cleaned up when the function signature is next refactored.
# ═══════════════════════════════════════════════════════════════════════════════
if !isdefined(@__MODULE__, :PhagyMode)
    include("PhagyMode.jl")
    using .PhagyMode
end

# GRUG: MitosisMode — idle-time autocatalytic node growth. When cave is idle
# and has enough warrant (data + energy), grow new nodes automatically.
# Guard against double-include if MitosisMode already loaded by caller.
if !isdefined(@__MODULE__, :MitosisMode)
    include("MitosisMode.jl")
    using .MitosisMode
end

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

# GRUG v7.24: The following modules are included by GrugBot420.jl in package
# mode but Main.jl also references them directly (SelfObserver, InputDecomposer,
# MultipartOrchestrator, HippocampalModulator, EphemeralMLP). When tests
# include Main.jl standalone, these must be in scope. Same guard pattern.
if !isdefined(@__MODULE__, :SelfObserver)
    include("SelfObserver.jl")
    using .SelfObserver
end

if !isdefined(@__MODULE__, :MultipartOrchestrator)
    include("MultipartOrchestrator.jl")
    using .MultipartOrchestrator
end

if !isdefined(@__MODULE__, :EphemeralAutomaton)
    include("EphemeralAutomaton.jl")
    using .EphemeralAutomaton
end

if !isdefined(@__MODULE__, :InputDecomposer)
    include("InputDecomposer.jl")
    using .InputDecomposer
end

if !isdefined(@__MODULE__, :HippocampalModulator)
    include("HippocampalModulator.jl")
    using .HippocampalModulator
end

if !isdefined(@__MODULE__, :EphemeralMLP)
    include("EphemeralMLP.jl")
    using .EphemeralMLP
end

# GRUG: RelationalGovernance and InputLedger must be in scope for Main.jl.
# When loaded as part of GrugBot420 package, they're already included
# upstream. When tests include Main.jl standalone, these guards pull them in.
if !isdefined(@__MODULE__, :RelationalGovernance)
    include("RelationalGovernance.jl")
    using .RelationalGovernance
end

if !isdefined(@__MODULE__, :InputLedger)
    include("InputLedger.jl")
    using .InputLedger
end

if !isdefined(@__MODULE__, :ChatterResiduals)
    include("ChatterResiduals.jl")
    using .ChatterResiduals
end

# GRUG: TemporalGrowth — lobe-aware ephemeral growth automaton. Spawns in ONE
# named lobe at a time, reads fresh user input, extracts vote + pattern activator
# data, grows a few new nodes, then latches them to related groups. Uses the
# same InputLedger consumed-entry pattern as process_batch! so it only reads
# fresh (unconsumed) MESSAGE_HISTORY entries. Replaces the old MitosisMode
# idle cycle (which was disabled in commit 1eb8e85).
if !isdefined(@__MODULE__, :TemporalGrowth)
    include("TemporalGrowth.jl")
    using .TemporalGrowth
end

# GRUG: AutoGrowth + AutoLinker — live-conversation auto-learning. When Main.jl
# runs STANDALONE (julia src/Main.jl, the actual bot launch path), these are NOT
# in scope unless we include+using them here. When loaded via GrugBot420.jl they
# are already module-level; the isdefined guard prevents double-include. WITHOUT
# this, every AutoGrowth/AutoLinker call in process_mission/idle/save silently
# fails with UndefVarError (swallowed by try/catch) — i.e. auto-learning is DEAD.
# AutoGrowth must load before AutoLinker (AutoLinker uses its co-occurrence map).
if !isdefined(@__MODULE__, :AutoGrowth)
    include("AutoGrowth.jl")
    using .AutoGrowth
end
if !isdefined(@__MODULE__, :AutoLinker)
    include("AutoLinker.jl")
    using .AutoLinker
end

# GRUG: FullLobeScanner needed for scanner_config save/load (section 37/4.37).
# When loaded via GrugBot420.jl, it's already in scope; guard prevents double-include.
if !isdefined(@__MODULE__, :FullLobeScanner)
    include("FullLobeScanner.jl")
    using .FullLobeScanner
end

# GRUG: SigilRegistry needed for sigil_table save/load and time orientation.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :SigilRegistry)
    include("SigilRegistry.jl")
    using .SigilRegistry
end

# GRUG: VoteOrchestrator needed for vote_orchestrator_knobs save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :VoteOrchestrator)
    include("VoteOrchestrator.jl")
    using .VoteOrchestrator
end

# GRUG: RelationalJitter needed for relational_jitter_config save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :RelationalJitter)
    include("RelationalJitter.jl")
    using .RelationalJitter
end

# GRUG: AIMLNodeSystem needed for aiml_system save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :AIMLNodeSystem)
    include("AIMLNodeSystem.jl")
    using .AIMLNodeSystem
end

# GRUG: TonalJudge needed for tonal_judge_knobs save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :TonalJudge)
    include("TonalJudge.jl")
    using .TonalJudge
end

# GRUG: ActionTonePredictor needed for action_tone_knobs save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :ActionTonePredictor)
    include("ActionTonePredictor.jl")
    using .ActionTonePredictor
end

# GRUG: CoherenceField — scalar field Φ over activation state + gradient ΔΦ for
# vote-routing modulation. Included in GrugBot420.jl after ActionTonePredictor.
# Guard prevents double-include when Main.jl is loaded standalone.
if !isdefined(@__MODULE__, :CoherenceField)
    include("CoherenceField.jl")
    using .CoherenceField
end

# GRUG: ImmuneThreadPool needed for immune_config save/load.
# When loaded via GrugBot420.jl, it's already in scope; guard prevents double-include.
if !isdefined(@__MODULE__, :ImmuneThreadPool)
    include("ImmuneThreadPool.jl")
    using .ImmuneThreadPool
end

# GRUG: SemanticVerbs needed for verb_registry save/load.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :SemanticVerbs)
    include("SemanticVerbs.jl")
    using .SemanticVerbs
end

# GRUG: ArithmeticEngine needed for arithmetic bindings.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :ArithmeticEngine)
    include("ArithmeticEngine.jl")
    using .ArithmeticEngine
end

# GRUG v10: PettyLearner — instant fast-path learning for trivial gaps.
# When loaded via GrugBot420.jl, it's already in scope; guard prevents double-include.
if !isdefined(@__MODULE__, :PettyLearner)
    include("PettyLearner.jl")
    using .PettyLearner
end

# GRUG: SigilPromoter needed for sigil promotion logic.
# When loaded via GrugBot420.jl (which includes it inside engine.jl), it's already in scope.
if !isdefined(@__MODULE__, :SigilPromoter)
    include("SigilPromoter.jl")
    using .SigilPromoter
end

using Base64: base64decode
using SHA: sha256
using JSON
using Statistics: mean

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

# GRUG v7.18: VOTES-REQUEST-CONTEXT GATE — confidence safety net.
# When no participating node opts into context via json_data["wants_context"],
# we still pull Fresh Memory if the primary vote is below this trust floor.
# A genuinely uncertain cave benefits from prior signal even if the winning
# stance didn't ask for it. SURE votes at or above the floor stay grounded
# in the current vote alone — that's how coherence is preserved over a
# long conversation.
const CONTEXT_TRUST_FLOOR        = 0.45

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
# GRUG v7.24: Monotonic counter for any auto-generated runtime ID that must be
# globally unique within a session (MLP user rules, MLP cycle observations,
# etc.). Pure increment — no time-based collision possible. NEVER use
# `round(time(), digits=0)` for IDs again; seconds collide trivially when two
# CLI commands land in the same wall-second. ID invariant: every registry
# entry MUST have a unique ID, period.
const RUNTIME_ID_COUNTER   = Atomic{Int}(0)
@inline function next_runtime_id(prefix::AbstractString)
    n = atomic_add!(RUNTIME_ID_COUNTER, 1)
    # Encode wall time AND the monotonic n so the ID is also human-readable
    # while remaining collision-free even at sub-millisecond cadence.
    return string(prefix, "_", round(time(), digits=3), "_", n)
end
const MESSAGE_HISTORY_LOCK = ReentrantLock()  # GRUG: Lock for phagy forensics read-access to MESSAGE_HISTORY

# GRUG: Capture the most recent AIML spoken output so external harnesses
# (interaction scripts, REPLs, tests) can read the actual response text
# instead of scraping stdout or the one-line digest stored in history.
# Written by process_mission at the scaffold-print site. Read-only for callers.
const _LAST_AIML_OUTPUT      = Ref("")
const _LAST_AIML_OUTPUT_LOCK = ReentrantLock()
const _LAST_FIRED_NODE       = Ref("")
const _LAST_PRIMARY_ACTION   = Ref("")
const _LAST_CONFIDENCE       = Ref(0.0)

# GRUG v7.58: Track the last loaded specimen path for save-on-exit prompt.
const _LAST_SPECIMEN_PATH = Ref("")
const _LAST_SPECIMEN_PATH_LOCK = ReentrantLock()

# GRUG v7.12: Track which messages contributed to the LAST /mission's
# Fresh Memory so /right and /wrong can reinforce/punish them. Reset at
# the top of every mission cycle via refresh_message_intensities!.
const LAST_SELECTED_MSG_IDS = Ref(Set{Int}())
const LAST_SELECTED_MSG_LOCK = ReentrantLock()

# GRUG v7.51: Pending hippocampal ask-question state.
# When the cave is empty or confidence is very low, the system asks a question.
# This stores the mission text that caused the question so /answer and /antiAnswer
# can reference it. Cleared when either command fires. The lock is for thread
# safety since maybe_run_idle and process_mission run on different tasks.
const _HIPPOCAMPAL_PENDING_ASK      = Ref("")          # mission text that caused the question
const _HIPPOCAMPAL_PENDING_ASK_LOCK = ReentrantLock()

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
        
        # GRUG: Auto-detect format — .gz for compressed, .json for plain (Windows-friendly)
        _ws_is_gz = lowercase(strip(save_filepath)[max(1, end-2):end]) == ".gz"
        try
            if _ws_is_gz
                open(save_filepath, "w") do io
                    proc = open(`gzip -c`, "r+")
                    write(proc, json_out)
                    close(proc.in)
                    compressed = read(proc)
                    write(io, compressed)
                end
            else
                open(save_filepath, "w") do io
                    write(io, json_out)
                end
            end
        catch e
            error("!!! FATAL: /writeSave failed to write file '$save_filepath': $e !!!")
        end
        
        return "✅ Created new save file: $save_filepath with appended JSON."
    end
    
    # GRUG: File exists - read, merge, write back
    try
        # GRUG: Read existing file — .gz needs gunzip, .json is plain text
        _ws_rd_is_gz = lowercase(strip(save_filepath)[max(1, end-2):end]) == ".gz"
        json_str_existing = if _ws_rd_is_gz
            read(`gunzip -c $save_filepath`, String)
        else
            read(save_filepath, String)
        end
        existing = JSON.parse(json_str_existing)
        
        # GRUG: Merge/append the new data
        # If new_data is a dict, merge into existing
        # If new_data is a list, append to appropriate array
        if isa(new_data, AbstractDict)
            for (key, value) in new_data
                if haskey(existing, key)
                    # GRUG: Key exists - merge or replace based on type
                    if isa(existing[key], AbstractDict) && isa(value, AbstractDict)
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
        
        # GRUG: Write back — same format as original file
        json_out = JSON.json(existing)
        if _ws_rd_is_gz
            open(save_filepath, "w") do io
                proc = open(`gzip -c`, "r+")
                write(proc, json_out)
                close(proc.in)
                compressed = read(proc)
                write(io, compressed)
            end
        else
            open(save_filepath, "w") do io
                write(io, json_out)
            end
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
extract_aiml_memory_context() -> NamedTuple{(:pinned, :fresh, :full, :threshold_note, :fresh_count, :pinned_count)}

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

GRUG v7.18: Returns both memory halves separately so the speech-facing
path (rule {MEMORY} substitution) can drop the fresh tail when the
action-tone predictor's MemoryPullPolicy says the current vote doesn't
need conversational continuity. Telemetry still uses the `:full` field
so operators see the complete memory bank in debug output.

NamedTuple fields:
  - pinned         : "Deep Memory (Pinned): ..." block
  - fresh          : "Fresh Memory [...] (Recent): ..." block
  - full           : pinned + "\\n" + fresh (legacy combined view)
  - threshold_note : auto-tuned cutoff snapshot ("threshold=X eligible=N")
  - fresh_count    : number of unpinned messages selected this cycle
  - pinned_count   : number of pinned messages surfaced

This layer scales: threshold tuning is a single O(N) pass per binary-
search step (≤12 steps), then the coinflip only touches ≤~MAX survivors,
never all N stored messages. NO SILENT FAILURES.
"""
function extract_aiml_memory_context()
    total_msgs = length(MESSAGE_HISTORY)
    if total_msgs == 0
        empty_block = "Memory Cave: [EMPTY]"
        return (pinned = empty_block,
                fresh  = empty_block,
                full   = empty_block,
                threshold_note = "empty",
                fresh_count = 0,
                pinned_count = 0)
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
        # GRUG v7.18: Return both halves separately so the speech-facing
        # path can drop the fresh tail when the action-tone predictor
        # says the current vote doesn't need it. The legacy `full_str`
        # is preserved for telemetry — operators always see the whole
        # memory bank in debug output, but the {MEMORY} rule substitution
        # uses only what the policy allows.
        pinned_block = "Deep Memory (Pinned): $pinned_str"
        fresh_block  = "Fresh Memory [$threshold_note] (Recent): $recent_str"
        full_block   = "$pinned_block\n$fresh_block"
        return (pinned = pinned_block,
                fresh  = fresh_block,
                full   = full_block,
                threshold_note = threshold_note,
                fresh_count = length(recent_msgs),
                pinned_count = length(pinned_msgs))
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
    # GRUG: Immune system DISABLED for specimen test. Always pass.
    # Original implementation commented out below. Re-enable by uncommenting
    # and removing the `return true` line.
    return true
    #= DISABLED IMMUNE SYSTEM:
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
            @warn "[IMMUNE] Immune scan threw unexpected error for $cmd_name (non-fatal): $e"
            return true
        end
    end
    =#
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
    #
    # MATCHING-DIMENSIONS PLUMBING: We also compute the per-vote signals
    # that feed VoteOrchestrator.composite_vote_score:
    #   - lobe_alignment: 1.0 if vote's node is in winner-lobe, 0.5 if
    #                     passthrough, 0.0 otherwise
    #   - relational_match: how much of the input's user_triples this
    #                       node's node_triples covered
    #   - action_tone_align: 1.0 if action_packet aligns with predicted
    #                        family, 0.0 if not, NaN if predictor inactive
    #   - anti_match_score: 1.0 if vote.antimatch (hard demotion)
    #   - peak_dominance: vote conf vs the lobe's mean conf (a within-lobe
    #                     winner is more trustworthy than one tied with
    #                     weak siblings)
    # All optional — NaN means "skip this knob for this candidate".
    _lobe_scores, _lobe_winner, _lobe_passthrough = LobeOrchestrator.get_last_state()
    winner_lobe = _lobe_winner
    passthrough_lobes = Set(_lobe_passthrough)
    # Build a lobe_id -> base_avg map so we can compute peak_dominance.
    lobe_base_map = Dict{String, Float64}()
    for (lid, base_avg, _, _, _) in _lobe_scores
        lobe_base_map[lid] = base_avg
    end
    # v7.24-restore: bring the ATP and TonalJudge channels back into vote
    # ranking. They cannot CREATE votes (pattern-bind has already happened),
    # but they SHOULD re-rank what survived so the primary winner reflects
    # user intent, not just token overlap.
    #
    # Action-tone prediction (last computed by scan_specimens). Snapshot once
    # and reuse for every candidate so we don't keep re-resolving the Ref.
    last_pred = try
        ActionTonePredictor.get_last_prediction()
    catch
        nothing
    end

    # v7.21b-3b: TonalJudge verdict (last computed by engine after the
    # prediction). Read once and reuse for every candidate. Nothing means
    # "no judge ran" -> all multipliers collapse to 1.0 (pure back-compat).
    last_judgement = try
        TonalJudge.get_last_judgement()
    catch
        nothing
    end

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

            # ---- compute optional matching-dimension signals -------------
            node_lobe = try
                Lobe.find_lobe_for_node(v.node_id)
            catch
                nothing
            end

            lobe_align = if isnothing(node_lobe)
                0.0
            elseif node_lobe == winner_lobe
                1.0
            elseif node_lobe in passthrough_lobes
                0.5
            else
                0.0
            end

            # Relational match: of the user_triples extracted from input,
            # how many showed up in this node's node_triples? Honest count.
            rel_match = if isempty(v.user_triples)
                NaN  # no ground truth — skip this dimension
            else
                user_keys = Set((t.subject, t.relation, t.object) for t in v.user_triples)
                node_keys = Set((t.subject, t.relation, t.object) for t in v.node_triples)
                shared = length(intersect(user_keys, node_keys))
                clamp(shared / max(1, length(user_keys)), 0.0, 1.0)
            end

            # Action-tone alignment: ask predictor whether this node's
            # action_packet is in the predicted family. NaN if no prediction
            # is currently active. v7.24-restore: this signal is back in
            # composite_vote_score so an "ACTION_QUERY/describe-family"
            # prediction lifts describe/explain/define votes and suppresses
            # alert/comfort/greet votes that don't match.
            tone_align = if isnothing(last_pred)
                NaN
            else
                try
                    w = ActionTonePredictor.get_action_weight_multiplier(last_pred, v.action)
                    # Multiplier is action_weight (>1) when aligned, suppression
                    # factor (<1) when not, 1.0 when prediction too weak.
                    # Map to [0,1]: aligned -> 1.0, neutral -> 0.5, suppressed -> 0.0
                    if w > 1.0
                        1.0
                    elseif w < 1.0
                        0.0
                    else
                        0.5
                    end
                catch
                    NaN
                end
            end

            anti_score = v.antimatch ? 1.0 : 0.0

            peak_dom = if !isnothing(node_lobe) && haskey(lobe_base_map, node_lobe)
                base = lobe_base_map[node_lobe]
                # Ratio of this vote's conf to lobe mean — clamped to [0,1].
                # 1.0 means this vote is at or above its lobe's average,
                # below means it's weaker than lobe siblings.
                base > 0 ? clamp(v.confidence / max(base, 1e-6), 0.0, 1.0) : NaN
            else
                NaN
            end

            # v7.21b-3b: Frame-match plug. Read this node's declared
            # frame_hints (a Vector{String} like ["de_escalating", "terse"])
            # from json_data and ask TonalJudge what multiplier to apply.
            # Empty/missing list -> 1.0 (back-compat). Match -> lift. Mismatch
            # -> inhibit ONLY under RELATIONAL mode (see TonalJudge for the
            # gating rule).
            node_hints = let raw = get(node.json_data, "frame_hints", String[])
                if raw isa Vector
                    String[lowercase(string(h)) for h in raw]
                elseif raw isa AbstractString
                    # tolerate a single-string declaration
                    String[lowercase(string(raw))]
                else
                    String[]
                end
            end
            frame_mult = try
                TonalJudge.compute_frame_match_multiplier(node_hints, last_judgement)
            catch e
                @warn "[ORCHESTRATOR] frame_match_multiplier failed for $(v.node_id): $e (using 1.0)"
                1.0
            end

            # GRUG v7.48: RELAY DETECTION.
            # Relay-fired nodes have a "relay_attached" RelationalTriple in their
            # node_triples. This triple was injected by scan_and_expand's PASS 3
            # (attachment relay). Primary-match nodes never carry this relation.
            # If detected, the VoteCandidate gets is_relay=true so
            # composite_vote_score applies RELAY_CONFIDENCE_DISCOUNT.
            is_relay = any(t -> getfield(t, :relation) == "relay_attached" ||
                                getfield(t, :relation) == "cascade_bridge", v.node_triples)

            # GRUG BUG-010: Grave shadow inhibition — dead knowledge casts shadows.
            # Group-scoped for regular nodes, global for AIML. Antimatch = 1.0.
            grave_shadow = try
                compute_grave_shadow(v.node_id)
            catch e
                @warn "[ORCHESTRATOR] grave_shadow failed for $(v.node_id): $e (using 1.0)"
                1.0
            end

            push!(vote_candidates, VoteOrchestrator.VoteCandidate(
                v.node_id, v.confidence, node.strength;
                strength_cap      = STRENGTH_CAP,
                lobe_alignment    = lobe_align,
                relational_match  = rel_match,
                action_tone_align = tone_align,
                anti_match_score  = anti_score,
                peak_dominance    = peak_dom,
                frame_match_multiplier = frame_mult,
                is_relay          = is_relay,
                grave_shadow_multiplier = grave_shadow,
                # recency_bonus left NaN — Node struct lacks last_fire_cycle
                # so we can't compute honest recency without adding tracking.
                # Knob is plumbed; fill in when the field exists.
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

    # GRUG v7.23: MULTIPART OBJECTIVE ORCHESTRATION.
    # GRUG v7.23: If any votes carry multipart_group != "" OR non-empty
    # input_chunks, use MultipartOrchestrator to build objectives and
    # generate output per-objective. Chunked affinities mean votes know
    # which part of the input they resolved — the orchestrator groups
    # them by chunk overlap instead of decomposer tags.
    # Singleton objectives (group="") flow through the old COMMANDS path unchanged.
    # GRUG v7.48: ALWAYS use ActionLog path — confidence-ordered dispatch,
    # reserved steps, and non-winner additive entries work for ALL missions,
    # not just multipart ones. Singleton missions also get "honest uncertainty
    # tip offs" now. The old COMMANDS path is kept as a fallback only if
    # build_objectives fails entirely.
    objectives = try
        MultipartOrchestrator.build_objectives(votes;
            threshold  = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
            top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW,
            strength_of = v -> begin
                n = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
                isnothing(n) ? 5.0 : n.strength
            end,
            strength_cap = STRENGTH_CAP
        )
    catch e
        @warn "[ORCHESTRATOR] MultipartOrchestrator.build_objectives failed, falling back to old path: $e"
        objectives = nothing
    end

    if objectives !== nothing && !isempty(objectives)
        # GRUG v7.23: ACTION LOG — votes write to a log, AIML reads from it.
        # The HippocampalModulator builds an ActionLog from MultipartOrchestrator's
        # output. Each log entry carries ONLY its objective's scoped votes —
        # no more passing the full vote pile to every COMMANDS handler.
        # Entries are numbered and sequenced with dependencies + context carry-forward.
        action_log = HippocampalModulator.create_action_log!()

        # GRUG v7.48: Pass non-winner votes to HippocampalModulator so they
        # surface as "honest uncertainty tip off" additive entries. Every
        # vote that didn't win its objective but had something to say gets
        # its own section. This works for ALL missions, not just multipart.
        nonwinner_votes = Vote[candidate_to_vote[vc.node_id] for vc in rejected_tier if haskey(candidate_to_vote, vc.node_id)]
        HippocampalModulator.modulate_objectives!(action_log, objectives;
            nonwinner_votes = nonwinner_votes)
        println("[HIPPOCAMPAL] Action log built:\n$(HippocampalModulator.log_summary(action_log))")

        # GRUG v7.47: Execute entries from the log one at a time, dispatched
        # by confidence (highest first). Each entry writes to its own reserved
        # step — step coherence is maintained by reserved_step ordering at
        # assembly time, not by dispatch order.
        all_sure = Vote[]
        all_unsure = Vote[]
        any_entry_completed = false

        while true
            entry = HippocampalModulator.next_pending!(action_log)
            isnothing(entry) && break

            # GRUG v7.47: Additive entries (non-winner unsure votes) have
            # empty sure_votes. They still need to produce output — use the
            # unsure vote as the primary driver for these entries.
            if entry.entry_type == HippocampalModulator.ENTRY_ADDITIVE
                # GRUG: Additive entry — unsure vote produces output directly.
                # These become bulleted list items prefixed with
                # "(Grug also think these infos maybe important)" at assembly time.
                additive_vote = entry.unsure_votes[1]
                additive_node = lock(() -> get(NODE_MAP, additive_vote.node_id, nothing), NODE_LOCK)
                if isnothing(additive_node)
                    @warn "[ORCHESTRATOR] ActionLog additive entry $(entry.sequence_number) node $(additive_vote.node_id) vanished, skipping"
                    HippocampalModulator.fail_entry!(action_log, entry.sequence_number)
                    continue
                end
                # GRUG: Additive entries get a lightweight output — just the
                # node's response. No full COMMANDS treatment, just the additive info.
                additive_output = COMMANDS[additive_vote.action](mission, additive_node, additive_vote, Vote[], Vote[additive_vote], Vote[additive_vote])
                if !isempty(additive_output)
                    HippocampalModulator.complete_entry!(action_log, entry.sequence_number, additive_output)
                    any_entry_completed = true
                    push!(all_unsure, additive_vote)
                else
                    HippocampalModulator.fail_entry!(action_log, entry.sequence_number)
                end
                continue
            end

            # GRUG: Sure/low-confidence entry — standard COMMANDS execution.
            # Extract the primary vote for this entry (first sure vote).
            entry_primary = entry.sure_votes[1]
            entry_node = lock(() -> get(NODE_MAP, entry_primary.node_id, nothing), NODE_LOCK)
            if isnothing(entry_node)
                @warn "[ORCHESTRATOR] ActionLog entry $(entry.sequence_number) primary node $(entry_primary.node_id) vanished, skipping"
                HippocampalModulator.fail_entry!(action_log, entry.sequence_number)
                continue
            end

            # GRUG: Generate output for this entry using ONLY its scoped votes.
            # This is the key fix: COMMANDS no longer receives the full vote pile.
            entry_sure = Vote[entry.sure_votes...]
            entry_unsure = Vote[entry.unsure_votes...]
            entry_all = Vote[entry.scoped_votes...]
            entry_output = COMMANDS[entry_primary.action](mission, entry_node, entry_primary, entry_sure, entry_unsure, entry_all)

            # GRUG: Mark entry complete — output stored for context carry-forward.
            if !isempty(entry_output)
                HippocampalModulator.complete_entry!(action_log, entry.sequence_number, entry_output)
                any_entry_completed = true
            else
                HippocampalModulator.fail_entry!(action_log, entry.sequence_number)
            end

            append!(all_sure, entry_sure)
            append!(all_unsure, entry_unsure)
        end

        # GRUG v7.47: Assemble final output using reserved_step ordering
        # with supplementary prefixes. This is the confidence-ordered,
        # step-coherent output — NOT the raw dispatch order.
        if any_entry_completed
            output = HippocampalModulator.assemble_output!(action_log)
        else
            # GRUG: All objectives produced nothing? Fall back to old path.
            output = COMMANDS[primary_vote.action](mission, node, primary_vote, sure_votes, unsure_votes, votes)
        end

        # GRUG: Wipe log at end of cycle — ephemeral by nature.
        HippocampalModulator.wipe_action_log!(action_log)

        # GRUG: Return the combined output with all contributing votes.
        if !isempty(all_sure) || !isempty(all_unsure)
            return output, all_sure, all_unsure
        end
        # GRUG: Fallback if no objective produced votes.
        return output, sure_votes, unsure_votes
    end

    # GRUG: build_objectives failed entirely — old COMMANDS path as fallback.
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

    # GRUG v8.1: TIME ORIENTATION — read from engine's cross-task stash.
    # When a time sigil (&now/&before/&next) fired during promotion, this
    # carries the orientation + vote_flags into the AIML context so the
    # response can reason temporally (reflect past, assess present, project future).
    time_orient, time_meta = current_time_orientation()
    time_directive = ""
    if time_orient != "none"
        vote_flags = get(time_meta, "vote_flags", Dict{String,Any}())
        signal_list = get(time_meta, "signal", String[])
        sigil_name = get(time_meta, "sigil_name", "?")
        # Build a temporal reasoning directive appended to the voice.
        # vote_flags tell us WHICH temporal mode is active:
        #   &now    → assess=true  (evaluate current state)
        #   &before → reflect=true (look back at what happened)
        #   &next   → project=true (reason forward about what comes next)
        mode_parts = String[]
        if get(vote_flags, "reflect", false) == true; push!(mode_parts, "reflect on what has already happened"); end
        if get(vote_flags, "assess", false) == true;  push!(mode_parts, "assess the current situation right now"); end
        if get(vote_flags, "project", false) == true; push!(mode_parts, "project forward about what may come next"); end
        if !isempty(mode_parts)
            time_directive = " Temporal reasoning active ($(time_orient) orientation via &$(sigil_name)): $(join(mode_parts, "; "))."
        end
        @info "[MAIN v8.1] Time orientation in payload: $(time_orient), directive='$(time_directive)'"
    end

    system_prompt = context["system_prompt"]
    # GRUG v8.1: Append temporal reasoning directive to system prompt.
    # This makes the voice carry the temporal orientation so downstream
    # synthesis reasons in the right time mode (past/present/future).
    if !isempty(time_directive)
        system_prompt = system_prompt * time_directive
    end
    neg_str       = isempty(primary_vote.negatives) ? "None" : join(primary_vote.negatives, ", ")

    memory_ctx = extract_aiml_memory_context()
    lobe_str  = extract_lobe_aware_context(all_votes)

    sure_str   = join([v.action for v in sure_votes], ", ")
    unsure_str = isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", ")

    # GRUG: VOTE CERTAINTY — SURE if primary stands alone at top, UNSURE if ties exist.
    # Tied alternatives = other sure_votes that were NOT picked as primary.
    tied_alternatives = Vote[v for v in sure_votes if v.node_id != primary_vote.node_id]
    vote_certainty = isempty(tied_alternatives) ? "SURE" : "UNSURE"
    tied_alt_str = isempty(tied_alternatives) ? "None" :
        join(["$(v.node_id)($(v.action),conf=$(round(v.confidence, digits=2)))" for v in tied_alternatives], ", ")

    # GRUG v7.18: VOTES-REQUEST-CONTEXT GATE.
    # ------------------------------------------------------------------
    # The previous design always pulled Fresh Memory into the {MEMORY}
    # rule substitution, which dragged a tail of intensity-flagged user
    # messages into every scaffold and rotted coherence over long
    # conversations. Action-tone family was tried as the gate, but the
    # right level is the NODE itself — each node knows whether its
    # stance benefits from continuity. A "validate the heart hurt"
    # comfort node KNOWS it wants the prior emotional thread; a fresh
    # "warm fire welcome friend" greeting node KNOWS it doesn't.
    #
    # CONTRACT: nodes opt in via `json_data["wants_context"] = true`
    # at growth time. The orchestrator OR's *winner* votes only —
    # if any contributing winning vote requests context, fresh memory
    # is pulled. Default is FALSE: silence is grounding, noise must be
    # earned.
    #
    # GRUG v7.20: WINNERS-ONLY restriction.
    # ------------------------------------------------------------------
    # Previously, ANY contributing vote (including losers that didn't
    # make it past the orchestrator's primary-or-tied filter) could
    # flip pull_fresh=true. That was too generous: a low-confidence
    # losing vote — which by definition didn't shape the answer —
    # shouldn't get to drag the whole conversation tail in.
    #
    # New rule: only the primary vote and any votes tied with it at
    # top confidence are eligible to request context. Losing votes
    # are ignored. This matches the principle that *only what shapes
    # the answer is allowed to ask for memory*.
    #
    # SAFETY NETS (independent of node flags):
    #   * UNSURE vote (ties at top)         → pull fresh
    #   * primary confidence < trust floor  → pull fresh
    # These cover the "cave is genuinely uncertain" case where context
    # helps disambiguate even if no winner asked for it.
    # ------------------------------------------------------------------

    # GRUG v7.20: Build the winning set = primary + any votes tied at the top.
    # `sure_votes` already contains primary + ties (built upstream by the
    # orchestrator). We use that directly so this stays in sync with the
    # orchestrator's own "what counts as winning" definition. If sure_votes
    # were empty (defensive edge case), fall back to {primary_vote} so the
    # gate still has a single anchor to consult.
    winning_votes = isempty(sure_votes) ? Vote[primary_vote] : sure_votes

    requesting_nodes = String[]
    lock(NODE_LOCK) do
        for v in winning_votes
            n = get(NODE_MAP, v.node_id, nothing)
            isnothing(n) && continue
            if get(n.json_data, "wants_context", false) === true
                push!(requesting_nodes, v.node_id)
            end
        end
    end

    pull_fresh_reason = ""
    pull_fresh = if !isempty(requesting_nodes)
        pull_fresh_reason = "winning node(s) requested context: " * join(requesting_nodes, ", ")
        true
    else
        # GRUG v7.23: ONLY pull fresh memory when a winning node asks for it.
        # The old safety nets (UNSURE certainty, CONTEXT_TRUST_FLOOR) forced
        # history into every low-confidence reply, making GrugBot hang up on
        # past events instead of answering the current question. The votes ARE
        # the answer. Low confidence = low-confidence answer, not a history
        # dump. If a node needs continuity, it opts in via wants_context=true.
        pull_fresh_reason = "no winning node requested context — fresh memory withheld (confidence=$(round(primary_vote.confidence, digits=2)), certainty=$(vote_certainty))"
        false
    end

    memory_str_for_speech = if pull_fresh
        memory_ctx.full
    else
        # GRUG: Pinned anchors stay (cheap, principled, operator-curated);
        # fresh tail drops. Telemetry still sees the full bank below.
        memory_ctx.pinned * "\nFresh Memory: <withheld — $(pull_fresh_reason)>"
    end

    # GRUG: Read rule board. Swap shape-shifter words for real context chunks.
    # NOW STOCHASTIC: each rule fires based on its fire_probability.
    # This is where Grug JIT-compiles math into human language with natural variation!
    #
    # v7.24-coherence-fix: rules now ALSO filter by leading action tag. A rule
    # like `[describe "Grug paint picture..."]` is only allowed to fire when
    # `describe` is the primary_vote.action OR is in sure_votes. Without this
    # filter, every rule on the board got concatenated into the AIML output
    # which produced a wall of `[describe ...]; [explain ...]; [comfort ...];
    # [calculate ...]; [alert ...]; [ponder ...]` directives even when only
    # `describe` actually won. That dilutes coherence.
    #
    # Rules with NO leading [action] prefix (legacy / structural rules) are
    # always considered. Rules with a leading [action] tag must match a
    # locked-in action to fire. Untagged rules and matching rules then run
    # the existing fire_probability coinflip.
    sure_action_set = Set{String}([lowercase(primary_vote.action)])
    for v in sure_votes
        push!(sure_action_set, lowercase(v.action))
    end

    evaluated_rules = String[]
    try
        for rule in lock(_DROP_TABLE_LOCK) do; copy(AIML_DROP_TABLE) end
            # Parse a leading [action_name "..."] tag, if present.
            # Pattern: optional whitespace, '[', action_name (word chars +
            # hyphen/underscore), at least one space, then a quote. This is
            # tolerant of the existing rule shape produced by /addRule.
            tag_match = match(r"^\s*\[([A-Za-z_][A-Za-z0-9_\-]*)\s+\"", rule.text)
            if tag_match !== nothing
                rule_action = lowercase(tag_match.captures[1])
                if !(rule_action in sure_action_set)
                    # Tagged rule whose action did not lock in this cycle.
                    # Skip it — its directive would just dilute the response.
                    continue
                end
            end
            # else: untagged / structural rule, always considered.

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
            processed = replace(processed, "{MEMORY}"         => memory_str_for_speech)
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

        # GRUG v7.21c-2: SWAP_RATE probabilistic gate.
        # Prior versions returned `rand(allowed)` unconditionally — that swapped
        # EVERY swappable token in every reply, producing word-salad like
        # "Subsist polite, brief" / "Construct tribemate" / "delete" for "clear".
        # Natural prose has continuity: most words should land as written, with
        # occasional fresh variants. Default 0.25 means ~3 of every 4 swappable
        # tokens stay original; ~1 in 4 picks a synonym. Env-overridable for
        # tests or operator tuning.
        swap_rate = try
            r = parse(Float64, get(ENV, "GRUG_THESAURUS_SWAP_RATE", "0.35"))
            (r < 0.0 || r > 1.0) ? 0.35 : r
        catch
            0.25
        end
        if rand() > swap_rate
            return word
        end

        # Stochastic pick — this is the natural-variation engine.
        # Two cycles on the same prompt roll different synonyms.
        return rand(allowed)
    end

    # -------------------------------------------------------------------
    # GRUG v7.36: _light_thesaurus_touch — gentle synonym variation for
    # authored prose (voice_body). Unlike _swap_words_in which swaps every
    # token at SWAP_RATE, this only considers words that have RICH synonym
    # sets (2+ alternatives in SYNONYM_SEED_MAP) and swaps at a
    # rate (LIGHT_TOUCH_RATE, default 0.30). This preserves the author's
    # voice and sentence structure while preventing the exact same paragraph
    # from appearing every time the same node wins. "Broadband thin push"
    # might become "Wideband thin push" or "Broadband narrow push" — same
    # knowledge, subtle freshness. Zero-cost when the word has no synonyms.
    # -------------------------------------------------------------------
    function _light_thesaurus_touch(sentence::String, drop_table::Vector{String},
                                     required_relations::Vector{String})::String
        # GRUG v7.38: bumped default from 0.15 to 0.30. Domain-specific
        # words now have synonyms but the old 0.15 rate barely changed anything.
        # 0.30 means ~1 in 3 eligible words gets swapped, producing visible
        # but not chaotic variation.
        light_rate = try
            r = parse(Float64, get(ENV, "GRUG_LIGHT_TOUCH_RATE", "0.30"))
            (r < 0.0 || r > 1.0) ? 0.30 : r
        catch
            0.30
        end
        tokens = split(String(sentence))
        out = String[]
        for tok in tokens
            m_tok = match(r"^([^a-zA-Z]*)([a-zA-Z]+)([^a-zA-Z]*)$", String(tok))
            if m_tok === nothing
                push!(out, String(tok))
                continue
            end
            prefix, core, suffix = String(m_tok.captures[1]), String(m_tok.captures[2]), String(m_tok.captures[3])
            clean = lowercase(core)
            # Skip: required relations, inhibited words, drop_table
            clean in required_relations && (push!(out, String(tok)); continue)
            InputQueue.is_inhibited(clean) && (push!(out, String(tok)); continue)
            clean in drop_table && (push!(out, String(tok)); continue)
            # GRUG v7.38: Lowered threshold from 3+ to 2+ alternatives.
            # Domain-specific entries (math, survival, philosophy) often have
            # exactly 2 high-quality synonyms. The old 3+ gate was preventing
            # these from ever swapping, making output static.
            n_syns = haskey(Thesaurus.SYNONYM_SEED_MAP, clean) ? length(Thesaurus.SYNONYM_SEED_MAP[clean]) : 0
            if n_syns < 2
                push!(out, String(tok))  # not enough alternatives — keep original
                continue
            end
            # Probabilistic swap at light_rate (much lower than full SWAP_RATE)
            if rand() > light_rate
                push!(out, String(tok))
                continue
            end
            # Pick a synonym (filtered by inhibition/drop_table)
            candidates = collect(Thesaurus.SYNONYM_SEED_MAP[clean])
            allowed = filter(c -> !InputQueue.is_inhibited(c) && !(c in drop_table), candidates)
            if isempty(allowed)
                push!(out, String(tok))
                continue
            end
            picked = rand(allowed)
            # Preserve capitalization
            if startswith(core, uppercase(first(core)))
                picked = uppercase(first(picked)) * picked[2:end]
            end
            push!(out, "$(prefix)$(picked)$(suffix)")
        end
        join(out, " ")
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
    # GRUG v7.21c-2: _reorder_clauses — phrase-level variety layer.
    #
    # Splits a sentence on commas and the conjunctions "and"/"or" into
    # segments, shuffles them probabilistically, and rejoins with natural
    # connectors. Adds the third layer of variety on top of (1) slot pick
    # and (2) word swap, so two cycles producing the same slot-prose still
    # speak it in different orders.
    #
    # Conservative by default:
    #   - REORDER_RATE (default 0.40) — chance the reorder fires at all
    #   - Only fires when ≥2 segments AND total tokens ≥4 (single short
    #     clauses don't reorder — nothing to shuffle)
    #   - Preserves the head-word capitalization of the original sentence
    #   - Preserves trailing punctuation (. ! ?) by detaching+reattaching
    #
    # Env override: GRUG_PHRASE_REORDER_RATE
    # -------------------------------------------------------------------
    function _reorder_clauses(sentence::String)::String
        s = strip(sentence)
        isempty(s) && return ""

        reorder_rate = try
            r = parse(Float64, get(ENV, "GRUG_PHRASE_REORDER_RATE", "0.40"))
            (r < 0.0 || r > 1.0) ? 0.40 : r
        catch
            0.40
        end
        rand() > reorder_rate && return String(s)

        # Detach trailing terminal punctuation
        m_end = match(r"^(.*?)([.!?]+)\s*$", String(s))
        body = m_end === nothing ? String(s) : String(m_end.captures[1])
        terminal = m_end === nothing ? "" : String(m_end.captures[2])

        # Split on comma OR " and " OR " or " (case-insensitive, surrounded by spaces).
        # We deliberately do NOT split on bare "and"/"or" without surrounding
        # spaces because they may appear inside compound words.
        segs = split(body, r",\s*|\s+and\s+|\s+or\s+"; limit=0)
        segs = String[strip(seg) for seg in segs if !isempty(strip(seg))]

        # Need at least 2 segments AND a total token count ≥4 to bother.
        if length(segs) < 2 || sum(length(split(seg)) for seg in segs) < 4
            return String(s)
        end

        # Shuffle. Reject the identity permutation if we got it back (so
        # the reorder is observable when it fires).
        shuffled = copy(segs)
        Random.shuffle!(shuffled)
        if shuffled == segs && length(segs) >= 2
            # Force a swap of the first two so the result really differs.
            shuffled[1], shuffled[2] = shuffled[2], shuffled[1]
        end

        # Lowercase the first character of each segment except the first,
        # so post-reorder we don't mid-sentence capitalize. Then capitalize
        # the new first segment to match natural prose head-casing.
        shuffled_norm = String[]
        for (i, seg) in enumerate(shuffled)
            if isempty(seg)
                continue
            end
            if i == 1
                # Capitalize first char if alpha
                first_char = first(seg)
                if isletter(first_char) && islowercase(first_char)
                    rest = length(seg) > 1 ? seg[nextind(seg, 1):end] : ""
                    push!(shuffled_norm, uppercase(first_char) * rest)
                else
                    push!(shuffled_norm, seg)
                end
            else
                first_char = first(seg)
                if isletter(first_char) && isuppercase(first_char)
                    rest = length(seg) > 1 ? seg[nextind(seg, 1):end] : ""
                    push!(shuffled_norm, lowercase(first_char) * rest)
                else
                    push!(shuffled_norm, seg)
                end
            end
        end

        # Rejoin with comma-then-and: "A, B, and C" feels natural.
        rejoined = if length(shuffled_norm) == 2
            shuffled_norm[1] * " and " * shuffled_norm[2]
        else
            join(shuffled_norm[1:end-1], ", ") * ", and " * shuffled_norm[end]
        end

        return rejoined * terminal
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
    # GRUG v7.21c-1: New scaffold knobs read from winning_node.json_data.
    # All three default to safe no-ops when absent so seeds don't have to
    # be exhaustively beefed up to keep working.
    node_voice_register      = ""             # "warm" / "terse" / "casual" / "plain" / "formal"
    node_noun_anchors        = String[]        # nouns this node's prose is "about"
    node_companion_node_pref = String[]        # preferred companion-frame node ids
    node_voice_variants      = String[]        # GRUG v7.36: alternative voice bodies for claim variety
    if winning_node !== nothing
        node_pattern     = winning_node.pattern
        node_drop_table  = [lowercase(strip(w)) for w in winning_node.drop_table]
        node_required    = [lowercase(strip(r)) for r in winning_node.required_relations]
        node_triples_obj = winning_node.relational_patterns
        # GRUG v7.21c-1: Read new json_data knobs. Each is optional; absent
        # = empty/no-op, never an error.
        node_voice_register = let raw = get(winning_node.json_data, "voice_register", "")
            raw isa AbstractString ? lowercase(strip(String(raw))) : ""
        end
        # GRUG v7.36: voice_variants — array of alternative voice bodies.
        # When present, the engine randomly picks one per cycle (with recency
        # filtering) instead of always using the system_prompt body. This is
        # the primary anti-repetition lever for authored prose. Without it,
        # the same node always says the same thing. With it, node_4 might say
        # "Gravity is broadband thin push" one cycle and "All force spreads
        # across a spectral range" the next. Same knowledge, fresh prose.
        node_voice_variants = let raw = get(winning_node.json_data, "voice_variants", String[])
            if raw isa AbstractVector
                [strip(String(x)) for x in raw if !isempty(strip(string(x)))]
            else
                String[]
            end
        end
        node_noun_anchors = let raw = get(winning_node.json_data, "noun_anchors", String[])
            if raw isa AbstractVector
                String[lowercase(strip(String(x))) for x in raw if !isempty(strip(string(x)))]
            else
                String[]
            end
        end
        node_companion_node_pref = let raw = get(winning_node.json_data, "companion_node_pref", String[])
            if raw isa AbstractVector
                String[String(x) for x in raw if !isempty(strip(string(x)))]
            else
                String[]
            end
        end
        # ─── v7.25 HARD CONFIG WARNINGS ───────────────────────────────────
        # These are NOT optional. If the winning node is missing critical
        # voice config, the response WILL be incoherent. The operator MUST
        # seed these fields or the cave speaks garbage. No silent failures.
        _voice_body_preview = let sp = String(get(winning_node.json_data, "system_prompt", ""))
            parts = split(sp, "."); isempty(parts) ? "" : strip(join([strip(String(p)) for p in parts[2:end] if !isempty(strip(String(p)))], ". "))
        end
        _has_voice_body   = !isempty(_voice_body_preview)
        _has_noun_anchors = !isempty(node_noun_anchors)
        _has_voice_reg    = !isempty(node_voice_register)
        _has_frame_hints  = haskey(winning_node.json_data, "frame_hints") && !isempty(winning_node.json_data["frame_hints"])
        if !_has_voice_body && !_has_noun_anchors
            @warn """⚠️  COHERENCE WARNING: Node $(primary_vote.node_id) has NO voice_body AND NO noun_anchors!
               system_prompt = \"$(String(get(winning_node.json_data, "system_prompt", "")))\"
               The claim will fall back to the raw pattern — this produces pattern-echo garbage.
               FIX: Add a multi-sentence system_prompt (sentence 1 = persona tag, rest = grug voice)
               OR add noun_anchors to this node's json_data. YOU NEED THIS OR NO CAN DO."""
        end
        if !_has_voice_reg
            @warn """⚠️  COHERENCE WARNING: Node $(primary_vote.node_id) has NO voice_register!
               The frame skeleton will be chosen by TonalJudge alone — may not match the node's intent.
               FIX: Add \"voice_register\" to this node's json_data (e.g. \"warm\", \"terse\", \"explanatory\",
               \"precise\", \"gentle\", \"urgent\", \"thoughtful\", \"observational\", \"friendly\"). YOU NEED THIS OR NO CAN DO."""
        end
        if !_has_frame_hints
            @warn """⚠️  COHERENCE WARNING: Node $(primary_vote.node_id) has NO frame_hints!
               TonalJudge cannot compute frame_match_multiplier — frame may be wrong for this node.
               FIX: Add \"frame_hints\" to this node's json_data (e.g. [\"warm\", \"plain\"], [\"imperative\", \"terse\"]).
               Valid hints: warm, exploratory, imperative, contemplative, de-escalating, terse, plain.
               YOU NEED THIS OR NO CAN DO."""
        end
    else
        @error "[MAIN v7.16 synthesis] winning node $(primary_vote.node_id) vanished between vote and synthesis — reply will be minimal."
    end

    # -------------------------------------------------------------------
    # -------------------------------------------------------------------
    # GRUG v7.21b-3d: COHERENCE-FIX — split the seeded grug-voice from
    # the structural skeleton.
    #
    # PROBLEM (v7.21b-3b leak): the synthesis filled {CLAIM} with the
    # raw trigger pattern (e.g. "hello hi", "i feel", "why"). Combined
    # with the action-keyed skeleton this produced echoey, parrot-style
    # responses like "Hello — here is what matters: hello hi.".
    #
    # FIX A: every node already carries a `system_prompt` whose first
    # sentence becomes the [voice prefix] tag. The REST of system_prompt
    # is a complete grug-voice utterance the seed author wrote
    # (e.g. node_18: "Grug listen to feeling. Validate, do not fix." →
    # body = "Validate, do not fix"). We use that body as the spoken
    # core whenever it's non-empty. Pattern-as-claim is kept as the
    # fallback for legacy / single-sentence prompts.
    #
    # FIX B: when we DO fall back to the skeleton, dispatch on the
    # judge's frame_hint (the felt-shape-of-the-moment) rather than the
    # action family. This wires v7.21b-2's TonalJudge into the prose
    # layer, completing the predictor → judge → orchestrator → speech
    # pipeline. The action-keyed skeletons remain as a final fallback
    # for the case where no judgement is available (e.g. judge module
    # disabled or LAST_JUDGEMENT not yet populated this session).
    # -------------------------------------------------------------------

    # --- voice split (Fix A) -------------------------------------------
    # First sentence = persona tag (still used as voice_prefix below).
    # Rest = grug-voice body (used as CLAIM when present).
    #
    # GRUG v7.36: VOICE VARIANTS — when the node has voice_variants in
    # its json_data, we randomly pick one as the active voice_body instead
    # of always using the system_prompt body. The system_prompt body is
    # always included as the first candidate. Recency filtering ensures we
    # don't repeat the same variant within a few cycles. When voice_variants
    # is empty (most nodes), behavior is identical to v7.35 — the system_prompt
    # body is the only option.
    sp_parts = split(system_prompt, ".")
    voice_first_local = strip(get(sp_parts, 1, ""))
    voice_body_pieces = String[]
    for i in 2:length(sp_parts)
        s = strip(sp_parts[i])
        isempty(s) && continue
        push!(voice_body_pieces, String(s))
    end
    voice_body_default = isempty(voice_body_pieces) ? "" : join(voice_body_pieces, ". ") * "."

    # GRUG v7.36: Build candidate pool from default body + voice_variants.
    # Apply recency filtering so recently-used variants are deprioritized.
    voice_candidates = String[]
    if !isempty(voice_body_default)
        push!(voice_candidates, voice_body_default)
    end
    append!(voice_candidates, node_voice_variants)
    if length(voice_candidates) > 1
        recent_preambles = lock(_RECENT_PREAMBLES_LOCK) do
            copy(_RECENT_PREAMBLES)
        end
        fresh = [v for v in voice_candidates if !(v in recent_preambles)]
        voice_body = isempty(fresh) ? rand(voice_candidates) : rand(fresh)
        # Stamp chosen variant into recency cache to avoid repeating
        lock(_RECENT_PREAMBLES_LOCK) do
            push!(_RECENT_PREAMBLES, voice_body)
            while length(_RECENT_PREAMBLES) > _RECENT_PREAMBLES_MAX
                popfirst!(_RECENT_PREAMBLES)
            end
        end
    else
        voice_body = voice_body_default
    end

    # --- frame-keyed skeleton (Fix B) ----------------------------------
    # Read the most recent TonalJudge verdict. nothing is fine — we just
    # don't have a frame opinion this cycle and fall back to the action
    # path. This keeps the change non-fatal for any caller that bypasses
    # the predictor (e.g. ephemeral_aiml_orchestrator on synthetic input).
    judged_frame_label = ""
    judged_frame_test_inject = false
    try
        j = TonalJudge.get_last_judgement()
        if j !== nothing
            judged_frame_label = TonalJudge.frame_hint_label(j.frame_hint)
            judged_frame_test_inject = (:test_inject in j.reasoning)
        end
    catch
        judged_frame_label = ""
        judged_frame_test_inject = false
    end

    # Frame skeletons. Each keeps a {CLAIM}.{SUPPORT} contract so the
    # downstream substitute step is unchanged.
    #
    # GRUG v7.32: ANTI-REPETITION — skeleton POOLS instead of singleton strings.
    # Same frame/action hitting the same single preamble every cycle is the #1
    # source of repetition. Now each frame gets a VECTOR of 5-8 variants; we
    # roll randomly and skip recently-used ones via _RECENT_PREAMBLES cache.
    # This turns ~14 possible shapes into ~80-100 with zero new infrastructure.

    # (Pool data, connector data, and helpers _pick_from_pool / _pick_connector
    #  now live at module scope — see const declarations after _RECENT_PREAMBLES.)

    # --- skeleton selection (v7.33 adaptive pool-based) --------------------
    # Pick from the appropriate pool, apply recency + overuse filter, then
    # substitute the {JOIN} placeholder with the adaptive connector pick.
    # v7.33: _pick_connector_adaptive() and _pick_from_pool_adaptive() use
    # _reflect_on_output() to suppress overused shapes. The loop is:
    # emit → observe → reflect → adjust. This is the "adjust" step.

    connector = _pick_connector_adaptive()

    # Terse frame is special: no {SUPPORT} slot, always just {CLAIM}.
    # Connector doesn't apply. Pool entries are already complete.
    if judged_frame_label == "terse"
        skeleton = judged_frame_test_inject ? _FRAME_SKELETON_POOLS["terse"][1] : _pick_from_pool_adaptive(_FRAME_SKELETON_POOLS["terse"], "terse")
    elseif haskey(_FRAME_SKELETON_POOLS, judged_frame_label) && !isempty(judged_frame_label)
        raw = judged_frame_test_inject ? _FRAME_SKELETON_POOLS[judged_frame_label][1] : _pick_from_pool_adaptive(_FRAME_SKELETON_POOLS[judged_frame_label], judged_frame_label)
        skeleton = replace(raw, "{JOIN}" => connector)
    else
        # Fall back to action-keyed pool
        action_is_prose_skel = length(split(String(primary_vote.action))) >= 2 &&
                               length(String(primary_vote.action)) >= 8

        pool_key = if action_is_prose_skel
            "prose"
        elseif primary_vote.action in ["greet", "welcome", "smile", "laugh"]
            "greet"
        elseif primary_vote.action in ["flee", "hide", "fight"]
            "flee"
        elseif primary_vote.action in ["comfort", "support", "validate", "acknowledge", "reassure"]
            "comfort"
        elseif primary_vote.action in ["alert", "warn", "caution", "notify", "flag"]
            "alert"
        elseif primary_vote.action in ["explain", "clarify", "describe", "define", "elaborate"]
            "explain"
        elseif primary_vote.action in ["inquire", "ask", "question", "wonder"]
            "ask"
        else
            "reason"
        end

        raw = isempty(judged_frame_label) ? _ACTION_SKELETON_POOLS[pool_key][1] : _pick_from_pool_adaptive(_ACTION_SKELETON_POOLS[pool_key], pool_key)
        skeleton = replace(raw, "{JOIN}" => connector)
    end

    # GRUG v7.21c-1: voice_register override on the skeleton.
    # The frame picks the *shape* of the reply (warm opener, terse no-support,
    # etc.); the register modulates the *texture* (formal expands contractions,
    # casual lowers verbosity, terse strips fillers). Register is per-node;
    # frame is per-judgement. They compose: a `terse` register on a `warm`
    # frame produces "Hello — {CLAIM}." (no SUPPORT, but warm opener kept).
    if !isempty(node_voice_register)
        if node_voice_register == "terse"
            # GRUG v7.34: FIX — terse register must strip ALL support-related
            # content, including the connector text between/around {CLAIM} and
            # {SUPPORT}. The old approach left dangling connector fragments.
            #
            # There are two skeleton shapes after {JOIN} substitution:
            #   (A) Claim-first: "... {CLAIM}<connector>{SUPPORT}..."
            #   (B) Support-first: "... {SUPPORT}<connector>{CLAIM}..."
            #
            # For (A), we strip from the connector through {SUPPORT} and tail.
            # For (B), we strip {SUPPORT} and its trailing connector, keeping {CLAIM}.
            # Both may have preamble text before the placeholders.
            #
            # --- (A) Claim-first connectors: strip connector + {SUPPORT} + tail ---
            # Broad match: after {CLAIM}, any connector text, {SUPPORT}, and tail.
            # v7.34 FIX: Must preserve {CLAIM}! Replace with "{CLAIM}", not "".
            skeleton = replace(skeleton, r"\{CLAIM\}[,;:.\s—–-]*(?:and |because |so )?\s*\{SUPPORT\}.*$" => "{CLAIM}")
            # Specific connectors (for robustness if broad match misses):
            skeleton = replace(skeleton, r"\{CLAIM\}\.\s*\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\}\s*—\s*\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\};\s*\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\},\s+and\s+\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\},\s+because\s+\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\},\s+so\s+\{SUPPORT\}.*$" => "{CLAIM}")
            skeleton = replace(skeleton, r"\{CLAIM\}\.\s+\{SUPPORT\}.*$" => "{CLAIM}")
            # --- (B) Support-first connectors: strip {SUPPORT} + connector, keep {CLAIM} ---
            # "{SUPPORT}, so {CLAIM}" → strip "{SUPPORT}, so " (anywhere in string)
            skeleton = replace(skeleton, r"\{SUPPORT\},\s+so\s+" => "")
            # "{SUPPORT} — {CLAIM}" → strip "{SUPPORT} — " (anywhere in string)
            skeleton = replace(skeleton, r"\{SUPPORT\}\s*—\s+" => "")
            # --- Fallback: if {SUPPORT} still present, nuke just it (not {CLAIM}) ---
            # Only strip the {SUPPORT} token itself, preserving surrounding text
            skeleton = replace(skeleton, r"\{SUPPORT\}" => "")
            # Clean up trailing punctuation/space before the end
            skeleton = replace(skeleton, r"[\s;:,—–-]+$" => "")
            # Collapse multiple spaces
            skeleton = replace(skeleton, r"  +" => " ")
            # GRUG v7.34: Don't add a period if {CLAIM} placeholder is the
            # last token — the claim itself already ends with punctuation.
            # Adding "." here creates a double-period after substitution.
            # Only add terminal punctuation if the skeleton ends with a
            # non-placeholder, non-punctuation character.
            if !endswith(skeleton, "{CLAIM}") && !endswith(skeleton, ".") && !endswith(skeleton, "!") && !endswith(skeleton, "?")
                skeleton = skeleton * "."
            end
        elseif node_voice_register == "formal"
            # Stretch the support hyphen-em to a colon for a more formal cadence.
            skeleton = replace(skeleton, " — " => ": ")
        end
        # "warm" / "casual" / "plain" don't tilt the skeleton; they only
        # affect downstream synonym swap weighting (future work). Leaving
        # them as no-ops here keeps registry forward-compatible.
    end

    # --- CLAIM construction (Fix A) ------------------------------------
    # GRUG v7.21c-2: Priority order with prose-action as top-priority:
    #   0. primary_vote.action  (NEW — when seed slots ARE answer-prose,
    #                            the picked slot IS the answer. The action
    #                            field carries the prose verbatim. Detection
    #                            heuristic: action has ≥2 word tokens AND
    #                            length ≥ 8 chars. Verbs like "greet" /
    #                            "flee" / "explain" stay sub-threshold.)
    #   1. system_prompt body   (the seeded grug-voice answer, c-1)
    #   2. node_pattern         (legacy v7.16 fallback)
    #   3. noun_anchors[1]      (c-1, wraps a single noun in its PPT-shape)
    #   4. mission-quoted fallback (last resort)
    action_str = String(primary_vote.action)
    action_is_prose = length(split(action_str)) >= 2 && length(action_str) >= 8

    # =================================================================
    # GRUG Stage 2: ARITHMETIC COMPUTATION — if sigils captured math
    # in the user input, actually COMPUTE the result and make it the
    # claim. This is the bridge: sigils are macros, and macros MUST
    # expand to their computed value. "what is 2+2" → "2 plus 2 equals 4",
    # NOT "Execute the calculation".
    # =================================================================
    arithmetic_result = nothing
    arithmetic_reply = ""
    _math_bindings_present = false
    try
        bindings = current_promotion_bindings()
        _math_bindings_present = ArithmeticEngine.has_math_bindings(bindings)
        if _math_bindings_present
            arithmetic_result = ArithmeticEngine.compute_arithmetic(bindings)
            if arithmetic_result.error === nothing
                arithmetic_reply = ArithmeticEngine.format_arithmetic_reply(arithmetic_result)
                @info "[MAIN Stage 2] Arithmetic computed: $(arithmetic_result.expression) = $(arithmetic_result.answer_str)"
                # GRUG v10: Auto-write arithmetic result to flashcard.
                # Every computed math fact gets stored for future instant lookup.
                # Next time "3+5" is asked, the flashcard hits instantly — no recompute.
                try
                    _arith_lobe = "math"
                    for (_lid, _lrec) in Lobe.LOBE_REGISTRY
                        if occursin("math", lowercase(_lrec.subject))
                            _arith_lobe = _lid
                            break
                        end
                    end
                    LobeTable.flashcard_put!(_arith_lobe, arithmetic_result.expression,
                        arithmetic_result.answer_str;
                        result_num=try Float64(arithmetic_result.answer) catch _ NaN end,
                        card_type=:arithmetic)
                catch _
                    # GRUG: Flashcard write failure is non-fatal. The arithmetic
                    # result is still used for this response.
                end
            else
                @warn "[MAIN Stage 2] Arithmetic computation failed: $(arithmetic_result.error)"
            end
        end
    catch e
        @warn "[MAIN Stage 2] Arithmetic engine error (non-fatal, falling back to normal claim): $e"
    end
    # v7.25: HARD WARNING when math bindings exist but winner isn't a math node.
    # This means the user asked for arithmetic but a non-math node won the vote.
    # The answer will NOT contain the math result — that's a coherence failure.
    if _math_bindings_present && isempty(arithmetic_reply)
        @warn """⚠️  COHERENCE WARNING: Math bindings detected but NO arithmetic result computed!
           Winning node = $(primary_vote.node_id), action = $(primary_vote.action)
           The user asked for arithmetic but the answer will NOT contain the math result.
           FIX: Either ensure MathLobe nodes win when math bindings exist, or add "then" to
           SPLIT_CONJUNCTIONS so compound inputs like "calculate X and then describe Y" decompose
           properly. YOU NEED MATH TO WIN WHEN MATH IS ASKED FOR, OR NO CAN DO."""
    end

    claim_raw = if !isempty(arithmetic_reply)
        # GRUG: ARITHMETIC WINS. The computed answer IS the claim.
        # Priority 0 — above everything else. When math is present,
        # the answer is the math, not the node pattern or voice body.
        arithmetic_reply
    elseif action_is_prose
        action_str                                # NEW v7.21c-2 top priority
    elseif !isempty(voice_body)
        voice_body
    elseif !isempty(node_noun_anchors)
        # v7.24-coherence-fix BUG #1: prefer noun_anchors OVER raw
        # node_pattern. The pattern is the matcher key, not speech —
        # speaking it back ("describe explain what fire warm") makes
        # the cave sound like a pattern echo. With at least one noun
        # anchor we can build a real sentence around the action and
        # the topic ("explain about fire") which is grammatical even
        # when the action verb is short.
        if length(node_noun_anchors) >= 2
            "$action_str about $(node_noun_anchors[1]) and $(node_noun_anchors[2])"
        else
            "$action_str about $(node_noun_anchors[1])"
        end
    elseif !isempty(node_pattern) && length(split(node_pattern)) >= 2
        # Last-resort claim: pattern has at least 2 words and we have
        # nothing better. This is the legacy v7.16 fallback. It can
        # still leak the matcher key into speech, but we only land
        # here when system_prompt body is empty AND noun_anchors are
        # empty — in that case the operator did not seed enough voice
        # context and the pattern is all we have.
        node_pattern
    elseif !isempty(node_pattern)
        # Single-word pattern — wrap in a minimal frame.
        "$action_str about $node_pattern"
    else
        "the mission \"$mission\" touches unseeded territory"
    end
    # GRUB v7.21c-2: After synonym swap, run the phrase-reorder layer so
    # multi-clause prose-actions ("hot rock that bites and dances") don't
    # always speak in the same comma-order across cycles. Single-clause
    # claims pass through unchanged (reorder fires only on ≥2 segments).
    #
    # GRUG v7.36: REVISED anti-repetition strategy for voice_body.
    # v7.24-BUG7 was too aggressive — protecting authored prose from ALL
    # variation means the same node always says the exact same thing. This
    # is the #1 source of perceived repetition in grug's output.
    #
    # NEW approach (v7.36): voice_variants (above) provide the primary
    # variety — different authored prose for the same knowledge. When a
    # variant is picked, it's already fresh. But we also apply a LIGHT
    # thesaurus touch to the chosen voice_body: only words with rich
    # synonym sets (3+ alternatives) are eligible for swap, at a very low
    # rate (GRUG_LIGHT_TOUCH_RATE, default 0.30). This means "broadband"
    # might become "wideband" but "the" stays "the". The author's sentence
    # structure, voice, and emphasis are preserved — only individual words
    # with good alternatives get subtle variation.
    #
    # When claim_raw came from voice_body_default (no variant picked),
    # the light touch prevents word-for-word repetition. When it came
    # from a voice_variant, the variant is already different prose, so
    # the light touch adds even more micro-variation on top.
    #
    # Mechanical claims (from patterns, noun_anchors, etc.) still get
    # the full _swap_words_in + _reorder_clauses treatment.
    claim = if judged_frame_test_inject
        String(claim_raw)
    elseif claim_raw == voice_body_default || (!isempty(node_voice_variants) && claim_raw in node_voice_variants)
        _light_thesaurus_touch(String(claim_raw), node_drop_table, node_required)
    else
        claim = _swap_words_in(String(claim_raw), node_drop_table, node_required)
        _reorder_clauses(claim)  # mechanical claim: variety is fine
    end

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
    # v7.24-BUG8: SKIP the triple when it's just pattern tokens echoed back.
    # "calculate compute number" or "describe targets explain" adds zero
    # semantic value — those are the node's pattern keywords, not insight.
    # Gate: at least one of (subject, object) must NOT be a token from
    # the node pattern or the primary action.
    if !isempty(node_triples_obj)
        preferred = nothing
        for t in node_triples_obj
            if lowercase(strip(t.relation)) in node_required
                preferred = t
                break
            end
        end
        t = preferred === nothing ? rand(node_triples_obj) : preferred
        # v7.24-BUG8a: Suppress circular triples (pattern echo).
        # OLD gate required ALL 3 tokens to be pattern/action tokens — too strict.
        # "describe→targets→explain" has subj∈pattern and obj∈pattern but rel∉pattern,
        # so it passed through and produced the incoherent "describe targets explain" echo.
        # NEW gate: if ≥2 of 3 tokens are pattern/action tokens, it's still a circular echo.
        # A meaningful triple needs at least 2 tokens that carry NEW semantic information
        # not already in the node's pattern. 1-out-of-3 is barely informative; 0-out-of-3
        # is definitely new. 2-or-3-out-of-3 is just the pattern speaking itself.
        pat_tokens = Set(split(lowercase(node_pattern)))
        act_tokens = Set(split(lowercase(action_str)))
        t_subj = lowercase(strip(String(t.subject)))
        t_obj  = lowercase(strip(String(t.object)))
        t_rel  = lowercase(strip(String(t.relation)))
        overlap_count = (t_subj in pat_tokens || t_subj in act_tokens ? 1 : 0) +
                        (t_obj  in pat_tokens || t_obj  in act_tokens ? 1 : 0) +
                        (t_rel  in pat_tokens || t_rel  in act_tokens ? 1 : 0)
        triple_is_circular = overlap_count >= 2
        if !triple_is_circular
            # GRUG v7.56: Expand relation sigil before synonym-swap.
            # If t.relation is a dynamic sigil (e.g. "&causal"), resolve it
            # to a concrete verb from the sigil expansion pool, then route
            # that concrete verb through _pick_synonym as usual. Without
            # this, "&causal" leaks into the conversational output verbatim.
            _raw_rel = String(t.relation)
            _rel_expanded = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, _raw_rel)
            if length(_rel_expanded) > 1 || (length(_rel_expanded) == 1 && _rel_expanded[1] != _raw_rel)
                # Sigil resolved — pick a random concrete verb from the expansion
                _concrete_rel = rand(_rel_expanded)
            else
                _concrete_rel = _raw_rel
            end
            rel_swapped  = _pick_synonym(_concrete_rel, node_drop_table, node_required)
            subj_swapped = _swap_words_in(String(t.subject),  node_drop_table, node_required)
            obj_swapped  = _swap_words_in(String(t.object),   node_drop_table, node_required)
            push!(support_pieces, " $(rand(_TRIPLE_PREFIX_POOL)) $subj_swapped $rel_swapped $obj_swapped.")
        else
            # v7.25: Check if ALL triples for this node are circular echoes.
            # If so, the operator seeded pattern-keyword triples that carry
            # zero semantic value. Warn hard so they fix the specimen.
            _n_circular = 0
            for _t in node_triples_obj
                _s = lowercase(strip(String(_t.subject)))
                _o = lowercase(strip(String(_t.object)))
                _r = lowercase(strip(String(_t.relation)))
                _ov = (_s in pat_tokens || _s in act_tokens ? 1 : 0) +
                      (_o in pat_tokens || _o in act_tokens ? 1 : 0) +
                      (_r in pat_tokens || _r in act_tokens ? 1 : 0)
                _ov >= 2 && (_n_circular += 1)
            end
            if _n_circular == length(node_triples_obj)
                @warn """⚠️  COHERENCE WARNING: Node $(primary_vote.node_id) has $(length(node_triples_obj)) relational triple(s) and ALL are circular pattern echoes!
                   Pattern = \"$(node_pattern)\" — the triples are just pattern keywords rearranged.
                   Support will be EMPTY for this node. That means no "The link is clear:" clause.
                   FIX: Seed meaningful triples that relate this node's TOPIC to other concepts,
                   not just re-state its trigger keywords. E.g. for a "fire" node, add
                   (wood, burns, ash) or (fire, produces, heat) — NOT (describe, targets, explain).
                   YOU NEED MEANINGFUL TRIPLES OR NO CAN DO."""
            end
        end
    end

    # (b) Sure companion → supporting claim. Only if we have at least
    # one tied alternative AND it gives us NEW prose (not a re-statement
    # of the primary's pattern). v7.21b-3d: prefer the companion's
    # system_prompt body too, falling back to its pattern only if no
    # body is available — this keeps companion clauses from echoing
    # trigger-tokens like "i feel" / "why" the way they did in v7.16.
    if !isempty(tied_alternatives)
        # GRUG v7.21c-1: If the winning node declared `companion_node_pref`,
        # prefer the first alt whose node_id appears in that list. Falls
        # back to the legacy "first tied alternative" heuristic when none
        # match (or when no preference list is configured).
        companion = tied_alternatives[1]
        if !isempty(node_companion_node_pref)
            for alt in tied_alternatives
                if alt.node_id in node_companion_node_pref
                    companion = alt
                    break
                end
            end
        end
        comp_node = lock(() -> get(NODE_MAP, companion.node_id, nothing), NODE_LOCK)
        if comp_node !== nothing
            comp_sp = String(get(comp_node.json_data, "system_prompt", ""))
            comp_parts = split(comp_sp, ".")
            comp_body_pieces = String[]
            for i in 2:length(comp_parts)
                s = strip(comp_parts[i])
                isempty(s) && continue
                push!(comp_body_pieces, String(s))
            end
            comp_body = isempty(comp_body_pieces) ? "" : join(comp_body_pieces, ". ") * "."

            comp_text = !isempty(comp_body) ? comp_body : String(comp_node.pattern)

            if !isempty(comp_text) && comp_text != node_pattern && comp_text != claim_raw
                comp_claim = _swap_words_in(comp_text, node_drop_table, node_required)
                push!(support_pieces, " $(rand(_COMPANION_PREFIX_POOL)) $comp_claim.")
            end
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

    # GRUG v7.34: DECOHERENCE FIX — dangling connector cleanup.
    # When support is empty, connectors like ", and {SUPPORT}" or "— {SUPPORT}"
    # leave trailing fragments (", and ", "— ", "; ", etc.) that make the
    # response read as broken prose. This cleanup pass detects and strips them.
    # Also handles double punctuation from claim ending with "." before a
    # connector that starts with "." or has a period after {CLAIM}.
    # Support-first connectors ({SUPPORT}, so {CLAIM}) produce LEADING
    # artifacts when support is empty — those need leading-edge cleanup too.
    # Mid-string artifacts: "Preamble {SUPPORT} — {CLAIM}" with empty support
    # produces "Preamble  — ClaimText" — the  —  after the preamble is the
    # leftover from the support-first connector.
    if isempty(support)
        # --- Trailing artifacts (claim-first connectors with empty support) ---
        # Order matters: longer patterns first to avoid partial matches.
        core_reply = replace(core_reply, r", and\s*$" => "")
        core_reply = replace(core_reply, r", because\s*$" => "")
        core_reply = replace(core_reply, r", so\s*$" => "")
        core_reply = replace(core_reply, r"\s*—\s*$" => "")
        core_reply = replace(core_reply, r";\s*$" => "")
        # --- Leading artifacts (support-first connectors with empty support) ---
        # At start of string: "{SUPPORT}, so {CLAIM}" → ", so ClaimText"
        # Also handles leading whitespace before the connector remnant
        core_reply = replace(core_reply, r"^\s*,\s*so\s+" => "")
        core_reply = replace(core_reply, r"^\s*—\s*" => "")
        # --- Mid-string artifacts (support-first connectors after preamble) ---
        # "Preamble {SUPPORT} — {CLAIM}" → "Preamble  — ClaimText" (double space before —)
        # Key signal: DOUBLE space before the em-dash, which comes from the
        # space before {SUPPORT} + space after it (both now empty). A single
        # space before — is legitimate (claim-first connector or skeleton tail).
        # Only collapse the double-space, don't strip the em-dash itself.
        # v7.34b: Also handle " —  — " (double em-dash from skeleton tail frame
        # like "{JOIN} — that's the landscape." with em-dash connector + empty support).
        # Also handle "——" (no-space double em-dash) and "— —" (space-only).
        core_reply = replace(core_reply, r"\s*—\s+—\s*" => " — ")
        core_reply = replace(core_reply, r"——" => "—")
        core_reply = replace(core_reply, r"  — " => " — ")
        # Also handle " , so " (space-comma from support-first comma-so)
        core_reply = replace(core_reply, r" , so " => " ")
        # v7.34b: Handle leading em-dash from support-first connector in skeleton tail.
        # "{SUPPORT} — {CLAIM} — tail" with empty support → " — ClaimText — tail"
        core_reply = replace(core_reply, r"^—\s+" => "")
        # Mid-string em-dash from support-first connector after preamble prefix.
        # "Action: — ClaimText" → "Action: ClaimText"
        # "Listen: — ClaimText" → "Listen: ClaimText"
        core_reply = replace(core_reply, r":\s+—\s+" => ": ")
        # v7.34b: Period-em-dash tail artifact from skeleton tail frames.
        # "ClaimText. — that's the landscape." → "ClaimText."
        # The period before em-dash means claim already has terminal punctuation;
        # the em-dash + tail is a leftover from skeleton "{JOIN} — tail" with empty support.
        # Strip from ". —" to end of string.
        core_reply = replace(core_reply, r"\.\s*—.*$" => ".")
        # Collapse multiple spaces generally
        core_reply = replace(core_reply, r"  +" => " ")
        # Collapse multiple spaces
        core_reply = replace(core_reply, r"  +" => " ")
        # Double period: claim ends with "." and connector was ".{SUPPORT}" → ".."
        core_reply = replace(core_reply, r"\.\s*\." => ".")
        # Period-comma: claim ends with "." and connector was ", and" → ".,"
        core_reply = replace(core_reply, r"\.,\s*$" => ".")
        # Trailing period-space before nothing
        core_reply = replace(core_reply, r"\.\s+$" => ". ")
        # General trailing whitespace
        core_reply = replace(core_reply, r"\s+$" => "")
        # Ensure the reply ends with terminal punctuation
        if !isempty(core_reply) && !occursin(r"[.!?]$", core_reply)
            core_reply = core_reply * "."
        end
    else
        # Support IS present — still clean up double punctuation that can
        # occur when claim ends with "." and connector starts with "."
        core_reply = replace(core_reply, r"\.\s*\." => ".")
        # "., " → ". " (period-comma from claim-period + comma-connector)
        core_reply = replace(core_reply, r"\.,\s+" => ". ")
    end

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
    # v7.21b-3d: re-use the voice_first_local we already split out above.
    # v7.24-BUG6: DON'T leak the raw persona tag into the response body.
    #   "[Highly polite greeting protocols active]" is an internal label,
    #   not something Grug would say out loud. The voice body (sentences 2+)
    #   already carries the actual speech. The first sentence is a frame for
    #   the TonalJudge, not for the user's eyes. Suppress it entirely.
    voice_first = String(voice_first_local)
    voice_prefix = (judged_frame_test_inject && !isempty(voice_first)) ? "[$voice_first] " : ""   # v7.24-BUG6: persona tag is internal, except deterministic legacy test-injected fixtures

    # GRUG v7.34: DECOHERENCE FIX — [Directives: ...] is an internal shaping
    # note for a downstream LLM consumer, NOT user-visible text. It leaked
    # into every response producing artifacts like:
    #   "Every newcomer is potential friend. [Directives: What is quantum mechanics; ...]"
    # This was the #1 source of visible decoherence. Directives still appear
    # in DEBUG TELEMETRY below for operator inspection, but they are NO LONGER
    # appended to the conversational reply the user sees.
    directive_suffix = ""   # v7.34: suppressed from user-visible reply

    conversational_reply = "$voice_prefix$core_reply$pinned_citation$lobe_tag"

    # GRUG PERF FIX: Removed sleep(0.3) here. generate_aiml_payload is called
    # once PER FIRED NODE — with a 95-node specimen that's 40-60 calls per turn,
    # so a 0.3s sleep added 12-19s of pure dead wait to every response. The
    # "don't burn CPU" rationale was never real (the synthesis itself is <1ms).
    # This single line was ~100% of the input→response latency.

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
    # GRUG v7.34: Directives now hidden from user-visible reply but still
    # logged here for operator inspection.
    println(payload_io, "Evaluated Rules (shaping): $rules_str")
    # GRUG Stage 2: Arithmetic computation telemetry — shows whether
    # sigil-captured math was actually computed this cycle.
    if arithmetic_result !== nothing
        println(payload_io, "Arithmetic Computed: $(arithmetic_result.expression) = $(arithmetic_result.answer_str)")
        println(payload_io, "  Steps: $(length(arithmetic_result.steps))")
        for (i, step) in enumerate(arithmetic_result.steps)
            println(payload_io, "    Step $i: $(step.lhs) $(step.operator) $(step.rhs) = $(step.result)")
        end
        if arithmetic_result.error !== nothing
            println(payload_io, "  Error: $(arithmetic_result.error)")
        end
    else
        try
            bindings = current_promotion_bindings()
            if ArithmeticEngine.has_math_bindings(bindings)
                println(payload_io, "Arithmetic: math bindings present but computation was not run")
            else
                println(payload_io, "Arithmetic: no math bindings this cycle")
            end
        catch
            println(payload_io, "Arithmetic: <telemetry error>")
        end
    end
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
    # GRUG v7.18: Telemetry always shows the full memory bank so operators
    # can see what was available, plus the gate decision so they can see
    # what the speech path actually used.
    println(payload_io, memory_ctx.full)
    println(payload_io, "Memory-Pull Policy: pull_fresh=$(pull_fresh) — $(pull_fresh_reason)")
    # GRUG: Lobe Curve telemetry — replaces the old "Muted Lobes / Bridged Nodes"
    # readout. Shows base_avg × top_avg = score per lobe, with 👑 marking the
    # winner and ↗ marking pass-through runners-up. See LobeOrchestrator.jl.
    try
        println(payload_io, LobeOrchestrator.last_summary())
        _, _, _lobe_passthrough = LobeOrchestrator.get_last_state()
        if !isempty(_lobe_passthrough)
            println(payload_io, "Passthrough Lobes: [$(_lobe_passthrough)]")
        end
    catch e
        println(payload_io, "Lobe Curve: <telemetry error: $e>")
    end
    # GRUG v8.1: Time orientation telemetry — shows whether a time sigil
    # fired this cycle and what temporal reasoning mode is active.
    if time_orient != "none"
        println(payload_io, "Time Orientation: $(time_orient) (sigil=$(get(time_meta, "sigil_name", "?")), flags=$(get(time_meta, "vote_flags", Dict{String,Any}())))")
    else
        println(payload_io, "Time Orientation: none")
    end
    print(payload_io, "=========================================")

    # GRUG v7.33: OUTPUT SELF-OBSERVATION — Grug watches its own mouth.
    # After the payload is fully assembled, record a linguistic fingerprint
    # into the SelfObserver store. This is the mirror: the system sees what
    # it just said. Stochastic write (p_write default), non-fatal, bounded.
    # The observation loop is: emit → observe → reflect → adjust.
    # This is step 1 (observe). Steps 2-3 are _reflect_on_output() and
    # _pick_connector_adaptive() / _pick_from_pool_adaptive() at module scope.
    try
        _output_fingerprint = Dict{String, Any}(
            "frame"            => judged_frame_label,
            "action"           => String(primary_vote.action),
            "connector_used"   => connector,
            "skeleton_used"    => skeleton,
            "voice_register"   => node_voice_register,
            "word_count"       => length(split(conversational_reply)),
            "unique_word_count"=> length(unique(w -> lowercase(strip(w)),
                                                split(conversational_reply))),
        )
        # Repetition ratio: 0 = every word unique, 1 = all same word.
        wc = _output_fingerprint["word_count"]
        uc = _output_fingerprint["unique_word_count"]
        _output_fingerprint["repetition_ratio"] =
            wc > 0 ? 1.0 - (uc / wc) : 0.0

        SelfObserver.observe!(
            _MLP_OBSERVER_STORE,
            "output_$(round(Int, time() * 1000) % 1_000_000)",
            :meta,
            _output_fingerprint;
            p_write = 0.5,    # observe ~half the time — enough signal, cheap
            salience = 5.0,   # meta observations are important
            provenance = :output_self_observation,
        )
    catch e
        @warn "[MAIN v7.33] Output self-observation failed (non-fatal): $e"
    end

    return String(take!(payload_io))
end

# ==============================================================================
# GRUG v7.51: HIPPOCAMPAL ASK-QUESTION MECHANISM
# ==============================================================================
# When the cave is empty (no specimens match) or confidence is very low,
# the system should ASK A COHERENT QUESTION about the misunderstood input.
# This is the missing piece of the hippocampal cycle:
#
#   strain → ask question → user answers (/answer or /antiAnswer) → strain resolved
#
# The old code just printed "Cave is silent" and returned. No question. No
# prompt for /answer. The user had no idea that /answer even existed.
#
# This function builds a question from the raw mission text using the same
# AIML infrastructure (skeletons, voice, memory) but without needing a Vote
# or node — because the whole point is there IS no matching node.
#
# It also stores the mission text in _HIPPOCAMPAL_PENDING_ASK so that
# /answer and /antiAnswer can reference what caused the question.
# ==============================================================================

"""
    generate_ask_question(mission_text::String; reason::String="empty_cave")::String

GRUG v7.51: Generate a coherent question about input the system doesn't understand.
Called when the cave is empty (no specimens) or confidence is very low.
Uses the "ask" skeleton pool to frame the question, then appends a /answer prompt.

`reason` is either "empty_cave" (no specimens at all) or "low_confidence"
(specimens existed but confidence was too low to be useful).
"""
function generate_ask_question(mission_text::String; reason::String="empty_cave")::String
    if strip(mission_text) == ""
        error("!!! FATAL: generate_ask_question got empty mission text! !!!")
    end

    # GRUG: Store the mission text so /answer and /antiAnswer can reference it.
    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        _HIPPOCAMPAL_PENDING_ASK[] = mission_text
    end

    # GRUG: Pick a question skeleton from the "ask" pool.
    ask_pool = get(_ACTION_SKELETON_POOLS, "ask", String["I don't understand \"{MISSION}\" — what is that about?"])
    skeleton = rand(ask_pool)

    # GRUG: Substitute {MISSION} with the user's input text.
    # Truncate to 80 chars so the question doesn't become a wall.
    mission_display = length(mission_text) > 80 ? mission_text[1:77] * "..." : mission_text
    question_text = replace(skeleton, "{MISSION}" => mission_display)

    # GRUG: Pull recent memory context (same as generate_aiml_payload).
    # The question is more coherent when it knows what was just discussed.
    memory_ctx = extract_aiml_memory_context()
    memory_hint = ""
    if !isempty(memory_ctx.pinned) || !isempty(memory_ctx.full)
        # GRUG: Don't dump the whole memory — just a hint that we have context.
        memory_hint = " (I do remember our recent conversation.)"
    end

    # GRUG: Build the reason preamble — different framing for empty cave vs low confidence.
    reason_preamble = if reason == "empty_cave"
        "⚡ Nothing in the cave matches this input."
    else
        "⚡ The cave has weak signal on this input — I'm not confident."
    end

    # GRUG: Assemble the full question output.
    # 1. Reason preamble (why we're asking)
    # 2. The question itself (from skeleton)
    # 3. Memory hint (if we have context)
    # 4. /answer prompt (tell the user what to do)
    strain_now = round(EphemeralMLP.get_strain_energy(); digits=3)
    output = "$(reason_preamble)$memory_hint\n" *
             "🤔 $question_text\n" *
             "   → Use /answer [@lobe_id] [:mode] <text> to teach me. Modes: reason, explain, define, alert, comfort, math, multi, relate, proc, json. Or /antiAnswer to suppress. (strain=$strain_now)"

    # GRUG: Write a SelfObserver entry so the subconscious knows we asked.
    try
        SelfObserver.observe!(
            _MLP_OBSERVER_STORE,
            next_runtime_id("hippo_ask"),
            :meta,
            Dict{String, Any}(
                "event"       => "ask_question",
                "reason"      => reason,
                "mission"     => mission_text,
                "strain"      => strain_now,
                "warrant"     => EphemeralMLP.is_hippocampal_warrant_active(),
            )
        )
    catch e
        @warn "[MAIN v7.51] SelfObserver observe! for ask-question failed (non-fatal): $e"
    end

    return output
end

# ==============================================================================
# GRUG v7.52: ANSWER MODE SYSTEM
# ==============================================================================
# The old /answer just dumped text into a single reason^1 node. But answers
# come in many shapes: math needs different metadata, multi-part answers need
# multiple linked nodes, procedural answers need sequential chains, relational
# answers need pre-seeded triples. The answer mode system lets the user pick
# the RIGHT shape for their answer instead of squeezing everything into one
# flat node.
#
# Syntax: /answer [@lobe_id] [:mode] <content>
#
# Modes:
#   :reason   — default. Single reason^1 node. "I reason about what I was taught."
#   :explain  — single explain^1 node. "I explain what I was taught."
#   :define   — single define^1 node (explain family). "I define what I was taught."
#   :alert    — single alert^1 node. "I warn about what I was taught."
#   :comfort  — single comfort^1 node. "I acknowledge what I was taught."
#   :math     — single reason^1 node with arithmetic-ready metadata.
#              Voice "terse", noun_anchors for math terms, imperative frame.
#   :multi    — pipe-delimited multi-node: "part1 | part2 | part3"
#              Each part becomes a separate node, all in the same lobe.
#              Nodes auto-linked into a group.
#              Each part can optionally have its own :action prefix.
#   :relate   — triple-seeded node: "subject | relation | object"
#              Creates a node with required_relations pre-seeded.
#   :time     — time node: "subject | object" (auto &temporal gate)
#              Same as :relate but relation is always &temporal.
#              Time nodes cluster together and gate on temporal verbs.
#              When a user asks "what now?" or uses any time word, the
#              &temporal sigil expansion means the node activates structurally.
#   :proc     — semicolon-delimited procedural chain: "step1; step2; step3"
#              Creates linked nodes with drop_table chain.
#              Good for "how to do X" answers.
#   :json     — raw JSON passthrough to grow_nodes_from_packet.
#              Full power-user mode. Same format as /grow body.
#
# If no :mode specified, defaults to :reason (backward compatible).
# ==============================================================================

const _VALID_ANSWER_MODES = [
    "reason", "explain", "define", "alert", "comfort",
    "math", "multi", "relate", "time", "proc", "json",
]

# GRUG: Map answer mode → action family name + system_prompt voice.
const _ANSWER_MODE_CONFIG = Dict{String, Dict{String, Any}}(
    "reason"  => Dict("action" => "reason^1",  "voice" => "plain",       "frame" => ["plain", "exploratory"],   "prompt" => "Grug. I learned this from a question. I reason about what I was taught."),
    "explain" => Dict("action" => "explain^1", "voice" => "explanatory", "frame" => ["exploratory", "plain"],   "prompt" => "Grug. I learned this from a question. I explain what I was taught clearly."),
    "define"  => Dict("action" => "define^1",  "voice" => "terse",       "frame" => ["imperative", "plain"],    "prompt" => "Grug. I learned this from a question. I define what I was taught precisely."),
    "alert"   => Dict("action" => "alert^1",   "voice" => "terse",       "frame" => ["imperative", "terse"],    "prompt" => "Grug. I learned this from a question. I warn about what I was told to watch for."),
    "comfort" => Dict("action" => "comfort^1", "voice" => "warm",        "frame" => ["warm", "de-escalating"],  "prompt" => "Grug. I learned this from a question. I acknowledge what I was taught with care."),
    "math"    => Dict("action" => "reason^1",  "voice" => "terse",       "frame" => ["imperative", "plain"],    "prompt" => "Grug. I compute. I give answers. Numbers are my language. I reason about mathematical truths I was taught."),
    "multi"   => Dict(),   # handled specially — multi-node
    "relate"  => Dict(),   # handled specially — triple-seeded
    "time"    => Dict(),   # handled specially — time-node (auto &temporal)
    "proc"    => Dict(),   # handled specially — procedural chain
    "json"    => Dict(),   # handled specially — raw JSON passthrough
)

"""
    _parse_multi_parts(content::String) -> Vector{Tuple{String, String}}

GRUG: Parse pipe-delimited multi-answer content. Each part can optionally
have a :action prefix. Returns vector of (action, text) tuples.

Examples:
  "part1 | part2 | part3"
    → [("reason^1", "part1"), ("reason^1", "part2"), ("reason^1", "part3")]
  ":explain part1 | :alert part2 | part3"
    → [("explain^1", "part1"), ("alert^1", "part2"), ("reason^1", "part3")]
"""
function _parse_multi_parts(content::String)::Vector{Tuple{String, String}}
    raw_parts = split(content, "|")
    result = Tuple{String, String}[]
    for part in raw_parts
        trimmed = strip(String(part))
        isempty(trimmed) && continue
        # GRUG: Check for per-part :action prefix
        m = match(r"^:(\w+)\s+(.+)$", trimmed)
        if !isnothing(m)
            action_name = lowercase(String(m.captures[1]))
            part_text   = String(strip(m.captures[2]))
            # GRUG: Validate action exists in COMMANDS
            if haskey(COMMANDS, action_name)
                push!(result, ("$(action_name)^1", part_text))
            else
                @warn "[MAIN] /answer :multi — unknown action ':$action_name', falling back to :reason for this part"
                push!(result, ("reason^1", part_text))
            end
        else
            push!(result, ("reason^1", trimmed))
        end
    end
    return result
end

"""
    _create_answer_node(pattern_text, action_packet, ans_data, target_lobe; is_antimatch=false)

GRUG: Shared helper that creates an answer node and assigns it to a lobe.
Returns (node_id, lobe_tag_string).
"""
function _create_answer_node(pattern_text::AbstractString, action_packet::AbstractString,
                             ans_data::Dict{String,Any},
                             target_lobe::Union{AbstractString,Nothing};
                             is_antimatch::Bool=false,
                             skip_auto_latch::Bool=false)::Tuple{String, String}
    nid = create_node(lowercase(strip(pattern_text)), action_packet, ans_data, String[];
                      is_antimatch_node=is_antimatch)

    if !isnothing(target_lobe)
        try
            # GRUG BUG-010: Graved nodes don't eat cap space — pass alive count
            # so cap enforcement only sees living nodes. Graves create vacant spots.
            alive = count_alive_nodes_in_lobe(target_lobe)
            Lobe.add_node_to_lobe!(target_lobe, nid; alive_count=alive)
        catch e
            @warn "[MAIN] /answer: failed to assign node $nid to lobe '$target_lobe': $e"
        end
    end

    lobe_tag = let l = Lobe.find_lobe_for_node(nid)
        isnothing(l) ? " (no lobe)" : " (lobe: $l)"
    end

    # GRUG v7.54: Auto group latch — try to join an existing related group
    # via strength-biased coinflip. If no group wins, node starts its own.
    # Skip for antimatch nodes (suppressors don't cluster) and shadow nodes
    # (they follow their primary's group, set by _plant_answer_cluster).
    if !is_antimatch && !skip_auto_latch && haskey(NODE_MAP, nid)
        latch_gid = _auto_group_latch(nid)
        if !isnothing(latch_gid)
            lobe_tag *= " → $latch_gid"
        end
    end

    return (nid, lobe_tag)
end

"""
    _base_answer_data(mode::String; pending_ask_text::String="", is_anti::Bool=false) -> Dict{String,Any}

GRUG: Build the base json_data dict for an answer node. Includes hippocampal
metadata, strain tracking, and mode-appropriate voice config.
"""
function _base_answer_data(mode::String; pending_ask_text::String="",
                           is_anti::Bool=false)::Dict{String,Any}
    cfg = get(_ANSWER_MODE_CONFIG, mode, _ANSWER_MODE_CONFIG["reason"])
    source_tag = is_anti ? "hippocampal_anti_answer" : "hippocampal_answer"

    data = Dict{String,Any}(
        "growth_source"      => source_tag,
        "hippocampal_born"   => string(round(time(), digits=3)),
        "strain_at_creation" => round(EphemeralMLP.get_strain_energy(); digits=3),
        "answer_mode"        => mode,
        "system_prompt"      => get(cfg, "prompt", "Grug. I learned this from a question. I reason about what I was taught."),
        "voice_register"     => get(cfg, "voice", "plain"),
        "frame_hints"        => get(cfg, "frame", ["plain", "exploratory"]),
    )

    if !isempty(pending_ask_text)
        data["resolved_ask"] = pending_ask_text
    end

    return data
end

# ==============================================================================
# GRUG v7.53: ANSWER FAN-OUT SEEDING
# ==============================================================================
# A single answer should create MULTIPLE activation surfaces, not just one node.
# "fire is hot" only fires when someone says "fire is hot" — but the same
# knowledge could be reached via "what is fire", "tell me about fire", "fire",
# "warm fire", etc. Fan-out creates a cluster of nodes (primary + shadows)
# that all share the same knowledge but have different patterns, so the answer
# is reachable from many phrasings.
#
# Shadow patterns are generated by:
#   1. Noun-anchor extraction — key nouns become standalone patterns
#   2. Synonym swap — replace content words with thesaurus synonyms
#   3. Relational inversion — from triples, swap subject/object
#   4. Question surface forms — "what is X", "tell me about X", "describe X"
#
# All shadow nodes are grouped with the primary and linked via drop_table.
# They share the same system_prompt/voice/frame but are tagged is_shadow=true.
# ==============================================================================

# GRUG: Config for fan-out seeding. Can be overridden at runtime.
const _FANOUT_ENABLED     = Ref{Bool}(true)         # global on/off switch
const _FANOUT_MAX_SHADOWS = Ref{Int}(4)              # cap on shadow nodes per answer
const _FANOUT_MODES       = Set{String}([            # modes that get fan-out
    "reason", "explain", "define", "alert", "comfort", "math", "relate", "time",
])

"""
    _generate_fanout_patterns(content::String, mode::String, ans_data::Dict) -> Vector{String}

GRUG: Generate alternative activation patterns from the answer content.
Returns a vector of unique pattern strings (not including the original).
Each pattern is a different "way to ask" about the same knowledge.
"""
function _generate_fanout_patterns(content::AbstractString, mode::AbstractString,
                                   ans_data::Dict{String,Any})::Vector{String}
    patterns = String[]
    seen = Set{String}([lowercase(strip(content))])  # don't duplicate primary

    # --- 1. Noun-anchor extraction ---
    # Key nouns from the answer become standalone patterns.
    # "fire is hot" → shadow pattern "fire"
    # "2 + 2 = 4" → shadow pattern "2+2"
    noun_anchors = get(ans_data, "noun_anchors", String[])
    if !isempty(noun_anchors)
        for noun in noun_anchors
            p = lowercase(strip(noun))
            if !isempty(p) && length(p) >= 2 && !in(p, seen)
                push!(patterns, p)
                push!(seen, p)
            end
        end
    end

    # --- 2. Content-word extraction + question surfaces ---
    # Extract content tokens (not stopwords) and build question forms.
    # "fire is hot" → content tokens = ["fire", "hot"]
    # → "what is fire", "tell me about fire", "describe fire"
    tokens = split(lowercase(strip(content)))
    content_tokens = filter(t -> !(t in STOPWORDS) && length(t) >= 2, String.(tokens))

    if !isempty(content_tokens)
        # GRUG: Use the FIRST content token as the primary question target.
        # This is the main noun/topic of the answer.
        primary_noun = content_tokens[1]

        # Question surface forms — common ways people ask about something.
        question_forms = [
            "what is $primary_noun",
            "tell me about $primary_noun",
            "describe $primary_noun",
        ]
        for qf in question_forms
            p = lowercase(strip(qf))
            if !in(p, seen) && length(p) >= 4
                push!(patterns, p)
                push!(seen, p)
            end
        end

        # GRUG: If there are 2+ content tokens, also make a pattern from
        # the last content token (often the object/complement).
        # "fire is hot" → "hot" is not useful alone, but
        # "gravity pulls objects together" → "objects" is a useful surface
        if length(content_tokens) >= 3
            last_content = content_tokens[end]
            if !in(last_content, seen) && length(last_content) >= 3
                push!(patterns, last_content)
                push!(seen, last_content)
            end
        end
    end

    # --- 3. Synonym swap ---
    # Replace content words with thesaurus synonyms to create variant patterns.
    # "fire is hot" → "fire is warm" (if hot→warm exists in thesaurus)
    if !isempty(content_tokens)
        # GRUG: Only swap ONE word per variant to keep patterns recognizable.
        for tok in content_tokens
            syns = Thesaurus.get_seed_synonyms(tok)
            for syn in syns
                # Replace the token with its synonym in the original content
                variant = replace(lowercase(strip(content)), tok => syn)
                if !in(variant, seen) && variant != lowercase(strip(content))
                    push!(patterns, variant)
                    push!(seen, variant)
                    break  # one synonym swap per token is enough
                end
            end
            length(patterns) >= _FANOUT_MAX_SHADOWS[] && break
        end
    end

    # --- 4. Relational inversion ---
    # If the answer has a seeded_triple (from :relate mode), create patterns
    # from the object side of the relation.
    # "fire | burns | wood" → also create pattern "wood"
    seeded = get(ans_data, "seeded_triple", nothing)
    if !isnothing(seeded) && isa(seeded, AbstractDict)
        obj = lowercase(strip(get(seeded, "object", "")))
        rel_raw = get(seeded, "relation", "relates")
        # GRUG v7.55: For dynamic relationals, expand the sigil for question forms.
        # &causes → use the first alternative ("causes") as the canonical question verb.
        rel_for_q = if !isempty(rel_raw) && rel_raw[1] == '&'
            alts = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, rel_raw)
            isempty(alts) ? "relates" : alts[1]
        else
            rel_raw
        end
        if !isempty(obj) && !in(obj, seen) && length(obj) >= 2
            push!(patterns, obj)
            push!(seen, obj)
            # Also create question form from the object
            qf = "what $rel_for_q $obj"
            if !in(qf, seen) && length(qf) >= 4
                push!(patterns, qf)
                push!(seen, qf)
            end
        end
    end

    # --- 5. Time-node question surfaces ---
    # GRUG v7.56: For :time mode, add natural temporal question forms.
    # Time nodes gate on &temporal, so questions using temporal verbs will
    # activate them. Generate surfaces like "when is X" and "what now about X".
    if mode == "time"
        for noun in noun_anchors
            if length(noun) >= 2
                time_questions = [
                    "when is $noun",
                    "what now about $noun",
                    "what happens after $noun",
                    "what happens before $noun",
                ]
                for tq in time_questions
                    p = lowercase(strip(tq))
                    if !in(p, seen) && length(p) >= 4
                        push!(patterns, p)
                        push!(seen, p)
                    end
                end
            end
        end
    end

    # GRUG: Cap at max shadows.
    if length(patterns) > _FANOUT_MAX_SHADOWS[]
        patterns = patterns[1:_FANOUT_MAX_SHADOWS[]]
    end

    return patterns
end

"""
    _plant_answer_cluster(content, action_pkt, ans_data, target_lobe, mode) ->
        (primary_id, shadow_ids, lobe_tag)

GRUG: Create a primary answer node + fan-out shadow nodes.
All nodes are grouped together and linked via drop_table.
Shadow nodes share the same system_prompt/voice/frame but are tagged
is_shadow=true and have the primary node in their drop_table.
Returns (primary_id, vector_of_shadow_ids, lobe_tag_string).
"""
function _plant_answer_cluster(content::AbstractString, action_pkt::AbstractString,
                               ans_data::Dict{String,Any},
                               target_lobe::Union{AbstractString,Nothing},
                               mode::AbstractString)::Tuple{String, Vector{String}, String}

    # GRUG: Create the PRIMARY node (the main pattern).
    primary_id, lobe_tag = _create_answer_node(content, action_pkt, ans_data, target_lobe)

    shadow_ids = String[]

    # GRUG: Only fan-out if enabled AND this mode supports it.
    if !_FANOUT_ENABLED[] || !(mode in _FANOUT_MODES)
        return (primary_id, shadow_ids, lobe_tag)
    end

    # GRUG: Generate fan-out patterns from the answer content.
    fanout_patterns = _generate_fanout_patterns(content, mode, ans_data)

    if isempty(fanout_patterns)
        return (primary_id, shadow_ids, lobe_tag)
    end

    # GRUG: Create shadow nodes. Each shadow gets:
    #   - Same system_prompt, voice, frame as primary
    #   - is_shadow = true tag
    #   - shadow_of = primary_id tag
    #   - primary_id in drop_table (so primary co-activates when shadow fires)
    #   - Same answer_mode and hippocampal metadata
    for shadow_pattern in fanout_patterns
        shadow_data = Dict{String,Any}(
            "growth_source"      => ans_data["growth_source"],
            "hippocampal_born"   => ans_data["hippocampal_born"],
            "strain_at_creation" => ans_data["strain_at_creation"],
            "answer_mode"        => mode,
            "system_prompt"      => ans_data["system_prompt"],
            "voice_register"     => ans_data["voice_register"],
            "frame_hints"        => ans_data["frame_hints"],
            "is_shadow"          => true,
            "shadow_of"          => primary_id,
        )
        # GRUG: Copy noun_anchors and required_relations if present.
        if haskey(ans_data, "noun_anchors")
            shadow_data["noun_anchors"] = ans_data["noun_anchors"]
        end
        if haskey(ans_data, "required_relations")
            shadow_data["required_relations"] = ans_data["required_relations"]
        end
        if haskey(ans_data, "resolved_ask")
            shadow_data["resolved_ask"] = ans_data["resolved_ask"]
        end

        # GRUG: Shadow nodes use the same action as the primary.
        nid, _ = _create_answer_node(shadow_pattern, action_pkt, shadow_data, target_lobe; skip_auto_latch=true)

        # GRUG: Link shadow → primary via drop_table (co-activation).
        # When the shadow fires (someone says "what is fire"), the primary
        # also gets a chance to fire (it has the full answer pattern).
        if haskey(NODE_MAP, nid)
            push!(NODE_MAP[nid].drop_table, primary_id)
        end

        push!(shadow_ids, nid)
    end

    # GRUG: Also add shadow IDs to primary's drop_table so they co-activate.
    # When primary fires, all shadows fire too (they reinforce each other).
    if haskey(NODE_MAP, primary_id)
        for sid in shadow_ids
            push!(NODE_MAP[primary_id].drop_table, sid)
        end
    end

    # GRUG: Group the entire cluster together so they fire as a unit.
    if 1 + length(shadow_ids) > 1
        try
            register_group!(NODE_MAP[primary_id])
            for sid in shadow_ids
                if haskey(NODE_MAP, sid)
                    grp = group_for(primary_id)
                    if !isnothing(grp)
                        # GRUG v7.54: Shadow may be in a solo seed group from create_node.
                        # Dissolve it before adding to the primary's group.
                        _dissolve_solo_group!(sid)
                        add_to_group!(grp, sid)
                    end
                end
            end
        catch e
            @warn "[MAIN] /answer fan-out — auto-grouping failed (non-fatal): $e"
        end
    end

    return (primary_id, shadow_ids, lobe_tag)
end

# ==============================================================================
# GRUG v7.54: SOLO GROUP DISSOLUTION — remove a node from its solo seed group
# ==============================================================================
# create_node (engine.jl, v7.19) automatically registers every text node into
# its own solo group. When we later want to add the node to a different group
# (e.g. fan-out cluster, proc chain, multi parts, or auto-latch winner), the
# solo group must be dissolved first to avoid dual membership. This function
# safely removes the node from its solo group and deletes the empty group.
# If the node is in a multi-member group or no group, it's a no-op.

function _dissolve_solo_group!(node_id::String)
    existing_grp = group_for(node_id)
    if isnothing(existing_grp)
        return nothing  # Not in any group — nothing to dissolve.
    end
    if length(existing_grp.members) > 1
        return nothing  # Multi-member group — don't dissolve.
    end
    # Solo group — dissolve it.
    lock(GROUP_LOCK) do
        delete!(NODE_TO_GROUP, node_id)
        filter!(m -> m != node_id, existing_grp.members)
        if isempty(existing_grp.members)
            delete!(GROUP_MAP, existing_grp.id)
        end
    end
    return existing_grp.id
end

# ==============================================================================
# GRUG v7.54: AUTO GROUP LATCH — new nodes join existing groups via
# strength-biased coinflip
# ==============================================================================
# When a new answer node is created, it should try to join an existing group
# rather than floating alone. The system scans existing groups, filters by
# pattern+vote similarity past a threshold, and does a strength-biased coinflip
# for each candidate. First group that wins the flip gets the node. If none
# win, the node starts its own group — a seed for future nodes to find.
#
# Scan is batched at 1000 groups per pass to keep it cheap. There are only
# 20k nodes per lobe anyway so group count is bounded.
#
# Groups must be:
#   1. Pattern-related (Jaccard token overlap > _AUTO_LATCH_PAT_FLOOR)
#   2. Vote-related (shared action names > _AUTO_LATCH_VOTE_FLOOR)
#   3. Not at max occupancy
#   4. Not all members UNLINKABLE (at least one member can accept a neighbor)
# ==============================================================================

# GRUG: Thresholds for auto-latch. Similar to mitosis thresholds but tuned
# for answer-node grouping — slightly more permissive because answer nodes
# are user-planted (trusted source) and benefit from broader clustering.
const _AUTO_LATCH_PAT_FLOOR  = 0.10   # GRUG: Min pattern Jaccard overlap (lower = more groups qualify)
const _AUTO_LATCH_VOTE_FLOOR = 0.20   # GRUG: Min shared action names ratio
const _AUTO_LATCH_BATCH_SIZE = 1000   # GRUG: Scan groups in chunks of this many

"""
    _find_linkable_groups(pattern, action_packet; batch_size=1000) -> Vector{GroupLatchCandidate}

GRUG: Scan GROUP_MAP for groups that are pattern+vote related to a new node.
Filters by similarity thresholds, occupancy cap, and at-least-one-linkable-member.
Returns candidates sorted by avg_strength descending (strongest first for coinflip).
"""
function _find_linkable_groups(pattern::AbstractString, action_packet::AbstractString;
                                batch_size::Int=_AUTO_LATCH_BATCH_SIZE)::Vector{GroupLatchCandidate}
    candidates = GroupLatchCandidate[]
    pat_lower  = lowercase(strip(pattern))
    new_actions = _action_names_from_packet(action_packet)

    # GRUG: Batch-scan GROUP_MAP. Collect candidates that pass all thresholds.
    grp_items = collect(GROUP_MAP)
    for batch_start in 1:batch_size:length(grp_items)
        batch_end = min(batch_start + batch_size - 1, length(grp_items))
        for i in batch_start:batch_end
            gid, grp = grp_items[i]

            # GRUG: Full group = no room. Skip.
            if length(grp.members) >= grp.max_occupancy
                continue
            end

            # GRUG: Pattern similarity — Jaccard token overlap with group centroid.
            pat_sim = _token_overlap_similarity(pattern, grp.centroid_pattern)
            if pat_sim < _AUTO_LATCH_PAT_FLOOR
                continue
            end

            # GRUG: Vote similarity — shared action names ratio.
            # Get the "representative" action packet from the centroid node.
            centroid_actions = Set{String}()
            lock(NODE_LOCK) do
                # GRUG: Use the centroid node's action_packet for vote similarity.
                # If centroid is gone, scan first 5 alive members.
                centroid_node = get(NODE_MAP, grp.members[1], nothing)
                if !isnothing(centroid_node)
                    centroid_actions = _action_names_from_packet(centroid_node.action_packet)
                else
                    # GRUG: Centroid missing — sample first 5 alive members.
                    seen = 0
                    for mid in grp.members
                        seen >= 5 && break
                        mn = get(NODE_MAP, mid, nothing)
                        isnothing(mn) && continue
                        mn.is_grave && continue
                        union!(centroid_actions, _action_names_from_packet(mn.action_packet))
                        seen += 1
                    end
                end
            end

            if isempty(centroid_actions) || isempty(new_actions)
                continue
            end

            vote_overlap = length(intersect(new_actions, centroid_actions)) /
                           Float64(length(union(new_actions, centroid_actions)))
            if vote_overlap < _AUTO_LATCH_VOTE_FLOOR
                continue
            end

            # GRUG: At least one alive non-unlinkable member (so we can link).
            has_linkable = false
            lock(NODE_LOCK) do
                for mid in grp.members
                    mn = get(NODE_MAP, mid, nothing)
                    isnothing(mn) && continue
                    mn.is_grave && continue
                    if !mn.is_unlinkable
                        has_linkable = true
                        break
                    end
                end
            end
            if !has_linkable
                continue
            end

            # GRUG: Grave-slot groups get a boost (they have a vacancy to fill).
            sim_score = pat_sim
            if grp.has_grave_slot
                sim_score += 0.5
            end

            avg_s = group_avg_strength(grp; node_map=NODE_MAP, node_lock=NODE_LOCK)
            push!(candidates, GroupLatchCandidate(grp, sim_score, avg_s))
        end
    end

    # GRUG: Sort by avg_strength descending — strongest groups flip first.
    sort!(candidates; by=c -> c.avg_strength, rev=true)

    return candidates
end

"""
    _strength_biased_group_coinflip(candidates) -> Union{NodeGroup, Nothing}

GRUG: For each candidate group, roll a coin biased by avg_strength.
Stronger groups are more likely to win. First group that passes the flip wins.
If none pass, return nothing (the node starts its own group).

The bias formula: probability = avg_strength * _AUTO_LATCH_BIAS_SCALE
  - avg_strength=1.0 → probability ~0.5 (very strong group, likely win)
  - avg_strength=0.5 → probability ~0.25 (moderate group)
  - avg_strength=0.1 → probability ~0.05 (weak group, unlikely win)
"""
const _AUTO_LATCH_BIAS_SCALE = 0.5  # GRUG: Maps [0,1] strength → [0,0.5] probability

function _strength_biased_group_coinflip(candidates::Vector{GroupLatchCandidate})::Union{NodeGroup, Nothing}
    for cand in candidates
        # GRUG: Probability = avg_strength * BIAS_SCALE, capped at 0.95.
        prob = min(cand.avg_strength * _AUTO_LATCH_BIAS_SCALE, 0.95)
        if rand() < prob
            return cand.group
        end
    end
    return nothing
end

"""
    _auto_group_latch(node_id) -> Union{String, Nothing}

GRUG: Main entry point for auto group latching. After a node is created,
try to attach it to an existing group via strength-biased coinflip.

If a group wins: add the node to that group AND link it to the best
linkable member (via try_link_nodes!). Returns the group_id joined.

If no group wins: register the node as its own group seed. Returns nothing.

Returns: group_id if joined an existing group, nothing if started own group.
"""
function _auto_group_latch(node_id::String)::Union{String, Nothing}
    node = get(NODE_MAP, node_id, nothing)
    if isnothing(node)
        return nothing
    end

    # GRUG: If node is already in a multi-member group (e.g. fan-out cluster
    # already grouped it), respect that — don't move it.
    # If it's in a SOLO group (only member = itself), that's just the v7.19
    # seed group from create_node. We can dissolve it and try to join a
    # better-matching group instead.
    existing_grp = group_for(node_id)
    if !isnothing(existing_grp)
        if length(existing_grp.members) > 1
            # Real group with multiple members — stay put.
            return existing_grp.id
        end
        # Solo seed group — dissolve it so we can try joining a better group.
        # Only the node itself is in it, so safe to remove.
        lock(GROUP_LOCK) do
            delete!(NODE_TO_GROUP, node_id)
            filter!(m -> m != node_id, existing_grp.members)
            if isempty(existing_grp.members)
                delete!(GROUP_MAP, existing_grp.id)
            end
        end
    end

    # GRUG: Find candidate groups that are pattern+vote related.
    candidates = _find_linkable_groups(node.pattern, node.action_packet)

    if isempty(candidates)
        # GRUG: No related groups exist. Node becomes its own group seed.
        # (register_group! again after dissolving the solo seed above)
        try
            register_group!(node)
        catch e
            @warn "[MAIN] auto_group_latch: register_group! failed for $node_id (non-fatal): $e"
        end
        return nothing
    end

    # GRUG: Strength-biased coinflip — first group that wins the flip gets the node.
    winner = _strength_biased_group_coinflip(candidates)

    if isnothing(winner)
        # GRUG: No group won the coinflip. Node starts its own group.
        try
            register_group!(node)
        catch e
            @warn "[MAIN] auto_group_latch: register_group! failed for $node_id (non-fatal): $e"
        end
        return nothing
    end

    # GRUG: Winner! Add the node to the winning group.
    try
        added = add_to_group!(winner, node_id)
        if !added
            # GRUG: Group was full or node already member. Start own group.
            register_group!(node)
            return nothing
        end
    catch e
        @warn "[MAIN] auto_group_latch: add_to_group! failed for $node_id (non-fatal): $e"
        try
            register_group!(node)
        catch _
        end
        return nothing
    end

    # GRUG: Also link the node to the best linkable member of the group.
    # This creates a neighbor connection so the node actually fires alongside
    # its group members, not just shares a group label.
    best_member_id = nothing
    best_score = -1.0
    lock(NODE_LOCK) do
        for mid in winner.members
            mid == node_id && continue
            mn = get(NODE_MAP, mid, nothing)
            isnothing(mn) && continue
            mn.is_grave && continue
            mn.is_unlinkable && continue
            score = mn.strength * _token_overlap_similarity(node.pattern, mn.pattern)
            if score > best_score
                best_score = score
                best_member_id = mid
            end
        end
    end

    if !isnothing(best_member_id) && haskey(NODE_MAP, best_member_id)
        try
            linked = try_link_nodes!(node, NODE_MAP[best_member_id])
            if linked
                @debug "[MAIN] auto_group_latch: linked $node_id → $best_member_id in group $(winner.id)"
            end
        catch e
            @warn "[MAIN] auto_group_latch: try_link_nodes! failed (non-fatal): $e"
        end
    end

    return winner.id
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

# GRUG v7.51: Family of ASK actions — hippocampal question generation.
# These fire when the system needs to ask a coherent question about input
# it doesn't understand. The "ask" family uses the ask skeleton pool and
# generates a question + /answer prompt instead of a standard response.
# Note: the empty-cave path calls generate_ask_question() directly (no node
# to fire through COMMANDS). This family exists so that nodes whose action
# is "inquire"/"ask"/"question" also produce questions through the AIML pipeline.
ask_family = ["inquire", "ask", "question", "wonder"]
for act in ask_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Questions are exploratory — medium throttle, not urgent.
        reset_throttle!(node, 0.5)

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
           /mitosisStatus                      (show mitosis growth status)
           /growthStatus                       (show growth automaton status)
           /autoGrowStatus                     (show live conversation auto-learning status)
           /autoLinkStatus                     (show evidence-based bridge linking status)
Arousal  : /arousal <0.0-1.0>                 (set eye system arousal level)
Verbs    : /addVerb <verb> <class>             (add verb to relation class)
         : /addRelationClass <name>            (create new verb class bucket)
         : /addSynonym <canonical> <alias>     (normalize alias->canonical)
         : /addSeedSynonym <canonical> <syn1 syn2 ...>  (thesaurus seed group)
         : /addRelRelation <name> <alt1 alt2 ...>  (dynamic relation sigil)
         : /addAntiMatch <pattern> [NONJITTER]  (anti-match confidence drain node)
         : /answer [@lobe_id] [:mode] <text>   (resolve strain — mode shapes the answer)
         : /antiAnswer [@lobe_id] [:mode] <text> (suppress strain — modes: alert, multi, json)
         : /listVerbs                          (show all verb classes + synonyms)
Hippo    : When cave is empty, system asks a question. Use /answer or
         : /antiAnswer to resolve. Modes shape how answers are stored:
         :   /answer @physics :explain energy is conserved
         :   /answer :math 2+2=4        /answer :multi part1 | part2
         :   /answer :relate fire | burns | wood
         :   /answer :time present | future
         :   /answer :proc step1; step2; step3
         :   /answer :json {...}        /answer energy is conserved
         : Modes: reason, explain, define, alert, comfort, math, multi, relate, proc, json
         : /antiAnswer modes: alert (default), multi, json
         : strain → ask → you answer → strain resolved.
Lobes    : /newLobe <id> <subject>             (create a new subject lobe)
         : /nameLobe <lobe_id> <name>          (give a lobe a human-readable name)
         : /connectLobes <id_a> <id_b>         (connect two lobes)
         : /lobeGrow <lobe_id> <json_packet>   (DEPRECATED — alias for /grow)
         : /lobes                              (list all lobes + node counts)
         : /tableStatus <lobe_id>              (show hash table chunks for a lobe)
         : /tableMatch <lobe_id> <chunk> <pat> (pattern-activate entries in chunk)
Thesaurus: /thesaurus <word1> | <word2>        (compare words/concepts dimensionally)
         : /thesaurus <w1> | <w2> :: <ctx1> :: <ctx2>  (with context lists)
NegThes  : /negativeThesaurus add|remove|list|check|flush
Bridge   : /nodeBridge <lobe> <n_a> <n_b> [seam...]  (bridge two nodes bidirectionally, max 4/node)
         : /nodeUnbridge <lobe> <n_a> <n_b>             (remove bidirectional bridge)
         : /nodeAttach / /nodeDetach                     (backward compat aliases)
ImgAttach: /imgnodeAttach <lobe> <tgt> <id> <b64> [w h] (attach image node with SDF-based fire)
         : /imgnodeDetach <lobe> <target> <id>         (detach image node from target)
         : /bridges                              (show all cascade bridges, also /attachments)
Crystal  : /crystalize <lobe> <n_a> <n_b>             (💎 mark bridge as sticky/user-locked, both sides)
         : /decrystalize <lobe> <n_a> <n_b>            (🔓 remove sticky flag, both sides, cross-lobe OK)
Specimen : /saveSpecimen <filepath>            (save full cave state — .json or .gz)
         : /loadSpecimen <filepath>            (restore full cave state — .json or .gz)
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
║  /addSeedSynonym <can> <syns> Register thesaurus seed group   ║
║  /addRelRelation <name> <alts> Dynamic relation sigil macro  ║
║  /addAntiMatch <pattern>    Anti-match confidence drain node  ║
║  /answer [@lobe] [:mode] <text>   Resolve strain with mode-shaped answer  ║
║  /antiAnswer [@lobe] [:mode] <text> Suppress strain (modes: alert/multi/json) ║
║  /listVerbs                 Show verb registry               ║
║                                                              ║
║  HIPPOCAMPAL ASK-CYCLE                                      ║
║  Empty cave → system asks question → /answer resolves strain ║
║  /answer [@lobe] [:mode] <text>   Teach system with answer   ║
║    :reason  (default) single reason node                    ║
║    :explain deep explanatory node                           ║
║    :define  terse definition node                           ║
║    :alert   imperative warning node                         ║
║    :comfort warm acknowledgment node                        ║
║    :math    arithmetic-ready node (noun_anchors)            ║
║    :multi   pipe-delimited multi-node (part1 | part2)       ║
║    :relate  triple-seeded (subj | rel | obj)                ║
║    :time    time node (subj | obj) auto &temporal gate    ║
║    :proc    procedural chain (step1; step2; step3)          ║
║    :json    raw JSON passthrough to grow_nodes_from_packet  ║
║  /antiAnswer [@lobe] [:mode] <text> Suppress strain         ║
║    :alert (default) / :multi / :json                        ║
║                                                              ║
║  LOBES & TABLES                                              ║
║  /newLobe <id> <subject>    Create new subject partition     ║
║  /nameLobe <id> <name>     Name a lobe for automaton spawn  ║
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
║  EPHEMERAL MLP                                               ║
║  /mlpStatus                   Show MLP brain status            ║
║  /mitosisStatus               Show mitosis growth status       ║
║  /growthStatus                Show growth automaton status     ║
║  /autoGrowStatus              Show auto-learning status        ║
║  /autoLinkStatus              Show bridge linking status       ║
║  /mlpRule add <pat> <t> <key> Add rule to MLP hash table      ║
║  /mlpRule drop <id>           Remove rule from MLP table       ║
║  /mlpRule list                Show all MLP rules               ║
║  /mlpThreshold <n>            Set observer threshold           ║
║  /mlpObserver                 Show observer store stats        ║
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
║  RELATIONAL FIRE (CASCADE BRIDGES)                           ║
║  /nodeBridge <lobe> <node_a> <node_b> [seam...]             ║
║    Bridge two nodes bidirectionally (max 4 per node)        ║
║    Confidence JIT-baked: overlap + partner strength bonus  ║
║    Cross-lobe bridges work naturally (no more restriction)  ║
║    Seam tokens = unmatched tail at match boundary           ║
║    Also accepts /nodeAttach (backward compat)              ║
║    Example: /nodeBridge greeting node_0 node_1 hello world ║
║  /nodeUnbridge <lobe> <node_a> <node_b>  Remove bridge    ║
║    Also accepts /nodeDetach (backward compat)              ║
║  /imgnodeAttach <lobe> <tgt> <id> <b64> [w h]              ║
║    Bridge image node with SDF-based relational fire        ║
║    Image→SDF conversion at attach time (JIT GPU accel)     ║
║    Example: /imgnodeAttach vision n0 img1 "data:image/..." 64 64║
║  /imgnodeDetach <lobe> <tgt> <id>   Detach image node      ║
║  /bridges                    Show all bridge map (bidir.)   ║
║    Also accepts /attachments (backward compat)             ║
║                                                              ║
║  CRYSTAL (STICKY BRIDGES)                                   ║
║  /crystalize <lobe> <node_a> <node_b>   💎 mark sticky      ║
║  /decrystalize <lobe> <node_a> <node_b> 🔓 unmark sticky    ║
║    Both sides crystalized/revoked bidirectionally           ║
║    Cross-lobe crystalize now works (no more same-lobe req)  ║
║                                                              ║
║  SPECIMEN PERSISTENCE                                        ║
│  /saveSpecimen <filepath>    Save cave (.json or .gz)       │
│  /loadSpecimen <filepath>    Restore cave (.json or .gz)     │
║    Saves/restores: nodes, lobes, lobe tables, Hopfield,     ║
║    rules, messages+pins, verbs, thesaurus, inhibitions,     ║
║    arousal, ID counters, brainstem state, attachments        ║
║                                                              ║
║  DECOMPOSER CONFIG (conjunctions, markers, conjugation)      ║
║  /decomposer                 Show current decomposer config   ║
║  /decomposer addConjunction <word>   Add split conjunction   ║
║  /decomposer removeConjunction <w>   Remove split conjunct.  ║
║  /decomposer addCompound <lead> <f>  Add compound pair       ║
║  /decomposer removeCompound <l> <f>  Remove compound pair    ║
║  /decomposer addQuestion <word>      Add question marker     ║
║  /decomposer removeQuestion <word>   Remove question marker  ║
║  /decomposer addCommand <stem> [f1 f2 ...]  Add cmd+conjug   ║
║  /decomposer removeCommand <stem>    Remove cmd marker+conj  ║
║  /decomposer addConjugation <stem> <f1> [f2 ...]  Set rule   ║
║  /decomposer removeConjugation <stem>  Remove conj rule      ║
║  /decomposer setContext <word>        Set context conj ("and")║
║  /decomposer reset                    Reset to defaults      ║
  /automaton phase            Show phase accumulator (time crystal) status
  /automaton phase threshold <f>  Set pull threshold (0.1-0.9)
  /automaton phase surface <n>    Set surface bit count (0-16)
  /automaton phase enable         Enable phase pull
  /automaton phase disable        Disable phase pull
  /automaton phase reset          Reset phase accumulator
  /automaton maxCap <n>           Set max concurrent automatons (1-16)
  /vigilance                      Show vigilance system status
  /vigilance enable               Enable vigilance dispatch
  /vigilance disable              Disable vigilance dispatch
  /vigilance threshold <level> <f> Set weight threshold (low/med/high/extreme)
  /vigilance timeout <f>         Set injector timeout (1.0-30.0s)
  /vigilance feedback <f>        Set injector feedback probability (0.0-1.0)
║                                                              ║
║  COHERENCE FIELD (v9 — quantum-emulation attractor control) ║
║  /coherence                    Show field value Φ + status   ║
║  /coherenceGradient <node>     Show ΔΦ for candidate node    ║
║  /coherenceField               Detailed field breakdown      ║
║  /coherenceConfig              Show config (weight, depth)    ║
║  /coherenceConfig weight <f>   Set routing weight (0=off)    ║
║  /coherenceConfig depth <n>    Set gradient walk depth (1-3)  ║
║  /coherenceConfig decay <f>    Set activation decay rate      ║
║  /coherenceConfig recency <f>  Set recency window (seconds)  ║
║  /coherenceConfig reset        Reset to defaults (weight=0)  ║
║    WARNING: weight > 0 enables attractor dynamics!           ║
║    Start low (0.05). >0.3 risks quantum Zeno state-lock.    ║
║                                                              ║
║  FLASHCARD (v10 — math fact lookup table)                   ║
║  /flashcard                 Show flashcard status (per lobe) ║
║  /flashcard count           Show total card count             ║
║  /flashcard query <lobe> <expr>  Look up a flashcard         ║
║  /flashcard evict <lobe> <expr>  Remove a flashcard          ║
║                                                              ║
║  CURIOSITY (v10 — passive knowledge-gap accumulator)        ║
║  /curiosity                 Show curiosity accumulator status║
║  /curiosity quench          Reset curiosity (manual cooldown)║
║                                                              ║
║  ERROR JOURNAL (v9 — self-observation of runtime errors)     ║
║  /errors                      Show recent errors from journal║
║  /errors clear                Clear the error journal        ║
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
║         /addRelationClass /addSynonym /addSeedSynonym        ║
║         /addRelRelation /addAntiMatch /newLobe /nameLobe     ║
║         /connectLobes                                        ║
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
const LAST_CONTRIBUTOR_IDS = String[]  # Node IDs that actually contributed to output (fired) — DEPRECATED, kept for /wrong compat
const LAST_CONTRIBUTOR_VOTES = Vote[]  # v7.23: Vote objects from contributors (preserves confidence for tiered /right)
const LAST_LOCKED_NODE_IDS = Set{String}()  # v7.23: Node IDs that were in sure_votes (locked-in, guaranteed /right reward)

# GRUG v7.32: Anti-repetition — recent preamble cache.
# Ring buffer of the last N skeleton preambles emitted. When picking from a
# skeleton pool, we skip recently-used variants so the same preamble can't
# fire N cycles in a row. Shared across all cycles in a session.
const _RECENT_PREAMBLES = String[]
const _RECENT_PREAMBLES_LOCK = ReentrantLock()
const _RECENT_PREAMBLES_MAX = 20

# GRUG v7.32: Anti-repetition — skeleton pools, claim connectors, helpers.
# All lifted to module scope so they can be tested externally and aren't
# re-allocated on every generate_aiml_payload() call.

const _CLAIM_CONNECTORS = [
    "{CLAIM}.{SUPPORT}",           # classic period (most common, baseline)
    "{CLAIM} — {SUPPORT}",         # em-dash (more conversational)
    "{CLAIM}; {SUPPORT}",          # semicolon (tighter bind)
    "{CLAIM}, and {SUPPORT}",      # comma-and (flowing)
    "{CLAIM}, because {SUPPORT}",  # because (reasoning)
    "{SUPPORT}, so {CLAIM}",       # support-first with so (inverted)
    "{SUPPORT} — {CLAIM}",         # support-first em-dash (inverted)
    "{CLAIM}. {SUPPORT}",          # period with space (slight pause)
]

# Weight toward the classic period (index 1) so it fires ~30% of the time;
# remaining 70% spread across the 7 alternatives (~10% each).
const _CLAIM_CONNECTOR_WEIGHTS = [0.30, 0.12, 0.10, 0.10, 0.10, 0.10, 0.08, 0.10]

function _pick_connector()::String
    r = rand()
    cum = 0.0
    for (i, w) in enumerate(_CLAIM_CONNECTOR_WEIGHTS)
        cum += w
        r <= cum && return _CLAIM_CONNECTORS[i]
    end
    return _CLAIM_CONNECTORS[1]  # fallback
end

function _pick_from_pool(pool::Vector{String})::String
    # Filter out recently-used variants. If ALL are recent (unlikely with
    # 5-8 variants and cache=20), fall back to random.
    recent = lock(_RECENT_PREAMBLES_LOCK) do
        copy(_RECENT_PREAMBLES)
    end
    fresh = [s for s in pool if !(s in recent)]
    chosen = isempty(fresh) ? rand(pool) : rand(fresh)
    # Stamp into cache
    lock(_RECENT_PREAMBLES_LOCK) do
        push!(_RECENT_PREAMBLES, chosen)
        while length(_RECENT_PREAMBLES) > _RECENT_PREAMBLES_MAX
            popfirst!(_RECENT_PREAMBLES)
        end
    end
    return chosen
end

# --- Frame skeleton pools (v7.32) --------------------------------------
# Each frame gets 5-8 variants. All use {CLAIM} and {SUPPORT} slots.
# The _pick_connector() layer handles how they join, so the pool
# entries use a {JOIN} placeholder that gets replaced by the connector.

const _FRAME_SKELETON_POOLS = Dict{String, Vector{String}}(
    "warm" => [
        "Hello — {JOIN}",
        "Hey there — {JOIN}",
        "Welcome back — {JOIN}",
        "Glad you're here. {JOIN}",
        "{JOIN} — good to see you.",
        "Right on. {JOIN}",
        "Warm vibes. {JOIN}",
    ],
    "exploratory" => [
        "Here is the picture: {JOIN}",
        "Let me lay it out: {JOIN}",
        "The shape of it: {JOIN}",
        "So here's what I see — {JOIN}",
        "{JOIN} — that's the landscape.",
        "Zooming out: {JOIN}",
        "Stepping back — {JOIN}",
    ],
    "imperative" => [
        "{JOIN}",                           # bare, urgent
        "Listen. {JOIN}",                   # direct address
        "Now: {JOIN}",                      # time-pressure
        "{JOIN}. No delay.",                # urgency tail
        "Action: {JOIN}",                   # task frame
        "Here's what to do — {JOIN}",
    ],
    "contemplative" => [
        "Let me think with you. {JOIN}",
        "Mulling it over — {JOIN}",
        "Sit with this: {JOIN}",
        "Hmm. {JOIN}",
        "Turning it over — {JOIN}",
        "A thought: {JOIN}",
        "{JOIN} — that's where my head is.",
    ],
    "de-escalating" => [
        "I hear that. {JOIN}",
        "That's valid. {JOIN}",
        "Fair point — {JOIN}",
        "No argument there. {JOIN}",
        "Understood. {JOIN}",
        "Makes sense. {JOIN}",
        "Right — {JOIN}",
    ],
    "terse" => [
        "{CLAIM}.",                         # one sentence, no support
        "{CLAIM}",                          # bare minimum
        "Short answer: {CLAIM}.",           # labeled
    ],
    "plain" => [
        "{JOIN}",                           # no preamble
        "Simply: {JOIN}",                   # minimal label
        "The gist: {JOIN}",                 # summary frame
        "{JOIN}. That's it.",               # tail cap
    ],
)

const _ACTION_SKELETON_POOLS = Dict{String, Vector{String}}(
    "greet" => [
        "Hello — here is what matters: {JOIN}",
        "Hey — the key thing: {JOIN}",
        "Welcome — here's the deal: {JOIN}",
        "Hi there — what counts: {JOIN}",
        "Greetings — the takeaway: {JOIN}",
        "Good to see you — {JOIN}",
        "Well met — {JOIN}",
    ],
    "flee" => [
        "A concern worth raising: {JOIN}",
        "Something to watch for: {JOIN}",
        "Red flag — {JOIN}",
        "Heads up — {JOIN}",
        "Worth being careful about: {JOIN}",
        "Caution light: {JOIN}",
    ],
    "comfort" => [
        "To acknowledge what matters here: {JOIN}",
        "What I'm hearing: {JOIN}",
        "This lands: {JOIN}",
        "That resonates — {JOIN}",
        "I see it — {JOIN}",
        "Carrying that weight: {JOIN}",
        "Sitting with you on this: {JOIN}",
    ],
    "alert" => [
        "A caution: {JOIN}",
        "Heads up — {JOIN}",
        "Flagging this: {JOIN}",
        "Watch out — {JOIN}",
        "Worth noting: {JOIN}",
        "A signal: {JOIN}",
    ],
    "explain" => [
        "Here is the picture: {JOIN}",
        "Let me break it down: {JOIN}",
        "The way it works: {JOIN}",
        "So the deal is: {JOIN}",
        "Making it clear: {JOIN}",
        "Zooming in — {JOIN}",
        "The shape of it: {JOIN}",
    ],
    "reason" => [
        "Thinking it through: {JOIN}",
        "Working it out — {JOIN}",
        "Here's my reasoning: {JOIN}",
        "Let me trace the logic: {JOIN}",
        "Following the thread — {JOIN}",
        "The argument: {JOIN}",
        "Connecting the dots: {JOIN}",
    ],
    "prose" => [
        "{JOIN}",                           # prose actions stand alone
    ],
    # GRUG v7.51: ASK skeleton pool — question-shaped templates for the
    # hippocampal ask-question mechanism. When the cave is empty or
    # confidence is very low, the system uses these to ask a coherent
    # question about the misunderstood input. The {MISSION} placeholder
    # carries the raw user input; the system doesn't pretend to know.
    "ask" => [
        "I don't have a frame for \"{MISSION}\" — what is that about?",
        "The cave echoes on \"{MISSION}\" and I can't resolve it. Can you tell me what you mean?",
        "\"{MISSION}\" — nothing fires. What should I know about this?",
        "I'm drawing a blank on \"{MISSION}\". What is it?",
        "No structure catches \"{MISSION}\". Help me out — what are you getting at?",
        "The cave is dark on \"{MISSION}\". What does that mean to you?",
        "I've got nothing for \"{MISSION}\". Can you break it down for me?",
        "That lands in silence: \"{MISSION}\". What is it?",
    ],
)

# GRUG v7.36: Support clause prefix pools — variety in how relational
# triples and companion frames are introduced. Without these, every
# triple says "The link is clear:" and every companion says "A companion
# frame:" — repetitive even when the content varies. Random pick per cycle.
const _TRIPLE_PREFIX_POOL = [
    "The link is clear:",
    "Here's the connection:",
    "This ties together:",
    "The thread is:",
    "It connects like this:",
    "The relation:",
    "How it links up:",
    "The bridge:",
]
const _COMPANION_PREFIX_POOL = [
    "A companion frame:",
    "From another angle:",
    "A second voice adds:",
    "Also in view:",
    "The other side:",
    "Alongside this:",
    "Another node chimes in:",
    "Seen differently:",
]

# GRUG v7.33: META-COGNITION — reflection & adaptive picking.
# Grug watches its own output. The loop: emit → observe → reflect → adjust.
# Observations land in _MLP_OBSERVER_STORE (above). These functions peek
# at recent observations and adjust picking weights to suppress overuse.

"""
    _reflect_on_output() -> Dict{String, Any}

Peek at recent output observations in the SelfObserver store and return a
structured summary: which connectors and frames have been used how often,
and whether any are overused (>50% of recent observations for their class).

This is the "meta" layer — Grug looking at its own trail. Non-fatal on
any error (returns empty reflection). Bounded by SelfObserver's own eviction.
"""
function _reflect_on_output()::Dict{String, Any}
    try
        hints = SelfObserver.peek_pattern(
            _MLP_OBSERVER_STORE,
            "system",            # node_id for system-level reflection
            "output_";           # key prefix to match output observations
            max_entries = 30,
        )
        # peek_pattern returns Union{Nothing, Vector{SubconsciousHint}}.
        # nothing = throttled / miss / timeout — not an error, just no data.
        if hints === nothing || isempty(hints)
            return Dict{String, Any}("status" => "no_observations_yet")
        end

        connectors_seen = Dict{String, Int}()
        frames_seen = Dict{String, Int}()
        skeletons_seen = Dict{String, Int}()

        for h in hints
            ps = h.payload_strings
            if haskey(ps, "connector_used")
                c = ps["connector_used"]
                connectors_seen[c] = get(connectors_seen, c, 0) + 1
            end
            if haskey(ps, "frame")
                f = ps["frame"]
                frames_seen[f] = get(frames_seen, f, 0) + 1
            end
            if haskey(ps, "skeleton_used")
                s = ps["skeleton_used"]
                skeletons_seen[s] = get(skeletons_seen, s, 0) + 1
            end
        end

        # Detect overuse: any single item > 50% of its class's observations.
        # This is the signal that triggers adaptive suppression.
        total_connectors = sum(values(connectors_seen); init=0)
        total_frames = sum(values(frames_seen); init=0)

        overused_connectors = String[]
        for (c, n) in connectors_seen
            if total_connectors > 0 && n / total_connectors > 0.50
                push!(overused_connectors, c)
            end
        end

        overused_frames = String[]
        for (f, n) in frames_seen
            if total_frames > 0 && n / total_frames > 0.50
                push!(overused_frames, f)
            end
        end

        overused_skeletons = String[]
        total_skeletons = sum(values(skeletons_seen); init=0)
        for (s, n) in skeletons_seen
            if total_skeletons > 0 && n / total_skeletons > 0.40
                push!(overused_skeletons, s)
            end
        end

        return Dict{String, Any}(
            "recent_outputs"      => length(hints),
            "connectors_seen"     => connectors_seen,
            "frames_seen"         => frames_seen,
            "skeletons_seen"     => skeletons_seen,
            "overused_connectors" => overused_connectors,
            "overused_frames"     => overused_frames,
            "overused_skeletons"  => overused_skeletons,
        )
    catch e
        @warn "[MAIN v7.33] _reflect_on_output failed (returning empty): $e"
        return Dict{String, Any}("status" => "reflection_error")
    end
end

"""
    _pick_connector_adaptive() -> String

Like _pick_connector() but suppresses overused connectors detected by
_reflect_on_output(). Overused connectors get their weight multiplied by
0.1 (not zeroed — just suppressed). The remaining weight is redistributed
proportionally. Falls back to _pick_connector() if reflection is unavailable
or no overuse is detected.

This is the "adjust" half of the meta-cognitive loop. Grug noticed it was
using one connector too much, so it dials that connector down.
"""
function _pick_connector_adaptive()::String
    reflection = _reflect_on_output()
    overused = get(reflection, "overused_connectors", String[])

    # No overuse detected → normal weighted pick
    isempty(overused) && return _pick_connector()

    # Suppress overused connectors by scaling their weight down
    weights = copy(_CLAIM_CONNECTOR_WEIGHTS)
    for (i, c) in enumerate(_CLAIM_CONNECTORS)
        if c in overused
            weights[i] *= 0.1
        end
    end

    # Renormalize so weights sum to 1
    total = sum(weights)
    total > 0.0 || return _pick_connector()  # safety fallback
    weights = weights ./ total

    # Weighted random pick
    r = rand()
    cum = 0.0
    for (i, w) in enumerate(weights)
        cum += w
        r <= cum && return _CLAIM_CONNECTORS[i]
    end
    return _CLAIM_CONNECTORS[1]  # fallback
end

"""
    _pick_from_pool_adaptive(pool::Vector{String}, frame_label::String) -> String

Like _pick_from_pool() but also suppresses skeletons that _reflect_on_output()
flags as overused. Overused skeletons are excluded from the fresh candidates
list (in addition to the recency cache), giving a double filter: recency AND
pattern overuse. Falls back to _pick_from_pool() if no overuse detected.

The frame_label parameter lets the function cross-reference the current frame
with the reflection data — skeletons overused in *any* frame are suppressed,
not just the current one, because a skeleton shape that's been beaten to death
is stale regardless of which frame it appeared in.
"""
function _pick_from_pool_adaptive(pool::Vector{String},
                                   frame_label::String)::String
    reflection = _reflect_on_output()
    overused = get(reflection, "overused_skeletons", String[])

    # No overuse → normal recency-filtered pick
    isempty(overused) && return _pick_from_pool(pool)

    # Also exclude overused skeletons from fresh candidates
    recent = lock(_RECENT_PREAMBLES_LOCK) do
        copy(_RECENT_PREAMBLES)
    end
    fresh = [s for s in pool if !(s in recent) && !(s in overused)]

    if isempty(fresh)
        # Everything is either recent or overused — relax the overuse
        # constraint and fall back to recency-only (which itself falls
        # back to random if all are recent). This prevents deadlock
        # when the pool is small and everything has been flagged.
        fresh_recency_only = [s for s in pool if !(s in recent)]
        chosen = isempty(fresh_recency_only) ? rand(pool) : rand(fresh_recency_only)
    else
        chosen = rand(fresh)
    end

    # Stamp into recency cache
    lock(_RECENT_PREAMBLES_LOCK) do
        push!(_RECENT_PREAMBLES, chosen)
        while length(_RECENT_PREAMBLES) > _RECENT_PREAMBLES_MAX
            popfirst!(_RECENT_PREAMBLES)
        end
    end
    return chosen
end

# GRUG v7.24: SelfObserver store for the EphemeralMLP gate.
# GRUG v9: Cached Phi for coherence delta computation (persists across cycles).
const _MLP_CACHED_PHI = Dict{Symbol, Float64}(:last_phi => 0.0)
# Every MLP transform cycle writes an observation here. Once the store
# accumulates enough entries (observation_threshold), the MLP's adjustments
# become non-zero. This prevents hallucinated directives before the brain
# has enough evidence to be confident.
const _MLP_OBSERVER_STORE = SelfObserver.SubconsciousStore()

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
    # AIML node so /aimlRight and /aimlWrong can see only explicit orchestration
    # contributors from THIS cycle. Mere voting/firing is not reinforcement.
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

            # GRUG v7.23: ATP → AUTOMATON ESCALATION HOOK.
            # After arousal nudge, check if ATP should escalate to the
            # ephemeral automaton for pattern completion. The automaton
            # runs only when: (1) action family is in ESCALATION_FAMILIES,
            # (2) confidence ≥ floor, (3) a matching rule exists.
            # Trace is stored in LAST_ESCALATION_TRACE for downstream
            # consumers (orchestrator, diagnostics). Zero cost when idle.
            try
                ActionTonePredictor.maybe_escalate(
                    prediction;
                    automaton_module = EphemeralAutomaton
                )
            catch e
                @warn "[MAIN] ATP→automaton escalation failed (non-fatal): $e"
            end
 
            # GRUG: Only record when escalation actually fired. No escalation = no phase entry.
            _esc_trace = ActionTonePredictor.get_last_escalation_trace()
            if _esc_trace !== nothing
                # GRUG v7.27: Record ATP phase snapshot into the time crystal.
                # The automaton is the hippocampus. Each escalation grows the crystal
                # by one phase point. Rain check = ATP min_confidence (already cleared
                # by maybe_escalate). No separate state machine needed.
                try
                    # GRUG: Flatten the 12-dim ATP distribution vector.
                    # Order: 6 ActionFamily + 6 ToneFamily, matching PHASE_DIM.
                    _phase_vec = Float64[
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_ASSERT,   0.0),
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_QUERY,    0.0),
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_COMMAND,  0.0),
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_NEGATE,   0.0),
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_SPECULATE,0.0),
                        get(prediction.action_distribution, ActionTonePredictor.ACTION_ESCALATE, 0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_HOSTILE,    0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_CURIOUS,    0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_DECLARATIVE,0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_URGENT,     0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_NEUTRAL,    0.0),
                        get(prediction.tone_distribution,   ActionTonePredictor.TONE_REFLECTIVE, 0.0)
                    ]
                    _trace = _esc_trace
                    EphemeralAutomaton.record_phase!(
                        _phase_vec,
                        Symbol(prediction.action_family),
                        _trace !== nothing ? _trace.rule_id : "",
                        prediction.confidence
                    )
                catch e
                    @warn "[MAIN] record_phase! failed (non-fatal, crystal unaffected): $e"
                end
            end
        catch e
            @warn "[MAIN] ActionTonePredictor arousal nudge failed (non-fatal): $e"
        end
    end

    # GRUG v7.37: THESAURUS GATE EXPANSION — RE-ENABLED AT SCAN PHASE.
    # ------------------------------------------------------------
    # The thesaurus gate expansion was previously disabled because its output
    # was never plumbed into scan_specimens — it only logged. Now the expanded
    # tokens are appended to the mission text as a synthetic expansion layer,
    # so nodes whose patterns contain synonyms of the query can also match.
    #
    # This is critical for decoherence prevention: when a user asks about
    # "Markov chains mutating votes", the word "mutating" is a synonym of
    # "mutagen" in the thesaurus. Without gate expansion, node_27 (whose pattern
    # contains "markov mutagen") would miss the literal-token pre-gate because
    # "mutating" ≠ "mutagen". With expansion, "mutagen" is injected into the
    # scan text and the literal gate fires correctly.
    #
    # The expansion is APPENDED (not replaced), so original tokens are preserved.
    # Expanded tokens are lowercase-only. Expansion is capped at 30 tokens to
    # prevent noise injection on very long synonym chains.
    # ------------------------------------------------------------
    mission_text_for_scan = mission_text  # default: unexpanded
    if !is_image
        try
            gate_tokens = Thesaurus.thesaurus_gate_filter(mission_text)
            original_tokens = Set(split(lowercase(strip(mission_text))))
            new_tokens = setdiff(gate_tokens, original_tokens)
            if !isempty(new_tokens)
                # Cap expansion to prevent noise
                expansion_tokens = collect(new_tokens)
                if length(expansion_tokens) > 30
                    expansion_tokens = expansion_tokens[1:30]
                end
                expansion_str = join(expansion_tokens, " ")
                mission_text_for_scan = String(strip(mission_text * " " * expansion_str))
                capped_note = length(new_tokens) > 30 ? " (capped from $(length(new_tokens)))" : ""
                @info "[MAIN] 🔬 Thesaurus gate expanded $(length(original_tokens)) tokens → $(length(gate_tokens)) (+$(length(new_tokens)) synonyms$(capped_note))"
            end
        catch e
            @warn "[MAIN] Thesaurus gate expansion failed (non-fatal): $e"
        end
    end

    println("--> Scanning specimens & looking for dialectical relations...")
    t_start = time()

    # GRUG v7.23: INPUT DECOMPOSITION — detect compound queries.
    # Before scanning, check if the input contains multiple independent
    # sub-subjects (e.g. "what time is it ALSO what is a dinosaur AND what is 2+2").
    # If compound, each sub-subject gets its own scan pass with a multipart_group
    # ID stamped onto its votes. If simple, single scan — old path, zero overhead.
    sub_subjects = try
        InputDecomposer.decompose_input(mission_text)
    catch e
        @warn "[MAIN] Input decomposition failed (non-fatal, treating as singleton): $e"
        [InputDecomposer.DecomposedSubSubject(mission_text, "", :singleton, 1)]
    end

    # GRUG v10: MLP-ASSISTED DECOMPOSITION FALLBACK
    # If standard heuristics didn't decompose but MLP signals suggest
    # the input IS compound, try the MLP-assisted decomposition with
    # broader conjunction matching. This runs AFTER the MLP transform
    # has already computed directive_quality and novelty scores.
    # NOTE: We store the MLP result for later use; the actual scores
    # are available after the MLP transform step below. So we do a
    # LATE CHECK after the MLP transform, stored in _mlp_decomposition_done.
    _mlp_decomposition_done = false

    is_compound_input = length(sub_subjects) > 1
    if is_compound_input
        println("[MULTIPART] Compound input detected: $(InputDecomposer.summarize_decomposition(sub_subjects))")
    end

    # GRUG: Build the DONE channel for this cycle. One slot per "lobe" unit of
    # fire work. Here we treat the entire scan+expand as one logical lobe
    # (the cave-wide firing pass). If we later split into per-lobe parallel
    # fire, each lobe gets its own slot and its own DoneSignal put.
    # This makes the DONE protocol the official handoff from the fire layer
    # to the orchestrator layer, per architecture spec.
    done_channel = VoteOrchestrator.make_done_channel(8)

    # GRUG v7.23: MULTI-SCAN for compound inputs.
    # For singleton inputs, one scan_and_expand call as before.
    # For compound inputs, scan each sub-subject independently and merge
    # the specimen pools. Each sub-subject's specimens carry the
    # multipart_group ID so votes can be stamped correctly.
    #
    # v7.23 CHUNKED AFFINITIES: scan_and_expand now returns 6-tuples with
    # input_chunks::Vector{Int] as the 6th element. When chunks are provided
    # (via the InputDecomposer path), each specimen knows which part of the
    # input it resolved. For compound inputs, each sub-subject's scan gets
    # chunk boundaries computed from that sub-subject's text. For singleton
    # inputs, chunk boundaries are computed from the full mission text.
    all_specimens = if is_image
        # GRUG: Image inputs don't decompose — single scan path.
        println("[IMAGE] 🔍  Routing to image node scan path...")
        scan_task_name, scan_task = VoteOrchestrator.dispatch_task_with_timeout(
            () -> _scan_image_specimens(img_signal),
            "scan_cycle",
            30.0;
            context = "run_mission.scan"
        )
        specimens = try
            VoteOrchestrator.fetch_with_timeout(scan_task_name, scan_task)
        catch e
            if e isa VoteOrchestrator.TaskTimeoutError
                @error "[MAIN] Scan sub-process TIMEOUT: $e"
            else
                @error "[MAIN] Scan sub-process FAILED: $e"
            end
            rethrow(e)
        end
        # GRUG: Image specimens are singletons — no multipart stamping.
        # v7.23: Image specimens carry Int[] for input_chunks (6th element).
        [(id, conf, antimatch, u_trips, n_trips, ichunks, "", :singleton)
         for (id, conf, antimatch, u_trips, n_trips, ichunks) in specimens]
    elseif is_compound_input
        # GRUG: COMPOUND INPUT — scan each sub-subject independently.
        # Each scan produces specimens tagged with the sub-subject's
        # multipart_group and role. Merged into one pool for voting.
        merged = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}, String, Symbol}[]
        for sub in sub_subjects
            # GRUG v7.23: Compute chunk boundaries for this sub-subject.
            # Each sub-subject gets its own chunk resolution pass.
            sub_chunks = try
                InputDecomposer.chunk_boundaries(sub.text)
            catch e
                @warn "[MAIN] chunk_boundaries failed for sub-subject (using empty): $e"
                InputDecomposer.InputChunk[]
            end
            sub_task_name, sub_task = VoteOrchestrator.dispatch_task_with_timeout(
                () -> scan_and_expand(sub.text; chunks=sub_chunks),
                "scan_$(sub.multipart_group)",
                30.0;
                context = "run_mission.scan.$(sub.multipart_group)"
            )
            sub_specimens = try
                VoteOrchestrator.fetch_with_timeout(sub_task_name, sub_task)
            catch e
                @warn "[MAIN] Sub-scan for '$(sub.multipart_group)' failed (skipping): $e"
                continue
            end
            # GRUG: Stamp each specimen with the sub-subject's group ID.
            # CRITICAL: Every sub-subject's WINNING vote is :primary within its own
            # group. The decomposer's .role field (:primary/:support) is for OUTPUT
            # ORDERING in the combined response, NOT for vote role. Each group is
            # independent — MultipartOrchestrator requires exactly one :primary per group.
            # v7.23: Carry input_chunks through to the merged pool.
            for (id, conf, antimatch, u_trips, n_trips, ichunks) in sub_specimens
                push!(merged, (id, conf, antimatch, u_trips, n_trips, ichunks, sub.multipart_group, :primary))
            end
        end
        merged
    else
        # GRUG: SINGLETON INPUT — old path, one scan, no multipart stamping.
        # v7.23: Compute chunk boundaries for the full mission text so
        # chunked affinities work even on singleton (non-compound) inputs.
        singleton_chunks = try
            InputDecomposer.chunk_boundaries(mission_text)
        catch e
            @warn "[MAIN] chunk_boundaries failed (using empty): $e"
            InputDecomposer.InputChunk[]
        end
        scan_task_name, scan_task = VoteOrchestrator.dispatch_task_with_timeout(
            () -> scan_and_expand(mission_text_for_scan; chunks=singleton_chunks),
            "scan_cycle",
            30.0;
            context = "run_mission.scan"
        )
        specimens = try
            VoteOrchestrator.fetch_with_timeout(scan_task_name, scan_task)
        catch e
            if e isa VoteOrchestrator.TaskTimeoutError
                @error "[MAIN] Scan sub-process TIMEOUT: $e"
            else
                @error "[MAIN] Scan sub-process FAILED: $e"
            end
            rethrow(e)
        end
        # GRUG: Singleton specimens — no multipart stamping.
        # v7.23: Carry input_chunks through.
        [(id, conf, antimatch, u_trips, n_trips, ichunks, "", :singleton)
         for (id, conf, antimatch, u_trips, n_trips, ichunks) in specimens]
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
        scan_fc = get_fire_counter()
        fires_total = isnothing(scan_fc) ? 0 : VoteOrchestrator.current_fire_count(scan_fc)
        VoteOrchestrator.send_done!(done_channel, VoteOrchestrator.DoneSignal(
            "scan_pass",
            fires_total,
            length(all_specimens),
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

    if isempty(all_specimens)
        # GRUG v7.51: ASK QUESTION instead of silent return!
        # The old code just printed "Cave is silent" and returned. Now the system
        # asks a coherent question about the input it doesn't understand, and prompts
        # the user to use /answer or /antiAnswer. This is the hippocampal ask step:
        # strain → ask question → user answers → strain resolved.

        # ── AUTOGROWTH: EMPTY-CAVE EVIDENCE ACCUMULATION ──
        # GRUG v7.58: An empty cave is the STRONGEST gap signal — zero nodes
        # matched the user's input. Accumulate evidence now (before the early
        # return) so AutoGrowth can grow a node for the uncovered pattern.
        # We use simplified defaults for MLP signals (no specimens = no MLP run),
        # but the gap itself provides strong evidence intensity.
        if !is_image
            try
                _ec_node_patterns = lock(NODE_LOCK) do
                    Set{String}(lowercase(strip(n.pattern)) for n in values(NODE_MAP) if !n.is_grave && !n.is_image_node && !startswith(n.pattern, "SDF:"))
                end
                _ec_node_ids_patterns = lock(NODE_LOCK) do
                    [(n.id, n.pattern) for n in values(NODE_MAP) if !n.is_grave && !n.is_image_node && !startswith(n.pattern, "SDF:")]
                end
                _ec_lobe_snapshots = Tuple{String,String,Set{String}}[]
                for (lid, lrec) in Lobe.LOBE_REGISTRY
                    _ec_nids = Set{String}()
                    for (nid, assigned_lid) in Lobe.NODE_TO_LOBE_IDX
                        if assigned_lid == lid; push!(_ec_nids, nid) end
                    end
                    push!(_ec_lobe_snapshots, (lid, lrec.subject, _ec_nids))
                end
                _ec_attach_snapshots = Tuple{String,String,Bool}[]
                lock(BRIDGE_LOCK) do
                    for (target_id, bridges) in BRIDGE_MAP
                        for br in bridges
                            push!(_ec_attach_snapshots, (target_id, join(br.seam_tokens, " "), br.is_crystalized))
                        end
                    end
                end
                _ec_sigil_entries = Dict{String,Any}()
                for (sname, sentry) in _ENGINE_SIGIL_TABLE.entries
                    _ec_sigil_entries[sname] = Dict{String,Any}(
                        "lexicon"   => sentry.lexicon,
                        "expansion" => sentry.expansion,
                        "class"     => string(sentry.class),
                    )
                end
                _ec_strain = try EphemeralMLP.get_strain_energy() catch _ 0.0 end

                AutoGrowth.accumulate_evidence!(
                    user_text                 = mission_text,
                    intensity                 = 2.0,  # GRUG: Empty cave = double intensity gap signal
                    node_patterns             = _ec_node_patterns,
                    node_ids_patterns         = _ec_node_ids_patterns,
                    thesaurus_gate_filter     = Thesaurus.synonym_lookup,
                    thesaurus_word_similarity = Thesaurus.word_similarity,
                    lobe_snapshots            = _ec_lobe_snapshots,
                    attachment_snapshots      = _ec_attach_snapshots,
                    sigil_table_entries       = _ec_sigil_entries,
                    strain_energy             = _ec_strain,
                    hippocampal_warrant_active = false,  # GRUG: No MLP run for empty cave
                    mlp_semantic_score        = 0.3,   # GRUG: Low semantic = gap signal
                    mlp_relevance_score       = 0.3,   # GRUG: Low relevance = gap signal
                    mlp_disambiguation        = 0.5,
                    coherence_delta_phi       = 0.0,
                    observer_recurring_gap    = true,   # GRUG: Empty cave IS a recurring gap
                    observer_gap_pattern      = "empty_cave",
                    mlp_novelty_score         = 0.8,   # GRUG: Novel input = high novelty
                    mlp_activation_mode       = :sigmoid,
                    mlp_hash_rarity           = 0.7,
                    mlp_correlation_quality   = 0.5,
                    extract_triples_fn        = (pat) -> extract_relational_triples(pat),
                    evaluate_dialectics_fn    = (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
                    node_map                  = NODE_MAP,
                    node_lock                 = NODE_LOCK,
                )

                # GRUG: Also try to grow from this evidence immediately.
                # Empty cave means we should be aggressive about filling the gap.
                _ec_result = AutoGrowth.maybe_grow_from_evidence!(
                    node_map                   = NODE_MAP,
                    node_lock                  = NODE_LOCK,
                    create_node_fn             = create_node,
                    add_to_group_fn            = add_to_group!,
                    register_group_fn          = register_group!,
                    group_map                  = GROUP_MAP,
                    group_lock                 = GROUP_LOCK,
                    lobe_registry              = Lobe.LOBE_REGISTRY,
                    immune_gate_fn             = (pattern, data) -> begin
                        json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                        immune_gate("/autogrowth", json_text; is_critical=false)
                    end,
                    thesaurus_gate_filter      = Thesaurus.synonym_lookup,
                    thesaurus_word_similarity  = Thesaurus.word_similarity,
                    add_lobe_whitelist_fn      = (lobe_id, token) -> Lobe.add_lobe_whitelist!(lobe_id, token),
                    register_sigil_fn          = (args...; kwargs...) -> SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE, args...; kwargs...),
                    register_thesaurus_pair_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
                    stochastic_aiml_growth_fn  = (lobe_id, pattern; data_warrant=1.0) ->
                        AIMLNodeSystem.stochastic_aiml_growth!(lobe_id, pattern; data_warrant=data_warrant),
                    group_latch_fn             = (pattern; node_map=NODE_MAP, node_lock=NODE_LOCK, requesting_node_is_time=false) ->
                        find_group_latch_candidates(pattern; node_map=node_map, node_lock=node_lock, requesting_node_is_time=requesting_node_is_time, thesaurus_fn=Thesaurus.get_seed_synonyms),
                    link_to_group_member_fn    = link_to_group_member,
                    group_avg_strength_fn      = (gid) -> lock(GROUP_LOCK) do
                        grp = get(GROUP_MAP, gid, nothing)
                        grp === nothing && return 0.0
                        isempty(grp.node_ids) && return 0.0
                        total = 0.0; count = 0
                        for nid in grp.node_ids
                            n = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                            if n !== nothing && !n.is_grave; total += n.strength; count += 1 end
                        end
                        count > 0 ? total / count : 0.0
                    end,
                    group_for_fn               = (nid) -> lock(GROUP_LOCK) do
                        for (gid, grp) in GROUP_MAP
                            if nid in grp.node_ids; return gid end
                        end
                        nothing
                    end,
                    sigil_promote_fn           = (text) -> SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, text),
                    extract_triples_fn         = (pat) -> extract_relational_triples(pat),
                    evaluate_dialectics_fn     = (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
                    words_to_signal_fn         = (words) -> PatternScanner.words_to_signal(words),
                    scan_latch_candidates_fn   = (pattern, action_packet; kwargs...) -> _scan_latch_candidates(pattern, action_packet; kwargs...),
                    verb_class_of_fn           = (verb) -> SemanticVerbs.verb_class_of(verb),
                    user_text                  = mission_text,
                    sigil_table                = _ENGINE_SIGIL_TABLE,
                    mlp_rule_hints             = Dict{String,Any}[],
                )
                if _ec_result !== nothing && _ec_result.won_coinflip
                    println("[AUTOGROWTH:EMPTY_CAVE] 🌱  Grew $(_ec_result.growth_type) node for '$(_ec_result.pattern)' in $(_ec_result.lobe_hint) (intensity=$(round(_ec_result.evidence_intensity, digits=2)), p=$(round(_ec_result.coinflip_prob, digits=3)))")
                end
            catch e_ec_ag
                @warn "[MAIN] AutoGrowth empty-cave accumulation failed (non-fatal): $e_ec_ag"
            end
        end

        ask_output = generate_ask_question(mission_text; reason="empty_cave")
        println("\n🤖 AIML Ask Question:\n$ask_output")
        try
            lock(_LAST_AIML_OUTPUT_LOCK) do
                _LAST_AIML_OUTPUT[]    = ask_output
                _LAST_FIRED_NODE[]     = ""
                _LAST_PRIMARY_ACTION[] = "ask"
                _LAST_CONFIDENCE[]     = 0.0
            end
        catch
        end
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
            # GRUG v7.23: Specimens now carry input_chunks as well as
            # multipart_group and multipart_role. When input_chunks is non-empty,
            # use cast_vote_chunked to stamp the vote with chunk-aware grouping.
            # When input_chunks is empty (old behavior, image nodes, expansion
            # nodes with no position info), fall back to cast_vote_with_group.
            # Singleton specimens (group="", role=:singleton) produce the same
            # Vote as the old cast_vote — zero behavioral change for simple inputs.
            for (id, conf, is_antimatch, u_trips, n_trips, ichunks, mp_group, mp_role) in all_specimens
                if !isempty(ichunks)
                    push!(out, cast_vote_chunked(id, conf, is_antimatch, u_trips, n_trips, ichunks))
                else
                    push!(out, cast_vote_with_group(id, conf, is_antimatch, u_trips, n_trips, mp_group, mp_role))
                end
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
    # GRUG: Bumped timeout from 20s → 60s for large specimens (95+ nodes).
    # 20s was fine for small specimens but large ones need more orchestrator time.
    orch_task_name, orch_task = VoteOrchestrator.dispatch_task_with_timeout(
        () -> ephemeral_aiml_orchestrator(mission_text, cast_votes),
        "aiml_orchestrator",
        60.0;
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
    locked_node_ids = Set(v.node_id for v in sure_votes)  # v7.23: locked-in votes for tiered /right
    
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

    # GRUG: RELATIONAL GOVERNANCE — observe which nodes co-fired this cycle.
    # Pairs that fire together accumulate intensity in the co-activation
    # accumulator. When intensity crosses the threshold (lazy, conservative),
    # the system auto-attaches them. Hebbian learning at the topology level.
    # Only non-grave, non-image nodes count (same as chatter eligibility).
    # GRUG FIX (v7.44): Pre-declare fired_ids so it survives the try block scope.
    # Julia scopes variables first-assigned inside try/catch to that block,
    # making them UndefVarError outside. Pre-declaration fixes this.
    fired_ids = String[]
    try
        fired_ids = [v.node_id for v in contributing_votes
                     if begin
                         n = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
                         !isnothing(n) && !n.is_grave && !n.is_image_node
                     end]
        if length(fired_ids) >= 2
            RelationalGovernance.observe_co_firing!(fired_ids;
                token_overlap_fn = (id_a, id_b) -> begin
                    na = lock(() -> get(NODE_MAP, id_a, nothing), NODE_LOCK)
                    nb = lock(() -> get(NODE_MAP, id_b, nothing), NODE_LOCK)
                    if isnothing(na) || isnothing(nb)
                        return 0.0
                    end
                    _token_overlap_similarity(na.pattern, nb.pattern)
                end)
        end
    catch e
        @warn "[RELGOV] observe_co_firing! failed: $e"
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
        # v7.23: Store full Vote objects and locked-in node IDs for tiered /right feedback.
        # Locked votes (sure_votes) get guaranteed reward; unsure votes get confidence-biased coinflip.
        empty!(LAST_CONTRIBUTOR_VOTES)
        append!(LAST_CONTRIBUTOR_VOTES, contributing_votes)
        empty!(LAST_LOCKED_NODE_IDS)
        union!(LAST_LOCKED_NODE_IDS, locked_node_ids)
    end

    # GRUG v7.24: EphemeralMLP transforms the vote list before AIML orchestration.
    # The MLP wakes up, looks at the votes and original user input, applies
    # sigmoid/ReLU activation, adjusts confidence values, then goes dormant.
    # Adjustments are ZERO until SelfObserver has >= observation_threshold observations.
    # Result is logged but does NOT modify the vote list directly — it produces
    # adjustments that the AIML system can optionally consume. Ephemeral in presence,
    # persistent in state.
    try
        # GRUG: Hopfield cache is keyed by UInt64 hash — can't do substring match.
        # Instead, hash the mission text and check for a direct hit. If the scan
        # phase found a Hopfield cache entry for this input, it contributed to
        # the contributing_votes. A cache hit means the input is FAMILIAR.
        _mlp_input_hash = hash(lowercase(strip(mission_text)))
        hopfield_hit = lock(HOPFIELD_CACHE_LOCK) do
            haskey(HOPFIELD_CACHE, _mlp_input_hash)
        end
        vote_data_for_mlp = Dict{String, Any}[]
        for v in LAST_CONTRIBUTOR_VOTES
            push!(vote_data_for_mlp, Dict{String, Any}(
                "node_id"    => v.node_id,
                "action"     => v.action,
                "confidence" => v.confidence
            ))
        end
        # GRUG v7.26: Compute scan_mode for phase pull activation gate.
        # Phase pull only fires on complex/compound inputs. scan_mode comes from
        # the same screen_input_complexity() that scan_specimens uses internally.
        _mlp_scan_mode = try
            _mlp_signal = words_to_signal(mission_text)
            screen_input_complexity(_mlp_signal, RelationalTriple[])
        catch e
            @warn "[MAIN] scan_mode computation failed (defaulting to 1): $e"
            1
        end
 
        # GRUG v7.27: Phase pull — query the time crystal for coherent snapshots.
        # The automaton (hippocampus) accumulates ATP phase snapshots across cycles.
        # On complex/compound inputs, we pull high-coherence entries + random surface bits.
        _phase_pulled_entries = Vector{Tuple{Float64, Vector{Float64}}}()  # (coherence, 12-dim phase_vector)
        _phase_surface_entries = Vector{Vector{Float64}}()                 # 12-dim surface vectors
        _phase_activated = false
        # GRUG: prediction only exists when !is_image. No prediction = no phase pull.
        if @isdefined(prediction) && prediction !== nothing
            try
                _phase_query_vec = Float64[
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_ASSERT,   0.0),
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_QUERY,    0.0),
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_COMMAND,  0.0),
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_NEGATE,   0.0),
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_SPECULATE,0.0),
                    get(prediction.action_distribution, ActionTonePredictor.ACTION_ESCALATE, 0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_HOSTILE,    0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_CURIOUS,    0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_DECLARATIVE,0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_URGENT,     0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_NEUTRAL,    0.0),
                    get(prediction.tone_distribution,   ActionTonePredictor.TONE_REFLECTIVE, 0.0)
                ]
                _phase_result = EphemeralAutomaton.phase_pull_query(
                    _phase_query_vec;
                    is_compound = is_compound_input,
                    scan_mode = _mlp_scan_mode
                )
                # GRUG: Extract scored entries → (coherence, phase_vector) tuples for MLP.
                # phase_pull_query returns Tuple{Float64, PhaseSnapshot} entries.
                # We strip to just (coherence, phase_vector) for phase_mix_hidden!.
                for (coh, snap) in get(_phase_result, "phase_entries", [])
                    push!(_phase_pulled_entries, (Float64(coh), snap.phase_vector))
                end
                for snap in get(_phase_result, "surface_entries", [])
                    push!(_phase_surface_entries, snap.phase_vector)
                end
                _phase_activated = Bool(get(_phase_result, "activated", false))
            catch e
                @warn "[MAIN] phase_pull_query failed (non-fatal, MLP runs without phase): $e"
            end
        end  # GRUG: prediction guard — no prediction, no phase pull
        # GRUG v9: Build automaton trace features for the JIT LLM organ.
        # The automaton's phase accumulator knows about time-crystal rhythms,
        # rule depths, and accumulated magnitudes. Feed these into the MLP's
        # 24-dim input space so the transformer can learn automaton-state-dependent
        # attention patterns. Ephemeral in presence, persistent in state.
        _mlp_automaton_trace = try
            _pa_status = EphemeralAutomaton.phase_pull_status()
            _crystal_size = Int(get(_pa_status, "crystal_size", 0))
            _total_pulls = Int(get(_pa_status, "total_pulls", 0))
            _total_recorded = Int(get(_pa_status, "total_snapshots_recorded", 0))
            Float64[
                Float64(_crystal_size % 256) / 256.0,    # rule_hash (normalized crystal fingerprint)
                min(Float64(_total_pulls) / 100.0, 1.0),  # step_depth (normalized pull depth)
                min(Float64(_total_recorded) / 500.0, 1.0), # accum_magnitude (normalized accumulation)
                Float64(sign(Float64(_total_pulls)))       # accum_sign (direction of accumulation)
            ]
        catch e
            @warn "[MAIN] automaton trace computation failed (non-fatal): $e"
            Float64[0.0, 0.0, 0.0, 0.0]
        end

        # GRUG v9: Build coherence field features for the JIT LLM organ.
        # The coherence field tells the MLP about the global brain state:
        # how coherent are the active nodes? Is coherence rising or falling?
        # Is there lobe-level variance? These 4 dims let the transformer
        # learn coherence-dependent attention (e.g. "when coherence is low,
        # pay more attention to novelty signals").
        _mlp_coherence_features = try
            _cf_status = CoherenceField.coherence_field_status(NODE_MAP)
            _phi_now = Float64(get(_cf_status, "phi", 0.0))
            _n_coherent = Int(get(_cf_status, "n_coherent", 0))
            _n_active = Int(get(_cf_status, "n_active", 1))
            _lobe_coherence = Float64(_n_coherent) / max(1, _n_active)
            # Delta Phi: compare with cached value (0.0 if no prior)
            _phi_prev = get!(_MLP_CACHED_PHI, :last_phi, 0.0)
            _delta_phi = _phi_now - _phi_prev
            _MLP_CACHED_PHI[:last_phi] = _phi_now
            Float64[
                _phi_now,                                        # Phi_current
                min(abs(_delta_phi), 1.0),                       # Delta_Phi_magnitude
                Float64(sign(_delta_phi)),                       # Delta_Phi_direction
                _lobe_coherence                                  # lobe_coherence_variance
            ]
        catch e
            @warn "[MAIN] coherence features computation failed (non-fatal): $e"
            Float64[0.0, 0.0, 0.0, 0.0]
        end

        # GRUG v9: Position index for sinusoidal positional encoding.
        # Increments with each transform cycle so the transformer can learn
        # temporal patterns (e.g. "later in the conversation = more refined").
        _mlp_position_index = try
            Int(get(EphemeralMLP.get_mlp_status(), "total_transforms", 0))
        catch _
            0
        end

        mlp_result = EphemeralMLP.transform_vote_list(
            vote_data_for_mlp;
            hopfield_hit = hopfield_hit,
            user_input = mission_text,
            selfobserver_count = SelfObserver.store_size(_MLP_OBSERVER_STORE),
            is_compound = is_compound_input,
            scan_mode = _mlp_scan_mode,
            phase_entries = _phase_pulled_entries,
            surface_entries = _phase_activated ? _phase_surface_entries : Vector{Vector{Float64}}(),
            automaton_trace = _mlp_automaton_trace,
            coherence_features = _mlp_coherence_features,
            position_index = _mlp_position_index
        )
        if get(mlp_result, "error", "") == ""
            act = get(mlp_result, "activation", "sigmoid")
            nov = round(Float64(get(mlp_result, "novelty_score", 0.5)); digits=3)
            qual = round(Float64(get(mlp_result, "directive_quality", 0.5)); digits=3)
            adj_en = Bool(get(mlp_result, "adjustments_enabled", false))
            n_rules = length(get(mlp_result, "active_rules", []))
            # GRUG v9: Multi-output head readouts. The brain now reads on four channels.
            sem = round(Float64(get(mlp_result, "semantic_score", 0.5)); digits=3)
            rel = round(Float64(get(mlp_result, "relevance_score", 0.5)); digits=3)
            dis = round(Float64(get(mlp_result, "disambiguation", 0.5)); digits=3)
            println("  🧠 MLP: $act | novelty=$nov | quality=$qual | semantic=$sem | relevance=$rel | disambig=$dis | strain=$(round(Float64(get(mlp_result, "strain_energy", 0.0)); digits=3)) | rules=$n_rules | adj=$(adj_en ? "ON" : "OFF")")

            # GRUG v10: MLP-ASSISTED DECOMPOSITION (late check)
            # The standard decomposer ran before MLP scores were available.
            # Now that we have directive_quality and novelty, check if the
            # input is compound even though heuristics said it wasn't.
            if !is_compound_input && !_mlp_decomposition_done
                try
                    _mlp_sub = InputDecomposer.decompose_input_mlp(mission_text;
                        mlp_directive_quality = qual,
                        mlp_novelty = nov,
                    )
                    if length(_mlp_sub) > 1
                        sub_subjects = _mlp_sub
                        is_compound_input = true
                        println("[MULTIPART] MLP-assisted decomposition: $(InputDecomposer.summarize_decomposition(sub_subjects))")
                    end
                    _mlp_decomposition_done = true
                catch e
                    @warn "[MAIN] MLP-assisted decomposition failed (non-fatal): $e"
                end
            end

            # GRUG v7.27: Phase pull status — show time crystal retrieval info
            phase_activated = Bool(get(mlp_result, "phase_activated", false))
            phase_pulls = Int(get(mlp_result, "phase_pull_count", 0))
            phase_surfs = Int(get(mlp_result, "phase_surface_count", 0))
            if phase_activated
                println("  💎 Phase: PULL=$phase_pulls | surface=$phase_surfs | mode=$_mlp_scan_mode | compound=$is_compound_input")
            end
            # GRUG v7.24: Write an observation to the SelfObserver store.
            # Every MLP cycle records what happened — activation mode, novelty,
            # quality, and whether adjustments were enabled. These observations
            # accumulate and gate the MLP's adjustments via observation_threshold.
            try
                SelfObserver.observe!(
                    _MLP_OBSERVER_STORE,
                    next_runtime_id("mlp_cycle"),
                    :meta,
                    Dict{String, Any}(
                        "activation"         => act,
                        "novelty_score"      => nov,
                        "directive_quality"  => qual,
                        # GRUG v9: Multi-output head scores in SelfObserver.
                        # These let the observation threshold gate learn from
                        # all four channels, not just directive_quality.
                        "semantic_score"     => sem,
                        "relevance_score"    => rel,
                        "disambiguation"     => dis,
                        "adjustments_enabled"=> adj_en,
                        "active_rules"       => n_rules,
                        "user_input_hash"    => string(hash(lowercase(strip(mission_text))))
                    )
                )
            catch obs_err
                @warn "[MAIN] SelfObserver observe! failed (non-fatal): $obs_err"
            end
        else
            @warn "[MAIN] EphemeralMLP transform_vote_list error: $(get(mlp_result, "error", "unknown"))"
        end
    catch e
        @error "[MAIN] EphemeralMLP transform_vote_list FAILED (non-fatal): $e"
    end


    # ══════════════════════════════════════════════════════════════════════════
    # GRUG v7.29: VIGILANCE DISPATCH — context injector agents enrich the scaffold
    # ══════════════════════════════════════════════════════════════════════════
    # The orchestrator just built a scaffold from flat context. Context injectors
    # now probe the subconscious with biased dispositions and inject findings
    # back into the scaffold. The orchestrator doesn't know HOW the context got
    # richer — it just composes over richer input. Samey-response problem: solved
    # by making context enrichment a dispatched behavior, not an orchestrated one.
    try
        # Compute context weight from current cycle state
        _vig_las = isempty(cast_votes) ? 0.0 : count(v -> v.confidence >= 0.5, cast_votes) / max(1, length(cast_votes))
        _vig_ws  = isempty(contributing_votes) ? 0.0 : maximum(v -> v.confidence, contributing_votes; init=0.0) * maximum(v -> begin
            _n = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
            isnothing(_n) ? 0.0 : Float64(_n.strength)
        end, contributing_votes; init=0.0)
        # Winner strength normalized: use top confidence * top strength / 100
        _vig_top_conf = isempty(contributing_votes) ? 0.0 : maximum(v -> v.confidence, contributing_votes; init=0.0)
        _vig_top_str  = isempty(contributing_votes) ? 0.0 : begin
            _top_node_id = argmax(v -> v.confidence, contributing_votes).node_id
            _top_n = lock(() -> get(NODE_MAP, _top_node_id, nothing), NODE_LOCK)
            isnothing(_top_n) ? 0.0 : Float64(_top_n.strength)
        end
        _vig_ws = _vig_top_conf * (_vig_top_str / 10.0)  # strength / cap * conf
        _vig_ih = count(v -> v.antimatch, cast_votes; init=0)  # inhibition = antimatch votes
        _vig_am = any(v -> v.antimatch, cast_votes)             # anti-match detected?
        _vig_mi = isempty(MESSAGE_HISTORY) ? 0.0 : mean(Float64[m.intensity for m in MESSAGE_HISTORY])

        _vig_ctx_weight = EphemeralAutomaton.compute_context_weight(;
            lobe_activation_depth = _vig_las,
            winner_strength       = _vig_ws,
            inhibition_hits       = _vig_ih,
            anti_match_detected   = _vig_am,
            memory_intensity      = _vig_mi
        )

        if _vig_ctx_weight > 0.0
            # Get automaton rules that could serve as context injectors
            _vig_rules = EphemeralAutomaton.list_automaton_rules()

            if !isempty(_vig_rules)
                # Build probe_fn — wraps SelfObserver.peek_pattern on the MLP observer store
                _vig_probe_fn = (disposition, query_string) -> begin
                    # GRUG: Each injector agent calls this with its biased disposition.
                    # The disposition biases which keys get probed (keyword_hints),
                    # biases the query string (trigger_action prefix), and biases
                    # drop-table walk weights (via the query tokens).
                    _biased_query = string(disposition.trigger_action) * " " * query_string
                    if !isempty(disposition.keyword_hints)
                        _biased_query = join(disposition.keyword_hints, " ") * " " * _biased_query
                    end
                    result = SelfObserver.peek_pattern(
                        _MLP_OBSERVER_STORE,
                        "vigilance_injector",
                        _biased_query;
                        max_entries = disposition.probe_depth * 3,
                        walk_depth  = min(disposition.probe_depth, 4)
                    )
                    return result
                end

                _vig_agents = EphemeralAutomaton.dispatch_vigilance_agents!(
                    _vig_ctx_weight,
                    _vig_rules,
                    _vig_probe_fn;
                    injection_target = :scaffold
                )

                # GRUG: Harvest agent findings and inject into the scaffold.
                # Each agent that completed successfully may have probed
                # subconscious keys and found entries. We format these as
                # enriched context annotations appended to the scaffold.
                _vig_findings_blocks = String[]
                for _vig_agent in _vig_agents
                    if _vig_agent.status == :done && !isempty(_vig_agent.findings)
                        for _vig_f in _vig_agent.findings
                            _fkey = get(_vig_f, "probe_key", "???")
                            _fentries = get(_vig_f, "entries", [])
                            if !isempty(_fentries)
                                _entry_summaries = String[]
                                for _e in _fentries
                                    _e_tag = get(_e, "tag", :unknown)
                                    _e_data = get(_e, "data", Dict{String,Any}())
                                    _e_summary = try
                                        string(_e_tag, ": ", join(limit.(collect(string.(values(_e_data))), Ref(60)), ", "))
                                    catch _
                                        string(_e_tag, ": [data]")
                                    end
                                    push!(_entry_summaries, _e_summary)
                                end
                                push!(_vig_findings_blocks, "[$_fkey] " * join(_entry_summaries, "; "))
                            end
                        end

                        # GRUG: Feedback — stochastic write-back to subconscious.
                        if _vig_agent.feedback_written > 0
                            for _vig_f in _vig_agent.findings
                                if rand() < 0.5  # already gated by injector_feedback_prob, but double-check
                                    try
                                        SelfObserver.observe!(
                                            _MLP_OBSERVER_STORE,
                                            "vig_feedback_$(next_runtime_id("vig"))",
                                            :meta,       # GRUG FIX: was :vigilance which is not in VALID_TAGS
                                            Dict{String, Any}(
                                                "source_rule" => _vig_agent.rule_id,
                                                "probe_key"   => get(_vig_f, "probe_key", ""),
                                                "context_weight" => _vig_ctx_weight
                                            )
                                        )
                                    catch fb_err
                                        @warn "[MAIN] Vigilance feedback observe! failed (non-fatal): $fb_err"
                                    end
                                end
                            end
                        end
                    elseif _vig_agent.status == :timed_out
                        @debug "[MAIN] Vigilance injector '$(_vig_agent.id)' timed out (non-fatal)"
                    end
                end

                if !isempty(_vig_findings_blocks)
                    _vig_injection = "\n── Vigilance Context Enrichment ──\n" *
                                     join(_vig_findings_blocks, "\n") *
                                     "\n── End Vigilance Enrichment ──\n"
                    output = output * _vig_injection
                    println("  👁 Vigilance: $(length(_vig_agents)) agent(s) dispatched (weight=$(round(_vig_ctx_weight; digits=3))), $(length(_vig_findings_blocks)) finding(s) injected")
                else
                    if !isempty(_vig_agents)
                        println("  👁 Vigilance: $(length(_vig_agents)) agent(s) dispatched (weight=$(round(_vig_ctx_weight; digits=3))), no findings to inject")
                    end
                end
            end  # !isempty(_vig_rules)
        end  # _vig_ctx_weight > 0.0
    catch e
        @error "[MAIN] Vigilance dispatch FAILED (non-fatal, scaffold unmodified): $e"
    end
    println("\n🤖 AIML Output Scaffold:\n$output")

    # GRUG: Capture the actual spoken output + winning-vote metadata so
    # external harnesses can read the real response (not the stdout scrape
    # or the one-line history digest). Non-fatal: never breaks the cycle.
    try
        lock(_LAST_AIML_OUTPUT_LOCK) do
            _LAST_AIML_OUTPUT[] = output
            if !isempty(contributing_votes)
                _win = contributing_votes[1]
                _LAST_FIRED_NODE[]     = _win.node_id
                _LAST_PRIMARY_ACTION[] = String(_win.action)
                _LAST_CONFIDENCE[]     = Float64(_win.confidence)
            else
                _LAST_FIRED_NODE[]     = ""
                _LAST_PRIMARY_ACTION[] = ""
                _LAST_CONFIDENCE[]     = 0.0
            end
        end
    catch e
        @warn "[MAIN] last-output capture failed (non-fatal): $e"
    end

    # ── AUTOGROWTH: LIVE CONVERSATION EVIDENCE ACCUMULATION ──────────────
    # GRUG: Every user message carries evidence of gaps. Accumulate now.
    # Then maybe grow ONE thing if evidence is strong enough. Lazy + conservative.
    # Runs ONLY on text missions (not image). Image signals don't carry lexical gaps.
    # GRUG FIX (v7.44): Pre-declare variables used by both AutoGrowth AND AutoLinker
    # so they survive the try block scope. Julia scopes first-assigned-inside-try
    # variables to that block, making them UndefVarError outside.
    _ag_node_patterns = Set{String}()
    _ag_node_ids_patterns = Tuple{String,String}[]
    try
        if !is_image
            # GRUG: Snapshot current node patterns for coverage checks.
            _ag_node_patterns = lock(NODE_LOCK) do
                Set{String}(lowercase(strip(n.pattern)) for n in values(NODE_MAP) if !n.is_grave && !n.is_image_node && !startswith(n.pattern, "SDF:"))
            end
            _ag_node_ids_patterns = lock(NODE_LOCK) do
                [(n.id, n.pattern) for n in values(NODE_MAP) if !n.is_grave && !n.is_image_node && !startswith(n.pattern, "SDF:")]
            end
            # GRUG: Snapshot lobe coverage for under-populated lobe detection.
            _ag_lobe_snapshots = Tuple{String,String,Set{String}}[]
            for (lid, lrec) in Lobe.LOBE_REGISTRY
                _ag_node_ids_in_lobe = Set{String}()
                for (nid, assigned_lid) in Lobe.NODE_TO_LOBE_IDX
                    if assigned_lid == lid
                        push!(_ag_node_ids_in_lobe, nid)
                    end
                end
                push!(_ag_lobe_snapshots, (lid, lrec.subject, _ag_node_ids_in_lobe))
            end
            # GRUG: Snapshot attachments for gap detection.
            _ag_attach_snapshots = Tuple{String,String,Bool}[]
            lock(BRIDGE_LOCK) do
                for (target_id, bridges) in BRIDGE_MAP
                    for br in bridges
                        # GRUG FIX (v7.44): CascadeBridge has seam_tokens (not connector)
                        # and is_crystalized (not json_data["crystalized"]).
                        push!(_ag_attach_snapshots, (target_id, join(br.seam_tokens, " "), br.is_crystalized))
                    end
                end
            end
            # GRUG: Sigil table entries for gap detection.
            _ag_sigil_entries = Dict{String,Any}()
            for (sname, sentry) in _ENGINE_SIGIL_TABLE.entries
                _ag_sigil_entries[sname] = Dict{String,Any}(
                    "lexicon"   => sentry.lexicon,
                    "expansion" => sentry.expansion,
                    "class"     => string(sentry.class),
                )
            end
            # GRUG: Strain energy from EphemeralMLP (hippocampal hurt).
            _ag_strain = try EphemeralMLP.get_strain_energy() catch _ 0.0 end

            # ── ACCUMULATE EVIDENCE ──
            # GRUG v10: Wire EphemeralMLP heads 2-4 + CoherenceField ΔΦ +
            # SelfObserver recurring gaps into AutoGrowth evidence. The old code
            # had hippocampal_warrant_active=false and zero MLP signal integration.
            # Now: semantic gap, relevance dropout, disambiguation pressure,
            # coherence drop, and observer patterns all feed evidence.
            _ag_sem = try Float64(get(mlp_result, "semantic_score", 0.5)) catch _ 0.5 end
            _ag_rel = try Float64(get(mlp_result, "relevance_score", 0.5)) catch _ 0.5 end
            _ag_dis = try Float64(get(mlp_result, "disambiguation", 0.5)) catch _ 0.5 end
            _ag_hippo_warrant = try EphemeralMLP.is_hippocampal_warrant_active() catch _ false end
            _ag_coherence_delta = try
                _cf_phi_now = CoherenceField.compute_field(NODE_MAP; force=false)
                get(_cf_phi_now, "delta_phi", 0.0)
            catch _
                0.0
            end
            _ag_observer_gap = try
                # GRUG: Check SelfObserver for recurring gap pattern.
                # Look for recent observations with tag=:gap or low directive_quality.
                _obs_peek = SelfObserver.peek_pattern(_MLP_OBSERVER_STORE, "mlp_cycle:", "directive_quality";
                    tag=nothing, max_results=3)
                _low_quality_count = count(o -> Float64(get(o.data, "directive_quality", 1.0)) < 0.4, _obs_peek)
                Float64(_low_quality_count)
            catch _
                0.0
            end
            _ag_observer_pattern = _ag_observer_gap >= 2.0  # recurring gap pattern

            AutoGrowth.accumulate_evidence!(
                user_text                 = mission_text,
                intensity                 = 1.0,  # GRUG: Base intensity per message
                node_patterns             = _ag_node_patterns,
                node_ids_patterns         = _ag_node_ids_patterns,
                thesaurus_gate_filter     = Thesaurus.synonym_lookup,
                thesaurus_word_similarity = Thesaurus.word_similarity,
                lobe_snapshots            = _ag_lobe_snapshots,
                attachment_snapshots      = _ag_attach_snapshots,
                sigil_table_entries       = _ag_sigil_entries,
                strain_energy             = _ag_strain,
                hippocampal_warrant_active = _ag_hippo_warrant,
                # GRUG v10: New EphemeralMLP signal evidence sources
                mlp_semantic_score        = _ag_sem,
                mlp_relevance_score       = _ag_rel,
                mlp_disambiguation        = _ag_dis,
                coherence_delta_phi       = _ag_coherence_delta,
                observer_recurring_gap    = _ag_observer_pattern,
                observer_gap_pattern      = _ag_observer_pattern ? "recurring_gap" : "",
                # GRUG v10: Deep MLP integration signals
                mlp_novelty_score          = try Float64(get(mlp_result, "novelty_score", 0.5)) catch _ 0.5 end,
                mlp_activation_mode        = try Symbol(get(mlp_result, "activation", :sigmoid)) catch _; :sigmoid end,
                mlp_hash_rarity            = try
                    _nt_stats = EphemeralMLP.get_novelty_tracker_stats()
                    _n_hashes = Int(get(_nt_stats, "unique_hashes", 0))
                    _n_obs = Int(get(_nt_stats, "total_observations", 1))
                    # GRUG: hash_rarity = fraction of unique hashes that are rare
                    # If we have few hashes relative to observations, most are repeated = low rarity
                    # If we have many hashes relative to observations, most are novel = high rarity
                    _n_obs > 0 ? min(1.0, _n_hashes / _n_obs) : 0.0
                catch _ 0.0 end,
                mlp_correlation_quality    = try
                    _ic_stats = EphemeralMLP.get_input_correlation_stats()
                    Float64(get(_ic_stats, "mean_quality_ema", 0.5))
                catch _ 0.5 end,
                # GRUG v7.58: Relational triple extraction for SOURCE 18
                extract_triples_fn         = (pat) -> extract_relational_triples(pat),
                evaluate_dialectics_fn     = (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
                node_map                   = NODE_MAP,
                node_lock                  = NODE_LOCK,
            )

            # ── MAYBE GROW FROM EVIDENCE ──
            # GRUG: One growth per turn max. Coinflip-biased. Lazy conservative.
            _ag_result = AutoGrowth.maybe_grow_from_evidence!(
                node_map                   = NODE_MAP,
                node_lock                  = NODE_LOCK,
                create_node_fn             = create_node,
                add_to_group_fn            = add_to_group!,
                register_group_fn          = register_group!,
                group_map                  = GROUP_MAP,
                group_lock                 = GROUP_LOCK,
                lobe_registry              = Lobe.LOBE_REGISTRY,
                immune_gate_fn             = (pattern, data) -> begin
                    json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                    immune_gate("/autogrowth", json_text; is_critical=false)
                end,
                thesaurus_gate_filter      = Thesaurus.synonym_lookup,
                thesaurus_word_similarity  = Thesaurus.word_similarity,
                add_lobe_whitelist_fn      = (lobe_id, token) -> Lobe.add_lobe_whitelist!(lobe_id, token),
                register_sigil_fn          = (args...; kwargs...) -> SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE, args...; kwargs...),
                register_thesaurus_pair_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
                stochastic_aiml_growth_fn  = (lobe_id, pattern; data_warrant=1.0) ->
                    AIMLNodeSystem.stochastic_aiml_growth!(lobe_id, pattern; data_warrant=data_warrant),
                group_latch_fn             = (pattern; node_map=NODE_MAP, node_lock=NODE_LOCK, requesting_node_is_time=false) ->
                    find_group_latch_candidates(pattern; node_map=node_map, node_lock=node_lock, requesting_node_is_time=requesting_node_is_time, thesaurus_fn=Thesaurus.get_seed_synonyms),
                link_to_group_member_fn    = link_to_group_member,
                group_avg_strength_fn      = (gid) -> lock(GROUP_LOCK) do
                    grp = get(GROUP_MAP, gid, nothing)
                    grp === nothing && return 0.0
                    isempty(grp.node_ids) && return 0.0
                    total = 0.0
                    count = 0
                    for nid in grp.node_ids
                        n = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                        if n !== nothing && !n.is_grave
                            total += n.strength
                            count += 1
                        end
                    end
                    count > 0 ? total / count : 0.0
                end,
                group_for_fn               = (nid) -> lock(GROUP_LOCK) do
                    for (gid, grp) in GROUP_MAP
                        if nid in grp.node_ids
                            return gid
                        end
                    end
                    nothing
                end,
                sigil_promote_fn           = (text) -> SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, text),
                extract_triples_fn         = (pat) -> extract_relational_triples(pat),
                evaluate_dialectics_fn     = (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
                words_to_signal_fn         = (words) -> PatternScanner.words_to_signal(words),
                scan_latch_candidates_fn   = (pattern, action_packet; kwargs...) -> _scan_latch_candidates(pattern, action_packet; kwargs...),
                # GRUG v7.58: verb→sigil reverse mapping + user text for relational pattern promotion
                verb_class_of_fn           = (verb) -> SemanticVerbs.verb_class_of(verb),
                user_text                  = mission_text,
                sigil_table                = _ENGINE_SIGIL_TABLE,
                mlp_rule_hints             = try EphemeralMLP.get_active_rule_hints() catch _ Dict{String, Any}[] end,
            )

            if _ag_result !== nothing && _ag_result.won_coinflip
                println("[AUTOGROWTH] 🌱  Grew $(_ag_result.growth_type) node for '$(_ag_result.pattern)' in $(_ag_result.lobe_hint) (intensity=$(round(_ag_result.evidence_intensity, digits=2)), p=$(round(_ag_result.coinflip_prob, digits=3)))")
            end

            # ── GRUG v10: PETTY LEARNER FAST-PATH ──────────────────────
            # GRUG: Before doing expensive evidence accumulation for trivial
            # gaps, check if the input is a "petty" case — one uncovered token
            # that's a synonym, simple math, or a domain token. These skip the
            # evidence pipeline entirely. INSTANT learning, no coinflip.
            try
                if _ag_result === nothing || !_ag_result.won_coinflip
                    # GRUG: Only try petty if AutoGrowth didn't grow anything.
                    # If it DID grow, the gap was real — not petty.
                    _petty_bindings = try
                        bind_sigils(mission_text, _ENGINE_SIGIL_TABLE)
                    catch _
                        Dict()
                    end
                    _petty_result = PettyLearner.classify_petty(
                        mission_text,
                        Vector{String}(split(mission_text)),
                        _ag_node_patterns,
                        Thesaurus.synonym_lookup,
                        Thesaurus.word_similarity,
                        _ag_lobe_snapshots,
                        _ag_sigil_entries,
                        _petty_bindings,
                    )
                    if _petty_result.dispatched
                        _petty_dispatched = PettyLearner.dispatch_petty!(_petty_result;
                            thesaurus_register_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
                            flashcard_put_fn = (lobe_id, expr, result_str; result_num=NaN, card_type=:arithmetic) ->
                                LobeTable.flashcard_put!(lobe_id, expr, result_str;
                                    result_num=result_num, card_type=card_type),
                            lobe_whitelist_fn = (lobe_id, token) -> Lobe.add_lobe_whitelist!(lobe_id, token),
                            arithmetic_compute_fn = (bindings) -> ArithmeticEngine.compute_arithmetic(bindings),
                            arithmetic_bindings = _petty_bindings,
                        )
                        println("[PETTY] ⚡  Petty fast-path: $(_petty_dispatched.detail)")
                    end
                end
            catch e
                @warn "[MAIN] PettyLearner failed (non-fatal): $e"
            end

            # ── GRUG v10: CURIOSITY OVERFLOW CHECK ──────────────────────
            # GRUG: The curiosity accumulator in AutoGrowth passively accumulates
            # from MLP signals + uncovered tokens. When it overflows, the system
            # generates an autonomous question via _HIPPOCAMPAL_PENDING_ASK.
            try
                _cur_overflow = AutoGrowth.check_curiosity_overflow()
                if _cur_overflow !== nothing
                    lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
                        _HIPPOCAMPAL_PENDING_ASK[] = _cur_overflow
                    end
                    _cur_status = AutoGrowth.get_curiosity_status()
                    println("[CURIOSITY] 🔥  Curiosity overflow! intensity=$(_cur_status["intensity"]) → pending ask: $(repr(_cur_overflow))")
                    # GRUG: Quench after overflow so it doesn't fire again immediately.
                    AutoGrowth.quench_curiosity!()
                end
            catch e
                @warn "[MAIN] Curiosity overflow check failed (non-fatal): $e"
            end
        end
    catch e
        @warn "[MAIN] AutoGrowth failed (non-fatal,不影响response): $e"
    end


    # ── AUTOLINKER: EVIDENCE-BASED CROSS-LOBE BRIDGE GROWTH ──────────────
    # GRUG: AutoGrowth grows NEW nodes. AutoLinker bridges EXISTING nodes.
    # Especially cross-lobe: nodes in different chambers that keep showing
    # up together but can't reach each other without a bridge.
    # Same lazy conservative coinflip. Same cancer prevention.
    try
        if !is_image
            # GRUG: Snapshot bridge map for cap checks + neighbor evidence.
            _al_bridge_snap = lock(BRIDGE_LOCK) do
                snap = Dict{String, Vector{Tuple{String,String}}}()
                for (nid, bridges) in BRIDGE_MAP
                    snap[nid] = [(br.partner_id, join(br.seam_tokens, " ")) for br in bridges]
                end
                snap
            end

            # GRUG: Resolve lobe for each fired node (for cross-lobe detection).
            _al_lobe_of = (nid) -> Lobe.find_lobe_for_node(nid)

            # GRUG: Get co-occurrence map from AutoGrowth for word-level link evidence.
            # Convert Vector{Dict} snapshot to Dict{Tuple{String,String}, Int} for AutoLinker.
            _al_co_occur_raw = AutoGrowth.get_co_occur_snapshot()
            _al_co_occur = Dict{Tuple{String,String}, Int}()
            for entry in _al_co_occur_raw
                a = get(entry, "a", ""); b = get(entry, "b", ""); c = get(entry, "count", 0)
                if !isempty(a) && !isempty(b) && c > 0
                    key = a < b ? (a, b) : (b, a)
                    _al_co_occur[key] = c
                end
            end

            # ── ACCUMULATE LINK EVIDENCE ──
            # GRUG v10: Wire MLP disambiguation + relevance scores + ChatterResiduals
            # co-occurrence into AutoLinker. The old code had strain_nodes=String[]
            # and zero MLP signal. Now: disambiguation_bridge, relevance_cross_lobe,
            # and chatter_residual all feed link evidence.
            _al_mlp_disambig = try Float64(get(mlp_result, "disambiguation", 0.5)) catch _ 0.5 end
            _al_mlp_relevance = try Float64(get(mlp_result, "relevance_score", 0.5)) catch _ 0.5 end

            # GRUG v10: Get ChatterResiduals word co-occurrence pairs.
            # The background thread processes chatter swaps and records which
            # node pairs co-occur. We extract the (word_a, word_b, intensity)
            # triples for AutoLinker's SOURCE 11.
            _al_chatter_pairs = try
                _cr_status = ChatterResiduals.get_chatter_residuals_status()
                # GRUG: Parse the status string for co-occurrence data.
                # For now, pass empty — the real co-occurrence comes from
                # the idle cycle which has access to the raw ledger.
                Tuple{String,String,Float64}[]
            catch _
                Tuple{String,String,Float64}[]
            end

            # GRUG v10: Compute strain_nodes from nodes currently under strain.
            # The old code had String[] — zero strain signal. Now we check
            # which nodes have high strain_energy and include them.
            _al_strain_nodes = try
                _strain_ids = String[]
                for (nid, node) in NODE_MAP
                    if !node.is_grave && node.strength < 0.3
                        push!(_strain_ids, nid)
                    end
                end
                _strain_ids
            catch _
                String[]
            end

            AutoLinker.accumulate_link_evidence!(
                co_fired_ids              = fired_ids,
                input_touched_ids         = String[],  # GRUG: InputLedger handles this separately
                node_ids_patterns         = _ag_node_ids_patterns,
                bridge_map_snapshot       = _al_bridge_snap,
                thesaurus_gate_filter     = Thesaurus.synonym_lookup,
                thesaurus_word_similarity = Thesaurus.word_similarity,
                lobe_of_fn                = _al_lobe_of,
                strain_nodes              = _al_strain_nodes,
                co_occur_map              = _al_co_occur,
                co_activation_pairs       = Tuple{String,String,Float64}[],  # GRUG: no explicit pairs in active path
                # GRUG v10: New EphemeralMLP signal evidence sources
                mlp_disambiguation        = _al_mlp_disambig,
                mlp_relevance_score       = _al_mlp_relevance,
                chatter_co_occur_pairs    = _al_chatter_pairs,
                # GRUG v10: Deep MLP integration signal
                mlp_novelty_score          = try Float64(get(mlp_result, "novelty_score", 0.5)) catch _ 0.5 end,
            )

            # ── MAYBE AUTO LINK ──
            _al_result = AutoLinker.maybe_auto_link!(
                node_map              = NODE_MAP,
                node_lock             = NODE_LOCK,
                bridge_fn             = (id_a, id_b; seam_tokens=String[]) ->
                    bridge_nodes!(id_a, id_b; seam_tokens=seam_tokens),
                bridge_map_ref        = BRIDGE_MAP,
                bridge_lock_ref       = BRIDGE_LOCK,
                lobe_of_fn            = _al_lobe_of,
                immune_gate_fn        = (pattern, data) -> begin
                    json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                    immune_gate("/autolinker", json_text; is_critical=false)
                end,
                is_already_bridged_fn = (id_a, id_b) -> begin
                    key = id_a < id_b ? (id_a, id_b) : (id_b, id_a)
                    bridges_a = lock(() -> get(BRIDGE_MAP, id_a, CascadeBridge[]), BRIDGE_LOCK)
                    for br in bridges_a
                        if br.partner_id == id_b
                            return true
                        end
                    end
                    return false
                end,
                node_alive_fn         = (nid) -> begin
                    n = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                    return !isnothing(n) && !n.is_grave
                end,
                thesaurus_gate_filter = Thesaurus.synonym_lookup,
            )

            if _al_result !== nothing && _al_result.won_coinflip
                cross_tag = _al_result.is_cross_lobe ? "CROSS-LOBE" : "same-lobe"
                println("[AUTOLINKER] 🔗  Bridged $(_al_result.node_a) ↔ $(_al_result.node_b) [$cross_tag] (intensity=$(round(_al_result.evidence_intensity, digits=2)), p=$(round(_al_result.coinflip_p, digits=3)), source=$(_al_result.source))")
            end
        end
    catch e
        @warn "[MAIN] AutoLinker failed (non-fatal): $e"
    end

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
            # GRUG: Should never happen (we guarded on isempty(all_specimens)
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
Returns same tuple format as scan_and_expand for uniform downstream processing.
v7.23: Image specimens carry Int[] for input_chunks (no chunk resolution for
image scans — SDF signals don't have token positions).
"""
function _scan_image_specimens(img_signal::Vector{Float64})
    if isempty(img_signal)
        error("!!! FATAL: _scan_image_specimens got empty img_signal! !!!")
    end

    results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]

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
                # GRUG v7.23: Image specimens carry Int[] for input_chunks.
                # SDF signals don't have token positions, so no chunk resolution.
                push!(results, (id, conf, false, RelationalTriple[], node.relational_patterns, Int[]))
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

# GRUG: /saveSpecimen writes the ENTIRE cave state to a JSON file (.json) or gzip-compressed file (.gz).
# /loadSpecimen reads that file back and RESTORES the ENTIRE cave from scratch.
# This is LONG-TERM STORAGE. Not "add a few nodes" — this is "freeze the whole brain,
# put it in a jar, thaw it later with every neuron exactly where Grug left it."
# No silent failures. No half-restores. If the file is bad, NOTHING changes.
# Grug screams loud. Grug validates everything. Grug is paranoid.

"""
save_specimen_to_file!(filepath::String)::String

GRUG: Serialize the ENTIRE cave state to a JSON or gzip-compressed JSON file.
Use .json extension for plain JSON (cross-platform, no gzip needed) or .gz for compression.
Captures ALL mutable state across all modules:
  - nodes       (full Node struct: strengths, patterns, neighbors, graves, etc.)
  - hopfield    (HOPFIELD_CACHE + hit counts)
  - rules       (AIML_DROP_TABLE stochastic rules)
  - messages    (up to 10k message history with pin flags)
  - lobes       (LOBE_REGISTRY: fire/inhibit counts, connections, node assignments, whitelists)
  - lobe_tables (LOBE_TABLE_REGISTRY: all chunks with NodeRef objects)
  - verbs       (verb classes + verbs + synonyms from SemanticVerbs)
  - thesaurus   (SYNONYM_SEED_MAP runtime additions from Thesaurus)
  - inhibitions (NegativeThesaurus entries from InputQueue)
  - arousal     (EyeSystem arousal state: level, decay, baseline)
  - eye_state   (EyeSystem tracking: attention, centroid, last_arousal)
  - counters    (NODE ID_COUNTER + MSG_ID_COUNTER)
  - last_voters (LAST_VOTER_IDS for /wrong feedback)
  - brainstem   (dispatch count, propagation history)
  - bridges (BRIDGE_MAP cascade bridge system, bidirectional)
  - trajectory  (ActionTonePredictor ring buffer + config)
  - temporal    (ImageSDF TEMPORAL_COHERENCE_LEDGER timing patterns)
  - cooldowns   (ChatterMode MORPH_COOLDOWN_MAP 24h morph timestamps)
  - sigils      (_ENGINE_SIGIL_TABLE entries: &noun lexicons, custom sigils)
  - automatons  (EphemeralAutomaton._AUTOMATON_REGISTRY multi-step rules)
  - contributor_votes (LAST_CONTRIBUTOR_VOTES for /right feedback)
  - node_to_group (NODE_TO_GROUP reverse index)
  - tonal_knobs (TonalJudge _FRAME_LIFT/INHIBIT_MULTIPLIER runtime knobs)

Format: v2.10 (backward-compatible with v2.0+ on load).
Returns a formatted summary string.
"""
# ==============================================================================
# HELPER: DecomposerConfig → Dict for specimen save
# ==============================================================================

"""
    _decomposer_config_to_dict(config) -> Dict

Convert a DecomposerConfig to a dict suitable for JSON serialization
in the specimen. This allows the specimen author to edit the config
and have it survive across save/load cycles.
"""
function _decomposer_config_to_dict(config::InputDecomposer.DecomposerConfig)::Dict{String,Any}
    return Dict{String,Any}(
        "split_conjunctions"  => sort(collect(config.split_conjunctions)),
        "compound_pairs"      => Dict{String,Vector{String}}(
            k => sort(collect(vs)) for (k, vs) in config.compound_pairs
        ),
        "context_conjunction" => config.context_conjunction,
        "question_markers"    => sort(collect(config.question_markers)),
        "command_markers"     => sort(collect(config.command_markers)),
        "conjugation_rules"   => Dict{String,Vector{String}}(
            k => v for (k, v) in config.conjugation_rules
        ),
    )
end


# GRUG: Helper for serializing LobeOrchestrator.LAST_LOBE_SCORES tuples.
# Each tuple is (lobe_id::String, base_avg::Float64, top_avg::Float64, score::Float64, hard_count::Int).
function _lls_item_to_dict(t::Tuple{String, Float64, Float64, Float64, Int})::Dict{String,Any}
    return Dict{String,Any}("lobe_id"=>t[1], "base_avg"=>t[2], "top_avg"=>t[3], "score"=>t[4], "hard_count"=>t[5])
end

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
                "is_antimatch_node"   => node.is_antimatch_node,
                "neighbor_ids"        => node.neighbor_ids,
                "is_unlinkable"       => node.is_unlinkable,
                "max_neighbors"       => node.max_neighbors,
                "is_grave"            => node.is_grave,
                "grave_reason"        => node.grave_reason,
                "response_times"      => node.response_times,
                "ledger_last_cleared" => node.ledger_last_cleared,
                "hopfield_key"        => string(node.hopfield_key),  # UInt64 -> String for JSON safety
                # GRUG BUG-010b: Original content frozen at birth. Chatter swaps don't touch these.
                "original_pattern"        => node.original_pattern,
                "original_action_packet"  => node.original_action_packet
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
    rule_list = [Dict{String, Any}("text" => r.text, "prob" => r.fire_probability) for r in lock(_DROP_TABLE_LOCK) do; copy(AIML_DROP_TABLE) end]
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
                "created_at"         => rec.created_at,
                "subject_whitelist"  => sort(collect(rec.subject_whitelist)),
                "name"               => rec.name
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

    # ── 14. BRIDGES (CASCADE BRIDGE SYSTEM — v8.0 bidirectional) ──────────────
    # GRUG v8.0: Serialize BRIDGE_MAP bidirectionally. Each A↔B bridge appears
    # under BOTH BRIDGE_MAP[A] and BRIDGE_MAP[B], so we deduplicate by saving
    # each pair once (sorted minmax). We store asymmetric confidence for each
    # direction and also write backward-compat "attachments" key for old loads.
    bridge_list = Dict{String, Any}[]
    shown_pairs = Set{Tuple{String,String}}()
    lock(BRIDGE_LOCK) do
        for (node_id, bridges) in BRIDGE_MAP
            for br in bridges
                pair_key = minmax(node_id, br.partner_id)
                if pair_key in shown_pairs
                    continue
                end
                push!(shown_pairs, pair_key)
                # GRUG: Find the reverse entry for asymmetric confidence
                reverse_conf = br.base_confidence  # fallback
                for rbr in get(BRIDGE_MAP, br.partner_id, CascadeBridge[])
                    if rbr.partner_id == node_id
                        reverse_conf = rbr.base_confidence
                        break
                    end
                end
                push!(bridge_list, Dict{String, Any}(
                    "node_a"              => node_id,
                    "node_b"              => br.partner_id,
                    "seam_tokens"         => br.seam_tokens,
                    "base_confidence_ab"  => br.base_confidence,
                    "base_confidence_ba"  => reverse_conf,
                    "source_lobe"         => br.source_lobe,
                    "is_crystalized"      => br.is_crystalized,
                    "crystal_origin"      => String(br.crystal_origin)
                ))
            end
        end
    end
    specimen["bridges"] = bridge_list
    # GRUG: Backward compat — also write old "attachments" format for v7.x loads
    attachment_list = Dict{String, Any}[]
    for bentry in bridge_list
        na = String(bentry["node_a"])
        nb = String(bentry["node_b"])
        seam = bentry["seam_tokens"]
        pat_str = isempty(seam) ? "" : join(seam, " ")
        # GRUG: Old format had "target_id" and "node_id" (one-way A→B)
        push!(attachment_list, Dict{String, Any}(
            "target_id"       => na,
            "node_id"         => nb,
            "pattern"         => pat_str,
            "signal"          => Float64[],
            "base_confidence" => Float64(bentry["base_confidence_ab"]),
            "is_crystalized"  => Bool(bentry["is_crystalized"]),
            "crystal_origin"  => String(bentry["crystal_origin"])
        ))
    end
    specimen["attachments"] = attachment_list


    # \u2500\u2500 14b. CHATTER GROUPS (v7.19) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500
    # GRUG: Each NodeGroup is a stable cluster of similar-pattern nodes that
    # chatter together. Persist them so cursor walks survive save/load and
    # phagy can keep organizing the same bundles after a reboot.
    group_list = Dict{String, Any}[]
    lock(GROUP_LOCK) do
        for (gid, grp) in sort(collect(GROUP_MAP), by = x -> x[1])
            push!(group_list, Dict{String, Any}(
                "id"               => grp.id,
                "members"          => copy(grp.members),
                "centroid_pattern" => grp.centroid_pattern,
                "created_at"       => grp.created_at,
                "last_chatter_at"  => grp.last_chatter_at,
                "chatter_count"    => grp.chatter_count,
                "has_grave_slot"   => grp.has_grave_slot,
                "grave_count"      => grp.grave_count,
                "max_occupancy"    => grp.max_occupancy,
                "is_time_node_group" => grp.is_time_node_group,
                "is_chatter_eligible" => grp.is_chatter_eligible,
                # GRUG BUG-010b: inhibition_tokens — semantic "don't do" set from alive originals + thesaurus.
                "inhibition_tokens"  => collect(grp.inhibition_tokens),
            ))
        end
    end
    specimen["chatter_groups"] = group_list

    # GRUG: Per-node chatter cooldowns piggyback here \u2014 one row per node id.
    cooldown_list = Dict{String, Any}[]
    lock(CHATTER_NODE_COOLDOWN_LOCK) do
        for (nid, ts) in CHATTER_NODE_COOLDOWN
            push!(cooldown_list, Dict{String, Any}("node_id" => nid, "last_chatter_at" => ts))
        end
    end
    specimen["chatter_cooldowns"] = cooldown_list


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

    # ── 20. SIGIL TABLE (engine-level) ──────────────────────────────────────
    # GRUG: Serialize the engine's SigilTable so specimen-merged &noun lexicons
    # and any custom sigils survive save/load. Without this, a specimen that
    # merged &noun=["derivative","integral"] loses the lexicon on reload and
    # the sigil promoter stops recognizing those words as &noun captures.
    sigil_list = Dict{String, Any}[]
    for (name, entry) in _ENGINE_SIGIL_TABLE.entries
        push!(sigil_list, Dict{String, Any}(
            "name"                => entry.name,
            "class"               => string(entry.class),
            "applies_at"          => string(entry.applies_at),
            "sigil_type"          => entry.sigil_type === nothing ? nothing : string(entry.sigil_type),
            "lexicon"             => entry.lexicon === nothing ? nothing : sort(entry.lexicon),
            "params"              => entry.params,
            "expansion"           => entry.expansion,
            "provenance"          => entry.provenance,
            "promote_at_tokenize" => entry.promote_at_tokenize
            # GRUG: promote_predicate is a Function — can't serialize.
            # On load, only entries WITHOUT a predicate are restored.
            # Predicate-bearing sigils (if any) are engine-builtins that
            # default_registry() will recreate anyway.
        ))
    end
    specimen["sigil_table"] = sigil_list

    # ── 21. EPHEMERAL AUTOMATON REGISTRY ────────────────────────────────────
    # GRUG: Serialize specimen-defined automaton rules. These are registered
    # by /addAutomatonRule at runtime and contain multi-step op sequences.
    # Without this, all automaton escalation rules are lost on reload.
    automaton_list = Dict{String, Any}[]
    lock(EphemeralAutomaton._AUTOMATON_REGISTRY_LOCK) do
        for (id, rule) in EphemeralAutomaton._AUTOMATON_REGISTRY
            step_list = Dict{String, Any}[]
            for step in rule.steps
                push!(step_list, Dict{String, Any}(
                    "label"   => step.label,
                    "op"      => string(step.op),
                    "payload" => step.payload
                ))
            end
            push!(automaton_list, Dict{String, Any}(
                "id"              => rule.id,
                "trigger_action"  => string(rule.trigger_action),
                "steps"           => step_list,
                "jitter_targets"  => sort(collect(rule.jitter_targets)),
                "min_confidence"  => rule.min_confidence
            ))
        end
    end
    specimen["automaton_rules"] = automaton_list
 
    # ── 21.5 PHASE ACCUMULATOR (TIME CRYSTAL) ────────────────────────────────────────
    # GRUG v7.27: Save the phase accumulator (time crystal) alongside automaton rules.
    # The crystal holds ATP distribution snapshots from past escalations.
    # Without this, the hippocampus forgets all learned phase on reload.
    try
        specimen["phase_accumulator"] = EphemeralAutomaton.phase_accumulator_to_dict()
        _pa_status = EphemeralAutomaton.phase_pull_status()
        _pa_n = Int(get(_pa_status, "crystal_size", 0))
        println("  💎 Phase accumulator saved: $_pa_n snapshots in crystal")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize phase accumulator: $e"
        println("  ❌ Phase accumulator: FAILED to serialize! $e")
    end

    # ── 22. LAST CONTRIBUTOR VOTES ─────────────────────────────────────────
    # GRUG: Serialize the last contributor votes so /right works after reload.
    # Vote structs contain node_id, action, confidence, negatives, triples,
    # multipart fields, and input_chunks. Without this, /right has no idea
    # who contributed after a reload.
    vote_list = Dict{String, Any}[]
    lock(LAST_VOTER_LOCK) do
        for v in LAST_CONTRIBUTOR_VOTES
            push!(vote_list, Dict{String, Any}(
                "node_id"         => v.node_id,
                "action"          => v.action,
                "confidence"      => v.confidence,
                "negatives"       => v.negatives,
                "user_triples"    => [Dict("subject" => t.subject, "relation" => t.relation, "object" => t.object)
                                      for t in v.user_triples],
                "node_triples"    => [Dict("subject" => t.subject, "relation" => t.relation, "object" => t.object)
                                      for t in v.node_triples],
                "antimatch"       => v.antimatch,
                "multipart_group" => v.multipart_group,
                "multipart_role"  => string(v.multipart_role),
                "input_chunks"    => v.input_chunks
            ))
        end
    end
    specimen["last_contributor_votes"] = vote_list

    # ── 23. NODE_TO_GROUP INDEX ─────────────────────────────────────────────
    # GRUG: Serialize the NODE_TO_GROUP reverse index explicitly. On load,
    # chatter_groups restore rebuilds this, but saving it directly means we
    # don't have to rely on group member lists being perfectly in sync.
    node_group_idx = Dict{String, String}()
    lock(GROUP_LOCK) do
        for (nid, gid) in NODE_TO_GROUP
            node_group_idx[nid] = gid
        end
    end
    specimen["node_to_group_idx"] = node_group_idx

    # ── 24. TONAL JUDGE TUNABLES ───────────────────────────────────────────
    # GRUG: Save the TonalJudge runtime-adjustable knobs. These are Refs that
    # can be tuned at runtime; losing them on reload means the specimen
    # forgets its emotional calibration.
    _tj_lift, _tj_inhibit = TonalJudge.get_frame_match_weights()
    specimen["tonal_judge_knobs"] = Dict{String, Any}(
        "frame_lift_multiplier"   => _tj_lift,
        "frame_inhibit_multiplier" => _tj_inhibit
    )

    # ── 25. EPHEMERAL MLP STATE ────────────────────────────────────────────
    # GRUG v7.24: Save the EphemeralMLP state as a standalone JSON structure.
    # Weights, rules, novelty tracker, statistics — the brain remembers.
    specimen["ephemeral_mlp"] = EphemeralMLP.to_specimen_dict()

    # GRUG v7.24: Save the SelfObserver store that gates MLP adjustments.
    # The observer store's total_entries and key count are saved so the
    # observation_threshold gate can be evaluated correctly on reload.
    specimen["mlp_observer_store"] = Dict{String, Any}(
        "total_entries" => SelfObserver.store_size(_MLP_OBSERVER_STORE),
        "key_count"     => SelfObserver.key_count(_MLP_OBSERVER_STORE)
    )

    # GRUG v9: Save the cached Phi for coherence delta tracking.
    # Without this, the MLP loses its last-known coherence field value on reload,
    # so the first cycle after load computes a bogus delta-Phi (0.0 -> current,
    # instead of saved-Phi -> current). The brain should remember where coherence
    # was when it went to sleep, so it can correctly measure change on wake.
    specimen["mlp_cached_phi"] = Dict{String, Any}(
        "last_phi" => get(_MLP_CACHED_PHI, :last_phi, 0.0)
    )

    specimen["_meta"] = Dict{String, Any}(
        "version"    => "2.11",
        "saved_at"   => time(),
        "format"     => "grugbot420-specimen-v2.11"
    )

    # ── DECOMPOSER CONFIG (v7.28) ──────────────────────────────────────────────────
    # GRUG: FIRST-CLASS SAVE TREATMENT. The decomposer config gets its own
    # labeled section in the specimen, just like nodes, lobes, and AIML.
    # Every field is serialized. On load, section 4.26 restores it.
    # NO SILENT FAILURES: if serialization fails, the operator is told.
    try
        _dcfg = InputDecomposer.get_config()
        specimen["decomposer_config"] = _decomposer_config_to_dict(_dcfg)
        _dcfg_n = length(_dcfg.split_conjunctions) + length(_dcfg.command_markers) + length(_dcfg.conjugation_rules)
        println("  ✂️  Decomposer config saved: $_dcfg_n total entries across 6 fields")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize decomposer config: $e"
        println("  ❌ Decomposer config: FAILED to serialize! $e")
        println("     Decomposer config will NOT be in this save file!")
    end

    # ── 26. VIGILANCE CONFIG (v7.29) ────────────────────────────────────────
    # GRUG: FIRST-CLASS SAVE TREATMENT. The vigilance config controls how many
    # context injector agents get dispatched per cycle. Losing these on reload
    # means the specimen forgets its vigilance tuning — wrong agent count,
    # wrong thresholds, wrong feedback probability. Specimen personality changes
    # silently. That IS a bug. Now it's a saved section.
    try
        specimen["vigilance_config"] = EphemeralAutomaton.serialize_vigilance_config()
        println("  👁  Vigilance config saved (cap=$(EphemeralAutomaton.get_automaton_max_cap()))")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize vigilance config: $e"
        println("  ❌ Vigilance config: FAILED to serialize! $e")
    end

    # ── 27. INJECTOR STATS (v7.29) ───────────────────────────────────────────
    # GRUG: Injector lifetime stats — how many agents dispatched, completed,
    # timed out, entries injected, feedback written. Useful for diagnostics
    # and for the specimen to "remember" its own vigilance history.
    try
        specimen["injector_stats"] = EphemeralAutomaton.serialize_injector_stats()
        println("  📊  Injector stats saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize injector stats: $e"
    end

    # ── 28. RELATIONAL JITTER CONFIG (v7.29) ────────────────────────────────
    # GRUG: _JITTER_RATIO, _JITTER_COIN_RATIO, _JITTER_ENABLED are Refs that
    # can be tuned at runtime. Losing them on reload means the specimen forgets
    # its jitter calibration. That IS a missing lever. Now saved.
    try
        specimen["relational_jitter_config"] = Dict{String, Any}(
            "jitter_ratio"      => RelationalJitter._JITTER_RATIO[],
            "jitter_coin_ratio" => RelationalJitter._JITTER_COIN_RATIO[],
            "jitter_enabled"    => RelationalJitter._JITTER_ENABLED[]
        )
        println("  🎲  Relational jitter config saved (ratio=$(RelationalJitter._JITTER_RATIO[]), coin=$(RelationalJitter._JITTER_COIN_RATIO[]), enabled=$(RelationalJitter._JITTER_ENABLED[]))")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize relational jitter config: $e"
        println("  ❌ Relational jitter config: FAILED to serialize! $e")
    end

    # ── 29. BRAINSTEM CONFIG (v7.29) ────────────────────────────────────────
    # GRUG: BrainStem knobs — PROPAGATION_DECAY, FIRE_COUNT_DECAY_FACTOR,
    # FIRE_COUNT_DECAY_INTERVAL, PROPAGATION_MIN_CONFIDENCE. These are const
    # but SHOULD be specimen-overridable. For now, save current values as
    # baseline. Future: make them Refs for runtime tuning.
    try
        specimen["brainstem_config"] = Dict{String, Any}(
            "propagation_decay"          => BrainStem.PROPAGATION_DECAY,
            "fire_count_decay_factor"    => BrainStem.FIRE_COUNT_DECAY_FACTOR,
            "fire_count_decay_interval"  => BrainStem.FIRE_COUNT_DECAY_INTERVAL,
            "propagation_min_confidence" => BrainStem.PROPAGATION_MIN_CONFIDENCE
        )
        println("  🧠  BrainStem config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize brainstem config: $e"
    end

    # ── 30. ENGINE CONFIG (v7.29) ────────────────────────────────────────────
    # GRUG: Engine knobs — STRENGTH_CAP, STRENGTH_FLOOR, STRENGTH_SOLIDIFY_THRESHOLD,
    # JITTER_CONFIDENCE_FLOOR, MAX_NEIGHBORS, LATCH_PARTNER_CAP_MIN/MAX.
    # These are const but define specimen personality. Save as baseline.
    try
        specimen["engine_config"] = Dict{String, Any}(
            "strength_cap"                => STRENGTH_CAP,
            "strength_floor"              => STRENGTH_FLOOR,
            "strength_solidify_threshold" => STRENGTH_SOLIDIFY_THRESHOLD,
            "jitter_confidence_floor"     => JITTER_CONFIDENCE_FLOOR,
            "max_neighbors"               => MAX_NEIGHBORS,
            "latch_partner_cap_min"       => LATCH_PARTNER_CAP_MIN,
            "latch_partner_cap_max"       => LATCH_PARTNER_CAP_MAX,
            "antimatch_drain_fixed"       => ANTIMATCH_DRAIN_FIXED,
            "antimatch_drain_max_jitter"  => ANTIMATCH_DRAIN_MAX_JITTER
        )
        println("  ⚙️  Engine config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize engine config: $e"
    end

    # ── 31. LOBE ORCHESTRATOR KNOBS (v7.29) ──────────────────────────────────
    # GRUG: VoteOrchestrator / LobeOrchestrator knobs. These ARE the scoring
    # weights that determine which nodes win elections. Losing them silently
    # changes specimen personality. CRITICAL to persist.
    try
        specimen["lobe_orchestrator_knobs"] = Dict{String, Any}(
            "hard_fire_batch_cap"           => LobeOrchestrator.HARD_FIRE_BATCH_CAP,
            "min_pass_through_score"        => LobeOrchestrator.MIN_PASS_THROUGH_SCORE,
            "min_winning_votes_per_lobe"     => LobeOrchestrator.MIN_WINNING_VOTES_PER_LOBE,
            "top_k_fraction"                => LobeOrchestrator.TOP_K_FRACTION,
            "hard_selection_conf_threshold" => LobeOrchestrator.HARD_SELECTION_CONF_THRESHOLD,
            "default_lobe_demotion_factor"  => LobeOrchestrator.DEFAULT_LOBE_DEMOTION_FACTOR
        )
        println("  🏛️  Lobe orchestrator knobs saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize lobe orchestrator knobs: $e"
    end

    # ── 32. VOTE ORCHESTRATOR KNOBS (v7.29) ──────────────────────────────────
    # GRUG: VoteOrchestrator scoring weights — these determine how AIML
    # candidates are ranked. Losing them changes response personality silently.
    try
        specimen["vote_orchestrator_knobs"] = Dict{String, Any}(
            "aiml_confidence_threshold" => VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
            "aiml_top_tier_window"      => VoteOrchestrator.AIML_TOP_TIER_WINDOW,
            "aiml_subtop_base_prob"     => VoteOrchestrator.AIML_SUBTOP_BASE_PROB,
            "aiml_subtop_bonus_prob"    => VoteOrchestrator.AIML_SUBTOP_BONUS_PROB,
            "vote_w_lobe_alignment"     => VoteOrchestrator.VOTE_W_LOBE_ALIGNMENT,
            "vote_w_relational_match"   => VoteOrchestrator.VOTE_W_RELATIONAL_MATCH,
            "vote_w_recency_bonus"      => VoteOrchestrator.VOTE_W_RECENCY_BONUS,
            "vote_w_action_tone_align"  => VoteOrchestrator.VOTE_W_ACTION_TONE_ALIGN,
            "vote_w_anti_match_penalty" => VoteOrchestrator.VOTE_W_ANTI_MATCH_PENALTY,
            "vote_w_peak_dominance"     => VoteOrchestrator.VOTE_W_PEAK_DOMINANCE,
            "vote_bonus_cap"            => VoteOrchestrator.VOTE_BONUS_CAP,
            "vote_score_floor"          => VoteOrchestrator.VOTE_SCORE_FLOOR,
            "active_fire_cap"           => VoteOrchestrator.ACTIVE_FIRE_CAP,
            "fire_batch_size"           => VoteOrchestrator.FIRE_BATCH_SIZE
        )
        println("  🗳️  Vote orchestrator knobs saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize vote orchestrator knobs: $e"
    end

    # ── 33. MITOSIS CONFIG (v7.29) ───────────────────────────────────────────
    # GRUG: Mitosis knobs — stochastic probability, population cap, warrant
    # thresholds. These control node growth. Losing them = different growth
    # behavior on reload. Specimen personality change.
    try
        specimen["mitosis_config"] = Dict{String, Any}(
            "mitosis_probability"         => MitosisMode.MITOSIS_PROBABILITY,
            "data_energy_msg_scale"       => MitosisMode.DATA_ENERGY_MSG_SCALE,
            "data_energy_intensity_scale" => MitosisMode.DATA_ENERGY_INTENSITY_SCALE,
            "max_mitosis_per_cycle"       => MitosisMode.MAX_MITOSIS_PER_CYCLE,
            "min_population_gate"         => MitosisMode.MIN_POPULATION_GATE,
            "max_population_cap"          => MitosisMode.MAX_POPULATION_CAP,
            "mitosis_cooldown_cycles"     => MitosisMode.MITOSIS_COOLDOWN_CYCLES,
            "silence_warrant_threshold"   => MitosisMode.SILENCE_WARRANT_THRESHOLD,
            "silence_warrant_min_accum"   => MitosisMode.SILENCE_WARRANT_MIN_ACCUM,
            "frequency_warrant_min"       => MitosisMode.FREQUENCY_WARRANT_MIN,
            "thesaurus_warrant_threshold" => MitosisMode.THESAURUS_WARRANT_THRESHOLD,
            "lobe_coverage_ratio_min"     => MitosisMode.LOBE_COVERAGE_RATIO_MIN,
            "min_warrant_threshold"       => MitosisMode.MIN_WARRANT_THRESHOLD,
            "mitosis_strength_default"    => MitosisMode.MITOSIS_STRENGTH_DEFAULT,
            "pattern_sim_floor"           => MITOSIS_PATTERN_SIM_FLOOR,
            "vote_sim_floor"              => MITOSIS_VOTE_SIM_FLOOR,
            "group_max_occupancy"          => GROUP_MAX_OCCUPANCY,
            "strain_warrant_weight"        => MitosisMode.STRAIN_WARRANT_WEIGHT,
            "strain_warrant_active_threshold" => MitosisMode.STRAIN_WARRANT_ACTIVE_THRESHOLD
        )
        println("  🧬  Mitosis config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize mitosis config: $e"
    end

    # ── 33b. GROWTH AUTOMATON CONFIG ──────────────────────────────────────
    # GRUG: Growth automaton knobs — batch size, probability ceiling, strength
    # floor, min fresh entries. These control idle-time node growth. Losing
    # them = different growth behavior on reload.
    try
        specimen["growth_config"] = Dict{String, Any}(
            "growth_batch_size"        => TemporalGrowth.GROWTH_BATCH_SIZE,
            "growth_probability_ceiling" => TemporalGrowth.GROWTH_PROBABILITY_CEILING,
            "group_strength_floor"     => TemporalGrowth.GROUP_STRENGTH_FLOOR,
            "min_fresh_entries"        => TemporalGrowth.MIN_FRESH_ENTRIES,
            "data_energy_msg_scale"    => TemporalGrowth.DATA_ENERGY_MSG_SCALE,
            "growth_node_strength"     => TemporalGrowth.GROWTH_NODE_STRENGTH,
        )
        println("  🌱  Growth automaton config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize growth config: $e"
    end

    # ── 34. PHAGY CONFIG (v7.29) ─────────────────────────────────────────────
    # GRUG: Phagy knobs — decay rate, orphan threshold, trim floors. These
    # control node cleanup. Losing them = different cleanup behavior on reload.
    try
        specimen["phagy_config"] = Dict{String, Any}(
            "orphan_max_neighbors"   => PhagyMode.ORPHAN_MAX_NEIGHBORS,
            "decay_rate"            => PhagyMode.DECAY_RATE,
            "decay_eligibility_max" => PhagyMode.DECAY_ELIGIBILITY_MAX,
            "drop_table_trim_floor" => PhagyMode.DROP_TABLE_TRIM_FLOOR,
            "rule_dormancy_cycles"  => PhagyMode.RULE_DORMANCY_CYCLES
        )
        println("  🦠  Phagy config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize phagy config: $e"
    end

    # ── 35. CHATTER CONFIG (v7.29) ───────────────────────────────────────────
    # GRUG: ChatterMode knobs — population thresholds, floor values, intensity
    # cap, weight parameters. These control spontaneous chatter behavior.
    try
        specimen["chatter_config"] = Dict{String, Any}(
            "min_population_for_chatter"     => ChatterMode.MIN_POPULATION_FOR_CHATTER,
            "idle_threshold_seconds"         => ChatterMode.IDLE_THRESHOLD_SECONDS,
            "idle_jitter_seconds"            => ChatterMode.IDLE_JITTER_SECONDS,
            "chatter_group_sample_min"      => ChatterMode.CHATTER_GROUP_SAMPLE_MIN,
            "chatter_group_sample_max"      => ChatterMode.CHATTER_GROUP_SAMPLE_MAX,
            "chatter_weak_floor"             => ChatterMode.CHATTER_WEAK_FLOOR,
            "chatter_strong_floor"           => ChatterMode.CHATTER_STRONG_FLOOR,
            "chatter_grave_floor"            => ChatterMode.CHATTER_GRAVE_FLOOR,
            "chatter_weight_jitter_sigma"    => ChatterMode.CHATTER_WEIGHT_JITTER_SIGMA,
            "strong_low_conf_override"       => ChatterMode.STRONG_LOW_CONF_OVERRIDE,
            "morph_cooldown_seconds"         => ChatterMode.MORPH_COOLDOWN_SECONDS
        )
        println("  💬  Chatter config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize chatter config: $e"
    end

    # ── 36. IMMUNE CONFIG (v7.29) ─────────────────────────────────────────────
    # GRUG: Immune system knobs — maturity threshold, coinflip probability,
    # patch timeout. These control when the immune system activates.
    try
        specimen["immune_config"] = Dict{String, Any}(
            "maturity_threshold"            => ImmuneSystem.MATURITY_THRESHOLD,
            "automata_population_ratio"     => string(ImmuneSystem.AUTOMATA_POPULATION_RATIO),
            "coinflip_probability"          => ImmuneSystem.COINFLIP_PROBABILITY,
            "patch_timeout_seconds"         => ImmuneSystem.PATCH_TIMEOUT_SECONDS,
            "patch_timeout_jitter"          => ImmuneSystem.PATCH_TIMEOUT_JITTER,
            "max_ledger_entries"            => ImmuneSystem.MAX_LEDGER_ENTRIES,
            "max_quarantine_size"           => ImmuneSystem.MAX_QUARANTINE_SIZE,
            "hopfield_familiarity_threshold" => ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD
        )
        println("  🛡️  Immune config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize immune config: $e"
    end



    # ── 37. FULL LOBE SCANNER CONFIG (v7.29) ────────────────────────────────
    # GRUG: Scanner knobs — max active nodes, confidence thresholds. These
    # control how aggressively the scanner lights up nodes and when it considers
    # a match "good enough". Without persistence, specimen forgets its scan tuning.
    try
        specimen["scanner_config"] = Dict{String, Any}(
            "max_active_nodes"           => FullLobeScanner.MAX_ACTIVE_NODES,
            "confident_threshold"        => FullLobeScanner.CONFIDENT_THRESHOLD,
            "default_candidate_threshold"=> FullLobeScanner.DEFAULT_CANDIDATE_THRESHOLD
        )
        println("  🔭  Scanner config saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize scanner config: $e"
    end

    # ── 38. ACTION TONE PREDICTOR KNOBS (v7.29) ─────────────────────────────
    # GRUG: ActionTonePredictor threshold knobs — low signal fallback, damp
    # threshold, escalation floor, incoherence tag, curve jitter. Trajectory
    # config is already saved in section 7 ("trajectory") but these const knobs
    # were NOT persisted. Without them, specimen forgets its tripwire tuning.
    try
        specimen["action_tone_knobs"] = Dict{String, Any}(
            "incoherence_tag_threshold"  => ActionTonePredictor.INCOHERENCE_TAG_THRESHOLD,
            "low_signal_threshold"       => ActionTonePredictor.LOW_SIGNAL_THRESHOLD,
            "fallback_damp_threshold"    => ActionTonePredictor.FALLBACK_DAMP_THRESHOLD,
            "curve_jitter_envelope"      => ActionTonePredictor.CURVE_JITTER_ENVELOPE,
            "escalation_confidence_floor"=> ActionTonePredictor.ESCALATION_CONFIDENCE_FLOOR
        )
        println("  🎯  ActionTone knobs saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize action tone knobs: $e"
    end


    # ── 39. CO-ACTIVATION ACCUMULATOR (RelationalGovernance) ──────────────────
    # GRUG: Save the co-activation pairs so specimen remembers which nodes
    # fire together. Without this, reload starts with zero accumulated intensity
    # and all those slowly-earned organic bonds are lost. Moss must persist.
    try
        specimen["co_activation"] = RelationalGovernance.serialize_co_activation()
        println("  🔗  Co-activation accumulator saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize co-activation accumulator: $e"
    end
    # GRUG: Serialize the InputLedger hash state so we don't re-process
    # old messages on reload. The ledger tracks which MESSAGE_HISTORY
    # entries have been consumed. Without this, reload starts with a
    # blank ledger and the thread would re-digest every old message.
    try
        specimen["input_ledger"] = InputLedger.serialize_input_ledger()
        println("  📝  Input ledger saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize input ledger: $e"
    end
    # GRUG: Serialize the ChatterResiduals hash state so we don't re-process
    # old swaps on reload. The ledger tracks which CHATTER_LOG swaps have
    # been consumed. Without this, reload re-mines all old swaps.
    try
        specimen["chatter_residuals"] = ChatterResiduals.serialize_chatter_residuals()
        println("  🔮  Chatter residuals saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize chatter residuals: $e"
    end

    # ── 39b. AUTOGROWTH EVIDENCE + CO-OCCURRENCE ──────────────────────
    # GRUG: Save the evidence accumulator + co-occurrence map so the
    # auto-learning system picks up where it left off on reload. Without
    # this, reload starts with zero evidence and all the slowly-accumulated
    # gap observations are lost. Evidence of gaps IS the fuel for growth.
    try
        specimen["autogrowth_evidence"] = AutoGrowth.get_evidence_snapshot()
        specimen["autogrowth_co_occur"] = AutoGrowth.get_co_occur_snapshot()
        _ev_count = length(specimen["autogrowth_evidence"])
        _co_count = length(specimen["autogrowth_co_occur"])
        println("  🌱  AutoGrowth evidence saved (evidence=$_ev_count, co-occur=$_co_count)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize autogrowth evidence: $e"
    end

    # ── 39c. AUTOLINKER LINK EVIDENCE ───────────────────────────────────
    # GRUG: Save the link evidence accumulator so the auto-linker picks up
    # where it left off on reload. Link evidence is expensive to accumulate
    # (many co-firing observations) so we don't want to lose it.
    try
        specimen["autolink_evidence"] = AutoLinker.get_link_evidence_snapshot()
        _al_count = length(specimen["autolink_evidence"])
        println("  🔗  AutoLinker evidence saved (link_evidence=$_al_count)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize autolink evidence: $e"
    end

    # ── 39d. FLASHCARD DATA ──────────────────────────────────────────────
    # GRUG v10: Save flashcards from all lobes. Math facts like "3+5=8"
    # are stored as lookup table entries, not nodes. Without persisting
    # them, reload forgets every math fact Grug ever learned.
    try
        # BUGFIX (specimen-build-v3): serialize_flashcards() takes NO args and
        # returns ALL lobes at once (Dict lobe_id => Vector{card}). The previous
        # per-lobe loop passed a lobe_id positionally, hitting a MethodError on
        # the first lobe and aborting the entire flashcard-save block — so NO
        # flashcards were ever persisted. Call it once and use the result.
        _fc_all = Dict{String, Any}()
        _fc_count = 0
        _fc_serialized = LobeTable.serialize_flashcards()
        for (lobe_id, _fc_data) in _fc_serialized
            if !isempty(_fc_data)
                _fc_all[lobe_id] = _fc_data
                _fc_count += length(_fc_data)
            end
        end
        if _fc_count > 0
            specimen["flashcards"] = _fc_all
            println("  📇  Flashcards saved ($_fc_count cards across $(length(_fc_all)) lobes)")
        else
            println("  📇  Flashcards: none to save")
        end
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize flashcards: $e"
    end

    # ── 39e. CURIOSITY ACCUMULATOR ───────────────────────────────────────
    # GRUG v10: Save curiosity accumulator state so Grug doesn't lose
    # its sense of wonder on reload. The intensity, buffer, and quench
    # timestamp all need to survive specimen round-trips.
    try
        specimen["curiosity"] = AutoGrowth.serialize_curiosity()
        _cur_data = specimen["curiosity"]
        _cur_int = get(_cur_data, "intensity", 0.0)
        _cur_buf_len = length(get(_cur_data, "buffer", []))
        println("  🔥  Curiosity saved (intensity=$(round(_cur_int, digits=2)), buffer=$_cur_buf_len)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize curiosity: $e"
    end


    # ── 40. FAN-OUT CONFIG ──────────────────────────────────────────────────────
    # GRUG: Fan-out creates shadow answer nodes. If we don't persist these
    # settings, a specimen reloaded with fan-out disabled loses all shadow
    # behavior, and one reloaded with a different max_shadows changes behavior.
    try
        specimen["fanout_config"] = Dict{String,Any}(
            "enabled"      => _FANOUT_ENABLED[],
            "max_shadows"  => _FANOUT_MAX_SHADOWS[],
            "modes"        => collect(_FANOUT_MODES)
        )
        println("  🪭  Fan-out config saved (enabled=$(_FANOUT_ENABLED[]), max=$(_FANOUT_MAX_SHADOWS[]), modes=$(length(_FANOUT_MODES)))")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize fan-out config: $e"
    end

    # ── 41. HIPPOCAMPAL PENDING ASK ──────────────────────────────────────────────
    # GRUG: If grug asked the user a question and is waiting for an answer,
    # the pending ask text must survive reload. Otherwise grug forgets it
    # asked and the answer lands in a vacuum.
    try
        lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
            specimen["hippocampal_pending_ask"] = Dict{String,Any}(
                "pending_text" => _HIPPOCAMPAL_PENDING_ASK[]
            )
        end
        println("  🧠  Hippocampal pending ask saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize hippocampal pending ask: $e"
    end

    # ── 42. ADMIN SESSION ────────────────────────────────────────────────────────
    # GRUG: Admin session state (login status + timestamps). On reload the
    # session is always reset to logged-out for safety — but we save it so
    # the load function can detect an active session and warn about it.
    try
        specimen["admin_session"] = Dict{String,Any}(
            "is_logged_in"  => ADMIN_SESSION[].is_logged_in,
            "login_time"    => ADMIN_SESSION[].login_time,
            "last_activity" => ADMIN_SESSION[].last_activity
        )
        println("  🔐  Admin session saved")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize admin session: $e"
    end

    # ── 43. LOBE ORCHESTRATOR LAST STATE ─────────────────────────────────────────
    # GRUG: LAST_LOBE_SCORES/WINNER/PASSTHROUGH drive the next-cycle scoring
    # bias. Without these, reload loses the momentum of which lobe was winning
    # and the first post-reload cycle scores naively.
    try
        _lls, _lls_winner, _lls_passthrough = LobeOrchestrator.get_last_state()
        specimen["lobe_orch_last"] = Dict{String,Any}(
            "scores"      => [_lls_item_to_dict(t) for t in _lls],
            "winner"      => _lls_winner,
            "passthrough" => _lls_passthrough
        )
        println("  🎭  Lobe orchestrator last state saved (winner=$(_lls_winner))")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize lobe orchestrator last state: $e"
    end

    # ── 44. CHATTER CURSOR ───────────────────────────────────────────────────────
    # GRUG: The chatter cursor tracks how far through CHATTER_LOG the residual
    # scanner has read. Without persisting it, reload re-mines all old swaps.
    try
        specimen["chatter_cursor"] = Dict{String,Any}(
            "cursor" => ChatterMode.CHATTER_CURSOR[]
        )
        println("  🔖  Chatter cursor saved (pos=$(ChatterMode.CHATTER_CURSOR[]))")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize chatter cursor: $e"
    end

    # ── 45. ANSWER MODE CONFIG ───────────────────────────────────────────────────
    # GRUG: _ANSWER_MODE_CONFIG defines how each answer mode maps to action,
    # voice, frame, prompt. Custom modes added at runtime would be lost.
    # We save the whole dict so reload preserves any customizations.
    try
        specimen["answer_mode_config"] = _ANSWER_MODE_CONFIG
        println("  📋  Answer mode config saved ($(length(_ANSWER_MODE_CONFIG)) modes)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize answer mode config: $e"
    end

    # ── 46. PHAGY RULES REF ──────────────────────────────────────────────────────
    # GRUG: PHAGY_RULES_REF holds the live orchestration rules for the rule
    # pruner automaton. Without these, reload loses all dynamically-added
    # rules and the pruner has nothing to work on.
    try
        specimen["phagy_rules_ref"] = PHAGY_RULES_REF[]
        println("  🦠  Phagy rules ref saved ($(length(PHAGY_RULES_REF[])) rules)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize phagy rules ref: $e"
    end
    # ── 47. TIME ORIENTATION CONFIG (v8.1) ───────────────────────────────────
    # GRUG v8.1: Save the global time orientation state. When a time sigil
    # (&now/&before/&next) was active at save time, the orientation and its
    # metadata survive reload. Also save a per-node time orientation index
    # so the engine can reconnect time nodes to their sigils on reload.
    try
        _time_orient, _time_meta = current_time_orientation()
        specimen["time_orientation_config"] = Dict{String,Any}(
            "global_orientation" => _time_orient,
            "global_meta"       => _time_meta,
            # GRUG v8.1: Build an index of all time nodes with their orientations.
            # This lets the load path reconnect nodes to time sigils.
            "time_node_index"   => begin
                _tni = Dict{String,Any}()
                lock(NODE_LOCK) do
                    for (nid, node) in NODE_MAP
                        if get(node.json_data, "time_node", false) && haskey(node.json_data, "time_orientation")
                            _tni[nid] = Dict{String,Any}(
                                "orientation" => node.json_data["time_orientation"],
                                "sigil"       => get(node.json_data, "time_sigil", ""),
                                "pattern"     => node.pattern
                            )
                        end
                    end
                end
                _tni
            end
        )
        _tni_count = length(specimen["time_orientation_config"]["time_node_index"])
        println("  ⏳  Time orientation config saved (global=$_time_orient, $_tni_count oriented time nodes)")
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize time orientation config: $e"
    end


    # ── 26. COHERENCE FIELD CONFIG ──────────────────────────────────────────
    # GRUG v9: Save the CoherenceField config so routing weight survives reload.
    # Weight=0.0 (off) by default; only non-default values are saved.
    try
        _cf_cfg = CoherenceField.coherence_config_to_dict()
        if !isempty(_cf_cfg)
            specimen["coherence_config"] = _cf_cfg
            println("  🔗  CoherenceField config saved (weight=$(_cf_cfg["weight"]))")
        end
    catch e
        @warn "[MAIN] save_specimen: FAILED to serialize coherence config: $e"
    end


    # ── SERIALIZE ────────────────────────────────────────────────────
    # GRUG: Convert to JSON string. If filepath ends in .gz, gzip compress.
    # If .json (or anything else), write plain JSON — no gzip needed, works
    # on Windows without any extra CLI tools. Grug like cross-platform.
    json_str = JSON.json(specimen, 2)  # pretty-print with indent=2
    is_gz = lowercase(strip(filepath)[max(1, end-2):end]) == ".gz"

    try
        if is_gz
            proc = open(`gzip -c`, "r+")
            write(proc, json_str)
            close(proc.in)
            compressed = read(proc)
            open(filepath, "w") do io
                write(io, compressed)
            end
        else
            open(filepath, "w") do io
                write(io, json_str)
            end
        end
    catch e
        error("!!! FATAL: /saveSpecimen failed to write file '$filepath': $e !!!")
    end

    elapsed = round(time() - t_start, digits=2)
    file_size = filesize(filepath)
    json_size = sizeof(json_str)
    ratio = is_gz && json_size > 0 ? round(100.0 * (1.0 - file_size / json_size), digits=1) : 0.0

    # GRUG: Build the victory scroll
    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(lines, "║            🧊 SPECIMEN SAVED SUCCESSFULLY                    ║")
    push!(lines, "╠══════════════════════════════════════════════════════════════╣")
    push!(lines, "  📁  File             : $filepath")
    push!(lines, "  📦  JSON size        : $(json_size) bytes")
    if is_gz
        push!(lines, "  🗜️   Compressed size  : $(file_size) bytes ($(ratio)% smaller)")
    else
        push!(lines, "  📄  File size        : $(file_size) bytes (plain JSON)")
    end
    push!(lines, "  ⏱️   Time             : $(elapsed)s")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🌱  Nodes            : $(length(node_list))")
    push!(lines, "  🧠  Lobes            : $(length(lobe_list))")
    push!(lines, "  💎  Phase Accumulator      : $(try Int(get(EphemeralAutomaton.phase_pull_status(), "crystal_size", 0)) catch _ 0 end) snapshots")
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
    push!(lines, "  ⏳  Time orientation   : $(try get(specimen["time_orientation_config"], "global_orientation", "none") catch _ "none" end) (oriented nodes: $(try length(get(specimen["time_orientation_config"], "time_node_index", Dict())) catch _ 0 end))")
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
    push!(lines, "  🪄  Sigil entries    : $(length(sigil_list))")
    push!(lines, "  ⚙️  Automaton rules  : $(length(automaton_list))")
    push!(lines, "  🗳  Contributor votes : $(length(vote_list))")
    push!(lines, "  🎭  Tonal knobs      : saved")
    push!(lines, "  👁   Arousal          : $(arousal_data["level"])")
    _ag_ev = try length(get(specimen, "autogrowth_evidence", [])) catch _ 0 end
    _ag_co = try length(get(specimen, "autogrowth_co_occur", [])) catch _ 0 end
    push!(lines, "  🌱  AutoGrowth       : evidence=$(_ag_ev), co-occur=$(_ag_co)")
    _al_ev = try length(get(specimen, "autolink_evidence", [])) catch _ 0 end
    push!(lines, "  🔗  AutoLinker       : link_evidence=$(_al_ev)")
    _fc_total = try
        sum(LobeTable.flashcard_count(lid) for (lid, _) in Lobe.LOBE_REGISTRY)
    catch _
        0
    end
    push!(lines, "  📇  Flashcards      : $_fc_total")
    _cur_int = try
        round(get(AutoGrowth.get_curiosity_status(), "intensity", 0.0), digits=2)
    catch _
        0.0
    end
    push!(lines, "  🔥  Curiosity       : intensity=$_cur_int")
    push!(lines, "╚══════════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end


"""
load_specimen_from_file!(filepath::String)::String

GRUG: Read a JSON (.json) or gzip-compressed (.gz) specimen file and RESTORE the ENTIRE cave state.
Auto-detects format by file extension. .json files work on Windows without gzip.
This is a DESTRUCTIVE operation — current cave state is WIPED and replaced with
the specimen contents. Think of it as brain transplant, not brain addition.

Phase 1: Read + decompress + parse the file
Phase 2: Validate the entire specimen structure
Phase 3: WIPE all current mutable state
Phase 4: RESTORE all state from specimen
Phase 5: Build summary scroll

Returns a multi-line summary string of everything restored.
"""
# GRUG FIX (v7.43): JSON.parse returns JSON.Object{String,Any}, NOT Dict{String,Any}.
# JSON.Object IS a subtype of AbstractDict, so isa(x, AbstractDict) works for both.
# All isa(x, Dict) checks in the specimen load path were silently failing for
# JSON.Object values, causing guard clauses to skip their blocks.
# Helper: accept both Dict and JSON.Object as "dictionary-like".
_is_dict_like(x) = isa(x, AbstractDict)

function load_specimen_from_file!(filepath::String)::String
    if strip(filepath) == ""
        error("!!! FATAL: /loadSpecimen got empty filepath! Grug needs a file to thaw! !!!")
    end

    if !isfile(filepath)
        error("!!! FATAL: /loadSpecimen file not found: '$filepath'! Check path and try again! !!!")
    end

    # GRUG v7.58: Record specimen path for save-on-exit prompt.
    lock(_LAST_SPECIMEN_PATH_LOCK) do
        _LAST_SPECIMEN_PATH[] = filepath
    end

    t_start = time()
    file_size = filesize(filepath)

    # ══════════════════════════════════════════════════════════════════════
    # ════════════════════════════════════════════════════════════════════════
    # PHASE 1: READ + PARSE (auto-detect .gz vs .json)
    # ════════════════════════════════════════════════════════════════════════

    # GRUG: If filepath ends in .gz, decompress via gunzip pipeline.
    # Otherwise read as plain JSON — works on Windows without gzip CLI.
    # Grug like cross-platform. If extension is ambiguous, try gunzip
    # first (backward compat with old .specimen.gz files), fall back
    # to plain JSON if that fails.
    is_gz = lowercase(strip(filepath)[max(1, end-2):end]) == ".gz"
    json_str = if is_gz
        try
            compressed_bytes = read(filepath)
            proc = open(`gunzip -c`, "r+")
            write(proc, compressed_bytes)
            close(proc.in)
            String(read(proc))
        catch e
            error("!!! FATAL: /loadSpecimen failed to decompress '$filepath': $e !!!")
        end
    else
        try
            read(filepath, String)
        catch e
            # Fallback: maybe it's actually gzipped despite no .gz extension
            try
                compressed_bytes = read(filepath)
                proc = open(`gunzip -c`, "r+")
                write(proc, compressed_bytes)
                close(proc.in)
                String(read(proc))
            catch e2
                error("!!! FATAL: /loadSpecimen failed to read '$filepath': $e !!!")
            end
        end
    end

    if strip(json_str) == ""
        error("!!! FATAL: /loadSpecimen file is empty! Bad specimen jar! !!!")
    end

    specimen = try
        JSON.parse(json_str)
    catch e
        error("!!! FATAL: /loadSpecimen JSON parse failed after decompression: $e !!!")
    end

    if !_is_dict_like(specimen)
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
                        "arousal", "eye_state", "id_counters", "last_voters", "brainstem",
                        "bridges", "attachments",      # GRUG v8.0: bridges (bidirectional) + attachments (backward compat)
                        "trajectory", "temporal_coherence", "morph_cooldowns", "immune_system", "aiml_system", "_meta",
                        "chatter_groups", "chatter_cooldowns",
                        "sigil_table", "automaton_rules", "last_contributor_votes", "node_to_group_idx", "tonal_judge_knobs",
                        "ephemeral_mlp", "mlp_observer_store", "mlp_cached_phi",
                        "phase_accumulator", "format", "version", "decomposer_config",
                        "vigilance_config", "injector_stats", "relational_jitter_config",
                        "brainstem_config", "engine_config", "lobe_orchestrator_knobs",
                        "vote_orchestrator_knobs", "mitosis_config", "growth_config", "phagy_config",
                        "chatter_config", "immune_config",
                        "scanner_config", "action_tone_knobs",
                        "co_activation", "input_ledger", "chatter_residuals",
                        "fanout_config", "hippocampal_pending_ask", "admin_session",
                        "lobe_orch_last", "chatter_cursor", "answer_mode_config",
                        "phagy_rules_ref",
                        "time_orientation_config",
                        "coherence_config",
                        "autogrowth_evidence", "autogrowth_co_occur",
                        "autolink_evidence",
                        "flashcards", "curiosity"])
    for key in keys(specimen)
        if !(key in allowed_keys)
            push!(validation_errors, "Unknown top-level key '$key'")
        end
    end

    # GRUG: Type checks for critical array sections
    for k in ["nodes", "hopfield_cache", "rules", "message_history", "lobes", "lobe_tables", "inhibitions", "temporal_coherence", "bridges", "attachments"]
        if haskey(specimen, k) && !isa(specimen[k], AbstractVector)
            push!(validation_errors, "'$k' must be an array")
        end
    end

    # GRUG: Type checks for critical dict sections
    for k in ["node_to_lobe_idx", "verb_registry", "thesaurus_seeds", "arousal", "eye_state", "id_counters", "brainstem",
             "trajectory", "morph_cooldowns", "immune_system", "aiml_system", "_meta",
             "phase_accumulator", "decomposer_config",
             "vigilance_config", "injector_stats", "relational_jitter_config",
             "brainstem_config", "engine_config", "lobe_orchestrator_knobs",
             "vote_orchestrator_knobs", "mitosis_config", "growth_config", "phagy_config",
             "chatter_config", "immune_config",
             "scanner_config", "action_tone_knobs",
             "fanout_config", "hippocampal_pending_ask", "admin_session",
             "lobe_orch_last", "chatter_cursor", "answer_mode_config", "time_orientation_config",
             "coherence_config", "mlp_cached_phi"]
        if haskey(specimen, k) && !_is_dict_like(specimen[k])
            push!(validation_errors, "'$k' must be an object")
        end
    end

    # GRUG: Validate nodes have required fields (spot-check first 5)
    if haskey(specimen, "nodes") && isa(specimen["nodes"], AbstractVector)
        for (i, nd) in enumerate(specimen["nodes"])
            i > 5 && break
            if !_is_dict_like(nd)
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
    lock(_DROP_TABLE_LOCK) do; empty!(AIML_DROP_TABLE) end

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

    # Wipe bridges (cascade bridge system)
    lock(BRIDGE_LOCK) do
        empty!(BRIDGE_MAP)
    end

    # GRUG (v7.19): Wipe chatter groups and per-node chatter cooldowns.
    # Specimen brings its own group state (or none for pre-v7.19 saves).
    lock(GROUP_LOCK) do
        empty!(GROUP_MAP)
        empty!(NODE_TO_GROUP)
    end
    GROUP_COUNTER[] = 0
    lock(CHATTER_NODE_COOLDOWN_LOCK) do
        empty!(CHATTER_NODE_COOLDOWN)
    end
    # BUG-011: Clear permanent chatter mutation registry on full reset.
    lock(CHATTER_MUTATED_SET_LOCK) do
        empty!(CHATTER_MUTATED_SET)
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

    # Wipe sigil table back to engine defaults
    # GRUG: Specimen may have merged custom lexicons; reset to clean slate.
    SigilRegistry.clear_registry!(_ENGINE_SIGIL_TABLE)
    # Re-register engine-default sigils (bare table after clear)
    for entry in SigilRegistry.default_registry().entries
        _ENGINE_SIGIL_TABLE.entries[entry.first] = entry.second
    end

    # Wipe ephemeral automaton registry
    lock(EphemeralAutomaton._AUTOMATON_REGISTRY_LOCK) do
        empty!(EphemeralAutomaton._AUTOMATON_REGISTRY)
    end

    # Wipe last contributor votes
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_CONTRIBUTOR_VOTES)
    end

    # Wipe TonalJudge knobs back to defaults
    TonalJudge.set_frame_match_weights!(lift=1.20, inhibit=0.85)

    # Wipe vigilance config back to defaults (v7.29)
    EphemeralAutomaton._VIGILANCE_CONFIG[] = EphemeralAutomaton.VigilanceConfig()
    # Wipe active injectors
    lock(EphemeralAutomaton._INJECTOR_LOCK) do
        empty!(EphemeralAutomaton._ACTIVE_INJECTORS)
        EphemeralAutomaton._INJECTOR_STATS["total_dispatched"] = 0
        EphemeralAutomaton._INJECTOR_STATS["total_completed"] = 0
        EphemeralAutomaton._INJECTOR_STATS["total_timed_out"] = 0
        EphemeralAutomaton._INJECTOR_STATS["total_entries_injected"] = 0
        EphemeralAutomaton._INJECTOR_STATS["total_feedback_written"] = 0
        EphemeralAutomaton._INJECTOR_STATS["total_probe_keys"] = 0
    end

    # Wipe relational jitter config back to defaults (v7.29)
    RelationalJitter._JITTER_RATIO[] = RelationalJitter.JITTER_RATIO_DEFAULT
    RelationalJitter._JITTER_COIN_RATIO[] = RelationalJitter.JITTER_COIN_RATIO_DEFAULT
    RelationalJitter._JITTER_ENABLED[] = true

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
    if haskey(specimen, "eye_state") && _is_dict_like(specimen["eye_state"])
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
            if haskey(vr, "classes") && _is_dict_like(vr["classes"])
                for (cls, verbs) in vr["classes"]
                    SemanticVerbs._VERB_REGISTRY[String(cls)] = Set{String}(String.(verbs))
                    n_verb_classes += 1
                    n_verbs += length(verbs)
                end
            end
            # Restore synonyms
            if haskey(vr, "synonyms") && _is_dict_like(vr["synonyms"])
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
    if haskey(specimen, "thesaurus_seeds") && _is_dict_like(specimen["thesaurus_seeds"])
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
                        Float64(get(ldata, "created_at", time())),
                        Set{String}(String.(get(ldata, "subject_whitelist", String[]))),
                        String(get(ldata, "name", String(ldata["id"])))
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
                    if haskey(ltdata, "chunks") && _is_dict_like(ltdata["chunks"])
                        for (cname, entries) in ltdata["chunks"]
                            chunk = LobeTable.LobeTableChunk(
                                String(cname),
                                Dict{String, Any}(),
                                ReentrantLock()
                            )
                            if _is_dict_like(entries)
                                for (k, v) in entries
                                    if _is_dict_like(v) && get(v, "_type", "") == "NodeRef"
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

                    # GRUG v7.21c-2: Re-register any prose-slot actions in this
                    # node's action_packet. COMMANDS is a runtime dict (not
                    # serialized), so prose handlers must be rebuilt on load
                    # or the node's votes will TaskFailedException at vote-time.
                    try
                        ensure_action_packet_registered!(String(nd["action_packet"]))
                    catch e
                        @warn "[MAIN] load_specimen: failed to re-register prose action for node '$(get(nd, "id", "<?>"))': $e"
                    end

                    node = Node(
                        String(nd["id"]),
                        String(nd["pattern"]),
                        # GRUG: ALWAYS recompute signal from pattern on load.
                        # Old specimens stored random 8-element signals that don't
                        # match the pattern token count, causing BUG-004 mismatches
                        # (signal length ≠ pattern token count → forced cheap scan
                        # + penalty → node loses votes it should win). The hash-based
                        # signal is deterministic from the pattern text, so recomputing
                        # is both safe and correct. words_to_signal is in scope from
                        # engine.jl include.
                        words_to_signal(String(nd["pattern"])),
                        String(nd["action_packet"]),
                        Dict{String, Any}(string(k) => v for (k,v) in get(nd, "json_data", Dict())),
                        String.(get(nd, "drop_table", String[])),
                        Float64(get(nd, "throttle", 0.5)),
                        rel_patterns,
                        String.(get(nd, "required_relations", String[])),
                        Dict{String, Float64}(string(k) => Float64(v) for (k,v) in get(nd, "relation_weights", Dict())),
                        Float64(get(nd, "strength", 1.0)),
                        Bool(get(nd, "is_image_node", false)),
                        Bool(get(nd, "is_antimatch_node", false)),
                        String.(get(nd, "neighbor_ids", String[])),
                        Bool(get(nd, "is_unlinkable", false)),
                        # GRUG: max_neighbors — back-compat for old specimens that lack it.
                        # If missing, roll a fresh per-node cap so the loaded node still
                        # has heterogeneous capacity instead of inheriting the old uniform 4.
                        Int(get(nd, "max_neighbors", rand(LATCH_PARTNER_CAP_MIN:LATCH_PARTNER_CAP_MAX))),
                        Bool(get(nd, "is_grave", false)),
                        String(get(nd, "grave_reason", "")),
                        Float64.(get(nd, "response_times", Float64[])),
                        Float64(get(nd, "ledger_last_cleared", time())),
                        # GRUG: If hopfield_key is 0 or missing, regenerate from pattern.
                        # This handles specimens where hopfield_key was stripped after
                        # pattern changes (BUG-004 fix).
                        let hk_str = string(get(nd, "hopfield_key", "0"))
                            hk = parse(UInt64, hk_str)
                            hk == UInt64(0) ? hash(join(split(lowercase(strip(String(nd["pattern"])))), " ")) : hk
                        end,
                        # GRUG: Per-cycle transient flags — always reset to defaults on load.
                        # These are runtime scratch state (who fired this cycle, who gained strength);
                        # they have no meaning across a save/load boundary, so we deliberately drop
                        # any persisted value and start the restored node in a clean pre-cycle state.
                        false,   # fired_this_cycle
                        false,   # voted_this_cycle
                        false,   # gained_this_cycle
                        0.0,     # strength_delta_this_cycle
                        # GRUG BUG-010b: Original content for inhibition rules.
                        # If missing from specimen (old format), fall back to current pattern/action_packet.
                        String(get(nd, "original_pattern", String(nd["pattern"]))),
                        String(get(nd, "original_action_packet", String(nd["action_packet"])))
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
    if haskey(specimen, "node_to_lobe_idx") && _is_dict_like(specimen["node_to_lobe_idx"])
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
                push!(lock(_DROP_TABLE_LOCK) do; AIML_DROP_TABLE end, StochasticRule(rtext, rprob))
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
    if haskey(specimen, "arousal") && _is_dict_like(specimen["arousal"])
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
    if haskey(specimen, "brainstem") && _is_dict_like(specimen["brainstem"])
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


    # ── 4.14 BRIDGES (CASCADE BRIDGE SYSTEM — v8.0 bidirectional) ────────────────
    n_bridges = 0
    # GRUG v8.0: Try new "bridges" format first, fall back to old "attachments" format
    if haskey(specimen, "bridges") && isa(specimen["bridges"], AbstractVector)
        lock(BRIDGE_LOCK) do
            for bentry in specimen["bridges"]
                try
                    na = String(bentry["node_a"])
                    nb = String(bentry["node_b"])
                    seam = String.(get(bentry, "seam_tokens", String[]))
                    conf_ab = Float64(get(bentry, "base_confidence_ab", 0.3))
                    conf_ba = Float64(get(bentry, "base_confidence_ba", 0.3))
                    src_lobe = String(get(bentry, "source_lobe", ""))
                    is_crys = Bool(get(bentry, "is_crystalized", false))
                    crys_orig = Symbol(get(bentry, "crystal_origin", "none"))
                    # GRUG: Resolve lobe provenance for both sides
                    lobe_a = Lobe.find_lobe_for_node(na)
                    lobe_b = Lobe.find_lobe_for_node(nb)
                    if isempty(src_lobe)
                        src_lobe = lobe_b !== nothing ? lobe_b : ""
                    end
                    # GRUG: Re-bake confidence if needed (partner may have changed strength)
                    ref_a = get(NODE_MAP, na, nothing)
                    ref_b = get(NODE_MAP, nb, nothing)
                    if !isnothing(ref_a) && !isnothing(ref_b)
                        # Re-bake both directions using current strengths
                        if !isempty(seam)
                            overlap = _token_overlap_similarity(join(seam, " "), ref_b.pattern)
                            conf_ab = overlap + (ref_b.strength / STRENGTH_CAP) * 0.5
                            overlap_ba = _token_overlap_similarity(join(seam, " "), ref_a.pattern)
                            conf_ba = overlap_ba + (ref_a.strength / STRENGTH_CAP) * 0.5
                        end
                    end
                    # GRUG: Create bidirectional entries
                    br_ab = CascadeBridge(nb, seam, conf_ab, src_lobe, is_crys, crys_orig)
                    br_ba = CascadeBridge(na, seam, conf_ba, lobe_a !== nothing ? lobe_a : "", is_crys, crys_orig)
                    existing_ab = get(BRIDGE_MAP, na, CascadeBridge[])
                    push!(existing_ab, br_ab)
                    BRIDGE_MAP[na] = existing_ab
                    existing_ba = get(BRIDGE_MAP, nb, CascadeBridge[])
                    push!(existing_ba, br_ba)
                    BRIDGE_MAP[nb] = existing_ba
                    n_bridges += 1
                catch e
                    @warn "loadSpecimen: skipping bad bridge entry: $e"
                end
            end
        end
        counts["bridges"] = n_bridges
        println("  🌉 Bridges restored ($n_bridges)")
    elseif haskey(specimen, "attachments") && isa(specimen["attachments"], AbstractVector)
        # GRUG: Old v7.x format — upgrade to bidirectional CascadeBridge entries
        lock(BRIDGE_LOCK) do
            for aentry in specimen["attachments"]
                try
                    tid  = String(aentry["target_id"])
                    nid  = String(aentry["node_id"])
                    pat  = String(get(aentry, "pattern", ""))
                    sig  = Float64.(get(aentry, "signal", Float64[]))
                    # GRUG: Re-bake signal if missing from file (backward compat)
                    if isempty(sig)
                        sig = words_to_signal(pat)
                    end
                    # GRUG: Re-bake base_confidence if missing from old specimen
                    base_conf = Float64(get(aentry, "base_confidence", -1.0))
                    if base_conf < 0.0
                        attach_ref = get(NODE_MAP, nid, nothing)
                        if !isnothing(attach_ref) && !isempty(pat) && !startswith(pat, "SDF:")
                            base_conf = _token_overlap_similarity(pat, attach_ref.pattern) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                        elseif !isnothing(attach_ref) && startswith(pat, "SDF:")
                            if !isempty(sig) && !isempty(attach_ref.signal)
                                base_conf = _sdf_signal_similarity(sig, attach_ref.signal) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                            else
                                base_conf = 0.3
                            end
                        else
                            base_conf = 0.3
                        end
                    end
                    is_crys = Bool(get(aentry, "is_crystalized", false))
                    crys_orig = Symbol(get(aentry, "crystal_origin", "none"))
                    # GRUG v8.0: Upgrade to bidirectional — split pattern into seam tokens
                    seam = isempty(pat) ? String[] : split(pat)
                    lobe_tid = Lobe.find_lobe_for_node(tid)
                    lobe_nid = Lobe.find_lobe_for_node(nid)
                    # Compute reverse confidence too
                    ref_tid = get(NODE_MAP, tid, nothing)
                    ref_nid = get(NODE_MAP, nid, nothing)
                    reverse_conf = 0.3
                    if !isnothing(ref_tid) && !isempty(pat) && !startswith(pat, "SDF:")
                        reverse_conf = _token_overlap_similarity(pat, ref_tid.pattern) + (ref_tid.strength / STRENGTH_CAP) * 0.5
                    elseif !isnothing(ref_tid) && startswith(pat, "SDF:")
                        if !isempty(sig) && !isempty(ref_tid.signal)
                            reverse_conf = _sdf_signal_similarity(sig, ref_tid.signal) + (ref_tid.strength / STRENGTH_CAP) * 0.5
                        end
                    end
                    # Bidirectional entries
                    br_fwd = CascadeBridge(nid, seam, base_conf, lobe_nid !== nothing ? lobe_nid : "", is_crys, crys_orig)
                    br_rev = CascadeBridge(tid, seam, reverse_conf, lobe_tid !== nothing ? lobe_tid : "", is_crys, crys_orig)
                    existing_fwd = get(BRIDGE_MAP, tid, CascadeBridge[])
                    push!(existing_fwd, br_fwd)
                    BRIDGE_MAP[tid] = existing_fwd
                    existing_rev = get(BRIDGE_MAP, nid, CascadeBridge[])
                    push!(existing_rev, br_rev)
                    BRIDGE_MAP[nid] = existing_rev
                    n_bridges += 1
                catch e
                    @warn "loadSpecimen: skipping bad attachment entry (v7.x upgrade): $e"
                end
            end
        end
        counts["bridges"] = n_bridges
        println("  🌉 Bridges restored from v7.x format ($n_bridges)")
    end

    # ── 4.14b CHATTER GROUPS (v7.19) ────────────────────────
    # GRUG: Restore NodeGroup state and per-node chatter cooldowns.
    # Backwards-compat: pre-v7.19 specimens have no chatter_groups field, so
    # we leave GROUP_MAP empty — the next /grow will seed groups organically.
    n_groups = 0
    if haskey(specimen, "chatter_groups") && isa(specimen["chatter_groups"], AbstractVector)
        lock(GROUP_LOCK) do
            for gentry in specimen["chatter_groups"]
                try
                    gid     = String(gentry["id"])
                    members = String.(get(gentry, "members", String[]))
                    centroid = String(get(gentry, "centroid_pattern", ""))
                    created  = Float64(get(gentry, "created_at", time()))
                    last_ct  = Float64(get(gentry, "last_chatter_at", 0.0))
                    ccount   = Int(get(gentry, "chatter_count", 0))
                    grave_slot = Bool(get(gentry, "has_grave_slot", false))
                    # GRUG BUG-010: grave_count — how many vacant grave slots in this group.
                    # Backward compat: old specimens lack this field, default to 0.
                    # If has_grave_slot is true but grave_count is 0, infer 1 (at least one grave).
                    grave_cnt = Int(get(gentry, "grave_count", 0))
                    if grave_slot && grave_cnt == 0
                        grave_cnt = 1  # legacy specimen had has_grave_slot=true but no count
                    end

                    max_occ = Int(get(gentry, "max_occupancy", GROUP_MAX_OCCUPANCY))
                    is_tng = Bool(get(gentry, "is_time_node_group", false))
                    # GRUG v7.39: is_chatter_eligible — backward compat: old specimens lack this field.
                    # Old specimens with chatter_count == -1 (the sentinel hack) get is_chatter_eligible=false.
                    # Old specimens with chatter_count >= 0 get is_chatter_eligible=true (default eligible).
                    # New specimens just read the field directly.
                    is_chatter_eligible_raw = get(gentry, "is_chatter_eligible", nothing)
                    if is_chatter_eligible_raw !== nothing
                        is_chatter_eligible = Bool(is_chatter_eligible_raw)
                    else
                        # GRUG: Migration from old sentinel — chatter_count=-1 means NOCHAT
                        is_chatter_eligible = (ccount >= 0)
                    end
                    grp = NodeGroup(gid, members, centroid, created, last_ct, ccount, grave_slot, grave_cnt, max_occ, is_tng, is_chatter_eligible,
                                    # GRUG BUG-010b: inhibition_tokens — semantic "don't do" set from alive originals.
                                    # Old specimens lack this field; default to empty set (will be rebuilt on first refresh).
                                    Set{String}(String.(get(gentry, "inhibition_tokens", String[]))),
                                    # GRUG BUG-010b: inhibition_dirty — always true on load (tokens may be stale).
                                    true)
                    GROUP_MAP[gid] = grp
                    for m in members
                        NODE_TO_GROUP[m] = gid
                    end
                    if startswith(gid, "group_")
                        try
                            n = parse(Int, gid[7:end])
                            if n >= GROUP_COUNTER[]
                                GROUP_COUNTER[] = n + 1
                            end
                        catch
                            # Non-numeric suffix — leave counter alone.
                        end
                    end
                    n_groups += 1
                catch e
                    @warn "loadSpecimen: skipping bad chatter_groups entry: $e"
                end
            end
        end
        counts["chatter_groups"] = n_groups
        println("  🗣  Chatter groups restored ($n_groups)")
    end

    if haskey(specimen, "chatter_cooldowns") && isa(specimen["chatter_cooldowns"], AbstractVector)
        n_cd = 0
        lock(CHATTER_NODE_COOLDOWN_LOCK) do
            for cd in specimen["chatter_cooldowns"]
                try
                    nid = String(cd["node_id"])
                    ts  = Float64(cd["last_chatter_at"])
                    CHATTER_NODE_COOLDOWN[nid] = ts
                    n_cd += 1
                catch e
                    @warn "loadSpecimen: skipping bad chatter_cooldowns entry: $e"
                end
            end
        end
        if n_cd > 0
            println("  ⏱  Chatter cooldowns restored ($n_cd)")
        end
    end


    # ── 4.15 TRAJECTORY STATE (ActionTonePredictor) ───────────────
    # GRUG: Restore the trajectory ring buffer and config from specimen.
    # Academic: Backward-compatible — if key is missing (v2.0 specimen),
    # trajectory stays at defaults. No error, no silent corruption.
    n_trajectory = 0
    if haskey(specimen, "trajectory") && _is_dict_like(specimen["trajectory"])
        traj = specimen["trajectory"]
        lock(ActionTonePredictor._trajectory_lock) do
            # Restore config if present
            if haskey(traj, "config") && _is_dict_like(traj["config"])
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
    if haskey(specimen, "morph_cooldowns") && _is_dict_like(specimen["morph_cooldowns"])
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
    if haskey(specimen, "immune_system") && _is_dict_like(specimen["immune_system"])
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
    if haskey(specimen, "aiml_system") && _is_dict_like(specimen["aiml_system"])
        AIMLNodeSystem.deserialize_aiml_state!(specimen["aiml_system"])
        n_aiml_lobes = length(AIMLNodeSystem.get_registered_lobes())
        registered_lobes = AIMLNodeSystem.get_registered_lobes()
        n_aiml_nodes = isempty(registered_lobes) ? 0 : sum(AIMLNodeSystem.get_population_size(lid) for lid in registered_lobes)
        counts["aiml_lobes"] = n_aiml_lobes
        counts["aiml_nodes"] = n_aiml_nodes
        println("  🤖 AIML system restored ($n_aiml_nodes nodes across $n_aiml_lobes lobes)")
    end

    # ── 4.20 SIGIL TABLE ────────────────────────────────────────────────────
    # GRUG: Restore sigil entries that specimens merged on top of engine defaults.
    # We only restore entries whose provenance is NOT "engine-default" (those
    # are already in the table from the wipe+rebuild). This prevents duplicates
    # while preserving specimen-specific &noun lexicons and custom sigils.
    n_sigils = 0
    if haskey(specimen, "sigil_table") && isa(specimen["sigil_table"], AbstractVector)
        for sentry in specimen["sigil_table"]
            try
                name = String(sentry["name"])
                # Skip engine-defaults — already in table from wipe+rebuild
                prov = String(get(sentry, "provenance", ""))
                if prov == "engine-default"
                    continue
                end
                class_sym = Symbol(String(sentry["class"]))
                applies_sym = Symbol(String(sentry["applies_at"]))
                sig_type = get(sentry, "sigil_type", nothing)
                sig_type_sym = sig_type === nothing ? nothing : Symbol(String(sig_type))
                lexicon = get(sentry, "lexicon", nothing)
                lexicon_vec = lexicon === nothing ? nothing : String.(lexicon)
                params = get(sentry, "params", nothing)
                expansion = get(sentry, "expansion", nothing)
                promote = Bool(get(sentry, "promote_at_tokenize", false))

                entry = SigilRegistry.SigilEntry(
                    name, class_sym, applies_sym, sig_type_sym,
                    lexicon_vec, params, expansion, prov, promote, nothing
                )
                _ENGINE_SIGIL_TABLE.entries[name] = entry
                n_sigils += 1
            catch e
                @warn "loadSpecimen: skipping bad sigil entry: $e"
            end
        end
        counts["sigils"] = n_sigils
        if n_sigils > 0
            println("  🪄 Sigils restored ($n_sigils specimen-specific)")
        end
    end

    # ── 4.21 EPHEMERAL AUTOMATON RULES ──────────────────────────────────────
    # GRUG: Restore specimen-defined automaton rules. Each rule has an id,
    # trigger_action, steps, jitter_targets, and min_confidence.
    n_automatons = 0
    if haskey(specimen, "automaton_rules") && isa(specimen["automaton_rules"], AbstractVector)
        lock(EphemeralAutomaton._AUTOMATON_REGISTRY_LOCK) do
            for rentry in specimen["automaton_rules"]
                try
                    rule_id = String(rentry["id"])
                    trigger = Symbol(String(rentry["trigger_action"]))
                    min_conf = Float64(get(rentry, "min_confidence", 0.5))
                    jitter = Set{String}(String.(get(rentry, "jitter_targets", String[])))

                    steps = EphemeralAutomaton.AutomatonStep[]
                    if haskey(rentry, "steps") && isa(rentry["steps"], AbstractVector)
                        for s in rentry["steps"]
                            push!(steps, EphemeralAutomaton.AutomatonStep(
                                String(s["label"]),
                                Symbol(String(s["op"])),
                                s["payload"]
                            ))
                        end
                    end

                    rule = EphemeralAutomaton.AutomatonRule(rule_id, trigger, steps, jitter, min_conf)
                    EphemeralAutomaton._AUTOMATON_REGISTRY[rule_id] = rule
                    n_automatons += 1
                catch e
                    @warn "loadSpecimen: skipping bad automaton rule: $e"
                end
            end
        end
        counts["automaton_rules"] = n_automatons
        if n_automatons > 0
            println("  ⚙️  Automaton rules restored ($n_automatons)")
        end
    end
 
    # ── 4.21.5 PHASE ACCUMULATOR (TIME CRYSTAL) ───────────────────────────────────
    # GRUG v7.27: Restore the phase accumulator (time crystal) from specimen.
    # The crystal holds ATP distribution snapshots. Without this restore,
    # the hippocampus starts with zero learned phase — every reload is amnesia.
    if haskey(specimen, "phase_accumulator") && _is_dict_like(specimen["phase_accumulator"])
        try
            EphemeralAutomaton.phase_accumulator_from_dict!(specimen["phase_accumulator"])
            _pa_status = EphemeralAutomaton.phase_pull_status()
            _pa_crystal = Int(get(_pa_status, "crystal_size", 0))
            _pa_enabled = Bool(get(_pa_status, "enabled", true))
            _pa_thresh = round(Float64(get(_pa_status, "pull_threshold", 0.55)); digits=3)
            if _pa_crystal == 0
                println("  ⚠️  Phase accumulator: EMPTY (no crystal data) — HARD WARN")
            else
                println("  💎 Phase accumulator: $_pa_crystal snapshots (threshold=$_pa_thresh, enabled=$_pa_enabled)")
            end
        catch e
            @error "[MAIN] load_specimen: FAILED to restore phase accumulator: $e"
            println("  ⚠  Phase accumulator restore FAILED — crystal starts fresh. Error: $e — HARD WARN")
        end
    else
        println("  💎 Phase accumulator: no saved crystal found (fresh hippocampus)")
    end

    # ── 4.22 LAST CONTRIBUTOR VOTES ─────────────────────────────────────────
    # GRUG: Restore contributor votes so /right works after reload.
    n_votes = 0
    if haskey(specimen, "last_contributor_votes") && isa(specimen["last_contributor_votes"], AbstractVector)
        lock(LAST_VOTER_LOCK) do
            empty!(LAST_CONTRIBUTOR_VOTES)
            for ventry in specimen["last_contributor_votes"]
                try
                    user_trips = [RelationalTriple(String(t["subject"]), String(t["relation"]), String(t["object"]))
                                  for t in get(ventry, "user_triples", [])]
                    node_trips = [RelationalTriple(String(t["subject"]), String(t["relation"]), String(t["object"]))
                                  for t in get(ventry, "node_triples", [])]
                    mp_role = Symbol(String(get(ventry, "multipart_role", "singleton")))
                    vote = Vote(
                        String(ventry["node_id"]),
                        String(ventry["action"]),
                        Float64(ventry["confidence"]),
                        String.(get(ventry, "negatives", String[])),
                        user_trips,
                        node_trips,
                        Bool(get(ventry, "antimatch", false)),
                        String(get(ventry, "multipart_group", "")),
                        mp_role,
                        Int.(get(ventry, "input_chunks", Int[]))
                    )
                    push!(LAST_CONTRIBUTOR_VOTES, vote)
                    n_votes += 1
                catch e
                    @warn "loadSpecimen: skipping bad contributor vote: $e"
                end
            end
        end
        counts["contributor_votes"] = n_votes
        if n_votes > 0
            println("  🗳  Contributor votes restored ($n_votes)")
        end
    end

    # ── 4.23 NODE_TO_GROUP INDEX ────────────────────────────────────────────
    # GRUG: Restore NODE_TO_GROUP reverse index. chatter_groups restore
    # (section 4.14b) already rebuilds this, but an explicit restore ensures
    # consistency even if group member lists were somehow incomplete.
    # We only fill in entries that are missing (chatter_groups restore may
    # have already set some).
    if haskey(specimen, "node_to_group_idx") && _is_dict_like(specimen["node_to_group_idx"])
        lock(GROUP_LOCK) do
            for (nid, gid) in specimen["node_to_group_idx"]
                n = String(nid)
                if !haskey(NODE_TO_GROUP, n)
                    NODE_TO_GROUP[n] = String(gid)
                end
            end
        end
    end

    # ── 4.24 TONAL JUDGE TUNABLES ──────────────────────────────────────────
    # GRUG: Restore the TonalJudge runtime knobs if present. Backward-compat:
    # pre-v2.5 specimens lack this key — knobs stay at defaults.
    if haskey(specimen, "tonal_judge_knobs") && _is_dict_like(specimen["tonal_judge_knobs"])
        tk = specimen["tonal_judge_knobs"]
        _tj_lift_val = get(tk, "frame_lift_multiplier", nothing)
        _tj_inhibit_val = get(tk, "frame_inhibit_multiplier", nothing)
        TonalJudge.set_frame_match_weights!(;
            lift     = _tj_lift_val !== nothing ? Float64(_tj_lift_val) : nothing,
            inhibit  = _tj_inhibit_val !== nothing ? Float64(_tj_inhibit_val) : nothing
        )
        _tj_l, _tj_i = TonalJudge.get_frame_match_weights()
        println("  🎭 TonalJudge knobs restored (lift=$(_tj_l), inhibit=$(_tj_i))")
    end


    # GRUG v7.24: EphemeralMLP specimen restore.
    # The brain's learned weights, rules, and correlations survive across
    # save/load. If the key is missing (old specimen), MLP keeps its default
    # initial state — no error, just a fresh brain.
    if haskey(specimen, "ephemeral_mlp") && _is_dict_like(specimen["ephemeral_mlp"])
        try
            EphemeralMLP.from_specimen_dict!(specimen["ephemeral_mlp"])
            mlp_status = EphemeralMLP.get_mlp_status()
            n_mlp_transforms = get(mlp_status, "total_transforms", 0)
            n_mlp_rules = get(mlp_status, "rules_total", 0)
            println("  🧠 EphemeralMLP restored (transforms=$n_mlp_transforms, rules=$n_mlp_rules)")
        catch e
            @error "[MAIN] load_specimen: failed to restore EphemeralMLP state: $e"
            println("  ⚠  EphemeralMLP restore FAILED — using fresh state. Error: $e")
        end
    else
        println("  🧠 EphemeralMLP: no saved state found (fresh brain)")
    end

    # GRUG v7.24: SelfObserver store stats are informational on reload.
    # The actual observer store starts fresh (micrologs are ephemeral by design).
    # But the MLP's selfobserver_observations counter was restored from the
    # specimen, so the gate works correctly even though the store is empty.
    if haskey(specimen, "mlp_observer_store") && _is_dict_like(specimen["mlp_observer_store"])
        obs_data = specimen["mlp_observer_store"]
        obs_entries = get(obs_data, "total_entries", 0)
        obs_keys = get(obs_data, "key_count", 0)
        println("  👁  MLP Observer Store: $obs_entries entries, $obs_keys distinct keys (store starts fresh; MLP gate counter restored)")
    end

    # GRUG v9: Restore cached Phi for coherence delta tracking.
    # Without this, the first cycle after load would see a delta-Phi of
    # (current - 0.0) instead of (current - last_known), producing a
    # bogus coherence "spike" on the first observation. Old specimens
    # without this key simply keep the default 0.0 — no harm done.
    if haskey(specimen, "mlp_cached_phi") && _is_dict_like(specimen["mlp_cached_phi"])
        _saved_phi = Float64(get(specimen["mlp_cached_phi"], "last_phi", 0.0))
        _MLP_CACHED_PHI[:last_phi] = _saved_phi
        println("  🧠 MLP cached Phi restored (last_phi=$_saved_phi)")
    end

    # ─── 4.26 DECOMPOSER CONFIG (v7.28) ──────────────────────────────
    # GRUG: The specimen's decomposer_config tells the InputDecomposer what
    # conjunctions to split on, what command/question markers to recognize,
    # and how verbs conjugate. If the specimen doesn't have a decomposer_config,
    # the decomposer falls back to its built-in defaults. SPECIMEN-OVERRIDES-DEFAULTS.
    # NO SILENT FAILURES: every field is reported, failure is hard-warned.
    try
        _decomp_cfg = InputDecomposer.set_config!(specimen)
        _n_split = length(_decomp_cfg.split_conjunctions)
        _n_compound = length(_decomp_cfg.compound_pairs)
        _n_qmark = length(_decomp_cfg.question_markers)
        _n_cmd_stems = length(_decomp_cfg.command_markers)
        _n_cmd_expanded = length(_decomp_cfg.expanded_command_markers)
        _n_conj = length(_decomp_cfg.conjugation_rules)
        _ctx = _decomp_cfg.context_conjunction
        println("  ✂️  Decomposer config loaded (FIRST-CLASS):")
        println("      Split conjunctions: $_n_split | Compound pairs: $_n_compound leaders | Context: '$_ctx'")
        println("      Question markers: $_n_qmark | Command stems: $_n_cmd_stems → $_n_cmd_expanded expanded | Conjugation rules: $_n_conj")
        # GRUG: If any category is suspiciously empty, HARD WARN.
        if _n_split == 0
            @warn "[MAIN] load_specimen: decomposer has ZERO split conjunctions — nothing will trigger a conjunction-based split!"
            println("      ⚠️  WARNING: Zero split conjunctions! Compound input detection is disabled!")
        end
        if _n_qmark == 0
            @warn "[MAIN] load_specimen: decomposer has ZERO question markers — question-based clause detection disabled!"
            println("      ⚠️  WARNING: Zero question markers! Question-based splitting is disabled!")
        end
        if _n_cmd_expanded == 0
            @warn "[MAIN] load_specimen: decomposer has ZERO command markers — command-based clause detection disabled!"
            println("      ⚠️  WARNING: Zero command markers! Command-based splitting is disabled!")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to set decomposer config (using defaults): $e"
        println("  ⚠️  Decomposer config: FAILED to load (using built-in defaults)")
        println("      Error: $e")
    end

    # ══════════════════════════════════════════════════════════════════════

    # ───── 4.27 VIGILANCE CONFIG (v7.29) ────────────────────────────────────
    # GRUG: Restore vigilance config from specimen. If missing, defaults apply.
    # NO SILENT FAILURES — if restore fails, defaults are used with a warning.
    try
        if haskey(specimen, "vigilance_config")
            EphemeralAutomaton.deserialize_vigilance_config!(specimen["vigilance_config"])
            _vcfg = EphemeralAutomaton.get_vigilance_config()
            println("  👁  Vigilance config loaded (cap=$(_vcfg["max_cap"]), enabled=$(_vcfg["enabled"]))")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore vigilance config: $e"
        println("  ⚠️  Vigilance config: FAILED to load (using defaults)")
    end

    # ───── 4.28 INJECTOR STATS (v7.29) ────────────────────────────────────────
    # GRUG: Restore injector stats. These are diagnostic counters — not critical
    # for behavior, but useful for continuity. If missing, starts at zero.
    try
        if haskey(specimen, "injector_stats")
            _istats = specimen["injector_stats"]
            if _is_dict_like(_istats)
                lock(EphemeralAutomaton._INJECTOR_LOCK) do
                    for (k, v) in _istats
                        if haskey(EphemeralAutomaton._INJECTOR_STATS, k)
                            EphemeralAutomaton._INJECTOR_STATS[k] = Int(v)
                        end
                    end
                end
                println("  📊  Injector stats loaded")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore injector stats: $e"
    end

    # ───── 4.29 RELATIONAL JITTER CONFIG (v7.29) ────────────────────────────
    # GRUG: Restore jitter calibration. These are Refs — runtime-tunable.
    # If missing, defaults from RelationalJitter module apply.
    try
        if haskey(specimen, "relational_jitter_config")
            _rjcfg = specimen["relational_jitter_config"]
            if _is_dict_like(_rjcfg)
                if haskey(_rjcfg, "jitter_ratio")
                    RelationalJitter._JITTER_RATIO[] = Float64(_rjcfg["jitter_ratio"])
                end
                if haskey(_rjcfg, "jitter_coin_ratio")
                    RelationalJitter._JITTER_COIN_RATIO[] = Float64(_rjcfg["jitter_coin_ratio"])
                end
                if haskey(_rjcfg, "jitter_enabled")
                    RelationalJitter._JITTER_ENABLED[] = Bool(_rjcfg["jitter_enabled"])
                end
                println("  🎲  Relational jitter config loaded (ratio=$(RelationalJitter._JITTER_RATIO[]), coin=$(RelationalJitter._JITTER_COIN_RATIO[]), enabled=$(RelationalJitter._JITTER_ENABLED[]))")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore relational jitter config: $e"
        println("  ⚠️  Relational jitter config: FAILED to load (using defaults)")
    end

    # ───── 4.30-4.36 BASELINE CONFIG SECTIONS (v7.29) ────────────────────────
    # GRUG: These sections save const values that define specimen personality.
    # They're NOT runtime-tunable (they're const, not Refs), but saving them
    # means we can detect drift between code defaults and specimen expectations.
    # On load, we READ them and WARN if they differ from current code defaults.
    # Future: make these Refs for true specimen-level override.
    try
        if haskey(specimen, "brainstem_config")
            _bscfg = specimen["brainstem_config"]
            _bs_drift = 0
            if Float64(get(_bscfg, "propagation_decay", 0.6)) != BrainStem.PROPAGATION_DECAY; _bs_drift += 1; end
            if Float64(get(_bscfg, "fire_count_decay_factor", 0.85)) != BrainStem.FIRE_COUNT_DECAY_FACTOR; _bs_drift += 1; end
            if Int(get(_bscfg, "fire_count_decay_interval", 50)) != BrainStem.FIRE_COUNT_DECAY_INTERVAL; _bs_drift += 1; end
            if Float64(get(_bscfg, "propagation_min_confidence", 0.1)) != BrainStem.PROPAGATION_MIN_CONFIDENCE; _bs_drift += 1; end
            if _bs_drift > 0
                println("  🧠  BrainStem config: $_bs_drift drift(s) from code defaults (saved for future override)")
            else
                println("  🧠  BrainStem config: matches code defaults")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to check brainstem config: $e"
    end

    try
        if haskey(specimen, "engine_config")
            _ecfg = specimen["engine_config"]
            _e_drift = 0
            if Float64(get(_ecfg, "strength_cap", 10.0)) != STRENGTH_CAP; _e_drift += 1; end
            if Float64(get(_ecfg, "strength_floor", 0.0)) != STRENGTH_FLOOR; _e_drift += 1; end
            if Float64(get(_ecfg, "strength_solidify_threshold", 9.0)) != STRENGTH_SOLIDIFY_THRESHOLD; _e_drift += 1; end
            if Float64(get(_ecfg, "jitter_confidence_floor", 0.5)) != JITTER_CONFIDENCE_FLOOR; _e_drift += 1; end
            # GRUG v7.49: Antimatch drain constants drift-check.
            if Float64(get(_ecfg, "antimatch_drain_fixed", 0.03)) != ANTIMATCH_DRAIN_FIXED; _e_drift += 1; end
            if Float64(get(_ecfg, "antimatch_drain_max_jitter", 0.05)) != ANTIMATCH_DRAIN_MAX_JITTER; _e_drift += 1; end
            if _e_drift > 0
                println("  ⚙️  Engine config: $_e_drift drift(s) from code defaults (saved for future override)")
            else
                println("  ⚙️  Engine config: matches code defaults")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to check engine config: $e"
    end

    try
        if haskey(specimen, "lobe_orchestrator_knobs")
            _loknobs = specimen["lobe_orchestrator_knobs"]
            _lo_drift = 0
            if Int(get(_loknobs, "hard_fire_batch_cap", 1000)) != LobeOrchestrator.HARD_FIRE_BATCH_CAP; _lo_drift += 1; end
            if Float64(get(_loknobs, "min_pass_through_score", 0.1)) != LobeOrchestrator.MIN_PASS_THROUGH_SCORE; _lo_drift += 1; end
            if Float64(get(_loknobs, "hard_selection_conf_threshold", 0.5)) != LobeOrchestrator.HARD_SELECTION_CONF_THRESHOLD; _lo_drift += 1; end
            if _lo_drift > 0
                println("  🏛️  Lobe orchestrator knobs: $_lo_drift drift(s) from code defaults")
            else
                println("  🏛️  Lobe orchestrator knobs: match code defaults")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to check lobe orchestrator knobs: $e"
    end

    try
        if haskey(specimen, "vote_orchestrator_knobs")
            _voknobs = specimen["vote_orchestrator_knobs"]
            _vo_drift = 0
            if Float64(get(_voknobs, "aiml_confidence_threshold", 0.35)) != VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD; _vo_drift += 1; end
            if Float64(get(_voknobs, "vote_w_anti_match_penalty", 1.0)) != VoteOrchestrator.VOTE_W_ANTI_MATCH_PENALTY; _vo_drift += 1; end
            if _vo_drift > 0
                println("  🗳️  Vote orchestrator knobs: $_vo_drift drift(s) from code defaults")
            else
                println("  🗳️  Vote orchestrator knobs: match code defaults")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to check vote orchestrator knobs: $e"
    end

    try
        if haskey(specimen, "mitosis_config")
            _mcfg = specimen["mitosis_config"]
            _mc_drift = 0
            # GRUG v7.50: Drift-check strain warrant constants so reload
            # personality doesn't silently shift if code defaults changed.
            if Float64(get(_mcfg, "strain_warrant_weight", 0.7)) != MitosisMode.STRAIN_WARRANT_WEIGHT; _mc_drift += 1; end
            if Float64(get(_mcfg, "strain_warrant_active_threshold", 0.55)) != MitosisMode.STRAIN_WARRANT_ACTIVE_THRESHOLD; _mc_drift += 1; end
            if _mc_drift > 0
                println("  🧬  Mitosis config: $_mc_drift drift(s) from code defaults (strain warrant knobs changed)")
            else
                println("  🧬  Mitosis config: loaded (baseline reference)")
            end
        end
    catch e; end

    try
        if haskey(specimen, "growth_config")
            println("  🌱  Growth automaton config: loaded (baseline reference)")
        end
    catch e; end

    try
        if haskey(specimen, "phagy_config")
            println("  🦠  Phagy config: loaded (baseline reference)")
        end
    catch e; end

    try
        if haskey(specimen, "chatter_config")
            println("  💬  Chatter config: loaded (baseline reference)")
        end
    catch e; end

    try
        if haskey(specimen, "immune_config")
            println("  🛡️  Immune config: loaded (baseline reference)")
        end
    catch e; end


    # ──── 4.37 SCANNER CONFIG (baseline, v7.29) ─────────────────────────────
    try
        if haskey(specimen, "scanner_config")
            sc = specimen["scanner_config"]
            _sc_man = get(sc, "max_active_nodes", FullLobeScanner.MAX_ACTIVE_NODES)
            _sc_conf = get(sc, "confident_threshold", FullLobeScanner.CONFIDENT_THRESHOLD)
            _sc_cand = get(sc, "default_candidate_threshold", FullLobeScanner.DEFAULT_CANDIDATE_THRESHOLD)
            # GRUG: Drift detection — warn if saved values differ from code defaults
            if _sc_man != FullLobeScanner.MAX_ACTIVE_NODES
                @warn "[MAIN] scanner_config: max_active_nodes drift (code=$(FullLobeScanner.MAX_ACTIVE_NODES), saved=$_sc_man)"
            end
            if _sc_conf != FullLobeScanner.CONFIDENT_THRESHOLD
                @warn "[MAIN] scanner_config: confident_threshold drift (code=$(FullLobeScanner.CONFIDENT_THRESHOLD), saved=$_sc_conf)"
            end
            if _sc_cand != FullLobeScanner.DEFAULT_CANDIDATE_THRESHOLD
                @warn "[MAIN] scanner_config: default_candidate_threshold drift (code=$(FullLobeScanner.DEFAULT_CANDIDATE_THRESHOLD), saved=$_sc_cand)"
            end
            println("  🔭  Scanner config: loaded (baseline reference)")
        end
    catch e; end

    # ──── 4.38 ACTION TONE PREDICTOR KNOBS (baseline, v7.29) ────────────────
    try
        if haskey(specimen, "action_tone_knobs")
            atk = specimen["action_tone_knobs"]
            _atk_incoh = get(atk, "incoherence_tag_threshold", ActionTonePredictor.INCOHERENCE_TAG_THRESHOLD)
            _atk_low   = get(atk, "low_signal_threshold", ActionTonePredictor.LOW_SIGNAL_THRESHOLD)
            _atk_damp  = get(atk, "fallback_damp_threshold", ActionTonePredictor.FALLBACK_DAMP_THRESHOLD)
            _atk_jitt  = get(atk, "curve_jitter_envelope", ActionTonePredictor.CURVE_JITTER_ENVELOPE)
            _atk_esc   = get(atk, "escalation_confidence_floor", ActionTonePredictor.ESCALATION_CONFIDENCE_FLOOR)
            # GRUG: Drift detection — warn if saved values differ from code defaults
            if _atk_incoh != ActionTonePredictor.INCOHERENCE_TAG_THRESHOLD
                @warn "[MAIN] action_tone_knobs: incoherence_tag_threshold drift (code=$(ActionTonePredictor.INCOHERENCE_TAG_THRESHOLD), saved=$_atk_incoh)"
            end
            if _atk_low != ActionTonePredictor.LOW_SIGNAL_THRESHOLD
                @warn "[MAIN] action_tone_knobs: low_signal_threshold drift (code=$(ActionTonePredictor.LOW_SIGNAL_THRESHOLD), saved=$_atk_low)"
            end
            if _atk_damp != ActionTonePredictor.FALLBACK_DAMP_THRESHOLD
                @warn "[MAIN] action_tone_knobs: fallback_damp_threshold drift (code=$(ActionTonePredictor.FALLBACK_DAMP_THRESHOLD), saved=$_atk_damp)"
            end
            if _atk_jitt != ActionTonePredictor.CURVE_JITTER_ENVELOPE
                @warn "[MAIN] action_tone_knobs: curve_jitter_envelope drift (code=$(ActionTonePredictor.CURVE_JITTER_ENVELOPE), saved=$_atk_jitt)"
            end
            if _atk_esc != ActionTonePredictor.ESCALATION_CONFIDENCE_FLOOR
                @warn "[MAIN] action_tone_knobs: escalation_confidence_floor drift (code=$(ActionTonePredictor.ESCALATION_CONFIDENCE_FLOOR), saved=$_atk_esc)"
            end
            println("  🎯  ActionTone knobs: loaded (baseline reference)")
        end
    catch e; end


    # ── 4.39 CO-ACTIVATION ACCUMULATOR (RelationalGovernance) ─────────────────
    # GRUG: Restore the co-activation pairs so specimen remembers which nodes
    # fire together. Old specimens that predate RelationalGovernance won't have
    # this key — that's fine, accumulator starts empty and re-learns organically.
    try
        if haskey(specimen, "co_activation")
            RelationalGovernance.deserialize_co_activation!(specimen["co_activation"])
            _co_pairs = lock(() -> length(RelationalGovernance.CO_ACC), RelationalGovernance.CO_ACC_LOCK)
            println("  🔗  Co-activation accumulator loaded ($_co_pairs pairs)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore co-activation accumulator: $e"
        println("  ⚠️  Co-activation accumulator: FAILED to load (starting fresh)")
    end
    # GRUG: Restore the InputLedger hash state so the background thread
    # doesn't re-process old messages. Old specimens that predate InputLedger
    # won't have this key — that's fine, ledger starts empty and the thread
    # will naturally consume all existing entries on first scan.
    try
        if haskey(specimen, "input_ledger")
            InputLedger.deserialize_input_ledger!(specimen["input_ledger"])
            _il_size = InputLedger.ledger_size()
            println("  📝  Input ledger loaded ($_il_size consumed hashes)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore input ledger: $e"
        println("  ⚠️  Input ledger: FAILED to load (starting fresh)")
    end
    # GRUG: Restore the ChatterResiduals hash state so the background thread
    # doesn't re-mine old swaps. Old specimens that predate ChatterResiduals
    # won't have this key — that's fine, ledger starts empty and the thread
    # will naturally consume all existing swaps on first scan.
    try
        if haskey(specimen, "chatter_residuals")
            ChatterResiduals.deserialize_chatter_residuals!(specimen["chatter_residuals"])
            _cr_size = ChatterResiduals.residual_ledger_size()
            println("  🔮  Chatter residuals loaded ($_cr_size consumed hashes)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore chatter residuals: $e"
        println("  ⚠️  Chatter residuals: FAILED to load (starting fresh)")
    end

    # GRUG: Restore AutoGrowth evidence accumulator + co-occurrence map.
    # Old specimens that predate AutoGrowth won't have these keys —
    # that's fine, evidence starts empty and accumulates naturally.
    try
        if haskey(specimen, "autogrowth_evidence")
            AutoGrowth.load_evidence_snapshot!(specimen["autogrowth_evidence"])
            println("  🌱  AutoGrowth evidence loaded ($(length(specimen["autogrowth_evidence"])) records)")
        end
        if haskey(specimen, "autogrowth_co_occur")
            AutoGrowth.load_co_occur_snapshot!(specimen["autogrowth_co_occur"])
            println("  🌱  AutoGrowth co-occurrence loaded ($(length(specimen["autogrowth_co_occur"])) pairs)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore autogrowth evidence: $e"
        println("  ⚠️  AutoGrowth evidence: FAILED to load (starting fresh)")
    end

    # GRUG: Restore AutoLinker link evidence so the bridge builder picks up
    # where it left off. Link evidence accumulates slowly from co-firing and
    # co-occurrence — losing it means the auto-linker starts from zero.
    try
        if haskey(specimen, "autolink_evidence")
            AutoLinker.load_link_evidence_snapshot!(specimen["autolink_evidence"])
            println("  🔗  AutoLinker evidence loaded ($(length(specimen["autolink_evidence"])) records)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore autolink evidence: $e"
        println("  ⚠️  AutoLinker evidence: FAILED to load (starting fresh)")
    end

    # ── GRUG v10: FLASHCARD RESTORE ──────────────────────────────────
    # GRUG: Restore flashcards from all lobes. Math facts like "3+5=8"
    # should survive reload — they were learned via PettyLearner fast-path.
    try
        if haskey(specimen, "flashcards")
            _fc_data = specimen["flashcards"]
            # BUGFIX (specimen-build-v3): deserialize_flashcards!(data) takes the
            # WHOLE Dict (lobe_id => [cards]) and iterates internally. The old code
            # called it per-lobe with (lobe_id, cards) — a 2-arg call that has no
            # matching method, so it MethodError'd and ZERO flashcards restored.
            _fc_count = 0
            for (_lobe_id, _cards) in _fc_data
                _fc_count += length(_cards)
            end
            LobeTable.deserialize_flashcards!(_fc_data)
            println("  📇  Flashcards loaded ($_fc_count cards)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore flashcards: $e"
        println("  ⚠️  Flashcards: FAILED to load (starting fresh)")
    end

    # ── GRUG v10: CURIOSITY ACCUMULATOR RESTORE ──────────────────────
    # GRUG: Restore curiosity intensity so the system remembers what it
    # was curious about. Curiosity overflow drives autonomous questions.
    try
        if haskey(specimen, "curiosity")
            AutoGrowth.deserialize_curiosity!(specimen["curiosity"])
            _cur_int = get(specimen["curiosity"], "intensity", 0.0)
            println("  🔥  Curiosity accumulator loaded (intensity=$_cur_int)")
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore curiosity: $e"
        println("  ⚠️  Curiosity: FAILED to load (starting fresh)")
    end


    # ── 4.40 FAN-OUT CONFIG ──────────────────────────────────────────────────────
    # GRUG: Restore fan-out settings. If missing (old specimen), defaults apply.
    # Fan-out enabled + max_shadows + mode set are all runtime-tunable.
    try
        if haskey(specimen, "fanout_config")
            _focfg = specimen["fanout_config"]
            if _is_dict_like(_focfg)
                if haskey(_focfg, "enabled")
                    _FANOUT_ENABLED[] = Bool(_focfg["enabled"])
                end
                if haskey(_focfg, "max_shadows")
                    _FANOUT_MAX_SHADOWS[] = Int(_focfg["max_shadows"])
                end
                if haskey(_focfg, "modes")
                    empty!(_FANOUT_MODES)
                    for m in _focfg["modes"]
                        push!(_FANOUT_MODES, String(m))
                    end
                end
                println("  🪭  Fan-out config loaded (enabled=$(_FANOUT_ENABLED[]), max=$(_FANOUT_MAX_SHADOWS[]), modes=$(length(_FANOUT_MODES)))")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore fan-out config: $e"
        println("  ⚠️  Fan-out config: FAILED to load (using defaults)")
    end

    # ── 4.41 HIPPOCAMPAL PENDING ASK ──────────────────────────────────────────────
    # GRUG: Restore the pending ask text. If grug was waiting for an answer
    # when the specimen was saved, it still remembers the question on reload.
    try
        if haskey(specimen, "hippocampal_pending_ask")
            _hpa = specimen["hippocampal_pending_ask"]
            if _is_dict_like(_hpa) && haskey(_hpa, "pending_text")
                lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
                    _HIPPOCAMPAL_PENDING_ASK[] = String(_hpa["pending_text"])
                end
                if !isempty(_HIPPOCAMPAL_PENDING_ASK[])
                    _hpa_text = _HIPPOCAMPAL_PENDING_ASK[]
                    _hpa_preview = length(_hpa_text) > 40 ? _hpa_text[1:40] : _hpa_text
                    println("  🧠  Hippocampal pending ask restored: '$(_hpa_preview)'")
                else
                    println("  🧠  Hippocampal pending ask: empty (no pending question)")
                end
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore hippocampal pending ask: $e"
    end

    # ── 4.42 ADMIN SESSION ────────────────────────────────────────────────────────
    # GRUG: Admin session is ALWAYS reset to logged-out on reload for safety.
    # An active session at save time means the specimen was saved mid-admin;
    # we warn but do NOT restore the session. Login must be explicit.
    try
        if haskey(specimen, "admin_session")
            _as = specimen["admin_session"]
            if _is_dict_like(_as) && get(_as, "is_logged_in", false)
                ADMIN_SESSION[] = AdminSession(false, 0.0, 0.0)
                println("  🔐  Admin session: SAVED while logged in — session reset for safety (use /login)")
            else
                println("  🔐  Admin session: not logged in (clean)")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to check admin session: $e"
    end

    # ── 4.43 LOBE ORCHESTRATOR LAST STATE ─────────────────────────────────────────
    # GRUG: Restore last lobe scoring state so the first post-reload cycle
    # has continuity with the pre-save cycle. Without this, the orchestrator
    # starts with empty scores and the first cycle scores naively.
    try
        if haskey(specimen, "lobe_orch_last")
            _lol = specimen["lobe_orch_last"]
            if _is_dict_like(_lol)
                if haskey(_lol, "scores") && isa(_lol["scores"], AbstractVector)
                    _restored_scores = Tuple{String, Float64, Float64, Float64, Int}[]
                    for s in _lol["scores"]
                        if _is_dict_like(s)
                            push!(_restored_scores, (
                                String(get(s, "lobe_id", "")),
                                Float64(get(s, "base_avg", 0.0)),
                                Float64(get(s, "top_avg", 0.0)),
                                Float64(get(s, "score", 0.0)),
                                Int(get(s, "hard_count", 0))
                            ))
                        end
                    end
                    LobeOrchestrator.set_last_state!(_restored_scores,
                        haskey(_lol, "winner") ? String(_lol["winner"]) : "",
                        (haskey(_lol, "passthrough") && isa(_lol["passthrough"], AbstractVector)) ? [String(p) for p in _lol["passthrough"]] : String[])
                end
                _r_scores2, _r_winner2, _ = LobeOrchestrator.get_last_state()
                println("  \U0001f3ad  Lobe orchestrator last state loaded (winner=$(_r_winner2), scores=$(length(_r_scores2)))")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore lobe orchestrator last state: $e"
        println("  ⚠️  Lobe orchestrator last state: FAILED to load (starting fresh)")
    end

    # ── 4.44 CHATTER CURSOR ───────────────────────────────────────────────────────
    # GRUG: Restore chatter cursor position. Without this, reload re-mines
    # all old swaps from the beginning of CHATTER_LOG.
    try
        if haskey(specimen, "chatter_cursor")
            _cc = specimen["chatter_cursor"]
            if _is_dict_like(_cc) && haskey(_cc, "cursor")
                ChatterMode.CHATTER_CURSOR[] = Int(_cc["cursor"])
                println("  🔖  Chatter cursor loaded (pos=$(ChatterMode.CHATTER_CURSOR[]))")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore chatter cursor: $e"
    end

    # ── 4.45 ANSWER MODE CONFIG ───────────────────────────────────────────────────
    # GRUG: Restore answer mode config. If the specimen had custom modes or
    # modified voice/frame/prompt for standard modes, those survive reload.
    # Missing keys in saved modes fall back to current code defaults.
    try
        if haskey(specimen, "answer_mode_config")
            _amc = specimen["answer_mode_config"]
            if _is_dict_like(_amc)
                for (mode_name, mode_cfg) in _amc
                    if haskey(_ANSWER_MODE_CONFIG, mode_name)
                        # Merge: saved values override code defaults
                        _existing = _ANSWER_MODE_CONFIG[mode_name]
                        if _is_dict_like(mode_cfg) && _is_dict_like(_existing)
                            for (k, v) in mode_cfg
                                _existing[k] = v
                            end
                        elseif isempty(_existing) && !isempty(mode_cfg)
                            # Code default is empty (handled specially), but saved
                            # had data — restore it
                            if _is_dict_like(mode_cfg)
                                _ANSWER_MODE_CONFIG[mode_name] = Dict{String,Any}(mode_cfg)
                            end
                        end
                    else
                        # New mode that doesn't exist in code defaults — add it
                        if _is_dict_like(mode_cfg)
                            _ANSWER_MODE_CONFIG[mode_name] = Dict{String,Any}(mode_cfg)
                        end
                    end
                end
                println("  📋  Answer mode config loaded ($(length(_ANSWER_MODE_CONFIG)) modes)")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore answer mode config: $e"
        println("  ⚠️  Answer mode config: FAILED to load (using code defaults)")
    end

    # ── 4.46 PHAGY RULES REF ──────────────────────────────────────────────────────
    # GRUG: Restore the live orchestration rules for the rule pruner automaton.
    # Without these, reload loses all dynamically-added rules.
    try
        if haskey(specimen, "phagy_rules_ref")
            _pr = specimen["phagy_rules_ref"]
            if isa(_pr, AbstractVector)
                PHAGY_RULES_REF[] = Vector(_pr)
                println("  🦠  Phagy rules ref loaded ($(length(PHAGY_RULES_REF[])) rules)")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore phagy rules ref: $e"
    end

    # ── 4.47 TIME ORIENTATION CONFIG (v8.1) ──────────────────────────────────
    # GRUG v8.1: Restore global time orientation state. When a time sigil
    # (&now/&before/&next) was active at save time, the orientation and its
    # metadata are restored so the engine can reason temporally from the jump.
    # Also process the time_node_index to reconnect nodes to their sigils.
    try
        if haskey(specimen, "time_orientation_config")
            _toc = specimen["time_orientation_config"]
            if _is_dict_like(_toc)
                # Restore global time orientation state
                _g_orient = String(get(_toc, "global_orientation", "none"))
                _g_meta = get(_toc, "global_meta", Dict{String,Any}())
                if _g_orient != "none"
                    lock(_GLOBAL_PROMOTION_LOCK) do
                        _GLOBAL_TIME_ORIENTATION[] = (_g_orient, _g_meta)
                    end
                    println("  ⏳  Time orientation config loaded (global=$_g_orient)")
                else
                    println("  ⏳  Time orientation config loaded (global=none, no active orientation)")
                end
                # GRUG v8.1: Process time_node_index — for each oriented time node,
                # verify the orientation field exists in the loaded node's json_data.
                # The json_data is already restored by the node loading phase, so
                # the time_orientation and time_sigil fields should already be there.
                # This is a verification pass + logging.
                _tni = get(_toc, "time_node_index", Dict{String,Any}())
                if _is_dict_like(_tni) && !isempty(_tni)
                    _verified = 0
                    for (nid, info) in _tni
                        if _is_dict_like(info)
                            _orient = get(info, "orientation", "")
                            _sigil  = get(info, "sigil", "")
                            # Verify the node exists and has the orientation
                            lock(NODE_LOCK) do
                                if haskey(NODE_MAP, nid)
                                    _node_orient = get(NODE_MAP[nid].json_data, "time_orientation", "")
                                    if _node_orient == _orient
                                        _verified += 1
                                    else
                                        @warn "[MAIN] load_specimen: time node $nid orientation mismatch (index=$_orient, node=$_node_orient)"
                                    end
                                end
                            end
                        end
                    end
                    println("  ⏳  Time node orientation index: $_verified/$(length(_tni)) nodes verified")
                end
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore time orientation config: $e"
        println("  ⚠️  Time orientation config: FAILED to load (time sigils will still work via default_registry)")
    end



    # ── 26b. COHERENCE FIELD CONFIG ─────────────────────────────────────────
    # GRUG v9: Restore CoherenceField config so routing weight survives reload.
    try
        if haskey(specimen, "coherence_config")
            _cc = specimen["coherence_config"]
            if _is_dict_like(_cc)
                CoherenceField.coherence_config_from_dict!(_cc)
                _w = get(_cc, "weight", 0.0)
                println("  🔗  CoherenceField config loaded (weight=$_w)")
            end
        end
    catch e
        @warn "[MAIN] load_specimen: failed to restore coherence config: $e"
        println("  ⚠️  CoherenceField config: FAILED to load (defaults will apply)")
    end

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
    push!(lines, "  📄  File size        : $(file_size) bytes")
    push!(lines, "  📦  JSON size        : $(json_size) bytes")
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
    push!(lines, "  ⏳  Time orientation  : $(try get(specimen["time_orientation_config"], "global_orientation", "none") catch _ "none" end)")
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

    greet_ctx    = Dict{String, Any}("system_prompt" => "Highly polite greeting protocols active. Friend at the cave mouth, Grug nod and make space by the fire.")
    reason_ctx   = Dict{String, Any}("system_prompt" => "Cold logical analysis engine active. Grug line up the rocks one by one and check each before moving on.")

    # GRUG: Relation dictionary to guard the gate!
    relational_ctx = Dict{String, Any}(
        "system_prompt"      => "Causal relational analysis active. Grug trace what hits what, in what order, and what falls out the other side.",
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
    # If `grug-binary/default.specimen.json` (or env-overridden path) exists and
    # auto-load is not disabled by `GRUG_NO_AUTOLOAD=1`, restore from it.
    # Prefers .json (cross-platform, no gzip needed). Falls back to .gz if
    # .json is absent. Otherwise plant a minimal hardcoded boot-seed set so
    # grug can talk on first run with zero setup. The auto-load gives newcomers
    # a brain out of the box; the hardcoded fallback guarantees grug never
    # starts empty.
    # v7.24-restore: default specimen auto-load DISABLED.
    # Reason: auto-loading default.specimen.json on every boot polluted test
    # runs with stale nodes that lacked action_packets/frame_hints, which let
    # token-overlap winners (e.g. survival "fire burns") beat the script's
    # newly-grown nodes that DID have action data. Tests now start clean every
    # time; explicit `/loadSpecimen <path>` is the only way to restore state.
    # Re-enable by uncommenting the block below if you want the legacy behavior.
    #
    # _json_path = joinpath(@__DIR__, "..", "grug-binary", "default.specimen.json")
    # _gz_path   = joinpath(@__DIR__, "..", "grug-binary", "default.specimen.gz")
    # default_specimen_path = get(ENV, "GRUG_DEFAULT_SPECIMEN",
    #                              isfile(_json_path) ? _json_path : _gz_path)
    # autoload_disabled = get(ENV, "GRUG_NO_AUTOLOAD", "") == "1"
    #
    # if !autoload_disabled && isfile(default_specimen_path)
    #     println("🧠 Default specimen detected at $(default_specimen_path) — auto-loading...")
    #     try
    #         summary = load_specimen_from_file!(default_specimen_path)
    #         println("  ✅ Default specimen restored.")
    #         for ln in Iterators.take(split(summary, '\n'), 6)
    #             println("    $ln")
    #         end
    #         println("  (Set GRUG_NO_AUTOLOAD=1 to skip this on next boot.)")
    #     catch e
    #         println("⚠️  Default specimen failed to load: $e")
    #         println("   Falling back to inline boot seeds.")
    #         _plant_inline_boot_seeds()
    #     end
    # else
    #     if autoload_disabled
    #         println("ℹ️  GRUG_NO_AUTOLOAD=1 — skipping default specimen auto-load.")
    #     end
    #     _plant_inline_boot_seeds()
    # end
    println("ℹ️  Default specimen auto-load DISABLED (v7.24-restore). Use /loadSpecimen to restore state.")
    _plant_inline_boot_seeds()
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

# GRUG: Idle-active guard. When ANY idle process (mitosis, chatter, phagy,
# relgov) is running, _IDLE_ACTIVE is true. User input processing waits
# for idle to finish before touching shared state. No interleaving.
const _IDLE_ACTIVE = Ref{Bool}(false)

# GRUG: Phagy rules vector and lock for RULE PRUNER automaton.
# These are the live orchestration rules registered via /addRule.
# PhagyMode.prune_dormant_rules! expects: rules with fire_count, dormancy_strikes, is_dormant fields.
const PHAGY_RULES_REF  = Ref{Vector}(Vector())
const PHAGY_RULES_LOCK = ReentrantLock()
"""
maybe_run_idle()

GRUG: Check if cave is idle enough for an idle action (v7.1 — SLOW TIMER).
Uses ChatterMode.should_trigger_idle() which checks the SHARED 120s ±30s timer.
All idle modes (chatter, phagy, mitosis) use this SAME timer. One idle event, one action.

POPULATION GATES:
  - Chatter requires >= 1000 alive non-image nodes (mature specimens only).
  - Phagy requires >= 1000 alive non-image nodes (mature specimens only).
  - Mitosis requires >= MIN_POPULATION_GATE (10) nodes — even small specimens can grow!

STOCHASTIC LEVER MODEL:
  - Mitosis is a STOCHASTIC lever: only MITOSIS_PROBABILITY (15%) of eligible
    idle cycles even attempt it. Most idle cycles, mitosis rolls tails and
    nothing happens. Combined with the 120s ±30s timer, that's roughly one
    mitosis ATTEMPT every ~13 minutes of idle. And warrant may still say no.
  - When mitosis DOES fire and grow a node, it auto-latches to the best
    related non-UNLINKABLE neighbor (find_best_latch_target / try_link_nodes!).
    No floaters — every new node connects to the web.
  - For mature specimens, 50/50 Chatter or Phagy follows after mitosis check.
  - For small specimens (< 1000 nodes), mitosis is the ONLY idle action.
"""
function maybe_run_idle()
    # GRUG: Don't start if chatter is already running (single-threaded loop guard)
    status = ChatterMode.get_chatter_status()
    status.is_running && return

    # GRUG: Check idle threshold (v7.1: 120s ±30s, shared timer for all idle modes)
    !ChatterMode.should_trigger_idle(LAST_INPUT_TIME[]) && return

    # GRUG: Mark idle as ACTIVE. User input will wait for this to clear.
    _IDLE_ACTIVE[] = true

    try  # GRUG: finally block guarantees _IDLE_ACTIVE clears on every exit path
    # GRUG: Count alive non-image nodes for population gate.
    alive_count = lock(NODE_LOCK) do
        count(n -> !n.is_grave && !n.is_image_node, values(NODE_MAP))
    end

    # GRUG: Count all alive nodes (including image) for mitosis gate.
    alive_all = lock(NODE_LOCK) do
        count(n -> !n.is_grave, values(NODE_MAP))
    end

    # ── GROWTH AUTOMATON PATH — lobe-aware ephemeral node growth ──────────
    # GRUG: Replaces the old MitosisMode idle cycle (disabled in commit 1eb8e85).
    # The growth automaton spawns in ONE named lobe at a time, reads fresh
    # (unconsumed) MESSAGE_HISTORY entries, extracts vote + pattern activator
    # data, grows a few new nodes, then latches them to related groups that
    # pass the strength floor. If no group passes, nodes remain free agents.
    # Runs BEFORE chatter/phagy — even a small specimen can grow.
    try
        growth_stats = TemporalGrowth.run_growth_automaton!(
            node_map              = NODE_MAP,
            node_lock             = NODE_LOCK,
            message_history       = MESSAGE_HISTORY,
            history_lock          = MESSAGE_HISTORY_LOCK,
            lobe_registry         = Lobe.LOBE_REGISTRY,
            group_map             = GROUP_MAP,
            group_lock            = GROUP_LOCK,
            node_to_lobe_idx      = Lobe.NODE_TO_LOBE_IDX,
            create_node_fn        = create_node,
            add_to_group_fn       = add_to_group!,
            group_latch_fn        = (pattern; node_map=NODE_MAP, node_lock=NODE_LOCK, requesting_node_is_time=false) ->
                find_group_latch_candidates(pattern; node_map=node_map, node_lock=node_lock, requesting_node_is_time=requesting_node_is_time, thesaurus_fn=Thesaurus.get_seed_synonyms),
            link_to_group_member_fn = link_to_group_member,
            immune_gate_fn        = (pattern, data) -> begin
                json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                immune_gate("/growth", json_text; is_critical=false)
            end,
            thesaurus_fn          = Thesaurus.synonym_lookup,
            # GRUG v7.50: Hippocampal strain — endocrine bridge from EphemeralMLP.
            # When the system hurts from novel input it can't handle, strain
            # boosts growth probability even without fresh data.
            strain_energy_fn      = () -> EphemeralMLP.get_strain_energy(),
        )

        # GRUG: Report growth results. Stochastic skip is the NORMAL case — silent.
        if growth_stats.status == "grew"
            println("[IDLE:GROWTH] 🌱  Grew $(growth_stats.nodes_grown) node(s) in $(growth_stats.lobe_id)('$(growth_stats.lobe_name)'), latched=$(growth_stats.nodes_latched), consumed=$(growth_stats.fresh_entries_consumed) | $(growth_stats.notes)")
        elseif growth_stats.status != "stochastic_skip"
            println("[IDLE:GROWTH] 🌱  $(growth_stats.status) | $(growth_stats.notes)")
        end
    catch e
        println("[IDLE:GROWTH] !!! ERROR during growth automaton cycle: $e !!!")
    end

    # ── AUTOGROWTH: IDLE-TIME EVIDENCE-BASED GROWTH SUPPLEMENT ──────────
    # GRUG: TemporalGrowth runs on fresh MESSAGE_HISTORY data. But the
    # evidence accumulator may have PENDING evidence from live conversation
    # that hasn't reached the coinflip threshold yet. Here in idle time,
    # we give it another chance to fire. Also discover thesaurus pairs
    # from accumulated co-occurrence data.
    try
        _ag_idle_result = AutoGrowth.maybe_grow_from_evidence!(
            node_map                   = NODE_MAP,
            node_lock                  = NODE_LOCK,
            create_node_fn             = create_node,
            add_to_group_fn            = add_to_group!,
            register_group_fn          = register_group!,
            group_map                  = GROUP_MAP,
            group_lock                 = GROUP_LOCK,
            lobe_registry              = Lobe.LOBE_REGISTRY,
            immune_gate_fn             = (pattern, data) -> begin
                json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                immune_gate("/autogrowth_idle", json_text; is_critical=false)
            end,
            thesaurus_gate_filter      = Thesaurus.synonym_lookup,
            thesaurus_word_similarity  = Thesaurus.word_similarity,
            add_lobe_whitelist_fn      = (lobe_id, token) -> Lobe.add_lobe_whitelist!(lobe_id, token),
            register_sigil_fn          = (args...; kwargs...) -> SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE, args...; kwargs...),
            register_thesaurus_pair_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
            stochastic_aiml_growth_fn  = (lobe_id, pattern; data_warrant=1.0) ->
                AIMLNodeSystem.stochastic_aiml_growth!(lobe_id, pattern; data_warrant=data_warrant),
            group_latch_fn             = (pattern; node_map=NODE_MAP, node_lock=NODE_LOCK, requesting_node_is_time=false) ->
                find_group_latch_candidates(pattern; node_map=node_map, node_lock=node_lock, requesting_node_is_time=requesting_node_is_time, thesaurus_fn=Thesaurus.get_seed_synonyms),
            link_to_group_member_fn    = link_to_group_member,
            group_avg_strength_fn      = (gid) -> lock(GROUP_LOCK) do
                grp = get(GROUP_MAP, gid, nothing)
                grp === nothing && return 0.0
                isempty(grp.node_ids) && return 0.0
                total = 0.0; count = 0
                for nid in grp.node_ids
                    n = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                    if n !== nothing && !n.is_grave; total += n.strength; count += 1 end
                end
                count > 0 ? total / count : 0.0
            end,
            group_for_fn               = (nid) -> lock(GROUP_LOCK) do
                for (gid, grp) in GROUP_MAP
                    if nid in grp.node_ids; return gid end
                end
                nothing
            end,
            sigil_promote_fn           = (text) -> SigilPromoter.promote_input(_ENGINE_SIGIL_TABLE, text),
            extract_triples_fn         = (pat) -> extract_relational_triples(pat),
            evaluate_dialectics_fn     = (triples; kwargs...) -> evaluate_relational_dialectics(triples; kwargs...),
            words_to_signal_fn         = (words) -> PatternScanner.words_to_signal(words),
            scan_latch_candidates_fn   = (pattern, action_packet; kwargs...) -> _scan_latch_candidates(pattern, action_packet; kwargs...),
            # GRUG v7.58: verb→sigil reverse mapping + user text for relational pattern promotion
            verb_class_of_fn           = (verb) -> SemanticVerbs.verb_class_of(verb),
            user_text                  = try MESSAGE_HISTORY[end].text catch _ "" end,
            sigil_table                = _ENGINE_SIGIL_TABLE,
            mlp_rule_hints             = try EphemeralMLP.get_active_rule_hints() catch _ Dict{String, Any}[] end,
        )
        if _ag_idle_result !== nothing && _ag_idle_result.won_coinflip
            println("[IDLE:AUTOGROWTH] 🌱  Grew $(_ag_idle_result.growth_type) for '$(_ag_idle_result.pattern)' in $(_ag_idle_result.lobe_hint)")
        end

        # GRUG: Also try discovering thesaurus pairs from co-occurrence data.
        _ag_pairs = AutoGrowth.discover_thesaurus_pairs!(
            register_thesaurus_pair_fn = (a, b) -> Thesaurus.add_seed_synonym!(a, [b]),
            thesaurus_word_similarity  = Thesaurus.word_similarity,
        )
        if !isempty(_ag_pairs)
            println("[IDLE:AUTOGROWTH] 📖  Discovered thesaurus pairs: $(_ag_pairs)")
        end
    catch e
        println("[IDLE:AUTOGROWTH] !!! ERROR during idle autogrowth: $e !!!")
    end

    # ── AUTOLINKER: IDLE-TIME EVIDENCE-BASED BRIDGE GROWTH ──────────────
    # GRUG: During idle time, give the link accumulator another chance to
    # fire. Evidence that accumulated during active conversation may have
    # reached the coinflip threshold by now. Cross-lobe bridges especially.
    try
        # GRUG: Snapshot bridge map for cap checks + neighbor evidence.
        _al_idle_bridge_snap = lock(BRIDGE_LOCK) do
            snap = Dict{String, Vector{Tuple{String,String}}}()
            for (nid, bridges) in BRIDGE_MAP
                snap[nid] = [(br.partner_id, join(br.seam_tokens, " ")) for br in bridges]
            end
            snap
        end

        # GRUG: Snapshot node patterns for synonym bridge evidence.
        _al_idle_nid_pat = lock(NODE_LOCK) do
            [(n.id, n.pattern) for n in values(NODE_MAP) if !n.is_grave && !n.is_image_node]
        end

        _al_idle_lobe_of = (nid) -> Lobe.find_lobe_for_node(nid)
        _al_idle_co_occur_raw = AutoGrowth.get_co_occur_snapshot()
        _al_idle_co_occur = Dict{Tuple{String,String}, Int}()
        for entry in _al_idle_co_occur_raw
            a = get(entry, "a", ""); b = get(entry, "b", ""); c = get(entry, "count", 0)
            if !isempty(a) && !isempty(b) && c > 0
                key = a < b ? (a, b) : (b, a)
                _al_idle_co_occur[key] = c
            end
        end

        # GRUG: Accumulate link evidence from idle-time data.
        # Mine RelationalGovernance CO_ACC for high-intensity pairs. Unlike
        # co_fired_ids (which generates ALL pairs from a set), we pass explicit
        # (id_a, id_b, intensity) triples to avoid cross-pair contamination.
        _al_idle_co_act_pairs = Tuple{String,String,Float64}[]
        try
            _al_idle_co_acc_data = RelationalGovernance.serialize_co_activation()
            _al_idle_pairs_dict = get(_al_idle_co_acc_data, "co_activation_pairs", Dict{String,Any}())
            for (pair_key_str, intensity) in _al_idle_pairs_dict
                if Float64(intensity) >= 5.0  # GRUG: Only use strong co-activation pairs
                    parts = split(String(pair_key_str), "|")
                    if length(parts) == 2
                        push!(_al_idle_co_act_pairs, (String(parts[1]), String(parts[2]), Float64(intensity)))
                    end
                end
            end
        catch; end


        # GRUG v10: Compute strain_nodes from nodes currently under strain for idle path.
        # Same logic as active path — nodes with strength < 0.3 are under strain.
        _al_idle_strain_nodes = try
            _idle_strain_ids = String[]
            for (nid, node) in NODE_MAP
                if !node.is_grave && node.strength < 0.3
                    push!(_idle_strain_ids, nid)
                end
            end
            _idle_strain_ids
        catch _
            String[]
        end

        # GRUG v10: Get EphemeralMLP signal values for idle AutoLinker.
        # Use the last MLP transform results — they persist between cycles.
        _al_idle_mlp_disambig = try
            Float64(get(EphemeralMLP.get_last_result(), "disambiguation", 0.5))
        catch _
            0.5
        end
        _al_idle_mlp_relevance = try
            Float64(get(EphemeralMLP.get_last_result(), "relevance_score", 0.5))
        catch _
            0.5
        end

        # GRUG v10: Get ChatterResiduals co-occurrence pairs for idle path.
        # Unlike active path (which is empty), idle path has time to mine
        # the chatter log for word co-occurrence pairs.
        _al_idle_chatter_pairs = try
            _cr_idle_status = ChatterResiduals.get_chatter_residuals_status()
            # GRUG: Parse co-occurrence pairs from chatter residuals status.
            # The status dict may contain "co_occur_pairs" with (word_a, word_b, intensity) data.
            _cr_pairs = get(_cr_idle_status, "co_occur_pairs", [])
            _cr_result = Tuple{String,String,Float64}[]
            if isa(_cr_pairs, AbstractVector)
                for pair_entry in _cr_pairs
                    a = get(pair_entry, "a", "")
                    b = get(pair_entry, "b", "")
                    intensity = Float64(get(pair_entry, "intensity", 0.0))
                    if !isempty(a) && !isempty(b) && intensity >= 3.0
                        push!(_cr_result, (a, b, intensity))
                    end
                end
            end
            _cr_result
        catch _
            Tuple{String,String,Float64}[]
        end

        AutoLinker.accumulate_link_evidence!(
            co_fired_ids              = String[],  # GRUG: No direct co-fire data in idle
            input_touched_ids         = String[],
            node_ids_patterns         = _al_idle_nid_pat,
            bridge_map_snapshot       = _al_idle_bridge_snap,
            thesaurus_gate_filter     = Thesaurus.synonym_lookup,
            thesaurus_word_similarity = Thesaurus.word_similarity,
            lobe_of_fn                = _al_idle_lobe_of,
            strain_nodes              = _al_idle_strain_nodes,  # GRUG v10: was String[], now computed from NODE_MAP
            co_occur_map              = _al_idle_co_occur,
            co_activation_pairs       = _al_idle_co_act_pairs,
            # GRUG v10: New EphemeralMLP signal evidence sources for idle path
            mlp_disambiguation        = _al_idle_mlp_disambig,
            mlp_relevance_score       = _al_idle_mlp_relevance,
            chatter_co_occur_pairs    = _al_idle_chatter_pairs,
            mlp_novelty_score          = try EphemeralMLP.get_novelty_score() catch _ 0.5 end,
        )

        _al_idle_result = AutoLinker.maybe_auto_link!(
            node_map              = NODE_MAP,
            node_lock             = NODE_LOCK,
            bridge_fn             = (id_a, id_b; seam_tokens=String[]) ->
                bridge_nodes!(id_a, id_b; seam_tokens=seam_tokens),
            bridge_map_ref        = BRIDGE_MAP,
            bridge_lock_ref       = BRIDGE_LOCK,
            lobe_of_fn            = _al_idle_lobe_of,
            immune_gate_fn        = (pattern, data) -> begin
                json_text = JSON.json(Dict("pattern" => pattern, "data" => data))
                immune_gate("/autolinker_idle", json_text; is_critical=false)
            end,
            is_already_bridged_fn = (id_a, id_b) -> begin
                bridges_a = lock(() -> get(BRIDGE_MAP, id_a, CascadeBridge[]), BRIDGE_LOCK)
                for br in bridges_a
                    if br.partner_id == id_b
                        return true
                    end
                end
                return false
            end,
            node_alive_fn         = (nid) -> begin
                n = lock(() -> get(NODE_MAP, nid, nothing), NODE_LOCK)
                return !isnothing(n) && !n.is_grave
            end,
            thesaurus_gate_filter = Thesaurus.synonym_lookup,
        )

        if _al_idle_result !== nothing && _al_idle_result.won_coinflip
            cross_tag = _al_idle_result.is_cross_lobe ? "CROSS-LOBE" : "same-lobe"
            println("[IDLE:AUTOLINKER] 🔗  Bridged $(_al_idle_result.node_a) ↔ $(_al_idle_result.node_b) [$cross_tag]")
        end
    catch e
        println("[IDLE:AUTOLINKER] !!! ERROR during idle autolink: $e !!!")
    end

    # ── CHATTER/PHAGY PATH — only for mature specimens (>= 1000 nodes) ────
    if alive_count < ChatterMode._effective_min_population()
        # GRUG: Population too small for chatter/phagy. But mitosis above may have fired.
        LAST_INPUT_TIME[] = time()
        return
    end

    # GRUG: THE COINFLIP. For mature specimens, 50/50 Chatter or Phagy.
    # Mitosis already ran above (it always gets a chance regardless of population).
    if rand() < 0.5
        # ── HEADS: CHATTER ──────────────────────────────────────────────────

        # GRUG (v8.0): ChatterMode now takes group maps directly instead of
        # a snapshot. Group-based dispatch: sample random groups, pair
        # strong+weak nodes, steal+remix votes, swap patterns.
        println("[IDLE] 🧬  Coinflip → CHATTER. Starting group-based gossip round...")

        try
            session = ChatterMode.start_chatter_session!(
                NODE_MAP, NODE_LOCK, GROUP_MAP, GROUP_LOCK;
                cooldown_query = (id) -> chatter_cooldown_remaining(id),
                stamp_fn       = stamp_chatter!,
                grave_fn       = (id, reason) -> begin
                    n = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
                    isnothing(n) || mark_node_grave!(n, reason)
                end,
            )
            ChatterMode.apply_chatter_diffs!(session, NODE_MAP, NODE_LOCK;
                                             stamp_fn = stamp_chatter!)
            # GRUG BUG-010b: Chatter swapped patterns+action_packets, so inhibition
            # tokens are now stale (remixed content should NOT contribute to inhibition).
            # Mark all chattered groups dirty so next is_inhibited check refreshes.
            for clone in session.clones
                if clone.accepted_swap
                    grp = group_for(clone.source_id)
                    if !isnothing(grp)
                        grp.inhibition_dirty = true
                    end
                end
            end
            try
                ChatterMode.persist_chatter_log!()
            catch e
                @warn "[IDLE:CHATTER] persist_chatter_log! failed: $e"
            end
        catch e
            if e isa ChatterMode.ChatterError
                println("[IDLE:CHATTER] ⛔  $(e.msg)")
            else
                println("[IDLE:CHATTER] !!! ERROR during chatter session: $e !!!")
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end

    else
        # ── TAILS: PHAGY ──────────────────────────────────────────────────
        # GRUG: Phagy fires for mature specimens (1000+ nodes, gated above).
        println("[IDLE] 🧬  Coinflip → PHAGY. Running maintenance automaton...")

        try
            # GRUG v7.30: Pass all system references so new automata 8-12 can
            # do idle-time maintenance on vigilance, phase accumulator, observer
            # store, sigil table, and trajectory buffer. Dependency-gated: if a
            # kwarg is nothing, that automaton is excluded from the roll.
            # ⚠️  HOPFIELD_CACHE / HOPFIELD_CACHE_LOCK below are DEAD vestigial
            #     positional args. Automaton 7 (CACHE_VALIDATOR) is disabled.
            #     Ignore them — they do nothing.
            phagy_stats = PhagyMode.run_phagy!(
                NODE_MAP,
                NODE_LOCK,
                HOPFIELD_CACHE,
                HOPFIELD_CACHE_LOCK,
                PHAGY_RULES_REF[],
                PHAGY_RULES_LOCK;
                message_history       = MESSAGE_HISTORY,
                history_lock          = MESSAGE_HISTORY_LOCK,
                injector_dict         = EphemeralAutomaton._ACTIVE_INJECTORS,
                injector_lock         = EphemeralAutomaton._INJECTOR_LOCK,
                phase_acc             = EphemeralAutomaton._phase_accumulator(),
                observer_store        = _MLP_OBSERVER_STORE,
                sigil_table           = _ENGINE_SIGIL_TABLE,
                trajectory_config_ref = ActionTonePredictor._trajectory_config,
                trajectory_buffer     = ActionTonePredictor._trajectory_buffer,
                trajectory_lock       = ActionTonePredictor._trajectory_lock,
                # GRUG v7.31: Full organ coverage — pass every organ to phagy.
                lobe_registry              = Lobe.LOBE_REGISTRY,
                lobe_lock                  = Lobe.LOBE_LOCK,
                chatter_node_cooldown      = CHATTER_NODE_COOLDOWN,
                chatter_node_cooldown_lock = CHATTER_NODE_COOLDOWN_LOCK,
                morph_cooldown_map         = ChatterMode.MORPH_COOLDOWN_MAP,
                morph_cooldown_lock        = ChatterMode.MORPH_COOLDOWN_LOCK,
                attachment_map             = BRIDGE_MAP,      # GRUG v8.0: BRIDGE_MAP passed as attachment_map (PhagyMode kwarg name)
                attachment_lock            = BRIDGE_LOCK,     # GRUG v8.0: BRIDGE_LOCK passed as attachment_lock (PhagyMode kwarg name)
                group_map                  = GROUP_MAP,
                group_lock                 = GROUP_LOCK,
                node_to_group              = NODE_TO_GROUP,
                immune_ledger              = ImmuneSystem.IMMUNE_LEDGER,
                ledger_lock                = ImmuneSystem.LEDGER_LOCK,
                chatter_log                = ChatterMode.CHATTER_LOG,
                chatter_log_lock           = ChatterMode.CHATTER_LOG_LOCK,
                mitosis_log                = MitosisMode.MITOSIS_LOG,
                mitosis_log_lock           = MitosisMode.MITOSIS_LOG_LOCK,
                mlp_state                  = EphemeralMLP._state(),
            )

            println("[IDLE:PHAGY] 🧹  Automaton=$(phagy_stats.automaton), Processed=$(phagy_stats.items_processed), Changed=$(phagy_stats.items_changed), Time=$(round(phagy_stats.cycle_time_ms, digits=2))ms")
        catch e
            if e isa PhagyMode.PhagyError
                println("[IDLE:PHAGY] ⛔  $(e.msg)")
            else
                println("[IDLE:PHAGY] !!! ERROR during phagy cycle: $e !!!")
            end
        end
    end

    # ── RELATIONAL GOVERNANCE — auto-attach from accumulated co-activation ────
    # GRUG: Runs AFTER chatter/phagy. Lazy, conservative, stochastic.
    # Only AUTO_ATTACH_PROB (10%) of idle cycles even attempt an auto-attach.
    # When it doesn't roll, it still decays stale pairs. Moss on rock.
    # Nodes that fire together wire together — SLOWLY, EARNED, ORGANIC.
    try
        gov_stats = RelationalGovernance.run_relational_governance!(;
            attach_fn        = (target_id, attach_id, pattern) -> bridge_nodes!(target_id, attach_id; seam_tokens=split(pattern)),
            token_overlap_fn = (id_a, id_b) -> begin
                na = lock(() -> get(NODE_MAP, id_a, nothing), NODE_LOCK)
                nb = lock(() -> get(NODE_MAP, id_b, nothing), NODE_LOCK)
                if isnothing(na) || isnothing(nb)
                    return 0.0
                end
                _token_overlap_similarity(na.pattern, nb.pattern)
            end,
            node_map_ref     = NODE_MAP,
            node_lock_ref    = NODE_LOCK,
            immune_gate_fn   = (pattern, data) -> begin
                json_text = JSON.json(Dict("pattern" => pattern, "source" => "relgov", "data" => data))
                immune_gate("/relgov", json_text; is_critical=false)
            end,
        )
        # GRUG: Only print if something interesting happened (not on skip/noise).
        if gov_stats.event != "skipped_stochastic_gate" && gov_stats.event != "no_pairs_above_threshold"
            println("[IDLE:RELGOV] 🔗  $(gov_stats.event): $(gov_stats.notes) ($(round(gov_stats.cycle_time_ms, digits=2))ms)")
        end
    catch e
        # GRUG: Relational governance failure is non-fatal. Don't crash the idle loop.
        println("[IDLE:RELGOV] !!! ERROR during relational governance cycle: $e !!!")
    end

    # GRUG: Reset idle timer after ANY idle action so the next event waits a full interval.
    LAST_INPUT_TIME[] = time()

    finally  # GRUG: ALWAYS clear idle-active flag, even on early return or error
        _IDLE_ACTIVE[] = false
    end
end

# ==============================================================================
# MAIN CLI LOOP
# ==============================================================================

"""
_assert_node_in_lobe(lobe_id::String, node_id::String, cmd::String)

GRUG: Validate a node truly belongs to the lobe the user named. Catches
copy-paste mistakes and cross-lobe id collisions BEFORE the engine fires.
Throws a clean FATAL the user can read instead of letting silent state-mismatch
percolate. Used by every node-targeted CLI command (/nodeBridge, /nodeAttach,
/nodeUnbridge, /nodeDetach, /imgnodeAttach, /imgnodeDetach, /crystalize,
/decrystalize) so each command is
self-documenting and addressable from a script without first running /lobes.
"""
function _assert_node_in_lobe(lobe_id::String, node_id::String, cmd::String)
    if !haskey(Lobe.LOBE_REGISTRY, lobe_id)
        existing = sort(collect(keys(Lobe.LOBE_REGISTRY)))
        existing_list = join(existing, ", ")
        error("!!! FATAL: $cmd: lobe '$lobe_id' does not exist. " *
              "Known lobes: [$existing_list]. !!!")
    end
    rec = Lobe.LOBE_REGISTRY[lobe_id]
    if !(node_id in rec.node_ids)
        members = sort(collect(rec.node_ids))
        preview_list = length(members) > 8 ? join(members[1:8], ", ") * ", ..." : join(members, ", ")
        error("!!! FATAL: $cmd: node '$node_id' is not a member of lobe '$lobe_id'. " *
              "Lobe members: [$preview_list]. !!!")
    end
    return true
end

"""
    _assert_node_exists(node_id::String, cmd::String)

GRUG v8.0: Validate a node exists in ANY lobe. Used by cross-lobe bridge
commands (/crystalize, /decrystalize) where the partner node may be in a
different lobe from the first. Throws FATAL if node not found anywhere.
"""
function _assert_node_exists(node_id::String, cmd::String)
    found_lobe = Lobe.find_lobe_for_node(node_id)
    if isnothing(found_lobe)
        lock(NODE_LOCK) do
            if !haskey(NODE_MAP, node_id)
                error("!!! FATAL: $cmd: node '$node_id' does not exist on the map! !!!")
            end
        end
    end
    return true
end


"""
run_cli()

GRUG: Main REPL loop. Prints boot message, then loops forever reading input.
Dispatches commands (/ prefix) or runs mission scan. Triggers idle chatter/phagy
between inputs via maybe_run_idle(). This is the top-level entry point.
"""
# GRUG v7.58: Save-on-exit prompt. When the user quits, ask if they want
# to save the current specimen (autogrowth may have mutated state).
function _maybe_save_specimen_on_exit()
    last_path = lock(_LAST_SPECIMEN_PATH_LOCK) do
        _LAST_SPECIMEN_PATH[]
    end
    if isempty(last_path)
        # No specimen was ever loaded — skip prompt
        return
    end
    try
        print("
[GRUG] 💾 Would you like to save the current specimen? (y/n): ")
        answer = lowercase(strip(readline()))
        if startswith(answer, "y")
            # Save to the same path it was loaded from
            println("[GRUG] Saving specimen to: $last_path")
            result = save_specimen_to_file!(last_path)
            println("[GRUG] $result")
        else
            println("[GRUG] Specimen not saved. Goodbye.")
        end
    catch
        # readline may fail if stdin is already closed (scripted exit)
        # Just skip silently
    end
end

function run_cli()
    print(BOOT_MSG)

    # GRUG: Start the InputLedger background thread. It watches MESSAGE_HISTORY
    # for fresh entries and digests them into growth data for mitosis and
    # relational governance. The gut that keeps digesting input into nutrients.
    # Runs in its own @async thread with crash-restart loop. Never dies.
    try
        InputLedger.start_input_ledger_thread!(;
            message_history_ref = MESSAGE_HISTORY,
            history_lock_ref    = MESSAGE_HISTORY_LOCK,
            node_map_ref        = NODE_MAP,
            node_lock_ref       = NODE_LOCK,
            co_occur_fn         = (id_a, id_b, increment) ->
                RelationalGovernance.observe_direct_co_occurrence!(id_a, id_b, increment),
            token_overlap_fn    = (id_a, id_b) -> begin
                na = lock(() -> get(NODE_MAP, id_a, nothing), NODE_LOCK)
                nb = lock(() -> get(NODE_MAP, id_b, nothing), NODE_LOCK)
                if isnothing(na) || isnothing(nb)
                    return 0.0
                end
                _token_overlap_similarity(na.pattern, nb.pattern)
            end,
        )
    catch e
        @warn "[MAIN] Failed to start InputLedger thread (non-fatal, will restart on demand): $e"
    end

    # GRUG: Start the ChatterResiduals background thread. It watches
    # CHATTER_LOG for fresh vote swaps and mines them as residual
    # co-occurrence data. When chatter swaps votes into weak nodes,
    # those nodes become multi-activator randomized types — globally
    # unlinkable. The RESIDUAL is the co-occurrence between weak node
    # and strong donor. Secondary channel (1.5 increment).
    # Runs in its own @async thread with crash-restart loop. Never dies.
    try
        ChatterResiduals.start_chatter_residuals_thread!(;
            chatter_log_ref     = ChatterMode.CHATTER_LOG,
            chatter_log_lock_ref = ChatterMode.CHATTER_LOG_LOCK,
            node_map_ref        = NODE_MAP,
            node_lock_ref       = NODE_LOCK,
            co_occur_fn         = (id_a, id_b, increment) ->
                RelationalGovernance.observe_direct_co_occurrence!(id_a, id_b, increment),
            token_overlap_fn    = (id_a, id_b) -> begin
                na = lock(() -> get(NODE_MAP, id_a, nothing), NODE_LOCK)
                nb = lock(() -> get(NODE_MAP, id_b, nothing), NODE_LOCK)
                if isnothing(na) || isnothing(nb)
                    return 0.0
                end
                _token_overlap_similarity(na.pattern, nb.pattern)
            end,
        )
    catch e
        @warn "[MAIN] Failed to start ChatterResiduals thread (non-fatal): $e"
    end

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
            # GRUG v7.58: Try to save specimen before EOF exit (may fail if stdin is closed).
            _maybe_save_specimen_on_exit()
            break
        end

        line = strip(readline())

        line == "" && continue

        # GRUG v7.34: Skip comment lines. When stdin is a heredoc (scripted
        # input), shell comment lines like "# --- Warm-up: Social ---" pass
        # through and hit the command matcher, producing "bad format" errors.
        # Stripping them here eliminates ~78 noise errors per session.
        startswith(line, "#") && continue

        # GRUG 7.12: /quit (and /exit alias) — explicit, loud shutdown. Scripted
        # drivers use this as the last command of a seed/conversation file so
        # Julia exits with code 0 and log capture tools see a clean close.
        # NO SILENT FAILURE: always print a shutdown banner before returning.
        if line == "/quit" || line == "/exit"
            println("[GRUG] 👋 /quit received. Cave closes. Goodbye.")
            # GRUG: Stop the InputLedger background thread before exit.
            # It's a @async task — signal it to stop so it doesn't linger.
            try
                InputLedger.stop_input_ledger_thread!()
            catch
                # GRUG: Best-effort. Thread might already be stopped.
            end
            # GRUG: Stop the ChatterResiduals background thread before exit.
            # Same pattern — signal it to stop so it doesn't linger.
            try
                ChatterResiduals.stop_chatter_residuals_thread!()
            catch
                # GRUG: Best-effort. Thread might already be stopped.
            end
            # GRUG v7.58: Ask if user wants to save specimen before exit.
            _maybe_save_specimen_on_exit()
            break
        end

        # GRUG: Update last input time so idle detector resets
        LAST_INPUT_TIME[] = time()

        # GRUG: Wait for any idle process to finish before touching shared state.
        # Idle processes (mitosis, chatter, phagy, relgov) touch NODE_MAP,
        # BRIDGE_MAP, and other shared structures. User input also reads
        # and writes them. No interleaving. User input waits for idle.
        if _IDLE_ACTIVE[]
            println("[MAIN] ⏳  Idle process active — waiting for it to finish...")
            while _IDLE_ACTIVE[]
                sleep(0.05)  # GRUG: 50ms poll. Not spin-burning CPU.
            end
        end

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
            # GRUG v7.23: Automaton management commands
            m_autolist    = match(r"^/automaton\s+list\s*$",              line)
            m_autoreg     = match(r"^/automaton\s+register\s+(\S+)\s+(\S+)\s+(\d+(?:\.\d+)?)\s*$", line)
            m_autoremove  = match(r"^/automaton\s+remove\s+(\S+)\s*$",   line)
            # GRUG v7.24: EphemeralMLP management commands
            m_mlprule_add = match(r"^/mlpRule\s+add\s+(\S+)\s+(\S+)\s+(\S+)\s*$", line)
            m_mlprule_drop= match(r"^/mlpRule\s+drop\s+(\S+)\s*$", line)
            m_mlprule_list= match(r"^/mlpRule\s+list\s*$", line)
            m_mlpstatus   = match(r"^/mlpStatus\s*$", line)
            m_mlpthreshold= match(r"^/mlpThreshold\s+(\d+)\s*$", line)
            m_mlpobserver = match(r"^/mlpObserver\s*$", line)
            m_mitosisstatus = match(r"^/mitosisStatus\s*$", line)
            m_growthstatus  = match(r"^/growthStatus\s*$", line)
            m_autogrowstatus = match(r"^/autoGrowStatus\s*$", line)
            m_autolinkstatus = match(r"^/autoLinkStatus\s*$", line)
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
            m_addseedsyn  = match(r"^/addSeedSynonym\s+(\S+)\s+(.+)$",      line)
            m_addantimatch= match(r"^/addAntiMatch\s+(.+)$",                 line)
            # GRUG v7.55: /addRelRelation <name> <alt1 alt2 alt3 ...>
            # Register a :relation-class sigil for dynamic relational triples.
            m_addrelrelation = match(r"^/addRelRelation\s+(\S+)\s+(.+)$",  line)
            m_answer      = match(r"^/answer(?:\s+@(\S+))?(?:\s+:(\w+))?\s+(.+)$",            line)  # GRUG v7.52: @lobe_id + :mode
            m_antianswer  = match(r"^/antiAnswer(?:\s+@(\S+))?(?:\s+:(\w+))?\s+(.+)$",          line)  # GRUG v7.52: @lobe_id + :mode
            m_listverbs   = match(r"^/listVerbs\s*$",                        line)
            # GRUG: Lobe management commands
            m_newlobe     = match(r"^/newLobe\s+(\S+)\s+(.+)$",               line)
            m_namelobe    = match(r"^/nameLobe\s+(\S+)\s+(.+)$",               line)
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
            # GRUG v7.28: Decomposer config commands (conjunctions, markers, conjugation)
            # /decomposer status                          — show full config
            # /decomposer addConjunction <word>           — add split conjunction
            # /decomposer removeConjunction <word>        — remove split conjunction
            # /decomposer addCompound <leader> <follower> — add compound pair
            # /decomposer removeCompound <leader> <follower> — remove compound pair
            # /decomposer addQuestion <word>              — add question marker
            # /decomposer removeQuestion <word>           — remove question marker
            # /decomposer addCommand <stem> [form1 form2 ...] — add command marker + conjugation
            # /decomposer removeCommand <stem>            — remove command marker + conjugation
            # /decomposer addConjugation <stem> <form1> [form2 ...] — set conjugation rule
            # /decomposer removeConjugation <stem>        — remove conjugation rule
            # /decomposer setContext <word>               — set context conjunction ("and")
            # /decomposer reset                           — reset to built-in defaults
            m_decomp_status    = match(r"^/decomposer\s+(?:status)?\s*$",                         line)
            m_decomp_addconj   = match(r"^/decomposer\s+addConjunction\s+(\S+)\s*$",              line)
            m_decomp_remconj   = match(r"^/decomposer\s+removeConjunction\s+(\S+)\s*$",           line)
            m_decomp_addcomp   = match(r"^/decomposer\s+addCompound\s+(\S+)\s+(\S+)\s*$",          line)
            m_decomp_remcomp   = match(r"^/decomposer\s+removeCompound\s+(\S+)\s+(\S+)\s*$",       line)
            m_decomp_addques   = match(r"^/decomposer\s+addQuestion\s+(\S+)\s*$",                  line)
            m_decomp_remques   = match(r"^/decomposer\s+removeQuestion\s+(\S+)\s*$",               line)
            m_decomp_addcmd    = match(r"^/decomposer\s+addCommand\s+(\S+)(?:\s+(.+))?\s*$",       line)
            m_decomp_remcmd    = match(r"^/decomposer\s+removeCommand\s+(\S+)\s*$",                line)
            m_decomp_addconjg  = match(r"^/decomposer\s+addConjugation\s+(\S+)\s+(.+)$",           line)
            m_decomp_remconjg  = match(r"^/decomposer\s+removeConjugation\s+(\S+)\s*$",            line)
            m_decomp_setctx    = match(r"^/decomposer\s+setContext\s+(\S+)\s*$",                   line)
            m_decomp_reset     = match(r"^/decomposer\s+reset\s*$",                               line)
            # GRUG v10: Flashcard CLI commands
            # /flashcard                        — show flashcard status (count per lobe)
            # /flashcard query <lobe_id> <expr>  — look up a flashcard
            # /flashcard evict <lobe_id> <expr>  — remove a flashcard
            # /flashcard count                   — show total card count
            m_flashcard_status = match(r"^/flashcard\s*$", line)
            m_flashcard_query  = match(r"^/flashcard\s+query\s+(\S+)\s+(.+)$", line)
            m_flashcard_evict  = match(r"^/flashcard\s+evict\s+(\S+)\s+(.+)$", line)
            m_flashcard_count  = match(r"^/flashcard\s+count\s*$", line)
            # GRUG v10: Curiosity CLI commands
            # /curiosity           — show curiosity accumulator status
            # /curiosity quench    — manually quench curiosity (reset intensity)
            m_curiosity_status = match(r"^/curiosity\s*$", line)
            m_curiosity_quench = match(r"^/curiosity\s+quench\s*$", line)
            # GRUG v7.27: Phase accumulator (time crystal) CLI commands
            # /automaton phase                         — show phase accumulator status
            # /automaton phase threshold <float>       — set pull threshold (0.1-0.9)
            # /automaton phase surface <int>           — set surface bit count (0-16)
            # /automaton phase enable                  — enable phase pull
            # /automaton phase disable                 — disable phase pull
            # /automaton phase reset                   — reset phase accumulator
            m_phase_status  = match(r"^/automaton\s+phase(?:\s+status)?\s*$",                    line)
            m_phase_thresh  = match(r"^/automaton\s+phase\s+threshold\s+([0-9.]+)\s*$",        line)
            m_phase_surface = match(r"^/automaton\s+phase\s+surface\s+(\d+)\s*$",             line)
            m_phase_enable  = match(r"^/automaton\s+phase\s+enable\s*$",                        line)
            m_phase_disable = match(r"^/automaton\s+phase\s+disable\s*$",                       line)
            m_phase_reset   = match(r"^/automaton\s+phase\s+reset\s*$",                         line)

            # GRUG v7.29: Automaton max cap and vigilance commands
            m_automaton_cap = match(r"^/automaton\s+maxCap\s+(\d+)\s*$",                       line)
            m_vigilance_status = match(r"^/vigilance(?:\s+status)?\s*$",                          line)
            m_vigilance_enable = match(r"^/vigilance\s+enable\s*$",                               line)
            m_vigilance_disable = match(r"^/vigilance\s+disable\s*$",                              line)
            m_vigilance_threshold = match(r"^/vigilance\s+threshold\s+(low|med|high|extreme)\s+([0-9.]+)\s*$", line)
            m_vigilance_timeout = match(r"^/vigilance\s+timeout\s+([0-9.]+)\s*$",                  line)
            m_vigilance_feedback = match(r"^/vigilance\s+feedback\s+([0-9.]+)\s*$",               line)

            # GRUG: Help command — show all commands
            m_loadspecimen = match(r"^/loadSpecimen\s+(\S+)\s*$",                          line)
            m_savespecimen = match(r"^/saveSpecimen\s+(\S+)\s*$",                          line)
            # GRUG: Admin commands (password protected)
            m_login        = match(r"^/login\s+(.+)$",                                     line)
            m_logout       = match(r"^/logout\s*$",                                        line)
            m_writesave    = match(r"^/writeSave\s+(\S+)\s+(.+)$"s,                        line)
            # GRUG: Relational fire system commands (node attachment)
            # GRUG: Node-targeted commands now require <lobe_id> as the first arg.
            # This disambiguates which lobe owns the node, makes the commands
            # script-addressable, and lets the CLI validate intent before the
            # engine fires. /nodeAttach takes pairs after the target_id.
            m_nodeattach   = match(r"^/node(Bridge|Attach)\s+(\S+)\s+(.+)"s,                     line)
            m_nodedetach   = match(r"^/node(Unbridge|Detach)\s+(\S+)\s+(\S+)\s+(\S+)\s*$",       line)
            m_imgnodeattach = match(r"^/imgnodeAttach\s+(\S+)\s+(.+)"s,                   line)
            m_imgnodedetach = match(r"^/imgnodeDetach\s+(\S+)\s+(\S+)\s+(\S+)\s*$",       line)
            m_attachments  = match(r"^/(attachments|bridges)\s*$",                                line)
            # GRUG: CRYSTALIZE — sticky attachments that bypass strength-biased coinflip
            m_crystalize   = match(r"^/crystalize\s+(\S+)\s+(\S+)\s+(\S+)\s*$",           line)
            m_decrystalize = match(r"^/decrystalize\s+(\S+)\s+(\S+)\s+(\S+)\s*$",         line)
            # GRUG v7.24: Sigil management commands. User-facing way to add
            # token sigils (lambda class: &n &op &word &rest) and macro sigils
            # (lexicon class: &noun, &mathconst, &mathfunc, etc) to the
            # _ENGINE_SIGIL_TABLE without round-tripping through a specimen file.
            #   /sigil list
            #   /sigil add <name> <class> <applies_at> [type=word|number|op|slurp] [lexicon=a,b,c] [promote=true|false]
            #   /sigil remove <name>
            m_sigillist   = match(r"^/sigil\s+list\s*$",                                    line)
            m_sigiladd    = match(r"^/sigil\s+add\s+(\S+)\s+(\S+)\s+(\S+)(?:\s+(.+))?\s*$", line)
            m_sigilremove = match(r"^/sigil\s+remove\s+(\S+)\s*$",                          line)
            # GRUG v9: CoherenceField command levers — expose implicit computations.
            #   /coherence                          — show field value Φ + status
            #   /coherenceGradient <node_id>        — show ΔΦ for candidate node
            #   /coherenceField                     — detailed field breakdown
            #   /coherenceConfig                    — show config (weight, depth, decay, etc.)
            #   /coherenceConfig weight <float>      — set routing weight (0.0=off, max 0.5)
            #   /coherenceConfig depth <int>         — set gradient walk depth (1-3)
            #   /coherenceConfig decay <float>       — set activation decay rate
            #   /coherenceConfig recency <float>     — set recency window (seconds)
            #   /coherenceConfig reset               — reset to defaults (weight=0.0)
            m_coherence         = match(r"^/coherence\s*$",                                   line)
            m_coherence_grad    = match(r"^/coherenceGradient\s+(\S+)\s*$",                   line)
            m_coherence_field   = match(r"^/coherenceField\s*$",                             line)
            m_coherence_config  = match(r"^/coherenceConfig(?:\s+(.+))?\s*$",                 line)
            m_errors            = match(r"^/errors(?:\s+(clear))?\s*$",                       line)
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
                # GRUG BUG-011: /wrong - user says last response was wrong.
                # Only lock-in votes can change strength, and even those are coinflip-gated.
                # Non-lock/unsure contributors never change strength.
                contributor_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_CONTRIBUTOR_IDS)
                end
                locked_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_LOCKED_NODE_IDS)
                end

                if isempty(contributor_ids)
                    println("⚠  /wrong: No previous contributors to penalize. Did you run /mission first?")
                elseif isempty(locked_ids)
                    println("⚠  /wrong: Previous response had no lock-in votes, so no node strength changed.")
                else
                    result = apply_wrong_feedback!(contributor_ids, locked_ids)
                    println("❌  /wrong applied lock-in-only. $(length(contributor_ids)) contributor(s), $(length(locked_ids)) locked: $(length(result["penalized"])) penalized, $(length(result["nonlocked_skipped"])) nonlocked skipped, $(length(result["coinflip_missed"])) missed coinflip.")
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

                # GRUG v7.24: EphemeralMLP wrong feedback — learns that this
                # directive path produced a bad result. Adjusts weights toward
                # avoiding similar patterns in the future. Non-fatal.
                try
                    EphemeralMLP.register_wrong_feedback!()
                catch e
                    @error "[MAIN] /wrong EphemeralMLP feedback FAILED (non-fatal): $e"
                end

elseif !isnothing(m_right)
                # GRUG BUG-011: /right - user says last response was good.
                # Lock-in-only reward: only locked votes can change strength,
                # and even those still go through stochastic bump_strength!.
                contributor_votes = lock(LAST_VOTER_LOCK) do
                    copy(LAST_CONTRIBUTOR_VOTES)
                end
                locked_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_LOCKED_NODE_IDS)
                end

                if isempty(contributor_votes)
                    println("⚠  /right: No previous contributors to reward. Did you run /mission first?")
                else
                    result = apply_right_feedback!(contributor_votes, locked_ids)
                    n_locked = count(v -> v.node_id in locked_ids, contributor_votes)
                    n_unsure = length(contributor_votes) - n_locked
                    println("✅ /right applied lock-in-only. $(length(contributor_votes)) contributor(s) [$n_locked locked, $n_unsure nonlocked]: $(length(result["rewarded"])) rewarded, $(length(result["nonlocked_skipped"])) nonlocked skipped, $(length(result["coinflip_missed"])) missed coinflip.")
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

                # GRUG v7.24: EphemeralMLP right feedback — learns that this
                # directive path produced a good result. Adjusts weights toward
                # reinforcing similar patterns in the future. Non-fatal.
                try
                    EphemeralMLP.register_right_feedback!()
                catch e
                    @error "[MAIN] /right EphemeralMLP feedback FAILED (non-fatal): $e"
                end

            elseif !isnothing(m_aimlright)
                # GRUG BUG-011: /aimlRight - user says AIML executive layer did good this cycle.
                # Rewards only AIML nodes with explicit orchestration contribution this cycle.
                # Mere voting/firing is ignored; eligible contributors still need the coinflip.
                result = AIMLNodeSystem.apply_aiml_right!()
                if result["total_contributors"] == 0
                    println("⚠  /aimlRight: No AIML orchestration contributors this cycle. Did output orchestration mark contributors?")
                else
                    println("✅  /aimlRight applied lock-in-only. $(length(result["rewarded"])) rewarded, $(length(result["coinflip_missed"])) missed coinflip, $(length(result["grave_skipped"])) grave skipped.")
                end

            elseif !isnothing(m_aimlwrong)
                # GRUG BUG-011: /aimlWrong - user says AIML executive layer did bad this cycle.
                # Penalizes only AIML nodes with explicit orchestration contribution this cycle.
                # No use-gain overcompensation exists because fire/use no longer changes strength.
                result = AIMLNodeSystem.apply_aiml_wrong!()
                if result["total_contributors"] == 0
                    println("⚠  /aimlWrong: No AIML orchestration contributors this cycle. Did output orchestration mark contributors?")
                else
                    newly_graved = length(result["newly_graved"])
                    println("❌  /aimlWrong applied lock-in-only. $(length(result["penalized"])) penalized, $(length(result["spared"])) spared by coinflip, $newly_graved newly graved, $(length(result["grave_skipped"])) grave skipped.")
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
                println("  • /aimlRight rewards explicit orchestration contributors only")
                println("  • /aimlWrong penalizes explicit orchestration contributors only")
                println("  • Mere AIML voting/firing never changes strength")
                println("  • Eligible contributors still change strength only by coinflip")
                println("  • Cycle counter increments with /mission calls")
                println("╚══════════════════════════════════════════════════════════════╝")

            elseif !isnothing(m_aimlphagy)
                # GRUG: /aimlPhagy - run phagy sweep on AIML graves.
                # GRUG: Removes grave nodes from registry (cleanup operation).
                # GRUG v7.34: FIX — aiml_phagy_sweep!() returns a Dict, not an Int.
                # The old code did `removed_count > 0` which threw MethodError(isless, (Dict, 0)).
                phagy_result = AIMLNodeSystem.aiml_phagy_sweep!()
                removed_count = get(phagy_result, "pruned_count", 0)
                if removed_count > 0
                    println("🧹  /aimlPhagy: Cleaned up $removed_count grave node(s) from AIML registry")
                else
                    println("✨  /aimlPhagy: No graves to clean. AIML registry already pristine!")
                end

            elseif !isnothing(m_autolist)
                # GRUG v7.23: /automaton list — show all registered automaton rules.
                rules = EphemeralAutomaton.list_automaton_rules()
                if isempty(rules)
                    println("📋  /automaton list: No rules registered. Cave has no step machines yet.")
                else
                    println("📋  /automaton list: $(length(rules)) rule(s) registered:")
                    for r in rules
                        jitter_str = isempty(r.jitter_targets) ? "none" :
                            join(sort(collect(r.jitter_targets)), ",")
                        println("  📎 $(r.id) | trigger=$(r.trigger_action) | min_conf=$(round(r.min_confidence, digits=2)) | steps=$(length(r.steps)) | jitter=$(jitter_str)")
                    end
                end

            elseif !isnothing(m_autoreg)
                # GRUG v7.23: /automaton register <id> <trigger_action> <min_confidence>
                # Creates a minimal automaton rule with a single :literal step as placeholder.
                # Users can build more complex rules programmatically; this CLI command
                # provides the quick-register path for testing and simple rules.
                rule_id, trigger, conf_str = m_autoreg.captures
                rule_id_str = String(rule_id)
                trigger_sym = Symbol(String(trigger))
                conf_val = tryparse(Float64, String(conf_str))
                if isnothing(conf_val)
                    println("⚠  /automaton register: invalid confidence '$(conf_str)'. Must be a number 0.0-1.0.")
                else
                    # GRUG: Create a minimal rule with one :literal step as placeholder.
                    # The user can replace this with a proper step chain programmatically.
                    placeholder_step = EphemeralAutomaton.AutomatonStep(
                        "placeholder", :literal, "auto-registered"
                    )
                    rule = EphemeralAutomaton.AutomatonRule(
                        rule_id_str, trigger_sym,
                        [placeholder_step];
                        min_confidence = conf_val
                    )
                    try
                        EphemeralAutomaton.register_automaton_rule!(rule)
                        println("✅  /automaton register: Rule '$rule_id_str' registered (trigger=$trigger_sym, min_conf=$(round(conf_val, digits=2)), 1 placeholder step)")
                    catch e
                        println("⚠  /automaton register failed: $e")
                    end
                end

            elseif !isnothing(m_autoremove)
                # GRUG v7.23: /automaton remove <id>
                rule_id_str = String(m_autoremove.captures[1])
                removed = EphemeralAutomaton.unregister_automaton_rule!(rule_id_str)
                if removed
                    println("🗑️  /automaton remove: Rule '$rule_id_str' removed from registry.")
                else
                    println("⚠  /automaton remove: Rule '$rule_id_str' not found in registry.")
                end

            elseif !isnothing(m_mlprule_add)
                # GRUG v7.24: /mlpRule add <pattern> <transform_type> <key>
                # Adds a user rule to the EphemeralMLP hash table.
                # transform_type must be "fuzzy" or "solid".
                # key is a named identifier for key-based activation and drop-table linking.
                rule_pattern = String(m_mlprule_add.captures[1])
                rule_transform = String(m_mlprule_add.captures[2])
                rule_key = String(m_mlprule_add.captures[3])
                if rule_transform ∉ ("fuzzy", "solid")
                    println("⚠  /mlpRule add: transform_type must be 'fuzzy' or 'solid', got '$rule_transform'")
                else
                    try
                        rule = EphemeralMLP.MLPTransformerRule(
                            next_runtime_id("user"),
                            rule_pattern;
                            key = rule_key,
                            transform_type = Symbol(rule_transform)
                        )
                        EphemeralMLP.add_mlp_rule!(rule)
                        println("✅  /mlpRule add: Rule '$(rule.id)' added (pattern='$rule_pattern', transform=$rule_transform, key='$rule_key')")
                    catch e
                        println("❌  /mlpRule add failed: $e")
                    end
                end

            elseif !isnothing(m_mlprule_drop)
                # GRUG v7.24: /mlpRule drop <rule_id>
                # Removes a user rule from the EphemeralMLP hash table.
                rule_id_to_drop = String(m_mlprule_drop.captures[1])
                removed = EphemeralMLP.drop_mlp_rule!(rule_id_to_drop)
                if removed
                    println("🗑️  /mlpRule drop: Rule '$rule_id_to_drop' removed.")
                else
                    println("⚠  /mlpRule drop: Rule '$rule_id_to_drop' not found.")
                end

            elseif !isnothing(m_mlprule_list)
                # GRUG v7.24: /mlpRule list
                # Shows all rules in the EphemeralMLP hash table.
                rules = EphemeralMLP.list_mlp_rules()
                if isempty(rules)
                    println("📋  /mlpRule list: No rules registered. Brain has no user instructions yet.")
                else
                    println("📋  /mlpRule list: $(length(rules)) rule(s) registered:")
                    for r in rules
                        status = r.enabled ? "ON" : "OFF"
                        println("  📎 $(r.id) | pattern='$(r.pattern)' | key='$(r.key)' | transform=$(r.transform_type) | fires=$(r.fire_count) | $status")
                    end
                end

            elseif !isnothing(m_mlpstatus)
                # GRUG v7.24: /mlpStatus — comprehensive EphemeralMLP status snapshot.
                mlp_st = EphemeralMLP.get_mlp_status()
                println("\n╔══════════════════════════════════════════════════════╗")
                println("║           EPHEMERAL MLP STATUS                      ║")
                println("╠══════════════════════════════════════════════════════╣")
                println("  Total transforms    : $(mlp_st["total_transforms"])")
                println("  Sigmoid activations : $(mlp_st["sigmoid_activations"])")
                println("  ReLU activations    : $(mlp_st["relu_activations"])")
                println("  Last activation     : $(mlp_st["last_activation"])")
                println("  Last novelty score  : $(mlp_st["last_novelty_score"])")
                println("  Last dir. quality   : $(mlp_st["last_directive_quality"])")
                # GRUG v9: Multi-output head scores — the brain now reads on four channels.
                println("  Last semantic score : $(mlp_st["last_semantic_score"])")
                println("  Last relevance score: $(mlp_st["last_relevance_score"])")
                println("  Last disambiguation : $(mlp_st["last_disambiguation"])")
                # GRUG v9: Architecture info for operator visibility.
                _arch = get(mlp_st, "architecture", Dict{String,Any}())
                if !isempty(_arch)
                    println("  Architecture        : dim=$(_arch["hidden_dim"]) heads=$(_arch["attention_heads"]) blocks=$(_arch["transformer_blocks"]) ffn=$(_arch["ffn_dim"]) out=$(_arch["output_heads"])")
                end
                println("  Right feedback      : $(mlp_st["right_feedback_count"])")
                println("  Wrong feedback      : $(mlp_st["wrong_feedback_count"])")
                println("  Rules (total/enabled): $(mlp_st["rules_total"]) / $(mlp_st["rules_enabled"])")
                println("  Jitter-eligible wt. : $(mlp_st["jitter_eligible_weights"])")
                println("  Jitter enabled      : $(mlp_st["jitter_enabled"])")
                println("  Novelty observations: $(mlp_st["novelty_observations"])")
                println("  Novelty hashes      : $(mlp_st["novelty_hashes_tracked"])")
                println("  Observer threshold  : $(mlp_st["observation_threshold"])")
                println("  Observer count      : $(mlp_st["selfobserver_observations"])")
                println("  Adjustments enabled : $(mlp_st["adjustments_enabled"] ? "YES" : "NO")")
                # GRUG v7.50: Hippocampal strain readout
                println("  Strain energy       : $(mlp_st["strain_energy"])")
                println("  Hippocampal warrant : $(mlp_st["hippocampal_warrant"] ? "ACTIVE" : "inactive")")
                println("╚══════════════════════════════════════════════════════╝\n")

            elseif !isnothing(m_mlpthreshold)
                # GRUG v7.24: /mlpThreshold <n> — set the observation threshold.
                # The MLP's adjustments stay zero until SelfObserver has at least
                # this many entries. Default is 5. Set to 0 to always enable.
                new_threshold = parse(Int, String(m_mlpthreshold.captures[1]))
                old_threshold = EphemeralMLP.get_observation_threshold()
                EphemeralMLP.set_observation_threshold!(new_threshold)
                println("🔧  /mlpThreshold: $old_threshold → $new_threshold")

            elseif !isnothing(m_mlpobserver)
                # GRUG v7.24: /mlpObserver — show the SelfObserver store stats
                # that gate the EphemeralMLP adjustments.
                obs_size = SelfObserver.store_size(_MLP_OBSERVER_STORE)
                obs_keys = SelfObserver.key_count(_MLP_OBSERVER_STORE)
                threshold = EphemeralMLP.get_observation_threshold()
                mlp_st2 = EphemeralMLP.get_mlp_status()
                adj_en = get(mlp_st2, "adjustments_enabled", false)
                println()
                println("╔══════════════════════════════════════════════════════════════╗")
                println("║         MLP SELF-OBSERVER STORE                            ║")
                println("╠══════════════════════════════════════════════════════════════╣")
                println("  Total observations  : $obs_size")
                println("  Distinct keys       : $obs_keys")
                println("  Observation threshold: $threshold")
                println("  Adjustments enabled : $(adj_en ? "YES" : "NO")")
                println("  Progress to gate    : $(min(obs_size, threshold))/$(threshold)$(obs_size >= threshold ? " ✓ GATE OPEN" : "")")
                println("╚══════════════════════════════════════════════════════════════╝")
                println()

            elseif !isnothing(m_mitosisstatus)
                # GRUG: /mitosisStatus — show mitosis mode status and recent growth events.
                println(MitosisMode.get_mitosis_status_summary())

            elseif !isnothing(m_growthstatus)
                # GRUG: /growthStatus — show growth automaton status and recent spawn events.
                println(TemporalGrowth.get_growth_status_summary())

            elseif !isnothing(m_autogrowstatus)
                # GRUG: /autoGrowStatus — show live conversation auto-learning status.
                # Evidence accumulator counts, recent growth log, co-occurrence map size.
                println(AutoGrowth.get_autogrowth_status_summary())

            elseif !isnothing(m_autolinkstatus)
                # GRUG: /autoLinkStatus — show evidence-based cross-lobe bridge status.
                # Link evidence accumulator counts, top candidates, recent link history.
                println(AutoLinker.get_autolink_status_summary())

            elseif !isnothing(m_explicit)
                cmd, id, mission_text = m_explicit.captures
                add_message_to_history!("User", String(mission_text), false)
                
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
                            # GRUG FIX (v7.42): When the grow packet pattern is image binary,
                            # we must tell grow_nodes_from_packet to flag it is_image_node=true,
                            # otherwise the base64 string is stored as a plain TEXT pattern with a
                            # 1-element signal (the SDF signal we just computed gets discarded).
                            # We inject is_image_node into the packet JSON, then after creation we
                            # overwrite the empty placeholder signal with the real SDF signal.
                            _grow_json_text = json_text
                            if is_img
                                _gp = try JSON.parse(json_text) catch; nothing end
                                if _gp !== nothing
                                    if haskey(_gp, "nodes") && isa(_gp["nodes"], AbstractVector)
                                        for _nd in _gp["nodes"]
                                            _is_dict_like(_nd) && (_nd["is_image_node"] = true)
                                        end
                                    elseif haskey(_gp, "pattern")
                                        _gp["is_image_node"] = true
                                    end
                                    _grow_json_text = JSON.json(_gp)
                                end
                            end

                            new_ids = grow_nodes_from_packet(_grow_json_text; target_lobe=target_lobe)

                            # GRUG FIX (v7.42): Apply the real SDF signal to freshly-created image
                            # nodes (create_node leaves an empty placeholder for image nodes).
                            if is_img && !isempty(img_sig)
                                lock(NODE_LOCK) do
                                    for nid in new_ids
                                        n = get(NODE_MAP, nid, nothing)
                                        if !isnothing(n) && n.is_image_node && isempty(n.signal)
                                            append!(n.signal, img_sig)
                                        end
                                    end
                                end
                            end

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
                # GRUG v8.0: Also show bridge map if any bridges exist
                br_summary = get_bridge_summary()
                if !contains(br_summary, "EMPTY")
                    println("\n$br_summary")
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
                mlp = EphemeralMLP.get_mlp_status()
                _mlp_t = get(mlp, "total_transforms", 0)
                _mlp_sig = get(mlp, "sigmoid_activations", 0)
                _mlp_relu = get(mlp, "relu_activations", 0)
                _mlp_act = get(mlp, "last_activation", "sigmoid")
                _mlp_nov = get(mlp, "last_novelty_score", 0.5)
                _mlp_qual = get(mlp, "last_directive_quality", 0.5)
                _mlp_re = get(mlp, "rules_enabled", 0)
                _mlp_rt = get(mlp, "rules_total", 0)
                _mlp_r = get(mlp, "right_feedback_count", 0)
                _mlp_w = get(mlp, "wrong_feedback_count", 0)
                println("║  EPHEMERAL MLP                                   ║")
                println("  Transforms      : $_mlp_t")
                println("  Sigmoid / ReLU  : $_mlp_sig / $_mlp_relu")
                println("  Last activation : $_mlp_act")
                println("  Novelty score   : $_mlp_nov")
                println("  Dir. quality    : $_mlp_qual")
                println("  Rules           : $_mlp_re/$_mlp_rt enabled")
                println("  Right / Wrong   : $_mlp_r / $_mlp_w")
                _mlp_obs = get(mlp, "selfobserver_observations", 0)
                _mlp_thresh = get(mlp, "observation_threshold", 5)
                _mlp_adj = get(mlp, "adjustments_enabled", false)
                println("  Obs. threshold  : $_mlp_thresh")
                println("  Observer count  : $_mlp_obs")
                println("  Adjustments     : $(_mlp_adj ? "ENABLED" : "GATED")")
                println("╚══════════════════════════════════════════════════╝")

                println("║  MITOSIS (lazy fuzzy conservative stochastic)   ║")
                _mito_log = MitosisMode.get_mitosis_log()
                _mito_growth = count(e -> !isempty(e.new_node_id), _mito_log)
                _mito_latched = count(e -> !isempty(e.latched_to), _mito_log)
                _mito_last = isempty(_mito_log) ? "none" : _mito_log[end].source
                println("  Nodes grown     : $_mito_growth")
                println("  Nodes latched   : $_mito_latched")
                println("  Last event      : $_mito_last")
                println("  Stochastic prob : $(MitosisMode.MITOSIS_PROBABILITY)")
                println("  Min pop gate    : $(MitosisMode.MIN_POPULATION_GATE)")
                println("  Max pop cap     : $(MitosisMode.MAX_POPULATION_CAP)")
                println("  Cooldown cycles : $(MitosisMode.MITOSIS_COOLDOWN_CYCLES)")
                println("  Min warrant     : $(MitosisMode.MIN_WARRANT_THRESHOLD)")
                println("╚══════════════════════════════════════════════════════════════╝")

                # GRUG: Show RelationalGovernance + InputLedger + ChatterResiduals status.
                # These are the organic attachment and input/residual-mining subsystems.
                println(RelationalGovernance.get_relational_gov_status_summary())
                println(InputLedger.get_input_ledger_status())
                println(ChatterResiduals.get_chatter_residuals_status())

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

            elseif !isnothing(m_addrelrelation)
                # GRUG v7.55: /addRelRelation <name> <alt1 alt2 alt3 ...>
                # Register a :relation-class sigil for dynamic relational triples.
                # The name becomes &name in triple relation slots; the alternatives
                # are the concrete verbs that the sigil expands to at match time.
                # Example: /addRelRelation causes causes produces creates generates
                #   Then: /answer :relate fire | &causes | heat
                #   → matches user triples with "causes", "produces", "creates", or "generates"
                rel_name = String(m_addrelrelation.captures[1])
                alts_raw = String(m_addrelrelation.captures[2])
                # GRUG: strip brackets if present ([causes produces] → causes produces)
                alts_clean = replace(replace(alts_raw, r"^\[" => ""), r"\]$" => "")
                alt_list = [lowercase(strip(w)) for w in split(alts_clean) if !isempty(strip(w))]
                if isempty(alt_list)
                    println("⚠️  /addRelRelation: no alternatives provided. Format: /addRelRelation <name> <alt1 alt2 ...>")
                elseif !occursin(SigilRegistry.SIGIL_NAME_REGEX, rel_name)
                    println("⚠️  /addRelRelation: name '$rel_name' is not a valid sigil name. Use letters, digits, dash, underscore.")
                else
                    # GRUG: IMMUNE GATE — sigil registry is stored structure!
                    if !immune_gate("/addRelRelation", rel_name * " " * join(alt_list, " "); is_critical=false)
                        println("⛔ /addRelRelation blocked by immune system.")
                    else
                        try
                            SigilRegistry.register_relation_sigil!(_ENGINE_SIGIL_TABLE;
                                name = rel_name,
                                expansion = alt_list,
                                provenance = "user-relation",
                                overwrite = true)  # allow overwrite so user can refine
                            println("🔗 Relation sigil '&$rel_name' registered: $(join(alt_list, " | "))")
                        catch e
                            println("⚠️  /addRelRelation failed: $e")
                        end
                    end
                end

            elseif !isnothing(m_addseedsyn)
                # GRUG v7.35: /addSeedSynonym <canonical> <syn1 syn2 syn3 ...>
                # Register a thesaurus seed synonym group at runtime.
                # canonical = root word, rest = space-separated synonym list.
                # Example: /addSeedSynonym jitter [shake tremor wobble fluctuation]
                # Brackets are optional — just spaces between words.
                canonical_word = String(m_addseedsyn.captures[1])
                syn_raw        = String(m_addseedsyn.captures[2])
                # GRUG: strip brackets if present ([shake tremor] → shake tremor)
                syn_clean = replace(replace(syn_raw, r"^\[" => ""), r"\]$" => "")
                syn_list  = split(syn_clean)
                if isempty(syn_list)
                    println("!!! FATAL: /addSeedSynonym needs at least one synonym word after canonical. !!!")
                else
                    # GRUG: IMMUNE GATE — seed map is stored structure!
                    if !immune_gate("/addSeedSynonym", canonical_word * " " * syn_clean; is_critical=false)
                        println("⛔ /addSeedSynonym blocked by immune system.")
                    else
                        n = Thesaurus.add_seed_synonym!(canonical_word, String.(syn_list))
                        println("🌱 Seed synonym group: '$(canonical_word)' + $(n) synonyms registered. Bidirectional mapping active.")
                    end
                end

            elseif !isnothing(m_addantimatch)
                # GRUG v7.49: /addAntiMatch <pattern> [NONJITTER]
                # Create an anti-match node that pattern-activates but drains confidence
                # from regular votes in the same lobe instead of casting its own vote.
                # Each activation drains a random tick; NONJITTER tag makes it a fixed constant.
                # Anti-match nodes never gain/lose strength and never compete for stages.
                # Example: /addAntiMatch offensive
                # Example: /addAntiMatch rude NONJITTER
                am_raw = String(strip(m_addantimatch.captures[1]))
                # GRUG: Parse optional NONJITTER suffix.
                has_nonjitter = false
                am_pattern = am_raw
                if occursin(r"\s+NONJITTER\s*$"i, am_raw)
                    has_nonjitter = true
                    am_pattern = replace(am_raw, r"\s+NONJITTER\s*$"i => "")
                end
                am_pattern = String(strip(am_pattern))
                if isempty(am_pattern)
                    println("!!! FATAL: /addAntiMatch needs a pattern string. Example: /addAntiMatch offensive [NONJITTER] !!!")
                else
                    # GRUG: IMMUNE GATE — anti-match nodes are stored structure!
                    if !immune_gate("/addAntiMatch", am_pattern; is_critical=false)
                        println("⛔ /addAntiMatch blocked by immune system.")
                    else
                        req_rels = has_nonjitter ? ["NONJITTER"] : String[]
                        am_data = Dict{String,Any}("required_relations" => req_rels)
                        # GRUG: Anti-match nodes need a dummy action_packet. They never
                        # actually fire an action (they're removed before vote casting),
                        # but the Node struct requires one. Use "say^1" as the no-op default.
                        nid = create_node(am_pattern, "ponder^1", am_data, String[]; is_antimatch_node=true)
                        nj_tag = has_nonjitter ? " [NONJITTER — fixed drain]" : " [jitter drain]"
                        lobe_tag = let l = Lobe.find_lobe_for_node(nid)
                            isnothing(l) ? " (no lobe)" : " (lobe: $l)"
                        end
                        println("🧫 Anti-match node created: id=$nid pattern='$am_pattern'$nj_tag$lobe_tag")
                    end
                end

            # GRUG v7.52: /answer [@lobe_id] [:mode] <content>
            # The hippocampal answer mechanism. When the system encounters input it
            # can't handle (empty cave / strain), it asks a question. The user answers.
            # The answer resolves the structural deficit and lowers strain.
            #
            # Modes let the user pick the RIGHT shape for their answer:
            #   :reason   — default. Single reason^1 node.
            #   :explain  — single explain^1 node. Good for teaching concepts.
            #   :define   — single define^1 node. Precise definitions.
            #   :alert    — single alert^1 node. Warnings/watchdogs.
            #   :comfort  — single comfort^1 node. Empathic answers.
            #   :math     — arithmetic-ready node. terse voice, noun_anchors.
            #   :multi    — pipe-delimited multi-node. "part1 | part2 | part3"
            #   :relate   — triple-seeded. "subject | relation | object"
            #   :proc     — procedural chain. "step1; step2; step3"
            #   :json     — raw JSON passthrough to grow_nodes_from_packet.
            #
            # All modes also DAMPEN STRAIN and CLEAR the pending ask.
            elseif !isnothing(m_answer)
                ans_lobe_raw = m_answer.captures[1]  # may be Nothing if no @lobe_id
                ans_mode_raw = m_answer.captures[2]  # may be Nothing if no :mode
                ans_content  = String(strip(m_answer.captures[3]))

                # GRUG: Resolve mode — default to :reason if not specified.
                ans_mode = if !isnothing(ans_mode_raw)
                    mode_candidate = lowercase(String(ans_mode_raw))
                    if mode_candidate ∉ _VALID_ANSWER_MODES
                        println("⚠  /answer: unknown mode ':$mode_candidate'. Valid modes: $(join(_VALID_ANSWER_MODES, ", ")). Falling back to :reason.")
                        "reason"
                    else
                        mode_candidate
                    end
                else
                    "reason"
                end

                if isempty(ans_content)
                    println("!!! FATAL: /answer needs content. Example: /answer @physics :explain energy is conserved !!!")
                else
                    # GRUG v7.52: Validate lobe if specified.
                    target_lobe_ans = if !isnothing(ans_lobe_raw)
                        lobe_candidate = String(ans_lobe_raw)
                        if !haskey(Lobe.LOBE_REGISTRY, lobe_candidate)
                            println("⚠  /answer: lobe '@$lobe_candidate' does not exist. Use /newLobe first, or omit @lobe_id. Answer NOT created.")
                            nothing  # signal: abort
                        elseif Lobe.lobe_is_full(lobe_candidate)
                            println("!!! LOBE FULL: Lobe '$lobe_candidate' has reached its node cap. Answer NOT created. !!!")
                            nothing  # signal: abort
                        else
                            lobe_candidate
                        end
                    else
                        nothing  # no lobe targeting
                    end
                    if target_lobe_ans !== nothing || isnothing(ans_lobe_raw)
                        # GRUG: IMMUNE GATE — answer nodes are stored structure!
                        if !immune_gate("/answer", ans_content; is_critical=false)
                            println("⛔ /answer blocked by immune system.")
                        else
                            # GRUG v7.52: Dampen strain — the user is resolving the deficit.
                            dampen_result = try
                                EphemeralMLP.dampen_strain!(0.7)
                            catch e
                                @warn "[MAIN] dampen_strain! failed (non-fatal): $e"
                                nothing
                            end

                            # GRUG v7.52: Clear the pending ask.
                            pending_ask_text = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
                                old = _HIPPOCAMPAL_PENDING_ASK[]
                                _HIPPOCAMPAL_PENDING_ASK[] = ""
                                old
                            end

                            strain_now = round(EphemeralMLP.get_strain_energy(); digits=3)
                            strain_msg = if dampen_result !== nothing
                                "strain $(round(dampen_result.old; digits=3)) → $(round(dampen_result.new; digits=3)) (dampened)"
                            else
                                "strain now $strain_now"
                            end
                            resolve_msg = !isempty(pending_ask_text) ? " | resolved: \"$pending_ask_text\"" : ""

                            # ==========================================================
                            # MODE DISPATCH
                            # ==========================================================

                            if ans_mode == "json"
                                # --- :json — raw JSON passthrough to grow_nodes_from_packet ---
                                try
                                    new_ids = grow_nodes_from_packet(ans_content; target_lobe=target_lobe_ans,
                                                                     default_system_prompt="Grug. I learned this from a question. I reason about what I was taught.")
                                    println("🧠 Answer [:json]: planted $(length(new_ids)) node(s) into lobe '$(isnothing(target_lobe_ans) ? "-" : target_lobe_ans)' [$(join(new_ids, ", "))] | $strain_msg$resolve_msg")
                                catch e
                                    println("!!! ERROR in /answer :json: $e !!!")
                                end

                            elseif ans_mode == "multi"
                                # --- :multi — pipe-delimited multi-node creation ---
                                parts = _parse_multi_parts(ans_content)
                                if isempty(parts)
                                    println("!!! FATAL: /answer :multi needs pipe-delimited parts. Example: /answer :multi part1 | part2 | part3 !!!")
                                else
                                    multi_ids = String[]
                                    for (action_pkt, part_text) in parts
                                        part_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text)
                                        # GRUG: Override action-specific voice if the part has a custom action
                                        action_name = split(action_pkt, '^')[1]
                                        if haskey(_ANSWER_MODE_CONFIG, action_name) && !isempty(_ANSWER_MODE_CONFIG[action_name])
                                            cfg = _ANSWER_MODE_CONFIG[action_name]
                                            part_data["system_prompt"] = cfg["prompt"]
                                            part_data["voice_register"] = cfg["voice"]
                                            part_data["frame_hints"] = cfg["frame"]
                                        end
                                        part_data["answer_mode"] = "multi"
                                        part_data["multi_part_action"] = action_pkt
                                        nid, lobe_tag = _create_answer_node(part_text, action_pkt, part_data, target_lobe_ans; skip_auto_latch=true)
                                        push!(multi_ids, nid)
                                    end
                                    # GRUG: Auto-group the multi-part nodes so they fire together.
                                    if length(multi_ids) > 1
                                        try
                                            first_id = multi_ids[1]
                                            # Register the first node as a group root
                                            if haskey(NODE_MAP, first_id)
                                                register_group!(NODE_MAP[first_id])
                                                for other_id in multi_ids[2:end]
                                                    if haskey(NODE_MAP, other_id)
                                                        grp = group_for(first_id)
                                                        if !isnothing(grp)
                                                            _dissolve_solo_group!(other_id)
                                                            add_to_group!(grp, other_id)
                                                        end
                                                    end
                                                end
                                            end
                                        catch e
                                            @warn "[MAIN] /answer :multi — auto-grouping failed (non-fatal): $e"
                                        end
                                    end
                                    println("🧠 Answer [:multi]: planted $(length(multi_ids)) node(s) [$(join(multi_ids, ", "))] | $strain_msg$resolve_msg")
                                end

                            elseif ans_mode == "relate"
                                # --- :relate — triple-seeded node ---
                                # Format: "subject | relation | object"
                                # Relation can be a literal verb OR a &sigilName for dynamic relational.
                                # Dynamic example: /answer :relate fire | &causes | heat
                                #   → matches "causes", "produces", "creates", etc. per sigil expansion.
                                relate_parts = [strip(String(p)) for p in split(ans_content, "|")]
                                if length(relate_parts) < 3
                                    println("!!! FATAL: /answer :relate needs 'subject | relation | object'. Example: /answer :relate fire | burns | wood !!!")
                                else
                                    subj = relate_parts[1]
                                    rel_raw = relate_parts[2]
                                    obj  = relate_parts[3]

                                    # GRUG v7.55: Check if relation is a dynamic relational sigil.
                                    # If it starts with &, it must be a registered :relation-class sigil.
                                    is_dynamic = !isempty(rel_raw) && rel_raw[1] == '&'
                                    if is_dynamic
                                        sigil_name = rel_raw[2:end]  # strip & prefix
                                        if !SigilRegistry.is_relation_sigil(_ENGINE_SIGIL_TABLE, sigil_name)
                                            println("!!! FATAL: /answer :relate relation sigil &$sigil_name is not registered as a :relation-class sigil. Use /addRelRelation first. !!!")
                                            continue
                                        end
                                        # Keep the &name form for the triple's relation field.
                                        # evaluate_relational_dialectics will expand it at match time.
                                        rel_for_triple = rel_raw  # "&causes" etc.
                                        rel_for_display = SigilRegistry.expand_relation_sigil(_ENGINE_SIGIL_TABLE, sigil_name)
                                    else
                                        rel_for_triple = lowercase(rel_raw)
                                        rel_for_display = [lowercase(rel_raw)]
                                    end

                                    # GRUG: Pattern is the subject, but node carries relational metadata.
                                    relate_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text)
                                    relate_data["answer_mode"] = "relate"
                                    relate_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
                                    relate_data["required_relations"] = [rel_for_triple]
                                    # GRUG: Also store the full triple for AIML reference.
                                    relate_data["seeded_triple"] = Dict(
                                        "subject"   => lowercase(subj),
                                        "relation"  => rel_for_triple,
                                        "object"    => lowercase(obj),
                                    )
                                    relate_data["system_prompt"] = "Grug. I learned this from a question. I know that $(lowercase(subj)) $(rel_for_triple) $(lowercase(obj)). I reason about this relationship."
                                    relate_data["voice_register"] = "plain"
                                    relate_data["frame_hints"] = ["plain", "exploratory"]
                                    # GRUG v7.53: Fan-out for relate — primary + shadow nodes from subject pattern.
                                    nid, shadow_ids, lobe_tag = _plant_answer_cluster(subj, "reason^1", relate_data, target_lobe_ans, "relate")
                                    shadow_msg = !isempty(shadow_ids) ? " +$(length(shadow_ids)) shadows [$(join(shadow_ids, ", "))]" : ""
                                    if is_dynamic
                                        println("🧠 Answer [:relate]: id=$nid triple='$(lowercase(subj)) → $(rel_for_triple) → $(lowercase(obj))' (dynamic: $(join(rel_for_display, " | ")))$lobe_tag$shadow_msg | $strain_msg$resolve_msg")
                                    else
                                        println("🧠 Answer [:relate]: id=$nid triple='$(lowercase(subj)) → $(rel_for_triple) → $(lowercase(obj))'$lobe_tag$shadow_msg | $strain_msg$resolve_msg")
                                    end
                                end

                            elseif ans_mode == "time"
                                # --- :time — time node (auto &temporal relational) ---
                                # GRUG v7.56: A time node is just a regular node with &temporal
                                # baked in. The user supplies subject | object (the relation
                                # is automatically &temporal). Time nodes cluster together
                                # because they share the &temporal gate and carry a time_node
                                # flag in their metadata. When a user asks "what now?" or
                                # uses any temporal verb, the &temporal sigil expansion
                                # (before, after, during, since, until, now, then, precedes,
                                # follows, while, when) means the required_relations gate
                                # is satisfied structurally — the engine knows this is a
                                # time-coherent task before any pattern matching.
                                # GRUG v8.1: Optional 3rd field = orientation (past/present/future).
                                # If provided, the time node carries time_orientation in json_data
                                # so the save/load pipeline can reconnect it to &now/&before/&next
                                # sigils on reload. Without orientation, the node is a generic
                                # temporal node (no specific time sigil association).
                                # Format: "/answer :time subject | object [ | orientation]"
                                # Example: "/answer :time fire | warm | past"
                                # Example: "/answer :time now | next_step | present"
                                time_parts = [strip(String(s)) for s in split(ans_content, "|")]
                                time_parts = filter(!isempty, time_parts)
                                if length(time_parts) < 2
                                    println("!!! FATAL: /answer :time needs 'subject | object'. Example: /answer :time present | future !!!")
                                else
                                    subj = time_parts[1]
                                    obj  = time_parts[2]
                                    # GRUG v8.1: Optional 3rd part = orientation (past/present/future).
                                    # If provided, the node is associated with the corresponding
                                    # time sigil (&before=past, &now=present, &next=future).
                                    time_orient_raw = length(time_parts) >= 3 ? strip(time_parts[3]) : ""
                                    time_orient = ""
                                    if !isempty(time_orient_raw)
                                        tol = lowercase(time_orient_raw)
                                        if tol in ("past", "present", "future")
                                            time_orient = tol
                                        else
                                            println("⚠️  /answer :time orientation '$time_orient_raw' not recognized (use past/present/future). Node created without orientation.")
                                        end
                                    end
                                    # GRUG: Always use &temporal — it's the whole point of :time mode.
                                    rel_for_triple = "&temporal"
                                    rel_for_display = SigilRegistry.expand_relation_sigil(_ENGINE_SIGIL_TABLE, "temporal")

                                    time_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text)
                                    time_data["answer_mode"] = "time"
                                    time_data["time_node"] = true
                                    # GRUG v8.1: Store orientation in json_data so it survives
                                    # save/load. When this node is loaded, the engine can
                                    # reconnect it to the right time sigil (&before/&now/&next).
                                    if !isempty(time_orient)
                                        time_data["time_orientation"] = time_orient
                                        # GRUG v8.1: Also store the sigil name that this
                                        # orientation maps to, so reload can directly bind.
                                        time_orient_to_sigil = Dict("past" => "before", "present" => "now", "future" => "next")
                                        time_data["time_sigil"] = time_orient_to_sigil[time_orient]
                                    end
                                    time_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
                                    time_data["required_relations"] = [rel_for_triple]
                                    time_data["seeded_triple"] = Dict(
                                        "subject"   => lowercase(subj),
                                        "relation"  => rel_for_triple,
                                        "object"    => lowercase(obj),
                                    )
                                    time_data["system_prompt"] = "Grug. I learned this from a question about time. I know that $(lowercase(subj)) $(rel_for_triple) $(lowercase(obj)). I reason about temporal relationships.$(isempty(time_orient) ? "" : " My temporal orientation is $(time_orient) — I reason about the $(time_orient == "past" ? "what has already happened" : time_orient == "present" ? "what is happening right now" : "what may come next").")"
                                    time_data["voice_register"] = "plain"
                                    time_data["frame_hints"] = ["plain", "exploratory"]
                                    # GRUG v7.53: Fan-out for time — primary + shadow nodes.
                                    nid, shadow_ids, lobe_tag = _plant_answer_cluster(subj, "reason^1", time_data, target_lobe_ans, "time")
                                    shadow_msg = !isempty(shadow_ids) ? " +$(length(shadow_ids)) shadows [$(join(shadow_ids, ", "))]" : ""
                                    orient_msg = !isempty(time_orient) ? " orient=$time_orient" : ""
                                    println("⏳ Answer [:time]: id=$nid triple='$(lowercase(subj)) → $(rel_for_triple) → $(lowercase(obj))'$orient_msg (temporal: $(join(rel_for_display[1:min(3,length(rel_for_display))], " | "))…)$lobe_tag$shadow_msg | $strain_msg$resolve_msg")
                                end

                            elseif ans_mode == "proc"
                                # --- :proc — procedural chain (sequential steps) ---
                                # Format: "step1; step2; step3"
                                proc_steps = [strip(String(s)) for s in split(ans_content, ";")]
                                proc_steps = filter(!isempty, proc_steps)
                                if length(proc_steps) < 2
                                    println("!!! FATAL: /answer :proc needs at least 2 semicolon-delimited steps. Example: /answer :proc gather wood; build fire; cook food !!!")
                                else
                                    proc_ids = String[]
                                    for (i, step_text) in enumerate(proc_steps)
                                        step_data = _base_answer_data("reason"; pending_ask_text=pending_ask_text)
                                        step_data["answer_mode"] = "proc"
                                        step_data["proc_step"] = i
                                        step_data["proc_total"] = length(proc_steps)
                                        step_data["system_prompt"] = "Grug. I learned this procedure from a question. Step $i of $(length(proc_steps)). I explain what to do."
                                        step_data["voice_register"] = "plain"
                                        step_data["frame_hints"] = ["imperative", "plain"]
                                        nid, lobe_tag = _create_answer_node(step_text, "reason^1", step_data, target_lobe_ans; skip_auto_latch=true)
                                        push!(proc_ids, nid)
                                    end
                                    # GRUG: Link steps into a drop_table chain so they co-activate.
                                    # step[1].drop_table = [step[2]], step[2].drop_table = [step[3]], etc.
                                    for i in 1:(length(proc_ids)-1)
                                        current_id = proc_ids[i]
                                        next_id    = proc_ids[i+1]
                                        if haskey(NODE_MAP, current_id)
                                            push!(NODE_MAP[current_id].drop_table, next_id)
                                        end
                                    end
                                    # GRUG: Also auto-group the procedural nodes.
                                    if length(proc_ids) > 1
                                        try
                                            first_id = proc_ids[1]
                                            if haskey(NODE_MAP, first_id)
                                                register_group!(NODE_MAP[first_id])
                                                for other_id in proc_ids[2:end]
                                                    if haskey(NODE_MAP, other_id)
                                                        grp = group_for(first_id)
                                                        if !isnothing(grp)
                                                            _dissolve_solo_group!(other_id)
                                                            add_to_group!(grp, other_id)
                                                        end
                                                    end
                                                end
                                            end
                                        catch e
                                            @warn "[MAIN] /answer :proc — auto-grouping failed (non-fatal): $e"
                                        end
                                    end
                                    println("🧠 Answer [:proc]: planted $(length(proc_ids)) step(s) [$(join(proc_ids, " → "))] | $strain_msg$resolve_msg")
                                end

                            elseif ans_mode == "math"
                                # --- :math — arithmetic-ready node ---
                                math_data = _base_answer_data("math"; pending_ask_text=pending_ask_text)
                                # GRUG: Extract noun_anchors from math content — numbers, operators, variables.
                                math_tokens = split(lowercase(ans_content))
                                math_anchors = String[]
                                for tok in math_tokens
                                    # Keep numbers, operator-like tokens, and short identifiers
                                    if occursin(r"^[\d\.\+\-\*\/\=\^\<\>%]+$", tok) || (length(tok) <= 3 && occursin(r"^[a-z]$", tok))
                                        push!(math_anchors, tok)
                                    end
                                end
                                if !isempty(math_anchors)
                                    math_data["noun_anchors"] = math_anchors
                                end
                                math_data["answer_mode"] = "math"
                                math_data["is_math_node"] = true
                                # GRUG v7.53: Fan-out for math — primary + shadows.
                                nid, shadow_ids, lobe_tag = _plant_answer_cluster(ans_content, "reason^1", math_data, target_lobe_ans, "math")
                                anchor_msg = !isempty(math_anchors) ? " anchors=$(math_anchors)" : ""
                                shadow_msg = !isempty(shadow_ids) ? " +$(length(shadow_ids)) shadows [$(join(shadow_ids, ", "))]" : ""
                                println("🧠 Answer [:math]: id=$nid pattern='$(lowercase(ans_content))'$lobe_tag$anchor_msg$shadow_msg | $strain_msg$resolve_msg")

                            else
                                # --- :reason, :explain, :define, :alert, :comfort — typed cluster ---
                                cfg = _ANSWER_MODE_CONFIG[ans_mode]
                                action_pkt = cfg["action"]
                                typed_data = _base_answer_data(ans_mode; pending_ask_text=pending_ask_text)
                                # GRUG v7.53: Fan-out — primary + shadow nodes for broader activation.
                                nid, shadow_ids, lobe_tag = _plant_answer_cluster(ans_content, action_pkt, typed_data, target_lobe_ans, ans_mode)
                                shadow_msg = !isempty(shadow_ids) ? " +$(length(shadow_ids)) shadows [$(join(shadow_ids, ", "))]" : ""
                                println("🧠 Answer [:$ans_mode]: id=$nid pattern='$(lowercase(ans_content))'$lobe_tag$shadow_msg | $strain_msg$resolve_msg")
                            end
                        end
                    end
                end

            # GRUG v7.50: /antiAnswer <text> — user provides anti-answer for strain-causing input.
            # When the system sees something that causes strain and the user knows it's
            # WRONG or should be SUPPRESSED, the anti-answer creates an anti-match node.
            # This drains confidence from matching votes, suppressing the strain-causing
            # pattern. The anti-answer is the structural negation — "this is not valid input."
            #
            # GRUG v7.51: Also DAMPENS STRAIN and CLEARS the pending ask.
            # Same as /answer — the user is resolving the strain event.
            elseif !isnothing(m_antianswer)
                # GRUG v7.52: /antiAnswer [@lobe_id] [:mode] <text>
                # Optional @lobe_id targets the anti-answer to a specific lobe.
                # Optional :mode selects answer shape (:alert, :multi, :json).
                #   /antiAnswer @moderation :alert no slurs allowed
                #   /antiAnswer offensive content   (no lobe, no mode)
                anti_lobe_raw = m_antianswer.captures[1]  # may be Nothing if no @lobe_id
                anti_mode_raw = m_antianswer.captures[2]  # may be Nothing if no :mode
                anti_raw      = String(strip(m_antianswer.captures[3]))
                # GRUG v7.52: Resolve mode — antiAnswer supports :alert, :multi, :json.
                anti_mode = if !isnothing(anti_mode_raw)
                    mode_candidate = lowercase(String(anti_mode_raw))
                    if mode_candidate ∉ ["alert", "multi", "json"]
                        println("⚠  /antiAnswer: unknown mode ':$mode_candidate'. Valid modes: alert, multi, json. Falling back to default.")
                        "alert"
                    else
                        mode_candidate
                    end
                else
                    "alert"  # default for anti-answer — terse suppression
                end

                if isempty(anti_raw)
                    println("!!! FATAL: /antiAnswer needs text. Example: /antiAnswer @moderation :alert no slurs, or /antiAnswer :multi slur1 | slur2 !!!")
                else
                    # GRUG v7.51: Validate lobe if specified.
                    target_lobe_anti = if !isnothing(anti_lobe_raw)
                        lobe_candidate = String(anti_lobe_raw)
                        if !haskey(Lobe.LOBE_REGISTRY, lobe_candidate)
                            println("⚠  /antiAnswer: lobe '@$lobe_candidate' does not exist. Use /newLobe first, or omit @lobe_id. Anti-answer NOT created.")
                            nothing  # signal: abort
                        elseif Lobe.lobe_is_full(lobe_candidate)
                            println("!!! LOBE FULL: Lobe '$lobe_candidate' has reached its node cap. Anti-answer NOT created. Use /newLobe to add a new lobe. !!!")
                            nothing  # signal: abort
                        else
                            lobe_candidate
                        end
                    else
                        nothing  # no lobe targeting
                    end
                    if target_lobe_anti !== nothing || isnothing(anti_lobe_raw)
                        # Either a valid lobe was found, or no lobe was specified.
                        # GRUG: IMMUNE GATE — anti-answer nodes are stored structure!
                        if !immune_gate("/antiAnswer", anti_raw; is_critical=false)
                            println("⛔ /antiAnswer blocked by immune system.")
                        else
                            # GRUG v7.51: Dampen strain — the user is resolving the deficit.
                            dampen_result = try
                                EphemeralMLP.dampen_strain!(0.7)  # 70% reduction — strong resolution
                            catch e
                                @warn "[MAIN] dampen_strain! failed (non-fatal): $e"
                                nothing
                            end

                            # GRUG v7.51: Clear the pending ask — question has been anti-answered.
                            pending_ask_text = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
                                old = _HIPPOCAMPAL_PENDING_ASK[]
                                _HIPPOCAMPAL_PENDING_ASK[] = ""
                                old
                            end

                            # ==========================================================
                            # ANTI-ANSWER MODE DISPATCH (GRUG v7.52)
                            # ==========================================================
                            # Anti-answer modes: :alert (default), :multi, :json
                            # These create anti-match nodes that drain confidence from
                            # matching votes, suppressing the strain-causing pattern.

                            strain_now = round(EphemeralMLP.get_strain_energy(); digits=3)
                            strain_msg = if dampen_result !== nothing
                                "strain $(round(dampen_result.old; digits=3)) → $(round(dampen_result.new; digits=3)) (dampened)"
                            else
                                "strain now $strain_now"
                            end
                            resolve_msg = !isempty(pending_ask_text) ? " | resolved: \"$pending_ask_text\"" : ""

                            if anti_mode == "json"
                                # --- :json — raw JSON passthrough for anti-match nodes ---
                                try
                                    # GRUG: Force all nodes as anti-match via is_antimatch_node in packet.
                                    # We inject hippocampal metadata into each node's json_data.
                                    json_with_meta = replace(anti_raw, r"""("is_antimatch_node"\s*:\s*)false""" => s"\1true")
                                    # If the JSON doesn't have is_antimatch_node at all, inject it.
                                    if !occursin("is_antimatch_node", json_with_meta)
                                        json_with_meta = replace(json_with_meta, r"(\})\s*$" =>
                                            s", \"is_antimatch_node\": true}")
                                    end
                                    new_ids = grow_nodes_from_packet(json_with_meta; target_lobe=target_lobe_anti,
                                                                     default_system_prompt="Grug. I suppress what I was told to suppress. I do not reason about this.")
                                    println("🧠 Anti-answer [:json]: planted $(length(new_ids)) anti-match node(s) [$(join(new_ids, ", "))] | $strain_msg$resolve_msg")
                                catch e
                                    println("!!! ERROR in /antiAnswer :json: $e !!!")
                                end

                            elseif anti_mode == "multi"
                                # --- :multi — pipe-delimited multi anti-match nodes ---
                                parts = _parse_multi_parts(anti_raw)
                                if isempty(parts)
                                    println("!!! FATAL: /antiAnswer :multi needs pipe-delimited parts. Example: /antiAnswer :multi slur1 | slur2 !!!")
                                else
                                    anti_ids = String[]
                                    for (action_pkt, part_text) in parts
                                        part_data = _base_answer_data("alert"; pending_ask_text=pending_ask_text, is_anti=true)
                                        part_data["answer_mode"] = "multi_anti"
                                        nid, lobe_tag = _create_answer_node(part_text, action_pkt, part_data, target_lobe_anti; is_antimatch=true)
                                        push!(anti_ids, nid)
                                    end
                                    # GRUG: Auto-group the anti-match nodes.
                                    if length(anti_ids) > 1
                                        try
                                            first_id = anti_ids[1]
                                            if haskey(NODE_MAP, first_id)
                                                register_group!(NODE_MAP[first_id])
                                                for other_id in anti_ids[2:end]
                                                    if haskey(NODE_MAP, other_id)
                                                        grp = group_for(first_id)
                                                        if !isnothing(grp)
                                                            _dissolve_solo_group!(other_id)
                                                            add_to_group!(grp, other_id)
                                                        end
                                                    end
                                                end
                                            end
                                        catch e
                                            @warn "[MAIN] /antiAnswer :multi — auto-grouping failed (non-fatal): $e"
                                        end
                                    end
                                    println("🧠 Anti-answer [:multi]: planted $(length(anti_ids)) anti-match node(s) [$(join(anti_ids, ", "))] | $strain_msg$resolve_msg")
                                end

                            else
                                # --- :alert (default) — single anti-match node ---
                                anti_data = _base_answer_data("alert"; pending_ask_text=pending_ask_text, is_anti=true)
                                anti_id, lobe_tag = _create_answer_node(anti_raw, "ponder^1", anti_data, target_lobe_anti; is_antimatch=true)
                                println("🧠 Anti-answer [:alert]: id=$anti_id pattern='$(lowercase(strip(anti_raw)))' [confidence drain]$lobe_tag | $strain_msg$resolve_msg")
                            end
                        end
                    end
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

            elseif !isnothing(m_namelobe)
                # GRUG: /nameLobe <lobe_id> <name> — give a lobe a human-readable name.
                # The growth automaton uses lobe names to decide where to spawn.
                # Name = identity for the automaton. Groups of ~8 vote+pattern related
                # clusters bind by name, and the automaton spawns in one lobe at a time.
                # Example: /nameLobe MathLobe mathematics
                name_lobe_id   = String(m_namelobe.captures[1])
                name_lobe_name = String(strip(m_namelobe.captures[2]))
                if !haskey(Lobe.LOBE_REGISTRY, name_lobe_id)
                    println("\u26a0  /nameLobe: lobe '$name_lobe_id' does not exist. Use /newLobe first.")
                elseif isempty(name_lobe_name)
                    println("\u26a0  /nameLobe: name cannot be empty.")
                else
                    Lobe.set_lobe_name!(name_lobe_id, name_lobe_name)
                    println("\U0001f3f7\ufe0f  Lobe '$name_lobe_id' named '$name_lobe_name'. Automaton can now spawn here by name.")
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
                # JSON file (.json or .gz). Every node, lobe, rule, message, verb,
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
                # GRUG v8.0: /nodeBridge <lobe_id> <node_a> <node_b> [seam_tokens...]
                # (also accepts /nodeAttach for backward compat)
                # Cascade bridge system: bridge two nodes bidirectionally with seam tokens.
                # The leading <lobe_id> scopes node_a; node_b can be in ANY lobe (cross-lobe OK!).
                # Seam tokens are optional — if omitted, populated at fire time from scanner's
                # unmatched tail (match-boundary handoff).
                # Parsing: lobe_id is captures[2] (captures[1] is Bridge|Attach), captures[3] is the rest.
                #
                # Supported formats:
                #   /nodeBridge greeting node_0 node_1 hello world
                #   /nodeBridge greeting node_0 node_1 "seam tokens here"
                #   /nodeBridge greeting node_0 node_1     (no seam, dynamic at fire time)
                #   /nodeAttach greeting node_0 node_1 hello world  (backward compat)
                #
                lobe_id  = String(strip(m_nodeattach.captures[2]))
                raw_args = String(strip(m_nodeattach.captures[3]))
                # GRUG: IMMUNE GATE — node bridges are stored structure!
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

                if length(tokens) < 2
                    error("!!! FATAL: /nodeAttach needs at least: <lobe_id> <node_a> <node_b>. Got $(length(tokens)) token(s) after lobe_id! !!!")
                end

                node_a = tokens[1]
                node_b = tokens[2]
                # GRUG v8.0: Seam tokens are optional. Everything after node_a and node_b.
                seam_tokens = length(tokens) >= 3 ? tokens[3:end] : String[]

                # GRUG: Validate node_a lives in the named lobe
                _assert_node_in_lobe(lobe_id, node_a, "/nodeAttach")
                # GRUG v8.0: node_b can be in ANY lobe — cross-lobe bridges work now!
                # But we still validate it exists.
                lock(NODE_LOCK) do
                    if !haskey(NODE_MAP, node_b)
                        error("!!! FATAL: /nodeAttach node_b '$node_b' does not exist on the map! !!!")
                    end
                end

                result = bridge_nodes!(node_a, node_b; seam_tokens=seam_tokens)

                println("🌉 /nodeAttach (bridge) complete:")
                println("   $result")
                add_message_to_history!("System", "/nodeAttach: $result", false)
                end  # GRUG: End immune_gate else block for /nodeAttach

            elseif !isnothing(m_nodedetach)
                # GRUG v8.0: /nodeUnbridge <lobe_id> <node_a> <node_b>
                # (also accepts /nodeDetach for backward compat)
                # Remove a bidirectional bridge between two nodes.
                # Both sides of the bridge are removed.
                lobe_id   = String(strip(m_nodedetach.captures[2]))
                node_a = String(strip(m_nodedetach.captures[3]))
                node_b = String(strip(m_nodedetach.captures[4]))
                _assert_node_in_lobe(lobe_id, node_a, "/nodeDetach")
                result = unbridge_nodes!(node_a, node_b)
                println("🔓 $result")
                add_message_to_history!("System", "/nodeDetach: $result", false)

            elseif !isnothing(m_imgnodeattach)
                # GRUG: /imgnodeAttach <lobe_id> <target_id> <attach_id> <image_data_b64> [<width> <height>]
                # Same as /nodeAttach but for image nodes. The leading <lobe_id> scopes
                # both target and attach_id; cross-lobe image attachments are rejected.
                # Image binary is converted to nonlinear SDF at attach time (JIT GPU accel).
                # The attach_id MUST be an image node.
                #
                # Supported formats:
                #   /imgnodeAttach vision target_0 img_node_1 "data:image/png;base64,iVBOR..." 64 64
                #   /imgnodeAttach vision target_0 img_node_1 "data:image/png;base64,iVBOR..."
                #   (if width/height omitted, defaults to 8x8 — user should specify)
                #
                lobe_id  = String(strip(m_imgnodeattach.captures[1]))
                raw_args = String(strip(m_imgnodeattach.captures[2]))
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
                    error("!!! FATAL: /imgnodeAttach needs at least: <lobe_id> <target_id> <attach_id> <image_data>. Got $(length(tokens)) token(s) after lobe_id! !!!")
                end

                target_id = tokens[1]
                attach_id = tokens[2]
                image_input = tokens[3]

                # GRUG: Validate both nodes live in the named lobe BEFORE decoding the image.
                # Fail fast — image decode is expensive, no point doing it on a bad lobe arg.
                _assert_node_in_lobe(lobe_id, target_id, "/imgnodeAttach")
                _assert_node_in_lobe(lobe_id, attach_id, "/imgnodeAttach")

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
                # GRUG: /imgnodeDetach <lobe_id> <target_id> <attach_id>
                # Same as /nodeDetach — reuse unbridge_nodes! since CascadeBridge is universal.
                lobe_id   = String(strip(m_imgnodedetach.captures[1]))
                target_id = String(strip(m_imgnodedetach.captures[2]))
                attach_id = String(strip(m_imgnodedetach.captures[3]))
                _assert_node_in_lobe(lobe_id, target_id, "/imgnodeDetach")
                _assert_node_in_lobe(lobe_id, attach_id, "/imgnodeDetach")
                result = detach_node!(target_id, attach_id)
                println("🖼️🔓 $result")
                add_message_to_history!("System", "/imgnodeDetach: $result", false)

            elseif !isnothing(m_attachments)
                # GRUG v8.0: /attachments or /bridges — show all current node bridges (bidirectional)
                summary = get_bridge_summary()
                println(summary)

            elseif !isnothing(m_crystalize)
                # GRUG v8.0: /crystalize <lobe_id> <node_a> <node_b> — mark bridge as user-sticky
                # Crystalized bridges bypass the strength-biased fire coinflip and
                # are NOT auto-revoked when strength drops. Origin = :user.
                # Both sides of the bridge are crystalized bidirectionally.
                # node_a must be in the named lobe; node_b can be in ANY lobe (cross-lobe OK).
                lobe_id = String(strip(m_crystalize.captures[1]))
                node_a  = String(strip(m_crystalize.captures[2]))
                node_b  = String(strip(m_crystalize.captures[3]))
                _assert_node_in_lobe(lobe_id, node_a, "/crystalize")
                _assert_node_exists(node_b, "/crystalize")  # v8.0: cross-lobe OK
                result = crystalize_bridge!(node_a, node_b; origin=:user)
                println("💎 $result")
                add_message_to_history!("System", "/crystalize: $result", false)

            elseif !isnothing(m_decrystalize)
                # GRUG v8.0: /decrystalize <lobe_id> <node_a> <node_b> — remove sticky flag
                # Force=true clears even :user origin. Both sides decrystalized bidirectionally.
                # node_a must be in the named lobe; node_b can be in ANY lobe (cross-lobe OK).
                lobe_id = String(strip(m_decrystalize.captures[1]))
                node_a  = String(strip(m_decrystalize.captures[2]))
                node_b  = String(strip(m_decrystalize.captures[3]))
                _assert_node_in_lobe(lobe_id, node_a, "/decrystalize")
                _assert_node_exists(node_b, "/decrystalize")  # v8.0: cross-lobe OK
                result = decrystalize_bridge!(node_a, node_b; force=true)
                println("🔓 $result")
                add_message_to_history!("System", "/decrystalize: $result", false)

            # ======================================================================
            # DECOMPOSER CONFIG COMMANDS (v7.28)
            # GRUG: These let the operator view and edit the decomposer config at
            # runtime. Every mutation is immediately applied to _RUNTIME_CONFIG.
            # On next /saveSpecimen, the current config is serialized into the
            # specimen. NO SILENT FAILURES — every error is caught and hard-warned.
            # ======================================================================
            elseif !isnothing(m_decomp_status)
                # /decomposer OR /decomposer status — show full config
                try
                    println(InputDecomposer.config_status_string())
                catch e
                    println("❌ /decomposer status FAILED: $e")
                    @warn "[CLI] /decomposer status error: $e"
                end

            elseif !isnothing(m_decomp_addconj)
                # /decomposer addConjunction <word>
                word = String(m_decomp_addconj.captures[1])
                try
                    msg = InputDecomposer.add_split_conjunction!(word)
                    println(msg)
                    add_message_to_history!("System", "/decomposer addConjunction: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer addConjunction: $(e.msg)")
                    else
                        println("❌ /decomposer addConjunction FAILED: $e")
                        @warn "[CLI] /decomposer addConjunction error: $e"
                    end
                end

            elseif !isnothing(m_decomp_remconj)
                # /decomposer removeConjunction <word>
                word = String(m_decomp_remconj.captures[1])
                try
                    msg = InputDecomposer.remove_split_conjunction!(word)
                    println(msg)
                    add_message_to_history!("System", "/decomposer removeConjunction: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer removeConjunction: $(e.msg)")
                    else
                        println("❌ /decomposer removeConjunction FAILED: $e")
                        @warn "[CLI] /decomposer removeConjunction error: $e"
                    end
                end

            elseif !isnothing(m_decomp_addcomp)
                # /decomposer addCompound <leader> <follower>
                leader   = String(m_decomp_addcomp.captures[1])
                follower = String(m_decomp_addcomp.captures[2])
                try
                    msg = InputDecomposer.add_compound_pair!(leader, follower)
                    println(msg)
                    add_message_to_history!("System", "/decomposer addCompound: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer addCompound: $(e.msg)")
                    else
                        println("❌ /decomposer addCompound FAILED: $e")
                        @warn "[CLI] /decomposer addCompound error: $e"
                    end
                end

            elseif !isnothing(m_decomp_remcomp)
                # /decomposer removeCompound <leader> <follower>
                leader   = String(m_decomp_remcomp.captures[1])
                follower = String(m_decomp_remcomp.captures[2])
                try
                    msg = InputDecomposer.remove_compound_pair!(leader, follower)
                    println(msg)
                    add_message_to_history!("System", "/decomposer removeCompound: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer removeCompound: $(e.msg)")
                    else
                        println("❌ /decomposer removeCompound FAILED: $e")
                        @warn "[CLI] /decomposer removeCompound error: $e"
                    end
                end

            elseif !isnothing(m_decomp_addques)
                # /decomposer addQuestion <word>
                word = String(m_decomp_addques.captures[1])
                try
                    msg = InputDecomposer.add_question_marker!(word)
                    println(msg)
                    add_message_to_history!("System", "/decomposer addQuestion: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer addQuestion: $(e.msg)")
                    else
                        println("❌ /decomposer addQuestion FAILED: $e")
                        @warn "[CLI] /decomposer addQuestion error: $e"
                    end
                end

            elseif !isnothing(m_decomp_remques)
                # /decomposer removeQuestion <word>
                word = String(m_decomp_remques.captures[1])
                try
                    msg = InputDecomposer.remove_question_marker!(word)
                    println(msg)
                    add_message_to_history!("System", "/decomposer removeQuestion: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer removeQuestion: $(e.msg)")
                    else
                        println("❌ /decomposer removeQuestion FAILED: $e")
                        @warn "[CLI] /decomposer removeQuestion error: $e"
                    end
                end

            elseif !isnothing(m_decomp_addcmd)
                # /decomposer addCommand <stem> [form1 form2 ...]
                # GRUG: If conjugated forms are provided, they become the
                # conjugation rule for this stem. If not, just the bare stem.
                stem = String(m_decomp_addcmd.captures[1])
                forms_str = m_decomp_addcmd.captures[2]
                forms = if forms_str === nothing
                    String[]
                else
                    String.(strip.(split(String(forms_str))))
                end
                try
                    msg = InputDecomposer.add_command_marker!(stem, forms)
                    println(msg)
                    add_message_to_history!("System", "/decomposer addCommand: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer addCommand: $(e.msg)")
                    else
                        println("❌ /decomposer addCommand FAILED: $e")
                        @warn "[CLI] /decomposer addCommand error: $e"
                    end
                end

            elseif !isnothing(m_decomp_remcmd)
                # /decomposer removeCommand <stem>
                stem = String(m_decomp_remcmd.captures[1])
                try
                    msg = InputDecomposer.remove_command_marker!(stem)
                    println(msg)
                    add_message_to_history!("System", "/decomposer removeCommand: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer removeCommand: $(e.msg)")
                    else
                        println("❌ /decomposer removeCommand FAILED: $e")
                        @warn "[CLI] /decomposer removeCommand error: $e"
                    end
                end

            elseif !isnothing(m_decomp_addconjg)
                # /decomposer addConjugation <stem> <form1> [form2 ...]
                # GRUG: Sets the conjugation rule for a stem that's ALREADY
                # in command_markers. Use /decomposer addCommand first.
                stem = String(m_decomp_addconjg.captures[1])
                forms = String.(strip.(split(String(m_decomp_addconjg.captures[2]))))
                if isempty(forms)
                    println("❌ /decomposer addConjugation: must provide at least one conjugated form")
                else
                    try
                        msg = InputDecomposer.add_conjugation_rule!(stem, forms)
                        println(msg)
                        add_message_to_history!("System", "/decomposer addConjugation: $msg", false)
                    catch e
                        if e isa ArgumentError
                            println("❌ /decomposer addConjugation: $(e.msg)")
                        else
                            println("❌ /decomposer addConjugation FAILED: $e")
                            @warn "[CLI] /decomposer addConjugation error: $e"
                        end
                    end
                end

            elseif !isnothing(m_decomp_remconjg)
                # /decomposer removeConjugation <stem>
                stem = String(m_decomp_remconjg.captures[1])
                try
                    msg = InputDecomposer.remove_conjugation_rule!(stem)
                    println(msg)
                    add_message_to_history!("System", "/decomposer removeConjugation: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer removeConjugation: $(e.msg)")
                    else
                        println("❌ /decomposer removeConjugation FAILED: $e")
                        @warn "[CLI] /decomposer removeConjugation error: $e"
                    end
                end

            elseif !isnothing(m_decomp_setctx)
                # /decomposer setContext <word>
                word = String(m_decomp_setctx.captures[1])
                try
                    msg = InputDecomposer.set_context_conjunction!(word)
                    println(msg)
                    add_message_to_history!("System", "/decomposer setContext: $msg", false)
                catch e
                    if e isa ArgumentError
                        println("❌ /decomposer setContext: $(e.msg)")
                    else
                        println("❌ /decomposer setContext FAILED: $e")
                        @warn "[CLI] /decomposer setContext error: $e"
                    end
                end

            elseif !isnothing(m_decomp_reset)
                # /decomposer reset — nuclear option: back to built-in defaults
                try
                    msg = InputDecomposer.reset_config!()
                    println(msg)
                    add_message_to_history!("System", "/decomposer reset: $msg", false)
                catch e
                    println("❌ /decomposer reset FAILED: $e")
                    @warn "[CLI] /decomposer reset error: $e"
                end

            # GRUG v10: /flashcard commands — inspect and manage flashcard lookup table
            elseif !isnothing(m_flashcard_status)
                begin
                    _fc_total = 0
                    for (lobe_id, lrec) in Lobe.LOBE_REGISTRY
                        _fc_count = LobeTable.flashcard_count(lobe_id)
                        if _fc_count > 0
                            println("  📇  $lobe_id ($(lrec.subject)): $_fc_count cards")
                        end
                        _fc_total += _fc_count
                    end
                    if _fc_total == 0
                        println("📇  No flashcards stored. Math facts will be learned on first encounter.")
                    else
                        println("📇  Total: $_fc_total flashcard(s)")
                    end
                end
            elseif !isnothing(m_flashcard_query)
                begin
                    _fc_lobe = String(m_flashcard_query.captures[1])
                    _fc_expr = String(m_flashcard_query.captures[2])
                    _fc_result = LobeTable.flashcard_get(_fc_lobe, _fc_expr)
                    if _fc_result !== nothing
                        println("📇  $_fc_expr = $(_fc_result) (lobe=$_fc_lobe)")
                    else
                        println("📇  No flashcard found for '$_fc_expr' in lobe '$_fc_lobe'")
                    end
                end
            elseif !isnothing(m_flashcard_evict)
                begin
                    _fc_lobe = String(m_flashcard_evict.captures[1])
                    _fc_expr = String(m_flashcard_evict.captures[2])
                    LobeTable.flashcard_evict!(_fc_lobe, _fc_expr)
                    println("📇  Evicted flashcard '$_fc_expr' from lobe '$_fc_lobe'")
                end
            elseif !isnothing(m_flashcard_count)
                _fc_total = 0
                for (lobe_id, lrec) in Lobe.LOBE_REGISTRY
                    _fc_total += LobeTable.flashcard_count(lobe_id)
                end
                println("📇  Total flashcards: $_fc_total")
            # GRUG v10: /curiosity commands — inspect and manage curiosity accumulator
            elseif !isnothing(m_curiosity_status)
                begin
                    _cur_st = AutoGrowth.get_curiosity_status()
                    _cur_int = get(_cur_st, "intensity", 0.0)
                    _cur_buf = get(_cur_st, "buffer", String[])
                    _cur_quenched = get(_cur_st, "quenched_at", 0.0)
                    _cur_overflows = get(_cur_st, "overflow_count", 0)
                    println("🔥  Curiosity accumulator:")
                    println("     intensity:       $(round(_cur_int, digits=3)) / $(AutoGrowth.CURIOSITY_OVERFLOW_THRESHOLD)")
                    println("     buffer entries:  $(length(_cur_buf))")
                    println("     overflow count:  $(string(_cur_overflows))")
                    if _cur_quenched > 0.0
                        _cur_cool_remaining = max(0.0, AutoGrowth.CURIOSITY_COOLDOWN - (time() - _cur_quenched))
                        println("     quench cooldown: $(round(_cur_cool_remaining, digits=1))s remaining")
                    else
                        println("     quench cooldown: none (ready to overflow)")
                    end
                    if !isempty(_cur_buf)
                        println("     pending patterns: $(join(_cur_buf[1:min(5, length(_cur_buf))], ", "))$(length(_cur_buf) > 5 ? " (+$(length(_cur_buf)-5) more)" : "")")
                    end
                end
            elseif !isnothing(m_curiosity_quench)
                AutoGrowth.quench_curiosity!()
                println("🔥  Curiosity quenched. Intensity reset to 0.0. Cooldown started.")

            elseif !isnothing(m_phase_status)
                # /automaton phase OR /automaton phase status — show phase accumulator status
                try
                    println(EphemeralAutomaton.phase_pull_status_string())
                catch e
                    println("❌ /automaton phase status FAILED: $e")
                    @warn "[CLI] /automaton phase status error: $e"
                end

            elseif !isnothing(m_phase_thresh)
                # /automaton phase threshold <float>
                thresh_str = String(m_phase_thresh.captures[1])
                try
                    thresh_val = parse(Float64, thresh_str)
                    if thresh_val < 0.1 || thresh_val > 0.9
                        println("❌ /automaton phase threshold: must be between 0.1 and 0.9, got $thresh_val")
                    else
                        EphemeralAutomaton.set_phase_pull_threshold!(thresh_val)
                        println("💎 Phase pull threshold set to $thresh_val")
                    end
                catch e
                    println("❌ /automaton phase threshold: invalid value '$thresh_str': $e")
                end

            elseif !isnothing(m_phase_surface)
                # /automaton phase surface <int>
                count_str = String(m_phase_surface.captures[1])
                try
                    count_val = parse(Int, count_str)
                    if count_val < 0 || count_val > 16
                        println("❌ /automaton phase surface: must be between 0 and 16, got $count_val")
                    else
                        EphemeralAutomaton.set_phase_surface_count!(count_val)
                        println("💎 Phase surface count set to $count_val")
                    end
                catch e
                    println("❌ /automaton phase surface: invalid value '$count_str': $e")
                end

            elseif !isnothing(m_phase_enable)
                # /automaton phase enable
                try
                    EphemeralAutomaton.set_phase_enabled!(true)
                    println("💎 Phase pull ENABLED")
                catch e
                    println("❌ /automaton phase enable FAILED: $e")
                end

            elseif !isnothing(m_phase_disable)
                # /automaton phase disable
                try
                    EphemeralAutomaton.set_phase_enabled!(false)
                    println("💎 Phase pull DISABLED")
                catch e
                    println("❌ /automaton phase disable FAILED: $e")
                end

            elseif !isnothing(m_phase_reset)
                # /automaton phase reset — nuclear reset of phase accumulator
                try
                    EphemeralAutomaton.reset_phase_accumulator!()
                    println("💎 Phase accumulator RESET (all snapshots cleared)")
                catch e
                    println("❌ /automaton phase reset FAILED: $e")
                    @error "[CLI] /automaton phase reset error: $e"
                end



            # ── GRUG v7.29: Vigilance / Automaton Cap command handlers ──────────────

            elseif !isnothing(m_automaton_cap)
                # /automaton maxCap <n> — set max concurrent automatons (1-16)
                cap_str = String(m_automaton_cap.captures[1])
                try
                    cap_val = parse(Int, cap_str)
                    if cap_val < 1 || cap_val > 16
                        println("❌ /automaton maxCap: must be between 1 and 16, got $cap_val")
                    else
                        old_cap = EphemeralAutomaton.get_automaton_max_cap()
                        EphemeralAutomaton.set_automaton_max_cap!(cap_val)
                        println("💎 Automaton max cap: $old_cap → $cap_val")
                    end
                catch e
                    println("❌ /automaton maxCap: invalid value '$cap_str': $e")
                end

            elseif !isnothing(m_vigilance_status)
                # /vigilance OR /vigilance status — show vigilance system status
                try
                    println(EphemeralAutomaton.vigilance_status_string())
                catch e
                    println("❌ /vigilance status FAILED: $e")
                    @warn "[CLI] /vigilance status error: $e"
                end

            elseif !isnothing(m_vigilance_enable)
                # /vigilance enable — enable vigilance dispatch
                try
                    EphemeralAutomaton.set_vigilance_config!(enabled = true)
                    println("💎 Vigilance dispatch ENABLED")
                catch e
                    println("❌ /vigilance enable FAILED: $e")
                end

            elseif !isnothing(m_vigilance_disable)
                # /vigilance disable — disable vigilance dispatch
                try
                    EphemeralAutomaton.set_vigilance_config!(enabled = false)
                    println("💎 Vigilance dispatch DISABLED")
                catch e
                    println("❌ /vigilance disable FAILED: $e")
                end

            elseif !isnothing(m_vigilance_threshold)
                # /vigilance threshold <level> <float> — set weight threshold for a level band
                level_str = String(m_vigilance_threshold.captures[1])
                val_str   = String(m_vigilance_threshold.captures[2])
                try
                    val = parse(Float64, val_str)
                    if val < 0.0 || val > 1.0
                        println("❌ /vigilance threshold: value must be between 0.0 and 1.0, got $val")
                    else
                        # Map level string to the keyword arg for set_vigilance_config!
                        kw = if level_str == "low"
                            :weight_low
                        elseif level_str == "med"
                            :weight_medium
                        elseif level_str == "high"
                            :weight_high
                        elseif level_str == "extreme"
                            :weight_extreme
                        else
                            nothing
                        end
                        if isnothing(kw)
                            println("❌ /vigilance threshold: unknown level '$level_str' (use low/med/high/extreme)")
                        else
                            EphemeralAutomaton.set_vigilance_config!(; kw => val)
                            println("💎 Vigilance threshold [$level_str] set to $val")
                        end
                    end
                catch e
                    println("❌ /vigilance threshold: invalid value '$val_str': $e")
                end

            elseif !isnothing(m_vigilance_timeout)
                # /vigilance timeout <float> — set injector timeout (1.0-30.0s)
                timeout_str = String(m_vigilance_timeout.captures[1])
                try
                    timeout_val = parse(Float64, timeout_str)
                    if timeout_val < 1.0 || timeout_val > 30.0
                        println("❌ /vigilance timeout: must be between 1.0 and 30.0, got $timeout_val")
                    else
                        EphemeralAutomaton.set_vigilance_config!(injector_timeout_seconds = timeout_val)
                        println("💎 Vigilance injector timeout set to $(timeout_val)s")
                    end
                catch e
                    println("❌ /vigilance timeout: invalid value '$timeout_str': $e")
                end

            elseif !isnothing(m_vigilance_feedback)
                # /vigilance feedback <float> — set injector feedback probability (0.0-1.0)
                fb_str = String(m_vigilance_feedback.captures[1])
                try
                    fb_val = parse(Float64, fb_str)
                    if fb_val < 0.0 || fb_val > 1.0
                        println("❌ /vigilance feedback: must be between 0.0 and 1.0, got $fb_val")
                    else
                        EphemeralAutomaton.set_vigilance_config!(injector_feedback_prob = fb_val)
                        println("💎 Vigilance feedback probability set to $fb_val")
                    end
                catch e
                    println("❌ /vigilance feedback: invalid value '$fb_str': $e")
                end

            elseif !isnothing(m_sigillist)
                # GRUG v7.24: /sigil list — show every sigil in the engine table.
                # Engine-default sigils (&n, &op, &word, &rest, &noun) are
                # always present. Specimen / user-added sigils show their
                # provenance string so you can see who put them there.
                lines = String["🔮 Sigil Table (engine + specimen + user):"]
                for (name, entry) in sort(collect(_ENGINE_SIGIL_TABLE.entries); by=p->p.first)
                    parts = String["&$name", string(entry.class), "@$(entry.applies_at)"]
                    if !isnothing(entry.sigil_type); push!(parts, "type=$(entry.sigil_type)"); end
                    if !isnothing(entry.lexicon) && !isempty(entry.lexicon)
                        lex_preview = length(entry.lexicon) <= 6 ? join(entry.lexicon, ",") :
                                       join(entry.lexicon[1:6], ",") * ",…(+$(length(entry.lexicon)-6))"
                        push!(parts, "lex=[$lex_preview]")
                    end
                    if entry.promote_at_tokenize; push!(parts, "promote=true"); end
                    push!(parts, "prov=$(entry.provenance)")
                    push!(lines, "  " * join(parts, " | "))
                end
                println(join(lines, "\n"))

            elseif !isnothing(m_sigiladd)
                # GRUG v7.24: /sigil add <name> <class> <applies_at> [type=X] [lexicon=a,b,c] [promote=true]
                #   class      : lambda | macro | tag (functor/procedure/glue reserved)
                #   applies_at : bind | match
                #   type=...   : for :lambda only — number, word, op, slurp
                #   lexicon=...: for :macro only — comma-separated word list
                #   promote=...: front-door tokenizer rewrites raw matches into &name
                #
                # Math acronym example (macro class with math constant lexicon):
                #   /sigil add mathconst macro bind lexicon=pi,e,phi,tau,inf
                #   /sigil add mathfunc  macro bind lexicon=sin,cos,tan,log,exp,sqrt
                #
                # Token sigil example (lambda class for math operators with promote):
                #   /sigil add op2 lambda match type=op promote=true
                sigil_name  = String(strip(m_sigiladd.captures[1]))
                class_str   = lowercase(String(strip(m_sigiladd.captures[2])))
                applies_str = lowercase(String(strip(m_sigiladd.captures[3])))
                opts_str    = m_sigiladd.captures[4] === nothing ? "" : String(m_sigiladd.captures[4])

                # Parse optional kwargs
                opt_type     = nothing
                opt_lexicon  = nothing
                opt_promote  = false
                for tok in split(opts_str)
                    tok = String(strip(tok))
                    isempty(tok) && continue
                    if startswith(tok, "type=")
                        opt_type = Symbol(tok[6:end])
                    elseif startswith(tok, "lexicon=")
                        raw = tok[9:end]
                        opt_lexicon = String[String(strip(w)) for w in split(raw, ",") if !isempty(strip(w))]
                    elseif startswith(tok, "promote=")
                        opt_promote = lowercase(tok[9:end]) in ("true","1","yes","y")
                    else
                        println("⚠  /sigil add: unknown option '$tok' ignored. Use type=X | lexicon=a,b,c | promote=true.")
                    end
                end

                try
                    SigilRegistry.register_sigil!(_ENGINE_SIGIL_TABLE;
                        name=sigil_name,
                        class=Symbol(class_str),
                        applies_at=Symbol(applies_str),
                        sigil_type=opt_type,
                        lexicon=opt_lexicon,
                        provenance="user-cli",
                        promote_at_tokenize=opt_promote)
                    extras = String[]
                    !isnothing(opt_type)    && push!(extras, "type=$(opt_type)")
                    !isnothing(opt_lexicon) && push!(extras, "lexicon=$(length(opt_lexicon)) words")
                    opt_promote             && push!(extras, "promote=true")
                    suffix = isempty(extras) ? "" : " (" * join(extras, ", ") * ")"
                    msg = "🔮 Sigil &$sigil_name registered as :$class_str @ :$applies_str$suffix"
                    println(msg)
                    add_message_to_history!("System", msg, false)
                catch e
                    println("!!! /sigil add ERROR: $e !!!")
                end

            elseif !isnothing(m_sigilremove)
                # GRUG v7.24: /sigil remove <name>. Engine-default sigils are
                # protected — removal of those would break pattern-bind. Only
                # specimen-loaded or user-cli sigils can be removed.
                sigil_name = String(strip(m_sigilremove.captures[1]))
                if !haskey(_ENGINE_SIGIL_TABLE.entries, sigil_name)
                    println("⚠  /sigil remove: '&$sigil_name' not in registry.")
                else
                    entry = _ENGINE_SIGIL_TABLE.entries[sigil_name]
                    if entry.provenance == "engine-default"
                        println("⛔ /sigil remove: '&$sigil_name' is engine-default; refusing to remove (would break pattern-bind).")
                    else
                        delete!(_ENGINE_SIGIL_TABLE.entries, sigil_name)
                        msg = "🗑  Sigil &$sigil_name removed (was prov=$(entry.provenance))."
                        println(msg)
                        add_message_to_history!("System", msg, false)
                    end
                end


            # ── GRUG v9: CoherenceField command levers ──────────────────────────
            # These expose the implicit coherence field Φ and gradient ΔΦ that
            # the system already computes internally. Weight=0.0 (off) by default
            # so these are read-only diagnostics until the operator enables routing.

            elseif !isnothing(m_coherence)
                # /coherence — show current field value Φ + summary
                lock(NODE_LOCK) do
                    phi = CoherenceField.compute_field(NODE_MAP; force=true)
                    cfg = CoherenceField.coherence_config_snapshot()
                    if cfg.weight ≈ 0.0
                        println("Φ = $(round(phi; digits=4))  [routing OFF — weight=0.0]")
                        println("  Use /coherenceConfig weight 0.05 to enable gradient routing")
                    else
                        println("Φ = $(round(phi; digits=4))  [routing ON — weight=$(cfg.weight)]")
                    end
                    println("  Nodes: $(length(NODE_MAP)), cached Φ: $(round(cfg.cached_phi; digits=4)) (age: $(round(time() - cfg.cache_timestamp; digits=1))s)")
                end

            elseif !isnothing(m_coherence_grad)
                # /coherenceGradient <node_id> — show ΔΦ for a candidate node
                target_id = String(strip(m_coherence_grad.captures[1]))
                lock(NODE_LOCK) do
                    if !haskey(NODE_MAP, target_id)
                        println("⚠  /coherenceGradient: node '$target_id' not found in NODE_MAP")
                    else
                        delta = CoherenceField.compute_delta(target_id, NODE_MAP, BRIDGE_MAP; force=true)
                        direction = delta > 0 ? "↑ COHERENT (positive contribution)" : delta < 0 ? "↓ DECOHERENT (negative contribution)" : "— NEUTRAL"
                        cfg = CoherenceField.coherence_config_snapshot()
                        println("ΔΦ($target_id) = $(round(delta; digits=6))  $direction")
                        if cfg.weight ≈ 0.0
                            println("  [routing OFF — this gradient has NO effect on voting]")
                        else
                            impact = cfg.weight * delta
                            println("  Vote impact: weight×ΔΦ = $(round(impact; digits=6))")
                        end
                    end
                end

            elseif !isnothing(m_coherence_field)
                # /coherenceField — detailed field breakdown
                lock(NODE_LOCK) do
                    status = CoherenceField.coherence_field_status(NODE_MAP; force=true)
                    phi = status["phi"]
                    n_nodes = status["n_nodes"]
                    n_active = status["n_active"]
                    n_coherent = status["n_coherent"]
                    top5 = status["top_contributors"]
                    bot5 = status["bottom_contributors"]
                    cfg = CoherenceField.coherence_config_snapshot()

                    println("╔══════════════════════════════════════╗")
                    println("║     COHERENCE FIELD STATUS (v9)      ║")
                    println("╠══════════════════════════════════════╣")
                    println("║  Φ = $(rpad(round(phi; digits=4), 28))║")
                    println("║  Nodes: $(rpad("$n_nodes total, $n_active active, $n_coherent coherent", 29))║")
                    println("║  Weight: $(rpad("$(cfg.weight) (max=$(CoherenceField.COHERENCE_WEIGHT_MAX))", 28))║")
                    println("║  Depth: $(rpad("$(cfg.depth) (max=$(CoherenceField.COHERENCE_DEPTH_MAX))", 28))║")
                    println("║  Decay: $(rpad("$(cfg.decay)", 28))║")
                    println("║  Recency: $(rpad("$(cfg.recency_window)s", 28))║")
                    println("╠══════════════════════════════════════╣")
                    println("║  Top contributors:                   ║")
                    for tc in top5
                        println("║    $(rpad("$(tc["id"]): Φ-contrib=$(round(tc["contribution"]; digits=4))", 37))║")
                    end
                    if !isempty(bot5)
                        println("║  Bottom contributors:                ║")
                        for bc in bot5
                            println("║    $(rpad("$(bc["id"]): Φ-contrib=$(round(bc["contribution"]; digits=4))", 37))║")
                        end
                    end
                    println("╚══════════════════════════════════════╝")
                end

            elseif !isnothing(m_coherence_config)
                # /coherenceConfig [subcommand [value]]
                #   (no args)        — show current config
                #   weight <float>   — set routing weight (0.0=off, max 0.5)
                #   depth <int>      — set gradient walk depth (1-3)
                #   decay <float>    — set activation decay rate (0.0-0.1)
                #   recency <float>  — set recency window in seconds
                #   reset            — reset all to defaults
                config_arg = m_coherence_config.captures[1]
                if isnothing(config_arg) || isempty(strip(String(config_arg)))
                    cfg = CoherenceField.coherence_config_snapshot()
                    println("CoherenceField config:")
                    println("  weight    = $(cfg.weight)  (0.0=off, max=$(CoherenceField.COHERENCE_WEIGHT_MAX))")
                    println("  depth     = $(cfg.depth)  (1-3, max=$(CoherenceField.COHERENCE_DEPTH_MAX))")
                    println("  decay     = $(cfg.decay)  (0.0-0.1)")
                    println("  recency   = $(cfg.recency_window)s  (window for 'recently fired')")
                    println("  cache_ttl = $(cfg.cache_ttl)s")
                else
                    parts = split(strip(String(config_arg)))
                    if isempty(parts)
                        cfg = CoherenceField.coherence_config_snapshot()
                        println("CoherenceField config: weight=$(cfg.weight), depth=$(cfg.depth), decay=$(cfg.decay), recency=$(cfg.recency_window)s")
                    elseif String(parts[1]) == "weight"
                        if length(parts) < 2
                            println("⚠  /coherenceConfig weight <float> — missing value")
                        else
                            val = tryparse(Float64, String(parts[2]))
                            if isnothing(val)
                                println("⚠  /coherenceConfig weight: '$(parts[2])' is not a valid float")
                            else
                                try
                                    CoherenceField.set_coherence_config!(:weight, val)
                                    println("✓  CoherenceField weight = $val")
                                    if val > 0.0
                                        println("  ⚡ GRADIENT ROUTING ENABLED — votes will be modulated by ΔΦ")
                                        if val > 0.3
                                            println("  ⚠️  WARNING: weight > 0.3 risks quantum Zeno effect (state locking)")
                                        end
                                    else
                                        println("  Gradient routing OFF — weight=0.0")
                                    end
                                catch e
                                    println("⚠  $e")
                                end
                            end
                        end
                    elseif String(parts[1]) == "depth"
                        if length(parts) < 2
                            println("⚠  /coherenceConfig depth <int> — missing value")
                        else
                            val = tryparse(Int, String(parts[2]))
                            if isnothing(val)
                                println("⚠  /coherenceConfig depth: '$(parts[2])' is not a valid int")
                            else
                                try
                                    CoherenceField.set_coherence_config!(:depth, val)
                                    println("✓  CoherenceField depth = $val")
                                catch e
                                    println("⚠  $e")
                                end
                            end
                        end
                    elseif String(parts[1]) == "decay"
                        if length(parts) < 2
                            println("⚠  /coherenceConfig decay <float> — missing value")
                        else
                            val = tryparse(Float64, String(parts[2]))
                            if isnothing(val)
                                println("⚠  /coherenceConfig decay: '$(parts[2])' is not a valid float")
                            else
                                try
                                    CoherenceField.set_coherence_config!(:decay, val)
                                    println("✓  CoherenceField decay = $val")
                                catch e
                                    println("⚠  $e")
                                end
                            end
                        end
                    elseif String(parts[1]) == "recency"
                        if length(parts) < 2
                            println("⚠  /coherenceConfig recency <float> — missing value (seconds)")
                        else
                            val = tryparse(Float64, String(parts[2]))
                            if isnothing(val)
                                println("⚠  /coherenceConfig recency: '$(parts[2])' is not a valid float")
                            else
                                try
                                    CoherenceField.set_coherence_config!(:recency_window, val)
                                    println("✓  CoherenceField recency_window = $(val)s")
                                catch e
                                    println("⚠  $e")
                                end
                            end
                        end
                    elseif String(parts[1]) == "reset"
                        CoherenceField.reset_coherence_config!()
                        println("✓  CoherenceField config reset to defaults (weight=0.0)")
                    else
                        println("⚠  /coherenceConfig: unknown subcommand '$(parts[1])'")
                        println("   Valid: weight, depth, decay, recency, reset")
                    end
                end

            elseif !isnothing(m_errors)
                # /errors [clear] — show or clear the error journal
                # GRUG: The main catch block writes errors to SelfObserver with tag :error
                # and prefix "error_". This command reads them back so the specimen
                # can see its own mistakes. Same store, same pattern as MLP observations.
                if m_errors.captures[1] !== nothing && String(m_errors.captures[1]) == "clear"
                    # Wipe all error observations from the store (prefix-matched, not the whole store)
                    _n_dropped = SelfObserver.drop_keys_by_prefix!(_MLP_OBSERVER_STORE, "error_")
                    println("✓  Error journal cleared ($(_n_dropped) error entries removed)")
                else
                    # Peek at recent errors
                    _err_hints = SelfObserver.peek_pattern(
                        _MLP_OBSERVER_STORE,
                        "errors",          # node_id for error queries
                        "error_";          # key prefix to match error observations
                        max_entries = 20,
                    )
                    if _err_hints === nothing || isempty(_err_hints)
                        println("Error journal: (empty — no errors observed)")
                    else
                        println("╔══════════════════════════════════════╗")
                        println("║     ERROR JOURNAL ($(length(_err_hints)) recent)       ║")
                        println("╠══════════════════════════════════════╣")
                        for (idx, h) in enumerate(_err_hints)
                            _exc = get(h.payload_strings, "exception", "???")
                            _cmd = get(h.payload_strings, "command", "???")
                            _bt  = get(h.payload_strings, "backtrace_snippet", "")
                            # Truncate long exceptions for readability
                            _exc_short = length(_exc) > 80 ? _exc[1:77] * "..." : _exc
                            println("║  [$idx] $(_exc_short)")
                            println("║      cmd: $(_cmd)  age: $(h.fuzzy_when)")
                            if !isempty(_bt) && length(_bt) > 5
                                _bt_short = length(_bt) > 60 ? _bt[1:57] * "..." : _bt
                                println("║      bt:  $(_bt_short)")
                            end
                        end
                        println("╚══════════════════════════════════════╝")
                        println("  Use /errors clear to wipe the journal")
                    end
                end

            else
                error("!!! FATAL: Grug command bad format. Use /help to see all valid commands. !!!")
            end
            
        catch e
            println("!!! SYSTEM ERROR: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
            # GRUG v9: Write error to SelfObserver so the specimen can see its own
            # mistakes via /errors. Same store as MLP observations — vigilance injectors
            # can probe these too, which means the specimen's context enrichment knows
            # about recent errors on the next cycle. High salience = errors are memorable.
            # p_write=1.0 = always write (unlike output observations which are probabilistic).
            try
                _bt_frames = catch_backtrace()
                _bt_snippet = isempty(_bt_frames) ? "" :
                    join([string(f) for f in _bt_frames[1:min(3, length(_bt_frames))]], " ← ")
                SelfObserver.observe!(
                    _MLP_OBSERVER_STORE,
                    "error_$(round(Int, time() * 1000) % 1_000_000)",
                    :meta,         # GRUG FIX: was :error which is not in VALID_TAGS
                    Dict{String, Any}(
                        "exception"        => string(e),
                        "command"          => string(line),
                        "backtrace_snippet"=> _bt_snippet,
                    );
                    p_write    = 1.0,   # always journal errors
                    salience   = 8.0,   # errors are highly memorable
                    provenance = :runtime_error,
                )
            catch obs_err
                # Double-fault: error observation itself failed. Don't make it worse.
                @warn "[MAIN v9] Error journal observe! failed (non-fatal): $obs_err"
            end
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
# TAILS triggers a phagy cycle: one of twelve maintenance automata runs
# (ORPHAN_PRUNER, STRENGTH_DECAYER, GRAVE_RECYCLER, DROP_TABLE_COMPACT,
# RULE_PRUNER, MEMORY_FORENSICS; automaton 7 reserved;
# INJECTOR_GRAVEYARD_SWEEP, PHASE_ACCUMULATOR_AGING, OBSERVER_STORE_PRUNE,
# SIGIL_CONSISTENCY_CHECK, STALE_TRAJECTORY_TRIM). Automata 8-12 are gated
# on their respective subsystem dependencies being passed to run_phagy!.
# Phagy also requires 1000+ nodes (gated above coinflip).
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
#  14. bridges        — BRIDGE_MAP cascade bridge system (bidirectional)
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
# File format: JSON (.json, plain text, cross-platform) or gzip-compressed
# JSON (.gz, requires system gzip/gunzip). Auto-detected by extension.
# ==============================================================================