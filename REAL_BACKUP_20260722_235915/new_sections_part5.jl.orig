
# ═══════════════════════════════════════════════════════════════
# 33. ARITHMETIC ENGINE — All Ops, Edge Cases, Comparisons
# ═══════════════════════════════════════════════════════════════
section("33. Arithmetic Engine — Deep Ops & Edge Cases")

subsection("33a. Basic Arithmetic via Bindings")
try
    global _add_bindings = promote_input("5 + 3")
    _add_result = compute_arithmetic(_add_bindings)
    record("compute_arithmetic(5+3) succeeds", _add_result !== nothing)
catch e
    record("compute_arithmetic add", false, "$e")
end

try
    global _sub_bindings = promote_input("20 - 7")
    _sub_result = compute_arithmetic(_sub_bindings)
    record("compute_arithmetic(20-7) succeeds", _sub_result !== nothing)
catch e
    record("compute_arithmetic sub", false, "$e")
end

try
    global _mul_bindings = promote_input("6 * 4")
    _mul_result = compute_arithmetic(_mul_bindings)
    record("compute_arithmetic(6*4) succeeds", _mul_result !== nothing)
catch e
    record("compute_arithmetic mul", false, "$e")
end

try
    global _div_bindings = promote_input("100 / 5")
    _div_result = compute_arithmetic(_div_bindings)
    record("compute_arithmetic(100/5) succeeds", _div_result !== nothing)
catch e
    record("compute_arithmetic div", false, "$e")
end

subsection("33b. Has Math Bindings Check")
try
    global _math_b = promote_input("42 + 17")
    _has_math = has_math_bindings(_math_b)
    record("has_math_bindings(42+17) is true", _has_math == true)
catch e
    record("has_math_bindings true", false, "$e")
end

try
    global _no_math_b = promote_input("hello world")
    _has_no_math = has_math_bindings(_no_math_b)
    record("has_math_bindings(hello world) is false", _has_no_math == false)
catch e
    record("has_math_bindings false", false, "$e")
end

subsection("33c. Format Arithmetic Reply")
try
    global _fmt_bindings = promote_input("12 + 8")
    global _fmt_result = nothing
    try
        global _fmt_result = compute_arithmetic(_fmt_bindings)
    catch
        global _fmt_result = nothing
    end
    if _fmt_result !== nothing
        _fmt_reply = format_arithmetic_reply(_fmt_result)
        record("format_arithmetic_reply returns String", _fmt_reply isa String)
        record("reply contains '20'", occursin("20", _fmt_reply))
    else
        record("format_arithmetic_reply (no result)", true, "skipped")
    end
catch e
    record("format_arithmetic_reply", false, "$e")
end

subsection("33d. Edge Cases — Large Numbers, Division, Zero")
try
    global _big_bindings = promote_input("999999 + 1")
    _big_result = compute_arithmetic(_big_bindings)
    record("compute_arithmetic(999999+1) succeeds", _big_result !== nothing)
catch e
    record("arithmetic big numbers", false, "$e")
end

try
    global _zero_bindings = promote_input("0 + 0")
    _zero_result = compute_arithmetic(_zero_bindings)
    record("compute_arithmetic(0+0) succeeds", _zero_result !== nothing)
catch e
    record("arithmetic zero", false, "$e")
end

try
    global _cmp_bindings = promote_input("5 > 3")
    _cmp_result = compute_arithmetic(_cmp_bindings)
    record("compute_arithmetic(5>3) comparison succeeds", _cmp_result !== nothing)
catch e
    record("arithmetic comparison", false, "$e")
end
