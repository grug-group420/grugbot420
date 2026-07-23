#!/usr/bin/env python3
"""Patch Main.jl for v8.26g per-group vote selection."""
import re

with open('src/Main.jl', 'r') as f:
    content = f.read()

# Find the section from "select_aiml_votes" call through node validation
# Lines 1842-1898
old_start = '    top_tier, subtop_tier, rejected_tier = VoteOrchestrator.select_aiml_votes(\n        vote_candidates;\n        threshold  = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,\n        top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW\n    )'
old_end = '    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)\n    if isnothing(node)\n        error("!!! FATAL: Winning node $(primary_vote.node_id) vanished before Grug could grab it! !!!")\n    end'

start_idx = content.find(old_start)
end_idx = content.find(old_end)
if start_idx == -1 or end_idx == -1:
    print(f"ERROR: Could not find markers. start={start_idx}, end={end_idx}")
    # Try to find parts
    if content.find('select_aiml_votes(') == -1:
        print("  select_aiml_votes not found")
    if content.find('FATAL: Winning node') == -1:
        print("  FATAL: Winning node not found")
    exit(1)

# Include the end marker in the replacement
end_marker_end = end_idx + len(old_end)

new_block = '''    # GRUG v8.26g: PER-GROUP VOTE SELECTION for multipart inputs.
    # Old way: run select_aiml_votes globally → one node wins for ALL groups.
    # Problem: node_113 (fire) wins globally, so even mp_2 (water) uses fire.
    # New way: partition by multipart_group, select winner per group, merge.
    _mp_groups_in_candidates = unique([vc.multipart_group for vc in vote_candidates if !isempty(vc.multipart_group)])
    _is_multipart_selection = !isempty(_mp_groups_in_candidates)

    if _is_multipart_selection
        # GRUG v8.26g: Partition candidates by multipart_group, select per group.
        top_tier = VoteOrchestrator.VoteCandidate[]
        subtop_tier = VoteOrchestrator.VoteCandidate[]
        rejected_tier = VoteOrchestrator.VoteCandidate[]
        for grp in _mp_groups_in_candidates
            grp_cands = filter(vc -> vc.multipart_group == grp, vote_candidates)
            if isempty(grp_cands); continue; end
            gt, gst, grj = VoteOrchestrator.select_aiml_votes(grp_cands;
                threshold = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
                top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW)
            append!(top_tier, gt)
            append!(subtop_tier, gst)
            append!(rejected_tier, grj)
        end
        # Also run singleton candidates (no group) through global selection
        singleton_cands = filter(vc -> isempty(vc.multipart_group), vote_candidates)
        if !isempty(singleton_cands)
            st, sst, srj = VoteOrchestrator.select_aiml_votes(singleton_cands;
                threshold = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
                top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW)
            append!(top_tier, st)
            append!(subtop_tier, sst)
            append!(rejected_tier, srj)
        end
        println("[ORCHESTRATOR] 📊 Per-group selection: $(length(_mp_groups_in_candidates)) groups, top_tier=$(length(top_tier)), subtop=$(length(subtop_tier))")
    else
        # GRUG: Singleton path — old global selection, unchanged behavior.
        top_tier, subtop_tier, rejected_tier = VoteOrchestrator.select_aiml_votes(
            vote_candidates;
            threshold  = VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD,
            top_window = VoteOrchestrator.AIML_TOP_TIER_WINDOW
        )
    end

    # GRUG v8.26e: NO FALLBACK. If nothing passed the threshold, the cave
    # admits it doesn't know instead of picking a weak irrelevant node.
    if isempty(top_tier) && isempty(subtop_tier)
        @warn "[ORCHESTRATOR] ⚠ No votes passed AIML_CONFIDENCE_THRESHOLD=$(VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD). Producing strain response instead of fallback."
        strain_output = generate_ask_question(mission; reason="low_confidence")
        return (strain_output, Vote[], Vote[])
    end

    # GRUG v8.26g: Translate candidates back to Votes using composite key.
    sure_votes   = Vote[candidate_to_vote[(vc.node_id, vc.multipart_group)] for vc in top_tier if haskey(candidate_to_vote, (vc.node_id, vc.multipart_group))]
    unsure_votes = Vote[candidate_to_vote[(vc.node_id, vc.multipart_group)] for vc in subtop_tier if haskey(candidate_to_vote, (vc.node_id, vc.multipart_group))]

    if isempty(sure_votes)
        error("!!! FATAL: Grug math broke! Top tier produced zero sure votes despite passing threshold! !!!")
    end

    # GRUG v8.26g: For multipart, pick primary_vote per group (each group's
    # top winner). For singletons, old tie-breaking logic unchanged.
    if _is_multipart_selection
        # GRUG: Each group's top_tier winner is that group's primary.
        # We pick the highest-confidence group winner as THE primary_vote
        # for legacy code that expects a single primary. But the action
        # log will use per-group primaries for each objective.
        _group_primaries = Dict{String, Vote}()
        for vc in top_tier
            grp = vc.multipart_group
            if isempty(grp); continue; end
            v = get(candidate_to_vote, (vc.node_id, grp), nothing)
            isnothing(v) && continue
            if !haskey(_group_primaries, grp) || v.confidence > _group_primaries[grp].confidence
                _group_primaries[grp] = v
            end
        end
        # GRUG: The global primary_vote is the highest-confidence group primary.
        # This is used by legacy code that expects a single primary_vote.
        if !isempty(_group_primaries)
            primary_vote = first(sort!(collect(values(_group_primaries)); by=v -> v.confidence, rev=true))
        else
            primary_vote = sure_votes[1]
        end
        println("[ORCHESTRATOR] 📋 Per-group primaries: ", join(["$grp→$(v.node_id)@$(round(v.confidence,digits=3))" for (grp,v) in _group_primaries], ", "))
    else
        # GRUG: Old tie-breaking for singleton inputs.
        if length(sure_votes) > 1
            top_conf = sure_votes[1].confidence
            tied_votes = Vote[v for v in sure_votes if abs(v.confidence - top_conf) < 1e-9]
            if length(tied_votes) > 1
                shuffle!(tied_votes)
                primary_vote = tied_votes[1]
                println("[ORCHESTRATOR] 🎲  TIE DETECTED! $(length(tied_votes)) rocks at confidence $(round(top_conf, digits=3)). Random winner: $(primary_vote.node_id)")
            else
                primary_vote = sure_votes[1]
            end
        else
            primary_vote = sure_votes[1]
        end
    end

    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    if isnothing(node)
        error("!!! FATAL: Winning node $(primary_vote.node_id) vanished before Grug could grab it! !!!")
    end'''

content = content[:start_idx] + new_block + content[end_marker_end:]

with open('src/Main.jl', 'w') as f:
    f.write(content)

print("Patch applied successfully")
