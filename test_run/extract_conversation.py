#!/usr/bin/env python3
"""
extract_conversation.py --- v2

GRUG: Transcribe the CLI driver log into a clean user <-> grug conversation.

Grug's ACTUAL VOICE is the text block starting at 'AIML Output Scaffold:'
up to (but not including) the '--- DEBUG TELEMETRY' banner. That is the
string that generate_aiml_payload() returns --- what a downstream LLM or
speech layer would say out loud. The block after DEBUG TELEMETRY is
internal orchestration info, not Grug's reply.

NO SILENT FAILURE: if a turn produced no scaffold (cave silent, /status,
/help, etc.) we keep the raw Brain> block verbatim so every turn shows
something. We never drop a turn.
"""
import re
import sys
from pathlib import Path

LOG_PATH = Path("test_run/conversation_run.log")
INPUT_PATH = Path("test_run/conversation.txt")
OUT_PATH = Path("test_run/conversation_log.md")

SCAFFOLD_HEADER = "AIML Output Scaffold:"
DEBUG_BANNER = "--- DEBUG TELEMETRY"
SILENT_MARK = "No valid specimens found for this input"


def load_commands():
    lines = []
    for raw in INPUT_PATH.read_text().splitlines():
        s = raw.strip()
        if s:
            lines.append(s)
    return lines


def split_blocks(log_text):
    """Split by 'Brain > ' prompt. First chunk is boot preamble --- drop."""
    parts = re.split(r"(?m)^Brain > ", log_text)
    return parts[1:]


def extract_grug_voice(block):
    """
    Pull the AIML scaffold (Grug's actual spoken reply) out of a block.
    Returns (voice_text, routing_dict) or (None, None).
    """
    idx = block.find(SCAFFOLD_HEADER)
    if idx == -1:
        return None, None
    # Start right after the header line
    after_header = block[idx + len(SCAFFOLD_HEADER):]
    # Skip leading newline(s)
    after_header = after_header.lstrip("\n")
    # End at DEBUG TELEMETRY banner
    end_idx = after_header.find(DEBUG_BANNER)
    if end_idx == -1:
        voice = after_header.strip()
    else:
        voice = after_header[:end_idx].rstrip()

    # Routing info from DEBUG TELEMETRY (if present)
    routing = {}
    primary = re.search(r"Primary Action:\s*(\S+)\s+\(conf=([\d.]+),\s*certainty=(\S+)\)", block)
    winning = re.search(r"Winning Node:\s*(\S+)", block)
    lobe_ctx = re.search(r"Lobe Context:\s*(.+)", block)
    if primary:
        routing["action"] = primary.group(1)
        routing["conf"] = primary.group(2)
        routing["certainty"] = primary.group(3)
    if winning:
        routing["winning_node"] = winning.group(1)
    if lobe_ctx:
        routing["lobe_ctx"] = lobe_ctx.group(1).strip()
    return voice, routing


def extract_engine_events(block):
    """Pull attachment-relay and gate lines so readers see the routing path."""
    events = []
    for line in block.splitlines():
        s = line.strip()
        if "[ENGINE]" in s and "Attachment relay" in s:
            events.append(s)
        elif "[v7.18]" in s and "topicality gate" in s:
            events.append(s)
        elif "[ORCHESTRATOR]" in s and "TIE DETECTED" in s:
            events.append(s)
        elif "valid votes passed gate" in s:
            events.append(s)
    return events


def is_cave_silent(block):
    return SILENT_MARK in block and SCAFFOLD_HEADER not in block


def render_readonly(block):
    """For /help, /status, /lobes, /nodes etc. --- keep the whole printed block."""
    txt = block.strip()
    # Drop the very long boot banner if this is the load turn (keep it short)
    if len(txt) > 2000:
        lines = txt.splitlines()
        if len(lines) > 60:
            txt = "\n".join(lines[:60]) + f"\n... [{len(lines) - 60} more lines trimmed] ..."
    return txt


def render_markdown(pairs):
    out = []
    out.append("# Grug Live Conversation Log")
    out.append("")
    out.append("Driven through the unmodified GrugBot420 CLI via stdin. Every entry shows")
    out.append("the exact user command and the exact text Grug emits --- the AIML scaffold")
    out.append("is Grug's spoken reply (what `generate_aiml_payload` returns); everything")
    out.append("after the `--- DEBUG TELEMETRY` banner is internal routing info shown")
    out.append("separately for transparency.")
    out.append("")
    out.append("---")
    out.append("")

    for i, (cmd, info) in enumerate(pairs, start=1):
        out.append(f"## Turn {i}")
        out.append("")
        out.append(f"**User said:** `{cmd}`")
        out.append("")

        if info is None:
            out.append("_(no log block --- driver hit EOF before a response was emitted)_")
            out.append("")
            continue

        kind = info["kind"]

        if kind == "voice":
            out.append("**Engine events:**")
            out.append("")
            out.append("```")
            if info["events"]:
                for ev in info["events"]:
                    out.append(ev)
            else:
                out.append("(no relay/gate events logged)")
            out.append("```")
            out.append("")

            r = info["routing"]
            if r:
                parts = []
                if "action" in r:
                    parts.append(f"primary_action=`{r['action']}`")
                    parts.append(f"confidence=`{r['conf']}`")
                    parts.append(f"certainty=`{r['certainty']}`")
                if "winning_node" in r:
                    parts.append(f"winning_node=`{r['winning_node']}`")
                out.append("**Routing:** " + "  ·  ".join(parts))
                out.append("")

            out.append("**Grug said:**")
            out.append("")
            out.append("```text")
            out.append(info["voice"])
            out.append("```")
            out.append("")

        elif kind == "silent":
            out.append("**Grug said:** _cave is silent --- no specimen matched this input._")
            out.append("")

        elif kind == "readonly":
            out.append("**Grug printed:**")
            out.append("")
            out.append("```")
            out.append(info["raw"])
            out.append("```")
            out.append("")

        else:
            out.append("**Grug printed:**")
            out.append("")
            out.append("```")
            out.append(info["raw"])
            out.append("```")
            out.append("")

    return "\n".join(out)


def classify(block):
    voice, routing = extract_grug_voice(block)
    if voice is not None:
        return {
            "kind": "voice",
            "voice": voice,
            "routing": routing,
            "events": extract_engine_events(block),
            "raw": block.strip(),
        }
    if is_cave_silent(block):
        return {"kind": "silent", "raw": block.strip()}
    return {"kind": "readonly", "raw": render_readonly(block)}


def main():
    if not LOG_PATH.exists():
        print(f"!!! FATAL: log not found at {LOG_PATH} !!!", file=sys.stderr)
        sys.exit(1)
    if not INPUT_PATH.exists():
        print(f"!!! FATAL: input script not found at {INPUT_PATH} !!!", file=sys.stderr)
        sys.exit(1)

    log_text = LOG_PATH.read_text()
    commands = load_commands()
    blocks = split_blocks(log_text)

    pairs = []
    for i, cmd in enumerate(commands):
        info = classify(blocks[i]) if i < len(blocks) else None
        pairs.append((cmd, info))

    md = render_markdown(pairs)

    # GRUG: append the session summary stats (same as before).
    stats = Path("test_run/session_stats.md")
    if stats.exists():
        md += "\n\n" + stats.read_text()

    OUT_PATH.write_text(md)
    voice_count = sum(1 for _, info in pairs if info and info.get("kind") == "voice")
    silent_count = sum(1 for _, info in pairs if info and info.get("kind") == "silent")
    readonly_count = sum(1 for _, info in pairs if info and info.get("kind") == "readonly")
    print(f"wrote {OUT_PATH} ({len(md.splitlines())} lines)")
    print(f"  voice turns    : {voice_count}")
    print(f"  silent turns   : {silent_count}")
    print(f"  readonly turns : {readonly_count}")


if __name__ == "__main__":
    main()
