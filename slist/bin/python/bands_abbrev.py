#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Python 3.5+ compatible (no f-strings)

from __future__ import print_function
import sys, os, json, tempfile, shutil
from argparse import ArgumentParser

def load_db(path):
    if not os.path.exists(path):
        return {"abbr_map": {}, "names_seen": []}
    try:
        with open(path, "r") as f:
            db = json.load(f)
            if "abbr_map" not in db: db["abbr_map"] = {}
            if "names_seen" not in db: db["names_seen"] = []
            return db
    except Exception:
        return {"abbr_map": {}, "names_seen": []}

def atomic_write(path, text):
    d = os.path.dirname(path) or "."
    fd, tmp = tempfile.mkstemp(prefix=".tmp_bands_", dir=d)
    try:
        with os.fdopen(fd, "w") as f:
            f.write(text)
        os.replace(tmp, path)
    except Exception:
        try: os.remove(tmp)
        except Exception: pass
        raise

def save_db(path, db):
    atomic_write(path, json.dumps(db, indent=2, sort_keys=True))

def norm_abbr(s):
    return "".join(ch for ch in (s or "").strip().lower() if ch.isalnum())

def clean(s):
    return (s or "").strip()

def find_matches(db, prefix):
    prefix = norm_abbr(prefix)
    if not prefix:
        return []
    out = []
    for ab, name in sorted(db["abbr_map"].items()):
        if ab.startswith(prefix):
            out.append((ab, name))
    return out

def cmd_search(args):
    db = load_db(args.db)
    matches = find_matches(db, args.prefix)
    if not matches:
        # non-zero so bash can show (lookup error)
        return 1
    # Pretty list
    width = max(len(ab) for ab,_ in matches)
    for ab, name in matches:
        print(("{:<" + str(width) + "}  ->  {}").format(ab, name))
    return 0

def expand_one_token(db, token, auto_add, messages):
    """
    Supported token forms inside the band line:
      - "!gd"            -> expands using abbr_map
      - "Name^gd"        -> learn abbr gd -> Name (if auto_add), return "Name"
      - plain text stays as-is
    """
    t = token.strip()
    if not t:
        return t

    # Learn pattern: Name^abbr
    if "^" in t and not t.startswith("!"):
        name, ab = t.split("^", 1)
        name = clean(name)
        ab = norm_abbr(ab)
        if name and ab:
            if auto_add:
                if ab not in db["abbr_map"] or db["abbr_map"][ab] != name:
                    db["abbr_map"][ab] = name
                if name not in db["names_seen"]:
                    db["names_seen"].append(name)
            return name

    # Abbrev use: !abbr
    if t.startswith("!"):
        ab = norm_abbr(t[1:])
        if ab and ab in db["abbr_map"]:
            return db["abbr_map"][ab]
        else:
            messages.append("unknown abbr: !" + (ab or t[1:]))
            return t  # leave verbatim

    return t

def cmd_expand(args):
    db = load_db(args.db)
    messages = []
    parts = [p for p in args.input_text.split(",")]
    out_parts = []
    for p in parts:
        # also split on " + " or " / " within a part if you use those; keep simple here
        out_parts.append(expand_one_token(db, p, args.auto_add, messages))
    line = ", ".join(out_parts)
    print(line)
    # If we learned new mappings, save
    save_db(args.db, db)
    # Non-zero only if there were unknown abbrs (but we still print the line)
    return 1 if messages else 0

def cmd_add(args):
    db = load_db(args.db)
    name = clean(args.name)
    ab   = norm_abbr(args.abbr)
    if not name or not ab:
        print("Name and abbr required", file=sys.stderr)
        return 2
    if ab in db["abbr_map"] and db["abbr_map"][ab] != name and not args.force:
        print("Abbrev '{}' already maps to '{}'; use --force to overwrite."
              .format(ab, db["abbr_map"][ab]), file=sys.stderr)
        return 3
    db["abbr_map"][ab] = name
    if name not in db["names_seen"]:
        db["names_seen"].append(name)
    save_db(args.db, db)
    print("Added mapping: {} -> {}".format(ab, name))
    return 0

def build_parser():
    p = ArgumentParser(prog="bands_abbrev.py")
    p.add_argument("--db", default=os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "bands.json"))
    sub = p.add_subparsers(dest="cmd")

    s = sub.add_parser("search", help="Search by abbreviation prefix")
    s.add_argument("prefix")
    s.set_defaults(func=cmd_search)

    e = sub.add_parser("expand", help="Expand/learn abbreviations in a band list")
    e.add_argument("--input-text", required=True)
    e.add_argument("--auto-add", action="store_true")
    e.set_defaults(func=cmd_expand)

    a = sub.add_parser("add", help="Add a mapping")
    a.add_argument("--name", required=True)
    a.add_argument("--abbr", required=True)
    a.add_argument("--force", action="store_true")
    a.set_defaults(func=cmd_add)

    return p

def main():
    p = build_parser()
    args = p.parse_args()
    if not getattr(args, "cmd", None):
        p.print_help(); return 2
    return args.func(args)

if __name__ == "__main__":
    sys.exit(main())

