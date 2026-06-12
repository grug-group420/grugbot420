#!/usr/bin/env julia
# Diagnostic: check lobe topicality for specific inputs
using GrugBot420
const GB = GrugBot420

println("Loading specimen...")
GB.load_specimen_from_file!("v722_test.specimen.gz")

# Check lobe subjects
lobe_ids = GB.Lobe.get_lobe_ids()
println("\n=== LOBE SUBJECTS ===")
for lid in lobe_ids
    rec = GB.Lobe.get_lobe(lid)
    println("  $lid: subject='$(rec.subject)' | nodes=$(length(rec.node_ids))")
end

# Check topicality for test inputs
test_inputs = [
    "what is 3 times 4 and what is the sky",
    "what is 2 plus 3 and what is 4 times 5",
    "what is 2 plus 2",
    "tell me about fire",
]

for input in test_inputs
    println("\n=== INPUT: '$input' ===")
    mission_expanded = try
        GB.Thesaurus.thesaurus_gate_filter(input)
    catch
        Set(lowercase.(filter(!isempty, map(strip, split(input)))))
    end
    println("  Mission expanded ($(length(mission_expanded)) tokens): $(sort(collect(mission_expanded))[1:min(20, length(mission_expanded))])")
    
    for lid in lobe_ids
        rec = GB.Lobe.get_lobe(lid)
        topic = GB._compute_lobe_topicality(rec.subject, mission_expanded)
        status = topic >= GB.LOBE_TOPICALITY_FLOOR ? "ELIGIBLE" : "MUTED"
        println("  $lid: topicality=$(round(topic, digits=4)) $status (subject='$(rec.subject)')")
        
        # Also show what the subject expands to
        subject_expanded = try
            GB.Thesaurus.thesaurus_gate_filter(rec.subject)
        catch
            Set(lowercase.(filter(!isempty, map(strip, split(rec.subject)))))
        end
        overlap = intersect(subject_expanded, mission_expanded)
        if !isempty(overlap)
            println("    Overlap tokens: $(sort(collect(overlap)))")
        end
    end
end

# Check ALL node patterns and which lobe they belong to
println("\n=== ALL NODES ===")
for (nid, node) in GB.NODE_MAP
    lobe_of = try GB.Lobe.find_lobe_for_node(nid) catch _; "none" end
    sigil = GB.has_sigil_tag(node) ? " [$(GB.node_sigil_kind(node))]" : ""
    grave = node.is_grave ? " [GRAVE]" : ""
    println("  $nid (lobe=$lobe_of)$sigil$grave: pattern='$(node.pattern)'")
end
