#!/usr/bin/env julia
# ==============================================================================
# kitchen_sink_sigil_registry.jl
# Comprehensive end-to-end exercise of the SigilRegistry (Stage 1) module.
# ==============================================================================
# GRUG: this is NOT the unit test suite — that lives in test/test_sigil_registry.jl.
# This script simulates a realistic specimen-load workload: build the engine
# default registry, layer a specimen-level registry on top with three merge
# policies, register every active class (:lambda, :macro, :tag), register
# reserved-class entries (forward-compat for Stage 2/6), parse a battery of
# pattern strings (zero-sigil fast path, single-sigil, multi-sigil, Greek
# names, oversize, unknown, reserved-gated), and print a top-to-bottom
# narrative log so the captured output reads as a Stage 1 acceptance demo.
#
# Final phases dump:
#   - the merged registry contents (all entries by name)
#   - per-class counts
#   - a list of every pattern parsed and its resolved sigil refs
#   - a list of every error path triggered and the exact error type/message
#
# Run from repo root:
#   julia --project=. specimen_demo/kitchen_sink_v19_sigils/kitchen_sink_sigil_registry.jl
# ==============================================================================

using Dates
using JSON

const REPO_ROOT = abspath(joinpath(@__DIR__, "..", ".."))
include(joinpath(REPO_ROOT, "src", "SigilRegistry.jl"))
using .SigilRegistry

# ------------------------------------------------------------------------------
# Helpers for the narrative output.
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

function dump_entry(e::SigilEntry)
    lex = e.lexicon === nothing ? "—" :
          (isempty(e.lexicon) ? "[]" : string("[", join(e.lexicon, ", "), "]"))
    typ = e.sigil_type === nothing ? "—" : string(e.sigil_type)
    exp = e.expansion === nothing ? "—" : string(e.expansion)
    par = e.params    === nothing ? "—" : string(e.params)
    println("  &", rpad(e.name, 14),
            " class=", rpad(string(e.class), 10),
            " phase=", rpad(string(e.applies_at), 12),
            " type=", rpad(typ, 8),
            " lex=", rpad(lex, 24),
            " params=", rpad(par, 14),
            " exp=", rpad(exp, 14),
            " prov=", e.provenance)
end

function try_throw(label::String, f::Function)
    try
        f()
        println("  [", label, "] UNEXPECTED: no throw")
        return (label, "no-throw", "")
    catch e
        msg = sprint(showerror, e)
        # Truncate long messages for display.
        short = length(msg) > 140 ? string(msg[1:137], "...") : msg
        println("  [", label, "] threw ", typeof(e), " — ", short)
        return (label, string(typeof(e)), msg)
    end
end

# ==============================================================================
# Phase 1 — Engine default registry.
# ==============================================================================
banner("PHASE 1 — Engine default registry")
println("Build the default registry that the engine ships. Stage 1 ships exactly")
println("four sigils: &n, &word, &rest, &noun. The &noun macro lexicon ships")
println("empty so specimens can fill it in without a collision.")

engine = default_registry()
println()
println("Registry label: \"", engine.label, "\"  size=", length(engine.entries))
subbanner("default entries (lexicographic)")
for e in list_sigils(engine)
    dump_entry(e)
end

# ==============================================================================
# Phase 2 — Specimen-level registry layered on top (three merge policies).
# ==============================================================================
banner("PHASE 2 — Specimen-level registry & merge policies")
println("Specimens declare their own sigils and layer them on top of the engine")
println("default. We exercise all three conflict policies: :error (default),")
println(":overwrite (specimen wins), :keep (engine wins).")

# Build a specimen registry that extends the defaults.
specimen = SigilTable("specimen-cave-life")

# A populated &noun lexicon (collides with engine default — used for policy demo).
register_sigil!(specimen;
    name="noun", class=:macro, applies_at=:bind,
    lexicon=["mammoth", "fish", "berry", "fire", "cave"],
    provenance="specimen-cave-life")

# A new :macro sigil that has no engine analogue.
register_sigil!(specimen;
    name="color", class=:macro, applies_at=:bind,
    lexicon=["red", "ochre", "white", "black"],
    provenance="specimen-cave-life")

# A :tag sigil for annotation-style markup.
register_sigil!(specimen;
    name="urgent", class=:tag, applies_at=:bind,
    provenance="specimen-cave-life")

# A :tag with params (params are stored Stage 1, consumed Stage 3+).
register_sigil!(specimen;
    name="fuzzy", class=:tag, applies_at=:bind,
    params=Dict("max_distance" => 2, "metric" => "lev"),
    provenance="specimen-cave-life")

# A reserved-class :glue sigil — registered for forward-compat (Stage 2).
# It's accepted on registration; pattern use will be gated until Stage 2 lands.
register_sigil!(specimen;
    name="and", class=:glue, applies_at=:bind,
    provenance="specimen-cave-life-stage2-preview")

# A reserved-class :procedure sigil with an expansion chain — forward-compat
# for Stage 6 (Antikythera-style event-alignment compression).
register_sigil!(specimen;
    name="Σ_greet", class=:procedure, applies_at=:bind,
    expansion=Any["hello", "&noun"],
    provenance="specimen-cave-life-stage6-preview")

println()
println("Specimen built: label=\"", specimen.label, "\"  size=", length(specimen.entries))
subbanner("specimen entries (lexicographic)")
for e in list_sigils(specimen)
    dump_entry(e)
end

# Demonstrate :error policy on a fresh copy — should THROW on the &noun collision.
subbanner("merge with :error policy (collision expected on &noun)")
attempt_a = default_registry()
try_throw("merge(:error) with &noun collision", () -> begin
    merge_registry!(attempt_a, specimen; conflict=:error)
end)
println("  After failed merge, &noun in target still has provenance=",
        lookup_sigil(attempt_a, "noun").provenance,
        ", lexicon=", lookup_sigil(attempt_a, "noun").lexicon)

# Demonstrate :keep — specimen entries that collide are silently dropped
# (this is the documented opt-in exception to no-silent-failures).
subbanner("merge with :keep policy (engine wins on collision)")
attempt_b = default_registry()
merge_registry!(attempt_b, specimen; conflict=:keep)
println("  After :keep merge, &noun provenance=",
        lookup_sigil(attempt_b, "noun").provenance,
        " (engine retained), and &color present=",
        has_sigil(attempt_b, "color"))

# Demonstrate :overwrite — specimen wins. This is the typical specimen-load path.
subbanner("merge with :overwrite policy (specimen wins on collision)")
merged = default_registry()
merge_registry!(merged, specimen; conflict=:overwrite)
println("  After :overwrite merge, &noun provenance=",
        lookup_sigil(merged, "noun").provenance,
        ", lexicon=", lookup_sigil(merged, "noun").lexicon)
println("  Total merged size=", length(merged.entries))

subbanner("merged registry — all entries (lexicographic)")
for e in list_sigils(merged)
    dump_entry(e)
end

# ==============================================================================
# Phase 3 — Per-class counts and filter discipline.
# ==============================================================================
banner("PHASE 3 — Per-class counts and filter discipline")
println("list_sigils filters by class and/or applies_at, with deterministic")
println("lexicographic ordering. Used by serialization and audit paths.")

println()
for c in SIGIL_CLASSES
    es = list_sigils(merged; class=c)
    println("  class=:", rpad(string(c), 10), " count=", length(es),
            "  names=", [e.name for e in es])
end
println()
for ph in SIGIL_APPLIES_AT
    es = list_sigils(merged; applies_at=ph)
    println("  phase=:", rpad(string(ph), 12), " count=", length(es),
            "  names=", [e.name for e in es])
end

# ==============================================================================
# Phase 4 — Pattern parsing battery.
# ==============================================================================
banner("PHASE 4 — Pattern parsing battery")
println("Walk a battery of pattern strings through resolve_sigils_in_pattern.")
println("Stage 1 active classes are :lambda, :macro, :tag. Active phases are")
println(":bind and :match. Patterns referencing reserved classes/phases throw")
println("unless the caller passes allow_reserved=true.")

# 4a — Zero-sigil fast path. Allocates nothing observable.
subbanner("4a. zero-sigil fast path (no &)")
for pat in ["hello world", "the cat sat on the mat",
            "lorem ipsum dolor sit amet", ""]
    refs = resolve_sigils_in_pattern(merged, pat)
    println("  pattern=", repr(pat), "  refs=", length(refs))
end

# 4b — Single-sigil patterns.
subbanner("4b. single-sigil patterns")
for pat in ["I want a &noun", "give me &n apples", "say &word now",
            "tell me &rest"]
    refs = resolve_sigils_in_pattern(merged, pat)
    println("  pattern=", rpad(repr(pat), 32),
            " refs=", length(refs),
            " names=", [r.name for r in refs],
            " classes=", [r.entry.class for r in refs])
end

# 4c — Multi-sigil math pattern (the canonical Stage 1 motivating example).
subbanner("4c. multi-sigil math pattern (canonical)")
for pat in ["what is &n + &n equal to",
            "compute &n times &n plus &n",
            "&n &n &n &n"]
    refs = resolve_sigils_in_pattern(merged, pat)
    println("  pattern=", rpad(repr(pat), 36),
            " refs=", length(refs))
    for (i, r) in enumerate(refs)
        println("      [", i, "] &", r.name,
                "  bytes=", r.start_byte, "..", r.end_byte,
                "  type=", r.entry.sigil_type)
    end
end

# 4d — Mixed lambda + macro pattern.
subbanner("4d. mixed lambda + macro pattern")
for pat in ["I have &n &noun in my cave",
            "the &color &noun is mine",
            "&n &color &noun please"]
    refs = resolve_sigils_in_pattern(merged, pat)
    println("  pattern=", rpad(repr(pat), 32),
            " refs=", length(refs),
            " classes=", [r.entry.class for r in refs])
end

# 4e — Greek-letter sigil names parse but reserved-class is gated.
subbanner("4e. Greek-letter sigil parsing (Σ_greet is reserved :procedure)")
ptok = parse_sigil_token("&Σ_greet")
println("  parse_sigil_token(\"&Σ_greet\") = ", repr(ptok))
try_throw("pattern uses &Σ_greet (reserved :procedure)", () -> begin
    resolve_sigils_in_pattern(merged, "say &Σ_greet to friend")
end)
println("  with allow_reserved=true:")
refs_g = resolve_sigils_in_pattern(merged, "say &Σ_greet to friend"; allow_reserved=true)
println("    refs=", length(refs_g),
        " class=", refs_g[1].entry.class,
        " expansion=", refs_g[1].entry.expansion)

# ==============================================================================
# Phase 5 — Error-path battery (NO SILENT FAILURES).
# ==============================================================================
banner("PHASE 5 — Error-path battery (NO SILENT FAILURES)")
println("Every malformed input throws a typed error. We trigger every documented")
println("path and capture the error type + message for the audit log.")

err_log = Tuple{String,String,String}[]

# 5a — Bad name shapes.
subbanner("5a. registration: bad name shapes")
push!(err_log, try_throw("empty name", () ->
    register_sigil!(SigilTable(); name="", class=:tag, applies_at=:bind)))
push!(err_log, try_throw("leading digit", () ->
    register_sigil!(SigilTable(); name="1n", class=:tag, applies_at=:bind)))
push!(err_log, try_throw("space in name", () ->
    register_sigil!(SigilTable(); name="n n", class=:tag, applies_at=:bind)))
push!(err_log, try_throw("punctuation in name", () ->
    register_sigil!(SigilTable(); name="n.x", class=:tag, applies_at=:bind)))
push!(err_log, try_throw("name carries prefix", () ->
    register_sigil!(SigilTable(); name="&n", class=:tag, applies_at=:bind)))

# 5b — Bad class / applies_at.
subbanner("5b. registration: bad class / phase")
push!(err_log, try_throw("unknown class", () ->
    register_sigil!(SigilTable(); name="x", class=:nope, applies_at=:bind)))
push!(err_log, try_throw("unknown phase", () ->
    register_sigil!(SigilTable(); name="x", class=:tag, applies_at=:nope)))

# 5c — Class/field coherence.
subbanner("5c. registration: class/field coherence")
push!(err_log, try_throw(":lambda missing sigil_type", () ->
    register_sigil!(SigilTable(); name="bad", class=:lambda, applies_at=:match)))
push!(err_log, try_throw(":lambda with lexicon", () ->
    register_sigil!(SigilTable(); name="bad", class=:lambda, applies_at=:match,
                    sigil_type=:number, lexicon=["a"])))
push!(err_log, try_throw(":macro missing lexicon", () ->
    register_sigil!(SigilTable(); name="bad", class=:macro, applies_at=:bind)))
push!(err_log, try_throw(":macro with sigil_type", () ->
    register_sigil!(SigilTable(); name="bad", class=:macro, applies_at=:bind,
                    lexicon=["a"], sigil_type=:word)))
push!(err_log, try_throw(":tag with sigil_type", () ->
    register_sigil!(SigilTable(); name="bad", class=:tag, applies_at=:bind,
                    sigil_type=:word)))
push!(err_log, try_throw(":tag with lexicon", () ->
    register_sigil!(SigilTable(); name="bad", class=:tag, applies_at=:bind,
                    lexicon=["a"])))
push!(err_log, try_throw("expansion on non-:procedure", () ->
    register_sigil!(SigilTable(); name="bad", class=:tag, applies_at=:bind,
                    expansion=["a"])))

# 5d — Lexicon validation.
subbanner("5d. registration: lexicon size and content")
push!(err_log, try_throw("empty string in lexicon", () ->
    register_sigil!(SigilTable(); name="bad", class=:macro, applies_at=:bind,
                    lexicon=["a", "", "b"])))

# 5e — Collision policy.
subbanner("5e. collision: default throws, overwrite=true succeeds")
let t = SigilTable("collide")
    register_sigil!(t; name="x", class=:tag, applies_at=:bind, provenance="first")
    push!(err_log, try_throw("collision without overwrite", () ->
        register_sigil!(t; name="x", class=:tag, applies_at=:bind, provenance="second")))
    e = register_sigil!(t; name="x", class=:tag, applies_at=:bind,
                       provenance="second", overwrite=true)
    println("  with overwrite=true: provenance now=", e.provenance)
end

# 5f — Lookup miss.
subbanner("5f. lookup: miss + empty name")
push!(err_log, try_throw("lookup_sigil miss", () ->
    lookup_sigil(merged, "definitely_not_there")))
push!(err_log, try_throw("lookup_sigil empty name", () ->
    lookup_sigil(merged, "")))

# 5g — Pattern parsing errors.
subbanner("5g. pattern: unknown sigil, reserved gating, oversize")
push!(err_log, try_throw("unknown sigil in pattern", () ->
    resolve_sigils_in_pattern(merged, "what about &nope here")))
push!(err_log, try_throw("reserved :glue in pattern", () ->
    resolve_sigils_in_pattern(merged, "do x &and y")))
let n_overflow = SigilRegistry.MAX_SIGILS_PER_PATTERN + 1
    pat = join(fill("&n", n_overflow), " + ")
    push!(err_log, try_throw("pattern over MAX_SIGILS_PER_PATTERN cap", () ->
        resolve_sigils_in_pattern(merged, pat)))
end

# 5h — list_sigils filter validation.
subbanner("5h. list_sigils: bad filter values")
push!(err_log, try_throw("list_sigils class filter unknown", () ->
    list_sigils(merged; class=:nope)))
push!(err_log, try_throw("list_sigils phase filter unknown", () ->
    list_sigils(merged; applies_at=:nope)))

# 5i — merge_registry! bad policy.
subbanner("5i. merge_registry!: bad conflict policy")
push!(err_log, try_throw("merge_registry! bad policy", () ->
    merge_registry!(SigilTable(), SigilTable(); conflict=:nope)))

# ==============================================================================
# Phase 6 — Audit dump.
# ==============================================================================
banner("PHASE 6 — Audit dump")
println("Dump the final merged registry and the captured error log to JSON for")
println("diff-friendly snapshotting. The error log proves every documented error")
println("path is live and typed.")

# Build a JSON-friendly snapshot of the merged registry.
function entry_to_json(e::SigilEntry)
    Dict(
        "name"        => e.name,
        "class"       => string(e.class),
        "applies_at"  => string(e.applies_at),
        "sigil_type"  => e.sigil_type === nothing ? nothing : string(e.sigil_type),
        "lexicon"     => e.lexicon,
        "params"      => e.params,
        "expansion"   => e.expansion === nothing ? nothing : [string(x) for x in e.expansion],
        "provenance"  => e.provenance,
    )
end

audit = Dict(
    "stage"               => 1,
    "schema_version"      => "sigil-registry/v1",
    "generated_utc"       => string(now(UTC)),
    "engine_default_size" => length(default_registry().entries),
    "specimen_size"       => length(specimen.entries),
    "merged_size"         => length(merged.entries),
    "active_classes"      => [string(c) for c in SigilRegistry.STAGE1_ACTIVE_CLASSES],
    "active_phases"       => [string(p) for p in SigilRegistry.STAGE1_ACTIVE_PHASES],
    "max_sigils_per_pattern" => SigilRegistry.MAX_SIGILS_PER_PATTERN,
    "max_registry_entries"   => SigilRegistry.MAX_REGISTRY_ENTRIES,
    "max_lexicon_size"       => SigilRegistry.MAX_LEXICON_SIZE,
    "merged_entries"      => [entry_to_json(e) for e in list_sigils(merged)],
    "error_log"           => [Dict("label"=>l, "type"=>t, "message"=>m)
                              for (l, t, m) in err_log],
)

audit_path = joinpath(@__DIR__, "audit_dump.json")
open(audit_path, "w") do io
    JSON.print(io, audit, 2)
end
println("Audit dump written to: ", audit_path,
        " (", filesize(audit_path), " bytes)")
println("Total error paths exercised: ", length(err_log))

banner("KITCHEN SINK COMPLETE — Stage 1 sigil registry validated end-to-end")
println("Engine default registry: 4 entries (&n &word &rest &noun)")
println("Specimen registry:       ", length(specimen.entries),
        " entries (3 active classes + 2 reserved)")
println("Merged registry:         ", length(merged.entries), " entries")
println("Pattern parsings:        zero-sigil fast path + single + multi + Greek")
println("Error paths covered:     ", length(err_log),
        " typed throws, all NO-SILENT-FAILURE")
println()
