import csv, glob, os, datetime, re
from collections import Counter

TMP = r'C:/Users/Zack/AppData/Local/Temp/PowerBIModelingMCP/QueryResults'
OUT = r'C:/Users/Zack/Documents/Code/michelman/Cognos Reports/Excel Validation/_validation_work/08 - SK Forecast'

# --- Load PBI windows (9 files with rk column) ---
files = sorted(glob.glob(os.path.join(TMP, 'dax_query_result_20260706_21*.csv')))
pbi_rows = {}
pbi_header = None
for f in files:
    with open(f, encoding='utf-8-sig') as fh:
        r = list(csv.reader(fh))
    hdr = r[0]
    if not hdr or 'Sales_History[Order Company]' not in hdr[0] or '[rk]' not in hdr:
        continue
    pbi_header = hdr
    rk_i = hdr.index('[rk]')
    for row in r[1:]:
        if len(row) < len(hdr):
            continue
        pbi_rows[int(row[rk_i])] = row
print('pbi window rows collected:', len(pbi_rows), 'min/max rk', min(pbi_rows), max(pbi_rows))

def cn(h):
    return re.sub(r'^Sales_History\[|^\[|\]$', '', h)
pcols = [cn(h) for h in pbi_header]
sk_idx = pcols.index('sk'); rk_idx = pcols.index('rk')
data_cols = [c for i, c in enumerate(pcols) if i not in (sk_idx, rk_idx)]

with open(os.path.join(OUT, 'pbi_Sales_History.csv'), 'w', newline='', encoding='utf-8') as fh:
    w = csv.writer(fh)
    w.writerow(data_cols)
    for rk in sorted(pbi_rows):
        row = pbi_rows[rk]
        w.writerow([v for i, v in enumerate(row) if i not in (sk_idx, rk_idx)])
print('wrote merged pbi rows:', len(pbi_rows))

def norm_date(v):
    v = str(v).strip()
    for fmt in ('%m/%d/%Y %I:%M:%S %p', '%m/%d/%Y', '%Y-%m-%d %H:%M:%S', '%Y-%m-%d'):
        try:
            return datetime.datetime.strptime(v, fmt).date()
        except Exception:
            pass
    return v
def to_int(v):
    try:
        return int(float(str(v).strip()))
    except Exception:
        return str(v).strip()
def to_num(v):
    try:
        return float(v)
    except Exception:
        return None

def keyf(d):
    return (to_int(d['Order Number']), d['2nd Item Number'].strip(), norm_date(d['Promised Ship Date']),
            d['Ordering Unit of Measure'].strip(), round(to_num(d['Ordered Quantity']), 3),
            d['Branch Plant'].strip(), d['Customer Code'].strip())

pbi = {}
pbi_dupe = 0
with open(os.path.join(OUT, 'pbi_Sales_History.csv'), encoding='utf-8') as fh:
    for d in csv.DictReader(fh):
        k = keyf(d)
        if k in pbi:
            pbi_dupe += 1
        pbi[k] = d
print('pbi keyed:', len(pbi), 'dupe keys:', pbi_dupe)

cog = []
with open(os.path.join(OUT, 'cognos_sales_history.csv'), encoding='utf-8') as fh:
    for d in csv.DictReader(fh):
        cog.append(d)
print('cognos rows:', len(cog))

compare_cols = ['Order Company', 'Branch Plant', 'Global Bulk Item', 'Bulk Item', '2nd Item Number', 'Order Number',
    'Next Status', 'Year', 'Month', 'Week', 'Promised Ship Date', 'Ordered Quantity KGs', 'Revenue Business Unit',
    'Customer Code', 'Customer Name', 'Global Parent', 'Global Parent Name', 'TM Name', 'Country Name',
    'Ordered Quantity', 'Ordering Unit of Measure', 'Ordered Quantity LBs', 'Open Indicator']
num_cols = {'Ordered Quantity KGs', 'Ordered Quantity LBs', 'Ordered Quantity'}
int_cols = {'Order Number', 'Year', 'Month', 'Week', 'Global Parent'}
date_cols = {'Promised Ship Date'}

def eqval(col, cv, pv):
    if col in num_cols:
        a, b = to_num(cv), to_num(pv)
        if a is None or b is None:
            return str(cv).strip() == str(pv).strip()
        return abs(a - b) <= 0.01
    if col in int_cols:
        return to_int(cv) == to_int(pv)
    if col in date_cols:
        return norm_date(cv) == norm_date(pv)
    return str(cv).strip() == str(pv).strip()

matched = 0
mismatch_counts = Counter()
comparison_rows = []
cog_unmatched = []
used = set()
for d in cog:
    k = keyf(d)
    p = pbi.get(k)
    if p is None:
        cog_unmatched.append(d)
        comparison_rows.append((d, None, None))
        continue
    used.add(k)
    matched += 1
    flags = {}
    for col in compare_cols:
        ok = eqval(col, d.get(col, ''), p.get(col, ''))
        flags[col] = 1 if ok else 0
        if not ok:
            mismatch_counts[col] += 1
    comparison_rows.append((d, p, flags))

pbi_unmatched = [pbi[k] for k in pbi if k not in used]
print('\n=== MATCH SUMMARY ===')
print('cognos rows:', len(cog), ' matched:', matched, ' cognos-unmatched:', len(cog_unmatched))
print('pbi rows:', len(pbi), ' pbi-unmatched(extra):', len(pbi_unmatched))
print('key-match rate: %.2f%%' % (100 * matched / len(cog)))
allmatch = sum(1 for d, p, f in comparison_rows if p is not None and all(f.values()))
print('rows all-columns-match: %d (%.2f%% of cognos)' % (allmatch, 100 * allmatch / len(cog)))
allmatch_excl_tm = sum(1 for d, p, f in comparison_rows if p is not None and all(v for c, v in f.items() if c != 'TM Name'))
print('rows all-columns-match EXCL TM Name: %d (%.2f%%)' % (allmatch_excl_tm, 100 * allmatch_excl_tm / len(cog)))
print('\n=== PER-COLUMN MISMATCH COUNTS (of %d matched) ===' % matched)
for col in compare_cols:
    if mismatch_counts[col]:
        print('  %-25s %d' % (col, mismatch_counts[col]))
if not mismatch_counts:
    print('  (none)')

with open(os.path.join(OUT, 'comparison_sales_history.csv'), 'w', newline='', encoding='utf-8') as fh:
    w = csv.writer(fh)
    w.writerow(['match_status', 'Order Number', '2nd Item Number', 'Promised Ship Date', 'UOM', 'Qty'] + ['flag_' + c for c in compare_cols])
    for d, p, flags in comparison_rows:
        if p is None:
            w.writerow(['COGNOS_ONLY', d['Order Number'], d['2nd Item Number'], d['Promised Ship Date'], d['Ordering Unit of Measure'], d['Ordered Quantity']] + [''] * len(compare_cols))
        else:
            st = 'ALL_MATCH' if all(flags.values()) else 'MISMATCH'
            w.writerow([st, d['Order Number'], d['2nd Item Number'], d['Promised Ship Date'], d['Ordering Unit of Measure'], d['Ordered Quantity']] + [flags[c] for c in compare_cols])
    for p in pbi_unmatched:
        w.writerow(['PBI_ONLY', p['Order Number'], p['2nd Item Number'], p['Promised Ship Date'], p['Ordering Unit of Measure'], p['Ordered Quantity']] + [''] * len(compare_cols))

with open(os.path.join(OUT, 'residuals.csv'), 'w', newline='', encoding='utf-8') as fh:
    w = csv.writer(fh)
    w.writerow(['type', 'Order Number', '2nd Item Number', 'Promised Ship Date', 'UOM', 'Qty', 'detail'])
    for d in cog_unmatched:
        w.writerow(['COGNOS_ONLY', d['Order Number'], d['2nd Item Number'], d['Promised Ship Date'], d['Ordering Unit of Measure'], d['Ordered Quantity'], ''])
    for p in pbi_unmatched:
        w.writerow(['PBI_ONLY', p['Order Number'], p['2nd Item Number'], p['Promised Ship Date'], p['Ordering Unit of Measure'], p['Ordered Quantity'], 'Next Status ' + p['Next Status']])
    for d, p, flags in comparison_rows:
        if p is not None and not all(flags.values()):
            bad = [c for c in compare_cols if not flags[c]]
            det = '; '.join('%s: [%s] vs [%s]' % (c, d.get(c, ''), p.get(c, '')) for c in bad)
            w.writerow(['COL_MISMATCH', d['Order Number'], d['2nd Item Number'], d['Promised Ship Date'], d['Ordering Unit of Measure'], d['Ordered Quantity'], det])

print('\n=== PBI-ONLY (extra) rows ===')
for p in sorted(pbi_unmatched, key=lambda x: to_int(x['Order Number'])):
    print('  ', p['Order Number'], p['2nd Item Number'], norm_date(p['Promised Ship Date']), p['Ordering Unit of Measure'], p['Ordered Quantity'], 'NS=' + p['Next Status'], p['Branch Plant'])
print('\n=== COGNOS-ONLY rows ===')
for d in cog_unmatched:
    print('  ', d['Order Number'], d['2nd Item Number'], norm_date(d['Promised Ship Date']), d['Ordering Unit of Measure'], d['Ordered Quantity'])

print('\n=== TM Name mismatch distinct pairs (cognos vs pbi), up to 25 ===')
seen = set()
for d, p, flags in comparison_rows:
    if p is not None and flags.get('TM Name') == 0:
        pair = (d['TM Name'], p['TM Name'])
        if pair not in seen:
            seen.add(pair)
            print('  [%s]  vs  [%s]' % pair)
    if len(seen) >= 25:
        break
print('  distinct TM mismatch pairs total:', len({(d['TM Name'], p['TM Name']) for d, p, f in comparison_rows if p is not None and f.get('TM Name') == 0}))

print('\n=== Non-TM-Name column mismatches (detail) ===')
cnt = 0
for d, p, flags in comparison_rows:
    if p is not None:
        bad = [c for c in compare_cols if not flags[c] and c != 'TM Name']
        if bad:
            cnt += 1
            if cnt <= 50:
                print('  Ord', d['Order Number'], d['2nd Item Number'], '|', '; '.join('%s:[%s]vs[%s]' % (c, d.get(c, ''), p.get(c, '')) for c in bad))
print('  total rows with non-TM mismatch:', cnt)
