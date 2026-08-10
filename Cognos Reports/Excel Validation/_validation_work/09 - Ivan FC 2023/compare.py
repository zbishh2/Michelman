import csv, re, os
from collections import Counter, defaultdict

D = os.path.dirname(os.path.abspath(__file__))

def load(path):
    with open(path, encoding='utf-8') as f:
        r = list(csv.reader(f))
    return r[0], r[1:]

def norm_num(s):
    s = (s or '').strip()
    if s == '': return ''
    try:
        return round(float(s), 3)
    except:
        return s

def norm_date(s):
    s = (s or '').strip()
    if s == '': return ''
    # ISO 'YYYY-MM-DD ...'
    m = re.match(r'(\d{4})-(\d{2})-(\d{2})', s)
    if m: return f'{int(m.group(1)):04d}-{int(m.group(2)):02d}-{int(m.group(3)):02d}'
    # US 'M/D/YYYY ...'
    m = re.match(r'(\d{1,2})/(\d{1,2})/(\d{4})', s)
    if m: return f'{int(m.group(3)):04d}-{int(m.group(1)):02d}-{int(m.group(2)):02d}'
    return s

def norm_str(s):
    return (s or '').strip()

# per-table config: list of (name, kind) in column order; key = indices; asof = indices to drop
CFG = {
 'inventory': dict(
    cols=['S','S','S','S','S','S','S','S','S','N','N','S','S','ASOF','N','N'],
    key=[1,3,4,5,6,7,8]),  # Branch,BulkItem,2ndItem,StockType,Lot,Location,Status
 'work_orders': dict(
    cols=['S','S','S','S','S','S','S','S','DT','DT','N','N','S','S','N','N','N','N','N','N','N','ASOF'],
    key=[3,6,12,8]),  # WONumber,2ndItem,Component2ndItem,StartDate
 'sales_order_summary': dict(
    cols=['S','S','S','S','S','S','S','S','S','S','S','S','S','S','N','N','N','S','N','S','DT','DT','DT','DT','S','S','S','S','S'],
    key=[7,11,6]),  # OrderNumber,2ndItem,Branch
 'inventory_hp': dict(
    cols=['S','S','S','S','S','S','S','S','S','N','N'],
    key=[1,4,5,6,7]),  # Branch,2ndItem,Location,Lot,Status
 'safety_stock_hp': dict(
    cols=['S','S','S','S','S','S','N','N','ASOF'],
    key=[1,4]),  # Branch,2ndItem; col8 = duplicate REGION (visual-only, PBI table has 8 cols)
}

def normrow(row, cols):
    out=[]
    for i,k in enumerate(cols):
        v = row[i] if i < len(row) else ''
        if k=='N': out.append(norm_num(v))
        elif k=='DT': out.append(norm_date(v))
        elif k=='ASOF': out.append('<ASOF>')  # ignore
        else: out.append(norm_str(v))
    return tuple(out)

summary=[]
for t,cfg in CFG.items():
    ch, cr = load(os.path.join(D,f'cognos_{t}.csv'))
    ph, pr = load(os.path.join(D,f'pbi_{t}.csv'))
    cols=cfg['cols']; key=cfg['key']
    cN=[normrow(r,cols) for r in cr]
    pN=[normrow(r,cols) for r in pr]
    cBag=Counter(cN); pBag=Counter(pN)
    inter = cBag & pBag
    only_c = cBag - pBag
    only_p = pBag - cBag
    exact = sum(inter.values())
    # key-level diagnosis on residuals
    def keyset(bag):
        d=defaultdict(int)
        for row,n in bag.items():
            k=tuple(row[i] for i in key)
            d[k]+=n
        return d
    ck=keyset(only_c); pk=keyset(only_p)
    shared_keys=set(ck)&set(pk)   # key present both but row differs => value mismatch
    conly=set(ck)-set(pk)         # key only in cognos residual
    ponly=set(pk)-set(ck)
    print(f'\n===== {t} =====')
    print(f'  cognos rows={len(cN)}  pbi rows={len(pN)}  exact-match rows={exact}')
    print(f'  only-cognos residual rows={sum(only_c.values())}  only-pbi residual rows={sum(only_p.values())}')
    print(f'  residual keys: value-mismatch(shared key)={len(shared_keys)}  cognos-only-key={len(conly)}  pbi-only-key={len(ponly)}')
    summary.append((t,len(cN),len(pN),exact,sum(only_c.values()),sum(only_p.values()),len(shared_keys),len(conly),len(ponly)))
    # write residual detail
    with open(os.path.join(D,f'residual_{t}.csv'),'w',newline='',encoding='utf-8') as f:
        w=csv.writer(f)
        w.writerow(['side','key']+ch)
        # value mismatches first
        for k in sorted(shared_keys):
            for row,n in only_c.items():
                if tuple(row[i] for i in key)==k:
                    for _ in range(n): w.writerow(['COGNOS-diff',str(k)]+list(row))
            for row,n in only_p.items():
                if tuple(row[i] for i in key)==k:
                    for _ in range(n): w.writerow(['PBI-diff',str(k)]+list(row))
        for k in sorted(conly):
            for row,n in only_c.items():
                if tuple(row[i] for i in key)==k:
                    for _ in range(n): w.writerow(['COGNOS-only',str(k)]+list(row))
        for k in sorted(ponly):
            for row,n in only_p.items():
                if tuple(row[i] for i in key)==k:
                    for _ in range(n): w.writerow(['PBI-only',str(k)]+list(row))

print('\n\nSUMMARY TABLE')
print('table,cognos,pbi,exact,only_c,only_p,valmismatch_keys,cognos_only_keys,pbi_only_keys')
for s in summary: print(','.join(map(str,s)))
