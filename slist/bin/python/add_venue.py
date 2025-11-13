#!/usr/bin/env python3
import os, sys
import xml.etree.ElementTree as ET

# Paths
BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'data'))
XML_FILE = os.path.join(BASE, 'venues.xml')

def load_tree():
    tree = ET.parse(XML_FILE)
    return tree, tree.getroot()

def save_tree(tree):
    tree.write(XML_FILE, encoding='utf-8', xml_declaration=True)

def get_entries(root):
    """Return list of (elem, pn, ln) for all venues except the placeholder."""
    entries = []
    for v in root.findall('venue'):
        pid = v.get('id')
        pn = v.find('pn').text or ''
        ln = v.find('ln').text or ''
        if pid != '0':
            entries.append((v, pn, ln))
    return entries

def add_venue(ln_text, pn_text):
    tree, root = load_tree()
    # Placeholder
    placeholder = root.find("venue[@id='0']")

    # Build new Element
    new_v = ET.Element('venue')
    ET.SubElement(new_v, 'pn').text = pn_text
    ET.SubElement(new_v, 'ln').text = ln_text

    # Collect and sort by pn
    entries = get_entries(root) + [(new_v, pn_text, ln_text)]
    entries.sort(key=lambda x: x[1].lower())

    # Rebuild root
    root.clear()
    if placeholder is not None:
        root.append(placeholder)
    for idx, (elem, pn, ln) in enumerate(entries, start=1):
        elem.set('id', str(idx))
        root.append(elem)

    save_tree(tree)
    print("Added venue: '{}' (short: '{}')".format(ln_text, pn_text))

def main():
    if not os.path.isfile(XML_FILE):
        sys.stderr.write("venues.xml not found at {}\n".format(XML_FILE))
        sys.exit(1)

    if len(sys.argv) == 3:
        ln_text, pn_text = sys.argv[1], sys.argv[2] or sys.argv[1]
    else:
        ln_text = input("Full venue name (ln): ").strip()
        if not ln_text:
            sys.exit("Full name required.")
        pn_text = input("Short name (pn) [same]: ").strip() or ln_text

    add_venue(ln_text, pn_text)

if __name__ == "__main__":
    main()

