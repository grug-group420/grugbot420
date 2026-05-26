#!/usr/bin/env bash
# build_default_specimen.sh
# Builds the canonical grug-binary/default.specimen.gz from
# scripts/default_specimen_seed.txt. Run from repo root.

set -euo pipefail

cd "$(dirname "$0")/.."

SEED_FILE="scripts/default_specimen_seed.txt"
OUT_FILE="grug-binary/default.specimen.gz"

if [[ ! -f "$SEED_FILE" ]]; then
    echo "ERROR: seed file not found: $SEED_FILE" >&2
    exit 1
fi

echo "==============================================================="
echo "Building $OUT_FILE from $SEED_FILE"
echo "==============================================================="

# Strip comments and blank lines, pipe to Main.jl
grep -v '^\s*#' "$SEED_FILE" | grep -v '^\s*$' | \
    julia --project=. src/Main.jl

if [[ -f "$OUT_FILE" ]]; then
    echo
    echo "✅ Built $OUT_FILE ($(du -h "$OUT_FILE" | cut -f1))"
else
    echo "❌ Failed: $OUT_FILE not produced" >&2
    exit 1
fi
