#!/usr/bin/env julia
# Test script: verify the IFS invariant fix for SelfObserver

include("src/RelationalJitter.jl")
include("src/SelfObserver.jl")

using .SelfObserver
using .RelationalJitter
using Statistics

println("=" ^ 60)
println("IFS INVARIANT FIX - VALIDATION TEST SUITE")
println("=" ^ 60)

let  # use let block to avoid soft-scope issues
all_pass = true

D = Dict{String,Any}

# ── Test 1 ──
print("\n[1] IFS constructor rejects invalid mu+nu+pi > 1.0 ... ")
try
    Microlog("k", :meta, D("x"=>1), 0.6, 0.5, 0.1, :test)
    println("FAIL - should have thrown")
    all_pass = false
catch e
    if e isa SelfObserverArgumentError && occursin("IFS invariant", e.message)
        println("PASS")
    else
        println("FAIL - wrong error type")
        all_pass = false
    end
end

# ── Test 2 ──
print("[2] Salience constructor produces valid IFS triple ... ")
ml = Microlog("k", :meta, D("x"=>1), 5.0, :test)
if ml.mu + ml.nu + ml.pi ≈ 1.0 && ml.mu >= 0.0 && ml.pi >= 0.0
    println("PASS (mu=$(round(ml.mu,digits=3)), nu=$(round(ml.nu,digits=3)), pi=$(round(ml.pi,digits=3)))")
else
    println("FAIL")
    all_pass = false
end

# ── Test 3: High-salience reinforcement ──
print("[3] High-salience reinforcement (50x, sal=10) preserves invariant ... ")
store = SubconsciousStore()
key = "test_concept"; tag = :meta; prov = :test
observe!(store, key, tag, D("x"=>1); p_write=1.0, salience=1.0, provenance=prov)

invariant_ok = true
last_mu = 0.0; last_nu = 0.0; last_pi = 0.0
for i in 1:50
    observe!(store, key, tag, D("x"=>i+1); p_write=1.0, salience=10.0, provenance=prov)
    for ml in store.table[key]
        if ml.tag == tag && ml.provenance == prov
            last_mu = ml.mu; last_nu = ml.nu; last_pi = ml.pi
            if ml.mu + ml.nu + ml.pi > 1.0 + 1e-9
                println("FAIL at iter $i: sum=$(ml.mu+ml.nu+ml.pi)")
                invariant_ok = false
            end
        end
    end
end
if invariant_ok
    println("PASS (final: mu=$(round(last_mu,digits=4)), nu=$(round(last_nu,digits=4)), pi=$(round(last_pi,digits=4)))")
else
    all_pass = false
end

# ── Test 4: Low-salience many reinforcements ──
print("[4] Low-salience reinforcement (100x, sal=1) preserves invariant ... ")
store2 = SubconsciousStore()
observe!(store2, key, tag, D("x"=>1); p_write=1.0, salience=1.0, provenance=prov)

invariant_ok = true
for i in 1:100
    observe!(store2, key, tag, D("x"=>i+1); p_write=1.0, salience=1.0, provenance=prov)
    for ml in store2.table[key]
        if ml.tag == tag && ml.provenance == prov
            if ml.mu + ml.nu + ml.pi > 1.0 + 1e-9
                println("FAIL at iter $i: sum=$(ml.mu+ml.nu+ml.pi)")
                invariant_ok = false
            end
        end
    end
end
if invariant_ok
    println("PASS")
else
    all_pass = false
end

# ── Test 5: Serialize/restore round-trip ──
print("[5] Serialize/restore round-trip after heavy reinforcement ... ")
snap = serialize_store(store)
store3 = SubconsciousStore()
try
    n = restore_store!(store3, snap)
    invariant_ok = true
    for (k, bucket) in store3.table
        for ml in bucket
            if ml.mu + ml.nu + ml.pi > 1.0 + 1e-9
                println("FAIL: restored sum=$(ml.mu+ml.nu+ml.pi)")
                invariant_ok = false
            end
        end
    end
    if invariant_ok
        println("PASS (restored $n entries)")
    else
        all_pass = false
    end
catch e
    println("FAIL - restore threw: $e")
    all_pass = false
end

# ── Test 6: Maturity transition ──
print("[6] Maturity transition - pi collapses below threshold ... ")
store4 = SubconsciousStore()
observe!(store4, "concept", :lexical, D("w"=>"hello"); p_write=1.0, salience=1.0, provenance=prov)

for ml in store4.table["concept"]
    if ml.provenance == prov
        print("starts IFML (pi=$(round(ml.pi,digits=3))) ... ")
    end
end

mature = false
for i in 1:30
    observe!(store4, "concept", :lexical, D("w"=>"hello$i"); p_write=1.0, salience=1.0, provenance=prov)
    for ml in store4.table["concept"]
        if ml.provenance == prov && is_entry_mature(ml)
            mature = true
        end
    end
    mature && break
end
if mature
    for ml in store4.table["concept"]
        if ml.provenance == prov
            println("PASS (mature, pi=$(round(ml.pi,digits=4)), mu=$(round(ml.mu,digits=4)))")
        end
    end
else
    println("FAIL - never matured")
    all_pass = false
end

# ── Test 7: Jitter variance ──
print("[7] _effective_weight jitter variance ... ")
ml_j = Microlog("jtest", :meta, D("x"=>1), 0.5, 0.05, 0.45, :test)
weights = Float64[]
for _ in 1:20
    push!(weights, SelfObserver._effective_weight(ml_j))
end
var_w = var(weights)
if var_w > 0.0
    println("PASS (var=$(round(var_w,digits=6)), mean=$(round(mean(weights),digits=4)))")
else
    println("FAIL - zero variance")
    all_pass = false
end

# ── Test 8: SubconsciousHint structural invariant ──
print("[8] SubconsciousHint structural invariant (zero Float64) ... ")
hint_fields = fieldnames(SubconsciousHint)
has_float = any(f -> fieldtype(SubconsciousHint, f) == Float64, hint_fields)
if !has_float
    println("PASS")
else
    println("FAIL")
    all_pass = false
end

# ── Test 9: Backward compat restore ──
print("[9] Backward compat - restore old weight format ... ")
old_snap = Dict{String,Any}(
    "table" => Dict{String,Any}(
        "old_key" => [Dict{String,Any}(
            "key" => "old_key",
            "tag" => "meta",
            "payload" => Dict{String,Any}("z" => 42),
            "weight" => 5.0,
            "timestamp" => time(),
            "provenance" => "legacy",
            "drop_table" => String["other_key"]
        )]
    ),
    "drop_tables" => Dict{String,Any}(),
    "total_entries" => 1
)
store5 = SubconsciousStore()
try
    n = restore_store!(store5, old_snap)
    if n == 1 && haskey(store5.table, "old_key")
        ml_old = store5.table["old_key"][1]
        if ml_old.mu + ml_old.nu + ml_old.pi ≈ 1.0
            println("PASS (migrated weight=5.0 -> mu=$(round(ml_old.mu,digits=3)))")
        else
            println("FAIL - bad IFS triple after migration")
            all_pass = false
        end
    else
        println("FAIL - restore count/key wrong")
        all_pass = false
    end
catch e
    println("FAIL - restore threw: $e")
    all_pass = false
end

# ── Test 10: ifs_reinforce_entry! public API ──
print("[10] ifs_reinforce_entry! public API ... ")
store6 = SubconsciousStore()
observe!(store6, "api_test", :relational, D("r"=>"x"); p_write=1.0, salience=1.0, provenance=prov)
result = ifs_reinforce_entry!(store6, "api_test", :relational, prov; positive=true, gain=0.05)
if result
    for ml in store6.table["api_test"]
        if ml.provenance == prov
            s = ifs_state(ml)
            if s.mu + s.nu + s.pi ≈ 1.0
                println("PASS (reinforced, IFS valid, mature=$(s.mature))")
            else
                println("FAIL - IFS invalid after public reinforce")
                all_pass = false
            end
        end
    end
else
    println("FAIL - reinforce returned false")
    all_pass = false
end

# ── Summary ──
println("\n" * "=" ^ 60)
if all_pass
    println("ALL TESTS PASSED")
else
    println("SOME TESTS FAILED")
end
println("=" ^ 60)

end # let block
