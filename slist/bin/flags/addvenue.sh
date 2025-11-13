#!/usr/bin/env bash
set -euo pipefail

# locate our helpers
HERE="$(cd "$(dirname "$0")" && pwd)"
PY_ADD="$HERE/../python/add_venue.py"
COLOR_UPDATE="$HERE/colorupdate.sh"
XML_FILE="$(cd "$HERE/../../data" && pwd)/venues.xml"

# run add_venue.py, interactive if no args, or with full+pn if provided
if [[ $# -eq 0 ]]; then
  python3 "$PY_ADD"       # prompts you for ln & pn
elif [[ $# -eq 2 ]]; then
  python3 "$PY_ADD" "$1" "$2"
else
  echo "Usage: $0 [\"Full LN\"] [\"Short PN\"]" >&2
  exit 1
fi

# now fetch the very last <ln> from venues.xml
# and update its color tag
"$COLOR_UPDATE" 
done

