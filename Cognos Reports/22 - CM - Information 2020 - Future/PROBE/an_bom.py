import openpyxl,csv,collections
wb=openpyxl.load_workbook('Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
ws=wb['BOM_5']; rows=list(ws.iter_rows(values_only=True)); hdr=rows[0]
cog=[dict(zip(hdr,r)) for r in rows[1:] if any(v is not None for v in r)]
edw=list(csv.DictReader(open('PROBE/13_bom_edw.csv',encoding='utf-8-sig')))
print(len(edw), collections.Counter(r['Branch'] for r in edw))
print('IsCurrent',collections.Counter(r['IsCurrent'] for r in edw))
g=collections.defaultdict(float); n=collections.Counter(); attrs={}
for r in edw:
    k=(r['Branch'],r['ParentItem2nd'],r['CompItem2nd'])
    g[k]+=float(r['Qty']); n[k]+=1; attrs[k]=(r['CompBulk'].strip(),r['CompGlobalBulk'].strip())
cg={}; ca={}
for r in cog:
    k=(r['Branch Plant'],r['Parent Second Item Number'],r['2nd Item Number'])
    cg[k]=cg.get(k,0)+float(r['Quantity']); ca[k]=(r['Bulk Item'],r['Global Bulk Item'])
print('cognos keys',len(cg),'edw keys',len(g))
only_c=[k for k in cg if k not in g]; only_e=[k for k in g if k not in cg]
print('only cognos',len(only_c),only_c[:20]); print('only edw',len(only_e),only_e[:20])
diff=[(k,cg[k],g[k]) for k in cg if k in g and abs(cg[k]-g[k])>1e-6]
print('qty diffs',len(diff),diff[:10])
ad=[(k,ca[k],attrs[k]) for k in cg if k in g and ca[k]!=attrs[k]]
print('attr diffs',len(ad),ad[:10])
print('sum cog',sum(cg.values()),'sum edw',sum(g.values()))
print('multi-row keys',sum(1 for k,v in n.items() if v>1))
