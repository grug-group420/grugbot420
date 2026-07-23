#!/usr/bin/env python3
"""
parse_missions.py — Parse the raw all_missions_raw.txt output into structured results.
Extracts the AIML scaffold/ask sections and splits conversational reply from debug telemetry.
"""

import re
import sys
import os

RAW_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "specimens", "all_missions_raw.txt")
RESULTS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "specimens", "chat_results_raw.txt")

def parse_missions(raw_text):
    results = []
    # Split on MISSION_START markers
    blocks = re.split(r'===MISSION_START:(.*?)===', raw_text)
    # blocks = [preamble, mission1_name, mission1_content, mission2_name, mission2_content, ...]
    
    for i in range(1, len(blocks), 2):
        mission_name = blocks[i]
        mission_content = blocks[i+1] if i+1 < len(blocks) else ""
        
        # Trim at MISSION_END
        end_marker = f"===MISSION_END:{mission_name}==="
        if end_marker in mission_content:
            mission_content = mission_content[:mission_content.index(end_marker)]
        
        # Check for error
        if "!!!MISSION_ERROR:" in mission_content:
            error_msg = re.search(r'!!!MISSION_ERROR: (.*)', mission_content)
            error_text = error_msg.group(1).strip() if error_msg else "Unknown error"
            results.append({
                "input": mission_name,
                "status": "ERROR",
                "conversational_reply": f"[Mission crashed: {error_text}]",
                "full_scaffold": "",
                "digest": "",
            })
            continue
        
        # Parse AIML scaffold
        scaffold_marker = "\U0001f916 AIML Output Scaffold:"
        ask_marker = "\U0001f916 AIML Ask Question:"
        
        if scaffold_marker in mission_content:
            idx = mission_content.index(scaffold_marker)
            content_start = idx + len(scaffold_marker)
            full_scaffold = mission_content[content_start:].strip()
            
            # Trim trailing separator line
            end_line = "========================================="
            if end_line in full_scaffold:
                full_scaffold = full_scaffold[:full_scaffold.index(end_line)].strip()
            
            # Split at DEBUG TELEMETRY
            telemetry_marker = "--- DEBUG TELEMETRY"
            if telemetry_marker in full_scaffold:
                idx = full_scaffold.index(telemetry_marker)
                conversational_reply = full_scaffold[:idx].strip()
            else:
                conversational_reply = full_scaffold
            
            # Extract digest
            digest = ""
            digest_pattern = r'Mission "(.*?)".+primary=(\w+) conf=([\d.]+) node=(\w+)'
            m = re.search(digest_pattern, full_scaffold)
            if m:
                digest = m.group(0)
            
            results.append({
                "input": mission_name,
                "status": "OK",
                "conversational_reply": conversational_reply,
                "full_scaffold": full_scaffold,
                "digest": digest,
            })
        
        elif ask_marker in mission_content:
            idx = mission_content.index(ask_marker)
            content_start = idx + len(ask_marker)
            full_scaffold = mission_content[content_start:].strip()
            
            # Trim trailing separator
            end_line = "========================================="
            if end_line in full_scaffold:
                full_scaffold = full_scaffold[:full_scaffold.index(end_line)].strip()
            
            results.append({
                "input": mission_name,
                "status": "ASK",
                "conversational_reply": full_scaffold.strip(),
                "full_scaffold": full_scaffold.strip(),
                "digest": "",
            })
        
        else:
            results.append({
                "input": mission_name,
                "status": "NO_SCAFFOLD",
                "conversational_reply": "[No AIML output captured]",
                "full_scaffold": "",
                "digest": "",
            })
    
    return results

def main():
    with open(RAW_PATH, "r") as f:
        raw_text = f.read()
    
    results = parse_missions(raw_text)
    
    # Print summary
    print(f"Parsed {len(results)} missions:")
    ok = sum(1 for r in results if r["status"] == "OK")
    ask = sum(1 for r in results if r["status"] == "ASK")
    err = sum(1 for r in results if r["status"] == "ERROR")
    print(f"  OK: {ok}, ASK: {ask}, ERROR: {err}")
    print()
    
    for r in results:
        reply = r["conversational_reply"]
        display = reply[:100] + "..." if len(reply) > 100 else reply
        print(f'  "{r["input"]}" [{r["status"]}]: {display}')
    
    # Save structured results
    with open(RESULTS_PATH, "w") as f:
        for r in results:
            f.write("=== INPUT ===\n")
            f.write(r["input"] + "\n")
            f.write("=== STATUS ===\n")
            f.write(r["status"] + "\n")
            f.write("=== CONVERSATIONAL_REPLY ===\n")
            f.write(r["conversational_reply"] + "\n")
            f.write("=== DIGEST ===\n")
            f.write(r["digest"] + "\n")
            f.write("=== FULL_SCAFFOLD ===\n")
            f.write(r["full_scaffold"] + "\n")
            f.write("\n")
    
    print(f"\nResults saved to specimens/chat_results_raw.txt")

if __name__ == "__main__":
    main()
