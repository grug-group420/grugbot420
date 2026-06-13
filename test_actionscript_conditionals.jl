#!/usr/bin/env julia
# test_actionscript_conditionals.jl — v7.35 ActionScript conditional ops

const REPO_ROOT = joinpath(@__DIR__)

# Load SemanticVerbs from the real source
const _SV_PATH = joinpath(REPO_ROOT, "src", "SemanticVerbs.jl")
if isfile(_SV_PATH)
    include(_SV_PATH)
    using .SemanticVerbs
else
    error("SemanticVerbs.jl not found at $_SV_PATH")
end

# Load ActionScript
include(joinpath(REPO_ROOT, "src", "ActionScript.jl"))
using .ActionScript

# ── TEST HELPERS ───────────────────────────────────────────
n_pass = 0
n_fail = 0

function tcheck(name::String, result::Bool)
    global n_pass, n_fail
    if result
        n_pass += 1
        println("[$(n_pass + n_fail)] $name ... PASS")
    else
        n_fail += 1
        println("[$(n_pass + n_fail)] $name ... FAIL")
    end
end

# ── 1. ALL_OPS classification ──
tcheck("ALL_OPS includes IF WHEN UNLESS",
    "IF" in ActionScript.ALL_OPS && "WHEN" in ActionScript.ALL_OPS && "UNLESS" in ActionScript.ALL_OPS)

tcheck("ALL_OPS includes EQUALS CONTAINS PRESENT EMPTY HAS GT LT GTE LTE",
    all(op in ActionScript.ALL_OPS for op in
        ("EQUALS", "CONTAINS", "PRESENT", "EMPTY", "HAS", "GT", "LT", "GTE", "LTE")))

# ── 2. _split_args with nested parens ──
tcheck("_split_args: EQUALS(a, b) stays as one arg",
    length(ActionScript._split_args("EQUALS(a, b)")) == 1)

tcheck("_split_args: EQUALS(a, b), SAY(x), SAY(y) splits into 3",
    (parts = ActionScript._split_args("EQUALS(a, b), SAY(x), SAY(y)");
     length(parts) == 3 && strip(parts[1]) == "EQUALS(a, b)"))

tcheck("_split_args: simple a, b, c splits into 3",
    length(ActionScript._split_args("a, b, c")) == 3)

tcheck("_split_args: empty string returns empty vector",
    isempty(ActionScript._split_args("")))

# ── 3. Static template rejects conditionals ──
tcheck("Static template rejects IF",
    try; ActionScript._validate_template("IF(EQUALS(x, y), SAY(a), SAY(b))", :static); false
    catch; true; end)

tcheck("Static template rejects PRESENT",
    try; ActionScript._validate_template("PRESENT(x)", :static); false
    catch; true; end)

tcheck("Dynamic template accepts IF",
    try; ActionScript._validate_template("IF(EQUALS(x, y), SAY(a), SAY(b))", :dynamic); true
    catch; false; end)

# ── 4. Unknown op still rejected ──
tcheck("Unknown op BOGUS rejected in validation",
    try; ActionScript._validate_template("BOGUS(x)", :dynamic); false
    catch; true; end)

# ── 5. IF with EQUALS — true branch ──
tcheck("IF(EQUALS(date, date), SAY(yes), SAY(no)) → yes",
    ActionScript._eval_op_chain("IF(EQUALS(date, date), SAY(yes), SAY(no))") == "yes")

# ── 6. IF with EQUALS — false branch ──
tcheck("IF(EQUALS(date, time), SAY(yes), SAY(no)) → no",
    ActionScript._eval_op_chain("IF(EQUALS(date, time), SAY(yes), SAY(no))") == "no")

# ── 7. IF with no else ──
tcheck("IF(EQUALS(date, time), SAY(yes)) → empty",
    ActionScript._eval_op_chain("IF(EQUALS(date, time), SAY(yes))") == "")

# ── 8. WHEN — true ──
tcheck("WHEN(EQUALS(1, 1), SAY(triggered)) → triggered",
    ActionScript._eval_op_chain("WHEN(EQUALS(1, 1), SAY(triggered))") == "triggered")

# ── 9. WHEN — false ──
tcheck("WHEN(EQUALS(1, 2), SAY(not_triggered)) → empty",
    ActionScript._eval_op_chain("WHEN(EQUALS(1, 2), SAY(not_triggered))") == "")

# ── 10. UNLESS — inverse ──
tcheck("UNLESS(EQUALS(1, 2), SAY(triggered)) → triggered",
    ActionScript._eval_op_chain("UNLESS(EQUALS(1, 2), SAY(triggered))") == "triggered")

tcheck("UNLESS(EQUALS(1, 1), SAY(not_triggered)) → empty",
    ActionScript._eval_op_chain("UNLESS(EQUALS(1, 1), SAY(not_triggered))") == "")

# ── 11. CONTAINS predicate ──
tcheck("IF(CONTAINS(hello world, world), SAY(found), SAY(missing)) → found",
    ActionScript._eval_op_chain("IF(CONTAINS(hello world, world), SAY(found), SAY(missing))") == "found")

tcheck("IF(CONTAINS(hello world, xyz), SAY(found), SAY(missing)) → missing",
    ActionScript._eval_op_chain("IF(CONTAINS(hello world, xyz), SAY(found), SAY(missing))") == "missing")

# ── 12. PRESENT and EMPTY ──
tcheck("PRESENT(non-empty-string) → true",
    ActionScript._eval_predicate("PRESENT(non-empty-string)"))

tcheck("EMPTY(non-empty-string) → false",
    !ActionScript._eval_predicate("EMPTY(non-empty-string)"))

tcheck("PRESENT of fallback string → false",
    !ActionScript._is_present("(no recent context available)"))

tcheck("PRESENT of real string → true",
    ActionScript._is_present("The user said hello"))

# ── 13. Numeric comparisons ──
tcheck("GT(10, 5) → true", ActionScript._eval_predicate("GT(10, 5)"))
tcheck("GT(5, 10) → false", !ActionScript._eval_predicate("GT(5, 10)"))
tcheck("LT(5, 10) → true", ActionScript._eval_predicate("LT(5, 10)"))
tcheck("GTE(10, 10) → true", ActionScript._eval_predicate("GTE(10, 10)"))
tcheck("LTE(10, 10) → true", ActionScript._eval_predicate("LTE(10, 10)"))
tcheck("LT(10, 10) → false", !ActionScript._eval_predicate("LT(10, 10)"))

# ── 14. Numeric comparison in conditional ──
tcheck("IF(GT(10, 5), SAY(big), SAY(small)) → big",
    ActionScript._eval_op_chain("IF(GT(10, 5), SAY(big), SAY(small))") == "big")

# ── 15. HAS predicate ──
tcheck("HAS(date) → true (clock always available)",
    ActionScript._eval_predicate("HAS(date)"))

tcheck("HAS(recent) → false (no callback wired)",
    !ActionScript._eval_predicate("HAS(recent)"))

# ── 16. Nested conditional ──
tcheck("Nested IF: → deep",
    ActionScript._eval_op_chain("IF(EQUALS(1, 1), IF(EQUALS(2, 2), SAY(deep), SAY(no)), SAY(outer))") == "deep")

# ── 17. Predicate at top level returns string ──
tcheck("EQUALS(a, a) at top level → 'true'",
    ActionScript._eval_op_chain("EQUALS(a, a)") == "true")

tcheck("EQUALS(a, b) at top level → 'false'",
    ActionScript._eval_op_chain("EQUALS(a, b)") == "false")

# ── 18. RESOLVE inside conditional ──
tcheck("IF(HAS(date), SAY(RESOLVE(date)), SAY(No date)) → contains date",
    occursin(r"\d{4}-\d{2}-\d{2}",
        ActionScript._eval_op_chain("IF(HAS(date), SAY(RESOLVE(date)), SAY(No date))")))

# ── 19. register_action! with conditional ──
tcheck("register_action! with IF in :dynamic works",
    try;
        ActionScript.reset_action_registry!()
        ActionScript.register_action!(
            trigger_verb = "testcond",
            action_type = :dynamic,
            template = "IF(HAS(date), SAY(RESOLVE(date)), SAY(no date))",
            description = "Test conditional"
        )
        true
    catch; false; end)

# ── 20. register_action! with IF in :static fails ──
tcheck("register_action! with IF in :static throws",
    try;
        ActionScript.register_action!(
            trigger_verb = "badstatic",
            action_type = :static,
            template = "IF(EQUALS(a, b), SAY(x), SAY(y))",
            description = "Should fail"
        )
        false
    catch; true; end)

# ── 21. execute_action with conditional ──
tcheck("execute_action with IF + RESOLVE(date)",
    (ActionScript.reset_action_registry!();
     ActionScript.register_action!(
         trigger_verb = "whattime",
         action_type = :dynamic,
         template = "IF(HAS(date), SAY(RESOLVE(date)), SAY(I don't know))",
         description = "Date test"
     );
     occursin(r"\d{4}-\d{2}-\d{2}",
         ActionScript.execute_action(ActionScript.lookup_action("whattime"), Dict{String,Any}()))))

# ── 22. default_actions! includes new conditionals ──
tcheck("default_actions! registers remind/announce/recall/confirm",
    (ActionScript.reset_action_registry!();
     ActionScript.default_actions!();
     !isnothing(ActionScript.lookup_action("remind")) &&
     !isnothing(ActionScript.lookup_action("announce")) &&
     !isnothing(ActionScript.lookup_action("recall")) &&
     !isnothing(ActionScript.lookup_action("confirm"))))

# ── 23. Serialize/restore round-trip ──
tcheck("Serialize/restore round-trip preserves conditional template",
    (ActionScript.reset_action_registry!();
     ActionScript.register_action!(
         trigger_verb = "roundtrip",
         action_type = :dynamic,
         template = "IF(PRESENT({{target}}), SAY({{target}}), SAY(missing))",
         description = "Round-trip test"
     );
     serialized = ActionScript.serialize_registry();
     ActionScript.reset_action_registry!();
     ActionScript.restore_registry!(serialized);
     entry = ActionScript.lookup_action("roundtrip");
     !isnothing(entry) && occursin("IF(PRESENT", entry.template)))

# ── 24. Existing ops still work ──
tcheck("REPEAT(hello, 3) still works",
    ActionScript._eval_op_chain("REPEAT(hello, 3)") == "hello hello hello")

tcheck("SAY(hello world) still works",
    ActionScript._eval_op_chain("SAY(hello world)") == "hello world")

tcheck("RESOLVE(date) returns date",
    occursin(r"\d{4}-\d{2}-\d{2}", ActionScript.resolve_reference("date")))

# ── SUMMARY ──
println()
println("=" ^ 60)
if n_fail == 0
    println("ALL $(n_pass) ACTIONSCRIPT CONDITIONAL TESTS PASSED")
else
    println("$(n_pass) PASSED, $(n_fail) FAILED")
end
println("=" ^ 60)
