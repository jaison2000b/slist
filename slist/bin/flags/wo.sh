#!/usr/bin/env bash
set -euo pipefail

# --- Paths ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJ_ROOT="$(cd "$BIN_DIR/.." && pwd)"
DATA_DIR="$PROJ_ROOT/data"
PY_DIR="$BIN_DIR/python"
FLAGS_DIR="$BIN_DIR/flags"

NEEDS="$DATA_DIR/needs_review.txt"
MYLIST="$DATA_DIR/mylist.txt"
VENUES_XML="$DATA_DIR/venues.xml"

FILTER_PY="$PY_DIR/filter_future_only.py"
DUPES_PY="$PY_DIR/duplicates.py"
FORMAT_SH="$FLAGS_DIR/f.sh"

LIVE_BASENAME_PREFIX="livelist"
LIVE_MAX_AGE_SECS=$((12*60*60))   # 12h cache window

# Desired indentation for second line:
INDENT="       "  # 7 spaces

echo "=== Starting write-out process ==="

touch "$MYLIST" "$NEEDS"

# readline helper (stdin = your terminal)
rl_read() {
  local __var="$1"; shift
  local __prompt="${1-}"; shift || true
  local __default="${1-}"
  if [[ -n "$__default" ]]; then
    # shellcheck disable=SC2229
    read -r -e -p "$__prompt" -i "$__default" "$__var"
  else
    # shellcheck disable=SC2229
    read -r -e -p "$__prompt" "$__var"
  fi
}

# normalize second line indentation on edited entries
normalize_l2() {
  # usage: normalize_l2 "<raw second line>"
  # strips leading whitespace then re-prefixes with INDENT (7 spaces)
  local raw="${1-}"
  # keep full text but remove leading spaces/tabs
  local trimmed="${raw#"${raw%%[![:space:]]*}"}"
  printf '%s%s\n' "$INDENT" "$trimmed"
}

get_live_cache() {
  local newest=""
  newest="$(ls -1t "$DATA_DIR"/${LIVE_BASENAME_PREFIX}-*.txt 2>/dev/null | head -n1 || true)"
  if [[ -n "$newest" ]]; then
    local now epoch age
    now=$(date +%s)
    epoch=$(date +%s -r "$newest")
    age=$(( now - epoch ))
    if (( age < LIVE_MAX_AGE_SECS )); then
      printf '%s\n' "$newest"
      return 0
    fi
  fi
  local ts out
  ts="$(date +%Y%m%d%H%M)"
  out="$DATA_DIR/${LIVE_BASENAME_PREFIX}-${ts}.txt"
  if command -v curl >/dev/null 2>&1; then
    curl -sS -L "https://stevelist.com/list" -o "$out" || out=""
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$out" "https://stevelist.com/list" || out=""
  else
    out=""
  fi
  printf '%s\n' "$out"
}

# 1) Filter past shows from both files
echo "Filtering out past-dated listings..."
TMP1="$(mktemp)"; TMP2="$(mktemp)"
python3 "$FILTER_PY" "$NEEDS"  > "$TMP1" || true
python3 "$FILTER_PY" "$MYLIST" > "$TMP2" || true
mv "$TMP1" "$NEEDS"
mv "$TMP2" "$MYLIST"

# 2) Interactive review (keep/edit/drop); ensure edited L2 is re-indented
if [[ -s "$NEEDS" ]]; then
  echo "Processing items in needs_review.txt ..."
  TMP_OUT="$(mktemp)"

  exec 4<"$NEEDS"
  while true; do
    IFS= read -r -u 4 L1 || break
    IFS= read -r -u 4 L2 || L2=""

    echo
    echo "----- Listing -----"
    printf "%s\n%s\n" "$L1" "$L2"
    echo "-------------------"
    echo "Action: [K]eep (default) / [E]dit / [D]rop"
    CHOICE=""
    read -r -p "Choose (K/e/d): " CHOICE
    CHOICE="${CHOICE:-K}"

    case "${CHOICE,,}" in
      k)
        # keep as-is (don’t touch whitespace)
        printf "%s\n%s\n" "$L1" "$L2" >> "$TMP_OUT"
        ;;
      e)
        NEW1=""; NEW2=""
        rl_read NEW1 "Edit line 1: " "$L1"
        rl_read NEW2 "Edit line 2: " "$L2"
        # force the indentation on line 2
        NEW2="$(normalize_l2 "$NEW2")"
        printf "%s\n%s\n" "$NEW1" "$NEW2" >> "$TMP_OUT"
        ;;
      d)
        echo "Dropped."
        ;;
      *)
        printf "%s\n%s\n" "$L1" "$L2" >> "$TMP_OUT"
        ;;
    esac
  done
  exec 4<&-

  : > "$NEEDS"
  cat "$TMP_OUT" >> "$MYLIST"
  rm -f "$TMP_OUT"
else
  echo "No items in needs_review.txt."
fi

# 2.5) Remove exact duplicate 2-line blocks inside MYLIST (post-merge)
if [[ -s "$MYLIST" ]]; then
  TMPU="$(mktemp)"
  awk '
    { if (!hold) hold=$0; else { block=hold ORS $0; if (!seen[block]++) print hold RS $0; hold="" } }
    END { if (hold!="") print hold }' "$MYLIST" > "$TMPU"
  mv "$TMPU" "$MYLIST"
fi

# 3) Duplicate check against live list (uses merged mylist)
if [[ -s "$MYLIST" ]]; then
  echo "Running duplicate check..."
  LIVE_CACHE="$(get_live_cache || true)"
  if [[ -z "${LIVE_CACHE:-}" || ! -s "$LIVE_CACHE" ]]; then
    echo "Warning: live list cache missing; skipping duplicate pass." >&2
  else
    python3 "$DUPES_PY" \
      --mylist "$MYLIST" \
      --live-cache "$LIVE_CACHE" \
      --venues "$VENUES_XML"
  fi
else
  echo "mylist.txt is empty; skipping duplicate pass."
fi

# 4) Sort final list
echo "Sorting mylist.txt ..."
bash "$FORMAT_SH"

# 5) Archive to mylist-YYYYMMDD.txt and keep last 5
STAMP="$(date +%Y%m%d)"
ARCHIVE="$DATA_DIR/mylist-$STAMP.txt"
cp "$MYLIST" "$ARCHIVE"
echo "Archived to $(basename "$ARCHIVE")"

ARCHIVES=( $(ls -1t "$DATA_DIR"/mylist-*.txt 2>/dev/null || true) )
if (( ${#ARCHIVES[@]} > 5 )); then
  to_delete=( "${ARCHIVES[@]:5}" )
  for f in "${to_delete[@]}"; do rm -f "$f" || true; done
fi

# 6) Page the final list
echo
echo "===== FINAL SHOW LIST ====="
if command -v less >/dev/null 2>&1; then
  less -R -F -S -X -M "$ARCHIVE"
else
  cat "$ARCHIVE"
fi
echo "==========================="

