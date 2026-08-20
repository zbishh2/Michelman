import openpyxl,csv,collections
wb=openpyxl.load_workbook('Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
ws=wb['Item Details_6']; rows=list(ws.iter_rows(values_only=True)); hdr=rows[0]; print(hdr)
cog=[r for r in rows[1:] if any(v is not None for v in r)]
print(len(cog)); print(rows[1]); print(rows[2])
print('branches',collections.Counter(r[0] for r in cog))
pb=list(csv.DictReader(open('PROBE/14_item_details.csv',encoding='utf-8-sig')))
print(len(pb)); print(pb[0])
print('probe branches',collections.Counter(r['Branch'].strip() for r in pb))
cg={}
for r in cog:
    k=(r[0],r[3]); 
    if k in cg: print('dup',k)
    cg[k]=r
g={}
for r in pb:
    k=(r['Branch'].strip(), r['Item2nd'].strip())
    if k in g: print('dup probe',k)
    g[k]=r
onlyc=[k for k in cg if k not in g]; onlye=[k for k in g if k not in cg]
print('only cognos',len(onlyc),collections.Counter(k[0] for k in onlyc)); print(onlyc[:10])
print('only probe',len(onlye),collections.Counter(k[0] for k in onlye)); print(onlye[:10])

both=[k for k in cg if k in g]
bad=collections.defaultdict(list)
def s(x): return '' if x is None else str(x).strip()
for k in both:
    c=cg[k]; r=g[k]
    checks={'gb':(s(c[1]),s(r['GlobalBulk'])),'bulk':(s(c[2]),s(r['Bulk'])),'stock':(s(c[4]),s(r['StockType'])),'mpf':(s(c[5]),s(r['MPF'])),
      'ltl':(s(c[6]),s(r['LeadTimeLevel'])),'ltmfg':(s(c[7]),s(r['LeadTimeMFG'])),'pc':(s(c[8]),s(r['PlanningCode'])),'ptf':(s(c[9]),s(r['PTF'])),
      'ss':(s(c[10]),s(r['SafetyStock'])),'ssSAFE':(s(c[10]),s(r['SafetyStockSAFE'])),'shelf':(s(c[11]),s(r['ShelfLife'])),
      'supnum':(s(c[12]),s(r['SupplierNum'])),'supname':(s(c[13]),s(r['SupplierName'])),'plnum':(s(c[14]),s(r['PlannerNum'])),'plname':(s(c[15]),s(r['PlannerName'])),'planner':(s(c[15]),s(r['Planner'])),
      'buynum':(s(c[16]),s(r['BuyerNum'])),'buyname':(s(c[17]),s(r['BuyerName']))}
    for n,(a,b2) in checks.items():
        if a!=b2: bad[n].append((k,a,b2))
for n,v in bad.items(): print(n,len(v),v[:6])
