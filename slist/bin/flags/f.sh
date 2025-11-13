#!/usr/bin/env bash
set -euo pipefail

# Input file (default)
INPUT="${1:-./../../data/mylist.txt}"

# Temp files
TMP=$(mktemp)
SORTED=$(mktemp)

# Month → MM map
declare -A MONTH_MAP=(
  [jan]=01 [feb]=02 [mar]=03 [apr]=04 [may]=05 [jun]=06
  [jul]=07 [aug]=08 [sep]=09 [oct]=10 [nov]=11 [dec]=12
)

# 1) Read two-line records, write KEY|LINE1<US>LINE2
while IFS= read -r line1; do
  [[ -z "$line1" ]] && continue
  IFS= read -r line2 || line2=""
  month_abbr=$(awk '{print $1}' <<<"$line1")
  day_field=$(awk '{print $2}' <<<"$line1" | sed 's/^ *//')
  month_num="${MONTH_MAP[$month_abbr]}"
  day_num=$(printf "%02d" "$day_field")
  printf "%s|%s\x1F%s\n" "$month_num$day_num" "$line1" "$line2" >> "$TMP"
done < "$INPUT"

# 2) Sort numerically on the KEY
sort -n -t'|' -k1,1 "$TMP" > "$SORTED"

# 3) Rewrite original, splitting on the unit separator
: > "$INPUT"
while IFS= read -r rec; do
  # drop the key|
  rest=${rec#*|}
  IFS=$'\x1F' read -r line1 line2 <<< "$rest"
  echo "$line1" >> "$INPUT"
  echo "$line2" >> "$INPUT"
done < "$SORTED"

# clean up
rm "$TMP" "$SORTED"

echo "✓ Sorted listings in $INPUT"
