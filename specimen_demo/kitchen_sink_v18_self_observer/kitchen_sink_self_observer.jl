#!/usr/bin/env julia
# ==============================================================================
# kitchen_sink_self_observer.jl
# Comprehensive end-to-end exercise of the SelfObserver / subconscious module.
# ==============================================================================
# GRUG: this is NOT the unit test suite — that lives in test/test_self_observer.jl.
# This script simulates a realistic mixed workload: many nodes writing across
# all five tag namespaces, with drop-table associations, reinforcement,
# throttling, eviction pressure, and concurrent reads. Every phase prints a
# clearly delimited section so the captured log reads top-to-bottom as a
# narrative. Final phase dumps the complete audit_trail to JSON and verifies
# the structural no-Float64 invariant on a live store.
#
# Run from repo root:
#   julia --project=. specimen_demo/kitchen_sink_v18_self_observer/kitchen_sink_self_observer.jl
# ==============================================================================

using Random
using Dates
using JSON
using Base.Threads: @spawn

const REPO_ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(REPO_ROOT, "src", "SelfObserver.jl"))
using .SelfObserver

# ------------------------------------------------------------------------------
# Helpers for the narrative output.
# ------------------------------------------------------------------------------
function banner(title::String)
    line = repeat("=", 78)
    println()
    println(line)
    println("  ", title)
    println(line)
end

function subbanner(title::String)
    println()
    println("--- ", title, " ", repeat("-", max(0, 70 - length(title))))
end

function show_audit(label::String, store::SubconsciousStore)
    a = audit_trail(store)
    println("[audit @ $label]")
    keys_in_order = (
        :writes, :writes_skipped_stochastic, :writes_reinforced,
        :evictions_per_key, :evictions_total_cap,
        :peeks_attempted, :peeks_hit, :peeks_miss,
        :peeks_throttle, :peeks_global_cap, :peeks_lock_busy, :peeks_timeout,
        :total_entries, :keys, :outstanding_tokens,
    )
    for k in keys_in_order
        v = get(a, k, 0)
        println("    ", rpad(string(k), 28), " = ", v)
    end
    return a
end

function show_hints(label::String, hints)
    println("[hints @ $label]")
    if hints === nothing
        println("    -> nothing (subconscious had no answer / was throttled / locked)")
        return
    end
    println("    -> ", length(hints), " hint(s):")
    for (i, h) in enumerate(hints)
        println("       #$i key=$(repr(h.key))  tag=$(h.tag)  when=$(h.fuzzy_when)  prov=$(h.provenance)")
        println("           payload_keys=", h.payload_keys)
        println("           payload_str =", h.payload_strings)
        if !isempty(h.associations)
            println("           assocs      =", h.associations)
        end
    end
end

# ==============================================================================
# Workload data — defined at module scope, used inside main().
# ==============================================================================

const KITCHEN_GRAPH = Dict(
    "kitchen"     => ["stove", "pan", "sink"],
    "stove"       => ["fire",  "heat", "pan"],
    "pan"         => ["stove", "oil"],
    "sink"        => ["water", "soap"],
    "fire"        => ["heat",  "smoke"],
    "water"       => ["sink",  "kettle"],
    "kettle"      => ["water", "tea"],
    "tea"         => ["kettle","cup"],
    "cup"         => ["tea",   "coffee"],
    "coffee"      => ["cup",   "morning"],
    "morning"     => ["coffee","alarm"],
    "alarm"       => ["morning","clock"],
)

const TAGGED_OBSERVATIONS = [
    ("kitchen",  :timing,     :slow_response,         Dict{String,Any}("op"=>"chop", "felt"=>"slow")),
    ("kitchen",  :mood,       :ambient_calm,          Dict{String,Any}("mood"=>"calm")),
    ("kitchen",  :relational, :no_relations_extracted,Dict{String,Any}("input"=>"the kitchen")),
    ("stove",    :timing,     :token_recurrence,      Dict{String,Any}("token"=>"stove", "count"=>3)),
    ("stove",    :meta,       :probe_attached,        Dict{String,Any}("probe"=>"heat-sensor")),
    ("fire",     :mood,       :mood_drift,            Dict{String,Any}("from"=>"calm","to"=>"alert")),
    ("fire",     :lexical,    :recurring_phrase,      Dict{String,Any}("phrase"=>"watch the fire")),
    ("water",    :lexical,    :recurring_phrase,      Dict{String,Any}("phrase"=>"running water")),
    ("water",    :relational, :no_relations_extracted,Dict{String,Any}("input"=>"some water")),
    ("kettle",   :timing,     :slow_response,         Dict{String,Any}("op"=>"boil","felt"=>"slow")),
    ("tea",      :mood,       :ambient_calm,          Dict{String,Any}("mood"=>"calm")),
    ("coffee",   :mood,       :mood_drift,            Dict{String,Any}("from"=>"sleepy","to"=>"awake")),
    ("morning",  :meta,       :probe_attached,        Dict{String,Any}("probe"=>"daily-cycle")),
    ("alarm",    :timing,     :token_recurrence,      Dict{String,Any}("token"=>"alarm","count"=>5)),
    ("cup",      :lexical,    :recurring_phrase,      Dict{String,Any}("phrase"=>"another cup")),
    ("sink",     :relational, :no_relations_extracted,Dict{String,Any}("input"=>"the sink")),
    ("pan",      :meta,       :probe_attached,        Dict{String,Any}("probe"=>"surface-temp")),
    ("heat",     :mood,       :mood_drift,            Dict{String,Any}("from"=>"calm","to"=>"alert")),
    ("smoke",    :timing,     :slow_response,         Dict{String,Any}("op"=>"detect","felt"=>"late")),
    ("oil",      :lexical,    :recurring_phrase,      Dict{String,Any}("phrase"=>"hot oil")),
]

# ==============================================================================
# Main — wrapped in a function so locals don't fight Julia's top-level loop scope.
# ==============================================================================
function main()
    # --------------------------------------------------------------------------
    # PHASE 1 — Construction + sanity smoke
    # --------------------------------------------------------------------------
    banner("PHASE 1 — Construction & smoke")

    store = SubconsciousStore(rng = MersenneTwister(0xC0FFEE))
    println("Constructed SubconsciousStore.")
    println("Initial size = $(store_size(store)), keys = $(key_count(store)).")
    println("FUZZY_BUCKETS:")
    for (sym, bound) in FUZZY_BUCKETS
        println("    ", rpad(string(sym), 18), " <= ", bound, " s")
    end

    observe!(store, "smoke_concept", :lexical,
             Dict{String,Any}("note" => "wiring check"); p_write = 1.0,
             provenance = :phase1_smoke)
    show_hints("phase1_smoke",
               peek_exact(store, "smoke-node", "smoke_concept"))
    show_audit("phase1_end", store)

    # --------------------------------------------------------------------------
    # PHASE 2 — Realistic mixed workload
    # --------------------------------------------------------------------------
    banner("PHASE 2 — Mixed workload across all tag namespaces")

    subbanner("Stochastic writes (p_write=0.6) with full drop-table wiring")
    written_count = 0
    skipped_count = 0
    for (key, tag, prov, payload) in TAGGED_OBSERVATIONS
        drop = get(KITCHEN_GRAPH, key, String[])
        salience = 1.0 + (length(drop) * 0.25)
        ok = observe!(store, key, tag, payload;
                      p_write = 0.6, salience = salience,
                      provenance = prov, drop_table = drop)
        if ok
            written_count += 1
        else
            skipped_count += 1
        end
    end
    println("First-pass writes: written=$(written_count) skipped=$(skipped_count) of $(length(TAGGED_OBSERVATIONS))")

    subbanner("Second pass at p_write=1.0 to fill remaining slots & exercise reinforcement")
    for (key, tag, prov, payload) in TAGGED_OBSERVATIONS
        drop = get(KITCHEN_GRAPH, key, String[])
        observe!(store, key, tag, payload;
                 p_write = 1.0, salience = 1.0,
                 provenance = prov, drop_table = drop)
    end

    subbanner("Reinforcement burst — same (key, tag, provenance) repeated 8x")
    for _ in 1:8
        observe!(store, "alarm", :timing, Dict{String,Any}("token"=>"alarm","count"=>5);
                 p_write = 1.0, salience = 1.0,
                 provenance = :token_recurrence,
                 drop_table = ["morning", "clock"])
    end
    show_audit("phase2_end", store)

    # --------------------------------------------------------------------------
    # PHASE 3 — Recall: exact + pattern + walk-only
    # --------------------------------------------------------------------------
    banner("PHASE 3 — Recall behaviors")

    subbanner("3a. Exact peek on 'kitchen' — should hit, multiple tags present")
    show_hints("exact:kitchen",
        peek_exact(store, "recall-A", "kitchen"; max_entries = 5))

    subbanner("3b. Exact peek on 'kitchen' filtered to :mood")
    show_hints("exact:kitchen :mood",
        peek_exact(store, "recall-B", "kitchen"; tag = :mood, max_entries = 5))

    subbanner("3c. Exact peek on a key that does not exist")
    show_hints("exact:nonexistent",
        peek_exact(store, "recall-C", "this_key_was_never_written"))

    subbanner("3d. Pattern peek on 'rainy seattle morning coffee' — token overlap on 'morning' & 'coffee'")
    show_hints("pattern:rainy seattle morning coffee",
        peek_pattern(store, "recall-D", "rainy seattle morning coffee";
                     max_entries = 5, walk_depth = 2))

    subbanner("3e. Pattern peek with walk_depth=0 — should NOT pull associated keys")
    show_hints("pattern:kitchen walk=0",
        peek_pattern(store, "recall-E", "kitchen"; walk_depth = 0, max_entries = 8))

    subbanner("3f. Pattern peek with walk_depth=2 — should reach 'fire' and 'heat' from 'kitchen'")
    show_hints("pattern:kitchen walk=2",
        peek_pattern(store, "recall-F", "kitchen"; walk_depth = 2, max_entries = 12))

    subbanner("3g. Pattern peek tag-filtered to :mood — only mood fragments survive")
    show_hints("pattern:kitchen tag=:mood",
        peek_pattern(store, "recall-G", "kitchen"; tag = :mood, walk_depth = 2,
                     max_entries = 8))
    show_audit("phase3_end", store)

    # --------------------------------------------------------------------------
    # PHASE 4 — Throttle + single-reader gate under contention
    # --------------------------------------------------------------------------
    banner("PHASE 4 — Throttle and single-reader gate")

    subbanner("4a. Per-node bucket exhaustion: 6 sequential peeks from one node")
    ok_n = 0; none_n = 0
    for i in 1:6
        r = peek_exact(store, "burner-1", "kitchen")
        if r === nothing
            none_n += 1
        else
            ok_n += 1
        end
    end
    println("burner-1 results: succeeded=$(ok_n) throttled/none=$(none_n)  (cap=3, expect 3 ok / 3 none)")

    subbanner("4b. Distinct nodes don't share buckets: 6 nodes × 1 peek each")
    ok_m = 0; none_m = 0
    for i in 1:6
        r = peek_exact(store, "fresh-$i", "kitchen")
        if r === nothing
            none_m += 1
        else
            ok_m += 1
        end
    end
    println("fresh-* results: succeeded=$(ok_m) throttled/none=$(none_m)  (each node has full 3-token bucket)")

    subbanner("4c. 64-thread concurrent peek storm — strict single-reader must hold")
    N = 64
    results = Vector{Any}(undef, N)
    @sync for i in 1:N
        @spawn begin
            node_id = "n-$(i % 8)"
            results[i] = peek_exact(store, node_id, "kitchen")
        end
    end
    some_ok = count(r -> r !== nothing, results)
    some_none = count(r -> r === nothing, results)
    println("storm results: hit=$(some_ok) none=$(some_none) of $(N)")
    show_audit("phase4_end", store)

    @assert audit_trail(store)[:outstanding_tokens] == 0 "outstanding tokens leaked after storm"

    # --------------------------------------------------------------------------
    # PHASE 5 — Reader timeout
    # --------------------------------------------------------------------------
    banner("PHASE 5 — Reader timeout (manual reader-slot hold)")

    subbanner("5a. Force the reader slot held; next peek must return nothing")
    store.reader_busy[] = true
    try
        r = peek_exact(store, "patient", "kitchen"; timeout_ms = 25)
        println("peek under held lock: ", r === nothing ? "nothing (correct)" : "UNEXPECTED HIT")
        @assert r === nothing "reader-slot timeout failed to return nothing"
    finally
        store.reader_busy[] = false
    end
    show_audit("phase5_end", store)

    # --------------------------------------------------------------------------
    # PHASE 6 — Eviction pressure
    # --------------------------------------------------------------------------
    banner("PHASE 6 — Eviction pressure")

    subbanner("6a. Per-key cap eviction — flood 'shared_concept' with 60 noise provenances")
    observe!(store, "shared_concept", :lexical,
             Dict{String,Any}("note"=>"vivid one"); p_write=1.0,
             salience = 8.0, provenance = :vivid_seed)
    for i in 1:60
        observe!(store, "shared_concept", :lexical,
                 Dict{String,Any}("i"=>i); p_write = 1.0,
                 salience = 0.4, provenance = Symbol("noise_$i"))
    end
    println("shared_concept bucket length after flood = ", length(store.table["shared_concept"]),
            "   (cap = 32)")
    hits_vivid = peek_exact(store, "vivid-check", "shared_concept";
                            tag=:lexical, max_entries = 32)
    @assert hits_vivid !== nothing
    @assert any(h -> h.provenance == :vivid_seed, hits_vivid) "vivid-salience entry was wrongly evicted"
    println("Vivid (salience=8) entry survived the flood: OK")

    subbanner("6b. Global total cap — push above 4096 distinct keys")
    for i in 1:4200
        observe!(store, "g$(i)", :lexical, Dict{String,Any}("i"=>i);
                 p_write = 1.0, salience = 0.3,
                 provenance = :bulk_fill)
    end
    println("After bulk fill: total_entries = $(store_size(store)) (must be <= 4096)")
    @assert store_size(store) <= 4096 "total cap not honored"
    show_audit("phase6_end", store)

    # --------------------------------------------------------------------------
    # PHASE 7 — Fuzzy bucket consistency
    # --------------------------------------------------------------------------
    banner("PHASE 7 — Fuzzy bucket consistency")

    subbanner("7a. Same query_id ⇒ same fuzzy bucket; new query_id may differ")
    observe!(store, "fuzzy_anchor", :meta, Dict{String,Any}("v"=>"test");
             p_write=1.0, provenance = :fuzzy_test)
    b1 = peek_exact(store, "fz-1", "fuzzy_anchor"; query_id = "QID-A")
    b2 = peek_exact(store, "fz-2", "fuzzy_anchor"; query_id = "QID-A")
    b3 = peek_exact(store, "fz-3", "fuzzy_anchor"; query_id = "QID-B")
    @assert b1 !== nothing && b2 !== nothing && b3 !== nothing
    println("QID-A peek 1 fuzzy_when = ", b1[1].fuzzy_when)
    println("QID-A peek 2 fuzzy_when = ", b2[1].fuzzy_when, "   (must equal peek 1)")
    println("QID-B peek   fuzzy_when = ", b3[1].fuzzy_when, "   (may differ; jittered seed)")
    @assert b1[1].fuzzy_when == b2[1].fuzzy_when "per-(key,query_id) fuzzy bucket not stable"
    valid_syms = Set(t[1] for t in FUZZY_BUCKETS)
    @assert b1[1].fuzzy_when in valid_syms
    @assert b3[1].fuzzy_when in valid_syms

    # --------------------------------------------------------------------------
    # PHASE 8 — Structural invariant on a LIVE store
    # --------------------------------------------------------------------------
    banner("PHASE 8 — Structural no-Float64 invariant on live store")

    subbanner("8a. SubconsciousHint fieldtypes")
    for (name, ft) in zip(fieldnames(SubconsciousHint), fieldtypes(SubconsciousHint))
        println("    $(rpad(string(name),18)) :: $(ft)")
        @assert !(Float64 <: ft) "Float64 leaked into SubconsciousHint field $name"
        @assert !(Float32 <: ft) "Float32 leaked into SubconsciousHint field $name"
    end

    subbanner("8b. Runtime return types of every public reader")
    println("audit_trail   -> ", typeof(audit_trail(store)))
    println("store_size    -> ", typeof(store_size(store)))
    println("key_count     -> ", typeof(key_count(store)))
    let r = peek_exact(store, "inv-A", "kitchen")
        println("peek_exact    -> ", r === nothing ? "Nothing" : typeof(r))
        @assert r === nothing || r isa Vector{SubconsciousHint}
    end
    let r = peek_pattern(store, "inv-B", "kitchen")
        println("peek_pattern  -> ", r === nothing ? "Nothing" : typeof(r))
        @assert r === nothing || r isa Vector{SubconsciousHint}
    end

    subbanner("8c. Float64 payload values are dropped from surfaced view")
    observe!(store, "float_carrier", :meta,
             Dict{String,Any}("kind"=>"thing", "score"=>0.7, "n"=>3);
             p_write=1.0, provenance = :float_check)
    fc = peek_exact(store, "fc-1", "float_carrier")
    @assert fc !== nothing
    println("payload_keys (caller can see fragment existed): ", fc[1].payload_keys)
    println("payload_strings (Float64 dropped): ", fc[1].payload_strings)
    @assert "score" in fc[1].payload_keys
    @assert !("score" in keys(fc[1].payload_strings))

    # --------------------------------------------------------------------------
    # PHASE 9 — drop_store! / reset_audit! semantics
    # --------------------------------------------------------------------------
    banner("PHASE 9 — drop_store! and reset_audit!")

    a_before_drop = audit_trail(store)
    println("Before drop_store!: total_entries=$(a_before_drop[:total_entries]), keys=$(a_before_drop[:keys]), writes=$(a_before_drop[:writes])")
    drop_store!(store)
    a_after_drop = audit_trail(store)
    println("After drop_store!:  total_entries=$(a_after_drop[:total_entries]), keys=$(a_after_drop[:keys]), writes=$(a_after_drop[:writes])")
    @assert a_after_drop[:total_entries] == 0
    @assert a_after_drop[:keys] == 0
    @assert a_after_drop[:writes] == a_before_drop[:writes]   # audit preserved

    reset_audit!(store)
    a_after_reset = audit_trail(store)
    println("After reset_audit!: writes=$(a_after_reset[:writes]) (must be 0)")
    @assert a_after_reset[:writes] == 0

    # --------------------------------------------------------------------------
    # PHASE 10 — Final audit JSON dump
    # --------------------------------------------------------------------------
    banner("PHASE 10 — Final audit dump")

    final_store = SubconsciousStore(rng = MersenneTwister(0xFEEDFACE))
    for (key, tag, prov, payload) in TAGGED_OBSERVATIONS
        drop = get(KITCHEN_GRAPH, key, String[])
        observe!(final_store, key, tag, payload;
                 p_write = 1.0, salience = 1.0,
                 provenance = prov, drop_table = drop)
    end
    peek_exact(final_store, "demo-1", "kitchen")
    peek_pattern(final_store, "demo-2", "morning coffee"; walk_depth = 2)
    peek_exact(final_store, "demo-3", "this_does_not_exist")
    for _ in 1:5
        peek_exact(final_store, "demo-burner", "kitchen")
    end

    final_audit = audit_trail(final_store)
    println("Final demo-store audit:")
    for (k, v) in sort(collect(final_audit); by = x -> string(x[1]))
        println("    ", rpad(string(k), 28), " = ", v)
    end

    audit_path = joinpath(@__DIR__, "audit_dump.json")
    open(audit_path, "w") do io
        JSON.print(io, Dict(string(k) => v for (k,v) in final_audit), 2)
    end
    println("Final audit JSON written to: $(audit_path)")

    banner("KITCHEN SINK COMPLETE — all phases passed")
    println("Timestamp: ", Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))
    return nothing
end

main()
