__precompile__(false)

module GrugBot420

# ==============================================================================
# GrugBot420 — Neuromorphic Cognitive Engine
# ==============================================================================
# A neuromorphic AI engine that models cognition through competing populations
# of pattern nodes. Many rocks compete to be loudest. Loudest rock gets to talk.
# Sometimes a quiet rock gets lucky (coinflip). That is how Grug think.
# ==============================================================================

using Distributions
using JSON
using Random
using Base.Threads: Atomic, atomic_add!, ReentrantLock
using Base64: base64decode

# --------------------------------------------------------------------------
# Submodule includes (order matters — upstream before downstream)
# --------------------------------------------------------------------------
include("stochastichelper.jl")
using .CoinFlipHeader

include("patternscanner.jl")
using .PatternScanner

include("ImageSDF.jl")
using .ImageSDF

include("EyeSystem.jl")
using .EyeSystem

include("SemanticVerbs.jl")
using .SemanticVerbs

include("ActionTonePredictor.jl")
using .ActionTonePredictor

include("TonalJudge.jl")
using .TonalJudge

include("LobeTable.jl")
using .LobeTable

include("Lobe.jl")
using .Lobe

# GRUG: LobeOrchestrator — averages-curve lobe selection (replaces the
# v7.18 hard mute gate). Must be loaded before engine.jl which references it
# in scan_and_expand. See plans/semantic_plugins/QOL_SWEEP_2025.md "BUG-011
# rewrite" for the spec.
include("LobeOrchestrator.jl")
using .LobeOrchestrator

include("BrainStem.jl")
using .BrainStem

include("Thesaurus.jl")
using .Thesaurus

include("InputQueue.jl")
using .InputQueue

include("ChatterMode.jl")
using .ChatterMode

include("PhagyMode.jl")
using .PhagyMode

# GRUG: Immune system — must be included before engine.jl so engine can use it.
# Scans all growth/ledger inputs for funky patterns before they touch anything.
include("ImmuneSystem.jl")
using .ImmuneSystem

# GRUG: Immune thread pool — 8 dedicated side threads for immune processing.
# All input waiting/collection happens here. Main cave never waits for immune work.
include("ImmuneThreadPool.jl")
using .ImmuneThreadPool

# GRUG: Full-lobe scanner - bounded activation scanning for associative memory
include("FullLobeScanner.jl")
using .FullLobeScanner

# GRUG: Relational jitter — per-activation zero-mean nudge on scored values
# and coin thresholds. Must load BEFORE AIMLNodeSystem (AIML strength/delta
# call sites use jitter_strength/jitter_delta/jitter_coin_threshold) AND
# BEFORE engine.jl (evaluate_relational_dialectics uses jitter_score/jitter_weight).
include("RelationalJitter.jl")
using .RelationalJitter

# GRUG: AIML node tribes - lobe-specific executive node populations.
# Must load BEFORE Main.jl so command handlers can reach the API. Ordering
# matters: Lobe must already exist so AIML knows what parent cap to read
# when registering a lobe's AIML tribe. Depends on RelationalJitter above.
include("AIMLNodeSystem.jl")
using .AIMLNodeSystem

# GRUG: Vote orchestrator — parallel 1000-cap fire + DONE signalling + threshold vote pick.
# Must load BEFORE engine.jl so engine can call parallel_fire_batches and FireCounter.
include("VoteOrchestrator.jl")
using .VoteOrchestrator

include("engine.jl")
include("Main.jl")

# --------------------------------------------------------------------------
# Re-exports for public API
# --------------------------------------------------------------------------
export @coinflip, bias
export cheap_scan, medium_scan, high_res_scan, big_number_small_number_coherence
export NONJITTER_TAG, is_nonjitter, set_nonjitter!, clear_nonjitter!, collect_nonjitter_ids,
       JITTER_CONFIDENCE_FLOOR, jitter_allowed_for
export STRENGTH_SOLIDIFY_THRESHOLD, is_solidified, check_solidify_threshold!
export detect_image_binary, image_to_sdf_params, SDFParams, apply_sdf_jitter
export sdf_to_signal, JITGPU
export add_verb!, add_relation_class!, add_synonym!
export create_lobe!, connect_lobes!, lobe_grow!
export create_lobe_table!
export immune_scan!, get_immune_status, get_ledger_entries
# GRUG: Immune thread pool exports — hardcore edition
export create_immune_pool, submit_immune_work!, submit_and_wait!, kill_immune_pool!
export restart_worker!, get_pool_status, get_worker_load, get_cost_weighted_load
export ImmuneFuture, ImmunePool, ImmuneWorkItem
export ImmuneWorkerDiedError, ImmunePoolOverloadError, ImmunePoolDeadError, ImmuneWorkerBalancerError
export ImmuneRateLimitExhaustedError, ImmuneTripwireTriggeredError, ImmunePriorityInversionError
export fetch_result, is_ready
# GRUG: Hardcore feature exports
export PriorityLevel, PRIORITY_CRITICAL, PRIORITY_NORMAL, PRIORITY_LOW, PRIORITY_JUNK
export ScanCost, COST_CHEAP, COST_MODERATE, COST_EXPENSIVE, COST_WEIGHTS, estimate_scan_cost
export SourceID, SOURCE_INTERNAL, SOURCE_ANONYMOUS
export TripwireState, TRIPWIRE_NORMAL, TRIPWIRE_ELEVATED, TRIPWIRE_HARDENED, TRIPWIRE_CRITICAL
export TokenBucket, TripwireMonitor, ImmuneRateLimiter
export try_consume!, refill!, get_tripwire_state
export record_processed!, get_rejection_rate, get_lane_size, update_tripwire_state!
export TRIPWIRE_WINDOW_S
export RATE_LIMIT_TOKENS_PER_SEC, RATE_LIMIT_BURST
export RATE_LIMIT_TOKENS_PER_SEC_HARDENED, RATE_LIMIT_BURST_HARDENED
export TRIPWIRE_ELEVATED_THRESHOLD, TRIPWIRE_HARDENED_THRESHOLD, TRIPWIRE_CRITICAL_THRESHOLD
export MAX_WAITING_LIST_SIZE_PER_PRIORITY

# GRUG: Full-lobe scanner exports
export FullLobeScanner, ScanResult, ActiveNodeSet
export PatternMatch, SemanticMatch
export FullLobeScanError, NoMatchFoundError
export set_query!, gather_candidates!, activate_candidates!
export continue_scan!, full_scan!, reset!
export can_aiml_respond, require_aiml_ready!
export scanner_status, print_status
export MAX_ACTIVE_NODES, MAX_THREADS, CONFIDENT_THRESHOLD

# GRUG: AIML node tribes exports - lobe-specific executive node populations
export AIMLNode, AIMLNodeError
export AIML_STRENGTH_CAP, AIML_STRENGTH_FLOOR, AIML_POPULATION_CAP_RATIO
export register_lobe!, unregister_lobe!, is_lobe_registered
export get_population_cap, get_population_size
export add_aiml_node!, get_aiml_node, has_aiml_node, remove_aiml_node!
export list_aiml_nodes, get_registered_lobes
export begin_cycle!, current_cycle
export record_fire!, record_vote!
export apply_aiml_right!, apply_aiml_wrong!
export aiml_phagy_sweep!, get_aiml_status_summary

# GRUG: RelationalJitter exports — per-activation zero-mean nudge on match scores
# and AIML strength/delta/coin-threshold values, plus the /brainstorm scoped
# heavy-jitter override. Nested module is still reachable as
# GrugBot420.RelationalJitter; these re-exports surface the common primitives
# directly on the package namespace.
export JitterError, JitterScopeError, JitterConfig
export JITTER_RATIO_DEFAULT, HARD_REQ_MISS_SENTINEL
export JITTER_COIN_RATIO_DEFAULT, JITTER_COIN_FLOOR, JITTER_COIN_CEILING
export JITTER_BRAINSTORM_RATIO, JITTER_BRAINSTORM_COIN_RATIO
export jitter_value, jitter_score, jitter_weight
export jitter_strength, jitter_delta, jitter_coin_threshold
export enable_jitter!, disable_jitter!, is_jitter_enabled
export set_jitter_ratio!, get_jitter_ratio
export set_jitter_coin_ratio!, get_jitter_coin_ratio
export with_brainstorm_jitter, is_brainstorm_active, get_brainstorm_depth

end # module GrugBot420