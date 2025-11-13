#!/usr/bin/env python3
import os
import sys
import json
import xml.etree.ElementTree as ET

# --- locate data files ---
script_dir = os.path.dirname(__file__)
data_dir = os.path.abspath(os.path.join(script_dir, '..', '..', 'data'))
json_file = os.path.join(data_dir, 'vencolor.json')
xml_file  = os.path.join(data_dir, 'venues.xml')

# --- load the color map ---
with open(json_file, encoding='utf-8') as f:
    mappings = json.load(f)

# --- parse XML ---
tree = ET.parse(xml_file)
root = tree.getroot()

# --- optional single‐venue filter ---
target = None
if len(sys.argv) == 2:
    target = sys.argv[1].strip().lower()

# --- process each <venue> ---
for venue in root.findall('venue'):
    ln_el = venue.find('ln')
    if ln_el is None or ln_el.text is None:
        continue
    ln_text = ln_el.text.strip().lower()

    # if targeting one venue, skip others
    if target and ln_text != target:
        continue

    # remove any existing <color> tags
    for old in venue.findall('color'):
        venue.remove(old)

    # find which mappings match
    hits = []
    for m in mappings:
        for loc in m.get('loc', []):
            if loc.lower() in ln_text:
                hits.append(m['color'])
                break

    # dedupe
    hits = list({h for h in hits})
    if len(hits) == 1:
        c = ET.SubElement(venue, 'color')
        c.text = hits[0]
    # if 0 or >1 hits → leave no <color>

# --- write back ---
tree.write(xml_file, encoding='utf-8', xml_declaration=True)

if target:
    print("Updated color for:", target)
else:
    print("Updated colors for all venues.")

