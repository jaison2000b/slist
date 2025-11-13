#!/usr/bin/env python3
import sys
from datetime import datetime, timedelta

DAYS = ['sun', 'mon', 'tue', 'wed', 'thr', 'fri', 'sat']
MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec']

def get_date_string(month, day):
    now = datetime.now()
    year = now.year
    try:
        test_date = datetime(year, month, day)
    except ValueError:
        print("Invalid date", file=sys.stderr)
        sys.exit(1)

    # If the date has already passed this year, assume next year
    if test_date < now:
        year += 1
        test_date = datetime(year, month, day)

    month_str = MONTHS[month - 1]
    day_num = str(day)
    spacing = "  " if len(day_num) == 1 else " "

    # Get correct day abbreviation
    weekday_index = test_date.weekday()  # Monday=0
    weekday_abbr = DAYS[weekday_index]

    return f"{month_str}{spacing}{day} {weekday_abbr}"


def parse_additional_info(args):
    output = []
    i = 0
    while i < len(args):
        word = args[i]
        if word == "*":
            output.append("*")
        elif word == "$":
            output.append("$")
        elif word == "@":
            output.append("@")
        elif word == "^":
            output.append("^")
        elif word == "#":
            output.append("#")
        elif word == "m":
            output.append("Message bands for location")
        else:
            output.append(word)
        i += 1
    print(" ".join(output))


if __name__ == "__main__":
    if sys.argv[1] == "date":
        try:
            m, d = map(int, sys.argv[2].split("/"))
            print(get_date_string(m, d))
        except Exception:
            print("Invalid input", file=sys.stderr)
            sys.exit(1)
    elif sys.argv[1] == "info":
        parse_additional_info(sys.argv[2:])
    else:
        print("Usage: parser.py date MM/DD | info * @ m etc", file=sys.stderr)
