# test_admin_system.jl
# ==============================================================================
# GRUG ADMIN SYSTEM COMPREHENSIVE TESTS
# Tests admin command system:
#   - Password hashing and verification
#   - Session management (login, logout, timeout)
#   - JSON validation
#   - /writeSave functionality
#   - Admin-only enforcement
# All failures scream loudly. No silent passes.
# ==============================================================================

using Test
using JSON
using SHA

println("\n" * "="^60)
println("GRUG ADMIN SYSTEM TESTS")
println("="^60)

# GRUG: We need to include Main.jl to test the admin functions
# But Main.jl is complex, so we'll test the core functions directly
include("../src/Main.jl")

# ==============================================================================
# [1] PASSWORD HASHING
# ==============================================================================
println("\n[1] PASSWORD HASHING")

# GRUG: Test that default password hash is correct
default_password = "grug_cave_master_420"
expected_hash = bytes2hex(sha256(default_password))
@test Main.ADMIN_PASSWORD_HASH == expected_hash
println("  ✓ Default password hash is correct")

# GRUG: Test that different passwords produce different hashes
other_hash = bytes2hex(sha256("wrong_password"))
@test Main.ADMIN_PASSWORD_HASH != other_hash
println("  ✓ Different passwords produce different hashes")

# ==============================================================================
# [2] SESSION MANAGEMENT - LOGIN
# ==============================================================================
println("\n[2] SESSION MANAGEMENT - LOGIN")

# GRUG: Test successful login
success, message = Main.admin_login(default_password)
@test success == true
@test contains(message, "successful")
println("  ✓ Successful login with correct password")

# GRUG: Test failed login with wrong password
success, message = Main.admin_login("wrong_password")
@test success == false
@test contains(message, "Invalid password")
println("  ✓ Failed login with wrong password")

# GRUG: Test failed login with empty password
success, message = Main.admin_login("")
@test success == false
@test contains(message, "empty")
println("  ✓ Failed login with empty password")

# GRUG: Logout to reset state
Main.admin_logout()

# ==============================================================================
# [3] SESSION MANAGEMENT - LOGOUT
# ==============================================================================
println("\n[3] SESSION MANAGEMENT - LOGOUT")

# GRUG: Login first
Main.admin_login(default_password)

# GRUG: Test logout
message = Main.admin_logout()
@test contains(message, "terminated")
println("  ✓ Logout terminates active session")

# GRUG: Test logout when not logged in
message = Main.admin_logout()
@test contains(message, "No active")
println("  ✓ Logout reports no active session when not logged in")

# ==============================================================================
# [4] SESSION MANAGEMENT - IS_LOGGED_IN
# ==============================================================================
println("\n[4] SESSION MANAGEMENT - IS_LOGGED_IN")

# GRUG: Test is_logged_in when not logged in
@test Main.is_admin_logged_in() == false
println("  ✓ is_admin_logged_in returns false when not logged in")

# GRUG: Test is_logged_in after login
Main.admin_login(default_password)
@test Main.is_admin_logged_in() == true
println("  ✓ is_admin_logged_in returns true after login")

# GRUG: Test is_logged_in after logout
Main.admin_logout()
@test Main.is_admin_logged_in() == false
println("  ✓ is_admin_logged_in returns false after logout")

# ==============================================================================
# [5] JSON VALIDATION
# ==============================================================================
println("\n[5] JSON VALIDATION")

# GRUG: Test valid JSON
valid_json = """{"key": "value", "number": 42}"""
is_valid, error_msg = Main.validate_json(valid_json)
@test is_valid == true
@test error_msg == ""
println("  ✓ Valid JSON passes validation")

# GRUG: Test invalid JSON
invalid_json = """{"key": "value", "number": }"""
is_valid, error_msg = Main.validate_json(invalid_json)
@test is_valid == false
@test !isempty(error_msg)
println("  ✓ Invalid JSON fails validation with error message")

# GRUG: Test empty JSON
is_valid, error_msg = Main.validate_json("")
@test is_valid == false
@test contains(error_msg, "empty")
println("  ✓ Empty JSON fails validation")

# GRUG: Test JSON array
valid_array = """[1, 2, 3, "four"]"""
is_valid, error_msg = Main.validate_json(valid_array)
@test is_valid == true
println("  ✓ Valid JSON array passes validation")

# ==============================================================================
# [6] WRITE SAVE - ADMIN ONLY ENFORCEMENT
# ==============================================================================
println("\n[6] WRITE SAVE - ADMIN ONLY ENFORCEMENT")

# GRUG: Test writeSave without login (should fail)
test_json = """{"test": "data"}"""
test_file = "/tmp/test_save.specimen.gz"

# Clean up if file exists
if isfile(test_file)
    rm(test_file)
end

@test_throws ErrorException Main.append_to_save_file(test_json, test_file)
println("  ✓ writeSave throws error when not logged in")

# GRUG: Login and try again
Main.admin_login(default_password)

# GRUG: Test writeSave with login (should succeed)
result = Main.append_to_save_file(test_json, test_file)
@test contains(result, "Created new save file")
@test isfile(test_file)
println("  ✓ writeSave succeeds when logged in")

# Clean up
rm(test_file)

# ==============================================================================
# [7] WRITE SAVE - JSON VALIDATION
# ==============================================================================
println("\n[7] WRITE SAVE - JSON VALIDATION")

# GRUG: Test writeSave with invalid JSON (should fail)
invalid_json = """{"broken": }"""
@test_throws ErrorException Main.append_to_save_file(invalid_json, test_file)
println("  ✓ writeSave throws error with invalid JSON")

# ==============================================================================
# [8] WRITE SAVE - FILE OPERATIONS
# ==============================================================================
println("\n[8] WRITE SAVE - FILE OPERATIONS")

# GRUG: Test creating new file
new_json = """{"new_data": "test_value"}"""
result = Main.append_to_save_file(new_json, test_file)
@test contains(result, "Created new save file")
@test isfile(test_file)
println("  ✓ writeSave creates new file")

# GRUG: Test appending to existing file
append_json = """{"appended": "data"}"""
result = Main.append_to_save_file(append_json, test_file)
@test contains(result, "Appended JSON")
println("  ✓ writeSave appends to existing file")

# GRUG: Verify file content using system gunzip
# Note: new file wraps data in "custom_append", appends merge at top level
json_str_content = read(`gunzip -c $test_file`, String)
parsed = JSON.parse(json_str_content)
@test haskey(parsed, "custom_append")
@test parsed["custom_append"]["new_data"] == "test_value"
@test haskey(parsed, "appended")
println("  ✓ File contains both original and appended data")

# Clean up
rm(test_file)

# ==============================================================================
# [9] WRITE SAVE - MERGE LOGIC
# ==============================================================================
println("\n[9] WRITE SAVE - MERGE LOGIC")

# GRUG: Create initial file with dict (will be wrapped in custom_append)
initial_json = """{"section1": {"key1": "value1"}, "section2": [1, 2, 3]}"""
result = Main.append_to_save_file(initial_json, test_file)
@test contains(result, "Created new save file")

# GRUG: Append to existing file - this merges at top level
# Note: first write wrapped in custom_append, so we append to the top level
merge_json = """{"section3": "new_section"}"""
result = Main.append_to_save_file(merge_json, test_file)
@test contains(result, "Appended JSON")

# GRUG: Verify merge using system gunzip
json_str_content = read(`gunzip -c $test_file`, String)
parsed = JSON.parse(json_str_content)
@test haskey(parsed, "custom_append")  # Original data wrapped here
@test haskey(parsed, "section3")  # Appended at top level
println("  ✓ writeSave correctly appends to existing file")

# Clean up
rm(test_file)

# ==============================================================================
# [10] ERROR HANDLING - NO SILENT FAILURES
# ==============================================================================
println("\n[10] ERROR HANDLING - NO SILENT FAILURES")

# GRUG: Test empty filepath
@test_throws ErrorException Main.append_to_save_file(test_json, "")
println("  ✓ Empty filepath throws error")

# GRUG: Test empty JSON
@test_throws ErrorException Main.append_to_save_file("", test_file)
println("  ✓ Empty JSON throws error")

# GRUG: Test invalid JSON
@test_throws ErrorException Main.append_to_save_file("{broken}", test_file)
println("  ✓ Invalid JSON throws error")

# ==============================================================================
# DONE
# ==============================================================================
println("\n" * "="^60)
println("✅  ALL ADMIN SYSTEM TESTS PASSED (10 groups)")
println("="^60 * "\n")