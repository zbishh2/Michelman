import csv,collections,openpyxl,datetime
rows=list(csv.DictReader(open('06_shipments_lines.csv',encoding='utf-8')))
wb=openpyxl.load_workbook("../Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx")
ws=wb.worksheets[1]; cr=list(ws.iter_rows(values_only=True)); hdr=cr[0]; ix={h:i for i,h in enumerate(hdr)}; cog=cr[1:]
def fl(s):
    if s is None or s=='': return 0.0
    return float(s)
ck=collections.defaultdict(list)
for r in cog: ck[(str(r[ix['Order Number']]),fl(r[ix['Line Number']]))].append(r)
sk=collections.defaultdict(list)
for r in rows: sk[(str(int(r['OrderNum'])),float(r['LineNum']))].append(r)
common=[k for k in sk if k in ck]
print('common',len(common))
zs=[k for k in common if sum(fl(r['USD']) for r in sk[k])==0]
print('SSAS USD=0 lines',len(zs),'Cognos USD nonzero among them',sum(1 for k in zs if sum(fl(r[ix['Order Net Amount USD']]) for r in ck[k])!=0))
print('sum Cognos USD on those', round(sum(fl(r[ix['Order Net Amount USD']]) for k in zs for r in ck[k]),2))
mm=collections.Counter(); 
for k in common:
    if k in zs: continue
    s=sum(fl(r['USD']) for r in sk[k]); c=sum(fl(r[ix['Order Net Amount USD']]) for r in ck[k])
    if abs(s-c)>max(0.02,abs(c)*0.0005): mm[sk[k][0]['OrderCo']]+=1
print('USD mismatches (nonzero) by co',mm)
rat=[]
for k in common:
    r=sk[k][0]
    if r['OrderCo']=='00020':
        s=sum(fl(x['USD']) for x in sk[k]); c=sum(fl(x[ix['Order Net Amount USD']]) for x in ck[k]); n=sum(fl(x['Net']) for x in sk[k])
        if s and c and n: rat.append((k, round(c/n,4), round(s/n,4), r['PromDate'][:10]))
print(sorted(rat,key=lambda x:x[3])[:15])
rat=[]
for k in common:
    r=sk[k][0]
    if r['OrderCo']=='00010':
        c=sum(fl(x[ix['Order Net Amount USD']]) for x in ck[k]); e=sum(fl(x[ix['Order Net Amount EUR']]) for x in ck[k])
        if c and e: rat.append((k, round(e/c,4), r['PromDate'][:10]))
print(sorted(rat,key=lambda x:x[2])[:10], sorted(rat,key=lambda x:x[2])[-5:])
ex=mm=0
for k in common:
    r=sk[k][0]
    if r['OrderCo'] in('00020','00034'):
        s=sum(fl(x['EUR']) for x in sk[k]); c=sum(fl(x[ix['Order Net Amount EUR']]) for x in ck[k])
        if abs(s-c)<=0.02: ex+=1
        else: mm+=1
print('00020/34 EUR exact',ex,'mismatch',mm)
