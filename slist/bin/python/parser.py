#!/usr/bin/env python3
import sys
from datetime import datetime
import os

# Constants
DAYS = ['mon', 'tue', 'wed', 'thr', 'fri', 'sat', 'sun']
MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun',
          'jul', 'aug', 'sep', 'oct', 'nov', 'dec']


def get_date_string(month, day):
    # Strip time so “today” is midnight
    now = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    year = now.year

    try:
        candidate = datetime(year, month, day)
    except ValueError:
        return "Invalid date"

    # If it’s already passed, roll to next year
    if candidate < now:
        year += 1
        try:
            candidate = datetime(year, month, day)
        except ValueError:
            return "Invalid date"

    dow = DAYS[candidate.weekday()]
    mstr = MONTHS[month - 1]
    # day padded to width 2, space-pad on left
    dstr = "{:2}".format(day)
    return "{} {} {}".format(mstr, dstr, dow)


def parse_additional_info(args):
    out = []
    for w in args:
        token = w.strip()
        low = token.lower()
        if low == "*":
            out.append("*")
        elif low == "$":
            out.append("$")
        elif low == "@":
            out.append("@")
        elif low == "^":
            out.append("^")
        elif low == "#":
            out.append("#")
        elif low == "m":
            out.append("(message bands for location)")
        elif low == "nf":
            out.append("no outside food/drink")
        else:
            out.append(token)
    sys.stdout.write(" ".join(out))


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: parser.py date MM/DD\n       parser.py info [symbols/text]\n")
        sys.exit(1)

    mode = sys.argv[1]
    if mode == "date":
        try:
            month, day = map(int, sys.argv[2].split("/"))
            sys.stdout.write(get_date_string(month, day))
        except:
            sys.stderr.write("Invalid date input\n")
            sys.exit(1)
    elif mode == "info":
        parse_additional_info(sys.argv[2:])
    else:
        sys.stderr.write("Unknown mode. Use 'date' or 'info'.\n")
        sys.exit(1)

