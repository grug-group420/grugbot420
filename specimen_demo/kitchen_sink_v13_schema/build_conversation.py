#!/usr/bin/env python3
"""Build CONVERSATION.md showing v11/v12/v13 replies for each mission."""
import re
from pathlib import Path

DIR = Path(__file__).parent

def parse_spoken(path: Path) -> dict:
    """Return {mission_text -> reply_text}. If a mission appears multiple
    times we keep the LAST reply (most-recent-state)."""
    text = path.read_text(encoding="utf-8", errors="replace")
    out = {}
    blocks = re.findall(r"- mission : '(.*?)'\s*\n\s+reply\s+:\s+(.+?)(?=\n- mission|\Z)",
                        text, re.DOTALL)
    for m, r in blocks:
        out[m.strip()] = r.strip()
    return out

v11 = parse_spoken(DIR / "spoken_v11.txt")
v12 = parse_spoken(DIR / "spoken_v12.txt")
v13 = parse_spoken(DIR / "spoken_v13.txt")

# Merge mission set, preserving v13 ordering when possible
ordered = []
seen = set()
text = (DIR / "spoken_v13.txt").read_text(encoding="utf-8", errors="replace")
for m in re.findall(r"- mission : '(.*?)'", text):
    m = m.strip()
    if m not in seen:
        seen.add(m)
        ordered.append(m)
# Append v11/v12 only missions
for src in (v12, v11):
    for m in src:
        if m not in seen:
            seen.add(m)
            ordered.append(m)

lines = []
lines.append("# Kitchen Sink v13 — Three-Way Conversation Diff")
lines.append("")
lines.append("Side-by-side spoken-reply comparison: v11 (pre-coherence) vs")
lines.append("v12 (coherence fix) vs v13 (schema utilization).")
lines.append("")
lines.append("Missions where v13 is silent but v12 spoke (or vice-versa) are")
lines.append("included with `(silent — pattern miss / gate filter)` so the diff")
lines.append("stays readable.")
lines.append("")
lines.append("---")
lines.append("")

for m in ordered:
    lines.append(f"### `{m}`")
    lines.append("")
    for tag, src in (("v11", v11), ("v12", v12), ("v13", v13)):
        r = src.get(m, "*(silent — pattern miss / gate filter)*")
        # collapse whitespace
        r = re.sub(r"\s+", " ", r)
        lines.append(f"- **{tag}**: {r}")
    lines.append("")

(DIR / "CONVERSATION.md").write_text("\n".join(lines), encoding="utf-8")
print(f"Wrote {DIR/'CONVERSATION.md'} — {len(ordered)} unique missions")
