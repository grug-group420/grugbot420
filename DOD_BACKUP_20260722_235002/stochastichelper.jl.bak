# ==============================
# Stochastic Coinflip Header
# ==============================
module CoinFlipHeader

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║  ⚠️  ARCHITECTURE REMINDERS — READ THESE OR SUFFER                          ║
# ║                                                                              ║
# ║  1. ANTIMATCH NODES WERE REMOVED. They do not exist. Do not reference        ║
# ║     is_antimatch_node, antimatch scoring, antimatch drains, or any           ║
# ║     antimatch logic. That entire concept was deprecated and deleted.          ║
# ║     If you find yourself writing antimatch code, STOP — you are              ║
# ║     reimplementing a removed feature.                                        ║
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

using Distributions

# GRUG: Export the macro and the bias helper so tribe can use them.
export @coinflip, bias

# ============================
# === Core Data Structures ===
# ============================

# GRUG: This hold name of side of coin, how likely to land, and what to do.
struct CoinOutcome
    name::Symbol
    probability::Float64
    action::Function
end

# GRUG: This hold bias number. So we know it not just regular rock/number.
struct Bias
    value::Float64
end

# ============================
# === Utility Functions ======
# ============================

# GRUG: Make sure chance is real chance. No negative chance. No more than 100%.
function validate_prob(p::Float64)
    if p < 0.0 || p > 1.0
        throw(ArgumentError("Invalid probability $p. Must be 0.0 <= p <= 1.0"))
    end
    return p
end

# GRUG: If probabilities not equal 1 (100%), make them equal 1. 
# GRUG: So math rock (Distributions) not explode.
function normalize_probs(probs::Vector{Float64})
    total = sum(probs)
    if total == 0.0
        throw(ArgumentError("Sum of probabilities is zero! Coin stuck in air forever!"))
    end
    # GRUG: Return new list with fixed chances.
    return [p / total for p in probs]
end

# ============================
# === Bias Handling ==========
# ============================

# GRUG: Safe helper. No steal Base Julia functions (Type Piracy bad, make Julia angry).
# GRUG: Call bias(:Heads, 60) to get 60% chance.
bias(name::Symbol, p::Real) = (name, Bias(p / 100.0))

# GRUG: Look at item. If it has Bias, take number. If just name, assume 50/50.
function extract_prob(name_raw)
    if name_raw isa Tuple{Symbol, Bias}
        return Float64(name_raw[2].value)
    elseif name_raw isa Symbol
        return 0.5 # default 50/50 if no bias provided
    else
        throw(ArgumentError("Outcome must be Symbol or bias(:Sym, percent). Grug confused by: $name_raw"))
    end
end

# GRUG: Get name out of raw item safely.
function extract_name(name_raw)
    if name_raw isa Tuple{Symbol, Bias}
        return name_raw[1]
    elseif name_raw isa Symbol
        return name_raw
    else
        throw(ArgumentError("Cannot extract name. Wrong type."))
    end
end

# ============================
# === Core Coinflip Logic ====
# ============================

# GRUG: Throw coin in air. See where land. Do the action.
function run_coinflip(outcomes::Vector{CoinOutcome})
    probs = [o.probability for o in outcomes]
    probs = normalize_probs(probs)
    
    # GRUG: Roll categorical dice.
    outcome_idx = rand(Categorical(probs))
    outcome = outcomes[outcome_idx]
    
    # GRUG: Do the thing!
    outcome.action()
    return outcome.name
end

# GRUG: Throw coin many times. Keep list of if first outcome won.
function run_coinflips(outcomes::Vector{CoinOutcome}, n::Int)
    first_outcome_name = outcomes[1].name
    
    # GRUG: Pre-allocate list so memory fast. No push! (Push is slow).
    results = Vector{Bool}(undef, n)
    for i in 1:n
        result_name = run_coinflip(outcomes)
        results[i] = (result_name == first_outcome_name)
    end
    return results
end

# ============================
# === Coinflip Macro =========
# ============================

macro coinflip(expr)
    # GRUG: Escaping so macro not lose variables in own cave. Look in user cave.
    escaped_expr = esc(expr)
    
    quote
        try
            # GRUG: Read list user gave.
            raw_items = $escaped_expr
            if !(raw_items isa AbstractVector)
                throw(ArgumentError("Grug need array. Like [ :Heads => action ]"))
            end
            
            outcomes = CoinOutcome[]
            for item in raw_items
                # GRUG: Check if user actually gave a Pair (=>)
                if !(item isa Pair)
                    throw(ArgumentError("Each outcome must be `name => action`. Got rock instead."))
                end
                
                name_raw = item.first
                action_block = item.second
                
                # GRUG: Check if action is function
                if !(action_block isa Function)
                    throw(ArgumentError("Action must be function! Use `() -> do_thing()`"))
                end

                # GRUG: Extract safely
                prob = extract_prob(name_raw)
                name = extract_name(name_raw)
                
                push!(outcomes, CoinOutcome(name, validate_prob(prob), action_block))
            end
            
            # GRUG: Flip the coin!
            run_coinflip(outcomes)
        catch e
            # GRUG: If coin explode, tell exactly why. No hide.
            rethrow(ErrorException("Coinflip macro failed: $(sprint(showerror, e))"))
        end
    end
end

end # module CoinFlipHeader

# ==============================================================================
# ACADEMIC SUMMARY:
#
# 1. Type Piracy Eradication: Lexically scoped `bias(Symbol, Real)` constructor 
#    maintains Julia method table stability.
# 2. Pre-allocation Optimization: Inside `run_coinflips`, contiguous memory 
#    allocation `Vector{Bool}(undef, n)` replaces dynamic heap structures.
# 3. Defensive DSL Parsing: Macro scope strict type-checking ensures invalid syntax 
#    aborts safely prior to execution, propagating contextual stack traces.
# ==============================================================================