# ==============================================================================
# CaveJournal.jl — GRUG Auto-Logging to Markdown
# ==============================================================================
# GRUG say: cave have many events. Grug forget things. Now cave write things
#           down in book. Book is markdown file. Grug can read book later.
#           Book live in same place as cave by default. Grug can move book
#           to different place if want.
# GRUG say: writing in book is OPTIONAL. Book starts CLOSED. Grug must say
#           "open book" before anything gets written. No surprise disk writes.
#           Grug says "close book" and nothing more gets written.
# GRUG say: book is APPENDED. Old entries stay. New entries go at bottom.
#           This is how real journal work. You don't erase yesterday.
# GRUG say: book writes are THREAD-SAFE. Two grugs can write at same time
#           and book doesn't get scrambled. Lock protects the pen.
# GRUG say: FORMAT IS CONSISTENT. Every entry has timestamp. Sections get
#           headers. Pass/fail gets emoji. Debug gets telemetry block.
#           Same format as test logs Grug already uses.
#
# ACADEMIC: This module provides structured markdown journaling with:
#   1. Toggle control (on/off, default off — no silent side effects)
#   2. Configurable directory (defaults to pwd)
#   3. Auto-creation on first write if file doesn't exist
#   4. Append-only semantics (existing data never overwritten)
#   5. Thread-safe writes via ReentrantLock
#   6. Consistent markdown formatting with timestamps, sections, emojis
#   7. Specimen save/load integration for journal path persistence
#
# The journal is NOT a replacement for println debug output. It's a
# persistent, structured log that survives across sessions. The workflow:
#   - Boot with specimen → journal picks up saved path
#   - /journal on → starts logging
#   - Have conversation → key events logged automatically
#   - /journal off → stops logging
#   - Save specimen → journal path saved
#   - Next boot → journal resumes to same file
# ==============================================================================

module CaveJournal

using Base.Threads: ReentrantLock
using Dates: now, format, Dates

# ══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ══════════════════════════════════════════════════════════════════════════════

export journal_on!, journal_off!, journal_toggle!,
       journal_is_active, journal_status,
       journal_set_path!, journal_get_path, journal_set_filename!,
       journal_log, journal_section, journal_subsection,
       journal_pass, journal_fail, journal_warn, journal_info,
       journal_debug_block, journal_telemetry,
       journal_clear!, journal_rotate!,
       journal_config_to_dict, journal_config_from_dict!,
       cave_print,
       JOURNAL_DEFAULT_FILENAME

# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ══════════════════════════════════════════════════════════════════════════════

const JOURNAL_DEFAULT_FILENAME = "cave_journal.md"
const JOURNAL_LOCK = ReentrantLock()
const JOURNAL_TIMESTAMP_FORMAT = "yyyy-mm-dd HH:MM:SS"

# ══════════════════════════════════════════════════════════════════════════════
# MUTABLE STATE (all guarded by JOURNAL_LOCK)
# ══════════════════════════════════════════════════════════════════════════════

_active::Ref{Bool} = Ref(false)
_directory::Ref{String} = Ref(pwd())
_filename::Ref{String} = Ref(JOURNAL_DEFAULT_FILENAME)
_entry_count::Ref{Int} = Ref(0)

# ══════════════════════════════════════════════════════════════════════════════
# INTERNAL HELPERS
# ══════════════════════════════════════════════════════════════════════════════

"""Get the full path to the journal file."""
function _full_path()::String
    return joinpath(_directory[], _filename[])
end

"""Get current timestamp string."""
function _timestamp()::String
    return format(now(), JOURNAL_TIMESTAMP_FORMAT)
end

"""Write a line to the journal file. Appends. Creates file/dir if needed."""
function _write(line::String)::Bool
    lock(JOURNAL_LOCK) do
        if !_active[]
            return false
        end
        try
            filepath = _full_path()
            # Ensure directory exists
            dir = dirname(filepath)
            if !isdir(dir)
                mkpath(dir)
            end
            # Append to file (create if not exists)

try
                open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "a") do f
                println(f, line)
            end
            _entry_count[] += 1
            return true
        catch e
            # GRUG: journal write failure must NOT crash the system.
            # Log to stderr and move on. Journal is auxiliary, not critical.
            @error "CaveJournal write failed" exception=e
            return false
        end
    end
end

"""Write multiple lines to the journal file."""
function _write_lines(lines::Vector{String})::Bool
    lock(JOURNAL_LOCK) do
        if !_active[]
            return false
        end
        try
            filepath = _full_path()
            dir = dirname(filepath)
            if !isdir(dir)
                mkpath(dir)
            end

try
                open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "a") do f
                for line in lines
                    println(f, line)
                end
            end
            _entry_count[] += length(lines)
            return true
        catch e
            @error "CaveJournal write failed" exception=e
            return false
        end
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# TOGGLE CONTROL
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_on!() → String

Turn the journal ON. Starts logging. If the file doesn't exist, it gets
created on the first write. Returns status message.
"""
function journal_on!()::String
    lock(JOURNAL_LOCK) do
        was = _active[]
        _active[] = true
        filepath = _full_path()
        if !was
            # Write a session header on first activation
            ts = _timestamp()
            header_lines = [
                "",
                "---",
                "# 📖 Cave Journal — Session Opened",
                "_Opened: $(ts)_",
                "_Path: $(filepath)_",
                "---",
                ""
            ]
            # Write directly (we're already inside lock)
            try
                dir = dirname(filepath)
                if !isdir(dir)
                    mkpath(dir)
                end

try
                    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "a") do f
                    for line in header_lines
                        println(f, line)
                    end
                end
                _entry_count[] += length(header_lines)
            catch e
                @error "CaveJournal session header failed" exception=e
            end
            return "📖 Journal ON → $(filepath)"
        else
            return "📖 Journal already ON → $(filepath)"
        end
    end
end

"""
    journal_off!() → String

Turn the journal OFF. Stops logging. Returns status message.
"""
function journal_off!()::String
    lock(JOURNAL_LOCK) do
        was = _active[]
        _active[] = false
        if was
            # Write session close marker
            ts = _timestamp()
            try
                filepath = _full_path()

try
                    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "a") do f
                    println(f, "")
                    println(f, "_Closed: $(ts) — $( _entry_count[]) entries this session_")
                    println(f, "---")
                    println(f, "")
                end
            catch e
                @error "CaveJournal close marker failed" exception=e
            end
            return "📕 Journal OFF ($( _entry_count[]) entries written)"
        else
            return "📕 Journal already OFF"
        end
    end
end

"""
    journal_toggle!() → String

Toggle journal on/off. Returns status message.
"""
function journal_toggle!()::String
    lock(JOURNAL_LOCK) do
        if _active[]
            return journal_off!()
        else
            return journal_on!()
        end
    end
end

"""
    journal_is_active() → Bool

Check if the journal is currently active.
"""
function journal_is_active()::Bool
    lock(JOURNAL_LOCK) do
        _active[]
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# PATH CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_set_path!(dir::String) → String

Set the directory for the journal file. Creates directory if it doesn't exist.
Returns status message.
"""
function journal_set_path!(dir::String)::String
    lock(JOURNAL_LOCK) do
        abs_dir = isabspath(dir) ? dir : joinpath(pwd(), dir)
        if !isdir(abs_dir)
            try
                mkpath(abs_dir)
            catch e
                return "⚠ Journal directory creation failed: $e"
            end
        end
        was = _active[]
        _directory[] = abs_dir
        return "📂 Journal directory → $(abs_dir) (journal is $(was ? "ON" : "OFF"))"
    end
end

"""
    journal_get_path() → String

Get the current full path to the journal file.
"""
function journal_get_path()::String
    lock(JOURNAL_LOCK) do
        _full_path()
    end
end

"""
    journal_set_filename!(name::String) → String

Set the filename for the journal. Returns status message.
"""
function journal_set_filename!(name::String)::String
    lock(JOURNAL_LOCK) do
        _filename[] = name
        return "📄 Journal filename → $(name) (full path: $(_full_path()))"
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# STATUS
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_status() → String

Get a status string summarizing the journal state.
"""
function journal_status()::String
    lock(JOURNAL_LOCK) do
        filepath = _full_path()
        exists = isfile(filepath)
        size_str = if exists
            sz = filesize(filepath)
            if sz < 1024
                "$(sz) B"
            elseif sz < 1024 * 1024
                "$(round(sz / 1024; digits=1)) KB"
            else
                "$(round(sz / (1024*1024); digits=1)) MB"
            end
        else
            "not created yet"
        end
        lines = [
            "📖 CaveJournal Status",
            "  Active: $(_active[] ? "✅ ON" : "📕 OFF")",
            "  Path:   $(filepath)",
            "  File:   $(exists ? "exists ($size_str)" : "does not exist")",
            "  Entries this session: $(_entry_count[])",
        ]
        return join(lines, "\n")
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# LOGGING PRIMITIVES
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_log(msg::String; tag::String="", emoji::String="")

Write a plain log entry with timestamp. Optional tag and emoji prefix.
This is the base primitive — all other logging functions build on this.
"""
function journal_log(msg::String; tag::String="", emoji::String="")
    ts = _timestamp()
    prefix = if !isempty(tag) && !isempty(emoji)
        "$(emoji) [$(tag)]"
    elseif !isempty(tag)
        "[$(tag)]"
    elseif !isempty(emoji)
        "$(emoji)"
    else
        ""
    end
    line = if isempty(prefix)
        "$(ts) │ $(msg)"
    else
        "$(ts) │ $(prefix) $(msg)"
    end
    _write(line)
end

"""
    journal_section(title::String)

Write a markdown section header (####). Good for grouping related entries.
"""
function journal_section(title::String)
    lines = [
        "",
        "#### $(title)",
        ""
    ]
    _write_lines(lines)
end

"""
    journal_subsection(title::String)

Write a markdown subsection header (#####).
"""
function journal_subsection(title::String)
    lines = [
        "",
        "##### $(title)",
        ""
    ]
    _write_lines(lines)
end

"""
    journal_pass(label::String; detail::String="")

Log a passing result. ✅ emoji, [PASS] tag.
"""
function journal_pass(label::String; detail::String="")
    d = isempty(detail) ? "" : " — $(detail)"
    journal_log("$(label)$(d)"; tag="PASS", emoji="✅")
end

"""
    journal_fail(label::String; detail::String="")

Log a failing result. ❌ emoji, [FAIL] tag.
"""
function journal_fail(label::String; detail::String="")
    d = isempty(detail) ? "" : " — $(detail)"
    journal_log("$(label)$(d)"; tag="FAIL", emoji="❌")
end

"""
    journal_warn(label::String; detail::String="")

Log a warning. ⚠️ emoji, [WARN] tag.
"""
function journal_warn(label::String; detail::String="")
    d = isempty(detail) ? "" : " — $(detail)"
    journal_log("$(label)$(d)"; tag="WARN", emoji="⚠️")
end

"""
    journal_info(label::String; detail::String="")

Log an informational note. ℹ️ emoji, [INFO] tag.
"""
function journal_info(label::String; detail::String="")
    d = isempty(detail) ? "" : " — $(detail)"
    journal_log("$(label)$(d)"; tag="INFO", emoji="ℹ️")
end



# ═══════════════════════════════════════════════════════════════════════════════
# DUAL-OUTPUT PRINT (cave_print)
# ═══════════════════════════════════════════════════════════════════════════════

"""
    cave_print(msg::String; tag::String="", emoji::String="")

Print `msg` to console (println) AND write it to the journal file if the
journal is active. When the journal is OFF, only the console println fires —
no disk writes, no side effects.

This is the single function that replaces the pattern of having a `println`
followed by a separate `CaveJournal.journal_*` call. Every tagged console
output in Main.jl should use `cave_print` instead of bare `println`, so that
journaling happens automatically and nothing gets missed.

GRUG say: one rock do two jobs. Print rock ALSO write rock. No forget.

# Examples
```julia
cave_print("[IMMUNE] ⛔ Command rejected")
cave_print("[CONV-TEACH] 📝 Teaching topic='math'"; tag="TEACH", emoji="📝")
cave_print("plain message")  # just println + raw journal entry (no tag)
```
"""
function cave_print(msg::String; tag::String="", emoji::String="")
    # Always print to console — this is the visible output
    println(msg)
    # If journal is active, also write to file
    if _active[]
        journal_log(msg; tag=tag, emoji=emoji)
    end
end

# GRUG: Variadic cave_print — concatenates all string arguments into one message.
# This lets callers do: cave_print("[TAG] prefix: ", detail; tag="TAG", emoji="🔥")
# instead of manually building: cave_print("[TAG] prefix: $detail"; tag="TAG", emoji="🔥")
cave_print(msgs::String...; tag::String="", emoji::String="") = cave_print(join(msgs); tag=tag, emoji=emoji)


# ══════════════════════════════════════════════════════════════════════════════
# STRUCTURED LOG BLOCKS
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_debug_block(title::String, content::String)

Write a debug/telemetry block in markdown quote format. Same style as
the test logs: indented block with --- boundaries.
"""
function journal_debug_block(title::String, content::String)
    ts = _timestamp()
    lines = String[]
    push!(lines, "> **$(title)** (at $(ts)):")
    push!(lines, ">")
    for line in split(content, "\n")
        push!(lines, "> $(line)")
    end
    push!(lines, "---")
    _write_lines(lines)
end

"""
    journal_telemetry(mission::String, action::String, confidence::Float64,
                      kind::Symbol; extra::String="")

Write a telemetry line for process_mission events. Captures the same
debug info that gets println'd but persists it to the journal.
"""
function journal_telemetry(mission::String, action::String, confidence::Float64,
                           kind::Symbol; extra::String="")
    ts = _timestamp()
    extra_str = isempty(extra) ? "" : " │ $(extra)"
    line = "$(ts) │ 📡 [TELEMETRY] kind=$(kind) action=$(action) conf=$(round(confidence; digits=3)) │ '$(mission)'$(extra_str)"
    _write(line)
end

# ══════════════════════════════════════════════════════════════════════════════
# FILE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_clear!() → String

Delete the current journal file. Returns status message.
"""
function journal_clear!()::String
    lock(JOURNAL_LOCK) do
        filepath = _full_path()
        if isfile(filepath)
            try
                rm(filepath)
                _entry_count[] = 0
                return "🗑 Journal file deleted: $(filepath)"
            catch e
                return "⚠ Failed to delete journal: $e"
            end
        else
            return "📭 No journal file to delete"
        end
    end
end

"""
    journal_rotate!(; keep_lines::Int=1000) → String

Rotate the journal: keep the last N lines, archive the rest.
Creates a .1, .2, ... backup sequence. Returns status message.
"""
function journal_rotate!(; keep_lines::Int=1000)::String
    lock(JOURNAL_LOCK) do
        filepath = _full_path()
        if !isfile(filepath)
            return "📭 No journal file to rotate"
        end

        try
            # Read all lines
            all_lines = readlines(filepath)
            total = length(all_lines)

            if total <= keep_lines
                return "ℹ Journal has $(total) lines — no rotation needed (keep=$(keep_lines))"
            end

            # Find next backup number
            backup_num = 1
            while isfile("$(filepath).$(backup_num)")
                backup_num += 1
            end

            # Move current to backup
            backup_path = "$(filepath).$(backup_num)"
            mv(filepath, backup_path)

            # Write back only the last N lines
            kept = all_lines[(end - keep_lines + 1):end]

try
                open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endfilepath, "w") do f
                for line in kept
                    println(f, line)
                end
            end

            return "🔄 Journal rotated: $(total)→$(keep_lines) lines, backup → $(backup_path)"
        catch e
            return "⚠ Journal rotation failed: $e"
        end
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# SPECIMEN SAVE/LOAD INTEGRATION
# ══════════════════════════════════════════════════════════════════════════════

"""
    journal_config_to_dict() → Dict{String,Any}

Serialize journal config for specimen save.
"""
function journal_config_to_dict()::Dict{String,Any}
    lock(JOURNAL_LOCK) do
        Dict{String,Any}(
            "active"        => _active[],
            "directory"     => _directory[],
            "filename"      => _filename[],
            "entry_count"   => _entry_count[],
        )
    end
end

"""
    journal_config_from_dict!(d) 

Restore journal config from specimen load.
"""
function journal_config_from_dict!(d)
    lock(JOURNAL_LOCK) do
        haskey(d, "directory")   && (_directory[]   = String(d["directory"]))
        haskey(d, "filename")    && (_filename[]     = String(d["filename"]))
        haskey(d, "entry_count") && (_entry_count[]  = Int(d["entry_count"]))
        # NOTE: active is NOT restored from specimen — journal starts OFF.
        # User must /journal on to start logging. No surprise activations.
        # This matches the same philosophy as CoherenceField weight=0.0 default.
    end
end

# ══════════════════════════════════════════════════════════════════════════════
# MODULE INIT — no auto-activation, no auto-creation
# ══════════════════════════════════════════════════════════════════════════════

# Nothing happens on module load. Journal is OFF. File is not created.
# User must explicitly /journal on to start. This is by design.

end # module CaveJournal
