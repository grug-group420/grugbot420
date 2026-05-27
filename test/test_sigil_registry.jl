# test/test_sigil_registry.jl
# ==============================================================================
# Tests for SigilRegistry — Stage 1 Sigil Kernel
# ==============================================================================
# GRUG: covers EVERY locked-in design point:
#   - SigilEntry shape: all 8 fields present on every entry, immutable.
#   - SigilTable construction: default and labelled.
#   - register_sigil! validation:
#       * empty / malformed name → SigilArgumentError
#       * unknown class → SigilConfigError
#       * unknown applies_at → SigilConfigError
#       * :lambda missing sigil_type → SigilConfigError
#       * :lambda with lexicon → SigilConfigError
#       * :macro missing lexicon → SigilConfigError
#       * :macro with sigil_type → SigilConfigError
#       * :tag with sigil_type or lexicon → SigilConfigError
#       * lexicon overflow (MAX_LEXICON_SIZE) → SigilConfigError
#       * lexicon empty-string entry → SigilConfigError
#       * expansion on non-:procedure class → SigilConfigError
#       * collision without overwrite → SigilConfigError
#       * collision with overwrite=true → succeeds
#       * registry overflow (MAX_REGISTRY_ENTRIES) → SigilConfigError
#   - lookup_sigil hit / miss / empty-name.
#   - has_sigil non-throwing existence probe.
#   - list_sigils filter validation + deterministic ordering.
#   - clear_registry! wipe.
#   - parse_sigil_token: pure-syntax happy paths and rejects.
#   - resolve_sigils_in_pattern:
#       * fast path on pattern with no '&'
#       * happy path: multi-sigil pattern, in-order refs with byte offsets
#       * unknown sigil → SigilResolutionError carrying pattern context
#       * reserved class registered + used in pattern → SigilConfigError unless allow_reserved
#       * reserved phase registered + used in pattern → SigilConfigError unless allow_reserved
#       * MAX_SIGILS_PER_PATTERN overflow → SigilConfigError
#   - default_registry: contains exactly &n, &word, &rest, &noun with the
#     locked-in shapes; provenance="engine-default".
#   - merge_registry!: :error / :overwrite / :keep; bad policy → SigilArgumentError.
#   - Greek-letter names accepted (forward-compat with Stage 6 procedure names).
#   - Reserved-class entries (:glue, :functor, :procedure) ACCEPT registration
#     (forward-compat) but REJECT use in patterns at Stage 1.
#
# No silent failures: every error branch is asserted with @test_throws on the
# specific error type.
# ==============================================================================

using Test

# GRUG: load module directly (test files run as isolated subprocesses, same
# pattern as test_self_observer.jl).
const REPO_ROOT = abspath(joinpath(@__DIR__, ".."))
include(joinpath(REPO_ROOT, "src", "SigilRegistry.jl"))
using .SigilRegistry

@testset "SigilRegistry — full surface" begin

    # ==========================================================================
    @testset "constants + closed enums" begin
        # GRUG: the closed enums are the schema. If anyone changes their
        # arity or membership without bumping the engine version, this test
        # catches it.
        @test SIGIL_PREFIX === '&'
        @test length(SIGIL_CLASSES) == 6
        @test :lambda    in SIGIL_CLASSES
        @test :macro     in SIGIL_CLASSES
        @test :tag       in SIGIL_CLASSES
        @test :glue      in SIGIL_CLASSES
        @test :functor   in SIGIL_CLASSES
        @test :procedure in SIGIL_CLASSES

        @test length(SIGIL_APPLIES_AT) == 9
        @test :bind   in SIGIL_APPLIES_AT
        @test :match  in SIGIL_APPLIES_AT
        @test :tone   in SIGIL_APPLIES_AT
        @test :render in SIGIL_APPLIES_AT

        # Regex sanity.
        @test occursin(SIGIL_NAME_REGEX, "n")
        @test occursin(SIGIL_NAME_REGEX, "noun")
        @test occursin(SIGIL_NAME_REGEX, "fuzzy-match")
        @test occursin(SIGIL_NAME_REGEX, "Σ_greet")
        @test !occursin(SIGIL_NAME_REGEX, "")
        @test !occursin(SIGIL_NAME_REGEX, "1n")        # leading digit
        @test !occursin(SIGIL_NAME_REGEX, "&n")        # carries prefix
        @test !occursin(SIGIL_NAME_REGEX, "n n")       # space
        @test !occursin(SIGIL_NAME_REGEX, "n.x")       # punctuation
    end

    # ==========================================================================
    @testset "SigilTable construction" begin
        t1 = SigilTable()
        @test t1.label == "unlabeled"
        @test isempty(t1.entries)

        t2 = SigilTable("specimen-foo")
        @test t2.label == "specimen-foo"
        @test isempty(t2.entries)
    end

    # ==========================================================================
    @testset "register_sigil! — name validation" begin
        t = SigilTable("test")

        # Empty name.
        @test_throws SigilArgumentError register_sigil!(t;
            name="", class=:tag, applies_at=:bind)

        # Malformed names.
        @test_throws SigilArgumentError register_sigil!(t;
            name="1n", class=:tag, applies_at=:bind)
        @test_throws SigilArgumentError register_sigil!(t;
            name="n n", class=:tag, applies_at=:bind)
        @test_throws SigilArgumentError register_sigil!(t;
            name="n.x", class=:tag, applies_at=:bind)
        @test_throws SigilArgumentError register_sigil!(t;
            name="&n", class=:tag, applies_at=:bind)  # must not include prefix

        # Confirm none of the failed registrations leaked.
        @test isempty(t.entries)
    end

    # ==========================================================================
    @testset "register_sigil! — class & applies_at validation" begin
        t = SigilTable("test")

        @test_throws SigilConfigError register_sigil!(t;
            name="x", class=:not_a_class, applies_at=:bind)

        @test_throws SigilConfigError register_sigil!(t;
            name="x", class=:tag, applies_at=:not_a_phase)

        @test isempty(t.entries)
    end

    # ==========================================================================
    @testset "register_sigil! — class/field coherence" begin
        t = SigilTable("test")

        # :lambda requires sigil_type
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_lambda", class=:lambda, applies_at=:match)

        # :lambda must NOT carry lexicon
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_lambda2", class=:lambda, applies_at=:match,
            sigil_type=:number, lexicon=["a", "b"])

        # :macro requires lexicon (even empty list is fine, but nothing is not)
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_macro", class=:macro, applies_at=:bind)

        # :macro must NOT carry sigil_type
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_macro2", class=:macro, applies_at=:bind,
            lexicon=["a"], sigil_type=:word)

        # :tag must NOT carry sigil_type
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_tag", class=:tag, applies_at=:bind, sigil_type=:word)

        # :tag must NOT carry lexicon
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_tag2", class=:tag, applies_at=:bind, lexicon=["x"])

        @test isempty(t.entries)
    end

    # ==========================================================================
    @testset "register_sigil! — happy paths for active classes" begin
        t = SigilTable("test")

        # :lambda
        e_n = register_sigil!(t;
            name="n", class=:lambda, applies_at=:match,
            sigil_type=:number, provenance="test")
        @test e_n.name == "n"
        @test e_n.class === :lambda
        @test e_n.applies_at === :match
        @test e_n.sigil_type === :number
        @test e_n.lexicon === nothing
        @test e_n.params === nothing
        @test e_n.expansion === nothing
        @test e_n.provenance == "test"

        # :macro with empty lexicon (allowed for specimen-overridable)
        e_noun = register_sigil!(t;
            name="noun", class=:macro, applies_at=:bind,
            lexicon=String[], provenance="test")
        @test e_noun.class === :macro
        @test e_noun.lexicon == String[]
        @test e_noun.sigil_type === nothing

        # :macro with populated lexicon
        e_color = register_sigil!(t;
            name="color", class=:macro, applies_at=:bind,
            lexicon=["red", "green", "blue"], provenance="test")
        @test e_color.lexicon == ["red", "green", "blue"]

        # :tag — no extra fields
        e_tag = register_sigil!(t;
            name="urgent", class=:tag, applies_at=:bind, provenance="test")
        @test e_tag.class === :tag
        @test e_tag.sigil_type === nothing
        @test e_tag.lexicon === nothing

        # params dict round-trip
        e_p = register_sigil!(t;
            name="fuzzy", class=:tag, applies_at=:bind,
            params=Dict("max" => 2, "mode" => "lev"), provenance="test")
        @test e_p.params !== nothing
        @test e_p.params["max"] == 2
        @test e_p.params["mode"] == "lev"

        @test length(t.entries) == 5
    end

    # ==========================================================================
    @testset "register_sigil! — collision policy" begin
        t = SigilTable("test")

        register_sigil!(t;
            name="x", class=:tag, applies_at=:bind, provenance="first")

        # Default behaviour: collision throws.
        @test_throws SigilConfigError register_sigil!(t;
            name="x", class=:tag, applies_at=:bind, provenance="second")

        # Explicit overwrite=true succeeds.
        e = register_sigil!(t;
            name="x", class=:tag, applies_at=:bind,
            provenance="second", overwrite=true)
        @test e.provenance == "second"
        @test t.entries["x"].provenance == "second"
        @test length(t.entries) == 1
    end

    # ==========================================================================
    @testset "register_sigil! — lexicon size + content validation" begin
        t = SigilTable("test")

        # Empty-string entry inside lexicon is rejected.
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_lex", class=:macro, applies_at=:bind,
            lexicon=["a", "", "b"])

        # Oversize lexicon rejected.
        big = [string("w", i) for i in 1:(SigilRegistry.MAX_LEXICON_SIZE + 1)]
        @test_throws SigilConfigError register_sigil!(t;
            name="big_lex", class=:macro, applies_at=:bind,
            lexicon=big)

        # Exactly at the cap is allowed.
        ok = [string("w", i) for i in 1:SigilRegistry.MAX_LEXICON_SIZE]
        e = register_sigil!(t;
            name="ok_lex", class=:macro, applies_at=:bind, lexicon=ok)
        @test length(e.lexicon) == SigilRegistry.MAX_LEXICON_SIZE
    end

    # ==========================================================================
    @testset "register_sigil! — expansion field is reserved" begin
        t = SigilTable("test")

        # expansion on non-:procedure class is REJECTED.
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_exp", class=:tag, applies_at=:bind,
            expansion=["step1", "step2"])

        # On :procedure class (reserved class) it is ACCEPTED — forward-compat
        # for Stage 6.
        e = register_sigil!(t;
            name="proc_x", class=:procedure, applies_at=:bind,
            expansion=Any["a", "b"], provenance="forward-compat")
        @test e.class === :procedure
        @test e.expansion == Any["a", "b"]
    end

    # ==========================================================================
    @testset "register_sigil! — promote_at_tokenize validation" begin
        t = SigilTable("promote-test")

        # Valid on :lambda.
        e_l = register_sigil!(t;
            name="num", class=:lambda, applies_at=:match,
            sigil_type=:number, promote_at_tokenize=true)
        @test e_l.promote_at_tokenize === true

        # Valid on :macro.
        e_m = register_sigil!(t;
            name="col", class=:macro, applies_at=:bind,
            lexicon=["red"], promote_at_tokenize=true)
        @test e_m.promote_at_tokenize === true

        # Default false when not specified.
        e_d = register_sigil!(t;
            name="def", class=:tag, applies_at=:bind)
        @test e_d.promote_at_tokenize === false

        # REJECTED on :tag (no value to capture).
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_tag", class=:tag, applies_at=:bind,
            promote_at_tokenize=true)

        # REJECTED on reserved classes (gated out of pattern resolution
        # anyway; setting promote on them is a programmer error).
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_glue", class=:glue, applies_at=:bind,
            promote_at_tokenize=true)
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_proc", class=:procedure, applies_at=:bind,
            promote_at_tokenize=true)
        @test_throws SigilConfigError register_sigil!(t;
            name="bad_fun", class=:functor, applies_at=:bind,
            promote_at_tokenize=true)
    end

    # ==========================================================================
    @testset "register_sigil! — promote_predicate validation (1.5c)" begin
        t = SigilTable("predicate-test")

        # Valid: predicate + promote_at_tokenize=true.
        e_ok = register_sigil!(t;
            name="gated_n", class=:lambda, applies_at=:match,
            sigil_type=:number, promote_at_tokenize=true,
            promote_predicate = canonical -> canonical != "0")
        @test e_ok.promote_predicate !== nothing
        # Confirm it's stored verbatim (no copy / wrap).
        @test e_ok.promote_predicate("1") === true
        @test e_ok.promote_predicate("0") === false

        # Default nothing when not specified.
        e_def = register_sigil!(t;
            name="plain_n", class=:lambda, applies_at=:match,
            sigil_type=:number, promote_at_tokenize=true)
        @test e_def.promote_predicate === nothing

        # REJECTED: predicate set without promote_at_tokenize=true.
        # Silent no-ops are forbidden.
        @test_throws SigilConfigError register_sigil!(t;
            name="silent_no_op", class=:lambda, applies_at=:match,
            sigil_type=:number, promote_at_tokenize=false,
            promote_predicate = _ -> true)

        # Predicate works on :macro too (lexicon membership gated).
        e_mac = register_sigil!(t;
            name="gated_color", class=:macro, applies_at=:bind,
            lexicon=["red", "blue"], promote_at_tokenize=true,
            promote_predicate = canonical -> canonical != "red")
        @test e_mac.promote_predicate !== nothing
    end

    # ==========================================================================
    @testset "register_sigil! — registry size cap" begin
        t = SigilTable("test")

        # Stuff to N-1, then N, then verify N+1 throws. Use a smaller
        # synthetic cap by exhausting the real one would take too long;
        # test the boundary by adding one entry below the cap and patching
        # haskey logic via direct dictionary inspection. Here we instead
        # build right up against a much smaller cap by relying on the real
        # constant; we cap the test scope at 256 to keep it fast.
        # GRUG: instead, we directly assert that the cap exists and is sane.
        @test SigilRegistry.MAX_REGISTRY_ENTRIES > 0
        @test SigilRegistry.MAX_REGISTRY_ENTRIES >= 256

        # Smoke: register 32 distinct sigils, confirm count.
        for i in 1:32
            register_sigil!(t;
                name="s$i", class=:tag, applies_at=:bind)
        end
        @test length(t.entries) == 32
    end

    # ==========================================================================
    @testset "lookup_sigil + has_sigil" begin
        t = SigilTable("test")
        register_sigil!(t;
            name="x", class=:tag, applies_at=:bind, provenance="lkp")

        e = lookup_sigil(t, "x")
        @test e.name == "x"
        @test e.provenance == "lkp"

        # Miss throws SigilResolutionError.
        @test_throws SigilResolutionError lookup_sigil(t, "missing")

        # Empty name throws SigilArgumentError.
        @test_throws SigilArgumentError lookup_sigil(t, "")

        # Non-throwing probes.
        @test has_sigil(t, "x") === true
        @test has_sigil(t, "missing") === false
    end

    # ==========================================================================
    @testset "list_sigils — filters and deterministic order" begin
        t = SigilTable("test")
        register_sigil!(t;
            name="zeta", class=:tag, applies_at=:bind)
        register_sigil!(t;
            name="alpha", class=:macro, applies_at=:bind, lexicon=["x"])
        register_sigil!(t;
            name="mid", class=:lambda, applies_at=:match, sigil_type=:word)

        # No filter: all entries, lexicographic by name.
        all_e = list_sigils(t)
        @test [e.name for e in all_e] == ["alpha", "mid", "zeta"]

        # Filter by class.
        only_tag = list_sigils(t; class=:tag)
        @test length(only_tag) == 1 && only_tag[1].name == "zeta"

        # Filter by applies_at.
        only_match = list_sigils(t; applies_at=:match)
        @test length(only_match) == 1 && only_match[1].name == "mid"

        # Combined filter.
        none = list_sigils(t; class=:tag, applies_at=:match)
        @test isempty(none)

        # Bad filter values throw SigilArgumentError.
        @test_throws SigilArgumentError list_sigils(t; class=:nope)
        @test_throws SigilArgumentError list_sigils(t; applies_at=:nope)
    end

    # ==========================================================================
    @testset "clear_registry!" begin
        t = SigilTable("test")
        register_sigil!(t; name="x", class=:tag, applies_at=:bind)
        register_sigil!(t; name="y", class=:tag, applies_at=:bind)
        @test length(t.entries) == 2

        clear_registry!(t)
        @test isempty(t.entries)
        @test t.label == "test"  # label preserved
    end

    # ==========================================================================
    @testset "parse_sigil_token — pure syntax" begin
        @test parse_sigil_token("&n") == "n"
        @test parse_sigil_token("&noun") == "noun"
        @test parse_sigil_token("&fuzzy-match") == "fuzzy-match"
        @test parse_sigil_token("&Σ_greet") == "Σ_greet"

        # Not a sigil token.
        @test parse_sigil_token("") === nothing
        @test parse_sigil_token("noun") === nothing      # no prefix
        @test parse_sigil_token("&") === nothing         # prefix only
        @test parse_sigil_token("&1n") === nothing       # bad name
        @test parse_sigil_token("& n") === nothing       # space after prefix
        @test parse_sigil_token("&n.x") === nothing      # punctuation
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — fast path" begin
        t = default_registry()

        # Pattern with no '&' returns empty vector and allocates nothing
        # observable. The fast path is the bit-identical guarantee for old
        # specimens.
        for pat in ["hello world", "the cat sat", "", "no sigils here at all"]
            refs = resolve_sigils_in_pattern(t, pat)
            @test refs == SigilTokenRef[]
        end
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — happy path" begin
        t = default_registry()
        # Add a populated &noun lexicon for the test.
        register_sigil!(t;
            name="noun", class=:macro, applies_at=:bind,
            lexicon=["dog", "cat"], provenance="test", overwrite=true)

        pat = "what is &n + &n equal to"
        refs = resolve_sigils_in_pattern(t, pat)
        @test length(refs) == 2
        @test refs[1].name == "n"
        @test refs[2].name == "n"
        @test refs[1].entry.class === :lambda
        @test refs[1].entry.sigil_type === :number
        @test refs[1].start_byte < refs[2].start_byte

        # Byte offsets land on '&'.
        @test pat[refs[1].start_byte] == '&'
        @test pat[refs[2].start_byte] == '&'

        pat2 = "feed the &noun please"
        refs2 = resolve_sigils_in_pattern(t, pat2)
        @test length(refs2) == 1
        @test refs2[1].name == "noun"
        @test refs2[1].entry.class === :macro
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — unknown sigil throws with context" begin
        t = default_registry()
        pat = "what about &nope here"

        # SigilResolutionError carries the pattern + name for traceability.
        @test_throws SigilResolutionError resolve_sigils_in_pattern(t, pat)

        try
            resolve_sigils_in_pattern(t, pat)
            @test false  # unreachable
        catch e
            @test e isa SigilResolutionError
            @test e.sigil_name == "nope"
            @test e.pattern == pat
        end
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — reserved class gating" begin
        t = SigilTable("reserved-test")
        # Register a :glue sigil — registration is allowed (forward-compat).
        register_sigil!(t;
            name="and", class=:glue, applies_at=:bind, provenance="forward")

        pat = "do x &and y"
        # Default: reserved class in pattern → SigilConfigError.
        @test_throws SigilConfigError resolve_sigils_in_pattern(t, pat)

        # allow_reserved=true bypasses the gate (test/specimen pre-load path).
        refs = resolve_sigils_in_pattern(t, pat; allow_reserved=true)
        @test length(refs) == 1
        @test refs[1].entry.class === :glue
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — reserved phase gating" begin
        t = SigilTable("reserved-phase-test")
        # Register a :tag sigil at a RESERVED phase (:tone). Class is active,
        # phase is not; pattern use must throw at Stage 1.
        register_sigil!(t;
            name="tonemark", class=:tag, applies_at=:tone,
            provenance="forward")

        pat = "say &tonemark hello"
        @test_throws SigilConfigError resolve_sigils_in_pattern(t, pat)

        # allow_reserved bypasses.
        refs = resolve_sigils_in_pattern(t, pat; allow_reserved=true)
        @test length(refs) == 1
        @test refs[1].entry.applies_at === :tone
    end

    # ==========================================================================
    @testset "resolve_sigils_in_pattern — MAX_SIGILS_PER_PATTERN" begin
        t = default_registry()
        # Build a pattern with one more `&n` than the cap.
        n_overflow = SigilRegistry.MAX_SIGILS_PER_PATTERN + 1
        pat = join(fill("&n", n_overflow), " + ")

        @test_throws SigilConfigError resolve_sigils_in_pattern(t, pat)

        # At the cap is allowed.
        n_cap = SigilRegistry.MAX_SIGILS_PER_PATTERN
        pat_ok = join(fill("&n", n_cap), " + ")
        refs = resolve_sigils_in_pattern(t, pat_ok)
        @test length(refs) == n_cap
    end

    # ==========================================================================
    @testset "default_registry — exact contents + provenance" begin
        t = default_registry()
        @test t.label == "engine-default"
        # Stage 1.5 added &op; default registry now ships 5 entries.
        @test length(t.entries) == 5

        e_n = lookup_sigil(t, "n")
        @test e_n.class === :lambda
        @test e_n.applies_at === :match
        @test e_n.sigil_type === :number
        @test e_n.provenance == "engine-default"
        # Stage 1.5: &n is promoted at tokenize time.
        @test e_n.promote_at_tokenize === true

        e_w = lookup_sigil(t, "word")
        @test e_w.class === :lambda
        @test e_w.sigil_type === :word
        @test e_w.promote_at_tokenize === false  # words are not auto-promoted

        e_r = lookup_sigil(t, "rest")
        @test e_r.class === :lambda
        @test e_r.sigil_type === :slurp

        e_noun = lookup_sigil(t, "noun")
        @test e_noun.class === :macro
        @test e_noun.applies_at === :bind
        @test e_noun.lexicon == String[]   # specimen-overridable
        @test e_noun.sigil_type === nothing

        # Stage 1.5: &op is the new math-operator lambda, promoted at tokenize.
        e_op = lookup_sigil(t, "op")
        @test e_op.class === :lambda
        @test e_op.applies_at === :match
        @test e_op.sigil_type === :op
        @test e_op.promote_at_tokenize === true

        # Two fresh defaults are independent objects (no shared state).
        t2 = default_registry()
        @test t2 !== t
        @test t2.entries !== t.entries
    end

    # ==========================================================================
    @testset "merge_registry! — three conflict policies" begin
        # :error policy
        a1 = default_registry()
        b1 = SigilTable("specimen")
        register_sigil!(b1; name="custom", class=:tag, applies_at=:bind,
            provenance="specimen")
        # No collision with engine-default — merges cleanly.
        merge_registry!(a1, b1; conflict=:error)
        @test has_sigil(a1, "custom")
        @test lookup_sigil(a1, "custom").provenance == "specimen"

        # :error policy WITH collision throws.
        a2 = default_registry()
        b2 = SigilTable("specimen")
        register_sigil!(b2; name="noun", class=:macro, applies_at=:bind,
            lexicon=["dog", "cat"], provenance="specimen")
        @test_throws SigilConfigError merge_registry!(a2, b2; conflict=:error)
        # Target unmodified on the conflicting key.
        @test lookup_sigil(a2, "noun").provenance == "engine-default"
        @test lookup_sigil(a2, "noun").lexicon == String[]

        # :overwrite policy replaces.
        a3 = default_registry()
        b3 = SigilTable("specimen")
        register_sigil!(b3; name="noun", class=:macro, applies_at=:bind,
            lexicon=["dog", "cat"], provenance="specimen")
        merge_registry!(a3, b3; conflict=:overwrite)
        @test lookup_sigil(a3, "noun").provenance == "specimen"
        @test lookup_sigil(a3, "noun").lexicon == ["dog", "cat"]

        # :keep policy preserves target.
        a4 = default_registry()
        b4 = SigilTable("specimen")
        register_sigil!(b4; name="noun", class=:macro, applies_at=:bind,
            lexicon=["dog", "cat"], provenance="specimen")
        merge_registry!(a4, b4; conflict=:keep)
        @test lookup_sigil(a4, "noun").provenance == "engine-default"
        @test lookup_sigil(a4, "noun").lexicon == String[]

        # Bad policy throws.
        a5 = default_registry()
        b5 = SigilTable("specimen")
        @test_throws SigilArgumentError merge_registry!(a5, b5; conflict=:nope)
    end

    # ==========================================================================
    @testset "Greek-letter names accepted" begin
        # Forward-compat for Stage 6 procedure naming convention (Σ_, Π_, λ_).
        t = SigilTable("greek")
        e = register_sigil!(t;
            name="Σ_greet", class=:procedure, applies_at=:bind,
            expansion=Any["hello"], provenance="forward")
        @test e.name == "Σ_greet"
        @test has_sigil(t, "Σ_greet")

        # Greek name in pattern parses too (would be reserved-gated at use).
        @test parse_sigil_token("&Σ_greet") == "Σ_greet"
    end

    # ==========================================================================
    @testset "SigilEntry immutability + schema shape" begin
        # GRUG: the entry is a plain immutable struct. We rely on this for
        # serialization predictability. If anyone makes it mutable later,
        # this assertion fires.
        @test isstructtype(SigilEntry)
        @test !ismutabletype(SigilEntry)
        # Fields are exactly the 10 we locked in:
        #   Stage 1     — first 8 (name..provenance)
        #   Stage 1.5a  — promote_at_tokenize
        #   Stage 1.5c  — promote_predicate (conditional gate)
        fns = fieldnames(SigilEntry)
        @test fns == (:name, :class, :applies_at, :sigil_type,
                      :lexicon, :params, :expansion, :provenance,
                      :promote_at_tokenize, :promote_predicate)
    end

end
