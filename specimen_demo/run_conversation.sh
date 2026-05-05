#!/bin/bash
# ============================================================================
# GRUG COMPREHENSIVE SPECIMEN CONVERSATION DRIVER
# ============================================================================
# Loads the specimen and runs the scripted conversation through the CLI.
# Produces (in order):
#   1. specimen_demo/conversation_raw.log    — full CLI transcript
#   2. specimen_demo/conversation_raw.log.gz — compressed copy (plain is
#      deleted afterwards because a 13-mission run can balloon to ~1 GB
#      thanks to O(N^2) mission-memory recursion)
#   3. specimen_demo/conversation.md         — human-readable markdown
#
# NO SILENT FAILURES: exits non-zero on missing specimen, non-zero CLI exit,
# formatter failure, or gzip failure.
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

SCRIPT="specimen_demo/conversation.txt"
RAW="specimen_demo/conversation_raw.log"
SPECIMEN="grugbot420_comprehensive.specimen.gz"
FMT="specimen_demo/format_conversation.py"
MD="specimen_demo/conversation.md"

if [[ ! -f "$SPECIMEN" ]]; then
    echo "FATAL: specimen $SPECIMEN missing. Run build_specimen.sh first." >&2
    exit 2
fi
if [[ ! -f "$SCRIPT" ]]; then
    echo "FATAL: conversation script $SCRIPT missing." >&2
    exit 2
fi

# Strip comment and blank lines (the CLI regex dispatcher would reject
# them as "command bad format" and pollute the log with SYSTEM ERROR
# banners). The cleaned file is a throwaway tempfile.
CLEANED=$(mktemp)
trap 'rm -f "$CLEANED"' EXIT
grep -v '^\s*#' "$SCRIPT" | grep -v '^\s*$' > "$CLEANED"

echo "[CONV] $(wc -l < "$CLEANED") live commands" >&2
echo "[CONV] running against $SPECIMEN..." >&2

julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' \
    < "$CLEANED" > "$RAW" 2>&1

echo "[CONV] OK: raw transcript at $RAW ($(wc -l < "$RAW") lines)" >&2

# GRUG: Raw log grows O(N^2) because each /mission output is stored as
# a system message and the next /mission re-embeds the last 5 system
# messages verbatim in its generated payload. A 13-mission run can
# balloon past 1 GB uncompressed, which is terrible for git check-in.
# Gzip the raw log (typically 10-20 MB compressed), then discard the
# plain file to save disk. The formatter transparently reads either
# form so downstream tooling does not care which one is on disk.
if [[ ! -f "$RAW" ]]; then
    echo "FATAL: CLI produced no raw log at $RAW" >&2
    exit 3
fi

RAW_SIZE=$(stat -c%s "$RAW")
gzip -f "$RAW"
GZ="${RAW}.gz"
if [[ ! -f "$GZ" ]]; then
    echo "FATAL: gzip did not produce $GZ" >&2
    exit 3
fi
GZ_SIZE=$(stat -c%s "$GZ")
echo "[CONV] gzipped raw log: $GZ ($GZ_SIZE bytes, from $RAW_SIZE uncompressed)" >&2

# GRUG: Run the formatter to produce a human-readable markdown
# transcript alongside the (gzipped) raw log. Formatter extracts
# primary action, confidence, vote certainty, winning node, lobe
# context, and node system_prompt per cycle plus baseline/final
# /status snapshots. We hand it $RAW (the plain path) and let the
# formatter's fallback logic resolve to the .gz if the plain file
# has already been deleted by gzip.
if [[ -x "$FMT" ]]; then
    if python3 "$FMT" "$RAW" "$MD"; then
        echo "[CONV] formatted markdown at $MD ($(stat -c%s "$MD") bytes)" >&2
    else
        echo "FATAL: formatter failed" >&2
        exit 4
    fi
else
    echo "WARN: formatter $FMT not executable; skipping markdown build" >&2
fi