import openpyxl,csv,collections
wb=openpyxl.load_workbook('Intake/Cognos export - CM - Information 2020-Future (filed 2026-08-19).xlsx')
ws=wb['Work Orders_4']; rows=list(ws.iter_rows(values_only=True)); hdr=rows[0]
cog=[r for r in rows[1:] if any(v is not None for v in r)]
cg={}
for r in cog:
    k=(int(r[4]), r[10], r[11], r[12])
    cg[k]=dict(issued=float(r[13] or 0),ordered=float(r[14] or 0),branch=r[0],parent=r[3],start=r[5],comp=r[6],status=r[9],year=r[7],month=r[8],gb=r[1],bulk=r[2],cgb=r[15],cbulk=r[16],c2nd=r[17],stock=r[18])
wo=list(csv.DictReader(open('PROBE/12_wo_lines.csv',encoding='utf-8-sig')))
g={}
for r in wo:
    o=float(r['QtyOrdered']); i=float(r['QtyTransaction'])
    if o+i<=0: continue
    if r['ParentItem2nd'].strip() in ('','??????'): continue
    k=(int(r['WONum']), r['PLBusinessUnit'].strip(), r['CompItem2nd'].strip(), r['UOM'].strip())
    d=g.setdefault(k,dict(issued=0.0,ordered=0.0,rows=[]))
    d['issued']+=i; d['ordered']+=o; d['rows'].append(r)
onlyc=[k for k in cg if k not in g]; onlye=[k for k in g if k not in cg]; both=[k for k in cg if k in g]
dq=[(k,cg[k]['issued'],g[k]['issued'],cg[k]['ordered'],g[k]['ordered']) for k in both if abs(cg[k]['issued']-g[k]['issued'])>1e-4 or abs(cg[k]['ordered']-g[k]['ordered'])>1e-4]
print(f'probe keys {len(g)}, cognos {len(cg)}, only cognos {len(onlyc)}, only probe {len(onlye)}, qty diffs {len(dq)}')
print('only cognos:'); [print('  ',k,cg[k]['parent'],cg[k]['start'],cg[k]['ordered'],cg[k]['issued']) for k in onlyc]
print('only probe:'); [print('  ',k,g[k]['rows'][0]['ParentItem2nd'],g[k]['rows'][0]['ParentBranch'],g[k]['rows'][0]['StartDate'][:10],g[k]['ordered'],g[k]['issued']) for k in onlye]
print('diffs:'); [print('  ',x) for x in dq]
# attribute checks on matched
bad=collections.Counter()
for k in both:
    r=g[k]['rows'][0]; c=cg[k]
    if c['branch']!=r['ParentBranch']: bad['branch']+=1
    if c['parent']!=r['ParentItem2nd'].strip(): bad['parent']+=1
    if c['start'].strftime('%Y-%m-%d')!=r['StartDate'][:10]: bad['start']+=1
    cd=r['CompletedDate'][:10]
    if (c['comp'] is None and cd!='1900-01-01') or (c['comp'] is not None and c['comp'].strftime('%Y-%m-%d')!=cd): bad['comp']+=1
    if str(c['status'])!=r['WOStatus'].strip(): bad['status']+=1
    if (c['gb'] or '')!=r['ParentGlobalBulk'].strip(): bad['pgb']+=1
    if (c['bulk'] or '')!=r['ParentBulk'].strip(): bad['pbulk']+=1
    if (c['cgb'] or '')!=r['CompGlobalBulk'].strip(): bad['cgb']+=1
    if (c['cbulk'] or '')!=r['CompBulk'].strip(): bad['cbulk']+=1
    if (c['stock'] or '')!=r['CompStockType'].strip(): bad['stock']+=1
    if c['comp'] is not None and (c['year']!=c['comp'].year or c['month']!=c['comp'].month): bad['ym']+=1
    if c['comp'] is None and (c['year'] is not None or c['month'] is not None): bad['ym_null']+=1
print('attr mismatches',bad, 'of',len(both))
print('cognos null completion rows', sum(1 for k in cg if cg[k]['comp'] is None))
