# test_immune.jl
# ==============================================================================
# GRUG IMMUNE SYSTEM TEST SUITE
# Tests the Specimen Immune System (automata-based anomaly handling).
# Every test is explicit. No silent failures. If something breaks, Grug screams.
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG IMMUNE SYSTEM TEST SUITE")
println("="^60)

# ==============================================================================
# 1. MODULE LOAD
# ==============================================================================
println("\n[1] MODULE LOAD")

include("../src/ImmuneSystem.jl")
using .ImmuneSystem
println("  ✓ ImmuneSystem module loaded")

# ==============================================================================
# 2. IMMUNE ERROR TYPE
# ==============================================================================
println("\n[2] IMMUNE ERROR TYPE")

err = ImmuneSystem.ImmuneError(:test_kind, UInt64(0xDEADBEEF), "test info")
@assert err.kind == :test_kind "FAIL: ImmuneError kind mismatch!"
@assert err.signature == UInt64(0xDEADBEEF) "FAIL: ImmuneError signature mismatch!"
@assert err.info == "test info" "FAIL: ImmuneError info mismatch!"
println("  ✓ ImmuneError struct fields correct")

# Test showerror doesn't crash
io = IOBuffer()
showerror(io, err)
err_str = String(take!(io))
@assert contains(err_str, "ImmuneError") "FAIL: showerror output missing ImmuneError!"
@assert contains(err_str, "deadbeef") "FAIL: showerror output missing hex signature!"
println("  ✓ showerror formats correctly: $err_str")

# ==============================================================================
# 3. IMMUNE LEDGER — APPEND-ONLY LOG
# ==============================================================================
println("\n[3] IMMUNE LEDGER")

# Reset state for clean test
ImmuneSystem.reset_immune_state!()

# Log some events
ImmuneSystem.log_immune_event!(:test_event_1, UInt64(100), "info1")
ImmuneSystem.log_immune_event!(:test_event_2, UInt64(200), "info2")
ImmuneSystem.log_immune_event!(:test_event_3, UInt64(300), nothing)

entries = ImmuneSystem.get_ledger_entries(10)
@assert length(entries) == 3 "FAIL: Expected 3 ledger entries, got $(length(entries))!"
@assert entries[1].kind == :test_event_1 "FAIL: First entry kind mismatch!"
@assert entries[2].signature == UInt64(200) "FAIL: Second entry signature mismatch!"
@assert entries[3].info === nothing "FAIL: Third entry info should be nothing!"
@assert entries[1].timestamp > 0.0 "FAIL: Timestamp should be positive!"
println("  ✓ Ledger append-only semantics work (3 entries)")

# Test get_ledger_entries returns last N
ImmuneSystem.log_immune_event!(:extra_1, UInt64(400), nothing)
ImmuneSystem.log_immune_event!(:extra_2, UInt64(500), nothing)
last2 = ImmuneSystem.get_ledger_entries(2)
@assert length(last2) == 2 "FAIL: Expected 2 entries, got $(length(last2))!"
@assert last2[1].kind == :extra_1 "FAIL: Last-2 should start with extra_1!"
@assert last2[2].kind == :extra_2 "FAIL: Last-2 should end with extra_2!"
println("  ✓ get_ledger_entries(2) returns last 2 entries")

# Test error on invalid n
err_caught = Ref(false)
try
    ImmuneSystem.get_ledger_entries(0)
catch e
    err_caught[] = true
end
@assert err_caught[] "FAIL: get_ledger_entries(0) should throw!"
println("  ✓ get_ledger_entries(0) correctly throws")

# ==============================================================================
# 4. HOPFIELD IMMUNE MEMORY
# ==============================================================================
println("\n[4] HOPFIELD IMMUNE MEMORY")

ImmuneSystem.reset_immune_state!()

sig1 = UInt64(0xAAAA)
sig2 = UInt64(0xBBBB)

# Initially unknown
@assert ImmuneSystem.lookup_signature(sig1) == 0 "FAIL: New signature should have count 0!"
@assert !ImmuneSystem.is_signature_known(sig1) "FAIL: New signature should not be known!"
println("  ✓ New signature returns count=0, known=false")

# Add signature once
ImmuneSystem.add_known_signature!(sig1)
@assert ImmuneSystem.lookup_signature(sig1) == 1 "FAIL: After 1 add, count should be 1!"
@assert !ImmuneSystem.is_signature_known(sig1) "FAIL: After 1 add, not yet strongly known!"
println("  ✓ After 1 add: count=1, known=false (threshold=$(ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD))")

# Add signature to threshold
for _ in 2:ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD
    ImmuneSystem.add_known_signature!(sig1)
end
@assert ImmuneSystem.is_signature_known(sig1) "FAIL: After $(ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD) adds, should be known!"
count1 = ImmuneSystem.lookup_signature(sig1)
@assert count1 == ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD "FAIL: Count should be $(ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD), got $count1!"
println("  ✓ After $(ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD) adds: count=$count1, known=true")

# Sig2 still unknown
@assert ImmuneSystem.lookup_signature(sig2) == 0 "FAIL: sig2 should still be unknown!"
println("  ✓ sig2 remains unknown (count=0)")

# ==============================================================================
# 5. AST SIGNATURE GENERATION
# ==============================================================================
println("\n[5] AST SIGNATURE GENERATION")

sig_a = ImmuneSystem.immune_ast_signature("hello world this is a test")
sig_b = ImmuneSystem.immune_ast_signature("goodbye earth that was a check")
sig_c = ImmuneSystem.immune_ast_signature("hello world this is a test")

@assert sig_a != UInt64(0) "FAIL: Signature should not be zero!"
@assert sig_a == sig_c "FAIL: Same input should produce same signature!"
println("  ✓ Same input → same signature (deterministic)")

# Different structure should produce different signature (usually)
sig_short = ImmuneSystem.immune_ast_signature("hi")
sig_long  = ImmuneSystem.immune_ast_signature("this is a much longer input with many more tokens and different structure entirely")
# Note: signatures CAN collide (hash collisions), but for very different structures they usually don't
println("  ✓ Signatures generated: short=0x$(string(sig_short, base=16)), long=0x$(string(sig_long, base=16))")

# JSON-like input
sig_json = ImmuneSystem.immune_ast_signature("""{"pattern":"hello","action_packet":"greet^1"}""")
@assert sig_json != UInt64(0) "FAIL: JSON signature should not be zero!"
println("  ✓ JSON input signature: 0x$(string(sig_json, base=16))")

# Empty input should throw
err_caught_ast = Ref(false)
try
    ImmuneSystem.immune_ast_signature("")
catch e
    err_caught_ast[] = true
end
@assert err_caught_ast[] "FAIL: Empty input should throw!"
println("  ✓ Empty input correctly throws")

# Whitespace-only input should throw
err_caught_ws = Ref(false)
try
    ImmuneSystem.immune_ast_signature("   ")
catch e
    err_caught_ws[] = true
end
@assert err_caught_ws[] "FAIL: Whitespace-only input should throw!"
println("  ✓ Whitespace-only input correctly throws")

# ==============================================================================
# 6. FUNKY DETECTION
# ==============================================================================
println("\n[6] FUNKY DETECTION")

ImmuneSystem.reset_immune_state!()

# Novel input with no Hopfield memory → funky
novel_sig = ImmuneSystem.immune_ast_signature("some completely unknown command text")
@assert ImmuneSystem.detect_funky(novel_sig, "some completely unknown command text") == true "FAIL: Novel input should be funky!"
println("  ✓ Novel non-JSON input detected as funky")

# JSON input is not funky (balanced structure)
json_sig = ImmuneSystem.immune_ast_signature("""{"pattern":"test","action":"greet"}""")
@assert ImmuneSystem.detect_funky(json_sig, """{"pattern":"test","action":"greet"}""") == false "FAIL: Valid JSON should not be funky!"
println("  ✓ Valid JSON input detected as non-funky")

# Unbalanced JSON is funky
bad_json = """{"pattern":"test","action":"greet" """
bad_json_sig = ImmuneSystem.immune_ast_signature(bad_json)
@assert ImmuneSystem.detect_funky(bad_json_sig, bad_json) == true "FAIL: Unbalanced JSON should be funky!"
println("  ✓ Unbalanced JSON detected as funky")

# After adding to Hopfield memory strongly, it becomes non-funky
for _ in 1:ImmuneSystem.HOPFIELD_FAMILIARITY_THRESHOLD
    ImmuneSystem.add_known_signature!(novel_sig)
end
@assert ImmuneSystem.detect_funky(novel_sig, "some completely unknown command text") == false "FAIL: Strongly known sig should not be funky!"
println("  ✓ After Hopfield strengthening, previously funky input becomes non-funky")

# ==============================================================================
# 7. QUARANTINE
# ==============================================================================
println("\n[7] QUARANTINE")

ImmuneSystem.reset_immune_state!()

q_sig = UInt64(0xCAFE)
qrecord = ImmuneSystem.quarantine_input!("suspicious input here", q_sig, 1)
@assert qrecord.original_text == "suspicious input here" "FAIL: Quarantine text mismatch!"
@assert qrecord.signature == q_sig "FAIL: Quarantine sig mismatch!"
@assert qrecord.patch_attempted == false "FAIL: Patch should not be attempted yet!"
@assert qrecord.patch_result == :pending "FAIL: Patch result should be :pending!"
@assert qrecord.agent_id == 1 "FAIL: Agent ID should be 1!"
@assert qrecord.quarantined_at > 0.0 "FAIL: Quarantine timestamp should be positive!"
println("  ✓ Quarantine record created correctly")

# Check ledger has quarantine entry
entries_q = ImmuneSystem.get_ledger_entries(5)
quarantine_logged = any(e -> e.kind == :quarantine && e.signature == q_sig, entries_q)
@assert quarantine_logged "FAIL: Quarantine event should be in ledger!"
println("  ✓ Quarantine event logged in ledger")

# Empty input should throw
err_caught_q = Ref(false)
try
    ImmuneSystem.quarantine_input!("", UInt64(0), 1)
catch e
    err_caught_q[] = true
end
@assert err_caught_q[] "FAIL: Empty quarantine input should throw!"
println("  ✓ Empty quarantine input correctly throws")

# ==============================================================================
# 8. PATCH ATTEMPT
# ==============================================================================
println("\n[8] PATCH ATTEMPT")

# Good input should patch successfully (has recognizable tokens + reasonable length + clean encoding)
good_result = ImmuneSystem.attempt_patch("/grow {\"pattern\":\"test\"}", UInt64(0x1111))
@assert good_result == :success "FAIL: Good input should patch successfully, got $good_result!"
println("  ✓ Good input patches successfully")

# Very short clean text should patch (reasonable length + clean encoding = 2/3)
short_result = ImmuneSystem.attempt_patch("hello", UInt64(0x2222))
@assert short_result == :success "FAIL: Short clean text should patch, got $short_result!"
println("  ✓ Short clean text patches successfully")

# Input with excessive control characters should fail
bad_input = String(UInt8[0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
bad_result = ImmuneSystem.attempt_patch(bad_input, UInt64(0x3333))
@assert bad_result == :failure "FAIL: Control-heavy input should fail patch, got $bad_result!"
println("  ✓ Control-heavy input fails patch")

# Empty input should throw
err_caught_p = Ref(false)
try
    ImmuneSystem.attempt_patch("", UInt64(0))
catch e
    err_caught_p[] = true
end
@assert err_caught_p[] "FAIL: Empty patch input should throw!"
println("  ✓ Empty patch input correctly throws")

# Verify patch events are in ledger
ledger_after_patch = ImmuneSystem.get_ledger_entries(20)
has_patch_success = any(e -> e.kind == :patch_success, ledger_after_patch)
has_patch_failure = any(e -> e.kind == :patch_failure, ledger_after_patch)
@assert has_patch_success "FAIL: Ledger should have :patch_success entry!"
@assert has_patch_failure "FAIL: Ledger should have :patch_failure entry!"
println("  ✓ Patch success and failure events logged in ledger")

# ==============================================================================
# 9. DELETE INPUT
# ==============================================================================
println("\n[9] DELETE INPUT")

ImmuneSystem.reset_immune_state!()

ImmuneSystem.delete_input!("bad berry to crush", UInt64(0xDEAD))
del_entries = ImmuneSystem.get_ledger_entries(5)
has_delete = any(e -> e.kind == :delete && e.signature == UInt64(0xDEAD), del_entries)
@assert has_delete "FAIL: Delete event should be in ledger!"
println("  ✓ Delete event logged in ledger with correct signature")

# ==============================================================================
# 10. FULL IMMUNE SCAN — MATURITY GATE
# ==============================================================================
println("\n[10] FULL IMMUNE SCAN — MATURITY GATE")

ImmuneSystem.reset_immune_state!()

# Below maturity threshold → immune system sleeping
status_immature, sig_immature = ImmuneSystem.immune_scan!("test input", 500; is_critical=true)
@assert status_immature == :immature "FAIL: Below 1000 nodes should return :immature, got $status_immature!"
@assert sig_immature == UInt64(0) "FAIL: Immature scan should return sig=0!"
println("  ✓ Below maturity (500 nodes): :immature returned")

# At exactly threshold → immune system active
status_threshold, sig_threshold = ImmuneSystem.immune_scan!("test input for mature", 1000; is_critical=true)
@assert status_threshold != :immature "FAIL: At 1000 nodes should NOT return :immature!"
println("  ✓ At maturity (1000 nodes): $(status_threshold) returned (immune active)")

# Negative node count should throw
err_caught_neg = Ref(false)
try
    ImmuneSystem.immune_scan!("test", -1; is_critical=true)
catch e
    err_caught_neg[] = true
end
@assert err_caught_neg[] "FAIL: Negative node_count should throw!"
println("  ✓ Negative node_count correctly throws")

# Empty input should throw
err_caught_empty = Ref(false)
try
    ImmuneSystem.immune_scan!("", 1500; is_critical=true)
catch e
    err_caught_empty[] = true
end
@assert err_caught_empty[] "FAIL: Empty input should throw!"
println("  ✓ Empty input correctly throws")

# ==============================================================================
# 11. FULL IMMUNE SCAN — NON-FUNKY PATH
# ==============================================================================
println("\n[11] FULL IMMUNE SCAN — NON-FUNKY PATH")

ImmuneSystem.reset_immune_state!()

# JSON input should be non-funky and stored in Hopfield
json_input = """{"pattern":"hello world","action_packet":"greet^2","data":{"system_prompt":"Hi"}}"""
status_nf, sig_nf = ImmuneSystem.immune_scan!(json_input, 2000; is_critical=true)
@assert status_nf == :nonfunky "FAIL: Valid JSON should be :nonfunky, got $status_nf!"
@assert sig_nf != UInt64(0) "FAIL: Signature should not be zero for mature scan!"
@assert ImmuneSystem.lookup_signature(sig_nf) >= 1 "FAIL: Non-funky sig should be added to Hopfield!"
println("  ✓ Valid JSON: :nonfunky, signature stored in Hopfield memory")

# Calling again should still be non-funky (Hopfield strengthening)
status_nf2, sig_nf2 = ImmuneSystem.immune_scan!(json_input, 2000; is_critical=true)
@assert status_nf2 == :nonfunky "FAIL: Same input second time should still be :nonfunky!"
@assert sig_nf2 == sig_nf "FAIL: Same input should produce same signature!"
@assert ImmuneSystem.lookup_signature(sig_nf) >= 2 "FAIL: Count should be >= 2 after second scan!"
println("  ✓ Second scan of same input: :nonfunky, Hopfield count=$(ImmuneSystem.lookup_signature(sig_nf))")

# ==============================================================================
# 12. FULL IMMUNE SCAN — FUNKY PATH (COINFLIP + PATCH)
# ==============================================================================
println("\n[12] FULL IMMUNE SCAN — FUNKY PATH")

ImmuneSystem.reset_immune_state!()

# Use a non-JSON novel input that will be funky
# Run multiple times to observe stochastic behavior
Random.seed!(42)  # Seed for reproducibility

funky_input = "zzz_completely_alien_structure_never_seen_before"
n_trials = 100
results = Symbol[]

for _ in 1:n_trials
    ImmuneSystem.reset_immune_state!()  # Fresh state each trial
    try
        status, _ = ImmuneSystem.immune_scan!(funky_input, 2000; is_critical=true)
        push!(results, status)
    catch e
        if e isa ImmuneSystem.ImmuneError
            push!(results, :deleted)
        else
            rethrow(e)
        end
    end
end

# Should see a mix of :coinflip_skip and :patched/:deleted
n_skip    = count(r -> r == :coinflip_skip, results)
n_patched = count(r -> r == :patched, results)
n_deleted = count(r -> r == :deleted, results)

println("  Stochastic results over $n_trials trials:")
println("    coinflip_skip: $n_skip ($(round(n_skip/n_trials*100, digits=1))%)")
println("    patched:       $n_patched ($(round(n_patched/n_trials*100, digits=1))%)")
println("    deleted:       $n_deleted ($(round(n_deleted/n_trials*100, digits=1))%)")

# GRUG: With 2000 nodes → ~666 automata, each coinflipping 50/50,
# probability ALL skip = (0.5)^666 ≈ 0. So coinflip_skip should be very rare.
# Most trials should result in :patched or :deleted.
@assert (n_patched + n_deleted) > 0 "FAIL: Some trials should result in patched or deleted!"
println("  ✓ Funky input triggers automata response (patched+deleted > 0)")

# ==============================================================================
# 13. FULL IMMUNE SCAN — NON-CRITICAL PATH
# ==============================================================================
println("\n[13] FULL IMMUNE SCAN — NON-CRITICAL PATH")

ImmuneSystem.reset_immune_state!()

# Non-critical funky input should get a pass (logged but not quarantined)
status_nc, sig_nc = ImmuneSystem.immune_scan!("zzz_alien_but_noncritical", 2000; is_critical=false)
@assert status_nc == :nonfunky "FAIL: Non-critical funky should return :nonfunky (pass-through), got $status_nc!"
println("  ✓ Non-critical funky input: passed through as :nonfunky")

# Check ledger has noncritical_pass event
nc_entries = ImmuneSystem.get_ledger_entries(10)
has_nc_pass = any(e -> e.kind == :noncritical_pass, nc_entries)
@assert has_nc_pass "FAIL: Ledger should have :noncritical_pass entry!"
println("  ✓ Non-critical pass logged in ledger")

# ==============================================================================
# 14. POPULATION COINFLIP STATISTICS
# ==============================================================================
println("\n[14] POPULATION COINFLIP STATISTICS")

# Test with very small population (3 nodes → 1 automata)
# Coinflip should roughly 50/50
Random.seed!(123)
small_pop_results = Symbol[]
for _ in 1:200
    ImmuneSystem.reset_immune_state!()
    try
        status, _ = ImmuneSystem.immune_scan!("zzz_alien_small_pop", 3; is_critical=true)
        push!(small_pop_results, status)
    catch e
        if e isa ImmuneSystem.ImmuneError
            push!(small_pop_results, :deleted)
        else
            rethrow(e)
        end
    end
end

# 3 nodes → below maturity threshold → all should be :immature
n_immature = count(r -> r == :immature, small_pop_results)
@assert n_immature == 200 "FAIL: All results with 3 nodes should be :immature!"
println("  ✓ 3 nodes → all :immature (maturity gate working)")

# Test with exactly 1000 nodes (1000/3 ≈ 333 automata)
# With 333 automata, P(all skip) = (0.5)^333 ≈ 0
Random.seed!(456)
med_pop_results = Symbol[]
for _ in 1:50
    ImmuneSystem.reset_immune_state!()
    try
        status, _ = ImmuneSystem.immune_scan!("zzz_alien_med_pop_test", 1000; is_critical=true)
        push!(med_pop_results, status)
    catch e
        if e isa ImmuneSystem.ImmuneError
            push!(med_pop_results, :deleted)
        else
            rethrow(e)
        end
    end
end
n_active = count(r -> r != :immature && r != :coinflip_skip, med_pop_results)
@assert n_active > 0 "FAIL: With 333 automata, at least some should materialize!"
println("  ✓ 1000 nodes → $n_active/50 trials had materialized agents")

# ==============================================================================
# 15. RESET STATE
# ==============================================================================
println("\n[15] RESET STATE")

# Add some state
ImmuneSystem.add_known_signature!(UInt64(0x1))
ImmuneSystem.add_known_signature!(UInt64(0x2))
ImmuneSystem.log_immune_event!(:test, UInt64(0), nothing)

# Verify state exists
@assert ImmuneSystem.lookup_signature(UInt64(0x1)) > 0 "FAIL: Sig should exist before reset!"

# Reset
ImmuneSystem.reset_immune_state!()
@assert ImmuneSystem.lookup_signature(UInt64(0x1)) == 0 "FAIL: Sig should be gone after reset!"
@assert length(ImmuneSystem.get_ledger_entries(100)) == 0 "FAIL: Ledger should be empty after reset!"
println("  ✓ reset_immune_state! clears all state")

# ==============================================================================
# 16. SERIALIZATION / DESERIALIZATION
# ==============================================================================
println("\n[16] SERIALIZATION / DESERIALIZATION")

ImmuneSystem.reset_immune_state!()

# Build some state
for _ in 1:5
    ImmuneSystem.add_known_signature!(UInt64(0xAAAA))
end
ImmuneSystem.add_known_signature!(UInt64(0xBBBB))
ImmuneSystem.log_immune_event!(:test_save_1, UInt64(0xAAAA), "saved event 1")
ImmuneSystem.log_immune_event!(:test_save_2, UInt64(0xBBBB), "saved event 2")

# Serialize
data = ImmuneSystem.serialize_immune_state()
@assert haskey(data, "hopfield") "FAIL: Serialized data missing hopfield!"
@assert haskey(data, "ledger") "FAIL: Serialized data missing ledger!"
@assert length(data["hopfield"]) == 2 "FAIL: Should have 2 Hopfield entries!"
@assert length(data["ledger"]) > 0 "FAIL: Should have ledger entries!"
println("  ✓ Serialized: $(length(data["hopfield"])) Hopfield entries, $(length(data["ledger"])) ledger entries")

# Reset and deserialize
ImmuneSystem.reset_immune_state!()
@assert ImmuneSystem.lookup_signature(UInt64(0xAAAA)) == 0 "FAIL: Should be empty after reset!"

ImmuneSystem.deserialize_immune_state!(data)
@assert ImmuneSystem.lookup_signature(UInt64(0xAAAA)) == 5 "FAIL: AAAA should be restored with count 5!"
@assert ImmuneSystem.lookup_signature(UInt64(0xBBBB)) == 1 "FAIL: BBBB should be restored with count 1!"

restored_ledger = ImmuneSystem.get_ledger_entries(100)
@assert length(restored_ledger) > 0 "FAIL: Ledger should have entries after deserialize!"
has_save_1 = any(e -> e.kind == :test_save_1, restored_ledger)
has_save_2 = any(e -> e.kind == :test_save_2, restored_ledger)
@assert has_save_1 "FAIL: Restored ledger missing :test_save_1!"
@assert has_save_2 "FAIL: Restored ledger missing :test_save_2!"
println("  ✓ Deserialized: Hopfield memory and ledger restored correctly")

# ==============================================================================
# 17. STATUS DIAGNOSTICS
# ==============================================================================
println("\n[17] STATUS DIAGNOSTICS")

status = ImmuneSystem.get_immune_status()
@assert haskey(status, "ledger_entries") "FAIL: Status missing ledger_entries!"
@assert haskey(status, "hopfield_signatures") "FAIL: Status missing hopfield_signatures!"
@assert haskey(status, "quarantine_depth") "FAIL: Status missing quarantine_depth!"
@assert haskey(status, "maturity_threshold") "FAIL: Status missing maturity_threshold!"
@assert haskey(status, "event_counts") "FAIL: Status missing event_counts!"
@assert status["maturity_threshold"] == ImmuneSystem.MATURITY_THRESHOLD "FAIL: Maturity threshold mismatch!"
@assert status["hopfield_signatures"] == 2 "FAIL: Should have 2 Hopfield signatures!"
println("  ✓ get_immune_status() returns all expected fields")
println("    Ledger: $(status["ledger_entries"]), Hopfield: $(status["hopfield_signatures"]), Quarantine: $(status["quarantine_depth"])")

# ==============================================================================
# 18. THREAD SAFETY — CONCURRENT ACCESS
# ==============================================================================
println("\n[18] THREAD SAFETY")

ImmuneSystem.reset_immune_state!()

# Spawn many concurrent operations
n_ops = 100
tasks = Task[]
for i in 1:n_ops
    t = @async begin
        ImmuneSystem.add_known_signature!(UInt64(i % 10))
        ImmuneSystem.log_immune_event!(:concurrent_test, UInt64(i), "task $i")
    end
    push!(tasks, t)
end

# Wait for all tasks
for t in tasks
    wait(t)
end

# Verify state is consistent
total_hopfield = sum(ImmuneSystem.lookup_signature(UInt64(i)) for i in 0:9)
@assert total_hopfield == n_ops "FAIL: Expected $n_ops total Hopfield adds, got $total_hopfield!"
ledger_entries = ImmuneSystem.get_ledger_entries(500)
# Each add_known_signature logs :nonfunky_stored, plus the :concurrent_test logs
concurrent_count = count(e -> e.kind == :concurrent_test, ledger_entries)
@assert concurrent_count == n_ops "FAIL: Expected $n_ops concurrent_test entries, got $concurrent_count!"
println("  ✓ $n_ops concurrent operations completed without data corruption")

# ==============================================================================
# 19. NO SILENT FAILURES — ERROR SURFACE COVERAGE
# ==============================================================================
println("\n[19] NO SILENT FAILURES — ERROR SURFACE COVERAGE")

# Every function that can fail should throw, never return silently
error_tests = [
    ("immune_ast_signature empty", () -> ImmuneSystem.immune_ast_signature("")),
    ("immune_ast_signature whitespace", () -> ImmuneSystem.immune_ast_signature("   ")),
    ("immune_scan! empty", () -> ImmuneSystem.immune_scan!("", 1500; is_critical=true)),
    ("immune_scan! negative nodes", () -> ImmuneSystem.immune_scan!("test", -1; is_critical=true)),
    ("quarantine_input! empty", () -> ImmuneSystem.quarantine_input!("", UInt64(0), 1)),
    ("attempt_patch empty", () -> ImmuneSystem.attempt_patch("", UInt64(0))),
    ("get_ledger_entries zero", () -> ImmuneSystem.get_ledger_entries(0)),
    ("get_ledger_entries negative", () -> ImmuneSystem.get_ledger_entries(-5)),
]

for (name, fn) in error_tests
    caught = Ref(false)
    try
        fn()
    catch e
        caught[] = true
    end
    @assert caught[] "FAIL: '$name' should throw but didn't!"
    println("  ✓ $name → throws correctly")
end

# ==============================================================================
# 20. LEDGER TRIMMING (overflow protection)
# ==============================================================================
println("\n[20] LEDGER TRIMMING")

ImmuneSystem.reset_immune_state!()

# Fill ledger beyond MAX_LEDGER_ENTRIES
for i in 1:(ImmuneSystem.MAX_LEDGER_ENTRIES + 500)
    ImmuneSystem.log_immune_event!(:overflow_test, UInt64(i), nothing)
end

final_entries = ImmuneSystem.get_ledger_entries(ImmuneSystem.MAX_LEDGER_ENTRIES + 100)
@assert length(final_entries) <= ImmuneSystem.MAX_LEDGER_ENTRIES "FAIL: Ledger should be trimmed to MAX_LEDGER_ENTRIES!"
println("  ✓ Ledger trimmed to $(length(final_entries)) entries (max=$(ImmuneSystem.MAX_LEDGER_ENTRIES))")

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("✅  ALL IMMUNE SYSTEM TESTS PASSED (20 groups)")
println("="^60 * "\n")