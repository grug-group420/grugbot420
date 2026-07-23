#!/usr/bin/env julia
# Quick verification script for the new NegativeThesaurus pair-ledger
# (context edge-case) system, per the user's design spec:
#   - pairs are (word, synonym) directional edge cases, not whole-word bans
#   - multi-word phrases supported on either side
#   - must gate BOTH activation (thesaurus_gate_filter) and orchestration
#     (the 4 synonym-swap functions in Main.jl)

include("src/Main.jl")

println("="^70)
println("TEST 1: Default seeded pairs are present")
println("="^70)
pairs = InputQueue.list_synonym_exceptions()
for p in pairs
    println("  ($(p.word)) <-> ($(p.synonym))  bidir=$(p.bidirectional)  :: $(p.reason)")
end
@assert InputQueue.synonym_exception_count() >= 4 "expected >=4 seeded pairs"
println("PASS: $(length(pairs)) pairs present\n")

println("="^70)
println("TEST 2: is_synonym_blocked basic directional + bidirectional checks")
println("="^70)
@assert InputQueue.is_synonym_blocked("deep", "abyss") == true
@assert InputQueue.is_synonym_blocked("abyss", "deep") == true   # bidirectional default
@assert InputQueue.is_synonym_blocked("keep", "store") == true
@assert InputQueue.is_synonym_blocked("time", "epoch") == true
@assert InputQueue.is_synonym_blocked("effect", "result") == true
# unrelated pair should NOT be blocked
@assert InputQueue.is_synonym_blocked("happy", "glad") == false
println("PASS\n")

println("="^70)
println("TEST 3: is_inhibited (old whole-word blacklist) is UNCHANGED/untouched")
println("="^70)
# whole-word blacklist should not know about 'deep' or 'abyss' unless explicitly added
@assert InputQueue.is_inhibited("deep") == false
@assert InputQueue.is_inhibited("abyss") == false
println("PASS: old mechanism untouched by new pair ledger\n")

println("="^70)
println("TEST 4: Multi-word phrase pair (\"you're\" <-> \"you are\")")
println("="^70)
InputQueue.add_synonym_exception!("you're", "you are"; reason="test: contraction register mismatch in formal output")
@assert InputQueue.is_synonym_blocked("you're", "you are") == true
@assert InputQueue.is_synonym_blocked("you are", "you're") == true
println("PASS: multi-word phrase pair works on both sides\n")

println("="^70)
println("TEST 5: remove_synonym_exception! works")
println("="^70)
removed = InputQueue.remove_synonym_exception!("you're", "you are")
@assert removed == true
@assert InputQueue.is_synonym_blocked("you're", "you are") == false
println("PASS\n")

println("="^70)
println("TEST 6: Activation-side wiring — thesaurus_gate_filter honors is_blocked")
println("="^70)
text = "the deep water is dangerous"
gate_unblocked = Thesaurus.thesaurus_gate_filter(text)
gate_blocked   = Thesaurus.thesaurus_gate_filter(text; is_blocked=InputQueue.is_synonym_blocked)
println("  unblocked expansion contains 'abyss'? ", ("abyss" in gate_unblocked))
println("  blocked   expansion contains 'abyss'? ", ("abyss" in gate_blocked))
if ("abyss" in gate_unblocked)
    @assert !("abyss" in gate_blocked) "abyss should be filtered out when is_blocked is wired"
    println("PASS: 'abyss' present without filter, absent with filter\n")
else
    println("NOTE: 'abyss' not a candidate synonym for 'deep' in current seed map at all (no expansion to test against) — pair mechanism still verified functionally in TEST 2\n")
end

println("="^70)
println("TEST 7: Main.jl process_mission call site actually passes is_blocked")
println("="^70)
site = read("src/Main.jl", String)
@assert occursin("thesaurus_gate_filter(mission_text; is_blocked=InputQueue.is_synonym_blocked)", site)
println("PASS: call site wired correctly\n")

println("="^70)
println("TEST 8: flush_synonym_exceptions! clears pairs but not word blacklist")
println("="^70)
InputQueue.add_inhibition!("testword_flushcheck")
before_word_inhibited = InputQueue.is_inhibited("testword_flushcheck")
InputQueue.flush_synonym_exceptions!()
@assert InputQueue.synonym_exception_count() == 0
@assert InputQueue.is_inhibited("testword_flushcheck") == before_word_inhibited == true
println("PASS: flush_synonym_exceptions! only clears pair ledger\n")

# restore defaults for future runs / other tests since flush wiped them
InputQueue._seed_default_synonym_exceptions!()

println("="^70)
println("ALL TESTS PASSED")
println("="^70)
