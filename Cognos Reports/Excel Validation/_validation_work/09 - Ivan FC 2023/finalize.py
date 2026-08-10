import csv, os
from collections import Counter, defaultdict
from compare import load, normrow, CFG   # reuse config + helpers

D = os.path.dirname(os.path.abspath(__file__))

allres = []
percol_report = {}
for t,cfg in CFG.items():
    ch, cr = load(os.path.join(D,f'cognos_{t}.csv'))
    ph, pr = load(os.path.join(D,f'pbi_{t}.csv'))
    cols=cfg['cols']; key=cfg['key']
    cN=[normrow(r,cols) for r in cr]; pN=[normrow(r,cols) for r in pr]
    cBag=Counter(cN); pBag=Counter(pN)
    only_c=cBag-pBag; only_p=pBag-cBag
    exact=sum((cBag&pBag).values())
    # per-column comparison over value-mismatch shared keys
    def keymap(bag):
        d=defaultdict(list)
        for row,n in bag.items():
            k=tuple(row[i] for i in key)
            for _ in range(n): d[k].append(row)
        return d
    ck=keymap(only_c); pk=keymap(only_p)
    shared=set(ck)&set(pk)
    percol=Counter()
    ncomparable = len(cols)
    # build comparison file: one line per non-matching column instance
    comp_rows=[]
    for k in sorted(shared):
        # pair up rows (they may be 1:1 or n:m; pair by index)
        crows=ck[k]; prows=pk[k]
        for i in range(min(len(crows),len(prows))):
            for ci,name in enumerate(ch):
                cv=crows[i][ci]; pv=prows[i][ci]
                if cv!=pv and cols[ci]!='ASOF':
                    percol[name]+=1
                    comp_rows.append([k, name, cv, pv])
    percol_report[t]=(exact,len(cN),len(pN),percol)
    with open(os.path.join(D,f'comparison_{t}.csv'),'w',newline='',encoding='utf-8') as f:
        w=csv.writer(f)
        w.writerow(['metric','value'])
        w.writerow(['cognos_rows',len(cN)]); w.writerow(['pbi_rows',len(pN)])
        w.writerow(['exact_match_rows',exact])
        w.writerow(['only_cognos_rows',sum(only_c.values())])
        w.writerow(['only_pbi_rows',sum(only_p.values())])
        w.writerow(['match_rate_vs_cognos', round(exact/len(cN),4)])
        w.writerow([])
        w.writerow(['--- column-level mismatches on shared-key rows ---'])
        w.writerow(['key','column','cognos_value','pbi_value'])
        for r in comp_rows: w.writerow(r)
    # accumulate global residuals
    with open(os.path.join(D,f'residual_{t}.csv'),encoding='utf-8') as f:
        rr=list(csv.reader(f))
    for row in rr[1:]:
        allres.append([t]+row)

with open(os.path.join(D,'residuals.csv'),'w',newline='',encoding='utf-8') as f:
    w=csv.writer(f)
    w.writerow(['table','side','key','...columns (see per-table residual_*.csv for headers)'])
    for r in allres: w.writerow(r)

print('PER-COLUMN MISMATCH SUMMARY (shared-key value differences only):')
for t,(ex,nc,npb,pc) in percol_report.items():
    print(f'\n{t}: exact {ex}/{nc} cognos ({round(100*ex/nc,1)}%), pbi rows {npb}')
    if pc:
        for name,cnt in pc.most_common(): print(f'    {name}: {cnt} row(s) differ')
    else:
        print('    (no shared-key column differences)')
