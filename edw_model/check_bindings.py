# -*- coding: utf-8 -*-
"""Every field binding in every visual must resolve to a real model object.
NOTE: glob('*.tmdl') silently SKIPS '.Measures.tmdl' -- Python's * does not match a
leading dot. Use listdir."""
import json, io, glob, os, re

ROOT = (r'C:\Users\Zack\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects'
        r'\Executive Dashboard\Executive Dashboard.Report\definition\pages')
DEF = (r'C:\Users\Zack\Michelman Inc\PBI Dashboard - LeanGo - General\PowerBI Projects'
       r'\Executive Dashboard\Executive Dashboard.SemanticModel\definition')

cols, meas = set(), set()
tdir = os.path.join(DEF, 'tables')
for name in os.listdir(tdir):
    if not name.endswith('.tmdl'):
        continue
    t = io.open(os.path.join(tdir, name), encoding='utf-8', newline='').read().replace('\r\n', '\n')
    mt = re.search(r"(?m)^table\s+(?:'([^']+)'|(\S+))\s*$", t)
    tbl = (mt.group(1) or mt.group(2)) if mt else name[:-5]
    for m in re.finditer(r"(?m)^\tcolumn\s+(?:'([^']+)'|([^\s=]+))", t):
        cols.add((tbl, m.group(1) or m.group(2)))
    for m in re.finditer(r"(?m)^\tmeasure\s+(?:'([^']+)'|([^\s=]+))", t):
        meas.add(m.group(1) or m.group(2))

print('model offers %d columns, %d measures' % (len(cols), len(meas)))

bad = []
for f in glob.glob(os.path.join(ROOT, '*', 'visuals', '*', 'visual.json')):
    s = json.dumps(json.load(io.open(f, encoding='utf-8')), ensure_ascii=False)
    page = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(f))))
    vis = os.path.basename(os.path.dirname(f))
    for kind, ent, prop in re.findall(
            r'"(Column|Measure)":\s*\{"Expression":\s*\{"SourceRef":\s*\{"Entity":\s*"([^"]+)"\}\},'
            r'\s*"Property":\s*"([^"]+)"', s):
        if kind == 'Measure':
            if prop not in meas:
                bad.append(('MEASURE', prop, page, vis))
        elif (ent, prop) not in cols and not ent.startswith('LocalDateTable'):
            bad.append(('COLUMN', '%s[%s]' % (ent, prop), page, vis))

if bad:
    print('\nBROKEN BINDINGS (%d distinct):' % len(set(bad)))
    for b in sorted(set(bad)):
        print('  %-8s %-45s page %s  visual %s' % b)
else:
    print('\nevery field binding across ALL pages resolves to a real model object')
