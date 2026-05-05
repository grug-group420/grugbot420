#!/bin/bash
# ============================================================================
# GRUG COMPREHENSIVE SPECIMEN BUILD DRIVER
# ============================================================================
# Strips comment/blank lines from seed_comprehensive.txt and pipes them into
# the GrugBot CLI. Produces:
#   - grugbot420_comprehensive.specimen.gz (the specimen file at repo root)
#   - specimen_demo/seed_build.log         (full CLI transcript)
#
# Usage:  ./specimen_demo/build_specimen.sh
#
# NO SILENT FAILURE: exits non-zero if CLI exits non-zero or specimen file
# is missing at end. Caller is expected to inspect seed_build.log on failure.
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

SEED="specimen_demo/seed_comprehensive.txt"
LOG="specimen_demo/seed_build.log"
SPECIMEN="grugbot420_comprehensive.specimen.gz"

if [[ ! -f "$SEED" ]]; then
    echo "FATAL: seed file missing at $SEED" >&2
    exit 2
fi

# Strip '#' comment lines and blank lines (blanks get silently ignored by
# the CLI; comments throw bad-format errors that clutter the log).
CLEANED=$(mktemp)
trap 'rm -f "$CLEANED"' EXIT
grep -v '^\s*#' "$SEED" | grep -v '^\s*$' > "$CLEANED"

echo "[BUILD] $(wc -l < "$CLEANED") live command lines" >&2
echo "[BUILD] piping into GrugBot420 CLI..." >&2

# Run and capture. The CLI ends with /quit so Julia exits 0 on success.
julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' < "$CLEANED" > "$LOG" 2>&1

if [[ ! -f "$SPECIMEN" ]]; then
    echo "FATAL: specimen file $SPECIMEN not produced; see $LOG" >&2
    exit 3
fi

SIZE=$(stat -c%s "$SPECIMEN")
echo "[BUILD] OK: $SPECIMEN ($SIZE bytes)" >&2
echo "[BUILD] log at $LOG ($(wc -l < "$LOG") lines)" >&2