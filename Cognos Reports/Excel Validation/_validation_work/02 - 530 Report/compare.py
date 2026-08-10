import openpyxl, csv, datetime, io

COGNOS_XLSX = "C:/Users/Zack/Documents/Code/michelman/Cognos Reports/Excel Validation/Shell and Kemper - 530 Report.xlsx"
PBI_CSV = "C:/Users/Zack/AppData/Local/Temp/PowerBIModelingMCP/QueryResults/dax_query_result_20260706_210335_445.csv"

COLS = ['Promised Ship','Requested','Plant','Ship To','CS','Order#','Line#','Bulk','Item',
        'Description','Owner','Planner','Status','Primary Qty','Primary UOM','Secondary Qty',
        'Secondary UOM','Order Date','CSR Name','Work Ctr','MPF']
DATECOLS = {'Promised Ship','Requested','Order Date'}
NUMCOLS  = {'Primary Qty','Secondary Qty','Line#'}
INTCOLS  = {'Order#','Planner'}

def norm(col, v):
    if v is None: return ''
    if isinstance(v, datetime.datetime): return v.date().isoformat()
    if isinstance(v, datetime.date): return v.isoformat()
    s = str(v).strip()
    if col in DATECOLS:
        # parse "7/20/2026 12:00:00 AM"
        for fmt in ("%m/%d/%Y %I:%M:%S %p","%m/%d/%Y"):
            try: return datetime.datetime.strptime(s, fmt).date().isoformat()
            except: pass
        return s
    if col in NUMCOLS or col in INTCOLS:
        if s=='' : return ''
        try:
            f=float(s)
            if col in INTCOLS or f==int(f): return str(int(round(f)))
            return f"{f:.4f}"
        except: return s
    return s

# --- load cognos ---
wb = openpyxl.load_workbook(COGNOS_XLSX, data_only=True)
ws = wb['page']
rows = list(ws.iter_rows(values_only=True))
chead = list(rows[0])
cog = []
for r in rows[1:]:
    if all(c is None for c in r): continue
    d = {COLS[i]: r[i] for i in range(len(COLS))}
    cog.append(d)

# --- load pbi ---
with open(PBI_CSV, newline='', encoding='utf-8-sig') as f:
    rd = csv.reader(f)
    phead = next(rd)
    praw = list(rd)
phead_clean = [h.split('[')[-1].rstrip(']') for h in phead]
pbi = []
for r in praw:
    d = {phead_clean[i]: r[i] for i in range(len(phead_clean))}
    pbi.append(d)

print("Cognos rows:", len(cog), "| PBI rows:", len(pbi))

def key(d):
    return (norm('Order#',d['Order#']), norm('Line#',d['Line#']), norm('Bulk',d['Bulk']),
            norm('Item',d['Item']), norm('Work Ctr',d['Work Ctr']))

ckeys = {}
for d in cog: ckeys.setdefault(key(d), []).append(d)
pkeys = {}
for d in pbi: pkeys.setdefault(key(d), []).append(d)

# duplicate keys?
for k,v in ckeys.items():
    if len(v)>1: print("DUP COGNOS KEY", k, len(v))
for k,v in pkeys.items():
    if len(v)>1: print("DUP PBI KEY", k, len(v))

matched = set(ckeys) & set(pkeys)
only_cog = set(ckeys) - set(pkeys)
only_pbi = set(pkeys) - set(ckeys)
print("Matched keys:", len(matched), "| only Cognos:", len(only_cog), "| only PBI:", len(only_pbi))

# --- write normalized csvs ---
def dump(fn, data):
    with open(fn,'w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(COLS)
        for d in data:
            w.writerow([norm(c,d.get(c)) for c in COLS])
dump('cognos_page.csv', cog)
dump('pbi_Shell_Kemper_530.csv', pbi)

# --- column comparison on matched ---
colmiss = {c:0 for c in COLS}
comp_rows=[]
real_disc=[]
for k in sorted(matched):
    c=ckeys[k][0]; p=pkeys[k][0]
    flags={}
    for col in COLS:
        cv=norm(col,c.get(col)); pv=norm(col,p.get(col))
        m = 1 if cv==pv else 0
        flags[col]=m
        if not m:
            colmiss[col]+=1
            real_disc.append((k,col,cv,pv))
    comp_rows.append((k,c,p,flags))

with open('comparison.csv','w',newline='',encoding='utf-8') as f:
    w=csv.writer(f)
    hdr=['key']+[f'C_{c}' for c in COLS]+[f'flag_{c}' for c in COLS]+[f'P_{c}' for c in COLS]
    w.writerow(hdr)
    for k,c,p,flags in comp_rows:
        w.writerow([str(k)]+[norm(x,c.get(x)) for x in COLS]+[flags[x] for x in COLS]+[norm(x,p.get(x)) for x in COLS])

with open('residuals.csv','w',newline='',encoding='utf-8') as f:
    w=csv.writer(f); w.writerow(['side','key','detail'])
    for k in sorted(only_cog):
        d=ckeys[k][0]
        w.writerow(['ONLY_COGNOS',str(k),f"Owner={d['Owner']} Ship To={d['Ship To']}"])
    for k in sorted(only_pbi):
        d=pkeys[k][0]
        w.writerow(['ONLY_PBI',str(k),f"Owner={d['Owner']} Ship To={d['Ship To']}"])

print("\n--- per-column mismatch counts (matched rows only) ---")
for c in COLS:
    if colmiss[c]: print(f"  {c}: {colmiss[c]}")
total_cells = len(matched)*len(COLS)
mism = sum(colmiss.values())
print(f"\nCell match rate on matched rows: {total_cells-mism}/{total_cells} = {100*(total_cells-mism)/total_cells:.2f}%")
print(f"Row match rate: {len(matched)}/{max(len(cog),len(pbi))}")

print("\n--- ONLY IN COGNOS ---")
for k in sorted(only_cog):
    d=ckeys[k][0]; print(" ", k, "Owner=",d['Owner'],"Ship=",d['Ship To'],"Prom=",norm('Promised Ship',d['Promised Ship']))
print("--- ONLY IN PBI ---")
for k in sorted(only_pbi):
    d=pkeys[k][0]; print(" ", k, "Owner=",d['Owner'],"Ship=",d['Ship To'],"Prom=",norm('Promised Ship',d['Promised Ship']))

print("\n--- REAL cell discrepancies on matched rows ---")
for k,col,cv,pv in real_disc:
    print(f"  {k} [{col}] Cognos='{cv}' PBI='{pv}'")

# error markers / any extra columns in cognos beyond 21?
print("\nCognos header cols:", len(chead), chead[21:] if len(chead)>21 else "(exactly 21)")
