#!/usr/bin/env bash
# g.sh — Music Show Manager
# - Robust submit keys: Enter (CR/LF/CRLF), Ctrl-J, Ctrl-M, Ctrl-D, and TAB
# - Live abbrev search on trailing `!abbr?`
# - Venue add supports attrs/children XML; prompts for color
# - Final prompt: "Does this need review?" → save to needs_review.txt or mylist.txt
# - Price flags: 's' => sliding scale, 'd' => donation (stackable)

set -euo pipefail

# ---------------------------
# Paths & dependencies
# ---------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PY_DIR="$BIN_DIR/python"
DATA_DIR="$(cd "$BIN_DIR/../data" && pwd)"

VENUES_XML="$DATA_DIR/venues.xml"
BANDS_DB="$DATA_DIR/bands.json"
MYLIST="$DATA_DIR/mylist.txt"
NEEDS_REVIEW="$DATA_DIR/needs_review.txt"

PY_PARSER="${PY_DIR}/parser.py"      # optional; safe fallback if missing
PY_SMARTTIME="${PY_DIR}/smarttime.py"
PY_BANDS="${PY_DIR}/bands_abbrev.py"     # required for abbrev search/expand

mkdir -p "$DATA_DIR"
[[ -f "$VENUES_XML" ]] || { echo "ERROR: Missing $VENUES_XML"; exit 1; }
command -v xmlstarlet >/dev/null 2>&1 || { echo "ERROR: xmlstarlet is required."; exit 1; }
[[ -f "$BANDS_DB" ]] || echo '{}' > "$BANDS_DB"

# ---------------------------
# ANSI colors + helpers
# ---------------------------
declare -A COLORS=(
  [black]=$'\033[30m' [red]=$'\033[31m' [green]=$'\033[32m' [yellow]=$'\033[33m'
  [blue]=$'\033[34m'  [magenta]=$'\033[35m' [cyan]=$'\033[36m' [white]=$'\033[37m'
  [reset]=$'\033[0m'  [rev]=$'\033[7m'
)
strip_ansi() { sed -r 's/\x1B\[[0-9;]*[mK]//g'; }

# ---------------------------
# Venue prompt (supports both XML shapes)
#   A) <venue id=".." pn=".." ln=".." color=".."/>
#   B) <venue id=".."><pn>..</pn><ln>..</ln><color>..</color></venue>
# ---------------------------
prompt_venue() {
  echo
  echo "Select a venue by number (0=custom):"

  # ANSI color codes
  declare -A COLORS=(
    [black]=$'\033[0m'   [red]=$'\033[31m'
    [green]=$'\033[32m'   [yellow]=$'\033[33m'
    [blue]=$'\033[34m'    [magenta]=$'\033[35m'
    [cyan]=$'\033[36m'    [white]=$'\033[37m'
    [reset]=$'\033[0m'
  )

  # 1) Load raw "ID: pn|color"
  mapfile -t raw < <(
    xmlstarlet sel -t -m "//venue" \
      -v "concat(@id,': ',pn,'|',color)" -n \
      ../../data/venues.xml
  )

  # 2) Wrap each in its ANSI color
  local items=()
  for entry in "${raw[@]}"; do
    IFS='|' read -r lbl col <<<"$entry"
    col="${col,,}"
    local code="${COLORS[reset]}"
    [[ -n "$col" && -n "${COLORS[$col]+_}" ]] && code="${COLORS[$col]}"
    items+=( "${code}${lbl}${COLORS[reset]}" )
  done

  # 3) Find the display‐length of the longest label (strip ANSI)
  local maxlen=0 clean
  for it in "${items[@]}"; do
    clean="$(echo -e "$it" | sed -r 's/\x1B\[[0-9;]*[mK]//g')"
    (( ${#clean} > maxlen )) && maxlen=${#clean}
  done

  # 4) Compute padding = at least 4, or 25% of maxlen, whichever is larger
  local pad_default=15
  local pad_dynamic=$(( maxlen / 15 ))
  local pad=$(( pad_dynamic > pad_default ? pad_dynamic : pad_default ))

  # 5) Build uniform column width
  local colw=$(( maxlen + pad ))
  local termw=$(tput cols)
  local cols=$(( termw / colw )); (( cols<1 )) && cols=1

  # 6) Compute rows for column-major fill
  local count=${#items[@]}
  local rows=$(( (count + cols - 1) / cols ))

  # 7) Print in column-major order using that single colw
  for (( r=0; r<rows; r++ )); do
    for (( c=0; c<cols; c++ )); do
      idx=$(( c*rows + r ))
      if (( idx < count )); then
        printf "%-${colw}s" "${items[idx]}"
      fi
    done
    echo
  done

    # Read selection
    read -r -p "Enter venue number: " venue_id
    if [[ "$venue_id" == "0" ]]; then
      read -r -p "Enter full venue name: " selected_venue
  read -r -p "Save this venue for future? (y/N): " save_choice
  if [[ "$save_choice" =~ ^[Yy]$ ]]; then
    read -r -p "Enter short name (default=full): " short_name
    short_name="${short_name:-$selected_venue}"
    # Call the Python helper
    ../python/add_venue.py "$selected_venue" "$short_name"
    bash ./colorupdate.sh
  fi
  else
        selected_venue=$(xmlstarlet sel \
          -t -v "//venue[@id='$venue_id']/ln" \
          ../../data/venues.xml)
    fi
} 

# ---------------------------
# Date prompt (uses parser.py if present)
# ---------------------------
prompt_date() {
  local date_in formatted_date
  read -r -p "Enter date (MM/DD): " date_in
  if [[ -f "$PY_PARSER" ]]; then
    formatted_date="$(python3 "$PY_PARSER" date "$date_in" 2>/dev/null || true)"
  fi
  [[ -z "${formatted_date:-}" ]] && formatted_date="$date_in"
  echo "Date: $formatted_date"
  FORMATTED_DATE="$formatted_date"; export FORMATTED_DATE
}

# ---------------------------
# Robust single-char reader with live search
# Submit on: CR, LF, CRLF, Ctrl-M, Ctrl-J, Ctrl-D, or TAB
# Live search when buffer ends with `!abbr?`
# ---------------------------
# ---------------------------
# Robust single-char reader with live search
# Submit on: Enter (CR/LF/CRLF, Ctrl-M/J), TAB, Ctrl-D, and keypad-Enter escapes.
# Live search when buffer ends with `!abbr?`
# ---------------------------
# Cooked-mode bands prompt with inline "!abbr?" search.
# Behavior:
#   - Type normally; press Enter to submit.
#   - If the line ends with "!<abbr>?" when you press Enter:
#       • show search results,
#       • strip the trailing '?',
#       • re-prompt with the edited line pre-filled (so you keep typing),
#     Enter again (without '?') will submit and expand.
bands_prompt_cooked() {
  local buf="" line prefix expanded

  while :; do
    if [[ -n "$buf" ]]; then
      # prefill with previous line (without the '?')
      read -e -r -p "Enter bands: " -i "$buf" line
    else
      read -e -r -p "Enter bands: " line
    fi

    # If user ended with !abbr? → do lookup, then loop and re-prompt
    if [[ "$line" =~ \!([[:alnum:]]+)\?$ ]]; then
      prefix="${BASH_REMATCH[1]}"
      echo "Abbreviation Search: $prefix"
      if ! python3 "$PY_BANDS" --db "$BANDS_DB" search "$prefix"; then
        echo "(lookup error)"
      fi
      # Remove the trailing '?' so they can keep typing with the result in mind
      buf="${line%?}"
      continue
    fi

    # Final submission path: expand abbreviations (keep your DB learning)
    expanded=""
    if [[ -f "$PY_BANDS" ]]; then
      expanded="$(python3 "$PY_BANDS" --db "$BANDS_DB" expand --input-text "$line" --auto-add 2>/dev/null || true)"
    fi
    [[ -z "$expanded" ]] && expanded="$line"

    BANDS_LINE="$expanded"
    export BANDS_LINE
    break
  done
}

prompt_bands() {
  bands_prompt_cooked
}
prompt_price() {
  read -r -p "Enter price (e.g., 5 | 10/15 | 10-15 | add 's' for Sliding Scale, 'd' for donation; stack like '10-15 s d'): " price_input
  formatted_price="$(format_price "$price_input")"
  echo "Formatted price: $formatted_price"
}
format_price() {
  local input="${1-}"

  # Normalize spaces to single spaces
  local normalized
  normalized="$(printf '%s' "$input" | tr '[:space:]' ' ' | sed 's/ \+/ /g' | sed 's/^ //; s/ $//')"

  # Make an array safely even if empty
  local -a words=()
  if [[ -n "$normalized" ]]; then
    # shellcheck disable=SC2206  # intentional word splitting on spaces
    words=($normalized)
  fi

  local sliding=false donation=false
  local -a parts=()
  local saw_nonzero_num=false
  local saw_zero_num=false

  # helper to add $ before each number in "A-B" or "A/B"
  _dollarize() {
    local tok="$1" sep n1 n2
    if [[ "$tok" == *"/"* ]]; then sep="/"; else sep="-"; fi
    IFS="$sep" read -r n1 n2 <<<"$tok"
    if [[ -n "$n2" ]]; then
      printf "\$%s%s\$%s" "$n1" "$sep" "$n2"
    else
      printf "\$%s" "$n1"
    fi
  }

  local w
  for w in "${words[@]:-}"; do
    [[ -z "$w" ]] && continue
    case "${w,,}" in
      s) sliding=true ;;
      d) donation=true ;;
      0) saw_zero_num=true ;;
      # numeric tokens: N | N-N | N/N
      ''|*[!0-9/-]*)
         # ignore non-price junk in the price field
         ;;
      *)
         if [[ "$w" =~ ^[0-9]+$ ]]; then
           if [[ "$w" != "0" ]]; then
             parts+=("\$${w}")
             saw_nonzero_num=true
           else
             saw_zero_num=true
           fi
         elif [[ "$w" =~ ^[0-9]+-[0-9]+$ || "$w" =~ ^[0-9]+/[0-9]+$ ]]; then
           parts+=("$(_dollarize "$w")")
           saw_nonzero_num=true
         fi
         ;;
    esac
  done

  local out=""
  if $saw_nonzero_num; then
    out="$(IFS=' '; echo "${parts[*]}")"
    $sliding && out+=" Sliding Scale"
    $donation && out+=" donation"
  else
    # No non-zero numbers present
    if $donation && ! $sliding && ! $saw_zero_num; then
      out="donation"
    elif $sliding && ! $donation && ! $saw_zero_num; then
      out="Sliding Scale"
    elif $saw_zero_num && ! $donation && ! $sliding; then
      out="free"
    elif $saw_zero_num && $donation && ! $sliding; then
      out="donation"
    elif $saw_zero_num && $sliding && ! $donation; then
      out="Sliding Scale"
    elif $saw_zero_num && $sliding && $donation; then
      out="Sliding Scale donation"
    else
      out=""  # user left it blank; caller can decide how to display
    fi
  fi

  printf '%s\n' "$out"
}

# ---------------------------
# Time
# ---------------------------
prompt_time() {
    read -r -p "Enter time (e.g. 7, 73->7:30, 7/73, 11a/1230 PM is Default): " time_input
    formatted_time=$(
        python3 "$PY_SMARTTIME" "$time_input"
    )
    echo "Time: $formatted_time"
}

# ---------------------------
# Additional info (via parser.py if available)
# ---------------------------
prompt_additional_info() {
  local info_in info_fmt
  echo "Additional info quick keys: * \$ @ ^ # m nf    (type any mix or free text)"
  read -e -r -p "Enter additional info: " info_in || info_in=""
  if [[ -f "$PY_PARSER" ]]; then
    info_fmt="$(python3 "$PY_PARSER" info $info_in 2>/dev/null || true)"
  fi
  ADDL_INFO="${info_fmt:-$info_in}"; export ADDL_INFO
}

# ---------------------------
# Confirm & save — REVIEW FIRST
# ---------------------------
confirm_event() {
  local venue date bands age price time info

  if (( $# == 7 )); then
    # OLD style: positional args
    venue="$1"; date="$2"; bands="$3"; age="$4"; price="$5"; time="$6"; info="$7"
  else
    # NEW style: pull from vars (with fallbacks to old names)
    venue="${VENUE:-${selected_venue:-}}"
    date="${DATE:-${FORMATTED_DATE:-}}"
    bands="${BANDS:-${BANDS_LINE:-}}"
    age="${AGE:-${age_output:-}}"
    price="${PRICE:-${formatted_price:-}}"
    time="${TIME:-${formatted_time:-}}"
    info="${ADDL_INFO:-${formatted_additional_info:-}}"
  fi

  local INDENT=$'       '
  local event_line
  event_line="$(printf "%s %s\n%sat %s %s %s %s %s" \
                "$date" "$bands" "$INDENT" "$venue" "$age" "$price" "$time" "$info")"

  echo ""
  echo "----------------------"
  echo "Formatted Event:"
  printf "%b\n" "$event_line"
  echo "----------------------"
  echo ""

  local need_review=""
  read -r -p "Does this need review? (y/N): " need_review || need_review=""
  if [[ "${need_review,,}" == "y" ]]; then
    printf "%b\n" "$event_line" >> "$NEEDS_REVIEW"
    echo "Saved to $(basename "$NEEDS_REVIEW")."
  else
    printf "%b\n" "$event_line" >> "$MYLIST"
    echo "Saved to $(basename "$MYLIST")."
  fi
}


# ---------------------------
# Age (unchanged)
# ---------------------------
prompt_age() {
  local age digits
  read -r -p "Enter age (blank→a/a, 1→18+, 2→21+, or custom age number): " age || age=""
  if   [[ -z "$age" ]]; then AGE="a/a"
  elif [[ "$age" == "1" ]]; then AGE="18+"
  elif [[ "$age" == "2" ]]; then AGE="21+"
  else digits="${age//[^0-9]/}"; AGE="${digits:+${digits}+}"; [[ -z "$AGE" ]] && AGE="a/a"
  fi
  export AGE
}

# ---------------------------
# Main loop
# ---------------------------
while true; do
  prompt_venue
  prompt_date
  prompt_bands
  prompt_age
  prompt_price
  prompt_time
  prompt_additional_info
  confirm_event
  echo "─── press Ctrl+C to exit, or continue entering events (TAB or Enter submits bands) ───"
  echo
done

