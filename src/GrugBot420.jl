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

# GRUG NOTE: TonalJudge was considered for port from origin/main but it
# depends on v7.21b-1 features (get_tonal_observation, emotional_coherence,
# classifier_mode) that the v7.15-updates ActionTonePredictor does not have.
# Rather than break the v7.15/v7.16 lock-in floor + relation-gated support
# stack by hot-swapping ATP, the new tonal build-up + per-prediction Lorenz
# snap-back dynamics are added directly to this branch's ActionTonePredictor.
# If TonalJudge is wanted later, port the v7.21b-1 emotional-coherence
# struct fields first.

include("LobeTable.jl")
using .LobeTable

include("Lobe.jl")
using .Lobe

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

# GRUG v7.15: Lobe orchestrator --- sequential + curved-average + multi-lobe
# async floor selection + cross-talk 1000-cap gate. Must load BEFORE engine.jl
# so engine and Main can use summarize_lobe_votes / compute_orchestration_plan.
include("LobeOrchestrator.jl")
using .LobeOrchestrator
# #############################################################################
# ###  DO NOT ADD LOBE MUTING. DO NOT CHANGE LOBE SELECTION TO A GATE.     ###
# ###  THE CORRECT DESIGN IS LobeOrchestrator.jl: SEQUENTIAL FIRING.       ###
# ###  LOBES ARE NEVER MUTED. DO NOT RE-ENABLE LOBE_TOPICALITY_FLOOR.      ###
# #############################################################################

# GRUG v7.15: Group registry --- 8-16 partner random cap, chatter windowing
# cursor, compressed JSON disk persistence. Must load BEFORE ChatterVoteSwap
# (which consumes group ids) and BEFORE PhagyMode extensions.
include("GroupRegistry.jl")
using .GroupRegistry

# GRUG v7.15: Crystalize tag --- user + auto crystalizer. Must load BEFORE
# engine.jl (attachment fire path respects crystalize) and BEFORE PhagyMode
# (maintenance pass revokes auto-crystalization).
include("CrystalizeTag.jl")
using .CrystalizeTag

# GRUG v7.15: Chatter vote-swap engine --- replaces pattern-copy chatter with
# vote-copy chatter. Loaded after RelationalJitter + GroupRegistry since it
# uses their primitives. Coexists with the classic ChatterMode above; callers
# pick the path they want.
include("ChatterVoteSwap.jl")
using .ChatterVoteSwap

# GRUG v7.15: Dynamic action-tone predictor --- gated by semantic complexity.
# Thin wrapper over ActionTonePredictor; loaded here so engine.jl can choose
# the dynamic path when screen_input_complexity clears COMPLEXITY_FLOOR.
include("DynamicActionTonePredictor.jl")
using .DynamicActionTonePredictor

# GRUG v7.15: Phagy group organizer automaton --- idle-time cleanup of the
# GroupRegistry. Loaded here so the phagy scheduler (and tests) can reach it.
include("PhagyGroupOrganizer.jl")
using .PhagyGroupOrganizer

# ==============================================================================
# v7.15 PHAGY AUTOMATON 7 REGISTRATION
# ==============================================================================
# GRUG: Wire PhagyGroupOrganizer into PhagyMode as the 7th automaton. This runs
# at package load time (after every module is included), converting the
# downstream GroupOrganizerStats into the PhagyStats record PhagyMode expects.
# NO SILENT FAILURE: if the organizer throws, the error propagates to
# run_phagy!'s rethrow block --- callers see the trace.
# NO CIRCULAR DEPENDENCY: PhagyMode doesn't import PhagyGroupOrganizer; it just
# stores the callback reference, so the load order stays clean.
# ==============================================================================
let
    # GRUG: Adapter closure --- zero-arg, returns PhagyMode.PhagyStats.
    organizer_adapter = function ()
        t_start = time()
        stats   = PhagyGroupOrganizer.run_group_organizer!()
        elapsed_ms = (time() - t_start) * 1000.0

        items_changed = stats.unlinkable_cleared + stats.groups_pruned +
                        (stats.cursor_reset ? 1 : 0)
        notes = string(
            "unlinkable_cleared=", stats.unlinkable_cleared,
            " groups_pruned=",     stats.groups_pruned,
            " cursor_reset=",      stats.cursor_reset,
        )
        # GRUG: items_processed == items_changed for this automaton --- it
        # only touches what it decides to mutate, no separate "examined"
        # population. Keeps the PhagyStats shape honest rather than padding
        # with a fake scan count.
        return PhagyMode.PhagyStats(
            PhagyMode.GROUP_ORGANIZER_NAME,
            items_changed,
            items_changed,
            elapsed_ms,
            notes,
        )
    end

    PhagyMode.register_group_organizer!(organizer_adapter)
end

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

# ────────────────────────────────────────────────────────────────────────────
# GRUG (port from main): subconscious + sigil + arithmetic stack.
# Order matters:
#   SelfObserver       — quiet-thought microlog; observation-only, never
#                        touches confidence. Used by AIML reply assembly to
#                        whisper fuzzy time-cues at the end if asked.
#   SigilRegistry      — Stage 1 sigil kernel (&n, &op, &noun, &word, &rest).
#                        Pure registry; no engine deps.
#   SigilPromoter      — Stage 1.5a/c front-door input promoter. Rewrites
#                        "two plus two" → "what is &n &op &n" before pattern
#                        matching. Depends on SigilRegistry.
#   ArithmeticEngine   — Stage 2 sigil-bound math. Reads SigilPromoter
#                        bindings, computes, returns ComputationStep.
# All four are additive: zero-cost when inputs don't trigger them; no
# v7.15/v7.16 module needs to know they exist.
# ────────────────────────────────────────────────────────────────────────────
include("SelfObserver.jl")
using .SelfObserver

include("SigilRegistry.jl")
using .SigilRegistry

include("SigilPromoter.jl")
using .SigilPromoter

# ArithmeticEngine MUST come after SigilPromoter (it does `using ..SigilPromoter`).
include("ArithmeticEngine.jl")
using .ArithmeticEngine

# GRUG v7.17: InputDecomposer — splits compound inputs into independent clauses.
# No module deps; pure text splitting. Lives BEFORE SigilMediator in the pipeline.
include("InputDecomposer.jl")
using .InputDecomposer

# SigilMediator is the engine-level coordinator on top of Registry/Promoter/Arith.
# Must come after all three (it `using`s each).
include("SigilMediator.jl")
using .SigilMediator

include("engine.jl")

# GRUG v7.17: MultipartOrchestrator — groups votes by objective_id for coherent
# multipart responses. Must come AFTER engine.jl (needs Vote struct).
include("MultipartOrchestrator.jl")
using .MultipartOrchestrator

include("Main.jl")

# --------------------------------------------------------------------------
# Re-exports for public API
# --------------------------------------------------------------------------
export @coinflip, bias
export cheap_scan, medium_scan, high_res_scan, big_number_small_number_coherence
export NONJITTER_TAG, is_nonjitter, set_nonjitter!, clear_nonjitter!, collect_nonjitter_ids
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
export strong_low_conf_override, jitter_score_with_override
export NONJITTER_OVERRIDE_STRENGTH_FLOOR, NONJITTER_OVERRIDE_CONF_CEIL

# GRUG v7.24: LobeOrchestrator exports --- sequential + lock-in-average floor
export LobeOrchestratorError, LobeVoteSummary, OrchestrationPlan, FloorWinner
export summarize_lobe_votes, compute_orchestration_plan
export MULTI_LOBE_THRESHOLD, MIN_WINNING_VOTES
export PER_LOBE_FIRE_CAP, CROSS_TALK_ACTIVE_CAP
export CrossTalkGate, new_cross_talk_gate
export try_claim_cross_talk!, release_cross_talk!, reserved_cross_talk_slots

# GRUG v7.15: GroupRegistry exports --- chatter groups, disk persistence
export GroupRegistryError, NodeGroup, GroupRegistryState
export register_node_in_group!, remove_node_from_group!, grave_node_in_group!
export grave_node_everywhere!
export get_group, list_group_ids, group_count, node_partners, partners_for_node
export next_chatter_window_ids, advance_chatter_cursor!
export save_registry_compressed, load_registry_compressed
export PARTNER_CAP_MIN, PARTNER_CAP_MAX, CHATTER_WINDOW_MIN, CHATTER_WINDOW_MAX
export assign_partner_cap, mark_unlinkable!, clear_unlinkable_if_has_grave!
export is_unlinkable, reset_registry!

# GRUG v7.15: CrystalizeTag exports --- user + auto crystalizer
export CrystalizeError
export crystalize!, uncrystalize!, is_crystalized, list_crystalized
export mark_user_crystalized!, mark_auto_crystalized!, is_auto_crystalized
export clear_all_crystalized!, crystalized_count
export should_auto_crystalize
export AUTO_STRENGTH_FLOOR, AUTO_SEMANTIC_FLOOR, AUTO_STRENGTH_RELEASE_FLOOR

# GRUG v7.15: ChatterVoteSwap exports --- vote-copy chatter with 1hr cooldown
export ChatterVoteSwapError, VoteSwapEvent, VoteSwapStats
export run_vote_swap_round!, should_swap_vote
export can_chatter_now, record_chatter_time!, clear_chatter_cooldowns!
export CHATTER_COOLDOWN_SECONDS, SEMANTIC_INTENSITY_CAP, WEIGHT_JITTER_RATIO
export DONATED_BARE_WEIGHT_PROB, DONATED_BARE_WEIGHT

# GRUG v7.15: DynamicActionTonePredictor exports --- complexity-gated dynamic path
export DynamicPredictionError
export predict_action_tone_dynamic, compute_semantic_complexity
export should_use_dynamic_path, COMPLEXITY_FLOOR

# GRUG v7.15: PhagyGroupOrganizer exports --- idle-time GroupRegistry cleanup
export GroupOrganizerStats, run_group_organizer!

end # module GrugBot420