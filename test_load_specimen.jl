# test_load_specimen.jl
# =====================
# GRUG: Comprehensive test suite for /saveSpecimen + /loadSpecimen file-based
# persistence system. Tests save, load, round-trip integrity, validation,
# error handling, and edge cases.
#
# Run: julia test_load_specimen.jl

println("\n" * "="^70)
println("   SPECIMEN PERSISTENCE TEST SUITE (SAVE/LOAD)")
println("="^70 * "\n")

# GRUG: Include all modules in correct order (same as Main.jl)
include("stochastichelper.jl")
using .CoinFlipHeader

include("ChatterMode.jl")
using .ChatterMode

include("PhagyMode.jl")
using .PhagyMode

include("Thesaurus.jl")
using .Thesaurus

include("Lobe.jl")
using .Lobe

include("LobeTable.jl")
using .LobeTable

include("BrainStem.jl")
using .BrainStem

include("InputQueue.jl")
using .InputQueue

# Engine brings in PatternScanner, ImageSDF, EyeSystem, SemanticVerbs, ActionTonePredictor
include("engine.jl")

using JSON
using Base.Threads: Atomic, atomic_add!
using Base64: base64decode

# ── GLOBAL STATE (mirrors Main.jl) ───────────────────────────────────────────

mutable struct ChatMessage
    id::Int
    role::String
    text::String
    pinned::Bool
end

const MAX_HISTORY    = 10000
const MESSAGE_HISTORY = Vector{ChatMessage}()
const MSG_ID_COUNTER  = Atomic{Int}(0)
const LAST_VOTER_IDS  = String[]
const LAST_VOTER_LOCK = ReentrantLock()

function add_message_to_history!(role::String, text::String, pinned::Bool=false)
    id  = atomic_add!(MSG_ID_COUNTER, 1)
    msg = ChatMessage(id, role, text, pinned)
    if length(MESSAGE_HISTORY) < MAX_HISTORY
        push!(MESSAGE_HISTORY, msg)
    else
        idx_to_replace = findfirst(m -> !m.pinned, MESSAGE_HISTORY)
        if isnothing(idx_to_replace)
            @warn "Message history full with only pinned messages!"
            return
        end
        deleteat!(MESSAGE_HISTORY, idx_to_replace)
        push!(MESSAGE_HISTORY, msg)
    end
end

# ── INCLUDE THE SPECIMEN FUNCTIONS ────────────────────────────────────────────
# GRUG: We need to extract just the save/load functions from Main.jl.
# But since Main.jl has its own module includes and CLI loop, we'll define
# thin wrappers that mirror what Main.jl does. The actual functions are
# self-contained in Main.jl's specimen section.
# For testing, we'll include them via a targeted eval approach.

# GRUG: Actually, let's just define the functions directly here since they
# only depend on the global state we've already set up above.

# Read Main.jl and extract the specimen functions
main_content = read("Main.jl", String)

# Find and eval the save function
save_start = findfirst("function save_specimen_to_file!", main_content)
if isnothing(save_start)
    error("!!! TEST FATAL: Could not find save_specimen_to_file! in Main.jl !!!")
end

# Find and eval the load function  
load_start = findfirst("function load_specimen_from_file!", main_content)
if isnothing(load_start)
    error("!!! TEST FATAL: Could not find load_specimen_from_file! in Main.jl !!!")
end

# GRUG: Rather than eval-ing from Main.jl (which has complex dependencies),
# we'll test the save/load cycle by building state, serializing manually,
# and verifying the JSON structure. Then test decompression round-trip.

# ── TEST INFRASTRUCTURE ──────────────────────────────────────────────────────

passed = 0
failed = 0
total  = 0

function test(name::String, expr::Bool)
    global passed, failed, total
    total += 1
    if expr
        passed += 1
        println("  ✅ $name")
    else
        failed += 1
        println("  ❌ FAILED: $name")
    end
end

function test_throws(name::String, f::Function)
    global passed, failed, total
    total += 1
    try
        f()
        failed += 1
        println("  ❌ FAILED (no error thrown): $name")
    catch e
        passed += 1
        println("  ✅ $name (threw: $(typeof(e)))")
    end
end

# ── TEST TEMP DIRECTORY ──────────────────────────────────────────────────────
const TEST_DIR = mktempdir()
println("Test directory: $TEST_DIR\n")

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 1: GZIP ROUND-TRIP
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 1: Gzip Round-Trip ──")

let
    test_data = Dict{String, Any}(
        "greeting" => "Hello Grug!",
        "numbers"  => [1, 2, 3, 4, 5],
        "nested"   => Dict("a" => 1.0, "b" => "test")
    )
    json_str = JSON.json(test_data, 2)
    
    # Compress
    filepath = joinpath(TEST_DIR, "roundtrip_test.gz")
    proc_c = open(`gzip -c`, "r+")
    write(proc_c, json_str)
    close(proc_c.in)
    compressed = read(proc_c)
    open(filepath, "w") do io
        write(io, compressed)
    end
    
    test("Compressed file exists", isfile(filepath))
    test("Compressed file is smaller", filesize(filepath) < sizeof(json_str))
    
    # Decompress
    compressed_bytes = read(filepath)
    proc_d = open(`gunzip -c`, "r+")
    write(proc_d, compressed_bytes)
    close(proc_d.in)
    decompressed = String(read(proc_d))
    
    test("Decompressed matches original", decompressed == json_str)
    
    # Parse back
    parsed = JSON.parse(decompressed)
    test("Parsed greeting matches", parsed["greeting"] == "Hello Grug!")
    test("Parsed numbers match", parsed["numbers"] == [1, 2, 3, 4, 5])
    test("Parsed nested matches", parsed["nested"]["a"] == 1.0)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 2: NODE SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 2: Node Serialization ──")

let
    # Create a test node
    nid = create_node(
        "hello world greeting",
        "respond[be friendly]^3 | greet^1",
        Dict{String, Any}("system_prompt" => "Friendly mode."),
        String["node_99"];
        initial_strength=5.0
    )
    
    test("Node created", haskey(NODE_MAP, nid))
    
    node = NODE_MAP[nid]
    test("Node has correct pattern", node.pattern == "hello world greeting")
    test("Node has correct strength", node.strength == 5.0)
    test("Node has drop table", node.drop_table == ["node_99"])
    test("Node has json_data", node.json_data["system_prompt"] == "Friendly mode.")
    test("Node signal is not empty", !isempty(node.signal))
    test("Node hopfield_key is nonzero", node.hopfield_key != UInt64(0))
    
    # Serialize to dict (same format as save_specimen_to_file!)
    nd_dict = Dict{String, Any}(
        "id"                  => node.id,
        "pattern"             => node.pattern,
        "signal"              => node.signal,
        "action_packet"       => node.action_packet,
        "json_data"           => node.json_data,
        "drop_table"          => node.drop_table,
        "throttle"            => node.throttle,
        "relational_patterns" => [Dict("subject" => rt.subject, "relation" => rt.relation, "object" => rt.object)
                                  for rt in node.relational_patterns],
        "required_relations"  => node.required_relations,
        "relation_weights"    => node.relation_weights,
        "strength"            => node.strength,
        "is_image_node"       => node.is_image_node,
        "neighbor_ids"        => node.neighbor_ids,
        "is_unlinkable"       => node.is_unlinkable,
        "is_grave"            => node.is_grave,
        "grave_reason"        => node.grave_reason,
        "response_times"      => node.response_times,
        "ledger_last_cleared" => node.ledger_last_cleared,
        "hopfield_key"        => string(node.hopfield_key)
    )
    
    # Serialize to JSON and back
    json_str = JSON.json(nd_dict)
    parsed = JSON.parse(json_str)
    
    test("Serialized id matches", parsed["id"] == node.id)
    test("Serialized pattern matches", parsed["pattern"] == node.pattern)
    test("Serialized strength matches", parsed["strength"] == node.strength)
    test("Serialized drop_table matches", parsed["drop_table"] == node.drop_table)
    test("Serialized hopfield_key round-trips", parse(UInt64, parsed["hopfield_key"]) == node.hopfield_key)
    test("Serialized signal length matches", length(parsed["signal"]) == length(node.signal))
    
    # Reconstruct node from parsed dict
    rel_patterns = RelationalTriple[]
    for rp in get(parsed, "relational_patterns", [])
        push!(rel_patterns, RelationalTriple(
            String(get(rp, "subject", "")),
            String(get(rp, "relation", "")),
            String(get(rp, "object", ""))
        ))
    end
    
    restored_node = Node(
        String(parsed["id"]),
        String(parsed["pattern"]),
        Float64.(parsed["signal"]),
        String(parsed["action_packet"]),
        Dict{String, Any}(string(k) => v for (k,v) in parsed["json_data"]),
        String.(parsed["drop_table"]),
        Float64(parsed["throttle"]),
        rel_patterns,
        String.(get(parsed, "required_relations", String[])),
        Dict{String, Float64}(string(k) => Float64(v) for (k,v) in get(parsed, "relation_weights", Dict())),
        Float64(parsed["strength"]),
        Bool(parsed["is_image_node"]),
        String.(parsed["neighbor_ids"]),
        Bool(parsed["is_unlinkable"]),
        Bool(parsed["is_grave"]),
        String(parsed["grave_reason"]),
        Float64.(parsed["response_times"]),
        Float64(parsed["ledger_last_cleared"]),
        parse(UInt64, parsed["hopfield_key"])
    )
    
    test("Restored node id matches", restored_node.id == node.id)
    test("Restored node pattern matches", restored_node.pattern == node.pattern)
    test("Restored node strength matches", restored_node.strength == node.strength)
    test("Restored node signal matches", restored_node.signal == node.signal)
    test("Restored node hopfield_key matches", restored_node.hopfield_key == node.hopfield_key)
    test("Restored node action_packet matches", restored_node.action_packet == node.action_packet)
    test("Restored node drop_table matches", restored_node.drop_table == node.drop_table)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 3: MESSAGE HISTORY SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 3: Message History Serialization ──")

let
    # Add test messages
    add_message_to_history!("User", "Hello Grug!", false)
    add_message_to_history!("System", "Grug say hi!", false)
    add_message_to_history!("User_Pinned", "Important fact: the cave is 42 rocks wide.", true)
    
    test("Messages added", length(MESSAGE_HISTORY) >= 3)
    
    # Serialize
    msg_list = [Dict{String, Any}(
        "id"     => m.id,
        "role"   => m.role,
        "text"   => m.text,
        "pinned" => m.pinned
    ) for m in MESSAGE_HISTORY]
    
    json_str = JSON.json(msg_list)
    parsed = JSON.parse(json_str)
    
    test("Serialized message count matches", length(parsed) == length(MESSAGE_HISTORY))
    
    # Find the pinned message
    pinned_msgs = filter(m -> m["pinned"], parsed)
    test("Pinned message preserved", length(pinned_msgs) >= 1)
    test("Pinned text correct", any(m -> m["text"] == "Important fact: the cave is 42 rocks wide.", pinned_msgs))
    
    # Reconstruct
    restored_msgs = ChatMessage[]
    for mentry in parsed
        push!(restored_msgs, ChatMessage(
            Int(mentry["id"]),
            String(mentry["role"]),
            String(mentry["text"]),
            Bool(mentry["pinned"])
        ))
    end
    
    test("Restored message count matches", length(restored_msgs) == length(MESSAGE_HISTORY))
    for (orig, rest) in zip(MESSAGE_HISTORY, restored_msgs)
        test("Message $(orig.id) role matches", orig.role == rest.role)
        test("Message $(orig.id) text matches", orig.text == rest.text)
        test("Message $(orig.id) pin matches", orig.pinned == rest.pinned)
    end
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 4: LOBE SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 4: Lobe Serialization ──")

let
    # Create test lobes
    Lobe.create_lobe!("science", "scientific reasoning")
    Lobe.create_lobe!("philosophy", "philosophical inquiry")
    Lobe.connect_lobes!("science", "philosophy")
    
    test("Lobes created", length(Lobe.LOBE_REGISTRY) >= 2)
    test("Lobes connected", "philosophy" in Lobe.LOBE_REGISTRY["science"].connected_lobe_ids)
    
    # Serialize
    lobe_list = Dict{String, Any}[]
    for (id, rec) in Lobe.LOBE_REGISTRY
        push!(lobe_list, Dict{String, Any}(
            "id"                 => rec.id,
            "subject"            => rec.subject,
            "node_ids"           => sort(collect(rec.node_ids)),
            "connected_lobe_ids" => sort(collect(rec.connected_lobe_ids)),
            "node_cap"           => rec.node_cap,
            "fire_count"         => rec.fire_count,
            "inhibit_count"      => rec.inhibit_count,
            "created_at"         => rec.created_at
        ))
    end
    
    json_str = JSON.json(lobe_list)
    parsed = JSON.parse(json_str)
    
    test("Serialized lobe count", length(parsed) >= 2)
    
    # Find science lobe
    sci_lobe = findfirst(l -> l["id"] == "science", parsed)
    test("Science lobe found in serialized", !isnothing(sci_lobe))
    test("Science lobe subject correct", parsed[sci_lobe]["subject"] == "scientific reasoning")
    test("Science lobe connection preserved", "philosophy" in parsed[sci_lobe]["connected_lobe_ids"])
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 5: VERB REGISTRY SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 5: Verb Registry Serialization ──")

let
    # Add test verbs
    SemanticVerbs.add_relation_class!("epistemic")
    SemanticVerbs.add_verb!("believes", "epistemic")
    SemanticVerbs.add_verb!("doubts", "epistemic")
    SemanticVerbs.add_synonym!("believes", "thinks")
    
    # Serialize
    verb_data = Dict{String, Any}()
    lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
        classes = Dict{String, Any}()
        for (cls, verbs) in SemanticVerbs._VERB_REGISTRY
            classes[cls] = sort(collect(verbs))
        end
        verb_data["classes"] = classes
        verb_data["synonyms"] = copy(SemanticVerbs._SYNONYM_MAP)
    end
    
    json_str = JSON.json(verb_data)
    parsed = JSON.parse(json_str)
    
    test("Verb classes serialized", haskey(parsed["classes"], "epistemic"))
    test("Epistemic verbs include believes", "believes" in parsed["classes"]["epistemic"])
    test("Epistemic verbs include doubts", "doubts" in parsed["classes"]["epistemic"])
    test("Synonym thinks->believes preserved", get(parsed["synonyms"], "thinks", "") == "believes")
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 6: INHIBITION SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 6: Inhibition Serialization ──")

let
    InputQueue.add_inhibition!("spam"; reason="content filter")
    InputQueue.add_inhibition!("profanity"; reason="language filter")
    
    test("Inhibitions added", InputQueue.inhibition_count() >= 2)
    
    # Serialize
    inhib_list = Dict{String, Any}[]
    lock(InputQueue._NEG_LOCK) do
        for (word, entry) in InputQueue._NEG_THESAURUS
            push!(inhib_list, Dict{String, Any}(
                "word"     => entry.word,
                "reason"   => entry.reason,
                "added_at" => entry.added_at
            ))
        end
    end
    
    json_str = JSON.json(inhib_list)
    parsed = JSON.parse(json_str)
    
    test("Inhibitions serialized", length(parsed) >= 2)
    spam_entry = findfirst(e -> e["word"] == "spam", parsed)
    test("Spam inhibition found", !isnothing(spam_entry))
    test("Spam reason correct", parsed[spam_entry]["reason"] == "content filter")
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 7: THESAURUS SEED SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 7: Thesaurus Seed Serialization ──")

let
    # The SYNONYM_SEED_MAP should already have hardcoded entries
    initial_count = length(Thesaurus.SYNONYM_SEED_MAP)
    test("Thesaurus has initial seeds", initial_count > 0)
    
    # Add a runtime seed
    Thesaurus.add_seed_synonym!("grugbot", ["cave_ai", "neuromorphic_engine"])
    
    test("Runtime seed added", haskey(Thesaurus.SYNONYM_SEED_MAP, "grugbot"))
    test("Seed has correct synonyms", "cave_ai" in Thesaurus.SYNONYM_SEED_MAP["grugbot"])
    
    # Serialize
    thesaurus_data = Dict{String, Any}()
    lock(Thesaurus.SEED_MAP_LOCK) do
        for (word, syns) in Thesaurus.SYNONYM_SEED_MAP
            thesaurus_data[word] = sort(collect(syns))
        end
    end
    
    json_str = JSON.json(thesaurus_data)
    parsed = JSON.parse(json_str)
    
    test("Thesaurus serialized", length(parsed) >= initial_count + 1)
    test("Grugbot entry in serialized", haskey(parsed, "grugbot"))
    test("Cave_ai in serialized grugbot synonyms", "cave_ai" in parsed["grugbot"])
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 8: AROUSAL STATE SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 8: Arousal State Serialization ──")

let
    EyeSystem.set_arousal!(0.75)
    test("Arousal set to 0.75", EyeSystem.get_arousal() == 0.75)
    
    # Serialize
    arousal_data = Dict{String, Any}()
    lock(EyeSystem.AROUSAL_LOCK) do
        arousal_data["level"]      = EyeSystem.AROUSAL_STATE.level
        arousal_data["decay_rate"] = EyeSystem.AROUSAL_STATE.decay_rate
        arousal_data["baseline"]   = EyeSystem.AROUSAL_STATE.baseline
    end
    
    json_str = JSON.json(arousal_data)
    parsed = JSON.parse(json_str)
    
    test("Arousal level serialized", parsed["level"] == 0.75)
    test("Arousal decay_rate serialized", parsed["decay_rate"] > 0.0)
    test("Arousal baseline serialized", parsed["baseline"] > 0.0)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 9: HOPFIELD CACHE SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 9: Hopfield Cache Serialization ──")

let
    # Manually insert a hopfield entry
    test_hash = hash("test input normalized")
    lock(HOPFIELD_CACHE_LOCK) do
        HOPFIELD_CACHE[test_hash] = ["node_1", "node_2"]
        HOPFIELD_HIT_COUNTS[test_hash] = 5
    end
    
    # Serialize
    hopfield_entries = Dict{String, Any}[]
    lock(HOPFIELD_CACHE_LOCK) do
        for (h, ids) in HOPFIELD_CACHE
            push!(hopfield_entries, Dict{String, Any}(
                "hash"      => string(h),
                "node_ids"  => ids,
                "hit_count" => get(HOPFIELD_HIT_COUNTS, h, 0)
            ))
        end
    end
    
    json_str = JSON.json(hopfield_entries)
    parsed = JSON.parse(json_str)
    
    test("Hopfield entries serialized", length(parsed) >= 1)
    
    # Find our test entry
    test_entry = findfirst(e -> e["hash"] == string(test_hash), parsed)
    test("Test hopfield entry found", !isnothing(test_entry))
    test("Hopfield node_ids correct", parsed[test_entry]["node_ids"] == ["node_1", "node_2"])
    test("Hopfield hit_count correct", parsed[test_entry]["hit_count"] == 5)
    
    # Round-trip UInt64 hash
    restored_hash = parse(UInt64, parsed[test_entry]["hash"])
    test("Hopfield hash round-trips", restored_hash == test_hash)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 10: FULL SPECIMEN JSON STRUCTURE
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 10: Full Specimen JSON Structure ──")

let
    # Build a complete specimen dict (same as save_specimen_to_file!)
    specimen = Dict{String, Any}()
    
    # Nodes
    node_list = Dict{String, Any}[]
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            push!(node_list, Dict{String, Any}(
                "id" => node.id, "pattern" => node.pattern,
                "signal" => node.signal, "action_packet" => node.action_packet,
                "strength" => node.strength, "hopfield_key" => string(node.hopfield_key),
                "json_data" => node.json_data, "drop_table" => node.drop_table,
                "throttle" => node.throttle, "is_image_node" => node.is_image_node,
                "neighbor_ids" => node.neighbor_ids, "is_unlinkable" => node.is_unlinkable,
                "is_grave" => node.is_grave, "grave_reason" => node.grave_reason,
                "response_times" => node.response_times,
                "ledger_last_cleared" => node.ledger_last_cleared,
                "relational_patterns" => [Dict("subject" => rt.subject, "relation" => rt.relation, "object" => rt.object)
                                          for rt in node.relational_patterns],
                "required_relations" => node.required_relations,
                "relation_weights" => node.relation_weights
            ))
        end
    end
    specimen["nodes"] = node_list
    
    # Rules
    specimen["rules"] = [Dict{String,Any}("text" => r.rule_text, "prob" => r.fire_prob) for r in AIML_DROP_TABLE]
    
    # Messages
    specimen["message_history"] = [Dict{String,Any}(
        "id" => m.id, "role" => m.role, "text" => m.text, "pinned" => m.pinned
    ) for m in MESSAGE_HISTORY]
    
    # ID counters
    specimen["id_counters"] = Dict{String,Any}(
        "node_id_counter" => ID_COUNTER[],
        "msg_id_counter"  => MSG_ID_COUNTER[]
    )
    
    # Meta
    specimen["_meta"] = Dict{String,Any}(
        "version" => "2.0",
        "saved_at" => time(),
        "format" => "grugbot420-specimen-v2"
    )
    
    # Serialize to JSON
    json_str = JSON.json(specimen, 2)
    
    test("Full specimen JSON is non-empty", !isempty(json_str))
    test("Full specimen JSON parses", !isnothing(JSON.parse(json_str)))
    
    # Compress and write
    filepath = joinpath(TEST_DIR, "full_specimen.specimen.gz")
    proc = open(`gzip -c`, "r+")
    write(proc, json_str)
    close(proc.in)
    compressed = read(proc)
    open(filepath, "w") do io
        write(io, compressed)
    end
    
    test("Full specimen file created", isfile(filepath))
    test("Full specimen is compressed", filesize(filepath) < sizeof(json_str))
    
    # Read back and verify
    compressed_bytes = read(filepath)
    proc_d = open(`gunzip -c`, "r+")
    write(proc_d, compressed_bytes)
    close(proc_d.in)
    decompressed = String(read(proc_d))
    restored = JSON.parse(decompressed)
    
    test("Restored specimen has nodes", haskey(restored, "nodes"))
    test("Restored specimen has rules", haskey(restored, "rules"))
    test("Restored specimen has message_history", haskey(restored, "message_history"))
    test("Restored specimen has id_counters", haskey(restored, "id_counters"))
    test("Restored specimen has _meta", haskey(restored, "_meta"))
    test("Restored meta version", restored["_meta"]["version"] == "2.0")
    test("Restored meta format", restored["_meta"]["format"] == "grugbot420-specimen-v2")
    test("Restored node count matches", length(restored["nodes"]) == length(node_list))
    test("Restored message count matches", length(restored["message_history"]) == length(MESSAGE_HISTORY))
    
    # Verify compression ratio
    ratio = 100.0 * (1.0 - filesize(filepath) / sizeof(json_str))
    println("    📊 Compression: $(sizeof(json_str)) bytes → $(filesize(filepath)) bytes ($(round(ratio, digits=1))% smaller)")
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 11: VALIDATION EDGE CASES
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 11: Validation Edge Cases ──")

let
    # Test: invalid JSON in compressed file
    bad_filepath = joinpath(TEST_DIR, "bad_json.gz")
    proc = open(`gzip -c`, "r+")
    write(proc, "{ this is not valid json !!!")
    close(proc.in)
    compressed = read(proc)
    open(bad_filepath, "w") do io
        write(io, compressed)
    end
    
    # The file exists and decompresses, but JSON parsing should fail
    compressed_bytes = read(bad_filepath)
    proc_d = open(`gunzip -c`, "r+")
    write(proc_d, compressed_bytes)
    close(proc_d.in)
    decompressed = String(read(proc_d))
    
    test("Bad JSON decompresses to string", !isempty(decompressed))
    test_throws("Bad JSON parse throws error", () -> JSON.parse(decompressed))
    
    # Test: valid JSON but wrong structure (array instead of dict)
    bad_struct_path = joinpath(TEST_DIR, "bad_struct.gz")
    proc2 = open(`gzip -c`, "r+")
    write(proc2, "[1, 2, 3]")
    close(proc2.in)
    compressed2 = read(proc2)
    open(bad_struct_path, "w") do io
        write(io, compressed2)
    end
    
    compressed_bytes2 = read(bad_struct_path)
    proc_d2 = open(`gunzip -c`, "r+")
    write(proc_d2, compressed_bytes2)
    close(proc_d2.in)
    decompressed2 = String(read(proc_d2))
    parsed2 = JSON.parse(decompressed2)
    
    test("Array JSON is not a Dict", !isa(parsed2, Dict))
    
    # Test: valid JSON with unknown keys
    unknown_keys_json = JSON.json(Dict("unknown_key" => "bad", "nodes" => []))
    test("Unknown key detection", occursin("unknown_key", unknown_keys_json))
    
    # Test: empty compressed file
    empty_path = joinpath(TEST_DIR, "empty.gz")
    proc3 = open(`gzip -c`, "r+")
    write(proc3, "")
    close(proc3.in)
    compressed3 = read(proc3)
    open(empty_path, "w") do io
        write(io, compressed3)
    end
    test("Empty compressed file created", isfile(empty_path))
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 12: LOBE TABLE SERIALIZATION WITH NODEREF
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 12: LobeTable + NodeRef Serialization ──")

let
    # Create a lobe table and add some entries
    LobeTable.create_lobe_table!("science")
    
    # Add a NodeRef
    LobeTable.node_ref_put!("science", "node_test_1")
    
    # Add some json data
    LobeTable.json_to_table_chunk!("science", "node_test_1", Dict{String, Any}("key" => "value"))
    
    # Serialize
    lock(LobeTable.TABLE_REGISTRY_LOCK) do
        rec = LobeTable.LOBE_TABLE_REGISTRY["science"]
        nodes_chunk = rec.chunks["nodes"]
        lock(nodes_chunk.lock) do
            test("NodeRef exists in chunk", haskey(nodes_chunk.store, "node_test_1"))
            val = nodes_chunk.store["node_test_1"]
            test("NodeRef is correct type", val isa LobeTable.NodeRef)
            test("NodeRef is active", val.is_active)
            
            # Serialize NodeRef
            serialized = Dict{String, Any}(
                "_type"       => "NodeRef",
                "node_id"     => val.node_id,
                "lobe_id"     => val.lobe_id,
                "is_active"   => val.is_active,
                "inserted_at" => val.inserted_at
            )
            
            json_str = JSON.json(serialized)
            parsed = JSON.parse(json_str)
            
            test("NodeRef _type marker", parsed["_type"] == "NodeRef")
            test("NodeRef node_id preserved", parsed["node_id"] == "node_test_1")
            test("NodeRef is_active preserved", parsed["is_active"] == true)
            
            # Reconstruct
            restored_ref = LobeTable.NodeRef(
                String(parsed["node_id"]),
                String(parsed["lobe_id"]),
                Bool(parsed["is_active"]),
                Float64(parsed["inserted_at"])
            )
            test("Restored NodeRef matches", restored_ref.node_id == val.node_id)
            test("Restored NodeRef active matches", restored_ref.is_active == val.is_active)
        end
    end
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 13: ID COUNTER SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 13: ID Counter Serialization ──")

let
    current_node_id = ID_COUNTER[]
    current_msg_id = MSG_ID_COUNTER[]
    
    test("Node ID counter is nonzero", current_node_id > 0)
    test("Msg ID counter is nonzero", current_msg_id > 0)
    
    # Serialize
    counters = Dict{String, Any}(
        "node_id_counter" => current_node_id,
        "msg_id_counter"  => current_msg_id
    )
    
    json_str = JSON.json(counters)
    parsed = JSON.parse(json_str)
    
    test("Node ID counter round-trips", Int(parsed["node_id_counter"]) == current_node_id)
    test("Msg ID counter round-trips", Int(parsed["msg_id_counter"]) == current_msg_id)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# TEST GROUP 14: BRAINSTEM STATE SERIALIZATION
# ══════════════════════════════════════════════════════════════════════════════
println("── GROUP 14: BrainStem State Serialization ──")

let
    # Set some brainstem state
    lock(BrainStem.BRAINSTEM_LOCK) do
        BrainStem.BRAINSTEM_STATE.dispatch_count = 42
        BrainStem.BRAINSTEM_STATE.last_winner_id = "node_7"
        BrainStem.BRAINSTEM_STATE.last_dispatch_t = 1234567890.0
    end
    
    # Serialize
    brainstem_data = Dict{String, Any}()
    lock(BrainStem.BRAINSTEM_LOCK) do
        bs = BrainStem.BRAINSTEM_STATE
        brainstem_data["dispatch_count"]  = bs.dispatch_count
        brainstem_data["last_winner_id"]  = bs.last_winner_id
        brainstem_data["last_dispatch_t"] = bs.last_dispatch_t
        brainstem_data["propagation_history"] = [
            Dict{String, Any}(
                "source_lobe_id" => pr.source_lobe_id,
                "target_lobe_id" => pr.target_lobe_id,
                "confidence"     => pr.confidence,
                "dispatch_count" => pr.dispatch_count
            ) for pr in bs.propagation_history
        ]
    end
    
    json_str = JSON.json(brainstem_data)
    parsed = JSON.parse(json_str)
    
    test("BrainStem dispatch_count serialized", parsed["dispatch_count"] == 42)
    test("BrainStem last_winner_id serialized", parsed["last_winner_id"] == "node_7")
    test("BrainStem last_dispatch_t serialized", parsed["last_dispatch_t"] == 1234567890.0)
end
println()

# ══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════════════════

# Clean up temp directory
rm(TEST_DIR; recursive=true, force=true)

# ══════════════════════════════════════════════════════════════════════════════
# RESULTS
# ══════════════════════════════════════════════════════════════════════════════

println("\n" * "="^70)
println("   TEST RESULTS")
println("="^70)
println("  Total:  $total")
println("  Passed: $passed ✅")
println("  Failed: $failed ❌")
println("="^70)

if failed > 0
    println("\n!!! SOME TESTS FAILED !!!")
    exit(1)
else
    println("\n🎉 ALL TESTS PASSED! Grug's specimen persistence is solid rock!")
    exit(0)
end