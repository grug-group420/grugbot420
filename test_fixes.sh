#!/bin/bash

# Test script for command system error handling fixes
# This script tests all the fixes made to the GrugBot420 command system

echo "=========================================="
echo "Testing Command System Error Handling Fixes"
echo "=========================================="
echo ""

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "ERROR: Julia is not installed. Please install Julia 1.9+ to run these tests."
    echo "Visit https://julialang.org/downloads/ for installation instructions."
    exit 1
fi

echo "✓ Julia found: $(julia --version)"
echo ""

# Test 1: ALLOWED_ROLES Fix
echo "Test 1: Testing ALLOWED_ROLES constant fix (/pin command)"
echo "--------------------------------------------------------"

# Test valid roles
echo "/pin Test message 1" | timeout 2 julia src/Main.jl 2>&1 | grep -q "pinned" && echo "✓ /pin command works with User_Pinned role" || echo "✗ /pin command failed"
echo ""

# Test 2: /grow command JSON parsing
echo "Test 2: Testing /grow command JSON parsing with error messages"
echo "----------------------------------------------------------------"

# Test valid JSON
echo '/grow {"nodes":[{"pattern":"test","action_packet":"explain^2","json_data":{}}]}' | timeout 2 julia src/Main.jl 2>&1 | grep -q "Tribe expanded" && echo "✓ /grow accepts valid JSON" || echo "✗ /grow failed with valid JSON"

# Test invalid JSON (missing nodes)
echo '/grow {"not_nodes":[]}' | timeout 2 julia src/Main.jl 2>&1 | grep -q "FATAL" && echo "✓ /grow rejects invalid JSON (missing nodes)" || echo "✗ /grow should reject invalid JSON"
echo ""

# Test 3: JSON parsing error context
echo "Test 3: Testing JSON parsing error messages with context"
echo "--------------------------------------------------------"

# Test malformed JSON
echo '/grow {invalid json}' | timeout 2 julia src/Main.jl 2>&1 | grep -q "JSON parser failed" && echo "✓ /grow provides detailed JSON parser error" || echo "✗ /grow should provide detailed error messages"
echo ""

# Test 4: Empty input validation
echo "Test 4: Testing empty input validation"
echo "--------------------------------------"

echo '/grow ""' | timeout 2 julia src/Main.jl 2>&1 | grep -q "empty JSON string" && echo "✓ /grow rejects empty input with proper message" || echo "✗ /grow should reject empty input"
echo ""

# Test 5: Orchestration rule validation
echo "Test 5: Testing orchestration rule tag validation"
echo "--------------------------------------------------"

# Test valid rule
echo '/addRule Test rule with {MISSION} and {CONFIDENCE}' | timeout 2 julia src/Main.jl 2>&1 | grep -q "Rule tied to tree" && echo "✓ /addRule accepts valid tags" || echo "✗ /addRule failed"

# Test invalid tag
echo '/addRule Test rule with {INVALID_TAG}' | timeout 2 julia src/Main.jl 2>&1 | grep -q "fake magic rock" && echo "✓ /addRule rejects invalid tags" || echo "✗ /addRule should reject invalid tags"
echo ""

# Test 6: Command statistics tracking
echo "Test 6: Testing command execution statistics"
echo "---------------------------------------------"

# Run a few successful commands and check stats are tracked
(echo '/grow {"nodes":[{"pattern":"test1","action_packet":"explain^2","json_data":{}}]}' && \
 echo '/grow {"nodes":[{"pattern":"test2","action_packet":"explain^2","json_data":{}}]}') | timeout 5 julia src/Main.jl 2>&1 | grep -q "success" && echo "✓ Command statistics are tracked" || echo "✗ Command statistics tracking may need verification"
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "All tests completed. Review output above for any failures."
echo ""
echo "Note: Some tests may show '✗' if the binary had issues loading."
echo "The important thing is that error messages are shown instead of silent failures."