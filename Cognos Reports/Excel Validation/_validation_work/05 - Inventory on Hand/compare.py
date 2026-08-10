import openpyxl, csv, os

BASE = r"C:\Users\Zack\Documents\Code\michelman\Cognos Reports\Excel Validation"
OUT  = os.path.join(BASE, "_validation_work", "05 - Inventory on Hand")

COLS = ['REGION','Branch Plant','Bulk Item','2nd Item Number','Status',
        'KG/EA OH','LB/EA OH','Hard Commit','Primary UOM']
NUM  = {'KG/EA OH','LB/EA OH','Hard Commit'}
KEY  = ['Branch Plant','Bulk Item','2nd Item Number','Status','Primary UOM']

def norm_txt(v):
    return '' if v is None else str(v).strip()

def to_num(v):
    if v is None or v == '': return None
    try: return float(v)
    except: return None

# ---- Cognos ----
wb = openpyxl.load_workbook(os.path.join(BASE,'CM - Inventory on Hand.xlsx'), data_only=True)
ws = wb.active
rows = list(ws.iter_rows(values_only=True))
hdr = [norm_txt(h) for h in rows[0]]
assert hdr == COLS, hdr
cog = [dict(zip(COLS, r)) for r in rows[1:]]

# ---- PBI ----
with open(os.path.join(OUT,'pbi_CM_Inventory_on_Hand.csv'), newline='', encoding='utf-8-sig') as f:
    pbi = list(csv.DictReader(f))
# strip table-name prefixes from PBI headers
def clean(d):
    return {k.split('[')[-1].rstrip(']'): v for k,v in d.items()}
pbi = [clean(r) for r in pbi]

# write normalized cognos.csv
with open(os.path.join(OUT,'cognos.csv'),'w',newline='',encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=COLS); w.writeheader()
    for r in cog: w.writerow({c: r[c] for c in COLS})

def keyf(r):
    return tuple(norm_txt(r[c]) for c in KEY)

from collections import defaultdict
def index(data):
    d = defaultdict(list)
    for r in data: d[keyf(r)].append(r)
    return d

ci, pi = index(cog), index(pbi)
allkeys = sorted(set(ci)|set(pi))

comp_rows=[]; residuals=[]; colmis=defaultdict(int)
matched=0
for k in allkeys:
    cl, pl = ci.get(k,[]), pi.get(k,[])
    if len(cl)!=1 or len(pl)!=1:
        residuals.append(('CARDINALITY', k, f'cognos={len(cl)} pbi={len(pl)}'))
        continue
    c, p = cl[0], pl[0]
    rowok=True; diffs=[]
    rec={'key':' | '.join(k)}
    for col in COLS:
        if col in NUM:
            cv, pv = to_num(c[col]), to_num(p[col])
            if cv is None and pv is None: ok=True
            elif cv is None or pv is None: ok=False
            else: ok = abs(cv-pv) <= max(0.01, abs(cv)*1e-6)
        else:
            ok = norm_txt(c[col]) == norm_txt(p[col])
        rec[col]=1 if ok else 0
        if not ok:
            rowok=False; colmis[col]+=1
            diffs.append(f'{col}: cognos={c[col]!r} pbi={p[col]!r}')
    comp_rows.append(rec)
    if rowok: matched+=1
    else: residuals.append(('VALUE', k, ' ; '.join(diffs)))

with open(os.path.join(OUT,'comparison.csv'),'w',newline='',encoding='utf-8') as f:
    w=csv.DictWriter(f, fieldnames=['key']+COLS); w.writeheader()
    for r in comp_rows: w.writerow(r)
with open(os.path.join(OUT,'residuals.csv'),'w',newline='',encoding='utf-8') as f:
    w=csv.writer(f); w.writerow(['type','key','detail'])
    for r in residuals: w.writerow(r)

# KG/LB math verification
FACTOR=0.453593
mathfail=[]
for r in cog:
    uom=norm_txt(r['Primary UOM']); kg=to_num(r['KG/EA OH']); lb=to_num(r['LB/EA OH'])
    if kg is None or lb is None: continue
    if uom=='KG':
        exp_lb = kg/FACTOR
        if abs(exp_lb-lb)>max(0.01,abs(exp_lb)*1e-4): mathfail.append((keyf(r),'KG',kg,lb,exp_lb))
    elif uom=='LB':
        exp_kg = lb*FACTOR
        if abs(exp_kg-kg)>max(0.01,abs(exp_kg)*1e-4): mathfail.append((keyf(r),'LB',kg,lb,exp_kg))
    else:
        if abs(kg-lb)>0.01: mathfail.append((keyf(r),uom,kg,lb,'passthru-equal'))

print(f'Cognos rows: {len(cog)}  PBI rows: {len(pbi)}')
print(f'Distinct keys: cognos={len(ci)} pbi={len(pi)} union={len(allkeys)}')
print(f'Fully-matched rows: {matched}/{len(allkeys)}')
print(f'Column mismatch counts: {dict(colmis)}')
print(f'Residuals: {len(residuals)}')
for r in residuals[:50]: print('  ',r)
print(f'KG/LB math failures: {len(mathfail)}')
for m in mathfail[:20]: print('  ',m)
# uom distribution
from collections import Counter
print('UOM dist (cognos):', Counter(norm_txt(r["Primary UOM"]) for r in cog))
print('Region dist (cognos):', Counter(norm_txt(r["REGION"]) for r in cog))
