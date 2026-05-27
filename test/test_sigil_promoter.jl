# test/test_sigil_promoter.jl
# ==============================================================================
# Tests for SigilPromoter — Stage 1.5a Front-Door Input Promoter
# ==============================================================================
# GRUG: covers EVERY locked-in design point:
#   - canonicalize_token: number-words 0–100, op-words, casing, strip,
#     unknown tokens pass through.
#   - _tokenize: digits-and-ops with no spaces ("2+2"), signed numerics,
#     decimals, words with apostrophes/hyphens, existing sigil tokens preserved.
#   - promote_input happy paths:
#       * "2 + 2"                                        -> "&n &op &n"
#       * "two plus two"                                 -> "&n &op &n"
#       * "2 plus two"                                   -> "&n &op &n"
#       * "WHAT is TWO Plus 2"                           -> "what is &n &op &n"
#       * "negative three" / "positive seven"            -> "&n=-3" / "&n=+7"
#       * decimals "2.5 plus 1.5"                        -> &n=2.5 &op=+ &n=1.5
#       * specimen-defined macro promotion (&color)
#   - promote_input fast path:
#       * "hello world"                  -> ("hello world", [])
#       * "" empty                       -> ("", [])
#       * "the cat sat"                  -> joined as-is, [])
#   - promote_input idempotency:
#       * promote(promote(x).rewritten).rewritten == promote(x).rewritten
#       * already-present "&n" tokens preserved verbatim
#   - bindings shape:
#       * Vector{SigilBinding} ordered by position (left-to-right capture)
#       * SigilBinding fields all populated
#       * bindings_by_name view groups correctly, preserving in-name order
#   - error paths:
#       * registry has a promotable sigil with unknown sigil_type -> PromoterConfigError
#   - registry interaction:
#       * default_registry has &n and &op promote-eligible
#       * specimen-overridden &noun promotes lexicon members
#   - confidence-equivalence test (the structural compression promise):
#       * pure-text input produces an unchanged matcher-input string
#         (the input is what scan_specimens would have seen pre-promoter).
#
# No silent failures: every error branch is asserted with @test_throws on
# the specific error type. Discipline mirrors SelfObserver and SigilRegistry.
# ==============================================================================

using Test

# GRUG: load the modules directly (test files run as isolated subprocesses,
# same pattern as test_self_observer.jl and test_sigil_registry.jl).
# SigilPromoter uses `using ..SigilRegistry`, so it expects to live inside
# a parent module that has SigilRegistry as a sibling. We construct that
# parent module here so the include works exactly like it does inside
# GrugBot420.
const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))

module _PromoterTestParent
    include(joinpath(@__DIR__, "..", "src", "SigilRegistry.jl"))
    include(joinpath(@__DIR__, "..", "src", "SigilPromoter.jl"))
    using .SigilRegistry
    using .SigilPromoter
end

# GRUG: pull names from BOTH submodules into the test scope so the @testset
# bodies can reference them unqualified.
using ._PromoterTestParent.SigilRegistry
using ._PromoterTestParent.SigilPromoter

@testset "SigilPromoter — full surface" begin

    # ==========================================================================
    @testset "canonicalize_token — closed maps" begin
        # Number-words.
        @test canonicalize_token("two")      == "2"
        @test canonicalize_token("Two")      == "2"
        @test canonicalize_token("TWO")      == "2"
        @test canonicalize_token("  two  ")  == "2"
        @test canonicalize_token("zero")     == "0"
        @test canonicalize_token("nineteen") == "19"
        @test canonicalize_token("hundred")  == "100"

        # Op-words.
        @test canonicalize_token("plus")        == "+"
        @test canonicalize_token("PLUS")        == "+"
        @test canonicalize_token("minus")       == "-"
        @test canonicalize_token("times")       == "*"
        @test canonicalize_token("multiplied")  == "*"
        @test canonicalize_token("divided")     == "/"
        @test canonicalize_token("over")        == "/"
        @test canonicalize_token("equals")      == "="
        @test canonicalize_token("equal")       == "="

        # Pass-through (unknown tokens are case-folded but not rewritten).
        @test canonicalize_token("the")     == "the"
        @test canonicalize_token("HELLO")   == "hello"
        @test canonicalize_token("2")       == "2"   # already canonical
        @test canonicalize_token("+")       == "+"   # already canonical
        @test canonicalize_token("")        == ""    # empty stays empty

        # "is" is INTENTIONALLY not in the op-word map (Stage 1.5a parks it).
        @test canonicalize_token("is") == "is"
    end

    # ==========================================================================
    @testset "promote_input — canonical math shapes converge" begin
        t = default_registry()

        # The headline win: every variant of "what is 2 + 2" lands in the
        # same matcher input with the same bindings.
        variants = [
            "what is 2 + 2",
            "what is 2+2",          # no spaces around op
            "what is two plus two",
            "what is 2 plus two",
            "what is two plus 2",
            "WHAT is TWO Plus 2",
            "  what is  2  +  2  ",  # extra whitespace
        ]

        # Reference output: compute once on the first variant.
        ref_rewritten, ref_bindings = promote_input(t, variants[1])
        @test ref_rewritten == "what is &n &op &n"
        @test length(ref_bindings) == 3
        @test ref_bindings[1].name == "n"  && ref_bindings[1].value == 2
        @test ref_bindings[2].name == "op" && ref_bindings[2].value == "+"
        @test ref_bindings[3].name == "n"  && ref_bindings[3].value == 2

        # All other variants must produce IDENTICAL rewritten + bindings.
        for v in variants[2:end]
            r, b = promote_input(t, v)
            @test r == ref_rewritten
            @test length(b) == length(ref_bindings)
            for (i, (got, want)) in enumerate(zip(b, ref_bindings))
                @test got.position == want.position
                @test got.name == want.name
                @test got.value == want.value
                @test got.class == want.class
            end
        end
    end

    # ==========================================================================
    @testset "promote_input — sign-prefix peek" begin
        t = default_registry()

        # "negative three" merges into a single &n binding with value -3.
        r, b = promote_input(t, "compute negative three")
        @test r == "compute &n"
        @test length(b) == 1
        @test b[1].name  == "n"
        @test b[1].value == -3

        # "positive seven" merges into +7. The signed numeric still parses
        # to Int 7 (the "+" is consumed; the sign is only meaningful for "-").
        r, b = promote_input(t, "give me positive seven")
        @test r == "give me &n"
        @test length(b) == 1
        @test b[1].value == 7

        # Sign prefix only fires when followed by a numeric; otherwise it
        # passes through as a literal.
        r, b = promote_input(t, "negative thoughts")
        @test r == "negative thoughts"
        @test isempty(b)

        # Sign prefix immediately before a digit-numeric.
        r, b = promote_input(t, "negative 5 plus 2")
        @test r == "&n &op &n"
        @test [bb.value for bb in b] == [-5, "+", 2]
    end

    # ==========================================================================
    @testset "promote_input — decimals" begin
        t = default_registry()
        r, b = promote_input(t, "2.5 plus 1.5")
        @test r == "&n &op &n"
        @test length(b) == 3
        @test b[1].value == 2.5
        @test b[2].value == "+"
        @test b[3].value == 1.5
        @test b[1].value isa Float64
        @test b[3].value isa Float64
    end

    # ==========================================================================
    @testset "promote_input — fast path (no promotion)" begin
        t = default_registry()

        # Pure-text inputs return the joined-tokens string with empty bindings.
        # Punctuation is dropped at the tokenizer (matcher already strips it).
        cases = [
            ("hello world", "hello world"),
            ("the cat sat on the mat", "the cat sat on the mat"),
            ("",  ""),
            ("   ",  ""),
        ]
        for (input, expected) in cases
            r, b = promote_input(t, input)
            @test r == expected
            @test isempty(b)
        end
    end

    # ==========================================================================
    @testset "promote_input — idempotency" begin
        t = default_registry()

        # Already-promoted sigil tokens pass through.
        r1, b1 = promote_input(t, "what is 2 + 2")
        r2, b2 = promote_input(t, r1)
        @test r1 == r2

        # The second call sees `&n &op &n` literally — no values to capture
        # there (no raw numbers/ops), so bindings is empty on the second call.
        # This is the correct semantics: bindings are derived from RAW input,
        # not from already-canonical input.
        @test isempty(b2)

        # And running it a third time is still stable.
        r3, _ = promote_input(t, r2)
        @test r3 == r2

        # Mixed: input has both already-promoted tokens and raw tokens.
        r, b = promote_input(t, "give me &n then 5 plus 3")
        @test occursin("&n", r)
        # The `5` and `plus` and `3` should still get promoted.
        @test count(==('&'), r) >= 3   # at least &n + &op + &n + the literal
        # And the bindings should capture only the raw tokens.
        @test 5 in [bb.value for bb in b if bb.name == "n"]
        @test 3 in [bb.value for bb in b if bb.name == "n"]
    end

    # ==========================================================================
    @testset "promote_input — multi-occurrence and ordering" begin
        t = default_registry()
        r, b = promote_input(t, "1 + 2 + 3 + 4")
        @test r == "&n &op &n &op &n &op &n"
        @test length(b) == 7
        # Position must increase monotonically.
        for i in 2:length(b)
            @test b[i].position > b[i-1].position
        end
        # Per-name order is preserved in bindings_by_name.
        bn = bindings_by_name(b)
        @test bn["n"]  == Any[1, 2, 3, 4]
        @test bn["op"] == Any["+", "+", "+"]
    end

    # ==========================================================================
    @testset "promote_input — specimen macro promotion" begin
        t = default_registry()
        # Override &noun with a specimen lexicon and mark it promotable.
        register_sigil!(t;
            name="noun", class=:macro, applies_at=:bind,
            lexicon=["mammoth", "fish", "berry", "fire", "cave"],
            promote_at_tokenize=true,
            provenance="test-specimen", overwrite=true)

        r, b = promote_input(t, "feed the mammoth to the fish")
        # "the", "to" are stop-words but NOT in any lexicon — they pass through
        # as literals; "mammoth" and "fish" are macro-promoted.
        @test occursin("&noun", r)
        @test count("&noun", r) == 2
        # Bindings carry the canonical surface form from the lexicon.
        noun_values = [bb.value for bb in b if bb.name == "noun"]
        @test "mammoth" in noun_values
        @test "fish"    in noun_values
        # All noun bindings classified as :macro (not :lambda).
        for bb in b
            if bb.name == "noun"
                @test bb.class === :macro
            end
        end
    end

    # ==========================================================================
    @testset "promote_input — registry without promotable sigils" begin
        # An empty/minimal registry (one sigil registered but none promotable)
        # should fall through cleanly, treating ALL input as literal text.
        t = SigilTable("minimal")
        register_sigil!(t;
            name="x", class=:tag, applies_at=:bind, provenance="test")

        r, b = promote_input(t, "what is 2 + 2")
        # No promotion happens, but Layer 1 canonicalization still runs:
        # the tokens are case-folded and op-symbols pass through untouched.
        @test occursin("2", r)  # numeric still there
        @test occursin("+", r)  # op-symbol still there
        @test isempty(b)
    end

    # ==========================================================================
    @testset "promote_input — confidence-equivalence guarantee" begin
        # The key structural guarantee: pure-text inputs (no canonicalizable,
        # no numeric, no op, no lexicon-member tokens) produce a rewritten
        # string that is byte-identical to what the existing matcher would
        # have seen in pre-promoter days, modulo whitespace normalization.
        # This is the "old specimens are bit-identical" promise.
        t = default_registry()
        register_sigil!(t; name="noun", class=:macro, applies_at=:bind,
                        lexicon=["mammoth", "fish"], promote_at_tokenize=true,
                        provenance="test", overwrite=true)

        pure_text_cases = [
            "hello world",
            "the cat sat on the mat",
            "good morning friend",
            "i need help with my project",
        ]
        for input in pure_text_cases
            r, b = promote_input(t, input)
            # No '&' in the rewritten string -> matcher input is unchanged
            # in shape from raw input (just whitespace + casing normalized).
            @test !occursin('&', r)
            @test isempty(b)
            # Whitespace-collapsed lowercase round-trip.
            expected = lowercase(strip(replace(input, r"\s+" => " ")))
            @test r == expected
        end
    end

    # ==========================================================================
    @testset "bindings_by_name view" begin
        # GRUG: 6-arg SigilBinding (Stage 1.5a-fix-1): pos, name, value, class,
        # surface, raw_position. Surface and raw_position are synthetic here
        # because this testset is exercising the name-keyed view, not the
        # promoter pipeline that produces them.
        bs = SigilBinding[
            SigilBinding(0, "n",  3,   :lambda, "3", 0),
            SigilBinding(1, "op", "+", :lambda, "+", 1),
            SigilBinding(2, "n",  4,   :lambda, "4", 2),
            SigilBinding(3, "op", "*", :lambda, "*", 3),
            SigilBinding(4, "n",  5,   :lambda, "5", 4),
        ]
        v = bindings_by_name(bs)
        @test v["n"]  == Any[3, 4, 5]
        @test v["op"] == Any["+", "*"]
        # Empty input -> empty Dict.
        @test isempty(bindings_by_name(SigilBinding[]))
    end

    # ==========================================================================
    @testset "error paths — promotable lambda with unknown sigil_type" begin
        # A lambda registered with promote_at_tokenize=true but a sigil_type
        # the promoter doesn't know -> PromoterConfigError. The registry
        # kernel can't validate this (sigil_types are open by design); the
        # promoter is the authoritative gate.
        t = SigilTable("bad")
        register_sigil!(t;
            name="weird", class=:lambda, applies_at=:match,
            sigil_type=:nonexistent_shape, promote_at_tokenize=true,
            provenance="test")
        @test_throws PromoterConfigError promote_input(t, "weird input 42")
    end

    # ==========================================================================
    # Stage 1.5a-fix-1: surface preservation. Each binding remembers what
    # the user actually typed, AND its position in the raw token stream.
    # AIML render uses .surface to echo back in the user's register; ATP
    # uses .surface + .raw_position for tone signals (caps, written-out vs
    # symbolic, position-in-utterance).
    # ==========================================================================
    @testset "promote_input — surface preservation (1.5a-fix-1)" begin
        t = default_registry()

        # Digits → surface keeps the digits, value is the parsed number.
        r, b = promote_input(t, "what is 2 + 3")
        @test r == "what is &n &op &n"
        @test length(b) == 3
        @test b[1].value == 2  && b[1].surface == "2"
        @test b[2].value == "+" && b[2].surface == "+"
        @test b[3].value == 3  && b[3].surface == "3"

        # Words → surface keeps the WORDS, value is the canonical number/op.
        # This is the whole point: AIML can render "two plus three" back in
        # words because the user wrote in words.
        r, b = promote_input(t, "what is two plus three")
        @test r == "what is &n &op &n"
        @test length(b) == 3
        @test b[1].value == 2  && b[1].surface == "two"
        @test b[2].value == "+" && b[2].surface == "plus"
        @test b[3].value == 3  && b[3].surface == "three"

        # Mixed → each binding remembers its own form.
        r, b = promote_input(t, "what is 2 plus three")
        @test b[1].surface == "2"
        @test b[2].surface == "plus"
        @test b[3].surface == "three"

        # Caps preserved verbatim — ATP reads this for arousal.
        r, b = promote_input(t, "WHAT IS TWO PLUS TWO")
        @test r == "what is &n &op &n"  # rewrite is lowercased
        @test b[1].surface == "TWO"     # but surface keeps the user's caps
        @test b[2].surface == "PLUS"
        @test b[3].surface == "TWO"

        # Sign-prefix merge surface = joined raw tokens ("negative three"),
        # NOT the canonical "-3". The user said it in words; render echoes
        # in words.
        r, b = promote_input(t, "compute negative three")
        @test r == "compute &n"
        @test length(b) == 1
        @test b[1].value == -3
        @test b[1].surface == "negative three"
    end

    # ==========================================================================
    @testset "promote_input — raw_position tracking (1.5a-fix-1)" begin
        t = default_registry()

        # Simple digit case: raw token positions match rewritten positions.
        r, b = promote_input(t, "what is 2 + 2")
        # raw stream tokens: ["what", "is", "2", "+", "2"]  (indices 0..4)
        @test b[1].raw_position == 2  # "2"
        @test b[2].raw_position == 3  # "+"
        @test b[3].raw_position == 4  # "2"
        # rewritten stream: ["what", "is", "&n", "&op", "&n"] (same indices)
        @test b[1].position == 2
        @test b[2].position == 3
        @test b[3].position == 4

        # Sign-prefix merge: raw consumes 2 tokens, rewritten emits 1.
        # Bindings AFTER the merge have diverging positions.
        r, b = promote_input(t, "give me negative three plus 5")
        # raw:        ["give"=0, "me"=1, "negative"=2, "three"=3, "plus"=4, "5"=5]
        # rewritten:  ["give"=0, "me"=1, "&n"=2,                   "&op"=3, "&n"=4]
        @test length(b) == 3
        @test b[1].surface      == "negative three"
        @test b[1].raw_position == 2  # points at FIRST raw token of merge
        @test b[1].position     == 2  # rewritten index
        @test b[2].surface      == "plus"
        @test b[2].raw_position == 4  # raw index 4
        @test b[2].position     == 3  # rewritten index 3 — diverged
        @test b[3].surface      == "5"
        @test b[3].raw_position == 5
        @test b[3].position     == 4
    end

    # ==========================================================================
    @testset "promote_input — surface for decimals" begin
        t = default_registry()
        r, b = promote_input(t, "compute 2.5 plus 1.5")
        @test r == "compute &n &op &n"
        @test b[1].value == 2.5  && b[1].surface == "2.5"
        @test b[2].value == "+"  && b[2].surface == "plus"
        @test b[3].value == 1.5  && b[3].surface == "1.5"
    end

    # ==========================================================================
    # Stage 1.5c — conditional promote_predicate. Three treatment modes per
    # sigil (functor / token / conditional) are now end-user discretion.
    # ==========================================================================
    @testset "promote_input — conditional predicate (1.5c) accepts" begin
        # GRUG: predicate that only allows promotion of small integers.
        # &n with promote=true + predicate(canonical) -> canonical numeric < 100.
        # Demonstrates per-token gating without changing the matcher or the
        # rest of the registry.
        t = SigilTable("conditional-small")
        register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test",
            promote_at_tokenize=true,
            promote_predicate = canonical -> begin
                # parse and gate; predicate is responsible for its own parsing
                v = tryparse(Int, canonical)
                v !== nothing && v < 100
            end)
        register_sigil!(t;
            name="op", class=:lambda, applies_at=:match,
            sigil_type=:op, provenance="test",
            promote_at_tokenize=true)

        # 2 < 100 -> promotes.
        r, b = promote_input(t, "compute 2 + 3")
        @test r == "compute &n &op &n"
        @test length(b) == 3

        # 500 >= 100 -> predicate rejects -> token stays as literal "500".
        r, b = promote_input(t, "compute 500 + 3")
        @test r == "compute 500 &op &n"
        @test length(b) == 2  # only &op and the trailing &n
        @test b[1].name == "op"
        @test b[2].name == "n" && b[2].value == 3
    end

    @testset "promote_input — conditional predicate (1.5c) rejects all" begin
        # GRUG: predicate that always returns false. Even though
        # promote_at_tokenize=true, NO token gets promoted. This is the
        # "functor-at-runtime" treatment expressed declaratively.
        t = SigilTable("conditional-never")
        register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test",
            promote_at_tokenize=true,
            promote_predicate = _ -> false)
        # &op stays as the always-promote default so we can see the
        # asymmetry in the rewrite.
        register_sigil!(t;
            name="op", class=:lambda, applies_at=:match,
            sigil_type=:op, provenance="test",
            promote_at_tokenize=true)

        r, b = promote_input(t, "compute 2 + 3")
        @test r == "compute 2 &op 3"
        @test length(b) == 1
        @test b[1].name == "op"
    end

    @testset "promote_input — conditional predicate (1.5c) on macro" begin
        # GRUG: predicates work on :macro classes too. Lexicon membership is
        # gated through the predicate before being checked. Use case: a
        # &color macro whose lexicon is huge, but we only want to promote
        # when the surrounding context is a paint-mixing utterance — the
        # predicate can run any cheap check.
        t = SigilTable("conditional-macro")
        register_sigil!(t;
            name="color", class=:macro, applies_at=:bind,
            lexicon=["red", "blue", "green"],
            provenance="test",
            promote_at_tokenize=true,
            # Reject "red" specifically (silly, but proves the gate fires).
            promote_predicate = canonical -> canonical != "red")

        r, b = promote_input(t, "i like red")
        @test r == "i like red"   # red was rejected by predicate, stays literal
        @test isempty(b)

        r, b = promote_input(t, "i like blue")
        @test r == "i like &color"
        @test length(b) == 1
        @test b[1].value == "blue"
    end

    @testset "promote_input — predicate raising raises PromoterConfigError" begin
        # GRUG: no silent failures. If the user-supplied predicate throws,
        # the promoter wraps and rethrows as PromoterConfigError attributable
        # to the offending sigil + token.
        t = SigilTable("conditional-broken")
        register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test",
            promote_at_tokenize=true,
            promote_predicate = _ -> error("predicate intentionally explodes"))

        @test_throws PromoterConfigError promote_input(t, "compute 2 + 3")
    end

    @testset "promote_input — predicate returning non-Bool raises" begin
        # GRUG: predicate must return Bool, not truthy. We catch this
        # explicitly to prevent silent misclassification (a String "yes"
        # is truthy in many languages but is a bug here).
        t = SigilTable("conditional-bad-return")
        register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test",
            promote_at_tokenize=true,
            promote_predicate = canonical -> "yes")  # String, not Bool

        @test_throws PromoterConfigError promote_input(t, "compute 2 + 3")
    end

    @testset "register_sigil! — predicate without promote=true raises" begin
        # GRUG: setting a predicate when promote_at_tokenize=false would
        # cause the predicate to never run — a silent no-op. We forbid
        # this at registration time.
        t = SigilTable("bad-predicate-config")
        @test_throws SigilConfigError register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test",
            promote_at_tokenize=false,
            promote_predicate = _ -> true)
    end

    # ==========================================================================
    @testset "SigilBinding shape" begin
        # The struct is plain immutable, fields are exactly what consumers
        # rely on. If anyone makes it mutable later, this fires. Stage
        # 1.5a-fix-1 added :surface and :raw_position so AIML render and
        # ATP can read the user's original input alongside the canonical
        # value.
        @test isstructtype(SigilBinding)
        @test !ismutabletype(SigilBinding)
        fns = fieldnames(SigilBinding)
        @test fns == (:position, :name, :value, :class, :surface, :raw_position)
    end

    # ==========================================================================
    @testset "exported closed maps shape" begin
        # NUMBER_WORD_MAP must contain at least 0–20 plus tens 30–90 plus 100.
        for i in 0:19
            words_for_i = [k for (k, v) in NUMBER_WORD_MAP if v == string(i)]
            @test length(words_for_i) >= 1
        end
        for v in ("20", "30", "40", "50", "60", "70", "80", "90", "100")
            @test v in values(NUMBER_WORD_MAP)
        end

        # OP_WORD_MAP must cover the canonical English ops.
        for w in ("plus", "minus", "times", "divided", "over", "equals")
            @test haskey(OP_WORD_MAP, w)
        end

        # OP_SYMBOL_SET must contain the closed math-op set.
        for s in ("+", "-", "*", "/", "=", "<", ">", "%", "^")
            @test s in OP_SYMBOL_SET
        end
    end

end
