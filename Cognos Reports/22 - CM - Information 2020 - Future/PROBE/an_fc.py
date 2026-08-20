import openpyxl, csv, collections
from datetime import datetime
wb = openpyxl.load_workbook(r'..\Intake\Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
ws = wb['Forecast_3']
rows = list(ws.iter_rows(values_only=True))
hdr = rows[0]; print(hdr)
cog = rows[1:]
print('cognos rows', len(cog))
def key(r):
    # Branch Plant, 2nd Item Number, Requested Date, Customer Code
    d = r[7]
    if isinstance(d, datetime): d = d.date()
    return (str(r[1]).strip(), str(r[4]).strip(), str(d), str(r[17]).strip())
cmap = collections.defaultdict(list)
for r in cog: cmap[key(r)].append(r)
print('cognos distinct keys', len(cmap), 'dups', sum(1 for k,v in cmap.items() if len(v)>1))
pb = list(csv.DictReader(open('11_forecast_lines.csv', encoding='utf-8')))
pb = [r for r in pb if float(r['QtyForecast'] or 0) > 0]
print('pbi pos rows', len(pb))
def pkey(r):
    d = r['ReqDate'][:10]
    return (r['BusinessUnit'].strip(), r['Item2nd'].strip(), d, r['AddressNum'].strip())
pmap = collections.defaultdict(list)
for r in pb: pmap[pkey(r)].append(r)
print('pbi distinct keys', len(pmap), 'dups', sum(1 for k,v in pmap.items() if len(v)>1))
common = set(cmap) & set(pmap)
print('common', len(common), 'cognos only', len(set(cmap)-set(pmap)), 'pbi only', len(set(pmap)-set(cmap)))
for k in list(set(cmap)-set(pmap))[:10]: print('C only', k, cmap[k][0][10])
for k in list(set(pmap)-set(cmap))[:15]: print('P only', k, pmap[k][0]['QtyForecast'], pmap[k][0]['Bulk'], pmap[k][0]['IBBulk'], pmap[k][0]['UpdatedDate'])
# compare values on common
mism = collections.Counter()
ex = []
for k in common:
    c = cmap[k][0]; p = pmap[k][0]
    if len(cmap[k])>1 or len(pmap[k])>1: mism['dupkey']+=1; continue
    checks = {
        'Company': (str(c[0]), p['Company']),
        'GlobalBulk': (str(c[2]).strip(), p['GlobalBulk'].strip()),
        'Bulk': (str(c[3]).strip(), p['Bulk'].strip()),
        'Desc1': (str(c[5]).strip(), (p['Desc1'] or '').strip()),
        'Desc2': (str(c[6]).strip(), (p['Desc2'] or '').strip() or '-'),
        'RevBU': (str(c[8]).strip(), p['BUDim']),
        'TM': (str(c[9]).strip(), (p['TM'] or '').strip() or 'Not Available'),
        'CF': (round(float(c[10]),3), round(float(p['QtyForecast']),3)),
        'UOM': (str(c[11]).strip(), p['UOMPrimary'].strip()),
        'LB': (round(float(c[12]),2), round(float(p['QtyFcLB']),2)),
        'KG': (round(float(c[13]),2), round(float(p['QtyFcKG']),2)),
        'CustName': (str(c[18]).strip(), (p['AddrName'] or '').strip()),
        'GP': (str(c[19]).strip(), (p['GlobalParentDesc'] or '').strip()),
        'Chemist': (str(c[20]).strip(), (p['Chemist'] or '').strip()),
    }
    for n,(a,b) in checks.items():
        if a != b:
            mism[n]+=1
            if len([e for e in ex if e[0]==n])<4: ex.append((n,k,a,b))
print(mism)
for e in ex: print(e)
# Year/Month/Date columns
print('sample cognos', cog[0])
print('sample pbi', pb[0])
