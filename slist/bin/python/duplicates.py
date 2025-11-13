#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import print_function
import argparse, sys, re, os, tempfile, datetime as dt

try:
    import requests
except Exception:
    requests = None

MONTHS = ['jan','feb','mar','apr','may','jun','jul','aug','sep','oct','nov','dec']
DATE_HEADER_RE = re.compile(
    r'^(?P<mon>jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s{1,2}(?P<day>\d{1,2})\s+(?P<dow>sun|mon|tue|wed|thr|fri|sat)\b',
    re.IGNORECASE)
TIME_TOKEN_RE = re.compile(r'(\d{1,2})(?::(\d{2}))?\s*([ap])m', re.IGNORECASE)

def eprint(msg):
    sys.stderr.write(str(msg) + "\n")
    sys.stderr.flush()

def normalize_text(s):
    s = s.lower()
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def normalize_venue(s):
    if not s:
        return None
    t = s.lower().strip()
    t = re.sub(r'^\bthe\b\s+', '', t)
    t = re.sub(r"[^a-z0-9\s&/-]+", '', t)
    t = re.sub(r'\s+', ' ', t)
    return t.strip()

def hhmm_to_minutes(h, m, ap):
    h = int(h); m = int(m); ap = ap.lower()
    if h == 12: h = 0
    if ap == 'p': h += 12
    return h*60 + m

def extract_first_time_minutes(text):
    m = TIME_TOKEN_RE.search(text)
    if not m: return None
    h = int(m.group(1))
    mm = int(m.group(2) or 0)
    ap = m.group(3)
    return hhmm_to_minutes(h, mm, ap)

def year_for_next_occurrence(mon, day):
    today = dt.date.today()
    try:
        candidate = dt.date(today.year, mon, day)
    except Exception:
        return today.year
    if candidate < today:
        y = today.year + 1
        while True:
            try:
                candidate = dt.date(y, mon, day)
                break
            except ValueError:
                y += 1
    return candidate.year

def parse_blocks_from_text(lines):
    blocks, current = [], []
    for raw in lines:
        line = raw.rstrip('\n')
        if DATE_HEADER_RE.match(line.strip()):
            if current: blocks.append(current); current = []
        current.append(line)
    if current: blocks.append(current)
    return blocks

def parse_block(block_lines):
    first = ''
    for l in block_lines:
        if l.strip():
            first = l.strip(); break
    m = DATE_HEADER_RE.match(first.lower())
    if not m: return None
    mon_txt = m.group('mon').lower()
    day = int(m.group('day'))
    mon = MONTHS.index(mon_txt) + 1
    year = year_for_next_occurrence(mon, day)
    date_key = "{:04d}-{:02d}-{:02d}".format(year, mon, day)

    block_text = normalize_text(' '.join(l.strip() for l in block_lines if l is not None))
    at_pos = block_text.rfind(' at ')
    venue_norm = None
    if at_pos != -1:
        rhs = block_text[at_pos+4:]
        cut = re.search(r'\b(?:a/a|18\+|21\+|[0-9]{1,2}(?::[0-9]{2})?\s*[ap]m|\$\d|free|donation|sliding scale)\b', rhs)
        venue_raw = rhs if not cut else rhs[:cut.start()]
        venue_norm = normalize_venue(venue_raw)

    time_min = extract_first_time_minutes(block_text)
    return {
        'date_key': date_key,
        'venue_norm': venue_norm,
        'time_min': time_min,
        'full_text': '\n'.join(block_lines).strip()
    }

def parse_plain_list(text):
    lines = text.splitlines()
    blocks = parse_blocks_from_text(lines)
    out = []
    for b in blocks:
        rec = parse_block(b)
        if rec and rec['venue_norm']:
            out.append(rec)
    return out

def parse_mylist(text):
    lines = [l.rstrip('\n') for l in text.splitlines()]
    entries, i = [], 0
    while i < len(lines):
        l = lines[i].strip().lower()
        if DATE_HEADER_RE.match(l):
            block = [lines[i]]
            if i+1 < len(lines) and lines[i+1].strip() != '':
                block.append(lines[i+1])
            rec = parse_block(block)
            if rec and rec['venue_norm']:
                entries.append(rec)
            i += 2
        else:
            i += 1
    return entries

def load_venues_dict(path):
    d = {}
    if not path or not os.path.exists(path): return d
    try:
        import xml.etree.ElementTree as ET
        tree = ET.parse(path)
        root = tree.getroot()
        for v in root.findall('venue'):
            ln = (v.findtext('ln') or '').strip()
            pn = (v.findtext('pn') or '').strip()
            norm_any = normalize_venue(ln or pn)
            multiple = (v.findtext('multiple') or '').strip().lower() in ('true','1','yes','y')
            d[norm_any] = multiple
        return d
    except Exception as ex:
        eprint("Warning: could not parse venues.xml: " + str(ex))
        return {}

def save_venues_multiple_true(path, venue_norm):
    if not path or not os.path.exists(path): return False
    try:
        import xml.etree.ElementTree as ET
        tree = ET.parse(path)
        root = tree.getroot()
        changed = False
        for v in root.findall('venue'):
            ln = (v.findtext('ln') or '').strip()
            pn = (v.findtext('pn') or '').strip()
            norm_any = normalize_venue(ln or pn)
            if norm_any == venue_norm:
                el = v.find('multiple')
                if el is None:
                    el = ET.SubElement(v, 'multiple')
                if (el.text or '').strip().lower() not in ('true','1','yes','y'):
                    el.text = 'true'
                    changed = True
                break
        if changed:
            tree.write(path, encoding='utf-8', xml_declaration=True)
        return changed
    except Exception as ex:
        eprint("Warning: could not write venues.xml multiple flag: " + str(ex))
        return False

def load_live_list(args):
    if args.live_cache:
        return open(args.live_cache, 'r').read()
    elif args.live_url:
        if not requests:
            eprint("requests not available; install or use --live-cache"); sys.exit(1)
        try:
            r = requests.get(args.live_url, timeout=20)
            r.raise_for_status()
            return r.text
        except Exception as ex:
            eprint("Error fetching live URL: " + str(ex)); sys.exit(1)
    else:
        eprint("Provide --live-cache or --live-url"); sys.exit(1)

def likely_dupe(a, b):
    if a['date_key'] != b['date_key']: return False
    if a['venue_norm'] != b['venue_norm']: return False
    ta, tb = a['time_min'], b['time_min']
    if ta is None or tb is None: return True
    return abs(ta - tb) <= 60

def get_tty_streams():
    """Return (in, out) streams hooked to the real terminal if possible."""
    try:
        tty_in = open('/dev/tty', 'r')
        tty_out = open('/dev/tty', 'w')
        return tty_in, tty_out
    except Exception:
        return None, None

def interactive_filter(my_entries, live_entries, venues_map, venues_path, non_interactive):
    live_by_key = {}
    for e in live_entries:
        key = (e['date_key'], e['venue_norm'])
        live_by_key.setdefault(key, []).append(e)

    # Prepare TTY for prompts even when stdout is redirected
    tty_in, tty_out = (None, None)
    if not non_interactive:
        if sys.stdout.isatty():
            tty_in, tty_out = sys.stdin, sys.stdout
        else:
            tty_in, tty_out = get_tty_streams()
            if tty_in is None or tty_out is None:
                eprint("No TTY available; running non-interactive.")
                non_interactive = True

    out_blocks = []
    total = len(my_entries)
    for idx, e in enumerate(my_entries, 1):
        sys.stderr.write("Checking {}/{}…\r".format(idx, total))
        sys.stderr.flush()

        key = (e['date_key'], e['venue_norm'])
        candidates = live_by_key.get(key, [])
        is_mult = venues_map.get(e['venue_norm'], False)

        dupes = [x for x in candidates if likely_dupe(e, x)]
        if dupes and not is_mult and not non_interactive:
            # Prompt on TTY
            tty_out.write("\nPossible duplicate found:\n")
            tty_out.write("  YOUR: " + e['full_text'] + "\n")
            tty_out.write("  LIVE: " + dupes[0]['full_text'] + "\n")
            tty_out.write("Duplicate? [y=omit / n=keep / e=edit / u=update-note / m=mark-venue-multiple] > ")
            tty_out.flush()
            choice = (tty_in.readline().strip().lower() or 'n')

            if choice == 'y':
                continue
            elif choice == 'm' and venues_path:
                if save_venues_multiple_true(venues_path, e['venue_norm']):
                    venues_map[e['venue_norm']] = True
                    tty_out.write("  Marked venue as multiple; keeping this listing.\n")
                    tty_out.flush()
            elif choice == 'e':
                tty_out.write("Edit your listing, then press Enter (blank = keep as-is):\n")
                tty_out.write(e['full_text'] + "\n")
                tty_out.flush()
                edited = tty_in.readline().rstrip('\n')
                if edited.strip():
                    e['full_text'] = edited
            elif choice == 'u':
                tty_out.write("Type an update note (e.g. lineup/time/venue change), then Enter (blank = skip):\n")
                tty_out.flush()
                note = tty_in.readline().strip()
                if note:
                    e['full_text'] = e['full_text'] + "  " + note

        out_blocks.append(e['full_text'])

    sys.stderr.write("\n"); sys.stderr.flush()
    # Close /dev/tty if we opened it
    if tty_in not in (None, sys.stdin):
        try: tty_in.close()
        except Exception: pass
    if tty_out not in (None, sys.stdout):
        try: tty_out.close()
        except Exception: pass
    return out_blocks

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--mylist', required=True)
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--live-cache')
    g.add_argument('--live-url')
    ap.add_argument('--venues', help='venues.xml (optional, for marking multiple)')
    ap.add_argument('--non-interactive', action='store_true',
                    help='do not prompt; keep all (still honors <multiple>)')
    args = ap.parse_args()

    try:
        eprint("Parsing live list…")
        live_text = load_live_list(args)
        live_entries = parse_plain_list(live_text)
        eprint("Parsed {} live entries.".format(len(live_entries)))

        eprint("Parsing mylist…")
        my_text = open(args.mylist, 'r').read()
        my_entries = parse_mylist(my_text)
        eprint("Parsed {} local entries.".format(len(my_entries)))

        venues_map = load_venues_dict(args.venues) if args.venues else {}

        filtered_blocks = interactive_filter(my_entries, live_entries, venues_map, args.venues, args.non_interactive)

        # Emit final list to stdout (which may be redirected by caller)
        for b in filtered_blocks:
            lines = b.splitlines()
            if len(lines) >= 2:
                print(lines[0])
                print(lines[1])
            else:
                parts = b.split(' at ', 1)
                if len(parts) == 2:
                    print(parts[0].strip())
                    print("\t       at " + parts[1].strip())
                else:
                    print(b)

    except KeyboardInterrupt:
        tb = tempfile.NamedTemporaryFile(delete=False, prefix="mylist_partial_", suffix=".txt")
        path = tb.name; tb.close()
        eprint("\nInterrupted. Writing any accepted items so far to: {}".format(path))
        try:
            for e in my_entries:
                lines = e['full_text'].splitlines()
                with open(path, 'a') as wf:
                    if len(lines) >= 2:
                        wf.write(lines[0] + "\n")
                        wf.write(lines[1] + "\n")
                    else:
                        wf.write(e['full_text'] + "\n")
        except Exception as ex:
            eprint("Could not write partial file: " + str(ex))
        sys.exit(130)

if __name__ == '__main__':
    main()

