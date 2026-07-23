__precompile__(false)

module GrugBot420

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

# GRUG: CoherenceField — scalar field Φ over the entire activation state,
# with bounded-depth gradient ΔΦ for vote-routing modulation. Weight=0.0
# (off) by default; no influence on existing behavior until user explicitly
# enables via /coherenceConfig weight 0.05. See plans/v9_command_levers.md.
include("CoherenceField.jl")
using .CoherenceField

# GRUG: GeometryKit — v9 state-space geometry. Thin wrapper over four named
# geometric spaces (semantic, coherence, phase, tone). No new algorithms —
# just names the spaces and provides unified distance/overview queries.
# Must load AFTER CoherenceField (references coherence concepts).
include("GeometryKit.jl")
using .GeometryKit

# GRUG: PatternMiner — v9 operator genesis. Self-discovery of new relation
# sigils from recurring graph shapes in the triple store.
# Follows CoherenceField's parameter-passing pattern — no cross-module refs.
include("PatternMiner.jl")
using .PatternMiner

# GRUG: TemporalIdentity — v9 temporal continuants. First-class objects
# for identity that persists across temporal change.
# Follows same parameter-passing pattern — no cross-module refs.
include("TemporalIdentity.jl")
using .TemporalIdentity

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

# GRUG: MitosisMode — idle-time autocatalytic node growth. When cave is idle
# and has enough warrant (data + energy), grow new nodes automatically.
# Five warrant sources: silence map, memory frequency, thesaurus gaps,
# lobe coverage, attachment implications. Follows ChatterMode/PhagyMode
# pattern: all state passed as parameters, no `using ..GrugBot420`.
include("MitosisMode.jl")
using .MitosisMode

# GRUG: RelationalGovernance — auto-attach from accumulated co-activation
# intensity. Nodes that fire together wire together — SLOW, LAZY, CONSERVATIVE.
# Hebbian learning at the topology level. Same attachment mechanism as /nodeAttach
# but earned organically from repeated co-firing instead of user-commanded.
# Must load AFTER MitosisMode (same idle-cycle pattern) and BEFORE engine.jl
# (so engine can call observe_co_firing! after scan cycles).
include("RelationalGovernance.jl")
using .RelationalGovernance

# GRUG: InputLedger — background thread that mines MESSAGE_HISTORY for
# growth data. Hash ledger tracks which entries have been consumed.
# Only fresh entries are digested. 10k records per batch = fuel for
# mitosis and relational governance. Runs in its own @async thread.
# Must load AFTER RelationalGovernance (calls observe_direct_co_occurrence!)
include("InputLedger.jl")
using .InputLedger

# GRUG: ChatterResiduals — background thread that mines CHATTER_LOG for
# residual co-occurrence data. When chatter swaps votes into weak nodes,
# those nodes become multi-activator randomized types with no solid group
# identity — globally unlinkable. The RESIDUAL is the co-occurrence between
# the weak node and its strong donor. This thread mines those afterimages
# as a secondary channel (1.5 increment) into RelationalGovernance.
# Must load AFTER InputLedger (same pattern, same dependency order).
include("ChatterResiduals.jl")
using .ChatterResiduals

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
# GRUG BUG-010b: Moved BEFORE AutoGrowth — AutoGrowth uses `using ..SigilRegistry`
# so SigilRegistry must be loaded first.
include("SigilRegistry.jl")
using .SigilRegistry

# GRUG v8.2: InverseSigil must load BEFORE AutoGrowth (AutoGrowth uses ..InverseSigil).
# InverseSigil needs SigilRegistry (it uses ..SigilRegistry), which is loaded
# just above. Must also load BEFORE AutoLinker and Main.jl.
include("InverseSigil.jl")
using .InverseSigil

# GRUG: AutoGrowth — live conversation evidence accumulation + lazy coinflip
# growth. Every user message carries evidence of gaps. The system accumulates
# lazily and grows when enough evidence piles up. All node types + sigils +
# thesaurus + lobe whitelists. Must load AFTER MitosisMode/RelationalGovernance/
# InputLedger/ChatterResiduals/SigilRegistry (same function-injection pattern)
# and BEFORE ImmuneSystem (growth calls immune_gate_fn on every new node).
include("AutoGrowth.jl")
using .AutoGrowth

# GRUG: AutoLinker — evidence-based cross-lobe bridge growth. Watches for
# pairs of existing nodes that SHOULD be bridged (co-firing, synonym, strain,
# opposing-lobe, etc). Accumulates link evidence lazily and bridges when
# enough evidence piles up. Cross-lobe priority (lower floor, higher bonus).
# Must load AFTER AutoGrowth (uses co-occurrence map) and BEFORE ImmuneSystem.
include("AutoLinker.jl")
using .AutoLinker

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
# and coin thresholds. Must load BEFORE engine.jl (evaluate_relational_dialectics
# uses jitter_score/jitter_weight).
include("RelationalJitter.jl")
using .RelationalJitter

# GRUG: AIMLNodeSystem removed in v8.12 — scaffold tracking layer had no
# output actuator. The stochastic rule board (ORCHESTRATION_RULES / /addRule)
# was itself removed in v9 — its output never shaped conversational_reply,
# only debug telemetry. Real orchestration is HippocampalModulator's ActionLog;
# staleness prevention is the thesaurus/synonym swap pipeline.

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

# GRUG: SigilRegistry already loaded above (before AutoGrowth, which needs it).

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

# GRUG: v7.23 — HippocampalModulator. Semantic ordering and vote scoping.
# Votes write to an ActionLog (ordered, numbered entries) instead of being
# submitted directly to AIML. Each entry carries only its objective's scoped
# votes. The modulator sequences entries with dependencies and context
# carry-forward. Log is wiped every cycle — ephemeral by nature.
# Depends on MultipartOrchestrator (for MultipartObjective type).
include("HippocampalModulator.jl")
using .HippocampalModulator

# GRUG: v7.24 — EphemeralMLP. Sigmoid/ReLU activated MLP with transformer
# backing that processes the vote list before AIML orchestration. Sigmoid
# (familiar) path uses solid/crystalized transformers; ReLU (novel) path
# uses fuzzy transformers. Jitter snap-back on key weights. User-extensible
# rules in a pattern/key-activated hash table with drop-table features.
# Ephemeral in presence (processes and dies each cycle), persistent in state
# (weights/rules survive across cycles and save/load). Depends on nothing
# except Base and Random — fully self-contained.
include("EphemeralMLP.jl")
using .EphemeralMLP

include("RoutingJudge.jl")
using .RoutingJudge

include("CaveJournal.jl")     # v9: Auto-logging to markdown — before engine/Main so they can use it
using .CaveJournal

include("engine.jl")
include("Main.jl")

# --------------------------------------------------------------------------
# Re-exports for public API
# --------------------------------------------------------------------------
export @coinflip, bias
export cheap_scan, medium_scan, high_res_scan, big_number_small_number_coherence
export NONJITTER_TAG, is_nonjitter, set_nonjitter!, clear_nonjitter!, collect_nonjitter_ids,
       is_time_node
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
export record_fire!, record_vote!, record_orchestration_contribution!
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

# GRUG: MitosisMode exports — idle-time autocatalytic node growth.
# Five warrant sources: silence_map, memory_frequency, thesaurus_gap,
# lobe_coverage, attachment_implication. One bud per cycle, cooldown-gated.
export MitosisMode
export run_mitosis!, MitosisStats, MitosisError, get_mitosis_log
export get_mitosis_status_summary
export MITOSIS_PROBABILITY, MIN_POPULATION_GATE, MAX_POPULATION_CAP
export MITOSIS_COOLDOWN_CYCLES, MIN_WARRANT_THRESHOLD
export GroupLatchCandidate, LatchCandidate, group_avg_strength, find_group_latch_candidates, _scan_latch_candidates, refresh_inhibition_tokens!, is_inhibited
export MITOSIS_PATTERN_SIM_FLOOR, MITOSIS_VOTE_SIM_FLOOR
export LATCH_SCAN_CONFIDENCE_FLOOR, THES_LATCH_WEIGHT, LATCH_CANDIDATE_TOP_N

# GRUG: RelationalGovernance exports — auto-attach from co-activation intensity.
# Hebbian learning at the topology level: nodes that fire together wire together.
# Lazy, conservative, data-driven. Same attachment mechanism as /nodeAttach.
export RelationalGovernance
export observe_co_firing!, run_relational_governance!, RelationalGovStats
export get_relational_gov_status_summary, RelationalGovError
export CO_ACC_MAX_PAIRS, CO_ACC_DECAY_RATE, AUTO_ATTACH_THRESHOLD, AUTO_ATTACH_PROB

# GRUG: InputLedger exports — background thread mining user input for growth data.
# Hash ledger tracks consumed entries. Only fresh data feeds mitosis/relgov.
# 10k records per batch. Runs in its own @async thread. The gut.
export InputLedger
export start_input_ledger_thread!, stop_input_ledger_thread!
export get_input_ledger_status, serialize_input_ledger, deserialize_input_ledger!
export LEDGER_CAP, BATCH_SIZE, MIN_BATCH_THRESHOLD

# GRUG: ChatterResiduals exports — background thread mining chatter swaps for
# relational data. Secondary channel (1.5 increment). The afterimage miner.
export ChatterResiduals
export start_chatter_residuals_thread!, stop_chatter_residuals_thread!
export get_chatter_residuals_status, serialize_chatter_residuals, deserialize_chatter_residuals!
export CHATTER_CO_OCCUR_INCREMENT, RESIDUAL_LEDGER_CAP
export CONFIDENCE_SIMILARITY_FLOOR, CONFIDENCE_SIMILARITY_JITTER_SIGMA
export MARKOV_BLEND_BIAS, MARKOV_MAX_ATTEMPTS, WEIGHT_BLEND_RECEIVER_SHARE

# GRUG: RelationalGovernance direct co-occurrence entry point.
# Used by InputLedger to feed user-input co-occurrence into the accumulator.
export observe_direct_co_occurrence!

# GRUG: front-door promotion side-channel accessors (live in engine.jl,
# re-exported here so callers don't have to know which module owns the
# task-local storage). Stage 1.5a-fix-1 added current_promotion_raw to
# preserve the user's verbatim input alongside the rewritten string.
# v8.1-coherence-fix: added per-group binding accessors for multipart.
export current_promotion_bindings, current_promotion_rewritten, current_promotion_raw
export stash_multipart_bindings!, clear_multipart_bindings!, get_multipart_bindings
export get_multipart_rewritten, get_multipart_raw
export stash_multipart_lobe_state!, clear_multipart_lobe_states!, get_multipart_lobe_state

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

# GRUG v7.29: Vigilance / Context Injector exports
export VigilanceConfig, ContextInjectorAgent, InjectorDisposition
export compute_context_weight, dispatch_vigilance_agents!
export get_vigilance_config, set_vigilance_config!
export get_automaton_max_cap, set_automaton_max_cap!
export vigilance_status, vigilance_status_string
export serialize_vigilance_config, deserialize_vigilance_config!
export serialize_injector_stats, reset_injector_stats!

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

# GRUG: v7.55 — Relation-class sigils for dynamic relational triples.
# A :relation sigil's expansion lists alternative relation verbs. At evaluation
# time, a triple with &name in its relation slot matches any alternative.
export register_relation_sigil!, expand_relation_sigil, is_relation_sigil,
       expand_relation_if_sigil

# GRUG: v7.23 — ATP→automaton escalation hook. `maybe_escalate(prediction)` is
# the primary entry; it checks if the predicted action family is in
# ESCALATION_FAMILIES and confidence is high enough, then runs the matching
# automaton rule. `LAST_ESCALATION_TRACE` stores the trace for downstream
# consumers. Zero cost when no escalation occurs.
export maybe_escalate, ESCALATION_FAMILIES, LAST_ESCALATION_TRACE

# GRUG: v7.24 EphemeralMLP exports — Sigmoid/ReLU MLP + transformer over vote list.
# Primary entry: transform_vote_list(vote_data; hopfield_hit). User rules:
# add_mlp_rule!, drop_mlp_rule!, list_mlp_rules. Feedback: register_right_feedback!,
# register_wrong_feedback!. Serialization: to_specimen_dict, from_specimen_dict!.
export EphemeralMLP
export EphemeralMLPState, MLPWeight, MLPTransformerRule, RuleHashTable
export EphemeralMLPError, EphemeralMLPConfigError, EphemeralMLPRuleError
export EphemeralMLPActivation
export ACTIVATION_SIGMOID, ACTIVATION_RELU
export init_ephemeral_mlp!, reset_ephemeral_mlp!
export transform_vote_list, get_mlp_status
export add_mlp_rule!, drop_mlp_rule!, list_mlp_rules, lookup_mlp_rule
export activate_rule_by_key!, activate_rules_by_pattern!
export to_specimen_dict, from_specimen_dict!
export register_right_feedback!, register_wrong_feedback!
export get_activation_mode, get_novelty_score
export get_strain_energy, is_hippocampal_warrant_active
export STRAIN_NOVELTY_WEIGHT, STRAIN_QUALITY_WEIGHT, STRAIN_THRESHOLD, STRAIN_FLOOR, STRAIN_CEILING
export MLP_TRANSFORM_FUZZY, MLP_TRANSFORM_SOLID

# GRUG v9: GeometryKit exports — state-space geometry over four named spaces.
# Thin wrapper: distance functions, space overview, trajectory, attractors.
# No new algorithms; just names what already exists.
export GeometryKit
export SpaceName, SEMANTIC_SPACE, COHERENCE_SPACE, PHASE_SPACE, TONE_SPACE
export SPACE_NAMES, SPACE_FROM_NAME
export GeometryConfig, GEOMETRY_CONFIG, geometry_config_snapshot
export set_geometry_config!, reset_geometry_config!
export geometry_config_to_dict, geometry_config_from_dict!
export semantic_distance, coherence_distance, phase_distance, tone_distance
export space_distance
export geometry_overview, trajectory, attractors

# GRUG v9: PatternMiner exports — operator genesis from recurring graph shapes.
# Proposal/approval gate: proposals are visible, not auto-registered.
export PatternMiner
export ShapeType, SHAPE_TRANSITIVITY, SHAPE_CHAINING, SHAPE_SYMMETRY
export SHAPE_NAMES
export ShapeInstance, GenesisProposal
export PatternMinerConfig, PATTERN_MINER_CONFIG, pattern_miner_config_snapshot
export set_pattern_miner_config!, reset_pattern_miner_config!
export pattern_miner_config_to_dict, pattern_miner_config_from_dict!
export record_instance!, prune_expired_instances!, count_instances, get_all_instances
export scan_transitivity!, scan_chaining!, scan_symmetry!, scan_all!
export check_and_propose!, list_proposals
export approve_proposal!, reject_proposal!
export clear_instances!, clear_proposals!
export pattern_miner_status

# GRUG v9: TemporalIdentity exports — first-class continuants for identity across change.
# Proposal/approval gate: proposals are visible, not auto-registered.
export TemporalIdentity
export Stage, Continuant, ContinuantProposal
export TemporalIdentityConfig, TEMPORAL_IDENTITY_CONFIG, temporal_identity_config_snapshot
export set_temporal_identity_config!, reset_temporal_identity_config!
export temporal_identity_config_to_dict, temporal_identity_config_from_dict!
export create_continuant, add_stage!, add_transform_rule!, remove_stage!
export identity_of, get_continuant, list_continuants, stages_of
export what_was, what_becomes
export merge_continuants!, delete_continuant!
export propose_continuant!, list_continuant_proposals
export approve_continuant_proposal!, reject_continuant_proposal!
export clear_continuants!, clear_proposals!
export temporal_identity_status
export temporal_identity_to_dict, temporal_identity_from_dict!

# GRUG v8.20: CLI entry-point + specimen lifecycle exports.
# These live in Main.jl (included into this module) but were never exported,
# forcing callers to use `import .GrugBot420: run_cli, ...` with explicit
# naming. Now boot.jl (and end users) can just do `using .GrugBot420`
# and call run_cli(), process_mission(), etc. directly.
export run_cli, process_mission
export load_specimen_from_file!, save_specimen_to_file!
export _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK
export _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE
export _LAST_SPECIMEN_PATH, _LAST_SPECIMEN_PATH_LOCK
export LAST_VOTER_IDS, LAST_VOTER_LOCK
export NODE_MAP, NODE_LOCK
export MESSAGE_HISTORY, MESSAGE_HISTORY_LOCK
export HELP_MSG

end # module GrugBot420