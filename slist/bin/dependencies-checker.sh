#!/usr/bin/env bash
set -euo pipefail

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "✗ missing: $1"; return 1; }; echo "✓ $1 found"; }

ver_ge() {  # ver_ge 1.2.3 1.2.0  -> true if 1st >= 2nd
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

check_ver() {  # check_ver cmd "arg to show version" MINVER PARSE_REGEX
  local cmd="$1" arg="$2" min="$3" re="$4" out ver
  out="$("$cmd" $arg 2>&1 || true)"
  if [[ "$out" =~ $re ]]; then
    ver="${BASH_REMATCH[1]}"
    if ver_ge "$ver" "$min"; then
      printf "✓ %-12s %s (>= %s)\n" "$cmd" "$ver" "$min"
    else
      printf "‼ %-12s %s (need >= %s)\n" "$cmd" "$ver" "$min"
      return 1
    fi
  else
    printf "‼ %-12s could not parse version\n" "$cmd"
    printf "   output: %s\n" "$out"
    return 1
  fi
}

echo "== Music Show Manager — dependency check =="

ok=0

# Presence checks
need_cmd bash        || ok=1
need_cmd python3     || ok=1
need_cmd xmlstarlet  || ok=1
need_cmd sed         || ok=1
need_cmd awk         || ok=1
need_cmd grep        || ok=1
need_cmd stty        || ok=1
need_cmd tput        || ok=1
need_cmd curl        || ok=1

echo

# Version checks (best-effort; some distros brand versions differently)
check_ver bash       "--version"          "4.3"   'GNU bash, version ([0-9]+\.[0-9]+(\.[0-9]+)?)' || ok=1
check_ver python3    "--version"          "3.5"   'Python ([0-9]+\.[0-9]+(\.[0-9]+)?)'           || ok=1
check_ver xmlstarlet "--version"          "1.6.1" 'XMLStarlet Toolkit: ([0-9]+\.[0-9]+(\.[0-9]+)?)' || ok=1
check_ver sed        "--version"          "4.2"   'sed \(GNU sed\) ([0-9]+\.[0-9]+(\.[0-9]+)?)'   || ok=1
# awk can be mawk or gawk; just report what we see
awk -W version >/dev/null 2>&1 && awkver=$(awk -W version 2>&1 | head -n1) || awkver=$(awk -V 2>&1 | head -n1)
echo "✓ awk        ${awkver:-unknown}"
check_ver grep       "--version"          "2.20"  'grep \(GNU grep\) ([0-9]+\.[0-9]+(\.[0-9]+)?)' || ok=1
check_ver tput       "-V"                 "5.9"   'ncurses.* ([0-9]+\.[0-9]+)'                    || ok=1
check_ver curl       "--version"          "7.38"  'curl ([0-9]+\.[0-9]+(\.[0-9]+)?)'              || ok=1

echo
if [[ $ok -eq 0 ]]; then
  echo "✅ All required dependencies look good."
else
  echo "⚠ Some dependencies are missing or older than recommended. See lines above."
fi

