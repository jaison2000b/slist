#!/usr/bin/env python3
import sys
import re
from datetime import datetime

def parse_time_segment(segment, default_ampm='pm'):
    segment = segment.strip().lower()
    ampm = default_ampm

    # Extract explicit am/pm suffix
    if segment.endswith('am') or segment.endswith('a'):
        ampm = 'am'
        segment = re.sub(r'(am|a)$', '', segment)
    elif segment.endswith('pm') or segment.endswith('p'):
        ampm = 'pm'
        segment = re.sub(r'(pm|p)$', '', segment)

    segment = segment.strip()

    # Initialize
    hour = 0
    minute = 0

    # 1-digit: hour only
    if re.fullmatch(r'\d{1}', segment):
        hour = int(segment)
        minute = 0

    # 2-digit: could be hour or shorthand minute
    elif re.fullmatch(r'\d{2}', segment):
        val = int(segment)
        if 0 <= val <= 12:
            hour = val
            minute = 0
        elif 13 <= val <= 95:
            # e.g. '73' → 7:30
            s = segment.zfill(2)
            hour = int(s[0])
            minute = int(s[1]) * 10
        else:
            return "invalid"

    # 3-digit: HMM
    elif re.fullmatch(r'\d{3}', segment):
        hour = int(segment[0])
        minute = int(segment[1:])

    # 4-digit: HHMM
    elif re.fullmatch(r'\d{4}', segment):
        hour = int(segment[:2])
        minute = int(segment[2:])

    # HH:MM
    elif re.fullmatch(r'\d{1,2}:\d{2}', segment):
        parts = segment.split(':')
        hour = int(parts[0])
        minute = int(parts[1])

    else:
        return "invalid"

    # Validate
    if not (1 <= hour <= 12 and 0 <= minute < 60):
        return "invalid"

    # Build a datetime to format
    try:
        # Use strptime with a formatted string
        timestr = "{:d}:{:02d} {}".format(hour, minute, ampm.upper())
        dt = datetime.strptime(timestr, "%I:%M %p")
        # Format back: no leading zero on hour, lowercase am/pm, drop ":00"
        out = dt.strftime("%I:%M%p").lstrip('0').lower()
        return out.replace(":00", "")
    except Exception:
        return "invalid"

def smarttime(raw):
    raw = raw.strip()
    if "/" in raw:
        parts = raw.split("/")
        results = []
        default_ampm = None
        for part in parts:
            parsed = parse_time_segment(part, default_ampm or 'pm')
            if parsed == "invalid":
                return "invalid"
            # track last am/pm for default
            if parsed.endswith('am'):
                default_ampm = 'am'
            elif parsed.endswith('pm'):
                default_ampm = 'pm'
            results.append(parsed)
        return "/".join(results)
    else:
        return parse_time_segment(raw, 'pm')

if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.stderr.write("Usage: smarttime.py <time> (e.g. 73 or 11a/1230)\n")
        sys.exit(1)
    print(smarttime(sys.argv[1]))

