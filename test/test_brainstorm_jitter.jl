# test_brainstorm_jitter.jl
# ==============================================================================
# GRUG /brainstorm SCOPED HEAVY-JITTER TESTS
# ==============================================================================
# Verifies the v7.11 "far-jump, then snap-back" scope primitive:
# `with_brainstorm_jitter(f)` temporarily raises the value-jitter and
# coin-threshold ratios to their brainstorm defaults for the duration of a
# single scope, then restores the previous ratios bit-exact on every exit
# path (normal, exceptional, early-return).
#
# Test groups:
#   [A] Normal enter/exit: ratios raised inside, restored outside.
#   [B] Exception inside scope: ratios still restored, exception rethrown.
#   [C] Nested scope: second entry throws JitterScopeError; outer scope
#       state remains intact; outer exits cleanly.
#   [D] Custom ratios: caller-supplied `ratio` / `coin_ratio` used inside,
#       both respected within hard caps.
#   [E] Invalid ratios: NaN / Inf / out-of-range raise JitterError BEFORE
#       any state mutation (saved state stays untouched).
#   [F] Disabled-jitter interaction: brainstorm does NOT force jitter on.
#       With jitter globally disabled, jittered primitives are still
#       identity inside the scope, and ratio state still restores.
#   [G] Value magnitude widens inside scope: a single jittered value in
#       brainstorm scope can exceed the default-ratio window but stays
#       inside the brainstorm-ratio window. Statistical check, not exact.
#   [H] is_brainstorm_active / get_brainstorm_depth sanity across the
#       lifecycle.
#
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test
using Random

println("\n" * "="^60)
println("GRUG /brainstorm SCOPED HEAVY-JITTER TESTS")
println("="^60)

include("../src/RelationalJitter.jl")
using .RelationalJitter

# ==============================================================================
# HELPERS
# ==============================================================================

# GRUG: Reset all jitter state at the start of each group so earlier groups
# cannot contaminate later ones. Brainstorm depth must be zero, ratios at
# defaults, jitter enabled.
function fresh_jitter!()
    # GRUG: If somehow a previous test left depth > 0 we cannot call the
    # scope-aware setters safely without clearing first. The test file
    # doesn't exercise that path, but we defend anyway: force-reset via
    # direct setters.
    enable_jitter!()
    set_jitter_ratio!(JITTER_RATIO_DEFAULT)
    set_jitter_coin_ratio!(JITTER_COIN_RATIO_DEFAULT)
    @assert get_brainstorm_depth() == 0 "brainstorm depth leaked across tests: $(get_brainstorm_depth())"
end

# ==============================================================================
# [A] NORMAL ENTER/EXIT
# ==============================================================================

println("\n[A] Normal enter/exit contract")

fresh_jitter!()

@test get_jitter_ratio()      == JITTER_RATIO_DEFAULT
@test get_jitter_coin_ratio() == JITTER_COIN_RATIO_DEFAULT
@test !is_brainstorm_active()
@test get_brainstorm_depth() == 0
println("  ✓ pre-scope state: defaults, inactive, depth=0")

# GRUG: Capture ratios inside the scope so we can assert on them after exit.
inside_ratio       = Ref{Float64}(-1.0)
inside_coin_ratio  = Ref{Float64}(-1.0)
inside_active      = Ref{Bool}(false)
inside_depth       = Ref{Int}(-1)

result = with_brainstorm_jitter() do
    inside_ratio[]      = get_jitter_ratio()
    inside_coin_ratio[] = get_jitter_coin_ratio()
    inside_active[]     = is_brainstorm_active()
    inside_depth[]      = get_brainstorm_depth()
    return "mission_return_value"
end

@test inside_ratio[]      == JITTER_BRAINSTORM_RATIO
@test inside_coin_ratio[] == JITTER_BRAINSTORM_COIN_RATIO
@test inside_active[]     == true
@test inside_depth[]      == 1
println("  ✓ inside scope: ratio=$(JITTER_BRAINSTORM_RATIO), coin=$(JITTER_BRAINSTORM_COIN_RATIO), active=true, depth=1")

@test result == "mission_return_value"
println("  ✓ with_brainstorm_jitter returns the body's return value")

@test get_jitter_ratio()      == JITTER_RATIO_DEFAULT
@test get_jitter_coin_ratio() == JITTER_COIN_RATIO_DEFAULT
@test !is_brainstorm_active()
@test get_brainstorm_depth() == 0
println("  ✓ post-scope state: ratios restored bit-exact, depth=0")

# ==============================================================================
# [B] EXCEPTION INSIDE SCOPE — FINALLY STILL RESTORES
# ==============================================================================

println("\n[B] Exception inside scope still restores state")

fresh_jitter!()

struct BrainstormTestError <: Exception end

@test_throws BrainstormTestError with_brainstorm_jitter() do
    @test is_brainstorm_active()
    @test get_jitter_ratio() == JITTER_BRAINSTORM_RATIO
    throw(BrainstormTestError())
end
println("  ✓ exception inside scope rethrown unchanged")

# GRUG: Post-throw state must be fully reset. This is the strongest
# correctness requirement of the scope primitive.
@test get_jitter_ratio()      == JITTER_RATIO_DEFAULT
@test get_jitter_coin_ratio() == JITTER_COIN_RATIO_DEFAULT
@test !is_brainstorm_active()
@test get_brainstorm_depth() == 0
println("  ✓ post-throw state: ratios restored, depth=0 (finally block fired)")

# ==============================================================================
# [C] NESTED SCOPE REFUSED
# ==============================================================================

println("\n[C] Nested scope throws JitterScopeError")

fresh_jitter!()

# GRUG: Use Ref to smuggle the inner throw's state back out so we can
# assert the outer scope saw a proper throw, not a silent coalesce.
outer_caught_nested = Ref{Bool}(false)

with_brainstorm_jitter() do
    # GRUG: Outer scope active. Depth=1. Any second entry MUST throw.
    @test is_brainstorm_active()
    @test get_brainstorm_depth() == 1

    try
        with_brainstorm_jitter() do
            # GRUG: If we reach here, nesting silently coalesced — test
            # fails loudly so we notice immediately.
            error("nested scope silently accepted — contract violation")
        end
    catch e
        # GRUG: Only JitterScopeError is an acceptable catch here.
        if e isa JitterScopeError
            outer_caught_nested[] = true
        else
            rethrow(e)
        end
    end

    # GRUG: After the nested refusal, outer scope state must still be
    # intact — the failed entry mutated nothing.
    @test is_brainstorm_active()
    @test get_brainstorm_depth() == 1
    @test get_jitter_ratio() == JITTER_BRAINSTORM_RATIO
end

@test outer_caught_nested[] == true
println("  ✓ nested with_brainstorm_jitter throws JitterScopeError")

# GRUG: Outer scope exits cleanly even after the nested refusal.
@test get_jitter_ratio()      == JITTER_RATIO_DEFAULT
@test get_jitter_coin_ratio() == JITTER_COIN_RATIO_DEFAULT
@test get_brainstorm_depth() == 0
println("  ✓ outer scope exits cleanly after rejecting nested attempt")

# ==============================================================================
# [D] CUSTOM RATIOS
# ==============================================================================

println("\n[D] Caller-supplied ratios respected")

fresh_jitter!()

with_brainstorm_jitter(ratio = 0.05, coin_ratio = 0.02) do
    @test get_jitter_ratio()      == 0.05
    @test get_jitter_coin_ratio() == 0.02
    @test is_brainstorm_active()
end

@test get_jitter_ratio()      == JITTER_RATIO_DEFAULT
@test get_jitter_coin_ratio() == JITTER_COIN_RATIO_DEFAULT
println("  ✓ custom ratios applied inside scope and restored on exit")

# ==============================================================================
# [E] INVALID RATIOS REJECTED BEFORE STATE MUTATION
# ==============================================================================

println("\n[E] Invalid ratios raise JitterError BEFORE mutating state")

fresh_jitter!()

# GRUG: Each invalid-ratio call must leave state untouched. We snapshot
# state before, assert the throw, then assert state unchanged.
pre_ratio      = get_jitter_ratio()
pre_coin_ratio = get_jitter_coin_ratio()
pre_depth      = get_brainstorm_depth()

@test_throws JitterError with_brainstorm_jitter(ratio = NaN) do
    error("should not be called")
end
@test get_jitter_ratio()      == pre_ratio
@test get_jitter_coin_ratio() == pre_coin_ratio
@test get_brainstorm_depth()  == pre_depth

@test_throws JitterError with_brainstorm_jitter(ratio = Inf) do
    error("should not be called")
end
@test get_jitter_ratio() == pre_ratio

@test_throws JitterError with_brainstorm_jitter(ratio = -0.01) do
    error("should not be called")
end
@test get_jitter_ratio() == pre_ratio

@test_throws JitterError with_brainstorm_jitter(ratio = 0.11) do  # > JITTER_RATIO_MAX = 0.10
    error("should not be called")
end
@test get_jitter_ratio() == pre_ratio

@test_throws JitterError with_brainstorm_jitter(coin_ratio = NaN) do
    error("should not be called")
end
@test get_jitter_coin_ratio() == pre_coin_ratio

@test_throws JitterError with_brainstorm_jitter(coin_ratio = 0.11) do
    error("should not be called")
end
@test get_jitter_coin_ratio() == pre_coin_ratio

@test get_brainstorm_depth() == 0
println("  ✓ NaN/Inf/negative/over-cap ratios all raise JitterError")
println("  ✓ state unchanged after every rejected call (no partial mutation)")

# ==============================================================================
# [F] BRAINSTORM DOES NOT FORCE JITTER ON
# ==============================================================================

println("\n[F] Brainstorm is orthogonal to the global enable toggle")

fresh_jitter!()
disable_jitter!()

@test !is_jitter_enabled()

with_brainstorm_jitter() do
    # GRUG: Inside the scope, ratios are raised to brainstorm values, but
    # because jitter is globally disabled, every jitter_* primitive still
    # returns identity. The two features are independent by design:
    # brainstorm controls MAGNITUDE, enable flag controls ON/OFF.
    @test is_brainstorm_active()
    @test get_jitter_ratio() == JITTER_BRAINSTORM_RATIO  # state says "brainstorm"
    @test jitter_value(5.0) == 5.0                     # but disabled wins
    @test jitter_coin_threshold(0.5) == 0.5
end

@test get_jitter_ratio() == JITTER_RATIO_DEFAULT
@test !is_jitter_enabled()  # GRUG: scope exit does NOT re-enable jitter
println("  ✓ disabled jitter stays identity inside brainstorm scope")
println("  ✓ scope exit does NOT re-enable the global toggle")

enable_jitter!()

# ==============================================================================
# [G] VALUE MAGNITUDE WIDENS INSIDE SCOPE
# ==============================================================================

println("\n[G] Jittered value spread widens inside brainstorm scope")

fresh_jitter!()

# GRUG: Sample enough jittered values to get a tight empirical range.
# With default ratio 0.03 on value 5.0, span = 0.15 per side.
# With brainstorm ratio 0.08, span = 0.40 per side.
# We verify:
#   (a) Outside scope: max |δ| observed over N samples stays ≤ 0.15·(1+ε).
#   (b) Inside scope: max |δ| observed can exceed 0.15 (often does).
# We don't assert (b) as a hard must, we assert the spread inside is larger
# in expectation than the spread outside.

function max_abs_delta(x0::Float64, n::Int)
    mx = 0.0
    for i in 1:n
        Random.seed!(i * 7919)
        d = abs(jitter_value(x0) - x0)
        if d > mx
            mx = d
        end
    end
    Random.seed!()
    return mx
end

x0 = 5.0
n  = 4000

outside_max = max_abs_delta(x0, n)
inside_max  = with_brainstorm_jitter() do
    max_abs_delta(x0, n)
end

# GRUG: Hard upper bound outside scope: ratio · |x| = 0.15. Add tiny fp slack.
@test outside_max <= JITTER_RATIO_DEFAULT * abs(x0) + 1e-9
# GRUG: Hard upper bound inside scope: brainstorm ratio · |x| = 0.40.
@test inside_max <= JITTER_BRAINSTORM_RATIO * abs(x0) + 1e-9
# GRUG: Inside-scope max must EXCEED outside-scope max by a healthy margin.
# With n=4000 the empirical max gets very close to the theoretical cap on
# both sides, so the ratio of maxes should approach brainstorm/default =
# 0.08/0.03 ≈ 2.67. We accept anything above 1.8 as "clearly wider".
@test inside_max > outside_max * 1.8
println("  ✓ outside-scope |δ| max over $n samples = $(round(outside_max; digits=4))")
println("  ✓ inside-scope  |δ| max over $n samples = $(round(inside_max;  digits=4))")
println("  ✓ brainstorm scope widens jitter window as designed (>1.8× factor)")

# ==============================================================================
# [H] DEPTH / ACTIVE STATE LIFECYCLE
# ==============================================================================

println("\n[H] Lifecycle of is_brainstorm_active / get_brainstorm_depth")

fresh_jitter!()

@test !is_brainstorm_active()
@test get_brainstorm_depth() == 0

with_brainstorm_jitter() do
    @test is_brainstorm_active()
    @test get_brainstorm_depth() == 1
end

@test !is_brainstorm_active()
@test get_brainstorm_depth() == 0

# GRUG: Re-entry after clean exit must work. Depth counter is not sticky.
with_brainstorm_jitter() do
    @test get_brainstorm_depth() == 1
end
@test get_brainstorm_depth() == 0
println("  ✓ active/depth toggle correctly across enter/exit/re-enter")

# GRUG: After an exception, re-entry must also work — finally block reset
# the depth counter, so a fresh scope opens cleanly.
try
    with_brainstorm_jitter() do
        throw(BrainstormTestError())
    end
catch
    # swallow — we only care that the NEXT enter is clean
end
@test get_brainstorm_depth() == 0
with_brainstorm_jitter() do
    @test get_brainstorm_depth() == 1
end
@test get_brainstorm_depth() == 0
println("  ✓ re-entry after exceptional exit also works")

# ==============================================================================
# SUMMARY
# ==============================================================================

println("\n" * "="^60)
println("ALL /brainstorm JITTER TESTS PASSED! 8 test groups complete.")
println("Scope primitive verified:")
println("  [A] normal enter/exit with ratio swap")
println("  [B] exception propagation with state restore")
println("  [C] nested scope refused via JitterScopeError")
println("  [D] custom ratios honored")
println("  [E] invalid ratios rejected before state mutation")
println("  [F] orthogonal to global enable toggle")
println("  [G] jitter window widens inside scope (>1.8× factor)")
println("  [H] depth/active lifecycle correct across re-entry")
println("="^60)