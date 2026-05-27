# Kitchen Sink v18 — SelfObserver / Subconscious Microlog Store

**Module:** `src/SelfObserver.jl`
**Driver:** `kitchen_sink_self_observer.jl`
**Captured run:** `run.log` (360 lines)
**Final demo audit:** `audit_dump.json`
**Commit:** `be06505` on `main`

---

## What this kitchen sink proves

This is an end-to-end exercise of the SelfObserver subconscious microlog store under a realistic mixed workload. It goes well beyond the unit-test suite (`test/test_self_observer.jl`, 129 assertions) by simulating many concurrent nodes writing observations across all five tag namespaces, with drop-table associations forming a small connected concept graph, then exercising every read path, throttle gate, eviction policy, and the structural no-Float64 invariant.

Every phase is delimited in the log with banner headers so the captured run reads top-to-bottom as a narrative. Every assertion in the script must hold or the run aborts non-zero. This run exited `0`.

---

## Workload shape

The driver builds a small "kitchen world" of 12 anchor concepts wired into a directed drop-table graph:

```
kitchen → stove, pan, sink
stove   → fire, heat, pan
pan     → stove, oil
sink    → water, soap
fire    → heat, smoke
water   → sink, kettle
kettle  → water, tea
tea     → kettle, cup
cup     → tea, coffee
coffee  → cup, morning
morning → coffee, alarm
alarm   → morning, clock
```

Onto these anchors it writes 20 observations spanning **all five tag namespaces** — `:timing`, `:lexical`, `:mood`, `:relational`, `:meta` — with realistic provenances such as `:slow_response`, `:no_relations_extracted`, `:mood_drift`, `:token_recurrence`, `:probe_attached`, `:recurring_phrase`, `:ambient_calm`. Salience is biased upward for well-connected concepts.

---

## Phase-by-phase results

### Phase 1 — Construction & smoke
Constructs a `SubconsciousStore` with a seeded RNG (`0xC0FFEE`), prints the seven fuzzy time buckets, performs one write + one peek round-trip. Audit confirms `writes=1, peeks_hit=1, total_entries=1, keys=1, outstanding_tokens=0`. Wiring is intact.

### Phase 2 — Mixed workload across all five tag namespaces
- First pass at `p_write=0.6` over 20 observations: stochastic gate fired correctly (skips counted, no failures).
- Second pass at `p_write=1.0` filled remaining slots and triggered the **reinforcement path** (same `(key, tag, provenance)` collapses into the existing entry with weight gain).
- Reinforcement burst: 8 successive writes for `("alarm", :timing, :token_recurrence)` collapsed into a single entry rather than appending.

End-of-phase snapshot: `total_entries=21, keys=16, writes_reinforced=18`. The 18 reinforcements is the second-pass collisions plus the 8 explicit burst — exactly as designed.

### Phase 3 — Recall behaviors
This is where the subconscious actually shows what it can do.

- **3a** — Exact peek on `"kitchen"`: 3 hints (one per tag present: `:relational`, `:mood`, `:timing`), each carrying its provenance, fuzzy `when=just_now`, and per-key associations `["sink","pan","stove"]`.
- **3b** — Same peek with `tag=:mood`: trimmed to a single hint, the `:ambient_calm` mood fragment.
- **3c** — Exact peek on a never-written key: returned `nothing` (silent miss, audit increments `peeks_miss`).
- **3d** — Pattern peek on `"rainy seattle morning coffee"`: token overlap on `morning` and `coffee` surfaced `alarm`, `cup`, `morning`, `coffee`, `tea`. Note the depth-2 walk pulled `tea` (associated with `cup`) and `alarm` (associated with `morning`) even though the query never mentioned them. This is the associative-recall property.
- **3e** — Pattern peek with `walk_depth=0`: returned ONLY the 3 direct `kitchen` fragments, no walk-reached neighbors. Confirms the walk is gated by depth.
- **3f** — Pattern peek with `walk_depth=2`: returned **12** fragments including `fire`, `heat`, `oil`, `pan`, `sink`, `water` — concepts reached through the drop-table graph from `kitchen` even though the query was a single token. This is the headline subconscious-style behavior: bits and pieces of inference.
- **3g** — Pattern peek with `tag=:mood, walk_depth=2`: cleanly trimmed the 12-fragment result to 3 mood fragments only (`kitchen → calm`, `fire → alert`, `heat → alert`). The tag namespace acts as a clean filter on top of associative recall.

### Phase 4 — Throttle and single-reader gate
- **4a** — Per-node bucket exhaustion (one node, 6 sequential peeks): result `succeeded=3 throttled/none=3` exactly as designed (`TOKEN_BUCKET_CAPACITY=3`).
- **4b** — Six different node ids, one peek each: `succeeded=6 throttled/none=0`. Buckets are correctly per-node, not shared.
- **4c** — 64-thread concurrent peek storm distributed across 8 node ids: `hit=24 none=40 of 64`. The strict global single-reader lock + per-node throttle cooperatively rejected 40 of 64 attempts. Outstanding tokens returned cleanly to `0` after the storm. No leaks.

End-of-phase audit: `peeks_attempted=84, peeks_hit=40, peeks_miss=1, peeks_throttle=43, peeks_lock_busy=0, peeks_timeout=0, outstanding_tokens=0`. Every attempt is accounted for.

### Phase 5 — Reader timeout
Manually held the global reader slot, then issued a peek with `timeout_ms=25`. Returned `nothing` cleanly without throwing. Audit incremented `peeks_lock_busy`. This confirms "I don't know" is a normal subconscious answer rather than an error.

### Phase 6 — Eviction pressure
- **6a** — Per-key cap: wrote one vivid (`salience=8.0`) entry to `shared_concept`, then flooded with 60 noise entries at `salience=0.4`. Bucket clamped to `32`. Vivid entry **survived** all 60 floods. Salience-aware eviction works: a one-off vivid memory outlives a noisy stream of low-importance ones.
- **6b** — Global total cap: pushed 4200 distinct keys at low salience. Final `total_entries=4096` (exactly the hard cap), `evictions_total_cap=157`. Note `keys=4060` in the audit — fewer than total_entries because the kitchen-world keys still hold multiple tag-distinct fragments.

### Phase 7 — Fuzzy bucket consistency
Two peeks against `"fuzzy_anchor"` with the same `query_id` returned the **same** `fuzzy_when` symbol. A third peek with a different `query_id` returned a bucket from the same valid set (`FUZZY_BUCKETS`). This confirms the per-(key, query_id) seeded jitter: stable within one query, independently jittered across queries — the "rule of thumb" feel.

### Phase 8 — Structural no-Float64 invariant on a live store
This is the architectural guarantee that side processes can never leak into vote confidence.

- **8a** — Every field of `SubconsciousHint` was inspected at runtime; none is `Float64` or `Float32`. Field types observed: `String, Symbol, Symbol, Symbol, Vector{String}, Dict{String,String}, Vector{String}`. Clean.
- **8b** — Runtime return types of every public reader: `audit_trail → Dict{Symbol,Int64}`, `store_size → Int64`, `key_count → Int64`, `peek_exact → Vector{SubconsciousHint}` (or `Nothing`), `peek_pattern → Vector{SubconsciousHint}` (or `Nothing`). Zero Float64 paths.
- **8c** — A payload was written with a Float64 value (`"score" => 0.7`). The surfaced hint's `payload_keys` includes `"score"` (the caller can see a fragment existed) but `payload_strings` does **not** contain `"score"` (the float value is dropped from the surfaced view). The fragment's existence is observable; the number is not.

### Phase 9 — drop_store! and reset_audit!
`drop_store!` wiped contents (`total_entries: 4097 → 0`, `keys: 4061 → 0`) while preserving audit counters (`writes` unchanged at 4302). `reset_audit!` then zeroed the counters without re-touching contents. Both maintenance calls behave as documented.

### Phase 10 — Final audit dump
A fresh demo store rebuilt from the kitchen-world workload, exercised with one exact peek, one pattern peek, one miss peek, and 5 burner peeks to exhaust a token bucket. Final audit serialized to `audit_dump.json`:

```json
{
  "writes": 20,
  "writes_skipped_stochastic": 0,
  "writes_reinforced": 0,
  "evictions_per_key": 0,
  "evictions_total_cap": 0,
  "peeks_attempted": 8,
  "peeks_hit": 5,
  "peeks_miss": 1,
  "peeks_throttle": 2,
  "peeks_global_cap": 0,
  "peeks_lock_busy": 0,
  "peeks_timeout": 0,
  "total_entries": 20,
  "keys": 15,
  "outstanding_tokens": 0
}
```

Attempts (8) = hits (5) + misses (1) + throttles (2). Conservation holds.

---

## Headline numbers

| Metric | End of Phase 4 | End of Phase 6 |
|---|---:|---:|
| writes (total) | 39 | 4 300 |
| writes_reinforced | 18 | 18 |
| writes_skipped_stochastic | 10 | 10 |
| evictions_per_key | 0 | 29 |
| evictions_total_cap | 0 | 157 |
| peeks_attempted | 84 | 86 |
| peeks_hit | 40 | 41 |
| peeks_miss | 1 | 1 |
| peeks_throttle | 43 | 43 |
| peeks_lock_busy | 0 | 1 |
| peeks_timeout | 0 | 0 |
| total_entries | 21 | 4 096 |
| keys | 16 | 4 060 |
| outstanding_tokens | 0 | 0 |

Conservation invariant `attempts == hits + miss + throttle + lock_busy + timeout + global_cap` holds at every snapshot.

---

## What this kitchen sink does NOT do

By explicit design and per the user's "one thing at a time" direction, the following are **not** exercised here and remain parked for follow-up commits:

- **Phagy maintenance scheduler** — idle-time decay/eviction tick. The `DECAY_PER_TICK` constant is wired in the module but no scheduler calls it yet.
- **Engine-side `observe!` call sites** — wiring of stochastic writes into honest core-evidence sites in `engine.jl` (no-relations cases, token recurrence, mood drift, slow response).
- **Orchestrator integration** — the AIML orchestrator's "one peek per cycle" gate and the path that attaches a hint, if any, to the generation/system-prompt layer only.

Each of those is a separate, scoped work item; this demo proves the underlying store is ready to receive them.

---

## How to reproduce

```sh
cd grugbot420_repo
julia --project=. specimen_demo/kitchen_sink_v18_self_observer/kitchen_sink_self_observer.jl \
  > specimen_demo/kitchen_sink_v18_self_observer/run.log 2>&1
echo "exit=$?"
```

Expected: exit `0`, ~360 lines of output, `audit_dump.json` regenerated, all phase assertions pass.

---

## Files in this directory

- `kitchen_sink_self_observer.jl` — the driver (10 phases, ~340 lines).
- `run.log` — captured stdout/stderr from the most recent successful run.
- `audit_dump.json` — final-phase audit trail in JSON.
- `SUMMARY.md` — this document.
