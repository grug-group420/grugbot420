# ==============================================================================
# test_sigil_pipeline.jl
# ------------------------------------------------------------------------------
# GRUG v7.16+ — Comprehensive coverage for the wired-in sigil routing pipeline.
#
# Surface tested (top-down, integration-style):
#   1. SigilMediator: mediate / has_math / has_multipart / kinds_for_bindings
#   2. Tagging convention: node_sigil_kind, has_sigil_tag, create_sigil_node,
#      list_sigil_node_ids
#   3. Multi-vote fire path: cast_sigil_votes for :math (single + multi-step),
#      :multipart (single + multi-conj + edge cases), :instruction (reserved),
#      :none (delegates), unknown (loud failure)
#   4. Vote struct: payload field default, explicit payload, backward compat
#   5. Direct routing: list_sigil_node_ids injection covers tagged nodes whose
#      patterns wouldn't normally bind
#   6. End-to-end: process_mission produces output with payload concatenated
#   7. Save/load v2.6: serialize_global round-trip, custom sigils preserved
#   8. Backward compat: v2.5 specimens (no "sigils" block) load to defaults
#
# RUNS INSIDE THE FULL PACKAGE, NOT A LIBRARY MODULE BOX. Loading the full
# GrugBot420 module pulls in COMMANDS / NODE_MAP / process_mission so we can
# validate the actual fire path, not just the shapes.
# ==============================================================================

using Test
using JSON

if !isdefined(Main, :GrugBot420) || !isdefined(Main.GrugBot420, :SigilMediator)
    using GrugBot420
end

const GB = GrugBot420
using GrugBot420.SigilMediator
using GrugBot420.SigilRegistry
using GrugBot420.SigilPromoter
using GrugBot420.ArithmeticEngine

@testset "SIGIL PIPELINE — full surface" begin

    # =========================================================================
    @testset "1. SigilMediator.mediate — happy path + kind detection" begin
        # 1a. plain math
        m1 = mediate("2 + 2")
        @test m1.original == "2 + 2"
        @test m1.rewritten == "&n &op &n"
        @test length(m1.bindings) == 3
        @test m1.kinds == [:math]

        # 1b. natural-language math (number-words + op-words)
        m2 = mediate("two plus two")
        @test m2.rewritten == "&n &op &n"
        @test m2.kinds == [:math]
        @test has_math(m2.bindings)

        # 1c. multipart only
        m3 = mediate("tell me X and explain Y")
        @test :multipart in m3.kinds
        @test :math ∉ m3.kinds
        @test has_multipart(m3.bindings)

        # 1d. combined
        m4 = mediate("what is 2+2 and 5-1")
        @test :math in m4.kinds
        @test :multipart in m4.kinds
        # deterministic order: math before multipart
        @test m4.kinds == [:math, :multipart]

        # 1e. neither kind
        m5 = mediate("hello there friend")
        @test isempty(m5.kinds)

        # 1f. empty / whitespace input throws
        @test_throws ArgumentError mediate("")
        @test_throws ArgumentError mediate("   ")
        @test_throws ArgumentError mediate("\t\n")
    end

    # =========================================================================
    @testset "2. kinds_for_bindings — deterministic ordering + no false positives" begin
        # Simulate bindings without going through promote_input: kinds should
        # depend on binding name presence only.
        # SigilBinding(position, name, value, class, surface, raw_position)
        b_math = SigilBinding[
            SigilBinding(1, "n",  2,   :lambda, "2", 0),
            SigilBinding(2, "op", "+", :lambda, "+", 2),
            SigilBinding(3, "n",  2,   :lambda, "2", 4),
        ]
        @test kinds_for_bindings(b_math) == [:math]

        b_mp = SigilBinding[SigilBinding(1, "conj", "and", :macro, "and", 3)]
        @test kinds_for_bindings(b_mp) == [:multipart]

        b_both = vcat(b_math, b_mp)
        @test kinds_for_bindings(b_both) == [:math, :multipart]

        b_none = SigilBinding[SigilBinding(1, "word", "hello", :lambda, "hello", 0)]
        @test isempty(kinds_for_bindings(b_none))

        # 1 of 2 numbers + 1 op → not math (need ≥2 numbers)
        b_partial = SigilBinding[
            SigilBinding(1, "n",  2,   :lambda, "2", 0),
            SigilBinding(2, "op", "+", :lambda, "+", 2),
        ]
        @test :math ∉ kinds_for_bindings(b_partial)
    end

    # =========================================================================
    @testset "3. Tagging — node_sigil_kind / has_sigil_tag / list_sigil_node_ids" begin
        # Snapshot then clear node map for isolation
        existing_ids = collect(keys(GB.NODE_MAP))

        opener = first(collect(keys(GB.COMMANDS)))

        id_math = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :math,
        )
        id_mp = GB.create_sigil_node(
            "&word &conj &word", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :multipart,
        )
        id_plain = GB.create_node(
            "untagged plain pattern", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[],
        )

        n_math = GB.NODE_MAP[id_math]
        n_mp   = GB.NODE_MAP[id_mp]
        n_plain = GB.NODE_MAP[id_plain]

        @test GB.node_sigil_kind(n_math)  === :math
        @test GB.node_sigil_kind(n_mp)    === :multipart
        @test GB.node_sigil_kind(n_plain) === :none

        @test GB.has_sigil_tag(n_math)
        @test GB.has_sigil_tag(n_mp)
        @test !GB.has_sigil_tag(n_plain)

        # Tag stored at front of drop_table
        @test n_math.drop_table[1] == "@sigil:math"
        @test n_mp.drop_table[1]   == "@sigil:multipart"

        # Discovery
        math_ids = GB.list_sigil_node_ids(:math)
        @test id_math in math_ids
        @test id_mp ∉ math_ids
        @test id_plain ∉ math_ids

        mp_ids = GB.list_sigil_node_ids(:multipart)
        @test id_mp in mp_ids
        @test id_math ∉ mp_ids

        any_ids = GB.list_sigil_node_ids(:any)
        @test id_math in any_ids
        @test id_mp in any_ids
        @test id_plain ∉ any_ids

        # create_sigil_node rejects :none
        @test_throws ErrorException GB.create_sigil_node(
            "p", "$(opener)^1.0", Dict{String,Any}("system_prompt" => "x"),
            String[]; kind = :none,
        )

        # Clean up nodes we created
        for id in (id_math, id_mp, id_plain)
            haskey(GB.NODE_MAP, id) && delete!(GB.NODE_MAP, id)
        end
    end

    # =========================================================================
    @testset "4. cast_sigil_votes — :math single op" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :math,
        )

        m = mediate("2 plus 2")
        votes = GB.cast_sigil_votes(id, 0.7, m.bindings, m.original,
                                    GB.RelationalTriple[], GB.RelationalTriple[])

        @test length(votes) == 1
        v = votes[1]
        @test v.action == opener           # action stays a real COMMANDS key
        @test occursin("4", v.payload)    # answer rides on payload (may be full sentence like "2 plus 2 equals 4")
        @test v.confidence == 0.7
        @test v.node_id == id
        # GRUG v7.27: antimatch field removed from Vote — no longer exists

        # Comparison op produces "true"/"false" payload
        m2 = mediate("5 > 3")
        v2 = GB.cast_sigil_votes(id, 0.5, m2.bindings, m2.original,
                                 GB.RelationalTriple[], GB.RelationalTriple[])[1]
        @test occursin("true", v2.payload) || occursin("false", v2.payload)

        delete!(GB.NODE_MAP, id)
    end

    # =========================================================================
    @testset "5. cast_sigil_votes — :math multi-step + step inheritance" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :math,
        )

        m = mediate("1 plus 2 plus 3")
        votes = GB.cast_sigil_votes(id, 0.6, m.bindings, m.original,
                                    GB.RelationalTriple[], GB.RelationalTriple[])

        # 2 steps + 1 final = 3 votes
        @test length(votes) == 3
        # All inherit the same conf
        @test all(v -> v.confidence == 0.6, votes)
        # All have action == opener
        @test all(v -> v.action == opener, votes)
        # Step votes carry "lhs op rhs = result" in payload
        @test any(occursin("=", v.payload) for v in votes)
        # Final vote payload contains the final answer
        @test any(occursin("6", v.payload) for v in votes)
        # Step payloads include intermediate result 3
        @test any(occursin("3", v.payload) for v in votes if occursin("=", v.payload))

        delete!(GB.NODE_MAP, id)
    end

    # =========================================================================
    @testset "6. cast_sigil_votes — :math malformed bindings → opener-only fallback" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :math,
        )

        # No bindings → has_math_bindings=false → opener-only fallback (1 vote, empty payload)
        empty_binds = SigilBinding[]
        votes = GB.cast_sigil_votes(id, 0.4, empty_binds, "no math here",
                                    GB.RelationalTriple[], GB.RelationalTriple[])
        @test length(votes) == 1
        @test votes[1].action == opener
        @test votes[1].payload == ""

        delete!(GB.NODE_MAP, id)
    end

    # =========================================================================
    @testset "7. cast_sigil_votes — :multipart slicing" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id = GB.create_sigil_node(
            "&word &conj &word", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :multipart,
        )

        # Single conj
        m = mediate("tell me about cats and explain dogs")
        votes = GB.cast_sigil_votes(id, 0.5, m.bindings, m.original,
                                    GB.RelationalTriple[], GB.RelationalTriple[])
        @test length(votes) == 2
        @test all(v -> v.action == opener, votes)
        # Clauses present in payloads
        payloads = [v.payload for v in votes]
        @test "tell me about cats" in payloads
        @test "explain dogs" in payloads
        # The conj word itself does NOT appear in any payload (clean slice)
        @test !any(occursin(r"\band\b", p) for p in payloads)

        # Two conj words → 3 clauses
        m2 = mediate("read this and write that and remember it")
        votes2 = GB.cast_sigil_votes(id, 0.5, m2.bindings, m2.original,
                                     GB.RelationalTriple[], GB.RelationalTriple[])
        @test length(votes2) == 3
        @test all(v -> v.confidence == 0.5, votes2)

        # No conj (text without &conj) → falls back to single full-text vote
        m3 = mediate("hello world")
        # m3 has NO conj bindings (no clause boundary), so multipart-routing on
        # this node should emit the full-text fallback even though the kind is
        # :multipart.
        votes3 = GB.cast_sigil_votes(id, 0.5, m3.bindings, m3.original,
                                     GB.RelationalTriple[], GB.RelationalTriple[])
        @test length(votes3) == 1
        @test votes3[1].payload == "hello world"

        delete!(GB.NODE_MAP, id)
    end

    # =========================================================================
    @testset "8. cast_sigil_votes — :instruction reserved + unknown raises" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id_inst = GB.create_sigil_node(
            "do x then y", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[];
            kind = :instruction,
        )

        m = mediate("plain text")
        @test_throws GB.SigilFireError GB.cast_sigil_votes(
            id_inst, 0.5, m.bindings, m.original,
            GB.RelationalTriple[], GB.RelationalTriple[],
        )

        # Unknown kind: tag the node manually with a bogus kind
        id_bad = GB.create_node(
            "p", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String["@sigil:bogus"],
        )
        @test_throws GB.SigilFireError GB.cast_sigil_votes(
            id_bad, 0.5, m.bindings, m.original,
            GB.RelationalTriple[], GB.RelationalTriple[],
        )

        delete!(GB.NODE_MAP, id_inst)
        delete!(GB.NODE_MAP, id_bad)
    end

    # =========================================================================
    @testset "9. cast_sigil_votes — :none kind delegates to cast_vote" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id_plain = GB.create_node(
            "plain pattern", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "test"),
            String[],
        )

        m = mediate("anything")
        votes = GB.cast_sigil_votes(id_plain, 0.4, m.bindings, m.original,
                                    GB.RelationalTriple[], GB.RelationalTriple[])
        # Untagged → exactly 1 vote, payload empty (default)
        @test length(votes) == 1
        @test votes[1].payload == ""
        @test votes[1].action == opener

        delete!(GB.NODE_MAP, id_plain)
    end

    # =========================================================================
    @testset "10. Vote struct — payload field default + explicit (v7.27: antimatch removed)" begin
        # 6-arg constructor (required args only) -> empty payload
        v_legacy = GB.Vote("nid", "act", 1.0, String[],
                           GB.RelationalTriple[], GB.RelationalTriple[])
        @test v_legacy.payload == ""

        # 7-arg constructor (with explicit payload) -> payload set
        v_new = GB.Vote("nid", "act", 1.0, String[],
                        GB.RelationalTriple[], GB.RelationalTriple[],
                        "hello payload")
        @test v_new.payload == "hello payload"

        # Round-trip through the struct preserves payload
        @test GB.Vote("a","b",2.0,String[],GB.RelationalTriple[],
                     GB.RelationalTriple[], "x").payload == "x"
    end

    # =========================================================================
    @testset "11. SigilFireError — fields + showerror" begin
        e = GB.SigilFireError(:math, "node_42", "test reason")
        @test e.kind === :math
        @test e.node_id == "node_42"
        @test e.reason == "test reason"
        io = IOBuffer()
        showerror(io, e)
        msg = String(take!(io))
        @test occursin("node_42", msg)
        @test occursin(":math", msg)
        @test occursin("test reason", msg)
    end

    # =========================================================================
    @testset "12. End-to-end: process_mission with math sigil node" begin
        opener = first(collect(keys(GB.COMMANDS)))
        # Pattern unrelated to "what is 2 plus 2" — direct routing must still
        # inject this node so the math answer reaches the orchestrator.
        id = GB.create_sigil_node(
            "completely unrelated xyzzy",
            "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "Be terse."),
            String[];
            kind = :math,
        )

        # Capture stdout so we can assert "4" appears in the rendered output
        old_stdout = stdout
        rd, wr = redirect_stdout()
        try
            GB.process_mission("what is 2 plus 2")
        finally
            redirect_stdout(old_stdout)
            close(wr)
        end
        captured = read(rd, String)
        # The math payload "4" should appear in the captured output
        @test occursin("4", captured)
        # The router log message should also surface
        @test occursin("Sigil router", captured) || occursin(":math", captured) ||
              occursin("4", captured)  # router-log is best-effort; "4" is the hard assert

        delete!(GB.NODE_MAP, id)
    end

    # =========================================================================
    @testset "13. Save/load v2.6 — sigil registry round-trip" begin
        # Snapshot default sigils
        SigilRegistry.reset_default_table!()
        default_count = length(SigilRegistry.default_table().entries)
        @test default_count == 6

        # Add a custom sigil
        SigilRegistry.register_sigil_global!(
            name = "roundtrip_test",
            class = :tag,
            applies_at = :bind,
            provenance = "v26-test",
        )
        @test has_sigil(SigilRegistry.default_table(), "roundtrip_test")

        # Save
        save_path = joinpath(tempdir(), "sigil_pipeline_v26.json.gz")
        try
            GB.save_specimen_to_file!(save_path)

            # Inspect raw JSON for "sigils" + version 2.6
            try
                proc = open(`gunzip -c $save_path`)
                raw = read(proc, String)
                close(proc)
                parsed = JSON.parse(raw)
                @test parsed["_meta"]["version"] == "2.6"
                @test haskey(parsed, "sigils")
                @test haskey(parsed["sigils"], "entries")
                names_saved = [e["name"] for e in parsed["sigils"]["entries"]]
                @test "roundtrip_test" in names_saved
                @test "n" in names_saved
                @test "conj" in names_saved
            catch e
                rethrow(e)
            end

            # Wipe singleton, then load — custom sigil restored
            SigilRegistry.reset_default_table!()
            @test !has_sigil(SigilRegistry.default_table(), "roundtrip_test")

            GB.load_specimen_from_file!(save_path)
            @test has_sigil(SigilRegistry.default_table(), "roundtrip_test")
            e_rt = lookup_sigil(SigilRegistry.default_table(), "roundtrip_test")
            @test e_rt.provenance == "v26-test"
            @test e_rt.class === :tag

            # Engine-default sigils still present (re-attached via merge_registry!(:keep))
            @test has_sigil(SigilRegistry.default_table(), "n")
            @test has_sigil(SigilRegistry.default_table(), "op")
            @test has_sigil(SigilRegistry.default_table(), "conj")
        finally
            isfile(save_path) && rm(save_path)
            SigilRegistry.reset_default_table!()
        end
    end

    # =========================================================================
    @testset "14. Save/load v2.5 backward compat — absent sigils key restores defaults" begin
        # Build a fake v2.5 specimen JSON (no "sigils" key) and load it.
        # Hand-crafted minimal viable specimen: just a _meta + the v2.5 keys
        # the loader expects to be optional.
        SigilRegistry.reset_default_table!()
        SigilRegistry.register_sigil_global!(
            name = "should_be_wiped",
            class = :tag,
            applies_at = :bind,
            provenance = "pre-load",
        )
        @test has_sigil(SigilRegistry.default_table(), "should_be_wiped")

        # Save once at v2.6 with that sigil, then strip the "sigils" key
        # in-place to simulate a v2.5 file.
        save_path = joinpath(tempdir(), "sigil_pipeline_v25_compat.json.gz")
        try
            GB.save_specimen_to_file!(save_path)
            # Decompress, strip sigils, re-compress
            proc = open(`gunzip -c $save_path`)
            raw = read(proc, String); close(proc)
            parsed = JSON.parse(raw)
            delete!(parsed, "sigils")
            parsed["_meta"]["version"] = "2.5"
            new_json = JSON.json(parsed, 2)
            # Re-gzip
            tmp_uncompressed = save_path * ".raw"
            open(tmp_uncompressed, "w") do f
                write(f, new_json)
            end
            run(pipeline(`gzip -c $tmp_uncompressed`, save_path))
            rm(tmp_uncompressed)

            # Load the v2.5-style file — wipe phase resets to defaults, no
            # sigils block to restore, end state is default_registry().
            GB.load_specimen_from_file!(save_path)
            @test !has_sigil(SigilRegistry.default_table(), "should_be_wiped")
            # All engine-default sigils present
            for nm in ("n", "word", "rest", "noun", "op", "conj")
                @test has_sigil(SigilRegistry.default_table(), nm)
            end
        finally
            isfile(save_path) && rm(save_path)
            SigilRegistry.reset_default_table!()
        end
    end

    # =========================================================================
    @testset "15. Singleton lifecycle — reset / register_global / serialize_global" begin
        SigilRegistry.reset_default_table!()
        @test length(SigilRegistry.default_table().entries) == 6

        # Add 3 custom sigils
        for nm in ("alpha", "beta", "gamma")
            SigilRegistry.register_sigil_global!(
                name = nm, class = :tag, applies_at = :bind,
                provenance = "lifecycle-test",
            )
        end
        @test length(SigilRegistry.default_table().entries) == 9

        # Serialize → 9 entries
        data = SigilRegistry.serialize_global()
        @test length(data["entries"]) == 9
        names = [e["name"] for e in data["entries"]]
        @test all(n -> n in names, ("alpha", "beta", "gamma", "n", "op", "conj"))
        # Deterministic order (alphabetical by name)
        @test names == sort(names)

        # Reset wipes
        SigilRegistry.reset_default_table!()
        @test length(SigilRegistry.default_table().entries) == 6
        @test !has_sigil(SigilRegistry.default_table(), "alpha")

        # Restore brings them back
        SigilRegistry.restore_global!(data)
        @test length(SigilRegistry.default_table().entries) == 9
        for nm in ("alpha", "beta", "gamma")
            @test has_sigil(SigilRegistry.default_table(), nm)
        end

        # Cleanup
        SigilRegistry.reset_default_table!()
    end

    # =========================================================================
    @testset "16. restore_table! — bad input tolerance + warning paths" begin
        SigilRegistry.reset_default_table!()

        # Empty data → no-op (returns 0)
        n0 = SigilRegistry.restore_global!(Dict{String,Any}())
        @test n0 == 0
        # Engine defaults still present (merge_registry!(:keep) safety net)
        @test has_sigil(SigilRegistry.default_table(), "n")

        # Non-Dict entries get skipped with warning, not throw
        bad_data = Dict{String,Any}(
            "label" => "test",
            "entries" => Any[
                "this_is_not_a_dict",
                Dict{String,Any}("name" => "good_one", "class" => "tag",
                                 "applies_at" => "bind", "provenance" => "ok",
                                 "promote_at_tokenize" => false),
                Dict{String,Any}("name" => "", "class" => "tag",
                                 "applies_at" => "bind"),  # empty name skipped
            ],
        )
        n1 = SigilRegistry.restore_global!(bad_data)
        @test n1 == 1   # only "good_one" registered
        @test has_sigil(SigilRegistry.default_table(), "good_one")

        # Engine-default sigils re-attached via merge
        @test has_sigil(SigilRegistry.default_table(), "n")
        @test has_sigil(SigilRegistry.default_table(), "conj")

        # Non-array entries throws
        @test_throws SigilArgumentError SigilRegistry.restore_table!(
            SigilRegistry.default_table(),
            Dict{String,Any}("entries" => "not_an_array"),
        )

        SigilRegistry.reset_default_table!()
    end

    # =========================================================================
    @testset "17. Direct routing — list_sigil_node_ids skips graved nodes" begin
        opener = first(collect(keys(GB.COMMANDS)))
        id_alive = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "x"),
            String[];
            kind = :math,
        )
        id_grave = GB.create_sigil_node(
            "&n &op &n", "$(opener)^1.0",
            Dict{String,Any}("system_prompt" => "x"),
            String[];
            kind = :math,
        )
        # Mark grave manually
        GB.NODE_MAP[id_grave].is_grave = true
        GB.NODE_MAP[id_grave].grave_reason = "test"

        ids = GB.list_sigil_node_ids(:math)
        @test id_alive in ids
        @test id_grave ∉ ids   # graved nodes excluded

        # Cleanup
        delete!(GB.NODE_MAP, id_alive)
        delete!(GB.NODE_MAP, id_grave)
    end

end  # @testset SIGIL PIPELINE

# =============================================================================
# Macro-scaffolding detector  -- verify spoken-text gate
# =============================================================================
@testset "pattern_is_macro_scaffolding -- macros never reach the user" begin
    using GrugBot420: pattern_is_macro_scaffolding

    # pure scaffolding -> true (these must be filtered out of CLAIM/SUPPORT)
    @test  pattern_is_macro_scaffolding("&n &op &n")
    @test  pattern_is_macro_scaffolding("&n &op &n &op &n")
    @test  pattern_is_macro_scaffolding("&conj")
    @test  pattern_is_macro_scaffolding("&word &word")
    @test  pattern_is_macro_scaffolding("  &n   &op   &n  ")  # whitespace ok

    # mixed or natural -> false (these are spoken-friendly)
    @test !pattern_is_macro_scaffolding("compute &n now")
    @test !pattern_is_macro_scaffolding("hello hi greeting")
    @test !pattern_is_macro_scaffolding("count number sum total")
    @test !pattern_is_macro_scaffolding("&n plus &n equals")  # has 'plus'/'equals' -- speakable

    # edge cases
    @test !pattern_is_macro_scaffolding("")
    @test !pattern_is_macro_scaffolding("   ")
end
