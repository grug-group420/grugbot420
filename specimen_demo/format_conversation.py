#!/usr/bin/env python3
"""
GRUG CONVERSATION LOG FORMATTER (v7.16)
========================================
Turn a raw run_cli() transcript into a human-readable DIALOGUE.

v7.16 scaffold shape (single reply line, then telemetry block):

  🤖 AIML Output Scaffold:
  [Voice Text] Skeleton: claim. Support. (from the X cave) [Directives: a; b; c]
  --- DEBUG TELEMETRY (orchestration internals, not for speech) ---
  Mission: '...'
  Primary Action: X  (conf=Y, certainty=Z)
  Sure Actions: [...]
  Unsure Actions (Coinflip Side-Features): [...]
  Constraints: [...]
  Winning Node: node_X
  Lobe Context: ...
  ...
  =========================================

We render each cycle as:

  ### Cycle N · /mission
  **🗣️ Interviewer:** <mission text>
  **🧠 Grug** _(as **<voice>**, from the **<cave>** cave)_:

  > <natural-language reply — claim + support, no directives, no cave tag>

  <sub>compact stats strip</sub>

  <details>collapsed directives</details>
  <details>collapsed full telemetry</details>

NO SILENT FAILURES: exits non-zero on missing raw log. Cycles that
match no scaffold are rendered as explicit "cave is silent" dialogue.
"""
import gzip
import re
import sys
from pathlib import Path


# GRUG: Recognise either of the two prompt commands we support.
MISSION_RE = re.compile(r"^(/mission|/brainstorm)\s+(.+?)$", flags=re.MULTILINE)

# GRUG v7.16: Scaffold emits ONE reply line after the header.
#   [Voice prefix] <synthesized reply text>
# Followed immediately by the DEBUG TELEMETRY separator. We capture:
#   group(1) = voice text inside the leading brackets
#   group(2) = the remainder of the reply line (claim + support +
#              optional "(from the X cave)" + "[Directives: ...]")
SCAFFOLD_RE = re.compile(
    r"🤖 AIML Output Scaffold:\n"
    r"\[([^\]]+)\]\s*(.+?)\n"
    r"--- DEBUG TELEMETRY",
    flags=re.DOTALL,
)

# Pull the stats block bounded by the telemetry separator and the
# '=====' divider that closes every scaffold.
#
# GRUG: Primary Action text can be multi-word (e.g. "morning bring fresh
# light to cave"). The previous \S+ pattern only matched single-token
# action labels and silently dropped every multi-word cycle to a fallback
# of "?" for mission/primary/conf/cert/winner. Fix is a non-greedy .+?
# anchored on the trailing "  (conf=..., certainty=...)" tail. The double-
# space before "(conf" is preserved as a hard anchor because the engine
# always emits exactly two spaces there; if that ever changes, this regex
# must change with it (no silent failures).
#
TELEMETRY_RE = re.compile(
    r"--- DEBUG TELEMETRY \(orchestration internals, not for speech\) ---\n"
    r"Mission: '(.+?)'\n"
    r"Primary Action: (.+?)\s+\(conf=([0-9.]+), certainty=(\w+)\)\n"
    r"Sure Actions: \[(.*?)\]\n"
    r"Unsure Actions \(Coinflip Side-Features\): \[(.*?)\]\n"
    r".*?Winning Node: (\S+)\n",
    flags=re.DOTALL,
)
SILENT_RE = re.compile(r"--> No valid specimens found for this input\. Cave is silent\.")

# Split a v7.16 reply line into (clean_reply, cave_tag, directives_list).
CAVE_RE = re.compile(r"\s*\(from the ([a-z_]+) cave\)\s*")
DIRECTIVES_RE = re.compile(r"\s*\[Directives:\s*(.+?)\s*\]\s*$", flags=re.DOTALL)


def split_reply(raw_reply: str):
    """Strip structural tags off the v7.16 reply text.

    Returns (speech, cave, directives) where:
      speech     = the conversational sentence(s) (claim + support)
      cave       = the winning lobe name (e.g. "cooking") or "" if
                   the scaffold didn't surface one (unassigned nodes)
      directives = list of shaping directives, one per entry
    """
    text = raw_reply.strip()
    directives = []
    m = DIRECTIVES_RE.search(text)
    if m:
        directives = [d.strip() for d in m.group(1).split(";") if d.strip()]
        text = text[:m.start()].rstrip()
    cave = ""
    m = CAVE_RE.search(text)
    if m:
        cave = m.group(1)
        text = (text[:m.start()] + text[m.end():]).strip()
    return text, cave, directives


# ---------------------------------------------------------------------------
# Text cleaners
# ---------------------------------------------------------------------------

def clean_box(text: str) -> str:
    """Strip unicode box-drawing glyphs so markdown fences render cleanly."""
    text = re.sub(r"[║╠╣╔╗╚╝═─│┌┐└┘├┤┬┴┼]+", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_field(block: str, label_re: str, default: str = "?") -> str:
    """Pull a single-line scalar field out of a telemetry block."""
    m = re.search(label_re, block)
    return m.group(1).strip() if m else default


def extract_lobe_context(block: str) -> str:
    """Pull the `Lobe Context: ...` line from telemetry."""
    m = re.search(r"Lobe Context: (.+?)\n", block)
    return m.group(1).strip() if m else "?"


def extract_threshold_note(block: str) -> str:
    """v7.13: Pull the Fresh Memory `[threshold=X eligible=N]` header."""
    m = re.search(r"Fresh Memory \[threshold=([0-9.]+) eligible=(\d+)\]", block)
    return f"threshold={m.group(1)}, eligible={m.group(2)}" if m else "—"


def extract_status_block(raw: str, marker: str, which: str = "last") -> str:
    """First/last block from `marker` up to the next 'Brain >' line."""
    pattern = re.compile(
        re.escape(marker) + r".*?(?=Brain >|\Z)",
        flags=re.DOTALL
    )
    matches = list(pattern.finditer(raw))
    if not matches:
        return ""
    return matches[0 if which == "first" else -1].group(0)


# ---------------------------------------------------------------------------
# Main dialogue builder
# ---------------------------------------------------------------------------

def build_transcript(raw: str, true_raw_size: int) -> str:
    scaffolds = list(SCAFFOLD_RE.finditer(raw))
    commands = list(MISSION_RE.finditer(raw))

    out = []
    out.append("# GrugBot420 Comprehensive Specimen — Interview Transcript\n\n")
    out.append(
        "_Auto-generated from `specimen_demo/conversation_raw.log` by_ "
        "`specimen_demo/format_conversation.py`._\n\n"
    )
    out.append(
        "**Specimen:** `grugbot420_comprehensive.specimen.gz` "
        "(23 nodes / 4 lobes / 8 orchestration rules / 12 AIML tribe "
        "nodes / 10 attachments / 3 inhibitions / 3 pinned memories).\n\n"
    )
    out.append(
        "Below is an interview between a human **Interviewer** and "
        "**Grug** (the GrugBot420 engine after the comprehensive "
        "specimen has been loaded). AIML's job is to synthesize a "
        "**natural-language reply** from the node votes — the winning "
        "node's pattern becomes the claim, relational triples + sure "
        "companions become supporting clauses, and every word routes "
        "through the thesaurus / negative thesaurus / drop tables for "
        "variation. Statistics live behind a debug-telemetry separator, "
        "out of speech. `/mission` uses standard jitter (snap-back "
        "dominant); `/brainstorm` uses heavy scoped jitter (far-jump "
        "dominant).\n\n"
    )

    # ---- Baseline diagnostics ---------------------------------------
    first_status = extract_status_block(raw, "GRUGBOT SYSTEM STATUS", which="first")
    if first_status:
        out.append("---\n\n## 🔍 Baseline diagnostics (post-load)\n\n")
        out.append("```text\n" + clean_box(first_status) + "\n```\n\n")

    # ---- The interview ----------------------------------------------
    out.append("---\n\n## 🎙️ The Interview\n\n")

    for idx, sc in enumerate(scaffolds, start=1):
        voice = sc.group(1).strip()
        reply_raw = sc.group(2).strip()
        speech, cave, directives = split_reply(reply_raw)

        # Telemetry block runs from the scaffold's start to the next
        # '=====' divider that closes the scaffold.
        start = sc.start()
        end_m = re.search(r"={30,}", raw[start:start + 80000])
        end = start + (end_m.end() if end_m else min(50000, len(raw) - start))
        scaf = raw[start:end]

        # Find telemetry portion (everything from DEBUG TELEMETRY onward).
        sep = "--- DEBUG TELEMETRY (orchestration internals, not for speech) ---"
        tele_block = ""
        if sep in scaf:
            tele_block = sep + scaf.split(sep, 1)[1]

        # Pull stats from the telemetry block
        tele_match = TELEMETRY_RE.search(tele_block) if tele_block else None
        if tele_match:
            mission = tele_match.group(1)
            primary = tele_match.group(2)
            conf    = tele_match.group(3)
            cert    = tele_match.group(4)
            sure    = tele_match.group(5) or "None"
            unsure  = tele_match.group(6) or "None"
            winner  = tele_match.group(7)
        else:
            mission = "?"
            primary, conf, cert = "?", "?", "?"
            sure, unsure, winner = "None", "None", "?"

        lobe_ctx       = extract_lobe_context(tele_block) if tele_block else "?"
        antim          = extract_field(tele_block, r"Anti-Match Detected: (\w+)") if tele_block else "?"
        user_triples   = extract_field(tele_block, r"User Triples: (.+?)\n") if tele_block else "?"
        node_triples   = extract_field(tele_block, r"Node Triples: (.+?)\n") if tele_block else "?"
        threshold_note = extract_threshold_note(tele_block) if tele_block else "—"

        # Determine /mission vs /brainstorm by matching the nth
        # occurrence of this prompt text in the script file.
        kind = "/mission"
        script_path = Path("specimen_demo/conversation.txt")
        if script_path.exists():
            script_text = script_path.read_text()
            script_cmds = list(MISSION_RE.finditer(script_text))
            matches_for_this = [c for c in script_cmds
                                if c.group(2).strip() == mission.strip()]
            if matches_for_this:
                same_text_before = 0
                for prev in scaffolds[:idx - 1]:
                    prev_chunk = raw[prev.start():prev.start() + 80000]
                    prev_tele = TELEMETRY_RE.search(prev_chunk)
                    prev_mission = prev_tele.group(1) if prev_tele else ""
                    if prev_mission.strip() == mission.strip():
                        same_text_before += 1
                if same_text_before < len(matches_for_this):
                    kind = matches_for_this[same_text_before].group(1)

        # ----------- Render the dialogue turn ---------------------
        out.append(f"### Cycle {idx} · `{kind}`\n\n")
        out.append(f"**🗣️ Interviewer:** {mission}\n\n")
        voice_line = f"**🧠 Grug** _(as **{voice}**"
        if cave:
            voice_line += f", from the **{cave}** cave"
        voice_line += ")_:\n\n"
        out.append(voice_line)

        # Pure reply — claim + support, no directives, no cave tag.
        speech_clean = clean_box(speech)
        for line in speech_clean.split("\n"):
            out.append(f"> {line}\n" if line else ">\n")
        out.append("\n")

        # Compact stats strip under the reply.
        out.append("<sub>")
        out.append(f"primary `{primary}` · ")
        out.append(f"conf `{conf}` · ")
        out.append(f"certainty `{cert}` · ")
        out.append(f"sure `[{sure}]` · ")
        out.append(f"unsure `[{unsure}]` · ")
        out.append(f"winning node `{winner}` · ")
        out.append(f"lobe `{lobe_ctx}` · ")
        out.append(f"anti-match `{antim}` · ")
        out.append(f"fresh-mem gate `{threshold_note}` · ")
        out.append(f"user triples `{user_triples}` · ")
        out.append(f"node triples `{node_triples}`")
        out.append("</sub>\n\n")

        # Shaping directives — collapsed list.
        if directives:
            out.append("<details>\n")
            out.append(f"<summary>🎯 Shaping directives ({len(directives)})</summary>\n\n")
            for d in directives:
                out.append(f"- {d}\n")
            out.append("\n</details>\n\n")

        # Debug telemetry — collapsed, available but not in-your-face.
        if tele_block:
            out.append("<details>\n")
            out.append("<summary>🔧 Debug telemetry (orchestration internals)</summary>\n\n")
            out.append("```text\n")
            out.append(clean_box(tele_block))
            out.append("\n```\n")
            out.append("</details>\n\n")
        out.append("---\n\n")

    # ---- Silent cycles ---------------------------------------------
    scaffold_missions = []
    for sc in scaffolds:
        start = sc.start()
        chunk = raw[start:start + 80000]
        m = TELEMETRY_RE.search(chunk)
        scaffold_missions.append(m.group(1).strip() if m else "")

    silent_prompts = []
    used = [False] * len(scaffold_missions)
    for cmd in commands:
        mtxt = cmd.group(2).strip()
        matched = False
        for i, sm in enumerate(scaffold_missions):
            if not used[i] and sm == mtxt:
                used[i] = True
                matched = True
                break
        if not matched:
            silent_prompts.append((cmd.group(1), mtxt, cmd.start()))

    silent_marker_count = len(SILENT_RE.findall(raw))
    script_path = Path("specimen_demo/conversation.txt")
    if script_path.exists():
        script_cmds_all = MISSION_RE.findall(script_path.read_text())
        inferred_silent = max(0, len(script_cmds_all) - len(scaffolds))
        if inferred_silent > silent_marker_count:
            silent_marker_count = inferred_silent

    if silent_prompts or silent_marker_count:
        out.append("## 🤐 Silent cycles\n\n")
        out.append(
            f"Grug went silent on **{silent_marker_count}** prompt(s) — "
            f"no pattern in any lobe matched and the gate produced no "
            f"votes. That is NOT a failure, it's an explicit \"I don't "
            f"know from my seeded patterns\" answer. The engine prints "
            f"`No valid specimens found for this input. Cave is silent.` "
            f"in those cycles.\n\n"
        )
        for kind, mtxt, _ in silent_prompts:
            out.append(f"- **Interviewer:** `{kind}` {mtxt}\n")
            out.append(f"  **Grug:** _\\[silent — cave has no matching pattern\\]_\n\n")

    # ---- Final diagnostics -----------------------------------------
    last_status = extract_status_block(raw, "GRUGBOT SYSTEM STATUS", which="last")
    if last_status:
        out.append("## 🔍 Final diagnostics — `/status`\n\n")
        out.append("```text\n" + clean_box(last_status) + "\n```\n\n")

    last_aiml = extract_status_block(raw, "🤖 AIML TRIBE STATUS", which="last")
    if last_aiml:
        out.append("## 🔍 Final diagnostics — `/aimlStatus`\n\n")
        out.append("```text\n" + clean_box(last_aiml) + "\n```\n\n")

    # ---- Footer summary --------------------------------------------
    out.append("---\n\n## 📊 Transcript summary\n\n")
    if script_path.exists():
        script_cmd_count = len(MISSION_RE.findall(script_path.read_text()))
    else:
        script_cmd_count = "?"
    out.append(f"- Scripted `/mission` and `/brainstorm` commands: **{script_cmd_count}**\n")
    out.append(f"- AIML scaffolds Grug emitted: **{len(scaffolds)}**\n")
    out.append(f"- Silent cycles: **{silent_marker_count}**\n")
    out.append(f"- Raw log size (on disk): **{true_raw_size:,} bytes**\n")
    if true_raw_size != len(raw):
        out.append(
            f"- Raw log size (read into formatter): **{len(raw):,} bytes** "
            "(head + tail slice; the plain log would balloon O(N²) "
            "without v7.12–v7.14 context gating)\n"
        )

    return "".join(out)


# ---------------------------------------------------------------------------
# I/O plumbing (auto-decompress + bounded read)
# ---------------------------------------------------------------------------

def _resolve_raw_path(raw_path: Path) -> Path:
    """Accept either the plain or gzipped raw log; auto-fall-back to .gz."""
    if raw_path.exists():
        return raw_path
    gz_path = raw_path.with_suffix(raw_path.suffix + ".gz")
    if gz_path.exists():
        return gz_path
    raise SystemExit(
        f"FATAL: raw log not found at {raw_path} or {gz_path}"
    )


def main():
    raw_arg = Path(sys.argv[1] if len(sys.argv) > 1
                   else "specimen_demo/conversation_raw.log")
    md_path = Path(sys.argv[2] if len(sys.argv) > 2
                   else "specimen_demo/conversation.md")

    raw_path = _resolve_raw_path(raw_arg)

    is_gz = raw_path.suffix == ".gz"
    compressed_size = raw_path.stat().st_size
    print(
        f"[FMT] reading {raw_path} ({compressed_size:,} bytes"
        + (", gzipped" if is_gz else "") + ")",
        file=sys.stderr,
    )

    READ_CAP_FRONT = 32 * 1024 * 1024
    READ_CAP_TAIL = 4 * 1024 * 1024
    BUDGET = READ_CAP_FRONT + READ_CAP_TAIL

    opener = gzip.open if is_gz else open

    if is_gz:
        uncompressed_size = 0
        with opener(raw_path, "rb") as f:
            while True:
                chunk = f.read(1024 * 1024)
                if not chunk:
                    break
                uncompressed_size += len(chunk)
        raw_size = uncompressed_size
    else:
        raw_size = compressed_size

    if raw_size <= BUDGET:
        with opener(raw_path, "rt", encoding="utf-8", errors="replace") as f:
            raw = f.read()
    else:
        print(
            f"[FMT] raw log exceeds {BUDGET:,} bytes uncompressed; "
            f"reading {READ_CAP_FRONT:,} bytes from head and "
            f"{READ_CAP_TAIL:,} bytes from tail with a truncation marker",
            file=sys.stderr,
        )
        with opener(raw_path, "rb") as f:
            front_bytes = f.read(READ_CAP_FRONT)
        front = front_bytes.decode("utf-8", errors="replace")

        if is_gz:
            tail_bytes = b""
            with opener(raw_path, "rb") as f:
                to_skip = raw_size - READ_CAP_TAIL
                while to_skip > 0:
                    chunk = f.read(min(1024 * 1024, to_skip))
                    if not chunk:
                        break
                    to_skip -= len(chunk)
                tail_bytes = f.read()
            tail = tail_bytes.decode("utf-8", errors="replace")
        else:
            with raw_path.open("rb") as f:
                f.seek(-READ_CAP_TAIL, 2)
                tail = f.read().decode("utf-8", errors="replace")

        raw = (
            front
            + f"\n\n[... TRUNCATED {raw_size - BUDGET:,} "
              f"bytes of O(N^2) mission-memory recursion ...]\n\n"
            + tail
        )

    if not raw.strip():
        raise SystemExit("FATAL: raw log is empty")

    md = build_transcript(raw, raw_size)
    if is_gz:
        print(f"[FMT] uncompressed raw log size: {raw_size:,} bytes",
              file=sys.stderr)
    md_path.write_text(md)
    print(f"[FMT] wrote {md_path} ({md_path.stat().st_size:,} bytes)",
          file=sys.stderr)


if __name__ == "__main__":
    main()