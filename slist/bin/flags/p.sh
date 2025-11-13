#!/usr/bin/env bash
set -euo pipefail

# Directory where lists live
DATA_DIR="$(cd "$(dirname "$0")/../../data" && pwd)"
mkdir -p "$DATA_DIR"

# Date stamp
TODAY=$(date +%Y%m%d)
OUT="$DATA_DIR/livelist-$TODAY.txt"

# Pager: less with raw‐control and quit‐on‐intr
PAGER="less -R -K"

# Helper to fetch & page
fetch_and_page() {
  local URL="$1"
  echo "Fetching live list from $URL → $(basename "$OUT")"
  curl -s "$URL" -o "$OUT"
  $PAGER "$OUT"
}

# SEARCH mode (-s): case‐insensitive grep, with 1‑line context
if [ "${1:-}" = "-s" ]; then
  shift
  # ensure we have the live list
  if [ ! -f "$OUT" ] || (( $(date +%s) - $(stat -c %Y "$OUT") > 43200 )); then
    fetch_and_page "https://stevelist.com/list"
  fi

  read -r -p "Search for: " term
  # -i: case-insensitive, -n: line numbers, -C1: one line before/after
  grep --color=always -i -n -C1 "$term" "$OUT" | $PAGER
  exit 0
fi

# No args → use cache if <12h old, else fetch
if [ $# -eq 0 ]; then
  if [ -f "$OUT" ]; then
    age=$(( $(date +%s) - $(stat -c %Y "$OUT") ))
    if (( age < 43200 )); then
      hours=$(awk "BEGIN{printf \"%.1f\", $age/3600}")
      echo "Using cached live list ($(basename "$OUT")), pulled $hours h ago"
      $PAGER "$OUT"
      exit 0
    fi
  fi
  fetch_and_page "https://stevelist.com/list"
  exit 0
fi

# URL arg → always fetch & page
if [[ "$1" =~ ^https?:// ]]; then
  fetch_and_page "$1"
  exit 0
fi

# File arg → page the file
if [ -f "$1" ]; then
  echo "Hint: you can also use the -mylist flag to view your local list"
  $PAGER "$1"
  exit 0
fi

# Otherwise, show usage
cat <<EOF
Usage:
  $0            # fetch & page today’s live list (12 h cache)
  $0 -s         # search (case‑insensitive, ±1 line context) in today’s list
  $0 <URL>      # fetch & page that URL
  $0 <file>     # page a local file
EOF
exit 1

