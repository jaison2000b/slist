#!/usr/bin/env python3
from __future__ import print_function
import sys
import re
from datetime import date, timedelta
import os, sys
# ... existing imports ...

def abspath_from_cwd(p):
    return p if os.path.isabs(p) else os.path.abspath(os.path.join(os.getcwd(), p))

# later in main():
    path = abspath_from_cwd(sys.argv[1])
    with open(path, 'r') as f:
        lines = [ln.rstrip('\n') for ln in f]

# Regex for first line: mon  dd ddd ...
HEAD_RE = re.compile(r'^([a-z]{3})\s+(\d{1,2})\s+([a-z]{3})\b')

MONTHS = {
    'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,
    'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12
}

DOW_LIST = ['mon','tue','wed','thu','fri','sat','sun']

def dow_abbr(dt):
    # python weekday: Mon=0
    ab = DOW_LIST[dt.weekday()]
    # your format uses 'thr' instead of 'thu'
    return 'thr' if ab == 'thu' else ab

def safe_date(y, m, d):
    try:
        return date(y, m, d)
    except ValueError:
        return None

def parse_head(line):
    m = HEAD_RE.match(line.strip())
    if not m:
        return None
    mon_ab, day_str, dow_ab = m.group(1), m.group(2), m.group(3)
    mon_ab = mon_ab.lower()
    dow_ab = dow_ab.lower()
    if mon_ab not in MONTHS:
        return None
    # normalize thu/thr
    if dow_ab == 'thu':
        dow_ab = 'thr'
    return (MONTHS[mon_ab], int(day_str), dow_ab)

def intended_date(m, d, listed_dow, today):
    thisy = today.year
    dt_this = safe_date(thisy, m, d)
    dt_next = safe_date(thisy + 1, m, d)

    # Try matching weekday
    if dt_this and listed_dow == dow_abbr(dt_this):
        intended = dt_this
    elif dt_next and listed_dow == dow_abbr(dt_next):
        intended = dt_next
    else:
        # Fallback: choose the next upcoming occurrence
        if dt_this and dt_this >= today:
            intended = dt_this
        elif dt_next:
            intended = dt_next
        else:
            intended = dt_this  # None if invalid; handled upstream
    return intended

def main():
    if len(sys.argv) != 2:
        print("Usage: filter_future_only.py needs_review.txt", file=sys.stderr)
        sys.exit(2)

    path = sys.argv[1]
    try:
        with open(path, 'r') as f:
            lines = [ln.rstrip('\n') for ln in f]
    except Exception as e:
        print("Error reading file:", e, file=sys.stderr)
        sys.exit(1)

    # Group into strict two-line blocks, ignoring blank lines
    blocks = []
    buf = []
    for ln in lines:
        if not ln.strip():
            continue
        buf.append(ln)
        if len(buf) == 2:
            blocks.append(tuple(buf))
            buf = []
    # If odd line leftover, keep it as a one-line block (we'll pass it through)
    if buf:
        blocks.append(tuple(buf))

    today = date.today()

    kept = []
    for blk in blocks:
        head = blk[0]
        parsed = parse_head(head)
        if not parsed:
            # Can't parse → keep (safer than dropping)
            kept.append(blk)
            continue
        m, d, listed_dow = parsed
        dt = intended_date(m, d, listed_dow, today)
        if dt is None:
            kept.append(blk)  # invalid date, keep rather than drop silently
            continue
        if dt < today:
            # past → drop (but log to stderr)
            print("Dropping past listing:", head, file=sys.stderr)
            continue
        kept.append(blk)

    # Emit kept blocks (preserve your exact formatting: line1, newline, line2, newline)
    out = []
    for blk in kept:
        out.extend(list(blk))
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))

if __name__ == "__main__":
    main()

