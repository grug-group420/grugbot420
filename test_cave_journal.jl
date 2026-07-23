#!/usr/bin/env julia
# test_cave_journal.jl — CaveJournal auto-logging module test
# Tests: toggle, file creation, appending, section formatting,
#         pass/fail/warn/info, debug blocks, path config, specimen round-trip

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420
using Dates: now

import .GrugBot420.CaveJournal:
    journal_on!, journal_off!, journal_toggle!, journal_is_active,
    journal_status, journal_set_path!, journal_get_path, journal_set_filename!,
    journal_log, journal_section, journal_subsection,
    journal_pass, journal_fail, journal_warn, journal_info,
    journal_debug_block, journal_telemetry,
    journal_clear!, journal_rotate!,
    journal_config_to_dict, journal_config_from_dict!,
    cave_print

const TEST_DIR = "/workspace/cave_journal_test"
const TEST_FILE = "test_journal.md"
const TEST_PATH = joinpath(TEST_DIR, TEST_FILE)

results = Tuple{String,Bool,String}[]
pass(name, detail="") = push!(results, (name, true, detail))
fail(name, detail="") = push!(results, (name, false, detail))

function check(name, condition; detail="")
    if condition
        pass(name, detail)
        println("  ✅ $name")
    else
        fail(name, detail)
        println("  ❌ $name — $detail")
    end
end

# ── Setup ──
println("=" ^ 60)
println("CaveJournal Test Suite")
println("=" ^ 60)

# Clean up any previous test artifacts
if isdir(TEST_DIR)
    rm(TEST_DIR; recursive=true)
end
mkpath(TEST_DIR)

# ── 1. Default state ──
println("\n## 1. Default State")
check("journal starts OFF", !journal_is_active())
check("default path is pwd", journal_get_path() == joinpath(pwd(), "cave_journal.md"))

# ── 2. Path configuration ──
println("\n## 2. Path Configuration")
msg = journal_set_path!(TEST_DIR)
check("set_path returns OK", occursin(TEST_DIR, msg))
# NOTE: filename is still default at this point, so get_path returns dir + default name
check("get_path reflects new dir (default filename)", occursin(TEST_DIR, journal_get_path()))

msg2 = journal_set_filename!(TEST_FILE)
check("set_filename returns OK", occursin(TEST_FILE, msg2))
# Now both dir + filename are set, get_path should match full TEST_PATH
check("get_path reflects dir + filename", journal_get_path() == TEST_PATH)

# ── 3. Toggle ON ──
println("\n## 3. Toggle ON")
msg3 = journal_on!()
check("journal_on returns ON message", occursin("ON", msg3))
check("journal is now active", journal_is_active())
check("journal file was created", isfile(TEST_PATH))

# Read the session header
content = read(TEST_PATH, String)
check("session header has 📖", occursin("📖", content))
check("session header has timestamp", occursin("Opened:", content))

# ── 4. Basic logging ──
println("\n## 4. Basic Logging")
journal_log("hello from test"; tag="TEST", emoji="🧪")
sleep(0.1)
content2 = read(TEST_PATH, String)
check("log entry written", occursin("hello from test", content2))
check("tag present", occursin("[TEST]", content2))
check("emoji present", occursin("🧪", content2))
check("timestamp present", occursin("│", content2))

# ── 5. Section headers ──
println("\n## 5. Section Headers")
journal_section("Test Section One")
journal_subsection("Test Subsection 1a")
journal_log("inside section")
sleep(0.1)
content3 = read(TEST_PATH, String)
check("## section header present", occursin("## Test Section One", content3))
check("### subsection header present", occursin("### Test Subsection 1a", content3))

# ── 6. Pass/fail/warn/info ──
println("\n## 6. Pass/Fail/Warn/Info")
journal_pass("test thing passed"; detail="extra info")
journal_fail("test thing failed"; detail="reason here")
journal_warn("test warning"; detail="watch out")
journal_info("test info"; detail="for your records")
sleep(0.1)
content4 = read(TEST_PATH, String)
check("✅ pass present", occursin("✅", content4) && occursin("[PASS]", content4))
check("❌ fail present", occursin("❌", content4) && occursin("[FAIL]", content4))
check("⚠️ warn present", occursin("⚠️", content4) && occursin("[WARN]", content4))
check("ℹ️ info present", occursin("ℹ️", content4) && occursin("[INFO]", content4))
check("detail text in pass", occursin("extra info", content4))

# ── 7. Debug block ──
println("\n## 7. Debug Block")
journal_debug_block("Mission Telemetry", "action=welcome\nconfidence=0.95\nkind=question")
sleep(0.1)
content5 = read(TEST_PATH, String)
check("debug block has title", occursin("Mission Telemetry", content5))
check("debug block has quote prefix", occursin("> action=welcome", content5))
check("debug block has --- separator", occursin("---", content5))

# ── 8. Telemetry logging ──
println("\n## 8. Telemetry Logging")
journal_telemetry("what is 5+5", "calculate", 0.95, :calculate; extra="result=10")
sleep(0.1)
content6 = read(TEST_PATH, String)
check("telemetry has [TELEMETRY]", occursin("[TELEMETRY]", content6))
check("telemetry has kind", occursin("kind=calculate", content6))
check("telemetry has mission text", occursin("what is 5+5", content6))
check("telemetry has extra", occursin("result=10", content6))

# ── 9. Toggle OFF ──
println("\n## 9. Toggle OFF")
msg9 = journal_off!()
check("journal_off returns OFF message", occursin("OFF", msg9))
check("journal is now inactive", !journal_is_active())

# Verify no more writes after OFF
sz_before = filesize(TEST_PATH)
journal_log("should not appear"; tag="AFTER", emoji="🚫")
sleep(0.1)
sz_after = filesize(TEST_PATH)
check("no writes after journal OFF", sz_before == sz_after)

# ── 10. Toggle (on/off flip) ──
println("\n## 10. Toggle")
msg10 = journal_toggle!()
check("toggle turns ON", occursin("ON", msg10) && journal_is_active())
msg10b = journal_toggle!()
check("toggle turns OFF", occursin("OFF", msg10b) && !journal_is_active())

# ── 11. Append semantics ──
println("\n## 11. Append Semantics")
journal_on!()
content_before = read(TEST_PATH, String)
lines_before = countlines(TEST_PATH)
journal_section("Second Session")
journal_log("appended content")
sleep(0.1)
content_after = read(TEST_PATH, String)
lines_after = countlines(TEST_PATH)
check("old content preserved", occursin("hello from test", content_after))
check("new content appended", lines_after > lines_before)

# ── 12. Rotate ──
println("\n## 12. Rotate")
# Add lots of lines to force rotation
for i in 1:50
    journal_log("filler line $i"; tag="FILL")
end
sleep(0.1)
total_lines = countlines(TEST_PATH)
msg12 = journal_rotate!(keep_lines=10)
check("rotate returns message", occursin("rotated", lowercase(msg12)) || occursin("no rotation", lowercase(msg12)))
if occursin("rotated", lowercase(msg12))
    # Check backup exists
    backup_path = TEST_PATH * ".1"
    check("backup file created", isfile(backup_path))
    # Check main file was trimmed
    remaining = countlines(TEST_PATH)
    check("main file trimmed", remaining <= 15)  # some margin for headers
end

# ── 13. Clear ──
println("\n## 13. Clear")
msg13 = journal_clear!()
check("clear returns deleted message", occursin("deleted", lowercase(msg13)) || occursin("no journal", lowercase(msg13)))
check("file was deleted", !isfile(TEST_PATH))

# ── 14. Specimen round-trip ──
println("\n## 14. Specimen Round-Trip")
# Turn journal OFF first so we have a clean baseline for the active-not-restored test
journal_off!()
journal_set_path!("/tmp/cave_test_specimen")
journal_set_filename!("roundtrip.md")
cfg = journal_config_to_dict()
check("config has directory", haskey(cfg, "directory") && cfg["directory"] == "/tmp/cave_test_specimen")
check("config has filename", haskey(cfg, "filename") && cfg["filename"] == "roundtrip.md")
check("config has active", haskey(cfg, "active"))

# Simulate load — change directory, then restore from dict
journal_set_path!("/some/other/place")
journal_set_filename!("other.md")
# Turn journal ON so we can prove from_dict does NOT restore active
journal_on!()
journal_config_from_dict!(cfg)
check("directory restored from dict", journal_get_path() == "/tmp/cave_test_specimen/roundtrip.md")
# active was ON before from_dict, but from_dict does NOT set active,
# so it should remain at its current value (ON in this case).
# The key test: from_dict should NOT change active to the saved value.
# To test this properly: save when active=true, turn off, load dict, verify stays OFF.
journal_off!()  # turn OFF
journal_config_from_dict!(cfg)  # cfg has active=true, but from_dict ignores it
check("active NOT restored from dict (stays OFF)", !journal_is_active())

# ── 15. Status string ──
println("\n## 15. Status String")
stat = journal_status()
check("status has 📖", occursin("📖", stat))
check("status shows OFF", occursin("OFF", stat) || occursin("📕", stat))
check("status shows path", occursin("roundtrip.md", stat))

# ── 16. Integration with process_mission ──
println("\n## 16. Integration with process_mission")
# Set up a journal file, turn on, run a mission, check log
journal_set_path!("/workspace/cave_journal_test")
journal_set_filename!("mission_integration.md")
journal_on!()

# Run a simple question
process_mission("what is fire")
sleep(0.2)
int_content = read("/workspace/cave_journal_test/mission_integration.md", String)
check("mission logged", occursin("what is fire", int_content))
check("route logged", occursin("[ROUTE]", int_content) || occursin("kind=", int_content))
check("question result logged", occursin("[PASS]", int_content) || occursin("question", int_content))

# Run arithmetic
process_mission("5+5")
sleep(0.2)
int_content2 = read("/workspace/cave_journal_test/mission_integration.md", String)
check("5+5 mission logged", occursin("5+5", int_content2))

journal_off!()

println("\n## 17. cave_print — dual output (console + journal)")
# Test that cave_print both prints to console AND writes to journal
journal_set_path!("/workspace/cave_journal_test")
journal_set_filename!("cave_print_test.md")
journal_on!()

# When journal is ON, cave_print should write to both
cave_print("[TEST-TAG] hello from cave_print"; tag="TEST", emoji="🧪")
sleep(0.1)
cp_content = read("/workspace/cave_journal_test/cave_print_test.md", String)
check("cave_print writes to journal when ON", occursin("hello from cave_print", cp_content))
check("cave_print tag appears in journal", occursin("[TEST]", cp_content))
check("cave_print emoji appears in journal", occursin("🧪", cp_content))

# When journal is OFF, cave_print should only println (no file write)
journal_off!()
cave_print("[TEST-TAG] journal is off now"; tag="TEST", emoji="🧪")
sleep(0.1)
cp_content2 = read("/workspace/cave_journal_test/cave_print_test.md", String)
check("cave_print does NOT write when journal OFF", !occursin("journal is off now", cp_content2))

# cave_print with no tag/emoji (plain message)
journal_on!()
cave_print("plain cave_print message")
sleep(0.1)
cp_content3 = read("/workspace/cave_journal_test/cave_print_test.md", String)
check("cave_print plain message in journal", occursin("plain cave_print message", cp_content3))

journal_off!()

# ── Cleanup ──
journal_clear!()
rm("/workspace/cave_journal_test"; recursive=true, force=true)

# ── Summary ──
total = length(results)
passed = count(x -> x[2], results)
failed = total - passed

println("\n", "=" ^ 60)
println("CaveJournal Test: $(passed)/$(total) passed")
if failed > 0
    println("FAILURES:")
    for (n, p, d) in results
        p && continue
        println("  ❌ $n — $d")
    end
else
    println("✅ ALL PASS")
end
println("=" ^ 60)

# Write log to markdown
log_path = "/workspace/cave_journal_test_log.md"

try
    open( # DoD REMEDIATION
catch e
    log_audit("ERROR", "SYSTEM", "File operation failed", e)
    return nothing
endlog_path, "w") do f
    println(f, "# CaveJournal Test Log")
    println(f, "")
    println(f, "_Generated: $(now())_")
    println(f, "")
    for (name, p, detail) in results
        emoji = p ? "✅" : "❌"
        d_str = isempty(detail) ? "" : " — $detail"
        println(f, "- $(emoji) **$(name)**$(d_str)")
    end
    println(f, "")
    println(f, "## Summary")
    println(f, "- Total: $(total)  |  Passed: $(passed)  |  Failed: $(failed)")
    println(f, "")
    println(f, "Result: $(failed == 0 ? "✅ ALL PASS" : "❌ SOME FAILURES")")
end

println("\nLog written to: $(log_path)")
