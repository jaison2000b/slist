#!/usr/bin/env python3
import os
import sys
import shutil
import subprocess
import readline
from datetime import datetime

# Paths (adjust relative to this script)
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'data'))
NEEDS = os.path.join(BASE, 'needs_review.txt')
MAIN  = os.path.join(BASE, 'mylist.txt')
F_FLAG = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'flags', 'f.sh'))

# Ensure data directory and files exist
os.makedirs(BASE, exist_ok=True)
open(NEEDS, 'a').close()
open(MAIN, 'a').close()

def read_records(path):
    """Yield (line1, line2) for each two-line record, skipping blanks."""
    with open(path) as f:
        lines = [l.rstrip('\n') for l in f if l.strip()]
    for i in range(0, len(lines), 2):
        l1 = lines[i]
        l2 = lines[i+1] if i+1 < len(lines) else ''
        yield l1, l2


def prompt_record(line1, line2):
    print("\nReview this entry:")
    print("  {}".format(line1))
    print("  {}".format(line2))
    choice = input("[ENTER]=keep, e=edit, d=delete: ").strip().lower()
    return choice


def prompt_edit(prompt, default):
    # Pre-fill input using readline
    def hook():
        readline.insert_text(default)
        readline.redisplay()
    readline.set_startup_hook(hook)
    try:
        result = input(prompt)
    finally:
        readline.set_startup_hook(None)
    return result if result else default


def main():
    # 1) Process entries
    for line1, line2 in read_records(NEEDS):
        choice = prompt_record(line1, line2)
        if choice == 'd':
            print('→ Deleted.')
            continue
        if choice == 'e':
            line1 = prompt_edit('Edit line1: ', line1)
            line2 = prompt_edit('Edit line2: ', line2)
            print('→ Edited, saving.')
        else:
            print('→ Accepted.')
        with open(MAIN, 'a') as m:
            m.write(line1 + '\n' + line2 + '\n\n')

    # 2) Clear needs_review.txt
    open(NEEDS, 'w').close()
    print('Cleared needs_review.txt')

    # 3) Sort main list
    print('Sorting mylist.txt ...')
    subprocess.check_call([F_FLAG, MAIN])

    # 4) Archive
    today = datetime.now().strftime('%Y%m%d')
    arch = os.path.join(BASE, 'mylist-{}.txt'.format(today))
    shutil.copy(MAIN, arch)
    print('Archived to {}'.format(os.path.basename(arch)))

    # 5) Prune
    files = sorted([f for f in os.listdir(BASE) if f.startswith('mylist-') and f.endswith('.txt')])
    if len(files) > 5:
        for old in files[:-5]:
            os.remove(os.path.join(BASE, old))
            print('Removed old archive {}'.format(old))

    # 6) Print final
    print('\n===== FINAL SHOW LIST =====')
    print(open(MAIN).read().rstrip())
    print('===========================')

if __name__ == '__main__':
    main()

