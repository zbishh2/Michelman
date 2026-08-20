import openpyxl, csv, collections
from datetime import datetime
wb = openpyxl.load_workbook(r'..\Intake\Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
cog = list(wb['Forecast_3'].iter_rows(values_only=True))[1:]
# Cognos: per (Customer Code, Company) -> RBU, TM
crbu = collections.defaultdict(set); ctm = collections.defaultdict(set)
for r in cog:
    k=(str(r[17]).strip(), str(r[0]).strip())
    crbu[k].add(str(r[8]).strip()); ctm[k].add(str(r[9]).strip())
print('cognos cust keys', len(crbu), 'multi-rbu', sum(1 for v in crbu.values() if len(v)>1), 'multi-tm', sum(1 for v in ctm.values() if len(v)>1))
pb = {(r['AddressNum'], r['Company']): r for r in csv.DictReader(open('11b_forecast_customers.csv', encoding='utf-8'))}
print('pbi cust keys', len(pb), 'CustN dist', collections.Counter(r['CustN'] for r in pb.values()))
def cmp(name, f):
    ok=bad=0; ex=[]
    for k,v in crbu.items() if name.startswith('rbu') else ctm.items():
        if k not in pb: continue
        a = list(v)[0]; b = f(pb[k]) or ''
        if a == b: ok+=1
        else:
            bad+=1
            if len(ex)<6: ex.append((k,a,b))
    print(name, 'ok', ok, 'bad', bad, ex)
cmp('rbu AddrSalesBU', lambda r: (r['AddrSalesBU'] or '').strip())
cmp('rbu CustSalesBU', lambda r: (r['CustSalesBU'] or '').strip())
cmp('rbu CustBU', lambda r: (r['CustBU'] or '').strip())
cmp('rbu CustAnySalesBU', lambda r: (r['CustAnySalesBU'] or '').strip())
cmp('tm CustRepName', lambda r: (r['CustRepName'] or '').strip() or 'Not Available')
cmp('tm CustPrimaryRep', lambda r: (r['CustPrimaryRep'] or '').strip() or 'Not Available')
cmp('tm CustAnyRepName', lambda r: (r['CustAnyRepName'] or '').strip() or 'Not Available')
# and FactForecast TM
fc = csv.DictReader(open('11_forecast_lines.csv', encoding='utf-8'))
ftm = {}
for r in fc:
    if float(r['QtyForecast'] or 0)>0: ftm[(r['AddressNum'], r['Company'])] = (r['TM'] or '').strip() or 'Not Available'
ok=bad=0; ex=[]
for k,v in ctm.items():
    if k in ftm:
        if list(v)[0]==ftm[k]: ok+=1
        else:
            bad+=1
            if len(ex)<8: ex.append((k, list(v)[0], ftm[k], pb.get(k,{}).get('CustRepName'), pb.get(k,{}).get('CustPrimaryRep')))
print('tm FactForecast', ok, bad, ex)
