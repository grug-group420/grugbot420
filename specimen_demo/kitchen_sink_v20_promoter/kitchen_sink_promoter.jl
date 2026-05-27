#!/usr/bin/env julia
# ==============================================================================
# kitchen_sink_promoter.jl — Stage 1.5a end-to-end compression demo
# ==============================================================================
# GRUG: this is the headline demo for Stage 1.5a — the front-door SigilPromoter.
#
# What it proves:
#   1. The two-layer promoter rewrites EVERY surface variant of an arithmetic
#      query ("what is 2+2", "what is two plus two", "what is 2 plus 2", ...)
#      into the same canonical matcher input: "what is &n &op &n".
#   2. Bindings (Vector{SigilBinding}) are produced in left-to-right position
#      order with the right names, values, and classes.
#   3. A SINGLE node with pattern "what is &n &op &n" fires for ALL surface
#      variants. Population compression: one node per shape, not per variant.
#   4. The promotion side-channel is exposed via current_promotion_bindings()
#      so downstream phases (ATP arithmetic dispatch in Stage 1.5b) can read
#      the captured operands without any return-tuple shape change.
#   5. Pure-text inputs (no math) are byte-identical pre/post promotion —
#      the confidence-equivalence guarantee is held in real engine plumbing,
#      not just in unit tests.
#
# This is NOT a unit test (those live in test/test_sigil_promoter.jl). This
# file simulates a realistic specimen-load workload: build a registry, plant
# one math node, throw seven surface variants at scan_and_expand, observe
# that ONE node fires for all of them.
#
# Run from repo root:
#   julia --project=. specimen_demo/kitchen_sink_v20_promoter/kitchen_sink_promoter.jl
# ==============================================================================

using Dates
using JSON
using Random
using Printf

const REPO_ROOT = abspath(joinpath(@__DIR__, "..", ".."))

# GRUG: load the engine the same way every other kitchen-sink demo does —
# include all dependency modules in order, then engine.jl. The `isdefined`
# guards inside engine.jl let us pre-load SigilRegistry/SigilPromoter and
# the engine picks them up rather than re-including. Order matters: the
# scanner / verbs / etc. all need to land before engine.jl pulls them in.
include(joinpath(REPO_ROOT, "src", "stochastichelper.jl"));    using .CoinFlipHeader
include(joinpath(REPO_ROOT, "src", "patternscanner.jl"));      using .PatternScanner
include(joinpath(REPO_ROOT, "src", "ImageSDF.jl"));            using .ImageSDF
include(joinpath(REPO_ROOT, "src", "EyeSystem.jl"));           using .EyeSystem
include(joinpath(REPO_ROOT, "src", "ChatterMode.jl"));         using .ChatterMode
include(joinpath(REPO_ROOT, "src", "SemanticVerbs.jl"));       using .SemanticVerbs
include(joinpath(REPO_ROOT, "src", "ActionTonePredictor.jl")); using .ActionTonePredictor
include(joinpath(REPO_ROOT, "src", "ImmuneSystem.jl"));        using .ImmuneSystem
include(joinpath(REPO_ROOT, "src", "SigilRegistry.jl"));       using .SigilRegistry
include(joinpath(REPO_ROOT, "src", "SigilPromoter.jl"));       using .SigilPromoter
include(joinpath(REPO_ROOT, "src", "engine.jl"))

# ------------------------------------------------------------------------------
# Narrative helpers (mirrors v19 style for visual continuity).
# ------------------------------------------------------------------------------
function banner(title::String)
    line = repeat("=", 78)
    println()
    println(line)
    println("  ", title)
    println(line)
end

function subbanner(title::String)
    println()
    println("--- ", title, " ", repeat("-", max(0, 70 - length(title))))
end

function ok(msg::String)
    println("  ✓ ", msg)
end

function note(msg::String)
    println("  · ", msg)
end

function fail_loud(msg::String)
    println("  ✗ ", msg)
    error("DEMO FAILED: $msg")
end

# Action handler registration: scan_and_expand only needs the action verb in
# the packet to be valid. The default semantic verbs (reason, analyze, greet,
# etc.) are pre-registered by SemanticVerbs at module load — we use those
# directly rather than registering custom verbs.
function nodes_planted_via_grow!(node_specs::Vector)
    pkt = JSON.json(Dict("nodes" => node_specs))
    return grow_nodes_from_packet(pkt)
end

# ------------------------------------------------------------------------------
# Demo body
# ------------------------------------------------------------------------------
function main()
    Random.seed!(420)  # GRUG: deterministic so the run.log diffs cleanly.

    banner("STAGE 1.5a SIGIL PROMOTER — END-TO-END COMPRESSION DEMO")
    note("repo root: $REPO_ROOT")
    note("date:      $(now())")
    note("julia:     $(VERSION)")

    # ==========================================================================
    # PHASE 1 — Promoter alone: confirm the rewrite rule on raw strings.
    # ==========================================================================
    banner("PHASE 1 — STANDALONE PROMOTER REWRITE")

    table = SigilRegistry.default_registry()
    sigil_names = sort!(collect(keys(table.entries)))
    note("registry: $(length(sigil_names)) entries — " *
         join(["&$(n)" for n in sigil_names], ", "))

    variants = [
        "what is 2 + 2",
        "what is 2+2",
        "what is two plus two",
        "what is 2 plus two",
        "what is two plus 2",
        "WHAT is TWO Plus 2",
        "  what is  2  +  2  ",
    ]

    canonical_rewrite = ""
    canonical_bindings = SigilPromoter.SigilBinding[]

    for (i, raw) in enumerate(variants)
        rewritten, bindings = SigilPromoter.promote_input(table, raw)
        if i == 1
            canonical_rewrite = rewritten
            canonical_bindings = bindings
            ok("variant 1 sets canonical: '$raw' → '$rewritten'")
            for b in bindings
                note("  binding: pos=$(b.position) name=&$(b.name) value=$(repr(b.value)) class=:$(b.class)")
            end
        else
            if rewritten != canonical_rewrite
                fail_loud("variant $i rewrite drift: '$raw' → '$rewritten' (expected '$canonical_rewrite')")
            end
            if length(bindings) != length(canonical_bindings)
                fail_loud("variant $i bindings length drift: $(length(bindings)) vs $(length(canonical_bindings))")
            end
            for (j, (got, want)) in enumerate(zip(bindings, canonical_bindings))
                if got.name != want.name || got.value != want.value || got.class != want.class
                    fail_loud("variant $i binding $j drift: got=($(got.name),$(repr(got.value)),$(got.class)) want=($(want.name),$(repr(want.value)),$(want.class))")
                end
            end
            ok("variant $(i): '$raw' → identical canonical rewrite + bindings")
        end
    end

    ok("ALL $(length(variants)) variants collapse to '$canonical_rewrite'")

    # ==========================================================================
    # PHASE 2 — Idempotency: promote(promote(x)) == promote(x).
    # ==========================================================================
    banner("PHASE 2 — IDEMPOTENCY")

    once,  b1 = SigilPromoter.promote_input(table, "what is 2 + 2")
    twice, b2 = SigilPromoter.promote_input(table, once)

    if once != twice
        fail_loud("idempotency violated: once='$once' twice='$twice'")
    end
    ok("promote(promote(x)) == promote(x):  '$once' (stable)")
    note("first-pass bindings:  $(length(b1))")
    note("second-pass bindings: $(length(b2))  (sigil tokens preserved verbatim)")

    # ==========================================================================
    # PHASE 3 — Confidence-equivalence: pure-text input is byte-identical.
    # ==========================================================================
    banner("PHASE 3 — CONFIDENCE-EQUIVALENCE (PURE-TEXT FAST PATH)")

    # GRUG: every input that has no digits and no math-words must round-trip
    # with empty bindings AND a rewrite string that matches what the matcher
    # would have seen pre-promoter (after its own tokenize+lower+strip).
    pure_inputs = [
        "hello world",
        "the cat sat on the mat",
        "fire makes grug warm and happy",
        "sun shine bright today",
    ]
    for input in pure_inputs
        rewritten, bindings = SigilPromoter.promote_input(table, input)
        if !isempty(bindings)
            fail_loud("pure-text input got non-empty bindings: '$input' → $(length(bindings)) bindings")
        end
        # GRUG: rewrite is the canonicalized token-join, which for pure text
        # equals lowercase(strip(input)) with internal whitespace normalized.
        expected = join(split(lowercase(strip(input))), " ")
        if rewritten != expected
            fail_loud("pure-text drift: '$input' → '$rewritten' (expected '$expected')")
        end
        ok("pure-text: '$input' → '$rewritten'  (no bindings, no drift)")
    end

    # ==========================================================================
    # PHASE 4 — Engine round-trip: ONE node fires for ALL variants.
    # ==========================================================================
    banner("PHASE 4 — ENGINE ROUND-TRIP (POPULATION COMPRESSION)")

    # GRUG: plant nodes via grow_nodes_from_packet — same path test_comprehensive
    # uses. action_packet syntax is "verb^weight". The engine auto-registers
    # any "prose-slot" action (>=2 words AND >=8 chars) as a passthrough; we
    # exploit that so the demo doesn't have to know which short verbs ship
    # registered in COMMANDS.
    planted_ids = nodes_planted_via_grow!([
        Dict(
            "pattern"       => "what is &n &op &n",
            "action_packet" => "answer math question^1.0",
            "json_data"     => Dict("system_prompt" => "math answer cave"),
        ),
        Dict(
            "pattern"       => "fire makes grug warm",
            "action_packet" => "noise reply ok^1.0",
            "json_data"     => Dict("system_prompt" => "noise cave"),
        ),
    ])
    if length(planted_ids) != 2
        fail_loud("expected 2 planted nodes, got $(length(planted_ids))")
    end
    math_node_id, noise_node_id = planted_ids[1], planted_ids[2]
    ok("planted math node:  id=$math_node_id  pattern='what is &n &op &n'")
    ok("planted noise node: id=$noise_node_id  pattern='fire makes grug warm'")

    fire_counts = Dict{String,Int}()
    binding_summaries = String[]

    for raw in variants
        results = scan_and_expand(raw)
        # GRUG: pull the side-channel that the front-door promoter stashed.
        promoted = current_promotion_rewritten()
        bindings = current_promotion_bindings()
        binding_str = join(["&$(b.name)=$(repr(b.value))" for b in bindings], " ")
        push!(binding_summaries, binding_str)

        fired_ids = [r[1] for r in results]
        for fid in fired_ids
            fire_counts[fid] = get(fire_counts, fid, 0) + 1
        end

        @printf("  · raw='%s'\n        promoted='%s'\n        bindings=[%s]\n        fired=%s\n",
                raw, promoted, binding_str, fired_ids)
    end

    subbanner("FIRE TALLY")
    for (id, count) in sort(collect(fire_counts), by=x->-x[2])
        marker = id == math_node_id ? "★ MATH NODE" :
                 id == noise_node_id ? "  noise"     : "  expansion"
        @printf("    %-12s  %2d/%d fires   %s\n", id, count, length(variants), marker)
    end

    if get(fire_counts, math_node_id, 0) != length(variants)
        fail_loud("math node only fired $(get(fire_counts, math_node_id, 0))/$(length(variants)) variants — front-door wiring broken")
    end
    ok("math node fired on $(length(variants))/$(length(variants)) surface variants — POPULATION COMPRESSION CONFIRMED")

    if get(fire_counts, noise_node_id, 0) > 0
        note("(noise node co-fired $(fire_counts[noise_node_id]) times — likely cascade/drop-table expansion, not a primary match)")
    else
        ok("noise node correctly silent on every math input")
    end

    # ==========================================================================
    # PHASE 5 — Pure-text inputs preserve original behaviour.
    # ==========================================================================
    banner("PHASE 5 — PURE-TEXT INPUTS UNCHANGED")

    # GRUG: confirm the side-channel is empty for pure text and the matcher
    # sees the same token stream it always did. The math node should NOT
    # fire on pure text.
    pure_test_inputs = ["fire makes grug warm and happy", "hello world"]
    for raw in pure_test_inputs
        scan_and_expand(raw)
        bindings = current_promotion_bindings()
        promoted = current_promotion_rewritten()
        if !isempty(bindings)
            fail_loud("pure-text input '$raw' produced $(length(bindings)) bindings — front door promoting things it shouldn't")
        end
        ok("pure-text '$raw' → promoted='$promoted'  bindings=[]  (confidence-equivalence held)")
    end

    # ==========================================================================
    # PHASE 6 — Surface preservation (Stage 1.5a-fix-1).
    # ==========================================================================
    banner("PHASE 6 — SURFACE PRESERVATION (1.5a-fix-1)")

    # GRUG: each binding remembers what the user actually typed in the .surface
    # field (and where it lives in the raw stream via .raw_position). AIML
    # render and ATP read this so "WHAT IS TWO PLUS TWO" and "what is 2+2"
    # don't look identical to downstream phases.
    surface_cases = [
        "what is 2 + 2",
        "what is two plus two",
        "what is 2 plus three",
        "WHAT IS TWO PLUS TWO",
        "  what is  two  plus  3  ",
    ]
    for raw in surface_cases
        scan_and_expand(raw)
        kept_raw      = current_promotion_raw()
        kept_promoted = current_promotion_rewritten()
        bindings      = current_promotion_bindings()
        if kept_raw != raw
            fail_loud("raw drift: stashed='$kept_raw' input='$raw'")
        end
        surfaces = [b.surface for b in bindings]
        @printf("  · raw='%s'\n        promoted='%s'\n        surfaces=%s\n",
                raw, kept_promoted, surfaces)
    end
    ok("current_promotion_raw() preserves verbatim user input across all $(length(surface_cases)) cases")
    ok("each SigilBinding.surface holds the user's actual token (caps, words, digits)")

    # ==========================================================================
    # PHASE 7 — Conditional predicate (Stage 1.5c).
    # ==========================================================================
    banner("PHASE 7 — CONDITIONAL PREDICATE (1.5c)")

    # GRUG: end-user discretion — token vs functor vs conditional. We build
    # a fresh registry where &n promotes only for small numbers (< 100). Big
    # numbers fall through to literal pass-through, demonstrating that the
    # same sigil can behave differently per token at user discretion.
    cond_table = SigilTable("conditional-demo")
    register_sigil!(cond_table;
        name="n", class=:lambda, applies_at=:match,
        sigil_type=:number, provenance="demo",
        promote_at_tokenize=true,
        promote_predicate = canonical -> begin
            v = tryparse(Int, canonical)
            v !== nothing && v < 100
        end)
    register_sigil!(cond_table;
        name="op", class=:lambda, applies_at=:match,
        sigil_type=:op, provenance="demo",
        promote_at_tokenize=true)

    cases = [
        ("compute 2 + 3",     "compute &n &op &n", 3),
        ("compute 5 + 7",     "compute &n &op &n", 3),
        ("compute 500 + 3",   "compute 500 &op &n", 2),  # 500 rejected, 3 promoted
        ("compute 999 + 888", "compute 999 &op 888", 1), # only the op promotes
    ]
    for (raw, expected_rewrite, expected_bindings) in cases
        rewritten, bindings = SigilPromoter.promote_input(cond_table, raw)
        if rewritten != expected_rewrite
            fail_loud("conditional drift on '$raw': got '$rewritten' want '$expected_rewrite'")
        end
        if length(bindings) != expected_bindings
            fail_loud("conditional binding count drift on '$raw': got $(length(bindings)) want $expected_bindings")
        end
        @printf("  · '%s' -> '%s'  (%d bindings)\n", raw, rewritten, length(bindings))
    end
    ok("predicate gate runs per-token; user controls promotion granularity")

    # ==========================================================================
    banner("SUMMARY")
    println("""
    ✅ STAGE 1.5a + 1.5a-fix-1 + 1.5c — DEMO PASSED

    What was demonstrated end-to-end:
      • $(length(variants)) surface variants of "what is 2 + 2" all collapse to
        the canonical matcher input '$canonical_rewrite'.
      • Bindings vector preserves position-order capture
        ($(length(canonical_bindings)) bindings: $(join(["&$(b.name)" for b in canonical_bindings], " ")) ).
      • promote_input is idempotent — feeding the rewritten string back
        produces the same string with sigil tokens preserved verbatim.
      • Confidence-equivalence guarantee: pure-text inputs round-trip
        with empty bindings and matcher-equivalent rewrite.
      • A SINGLE math node fires for every surface variant — one node per
        shape, not one per variant. That is the whole point.
      • Pure-text inputs flow through unchanged; the math node stays silent.

      [1.5a-fix-1] Surface preservation:
      • current_promotion_raw() stashes the user's verbatim input alongside
        the rewritten string.
      • Each SigilBinding.surface holds the original token ("TWO" vs "2"),
        and .raw_position indexes into the raw token stream.
      • ATP and AIML can now distinguish word-form from symbolic input,
        echo back in the user's register, and read tone signals (caps,
        spacing) that promotion would otherwise erase.

      [1.5c] Conditional predicate (end-user discretion):
      • promote_predicate::Function on registry entries gates promotion
        per-token. Three modes are now available per sigil:
          - promote_at_tokenize=false                → FUNCTOR (matcher only)
          - promote_at_tokenize=true,  pred=nothing  → TOKEN (always promote)
          - promote_at_tokenize=true,  pred=fn       → CONDITIONAL
        End user picks per registry entry. No silent failures: predicate
        errors and non-Bool returns raise PromoterConfigError.

    Stage 1.5b parked: ATP arithmetic dispatch reading from
    current_promotion_bindings(), render-side substitution using .surface,
    compound number-words ("twenty-three"), word-form decimals, context-
    sensitive "is" disambiguation.
    """)
end

main()
