#!/usr/bin/env python3
"""
Extract spoken-reply lines from a kitchen-sink run.log.
For each AIML scaffold block ('🤖 AIML Output Scaffold:' ... '--- DEBUG TELEMETRY'),
capture the line between them (the spoken reply) plus the corresponding
"Mission: '...'" from the telemetry block.
"""
import re
import sys
from pathlib import Path

def extract(path: Path):
    text = path.read_text(encoding="utf-8", errors="replace").splitlines()
    out = []
    i = 0
    n = len(text)
    while i < n:
        line = text[i]
        if "AIML Output Scaffold:" in line:
            # Spoken reply is the next non-empty line
            j = i + 1
            while j < n and text[j].strip() == "":
                j += 1
            spoken = text[j].strip() if j < n else ""
            # Find the matching Mission: line
            mission = ""
            for k in range(j, min(j + 40, n)):
                m = re.match(r"Mission:\s*'(.*)'\s*$", text[k])
                if m:
                    mission = m.group(1)
                    break
            out.append((mission, spoken))
            i = j + 1
        else:
            i += 1
    return out

if __name__ == "__main__":
    path = Path(sys.argv[1])
    label = sys.argv[2] if len(sys.argv) > 2 else path.stem
    pairs = extract(path)
    print(f"# {label}: {len(pairs)} mission/reply pairs\n")
    for mission, spoken in pairs:
        print(f"- mission : {mission!r}")
        print(f"  reply   : {spoken}")
        print()
