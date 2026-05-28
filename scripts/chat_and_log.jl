#!/usr/bin/env julia
# =============================================================================
# GRUG v2.6 -- INTERACT WITH COMPREHENSIVE SPECIMEN + LOG TO MARKDOWN
#
# Loads a saved specimen, runs a curated battery of prompts through
# `process_mission`, captures stdout per turn, and writes a Markdown log:
#
#   ## Chat
#     User/Specimen pairs in clean prose (top of file)
#
#   ## Diagnostics
#     Full brain mechanics + stats kept SEPARATE below the chat
#     (lobe status, node status, AIML status, immune status,
#      sigil registry, group registry, crystalize, tonal buildup,
#      sparse-active fire skip, subconscious, sigil mediations)
#
# Usage:
#   julia --project=. scripts/chat_and_log.jl <specimen.gz> <output.md>
# =============================================================================

if length(ARGS) < 2
    println("Usage: julia --project=. scripts/chat_and_log.jl <specimen.gz> <output.md>")
    exit(2)
end

const SPECIMEN_PATH = ARGS[1]
const LOG_PATH      = ARGS[2]

if !isfile(SPECIMEN_PATH)
    println("!!! specimen not found: $SPECIMEN_PATH")
    exit(2)
end

println("Loading GrugBot420 ...")
using GrugBot420
using Dates
const GB = GrugBot420

now_str() = string(Dates.now())

println("Loading specimen from $SPECIMEN_PATH ...")
GB.load_specimen_from_file!(SPECIMEN_PATH)
println("Specimen loaded.\n")

# =============================================================================
# capture helper -- runs `f()` while redirecting stdout to a tempfile,
# reads it back, returns the text. tempfile path is robust across child
# tasks (process_mission spawns Tasks via dispatch_task_with_timeout, and
# pipe-based redirect_stdout in Julia 1.10 doesn't always propagate to
# task-spawned writers, which silently dropped scan output between turns).
# =============================================================================
function capture_stdout(f::Function)::String
    path, io = mktemp()
    local ok = true
    local err_str = ""
    try
        redirect_stdout(io) do
            try
                f()
            catch e
                ok = false
                err_str = "ERROR: $(typeof(e))\n$(sprint(showerror, e))"
            end
            flush(io)
        end
    finally
        close(io)
    end
    txt = read(path, String)
    rm(path; force=true)
    if !ok
        txt *= "\n" * err_str
    end
    return txt
end

# =============================================================================
# curated prompts -- exercise multiple lobes + sigil rail + edge cases
# =============================================================================
const PROMPTS = [
    "hi grug",                                                    # social/greeting
    "what is two plus two",                                       # math (sigil rail)
    "what is 7 + 5",                                              # math (numeric)
    "what is 3 + 4 + 5",                                          # math triple (sigil rail)
    "tell me about danger and explain why",                       # multipart (sigil rail) + survival
    "why is the sky blue",                                        # reasoning / why
    "i feel sad and need comfort",                                # social / empathy
    "danger threat warning",                                      # survival
    "help me understand this",                                    # assistance
    "build something great and destroy what is broken",           # multipart, mixed lobes
]

# =============================================================================
# run all prompts, capturing per-turn output + per-turn quick mediation
# =============================================================================
struct Turn
    user::String
    captured::String
    mediation_kinds::Vector{Symbol}
    mediation_bindings::Int
end
turns = Turn[]

for (i, prompt) in enumerate(PROMPTS)
    println("[$i/$(length(PROMPTS))] >>> $prompt")
    # peek at sigil mediation BEFORE process_mission consumes it
    kinds = Symbol[]
    nbind = 0
    try
        med = GB.SigilMediator.mediate(prompt)
        kinds = collect(med.kinds)
        nbind = length(med.bindings)
    catch
        # mediation can be empty -- not fatal
    end
    captured = capture_stdout() do
        GB.process_mission(prompt)
    end
    push!(turns, Turn(prompt, captured, kinds, nbind))
end

# =============================================================================
# extract a clean "specimen response" line from each captured block
#
# process_mission prints lots of pipeline trace; the actual response usually
# comes out via Engine_Voice / final node fire. We try a few markers, and fall
# back to "last non-empty content line" if none match.
# =============================================================================
function extract_response(captured::AbstractString)::String
    lines = split(captured, '\n')

    # The cave's user-visible answer is the "AIML Output Scaffold" block,
    # which sits between "🤖 AIML Output Scaffold:" and "--- DEBUG TELEMETRY".
    # The arithmetic engine (when sigil math fires) appends a short numeric
    # answer line at the very end of the captured stdout, of the form
    # "==... <answer>" -- but only when the answer is purely numeric or
    # boolean. We pull that ONLY if it parses as a number to avoid grabbing
    # debug-bar artifacts that happen to start with '='.
    scaffold = String[]
    in_scaffold = false
    for ln in lines
        s = strip(ln)
        if occursin("AIML Output Scaffold", s)
            in_scaffold = true
            continue
        end
        if in_scaffold
            if startswith(s, "---") || s == ""
                break
            end
            push!(scaffold, s)
        end
    end

    # Look for an arithmetic answer line: only accept if the trailing token
    # is purely numeric (int or float, optionally negative) -- this is what
    # the math macro emits as a final stdout line. Anything else is debug.
    math_tail = ""
    for ln in Iterators.reverse(lines)
        s = strip(ln)
        s == "" && continue
        m = match(r"^=+\s*(-?\d+(?:\.\d+)?)\s*$", s)
        if m !== nothing
            math_tail = strip(m.captures[1])
            break
        end
        # stop scanning once we hit non-trivial content lines
        if length(s) > 4 && !startswith(s, "===") && !startswith(s, "---")
            break
        end
    end

    if !isempty(scaffold)
        body = join(scaffold, " ")
        # trim AIML scaffold "[Directives: ...]" tail for cleaner chat view
        body = replace(body, r"\s*\[Directives:.*$" => "")
        if !isempty(math_tail)
            return body * "  →  **$math_tail**"
        end
        return body
    end

    # fallback: silent-cave marker
    for ln in lines
        s = strip(ln)
        if occursin("Cave is silent", s) || occursin("No valid specimens", s)
            return s
        end
    end
    return "(no clean response extracted)"
end

# =============================================================================
# safe diagnostics -- each block fenced in try so one failure can't sink log
# =============================================================================
function safe_call(label::String, f::Function)::String
    try
        out = f()
        s = isnothing(out) ? "" : (out isa AbstractString ? out : sprint(show, out))
        return "### $label\n```\n$s\n```\n"
    catch e
        return "### $label\n```\n[unavailable: $(typeof(e)) $(sprint(showerror, e))]\n```\n"
    end
end

println("\nGathering diagnostics ...")

diag_lobe   = safe_call("Lobe Status",   () -> GB.Lobe.get_lobe_status_summary())
diag_nodes  = safe_call("Node Status",   () -> GB.get_node_status_summary())
diag_aiml   = safe_call("AIML Status",   () -> GB.AIMLNodeSystem.get_aiml_status_summary())

# immune system summary
diag_immune = safe_call("Immune System", function ()
    s = GB.ImmuneSystem.get_immune_status()
    io = IOBuffer()
    for (k, v) in s
        println(io, "  $k = $v")
    end
    return String(take!(io))
end)

# sigil registry dump
diag_sigils = safe_call("Sigil Registry", function ()
    table = GB.SigilRegistry.default_table()
    sigils = GB.SigilRegistry.list_sigils(table)
    io = IOBuffer()
    println(io, "Registered sigils: $(length(sigils))")
    for s in sigils
        println(io, "  &$s")
    end
    println(io)
    println(io, "Sigil-tagged nodes: $(length(GB.list_sigil_node_ids()))")
    println(io, "  math:       $(length(GB.list_sigil_node_ids(:math)))")
    println(io, "  multipart:  $(length(GB.list_sigil_node_ids(:multipart)))")
    return String(take!(io))
end)

# group registry
diag_groups = safe_call("Group Registry", function ()
    ids = GB.GroupRegistry.list_group_ids()
    io = IOBuffer()
    println(io, "Group count: $(GB.GroupRegistry.group_count())")
    for gid in ids
        g = GB.GroupRegistry.get_group(gid)
        if g !== nothing
            println(io, "  $gid -> partner_cap=$(g.partner_cap), members=$(length(g.member_ids)), grave=$(g.grave_count)")
        end
    end
    return String(take!(io))
end)

# crystalize counts
diag_crystal = safe_call("Crystalize", function ()
    crys = GB.CrystalizeTag.list_crystalized()
    io = IOBuffer()
    println(io, "Crystalized nodes: $(GB.CrystalizeTag.crystalized_count())")
    for nid in crys
        kind = GB.CrystalizeTag.is_auto_crystalized(nid) ? "AUTO" : "USER"
        println(io, "  $nid [$kind]")
    end
    return String(take!(io))
end)

# tonal buildup snapshot
diag_tonal = safe_call("Tonal Build-Up", function ()
    tb = GB.ActionTonePredictor.get_tonal_buildup()
    return repr(tb)
end)

# sparse-active fire skip
diag_sparse = safe_call("Sparse-Active Fire Gate", function ()
    fc = GB._LAST_FIRE_COUNTER[]
    return "fires this cycle: $(fc.active[]) / cap $(fc.cap)  |  cycle_id=$(fc.cycle_id)"
end)

# subconscious snapshot
diag_subconscious = safe_call("Subconscious", function ()
    store = GB.SelfObserver.default_store()
    io = IOBuffer()
    println(io, "Total entries: $(GB.SelfObserver.store_size(store))")
    println(io, "Key count:     $(GB.SelfObserver.key_count(store))")
    audit = GB.SelfObserver.audit_trail(store)
    println(io, "Audit trail:")
    for (k, v) in audit
        println(io, "  $k = $v")
    end
    return String(take!(io))
end)

# eye / arousal
diag_eye = safe_call("Eye / Arousal", function ()
    return "current arousal: $(GB.EyeSystem.get_arousal())"
end)

# message history
diag_msgs = safe_call("Message History (post-run)", function ()
    if isdefined(GB, :MESSAGE_HISTORY)
        msgs = GB.MESSAGE_HISTORY
        io = IOBuffer()
        println(io, "Total messages: $(length(msgs))")
        for m in Iterators.take(Iterators.reverse(msgs), 12)
            tag = m.pinned ? "[PIN]" : "     "
            println(io, "  $tag $(m.role): $(first(m.text, 80))")
        end
        return String(take!(io))
    end
    return "[message history not directly exposed]"
end)

# =============================================================================
# write the markdown log
#   - chat first (clean prose)
#   - diagnostics after, separate section
# =============================================================================
println("Writing log to $LOG_PATH ...")
open(LOG_PATH, "w") do io
    println(io, "# GrugBot420 v7.22 + v2.6 -- Comprehensive Specimen Session Log")
    println(io)
    println(io, "Specimen file: `$SPECIMEN_PATH`")
    println(io, "Generated: ", string(now_str()))
    println(io)
    println(io, "---")
    println(io)

    # ---------------- CHAT ----------------
    println(io, "## Chat")
    println(io)
    println(io, "_User prompts and the specimen's responses, in order. Pipeline trace lives in the Diagnostics section below._")
    println(io)

    for (i, t) in enumerate(turns)
        resp = extract_response(t.captured)
        kinds_str = isempty(t.mediation_kinds) ? "—" : join(t.mediation_kinds, ", ")
        println(io, "### Turn $i")
        println(io)
        println(io, "**User:** $(t.user)")
        println(io)
        println(io, "**Specimen:** $resp")
        println(io)
        println(io, "_sigil mediation: kinds=[$kinds_str], bindings=$(t.mediation_bindings)_")
        println(io)
    end

    println(io, "---")
    println(io)

    # ---------------- DIAGNOSTICS ----------------
    println(io, "## Diagnostics")
    println(io)
    println(io, "_Full brain mechanics, levers, and stats. Captured AFTER the chat run completed._")
    println(io)

    print(io, diag_lobe)
    print(io, diag_nodes)
    print(io, diag_aiml)
    print(io, diag_immune)
    print(io, diag_sigils)
    print(io, diag_groups)
    print(io, diag_crystal)
    print(io, diag_tonal)
    print(io, diag_sparse)
    print(io, diag_subconscious)
    print(io, diag_eye)
    print(io, diag_msgs)

    # per-turn captured pipeline traces -- still in diagnostics, fully separate
    println(io)
    println(io, "### Per-Turn Pipeline Traces")
    println(io)
    for (i, t) in enumerate(turns)
        println(io, "#### Turn $i pipeline trace -- `$(t.user)`")
        println(io)
        println(io, "```")
        # cap at ~6KB per turn so the log stays readable
        cap = length(t.captured) > 6000 ? first(t.captured, 6000) * "\n... [truncated]" : t.captured
        println(io, cap)
        println(io, "```")
        println(io)
    end
end

println("\n✅ wrote log: $LOG_PATH")
println("   chat turns:  $(length(turns))")
println("   bytes:       $(filesize(LOG_PATH))")
