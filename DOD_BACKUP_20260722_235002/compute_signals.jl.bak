# Compute correct signal vectors for all node patterns
using Pkg
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
Pkg.activate(".")

# Only need the hash function, not the whole engine
function words_to_signal(text::String)::Vector{Float64}
    tokens = split(lowercase(strip(text)))
    if isempty(tokens)
        error("empty text")
    end
    signal = Float64[]
    for tok in tokens
        val = Float64(hash(tok)) / Float64(typemax(UInt64))
        push!(signal, val)
    end
    return signal
end

patterns = [
    "derivative",
    "integral",
    "pythagorean theorem",
    "what is consciousness",
    "meaning of life",
    "free will",
    "danger",
    "hide and seek",
    "fight back",
    "i feel sad",
    "i feel anxious",
    "validate my feelings",
    "write a poem",
    "tell me a story",
    "imagine",
    "hello",
    "what time is it",
    "what happened before",
    "ignore mathematics",
    "stop empathy",
    "sunset image",
    "watch out",
    "why does",
    "obsolete test pattern",
    "sacred knowledge",
]

using JSON

results = Dict{String, Vector{Float64}}()
for p in patterns
    sig = words_to_signal(p)
    results[p] = sig
    println("$(repr(p)): $(length(sig)) tokens → $(sig)")
end

# Also compute signals for the action packets
action_packets = [
    "reason", "greet", "flee", "explain", "comfort", "alert", "inquire"
]
for a in action_packets
    sig = words_to_signal(a)
    results[a] = sig
    println("action:$(repr(a)): $(length(sig)) tokens → $(sig)")
end

# Save to JSON
open("specimens/signal_map.json", "w") do f
    JSON.print(f, results, 2)
end
println("\nSaved signal_map.json")
