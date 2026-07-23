# test_input_decomposer_enhanced.jl - GRUG v10 Enhanced InputDecomposer Tests
# GRUG say: New conjunctions must split. New markers must detect. Conjugation
# must expand. Sigil boundary must separate arith from lang. Comma lookahead
# must see past "and". MLP must assist when confused. TEST EVERYTHING.

using Test
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║                                                                              ║
# ║  2. SIGILS CAN AND DO APPEAR IN RELATIONAL TRIPLES. A triple like           ║
# ║     (&n, is_greater_than, &n) is DYNAMIC — it evaluates at match time        ║
# ║     with sigil-bound values, NOT a fixed string comparison. Relational       ║
# ║     triples are not limited to literal words. Any triple field may            ║
# ║     contain &sigil tokens. Code that consumes triples MUST handle this.      ║
# ║     Forgetting this means you break arithmetic, comparisons, and             ║
# ║     any dynamic relational outcome.                                          ║
# ║                                                                              ║
# ║  3. HOPFIELD CACHING WAS REMOVED. The hopfield_key field on Node is         ║
# ║     a DEAD FIELD — it exists only for specimen save/load round-trip           ║
# ║     compatibility. Do not use it for caching, lookups, or any logic.         ║
# ║     Pattern scanning does NOT use hopfield caching. It was disabled          ║
# ║     ages ago. New code must never depend on hopfield_key.                    ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

module _DecomposerEnhancedParent
    include(joinpath(@__DIR__, "..", "src", "InputDecomposer.jl"))
end

using ._DecomposerEnhancedParent.InputDecomposer

println("🧪 Running Enhanced InputDecomposer tests...")

# =========================================================================
# HELPERS
# =========================================================================

"""Reset decomposer config to defaults before each test group."""
function _reset_config!()
    InputDecomposer.reset_config!()
end

"""Get texts from decomposition as a Set for easy checking."""
function _texts(subs::Vector{DecomposedSubSubject})::Set{String}
    return Set(strip(s.text) for s in subs)
end

"""Get group IDs from decomposition."""
function _group_ids(subs::Vector{DecomposedSubSubject})::Vector{String}
    return [s.multipart_group for s in subs]
end

"""Get roles from decomposition."""
function _roles(subs::Vector{DecomposedSubSubject})::Vector{Symbol}
    return [s.role for s in subs]
end

# =========================================================================
# EXPANDED SPLIT CONJUNCTIONS (v10 additions)
# =========================================================================

@testset "v10 — 'while' splits independent clauses" begin
    _reset_config!()
    subs = decompose_input("what is fire while what is ice")
    @test length(subs) == 2
    @test occursin("fire", lowercase(subs[1].text))
    @test occursin("ice", lowercase(subs[2].text))
    @test is_compound("what is fire while what is ice")
end

@testset "v10 — 'whilst' splits independent clauses" begin
    _reset_config!()
    subs = decompose_input("what is fire whilst what is ice")
    @test length(subs) == 2
    @test is_compound("what is fire whilst what is ice")
end

@testset "v10 — 'since' splits with clause structure on right" begin
    _reset_config!()
    subs = decompose_input("describe gravity since what is magnetism")
    @test length(subs) == 2
    @test is_compound("describe gravity since what is magnetism")
end

@testset "v10 — 'unless' splits with clause structure on right" begin
    _reset_config!()
    subs = decompose_input("explain thermodynamics unless calculate entropy")
    @test length(subs) == 2
    @test is_compound("explain thermodynamics unless calculate entropy")
end

@testset "v10 — 'except' splits with clause structure on right" begin
    _reset_config!()
    subs = decompose_input("compute velocity except define acceleration")
    @test length(subs) == 2
    @test is_compound("compute velocity except define acceleration")
end

@testset "v10 — 'plus' splits with clause structure on right" begin
    _reset_config!()
    subs = decompose_input("what is light plus what is sound")
    @test length(subs) == 2
    @test is_compound("what is light plus what is sound")
end

@testset "v10 — 'independently' splits" begin
    _reset_config!()
    subs = decompose_input("analyze data independently evaluate results")
    @test length(subs) == 2
    @test is_compound("analyze data independently evaluate results")
end

@testset "v10 — 'separately' splits" begin
    _reset_config!()
    subs = decompose_input("describe physics separately summarize chemistry")
    @test length(subs) == 2
    @test is_compound("describe physics separately summarize chemistry")
end

# =========================================================================
# EXPANDED COMPOUND PAIRS (v10 additions)
# =========================================================================

@testset "v10 — compound pair 'or else' splits" begin
    _reset_config!()
    subs = decompose_input("what is fire or else what is water")
    @test length(subs) == 2
    @test is_compound("what is fire or else what is water")
end

@testset "v10 — compound pair 'but rather' splits" begin
    _reset_config!()
    subs = decompose_input("what is fire but rather what is water")
    @test length(subs) == 2
    @test is_compound("what is fire but rather what is water")
end

@testset "v10 — compound pair 'but instead' splits" begin
    _reset_config!()
    subs = decompose_input("describe sun but instead describe moon")
    @test length(subs) == 2
    @test is_compound("describe sun but instead describe moon")
end

@testset "v10 — compound pair 'then additionally' splits" begin
    _reset_config!()
    subs = decompose_input("what is heat then additionally what is cold")
    @test length(subs) == 2
    @test is_compound("what is heat then additionally what is cold")
end

# =========================================================================
# EXPANDED QUESTION MARKERS (v10: auxiliary verbs)
# =========================================================================

@testset "v10 — 'can' as question marker triggers split" begin
    _reset_config!()
    subs = decompose_input("what is fire and can water boil")
    @test length(subs) == 2
    @test is_compound("what is fire and can water boil")
end

@testset "v10 — 'could' as question marker" begin
    _reset_config!()
    subs = decompose_input("could gravity change and what is mass")
    @test length(subs) == 2
end

@testset "v10 — 'would' as question marker" begin
    _reset_config!()
    subs = decompose_input("what is energy and would it transform")
    @test length(subs) == 2
end

@testset "v10 — 'do' as question marker" begin
    _reset_config!()
    subs = decompose_input("do stars shine and what are planets")
    @test length(subs) == 2
end

@testset "v10 — 'does' as question marker" begin
    _reset_config!()
    subs = decompose_input("what is heat and does ice melt")
    @test length(subs) == 2
end

@testset "v10 — 'is' as question marker (with 'and')" begin
    _reset_config!()
    # "is X and is Y" should split
    subs = decompose_input("what is fire and is water wet")
    @test length(subs) == 2
end

@testset "v10 — 'are' as question marker" begin
    _reset_config!()
    subs = decompose_input("what are rocks and are minerals dense")
    @test length(subs) == 2
end

@testset "v10 — 'was' as question marker" begin
    _reset_config!()
    subs = decompose_input("was it hot and what is temperature")
    @test length(subs) == 2
end

@testset "v10 — 'were' as question marker" begin
    _reset_config!()
    subs = decompose_input("were they fast and what is speed")
    @test length(subs) == 2
end

@testset "v10 — 'will' as question marker" begin
    _reset_config!()
    subs = decompose_input("what is time and will it end")
    @test length(subs) == 2
end

@testset "v10 — 'shall' as question marker" begin
    _reset_config!()
    subs = decompose_input("shall we proceed and what is the plan")
    @test length(subs) == 2
end

# =========================================================================
# EXPANDED COMMAND MARKERS + CONJUGATION RULES (v10)
# =========================================================================

@testset "v10 — 'compare' as command marker" begin
    _reset_config!()
    subs = decompose_input("compare heat and what is cold")
    @test length(subs) == 2
end

@testset "v10 — 'contrast' as command marker" begin
    _reset_config!()
    subs = decompose_input("describe light but contrast darkness")
    @test length(subs) == 2
end

@testset "v10 — 'analyze' as command marker" begin
    _reset_config!()
    subs = decompose_input("analyze data and what is statistics")
    @test length(subs) == 2
end

@testset "v10 — 'evaluate' as command marker" begin
    _reset_config!()
    subs = decompose_input("evaluate results and what is accuracy")
    @test length(subs) == 2
end

@testset "v10 — 'summarize' as command marker" begin
    _reset_config!()
    subs = decompose_input("summarize findings and what is conclusion")
    @test length(subs) == 2
end

@testset "v10 — 'determine' as command marker" begin
    _reset_config!()
    subs = decompose_input("determine value and what is measurement")
    @test length(subs) == 2
end

@testset "v10 — 'identify' as command marker" begin
    _reset_config!()
    subs = decompose_input("identify species and describe habitat")
    @test length(subs) == 2
end

@testset "v10 — 'convert' as command marker" begin
    _reset_config!()
    subs = decompose_input("convert units and what is metric")
    @test length(subs) == 2
end

@testset "v10 — 'translate' as command marker" begin
    _reset_config!()
    subs = decompose_input("translate text and what is language")
    @test length(subs) == 2
end

@testset "v10 — 'search' as command marker" begin
    _reset_config!()
    subs = decompose_input("search records and what is database")
    @test length(subs) == 2
end

@testset "v10 — 'lookup' as command marker" begin
    _reset_config!()
    subs = decompose_input("lookup definition and what is vocabulary")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'calculates' matches 'calculate' command" begin
    _reset_config!()
    # "calculates" should be recognized as a command marker via conjugation
    subs = decompose_input("calculates velocity and what is speed")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'described' matches 'describe' command" begin
    _reset_config!()
    subs = decompose_input("described weather also what is climate")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'explaining' matches 'explain' command" begin
    _reset_config!()
    subs = decompose_input("explaining physics and what is force")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'compares' matches 'compare' command" begin
    _reset_config!()
    subs = decompose_input("compares velocity and what is speed")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'analyzed' matches 'analyze' command" begin
    _reset_config!()
    subs = decompose_input("analyzed data and what is result")
    @test length(subs) == 2
end

@testset "v10 — conjugation: 'summarized' matches 'summarize' command" begin
    _reset_config!()
    subs = decompose_input("summarized report and what is summary")
    @test length(subs) == 2
end

# =========================================================================
# SIGIL-BOUNDARY SPLITTING (Strategy 4)
# =========================================================================

@testset "v10 — sigil boundary: arithmetic next to natural language" begin
    _reset_config!()
    subs = decompose_input("describe gravity 2+3 what is fire")
    @test length(subs) >= 2  # Should split arith zone from lang zone
    # At least one sub-subject should contain arithmetic
    texts = _texts(subs)
    has_arith = any(t -> occursin(r"2\+3", t), texts)
    @test has_arith
end

@testset "v10 — sigil boundary: pure arithmetic no split" begin
    _reset_config!()
    subs = decompose_input("2+3*4")
    @test length(subs) == 1  # Pure arithmetic, no lang zone → singleton
end

@testset "v10 — sigil boundary: compute arith then explain" begin
    _reset_config!()
    subs = decompose_input("compute 3*4+1 explain photosynthesis")
    @test length(subs) >= 2
end

@testset "v10 — sigil boundary: arith between two questions" begin
    _reset_config!()
    subs = decompose_input("what is gravity 5*7 what is fire")
    @test length(subs) >= 2
end

@testset "v10 — sigil boundary: too short for split" begin
    _reset_config!()
    # Less than 3 tokens → no split
    subs = decompose_input("2+3")
    @test length(subs) == 1
end

# =========================================================================
# ENHANCED COMMA LOOKAHEAD (v10)
# =========================================================================

@testset "v10 — comma lookahead: 'what is X, and what is Y'" begin
    _reset_config!()
    # The original comma split only checks the token RIGHT AFTER the comma.
    # "what is X, and what is Y" has "and" after comma, not a question marker.
    # The enhanced lookahead sees past "and" to find "what".
    subs = decompose_input("what is fire, and what is ice")
    @test length(subs) == 2
    @test occursin("fire", lowercase(subs[1].text))
    @test occursin("ice", lowercase(subs[2].text))
end

@testset "v10 — comma lookahead: 'what is X, or what is Y'" begin
    _reset_config!()
    subs = decompose_input("what is fire, or what is ice")
    @test length(subs) == 2
end

@testset "v10 — comma lookahead: 'what is X, but what is Y'" begin
    _reset_config!()
    subs = decompose_input("what is fire, but what is ice")
    @test length(subs) == 2
end

@testset "v10 — comma lookahead: 'what is X, also what is Y'" begin
    _reset_config!()
    subs = decompose_input("what is fire, also what is ice")
    @test length(subs) == 2
end

@testset "v10 — comma lookahead: 'what is X, then what is Y'" begin
    _reset_config!()
    subs = decompose_input("what is fire, then what is ice")
    @test length(subs) >= 2
end

@testset "v10 — comma lookahead: 'describe X, and also explain Y'" begin
    _reset_config!()
    # Two-level lookahead: "and" + "also" + command marker "explain"
    subs = decompose_input("describe gravity, and also explain magnetism")
    @test length(subs) == 2
end

@testset "v10 — comma lookahead: no split without clause after comma" begin
    _reset_config!()
    # "bread, butter and cheese" — "butter" is not a question/command marker
    subs = decompose_input("bread, butter and cheese")
    @test length(subs) == 1
    @test subs[1].role == :singleton
end

# =========================================================================
# MLP-ASSISTED DECOMPOSITION (Strategy 5)
# =========================================================================

@testset "v10 — MLP-assisted: low directive quality + high novelty triggers split" begin
    _reset_config!()
    # directive_quality < 0.35 AND novelty >= 0.70 → MLP-assisted decomposition
    subs = decompose_input_mlp("what is quantum physics and explain entanglement";
        mlp_directive_quality=0.2,  # below 0.35
        mlp_novelty=0.8,            # above 0.70
    )
    @test length(subs) >= 2
    @test subs[1].multipart_group != ""
end

@testset "v10 — MLP-assisted: high directive quality → no MLP split" begin
    _reset_config!()
    subs = decompose_input_mlp("what is quantum physics and explain entanglement";
        mlp_directive_quality=0.5,  # above 0.35 → not confused
        mlp_novelty=0.8,
    )
    @test length(subs) == 1
    @test subs[1].role == :singleton
end

@testset "v10 — MLP-assisted: low novelty → no MLP split" begin
    _reset_config!()
    subs = decompose_input_mlp("what is quantum physics and explain entanglement";
        mlp_directive_quality=0.2,  # confused
        mlp_novelty=0.5,            # but not novel enough (< 0.70)
    )
    @test length(subs) == 1
    @test subs[1].role == :singleton
end

@testset "v10 — MLP-assisted: both thresholds needed (AND not OR)" begin
    _reset_config!()
    # Case 1: only directive quality low, novelty OK → no split
    subs1 = decompose_input_mlp("compute force and describe motion";
        mlp_directive_quality=0.2,
        mlp_novelty=0.5,
    )
    @test length(subs1) == 1

    # Case 2: only novelty high, directive quality OK → no split
    subs2 = decompose_input_mlp("compute force and describe motion";
        mlp_directive_quality=0.5,
        mlp_novelty=0.9,
    )
    @test length(subs2) == 1

    # Case 3: both triggered → split
    subs3 = decompose_input_mlp("compute force and describe motion";
        mlp_directive_quality=0.2,
        mlp_novelty=0.9,
    )
    @test length(subs3) >= 2
end

@testset "v10 — MLP-assisted: max parts cap (MLP_COMPOUND_MAX_PARTS=4)" begin
    _reset_config!()
    # Input with 5+ conjunctions — should be capped at 4 parts
    subs = decompose_input_mlp("compute force and describe motion and explain energy and summarize findings and define mass";
        mlp_directive_quality=0.2,
        mlp_novelty=0.9,
    )
    @test length(subs) <= 4  # MLP_COMPOUND_MAX_PARTS
end

@testset "v10 — MLP-assisted: too short input → singleton" begin
    _reset_config!()
    # Less than 4 tokens → no MLP split
    subs = decompose_input_mlp("what and";
        mlp_directive_quality=0.2,
        mlp_novelty=0.9,
    )
    @test length(subs) == 1
end

@testset "v10 — MLP-assisted: uses broader conjunction set" begin
    _reset_config!()
    # "with" is in _MLP_AGGRESSIVE_CONJUNCTIONS but not in split_conjunctions
    subs = decompose_input_mlp("describe photosynthesis with explain cellular respiration";
        mlp_directive_quality=0.2,
        mlp_novelty=0.9,
    )
    @test length(subs) >= 2
end

@testset "v10 — MLP-assisted: threshold constants exported" begin
    @test InputDecomposer.MLP_COMPOUND_THRESHOLD ≈ 0.35 atol=0.01
    @test InputDecomposer.MLP_NOVELTY_COMPOUND_THRESHOLD ≈ 0.70 atol=0.01
    @test InputDecomposer.MLP_COMPOUND_MAX_PARTS == 4
end

# =========================================================================
# CONFIG MUTATION API (runtime editing)
# =========================================================================

@testset "v10 — add/remove split conjunction at runtime" begin
    _reset_config!()
    # Add "hence" as a new split conjunction
    result = add_split_conjunction!("hence")
    @test occursin("Added", result)

    # Now "hence" should trigger a split
    subs = decompose_input("what is fire hence what is ice")
    @test length(subs) == 2

    # Adding again is a no-op with warning
    result2 = add_split_conjunction!("hence")
    @test occursin("already", result2)

    # Remove it
    result3 = remove_split_conjunction!("hence")
    @test occursin("Removed", result3)

    # Now "hence" should NOT trigger a split anymore
    subs2 = decompose_input("what is fire hence what is ice")
    @test length(subs2) == 1  # back to singleton
end

@testset "v10 — add/remove compound pair at runtime" begin
    _reset_config!()
    result = add_compound_pair!("and", "therefore")
    @test occursin("Added", result) || occursin("Created", result)

    # "and therefore" should now be treated as compound conjunction
    subs = decompose_input("what is fire and therefore what is ice")
    @test length(subs) == 2

    # Remove it
    result2 = remove_compound_pair!("and", "therefore")
    @test occursin("Removed", result2)
end

@testset "v10 — add/remove question marker at runtime" begin
    _reset_config!()
    result = add_question_marker!("whether")
    @test occursin("Added", result)

    # "whether" should now be a question marker
    subs = decompose_input("whether fire burns and what is heat")
    @test length(subs) == 2

    # Remove it
    result2 = remove_question_marker!("whether")
    @test occursin("Removed", result2)
end

@testset "v10 — add/remove command marker with conjugation" begin
    _reset_config!()
    result = add_command_marker!("investigate", ["investigates", "investigated", "investigating"])
    @test occursin("Added", result)

    # "investigates" should now be recognized as a command marker
    subs = decompose_input("investigates crime and what is evidence")
    @test length(subs) == 2

    # Remove the command marker
    result2 = remove_command_marker!("investigate")
    @test occursin("Removed", result2)
end

@testset "v10 — add conjugation rule for existing stem" begin
    _reset_config!()
    # "calculate" already exists. Add a new conjugated form.
    result = add_conjugation_rule!("calculate", ["calculates", "calculated", "calculating", "calc"])
    @test occursin("Set", result)

    # "calc" should now match
    subs = decompose_input("calc velocity and what is speed")
    @test length(subs) == 2
end

@testset "v10 — set context conjunction" begin
    _reset_config!()
    # Default context conjunction is "and". Change to "plus".
    result = set_context_conjunction!("plus")
    @test occursin("changed", lowercase(result))

    # "plus" should now act like "and" — split when both sides have clause structure
    subs = decompose_input("what is fire plus what is ice")
    @test length(subs) == 2

    # Reset back
    _reset_config!()
    # After reset, "plus" is a split_conjunction (not context), still splits
    subs2 = decompose_input("what is fire plus what is ice")
    @test length(subs2) == 2
end

@testset "v10 — config status string" begin
    _reset_config!()
    status = config_status_string()
    @test occursin("SPLIT CONJUNCTIONS", status)
    @test occursin("COMPOUND PAIRS", status)
    @test occursin("CONTEXT CONJUNCTION", status)
    @test occursin("QUESTION MARKERS", status)
    @test occursin("COMMAND MARKERS", status)
    @test occursin("CONJUGATION RULES", status)
end

@testset "v10 — build_config from specimen dict" begin
    specimen = Dict{String,Any}(
        "decomposer_config" => Dict{String,Any}(
            "split_conjunctions" => ["also", "furthermore", "hence"],
            "question_markers" => ["what", "who", "how", "whether"],
            "command_markers" => ["tell", "explain", "investigate"],
            "conjugation_rules" => Dict{String,Any}(
                "investigate" => ["investigates", "investigated"],
            ),
        )
    )
    cfg = build_config(specimen)
    @test "hence" in cfg.split_conjunctions
    @test "whether" in cfg.question_markers
    @test "investigate" in cfg.command_markers
    @test "investigates" in cfg.expanded_command_markers
    @test "investigated" in cfg.expanded_command_markers
end

@testset "v10 — build_config with missing keys uses defaults" begin
    specimen = Dict{String,Any}(
        "decomposer_config" => Dict{String,Any}(
            "split_conjunctions" => ["also", "hence"],
            # Missing question_markers, command_markers, etc.
        )
    )
    cfg = build_config(specimen)
    @test "hence" in cfg.split_conjunctions
    # question_markers should fall back to defaults
    @test "what" in cfg.question_markers
    @test "who" in cfg.question_markers
end

@testset "v10 — build_config with no decomposer_config returns DEFAULT" begin
    specimen = Dict{String,Any}()
    cfg = build_config(specimen)
    @test cfg === DEFAULT_CONFIG
end

@testset "v10 — error on empty string inputs" begin
    _reset_config!()
    @test_throws ArgumentError add_split_conjunction!("")
    @test_throws ArgumentError remove_split_conjunction!("")
    @test_throws ArgumentError add_compound_pair!("", "then")
    @test_throws ArgumentError add_compound_pair!("and", "")
    @test_throws ArgumentError add_question_marker!("")
    @test_throws ArgumentError remove_question_marker!("")
    @test_throws ArgumentError add_command_marker!("")
    @test_throws ArgumentError set_context_conjunction!("")
end

@testset "v10 — error on removing nonexistent entries" begin
    _reset_config!()
    @test_throws ArgumentError remove_split_conjunction!("zzzznotexist")
    @test_throws ArgumentError remove_question_marker!("zzzznotexist")
    @test_throws ArgumentError remove_command_marker!("zzzznotexist")
    @test_throws ArgumentError remove_compound_pair!("zzzznotexist", "whatever")
end

# =========================================================================
# CHUNK BOUNDARIES
# =========================================================================

@testset "v10 — chunk_boundaries for singleton input" begin
    _reset_config!()
    chunks = chunk_boundaries("what is a rock")
    @test length(chunks) == 1
    @test chunks[1].first_token == 1
    @test chunks[1].chunk_index == 1
end

@testset "v10 — chunk_boundaries for compound input" begin
    _reset_config!()
    chunks = chunk_boundaries("what is fire also what is ice")
    @test length(chunks) == 2
    @test chunks[1].chunk_index == 1
    @test chunks[2].chunk_index == 2
end

@testset "v10 — chunk_boundaries for empty input" begin
    _reset_config!()
    chunks = chunk_boundaries("")
    @test length(chunks) == 1
end

# =========================================================================
# NEGATIVE CASES — things that should NOT split
# =========================================================================

@testset "v10 — no split: 'bread and butter' (no clause structure)" begin
    _reset_config!()
    subs = decompose_input("bread and butter")
    @test length(subs) == 1
end

@testset "v10 — no split: 'fire and ice' (no clause markers)" begin
    _reset_config!()
    subs = decompose_input("fire and ice")
    @test length(subs) == 1
end

@testset "v10 — no split: single question" begin
    _reset_config!()
    subs = decompose_input("what is a rock")
    @test length(subs) == 1
    @test subs[1].role == :singleton
    @test subs[1].multipart_group == ""
end

@testset "v10 — no split: 'while' without clause structure on right" begin
    _reset_config!()
    # "while running fast" has no question/command marker → no split
    subs = decompose_input("fire while running fast")
    @test length(subs) == 1
end

@testset "v10 — no split: 'since' without clause structure" begin
    _reset_config!()
    subs = decompose_input("happy since yesterday")
    @test length(subs) == 1
end

println("✅ All Enhanced InputDecomposer tests complete!")
