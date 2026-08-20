import csv,collections,openpyxl,datetime
def fl(s):
    if s is None or s=='': return 0.0
    return float(s)
rows=list(csv.DictReader(open('09_shipments_amounts.csv',encoding='utf-8')))
rates={}
for r in csv.DictReader(open('10_currency_month_rates.csv',encoding='utf-8')):
    d=r['PeriodEnd'][:7]
    rates[d]={'M':fl(r['RateM']),'A':fl(r['RateA']),'D':fl(r['RateDaily'])}
wb=openpyxl.load_workbook("../Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx")
ws=wb.worksheets[1]; cr=list(ws.iter_rows(values_only=True)); hdr=cr[0]; ix={h:i for i,h in enumerate(hdr)}; cog=cr[1:]
ck=collections.defaultdict(list)
for r in cog: ck[(str(r[ix['Order Number']]),fl(r[ix['Line Number']]))].append(r)
sk=collections.defaultdict(list)
for r in rows: sk[(str(int(r['OrderNum'])),float(r['LineNum']))].append(r)
common=[k for k in sk if k in ck]
print('ssas lines',len(sk),'cognos',len(ck),'common',len(common),'ssas-only',[k for k in sk if k not in ck][:10],'cog-only',[k for k in ck if k not in sk][:10])
# BOAmt when NetUSD != 0?
print('rows NetUSD!=0 & BOAmt!=0:',sum(1 for r in rows if fl(r['NetUSD'])!=0 and fl(r['BOAmt'])!=0), ' rows NetUSD==0 & BOAmt!=0:',sum(1 for r in rows if fl(r['NetUSD'])==0 and fl(r['BOAmt'])!=0), ' QtyBO>0 rows:',sum(1 for r in rows if fl(r['QtyBO'])>0))
def cmp(name,f,cf,tol=0.0005):
    ex=mm=0;bad=[];byco=collections.Counter()
    for k in common:
        s=sum(f(r) for r in sk[k]); c=sum(fl(r[ix[cf]]) for r in ck[k])
        if abs(s-c)<=max(0.02,abs(c)*tol): ex+=1
        else:
            mm+=1; byco[sk[k][0]['OrderCo']]+=1
            if len(bad)<6: bad.append((k,round(s,2),round(c,2),sk[k][0]['OrderCo'],sk[k][0]['OrderDate'][:10],sk[k][0]['GLDate'][:10]))
    print(name,'match',ex,'mismatch',mm,dict(byco),bad)
cmp('USD = NetUSD',lambda r: fl(r['NetUSD']),'Order Net Amount USD')
cmp('USD = NetUSD+BOAmt',lambda r: fl(r['NetUSD'])+fl(r['BOAmt']),'Order Net Amount USD')
cmp('USD @1%',lambda r: fl(r['NetUSD'])+fl(r['BOAmt']),'Order Net Amount USD',0.01)
def rate(r,kind,basis):
    d=r[basis] or r['OrderDate']; m=d[:7]
    return rates.get(m,{}).get(kind) or 0
def usd_m(r,basis):
    if r['LocalCcy']=='EUR': return (fl(r['Net'])+fl(r['BOAmtLC']))*rate(r,'M',basis)
    return fl(r['NetUSD'])+fl(r['BOAmt'])
cmp('USD via RateM(GL|Order)',lambda r: usd_m(r,'GLDate'),'Order Net Amount USD')
cmp('USD via RateM(Order)',lambda r: usd_m(r,'OrderDate'),'Order Net Amount USD')
def eur(r,basis,kind='M'):
    if r['LocalCcy']=='EUR': return fl(r['NetEUR'])+fl(r['BOAmtEUR'])
    rt=rate(r,kind,basis)
    return (fl(r['NetUSD'])+fl(r['BOAmt']))/rt if rt else 0
cmp('EUR native+BO',lambda r: fl(r['NetEUR'])+fl(r['BOAmtEUR']),'Order Net Amount EUR')
cmp('EUR derived RateM(GL|Order)',lambda r: eur(r,'GLDate'),'Order Net Amount EUR')
cmp('EUR derived RateM(Order)',lambda r: eur(r,'OrderDate'),'Order Net Amount EUR')
cmp('EUR derived RateM(GL|Order) @1%',lambda r: eur(r,'GLDate'),'Order Net Amount EUR',0.01)
cmp('EUR derived RateA(GL|Order) @1%',lambda r: eur(r,'GLDate','A'),'Order Net Amount EUR',0.01)
# margin
cmp('RMM = USD+BO - ExtCostUSD',lambda r: fl(r['NetUSD'])+fl(r['BOAmt'])-fl(r['ExtCostUSD']),'Raw Material Margin USD')
cmp('RMM = USD+BO - ExtCostUSD - BOCost @1%',lambda r: fl(r['NetUSD'])+fl(r['BOAmt'])-fl(r['ExtCostUSD'])-fl(r['BOCost']),'Raw Material Margin USD',0.01)
cmp('RMM = USD+BO - ExtCostUSD @1%',lambda r: fl(r['NetUSD'])+fl(r['BOAmt'])-fl(r['ExtCostUSD']),'Raw Material Margin USD',0.01)
print('totals: cog USD',round(sum(fl(r[ix['Order Net Amount USD']]) for r in cog),2),'ssas',round(sum(fl(r['NetUSD'])+fl(r['BOAmt']) for r in rows),2))
print('totals: cog EUR',round(sum(fl(r[ix['Order Net Amount EUR']]) for r in cog),2),'ssas derived',round(sum(eur(r,'GLDate') for r in rows),2))
print('totals: cog RMM',round(sum(fl(r[ix['Raw Material Margin USD']]) for r in cog),2),'ssas',round(sum(fl(r['NetUSD'])+fl(r['BOAmt'])-fl(r['ExtCostUSD']) for r in rows),2))
print('---- RateA tests')
def rate(r,kind,basis):
    d=r[basis]
    if not d or d.startswith('1900'): d=r['OrderDate']
    return rates.get(d[:7],{}).get(kind) or 0
def usd_a(r,basis):
    if r['LocalCcy']=='EUR': return (fl(r['Net'])+fl(r['BOAmtLC']))*rate(r,'A',basis)
    return fl(r['NetUSD'])+fl(r['BOAmt'])
cmp('USD via RateA(GL|Order)',lambda r: usd_a(r,'GLDate'),'Order Net Amount USD')
cmp('USD via RateA(GL|Order) @1%',lambda r: usd_a(r,'GLDate'),'Order Net Amount USD',0.01)
cmp('USD via RateA(Order)',lambda r: usd_a(r,'OrderDate'),'Order Net Amount USD')
cmp('EUR derived RateA(GL|Order)',lambda r: eur(r,'GLDate','A'),'Order Net Amount EUR')
cmp('EUR derived RateA(GL|Order) @1%',lambda r: eur(r,'GLDate','A'),'Order Net Amount EUR',0.01)
cmp('EUR derived RateA(Order)',lambda r: eur(r,'OrderDate','A'),'Order Net Amount EUR')
cmp('EUR derived RateA(Order) @1%',lambda r: eur(r,'OrderDate','A'),'Order Net Amount EUR',0.01)
# Which month does Cognos use? for mismatching 00020 lines compute implied rate and find the month whose RateA matches
imp=collections.Counter()
for k in common:
    r=sk[k][0]
    if r['LocalCcy']!='EUR' or len(sk[k])>1: continue
    n=fl(r['Net'])+fl(r['BOAmtLC']); c=sum(fl(x[ix['Order Net Amount USD']]) for x in ck[k])
    if not n or not c: continue
    ir=round(c/n,4)
    cand=[m for m,v in rates.items() if abs(v['A']-ir)<0.00015]
    g=r['GLDate'][:7] if not r['GLDate'].startswith('1900') else None; o=r['OrderDate'][:7]
    tag='GL' if g in cand else ('ORD' if o in cand else ('none' if not cand else 'other:'+','.join(cand[:2])+' g='+str(g)+' o='+o))
    imp[tag.split(':')[0]]+=1
    if tag.startswith('other') and imp['other']<=8: print('  ',k,ir,tag,'prom',r.get('PromDate',''))
print(imp)
