import openpyxl,csv,collections
wb=openpyxl.load_workbook('Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
ws=wb['Work Orders_4']; rows=list(ws.iter_rows(values_only=True)); hdr=rows[0]; print(hdr)
cog=[dict(zip(range(len(hdr)),r)) for r in rows[1:] if any(v is not None for v in r)]
print(len(cog)); print(rows[1]); print(rows[2])
wo=list(csv.DictReader(open('PROBE/12_wo_lines.csv',encoding='utf-8-sig')))
print(len(wo)); print(wo[0])
print('CompType',collections.Counter(r['CompType'] for r in wo)); print('LineType',collections.Counter(r['LineType'] for r in wo)); print('WOType',collections.Counter(r['WOType'] for r in wo)); print('WOStatus',collections.Counter(r['WOStatus'] for r in wo).most_common(12))

# Cognos grain: (WO, PL branch, comp 2nd, UOM) with sum Issued, Ordered
cg={}
for r in cog:
    k=(int(r[4]), r[10], r[11], r[12])
    if k in cg: print('dup cognos key',k)
    cg[k]=dict(issued=float(r[13] or 0),ordered=float(r[14] or 0),branch=r[0],parent=r[3],start=r[5],comp=r[6],status=r[9],year=r[7],month=r[8],gb=r[15],bulk=r[16],stock=r[18])
def agg(rows, issued_field):
    g={}
    for r in rows:
        k=(int(r['WONum']), r['PLBranch'], r['CompItem2nd'].strip(), r['UOM'].strip())
        d=g.setdefault(k,dict(issued=0.0,ordered=0.0,n=0,rows=[]))
        d['issued']+=float(r[issued_field]); d['ordered']+=float(r['QtyOrdered']); d['n']+=1; d['rows'].append(r)
    return g
for fld in ('QtyShipped','QtyTransaction'):
    g=agg(wo,fld)
    g2={k:v for k,v in g.items() if v['ordered']+v['issued']>0}
    onlyc=[k for k in cg if k not in g2]; onlye=[k for k in g2 if k not in cg]
    both=[k for k in cg if k in g2]
    dq=[(k,cg[k]['issued'],g2[k]['issued'],cg[k]['ordered'],g2[k]['ordered']) for k in both if abs(cg[k]['issued']-g2[k]['issued'])>1e-6 or abs(cg[k]['ordered']-g2[k]['ordered'])>1e-6]
    print(f'== issued={fld}: probe keys {len(g)} (>0: {len(g2)}), cognos {len(cg)}, only cognos {len(onlyc)}, only probe {len(onlye)}, qty diffs {len(dq)}')
    print('  only cognos sample',onlyc[:8]); print('  only probe sample',onlye[:8]); print('  diffs sample',dq[:8])
    globals()['g_'+fld]=g2; globals()['onlyc_'+fld]=onlyc; globals()['onlye_'+fld]=onlye

print('\n#### extras (only probe, QtyTransaction)')
g=g_QtyTransaction
import itertools
ex=onlye_QtyTransaction
print(collections.Counter(k[1] for k in ex)); print(collections.Counter(k[2]=='' for k in ex))
for k in ex[:12]:
    for r in g[k]['rows'][:2]:
        print({x:r[x] for x in ('WONum','WOType','StartDate','CompletedDate','WOStatus','ParentItem2nd','ParentBranch','ParentBulk','PLBranch','CompItem2nd','CompIBItem2nd','CompBulk','UOM','QtyOrdered','QtyTransaction','LineType')})
print('\n#### missing (only cognos)')
for k in onlyc_QtyTransaction: print(k, cg[k])
# do the missing WOs exist in probe at all?
wos=set(int(r['WONum']) for r in wo)
print('missing WO present in probe:', [(k[0], k[0] in wos) for k in onlyc_QtyTransaction])
