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

# GRUG: SelfObserver — subconscious-style microlog store. ARCHITECTURALLY ISOLATED
# from vote ranking and routing. Stochastic writes, throttled single-reader peeks,
# fuzzy "rule of thumb" time buckets, drop-table associative recall. The public
# API returns NO Float64 — this is a structural guarantee enforced by tests.
# Side processes never affect vote confidence: SelfObserver hints are usable only
# by the generation/system-prompt layer, never by candidate scoring.
include("SelfObserver.jl")
using .SelfObserver

# GRUG: SigilRegistry — Stage 1 sigil registry kernel. Single source of truth
# for typed symbolic handles (&n, &word, &rest, &noun, ...) used in pattern
# matching and (in later stages) cross-subsystem semantic propagation. Stage 1
# activates classes :lambda, :macro, :tag and phases :bind, :match. Reserved
# classes (:glue, :functor, :procedure) and reserved phases are accepted on
# registration but rejected at pattern-resolution time. NO SILENT FAILURES:
# unknown sigils, bad classes, malformed names all THROW. Patterns with no
# `&` token take a fast path that allocates nothing — old specimens are
# bit-identical to pre-sigil behaviour. See plans/sigil_architecture/STAGE1.md
# for the locked-in scope and the reserved-stage roadmap.
include("SigilRegistry.jl")
using .SigilRegistry

# GRUG: SigilPromoter — Stage 1.5a front-door input promoter. Two-pass:
# Layer 1 canonicalizes tokens via closed number-word and op-word maps
# ("two plus two" -> "2 + 2"); Layer 2 walks registry sigils with
# promote_at_tokenize=true and rewrites canonical tokens into &n / &op /
# specimen-defined macros. Returns (rewritten_string, bindings_vector)
# where bindings ride as a side-channel — ATP and the Stage 3 evaluator
# consume them, the matcher and confidence math NEVER see them.
# This is the population-compression mechanic: many surface variants of
# the same shape collapse to one canonical matcher input, so one node per
# shape is enough instead of one node per variant. NO SILENT FAILURES.
# Idempotent. Fast path on no-promotable input. See plans/sigil_architecture/
# STAGE_1_5A.md for the locked-in scope.
include("SigilPromoter.jl")
using .SigilPromoter

# GRUG: ArithmeticEngine — Stage 2 arithmetic evaluator. When sigils capture
# math in user input (&n &op &n), this module reads the bindings and ACTUALLY
# COMPUTES the result (2+2=4, not "Execute the calculation"). Returns structured
# ArithmeticResult that the AIML payload builder injects into the reply.
# MUST come after SigilPromoter because it does `using ..SigilPromoter`.
include("ArithmeticEngine.jl")
using .ArithmeticEngine

# GRUG: v7.23 — MultipartOrchestrator. Coalesces votes that share a
# `multipart_group` id into one cohesive AIML objective with internal
# (locked / unsure) structure. Singletons pass through as one-vote objectives
# so downstream code sees a uniform shape. Depends on VoteOrchestrator
# constants only; uses duck-typing on the Vote struct so this module does
# not require engine.jl to be loaded first.
include("MultipartOrchestrator.jl")
using .MultipartOrchestrator

# GRUG: v7.23 — EphemeralAutomaton. ATP-callable JIT step machine for
# pattern-completion paths. Pure working-memory loop, no node population,
# user-extensible rule set, jitter snap-back on caller-tagged numeric
# outputs only. Depends on RelationalJitter.
include("EphemeralAutomaton.jl")
using .EphemeralAutomaton

# GRUG: v7.23 — InputDecomposer. Detects compound queries (multiple independent
# sub-subjects in one user input) and splits them into sub-subjects, each with
# a multipart_group ID. The group ID flows DOWN through scan and vote so
# MultipartOrchestrator can coalesce votes from different scan passes into
# one cohesive objective. THIS is where multipart_group is born — not in the
# node, not in the vote, but at the INPUT DECOMPOSITION LAYER.
include("InputDecomposer.jl")
using .InputDecomposer

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

# GRUG: SelfObserver exports — subconscious microlog store. Public surface only.
# Microlog and SubconsciousStore are exported for callers who need to construct
# their own; the typical caller just uses observe!/peek_exact/peek_pattern.
# audit_trail returns Int-valued counters (no Float64 leakage path).
export SelfObserver
export Microlog, SubconsciousStore, SubconsciousHint
export SelfObserverError, SelfObserverConfigError, SelfObserverArgumentError
export observe!, peek_exact, peek_pattern, audit_trail
export drop_store!, reset_audit!, store_size, key_count
export FUZZY_BUCKETS

# GRUG: SigilRegistry exports — Stage 1 sigil kernel public surface.
# Registry entry/table types, error types, registration/lookup/list helpers,
# pattern-resolution entry point, default registry builder, and merge helper.
# Constants (SIGIL_CLASSES, SIGIL_APPLIES_AT, SIGIL_PREFIX, regexes) are
# exported for callers that want to validate against the closed enums
# without reaching into the submodule namespace.
export SigilRegistry
export SigilEntry, SigilTable, SigilTokenRef
export SigilError, SigilConfigError, SigilArgumentError, SigilResolutionError
export register_sigil!, lookup_sigil, has_sigil, list_sigils, clear_registry!
export resolve_sigils_in_pattern, parse_sigil_token
export default_registry, merge_registry!
export SIGIL_CLASSES, SIGIL_APPLIES_AT, SIGIL_PREFIX
export SIGIL_NAME_REGEX, SIGIL_TOKEN_REGEX

# GRUG: SigilPromoter exports — Stage 1.5a front-door input promoter.
# `promote_input(table, raw)` is the single public entry point; it returns
# `(rewritten_string, bindings::Vector{SigilBinding})`. `bindings_by_name`
# offers a name-keyed view for consumers that don't care about absolute
# position. Closed canonical maps (NUMBER_WORD_MAP, OP_WORD_MAP, OP_SYMBOL_SET)
# are exported for callers that want to inspect or extend them at registry-
# build time. Error types follow the same shape as SigilRegistry: typed
# throws on bad input, no silent fallbacks.
export SigilPromoter
export SigilBinding
export PromoterError, PromoterArgumentError, PromoterConfigError
export promote_input, bindings_by_name, canonicalize_token
export NUMBER_WORD_MAP, OP_WORD_MAP, OP_SYMBOL_SET, NUMBER_TOKEN_REGEX

# GRUG: front-door promotion side-channel accessors (live in engine.jl,
# re-exported here so callers don't have to know which module owns the
# task-local storage). Stage 1.5a-fix-1 added current_promotion_raw to
# preserve the user's verbatim input alongside the rewritten string.
export current_promotion_bindings, current_promotion_rewritten, current_promotion_raw

# GRUG: ArithmeticEngine exports — Stage 2 arithmetic evaluator.
# `compute_arithmetic(bindings)` is the primary entry point; it returns an
# ArithmeticResult with the computed answer, step-by-step breakdown, and
# formatted reply string. `format_arithmetic_reply` produces natural-language
# output like "2 plus 2 equals 4". `has_math_bindings` is a cheap predicate
# for checking whether bindings contain enough math sigils to attempt evaluation.
export ArithmeticEngine
export ArithmeticResult, ComputationStep
export compute_arithmetic, format_arithmetic_reply, has_math_bindings

# GRUG: v7.23 MultipartOrchestrator exports — vote coalescing into objectives.
# `build_objectives(votes)` is the primary entry; pairs nicely with the existing
# `select_aiml_votes` (singletons can flow through either path identically).
# `MultipartObjective` is the unit of work AIML now consumes.
export MultipartOrchestrator
export MultipartObjective, MultipartError
export group_votes_by_multipart, build_objectives, summarize_objective

# GRUG: v7.23 EphemeralAutomaton exports — ATP-callable JIT step machine.
# Rules are persistent in the registry; traces are not. `register_automaton_rule!`
# adds a rule; `run_for_action_family(family, conf)` is the typical ATP-side
# call (returns nothing if no matching rule). `:procedure` sigils from the
# registry can stand in as compact step descriptions.
export EphemeralAutomaton
export AutomatonRule, AutomatonStep, AutomatonTrace
export AutomatonError, AutomatonRuleError
export register_automaton_rule!, unregister_automaton_rule!,
       list_automaton_rules, lookup_automaton_rule, clear_automaton_rules!
export run_automaton, find_matching_rule, run_for_action_family

# GRUG: v7.23 InputDecomposer exports — compound-query decomposition.
# `decompose_input(text)` is the primary entry; returns Vector{DecomposedSubSubject}.
# `is_compound(text)` is a cheap boolean check. Each sub-subject carries a
# multipart_group ID that flows into scan → vote → MultipartOrchestrator.
export InputDecomposer
export DecomposedSubSubject, decompose_input, is_compound

# GRUG: v7.23 — :procedure class activation in SigilRegistry. New helpers for
# math-acronym style sigils that expand to ordered chains of literals and
# nested sigil tokens. Bounded recursion (cycle guard); loud failures on
# unknown nested references.
export register_procedure_sigil!, expand_procedure_sigil, is_procedure_sigil,
       MAX_PROCEDURE_DEPTH

# GRUG: v7.23 — ATP→automaton escalation hook. `maybe_escalate(prediction)` is
# the primary entry; it checks if the predicted action family is in
# ESCALATION_FAMILIES and confidence is high enough, then runs the matching
# automaton rule. `LAST_ESCALATION_TRACE` stores the trace for downstream
# consumers. Zero cost when no escalation occurs.
export maybe_escalate, ESCALATION_FAMILIES, LAST_ESCALATION_TRACE

end # module GrugBot420