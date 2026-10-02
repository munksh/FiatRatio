#!/usr/bin/env python3
"""After lupdate: give every English entry its source text as translation.

An English .qm is what lets a deliberate "English" override win over a phone
set to another language; an empty entry would fall through to that language.

    lupdate qml -ts translations/harbour-fiatratio-en.ts
    python3 tools/fill_en_ts.py"""
import os
import xml.etree.ElementTree as ET

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "translations", "harbour-fiatratio-en.ts")
tree = ET.parse(path)
for msg in tree.getroot().iter("message"):
    tr = msg.find("translation")
    if tr.get("type") in ("obsolete", "vanished"):
        continue
    tr.text = msg.find("source").text
    tr.attrib.pop("type", None)
tree.write(path, encoding="utf-8", xml_declaration=True)
print("filled", path)
