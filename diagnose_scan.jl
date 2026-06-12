#!/usr/bin/env julia
# Deep diagnostic: trace scan_and_expand for failing test inputs
using GrugBot420
const GB = GrugBot420

println("Loading specimen...")
GB.load_specimen_from_file!("v722_test.specimen.gz")

# Test the scan directly for test 8
test_inputs = [
    "what is 2 plus 3 and what is 4 times 5",
    "what is 3 times 4 and what is the sky",
]

for input in test_inputs
    println("\n====== TESTING SCAN: '$input' ======")
    
    # Run scan_specimens (before topicality gate)
    println("\n--- scan_specimens results ---")
    scan_result = try
        GB.scan_specimens(input)
    catch e
        println("SCAN ERROR: $e")
        nothing
    end
    
    if !isnothing(scan_result)
        println("  Raw scan hits: $(length(scan_result))")
        for (id, conf, antimatch, u_trips, n_trips) in scan_result
            lobe_of = try GB.Lobe.find_lobe_for_node(id) catch _; "none" end
            node = lock(() -> get(GB.NODE_MAP, id, nothing), GB.NODE_LOCK)
            pattern = isnothing(node) ? "?" : node.pattern
            sigil = !isnothing(node) && GB.has_sigil_tag(node) ? " [$(GB.node_sigil_kind(node))]" : ""
            println("    $id (lobe=$lobe_of)$sigil: conf=$(round(conf, digits=3)) pattern='$pattern'")
        end
    end
    
    # Run scan_and_expand (includes topicality gate)
    println("\n--- scan_and_expand results ---")
    expand_result = try
        GB.scan_and_expand(input)
    catch e
        println("EXPAND ERROR: $e")
        nothing
    end
    
    if !isnothing(expand_result)
        println("  After topicality gate: $(length(expand_result)) specimens")
        for (id, conf, antimatch, u_trips, n_trips) in expand_result
            lobe_of = try GB.Lobe.find_lobe_for_node(id) catch _; "none" end
            node = lock(() -> get(GB.NODE_MAP, id, nothing), GB.NODE_LOCK)
            pattern = isnothing(node) ? "?" : node.pattern
            sigil = !isnothing(node) && GB.has_sigil_tag(node) ? " [$(GB.node_sigil_kind(node))]" : ""
            println("    $id (lobe=$lobe_of)$sigil: conf=$(round(conf, digits=3)) pattern='$pattern'")
        end
    end
    
    # Check sigil mediation
    println("\n--- SigilMediator results ---")
    med = try GB.SigilMediator.mediate(input) catch e; println("  MEDIATE ERROR: $e"); nothing end
    if !isnothing(med)
        println("  Bindings: $(length(med.bindings))")
        for b in med.bindings
            println("    binding: $(b)")
        end
        println("  Kinds: $(med.kinds)")
        println("  Rewritten: $(med.rewritten)")
    end
end
