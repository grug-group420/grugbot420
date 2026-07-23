# test_chat_specimen.jl
# ─────────────────────────────────────────────────────────────────────────────
# GRUG: Live chat specimen test. Load Main.jl non-interactively, seed a
# meaningful specimen, add orchestration rules, fire /mission calls, observe.
# We monkey-patch run_cli() to a no-op so Main.jl loads without blocking.
# ─────────────────────────────────────────────────────────────────────────────

# GRUG: Suppress run_cli() from blocking by redefining it before Main.jl
# loads... except Main.jl defines run_cli() itself. Trick: include everything
# EXCEPT the final run_cli() call by including the component files directly.

if !isdefined(Main, :CoinFlipHeader)
    include("stochastichelper.jl")
end
using .CoinFlipHeader

include("engine.jl")

if !isdefined(Main, :ChatterMode)
    include("ChatterMode.jl")
end
using .ChatterMode

using Base64: base64decode
using Base.Threads: Atomic, atomic_add!

# ─────────────────────────────────────────────────────────────────────────────
# INLINE the parts of Main.jl we need (memory cave, orchestrator, commands,
# process_mission) without the CLI loop. We just copy the non-CLI definitions.
# ─────────────────────────────────────────────────────────────────────────────

mutable struct ChatMessage
    id::Int
    role::String
    text::String
    pinned::Bool
end

const MAX_HISTORY    = 10000
const MESSAGE_HISTORY = Vector{ChatMessage}()
const MSG_ID_COUNTER  = Atomic{Int}(0)
const ALLOWED_ROLES   = Set(["User", "System", "User_Pinned", "Engine_Voice"])

function add_message_to_history!(role::String, text::String, pinned::Bool=false)
    strip(text) == "" || strip(role) == "" && error("!!! FATAL: empty message !!!")
    !(role in ALLOWED_ROLES) && error("!!! FATAL: bad role '$role' !!!")
    id  = atomic_add!(MSG_ID_COUNTER, 1)
    msg = ChatMessage(id, role, text, pinned)
    if length(MESSAGE_HISTORY) < MAX_HISTORY
        push!(MESSAGE_HISTORY, msg)
    else
        idx = findfirst(m -> !m.pinned, MESSAGE_HISTORY)
        isnothing(idx) && error("!!! FATAL: memory cave full of pinned rocks !!!")
        deleteat!(MESSAGE_HISTORY, idx)
        push!(MESSAGE_HISTORY, msg)
    end
end

function extract_aiml_memory_context()::String
    length(MESSAGE_HISTORY) == 0 && return "Memory Cave: [EMPTY]"
    pinned_msgs = String[]
    recent_msgs = String[]
    for m in MESSAGE_HISTORY
        m.pinned && push!(pinned_msgs, "[$(m.role)]: $(m.text)")
    end
    unpinned = [m for m in MESSAGE_HISTORY if !m.pinned]
    rc = min(5, length(unpinned))
    for i in (length(unpinned)-rc+1):length(unpinned)
        push!(recent_msgs, "[$(unpinned[i].role)]: $(unpinned[i].text)")
    end
    pinned_str = isempty(pinned_msgs) ? "No pinned rocks" : join(pinned_msgs, " | ")
    recent_str = isempty(recent_msgs) ? "No recent sounds" : join(recent_msgs, " | ")
    return "Deep Memory (Pinned): $pinned_str\nFresh Memory (Recent): $recent_str"
end

function ephemeral_aiml_orchestrator(mission::String, votes::Vector{Vote})
    isempty(votes) && error("!!! FATAL: zero votes !!!")
    strip(mission) == "" && error("!!! FATAL: empty mission !!!")
    max_conf   = maximum(v.confidence for v in votes)
    sure_votes = Vote[]
    unsure_votes = Vote[]
    for v in votes
        if v.confidence >= max_conf - 0.05
            push!(sure_votes, v)
        else
            @coinflip [
                bias(:Keep, 50) => () -> push!(unsure_votes, v),
                bias(:Drop, 50) => () -> nothing
            ]
        end
    end
    isempty(sure_votes) && error("!!! FATAL: zero sure votes !!!")
    primary_vote = sure_votes[1]
    node = lock(() -> get(NODE_MAP, primary_vote.node_id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: winning node vanished !!!")
    return COMMANDS[primary_vote.action](mission, node, primary_vote, sure_votes, unsure_votes, votes)
end

function generate_aiml_payload(mission, primary_vote, sure_votes, unsure_votes, all_votes, context)
    !haskey(context, "system_prompt") && error("!!! FATAL: missing system_prompt !!!")
    system_prompt = context["system_prompt"]
    neg_str       = isempty(primary_vote.negatives) ? "None" : join(primary_vote.negatives, ", ")
    memory_str    = extract_aiml_memory_context()
    sure_str      = join([v.action for v in sure_votes], ", ")
    unsure_str    = isempty(unsure_votes) ? "None" : join([v.action for v in unsure_votes], ", ")

    evaluated_rules = String[]
    for rule in AIML_DROP_TABLE
        rand() > rule.fire_probability && continue
        processed = rule.text
        processed = replace(processed, "{MISSION}"        => mission)
        processed = replace(processed, "{PRIMARY_ACTION}" => primary_vote.action)
        processed = replace(processed, "{SURE_ACTIONS}"   => sure_str)
        processed = replace(processed, "{UNSURE_ACTIONS}" => unsure_str)
        processed = replace(processed, "{ALL_ACTIONS}"    => join([v.action for v in all_votes], ", "))
        processed = replace(processed, "{CONFIDENCE}"     => string(round(primary_vote.confidence, digits=2)))
        processed = replace(processed, "{NODE_ID}"        => primary_vote.node_id)
        processed = replace(processed, "{MEMORY}"         => memory_str)
        push!(evaluated_rules, processed)
    end

    rules_str = isempty(evaluated_rules) ? "None" : join(evaluated_rules, " | ")
    u_triples = isempty(primary_vote.user_triples) ? "None" :
        join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.user_triples], ", ")
    n_triples = isempty(primary_vote.node_triples) ? "None" :
        join(["($(t.subject), $(t.relation), $(t.object))" for t in primary_vote.node_triples], ", ")

    jit_response = "[System: $system_prompt]\n"
    if primary_vote.action in ["greet", "welcome", "smile", "laugh"]
        jit_response *= "Hello! Received: '$mission'. "
    elseif primary_vote.action in ["flee", "hide", "fight"]
        jit_response *= "⚠ Evasive protocol: '$mission'. "
    elseif primary_vote.action in ["explain", "clarify", "define", "describe", "elaborate"]
        jit_response *= "📖 Explanation mode: '$mission'. "
    elseif primary_vote.action in ["comfort", "support", "validate", "acknowledge", "reassure"]
        jit_response *= "💙 Support mode: '$mission'. "
    elseif primary_vote.action in ["warn", "alert", "caution", "notify", "flag"]
        jit_response *= "🚨 Alert mode: '$mission'. "
    else
        jit_response *= "🧠 Processing: '$mission'. "
    end

    jit_response *= "Sure: [$sure_str]. "
    !isempty(unsure_votes) && (jit_response *= "Considering: [$unsure_str]. ")
    if !isempty(evaluated_rules)
        jit_response *= "\n[RULES FIRED]:\n"
        for r in evaluated_rules; jit_response *= " -> $r\n"; end
    end

    sleep(0.05)

    out  = "─────────────────────────────────────────────────\n"
    out *= "PAYLOAD  | Conf=$(round(primary_vote.confidence, digits=3)) | Node=$(primary_vote.node_id)\n"
    out *= "Mission  | $mission\n"
    out *= "Action   | $(primary_vote.action)\n"
    out *= "Sure     | [$sure_str]\n"
    out *= "Unsure   | [$unsure_str]\n"
    out *= "Rules    | [$rules_str]\n"
    out *= "Limits   | [$neg_str]\n"
    out *= "Context  | $system_prompt\n"
    out *= "U-Trips  | $u_triples\n"
    out *= "N-Trips  | $n_triples\n"
    out *= "Antimatch| $(primary_vote.antimatch)\n"
    out *= "Memory   |\n$memory_str\n"
    out *= "─────────────────────────────────────────────────\n"
    out *= "🗣 JIT RESPONSE:\n$jit_response\n"
    out *= "─────────────────────────────────────────────────"
    return out
end

# GRUG: Action family registrations
for act in ["reason", "analyze", "ponder", "calculate"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        mission == "boom" && error("!!! intentional crash !!!")
        node.json_data["last_reason"] = mission
        generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
    end
end
for act in ["greet", "welcome", "smile", "laugh"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
end
for act in ["flee", "hide", "fight"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        reset_throttle!(node, 1.0)
        generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
    end
end
# GRUG: explain/clarify/define/describe/elaborate now registered in the warning+empathy+explain blocks below.
for act in ["warn", "alert", "caution", "notify", "flag"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        reset_throttle!(node, 1.0)
        generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
    end
end
# GRUG: Empathy family — matches Main.jl registration
for act in ["comfort", "support", "validate", "acknowledge", "reassure"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        reset_throttle!(node, 0.5)
        generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
    end
end
# GRUG: Explain family — matches Main.jl registration
for act in ["explain", "clarify", "describe", "define", "elaborate"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        reset_throttle!(node, 0.7)
        generate_aiml_payload(mission, pv, sv, uv, av, node.json_data)
    end
end

const LAST_VOTER_IDS  = String[]
const LAST_VOTER_LOCK = ReentrantLock()

function process_mission(mission_text::String)
    strip(mission_text) == "" && error("!!! FATAL: empty mission !!!")
    add_message_to_history!("User", mission_text, false)

    is_image = false

    if !is_image
        try
            prediction = ActionTonePredictor.predict_action_tone(
                mission_text, SemanticVerbs.get_all_verbs()
            )
            ActionTonePredictor.apply_prediction_to_arousal!(
                prediction, EyeSystem.get_arousal, EyeSystem.set_arousal!
            )
        catch e
            @warn "[MAIN] arousal nudge failed (non-fatal): $e"
        end
    end

    t_start         = time()
    valid_specimens = scan_and_expand(mission_text)

    if isempty(valid_specimens)
        println("  [CAVE SILENT] No nodes fired for this input.")
        return nothing
    end

    cast_votes = Vote[]
    for (id, conf, is_antimatch, u_trips, n_trips) in valid_specimens
        push!(cast_votes, cast_vote(id, conf, is_antimatch, u_trips, n_trips))
    end

    output = ephemeral_aiml_orchestrator(mission_text, cast_votes)
    t_elapsed = time() - t_start

    for v in cast_votes
        vn = lock(() -> get(NODE_MAP, v.node_id, nothing), NODE_LOCK)
        !isnothing(vn) && record_response_time!(vn, t_elapsed)
    end

    lock(LAST_VOTER_LOCK) do
        empty!(LAST_VOTER_IDS)
        append!(LAST_VOTER_IDS, [v.node_id for v in cast_votes])
    end

    add_message_to_history!("System", output, false)
    return output
end

# ═════════════════════════════════════════════════════════════════════════════
# SPECIMEN SEEDING
# ═════════════════════════════════════════════════════════════════════════════

println("\n" * "="^65)
println("  GRUGBOT CHAT SPECIMEN — LIVE TEST RUN")
println("="^65)
println("\n📦 Seeding specimen nodes...\n")

# ── GREETING CLUSTER ──────────────────────────────────────────────────────
greet_ctx = Dict{String,Any}("system_prompt" => "Warm greeting protocols. Be friendly and welcoming.")
create_node("hello hi hey howdy greetings good morning",
    "greet[dont ignore, dont be rude]^4 | welcome[dont be cold]^3 | smile^2 | laugh^1",
    greet_ctx, String[])
create_node("welcome back nice to see you again glad you are here",
    "welcome[dont be cold]^5 | greet^2 | smile^1",
    greet_ctx, String[])

# ── REASONING / ANALYSIS CLUSTER ──────────────────────────────────────────
reason_ctx = Dict{String,Any}("system_prompt" => "Cold logical analysis engine. Think step by step.")
create_node("think reason logic analyze explain why how does work",
    "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^2 | explain^1",
    reason_ctx, String[])
create_node("calculate compute math formula number result answer",
    "calculate[dont guess, dont approximate]^5 | analyze^3 | reason^2",
    reason_ctx, String[])
create_node("understand meaning concept idea what is definition",
    "define[dont oversimplify]^4 | explain^3 | clarify^2 | describe^1",
    reason_ctx, String[])

# ── KNOWLEDGE / EXPLANATION CLUSTER ───────────────────────────────────────
explain_ctx = Dict{String,Any}("system_prompt" => "Knowledge base. Provide clear accurate explanations.")
create_node("explain describe tell me about show me how learn teach",
    "explain[dont lie, dont confuse]^5 | describe^3 | clarify^2 | define^1",
    explain_ctx, String[])
create_node("what is difference between compare contrast versus",
    "clarify[dont conflate]^4 | explain^3 | describe^2 | analyze^1",
    explain_ctx, String[])

# ── CAUSAL REASONING CLUSTER (with relational gating) ─────────────────────
causal_ctx = Dict{String,Any}(
    "system_prompt"      => "Causal reasoning engine. Trace cause and effect chains.",
    "required_relations" => ["causes"],
    "relation_weights"   => Dict("causes" => 3.0)
)
create_node("fire causes smoke heat damage destruction burn",
    "analyze[dont minimize, dont panic]^5 | reason^3 | warn^2",
    causal_ctx, String[])
create_node("rain causes flood water rise danger risk",
    "warn[dont ignore]^4 | analyze^3 | alert^2",
    causal_ctx, String[])
create_node("stress causes problems health mental physical",
    "comfort[dont dismiss]^4 | analyze^3 | support^2",
    causal_ctx, String[])

# ── EMOTIONAL SUPPORT CLUSTER ─────────────────────────────────────────────
support_ctx = Dict{String,Any}("system_prompt" => "Empathetic support mode. Acknowledge feelings first.")
create_node("feel sad unhappy depressed down low mood struggle",
    "comfort[dont minimize, dont lecture]^5 | support^4 | validate^3",
    support_ctx, String[])
create_node("worried anxious nervous scared afraid fear stress",
    "comfort[dont dismiss]^5 | support^4 | reassure^3 | explain[dont escalate]^1",
    support_ctx, String[])
create_node("happy excited good great wonderful amazing joy",
    "smile[dont dampen]^5 | laugh^3 | greet^2 | welcome^1",
    support_ctx, String[])

# ── WARNING / DANGER CLUSTER ──────────────────────────────────────────────
warn_ctx = Dict{String,Any}("system_prompt" => "Safety alert system. Surface risks clearly and calmly.")
create_node("danger warning alert risk hazard unsafe critical error",
    "warn[dont ignore, dont downplay]^5 | alert^4 | caution^3 | analyze^2",
    warn_ctx, String[])
create_node("urgent emergency now immediately critical failure crash",
    "alert[dont delay, dont dismiss]^5 | warn^4 | notify^3",
    warn_ctx, String[])

# ── IDENTITY / META CLUSTER ───────────────────────────────────────────────
meta_ctx = Dict{String,Any}("system_prompt" => "Self-aware meta layer. Answer questions about the system itself.")
create_node("who are you what are you tell me about yourself system ai bot",
    "describe[dont lie, dont overclaim]^4 | explain^3 | define^2",
    meta_ctx, String[])
create_node("how do you work what can you do capabilities features",
    "explain[dont exaggerate]^5 | describe^3 | clarify^2",
    meta_ctx, String[])

# ── CONFLICT / NEGATION CLUSTER ───────────────────────────────────────────
conflict_ctx = Dict{String,Any}(
    "system_prompt"      => "Conflict detection. Flag contradictions and anti-patterns.",
    "required_relations" => ["hits"],
    "relation_weights"   => Dict("hits" => 2.5)
)
create_node("grug hits rock makes fire strong",
    "analyze[dont panic]^5 | ponder^2 | reason^1",
    conflict_ctx, String[])

println("✅ Planted $(length(NODE_MAP)) specimen nodes.\n")

# ═════════════════════════════════════════════════════════════════════════════
# ORCHESTRATION RULES
# ═════════════════════════════════════════════════════════════════════════════

println("📋 Adding orchestration rules...\n")

add_orchestration_rule!("Mission '{MISSION}' routed to action [{PRIMARY_ACTION}] with confidence {CONFIDENCE}.")
add_orchestration_rule!("Sure actions for this input: [{SURE_ACTIONS}].")
add_orchestration_rule!("Confidence {CONFIDENCE} — primary node: {NODE_ID}. [prob=0.75]")
add_orchestration_rule!("Also considering side features: [{UNSURE_ACTIONS}]. [prob=0.6]")
add_orchestration_rule!("Memory context: {MEMORY}. [prob=0.4]")
add_orchestration_rule!("Input '{MISSION}' analyzed. Primary route confirmed: {PRIMARY_ACTION}. [prob=0.85]")
add_orchestration_rule!("All candidate actions: [{ALL_ACTIONS}]. [prob=0.5]")

println("✅ $(length(AIML_DROP_TABLE)) rules loaded.\n")

# ═════════════════════════════════════════════════════════════════════════════
# SYNONYM + VERB REGISTRY SETUP
# ═════════════════════════════════════════════════════════════════════════════

SemanticVerbs.add_synonym!("causes", "triggers")
SemanticVerbs.add_synonym!("causes", "leads")
SemanticVerbs.add_synonym!("causes", "produces")
SemanticVerbs.add_synonym!("causes", "results")
SemanticVerbs.add_synonym!("follows", "after")
SemanticVerbs.add_synonym!("follows", "succeeds")
SemanticVerbs.add_synonym!("connects", "links")
SemanticVerbs.add_synonym!("connects", "bridges")

println("✅ Synonyms registered: triggers/leads/produces/results → causes, after/succeeds → follows, links/bridges → connects\n")

# ═════════════════════════════════════════════════════════════════════════════
# LIVE /MISSION TEST RUNS
# ═════════════════════════════════════════════════════════════════════════════

missions = [
    # Greeting inputs
    "hello there how are you doing today",
    "hey good morning glad to be here",

    # Reasoning / analysis
    "how does machine learning work",
    "what is the difference between supervised and unsupervised learning",
    "can you explain why neural networks need activation functions",

    # Causal chain inputs (should trigger relational gating)
    "fire causes smoke and destruction everywhere",
    "stress causes serious health problems over time",
    "heavy rain triggers flooding in low areas",       # synonym: triggers → causes

    # Emotional support
    "i feel really sad and dont know what to do",
    "im so worried about everything lately",
    "this is amazing i am so excited and happy",

    # Warning / danger
    "critical error detected system is about to crash",
    "urgent this is an emergency we need help now",

    # Identity / meta
    "who are you and what can you do",
    "how do you actually work under the hood",

    # Ambiguous / mixed
    "grug hits rock and makes fire",
    "i need to calculate the result of this formula",

    # Incomplete causal (dangling verb — should trigger chain warning)
    "the system failure causes",
]

println("="^65)
println("  FIRING $(length(missions)) MISSION INPUTS")
println("="^65)

pass_count  = 0
fail_count  = 0
silent_count = 0

for (i, m) in enumerate(missions)
    println("\n┌─ MISSION $(lpad(i, 2)) ─────────────────────────────────────────────")
    println("│  INPUT: \"$m\"")
    println("└" * "─"^60)
    try
        result = process_mission(m)
        if isnothing(result)
            println("  ⚠  [CAVE SILENT — no nodes fired]")
            global silent_count += 1
        else
            # Print just the key lines (not full payload dump — too noisy)
            for line in split(result, "\n")
                if startswith(line, "Action") || startswith(line, "Sure") ||
                   startswith(line, "Conf")   || startswith(line, "Rules") ||
                   startswith(line, "🗣")     || startswith(line, " ->") ||
                   startswith(line, "U-Trips") || startswith(line, "Antimatch")
                    println("  $line")
                end
            end
            global pass_count += 1
        end
    catch e
        println("  ❌ ERROR: $e")
        global fail_count += 1
    end
end

println("\n" * "="^65)
println("  RESULTS: $(pass_count) fired | $(silent_count) silent | $(fail_count) errors")
println("  Node map size : $(length(NODE_MAP))")
println("  Memory history: $(length(MESSAGE_HISTORY)) messages")
println("  Arousal level : $(round(EyeSystem.get_arousal(), digits=3))")
println("  Hopfield cache: $(length(HOPFIELD_CACHE)) entries")
println("="^65)

# ── Final: dump node strengths to see who got reinforced ──────────────────
println("\n📊 NODE STRENGTH SUMMARY (after $(length(missions)) missions):")
lock(NODE_LOCK) do
    for (id, node) in sort(collect(NODE_MAP), by=x->-x[2].strength)
        grave  = node.is_grave ? " [GRAVE]" : ""
        voters = id in LAST_VOTER_IDS ? " ◄ last voter" : ""
        println("  $(rpad(id,10)) | str=$(lpad(round(node.strength,digits=1),4)) | $(first(node.pattern, 45))$grave$voters")
    end
end

println("\n✅ Chat specimen test complete.\n")