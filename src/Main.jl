# Main.jl

# GRUG: When loaded as part of GrugBot420 package, CoinFlipHeader is already
# included and in scope from GrugBot420.jl. Only include/use it standalone.
if !isdefined(@__MODULE__, :CoinFlipHeader)
    include("stochastichelper.jl")
    using .CoinFlipHeader
end

# GRUG: Include engine after macro is alive. Engine need coinflip!
# Engine.jl now includes patternscanner.jl, ImageSDF.jl and EyeSystem.jl internally.
include("engine.jl")

# GRUG: Bring the Chatter Mode gossip system into the cave!
# GRUG: Guard against double-include if ChatterMode already loaded by caller.
if !isdefined(@__MODULE__, :ChatterMode)
    include("ChatterMode.jl")
    using .ChatterMode
end

# GRUG: Bring the Phagy Mode maintenance automata into the cave!
# GRUG: Guard against double-include if PhagyMode already loaded by caller.
if !isdefined(@__MODULE__, :PhagyMode)
    include("PhagyMode.jl")
    using .PhagyMode
end

# GRUG: Bring the Thesaurus dimensional similarity engine into the cave!
# GRUG: Guard against double-include if Thesaurus already loaded by caller.
if !isdefined(@__MODULE__, :Thesaurus)
    include("Thesaurus.jl")
    using .Thesaurus
end

# GRUG: Bring the Lobe partitioning system into the cave!
# GRUG: Guard against double-include if Lobe already loaded by caller.
if !isdefined(@__MODULE__, :Lobe)
    include("Lobe.jl")
    using .Lobe
end

# GRUG: Bring the LobeTable hash storage system into the cave!
# GRUG: Guard against double-include if LobeTable already loaded by caller.
if !isdefined(@__MODULE__, :LobeTable)
    include("LobeTable.jl")
    using .LobeTable
end

# GRUG: Bring the BrainStem winner-take-all dispatcher into the cave!
# GRUG: Guard against double-include if BrainStem already loaded by caller.
if !isdefined(@__MODULE__, :BrainStem)
    include("BrainStem.jl")
    using .BrainStem
end

# GRUG: Bring the InputQueue and NegativeThesaurus inhibition system into the cave!
# GRUG: Guard against double-include if InputQueue already loaded by caller.
if !isdefined(@__MODULE__, :InputQueue)
    include("InputQueue.jl")
    using .InputQueue
end

# GRUG: Bring the Immune System into the cave!
# GRUG: Guard against double-include if ImmuneSystem already loaded by caller.
if !isdefined(@__MODULE__, :ImmuneSystem)
    include("ImmuneSystem.jl")
    using .ImmuneSystem
end

using Base64: base64decode

# ==============================================================================
# MEMORY CAVE (PIN AWARENESS LAYER)
# ==============================================================================

# GRUG DOC 3.6: These big memory rocks disappear when Grug goes to sleep (CLI closes).
# Future Grug need to learn how to write on permanent cave walls (Persistence feature).
mutable struct ChatMessage
    id::Int
    role::String
    text::String
    pinned::Bool
end

const MAX_HISTORY   = 10000
const MESSAGE_HISTORY = Vector{ChatMessage}()
const MSG_ID_COUNTER       = Atomic{Int}(0)
const MESSAGE_HISTORY_LOCK = ReentrantLock()  # GRUG: Lock for phagy forensics read-access to MESSAGE_HISTORY

# GRUG FIX 3.1: Strict Role Validation!
# Grug no let random strangers paint on memory wall.
const ALLOWED_ROLES = Set(["User", "System", "User_Pinned", "Engine_Voice"])

"""
add_message_to_history!(role::String, text::String, pinned::Bool=false)

GRUG: Write new words on memory cave wall. If wall full, wash away old words.
Pinned messages survive eviction. Throws on empty input — NO SILENT FAILURES.
"""
function add_message_to_history!(role::String, text::String, pinned::Bool=false)
    if strip(text) == "" || strip(role) == ""
        error("!!! FATAL: Grug cannot paint empty air on memory cave wall! !!!")
    end

    if !(role in ALLOWED_ROLES)
        error("!!! FATAL: Grug does not know role '$role'. Allowed roles: $(join(ALLOWED_ROLES, ", ")) !!!")
    end
    
    id  = atomic_add!(MSG_ID_COUNTER, 1)
    msg = ChatMessage(id, role, text, pinned)
    
    if length(MESSAGE_HISTORY) < MAX_HISTORY
        push!(MESSAGE_HISTORY, msg)
    else
        # GRUG: Cave full! Find oldest un-pinned drawing and smash it.
        idx_to_replace = findfirst(m -> !m.pinned, MESSAGE_HISTORY)
        if isnothing(idx_to_replace)
            error("!!! FATAL: All 10,000 slots have pinned rocks! Grug's memory cave is completely full! !!!")
        end
        deleteat!(MESSAGE_HISTORY, idx_to_replace)
        push!(MESSAGE_HISTORY, msg)
    end
end

# ==============================================================================
# DYNAMIC AIML DROP TABLE & MAGIC WORD TEMPLATES
# ==============================================================================
# GRUG: AIML_DROP_TABLE, StochasticRule, ALLOWED_RULE_TAGS, and add_orchestration_rule!
# are defined in Engine.jl so they are available to both Main.jl and the test runner.
# Nothing to re-define here. Grug just uses them directly!

# ==============================================================================
# EPHEMERAL AIML ORCHESTRATOR
# ==============================================================================

"""
extract_lobe_aware_context(votes::Vector{Vote})::String

GRUG: Read the pinned words and the fresh words to give context to the dynamic
generation engine. Extracts lobe knowledge from winning votes for AIML context.
Non-fatal on lobe read errors — warns and returns error placeholder.
"""
function extract_lobe_aware_context(votes::Vector{Vote})::String
    # GRUG: Prefrontal cortex context injector!
    # Show which lobes are active and what knowledge is available from each.
    # This lets AIML rules reason across domain boundaries (science ↔ philosophy ↔ etc.)
    
    try
        if isempty(votes)
            return "Lobe Context: [No active lobes]"
        end
        
        # GRUG: Map each vote to its lobe, collect unique active lobes
        active_lobes = Set{String}()
        for vote in votes
            lobe_name = Lobe.find_lobe_for_node(vote.node_id)
            if !isnothing(lobe_name)
                push!(active_lobes, lobe_name)
            end
        end
        
        if isempty(active_lobes)
            return "Lobe Context: [Unassigned nodes - no lobe context]"
        end
        
        # GRUG: Build context string with active lobes and their node counts
        lobe_parts = String[]
        for lobe_name in sort(collect(active_lobes))
            lobe_node_count = Lobe.get_lobe_node_count(lobe_name)
            active_node_ids = if isdefined(@__MODULE__, :LobeTable) && LobeTable.table_exists(lobe_name)
                LobeTable.get_active_node_ids(lobe_name)
            else
                String[]
            end
            active_count = length(active_node_ids)
            
            # Sample 2-3 node patterns from this lobe to show domain flavor
            sample_patterns = String[]
            for node_id in active_node_ids[1:min(3, length(active_node_ids))]
                node = lock(() -> get(NODE_MAP, node_id, nothing), NODE_LOCK)
                if !isnothing(node)
                    push!(sample_patterns, node.pattern)
                end
            end
            
            pattern_preview = isempty(sample_patterns) ? "" : 
                " ($(join([p[1:min(30, length(p))] for p in sample_patterns], " | ")))"
            
            push!(lobe_parts, "$lobe_name ($active_count/$lobe_node_count active$pattern_preview)")
        end
        
        return "Lobe Context: [" * join(lobe_parts, "] | [") * "]"
        
    catch e
        # GRUG: Don't crash AIML on lobe context error, but WARN
        @warn "[MAIN] ⚠ Failed to extract lobe-aware context (non-fatal): $e"
        return "Lobe Context: [Error retrieving lobe information]"
    end
end

"""
extract_aiml_memory_context()::String

GRUG: Chief Orchestrator reads memory wall — pinned and recent messages.
Formats them for AIML context injection. Throws on read failure — NO SILENT FAILURES.
"""
function extract_aiml_memory_context()::String
    total_msgs = length(MESSAGE_HISTORY)
    if total_msgs == 0
        return "Memory Cave: [EMPTY]"
    end
    
    pinned_msgs = String[]
    recent_msgs = String[]
    
    try
        # 1. Grab all pinned rocks
        for m in MESSAGE_HISTORY
            if m.pinned
                push!(pinned_msgs, "[$(m.role)]: $(m.text)")
            end
        end
        
        # GRUG FIX 3.2: Grug want last 5 UNPINNED rocks. 
        # If Grug just check last 5 spots and all are pinned, recent sounds is empty!
        # So Grug filter first, then take last 5.
        unpinned_history = [m for m in MESSAGE_HISTORY if !m.pinned]
        recent_count = min(5, length(unpinned_history))
        
        for i in (length(unpinned_history) - recent_count + 1):length(unpinned_history)
            m = unpinned_history[i]
            push!(recent_msgs, "[$(m.role)]: $(m.text)")
        end
        
        pinned_str = isempty(pinned_msgs) ? "No pinned rocks" : join(pinned_msgs, " | ")
        recent_str = isempty(recent_msgs) ? "No recent sounds" : join(recent_msgs, " | ")
        
        return "Deep Memory (Pinned): $pinned_str\nFresh Memory (Recent): $recent_str"
    catch e
        error("!!! FATAL: Chief Orchestrator failed to read memory wall: $e !!!")
    end
end

# GRUG DOC 3.9: SUPERPOSITION ORCHESTRATOR!
"""
ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})

GRUG: Superposition orchestrator. Finds heaviest rocks (max confidence) for "Sure"
basket, coinflips smaller rocks into "Unsure" basket. Builds AIML payload and
fires the generative engine. Throws on empty votes — NO SILENT FAILURES.
"""
function ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})
    if isempty(votes)
        error("!!! FATAL: Orchestrator failed: Cave empty! Received zero votes! Cannot build fire! !!!")
    end
    if strip(mission) == ""
        error("!!! FATAL: Orchestrator failed: Mission text is invisible wind! !!!")
    end

    # GRUG FIX: Sort votes by confidence descending BEFORE bucketing.
    # This guarantees the highest-confidence domain node wins primary slot,
    # not a boot seed that happened to be inserted first.
    sorted_votes = sort(votes; by = v -> v.confidence, rev = true)

    max_conf = sorted_votes[1].confidence

    sure_votes   = Vote[]
    unsure_votes = Vote[]

    for v in sorted_votes
        # GRUG: If rock is within 0.05 of the biggest rock, it is a SURE thing.
        if v.confidence >= max_conf - 0.05
            push!(sure_votes, v)
        else
            # GRUG: For smaller rocks, loop through and flip a flat 50/50 coin!
            # Side effects! If Keep wins, push to unsure_votes.
            @coinflip [
                bias(:Keep, 50) => () -> push!(unsure_votes, v),
                bias(:Drop, 50) => () -> nothing
            ]
        end
    end

    if isempty(sure_votes)
        # GRUG: Should be mathematically impossible, but Grug checks anyway! NO SILENT FAILURES!
        error("!!! FATAL: Grug math broke! Max confidence produced zero sure votes! !!!")
    end

    # GRUG: Primary action is first in sorted sure_votes = highest confidence winner.
    primary_vote = sure_votes[1]

    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    if isnothing(node)
        error("!!! FATAL: Winning node $(primary_vote.node_id) vanished before Grug could grab it! !!!")
    end

    # GRUG: Pass EVERYTHING to the command block so the Generative Engine can see Grug's whole mind!
    return COMMANDS[primary_vote.action](mission, node, primary_vote, sure_votes, unsure_votes, votes)
end

# ==============================================================================
# COMMAND DEFINITIONS & JIT TEXT GENERATION
# ==============================================================================

"""
generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, context)

GRUG: Build text sandwich for the JIT Generative Builder and synthesize
the dynamic response. Assembles system prompt, mission, vote context, and
memory into a single payload. Throws on missing context keys — NO SILENT FAILURES.
"""
function generate_aiml_payload(mission::String, primary_vote::Vote, sure_votes::Vector{Vote}, unsure_votes::Vector{Vote}, all_votes::Vector{Vote}, context::Dict)
    if !haskey(context, "system_prompt")
        error("!!! FATAL: Node dictionary missing 'system_prompt'! Grug confused! !!!")
    end

    system_prompt = context["system_prompt"]
    neg_str       = isempty(primary_vote.negatives) ? "None" : join(primary_vote.negatives, ", ")
    
    memory_str = extract_aiml_memory_context()
    lobe_str  = extract_lobe_aware_context(all_votes)

    sure_str   = join([v.action for v in sure_votes], ", ")
    unsure_str = isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", ")

    # GRUG: Read rule board. Swap shape-shifter words for real context chunks.
    # NOW STOCHASTIC: each rule fires based on its fire_probability.
    # This is where Grug JIT-compiles math into human language with natural variation!
    evaluated_rules = String[]
    try
        for rule in AIML_DROP_TABLE
            # GRUG: Roll a coinflip against the rule's fire probability.
            # prob=1.0 rules always fire. prob=0.5 rules fire ~half the time.
            if rand() > rule.fire_probability
                # GRUG: This rule lost its coinflip this round. Skip it!
                continue
            end

            processed = rule.text
            processed = replace(processed, "{MISSION}"        => mission)
            processed = replace(processed, "{PRIMARY_ACTION}" => primary_vote.action)
            processed = replace(processed, "{SURE_ACTIONS}"   => sure_str)
            processed = replace(processed, "{UNSURE_ACTIONS}" => unsure_str)
            processed = replace(processed, "{ALL_ACTIONS}"    => join([v.action for v in all_votes], ", "))
            processed = replace(processed, "{CONFIDENCE}"     => string(round(primary_vote.confidence, digits=2)))
            processed = replace(processed, "{NODE_ID}"        => primary_vote.node_id)
            processed = replace(processed, "{MEMORY}"         => memory_str)
            processed = replace(processed, "{LOBE_CONTEXT}"   => lobe_str)
            push!(evaluated_rules, processed)
        end
    catch e
        error("!!! FATAL: Grug failed to swap shape-shifter words in dynamic rules: $e !!!")
    end

    rules_str = isempty(evaluated_rules) ? "None" : join(evaluated_rules, " | ")

    # GRUG: Put relation verb-noun sandwiches into the prompt to provide grammar context.
    u_triples = isempty(primary_vote.user_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.user_triples], ", ")
    n_triples = isempty(primary_vote.node_triples) ? "None" : join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.node_triples], ", ")
    
    # GRUG DOC 3.4: Dynamic Stochastic Generation!
    # Grug uses the primary action AND the side-feature unsure actions to construct a highly varied output.
    jit_response = "[System Prompt Active: $system_prompt]\n"
    if primary_vote.action in ["greet", "welcome", "smile", "laugh"]
        jit_response *= "Hello human! I have received your input: '$mission'. "
    elseif primary_vote.action in ["flee", "hide", "fight"]
        jit_response *= "Warning! Evasive action protocol triggered by input: '$mission'. "
    else
        jit_response *= "Processing input... Executing logical analysis on: '$mission'. "
    end

    jit_response *= "I am entirely sure that I should: [$sure_str]. "
    if !isempty(unsure_votes)
        jit_response *= "However, due to stochastic variations, I am also considering these side features: [$unsure_str]. "
    end

    if !isempty(evaluated_rules)
        jit_response *= "\n[ENFORCING DYNAMIC USER RULES]:\n"
        for r in evaluated_rules
            jit_response *= " -> $r\n"
        end
    end

    # GRUG: Wait little bit so cpu fire not burn down hut.
    sleep(0.3) 
    
    out  = "SYNTHESIZED PAYLOAD. (Primary Confidence: $(round(primary_vote.confidence, digits=2))).\n"
    out *= "Mission: '$mission'\n"
    out *= "Primary Action: $(primary_vote.action)\n"
    out *= "Sure Actions: [$sure_str]\n"
    out *= "Unsure Actions (Coinflip Side-Features): [$unsure_str]\n"
    out *= "Dynamic Rules (Stochastic): [$rules_str]\n"
    out *= "Constraints: [$neg_str]\n"
    out *= "Context: '$system_prompt'\n"
    out *= "--- LOBE CONTEXT (PREFRONTAL CORTEX) ---\n"
    out *= "$lobe_str\n"
    out *= "--- RELATIONAL CONTEXT ---\n"
    out *= "User Triples: $u_triples\n"
    out *= "Node Triples: $n_triples\n"
    out *= "Anti-Match Detected: $(primary_vote.antimatch)\n"
    out *= "--- AIML MEMORY BANK ---\n$memory_str\n"
    out *= "=========================================\n"
    out *= "🗣️ STOCHASTIC GENERATION (JIT AIML):\n$jit_response\n"
    out *= "========================================="
    return out
end

# GRUG: Family of brain actions. Command must take all vote states now!
reason_family = ["reason", "analyze", "ponder", "calculate"]
for act in reason_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        if mission == "boom"
            error("!!! FATAL: Grug triggered intentional crash to test safety nets !!!")
        end
        node.json_data["last_reason"] = mission
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        
        # GRUG: If relations match well, node stay hot. Else, cool down fast.
        rel_strength = length(primary_vote.user_triples) > 0 ? 2.0 : 0.5
        reset_throttle!(node, rel_strength)
        return generated_text
    end
end

# GRUG: Family of happy face actions.
greet_family = ["greet", "welcome", "smile", "laugh"]
for act in greet_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
        reset_throttle!(node, 0.5)
        return generated_text
    end
end

# GRUG: Family of survival actions. Grug learn to run away!
survival_family = ["flee", "hide", "fight"]
for act in survival_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        # Give survival actions a unique payload if we want, or use the standard one
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Survival means danger! Keep the node throttle HOT!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# GRUG: Family of explain actions. Grug make things clear like cave painting!
explain_family = ["explain", "clarify", "describe", "define", "elaborate"]
for act in explain_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Explanations are cold logical work. Medium throttle.
        reset_throttle!(node, 0.7)

        return generated_text
    end
end

# GRUG: Family of empathy actions. Grug feel your pain!
empathy_family = ["comfort", "support", "validate", "acknowledge", "reassure"]
for act in empathy_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Emotional support - warm and open throttle.
        reset_throttle!(node, 0.5)

        return generated_text
    end
end

# GRUG: Family of warning actions. Grug shout danger before it arrives!
warning_family = ["alert", "warn", "caution", "notify", "flag"]
for act in warning_family
    COMMANDS[act] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
        generated_text = generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)

        # GRUG: Warnings are urgent! Keep throttle HOT like survival!
        reset_throttle!(node, 1.0)

        return generated_text
    end
end

# ==============================================================================
# IMAGE BINARY DETECTION HELPER (FOR /mission AND /grow)
# ==============================================================================

"""
maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}

GRUG: Pre-screen input text for image binary using regex from ImageSDF.
If image binary found:
  1. Decode image data from Base64 (or hex)
  2. Run JITGPU — real GPU-accelerated nonlinear SDF conversion via KernelAbstractions.jl
  3. Apply EyeSystem visual processing (edge blur, attention, arousal cutout)
  4. Apply SDF jitter (pineal drip)
  5. Convert to flat Float64 signal
  6. Return (true, signal)
If no image binary: return (false, Float64[])
Throws on empty input or conversion failure — NO SILENT FAILURES.
"""
function maybe_convert_image_input(input_text::String)::Tuple{Bool, Vector{Float64}}
    if strip(input_text) == ""
        error("!!! FATAL: maybe_convert_image_input got empty input! !!!")
    end

    found, fmt, payload = ImageSDF.detect_image_binary(input_text)
    if !found
        return (false, Float64[])
    end

    println("[IMAGE] 🖼  Image binary detected (format: $fmt). Running JIT SDF conversion...")

    try
        # GRUG: Decode raw image bytes based on detected format
        raw_bytes = if fmt == :base64
            base64decode(payload)
        elseif fmt == :hex_png || fmt == :hex_jpeg
            # GRUG: Convert hex string to bytes
            hex_clean = replace(payload, r"[^A-Fa-f0-9]" => "")
            # GRUG: Hex must be even length (2 chars per byte)
            if length(hex_clean) % 2 != 0
                hex_clean = hex_clean[1:end-1]
            end
            UInt8[parse(UInt8, hex_clean[i:i+1], base=16) for i in 1:2:length(hex_clean)]
        else
            # GRUG: Raw binary escape sequences - use payload bytes directly
            Vector{UInt8}(codeunits(payload))
        end

        if isempty(raw_bytes)
            error("!!! FATAL: Image decode produced empty byte array for format $fmt! !!!")
        end

        # GRUG: Estimate dimensions from byte count (assume square grayscale as fallback).
        # Real use case: width/height should come from image metadata.
        # For this JIT path, Grug use sqrt to estimate square-ish dimensions.
        n_bytes     = length(raw_bytes)
        est_side    = max(1, round(Int, sqrt(Float64(n_bytes))))
        est_width   = est_side
        est_height  = max(1, n_bytes ÷ est_side)

        # GRUG: Run JIT GPU-accelerated image -> SDFParams conversion
        # JITGPU dispatches real KernelAbstractions kernels: CUDA/ROC/Metal/CPU.
        # CPU() is genuine multithreaded kernel dispatch, not a fake fallback.
        sdf_params  = ImageSDF.JITGPU(raw_bytes; width=est_width, height=est_height)

        # GRUG: Apply EyeSystem visual processing (blur + attention modulation + arousal cutout)
        mod_brightness, _attn_map = EyeSystem.process_visual_input(
            sdf_params.brightnessArray,
            sdf_params.colorArray,
            sdf_params.xArray,
            sdf_params.yArray,
            sdf_params.width,
            sdf_params.height
        )

        # GRUG: Rebuild SDFParams with eye-processed brightness before jitter
        eye_params = ImageSDF.SDFParams(
            sdf_params.xArray, sdf_params.yArray,
            mod_brightness, sdf_params.colorArray,
            sdf_params.width, sdf_params.height,
            sdf_params.timestamp
        )

        # GRUG: Apply pineal drip jitter (slight deviation from bullseye, snaps back next call)
        jittered_params = ImageSDF.apply_sdf_jitter(eye_params)

        # GRUG: Convert to flat signal vector for PatternScanner compatibility
        signal = ImageSDF.sdf_to_signal(jittered_params; max_samples=256)

        println("[IMAGE] ✅  JIT SDF conversion complete. Signal length: $(length(signal)).")
        return (true, signal)

    catch e
        # GRUG: Image conversion failure is LOUD. No silent swallowing!
        error("!!! FATAL: JIT image->SDF conversion failed for format $fmt: $e !!!")
    end
end

# ==============================================================================
# MISSION PROCESSOR (EXTRACTED FOR QUEUE REUSE)
# ==============================================================================

# ==============================================================================
# GRUG: Consolidated UI string constants for compiler efficiency.
# Single-string print replaces ~100 individual println calls.
# Same output, zero string-table bloat at compile time.
# ==============================================================================

const BOOT_MSG = """
System Online. Grug waiting at cave entrance for instructions.
Primary  : /mission <input>                    (text or image binary)
Feedback : /wrong                              (penalize last response voters)
Explicit : /explicit <cmd> [<node_id>] <input>
Grow     : /grow <single_line_json_packet>
Rules    : /addRule <rule text> [prob=0.0-1.0]
           Tags: {MISSION}, {PRIMARY_ACTION}, {SURE_ACTIONS}, {UNSURE_ACTIONS},
                 {ALL_ACTIONS}, {CONFIDENCE}, {NODE_ID}, {MEMORY}, {LOBE_CONTEXT}
Memory   : /pin <text>
Nodes    : /nodes                              (show node map status)
Status   : /status                             (show chatter + system status)
Arousal  : /arousal <0.0-1.0>                 (set eye system arousal level)
Verbs    : /addVerb <verb> <class>             (add verb to relation class)
         : /addRelationClass <name>            (create new verb class bucket)
         : /addSynonym <canonical> <alias>     (normalize alias->canonical)
         : /listVerbs                          (show all verb classes + synonyms)
Lobes    : /newLobe <id> <subject>             (create a new subject lobe)
         : /connectLobes <id_a> <id_b>         (connect two lobes)
         : /lobeGrow <lobe_id> <json_packet>   (grow node into specific lobe)
         : /lobes                              (list all lobes + node counts)
         : /tableStatus <lobe_id>              (show hash table chunks for a lobe)
         : /tableMatch <lobe_id> <chunk> <pat> (pattern-activate entries in chunk)
Thesaurus: /thesaurus <word1> | <word2>        (compare words/concepts dimensionally)
         : /thesaurus <w1> | <w2> :: <ctx1> :: <ctx2>  (with context lists)
NegThes  : /negativeThesaurus add|remove|list|check|flush
Attach   : /nodeAttach <target> <id> <pat> ...  (attach nodes with relational fire patterns)
         : /nodeDetach <target> <id>            (detach a node from target)
ImgAttach: /imgnodeAttach <tgt> <id> <b64> [w h] (attach image node with SDF-based fire)
         : /imgnodeDetach <target> <id>         (detach image node from target)
         : /attachments                         (show all node attachments)
Specimen : /saveSpecimen <filepath>            (save full cave state to compressed file)
         : /loadSpecimen <filepath>            (restore full cave state from compressed file)
Help     : /help                               (full command reference)

╔══════════════════════════════════════════════════════════════════╗
║  SPECIMEN SEEDING GUIDE (read before /grow)                     ║
╠══════════════════════════════════════════════════════════════════╣
║  Automatic neighbor latching is SUPPRESSED below 1000 nodes.   ║
║  Below that threshold, YOU control topology via drop_table.     ║
║                                                                  ║
║  For a coherent specimen from the start:                        ║
║  1. Seed ORTHOGONAL archetypes first - distinct semantic poles. ║
║     Don't plant 50 near-identical nodes up front.               ║
║  2. Use required_relations as semantic GATES from day one.      ║
║     Nodes that demand specific verbs won't fire on noise.       ║
║  3. Name action_packets deliberately - distinct action families ║
║     give the superposition orchestrator something to work with. ║
║  4. Wire drop_tables manually for known co-activation pairs.    ║
║     Don't rely on the latch system to discover semantics.       ║
║  5. Your first ~100 nodes are the specimen's DNA.               ║
║     The engine enforces structure at scale (1000+ nodes).       ║
║     You enforce MEANING at the start.                           ║
╚══════════════════════════════════════════════════════════════════╝
"""

const HELP_MSG = """
╔══════════════════════════════════════════════════════════════╗
║                  GRUGBOT COMMAND REFERENCE                  ║
╠══════════════════════════════════════════════════════════════╣
║  CORE                                                        ║
║  /mission <text>            Send input to the AI engine      ║
║  /wrong                     Penalize last response voters    ║
║  /explicit <cmd> [<id>] <t> Force a specific command+node    ║
║  /grow <json>               Plant nodes from JSON packet     ║
║  /addRule <rule>            Add stochastic orchestration rule║
║  /pin <text>                Pin text to memory cave wall     ║
║                                                              ║
║  STATUS                                                      ║
║  /nodes                     Show all node map status         ║
║  /status                    Full system health snapshot      ║
║  /arousal <0.0-1.0>         Set eye system arousal level     ║
║                                                              ║
║  SEMANTIC VERBS                                              ║
║  /addVerb <verb> <class>    Add verb to relation class       ║
║  /addRelationClass <name>   Create new verb class bucket     ║
║  /addSynonym <canon> <alias> Register synonym normalization  ║
║  /listVerbs                 Show verb registry               ║
║                                                              ║
║  LOBES & TABLES                                              ║
║  /newLobe <id> <subject>    Create new subject partition     ║
║  /connectLobes <a> <b>      Link two lobes bidirectionally   ║
║  /lobeGrow <id> <json>      Grow node directly into lobe     ║
║  /lobes                     Show lobe status summary         ║
║  /tableStatus <lobe_id>     Show hash table chunk sizes      ║
║  /tableMatch <l> <c> <pat>  Pattern-activate table entries   ║
║                                                              ║
║  THESAURUS                                                   ║
║  /thesaurus <w1> | <w2>     Dimensional similarity compare   ║
║                                                              ║
║  NEGATIVE THESAURUS (INHIBITION FILTER)                     ║
║  /negativeThesaurus add <word> [--reason <text>]             ║
║  /negativeThesaurus remove <word>                           ║
║  /negativeThesaurus list                                    ║
║  /negativeThesaurus check <word>                            ║
║  /negativeThesaurus flush                                   ║
║                                                              ║
║  RELATIONAL FIRE (NODE ATTACHMENTS)                          ║
║  /nodeAttach <tgt> <id> <pat> ...                            ║
║    Attach up to 4 nodes to target with firing patterns       ║
║    Confidence JIT-baked at attach time (not at fire time)    ║
║    Example: /nodeAttach node_0 node_1 "fire pattern"         ║
║  /nodeDetach <target> <id>   Detach node from target         ║
║  /imgnodeAttach <tgt> <id> <b64> [w h]                       ║
║    Attach image node with SDF-based relational fire          ║
║    Image→SDF conversion at attach time (JIT GPU accel)       ║
║    Example: /imgnodeAttach n0 img1 "data:image/png;..." 64 64║
║  /imgnodeDetach <tgt> <id>   Detach image node from target   ║
║  /attachments                Show all attachment map          ║
║                                                              ║
║  SPECIMEN PERSISTENCE                                        ║
║  /saveSpecimen <filepath>    Save full cave to compressed gz ║
║  /loadSpecimen <filepath>    Restore full cave from gz file  ║
║    Saves/restores: nodes, lobes, lobe tables, Hopfield,     ║
║    rules, messages+pins, verbs, thesaurus, inhibitions,     ║
║    arousal, ID counters, brainstem state, attachments        ║
║                                                              ║
║  /help                      Show this scroll                ║
╚══════════════════════════════════════════════════════════════╝
"""

# GRUG: Track last voter IDs so /wrong knows who to punish
const LAST_VOTER_IDS = String[]
const LAST_VOTER_LOCK = ReentrantLock()

"""
process_mission(mission_text::String)

GRUG: Core mission processing logic, extracted so chatter queue can reuse it.
Handles both text missions and image-binary missions.
Measures response time and records it on the winning nodes for big-O ledger.
"""
function process_mission(mission_text::String)
    if strip(mission_text) == ""
        error("!!! FATAL: process_mission got empty mission text! !!!")
    end

    add_message_to_history!("User", mission_text, false)
    
    # GRUG: Pre-screen for image binary BEFORE normal scan
    is_image, img_signal = maybe_convert_image_input(mission_text)

    # GRUG: ACTION+TONE AROUSAL PRE-SET (text inputs only)
    # For text missions, run the predictor here to nudge EyeSystem arousal BEFORE
    # the scan starts. Image inputs skip this — SDF has its own visual arousal path.
    #
    # WHY HERE AND NOT JUST IN scan_specimens?
    # scan_specimens uses the prediction for confidence weighting (its own concern).
    # Arousal is an EyeSystem concern — it belongs in Main where EyeSystem lives.
    # Running it here means the eye is already tuned by the time scan fires.
    # The two calls are intentionally separate: one modulates scan weights,
    # the other modulates the visual attention gate. They are orthogonal.
    #
    # GRUG: Non-fatal on error. Arousal nudge is enhancement, not core pipeline.
    # If prediction throws for any reason, cave still scans normally.
    if !is_image
        try
            prediction = ActionTonePredictor.predict_action_tone(
                mission_text, SemanticVerbs.get_all_verbs()
            )
            ActionTonePredictor.apply_prediction_to_arousal!(
                prediction,
                EyeSystem.get_arousal,
                EyeSystem.set_arousal!
            )
        catch e
            @warn "[MAIN] ActionTonePredictor arousal nudge failed (non-fatal): $e"
        end
    end

    # GRUG: THESAURUS GATE EXPANSION (text inputs only)
    # Before the scan fires, expand the mission tokens with synonym cloud.
    # This bridges the structural gap (happy/joyful = 0.0 without seeds).
    # Expansion is logged so operator can see what the gate added.
    # Non-fatal: if thesaurus throws for any reason, scan proceeds on raw text.
    if !is_image
        try
            gate_tokens = Thesaurus.thesaurus_gate_filter(mission_text)
            original_tokens = Set(split(lowercase(strip(mission_text))))
            new_tokens = setdiff(gate_tokens, original_tokens)
            if !isempty(new_tokens)
                @info "[MAIN] 🔤 Thesaurus gate expanded $(length(original_tokens)) tokens → $(length(gate_tokens)) (+$(length(new_tokens)) synonyms: $(join(sort(collect(new_tokens)), ", ")))"
            end
        catch e
            @warn "[MAIN] Thesaurus gate expansion failed (non-fatal): $e"
        end
    end

    println("--> Scanning specimens & looking for dialectical relations...")
    t_start = time()

    valid_specimens = if is_image
        # GRUG: Image input! Scan image nodes using SDF signal.
        println("[IMAGE] 🔍  Routing to image node scan path...")
        _scan_image_specimens(img_signal)
    else
        # GRUG: Normal text scan with drop-table expansion
        scan_and_expand(mission_text)
    end

    if isempty(valid_specimens)
        println("--> No valid specimens found for this input. Cave is silent.")
        return
    end

    cast_votes = Vote[]
    for (id, conf, is_antimatch, u_trips, n_trips) in valid_specimens
        push!(cast_votes, cast_vote(id, conf, is_antimatch, u_trips, n_trips))
    end

    println("--> $(length(cast_votes)) valid votes passed gate... compiling JIT superposition...")
    output = ephemeral_aiml_orchestrator(mission_text, cast_votes)

    t_elapsed = time() - t_start

    # GRUG: Record response time on all winning node voters for big-O ledger
    for v in cast_votes
        voter_node = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
        if !isnothing(voter_node)
            record_response_time!(voter_node, t_elapsed)
        end
    end

    # GRUG: Store voter IDs so /wrong can punish them if user is unhappy
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
        append!(LAST_VOTER_IDS, [v.node_id for v in cast_votes])
    end

    println("\n🤖 AIML Output Scaffold:\n$output")
    add_message_to_history!("System", output, false)
end

# ==============================================================================
# IMAGE NODE SCAN PATH
# ==============================================================================

"""
_scan_image_specimens(img_signal::Vector{Float64})::Vector{Tuple{...}}

GRUG: Scan only image nodes using SDF signal vector.
Text nodes are skipped. Image nodes use their stored SDF signal for comparison.
Returns same tuple format as scan_specimens for uniform downstream processing.
"""
function _scan_image_specimens(img_signal::Vector{Float64})
    if isempty(img_signal)
        error("!!! FATAL: _scan_image_specimens got empty img_signal! !!!")
    end

    results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}}[]

    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            # GRUG: Only image nodes respond to image signals
            !node.is_image_node && continue
            node.is_grave       && continue

            # GRUG: Strength-biased coinflip applies to image nodes too
            !strength_biased_scan_coinflip(node) && continue

            # GRUG: Image node needs a non-empty SDF signal to compare against
            if isempty(node.signal)
                # GRUG: Image node has no signal baked in yet. Skip safely.
                continue
            end

            # GRUG: Use cheap_scan for image signals (SDF comparison)
            try
                target = length(img_signal) >= length(node.signal) ? img_signal : continue
                _, conf = cheap_scan(target, node.signal; threshold=0.25)
                push!(results, (id, conf, false, RelationalTriple[], node.relational_patterns))
            catch e
                if e isa PatternNotFoundError
                    continue
                elseif e isa PatternScanError
                    rethrow(e)
                else
                    error("!!! FATAL: Unknown error in _scan_image_specimens for node $id: $e !!!")
                end
            end
        end
    end

    return results
end

# ==============================================================================
# SPECIMEN PERSISTENCE (SAVE / LOAD FULL CAVE STATE FROM COMPRESSED FILE)
# ==============================================================================

# GRUG: /saveSpecimen writes the ENTIRE cave state to a gzip-compressed JSON file.
# /loadSpecimen reads that file back and RESTORES the ENTIRE cave from scratch.
# This is LONG-TERM STORAGE. Not "add a few nodes" — this is "freeze the whole brain,
# put it in a jar, thaw it later with every neuron exactly where Grug left it."
# No silent failures. No half-restores. If the file is bad, NOTHING changes.
# Grug screams loud. Grug validates everything. Grug is paranoid.

"""
save_specimen_to_file!(filepath::String)::String

GRUG: Serialize the ENTIRE cave state to a gzip-compressed JSON file.
Captures ALL mutable state across all modules:
  - nodes       (full Node struct: strengths, patterns, neighbors, graves, etc.)
  - hopfield    (HOPFIELD_CACHE + hit counts)
  - rules       (AIML_DROP_TABLE stochastic rules)
  - messages    (up to 10k message history with pin flags)
  - lobes       (LOBE_REGISTRY: fire/inhibit counts, connections, node assignments)
  - lobe_tables (LOBE_TABLE_REGISTRY: all chunks with NodeRef objects)
  - verbs       (verb classes + verbs + synonyms from SemanticVerbs)
  - thesaurus   (SYNONYM_SEED_MAP runtime additions from Thesaurus)
  - inhibitions (NegativeThesaurus entries from InputQueue)
  - arousal     (EyeSystem arousal state: level, decay, baseline)
  - counters    (NODE ID_COUNTER + MSG_ID_COUNTER)
  - brainstem   (dispatch count, propagation history)
  - attachments (ATTACHMENT_MAP relational fire system)
  - trajectory  (ActionTonePredictor ring buffer + config)
  - temporal    (ImageSDF TEMPORAL_COHERENCE_LEDGER timing patterns)
  - cooldowns   (ChatterMode MORPH_COOLDOWN_MAP 24h morph timestamps)

Format: v2.1 (backward-compatible with v2.0 on load).
Returns a formatted summary string.
"""
function save_specimen_to_file!(filepath::String)::String
    if strip(filepath) == ""
        error("!!! FATAL: /saveSpecimen got empty filepath! Grug cannot write to invisible air! !!!")
    end

    # GRUG: Build the specimen dict — one key per state category.
    specimen = Dict{String, Any}()
    t_start = time()

    # ── 1. NODES ──────────────────────────────────────────────────────────
    # GRUG: Serialize every node in NODE_MAP with ALL fields.
    # We bypass create_node() on restore and inject directly, so we need EVERYTHING.
    node_list = Dict{String, Any}[]
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            nd = Dict{String, Any}(
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
                "hopfield_key"        => string(node.hopfield_key)  # UInt64 -> String for JSON safety
            )
            push!(node_list, nd)
        end
    end
    specimen["nodes"] = node_list

    # ── 2. HOPFIELD CACHE ─────────────────────────────────────────────────
    # GRUG: Serialize Hopfield fast-path cache keyed by UInt64 hash -> node ID list.
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
    specimen["hopfield_cache"] = hopfield_entries

    # ── 3. RULES (AIML_DROP_TABLE) ────────────────────────────────────────
    # GRUG: r.text and r.fire_probability are the actual struct field names.
    # Academic: Previously used r.rule_text / r.fire_prob which would cause a
    # Julia field access error at runtime. Fixed in v2.1.
    rule_list = [Dict{String, Any}("text" => r.text, "prob" => r.fire_probability) for r in AIML_DROP_TABLE]
    specimen["rules"] = rule_list

    # ── 4. MESSAGE HISTORY ────────────────────────────────────────────────
    # GRUG: Serialize the full message cave (up to 10k entries). Pins are preserved.
    msg_list = [Dict{String, Any}(
        "id"     => m.id,
        "role"   => m.role,
        "text"   => m.text,
        "pinned" => m.pinned
    ) for m in MESSAGE_HISTORY]
    specimen["message_history"] = msg_list

    # ── 5. LOBES ──────────────────────────────────────────────────────────
    lobe_list = Dict{String, Any}[]
    lock(Lobe.LOBE_LOCK) do
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
    end
    specimen["lobes"] = lobe_list

    # ── 6. NODE_TO_LOBE_IDX ──────────────────────────────────────────────
    node_lobe_idx = Dict{String, String}()
    lock(Lobe.LOBE_LOCK) do
        for (nid, lid) in Lobe.NODE_TO_LOBE_IDX
            node_lobe_idx[nid] = lid
        end
    end
    specimen["node_to_lobe_idx"] = node_lobe_idx

    # ── 7. LOBE TABLES ───────────────────────────────────────────────────
    # GRUG: Serialize all lobe table chunks. NodeRef objects are converted to dicts.
    lobe_table_list = Dict{String, Any}[]
    lock(LobeTable.TABLE_REGISTRY_LOCK) do
        for (lid, rec) in LobeTable.LOBE_TABLE_REGISTRY
            chunks_data = Dict{String, Any}()
            for (cname, chunk) in rec.chunks
                lock(chunk.lock) do
                    entries = Dict{String, Any}()
                    for (k, v) in chunk.store
                        if v isa LobeTable.NodeRef
                            entries[k] = Dict{String, Any}(
                                "_type"       => "NodeRef",
                                "node_id"     => v.node_id,
                                "lobe_id"     => v.lobe_id,
                                "is_active"   => v.is_active,
                                "inserted_at" => v.inserted_at
                            )
                        else
                            # GRUG: Generic value — store as-is (json, drop, hopfield, meta chunks)
                            entries[k] = v
                        end
                    end
                    chunks_data[cname] = entries
                end
            end
            push!(lobe_table_list, Dict{String, Any}(
                "lobe_id"    => rec.lobe_id,
                "chunks"     => chunks_data,
                "created_at" => rec.created_at
            ))
        end
    end
    specimen["lobe_tables"] = lobe_table_list

    # ── 8. VERB REGISTRY ─────────────────────────────────────────────────
    verb_data = Dict{String, Any}()
    lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
        classes = Dict{String, Any}()
        for (cls, verbs) in SemanticVerbs._VERB_REGISTRY
            classes[cls] = sort(collect(verbs))
        end
        verb_data["classes"] = classes
        verb_data["synonyms"] = copy(SemanticVerbs._SYNONYM_MAP)
    end
    specimen["verb_registry"] = verb_data

    # ── 9. THESAURUS SEEDS ────────────────────────────────────────────────
    # GRUG: Serialize the SYNONYM_SEED_MAP (includes hardcoded + runtime additions).
    thesaurus_data = Dict{String, Any}()
    lock(Thesaurus.SEED_MAP_LOCK) do
        for (word, syns) in Thesaurus.SYNONYM_SEED_MAP
            thesaurus_data[word] = sort(collect(syns))
        end
    end
    specimen["thesaurus_seeds"] = thesaurus_data

    # ── 10. INHIBITIONS (NegativeThesaurus) ───────────────────────────────
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
    specimen["inhibitions"] = inhib_list

    # ── 11. AROUSAL STATE ─────────────────────────────────────────────────
    arousal_data = Dict{String, Any}()
    lock(EyeSystem.AROUSAL_LOCK) do
        arousal_data["level"]      = EyeSystem.AROUSAL_STATE.level
        arousal_data["decay_rate"] = EyeSystem.AROUSAL_STATE.decay_rate
        arousal_data["baseline"]   = EyeSystem.AROUSAL_STATE.baseline
    end
    specimen["arousal"] = arousal_data

    # ── 12. ID COUNTERS ──────────────────────────────────────────────────
    specimen["id_counters"] = Dict{String, Any}(
        "node_id_counter" => ID_COUNTER[],
        "msg_id_counter"  => MSG_ID_COUNTER[]
    )

    # ── 13. BRAINSTEM STATE ──────────────────────────────────────────────
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
    specimen["brainstem"] = brainstem_data

    # ── 14. ATTACHMENTS (RELATIONAL FIRE SYSTEM) ──────────────────────────────
    # GRUG: Serialize the ATTACHMENT_MAP. Each target_id maps to a list of
    # AttachedNode structs (node_id, pattern, signal, base_confidence).
    # base_confidence is the JIT-baked value computed at attach time.
    attachment_list = Dict{String, Any}[]
    lock(ATTACHMENT_LOCK) do
        for (target_id, attachments) in ATTACHMENT_MAP
            for att in attachments
                push!(attachment_list, Dict{String, Any}(
                    "target_id"       => target_id,
                    "node_id"         => att.node_id,
                    "pattern"         => att.pattern,
                    "signal"          => att.signal,
                    "base_confidence" => att.base_confidence
                ))
            end
        end
    end
    specimen["attachments"] = attachment_list


    # ── 15. TRAJECTORY STATE (ActionTonePredictor) ────────────────
    # GRUG: Save the trajectory ring buffer + config knobs.
    # Academic: The trajectory buffer tracks the system's path through
    # action-tone space. Without persistence, Lorenz attractor damping
    # resets on every load — the specimen forgets its behavioral inertia.
    trajectory_data = Dict{String, Any}()
    lock(ActionTonePredictor._trajectory_lock) do
        config = ActionTonePredictor._trajectory_config[]
        trajectory_data["config"] = Dict{String, Any}(
            "buffer_size"         => config.buffer_size,
            "decay_halflife"      => config.decay_halflife,
            "gini_threshold"      => config.gini_threshold,
            "damping_strength"    => config.damping_strength,
            "softmax_temperature" => config.softmax_temperature
        )
        buf_entries = Dict{String, Any}[]
        for entry in ActionTonePredictor._trajectory_buffer
            push!(buf_entries, Dict{String, Any}(
                "action_dist" => Dict(string(k) => v for (k, v) in entry.action_dist),
                "tone_dist"   => Dict(string(k) => v for (k, v) in entry.tone_dist),
                "timestamp"   => entry.timestamp
            ))
        end
        trajectory_data["buffer"] = buf_entries
    end
    specimen["trajectory"] = trajectory_data

    # ── 16. TEMPORAL COHERENCE LEDGER (ImageSDF) ──────────────────
    # GRUG: Save the SDF timing patterns so temporal coherence survives reload.
    # Academic: Without this, the coherence_score for every SDF resets to zero
    # on load, destroying the temporal stability model for image nodes.
    tcl_list = Dict{String, Any}[]
    lock(ImageSDF.TCL_LOCK) do
        for (sdf_id, rec) in ImageSDF.TEMPORAL_COHERENCE_LEDGER
            push!(tcl_list, Dict{String, Any}(
                "sdf_id"          => rec.sdf_id,
                "last_fired"      => rec.last_fired,
                "fire_count"      => rec.fire_count,
                "avg_interval"    => rec.avg_interval,
                "coherence_score" => rec.coherence_score
            ))
        end
    end
    specimen["temporal_coherence"] = tcl_list

    # ── 17. MORPH COOLDOWN MAP (ChatterMode) ─────────────────────
    # GRUG: Save the 24h morph cooldown timestamps so morphed nodes stay on cooldown after reload.
    # Academic: Without persistence, a save/load cycle would reset all cooldowns,
    # allowing nodes to morph again immediately — violating the 24h invariant.
    cooldown_data = Dict{String, Any}()
    lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
        for (node_id, ts) in ChatterMode.MORPH_COOLDOWN_MAP
            cooldown_data[node_id] = ts
        end
    end
    specimen["morph_cooldowns"] = cooldown_data

    # ── METADATA ──────────────────────────────────────────────────
    # GRUG: Version bumped to 2.1 — added trajectory, temporal_coherence, morph_cooldowns.
    # Academic: v2.1 is backward-compatible with v2.0 on load (new keys are optional).
    # —— 18. IMMUNE SYSTEM STATE ————————————————————————————
    # GRUG: Save immune Hopfield memory + ledger so specimen remembers what was safe/funky.
    # Academic: Without this, the immune system resets on every load —
    # losing all learned safe signatures and audit history.
    specimen["immune_system"] = ImmuneSystem.serialize_immune_state()

    specimen["_meta"] = Dict{String, Any}(
        "version"    => "2.2",
        "saved_at"   => time(),
        "format"     => "grugbot420-specimen-v2.2"
    )

    # ── SERIALIZE + COMPRESS ──────────────────────────────────────────────
    # GRUG: Convert to JSON string, then gzip compress to file.
    # Use system gzip via pipeline — no extra packages needed. Grug like simple.
    json_str = JSON.json(specimen, 2)  # pretty-print with indent=2

    try
        proc = open(`gzip -c`, "r+")
        write(proc, json_str)
        close(proc.in)
        compressed = read(proc)
        open(filepath, "w") do io
            write(io, compressed)
        end
    catch e
        error("!!! FATAL: /saveSpecimen failed to write compressed file '$filepath': $e !!!")
    end

    elapsed = round(time() - t_start, digits=2)
    file_size = filesize(filepath)
    json_size = sizeof(json_str)
    ratio = json_size > 0 ? round(100.0 * (1.0 - file_size / json_size), digits=1) : 0.0

    # GRUG: Build the victory scroll
    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(lines, "║            🧊 SPECIMEN SAVED SUCCESSFULLY                    ║")
    push!(lines, "╠══════════════════════════════════════════════════════════════╣")
    push!(lines, "  📁  File             : $filepath")
    push!(lines, "  📦  JSON size        : $(json_size) bytes")
    push!(lines, "  🗜️   Compressed size  : $(file_size) bytes ($(ratio)% smaller)")
    push!(lines, "  ⏱️   Time             : $(elapsed)s")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🌱  Nodes            : $(length(node_list))")
    push!(lines, "  🧠  Lobes            : $(length(lobe_list))")
    push!(lines, "  📋  Lobe tables      : $(length(lobe_table_list))")
    push!(lines, "  ⚡  Hopfield entries  : $(length(hopfield_entries))")
    push!(lines, "  ⚙️   Rules            : $(length(rule_list))")
    push!(lines, "  💬  Messages         : $(length(msg_list))")
    push!(lines, "  🔧  Verb classes     : $(length(get(verb_data, "classes", Dict())))")
    push!(lines, "  🔤  Thesaurus words  : $(length(thesaurus_data))")
    push!(lines, "  🚫  Inhibitions      : $(length(inhib_list))")
    push!(lines, "  🔗  Attachments      : $(length(attachment_list))")
    _traj_buf = get(trajectory_data, "buffer", [])
    push!(lines, "  🔮  Trajectory entries : $(length(_traj_buf))")
    push!(lines, "  🕐  Temporal coherence : $(length(tcl_list))")
    push!(lines, "  ⏳  Morph cooldowns    : $(length(cooldown_data))")
    push!(lines, "  👁   Arousal          : $(arousal_data["level"])")
    push!(lines, "╚══════════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end


"""
load_specimen_from_file!(filepath::String)::String

GRUG: Read a gzip-compressed JSON specimen file and RESTORE the ENTIRE cave state.
This is a DESTRUCTIVE operation — current cave state is WIPED and replaced with
the specimen contents. Think of it as brain transplant, not brain addition.

Phase 1: Read + decompress + parse the file
Phase 2: Validate the entire specimen structure
Phase 3: WIPE all current mutable state
Phase 4: RESTORE all state from specimen
Phase 5: Build summary scroll

Returns a multi-line summary string of everything restored.
"""
function load_specimen_from_file!(filepath::String)::String
    if strip(filepath) == ""
        error("!!! FATAL: /loadSpecimen got empty filepath! Grug needs a file to thaw! !!!")
    end

    if !isfile(filepath)
        error("!!! FATAL: /loadSpecimen file not found: '$filepath'! Check path and try again! !!!")
    end

    t_start = time()
    file_size = filesize(filepath)

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 1: READ + DECOMPRESS + PARSE
    # ══════════════════════════════════════════════════════════════════════

    # GRUG: Read compressed file and decompress via pipeline to gunzip.
    # No extra packages needed — just shell out to gunzip. Grug like simple.
    json_str = try
        compressed_bytes = read(filepath)
        proc = open(`gunzip -c`, "r+")
        write(proc, compressed_bytes)
        close(proc.in)
        String(read(proc))
    catch e
        error("!!! FATAL: /loadSpecimen failed to read/decompress '$filepath': $e !!!")
    end

    if strip(json_str) == ""
        error("!!! FATAL: /loadSpecimen decompressed file is empty! Bad specimen jar! !!!")
    end

    specimen = try
        JSON.parse(json_str)
    catch e
        error("!!! FATAL: /loadSpecimen JSON parse failed after decompression: $e !!!")
    end

    if !isa(specimen, Dict)
        error("!!! FATAL: /loadSpecimen expects a JSON object at top level, got $(typeof(specimen))! !!!")
    end

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 2: VALIDATE STRUCTURE
    # GRUG: Check that all sections exist and have correct types.
    # We don't validate every field here — the restore phase handles
    # individual field errors with try/catch. But we catch structural
    # problems early to avoid partial wipes. Grug is paranoid.
    # ══════════════════════════════════════════════════════════════════════

    validation_errors = String[]

    # GRUG: Allowed top-level keys
    allowed_keys = Set(["nodes", "hopfield_cache", "rules", "message_history",
                        "lobes", "node_to_lobe_idx", "lobe_tables",
                        "verb_registry", "thesaurus_seeds", "inhibitions",
                        "arousal", "id_counters", "brainstem", "attachments",
                        "trajectory", "temporal_coherence", "morph_cooldowns", "immune_system", "_meta"])
    for key in keys(specimen)
        if !(key in allowed_keys)
            push!(validation_errors, "Unknown top-level key '$key'")
        end
    end

    # GRUG: Type checks for critical array sections
    for k in ["nodes", "hopfield_cache", "rules", "message_history", "lobes", "lobe_tables", "inhibitions", "temporal_coherence"]
        if haskey(specimen, k) && !isa(specimen[k], AbstractVector)
            push!(validation_errors, "'$k' must be an array")
        end
    end

    # GRUG: Type checks for critical dict sections
    for k in ["node_to_lobe_idx", "verb_registry", "thesaurus_seeds", "arousal", "id_counters", "brainstem",
             "trajectory", "morph_cooldowns", "immune_system", "_meta"]
        if haskey(specimen, k) && !isa(specimen[k], Dict)
            push!(validation_errors, "'$k' must be an object")
        end
    end

    # GRUG: Validate nodes have required fields (spot-check first 5)
    if haskey(specimen, "nodes") && isa(specimen["nodes"], AbstractVector)
        for (i, nd) in enumerate(specimen["nodes"])
            i > 5 && break
            if !isa(nd, Dict)
                push!(validation_errors, "nodes[$i]: not a JSON object")
            elseif !haskey(nd, "id") || !haskey(nd, "pattern") || !haskey(nd, "action_packet")
                push!(validation_errors, "nodes[$i]: missing 'id', 'pattern', or 'action_packet'")
            end
        end
    end

    if !isempty(validation_errors)
        err_list = join(["  - $e" for e in validation_errors], "\n")
        error("!!! FATAL: /loadSpecimen validation failed with $(length(validation_errors)) error(s):\n$err_list\n!!! NO CHANGES MADE. Fix the specimen file and try again. !!!")
    end

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 3: WIPE ALL CURRENT STATE
    # GRUG: Clear EVERYTHING. This is a brain transplant. Old brain goes in the bin.
    # Order doesn't matter for wipe — we lock everything and empty it.
    # ══════════════════════════════════════════════════════════════════════

    println("  🧹 Wiping current cave state...")

    # Wipe nodes
    lock(NODE_LOCK) do
        empty!(NODE_MAP)
    end

    # Wipe Hopfield cache
    lock(HOPFIELD_CACHE_LOCK) do
        empty!(HOPFIELD_CACHE)
        empty!(HOPFIELD_HIT_COUNTS)
    end

    # Wipe AIML rules
    empty!(AIML_DROP_TABLE)

    # Wipe message history
    empty!(MESSAGE_HISTORY)

    # Wipe lobes + index
    lock(Lobe.LOBE_LOCK) do
        empty!(Lobe.LOBE_REGISTRY)
        empty!(Lobe.NODE_TO_LOBE_IDX)
    end

    # Wipe lobe tables
    lock(LobeTable.TABLE_REGISTRY_LOCK) do
        empty!(LobeTable.LOBE_TABLE_REGISTRY)
    end

    # Wipe verb registry
    lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
        empty!(SemanticVerbs._VERB_REGISTRY)
        empty!(SemanticVerbs._VERB_TO_CLASS)
        empty!(SemanticVerbs._SYNONYM_MAP)
    end

    # Wipe thesaurus seeds
    lock(Thesaurus.SEED_MAP_LOCK) do
        empty!(Thesaurus.SYNONYM_SEED_MAP)
    end

    # Wipe inhibitions
    lock(InputQueue._NEG_LOCK) do
        empty!(InputQueue._NEG_THESAURUS)
    end

    # Wipe brainstem state
    lock(BrainStem.BRAINSTEM_LOCK) do
        BrainStem.BRAINSTEM_STATE.dispatch_count = 0
        BrainStem.BRAINSTEM_STATE.last_winner_id = ""
        BrainStem.BRAINSTEM_STATE.last_dispatch_t = 0.0
        BrainStem.BRAINSTEM_STATE.is_dispatching = false
        empty!(BrainStem.BRAINSTEM_STATE.propagation_history)
    end

    # Wipe last voter IDs
    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
    end

    # Wipe attachments (relational fire system)
    lock(ATTACHMENT_LOCK) do
        empty!(ATTACHMENT_MAP)
    end


    # Wipe trajectory state (ActionTonePredictor)
    # GRUG: Reset the trajectory ring buffer and config back to defaults.
    lock(ActionTonePredictor._trajectory_lock) do
        empty!(ActionTonePredictor._trajectory_buffer)
        ActionTonePredictor._trajectory_config[] = ActionTonePredictor.DEFAULT_TRAJECTORY_CONFIG
    end

    # Wipe temporal coherence ledger (ImageSDF)
    # GRUG: Clear all SDF timing patterns. Fresh start for image coherence.
    lock(ImageSDF.TCL_LOCK) do
        empty!(ImageSDF.TEMPORAL_COHERENCE_LEDGER)
    end

    # Wipe morph cooldown map (ChatterMode)
    # GRUG: Clear all morph cooldowns. Specimen will bring its own.
    lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
        empty!(ChatterMode.MORPH_COOLDOWN_MAP)
    end

    # Wipe immune system state
    # GRUG: Clear all immune memory. Specimen will bring its own.
    ImmuneSystem.reset_immune_state!()

    println("  ✅ Cave wiped clean. Beginning restore...")

    # ══════════════════════════════════════════════════════════════════════
    # PHASE 4: RESTORE ALL STATE FROM SPECIMEN
    # GRUG: Rebuild the cave brick by brick. Order matters here:
    # ID counters -> verb registry -> thesaurus -> lobes -> lobe tables ->
    # nodes -> node_to_lobe_idx -> hopfield cache -> rules -> inhibitions ->
    # messages -> arousal -> brainstem -> attachments -> trajectory ->
    # temporal_coherence -> morph_cooldowns
    # ══════════════════════════════════════════════════════════════════════

    counts = Dict{String,Int}()

    # ── 4.1 ID COUNTERS ──────────────────────────────────────────────────
    if haskey(specimen, "id_counters")
        idc = specimen["id_counters"]
        if haskey(idc, "node_id_counter")
            ID_COUNTER[] = Int(idc["node_id_counter"])
        end
        if haskey(idc, "msg_id_counter")
            MSG_ID_COUNTER[] = Int(idc["msg_id_counter"])
        end
        println("  🔢 ID counters restored (node=$(ID_COUNTER[]), msg=$(MSG_ID_COUNTER[]))")
    end

    # ── 4.2 VERB REGISTRY ────────────────────────────────────────────────
    n_verb_classes = 0
    n_verbs = 0
    n_verb_synonyms = 0
    if haskey(specimen, "verb_registry")
        vr = specimen["verb_registry"]
        lock(SemanticVerbs.VERB_REGISTRY_LOCK) do
            # Restore classes + verbs
            if haskey(vr, "classes") && isa(vr["classes"], Dict)
                for (cls, verbs) in vr["classes"]
                    SemanticVerbs._VERB_REGISTRY[String(cls)] = Set{String}(String.(verbs))
                    n_verb_classes += 1
                    n_verbs += length(verbs)
                end
            end
            # Restore synonyms
            if haskey(vr, "synonyms") && isa(vr["synonyms"], Dict)
                for (alias, canon) in vr["synonyms"]
                    SemanticVerbs._SYNONYM_MAP[String(alias)] = String(canon)
                    n_verb_synonyms += 1
                end
            end
            # Rebuild reverse map (_VERB_TO_CLASS)
            SemanticVerbs._rebuild_verb_to_class!()
        end
        counts["verb_classes"] = n_verb_classes
        counts["verbs"] = n_verbs
        counts["verb_synonyms"] = n_verb_synonyms
        println("  🔧 Verb registry restored ($n_verb_classes classes, $n_verbs verbs, $n_verb_synonyms synonyms)")
    end

    # ── 4.3 THESAURUS SEEDS ──────────────────────────────────────────────
    n_thesaurus = 0
    if haskey(specimen, "thesaurus_seeds") && isa(specimen["thesaurus_seeds"], Dict)
        lock(Thesaurus.SEED_MAP_LOCK) do
            for (word, syns) in specimen["thesaurus_seeds"]
                Thesaurus.SYNONYM_SEED_MAP[String(word)] = Set{String}(String.(syns))
                n_thesaurus += 1
            end
        end
        counts["thesaurus_words"] = n_thesaurus
        println("  🔤 Thesaurus restored ($n_thesaurus words)")
    end

    # ── 4.4 LOBES ────────────────────────────────────────────────────────
    n_lobes = 0
    if haskey(specimen, "lobes") && isa(specimen["lobes"], AbstractVector)
        lock(Lobe.LOBE_LOCK) do
            for ldata in specimen["lobes"]
                try
                    rec = Lobe.LobeRecord(
                        String(ldata["id"]),
                        String(ldata["subject"]),
                        Set{String}(String.(get(ldata, "node_ids", String[]))),
                        Set{String}(String.(get(ldata, "connected_lobe_ids", String[]))),
                        Int(get(ldata, "node_cap", Lobe.LOBE_NODE_CAP)),
                        Int(get(ldata, "fire_count", 0)),
                        Int(get(ldata, "inhibit_count", 0)),
                        Float64(get(ldata, "created_at", time()))
                    )
                    Lobe.LOBE_REGISTRY[rec.id] = rec
                    n_lobes += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore lobe '$(get(ldata, "id", "?"))': $e !!!")
                end
            end
        end
        counts["lobes"] = n_lobes
        println("  🧠 Lobes restored ($n_lobes)")
    end

    # ── 4.5 LOBE TABLES ──────────────────────────────────────────────────
    n_lobe_tables = 0
    if haskey(specimen, "lobe_tables") && isa(specimen["lobe_tables"], AbstractVector)
        lock(LobeTable.TABLE_REGISTRY_LOCK) do
            for ltdata in specimen["lobe_tables"]
                try
                    lid = String(ltdata["lobe_id"])
                    chunks = Dict{String, LobeTable.LobeTableChunk}()
                    if haskey(ltdata, "chunks") && isa(ltdata["chunks"], Dict)
                        for (cname, entries) in ltdata["chunks"]
                            chunk = LobeTable.LobeTableChunk(
                                String(cname),
                                Dict{String, Any}(),
                                ReentrantLock()
                            )
                            if isa(entries, Dict)
                                for (k, v) in entries
                                    if isa(v, Dict) && get(v, "_type", "") == "NodeRef"
                                        chunk.store[String(k)] = LobeTable.NodeRef(
                                            String(v["node_id"]),
                                            String(v["lobe_id"]),
                                            Bool(v["is_active"]),
                                            Float64(get(v, "inserted_at", time()))
                                        )
                                    else
                                        chunk.store[String(k)] = v
                                    end
                                end
                            end
                            chunks[String(cname)] = chunk
                        end
                    end
                    rec = LobeTable.LobeTableRecord(
                        lid,
                        chunks,
                        Float64(get(ltdata, "created_at", time()))
                    )
                    LobeTable.LOBE_TABLE_REGISTRY[lid] = rec
                    n_lobe_tables += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore lobe table '$(get(ltdata, "lobe_id", "?"))': $e !!!")
                end
            end
        end
        counts["lobe_tables"] = n_lobe_tables
        println("  📋 Lobe tables restored ($n_lobe_tables)")
    end

    # ── 4.6 NODES ─────────────────────────────────────────────────────────
    # GRUG: Direct injection into NODE_MAP — bypasses create_node() to preserve
    # original IDs, strengths, neighbors, graves, everything. This is a RESTORE,
    # not a grow. Every field is exactly what it was when /saveSpecimen froze it.
    n_nodes = 0
    if haskey(specimen, "nodes") && isa(specimen["nodes"], AbstractVector)
        lock(NODE_LOCK) do
            for nd in specimen["nodes"]
                try
                    # Rebuild RelationalTriple vector from serialized dicts
                    rel_patterns = RelationalTriple[]
                    if haskey(nd, "relational_patterns") && isa(nd["relational_patterns"], AbstractVector)
                        for rp in nd["relational_patterns"]
                            push!(rel_patterns, RelationalTriple(
                                String(get(rp, "subject", "")),
                                String(get(rp, "relation", "")),
                                String(get(rp, "object", ""))
                            ))
                        end
                    end

                    node = Node(
                        String(nd["id"]),
                        String(nd["pattern"]),
                        Float64.(get(nd, "signal", Float64[])),
                        String(nd["action_packet"]),
                        Dict{String, Any}(string(k) => v for (k,v) in get(nd, "json_data", Dict())),
                        String.(get(nd, "drop_table", String[])),
                        Float64(get(nd, "throttle", 0.5)),
                        rel_patterns,
                        String.(get(nd, "required_relations", String[])),
                        Dict{String, Float64}(string(k) => Float64(v) for (k,v) in get(nd, "relation_weights", Dict())),
                        Float64(get(nd, "strength", 1.0)),
                        Bool(get(nd, "is_image_node", false)),
                        String.(get(nd, "neighbor_ids", String[])),
                        Bool(get(nd, "is_unlinkable", false)),
                        Bool(get(nd, "is_grave", false)),
                        String(get(nd, "grave_reason", "")),
                        Float64.(get(nd, "response_times", Float64[])),
                        Float64(get(nd, "ledger_last_cleared", time())),
                        parse(UInt64, string(get(nd, "hopfield_key", "0")))
                    )
                    NODE_MAP[node.id] = node
                    n_nodes += 1
                catch e
                    error("!!! FATAL: /loadSpecimen failed to restore node '$(get(nd, "id", "?"))': $e !!!")
                end
            end
        end
        counts["nodes"] = n_nodes
        println("  🌱 Nodes restored ($n_nodes)")
    end

    # ── 4.7 NODE_TO_LOBE_IDX ─────────────────────────────────────────────
    if haskey(specimen, "node_to_lobe_idx") && isa(specimen["node_to_lobe_idx"], Dict)
        lock(Lobe.LOBE_LOCK) do
            for (nid, lid) in specimen["node_to_lobe_idx"]
                Lobe.NODE_TO_LOBE_IDX[String(nid)] = String(lid)
            end
        end
    end

    # ── 4.8 HOPFIELD CACHE ────────────────────────────────────────────────
    n_hopfield = 0
    if haskey(specimen, "hopfield_cache") && isa(specimen["hopfield_cache"], AbstractVector)
        lock(HOPFIELD_CACHE_LOCK) do
            for hentry in specimen["hopfield_cache"]
                try
                    h = parse(UInt64, String(hentry["hash"]))
                    ids = String.(hentry["node_ids"])
                    hit = Int(get(hentry, "hit_count", 0))
                    HOPFIELD_CACHE[h] = ids
                    HOPFIELD_HIT_COUNTS[h] = hit
                    n_hopfield += 1
                catch e
                    @warn "loadSpecimen: skipping bad Hopfield entry: $e"
                end
            end
        end
        counts["hopfield_entries"] = n_hopfield
        println("  ⚡ Hopfield cache restored ($n_hopfield entries)")
    end

    # ── 4.9 RULES ─────────────────────────────────────────────────────────
    n_rules = 0
    if haskey(specimen, "rules") && isa(specimen["rules"], AbstractVector)
        for rentry in specimen["rules"]
            try
                rtext = String(rentry["text"])
                rprob = Float64(get(rentry, "prob", 1.0))
                push!(AIML_DROP_TABLE, StochasticRule(rtext, rprob))
                n_rules += 1
            catch e
                error("!!! FATAL: /loadSpecimen failed to restore rule: $e !!!")
            end
        end
        counts["rules"] = n_rules
        println("  ⚙️  Rules restored ($n_rules)")
    end

    # ── 4.10 INHIBITIONS ──────────────────────────────────────────────────
    n_inhibitions = 0
    if haskey(specimen, "inhibitions") && isa(specimen["inhibitions"], AbstractVector)
        lock(InputQueue._NEG_LOCK) do
            for ientry in specimen["inhibitions"]
                try
                    entry = InputQueue.NegEntry(
                        String(ientry["word"]),
                        String(get(ientry, "reason", "")),
                        Float64(get(ientry, "added_at", time()))
                    )
                    InputQueue._NEG_THESAURUS[entry.word] = entry
                    n_inhibitions += 1
                catch e
                    @warn "loadSpecimen: skipping bad inhibition entry: $e"
                end
            end
        end
        counts["inhibitions"] = n_inhibitions
        println("  🚫 Inhibitions restored ($n_inhibitions)")
    end

    # ── 4.11 MESSAGE HISTORY ──────────────────────────────────────────────
    n_messages = 0
    if haskey(specimen, "message_history") && isa(specimen["message_history"], AbstractVector)
        for mentry in specimen["message_history"]
            try
                msg = ChatMessage(
                    Int(mentry["id"]),
                    String(mentry["role"]),
                    String(mentry["text"]),
                    Bool(get(mentry, "pinned", false))
                )
                push!(MESSAGE_HISTORY, msg)
                n_messages += 1
            catch e
                @warn "loadSpecimen: skipping bad message entry: $e"
            end
        end
        counts["messages"] = n_messages
        n_pinned = count(m -> m.pinned, MESSAGE_HISTORY)
        println("  💬 Messages restored ($n_messages total, $n_pinned pinned)")
    end

    # ── 4.12 AROUSAL ──────────────────────────────────────────────────────
    if haskey(specimen, "arousal") && isa(specimen["arousal"], Dict)
        ar = specimen["arousal"]
        lock(EyeSystem.AROUSAL_LOCK) do
            EyeSystem.AROUSAL_STATE.level      = Float64(get(ar, "level", 0.3))
            EyeSystem.AROUSAL_STATE.decay_rate  = Float64(get(ar, "decay_rate", 0.05))
            EyeSystem.AROUSAL_STATE.baseline    = Float64(get(ar, "baseline", 0.3))
        end
        counts["arousal"] = 1
        println("  👁  Arousal restored (level=$(get(ar, "level", 0.3)))")
    end

    # ── 4.13 BRAINSTEM ────────────────────────────────────────────────────
    if haskey(specimen, "brainstem") && isa(specimen["brainstem"], Dict)
        bs = specimen["brainstem"]
        lock(BrainStem.BRAINSTEM_LOCK) do
            BrainStem.BRAINSTEM_STATE.dispatch_count = Int(get(bs, "dispatch_count", 0))
            BrainStem.BRAINSTEM_STATE.last_winner_id = String(get(bs, "last_winner_id", ""))
            BrainStem.BRAINSTEM_STATE.last_dispatch_t = Float64(get(bs, "last_dispatch_t", 0.0))
            if haskey(bs, "propagation_history") && isa(bs["propagation_history"], AbstractVector)
                for pr in bs["propagation_history"]
                    push!(BrainStem.BRAINSTEM_STATE.propagation_history,
                        BrainStem.PropagationRecord(
                            String(get(pr, "source_lobe_id", "")),
                            String(get(pr, "target_lobe_id", "")),
                            Float64(get(pr, "confidence", 0.0)),
                            Int(get(pr, "dispatch_count", 0))
                        )
                    )
                end
            end
        end
        println("  🧬 BrainStem state restored")
    end


    # ── 4.14 ATTACHMENTS (RELATIONAL FIRE SYSTEM) ────────────────────────────
    n_attachments = 0
    if haskey(specimen, "attachments") && isa(specimen["attachments"], AbstractVector)
        lock(ATTACHMENT_LOCK) do
            for aentry in specimen["attachments"]
                try
                    tid  = String(aentry["target_id"])
                    nid  = String(aentry["node_id"])
                    pat  = String(aentry["pattern"])
                    sig  = Float64.(get(aentry, "signal", Float64[]))
                    # GRUG: Re-bake signal if missing from file (backward compat)
                    if isempty(sig)
                        sig = words_to_signal(pat)
                    end
                    # GRUG: Re-bake base_confidence if missing from old specimen (backward compat).
                    # Old specimens didn't store JIT-baked confidence, so we re-compute it.
                    # If the attached node still exists, use its pattern for similarity.
                    # Otherwise, use a sensible default of 0.3 (some voice, not dominant).
                    base_conf = Float64(get(aentry, "base_confidence", -1.0))
                    if base_conf < 0.0
                        # GRUG: Backward compat re-bake — compute JIT confidence now
                        attach_ref = get(NODE_MAP, nid, nothing)
                        if !isnothing(attach_ref) && !isempty(pat) && !startswith(pat, "SDF:")
                            base_conf = _token_overlap_similarity(pat, attach_ref.pattern) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                        elseif !isnothing(attach_ref) && startswith(pat, "SDF:")
                            # GRUG: Image attachment — use SDF signal similarity if possible
                            if !isempty(sig) && !isempty(attach_ref.signal)
                                base_conf = _sdf_signal_similarity(sig, attach_ref.signal) + (attach_ref.strength / STRENGTH_CAP) * 0.5
                            else
                                base_conf = 0.3
                            end
                        else
                            base_conf = 0.3
                        end
                    end
                    att = AttachedNode(nid, pat, sig, base_conf)
                    existing = get(ATTACHMENT_MAP, tid, AttachedNode[])
                    push!(existing, att)
                    ATTACHMENT_MAP[tid] = existing
                    n_attachments += 1
                catch e
                    @warn "loadSpecimen: skipping bad attachment entry: $e"
                end
            end
        end
        counts["attachments"] = n_attachments
        println("  🔗 Attachments restored ($n_attachments)")
    end


    # ── 4.15 TRAJECTORY STATE (ActionTonePredictor) ───────────────
    # GRUG: Restore the trajectory ring buffer and config from specimen.
    # Academic: Backward-compatible — if key is missing (v2.0 specimen),
    # trajectory stays at defaults. No error, no silent corruption.
    n_trajectory = 0
    if haskey(specimen, "trajectory") && isa(specimen["trajectory"], Dict)
        traj = specimen["trajectory"]
        lock(ActionTonePredictor._trajectory_lock) do
            # Restore config if present
            if haskey(traj, "config") && isa(traj["config"], Dict)
                tc = traj["config"]
                try
                    ActionTonePredictor._trajectory_config[] = ActionTonePredictor.TrajectoryConfig(
                        Int(get(tc, "buffer_size", 16)),
                        Float64(get(tc, "decay_halflife", 120.0)),
                        Float64(get(tc, "gini_threshold", 0.72)),
                        Float64(get(tc, "damping_strength", 0.25)),
                        Float64(get(tc, "softmax_temperature", 1.5))
                    )
                catch e
                    @warn "loadSpecimen: bad trajectory config, using defaults: $e"
                    ActionTonePredictor._trajectory_config[] = ActionTonePredictor.DEFAULT_TRAJECTORY_CONFIG
                end
            end
            # Restore buffer entries
            if haskey(traj, "buffer") && isa(traj["buffer"], AbstractVector)
                for bentry in traj["buffer"]
                    try
                        # GRUG: Enum keys are stored as strings — parse them back.
                        # Academic: ActionFamily/ToneFamily are @enum types. We
                        # build safe lookup tables from instances() — no eval(), no injection risk.
                        action_d = Dict{ActionTonePredictor.ActionFamily, Float64}()
                        action_lookup = Dict(string(f) => f for f in instances(ActionTonePredictor.ActionFamily))
                        for (k, v) in bentry["action_dist"]
                            sk = String(k)
                            if !haskey(action_lookup, sk)
                                error("Unknown ActionFamily value: '$sk'")
                            end
                            action_d[action_lookup[sk]] = Float64(v)
                        end
                        tone_d = Dict{ActionTonePredictor.ToneFamily, Float64}()
                        tone_lookup = Dict(string(f) => f for f in instances(ActionTonePredictor.ToneFamily))
                        for (k, v) in bentry["tone_dist"]
                            sk = String(k)
                            if !haskey(tone_lookup, sk)
                                error("Unknown ToneFamily value: '$sk'")
                            end
                            tone_d[tone_lookup[sk]] = Float64(v)
                        end
                        push!(ActionTonePredictor._trajectory_buffer,
                            ActionTonePredictor.TrajectoryEntry(action_d, tone_d, Float64(bentry["timestamp"]))
                        )
                        n_trajectory += 1
                    catch e
                        @warn "loadSpecimen: skipping bad trajectory entry: $e"
                    end
                end
            end
        end
        counts["trajectory_entries"] = n_trajectory
        println("  🔮 Trajectory restored ($n_trajectory entries)")
    end

    # ── 4.16 TEMPORAL COHERENCE LEDGER (ImageSDF) ─────────────────
    # GRUG: Restore SDF timing patterns from specimen.
    # Academic: Backward-compatible — missing key means no temporal coherence
    # history, which is the same as a fresh specimen. No error.
    n_tcl = 0
    if haskey(specimen, "temporal_coherence") && isa(specimen["temporal_coherence"], AbstractVector)
        lock(ImageSDF.TCL_LOCK) do
            for tentry in specimen["temporal_coherence"]
                try
                    sdf_id = String(tentry["sdf_id"])
                    if strip(sdf_id) == ""
                        error("empty sdf_id in temporal coherence entry")
                    end
                    rec = ImageSDF.TemporalCoherenceRecord(
                        sdf_id,
                        Float64(get(tentry, "last_fired", 0.0)),
                        Int(get(tentry, "fire_count", 0)),
                        Float64(get(tentry, "avg_interval", 0.0)),
                        Float64(get(tentry, "coherence_score", 0.0))
                    )
                    ImageSDF.TEMPORAL_COHERENCE_LEDGER[sdf_id] = rec
                    n_tcl += 1
                catch e
                    @warn "loadSpecimen: skipping bad temporal coherence entry: $e"
                end
            end
        end
        counts["temporal_coherence"] = n_tcl
        println("  🕐 Temporal coherence restored ($n_tcl entries)")
    end

    # ── 4.17 MORPH COOLDOWN MAP (ChatterMode) ────────────────────
    # GRUG: Restore the 24h morph cooldown timestamps from specimen.
    # Academic: Backward-compatible — missing key means no active cooldowns,
    # which is correct for v2.0 specimens that never tracked this.
    n_cooldowns = 0
    if haskey(specimen, "morph_cooldowns") && isa(specimen["morph_cooldowns"], Dict)
        lock(ChatterMode.MORPH_COOLDOWN_LOCK) do
            for (node_id, ts) in specimen["morph_cooldowns"]
                try
                    nid = String(node_id)
                    timestamp = Float64(ts)
                    # GRUG: Only restore cooldowns that are still within the 24h window.
                    # Academic: Stale cooldowns (older than MORPH_COOLDOWN_SECONDS) are
                    # silently discarded — they would expire immediately anyway.
                    if (time() - timestamp) < ChatterMode.MORPH_COOLDOWN_SECONDS
                        ChatterMode.MORPH_COOLDOWN_MAP[nid] = timestamp
                        n_cooldowns += 1
                    end
                catch e
                    @warn "loadSpecimen: skipping bad morph cooldown entry: $e"
                end
            end
        end
        counts["morph_cooldowns"] = n_cooldowns
        println("  ⏳ Morph cooldowns restored ($n_cooldowns active)")
    end

    # —— 4.18 IMMUNE SYSTEM STATE ——————————————————————————————
    if haskey(specimen, "immune_system") && isa(specimen["immune_system"], Dict)
        ImmuneSystem.deserialize_immune_state!(specimen["immune_system"])
        n_immune_sigs = lock(ImmuneSystem.IMMUNE_HOPFIELD_LOCK) do
            length(ImmuneSystem.IMMUNE_HOPFIELD)
        end
        n_immune_log = lock(ImmuneSystem.LEDGER_LOCK) do
            length(ImmuneSystem.IMMUNE_LEDGER)
        end
        counts["immune_signatures"] = n_immune_sigs
        counts["immune_ledger"] = n_immune_log
        println("  🛡 Immune system restored ($n_immune_sigs signatures, $n_immune_log ledger entries)")
    end


    # ══════════════════════════════════════════════════════════════════════
    # PHASE 5: BUILD SUMMARY SCROLL
    # ══════════════════════════════════════════════════════════════════════

    elapsed = round(time() - t_start, digits=2)
    json_size = sizeof(json_str)
    n_pinned = count(m -> m.pinned, MESSAGE_HISTORY)

    lines = String[]
    push!(lines, "╔══════════════════════════════════════════════════════════════╗")
    push!(lines, "║            🧬 SPECIMEN LOADED SUCCESSFULLY                   ║")
    push!(lines, "╠══════════════════════════════════════════════════════════════╣")
    push!(lines, "  📁  File             : $filepath")
    push!(lines, "  📦  Compressed size  : $(file_size) bytes")
    push!(lines, "  📄  JSON size        : $(json_size) bytes")
    push!(lines, "  ⏱️   Time             : $(elapsed)s")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🌱  Nodes            : $(get(counts, "nodes", 0))")
    push!(lines, "  🧠  Lobes            : $(get(counts, "lobes", 0))")
    push!(lines, "  📋  Lobe tables      : $(get(counts, "lobe_tables", 0))")
    push!(lines, "  ⚡  Hopfield entries  : $(get(counts, "hopfield_entries", 0))")
    push!(lines, "  ⚙️   Rules            : $(get(counts, "rules", 0))")
    push!(lines, "  💬  Messages         : $(get(counts, "messages", 0)) ($n_pinned pinned)")
    push!(lines, "  🔧  Verb classes     : $(get(counts, "verb_classes", 0)) ($(get(counts, "verbs", 0)) verbs)")
    push!(lines, "  🔤  Thesaurus words  : $(get(counts, "thesaurus_words", 0))")
    push!(lines, "  🚫  Inhibitions      : $(get(counts, "inhibitions", 0))")
    push!(lines, "  🔗  Attachments      : $(get(counts, "attachments", 0))")
    push!(lines, "  👁   Arousal          : $(EyeSystem.get_arousal())")
    push!(lines, "  🔢  ID counters      : node=$(ID_COUNTER[]), msg=$(MSG_ID_COUNTER[])")
    push!(lines, "  ─────────────────────────────────────────────")
    push!(lines, "  🧹  Previous state   : WIPED (full brain transplant)")
    push!(lines, "╚══════════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end
# ==============================================================================
# CAVE POPULATION & CLI LOOP
# ==============================================================================

try
    println("Growing initial map seeds with Stochastic Emotion Packets & Relational Gating...")
    greet_ctx    = Dict{String, Any}("system_prompt" => "Highly polite greeting protocols active.")
    reason_ctx   = Dict{String, Any}("system_prompt" => "Cold logical analysis engine active.")
    
    # GRUG: Relation dictionary to guard the gate!
    relational_ctx = Dict{String, Any}(
        "system_prompt"      => "Causal relational analysis active.",
        "required_relations" => ["hits"], # GRUG: Gate requirement! Must hit!
        "relation_weights"   => Dict("hits" => 2.5) # GRUG: Amplify math if hits match!
    )

    # GRUG: Seed nodes use pipe-delimited action packets with inline negatives per action.
    # Format: "action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight"
    create_node("hello hi greeting mornin",
        "greet[dont frown, dont insult]^3 | welcome[dont be rude]^2 | smile^1",
        greet_ctx, String[])

    create_node("think ponder reason calculate",
        "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^1",
        reason_ctx, String[])

    # GRUG: Node that demands verb "hits". Will hard-reject "rock hits grug" via anti-match!
    create_node("grug hits rock and makes fire",
        "analyze[dont panic]^5 | ponder^2",
        relational_ctx, String[])
catch e
    println("!!! FATAL: Grug failed to plant initial seeds in cave !!!")
    Base.show_backtrace(stdout, catch_backtrace())
    exit(1)
end

# ==============================================================================
# IDLE BACKGROUND TRACKER (CHATTER + PHAGY)
# ==============================================================================

# GRUG: Track when last user input arrived so idle detector knows when to act.
const LAST_INPUT_TIME = Ref{Float64}(time())

# GRUG: Rules vector and lock for RULE PRUNER automaton.
# These are the live orchestration rules registered via /addRule.
# PhagyMode.prune_dormant_rules! expects: rules with fire_count, dormancy_strikes, is_dormant fields.
const PHAGY_RULES_REF  = Ref{Vector}(Vector())
const PHAGY_RULES_LOCK = ReentrantLock()

"""
maybe_run_idle()

GRUG: Check if cave is idle enough for an idle action (v7.1 — SLOW TIMER).
Uses ChatterMode.should_trigger_idle() which checks the SHARED 120s ±30s timer.
Both chatter and phagy use this SAME timer. One idle event, one action.

POPULATION GATE: Both chatter AND phagy require >= 1000 alive non-image nodes.
New specimens with < 1000 nodes skip ALL idle actions. They need to grow first.

If yes, do a 50/50 COINFLIP:
  - Heads (CHATTER): snapshot NODE_MAP, run gossip session, apply diffs back.
  - Tails (PHAGY):   run one phagy automaton for map maintenance.
"""
function maybe_run_idle()
    # GRUG: Don't start if chatter is already running (single-threaded loop guard)
    status = ChatterMode.get_chatter_status()
    status.is_running && return

    # GRUG: Check idle threshold (v7.1: 120s ±30s, shared timer for both chatter + phagy)
    !ChatterMode.should_trigger_idle(LAST_INPUT_TIME[]) && return

    # GRUG: Count alive non-image nodes for population gate (v7.1).
    # Both chatter AND phagy require >= 1000 nodes. New specimens skip all idle actions.
    alive_count = lock(NODE_LOCK) do
        count(n -> !n.is_grave && !n.is_image_node, values(NODE_MAP))
    end

    if alive_count < ChatterMode.MIN_POPULATION_FOR_CHATTER
        # GRUG: Population too small. No idle actions for young specimens.
        LAST_INPUT_TIME[] = time()
        return
    end

    # GRUG: THE COINFLIP. 50/50 - Chatter or Phagy. No favorites.
    if rand() < 0.5
        # ── HEADS: CHATTER ────────────────────────────────────────────────────

        # GRUG: Snapshot the NODE_MAP for the chatter clones
        snapshot = Tuple{String, String, String, Float64}[]
        lock(NODE_LOCK) do
            for (id, node) in NODE_MAP
                # GRUG: Only snapshot alive, non-image nodes for chatter
                # (Image nodes don't gossip pattern text - their patterns are SDF data)
                !node.is_grave && !node.is_image_node && push!(snapshot, (id, node.pattern, node.action_packet, node.strength))
            end
        end

        if isempty(snapshot)
            println("[IDLE:CHATTER] ⚠  No eligible nodes for chatter (all grave or image). Skipping.")
            LAST_INPUT_TIME[] = time()
            return
        end

        println("[IDLE] 🪙  Coinflip → CHATTER. Starting gossip round ($(length(snapshot)) eligible nodes)...")

        try
            session = ChatterMode.start_chatter_session!(snapshot)
            ChatterMode.apply_chatter_diffs!(session, NODE_MAP, NODE_LOCK)
        catch e
            if e isa ChatterMode.ChatterError
                # GRUG: ChatterErrors are expected (population gate, etc). Log and continue.
                println("[IDLE:CHATTER] ⛔  $(e.msg)")
            else
                println("[IDLE:CHATTER] !!! ERROR during chatter session: $e !!!")
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end

    else
        # ── TAILS: PHAGY ──────────────────────────────────────────────────────
        # GRUG: Phagy fires for mature specimens (1000+ nodes, gated above).
        println("[IDLE] 🪙  Coinflip → PHAGY. Running maintenance automaton...")

        # GRUG: Grab the live rules vector for RULE PRUNER
        rules_snapshot = lock(PHAGY_RULES_LOCK) do
            PHAGY_RULES_REF[]
        end

        try
            PhagyMode.run_phagy!(
                NODE_MAP,
                NODE_LOCK,
                HOPFIELD_CACHE,
                HOPFIELD_CACHE_LOCK,
                rules_snapshot,
                PHAGY_RULES_LOCK;
                message_history = MESSAGE_HISTORY,
                history_lock    = MESSAGE_HISTORY_LOCK
            )
        catch e
            println("[IDLE:PHAGY] !!! ERROR during phagy cycle: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    # GRUG: Reset idle timer after EITHER action so the next event waits a full interval.
    # Without this reset, chatter or phagy would re-trigger immediately next loop tick.
    LAST_INPUT_TIME[] = time()
end

# ==============================================================================
# MAIN CLI LOOP
# ==============================================================================

"""
run_cli()

GRUG: Main REPL loop. Prints boot message, then loops forever reading input.
Dispatches commands (/ prefix) or runs mission scan. Triggers idle chatter/phagy
between inputs via maybe_run_idle(). This is the top-level entry point.
"""
function run_cli()
    print(BOOT_MSG)
    
    while true
        print("\nBrain > ")

        # GRUG: Quick idle check BEFORE reading input.
        # Non-blocking: if no input ready, maybe trigger chatter OR phagy (50/50 coinflip).
        # In standard Julia CLI, readline() blocks. So idle action runs between prompts.
        maybe_run_idle()

        line = strip(readline())
        
        line == "" && continue

        # GRUG: Update last input time so idle detector resets
        LAST_INPUT_TIME[] = time()

        # GRUG: If chatter is currently running (async future), queue the input.
        # In this single-threaded implementation, chatter runs synchronously between
        # prompts so this is a safeguard for future async upgrades.
        status = ChatterMode.get_chatter_status()
        if status.is_running
            ChatterMode.enqueue_input!(line)
            println("[MAIN] ⏳  Input queued (chatter active). Will process after chatter ends.")
            continue
        end

        # GRUG: Drain any queued inputs from previous chatter round before processing new one
        ChatterMode.process_chatter_queue!(process_mission)
        
        try
            # GRUG: Parse all known commands via regex
            m_mission     = match(r"^/mission\s+(.+)"s,  line)
            m_wrong       = match(r"^/wrong\s*$",         line)
            m_explicit    = match(r"^/explicit\s+([a-zA-Z0-9_]+)\s+\[(.+?)\]\s+(.+)", line)
            m_grow        = match(r"^/grow\s+(.+)"s,      line)
            m_rule        = match(r"^/addRule\s+(.+)"s,   line)
            m_pin         = match(r"^/pin\s+(.+)"s,       line)
            m_nodes       = match(r"^/nodes\s*$",          line)
            m_status      = match(r"^/status\s*$",         line)
            m_arousal     = match(r"^/arousal\s+([0-9.]+)\s*$", line)
            # GRUG: Semantic verb/synonym system commands
            m_addverb     = match(r"^/addVerb\s+(\S+)\s+(\S+)\s*$",        line)
            m_addrelclass = match(r"^/addRelationClass\s+(\S+)\s*$",        line)
            m_addsynonym  = match(r"^/addSynonym\s+(\S+)\s+(\S+)\s*$",     line)
            m_listverbs   = match(r"^/listVerbs\s*$",                        line)
            # GRUG: Lobe management commands
            m_newlobe     = match(r"^/newLobe\s+(\S+)\s+(.+)$",               line)
            m_connectlobes= match(r"^/connectLobes\s+(\S+)\s+(\S+)\s*$",    line)
            m_lobegrow    = match(r"^/lobeGrow\s+(\S+)\s+(.+)$"s,             line)
            m_lobes        = match(r"^/lobes\s*$",                                      line)
            m_tablestatus  = match(r"^/tableStatus\s+(\S+)\s*$",                        line)
            m_tablematch   = match(r"^/tableMatch\s+(\S+)\s+(\S+)\s+(.+)$",            line)
            # GRUG: Thesaurus dimensional similarity command
            m_thesaurus    = match(r"^/thesaurus\s+(.+)\|(.+)$",                       line)
            # GRUG: NegativeThesaurus inhibition commands
            m_neginhibit   = match(r"^/negativeThesaurus\s+add\s+(.+?)(?:\s+--reason\s+(.+))?$", line)
            m_negremove    = match(r"^/negativeThesaurus\s+remove\s+(\S+)\s*$",         line)
            m_neglist      = match(r"^/negativeThesaurus\s+list\s*$",                   line)
            m_negcheck     = match(r"^/negativeThesaurus\s+check\s+(.+)$",              line)
            m_negflush     = match(r"^/negativeThesaurus\s+flush\s*$",                  line)
            # GRUG: Help command — show all commands
            m_loadspecimen = match(r"^/loadSpecimen\s+(\S+)\s*$",                          line)
            m_savespecimen = match(r"^/saveSpecimen\s+(\S+)\s*$",                          line)
            # GRUG: Relational fire system commands (node attachment)
            m_nodeattach   = match(r"^/nodeAttach\s+(.+)"s,                              line)
            m_nodedetach   = match(r"^/nodeDetach\s+(\S+)\s+(\S+)\s*$",                  line)
            m_imgnodeattach = match(r"^/imgnodeAttach\s+(.+)"s,                          line)
            m_imgnodedetach = match(r"^/imgnodeDetach\s+(\S+)\s+(\S+)\s*$",              line)
            m_attachments  = match(r"^/attachments\s*$",                                 line)
            m_help         = match(r"^/help\s*$",                                       line)
            
            if !isnothing(m_help)
                # GRUG: /help - show all available CLI commands. Cave painting instruction scroll!
                print(HELP_MSG)

            elseif !isnothing(m_mission)
                # GRUG: /mission - main input command. Handles text AND image binary.
                mission_text = String(m_mission.captures[1])
                process_mission(mission_text)

            elseif !isnothing(m_wrong)
                # GRUG: /wrong - user says last response was wrong.
                # Every node that voted gets a coinflip strength penalty.
                # Nodes that hit 0 become grave (negative reinforcement markers).
                voter_ids = lock(LAST_VOTER_LOCK) do
                    copy(LAST_VOTER_IDS)
                end

                if isempty(voter_ids)
                    println("⚠  /wrong: No previous voters to penalize. Did you run /mission first?")
                else
                    apply_wrong_feedback!(voter_ids)
                    println("❌  /wrong applied. $(length(voter_ids)) voter(s) penalized via coinflip.")
                end

            elseif !isnothing(m_explicit)
                cmd, id, mission_text = m_explicit.captures
                add_message_to_history!("User", mission_text, false)
                
                println("--> Grug forcing command override for [$id]...")
                override_vote = cast_explicit_vote(String(cmd), String(id))
                
                output = ephemeral_aiml_orchestrator(String(mission_text), [override_vote])
                println("\n🤖 AIML [Targeted Override]:\n$output")
                add_message_to_history!("System", output, false)
                
            elseif !isnothing(m_grow)
                # GRUG: /grow - plant new nodes from JSON packet.
                # Regex pre-screens JSON for image binary patterns before parsing.
                json_text = String(m_grow.captures[1])
                add_message_to_history!("System", "/grow [JSON MAP PACKET]", false)

                # GRUG: IMMUNE SYSTEM GATE — scan grow input before touching anything!
                # /grow is a CRITICAL command (modifies node population). Full immune scan.
                node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
                immune_passed = true
                try
                    status, _sig = ImmuneSystem.immune_scan!(json_text, node_count; is_critical=true)
                    if status == :deleted
                        immune_passed = false
                    end
                    if status != :immature
                        println("[IMMUNE] 🛡  /grow scan: $status (sig=0x$(string(_sig, base=16)))")
                    end
                catch e
                    if e isa ImmuneSystem.ImmuneError
                        println("[IMMUNE] ⛔ /grow REJECTED by immune system: $(e.info)")
                        add_message_to_history!("System", "⛔ /grow input rejected by immune system: $(e.kind)", false)
                        immune_passed = false
                    else
                        # GRUG: Immune system itself broke. Log it but don't block growth.
                        # Non-fatal: immune failure should not kill the cave.
                        @warn "[IMMUNE] Immune scan threw unexpected error (non-fatal): $e"
                    end
                end

                if immune_passed
                    println("--> Grug unpacking JSON node seeds...")

                    # GRUG: Check if the grow packet contains image binary data.
                    # If pattern field has image binary, flag it as image node automatically.
                    is_img, img_sig = maybe_convert_image_input(json_text)
                    if is_img
                        println("[GROW] 🖼  Image binary detected in /grow packet. Image node path active.")
                        # GRUG: The JSON node grower in Engine.jl handles is_image_node flag.
                        # Image binary in pattern will be stored as SDF signal.
                        # Caller must set "is_image_node": true in the JSON for this to work.
                    end

                    new_ids = grow_nodes_from_packet(json_text)

                    success_msg = "🌱 Tribe expanded! Grug planted $(length(new_ids)) new nodes: [$(join(new_ids, ", "))]"
                    println(success_msg)
                    add_message_to_history!("System", success_msg, false)
                end

            elseif !isnothing(m_rule)
                # GRUG: /addRule - add a stochastic orchestration rule.
                # Optional [prob=X.XX] suffix sets fire probability (default 1.0).
                rule_text = String(m_rule.captures[1])
                println("⚙️ ", add_orchestration_rule!(rule_text))

            elseif !isnothing(m_pin)
                pin_text = String(m_pin.captures[1])
                add_message_to_history!("User_Pinned", pin_text, true)
                println("📌 Grug pinned text to Memory Wall!")

            elseif !isnothing(m_nodes)
                # GRUG: /nodes - show full node map status (strength, neighbors, graves, etc.)
                println(get_node_status_summary())
                # GRUG: Also show attachment map if any attachments exist
                att_summary = get_attachment_summary()
                if !contains(att_summary, "EMPTY")
                    println("\n$att_summary")
                end

            elseif !isnothing(m_status)
                # GRUG: /status - comprehensive system health snapshot.
                # Shows: engine, chatter, lobes, brainstem, thesaurus gate, memory estimate.
                cs  = ChatterMode.get_chatter_status()
                bs  = BrainStem.get_brainstem_status()
                lobe_ids_now = Lobe.get_lobe_ids()
                total_lobe_nodes = sum(Lobe.get_lobe_node_count(lid) for lid in lobe_ids_now; init=0)

                # GRUG: Rough memory estimate. Each node ~= 1KB (pattern + signal + metadata).
                # Hopfield cache ~= 200 bytes per entry. Message history ~= 500 bytes per msg.
                est_node_mem_kb    = length(NODE_MAP) * 1
                est_hopfield_mem_b = length(HOPFIELD_CACHE) * 200
                est_history_mem_b  = length(MESSAGE_HISTORY) * 500
                est_total_kb       = est_node_mem_kb + div(est_hopfield_mem_b + est_history_mem_b, 1024)

                # GRUG: Find top-firing lobe (most wins)
                top_lobe = isempty(lobe_ids_now) ? "none" : begin
                    best_lid = lobe_ids_now[1]
                    best_fc  = 0
                    for lid in lobe_ids_now
                        rec = Lobe.get_lobe(lid)
                        if rec.fire_count > best_fc
                            best_fc  = rec.fire_count
                            best_lid = lid
                        end
                    end
                    "$(best_lid) ($(best_fc) fires)"
                end

                println("╔══════════════════════════════════════════════════╗")
                println("║              GRUGBOT SYSTEM STATUS               ║")
                println("╠══════════════════════════════════════════════════╣")
                println("║  ENGINE                                          ║")
                println("  Nodes in cave   : $(length(NODE_MAP))")
                println("  Hopfield cache  : $(length(HOPFIELD_CACHE)) entries")
                println("  Memory messages : $(length(MESSAGE_HISTORY))")
                println("  Est. memory use : ~$(est_total_kb) KB")
                println("  Trajectory buf  : $(length(ActionTonePredictor._trajectory_buffer)) entries")
                println("  Temporal coher  : $(length(ImageSDF.TEMPORAL_COHERENCE_LEDGER)) entries")
                println("  Morph cooldowns : $(length(ChatterMode.MORPH_COOLDOWN_MAP)) active")
                println("  Current arousal : $(round(EyeSystem.get_arousal(), digits=3))")
                println("  Last input ago  : $(round(time() - LAST_INPUT_TIME[], digits=1))s")
                println("║  LOBES                                           ║")
                println("  Lobes registered: $(length(lobe_ids_now))")
                println("  Nodes in lobes  : $(total_lobe_nodes)")
                println("  Top lobe (fires): $(top_lobe)")
                println("║  BRAINSTEM                                       ║")
                println("  Dispatches run  : $(bs["dispatch_count"])")
                println("  Last winner     : $(isempty(bs["last_winner_id"]) ? "none" : bs["last_winner_id"])")
                println("  Propagations    : $(bs["propagation_events"])")
                println("  Is dispatching  : $(bs["is_dispatching"])")
                println("║  CHATTER                                         ║")
                println("  Chatter running : $(cs.is_running)")
                println("  Input queue     : $(cs.queue_depth) pending")
                println("  Sessions run    : $(cs.sessions_run)")
                println("╚══════════════════════════════════════════════════╝")

            elseif !isnothing(m_arousal)
                # GRUG: /arousal - manually set eye system arousal level [0.0, 1.0]
                arousal_val = tryparse(Float64, m_arousal.captures[1])
                if isnothing(arousal_val)
                    error("!!! FATAL: /arousal value is not a valid float! !!!")
                end
                EyeSystem.set_arousal!(arousal_val)
                println("👁  Arousal set to $(round(arousal_val, digits=3)). Eye system updated.")

            elseif !isnothing(m_addverb)
                # GRUG: /addVerb <verb> <class> - add a new verb to a relation class at runtime.
                # User must create the class first with /addRelationClass if it is new.
                # Example: /addVerb triggers causal
                verb_word  = String(m_addverb.captures[1])
                verb_class = String(m_addverb.captures[2])
                SemanticVerbs.add_verb!(verb_word, verb_class)
                println("🔧 Verb '$(verb_word)' added to class '$(verb_class)'. Active immediately.")

            elseif !isnothing(m_addrelclass)
                # GRUG: /addRelationClass <name> - create a new verb class bucket.
                # After this, user can /addVerb <word> <name> to populate it.
                # Example: /addRelationClass epistemic
                class_name = String(m_addrelclass.captures[1])
                SemanticVerbs.add_relation_class!(class_name)
                println("🗂  Relation class '$(class_name)' created. Use /addVerb to populate.")

            elseif !isnothing(m_addsynonym)
                # GRUG: /addSynonym <canonical> <alias> - register a synonym normalization.
                # From now on, <alias> in user input is treated as <canonical> before triple extraction.
                # Canonical verb must already exist in a relation class!
                # Example: /addSynonym causes triggers
                canonical_verb = String(m_addsynonym.captures[1])
                alias_verb     = String(m_addsynonym.captures[2])
                SemanticVerbs.add_synonym!(canonical_verb, alias_verb)
                println("📖 Synonym registered: '$(alias_verb)' → '$(canonical_verb)'. Normalization active.")

            elseif !isnothing(m_listverbs)
                # GRUG: /listVerbs - show all registered verb classes and their verbs + synonyms.
                classes   = SemanticVerbs.get_relation_classes()
                synonyms  = SemanticVerbs.get_synonym_map()
                println("=== SEMANTIC VERB REGISTRY ===")
                for cls in classes
                    verbs = SemanticVerbs.get_verbs_in_class(cls)
                    println("  [$(cls)]: $(join(sort(collect(verbs)), ", "))")
                end
                if !isempty(synonyms)
                    println("  --- Synonyms ---")
                    for (alias, canon) in sort(collect(synonyms))
                        println("    $(alias) → $(canon)")
                    end
                else
                    println("  (no synonyms registered)")
                end

            elseif !isnothing(m_newlobe)
                # GRUG: /newLobe <id> <subject> - create a new subject partition.
                # Example: /newLobe language "natural language processing"
                lobe_id_new  = String(m_newlobe.captures[1])
                lobe_subject = String(strip(m_newlobe.captures[2]))
                Lobe.create_lobe!(lobe_id_new, lobe_subject)
                println("\U0001f9e0 Lobe '$(lobe_id_new)' created for subject: '$(lobe_subject)'. Cap: $(Lobe.LOBE_NODE_CAP) nodes.")

            elseif !isnothing(m_connectlobes)
                # GRUG: /connectLobes <id_a> <id_b> - link two lobes bidirectionally.
                # BrainStem uses connections for lateral signal routing.
                # Example: /connectLobes language emotion
                lobe_a = String(m_connectlobes.captures[1])
                lobe_b = String(m_connectlobes.captures[2])
                Lobe.connect_lobes!(lobe_a, lobe_b)
                println("\U0001f517 Lobes '$(lobe_a)' \u2194 '$(lobe_b)' connected.")

            elseif !isnothing(m_lobegrow)
                # GRUG: /lobeGrow <lobe_id> <json_packet> - grow a node directly into a lobe.
                # JSON must have: pattern, action_packet. Optional: data, drop_table.
                # Example: /lobeGrow language {"pattern":"hello","action_packet":"{...}"}
                target_lobe_id = String(m_lobegrow.captures[1])
                lobe_json      = String(strip(m_lobegrow.captures[2]))

                # GRUG: IMMUNE SYSTEM GATE — scan lobeGrow input before touching anything!
                lobegrow_immune_passed = true
                node_count_lg = lock(() -> length(NODE_MAP), NODE_LOCK)
                try
                    lg_status, lg_sig = ImmuneSystem.immune_scan!(lobe_json, node_count_lg; is_critical=true)
                    if lg_status == :deleted
                        lobegrow_immune_passed = false
                    end
                    if lg_status != :immature
                        println("[IMMUNE] \U0001f6e1  /lobeGrow scan: $lg_status (sig=0x$(string(lg_sig, base=16)))")
                    end
                catch e
                    if e isa ImmuneSystem.ImmuneError
                        println("[IMMUNE] \u26d4 /lobeGrow REJECTED by immune system: $(e.info)")
                        add_message_to_history!("System", "\u26d4 /lobeGrow input rejected by immune system: $(e.kind)", false)
                        lobegrow_immune_passed = false
                    else
                        @warn "[IMMUNE] Immune scan threw unexpected error for /lobeGrow (non-fatal): $e"
                    end
                end

                if !lobegrow_immune_passed
                    # GRUG: Immune system said no. Skip growth.
                elseif !haskey(Lobe.LOBE_REGISTRY, target_lobe_id)
                    println("\u26a0  /lobeGrow: Lobe '$(target_lobe_id)' does not exist. Use /newLobe first.")
                elseif Lobe.lobe_is_full(target_lobe_id)
                    println("!!! LOBE FULL: Lobe '$(target_lobe_id)' has reached its node cap. Cannot grow more nodes! Use /newLobe to add a new lobe. !!!")
                else
                    try
                        packet = JSON.parse(lobe_json)
                        if !haskey(packet, "pattern") || !haskey(packet, "action_packet")
                            println("\u26a0  /lobeGrow: JSON must have 'pattern' and 'action_packet' fields.")
                        else
                            json_data  = Dict{String,Any}(string(k) => v for (k,v) in get(packet, "data", Dict()))
                            drop_table = haskey(packet, "drop_table") && packet["drop_table"] isa AbstractVector ?
                                         String[string(x) for x in packet["drop_table"]] : String[]
                            new_id = create_node(
                                packet["pattern"],
                                packet["action_packet"],
                                json_data,
                                drop_table
                            )
                            Lobe.add_node_to_lobe!(target_lobe_id, new_id)
                            # GRUG: Convert JSON data and drop table into lobe's hash table chunks.
                            # Flat dict and flat vector become O(1) pattern-activated storage.
                            json_count = LobeTable.json_to_table_chunk!(target_lobe_id, new_id, json_data)
                            drop_count = LobeTable.drop_table_to_chunk!(target_lobe_id, new_id, drop_table)
                            println("\U0001f331 Node '$(new_id)' grown into lobe '$(target_lobe_id)'. json_fields=$json_count drop_links=$drop_count")
                        end
                    catch e
                        ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" :
                              e isa Lobe.LobeError ? " [ctx: $(e.context)]" : ""
                        println("!!! ERROR in /lobeGrow: $e$ctx !!!")
                    end
                end

            elseif !isnothing(m_lobes)
                # GRUG: /lobes - uses get_lobe_status_summary() which includes O(1) reverse index count.
                println(Lobe.get_lobe_status_summary())

            elseif !isnothing(m_tablestatus)
                # GRUG: /tableStatus <lobe_id> - show hash table chunk sizes for a lobe.
                # Shows nodes/json/drop/hopfield/meta chunk entry counts.
                ts_lobe_id = String(m_tablestatus.captures[1])
                try
                    if !LobeTable.table_exists(ts_lobe_id)
                        println("\u26a0  /tableStatus: No table found for lobe '$(ts_lobe_id)'. Does the lobe exist?")
                    else
                        println(LobeTable.get_table_summary(ts_lobe_id))
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableStatus: $e$ctx !!!")
                end

            elseif !isnothing(m_tablematch)
                # GRUG: /tableMatch <lobe_id> <chunk> <pattern> - pattern-activate entries.
                # chunk must be one of: nodes, json, drop, hopfield, meta
                # pattern is matched as token mode (any token in pattern activates key)
                # Example: /tableMatch lang json node_0 -> all json fields for node_0
                # Example: /tableMatch lang drop node_0 -> all drop neighbors of node_0
                tm_lobe_id  = String(m_tablematch.captures[1])
                tm_chunk    = String(strip(m_tablematch.captures[2]))
                tm_pattern  = String(strip(m_tablematch.captures[3]))
                try
                    if !LobeTable.table_exists(tm_lobe_id)
                        println("\u26a0  /tableMatch: No table found for lobe '$(tm_lobe_id)'.")
                    else
                        # GRUG: Use prefix mode when pattern looks like a node_id, token otherwise
                        match_mode = startswith(tm_pattern, "node_") ? :prefix : :token
                        hits = LobeTable.table_match(tm_lobe_id, tm_chunk, tm_pattern, mode=match_mode)
                        if isempty(hits)
                            println("[tableMatch] No entries matched '$(tm_pattern)' in chunk '$(tm_chunk)' of lobe '$(tm_lobe_id)'.")
                        else
                            println("[tableMatch] $(length(hits)) hits in lobe='$(tm_lobe_id)' chunk='$(tm_chunk)' pattern='$(tm_pattern)':")
                            for (k, v) in sort(collect(hits), by=x->x[1])
                                println("  $(k) -> $(v)")
                            end
                        end
                    end
                catch e
                    ctx = e isa LobeTable.LobeTableError ? " [ctx: $(e.context)]" : ""
                    println("!!! ERROR in /tableMatch: $e$ctx !!!")
                end

            elseif !isnothing(m_thesaurus)
                # GRUG: /thesaurus <input1> | <input2> - dimensional similarity comparison.
                # Optional context lists after :: separators (comma-separated).
                # Examples:
                #   /thesaurus happy | joyful
                #   /thesaurus machine learning | artificial intelligence
                #   /thesaurus dog | canine :: pet,animal :: domesticated,beast
                raw1 = String(strip(m_thesaurus.captures[1]))
                raw2 = String(strip(m_thesaurus.captures[2]))
                # GRUG: Parse optional context lists after :: separator in raw2
                ctx1 = String[]
                ctx2 = String[]
                if occursin("::", raw2)
                    parts = split(raw2, "::")
                    raw2  = String(strip(parts[1]))
                    if length(parts) >= 2
                        ctx1 = filter(!isempty, map(c -> String(strip(c)), split(parts[2], ",")))
                    end
                    if length(parts) >= 3
                        ctx2 = filter(!isempty, map(c -> String(strip(c)), split(parts[3], ",")))
                    end
                end
                try
                    result = Thesaurus.thesaurus_compare(raw1, raw2; context1=ctx1, context2=ctx2)
                    intensity = Thesaurus.format_thesaurus_intensity(result.overall)
                    # GRUG: Show seed synonyms for single-word inputs so operator sees what gate knows
                    syns1 = !occursin(" ", raw1) ? Thesaurus.get_seed_synonyms(raw1) : String[]
                    syns2 = !occursin(" ", raw2) ? Thesaurus.get_seed_synonyms(raw2) : String[]
                    syn1_str = isempty(syns1) ? "" : "  → seeds: $(join(first(syns1, 4), ", "))"
                    syn2_str = isempty(syns2) ? "" : "  → seeds: $(join(first(syns2, 4), ", "))"
                    println("\n\U0001f50d THESAURUS COMPARISON")
                    println("  Input 1  : \"$(raw1)\"$(syn1_str)")
                    println("  Input 2  : \"$(raw2)\"$(syn2_str)")
                    println("  Type     : $(result.match_type)")
                    println("  \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500")
                    println("  Overall  : $(round(result.overall * 100, digits=1))%  [$(intensity)]")
                    println("  Semantic : $(round(result.semantic * 100, digits=1))%")
                    println("  Context  : $(round(result.contextual * 100, digits=1))%")
                    println("  Assoc    : $(round(result.associative * 100, digits=1))%")
                    println("  Confid.  : $(round(result.confidence * 100, digits=1))%")
                    if !isempty(ctx1)
                        println("  Ctx1     : $(join(ctx1, ", "))")
                    end
                    if !isempty(ctx2)
                        println("  Ctx2     : $(join(ctx2, ", "))")
                    end
                    println()
                catch e
                    # GRUG: Surface full error context from typed exceptions, not just message!
                    if e isa Thesaurus.ThesaurusError
                        println("!!! THESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! THESAURUS ERROR: $e !!!")
                    end
                end

            elseif !isnothing(m_neginhibit)
                # GRUG: /negativeThesaurus add <word> [--reason <text>]
                # Register a word/phrase as inhibited. Filtered from input before scanning.
                inhibit_word   = String(strip(m_neginhibit.captures[1]))
                inhibit_reason = isnothing(m_neginhibit.captures[2]) ? "" : String(strip(m_neginhibit.captures[2]))
                try
                    InputQueue.add_inhibition!(inhibit_word; reason=inhibit_reason)
                    println("🚫 Inhibition registered: '$(inhibit_word)'" * (isempty(inhibit_reason) ? "" : "  reason: $(inhibit_reason)"))
                    println("   NegativeThesaurus size: $(InputQueue.inhibition_count()) / $(InputQueue.NEG_THESAURUS_MAX)")
                catch e
                    if e isa InputQueue.InputQueueError
                        println("!!! NEGATIVETHESAURUS ERROR [$(e.context)]: $(e.message) !!!")
                    else
                        println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                    end
                end

            elseif !isnothing(m_negremove)
                # GRUG: /negativeThesaurus remove <word>
                # Remove a word from the inhibition list.
                remove_word = String(strip(m_negremove.captures[1]))
                try
                    removed = InputQueue.remove_inhibition!(remove_word)
                    if removed
                        println("✅ Inhibition removed: '$(remove_word)'. Word no longer blocked.")
                    else
                        println("⚠️  '$(remove_word)' was not in NegativeThesaurus. Nothing changed.")
                    end
                catch e
                    println("!!! NEGATIVETHESAURUS ERROR: $e !!!")
                end

            elseif !isnothing(m_neglist)
                # GRUG: /negativeThesaurus list
                # Show all currently inhibited words with reasons and timestamps.
                entries = InputQueue.list_inhibitions()
                if isempty(entries)
                    println("📋 NegativeThesaurus is empty. No words currently inhibited.")
                else
                    println("📋 NegativeThesaurus — $(length(entries)) inhibited word(s):")
                    for e in entries
                        age_s   = round(time() - e.added_at, digits=0)
                        reason  = isempty(e.reason) ? "(no reason)" : e.reason
                        println("   🚫 '$(e.word)'   reason: $(reason)   added: $(age_s)s ago")
                    end
                end

            elseif !isnothing(m_negcheck)
                # GRUG: /negativeThesaurus check <word>
                # Quick check if a word is inhibited or not.
                check_word = String(strip(m_negcheck.captures[1]))
                if InputQueue.is_inhibited(check_word)
                    println("🚫 '$(check_word)' IS inhibited in NegativeThesaurus.")
                else
                    println("✅ '$(check_word)' is NOT inhibited. Word passes filter freely.")
                end

            elseif !isnothing(m_negflush)
                # GRUG: /negativeThesaurus flush
                # Remove ALL inhibitions at once. Destructive but useful for resets.
                old_count = InputQueue.inhibition_count()
                lock(InputQueue._NEG_LOCK) do
                    empty!(InputQueue._NEG_THESAURUS)
                end
                println("🧹 NegativeThesaurus flushed. Removed $(old_count) inhibition(s). Cave filter is now empty.")

            elseif !isnothing(m_savespecimen)
                # GRUG: /saveSpecimen <filepath> — freeze the entire cave state to a
                # gzip-compressed JSON file. Every node, lobe, rule, message, verb,
                # thesaurus entry, inhibition, arousal level — EVERYTHING.
                spec_path = String(strip(m_savespecimen.captures[1]))
                add_message_to_history!("System", "/saveSpecimen $spec_path", false)

                println("--> Grug freezing entire cave to specimen file...")
                result_summary = save_specimen_to_file!(spec_path)
                println("\n$result_summary")
                add_message_to_history!("System", result_summary, false)

            elseif !isnothing(m_loadspecimen)
                # GRUG: /loadSpecimen <filepath> — thaw a previously saved specimen file
                # and RESTORE the entire cave state. This is a DESTRUCTIVE operation —
                # current state is WIPED and replaced. Full brain transplant.
                spec_path = String(strip(m_loadspecimen.captures[1]))
                add_message_to_history!("System", "/loadSpecimen $spec_path", false)

                println("--> Grug thawing specimen from file...")
                result_summary = load_specimen_from_file!(spec_path)
                println("\n$result_summary")
                add_message_to_history!("System", result_summary, false)

            elseif !isnothing(m_nodeattach)
                # GRUG: /nodeAttach <target_id> <attach_id1> <pattern1> [<attach_id2> <pattern2> ...]
                # Relational fire system: bolt nodes onto a target with user-defined patterns.
                # Parsing: target_id is first token. Remaining tokens alternate between
                # node_id and quoted/unquoted pattern. Each pair is one attachment.
                #
                # Supported formats:
                #   /nodeAttach target_0 node_1 "hello world" node_2 "fire pattern"
                #   /nodeAttach target_0 node_1 hello node_2 fire
                #
                # GRUG: Use a regex to extract pairs of (node_id, pattern) after target_id.
                raw_args = String(strip(m_nodeattach.captures[1]))
                
                # GRUG: Tokenize respecting quoted strings
                tokens = String[]
                remaining = raw_args
                while !isempty(remaining)
                    remaining = lstrip(remaining)
                    isempty(remaining) && break
                    if remaining[1] == '"'
                        # GRUG: Quoted token — find closing quote
                        close_idx = findnext('"', remaining, 2)
                        if isnothing(close_idx)
                            error("!!! FATAL: /nodeAttach found opening quote with no closing quote! Check your syntax! !!!")
                        end
                        push!(tokens, remaining[2:close_idx-1])
                        remaining = remaining[close_idx+1:end]
                    else
                        # GRUG: Unquoted token — split on whitespace
                        space_idx = findfirst(isspace, remaining)
                        if isnothing(space_idx)
                            push!(tokens, remaining)
                            remaining = ""
                        else
                            push!(tokens, remaining[1:space_idx-1])
                            remaining = remaining[space_idx+1:end]
                        end
                    end
                end

                if length(tokens) < 3
                    error("!!! FATAL: /nodeAttach needs at least: <target_id> <attach_id> <pattern>. Got $(length(tokens)) token(s)! !!!")
                end

                target_id = tokens[1]
                
                # GRUG: Remaining tokens are pairs: (node_id, pattern)
                pair_tokens = tokens[2:end]
                if length(pair_tokens) % 2 != 0
                    error("!!! FATAL: /nodeAttach attachment args must be pairs of <node_id> <pattern>. Got odd count ($(length(pair_tokens)))! !!!")
                end

                n_pairs = length(pair_tokens) ÷ 2
                if n_pairs > MAX_ATTACHMENTS
                    error("!!! FATAL: /nodeAttach trying to attach $n_pairs nodes at once, but max is $MAX_ATTACHMENTS! !!!")
                end

                results = String[]
                for i in 1:n_pairs
                    aid = pair_tokens[(i-1)*2 + 1]
                    pat = pair_tokens[(i-1)*2 + 2]
                    result = attach_node!(target_id, aid, pat)
                    push!(results, result)
                end

                println("🔗 /nodeAttach complete:")
                for r in results
                    println("   → $r")
                end
                add_message_to_history!("System", "/nodeAttach: $(join(results, " | "))", false)

            elseif !isnothing(m_nodedetach)
                # GRUG: /nodeDetach <target_id> <attach_id>
                # Remove a specific attached node from a target.
                target_id = String(strip(m_nodedetach.captures[1]))
                attach_id = String(strip(m_nodedetach.captures[2]))
                result = detach_node!(target_id, attach_id)
                println("🔓 $result")
                add_message_to_history!("System", "/nodeDetach: $result", false)

            elseif !isnothing(m_imgnodeattach)
                # GRUG: /imgnodeAttach <target_id> <attach_id> <image_data_b64> [<width> <height>]
                # Same as /nodeAttach but for image nodes. Image binary is converted to
                # nonlinear SDF at attach time (JIT GPU accel). Confidence is baked from
                # SDF signal similarity. The attach_id MUST be an image node.
                #
                # Supported formats:
                #   /imgnodeAttach target_0 img_node_1 "data:image/png;base64,iVBOR..." 64 64
                #   /imgnodeAttach target_0 img_node_1 "data:image/png;base64,iVBOR..."
                #   (if width/height omitted, defaults to 8x8 — user should specify)
                #
                # GRUG: Tokenize respecting quoted strings (same as /nodeAttach)
                raw_args = String(strip(m_imgnodeattach.captures[1]))
                tokens = String[]
                remaining = raw_args
                while !isempty(remaining)
                    remaining = lstrip(remaining)
                    isempty(remaining) && break
                    if remaining[1] == '"'
                        close_idx = findnext('"', remaining, 2)
                        if isnothing(close_idx)
                            error("!!! FATAL: /imgnodeAttach found opening quote with no closing quote! Check your syntax! !!!")
                        end
                        push!(tokens, remaining[2:close_idx-1])
                        remaining = remaining[close_idx+1:end]
                    else
                        space_idx = findfirst(isspace, remaining)
                        if isnothing(space_idx)
                            push!(tokens, remaining)
                            remaining = ""
                        else
                            push!(tokens, remaining[1:space_idx-1])
                            remaining = remaining[space_idx+1:end]
                        end
                    end
                end

                if length(tokens) < 3
                    error("!!! FATAL: /imgnodeAttach needs at least: <target_id> <attach_id> <image_data>. Got $(length(tokens)) token(s)! !!!")
                end

                target_id = tokens[1]
                attach_id = tokens[2]
                image_input = tokens[3]

                # GRUG: Parse optional width/height (default 8x8 if not provided)
                img_width = length(tokens) >= 4 ? parse(Int, tokens[4]) : 8
                img_height = length(tokens) >= 5 ? parse(Int, tokens[5]) : 8

                # GRUG: Detect and decode image binary from the input string
                found, fmt, extracted = ImageSDF.detect_image_binary(image_input)
                if !found
                    error("!!! FATAL: /imgnodeAttach could not detect image binary in input! Expected Base64 data URI or hex dump! !!!")
                end

                # GRUG: Convert extracted image data to raw bytes
                image_bytes = if fmt == :base64
                    ImageSDF.base64_to_bytes(extracted)
                else
                    # GRUG: For hex/raw formats, convert hex string to bytes
                    hex_clean = replace(extracted, r"[^A-Fa-f0-9]" => "")
                    [parse(UInt8, hex_clean[i:i+1], base=16) for i in 1:2:length(hex_clean)-1]
                end

                result = attach_image_node!(target_id, attach_id, image_bytes, img_width, img_height)
                println("🖼️🔗 /imgnodeAttach complete:")
                println("   → $result")
                add_message_to_history!("System", "/imgnodeAttach: $result", false)

            elseif !isnothing(m_imgnodedetach)
                # GRUG: /imgnodeDetach <target_id> <attach_id>
                # Same as /nodeDetach — reuse detach_node! since AttachedNode is universal.
                target_id = String(strip(m_imgnodedetach.captures[1]))
                attach_id = String(strip(m_imgnodedetach.captures[2]))
                result = detach_node!(target_id, attach_id)
                println("🖼️🔓 $result")
                add_message_to_history!("System", "/imgnodeDetach: $result", false)

            elseif !isnothing(m_attachments)
                # GRUG: /attachments — show all current node attachments
                summary = get_attachment_summary()
                println(summary)

            else
                error("!!! FATAL: Grug command bad format. Use /help to see all valid commands. !!!")
            end
            
        catch e
            println("!!! SYSTEM ERROR: $e !!!")
            Base.show_backtrace(stdout, catch_backtrace())
            println()
        end
    end
end

# GRUG: Only run the CLI when executing Main.jl directly as a script,
# not when loaded as part of the GrugBot420 package (e.g., by Documenter or Pkg.test).
if abspath(PROGRAM_FILE) == @__FILE__
    run_cli()
end

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: BEHAVIORAL LAYER (MAIN.JL - UPDATED)
#
# 1. COGNITIVE SUPERPOSITION (MULTI-VOTE ORCHESTRATION):
# The routing engine abandons "winner-takes-all" Softmax weighting in favor of a 
# deterministic/stochastic superposition model. The maximum confidence threshold 
# mathematically bounds the sure_votes array (guaranteed truths), while ALL 
# remaining valid votes are subjected to an iterative 50/50 @coinflip to simulate 
# stochastic side-feature consideration (unsure_votes).
#
# 2. STOCHASTIC AIML RULES:
# Each orchestration rule now carries a fire_probability [0.0, 1.0]. At generation
# time, rules roll against their probability before being injected into the JIT
# payload. This produces natural, non-robotic variation in orchestrator output.
# Rules with no [prob=X] suffix default to 1.0 (always fire, backward compatible).
#
# 3. /WRONG FEEDBACK LOOP:
# /wrong triggers apply_wrong_feedback!() on all node IDs from the last /mission.
# Each voter does a coinflip strength penalty. Nodes reaching strength=0 become
# GRAVE markers used as negative reinforcement anchors during future generative phases.
#
# 4. IMAGE BINARY ROUTING:
# /mission and /grow pre-screen input via ImageSDF.detect_image_binary() regex.
# Detected image binary is decoded, JIT-converted to SDFParams, processed through
# EyeSystem (edge blur + arousal-gated attention cutout), jittered, and converted
# to a flat signal vector for PatternScanner-compatible image node matching.
#
# 5. IDLE MODE: CHATTER + PHAGY COINFLIP (v7.1 — SLOW TIMER):
# Idle detection runs between CLI prompts via maybe_run_idle(). When the cave has
# been quiet for ~120s (±30s jitter), a 50/50 coinflip fires. BOTH chatter and
# phagy share this same slow timer. Both require >= 1000 alive non-image nodes;
# new specimens skip ALL idle actions. HEADS triggers a chatter session: 50-500 node clones gossip
# and exchange patterns. Only WEAK nodes morph — receivers must be weaker than
# senders. Each node can only morph once per 24 hours (MORPH_COOLDOWN_MAP).
# TAILS triggers a phagy cycle: one of six maintenance automata runs
# (ORPHAN_PRUNER, STRENGTH_DECAYER, GRAVE_RECYCLER, CACHE_VALIDATOR,
# DROP_TABLE_COMPACT, RULE_PRUNER). Phagy also requires 1000+ nodes (gated above coinflip).
# Only ONE automaton runs per phagy cycle to preserve Big-O safety. User input
# arriving during chatter is queued and drained after session completion. Phagy is
# synchronous and completes before the next prompt, so no queuing is needed.
#
# 6. DROP TABLE CO-ACTIVATION:
# scan_and_expand() replaces direct scan_specimens() calls for text missions.
# Primary scan results are expanded with drop-table neighbor nodes, modeling
# associative memory co-activation.
#
# 7. BIG-O RESPONSE TIME TRACKING:
# process_mission() measures wall-clock time for each full scan+vote+generate cycle
# and records it on all participating nodes via record_response_time!(). Nodes 
# with slow average times are automatically graved by the Engine ledger system.
#
# 8. SEMANTIC VERB REGISTRY CLI INTEGRATION:
# Four CLI commands expose the SemanticVerbs live registry to the operator at runtime:
#   /addVerb <verb> <class>           — adds a verb to an existing relation class
#   /addRelationClass <name>          — creates a new verb class bucket
#   /addSynonym <canonical> <alias>   — registers alias→canonical normalization
#   /listVerbs                        — dumps all classes, verbs, and synonyms
# All mutations take effect immediately on the next /mission call because
# extract_relational_triples() calls get_all_verbs() and normalize_synonyms()
# on every invocation. Errors from bad class names or duplicate entries are
# surfaced loudly through the standard CLI catch block with a printed backtrace.
#
# 9. ACTION+TONE AROUSAL PRE-SET IN BEHAVIORAL LAYER:
# process_mission() invokes ActionTonePredictor.predict_action_tone() a second
# time (first invocation is inside scan_specimens for confidence weighting) to
# apply an EyeSystem arousal nudge before the scan. The two invocations are
# intentionally orthogonal: the engine-layer call modulates per-node confidence
# multipliers (scan concern); the behavioral-layer call here modulates the global
# arousal level (EyeSystem concern). apply_prediction_to_arousal!() is decoupled
# from EyeSystem via function handle injection, keeping the predictor independently
# testable. Both calls are wrapped in non-fatal try/catch: a prediction failure
# never blocks the mission scan or response generation.
#
# 10. LOBE-AWARE PREFRONTAL CORTEX (AIML CONTEXT):
# extract_lobe_aware_context(votes) maps all votes to their owning lobes,
# building a cross-domain context string injected into the AIML payload via
# the {LOBE_CONTEXT} placeholder. This ensures the prefrontal cortex (AIML)
# has global awareness of which subject domains are active for the current
# query, preventing domain isolation where only one lobe's knowledge would
# be visible. Active lobe names, node counts, and sample patterns are
# included so orchestration rules can reason across science ↔ philosophy ↔
# reasoning boundaries. Errors in lobe context extraction are non-fatal
# (logged via @warn, fallback to empty context string).
#
# 11. NEGATIVE THESAURUS (INHIBITION FILTER):
# Five CLI commands expose the InputQueue.NegativeThesaurus to the operator:
#   /negativeThesaurus add <word> [--reason <text>]  — register inhibition
#   /negativeThesaurus remove <word>                 — deregister
#   /negativeThesaurus list                          — show all entries
#   /negativeThesaurus check <word>                  — test if inhibited
#   /negativeThesaurus flush                         — clear all entries
# Inhibited words are filtered from input tokens before pattern scanning,
# acting as a pre-scan suppression layer. O(1) lookup via Dict{String,NegEntry}.
#
# 12. SPECIMEN PERSISTENCE (FULL CAVE STATE SAVE/RESTORE):
# /saveSpecimen <filepath> serializes the ENTIRE cave state to a gzip-compressed
# JSON file. /loadSpecimen <filepath> reads that file and performs a full brain
# transplant — current state is WIPED and replaced with the specimen contents.
# Together they provide long-term persistence for GrugBot instances.
#
# State categories captured (17 total, v2.1):
#   1. nodes          — full Node structs (id, pattern, signal, action_packet,
#                       strength, neighbors, graves, drop_table, response_times,
#                       hopfield_key, relational_patterns, etc.)
#   2. hopfield_cache — familiar input fast-path cache + hit counts
#   3. rules          — AIML_DROP_TABLE stochastic orchestration rules
#   4. message_history— up to 10k ChatMessage entries with pin flags
#   5. lobes          — LOBE_REGISTRY (subject, node_ids, connections, fire/inhibit)
#   6. node_to_lobe_idx — NODE_TO_LOBE_IDX reverse index
#   7. lobe_tables    — LOBE_TABLE_REGISTRY with all chunks (NodeRef objects)
#   8. verb_registry  — SemanticVerbs classes + verbs + synonyms
#   9. thesaurus_seeds— Thesaurus SYNONYM_SEED_MAP (hardcoded + runtime)
#  10. inhibitions    — InputQueue NegativeThesaurus entries
#  11. arousal        — EyeSystem arousal state (level, decay_rate, baseline)
#  12. id_counters    — NODE ID_COUNTER + MSG_ID_COUNTER atomic values
#  13. brainstem      — dispatch count, propagation history
#  14. attachments    — ATTACHMENT_MAP relational fire system
#  15. trajectory     — ActionTonePredictor ring buffer + config (Lorenz damping)
#  16. temporal_coherence — ImageSDF TEMPORAL_COHERENCE_LEDGER timing patterns
#  17. morph_cooldowns — ChatterMode MORPH_COOLDOWN_MAP 24h timestamps
#
# /loadSpecimen is DESTRUCTIVE: validates the entire file structure BEFORE
# wiping any state. If validation fails, ZERO changes are made. Restore order
# is deliberate: counters → verbs → thesaurus → lobes → lobe_tables → nodes →
# node_to_lobe_idx → hopfield → rules → inhibitions → messages → arousal →
# brainstem → attachments → trajectory → temporal_coherence → morph_cooldowns.
# Each restore step is individually wrapped in try/catch with FATAL error
# reporting. v2.1 keys are optional on load for backward compat with v2.0.
# File format: gzip-compressed JSON (system gzip/gunzip via pipeline,
# no extra Julia packages required).
# ==============================================================================