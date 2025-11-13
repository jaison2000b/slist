#!/usr/bin/env bash
set -euo pipefail

PY_SCRIPT="$(dirname "$0")/../python/color_update.py"

if [[ $# -eq 0 ]]; then
  python3 "$PY_SCRIPT"
elif [[ $# -eq 1 ]]; then
  python3 "$PY_SCRIPT" "$1"
else
  echo "Usage: $0 [\"Full Venue Name\"]" >&2
  exit 1
fi

