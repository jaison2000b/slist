#!/usr/bin/env bash
# main.sh — Music Show Manager multi-flag runner
set -euo pipefail

# --- Resolve paths whether main.sh is in repo root or repo/bin ---
HERE="$(cd "$(dirname "$0")" && pwd)"
if [[ -d "$HERE/flags" ]]; then
  REPO_ROOT="$(cd "$HERE/.." && pwd)"
  FLAGS_DIR="$HERE/flags"
else
  REPO_ROOT="$HERE"
  FLAGS_DIR="$REPO_ROOT/bin/flags"
fi

# --- Pretty help formatting helpers -----------------------------------------
_wrap() {
  # _wrap "<text>" <indent_columns>  -> wraps to terminal width, soft breaks
  local text="$1" indent="${2:-0}"
  local width; width="$(tput cols 2>/dev/null || echo 80)"
  local eff=$(( width - indent ))
  (( eff < 20 )) && eff=20   # never wrap narrower than 20 cols
  echo "$text" | fold -s -w "$eff" | sed "2,\$s/^/$(printf '%*s' "$indent")/"
}

_print_flag() {
  # _print_flag "<flag tokens>" "<description>"
  local flag="$1" desc="$2"
  local flag_col=14                    # width reserved for the flag column
  local indent=$(( flag_col + 2 ))     # indent for wrapped description lines
  printf "  %-*s" "$flag_col" "$flag"
  _wrap "$desc" "$indent"
}

usage() {
  cat <<EOF
Steve List — SF Bay Area Show List Ops
Points to flag scripts in: slist/bin/flags/

Usage:
  $(basename "$0") <flag> [args...] [<flag> [args...]] ...

Examples:
  $(basename "$0") -p -s
  $(basename "$0") p s
  $(basename "$0") -p out.txt -s "mug"

Flags:
EOF

  _print_flag "-g | g" \
    "Interactive generator. Follows prompts and saves to mylist.txt or needs_review.txt, respectively."

  _print_flag "-f | f" \
    "Format/sort (mylist.txt by default) or point it at another file (e.g., todays-list.txt)."

  _print_flag "-p | p" \
    "Fetches and prints the current list from stevelist.com/list (unless otherwise specified). Commonly chained with -s (e.g., 'p s') to search after printing."

  _print_flag "-s | s" \
    "Search utilities for your lists."

  _print_flag "-wo | wo" \
    "“Write-out” helper. When you’re ready to send a final output to Steve, this runs format, duplicate checks, and optionally resolves/merges needs_review.txt, then merges with mylist.txt and prints/saves to {date}list.txt in slist/data/."

  _print_flag "-co | co" \
    "Color update for venues. Pulls color sets by micro-region (SF, South Bay, East Bay) and assigns venue colors used in the generator menu. Automatically run when adding a venue from the g prompt."

  _print_flag "-av | av" \
    "Add a venue. (You can also add from the g prompt by choosing option 0.)"

  _print_flag "-abrv | abrv" \
    "Add band abbreviations for the g prompt. You can also learn pairs inline by typing 'Band Name^abbr' while prompting."

  _print_flag "-h | --help" \
    "Show this help."

  cat <<'EOF'

Notes:
  • Each script runs with CWD=bin/flags so ./../python and ../../data paths work as-is.
EOF
}


normalize_flag() {
  local f="${1:-}"; f="${f#-}"; f="${f#-}"
  case "$f" in
    g) echo "g.sh" ;;
    f) echo "f.sh" ;;
    p) echo "p.sh" ;;
    s) echo "s.sh" ;;
    wo) echo "wo.sh" ;;
    co) echo "colorupdate.sh" ;;
    av) echo "addvenue.sh" ;;
    abrv) echo "addbandabbrv.sh" ;;
    h|help|usage|"") echo "" ;;
    *) echo "UNKNOWN" ;;
  esac
}

# show help if requested / no args
if [[ $# -eq 0 ]]; then usage; exit 0; fi
for tok in "$@"; do case "$tok" in -h|--help|h|help) usage; exit 0 ;; esac; done

# parse argv into a queue of commands (script + its args)
declare -a CURRENT_ARGS=()
CURRENT_SCRIPT=""
declare -a QUEUE=()
SEP_ITEM=$'\x1f'

flush_current() {
  if [[ -n "${CURRENT_SCRIPT:-}" ]]; then
    local item="$CURRENT_SCRIPT"
    if ((${#CURRENT_ARGS[@]} > 0)); then
      local a; for a in "${CURRENT_ARGS[@]}"; do item+="${SEP_ITEM}${a}"; done
    fi
    QUEUE+=("$item")
    CURRENT_SCRIPT=""
    CURRENT_ARGS=()
  fi
}

while (( $# )); do
  tok="$1"; shift
  script_basename="$(normalize_flag "$tok")"
  if [[ "$script_basename" == "UNKNOWN" ]]; then
    if [[ -z "${CURRENT_SCRIPT:-}" ]]; then
      echo "Error: argument '$tok' appears before any flag." >&2
      usage; exit 1
    fi
    CURRENT_ARGS+=("$tok")
  elif [[ -z "$script_basename" ]]; then
    usage; exit 0
  else
    flush_current
    script_path="$FLAGS_DIR/$script_basename"
    [[ -f "$script_path" ]] || { echo "Error: not found: $script_path" >&2; exit 1; }
    chmod +x "$script_path" 2>/dev/null || true
    CURRENT_SCRIPT="$script_path"
  fi
done
flush_current

# run each queued command from bin/flags
export MSM_REPO_ROOT="$REPO_ROOT"
export MSM_FLAGS_DIR="$FLAGS_DIR"
cd "$FLAGS_DIR"

for cmd in "${QUEUE[@]}"; do
  IFS="$SEP_ITEM" read -r -a parts <<<"$cmd"
  script="${parts[0]}"
  declare -a args=()
  if ((${#parts[@]} > 1)); then
    args=("${parts[@]:1}")
  fi
  if ((${#args[@]} > 0)); then
    echo "→ Running $(basename "$script") -- ${args[*]}"
    "./$(basename "$script")" "${args[@]}"
  else
    echo "→ Running $(basename "$script")"
    "./$(basename "$script")"
  fi
done

