#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PY="$BIN_DIR/python/bands_abbrev.py"

DB="$(cd "$BIN_DIR/.." && pwd)/data/bands.json"

if [[ ! -f "$PY" ]]; then
  echo "bands_abbrev.py not found at $PY" >&2
  exit 1
fi

read -r -p "Full band name: " NAME
read -r -p "Abbreviation (letters/numbers, e.g. gd): " ABBR

if [[ -z "${NAME// }" || -z "${ABBR// }" ]]; then
  echo "Both fields are required." >&2
  exit 1
fi

# Try to add; if conflict, offer overwrite
if ! "$PY" add --db "$DB" --name "$NAME" --abbr "$ABBR"; then
  read -r -p "Abbreviation exists for a different band. Overwrite? (y/N): " yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    "$PY" add --db "$DB" --name "$NAME" --abbr "$ABBR" --force
  else
    echo "No changes made."
  fi
fi

