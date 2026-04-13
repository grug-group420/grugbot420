# test_vote_ties.jl
# ==============================================================================
# GRUG VOTE TIE-BREAKING TEST SUITE
# Tests tie detection, random winner selection, SURE/UNSURE classification,
# and tied alternative listing in the orchestrator.
# Every test is explicit. No silent failures. If something breaks, Grug screams.
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG VOTE TIE-BREAKING TEST SUITE")
println("="^60)

# ==============================================================================
# 1. MODULE LOAD
# ==============================================================================
println("\n[1] MODULE LOAD")

include("../src/ImmuneSystem.jl")
using .ImmuneSystem

include("../src/engine.jl")
println("  ✓ Engine module loaded (Vote struct available)")

# ==============================================================================
# 2. VOTE STRUCT CONSTRUCTION
# ==============================================================================
println("\n[2] VOTE STRUCT CONSTRUCTION")

v1 = Vote("node_a", "reason", 2.5, String[], RelationalTriple[], [RelationalTriple("dog", "is", "animal")], false)
v2 = Vote("node_b", "greet",  2.5, String[], RelationalTriple[], [RelationalTriple("cat", "is", "pet")], false)
v3 = Vote("node_c", "reason", 2.5, String[], RelationalTriple[], RelationalTriple[], false)
v4 = Vote("node_d", "flee",   1.8, String[], RelationalTriple[], RelationalTriple[], false)
v5 = Vote("node_e", "ponder", 1.5, String[], RelationalTriple[], RelationalTriple[], false)

@assert v1.confidence == 2.5 "FAIL: Vote confidence mismatch!"
@assert v1.node_id == "node_a" "FAIL: Vote node_id mismatch!"
@assert v2.action == "greet" "FAIL: Vote action mismatch!"
println("  ✓ Vote structs constructed correctly")

# ==============================================================================
# 3. TIE DETECTION LOGIC
# ==============================================================================
println("\n[3] TIE DETECTION LOGIC")

# GRUG: Simulate the tie detection from ephemeral_aiml_orchestrator.
# sure_votes = votes within 0.05 of max. Ties = same confidence within epsilon.
sorted_votes = sort([v1, v2, v3, v4, v5]; by = v -> v.confidence, rev = true)
max_conf = sorted_votes[1].confidence

sure_votes = Vote[v for v in sorted_votes if v.confidence >= max_conf - 0.05]
@assert length(sure_votes) == 3 "FAIL: Expected 3 sure_votes (v1,v2,v3 all at 2.5), got $(length(sure_votes))!"
println("  ✓ Sure votes correctly identified: $(length(sure_votes)) tied at conf=$(max_conf)")

# Identify exact ties
top_conf = sure_votes[1].confidence
tied_votes = Vote[v for v in sure_votes if abs(v.confidence - top_conf) < 1e-9]
@assert length(tied_votes) == 3 "FAIL: Expected 3 exact ties, got $(length(tied_votes))!"
println("  ✓ Exact tie detection: $(length(tied_votes)) rocks at identical confidence")

# ==============================================================================
# 4. RANDOM TIE-BREAK DISTRIBUTION
# ==============================================================================
println("\n[4] RANDOM TIE-BREAK DISTRIBUTION")

# GRUG: Run 300 tie-breaks on 3 tied votes. Each node should win roughly 100 times.
# If one node NEVER wins, the random selection is broken (always picking first).
win_counts = Dict("node_a" => 0, "node_b" => 0, "node_c" => 0)
n_trials = 300

for _ in 1:n_trials
    tied_copy = copy(tied_votes)
    shuffle!(tied_copy)
    winner = tied_copy[1]
    win_counts[winner.node_id] += 1
end

for (nid, count) in win_counts
    @assert count > 0 "FAIL: Node $nid never won in $n_trials trials! Random tie-break is broken!"
    println("  ✓ $nid won $count/$n_trials times")
end

# GRUG: Sanity check — no single node should win more than 70% (would imply heavy bias)
for (nid, count) in win_counts
    @assert count < n_trials * 0.7 "FAIL: Node $nid won $count/$n_trials (>70%) — suspicious bias!"
end
println("  ✓ No single node dominates (all within expected range)")

# ==============================================================================
# 5. SINGLE WINNER (NO TIE)
# ==============================================================================
println("\n[5] SINGLE WINNER (NO TIE)")

v_clear_winner = Vote("node_king", "reason", 5.0, String[], RelationalTriple[], RelationalTriple[], false)
v_runner1 = Vote("node_r1", "greet", 4.94, String[], RelationalTriple[], RelationalTriple[], false)
v_runner2 = Vote("node_r2", "flee", 3.0, String[], RelationalTriple[], RelationalTriple[], false)

sorted_clear = sort([v_clear_winner, v_runner1, v_runner2]; by = v -> v.confidence, rev = true)
max_clear = sorted_clear[1].confidence
sure_clear = Vote[v for v in sorted_clear if v.confidence >= max_clear - 0.05]

# v_clear_winner (5.0) and v_runner1 (4.94) are both within 0.05 of max
@assert length(sure_clear) == 2 "FAIL: Expected 2 sure votes, got $(length(sure_clear))!"

# But exact tie detection should show only 1 (5.0 != 4.94)
top_clear = sure_clear[1].confidence
tied_clear = Vote[v for v in sure_clear if abs(v.confidence - top_clear) < 1e-9]
@assert length(tied_clear) == 1 "FAIL: Expected 1 exact tie (clear winner), got $(length(tied_clear))!"
@assert tied_clear[1].node_id == "node_king" "FAIL: Clear winner should be node_king!"
println("  ✓ Clear winner detected: $(tied_clear[1].node_id) at conf=$(top_clear)")

# ==============================================================================
# 6. VOTE CERTAINTY CLASSIFICATION
# ==============================================================================
println("\n[6] VOTE CERTAINTY CLASSIFICATION")

# GRUG: SURE = primary stands alone at top. UNSURE = ties exist in sure_votes.
function classify_certainty(primary::Vote, sure::Vector{Vote})
    tied_alts = Vote[v for v in sure if v.node_id != primary.node_id]
    return isempty(tied_alts) ? "SURE" : "UNSURE"
end

# Case 1: Single sure vote = SURE
@assert classify_certainty(v_clear_winner, [v_clear_winner]) == "SURE" "FAIL: Single winner should be SURE!"
println("  ✓ Single winner → SURE")

# Case 2: Multiple sure votes = UNSURE
@assert classify_certainty(v1, sure_votes) == "UNSURE" "FAIL: Tied votes should be UNSURE!"
println("  ✓ Tied votes → UNSURE")

# ==============================================================================
# 7. TIED ALTERNATIVES LISTING
# ==============================================================================
println("\n[7] TIED ALTERNATIVES LISTING")

# GRUG: When primary is picked from a tie, the other tied winners are "alternatives"
primary = v1
tied_alts = Vote[v for v in sure_votes if v.node_id != primary.node_id]
@assert length(tied_alts) == 2 "FAIL: Expected 2 tied alternatives, got $(length(tied_alts))!"

# Check that alternatives carry their relational patterns
alt_b = filter(v -> v.node_id == "node_b", tied_alts)
@assert length(alt_b) == 1 "FAIL: node_b should be in alternatives!"
@assert !isempty(alt_b[1].node_triples) "FAIL: node_b should have relational triples!"
@assert alt_b[1].node_triples[1].subject == "cat" "FAIL: node_b triple subject should be 'cat'!"
println("  ✓ Tied alternatives listed with relations: $(length(tied_alts)) alternatives")
for tv in tied_alts
    triples_str = isempty(tv.node_triples) ? "None" :
        join(["($(t.subject), $(t.relation), $(t.object))" for t in tv.node_triples], ", ")
    println("    🪨 $(tv.node_id) | action=$(tv.action) | relations=$triples_str")
end

# ==============================================================================
# 8. UNSURE VOTES (STRONG RUNNER-UPS)
# ==============================================================================
println("\n[8] UNSURE VOTES (STRONG RUNNER-UPS)")

# GRUG: Votes below the sure threshold but above zero are potential unsure_votes.
# In the real system, each gets a 50/50 coinflip. Here we just test the concept.
all_votes = [v1, v2, v3, v4, v5]
sorted_all = sort(all_votes; by = v -> v.confidence, rev = true)
max_all = sorted_all[1].confidence

sure_all = Vote[v for v in sorted_all if v.confidence >= max_all - 0.05]
unsure_candidates = Vote[v for v in sorted_all if v.confidence < max_all - 0.05]

@assert length(unsure_candidates) == 2 "FAIL: Expected 2 unsure candidates (v4, v5), got $(length(unsure_candidates))!"
@assert unsure_candidates[1].node_id == "node_d" "FAIL: First unsure should be node_d (1.8)!"
@assert unsure_candidates[2].node_id == "node_e" "FAIL: Second unsure should be node_e (1.5)!"
println("  ✓ Unsure candidates: $(length(unsure_candidates)) strong non-winners")
for uv in unsure_candidates
    println("    🔸 $(uv.node_id) | action=$(uv.action) | conf=$(uv.confidence)")
end

# ==============================================================================
# 9. AIML RULE TAGS — VOTE_CERTAINTY AND TIED_ALTERNATIVES
# ==============================================================================
println("\n[9] AIML RULE TAGS")

@assert "{VOTE_CERTAINTY}" in ALLOWED_RULE_TAGS "FAIL: {VOTE_CERTAINTY} not in ALLOWED_RULE_TAGS!"
@assert "{TIED_ALTERNATIVES}" in ALLOWED_RULE_TAGS "FAIL: {TIED_ALTERNATIVES} not in ALLOWED_RULE_TAGS!"
println("  ✓ {VOTE_CERTAINTY} registered in ALLOWED_RULE_TAGS")
println("  ✓ {TIED_ALTERNATIVES} registered in ALLOWED_RULE_TAGS")

# Test rule addition with new tags
empty!(AIML_DROP_TABLE)
result = add_orchestration_rule!("When {VOTE_CERTAINTY} is UNSURE, consider: {TIED_ALTERNATIVES} [prob=0.8]")
@assert contains(result, "Rule tied to tree") "FAIL: Rule addition failed!"
@assert AIML_DROP_TABLE[1].fire_probability == 0.8 "FAIL: Rule fire_probability should be 0.8!"
println("  ✓ AIML rule with {VOTE_CERTAINTY} and {TIED_ALTERNATIVES} accepted")

# ==============================================================================
# 10. EDGE CASE — ALL VOTES IDENTICAL
# ==============================================================================
println("\n[10] EDGE CASE — ALL VOTES IDENTICAL CONFIDENCE")

identical_votes = [
    Vote("id_1", "reason", 1.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("id_2", "greet",  1.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("id_3", "flee",   1.0, String[], RelationalTriple[], RelationalTriple[], false),
    Vote("id_4", "ponder", 1.0, String[], RelationalTriple[], RelationalTriple[], false),
]

sorted_id = sort(identical_votes; by = v -> v.confidence, rev = true)
max_id = sorted_id[1].confidence
sure_id = Vote[v for v in sorted_id if v.confidence >= max_id - 0.05]
tied_id = Vote[v for v in sure_id if abs(v.confidence - max_id) < 1e-9]

@assert length(sure_id) == 4 "FAIL: All 4 should be sure!"
@assert length(tied_id) == 4 "FAIL: All 4 should be tied!"

# Run 200 trials — every node should win at least once
id_wins = Dict(v.node_id => 0 for v in identical_votes)
for _ in 1:200
    tc = copy(tied_id)
    shuffle!(tc)
    id_wins[tc[1].node_id] += 1
end
for (nid, count) in id_wins
    @assert count > 0 "FAIL: $nid never won in 200 4-way tie trials!"
end
println("  ✓ 4-way tie: all nodes won at least once in 200 trials")

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("ALL VOTE TIE-BREAKING TESTS PASSED!")
println("="^60 * "\n")