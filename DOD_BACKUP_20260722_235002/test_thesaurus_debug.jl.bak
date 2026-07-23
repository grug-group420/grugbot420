# Quick debug: test _vote_word_swap on the fire claim_raw
using Pkg
Pkg.activate("/workspace/grugbot420")

# We need to load just enough to test
import Main as M

# Actually let's just simulate what _vote_word_swap does manually
sentence = "Oxygen combines with fuel and releases energy as heat and light. Grug learned to tame fire long ago. Fire is both creator and destroyer. It warms the cave but devours the forest. Grug speak of fire."

tokens = split(sentence)
println("=== Tokens ($(length(tokens))) ===")
for (j, tok) in enumerate(tokens)
    println("  [$j] '$tok'")
end

println()
