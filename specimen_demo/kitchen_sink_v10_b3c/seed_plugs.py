#!/usr/bin/env python3
"""
v7.21b-3c: Seed kitchen-sink nodes with frame_hints plugs.

Reads grug_test/kitchen_sink_v9_b3a/kitchen_sink.specimen.gz, mutates
node.json_data["frame_hints"] for a chosen subset, writes
grug_test/kitchen_sink_v10_b3c/kitchen_sink.specimen.gz.

The seeding is deliberately partial — about a third of nodes get plugs
so we can see lift / inhibit / neutral all fire in the same run. Legacy
nodes (no plugs) remain neutral pass-through, exercising back-compat.

Plug map is hand-curated to match what each pattern *should* feel like
when it fires:
  - sad / worried / lonely / i feel          -> de_escalating, warm
  - danger / warning / watch out             -> imperative, terse
  - hello / greet / morning                  -> warm
  - thank you                                -> warm
  - victory / i did it                       -> warm
  - what is / how does / why                 -> exploratory
  - think about                              -> contemplative, exploratory
  - clarify / define / tell me               -> exploratory
"""

from __future__ import annotations
import gzip
import json
import os
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SRC = REPO / "grug_test" / "kitchen_sink_v9_b3a" / "kitchen_sink.specimen.gz"
DST = REPO / "grug_test" / "kitchen_sink_v10_b3c" / "kitchen_sink.specimen.gz"

# pattern-prefix -> list of frame_hints
# match by `node["pattern"].lower().startswith(prefix)` for stability
PLUG_MAP = {
    # Vulnerable / reflective tones — de-escalating + warm.
    "sad":           ["de_escalating", "warm"],
    "worried":       ["de_escalating", "warm"],
    "lonely":        ["de_escalating", "warm"],
    "i feel":        ["warm", "contemplative"],

    # Danger / urgency — imperative + terse.
    "danger":        ["imperative", "terse"],
    "warning":       ["imperative"],
    "watch out":     ["imperative", "terse"],
    "fire burns":    ["imperative", "terse"],
    "careful":       ["imperative"],
    "run":           ["imperative", "terse"],
    "hide":          ["imperative"],

    # Greetings + thanks + celebration — warm.
    "hello hi greeting": ["warm"],
    "hello hi":      ["warm"],
    "good morning":  ["warm"],
    "howdy":         ["warm"],
    "thank you":     ["warm"],
    "victory":       ["warm"],
    "i did it":      ["warm"],

    # Inquiry — exploratory.
    "what is":       ["exploratory"],
    "how does":      ["exploratory"],
    "how do you":    ["exploratory"],
    "why":           ["exploratory"],
    "do you know":   ["exploratory"],
    "tell me":       ["exploratory"],
    "clarify":       ["exploratory"],
    "define":        ["exploratory"],

    # Reflection — contemplative.
    "think about":   ["contemplative", "exploratory"],
    "think ponder":  ["contemplative"],
    "remember when": ["contemplative"],
    "last time":     ["contemplative"],

    # Planning — plain (deliberately a NEUTRAL plug to test the
    # mismatch-under-relational case). In a relational hostile context
    # these should get inhibited because their plug doesn't match.
    "should we":     ["plain"],
    "plan to":       ["plain"],
    "next step":     ["plain"],
}


def first_match(pattern: str):
    """Return the longest-matching plug list for the given pattern, or None."""
    pat = pattern.lower().strip()
    # Sort by length DESC so 'hello hi greeting' beats 'hello hi'
    for prefix in sorted(PLUG_MAP.keys(), key=len, reverse=True):
        if pat.startswith(prefix):
            return PLUG_MAP[prefix]
    return None


def main():
    with gzip.open(SRC, "rt", encoding="utf-8") as f:
        spec = json.load(f)

    seeded = 0
    skipped = 0
    seeded_log = []
    for node in spec.get("nodes", []):
        plugs = first_match(node.get("pattern", ""))
        if plugs is None:
            skipped += 1
            continue
        node.setdefault("json_data", {})
        node["json_data"]["frame_hints"] = list(plugs)
        seeded += 1
        seeded_log.append((node["id"], node["pattern"], plugs))

    DST.parent.mkdir(parents=True, exist_ok=True)
    with gzip.open(DST, "wt", encoding="utf-8") as f:
        json.dump(spec, f, indent=2)

    # Sidecar: human-readable summary of what got plugged.
    sidecar = DST.parent / "seeded_plugs.md"
    with open(sidecar, "w", encoding="utf-8") as f:
        f.write("# v7.21b-3c — seeded frame_hints plugs\n\n")
        f.write(f"Source: `{SRC.relative_to(REPO)}`\n")
        f.write(f"Output: `{DST.relative_to(REPO)}`\n\n")
        f.write(f"- nodes seeded: **{seeded}**\n")
        f.write(f"- nodes left as legacy / no plugs: **{skipped}**\n\n")
        f.write("## Seeded nodes\n\n")
        f.write("| node_id | pattern | frame_hints |\n")
        f.write("|---------|---------|-------------|\n")
        for nid, pat, plugs in sorted(seeded_log):
            f.write(f"| `{nid}` | `{pat[:30]}` | `{plugs}` |\n")

    print(f"OK: {seeded} nodes seeded, {skipped} left untouched.")
    print(f"    -> {DST}")
    print(f"    -> {sidecar}")


if __name__ == "__main__":
    main()
