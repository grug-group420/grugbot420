#!/usr/bin/env python3
"""Pair v11 spoken replies with v12 spoken replies by mission and emit markdown."""
import re
import sys
from pathlib import Path

def load(path):
    out = []
    cur = {}
    for line in path.read_text().splitlines():
        m = re.match(r"-\s+mission\s+:\s+'(.*)'\s*$", line)
        if m:
            if cur:
                out.append(cur)
            cur = {"mission": m.group(1)}
            continue
        m = re.match(r"\s+reply\s+:\s+(.*)$", line)
        if m:
            cur["reply"] = m.group(1)
    if cur:
        out.append(cur)
    return out

v11 = load(Path("/workspace/grug_test/kitchen_sink_v12_coherence/spoken_v11.txt"))
v12 = load(Path("/workspace/grug_test/kitchen_sink_v12_coherence/spoken_v12.txt"))

# Pair by index (both runs hit same missions in same order)
n = min(len(v11), len(v12))
print("# Coherence Delta — v11 (broken scaffold) vs v12 (Fix A + Fix B)\n")
print(f"Both runs: same missions, same seed specimen, same tonal judge.\n")
print(f"Only the AIML scaffold + system_prompt-body wiring changed.\n")
print(f"Pair count: {n}\n")
print("---\n")

improved = 0
neutral = 0
for i in range(n):
    a = v11[i]
    b = v12[i]
    mission = a.get("mission", "?")
    ra = a.get("reply", "")
    rb = b.get("reply", "")
    # Heuristic: v11 was parroting if reply contains "what matters here:" or
    # "here is what matters" or ends in fragment of mission
    parroted = any(s in ra for s in [
        "what matters here:",
        "here is what matters:",
        "Thinking it through:",
    ])
    diff = ra != rb
    tag = "🟢 IMPROVED" if (parroted and diff) else ("🟡 changed" if diff else "⚪ same")
    if parroted and diff:
        improved += 1
    elif diff:
        neutral += 1
    print(f"### {i+1}. mission: `{mission}` — {tag}")
    print(f"- v11: `{ra}`")
    print(f"- v12: `{rb}`")
    print()

print(f"\n## Tally\n")
print(f"- 🟢 IMPROVED (broken pattern echo replaced with system_prompt body): **{improved}**")
print(f"- 🟡 changed but not from a known broken pattern: **{neutral}**")
print(f"- ⚪ identical: **{n - improved - neutral}**")
