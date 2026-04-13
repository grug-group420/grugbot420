# ImmuneSystem.jl — Specimen Immune System (Automata-Based Anomaly Handling)
# ==============================================================================
# GRUG: This is the cave's immune system. When specimen is mature (≥1000 nodes),
# every growth/ledger command gets AST-scanned before it touches anything.
# If input looks funky, automata crew wakes up, coinflips, quarantines, patches,
# or deletes. NO SILENT FAILURES. Every decision is logged in the ledger.
#
# GRUG: Think weird berry analogy. Berry arrives. Grug looks at it.
# If berry looks normal → remember its shape in Hopfield memory, let it in.
# If berry looks funky → wake up helper spirits (automata).
# Each helper coinflips 50/50 before doing anything (prevents explosion).
# Helper quarantines berry, tries to patch it on a timer.
# If patch fails → crush berry (delete), log why.
# Everything is written down. Nothing happens in the dark.
#
# DESIGN RULES:
#   - No silent failures. Every path logs to the ledger.
#   - Maturity gate: immune system sleeps below 1000 nodes.
#   - Automata population = 1/3 of node count.
#   - Each automata agent coinflips independently (population coinflip).
#   - Ephemeral agents: born on input arrival, die after handling.
#   - Persistent state: HopfieldImmuneMemory + ImmuneLedger survive across calls.
#   - Thread safe: all shared state behind ReentrantLock.
#   - Non-adversarial: patch before delete, quarantine before action.
# ==============================================================================

module ImmuneSystem

using Random

export ImmuneError, ImmuneLedger, HopfieldImmuneMemory
export immune_scan!, get_immune_status, get_ledger_entries
export immune_ast_signature, detect_funky, quarantine_input!, attempt_patch, delete_input!
export add_known_signature!, lookup_signature, reset_immune_state!

# ==============================================================================
# ERROR TYPES — GRUG: NO SILENT FAILURES
# ==============================================================================

struct ImmuneError <: Exception
    kind::Symbol
    signature::UInt64
    info::Any
end

function Base.showerror(io::IO, e::ImmuneError)
    print(io, "ImmuneError($(e.kind)): sig=0x$(string(e.signature, base=16)), info=$(e.info)")
end

# ==============================================================================
# CONSTANTS — GRUG like numbers in one place
# ==============================================================================

# GRUG: Specimen must have this many nodes before immune system wakes up.
# Below this, specimen is too young — immune reactions would kill it.
const MATURITY_THRESHOLD = 1000

# GRUG: Automata population is 1/3 of node count. Each coinflips independently.
const AUTOMATA_POPULATION_RATIO = 1//3

# GRUG: Each automata agent has 50/50 chance to materialize.
# This prevents explosion — not every agent acts on every funky input.
const COINFLIP_PROBABILITY = 0.5

# GRUG: Maximum time (seconds) an automata agent spends trying to patch.
# After this, patch is declared failed. Berry gets crushed.
const PATCH_TIMEOUT_SECONDS = 2.0

# GRUG: Jitter on patch timeout so agents don't all timeout simultaneously.
const PATCH_TIMEOUT_JITTER = 0.5

# GRUG: Maximum ledger entries before oldest get trimmed.
# Append-only within this window. Grug's memory cave has walls.
const MAX_LEDGER_ENTRIES = 10000

# GRUG: Minimum AST token count for a scan to be meaningful.
# Fewer tokens than this = not enough structure to judge.
const MIN_AST_TOKENS = 1

# GRUG: Maximum quarantine queue size. Prevents memory bloat from flood.
const MAX_QUARANTINE_SIZE = 256

# ==============================================================================
# IMMUNE LEDGER — Append-only event log
# ==============================================================================
# GRUG: Every immune decision gets written here. Nothing happens in the dark.
# Ledger entries have: timestamp, event kind, AST signature, extra info.

struct LedgerEntry
    timestamp::Float64
    kind::Symbol
    signature::UInt64
    info::Any
end

const IMMUNE_LEDGER = LedgerEntry[]
const LEDGER_LOCK   = ReentrantLock()

"""
    log_immune_event!(kind::Symbol, signature::UInt64, info=nothing)

GRUG: Write event to immune ledger. No-op is FORBIDDEN. Every call writes.
Trims oldest entries if ledger exceeds MAX_LEDGER_ENTRIES.
"""
function log_immune_event!(kind::Symbol, signature::UInt64, info=nothing)
    entry = LedgerEntry(time(), kind, signature, info)
    lock(LEDGER_LOCK) do
        push!(IMMUNE_LEDGER, entry)
        if length(IMMUNE_LEDGER) > MAX_LEDGER_ENTRIES
            # GRUG: Trim oldest 10% to avoid trimming every single call
            trim_count = div(MAX_LEDGER_ENTRIES, 10)
            deleteat!(IMMUNE_LEDGER, 1:trim_count)
        end
    end
    return entry
end

"""
    get_ledger_entries(n::Int=50)::Vector{LedgerEntry}

GRUG: Return last n ledger entries for diagnostics. Non-destructive read.
"""
function get_ledger_entries(n::Int=50)::Vector{LedgerEntry}
    if n <= 0
        error("!!! FATAL: get_ledger_entries got n=$n, must be positive! !!!")
    end
    lock(LEDGER_LOCK) do
        start_idx = max(1, length(IMMUNE_LEDGER) - n + 1)
        return IMMUNE_LEDGER[start_idx:end]
    end
end

# ==============================================================================
# HOPFIELD IMMUNE MEMORY — Attractor memory for known-safe AST signatures
# ==============================================================================
# GRUG: When input is NOT funky, its AST signature gets stored here.
# Next time similar input arrives, Hopfield memory recognizes it as safe.
# This is a SEPARATE memory from the engine's Hopfield cache.
# Engine Hopfield = "I've seen this input text before, here are the node IDs."
# Immune Hopfield = "I've scanned this AST shape before, it was safe."

const IMMUNE_HOPFIELD       = Dict{UInt64, Int}()  # signature → seen_count
const IMMUNE_HOPFIELD_LOCK  = ReentrantLock()

# GRUG: How many times a signature must be seen before it's "strongly known".
# Below this, we still scan but with lighter suspicion.
const HOPFIELD_FAMILIARITY_THRESHOLD = 3

"""
    add_known_signature!(sig::UInt64)

GRUG: Register a non-funky AST signature in immune memory.
Increments the familiarity counter. Safe signatures get stronger basins.
"""
function add_known_signature!(sig::UInt64)
    lock(IMMUNE_HOPFIELD_LOCK) do
        IMMUNE_HOPFIELD[sig] = get(IMMUNE_HOPFIELD, sig, 0) + 1
    end
    log_immune_event!(:nonfunky_stored, sig, nothing)
end

"""
    lookup_signature(sig::UInt64)::Int

GRUG: Check how familiar this signature is. Returns seen_count (0 = never seen).
"""
function lookup_signature(sig::UInt64)::Int
    lock(IMMUNE_HOPFIELD_LOCK) do
        return get(IMMUNE_HOPFIELD, sig, 0)
    end
end

"""
    is_signature_known(sig::UInt64)::Bool

GRUG: Returns true if this signature has been seen enough times to be trusted.
"""
function is_signature_known(sig::UInt64)::Bool
    return lookup_signature(sig) >= HOPFIELD_FAMILIARITY_THRESHOLD
end

# ==============================================================================
# QUARANTINE ZONE — Temporary holding for funky inputs
# ==============================================================================
# GRUG: Funky inputs go here before patch/delete decision.
# Quarantine is ephemeral — cleared after each immune cycle.

mutable struct QuarantinedInput
    original_text::String
    signature::UInt64
    quarantined_at::Float64
    patch_attempted::Bool
    patch_result::Symbol   # :pending, :success, :failure
    agent_id::Int          # which automata agent handled this
end

const QUARANTINE_ZONE = QuarantinedInput[]
const QUARANTINE_LOCK = ReentrantLock()

"""
    quarantine_input!(text::String, sig::UInt64, agent_id::Int)::QuarantinedInput

GRUG: Put funky input in quarantine. Log it. Returns the quarantine record.
"""
function quarantine_input!(text::String, sig::UInt64, agent_id::Int)::QuarantinedInput
    if strip(text) == ""
        error("!!! FATAL: Cannot quarantine empty input! !!!")
    end

    record = QuarantinedInput(text, sig, time(), false, :pending, agent_id)

    lock(QUARANTINE_LOCK) do
        if length(QUARANTINE_ZONE) >= MAX_QUARANTINE_SIZE
            error("!!! FATAL: Quarantine zone full ($(MAX_QUARANTINE_SIZE) items)! Specimen under heavy attack or flood! !!!")
        end
        push!(QUARANTINE_ZONE, record)
    end

    log_immune_event!(:quarantine, sig, Dict("agent_id" => agent_id))
    return record
end

# ==============================================================================
# AST SIGNATURE GENERATION
# ==============================================================================
# GRUG: High-resolution AST scan of input text.
# "AST" here means structural analysis of the input — token structure, length
# distribution, character classes, command shape. Not a compiler AST.
# The signature is a hash of these structural features so similar structures
# produce similar (ideally identical) signatures.

"""
    immune_ast_signature(input_text::String)::UInt64

GRUG: Generate structural AST signature from input text.
Analyzes token structure, character class distribution, length ratios,
and command shape. Returns UInt64 hash of structural features.
Academic: This is a structural fingerprint, not a content hash.
Two inputs with same structure but different words should hash similarly.
"""
function immune_ast_signature(input_text::String)::UInt64
    if strip(input_text) == ""
        error("!!! FATAL: immune_ast_signature got empty input! !!!")
    end

    tokens = split(strip(input_text))
    n_tokens = length(tokens)

    if n_tokens < MIN_AST_TOKENS
        error("!!! FATAL: Input has $n_tokens tokens, need at least $MIN_AST_TOKENS for AST scan! !!!")
    end

    # GRUG: Structural features (not content-dependent):
    # 1. Token count bucket (quantized to reduce sensitivity)
    token_bucket = div(n_tokens, 5) * 5  # bucket by 5s

    # 2. Average token length bucket
    avg_len = sum(length.(tokens)) / n_tokens
    avg_len_bucket = round(Int, avg_len * 2) # quantize to 0.5 resolution

    # 3. Character class ratio: alpha vs numeric vs punctuation
    text_flat = join(tokens, " ")
    n_alpha = count(isletter, text_flat)
    n_digit = count(isdigit, text_flat)
    n_punct = count(c -> ispunct(c), text_flat)
    n_total = max(length(text_flat), 1)
    alpha_ratio = round(Int, (n_alpha / n_total) * 10)
    digit_ratio = round(Int, (n_digit / n_total) * 10)
    punct_ratio = round(Int, (n_punct / n_total) * 10)

    # 4. First token class (command shape detector)
    first_token = lowercase(tokens[1])
    first_class = if startswith(first_token, "{") || startswith(first_token, "[")
        1  # JSON-like
    elseif startswith(first_token, "/")
        2  # command-like
    elseif all(isuppercase, first_token) && length(first_token) > 1
        3  # SHOUTING
    else
        0  # normal
    end

    # 5. Presence of JSON structure markers
    has_json = ('{' in text_flat || '[' in text_flat) ? 1 : 0

    # 6. Max token length (catches abnormally long tokens — possible injection)
    max_token_len = maximum(length.(tokens))
    max_token_bucket = div(min(max_token_len, 100), 10)

    # GRUG: Combine structural features into a hash.
    # Use Julia's built-in hash which is good enough for this purpose.
    feature_vec = (token_bucket, avg_len_bucket, alpha_ratio, digit_ratio,
                   punct_ratio, first_class, has_json, max_token_bucket)
    return hash(feature_vec)
end

# ==============================================================================
# FUNKY DETECTION
# ==============================================================================
# GRUG: "Funky" = input whose AST signature doesn't match known patterns.
# Known patterns come from two sources:
#   1. Immune Hopfield memory (previously seen safe signatures)
#   2. Built-in structural expectations for grow/ledger commands

"""
    detect_funky(sig::UInt64, input_text::String)::Bool

GRUG: Returns true if input looks funky (unknown/suspicious structure).
Returns false if input matches known safe patterns in immune memory.
"""
function detect_funky(sig::UInt64, input_text::String)::Bool
    # GRUG: If Hopfield memory strongly recognizes this signature, it's safe.
    if is_signature_known(sig)
        return false
    end

    # GRUG: Basic structural sanity checks for grow commands (JSON expected)
    text = strip(input_text)

    # GRUG: Check if it looks like valid JSON structure for /grow commands
    if startswith(text, "{") || startswith(text, "[")
        # JSON-shaped inputs: check for balanced brackets (rough check)
        open_count = count(c -> c == '{' || c == '[', text)
        close_count = count(c -> c == '}' || c == ']', text)
        if open_count != close_count
            return true  # GRUG: Unbalanced brackets = funky!
        end
        # GRUG: If seen before even once (not strongly), still give benefit of doubt
        if lookup_signature(sig) > 0
            return false
        end
        return false  # JSON structure looks balanced, probably fine
    end

    # GRUG: If we've seen this signature at least once but not strongly, borderline.
    # Give it a pass — Hopfield will strengthen with more sightings.
    seen_count = lookup_signature(sig)
    if seen_count > 0
        return false
    end

    # GRUG: Truly novel signature for non-JSON input — funky!
    return true
end

# ==============================================================================
# PATCH ATTEMPT
# ==============================================================================
# GRUG: Try to repurpose/fix a funky input within a time limit.
# "Patching" means: can we interpret this input charitably?
# If the structure is close to something we know, patch succeeds.
# If it's completely alien, patch fails.

"""
    attempt_patch(input_text::String, sig::UInt64; t_max::Float64=PATCH_TIMEOUT_SECONDS)::Symbol

GRUG: Attempt to patch a quarantined input.
Returns :success if input can be repurposed, :failure if not.
Operates within stochastic time limit (t_max ± jitter).
"""
function attempt_patch(input_text::String, sig::UInt64; t_max::Float64=PATCH_TIMEOUT_SECONDS)::Symbol
    if strip(input_text) == ""
        error("!!! FATAL: attempt_patch got empty input! !!!")
    end

    # GRUG: Stochastic timer — add jitter so agents don't synchronize
    actual_timeout = t_max + (rand() - 0.5) * PATCH_TIMEOUT_JITTER

    t_start = time()

    # GRUG: Patch heuristics — try to find something salvageable
    text = strip(input_text)
    tokens = split(text)

    # Check 1: Does it have any recognizable command structure?
    has_command_tokens = any(t -> startswith(lowercase(t), "/") ||
                                 lowercase(t) in ["grow", "add", "create", "set", "update", "delete", "remove"],
                            tokens)

    # Check 2: Is the text length reasonable? (not too short, not suspiciously long)
    reasonable_length = 1 <= length(tokens) <= 500

    # Check 3: Character encoding sanity (no excessive control characters)
    control_chars = count(c -> iscntrl(c) && c != '\n' && c != '\r' && c != '\t', text)
    clean_encoding = control_chars <= 2

    # GRUG: Time check — don't exceed our budget
    if (time() - t_start) > actual_timeout
        log_immune_event!(:patch_timeout, sig, Dict("elapsed" => time() - t_start))
        return :failure
    end

    # GRUG: Patch succeeds if at least 2 of 3 heuristics pass
    score = Int(has_command_tokens) + Int(reasonable_length) + Int(clean_encoding)

    if score >= 2
        log_immune_event!(:patch_success, sig, Dict("score" => score, "heuristics" => "cmd=$(has_command_tokens),len=$(reasonable_length),enc=$(clean_encoding)"))
        return :success
    else
        log_immune_event!(:patch_failure, sig, Dict("score" => score, "heuristics" => "cmd=$(has_command_tokens),len=$(reasonable_length),enc=$(clean_encoding)"))
        return :failure
    end
end

# ==============================================================================
# DELETE INPUT
# ==============================================================================

"""
    delete_input!(input_text::String, sig::UInt64)

GRUG: Permanently reject a funky input that failed patching.
Logs deletion event. Input is gone. Berry is crushed.
"""
function delete_input!(input_text::String, sig::UInt64)
    log_immune_event!(:delete, sig, Dict("text_preview" => input_text[1:min(80, length(input_text))]))
    # GRUG: Input is not stored anywhere after this. It's gone.
    # The only trace is the ledger entry above.
    return nothing
end

# ==============================================================================
# MAIN IMMUNE SCAN — The full pipeline
# ==============================================================================

"""
    immune_scan!(input_text::String, node_count::Int; is_critical::Bool=true)::Tuple{Symbol, UInt64}

GRUG: Run the full immune system pipeline on an input.

Returns (status, signature) where status is one of:
  :immature    — specimen below maturity threshold, immune system sleeping
  :nonfunky    — input is safe, signature stored in Hopfield memory
  :coinflip_skip — input was funky but all agents coinflipped to skip
  :patched     — input was funky, quarantined, and successfully patched
  :deleted     — input was funky, quarantine+patch failed, input destroyed
  :error       — something went wrong (details in ledger)

Academic: This function implements the full immune pipeline:
  1. Maturity gate check
  2. AST scan → structural signature
  3. Funky detection (compare against Hopfield + known patterns)
  4. Non-funky → store in Hopfield, return :nonfunky
  5. Funky → spawn automata population, each coinflips
  6. Materialized agents → quarantine → patch → delete on failure
  7. All paths logged to ledger

is_critical: Set to true for grow/ledger commands (full immune response).
             Set to false for casual input (lighter response, just log).
"""
function immune_scan!(input_text::String, node_count::Int; is_critical::Bool=true)::Tuple{Symbol, UInt64}
    if strip(input_text) == ""
        error("!!! FATAL: immune_scan! got empty input! !!!")
    end

    if node_count < 0
        error("!!! FATAL: immune_scan! got negative node_count=$node_count! !!!")
    end

    # GRUG: Step 0 — Maturity gate
    if node_count < MATURITY_THRESHOLD
        return (:immature, UInt64(0))
    end

    # GRUG: Step 1 — High-resolution AST scan
    sig = immune_ast_signature(input_text)

    # GRUG: Step 2 — Funky detection
    funky = detect_funky(sig, input_text)

    if !funky
        # GRUG: Safe berry! Remember its shape, let it through.
        add_known_signature!(sig)
        return (:nonfunky, sig)
    end

    # GRUG: Input is funky! Log it immediately.
    log_immune_event!(:funky_detected, sig, Dict(
        "text_preview" => input_text[1:min(80, length(input_text))],
        "node_count" => node_count,
        "is_critical" => is_critical
    ))

    # GRUG: For non-critical inputs (casual chat), just log and let through.
    # Immune system only gets aggressive for growth/ledger commands.
    if !is_critical
        log_immune_event!(:noncritical_pass, sig, nothing)
        return (:nonfunky, sig)
    end

    # GRUG: Step 3 — Spawn automata population
    automata_count = max(1, div(node_count, 3))

    # GRUG: Step 4 — Population coinflip. Each agent flips independently.
    # Count how many agents materialize (decide to act).
    materialized_count = 0
    for agent_id in 1:automata_count
        if rand() < COINFLIP_PROBABILITY
            materialized_count += 1
        end
    end

    # GRUG: If NO agents materialized, log the skip and let input through.
    # This is the stochastic imperfection — the system might miss things.
    # That's by design. Organisms aren't perfect either.
    if materialized_count == 0
        log_immune_event!(:coinflip_skip, sig, Dict(
            "automata_count" => automata_count,
            "materialized" => 0
        ))
        return (:coinflip_skip, sig)
    end

    log_immune_event!(:automata_materialized, sig, Dict(
        "automata_count" => automata_count,
        "materialized" => materialized_count
    ))

    # GRUG: Step 5 — First materialized agent quarantines and tries to patch
    # Only ONE agent acts (synergy rule — avoid collisions).
    # The first materialized agent handles it. Others stand by.
    acting_agent_id = 1  # First agent takes point

    qrecord = quarantine_input!(input_text, sig, acting_agent_id)

    # GRUG: Step 6 — Attempt patch within stochastic timer
    patch_result = attempt_patch(input_text, sig)
    qrecord.patch_attempted = true
    qrecord.patch_result = patch_result

    if patch_result == :success
        # GRUG: Patched! Input is repurposed. Add to Hopfield so we
        # recognize it next time (learning from experience).
        add_known_signature!(sig)

        # GRUG: Clean up quarantine zone
        lock(QUARANTINE_LOCK) do
            filter!(q -> q.signature != sig, QUARANTINE_ZONE)
        end

        return (:patched, sig)
    else
        # GRUG: Patch failed. Delete the input. Log everything.
        delete_input!(input_text, sig)

        # GRUG: Clean up quarantine zone
        lock(QUARANTINE_LOCK) do
            filter!(q -> q.signature != sig, QUARANTINE_ZONE)
        end

        # GRUG: Throw ImmuneError so caller knows input was rejected.
        # This is NOT a silent failure — it's an explicit rejection.
        throw(ImmuneError(:rejected, sig, "Funky input failed patching and was deleted"))
    end
end

# ==============================================================================
# STATUS / DIAGNOSTICS
# ==============================================================================

"""
    get_immune_status()::Dict{String, Any}

GRUG: Return immune system status for /status CLI display.
"""
function get_immune_status()::Dict{String, Any}
    ledger_count = lock(LEDGER_LOCK) do
        length(IMMUNE_LEDGER)
    end

    hopfield_count = lock(IMMUNE_HOPFIELD_LOCK) do
        length(IMMUNE_HOPFIELD)
    end

    quarantine_count = lock(QUARANTINE_LOCK) do
        length(QUARANTINE_ZONE)
    end

    # GRUG: Count events by kind for summary
    event_counts = Dict{Symbol, Int}()
    lock(LEDGER_LOCK) do
        for entry in IMMUNE_LEDGER
            event_counts[entry.kind] = get(event_counts, entry.kind, 0) + 1
        end
    end

    return Dict{String, Any}(
        "ledger_entries"         => ledger_count,
        "hopfield_signatures"   => hopfield_count,
        "quarantine_depth"      => quarantine_count,
        "maturity_threshold"    => MATURITY_THRESHOLD,
        "automata_ratio"        => string(AUTOMATA_POPULATION_RATIO),
        "coinflip_probability"  => COINFLIP_PROBABILITY,
        "event_counts"          => event_counts
    )
end

# ==============================================================================
# RESET (for testing / specimen reload)
# ==============================================================================

"""
    reset_immune_state!()

GRUG: Wipe all immune state. Used during /loadSpecimen and testing.
"""
function reset_immune_state!()
    lock(LEDGER_LOCK) do
        empty!(IMMUNE_LEDGER)
    end
    lock(IMMUNE_HOPFIELD_LOCK) do
        empty!(IMMUNE_HOPFIELD)
    end
    lock(QUARANTINE_LOCK) do
        empty!(QUARANTINE_ZONE)
    end
end

# ==============================================================================
# SERIALIZATION HELPERS (for specimen persistence)
# ==============================================================================

"""
    serialize_immune_state()::Dict{String, Any}

GRUG: Export immune state for /saveSpecimen.
"""
function serialize_immune_state()::Dict{String, Any}
    hopfield_data = Dict{String, Any}()
    lock(IMMUNE_HOPFIELD_LOCK) do
        for (sig, count) in IMMUNE_HOPFIELD
            hopfield_data[string(sig)] = count
        end
    end

    ledger_data = Dict{String, Any}[]
    lock(LEDGER_LOCK) do
        for entry in IMMUNE_LEDGER
            push!(ledger_data, Dict{String, Any}(
                "timestamp" => entry.timestamp,
                "kind"      => string(entry.kind),
                "signature" => string(entry.signature),
                "info"      => entry.info
            ))
        end
    end

    return Dict{String, Any}(
        "hopfield"  => hopfield_data,
        "ledger"    => ledger_data
    )
end

"""
    deserialize_immune_state!(data::Dict)

GRUG: Restore immune state from /loadSpecimen data.
"""
function deserialize_immune_state!(data::Dict)
    reset_immune_state!()

    # Restore Hopfield memory
    if haskey(data, "hopfield") && isa(data["hopfield"], Dict)
        lock(IMMUNE_HOPFIELD_LOCK) do
            for (sig_str, count) in data["hopfield"]
                IMMUNE_HOPFIELD[parse(UInt64, sig_str)] = Int(count)
            end
        end
    end

    # Restore ledger
    if haskey(data, "ledger") && isa(data["ledger"], AbstractVector)
        lock(LEDGER_LOCK) do
            for entry_data in data["ledger"]
                push!(IMMUNE_LEDGER, LedgerEntry(
                    Float64(get(entry_data, "timestamp", 0.0)),
                    Symbol(get(entry_data, "kind", "unknown")),
                    parse(UInt64, string(get(entry_data, "signature", "0"))),
                    get(entry_data, "info", nothing)
                ))
            end
        end
    end
end

# ==============================================================================
# ACADEMIC BLOCK
# ==============================================================================
# The Specimen Immune System implements a biologically-inspired anomaly detection
# mechanism for a growing neuromorphic node graph. It draws from:
#
# 1. **Hopfield Attractor Memory**: Non-funky AST signatures are stored in an
#    attractor memory that strengthens with repeated observation. This creates
#    basins of attraction around known-safe input structures, enabling fast
#    recognition of familiar patterns without full re-scanning.
#
# 2. **Stochastic Automata Population**: When an anomaly is detected, a population
#    of ephemeral automata agents is spawned (|population| = ⌊N/3⌋ where N is
#    node count). Each agent independently performs a Bernoulli trial (p=0.5)
#    to decide whether to materialize. This population-level coinflip prevents
#    explosion: the probability that ALL agents skip is (0.5)^k which approaches
#    zero for large populations, while the probability of synchronized action
#    remains bounded.
#
# 3. **Quarantine-Patch-Delete Pipeline**: Materialized agents quarantine the
#    anomalous input and attempt structural patching within a stochastic time
#    window (t_max ± jitter). Patching applies heuristic analysis to determine
#    if the input can be charitably reinterpreted. Failed patches result in
#    input deletion with full audit trail.
#
# 4. **Non-Adversarial Design**: The system never assumes malicious intent.
#    It patches before deleting, quarantines before acting, and logs every
#    decision. This is closer to biological immune response (tolerance-based)
#    than to adversarial security models (firewall-based).
#
# 5. **Maturity Gating**: The immune system only activates for specimens with
#    ≥1000 nodes. Below this threshold, the specimen is too small for
#    meaningful pattern recognition, and immune reactions would be more
#    harmful than the anomalies they detect.
#
# Formal specification:
#   Let I = input, N = |NodeMap|, A = ⌊N/3⌋, p = 0.5, T = t_max ± jitter
#   sig(I) = structural_hash(AST(I))
#   detect_funky(sig) = ¬(sig ∈ HopfieldMemory ∧ familiarity(sig) ≥ threshold)
#   materialize(a_i) ~ Bernoulli(p) for i ∈ {1..A}
#   immune_scan(I, N) =
#     if N < 1000: (:immature, 0)
#     if ¬funky:   HopfieldMemory ∪= {sig}; (:nonfunky, sig)
#     if Σmaterialize = 0: (:coinflip_skip, sig)
#     quarantine(I); result = patch(I, T)
#     if result = :success: HopfieldMemory ∪= {sig}; (:patched, sig)
#     else: delete(I); throw(ImmuneError(:rejected, sig))
# ==============================================================================

end # module ImmuneSystem