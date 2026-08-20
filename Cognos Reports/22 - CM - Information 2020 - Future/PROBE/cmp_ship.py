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
print('Cognos negative USD rows',sum(1 for r in cog if fl(r[ix['Order Net Amount USD']])<0))
print('Cognos EUR blank rows',sum(1 for r in cog if r[ix['Order Net Amount EUR']] in (None,'')))
for fld,cf in [('USD','Order Net Amount USD'),('EUR','Order Net Amount EUR'),('LB','Ordered Quantity LBs'),('KG','Ordered Quantity KGs')]:
    mm=[];big=[]
    for k in common:
        s=sum(fl(r[fld]) for r in sk[k]); c=sum(fl(r[ix[cf]]) for r in ck[k])
        if abs(s-c)>max(0.02,abs(c)*0.0005): mm.append((k,round(s,2),round(c,2),sk[k][0]['Item2nd'],sk[k][0]['OrderCo']))
        if abs(s-c)>max(1,abs(c)*0.02): big.append((k,round(s,2),round(c,2),sk[k][0]['Item2nd'],sk[k][0]['OrderCo'],sk[k][0]['QtyOrd']))
    print(fld,'mismatch',len(mm),'>2%',len(big),big[:12])
    print('   by company',collections.Counter(m[4] for m in mm))
for fld,cf in [('OrderCo','Order Company'),('Branch','Branch Plant'),('OpenFlag','Open Indicator'),('GlobalBulk','Global Bulk Item'),('Bulk','Bulk Item'),('Item2nd','2nd Item Number'),('Desc1','Description 1'),('Desc2','Description 2'),('FHC','Freight Handling Code'),('NextStatus','Next Status'),('RBU','Revenue Business Unit'),('TM','TM Name'),('CustName','Customer Name'),('Country','Country Name'),('GlobalParent','Global Parent Name'),('Chemist','Chemist Name')]:
    mm=collections.Counter()
    for k in common:
        s=(sk[k][0][fld] or '').strip(); c=str(ck[k][0][ix[cf]] if ck[k][0][ix[cf]] is not None else '').strip()
        if s!=c: mm[(s,c)]+=1
    print(fld,'mismatch',sum(mm.values()),mm.most_common(4))
mm=0
for k in common:
    s=datetime.datetime.fromisoformat(sk[k][0]['PromDate'].replace('Z','')).date(); c=ck[k][0][ix['Date']].date()
    if s!=c: mm+=1
print('date mismatch',mm)
for name,f in [('CM',lambda r: fl(r['CM'])),('USD-ExtCostUSD',lambda r: fl(r['USD'])-fl(r['ExtCostUSD'])),('USD-StdExtCostUSD',lambda r: fl(r['USD'])-fl(r['StdExtCostUSD'])),('Net-ExtCost',lambda r: fl(r['Net'])-fl(r['ExtCost']))]:
    ex=w1=0;tot=0
    for k in common:
        s=sum(f(r) for r in sk[k]); c=sum(fl(r[ix['Raw Material Margin USD']]) for r in ck[k]); tot+=s
        if abs(s-c)<=0.02: ex+=1
        if abs(s-c)<=max(0.02,0.01*abs(c)): w1+=1
    print(name,'sum',round(tot,2),'exact',ex,'within1%',w1)
print('cog RMM sum',round(sum(fl(r[ix['Raw Material Margin USD']]) for k in common for r in ck[k]),2))
# sample rows for RMM comparison
for k in common[:8]:
    r=sk[k][0]; c=ck[k][0]
    print(k,r['Item2nd'],'USD',r['USD'],'CM',r['CM'],'ExtCostUSD',r['ExtCostUSD'],'StdExt',r['StdExtCostUSD'],'FSDunit',r['FSDUnitCost'],'qty',r['QtyOrd'],'| cog USD',c[ix['Order Net Amount USD']],'RMM',c[ix['Raw Material Margin USD']])
