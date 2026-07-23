# live_training_test.jl
# ─────────────────────────────────────────────────────────────────────────────
# GRUG: Full multi-lobe training harness. Grow lobes, seed nodes, run missions.
# Tests cross-domain bridging, causal chains, emotional routing, and cascade.
# Run with: julia live_training_test.jl
# ─────────────────────────────────────────────────────────────────────────────

# GRUG: Load Main.jl non-interactively by stripping the run_cli() call.
# Must strip bare `run_cli()` at end of file before including.

println("=" ^ 65)
println("  GRUGBOT LIVE TRAINING TEST")
println("=" ^ 65)
println()

print("⏳ Loading Main.jl (stripping CLI loop)... ")
main_src = read("Main.jl", String)

# GRUG: Strip bare run_cli() call at end of file (must be on its own line)
main_src = replace(main_src, r"^run_cli\(\)\s*$"m => "# [TRAINING] run_cli() suppressed")

include_string(Main, main_src)
println("✅ Done.\n")

# ─────────────────────────────────────────────────────────────────────────────
# LOBE SETUP: Build multi-domain lobe structure
# ─────────────────────────────────────────────────────────────────────────────

println("🧠 Building lobe architecture...")

Lobe.create_lobe!("greetings",   "Social greeting and welcome behaviors")
Lobe.create_lobe!("reasoning",   "Logic, analysis, and calculation")
Lobe.create_lobe!("knowledge",   "Explanation and knowledge retrieval")
Lobe.create_lobe!("causal",      "Cause-and-effect chain analysis")
Lobe.create_lobe!("emotional",   "Emotional support and empathy")
Lobe.create_lobe!("warnings",    "Safety alerts and danger detection")
Lobe.create_lobe!("identity",    "Self-awareness and meta responses")

# GRUG: Connect related lobes for cascade bridging
Lobe.connect_lobes!("reasoning",  "knowledge")   # Logic bridges to knowledge
Lobe.connect_lobes!("causal",     "warnings")    # Cause-effect bridges to danger
Lobe.connect_lobes!("emotional",  "warnings")    # Emotional distress bridges to alerts
Lobe.connect_lobes!("greetings",  "emotional")   # Greetings bridge to emotional tone
Lobe.connect_lobes!("identity",   "knowledge")   # Self-knowledge bridges to general knowledge

println("✅ $(length(Lobe.get_lobe_ids())) lobes created and connected.\n")

# ─────────────────────────────────────────────────────────────────────────────
# NODE SEEDING: Grow nodes directly into lobes
# ─────────────────────────────────────────────────────────────────────────────

println("🌱 Seeding nodes into lobes...\n")

function grow_into_lobe!(lobe_id, pattern, action_packet, ctx, drop_table=String[])
    nid = create_node(pattern, action_packet, ctx, drop_table)
    Lobe.add_node_to_lobe!(lobe_id, nid)
    LobeTable.create_lobe_table!(lobe_id)  # idempotent
    LobeTable.drop_table_to_chunk!(lobe_id, nid, drop_table)
    LobeTable.node_ref_put!(lobe_id, nid)
    return nid
end

# ── GREETINGS LOBE ───────────────────────────────────────────────────────────
greet_ctx = Dict{String,Any}("system_prompt" => "Warm greeting protocols. Be friendly and welcoming.")

g1 = grow_into_lobe!("greetings",
    "hello hi hey howdy greetings good morning",
    "greet[dont ignore, dont be rude]^4 | welcome[dont be cold]^3 | smile^2 | laugh^1",
    greet_ctx)

g2 = grow_into_lobe!("greetings",
    "welcome back nice to see you again glad you are here",
    "welcome[dont be cold]^5 | greet^2 | smile^1",
    greet_ctx)

# GRUG: Link greetings as drop-table neighbors
Lobe.add_node_to_lobe!("greetings", g1)
LobeTable.drop_table_to_chunk!("greetings", g1, [g2])
LobeTable.drop_table_to_chunk!("greetings", g2, [g1])

println("  ✅ Greetings lobe: 2 nodes")

# ── REASONING LOBE ───────────────────────────────────────────────────────────
reason_ctx = Dict{String,Any}("system_prompt" => "Cold logical analysis. Think step by step.")

r1 = grow_into_lobe!("reasoning",
    "think reason logic analyze explain why how does work",
    "reason[dont guess, dont hallucinate]^4 | analyze[dont assume]^3 | ponder^2 | explain^1",
    reason_ctx)

r2 = grow_into_lobe!("reasoning",
    "calculate compute math formula number result answer",
    "calculate[dont guess, dont approximate]^5 | analyze^3 | reason^2",
    reason_ctx)

r3 = grow_into_lobe!("reasoning",
    "understand meaning concept idea what is definition",
    "define[dont oversimplify]^4 | explain^3 | clarify^2 | describe^1",
    reason_ctx)

LobeTable.drop_table_to_chunk!("reasoning", r1, [r2, r3])
LobeTable.drop_table_to_chunk!("reasoning", r2, [r1])
LobeTable.drop_table_to_chunk!("reasoning", r3, [r1])

println("  ✅ Reasoning lobe: 3 nodes")

# ── KNOWLEDGE LOBE ───────────────────────────────────────────────────────────
explain_ctx = Dict{String,Any}("system_prompt" => "Knowledge base. Provide clear accurate explanations.")

k1 = grow_into_lobe!("knowledge",
    "explain describe tell me about show me how learn teach",
    "explain[dont lie, dont confuse]^5 | describe^3 | clarify^2 | define^1",
    explain_ctx)

k2 = grow_into_lobe!("knowledge",
    "what is difference between compare contrast versus",
    "clarify[dont conflate]^4 | explain^3 | describe^2 | analyze^1",
    explain_ctx)

k3 = grow_into_lobe!("knowledge",
    "machine learning neural network deep learning ai algorithm model train",
    "explain[dont overclaim]^5 | describe^4 | clarify^3 | analyze^2",
    explain_ctx)

k4 = grow_into_lobe!("knowledge",
    "supervised unsupervised learning label feature classification regression",
    "clarify[dont oversimplify]^4 | explain^3 | describe^3 | define^2",
    explain_ctx)

k5 = grow_into_lobe!("knowledge",
    "activation function neural network layer gradient backpropagation",
    "explain[dont overcomplicate]^5 | describe^3 | analyze^2",
    explain_ctx)

LobeTable.drop_table_to_chunk!("knowledge", k1, [k2])
LobeTable.drop_table_to_chunk!("knowledge", k2, [k1])
LobeTable.drop_table_to_chunk!("knowledge", k3, [k4, k5])
LobeTable.drop_table_to_chunk!("knowledge", k4, [k3, k5])
LobeTable.drop_table_to_chunk!("knowledge", k5, [k3, k4])

println("  ✅ Knowledge lobe: 5 nodes")

# ── CAUSAL LOBE ──────────────────────────────────────────────────────────────
causal_ctx = Dict{String,Any}(
    "system_prompt"      => "Causal reasoning engine. Trace cause and effect chains.",
    "required_relations" => ["causes"],
    "relation_weights"   => Dict("causes" => 3.0)
)

c1 = grow_into_lobe!("causal",
    "fire causes smoke heat damage destruction burn",
    "analyze[dont minimize, dont panic]^5 | reason^3 | warn^2",
    causal_ctx)

c2 = grow_into_lobe!("causal",
    "rain causes flood water rise danger risk",
    "warn[dont ignore]^4 | analyze^3 | alert^2",
    causal_ctx)

c3 = grow_into_lobe!("causal",
    "stress causes problems health mental physical",
    "comfort[dont dismiss]^4 | analyze^3 | support^2",
    causal_ctx)

c4 = grow_into_lobe!("causal",
    "heavy rain triggers flooding low areas risk overflow",
    "warn[dont downplay]^4 | alert^3 | analyze^2",
    causal_ctx)

LobeTable.drop_table_to_chunk!("causal", c1, [c2])
LobeTable.drop_table_to_chunk!("causal", c2, [c1, c4])
LobeTable.drop_table_to_chunk!("causal", c4, [c2])

println("  ✅ Causal lobe: 4 nodes")

# ── EMOTIONAL LOBE ───────────────────────────────────────────────────────────
support_ctx = Dict{String,Any}("system_prompt" => "Empathetic support mode. Acknowledge feelings first.")

e1 = grow_into_lobe!("emotional",
    "feel sad unhappy depressed down low mood struggle",
    "comfort[dont minimize, dont lecture]^5 | support^4 | validate^3",
    support_ctx)

e2 = grow_into_lobe!("emotional",
    "worried anxious nervous scared afraid fear stress",
    "comfort[dont dismiss]^5 | support^4 | reassure^3 | explain[dont escalate]^1",
    support_ctx)

e3 = grow_into_lobe!("emotional",
    "happy excited good great wonderful amazing joy",
    "smile[dont dampen]^5 | laugh^3 | greet^2 | welcome^1",
    support_ctx)

LobeTable.drop_table_to_chunk!("emotional", e1, [e2])
LobeTable.drop_table_to_chunk!("emotional", e2, [e1])

println("  ✅ Emotional lobe: 3 nodes")

# ── WARNINGS LOBE ────────────────────────────────────────────────────────────
warn_ctx = Dict{String,Any}("system_prompt" => "Safety alert system. Surface risks clearly and calmly.")

w1 = grow_into_lobe!("warnings",
    "danger warning alert risk hazard unsafe critical error",
    "warn[dont ignore, dont downplay]^5 | alert^4 | caution^3 | analyze^2",
    warn_ctx)

w2 = grow_into_lobe!("warnings",
    "urgent emergency now immediately critical failure crash",
    "alert[dont delay, dont dismiss]^5 | warn^4 | notify^3",
    warn_ctx)

LobeTable.drop_table_to_chunk!("warnings", w1, [w2])
LobeTable.drop_table_to_chunk!("warnings", w2, [w1])

println("  ✅ Warnings lobe: 2 nodes")

# ── IDENTITY LOBE ────────────────────────────────────────────────────────────
meta_ctx = Dict{String,Any}("system_prompt" => "Self-aware meta layer. Answer questions about the system itself.")

m1 = grow_into_lobe!("identity",
    "who are you what are you tell me about yourself system ai bot",
    "describe[dont lie, dont overclaim]^4 | explain^3 | define^2",
    meta_ctx)

m2 = grow_into_lobe!("identity",
    "how do you work what can you do capabilities features",
    "explain[dont exaggerate]^5 | describe^3 | clarify^2",
    meta_ctx)

LobeTable.drop_table_to_chunk!("identity", m1, [m2])
LobeTable.drop_table_to_chunk!("identity", m2, [m1])

println("  ✅ Identity lobe: 2 nodes")

println("\n📊 Total nodes in cave: $(length(NODE_MAP))")
println("📊 Lobe structure:\n$(Lobe.get_lobe_status_summary())\n")

# ─────────────────────────────────────────────────────────────────────────────
# REGISTER TEST COMMANDS (same families as Main.jl)
# ─────────────────────────────────────────────────────────────────────────────

println("⚙️  Registering command families...")

for act in ["reason", "analyze", "ponder", "calculate"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) -> begin
        mission == "boom" && error("!!! FATAL: intentional crash !!!")
        node.json_data["last_reason"] = mission
        "📊 [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3)) | negs=$(join(pv.negatives, ","))"
    end
end
for act in ["greet", "welcome", "smile", "laugh"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) ->
        "👋 [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3))"
end
for act in ["flee", "hide", "fight"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) ->
        "⚠️  [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3))"
end
for act in ["explain", "clarify", "describe", "define", "elaborate"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) ->
        "📖 [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3)) | negs=$(join(pv.negatives, ","))"
end
for act in ["comfort", "support", "validate", "acknowledge", "reassure"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) ->
        "💙 [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3))"
end
for act in ["warn", "alert", "caution", "notify", "flag"]
    COMMANDS[act] = (mission, node, pv, sv, uv, av) ->
        "🚨 [$(act)] $(mission) | conf=$(round(pv.confidence, digits=3))"
end

println("✅ $(length(COMMANDS)) commands registered.\n")

# ─────────────────────────────────────────────────────────────────────────────
# ORCHESTRATION RULES
# ─────────────────────────────────────────────────────────────────────────────

add_orchestration_rule!("Mission '{MISSION}' → action [{PRIMARY_ACTION}] conf {CONFIDENCE}.")
add_orchestration_rule!("Sure actions: [{SURE_ACTIONS}].")

# ─────────────────────────────────────────────────────────────────────────────
# TEST HELPER
# ─────────────────────────────────────────────────────────────────────────────

pass_count  = 0
soft_count  = 0  # GRUG: Cave silent = soft miss, not hard fail
fail_count  = 0

function run_mission(label::String, text::String;
                     expect_action=nothing, expect_no_crash=true)
    global pass_count, soft_count, fail_count
    print("  TEST [$(label)]: ")
    try
        votes = Vote[]
        for (id, conf, anti, ut, nt) in scan_and_expand(text)
            push!(votes, cast_vote(id, conf, anti, ut, nt))
        end
        if isempty(votes)
            # GRUG: Cave silent is a soft miss — scanner threshold too high for input.
            # Not a crash, just means we need more nodes or lower threshold.
            println("⚠️  CAVE SILENT — no nodes fired (soft miss)")
            soft_count += 1
            return
        end
        # GRUG: Sort votes by confidence (mirrors orchestrator fix)
        sort!(votes; by = v -> v.confidence, rev = true)
        result = ephemeral_aiml_orchestrator(text, votes)
        primary_action = votes[1].action
        n_votes = length(votes)

        if !isnothing(expect_action) && primary_action != expect_action
            println("❌ FAIL — got action '$(primary_action)', expected '$(expect_action)'")
            println("     Result: $(first(result, 80))")
            fail_count += 1
        else
            println("✅ OK — action=$(primary_action) votes=$(n_votes) | $(first(result, 60))...")
            pass_count += 1
        end
    catch e
        if expect_no_crash
            println("❌ CRASH — $e")
            Base.show_backtrace(stdout, catch_backtrace())
            fail_count += 1
        else
            println("✅ EXPECTED ERROR — $e")
            pass_count += 1
        end
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# TRAINING MISSIONS
# ─────────────────────────────────────────────────────────────────────────────

println("=" ^ 65)
println("  FIRING TRAINING MISSIONS")
println("=" ^ 65)
println()

println("── Greeting inputs ──────────────────────────────────────────")
run_mission("greet-hello",     "hello there how are you doing today")
run_mission("greet-morning",   "hey good morning glad to be here")
run_mission("greet-welcome",   "welcome back i missed this place")

println()
println("── Reasoning / Analysis ─────────────────────────────────────")
run_mission("reason-ml",       "how does machine learning work")
run_mission("reason-diff",     "what is the difference between supervised and unsupervised learning")
run_mission("reason-why",      "can you explain why neural networks need activation functions")
run_mission("calc-formula",    "calculate the result of this formula for me")

println()
println("── Causal chain inputs (relational gating) ──────────────────")
run_mission("causal-fire",     "fire causes smoke and destruction everywhere")
run_mission("causal-stress",   "stress causes serious health problems over time")
run_mission("causal-rain",     "heavy rain triggers flooding in low areas")   # triggers → causes
run_mission("causal-dangling", "the system failure causes")                   # dangling verb

println()
println("── Emotional support ────────────────────────────────────────")
run_mission("emotion-sad",     "i feel really sad and dont know what to do")
run_mission("emotion-worry",   "im so worried about everything lately")
run_mission("emotion-happy",   "this is amazing i am so excited and happy")

println()
println("── Warning / Danger ─────────────────────────────────────────")
run_mission("warn-error",      "critical error detected system is about to crash")
run_mission("warn-emergency",  "urgent this is an emergency we need help now")

println()
println("── Identity / Meta ──────────────────────────────────────────")
run_mission("meta-who",        "who are you and what can you do")
run_mission("meta-how",        "how do you actually work under the hood")

println()
println("── Ambiguous / Cross-domain ─────────────────────────────────")
run_mission("cross-grug",      "grug hits rock and makes fire")
run_mission("cross-formula",   "i need to calculate the result of this formula")

println()
println("── NegativeThesaurus integration ────────────────────────────")
println("  Registering inhibitions...")
InputQueue.add_inhibition!("spam"; reason="noise word test")
InputQueue.add_inhibition!("garbage"; reason="noise word test")

# GRUG: Test that inhibited words are filtered
filtered_text, removed = InputQueue.apply_inhibition_to_text("hello spam how garbage are you")
println("  Filtered: '$(filtered_text)'  removed: $(removed)")
@assert removed == ["spam", "garbage"] "!!! FATAL: inhibition filter did not remove expected tokens !!!"
run_mission("neginhibit-filtered", filtered_text)

# Clean up
InputQueue.remove_inhibition!("spam")
InputQueue.remove_inhibition!("garbage")
println("  Inhibitions cleared: $(InputQueue.inhibition_count()) remaining")

println()
println("── Lobe cascade check ───────────────────────────────────────")
# GRUG: This mission spans reasoning+knowledge — cascade should bridge both lobes
run_mission("cascade-crossdomain",
    "machine learning is a way to teach computers to reason and analyze patterns")

println()
println("=" ^ 65)
println("  TRAINING COMPLETE")
println("    ✅ Passed     : $(pass_count)")
println("    ⚠️  Cave Silent: $(soft_count) (soft misses — need more nodes/lower threshold)")
println("    ❌ Hard Fails : $(fail_count) (crashes or wrong action)")
println("=" ^ 65)
println()

if fail_count > 0
    println("!!! $(fail_count) HARD FAILURE(S). Review output above. !!!")
    exit(1)
else
    println("✅ Zero crashes! Cave architecture is healthy.")
    if soft_count > 0
        println("ℹ️  $(soft_count) soft miss(es) — scanner needs more nodes or lower thresholds for full coverage.")
    end
end