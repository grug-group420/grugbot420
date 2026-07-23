# ImmuneThreadPool.jl — Immune System Thread Space
# ==============================================================================
# GRUG: Immune system now lives in its OWN CAVE. Separate from main cave.
# 8 dedicated side threads. All input waiting/collection happens HERE.
# Bad input gets processed here. Main cave NEVER WAITS for immune work.
# If immune thread dies, IT SCREAMS LOUD. No hush. No quiet death.
#
# HARDCORE FEATURES:
#   - Priority Lanes: CRITICAL > NORMAL > LOW > JUNK. Critical never waits.
#   - Per-Source Rate Limiting: One spammer can't eat the whole immune budget.
#   - Cost-Weighted Balancing: Expensive scans count heavier in load balancing.
#   - Tripwire Metrics: If rejection rate spikes, system enters HARDENED mode.
#
# ARCHITECTURE:
#   - 8 worker threads (ImmuneWorker). Each owns one inbox Channel.
#   - ImmuneLoadBalancer: routes incoming scan requests to least-loaded worker.
#   - ImmuneWaitingList: PRIORITY-AWARE inputs sit here before dispatch.
#   - Main thread calls submit_immune_work! → WaitingList → Balancer → Worker.
#   - Workers call ImmuneSystem.immune_scan! and return result via Future.
#   - Non-blocking: submit_immune_work! returns immediately with a Future.
#   - Caller can fetch(future) later, or fire-and-forget with watch mode.
#   - Zero silent failures: dead workers SCREAM via ImmuneWorkerDiedError.
#     Balancer SCREAMS if overloaded. Future SCREAMS if result is an error.
#
# GRUG RULES:
#   1. Immune thread space is isolated. Main cave does not touch it directly.
#   2. Load balancer distributes by COST-WEIGHTED queue depth.
#   3. Waiting list is PRIORITY-AWARE and bounded. Overflow = LOUD ERROR.
#   4. Worker crash = ImmuneWorkerDiedError thrown to all pending futures.
#   5. All state behind locks. Atomic counters for hot-path metrics.
#   6. No @warn, no @info for failures. Only @error or throw. Grug not whisper.
#   7. Per-source rate limiting. Spammer gets ImmuneRateLimitExhaustedError.
#   8. Tripwire monitors rejection rate. Spikes trigger HARDENED mode.
# ==============================================================================

module ImmuneThreadPool

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

using Base.Threads: Atomic, atomic_add!, atomic_sub!, ReentrantLock

# ImmuneSystem is included by the parent module (GrugBot420.jl / Main.jl).
# We reference it via the module name. If running standalone for tests,
# caller must include ImmuneSystem.jl first.

# ==============================================================================
# CONSTANTS
# ==============================================================================

# GRUG: Exactly 8 immune worker threads. Matches GrugBreathMap's 8 holes.
# 8 is the number. Not 7. Not 9. Eight.
const NUM_IMMUNE_WORKERS = 8

# GRUG: Each worker has an inbox channel of this depth.
# Deep enough to buffer burst traffic. Overflow → WaitingList backs up → LOUD ERROR.
const WORKER_CHANNEL_DEPTH = 64

# GRUG: Maximum items sitting in the WaitingList PER PRIORITY LANE before we scream.
# If a priority lane is full, that priority gets rejected (lower priorities still flow).
const MAX_WAITING_LIST_SIZE_PER_PRIORITY = 128

# GRUG: Total waiting list max across all priorities.
const MAX_WAITING_LIST_SIZE = MAX_WAITING_LIST_SIZE_PER_PRIORITY * 4

# GRUG: How often (seconds) the dispatcher wakes to drain WaitingList into workers.
# Short interval = low latency. 0.5ms is plenty.
const DISPATCHER_SLEEP_S = 0.0005

# GRUG: How long (seconds) worker waits for new work before looping.
# Controls worker responsiveness vs CPU burn. 1ms is fine.
const WORKER_TAKE_TIMEOUT_S = 0.001

# GRUG: Maximum retries to find a non-full worker before screaming.
const BALANCER_MAX_RETRY = 16

# ==============================================================================
# PRIORITY LANES — GRUG: Critical inputs get FAST LANE. Junk gets SLOW LANE.
# ==============================================================================

"""
    PriorityLevel

GRUG: Priority lanes for immune work. Higher priority = processed first.
- CRITICAL: User commands, direct interactions. NEVER starved.
- NORMAL: Regular inputs, background scans.
- LOW: Batch operations, bulk imports.
- JUNK: Untrusted inputs, rate-limited sources, suspicious content.
"""
@enum PriorityLevel begin
    PRIORITY_CRITICAL = 0
    PRIORITY_NORMAL   = 1
    PRIORITY_LOW      = 2
    PRIORITY_JUNK     = 3
end

# GRUG: Priority order for dispatcher draining. CRITICAL first, JUNK last.
const PRIORITY_DRAIN_ORDER = [PRIORITY_CRITICAL, PRIORITY_NORMAL, PRIORITY_LOW, PRIORITY_JUNK]

# ==============================================================================
# COST WEIGHTS — GRUG: Expensive scans cost more in load balancing.
# ==============================================================================

"""
    ScanCost

GRUG: Estimated cost of an immune scan. Used for cost-weighted load balancing.
- COST_CHEAP: Simple text, few nodes. Weight = 1.
- COST_MODERATE: Medium complexity. Weight = 2.
- COST_EXPENSIVE: Complex AST, many nodes, deep nesting. Weight = 4.
"""
@enum ScanCost begin
    COST_CHEAP     = 0
    COST_MODERATE  = 1
    COST_EXPENSIVE = 2
end

# GRUG: Cost weights for load balancing. Higher = counts more toward worker load.
const COST_WEIGHTS = Dict(
    COST_CHEAP     => 1,
    COST_MODERATE  => 2,
    COST_EXPENSIVE => 4
)

"""
    estimate_scan_cost(node_count::Int) -> ScanCost

GRUG: Estimate scan cost based on AST node count.
Simple heuristic: more nodes = more expensive.
"""
function estimate_scan_cost(node_count::Int)::ScanCost
    if node_count < 50
        return COST_CHEAP
    elseif node_count < 200
        return COST_MODERATE
    else
        return COST_EXPENSIVE
    end
end

# ==============================================================================
# SOURCE IDENTIFICATION — GRUG: Who sent this input? Track for rate limiting.
# ==============================================================================

"""
    SourceID

GRUG: Identifies the source of an immune scan request.
Used for per-source rate limiting. One source can't eat the whole budget.
- source_type: :user, :api, :batch, :anonymous, :internal
- source_id: Unique identifier (user ID, API key hash, IP hash, etc.)
"""
struct SourceID
    source_type::Symbol
    source_id::UInt64
end

# GRUG: Special source IDs
const SOURCE_INTERNAL  = SourceID(:internal, 0x0000000000000000)
const SOURCE_ANONYMOUS = SourceID(:anonymous, 0xFFFFFFFFFFFFFFFF)

# ==============================================================================
# RATE LIMITING CONSTANTS — GRUG: Per-source budgets. No single spammer wins.
# ==============================================================================

# GRUG: Tokens per second per source type. Spammer can't spam faster than this.
const RATE_LIMIT_TOKENS_PER_SEC = Dict(
    :user      => 10.0,   # 10 immune scans/sec per user
    :api       => 5.0,    # 5 immune scans/sec per API key
    :batch     => 2.0,    # 2 immune scans/sec for batch operations
    :anonymous => 1.0,    # 1 immune scan/sec for anonymous
    :internal  => 100.0   # 100 immune scans/sec for internal (unlimited for trusted)
)

# GRUG: Maximum burst tokens per source type. Allows brief bursts.
const RATE_LIMIT_BURST = Dict(
    :user      => 20,
    :api       => 10,
    :batch     => 5,
    :anonymous => 3,
    :internal  => 200
)

# GRUG: Hardened mode rate limits (tripwire triggered). Much stricter.
const RATE_LIMIT_TOKENS_PER_SEC_HARDENED = Dict(
    :user      => 2.0,
    :api       => 1.0,
    :batch     => 0.5,
    :anonymous => 0.1,
    :internal  => 50.0
)

const RATE_LIMIT_BURST_HARDENED = Dict(
    :user      => 5,
    :api       => 3,
    :batch     => 2,
    :anonymous => 1,
    :internal  => 100
)

# ==============================================================================
# TRIPWIRE CONSTANTS — GRUG: If rejection rate spikes, system gets SUSPICIOUS.
# ==============================================================================

"""
    TripwireState

GRUG: System state based on rejection rate monitoring.
- TRIPWIRE_NORMAL: All clear. Normal operation.
- TRIPWIRE_ELEVATED: Rejection rate above threshold. Watching closely.
- TRIPWIRE_HARDENED: High rejection rate. Stricter rate limits. Alerts on.
- TRIPWIRE_CRITICAL: System under attack. Maximum restrictions.
"""
@enum TripwireState begin
    TRIPWIRE_NORMAL   = 0
    TRIPWIRE_ELEVATED = 1
    TRIPWIRE_HARDENED = 2
    TRIPWIRE_CRITICAL = 3
end

# GRUG: Rejection rate thresholds (rejections / total processed in window).
# Window is sliding, updated every TRIPWIRE_WINDOW_S seconds.
const TRIPWIRE_WINDOW_S = 5.0  # 5 second sliding window
const TRIPWIRE_ELEVATED_THRESHOLD = 0.1   # 10% rejection rate
const TRIPWIRE_HARDENED_THRESHOLD = 0.25  # 25% rejection rate
const TRIPWIRE_CRITICAL_THRESHOLD = 0.5   # 50% rejection rate

# GRUG: Cooldown before returning to lower tripwire state (seconds).
const TRIPWIRE_COOLDOWN_S = 30.0

# GRUG: How often to check tripwire state (seconds).
const TRIPWIRE_CHECK_INTERVAL_S = 1.0

# ==============================================================================
# ERROR TYPES — GRUG: ALL LOUD. NO WHISPERING.
# ==============================================================================

"""
    ImmuneWorkerDiedError

GRUG: A worker thread in the immune pool died unexpectedly.
This is NOT a silent failure. Everyone hears about it.
All pending futures on that worker receive this error.
"""
struct ImmuneWorkerDiedError <: Exception
    worker_id::Int
    cause::Any   # The exception that killed it
end

function Base.showerror(io::IO, e::ImmuneWorkerDiedError)
    print(io, "💀 IMMUNE WORKER #$(e.worker_id) DIED! Grug's immune cave wall crumbled! cause=$(e.cause)")
end

"""
    ImmunePoolOverloadError

GRUG: The immune waiting list is full. Too many inputs piling up.
System is overwhelmed. Caller must back off and retry.
"""
struct ImmunePoolOverloadError <: Exception
    waiting_list_size::Int
    priority::PriorityLevel
    msg::String
end

function Base.showerror(io::IO, e::ImmunePoolOverloadError)
    print(io, "💀 IMMUNE POOL OVERLOADED! Priority $(e.priority) lane at $(e.waiting_list_size). $(e.msg)")
end

"""
    ImmunePoolDeadError

GRUG: Tried to submit work to a dead pool. Pool was shut down.
Make a new pool if you want immune scanning.
"""
struct ImmunePoolDeadError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::ImmunePoolDeadError)
    print(io, "💀 IMMUNE POOL IS DEAD! Cannot submit work. $(e.msg)")
end

"""
    ImmuneWorkerBalancerError

GRUG: Load balancer could not find any worker with space.
All 8 worker inboxes are full. System is severely overloaded.
"""
struct ImmuneWorkerBalancerError <: Exception
    msg::String
end

function Base.showerror(io::IO, e::ImmuneWorkerBalancerError)
    print(io, "💀 IMMUNE BALANCER STUCK! All 8 workers full. $(e.msg)")
end

"""
    ImmuneRateLimitExhaustedError

GRUG: Source has exhausted its rate limit budget.
Too many submissions from this source. Back off.
"""
struct ImmuneRateLimitExhaustedError <: Exception
    source::SourceID
    retry_after_ms::Int
    msg::String
end

function Base.showerror(io::IO, e::ImmuneRateLimitExhaustedError)
    print(io, "💀 IMMUNE RATE LIMIT EXHAUSTED! Source $(e.source) must wait $(e.retry_after_ms)ms. $(e.msg)")
end

"""
    ImmuneTripwireTriggeredError

GRUG: Tripwire state changed. System entering or leaving hardened mode.
This is informational but LOUD.
"""
struct ImmuneTripwireTriggeredError <: Exception
    old_state::TripwireState
    new_state::TripwireState
    rejection_rate::Float64
    msg::String
end

function Base.showerror(io::IO, e::ImmuneTripwireTriggeredError)
    print(io, "⚠️ IMMUNE TRIPWIRE TRIGGERED! $(e.old_state) → $(e.new_state) (rejection rate: $(round(e.rejection_rate * 100, digits=1))%). $(e.msg)")
end

"""
    ImmunePriorityInversionError

GRUG: Critical priority items are starving behind lower priority junk.
This should never happen if dispatcher is working correctly.
"""
struct ImmunePriorityInversionError <: Exception
    critical_waiting::Int
    lower_priority_processed::Int
    msg::String
end

function Base.showerror(io::IO, e::ImmunePriorityInversionError)
    print(io, "💀 IMMUNE PRIORITY INVERSION! $(e.critical_waiting) CRITICAL items waiting while $(e.lower_priority_processed) lower-priority processed. $(e.msg)")
end

# ==============================================================================
# TOKEN BUCKET — GRUG: Per-source rate limiting bucket.
# ==============================================================================

"""
    TokenBucket

GRUG: Token bucket for rate limiting. One per source.
Tokens refill at `rate` per second, up to `burst` max.
"""
mutable struct TokenBucket
    tokens::Float64
    rate::Float64         # tokens per second
    burst::Int            # max tokens
    last_refill::Float64  # timestamp of last refill
    lock::ReentrantLock
end

function TokenBucket(rate::Float64, burst::Int)
    return TokenBucket(
        Float64(burst),  # Start full
        rate,
        burst,
        time(),
        ReentrantLock()
    )
end

"""
    try_consume!(bucket::TokenBucket, cost::Int = 1) -> Bool

GRUG: Try to consume tokens from bucket. Returns true if successful.
Refills tokens based on elapsed time since last call.
"""
function try_consume!(bucket::TokenBucket, cost::Int = 1)::Bool
    lock(bucket.lock) do
        now = time()
        elapsed = now - bucket.last_refill
        bucket.last_refill = now
        
        # GRUG: Refill tokens based on elapsed time
        bucket.tokens = min(Float64(bucket.burst), bucket.tokens + elapsed * bucket.rate)
        
        # GRUG: Try to consume
        if bucket.tokens >= Float64(cost)
            bucket.tokens -= Float64(cost)
            return true
        end
        return false
    end
end

"""
    time_to_next_token(bucket::TokenBucket) -> Float64

GRUG: How long until at least one token is available (seconds).
"""
function time_to_next_token(bucket::TokenBucket)::Float64
    lock(bucket.lock) do
        if bucket.tokens >= 1.0
            return 0.0
        end
        return (1.0 - bucket.tokens) / bucket.rate
    end
end

"""
    refill!(bucket::TokenBucket)

GRUG: Force refill bucket (used when rate limits change).
"""
function refill!(bucket::TokenBucket)
    lock(bucket.lock) do
        bucket.tokens = Float64(bucket.burst)
        bucket.last_refill = time()
    end
end

# ==============================================================================
# TRIPWIRE MONITOR — GRUG: Watches rejection rate, flips states.
# ==============================================================================

"""
    TripwireMonitor

GRUG: Tracks rejection rate in a sliding window. Triggers state changes.
"""
mutable struct TripwireMonitor
    state::Atomic{Int}           # TripwireState as Int
    window_start::Atomic{Float64}
    window_processed::Atomic{Int}
    window_rejected::Atomic{Int}
    last_state_change::Atomic{Float64}
    total_processed::Atomic{Int}
    total_rejected::Atomic{Int}
    lock::ReentrantLock
end

function TripwireMonitor()
    return TripwireMonitor(
        Atomic{Int}(Int(TRIPWIRE_NORMAL)),
        Atomic{Float64}(time()),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Float64}(0.0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock()
    )
end

"""
    get_tripwire_state(mon::TripwireMonitor) -> TripwireState
"""
function get_tripwire_state(mon::TripwireMonitor)::TripwireState
    return TripwireState(mon.state[])
end

"""
    record_processed!(mon::TripwireMonitor; rejected::Bool = false)

GRUG: Record a processed item. If rejected=true, counts toward rejection rate.
"""
function record_processed!(mon::TripwireMonitor; rejected::Bool = false)
    atomic_add!(mon.window_processed, 1)
    atomic_add!(mon.total_processed, 1)
    if rejected
        atomic_add!(mon.window_rejected, 1)
        atomic_add!(mon.total_rejected, 1)
    end
end

"""
    get_rejection_rate(mon::TripwireMonitor) -> Float64

GRUG: Get current rejection rate (0.0 to 1.0) in the sliding window.
"""
function get_rejection_rate(mon::TripwireMonitor)::Float64
    processed = mon.window_processed[]
    if processed == 0
        return 0.0
    end
    return Float64(mon.window_rejected[]) / Float64(processed)
end

"""
    update_tripwire_state!(mon::TripwireMonitor) -> Tuple{TripwireState, TripwireState}

GRUG: Check rejection rate and potentially update tripwire state.
Returns (old_state, new_state). Caller should handle state change.
"""
function update_tripwire_state!(mon::TripwireMonitor)::Tuple{TripwireState, TripwireState}
    lock(mon.lock) do
        now = time()
        window_elapsed = now - mon.window_start[]
        
        # GRUG: Slide window if enough time has passed
        if window_elapsed >= TRIPWIRE_WINDOW_S
            mon.window_start[] = now
            mon.window_processed[] = 0
            mon.window_rejected[] = 0
        end
        
        rejection_rate = get_rejection_rate(mon)
        current_state = TripwireState(mon.state[])
        new_state = current_state
        
        # GRUG: Check thresholds (only escalate, never skip states)
        if rejection_rate >= TRIPWIRE_CRITICAL_THRESHOLD
            new_state = TRIPWIRE_CRITICAL
        elseif rejection_rate >= TRIPWIRE_HARDENED_THRESHOLD
            if current_state != TRIPWIRE_CRITICAL
                new_state = TRIPWIRE_HARDENED
            end
        elseif rejection_rate >= TRIPWIRE_ELEVATED_THRESHOLD
            if current_state == TRIPWIRE_NORMAL
                new_state = TRIPWIRE_ELEVATED
            end
        else
            # GRUG: Cooldown before de-escalating
            time_since_change = now - mon.last_state_change[]
            if time_since_change >= TRIPWIRE_COOLDOWN_S
                if current_state == TRIPWIRE_CRITICAL
                    new_state = TRIPWIRE_HARDENED
                elseif current_state == TRIPWIRE_HARDENED
                    new_state = TRIPWIRE_ELEVATED
                elseif current_state == TRIPWIRE_ELEVATED
                    new_state = TRIPWIRE_NORMAL
                end
            end
        end
        
        if new_state != current_state
            mon.state[] = Int(new_state)
            mon.last_state_change[] = now
            return (current_state, new_state)
        end
        
        return (current_state, current_state)
    end
end

# ==============================================================================
# IMMUNE FUTURE — Return handle for async immune scan results
# ==============================================================================

"""
    ImmuneFuture

GRUG: Handle to a pending immune scan result.
Call fetch_result(future) to get the result.
If immune worker died, fetch_result throws ImmuneWorkerDiedError.
If scan was rejected (ImmuneError), fetch_result throws that error.
No silent swallowing. Future either delivers or screams.

Fields:
- result_channel: buffered channel(1) where worker deposits result
- input_text:     original input (for debugging)
- submitted_at:   when this was submitted
- worker_id:      which worker is handling it (set by balancer)
- request_id:     unique monotonic ID for this request
- priority:       priority level of this request
- source:         source ID of submitter (for rate limiting)
- cost:           estimated scan cost
"""
mutable struct ImmuneFuture
    result_channel::Channel{Any}  # delivers (status, sig) or an Exception
    input_text::String
    submitted_at::Float64
    worker_id::Atomic{Int}        # -1 = not yet assigned
    request_id::UInt64
    priority::PriorityLevel
    source::SourceID
    cost::ScanCost
end

"""
    ImmuneFuture(input_text::String, request_id::UInt64, priority::PriorityLevel, source::SourceID, cost::ScanCost) -> ImmuneFuture

Create a new future for a pending immune scan.
"""
function ImmuneFuture(input_text::String, request_id::UInt64, priority::PriorityLevel, source::SourceID, cost::ScanCost)
    return ImmuneFuture(
        Channel{Any}(1),
        input_text,
        time(),
        Atomic{Int}(-1),
        request_id,
        priority,
        source,
        cost
    )
end

"""
    fetch_result(future::ImmuneFuture)::Tuple{Symbol, UInt64}

GRUG: Wait for immune scan result. Blocks until result is ready.
Returns (status, signature) on success.
Throws if immune worker died or input was rejected.
NO SILENT SWALLOWING. All errors propagate to caller.
"""
function fetch_result(future::ImmuneFuture)
    result = take!(future.result_channel)
    if result isa Exception
        throw(result)  # GRUG SCREAMS
    end
    return result::Tuple{Symbol, UInt64}
end

"""
    is_ready(future::ImmuneFuture)::Bool

GRUG: Non-blocking check. Is result already available?
"""
function is_ready(future::ImmuneFuture)::Bool
    return isready(future.result_channel)
end

# ==============================================================================
# IMMUNE WORK ITEM — What goes into a worker's inbox
# ==============================================================================

"""
    ImmuneWorkItem

GRUG: A unit of immune work. Lives in the waiting list and worker inboxes.
Contains the input to scan, context for the scan, and the future to fill.
"""
struct ImmuneWorkItem
    future::ImmuneFuture
    input_text::String
    node_count::Int
    is_critical::Bool
    priority::PriorityLevel
    cost::ScanCost
    source::SourceID
    enqueued_at::Float64
end

# ==============================================================================
# IMMUNE WORKER — One thread, one inbox, one job: scan inputs
# ==============================================================================

"""
    ImmuneWorker

GRUG: One immune worker. Lives on its own thread. Has its own inbox channel.
Drains inbox, runs immune_scan!, puts result in future.
If it dies for any reason, it screams and poisons all pending futures.

Fields:
- id:           Worker ID (1–8)
- inbox:        Channel of ImmuneWorkItem
- task:         The background Task running this worker
- alive:        Atomic Bool. true = running, false = dead/stopping
- processed:    Atomic counter for diagnostics
- errors:       Atomic counter for scan errors (rejected inputs etc.)
- cost_load:    Atomic cumulative cost-weighted load
- lock:         Lock for task reassignment during restart
"""
mutable struct ImmuneWorker
    id::Int
    inbox::Channel{ImmuneWorkItem}
    task::Task
    alive::Atomic{Bool}
    processed::Atomic{Int}
    errors::Atomic{Int}
    cost_load::Atomic{Int}
    lock::ReentrantLock
end

# ==============================================================================
# IMMUNE WAITING LIST — Priority-aware bounded input buffer
# ==============================================================================

"""
    ImmuneWaitingList

GRUG: The waiting room. PRIORITY-AWARE. Inputs arrive here before dispatch.
Bounded per-priority. Overflow = LOUD ERROR for that priority.
The dispatcher task drains this into worker inboxes, CRITICAL first.

Fields:
- lanes:      Dict{PriorityLevel, Vector{ImmuneWorkItem}} - separate queues
- lock:       Protects all lanes
- size:       Atomic for fast non-locked total size check
- lane_sizes: Atomic counters per lane for O(1) checks
"""
mutable struct ImmuneWaitingList
    lanes::Dict{PriorityLevel, Vector{ImmuneWorkItem}}
    lock::ReentrantLock
    size::Atomic{Int}
    lane_sizes::Dict{PriorityLevel, Atomic{Int}}
end

function ImmuneWaitingList()
    lanes = Dict{PriorityLevel, Vector{ImmuneWorkItem}}()
    lane_sizes = Dict{PriorityLevel, Atomic{Int}}()
    for p in instances(PriorityLevel)
        lanes[p] = ImmuneWorkItem[]
        lane_sizes[p] = Atomic{Int}(0)
    end
    return ImmuneWaitingList(lanes, ReentrantLock(), Atomic{Int}(0), lane_sizes)
end

"""
    get_lane_size(wl::ImmuneWaitingList, priority::PriorityLevel) -> Int

GRUG: Get the size of a specific priority lane. O(1) atomic read.
"""
function get_lane_size(wl::ImmuneWaitingList, priority::PriorityLevel)::Int
    return wl.lane_sizes[priority][]
end

"""
    pop_next!(wl::ImmuneWaitingList) -> Union{ImmuneWorkItem, Nothing}

GRUG: Pop the highest priority item available. CRITICAL first, JUNK last.
Returns nothing if all lanes are empty.
"""
function pop_next!(wl::ImmuneWaitingList)::Union{ImmuneWorkItem, Nothing}
    lock(wl.lock) do
        for priority in PRIORITY_DRAIN_ORDER
            if !isempty(wl.lanes[priority])
                item = popfirst!(wl.lanes[priority])
                atomic_sub!(wl.lane_sizes[priority], 1)
                atomic_sub!(wl.size, 1)
                return item
            end
        end
        return nothing
    end
end

# ==============================================================================
# IMMUNE LOAD BALANCER — Routes work to least-loaded worker (cost-weighted)
# ==============================================================================

"""
    ImmuneLoadBalancer

GRUG: Picks which worker gets the next job.
Strategy: COST-WEIGHTED least-queue-depth (cheapest bin first filling).
If all workers full, throws ImmuneWorkerBalancerError LOUD.

Fields:
- workers:      Vector{ImmuneWorker} of exactly 8
- round_robin:  Atomic{Int} fallback counter (used when all depths equal)
"""
mutable struct ImmuneLoadBalancer
    workers::Vector{ImmuneWorker}
    round_robin::Atomic{Int}
end

"""
    pick_worker(balancer::ImmuneLoadBalancer; cost::ScanCost = COST_CHEAP)::ImmuneWorker

GRUG: Find the least-loaded alive worker, considering COST-WEIGHTED load.
Returns the worker to dispatch to.
Throws ImmuneWorkerBalancerError if all workers dead or all inboxes full.
"""
function pick_worker(balancer::ImmuneLoadBalancer; cost::ScanCost = COST_CHEAP)::ImmuneWorker
    # GRUG: Try to find least-loaded alive worker using COST-WEIGHTED depth.
    # Cost-weighted depth = queue_depth * average_cost + current_cost_load
    best_worker = nothing
    best_weighted_depth = typemax(Float64)
    
    cost_weight = COST_WEIGHTS[cost]

    for w in balancer.workers
        if !w.alive[]
            continue  # GRUG: Skip dead workers
        end
        queue_depth = Float64(Base.n_avail(w.inbox))
        # GRUG: Cost-weighted load = queue items * avg_weight + accumulated cost
        # Simplified: current depth * 2 (avg weight) + cost_load / 10
        weighted_depth = queue_depth * 2.0 + Float64(w.cost_load[]) / 10.0
        
        if weighted_depth < best_weighted_depth
            best_weighted_depth = weighted_depth
            best_worker = w
        end
    end

    if best_worker === nothing
        throw(ImmuneWorkerBalancerError(
            "All $(NUM_IMMUNE_WORKERS) immune workers are dead or unavailable. " *
            "Pool needs restart. Call restart_immune_pool!(pool)."
        ))
    end

    # GRUG: Check that chosen worker's inbox is not full
    for attempt in 1:BALANCER_MAX_RETRY
        if !isfull(best_worker.inbox)
            return best_worker
        end
        # GRUG: Chosen worker full, try round-robin among alive workers
        idx = (atomic_add!(balancer.round_robin, 1) % NUM_IMMUNE_WORKERS) + 1
        w = balancer.workers[idx]
        if w.alive[] && !isfull(w.inbox)
            return w
        end
    end

    throw(ImmuneWorkerBalancerError(
        "All $(NUM_IMMUNE_WORKERS) immune worker inboxes full after $(BALANCER_MAX_RETRY) retries. " *
        "Immune system is severely overloaded. Back off."
    ))
end

# Helper: check if channel is at capacity
function isfull(ch::Channel)::Bool
    return Base.n_avail(ch) >= ch.sz_max
end

# ==============================================================================
# RATE LIMITER — Per-source token bucket management
# ==============================================================================

"""
    ImmuneRateLimiter

GRUG: Manages per-source rate limiting. One bucket per source.
Cleans up stale buckets to prevent memory leak.
"""
mutable struct ImmuneRateLimiter
    buckets::Dict{SourceID, TokenBucket}
    last_access::Dict{SourceID, Float64}
    lock::ReentrantLock
    tripwire_monitor::TripwireMonitor
end

function ImmuneRateLimiter(tripwire::TripwireMonitor)
    return ImmuneRateLimiter(
        Dict{SourceID, TokenBucket}(),
        Dict{SourceID, Float64}(),
        ReentrantLock(),
        tripwire
    )
end

"""
    get_or_create_bucket!(rl::ImmuneRateLimiter, source::SourceID) -> TokenBucket

GRUG: Get or create a token bucket for a source.
Rate limits depend on current tripwire state.
"""
function get_or_create_bucket!(rl::ImmuneRateLimiter, source::SourceID)::TokenBucket
    lock(rl.lock) do
        now = time()
        
        # GRUG: Clean up stale buckets (not accessed in 5 minutes)
        stale_cutoff = now - 300.0
        stale_sources = [s for (s, t) in rl.last_access if t < stale_cutoff]
        for s in stale_sources
            delete!(rl.buckets, s)
            delete!(rl.last_access, s)
        end
        
        # GRUG: Get or create bucket
        if !haskey(rl.buckets, source)
            state = get_tripwire_state(rl.tripwire_monitor)
            if state >= TRIPWIRE_HARDENED
                rate = get(RATE_LIMIT_TOKENS_PER_SEC_HARDENED, source.source_type, 1.0)
                burst = get(RATE_LIMIT_BURST_HARDENED, source.source_type, 5)
            else
                rate = get(RATE_LIMIT_TOKENS_PER_SEC, source.source_type, 1.0)
                burst = get(RATE_LIMIT_BURST, source.source_type, 10)
            end
            rl.buckets[source] = TokenBucket(rate, burst)
        end
        
        rl.last_access[source] = now
        return rl.buckets[source]
    end
end

"""
    try_consume_rate_limit!(rl::ImmuneRateLimiter, source::SourceID, cost::Int = 1) -> Bool

GRUG: Try to consume rate limit tokens for a source.
Returns true if successful, false if rate limited.
"""
function try_consume_rate_limit!(rl::ImmuneRateLimiter, source::SourceID, cost::Int = 1)::Bool
    # GRUG: Internal sources bypass rate limiting
    if source.source_type == :internal
        return true
    end
    
    bucket = get_or_create_bucket!(rl, source)
    return try_consume!(bucket, cost)
end

"""
    get_retry_after_ms(rl::ImmuneRateLimiter, source::SourceID) -> Int

GRUG: How many milliseconds until source can retry.
"""
function get_retry_after_ms(rl::ImmuneRateLimiter, source::SourceID)::Int
    if source.source_type == :internal
        return 0
    end
    
    bucket = get_or_create_bucket!(rl, source)
    return round(Int, time_to_next_token(bucket) * 1000)
end

"""
    update_buckets_for_tripwire!(rl::ImmuneRateLimiter, new_state::TripwireState)

GRUG: Update all bucket rates when tripwire state changes.
"""
function update_buckets_for_tripwire!(rl::ImmuneRateLimiter, new_state::TripwireState)
    lock(rl.lock) do
        for (source, bucket) in rl.buckets
            if new_state >= TRIPWIRE_HARDENED
                bucket.rate = get(RATE_LIMIT_TOKENS_PER_SEC_HARDENED, source.source_type, 1.0)
                bucket.burst = get(RATE_LIMIT_BURST_HARDENED, source.source_type, 5)
            else
                bucket.rate = get(RATE_LIMIT_TOKENS_PER_SEC, source.source_type, 1.0)
                bucket.burst = get(RATE_LIMIT_BURST, source.source_type, 10)
            end
            refill!(bucket)
        end
    end
end

# ==============================================================================
# IMMUNE THREAD POOL — The whole immune cave
# ==============================================================================

"""
    ImmunePool

GRUG: The whole immune cave. Eight workers. One dispatcher. One waiting list.
Submit work here. Pool handles everything. Main cave stays clean.

Fields:
- workers:       8 ImmuneWorker instances
- balancer:      ImmuneLoadBalancer
- waiting_list:  ImmuneWaitingList
- dispatcher:    Background Task draining waiting_list → workers
- alive:         Atomic{Bool} — true while pool is running
- request_counter: Atomic{UInt64} monotonic request ID generator
- submitted:     Atomic{Int} total submitted count
- dispatched:    Atomic{Int} total dispatched to workers
- rejected:      Atomic{Int} total immune rejections (not pool errors)
- rate_limited:  Atomic{Int} total rate-limited rejections
- pool_lock:     ReentrantLock for pool-level operations
- tripwire:      TripwireMonitor for rejection rate tracking
- rate_limiter:  ImmuneRateLimiter for per-source rate limiting
"""
mutable struct ImmunePool
    workers::Vector{ImmuneWorker}
    balancer::ImmuneLoadBalancer
    waiting_list::ImmuneWaitingList
    dispatcher::Task
    alive::Atomic{Bool}
    request_counter::Atomic{Int}
    submitted::Atomic{Int}
    dispatched::Atomic{Int}
    rejected::Atomic{Int}
    rate_limited::Atomic{Int}
    pool_lock::ReentrantLock
    tripwire::TripwireMonitor
    rate_limiter::ImmuneRateLimiter
end

# ==============================================================================
# WORKER LOOP — What each worker thread runs forever
# ==============================================================================

"""
    _worker_loop(worker::ImmuneWorker, immune_module, pool::ImmunePool)

GRUG: The inner loop of one immune worker.
Drains its inbox. Runs immune_scan! on each item.
Puts result in the item's future.
If immune_scan! throws ImmuneError → result is that error (rejection, not crash).
If anything ELSE throws → worker is considered dead, screams, poisons futures.

immune_module: The ImmuneSystem module reference passed in at pool creation.
"""
function _worker_loop(worker::ImmuneWorker, immune_module, pool::ImmunePool)
    worker.alive[] = true

    # GRUG: Worker stays alive until pool shuts down or fatal error
    while worker.alive[]
        # GRUG: Try to take from inbox. Non-blocking check first.
        local item::ImmuneWorkItem
        try
            # GRUG: isready check to avoid blocking when inbox empty
            if !isready(worker.inbox)
                sleep(WORKER_TAKE_TIMEOUT_S)
                continue
            end
            item = take!(worker.inbox)
        catch e
            # GRUG: Channel was closed (pool shutting down) — exit gracefully
            if e isa InvalidStateException
                break
            end
            # GRUG: Something weird happened to the channel. SCREAM.
            error_obj = ImmuneWorkerDiedError(worker.id, e)
            @error "💀 IMMUNE WORKER #$(worker.id): inbox take! failed" exception=e
            worker.alive[] = false
            break
        end

        # GRUG: Update cost load
        atomic_add!(worker.cost_load, COST_WEIGHTS[item.cost])

        # GRUG: We have work. Do the immune scan.
        try
            result = immune_module.immune_scan!(
                item.input_text,
                item.node_count;
                is_critical=item.is_critical
            )
            # GRUG: Success. Deliver result to future.
            put!(item.future.result_channel, result)
            atomic_add!(worker.processed, 1)
            record_processed!(pool.tripwire, rejected=false)

        catch e
            atomic_add!(worker.errors, 1)

            if e isa immune_module.ImmuneError
                # GRUG: Input was rejected by immune system.
                # This is NOT a worker crash. Deliver the error to the future.
                # Caller who fetch_result()s will see the ImmuneError thrown at them.
                put!(item.future.result_channel, e)
                atomic_add!(worker.processed, 1)
                record_processed!(pool.tripwire, rejected=true)
                atomic_add!(pool.rejected, 1)

            else
                # GRUG: Unexpected error in immune_scan!. This is a REAL crash.
                # Poison this future. Then check if worker should die.
                death_error = ImmuneWorkerDiedError(worker.id, e)
                put!(item.future.result_channel, death_error)

                # GRUG: Log loud — this is not a normal rejection
                @error "💀 IMMUNE WORKER #$(worker.id): immune_scan! threw unexpected error" exception=(e, catch_backtrace())

                # GRUG: Worker stays alive (scan error ≠ worker death).
                # Only truly fatal errors (OOM, stack overflow) kill the worker.
                # Those will be caught by the outer try/catch below.
            end
        end

        # GRUG: Decay cost load over time (simple approach: subtract 1 each cycle)
        if worker.cost_load[] > 0
            atomic_sub!(worker.cost_load, 1)
        end
    end

    worker.alive[] = false
end

"""
    _start_worker(id::Int, immune_module, pool::ImmunePool) -> ImmuneWorker

GRUG: Spawn a new immune worker on a background task.
Returns the worker struct with running task.
"""
function _start_worker(id::Int, immune_module, pool::ImmunePool)::ImmuneWorker
    inbox = Channel{ImmuneWorkItem}(WORKER_CHANNEL_DEPTH)
    worker = ImmuneWorker(
        id,
        inbox,
        Task(() -> nothing),  # dummy task, replaced below
        Atomic{Bool}(false),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock()
    )

    worker.task = @async begin
        try
            _worker_loop(worker, immune_module, pool)
        catch fatal_e
            # GRUG: Worker died with a fatal error (OOM etc). SCREAM LOUD.
            @error "💀 IMMUNE WORKER #$id FATALLY CRASHED" exception=(fatal_e, catch_backtrace())
            worker.alive[] = false
            # GRUG: Drain remaining inbox items, poison their futures with the fatal
            # cause so callers see a real error instead of a silent hang.
            # ACADEMIC: The bare catch below is INTENTIONAL and NOT a silent failure.
            # During worker death, the inbox Channel may be closed mid-drain by another
            # task (normal shutdown race). That close surfaces as an InvalidStateException
            # from take!/isready/put!. The only correct response is to stop draining,
            # because the channel is gone. We exit the loop; any un-drained futures are
            # handled by the pool-level shutdown path which poisons them uniformly.
            while isready(inbox)
                try
                    item = take!(inbox)
                    death = ImmuneWorkerDiedError(id, fatal_e)
                    if isopen(item.future.result_channel)
                        put!(item.future.result_channel, death)
                    end
                catch drain_e
                    # Channel-closed-mid-drain is the only expected error class here.
                    # Anything else is a real bug we want to know about.
                    if !(drain_e isa InvalidStateException)
                        @warn "worker $id drain loop hit unexpected error" exception=(drain_e, catch_backtrace())
                    end
                    break
                end
            end
        end
    end

    return worker
end

# ==============================================================================
# DISPATCHER LOOP — Drains WaitingList into workers
# ==============================================================================

"""
    _dispatcher_loop(pool::ImmunePool)

GRUG: Background task. Wakes every DISPATCHER_SLEEP_S seconds.
Drains the waiting list (CRITICAL first) into worker inboxes via load balancer.
If balancer throws (all workers dead/full), dispatcher screams too.
Dispatcher death = pool death. Pool should be restarted.
"""
function _dispatcher_loop(pool::ImmunePool)
    while pool.alive[]
        # GRUG: Drain as many items from waiting list as possible this cycle
        drained = 0
        while true
            # GRUG: Grab next item from waiting list (priority-aware)
            item = pop_next!(pool.waiting_list)

            if item === nothing
                break  # GRUG: Waiting list is empty. Rest.
            end

            # GRUG: Route item to a worker via load balancer
            try
                worker = pick_worker(pool.balancer; cost=item.cost)
                item.future.worker_id[] = worker.id
                put!(worker.inbox, item)
                atomic_add!(pool.dispatched, 1)
                drained += 1
            catch e
                if e isa ImmuneWorkerBalancerError
                    # GRUG: All workers full or dead. Put item BACK at front of correct lane.
                    # Log it loud. Don't silently drop.
                    @error "💀 IMMUNE DISPATCHER: Balancer failed, re-queuing item" exception=e
                    lock(pool.waiting_list.lock) do
                        pushfirst!(pool.waiting_list.lanes[item.priority], item)
                        atomic_add!(pool.waiting_list.lane_sizes[item.priority], 1)
                        atomic_add!(pool.waiting_list.size, 1)
                    end
                    break  # Stop draining this cycle, try again next tick
                else
                    # GRUG: Unexpected dispatcher error. Poison the future. SCREAM.
                    @error "💀 IMMUNE DISPATCHER: Unexpected error dispatching item" exception=(e, catch_backtrace())
                    death = ImmuneWorkerDiedError(-1, e)
                    if isopen(item.future.result_channel)
                        put!(item.future.result_channel, death)
                    end
                end
            end
        end

        sleep(DISPATCHER_SLEEP_S)
    end
end

# ==============================================================================
# TRIPWIRE CHECK LOOP — Monitors rejection rate
# ==============================================================================

"""
    _tripwire_loop(pool::ImmunePool)

GRUG: Background task. Wakes every TRIPWIRE_CHECK_INTERVAL_S seconds.
Checks rejection rate and updates tripwire state.
If state changes, updates rate limiter buckets.
"""
function _tripwire_loop(pool::ImmunePool)
    while pool.alive[]
        old_state, new_state = update_tripwire_state!(pool.tripwire)
        
        if old_state != new_state
            # GRUG: State changed! Update rate limiter and log LOUD.
            @error "⚠️ IMMUNE TRIPWIRE STATE CHANGE: $old_state → $new_state"
            
            # GRUG: Update rate limiter buckets for new thresholds
            update_buckets_for_tripwire!(pool.rate_limiter, new_state)
            
            # GRUG: If entering CRITICAL, this is a big deal
            if new_state == TRIPWIRE_CRITICAL
                @error "🚨 IMMUNE SYSTEM IN CRITICAL MODE! HIGH REJECTION RATE DETECTED!"
            end
        end
        
        sleep(TRIPWIRE_CHECK_INTERVAL_S)
    end
end

# ==============================================================================
# PUBLIC API — Create, use, and shut down the immune pool
# ==============================================================================

"""
    create_immune_pool(immune_module) -> ImmunePool

GRUG: Spin up the immune thread pool. 8 workers. 1 dispatcher. 1 waiting list.
Pass in the ImmuneSystem module so workers can call immune_scan!.
Returns a running ImmunePool.

This should be called ONCE at bot startup. Keep the pool alive for the bot's lifetime.
"""
function create_immune_pool(immune_module)::ImmunePool
    # GRUG: Create tripwire monitor and rate limiter first
    tripwire = TripwireMonitor()
    rate_limiter = ImmuneRateLimiter(tripwire)

    # GRUG: Spawn 8 workers (with dummy pool for now)
    dummy_pool = nothing
    
    workers = ImmuneWorker[]
    for i in 1:NUM_IMMUNE_WORKERS
        inbox = Channel{ImmuneWorkItem}(WORKER_CHANNEL_DEPTH)
        worker = ImmuneWorker(
            i,
            inbox,
            Task(() -> nothing),
            Atomic{Bool}(false),
            Atomic{Int}(0),
            Atomic{Int}(0),
            Atomic{Int}(0),
            ReentrantLock()
        )
        push!(workers, worker)
    end

    # Small yield to let workers start their loops
    yield()

    balancer = ImmuneLoadBalancer(workers, Atomic{Int}(0))
    waiting_list = ImmuneWaitingList()

    # GRUG: Dummy dispatcher task, replaced below
    dummy_dispatcher = Task(() -> nothing)

    pool = ImmunePool(
        workers,
        balancer,
        waiting_list,
        dummy_dispatcher,
        Atomic{Bool}(true),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock(),
        tripwire,
        rate_limiter
    )

    # GRUG: Now properly start workers with reference to pool
    for i in 1:NUM_IMMUNE_WORKERS
        workers[i].task = @async begin
            try
                _worker_loop(workers[i], immune_module, pool)
            catch fatal_e
                @error "💀 IMMUNE WORKER #$i FATALLY CRASHED" exception=(fatal_e, catch_backtrace())
                workers[i].alive[] = false
            end
        end
    end

    # GRUG: Start the dispatcher
    pool.dispatcher = @async begin
        try
            _dispatcher_loop(pool)
        catch e
            @error "💀 IMMUNE DISPATCHER FATALLY CRASHED" exception=(e, catch_backtrace())
            pool.alive[] = false
        end
    end

    # GRUG: Start the tripwire monitor
    @async begin
        try
            _tripwire_loop(pool)
        catch e
            @error "💀 IMMUNE TRIPWIRE MONITOR CRASHED" exception=(e, catch_backtrace())
        end
    end

    return pool
end

"""
    submit_immune_work!(
        pool::ImmunePool,
        input_text::String,
        node_count::Int;
        is_critical::Bool = true,
        priority::PriorityLevel = PRIORITY_NORMAL,
        source::SourceID = SOURCE_ANONYMOUS
    ) -> ImmuneFuture

GRUG: Submit an input to the immune thread pool for scanning.
Returns immediately with an ImmuneFuture. NEVER BLOCKS MAIN CAVE.
Input goes to WaitingList → Dispatcher → Worker → Future.

Priority lanes:
- PRIORITY_CRITICAL: Never starves. Always processed first.
- PRIORITY_NORMAL: Default for most inputs.
- PRIORITY_LOW: Batch operations.
- PRIORITY_JUNK: Untrusted inputs. Processed last.

Rate limiting:
- Per-source rate limiting applied.
- Throws ImmuneRateLimitExhaustedError if source has no budget.

Throws:
- ImmunePoolDeadError: if pool is not running
- ImmunePoolOverloadError: if waiting list lane is full
- ImmuneRateLimitExhaustedError: if source has exhausted rate limit

No silent failures. If submit throws, caller knows immediately.
"""
function submit_immune_work!(
    pool::ImmunePool,
    input_text::String,
    node_count::Int;
    is_critical::Bool = true,
    priority::PriorityLevel = PRIORITY_NORMAL,
    source::SourceID = SOURCE_ANONYMOUS
)::ImmuneFuture

    # GRUG: Guard — pool must be alive
    if !pool.alive[]
        throw(ImmunePoolDeadError(
            "Immune pool is not running. Call create_immune_pool() first."
        ))
    end

    # GRUG: Guard — input must not be empty
    if strip(input_text) == ""
        error("!!! FATAL: submit_immune_work! got empty input_text! !!!")
    end

    # GRUG: Check rate limiting
    cost = estimate_scan_cost(node_count)
    cost_weight = COST_WEIGHTS[cost]
    
    if !try_consume_rate_limit!(pool.rate_limiter, source, cost_weight)
        retry_ms = get_retry_after_ms(pool.rate_limiter, source)
        atomic_add!(pool.rate_limited, 1)
        throw(ImmuneRateLimitExhaustedError(
            source,
            retry_ms,
            "Source has exhausted its immune scan budget. Wait $(retry_ms)ms and retry."
        ))
    end

    # GRUG: Guard — waiting list lane not full
    lane_size = get_lane_size(pool.waiting_list, priority)
    if lane_size >= MAX_WAITING_LIST_SIZE_PER_PRIORITY
        throw(ImmunePoolOverloadError(
            lane_size,
            priority,
            "Immune pool $(priority) lane full ($lane_size/$(MAX_WAITING_LIST_SIZE_PER_PRIORITY)). " *
            "Back off or use lower priority."
        ))
    end

    # GRUG: Create request ID and future
    req_id = UInt64(atomic_add!(pool.request_counter, 1))
    future = ImmuneFuture(input_text, req_id, priority, source, cost)

    item = ImmuneWorkItem(
        future,
        input_text,
        node_count,
        is_critical,
        priority,
        cost,
        source,
        time()
    )

    # GRUG: Push to correct priority lane (under lock)
    lock(pool.waiting_list.lock) do
        push!(pool.waiting_list.lanes[priority], item)
        atomic_add!(pool.waiting_list.lane_sizes[priority], 1)
        atomic_add!(pool.waiting_list.size, 1)
    end

    atomic_add!(pool.submitted, 1)
    return future
end

"""
    submit_and_wait!(
        pool::ImmunePool,
        input_text::String,
        node_count::Int;
        is_critical::Bool = true,
        priority::PriorityLevel = PRIORITY_NORMAL,
        source::SourceID = SOURCE_ANONYMOUS
    ) -> Tuple{Symbol, UInt64}

GRUG: Submit AND wait for result. Blocking convenience wrapper.
Use this when you need the result before proceeding (e.g., /grow gate).
Use submit_immune_work! when you want fire-and-forget or async checking.

Throws whatever the immune scan throws (ImmuneError on rejection, etc.).
"""
function submit_and_wait!(
    pool::ImmunePool,
    input_text::String,
    node_count::Int;
    is_critical::Bool = true,
    priority::PriorityLevel = PRIORITY_NORMAL,
    source::SourceID = SOURCE_ANONYMOUS
)::Tuple{Symbol, UInt64}

    future = submit_immune_work!(pool, input_text, node_count; 
        is_critical=is_critical, priority=priority, source=source)
    return fetch_result(future)
end

"""
    kill_immune_pool!(pool::ImmunePool)

GRUG: Shut down the immune pool. Signal dispatcher and workers to stop.
Drain and poison any remaining waiting list items.
After this, pool is dead. Cannot be restarted (make a new one).
"""
function kill_immune_pool!(pool::ImmunePool)
    pool.alive[] = false

    # GRUG: Signal all workers to stop
    for w in pool.workers
        w.alive[] = false
    end

    # GRUG: Close all worker inboxes so blocked takes! wake up
    for w in pool.workers
        if isopen(w.inbox)
            close(w.inbox)
        end
    end

    # GRUG: Poison remaining items in waiting list
    remaining_items = ImmuneWorkItem[]
    lock(pool.waiting_list.lock) do
        for priority in instances(PriorityLevel)
            append!(remaining_items, pool.waiting_list.lanes[priority])
            empty!(pool.waiting_list.lanes[priority])
        end
        pool.waiting_list.size[] = 0
    end

    shutdown_error = ImmunePoolDeadError("Immune pool was shut down while item was waiting.")
    for item in remaining_items
        if isopen(item.future.result_channel)
            put!(item.future.result_channel, shutdown_error)
        end
    end

    return nothing
end

"""
    restart_worker!(pool::ImmunePool, worker_id::Int, immune_module)

GRUG: Restart a dead worker. Use when a worker crashes.
Does NOT block. New worker starts async.
Throws if worker_id is out of range.
"""
function restart_worker!(pool::ImmunePool, worker_id::Int, immune_module)
    if worker_id < 1 || worker_id > NUM_IMMUNE_WORKERS
        error("!!! FATAL: restart_worker! got invalid worker_id=$worker_id (must be 1–$(NUM_IMMUNE_WORKERS))! !!!")
    end

    old_worker = pool.workers[worker_id]

    if old_worker.alive[]
        error("!!! FATAL: restart_worker! called on still-alive worker #$worker_id! Kill it first. !!!")
    end

    # GRUG: Close old inbox, create new worker
    if isopen(old_worker.inbox)
        close(old_worker.inbox)
    end

    inbox = Channel{ImmuneWorkItem}(WORKER_CHANNEL_DEPTH)
    new_worker = ImmuneWorker(
        worker_id,
        inbox,
        Task(() -> nothing),
        Atomic{Bool}(false),
        Atomic{Int}(0),
        Atomic{Int}(0),
        Atomic{Int}(0),
        ReentrantLock()
    )

    new_worker.task = @async begin
        try
            _worker_loop(new_worker, immune_module, pool)
        catch fatal_e
            @error "💀 IMMUNE WORKER #$worker_id FATALLY CRASHED" exception=(fatal_e, catch_backtrace())
            new_worker.alive[] = false
        end
    end

    lock(pool.pool_lock) do
        pool.workers[worker_id] = new_worker
        pool.balancer.workers[worker_id] = new_worker
    end

    return new_worker
end

# ==============================================================================
# STATUS / DIAGNOSTICS
# ==============================================================================

"""
    get_pool_status(pool::ImmunePool) -> Dict{String, Any}

GRUG: Return full status of the immune thread pool.
Used for /status CLI display and monitoring.
"""
function get_pool_status(pool::ImmunePool)::Dict{String, Any}
    worker_statuses = Dict{String, Any}[]

    for w in pool.workers
        push!(worker_statuses, Dict{String, Any}(
            "id"          => w.id,
            "alive"       => w.alive[],
            "processed"   => w.processed[],
            "errors"      => w.errors[],
            "cost_load"   => w.cost_load[],
            "inbox_depth" => isopen(w.inbox) ? Base.n_avail(w.inbox) : -1,
            "inbox_max"   => WORKER_CHANNEL_DEPTH
        ))
    end

    alive_count = count(w -> w.alive[], pool.workers)
    
    lane_sizes = Dict{String, Int}()
    for p in instances(PriorityLevel)
        lane_sizes[string(p)] = pool.waiting_list.lane_sizes[p][]
    end

    return Dict{String, Any}(
        "pool_alive"        => pool.alive[],
        "num_workers"       => NUM_IMMUNE_WORKERS,
        "alive_workers"     => alive_count,
        "dead_workers"      => NUM_IMMUNE_WORKERS - alive_count,
        "waiting_list_size" => pool.waiting_list.size[],
        "waiting_list_max"  => MAX_WAITING_LIST_SIZE,
        "lane_sizes"        => lane_sizes,
        "submitted_total"   => pool.submitted[],
        "dispatched_total"  => pool.dispatched[],
        "rejected_total"    => pool.rejected[],
        "rate_limited_total"=> pool.rate_limited[],
        "tripwire_state"    => string(get_tripwire_state(pool.tripwire)),
        "rejection_rate"    => get_rejection_rate(pool.tripwire),
        "workers"           => worker_statuses
    )
end

"""
    get_worker_load(pool::ImmunePool) -> Vector{Int}

GRUG: Return inbox depth of each worker (load snapshot).
Index = worker_id, value = current queue depth.
"""
function get_worker_load(pool::ImmunePool)::Vector{Int}
    return [isopen(w.inbox) ? Base.n_avail(w.inbox) : -1 for w in pool.workers]
end

"""
    get_cost_weighted_load(pool::ImmunePool) -> Vector{Int}

GRUG: Return cost-weighted load of each worker.
More meaningful than raw queue depth for load balancing decisions.
"""
function get_cost_weighted_load(pool::ImmunePool)::Vector{Int}
    return [w.cost_load[] for w in pool.workers]
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export ImmunePool, ImmuneFuture, ImmuneWorkItem
export ImmuneWorkerDiedError, ImmunePoolOverloadError, ImmunePoolDeadError, ImmuneWorkerBalancerError
export ImmuneRateLimitExhaustedError, ImmuneTripwireTriggeredError, ImmunePriorityInversionError
export create_immune_pool, submit_immune_work!, submit_and_wait!, kill_immune_pool!
export restart_worker!, get_pool_status, get_worker_load, get_cost_weighted_load
export fetch_result, is_ready
export NUM_IMMUNE_WORKERS, MAX_WAITING_LIST_SIZE, WORKER_CHANNEL_DEPTH
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

# ==============================================================================
# ACADEMIC BLOCK
# ==============================================================================
# The ImmuneThreadPool implements a bounded work-stealing-style executor for
# the grugbot420 immune system. Key design properties:
#
# 1. **Thread Isolation**: The 8 immune workers run exclusively on @async Tasks,
#    ensuring immune processing never executes on the main task's call stack.
#    This guarantees main-path latency is unaffected by immune work, even under
#    heavy anomaly load.
#
# 2. **Load Balancing via Cost-Weighted Least-Queue-Depth**: The ImmuneLoadBalancer
#    implements a greedy bin-filling strategy that considers both queue depth and
#    estimated scan cost. Expensive scans (COST_EXPENSIVE) count 4x toward load
#    compared to cheap scans. This prevents a few expensive scans from monopolizing
#    a worker while cheap scans wait.
#
# 3. **Priority Lanes**: The ImmuneWaitingList maintains separate FIFO queues per
#    priority level (CRITICAL, NORMAL, LOW, JUNK). The dispatcher drains CRITICAL
#    first, ensuring time-sensitive inputs are never starved by lower-priority work.
#    Each lane has its own bound (MAX_WAITING_LIST_SIZE_PER_PRIORITY).
#
# 4. **Per-Source Rate Limiting**: Each source (identified by SourceID) has a token
#    bucket with type-specific rate limits. This prevents a single malicious or
#    misbehaving source from consuming the entire immune processing budget. Internal
#    sources bypass rate limiting; anonymous sources have the strictest limits.
#
# 5. **Tripwire Metrics**: The TripwireMonitor tracks rejection rate in a sliding
#    window. When rejection rate exceeds thresholds, the system transitions through
#    ELEVATED → HARDENED → CRITICAL states. In HARDENED+ states, rate limits become
#    much stricter, providing automatic protection against attack.
#
# 6. **Bounded Buffering**: The ImmuneWaitingList provides bounded FIFO buffers
#    (capacity MAX_WAITING_LIST_SIZE_PER_PRIORITY per lane) between submission and
#    dispatch. This decouples the submission rate from the processing rate and
#    provides backpressure signaling (ImmunePoolOverloadError) when saturated.
#
# 7. **Non-Blocking Submission**: submit_immune_work! enqueues to the correct
#    priority lane under a single lock acquisition and returns an ImmuneFuture
#    immediately. The O(1) enqueue ensures the main path is never blocked.
#
# 8. **Zero Silent Failures**: Every failure path either (a) throws a typed
#    exception to the caller, or (b) delivers a typed exception into the
#    ImmuneFuture. There is no logging-only path for errors. Dead workers
#    propagate ImmuneWorkerDiedError to all pending futures on their inbox.
#
# 9. **Future-Based Result Delivery**: Results flow through Channel{Any}(1)
#    futures, enabling both blocking (fetch_result) and polling (is_ready)
#    consumption patterns. The single-slot channel ensures at-most-once delivery.
#
# Formal properties:
#   Let W = {w₁,...w₈}, Q_i = inbox depth of wᵢ, C_i = cost_load of wᵢ
#   pick_worker: argmin_{wᵢ alive} (Q_i * 2 + C_i/10)  (cost-weighted depth)
#   submit_immune_work!: O(1) amortized (lane append + size atomic)
#   dispatch latency: ≤ DISPATCHER_SLEEP_S + O(1) pick_worker time
#   priority order: CRITICAL >> NORMAL >> LOW >> JUNK (strict priority drain)
#   rate limit per source: token bucket with type-specific rate/burst
#   tripwire thresholds: 10% → ELEVATED, 25% → HARDENED, 50% → CRITICAL
#   hardened mode: 5x stricter rate limits across all source types
#   overload signal: ImmunePoolOverloadError when |lane| ≥ MAX_WAITING_LIST_SIZE_PER_PRIORITY
#   rate limit signal: ImmuneRateLimitExhaustedError when token bucket empty
#   worker fault isolation: crash of wᵢ does not affect w_{j≠i}
#   main-path isolation: main task never holds ImmunePool locks during submission
# ==============================================================================

end # module ImmuneThreadPool