#!/usr/bin/env python3
"""
GRUG CONVERSATION LOG FORMATTER (v7.14)
========================================
Turn a raw run_cli() transcript into a human-readable DIALOGUE.

The whole log is framed as an interview: the Interviewer asks a
question (the /mission or /brainstorm text from the script) and Grug
answers (the AIML Output Scaffold the engine emitted). We render:

  **Interviewer:** <prompt>
  **Grug:**       <headline paraphrase from primary action + winning node>

  <blockquote>
  Full AIML response payload (the exact bytes a downstream LLM
  would receive for this cycle)
  </blockquote>

  Then a compact stats strip (confidence, certainty, lobe, etc.)

This is what the user explicitly asked for: "include actual logs of
replies etc ... you querying the ai replying". The /mission prompt is
the question, the scaffold IS Grug's reply. We no longer bury the
reply inside a collapsible after a giant stats table.

NO SILENT FAILURES: exits non-zero on missing raw log. If a cycle is
silent (no pattern matched), we render it as Grug saying so, explicitly.
"""
import gzip
import re
import sys
from pathlib import Path


# GRUG: Recognise either of the two prompt commands we support.
MISSION_RE = re.compile(r"^(/mission|/brainstorm)\s+(.+?)$", flags=re.MULTILINE)

# GRUG v7.15: Scaffold now LEADS with a conversational reply and puts
# stats behind a --- DEBUG TELEMETRY --- separator. The regex picks up
# the scaffold start + voice + opener + mission, and we fish out the
# stats from the telemetry block separately.
SCAFFOLD_RE = re.compile(
    r"🤖 AIML Output Scaffold:\n"
    r"\[Voice: (.+?)\]\n"
    r"On \"(.+?)\" — I'll (.+?)\.\n"
)
# Extract the stats we need from the debug telemetry block that follows
# the scaffold header. The telemetry block is bounded by the separator
# line and the next '=====' divider.
TELEMETRY_RE = re.compile(
    r"--- DEBUG TELEMETRY \(orchestration internals, not for speech\) ---\n"
    r"Mission: '(.+?)'\n"
    r"Primary Action: (\S+)\s+\(conf=([0-9.]+), certainty=(\w+)\)\n"
    r"Sure Actions: \[(.*?)\]\n"
    r"Unsure Actions \(Coinflip Side-Features\): \[(.*?)\]\n"
    r".*?Winning Node: (\S+)\n",
    flags=re.DOTALL
)
SILENT_RE = re.compile(r"--> No valid specimens found for this input\. Cave is silent\.")


# ---------------------------------------------------------------------------
# Text cleaners
# ---------------------------------------------------------------------------

def clean_box(text: str) -> str:
    """Strip unicode box-drawing glyphs so markdown fences render cleanly."""
    text = re.sub(r"[║╠╣╔╗╚╝═─│┌┐└┘├┤┬┴┼]+", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_field(scaffold: str, label_re: str, default: str = "?") -> str:
    """Pull a single-line scalar field out of a scaffold block."""
    m = re.search(label_re, scaffold)
    return m.group(1).strip() if m else default


def extract_lobe_context(scaffold: str) -> str:
    """Anchor between the LOBE CONTEXT and RELATIONAL CONTEXT dividers."""
    m = re.search(
        r"--- LOBE CONTEXT \(PREFRONTAL CORTEX\) ---\n"
        r"Lobe Context: (.+?)\n"
        r"--- RELATIONAL CONTEXT ---",
        scaffold, flags=re.DOTALL
    )
    if not m:
        m2 = re.search(r"Lobe Context: (.+?)\n", scaffold)
        return m2.group(1).strip() if m2 else "?"
    return m.group(1).strip()


def extract_node_context(scaffold: str) -> str:
    """Pull the node's system_prompt from `Context: '<...>'`."""
    m = re.search(r"Context: '(.+?)'\n", scaffold)
    return m.group(1).strip() if m else "?"


def extract_winner_node(scaffold: str) -> str:
    """Winning node id is surfaced in the orchestration rule template."""
    m = re.search(r"Surface the winning node (\S+) from lobe", scaffold)
    return m.group(1) if m else "?"


def extract_threshold_note(scaffold: str) -> str:
    """v7.13: Pull the Fresh Memory `[threshold=X eligible=N]` header."""
    m = re.search(r"Fresh Memory \[threshold=([0-9.]+) eligible=(\d+)\]", scaffold)
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


def grug_headline(primary: str, node_ctx: str, winner: str, lobe_ctx: str) -> str:
    """
    GRUG v7.14: Build a one-sentence lead that frames the scaffold as
    Grug's reply. This is the "voice" line the reader sees immediately
    under **Grug:** before the full payload. It combines the primary
    action, the winning node's system_prompt (which IS the voice the
    JIT AIML pulled), and the winning lobe.
    """
    # Winning lobe: first name that appears in the lobe context strip.
    lobe_match = re.search(r"\[([a-z_]+) \(\d+/\d+ active\)\]", lobe_ctx)
    lobe_name = lobe_match.group(1) if lobe_match else "cave"
    # Trim node voice to one sentence so the headline stays scannable.
    voice = node_ctx.split(".")[0].strip() if node_ctx and node_ctx != "?" else ""
    if voice:
        return (f"_speaking as **{lobe_name}** ({winner}) — **{voice}**_ "
                f"→ primary action: **`{primary}`**")
    return f"_speaking from **{lobe_name}** ({winner})_ → primary action: **`{primary}`**"


# ---------------------------------------------------------------------------
# Main dialogue builder
# ---------------------------------------------------------------------------

def _split_reply_and_telemetry(scaf: str):
    """
    GRUG v7.15: Scaffold is `reply || --- DEBUG TELEMETRY --- || stats`.
    Return (reply_block, telemetry_block). If the separator is missing
    (truncated/malformed), return the whole scaf as reply and empty
    telemetry so we never silently drop a cycle.
    """
    sep = "--- DEBUG TELEMETRY (orchestration internals, not for speech) ---"
    if sep in scaf:
        reply_part, tele_part = scaf.split(sep, 1)
        return reply_part.rstrip(), sep + "\n" + tele_part.strip()
    return scaf.rstrip(), ""


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
        "specimen has been loaded). AIML's job is to turn raw votes "
        "into a **conversational reply** — what a downstream LLM "
        "would speak. Statistics live behind a debug-telemetry "
        "separator, out of speech. `/mission` uses standard jitter "
        "(snap-back dominant); `/brainstorm` uses heavy scoped jitter "
        "(far-jump dominant).\n\n"
    )

    # ---- Baseline diagnostics ---------------------------------------
    first_status = extract_status_block(raw, "GRUGBOT SYSTEM STATUS", which="first")
    if first_status:
        out.append("---\n\n## 🔍 Baseline diagnostics (post-load)\n\n")
        out.append("```text\n" + clean_box(first_status) + "\n```\n\n")

    # ---- The interview ----------------------------------------------
    out.append("---\n\n## 🎙️ The Interview\n\n")

    for idx, sc in enumerate(scaffolds, start=1):
        voice = sc.group(1)
        mission = sc.group(2)
        verb_phrase = sc.group(3)

        # Bound the scaffold at the next '=====' divider or next Brain >
        start = sc.start()
        end_m = re.search(r"={30,}", raw[start:start + 80000])
        reply_end_m = re.search(r"\nBrain >", raw[start:start + 80000])
        candidates = [e for e in [end_m.end() if end_m else None,
                                  reply_end_m.start() if reply_end_m else None]
                      if e is not None]
        end = start + (min(candidates) if candidates else min(50000, len(raw) - start))
        scaf = raw[start:end]

        # v7.15: split reply from telemetry
        reply_block, tele_block = _split_reply_and_telemetry(scaf)

        # Pull stats from the telemetry block (may be empty on malformed)
        tele_match = TELEMETRY_RE.search(tele_block) if tele_block else None
        if tele_match:
            primary = tele_match.group(2)
            conf    = tele_match.group(3)
            cert    = tele_match.group(4)
            sure    = tele_match.group(5) or "None"
            unsure  = tele_match.group(6) or "None"
            winner  = tele_match.group(7)
        else:
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
                same_text_before = sum(
                    1 for prev in scaffolds[:idx - 1]
                    if prev.group(2).strip() == mission.strip()
                )
                if same_text_before < len(matches_for_this):
                    kind = matches_for_this[same_text_before].group(1)

        # Trim verb_phrase to the first clause for the stats strip
        # (the full verb may include hedges like "... I'm not fully
        # locked in — analyze is also on the table"). The reply block
        # still shows the whole thing; this is just the compact tag.
        verb_short = verb_phrase.split(".")[0].split("(")[0].strip()
        if len(verb_short) > 60:
            verb_short = verb_short[:57] + "..."

        # ----------- Render the dialogue turn ---------------------
        out.append(f"### Cycle {idx} · `{kind}`\n\n")
        out.append(f"**🗣️ Interviewer:** {mission}\n\n")
        out.append(f"**🧠 Grug** _(as **{voice}**)_:\n\n")

        # Pure reply — strip the AIML scaffold header and the Voice tag
        # (we already surfaced voice in the "as X" line above).
        reply_clean = clean_box(reply_block)
        reply_clean = re.sub(r"^🤖 AIML Output Scaffold:\s*\n", "", reply_clean)
        reply_clean = re.sub(r"^\[Voice: .+?\]\s*\n", "", reply_clean)
        for line in reply_clean.split("\n"):
            out.append(f"> {line}\n" if line else ">\n")
        out.append("\n")

        # Compact stats strip under the reply.
        out.append("<sub>")
        out.append(f"verb `{verb_short}` · ")
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
    scaffold_missions = [sc.group(2).strip() for sc in scaffolds]
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
    """
    Accept either the plain or gzipped raw log. The conversation driver
    may delete the plain file after compressing it, so we auto-fall-back
    to ``<path>.gz`` when the plain file is missing.
    """
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

    # Bound the read in case the plain log ballooned past what we can
    # hold in RAM on small sandboxes. v7.12+v7.13+v7.14 make this
    # bound almost never trigger (logs shrink 70×), but the safety net
    # stays so historical runs still format.
    READ_CAP_FRONT = 32 * 1024 * 1024   # 32 MB front slice
    READ_CAP_TAIL = 4 * 1024 * 1024     # 4 MB tail slice
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