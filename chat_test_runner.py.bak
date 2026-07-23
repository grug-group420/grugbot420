#!/usr/bin/env python3
"""
chat_test_runner.py — Runs each of 25 test missions as a separate Julia child
process, captures stdout, and parses the AIML scaffold output into natural
language responses.

This replaces the Julia-based full_chat_test.jl because:
1. redirect_stdout(IOBuffer) doesn't work in Julia (Tasks hold original stdout refs)
2. Running all 25 missions in one child process crashes if any single mission fails
3. Python subprocess handling is more robust for this capture-and-parse pattern
"""

import subprocess
import sys
import os
import json
import re

WRAPPER_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_mission_wrapper.jl")
RESULTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "specimens", "chat_results_raw.txt")

TEST_INPUTS = [
    ("derivative", "node_math_001"),
    ("integral", "node_math_002"),
    ("pythagorean theorem", "node_math_003"),
    ("what is consciousness", "node_phil_001"),
    ("meaning of life", "node_phil_002"),
    ("free will", "node_phil_003"),
    ("danger", "node_surv_001"),
    ("hide and seek", "node_surv_002"),
    ("fight back", "node_surv_003"),
    ("i feel sad", "node_emp_001"),
    ("i feel anxious", "node_emp_002"),
    ("validate my feelings", "node_emp_003"),
    ("write a poem", "node_crea_001"),
    ("tell me a story", "node_crea_002"),
    ("imagine", "node_crea_003"),
    ("hello", "node_greet_001"),
    ("what time is it", "node_time_001"),
    ("what happened before", "node_time_002"),
    ("ignore mathematics", "node_anti_001"),
    ("stop empathy", "node_anti_002"),
    ("sunset image", "node_img_001"),
    ("watch out", "node_warn_001"),
    ("why does", "node_ask_001"),
    ("obsolete test pattern", "node_grave_001"),
    ("sacred knowledge", "node_unlink_001"),
]

def parse_mission_output(raw_stdout: str) -> dict:
    """Parse captured stdout from a single process_mission() call.
    Extract the AIML scaffold section and split at the DEBUG TELEMETRY divider.
    """
    scaffold_marker = "\U0001f916 AIML Output Scaffold:"
    ask_marker = "\U0001f916 AIML Ask Question:"
    
    result = {
        "status": "OK",
        "conversational_reply": "",
        "full_scaffold": "",
        "digest": "",
    }
    
    if scaffold_marker in raw_stdout:
        idx = raw_stdout.index(scaffold_marker)
        content_start = idx + len(scaffold_marker)
        full_scaffold = raw_stdout[content_start:].strip()
        
        # Find the MISSION_END marker and trim there
        end_marker = "===MISSION_END:"
        if end_marker in full_scaffold:
            full_scaffold = full_scaffold[:full_scaffold.index(end_marker)].strip()
        
        # Also trim at the "==========================================" that marks end of telemetry
        end_line = "========================================="
        if end_line in full_scaffold:
            full_scaffold = full_scaffold[:full_scaffold.index(end_line)].strip()
        
        result["full_scaffold"] = full_scaffold
        
        # Split at DEBUG TELEMETRY divider
        telemetry_marker = "--- DEBUG TELEMETRY"
        if telemetry_marker in full_scaffold:
            idx = full_scaffold.index(telemetry_marker)
            result["conversational_reply"] = full_scaffold[:idx].strip()
        else:
            result["conversational_reply"] = full_scaffold
    
    elif ask_marker in raw_stdout:
        idx = raw_stdout.index(ask_marker)
        content_start = idx + len(ask_marker)
        full_scaffold = raw_stdout[content_start:].strip()
        
        end_marker = "===MISSION_END:"
        if end_marker in full_scaffold:
            full_scaffold = full_scaffold[:full_scaffold.index(end_marker)].strip()
        
        result["full_scaffold"] = full_scaffold
        result["conversational_reply"] = full_scaffold
        result["status"] = "ASK"
    
    else:
        result["status"] = "NO_SCAFFOLD"
        result["conversational_reply"] = "[No AIML output captured]"
        result["full_scaffold"] = raw_stdout[-500:] if len(raw_stdout) > 500 else raw_stdout
    
    # Extract digest
    digest_pattern = r'Mission "(.*?)" .+ primary=(\w+) conf=([\d.]+) node=(\w+)'
    m = re.search(digest_pattern, raw_stdout)
    if m:
        result["digest"] = m.group(0)
    
    return result

def run_single_mission(input_text: str) -> dict:
    """Run one mission as a child Julia process, capture stdout."""
    try:
        proc = subprocess.run(
            ["julia", WRAPPER_PATH, input_text],
            capture_output=True,
            text=True,
            timeout=120,
        )
        combined = proc.stdout
        # Also check stderr for the scaffold (in case stdout was redirected)
        if "AIML Output Scaffold" not in combined and "AIML Output Scaffold" in proc.stderr:
            combined = proc.stderr
        result = parse_mission_output(combined)
        if proc.returncode != 0 and result["status"] == "OK":
            result["status"] = "PARTIAL"
        return result
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "conversational_reply": "[Timeout after 120s]", "full_scaffold": "", "digest": ""}
    except Exception as e:
        return {"status": "FATAL", "conversational_reply": f"[Error: {e}]", "full_scaffold": "", "digest": ""}

def main():
    print("=" * 60)
    print("COMPREHENSIVE CHAT TEST - 25 Node Patterns (AIML Capture)")
    print("=" * 60)
    print()
    
    results = []
    
    for i, (input_text, expected_node) in enumerate(TEST_INPUTS):
        print(f'[{i+1}/25] "{input_text}" -> ', end="", flush=True)
        result = run_single_mission(input_text)
        result["input"] = input_text
        result["expected_node"] = expected_node
        
        # Display abbreviated
        reply = result["conversational_reply"]
        display = reply[:100] + "..." if len(reply) > 100 else reply
        print(f'{result["status"]}: {display}')
        results.append(result)
    
    print()
    print("=" * 60)
    print(f"CHAT TEST COMPLETE - {len(results)} results")
    print("=" * 60)
    
    # Save results
    with open(RESULTS_PATH, "w") as f:
        for r in results:
            f.write("=== INPUT ===\n")
            f.write(r["input"] + "\n")
            f.write("=== EXPECTED_NODE ===\n")
            f.write(r["expected_node"] + "\n")
            f.write("=== STATUS ===\n")
            f.write(r["status"] + "\n")
            f.write("=== CONVERSATIONAL_REPLY ===\n")
            f.write(r["conversational_reply"] + "\n")
            f.write("=== DIGEST ===\n")
            f.write(r["digest"] + "\n")
            f.write("=== FULL_SCAFFOLD ===\n")
            f.write(r["full_scaffold"] + "\n")
            f.write("\n")
    
    print(f"Raw results saved to specimens/chat_results_raw.txt")
    
    # Summary
    ok_count = sum(1 for r in results if r["status"] == "OK")
    print(f"\nSummary: {ok_count}/{len(results)} missions produced AIML output")

if __name__ == "__main__":
    main()
